"""Game lifecycle. The server owns the letter, the clock and the score."""

from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import HINTS_PER_GAME, SUBMIT_GRACE_SECONDS, Category, Difficulty
from app.models import Game, GameRound, HintRequest, Player, PlayerAnswer, Submission
from app.models.base import utcnow
from app.schemas.game import SoloGameCreate
from app.services import hint_service, letter_service
from app.services.scoring_service import score_round
from app.services.validation_service import Status, ValidationResult, validate_answer


class GameError(Exception):
    def __init__(self, code: str, status_code: int = 409):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


async def get_game(session: AsyncSession, game_id: str) -> Game:
    game = await session.scalar(select(Game).where(Game.id == game_id))
    if game is None:
        raise GameError("game_not_found", 404)
    return game


async def create_solo_game(session: AsyncSession, data: SoloGameCreate) -> Game:
    game = Game(
        mode="solo",
        language=data.language,
        difficulty=data.difficulty,
        categories=[c.value for c in data.categories],
        total_rounds=data.rounds,
        round_duration=data.round_duration,
        status="playing",
        players=[Player(nickname=data.nickname)],
        rounds=[],
    )
    session.add(game)
    await session.commit()
    return game


def _is_expired(game_round: GameRound) -> bool:
    return utcnow() > game_round.ends_at + timedelta(seconds=SUBMIT_GRACE_SECONDS)


async def _close_expired_round(session: AsyncSession, game: Game, game_round: GameRound) -> None:
    """Players who never submitted get a late, zero-point submission."""
    submitted = {s.player_id for s in game_round.submissions}
    for player in game.players:
        if player.id not in submitted:
            game_round.submissions.append(
                Submission(
                    player_id=player.id,
                    submitted_at=game_round.ends_at,
                    score=0,
                    answers=[
                        PlayerAnswer(category=c, raw_value="", status=Status.LATE, points=0)
                        for c in game.categories
                    ],
                )
            )
    game_round.finished = True
    if game_round.number >= game.total_rounds:
        game.status = "finished"


async def start_next_round(session: AsyncSession, game: Game) -> GameRound:
    current = game.current_round
    if current is not None and not current.finished:
        if not _is_expired(current):
            raise GameError("round_in_progress")
        await _close_expired_round(session, game, current)

    if game.status == "finished" or len(game.rounds) >= game.total_rounds:
        await session.commit()
        raise GameError("game_finished")

    counts = await letter_service.letter_counts(session, game.language)
    eligible = letter_service.eligible_letters(counts, game.categories, Difficulty(game.difficulty))
    try:
        letter = letter_service.draw_letter(eligible, (r.letter for r in game.rounds))
    except letter_service.NoLetterAvailable:
        raise GameError("no_letter_available", 503) from None

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
    return game_round


async def hints_left(session: AsyncSession, game: Game) -> int:
    used = await session.scalar(
        select(func.count()).select_from(HintRequest).where(HintRequest.player_id == game.players[0].id)
    )
    return max(0, HINTS_PER_GAME - used)


def _playable_round(game: Game, round_number: int) -> GameRound:
    game_round = game.current_round
    if game_round is None or game_round.number != round_number:
        raise GameError("round_not_current")
    if game_round.finished or _is_expired(game_round):
        raise GameError("round_over")
    return game_round


async def _hint_for(session: AsyncSession, game_round: GameRound, player_id: str, category: str):
    return await session.scalar(
        select(HintRequest).where(
            HintRequest.round_id == game_round.id,
            HintRequest.player_id == player_id,
            HintRequest.category == category,
        )
    )


async def request_hint(
    session: AsyncSession, game: Game, round_number: int, category: Category
) -> tuple[HintRequest, int]:
    """Four options for a category; asking again returns the same ones."""
    game_round = _playable_round(game, round_number)
    if category.value not in game.categories:
        raise GameError("invalid_category", 422)
    player = game.players[0]

    existing = await _hint_for(session, game_round, player.id, category.value)
    if existing is not None:
        return existing, await hints_left(session, game)
    if await hints_left(session, game) == 0:
        raise GameError("no_hints_left")

    try:
        hint = await hint_service.build_hint(session, game.language, category.value, game_round.letter)
    except hint_service.NoHintAvailable:
        raise GameError("no_hint_available") from None
    request = HintRequest(
        round_id=game_round.id,
        player_id=player.id,
        category=category.value,
        options=hint.options,
        answer=hint.answer,
    )
    session.add(request)
    await session.commit()
    return request, await hints_left(session, game)


async def pick_hint(
    session: AsyncSession, game: Game, round_number: int, category: Category, choice: str
) -> HintRequest:
    game_round = _playable_round(game, round_number)
    request = await _hint_for(session, game_round, game.players[0].id, category.value)
    if request is None:
        raise GameError("no_hint_requested")
    if request.picked is not None:
        raise GameError("hint_already_picked")
    if choice not in request.options:
        raise GameError("invalid_choice", 422)
    request.picked = choice
    await session.commit()
    return request


async def submit_answers(
    session: AsyncSession, game: Game, round_number: int, answers: dict[Category, str]
) -> Submission:
    game_round = game.current_round
    if game_round is None or game_round.number != round_number:
        raise GameError("round_not_current")
    if game_round.finished:
        raise GameError("round_already_submitted")

    player = game.players[0]
    submitted_at = utcnow()
    late = _is_expired(game_round)

    picked = {
        h.category: h
        for h in await session.scalars(
            select(HintRequest).where(
                HintRequest.round_id == game_round.id,
                HintRequest.player_id == player.id,
                HintRequest.picked.is_not(None),
            )
        )
    }
    answers = {**answers, **{Category(c): h.picked for c, h in picked.items()}}

    results: dict[str, ValidationResult] = {}
    for category in game.categories:
        raw = answers.get(Category(category), "")
        if late:
            results[category] = ValidationResult(Status.LATE)
        elif category in picked and picked[category].picked != picked[category].answer:
            results[category] = ValidationResult(Status.HINT_WRONG)
        else:
            results[category] = await validate_answer(
                session, Category(category), game.language, game_round.letter, raw
            )

    points = score_round({player.id: results}, {player.id: set(picked)})[player.id]
    submission = Submission(
        player_id=player.id,
        submitted_at=min(submitted_at, game_round.ends_at),
        score=sum(points.values()),
        answers=[
            PlayerAnswer(
                category=category,
                raw_value=answers.get(Category(category), "")[:200],
                matched_value=result.matched_value if result.is_valid else None,
                status=result.status,
                points=points[category],
                hinted=category in picked,
            )
            for category, result in results.items()
        ],
    )
    game_round.submissions.append(submission)
    game_round.finished = True
    player.total_score += submission.score
    if game_round.number >= game.total_rounds:
        game.status = "finished"

    await session.commit()
    return submission
