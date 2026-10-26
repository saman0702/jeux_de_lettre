from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.client_auth import verified_client
from app.core.database import get_session
from app.models import Profile
from app.schemas.game import CosmeticIn, CosmeticResult, LookOut, ProfileOut, ProfileUpdate, UnequipIn, WalletOut
from app.api.shop.router import get_store_verifier
from app.services import avatar_service, perks_service, shop_service, wallet_service
from app.services.store_service import StoreVerifier

# Toutes ces routes agissent sur le profil d'un joueur : son jeton secret est exigé.
router = APIRouter(prefix="/api/v1/profiles", tags=["profiles"], dependencies=[Depends(verified_client)])


def profile_out(profile: Profile, ad_rewards_left: int = 0) -> ProfileOut:
    snap = wallet_service.snapshot(profile)
    return ProfileOut(
        ads_removed=bool(profile.ads_removed),
        pass_expires_at=profile.pass_expires_at,
        ad_rewards_left=ad_rewards_left,
        daily_bonus_available=perks_service.daily_bonus_available(profile),
        client_id=profile.client_id,
        nickname=profile.nickname,
        coins=profile.coins,
        total_points=profile.total_points,
        points_to_next_coin=snap.points_to_next_coin,
        level=snap.level,
        avatar_preset=profile.avatar_preset,
        avatar_url=wallet_service.avatar_url(profile),
        look=LookOut(**wallet_service.look_of(profile)),
    )


def _cosmetic_result(profile: Profile) -> CosmeticResult:
    snap = wallet_service.snapshot(profile)
    return CosmeticResult(**snap.as_dict(), look=LookOut(**wallet_service.look_of(profile)))


async def _profile(session: AsyncSession, client_id: str) -> Profile:
    try:
        return await wallet_service.get_profile(session, client_id)
    except wallet_service.WalletError as error:
        raise HTTPException(status_code=422, detail=error.code) from None


@router.get("/{client_id}", response_model=ProfileOut)
async def get_profile(
    client_id: str,
    session: AsyncSession = Depends(get_session),
    verifier: StoreVerifier = Depends(get_store_verifier),
):
    """Profil du joueur (pièces, avatar, avantages) ; créé au premier appel."""
    profile = await _profile(session, client_id)
    if profile.pass_token and not perks_service.pass_active(profile):
        await shop_service.refresh_pass(session, verifier, profile)
    await session.commit()
    return profile_out(profile, await perks_service.ad_rewards_left(session, client_id))


@router.post("/{client_id}/daily-bonus", response_model=WalletOut)
async def claim_daily_bonus(client_id: str, session: AsyncSession = Depends(get_session)):
    """Bonus de pièces du jour, pour les abonnés au Pass."""
    profile = await _profile(session, client_id)
    try:
        wallet = await perks_service.claim_daily_bonus(session, profile)
    except perks_service.PerkError as error:
        raise HTTPException(status_code=error.status_code, detail=error.code) from None
    await session.commit()
    return wallet.as_dict()


async def _avatar_changed(request: Request, profile: Profile) -> None:
    """Les salles où se trouve le joueur affichent tout de suite son nouvel avatar."""
    await request.app.state.room_manager.update_avatar(
        profile.client_id, profile.avatar_preset, wallet_service.avatar_url(profile)
    )


@router.put("/{client_id}", response_model=ProfileOut)
async def update_profile(
    client_id: str, data: ProfileUpdate, request: Request, session: AsyncSession = Depends(get_session)
):
    """Change le pseudo ou l'avatar dessiné (choisir un avatar dessiné retire la photo)."""
    profile = await _profile(session, client_id)
    if data.nickname is not None:
        profile.nickname = data.nickname
    previous = None
    if data.avatar_preset is not None:
        profile.avatar_preset = data.avatar_preset
        previous, profile.avatar_file = profile.avatar_file, None
    await session.commit()
    if previous:
        avatar_service.delete_avatar(previous)
    if data.avatar_preset is not None:
        await _avatar_changed(request, profile)
    return profile_out(profile)


@router.post("/{client_id}/avatar", response_model=ProfileOut)
async def upload_avatar(
    client_id: str,
    request: Request,
    photo: UploadFile = File(...),
    session: AsyncSession = Depends(get_session),
):
    """Reçoit une photo (appareil photo ou galerie) et la remplace par sa version dessinée."""
    profile = await _profile(session, client_id)
    data = await photo.read(avatar_service.MAX_UPLOAD_BYTES + 1)
    try:
        profile.avatar_file = avatar_service.save_avatar(client_id, data, profile.avatar_file)
    except avatar_service.AvatarError as error:
        raise HTTPException(status_code=error.status_code, detail=error.code) from None
    await session.commit()
    await _avatar_changed(request, profile)
    return profile_out(profile)


async def _apply_look(request: Request, profile: Profile) -> None:
    """Le salon affiche tout de suite les apparences équipées."""
    await request.app.state.room_manager.update_look(
        profile.client_id,
        hair=profile.cosmetic_hair,
        hat=profile.cosmetic_hat,
        frame=profile.cosmetic_frame,
        name_style=profile.cosmetic_name,
    )


@router.post("/{client_id}/cosmetics/buy", response_model=CosmeticResult)
async def buy_cosmetic(
    client_id: str, data: CosmeticIn, request: Request, session: AsyncSession = Depends(get_session)
):
    """Achète une apparence avec des pièces et l'équipe."""
    try:
        profile = await wallet_service.buy_cosmetic(session, client_id, data.item_id)
    except wallet_service.WalletError as error:
        await session.rollback()
        status = 402 if error.code == "not_enough_coins" else 422
        raise HTTPException(status_code=status, detail=error.code) from None
    await session.commit()
    await _apply_look(request, profile)
    return _cosmetic_result(profile)


@router.post("/{client_id}/cosmetics/equip", response_model=CosmeticResult)
async def equip_cosmetic(
    client_id: str, data: CosmeticIn, request: Request, session: AsyncSession = Depends(get_session)
):
    """Équipe une apparence déjà achetée."""
    try:
        profile = await wallet_service.equip_cosmetic(session, client_id, data.item_id)
    except wallet_service.WalletError as error:
        raise HTTPException(status_code=422, detail=error.code) from None
    await session.commit()
    await _apply_look(request, profile)
    return _cosmetic_result(profile)


@router.post("/{client_id}/cosmetics/unequip", response_model=CosmeticResult)
async def unequip_cosmetic(
    client_id: str, data: UnequipIn, request: Request, session: AsyncSession = Depends(get_session)
):
    """Retire l'apparence équipée d'un emplacement."""
    try:
        profile = await wallet_service.unequip_cosmetic(session, client_id, data.kind)
    except wallet_service.WalletError as error:
        raise HTTPException(status_code=422, detail=error.code) from None
    await session.commit()
    await _apply_look(request, profile)
    return _cosmetic_result(profile)
