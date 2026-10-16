from app.models import Game, GameRound, Submission
from app.schemas.game import AnswerResultOut, GameOut, GameSummaryOut, RoundResultOut


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


def round_result_out(game_round: GameRound, submission: Submission) -> RoundResultOut:
    elapsed = submission.submitted_at - game_round.started_at
    return RoundResultOut(
        number=game_round.number,
        letter=game_round.letter,
        answers=[
            AnswerResultOut(
                category=a.category,
                value=a.raw_value,
                status=a.status,
                points=a.points,
                matched_value=a.matched_value,
                hinted=a.hinted,
                suggestion=a.suggestion,
            )
            for a in submission.answers
        ],
        round_score=submission.score,
        elapsed_ms=max(0, int(elapsed.total_seconds() * 1000)),
    )


def game_summary_out(game: Game, hints_left: int) -> GameSummaryOut:
    rounds = [
        round_result_out(r, r.submissions[0]) for r in game.rounds if r.finished and r.submissions
    ]
    return GameSummaryOut(**game_out(game, hints_left).model_dump(), rounds=rounds)
