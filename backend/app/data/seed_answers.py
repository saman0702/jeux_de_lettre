"""Charge la base de réponses.

    python -m app.data.seed_answers

Les pays, animaux et fruits viennent des fichiers JSON choisis à la main dans seed/. Les villes
viennent de GeoNames (villes de plus de 5 000 habitants, CC BY 4.0) et sont valables dans toutes les
langues. Les prénoms viennent du fichier des prénoms de l'Insee (naissances en France depuis 1900,
Licence Ouverte) et des 1 000 prénoms les plus donnés chaque année aux États-Unis (1880–2008,
Social Security Administration, domaine public) ; eux aussi valent dans toutes les langues.
"""

import asyncio
import csv
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
INSEE_NAMES_URL = "https://www.insee.fr/fr/statistiques/fichier/8595130/prenoms-2025-nat_csv.zip"
US_NAMES_URL = "https://raw.githubusercontent.com/hadley/data-baby-names/master/baby-names.csv"
# Un prénom de l'Insee compte s'il a été donné au moins ce nombre de fois depuis 1900.
MIN_NAME_BIRTHS = 20
# Les fichiers américains donnent une part des naissances : ~2 millions de naissances par sexe et
# par an pour la ramener à un nombre comparable à celui de l'Insee.
US_BIRTHS_PER_YEAR = 2_000_000

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


def _download(url: str, filename: str) -> bytes:
    """Fichier source, téléchargé une fois puis gardé dans .cache."""
    CACHE_DIR.mkdir(exist_ok=True)
    path = CACHE_DIR / filename
    if not path.exists():
        print(f"Downloading {url}…")
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request, timeout=180) as response:
            path.write_bytes(response.read())
    return path.read_bytes()


def geonames_archive() -> bytes:
    return _download(GEONAMES_URL, "cities5000.zip")


def display_name(raw: str) -> str:
    """« JEAN-PIERRE » -> « Jean-Pierre », « M'MAH » -> « M'Mah »."""
    out, upper_next = [], True
    for char in raw.strip().lower():
        out.append(char.upper() if upper_next else char)
        upper_next = char in " -'’"
    return "".join(out)


def name_entries() -> Iterator[Entry]:
    """Prénoms féminins et masculins, avec le nombre de naissances comme popularité."""
    counts: dict[tuple[Category, str], int] = {}
    archive = zipfile.ZipFile(io.BytesIO(_download(INSEE_NAMES_URL, "prenoms-2025-nat_csv.zip")))
    lines = archive.read(archive.namelist()[0]).decode("utf-8").splitlines()
    for line in lines[1:]:
        sex, name, _period, value, _rank = line.split(";")
        # « _PRENOMS_RARES » regroupe les prénoms trop rares pour être publiés.
        if name.startswith("_") or not value:
            continue
        category = Category.MALE_NAME if sex == "1" else Category.FEMALE_NAME
        key = (category, display_name(name))
        counts[key] = counts.get(key, 0) + int(value)
    for (category, name), births in counts.items():
        if births >= MIN_NAME_BIRTHS:
            yield category, ANY_LANGUAGE, name, births

    us = _download(US_NAMES_URL, "us-baby-names.csv").decode("utf-8")
    best: dict[tuple[Category, str], float] = {}
    for row in csv.DictReader(io.StringIO(us)):
        category = Category.MALE_NAME if row["sex"] == "boy" else Category.FEMALE_NAME
        key = (category, row["name"])
        best[key] = max(best.get(key, 0.0), float(row["percent"]))
    for (category, name), share in best.items():
        yield category, ANY_LANGUAGE, name, round(share * US_BIRTHS_PER_YEAR)


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
        rows += build_rows(name_entries())

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
