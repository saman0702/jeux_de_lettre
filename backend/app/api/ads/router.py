from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import client_auth
from app.core.config import settings
from app.core.database import get_session
from app.schemas.game import WalletOut
from app.services import perks_service
from app.services.perks_service import AdMobVerifier

router = APIRouter(prefix="/api/v1/ads", tags=["ads"])


def get_admob_verifier() -> AdMobVerifier:
    return perks_service.admob_verifier


@router.get("/reward-callback")
async def admob_reward_callback(
    request: Request,
    session: AsyncSession = Depends(get_session),
    verifier: AdMobVerifier = Depends(get_admob_verifier),
):
    """Rappel d'AdMob quand une vidéo récompensée a été regardée en entier (URL à déclarer sur le
    bloc d'annonces). L'appli transmet l'identifiant du joueur dans `user_id`."""
    try:
        params = await verifier.verify(request.url.query)
        await perks_service.grant_ad_reward(session, params.get("user_id", ""), params.get("transaction_id", ""))
    except perks_service.PerkError as error:
        raise HTTPException(status_code=error.status_code, detail=error.code) from None
    await session.commit()
    return {"ok": True}


class RewardIn(BaseModel):
    client_id: str = Field(pattern=r"^[A-Za-z0-9-]{8,64}$")
    # Identifiant unique de la vidéo vue, fourni par l'appli.
    reward_id: str = Field(min_length=1, max_length=48)


@router.post("/reward", response_model=WalletOut)
async def client_reported_reward(
    data: RewardIn,
    session: AsyncSession = Depends(get_session),
    x_client_token: str | None = Header(default=None),
):
    """Tests en local seulement (REWARDED_ADS_TRUST_CLIENT=true) : en prod, seul le rappel signé
    d'AdMob crédite les pièces."""
    if not settings.rewarded_ads_trust_client:
        raise HTTPException(status_code=403, detail="server_verification_only")
    await client_auth.check(session, data.client_id, x_client_token)
    try:
        wallet = await perks_service.grant_ad_reward(session, data.client_id, f"app:{data.reward_id}")
    except perks_service.PerkError as error:
        raise HTTPException(status_code=error.status_code, detail=error.code) from None
    await session.commit()
    return wallet.as_dict()
