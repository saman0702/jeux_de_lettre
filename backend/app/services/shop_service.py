"""Boutique : transforme un achat vérifié par le store en pièces, une seule fois par achat."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.game_rules import COIN_PACKS
from app.models import CoinPurchase, Profile
from app.services import wallet_service
from app.services.perks_service import PASS_PRODUCT, REMOVE_ADS_PRODUCT
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
    if product_id == PASS_PRODUCT:
        return await _redeem_pass(session, verifier, client_id, platform, token)
    coins = COIN_PACKS.get(product_id)
    if product_id == REMOVE_ADS_PRODUCT:
        if not settings.feature_remove_ads:
            raise StoreError("unknown_product")
        coins = 0
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
        # Achat déjà crédité (ou restauré sur un nouveau téléphone) : on réapplique l'avantage.
        if product_id == REMOVE_ADS_PRODUCT:
            profile.ads_removed = True
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
    if product_id == REMOVE_ADS_PRODUCT:
        profile.ads_removed = True
        return wallet_service.snapshot(profile)
    await wallet_service.credit(session, client_id, coins, "purchase", reference=str(purchase.id))
    return wallet_service.snapshot(profile, coins)


async def _redeem_pass(
    session: AsyncSession, verifier: StoreVerifier, client_id: str, platform: str, token: str
) -> wallet_service.WalletUpdate:
    """Abonnement Pass : le store dit jusqu'à quand il est payé (renouvellements compris)."""
    if not settings.feature_subscription:
        raise StoreError("unknown_product")
    try:
        profile = await wallet_service.get_profile(session, client_id)
    except wallet_service.WalletError as error:
        raise StoreError(error.code, 422) from None
    owner = await session.scalar(select(Profile).where(Profile.pass_token == token))
    if owner is not None and owner.client_id != client_id:
        raise StoreError("purchase_already_used", 409)
    verified = await verifier.verify_subscription(platform, PASS_PRODUCT, token)
    profile.pass_expires_at = verified.expires_at
    profile.pass_platform = platform
    profile.pass_token = token
    return wallet_service.snapshot(profile)


async def refresh_pass(session: AsyncSession, verifier: StoreVerifier, profile: Profile) -> None:
    """Pass arrivé à échéance : on redemande au store s'il a été renouvelé."""
    if not settings.feature_subscription or not profile.pass_token or not profile.pass_platform:
        return
    try:
        verified = await verifier.verify_subscription(profile.pass_platform, PASS_PRODUCT, profile.pass_token)
    except StoreError:
        return
    profile.pass_expires_at = verified.expires_at
