"""Build & post-process all 16 Living 2.5D Power Card sprites into assets/vfx/power_25d/.

Produces:
  - 3 AI-generated woodcut hero sprites (border white flood-fill)
  - 7 hand-drawn woodcut hero sprites extracted from assets/cards/SPEC_*.png
  - 2 independent spinning woodcut rings + 4 woodcut particle sprites (2x SSAA)
  - 1 dark-background 4x4 cutout inspection sheet in the artifact directory
"""

import math
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "vfx" / "power_25d"
CARDS_DIR = ROOT / "assets" / "cards"
ARTIFACT_DIR = Path(r"C:\Users\lostv\.gemini\antigravity\brain\bbdbfa05-ae04-40d3-887b-1696a0626a58")

GENERATED_HEROES = {
    "midas_gauntlet_2d": ARTIFACT_DIR / "raw_midas_gauntlet_2d_1795731019709.jpg",
    "hex_grimoire_2d": ARTIFACT_DIR / "hex_grimoire_2d_1795731035575.jpg",
    "magnet_sigil_2d": ARTIFACT_DIR / "raw_magnet_sigil_2d_1795731052213.jpg",
}

EXTRACTED_CARDS = {
    "chronos_astrolabe_2d": (CARDS_DIR / "SPEC_CHRONOS.png", 768),
    "oracle_eye_2d": (CARDS_DIR / "SPEC_ORACLE.png", 768),
    "jester_mask_2d": (CARDS_DIR / "SPEC_JESTER.png", 768),
    "bastion_shield_2d": (CARDS_DIR / "SPEC_SHIELD.png", 768),
    "gambler_dice_2d": (CARDS_DIR / "SPEC_GAMBLER.png", 384),
    "plague_frost_2d": (CARDS_DIR / "SPEC_PLAGUE.png", 768),
    "sovereign_crown_2d": (CARDS_DIR / "SPEC_CROWN.png", 768),
}


