import asyncio
from contextlib import contextmanager
from dataclasses import replace

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool
from starlette.testclient import TestClient

from app.main import app
from app.services import letter_service, wallet_service
from app.services.presence_service import MemoryPresence
from app.services.room_service import RoomManager, Timings
from tests.conftest import TEST_DATABASE_URL

FAST = Timings(
    countdown=0.05,
    results=0.05,
    quick_start=0.2,
    reconnect_grace=0.3,
    presence_interval=0.05,
    quick_bot_fill=5.0,
    bot_speed=0.001,
)
SETTINGS = {"language": "fr", "categories": ["city", "country"], "rounds": 5, "round_duration": 30}


@pytest.fixture
def manager(monkeypatch):
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)

    async def truncate():
        async with engine.begin() as conn:
            await conn.execute(text("TRUNCATE games, profiles, saved_rooms CASCADE"))

    asyncio.run(truncate())
    letter_service.clear_cache()
    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "M")

    manager = RoomManager(
        session_factory=async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False),
        presence=MemoryPresence(),
        timings=replace(FAST),
    )
    previous = app.state.room_manager
    app.state.room_manager = manager
    yield manager
    app.state.room_manager = previous


@pytest.fixture
def client(manager):
    with TestClient(app) as client:
        yield client


@contextmanager
def player(client, client_id, nickname, language="fr", country=""):
    url = f"/ws?client_id={client_id}&nickname={nickname}&language={language}&country={country}"
    with client.websocket_connect(url) as ws:
        welcome = ws.receive_json()
        assert welcome["type"] == "welcome"
        yield ws


def wait_for(ws, predicate, limit=200):
    """Lit les messages jusqu'à en trouver un qui correspond ; les autres événements (notifications,
    compteurs) sont ignorés.
    """
    for _ in range(limit):
        message = ws.receive_json()
        if predicate(message):
            return message
    raise AssertionError("expected message never arrived")


def state(ws, phase=None, check=lambda room: True):
    return wait_for(
        ws,
        lambda m: m["type"] == "room_state"
        and (phase is None or m["room"]["phase"] == phase)
        and check(m["room"]),
    )["room"]


def error(ws):
    return wait_for(ws, lambda m: m["type"] == "error")["code"]


def create_room(ws, **settings):
    ws.send_json({"type": "create_room", "settings": {**SETTINGS, **settings}})
    return state(ws, "waiting")


def test_private_room_full_game(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice)
        assert room["host_id"] == "alice-0001"
        assert len(room["code"]) == 5

        bob.send_json({"type": "join_room", "code": room["code"].lower()})
        room = state(bob, "waiting")
        assert [p["nickname"] for p in room["players"]] == ["Alice", "Bob"]

        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})

        countdown = state(alice, "countdown")
        assert countdown["go_at"] is not None

        round_ = state(alice, "round")["round"]
        assert round_["letter"] == "M" and round_["number"] == 1
        state(bob, "round")

        alice.send_json({"type": "submit", "round": 1, "answers": {"city": "Marseille"}})
        bob.send_json({"type": "submit", "round": 1, "answers": {"city": "marseille", "country": "Maroc"}})

        results = state(alice, "results")["results"]
        scores = {p["nickname"]: p["round_score"] for p in results["players"]}
        assert scores == {"Alice": 5, "Bob": 15}, "shared answers score 5, unique ones 10"

        for number in range(2, 6):
            state(alice, "round", lambda r, n=number: r["round"]["number"] == n)
            alice.send_json({"type": "submit", "round": number, "answers": {}})
            bob.send_json({"type": "submit", "round": number, "answers": {}})

        final = state(alice, "finished")
        assert {p["nickname"]: p["score"] for p in final["players"]} == {"Alice": 5, "Bob": 15}
        assert all(not p["ready"] for p in final["players"])

        # « Rejouer » ramène la salle en attente avec les scores remis à zéro.
        alice.send_json({"type": "set_ready", "ready": True})
        lobby = state(alice, "waiting")
        assert all(p["score"] == 0 for p in lobby["players"])


