from functools import lru_cache

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.game_rules import COIN_PACKS
from app.schemas.game import WalletOut
from app.services import shop_service
from app.services.store_service import StoreError, StoreVerifier, build_verifiers

router = APIRouter(prefix="/api/v1/shop", tags=["shop"])


@lru_cache
def get_store_verifier() -> StoreVerifier:
    """Vérificateurs des stores, construits une fois depuis la configuration."""
    return build_verifiers()


class PackOut(BaseModel):
    product_id: str
    coins: int


class PurchaseIn(BaseModel):
    client_id: str = Field(pattern=r"^[A-Za-z0-9-]{8,64}$")
    platform: str = Field(pattern="^(android|ios)$")
    product_id: str = Field(max_length=64)
    # Jeton d'achat Google Play, ou identifiant de transaction App Store.
    token: str = Field(min_length=1, max_length=512)


@router.get("/packs", response_model=list[PackOut])
async def list_packs():
    """Packs vendus ; l'appli demande leurs prix au store (dans la monnaie du joueur)."""
    return [PackOut(product_id=pid, coins=coins) for pid, coins in COIN_PACKS.items()]


@router.post("/purchases", response_model=WalletOut)
async def redeem_purchase(
    data: PurchaseIn,
    session: AsyncSession = Depends(get_session),
    verifier: StoreVerifier = Depends(get_store_verifier),
):
    """Crédite un achat après l'avoir vérifié auprès du store."""
    try:
        wallet = await shop_service.redeem(session, verifier, data.client_id, data.platform, data.product_id, data.token)
    except StoreError as error:
        await session.rollback()
        raise HTTPException(status_code=error.status_code, detail=error.code) from None
    await session.commit()
    return wallet.as_dict()
