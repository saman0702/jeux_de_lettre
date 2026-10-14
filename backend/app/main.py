from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.games.router import router as games_router
from app.api.health import router as health_router
from app.core.config import settings
from app.core.database import engine
from app.core.redis import redis_client
from app.services.game_service import GameError


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await redis_client.aclose()
    await engine.dispose()


app = FastAPI(title=settings.app_name, lifespan=lifespan)
app.include_router(health_router)
app.include_router(games_router)


@app.exception_handler(GameError)
async def game_error_handler(request: Request, exc: GameError):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.code})
