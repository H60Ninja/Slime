#!/usr/bin/env python3
"""Generate the game's sound effects as 16-bit mono WAVs. Pure stdlib, deterministic.

    python3 art/make_sfx.py game/assets/sfx
"""
import math, random, struct, sys, wave, os

SR = 44100

def write(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = 0.9 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in samples))
    print("wrote", path, f"{len(samples)/SR:.2f}s")

def lowpass(xs, cutoff_fn):
    """One-pole lowpass with a per-sample cutoff (Hz)."""
    y, out = 0.0, []
    for i, x in enumerate(xs):
        a = 1 - math.exp(-2 * math.pi * cutoff_fn(i) / SR)
        y += a * (x - y)
        out.append(y)
    return out

def env(n, attack, decay_pow=2.0):
    out = []
    for i in range(n):
        t = i / n
        a = min(1.0, i / max(1, attack))
        out.append(a * (1 - t) ** decay_pow)
    return out

def squish(seed):
    rnd = random.Random(seed)
    n = int(SR * 0.22)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    wet = lowpass(noise, lambda i: 1800 * (1 - i / n) + 250)
    e = env(n, SR * 0.004, 1.6)
    thump = [0.6 * math.sin(2 * math.pi * (95 - 40 * i / n) * i / SR) for i in range(n)]
    return [(wet[i] * 1.2 + thump[i]) * e[i] for i in range(n)]

def pop(seed):
    n = int(SR * 0.09)
    e = env(n, SR * 0.001, 3.0)
    return [math.sin(2 * math.pi * (650 - 420 * i / n) * i / SR) * e[i] for i in range(n)]

def slurp(seed):
    rnd = random.Random(seed)
    n = int(SR * 0.35)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    wet = lowpass(noise, lambda i: 300 + 2200 * (i / n))
    e = [math.sin(math.pi * i / n) ** 1.5 for i in range(n)]
    return [wet[i] * e[i] for i in range(n)]

def squelch(seed):
    rnd = random.Random(seed)
    n = int(SR * 0.38)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    wet = lowpass(noise, lambda i: 900 - 500 * (i / n))
    e = [math.sin(math.pi * min(1.0, i / (n * 0.9))) ** 2.2 * (1 + 0.35 * math.sin(2 * math.pi * 11 * i / SR)) for i in range(n)]
    thump = [0.5 * math.sin(2 * math.pi * (70 - 25 * i / n) * i / SR) for i in range(n)]
    return [(wet[i] * 1.3 + thump[i]) * e[i] for i in range(n)]

def stretch(seed):
    rnd = random.Random(seed)
    n = int(SR * 0.42)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    wet = lowpass(noise, lambda i: 500 + 2600 * (i / n) ** 1.5)
    e = [math.sin(math.pi * i / n) ** 1.2 for i in range(n)]
    # rising wet tone underneath
    tone = [0.35 * math.sin(2 * math.pi * (220 + 380 * (i / n) ** 2) * i / SR) for i in range(n)]
    return [(wet[i] + tone[i]) * e[i] for i in range(n)]

def sprinkle(seed):
    rnd = random.Random(seed)
    n = int(SR * 0.45)
    out = [0.0] * n
    t = 0
    while t < n - 400:
        f = rnd.uniform(1800, 3600)
        for k in range(400):
            out[t + k] += math.sin(2 * math.pi * f * k / SR) * (1 - k / 400) ** 3 * 0.8
        t += rnd.randint(500, 1600)
    return out

def bubble(seed):
    rnd = random.Random(seed)
    n = int(SR * 0.07)
    f0 = rnd.uniform(900, 1700)
    e = env(n, SR * 0.001, 2.5)
    return [math.sin(2 * math.pi * (f0 + 600 * (i / n)) * i / SR) * e[i] for i in range(n)]

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "game/assets/sfx"
    os.makedirs(out, exist_ok=True)
    for k in range(3):
        write(os.path.join(out, f"squish{k}.wav"), squish(10 + k))
    write(os.path.join(out, "pop.wav"), pop(1))
    write(os.path.join(out, "slurp.wav"), slurp(2))
    write(os.path.join(out, "squelch.wav"), squelch(3))
    write(os.path.join(out, "stretch.wav"), stretch(4))
    write(os.path.join(out, "sprinkle.wav"), sprinkle(5))
    for k in range(3):
        write(os.path.join(out, f"bubble{k}.wav"), bubble(20 + k))
