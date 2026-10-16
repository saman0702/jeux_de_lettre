from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.games.presenters import game_out, game_summary_out, round_result_out
from app.core.database import get_session
from app.core.game_rules import DURATION_OPTIONS, ROUND_OPTIONS, Category, Difficulty, Language
from app.models.base import utcnow
from app.schemas.game import (
    GameConfigOut,
    GameOut,
    GameSummaryOut,
    HintOut,
    HintPickIn,
    HintPickOut,
    HintRequestIn,
    RoundOut,
    SoloGameCreate,
    SubmitAnswers,
    SubmitResultOut,
)
from app.services import game_service

router = APIRouter(prefix="/api/v1", tags=["games"])


@router.get("/config", response_model=GameConfigOut)
async def get_config():
    return GameConfigOut(
        languages=list(Language),
        categories=list(Category),
        difficulties=list(Difficulty),
        round_options=list(ROUND_OPTIONS),
        duration_options=list(DURATION_OPTIONS),
    )


@router.post("/solo/games", response_model=GameOut, status_code=201)
async def create_solo_game(data: SoloGameCreate, session: AsyncSession = Depends(get_session)):
    game = await game_service.create_solo_game(session, data)
    return game_out(game, await game_service.hints_left(session, game))


@router.get("/solo/games/{game_id}", response_model=GameSummaryOut)
async def get_solo_game(game_id: str, session: AsyncSession = Depends(get_session)):
    game = await game_service.get_game(session, game_id)
    return game_summary_out(game, await game_service.hints_left(session, game))


@router.post("/solo/games/{game_id}/rounds", response_model=RoundOut, status_code=201)
async def start_round(game_id: str, session: AsyncSession = Depends(get_session)):
    game = await game_service.get_game(session, game_id)
    game_round = await game_service.start_next_round(session, game)
    return RoundOut(
        number=game_round.number,
        letter=game_round.letter,
        duration=game.round_duration,
        started_at=game_round.started_at,
        ends_at=game_round.ends_at,
        server_time=utcnow(),
    )


@router.post("/solo/games/{game_id}/rounds/{number}/submit", response_model=SubmitResultOut)
async def submit_round(
    game_id: str,
    number: int,
    data: SubmitAnswers,
    session: AsyncSession = Depends(get_session),
):
    game = await game_service.get_game(session, game_id)
    submission, wallet = await game_service.submit_answers(session, game, number, data.answers)
    return SubmitResultOut(
        round=round_result_out(game.current_round, submission),
        game=game_out(game, await game_service.hints_left(session, game)),
        wallet=wallet.as_dict() if wallet else None,
    )


@router.post("/solo/games/{game_id}/rounds/{number}/hint", response_model=HintOut)
async def request_hint(
    game_id: str,
    number: int,
    data: HintRequestIn,
    session: AsyncSession = Depends(get_session),
):
    """Quatre propositions pour une catégorie, une seule valide. Consomme un des jokers de la partie.
    """
    game = await game_service.get_game(session, game_id)
    hint, left = await game_service.request_hint(session, game, number, data.category)
    return HintOut(category=hint.category, options=hint.options, hints_left=left)


@router.post("/solo/games/{game_id}/rounds/{number}/hint/pick", response_model=HintPickOut)
async def pick_hint(
    game_id: str,
    number: int,
    data: HintPickIn,
    session: AsyncSession = Depends(get_session),
):
    game = await game_service.get_game(session, game_id)
    hint = await game_service.pick_hint(session, game, number, data.category, data.choice)
    return HintPickOut(category=hint.category, correct=hint.picked == hint.answer, answer=hint.answer)
