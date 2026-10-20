import asyncio
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


@pytest.fixture(scope="session", autouse=True)
def database():
    asyncio.run(_prepare_database())


@pytest.fixture
async def session_factory():
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.execute(text("TRUNCATE games, profiles, saved_rooms CASCADE"))
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
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()
