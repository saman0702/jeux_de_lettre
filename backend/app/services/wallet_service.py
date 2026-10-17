"""Porte-monnaie des joueurs : conversion des points en pièces, mises et gains.

Toute variation du solde passe par ce module et laisse une ligne dans
coin_transactions."""

import re
from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import (
    COSMETIC_BY_ID,
    COSMETIC_KINDS,
    COSMETIC_PACK_BY_ID,
    LEVEL_XP_STEP,
    POINTS_PER_COIN,
)
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


def owned_cosmetics(profile: Profile) -> list[str]:
    return [item for item in profile.cosmetics_owned.split(",") if item]


def unlocked_facts(profile: Profile) -> set[str]:
    return {item for item in profile.facts_unlocked.split(",") if item}


def has_fact_unlocked(profile: Profile, unlock_id: str) -> bool:
    return unlock_id in unlocked_facts(profile)


def unlock_fact(profile: Profile, unlock_id: str) -> None:
    """Enregistre un déblocage permanent d'infos (idempotent)."""
    owned = [item for item in profile.facts_unlocked.split(",") if item]
    if unlock_id in owned:
        return
    owned.append(unlock_id)
    # Garde une marge sous la limite SQL ; les plus anciens partent en premier.
    while len(",".join(owned)) > 8000 and owned:
        owned.pop(0)
    profile.facts_unlocked = ",".join(owned)


def look_of(profile: Profile) -> dict:
    """Apparences possédées et celle équipée à chaque emplacement."""
    return {
        "owned": owned_cosmetics(profile),
        "hair": profile.cosmetic_hair,
        "hat": profile.cosmetic_hat,
        "frame": profile.cosmetic_frame,
        "name": profile.cosmetic_name,
        "tiles": profile.cosmetic_tiles,
        "victory": profile.cosmetic_victory,
    }


def _equip(profile: Profile, item: dict) -> None:
    slot = item["kind"]
    if slot == "hair":
        profile.cosmetic_hair = item["id"]
    elif slot == "hat":
        profile.cosmetic_hat = item["id"]
    elif slot == "frame":
        profile.cosmetic_frame = item["id"]
    elif slot == "name":
        profile.cosmetic_name = item["id"]
    elif slot == "tiles":
        profile.cosmetic_tiles = item["id"]
    else:
        profile.cosmetic_victory = item["id"]


async def buy_cosmetic(session: AsyncSession, client_id: str, item_id: str) -> Profile:
    """Achète une apparence (ou un pack) et l'équipe. Prix débité une seule fois."""
    if pack := COSMETIC_PACK_BY_ID.get(item_id):
        return await _buy_pack(session, client_id, pack)
    item = COSMETIC_BY_ID.get(item_id)
    if item is None:
        raise WalletError("unknown_cosmetic")
    profile = await get_profile(session, client_id)
    owned = owned_cosmetics(profile)
    if item_id in owned:
        raise WalletError("already_owned")
    await debit(session, client_id, item["price"], "cosmetic", item_id)
    owned.append(item_id)
    profile.cosmetics_owned = ",".join(owned)
    _equip(profile, item)
    return profile


async def _buy_pack(session: AsyncSession, client_id: str, pack: dict) -> Profile:
    """Achète un pack : ajoute chaque pièce manquante et les équipe."""
    profile = await get_profile(session, client_id)
    owned = owned_cosmetics(profile)
    pack_id = pack["id"]
    if pack_id in owned:
        raise WalletError("already_owned")
    # Déjà tout le contenu = inutile d'acheter le pack.
    if all(item_id in owned for item_id in pack["items"]):
        raise WalletError("already_owned")
    await debit(session, client_id, pack["price"], "cosmetic", pack_id)
    owned.append(pack_id)
    for item_id in pack["items"]:
        if item_id not in owned:
            owned.append(item_id)
        item = COSMETIC_BY_ID[item_id]
        _equip(profile, item)
    profile.cosmetics_owned = ",".join(owned)
    return profile


async def equip_cosmetic(session: AsyncSession, client_id: str, item_id: str) -> Profile:
    if item_id in COSMETIC_PACK_BY_ID:
        raise WalletError("unknown_cosmetic")
    item = COSMETIC_BY_ID.get(item_id)
    if item is None:
        raise WalletError("unknown_cosmetic")
    profile = await get_profile(session, client_id)
    if item_id not in owned_cosmetics(profile):
        raise WalletError("not_owned")
    _equip(profile, item)
    return profile


async def unequip_cosmetic(session: AsyncSession, client_id: str, kind: str) -> Profile:
    if kind not in COSMETIC_KINDS:
        raise WalletError("unknown_cosmetic")
    profile = await get_profile(session, client_id)
    if kind == "hair":
        profile.cosmetic_hair = ""
    elif kind == "hat":
        profile.cosmetic_hat = ""
    elif kind == "frame":
        profile.cosmetic_frame = ""
    elif kind == "name":
        profile.cosmetic_name = ""
    elif kind == "tiles":
        profile.cosmetic_tiles = ""
    else:
        profile.cosmetic_victory = ""
    return profile


async def credit(session: AsyncSession, client_id: str, amount: int, reason: str, reference: str | None = None) -> Profile:
    profile = await get_profile(session, client_id)
    profile.coins += amount
    session.add(CoinTransaction(client_id=client_id, amount=amount, reason=reason, reference=reference))
    return profile
