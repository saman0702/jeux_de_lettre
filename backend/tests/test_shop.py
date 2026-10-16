import base64
import json
import time

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa

from app.api.shop.router import get_store_verifier
from app.main import app
from app.services.store_service import (
    AppStoreVerifier,
    GooglePlayVerifier,
    StoreError,
    StoreVerifiers,
    VerifiedPurchase,
)

CLIENT = "flore-0001"


class FakeStore:
    """Store de test : accepte les jetons commençant par « ok- »."""

    def __init__(self):
        self.calls = []

    async def verify(self, platform, product_id, token):
        self.calls.append((platform, product_id, token))
        if token.startswith("pending-"):
            raise StoreError("purchase_pending", 409)
        if not token.startswith("ok-"):
            raise StoreError("invalid_purchase")
        return VerifiedPurchase(product_id, f"GPA.{token}")


@pytest.fixture
def store():
    fake = FakeStore()
    app.dependency_overrides[get_store_verifier] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_store_verifier, None)


async def buy(client, token, product="coins_550", client_id=CLIENT, platform="android"):
    return await client.post(
        "/api/v1/shop/purchases",
        json={"client_id": client_id, "platform": platform, "product_id": product, "token": token},
    )


async def test_packs_are_listed(client):
    packs = (await client.get("/api/v1/shop/packs")).json()
    assert {p["product_id"]: p["coins"] for p in packs}["coins_550"] == 550


async def test_a_verified_purchase_credits_coins_once(client, store):
    response = await buy(client, "ok-1")
    assert response.status_code == 200, response.text
    assert response.json() == {"coins": 550, "coins_gained": 550, "points_to_next_coin": 20}

    # L'appli renvoie le même achat (relancée avant d'avoir pu le confirmer) : pas de double crédit.
    again = await buy(client, "ok-1")
    assert again.json()["coins"] == 550 and again.json()["coins_gained"] == 0
    assert len(store.calls) == 1

    profile = (await client.get(f"/api/v1/profiles/{CLIENT}")).json()
    assert profile["coins"] == 550


async def test_purchase_errors(client, store):
    assert (await buy(client, "bad")).json()["detail"] == "invalid_purchase"
    response = await buy(client, "pending-1")
    assert (response.status_code, response.json()["detail"]) == (409, "purchase_pending")
    assert (await buy(client, "ok-2", product="coins_999999")).json()["detail"] == "unknown_product"

    await buy(client, "ok-3")
    response = await buy(client, "ok-3", client_id="someone-else")
    assert (response.status_code, response.json()["detail"]) == (409, "purchase_already_used")


async def test_unconfigured_store_is_reported(client):
    app.dependency_overrides[get_store_verifier] = lambda: StoreVerifiers(None, None)
    try:
        response = await buy(client, "ok-1", platform="ios")
    finally:
        app.dependency_overrides.pop(get_store_verifier, None)
    assert (response.status_code, response.json()["detail"]) == (503, "store_not_configured")


# ------------------------------------------------------------------ vérificateurs réels, réseau simulé


def pem(key) -> str:
    return key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
    ).decode()


async def test_google_play_verifier():
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    states = {"tok-paid": 0, "tok-cancelled": 1, "tok-pending": 2}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/token":
            assertion = dict(x.split("=") for x in request.content.decode().split("&"))["assertion"]
            claims = jwt.decode(assertion, key.public_key(), algorithms=["RS256"], audience="https://oauth.test/token")
            assert claims["scope"].endswith("androidpublisher")
            return httpx.Response(200, json={"access_token": "secret", "expires_in": 3600})
        assert request.headers["authorization"] == "Bearer secret"
        assert "/applications/com.test.app/purchases/products/coins_100/tokens/" in request.url.path
        token = request.url.path.rsplit("/", 1)[1]
        if token not in states:
            return httpx.Response(404)
        return httpx.Response(200, json={"purchaseState": states[token], "orderId": "GPA.1"})

    verifier = GooglePlayVerifier(
        {"client_email": "shop@test.iam", "private_key": pem(key), "token_uri": "https://oauth.test/token"},
        "com.test.app",
        transport=httpx.MockTransport(handler),
    )
    assert await verifier.verify("android", "coins_100", "tok-paid") == VerifiedPurchase("coins_100", "GPA.1")
    for token, code in [("tok-cancelled", "invalid_purchase"), ("tok-pending", "purchase_pending"), ("x", "invalid_purchase")]:
        with pytest.raises(StoreError, match=code):
            await verifier.verify("android", "coins_100", token)


def signed_transaction(info: dict) -> str:
    def part(data):
        return base64.urlsafe_b64encode(json.dumps(data).encode()).rstrip(b"=").decode()

    return f"{part({'alg': 'ES256'})}.{part(info)}.signature"


async def test_app_store_verifier_with_sandbox_fallback():
    key = ec.generate_private_key(ec.SECP256R1())
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        token = request.headers["authorization"].removeprefix("Bearer ")
        assert jwt.get_unverified_header(token)["kid"] == "KEY123"
        claims = jwt.decode(token, key.public_key(), algorithms=["ES256"], audience="appstoreconnect-v1")
        assert claims["bid"] == "com.test.app" and claims["exp"] > time.time()
        seen.append(request.url.host)
        transaction = request.url.path.rsplit("/", 1)[1]
        if "sandbox" not in request.url.host or transaction == "missing":
            return httpx.Response(404)
        info = {"bundleId": "com.test.app", "productId": "coins_100", "originalTransactionId": transaction}
        if transaction == "refunded":
            info["revocationDate"] = 1700000000000
        return httpx.Response(200, json={"signedTransactionInfo": signed_transaction(info)})

    verifier = AppStoreVerifier("issuer", "KEY123", pem(key), "com.test.app", "production", httpx.MockTransport(handler))
    assert await verifier.verify("ios", "coins_100", "2000001") == VerifiedPurchase("coins_100", "2000001")
    assert seen == ["api.storekit.itunes.apple.com", "api.storekit-sandbox.itunes.apple.com"]
    for transaction, product in [("refunded", "coins_100"), ("2000002", "coins_550"), ("missing", "coins_100")]:
        with pytest.raises(StoreError, match="invalid_purchase"):
            await verifier.verify("ios", product, transaction)
