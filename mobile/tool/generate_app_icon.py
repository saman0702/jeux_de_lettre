#!/usr/bin/env python3
"""Génère l'icône Mind Race (fond blanc, bordure jaune, MR violet + motifs)."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "assets" / "fonts" / "LilitaOne.ttf"
MASTER = ROOT / "assets" / "branding" / "letter_race_icon.png"

# AppColors
WHITE = (255, 255, 255, 255)
PURPLE = (108, 60, 225, 255)  # #6C3CE1
ORANGE = (255, 138, 61, 255)  # #FF8A3D
YELLOW = (255, 201, 60, 255)  # #FFC93C
GREEN = (46, 204, 113, 255)  # #2ECC71
RED = (255, 90, 95, 255)  # #FF5A5F
CYAN = (45, 212, 191, 255)  # #2DD4BF
PINK = (255, 122, 178, 255)  # #FF7AB2
INK = (38, 22, 72, 255)

# Initiales colorées (autour du LR)
DECO_COLORS = {
    "E": GREEN,
    "B": PURPLE,
    "S": ORANGE,
    "J": RED,
    "A": YELLOW,
    "C": CYAN,
    "M": PINK,
    "P": ORANGE,
}

ANDROID = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

IOS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def _font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), size=size)


def _draw_outlined_text(
    base: Image.Image,
    text: str,
    xy: tuple[float, float],
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int],
    stroke: int,
    shadow: tuple[int, int] | None = None,
) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x, y = xy
    if shadow:
        sx, sy = shadow
        draw.text((x + sx, y + sy), text, font=font, fill=INK)
    draw.text(
        (x, y),
        text,
        font=font,
        fill=fill,
        stroke_width=stroke,
        stroke_fill=outline,
    )
    base.alpha_composite(layer)


def _star_points(
    cx: float, cy: float, outer: float, inner: float, points: int = 5, rotation: float = 0
) -> list[tuple[float, float]]:
    coords: list[tuple[float, float]] = []
    for i in range(points * 2):
        angle = math.radians(rotation - 90 + i * 180 / points)
        r = outer if i % 2 == 0 else inner
        coords.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    return coords


def _draw_star(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    size: float,
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    rotation: float = 0,
) -> None:
    pts = _star_points(cx, cy, size, size * 0.42, rotation=rotation)
    draw.polygon(pts, fill=fill, outline=outline)


def _draw_medal(
    base: Image.Image,
    cx: float,
    cy: float,
    size: float,
    metal: tuple[int, int, int, int],
    ribbon: tuple[int, int, int, int],
) -> None:
    """Petite médaille éducative (ruban + disque)."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    r = size * 0.38
    # Ruban en V
    top = cy - size * 0.55
    draw.polygon(
        [
            (cx - size * 0.22, top),
            (cx - size * 0.05, cy - r * 0.2),
            (cx - size * 0.14, cy - r * 0.55),
        ],
        fill=ribbon,
    )
    draw.polygon(
        [
            (cx + size * 0.22, top),
            (cx + size * 0.05, cy - r * 0.2),
            (cx + size * 0.14, cy - r * 0.55),
        ],
        fill=ribbon,
    )
    # Disque
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=metal, outline=YELLOW, width=max(1, int(size * 0.08)))
    # Étoile centrale
    _draw_star(draw, cx, cy, r * 0.45, WHITE)
    base.alpha_composite(layer)


