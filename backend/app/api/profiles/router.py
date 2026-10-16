from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models import Profile
from app.schemas.game import ProfileOut, ProfileUpdate
from app.services import avatar_service, wallet_service

router = APIRouter(prefix="/api/v1/profiles", tags=["profiles"])


def profile_out(profile: Profile) -> ProfileOut:
    return ProfileOut(
        client_id=profile.client_id,
        nickname=profile.nickname,
        coins=profile.coins,
        total_points=profile.total_points,
        points_to_next_coin=wallet_service.snapshot(profile).points_to_next_coin,
        level=wallet_service.snapshot(profile).level,
        avatar_preset=profile.avatar_preset,
        avatar_url=wallet_service.avatar_url(profile),
    )


async def _profile(session: AsyncSession, client_id: str) -> Profile:
    try:
        return await wallet_service.get_profile(session, client_id)
    except wallet_service.WalletError as error:
        raise HTTPException(status_code=422, detail=error.code) from None


@router.get("/{client_id}", response_model=ProfileOut)
async def get_profile(client_id: str, session: AsyncSession = Depends(get_session)):
    """Profil du joueur (pièces, avatar) ; créé au premier appel."""
    profile = await _profile(session, client_id)
    await session.commit()
    return profile_out(profile)


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
