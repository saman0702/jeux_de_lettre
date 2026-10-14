"""Synthesize the game's sound effects and menu music.

    python3 tool/generate_sounds.py

Everything is generated from scratch (no third-party samples), so the files
are free to use. Output: assets/sounds/*.wav (16-bit mono, 44.1 kHz).
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
    if kind == "bell":  # sine with soft harmonics
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
    """A note with a short attack and exponential decay; optional pitch glide f0 -> f1."""
    n = int(RATE * duration)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f0 if f1 is None else f0 + (f1 - f0) * (i / n)
        phase += f / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        release = min(1.0, (n - i) / (RATE * 0.01))  # avoid clicks at the end
        out.append(osc(kind, phase) * env * release * volume)
    return out


def noise(duration: float, decay: float = 60.0, volume: float = 1.0) -> list[float]:
    rng = random.Random(7)
    n = int(RATE * duration)
    return [rng.uniform(-1, 1) * math.exp(-decay * i / RATE) * volume for i in range(n)]


def silence(duration: float) -> list[float]:
    return [0.0] * int(RATE * duration)


def mix(*tracks: tuple[float, list[float]]) -> list[float]:
    """Mix (start_seconds, samples) tracks together."""
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
    write(
        "go",
        mix(
            *[(i * 0.06, tone(freq(n), 0.25, "square", decay=12, volume=0.4))
              for i, n in enumerate(["C5", "E5", "G5"])],
            (0.18, tone(freq("C6"), 0.5, "bell", decay=5)),
            (0.18, tone(freq("G5"), 0.5, "bell", decay=5, volume=0.6)),
        ),
    )
    write("tick", mix((0, noise(0.03, decay=150, volume=0.6)), (0, tone(1800, 0.03, decay=120))), peak=0.45)
    write("reveal", seq(*[tone(freq(n), 0.045, "triangle", decay=30)
                          for n in ["C5", "E5", "G5", "C6", "E6", "G6"]]), peak=0.5)
    write("valid", mix((0, tone(freq("E6"), 0.2, "bell", decay=12)),
                       (0.08, tone(freq("B6"), 0.3, "bell", decay=10))), peak=0.6)
    write("invalid", tone(260, 0.28, "square", f1=150, decay=8, volume=0.5), peak=0.4)
    write("points", seq(tone(freq("B5"), 0.07, "square", decay=10, volume=0.5),
                        tone(freq("E6"), 0.3, "square", decay=9, volume=0.5)), peak=0.45)
    fanfare = [("C5", 0.0), ("E5", 0.12), ("G5", 0.24), ("C6", 0.36), ("G5", 0.6), ("C6", 0.72)]
    write(
        "victory",
        mix(
            *[(t, tone(freq(n), 0.3, "square", decay=6, volume=0.35)) for n, t in fanfare],
            *[(0.9, tone(freq(n), 1.2, "bell", decay=2.5, volume=0.5)) for n in ["C5", "E5", "G5", "C6"]],
        ),
    )


def menu_music() -> None:
    """A short, cheerful loop: 8 bars at 112 BPM, loops seamlessly."""
    beat = 60 / 112
    bar = 4 * beat
    chords = ["C", "A", "F", "G", "C", "A", "F", "G"]
    roots = {"C": "C3", "A": "A2", "F": "F2", "G": "G2"}
    arps = {
        "C": ["C5", "E5", "G5", "E5"],
        "A": ["A4", "C5", "E5", "C5"],
        "F": ["F4", "A4", "C5", "A4"],
        "G": ["G4", "B4", "D5", "B4"],
    }
    melody = [
        ("E5", 0, 1), ("G5", 1, 1), ("A5", 2, 2),
        ("G5", 4, 1), ("E5", 5, 1), ("C5", 6, 2),
        ("F5", 8, 1), ("A5", 9, 1), ("C6", 10, 1), ("A5", 11, 1),
        ("G5", 12, 3), ("D5", 15, 1),
        ("E5", 16, 1), ("G5", 17, 1), ("C6", 18, 2),
        ("B5", 20, 1), ("A5", 21, 1), ("E5", 22, 2),
        ("F5", 24, 1), ("E5", 25, 1), ("D5", 26, 1), ("F5", 27, 1),
        ("E5", 28, 2), ("D5", 30, 2),
    ]
    tracks = []
    for i, chord in enumerate(chords):
        start = i * bar
        for b in range(4):
            tracks.append((start + b * beat, tone(freq(roots[chord]), beat * 0.9, "triangle", decay=3, volume=0.55)))
            for s, note in enumerate(arps[chord]):
                t = start + b * beat + s * beat / 4
                tracks.append((t, tone(freq(note), beat / 4, "square", decay=18, volume=0.08)))
        tracks.append((start, noise(0.05, decay=80, volume=0.12)))
        tracks.append((start + 2 * beat, noise(0.05, decay=80, volume=0.08)))
    for note, at, length in melody:
        tracks.append((at * beat, tone(freq(note), length * beat * 0.95, "bell", decay=2.2, volume=0.45)))

    samples = mix(*tracks)[: int(8 * bar * RATE)]  # cut exactly at the loop point
    write("menu_music", samples, peak=0.35)


if __name__ == "__main__":
    sound_effects()
    menu_music()
