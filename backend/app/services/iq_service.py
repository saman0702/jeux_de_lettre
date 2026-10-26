"""Énigmes de QI : tirage, vérification et points.

Deux sortes d'énigmes :
- « number » : le joueur tape un nombre (suites, grilles, calculs) ;
- « choice » : 4 choix, un seul bon (analogies, intrus, logique, suites de lettres, calendrier…).

Le texte est donné en français et en anglais : dans une partie mélangée, chacun lit dans sa langue.
Les suites, grilles et problèmes sont générés (en nombre illimité) ; les autres viennent de
app/data/iq_bank.py.
"""

import random
from dataclasses import dataclass, field

from app.data.iq_bank import ANALOGIES, LOGIC, ODD_ONE_OUT

POINTS_CORRECT = 10
SPEED_BONUS_MAX = 10
WRONG_PENALTY = 5


@dataclass(frozen=True)
class Puzzle:
    id: str
    kind: str  # sequence | grid | problem | analogy | odd | logic | letters | calendar
    level: int  # 1 facile, 2 moyen, 3 difficile
    input: str  # number | choice
    prompt: dict[str, str]
    answer: str  # nombre, ou indice du bon choix
    explanation: dict[str, str]
    choices: dict[str, list[str]] | None = None
    # Grille de nombres (« ? » pour la case à trouver).
    grid: list[list[str]] | None = None
    # Suite affichée en grandes tuiles.
    items: list[str] = field(default_factory=list)

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


_GENERATORS = [
    ("sequence", 3, _sequence),
    ("grid", 2, _grid),
    ("problem", 2, _problem),
    ("letters", 1, _letters),
    ("calendar", 1, _calendar),
    ("analogy", 2, lambda rng, lvl: _bank(rng, lvl, "analogy", ANALOGIES)),
    ("odd", 2, lambda rng, lvl: _bank(rng, lvl, "odd", ODD_ONE_OUT)),
    ("logic", 2, lambda rng, lvl: _bank(rng, lvl, "logic", LOGIC)),
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
    value = int(float(puzzle.answer))
    return str(value + rng.choice([-3, -2, -1, 1, 2, 3, 10]))


def iq_estimate(results: list[tuple[int, bool]]) -> int:
    """QI estimé (pour s'amuser) à partir de (niveau, juste) : 70 à 145."""
    if not results:
        return 100
    weight = {1: 1.0, 2: 1.5, 3: 2.0}
    total = sum(weight[level] for level, _ in results)
    got = sum(weight[level] for level, ok in results if ok)
    return round(70 + 75 * got / total)
