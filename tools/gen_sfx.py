#!/usr/bin/env python3
"""Synthesise every sound effect in audio/sfx from scratch (numpy + ffmpeg).

No samples are used: each sound is built from noise, oscillators and
envelopes, so the results are original and free of any licence.

    python3 tools/gen_sfx.py            # writes audio/sfx/*.ogg
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "sfx")
rng = np.random.default_rng(1898)


# ------------------------------------------------------------------ helpers

def t_(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def brown(dur):
    x = np.cumsum(rng.uniform(-1, 1, int(dur * SR)))
    x -= np.convolve(x, np.ones(2000) / 2000, mode="same")   # remove drift
    return x / (np.max(np.abs(x)) + 1e-9)


def fft_filter(x, lo=0.0, hi=None, slope=1.0):
    """Band-pass with soft edges, done in the frequency domain."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo > 0:
        g *= 1 / (1 + (lo / np.maximum(f, 1)) ** (2 * slope))
    if hi:
        g *= 1 / (1 + (f / hi) ** (2 * slope))
    return np.fft.irfft(X * g, n)


def peak(x, freqs, q=8.0):
    """Sum of resonant peaks (formants) applied to x."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.zeros_like(f)
    for fc in freqs:
        bw = fc / q
        g += 1 / (1 + ((f - fc) / bw) ** 2)
    return np.fft.irfft(X * g, n)


def env(n, a=0.01, d=0.3, curve=3.0):
    """Attack then exponential-ish decay over n samples."""
    t = np.arange(n) / SR
    e = np.minimum(t / max(a, 1e-4), 1.0)
    dec = np.exp(-np.maximum(t - a, 0) / max(d, 1e-4) * curve / 3)
    return e * dec


def adsr(n, a, s_level, r):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.minimum(t / max(a, 1e-4), 1.0) * 1.0
    e = np.where(t > a, s_level + (1 - s_level) * np.exp(-(t - a) * 6), e)
    rel = np.clip((dur - t) / max(r, 1e-4), 0, 1)
    return e * rel


def osc(freq, dur, shape="sine"):
    """freq may be a scalar or an array (for sweeps)."""
    n = int(dur * SR)
    if np.ndim(freq) == 0:
        f = np.full(n, float(freq))
    else:
        f = np.asarray(freq, dtype=float)
        f = f[:n] if len(f) >= n else np.concatenate([f, np.full(n - len(f), f[-1])])
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    if shape == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    raise ValueError(shape)


def lin(a, b, dur):
    return np.linspace(a, b, int(dur * SR))


def expo(a, b, dur):
    return a * (b / a) ** np.linspace(0, 1, int(dur * SR))


def place(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i]
    return buf


def norm(x, level=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * level


def loopify(x, xf=0.25):
    """Crossfade the tail into the head so the sound loops seamlessly."""
    k = int(xf * SR)
    head, tail = x[:k], x[-k:]
    fade = np.linspace(0, 1, k)
    out = x[:-k].copy()
    out[:k] = head * fade + tail * (1 - fade)
    return out


def fade(x, fin=0.005, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def reverb(x, size=0.6, wet=0.3):
    """Cheap convolution reverb with a decaying noise tail."""
    n = int(size * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR / (size / 5))
    ir = fft_filter(ir, 0, 5000)
    ir /= np.sqrt(np.sum(ir ** 2))
    y = np.fft.irfft(np.fft.rfft(x, len(x) + n) * np.fft.rfft(ir, len(x) + n), len(x) + n)
    y = y[: len(x) + n]
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - wet) + norm(y, np.max(np.abs(x))) * wet


def save(name, x, level=0.9):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(norm(x, level), -1, 1)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    print(f"  {name:22s} {len(x) / SR:5.2f}s")


# ------------------------------------------------------------------ the Martians

def ulla():
    """'Ulla, ulla, ulla, ulla' - Wells' Martian howl. A vast, falling,
    vowel-shaped siren: 'oo' sliding into 'ah', twice."""
    out = np.zeros(int(5.2 * SR))
    for k, at in enumerate([0.0, 2.4]):
        d = 2.3
        f0 = np.concatenate([lin(150, 230, 0.35), lin(230, 205, d - 1.0), lin(205, 120, 0.65)])
        vib = 1 + 0.012 * np.sin(2 * np.pi * 5.2 * np.arange(len(f0)) / SR)
        src = osc(f0 * vib, d, "saw") + 0.4 * osc(f0 * vib * 1.005, d, "saw")
        # glide the formants from 'oo' (300/870) to 'ah' (730/1090)
        half = len(src) // 2
        a = peak(src[:half], [300, 870, 2240], q=6)
        b = peak(src[half:], [730, 1090, 2440], q=6)
        x = np.concatenate([a, b])
        x = fft_filter(x, 80, 3500)
        x *= adsr(len(x), 0.25, 0.85, 0.6)
        place(out, x * (1.0 if k == 0 else 0.85), at)
    rumble = fft_filter(brown(5.2), 0, 120) * 0.25
    return reverb(out + rumble, 2.2, 0.45)


def ray_fire():
    """The Heat-Ray: an inaudible beam in Wells, but games need a sound:
    a rising electrical whine over a roar of air."""
    d = 1.6
    whine = osc(expo(300, 2400, d), d, "saw") * 0.25
    whine = fft_filter(whine, 400, 6000)
    roar = fft_filter(noise(d), 200, 3000) * env(int(d * SR), 0.05, 0.9)
    x = (whine * adsr(int(d * SR), 0.08, 0.7, 0.4) + roar * 0.6)
    return reverb(x, 0.8, 0.25)


def ray_hum():
    """Loop while a ray is playing: a steady, singing hum with a hiss."""
    d = 3.0
    t = t_(d)
    f = 520 + 8 * np.sin(2 * np.pi * 0.67 * t)
    x = osc(f, d, "saw") * 0.2 + osc(f * 1.5, d, "sine") * 0.15 + osc(f * 0.5, d, "sine") * 0.3
    x = fft_filter(x, 100, 4000)
    hiss = fft_filter(noise(d), 2000, 9000) * 0.25 * (0.7 + 0.3 * np.sin(2 * np.pi * 3 * t))
    return loopify(x + hiss)


def ignite():
    """'A flash, a puff of flame': something catches fire."""
    d = 1.2
    whoomp = fft_filter(noise(d), 60, 900) * env(int(d * SR), 0.02, 0.5)
    crack = np.zeros(int(d * SR))
    for k in range(40):
        at = rng.uniform(0.05, 1.0)
        c = fft_filter(noise(0.01), 1500, 8000) * rng.uniform(0.2, 1)
        place(crack, c, at)
    return whoomp + crack * 0.5


def fire_loop():
    d = 4.0
    base = fft_filter(brown(d), 40, 400) * 0.6
    crack = np.zeros(int(d * SR))
    for k in range(260):
        at = rng.uniform(0, d - 0.02)
        c = fft_filter(noise(rng.uniform(0.002, 0.012)), 1200, 9000) * rng.uniform(0.1, 1) ** 2
        place(crack, c, at)
    return loopify(base + crack * 0.8)


def stride():
    """A fighting-machine's leg coming down: a deep thud and a clang of metal."""
    d = 1.4
    n = int(d * SR)
    thud = osc(expo(70, 32, d), d, "sine") * env(n, 0.005, 0.35)
    thud += fft_filter(noise(d), 20, 200) * env(n, 0.002, 0.15)
    clang = np.zeros(n)
    for f, a in [(310, 1), (437, 0.7), (612, 0.5), (889, 0.35), (1290, 0.2)]:
        clang += osc(f * rng.uniform(0.99, 1.01), d, "sine") * a * env(n, 0.002, 0.6 + 200 / f)
    x = thud * 1.2 + clang * 0.25
    return reverb(x, 1.2, 0.3)