def _decontaminate_and_center(img: Image.Image, target_size: int, fringe_lum: float = 195.0) -> Image.Image:
    w, h = img.size
    px = img.load()
    to_soften = []
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            bg_n = 0
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if px[nx, ny][3] == 0:
                    bg_n += 1
            if bg_n > 0:
                lum = (r + g + b) / 3.0
                chroma = max(r, g, b) - min(r, g, b)
                if lum > fringe_lum and chroma < 38:
                    new_a = max(0, int(a * (1.0 - 0.38 * bg_n)))
                    to_soften.append((x, y, (int(r * 0.35), int(g * 0.35), int(b * 0.35), new_a)))
                elif bg_n >= 2:
                    to_soften.append((x, y, (r, g, b, int(a * 0.86))))
    for x, y, rgba in to_soften:
        px[x, y] = rgba

    bbox = img.getbbox()
    if bbox is None:
        raise ValueError("Sprite became completely transparent!")
    cropped = img.crop(bbox)
    cw, ch = cropped.size
    max_inner = int(target_size * 0.90)
    scale = min(max_inner / cw, max_inner / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    ox = (target_size - nw) // 2
    oy = (target_size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def process_generated_white_bg(name: str, src_path: Path, target_size: int = 768) -> Image.Image:
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    px = img.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def is_white(r: int, g: int, b: int, a: int) -> bool:
        return a < 16 or (min(r, g, b) >= 232 and (max(r, g, b) - min(r, g, b)) <= 26)

    def try_seed(x: int, y: int) -> None:
        if not visited[y][x] and is_white(*px[x, y]):
            visited[y][x] = True
            q.append((x, y))

    for x in range(w):
        try_seed(x, 0)
        try_seed(x, h - 1)
    for y in range(h):
        try_seed(0, y)
        try_seed(w - 1, y)
    # Also seed center for enclosed interior holes like magnet_sigil_2d horseshoe U-gap
    if name == "magnet_sigil_2d":
        try_seed(w // 2, h // 2)

    while q:
        cx, cy = q.popleft()
        px[cx, cy] = (0, 0, 0, 0)
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and is_white(*px[nx, ny]):
                visited[ny][nx] = True
                q.append((nx, ny))

    out = _decontaminate_and_center(img, target_size, 205.0)
    out.save(OUT_DIR / f"{name}.png", "PNG")
    print(f"OK generated {name}.png {out.size}")
    return out


def extract_card_woodcut(name: str, card_path: Path, target_size: int) -> Image.Image:
    full = Image.open(card_path).convert("RGBA")
    fw, fh = full.size
    # Strictly inside the inner parchment art box so no card border leaks in
    crop_box = (int(fw * 0.115), int(fh * 0.145), int(fw * 0.885), int(fh * 0.675))
    img = full.crop(crop_box)
    w, h = img.size
    px = img.load()

    # Sample median parchment color from the 4 corners
    samples = []
    for sx in (2, 8, w - 9, w - 3):
        for sy in (2, 8, h - 9, h - 3):
            samples.append(px[sx, sy][:3])
    pr = sorted(s[0] for s in samples)[len(samples) // 2]
    pg = sorted(s[1] for s in samples)[len(samples) // 2]
    pb = sorted(s[2] for s in samples)[len(samples) // 2]

    def is_parchment(r: int, g: int, b: int, a: int, y_pos: int = 999) -> bool:
        if a < 16:
            return True
        dist = math.sqrt((r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2)
        lum = (r + g + b) / 3.0
        chroma = max(r, g, b) - min(r, g, b)
        if y_pos < int(h * 0.34) and lum > 152.0 and chroma < 30 and dist < 68.0:
            return True
        return dist < 38.0 or (lum > 178.0 and chroma < 28 and dist < 66.0)

    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def try_seed(x: int, y: int) -> None:
        if not visited[y][x] and is_parchment(*px[x, y], y):
            visited[y][x] = True
            q.append((x, y))

    for x in range(w):
        try_seed(x, 0)
        try_seed(x, h - 1)
    for y in range(h):
        try_seed(0, y)
        try_seed(w - 1, y)

    while q:
        cx, cy = q.popleft()
        px[cx, cy] = (0, 0, 0, 0)
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx] and is_parchment(*px[nx, ny], ny):
                visited[ny][nx] = True
                q.append((nx, ny))

    # Connected-component filter on opaque pixels to remove stray sunray/dust specks
    comp_vis = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0 and not comp_vis[y][x]:
                comp = []
                cq: deque[tuple[int, int]] = deque([(x, y)])
                comp_vis[y][x] = True
                while cq:
                    cx, cy = cq.popleft()
                    comp.append((cx, cy))
                    for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                        if 0 <= nx < w and 0 <= ny < h and not comp_vis[ny][nx] and px[nx, ny][3] > 0:
                            comp_vis[ny][nx] = True
                            cq.append((nx, ny))
                if len(comp) < 900:
                    for cx, cy in comp:
                        px[cx, cy] = (0, 0, 0, 0)

    # Mild contrast & color boost while preserving alpha
    r_ch, g_ch, b_ch, a_ch = img.split()
    rgb = Image.merge("RGB", (r_ch, g_ch, b_ch))
    rgb = ImageEnhance.Color(rgb).enhance(1.22)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.12)
    r2, g2, b2 = rgb.split()
    img = Image.merge("RGBA", (r2, g2, b2, a_ch))

    out = _decontaminate_and_center(img, target_size, 185.0)
    out.save(OUT_DIR / f"{name}.png", "PNG")
    print(f"OK extracted {name}.png {out.size}")
    return out


def _ink_poly(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill, outline=(18, 13, 10, 255), width: int = 8) -> None:
    draw.polygon(pts, fill=fill)
    draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def build_chronos_gear_ring(size: int = 768) -> Image.Image:
    ss = size * 2
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = ss / 2.0
    ink = (18, 12, 8, 255)
    brass = (196, 152, 62, 255)
    brass_hi = (232, 194, 96, 255)
    brass_dk = (128, 92, 34, 255)
    cyan = (110, 232, 255, 255)

    # 24 gear teeth around outer perimeter
    r_out = ss * 0.42
    r_tooth = ss * 0.465
    for i in range(24):
        a0 = (i / 24.0) * math.tau - 0.055
        a1 = (i / 24.0) * math.tau + 0.055
        pts = [
            (cx + math.cos(a0 - 0.02) * (r_out - 12), cy + math.sin(a0 - 0.02) * (r_out - 12)),
            (cx + math.cos(a0) * r_tooth, cy + math.sin(a0) * r_tooth),
            (cx + math.cos(a1) * r_tooth, cy + math.sin(a1) * r_tooth),
            (cx + math.cos(a1 + 0.02) * (r_out - 12), cy + math.sin(a1 + 0.02) * (r_out - 12)),
        ]
        _ink_poly(d, pts, brass if i % 2 == 0 else brass_dk, ink, 7)

    # Main concentric hollow ring
    d.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=brass, outline=ink, width=10)
    r_mid = ss * 0.375
    d.ellipse([cx - r_mid, cy - r_mid, cx + r_mid, cy + r_mid], fill=brass_dk, outline=ink, width=7)
    r_in_ring = ss * 0.325
    d.ellipse([cx - r_in_ring, cy - r_in_ring, cx + r_in_ring, cy + r_in_ring], fill=brass_hi, outline=ink, width=8)

    # Cutout hollow center!
    r_hole = ss * 0.285
    d.ellipse([cx - r_hole, cy - r_hole, cx + r_hole, cy + r_hole], fill=(0, 0, 0, 0), outline=ink, width=10)

    # Radial engraving tick marks & 12 glowing cyan zodiac runes
    for i in range(48):
        a = (i / 48.0) * math.tau
        r0 = r_in_ring + 4
        r1 = r_out - 8 if i % 4 == 0 else r_mid - 4
        d.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)], fill=ink, width=5 if i % 4 == 0 else 3)

    for i in range(12):
        a = (i / 12.0) * math.tau
        rx = cx + math.cos(a) * (ss * 0.35)
        ry = cy + math.sin(a) * (ss * 0.35)
        d.ellipse([rx - 14, ry - 14, rx + 14, ry + 14], fill=cyan, outline=ink, width=5)

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "chronos_gear_ring_2d.png", "PNG")
    print(f"OK built chronos_gear_ring_2d.png {out.size}")
    return out


