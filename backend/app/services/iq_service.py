"""Énigmes de QI : tirage, vérification et points.

Deux sortes d'énigmes :
- « number » : le joueur tape un nombre (suites, grilles, calculs) ;
- « choice » : 4 choix, un seul bon (analogies, intrus, logique, suites de lettres, calendrier…).

Le texte est donné en français et en anglais : dans une partie mélangée, chacun lit dans sa langue.
Les suites, grilles et problèmes sont générés (en nombre illimité) ; les autres viennent de
app/data/iq_bank.py.

Énigmes à schémas (matrice, rotation, intrus visuel) : les figures sont décrites en données
(forme, couleur, nombre, plein ou vide, rotation) et dessinées par l'appli ; les 4 choix sont
des figures notées A à D.
"""

import json
import random
from dataclasses import dataclass, field

from app.data.iq_bank import ANALOGIES, LOGIC, ODD_ONE_OUT

POINTS_CORRECT = 10
SPEED_BONUS_MAX = 10
WRONG_PENALTY = 5

# Jokers payants (en pièces), une fois par énigme chacun :
# - fifty : retire 2 mauvais choix (énigmes à choix) ;
# - hint : donne un intervalle qui contient la réponse (énigmes à nombre) ;
# - time : 15 secondes de plus ;
# - skip : une autre énigme du même niveau.
JOKER_PRICES = {"fifty": 3, "hint": 3, "time": 3, "skip": 5}
EXTRA_TIME = 15


@dataclass(frozen=True)
class Puzzle:
    id: str
    kind: str  # sequence, grid, problem, analogy, odd, logic, letters, calendar, matrix, rotation, figure_odd, trace
    level: int  # 1 facile, 2 moyen, 3 difficile
    input: str  # number | choice | trace
    prompt: dict[str, str]
    answer: str  # nombre, ou indice du bon choix
    explanation: dict[str, str]
    choices: dict[str, list[str]] | None = None
    # Grille de nombres (« ? » pour la case à trouver).
    grid: list[list[str]] | None = None
    # Suite affichée en grandes tuiles.
    items: list[str] = field(default_factory=list)
    # Schémas : {"layout": "grid" | "row" | "none", "cells": [figure | None], "options": [figure × 4]}.
    figures: dict | None = None
    # Un seul trait : {"points": [[x, y]], "edges": [[a, b]]} ; la réponse est un chemin « 0-3-1… ».
    trace: dict | None = None

    def public(self) -> dict:
        """Ce que voient les joueurs pendant la manche (sans la réponse)."""
        return {
            "id": self.id,
            "kind": self.kind,
            "level": self.level,
            "input": self.input,
            "prompt": self.prompt,
            "choices": self.choices,
            "grid": self.grid,
            "items": self.items,
            "figures": self.figures,
            "trace": self.trace,
        }

    def reveal(self) -> dict:
        return {**self.public(), "answer": self.answer, "explanation": self.explanation}


def _text(fr: str, en: str) -> dict[str, str]:
    return {"fr": fr, "en": en}


# ------------------------------------------------------------------ générateurs