def hydraulics():
    """Hiss and creak of the machine's joints."""
    d = 1.1
    n = int(d * SR)
    hiss = fft_filter(noise(d), 1500, 7000) * adsr(n, 0.08, 0.6, 0.4)
    creak = osc(lin(140, 90, d) * (1 + 0.05 * np.sign(np.sin(2 * np.pi * 37 * t_(d)))), d, "saw")
    creak = peak(creak, [500, 1300], q=5) * env(n, 0.1, 0.8) * 0.4
    return hiss * 0.6 + creak


def machine_walk():
    """Loop of a machine walking: stride + creak every 1.5 s."""
    out = np.zeros(int(3.0 * SR))
    place(out, stride()[: int(1.5 * SR)], 0.0)
    place(out, hydraulics() * 0.5, 0.6)
    place(out, stride()[: int(1.5 * SR)] * 0.9, 1.5)
    place(out, hydraulics() * 0.4, 2.1)
    return loopify(out, 0.05)


def tentacle():
    """A metallic tentacle groping: a slither of scraping and clicking."""
    d = 2.2
    n = int(d * SR)
    t = t_(d)
    scrape = fft_filter(noise(d), 800, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.3 * t) ** 2)
    clicks = np.zeros(n)
    for k in range(30):
        place(clicks, osc(rng.uniform(2000, 3500), 0.012) * env(int(0.012 * SR), 0.001, 0.004), rng.uniform(0, d - 0.02))
    return (scrape * 0.5 + clicks * 0.6) * adsr(n, 0.3, 0.8, 0.5)


