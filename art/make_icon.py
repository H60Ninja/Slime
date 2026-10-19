#!/usr/bin/env python3
"""Render launcher icons and the Play feature graphic (pure stdlib PNG writer, supersampled).

    python3 art/make_icon.py game/icons store
Produces icon_192.png, icon_512.png, fg_432.png, bg_432.png and store/feature-graphic.png (1024x500).
"""
import math, os, struct, sys, zlib

def lerp(a, b, t): return a + (b - a) * t

def over(dst, src):
    a = src[3]
    return tuple(lerp(dst[i], src[i], a) for i in range(3)) + (dst[3] + a * (1 - dst[3]),)

def blob_field(x, y, lobes):
    """Metaball field of a few circles -> >1 inside."""
    f = 0.0
    for (cx, cy, r) in lobes:
        d2 = (x - cx) ** 2 + (y - cy) ** 2
        f += (r * r) / max(d2, 1e-6)
    return f

def shade_blob(x, y, lobes, base, rim, light):
    """Returns rgba for a glossy blob pixel (None if outside)."""
    f = blob_field(x, y, lobes)
    if f < 1.0:
        return None
    # approximate normal from field gradient
    e = 1.5
    gx = blob_field(x + e, y, lobes) - blob_field(x - e, y, lobes)
    gy = blob_field(x, y + e, lobes) - blob_field(x, y - e, lobes)
    edge = min(1.0, (f - 1.0) * 2.2)          # 0 at edge .. 1 inside
    nz = edge
    nl = math.sqrt(gx * gx + gy * gy) + 1e-6
    nx, ny = gx / nl * (1 - edge), gy / nl * (1 - edge)
    ndl = max(0.0, nx * light[0] + ny * light[1] + nz * light[2])
    diff = 0.55 + 0.45 * ndl
    h = (light[0], light[1], light[2] + 1.0)
    hl = math.sqrt(sum(v * v for v in h))
    spec = max(0.0, (nx * h[0] + ny * h[1] + nz * h[2]) / hl) ** 40 * 0.7
    col = rim if edge < 0.18 else base
    return (min(1, col[0] * diff + spec), min(1, col[1] * diff + spec), min(1, col[2] * diff + spec), 1.0)

def render(w, h, ss, paint):
    W, H = w * ss, h * ss
    out = bytearray()
    rows = []
    for Y in range(H):
        row = []
        for X in range(W):
            row.append(paint(X / ss, Y / ss))
        rows.append(row)
    for y in range(h):
        out.append(0)
        for x in range(w):
            acc = [0.0] * 4
            for dy in range(ss):
                for dx in range(ss):
                    p = rows[y * ss + dy][x * ss + dx]
                    for i in range(4): acc[i] += p[i]
            out.extend(int(max(0, min(1, v / (ss * ss))) * 255 + 0.5) for v in acc)
    return bytes(out)

def png(path, w, h, raw):
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(data); print("wrote", path)

BG = (0.17, 0.18, 0.26, 1.0)
GREEN = (0.44, 0.89, 0.42)
GREEN_RIM = (0.30, 0.70, 0.30)
LIGHT = (-0.5, -0.6, 0.65)
BEADS = [((0.42, 0.56), (1.0, 0.56, 0.81)), ((0.60, 0.50), (0.56, 0.85, 1.0)), ((0.53, 0.68), (1.0, 0.89, 0.42))]

def icon_paint(size, with_bg):
    lobes = [(size * 0.50, size * 0.56, size * 0.27), (size * 0.36, size * 0.44, size * 0.17), (size * 0.65, size * 0.48, size * 0.15)]
    def paint(x, y):
        c = BG if with_bg else (0.0, 0.0, 0.0, 0.0)
        # soft shadow
        sf = blob_field(x - size * 0.02, y - size * 0.035, lobes)
        if sf >= 1.0:
            c = over(c, (0, 0, 0, 0.25))
        b = shade_blob(x, y, lobes, GREEN, GREEN_RIM, LIGHT)
        if b:
            c = over(c, b)
            # beads embedded
            for (bx, by), bc in BEADS:
                d = math.hypot(x - bx * size, y - by * size)
                r = size * 0.045
                if d < r:
                    hi = 1.0 if math.hypot(x - bx * size + r * 0.35, y - by * size + r * 0.35) < r * 0.3 else 0.0
                    c = over(c, (bc[0], bc[1], bc[2], 0.9))
                    c = over(c, (1, 1, 1, 0.7 * hi))
            # big specular highlight
            ex, ey = (x - size * 0.40) / (size * 0.11), (y - size * 0.40) / (size * 0.065)
            if ex * ex + ey * ey < 1:
                c = over(c, (1, 1, 1, 0.75))
        # sparkle star top-right
        sx, sy = size * 0.80, size * 0.22
        d = math.hypot(x - sx, y - sy)
        ang = math.atan2(y - sy, x - sx)
        star_r = size * 0.07 * (0.35 + 0.65 * abs(math.cos(2 * ang)) ** 6)
        if d < star_r:
            c = over(c, (1, 1, 1, 0.95))
        return c
    return paint

