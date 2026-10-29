"""Exporte des énigmes de QI pour le solo hors ligne de l'appli.

    python -m app.data.export_iq

Écrit mobile/assets/data/iq_puzzles.json : toutes les énigmes écrites à la main et des énigmes
générées (suites, grilles, problèmes, lettres, calendrier) pour chaque niveau.
"""

import json
import random
from pathlib import Path

from app.services import iq_service

MOBILE = Path(__file__).resolve().parents[3] / "mobile"
PER_LEVEL = 120


def main() -> None:
    rng = random.Random(2026)
    seen: dict[str, dict] = {}
    for level in (1, 2, 3):
        tries = 0
        while sum(1 for p in seen.values() if p["level"] == level) < PER_LEVEL and tries < 5000:
            tries += 1
            puzzle = iq_service.draw(level, exclude=set(seen), rng=rng)
            seen.setdefault(puzzle.id, puzzle.reveal())
    out = MOBILE / "assets" / "data" / "iq_puzzles.json"
    out.write_text(json.dumps(list(seen.values()), ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Exported {len(seen)} IQ puzzles to {out}")


if __name__ == "__main__":
    main()