def _sequence(rng: random.Random, level: int) -> Puzzle:
    """Suite de nombres : trouver le suivant."""
    kinds = {1: ["add", "mul2"], 2: ["add_grow", "mul", "alt"], 3: ["fib", "squares", "interleave", "mul_add"]}
    kind = rng.choice(kinds[level])
    if kind == "add":
        a, d = rng.randint(1, 20), rng.randint(2, 9)
        seq = [a + i * d for i in range(6)]
        why = _text(f"On ajoute {d} à chaque fois.", f"Add {d} each time.")
    elif kind == "mul2":
        a = rng.randint(1, 6)
        seq = [a * 2**i for i in range(6)]
        why = _text("On multiplie par 2 à chaque fois.", "Multiply by 2 each time.")
    elif kind == "add_grow":
        a, d = rng.randint(1, 10), rng.randint(1, 3)
        seq = [a]
        for i in range(5):
            seq.append(seq[-1] + d + i)
        why = _text(f"L'écart grandit de 1 : +{d}, +{d + 1}, +{d + 2}…", f"The gap grows by 1: +{d}, +{d + 1}, +{d + 2}…")
    elif kind == "mul":
        a, m = rng.randint(1, 4), rng.choice([3, 4])
        seq = [a * m**i for i in range(6)]
        why = _text(f"On multiplie par {m} à chaque fois.", f"Multiply by {m} each time.")
    elif kind == "alt":
        a, p, q = rng.randint(1, 9), rng.randint(2, 6), rng.randint(1, 3)
        seq = [a]
        for i in range(5):
            seq.append(seq[-1] + p if i % 2 == 0 else seq[-1] - q)
        why = _text(f"On ajoute {p}, puis on retire {q}, et ainsi de suite.", f"Add {p}, then subtract {q}, and so on.")
    elif kind == "fib":
        a, b = rng.randint(1, 5), rng.randint(1, 6)
        seq = [a, b]
        while len(seq) < 7:
            seq.append(seq[-1] + seq[-2])
        why = _text("Chaque nombre est la somme des deux précédents.", "Each number is the sum of the previous two.")
    elif kind == "squares":
        s = rng.randint(1, 5)
        seq = [(s + i) ** 2 for i in range(6)]
        why = _text(f"Les carrés : {s}², {s + 1}², {s + 2}²…", f"Squares: {s}², {s + 1}², {s + 2}²…")
    elif kind == "interleave":
        a, d, b, e = rng.randint(1, 9), rng.randint(2, 5), rng.randint(20, 40), rng.randint(1, 3)
        seq = []
        for i in range(4):
            seq += [a + i * d, b - i * e]
        seq = seq[:7]
        why = _text(
            f"Deux suites mêlées : l'une monte de {d}, l'autre descend de {e}.",
            f"Two sequences mixed: one goes up by {d}, the other down by {e}.",
        )
    else:  # mul_add
        a, m, c = rng.randint(1, 4), 2, rng.randint(1, 3)
        seq = [a]
        for _ in range(5):
            seq.append(seq[-1] * m + c)
        why = _text(f"On multiplie par {m} puis on ajoute {c}.", f"Multiply by {m} then add {c}.")
    shown, answer = seq[:-1], seq[-1]
    return Puzzle(
        id=f"seq-{kind}-{'-'.join(map(str, seq))}",
        kind="sequence",
        level=level,
        input="number",
        prompt=_text("Quel nombre vient ensuite ?", "Which number comes next?"),
        answer=str(answer),
        explanation=why,
        items=[str(n) for n in shown] + ["?"],
    )


def _grid(rng: random.Random, level: int) -> Puzzle:
    """Grille 3 × 3 : chaque ligne suit la même règle, une case est cachée."""
    if level == 1:
        rows = []
        for _ in range(3):
            a, b = rng.randint(1, 9), rng.randint(1, 9)
            rows.append([a, b, a + b])
        why = _text("Sur chaque ligne, le 3e nombre est la somme des deux premiers.",
                    "In each row, the 3rd number is the sum of the first two.")
    elif level == 2:
        rows = []
        for _ in range(3):
            a, b = rng.randint(2, 9), rng.randint(2, 6)
            rows.append([a, b, a * b])
        why = _text("Sur chaque ligne, le 3e nombre est le produit des deux premiers.",
                    "In each row, the 3rd number is the product of the first two.")
    else:
        rows = []
        for _ in range(3):
            a, b = rng.randint(2, 9), rng.randint(1, 5)
            rows.append([a, b, a * a - b])
        why = _text("Sur chaque ligne : 1er au carré, moins le 2e.",
                    "In each row: the 1st squared, minus the 2nd.")
    r, c = 2, rng.choice([0, 1, 2]) if level == 3 else 2
    answer = rows[r][c]
    grid = [[str(v) for v in row] for row in rows]
    grid[r][c] = "?"
    return Puzzle(
        id=f"grid-{level}-{'-'.join(str(v) for row in rows for v in row)}-{c}",
        kind="grid",
        level=level,
        input="number",
        prompt=_text("Quel nombre remplace le « ? » ?", "Which number replaces the “?”?"),
        answer=str(answer),
        explanation=why,
        grid=grid,
    )