def cylinder_unscrew():
    """'The top of the cylinder was rotating': a slow, grinding screech."""
    d = 4.5
    n = int(d * SR)
    t = t_(d)
    jitter = 1 + 0.03 * np.sin(2 * np.pi * 11 * t) + 0.02 * np.sin(2 * np.pi * 3.1 * t)
    sq = osc(170 * jitter, d, "saw")
    sq = peak(sq, [700, 1800, 3100], q=10)
    grind = fft_filter(noise(d), 200, 2000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 2.3 * t)))
    x = (sq * 0.6 + grind * 0.5) * adsr(n, 0.4, 0.9, 0.6)
    return reverb(x, 0.9, 0.2)


def cylinder_open():
    """The lid drops off: a heavy metallic clang on sand."""
    d = 2.5
    n = int(d * SR)
    x = np.zeros(n)
    for f, a in [(118, 1), (191, 0.8), (267, 0.6), (402, 0.4), (577, 0.3), (833, 0.2)]:
        x += osc(f, d, "sine") * a * env(n, 0.002, 1.4)
    thud = fft_filter(noise(d), 30, 300) * env(n, 0.002, 0.25)
    return reverb(x * 0.6 + thud, 1.5, 0.3)


def falling_star():
    """The cylinder streaks overhead: a long descending roar."""
    d = 3.2
    n = int(d * SR)
    t = t_(d)
    x = fft_filter(noise(d), 200, 2500)
    swoop = osc(expo(1800, 180, d), d, "saw")
    swoop = fft_filter(swoop, 100, 3000) * 0.3
    pan = np.clip(t / 2.6, 0, 1)
    return (x * 0.7 + swoop) * (pan ** 1.5) * adsr(n, 0.01, 1.0, 0.1)


def impact():
    """The cylinder strikes the common, far off."""
    d = 3.5
    n = int(d * SR)
    boom = osc(expo(60, 25, d), d, "sine") * env(n, 0.005, 0.8)
    rumble = fft_filter(brown(d), 15, 180) * env(n, 0.01, 1.4)
    debris = fft_filter(noise(d), 300, 3000) * env(n, 0.05, 0.6) * 0.3
    return reverb(boom + rumble + debris, 2.0, 0.35)


def shield_hum():
    """The (2005-style) force field: a phasing, glassy hum. Loops."""
    d = 4.0
    t = t_(d)
    x = sum(osc(f * (1 + 0.003 * np.sin(2 * np.pi * (0.25 * (i + 1)) * t)), d, "sine") / (i + 1)
            for i, f in enumerate([110, 165, 220, 331, 440]))
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t)
    return loopify(x)


def shield_fail():
    """The shield sputters and dies as the Martians sicken."""
    d = 2.8
    n = int(d * SR)
    t = t_(d)
    f = expo(220, 40, d)
    x = osc(f, d, "saw") * 0.4 + osc(f * 1.5, d, "sine") * 0.3
    stutter = (np.sin(2 * np.pi * lin(18, 3, d) * t) > 0).astype(float) * 0.7 + 0.3
    x = fft_filter(x, 30, 3000) * stutter * adsr(n, 0.01, 1.0, 0.8)
    zap = fft_filter(noise(d), 2000, 8000) * env(n, 0.005, 0.3) * 0.4
    return x + zap


