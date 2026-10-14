from app.core.game_rules import Category
from app.services.normalization import lookup_keys, normalize, starts_with_letter


def test_normalize_ignores_case_accents_and_spaces():
    assert normalize("éléphant") == normalize("Elephant") == normalize("  ELEPHANT ") == "elephant"


def test_normalize_handles_separators_and_ligatures():
    assert normalize("Côte d’Ivoire") == "cote d ivoire"
    assert normalize("Bœuf") == "boeuf"
    assert normalize("Porc-épic!") == "porc epic"


def test_lookup_keys_strip_articles_and_plurals_for_common_nouns():
    assert "mangue" in lookup_keys("Les Mangues", Category.FRUIT)
    assert "elephant" in lookup_keys("l'éléphant", Category.ANIMAL)


def test_lookup_keys_keep_city_names_intact():
    assert lookup_keys("Le Havre", Category.CITY) == ["le havre"]


def test_lookup_keys_empty_answer():
    assert lookup_keys("   ", Category.CITY) == []


def test_starts_with_letter_with_or_without_article():
    assert starts_with_letter("le havre", "h")
    assert starts_with_letter("le havre", "L")
    assert not starts_with_letter("chat", "M")
