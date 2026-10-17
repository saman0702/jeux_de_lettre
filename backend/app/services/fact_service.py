"""Infos pédagogiques payantes sur une réponse (ville → pays, pays → capitale…).

Les faits sont chargés une fois depuis `app/data/facts/facts.json.gz`.
"""

from __future__ import annotations

import gzip
import json
from functools import lru_cache
from pathlib import Path

from app.core.game_rules import (
    CATEGORY_INFO_PRICE_FOUND,
    CATEGORY_INFO_PRICE_MISSED,
    Category,
)
from app.services.normalization import lookup_keys, normalize
from app.services.validation_service import Status

_FACTS_PATH = Path(__file__).resolve().parents[1] / "data" / "facts" / "facts.json.gz"

# Catégories pour lesquelles on vend des infos.
INFO_CATEGORIES = frozenset(
    {Category.CITY, Category.COUNTRY, Category.ANIMAL, Category.FRUIT}
)


def info_price(status: str) -> int:
    """1 pièce si la réponse était valide, 2 sinon."""
    return CATEGORY_INFO_PRICE_FOUND if status == Status.VALID else CATEGORY_INFO_PRICE_MISSED


@lru_cache(maxsize=1)
def _catalog() -> dict[str, dict[str, dict[str, list[str]]]]:
    with gzip.open(_FACTS_PATH, "rt", encoding="utf-8") as handle:
        return json.load(handle)


def info_word(matched_value: str | None, suggestion: str | None, raw_value: str) -> str:
    """Mot sur lequel porter l'info : réponse validée, sinon exemple, sinon saisie."""
    for candidate in (matched_value, suggestion, raw_value):
        if candidate and candidate.strip():
            return candidate.strip()
    return ""


def resolve_key(category: str, word: str) -> str | None:
    """Clé normalisée du catalogue pour ce mot, ou None."""
    if category not in {c.value for c in INFO_CATEGORIES} or not word.strip():
        return None
    bucket = _catalog().get(category) or {}
    cat = Category(category)
    for key in lookup_keys(word, cat):
        if key in bucket:
            return key
    key = normalize(word)
    return key if key in bucket else None


def unlock_id(category: str, word: str) -> str | None:
    """Identifiant durable d'un déblocage : `country:france`."""
    key = resolve_key(category, word)
    return f"{category}:{key}" if key else None


def lookup_lines(category: str, word: str, language: str) -> list[str] | None:
    """Lignes d'info pour un mot, ou None s'il n'y en a pas."""
    key = resolve_key(category, word)
    if key is None:
        return None
    entry = _catalog()[category][key]
    lines = entry.get(language) or entry.get("fr")
    return list(lines) if lines else None


def has_info(category: str, word: str) -> bool:
    return resolve_key(category, word) is not None
