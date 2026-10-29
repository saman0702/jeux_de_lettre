import random

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import client_auth
from app.core.database import get_session
from app.services import iq_play_service, iq_service
from app.services.iq_play_service import IqPlayError

router = APIRouter(prefix="/api/v1/iq", tags=["iq"])

CLIENT_ID = r"^[A-Za-z0-9-]{8,64}$"


@router.get("/puzzles")
async def solo_puzzles(
    count: int = Query(default=10, ge=1, le=30),
    difficulty: str = Query(default="normal", pattern="^(easy|normal|hard)$"),
):
    """Énigmes avec leurs réponses, pour un solo joué sur le téléphone (sans pièces)."""
    rng = random.Random()
    used: set[str] = set()
    puzzles = []
    for number in range(1, count + 1):
        puzzle = iq_service.draw(iq_service.level_for(number, count, difficulty), exclude=used, rng=rng)
        used.add(puzzle.id)
        puzzles.append(puzzle.reveal())
    return puzzles


class SoloIn(BaseModel):
    client_id: str = Field(pattern=CLIENT_ID)
    rounds: int = 10
    duration: int = 30
    difficulty: str = Field(default="normal", pattern="^(easy|normal|hard)$")
    speed_bonus: bool = True
    penalty: bool = False


class PlayerIn(BaseModel):
    client_id: str = Field(pattern=CLIENT_ID)


class AnswerIn(PlayerIn):
    answer: str | None = Field(default=None, max_length=16)


class JokerIn(PlayerIn):
    kind: str = Field(pattern="^(fifty|hint|time|skip)$")


async def _run(session: AsyncSession, call):
    try:
        result = await call
    except IqPlayError as error:
        await session.rollback()
        raise HTTPException(status_code=error.status_code, detail=error.code) from None
    await session.commit()
    return result


@router.post("/solo")
async def start_solo(
    data: SoloIn, session: AsyncSession = Depends(get_session), x_client_token: str | None = Header(default=None)
):
    """Solo en ligne : les réponses sont vérifiées par le serveur et les points rapportent des pièces."""
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(
        session,
        iq_play_service.start_solo(
            session, data.client_id, data.rounds, data.duration, data.difficulty, data.speed_bonus, data.penalty
        ),
    )


@router.post("/daily")
async def start_daily(
    data: PlayerIn, session: AsyncSession = Depends(get_session), x_client_token: str | None = Header(default=None)
):
    """Défi du jour : les mêmes énigmes pour tous, une tentative par jour."""
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.start_daily(session, data.client_id))


@router.get("/daily/leaderboard")
async def daily_leaderboard(
    client_id: str | None = Query(default=None, pattern=CLIENT_ID),
    session: AsyncSession = Depends(get_session),
):
    """Classement du défi du jour (et podium d'hier) ; verse les primes des jours passés."""
    result = await iq_play_service.leaderboard(session, client_id)
    await session.commit()
    return result


@router.post("/sessions/{game_id}/answer")
async def answer(
    game_id: str,
    data: AnswerIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.answer(session, game_id, data.client_id, data.answer))


@router.post("/sessions/{game_id}/next")
async def next_puzzle(
    game_id: str,
    data: PlayerIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.next_puzzle(session, game_id, data.client_id))


@router.post("/sessions/{game_id}/joker")
async def joker(
    game_id: str,
    data: JokerIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Joker payant : 50/50, indice, +15 s ou passer (solo seulement)."""
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.use_joker(session, game_id, data.client_id, data.kind))