def test_game_needs_everyone_ready(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice)
        bob.send_json({"type": "join_room", "code": room["code"]})
        alice.send_json({"type": "set_ready", "ready": True})
        room = state(alice, check=lambda r: r["players"][0]["ready"])
        assert room["phase"] == "waiting"


def test_join_errors(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        alice.send_json({"type": "join_room", "code": "ZZZZZ"})
        assert error(alice) == "room_not_found"

        room = create_room(alice, max_players=2)
        bob.send_json({"type": "join_room", "code": room["code"]})
        state(bob)
        with player(client, "carol-001", "Carol") as carol:
            carol.send_json({"type": "join_room", "code": room["code"]})
            assert error(carol) == "room_full"


def test_invalid_messages_are_rejected(client):
    with player(client, "alice-0001", "Alice") as alice:
        alice.send_text("not json")
        assert error(alice) == "invalid_message"
        alice.send_json({"type": "create_room", "settings": {**SETTINGS, "rounds": 7}})
        assert error(alice) == "invalid_settings"
        alice.send_json({"type": "set_ready"})
        assert error(alice) == "not_in_room"


def test_quick_match_groups_players_and_starts_automatically(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        alice.send_json({"type": "quick_match", "language": "fr"})
        first = state(alice, "waiting")
        assert first["quick"] and first["players"][0]["ready"]

        bob.send_json({"type": "quick_match", "language": "fr"})
        joined = state(bob, "waiting")
        assert joined["code"] == first["code"]
        assert joined["starts_at"] is not None

        assert state(alice, "round")["round"]["letter"] == "M"


def test_quick_match_mixes_languages(client):
    """Chacun répond dans sa langue : un francophone et un anglophone jouent ensemble."""
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob", "en") as bob:
        alice.send_json({"type": "quick_match", "language": "fr"})
        code = state(alice, "waiting")["code"]
        bob.send_json({"type": "quick_match", "language": "en"})
        assert state(bob, "waiting")["code"] == code


def test_public_rooms_are_listed(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        bob.send_json({"type": "subscribe_rooms", "language": "fr"})
        assert wait_for(bob, lambda m: m["type"] == "room_list")["rooms"] == []

        public = create_room(alice, public=True)
        rooms = wait_for(bob, lambda m: m["type"] == "room_list" and m["rooms"])["rooms"]
        assert rooms[0]["code"] == public["code"]
        assert rooms[0]["host"] == "Alice" and rooms[0]["players"] == 1
        assert rooms[0]["nicknames"] == ["Alice"]

        create_room(alice)  # privée : remplace la salle publique, désormais vide
        assert wait_for(bob, lambda m: m["type"] == "room_list")["rooms"] == []


def test_reconnect_gets_the_seat_back(client):
    with player(client, "alice-0001", "Alice") as alice:
        room = create_room(alice)
        with player(client, "bob-00001", "Bob") as bob:
            bob.send_json({"type": "join_room", "code": room["code"]})
            state(bob)
        gone = state(alice, check=lambda r: len(r["players"]) == 2 and not r["players"][1]["connected"])
        assert gone["players"][1]["nickname"] == "Bob"

        with player(client, "bob-00001", "Bob") as bob:
            back = state(bob)
            assert back["code"] == room["code"]
            assert back["players"][1]["connected"]


def test_player_who_does_not_come_back_leaves_and_host_moves(client):
    with player(client, "bob-00001", "Bob") as bob:
        with player(client, "alice-0001", "Alice") as alice:
            room = create_room(alice)
            bob.send_json({"type": "join_room", "code": room["code"]})
            state(bob, check=lambda r: len(r["players"]) == 2)
        room = state(bob, check=lambda r: len(r["players"]) == 1)
        assert room["host_id"] == "bob-00001"


def test_disconnected_player_does_not_block_the_round(client):
    with player(client, "alice-0001", "Alice") as alice:
        with player(client, "bob-00001", "Bob") as bob:
            room = create_room(alice)
            bob.send_json({"type": "join_room", "code": room["code"]})
            alice.send_json({"type": "set_ready", "ready": True})
            bob.send_json({"type": "set_ready", "ready": True})
            state(bob, "round")
        alice.send_json({"type": "submit", "round": 1, "answers": {"city": "Madrid"}})
        results = state(alice, "results")["results"]
        bob_result = next(p for p in results["players"] if p["nickname"] == "Bob")
        assert bob_result["elapsed_ms"] is None
        assert {a["status"] for a in bob_result["answers"]} == {"late"}


def test_online_count(client):
    with player(client, "alice-0001", "Alice") as alice:
        with player(client, "bob-00001", "Bob"):
            assert wait_for(alice, lambda m: m["type"] == "online_count" and m["count"] == 2)
        assert wait_for(alice, lambda m: m["type"] == "online_count" and m["count"] == 1)


def test_play_against_bots(client):
    with player(client, "alice-0001", "Alice") as alice:
        alice.send_json({
            "type": "create_room",
            "settings": {**SETTINGS, "categories": ["country"]},
            "bots": {"count": 2, "level": "hard"},
        })
        room = state(alice, "countdown")
        bots = [p for p in room["players"] if p["bot"]]
        assert len(bots) == 2 and all(b["bot_level"] == "hard" for b in bots)
        assert len({b["nickname"] for b in bots}) == 2

        state(alice, "round")
        alice.send_json({"type": "submit", "round": 1, "answers": {"country": "Maroc"}})
        results = state(alice, "results")["results"]["players"]
        assert len(results) == 3
        bot_answers = [p["answers"][0] for p in results if p["client_id"].startswith("bot-")]
        # Les bots ont répondu seuls, avec de vrais pays commençant par M.
        assert any(a["status"] == "valid" for a in bot_answers)


def test_lightning_pick_is_recorded(client, manager):
    """Après une manche, le QCM éclair enregistre le choix du joueur."""
    manager.timings.results = 2.0
    with player(client, "alice-0001", "Alice") as alice:
        alice.send_json({
            "type": "create_room",
            "settings": {**SETTINGS, "categories": ["country"], "rounds": 5},
            "bots": {"count": 1, "level": "easy"},
        })
        state(alice, "round")
        alice.send_json({"type": "submit", "round": 1, "answers": {"country": "Maroc"}})
        state(alice, "results")
        room = state(alice, "lightning")
        lightning = room["lightning"]
        assert lightning and lightning["options"]
        choice = lightning["options"][0]
        alice.send_json({"type": "lightning_pick", "choice": choice})
        updated = state(
            alice,
            "lightning",
            check=lambda r: "alice-0001" in (r.get("lightning") or {}).get("picks", {}),
        )
        pick = updated["lightning"]["picks"]["alice-0001"]
        assert pick["choice"] == choice
        assert "points" in pick


def test_host_adds_and_removes_bots(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice)
        bob.send_json({"type": "join_room", "code": room["code"]})
        state(bob, check=lambda r: len(r["players"]) == 2)

        bob.send_json({"type": "add_bot", "level": "easy"})
        assert error(bob) == "not_host"

        alice.send_json({"type": "add_bot", "level": "easy"})
        room = state(alice, check=lambda r: len(r["players"]) == 3)
        bot = room["players"][2]
        assert bot["bot"] and bot["ready"]

        alice.send_json({"type": "remove_bot", "client_id": bot["client_id"]})
        assert len(state(alice, check=lambda r: len(r["players"]) == 2)["players"]) == 2

        alice.send_json({"type": "remove_bot", "client_id": "bob-00001"})
        assert error(alice) == "not_a_bot"


def test_lonely_quick_match_gets_bots(client, manager):
    manager.timings.quick_bot_fill = 0.1
    with player(client, "alice-0001", "Alice") as alice:
        alice.send_json({"type": "quick_match", "language": "fr"})
        assert wait_for(alice, lambda m: m["type"] == "notice" and m["kind"] == "bots_joined")
        room = state(alice, "round")
        assert sum(p["bot"] for p in room["players"]) == 2


def test_room_closes_when_only_bots_remain(client, manager):
    with player(client, "alice-0001", "Alice") as alice:
        room = create_room(alice)
        alice.send_json({"type": "add_bot"})
        state(alice, check=lambda r: len(r["players"]) == 2)
        alice.send_json({"type": "leave_room"})
        wait_for(alice, lambda m: m["type"] == "left_room")
    assert room["code"] not in manager.rooms


def test_hints_in_a_room(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice, categories=["animal"])
        bob.send_json({"type": "join_room", "code": room["code"]})
        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        state(alice, "round")

        alice.send_json({"type": "hint", "round": 1, "category": "animal"})
        hint = wait_for(alice, lambda m: m["type"] == "hint")
        assert len(hint["options"]) == 4 and hint["hints_left"] == 2
        assert "answer" not in hint, "the right answer never leaves the server"

        alice.send_json({"type": "hint_pick", "round": 1, "category": "animal", "choice": hint["options"][0]})
        picked = wait_for(alice, lambda m: m["type"] == "hint_result")

        alice.send_json({"type": "submit", "round": 1, "answers": {}})
        bob.send_json({"type": "submit", "round": 1, "answers": {"animal": "Mouton"}})
        results = {p["nickname"]: p for p in state(alice, "results")["results"]["players"]}
        answer = results["Alice"]["answers"][0]
        assert answer["hinted"]
        expected = (5 if answer["value"] != "Mouton" else 2) if picked["correct"] else 0
        assert answer["points"] == expected
        assert state(alice)["players"][0]["hints_left"] == 2


def test_round_results_include_examples_for_missed_categories(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice, categories=["country", "fruit"])
        bob.send_json({"type": "join_room", "code": room["code"]})
        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        state(alice, "round")
        alice.send_json({"type": "submit", "round": 1, "answers": {"country": "Maroc"}})
        bob.send_json({"type": "submit", "round": 1, "answers": {"country": "Maroc"}})

        results = state(alice, "results")["results"]
        assert "fruit" in results["examples"] and results["examples"]["fruit"][0] == "M"
        assert "country" not in results["examples"], "personne n'a raté le pays"
        alice_fruit = next(p for p in results["players"] if p["nickname"] == "Alice")["answers"][1]
        assert alice_fruit["suggestion"] == results["examples"]["fruit"]


# ------------------------------------------------------------------ pièces et paris


def give_coins(manager, client_id, amount):
    async def run():
        async with manager.session_factory() as session:
            await wallet_service.credit(session, client_id, amount, "bet_win")
            await session.commit()

    asyncio.run(run())


def coins_of(manager, client_id):
    async def run():
        async with manager.session_factory() as session:
            return (await wallet_service.get_profile(session, client_id)).coins

    return asyncio.run(run())


def play_bet_game(alice, bob, room, alice_answers, bob_answers):
    bob.send_json({"type": "join_room", "code": room["code"]})
    state(bob, "waiting")
    alice.send_json({"type": "set_ready", "ready": True})
    bob.send_json({"type": "set_ready", "ready": True})
    state(alice, "round")
    alice.send_json({"type": "submit", "round": 1, "answers": alice_answers})
    bob.send_json({"type": "submit", "round": 1, "answers": bob_answers})
    for number in range(2, 6):
        state(alice, "round", lambda r, n=number: r["round"]["number"] == n)
        alice.send_json({"type": "submit", "round": number, "answers": {}})
        bob.send_json({"type": "submit", "round": number, "answers": {}})
    return state(alice, "finished")


def test_welcome_carries_the_wallet(client, manager):
    give_coins(manager, "alice-0001", 7)
    with client.websocket_connect("/ws?client_id=alice-0001&nickname=Alice") as ws:
        welcome = ws.receive_json()
        assert welcome["wallet"] == {"coins": 7, "coins_gained": 0, "points_to_next_coin": 20, "level": 1, "level_xp": 0, "level_xp_needed": 100, "ads_removed": False, "pass_expires_at": None}


def test_round_points_become_coins(client):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice)
        bob.send_json({"type": "join_room", "code": room["code"]})
        state(bob, "waiting")
        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        state(alice, "round")
        alice.send_json({"type": "submit", "round": 1, "answers": {"city": "Madrid", "country": "Maroc"}})
        bob.send_json({"type": "submit", "round": 1, "answers": {}})
        wallet = wait_for(alice, lambda m: m["type"] == "wallet")
        assert wallet == {"type": "wallet", "coins": 1, "coins_gained": 1, "points_to_next_coin": 20, "level": 1, "level_xp": 20, "level_xp_needed": 100, "ads_removed": False, "pass_expires_at": None}


def test_betting_room_needs_coins(client, manager):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        alice.send_json({"type": "create_room", "settings": {**SETTINGS, "kind": "bet", "stake": 5}})
        assert error(alice) == "not_enough_coins"

        give_coins(manager, "alice-0001", 5)
        room = create_room(alice, kind="bet", stake=5)
        assert room["settings"]["kind"] == "bet" and room["settings"]["stake"] == 5

        bob.send_json({"type": "join_room", "code": room["code"]})
        assert error(bob) == "not_enough_coins"

        alice.send_json({"type": "add_bot", "level": "easy"})
        assert error(alice) == "bots_not_allowed"

        alice.send_json({"type": "create_room", "settings": {**SETTINGS, "kind": "bet", "stake": 0}})
        assert error(alice) == "invalid_settings"


def test_winner_takes_the_pot(client, manager):
    give_coins(manager, "alice-0001", 10)
    give_coins(manager, "bob-00001", 10)
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice, kind="bet", stake=10)
        final = play_bet_game(alice, bob, room, {"city": "Madrid"}, {})
        assert final["pot"] == 20
        assert final["winnings"] == {"alice-0001": 20}
    assert coins_of(manager, "alice-0001") == 20
    assert coins_of(manager, "bob-00001") == 0


def test_prize_room_host_funds_winner_takes(client, manager):
    """Dotation : l'hôte place les pièces, l'invité ne paie pas, bots autorisés."""
    give_coins(manager, "alice-0001", 25)
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        alice.send_json(
            {
                "type": "create_room",
                "settings": {**SETTINGS, "kind": "prize", "stake": 15, "format": "elimination", "rounds": 2},
            }
        )
        room = state(alice, "waiting")
        assert room["settings"]["kind"] == "prize"
        alice.send_json({"type": "add_bot", "level": "easy"})
        state(alice, "waiting", lambda r: any(p.get("bot") for p in r["players"]))

        bob.send_json({"type": "join_room", "code": room["code"]})
        state(bob, "waiting")
        # Bob sans pièces peut quand même rejoindre.
        assert coins_of(manager, "bob-00001") == 0

        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        state(alice, "round")
        state(bob, "round")
        alice.send_json({"type": "submit", "round": 1, "answers": {}})
        bob.send_json({"type": "submit", "round": 1, "answers": {"city": "Madrid"}})
        state(alice, "results")
        # 2e manche pour finir (ou élimination).
        for number in range(2, 3):
            state(alice, "round", lambda r, n=number: r["round"]["number"] == n)
            alice.send_json({"type": "submit", "round": number, "answers": {}})
            bob.send_json({"type": "submit", "round": number, "answers": {"city": "Metz"}})
        final = state(alice, "finished")
        assert final["pot"] == 15
        assert final["winnings"].get("bob-00001") == 15
    assert coins_of(manager, "alice-0001") == 10  # 25 - 15
    assert coins_of(manager, "bob-00001") == 15


def test_tied_players_share_the_pot(client, manager):
    give_coins(manager, "alice-0001", 3)
    give_coins(manager, "bob-00001", 3)
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice, kind="bet", stake=3)
        final = play_bet_game(alice, bob, room, {}, {})
        assert final["winnings"] == {"alice-0001": 3, "bob-00001": 3}


