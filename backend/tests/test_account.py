"""Supprimer son compte (Réglages > Supprimer mon compte)."""

from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select

from app.main import app
from app.models import CoinPurchase, CoinTransaction, IqSession, Profile, RoomGame, RoomMember, RoomMessage, SavedRoom
from app.services import room_store, wallet_service

ME = "leaver-0001"
FRIEND = "friend-0001"


async def _count(session, model, *where):
    return await session.scalar(select(func.count()).select_from(model).where(*where))


async def test_deleting_my_account_erases_my_data(client, session):
    # Un joueur avec des pièces, un achat, une partie de QI, un salon, des messages, un classement.
    await client.get(f"/api/v1/profiles/{ME}")
    await client.get(f"/api/v1/profiles/{FRIEND}")
    await wallet_service.credit(session, ME, 40, "bet_win")
    session.add(CoinPurchase(client_id=ME, platform="android", product_id="coins_100", store_token="tok-leaver", coins=100))
    await room_store.save_room(session, "MINE1", ME, "Leaver", True, "fr", {})
    await room_store.save_room(session, "HIS01", FRIEND, "Friend", True, "fr", {})
    await session.flush()
    for code in ("MINE1", "HIS01"):
        await room_store.join(session, code, ME, "Leaver")
    await room_store.join(session, "HIS01", FRIEND, "Friend")
    await room_store.add_message(session, "HIS01", ME, "Leaver", "salut")
    await room_store.add_message(session, "HIS01", FRIEND, "Friend", "coucou")
    await room_store.record_game(
        session, "HIS01", None, "rounds", 5,
        [{"client_id": FRIEND, "nickname": "Friend", "score": 30, "bot": False},
         {"client_id": ME, "nickname": "Leaver", "score": 20, "bot": False}],
    )
    await session.commit()
    await client.post("/api/v1/iq/solo", json={"client_id": ME, "rounds": 5, "duration": 30})

    response = await client.delete(f"/api/v1/profiles/{ME}")
    assert response.status_code == 200 and response.json() == {"ok": True}

    session.expire_all()
    assert await session.get(Profile, ME) is None
    assert await _count(session, CoinTransaction, CoinTransaction.client_id == ME) == 0
    assert await _count(session, IqSession, IqSession.client_id == ME) == 0
    assert await session.get(SavedRoom, "MINE1") is None, "rooms I created go away"
    assert await session.get(SavedRoom, "HIS01") is not None, "others' rooms stay"
    assert await _count(session, RoomMember, RoomMember.client_id == ME) == 0
    assert await _count(session, RoomMessage, RoomMessage.sender_id == ME) == 0
    assert await _count(session, RoomMessage, RoomMessage.sender_id == FRIEND) == 1
    ranking = (await session.scalars(select(RoomGame.ranking).where(RoomGame.room_code == "HIS01"))).one()
    assert [r["nickname"] for r in ranking] == ["Friend", "Joueur supprimé"]
    assert all(r["client_id"] != ME for r in ranking)
    # L'achat reste (un reçu ne se crédite pas deux fois), sans lien avec le joueur.
    purchase = (await session.scalars(select(CoinPurchase).where(CoinPurchase.store_token == "tok-leaver"))).one()
    assert purchase.client_id == "deleted-accounts"


async def test_nobody_else_can_delete_my_account(client):
    await client.get(f"/api/v1/profiles/{ME}")
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as other:
        refused = await other.delete(f"/api/v1/profiles/{ME}", headers={"X-Client-Token": "x" * 32})
        assert refused.status_code == 401
    assert (await client.get(f"/api/v1/profiles/{ME}")).status_code == 200
