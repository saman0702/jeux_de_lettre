from app.models import Game, GameRound, Profile, Submission
from app.schemas.game import AnswerResultOut, GameOut, GameSummaryOut, RoundResultOut
from app.services import fact_service, wallet_service


def game_out(game: Game, hints_left: int) -> GameOut:
    player = game.players[0]
    return GameOut(
        id=game.id,
        mode=game.mode,
        language=game.language,
        difficulty=game.difficulty,
        categories=game.categories,
        total_rounds=game.total_rounds,
        round_duration=game.round_duration,
        status=game.status,
        nickname=player.nickname,
        total_score=player.total_score,
        rounds_played=sum(1 for r in game.rounds if r.finished),
        hints_left=hints_left,
    )


def _answer_out(
    answer,
    *,
    language: str,
    unlocked: set[str],
) -> AnswerResultOut:
    word = fact_service.info_word(answer.matched_value, answer.suggestion, answer.raw_value)
    unlock = fact_service.unlock_id(answer.category, word)
    available = unlock is not None
    is_unlocked = bool(unlock and unlock in unlocked)
    lines = (
        fact_service.lookup_lines(answer.category, word, language) if is_unlocked else None
    )
    return AnswerResultOut(
        category=answer.category,
        value=answer.raw_value,
        status=answer.status,
        points=answer.points,
        matched_value=answer.matched_value,
        hinted=answer.hinted,
        suggestion=answer.suggestion,
        info_available=available,
        info_price=0 if is_unlocked or not available else fact_service.info_price(answer.status),
        info_unlocked=is_unlocked,
        info_lines=lines,
    )


def round_result_out(
    game_round: GameRound,
    submission: Submission,
    *,
    language: str = "fr",
    unlocked: set[str] | None = None,
) -> RoundResultOut:
    unlocked = unlocked or set()
    elapsed = submission.submitted_at - game_round.started_at
    return RoundResultOut(
        number=game_round.number,
        letter=game_round.letter,
        answers=[
            _answer_out(a, language=language, unlocked=unlocked) for a in submission.answers
        ],
        round_score=submission.score,
        elapsed_ms=max(0, int(elapsed.total_seconds() * 1000)),
    )


def enrich_answer_dict(answer: dict, *, language: str, unlocked: set[str]) -> dict:
    """Enrichit un dict de réponse multijoueur avec le statut de déblocage."""
    word = fact_service.info_word(
        answer.get("matched_value"), answer.get("suggestion"), answer.get("value") or ""
    )
    category = answer["category"]
    unlock = fact_service.unlock_id(category, word)
    available = unlock is not None
    is_unlocked = bool(unlock and unlock in unlocked)
    lines = fact_service.lookup_lines(category, word, language) if is_unlocked else None
    return {
        **answer,
        "info_available": available,
        "info_price": 0
        if is_unlocked or not available
        else fact_service.info_price(answer.get("status") or ""),
        "info_unlocked": is_unlocked,
        "info_lines": lines,
    }


def game_summary_out(
    game: Game, hints_left: int, profile: Profile | None = None
) -> GameSummaryOut:
    unlocked = wallet_service.unlocked_facts(profile) if profile else set()
    rounds = [
        round_result_out(
            r, r.submissions[0], language=game.language, unlocked=unlocked
        )
        for r in game.rounds
        if r.finished and r.submissions
    ]
    return GameSummaryOut(**game_out(game, hints_left).model_dump(), rounds=rounds)
