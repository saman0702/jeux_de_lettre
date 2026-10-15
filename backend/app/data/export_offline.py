"""Export the answer knowledge base for offline solo games in the app.

    python -m app.data.export_offline

Writes into mobile/:
- assets/data/answers.tsv.gz: category, language, first letter, normalized
  value, value — sorted so the best-known answers of each letter come first
- assets/data/normalize_map.json: how each non-ASCII character normalizes,
  so the app compares typed answers exactly like the server
- test/fixtures/normalize_cases.json: inputs and expected keys used by the
  app's tests to check both sides agree
"""

import gzip
import json
import unicodedata
from pathlib import Path

from app.data.seed_answers import build_rows, city_entries, curated_entries
from app.services.normalization import _LIGATURES, normalize

MOBILE = Path(__file__).resolve().parents[3] / "mobile"


def char_map() -> dict[str, str]:
    """How the server folds each non-ASCII character (accents, ligatures, case).

    The app maps characters through this table, then applies the same
    separator and a-z0-9 filtering, which gives the same key as `normalize`.
    Characters absent from the table are dropped, as on the server.
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
    rows = build_rows(curated_entries()) + build_rows(city_entries())
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