def _problem(rng: random.Random, level: int) -> Puzzle:
    """Petit problème de calcul (proportions, âges, vitesse, pourcentages)."""
    kind = rng.choice({1: ["price", "share"], 2: ["age", "speed", "percent"], 3: ["work", "age2", "percent2"]}[level])
    if kind == "price":
        n, p, m = rng.randint(2, 5), rng.randint(2, 9), rng.randint(6, 12)
        total = n * p
        fr = f"{n} cahiers coûtent {total} €. Combien coûtent {m} cahiers ?"
        en = f"{n} notebooks cost ${total}. How much do {m} notebooks cost?"
        answer, why = m * p, _text(f"Un cahier coûte {p} €, donc {m} × {p}.", f"One notebook costs ${p}, so {m} × {p}.")
    elif kind == "share":
        people, each = rng.randint(3, 8), rng.randint(3, 12)
        total = people * each
        fr = f"On partage {total} bonbons entre {people} enfants. Combien en a chacun ?"
        en = f"{total} sweets are shared between {people} children. How many does each get?"
        answer, why = each, _text(f"{total} ÷ {people}.", f"{total} ÷ {people}.")
    elif kind == "age":
        son, gap = rng.randint(5, 15), rng.randint(20, 35)
        total = 2 * son + gap
        fr = f"Un père et son fils ont {total} ans à eux deux. Le père a {gap} ans de plus. Quel âge a le fils ?"
        en = f"A father and his son are {total} years old together. The father is {gap} years older. How old is the son?"
        answer, why = son, _text(f"({total} − {gap}) ÷ 2.", f"({total} − {gap}) ÷ 2.")
    elif kind == "speed":
        speed, hours = rng.choice([40, 50, 60, 80, 90]), rng.randint(2, 4)
        fr = f"Une voiture roule à {speed} km/h pendant {hours} h. Quelle distance (en km) parcourt-elle ?"
        en = f"A car drives at {speed} km/h for {hours} h. What distance (in km) does it cover?"
        answer, why = speed * hours, _text(f"{speed} × {hours}.", f"{speed} × {hours}.")
    elif kind == "percent":
        price, pct = rng.choice([40, 60, 80, 120, 200]), rng.choice([10, 25, 50])
        fr = f"Un jeu coûte {price} €. Il est soldé à −{pct} %. Quel est son nouveau prix (en €) ?"
        en = f"A game costs ${price}. It is {pct}% off. What is its new price (in $)?"
        answer, why = price - price * pct // 100, _text(f"{price} − {pct} % de {price}.", f"{price} − {pct}% of {price}.")
    elif kind == "work":
        days, workers, more = rng.choice([6, 8, 12]), rng.choice([2, 3, 4]), 2
        fr = f"{workers} ouvriers construisent un mur en {days} jours. Combien de jours faut-il à {workers * more} ouvriers ?"
        en = f"{workers} workers build a wall in {days} days. How many days do {workers * more} workers need?"
        answer, why = days // more, _text(f"Deux fois plus d'ouvriers : deux fois moins de temps.",
                                          "Twice as many workers: half the time.")
    elif kind == "age2":
        child, mult, years = rng.randint(4, 10), 3, rng.randint(2, 6)
        parent = child * mult
        fr = f"Ma mère a {mult} fois mon âge. J'ai {child} ans. Quel âge aura-t-elle dans {years} ans ?"
        en = f"My mother is {mult} times my age. I am {child}. How old will she be in {years} years?"
        answer, why = parent + years, _text(f"{child} × {mult} + {years}.", f"{child} × {mult} + {years}.")
    else:  # percent2
        base, up, down = rng.choice([100, 200, 400]), 50, 50
        fr = f"Un prix de {base} € augmente de {up} %, puis baisse de {down} %. Quel est le prix final (en €) ?"
        en = f"A ${base} price goes up {up}%, then down {down}%. What is the final price (in $)?"
        answer = base * 150 // 100 * 50 // 100
        why = _text(f"{base} × 1,5 = {base * 3 // 2}, puis la moitié.", f"{base} × 1.5 = {base * 3 // 2}, then half of it.")
    return Puzzle(
        id=f"pb-{kind}-{answer}-{abs(hash(fr)) % 10**8}",
        kind="problem",
        level=level,
        input="number",
        prompt=_text(fr, en),
        answer=str(answer),
        explanation=why,
    )


