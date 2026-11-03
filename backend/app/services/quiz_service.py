"""QCM Chrono / Mot & Sens : tirage compatible avec le pipeline QI (choix 0–3)."""

from __future__ import annotations

import random

from app.data.chrono_bank import CHRONO_QUESTIONS
from app.data.mots_bank import MOTS_QUESTIONS
from app.services.iq_service import Puzzle, level_for

BANKS = {
    "chrono": CHRONO_QUESTIONS,
    "mots": MOTS_QUESTIONS,
}


def draw(game: str, level: int, exclude: set[str] | None = None, rng: random.Random | None = None) -> Puzzle:
    """Tire une question du niveau demandé (repli sur d'autres niveaux si besoin)."""
    rng = rng or random.Random()
    bank = BANKS[game]
    exclude = exclude or set()
    pool = [q for q in bank if q["level"] == level and q["id"] not in exclude]
    if not pool:
        pool = [q for q in bank if q["id"] not in exclude]
    if not pool:
        pool = list(bank)
    q = rng.choice(pool)
    return Puzzle(
        id=q["id"],
        kind=q["kind"],
        level=q["level"],
        input="choice",
        prompt=q["prompt"],
        answer=str(q["answer"]),
        explanation=q["explanation"],
        choices=q["choices"],
    )


def wrong_answer(puzzle: Puzzle, rng: random.Random | None = None) -> str:
    rng = rng or random.Random()
    options = [str(i) for i in range(4) if str(i) != puzzle.answer]
    return rng.choice(options)
