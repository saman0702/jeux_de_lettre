from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models import Profile
from app.schemas.game import ProfileOut, ProfileUpdate
from app.services import wallet_service

router = APIRouter(prefix="/api/v1/profiles", tags=["profiles"])


def profile_out(profile: Profile) -> ProfileOut:
    return ProfileOut(
        client_id=profile.client_id,
        nickname=profile.nickname,
        coins=profile.coins,
        total_points=profile.total_points,
        points_to_next_coin=wallet_service.snapshot(profile).points_to_next_coin,
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


@router.put("/{client_id}", response_model=ProfileOut)
async def update_profile(client_id: str, data: ProfileUpdate, session: AsyncSession = Depends(get_session)):
    """Change le pseudo ou l'avatar dessiné (choisir un avatar dessiné retire la photo)."""
    profile = await _profile(session, client_id)
    if data.nickname is not None:
        profile.nickname = data.nickname
    if data.avatar_preset is not None:
        profile.avatar_preset = data.avatar_preset
        profile.avatar_file = None
    await session.commit()
    return profile_out(profile)
