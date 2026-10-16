"""Synthétise les effets sonores du jeu (la musique de menu vient de Kevin MacLeod, voir CREDITS.md).

    python3 tool/generate_sounds.py

Tout est généré de zéro (aucun échantillon tiers), donc les fichiers sont libres d'utilisation.
Sortie : assets/sounds/*.wav (mono 16 bits, 44,1 kHz).
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"

NOTES = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def freq(note: str) -> float:
    """'A4' -> 440.0, 'C#5', 'Bb3'..."""
    name, octave = note[:-1], int(note[-1])
    semitone = NOTES[name[0]] + name[1:].count("#") - name[1:].count("b")
    return 440.0 * 2 ** ((semitone + 12 * (octave - 4)) / 12)


def osc(kind: str, phase: float) -> float:
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "triangle":
        return 4 * abs(p - 0.5) - 1
    if kind == "bell":  # sinusoïde avec des harmoniques douces
        return (
            math.sin(2 * math.pi * p)
            + 0.35 * math.sin(4 * math.pi * p)
            + 0.15 * math.sin(6 * math.pi * p)
        ) / 1.5
    raise ValueError(kind)


def tone(
    f0: float,
    duration: float,
    kind: str = "sine",
    f1: float | None = None,
    attack: float = 0.005,
    decay: float = 6.0,
    volume: float = 1.0,
) -> list[float]:
    """Une note à l'attaque brève et à la décroissance exponentielle ; glissement de hauteur f0 -> f1
    facultatif.
    """
    n = int(RATE * duration)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f0 if f1 is None else f0 + (f1 - f0) * (i / n)
        phase += f / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        release = min(1.0, (n - i) / (RATE * 0.01))  # évite les clics à la fin
        out.append(osc(kind, phase) * env * release * volume)
    return out


def noise(duration: float, decay: float = 60.0, volume: float = 1.0) -> list[float]:
    rng = random.Random(7)
    n = int(RATE * duration)
    return [rng.uniform(-1, 1) * math.exp(-decay * i / RATE) * volume for i in range(n)]


def silence(duration: float) -> list[float]:
    return [0.0] * int(RATE * duration)


def mix(*tracks: tuple[float, list[float]]) -> list[float]:
    """Mixe ensemble des pistes (début_en_secondes, échantillons)."""
    length = max(int(start * RATE) + len(samples) for start, samples in tracks)
    out = [0.0] * length
    for start, samples in tracks:
        offset = int(start * RATE)
        for i, s in enumerate(samples):
            out[offset + i] += s
    return out


def seq(*parts: list[float]) -> list[float]:
    return [s for part in parts for s in part]


def write(name: str, samples: list[float], peak: float = 0.8) -> None:
    top = max(abs(s) for s in samples) or 1.0
    scale = peak / top
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))
    print(f"{name}.wav  {len(samples) / RATE:.2f}s")


def sound_effects() -> None:
    write("tap", tone(700, 0.07, "sine", f1=1200, decay=40), peak=0.5)
    write("countdown", tone(freq("A5"), 0.18, "bell", decay=14), peak=0.6)
    write("tick", mix((0, noise(0.03, decay=150, volume=0.6)), (0, tone(1800, 0.03, decay=120))), peak=0.45)
    write("reveal", seq(*[tone(freq(n), 0.045, "triangle", decay=30)
                          for n in ["C5", "E5", "G5", "C6", "E6", "G6"]]), peak=0.5)


def variant_effects() -> None:
    """Les effets fréquents existent en plusieurs versions, jouées à tour de rôle, pour que le jeu ne
    répète pas toujours exactement le même son.
    """
    # GO ! — trois courtes fanfares.
    for i, (arp, top) in enumerate([
        (["C5", "E5", "G5"], ["C6", "G5"]),
        (["D5", "F#5", "A5"], ["D6", "A5"]),
        (["G4", "B4", "D5", "G5"], ["G5", "D6"]),
    ], start=1):
        write(f"go_{i}", mix(
            *[(j * 0.06, tone(freq(n), 0.25, "square", decay=12, volume=0.4)) for j, n in enumerate(arp)],
            *[(0.06 * len(arp), tone(freq(n), 0.5, "bell", decay=5, volume=v)) for n, v in zip(top, (1, 0.6))],
        ))
    # Bonne réponse — carillons montants sur différents intervalles.
    for i, (a, b) in enumerate([("E6", "B6"), ("C6", "G6"), ("G6", "D7")], start=1):
        write(f"valid_{i}", mix((0, tone(freq(a), 0.2, "bell", decay=12)),
                                (0.08, tone(freq(b), 0.3, "bell", decay=10))), peak=0.6)
    # Mauvaise réponse — un « bwop » doux et un double « buzz ».
    write("invalid_1", tone(260, 0.28, "square", f1=150, decay=8, volume=0.5), peak=0.4)
    write("invalid_2", seq(tone(220, 0.1, "triangle", decay=20), tone(170, 0.18, "triangle", f1=130, decay=12)), peak=0.4)
    # Points — bruits de pièces.
    write("points_1", seq(tone(freq("B5"), 0.07, "square", decay=10, volume=0.5),
                          tone(freq("E6"), 0.3, "square", decay=9, volume=0.5)), peak=0.45)
    write("points_2", seq(*[tone(freq(n), 0.05, "square", decay=14, volume=0.5) for n in ["C6", "E6", "G6"]],
                          tone(freq("C7"), 0.25, "bell", decay=9)), peak=0.45)
    # Victoire — deux fanfares.
    fanfare = [("C5", 0.0), ("E5", 0.12), ("G5", 0.24), ("C6", 0.36), ("G5", 0.6), ("C6", 0.72)]
    write("victory_1", mix(
        *[(t, tone(freq(n), 0.3, "square", decay=6, volume=0.35)) for n, t in fanfare],
        *[(0.9, tone(freq(n), 1.2, "bell", decay=2.5, volume=0.5)) for n in ["C5", "E5", "G5", "C6"]],
    ))
    fanfare2 = [("G4", 0.0), ("G4", 0.1), ("G4", 0.2), ("C5", 0.32), ("E5", 0.5), ("D5", 0.62), ("G5", 0.74)]
    write("victory_2", mix(
        *[(t, tone(freq(n), 0.25, "triangle", decay=6, volume=0.5)) for n, t in fanfare2],
        *[(0.95, tone(freq(n), 1.2, "bell", decay=2.4, volume=0.5)) for n in ["G4", "B4", "D5", "G5"]],
    ))


def typing_sounds() -> None:
    """« Toc » boisé et doux quand une tuile-lettre se pose, sur trois hauteurs pour qu'une frappe
    rapide ne sonne pas mécanique.
    """
    for i, pitch in enumerate([880, 990, 1110], start=1):
        write(
            f"key_{i}",
            mix(
                (0, tone(pitch, 0.06, "triangle", f1=pitch * 0.8, decay=55)),
                (0, noise(0.012, decay=400, volume=0.25)),
            ),
            peak=0.35,
        )
    write("erase", tone(620, 0.08, "triangle", f1=380, decay=35), peak=0.3)
    write("match", mix((0, tone(freq("G6"), 0.18, "bell", decay=16)),
                       (0.05, tone(freq("D7"), 0.22, "bell", decay=14, volume=0.7))), peak=0.4)
    write("finish", mix(
        (0, tone(300, 0.28, "sine", f1=1400, decay=6, volume=0.6)),
        (0.18, tone(freq("C6"), 0.25, "bell", decay=10)),
    ), peak=0.5)
    write("hint_open", seq(*[tone(freq(n), 0.06, "bell", decay=22)
                             for n in ["E6", "G6", "B6", "E7"]]), peak=0.4)


if __name__ == "__main__":
    sound_effects()
    variant_effects()
    typing_sounds()
