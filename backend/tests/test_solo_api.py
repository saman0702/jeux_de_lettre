from datetime import timedelta

import pytest

from app.models.base import utcnow
from app.services import game_service, letter_service

GAME = {"language": "fr", "rounds": 5, "round_duration": 30, "nickname": "Blaise"}


@pytest.fixture
def letter_m(monkeypatch):
    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "M")


async def create_game(client, **overrides) -> dict:
    response = await client.post("/api/v1/solo/games", json={**GAME, **overrides})
    assert response.status_code == 201, response.text
    return response.json()


async def test_config_lists_game_options(client):
    response = await client.get("/api/v1/config")
    assert response.json()["languages"] == ["fr", "en"]
    assert response.json()["duration_options"] == [15, 30, 45, 60]


async def test_create_game_rejects_unknown_options(client):
    response = await client.post("/api/v1/solo/games", json={**GAME, "rounds": 7})
    assert response.status_code == 422


async def test_full_round(client, letter_m):
    game = await create_game(client)
    assert game["status"] == "playing"
    assert game["categories"] == ["city", "country", "animal", "fruit"]

    round_ = (await client.post(f"/api/v1/solo/games/{game['id']}/rounds")).json()
    assert round_["number"] == 1
    assert round_["letter"] == "M"
    assert round_["duration"] == 30

    response = await client.post(
        f"/api/v1/solo/games/{game['id']}/rounds/1/submit",
        json={"answers": {"city": "Marseille", "country": "maroc", "animal": "Chat", "fruit": ""}},
    )
    body = response.json()

    statuses = {a["category"]: (a["status"], a["points"]) for a in body["round"]["answers"]}
    assert statuses == {
        "city": ("valid", 10),
        "country": ("valid", 10),
        "animal": ("wrong_letter", 0),
        "fruit": ("empty", 0),
    }
    assert body["round"]["round_score"] == 20
    assert body["game"]["total_score"] == 20
    assert body["game"]["rounds_played"] == 1


async def test_cannot_start_a_round_while_one_is_running(client, letter_m):
    game = await create_game(client)
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")

    response = await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    assert response.status_code == 409
    assert response.json()["detail"] == "round_in_progress"


async def test_cannot_submit_twice(client, letter_m):
    game = await create_game(client)
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    url = f"/api/v1/solo/games/{game['id']}/rounds/1/submit"
    await client.post(url, json={"answers": {}})

    response = await client.post(url, json={"answers": {"city": "Madrid"}})
    assert response.json()["detail"] == "round_already_submitted"


async def test_late_submission_scores_zero(client, letter_m, monkeypatch):
    game = await create_game(client)
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")

    later = utcnow() + timedelta(seconds=60)
    monkeypatch.setattr(game_service, "utcnow", lambda: later)
    response = await client.post(
        f"/api/v1/solo/games/{game['id']}/rounds/1/submit",
        json={"answers": {"city": "Marseille"}},
    )

    body = response.json()
    assert {a["status"] for a in body["round"]["answers"]} == {"late"}
    assert body["game"]["total_score"] == 0


async def test_abandoned_round_is_closed_when_next_round_starts(client, letter_m, monkeypatch):
    game = await create_game(client)
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")

    later = utcnow() + timedelta(seconds=60)
    monkeypatch.setattr(game_service, "utcnow", lambda: later)
    response = await client.post(f"/api/v1/solo/games/{game['id']}/rounds")

    assert response.json()["number"] == 2
    summary = (await client.get(f"/api/v1/solo/games/{game['id']}")).json()
    assert summary["rounds"][0]["round_score"] == 0


async def test_game_finishes_after_last_round(client):
    game = await create_game(client, categories=["country"])
    letters = []
    for number in range(1, 6):
        round_ = (await client.post(f"/api/v1/solo/games/{game['id']}/rounds")).json()
        letters.append(round_["letter"])
        result = await client.post(
            f"/api/v1/solo/games/{game['id']}/rounds/{number}/submit", json={"answers": {}}
        )

    assert result.json()["game"]["status"] == "finished"
    assert len(set(letters)) == 5, "a letter must not repeat within a game"

    response = await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    assert response.json()["detail"] == "game_finished"

    summary = (await client.get(f"/api/v1/solo/games/{game['id']}")).json()
    assert [r["number"] for r in summary["rounds"]] == [1, 2, 3, 4, 5]


async def test_unknown_game_returns_404(client):
    response = await client.get("/api/v1/solo/games/nope")
    assert response.status_code == 404
