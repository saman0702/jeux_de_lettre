"""Check a player's answer against the knowledge base."""

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import ANY_LANGUAGE, Category
from app.models import Answer
from app.services.normalization import lookup_keys, normalize, starts_with_letter


class Status:
    VALID = "valid"
    EMPTY = "empty"
    WRONG_LETTER = "wrong_letter"
    NOT_FOUND = "not_found"
    LATE = "late"
    HINT_WRONG = "hint_wrong"


@dataclass(frozen=True)
class ValidationResult:
    status: str
    matched_value: str | None = None
    # Canonical key used to detect identical answers between players.
    match_key: str | None = None

    @property
    def is_valid(self) -> bool:
        return self.status == Status.VALID


async def validate_answer(
    session: AsyncSession, category: Category, language: str, letter: str, raw: str
) -> ValidationResult:
    keys = lookup_keys(raw, category)
    if not keys:
        return ValidationResult(Status.EMPTY)

    rows = await session.execute(
        select(Answer.value, Answer.normalized_value).where(
            Answer.category == category,
            Answer.language.in_([language, ANY_LANGUAGE]),
            Answer.accepted.is_(True),
            Answer.normalized_value.in_(keys),
        )
    )
    found = {normalized: value for value, normalized in rows}
    match = next((key for key in keys if key in found), None)

    if match is None:
        if not starts_with_letter(normalize(raw), letter):
            return ValidationResult(Status.WRONG_LETTER)
        return ValidationResult(Status.NOT_FOUND)

    if not starts_with_letter(match, letter):
        return ValidationResult(Status.WRONG_LETTER, matched_value=found[match])

    return ValidationResult(Status.VALID, matched_value=found[match], match_key=match)
