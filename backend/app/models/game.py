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
    round_duration: Mapped[int] = mapped_column(Integer)  # seconds
    status: Mapped[str] = mapped_column(String(16), default="waiting")  # waiting | playing | finished

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
    """One player's answers for one round."""

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


class PlayerAnswer(Base):
    __tablename__ = "player_answers"

    id: Mapped[int] = mapped_column(primary_key=True)
    submission_id: Mapped[int] = mapped_column(
        ForeignKey("submissions.id", ondelete="CASCADE"), index=True
    )
    category: Mapped[str] = mapped_column(String(32))
    raw_value: Mapped[str] = mapped_column(String(200))
    # Knowledge-base value the answer matched, when valid.
    matched_value: Mapped[str | None] = mapped_column(String(200), nullable=True)
    status: Mapped[str] = mapped_column(String(16))  # valid | empty | wrong_letter | not_found | late
    points: Mapped[int] = mapped_column(Integer, default=0)

    submission: Mapped[Submission] = relationship(back_populates="answers")
