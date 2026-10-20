from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, utcnow


class SavedRoom(Base):
    """Salon créé par un joueur (pas les parties rapides) : il survit quand tout le monde part,
    avec ses parties et ses conversations, jusqu'à 30 jours sans activité."""

    __tablename__ = "saved_rooms"

    code: Mapped[str] = mapped_column(String(8), primary_key=True)
    creator_id: Mapped[str] = mapped_column(String(64), index=True)
    creator_nickname: Mapped[str] = mapped_column(String(32), default="")
    public: Mapped[bool] = mapped_column(Boolean, default=False)
    language: Mapped[str] = mapped_column(String(8), default="fr")
    # Réglages du salon (RoomSettings), pour le rouvrir à l'identique.
    settings: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_activity_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)


class RoomMember(Base):
    """Joueur passé par un salon : il le retrouve dans « Mes salons »."""

    __tablename__ = "room_members"

    room_code: Mapped[str] = mapped_column(
        ForeignKey("saved_rooms.code", ondelete="CASCADE"), primary_key=True
    )
    client_id: Mapped[str] = mapped_column(String(64), primary_key=True, index=True)
    nickname: Mapped[str] = mapped_column(String(32), default="")
    # Messages privés débloqués (en pièces) dans ce salon.
    private_unlocked: Mapped[bool] = mapped_column(Boolean, default=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class RoomMessage(Base):
    """Message du salon : de groupe (recipient_id vide) ou privé entre deux membres."""

    __tablename__ = "room_messages"
    __table_args__ = (Index("ix_room_messages_room_time", "room_code", "created_at"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    room_code: Mapped[str] = mapped_column(ForeignKey("saved_rooms.code", ondelete="CASCADE"))
    sender_id: Mapped[str] = mapped_column(String(64))
    sender_nickname: Mapped[str] = mapped_column(String(32))
    recipient_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    text: Mapped[str] = mapped_column(Text)
    # Joueurs tagués (@pseudo) dans un message de groupe.
    mentions: Mapped[list] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class RoomGame(Base):
    """Résumé d'une partie jouée dans un salon (classement final)."""

    __tablename__ = "room_games"

    id: Mapped[int] = mapped_column(primary_key=True)
    room_code: Mapped[str] = mapped_column(ForeignKey("saved_rooms.code", ondelete="CASCADE"), index=True)
    game_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    format: Mapped[str] = mapped_column(String(16), default="rounds")
    rounds: Mapped[int] = mapped_column(Integer, default=0)
    # [{client_id, nickname, score, bot}] du premier au dernier.
    ranking: Mapped[list] = mapped_column(JSON, default=list)
    finished_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