def shield_hit():
    d = 0.7
    n = int(d * SR)
    x = osc(expo(900, 300, d), d, "sine") * env(n, 0.002, 0.3)
    x += fft_filter(noise(d), 1500, 6000) * env(n, 0.001, 0.08) * 0.6
    return reverb(x, 0.6, 0.3)


def smoke_hiss():
    """The Black Smoke canister bursting: a gush of vapour."""
    d = 2.6
    n = int(d * SR)
    pop = fft_filter(noise(0.1), 100, 1500) * env(int(0.1 * SR), 0.001, 0.04)
    hiss = fft_filter(noise(d), 600, 5000) * adsr(n, 0.05, 0.6, 1.2)
    out = hiss * 0.7
    place(out, pop, 0)
    return out


# ------------------------------------------------------------------ the army

def gun_boom():
    """A field gun firing: a sharp crack and a long low boom."""
    d = 2.6
    n = int(d * SR)
    crack = fft_filter(noise(d), 500, 9000) * env(n, 0.0005, 0.03)
    boom = osc(expo(90, 35, d), d, "sine") * env(n, 0.002, 0.5)
    body = fft_filter(noise(d), 30, 400) * env(n, 0.002, 0.7)
    return reverb(crack * 0.8 + boom + body * 0.8, 2.0, 0.35)


def shell_whistle():
    d = 1.6
    n = int(d * SR)
    w = osc(expo(1700, 650, d), d, "sine")
    air = fft_filter(noise(d), 1000, 4000) * 0.15
    return (w * 0.5 + air) * adsr(n, 0.3, 0.9, 0.05)


def explosion():
    d = 3.0
    n = int(d * SR)
    blast = fft_filter(noise(d), 40, 4000) * env(n, 0.001, 0.35)
    low = osc(expo(55, 22, d), d, "sine") * env(n, 0.002, 0.9)
    rumble = fft_filter(brown(d), 15, 150) * env(n, 0.05, 1.5)
    debris = np.zeros(n)
    for k in range(30):
        place(debris, fft_filter(noise(0.04), 800, 6000) * env(int(0.04 * SR), 0.001, 0.02), rng.uniform(0.3, 2.2))
    return reverb(blast + low * 1.1 + rumble + debris * 0.4, 1.8, 0.3)


def distant_guns():
    """Loop: guns booming somewhere over the hills."""
    d = 8.0
    out = fft_filter(brown(d), 15, 100) * 0.2
    for at, a in [(0.3, 1.0), (2.1, 0.6), (3.4, 0.8), (5.9, 0.5), (6.7, 0.9)]:
        b = fft_filter(gun_boom(), 20, 300)
        place(out, b * a * 0.6, at)
    return loopify(out, 1.0)


def rifle():
    d = 0.9
    n = int(d * SR)
    return reverb(fft_filter(noise(d), 300, 7000) * env(n, 0.0005, 0.05), 0.9, 0.3)


def gun_load():
    """Breech opened, shell in, breech closed."""
    out = np.zeros(int(1.0 * SR))
    for at, f in [(0.0, 900), (0.35, 600), (0.75, 1100)]:
        n = int(0.15 * SR)
        c = fft_filter(noise(0.15), 300, 6000) * env(n, 0.001, 0.03)
        c += osc(f, 0.15, "sine") * env(n, 0.001, 0.05) * 0.4
        place(out, c, at)
    return out


def bugle():
    """A bugle call to the guns (an original little call, not a real one)."""
    notes = [(392, 0.18), (523, 0.18), (659, 0.18), (784, 0.5), (659, 0.18), (784, 0.7)]
    out = np.zeros(int(sum(d for _, d in notes) * SR + SR))
    at = 0.0
    for f, d in notes:
        n = int(d * SR)
        x = sum(osc(f * h, d, "sine") / h ** 1.2 for h in range(1, 8))
        x *= adsr(n, 0.03, 0.8, 0.06)
        place(out, x, at)
        at += d
    return reverb(out, 1.4, 0.35)


