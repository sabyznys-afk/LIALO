"""Generate 1024x1024 Normal/Roughness/AO PBR maps & ghost ivory/shroud ink textures for v0.197 Priorita #5."""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(__file__))
OUT_DIR = os.path.join(ROOT, "assets", "textures", "tavern")


def _height_to_normal(height_img: Image.Image, strength: float = 2.4) -> Image.Image:
    w, h = height_img.size
    px = height_img.load()
    norm = Image.new("RGB", (w, h), (128, 128, 255))
    npx = norm.load()
    for y in range(h):
        ym = (y - 1) % h
        yp = (y + 1) % h
        for x in range(w):
            xm = (x - 1) % w
            xp = (x + 1) % w
            dx = (px[xp, y] - px[xm, y]) / 255.0 * strength
            dy = (px[x, yp] - px[x, ym]) / 255.0 * strength
            nx, ny, nz = -dx, -dy, 1.0
            ln = math.sqrt(nx * nx + ny * ny + nz * nz)
            npx[x, y] = (
                int((nx / ln * 0.5 + 0.5) * 255),
                int((ny / ln * 0.5 + 0.5) * 255),
                int((nz / ln * 0.5 + 0.5) * 255),
            )
    return norm


def gen_stone_maps():
    rng = random.Random(501)
    h = Image.new("L", (512, 512), 180)
    d = ImageDraw.Draw(h)
    rows = 8
    rh = 512 // rows
    for r in range(rows):
        y0 = r * rh
        d.line([(0, y0), (512, y0)], fill=35, width=6)
        cols = 4
        cw = 512 // cols
        off = (cw // 2) if (r % 2 == 1) else 0
        for c in range(cols + 1):
            x = (c * cw + off) % 512
            d.line([(x, y0), (x, y0 + rh)], fill=40, width=6)
    for _ in range(1800):
        px, py = rng.randint(0, 511), rng.randint(0, 511)
        d.point((px, py), fill=rng.randint(110, 235))
    h = h.filter(ImageFilter.GaussianBlur(1.2))
    n = _height_to_normal(h, 2.8).resize((1024, 1024), Image.BILINEAR)
    n.save(os.path.join(OUT_DIR, "tavern_stone_normal.png"))
    h.resize((1024, 1024), Image.BILINEAR).save(os.path.join(OUT_DIR, "tavern_stone_ao.png"))


def gen_wood_maps():
    rng = random.Random(502)
    h = Image.new("L", (512, 512), 160)
    d = ImageDraw.Draw(h)
    for x in range(0, 512, 5):
        v = 135 + int(28 * math.sin(x * 0.08)) + rng.randint(-14, 14)
        d.line([(x, 0), (x, 512)], fill=max(20, min(240, v)), width=2)
    for plank in range(0, 512, 128):
        d.line([(plank, 0), (plank, 512)], fill=28, width=5)
    h = h.filter(ImageFilter.GaussianBlur(0.8))
    _height_to_normal(h, 2.2).resize((1024, 1024), Image.BILINEAR).save(os.path.join(OUT_DIR, "tavern_wood_normal.png"))


def gen_ghost_textures():
    rng = random.Random(503)
    # 1024x1024 cracked ivory skull texture
    skull = Image.new("RGB", (1024, 1024), (206, 202, 188))
    sd = ImageDraw.Draw(skull)
    for _ in range(28):
        x0, y0 = rng.randint(60, 960), rng.randint(60, 960)
        pts = [(x0, y0)]
        for _ in range(5):
            x0 += rng.randint(-55, 55)
            y0 += rng.randint(-55, 55)
            pts.append((x0, y0))
        sd.line(pts, fill=(32, 34, 42), width=3)
    for _ in range(1200):
        hx, hy = rng.randint(0, 1000), rng.randint(0, 1020)
        sd.line([(hx, hy), (hx + rng.randint(8, 22), hy + rng.randint(-4, 4))], fill=(92, 96, 106), width=2)
    skull.save(os.path.join(OUT_DIR, "ghost_skull_ivory_ink.png"))

    # 1024x1024 tattered spectral shroud weave
    shroud = Image.new("RGB", (1024, 1024), (175, 205, 220))
    shd = ImageDraw.Draw(shroud)
    for y in range(0, 1024, 6):
        shd.line([(0, y), (1024, y)], fill=(120, 155, 175) if y % 12 == 0 else (190, 218, 232), width=2)
    for x in range(0, 1024, 6):
        shd.line([(x, 0), (x, 1024)], fill=(90, 130, 152), width=1)
    shroud.save(os.path.join(OUT_DIR, "ghost_shroud_weave_ink.png"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    gen_stone_maps()
    gen_wood_maps()
    gen_ghost_textures()
    print("Generated tavern PBR maps & ghost textures in", OUT_DIR)


if __name__ == "__main__":
    main()
