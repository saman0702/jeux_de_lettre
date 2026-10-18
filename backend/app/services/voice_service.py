"""Salon vocal (Agora) : tokens RTC pendant la partie et au podium."""

from __future__ import annotations

import logging
import time
import zlib

from agora_token_builder import RtcTokenBuilder

from app.core.config import settings

logger = logging.getLogger(__name__)

# Rôle éditeur : chacun peut parler (sauf mute forcé côté client).
ROLE_PUBLISHER = 1
TOKEN_TTL_SECONDS = 3600


def voice_enabled() -> bool:
    return bool(settings.agora_app_id and settings.agora_app_certificate)


def agora_app_id() -> str:
    return settings.agora_app_id or ""


def uid_for(client_id: str) -> int:
    """UID Agora 32-bit positif, stable pour un client_id."""
    return zlib.crc32(client_id.encode("utf-8")) & 0x7FFFFFFF or 1


def build_token(channel: str, client_id: str) -> str | None:
    if not voice_enabled():
        return None
    uid = uid_for(client_id)
    expire = int(time.time()) + TOKEN_TTL_SECONDS
    try:
        return RtcTokenBuilder.buildTokenWithUid(
            settings.agora_app_id,
            settings.agora_app_certificate,
            channel,
            uid,
            ROLE_PUBLISHER,
            expire,
        )
    except Exception:
        logger.exception("agora token failed for channel=%s", channel)
        return None
