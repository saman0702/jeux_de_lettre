import random
from datetime import timedelta

import pytest

from app.core.game_rules import Category
from app.models.base import utcnow
from app.services import game_service, hint_service, letter_service
from app.services.hint_service import Hint, build_hint
from app.services.normalization import first_letter, normalize
from app.services.validation_service import Status, validate_answer

GAME = {"language": "fr", "rounds": 5, "round_duration": 30}


@pytest.mark.parametrize("category", ["animal", "fruit", "country", "city"])
@pytest.mark.parametrize("seed", range(5))
async def test_exactly_one_option_fits_the_category(session, category, seed):
    hint = await build_hint(session, "fr", category, "M", random.Random(seed))

    assert len(hint.options) == 4 and len(set(hint.options)) == 4
    assert all(first_letter(normalize(o)) == "M" for o in hint.options)
    valid = [
        o for o in hint.options
        if (await validate_answer(session, Category(category), "fr", "M", o)).status == Status.VALID
    ]
    assert valid == [hint.answer]


@pytest.fixture
def letter_m(monkeypatch):
    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "M")


async def start(client, **overrides):
    game = (await client.post("/api/v1/solo/games", json={**GAME, **overrides})).json()
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    return game, f"/api/v1/solo/games/{game['id']}/rounds/1"


@pytest.fixture
def fixed_hint(monkeypatch):
    async def fake(session, language, category, letter, rng=None):
        return Hint(category=category, options=["Mangue", "Mouton", "Madrid", "Maroc"], answer="Mouton")

    monkeypatch.setattr(hint_service, "build_hint", fake)


async def submit(client, url, answers):
    result = (await client.post(f"{url}/submit", json={"answers": answers})).json()
    return {a["category"]: a for a in result["round"]["answers"]}, result["game"]


async def test_right_hint_scores_half_points(client, letter_m, fixed_hint):
    game, url = await start(client, categories=["animal", "fruit"])
    assert game["hints_left"] == 3

    hint = (await client.post(f"{url}/hint", json={"category": "animal"})).json()
    assert hint == {"category": "animal", "options": ["Mangue", "Mouton", "Madrid", "Maroc"], "hints_left": 2}
    again = (await client.post(f"{url}/hint", json={"category": "animal"})).json()
    assert again == hint, "asking twice shows the same options for free"

    picked = (await client.post(f"{url}/hint/pick", json={"category": "animal", "choice": "Mouton"})).json()
    assert picked == {"category": "animal", "correct": True, "answer": "Mouton"}

    answers, game = await submit(client, url, {"animal": "typed text is ignored", "fruit": "Mangue"})
    assert (answers["animal"]["value"], answers["animal"]["status"], answers["animal"]["points"]) == ("Mouton", "valid", 5)
    assert answers["animal"]["hinted"] is True
    assert (answers["fruit"]["points"], answers["fruit"]["hinted"]) == (10, False)
    assert game["hints_left"] == 2


async def test_wrong_hint_scores_zero(client, letter_m, fixed_hint):
    _, url = await start(client, categories=["animal"])
    await client.post(f"{url}/hint", json={"category": "animal"})
    picked = (await client.post(f"{url}/hint/pick", json={"category": "animal", "choice": "Mangue"})).json()
    assert picked == {"category": "animal", "correct": False, "answer": "Mouton"}

    again = await client.post(f"{url}/hint/pick", json={"category": "animal", "choice": "Mouton"})
    assert again.json()["detail"] == "hint_already_picked"

    answers, _ = await submit(client, url, {"animal": "Mouton"})
    assert (answers["animal"]["status"], answers["animal"]["points"]) == ("hint_wrong", 0)


async def test_hint_limits_and_errors(client, letter_m):
    _, url = await start(client)
    for category in ("city", "country", "animal"):
        assert (await client.post(f"{url}/hint", json={"category": category})).status_code == 200
    over = await client.post(f"{url}/hint", json={"category": "fruit"})
    assert over.json()["detail"] == "no_hints_left"

    bad = await client.post(f"{url}/hint/pick", json={"category": "city", "choice": "Nope"})
    assert bad.status_code == 422
    missing = await client.post(f"{url}/hint/pick", json={"category": "fruit", "choice": "x"})
    assert missing.json()["detail"] == "no_hint_requested"


async def test_no_hint_after_the_round(client, letter_m, monkeypatch):
    _, url = await start(client)
    later = utcnow() + timedelta(seconds=60)
    monkeypatch.setattr(game_service, "utcnow", lambda: later)
    response = await client.post(f"{url}/hint", json={"category": "city"})
    assert response.json()["detail"] == "round_over"
