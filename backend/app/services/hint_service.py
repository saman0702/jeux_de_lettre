"""Jokers : quatre mots commençant par la lettre de la manche, dont un seul appartient à la catégorie.
Les leurres viennent des autres catégories (un fruit proposé pour « Animal ») : il faut savoir
lequel convient.

Le serveur garde la bonne réponse ; les clients ne voient que les quatre propositions.
"""

import random
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import ANY_LANGUAGE, HINT_OPTIONS, Category
from app.models import Answer
from app.services.normalization import normalize

_POOL = 60
# Les leurres doivent être crédibles : seulement les villes les plus connues (Lima, pas Laiwu).
_DECOY_POOL = {"city": 12}
_DEFAULT_DECOY_POOL = 40


@dataclass
class Hint:
    category: str
    options: list[str]
    answer: str
    picked: str | None = None

    @property
    def correct(self) -> bool | None:
        """None tant que le joueur n'a pas choisi."""
        return None if self.picked is None else self.picked == self.answer


class NoHintAvailable(Exception):
    pass


async def popular_answers(session: AsyncSession, category: str, language: str, letter: str) -> list[str]:
    rows = await session.scalars(
        select(Answer.value)
        .where(
            Answer.category == category,
            Answer.language.in_([language, ANY_LANGUAGE]),
            Answer.first_letter == letter,
            Answer.accepted.is_(True),
        )
        .order_by(Answer.popularity.desc(), Answer.id)
        .limit(_POOL)
    )
    return list(rows)


async def _valid_keys(session: AsyncSession, category: str, language: str, keys: list[str]) -> set[str]:
    rows = await session.scalars(
        select(Answer.normalized_value).where(
            Answer.category == category,
            Answer.language.in_([language, ANY_LANGUAGE]),
            Answer.normalized_value.in_(keys),
        )
    )
    return set(rows)


def _scramble(word: str, rng: random.Random) -> str:
    """Un faux mot crédible qui garde la première lettre (« Moutno »)."""
    if len(word) < 4:
        return word + word[-1].lower()
    middle = list(word[1:])
    for _ in range(10):
        rng.shuffle(middle)
        candidate = word[0] + "".join(middle)
        if candidate != word:
            return candidate
    return word + word[-1].lower()


async def build_hint(
    session: AsyncSession, language: str, category: str, letter: str, rng: random.Random | None = None
    ) -> Hint:
    rng = rng or random.Random()
    answers = await popular_answers(session, category, language, letter)
    if not answers:
        raise NoHintAvailable
    answer = rng.choice(answers[: _DECOY_POOL.get(category, 20)])

    decoys: list[str] = []
    others = [c.value for c in Category if c.value != category]
    rng.shuffle(others)
    for other in others:
        candidates = (await popular_answers(session, other, language, letter))[
            : _DECOY_POOL.get(other, _DEFAULT_DECOY_POOL)
        ]
        rng.shuffle(candidates)
        if not candidates:
            continue
        # Un leurre qui conviendrait aussi à la catégorie (kiwi : fruit et oiseau) serait injuste.
        valid = await _valid_keys(session, category, language, [normalize(c) for c in candidates])
        for candidate in candidates:
            if normalize(candidate) not in valid and candidate not in decoys:
                decoys.append(candidate)
                break
    for _ in range(20):
        if len(decoys) >= HINT_OPTIONS - 1:
            break
        decoy = _scramble(rng.choice([answer, *decoys]), rng)
        if decoy not in decoys and normalize(decoy) != normalize(answer):
            decoys.append(decoy)

    options = [answer, *decoys[: HINT_OPTIONS - 1]]
    rng.shuffle(options)
    return Hint(category=category, options=options, answer=answer)
