import pytest

from app.core.game_rules import Category
from app.services.validation_service import Status, validate_answer


@pytest.mark.parametrize(
    ("category", "language", "letter", "raw", "status"),
    [
        (Category.ANIMAL, "fr", "M", "Mouton", Status.VALID),
        (Category.ANIMAL, "fr", "E", "ÉLÉPHANT", Status.VALID),
        (Category.ANIMAL, "fr", "E", "  l'éléphant ", Status.VALID),
        (Category.FRUIT, "fr", "M", "mangues", Status.VALID),
        (Category.ANIMAL, "fr", "M", "Chat", Status.WRONG_LETTER),
        (Category.COUNTRY, "fr", "M", "Marseille", Status.NOT_FOUND),
        (Category.ANIMAL, "en", "M", "Mouton", Status.NOT_FOUND),
        (Category.ANIMAL, "en", "S", "Sheep", Status.VALID),
        (Category.CITY, "en", "M", "Mbandaka", Status.VALID),
        (Category.CITY, "fr", "H", "le havre", Status.VALID),
        (Category.COUNTRY, "fr", "C", "cote d'ivoire", Status.VALID),
        (Category.COUNTRY, "fr", "R", "RDC", Status.VALID),
        (Category.FRUIT, "fr", "K", "kiwi", Status.VALID),
        (Category.CITY, "fr", "M", "", Status.EMPTY),
    ],
)
async def test_validate_answer(session, category, language, letter, raw, status):
    result = await validate_answer(session, category, language, letter, raw)
    assert result.status == status


async def test_valid_answer_returns_canonical_value(session):
    result = await validate_answer(session, Category.ANIMAL, "fr", "E", "elephant")
    assert result.matched_value == "Éléphant"
