import json
import re

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.core import client_auth
from app.core.rate_limit import MessageBucket
from app.services.room_service import room_manager

router = APIRouter()

_CLIENT_ID = re.compile(r"^[A-Za-z0-9-]{8,64}$")


def clean_country(raw: str) -> str | None:
    """Pays choisi dans l'appli (nom anglais, ex. « Ivory Coast ») ; vide = pas de drapeau."""
    country = " ".join(raw.split())[:48]
    return country or None


def clean_nickname(raw: str) -> str:
    nickname = " ".join(raw.split())[:20]
    return nickname or "Joueur"


@router.websocket("/ws")
async def game_socket(
    websocket: WebSocket,
    client_id: str = Query(...),
    nickname: str = Query("Joueur"),
    language: str = Query("fr"),
    country: str = Query(""),
    token: str = Query(""),
):
    """Une connexion persistante par appli : présence, salle d'attente et parties en direct.

    `client_id` est un identifiant aléatoire que l'appli génère une fois et conserve : un joueur qui
    perd la connexion retrouve sa place en se reconnectant. Il est public (les autres joueurs le
    voient) : `token`, le jeton secret de l'appli, prouve que c'est bien ce joueur.
    """
    if not _CLIENT_ID.match(client_id):
        await websocket.close(code=4400, reason="invalid client_id")
        return

    manager = websocket.app.state.room_manager
    try:
        async with manager.session_factory() as session:
            await client_auth.authenticate(session, client_id, token)
            await session.commit()
    except client_auth.AuthError as error:
        await websocket.close(code=4401, reason=error.code)
        return

    await websocket.accept()
    connection = await manager.connect(
        websocket,
        client_id,
        clean_nickname(nickname),
        # Langue de l'appli (réponses validées dans celle-ci) et pays d'origine (drapeau).
        language=language if language in {"fr", "en"} else "fr",
        country=clean_country(country),
    )
    bucket = MessageBucket()
    try:
        while True:
            text = await websocket.receive_text()
            # Trop de messages d'un coup : les suivants sont ignorés le temps que le seau se remplisse.
            if not bucket.take():
                continue
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
