import json
import re

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.services.room_service import room_manager

router = APIRouter()

_CLIENT_ID = re.compile(r"^[A-Za-z0-9-]{8,64}$")


def clean_nickname(raw: str) -> str:
    nickname = " ".join(raw.split())[:20]
    return nickname or "Joueur"


@router.websocket("/ws")
async def game_socket(
    websocket: WebSocket,
    client_id: str = Query(...),
    nickname: str = Query("Joueur"),
):
    """Une connexion persistante par appli : présence, salle d'attente et parties en direct.

    `client_id` est un identifiant aléatoire que l'appli génère une fois et conserve : un joueur qui
    perd la connexion retrouve sa place en se reconnectant.
    """
    if not _CLIENT_ID.match(client_id):
        await websocket.close(code=4400, reason="invalid client_id")
        return

    await websocket.accept()
    manager = websocket.app.state.room_manager
    connection = await manager.connect(websocket, client_id, clean_nickname(nickname))
    try:
        while True:
            text = await websocket.receive_text()
            try:
                message = json.loads(text)
            except json.JSONDecodeError:
                message = None
            await manager.handle(connection, message)
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(connection)


__all__ = ["router", "room_manager"]
