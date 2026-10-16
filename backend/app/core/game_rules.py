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

# Pièces : les points validés par le serveur se convertissent en pièces.
POINTS_PER_COIN = 20
# Mise maximale d'un salon de paris.
MAX_STAKE = 1000

# Packs de pièces vendus dans les stores : identifiant du produit (le même dans la Play Console et
# App Store Connect) -> nombre de pièces. Les prix sont fixés dans les stores.
COIN_PACKS = {
    "coins_100": 100,
    "coins_550": 550,
    "coins_1200": 1200,
    "coins_2500": 2500,
}

# Niveaux de joueur : l'expérience est le total des points marqués dans les parties validées par
# le serveur. Atteindre le niveau N demande LEVEL_XP_STEP * N * (N - 1) / 2 points au total :
# niveau 2 à 100, 3 à 300, 4 à 600, 5 à 1 000, 10 à 4 500…
LEVEL_XP_STEP = 100
