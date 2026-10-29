from fastapi import APIRouter, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.games.presenters import game_out, game_summary_out, round_result_out
from app.core import client_auth
from app.core.database import get_session
from app.core.game_rules import (
    CATEGORY_INFO_PRICE_FOUND,
    CATEGORY_INFO_PRICE_MISSED,
    DURATION_OPTIONS,
    EXTRA_HINT_PRICE,
    ROUND_OPTIONS,
    Category,
    Difficulty,
    Language,
)
from app.models.base import utcnow
from app.schemas.game import (
    BuyHintOut,
    CategoryInfoIn,
    CategoryInfoOut,
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
from app.services import game_service, perks_service, wallet_service

router = APIRouter(prefix="/api/v1", tags=["games"])


@router.get("/config", response_model=GameConfigOut)
async def get_config():
    return GameConfigOut(
        languages=list(Language),
        categories=list(Category),
        difficulties=list(Difficulty),
        round_options=list(ROUND_OPTIONS),
        duration_options=list(DURATION_OPTIONS),
        category_info_price_found=CATEGORY_INFO_PRICE_FOUND,
        category_info_price_missed=CATEGORY_INFO_PRICE_MISSED,
        extra_hint_price=EXTRA_HINT_PRICE,
        features=perks_service.features(),
    )


@router.post("/solo/games", response_model=GameOut, status_code=201)
async def create_solo_game(
    data: SoloGameCreate,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    # Partie liée à un joueur (points, pièces, indices achetés) : son jeton est exigé.
    if data.client_id:
        await client_auth.check(session, data.client_id, x_client_token)
    game = await game_service.create_solo_game(session, data)
    return game_out(game, await game_service.hints_left(session, game))


@router.get("/solo/games/{game_id}", response_model=GameSummaryOut)
async def get_solo_game(game_id: str, session: AsyncSession = Depends(get_session)):
    game = await game_service.get_game(session, game_id)
    profile = None
    if game.owner_client_id:
        profile = await wallet_service.get_profile(session, game.owner_client_id)
    return game_summary_out(game, await game_service.hints_left(session, game), profile)


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
    unlocked: set[str] = set()
    if game.owner_client_id:
        profile = await wallet_service.get_profile(session, game.owner_client_id)
        unlocked = wallet_service.unlocked_facts(profile)
    return SubmitResultOut(
        round=round_result_out(
            game.current_round,
            submission,
            language=game.language,
            unlocked=unlocked,
        ),
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
    """Trois propositions pour une catégorie, une seule valide. Consomme un des jokers de la partie.
    """
    game = await game_service.get_game(session, game_id)
    hint, left = await game_service.request_hint(
        session, game, number, data.category, reveal=data.reveal
    )
    revealed = data.reveal and hint.picked == hint.answer
    return HintOut(
        category=hint.category,
        options=hint.options,
        hints_left=left,
        revealed=bool(revealed),
        answer=hint.answer if revealed else None,
    )


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


@router.post("/solo/games/{game_id}/hint/buy", response_model=BuyHintOut)
async def buy_hint(game_id: str, session: AsyncSession = Depends(get_session)):
    """Achète un joker supplémentaire avec des pièces."""
    game = await game_service.get_game(session, game_id)
    left, wallet = await game_service.buy_hint(session, game)
    return BuyHintOut(hints_left=left, price=EXTRA_HINT_PRICE, wallet=wallet.as_dict())


@router.post(
    "/solo/games/{game_id}/rounds/{number}/info",
    response_model=CategoryInfoOut,
)
async def buy_category_info(
    game_id: str,
    number: int,
    data: CategoryInfoIn,
    session: AsyncSession = Depends(get_session),
):
    """Dévoile les infos d'une catégorie après la manche (payant en pièces)."""
    game = await game_service.get_game(session, game_id)
    word, lines, price, wallet = await game_service.buy_category_info(
        session, game, number, data.category
    )
    return CategoryInfoOut(
        category=data.category,
        word=word,
        lines=lines,
        price=price,
        wallet=wallet.as_dict(),
    )