def _draw_trophy(
    base: Image.Image,
    cx: float,
    cy: float,
    size: float,
    cup: tuple[int, int, int, int],
) -> None:
    """Petit trophée de victoire."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    # Coupe
    top = cy - size * 0.35
    bottom = cy + size * 0.05
    draw.pieslice(
        [cx - size * 0.32, top, cx + size * 0.32, bottom + size * 0.25],
        0,
        180,
        fill=cup,
    )
    draw.rectangle(
        [cx - size * 0.28, top, cx + size * 0.28, top + size * 0.12],
        fill=cup,
    )
    # Anses
    stroke = max(2, int(size * 0.1))
    draw.arc(
        [cx - size * 0.48, top + size * 0.02, cx - size * 0.18, top + size * 0.38],
        90,
        270,
        fill=cup,
        width=stroke,
    )
    draw.arc(
        [cx + size * 0.18, top + size * 0.02, cx + size * 0.48, top + size * 0.38],
        -90,
        90,
        fill=cup,
        width=stroke,
    )
    # Pied
    stem_w = size * 0.1
    draw.rectangle(
        [cx - stem_w / 2, bottom, cx + stem_w / 2, cy + size * 0.28],
        fill=cup,
    )
    draw.rounded_rectangle(
        [cx - size * 0.22, cy + size * 0.26, cx + size * 0.22, cy + size * 0.4],
        radius=size * 0.04,
        fill=cup,
    )
    base.alpha_composite(layer)


def _draw_spark(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    size: float,
    fill: tuple[int, int, int, int],
    rotation: float = 0,
) -> None:
    """Éclat / confetti en croix (effet victoire)."""
    pts = _star_points(cx, cy, size, size * 0.22, points=4, rotation=rotation)
    draw.polygon(pts, fill=fill)


def _paste_letter(
    base: Image.Image,
    letter: str,
    cx: float,
    cy: float,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int],
    stroke: int,
    angle: float,
    font_size: int,
) -> None:
    tw = font.getlength(letter)
    pad = stroke * 4
    tmp = Image.new("RGBA", (int(tw + pad), int(font_size + pad)), (0, 0, 0, 0))
    td = ImageDraw.Draw(tmp)
    td.text(
        (stroke * 2, stroke),
        letter,
        font=font,
        fill=fill,
        stroke_width=stroke,
        stroke_fill=YELLOW,
    )
    rotated = tmp.rotate(-angle * 180, expand=True, resample=Image.Resampling.BICUBIC)
    px = int(cx - rotated.width / 2)
    py = int(cy - rotated.height / 2)
    base.alpha_composite(rotated, (px, py))


def render(size: int = 1024) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Fond blanc + fine bordure jaune (coins arrondis type icône).
    margin = size * 0.02
    radius = size * 0.22
    border = max(2, int(size * 0.012))
    box = [margin, margin, size - margin - 1, size - margin - 1]
    draw.rounded_rectangle(box, radius=radius, fill=YELLOW)
    inner = [
        margin + border,
        margin + border,
        size - margin - border - 1,
        size - margin - border - 1,
    ]
    draw.rounded_rectangle(inner, radius=radius * 0.85, fill=WHITE)

    cx, cy = size / 2, size / 2 - size * 0.02
    lr_size = int(size * 0.42)
    deco_size = int(size * 0.12)
    tiny_size = int(size * 0.075)
    font_lr = _font(lr_size)
    font_deco = _font(deco_size)
    font_tiny = _font(tiny_size)

    lw = font_lr.getlength("M")
    rw = font_lr.getlength("R")
    gap = size * 0.01
    total = lw + gap + rw
    left = cx - total / 2
    baseline = cy - lr_size * 0.55

    shadow = (int(size * 0.01), int(size * 0.012))
    stroke_lr = max(2, int(size * 0.01))
    stroke_deco = max(1, int(size * 0.006))
    stroke_tiny = max(1, int(size * 0.004))

    # Motifs d'arrière-plan (sous les lettres) — plus petits que les initiales.
    motifs_back = [
        ("star", (-0.34, -0.30), size * 0.035, YELLOW, 12),
        ("star", (0.32, -0.28), size * 0.028, ORANGE, -18),
        ("spark", (0.02, -0.34), size * 0.022, PINK, 20),
        ("spark", (-0.36, 0.12), size * 0.018, CYAN, 35),
        ("star", (0.36, 0.08), size * 0.024, GREEN, 8),
        ("spark", (-0.08, 0.32), size * 0.016, RED, 10),
        ("star", (0.28, 0.30), size * 0.022, PURPLE, -25),
        ("spark", (-0.30, 0.28), size * 0.014, YELLOW, 40),
    ]
    for kind, (dx, dy), s, color, rot in motifs_back:
        mx, my = cx + dx * size, cy + dy * size
        if kind == "star":
            _draw_star(draw, mx, my, s, color, rotation=rot)
        else:
            _draw_spark(draw, mx, my, s, color, rotation=rot)

    # Médaille et trophée (petits, éducatif / victoire).
    _draw_medal(img, cx + size * 0.34, cy - size * 0.08, size * 0.09, YELLOW, RED)
    _draw_trophy(img, cx - size * 0.34, cy + size * 0.18, size * 0.1, ORANGE)

    # MR central.
    _draw_outlined_text(
        img, "M", (left, baseline), font_lr, PURPLE, YELLOW, stroke_lr, shadow
    )
    _draw_outlined_text(
        img,
        "R",
        (left + lw + gap, baseline),
        font_lr,
        PURPLE,
        YELLOW,
        stroke_lr,
        shadow,
    )

    # Initiales principales (taille actuelle).
    decos = [
        ("E", (-0.30, -0.22), -0.25),
        ("B", (-0.36, 0.06), 0.18),
        ("S", (-0.20, 0.22), -0.12),
        ("J", (0.18, -0.18), 0.22),
        ("A", (0.24, 0.18), -0.18),
    ]
    for letter, (dx, dy), angle in decos:
        _paste_letter(
            img,
            letter,
            cx + dx * size,
            cy + dy * size,
            font_deco,
            DECO_COLORS[letter],
            stroke_deco,
            angle,
            deco_size,
        )

    # Autres lettres, encore plus petites.
    tinies = [
        ("C", (0.08, -0.28), 0.15, CYAN),
        ("M", (-0.08, 0.26), -0.2, PINK),
        ("P", (0.34, 0.20), 0.1, ORANGE),
    ]
    for letter, (dx, dy), angle, color in tinies:
        _paste_letter(
            img,
            letter,
            cx + dx * size,
            cy + dy * size,
            font_tiny,
            color,
            stroke_tiny,
            angle,
            tiny_size,
        )

    # Motifs devant / autour (confettis et étoiles plus nets).
    motifs_front = [
        ("star", (0.12, 0.22), size * 0.02, YELLOW, 0),
        ("spark", (-0.16, -0.30), size * 0.015, GREEN, 25),
        ("spark", (0.22, -0.30), size * 0.014, RED, -30),
        ("star", (-0.02, -0.20), size * 0.016, CYAN, 15),
    ]
    for kind, (dx, dy), s, color, rot in motifs_front:
        mx, my = cx + dx * size, cy + dy * size
        if kind == "star":
            _draw_star(draw, mx, my, s, color, rotation=rot)
        else:
            _draw_spark(draw, mx, my, s, color, rotation=rot)

    # Trait jaune sous LR.
    line_w = size * 0.42
    line_h = max(3, int(size * 0.012))
    y_line = cy + size * 0.28
    draw.rounded_rectangle(
        [cx - line_w / 2, y_line, cx + line_w / 2, y_line + line_h],
        radius=line_h,
        fill=YELLOW,
    )
    return img


def main() -> None:
    master = render(1024)
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    master.save(MASTER, "PNG")
    print(f"Wrote {MASTER}")

    for folder, px in ANDROID.items():
        out = ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        master.resize((px, px), Image.Resampling.LANCZOS).save(out, "PNG")
        print(f"Wrote {out}")

    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in IOS.items():
        out = ios_dir / name
        # iOS 1024 doit être opaque (pas d'alpha).
        frame = master.resize((px, px), Image.Resampling.LANCZOS)
        if px >= 1024:
            opaque = Image.new("RGB", frame.size, (255, 255, 255))
            opaque.paste(frame, mask=frame.split()[-1])
            opaque.save(out, "PNG")
        else:
            frame.save(out, "PNG")
        print(f"Wrote {out}")


if __name__ == "__main__":
    main()
