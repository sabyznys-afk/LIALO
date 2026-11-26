"""Generate 1024x1024 hand-inked particle sprite atlas + gallows_oak_ink.png for LIALO v0.197 Priorita #1."""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(__file__))
ATLAS_PATH = os.path.join(ROOT, "assets", "vfx", "relic_ink_particles_atlas.png")
OAK_PATH = os.path.join(ROOT, "assets", "textures", "relics", "gallows_oak_ink.png")


def draw_cell_smoke(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int, rng: random.Random):
    cx, cy = ox + s * 0.5, oy + s * 0.52
    for k in range(5):
        ang = k * 1.1
        rx = s * (0.18 - k * 0.02)
        ry = s * (0.24 - k * 0.025)
        px = cx + math.cos(ang) * s * 0.07
        py = cy + math.sin(ang) * s * 0.07 - k * 4
        alpha = 200 - k * 25
        d.ellipse([px - rx, py - ry, px + rx, py + ry], fill=(235, 228, 215, alpha), outline=(24, 18, 14, 210), width=4)
    # Ink curl strokes
    d.arc([cx - 56, cy - 64, cx + 48, cy + 44], 30, 250, fill=(24, 18, 14, 230), width=5)


def draw_cell_bubble(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int):
    cx, cy, r = ox + s // 2, oy + s // 2, int(s * 0.34)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(220, 220, 220, 95), outline=(22, 16, 14, 250), width=8)
    # Gouache highlight crescent
    d.arc([cx - r + 18, cy - r + 18, cx + r - 18, cy + r - 18], 200, 275, fill=(255, 250, 240, 245), width=10)
    d.ellipse([cx - r // 2, cy - r // 2, cx - r // 5, cy - r // 5], fill=(255, 250, 240, 235))


def draw_cell_rune(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int):
    cx, cy = ox + s // 2, oy + s // 2
    pts = [(cx, cy - 88), (cx, cy + 88)]
    d.line(pts, fill=(20, 14, 10, 255), width=18)
    d.line([(cx - 52, cy - 28), (cx, cy - 72), (cx + 52, cy - 24)], fill=(20, 14, 10, 255), width=14)
    d.line([(cx - 44, cy + 36), (cx + 44, cy - 6)], fill=(20, 14, 10, 255), width=14)
    d.line(pts, fill=(245, 245, 245, 255), width=9)
    d.line([(cx - 52, cy - 28), (cx, cy - 72), (cx + 52, cy - 24)], fill=(245, 245, 245, 255), width=7)
    d.line([(cx - 44, cy + 36), (cx + 44, cy - 6)], fill=(245, 245, 245, 255), width=7)


def draw_cell_flame(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int):
    cx, cy = ox + s // 2, oy + s // 2
    outer = [(cx, oy + 24), (cx + 56, cy - 10), (cx + 48, oy + s - 34), (cx, oy + s - 22), (cx - 48, oy + s - 34), (cx - 56, cy - 10)]
    d.polygon(outer, fill=(240, 235, 220, 245), outline=(22, 14, 10, 255), width=7)
    inner = [(cx, oy + 64), (cx + 26, cy + 12), (cx + 18, oy + s - 44), (cx - 18, oy + s - 44), (cx - 26, cy + 12)]
    d.polygon(inner, fill=(255, 252, 240, 255))


def draw_cell_droplet(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int):
    cx, cy = ox + s // 2, oy + s // 2
    pts = [(cx, oy + 30), (cx + 44, cy + 18), (cx + 36, oy + s - 36), (cx, oy + s - 22), (cx - 36, oy + s - 36), (cx - 44, cy + 18)]
    d.polygon(pts, fill=(235, 225, 220, 245), outline=(18, 10, 10, 255), width=7)
    d.ellipse([cx - 18, cy + 4, cx - 2, cy + 32], fill=(255, 250, 248, 235))


def draw_cell_sand(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int, rng: random.Random):
    for _ in range(26):
        px = ox + rng.randint(42, s - 42)
        py = oy + rng.randint(36, s - 36)
        r = rng.randint(5, 13)
        d.ellipse([px - r, py - r, px + r, py + r], fill=(248, 240, 215, rng.randint(170, 245)), outline=(26, 18, 12, 210), width=2)


def draw_cell_ripple(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int):
    cx, cy = ox + s // 2, oy + s // 2
    for r, w in [(88, 10), (56, 6)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(24, 18, 14, 240), width=w + 6)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(240, 236, 224, 235), width=w)


def draw_cell_spark(d: ImageDraw.ImageDraw, ox: int, oy: int, s: int):
    cx, cy = ox + s // 2, oy + s // 2
    pts = [(cx, oy + 24), (cx + 22, cy - 16), (ox + s - 24, cy), (cx + 22, cy + 16), (cx, oy + s - 24), (cx - 22, cy + 16), (ox + 24, cy), (cx - 22, cy - 16)]
    d.polygon(pts, fill=(252, 248, 235, 255), outline=(22, 16, 12, 245), width=6)


def generate_atlas():
    os.makedirs(os.path.dirname(ATLAS_PATH), exist_ok=True)
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(19701)
    cell = 256
    # Row 0: 0=smoke, 1=bubble, 2=rune, 3=flame
    draw_cell_smoke(d, 0 * cell, 0 * cell, cell, rng)
    draw_cell_bubble(d, 1 * cell, 0 * cell, cell)
    draw_cell_rune(d, 2 * cell, 0 * cell, cell)
    draw_cell_flame(d, 3 * cell, 0 * cell, cell)
    # Row 1: 4=droplet, 5=sand, 6=ripple, 7=spark
    draw_cell_droplet(d, 0 * cell, 1 * cell, cell)
    draw_cell_sand(d, 1 * cell, 1 * cell, cell, rng)
    draw_cell_ripple(d, 2 * cell, 1 * cell, cell)
    draw_cell_spark(d, 3 * cell, 1 * cell, cell)
    # Row 2 & 3: mirrored/rotated subtle variants for cells 8..15
    for idx in range(8):
        sx, sy = (idx % 4) * cell, (idx // 4) * cell
        dx, dy = (idx % 4) * cell, (2 + idx // 4) * cell
        crop = img.crop((sx, sy, sx + cell, sy + cell)).transpose(Image.FLIP_LEFT_RIGHT)
        img.paste(crop, (dx, dy))
    img.save(ATLAS_PATH)
    print("Generated", ATLAS_PATH)


def generate_gallows_oak():
    os.makedirs(os.path.dirname(OAK_PATH), exist_ok=True)
    rng = random.Random(19702)
    img = Image.new("RGB", (1024, 1024), (74, 54, 38))
    d = ImageDraw.Draw(img)
    # Vertical oak grain + charred/mossy knots & woodcut crosshatching
    for x in range(0, 1024, 6):
        c = 58 + int(18 * math.sin(x * 0.04)) + rng.randint(-8, 8)
        d.line([(x, 0), (x + rng.randint(-6, 6), 1024)], fill=(c, int(c * 0.72), int(c * 0.50)), width=rng.randint(2, 5))
    # Mossy weathered patches & dark ink grain
    for _ in range(42):
        kx, ky = rng.randint(40, 984), rng.randint(40, 984)
        rw, rh = rng.randint(18, 46), rng.randint(48, 120)
        d.ellipse([kx - rw, ky - rh, kx + rw, ky + rh], outline=(26, 20, 14), width=3)
        if rng.random() < 0.45:
            d.ellipse([kx - rw // 2, ky - rh // 2, kx + rw // 2, ky + rh // 2], fill=(56, 72, 42))
    # Woodcut horizontal hatch ticks
    for _ in range(900):
        hx, hy = rng.randint(0, 1000), rng.randint(0, 1020)
        d.line([(hx, hy), (hx + rng.randint(10, 26), hy + rng.randint(-2, 3))], fill=(24, 18, 12), width=2)
    img = img.filter(ImageFilter.SMOOTH_MORE)
    img.save(OAK_PATH)
    print("Generated", OAK_PATH)


if __name__ == "__main__":
    generate_atlas()
    generate_gallows_oak()
