"""Les noms de pays ne doivent pas passer en catégorie ville (sauf capitales PPLC)."""

from app.data.seed_answers import country_normalized_names, is_allowed_city_label


def test_country_list_includes_angola():
    assert "angola" in country_normalized_names()


def test_rejects_country_homonym_cities():
    countries = country_normalized_names()
    assert not is_allowed_city_label("Angola", countries, allow_country_name=False)
    assert not is_allowed_city_label("Brazil", countries, allow_country_name=False)


def test_allows_city_state_capitals():
    countries = country_normalized_names()
    assert is_allowed_city_label("Luxembourg", countries, allow_country_name=True)
    assert is_allowed_city_label("Singapore", countries, allow_country_name=True)
    assert is_allowed_city_label("Paris", countries, allow_country_name=False)
