"""Game rules shared by every mode (solo, duel, multiplayer)."""

from enum import StrEnum


class Category(StrEnum):
    CITY = "city"
    COUNTRY = "country"
    ANIMAL = "animal"
    FRUIT = "fruit"


class Language(StrEnum):
    FR = "fr"
    EN = "en"


class Difficulty(StrEnum):
    EASY = "easy"
    NORMAL = "normal"
    HARD = "hard"


# Knowledge-base entries valid whatever the game language (e.g. city names).
ANY_LANGUAGE = "*"

ROUND_OPTIONS = (5, 10, 15)
DURATION_OPTIONS = (15, 30, 45, 60)

HARD_LETTERS = frozenset("KQWXYZ")
ALL_LETTERS = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

# Letters the draw may pick from, per difficulty.
LETTER_POOLS: dict[Difficulty, frozenset[str]] = {
    Difficulty.EASY: frozenset("ABCDEFGLMPRST"),
    Difficulty.NORMAL: ALL_LETTERS - HARD_LETTERS,
    Difficulty.HARD: ALL_LETTERS,
}

# A letter is only drawn if every selected category has at least this many
# known answers for it, so easy games never get an almost-impossible letter.
MIN_ANSWERS_PER_CATEGORY: dict[Difficulty, int] = {
    Difficulty.EASY: 5,
    Difficulty.NORMAL: 3,
    Difficulty.HARD: 1,
}

POINTS_UNIQUE = 10
POINTS_SHARED = 5

# Extra time accepted after `ends_at` to absorb network latency on submit.
SUBMIT_GRACE_SECONDS = 2.0

MIN_ROOM_PLAYERS = 2
MAX_ROOM_PLAYERS = 8
