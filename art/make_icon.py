#!/usr/bin/env python3
"""Render the launcher icons (pure stdlib PNG writer, supersampled).

    python3 art/make_icon.py game/icons
Produces icon_192.png (legacy), fg_432.png + bg_432.png (adaptive), icon_512.png (store).
"""
import math, os, struct, sys, zlib

def lerp(a, b, t): return a + (b - a) * t

def blend(dst, src):  # premultiplied-free "over" with float rgba
    a = src[3]
    return tuple(lerp(dst[i], src[i], a) for i in range(3)) + (dst[3] + a * (1 - dst[3]),)

def render(size, with_bg, ss=3):
    W = size * ss
    px = [[(0.0, 0.0, 0.0, 0.0)] * W for _ in range(W)]
    bg = (0.17, 0.18, 0.26, 1.0)
    base = (0.44, 0.89, 0.42, 1.0)
    rim = (0.33, 0.73, 0.32, 1.0)
    cx, cy, R = W * 0.5, W * 0.54, W * 0.33
    for y in range(W):
        for x in range(W):
            c = bg if with_bg else (0.0, 0.0, 0.0, 0.0)
            # blobby radius: a circle with a soft bulge
            ang = math.atan2(y - cy, x - cx)
            r = R * (1 + 0.06 * math.cos(3 * ang + 0.8) + 0.03 * math.sin(5 * ang))
            d = math.hypot(x - cx, y - cy)
            if d < r:
                c = blend(c, rim)
                if d < r - W * 0.028:
                    c = blend(c, base)
                # highlight gradient (lighter up-left)
                hx, hy = cx - R * 0.42, cy - R * 0.5
                h = max(0.0, 1 - math.hypot(x - hx, y - hy) / (R * 1.1))
                c = blend(c, (1, 1, 1, 0.28 * h * h))
                # specular ellipse
                ex, ey = (x - (cx - R * 0.38)) / (R * 0.30), (y - (cy - R * 0.45)) / (R * 0.17)
                if ex * ex + ey * ey < 1:
                    c = blend(c, (1, 1, 1, 0.7))
            px[y][x] = c
    # downsample
    out = bytearray()
    for y in range(size):
        out.append(0)
        for x in range(size):
            acc = [0.0] * 4
            for dy in range(ss):
                for dx in range(ss):
                    p = px[y * ss + dy][x * ss + dx]
                    for i in range(4): acc[i] += p[i]
            out.extend(int(max(0, min(1, v / (ss * ss))) * 255 + 0.5) for v in acc)
    return bytes(out)

def png(path, size, raw):
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(data); print("wrote", path)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "game/icons"
    os.makedirs(out, exist_ok=True)
    png(os.path.join(out, "icon_192.png"), 192, render(192, True))
    png(os.path.join(out, "icon_512.png"), 512, render(512, True))
    png(os.path.join(out, "fg_432.png"), 432, render(432, False))
    # flat background for the adaptive icon
    bgraw = bytearray()
    for y in range(432):
        bgraw.append(0); bgraw.extend(bytes([43, 46, 66, 255]) * 432)
    png(os.path.join(out, "bg_432.png"), 432, bytes(bgraw))