# ------------------------------------------------------------------ weather

def rain_loop():
    d = 5.0
    hiss = fft_filter(noise(d), 800, 9000) * 0.5
    patter = np.zeros(int(d * SR))
    for k in range(1500):
        place(patter, fft_filter(noise(0.004), 2000, 9000) * rng.uniform(0, 1) ** 3, rng.uniform(0, d - 0.01))
    low = fft_filter(brown(d), 30, 300) * 0.3
    return loopify(hiss + patter * 0.6 + low)


def thunder(seed):
    r = np.random.default_rng(seed)
    d = 5.0
    n = int(d * SR)
    crack = fft_filter(noise(d), 300, 6000) * env(n, 0.001, 0.12)
    roll = np.zeros(n)
    for k in range(9):
        at = r.uniform(0.05, 2.5)
        seg = fft_filter(brown(2.5), 20, 300) * env(int(2.5 * SR), 0.15, 1.2) * r.uniform(0.4, 1.0)
        place(roll, seg, at)
    return reverb(crack * 0.7 + roll, 2.5, 0.4)[: n + SR]


def wind_loop():
    d = 6.0
    t = t_(d)
    x = fft_filter(noise(d), 150, 900, slope=2)
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * 0.17 * t) * np.sin(2 * np.pi * 0.41 * t + 1)
    whistle = peak(noise(d), [620 + 40 * np.sin(1)], q=40) * 0.15
    return loopify(x * gust + whistle * gust)


def night_loop():
    """A quiet summer night on Horsell Common: crickets and a breath of air."""
    d = 6.0
    out = fft_filter(noise(d), 200, 800) * 0.05
    for k in range(70):
        at = rng.uniform(0, d - 0.2)
        n = int(0.12 * SR)
        chirp = osc(4300 + rng.uniform(-200, 200), 0.12, "sine")
        chirp *= (np.sin(2 * np.pi * 45 * t_(0.12)) > 0).astype(float) * env(n, 0.005, 0.1)
        place(out, chirp * rng.uniform(0.04, 0.12), at)
    return loopify(out)


def crowd_loop():
    """A murmuring crowd: babble built from many tiny vowel-ish blips."""
    d = 6.0
    out = fft_filter(noise(d), 200, 1500) * 0.1
    for k in range(500):
        dd = rng.uniform(0.08, 0.25)
        f0 = rng.uniform(100, 240)
        v = osc(f0 * lin(1.0, rng.uniform(0.85, 1.15), dd), dd, "saw")
        v = peak(v, [rng.uniform(300, 800), rng.uniform(900, 2200)], q=5)
        place(out, v * adsr(len(v), 0.02, 0.8, 0.05) * rng.uniform(0.05, 0.2), rng.uniform(0, d - dd))
    return loopify(fft_filter(out, 100, 3500))


def panic_loop():
    """A crowd in flight: shouts over running feet."""
    d = 6.0
    out = crowd_loop() * 0.6
    out = out[: int(d * SR)] if len(out) >= int(d * SR) else np.pad(out, (0, int(d * SR) - len(out)))
    for k in range(40):
        dd = rng.uniform(0.25, 0.6)
        f0 = rng.uniform(250, 420)
        v = osc(f0 * expo(1.0, rng.uniform(0.7, 1.2), dd), dd, "saw")
        v = peak(v, [rng.uniform(700, 1000), rng.uniform(1200, 2500)], q=6)
        place(out, v * adsr(len(v), 0.03, 0.8, 0.1) * rng.uniform(0.1, 0.35), rng.uniform(0, d - dd))
    for k in range(120):
        place(out, fft_filter(noise(0.03), 100, 1500) * env(int(0.03 * SR), 0.001, 0.015) * 0.3, rng.uniform(0, d - 0.04))
    return loopify(out)