_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def _letters(rng: random.Random, level: int) -> Puzzle:
    """Suite de lettres : trouver la suivante parmi 4."""
    step = {1: rng.choice([1, 2]), 2: rng.choice([3, 4]), 3: 0}[level]
    if step:
        start = rng.randint(0, 25 - 5 * step)
        seq = [_LETTERS[start + i * step] for i in range(6)]
        why = _text(f"On avance de {step} lettre(s) dans l'alphabet.", f"Move {step} letter(s) forward in the alphabet.")
    else:
        start = rng.randint(0, 6)
        idx = [start]
        for i in range(5):
            idx.append(idx[-1] + i + 1)
        seq = [_LETTERS[i] for i in idx]
        why = _text("L'écart grandit : +1, +2, +3, +4…", "The gap grows: +1, +2, +3, +4…")
    answer = seq[-1]
    wrong = {c for c in _LETTERS if c != answer and abs(_LETTERS.index(c) - _LETTERS.index(answer)) <= 3}
    choices = [answer, *rng.sample(sorted(wrong), 3)]
    return _shuffled(
        rng,
        Puzzle(
            id=f"let-{''.join(seq)}",
            kind="letters",
            level=level,
            input="choice",
            prompt=_text("Quelle lettre vient ensuite ?", "Which letter comes next?"),
            answer="0",
            explanation=why,
            choices={"fr": choices, "en": choices},
            items=seq[:-1] + ["?"],
        ),
    )


_DAYS_FR = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
_DAYS_EN = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


def _calendar(rng: random.Random, level: int) -> Puzzle:
    """Jour de la semaine dans N jours."""
    today = rng.randrange(7)
    n = {1: rng.randint(3, 9), 2: rng.randint(15, 40), 3: rng.randint(60, 200)}[level]
    target = (today + n) % 7
    others = [d for d in range(7) if d != target]
    picks = [target, *rng.sample(others, 3)]
    return _shuffled(
        rng,
        Puzzle(
            id=f"cal-{today}-{n}",
            kind="calendar",
            level=level,
            input="choice",
            prompt=_text(
                f"Aujourd'hui, c'est {_DAYS_FR[today]}. Quel jour serons-nous dans {n} jours ?",
                f"Today is {_DAYS_EN[today]}. What day will it be in {n} days?",
            ),
            answer="0",
            explanation=_text(
                f"{n} jours = {n // 7} semaine(s) et {n % 7} jour(s) après {_DAYS_FR[today]}.",
                f"{n} days = {n // 7} week(s) and {n % 7} day(s) after {_DAYS_EN[today]}.",
            ),
            choices={"fr": [_DAYS_FR[d] for d in picks], "en": [_DAYS_EN[d] for d in picks]},
        ),
    )


def _bank(rng: random.Random, level: int, kind: str, bank: list) -> Puzzle:
    candidates = [(i, e) for i, e in enumerate(bank) if e[0] == level] or list(enumerate(bank))
    index, (lvl, pfr, pen, cfr, cen, wfr, wen) = rng.choice(candidates)
    return _shuffled(
        rng,
        Puzzle(
            id=f"{kind}-{index}",
            kind=kind,
            level=lvl,
            input="choice",
            prompt=_text(pfr, pen),
            answer="0",
            explanation=_text(wfr, wen),
            choices={"fr": list(cfr), "en": list(cen)},
        ),
    )


def _shuffled(rng: random.Random, puzzle: Puzzle) -> Puzzle:
    """Mélange les 4 choix (le bon est en tête dans la banque) en gardant les langues alignées."""
    order = list(range(4))
    rng.shuffle(order)
    choices = {lang: [values[i] for i in order] for lang, values in (puzzle.choices or {}).items()}
    return Puzzle(**{**puzzle.__dict__, "choices": choices, "answer": str(order.index(0))})


# ------------------------------------------------------------------ schémas

_SHAPES = ["circle", "square", "triangle", "diamond", "pentagon", "hexagon", "star"]
_SIDES = {"triangle": 3, "square": 4, "pentagon": 5, "hexagon": 6}
_LABELS = ["A", "B", "C", "D"]


def _fig(shape: str, color: int = 0, count: int = 1, filled: bool = True, rotation: int = 0) -> dict:
    """Une figure : 1 à 4 formes identiques dans une case."""
    return {"s": shape, "c": color, "n": count, "f": filled, "r": rotation % 360}


