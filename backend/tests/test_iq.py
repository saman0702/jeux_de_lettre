import json
import random

from app.services import iq_service


def test_every_puzzle_kind_is_consistent():
    rng = random.Random(7)
    kinds = set()
    for level in (1, 2, 3):
        for _ in range(500):
            p = iq_service.draw(level, rng=rng)
            kinds.add(p.kind)
            assert p.prompt["fr"] and p.prompt["en"]
            assert p.explanation["fr"] and p.explanation["en"]
            assert iq_service.check(p, p.answer)
            if p.input == "choice":
                assert len(p.choices["fr"]) == len(p.choices["en"]) == 4
                assert not iq_service.check(p, iq_service.wrong_answer(p, rng))
            else:
                assert not iq_service.check(p, iq_service.wrong_answer(p, rng))
            assert "answer" not in p.public()
    assert kinds == {
        "sequence", "grid", "problem", "letters", "calendar", "analogy", "odd", "logic",
        "matrix", "rotation", "figure_odd", "trace",
    }


def test_numbers_are_compared_loosely():
    p = iq_service.Puzzle("x", "sequence", 1, "number", {"fr": "", "en": ""}, "1024", {"fr": "", "en": ""})
    assert iq_service.check(p, " 1 024 ")
    assert iq_service.check(p, "1024,0")
    assert not iq_service.check(p, "1023")
    assert not iq_service.check(p, "")


def test_points_follow_the_host_settings():
    assert iq_service.points(True, True, 0, 30, speed_bonus=True, penalty=False) == 20
    assert iq_service.points(True, True, 15, 30, speed_bonus=True, penalty=False) == 15
    assert iq_service.points(True, True, 0, 30, speed_bonus=False, penalty=False) == 10
    assert iq_service.points(False, True, 3, 30, speed_bonus=True, penalty=True) == -5
    assert iq_service.points(False, False, 0, 30, speed_bonus=True, penalty=True) == 0, "no answer, no penalty"
    assert iq_service.points(False, True, 3, 30, speed_bonus=True, penalty=False) == 0


def test_difficulty_rises_with_the_rounds():
    assert [iq_service.level_for(n, 9, "normal") for n in (1, 5, 9)] == [1, 2, 3]
    assert iq_service.level_for(1, 9, "hard") == 2
    assert iq_service.level_for(9, 9, "easy") == 2


def test_iq_estimate_for_fun():
    assert iq_service.iq_estimate([(1, False)] * 5) == 70
    assert iq_service.iq_estimate([(3, True)] * 5) == 145
    assert 95 < iq_service.iq_estimate([(1, True), (2, True), (3, False)]) < 120
    # 2 justes sur 5 (une facile, une difficile) : sous la moyenne, pas 100.
    assert iq_service.iq_estimate([(1, True), (1, False), (2, False), (3, True), (3, False)]) == 90
    assert iq_service.iq_estimate([(1, True), (1, True), (2, True), (3, False), (3, True)]) == 115


async def test_solo_puzzles_route(client):
    puzzles = (await client.get("/api/v1/iq/puzzles", params={"count": 9})).json()
    assert len(puzzles) == 9 and len({p["id"] for p in puzzles}) == 9
    assert [p["level"] for p in puzzles][0] == 1 and puzzles[-1]["level"] == 3
    assert all("answer" in p and "explanation" in p for p in puzzles)


def test_figure_puzzles_have_four_different_drawn_choices():
    rng = random.Random(11)
    for level in (1, 2, 3):
        for make in (iq_service._matrix, iq_service._rotation, iq_service._figure_odd):
            for _ in range(200):
                p = make(rng, level)
                options = p.figures["options"]
                assert len(options) == 4
                assert len({json.dumps(o, sort_keys=True) for o in options}) == 4, "four different figures"
                assert p.choices["fr"] == ["A", "B", "C", "D"]
                assert p.public()["figures"] == p.figures
                if p.kind == "matrix":
                    cells = p.figures["cells"]
                    assert len(cells) == 9 and cells.count(None) == 1
                if p.kind == "rotation":
                    assert p.figures["cells"][-1] is None


def test_matrix_answer_is_the_missing_cell():
    rng = random.Random(3)
    p = iq_service._matrix(rng, 2)
    options = p.figures["options"]
    correct = options[int(p.answer)]
    # Niveau 2 : ligne 3 = même forme que les deux autres cases de la ligne.
    row = p.figures["cells"][6:8]
    assert all(c["s"] == correct["s"] for c in row)


