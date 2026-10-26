"""Salons multijoueur en direct : salle d'attente, partie rapide, manches synchronisées.

Chaque client garde une WebSocket ouverte. À chaque changement d'une salle, chaque membre reçoit le
`room_state` complet : un client (ou un client qui se reconnecte) n'a besoin que du dernier état
pour afficher le bon écran.

Les salles vivent dans la mémoire de ce processus (un seul worker d'API pour le MVP) ; les parties,
manches et réponses sont enregistrées via multiplayer_service.
"""

import asyncio
import contextlib
import logging
import random
import secrets
from types import SimpleNamespace
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timedelta

from fastapi import WebSocket
from pydantic import Field, ValidationError, model_validator
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.database import SessionLocal
from app.core.game_rules import (
    BONUS_CATEGORIES,
    BONUS_ROUND_DURATION,
    CHAT_HISTORY,
    CHAT_MESSAGE_MAX,
    CHAT_UNLOCK_PRICE,
    EXTRA_HINT_PRICE,
    FREEZE_PRICE,
    FREEZE_SECONDS,
    FREEZES_PER_GAME,
    HINTS_PER_GAME,
    LIGHTNING_SECONDS,
    MAX_ROOM_PLAYERS,
    MAX_STAKE,
    MIN_ROOM_PLAYERS,
    ROOM_THEMES,
    STICKER_IDS,
    SUBMIT_GRACE_SECONDS,
    Category,
    Difficulty,
    Language,
)
from app.models import Profile
from app.models.base import utcnow
from app.schemas.game import GameSettings
from app.api.games.presenters import enrich_answer_dict
from app.services import (
    bot_service,
    fact_service,
    hint_service,
    iq_service,
    multiplayer_service,
    perks_service,
    room_store,
    voice_service,
    wallet_service,
)
from app.services.presence_service import PresenceStore, RedisPresence
from app.services.room_extras import (
    ChatMessage,
    LightningChallenge,
    Reaction,
    assign_relay_categories,
    build_word_review,
    compute_titles,
    score_lightning,
    trim_chat,
    trim_reactions,
)

logger = logging.getLogger(__name__)

CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # pas de confusion O/0 ni I/1
CODE_LENGTH = 5


class RoomSettings(GameSettings):
    public: bool = False
    max_players: int = Field(default=MAX_ROOM_PLAYERS, ge=MIN_ROOM_PLAYERS, le=MAX_ROOM_PLAYERS)
    # « classic » : gratuit ; « bet » : chaque joueur mise ; « prize » : l'hôte place la dotation.
    kind: str = Field(default="classic", pattern="^(classic|bet|prize)$")
    stake: int = Field(default=0, ge=0, le=MAX_STAKE)
    # « rounds » | « elimination » | « relay » (chaque joueur a un sous-ensemble de catégories).
    format: str = Field(default="rounds", pattern="^(rounds|elimination|relay)$")
    # Thème du jour : catégories à score doublé (geography | names | nature | "").
    theme: str = Field(default="", pattern="^(|geography|names|nature)$")
    # Jeu du salon : « letters » (Géographie & Nature, le Petit Bac) ou « iq » (énigmes de QI).
    game: str = Field(default="letters", pattern="^(letters|iq)$")
    # QI : bonus de rapidité (jusqu'à +10) et malus si la réponse est fausse (−5), au choix de l'hôte.
    iq_speed_bonus: bool = True
    iq_penalty: bool = False

    @model_validator(mode="after")
    def _check_stake(self) -> "RoomSettings":
        if self.kind in ("bet", "prize") and self.stake < 1:
            raise ValueError("a betting/prize room needs a stake")
        if self.kind == "classic":
            self.stake = 0
        if self.game == "iq":
            # Pas de lettre ni de catégories en QI : ni relais ni thème.
            if self.format == "relay":
                self.format = "rounds"
            self.theme = ""
        return self

    @property
    def iq(self) -> bool:
        return self.game == "iq"

    @property
    def betting(self) -> bool:
        return self.kind == "bet"

    @property
    def prize(self) -> bool:
        return self.kind == "prize"

    @property
    def elimination(self) -> bool:
        return self.format == "elimination"

    @property
    def relay(self) -> bool:
        return self.format == "relay"

    @property
    def theme_categories(self) -> list[Category]:
        return list(ROOM_THEMES.get(self.theme, ()))


@dataclass
class Timings:
    countdown: float = 3.0
    results: float = 8.0
    quick_start: float = 15.0
    reconnect_grace: float = 30.0
    presence_interval: float = 5.0
    submit_grace: float = SUBMIT_GRACE_SECONDS
    # Un joueur seul en partie rapide reçoit des bots après cette attente.
    quick_bot_fill: float = 12.0
    quick_bot_count: int = 2
    # Multiplie les délais de réponse des bots (les tests utilisent une toute petite valeur).
    bot_speed: float = 1.0


@dataclass
class RoomPlayer:
    client_id: str
    nickname: str
    ready: bool = False
    connected: bool = True
    score: int = 0
    # Renseigné dès que le joueur participe à la partie (ceux qui arrivent en retard l'obtiennent à
    # la manche suivante).
    db_player_id: str | None = None
    bot_level: Difficulty | None = None
    hints_used: int = 0
    bonus_hints: int = 0
    # Freeze : 1 gratuit en début de partie, rechargeables en pièces.
    freezes_left: int = 0
    chat_unlocked: bool = False
    rematch_vote: bool = False
    title: str = ""
    # Éliminatoires : manche où le joueur a été éliminé (il regarde la suite).
    eliminated_round: int | None = None
    avatar_preset: int = 0
    avatar_url: str | None = None
    level: int = 1
    # Apparences visibles par la salle (identifiants du catalogue, ou vide).
    hair: str = ""
    hat: str = ""
    frame: str = ""
    name_style: str = ""
    # Langue de l'appli du joueur (il répond dans celle-ci) et pays d'origine (drapeau).
    language: str = "fr"
    country: str | None = None

    @property
    def bot(self) -> bool:
        return self.bot_level is not None


@dataclass
class LiveRound:
    number: int
    letter: str
    started_at: datetime
    ends_at: datetime
    participants: dict[str, str]  # id client -> id joueur en base
    submissions: dict[str, tuple[datetime, dict[Category, str]]] = field(default_factory=dict)
    all_in: asyncio.Event = field(default_factory=asyncio.Event)
    bot_tasks: list[asyncio.Task] = field(default_factory=list)
    hints: dict[str, dict[str, hint_service.Hint]] = field(default_factory=dict)  # client -> catégorie
    # Relais : catégories assignées à chaque client.
    assignments: dict[str, list[str]] = field(default_factory=dict)
    # Freeze : client cible -> fin du gel.
    frozen_until: dict[str, datetime] = field(default_factory=dict)
    bonus: bool = False
    # QI : l'énigme de la manche.
    puzzle: iq_service.Puzzle | None = None


@dataclass
class Room:
    code: str
    settings: RoomSettings
    quick: bool
    host_id: str
    players: dict[str, RoomPlayer] = field(default_factory=dict)
    # waiting -> countdown -> round -> results -> lightning? -> ... -> finished -> waiting
    phase: str = "waiting"
    game_id: str | None = None
    round_number: int = 0
    live_round: LiveRound | None = None
    results: dict | None = None
    starts_at: datetime | None = None  # démarrage automatique de la partie rapide
    go_at: datetime | None = None
    next_round_at: datetime | None = None
    game_task: asyncio.Task | None = None
    quick_timer: asyncio.Task | None = None
    bot_fill_timer: asyncio.Task | None = None
    # Salon de paris : joueurs qui ont payé leur mise pour la partie en cours, et ce que chacun a
    # gagné une fois la partie terminée.
    stakers: list[str] = field(default_factory=list)
    winnings: dict[str, int] = field(default_factory=dict)
    chat: deque[ChatMessage] = field(default_factory=lambda: deque(maxlen=CHAT_HISTORY))
    reactions: deque[Reaction] = field(default_factory=lambda: deque(maxlen=24))
    lightning: LightningChallenge | None = None
    results_history: list[dict] = field(default_factory=list)
    word_review: list[dict] = field(default_factory=list)
    bonus_played: bool = False
    # Salon gardé en base (créé par un joueur) : son créateur en redevient l'hôte à chaque retour.
    creator_id: str | None = None
    # Vocal pendant la partie : mutés / exclus par l'hôte (humains seulement).
    voice_muted: set[str] = field(default_factory=set)
    voice_excluded: set[str] = field(default_factory=set)

    @property
    def in_game(self) -> bool:
        return self.phase in ("countdown", "round", "results", "lightning")

    @property
    def joinable(self) -> bool:
        # On ne rejoint pas en cours de partie un salon de paris (mise payée au départ) ni des
        # éliminatoires (tout le monde part à égalité).
        if (self.settings.betting or self.settings.elimination) and self.in_game:
            return False
        return len(self.players) < self.settings.max_players

    @property
    def pot(self) -> int:
        # Paris : mise × joueurs ; dotation : montant placé par l'hôte (un seul « staker »).
        if not self.stakers:
            return 0
        if self.settings.prize:
            return self.settings.stake
        return self.settings.stake * len(self.stakers)

    def connected_players(self) -> list[RoomPlayer]:
        return [p for p in self.players.values() if p.connected]

    def humans(self) -> list[RoomPlayer]:
        return [p for p in self.players.values() if not p.bot]


@dataclass
class Connection:
    client_id: str
    nickname: str
    websocket: WebSocket
    avatar_preset: int = 0
    avatar_url: str | None = None
    level: int = 1
    hair: str = ""
    hat: str = ""
    frame: str = ""
    name_style: str = ""
    # Langue de l'appli du joueur (il répond dans celle-ci) et pays d'origine (drapeau).
    language: str = "fr"
    country: str | None = None


class RoomError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def _nicknames_host_first(room: Room) -> list[str]:
    """L'hôte d'abord, puis les autres dans l'ordre d'arrivée."""
    players = list(room.players.values())
    host = room.players.get(room.host_id)
    if host is not None:
        players = [host, *[player for player in players if player is not host]]
    return [player.nickname for player in players]


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


