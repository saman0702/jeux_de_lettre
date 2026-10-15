"""Live multiplayer rooms: lobby, quick match, synchronized rounds.

Each client keeps one WebSocket open. Whenever a room changes, every member
receives the full `room_state`, so a client (or a reconnecting one) only
ever needs the latest state to render the right screen.

Rooms live in this process's memory (one API worker for the MVP); games,
rounds and answers are persisted through multiplayer_service.
"""

import asyncio
import contextlib
import logging
import secrets
from dataclasses import dataclass, field
from datetime import datetime, timedelta

from fastapi import WebSocket
from pydantic import Field, ValidationError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.database import SessionLocal
from app.core.game_rules import (
    HINTS_PER_GAME,
    MAX_ROOM_PLAYERS,
    MIN_ROOM_PLAYERS,
    SUBMIT_GRACE_SECONDS,
    Category,
    Difficulty,
    Language,
)
from app.models.base import utcnow
from app.schemas.game import GameSettings
from app.services import bot_service, hint_service, multiplayer_service
from app.services.presence_service import PresenceStore, RedisPresence

logger = logging.getLogger(__name__)

CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no O/0 or I/1 confusion
CODE_LENGTH = 5


class RoomSettings(GameSettings):
    public: bool = False
    max_players: int = Field(default=MAX_ROOM_PLAYERS, ge=MIN_ROOM_PLAYERS, le=MAX_ROOM_PLAYERS)


@dataclass
class Timings:
    countdown: float = 3.0
    results: float = 8.0
    quick_start: float = 15.0
    reconnect_grace: float = 30.0
    presence_interval: float = 5.0
    submit_grace: float = SUBMIT_GRACE_SECONDS
    # A lone quick-match player gets bots after this wait.
    quick_bot_fill: float = 12.0
    quick_bot_count: int = 2
    # Multiplies bot answer delays (tests use a tiny value).
    bot_speed: float = 1.0


@dataclass
class RoomPlayer:
    client_id: str
    nickname: str
    ready: bool = False
    connected: bool = True
    score: int = 0
    # Set once the player takes part in the game (late joiners get it at the next round).
    db_player_id: str | None = None
    bot_level: Difficulty | None = None
    hints_used: int = 0

    @property
    def bot(self) -> bool:
        return self.bot_level is not None


@dataclass
class LiveRound:
    number: int
    letter: str
    started_at: datetime
    ends_at: datetime
    participants: dict[str, str]  # client id -> db player id
    submissions: dict[str, tuple[datetime, dict[Category, str]]] = field(default_factory=dict)
    all_in: asyncio.Event = field(default_factory=asyncio.Event)
    bot_tasks: list[asyncio.Task] = field(default_factory=list)
    hints: dict[str, dict[str, hint_service.Hint]] = field(default_factory=dict)  # client -> category


@dataclass
class Room:
    code: str
    settings: RoomSettings
    quick: bool
    host_id: str
    players: dict[str, RoomPlayer] = field(default_factory=dict)
    # waiting -> countdown -> round -> results -> ... -> finished -> waiting
    phase: str = "waiting"
    game_id: str | None = None
    round_number: int = 0
    live_round: LiveRound | None = None
    results: dict | None = None
    starts_at: datetime | None = None  # quick match automatic start
    go_at: datetime | None = None
    next_round_at: datetime | None = None
    game_task: asyncio.Task | None = None
    quick_timer: asyncio.Task | None = None
    bot_fill_timer: asyncio.Task | None = None

    @property
    def in_game(self) -> bool:
        return self.phase in ("countdown", "round", "results")

    @property
    def joinable(self) -> bool:
        return len(self.players) < self.settings.max_players

    def connected_players(self) -> list[RoomPlayer]:
        return [p for p in self.players.values() if p.connected]

    def humans(self) -> list[RoomPlayer]:
        return [p for p in self.players.values() if not p.bot]


@dataclass
class Connection:
    client_id: str
    nickname: str
    websocket: WebSocket