def build_gambler_wheel(size: int = 768) -> Image.Image:
    ss = size * 2
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = ss / 2.0
    ink = (18, 12, 10, 255)
    gold = (224, 176, 64, 255)
    silver = (206, 210, 218, 255)
    crimson = (168, 38, 46, 255)
    ivory = (232, 220, 188, 255)

    r_rim = ss * 0.43
    # 16 outer spiked finials
    for i in range(16):
        a = (i / 16.0) * math.tau
        pts = [
            (cx + math.cos(a - 0.08) * (r_rim - 14), cy + math.sin(a - 0.08) * (r_rim - 14)),
            (cx + math.cos(a) * (r_rim + 48), cy + math.sin(a) * (r_rim + 48)),
            (cx + math.cos(a + 0.08) * (r_rim - 14), cy + math.sin(a + 0.08) * (r_rim - 14)),
        ]
        _ink_poly(d, pts, gold, ink, 8)

    d.ellipse([cx - r_rim, cy - r_rim, cx + r_rim, cy + r_rim], fill=gold, outline=ink, width=10)
    r_inner = ss * 0.365
    # 12 alternating fortune wedges
    for i in range(12):
        a0 = i * 30.0
        a1 = (i + 1) * 30.0
        col = [ivory, crimson, silver][i % 3]
        d.pieslice([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner], start=a0, end=a1, fill=col, outline=ink, width=8)

    # Rim rivets
    for i in range(24):
        a = (i / 24.0) * math.tau
        rx = cx + math.cos(a) * (ss * 0.398)
        ry = cy + math.sin(a) * (ss * 0.398)
        d.ellipse([rx - 10, ry - 10, rx + 10, ry + 10], fill=silver, outline=ink, width=4)

    # Center hub medallion
    r_hub = ss * 0.11
    d.ellipse([cx - r_hub, cy - r_hub, cx + r_hub, cy + r_hub], fill=gold, outline=ink, width=10)
    r_gem = ss * 0.055
    d.ellipse([cx - r_gem, cy - r_gem, cx + r_gem, cy + r_gem], fill=crimson, outline=ink, width=7)

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "gambler_wheel_2d.png", "PNG")
    print(f"OK built gambler_wheel_2d.png {out.size}")
    return out


