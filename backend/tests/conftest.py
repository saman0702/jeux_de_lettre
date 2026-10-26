import asyncio
import json
import re
from urllib.parse import urlsplit

import asyncpg
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import insert, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings
from app.core.database import get_session
from app.core.game_rules import ANY_LANGUAGE, Category
from app.data.seed_answers import build_rows, curated_entries
from app.main import app
from app.models import Answer, Base
from app.services import letter_service

# Les tests enchaînent des centaines de requêtes depuis la même adresse.
settings.rate_limit_per_minute = 0

TEST_DB = f"{settings.postgres_db}_test"
TEST_DATABASE_URL = settings.database_url.rsplit("/", 1)[0] + f"/{TEST_DB}"

# Garde-fou : les tests effacent et recréent leurs tables. Ils ne tournent jamais contre une base
# distante (ex. DATABASE_URL de .env.production) : il faut viser le Postgres local.
_TEST_HOST = urlsplit(TEST_DATABASE_URL.replace("+asyncpg", "")).hostname
if _TEST_HOST not in {"localhost", "127.0.0.1", "postgres"}:
    raise RuntimeError(
        f"Tests refusés sur la base distante {_TEST_HOST!r}. Lancer avec "
        "DATABASE_URL=postgresql+asyncpg://USER:PASS@localhost:5432/letterbattle"
    )

TEST_CITIES = ["Marseille", "Mbandaka", "Madrid", "Montréal", "Le Havre", "Abidjan", "Paris"]
TEST_FEMALE_NAMES = ["Marie", "Mariam", "Manon", "Awa", "Camille"]
TEST_MALE_NAMES = ["Mamadou", "Marc", "Moussa", "Kofi", "Camille"]


async def _prepare_database() -> None:
    admin = await asyncpg.connect(
        user=settings.postgres_user,
        password=settings.postgres_password,
        host=settings.postgres_host,
        port=settings.postgres_port,
        database=settings.postgres_db,
    )
    try:
        exists = await admin.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", TEST_DB)
        if not exists:
            await admin.execute(f'CREATE DATABASE "{TEST_DB}"')
    finally:
        await admin.close()

    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
        cities = ((Category.CITY, ANY_LANGUAGE, city) for city in TEST_CITIES)
        names = [(Category.FEMALE_NAME, ANY_LANGUAGE, n) for n in TEST_FEMALE_NAMES] + [
            (Category.MALE_NAME, ANY_LANGUAGE, n) for n in TEST_MALE_NAMES
        ]
        await conn.execute(
            insert(Answer), build_rows(curated_entries()) + build_rows(cities) + build_rows(iter(names))
        )
    await engine.dispose()


def token_for(client_id: str) -> str:
    """Jeton secret de l'appli d'un joueur de test."""
    return f"test-token-{client_id}"


def auth(client_id: str) -> dict[str, str]:
    return {"X-Client-Token": token_for(client_id)}


_PROFILE_PATH = re.compile(r"/api/v1/profiles/([^/?]+)")


def _client_of(request) -> str | None:
    """Joueur pour qui la requête agit : chemin /profiles/<id>, ?client_id= ou corps JSON."""
    match = _PROFILE_PATH.search(request.url.path)
    if match:
        return match.group(1)
    if request.url.params.get("client_id"):
        return request.url.params["client_id"]
    if request.headers.get("content-type", "").startswith("application/json"):
        try:
            body = json.loads(request.content or b"{}")
        except ValueError:
            return None
        if isinstance(body, dict) and isinstance(body.get("client_id"), str):
            return body["client_id"]
    return None


def sign_as_owner(request) -> None:
    """Les tests jouent le rôle de l'appli : chaque requête porte le jeton du joueur concerné
    (sauf si le test en donne un lui-même). Les refus sont testés à part, sans ce crochet."""
    if "x-client-token" in request.headers:
        return
    client_id = _client_of(request)
    if client_id:
        request.headers["X-Client-Token"] = token_for(client_id)


async def _sign_async(request) -> None:
    sign_as_owner(request)


@pytest.fixture(scope="session", autouse=True)
def database():
    asyncio.run(_prepare_database())


@pytest.fixture
async def session_factory():
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.execute(text("TRUNCATE games, profiles, saved_rooms, iq_sessions, iq_daily_payouts CASCADE"))
    letter_service.clear_cache()
    yield async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    await engine.dispose()


@pytest.fixture
async def session(session_factory):
    async with session_factory() as session:
        yield session


@pytest.fixture
async def client(session_factory):
    async def override_session():
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test", event_hooks={"request": [_sign_async]}
    ) as client:
        yield client
    app.dependency_overrides.clear()