def test_player_who_cannot_pay_anymore_is_sent_away(client, manager):
    give_coins(manager, "alice-0001", 5)
    give_coins(manager, "bob-00001", 5)
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice, kind="bet", stake=5)
        bob.send_json({"type": "join_room", "code": room["code"]})
        state(bob, "waiting")
        # Bob dépense ses pièces ailleurs avant le départ.
        asyncio.run(_spend(manager, "bob-00001", 5))
        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        assert error(bob) == "not_enough_coins"
        room = state(alice, "waiting", lambda r: len(r["players"]) == 1)
        assert room["pot"] == 0
    assert coins_of(manager, "alice-0001") == 5


async def _spend(manager, client_id, amount):
    async with manager.session_factory() as session:
        await wallet_service.debit(session, client_id, amount, "bet_stake")
        await session.commit()


def test_avatars_are_shared_and_photos_can_be_reported(client, manager):
    async def set_photo():
        async with manager.session_factory() as session:
            profile = await wallet_service.get_profile(session, "bob-00001")
            profile.avatar_file = "bob-00001-abcd.png"
            profile.avatar_preset = 5
            await session.commit()

    asyncio.run(set_photo())
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice)
        bob.send_json({"type": "join_room", "code": room["code"]})
        room = state(alice, check=lambda r: len(r["players"]) == 2)
        assert room["players"][1]["avatar_url"] == "/media/avatars/bob-00001-abcd.png"

        alice.send_json({"type": "report_player", "client_id": "bob-00001"})
        assert wait_for(alice, lambda m: m["type"] == "reported")["client_id"] == "bob-00001"

        alice.send_json({"type": "report_player", "client_id": "alice-0001"})
        assert error(alice) == "invalid_message"


