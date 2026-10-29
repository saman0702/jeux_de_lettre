"""Le client_id est public : sans le jeton secret de l'appli, on ne peut pas agir pour un joueur."""

from httpx import ASGITransport, AsyncClient

from app.core import rate_limit
from app.core.config import settings
from app.main import app
from tests.conftest import auth

CLIENT = "victim-0001"
GAME = {"language": "fr", "rounds": 5, "round_duration": 30, "nickname": "Blaise"}


def raw_client() -> AsyncClient:
    """Client sans le crochet qui signe les requêtes : comme un tiers qui ne connaît que l'id."""
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_a_profile_needs_its_secret_token(client):
    # Le vrai joueur se présente le premier : son jeton est enregistré.
    assert (await client.get(f"/api/v1/profiles/{CLIENT}")).status_code == 200
    async with raw_client() as other:
        missing = await other.get(f"/api/v1/profiles/{CLIENT}")
        assert missing.status_code == 401 and missing.json()["detail"] == "missing_token"
        wrong = await other.get(f"/api/v1/profiles/{CLIENT}", headers={"X-Client-Token": "x" * 32})
        assert wrong.status_code == 401 and wrong.json()["detail"] == "invalid_token"
        bonus = await other.post(f"/api/v1/profiles/{CLIENT}/daily-bonus", headers={"X-Client-Token": "x" * 32})
        assert bonus.status_code == 401
        rename = await other.put(f"/api/v1/profiles/{CLIENT}", json={"nickname": "Pirate"}, headers={"X-Client-Token": "x" * 32})
        assert rename.status_code == 401
        good = await other.get(f"/api/v1/profiles/{CLIENT}", headers=auth(CLIENT))
        assert good.status_code == 200 and good.json()["nickname"] != "Pirate"


async def test_nobody_can_start_a_solo_game_in_someone_elses_name(client):
    await client.get(f"/api/v1/profiles/{CLIENT}")
    async with raw_client() as other:
        stolen = await other.post("/api/v1/solo/games", json={**GAME, "client_id": CLIENT}, headers={"X-Client-Token": "y" * 32})
        assert stolen.status_code == 401
        anonymous = await other.post("/api/v1/solo/games", json=GAME)
        assert anonymous.status_code == 201, "a game without a player stays open to all"


async def test_saved_room_lists_need_the_token(client):
    await client.get(f"/api/v1/profiles/{CLIENT}")
    async with raw_client() as other:
        assert (await other.get("/api/v1/rooms/mine", params={"client_id": CLIENT})).status_code == 401
        public = await other.get("/api/v1/rooms/public", params={"client_id": CLIENT})
        assert public.status_code == 200, "public rooms stay readable by everyone"


async def test_api_requests_are_limited_per_address(client, monkeypatch):
    monkeypatch.setattr(settings, "rate_limit_per_minute", 3)
    monkeypatch.setattr(rate_limit, "limiter", rate_limit.RequestLimiter())
    codes = [(await client.get("/api/v1/config")).status_code for _ in range(5)]
    assert codes == [200, 200, 200, 429, 429]
    assert (await client.get("/health")).status_code == 200, "health checks are never limited"


def test_request_window_slides():
    limiter = rate_limit.RequestLimiter()
    assert all(limiter.allow("ip", 2, now=t) for t in (0.0, 1.0))
    assert not limiter.allow("ip", 2, now=2.0)
    assert limiter.allow("ip", 2, now=61.5), "a minute later it is allowed again"


def test_message_bucket_refills():
    bucket = rate_limit.MessageBucket(rate=10, burst=3)
    assert [bucket.take(now=bucket._at) for _ in range(4)] == [True, True, True, False]
    assert bucket.take(now=bucket._at + 0.2)