def feature_paint(w, h):
    lobes = [(w * 0.30, h * 0.58, h * 0.30), (w * 0.22, h * 0.45, h * 0.18), (w * 0.40, h * 0.50, h * 0.17)]
    def paint(x, y):
        t = y / h
        u = x / w
        c = (lerp(0.98, 0.93, t) * (1 - 0.04 * u), lerp(0.96, 0.88, t), lerp(0.93, 0.80, t), 1.0)
        sf = blob_field(x - 10, y - 16, lobes)
        if sf >= 1.0:
            c = over(c, (0, 0, 0, 0.18))
        b = shade_blob(x, y, lobes, (1.0, 0.37, 0.72), (0.80, 0.22, 0.55), LIGHT)
        if b:
            c = over(c, b)
            ex, ey = (x - w * 0.25) / (h * 0.11), (y - h * 0.40) / (h * 0.065)
            if ex * ex + ey * ey < 1:
                c = over(c, (1, 1, 1, 0.7))
        # drops of colour falling on the right
        for (dx, dy, dc) in [(0.62, 0.30, (0.44, 0.89, 0.42)), (0.74, 0.55, (0.31, 0.72, 1.0)), (0.86, 0.35, (1.0, 0.89, 0.30)), (0.70, 0.78, (0.62, 0.42, 1.0))]:
            r = h * 0.075
            cx, cy = dx * w, dy * h
            d = math.hypot(x - cx, y - cy)
            tail = (abs(x - cx) < r * 0.5 * max(0.0, 1 - (cy - y) / (r * 1.8))) and (cy - r * 1.8 < y < cy)
            if d < r or tail:
                c = over(c, (dc[0], dc[1], dc[2], 1.0))
                if math.hypot(x - cx + r * 0.35, y - cy + r * 0.3) < r * 0.28:
                    c = over(c, (1, 1, 1, 0.7))
        # sparkles
        for (sx, sy, sr) in [(0.55, 0.15, 0.05), (0.93, 0.75, 0.04), (0.50, 0.85, 0.035)]:
            d = math.hypot(x - sx * w, y - sy * h)
            ang = math.atan2(y - sy * h, x - sx * w)
            star_r = h * sr * (0.3 + 0.7 * abs(math.cos(2 * ang)) ** 6)
            if d < star_r:
                c = over(c, (1, 1, 1, 0.95))
        return c
    return paint

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "game/icons"
    store = sys.argv[2] if len(sys.argv) > 2 else "store"
    os.makedirs(out, exist_ok=True); os.makedirs(store, exist_ok=True)
    png(os.path.join(out, "icon_114.png"), 114, 114, render(114, 114, 4, icon_paint(114, True)))
    png(os.path.join(out, "icon_192.png"), 192, 192, render(192, 192, 3, icon_paint(192, True)))
    png(os.path.join(out, "icon_512.png"), 512, 512, render(512, 512, 2, icon_paint(512, True)))
    png(os.path.join(out, "fg_432.png"), 432, 432, render(432, 432, 2, icon_paint(432, False)))
    bgraw = bytearray()
    for y in range(432):
        bgraw.append(0); bgraw.extend(bytes([43, 46, 66, 255]) * 432)
    png(os.path.join(out, "bg_432.png"), 432, 432, bytes(bgraw))
    png(os.path.join(store, "feature-graphic.png"), 1024, 500, render(1024, 500, 2, feature_paint(1024, 500)))
