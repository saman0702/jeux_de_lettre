import io

import pytest
from PIL import Image, ImageDraw
from sqlalchemy import select

from app.models import CoinTransaction
from app.core.config import settings
from app.services import avatar_service, letter_service, wallet_service

GAME = {"language": "fr", "rounds": 5, "round_duration": 30, "nickname": "Blaise"}
CLIENT = "flore-0001"


async def test_twenty_points_make_one_coin(session):
    update = await wallet_service.award_points(session, CLIENT, 15)
    assert (update.coins, update.coins_gained, update.points_to_next_coin) == (0, 0, 5)

    update = await wallet_service.award_points(session, CLIENT, 30)
    assert (update.coins, update.coins_gained, update.points_to_next_coin) == (2, 2, 15)
    await session.commit()

    ledger = (await session.scalars(select(CoinTransaction))).all()
    assert [(t.amount, t.reason) for t in ledger] == [(2, "points")]
    profile = await wallet_service.get_profile(session, CLIENT)
    assert profile.total_points == 45


async def test_debit_needs_enough_coins(session):
    await wallet_service.credit(session, CLIENT, 3, "bet_win")
    with pytest.raises(wallet_service.WalletError, match="not_enough_coins"):
        await wallet_service.debit(session, CLIENT, 4, "bet_stake")
    profile = await wallet_service.debit(session, CLIENT, 3, "bet_stake")
    assert profile.coins == 0


async def test_cosmetics_are_bought_once_and_equipped(session):
    await wallet_service.credit(session, CLIENT, 80, "purchase")
    profile = await wallet_service.buy_cosmetic(session, CLIENT, "frame_gold")
    assert profile.coins == 65
    assert profile.cosmetic_frame == "frame_gold"
    assert wallet_service.look_of(profile)["owned"] == ["frame_gold"]

    profile = await wallet_service.buy_cosmetic(session, CLIENT, "hat_crown")
    assert profile.coins == 25
    assert profile.cosmetic_hat == "hat_crown"
    profile = await wallet_service.buy_cosmetic(session, CLIENT, "hair_spiky")
    assert profile.cosmetic_hair == "hair_spiky"

    with pytest.raises(wallet_service.WalletError, match="already_owned"):
        await wallet_service.buy_cosmetic(session, CLIENT, "frame_gold")
    with pytest.raises(wallet_service.WalletError, match="not_enough_coins"):
        await wallet_service.buy_cosmetic(session, CLIENT, "tiles_sunset")

    profile = await wallet_service.unequip_cosmetic(session, CLIENT, "frame")
    assert profile.cosmetic_frame == ""
    profile = await wallet_service.equip_cosmetic(session, CLIENT, "frame_gold")
    assert profile.cosmetic_frame == "frame_gold"
    profile = await wallet_service.unequip_cosmetic(session, CLIENT, "hat")
    assert profile.cosmetic_hat == ""


async def test_cosmetic_pack_unlocks_bundle(session):
    await wallet_service.credit(session, CLIENT, 50, "purchase")
    profile = await wallet_service.buy_cosmetic(session, CLIENT, "pack_ocean")
    assert profile.coins == 10
    owned = wallet_service.look_of(profile)["owned"]
    assert "pack_ocean" in owned
    assert "frame_cyan" in owned
    assert "tiles_ocean" in owned
    assert "victory_bubbles" in owned
    assert profile.cosmetic_frame == "frame_cyan"
    assert profile.cosmetic_tiles == "tiles_ocean"
    assert profile.cosmetic_victory == "victory_bubbles"
    with pytest.raises(wallet_service.WalletError, match="already_owned"):
        await wallet_service.buy_cosmetic(session, CLIENT, "pack_ocean")


async def test_invalid_client_id_is_rejected(session):
    with pytest.raises(wallet_service.WalletError):
        await wallet_service.get_profile(session, "a b")


async def test_profile_api(client):
    response = await client.get(f"/api/v1/profiles/{CLIENT}")
    assert response.status_code == 200
    assert response.json()["coins"] == 0
    assert response.json()["points_to_next_coin"] == 20

    response = await client.put(f"/api/v1/profiles/{CLIENT}", json={"nickname": "Flore", "avatar_preset": 4})
    assert response.json()["nickname"] == "Flore"
    assert response.json()["avatar_preset"] == 4

    assert (await client.get("/api/v1/profiles/x")).status_code == 422