def scream():
    d = 1.2
    n = int(d * SR)
    f0 = np.concatenate([lin(500, 900, 0.2), lin(900, 820, 0.7), lin(820, 500, 0.3)])
    v = osc(f0 * (1 + 0.02 * np.sin(2 * np.pi * 7 * np.arange(len(f0)) / SR)), d, "saw")
    v = peak(v, [900, 1500, 2800], q=6)
    return reverb(v * adsr(n, 0.04, 0.9, 0.3), 1.0, 0.3)


# ------------------------------------------------------------------ people and places

def footstep(kind, seed):
    r = np.random.default_rng(seed)
    d = 0.18
    n = int(d * SR)
    if kind == "grass":
        x = fft_filter(noise(d), 600, 5000) * env(n, 0.01, 0.07)
        x += fft_filter(noise(d), 60, 300) * env(n, 0.002, 0.04) * 0.6
    elif kind == "gravel":
        x = np.zeros(n)
        for k in range(14):
            place(x, fft_filter(noise(0.006), 1500, 8000) * r.uniform(0.2, 1), r.uniform(0, 0.08))
        x += fft_filter(noise(d), 80, 400) * env(n, 0.002, 0.04) * 0.5
    else:  # floor boards
        x = fft_filter(noise(d), 80, 1200) * env(n, 0.002, 0.05)
        x += osc(r.uniform(140, 190), d, "sine") * env(n, 0.002, 0.06) * 0.5
    return x


def crockery():
    """Treading on 'smashed crockery': the house's sharpest danger."""
    d = 0.9
    n = int(d * SR)
    out = np.zeros(n)
    for k in range(22):
        f = rng.uniform(2500, 6500)
        dd = rng.uniform(0.03, 0.12)
        c = osc(f, dd, "sine") * env(int(dd * SR), 0.001, dd * 0.6)
        c += fft_filter(noise(dd), 3000, 10000) * env(int(dd * SR), 0.0005, 0.01)
        place(out, c * rng.uniform(0.2, 1), rng.uniform(0, 0.35))
    return out


def heartbeat():
    d = 1.0
    n = int(d * SR)
    out = np.zeros(n)
    for at, a in [(0.0, 1.0), (0.22, 0.7)]:
        b = osc(expo(60, 40, 0.15), 0.15, "sine") * env(int(0.15 * SR), 0.005, 0.06)
        place(out, b * a, at)
    return out


def door():
    d = 1.4
    n = int(d * SR)
    creak = osc(lin(220, 160, 1.0) * (1 + 0.08 * np.sign(np.sin(2 * np.pi * 23 * t_(1.0)))), 1.0, "saw")
    creak = peak(creak, [600, 1400], q=7) * adsr(int(1.0 * SR), 0.1, 0.7, 0.2) * 0.4
    out = np.zeros(n)
    place(out, creak, 0)
    place(out, fft_filter(noise(0.2), 60, 800) * env(int(0.2 * SR), 0.002, 0.05), 1.05)
    return out


def clock_tick():
    """The telescope's clockwork drive."""
    d = 1.0
    out = np.zeros(int(d * SR))
    for at, f in [(0.0, 3200), (0.5, 2600)]:
        n = int(0.02 * SR)
        place(out, osc(f, 0.02, "sine") * env(n, 0.0005, 0.004) + fft_filter(noise(0.02), 3000, 9000) * env(n, 0.0005, 0.002) * 0.5, at)
    return out


def page_turn():
    d = 0.5
    n = int(d * SR)
    return fft_filter(noise(d), 1500, 8000) * adsr(n, 0.08, 0.5, 0.25) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t_(d)) ** 2)


def ui_click():
    d = 0.06
    n = int(d * SR)
    return osc(1400, d, "sine") * env(n, 0.001, 0.015) + fft_filter(noise(d), 2000, 7000) * env(n, 0.0005, 0.004) * 0.4


def horse():
    """A whinny (original synthesis)."""
    d = 1.4
    n = int(d * SR)
    f0 = np.concatenate([lin(500, 1100, 0.2), 1100 - 400 * np.linspace(0, 1, int(1.2 * SR)) ** 0.6])
    f0 = osc(0, d) * 0 + np.resize(f0, n)
    trill = 1 + 0.06 * np.sin(2 * np.pi * lin(22, 12, d)[:n] * t_(d)[:n])
    v = osc(f0 * trill, d, "saw")
    v = peak(v, [800, 1700, 2900], q=5)
    return reverb(v * adsr(n, 0.03, 0.8, 0.5), 0.8, 0.2)


