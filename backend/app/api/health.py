from fastapi import APIRouter
from sqlalchemy import text

from app.core.database import engine
from app.core.redis import redis_client

router = APIRouter(tags=["health"])


async def check_postgres() -> bool:
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


async def check_redis() -> bool:
    try:
        return bool(await redis_client.ping())
    except Exception:
        return False


@router.get("/health")
async def health():
    postgres_ok = await check_postgres()
    redis_ok = await check_redis()
    return {
        "status": "ok" if postgres_ok and redis_ok else "degraded",
        "postgres": postgres_ok,
        "redis": redis_ok,
    }
