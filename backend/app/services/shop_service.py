"""Boutique : transforme un achat vérifié par le store en pièces, une seule fois par achat."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import COIN_PACKS
from app.models import CoinPurchase
from app.services import wallet_service
from app.services.store_service import StoreError, StoreVerifier


async def redeem(
    session: AsyncSession,
    verifier: StoreVerifier,
    client_id: str,
    platform: str,
    product_id: str,
    token: str,
) -> wallet_service.WalletUpdate:
    """Vérifie l'achat auprès du store puis crédite les pièces du pack.

    Renvoyer le même achat (appli relancée avant d'avoir confirmé l'achat au store) ne crédite pas
    une deuxième fois : on renvoie simplement le solde.
    """
    coins = COIN_PACKS.get(product_id)
    if coins is None:
        raise StoreError("unknown_product")
    try:
        profile = await wallet_service.get_profile(session, client_id)
    except wallet_service.WalletError as error:
        raise StoreError(error.code, 422) from None

    existing = await session.scalar(select(CoinPurchase).where(CoinPurchase.store_token == token))
    if existing is not None:
        if existing.client_id != client_id:
            raise StoreError("purchase_already_used", 409)
        return wallet_service.snapshot(profile)

    verified = await verifier.verify(platform, product_id, token)
    if verified.product_id != product_id:
        raise StoreError("invalid_purchase")

    purchase = CoinPurchase(
        client_id=client_id,
        platform=platform,
        product_id=product_id,
        store_token=token,
        order_id=verified.order_id,
        coins=coins,
    )
    session.add(purchase)
    try:
        await session.flush()
    except IntegrityError:
        # Le même achat est arrivé deux fois en même temps : l'autre requête l'a crédité.
        await session.rollback()
        return wallet_service.snapshot(await wallet_service.get_profile(session, client_id))
    await wallet_service.credit(session, client_id, coins, "purchase", reference=str(purchase.id))
    return wallet_service.snapshot(profile, coins)
