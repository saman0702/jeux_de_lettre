"""Réponses équivalentes d'une langue à l'autre, pour les parties où chacun joue dans sa langue.

« Spain » (anglais) et « Espagne » (français) sont la même réponse : elles comptent comme
partagées dans le calcul des points. Les paires viennent des fichiers choisis à la main
(pays, animaux, fruits). Les villes et les prénoms sont déjà communs à toutes les langues.
"""

import json
from functools import lru_cache

from app.core.game_rules import Category
from app.data.seed_answers import CURATED_FILES, SEED_DIR
from app.services.normalization import normalize, strip_article


@lru_cache
def _concepts() -> dict[tuple[str, str], str]:
    """(catégorie, valeur normalisée) -> identifiant commun de la réponse."""
    concepts: dict[tuple[str, str], str] = {}
    for category, filename in CURATED_FILES.items():
        items = json.loads((SEED_DIR / filename).read_text(encoding="utf-8"))
        for index, item in enumerate(items):
            concept = f"{category.value}:{index}"
            for values in item.values():
                for value in values:
                    key = normalize(value)
                    for form in {key, strip_article(key)}:
                        concepts.setdefault((category.value, form), concept)
    return concepts


def concept_key(category: Category | str, match_key: str | None) -> str | None:
    """Clé de comparaison entre joueurs : la même pour une réponse et sa traduction."""
    if match_key is None:
        return None
    return _concepts().get((str(category), match_key), match_key)
