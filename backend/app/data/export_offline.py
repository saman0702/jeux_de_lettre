"""Exporte la base de réponses pour les parties solo hors ligne de l'appli.

    python -m app.data.export_offline

Écrit dans mobile/ :
- assets/data/answers.tsv.gz : catégorie, langue, première lettre, valeur normalisée, valeur —
  triées pour que les réponses les plus connues de chaque lettre viennent en premier
- assets/data/normalize_map.json : la normalisation de chaque caractère non ASCII, pour que l'appli
  compare les réponses exactement comme le serveur
- test/fixtures/normalize_cases.json : entrées et clés attendues, utilisées par les tests de l'appli
  pour vérifier que les deux côtés concordent
"""

import gzip
import json
import unicodedata
from pathlib import Path

from app.data.seed_answers import build_rows, city_entries, curated_entries, name_entries
from app.services.normalization import _LIGATURES, normalize

MOBILE = Path(__file__).resolve().parents[3] / "mobile"


def char_map() -> dict[str, str]:
    """Comment le serveur transforme chaque caractère non ASCII (accents, ligatures, casse).

    L'appli fait passer chaque caractère par cette table, puis applique le même filtrage des
    séparateurs et des a-z0-9, ce qui donne la même clé que `normalize`. Les caractères absents de
    la table sont supprimés, comme sur le serveur.
    """
    mapping = {}
    for code in range(0x80, 0x3000):
        char = chr(code)
        folded = unicodedata.normalize("NFKD", char.translate(_LIGATURES))
        folded = "".join(c for c in folded if not unicodedata.combining(c)).lower()
        if folded != char and any(c.isascii() for c in folded):
            mapping[char] = folded
    return mapping


def cases(rows: list[dict]) -> list[list[str]]:
    samples = [
        "Éléphant", "  l'ÉLÉPHANT ", "Côte d’Ivoire", "Bœuf", "Porc-épic!", "Łódź", "Şanlıurfa",
        "São Paulo", "Ærøskøbing", "Straße", "İzmir", "Mbandaka", "Le Havre", "N'Djamena",
        "Yamoussoukro", "Bouaké", "Zürich", "Kraków", "Hà Nội", "Đà Nẵng", "Reykjavík", "Ñuñoa",
    ]
    samples += [r["value"] for r in rows[:: max(1, len(rows) // 400)]]
    return [[s, normalize(s)] for s in samples]


def main() -> None:
    rows = build_rows(curated_entries()) + build_rows(city_entries()) + build_rows(name_entries())
    rows.sort(key=lambda r: (r["category"], r["language"], r["first_letter"], -r["popularity"], r["value"]))

    data = MOBILE / "assets" / "data"
    data.mkdir(parents=True, exist_ok=True)
    lines = "".join(
        f"{r['category']}\t{r['language']}\t{r['first_letter']}\t{r['normalized_value']}\t{r['value']}\n"
        for r in rows
    )
    (data / "answers.tsv.gz").write_bytes(gzip.compress(lines.encode("utf-8"), compresslevel=9, mtime=0))
    (data / "normalize_map.json").write_text(json.dumps(char_map(), ensure_ascii=False, sort_keys=True))

    fixtures = MOBILE / "test" / "fixtures"
    fixtures.mkdir(parents=True, exist_ok=True)
    (fixtures / "normalize_cases.json").write_text(json.dumps(cases(rows), ensure_ascii=False, indent=0))
    print(f"Exported {len(rows)} answers.")


if __name__ == "__main__":
    main()