def test_trace_puzzles_can_always_be_drawn_in_one_stroke():
    rng = random.Random(21)
    for level in (1, 2, 3):
        for _ in range(150):
            p = iq_service._trace(rng, level)
            edges = p.trace["edges"]
            assert len(p.trace["points"]) >= 3
            assert iq_service.valid_trace(p.trace, p.answer), "the stored solution works"
            # Un autre tracé valide est accepté aussi : le même chemin parcouru à l'envers.
            assert iq_service.check(p, "-".join(reversed(p.answer.split("-"))))
            assert not iq_service.check(p, iq_service.wrong_answer(p, rng))
            assert len(edges) >= {1: 5, 2: 8, 3: 11}[level]
            odd = [n for n in range(len(p.trace["points"])) if sum(n in e for e in edges) % 2]
            assert len(odd) in (0, 2)


def test_a_trace_cannot_jump_or_repeat_a_line():
    trace = {"points": [[0, 0], [1, 0], [1, 1]], "edges": [[0, 1], [1, 2], [0, 2]]}
    assert iq_service.valid_trace(trace, "0-1-2-0")
    assert not iq_service.valid_trace(trace, "0-1-0-2"), "line 0-1 twice"
    assert not iq_service.valid_trace(trace, "0-1-2"), "a line is missing"
    assert not iq_service.valid_trace(trace, "x")


# ------------------------------------------------------------- parties vérifiées par le serveur

from datetime import date, timedelta  # noqa: E402

from app.models import IqSession  # noqa: E402
from app.services import iq_play_service  # noqa: E402

PLAYER = "iq-player-0001"


async def _give_coins(client, session, client_id, coins):
    from app.services import wallet_service

    await client.get(f"/api/v1/profiles/{client_id}")
    profile = await wallet_service.get_profile(session, client_id)
    profile.coins = coins
    await session.commit()


async def test_online_solo_checks_answers_on_the_server_and_pays_coins(client, session):
    game = (await client.post("/api/v1/iq/solo", json={"client_id": PLAYER, "rounds": 5, "duration": 30})).json()
    assert game["number"] == 1 and game["total"] == 5
    assert "answer" not in game["puzzle"], "the answer stays on the server"
    stored = await session.get(IqSession, game["id"])
    total_points = 0
    for number in range(1, 6):
        await session.refresh(stored)
        right = stored.puzzles[number - 1]["answer"]
        result = (await client.post(f"/api/v1/iq/sessions/{game['id']}/answer", json={"client_id": PLAYER, "answer": right})).json()
        assert result["correct"] is True and result["points"] >= 10
        total_points += result["points"]
        again = await client.post(f"/api/v1/iq/sessions/{game['id']}/answer", json={"client_id": PLAYER, "answer": right})
        assert again.status_code == 409, "one answer per puzzle"
        if number < 5:
            nxt = (await client.post(f"/api/v1/iq/sessions/{game['id']}/next", json={"client_id": PLAYER})).json()
            assert nxt["number"] == number + 1
    assert result["finished"] is True and result["iq"] == 145
    profile = (await client.get(f"/api/v1/profiles/{PLAYER}")).json()
    assert profile["total_points"] == total_points and profile["coins"] == total_points // 20


async def test_a_late_answer_counts_as_no_answer(client, session):
    game = (await client.post("/api/v1/iq/solo", json={"client_id": PLAYER, "rounds": 5, "duration": 15})).json()
    stored = await session.get(IqSession, game["id"])
    stored.served_at = stored.served_at - timedelta(seconds=60)
    await session.commit()
    right = stored.puzzles[0]["answer"]
    result = (await client.post(f"/api/v1/iq/sessions/{game['id']}/answer", json={"client_id": PLAYER, "answer": right})).json()
    assert result["late"] is True and result["correct"] is False and result["points"] == 0


async def test_someone_else_cannot_answer_my_game(client):
    game = (await client.post("/api/v1/iq/solo", json={"client_id": PLAYER, "rounds": 5, "duration": 30})).json()
    other = await client.post(f"/api/v1/iq/sessions/{game['id']}/answer", json={"client_id": "other-0001", "answer": "1"})
    assert other.status_code == 404


