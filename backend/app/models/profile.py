from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, utcnow


class Profile(TimestampMixin, Base):
    """Profil d'un joueur invité, retrouvé grâce à l'identifiant gardé par l'appli."""

    __tablename__ = "profiles"

    client_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    nickname: Mapped[str] = mapped_column(String(32), default="Joueur")
    coins: Mapped[int] = mapped_column(Integer, default=0)
    # Points gagnés depuis toujours (statistique).
    total_points: Mapped[int] = mapped_column(Integer, default=0)
    # Points pas encore convertis en pièce (toujours < POINTS_PER_COIN).
    points_balance: Mapped[int] = mapped_column(Integer, default=0)
    # Avatar : un avatar dessiné (avatar_preset) ou une photo transformée (avatar_file).
    avatar_preset: Mapped[int] = mapped_column(Integer, default=0)
    avatar_file: Mapped[str | None] = mapped_column(String(64), nullable=True)
    # Apparences achetées (identifiants séparés par des virgules) et celle
    # équipée pour chaque emplacement.
    cosmetics_owned: Mapped[str] = mapped_column(String(512), default="", server_default="")
    cosmetic_hair: Mapped[str] = mapped_column(String(32), default="", server_default="")
    cosmetic_hat: Mapped[str] = mapped_column(String(32), default="", server_default="")
    cosmetic_frame: Mapped[str] = mapped_column(String(32), default="", server_default="")
    cosmetic_name: Mapped[str] = mapped_column(String(32), default="", server_default="")
    cosmetic_tiles: Mapped[str] = mapped_column(String(32), default="", server_default="")
    cosmetic_victory: Mapped[str] = mapped_column(String(32), default="", server_default="")
    # Infos catégories débloquées une fois pour toutes (`country:france,city:paris`…).
    facts_unlocked: Mapped[str] = mapped_column(String(8192), default="", server_default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)


class CoinTransaction(TimestampMixin, Base):
    """Journal des mouvements de pièces : conversions de points, mises, gains.

    Sert d'historique et prépare un éventuel achat de pièces plus tard."""

    __tablename__ = "coin_transactions"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[str] = mapped_column(ForeignKey("profiles.client_id", ondelete="CASCADE"), index=True)
    # Positif pour un gain, négatif pour une dépense.
    amount: Mapped[int] = mapped_column(Integer)
    # points | bet_stake | bet_win | bet_refund | purchase | cosmetic |
    # category_info | extra_hint
    reason: Mapped[str] = mapped_column(String(32))
    reference: Mapped[str | None] = mapped_column(String(64), nullable=True)


class AvatarReport(TimestampMixin, Base):
    """Signalement d'une photo d'avatar ; plusieurs signalements la retirent."""

    __tablename__ = "avatar_reports"
    __table_args__ = (UniqueConstraint("reporter_id", "avatar_file"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    reporter_id: Mapped[str] = mapped_column(String(64))
    reported_id: Mapped[str] = mapped_column(ForeignKey("profiles.client_id"), index=True)
    avatar_file: Mapped[str] = mapped_column(String(64))


class CoinPurchase(TimestampMixin, Base):
    """Achat de pièces vérifié auprès d'un store. Le jeton unique empêche de créditer deux fois."""

    __tablename__ = "coin_purchases"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[str] = mapped_column(ForeignKey("profiles.client_id"), index=True)
    platform: Mapped[str] = mapped_column(String(16))  # android | ios
    product_id: Mapped[str] = mapped_column(String(64))
    # Jeton d'achat Google ou identifiant de transaction Apple.
    store_token: Mapped[str] = mapped_column(String(512), unique=True)
    order_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    coins: Mapped[int] = mapped_column(Integer)
