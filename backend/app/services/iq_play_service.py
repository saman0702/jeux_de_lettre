"""Parties de QI vérifiées par le serveur : solo en ligne et défi du jour.

Les énigmes et leurs réponses restent en base ; l'appli ne reçoit que l'énoncé de l'énigme en
cours. Le temps est mesuré par le serveur (de l'envoi de l'énigme à la réponse). Les points
rapportent des pièces comme au Petit Bac (20 points = 1 pièce). Hors ligne, l'appli joue seule
sur ses énigmes embarquées, sans pièces.

Défi du jour : les mêmes 10 énigmes pour tout le monde (tirées d'une graine du jour), une
tentative par jour, sans jokers ; classement au score puis au temps. Le podium d'un jour est
récompensé une fois, dès qu'on consulte le classement un jour suivant.
"""

import random
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import IqDailyPayout, IqSession
from app.services import iq_service, wallet_service

DAILY_COUNT = 10
DAILY_DURATION = 30
DAILY_PRIZES = [50, 30, 20]
# Marge pour le trajet réseau avant de compter une réponse comme hors délai.
GRACE_SECONDS = 2
SOLO_ROUNDS = (5, 10, 15)
# 0 = illimité ; presets UI ; sinon 10–900 s saisis à la main.
SOLO_DURATIONS = (0, 15, 30, 45, 60)
MIN_CUSTOM_DURATION = 10
MAX_CUSTOM_DURATION = 900
# Pause vidéo (pas assez de pièces pour un joker) : notée dans game.jokers, une par énigme.
AD_BREAK = "ad"
AD_BREAK_MAX_SECONDS = 120


def _valid_duration(duration: int) -> bool:
    if duration in SOLO_DURATIONS:
        return True
    return MIN_CUSTOM_DURATION <= duration <= MAX_CUSTOM_DURATION


class IqPlayError(Exception):
    def __init__(self, code: str, status_code: int = 409):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


def today() -> date:
    return datetime.now(UTC).date()


def _now() -> datetime:
    return datetime.now(UTC)


def _draw(
    count: int,
    difficulty: str,
    rng: random.Random,
    avoid: set[str] | None = None,
) -> list[dict]:
    """Tire [count] énigmes distinctes ; [avoid] = ids déjà vus (parties précédentes)."""
    used: set[str] = set(avoid or ())
    recent_kinds: list[str] = []
    puzzles = []
    for number in range(1, count + 1):
        # Évite de retomber 3 fois de suite sur le même type (suite, figure…).
        soft = set(recent_kinds[-2:])
        puzzle = iq_service.draw(
            iq_service.level_for(number, count, difficulty),
            exclude=used,
            rng=rng,
            avoid_kinds=soft,
        )
        used.add(puzzle.id)
        recent_kinds.append(puzzle.kind)
        puzzles.append(puzzle.reveal())
    return puzzles


def daily_puzzles(day: date) -> list[dict]:
    """Les énigmes du jour : les mêmes pour tous (graine = la date)."""
    return _draw(DAILY_COUNT, "normal", random.Random(f"iq-daily-{day.isoformat()}"))


def _current(game: IqSession) -> iq_service.Puzzle:
    return iq_service.puzzle_from(game.puzzles[game.number - 1])


def _public(game: IqSession) -> dict:
    """Ce que l'appli reçoit pour l'énigme en cours (sans la réponse)."""
    return {
        "id": game.id,
        "mode": game.mode,
        "number": game.number,
        "total": len(game.puzzles),
        "duration": game.duration,
        "extra_seconds": game.extra_seconds,
        "speed_bonus": game.speed_bonus,
        "penalty": game.penalty,
        "score": game.score,
        "jokers_used": [j for j in game.jokers if j != AD_BREAK and not j.startswith(f"{AD_BREAK}@")],
        "joker_prices": (
            iq_service.joker_prices(game.duration) if game.mode == "solo" else {}
        ),
        "puzzle": _current(game).public(),
    }


async def _abandon_open_solos(session: AsyncSession, client_id: str) -> None:
    """Une nouvelle partie remplace les solos inachevés (pause abandonnée)."""
    open_games = (
        await session.scalars(
            select(IqSession).where(
                IqSession.client_id == client_id,
                IqSession.mode == "solo",
                IqSession.finished.is_(False),
            )
        )
    ).all()
    for game in open_games:
        game.finished = True