# ------------------------------------------------------------------ éliminatoires


def test_knockout_room_eliminates_the_lowest_score_each_round(client):
    with (
        player(client, "alice-0001", "Alice") as alice,
        player(client, "bob-00001", "Bob") as bob,
        player(client, "carol-0001", "Carol") as carol,
    ):
        room = create_room(alice, format="elimination")
        assert room["settings"]["format"] == "elimination"
        for ws in (bob, carol):
            ws.send_json({"type": "join_room", "code": room["code"]})
            state(ws, "waiting")
        for ws in (alice, bob, carol):
            ws.send_json({"type": "set_ready", "ready": True})

        # Manche 1 : tout le monde à 0, personne ne sort.
        state(alice, "round")
        for ws in (alice, bob, carol):
            ws.send_json({"type": "submit", "round": 1, "answers": {}})
        assert state(alice, "results")["results"]["eliminated"] == []

        # Manche 2 : Carol n'a rien, elle sort.
        state(alice, "round", lambda r: r["round"]["number"] == 2)
        alice.send_json({"type": "submit", "round": 2, "answers": {"city": "Madrid"}})
        bob.send_json({"type": "submit", "round": 2, "answers": {"country": "Maroc"}})
        carol.send_json({"type": "submit", "round": 2, "answers": {}})
        results = state(alice, "results", lambda r: r["results"]["number"] == 2)
        assert results["results"]["eliminated"] == ["carol-0001"]
        assert {p["client_id"]: p["eliminated_round"] for p in results["players"]}["carol-0001"] == 2

        # Manche 3 : Carol regarde ; à 2 joueurs on n'élimine plus avant la dernière manche.
        round3 = state(alice, "round", lambda r: r["round"]["number"] == 3)
        assert {p["client_id"]: p["playing"] for p in round3["players"]}["carol-0001"] is False
        alice.send_json({"type": "submit", "round": 3, "answers": {"city": "Madrid"}})
        bob.send_json({"type": "submit", "round": 3, "answers": {}})
        results3 = state(alice, "results", lambda r: r["results"]["number"] == 3)
        assert results3["results"]["eliminated"] == []

        # Manches 4 puis 5 (finale) : Bob sort seulement à la dernière manche.
        state(alice, "round", lambda r: r["round"]["number"] == 4)
        alice.send_json({"type": "submit", "round": 4, "answers": {"city": "Madrid"}})
        bob.send_json({"type": "submit", "round": 4, "answers": {"country": "Maroc"}})
        state(alice, "results", lambda r: r["results"]["number"] == 4)

        state(alice, "round", lambda r: r["round"]["number"] == 5)
        alice.send_json({"type": "submit", "round": 5, "answers": {"city": "Madrid"}})
        bob.send_json({"type": "submit", "round": 5, "answers": {}})
        final = state(alice, "finished")
        assert final["round_number"] == 5
        assert {p["client_id"]: p["eliminated_round"] for p in final["players"]} == {
            "alice-0001": None,
            "bob-00001": 5,
            "carol-0001": 2,
        }