def _figure_puzzle(
    rng: random.Random,
    kind: str,
    level: int,
    prompt: dict[str, str],
    why: dict[str, str],
    layout: str,
    cells: list[dict | None],
    correct: dict,
    wrong: list[dict],
) -> Puzzle:
    """Mélange la bonne figure parmi 3 fausses (toutes différentes) ; les choix restent notés A à D."""
    options = [correct]
    for w in wrong:
        if w not in options:
            options.append(w)
    while len(options) < 4:
        extra = {**correct, "c": (correct["c"] + len(options)) % 4, "r": (correct["r"] + 45 * len(options)) % 360}
        if extra not in options:
            options.append(extra)
    options = options[:4]
    order = list(range(4))
    rng.shuffle(order)
    shuffled = [options[i] for i in order]
    payload = {"layout": layout, "cells": cells, "options": shuffled}
    digest = abs(hash(json.dumps([cells, correct], sort_keys=True))) % 10**10
    return Puzzle(
        id=f"{kind}-{level}-{digest}",
        kind=kind,
        level=level,
        input="choice",
        prompt=prompt,
        answer=str(order.index(0)),
        explanation=why,
        choices={"fr": list(_LABELS), "en": list(_LABELS)},
        figures=payload,
    )


def _matrix(rng: random.Random, level: int) -> Puzzle:
    """Matrice 3 × 3 de figures (façon Raven) : trouver la case manquante."""
    shapes = rng.sample(_SHAPES, 3)
    colors = rng.sample(range(4), 3)
    counts = [1, 2, 3]
    rng.shuffle(counts)

    def cell(r: int, c: int) -> dict:
        if level == 1:
            return _fig(shapes[r], colors[0], counts[c])
        if level == 2:
            return _fig(shapes[r], colors[(r + c) % 3], counts[c])
        return _fig(shapes[(r + c) % 3], colors[(r + 2 * c) % 3], counts[r], filled=c != 1)

    grid = [cell(r, c) for r in range(3) for c in range(3)]
    missing = 8 if level < 3 else rng.randrange(9)
    correct = grid[missing]
    cells: list[dict | None] = list(grid)
    cells[missing] = None
    other_shape = next(x for x in _SHAPES if x != correct["s"] and x in shapes) if level > 1 else rng.choice(
        [x for x in _SHAPES if x != correct["s"]]
    )
    wrong = [
        {**correct, "s": other_shape},
        {**correct, "n": 1 + correct["n"] % 3},
        {**correct, "c": next(c for c in range(4) if c != correct["c"])},
    ]
    if level == 3:
        wrong[2] = {**correct, "f": not correct["f"]}
    why = {
        1: _text("Chaque ligne garde sa forme, chaque colonne son nombre de formes.",
                 "Each row keeps its shape, each column its number of shapes."),
        2: _text("Forme par ligne, nombre par colonne, et chaque couleur une seule fois par ligne et par colonne.",
                 "Shape by row, number by column, and each colour once per row and per column."),
        3: _text("Chaque forme et chaque couleur apparaissent une fois par ligne et par colonne ; "
                 "le nombre suit la ligne, et la colonne du milieu est vide.",
                 "Each shape and colour appears once per row and per column; the number follows the row, "
                 "and the middle column is hollow."),
    }[level]
    return _figure_puzzle(
        rng, "matrix", level,
        _text("Quelle figure complète la grille ?", "Which figure completes the grid?"),
        why, "grid", cells, correct, wrong,
    )


def _rotation(rng: random.Random, level: int) -> Puzzle:
    """Une figure tourne à chaque case : laquelle vient ensuite ?"""
    shape = rng.choice(["arrow", "triangle"]) if level < 3 else "arrow"
    start = rng.choice(range(0, 360, 45))
    colors = rng.sample(range(4), 3)
    if level == 1:
        step = rng.choice([90, -90])
        turns = [start + i * step for i in range(5)]
        tint = [colors[0]] * 5
        why = _text(f"La figure tourne d'un quart de tour ({abs(step)}°) à chaque fois.",
                    f"The figure turns a quarter turn ({abs(step)}°) each time.")
    elif level == 2:
        step = rng.choice([45, -45, 135])
        turns = [start + i * step for i in range(5)]
        tint = [colors[i % 2] for i in range(5)]
        why = _text(f"Elle tourne de {abs(step)}° à chaque fois, et les deux couleurs alternent.",
                    f"It turns {abs(step)}° each time, and the two colours alternate.")
    else:
        turns = [start]
        for i in range(4):
            turns.append(turns[-1] + 45 * (i + 1))
        tint = [colors[i % 3] for i in range(5)]
        why = _text("La rotation grandit : +45°, +90°, +135°, +180° ; les trois couleurs tournent aussi.",
                    "The turn grows: +45°, +90°, +135°, +180°; the three colours cycle too.")
    figs = [_fig(shape, tint[i], 1, True, turns[i]) for i in range(5)]
    correct = figs[4]
    wrong = [
        {**correct, "r": (correct["r"] + 45) % 360},
        {**correct, "r": (correct["r"] + 180) % 360},
        {**correct, "c": next(c for c in colors if c != correct["c"])}
        if level > 1
        else {**correct, "r": (correct["r"] + 90) % 360},
    ]
    return _figure_puzzle(
        rng, "rotation", level,
        _text("Quelle figure vient ensuite ?", "Which figure comes next?"),
        why, "row", [*figs[:4], None], correct, wrong,
    )


