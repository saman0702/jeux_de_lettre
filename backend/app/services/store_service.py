"""Vérification des achats de pièces auprès de Google Play et de l'App Store.

L'appli n'est jamais crue sur parole : le serveur redemande chaque achat au store avant de créditer
les pièces. Les identifiants des stores se règlent dans le .env (voir docs/BOUTIQUE.md).
"""

import base64
import json
import time
from dataclasses import dataclass
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


class StoreVerifier(Protocol):
    async def verify(self, platform: str, product_id: str, token: str) -> VerifiedPurchase: ...


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
        signed = response.json()["signedTransactionInfo"]
        # Réponse obtenue directement d'Apple en HTTPS : on lit la charge utile du JWS.
        payload = signed.split(".")[1]
        return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))

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
