#!/usr/bin/env python3
"""Synthesises the sound a video is mixed with: a soft ambient bed and a few
effects. Nothing is recorded or downloaded; every sample is arithmetic.

The bed is as long as the longest video it goes under, and fades itself out
at the end: a bed that is too short fades out early, which is graceful; one
that is too long is cut, which is not.

    tool/.venv/bin/python tool/sound.py example/assets/sound

Seeded, so running it again writes the same files.
"""

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 48000
rng = np.random.default_rng(7)


def write(path, signal):
    peak = np.max(np.abs(signal))
    pcm = (signal / peak * 0.95 * 32767).astype("<i2") if peak > 0 else signal.astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def t_of(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x, cutoff):
    """One-pole low-pass, run forwards."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        out[i] = acc
    return out


def fade(x, seconds_in, seconds_out):
    n_in, n_out = int(seconds_in * RATE), int(seconds_out * RATE)
    env = np.ones_like(x)
    if n_in:
        env[:n_in] = np.linspace(0, 1, n_in) ** 2
    if n_out:
        env[-n_out:] = np.linspace(1, 0, n_out) ** 2
    return x * env


def bed(seconds=37):
    """A warm pad over a slow four-chord loop (Am, F, C, G), with a faint
    pulse: sparse enough to sit under a voice."""
    t = t_of(seconds)
    chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]  # midi
    beat = 6.0  # seconds a chord lasts
    out = np.zeros_like(t)
    for i in range(int(np.ceil(seconds / beat))):
        notes = chords[i % 4]
        start, end = i * beat, min(seconds, (i + 1) * beat + 1.5)
        seg = (t >= start) & (t < end)
        local = t[seg] - start
        env = np.minimum(local / 1.8, 1) * np.minimum((end - t[seg]) / 1.5, 1)
        for n in notes:
            f = 440 * 2 ** ((n - 69) / 12)
            for detune in (-0.12, 0.0, 0.12):
                out[seg] += env * np.sin(2 * np.pi * (f + detune) * t[seg]) * 0.12
            out[seg] += env * np.sin(2 * np.pi * f * 2 * t[seg]) * 0.025
        # A soft low root an octave down.
        f0 = 440 * 2 ** ((notes[0] - 12 - 69) / 12)
        out[seg] += env * np.sin(2 * np.pi * f0 * t[seg]) * 0.18
    # A gentle pulse, two beats a second apart in 8ths, very quiet.
    pulse = (np.sin(2 * np.pi * 0.5 * t) * 0.5 + 0.5) ** 3
    out *= 0.85 + 0.15 * pulse
    return fade(lowpass(out, 1800), 3, 5)


def whoosh(seconds=0.9):
    t = t_of(seconds)
    noise = rng.standard_normal(len(t))
    # A band that sweeps up then down.
    sweep = 400 + 3200 * np.sin(np.pi * t / seconds) ** 2
    out = np.empty_like(t)
    lo = hi = 0.0
    for i, v in enumerate(noise):
        a = np.exp(-2 * np.pi * sweep[i] / RATE)
        b = np.exp(-2 * np.pi * (sweep[i] * 0.25) / RATE)
        lo = (1 - a) * v + a * lo
        hi = (1 - b) * v + b * hi
        out[i] = lo - hi
    env = np.sin(np.pi * t / seconds) ** 1.5
    return out * env


def pop(seconds=0.25):
    t = t_of(seconds)
    f = 520 + 380 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 22)


def tick(seconds=0.12):
    t = t_of(seconds)
    return np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 60) * 0.7


def swell(seconds=2.2):
    """A rising shimmer to open a section."""
    t = t_of(seconds)
    out = sum(np.sin(2 * np.pi * f * t) for f in (220, 330, 440, 660, 880))
    return out * (t / seconds) ** 2 * np.exp(-((t - seconds) ** 2) * 0)


def band(x, lo, hi):
    """Brick-wall band-pass by FFT: fast, and good enough for noise."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    spec[(freqs < lo) | (freqs > hi)] = 0
    return np.fft.irfft(spec, len(x))