async def start_solo(
    session: AsyncSession,
    client_id: str,
    rounds: int,
    duration: int,
    difficulty: str,
    speed_bonus: bool,
    penalty: bool,
    nickname: str | None = None,
    avoid: set[str] | None = None,
) -> dict:
    if rounds not in SOLO_ROUNDS or not _valid_duration(duration):
        raise IqPlayError("invalid_settings", 422)
    await _abandon_open_solos(session, client_id)
    profile = await wallet_service.get_profile(session, client_id)
    game = IqSession(
        client_id=client_id,
        nickname=nickname or profile.nickname,
        mode="solo",
        duration=duration,
        speed_bonus=speed_bonus,
        penalty=penalty,
        puzzles=_draw(rounds, difficulty, random.Random(), avoid=avoid),
        jokers=[],
        results=[],
    )
    _serve(game, 1)
    session.add(game)
    await session.flush()
    return _public(game)


async def start_daily(session: AsyncSession, client_id: str, nickname: str | None = None) -> dict:
    day = today()
    done = await session.scalar(select(IqSession).where(IqSession.client_id == client_id, IqSession.day == day))
    if done is not None:
        raise IqPlayError("daily_done")
    profile = await wallet_service.get_profile(session, client_id)
    game = IqSession(
        client_id=client_id,
        nickname=nickname or profile.nickname,
        mode="daily",
        day=day,
        duration=DAILY_DURATION,
        speed_bonus=True,
        penalty=False,
        puzzles=daily_puzzles(day),
        jokers=[],
        results=[],
    )
    _serve(game, 1)
    session.add(game)
    try:
        await session.flush()
    except IntegrityError:
        raise IqPlayError("daily_done") from None
    return _public(game)


def _serve(game: IqSession, number: int) -> None:
    game.number = number
    game.served_at = _now()
    game.answered = False
    game.extra_seconds = 0
    game.jokers = []


async def _game(session: AsyncSession, game_id: str, client_id: str) -> IqSession:
    game = await session.get(IqSession, game_id)
    if game is None or game.client_id != client_id:
        raise IqPlayError("game_not_found", 404)
    return game


async def pause(session: AsyncSession, game_id: str, client_id: str) -> dict:
    """Pause après une manche : prépare l'énigme suivante sans démarrer le chrono.

    Impossible pendant une énigme en cours (il faut d'abord répondre).
    """
    game = await _game(session, game_id, client_id)
    if game.mode != "solo":
        raise IqPlayError("pause_not_allowed", 403)
    if game.finished:
        return {
            "id": game.id,
            "finished": True,
            "score": game.score,
            "correct_count": game.correct,
            "iq": iq_service.iq_estimate(game.results),
        }
    if not game.answered:
        raise IqPlayError("pause_not_allowed")
    if game.number >= len(game.puzzles):
        game.finished = True
        return {
            "id": game.id,
            "finished": True,
            "score": game.score,
            "correct_count": game.correct,
            "iq": iq_service.iq_estimate(game.results),
        }
    _serve(game, game.number + 1)
    game.served_at = None  # gelé jusqu'à resume
    return {
        "id": game.id,
        "finished": False,
        "number": game.number,
        "total": len(game.puzzles),
        "paused": True,
    }


async def resume(session: AsyncSession, game_id: str, client_id: str) -> dict:
    """Reprend un solo en pause : démarre (ou relance) le chrono de l'énigme en cours."""
    game = await _game(session, game_id, client_id)
    if game.mode != "solo":
        raise IqPlayError("pause_not_allowed", 403)
    if game.finished:
        return {
            "id": game.id,
            "finished": True,
            "score": game.score,
            "correct_count": game.correct,
            "iq": iq_service.iq_estimate(game.results),
            "results": list(game.results),
        }
    if game.answered:
        # Pause oubliée après réponse : avancer comme pause().
        if game.number >= len(game.puzzles):
            game.finished = True
            return {
                "id": game.id,
                "finished": True,
                "score": game.score,
                "correct_count": game.correct,
                "iq": iq_service.iq_estimate(game.results),
                "results": list(game.results),
            }
        _serve(game, game.number + 1)
    else:
        # Chrono neuf (pause ou abandon mid-énigme).
        game.served_at = _now()
        game.extra_seconds = 0
        game.jokers = []
    return _public(game)


async def active_solo(session: AsyncSession, client_id: str) -> dict | None:
    """Solo inachevé le plus récent (pour le bouton Continuer)."""
    game = await session.scalar(
        select(IqSession)
        .where(
            IqSession.client_id == client_id,
            IqSession.mode == "solo",
            IqSession.finished.is_(False),
        )
        .order_by(IqSession.created_at.desc())
        .limit(1)
    )
    if game is None:
        return None
    return {
        "id": game.id,
        "number": game.number,
        "total": len(game.puzzles),
        "answered": game.answered,
        "paused": game.served_at is None,
        "duration": game.duration,
        "speed_bonus": game.speed_bonus,
        "penalty": game.penalty,
    }


