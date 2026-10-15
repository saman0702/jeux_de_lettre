"""Round scoring: a valid answer is worth more when no other player gave it."""

from collections import Counter

from app.core.game_rules import HINT_POINTS_SHARED, HINT_POINTS_UNIQUE, POINTS_SHARED, POINTS_UNIQUE
from app.services.validation_service import ValidationResult

PlayerResults = dict[str, dict[str, ValidationResult]]  # player -> category -> result


def score_round(
    results: PlayerResults, hinted: dict[str, set[str]] | None = None
) -> dict[str, dict[str, int]]:
    """`hinted` lists, per player, the categories answered with a hint (half points)."""
    hinted = hinted or {}
    occurrences: Counter[tuple[str, str]] = Counter(
        (category, result.match_key)
        for answers in results.values()
        for category, result in answers.items()
        if result.is_valid
    )

    scores: dict[str, dict[str, int]] = {}
    for player_id, answers in results.items():
        scores[player_id] = {}
        for category, result in answers.items():
            if not result.is_valid:
                points = 0
            else:
                shared = occurrences[(category, result.match_key)] > 1
                if category in hinted.get(player_id, ()):
                    points = HINT_POINTS_SHARED if shared else HINT_POINTS_UNIQUE
                else:
                    points = POINTS_SHARED if shared else POINTS_UNIQUE
            scores[player_id][category] = points
    return scores
