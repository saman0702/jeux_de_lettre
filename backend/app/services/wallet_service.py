"""Porte-monnaie des joueurs : conversion des points en pièces, mises et gains.

Toute variation du solde passe par ce module et laisse une ligne dans
coin_transactions."""

import re
from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import POINTS_PER_COIN
from app.models import CoinTransaction, Profile

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

    def as_dict(self) -> dict:
        return {
            "coins": self.coins,
            "coins_gained": self.coins_gained,
            "points_to_next_coin": self.points_to_next_coin,
        }


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


def snapshot(profile: Profile, gained: int = 0) -> WalletUpdate:
    return WalletUpdate(profile.coins, gained, POINTS_PER_COIN - profile.points_balance)


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
