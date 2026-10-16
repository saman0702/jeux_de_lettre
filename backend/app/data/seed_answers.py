"""Charge la base de réponses.

    python -m app.data.seed_answers

Les pays, animaux et fruits viennent des fichiers JSON choisis à la main dans seed/. Les villes
viennent de GeoNames (villes de plus de 5 000 habitants, CC BY 4.0) et sont valables dans toutes les
langues.
"""

import asyncio
import io
import json
import unicodedata
import urllib.request
import zipfile
from collections.abc import Iterator
from pathlib import Path

from sqlalchemy import delete, insert

from app.core.database import SessionLocal
from app.core.game_rules import ANY_LANGUAGE, Category, Language
from app.models import Answer
from app.services.normalization import first_letter, normalize

DATA_DIR = Path(__file__).parent
SEED_DIR = DATA_DIR / "seed"
CACHE_DIR = DATA_DIR / ".cache"
GEONAMES_URL = "https://download.geonames.org/export/dump/cities5000.zip"

CURATED_FILES = {
    Category.COUNTRY: "countries.json",
    Category.ANIMAL: "animals.json",
    Category.FRUIT: "fruits.json",
}

# catégorie, langue, valeur[, popularité] ; la popularité aide les bots à choisir des réponses
# connues
Entry = tuple


def curated_entries() -> Iterator[Entry]:
    for category, filename in CURATED_FILES.items():
        for item in json.loads((SEED_DIR / filename).read_text(encoding="utf-8")):
            for language in Language:
                for value in item.get(language, []):
                    yield category, language, value


def _is_latin(text: str) -> bool:
    return all(c.isascii() or "LATIN" in unicodedata.name(c, "") for c in text)


def _is_city_name(text: str) -> bool:
    # Les noms alternatifs de GeoNames mélangent de vraies orthographes (« Londres »), des codes («
    # YXU ») et des translittérations en minuscules (« lndn ») : on ne garde que les vraies.
    return len(text) >= 2 and _is_latin(text) and text[0].isupper() and not text.isupper()


def geonames_archive() -> bytes:
    CACHE_DIR.mkdir(exist_ok=True)
    path = CACHE_DIR / "cities5000.zip"
    if not path.exists():
        print(f"Downloading {GEONAMES_URL}…")
        with urllib.request.urlopen(GEONAMES_URL, timeout=120) as response:
            path.write_bytes(response.read())
    return path.read_bytes()


def city_entries() -> Iterator[Entry]:
    with zipfile.ZipFile(io.BytesIO(geonames_archive())) as archive:
        lines = archive.read("cities5000.txt").decode("utf-8").splitlines()
    for line in lines:
        fields = line.split("\t")
        name, ascii_name, alternates = fields[1], fields[2], fields[3]
        population = int(fields[14] or 0)
        # Seules les orthographes principales portent la population, pour que les bots préfèrent «
        # Paris » à un nom alternatif exotique.
        for value in [name, ascii_name]:
            if _is_city_name(value):
                yield Category.CITY, ANY_LANGUAGE, value, population
        for value in alternates.split(","):
            if _is_city_name(value):
                yield Category.CITY, ANY_LANGUAGE, value, 0


def build_rows(entries: Iterator[Entry]) -> list[dict]:
    rows: dict[tuple[str, str, str], dict] = {}
    for category, language, value, *rest in entries:
        popularity = rest[0] if rest else 0
        normalized = normalize(value)
        key = (category, language, normalized)
        if not normalized:
            continue
        if key in rows:
            rows[key]["popularity"] = max(rows[key]["popularity"], popularity)
        else:
            rows[key] = {
                "category": category,
                "language": language,
                "value": value.strip()[:200],
                "normalized_value": normalized[:200],
                "first_letter": first_letter(normalized),
                "accepted": True,
                "popularity": popularity,
            }
    return list(rows.values())


async def seed(include_cities: bool = True) -> int:
    entries = curated_entries()
    rows = build_rows(entries)
    if include_cities:
        rows += build_rows(city_entries())

    async with SessionLocal() as session:
        await session.execute(delete(Answer))
        for start in range(0, len(rows), 5000):
            await session.execute(insert(Answer), rows[start : start + 5000])
        await session.commit()
    return len(rows)


def main() -> None:
    count = asyncio.run(seed())
    print(f"Seeded {count} answers.")


if __name__ == "__main__":
    main()
