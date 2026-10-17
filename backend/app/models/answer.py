from sqlalchemy import BigInteger, Boolean, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Answer(Base):
    """Entrée de la base de réponses : une réponse acceptée pour une catégorie."""

    __tablename__ = "answers"
    __table_args__ = (
        Index("ix_answers_lookup", "category", "language", "normalized_value", unique=True),
        Index("ix_answers_letter", "language", "category", "first_letter"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    category: Mapped[str] = mapped_column(String(32))
    # Langue de partie dans laquelle l'entrée est valable, ou « * » pour toutes.
    language: Mapped[str] = mapped_column(String(8))
    value: Mapped[str] = mapped_column(String(200))
    normalized_value: Mapped[str] = mapped_column(String(200))
    first_letter: Mapped[str] = mapped_column(String(1))
    accepted: Mapped[bool] = mapped_column(Boolean, default=True)
    # Notoriété de la réponse (population pour les villes) ; les bots préfèrent les valeurs élevées.
    popularity: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