def _figure_odd(rng: random.Random, level: int) -> Puzzle:
    """Intrus visuel : trois figures suivent une règle, pas la quatrième."""
    if level == 1:
        same, odd = rng.sample(_SHAPES, 2)
        good = [_fig(same, c, rng.randint(1, 3)) for c in rng.sample(range(4), 3)]
        intruder = _fig(odd, rng.randrange(4), rng.randint(1, 3))
        why = _text("Trois figures ont la même forme, pas l'intrus.", "Three figures share the same shape, the odd one doesn't.")
    elif level == 2:
        n = rng.randint(1, 4)
        good = [_fig(sh, rng.randrange(4), n, rng.random() < 0.5) for sh in rng.sample(_SHAPES, 3)]
        intruder = _fig(rng.choice(_SHAPES), rng.randrange(4), rng.choice([k for k in range(1, 5) if k != n]))
        why = _text(f"Trois figures ont {n} forme(s), l'intrus non.", f"Three figures have {n} shape(s), the odd one doesn't.")
    else:
        # Côtés en tout : 2 hexagones = 3 carrés = 4 triangles = 12 côtés.
        good = [_fig("hexagon", 0, 2), _fig("square", 0, 3), _fig("triangle", 0, 4)]
        for g in good:
            g["c"] = rng.randrange(4)
        n, sh = rng.choice([(2, "pentagon"), (3, "triangle"), (1, "hexagon"), (2, "square"), (4, "square")])
        intruder = _fig(sh, rng.randrange(4), n)
        why = _text(
            f"Comptez tous les côtés : 12 dans chaque figure, sauf l'intrus ({n} × {_SIDES[sh]} = {n * _SIDES[sh]}).",
            f"Count all the sides: 12 in each figure, except the odd one ({n} × {_SIDES[sh]} = {n * _SIDES[sh]}).",
        )
    return _figure_puzzle(
        rng, "figure_odd", level,
        _text("Quelle figure est l'intrus ?", "Which figure is the odd one out?"),
        why, "none", [], intruder, good,
    )


# ------------------------------------------------------------------ un seul trait


def _euler_trail(edges: list[tuple[int, int]]) -> list[int]:
    """Un chemin qui passe une fois par chaque ligne (algorithme de Hierholzer)."""
    adjacency: dict[int, list[int]] = {}
    for i, (a, b) in enumerate(edges):
        adjacency.setdefault(a, []).append(i)
        adjacency.setdefault(b, []).append(i)
    odd = [n for n, e in adjacency.items() if len(e) % 2]
    start = odd[0] if odd else edges[0][0]
    used = [False] * len(edges)
    stack, trail = [start], []
    while stack:
        node = stack[-1]
        while adjacency[node] and used[adjacency[node][-1]]:
            adjacency[node].pop()
        if adjacency[node]:
            i = adjacency[node].pop()
            used[i] = True
            a, b = edges[i]
            stack.append(b if a == node else a)
        else:
            trail.append(stack.pop())
    return trail[::-1]


def valid_trace(trace: dict, raw: str) -> bool:
    """Le chemin donné passe-t-il exactement une fois par chaque ligne, sans saut ?"""
    try:
        path = [int(x) for x in str(raw).split("-")]
    except ValueError:
        return False
    remaining = {tuple(sorted(e)) for e in trace["edges"]}
    if len(path) != len(remaining) + 1:
        return False
    for a, b in zip(path, path[1:]):
        edge = (min(a, b), max(a, b))
        if edge not in remaining:
            return False
        remaining.remove(edge)
    return not remaining


