from datetime import datetime

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.game_rules import (
    CLASSIC_CATEGORIES,
    DURATION_OPTIONS,
    MANY_CATEGORIES,
    MANY_CATEGORIES_MIN_DURATION,
    ROOM_THEMES,
    ROUND_OPTIONS,
    STRICT_SPELLING_MIN_DURATION,
    Category,
    Difficulty,
    Language,
)


class GameSettings(BaseModel):
    """Options communes à tous les modes."""

    language: Language
    difficulty: Difficulty = Difficulty.NORMAL
    categories: list[Category] = Field(default_factory=lambda: list(CLASSIC_CATEGORIES), min_length=1)
    rounds: int = 5
    round_duration: int = 30
    # True : la réponse doit coller à la fiche (casse, accents, espaces).
    strict_spelling: bool = False

    @field_validator("categories")
    @classmethod
    def unique_categories(cls, value: list[Category]) -> list[Category]:
        return list(dict.fromkeys(value))

    @field_validator("rounds")
    @classmethod
    def allowed_rounds(cls, value: int) -> int:
        if value not in ROUND_OPTIONS:
            raise ValueError(f"rounds must be one of {ROUND_OPTIONS}")
        return value

    @field_validator("round_duration")
    @classmethod
    def allowed_duration(cls, value: int) -> int:
        if value not in DURATION_OPTIONS:
            raise ValueError(f"round_duration must be one of {DURATION_OPTIONS}")
        return value

    @model_validator(mode="after")
    def long_enough_for_rules(self) -> "GameSettings":
        """Beaucoup de catégories ou orthographe stricte demandent plus de temps."""
        if len(self.categories) >= MANY_CATEGORIES and self.round_duration < MANY_CATEGORIES_MIN_DURATION:
            raise ValueError(
                f"{MANY_CATEGORIES} categories or more need rounds of at least {MANY_CATEGORIES_MIN_DURATION} s"
            )
        if self.strict_spelling and self.round_duration < STRICT_SPELLING_MIN_DURATION:
            raise ValueError(
                f"strict spelling needs rounds of at least 2 minutes "
                f"({STRICT_SPELLING_MIN_DURATION} s)"
            )
        return self


class SoloGameCreate(GameSettings):
    nickname: str = Field(default="Player", min_length=1, max_length=32)
    # Identifiant de l'appli : les points de la partie vont dans son porte-monnaie.
    client_id: str | None = Field(default=None, pattern=r"^[A-Za-z0-9-]{8,64}$")
    # Lettres de la dernière partie de ce niveau : une revanche les évite.
    avoid_letters: str = ""
    # Mots déjà validés dans le même monde de carrière (catégorie → valeurs).
    banned_answers: dict[Category, list[str]] = Field(default_factory=dict)

    @field_validator("avoid_letters")
    @classmethod
    def uppercase_letters(cls, value: str) -> str:
        seen: set[str] = set()
        letters = []
        for char in value.upper():
            if "A" <= char <= "Z" and char not in seen:
                seen.add(char)
                letters.append(char)
        return "".join(letters)[:26]

    @field_validator("banned_answers")
    @classmethod
    def clean_banned_answers(
        cls, value: dict[Category, list[str]]
    ) -> dict[Category, list[str]]:
        cleaned: dict[Category, list[str]] = {}
        for category, words in value.items():
            seen: set[str] = set()
            unique: list[str] = []
            for raw in words:
                word = raw.strip()[:100]
                if not word:
                    continue
                key = word.casefold()
                if key in seen:
                    continue
                seen.add(key)
                unique.append(word)
                if len(unique) >= 500:
                    break
            if unique:
                cleaned[category] = unique
        return cleaned


class SubmitAnswers(BaseModel):
    answers: dict[Category, str] = Field(default_factory=dict)

    @field_validator("answers")
    @classmethod
    def limit_length(cls, value: dict[Category, str]) -> dict[Category, str]:
        return {category: text[:100] for category, text in value.items()}


class RoundOut(BaseModel):
    number: int
    letter: str
    duration: int
    started_at: datetime
    ends_at: datetime
    # Permet au client de calculer son décalage d'horloge ; l'horloge du serveur fait référence.
    server_time: datetime


class AnswerResultOut(BaseModel):
    category: Category
    value: str
    status: str
    points: int
    matched_value: str | None
    hinted: bool = False
    # Réponse valide proposée quand celle du joueur ne l'était pas.
    suggestion: str | None = None
    # True s'il existe une fiche info achetable pour ce mot.
    info_available: bool = False
    # Prix en pièces (1 si réponse juste, 2 sinon) ; 0 si déjà débloqué / pas d'info.
    info_price: int = 0
    # Déjà débloqué pour ce joueur : les lignes peuvent être renvoyées tout de suite.
    info_unlocked: bool = False
    info_lines: list[str] | None = None


class RoundResultOut(BaseModel):
    number: int
    letter: str
    answers: list[AnswerResultOut]
    round_score: int
    elapsed_ms: int


class GameOut(BaseModel):
    id: str
    mode: str
    language: Language
    difficulty: Difficulty
    categories: list[Category]
    total_rounds: int
    round_duration: int
    strict_spelling: bool = False
    status: str
    nickname: str
    total_score: int
    rounds_played: int
    hints_left: int


class WalletOut(BaseModel):
    coins: int
    coins_gained: int
    points_to_next_coin: int
    level: int
    level_xp: int
    level_xp_needed: int


class SubmitResultOut(BaseModel):
    round: RoundResultOut
    game: GameOut
    # Présent quand la partie est liée à un profil.
    wallet: WalletOut | None = None


class LookOut(BaseModel):
    owned: list[str]
    hair: str = ""
    hat: str = ""
    frame: str
    name: str
    tiles: str
    victory: str


class ProfileOut(BaseModel):
    client_id: str
    nickname: str
    coins: int
    total_points: int
    points_to_next_coin: int
    level: int
    avatar_preset: int
    avatar_url: str | None
    look: LookOut


class CosmeticIn(BaseModel):
    item_id: str = Field(max_length=32)


class UnequipIn(BaseModel):
    kind: str = Field(max_length=16)


class CosmeticResult(WalletOut):
    look: LookOut


class ProfileUpdate(BaseModel):
    nickname: str | None = Field(default=None, min_length=1, max_length=32)
    avatar_preset: int | None = Field(default=None, ge=0, le=63)


class GameSummaryOut(GameOut):
    rounds: list[RoundResultOut]


class HintRequestIn(BaseModel):
    category: Category
    # True = joker payant : révèle directement le mot exact (pas de QCM).
    reveal: bool = False


class HintPickIn(BaseModel):
    category: Category
    choice: str = Field(max_length=200)


class HintOut(BaseModel):
    category: Category
    options: list[str]
    hints_left: int
    # Renseigné quand reveal=True : le mot est déjà choisi et correct.
    revealed: bool = False
    answer: str | None = None


class HintPickOut(BaseModel):
    category: Category
    correct: bool
    answer: str


class BuyHintOut(BaseModel):
    hints_left: int
    price: int
    wallet: WalletOut


class CategoryInfoIn(BaseModel):
    category: Category


class CategoryInfoOut(BaseModel):
    category: Category
    word: str
    lines: list[str]
    price: int
    wallet: WalletOut


class GameConfigOut(BaseModel):
    languages: list[Language]
    categories: list[Category]
    difficulties: list[Difficulty]
    round_options: list[int]
    duration_options: list[int]
    category_info_price_found: int
    category_info_price_missed: int
    extra_hint_price: int
