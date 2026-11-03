"""Figures pour le kind QI « count » : compter les triangles dans un schéma.

Chaque entrée : (niveau, id, nombre_de_triangles, segments, highlights, why_fr, why_en).
- segments : lignes [x1, y1, x2, y2] en coords 0–1
- highlights : quelques triangles pour l'explication visuelle

On compte **tous** les triangles (petits + composés), comme dans les tests de QI classiques.
"""

_A = (0.50, 0.08)
_B = (0.08, 0.92)
_C = (0.92, 0.92)
_M = (0.50, 0.92)
_AB = (0.29, 0.50)
_AC = (0.71, 0.50)
_BC = (0.50, 0.92)
_P1 = (0.36, 0.92)
_P2 = (0.64, 0.92)


def _seg(a, b):
    return [a[0], a[1], b[0], b[1]]


def _tri(*pts):
    return [[p[0], p[1]] for p in pts]


COUNT_FIGURES: list[tuple] = [
    # —— Niveau 1 ——
    (
        1,
        "one",
        1,
        [_seg(_A, _B), _seg(_B, _C), _seg(_C, _A)],
        [_tri(_A, _B, _C)],
        "Un seul triangle.",
        "Just one triangle.",
    ),
    (
        1,
        "split3",
        3,
        [_seg(_A, _B), _seg(_B, _C), _seg(_C, _A), _seg(_A, _M)],
        [_tri(_A, _B, _M), _tri(_A, _M, _C), _tri(_A, _B, _C)],
        "2 petits + le grand = 3.",
        "2 small + the large one = 3.",
    ),
    (
        1,
        "square-diag",
        2,
        [
            _seg((0.2, 0.2), (0.8, 0.2)),
            _seg((0.8, 0.2), (0.8, 0.8)),
            _seg((0.8, 0.8), (0.2, 0.8)),
            _seg((0.2, 0.8), (0.2, 0.2)),
            _seg((0.2, 0.2), (0.8, 0.8)),
        ],
        [
            _tri((0.2, 0.2), (0.8, 0.2), (0.8, 0.8)),
            _tri((0.2, 0.2), (0.8, 0.8), (0.2, 0.8)),
        ],
        "Le carré et sa diagonale forment 2 triangles.",
        "The square and its diagonal make 2 triangles.",
    ),
    # —— Niveau 2 ——
    # Milieux reliés : 3 coins + 1 milieu + le grand = 5
    (
        2,
        "midpoints5",
        5,
        [
            _seg(_A, _B),
            _seg(_B, _C),
            _seg(_C, _A),
            _seg(_AB, _AC),
            _seg(_AB, _BC),
            _seg(_AC, _BC),
        ],
        [
            _tri(_A, _AB, _AC),
            _tri(_AB, _B, _BC),
            _tri(_AC, _BC, _C),
            _tri(_AB, _AC, _BC),
            _tri(_A, _B, _C),
        ],
        "3 petits aux coins + 1 au milieu + le grand = 5.",
        "3 small in the corners + 1 in the middle + the large one = 5.",
    ),
    (
        2,
        "square-x",
        4,
        [
            _seg((0.2, 0.2), (0.8, 0.2)),
            _seg((0.8, 0.2), (0.8, 0.8)),
            _seg((0.8, 0.8), (0.2, 0.8)),
            _seg((0.2, 0.8), (0.2, 0.2)),
            _seg((0.2, 0.2), (0.8, 0.8)),
            _seg((0.8, 0.2), (0.2, 0.8)),
        ],
        [
            _tri((0.2, 0.2), (0.8, 0.2), (0.5, 0.5)),
            _tri((0.8, 0.2), (0.8, 0.8), (0.5, 0.5)),
            _tri((0.8, 0.8), (0.2, 0.8), (0.5, 0.5)),
            _tri((0.2, 0.8), (0.2, 0.2), (0.5, 0.5)),
        ],
        "Les deux diagonales découpent 4 triangles.",
        "The two diagonals split the square into 4 triangles.",
    ),
    # 2 rayons intérieurs → 3 petits + 2 moyens + 1 grand = 6
    (
        2,
        "fan6",
        6,
        [
            _seg(_A, _B),
            _seg(_B, _C),
            _seg(_C, _A),
            _seg(_A, _P1),
            _seg(_A, _P2),
        ],
        [
            _tri(_A, _B, _P1),
            _tri(_A, _P1, _P2),
            _tri(_A, _P2, _C),
            _tri(_A, _B, _P2),
            _tri(_A, _P1, _C),
            _tri(_A, _B, _C),
        ],
        "3 petits + 2 moyens + le grand = 6.",
        "3 small + 2 medium + the large one = 6.",
    ),
    # —— Niveau 3 ——
    # 3 rayons intérieurs → 4+3+2+1 = 10
    (
        3,
        "fan10",
        10,
        [
            _seg(_A, _B),
            _seg(_B, _C),
            _seg(_C, _A),
            _seg(_A, (0.29, 0.92)),
            _seg(_A, (0.50, 0.92)),
            _seg(_A, (0.71, 0.92)),
        ],
        [
            _tri(_A, _B, (0.29, 0.92)),
            _tri(_A, (0.29, 0.92), (0.50, 0.92)),
            _tri(_A, (0.50, 0.92), (0.71, 0.92)),
            _tri(_A, (0.71, 0.92), _C),
            _tri(_A, _B, _C),
        ],
        "4 de taille 1 + 3 de taille 2 + 2 de taille 3 + 1 grand = 10.",
        "4 of size 1 + 3 of size 2 + 2 of size 3 + 1 large = 10.",
    ),
    (
        3,
        "diamond8",
        8,
        # Losange (2 grands triangles) + horizontale médiane + verticale
        [
            _seg((0.5, 0.1), (0.9, 0.5)),
            _seg((0.9, 0.5), (0.5, 0.9)),
            _seg((0.5, 0.9), (0.1, 0.5)),
            _seg((0.1, 0.5), (0.5, 0.1)),
            _seg((0.1, 0.5), (0.9, 0.5)),
            _seg((0.5, 0.1), (0.5, 0.9)),
        ],
        [
            _tri((0.5, 0.1), (0.9, 0.5), (0.5, 0.5)),
            _tri((0.9, 0.5), (0.5, 0.9), (0.5, 0.5)),
            _tri((0.5, 0.9), (0.1, 0.5), (0.5, 0.5)),
            _tri((0.1, 0.5), (0.5, 0.1), (0.5, 0.5)),
            _tri((0.5, 0.1), (0.9, 0.5), (0.5, 0.9)),
            _tri((0.5, 0.1), (0.1, 0.5), (0.5, 0.9)),
            _tri((0.5, 0.1), (0.9, 0.5), (0.1, 0.5)),
            _tri((0.9, 0.5), (0.5, 0.9), (0.1, 0.5)),
        ],
        "4 tout petits au centre + 4 grands (moitiés / losange) = 8.",
        "4 tiny in the middle + 4 larger ones = 8.",
    ),
]