class RoomManager:
    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession] = SessionLocal,
        presence: PresenceStore | None = None,
        timings: Timings | None = None,
    ):
        self.session_factory = session_factory
        self.presence = presence or RedisPresence()
        self.timings = timings or Timings()
        self.connections: dict[str, Connection] = {}
        self.rooms: dict[str, Room] = {}
        self._room_of: dict[str, str] = {}  # id client -> code de salle
        self._room_list_subscribers: dict[str, str | None] = {}  # id client -> filtre de langue
        self._expiry_tasks: dict[str, asyncio.Task] = {}
        self._online_count = 0
        self._presence_task: asyncio.Task | None = None

    # ------------------------------------------------------------- cycle de vie

    def start(self) -> None:
        self._presence_task = asyncio.create_task(self._presence_loop())
        self._purge_task = asyncio.create_task(self._purge_loop())

    async def _purge_loop(self) -> None:
        """Une fois par heure : salons sans activité depuis 30 jours supprimés."""
        while True:
            try:
                async with self.session_factory() as session:
                    await room_store.purge_inactive(session, keep=set(self.rooms))
                    await session.commit()
            except Exception:
                logger.exception("room purge failed")
            await asyncio.sleep(3600)

    async def stop(self) -> None:
        tasks = [self._presence_task, getattr(self, "_purge_task", None), *self._expiry_tasks.values()]
        for room in self.rooms.values():
            tasks += [room.game_task, room.quick_timer, room.bot_fill_timer]
        for task in tasks:
            if task:
                task.cancel()

    async def _presence_loop(self) -> None:
        while True:
            try:
                await self.presence.touch(list(self.connections))
                await self._refresh_online_count()
            except Exception:
                logger.exception("presence update failed")
            await asyncio.sleep(self.timings.presence_interval)

    async def _refresh_online_count(self) -> None:
        count = await self.presence.count()
        if count != self._online_count:
            self._online_count = count
            for client_id in list(self.connections):
                await self._send(client_id, {"type": "online_count", "count": count})

    # ---------------------------------------------------------------- connexions

    async def connect(
        self,
        websocket: WebSocket,
        client_id: str,
        nickname: str,
        language: str = "fr",
        country: str | None = None,
    ) -> Connection:
        previous = self.connections.get(client_id)
        if previous is not None:
            with contextlib.suppress(Exception):
                await previous.websocket.close(code=4000, reason="replaced")

        connection = Connection(client_id, nickname, websocket, language=language, country=country)
        # Profil lu avant d'enregistrer la connexion : « welcome » reste ainsi le premier message.
        wallet = None
        look = None
        try:
            async with self.session_factory() as session:
                profile = await wallet_service.get_profile(session, client_id, nickname)
                if country is not None and profile.country != country:
                    profile.country = country
                await session.commit()
            wallet = wallet_service.snapshot(profile).as_dict()
            look = wallet_service.look_of(profile)
            connection.avatar_preset = profile.avatar_preset
            connection.avatar_url = wallet_service.avatar_url(profile)
            connection.level = wallet_service.snapshot(profile).level
            connection.hair = profile.cosmetic_hair
            connection.hat = profile.cosmetic_hat
            connection.frame = profile.cosmetic_frame
            connection.name_style = profile.cosmetic_name
        except Exception:
            logger.exception("profile lookup failed for %s", client_id)
        self.connections[client_id] = connection
        if task := self._expiry_tasks.pop(client_id, None):
            task.cancel()

        await self.presence.touch([client_id])
        await self._send(
            client_id,
            {
                "type": "welcome",
                "online_count": await self.presence.count(),
                "wallet": wallet,
                "avatar": {"preset": connection.avatar_preset, "url": connection.avatar_url},
                "look": look,
            },
        )
        await self._refresh_online_count()

        room = self._current_room(client_id)
        if room is not None:
            player = room.players[client_id]
            player.connected = True
            player.hair = connection.hair
            player.hat = connection.hat
            player.frame = connection.frame
            player.name_style = connection.name_style
            await self._notice(room, "reconnected", player.nickname, exclude=client_id)
            await self._broadcast(room)
        return connection

    async def disconnect(self, connection: Connection) -> None:
        client_id = connection.client_id
        if self.connections.get(client_id) is not connection:
            return  # remplacée par une connexion plus récente
        del self.connections[client_id]
        self._room_list_subscribers.pop(client_id, None)
        with contextlib.suppress(Exception):
            await self.presence.remove(client_id)
            await self._refresh_online_count()

        room = self._current_room(client_id)
        if room is None:
            return
        player = room.players[client_id]
        player.connected = False
        await self._notice(room, "disconnected", player.nickname)
        await self._broadcast(room)
        self._check_all_in(room)
        self._expiry_tasks[client_id] = asyncio.create_task(self._expire(client_id))

    async def _expire(self, client_id: str) -> None:
        """Les joueurs qui ne reviennent pas à temps quittent leur salle."""
        await asyncio.sleep(self.timings.reconnect_grace)
        self._expiry_tasks.pop(client_id, None)
        room = self._current_room(client_id)
        if room is not None and not room.players[client_id].connected:
            await self._leave(client_id)

    # ------------------------------------------------------------------ messages

    async def handle(self, connection: Connection, message: dict) -> None:
        handlers = {
            "create_room": self._on_create_room,
            "join_room": self._on_join_room,
            "quick_match": self._on_quick_match,
            "leave_room": self._on_leave_room,
            "set_ready": self._on_set_ready,
            "submit": self._on_submit,
            "iq_answer": self._on_iq_answer,
            "hint": self._on_hint,
            "hint_pick": self._on_hint_pick,
            "buy_hint": self._on_buy_hint,
            "category_info": self._on_category_info,
            "freeze": self._on_freeze,
            "buy_freeze": self._on_buy_freeze,
            "react": self._on_react,
            "unlock_chat": self._on_unlock_chat,
            "chat": self._on_chat,
            "dm": self._on_dm,
            "rematch_vote": self._on_rematch_vote,
            "lightning_pick": self._on_lightning_pick,
            "start_bonus": self._on_start_bonus,
            "add_bot": self._on_add_bot,
            "remove_bot": self._on_remove_bot,
            "report_player": self._on_report_player,
            "subscribe_rooms": self._on_subscribe_rooms,
            "unsubscribe_rooms": self._on_unsubscribe_rooms,
            "voice_join": self._on_voice_join,
            "voice_mute": self._on_voice_mute,
            "voice_mute_all": self._on_voice_mute_all,
            "voice_exclude": self._on_voice_exclude,
            "ping": self._on_ping,
        }
        handler = handlers.get(message.get("type")) if isinstance(message, dict) else None
        if handler is None:
            await self._error(connection.client_id, "invalid_message")
            return
        try:
            await handler(connection, message)
        except RoomError as error:
            await self._error(connection.client_id, error.code)

    async def _on_ping(self, connection: Connection, message: dict) -> None:
        await self._send(connection.client_id, {"type": "pong"})

    async def _on_create_room(self, connection: Connection, message: dict) -> None:
        try:
            settings = RoomSettings.model_validate(message.get("settings") or {})
        except ValidationError:
            raise RoomError("invalid_settings") from None
        bots = message.get("bots") if isinstance(message.get("bots"), dict) else {}
        try:
            bot_count = min(int(bots.get("count", 0)), settings.max_players - 1)
            bot_level = Difficulty(bots.get("level", Difficulty.NORMAL))
        except (TypeError, ValueError):
            raise RoomError("invalid_settings") from None
        if settings.betting:
            if bot_count > 0:
                raise RoomError("bots_not_allowed")
            await self._require_coins(connection.client_id, settings.stake)
        elif settings.prize:
            # Dotation : seul l'hôte doit avoir les pièces ; les bots sont OK.
            await self._require_coins(connection.client_id, settings.stake)

        await self._leave(connection.client_id)
        room = self._new_room(settings, quick=False, host=connection, code=await self._free_code())
        room.creator_id = connection.client_id
        async with self.session_factory() as session:
            await room_store.save_room(
                session,
                room.code,
                connection.client_id,
                connection.nickname,
                settings.public,
                settings.language,
                settings.model_dump(mode="json"),
            )
            await session.commit()
        await self._add_player(room, connection)
        if bot_count > 0:
            # Partie contre l'ordinateur : on démarre tout de suite.
            for _ in range(bot_count):
                self._add_bot(room, bot_level)
            room.players[connection.client_id].ready = True
            await self._broadcast(room)
            await self._maybe_start(room)

    async def _on_join_room(self, connection: Connection, message: dict) -> None:
        code = str(message.get("code", "")).strip().upper()
        room = self.rooms.get(code) or await self._reopen(code, connection)
        if room is None:
            raise RoomError("room_not_found")
        if connection.client_id in room.players:
            await self._broadcast(room)
            return
        if not room.joinable:
            raise RoomError("game_in_progress" if room.in_game else "room_full")
        if room.settings.betting:
            await self._require_coins(connection.client_id, room.settings.stake)
        await self._leave(connection.client_id)
        await self._add_player(room, connection)

    async def _on_quick_match(self, connection: Connection, message: dict) -> None:
        try:
            language = Language(message.get("language", "fr"))
        except ValueError:
            raise RoomError("invalid_settings") from None
        await self._leave(connection.client_id)

        candidates = [
            r
            for r in self.rooms.values()
            # Toutes langues mélangées : chacun répond dans la sienne.
            if r.quick and r.phase == "waiting" and r.joinable
        ]
        # Rejoint la salle la plus remplie pour que la partie démarre plus vite.
        room = max(candidates, key=lambda r: len(r.players), default=None)
        if room is None:
            room = self._new_room(RoomSettings(language=language, public=True), quick=True, host=connection)
        await self._add_player(room, connection)

    async def _on_leave_room(self, connection: Connection, message: dict) -> None:
        await self._leave(connection.client_id)
        await self._send(connection.client_id, {"type": "left_room"})

    async def _on_set_ready(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        # Fin de partie : le prêt classique vote aussi pour la revanche.
        if room.phase == "finished":
            await self._cast_rematch_vote(room, connection.client_id, True)
            return
        if room.phase != "waiting":
            raise RoomError("game_in_progress")
        room.players[connection.client_id].ready = bool(message.get("ready", True))
        if room.quick:
            self._schedule_quick_start(room)
        await self._broadcast(room)
        await self._maybe_start(room)

    async def _on_rematch_vote(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        if room.phase != "finished":
            raise RoomError("game_in_progress")
        await self._cast_rematch_vote(room, connection.client_id, bool(message.get("vote", True)))

    async def _cast_rematch_vote(self, room: Room, client_id: str, vote: bool) -> None:
        player = room.players.get(client_id)
        if player is None or player.bot:
            raise RoomError("invalid_message")
        player.rematch_vote = vote
        humans = [p for p in room.humans() if p.connected]
        votes = sum(1 for p in humans if p.rematch_vote)
        need = max(1, (len(humans) + 1) // 2)  # majorité stricte (ceil)
        await self._broadcast(room)
        if votes >= need and humans:
            self._reset_to_lobby(room)
            for p in room.players.values():
                p.ready = room.quick or p.bot or p.rematch_vote
                p.rematch_vote = False
            await self._broadcast(room)
            await self._rooms_changed()
            if room.settings.public and room.joinable:
                await self._announce_public_room(room)
            await self._maybe_start(room)

    async def _on_submit(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        live = room.live_round
        client_id = connection.client_id
        try:
            round_number = int(message.get("round"))
        except (TypeError, ValueError):
            round_number = -1
        if (
            room.phase != "round"
            or live is None
            or round_number != live.number
            or client_id not in live.participants
        ):
            raise RoomError("round_not_current")
        if client_id in live.submissions:
            raise RoomError("round_already_submitted")

        now = utcnow()
        if now > live.ends_at + timedelta(seconds=self.timings.submit_grace):
            raise RoomError("round_over")
        until = live.frozen_until.get(client_id)
        if until is not None and now < until:
            raise RoomError("frozen")

        raw = message.get("answers") if isinstance(message.get("answers"), dict) else {}
        answers: dict[Category, str] = {}
        allowed = set(live.assignments.get(client_id) or [c.value for c in room.settings.categories])
        for key, value in raw.items():
            if key not in allowed:
                continue
            with contextlib.suppress(ValueError):
                answers[Category(key)] = str(value)[:100]
        live.submissions[client_id] = (now, answers)

        await self._broadcast(room)
        self._check_all_in(room)

    def _hintable_round(self, room: Room, client_id: str, message: dict) -> tuple[LiveRound, str]:
        live = room.live_round
        if (
            room.phase != "round"
            or live is None
            or message.get("round") != live.number
            or client_id not in live.participants
            or client_id in live.submissions
        ):
            raise RoomError("round_not_current")
        category = message.get("category")
        if category not in [c.value for c in room.settings.categories]:
            raise RoomError("invalid_category")
        return live, category

    async def _on_hint(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        live, category = self._hintable_round(room, connection.client_id, message)
        player = room.players[connection.client_id]
        mine = live.hints.setdefault(connection.client_id, {})
        reveal = bool(message.get("reveal"))

        hint = mine.get(category)
        if hint is None:
            if player.hints_used >= HINTS_PER_GAME + player.bonus_hints:
                raise RoomError("no_hints_left")
            try:
                async with self.session_factory() as session:
                    hint = await hint_service.build_hint(
                        session, player.language, category, live.letter
                    )
            except hint_service.NoHintAvailable:
                raise RoomError("no_hint_available") from None
            if reveal:
                hint = hint_service.Hint(
                    category=hint.category,
                    options=[hint.answer],
                    answer=hint.answer,
                    picked=hint.answer,
                )
            mine[category] = hint
            player.hints_used += 1
            # Tout le salon voit qu'un joker vient d'être utilisé.
            await self._notice(
                room,
                "hint_used",
                player.nickname,
                detail=category,
                exclude=None,
            )
        elif reveal and hint.picked is None:
            hint.options = [hint.answer]
            hint.picked = hint.answer
        revealed = bool(reveal and hint.picked == hint.answer)
        await self._send(
            connection.client_id,
            {
                "type": "hint",
                "round": live.number,
                "category": category,
                "options": hint.options,
                "hints_left": HINTS_PER_GAME + player.bonus_hints - player.hints_used,
                "revealed": revealed,
                "answer": hint.answer if revealed else None,
            },
        )

    async def _on_buy_hint(self, connection: Connection, message: dict) -> None:
        """Achète un joker supplémentaire avec des pièces (pendant la manche)."""
        room = self._require_room(connection.client_id)
        live = room.live_round
        if room.phase != "round" or live is None or connection.client_id not in live.participants:
            raise RoomError("round_not_current")
        if connection.client_id in live.submissions:
            raise RoomError("round_not_current")
        player = room.players[connection.client_id]
        if player.bot:
            raise RoomError("invalid_message")
        async with self.session_factory() as session:
            try:
                profile = await wallet_service.debit(
                    session, connection.client_id, EXTRA_HINT_PRICE, "extra_hint", room.code
                )
            except wallet_service.WalletError as error:
                raise RoomError(error.code) from None
            await session.commit()
            wallet = wallet_service.snapshot(profile)
        player.bonus_hints += 1
        await self._send(
            connection.client_id,
            {
                "type": "hint_bought",
                "hints_left": HINTS_PER_GAME + player.bonus_hints - player.hints_used,
                "price": EXTRA_HINT_PRICE,
                "wallet": wallet.as_dict(),
            },
        )
        await self._broadcast(room)

    async def _on_category_info(self, connection: Connection, message: dict) -> None:
        """Infos payantes sur une catégorie après la manche."""
        room = self._require_room(connection.client_id)
        if room.phase != "results" or room.results is None:
            raise RoomError("round_not_finished")
        category = message.get("category")
        if category not in [c.value for c in room.settings.categories]:
            raise RoomError("invalid_category")
        if category not in {c.value for c in fact_service.INFO_CATEGORIES}:
            raise RoomError("no_info_available")
        mine = next(
            (p for p in room.results["players"] if p["client_id"] == connection.client_id),
            None,
        )
        if mine is None:
            raise RoomError("round_not_finished")
        answer = next((a for a in mine["answers"] if a["category"] == category), None)
        if answer is None:
            raise RoomError("invalid_category")
        word = fact_service.info_word(
            answer.get("matched_value"), answer.get("suggestion"), answer.get("value") or ""
        )
        asker = room.players.get(connection.client_id)
        lines = fact_service.lookup_lines(category, word, asker.language if asker else room.settings.language)
        unlock = fact_service.unlock_id(category, word)
        if not lines or unlock is None:
            raise RoomError("no_info_available")
        async with self.session_factory() as session:
            profile = await wallet_service.get_profile(session, connection.client_id)
            if wallet_service.has_fact_unlocked(profile, unlock):
                price = 0
            else:
                price = fact_service.info_price(answer.get("status") or "")
                try:
                    profile = await wallet_service.debit(
                        session,
                        connection.client_id,
                        price,
                        "category_info",
                        unlock[:64],
                    )
                except wallet_service.WalletError as error:
                    raise RoomError(error.code) from None
                wallet_service.unlock_fact(profile, unlock)
            await session.commit()
            wallet = wallet_service.snapshot(profile)
        # Met à jour le résultat en mémoire pour ce joueur.
        answer["info_unlocked"] = True
        answer["info_price"] = 0
        answer["info_lines"] = lines
        await self._send(
            connection.client_id,
            {
                "type": "category_info",
                "category": category,
                "word": word,
                "lines": lines,
                "price": price,
                "wallet": wallet.as_dict(),
            },
        )

    async def _on_freeze(self, connection: Connection, message: dict) -> None:
        """Gèle un adversaire 10 s. Coût : 1 charge (1 gratuite / partie)."""
        room = self._require_room(connection.client_id)
        live = room.live_round
        me = connection.client_id
        if room.phase != "round" or live is None or me not in live.participants:
            raise RoomError("round_not_current")
        if me in live.submissions:
            raise RoomError("round_not_current")
        player = room.players[me]
        if player.bot or player.freezes_left < 1:
            raise RoomError("no_freezes_left")
        target_id = str(message.get("target") or "")
        target = room.players.get(target_id)
        if (
            target is None
            or target_id == me
            or target_id not in live.participants
            or target_id in live.submissions
            or target.eliminated_round is not None
        ):
            raise RoomError("invalid_target")
        now = utcnow()
        if live.frozen_until.get(target_id) and live.frozen_until[target_id] > now:
            raise RoomError("already_frozen")
        player.freezes_left -= 1
        live.frozen_until[target_id] = now + timedelta(seconds=FREEZE_SECONDS)
        await self._broadcast(room)
        await self._send(
            me,
            {
                "type": "freeze_ok",
                "target": target_id,
                "freezes_left": player.freezes_left,
                "until": live.frozen_until[target_id].isoformat(),
            },
        )

    async def _on_buy_freeze(self, connection: Connection, message: dict) -> None:
        """Acheter une charge Freeze supplémentaire."""
        room = self._require_room(connection.client_id)
        if room.phase not in ("waiting", "countdown", "round", "results", "finished"):
            raise RoomError("invalid_message")
        player = room.players[connection.client_id]
        if player.bot:
            raise RoomError("invalid_message")
        async with self.session_factory() as session:
            try:
                profile = await wallet_service.debit(
                    session, connection.client_id, FREEZE_PRICE, "buy_freeze", room.code
                )
            except wallet_service.WalletError as error:
                raise RoomError(error.code) from None
            await session.commit()
            wallet = wallet_service.snapshot(profile)
        player.freezes_left += 1
        await self._send(
            connection.client_id,
            {
                "type": "freeze_bought",
                "freezes_left": player.freezes_left,
                "price": FREEZE_PRICE,
                "wallet": wallet.as_dict(),
            },
        )
        await self._broadcast(room)

    async def _on_react(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        if room.phase not in ("results", "finished", "lightning"):
            raise RoomError("round_not_finished")
        sticker = str(message.get("sticker") or "")
        if sticker not in STICKER_IDS:
            raise RoomError("invalid_message")
        player = room.players[connection.client_id]
        room.reactions.append(
            Reaction(connection.client_id, player.nickname, sticker, utcnow())
        )
        await self._broadcast(room)

    async def _on_unlock_chat(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        player = room.players[connection.client_id]
        if player.bot:
            raise RoomError("invalid_message")
        if player.chat_unlocked:
            await self._send(
                connection.client_id,
                {"type": "chat_unlocked", "price": 0, "wallet": None},
            )
            return
        async with self.session_factory() as session:
            try:
                profile = await wallet_service.debit(
                    session, connection.client_id, CHAT_UNLOCK_PRICE, "chat_unlock", room.code
                )
            except wallet_service.WalletError as error:
                raise RoomError(error.code) from None
            await session.commit()
            wallet = wallet_service.snapshot(profile)
        player.chat_unlocked = True
        if room.creator_id is not None:
            async with self.session_factory() as session:
                await room_store.unlock_private(session, room.code, connection.client_id)
                await session.commit()
        await self._send(
            connection.client_id,
            {
                "type": "chat_unlocked",
                "price": CHAT_UNLOCK_PRICE,
                "wallet": wallet.as_dict(),
            },
        )
        await self._broadcast(room)

    async def _on_chat(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        if room.phase == "round":
            raise RoomError("game_in_progress")
        player = room.players[connection.client_id]
        # Conversation de groupe gratuite ; seuls les messages privés se débloquent en pièces.
        if player.bot:
            raise RoomError("invalid_message")
        text = " ".join(str(message.get("text") or "").split())[:CHAT_MESSAGE_MAX]
        if not text:
            raise RoomError("invalid_message")
        mentions: list[str] = []
        if room.creator_id is not None:
            async with self.session_factory() as session:
                mentions = await room_store.mentions_in(session, room.code, text)
                await room_store.add_message(session, room.code, connection.client_id, player.nickname, text, mentions=mentions)
                await session.commit()
        room.chat.append(ChatMessage(connection.client_id, player.nickname, text, utcnow(), mentions))
        await self._broadcast(room)
        for client_id in mentions:
            if client_id != connection.client_id:
                await self._send(
                    client_id,
                    {"type": "mention", "room": room.code, "from": player.nickname, "text": text},
                )

    async def _on_dm(self, connection: Connection, message: dict) -> None:
        """Message privé à un autre membre du salon (débloqué en pièces)."""
        room = self._require_room(connection.client_id)
        player = room.players[connection.client_id]
        if room.creator_id is None or player.bot:
            raise RoomError("invalid_message")
        if not player.chat_unlocked:
            raise RoomError("chat_locked")
        to = str(message.get("to") or "")
        text = " ".join(str(message.get("text") or "").split())[:CHAT_MESSAGE_MAX]
        if not text or not to or to == connection.client_id:
            raise RoomError("invalid_message")
        async with self.session_factory() as session:
            if not await room_store.is_member(session, room.code, to):
                raise RoomError("invalid_message")
            saved = await room_store.add_message(
                session, room.code, connection.client_id, player.nickname, text, recipient_id=to
            )
            await session.commit()
        payload = {"type": "dm", "room": room.code, "message": room_store.message_dict(saved)}
        await self._send(connection.client_id, payload)
        await self._send(to, payload)

    async def _on_lightning_pick(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        challenge = room.lightning
        if room.phase != "lightning" or challenge is None:
            raise RoomError("round_not_current")
        if utcnow() > challenge.ends_at:
            raise RoomError("round_over")
        choice = str(message.get("choice") or "")
        if choice not in challenge.options:
            raise RoomError("invalid_message")
        player = room.players.get(connection.client_id)
        if player is None or player.bot:
            raise RoomError("invalid_message")
        already = connection.client_id in challenge.picks
        points = score_lightning(challenge, connection.client_id, choice)
        if points and not already:
            player.score += points
        await self._broadcast(room)

    async def _on_start_bonus(self, connection: Connection, message: dict) -> None:
        """L'hôte (ou n'importe qui en revanche) lance la mini-manche bonus."""
        room = self._require_room(connection.client_id)
        if room.settings.iq:
            # La mini-manche bonus est une manche de lettres.
            raise RoomError("invalid_message")
        if room.phase != "finished" or room.bonus_played or room.game_task:
            raise RoomError("game_in_progress")
        if connection.client_id != room.host_id and not room.players[connection.client_id].rematch_vote:
            # Tout humain connecté peut lancer le bonus une fois.
            pass
        if len(room.connected_players()) < MIN_ROOM_PLAYERS:
            raise RoomError("not_enough_players")
        room.bonus_played = True
        room.game_task = asyncio.create_task(self._run_bonus_round(room))

    async def _on_hint_pick(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        live, category = self._hintable_round(room, connection.client_id, message)
        hint = live.hints.get(connection.client_id, {}).get(category)
        if hint is None:
            raise RoomError("no_hint_requested")
        if hint.picked is not None:
            raise RoomError("hint_already_picked")
        if message.get("choice") not in hint.options:
            raise RoomError("invalid_choice")
        hint.picked = message["choice"]
        await self._send(
            connection.client_id,
            {
                "type": "hint_result",
                "round": live.number,
                "category": category,
                "correct": hint.correct,
                "answer": hint.answer,
            },
        )

    async def _on_add_bot(self, connection: Connection, message: dict) -> None:
        room = self._require_host(connection.client_id)
        if room.quick or room.phase != "waiting":
            raise RoomError("game_in_progress")
        if room.settings.betting:
            raise RoomError("bots_not_allowed")
        if not room.joinable:
            raise RoomError("room_full")
        try:
            level = Difficulty(message.get("level", Difficulty.NORMAL))
        except ValueError:
            raise RoomError("invalid_settings") from None
        bot = self._add_bot(room, level)
        await self._notice(room, "joined", bot.nickname)
        await self._broadcast(room)
        await self._rooms_changed()
        await self._maybe_start(room)

    async def _on_remove_bot(self, connection: Connection, message: dict) -> None:
        room = self._require_host(connection.client_id)
        if room.phase != "waiting":
            raise RoomError("game_in_progress")
        bot = room.players.get(str(message.get("client_id", "")))
        if bot is None or not bot.bot:
            raise RoomError("not_a_bot")
        del room.players[bot.client_id]
        await self._notice(room, "left", bot.nickname)
        await self._broadcast(room)
        await self._rooms_changed()

    async def _on_report_player(self, connection: Connection, message: dict) -> None:
        """Signale la photo d'un autre joueur de la salle."""
        room = self._require_room(connection.client_id)
        reported = str(message.get("client_id", ""))
        player = room.players.get(reported)
        if player is None or player.bot or reported == connection.client_id:
            raise RoomError("invalid_message")
        async with self.session_factory() as session:
            hidden = await wallet_service.report_avatar(session, connection.client_id, reported)
            await session.commit()
            preset = (await wallet_service.get_profile(session, reported)).avatar_preset
        await self._send(connection.client_id, {"type": "reported", "client_id": reported})
        if hidden:
            await self.update_avatar(reported, preset, None)

    async def update_avatar(self, client_id: str, preset: int, url: str | None) -> None:
        """Nouvel avatar d'un joueur : mis à jour sur sa connexion et dans sa salle."""
        if connection := self.connections.get(client_id):
            connection.avatar_preset, connection.avatar_url = preset, url
        room = self._current_room(client_id)
        if room is not None and client_id in room.players:
            room.players[client_id].avatar_preset = preset
            room.players[client_id].avatar_url = url
            await self._broadcast(room)

    async def update_look(
        self,
        client_id: str,
        *,
        hair: str,
        hat: str,
        frame: str,
        name_style: str,
    ) -> None:
        """Apparences visibles tout de suite par la salle."""
        if connection := self.connections.get(client_id):
            connection.hair = hair
            connection.hat = hat
            connection.frame = frame
            connection.name_style = name_style
        room = self._current_room(client_id)
        if room is not None and client_id in room.players:
            player = room.players[client_id]
            player.hair = hair
            player.hat = hat
            player.frame = frame
            player.name_style = name_style
            await self._broadcast(room)

    async def _on_subscribe_rooms(self, connection: Connection, message: dict) -> None:
        language = message.get("language")
        self._room_list_subscribers[connection.client_id] = language if language in list(Language) else None
        await self._send_room_list(connection.client_id)

    async def _on_unsubscribe_rooms(self, connection: Connection, message: dict) -> None:
        self._room_list_subscribers.pop(connection.client_id, None)

    def _voice_is_open(self, room: Room) -> bool:
        """Vocal dispo dès le compte à rebours jusqu'au podium (pas en lobby)."""
        return room.phase in (
            "countdown",
            "round",
            "results",
            "lightning",
            "finished",
        )

    async def _on_voice_join(self, connection: Connection, message: dict) -> None:
        """Token Agora pour rejoindre le salon vocal pendant la partie."""
        room = self._require_room(connection.client_id)
        if not voice_service.voice_enabled():
            raise RoomError("voice_unavailable")
        if not self._voice_is_open(room):
            raise RoomError("voice_closed")
        if connection.client_id in room.voice_excluded:
            raise RoomError("voice_excluded")
        player = room.players.get(connection.client_id)
        if player is None or player.bot:
            raise RoomError("invalid_message")
        token = voice_service.build_token(room.code, connection.client_id)
        if not token:
            raise RoomError("voice_unavailable")
        await self._send(
            connection.client_id,
            {
                "type": "voice_credentials",
                "app_id": voice_service.agora_app_id(),
                "channel": room.code,
                "token": token,
                "uid": voice_service.uid_for(connection.client_id),
                "muted": connection.client_id in room.voice_muted,
            },
        )

    async def _on_voice_mute(self, connection: Connection, message: dict) -> None:
        """L'hôte coupe / rétablit le micro d'un joueur."""
        room = self._require_host(connection.client_id)
        if not self._voice_is_open(room):
            raise RoomError("voice_closed")
        target = str(message.get("client_id", ""))
        player = room.players.get(target)
        if player is None or player.bot or target == room.host_id:
            raise RoomError("invalid_message")
        muted = bool(message.get("muted", True))
        if muted:
            room.voice_muted.add(target)
        else:
            room.voice_muted.discard(target)
        await self._broadcast(room)
        await self._send(
            target,
            {"type": "voice_force_mute", "muted": muted},
        )

    async def _on_voice_mute_all(self, connection: Connection, message: dict) -> None:
        """L'hôte coupe ou rétablit le micro de tous les joueurs (sauf lui)."""
        room = self._require_host(connection.client_id)
        if not self._voice_is_open(room):
            raise RoomError("voice_closed")
        muted = bool(message.get("muted", True))
        targets: list[str] = []
        for cid, player in room.players.items():
            if player.bot or cid == room.host_id:
                continue
            if cid in room.voice_excluded:
                continue
            if muted:
                room.voice_muted.add(cid)
            else:
                room.voice_muted.discard(cid)
            targets.append(cid)
        await self._broadcast(room)
        for cid in targets:
            await self._send(cid, {"type": "voice_force_mute", "muted": muted})

    async def _on_voice_exclude(self, connection: Connection, message: dict) -> None:
        """L'hôte exclut un joueur du salon vocal jusqu'à la prochaine manche."""
        room = self._require_host(connection.client_id)
        if not self._voice_is_open(room):
            raise RoomError("voice_closed")
        target = str(message.get("client_id", ""))
        player = room.players.get(target)
        if player is None or player.bot or target == room.host_id:
            raise RoomError("invalid_message")
        room.voice_excluded.add(target)
        room.voice_muted.discard(target)
        await self._broadcast(room)
        await self._send(target, {"type": "voice_kicked"})

    # --------------------------------------------------------------------- salles

    async def _free_code(self) -> str:
        """Code libre en mémoire et parmi les salons gardés en base."""
        async with self.session_factory() as session:
            while True:
                code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
                if code not in self.rooms and not await room_store.code_taken(session, code):
                    return code

    async def _reopen(self, code: str, connection: Connection) -> Room | None:
        """Salon fermé (plus personne dedans) : on le rouvre avec ses réglages et sa conversation."""
        if not code:
            return None
        async with self.session_factory() as session:
            saved = await room_store.get_room(session, code)
            if saved is None:
                return None
            messages = await room_store.group_messages(session, code, CHAT_HISTORY)
        try:
            settings = RoomSettings.model_validate(saved.settings)
        except ValidationError:
            settings = RoomSettings(language=saved.language, public=saved.public)
        room = Room(code=code, settings=settings, quick=False, host_id=connection.client_id)
        room.creator_id = saved.creator_id
        for m in messages:
            room.chat.append(ChatMessage(m.sender_id, m.sender_nickname, m.text, m.created_at, list(m.mentions or [])))
        self.rooms[code] = room
        return room

    def _new_room(self, settings: RoomSettings, quick: bool, host: Connection, code: str | None = None) -> Room:
        while code is None or code in self.rooms:
            code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
        room = Room(code=code, settings=settings, quick=quick, host_id=host.client_id)
        self.rooms[code] = room
        return room

    def _add_bot(self, room: Room, level: Difficulty) -> RoomPlayer:
        taken = {p.nickname for p in room.players.values()}
        bot = RoomPlayer(
            client_id=f"bot-{secrets.token_hex(4)}",
            nickname=bot_service.bot_name(taken),
            ready=True,
            bot_level=level,
            # Les bots répondent dans la langue du salon.
            language=room.settings.language,
        )
        room.players[bot.client_id] = bot
        return bot

    async def _add_player(self, room: Room, connection: Connection) -> None:
        room.players[connection.client_id] = RoomPlayer(
            client_id=connection.client_id,
            nickname=connection.nickname,
            ready=room.quick,
            avatar_preset=connection.avatar_preset,
            avatar_url=connection.avatar_url,
            level=connection.level,
            hair=connection.hair,
            hat=connection.hat,
            frame=connection.frame,
            name_style=connection.name_style,
            language=connection.language,
            country=connection.country,
        )
        self._room_of[connection.client_id] = room.code
        if room.creator_id is not None:
            # Salon gardé : le joueur le retrouvera dans « Mes salons » ; son déblocage des
            # messages privés le suit ; le créateur redevient l'hôte.
            async with self.session_factory() as session:
                member = await room_store.join(session, room.code, connection.client_id, connection.nickname)
                await session.commit()
            if member is not None and member.private_unlocked:
                room.players[connection.client_id].chat_unlocked = True
            if connection.client_id == room.creator_id:
                room.host_id = connection.client_id
        if room.quick:
            self._schedule_quick_start(room)
        await self._notice(room, "joined", connection.nickname, exclude=connection.client_id)
        await self._broadcast(room)
        await self._rooms_changed()
        # Salon public en attente : tous les connectés sont prévenus (rejoindre sans code).
        if room.settings.public and room.phase == "waiting" and room.joinable and not room.quick:
            await self._announce_public_room(room)

    async def _leave(self, client_id: str) -> None:
        room = self._current_room(client_id)
        if room is None:
            return
        player = room.players.pop(client_id)
        self._room_of.pop(client_id, None)

        if not room.humans():
            await self._close_room(room)
            return
        if room.host_id == client_id:
            room.host_id = room.humans()[0].client_id
        if room.quick:
            self._schedule_quick_start(room)
        # « left » → snackbar rouge côté clients (salon / éliminatoires).
        await self._notice(room, "left", player.nickname)
        await self._broadcast(room)
        await self._rooms_changed()
        self._check_all_in(room)
        await self._maybe_start(room)

    async def _close_room(self, room: Room) -> None:
        tasks = [room.game_task, room.quick_timer, room.bot_fill_timer]
        if room.live_round:
            tasks += room.live_round.bot_tasks
        for task in tasks:
            if task and task is not asyncio.current_task():
                task.cancel()
        self.rooms.pop(room.code, None)
        await self._rooms_changed()

    def _reset_to_lobby(self, room: Room) -> None:
        room.phase = "waiting"
        room.game_id = None
        room.round_number = 0
        room.live_round = None
        room.results = None
        room.go_at = room.next_round_at = None
        room.stakers = []
        room.winnings = {}
        room.lightning = None
        room.results_history = []
        room.word_review = []
        room.bonus_played = False
        room.reactions.clear()
        room.voice_muted.clear()
        room.voice_excluded.clear()
        for player in room.players.values():
            player.score = 0
            player.ready = room.quick or player.bot
            player.db_player_id = None
            player.hints_used = 0
            player.bonus_hints = 0
            player.freezes_left = 0
            player.rematch_vote = False
            player.title = ""
            player.eliminated_round = None
            # chat_unlocked : reste pour la session dans la salle

    def _current_room(self, client_id: str) -> Room | None:
        code = self._room_of.get(client_id)
        return self.rooms.get(code) if code else None

    def _require_room(self, client_id: str) -> Room:
        room = self._current_room(client_id)
        if room is None:
            raise RoomError("not_in_room")
        return room

    def _require_host(self, client_id: str) -> Room:
        room = self._require_room(client_id)
        if room.host_id != client_id:
            raise RoomError("not_host")
        return room

    # ------------------------------------------------------- démarrage de partie

    async def _maybe_start(self, room: Room) -> None:
        if room.quick or room.phase != "waiting":
            return
        connected = room.connected_players()
        if len(connected) >= MIN_ROOM_PLAYERS and all(p.ready for p in connected):
            self._start_game(room)

    def _schedule_quick_start(self, room: Room) -> None:
        if room.phase != "waiting":
            return
        count = len(room.players)
        if count >= MIN_ROOM_PLAYERS and room.bot_fill_timer:
            room.bot_fill_timer.cancel()
            room.bot_fill_timer = None
        if count >= room.settings.max_players:
            self._cancel_quick_timer(room)
            self._start_game(room)
        elif count >= MIN_ROOM_PLAYERS:
            if room.quick_timer is None:
                room.starts_at = utcnow() + timedelta(seconds=self.timings.quick_start)
                room.quick_timer = asyncio.create_task(self._quick_start_later(room))
        else:
            self._cancel_quick_timer(room)
            if count == 1 and room.bot_fill_timer is None:
                room.bot_fill_timer = asyncio.create_task(self._fill_with_bots_later(room))

    def _cancel_quick_timer(self, room: Room) -> None:
        if room.quick_timer and room.quick_timer is not asyncio.current_task():
            room.quick_timer.cancel()
        room.quick_timer = None
        room.starts_at = None

    async def _fill_with_bots_later(self, room: Room) -> None:
        """Personne d'autre en ligne : des bots rejoignent la partie pour que le joueur n'attende pas.
        """
        await asyncio.sleep(self.timings.quick_bot_fill)
        room.bot_fill_timer = None
        if room.phase != "waiting" or len(room.players) != 1 or room.code not in self.rooms:
            return
        for _ in range(self.timings.quick_bot_count):
            self._add_bot(room, room.settings.difficulty)
        await self._notice(room, "bots_joined", "")
        self._start_game(room)
        await self._broadcast(room)

    async def _quick_start_later(self, room: Room) -> None:
        await asyncio.sleep(self.timings.quick_start)
        room.quick_timer = None
        room.starts_at = None
        if room.phase == "waiting" and len(room.players) >= MIN_ROOM_PLAYERS:
            self._start_game(room)

    def _start_game(self, room: Room) -> None:
        room.phase = "countdown"
        room.game_task = asyncio.create_task(self._run_game(room))

    # ------------------------------------------------------- boucle de la partie

    async def _run_game(self, room: Room) -> None:
        try:
            await self._rooms_changed()
            if room.settings.betting and not await self._collect_stakes(room):
                return
            if room.settings.prize and not await self._collect_prize(room):
                return
            mode = "duel" if room.settings.max_players == 2 else "multiplayer"
            async with self.session_factory() as session:
                room.game_id, ids = await multiplayer_service.create_game(
                    session, mode, room.settings, {cid: p.nickname for cid, p in room.players.items()}
                )
            for client_id, player_id in ids.items():
                room.players[client_id].db_player_id = player_id
            await self._apply_pass_hints(room)

            # 1 Freeze gratuit par humain en début de partie.
            for player in room.players.values():
                player.freezes_left = 0 if player.bot else FREEZES_PER_GAME
                player.title = ""
                player.rematch_vote = False
            room.results_history = []
            room.bonus_played = False

            for number in range(1, room.settings.rounds + 1):
                await self._enrol_late_joiners(room)
                if len(room.connected_players()) < MIN_ROOM_PLAYERS:
                    break
                if room.settings.iq:
                    await self._play_iq_round(room, number)
                else:
                    await self._play_round(room, number)
                if number == room.settings.rounds:
                    break
                # Éliminatoires : la partie s'arrête quand il ne reste qu'un joueur en lice.
                if room.settings.elimination and len(self._alive(room)) <= 1:
                    break
                room.next_round_at = utcnow() + timedelta(seconds=self.timings.results)
                await self._broadcast(room)
                # Défi éclair pendant l'écran résultats, puis on enchaîne (pas en QI).
                if not room.settings.iq:
                    await self._run_lightning(room)
                remaining = (room.next_round_at - utcnow()).total_seconds()
                if remaining > 0:
                    await asyncio.sleep(remaining)

            async with self.session_factory() as session:
                await multiplayer_service.finish_game(session, room.game_id)
            await self._pay_winners(room)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("game loop failed in room %s", room.code)
            await self._notice(room, "error", "")
            await self._refund_stakes(room)
        finally:
            room.game_task = None

        self._finalize_social(room)
        await self._record_room_game(room)
        room.phase = "finished"
        room.live_round = None
        room.lightning = None
        room.go_at = room.next_round_at = None
        for player in room.players.values():
            player.ready = False
            player.rematch_vote = False
        await self._broadcast(room)
        await self._rooms_changed()

    async def _record_room_game(self, room: Room) -> None:
        """Classement final dans l'historique du salon (salons gardés seulement)."""
        if room.creator_id is None or room.round_number == 0:
            return
        def place(p: RoomPlayer) -> tuple:
            # Éliminatoires : les survivants d'abord, puis les éliminés du plus tardif au plus tôt.
            if room.settings.elimination:
                return (p.eliminated_round is not None, -(p.eliminated_round or 0), -p.score)
            return (-p.score, p.nickname)

        ranking = [
            {"client_id": p.client_id, "nickname": p.nickname, "score": p.score, "bot": p.bot}
            for p in sorted(room.players.values(), key=place)
        ]
        try:
            async with self.session_factory() as session:
                await room_store.record_game(
                    session,
                    room.code,
                    room.game_id,
                    "iq" if room.settings.iq else room.settings.format,
                    room.round_number,
                    ranking,
                )
                await session.commit()
        except Exception:
            logger.exception("could not record game of room %s", room.code)

    def _finalize_social(self, room: Room) -> None:
        """Titres de salon + revue des mots à la fin de partie."""
        if room.settings.iq:
            return
        ranking = sorted(
            [(p.client_id, p.score, p.nickname) for p in room.players.values()],
            key=lambda x: (-x[1], x[2]),
        )
        titles = compute_titles(room.results_history, ranking)
        for cid, title in titles.items():
            if cid in room.players:
                room.players[cid].title = title
        room.word_review = build_word_review(
            room.results_history,
            language=room.settings.language,
        )

    async def _run_lightning(self, room: Room) -> None:
        """QCM 10 s entre deux manches (points bonus)."""
        if room.phase != "results" or not room.results:
            return
        letter = room.results.get("letter") or "A"
        categories = [c.value for c in room.settings.categories]
        if not categories:
            return
        category = secrets.choice(categories)
        try:
            async with self.session_factory() as session:
                hint = await hint_service.build_hint(
                    session, room.settings.language, category, letter
                )
        except hint_service.NoHintAvailable:
            return
        saved_next = room.next_round_at
        ends = utcnow() + timedelta(seconds=LIGHTNING_SECONDS)
        room.lightning = LightningChallenge(
            letter=letter,
            category=category,
            options=list(hint.options),
            answer=hint.answer,
            ends_at=ends,
        )
        room.phase = "lightning"
        await self._broadcast(room)
        await asyncio.sleep(LIGHTNING_SECONDS)
        room.phase = "results"
        room.lightning = None
        room.next_round_at = saved_next
        await self._broadcast(room)

    async def _run_bonus_round(self, room: Room) -> None:
        """Mini-manche bonus post-podium (sans mise)."""
        try:
            cats = list(room.settings.categories)[:BONUS_CATEGORIES]
            if not cats:
                cats = list(room.settings.categories)
            # Réutilise le même game_id si encore valide, sinon crée une mini partie.
            async with self.session_factory() as session:
                settings = room.settings.model_copy(
                    update={
                        "rounds": 1,
                        "round_duration": BONUS_ROUND_DURATION,
                        "categories": cats,
                    }
                )
                room.game_id, ids = await multiplayer_service.create_game(
                    session,
                    "multiplayer",
                    settings,
                    {
                        cid: p.nickname
                        for cid, p in room.players.items()
                        if p.eliminated_round is None
                    },
                )
            for client_id, player_id in ids.items():
                room.players[client_id].db_player_id = player_id
            await self._play_round(room, 1, bonus=True)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("bonus round failed in room %s", room.code)
        finally:
            room.game_task = None
            self._finalize_social(room)
            room.phase = "finished"
            room.live_round = None
            await self._broadcast(room)

    async def _enrol_late_joiners(self, room: Room) -> None:
        for player in room.players.values():
            if player.db_player_id is None:
                async with self.session_factory() as session:
                    player.db_player_id = await multiplayer_service.add_player(
                        session, room.game_id, player.nickname
                    )

    async def _play_round(self, room: Room, number: int, *, bonus: bool = False) -> None:
        room.phase = "countdown"
        room.results = None
        room.lightning = None
        room.next_round_at = None
        room.go_at = utcnow() + timedelta(seconds=self.timings.countdown)
        await self._broadcast(room)
        await asyncio.sleep(self.timings.countdown)

        async with self.session_factory() as session:
            # Lettre jouable dans toutes les langues des joueurs encore en lice.
            languages = {
                p.language for p in room.players.values() if not p.bot and p.eliminated_round is None
            } or {room.settings.language}
            info = await multiplayer_service.start_round(session, room.game_id, languages)
        # Bonus : durée plus courte côté client (ends_at recalculé).
        ends_at = info.ends_at
        if bonus:
            ends_at = info.started_at + timedelta(seconds=BONUS_ROUND_DURATION)
        participants = {
            cid: p.db_player_id
            for cid, p in room.players.items()
            if p.eliminated_round is None and p.db_player_id
        }
        assignments: dict[str, list[str]] = {}
        if room.settings.relay:
            assignments = assign_relay_categories(
                list(room.settings.categories), list(participants)
            )
        room.round_number = number
        room.live_round = LiveRound(
            number=info.number,
            letter=info.letter,
            started_at=info.started_at,
            ends_at=ends_at,
            participants=participants,
            assignments=assignments,
            bonus=bonus,
        )
        room.phase = "round"
        room.go_at = None
        await self._broadcast(room)
        await self._launch_bots(room, room.live_round)

        timeout = (ends_at - utcnow()).total_seconds() + self.timings.submit_grace
        with contextlib.suppress(TimeoutError):
            await asyncio.wait_for(room.live_round.all_in.wait(), timeout=max(0.0, timeout))

        live = room.live_round
        for task in live.bot_tasks:
            task.cancel()
        # Les propositions de joker choisies remplacent ce qui a été tapé dans ces catégories.
        hints: dict[str, dict[str, bool]] = {}
        for cid, by_category in live.hints.items():
            picked = {c: h for c, h in by_category.items() if h.picked is not None}
            if not picked or cid not in live.participants:
                continue
            hints[live.participants[cid]] = {c: bool(h.correct) for c, h in picked.items()}
            if cid in live.submissions:
                submitted_at, answers = live.submissions[cid]
                live.submissions[cid] = (
                    submitted_at,
                    {**answers, **{Category(c): h.picked for c, h in picked.items()}},
                )
        async with self.session_factory() as session:
            outcome = await multiplayer_service.close_round(
                session,
                room.game_id,
                participants=list(live.participants.values()),
                submissions={live.participants[cid]: sub for cid, sub in live.submissions.items()},
                hints=hints,
                languages={
                    db_id: room.players[cid].language if cid in room.players else room.settings.language
                    for cid, db_id in live.participants.items()
                },
            )

        by_player_id = {p.db_player_id: p for p in room.players.values()}
        client_of = {db_id: cid for cid, db_id in live.participants.items()}
        unlocked_by_client: dict[str, set[str]] = {}
        async with self.session_factory() as session:
            for cid in live.participants:
                if room.players[cid].bot:
                    unlocked_by_client[cid] = set()
                    continue
                try:
                    profile = await wallet_service.get_profile(session, cid)
                    unlocked_by_client[cid] = wallet_service.unlocked_facts(profile)
                except wallet_service.WalletError:
                    unlocked_by_client[cid] = set()
        language = room.settings.language
        results = []
        for result in outcome.results:
            player = by_player_id.get(result.player_id)
            if player is not None:
                player.score += result.round_score
            cid = client_of[result.player_id]
            unlocked = unlocked_by_client.get(cid, set())
            results.append(
                {
                    "client_id": cid,
                    "nickname": player.nickname if player else "",
                    "answers": [
                        enrich_answer_dict(a, language=player.language if player else language, unlocked=unlocked)
                        for a in result.answers
                    ],
                    "round_score": result.round_score,
                    "elapsed_ms": result.elapsed_ms,
                }
            )
        # Thème du jour : ×2 sur les catégories du thème.
        theme_cats = {c.value for c in room.settings.theme_categories}
        if theme_cats:
            for row in results:
                player = room.players.get(row["client_id"])
                bonus_pts = 0
                for answer in row["answers"]:
                    if answer.get("category") in theme_cats and (answer.get("points") or 0) > 0:
                        extra = answer["points"]
                        answer["points"] = answer["points"] + extra
                        answer["theme_bonus"] = True
                        bonus_pts += extra
                row["round_score"] += bonus_pts
                if player is not None and bonus_pts:
                    player.score += bonus_pts

        # Relais : on ne compte que les catégories assignées (les autres à 0 déjà si non soumises).
        eliminated = self._eliminate(room, outcome.number, {r["client_id"]: r["round_score"] for r in results})
        room.results = {
            "number": outcome.number,
            "letter": outcome.letter,
            "players": results,
            "examples": outcome.examples,
            "examples_by_language": outcome.examples_by_language,
            "eliminated": eliminated,
            "bonus": bool(live and live.bonus),
            "assignments": dict(live.assignments) if live else {},
        }
        room.results_history.append(room.results)
        room.live_round = None
        room.phase = "results"
        await self._broadcast(room)
        await self._award_round_points(room, outcome.results, client_of)

    async def _apply_pass_hints(self, room: Room) -> None:
        """Abonnés au Pass : jokers en plus pour la partie."""
        humans = [p for p in room.players.values() if not p.bot and wallet_service.is_client_id(p.client_id)]
        if not humans:
            return
        async with self.session_factory() as session:
            for player in humans:
                profile = await session.get(Profile, player.client_id)
                player.bonus_hints += perks_service.bonus_hints_for(profile)

    def _alive(self, room: Room) -> list[RoomPlayer]:
        return [p for p in room.players.values() if p.eliminated_round is None]

    def _eliminate(self, room: Room, number: int, round_scores: dict[str, int]) -> list[str]:
        """Éliminatoires : le plus petit score de la manche sort (tous ceux à égalité).

        À 2 joueurs encore en lice, on n'élimine qu'à la dernière manche configurée —
        sinon la partie se termine après 1 manche (impression de « rejouer » trop tôt).
        Personne ne sort si tous les joueurs en lice ont le même score.
        """
        if not room.settings.elimination:
            return []
        alive = [p for p in self._alive(room) if p.client_id in round_scores]
        if len(alive) < 2:
            return []
        # Duel à 2 : jouer toutes les manches, élimination seulement en finale.
        if len(alive) == 2 and number < room.settings.rounds:
            return []
        lowest = min(round_scores[p.client_id] for p in alive)
        losers = [p for p in alive if round_scores[p.client_id] == lowest]
        if len(losers) == len(alive):
            return []
        for player in losers:
            player.eliminated_round = number
        return [p.client_id for p in losers]

    # ------------------------------------------------------------- pièces

    async def _require_coins(self, client_id: str, amount: int) -> None:
        async with self.session_factory() as session:
            try:
                profile = await wallet_service.get_profile(session, client_id)
            except wallet_service.WalletError as error:
                raise RoomError(error.code) from None
            await session.commit()
        if profile.coins < amount:
            raise RoomError("not_enough_coins")

    async def _send_wallets(self, updates: dict[str, wallet_service.WalletUpdate]) -> None:
        for client_id, update in updates.items():
            # Le niveau affiché dans la salle suit les points gagnés.
            if connection := self.connections.get(client_id):
                connection.level = update.level
            room = self._current_room(client_id)
            if room is not None and client_id in room.players:
                room.players[client_id].level = update.level
            await self._send(client_id, {"type": "wallet", **update.as_dict()})

    async def _award_round_points(self, room: Room, results: list, client_of: dict[str, str]) -> None:
        """Les points de la manche reviennent aux joueurs humains : 20 points font une pièce."""
        updates = {}
        async with self.session_factory() as session:
            for result in results:
                client_id = client_of[result.player_id]
                player = room.players.get(client_id)
                if player is None or player.bot or not wallet_service.is_client_id(client_id):
                    continue
                updates[client_id] = await wallet_service.award_points(
                    session, client_id, result.round_score, reference=room.game_id
                )
            await session.commit()
        await self._send_wallets(updates)

    async def _collect_stakes(self, room: Room) -> bool:
        """Prélève la mise de chaque joueur au départ d'un salon de paris.

        Tout ou rien : si un joueur n'a plus assez de pièces, personne n'est débité, il est renvoyé
        de la salle et les autres reviennent en attente.
        """
        stake = room.settings.stake
        humans = [p.client_id for p in room.humans()]
        broke = []
        async with self.session_factory() as session:
            for client_id in humans:
                try:
                    await wallet_service.debit(session, client_id, stake, "bet_stake", reference=room.code)
                except wallet_service.WalletError:
                    broke.append(client_id)
            if broke:
                await session.rollback()
            else:
                await session.commit()
                updates = {
                    cid: wallet_service.snapshot(await wallet_service.get_profile(session, cid))
                    for cid in humans
                }
        if broke:
            # Retour en attente : chacun doit se redéclarer prêt.
            room.phase = "waiting"
            for player in room.players.values():
                player.ready = False
            for client_id in broke:
                await self._error(client_id, "not_enough_coins")
                await self._leave(client_id)
                await self._send(client_id, {"type": "left_room"})
            if room.code in self.rooms:
                await self._broadcast(room)
                await self._rooms_changed()
            return False
        room.stakers = humans
        await self._send_wallets(updates)
        return True

    async def _collect_prize(self, room: Room) -> bool:
        """Prélève la dotation chez l'hôte uniquement ; le vainqueur la récupérera."""
        host_id = room.host_id
        if host_id not in room.players or room.players[host_id].bot:
            room.phase = "waiting"
            for player in room.players.values():
                player.ready = False
            await self._broadcast(room)
            return False
        stake = room.settings.stake
        async with self.session_factory() as session:
            try:
                await wallet_service.debit(session, host_id, stake, "prize_fund", reference=room.code)
            except wallet_service.WalletError:
                await session.rollback()
                room.phase = "waiting"
                for player in room.players.values():
                    player.ready = False
                await self._error(host_id, "not_enough_coins")
                await self._broadcast(room)
                return False
            await session.commit()
            updates = {
                host_id: wallet_service.snapshot(await wallet_service.get_profile(session, host_id))
            }
        room.stakers = [host_id]
        await self._send_wallets(updates)
        return True

    async def _pay_winners(self, room: Room) -> None:
        """Le meilleur score parmi les joueurs restés jusqu'au bout rafle le pot (partagé en cas
        d'égalité). Paris : qui quitte perd sa mise. Dotation : le vainqueur (humain) prend tout."""
        if not room.stakers:
            return
        if room.settings.prize:
            # Tous les humains encore en lice (ou tous s'ils sont éliminés) peuvent gagner.
            candidates = [p for p in room.humans() if p.client_id in room.players]
            if room.settings.elimination:
                alive = [p for p in candidates if p.eliminated_round is None]
                candidates = alive or candidates
            if not candidates:
                # Personne d'humain : rembourser l'hôte.
                await self._refund_stakes(room)
                return
            best = max(p.score for p in candidates)
            winners = [p.client_id for p in candidates if p.score == best]
            share, rest = divmod(room.pot, len(winners))
            room.winnings = {cid: share + (1 if i < rest else 0) for i, cid in enumerate(winners)}
            await self._credit_all(room, room.winnings, "prize_win")
            return
        remaining = [room.players[cid] for cid in room.stakers if cid in room.players]
        if room.settings.elimination:
            # Seuls les joueurs encore en lice peuvent gagner.
            remaining = [p for p in remaining if p.eliminated_round is None] or remaining
        if not remaining:
            return
        best = max(p.score for p in remaining)
        winners = [p.client_id for p in remaining if p.score == best]
        share, rest = divmod(room.pot, len(winners))
        room.winnings = {cid: share + (1 if i < rest else 0) for i, cid in enumerate(winners)}
        await self._credit_all(room, room.winnings, "bet_win")

    async def _refund_stakes(self, room: Room) -> None:
        """Partie interrompue : rembourser mises (paris) ou dotation (hôte)."""
        if room.stakers and not room.winnings:
            reason = "prize_refund" if room.settings.prize else "bet_refund"
            if room.settings.prize:
                await self._credit_all(
                    room, {room.stakers[0]: room.settings.stake}, reason
                )
            else:
                await self._credit_all(
                    room, {cid: room.settings.stake for cid in room.stakers}, reason
                )
            room.stakers = []

    async def _credit_all(self, room: Room, amounts: dict[str, int], reason: str) -> None:
        updates = {}
        async with self.session_factory() as session:
            for client_id, amount in amounts.items():
                profile = await wallet_service.credit(session, client_id, amount, reason, reference=room.game_id)
                updates[client_id] = wallet_service.snapshot(profile, amount)
            await session.commit()
        await self._send_wallets(updates)

    async def _launch_bots(self, room: Room, live: LiveRound) -> None:
        bots = [p for p in room.players.values() if p.bot and p.client_id in live.participants]
        if not bots:
            return
        pool = max(bot_service.BOT_PROFILES[b.bot_level].pool for b in bots)
        async with self.session_factory() as session:
            options = await bot_service.candidates(
                session, room.settings.language, [c.value for c in room.settings.categories], live.letter, pool
            )
        for bot in bots:
            profile = bot_service.BOT_PROFILES[bot.bot_level]
            answers = bot_service.choose_answers(
                profile, {c: values[: profile.pool] for c, values in options.items()}
            )
            delay = bot_service.answer_delay(profile, room.settings.round_duration) * self.timings.bot_speed
            live.bot_tasks.append(asyncio.create_task(self._bot_submit(room, live, bot.client_id, answers, delay)))

    async def _bot_submit(
        self, room: Room, live: LiveRound, client_id: str, answers: dict[Category, str], delay: float
    ) -> None:
        await asyncio.sleep(delay)
        if room.live_round is not live or client_id in live.submissions:
            return
        live.submissions[client_id] = (utcnow(), answers)
        await self._broadcast(room)
        self._check_all_in(room)

    # ------------------------------------------------------------- QI

    async def _on_iq_answer(self, connection: Connection, message: dict) -> None:
        """Réponse à l'énigme de QI : un nombre ou l'indice du choix ; une seule par manche."""
        room = self._require_room(connection.client_id)
        live = room.live_round
        if (
            not room.settings.iq
            or room.phase != "round"
            or live is None
            or live.puzzle is None
            or message.get("round") != live.number
            or connection.client_id not in live.participants
        ):
            raise RoomError("round_not_current")
        if connection.client_id in live.submissions:
            return
        answer = str(message.get("answer") if message.get("answer") is not None else "")[:16]
        live.submissions[connection.client_id] = (utcnow(), {"iq": answer})
        await self._broadcast(room)
        self._check_all_in(room)

    async def _play_iq_round(self, room: Room, number: int) -> None:
        """Une manche de QI : une énigme, des points selon la justesse (et la vitesse)."""
        room.phase = "countdown"
        room.results = None
        room.next_round_at = None
        room.go_at = utcnow() + timedelta(seconds=self.timings.countdown)
        await self._broadcast(room)
        await asyncio.sleep(self.timings.countdown)

        settings = room.settings
        level = iq_service.level_for(number, settings.rounds, settings.difficulty)
        used = {r.get("puzzle", {}).get("id") for r in room.results_history if isinstance(r.get("puzzle"), dict)}
        puzzle = iq_service.draw(level, exclude=used)
        started = utcnow()
        live = LiveRound(
            number=number,
            letter="",
            started_at=started,
            ends_at=started + timedelta(seconds=settings.round_duration),
            participants={
                cid: p.db_player_id or cid
                for cid, p in room.players.items()
                if p.eliminated_round is None
            },
            puzzle=puzzle,
        )
        room.round_number = number
        room.live_round = live
        room.phase = "round"
        room.go_at = None
        await self._broadcast(room)
        self._launch_iq_bots(room, live)

        timeout = settings.round_duration + self.timings.submit_grace
        with contextlib.suppress(TimeoutError):
            await asyncio.wait_for(live.all_in.wait(), timeout=timeout)
        for task in live.bot_tasks:
            task.cancel()

        results, awards, client_of = [], [], {}
        for cid in live.participants:
            player = room.players.get(cid)
            if player is None:
                continue
            submitted = live.submissions.get(cid)
            answer = submitted[1].get("iq") if submitted else None
            elapsed = (min(submitted[0], live.ends_at) - started).total_seconds() if submitted else None
            correct = submitted is not None and iq_service.check(puzzle, answer)
            pts = iq_service.points(
                correct,
                submitted is not None,
                elapsed or 0.0,
                settings.round_duration,
                settings.iq_speed_bonus,
                settings.iq_penalty,
            )
            player.score += pts
            results.append(
                {
                    "client_id": cid,
                    "nickname": player.nickname,
                    "answers": [],
                    "answer": answer,
                    "correct": correct,
                    "round_score": pts,
                    "elapsed_ms": int(elapsed * 1000) if elapsed is not None else None,
                }
            )
            if pts > 0 and player.db_player_id:
                awards.append(SimpleNamespace(player_id=player.db_player_id, round_score=pts))
                client_of[player.db_player_id] = cid
        eliminated = self._eliminate(room, number, {r["client_id"]: r["round_score"] for r in results})
        room.results = {
            "number": number,
            "letter": "",
            "puzzle": puzzle.reveal(),
            "players": results,
            "examples": {},
            "eliminated": eliminated,
            "bonus": False,
            "assignments": {},
        }
        room.results_history.append(room.results)
        room.live_round = None
        room.phase = "results"
        await self._broadcast(room)
        await self._award_round_points(room, awards, client_of)

    def _launch_iq_bots(self, room: Room, live: LiveRound) -> None:
        """Bots : plus ils sont forts, plus ils répondent vite et juste."""
        profiles = {
            Difficulty.EASY: (0.5, (0.55, 0.95)),
            Difficulty.NORMAL: (0.7, (0.35, 0.8)),
            Difficulty.HARD: (0.9, (0.2, 0.55)),
        }
        rng = random.Random()
        for cid in live.participants:
            bot = room.players.get(cid)
            if bot is None or not bot.bot:
                continue
            accuracy, (low, high) = profiles.get(bot.bot_level, profiles[Difficulty.NORMAL])
            answer = live.puzzle.answer if rng.random() < accuracy else iq_service.wrong_answer(live.puzzle, rng)
            delay = room.settings.round_duration * rng.uniform(low, high) * self.timings.bot_speed
            live.bot_tasks.append(asyncio.create_task(self._iq_bot_answer(room, live, cid, answer, delay)))

    async def _iq_bot_answer(self, room: Room, live: LiveRound, client_id: str, answer: str, delay: float) -> None:
        await asyncio.sleep(delay)
        if room.live_round is not live or client_id in live.submissions:
            return
        live.submissions[client_id] = (utcnow(), {"iq": answer})
        await self._broadcast(room)
        self._check_all_in(room)

    def _check_all_in(self, room: Room) -> None:
        """Termine la manche plus tôt dès que chaque participant connecté a répondu."""
        live = room.live_round
        if live is None or room.phase != "round":
            return
        waiting_for = [
            cid
            for cid in live.participants
            if cid in room.players and room.players[cid].connected and cid not in live.submissions
        ]
        if not waiting_for:
            live.all_in.set()

    # ------------------------------------------------------------- sérialisation

    def room_state(self, room: Room) -> dict:
        live = room.live_round
        settings = room.settings
        now = utcnow()
        humans = [p for p in room.humans() if p.connected]
        rematch_votes = sum(1 for p in humans if p.rematch_vote)
        rematch_need = max(1, (len(humans) + 1) // 2) if humans else 1
        return {
            "code": room.code,
            "public": settings.public,
            "quick": room.quick,
            "host_id": room.host_id,
            "phase": room.phase,
            "pot": room.pot,
            "winnings": room.winnings,
            "settings": {
                "kind": settings.kind,
                "stake": settings.stake,
                "format": settings.format,
                "game": settings.game,
                "iq_speed_bonus": settings.iq_speed_bonus,
                "iq_penalty": settings.iq_penalty,
                "theme": settings.theme,
                "language": settings.language,
                "difficulty": settings.difficulty,
                "categories": [c.value for c in settings.categories],
                "rounds": settings.rounds,
                "round_duration": settings.round_duration,
                "strict_spelling": settings.strict_spelling,
                "max_players": settings.max_players,
            },
            "players": [
                {
                    "client_id": p.client_id,
                    "nickname": p.nickname,
                    "ready": p.ready,
                    "connected": p.connected,
                    "score": p.score,
                    "finished": bool(live and p.client_id in live.submissions),
                    "playing": bool(live and p.client_id in live.participants) or not room.in_game,
                    "bot": p.bot,
                    "bot_level": p.bot_level,
                    "hints_left": HINTS_PER_GAME + p.bonus_hints - p.hints_used,
                    "freezes_left": p.freezes_left,
                    "frozen_until": _iso(
                        live.frozen_until.get(p.client_id)
                        if live and live.frozen_until.get(p.client_id) and live.frozen_until[p.client_id] > now
                        else None
                    ),
                    "chat_unlocked": p.chat_unlocked,
                    "rematch_vote": p.rematch_vote,
                    "title": p.title,
                    "assignments": list((live.assignments if live else {}).get(p.client_id, [])),
                    "avatar_preset": p.avatar_preset,
                    "avatar_url": p.avatar_url,
                    "level": p.level,
                    "eliminated_round": p.eliminated_round,
                    "language": p.language,
                    "country": p.country,
                    "hair": p.hair,
                    "hat": p.hat,
                    "frame": p.frame,
                    "name_style": p.name_style,
                }
                for p in room.players.values()
            ],
            "round_number": room.round_number,
            "round": None
            if live is None
            else {
                "number": live.number,
                "letter": live.letter,
                "duration": BONUS_ROUND_DURATION if live.bonus else settings.round_duration,
                "started_at": _iso(live.started_at),
                "ends_at": _iso(live.ends_at),
                "bonus": live.bonus,
                "assignments": live.assignments,
                # QI : l'énigme, sans sa réponse.
                "puzzle": live.puzzle.public() if live.puzzle else None,
            },
            "results": room.results,
            "lightning": None
            if room.lightning is None
            else {
                "letter": room.lightning.letter,
                "category": room.lightning.category,
                "options": room.lightning.options,
                "ends_at": _iso(room.lightning.ends_at),
                "picks": {
                    cid: {"choice": choice, "points": room.lightning.scores.get(cid, 0)}
                    for cid, choice in room.lightning.picks.items()
                },
            },
            "reactions": trim_reactions(room.reactions),
            "chat": trim_chat(room.chat, CHAT_HISTORY),
            "creator_id": room.creator_id,
            "saved": room.creator_id is not None,
            "word_review": room.word_review,
            "bonus_played": room.bonus_played,
            "rematch_votes": rematch_votes,
            "rematch_need": rematch_need,
            "voice": {
                "enabled": voice_service.voice_enabled(),
                "open": voice_service.voice_enabled() and self._voice_is_open(room),
                "channel": room.code,
                "muted": sorted(room.voice_muted),
                "excluded": sorted(room.voice_excluded),
            },
            "prices": {
                "freeze": FREEZE_PRICE,
                "chat_unlock": CHAT_UNLOCK_PRICE,
                "extra_hint": EXTRA_HINT_PRICE,
            },
            "starts_at": _iso(room.starts_at),
            "go_at": _iso(room.go_at),
            "next_round_at": _iso(room.next_round_at),
            "server_time": _iso(utcnow()),
        }

    def room_list(self, language: str | None) -> list[dict]:
        rooms = [
            r
            for r in self.rooms.values()
            if r.settings.public
            and r.phase == "waiting"
            and r.joinable
        ]
        # Toutes les langues se mélangent ; les salons de la même langue viennent en premier.
        rooms.sort(key=lambda r: (r.settings.language != language, -len(r.players)))
        return [
            {
                "code": r.code,
                "quick": r.quick,
                "host": r.players[r.host_id].nickname if r.host_id in r.players else "",
                "nicknames": _nicknames_host_first(r),
                "players": len(r.players),
                "max_players": r.settings.max_players,
                "language": r.settings.language,
                "difficulty": r.settings.difficulty,
                "rounds": r.settings.rounds,
                "round_duration": r.settings.round_duration,
                "strict_spelling": r.settings.strict_spelling,
                "kind": r.settings.kind,
                "stake": r.settings.stake,
                "format": r.settings.format,
                "game": r.settings.game,
                "theme": r.settings.theme,
            }
            for r in rooms[:50]
        ]

    # ---------------------------------------------------------------------- envoi

    async def _send(self, client_id: str, message: dict) -> None:
        connection = self.connections.get(client_id)
        if connection is None:
            return
        with contextlib.suppress(Exception):
            await connection.websocket.send_json(message)

    async def _broadcast(self, room: Room) -> None:
        state = {"type": "room_state", "room": self.room_state(room)}
        for player in list(room.players.values()):
            if player.connected:
                await self._send(player.client_id, state)

    async def _notice(
        self,
        room: Room,
        kind: str,
        nickname: str,
        exclude: str | None = None,
        detail: str = "",
    ) -> None:
        message = {
            "type": "notice",
            "kind": kind,
            "nickname": nickname,
            "detail": detail,
        }
        for player in list(room.players.values()):
            if player.connected and player.client_id != exclude:
                await self._send(player.client_id, message)

    async def _error(self, client_id: str, code: str) -> None:
        await self._send(client_id, {"type": "error", "code": code})

    async def _send_room_list(self, client_id: str) -> None:
        language = self._room_list_subscribers.get(client_id)
        await self._send(client_id, {"type": "room_list", "rooms": self.room_list(language)})

    async def _rooms_changed(self) -> None:
        for client_id in list(self._room_list_subscribers):
            await self._send_room_list(client_id)

    def _public_room_summary(self, room: Room) -> dict:
        return {
            "code": room.code,
            "quick": room.quick,
            "host": room.players[room.host_id].nickname if room.host_id in room.players else "",
            "nicknames": _nicknames_host_first(room),
            "players": len(room.players),
            "max_players": room.settings.max_players,
            "language": room.settings.language,
            "difficulty": room.settings.difficulty,
            "rounds": room.settings.rounds,
            "round_duration": room.settings.round_duration,
            "strict_spelling": room.settings.strict_spelling,
            "kind": room.settings.kind,
            "stake": room.settings.stake,
            "format": room.settings.format,
            "theme": room.settings.theme,
        }

    async def _announce_public_room(self, room: Room) -> None:
        """Préviens chaque joueur connecté hors du salon qu'un salon public est ouvert."""
        payload = {"type": "public_room", "room": self._public_room_summary(room)}
        for client_id in list(self.connections):
            if client_id in room.players:
                continue
            await self._send(client_id, payload)


room_manager = RoomManager()
