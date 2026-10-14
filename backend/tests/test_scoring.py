from app.services.scoring_service import score_round
from app.services.validation_service import Status, ValidationResult


def valid(key: str) -> ValidationResult:
    return ValidationResult(Status.VALID, matched_value=key.title(), match_key=key)


def test_unique_answer_scores_10_shared_scores_5_invalid_scores_0():
    scores = score_round(
        {
            "kevin": {"city": valid("marseille"), "fruit": valid("mangue")},
            "blaise": {"city": valid("marseille"), "fruit": ValidationResult(Status.NOT_FOUND)},
            "serge": {"city": valid("mbandaka"), "fruit": ValidationResult(Status.EMPTY)},
        }
    )

    assert scores["kevin"] == {"city": 5, "fruit": 10}
    assert scores["blaise"] == {"city": 5, "fruit": 0}
    assert scores["serge"] == {"city": 10, "fruit": 0}


def test_solo_player_always_gets_full_points():
    assert score_round({"me": {"city": valid("madrid")}}) == {"me": {"city": 10}}
