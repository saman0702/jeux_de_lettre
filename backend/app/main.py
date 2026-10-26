from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api.games.router import router as games_router
from app.api.profiles.router import router as profiles_router
from app.api.ads.router import router as ads_router
from app.api.iq.router import router as iq_router
from app.api.rooms.router import router as rooms_router
from app.api.shop.router import router as shop_router
from app.api.health import router as health_router
from app.core.config import settings
from app.core.rate_limit import limit_requests
from app.core.database import engine
from app.core.redis import redis_client
from app.services import avatar_service
from app.services.game_service import GameError
from app.services.room_service import room_manager
from app.websocket.game_ws import router as ws_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.room_manager.start()
    yield
    await app.state.room_manager.stop()
    await redis_client.aclose()
    await engine.dispose()


app = FastAPI(title=settings.app_name, lifespan=lifespan)
app.state.room_manager = room_manager
app.middleware("http")(limit_requests)
app.include_router(health_router)
app.include_router(games_router)
app.include_router(profiles_router)
app.include_router(shop_router)
app.include_router(ads_router)
app.include_router(rooms_router)
app.include_router(iq_router)
app.include_router(ws_router)
avatar_service.avatars_dir()
app.mount("/media", StaticFiles(directory=settings.media_dir), name="media")


@app.exception_handler(GameError)
async def game_error_handler(request: Request, exc: GameError):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.code})
