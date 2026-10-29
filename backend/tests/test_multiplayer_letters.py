"""Tirage de la lettre d'une manche de salon, sans remplacer draw_letter (les tests de salons le
remplacent par « M », ce qui cachait un bug : la partie finissait tout de suite au podium)."""

from app.schemas.game import GameSettings
from app.services import letter_service, multiplayer_service


def test_draw_letter_accepts_any_collection():
    assert letter_service.draw_letter(["A", "B"], ["A"]) == "B"
    assert letter_service.draw_letter({"A"}, ["A"]) == "A", "all used: letters come back"


async def test_a_room_round_draws_a_real_letter(session):
    settings = GameSettings(language="fr", rounds=5)
    game_id, _ = await multiplayer_service.create_game(session, "room", settings, {"alice-0001": "Alice"})
    # Avant la correction : TypeError ici, la boucle de jeu s'arrêtait et la salle allait au podium.
    for _ in range(3):
        info = await multiplayer_service.start_round(session, game_id, {"fr"})
        assert len(info.letter) == 1


async def test_a_mixed_language_round_draws_a_letter(session):
    settings = GameSettings(language="fr", rounds=5)
    game_id, _ = await multiplayer_service.create_game(session, "room", settings, {"alice-0001": "Alice"})
    info = await multiplayer_service.start_round(session, game_id, {"fr", "en"})
    assert len(info.letter) == 1
