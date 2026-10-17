"""Adversaires contrôlés par l'ordinateur.

Un bot répond comme une personne : pas à toutes les catégories, pas instantanément, avec des
réponses connues (Paris avant un village inconnu) et quelques fautes de frappe. Le niveau règle la
fréquence de ses réponses, sa rapidité et la rareté de ses réponses.
"""

import random
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import ANY_LANGUAGE, Category, Difficulty
from app.models import Answer

BOT_NAMES = ["Robo-Léa", "Robo-Max", "Robo-Zoé", "Robo-Tom", "Robo-Inès", "Robo-Sam", "Robo-Nina", "Robo-Yao"]


@dataclass(frozen=True)
class BotProfile:
    answer_rate: float  # probabilité de remplir une catégorie
    typo_rate: float  # probabilité qu'une réponse soit mal orthographiée (et donc refusée)
    answer_time: tuple[float, float]  # part de la manche écoulée avant l'envoi
    pool: int  # choisit parmi les N réponses les plus connues pour la lettre


BOT_PROFILES: dict[Difficulty, BotProfile] = {
    Difficulty.EASY: BotProfile(answer_rate=0.5, typo_rate=0.15, answer_time=(0.55, 0.95), pool=15),
    Difficulty.NORMAL: BotProfile(answer_rate=0.75, typo_rate=0.07, answer_time=(0.35, 0.8), pool=80),
    Difficulty.HARD: BotProfile(answer_rate=0.92, typo_rate=0.02, answer_time=(0.2, 0.55), pool=600),
}


def bot_name(taken: set[str], rng: random.Random | None = None) -> str:
    rng = rng or random.Random()
    free = [name for name in BOT_NAMES if name not in taken]
    if free:
        return rng.choice(free)
    return f"Robo-{rng.randint(10, 99)}"


async def candidates(
    session: AsyncSession, language: str, categories: list[str], letter: str, pool: int
) -> dict[str, list[str]]:
    """Les réponses connues les plus populaires par catégorie pour cette lettre."""
    result: dict[str, list[str]] = {}
    for category in categories:
        rows = await session.scalars(
            select(Answer.value)
            .where(
                Answer.category == category,
                Answer.language.in_([language, ANY_LANGUAGE]),
                Answer.first_letter == letter,
                Answer.accepted.is_(True),
            )
            .order_by(Answer.popularity.desc(), Answer.id)
            .limit(pool)
        )
        result[category] = list(rows)
    return result


def _typo(word: str, rng: random.Random) -> str:
    if len(word) < 4:
        return word + word[-1]
    i = rng.randrange(1, len(word) - 1)
    return word[:i] + word[i + 1] + word[i] + word[i + 2 :]


def choose_answers(
    profile: BotProfile, options: dict[str, list[str]], rng: random.Random | None = None
    ) -> dict[Category, str]:
    rng = rng or random.Random()
    answers: dict[Category, str] = {}
    for category, values in options.items():
        if not values or rng.random() > profile.answer_rate:
            continue
        answer = rng.choice(values)
        if rng.random() < profile.typo_rate:
            answer = _typo(answer, rng)
        answers[Category(category)] = answer
    return answers


def answer_delay(profile: BotProfile, round_seconds: float, rng: random.Random | None = None) -> float:
    rng = rng or random.Random()
    low, high = profile.answer_time
    return round_seconds * rng.uniform(low, high)