def _trace(rng: random.Random, level: int) -> Puzzle:
    """Tracer une figure d'un seul trait, sans repasser deux fois sur une ligne."""
    cols, rows = (3, 3) if level < 3 else (4, 3)
    low, high = {1: (5, 7), 2: (8, 10), 3: (11, 14)}[level]
    nodes = [(x, y) for y in range(rows) for x in range(cols)]
    index = {p: i for i, p in enumerate(nodes)}
    for _ in range(4000):
        candidates = []
        for x, y in nodes:
            if x + 1 < cols:
                candidates.append((index[(x, y)], index[(x + 1, y)]))
            if y + 1 < rows:
                candidates.append((index[(x, y)], index[(x, y + 1)]))
            # Une seule diagonale par case : les lignes ne se croisent jamais hors d'un point.
            if x + 1 < cols and y + 1 < rows:
                if rng.random() < 0.5:
                    candidates.append((index[(x, y)], index[(x + 1, y + 1)]))
                else:
                    candidates.append((index[(x + 1, y)], index[(x, y + 1)]))
        edges = rng.sample(candidates, rng.randint(low, high))
        degree: dict[int, int] = {}
        for a, b in edges:
            degree[a] = degree.get(a, 0) + 1
            degree[b] = degree.get(b, 0) + 1
        odd = [n for n, d in degree.items() if d % 2]
        if len(odd) not in (0, 2) or (level > 1 and max(degree.values()) < 3):
            continue
        # Figure d'un seul morceau.
        seen, todo = set(), [edges[0][0]]
        while todo:
            n = todo.pop()
            if n in seen:
                continue
            seen.add(n)
            todo += [b if a == n else a for a, b in edges if n in (a, b)]
        if seen != set(degree):
            continue
        used_nodes = sorted(degree)
        renum = {old: new for new, old in enumerate(used_nodes)}
        edges = sorted((min(renum[a], renum[b]), max(renum[a], renum[b])) for a, b in edges)
        break
    trail = _euler_trail(edges)
    odd_count = sum(1 for n in range(len(used_nodes)) if sum(n in e for e in edges) % 2)
    why = (
        _text("Deux points ont un nombre impair de lignes : il faut partir de l'un et finir sur l'autre.",
              "Two dots have an odd number of lines: start at one and finish at the other.")
        if odd_count
        else _text("Chaque point a un nombre pair de lignes : on peut partir de n'importe où, et on revient au départ.",
                   "Every dot has an even number of lines: start anywhere, you will come back to the start.")
    )
    return Puzzle(
        id=f"trace-{level}-{'-'.join(f'{a}.{b}' for a, b in edges)}",
        kind="trace",
        level=level,
        input="trace",
        prompt=_text(
            "Trace la figure d'un seul trait : passe sur chaque ligne une seule fois, sans lever le doigt.",
            "Draw the figure in one stroke: go over every line exactly once, without lifting your finger.",
        ),
        answer="-".join(map(str, trail)),
        explanation=why,
        trace={"points": [list(nodes[i]) for i in used_nodes], "edges": [list(e) for e in edges]},
    )


_GENERATORS = [
    ("sequence", 3, _sequence),
    ("grid", 2, _grid),
    ("problem", 2, _problem),
    ("letters", 1, _letters),
    ("calendar", 1, _calendar),
    ("analogy", 2, lambda rng, lvl: _bank(rng, lvl, "analogy", ANALOGIES)),
    ("odd", 2, lambda rng, lvl: _bank(rng, lvl, "odd", ODD_ONE_OUT)),
    ("logic", 2, lambda rng, lvl: _bank(rng, lvl, "logic", LOGIC)),
    ("matrix", 2, _matrix),
    ("rotation", 2, _rotation),
    ("figure_odd", 2, _figure_odd),
    ("trace", 2, _trace),
]


def level_for(round_number: int, rounds: int, difficulty: str) -> int:
    """La difficulté monte au fil des manches ; « facile » et « difficile » décalent d'un cran."""
    progress = (round_number - 1) / max(1, rounds - 1)
    base = 1 if progress < 0.34 else (2 if progress < 0.67 else 3)
    shift = {"easy": -1, "normal": 0, "hard": 1}.get(str(difficulty), 0)
    return max(1, min(3, base + shift))


