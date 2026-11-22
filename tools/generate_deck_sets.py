"""
Generates 5 completely distinct, museum-grade hand-drawn medieval woodcut/manuscript card backs (540x810 RGBA):
  - assets/table/deck_back_klasic.png     (Classic Leather: bespoke 1480s stitched tavern leather, brass corners & tankard woodcut)
  - assets/table/deck_back_antika.png     (Pharaoh's Vault: woven papyrus & lapis, lotus frieze, engraved palmette brackets, scarab)
  - assets/table/deck_back_rim.png        (Legion's Aegis: hammered vermilion scutum, Greek-key border, engraved acanthus brackets, Aquila)
  - assets/table/deck_back_stredovek.png  (Iron Crown: Gothic quatrefoil diaper ironwork & emerald lancet arch, Wenceslas crown & halberds)
  - assets/table/deck_back_objavy.png     (Corsair's Grip: portolan sea-chart grid, hemp-rope frame, engraved windrose brackets, caravel & anchor)
Also copies deck_back_klasic.png -> assets/table/card_back.png (original preserved at tools/backup_table_orig/card_back.png).
"""
import math
import pathlib
import shutil
import numpy as np
import scipy.ndimage as ndi
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = pathlib.Path(r"D:\downpour-godot")
TABLE_DIR = ROOT / "assets" / "table"
RENDER_DIR = ROOT / "tools" / "power_renders"
BACKUP_DIR = ROOT / "tools" / "backup_table_orig"
ARTIFACT_DIR = pathlib.Path(r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d")

OUT_W, OUT_H = 540, 810
W, H = 1080, 1620
CX, CY = W // 2, H // 2
INK = (24, 15, 9, 255)
INK_SOFT = (46, 30, 18, 220)


def ensure_backup() -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    src = TABLE_DIR / "card_back.png"
    dst = BACKUP_DIR / "card_back.png"
    if src.exists() and not dst.exists():
        shutil.copy2(src, dst)


def make_aged_ground(base_rgb: tuple, grain_sigma: float = 9.0, stains: int = 22, seed: int = 100, pattern: str = "none") -> Image.Image:
    rng = np.random.default_rng(seed)
    low = ndi.gaussian_filter(rng.normal(0.0, 1.0, (H // 8, W // 8)).astype(np.float32), sigma=4.0)
    low = (low - low.min()) / max(1e-5, low.max() - low.min())
    low_up = np.array(Image.fromarray((low * 255).astype(np.uint8)).resize((W, H), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    rx = np.abs(xx - CX) / (W * 0.5)
    ry = np.abs(yy - CY) / (H * 0.5)
    vig = np.clip((rx ** 2.2 + ry ** 2.2) * 0.44, 0.0, 0.56)

    fine = rng.normal(0.0, grain_sigma, (H, W, 1)).astype(np.float32)
    fiber_h = np.sin((yy + low_up * 5.0) * (math.pi / 9.0)) * 3.0

    arr = np.zeros((H, W, 3), dtype=np.float32)
    for ci, bv in enumerate(base_rgb):
        arr[:, :, ci] = bv * (0.90 + 0.20 * low_up) * (1.0 - vig * 0.34)
    arr += fine + fiber_h[:, :, None]

    # Subtle per-theme embossed craft texture
    if pattern == "antika":
        # Criss-cross woven papyrus strips
        reed_h = np.sin((yy + low_up * 4.0) * (math.pi / 6.0)) * 4.5
        reed_v = np.sin((xx + low_up * 4.0) * (math.pi / 11.0)) * 3.2
        arr += (reed_h + reed_v)[:, :, None]
    elif pattern == "rim":
        # Hammered crimson-leather & bronze grain dimples
        cell = ndi.gaussian_filter(rng.normal(0.0, 1.0, (H // 6, W // 6)).astype(np.float32), sigma=1.6)
        cell_up = np.array(Image.fromarray(np.clip((cell * 0.25 + 0.5) * 255, 0, 255).astype(np.uint8)).resize((W, H), Image.Resampling.BICUBIC), dtype=np.float32) - 127.5
        arr += (cell_up * 0.16)[:, :, None]
    elif pattern == "stredovek":
        # Embossed Gothic diamond & quatrefoil ironwork diaper pattern
        d_a = np.abs(np.sin((xx + yy) * (math.pi / 120.0)))
        d_b = np.abs(np.sin((xx - yy) * (math.pi / 120.0)))
        lattice = np.exp(-((np.minimum(d_a, d_b)) ** 2) / 0.015) * -9.0
        q_dot = np.exp(-(((d_a - 0.85) ** 2 + (d_b - 0.85) ** 2) / 0.03)) * 5.5
        arr += (lattice + q_dot)[:, :, None]
    elif pattern == "objavy":
        # Faded portolan cartographer chart grid + tide watermark lines
        gx = np.exp(-((np.mod(xx, 135.0) - 67.5) ** 2) / 3.0) * -8.0
        gy = np.exp(-((np.mod(yy, 135.0) - 67.5) ** 2) / 3.0) * -8.0
        arr += (gx + gy)[:, :, None]

    for _ in range(stains):
        sx = rng.uniform(50, W - 50)
        sy = rng.uniform(50, H - 50)
        sr = rng.uniform(40, 165)
        dist2 = ((xx - sx) ** 2 + (yy - sy) ** 2) / (sr ** 2)
        arr += (np.exp(-dist2 * 1.8) * rng.uniform(-14.0, 9.0))[:, :, None]

    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def hand_line(d: ImageDraw.ImageDraw, p0: tuple, p1: tuple, fill=INK, width: int = 5, seed: int = 1, amp: float = 2.4) -> None:
    rng = np.random.default_rng(seed)
    x0, y0 = p0
    x1, y1 = p1
    dx, dy = x1 - x0, y1 - y0
    L = max(1.0, math.hypot(dx, dy))
    nx, ny = -dy / L, dx / L
    n_seg = max(5, min(64, int(L / 18)))
    pts = []
    ph = rng.uniform(0, math.tau)
    for i in range(n_seg + 1):
        t = i / n_seg
        env = math.sin(t * math.pi)
        wob = (math.sin(t * 7.8 + ph) * 0.55 + rng.uniform(-0.65, 0.65)) * amp * env
        pts.append((x0 + dx * t + nx * wob, y0 + dy * t + ny * wob))
    d.line(pts, fill=fill, width=width, joint="curve")


def hand_poly(d: ImageDraw.ImageDraw, pts: list, fill=None, outline=INK, width: int = 5, seed: int = 7, amp: float = 2.2) -> None:
    if fill is not None:
        d.polygon(pts, fill=fill)
    if outline is not None:
        for i in range(len(pts)):
            hand_line(d, pts[i], pts[(i + 1) % len(pts)], fill=outline, width=width, seed=seed + i * 13, amp=amp)


def hand_circle(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill=None, outline=INK, width: int = 5, seed: int = 3, amp: float = 2.4, n: int = 52) -> None:
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, math.tau)
    pts = []
    for i in range(n):
        a = (i / n) * math.tau
        rr = r + math.sin(a * 5.0 + ph) * (amp * 0.6) + rng.uniform(-amp * 0.5, amp * 0.5)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    if fill is not None:
        d.polygon(pts, fill=fill)
    if outline is not None:
        d.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def hand_rect(d: ImageDraw.ImageDraw, box: tuple, fill=None, outline=INK, width: int = 5, seed: int = 9, amp: float = 2.5) -> None:
    x0, y0, x1, y1 = box
    hand_poly(d, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill=fill, outline=outline, width=width, seed=seed, amp=amp)


def convert_relief_to_woodcut(render_png: pathlib.Path, target_size: tuple, theme_tint: tuple, paper_highlight: tuple, seed: int) -> tuple:
    """
    Converts Blender Freestyle 3D heraldic relief into rich non-checkerboard woodcut print:
      - Crisp Freestyle ink outlines + Sobel ridges + outer silhouette stroke
      - Light single-angle diagonal burin shadow hatching ONLY where lum < 0.26
      - Rich, saturated mineral pigment wash (preserving gold/lapis/crimson/emerald vibrancy!)
    """
    tw, th = target_size
    im = Image.open(render_png).convert("RGBA").resize((tw, th), Image.Resampling.LANCZOS)
    arr = np.array(im, dtype=np.float32)
    alpha = arr[:, :, 3] / 255.0
    rgb = arr[:, :, :3]

    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:th, 0:tw].astype(np.float32)
    wu = ndi.gaussian_filter(rng.normal(0.0, 1.0, (th, tw)).astype(np.float32), sigma=3.5)
    wv = ndi.gaussian_filter(rng.normal(0.0, 1.0, (th, tw)).astype(np.float32), sigma=3.5)
    wu /= max(1e-4, float(np.std(wu)))
    wv /= max(1e-4, float(np.std(wv)))

    mx = np.clip(xx + wu * 1.25, 0.0, tw - 1.0)
    my = np.clip(yy + wv * 1.25, 0.0, th - 1.0)
    w_rgb = np.empty_like(rgb)
    for c in range(3):
        w_rgb[:, :, c] = ndi.map_coordinates(rgb[:, :, c], [my, mx], order=1, mode="nearest")
    w_a = ndi.map_coordinates(alpha, [my, mx], order=1, mode="constant", cval=0.0)
    inside = w_a > 0.38

    lum = (0.299 * w_rgb[:, :, 0] + 0.587 * w_rgb[:, :, 1] + 0.114 * w_rgb[:, :, 2]) / 255.0
    gx = ndi.sobel(lum * inside, axis=1)
    gy = ndi.sobel(lum * inside, axis=0)
    sobel_ink = np.hypot(gx, gy) > 0.58
    freestyle_ink = inside & (lum < 0.15)
    sil_ink = inside & (~ndi.binary_erosion(inside, iterations=3))

    hwarp = ndi.gaussian_filter(rng.normal(0.0, 1.0, (th, tw)).astype(np.float32), sigma=7.0) * 5.2
    diag1 = np.sin((xx * 0.80 + yy * 0.60 + hwarp) * (math.pi / 5.4)) > 0.50
    shadow_hatch = inside & (lum < 0.26) & diag1
    ink_mask = freestyle_ink | sil_ink | sobel_ink | shadow_hatch

    q_rgb = np.round(np.clip(w_rgb * 1.18 + 14.0, 0.0, 255.0) / 36.0) * 36.0
    tint_v = np.array(theme_tint, dtype=np.float32)
    high_v = np.array(paper_highlight, dtype=np.float32)
    pig = q_rgb * 0.76 + tint_v[None, None, :] * 0.18 + high_v[None, None, :] * 0.06
    lit = lum > 0.84
    for c in range(3):
        pig[:, :, c] = np.where(lit, high_v[c], pig[:, :, c])

    pig_a = np.where(inside, 236.0, 0.0).astype(np.uint8)
    wash_img = Image.fromarray(np.dstack([np.clip(pig, 0, 255).astype(np.uint8), pig_a]), "RGBA")
    ink_rgba = np.zeros((th, tw, 4), dtype=np.uint8)
    ink_rgba[ink_mask] = [24, 15, 9, 246]
    ink_img = Image.fromarray(ink_rgba, "RGBA")
    return wash_img, ink_img


def draw_woodblock_bracket_crest(wd: ImageDraw.ImageDraw, idraw: ImageDraw.ImageDraw, cx: int, cy: int, w_span: int, flip_y: int, col: tuple, accent_col: tuple, seed: int) -> None:
    """Draws bold woodblock-engraved architectural & botanical bracket crests (ribbons, palmette wedges, diamond clasps)."""
    fy = float(flip_y)
    # Central engraved palmette spear + diamond rivet
    spear = [
        (cx, cy - fy * 46),
        (cx + 22, cy - fy * 6),
        (cx, cy + fy * 16),
        (cx - 22, cy - fy * 6),
    ]
    hand_poly(wd, spear, fill=accent_col, outline=None, seed=seed, amp=2.0)
    hand_poly(idraw, spear, outline=INK, width=5, seed=seed + 1, amp=2.0)

    for sx in (-1, 1):
        # Tapered woodblock ribbon arm
        arm = [
            (cx + sx * 14, cy + fy * 2),
            (cx + sx * w_span * 0.42, cy + fy * 34),
            (cx + sx * w_span * 0.86, cy + fy * 10),
            (cx + sx * w_span, cy + fy * 36),
            (cx + sx * w_span * 0.76, cy + fy * 46),
            (cx + sx * w_span * 0.40, cy + fy * 52),
            (cx + sx * 12, cy + fy * 16),
        ]
        hand_poly(wd, arm, fill=col, outline=None, seed=seed + sx * 10, amp=2.2)
        hand_poly(idraw, arm, outline=INK, width=5, seed=seed + sx * 11, amp=2.2)

        # Flanking carved leaf/palmette wedges & diamond studs along crest
        for ti, t_frac in enumerate((0.36, 0.68, 0.94)):
            px = cx + sx * w_span * t_frac
            py = cy + fy * (30 if ti == 0 else (18 if ti == 1 else 34))
            l_w = 24 - ti * 3
            wedge = [
                (px, py),
                (px + sx * l_w, py - fy * 30),
                (px + sx * (l_w * 0.55), py - fy * 48),
                (px - sx * 6, py - fy * 14),
            ]
            hand_poly(wd, wedge, fill=accent_col if ti == 1 else col, outline=None, seed=seed + ti * 19 + sx, amp=1.8)
            hand_poly(idraw, wedge, outline=INK, width=4, seed=seed + ti * 23 + sx, amp=1.8)

            # Engraved diamond rivet at junction
            diam = [(px, py - 9), (px + 10, py), (px, py + 9), (px - 10, py)]
            hand_poly(wd, diam, fill=accent_col, outline=None, seed=seed + 90 + ti + sx, amp=1.2)
            hand_poly(idraw, diam, outline=INK, width=3, seed=seed + 95 + ti + sx, amp=1.2)


def finish_woodblock_plate(ground: Image.Image, wash_layer: Image.Image, ink_layer: Image.Image, seed: int) -> Image.Image:
    shifted_wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shifted_wash.paste(wash_layer, (4, 3))
    shifted_wash = shifted_wash.filter(ImageFilter.GaussianBlur(radius=0.5))

    comp = Image.alpha_composite(ground, shifted_wash)
    comp = Image.alpha_composite(comp, ink_layer)

    arr = np.array(comp, dtype=np.float32)
    rng = np.random.default_rng(seed)
    lum = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    flecks = (lum < 75.0) & (rng.random((H, W)) < 0.03)
    arr[flecks, :3] += 24.0
    comp = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

    out_540 = comp.resize((OUT_W, OUT_H), Image.Resampling.LANCZOS)
    mask = Image.new("L", (OUT_W, OUT_H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((3, 3, OUT_W - 4, OUT_H - 4), radius=26, fill=255)
    out_540.putalpha(mask)
    return out_540


def composite_relief(wash: Image.Image, ink: Image.Image, deck_id: str, theme_tint: tuple, paper_hl: tuple, seed: int, y_off: int = -10, size: int = 790) -> None:
    rw, rh = size, size
    rw_img, ri_img = convert_relief_to_woodcut(RENDER_DIR / f"DECK_{deck_id}.png", (rw, rh), theme_tint, paper_hl, seed=seed)
    px, py = CX - rw // 2, CY - rh // 2 + y_off
    wash.alpha_composite(rw_img, (px + 4, py + 3))
    ink.alpha_composite(ri_img, (px, py))


def build_deck_klasic() -> Image.Image:
    """Bespoke 1480s hand-tooled tavern leather & brass deck back (deck_klasic_1795126077581.jpg)."""
    src_path = ARTIFACT_DIR / "deck_klasic_1795126077581.jpg"
    im = Image.open(src_path).convert("RGBA")
    iw, ih = im.size
    target_ratio = OUT_W / OUT_H
    cur_ratio = iw / max(1, ih)
    if cur_ratio > target_ratio:
        nw = int(round(ih * target_ratio))
        x0 = (iw - nw) // 2
        im = im.crop((x0, 0, x0 + nw, ih))
    elif cur_ratio < target_ratio:
        nh = int(round(iw / target_ratio))
        y0 = (ih - nh) // 2
        im = im.crop((0, y0, iw, y0 + nh))

    out_540 = im.resize((OUT_W, OUT_H), Image.Resampling.LANCZOS)
    out_540 = ImageEnhance.Sharpness(out_540).enhance(1.08)
    mask = Image.new("L", (OUT_W, OUT_H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((3, 3, OUT_W - 4, OUT_H - 4), radius=26, fill=255)
    out_540.putalpha(mask)
    return out_540


def build_deck_antika() -> Image.Image:
    ground = make_aged_ground((214, 184, 128), grain_sigma=8.0, stains=22, seed=202, pattern="antika")
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ink = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd, idraw = ImageDraw.Draw(wash), ImageDraw.Draw(ink)

    hand_rect(wd, (54, 58, W - 54, H - 58), fill=(32, 66, 124, 240), outline=None, seed=201)
    hand_rect(wd, (118, 128, W - 118, H - 128), fill=(226, 198, 144, 250), outline=None, seed=202)
    hand_rect(idraw, (54, 58, W - 54, H - 58), outline=INK, width=7, seed=203)
    hand_rect(idraw, (118, 128, W - 118, H - 128), outline=INK, width=6, seed=204)

    # Lotus frieze teeth top & bottom
    for x in range(132, W - 140, 48):
        col_f = (212, 160, 44, 245) if ((x // 48) % 2 == 0) else (44, 142, 134, 240)
        for yy_base, dy in [(60, 64), (H - 60, -64)]:
            tri = [(x, yy_base), (x + 42, yy_base), (x + 21, yy_base + dy)]
            hand_poly(wd, tri, fill=col_f, outline=None, seed=x + yy_base)
            hand_poly(idraw, tri, outline=INK, width=4, seed=x + yy_base + 5)

    # Side sacred Ankh & Solar-Disk motifs along lapis columns
    for side_x in [86, W - 86]:
        for ky in range(200, H - 190, 94):
            hand_circle(idraw, side_x, ky, 14, outline=(228, 188, 92, 245), width=4, seed=side_x + ky, n=14)
            hand_line(idraw, (side_x - 16, ky + 32), (side_x + 16, ky + 32), fill=(228, 188, 92, 245), width=4, seed=ky + 1)
            hand_line(idraw, (side_x, ky + 16), (side_x, ky + 56), fill=(228, 188, 92, 245), width=4, seed=ky + 2)

    # Central stepped cartouche tablet frame with sunburst rays
    cart = [(CX - 280, CY - 390), (CX + 286, CY - 384), (CX + 318, CY), (CX + 282, CY + 394), (CX - 286, CY + 388), (CX - 318, CY)]
    hand_poly(wd, cart, fill=(198, 152, 58, 225), outline=None, seed=210, amp=3.0)
    hand_poly(idraw, cart, outline=INK, width=7, seed=211, amp=3.0)
    inner_cart = [(CX - 246, CY - 350), (CX + 252, CY - 346), (CX + 278, CY), (CX + 248, CY + 356), (CX - 252, CY + 350), (CX - 278, CY)]
    hand_poly(wd, inner_cart, fill=(238, 218, 174, 255), outline=None, seed=212)
    hand_poly(idraw, inner_cart, outline=INK, width=5, seed=213)
    for ri in range(20):
        a = (ri / 20.0) * math.tau
        hand_line(idraw, (CX, CY - 24), (CX + math.cos(a) * 235, CY - 24 + math.sin(a) * 290), fill=(116, 86, 34, 80), width=2, seed=240 + ri)

    # Lotus corner fan medallions inside cartouche field
    for (lx, ly, sx, sy) in [(164, 174, 1, 1), (W - 164, 174, -1, 1), (164, H - 174, 1, -1), (W - 164, H - 174, -1, -1)]:
        for pi, ang in enumerate((0.18, 0.55, 0.92, 1.32)):
            px = lx + sx * math.cos(ang) * 72
            py = ly + sy * math.sin(ang) * 72
            petal = [(lx, ly), (px + sx * 12, py - sy * 8), (px, py), (px - sx * 8, py + sy * 12)]
            hand_poly(wd, petal, fill=(212, 162, 48, 240) if pi % 2 == 0 else (38, 128, 122, 238), outline=None, seed=lx + ly + pi)
            hand_poly(idraw, petal, outline=INK, width=3, seed=lx + ly + pi + 20)

    draw_woodblock_bracket_crest(wd, idraw, CX, 255, 220, 1, (38, 124, 126, 242), (212, 166, 52, 248), seed=270)
    draw_woodblock_bracket_crest(wd, idraw, CX, H - 255, 220, -1, (38, 124, 126, 242), (212, 166, 52, 248), seed=280)
    composite_relief(wash, ink, "antika", (202, 158, 56), (242, 224, 180), seed=202, y_off=-8, size=810)
    return finish_woodblock_plate(ground, wash, ink, seed=202)


def build_deck_rim() -> Image.Image:
    ground = make_aged_ground((144, 38, 32), grain_sigma=9.5, stains=24, seed=303, pattern="rim")
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ink = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd, idraw = ImageDraw.Draw(wash), ImageDraw.Draw(ink)

    hand_rect(wd, (44, 48, W - 44, H - 48), fill=None, outline=(212, 162, 54, 245), width=26, seed=301)
    hand_rect(idraw, (32, 36, W - 32, H - 36), outline=INK, width=6, seed=302)
    hand_rect(idraw, (58, 62, W - 58, H - 62), outline=INK, width=5, seed=303)
    hand_rect(wd, (96, 102, W - 96, H - 102), fill=None, outline=(230, 208, 166, 242), width=24, seed=304)
    hand_rect(idraw, (84, 90, W - 84, H - 90), outline=INK, width=5, seed=305)
    hand_rect(idraw, (112, 118, W - 112, H - 118), outline=INK, width=5, seed=306)

    for x in range(120, W - 150, 56):
        for ybase in [102, H - 102]:
            hand_line(idraw, (x, ybase - 8), (x + 28, ybase - 8), fill=INK, width=4, seed=x + ybase)
            hand_line(idraw, (x + 28, ybase - 8), (x + 28, ybase + 10), fill=INK, width=4, seed=x + ybase + 1)
            hand_line(idraw, (x + 28, ybase + 10), (x + 48, ybase + 10), fill=INK, width=4, seed=x + ybase + 2)

    for (bx, by) in [(160, 172), (W - 160, 172), (160, H - 172), (W - 160, H - 172)]:
        hand_circle(wd, bx, by, 32, fill=(216, 168, 58, 255), outline=None, seed=bx + by)
        hand_circle(idraw, bx, by, 32, outline=INK, width=5, seed=bx + by + 1)
        hand_circle(idraw, bx, by, 12, fill=INK, outline=INK, width=2, seed=bx + 2)

    # Roman Laurel Triumph Wreath framing the bronze scutum medallion
    hand_circle(wd, CX, CY, 322, fill=(224, 198, 144, 215), outline=None, seed=340)
    hand_circle(idraw, CX, CY, 322, outline=INK, width=6, seed=341)
    for li in range(28):
        a = (li / 28.0) * math.tau
        tx, ty = CX + math.cos(a) * 356, CY + math.sin(a) * 356
        dx_l, dy_l = -math.sin(a) * 26, math.cos(a) * 26
        nx_l, ny_l = math.cos(a) * 14, math.sin(a) * 14
        leaf = [(tx - dx_l * 0.4, ty - dy_l * 0.4), (tx + nx_l, ty + ny_l), (tx + dx_l * 0.7, ty + dy_l * 0.7), (tx - nx_l * 0.7, ty - ny_l * 0.7)]
        col_l = (66, 108, 46, 240) if (li % 3 != 0) else (216, 168, 58, 245)
        hand_poly(wd, leaf, fill=col_l, outline=None, seed=370 + li, amp=1.4)
        hand_poly(idraw, leaf, outline=INK, width=3, seed=399 + li, amp=1.4)

    draw_woodblock_bracket_crest(wd, idraw, CX, 272, 235, 1, (168, 54, 38, 240), (218, 170, 58, 248), seed=350)
    draw_woodblock_bracket_crest(wd, idraw, CX, H - 272, 235, -1, (168, 54, 38, 240), (218, 170, 58, 248), seed=360)
    composite_relief(wash, ink, "rim", (206, 146, 46), (242, 220, 174), seed=303, y_off=-4, size=800)
    return finish_woodblock_plate(ground, wash, ink, seed=303)


def build_deck_stredovek() -> Image.Image:
    ground = make_aged_ground((54, 68, 60), grain_sigma=9.5, stains=22, seed=404, pattern="stredovek")
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ink = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd, idraw = ImageDraw.Draw(wash), ImageDraw.Draw(ink)

    hand_rect(wd, (54, 60, W - 54, H - 60), fill=(44, 48, 54, 236), outline=None, seed=401)
    hand_rect(wd, (112, 126, W - 112, H - 126), fill=(36, 94, 62, 225), outline=None, seed=402)
    hand_rect(idraw, (54, 60, W - 54, H - 60), outline=INK, width=7, seed=403)
    hand_rect(idraw, (112, 126, W - 112, H - 126), outline=INK, width=6, seed=404)

    arch = [(150, H - 180), (150, 500), (225, 290), (CX, 174), (W - 225, 290), (W - 150, 500), (W - 150, H - 180)]
    hand_poly(wd, arch, fill=(224, 208, 176, 248), outline=None, seed=410)
    hand_poly(idraw, arch, outline=INK, width=7, seed=411)

    # Cathedral Rose Window stone tracery rings & trefoil spokes behind the Crown
    hand_circle(idraw, CX, CY - 10, 326, outline=(88, 72, 52, 155), width=4, seed=415)
    hand_circle(idraw, CX, CY - 10, 276, outline=(88, 72, 52, 145), width=3, seed=416)
    for si in range(12):
        a = (si / 12.0) * math.tau
        p0 = (CX + math.cos(a) * 140, CY - 10 + math.sin(a) * 140)
        p1 = (CX + math.cos(a) * 324, CY - 10 + math.sin(a) * 324)
        hand_line(idraw, p0, p1, fill=(88, 72, 52, 130), width=3, seed=420 + si)
        hand_circle(idraw, CX + math.cos(a + 0.26) * 300, CY - 10 + math.sin(a + 0.26) * 300, 14, outline=(88, 72, 52, 135), width=3, seed=450 + si, n=12)

    for (rx, ry) in [(82, 92), (W - 82, 92), (82, H - 92), (W - 82, H - 92)]:
        hand_circle(wd, rx, ry, 20, fill=(148, 154, 162, 255), outline=None, seed=rx + ry)
        hand_circle(idraw, rx, ry, 20, outline=INK, width=5, seed=rx + ry + 3)

    draw_woodblock_bracket_crest(wd, idraw, CX, 315, 225, 1, (54, 128, 82, 240), (196, 154, 52, 248), seed=430)
    draw_woodblock_bracket_crest(wd, idraw, CX, H - 285, 225, -1, (54, 128, 82, 240), (196, 154, 52, 248), seed=440)
    composite_relief(wash, ink, "stredovek", (134, 146, 128), (240, 226, 196), seed=404, y_off=-8, size=840)
    return finish_woodblock_plate(ground, wash, ink, seed=404)


def build_deck_objavy() -> Image.Image:
    ground = make_aged_ground((196, 184, 154), grain_sigma=9.0, stains=26, seed=505, pattern="objavy")
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ink = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd, idraw = ImageDraw.Draw(wash), ImageDraw.Draw(ink)

    hand_rect(wd, (44, 48, W - 44, H - 48), fill=None, outline=(32, 68, 108, 235), width=38, seed=501)
    hand_rect(wd, (98, 106, W - 98, H - 106), fill=(182, 198, 210, 150), outline=None, seed=502)

    for hub_x, hub_y in [(CX + 135, CY - 290), (CX - 165, CY + 250)]:
        for i in range(16):
            a = (i / 16.0) * math.tau
            x2 = max(106, min(W - 106, hub_x + math.cos(a) * 1400))
            y2 = max(112, min(H - 112, hub_y + math.sin(a) * 1400))
            hand_line(idraw, (hub_x, hub_y), (x2, y2), fill=(52, 68, 86, 105), width=2, seed=510 + i + hub_x)

    # Graduated cartographer astrolabe circle framing caravel
    hand_circle(idraw, CX, CY - 26, 336, outline=(38, 62, 92, 165), width=4, seed=515)
    hand_circle(idraw, CX, CY - 26, 314, outline=(38, 62, 92, 140), width=3, seed=516)
    for dt in range(24):
        a = (dt / 24.0) * math.tau
        hand_line(idraw, (CX + math.cos(a) * 314, CY - 26 + math.sin(a) * 314), (CX + math.cos(a) * 336, CY - 26 + math.sin(a) * 336), fill=(38, 62, 92, 160), width=3, seed=560 + dt)

    hand_rect(idraw, (58, 62, W - 58, H - 62), outline=INK, width=7, seed=520)
    hand_rect(idraw, (96, 102, W - 96, H - 102), outline=INK, width=6, seed=521)
    for t_step in range(72, W - 70, 24):
        for r_y in (82, H - 82):
            hand_line(wd, (t_step, r_y - 12), (t_step + 18, r_y + 12), fill=(184, 142, 82, 245), width=9, seed=t_step + r_y)
            hand_line(idraw, (t_step, r_y - 12), (t_step + 18, r_y + 12), fill=INK, width=4, seed=t_step + r_y + 3)
    for t_step in range(96, H - 94, 24):
        for r_x in (76, W - 76):
            hand_line(wd, (r_x - 12, t_step), (r_x + 12, t_step + 18), fill=(184, 142, 82, 245), width=9, seed=t_step + r_x)
            hand_line(idraw, (r_x - 12, t_step), (r_x + 12, t_step + 18), fill=INK, width=4, seed=t_step + r_x + 3)

    # Continuous rolling scalloped nautical wave bands below ship
    for row_i, wy in enumerate([CY + 245, CY + 298, CY + 352]):
        pts = []
        span = 66
        for xi, wx_p in enumerate(range(122, W - 120, span // 2)):
            pts.append((wx_p, wy - (14 if (xi + row_i) % 2 == 0 else -10)))
        for pi in range(len(pts) - 1):
            hand_line(wd, pts[pi], pts[pi + 1], fill=(54, 102, 142, 185), width=10, seed=600 + pi + row_i * 50, amp=1.8)
            hand_line(idraw, pts[pi], pts[pi + 1], fill=INK, width=4, seed=630 + pi + row_i * 50, amp=1.8)

    draw_woodblock_bracket_crest(wd, idraw, CX, 240, 225, 1, (48, 92, 134, 236), (194, 72, 46, 245), seed=550)
    draw_woodblock_bracket_crest(wd, idraw, CX, H - 240, 225, -1, (48, 92, 134, 236), (194, 72, 46, 245), seed=560)
    composite_relief(wash, ink, "objavy", (72, 108, 148), (238, 226, 200), seed=505, y_off=-28, size=820)
    return finish_woodblock_plate(ground, wash, ink, seed=505)


def main() -> None:
    TABLE_DIR.mkdir(parents=True, exist_ok=True)
    ensure_backup()

    builders = {
        "klasic": build_deck_klasic,
        "antika": build_deck_antika,
        "rim": build_deck_rim,
        "stredovek": build_deck_stredovek,
        "objavy": build_deck_objavy,
    }
    for deck_id, fn in builders.items():
        img = fn()
        out_path = TABLE_DIR / f"deck_back_{deck_id}.png"
        img.save(out_path, "PNG")
        print(f"Generated {out_path.name} ({img.size[0]}x{img.size[1]} {img.mode})")

    shutil.copy2(TABLE_DIR / "deck_back_klasic.png", TABLE_DIR / "card_back.png")
    print("Replaced legacy card_back.png with bespoke 1480s Klasická kůže artwork.")


if __name__ == "__main__":
    main()
