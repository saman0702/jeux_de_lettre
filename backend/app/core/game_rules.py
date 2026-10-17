"""Règles du jeu communes à tous les modes (solo, duel, multijoueur)."""

from enum import StrEnum


class Category(StrEnum):
    CITY = "city"
    COUNTRY = "country"
    ANIMAL = "animal"
    FRUIT = "fruit"
    FEMALE_NAME = "female_name"
    MALE_NAME = "male_name"


# Catégories cochées par défaut (le Petit Bac classique).
CLASSIC_CATEGORIES = (Category.CITY, Category.COUNTRY, Category.ANIMAL, Category.FRUIT)

# À partir de ce nombre de catégories, une manche doit durer plus de 30 secondes.
MANY_CATEGORIES = 5
MANY_CATEGORIES_MIN_DURATION = 45


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

# Jokers : trois mots, un seul valide pour la catégorie ; un bon choix rapporte la moitié des
# points.
HINTS_PER_GAME = 3
HINT_OPTIONS = 3
HINT_POINTS_UNIQUE = 5
HINT_POINTS_SHARED = 2

# Pièces : les points validés par le serveur se convertissent en pièces.
POINTS_PER_COIN = 20

# Achats en pièces pendant / après une manche (ne changent pas le score).
# Infos : 1 pièce si la réponse était juste, 2 sinon.
CATEGORY_INFO_PRICE_FOUND = 1
CATEGORY_INFO_PRICE_MISSED = 2
EXTRA_HINT_PRICE = 5

# Apparences achetées avec des pièces (pas d'avantage de jeu).
# hair/hat : calques sur l'avatar ; frame/name : visibles en salon ;
# tiles/victory : chez soi (tuiles de saisie / confettis).

COSMETICS = (
    {"id": "hair_spiky", "kind": "hair", "price": 25, "color": "ink"},
    {"id": "hair_bob", "kind": "hair", "price": 25, "color": "pink"},
    {"id": "hair_curly", "kind": "hair", "price": 25, "color": "cyan"},
    {"id": "hair_bun", "kind": "hair", "price": 25, "color": "yellow"},
    {"id": "hat_crown", "kind": "hat", "price": 40, "color": "yellow"},
    {"id": "hat_cap", "kind": "hat", "price": 30, "color": "red"},
    {"id": "hat_wizard", "kind": "hat", "price": 35, "color": "purple"},
    {"id": "hat_party", "kind": "hat", "price": 30, "color": "pink"},
    {"id": "frame_gold", "kind": "frame", "price": 15, "color": "yellow"},
    {"id": "frame_pink", "kind": "frame", "price": 15, "color": "pink"},
    {"id": "frame_cyan", "kind": "frame", "price": 15, "color": "cyan"},
    {"id": "frame_ornament", "kind": "frame", "price": 25, "color": "yellow"},
    {"id": "frame_flames", "kind": "frame", "price": 25, "color": "orange"},
    {"id": "frame_stars", "kind": "frame", "price": 25, "color": "purple"},
    {"id": "name_rose", "kind": "name", "price": 10, "color": "pink"},
    {"id": "name_violet", "kind": "name", "price": 10, "color": "purple"},
    {"id": "name_orange", "kind": "name", "price": 10, "color": "orange"},
    {"id": "name_gradient", "kind": "name", "price": 18, "color": "pink"},
    {"id": "name_outline", "kind": "name", "price": 18, "color": "yellow"},
    {"id": "name_badge", "kind": "name", "price": 18, "color": "orange"},
    {"id": "tiles_sunset", "kind": "tiles", "price": 20, "color": "orange"},
    {"id": "tiles_ocean", "kind": "tiles", "price": 20, "color": "cyan"},
    {"id": "tiles_candy", "kind": "tiles", "price": 20, "color": "pink"},
    {"id": "tiles_stripes", "kind": "tiles", "price": 25, "color": "cyan"},
    {"id": "tiles_dots", "kind": "tiles", "price": 25, "color": "pink"},
    {"id": "tiles_metal", "kind": "tiles", "price": 25, "color": "ink"},
    {"id": "victory_gold", "kind": "victory", "price": 15, "color": "yellow"},
    {"id": "victory_pink", "kind": "victory", "price": 15, "color": "pink"},
    {"id": "victory_mint", "kind": "victory", "price": 15, "color": "green"},
    {"id": "victory_stars", "kind": "victory", "price": 22, "color": "yellow"},
    {"id": "victory_bubbles", "kind": "victory", "price": 22, "color": "cyan"},
    {"id": "victory_letters", "kind": "victory", "price": 22, "color": "orange"},
)
COSMETIC_BY_ID = {item["id"]: item for item in COSMETICS}
COSMETIC_KINDS = ("hair", "hat", "frame", "name", "tiles", "victory")

# Packs thématiques : moins cher que d'acheter chaque pièce séparément.
COSMETIC_PACKS = (
    {
        "id": "pack_ocean",
        "price": 40,
        "items": ("frame_cyan", "tiles_ocean", "victory_bubbles"),
    },
    {
        "id": "pack_candy",
        "price": 40,
        "items": ("frame_pink", "tiles_candy", "victory_stars"),
    },
    {
        "id": "pack_royal",
        "price": 50,
        "items": ("frame_ornament", "name_outline", "victory_stars"),
    },
)
COSMETIC_PACK_BY_ID = {pack["id"]: pack for pack in COSMETIC_PACKS}
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
