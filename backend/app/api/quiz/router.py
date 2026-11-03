from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import client_auth
from app.core.database import get_session
from app.services import quiz_play_service

router = APIRouter(prefix="/api/v1/quiz", tags=["quiz"])

CLIENT_ID = r"^[A-Za-z0-9-]{8,64}$"


class AnswerIn(BaseModel):
    id: str = Field(min_length=1, max_length=32)
    choice: int | None = Field(default=None, ge=0, le=3)


class FinishSoloIn(BaseModel):
    client_id: str = Field(pattern=CLIENT_ID)
    game: str = Field(pattern="^(chrono|mots)$")
    answers: list[AnswerIn] = Field(default_factory=list, max_length=15)


@router.post("/solo/finish")
async def finish_solo(
    data: FinishSoloIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Fin d'un solo Chrono / Mot : points vérifiés → pièces si en ligne."""
    await client_auth.check(session, data.client_id, x_client_token)
    try:
        result = await quiz_play_service.finish_solo(
            session,
            data.client_id,
            data.game,
            [a.model_dump() for a in data.answers],
        )
    except Exception as error:  # noqa: BLE001 — renvoyé en 400
        await session.rollback()
        raise HTTPException(status_code=400, detail=str(error)) from error
    await session.commit()
    return result