def _ad_mark(game: IqSession) -> str | None:
    """Marque de la pause vidéo de l'énigme en cours (« ad@<début> » ouverte, « ad » finie)."""
    return next((j for j in game.jokers if j == AD_BREAK or j.startswith(f"{AD_BREAK}@")), None)


def _close_ad_break(game: IqSession) -> int:
    """Termine la pause vidéo ouverte : le chrono repart d'où il était (served_at décalé)."""
    mark = _ad_mark(game)
    if mark is None or mark == AD_BREAK:
        return 0
    started = datetime.fromisoformat(mark.split("@", 1)[1])
    paused = int(min(max((_now() - started).total_seconds(), 0), AD_BREAK_MAX_SECONDS))
    if game.served_at is not None:
        game.served_at += timedelta(seconds=paused)
    game.jokers = [AD_BREAK if j == mark else j for j in game.jokers]
    return paused


async def start_ad_break(session: AsyncSession, game_id: str, client_id: str, kind: str) -> dict:
    """Pas assez de pièces pour un joker : chrono figé le temps d'une vidéo (une fois par énigme)."""
    game = await _game(session, game_id, client_id)
    if game.mode != "solo":
        raise IqPlayError("jokers_not_allowed", 403)
    if game.finished or game.answered or game.served_at is None or _ad_mark(game) is not None:
        raise IqPlayError("ad_break_unavailable")
    price = iq_service.joker_prices(game.duration).get(kind)
    if price is None:
        raise IqPlayError("joker_unavailable")
    profile = await wallet_service.get_profile(session, client_id)
    if profile.coins >= price:
        raise IqPlayError("ad_break_unavailable")
    game.jokers = [*game.jokers, f"{AD_BREAK}@{_now().isoformat()}"]
    return _public(game)


async def end_ad_break(session: AsyncSession, game_id: str, client_id: str) -> dict:
    """Fin de la vidéo : le chrono reprend (pause plafonnée à AD_BREAK_MAX_SECONDS)."""
    game = await _game(session, game_id, client_id)
    paused = _close_ad_break(game)
    return _public(game) | {"paused_seconds": paused}


async def answer(session: AsyncSession, game_id: str, client_id: str, raw: str | None) -> dict:
    game = await _game(session, game_id, client_id)
    if game.finished or game.answered:
        raise IqPlayError("already_answered")
    _close_ad_break(game)
    if game.served_at is None:
        game.served_at = _now()
    puzzle = _current(game)
    unlimited = game.duration <= 0
    allowed = game.duration + game.extra_seconds
    elapsed = (_now() - game.served_at).total_seconds()
    # Illimité : jamais hors délai. Sinon trop tard = comme pas de réponse.
    late = (not unlimited) and elapsed > allowed + GRACE_SECONDS
    given = None if late or raw is None or not str(raw).strip() else str(raw).strip()[:512]
    correct = given is not None and iq_service.check(puzzle, given)
    scored_elapsed = elapsed if unlimited else min(elapsed, allowed)
    speed = iq_service.speed_of(scored_elapsed, puzzle.level) if given is not None else None
    points = iq_service.points(
        correct,
        given is not None,
        scored_elapsed,
        game.duration,
        game.speed_bonus,
        game.penalty,
        level=puzzle.level,
    )
    game.answered = True
    game.score += points
    game.correct += int(correct)
    game.results = [*game.results, [puzzle.level, correct, speed]]
    game.elapsed_ms += int(scored_elapsed * 1000)
    game.finished = game.number >= len(game.puzzles)
    wallet = None
    if points > 0:
        wallet = (await wallet_service.award_points(session, client_id, points, reference=f"iq:{game.id}")).as_dict()
    result = {
        "number": game.number,
        "total": len(game.puzzles),
        "answer": given,
        "correct": correct,
        "late": late,
        "points": points,
        "elapsed_ms": int(scored_elapsed * 1000),
        "speed": speed,
        "score": game.score,
        "puzzle": puzzle.reveal(),
        "finished": game.finished,
        "wallet": wallet,
    }
    if game.finished:
        result["correct_count"] = game.correct
        result["iq"] = iq_service.iq_estimate(game.results)
    return result


async def next_puzzle(session: AsyncSession, game_id: str, client_id: str) -> dict:
    game = await _game(session, game_id, client_id)
    if game.finished or not game.answered:
        raise IqPlayError("not_answered")
    _serve(game, game.number + 1)
    return _public(game)


