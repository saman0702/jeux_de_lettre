"""Limites de débit : protège le serveur d'un client qui l'inonde de requêtes.

- API : au plus `rate_limit_per_minute` requêtes par minute et par adresse IP (0 = pas de limite).
- Temps réel : chaque connexion a un « seau » de messages qui se remplit à vitesse fixe ; un
  message reçu quand le seau est vide est ignoré.

En mémoire, par processus : suffisant pour une seule instance du serveur.
"""

import time
from collections import deque

from fastapi import Request
from fastapi.responses import JSONResponse

from app.core.config import settings

# Ni la santé (surveillance) ni les images ne comptent.
_EXEMPT_PREFIXES = ("/health", "/media")
_WINDOW = 60.0


class RequestLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, deque[float]] = {}
        self._last_cleanup = time.monotonic()

    def allow(self, key: str, limit: int, now: float | None = None) -> bool:
        now = time.monotonic() if now is None else now
        hits = self._hits.setdefault(key, deque())
        while hits and now - hits[0] > _WINDOW:
            hits.popleft()
        if len(hits) >= limit:
            return False
        hits.append(now)
        if now - self._last_cleanup > _WINDOW:
            self._cleanup(now)
        return True

    def _cleanup(self, now: float) -> None:
        """Oublie les adresses sans requête récente (la mémoire ne grossit pas)."""
        self._last_cleanup = now
        for key in [k for k, h in self._hits.items() if not h or now - h[-1] > _WINDOW]:
            del self._hits[key]


limiter = RequestLimiter()


def client_ip(request: Request) -> str:
    """Derrière le proxy (Dokploy / Traefik), la vraie adresse est la première de X-Forwarded-For."""
    forwarded = request.headers.get("x-forwarded-for", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


async def limit_requests(request: Request, call_next):
    limit = settings.rate_limit_per_minute
    if limit > 0 and not request.url.path.startswith(_EXEMPT_PREFIXES):
        if not limiter.allow(client_ip(request), limit):
            return JSONResponse(status_code=429, content={"detail": "too_many_requests"})
    return await call_next(request)


class MessageBucket:
    """Seau de messages d'une connexion temps réel : `rate` par seconde, `burst` d'avance."""

    def __init__(self, rate: float = 10, burst: int = 30) -> None:
        self.rate = rate
        self.burst = burst
        self._tokens = float(burst)
        self._at = time.monotonic()

    def take(self, now: float | None = None) -> bool:
        now = time.monotonic() if now is None else now
        self._tokens = min(self.burst, self._tokens + (now - self._at) * self.rate)
        self._at = now
        if self._tokens < 1:
            return False
        self._tokens -= 1
        return True
