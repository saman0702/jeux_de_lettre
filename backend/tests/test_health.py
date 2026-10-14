from fastapi.testclient import TestClient

from app.api import health
from app.main import app


def test_health_ok(monkeypatch):
    async def ok():
        return True

    monkeypatch.setattr(health, "check_postgres", ok)
    monkeypatch.setattr(health, "check_redis", ok)

    response = TestClient(app).get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "postgres": True, "redis": True}


def test_health_degraded(monkeypatch):
    async def ok():
        return True

    async def ko():
        return False

    monkeypatch.setattr(health, "check_postgres", ko)
    monkeypatch.setattr(health, "check_redis", ok)

    response = TestClient(app).get("/health")

    assert response.json()["status"] == "degraded"
