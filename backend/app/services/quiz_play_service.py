"""Solo Chrono / Mot & Sens : vérification serveur et conversion points → pièces."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.data.chrono_bank import CHRONO_QUESTIONS
from app.data.mots_bank import MOTS_QUESTIONS
from app.services import wallet_service

BANKS = {
    "chrono": {q["id"]: q for q in CHRONO_QUESTIONS},
    "mots": {q["id"]: q for q in MOTS_QUESTIONS},
}

POINTS_PER_CORRECT = 10
MAX_ANSWERS = 15


async def finish_solo(
    session: AsyncSession,
    client_id: str,
    game: str,
    answers: list[dict],
) -> dict:
    """Vérifie les réponses, crédite les points, renvoie le wallet éventuel."""
    bank = BANKS[game]
    seen: set[str] = set()
    correct = 0
    points = 0
    detail = []
    for raw in answers[:MAX_ANSWERS]:
        qid = str(raw.get("id") or "")
        if not qid or qid in seen or qid not in bank:
            continue
        seen.add(qid)
        choice = raw.get("choice")
        expected = int(bank[qid]["answer"])
        ok = choice is not None and int(choice) == expected
        pts = POINTS_PER_CORRECT if ok else 0
        if ok:
            correct += 1
            points += pts
        detail.append({"id": qid, "correct": ok, "points": pts})

    wallet = None
    if points > 0:
        wallet = (
            await wallet_service.award_points(
                session, client_id, points, reference=f"quiz:{game}"
            )
        ).as_dict()

    return {
        "game": game,
        "correct": correct,
        "total": len(detail),
        "points": points,
        "answers": detail,
        "wallet": wallet,
    }
