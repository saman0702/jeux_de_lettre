"""Écrit les icônes Android et iOS à partir des grands modèles dessinés par
tool/render_app_icon_test.dart (assets/branding/mind_race_icon*.png).

    ../backend/.venv/bin/python tool/export_app_icon.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"

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


def main() -> None:
    android = Image.open(BRANDING / "mind_race_icon.png").convert("RGBA")
    for folder, px in ANDROID.items():
        out = ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        android.resize((px, px), Image.Resampling.LANCZOS).save(out, "PNG")
        print(f"Wrote {out}")

    # iOS arrondit lui-même : carré plein, sans transparence.
    ios = Image.open(BRANDING / "mind_race_icon_ios.png").convert("RGB")
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in IOS.items():
        ios.resize((px, px), Image.Resampling.LANCZOS).save(ios_dir / name, "PNG")
        print(f"Wrote {ios_dir / name}")


if __name__ == "__main__":
    main()
