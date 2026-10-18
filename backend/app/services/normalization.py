"""Transforme les réponses libres en clés comparables.

« Éléphant », « elephant  » et « ELEPHANT » deviennent tous « elephant ».
"""

import re
import unicodedata

from app.core.game_rules import Category

_LIGATURES = str.maketrans({"œ": "oe", "Œ": "oe", "æ": "ae", "Æ": "ae", "ß": "ss"})
_SEPARATORS = re.compile(r"[\s\-‐‑–—'’`´.,/_]+")
_NON_ALNUM = re.compile(r"[^a-z0-9 ]")

_LEADING_ARTICLES = re.compile(r"^(?:le|la|les|l|un|une|des|du|the|a|an) (?=.)")

# Les noms communs peuvent être tapés avec un article ou au pluriel ; les noms propres (villes)
# gardent leur article, qui fait partie du nom (« Le Havre »).
_COMMON_NOUN_CATEGORIES = frozenset({Category.ANIMAL, Category.FRUIT})
_ARTICLE_CATEGORIES = frozenset({Category.ANIMAL, Category.FRUIT, Category.COUNTRY})


def normalize(text: str) -> str:
    text = text.translate(_LIGATURES)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c)).lower()
    text = _SEPARATORS.sub(" ", text)
    text = _NON_ALNUM.sub("", text)
    return " ".join(text.split())


def strict_form(text: str) -> str:
    """Forme exigée en mode sévère : casse, accents et espaces comptent (seuls les bords sont coupés)."""
    return unicodedata.normalize("NFC", text.strip())


def strip_article(normalized: str) -> str:
    return _LEADING_ARTICLES.sub("", normalized)


def first_letter(normalized: str) -> str:
    return normalized[:1].upper()


def lookup_keys(raw: str, category: Category) -> list[str]:
    """Formes normalisées à chercher dans la base, de la plus précise à la plus large."""
    base = normalize(raw)
    if not base:
        return []

    keys = [base]
    if category in _ARTICLE_CATEGORIES:
        keys.append(strip_article(base))
    if category in _COMMON_NOUN_CATEGORIES:
        for key in list(keys):
            for suffix in ("es", "s", "x"):
                if key.endswith(suffix) and len(key) > len(suffix) + 2:
                    keys.append(key[: -len(suffix)])

    return list(dict.fromkeys(keys))


def starts_with_letter(normalized: str, letter: str) -> bool:
    """Vrai si la réponse commence par la lettre, avec ou sans son article."""
    letter = letter.upper()
    return first_letter(normalized) == letter or first_letter(strip_article(normalized)) == letter
