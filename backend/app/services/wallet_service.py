"""Porte-monnaie des joueurs : conversion des points en pièces, mises et gains.

Toute variation du solde passe par ce module et laisse une ligne dans
coin_transactions."""

import re
from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import LEVEL_XP_STEP, POINTS_PER_COIN
from app.models import AvatarReport, CoinTransaction, Profile

CLIENT_ID = re.compile(r"^[A-Za-z0-9-]{8,64}$")


class WalletError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


@dataclass(frozen=True)
class WalletUpdate:
    coins: int
    coins_gained: int
    points_to_next_coin: int
    level: int = 1
    # Points gagnés dans le niveau actuel / points à gagner pour passer au suivant.
    level_xp: int = 0
    level_xp_needed: int = LEVEL_XP_STEP

    def as_dict(self) -> dict:
        return {
            "coins": self.coins,
            "coins_gained": self.coins_gained,
            "points_to_next_coin": self.points_to_next_coin,
            "level": self.level,
            "level_xp": self.level_xp,
            "level_xp_needed": self.level_xp_needed,
        }


def level_threshold(level: int) -> int:
    """Total de points nécessaire pour atteindre [level]."""
    return LEVEL_XP_STEP * level * (level - 1) // 2


def level_of(total_points: int) -> tuple[int, int, int]:
    """Niveau, points dans ce niveau et points à gagner pour le suivant."""
    level = 1
    while level_threshold(level + 1) <= total_points:
        level += 1
    start = level_threshold(level)
    return level, total_points - start, level_threshold(level + 1) - start


def is_client_id(value: str | None) -> bool:
    return bool(value) and bool(CLIENT_ID.match(value))


async def get_profile(session: AsyncSession, client_id: str, nickname: str | None = None) -> Profile:
    """Profil du joueur, créé au premier passage."""
    if not is_client_id(client_id):
        raise WalletError("invalid_client_id")
    profile = await session.get(Profile, client_id)
    if profile is None:
        profile = Profile(client_id=client_id, nickname=nickname or "Joueur", coins=0, total_points=0, points_balance=0)
        session.add(profile)
        await session.flush()
    elif nickname and profile.nickname != nickname:
        profile.nickname = nickname
    return profile


def avatar_url(profile: Profile) -> str | None:
    return f"/media/avatars/{profile.avatar_file}" if profile.avatar_file else None


REPORTS_TO_HIDE = 3


async def report_avatar(session: AsyncSession, reporter_id: str, reported_id: str) -> bool:
    """Enregistre un signalement de la photo actuelle du joueur. Renvoie vrai quand la photo vient
    d'être retirée (trop de signalements) : le joueur repasse alors sur son avatar dessiné."""
    profile = await session.get(Profile, reported_id)
    if profile is None or not profile.avatar_file or reporter_id == reported_id:
        return False
    file = profile.avatar_file
    exists = await session.scalar(
        select(AvatarReport.id).where(AvatarReport.reporter_id == reporter_id, AvatarReport.avatar_file == file)
    )
    if exists is None:
        session.add(AvatarReport(reporter_id=reporter_id, reported_id=reported_id, avatar_file=file))
        await session.flush()
    count = await session.scalar(select(func.count()).where(AvatarReport.avatar_file == file))
    if count >= REPORTS_TO_HIDE:
        profile.avatar_file = None
        return True
    return False


def snapshot(profile: Profile, gained: int = 0) -> WalletUpdate:
    level, xp, needed = level_of(profile.total_points)
    return WalletUpdate(profile.coins, gained, POINTS_PER_COIN - profile.points_balance, level, xp, needed)


async def award_points(
    session: AsyncSession, client_id: str, points: int, reference: str | None = None
) -> WalletUpdate:
    """Ajoute des points gagnés en jeu ; chaque tranche de 20 donne une pièce."""
    profile = await get_profile(session, client_id)
    points = max(0, points)
    profile.total_points += points
    profile.points_balance += points
    gained, profile.points_balance = divmod(profile.points_balance, POINTS_PER_COIN)
    if gained:
        profile.coins += gained
        session.add(CoinTransaction(client_id=client_id, amount=gained, reason="points", reference=reference))
    return snapshot(profile, gained)


async def debit(session: AsyncSession, client_id: str, amount: int, reason: str, reference: str | None = None) -> Profile:
    profile = await get_profile(session, client_id)
    if profile.coins < amount:
        raise WalletError("not_enough_coins")
    profile.coins -= amount
    session.add(CoinTransaction(client_id=client_id, amount=-amount, reason=reason, reference=reference))
    return profile


async def credit(session: AsyncSession, client_id: str, amount: int, reason: str, reference: str | None = None) -> Profile:
    profile = await get_profile(session, client_id)
    profile.coins += amount
    session.add(CoinTransaction(client_id=client_id, amount=amount, reason=reason, reference=reference))
    return profile
