"""Cycle de vie d'une partie. Le serveur maîtrise la lettre, le chrono et le score."""

from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.game_rules import (
    EXTRA_HINT_PRICE,
    HINTS_PER_GAME,
    SUBMIT_GRACE_SECONDS,
    Category,
    Difficulty,
)
from app.models import Game, GameRound, HintRequest, Player, PlayerAnswer, Submission
from app.models.base import utcnow
from app.schemas.game import SoloGameCreate
from app.services import fact_service, hint_service, letter_service, perks_service, suggestion_service, wallet_service
from app.services.scoring_service import score_round
from app.services.normalization import lookup_keys, normalize
from app.services.validation_service import Status, ValidationResult, validate_answer


class GameError(Exception):
    def __init__(self, code: str, status_code: int = 409):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


async def get_game(session: AsyncSession, game_id: str) -> Game:
    game = await session.scalar(select(Game).where(Game.id == game_id))
    if game is None:
        raise GameError("game_not_found", 404)
    return game


async def create_solo_game(session: AsyncSession, data: SoloGameCreate) -> Game:
    game = Game(
        mode="solo",
        language=data.language,
        difficulty=data.difficulty,
        categories=[c.value for c in data.categories],
        total_rounds=data.rounds,
        round_duration=data.round_duration,
        strict_spelling=data.strict_spelling,
        status="playing",
        players=[Player(nickname=data.nickname)],
        rounds=[],
        owner_client_id=data.client_id,
        avoid_letters=data.avoid_letters,
        banned_answers={c.value: words for c, words in data.banned_answers.items()},
    )
    session.add(game)
    if data.client_id:
        profile = await wallet_service.get_profile(session, data.client_id, data.nickname)
        # Abonnés au Pass : jokers en plus dans chaque partie.
        game.bonus_hints = perks_service.bonus_hints_for(profile)
    await session.commit()
    return game


def _is_expired(game_round: GameRound) -> bool:
    return utcnow() > game_round.ends_at + timedelta(seconds=SUBMIT_GRACE_SECONDS)


def _banned_keys(game: Game) -> dict[str, set[str]]:
    """Clés normalisées interdites : stock carrière + réponses déjà validées ici."""
    banned: dict[str, set[str]] = {}
    for category, words in (game.banned_answers or {}).items():
        keys = banned.setdefault(category, set())
        cat = Category(category)
        for word in words:
            keys.add(normalize(word))
            keys.update(lookup_keys(word, cat))
    for game_round in game.rounds:
        if not game_round.finished:
            continue
        for submission in game_round.submissions:
            for answer in submission.answers:
                if answer.status != Status.VALID or not answer.matched_value:
                    continue
                cat = Category(answer.category)
                keys = banned.setdefault(answer.category, set())
                keys.add(normalize(answer.matched_value))
                keys.update(lookup_keys(answer.matched_value, cat))
    return banned


async def _close_expired_round(session: AsyncSession, game: Game, game_round: GameRound) -> None:
    """Les joueurs qui n'ont rien envoyé reçoivent un envoi « en retard » à zéro point."""
    submitted = {s.player_id for s in game_round.submissions}
    for player in game.players:
        if player.id not in submitted:
            game_round.submissions.append(
                Submission(
                    player_id=player.id,
                    submitted_at=game_round.ends_at,
                    score=0,
                    answers=[
                        PlayerAnswer(category=c, raw_value="", status=Status.LATE, points=0)
                        for c in game.categories
                    ],
                )
            )
    game_round.finished = True
    if game_round.number >= game.total_rounds:
        game.status = "finished"


async def start_next_round(session: AsyncSession, game: Game) -> GameRound:
    current = game.current_round
    if current is not None and not current.finished:
        if not _is_expired(current):
            raise GameError("round_in_progress")
        await _close_expired_round(session, game, current)

    if game.status == "finished" or len(game.rounds) >= game.total_rounds:
        await session.commit()
        raise GameError("game_finished")

    counts = await letter_service.letter_counts(session, game.language)
    eligible = letter_service.eligible_letters(counts, game.categories, Difficulty(game.difficulty))
    try:
        letter = letter_service.draw_letter(
            eligible,
            [r.letter for r in game.rounds] + list(game.avoid_letters or ""),
        )
    except letter_service.NoLetterAvailable:
        raise GameError("no_letter_available", 503) from None

    started_at = utcnow()
    game_round = GameRound(
        number=len(game.rounds) + 1,
        letter=letter,
        started_at=started_at,
        ends_at=started_at + timedelta(seconds=game.round_duration),
        submissions=[],
    )
    game.rounds.append(game_round)
    await session.commit()
    return game_round


