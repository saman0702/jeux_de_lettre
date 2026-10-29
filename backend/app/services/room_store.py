"""Mémoire durable des salons : un salon créé par un joueur (pas une partie rapide) garde ses
membres, ses parties et ses conversations quand tout le monde part. On le rouvre avec son code.

Visibilité : un salon public est visible par tous ; un salon privé seulement par ceux qui y sont
déjà entrés (on peut toujours y inviter quelqu'un avec le code). Après 30 jours sans activité, le
salon et son historique sont supprimés.
"""

import re
from datetime import datetime, timedelta

from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import RoomGame, RoomMember, RoomMessage, SavedRoom
from app.models.base import utcnow

RETENTION_DAYS = 30
# Messages de groupe rechargés à la réouverture et renvoyés par l'historique.
GROUP_HISTORY = 200
PRIVATE_HISTORY = 200
MENTION = re.compile(r"@([^\s@]{1,32})")


async def save_room(
    session: AsyncSession, code: str, creator_id: str, creator_nickname: str, public: bool, language: str, settings: dict
) -> SavedRoom:
    room = SavedRoom(
        code=code,
        creator_id=creator_id,
        creator_nickname=creator_nickname,
        public=public,
        language=language,
        settings=settings,
    )
    session.add(room)
    return room


async def code_taken(session: AsyncSession, code: str) -> bool:
    return await session.get(SavedRoom, code) is not None


async def get_room(session: AsyncSession, code: str) -> SavedRoom | None:
    return await session.get(SavedRoom, code)


async def save_bots(session: AsyncSession, code: str, bots: list[dict]) -> None:
    """Bots présents à la fermeture : ils reviennent quand le salon se rouvre."""
    room = await session.get(SavedRoom, code)
    if room is not None:
        room.settings = {**(room.settings or {}), "bots": bots}


async def touch(session: AsyncSession, code: str) -> None:
    room = await session.get(SavedRoom, code)
    if room is not None:
        room.last_activity_at = utcnow()


async def join(session: AsyncSession, code: str, client_id: str, nickname: str) -> RoomMember | None:
    """Enregistre le passage du joueur ; renvoie son adhésion (None si le salon n'est pas gardé)."""
    room = await session.get(SavedRoom, code)
    if room is None:
        return None
    member = await session.get(RoomMember, (code, client_id))
    if member is None:
        member = RoomMember(room_code=code, client_id=client_id, nickname=nickname)
        session.add(member)
    member.nickname = nickname
    member.last_seen_at = utcnow()
    room.last_activity_at = utcnow()
    return member


async def is_member(session: AsyncSession, code: str, client_id: str) -> bool:
    return await session.get(RoomMember, (code, client_id)) is not None


async def unlock_private(session: AsyncSession, code: str, client_id: str) -> None:
    member = await session.get(RoomMember, (code, client_id))
    if member is not None:
        member.private_unlocked = True


async def mentions_in(session: AsyncSession, code: str, text: str) -> list[str]:
    """Membres tagués « @pseudo » dans un message (pseudo sans espace, insensible à la casse)."""
    tags = {t.lower() for t in MENTION.findall(text)}
    if not tags:
        return []
    members = (await session.scalars(select(RoomMember).where(RoomMember.room_code == code))).all()
    return [m.client_id for m in members if m.nickname.replace(" ", "").lower() in tags]


async def add_message(
    session: AsyncSession,
    code: str,
    sender_id: str,
    sender_nickname: str,
    text: str,
    recipient_id: str | None = None,
    mentions: list[str] | None = None,
) -> RoomMessage:
    message = RoomMessage(
        room_code=code,
        sender_id=sender_id,
        sender_nickname=sender_nickname,
        recipient_id=recipient_id,
        text=text,
        mentions=mentions or [],
        created_at=utcnow(),
    )
    session.add(message)
    await touch(session, code)
    return message


