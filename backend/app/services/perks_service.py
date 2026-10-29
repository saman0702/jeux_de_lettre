"""Revenus en plus de la vente de pièces : pubs récompensées, achat « Sans pub », abonnement Pass.

Chaque option s'active ou se coupe dans le .env (FEATURE_…) ; l'appli lit ces réglages au démarrage
via /api/v1/config et n'affiche que ce qui est actif.
"""

import base64
import time
from datetime import UTC, datetime
from urllib.parse import parse_qs

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import CoinTransaction, Profile
from app.services import wallet_service

REMOVE_ADS_PRODUCT = "remove_ads"
PASS_PRODUCT = "pass_monthly"
ADMOB_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json"


class PerkError(Exception):
    def __init__(self, code: str, status_code: int = 400):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


def features() -> dict:
    """Ce que l'appli doit proposer, d'après le .env."""
    return {
        "rewarded_ads": settings.feature_rewarded_ads,
        "rewarded_ad_coins": settings.rewarded_ad_coins,
        "rewarded_ads_per_day": settings.rewarded_ads_per_day,
        "interstitial_ads": settings.feature_interstitial_ads,
        "interstitial_every_games": settings.interstitial_every_games,
        "remove_ads": settings.feature_remove_ads,
        "subscription": settings.feature_subscription,
        "pass_daily_coins": settings.pass_daily_coins,
        "pass_bonus_hints": settings.pass_bonus_hints,
    }


def _now() -> datetime:
    return datetime.now(UTC)


def pass_active(profile: Profile, now: datetime | None = None) -> bool:
    return bool(profile.pass_expires_at and profile.pass_expires_at > (now or _now()))


def bonus_hints_for(profile: Profile | None) -> int:
    """Jokers en plus dans chaque partie pour les abonnés au Pass."""
    if profile is None or not settings.feature_subscription or not pass_active(profile):
        return 0
    return settings.pass_bonus_hints


def _today_start() -> datetime:
    now = _now()
    return now.replace(hour=0, minute=0, second=0, microsecond=0)


async def ad_rewards_today(session: AsyncSession, client_id: str) -> int:
    return await session.scalar(
        select(func.count()).where(
            CoinTransaction.client_id == client_id,
            CoinTransaction.reason == "ad_reward",
            CoinTransaction.created_at >= _today_start(),
        )
    ) or 0


async def ad_rewards_left(session: AsyncSession, client_id: str) -> int:
    if not settings.feature_rewarded_ads:
        return 0
    return max(0, settings.rewarded_ads_per_day - await ad_rewards_today(session, client_id))


async def grant_ad_reward(
    session: AsyncSession, client_id: str, transaction_id: str
) -> wallet_service.WalletUpdate:
    """Crédite une vidéo regardée, une seule fois par transaction et dans la limite du jour."""
    if not settings.feature_rewarded_ads:
        raise PerkError("feature_disabled", 403)
    profile = await wallet_service.get_profile(session, client_id)
    reference = f"ad:{transaction_id}"[:64]
    already = await session.scalar(select(CoinTransaction.id).where(CoinTransaction.reference == reference))
    if already is not None:
        return wallet_service.snapshot(profile)
    if await ad_rewards_left(session, client_id) <= 0:
        raise PerkError("daily_limit_reached", 429)
    coins = settings.rewarded_ad_coins
    await wallet_service.credit(session, client_id, coins, "ad_reward", reference=reference)
    return wallet_service.snapshot(profile, coins)


async def claim_daily_bonus(session: AsyncSession, profile: Profile) -> wallet_service.WalletUpdate:
    """Bonus de pièces du Pass, une fois par jour (UTC)."""
    if not settings.feature_subscription:
        raise PerkError("feature_disabled", 403)
    if not pass_active(profile):
        raise PerkError("no_pass", 403)
    today = _now().date()
    if profile.daily_bonus_on == today:
        raise PerkError("already_claimed", 409)
    profile.daily_bonus_on = today
    coins = settings.pass_daily_coins
    await wallet_service.credit(session, profile.client_id, coins, "pass_daily", reference=today.isoformat())
    return wallet_service.snapshot(profile, coins)


def daily_bonus_available(profile: Profile) -> bool:
    return settings.feature_subscription and pass_active(profile) and profile.daily_bonus_on != _now().date()


# ------------------------------------------------------------------ vérification côté serveur AdMob


class AdMobVerifier:
    """Vérifie les rappels « récompense accordée » d'AdMob (signature ECDSA de Google).

    AdMob appelle l'URL configurée sur le bloc d'annonces avec les paramètres de la récompense ;
    `signature` et `key_id` sont les deux derniers. Le message signé est tout ce qui précède
    `&signature=`.
    """

    def __init__(self, keys_url: str = ADMOB_KEYS_URL, transport: httpx.AsyncBaseTransport | None = None):
        self.keys_url = keys_url
        self.transport = transport
        self._keys: tuple[dict[str, ec.EllipticCurvePublicKey], float] | None = None

    async def _public_keys(self) -> dict[str, ec.EllipticCurvePublicKey]:
        if self._keys and self._keys[1] > time.time():
            return self._keys[0]
        async with httpx.AsyncClient(timeout=10, transport=self.transport) as client:
            response = await client.get(self.keys_url)
        response.raise_for_status()
        keys = {
            str(k["keyId"]): serialization.load_pem_public_key(k["pem"].encode())
            for k in response.json()["keys"]
        }
        # Google recommande de ne pas garder les clés plus d'un jour.
        self._keys = (keys, time.time() + 24 * 3600)
        return keys

    async def verify(self, query: str) -> dict[str, str]:
        """Renvoie les paramètres du rappel s'il est authentique, sinon lève PerkError."""
        marker = "&signature="
        if marker not in query:
            raise PerkError("invalid_signature", 403)
        message = query[: query.index(marker)].encode()
        params = {k: v[0] for k, v in parse_qs(query, keep_blank_values=True).items()}
        signature = params.get("signature", "")
        key = (await self._public_keys()).get(params.get("key_id", ""))
        if key is None:
            raise PerkError("invalid_signature", 403)
        try:
            raw = base64.urlsafe_b64decode(signature + "=" * (-len(signature) % 4))
            key.verify(raw, message, ec.ECDSA(hashes.SHA256()))
        except (InvalidSignature, ValueError):
            raise PerkError("invalid_signature", 403) from None
        return params


admob_verifier = AdMobVerifier()

