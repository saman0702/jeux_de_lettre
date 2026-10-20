import base64
from datetime import UTC, datetime, timedelta
from urllib.parse import urlencode

import httpx
import pytest
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

from app.api.ads.router import get_admob_verifier
from app.api.shop.router import get_store_verifier
from app.core.config import settings
from app.main import app
from app.services.perks_service import AdMobVerifier
from app.services.store_service import StoreError, VerifiedPurchase

CLIENT = "flore-0001"
GAME = {"language": "fr", "rounds": 5, "round_duration": 30, "nickname": "Flore"}


class FakeStore:
    """Store de test : jetons « ok-… » valides, abonnement payé pour [days] jours."""

    def __init__(self, days: int = 30):
        self.days = days

    async def verify(self, platform, product_id, token):
        if not token.startswith("ok-"):
            raise StoreError("invalid_purchase")
        return VerifiedPurchase(product_id, f"GPA.{token}")

    async def verify_subscription(self, platform, product_id, token):
        if not token.startswith("ok-"):
            raise StoreError("invalid_purchase")
        return VerifiedPurchase(product_id, "GPA.sub", datetime.now(UTC) + timedelta(days=self.days))


@pytest.fixture
def flags(monkeypatch):
    """Active les options demandées, comme dans le .env."""

    def enable(**values):
        for name, value in values.items():
            monkeypatch.setattr(settings, name, value)

    return enable


@pytest.fixture
def store():
    fake = FakeStore()
    app.dependency_overrides[get_store_verifier] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_store_verifier, None)


async def buy(client, product, token):
    return await client.post(
        "/api/v1/shop/purchases",
        json={"client_id": CLIENT, "platform": "android", "product_id": product, "token": token},
    )


async def test_config_tells_the_app_what_is_enabled(client, flags):
    features = (await client.get("/api/v1/config")).json()["features"]
    assert not any(features[k] for k in ("rewarded_ads", "interstitial_ads", "remove_ads", "subscription"))

    flags(feature_rewarded_ads=True, feature_subscription=True, interstitial_every_games=4)
    features = (await client.get("/api/v1/config")).json()["features"]
    assert features["rewarded_ads"] and features["subscription"]
    assert not features["interstitial_ads"]
    assert features["interstitial_every_games"] == 4


# ------------------------------------------------------------------ pubs récompensées


async def test_rewarded_ads_are_off_unless_enabled(client, flags):
    flags(rewarded_ads_trust_client=True)
    response = await client.post("/api/v1/ads/reward", json={"client_id": CLIENT, "reward_id": "r1"})
    assert (response.status_code, response.json()["detail"]) == (403, "feature_disabled")


async def test_client_reported_rewards_only_when_trusted(client, flags):
    flags(feature_rewarded_ads=True)
    response = await client.post("/api/v1/ads/reward", json={"client_id": CLIENT, "reward_id": "r1"})
    assert (response.status_code, response.json()["detail"]) == (403, "server_verification_only")


async def test_rewarded_video_gives_coins_within_the_daily_limit(client, flags):
    flags(feature_rewarded_ads=True, rewarded_ads_trust_client=True, rewarded_ad_coins=5, rewarded_ads_per_day=2)
    first = await client.post("/api/v1/ads/reward", json={"client_id": CLIENT, "reward_id": "r1"})
    assert (first.json()["coins"], first.json()["coins_gained"]) == (5, 5)
    again = await client.post("/api/v1/ads/reward", json={"client_id": CLIENT, "reward_id": "r1"})
    assert again.json()["coins"] == 5, "the same video is paid once"
    await client.post("/api/v1/ads/reward", json={"client_id": CLIENT, "reward_id": "r2"})
    assert (await client.get(f"/api/v1/profiles/{CLIENT}")).json()["ad_rewards_left"] == 0
    third = await client.post("/api/v1/ads/reward", json={"client_id": CLIENT, "reward_id": "r3"})
    assert (third.status_code, third.json()["detail"]) == (429, "daily_limit_reached")