async def use_joker(session: AsyncSession, game_id: str, client_id: str, kind: str) -> dict:
    """Joker payé en pièces sur l'énigme en cours (solo seulement)."""
    game = await _game(session, game_id, client_id)
    if game.mode != "solo":
        raise IqPlayError("jokers_not_allowed", 403)
    if game.served_at is None:
        raise IqPlayError("joker_unavailable")
    if game.finished or game.answered or kind in game.jokers:
        raise IqPlayError("joker_unavailable")
    _close_ad_break(game)
    puzzle = _current(game)
    prices = iq_service.joker_prices(game.duration)
    if kind not in prices or not iq_service.joker_allowed(puzzle, kind):
        raise IqPlayError("joker_unavailable")
    if kind == "time" and game.duration <= 0:
        raise IqPlayError("joker_unavailable")
    price = prices[kind]
    try:
        profile = await wallet_service.debit(session, client_id, price, f"iq_joker_{kind}", reference=game.id)
    except wallet_service.WalletError as error:
        raise IqPlayError(error.code, 402) from None
    rng = random.Random()
    effect: dict = {"kind": kind, "price": price}
    if kind == "fifty":
        effect["removed"] = iq_service.fifty(puzzle, rng)
    elif kind == "hint":
        effect |= iq_service.hint(puzzle, rng)
    elif kind == "time":
        game.extra_seconds += iq_service.EXTRA_TIME
        effect["extra_seconds"] = game.extra_seconds
    elif kind == "reveal":
        # Temps illimité : voit la solution, 0 point, puis énigme suivante.
        if game.served_at is not None:
            game.elapsed_ms += int((_now() - game.served_at).total_seconds() * 1000)
        game.answered = True
        game.results = [*game.results, [puzzle.level, False, None]]
        game.finished = game.number >= len(game.puzzles)
        effect["revealed"] = True
        effect["correct"] = False
        effect["points"] = 0
        effect["answer"] = None
        effect["elapsed_ms"] = 0
        effect["speed"] = None
        effect["puzzle"] = puzzle.reveal()
        if game.finished:
            effect["iq"] = iq_service.iq_estimate(game.results)
            effect["correct_count"] = game.correct
    else:  # skip : une autre énigme du même niveau, chrono relancé
        used = {p["id"] for p in game.puzzles}
        replacement = iq_service.draw(puzzle.level, exclude=used, rng=rng)
        puzzles = list(game.puzzles)
        puzzles[game.number - 1] = replacement.reveal()
        game.puzzles = puzzles
        game.served_at = _now()
        game.extra_seconds = 0
    game.jokers = [*game.jokers, kind]
    effect["wallet"] = wallet_service.snapshot(profile).as_dict()
    effect["game"] = _public(game)
    return effect


async def settle_past_days(session: AsyncSession) -> None:
    """Récompense le podium des jours passés pas encore payés (une seule fois par jour)."""
    days = (
        await session.scalars(
            select(IqSession.day)
            .where(IqSession.day.is_not(None), IqSession.day < today(), IqSession.finished.is_(True))
            .distinct()
        )
    ).all()
    for day in days:
        if await session.get(IqDailyPayout, day) is not None:
            continue
        session.add(IqDailyPayout(day=day))
        for game, prize in zip(await _ranking(session, day, len(DAILY_PRIZES)), DAILY_PRIZES):
            await wallet_service.credit(session, game.client_id, prize, "iq_daily_prize", reference=day.isoformat())
        await session.flush()


async def _ranking(session: AsyncSession, day: date, limit: int) -> list[IqSession]:
    return list(
        (
            await session.scalars(
                select(IqSession)
                .where(IqSession.day == day, IqSession.finished.is_(True))
                .order_by(IqSession.score.desc(), IqSession.elapsed_ms.asc(), IqSession.created_at.asc())
                .limit(limit)
            )
        ).all()
    )


def _row(rank: int, game: IqSession) -> dict:
    return {
        "rank": rank,
        "client_id": game.client_id,
        "nickname": game.nickname,
        "score": game.score,
        "correct": game.correct,
        "elapsed_ms": game.elapsed_ms,
    }


async def leaderboard(session: AsyncSession, client_id: str | None, limit: int = 20) -> dict:
    await settle_past_days(session)
    day = today()
    top = await _ranking(session, day, 500)
    me = None
    played = False
    if client_id:
        mine = await session.scalar(select(IqSession).where(IqSession.client_id == client_id, IqSession.day == day))
        played = mine is not None
        for rank, game in enumerate(top, 1):
            if game.client_id == client_id:
                me = _row(rank, game)
    yesterday = await _ranking(session, day - timedelta(days=1), len(DAILY_PRIZES))
    return {
        "day": day.isoformat(),
        "count": DAILY_COUNT,
        "prizes": DAILY_PRIZES,
        "played": played,
        "me": me,
        "top": [_row(rank, game) for rank, game in enumerate(top[:limit], 1)],
        "yesterday": [_row(rank, game) | {"prize": prize} for rank, (game, prize) in enumerate(zip(yesterday, DAILY_PRIZES), 1)],
    }
