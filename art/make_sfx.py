#!/usr/bin/env python3
"""Generate the game's sound effects as 16-bit WAVs. Pure stdlib, deterministic.

    python3 art/make_sfx.py game/assets/sfx

Design notes (from the 2026-10-18 research pass, see docs/market-research.md):
- ASMR "tingle" tracks energy around 5 kHz in short, repeated transients, so every wet
  sound carries a sticky-click layer: dense clusters of 3-15 ms resonant bursts at 2-6 kHz.
- Real slime foley is built in layers: a wet squelch body (noise through a modulated
  band-pass and a comb filter), separate sharp pops, and fine crackle; here each sound
  is mixed from those same layers.
- A sticky release is a resonant burst whose centre frequency falls fast, followed by a
  faint delayed tail (the two surfaces letting go).
- Variation beats fidelity: each family has several variants and the game adds pitch
  randomisation on top, so nothing repeats exactly.
"""
import math, os, random, struct, subprocess, sys, wave

SR = 44100
CC0_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cc0")
DECODED = os.path.join(CC0_DIR, ".decoded")
_rec_cache = {}


def rec(name, dur=None, gain=1.0, start_at_attack=True, fade_ms=18):
    """A CC0 recording (see art/cc0/LICENSE.md) as a mono float list, decoded once with
    ffmpeg. Trimmed to `dur` seconds from its attack and faded out. Missing ffmpeg or file
    -> empty list, so the synthesized layers still build on their own."""
    key = (name, dur, start_at_attack)
    if key in _rec_cache:
        return gain_list(_rec_cache[key], gain)
    src = None
    for ext in (".ogg", ".mp3", ".flac", ".wav"):
        cand = os.path.join(CC0_DIR, name + ext)
        if os.path.exists(cand):
            src = cand
            break
    if src is None:
        print("  (no recording", name, ")")
        return []
    os.makedirs(DECODED, exist_ok=True)
    wav = os.path.join(DECODED, name + ".wav")
    if not os.path.exists(wav):
        try:
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-ac", "1", "-ar", str(SR), "-sample_fmt", "s16", wav], check=True)
        except Exception as e:
            print("  (ffmpeg failed for", name, e, ")")
            return []
    w = wave.open(wav); n = w.getnframes(); data = w.readframes(n); w.close()
    xs = [v / 32767 for v in struct.unpack("<%dh" % n, data)]
    peak = max(1e-6, max(abs(v) for v in xs))
    xs = [v / peak * 0.9 for v in xs]
    if start_at_attack:
        th = 0.12
        i0 = next((i for i, v in enumerate(xs) if abs(v) > th), 0)
        i0 = max(0, i0 - int(SR * 0.004))
        xs = xs[i0:]
    if dur is not None:
        xs = xs[: int(SR * dur)]
    f = int(SR * fade_ms / 1000)
    n = len(xs)
    for i in range(min(f, n)):
        xs[n - 1 - i] *= i / f
    for i in range(min(int(SR * 0.002), n)):
        xs[i] *= i / (SR * 0.002)
    _rec_cache[key] = xs
    return gain_list(xs, gain)


def gain_list(xs, g):
    return [x * g for x in xs]


# ---------------------------------------------------------------- DSP helpers

