import pytest

from app.core.game_rules import Difficulty
from app.services.letter_service import NoLetterAvailable, draw_letter, eligible_letters

COUNTS = {
    "city": {"A": 10, "M": 10, "Z": 10},
    "fruit": {"A": 10, "M": 2, "Z": 1},
}


def test_hard_letters_only_in_hard_mode():
    assert "Z" not in eligible_letters(COUNTS, ["city"], Difficulty.NORMAL)
    assert "Z" in eligible_letters(COUNTS, ["city"], Difficulty.HARD)


def test_letter_needs_enough_answers_in_every_category():
    assert eligible_letters(COUNTS, ["city", "fruit"], Difficulty.NORMAL) == {"A"}
    assert eligible_letters(COUNTS, ["city", "fruit"], Difficulty.HARD) == {"A", "M", "Z"}


def test_draw_avoids_letters_already_used():
    assert draw_letter({"A", "M"}, used=["A"]) == "M"


def test_draw_reuses_letters_once_all_are_spent():
    assert draw_letter({"A"}, used=["A"]) == "A"


def test_draw_without_eligible_letter_fails():
    with pytest.raises(NoLetterAvailable):
        draw_letter(set(), used=[])