def train_loop():
    """A train in the distance (the panic-stricken exodus by rail)."""
    d = 4.0
    out = fft_filter(brown(d), 30, 300) * 0.4
    for k in range(16):
        at = k * 0.25
        place(out, fft_filter(noise(0.06), 80, 1500) * env(int(0.06 * SR), 0.002, 0.02) * (1.0 if k % 2 == 0 else 0.6), at)
    return loopify(out, 0.1)


def steam_whistle():
    d = 2.0
    n = int(d * SR)
    x = sum(osc(f, d, "sine") for f in [622, 740, 932]) + fft_filter(noise(d), 1500, 5000) * 0.6
    return reverb(x * adsr(n, 0.08, 0.85, 0.4), 1.5, 0.35)


def church_bell():
    d = 4.5
    n = int(d * SR)
    x = np.zeros(n)
    for f, a, dec in [(220, 1, 3.5), (264, 0.5, 2.5), (330, 0.6, 2.8), (440, 0.4, 2.0), (523, 0.3, 1.5), (110, 0.6, 4.0)]:
        x += osc(f, d, "sine") * a * env(n, 0.002, dec)
    return reverb(x, 2.0, 0.3)


def sting_death():
    """Short orchestral-ish sting when the player dies."""
    d = 2.5
    n = int(d * SR)
    x = sum(osc(f * expo(1, 0.94, d), d, "saw") for f in [110, 130.8, 164.8]) / 3
    x = fft_filter(x, 60, 1500) * adsr(n, 0.01, 0.7, 1.4)
    return reverb(x + fft_filter(noise(d), 40, 200) * env(n, 0.002, 0.3), 1.6, 0.35)


def sting_win():
    d = 3.0
    n = int(d * SR)
    out = np.zeros(n)
    for k, f in enumerate([261.6, 329.6, 392.0, 523.3]):
        nn = int((d - k * 0.15) * SR)
        x = (osc(f, d - k * 0.15, "tri") + 0.3 * osc(f * 2, d - k * 0.15, "sine")) * adsr(nn, 0.05, 0.6, 1.2)
        place(out, x, k * 0.15)
    return reverb(out, 1.6, 0.35)


SOUNDS = {
    "ulla": ulla, "ray_fire": ray_fire, "ray_hum": ray_hum, "ignite": ignite, "fire_loop": fire_loop,
    "stride": stride, "hydraulics": hydraulics, "machine_walk": machine_walk, "tentacle": tentacle,
    "cylinder_unscrew": cylinder_unscrew, "cylinder_open": cylinder_open, "falling_star": falling_star,
    "impact": impact, "shield_hum": shield_hum, "shield_fail": shield_fail, "shield_hit": shield_hit,
    "smoke_hiss": smoke_hiss,
    "gun_boom": gun_boom, "shell_whistle": shell_whistle, "explosion": explosion, "distant_guns": distant_guns,
    "rifle": rifle, "gun_load": gun_load, "bugle": bugle,
    "rain_loop": rain_loop, "thunder_1": lambda: thunder(1), "thunder_2": lambda: thunder(2),
    "wind_loop": wind_loop, "night_loop": night_loop, "crowd_loop": crowd_loop, "panic_loop": panic_loop,
    "scream": scream,
    "step_grass_1": lambda: footstep("grass", 1), "step_grass_2": lambda: footstep("grass", 2),
    "step_gravel_1": lambda: footstep("gravel", 3), "step_gravel_2": lambda: footstep("gravel", 4),
    "step_floor_1": lambda: footstep("floor", 5), "step_floor_2": lambda: footstep("floor", 6),
    "crockery": crockery, "heartbeat": heartbeat, "door": door, "clock_tick": clock_tick,
    "page_turn": page_turn, "ui_click": ui_click, "horse": horse, "train_loop": train_loop,
    "steam_whistle": steam_whistle, "church_bell": church_bell,
    "sting_death": sting_death, "sting_win": sting_win,
}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        save(name, fn())
