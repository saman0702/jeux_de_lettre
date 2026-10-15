from sqlalchemy import BigInteger, Boolean, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Answer(Base):
    """Knowledge-base entry: one accepted answer for a category."""

    __tablename__ = "answers"
    __table_args__ = (
        Index("ix_answers_lookup", "category", "language", "normalized_value", unique=True),
        Index("ix_answers_letter", "language", "category", "first_letter"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    category: Mapped[str] = mapped_column(String(32))
    # Game language the entry is valid in, or "*" for every language.
    language: Mapped[str] = mapped_column(String(8))
    value: Mapped[str] = mapped_column(String(200))
    normalized_value: Mapped[str] = mapped_column(String(200))
    first_letter: Mapped[str] = mapped_column(String(1))
    accepted: Mapped[bool] = mapped_column(Boolean, default=True)
    # How well known the answer is (population for cities); bots prefer high values.
    popularity: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
