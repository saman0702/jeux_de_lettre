"""Suppression d'un compte joueur (Réglages > Supprimer mon compte, ou demande par e-mail).

Efface le profil et tout ce qui lui appartient : pièces et historique, avatar (fichier compris),
parties de QI, salons créés, appartenance aux salons, messages envoyés ou reçus en privé,
signalements. Les classements des parties terminées gardent la place, sous un nom anonyme.
Les achats déjà vérifiés sont gardés, rattachés à un profil anonyme : un même reçu du store ne
peut ainsi pas être crédité une deuxième fois sur un nouveau compte.
"""

from sqlalchemy import delete, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AvatarReport,
    CoinPurchase,
    Game,
    IqSession,
    Profile,
    RoomGame,
    RoomMember,
    RoomMessage,
    SavedRoom,
)
from app.services import avatar_service

# Profil technique qui garde les achats des comptes supprimés.
DELETED_ACCOUNTS = "deleted-accounts"
ANONYMOUS_NAME = "Joueur supprimé"


async def delete_account(session: AsyncSession, client_id: str) -> bool:
    """Supprime le compte ; faux s'il n'existait pas."""
    profile = await session.get(Profile, client_id)
    if profile is None:
        return False
    avatar_file = profile.avatar_file

    # Achats : gardés (anti double crédit), rattachés au profil anonyme.
    if await session.scalar(select(CoinPurchase.id).where(CoinPurchase.client_id == client_id).limit(1)):
        if await session.get(Profile, DELETED_ACCOUNTS) is None:
            session.add(Profile(client_id=DELETED_ACCOUNTS, nickname=ANONYMOUS_NAME, coins=0, total_points=0, points_balance=0))
            await session.flush()
        await session.execute(
            update(CoinPurchase).where(CoinPurchase.client_id == client_id).values(client_id=DELETED_ACCOUNTS)
        )

    # Classements des salons où il a joué : la place reste, le nom part.
    codes = (await session.scalars(select(RoomMember.room_code).where(RoomMember.client_id == client_id))).all()
    if codes:
        for game in (await session.scalars(select(RoomGame).where(RoomGame.room_code.in_(codes)))).all():
            ranking = [
                {**row, "client_id": "", "nickname": ANONYMOUS_NAME} if row.get("client_id") == client_id else row
                for row in (game.ranking or [])
            ]
            if ranking != game.ranking:
                game.ranking = ranking

    await session.execute(delete(SavedRoom).where(SavedRoom.creator_id == client_id))
    await session.execute(delete(RoomMember).where(RoomMember.client_id == client_id))
    await session.execute(
        delete(RoomMessage).where(or_(RoomMessage.sender_id == client_id, RoomMessage.recipient_id == client_id))
    )
    await session.execute(
        delete(AvatarReport).where(or_(AvatarReport.reporter_id == client_id, AvatarReport.reported_id == client_id))
    )
    await session.execute(delete(IqSession).where(IqSession.client_id == client_id))
    await session.execute(update(Game).where(Game.owner_client_id == client_id).values(owner_client_id=None))
    # Le profil emporte ses mouvements de pièces (suppression en cascade).
    await session.delete(profile)
    await session.flush()
    if avatar_file:
        avatar_service.delete_avatar(avatar_file)
    return True
