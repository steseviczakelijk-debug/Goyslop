"""Synthesise the placeholder sound effects and music into assets/audio/.

Run from the repo root:  python3 tools/make_sounds.py
Everything here is generated from scratch, so there are no licences to track.
Replace any file with a recorded sound of the same name to upgrade it.
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path("assets/audio")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def sweep(f0, f1, seconds):
    """Sine whose pitch glides from f0 to f1."""
    x = t(seconds)
    freq = f0 * (f1 / f0) ** (x / seconds)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def decay(n, rate):
    return np.exp(-np.arange(n) / RATE * rate)


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def lowpass(x, strength):
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += (v - acc) * strength
        out[i] = acc
    return out


def bell(freq, seconds, rate=9.0):
    x = t(seconds)
    tone = np.sin(2 * np.pi * freq * x) + 0.4 * np.sin(2 * np.pi * freq * 2.0 * x) + 0.2 * np.sin(2 * np.pi * freq * 3.01 * x)
    return tone * decay(len(x), rate)


def pluck(freq, seconds, bright=0.5):
    """Karplus-Strong plucked string: sounds like a lute or harp."""
    n = int(RATE * seconds)
    period = max(2, int(RATE / freq))
    buf = lowpass(rng.uniform(-1, 1, period), bright)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.498 * (buf[i % period] + buf[(i + 1) % period])
    return out


def mix(length, parts):
    """parts: (start_seconds, samples, gain). Returns a buffer of `length` seconds."""
    out = np.zeros(int(RATE * length))
    for start, samples, gain in parts:
        i = int(RATE * start)
        seg = samples[: len(out) - i]
        out[i : i + len(seg)] += seg * gain
    return out


def save(name, samples, peak=0.8):
    samples = samples / max(1e-9, np.max(np.abs(samples))) * peak
    fade = min(len(samples) // 2, int(RATE * 0.004))
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((samples * 32767).astype(np.int16).tobytes())
    print(f"{name}.wav  {len(samples) / RATE:.2f}s")


NOTE = {"A2": 110.0, "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0, "A3": 220.0,
        "Bb3": 233.08, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "F#4": 369.99, "G4": 392.0,
        "A4": 440.0, "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.0}


def effects():
    n = lambda s: len(t(s))
    save("shoot", sweep(1100, 350, 0.07) * decay(n(0.07), 40) + lowpass(noise(0.07), 0.5) * decay(n(0.07), 60) * 0.6, 0.5)
    save("hit", sweep(220, 90, 0.06) * decay(n(0.06), 45) + lowpass(noise(0.06), 0.3) * decay(n(0.06), 70))
    save("kill", sweep(620, 140, 0.11) * decay(n(0.11), 28) + lowpass(noise(0.11), 0.4) * decay(n(0.11), 50) * 0.5)
    save("lost", np.sign(sweep(330, 110, 0.18)) * 0.5 * decay(n(0.18), 14) + sweep(330, 110, 0.18) * decay(n(0.18), 14))
    save("grow", bell(1318.5, 0.08, 45), 0.5)
    save("gate_good", mix(0.5, [(0.0, bell(NOTE["E5"], 0.4), 1.0), (0.09, bell(NOTE["A5"], 0.4), 1.0)]))
    save("gate_bad", lowpass(np.sign(sweep(160, 80, 0.3)), 0.25) * decay(n(0.3), 9))
    save("stomp", sweep(85, 38, 0.28) * decay(n(0.28), 13) + lowpass(noise(0.28), 0.08) * decay(n(0.28), 20) * 1.5)
    save("boss_dead", sweep(140, 30, 1.0) * decay(n(1.0), 3.5) + lowpass(noise(1.0), 0.1) * decay(n(1.0), 4.0) * 1.5)
    save("coin", mix(0.25, [(0.0, bell(1568.0, 0.2, 18), 1.0), (0.05, bell(2093.0, 0.2, 18), 0.8)]), 0.6)
    save("click", bell(880.0, 0.06, 60), 0.5)
    win = [("D4", 0.0), ("F#4", 0.12), ("A4", 0.24), ("D5", 0.36), ("A4", 0.54), ("D5", 0.66)]
    save("win", mix(1.8, [(s, pluck(NOTE[k], 1.1, 0.7) + bell(NOTE[k], 1.1) * 0.5, 1.0) for k, s in win]))
    lose = [("D4", 0.0), ("C4", 0.22), ("Bb3", 0.44), ("A3", 0.66)]
    save("lose", mix(1.8, [(s, pluck(NOTE[k], 1.1, 0.35), 1.0) for k, s in lose]))


def music():
    """Eight bars of plucked-string arpeggios in D dorian, built to loop cleanly."""
    eighth = 0.22
    bar = eighth * 6
    bars = [
        (["D3", "A3", "D4", "F4", "D4", "A3"], ["D5", "F5"]),
        (["C3", "G3", "C4", "E4", "C4", "G3"], ["E5", "G5"]),
        (["D3", "A3", "D4", "F4", "D4", "A3"], ["F5", "A5"]),
        (["A2", "E3", "A3", "C4", "A3", "E3"], ["E5", "C5"]),
        (["F3", "C4", "F4", "A4", "F4", "C4"], ["A5", "F5"]),
        (["C3", "G3", "C4", "E4", "C4", "G3"], ["G5", "E5"]),
        (["D3", "A3", "D4", "F4", "E4", "C4"], ["F5", "E5"]),
        (["D3", "A3", "D4", "A3", "D4", "A3"], ["D5", "D5"]),
    ]
    total = bar * len(bars)
    length = int(RATE * total)
    out = np.zeros(length)

    def add(start, samples, gain):
        # Wrap tails around the end so the loop point is inaudible.
        idx = (int(RATE * start) + np.arange(len(samples))) % length
        np.add.at(out, idx, samples * gain)

    drum = sweep(110, 55, 0.18) * decay(len(t(0.18)), 22)
    for b, (arp, tune) in enumerate(bars):
        for i, k in enumerate(arp):
            add(b * bar + i * eighth, pluck(NOTE[k], 1.2, 0.45), 0.5 if i else 0.75)
        for i, k in enumerate(tune):
            add(b * bar + i * 3 * eighth, pluck(NOTE[k], 1.4, 0.6), 0.55)
        add(b * bar, drum, 0.5)
        add(b * bar + 3 * eighth, drum, 0.3)
    out = out / np.max(np.abs(out)) * 0.7
    with wave.open(str(OUT / "music.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((out * 32767).astype(np.int16).tobytes())
    print(f"music.wav  {total:.2f}s")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    effects()
    music()