def build_gold_florin(size: int = 384) -> Image.Image:
    ss = size * 2
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = ss / 2.0
    ink = (20, 14, 8, 255)
    gold = (232, 184, 58, 255)
    gold_hi = (252, 224, 118, 255)
    gold_dk = (164, 114, 28, 255)

    r0 = ss * 0.43
    d.ellipse([cx - r0, cy - r0, cx + r0, cy + r0], fill=gold, outline=ink, width=12)
    r1 = ss * 0.36
    d.ellipse([cx - r1, cy - r1, cx + r1, cy + r1], fill=gold_dk, outline=ink, width=8)
    r2 = ss * 0.31
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=gold_hi, outline=ink, width=7)
    # Beaded rim
    for i in range(24):
        a = (i / 24.0) * math.tau
        bx = cx + math.cos(a) * (ss * 0.395)
        by = cy + math.sin(a) * (ss * 0.395)
        d.ellipse([bx - 8, by - 8, bx + 8, by + 8], fill=gold_hi, outline=ink, width=4)
    # Embossed 3-point royal crown
    crown_pts = [
        (cx - 110, cy + 75),
        (cx - 135, cy - 55),
        (cx - 55, cy + 5),
        (cx, cy - 110),
        (cx + 55, cy + 5),
        (cx + 135, cy - 55),
        (cx + 110, cy + 75),
    ]
    _ink_poly(d, crown_pts, gold, ink, 9)
    d.rectangle([cx - 115, cy + 75, cx + 115, cy + 108], fill=gold_dk, outline=ink, width=8)
    # Woodcut crosshatching
    for hx in range(-180, 181, 24):
        d.line([(cx + hx, cy - 160), (cx + hx - 30, cy - 110)], fill=(45, 30, 12, 110), width=3)

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "gold_florin_2d.png", "PNG")
    print(f"OK built gold_florin_2d.png {out.size}")
    return out


def build_jester_card(size: int = 384) -> Image.Image:
    ss = size * 2
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = ss / 2.0
    ink = (18, 12, 14, 255)
    parch = (234, 220, 186, 255)
    mag = (196, 48, 152, 255)
    gold = (232, 184, 58, 255)

    # Torn medieval playing card silhouette
    card_pts = [
        (cx - 160, cy - 245),
        (cx + 150, cy - 235),
        (cx + 168, cy + 125),
        (cx + 95, cy + 165),
        (cx + 125, cy + 235),
        (cx - 35, cy + 245),
        (cx - 155, cy + 215),
    ]
    _ink_poly(d, card_pts, parch, ink, 12)
    inner = [(cx - 122, cy - 205), (cx + 118, cy - 198), (cx + 126, cy + 175), (cx - 118, cy + 182)]
    d.line(inner + [inner[0]], fill=ink, width=6)
    # Center jester diamond & bells motif
    diam = [(cx, cy - 115), (cx + 85, cy), (cx, cy + 115), (cx - 85, cy)]
    _ink_poly(d, diam, mag, ink, 9)
    diam_in = [(cx, cy - 62), (cx + 46, cy), (cx, cy + 62), (cx - 46, cy)]
    _ink_poly(d, diam_in, gold, ink, 7)

    img = img.rotate(14, resample=Image.Resampling.BICUBIC)
    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "jester_card_2d.png", "PNG")
    print(f"OK built jester_card_2d.png {out.size}")
    return out


