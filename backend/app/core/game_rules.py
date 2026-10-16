"""Règles du jeu communes à tous les modes (solo, duel, multijoueur)."""

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


# Entrées de la base valables quelle que soit la langue de la partie (ex. noms de villes).
ANY_LANGUAGE = "*"

ROUND_OPTIONS = (5, 10, 15)
DURATION_OPTIONS = (15, 30, 45, 60)

HARD_LETTERS = frozenset("KQWXYZ")
ALL_LETTERS = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

# Lettres que le tirage peut choisir, selon la difficulté.
LETTER_POOLS: dict[Difficulty, frozenset[str]] = {
    Difficulty.EASY: frozenset("ABCDEFGLMPRST"),
    Difficulty.NORMAL: ALL_LETTERS - HARD_LETTERS,
    Difficulty.HARD: ALL_LETTERS,
}

# Une lettre n'est tirée que si chaque catégorie choisie compte au moins ce nombre de réponses
# connues pour elle : une partie facile ne tombe jamais sur une lettre quasi impossible.
MIN_ANSWERS_PER_CATEGORY: dict[Difficulty, int] = {
    Difficulty.EASY: 5,
    Difficulty.NORMAL: 3,
    Difficulty.HARD: 1,
}

POINTS_UNIQUE = 10
POINTS_SHARED = 5

# Délai accepté après `ends_at` pour absorber la latence réseau à l'envoi des réponses.
SUBMIT_GRACE_SECONDS = 2.0

MIN_ROOM_PLAYERS = 2
MAX_ROOM_PLAYERS = 8

# Jokers : quatre mots, un seul valide pour la catégorie ; un bon choix rapporte la moitié des
# points.
HINTS_PER_GAME = 3
HINT_OPTIONS = 4
HINT_POINTS_UNIQUE = 5
HINT_POINTS_SHARED = 2
