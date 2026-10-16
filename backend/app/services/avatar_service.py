"""Photos d'avatar : la photo envoyée est recadrée puis transformée en dessin avant d'être partagée.

La transformation est faite ici, côté serveur : aucune photo brute n'est jamais stockée ni montrée
aux autres joueurs, même si l'appli était modifiée.
"""

import io
import secrets
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps, UnidentifiedImageError

from app.core.config import settings

AVATAR_SIZE = 256
MAX_UPLOAD_BYTES = 6 * 1024 * 1024
# Refuse les images gigantesques avant même de les décoder.
MAX_PIXELS = 40_000_000
INK = (38, 22, 72)


class AvatarError(Exception):
    def __init__(self, code: str, status_code: int = 422):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


def avatars_dir() -> Path:
    path = Path(settings.media_dir) / "avatars"
    path.mkdir(parents=True, exist_ok=True)
    return path


def cartoonize(data: bytes) -> Image.Image:
    """Recadre en carré et donne un rendu de dessin animé : aplats de couleurs et contours encrés."""
    if len(data) > MAX_UPLOAD_BYTES:
        raise AvatarError("file_too_large", 413)
    try:
        image = Image.open(io.BytesIO(data))
        if image.width * image.height > MAX_PIXELS:
            raise AvatarError("file_too_large", 413)
        image = ImageOps.exif_transpose(image).convert("RGB")
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise AvatarError("invalid_image") from None

    image = ImageOps.fit(image, (AVATAR_SIZE, AVATAR_SIZE), Image.Resampling.LANCZOS, centering=(0.5, 0.4))

    # Aplats : lissage qui garde les bords, puis peu de couleurs, bien saturées.
    smooth = image.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.SMOOTH_MORE)
    flat = smooth.quantize(colors=10, method=Image.Quantize.MEDIANCUT).convert("RGB")
    flat = ImageEnhance.Color(flat).enhance(1.35)
    flat = ImageEnhance.Brightness(flat).enhance(1.05)

    # Contours : les bords marqués de l'image lissée deviennent un trait d'encre ; les points isolés
    # (grain de la photo) sont retirés.
    edges = smooth.convert("L").filter(ImageFilter.GaussianBlur(1.5)).filter(ImageFilter.FIND_EDGES)
    edges = edges.point(lambda v: 255 if v > 22 else 0).filter(ImageFilter.MedianFilter(3))
    edges = edges.filter(ImageFilter.MaxFilter(3))
    # FIND_EDGES marque toujours le bord de l'image : on l'efface.
    mask = Image.new("L", edges.size, 0)
    mask.paste(edges.crop((3, 3, AVATAR_SIZE - 3, AVATAR_SIZE - 3)), (3, 3))
    return Image.composite(Image.new("RGB", flat.size, INK), flat, mask)


def save_avatar(client_id: str, data: bytes, previous: str | None) -> str:
    """Enregistre le dessin et renvoie le nom du fichier ; l'ancien avatar est supprimé."""
    drawing = cartoonize(data)
    name = f"{client_id}-{secrets.token_hex(4)}.png"
    drawing.save(avatars_dir() / name, format="PNG", optimize=True)
    if previous:
        delete_avatar(previous)
    return name


def delete_avatar(name: str) -> None:
    path = avatars_dir() / Path(name).name
    path.unlink(missing_ok=True)