def admob_query(key, key_id: int, params: dict) -> str:
    """Rappel AdMob signé comme le fait Google : signature et key_id en dernier."""
    message = urlencode(params)
    signature = key.sign(message.encode(), ec.ECDSA(hashes.SHA256()))
    encoded = base64.urlsafe_b64encode(signature).rstrip(b"=").decode()
    return f"{message}&signature={encoded}&key_id={key_id}"


async def test_admob_server_callback_is_verified(client, flags):
    flags(feature_rewarded_ads=True, rewarded_ad_coins=5)
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
    ).decode()
    keys = httpx.MockTransport(lambda request: httpx.Response(200, json={"keys": [{"keyId": 7, "pem": pem}]}))
    app.dependency_overrides[get_admob_verifier] = lambda: AdMobVerifier("https://keys.test", keys)
    try:
        params = {"ad_unit": "123", "reward_amount": "1", "transaction_id": "tx-42", "user_id": CLIENT}
        response = await client.get(f"/api/v1/ads/reward-callback?{admob_query(key, 7, params)}")
        assert response.status_code == 200, response.text
        assert (await client.get(f"/api/v1/profiles/{CLIENT}")).json()["coins"] == 5

        forged = admob_query(key, 7, params).replace("tx-42", "tx-43")
        response = await client.get(f"/api/v1/ads/reward-callback?{forged}")
        assert (response.status_code, response.json()["detail"]) == (403, "invalid_signature")
    finally:
        app.dependency_overrides.pop(get_admob_verifier, None)


# ------------------------------------------------------------------ « Sans pub » et Pass


async def test_remove_ads_purchase(client, flags, store):
    assert (await buy(client, "remove_ads", "ok-1")).json()["detail"] == "unknown_product"
    flags(feature_remove_ads=True)
    response = await buy(client, "remove_ads", "ok-1")
    assert response.status_code == 200, response.text
    assert response.json()["ads_removed"] is True
    assert response.json()["coins"] == 0
    # Restauration sur un nouveau téléphone : même achat, toujours sans pub.
    assert (await buy(client, "remove_ads", "ok-1")).json()["ads_removed"] is True
    assert (await client.get(f"/api/v1/profiles/{CLIENT}")).json()["ads_removed"] is True


async def test_pass_gives_daily_coins_and_extra_hints(client, flags, store):
    flags(feature_subscription=True, pass_daily_coins=20, pass_bonus_hints=2)
    response = await buy(client, "pass_monthly", "ok-sub")
    assert response.status_code == 200, response.text
    assert response.json()["pass_expires_at"] is not None

    profile = (await client.get(f"/api/v1/profiles/{CLIENT}")).json()
    assert profile["daily_bonus_available"] is True
    bonus = await client.post(f"/api/v1/profiles/{CLIENT}/daily-bonus")
    assert (bonus.json()["coins"], bonus.json()["coins_gained"]) == (20, 20)
    again = await client.post(f"/api/v1/profiles/{CLIENT}/daily-bonus")
    assert (again.status_code, again.json()["detail"]) == (409, "already_claimed")

    game = (await client.post("/api/v1/solo/games", json={**GAME, "client_id": CLIENT})).json()
    assert game["hints_left"] == 5, "3 jokers + 2 for Pass holders"


async def test_expired_pass_is_renewed_from_the_store(client, flags, store):
    flags(feature_subscription=True)
    store.days = -1
    await buy(client, "pass_monthly", "ok-sub")
    assert (await client.get(f"/api/v1/profiles/{CLIENT}")).json()["daily_bonus_available"] is False
    # Le store a renouvelé l'abonnement : la lecture du profil le redemande.
    store.days = 30
    assert (await client.get(f"/api/v1/profiles/{CLIENT}")).json()["daily_bonus_available"] is True


async def test_without_pass_no_daily_bonus(client, flags):
    flags(feature_subscription=True)
    response = await client.post(f"/api/v1/profiles/{CLIENT}/daily-bonus")
    assert (response.status_code, response.json()["detail"]) == (403, "no_pass")
