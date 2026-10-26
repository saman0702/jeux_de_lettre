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
SOLO_DURATIONS = (15, 30, 45, 60)


class IqPlayError(Exception):
    def __init__(self, code: str, status_code: int = 409):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


def today() -> date:
    return datetime.now(UTC).date()


def _now() -> datetime:
    return datetime.now(UTC)


def _draw(count: int, difficulty: str, rng: random.Random) -> list[dict]:
    used: set[str] = set()
    puzzles = []
    for number in range(1, count + 1):
        puzzle = iq_service.draw(iq_service.level_for(number, count, difficulty), exclude=used, rng=rng)
        used.add(puzzle.id)
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
        "jokers_used": list(game.jokers),
        "joker_prices": iq_service.JOKER_PRICES if game.mode == "solo" else {},
        "puzzle": _current(game).public(),
    }


async def start_solo(
    session: AsyncSession,
    client_id: str,
    rounds: int,
    duration: int,
    difficulty: str,
    speed_bonus: bool,
    penalty: bool,
    nickname: str | None = None,
) -> dict:
    if rounds not in SOLO_ROUNDS or duration not in SOLO_DURATIONS:
        raise IqPlayError("invalid_settings", 422)
    profile = await wallet_service.get_profile(session, client_id)
    game = IqSession(
        client_id=client_id,
        nickname=nickname or profile.nickname,
        mode="solo",
        duration=duration,
        speed_bonus=speed_bonus,
        penalty=penalty,
        puzzles=_draw(rounds, difficulty, random.Random()),
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


async def answer(session: AsyncSession, game_id: str, client_id: str, raw: str | None) -> dict:
    game = await _game(session, game_id, client_id)
    if game.finished or game.answered or game.served_at is None:
        raise IqPlayError("already_answered")
    puzzle = _current(game)
    allowed = game.duration + game.extra_seconds
    elapsed = (_now() - game.served_at).total_seconds()
    # Réponse arrivée trop tard (au-delà du temps et d'une petite marge) : comme pas de réponse.
    late = elapsed > allowed + GRACE_SECONDS
    given = None if late or raw is None or not str(raw).strip() else str(raw)[:16]
    correct = given is not None and iq_service.check(puzzle, given)
    points = iq_service.points(
        correct, given is not None, min(elapsed, allowed), game.duration, game.speed_bonus, game.penalty
    )
    game.answered = True
    game.score += points
    game.correct += int(correct)
    game.results = [*game.results, [puzzle.level, correct]]
    game.elapsed_ms += int(min(elapsed, allowed) * 1000)
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
        "score": game.score,
        "puzzle": puzzle.reveal(),
        "finished": game.finished,
        "wallet": wallet,
    }
    if game.finished:
        result["correct_count"] = game.correct
        result["iq"] = iq_service.iq_estimate([(lvl, ok) for lvl, ok in game.results])
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
    if game.finished or game.answered or kind in game.jokers:
        raise IqPlayError("joker_unavailable")
    puzzle = _current(game)
    if kind not in iq_service.JOKER_PRICES or not iq_service.joker_allowed(puzzle, kind):
        raise IqPlayError("joker_unavailable")
    price = iq_service.JOKER_PRICES[kind]
    try:
        profile = await wallet_service.debit(session, client_id, price, f"iq_joker_{kind}", reference=game.id)
    except wallet_service.WalletError as error:
        raise IqPlayError(error.code, 402) from None
    rng = random.Random()
    effect: dict = {"kind": kind, "price": price}
    if kind == "fifty":
        effect["removed"] = iq_service.fifty(puzzle, rng)
    elif kind == "hint":
        effect["low"], effect["high"] = iq_service.hint_range(puzzle, rng)
    elif kind == "time":
        game.extra_seconds += iq_service.EXTRA_TIME
        effect["extra_seconds"] = game.extra_seconds
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
