"""Authentification des joueurs invités.

Le `client_id` est public : il apparaît dans l'état des salons envoyé à tous les joueurs. L'appli
garde en plus un jeton secret, créé au premier lancement et jamais montré aux autres ; le serveur
n'en garde que l'empreinte. Le premier jeton présenté pour un profil lui est associé, ensuite seul
ce jeton est accepté (connexion temps réel, portefeuille, achats, profil, historique privé).
"""

import hashlib
import hmac

from fastapi import Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models import Profile
from app.services import wallet_service

TOKEN_HEADER = "X-Client-Token"
MIN_TOKEN_LENGTH = 16
MAX_TOKEN_LENGTH = 128


class AuthError(Exception):
    def __init__(self, code: str, status_code: int = 401):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


async def authenticate(
    session: AsyncSession, client_id: str, token: str | None, nickname: str | None = None
) -> Profile:
    """Profil du joueur si le jeton est le bon ; le premier jeton présenté est enregistré."""
    if not wallet_service.is_client_id(client_id):
        raise AuthError("invalid_client_id", 422)
    if not token or not MIN_TOKEN_LENGTH <= len(token) <= MAX_TOKEN_LENGTH:
        raise AuthError("missing_token")
    try:
        profile = await wallet_service.get_profile(session, client_id, nickname)
    except wallet_service.WalletError as error:
        raise AuthError(error.code, 422) from None
    digest = hash_token(token)
    if profile.secret_hash is None:
        profile.secret_hash = digest
        await session.flush()
    elif not hmac.compare_digest(profile.secret_hash, digest):
        raise AuthError("invalid_token")
    return profile


async def check(session: AsyncSession, client_id: str, token: str | None) -> Profile:
    """Comme `authenticate`, en erreur HTTP pour les routes de l'API."""
    try:
        profile = await authenticate(session, client_id, token)
    except AuthError as error:
        raise HTTPException(status_code=error.status_code, detail=error.code) from None
    await session.commit()
    return profile


async def verified_client(
    client_id: str,
    x_client_token: str | None = Header(default=None),
    session: AsyncSession = Depends(get_session),
) -> str:
    """Dépendance des routes qui agissent pour un joueur (`client_id` dans le chemin ou la requête)."""
    await check(session, client_id, x_client_token)
    return client_id