def shaped_noise(seconds, gen, slope, lo, hi):
    """Noise whose power falls as 1/f**slope between lo and hi."""
    n = int(seconds * RATE)
    spec = np.fft.rfft(gen.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    gain = np.zeros_like(freqs)
    inside = (freqs >= lo) & (freqs <= hi)
    gain[inside] = (freqs[inside] / lo) ** (-slope / 2)
    return np.fft.irfft(spec * gain, n)


def rain(seconds=60):
    """Steady rain: a wide hiss, a lower body of it, and the pitter of single
    drops on leaves. The ends are crossfaded so it loops without a seam."""
    gen = np.random.default_rng(11)
    t = t_of(seconds)
    hiss = shaped_noise(seconds, gen, 0.6, 600, 9000)
    body = shaped_noise(seconds, gen, 1.2, 120, 900)
    out = hiss / np.std(hiss) * 0.55 + body / np.std(body) * 0.35
    # Single drops: short, bright, at random.
    drops = np.zeros_like(t)
    for at in gen.uniform(0, seconds - 0.05, int(seconds * 90)):
        i = int(at * RATE)
        n = int(0.012 * RATE)
        k = np.arange(n) / RATE
        drops[i:i + n] += np.sin(2 * np.pi * gen.uniform(2200, 5200) * k) * np.exp(-k * 520) * gen.uniform(0.1, 0.5)
    out = out + drops * 0.5
    # A slow swell in the downpour, so it breathes.
    out *= 0.85 + 0.15 * np.sin(2 * np.pi * t / 9.0 + 1.0)
    # Make it loop: fold the tail over the head.
    xf = int(1.5 * RATE)
    ramp = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * ramp + out[-xf:] * (1 - ramp)
    return out[:-xf]


def thunder(seconds=7.0):
    """A crack, then a long low roll that wobbles as it dies away."""
    gen = np.random.default_rng(23)
    t = t_of(seconds)
    crack = band(gen.standard_normal(len(t)), 300, 5000) * np.exp(-t * 18) * 1.0
    roll = shaped_noise(seconds, gen, 2.0, 25, 220)
    roll = roll / np.max(np.abs(roll))
    env = (1 - np.exp(-t * 14)) * np.exp(-t * 0.65)
    wobble = 0.7 + 0.3 * np.sin(2 * np.pi * 3.1 * t + np.sin(2 * np.pi * 0.7 * t) * 3)
    out = crack * 0.7 + roll * env * wobble * 2.4
    return fade(out, 0, 1.5)


def crackle(seconds=8.0):
    """A fire: a low rustle under sharp snaps at random, loopable."""
    gen = np.random.default_rng(31)
    t = t_of(seconds)
    rustle = shaped_noise(seconds, gen, 1.0, 80, 2500)
    out = rustle / np.std(rustle) * 0.25 * (0.7 + 0.3 * np.sin(2 * np.pi * t * 0.8 + 2))
    for at in gen.uniform(0, seconds - 0.1, int(seconds * 14)):
        i = int(at * RATE)
        n = int(gen.uniform(0.004, 0.03) * RATE)
        k = np.arange(n) / RATE
        out[i:i + n] += band(gen.standard_normal(n), 900, 7000) * np.exp(-k * gen.uniform(120, 420)) * gen.uniform(0.4, 2.0) if n > 16 else 0
    xf = int(0.5 * RATE)
    ramp = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * ramp + out[-xf:] * (1 - ramp)
    return out[:-xf]


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("example/assets/sound")
    out.mkdir(parents=True, exist_ok=True)
    # The bed is long, so it is kept compressed; the effects are tiny.
    wav = out / "bed.wav"
    write(wav, bed())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "aac", "-b:a", "96k", str(out / "bed.m4a")], check=True)
    wav.unlink()
    print("  bed.m4a  37.00s")
    for name, signal in (
        ("whoosh", whoosh()),
        ("pop", pop()),
        ("tick", tick()),
        ("swell", fade(swell(), 0, 0.25)),
    ):
        write(out / f"{name}.wav", signal)
        print(f"  {name}.wav  {len(signal) / RATE:.2f}s")
    # Weather and fire. Rain is long, so it is kept compressed, like the bed.
    for name, signal in (("rain", rain()), ("thunder", thunder()), ("crackle", crackle())):
        wav = out / f"{name}.wav"
        write(wav, signal)
        if name == "thunder":
            print(f"  {name}.wav  {len(signal) / RATE:.2f}s")
            continue
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "aac", "-b:a", "96k", str(out / f"{name}.m4a")], check=True)
        wav.unlink()
        print(f"  {name}.m4a  {len(signal) / RATE:.2f}s")


if __name__ == "__main__":
    main()
