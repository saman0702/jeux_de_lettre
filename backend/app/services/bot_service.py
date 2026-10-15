"""Computer opponents.

A bot answers like a person would: not every category, not instantly, with
well-known answers (Paris before an unknown village) and the odd typo. The
level sets how often it finds an answer, how fast, and how obscure its
answers can be.
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
    answer_rate: float  # chance to fill in a category
    typo_rate: float  # chance a given answer is misspelled (and rejected)
    answer_time: tuple[float, float]  # share of the round before submitting
    pool: int  # picks among the N most popular answers for the letter


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
    """The most popular known answers per category for this letter."""
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

