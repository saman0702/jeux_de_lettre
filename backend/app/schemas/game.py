from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.core.game_rules import DURATION_OPTIONS, ROUND_OPTIONS, Category, Difficulty, Language


class GameSettings(BaseModel):
    """Options shared by every mode."""

    language: Language
    difficulty: Difficulty = Difficulty.NORMAL
    categories: list[Category] = Field(default_factory=lambda: list(Category), min_length=1)
    rounds: int = 5
    round_duration: int = 30

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


class SoloGameCreate(GameSettings):
    nickname: str = Field(default="Player", min_length=1, max_length=32)


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
    # Lets the client compute its clock offset; the server clock is the reference.
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
    status: str
    nickname: str
    total_score: int
    rounds_played: int
    hints_left: int


class SubmitResultOut(BaseModel):
    round: RoundResultOut
    game: GameOut


class GameSummaryOut(GameOut):
    rounds: list[RoundResultOut]


class HintRequestIn(BaseModel):
    category: Category


class HintPickIn(BaseModel):
    category: Category
    choice: str = Field(max_length=200)


class HintOut(BaseModel):
    category: Category
    options: list[str]
    hints_left: int


class HintPickOut(BaseModel):
    category: Category
    correct: bool
    answer: str


class GameConfigOut(BaseModel):
    languages: list[Language]
    categories: list[Category]
    difficulties: list[Difficulty]
    round_options: list[int]
    duration_options: list[int]