def write(path, samples, stereo=None):
    """samples: mono list in [-1,1]. stereo: optional (L, R) lists."""
    if stereo is not None:
        L, R = stereo
        peak = max(1e-6, max(max(abs(s) for s in L), max(abs(s) for s in R)))
        norm = 0.92 / peak
        frames = b"".join(struct.pack("<hh", int(max(-1, min(1, L[i] * norm)) * 32767), int(max(-1, min(1, R[i] * norm)) * 32767)) for i in range(len(L)))
        ch = 2
        n = len(L)
    else:
        peak = max(1e-6, max(abs(s) for s in samples))
        norm = 0.92 / peak
        frames = b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in samples)
        ch = 1
        n = len(samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(frames)
    print("wrote", os.path.basename(path), f"{n / SR:.2f}s", "stereo" if ch == 2 else "mono")


def lowpass(xs, cutoff_fn):
    y, out = 0.0, []
    for i, x in enumerate(xs):
        a = 1 - math.exp(-2 * math.pi * cutoff_fn(i) / SR)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(xs, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    out, prev_x, prev_y = [], 0.0, 0.0
    for x in xs:
        y = a * (prev_y + x - prev_x)
        out.append(y); prev_x, prev_y = x, y
    return out


def bandpass(xs, freq_fn, q=6.0):
    """Biquad band-pass with a per-sample centre frequency (state-variable form)."""
    out = []
    lp = bp = 0.0
    for i, x in enumerate(xs):
        f = 2 * math.sin(math.pi * min(freq_fn(i), SR * 0.45) / SR)
        hp = x - lp - bp / q
        bp += f * hp
        lp += f * bp
        out.append(bp)
    return out


def comb(xs, delay_fn, feedback=0.6, mix=0.5):
    """Feedback comb with a per-sample delay (samples). The 'squish engine' core."""
    buf = [0.0] * 4096
    out = []
    w = 0
    for i, x in enumerate(xs):
        d = max(1.0, min(4000.0, delay_fn(i)))
        r = (w - d) % 4096
        i0 = int(r); fr = r - i0
        y = buf[i0] * (1 - fr) + buf[(i0 + 1) % 4096] * fr
        v = x + y * feedback
        buf[w] = v
        w = (w + 1) % 4096
        out.append(x * (1 - mix) + y * mix)
    return out


def env(n, attack, decay_pow=2.0, hold=0.0):
    out = []
    for i in range(n):
        t = i / n
        a = min(1.0, i / max(1, attack))
        d = 1.0 if t < hold else (1 - (t - hold) / (1 - hold)) ** decay_pow
        out.append(a * d)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out


def gain(xs, g):
    return [x * g for x in xs]


def fade_edges(xs, ms=4):
    n = len(xs); f = int(SR * ms / 1000)
    for i in range(min(f, n)):
        k = i / f
        xs[i] *= k
        xs[n - 1 - i] *= k
    return xs


# ---------------------------------------------------------------- layers

def sticky_clicks(rnd, n, density, f_lo=2200, f_hi=6000, amp=1.0, shape=None):
    """Clusters of tiny resonant bursts: the 'sticky' high-frequency detail.
    density: expected clicks per second (callable of i or float). shape: amplitude fn of i."""
    out = [0.0] * n
    i = 0
    while i < n:
        d = density(i) if callable(density) else density
        gap = int(SR / max(1.0, d) * rnd.uniform(0.35, 1.65))
        i += max(40, gap)
        if i >= n:
            break
        ln = rnd.randint(int(SR * 0.003), int(SR * 0.014))
        f = rnd.uniform(f_lo, f_hi)
        a = amp * rnd.uniform(0.35, 1.0) * (shape(i) if shape else 1.0)
        q = rnd.uniform(5.0, 14.0)
        burst = [rnd.uniform(-1, 1) for _ in range(ln)]
        burst = bandpass(burst, lambda k, f=f, ln=ln: f * (1 - 0.25 * k / ln), q)
        e = env(ln, SR * 0.0004, 2.2)
        for k in range(ln):
            if i + k < n:
                out[i + k] += burst[k] * e[k] * a * 2.2
    return out


def wet_body(rnd, n, cut_fn, comb_delay_fn, amp=1.0):
    """Noise through a wandering band-pass + comb: the gooey mid-range squelch body."""
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    bp = bandpass(noise, cut_fn, 2.2)
    c = comb(bp, comb_delay_fn, feedback=0.72, mix=0.55)
    return gain(c, amp)


def thump(n, f0, f1, amp=0.6):
    out = []
    ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * amp)
    return out


def release_tail(rnd, start_f, end_f, dur, amp=1.0, tail_delay=0.035):
    """Sticky let-go: resonant burst falling in frequency, then a faint delayed echo."""
    n = int(SR * dur)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    b = bandpass(noise, lambda i: start_f + (end_f - start_f) * (i / n) ** 0.6, 9.0)
    e = env(n, SR * 0.001, 3.0)
    main = [b[i] * e[i] * amp for i in range(n)]
    d = int(SR * tail_delay)
    out = main + [0.0] * d
    for i in range(n):
        out[i + d] += main[i] * 0.32
    return out


def bubble(rnd, f0, dur, amp=1.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        k = i / n
        f = f0 * (1 + 0.9 * k * k)          # pitch rises as the bubble thins
        ph += 2 * math.pi * f / SR
        e = (1 - k) ** 2.6 * min(1.0, i / (SR * 0.0008))
        out.append(math.sin(ph) * e * amp)
    # tiny click at the burst
    cl = int(SR * 0.004)
    for i in range(cl):
        out[i] += rnd.uniform(-1, 1) * (1 - i / cl) ** 3 * 0.5 * amp
    return out


# ---------------------------------------------------------------- sounds

SQUISH_RECS = ["slime_04", "slime_16", "slime_15", "squish_04", "slime_02"]
POP_RECS = ["squishsplat_impact", "squish_03", "squish_01", "mud_24"]
SQUELCH_RECS = ["slime_09", "slime_10", "mud_19"]
STRETCH_RECS = ["slime_11", "slime_08", "slime_03"]
SLURP_RECS = ["splash_10", "splash_06"]


def squish(seed):
    """Finger lands on slime: real slime recording as the body, synthesized thump,
    sticky clicks and a late tearing release on top."""
    rnd = random.Random(seed)
    n = int(SR * 0.30)
    r = rec(SQUISH_RECS[seed % len(SQUISH_RECS)], 0.30, 0.9)
    body = wet_body(rnd, n,
                    lambda i: 380 + 900 * (0.5 + 0.5 * math.sin(2 * math.pi * 7 * i / SR)) * (1 - i / n),
                    lambda i: 60 + 50 * math.sin(2 * math.pi * 3.1 * i / SR + seed), 1.0)
    e_body = env(n, SR * 0.018, 1.8)            # pressure builds over ~18 ms (foley note)
    body = [body[i] * e_body[i] for i in range(n)]
    clicks = sticky_clicks(rnd, n, lambda i: 140 * (1 - i / n) + 20, amp=0.55,
                           shape=lambda i: min(1.0, i / (SR * 0.01)))
    th = [v * env(n, SR * 0.002, 3.5)[i] for i, v in enumerate(thump(n, 110, 60, 0.7))]
    rel = release_tail(rnd, 2600, 700, 0.07, 0.45)
    out = mix(gain_list(body, 0.35 if r else 1.0), clicks, th, r)
    for i, v in enumerate(rel):
        j = int(SR * 0.16) + i
        if j < n:
            out[j] += v
    return fade_edges(out)


def pop(seed):
    """Finger lifts off: sharp sticky release with a little suction."""
    rnd = random.Random(seed)
    rel = release_tail(rnd, 3400 + rnd.uniform(-600, 600), 500, 0.11, 1.0)
    n = len(rel)
    suck = wet_body(rnd, n, lambda i: 900 - 500 * i / n, lambda i: 40 + 30 * i / n, 0.4)
    suck = [suck[i] * env(n, SR * 0.001, 2.5)[i] for i in range(n)]
    clicks = sticky_clicks(rnd, n, lambda i: 260 * (1 - i / n), amp=0.6)
    r = rec(POP_RECS[seed % len(POP_RECS)], 0.14, 0.8)
    return fade_edges(mix(rel, gain_list(suck, 0.5 if r else 1.0), clicks, r))


def squelch(seed):
    """Finger held down and wiggled: long gooey kneading squelch."""
    rnd = random.Random(seed)
    n = int(SR * 0.55)
    r = rec(SQUELCH_RECS[seed % len(SQUELCH_RECS)], 0.55, 0.9)
    body = wet_body(rnd, n,
                    lambda i: 300 + 700 * (0.5 + 0.5 * math.sin(2 * math.pi * 4.5 * i / SR)) + 300 * math.sin(2 * math.pi * 0.9 * i / SR),
                    lambda i: 55 + 45 * math.sin(2 * math.pi * 2.2 * i / SR), 1.0)
    e = [math.sin(math.pi * min(1.0, i / (n * 0.95))) ** 1.4 for i in range(n)]
    body = [body[i] * e[i] for i in range(n)]
    clicks = sticky_clicks(rnd, n, lambda i: 90 + 60 * math.sin(2 * math.pi * 3 * i / SR), amp=0.5, shape=lambda i: e[i])
    th = [v * e[i] for i, v in enumerate(thump(n, 75, 55, 0.45))]
    bubs = [0.0] * n
    for _ in range(4):
        b = bubble(rnd, rnd.uniform(500, 1100), 0.05, 0.35)
        t = rnd.randint(int(n * 0.15), int(n * 0.85))
        for i, v in enumerate(b):
            if t + i < n:
                bubs[t + i] += v
    return fade_edges(mix(gain_list(body, 0.25 if r else 1.0), gain_list(clicks, 0.7), th, bubs, r))


def stretch(seed):
    """Fast pull: rising wet tear with crackle that gets finer as it thins."""
    rnd = random.Random(seed)
    n = int(SR * 0.5)
    r = rec(STRETCH_RECS[seed % len(STRETCH_RECS)], 0.5, 0.95, start_at_attack=False)
    body = wet_body(rnd, n, lambda i: 500 + 2400 * (i / n) ** 1.6,
                    lambda i: 70 - 50 * i / n, 0.9)
    e = [math.sin(math.pi * i / n) ** 1.1 for i in range(n)]
    body = [body[i] * e[i] for i in range(n)]
    clicks = sticky_clicks(rnd, n, lambda i: 60 + 420 * (i / n) ** 2, f_lo=2800, f_hi=7000, amp=0.75, shape=lambda i: e[i])
    rel = release_tail(rnd, 4200, 900, 0.09, 0.7)
    out = mix(gain_list(body, 0.3 if r else 1.0), gain_list(clicks, 0.8), r)
    for i, v in enumerate(rel):
        j = int(n * 0.82) + i
        if j < n:
            out[j] += v
    return fade_edges(out)


def crackle(seed):
    """Crunchy slime: dense foam-bead crackle, bright and dry."""
    rnd = random.Random(seed)
    n = int(SR * 0.34)
    cl = sticky_clicks(rnd, n, lambda i: 520 * (1 - 0.7 * i / n), f_lo=1800, f_hi=7500, amp=1.0,
                       shape=lambda i: (1 - i / n) ** 0.7)
    body = wet_body(rnd, n, lambda i: 900 - 300 * i / n, lambda i: 30, 0.25)
    body = [body[i] * (1 - i / n) ** 2 for i in range(n)]
    return fade_edges(mix(cl, body))


def poof(seed):
    """Fluffy slime: soft airy puff, almost no clicks."""
    rnd = random.Random(seed)
    n = int(SR * 0.32)
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    air = lowpass(noise, lambda i: 350 + 1100 * (1 - i / n))
    e = [math.sin(math.pi * min(1.0, i / (n * 0.95))) ** 0.8 for i in range(n)]
    air = [air[i] * e[i] for i in range(n)]
    clicks = sticky_clicks(rnd, n, 25, f_lo=1500, f_hi=3000, amp=0.15, shape=lambda i: e[i])
    return fade_edges(mix(air, clicks))


def slurp(seed):
    """Colour drop lands / new lump: wet plop with a bubbly settle."""
    rnd = random.Random(seed)
    n = int(SR * 0.42)
    th = [v * env(n, SR * 0.003, 2.5)[i] for i, v in enumerate(thump(n, 140, 50, 0.9))]
    body = wet_body(rnd, n, lambda i: 400 + 1800 * (1 - i / n) ** 2, lambda i: 45 + 25 * i / n, 0.8)
    body = [body[i] * env(n, SR * 0.004, 2.2)[i] for i in range(n)]
    bubs = [0.0] * n
    for k in range(6):
        b = bubble(rnd, rnd.uniform(400, 1400), rnd.uniform(0.03, 0.07), 0.5)
        t = int(n * (0.12 + 0.12 * k)) + rnd.randint(0, int(SR * 0.02))
        for i, v in enumerate(b):
            if t + i < n:
                bubs[t + i] += v
    clicks = sticky_clicks(rnd, n, lambda i: 120 * (1 - i / n), amp=0.4)
    r = rec(SLURP_RECS[seed % len(SLURP_RECS)], 0.42, 0.85)
    return fade_edges(mix(th, gain_list(body, 0.4 if r else 1.0), bubs, clicks, r))


# ---------------------------------------------------------------- per-kind voices

def sine_tail(f, dur, amp, decay=4.0, vib=0.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        k = i / n
        ph += 2 * math.pi * f * (1 + vib * math.sin(2 * math.pi * 6 * i / SR)) / SR
        out.append(math.sin(ph) * (1 - k) ** decay * amp * min(1.0, i / (SR * 0.003)))
    return out


def jelly(seed):
    """Clear slime: watery, bubbly, higher and cleaner than shiny."""
    rnd = random.Random(seed)
    n = int(SR * 0.3)
    r = rec(["splash_14", "splash_02", "splash_07"][seed % 3], 0.3, 0.8)
    bubs = [0.0] * n
    for _ in range(5):
        b = bubble(rnd, rnd.uniform(900, 2200), rnd.uniform(0.03, 0.06), 0.5)
        t = rnd.randint(int(n * 0.05), int(n * 0.7))
        for i, v in enumerate(b):
            if t + i < n:
                bubs[t + i] += v
    clicks = sticky_clicks(rnd, n, lambda i: 110 * (1 - i / n), f_lo=3000, f_hi=7000, amp=0.4)
    return fade_edges(mix(highpass(r, 350) if r else [], bubs, clicks))


def metal(seed):
    """Metallic slime: squish with a short ringing tang."""
    rnd = random.Random(seed)
    base = squish(seed + 300)
    n = len(base)
    ring = [0.0] * n
    for f, a in [(2960, 0.5), (4420, 0.35), (6180, 0.2)]:
        f *= rnd.uniform(0.96, 1.04)
        t = sine_tail(f, 0.22, a, 5.0)
        for i, v in enumerate(t):
            if i < n:
                ring[i] += v
    c = comb(base, lambda i: 9.0 + 2.0 * math.sin(i * 0.001), feedback=0.8, mix=0.5)
    return fade_edges(mix(gain_list(c, 0.8), ring))


def cloud(seed):
    """Cloud slime: muffled, soft, almost no clicks."""
    base = squish(seed + 400)
    soft = lowpass(base, lambda i: 900)
    air = poof(seed + 400)
    return fade_edges(mix(soft, gain_list(air, 0.35)))


def butter(seed):
    """Butter slime: low, smooth smear, no clicks."""
    rnd = random.Random(seed)
    n = int(SR * 0.34)
    r = rec(["mud_04", "mud_19", "slime_13"][seed % 3], 0.34, 0.9)
    r = lowpass(r, lambda i: 700) if r else []
    e = [math.sin(math.pi * min(1.0, i / (n * 0.95))) ** 1.3 for i in range(n)]
    body = wet_body(rnd, n, lambda i: 220 + 260 * (0.5 + 0.5 * math.sin(2 * math.pi * 3 * i / SR)), lambda i: 90 + 30 * math.sin(i * 0.0005), 0.6)
    body = [body[i] * e[i] for i in range(n)]
    th = [v * e[i] for i, v in enumerate(thump(n, 80, 55, 0.5))]
    return fade_edges(mix(r, body, th))


def glow(seed):
    """Glow slime: squish with a soft ethereal hum underneath."""
    base = squish(seed + 500)
    n = len(base)
    hum = [0.0] * n
    for f, a in [(392, 0.25), (587.3, 0.18), (784, 0.12)]:
        t = sine_tail(f, 0.3, a, 1.8, vib=0.004)
        for i, v in enumerate(t):
            if i < n:
                hum[i] += v
    return fade_edges(mix(gain_list(base, 0.85), hum))


def holo(seed):
    """Holographic slime: squish plus a glassy little descending sparkle."""
    rnd = random.Random(seed)
    base = squish(seed + 600)
    n = len(base)
    spark = [0.0] * n
    for k, f in enumerate([2637, 2093, 1760, 1319]):
        t = sine_tail(f * rnd.uniform(0.99, 1.01), 0.09, 0.3, 3.0)
        off = int(SR * (0.03 + 0.045 * k))
        for i, v in enumerate(t):
            if off + i < n:
                spark[off + i] += v
    return fade_edges(mix(gain_list(base, 0.85), spark))


def magic(seed):
    """Colour-changing slime: squish plus a rising twinkle of random high notes."""
    rnd = random.Random(seed)
    base = squish(seed + 700)
    n = len(base)
    tw = [0.0] * n
    for k in range(7):
        f = rnd.uniform(1500, 4200) * (1 + 0.1 * k)
        t = sine_tail(f, 0.06, 0.22, 3.0)
        off = int(SR * (0.02 + 0.03 * k)) + rnd.randint(0, int(SR * 0.01))
        for i, v in enumerate(t):
            if off + i < n:
                tw[off + i] += v
    return fade_edges(mix(gain_list(base, 0.85), tw))


def bubble_pop(seed):
    rnd = random.Random(seed)
    b = bubble(rnd, rnd.uniform(700, 1500), 0.07, 1.0)
    rel = release_tail(rnd, 3000, 1200, 0.04, 0.5, 0.02)
    return fade_edges(mix(b, rel))


def sprinkle(seed):
    """Beads/stars landing: a scatter of tiny tinkly taps into soft slime."""
    rnd = random.Random(seed)
    n = int(SR * 0.5)
    out = [0.0] * n
    t = 0
    while t < n - 600:
        f = rnd.uniform(1600, 4200)
        ln = rnd.randint(300, 700)
        for k in range(ln):
            out[t + k] += math.sin(2 * math.pi * f * k / SR) * (1 - k / ln) ** 3 * 0.8
        # each bead also makes a tiny wet contact
        for k in range(120):
            out[t + k] += rnd.uniform(-1, 1) * (1 - k / 120) ** 3 * 0.25
        t += rnd.randint(500, 1500)
    return fade_edges(out)


def click(seed):
    n = int(SR * 0.08)
    out = []
    for i in range(n):
        e = (1 - i / n) ** 6
        out.append((math.sin(2 * math.pi * 2400 * i / SR) + 0.5 * math.sin(2 * math.pi * 900 * i / SR)) * e)
    return fade_edges(out)


def slice_wet(seed):
    """Knife through soft slime: a wet zip that opens, then two surfaces part."""
    rnd = random.Random(seed)
    n = int(SR * 0.32)
    body = wet_body(rnd, n, lambda i: 1800 - 1200 * i / n, lambda i: 25 + 20 * i / n, 0.9)
    e = [(math.sin(math.pi * min(1.0, i / (n * 0.5))) ** 0.6) * (1 - i / n) ** 0.8 for i in range(n)]
    body = [body[i] * e[i] for i in range(n)]
    clicks = sticky_clicks(rnd, n, lambda i: 320 * (1 - i / n) + 40, f_lo=2500, f_hi=6500, amp=0.7, shape=lambda i: e[i])
    rel = release_tail(rnd, 2200, 600, 0.08, 0.5)
    r = rec(["slime_12", "slime_14"][seed % 2], 0.32, 0.7)
    out = mix(gain_list(body, 0.5 if r else 1.0), clicks, r)
    for i, v in enumerate(rel):
        j = int(n * 0.55) + i
        if j < n:
            out[j] += v
    return fade_edges(out)


def slice_crunch(seed):
    rnd = random.Random(seed)
    n = int(SR * 0.3)
    cl = sticky_clicks(rnd, n, lambda i: 700 * (1 - 0.6 * i / n), f_lo=1500, f_hi=7000, amp=1.0,
                       shape=lambda i: (1 - i / n) ** 0.5)
    return fade_edges(cl)


def jar_open(seed):
    n = int(SR * 0.2)
    out = []
    for i in range(n):
        e = (1 - i / n) ** 3
        f = 900 + 1400 * (i / n)
        out.append((math.sin(2 * math.pi * f * i / SR) * 0.7 + math.sin(2 * math.pi * 320 * i / SR) * 0.4) * e)
    rel = release_tail(random.Random(seed), 2500, 900, 0.05, 0.4, 0.015)
    return fade_edges(mix(out, rel))


def wet_loop(seed):
    """Seamless ~1 s stereo kneading bed: wandering wet body + sticky clicks, L/R decorrelated."""
    rnd = random.Random(seed)
    n = SR
    chans = []
    for ch in range(2):
        r2 = random.Random(seed * 7 + ch)
        body = wet_body(r2, n,
                        lambda i: 320 + 520 * (0.5 + 0.5 * math.sin(2 * math.pi * 1.7 * i / SR + ch)) + 260 * math.sin(2 * math.pi * 4.3 * i / SR + 1 + ch),
                        lambda i: 55 + 35 * math.sin(2 * math.pi * 0.8 * i / SR + ch * 2), 1.0)
        clicks = sticky_clicks(r2, n, lambda i: 70 + 40 * math.sin(2 * math.pi * 2.5 * i / SR + ch), amp=0.45)
        bubs = [0.0] * n
        for _ in range(5):
            b = bubble(r2, r2.uniform(500, 1300), 0.045, 0.25)
            t = r2.randint(0, n - len(b) - 1)
            for i, v in enumerate(b):
                bubs[t + i] += v
        bed = rec("loop_bubbles_1", None, 0.5, start_at_attack=False, fade_ms=0)
        if bed:
            off = int(SR * 0.6) * (ch + 1)
            bed = [bed[(off + i) % len(bed)] for i in range(n)]
        x = mix(body, clicks, bubs, bed)
        # crossfade tail into head so it loops
        f = int(SR * 0.08)
        for i in range(f):
            a = i / f
            x[i] = x[i] * a + x[n - f + i] * (1 - a)
        chans.append(x[: n - f])
    return chans


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "game/assets/sfx"
    os.makedirs(out, exist_ok=True)
    for k in range(5):
        write(os.path.join(out, f"squish{k}.wav"), squish(10 + k))
    for k in range(4):
        write(os.path.join(out, f"pop{k}.wav"), pop(20 + k))
    for k in range(3):
        write(os.path.join(out, f"squelch{k}.wav"), squelch(30 + k))
    for k in range(3):
        write(os.path.join(out, f"stretch{k}.wav"), stretch(40 + k))
    for k in range(3):
        write(os.path.join(out, f"crackle{k}.wav"), crackle(50 + k))
    for k in range(2):
        write(os.path.join(out, f"poof{k}.wav"), poof(60 + k))
    for k in range(2):
        write(os.path.join(out, f"slurp{k}.wav"), slurp(70 + k))
    for k in range(4):
        write(os.path.join(out, f"bubble{k}.wav"), bubble_pop(80 + k))
    for fam, fn in [("jelly", jelly), ("metal", metal), ("cloud", cloud), ("butter", butter), ("glow", glow), ("holo", holo), ("magic", magic)]:
        for k in range(3):
            write(os.path.join(out, f"{fam}{k}.wav"), fn(200 + k))
    write(os.path.join(out, "sprinkle.wav"), sprinkle(90))
    write(os.path.join(out, "click.wav"), click(91))
    for k in range(2):
        write(os.path.join(out, f"slice_wet{k}.wav"), slice_wet(100 + k))
    write(os.path.join(out, "slice_crunch.wav"), slice_crunch(102))
    write(os.path.join(out, "jar.wav"), jar_open(103))
    L, R = wet_loop(110)
    write(os.path.join(out, "wet_loop.wav"), None, stereo=(L, R))