def message_dict(m: RoomMessage) -> dict:
    return {
        "id": m.id,
        "client_id": m.sender_id,
        "nickname": m.sender_nickname,
        "to": m.recipient_id,
        "text": m.text,
        "mentions": list(m.mentions or []),
        "at": m.created_at.isoformat(),
    }


async def group_messages(session: AsyncSession, code: str, limit: int = GROUP_HISTORY) -> list[RoomMessage]:
    rows = await session.scalars(
        select(RoomMessage)
        .where(RoomMessage.room_code == code, RoomMessage.recipient_id.is_(None))
        .order_by(RoomMessage.created_at.desc(), RoomMessage.id.desc())
        .limit(limit)
    )
    return list(reversed(rows.all()))


async def private_messages(
    session: AsyncSession, code: str, client_id: str, limit: int = PRIVATE_HISTORY
) -> list[RoomMessage]:
    """Conversations privées du joueur dans ce salon (envoyées ou reçues)."""
    rows = await session.scalars(
        select(RoomMessage)
        .where(
            RoomMessage.room_code == code,
            RoomMessage.recipient_id.is_not(None),
            or_(RoomMessage.sender_id == client_id, RoomMessage.recipient_id == client_id),
        )
        .order_by(RoomMessage.created_at.desc(), RoomMessage.id.desc())
        .limit(limit)
    )
    return list(reversed(rows.all()))


async def record_game(
    session: AsyncSession, code: str, game_id: str | None, format: str, rounds: int, ranking: list[dict]
) -> None:
    session.add(RoomGame(room_code=code, game_id=game_id, format=format, rounds=rounds, ranking=ranking))
    await touch(session, code)


async def games(session: AsyncSession, code: str, limit: int = 50) -> list[RoomGame]:
    rows = await session.scalars(
        select(RoomGame).where(RoomGame.room_code == code).order_by(RoomGame.finished_at.desc()).limit(limit)
    )
    return list(rows.all())


async def rooms_of(session: AsyncSession, client_id: str, limit: int = 50) -> list[tuple[SavedRoom, RoomMember]]:
    rows = await session.execute(
        select(SavedRoom, RoomMember)
        .join(RoomMember, RoomMember.room_code == SavedRoom.code)
        .where(RoomMember.client_id == client_id)
        .order_by(SavedRoom.last_activity_at.desc())
        .limit(limit)
    )
    return [(room, member) for room, member in rows.all()]


async def public_rooms(session: AsyncSession, language: str | None, limit: int = 50) -> list[SavedRoom]:
    query = select(SavedRoom).where(SavedRoom.public.is_(True))
    if language:
        query = query.where(SavedRoom.language == language)
    rows = await session.scalars(query.order_by(SavedRoom.last_activity_at.desc()).limit(limit))
    return list(rows.all())


async def member_counts(session: AsyncSession, codes: list[str]) -> dict[str, int]:
    if not codes:
        return {}
    rows = await session.execute(select(RoomMember.room_code).where(RoomMember.room_code.in_(codes)))
    counts: dict[str, int] = {}
    for (code,) in rows.all():
        counts[code] = counts.get(code, 0) + 1
    return counts


async def delete_room(session: AsyncSession, code: str) -> None:
    """Supprime le salon avec ses membres, ses parties et ses conversations (cascade)."""
    await session.execute(delete(SavedRoom).where(SavedRoom.code == code))


async def purge_inactive(session: AsyncSession, keep: set[str], now: datetime | None = None) -> int:
    """Supprime les salons sans activité depuis 30 jours (sauf ceux ouverts en ce moment)."""
    limit = (now or utcnow()) - timedelta(days=RETENTION_DAYS)
    query = delete(SavedRoom).where(SavedRoom.last_activity_at < limit)
    if keep:
        query = query.where(SavedRoom.code.not_in(keep))
    result = await session.execute(query)
    return result.rowcount or 0