def test_knockout_rooms_cannot_be_joined_during_a_game(client):
    with (
        player(client, "alice-0001", "Alice") as alice,
        player(client, "bob-00001", "Bob") as bob,
        player(client, "carol-0001", "Carol") as carol,
    ):
        room = create_room(alice, format="elimination")
        bob.send_json({"type": "join_room", "code": room["code"]})
        state(bob, "waiting")
        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        state(alice, "round")
        carol.send_json({"type": "join_room", "code": room["code"]})
        assert error(carol) == "game_in_progress"


# ------------------------------------------------------------------ salons gardés et historique


@pytest.fixture
def http(manager):
    """Routes HTTP sur la même base de test que le gestionnaire de salons."""
    from app.core.database import get_session

    async def session():
        async with manager.session_factory() as s:
            yield s

    app.dependency_overrides[get_session] = session
    yield
    app.dependency_overrides.pop(get_session, None)


def test_a_closed_room_reopens_with_its_chat_and_creator_as_host(client, http):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        room = create_room(alice, public=False)
        code = room["code"]
        assert room["saved"] is True
        bob.send_json({"type": "join_room", "code": code})
        state(bob, "waiting", lambda r: len(r["players"]) == 2)
        bob.send_json({"type": "chat", "text": "Salut @Alice !"})
        chat = state(alice, check=lambda r: len(r["chat"]) == 1)["chat"]
        assert chat[0]["mentions"] == ["alice-0001"], "@Alice is tagged"
        assert wait_for(alice, lambda m: m["type"] == "mention")["from"] == "Bob"
        for ws in (alice, bob):
            ws.send_json({"type": "leave_room"})
            wait_for(ws, lambda m: m["type"] == "left_room")

    # Plus personne : le salon est fermé, mais gardé.
    with player(client, "bob-00001", "Bob") as bob:
        bob.send_json({"type": "join_room", "code": code})
        reopened = state(bob, "waiting")
        assert reopened["code"] == code
        assert [m["text"] for m in reopened["chat"]] == ["Salut @Alice !"]
        assert reopened["host_id"] == "bob-00001", "creator away: first back is host"
        with player(client, "alice-0001", "Alice") as alice:
            alice.send_json({"type": "join_room", "code": code})
            assert state(alice, check=lambda r: len(r["players"]) == 2)["host_id"] == "alice-0001"

    mine = client.get("/api/v1/rooms/mine", params={"client_id": "bob-00001"}).json()
    assert [r["code"] for r in mine] == [code]
    assert mine[0]["members"] == 2


