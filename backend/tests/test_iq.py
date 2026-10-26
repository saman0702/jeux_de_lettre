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
        "matrix", "rotation", "figure_odd",
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
