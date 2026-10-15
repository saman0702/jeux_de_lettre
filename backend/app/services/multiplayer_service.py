"""Persistence and scoring of multiplayer games (duel, rooms, quick match).

The live orchestration lives in room_service; this module only talks to the
database, reusing the models of solo games.
"""

from dataclasses import dataclass, field
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import Category, Difficulty
from app.models import Game, GameRound, Player, PlayerAnswer, Submission
from app.models.base import utcnow
from app.schemas.game import GameSettings
from app.services import letter_service
from app.services.scoring_service import score_round
from app.services.validation_service import Status, ValidationResult, validate_answer


@dataclass
class RoundInfo:
    number: int
    letter: str
    started_at: datetime
    ends_at: datetime


@dataclass
class PlayerRoundResult:
    player_id: str
    answers: list[dict]
    round_score: int
    elapsed_ms: int | None  # None when the player did not submit


@dataclass
class RoundOutcome:
    number: int
    letter: str
    results: list[PlayerRoundResult] = field(default_factory=list)


async def create_game(
    session: AsyncSession, mode: str, settings: GameSettings, nicknames: dict[str, str]
) -> tuple[str, dict[str, str]]:
    """Create the game and its players. Returns the game id and client id -> player id."""
    players = {client_id: Player(nickname=name) for client_id, name in nicknames.items()}
    game = Game(
        mode=mode,
        language=settings.language,
        difficulty=settings.difficulty,
        categories=[c.value for c in settings.categories],
        total_rounds=settings.rounds,
        round_duration=settings.round_duration,
        status="playing",
        players=list(players.values()),
        rounds=[],
    )
    session.add(game)
    await session.commit()
    return game.id, {client_id: player.id for client_id, player in players.items()}


async def add_player(session: AsyncSession, game_id: str, nickname: str) -> str:
    player = Player(game_id=game_id, nickname=nickname)
    session.add(player)
    await session.commit()
    return player.id


async def _game(session: AsyncSession, game_id: str) -> Game:
    return await session.scalar(select(Game).where(Game.id == game_id))


async def start_round(session: AsyncSession, game_id: str) -> RoundInfo:
    game = await _game(session, game_id)
    counts = await letter_service.letter_counts(session, game.language)
    eligible = letter_service.eligible_letters(counts, game.categories, Difficulty(game.difficulty))
    letter = letter_service.draw_letter(eligible, (r.letter for r in game.rounds))

    started_at = utcnow()
    game_round = GameRound(
        number=len(game.rounds) + 1,
        letter=letter,
        started_at=started_at,
        ends_at=started_at + timedelta(seconds=game.round_duration),
        submissions=[],
    )
    game.rounds.append(game_round)
    await session.commit()
    return RoundInfo(game_round.number, letter, started_at, game_round.ends_at)


async def close_round(
    session: AsyncSession,
    game_id: str,
    participants: list[str],
    submissions: dict[str, tuple[datetime, dict[Category, str]]],
    hints: dict[str, dict[str, bool]] | None = None,
) -> RoundOutcome:
    """Validate and score everyone's answers for the current round.

    `participants` are the player ids that played the round; those missing
    from `submissions` score zero. `hints` maps player id -> category ->
    whether the picked hint option was the right one.
    """
    hints = hints or {}
    game = await _game(session, game_id)
    game_round = game.current_round
    players = {p.id: p for p in game.players}

    validated: dict[str, dict[str, ValidationResult]] = {}
    for player_id in participants:
        _, answers = submissions.get(player_id, (None, {}))
        validated[player_id] = {}
        for category in game.categories:
            raw = answers.get(Category(category), "")
            if player_id not in submissions:
                result = ValidationResult(Status.LATE)
            elif hints.get(player_id, {}).get(category) is False:
                result = ValidationResult(Status.HINT_WRONG)
            else:
                result = await validate_answer(
                    session, Category(category), game.language, game_round.letter, raw
                )
            validated[player_id][category] = result

    points = score_round(validated, {pid: set(h) for pid, h in hints.items()})
    outcome = RoundOutcome(game_round.number, game_round.letter)
    for player_id in participants:
        submitted_at, answers = submissions.get(player_id, (game_round.ends_at, {}))
        answer_rows = [
            PlayerAnswer(
                category=category,
                raw_value=answers.get(Category(category), "")[:200],
                matched_value=result.matched_value if result.is_valid else None,
                status=result.status,
                points=points[player_id][category],
                hinted=category in hints.get(player_id, {}),
            )
            for category, result in validated[player_id].items()
        ]
        score = sum(points[player_id].values())
        game_round.submissions.append(
            Submission(
                player_id=player_id,
                submitted_at=min(submitted_at, game_round.ends_at),
                score=score,
                answers=answer_rows,
            )
        )
        players[player_id].total_score += score
        elapsed = (
            int((min(submitted_at, game_round.ends_at) - game_round.started_at).total_seconds() * 1000)
            if player_id in submissions
            else None
        )
        outcome.results.append(
            PlayerRoundResult(
                player_id=player_id,
                answers=[
                    {
                        "category": a.category,
                        "value": a.raw_value,
                        "status": a.status,
                        "points": a.points,
                        "matched_value": a.matched_value,
                        "hinted": a.hinted,
                    }
                    for a in answer_rows
                ],
                round_score=score,
                elapsed_ms=elapsed,
            )
        )

    game_round.finished = True
    await session.commit()
    return outcome


async def finish_game(session: AsyncSession, game_id: str) -> None:
    game = await _game(session, game_id)
    game.status = "finished"
    await session.commit()
