"""Vérification des achats de pièces auprès de Google Play et de l'App Store.

L'appli n'est jamais crue sur parole : le serveur redemande chaque achat au store avant de créditer
les pièces. Les identifiants des stores se règlent dans le .env (voir docs/BOUTIQUE.md).
"""

import base64
import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Protocol

import httpx
import jwt

from app.core.config import settings

GOOGLE_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
GOOGLE_API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
APPLE_API = {
    "production": "https://api.storekit.itunes.apple.com",
    "sandbox": "https://api.storekit-sandbox.itunes.apple.com",
}


class StoreError(Exception):
    def __init__(self, code: str, status_code: int = 400):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


@dataclass(frozen=True)
class VerifiedPurchase:
    product_id: str
    order_id: str | None
    # Abonnements : fin de la période payée.
    expires_at: datetime | None = None


class StoreVerifier(Protocol):
    async def verify(self, platform: str, product_id: str, token: str) -> VerifiedPurchase: ...

    async def verify_subscription(self, platform: str, product_id: str, token: str) -> VerifiedPurchase: ...


def _decode_jws(signed: str) -> dict:
    """Charge utile d'un JWS d'Apple, obtenu directement d'Apple en HTTPS."""
    payload = signed.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))


def _from_millis(value) -> datetime | None:
    return datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc) if value else None


class GooglePlayVerifier:
    """API Google Play Developer, avec un compte de service (jeton OAuth signé en RS256)."""

    def __init__(self, service_account: dict, package: str, transport: httpx.AsyncBaseTransport | None = None):
        self.account = service_account
        self.package = package
        # Remplaçable dans les tests pour ne pas appeler Google.
        self.transport = transport
        self._token: tuple[str, float] | None = None

    async def _access_token(self, client: httpx.AsyncClient) -> str:
        if self._token and self._token[1] > time.time() + 60:
            return self._token[0]
        now = int(time.time())
        assertion = jwt.encode(
            {
                "iss": self.account["client_email"],
                "scope": GOOGLE_SCOPE,
                "aud": self.account["token_uri"],
                "iat": now,
                "exp": now + 3600,
            },
            self.account["private_key"],
            algorithm="RS256",
        )
        response = await client.post(
            self.account["token_uri"],
            data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
        )
        if response.status_code != 200:
            raise StoreError("store_unavailable", 503)
        body = response.json()
        self._token = (body["access_token"], now + body.get("expires_in", 3600))
        return self._token[0]

    async def verify(self, platform: str, product_id: str, token: str) -> VerifiedPurchase:
        async with httpx.AsyncClient(timeout=15, transport=self.transport) as client:
            access = await self._access_token(client)
            response = await client.get(
                f"{GOOGLE_API}/applications/{self.package}/purchases/products/{product_id}/tokens/{token}",
                headers={"Authorization": f"Bearer {access}"},
            )
        if response.status_code in (400, 404, 410):
            raise StoreError("invalid_purchase")
        if response.status_code != 200:
            raise StoreError("store_unavailable", 503)
        body = response.json()
        # 0 : payé ; 1 : annulé ; 2 : en attente (paiement en espèces, opérateur…).
        state = body.get("purchaseState")
        if state == 2:
            raise StoreError("purchase_pending", 409)
        if state != 0:
            raise StoreError("invalid_purchase")
        return VerifiedPurchase(product_id, body.get("orderId"))

    async def verify_subscription(self, platform: str, product_id: str, token: str) -> VerifiedPurchase:
        """Abonnement Google Play (API subscriptionsv2) : actif ou non, et jusqu'à quand."""
        async with httpx.AsyncClient(timeout=15, transport=self.transport) as client:
            access = await self._access_token(client)
            response = await client.get(
                f"{GOOGLE_API}/applications/{self.package}/purchases/subscriptionsv2/tokens/{token}",
                headers={"Authorization": f"Bearer {access}"},
            )
        if response.status_code in (400, 404, 410):
            raise StoreError("invalid_purchase")
        if response.status_code != 200:
            raise StoreError("store_unavailable", 503)
        body = response.json()
        state = body.get("subscriptionState", "")
        if state == "SUBSCRIPTION_STATE_PENDING":
            raise StoreError("purchase_pending", 409)
        items = [i for i in body.get("lineItems", []) if i.get("productId") == product_id]
        if not items:
            raise StoreError("invalid_purchase")
        expiry = max(datetime.fromisoformat(i["expiryTime"].replace("Z", "+00:00")) for i in items)
        return VerifiedPurchase(product_id, body.get("latestOrderId"), expiry)