async def hints_left(session: AsyncSession, game: Game) -> int:
    used = await session.scalar(
        select(func.count()).select_from(HintRequest).where(HintRequest.player_id == game.players[0].id)
    )
    return max(0, HINTS_PER_GAME + (game.bonus_hints or 0) - (used or 0))


def _playable_round(game: Game, round_number: int) -> GameRound:
    game_round = game.current_round
    if game_round is None or game_round.number != round_number:
        raise GameError("round_not_current")
    if game_round.finished or _is_expired(game_round):
        raise GameError("round_over")
    return game_round


async def _hint_for(session: AsyncSession, game_round: GameRound, player_id: str, category: str):
    return await session.scalar(
        select(HintRequest).where(
            HintRequest.round_id == game_round.id,
            HintRequest.player_id == player_id,
            HintRequest.category == category,
        )
    )


async def request_hint(
    session: AsyncSession,
    game: Game,
    round_number: int,
    category: Category,
    *,
    reveal: bool = False,
) -> tuple[HintRequest, int]:
    """Joker : QCM (3 choix) ou révélation directe du mot si reveal=True."""
    game_round = _playable_round(game, round_number)
    if category.value not in game.categories:
        raise GameError("invalid_category", 422)
    player = game.players[0]

    existing = await _hint_for(session, game_round, player.id, category.value)
    if existing is not None:
        if reveal and existing.picked is None:
            existing.options = [existing.answer]
            existing.picked = existing.answer
            await session.commit()
        return existing, await hints_left(session, game)
    if await hints_left(session, game) == 0:
        raise GameError("no_hints_left")

    try:
        hint = await hint_service.build_hint(session, game.language, category.value, game_round.letter)
    except hint_service.NoHintAvailable:
        raise GameError("no_hint_available") from None
    if reveal:
        # Joker acheté en pièces : un seul mot, déjà validé.
        request = HintRequest(
            round_id=game_round.id,
            player_id=player.id,
            category=category.value,
            options=[hint.answer],
            answer=hint.answer,
            picked=hint.answer,
        )
    else:
        request = HintRequest(
            round_id=game_round.id,
            player_id=player.id,
            category=category.value,
            options=hint.options,
            answer=hint.answer,
        )
    session.add(request)
    await session.commit()
    return request, await hints_left(session, game)


async def pick_hint(
    session: AsyncSession, game: Game, round_number: int, category: Category, choice: str
) -> HintRequest:
    game_round = _playable_round(game, round_number)
    request = await _hint_for(session, game_round, game.players[0].id, category.value)
    if request is None:
        raise GameError("no_hint_requested")
    if request.picked is not None:
        raise GameError("hint_already_picked")
    if choice not in request.options:
        raise GameError("invalid_choice", 422)
    request.picked = choice
    await session.commit()
    return request


async def buy_hint(
    session: AsyncSession, game: Game
) -> tuple[int, wallet_service.WalletUpdate]:
    """Achète un joker supplémentaire avec des pièces (pendant la partie)."""
    if not game.owner_client_id:
        raise GameError("login_required", 401)
    if game.status != "playing":
        raise GameError("game_finished")
    try:
        profile = await wallet_service.debit(
            session, game.owner_client_id, EXTRA_HINT_PRICE, "extra_hint", game.id
        )
    except wallet_service.WalletError as error:
        raise GameError(error.code, 402 if error.code == "not_enough_coins" else 422) from None
    game.bonus_hints = (game.bonus_hints or 0) + 1
    await session.commit()
    left = await hints_left(session, game)
    return left, wallet_service.snapshot(profile)


