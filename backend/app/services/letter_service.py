"""Server-side letter draw."""

import secrets
import time
from collections.abc import Iterable

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import (
    ANY_LANGUAGE,
    LETTER_POOLS,
    MIN_ANSWERS_PER_CATEGORY,
    Difficulty,
)
from app.models import Answer

LetterCounts = dict[str, dict[str, int]]  # category -> letter -> number of answers

_CACHE_TTL_SECONDS = 600
_counts_cache: dict[str, tuple[float, LetterCounts]] = {}


class NoLetterAvailable(Exception):
    pass


async def letter_counts(session: AsyncSession, language: str) -> LetterCounts:
    cached = _counts_cache.get(language)
    if cached and time.monotonic() - cached[0] < _CACHE_TTL_SECONDS:
        return cached[1]

    rows = await session.execute(
        select(Answer.category, Answer.first_letter, func.count())
        .where(Answer.language.in_([language, ANY_LANGUAGE]), Answer.accepted.is_(True))
        .group_by(Answer.category, Answer.first_letter)
    )
    counts: LetterCounts = {}
    for category, letter, count in rows:
        counts.setdefault(category, {})
        counts[category][letter] = counts[category].get(letter, 0) + count

    _counts_cache[language] = (time.monotonic(), counts)
    return counts


def clear_cache() -> None:
    _counts_cache.clear()


def eligible_letters(
    counts: LetterCounts, categories: Iterable[str], difficulty: Difficulty
) -> set[str]:
    minimum = MIN_ANSWERS_PER_CATEGORY[difficulty]
    return {
        letter
        for letter in LETTER_POOLS[difficulty]
        if all(counts.get(category, {}).get(letter, 0) >= minimum for category in categories)
    }


def draw_letter(eligible: set[str], used: Iterable[str]) -> str:
    """Pick a letter not used yet in the game; reuse letters only once all are spent."""
    if not eligible:
        raise NoLetterAvailable
    fresh = eligible - set(used)
    return secrets.choice(sorted(fresh or eligible))