class AppStoreVerifier:
    """App Store Server API, avec une clé « In-App Purchase » (jeton signé en ES256)."""

    def __init__(
        self,
        issuer_id: str,
        key_id: str,
        private_key: str,
        bundle_id: str,
        environment: str,
        transport: httpx.AsyncBaseTransport | None = None,
    ):
        self.transport = transport
        self.issuer_id = issuer_id
        self.key_id = key_id
        self.private_key = private_key
        self.bundle_id = bundle_id
        self.environment = environment

    def _token(self) -> str:
        now = int(time.time())
        return jwt.encode(
            {"iss": self.issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1", "bid": self.bundle_id},
            self.private_key,
            algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )

    async def _transaction(self, client: httpx.AsyncClient, environment: str, transaction_id: str) -> dict | None:
        response = await client.get(
            f"{APPLE_API[environment]}/inApps/v1/transactions/{transaction_id}",
            headers={"Authorization": f"Bearer {self._token()}"},
        )
        if response.status_code == 404:
            return None
        if response.status_code == 400:
            raise StoreError("invalid_purchase")
        if response.status_code != 200:
            raise StoreError("store_unavailable", 503)
        return _decode_jws(response.json()["signedTransactionInfo"])

    async def _statuses(self, client: httpx.AsyncClient, environment: str, transaction_id: str) -> dict | None:
        response = await client.get(
            f"{APPLE_API[environment]}/inApps/v1/subscriptions/{transaction_id}",
            headers={"Authorization": f"Bearer {self._token()}"},
        )
        if response.status_code == 404:
            return None
        if response.status_code == 400:
            raise StoreError("invalid_purchase")
        if response.status_code != 200:
            raise StoreError("store_unavailable", 503)
        return response.json()

    async def verify_subscription(self, platform: str, product_id: str, token: str) -> VerifiedPurchase:
        """Dernier état de l'abonnement (renouvellements compris) via l'App Store Server API."""
        async with httpx.AsyncClient(timeout=15, transport=self.transport) as client:
            statuses = await self._statuses(client, self.environment, token)
            if statuses is None and self.environment == "production":
                statuses = await self._statuses(client, "sandbox", token)
        if statuses is None or statuses.get("bundleId", self.bundle_id) != self.bundle_id:
            raise StoreError("invalid_purchase")
        best: dict | None = None
        for group in statuses.get("data", []):
            for last in group.get("lastTransactions", []):
                info = _decode_jws(last["signedTransactionInfo"])
                if info.get("productId") != product_id or info.get("revocationDate"):
                    continue
                if best is None or int(info.get("expiresDate", 0)) > int(best.get("expiresDate", 0)):
                    best = info
        if best is None:
            raise StoreError("invalid_purchase")
        return VerifiedPurchase(product_id, best.get("originalTransactionId"), _from_millis(best.get("expiresDate")))

    async def verify(self, platform: str, product_id: str, token: str) -> VerifiedPurchase:
        async with httpx.AsyncClient(timeout=15, transport=self.transport) as client:
            info = await self._transaction(client, self.environment, token)
            # Les relecteurs d'Apple et TestFlight achètent en sandbox même sur l'appli publiée.
            if info is None and self.environment == "production":
                info = await self._transaction(client, "sandbox", token)
        if info is None:
            raise StoreError("invalid_purchase")
        if info.get("bundleId") != self.bundle_id or info.get("productId") != product_id:
            raise StoreError("invalid_purchase")
        if info.get("revocationDate"):
            raise StoreError("invalid_purchase")
        return VerifiedPurchase(product_id, info.get("originalTransactionId"))


class StoreVerifiers:
    """Choisit le store selon la plateforme de l'appli."""

    def __init__(self, google: StoreVerifier | None, apple: StoreVerifier | None):
        self.by_platform = {"android": google, "ios": apple}

    async def verify(self, platform: str, product_id: str, token: str) -> VerifiedPurchase:
        verifier = self.by_platform.get(platform)
        if verifier is None:
            raise StoreError("store_not_configured", 503)
        return await verifier.verify(platform, product_id, token)

    async def verify_subscription(self, platform: str, product_id: str, token: str) -> VerifiedPurchase:
        verifier = self.by_platform.get(platform)
        if verifier is None:
            raise StoreError("store_not_configured", 503)
        return await verifier.verify_subscription(platform, product_id, token)


def _read(path: str | None) -> str | None:
    return Path(path).read_text() if path and Path(path).is_file() else None


def build_verifiers() -> StoreVerifiers:
    google = None
    if account := _read(settings.google_service_account_file):
        google = GooglePlayVerifier(json.loads(account), settings.google_play_package)
    apple = None
    key = _read(settings.apple_private_key_file)
    if key and settings.apple_issuer_id and settings.apple_key_id:
        apple = AppStoreVerifier(
            settings.apple_issuer_id, settings.apple_key_id, key, settings.apple_bundle_id, settings.apple_environment
        )
    return StoreVerifiers(google, apple)
