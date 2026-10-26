import random

from fastapi import APIRouter, Query

from app.services import iq_service

router = APIRouter(prefix="/api/v1/iq", tags=["iq"])


@router.get("/puzzles")
async def solo_puzzles(
    count: int = Query(default=10, ge=1, le=30),
    difficulty: str = Query(default="normal", pattern="^(easy|normal|hard)$"),
):
    """Énigmes d'une partie solo, de plus en plus difficiles, avec leurs réponses : le solo se
    joue sur le téléphone (il ne rapporte ni pièces ni niveau)."""
    rng = random.Random()
    used: set[str] = set()
    puzzles = []
    for number in range(1, count + 1):
        puzzle = iq_service.draw(iq_service.level_for(number, count, difficulty), exclude=used, rng=rng)
        used.add(puzzle.id)
        puzzles.append(puzzle.reveal())
    return puzzles