def test_private_rooms_are_listed_only_for_members(client, http):
    with player(client, "alice-0001", "Alice") as alice:
        private = create_room(alice, public=False)["code"]
        alice.send_json({"type": "leave_room"})
        wait_for(alice, lambda m: m["type"] == "left_room")
        public = create_room(alice, public=True)["code"]

    others = client.get("/api/v1/rooms/public", params={"language": "fr"}).json()
    assert [r["code"] for r in others] == [public], "private room hidden from strangers"
    assert client.get(f"/api/v1/rooms/{private}/history", params={"client_id": "carol-0001"}).status_code == 404
    history = client.get(f"/api/v1/rooms/{public}/history", params={"client_id": "carol-0001"})
    assert history.status_code == 200, "anyone can read a public room"
    assert client.get(f"/api/v1/rooms/{private}/history", params={"client_id": "alice-0001"}).status_code == 200


def test_finished_games_are_kept_in_the_room_history(client, http):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        code = create_room(alice)["code"]
        bob.send_json({"type": "join_room", "code": code})
        state(bob, "waiting", lambda r: len(r["players"]) == 2)
        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        for number in range(1, 6):
            state(alice, "round", lambda r, n=number: r["round"]["number"] == n)
            answers = {"city": "Madrid"} if number == 1 else {}
            alice.send_json({"type": "submit", "round": number, "answers": answers})
            bob.send_json({"type": "submit", "round": number, "answers": {}})
        state(alice, "finished")

    games = client.get(f"/api/v1/rooms/{code}/history", params={"client_id": "bob-00001"}).json()["games"]
    assert len(games) == 1
    assert [p["nickname"] for p in games[0]["ranking"]] == ["Alice", "Bob"]
    assert games[0]["ranking"][0]["score"] == 10


