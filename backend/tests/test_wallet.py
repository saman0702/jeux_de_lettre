import pytest
from sqlalchemy import select

from app.models import CoinTransaction
from app.services import letter_service, wallet_service

GAME = {"language": "fr", "rounds": 5, "round_duration": 30, "nickname": "Blaise"}
CLIENT = "flore-0001"


async def test_twenty_points_make_one_coin(session):
    update = await wallet_service.award_points(session, CLIENT, 15)
    assert (update.coins, update.coins_gained, update.points_to_next_coin) == (0, 0, 5)

    update = await wallet_service.award_points(session, CLIENT, 30)
    assert (update.coins, update.coins_gained, update.points_to_next_coin) == (2, 2, 15)
    await session.commit()

    ledger = (await session.scalars(select(CoinTransaction))).all()
    assert [(t.amount, t.reason) for t in ledger] == [(2, "points")]
    profile = await wallet_service.get_profile(session, CLIENT)
    assert profile.total_points == 45


async def test_debit_needs_enough_coins(session):
    await wallet_service.credit(session, CLIENT, 3, "bet_win")
    with pytest.raises(wallet_service.WalletError, match="not_enough_coins"):
        await wallet_service.debit(session, CLIENT, 4, "bet_stake")
    profile = await wallet_service.debit(session, CLIENT, 3, "bet_stake")
    assert profile.coins == 0


async def test_invalid_client_id_is_rejected(session):
    with pytest.raises(wallet_service.WalletError):
        await wallet_service.get_profile(session, "a b")


async def test_profile_api(client):
    response = await client.get(f"/api/v1/profiles/{CLIENT}")
    assert response.status_code == 200
    assert response.json()["coins"] == 0
    assert response.json()["points_to_next_coin"] == 20

    response = await client.put(f"/api/v1/profiles/{CLIENT}", json={"nickname": "Flore", "avatar_preset": 4})
    assert response.json()["nickname"] == "Flore"
    assert response.json()["avatar_preset"] == 4

    assert (await client.get("/api/v1/profiles/x")).status_code == 422


async def test_online_solo_game_fills_the_wallet(client, monkeypatch):
    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "M")
    game = (await client.post("/api/v1/solo/games", json={**GAME, "client_id": CLIENT})).json()
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    body = (
        await client.post(
            f"/api/v1/solo/games/{game['id']}/rounds/1/submit",
            json={"answers": {"city": "Marseille", "country": "Maroc", "fruit": "Mangue"}},
        )
    ).json()
    assert body["round"]["round_score"] == 30
    assert body["wallet"] == {"coins": 1, "coins_gained": 1, "points_to_next_coin": 10}


async def test_solo_game_without_profile_has_no_wallet(client, monkeypatch):
    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "M")
    game = (await client.post("/api/v1/solo/games", json=GAME)).json()
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    body = (await client.post(f"/api/v1/solo/games/{game['id']}/rounds/1/submit", json={"answers": {}})).json()
    assert body["wallet"] is None
