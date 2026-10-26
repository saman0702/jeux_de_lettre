from datetime import date, datetime

from sqlalchemy import JSON, Boolean, Date, DateTime, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, new_id, utcnow


class IqSession(Base):
    """Partie de QI jouée contre le serveur (solo en ligne ou défi du jour) : les énigmes et leurs
    réponses restent ici, le temps est mesuré par le serveur, les points rapportent des pièces."""

    __tablename__ = "iq_sessions"
    # Défi du jour : une seule tentative par joueur et par jour (solo : day est vide).
    __table_args__ = (UniqueConstraint("client_id", "day", name="uq_iq_daily_attempt"),)

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    client_id: Mapped[str] = mapped_column(String(64), index=True)
    nickname: Mapped[str] = mapped_column(String(32), default="Joueur")
    mode: Mapped[str] = mapped_column(String(8), default="solo")  # solo | daily
    day: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    duration: Mapped[int] = mapped_column(Integer, default=30)
    speed_bonus: Mapped[bool] = mapped_column(Boolean, default=True)
    penalty: Mapped[bool] = mapped_column(Boolean, default=False)
    # Énigmes complètes (avec réponses) ; jamais envoyées telles quelles à l'appli.
    puzzles: Mapped[list] = mapped_column(JSON, default=list)
    # Énigme en cours (1 = la première) ; servie à served_at.
    number: Mapped[int] = mapped_column(Integer, default=0)
    served_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    answered: Mapped[bool] = mapped_column(Boolean, default=False)
    extra_seconds: Mapped[int] = mapped_column(Integer, default=0)
    # Jokers déjà pris sur l'énigme en cours.
    jokers: Mapped[list] = mapped_column(JSON, default=list)
    score: Mapped[int] = mapped_column(Integer, default=0)
    correct: Mapped[int] = mapped_column(Integer, default=0)
    # [niveau, juste] de chaque énigme, pour le QI estimé.
    results: Mapped[list] = mapped_column(JSON, default=list)
    elapsed_ms: Mapped[int] = mapped_column(Integer, default=0)
    finished: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class IqDailyPayout(Base):
    """Jour du défi dont le podium a été récompensé (une seule fois)."""

    __tablename__ = "iq_daily_payouts"

    day: Mapped[date] = mapped_column(Date, primary_key=True)
    paid_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