async def buy_category_info(
    session: AsyncSession, game: Game, round_number: int, category: Category
) -> tuple[str, list[str], int, wallet_service.WalletUpdate]:
    """Dévoile les infos d'une catégorie après la manche (ville → pays, etc.)."""
    if not game.owner_client_id:
        raise GameError("login_required", 401)
    if category.value not in game.categories:
        raise GameError("invalid_category", 422)
    if category not in fact_service.INFO_CATEGORIES:
        raise GameError("no_info_available", 422)

    game_round = next((r for r in game.rounds if r.number == round_number), None)
    if game_round is None or not game_round.finished or not game_round.submissions:
        raise GameError("round_not_finished", 409)
    submission = game_round.submissions[0]
    answer = next((a for a in submission.answers if a.category == category.value), None)
    if answer is None:
        raise GameError("invalid_category", 422)

    word = fact_service.info_word(answer.matched_value, answer.suggestion, answer.raw_value)
    lines = fact_service.lookup_lines(category.value, word, game.language)
    unlock = fact_service.unlock_id(category.value, word)
    if not lines or unlock is None:
        raise GameError("no_info_available", 422)

    profile = await wallet_service.get_profile(session, game.owner_client_id)
    if wallet_service.has_fact_unlocked(profile, unlock):
        await session.commit()
        return word, lines, 0, wallet_service.snapshot(profile)

    price = fact_service.info_price(answer.status)
    try:
        profile = await wallet_service.debit(
            session,
            game.owner_client_id,
            price,
            "category_info",
            unlock[:64],
        )
    except wallet_service.WalletError as error:
        raise GameError(error.code, 402 if error.code == "not_enough_coins" else 422) from None
    wallet_service.unlock_fact(profile, unlock)
    await session.commit()
    return word, lines, price, wallet_service.snapshot(profile)


async def submit_answers(
    session: AsyncSession, game: Game, round_number: int, answers: dict[Category, str]
) -> tuple[Submission, wallet_service.WalletUpdate | None]:
    """Valide et note la manche ; crédite les points au profil du joueur s'il en a un."""
    game_round = game.current_round
    if game_round is None or game_round.number != round_number:
        raise GameError("round_not_current")
    if game_round.finished:
        raise GameError("round_already_submitted")

    player = game.players[0]
    submitted_at = utcnow()
    late = _is_expired(game_round)

    picked = {
        h.category: h
        for h in await session.scalars(
            select(HintRequest).where(
                HintRequest.round_id == game_round.id,
                HintRequest.player_id == player.id,
                HintRequest.picked.is_not(None),
            )
        )
    }
    answers = {**answers, **{Category(c): h.picked for c, h in picked.items()}}

    banned = _banned_keys(game)
    results: dict[str, ValidationResult] = {}
    for category in game.categories:
        raw = answers.get(Category(category), "")
        if late:
            results[category] = ValidationResult(Status.LATE)
        elif category in picked and picked[category].picked != picked[category].answer:
            results[category] = ValidationResult(Status.HINT_WRONG)
        else:
            result = await validate_answer(
                session,
                Category(category),
                game.language,
                game_round.letter,
                raw,
                strict_spelling=game.strict_spelling,
            )
            if (
                result.is_valid
                and result.match_key is not None
                and result.match_key in banned.get(category, ())
            ):
                result = ValidationResult(
                    Status.ALREADY_USED, matched_value=result.matched_value, match_key=result.match_key
                )
            results[category] = result

    points = score_round({player.id: results}, {player.id: set(picked)})[player.id]
    # Une bonne réponse à montrer pour chaque catégorie ratée.
    missed = [c for c, r in results.items() if not r.is_valid]
    examples = await suggestion_service.example_answers(session, game.language, missed, game_round.letter)
    submission = Submission(
        player_id=player.id,
        submitted_at=min(submitted_at, game_round.ends_at),
        score=sum(points.values()),
        answers=[
            PlayerAnswer(
                category=category,
                raw_value=answers.get(Category(category), "")[:200],
                matched_value=result.matched_value if result.is_valid else None,
                status=result.status,
                points=points[category],
                hinted=category in picked,
                suggestion=examples.get(category),
            )
            for category, result in results.items()
        ],
    )
    game_round.submissions.append(submission)
    game_round.finished = True
    player.total_score += submission.score
    if game_round.number >= game.total_rounds:
        game.status = "finished"

    wallet = None
    if game.owner_client_id:
        wallet = await wallet_service.award_points(
            session, game.owner_client_id, submission.score, reference=game.id
        )
    await session.commit()
    return submission, wallet