def draw(level: int, exclude: set[str] | None = None, rng: random.Random | None = None) -> Puzzle:
    """Une énigme du niveau voulu, jamais deux fois la même dans la partie."""
    rng = rng or random.Random()
    exclude = exclude or set()
    weights = [w for _, w, _ in _GENERATORS]
    puzzle = None
    for _ in range(40):
        _, _, make = rng.choices(_GENERATORS, weights=weights)[0]
        puzzle = make(rng, level)
        if puzzle.id not in exclude:
            return puzzle
    return puzzle


def check(puzzle: Puzzle, raw: object) -> bool:
    """Réponse juste ? Nombres : « 1 024 », « 1024 » et « 1024,0 » se valent."""
    text = str(raw if raw is not None else "").strip().replace(" ", "").replace(",", ".")
    if not text:
        return False
    if puzzle.input == "trace":
        return puzzle.trace is not None and valid_trace(puzzle.trace, text)
    if puzzle.input == "choice":
        return text == puzzle.answer
    try:
        return float(text) == float(puzzle.answer)
    except ValueError:
        return False


def points(correct: bool, answered: bool, elapsed: float, duration: float, speed_bonus: bool, penalty: bool) -> int:
    """10 points si c'est juste (+ jusqu'à 10 selon la rapidité) ; −5 si c'est faux avec malus."""
    if correct:
        bonus = 0
        if speed_bonus and duration > 0:
            bonus = round(SPEED_BONUS_MAX * max(0.0, 1 - elapsed / duration))
        return POINTS_CORRECT + bonus
    return -WRONG_PENALTY if penalty and answered else 0


def wrong_answer(puzzle: Puzzle, rng: random.Random) -> str:
    """Réponse fausse plausible (bots qui se trompent)."""
    if puzzle.input == "choice":
        return rng.choice([str(i) for i in range(4) if str(i) != puzzle.answer])
    if puzzle.input == "trace":
        # Tracé arrêté avant la fin : il manque une ligne.
        return "-".join(puzzle.answer.split("-")[:-1])
    value = int(float(puzzle.answer))
    return str(value + rng.choice([-3, -2, -1, 1, 2, 3, 10]))


def joker_allowed(puzzle: Puzzle, kind: str) -> bool:
    """50/50 pour les choix, indice pour les nombres ; +15 s et passer pour toutes."""
    if kind == "fifty":
        return puzzle.input == "choice"
    if kind == "hint":
        return puzzle.input in ("number", "trace")
    return kind in ("time", "skip")


def fifty(puzzle: Puzzle, rng: random.Random) -> list[int]:
    """Deux mauvais choix à retirer."""
    wrong = [i for i in range(4) if str(i) != puzzle.answer]
    return sorted(rng.sample(wrong, 2))


def hint(puzzle: Puzzle, rng: random.Random) -> dict:
    """Indice : un intervalle pour un nombre, le point de départ pour un tracé."""
    if puzzle.input == "trace":
        return {"start": int(puzzle.answer.split("-")[0])}
    low, high = hint_range(puzzle, rng)
    return {"low": low, "high": high}


def hint_range(puzzle: Puzzle, rng: random.Random) -> tuple[int, int]:
    """Un intervalle d'entiers qui contient la réponse, sans la mettre au milieu."""
    value = round(float(puzzle.answer))
    width = max(4, round(abs(value) * 0.3))
    low = value - rng.randint(1, width - 1)
    return low, low + width


def puzzle_from(data: dict) -> Puzzle:
    """Énigme gardée en base (reveal()) remise en objet."""
    return Puzzle(
        id=data["id"],
        kind=data["kind"],
        level=data["level"],
        input=data["input"],
        prompt=data["prompt"],
        answer=data["answer"],
        explanation=data["explanation"],
        choices=data.get("choices"),
        grid=data.get("grid"),
        items=data.get("items") or [],
        figures=data.get("figures"),
        trace=data.get("trace"),
    )


def iq_estimate(results: list[tuple[int, bool]]) -> int:
    """QI estimé (pour s'amuser) à partir de (niveau, juste) : 70 à 145."""
    if not results:
        return 100
    weight = {1: 1.0, 2: 1.5, 3: 2.0}
    total = sum(weight[level] for level, _ in results)
    got = sum(weight[level] for level, ok in results if ok)
    return round(70 + 75 * got / total)