async def test_jokers_cost_coins_and_help(client, session):
    await _give_coins(client, session, PLAYER, 100)
    game = (await client.post("/api/v1/iq/solo", json={"client_id": PLAYER, "rounds": 5, "duration": 30})).json()
    stored = await session.get(IqSession, game["id"])
    puzzle = iq_service.puzzle_from(stored.puzzles[0])
    help_kind = "fifty" if puzzle.input == "choice" else "hint"
    wrong_kind = "hint" if help_kind == "fifty" else "fifty"
    url = f"/api/v1/iq/sessions/{game['id']}/joker"
    assert (await client.post(url, json={"client_id": PLAYER, "kind": wrong_kind})).status_code == 409
    effect = (await client.post(url, json={"client_id": PLAYER, "kind": help_kind})).json()
    if help_kind == "fifty":
        assert len(effect["removed"]) == 2 and puzzle.answer not in {str(i) for i in effect["removed"]}
    elif puzzle.input == "trace":
        assert effect["start"] == int(puzzle.answer.split("-")[0]), "the hint shows where to start"
    else:
        assert effect["low"] <= float(puzzle.answer) <= effect["high"]
    assert effect["wallet"]["coins"] == 97
    assert (await client.post(url, json={"client_id": PLAYER, "kind": help_kind})).status_code == 409, "once per puzzle"
    timed = (await client.post(url, json={"client_id": PLAYER, "kind": "time"})).json()
    assert timed["extra_seconds"] == 15
    skipped = (await client.post(url, json={"client_id": PLAYER, "kind": "skip"})).json()
    assert skipped["game"]["puzzle"]["id"] != puzzle.id and skipped["wallet"]["coins"] == 89


async def test_jokers_need_coins(client, session):
    game = (await client.post("/api/v1/iq/solo", json={"client_id": PLAYER, "rounds": 5, "duration": 30})).json()
    broke = await client.post(f"/api/v1/iq/sessions/{game['id']}/joker", json={"client_id": PLAYER, "kind": "time"})
    assert broke.status_code == 402 and broke.json()["detail"] == "not_enough_coins"


def test_daily_puzzles_are_the_same_for_everyone():
    day = date(2026, 10, 26)
    first, second = iq_play_service.daily_puzzles(day), iq_play_service.daily_puzzles(day)
    assert [p["prompt"] for p in first] == [p["prompt"] for p in second]
    assert [p["answer"] for p in first] == [p["answer"] for p in second]
    assert len(first) == 10 and first[0]["level"] == 1 and first[-1]["level"] == 3
    assert [p["prompt"] for p in iq_play_service.daily_puzzles(day + timedelta(days=1))] != [p["prompt"] for p in first]


async def test_daily_challenge_once_a_day_and_podium_paid_once(client, session):
    for i, cid in enumerate(["daily-a-0001", "daily-b-0001", "daily-c-0001", "daily-d-0001"]):
        game = (await client.post("/api/v1/iq/daily", json={"client_id": cid})).json()
        assert game["mode"] == "daily" and game["joker_prices"] == {}
        assert (await client.post("/api/v1/iq/daily", json={"client_id": cid})).status_code == 409
        no_joker = await client.post(f"/api/v1/iq/sessions/{game['id']}/joker", json={"client_id": cid, "kind": "time"})
        assert no_joker.status_code == 403
        stored = await session.get(IqSession, game["id"])
        await session.refresh(stored)
        # a répond juste à tout, b à 9, c à 8, d à 7.
        for number in range(1, 11):
            await session.refresh(stored)
            right = stored.puzzles[number - 1]["answer"]
            answer = right if number > i else "-999"
            await client.post(f"/api/v1/iq/sessions/{game['id']}/answer", json={"client_id": cid, "answer": answer})
            if number < 10:
                await client.post(f"/api/v1/iq/sessions/{game['id']}/next", json={"client_id": cid})
    board = (await client.get("/api/v1/iq/daily/leaderboard", params={"client_id": "daily-b-0001"})).json()
    assert [r["client_id"] for r in board["top"]] == ["daily-a-0001", "daily-b-0001", "daily-c-0001", "daily-d-0001"]
    assert board["me"]["rank"] == 2 and board["played"] is True

    # Le lendemain : le podium d'hier est payé, une seule fois.
    await session.execute(IqSession.__table__.update().values(day=iq_play_service.today() - timedelta(days=1)))
    await session.commit()
    before = {cid: (await client.get(f"/api/v1/profiles/{cid}")).json()["coins"] for cid in ["daily-a-0001", "daily-d-0001"]}
    board = (await client.get("/api/v1/iq/daily/leaderboard")).json()
    await client.get("/api/v1/iq/daily/leaderboard")
    assert [r["prize"] for r in board["yesterday"]] == [50, 30, 20]
    after = {cid: (await client.get(f"/api/v1/profiles/{cid}")).json()["coins"] for cid in ["daily-a-0001", "daily-d-0001"]}
    assert after["daily-a-0001"] == before["daily-a-0001"] + 50
    assert after["daily-d-0001"] == before["daily-d-0001"], "4th place: no prize"