def test_private_messages_cost_coins_and_stay_between_two(client, manager, http):
    with player(client, "alice-0001", "Alice") as alice, player(client, "bob-00001", "Bob") as bob:
        code = create_room(alice)["code"]
        bob.send_json({"type": "join_room", "code": code})
        state(bob, "waiting", lambda r: len(r["players"]) == 2)

        alice.send_json({"type": "dm", "to": "bob-00001", "text": "Coucou"})
        assert error(alice) == "chat_locked"

        give_coins(manager, "alice-0001", 100)
        alice.send_json({"type": "unlock_chat"})
        wait_for(alice, lambda m: m["type"] == "chat_unlocked")
        alice.send_json({"type": "dm", "to": "bob-00001", "text": "Coucou"})
        received = wait_for(bob, lambda m: m["type"] == "dm")["message"]
        assert (received["nickname"], received["to"], received["text"]) == ("Alice", "bob-00001", "Coucou")

    with player(client, "carol-0001", "Carol") as carol:
        carol.send_json({"type": "join_room", "code": code})
        state(carol, "waiting")

    def private(client_id):
        return client.get(f"/api/v1/rooms/{code}/history", params={"client_id": client_id}).json()["private"]

    assert [m["text"] for m in private("bob-00001")] == ["Coucou"]
    assert private("carol-0001") == [], "others never see private messages"


