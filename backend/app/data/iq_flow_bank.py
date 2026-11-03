"""Grilles Flow : relier chaque paire de même couleur, cases adjacentes, sans croiser.

Chaque entrée : (niveau, id, taille, paires, solutions, why_fr, why_en).
"""

from __future__ import annotations

import json


def _adjacent(a: list[int], b: list[int]) -> bool:
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1


def assert_flow_solution(size: int, pairs: list[dict], solutions: list[list[list[int]]]) -> None:
    """Vérifie qu'une solution ne se croise pas et relie bien chaque paire."""
    occupied: dict[tuple[int, int], int] = {}
    assert len(pairs) == len(solutions)
    for i, (pair, path) in enumerate(zip(pairs, solutions)):
        assert path[0] == pair["a"] and path[-1] == pair["b"], (pair, path)
        for cell in path:
            assert 0 <= cell[0] < size and 0 <= cell[1] < size
            key = (cell[0], cell[1])
            assert key not in occupied, f"cell {key} reused"
            occupied[key] = i
        for a, b in zip(path, path[1:]):
            assert _adjacent(a, b), f"gap {a}-{b}"


def valid_flow(flow: dict, raw: object) -> bool:
    """Réponse joueur : liste de chemins (même ordre que pairs)."""
    try:
        paths = raw if isinstance(raw, list) else json.loads(str(raw))
        assert_flow_solution(flow["size"], flow["pairs"], paths)
        return True
    except (TypeError, ValueError, AssertionError, json.JSONDecodeError):
        return False


_RAW: list[tuple] = [
    (
        1,
        "rows",
        4,
        [
            {"color": 0, "a": [0, 0], "b": [0, 3]},
            {"color": 1, "a": [3, 0], "b": [3, 3]},
            {"color": 2, "a": [1, 1], "b": [2, 1]},
        ],
        [
            [[0, 0], [0, 1], [0, 2], [0, 3]],
            [[3, 0], [3, 1], [3, 2], [3, 3]],
            [[1, 1], [2, 1]],
        ],
        "Deux lignes horizontales et un petit lien vertical.",
        "Two horizontal lines and a short vertical link.",
    ),
    (
        1,
        "cols",
        4,
        [
            {"color": 0, "a": [0, 0], "b": [3, 0]},
            {"color": 1, "a": [0, 3], "b": [3, 3]},
            {"color": 2, "a": [1, 1], "b": [1, 2]},
        ],
        [
            [[0, 0], [1, 0], [2, 0], [3, 0]],
            [[0, 3], [1, 3], [2, 3], [3, 3]],
            [[1, 1], [1, 2]],
        ],
        "Deux colonnes sur les bords, un lien au centre.",
        "Two edge columns and a link in the middle.",
    ),
    (
        1,
        "L",
        4,
        [
            {"color": 0, "a": [0, 0], "b": [0, 2]},
            {"color": 1, "a": [0, 3], "b": [3, 3]},
            {"color": 2, "a": [3, 0], "b": [1, 2]},
        ],
        [
            [[0, 0], [0, 1], [0, 2]],
            [[0, 3], [1, 3], [2, 3], [3, 3]],
            [[3, 0], [3, 1], [3, 2], [2, 2], [1, 2]],
        ],
        "Un L, une colonne, un petit trait.",
        "An L, a column, and a short stroke.",
    ),
    (
        2,
        "frame",
        5,
        [
            {"color": 0, "a": [0, 1], "b": [0, 3]},
            {"color": 1, "a": [1, 0], "b": [3, 0]},
            {"color": 2, "a": [1, 4], "b": [3, 4]},
            {"color": 3, "a": [4, 1], "b": [4, 3]},
        ],
        [
            [[0, 1], [0, 2], [0, 3]],
            [[1, 0], [2, 0], [3, 0]],
            [[1, 4], [2, 4], [3, 4]],
            [[4, 1], [4, 2], [4, 3]],
        ],
        "Quatre côtés d'un cadre.",
        "Four sides of a frame.",
    ),
    (
        2,
        "u-turn",
        5,
        [
            {"color": 0, "a": [0, 0], "b": [0, 4]},
            {"color": 1, "a": [4, 0], "b": [4, 4]},
            {"color": 2, "a": [1, 1], "b": [3, 1]},
            {"color": 3, "a": [1, 3], "b": [3, 3]},
        ],
        [
            [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]],
            [[4, 0], [4, 1], [4, 2], [4, 3], [4, 4]],
            [[1, 1], [2, 1], [3, 1]],
            [[1, 3], [2, 3], [3, 3]],
        ],
        "Haut, bas, et deux piliers.",
        "Top, bottom, and two pillars.",
    ),
    (
        3,
        "spiral",
        5,
        [
            {"color": 0, "a": [0, 0], "b": [2, 2]},
            {"color": 1, "a": [0, 4], "b": [4, 4]},
            {"color": 2, "a": [4, 0], "b": [4, 3]},
            {"color": 3, "a": [1, 1], "b": [3, 1]},
        ],
        [
            [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]],
            [[0, 4], [1, 4], [2, 4], [3, 4], [4, 4]],
            [[4, 0], [4, 1], [4, 2], [4, 3]],
            [[1, 1], [1, 2], [1, 3], [2, 3], [3, 3], [3, 2], [3, 1]],
        ],
        "Le vert contourne le centre pour rejoindre ses points.",
        "Green goes around the center to meet its dots.",
    ),
]

FLOW_PUZZLES: list[tuple] = []
for entry in _RAW:
    level, slug, size, pairs, sols, wfr, wen = entry
    assert_flow_solution(size, pairs, sols)
    FLOW_PUZZLES.append(entry)

assert {e[0] for e in FLOW_PUZZLES} >= {1, 2, 3}