def build_hex_thorn(size: int = 384) -> Image.Image:
    ss = size * 2
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = ss / 2.0
    ink = (14, 10, 18, 255)
    iron = (56, 46, 72, 255)
    iron_hi = (108, 86, 138, 255)
    violet = (182, 86, 255, 255)

    # Jagged barbed iron thorn shard
    pts = [
        (cx, cy - 305),
        (cx + 58, cy - 110),
        (cx + 125, cy - 135),
        (cx + 72, cy + 15),
        (cx + 110, cy + 145),
        (cx + 38, cy + 120),
        (cx, cy + 295),
        (cx - 42, cy + 115),
        (cx - 115, cy + 140),
        (cx - 72, cy + 12),
        (cx - 120, cy - 130),
        (cx - 56, cy - 110),
    ]
    _ink_poly(d, pts, iron, ink, 11)
    left_facet = [(cx, cy - 305), (cx, cy + 295), (cx - 42, cy + 115), (cx - 72, cy + 12), (cx - 56, cy - 110)]
    _ink_poly(d, left_facet, iron_hi, ink, 7)
    vein = [(cx, cy - 180), (cx + 18, cy), (cx, cy + 170), (cx - 18, cy)]
    _ink_poly(d, vein, violet, ink, 6)

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "hex_thorn_2d.png", "PNG")
    print(f"OK built hex_thorn_2d.png {out.size}")
    return out


def build_frost_crystal(size: int = 384) -> Image.Image:
    ss = size * 2
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = ss / 2.0
    ink = (14, 22, 26, 255)
    ice = (96, 224, 210, 255)
    ice_hi = (204, 252, 248, 255)
    ice_dk = (44, 152, 146, 255)

    # Central + 2 side faceted ice crystal spires
    for dx, dy, sc in [(-95, 55, 0.56), (95, 55, 0.56), (0, 0, 1.0)]:
        px0 = cx + dx
        py0 = cy + dy
        outer = [
            (px0, py0 - 285 * sc),
            (px0 + 95 * sc, py0 - 95 * sc),
            (px0 + 75 * sc, py0 + 210 * sc),
            (px0, py0 + 280 * sc),
            (px0 - 75 * sc, py0 + 210 * sc),
            (px0 - 95 * sc, py0 - 95 * sc),
        ]
        _ink_poly(d, outer, ice, ink, 10)
        hi = [(px0, py0 - 285 * sc), (px0, py0 + 280 * sc), (px0 - 75 * sc, py0 + 210 * sc), (px0 - 95 * sc, py0 - 95 * sc)]
        _ink_poly(d, hi, ice_hi, ink, 7)
        dk = [(px0, py0 - 110 * sc), (px0 + 95 * sc, py0 - 95 * sc), (px0 + 75 * sc, py0 + 210 * sc), (px0, py0 + 280 * sc)]
        _ink_poly(d, dk, ice_dk, ink, 7)

    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "frost_crystal_2d.png", "PNG")
    print(f"OK built frost_crystal_2d.png {out.size}")
    return out


def save_cutout_check_sheet(sprites: list[tuple[str, Image.Image]]) -> None:
    cols = 4
    rows = 4
    cell = 260
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (24, 18, 14, 255))
    d = ImageDraw.Draw(sheet)
    for idx, (name, sp) in enumerate(sprites[:16]):
        r, c = divmod(idx, cols)
        x0, y0 = c * cell, r * cell
        d.rectangle([x0 + 4, y0 + 4, x0 + cell - 4, y0 + cell - 4], outline=(90, 72, 48, 255), width=2)
        thumb = sp.resize((210, 210), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x0 + 25, y0 + 16), thumb)
        d.text((x0 + 14, y0 + 232), name, fill=(240, 216, 156, 255))
    out_sheet = ARTIFACT_DIR / "p2b_sprites_cutout_check.png"
    sheet.save(out_sheet, "PNG")
    print(f"Saved cutout check sheet -> {out_sheet}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    results: list[tuple[str, Image.Image]] = []
    for name, src in GENERATED_HEROES.items():
        results.append((name, process_generated_white_bg(name, src, 768)))
    for name, (src, sz) in EXTRACTED_CARDS.items():
        results.append((name, extract_card_woodcut(name, src, sz)))
    results.append(("chronos_gear_ring_2d", build_chronos_gear_ring(768)))
    results.append(("gambler_wheel_2d", build_gambler_wheel(768)))
    results.append(("gold_florin_2d", build_gold_florin(384)))
    results.append(("jester_card_2d", build_jester_card(384)))
    results.append(("hex_thorn_2d", build_hex_thorn(384)))
    results.append(("frost_crystal_2d", build_frost_crystal(384)))
    save_cutout_check_sheet(results)


if __name__ == "__main__":
    main()
