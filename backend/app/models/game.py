from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, new_id


class Game(TimestampMixin, Base):
    __tablename__ = "games"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    mode: Mapped[str] = mapped_column(String(16))  # solo | duel | multiplayer
    language: Mapped[str] = mapped_column(String(8))
    difficulty: Mapped[str] = mapped_column(String(16))
    categories: Mapped[list[str]] = mapped_column(JSON)
    total_rounds: Mapped[int] = mapped_column(Integer)
    round_duration: Mapped[int] = mapped_column(Integer)  # secondes
    # Orthographe stricte : casse, accents et espaces doivent coller à la fiche.
    strict_spelling: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    status: Mapped[str] = mapped_column(String(16), default="waiting")  # waiting | playing | finished
    # Joueur à créditer en pièces pour une partie solo (absent pour un invité sans profil).
    owner_client_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    # Lettres à ne pas retirer (revanche d'un niveau de carrière).
    avoid_letters: Mapped[str] = mapped_column(String(26), default="")
    # Mots déjà validés dans le même monde de carrière : catégorie → valeurs.
    banned_answers: Mapped[dict] = mapped_column(JSON, default=dict, server_default="{}")
    # Jokers achetés en pièces, en plus du quota gratuit HINTS_PER_GAME.
    bonus_hints: Mapped[int] = mapped_column(Integer, default=0, server_default="0")

    players: Mapped[list["Player"]] = relationship(
        back_populates="game", order_by="Player.created_at", lazy="selectin"
    )
    rounds: Mapped[list["GameRound"]] = relationship(
        back_populates="game", order_by="GameRound.number", lazy="selectin"
    )

    @property
    def current_round(self) -> "GameRound | None":
        return self.rounds[-1] if self.rounds else None


class Player(TimestampMixin, Base):
    __tablename__ = "players"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    game_id: Mapped[str] = mapped_column(ForeignKey("games.id", ondelete="CASCADE"), index=True)
    nickname: Mapped[str] = mapped_column(String(32))
    total_score: Mapped[int] = mapped_column(Integer, default=0)

    game: Mapped[Game] = relationship(back_populates="players")


class GameRound(Base):
    __tablename__ = "game_rounds"
    __table_args__ = (UniqueConstraint("game_id", "number"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    game_id: Mapped[str] = mapped_column(ForeignKey("games.id", ondelete="CASCADE"), index=True)
    number: Mapped[int] = mapped_column(Integer)
    letter: Mapped[str] = mapped_column(String(1))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished: Mapped[bool] = mapped_column(Boolean, default=False)

    game: Mapped[Game] = relationship(back_populates="rounds")
    submissions: Mapped[list["Submission"]] = relationship(
        back_populates="round", lazy="selectin"
    )


class Submission(Base):
    """Les réponses d'un joueur pour une manche."""

    __tablename__ = "submissions"
    __table_args__ = (UniqueConstraint("round_id", "player_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    round_id: Mapped[int] = mapped_column(ForeignKey("game_rounds.id", ondelete="CASCADE"), index=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    score: Mapped[int] = mapped_column(Integer, default=0)

    round: Mapped[GameRound] = relationship(back_populates="submissions")
    answers: Mapped[list["PlayerAnswer"]] = relationship(
        back_populates="submission", lazy="selectin", cascade="all, delete-orphan"
    )


class HintRequest(Base):
    """Un joker montré à un joueur (les parties solo le conservent entre deux requêtes)."""

    __tablename__ = "hint_requests"
    __table_args__ = (UniqueConstraint("round_id", "player_id", "category"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    round_id: Mapped[int] = mapped_column(ForeignKey("game_rounds.id", ondelete="CASCADE"), index=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    category: Mapped[str] = mapped_column(String(32))
    options: Mapped[list[str]] = mapped_column(JSON)
    answer: Mapped[str] = mapped_column(String(200))
    picked: Mapped[str | None] = mapped_column(String(200), nullable=True)


class PlayerAnswer(Base):
    __tablename__ = "player_answers"

    id: Mapped[int] = mapped_column(primary_key=True)
    submission_id: Mapped[int] = mapped_column(
        ForeignKey("submissions.id", ondelete="CASCADE"), index=True
    )
    category: Mapped[str] = mapped_column(String(32))
    raw_value: Mapped[str] = mapped_column(String(200))
    # Valeur de la base qui correspond à la réponse, quand elle est valide.
    matched_value: Mapped[str | None] = mapped_column(String(200), nullable=True)
    status: Mapped[str] = mapped_column(String(16))  # valid | empty | wrong_letter | not_found | late | hint_wrong
    points: Mapped[int] = mapped_column(Integer, default=0)
    # Réponse obtenue en choisissant parmi les trois propositions du joker.
    hinted: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    # Réponse valide montrée au joueur quand la sienne ne l'était pas.
    suggestion: Mapped[str | None] = mapped_column(String(200), nullable=True)

    submission: Mapped[Submission] = relationship(back_populates="answers")
