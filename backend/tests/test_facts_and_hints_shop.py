"""Infos payantes après manche + achat de joker."""

import pytest

from app.core.game_rules import CATEGORY_INFO_PRICE_MISSED, EXTRA_HINT_PRICE
from app.services import fact_service, wallet_service


def test_fact_lookup_country_and_city():
    france = fact_service.lookup_lines("country", "France", "fr")
    assert france is not None
    assert any("Continent" in line for line in france)
    assert any("Paris" in line for line in france)

    paris = fact_service.lookup_lines("city", "Paris", "fr")
    assert paris is not None
    assert any("France" in line for line in paris)

    lion = fact_service.lookup_lines("animal", "Lion", "fr")
    assert lion is not None
    assert any("carnivore" in line.lower() for line in lion)

    mango = fact_service.lookup_lines("fruit", "Mangue", "fr")
    assert mango is not None


@pytest.mark.asyncio
async def test_buy_hint_and_category_info(client, session, monkeypatch):
    from app.services import letter_service

    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "F")
    await wallet_service.credit(session, "shop-client-abc12", 50, "test")
    await session.commit()

    create = await client.post(
        "/api/v1/solo/games",
        json={
            "language": "fr",
            "difficulty": "normal",
            "categories": ["city", "country", "animal", "fruit"],
            "rounds": 5,
            "round_duration": 30,
            "nickname": "Test",
            "client_id": "shop-client-abc12",
        },
    )
    assert create.status_code == 201
    game = create.json()
    game_id = game["id"]
    assert game["hints_left"] == 3

    round_res = await client.post(f"/api/v1/solo/games/{game_id}/rounds")
    assert round_res.status_code == 201
    number = round_res.json()["number"]
    assert round_res.json()["letter"] == "F"

    buy = await client.post(f"/api/v1/solo/games/{game_id}/hint/buy")
    assert buy.status_code == 200
    body = buy.json()
    assert body["hints_left"] == 4
    assert body["price"] == EXTRA_HINT_PRICE
    assert body["wallet"]["coins"] == 50 - EXTRA_HINT_PRICE

    submit = await client.post(
        f"/api/v1/solo/games/{game_id}/rounds/{number}/submit",
        json={"answers": {"country": "France", "city": "", "animal": "", "fruit": ""}},
    )
    assert submit.status_code == 200
    answers = {a["category"]: a for a in submit.json()["round"]["answers"]}
    assert answers["country"]["status"] == "valid"
    assert answers["country"]["info_available"] is True
    assert answers["country"]["info_price"] == 1

    info = await client.post(
        f"/api/v1/solo/games/{game_id}/rounds/{number}/info",
        json={"category": "country"},
    )
    assert info.status_code == 200
    payload = info.json()
    assert payload["word"]
    assert payload["lines"]
    assert payload["price"] == 1
    coins_after = payload["wallet"]["coins"]
    assert coins_after == 50 - EXTRA_HINT_PRICE - 1

    # Second appel : gratuit (déjà débloqué).
    again = await client.post(
        f"/api/v1/solo/games/{game_id}/rounds/{number}/info",
        json={"category": "country"},
    )
    assert again.status_code == 200
    assert again.json()["price"] == 0
    assert again.json()["wallet"]["coins"] == coins_after

    # Catégorie ratée avec fiche dispo : 2 pièces.
    missed_cat = next(
        cat
        for cat, row in answers.items()
        if cat != "country" and row["info_available"] and row["status"] != "valid"
    )
    assert answers[missed_cat]["info_price"] == CATEGORY_INFO_PRICE_MISSED
    missed = await client.post(
        f"/api/v1/solo/games/{game_id}/rounds/{number}/info",
        json={"category": missed_cat},
    )
    assert missed.status_code == 200
    assert missed.json()["price"] == CATEGORY_INFO_PRICE_MISSED
    assert missed.json()["wallet"]["coins"] == coins_after - CATEGORY_INFO_PRICE_MISSED

    # Nouvelle partie : France déjà débloquée → infos gratuites / préremplies.
    create2 = await client.post(
        "/api/v1/solo/games",
        json={
            "language": "fr",
            "difficulty": "normal",
            "categories": ["country"],
            "rounds": 5,
            "round_duration": 30,
            "nickname": "Test",
            "client_id": "shop-client-abc12",
        },
    )
    game2 = create2.json()["id"]
    round2 = (
        await client.post(f"/api/v1/solo/games/{game2}/rounds")
    ).json()["number"]
    submit2 = await client.post(
        f"/api/v1/solo/games/{game2}/rounds/{round2}/submit",
        json={"answers": {"country": "France"}},
    )
    country2 = submit2.json()["round"]["answers"][0]
    assert country2["info_unlocked"] is True
    assert country2["info_price"] == 0
    assert country2["info_lines"]