async def test_online_solo_game_fills_the_wallet(client, monkeypatch):
    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "M")
    game = (await client.post("/api/v1/solo/games", json={**GAME, "client_id": CLIENT})).json()
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    body = (
        await client.post(
            f"/api/v1/solo/games/{game['id']}/rounds/1/submit",
            json={"answers": {"city": "Marseille", "country": "Maroc", "fruit": "Mangue"}},
        )
    ).json()
    assert body["round"]["round_score"] == 30
    assert body["wallet"] == {"coins": 1, "coins_gained": 1, "points_to_next_coin": 10, "level": 1, "level_xp": 30, "level_xp_needed": 100, "ads_removed": False, "pass_expires_at": None}


async def test_solo_game_without_profile_has_no_wallet(client, monkeypatch):
    monkeypatch.setattr(letter_service, "draw_letter", lambda eligible, used: "M")
    game = (await client.post("/api/v1/solo/games", json=GAME)).json()
    await client.post(f"/api/v1/solo/games/{game['id']}/rounds")
    body = (await client.post(f"/api/v1/solo/games/{game['id']}/rounds/1/submit", json={"answers": {}})).json()
    assert body["wallet"] is None


# ------------------------------------------------------------------ avatars


def photo_bytes(size=(640, 480), fmt="JPEG") -> bytes:
    """Fausse photo : un dégradé avec un rond, comme un visage sur un fond."""
    image = Image.new("RGB", size, (90, 140, 200))
    draw = ImageDraw.Draw(image)
    draw.ellipse((200, 100, 440, 380), fill=(235, 190, 150), outline=(60, 40, 30), width=6)
    buffer = io.BytesIO()
    image.save(buffer, format=fmt)
    return buffer.getvalue()


@pytest.fixture
def media(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "media_dir", str(tmp_path))
    return tmp_path / "avatars"


async def test_photo_becomes_a_drawn_avatar(client, media):
    response = await client.post(
        f"/api/v1/profiles/{CLIENT}/avatar", files={"photo": ("me.jpg", photo_bytes(), "image/jpeg")}
    )
    assert response.status_code == 200, response.text
    url = response.json()["avatar_url"]
    assert url.startswith(f"/media/avatars/{CLIENT}-") and url.endswith(".png")

    drawing = Image.open(media / url.rsplit("/", 1)[1])
    assert drawing.size == (256, 256)
    # Peu de couleurs : c'est un dessin, plus une photo.
    assert len(drawing.getcolors(256 * 256)) <= 12

    # Une nouvelle photo remplace l'ancienne ; un avatar dessiné retire la photo.
    second = (
        await client.post(f"/api/v1/profiles/{CLIENT}/avatar", files={"photo": ("b.png", photo_bytes(fmt="PNG"))})
    ).json()["avatar_url"]
    assert len(list(media.iterdir())) == 1
    response = await client.put(f"/api/v1/profiles/{CLIENT}", json={"avatar_preset": 3})
    assert response.json()["avatar_url"] is None
    assert not (media / second.rsplit("/", 1)[1]).exists()


async def test_bad_uploads_are_refused(client, media):
    response = await client.post(f"/api/v1/profiles/{CLIENT}/avatar", files={"photo": ("x.jpg", b"not an image")})
    assert response.status_code == 422
    assert response.json()["detail"] == "invalid_image"

    huge = b"\0" * (avatar_service.MAX_UPLOAD_BYTES + 10)
    response = await client.post(f"/api/v1/profiles/{CLIENT}/avatar", files={"photo": ("x.jpg", huge)})
    assert response.status_code == 413


async def test_three_reports_remove_a_photo(session, media):
    profile = await wallet_service.get_profile(session, CLIENT)
    profile.avatar_file = avatar_service.save_avatar(CLIENT, photo_bytes(), None)
    await session.flush()

    assert not await wallet_service.report_avatar(session, "reporter-1", CLIENT)
    assert not await wallet_service.report_avatar(session, "reporter-1", CLIENT), "one vote per player"
    assert not await wallet_service.report_avatar(session, "reporter-2", CLIENT)
    assert await wallet_service.report_avatar(session, "reporter-3", CLIENT)
    assert profile.avatar_file is None


def test_levels_follow_total_points():
    assert [wallet_service.level_threshold(n) for n in range(1, 6)] == [0, 100, 300, 600, 1000]
    assert wallet_service.level_of(0) == (1, 0, 100)
    assert wallet_service.level_of(99) == (1, 99, 100)
    assert wallet_service.level_of(100) == (2, 0, 200)
    assert wallet_service.level_of(450) == (3, 150, 300)


async def test_level_rises_with_points(session):
    update = await wallet_service.award_points(session, CLIENT, 320)
    assert (update.level, update.level_xp, update.level_xp_needed) == (3, 20, 300)
