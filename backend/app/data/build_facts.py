"""Régénère `facts/facts.json.gz` (infos payantes ville/pays/animal/fruit).

Usage (depuis backend/, avec le cache GeoNames présent) :
  python -m app.data.build_facts
"""

from __future__ import annotations

# Script long : pour régénérer, relancer la génération interactive utilisée
# lors de l'ajout de la fonctionnalité, ou étendre ce module.
# Le fichier livré est `app/data/facts/facts.json.gz`.

from pathlib import Path

FACTS_GZ = Path(__file__).resolve().parent / "facts" / "facts.json.gz"


def main() -> None:
    if not FACTS_GZ.exists():
        raise SystemExit(f"Manquant : {FACTS_GZ}")
    print(f"OK {FACTS_GZ} ({FACTS_GZ.stat().st_size} octets)")


if __name__ == "__main__":
    main()
