import random

from app.core.game_rules import Category, Difficulty
from app.services.bot_service import BOT_PROFILES, answer_delay, bot_name, candidates, choose_answers

OPTIONS = {"city": ["Madrid", "Marseille", "Mbandaka"], "fruit": ["Mangue", "Melon"]}


def test_hard_bots_answer_more_often_than_easy_ones():
    rng = random.Random(1)
    easy = sum(len(choose_answers(BOT_PROFILES[Difficulty.EASY], OPTIONS, rng)) for _ in range(300))
    hard = sum(len(choose_answers(BOT_PROFILES[Difficulty.HARD], OPTIONS, rng)) for _ in range(300))
    assert hard > easy * 1.4


def test_bots_skip_categories_without_known_answers():
    answers = choose_answers(BOT_PROFILES[Difficulty.HARD], {"city": [], "fruit": ["Mangue"]}, random.Random(2))
    assert Category.CITY not in answers


def test_hard_bots_answer_faster():
    rng = random.Random(3)
    assert max(answer_delay(BOT_PROFILES[Difficulty.HARD], 30, rng) for _ in range(50)) < 30 * 0.56
    assert min(answer_delay(BOT_PROFILES[Difficulty.EASY], 30, rng) for _ in range(50)) > 30 * 0.54


def test_bot_names_are_unique_in_a_room():
    taken = set()
    for _ in range(8):
        taken.add(bot_name(taken))
    assert len(taken) == 8


async def test_candidates_prefer_popular_answers(session):
    options = await candidates(session, "fr", ["country", "fruit"], "M", pool=50)
    assert "Maroc" in options["country"]
    assert all(value.upper().startswith("M") for value in options["fruit"])