class RoomError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


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
        self._room_of: dict[str, str] = {}  # client id -> room code
        self._room_list_subscribers: dict[str, str | None] = {}  # client id -> language filter
        self._expiry_tasks: dict[str, asyncio.Task] = {}
        self._online_count = 0
        self._presence_task: asyncio.Task | None = None

    # ------------------------------------------------------------------ lifecycle

    def start(self) -> None:
        self._presence_task = asyncio.create_task(self._presence_loop())

    async def stop(self) -> None:
        tasks = [self._presence_task, *self._expiry_tasks.values()]
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

    # ---------------------------------------------------------------- connections

    async def connect(self, websocket: WebSocket, client_id: str, nickname: str) -> Connection:
        previous = self.connections.get(client_id)
        if previous is not None:
            with contextlib.suppress(Exception):
                await previous.websocket.close(code=4000, reason="replaced")

        connection = Connection(client_id, nickname, websocket)
        self.connections[client_id] = connection
        if task := self._expiry_tasks.pop(client_id, None):
            task.cancel()

        await self.presence.touch([client_id])
        await self._send(client_id, {"type": "welcome", "online_count": await self.presence.count()})
        await self._refresh_online_count()

        room = self._current_room(client_id)
        if room is not None:
            player = room.players[client_id]
            player.connected = True
            await self._notice(room, "reconnected", player.nickname, exclude=client_id)
            await self._broadcast(room)
        return connection

    async def disconnect(self, connection: Connection) -> None:
        client_id = connection.client_id
        if self.connections.get(client_id) is not connection:
            return  # replaced by a newer connection
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
        """Players who do not come back in time leave their room."""
        await asyncio.sleep(self.timings.reconnect_grace)
        self._expiry_tasks.pop(client_id, None)
        room = self._current_room(client_id)
        if room is not None and not room.players[client_id].connected:
            await self._leave(client_id)

    # ------------------------------------------------------------------- messages

    async def handle(self, connection: Connection, message: dict) -> None:
        handlers = {
            "create_room": self._on_create_room,
            "join_room": self._on_join_room,
            "quick_match": self._on_quick_match,
            "leave_room": self._on_leave_room,
            "set_ready": self._on_set_ready,
            "submit": self._on_submit,
            "hint": self._on_hint,
            "hint_pick": self._on_hint_pick,
            "add_bot": self._on_add_bot,
            "remove_bot": self._on_remove_bot,
            "subscribe_rooms": self._on_subscribe_rooms,
            "unsubscribe_rooms": self._on_unsubscribe_rooms,
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

        await self._leave(connection.client_id)
        room = self._new_room(settings, quick=False, host=connection)
        await self._add_player(room, connection)
        if bot_count > 0:
            # Playing against the computer: start right away.
            for _ in range(bot_count):
                self._add_bot(room, bot_level)
            room.players[connection.client_id].ready = True
            await self._broadcast(room)
            await self._maybe_start(room)

    async def _on_join_room(self, connection: Connection, message: dict) -> None:
        code = str(message.get("code", "")).strip().upper()
        room = self.rooms.get(code)
        if room is None:
            raise RoomError("room_not_found")
        if connection.client_id in room.players:
            await self._broadcast(room)
            return
        if not room.joinable:
            raise RoomError("room_full")
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
            if r.quick and r.phase == "waiting" and r.joinable and r.settings.language == language
        ]
        # Join the fullest room so games start sooner.
        room = max(candidates, key=lambda r: len(r.players), default=None)
        if room is None:
            room = self._new_room(RoomSettings(language=language, public=True), quick=True, host=connection)
        await self._add_player(room, connection)

    async def _on_leave_room(self, connection: Connection, message: dict) -> None:
        await self._leave(connection.client_id)
        await self._send(connection.client_id, {"type": "left_room"})

    async def _on_set_ready(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        if room.phase == "finished":
            self._reset_to_lobby(room)
        if room.phase != "waiting":
            raise RoomError("game_in_progress")
        room.players[connection.client_id].ready = bool(message.get("ready", True))
        if room.quick:
            self._schedule_quick_start(room)
        await self._broadcast(room)
        await self._maybe_start(room)

    async def _on_submit(self, connection: Connection, message: dict) -> None:
        room = self._require_room(connection.client_id)
        live = room.live_round
        client_id = connection.client_id
        if (
            room.phase != "round"
            or live is None
            or message.get("round") != live.number
            or client_id not in live.participants
        ):
            raise RoomError("round_not_current")
        if client_id in live.submissions:
            raise RoomError("round_already_submitted")

        now = utcnow()
        if now > live.ends_at + timedelta(seconds=self.timings.submit_grace):
            raise RoomError("round_over")

        raw = message.get("answers") if isinstance(message.get("answers"), dict) else {}
        answers: dict[Category, str] = {}
        for key, value in raw.items():
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

        hint = mine.get(category)
        if hint is None:
            if player.hints_used >= HINTS_PER_GAME:
                raise RoomError("no_hints_left")
            try:
                async with self.session_factory() as session:
                    hint = await hint_service.build_hint(
                        session, room.settings.language, category, live.letter
                    )
            except hint_service.NoHintAvailable:
                raise RoomError("no_hint_available") from None
            mine[category] = hint
            player.hints_used += 1
        await self._send(
            connection.client_id,
            {
                "type": "hint",
                "round": live.number,
                "category": category,
                "options": hint.options,
                "hints_left": HINTS_PER_GAME - player.hints_used,
            },
        )

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

    async def _on_subscribe_rooms(self, connection: Connection, message: dict) -> None:
        language = message.get("language")
        self._room_list_subscribers[connection.client_id] = language if language in list(Language) else None
        await self._send_room_list(connection.client_id)

    async def _on_unsubscribe_rooms(self, connection: Connection, message: dict) -> None:
        self._room_list_subscribers.pop(connection.client_id, None)

    # ---------------------------------------------------------------------- rooms

    def _new_room(self, settings: RoomSettings, quick: bool, host: Connection) -> Room:
        code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
        while code in self.rooms:
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
        )
        room.players[bot.client_id] = bot
        return bot

    async def _add_player(self, room: Room, connection: Connection) -> None:
        room.players[connection.client_id] = RoomPlayer(
            client_id=connection.client_id, nickname=connection.nickname, ready=room.quick
        )
        self._room_of[connection.client_id] = room.code
        if room.quick:
            self._schedule_quick_start(room)
        await self._notice(room, "joined", connection.nickname, exclude=connection.client_id)
        await self._broadcast(room)
        await self._rooms_changed()

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
        for player in room.players.values():
            player.score = 0
            player.ready = room.quick or player.bot
            player.db_player_id = None
            player.hints_used = 0

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

    # ---------------------------------------------------------------- game start

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
        """Nobody else online: bots join so the player is not left waiting."""
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

    # ----------------------------------------------------------------- game loop

    async def _run_game(self, room: Room) -> None:
        try:
            await self._rooms_changed()
            mode = "duel" if room.settings.max_players == 2 else "multiplayer"
            async with self.session_factory() as session:
                room.game_id, ids = await multiplayer_service.create_game(
                    session, mode, room.settings, {cid: p.nickname for cid, p in room.players.items()}
                )
            for client_id, player_id in ids.items():
                room.players[client_id].db_player_id = player_id

            for number in range(1, room.settings.rounds + 1):
                await self._enrol_late_joiners(room)
                if len(room.connected_players()) < MIN_ROOM_PLAYERS:
                    break
                await self._play_round(room, number)
                if number == room.settings.rounds:
                    break
                room.next_round_at = utcnow() + timedelta(seconds=self.timings.results)
                await self._broadcast(room)
                await asyncio.sleep(self.timings.results)

            async with self.session_factory() as session:
                await multiplayer_service.finish_game(session, room.game_id)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("game loop failed in room %s", room.code)
            await self._notice(room, "error", "")
        finally:
            room.game_task = None

        room.phase = "finished"
        room.live_round = None
        room.go_at = room.next_round_at = None
        for player in room.players.values():
            player.ready = False
        await self._broadcast(room)
        await self._rooms_changed()

    async def _enrol_late_joiners(self, room: Room) -> None:
        for player in room.players.values():
            if player.db_player_id is None:
                async with self.session_factory() as session:
                    player.db_player_id = await multiplayer_service.add_player(
                        session, room.game_id, player.nickname
                    )

    async def _play_round(self, room: Room, number: int) -> None:
        room.phase = "countdown"
        room.results = None
        room.next_round_at = None
        room.go_at = utcnow() + timedelta(seconds=self.timings.countdown)
        await self._broadcast(room)
        await asyncio.sleep(self.timings.countdown)

        async with self.session_factory() as session:
            info = await multiplayer_service.start_round(session, room.game_id)
        room.round_number = number
        room.live_round = LiveRound(
            number=info.number,
            letter=info.letter,
            started_at=info.started_at,
            ends_at=info.ends_at,
            participants={cid: p.db_player_id for cid, p in room.players.items()},
        )
        room.phase = "round"
        room.go_at = None
        await self._broadcast(room)
        await self._launch_bots(room, room.live_round)

        timeout = (info.ends_at - utcnow()).total_seconds() + self.timings.submit_grace
        with contextlib.suppress(TimeoutError):
            await asyncio.wait_for(room.live_round.all_in.wait(), timeout=max(0.0, timeout))

        live = room.live_round
        for task in live.bot_tasks:
            task.cancel()
        # Picked hint options replace whatever was typed in those categories.
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
            )

        by_player_id = {p.db_player_id: p for p in room.players.values()}
        client_of = {db_id: cid for cid, db_id in live.participants.items()}
        results = []
        for result in outcome.results:
            player = by_player_id.get(result.player_id)
            if player is not None:
                player.score += result.round_score
            results.append(
                {
                    "client_id": client_of[result.player_id],
                    "nickname": player.nickname if player else "",
                    "answers": result.answers,
                    "round_score": result.round_score,
                    "elapsed_ms": result.elapsed_ms,
                }
            )
        room.results = {"number": outcome.number, "letter": outcome.letter, "players": results}
        room.live_round = None
        room.phase = "results"
        await self._broadcast(room)

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

    def _check_all_in(self, room: Room) -> None:
        """Ends the round early once every connected participant has answered."""
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

    # -------------------------------------------------------------- serialization

    def room_state(self, room: Room) -> dict:
        live = room.live_round
        settings = room.settings
        return {
            "code": room.code,
            "public": settings.public,
            "quick": room.quick,
            "host_id": room.host_id,
            "phase": room.phase,
            "settings": {
                "language": settings.language,
                "difficulty": settings.difficulty,
                "categories": [c.value for c in settings.categories],
                "rounds": settings.rounds,
                "round_duration": settings.round_duration,
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
                    "hints_left": HINTS_PER_GAME - p.hints_used,
                }
                for p in room.players.values()
            ],
            "round_number": room.round_number,
            "round": None
            if live is None
            else {
                "number": live.number,
                "letter": live.letter,
                "duration": settings.round_duration,
                "started_at": _iso(live.started_at),
                "ends_at": _iso(live.ends_at),
            },
            "results": room.results,
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
            and (language is None or r.settings.language == language)
        ]
        rooms.sort(key=lambda r: len(r.players), reverse=True)
        return [
            {
                "code": r.code,
                "quick": r.quick,
                "host": r.players[r.host_id].nickname if r.host_id in r.players else "",
                "players": len(r.players),
                "max_players": r.settings.max_players,
                "language": r.settings.language,
                "difficulty": r.settings.difficulty,
                "rounds": r.settings.rounds,
                "round_duration": r.settings.round_duration,
            }
            for r in rooms[:50]
        ]

    # -------------------------------------------------------------------- sending

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

    async def _notice(self, room: Room, kind: str, nickname: str, exclude: str | None = None) -> None:
        message = {"type": "notice", "kind": kind, "nickname": nickname}
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


room_manager = RoomManager()
