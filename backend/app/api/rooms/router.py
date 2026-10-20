from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models import SavedRoom
from app.services import room_store

router = APIRouter(prefix="/api/v1/rooms", tags=["rooms"])

CLIENT_ID = r"^[A-Za-z0-9-]{8,64}$"


def _summary(request: Request, room: SavedRoom, members: int, mine: bool) -> dict:
    live = request.app.state.room_manager.rooms.get(room.code)
    return {
        "code": room.code,
        "public": room.public,
        "creator": room.creator_nickname,
        "language": room.language,
        "format": room.settings.get("format", "rounds"),
        "kind": room.settings.get("kind", "classic"),
        "members": members,
        "mine": mine,
        # Ouvert en ce moment (joueurs dedans) ou fermé, en attente d'être rouvert.
        "open": live is not None,
        "players_now": len(live.players) if live is not None else 0,
        "last_activity_at": room.last_activity_at.isoformat(),
    }


@router.get("/mine")
async def my_rooms(
    request: Request,
    client_id: str = Query(pattern=CLIENT_ID),
    session: AsyncSession = Depends(get_session),
):
    """Salons où le joueur est déjà allé (publics et privés), du plus récent au plus ancien."""
    rows = await room_store.rooms_of(session, client_id)
    counts = await room_store.member_counts(session, [r.code for r, _ in rows])
    return [_summary(request, room, counts.get(room.code, 0), True) for room, _ in rows]


@router.get("/public")
async def public_rooms(
    request: Request,
    language: str | None = Query(default=None, max_length=8),
    client_id: str | None = Query(default=None, pattern=CLIENT_ID),
    session: AsyncSession = Depends(get_session),
):
    """Salons publics, ouverts ou fermés : visibles par tous, même sans y être allé."""
    rooms = await room_store.public_rooms(session, language)
    counts = await room_store.member_counts(session, [r.code for r in rooms])
    mine = set()
    if client_id:
        mine = {r.code for r, _ in await room_store.rooms_of(session, client_id, limit=200)}
    return [_summary(request, room, counts.get(room.code, 0), room.code in mine) for room in rooms]


@router.get("/{code}/history")
async def room_history(
    code: str,
    request: Request,
    client_id: str = Query(pattern=CLIENT_ID),
    session: AsyncSession = Depends(get_session),
):
    """Parties jouées, conversation de groupe et conversations privées du joueur dans ce salon.

    Salon privé : seulement pour ceux qui y sont déjà entrés. Salon public : pour tous (les
    conversations privées restent visibles uniquement par les deux personnes)."""
    code = code.strip().upper()
    room = await room_store.get_room(session, code)
    member = room is not None and await room_store.is_member(session, code, client_id)
    if room is None or (not room.public and not member):
        raise HTTPException(status_code=404, detail="room_not_found")
    games = await room_store.games(session, code)
    group = await room_store.group_messages(session, code)
    private = await room_store.private_messages(session, code, client_id) if member else []
    counts = await room_store.member_counts(session, [code])
    return {
        "room": _summary(request, room, counts.get(code, 0), member),
        "games": [
            {
                "finished_at": g.finished_at.isoformat(),
                "format": g.format,
                "rounds": g.rounds,
                "ranking": g.ranking,
            }
            for g in games
        ],
        "group": [room_store.message_dict(m) for m in group],
        "private": [room_store.message_dict(m) for m in private],
    }
