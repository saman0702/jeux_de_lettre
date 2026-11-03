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
    avoid: str | None = Query(
        default=None,
        max_length=4000,
        description="Ids déjà vus, séparés par des virgules (rejouer sans trop de doublons).",
    ),
):
    """Énigmes avec leurs réponses, pour un solo joué sur le téléphone (sans pièces)."""
    seen = {x for x in (avoid or "").split(",") if x.strip()}
    return iq_play_service._draw(count, difficulty, random.Random(), avoid=seen)


class SoloIn(BaseModel):
    client_id: str = Field(pattern=CLIENT_ID)
    rounds: int = 10
    duration: int = 30
    difficulty: str = Field(default="normal", pattern="^(easy|normal|hard)$")
    speed_bonus: bool = True
    penalty: bool = False
    # Ids déjà joués sur l'appareil : on évite de les retirer tout de suite.
    avoid: list[str] = Field(default_factory=list, max_length=120)


class PlayerIn(BaseModel):
    client_id: str = Field(pattern=CLIENT_ID)


class AnswerIn(PlayerIn):
    # Tracés « 0-1-2-… » et Flow (JSON des chemins, jusqu'à ~150 car.) ;
    # 64 tronquait toutes les réponses Flow et provoquait un 422.
    answer: str | None = Field(default=None, max_length=512)


class JokerIn(PlayerIn):
    kind: str = Field(pattern="^(fifty|hint|time|skip|reveal)$")


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
            session,
            data.client_id,
            data.rounds,
            data.duration,
            data.difficulty,
            data.speed_bonus,
            data.penalty,
            avoid={x[:80] for x in data.avoid if x},
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


@router.get("/sessions/active")
async def active_session(
    client_id: str = Query(pattern=CLIENT_ID),
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Solo inachevé (pause) pour ce joueur, ou null."""
    await client_auth.check(session, client_id, x_client_token)
    return await iq_play_service.active_solo(session, client_id)


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


@router.post("/sessions/{game_id}/pause")
async def pause_session(
    game_id: str,
    data: PlayerIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Pause après une manche : on peut quitter et reprendre plus tard."""
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.pause(session, game_id, data.client_id))


@router.post("/sessions/{game_id}/resume")
async def resume_session(
    game_id: str,
    data: PlayerIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Reprend un solo en pause (chrono relancé)."""
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.resume(session, game_id, data.client_id))


@router.post("/sessions/{game_id}/ad-break")
async def start_ad_break(
    game_id: str,
    data: JokerIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Pas assez de pièces pour ce joker : chrono figé pendant la vidéo (une fois par énigme)."""
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.start_ad_break(session, game_id, data.client_id, data.kind))


@router.post("/sessions/{game_id}/ad-break/end")
async def end_ad_break(
    game_id: str,
    data: PlayerIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Fin de la vidéo : le chrono reprend là où il était."""
    await client_auth.check(session, data.client_id, x_client_token)
    return await _run(session, iq_play_service.end_ad_break(session, game_id, data.client_id))


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