def test_rooms_without_activity_for_30_days_are_deleted(manager):
    from datetime import timedelta

    from app.models.base import utcnow
    from app.services import room_store

    async def run():
        async with manager.session_factory() as session:
            await room_store.save_room(session, "OLD01", "alice-0001", "Alice", True, "fr", {})
            await room_store.save_room(session, "NEW01", "alice-0001", "Alice", True, "fr", {})
            await session.flush()
            (await room_store.get_room(session, "OLD01")).last_activity_at = utcnow() - timedelta(days=31)
            await session.commit()
            removed = await room_store.purge_inactive(session, keep=set())
            await session.commit()
            return removed, await room_store.get_room(session, "OLD01"), await room_store.get_room(session, "NEW01")

    removed, old, new = asyncio.run(run())
    assert removed == 1 and old is None and new is not None


# ------------------------------------------------------------------ langues mélangées et pays


def test_french_and_english_players_share_a_room(client):
    with (
        player(client, "alice-0001", "Alice", "fr", "France") as alice,
        player(client, "bob-00001", "Bob", "en", "Ivory%20Coast") as bob,
    ):
        room = create_room(alice, categories=["country"])
        bob.send_json({"type": "join_room", "code": room["code"]})
        room = state(bob, "waiting", lambda r: len(r["players"]) == 2)
        assert {p["client_id"]: (p["language"], p["country"]) for p in room["players"]} == {
            "alice-0001": ("fr", "France"),
            "bob-00001": ("en", "Ivory Coast"),
        }
        alice.send_json({"type": "set_ready", "ready": True})
        bob.send_json({"type": "set_ready", "ready": True})
        state(alice, "round")
        # Chacun dans sa langue : « Maroc » et « Morocco » sont la même réponse (partagée).
        alice.send_json({"type": "submit", "round": 1, "answers": {"country": "Maroc"}})
        bob.send_json({"type": "submit", "round": 1, "answers": {"country": "Morocco"}})
        results = state(alice, "results")["results"]
        by_player = {p["nickname"]: p for p in results["players"]}
        assert by_player["Alice"]["answers"][0]["status"] == "valid"
        assert by_player["Bob"]["answers"][0]["status"] == "valid"
        assert by_player["Alice"]["round_score"] == by_player["Bob"]["round_score"] == 5

        # Un anglophone qui répond en français n'est pas validé (il joue en anglais).
        state(alice, "round", lambda r: r["round"]["number"] == 2)
        alice.send_json({"type": "submit", "round": 2, "answers": {}})
        bob.send_json({"type": "submit", "round": 2, "answers": {"country": "Maroc"}})
        results = state(bob, "results", lambda r: r["results"]["number"] == 2)["results"]
        bob_answer = {p["nickname"]: p for p in results["players"]}["Bob"]["answers"][0]
        assert bob_answer["status"] != "valid"
        assert set(results["examples_by_language"]) == {"fr", "en"}
