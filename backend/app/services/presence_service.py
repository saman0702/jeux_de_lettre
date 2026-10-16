"""Qui est en ligne : chaque WebSocket ouverte rafraîchit son signal de présence dans Redis, pour que
le compte reste juste même avec plusieurs workers d'API.
"""

import time
from typing import Protocol

from app.core.redis import redis_client

PRESENCE_KEY = "presence:online"
PRESENCE_TTL_SECONDS = 45


class PresenceStore(Protocol):
    async def touch(self, client_ids: list[str]) -> None: ...
    async def remove(self, client_id: str) -> None: ...
    async def count(self) -> int: ...


class RedisPresence:
    async def touch(self, client_ids: list[str]) -> None:
        if client_ids:
            now = time.time()
            await redis_client.zadd(PRESENCE_KEY, {cid: now for cid in client_ids})

    async def remove(self, client_id: str) -> None:
        await redis_client.zrem(PRESENCE_KEY, client_id)

    async def count(self) -> int:
        cutoff = time.time() - PRESENCE_TTL_SECONDS
        await redis_client.zremrangebyscore(PRESENCE_KEY, 0, cutoff)
        return await redis_client.zcard(PRESENCE_KEY)


class MemoryPresence:
    """Stockage en mémoire d'un seul processus, utilisé par les tests."""

    def __init__(self) -> None:
        self._seen: dict[str, float] = {}

    async def touch(self, client_ids: list[str]) -> None:
        now = time.time()
        self._seen.update({cid: now for cid in client_ids})

    async def remove(self, client_id: str) -> None:
        self._seen.pop(client_id, None)

    async def count(self) -> int:
        cutoff = time.time() - PRESENCE_TTL_SECONDS
        self._seen = {cid: t for cid, t in self._seen.items() if t >= cutoff}
        return len(self._seen)
