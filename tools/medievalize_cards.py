"""
Composites all 16 Power Cards (SPEC_*.png -> 540x810 RGBA) onto asymmetric hand-inked
1480s Bohemian woodblock broadsheet plates with blank Godot Label3D-safe parchment ribbons
(y=588..663 & y=683..740):
  - Group A (10 cards): Museum-grade Pentiment-style 1480s woodblock illustrations (VAMPIRE..HEX)
  - Group B (2 cards): Cropped, tilted & organically warped woodcut broadsheets (PLAGUE, CROWN)
  - Group C (3 cards): Anti-AI tilted/warped/misregistered woodblock reworks (MAGNET, SHIELD, GAMBLER)
  - Group D (1 card): Airy non-checkerboard Blender Freestyle woodblock prism (PRISM)
"""
import math
import pathlib
import shutil
import numpy as np
import scipy.ndimage as ndi
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(r"D:\downpour-godot")
CARD_DIR = ROOT / "assets" / "cards"
RENDER_DIR = ROOT / "tools" / "power_renders"
BACKUP_SPEC_DIR = ROOT / "tools" / "backup_spec_orig"
FONT_DISPLAY = ROOT / "assets" / "fonts" / "LialoDisplay.ttf"
ARTIFACT_DIR = pathlib.Path(r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d")

OUT_W, OUT_H = 540, 810
SS_W, SS_H = 1080, 1620

INK = (24, 15, 9, 255)
INK_MID = (48, 30, 18, 225)

SPEC_META = [
    ("SPEC_VAMPIRE",   "I",    "CERVEN"),
    ("SPEC_STORM",     "II",   "ZELEN"),
    ("SPEC_MIRROR",    "III",  "CERVEN"),
    ("SPEC_ALCHEMIST", "IV",   "ZALUD"),
    ("SPEC_ORACLE",    "V",    "ZELEN"),
    ("SPEC_PHOENIX",   "VI",   "CERVEN"),
    ("SPEC_MIDAS",     "VII",  "GULA"),
    ("SPEC_CHRONOS",   "VIII", "GULA"),
    ("SPEC_JESTER",    "IX",   "GULA"),
    ("SPEC_HEX",       "X",    "ZALUD"),
    ("SPEC_MAGNET",    "XI",   "GULA"),
    ("SPEC_SHIELD",    "XII",  "ZALUD"),
    ("SPEC_GAMBLER",   "XIII", "ZALUD"),
    ("SPEC_PLAGUE",    "XIV",  "ZELEN"),
    ("SPEC_CROWN",     "XV",   "GULA"),
    ("SPEC_PRISM",     "XVI",  "CERVEN"),
]

WHITE_WOODBLOCK_MAP = {
    "SPEC_VAMPIRE":   "spec_vampire_1795126062138.jpg",
    "SPEC_STORM":     "spec_storm_1795126102236.jpg",
    "SPEC_MIRROR":    "spec_mirror_1795126079091.jpg",
    "SPEC_ALCHEMIST": "spec_alchemist_1795126086588.jpg",
    "SPEC_ORACLE":    "spec_oracle_1795126064992.jpg",
    "SPEC_PHOENIX":   "spec_phoenix_v2_1795126114165.jpg",
    "SPEC_MIDAS":     "spec_midas_1795126083860.jpg",
    "SPEC_CHRONOS":   "spec_chronos_1795126092787.jpg",
    "SPEC_JESTER":    "spec_jester_1795126063510.jpg",
    "SPEC_HEX":       "spec_hex_1795126071823.jpg",
}

PARCHMENT_ARTIFACT_MAP = {
    "SPEC_PLAGUE": ("spec_plague_1795039052086.jpg", (0.07, 0.07, 0.93, 0.93), 3.2),
    "SPEC_CROWN":  ("spec_crown_1795039043589.jpg",  (0.06, 0.08, 0.94, 0.92), -2.8),
}

BACKUP_WOODCUT_MAP = {
    "SPEC_MAGNET":  ("SPEC_MAGNET.png",  (52, 56, 308, 375), -4.2),
    "SPEC_SHIELD":  ("SPEC_SHIELD.png",  (42, 42, 318, 494),  3.8),
    "SPEC_GAMBLER": ("SPEC_GAMBLER.png", (42, 42, 318, 496), -3.5),
}

SUIT_PIGMENT = {
    "CERVEN": {"main": (156, 36, 34, 255), "wash": (178, 56, 46, 200), "trim": (184, 134, 48, 255)},
    "ZALUD":  {"main": (122, 68, 24, 255), "wash": (150, 96, 40, 200), "trim": (166, 126, 54, 255)},
    "ZELEN":  {"main": (36, 92, 50, 255),  "wash": (54, 114, 68, 200), "trim": (154, 124, 54, 255)},
    "GULA":   {"main": (164, 108, 24, 255),"wash": (192, 140, 42, 200), "trim": (132, 48, 34, 255)},
}


def ensure_spec_backup() -> None:
    BACKUP_SPEC_DIR.mkdir(parents=True, exist_ok=True)
    for spec_id, _, _ in SPEC_META:
        src = CARD_DIR / f"{spec_id}.png"
        dst = BACKUP_SPEC_DIR / f"{spec_id}.png"
        if src.exists() and not dst.exists():
            shutil.copy2(src, dst)


def make_laid_vellum_base(w: int, h: int, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    low = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h // 10, w // 10)).astype(np.float32), sigma=3.5)
    low = (low - low.min()) / max(1e-5, low.max() - low.min())
    low = np.array(Image.fromarray((low * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0

    laid_lines = np.sin((yy + low * 5.0) * (math.pi / 7.5)) * 2.4
    chain_lines = np.exp(-((np.mod(xx + low * 3.0, 110.0) - 55.0) ** 2) / 14.0) * -4.2

    rx = np.abs(xx - w * 0.5) / (w * 0.5)
    ry = np.abs(yy - h * 0.5) / (h * 0.5)
    vig = np.clip((rx ** 2.3 + ry ** 2.3) * 0.42, 0.0, 0.50)

    r = 236.0 - vig * 34.0 + low * 13.0 + laid_lines + chain_lines
    g = 222.0 - vig * 38.0 + low * 11.0 + laid_lines + chain_lines
    b = 190.0 - vig * 46.0 + low * 9.0 + laid_lines + chain_lines

    grain = rng.normal(0.0, 4.0, (h, w, 1)).astype(np.float32)
    arr = np.stack([r, g, b], axis=-1) + grain

    for _ in range(28):
        fx = rng.uniform(50, w - 50)
        fy = rng.uniform(50, h - 50)
        fr = rng.uniform(12, 85)
        blob = np.exp(-(((xx - fx) ** 2 + (yy - fy) ** 2) / (fr ** 2)) * 2.0) * rng.uniform(-16.0, 6.0)
        arr += blob[:, :, None]

    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def hand_line(d: ImageDraw.ImageDraw, p0: tuple, p1: tuple, fill=INK, width: int = 4, seed: int = 1, amp: float = 2.8) -> None:
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
        wob = (math.sin(t * 8.2 + ph) * 0.55 + rng.uniform(-0.65, 0.65)) * amp * env
        pts.append((x0 + dx * t + nx * wob, y0 + dy * t + ny * wob))
    d.line(pts, fill=fill, width=width, joint="curve")


def hand_poly(d: ImageDraw.ImageDraw, pts: list, fill=None, outline=INK, width: int = 4, seed: int = 7, amp: float = 2.4) -> None:
    if fill is not None:
        d.polygon(pts, fill=fill)
    if outline is not None:
        for i in range(len(pts)):
            hand_line(d, pts[i], pts[(i + 1) % len(pts)], fill=outline, width=width, seed=seed + i * 17, amp=amp)


def hand_circle(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill=None, outline=INK, width: int = 4, seed: int = 5, amp: float = 2.6, n: int = 40) -> None:
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, math.tau)
    pts = []
    for i in range(n):
        a = (i / n) * math.tau
        rr = r + math.sin(a * 4.0 + ph) * (amp * 0.65) + rng.uniform(-amp * 0.45, amp * 0.45)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    if fill is not None:
        d.polygon(pts, fill=fill)
    if outline is not None:
        d.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def apply_elastic_warp(img_rgba: Image.Image, low_amp: float, hi_amp: float, seed: int) -> Image.Image:
    """Applies smooth low-frequency elastic distortion + fine pearwood quill tremor to RGBA."""
    arr = np.array(img_rgba.convert("RGBA"), dtype=np.float32)
    h, w, _ = arr.shape
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    dx = np.zeros((h, w), dtype=np.float32)
    dy = np.zeros((h, w), dtype=np.float32)
    if low_amp > 0.01:
        lu = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=18.0)
        lv = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=18.0)
        dx += (lu / max(1e-4, float(np.std(lu)))) * low_amp
        dy += (lv / max(1e-4, float(np.std(lv)))) * low_amp
    if hi_amp > 0.01:
        hu = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=3.4)
        hv = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=3.4)
        dx += (hu / max(1e-4, float(np.std(hu)))) * hi_amp
        dy += (hv / max(1e-4, float(np.std(hv)))) * hi_amp

    map_x = np.clip(xx + dx, 0.0, w - 1.0)
    map_y = np.clip(yy + dy, 0.0, h - 1.0)
    out = np.empty_like(arr)
    for c in range(3):
        out[:, :, c] = ndi.map_coordinates(arr[:, :, c], [map_y, map_x], order=1, mode="nearest")
    out[:, :, 3] = ndi.map_coordinates(arr[:, :, 3], [map_y, map_x], order=1, mode="constant", cval=0.0)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def flood_remove_border_bg(img_rgb: Image.Image, lum_thresh: float, chroma_thresh: float, warm_highlights: bool = True) -> Image.Image:
    """
    Removes border-connected background cleanly via 8-connected flood-fill without punching
    holes inside bright highlights (goblets, skulls, scrolls), softly de-fringes edges,
    and warms bright interior highlights slightly to antique vellum tooth.
    """
    arr = np.array(img_rgb.convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    lum = np.mean(arr, axis=-1)
    chroma = np.max(arr, axis=-1) - np.min(arr, axis=-1)

    is_bg_cand = (lum > lum_thresh) & (chroma < chroma_thresh)
    seed = np.zeros((h, w), dtype=bool)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    lab, _ = ndi.label(is_bg_cand, structure=np.ones((3, 3), dtype=bool))
    bg_labels = set(np.unique(lab[seed])) - {0}
    bg_mask = np.isin(lab, list(bg_labels))

    alpha = np.where(bg_mask, 0.0, 255.0).astype(np.float32)
    near = ndi.binary_dilation(bg_mask, iterations=2) & (~bg_mask)
    fringe = near & (lum > lum_thresh - 48.0) & (chroma < chroma_thresh + 18.0)
    t_f = np.clip((lum_thresh + 6.0 - lum[fringe]) / 52.0, 0.0, 1.0)
    alpha[fringe] = t_f * 255.0
    # Pull bright fringe halo subtly toward sepia ink so zero light halo remains
    for c, ink_c in enumerate((58.0, 42.0, 30.0)):
        arr[fringe, c] = arr[fringe, c] * t_f + ink_c * (1.0 - t_f)

    if warm_highlights:
        # Warm pure paper-white enclosed highlights so they blend naturally into laid vellum
        hl_w = np.clip((lum - 216.0) / 39.0, 0.0, 1.0) * np.clip(1.0 - chroma / 26.0, 0.0, 1.0)
        vellum = np.array([240.0, 226.0, 194.0], dtype=np.float32)
        for c in range(3):
            arr[:, :, c] = arr[:, :, c] * (1.0 - hl_w * 0.85) + vellum[c] * (hl_w * 0.85)

    return Image.fromarray(np.dstack([np.clip(arr, 0, 255), np.clip(alpha, 0, 255)]).astype(np.uint8), "RGBA")


def trim_and_fit_rgba(img_rgba: Image.Image, max_w: int, max_h: int) -> Image.Image:
    arr = np.array(img_rgba.convert("RGBA"))
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) > 0:
        x0, x1 = max(0, int(xs.min()) - 4), min(arr.shape[1], int(xs.max()) + 5)
        y0, y1 = max(0, int(ys.min()) - 4), min(arr.shape[0], int(ys.max()) + 5)
        cropped = img_rgba.crop((x0, y0, x1, y1))
    else:
        cropped = img_rgba
    cw, ch = cropped.size
    sc = min(max_w / max(1, cw), max_h / max(1, ch))
    nw, nh = max(1, int(round(cw * sc))), max(1, int(round(ch * sc)))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))
    canvas.paste(resized, ((max_w - nw) // 2, (max_h - nh) // 2), resized)
    return canvas


def prepare_white_woodblock_art(jpg_path: pathlib.Path, max_size: tuple, seed: int) -> Image.Image:
    """Group A: Pure-white-ground 1480s Pentiment woodblock illustration -> transparent vellum-warmed RGBA."""
    raw = Image.open(jpg_path).convert("RGB")
    cut = flood_remove_border_bg(raw, lum_thresh=234.0, chroma_thresh=20.0, warm_highlights=True)
    fitted = trim_and_fit_rgba(cut, max_size[0], max_size[1])
    return apply_elastic_warp(fitted, low_amp=0.0, hi_amp=0.8, seed=seed)


def prepare_parchment_woodcut_art(jpg_path: pathlib.Path, crop_fracs: tuple, tilt_deg: float, max_size: tuple, seed: int) -> Image.Image:
    """Group B: High-res aged-parchment woodcut -> frame-cropped, slightly tilted, organically warped RGBA."""
    raw = Image.open(jpg_path).convert("RGB")
    rw, rh = raw.size
    cropped = raw.crop((
        int(round(rw * crop_fracs[0])),
        int(round(rh * crop_fracs[1])),
        int(round(rw * crop_fracs[2])),
        int(round(rh * crop_fracs[3])),
    ))
    cut = flood_remove_border_bg(cropped, lum_thresh=156.0, chroma_thresh=48.0, warm_highlights=True)
    # Softly dissolve any lingering isolated low-chroma parchment foxing islands outside core illustration
    c_arr = np.array(cut, dtype=np.float32)
    c_lum = np.mean(c_arr[:, :, :3], axis=-1)
    c_chr = np.max(c_arr[:, :, :3], axis=-1) - np.min(c_arr[:, :, :3], axis=-1)
    faint_stain = (c_lum > 172.0) & (c_chr < 42.0)
    c_arr[:, :, 3] = np.where(faint_stain, 0.0, c_arr[:, :, 3])
    cut = Image.fromarray(np.clip(c_arr, 0, 255).astype(np.uint8), "RGBA")
    rot = cut.rotate(tilt_deg, resample=Image.Resampling.BICUBIC, expand=True)
    warped = apply_elastic_warp(rot, low_amp=1.6, hi_amp=0.8, seed=seed)
    return trim_and_fit_rgba(warped, max_size[0], max_size[1])


def prepare_reworked_backup_woodcut(png_path: pathlib.Path, crop_px: tuple, tilt_deg: float, target_size: tuple, suit_id: str, seed: int) -> tuple:
    """
    Group C: Anti-AI rework of backup SPEC plate -> upscale, remove border parchment, tilt & warp
    asymmetrically, then split into off-register 4-tone mineral wash + crisp sepia-black woodcut ink keyplate
    (ZERO dark checkerboard!).
    """
    src = Image.open(png_path).convert("RGB").crop(crop_px)
    up = src.resize((src.width * 3, src.height * 3), Image.Resampling.LANCZOS)
    cut = flood_remove_border_bg(up, lum_thresh=175.0, chroma_thresh=44.0, warm_highlights=False)
    rot = cut.rotate(tilt_deg, resample=Image.Resampling.BICUBIC, expand=True)
    warped = apply_elastic_warp(rot, low_amp=2.4, hi_amp=1.0, seed=seed)
    fitted = trim_and_fit_rgba(warped, target_size[0], target_size[1])

    arr = np.array(fitted, dtype=np.float32)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3] / 255.0
    inside = alpha > 0.35

    lum = (0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]) / 255.0
    gx = ndi.sobel(lum * inside, axis=1)
    gy = ndi.sobel(lum * inside, axis=0)
    sobel_ink = np.hypot(gx, gy) > 0.56
    dark_ink = inside & (lum < 0.24)
    eroded = ndi.binary_erosion(inside, iterations=2)
    sil_ink = inside & (~eroded)
    ink_mask = dark_ink | sobel_ink | sil_ink

    # Airy 4-tone mineral watercolor wash (no heavy dark greying!)
    q_rgb = np.round(rgb / 56.0) * 56.0
    suit_w = np.array(SUIT_PIGMENT[suit_id]["wash"][:3], dtype=np.float32)
    parch = np.array([236.0, 222.0, 190.0], dtype=np.float32)
    pig = q_rgb * 0.74 + suit_w[None, None, :] * 0.14 + parch[None, None, :] * 0.12
    lit = lum > 0.80
    for c in range(3):
        pig[:, :, c] = np.where(lit, parch[c], pig[:, :, c])
    pig_a = np.where(inside & (~lit), np.clip(alpha * 212.0, 0, 212), np.where(inside, 110.0, 0.0)).astype(np.uint8)
    wash_img = Image.fromarray(np.dstack([np.clip(pig, 0, 255).astype(np.uint8), pig_a]), "RGBA")

    ink_rgba = np.zeros((target_size[1], target_size[0], 4), dtype=np.uint8)
    ink_rgba[ink_mask] = [24, 15, 9, 246]
    ink_img = Image.fromarray(ink_rgba, "RGBA")
    return wash_img, ink_img


def convert_blender_render_to_woodcut(render_png: pathlib.Path, target_size: tuple, suit_id: str, seed: int) -> tuple:
    """
    Group D (SPEC_PRISM): Crisp Freestyle/Sobel woodblock prism with ONLY delicate single-angle shadow
    hatching where lum < 0.28 and airy off-register spectral watercolor wash (NO dark checkerboard!).
    """
    tw, th = target_size
    im = Image.open(render_png).convert("RGBA").resize((tw, th), Image.Resampling.LANCZOS)
    warped = apply_elastic_warp(im, low_amp=0.8, hi_amp=1.2, seed=seed)
    arr = np.array(warped, dtype=np.float32)
    alpha = arr[:, :, 3] / 255.0
    rgb = arr[:, :, :3]
    inside = alpha > 0.38

    lum = (0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]) / 255.0
    gx = ndi.sobel(lum * inside, axis=1)
    gy = ndi.sobel(lum * inside, axis=0)
    sobel_ink = np.hypot(gx, gy) > 0.62
    freestyle_ink = inside & (lum < 0.14)
    eroded = ndi.binary_erosion(inside, iterations=3)
    sil_ink = inside & (~eroded)

    # Delicate single-angle shadow hatching strictly in deep crevices (lum < 0.28)
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:th, 0:tw].astype(np.float32)
    h_warp = ndi.gaussian_filter(rng.normal(0.0, 1.0, (th, tw)).astype(np.float32), sigma=7.0) * 5.0
    diag1 = np.sin((xx * 0.80 + yy * 0.60 + h_warp) * (math.pi / 5.4)) > 0.52
    shadow_hatch = inside & (lum < 0.28) & diag1
    ink_mask = freestyle_ink | sil_ink | sobel_ink | shadow_hatch

    q_rgb = np.round(rgb / 48.0) * 48.0
    parch = np.array([236.0, 222.0, 190.0], dtype=np.float32)
    pig = q_rgb * 0.84 + parch[None, None, :] * 0.16
    lit = lum > 0.86
    for c in range(3):
        pig[:, :, c] = np.where(lit, parch[c], pig[:, :, c])
    pig_a = np.where(inside & (~lit), 205.0, np.where(inside, 115.0, 0.0)).astype(np.uint8)
    wash_img = Image.fromarray(np.dstack([np.clip(pig, 0, 255).astype(np.uint8), pig_a]), "RGBA")

    ink_rgba = np.zeros((th, tw, 4), dtype=np.uint8)
    ink_rgba[ink_mask] = [24, 15, 9, 245]
    ink_img = Image.fromarray(ink_rgba, "RGBA")
    return wash_img, ink_img


def draw_marginalia_sprig(d_ink: ImageDraw.ImageDraw, d_wash: ImageDraw.ImageDraw, x: int, y: int, scale: float, flip_x: bool, seed: int, col: tuple) -> None:
    sx = -1.0 if flip_x else 1.0
    stem_end = (x + sx * 84 * scale, y + 66 * scale)
    hand_line(d_ink, (x, y), stem_end, fill=INK_MID, width=4, seed=seed, amp=3.0)
    for k in range(3):
        t = 0.25 + k * 0.28
        lx = x + sx * 84 * scale * t
        ly = y + 66 * scale * t
        hand_circle(d_wash, lx + sx * 10, ly - 10, 15 * scale, fill=col, outline=None, seed=seed + k + 1, amp=4.0, n=10)
        hand_circle(d_ink, lx + sx * 10, ly - 10, 15 * scale, outline=INK_MID, width=3, seed=seed + k + 2, amp=4.0, n=10)


def draw_suit_sigil_hand(d_ink: ImageDraw.ImageDraw, d_wash: ImageDraw.ImageDraw, cx: float, cy: float, suit_id: str, r: float, seed: int) -> None:
    col = SUIT_PIGMENT[suit_id]["main"]
    if suit_id == "CERVEN":
        pts = [(cx, cy + r), (cx - r * 0.9, cy - r * 0.1), (cx - r * 0.5, cy - r * 0.8), (cx, cy - r * 0.35), (cx + r * 0.5, cy - r * 0.8), (cx + r * 0.9, cy - r * 0.1)]
        hand_poly(d_wash, pts, fill=col, outline=None, seed=seed)
        hand_poly(d_ink, pts, outline=INK, width=4, seed=seed + 1)
    elif suit_id == "ZALUD":
        hand_circle(d_wash, cx, cy + r * 0.15, r * 0.68, fill=col, outline=None, seed=seed, n=12)
        hand_circle(d_ink, cx, cy + r * 0.15, r * 0.68, outline=INK, width=4, seed=seed + 1, n=12)
        hand_poly(d_ink, [(cx - r * 0.72, cy - r * 0.1), (cx + r * 0.72, cy - r * 0.1), (cx + r * 0.4, cy - r * 0.65), (cx - r * 0.4, cy - r * 0.65)], fill=(90, 52, 22, 240), outline=INK, width=3, seed=seed + 2)
    elif suit_id == "ZELEN":
        pts = [(cx, cy - r * 0.95), (cx + r * 0.85, cy + r * 0.25), (cx, cy + r * 0.85), (cx - r * 0.85, cy + r * 0.25)]
        hand_poly(d_wash, pts, fill=col, outline=None, seed=seed)
        hand_poly(d_ink, pts, outline=INK, width=4, seed=seed + 1)
        hand_line(d_ink, (cx, cy - r * 0.7), (cx, cy + r * 1.15), fill=INK, width=3, seed=seed + 2)
    else:
        hand_circle(d_wash, cx, cy, r * 0.78, fill=col, outline=None, seed=seed, n=16)
        hand_circle(d_ink, cx, cy, r * 0.78, outline=INK, width=4, seed=seed + 1, n=16)
        hand_line(d_ink, (cx - r * 0.72, cy), (cx + r * 0.72, cy), fill=INK, width=3, seed=seed + 2)


def compose_power_card(spec_id: str, roman: str, suit_id: str, idx: int) -> None:
    rng = np.random.default_rng(7700 + idx * 37)
    ground = make_laid_vellum_base(SS_W, SS_H, seed=3100 + idx * 19)
    wash = Image.new("RGBA", (SS_W, SS_H), (0, 0, 0, 0))
    direct_art = Image.new("RGBA", (SS_W, SS_H), (0, 0, 0, 0))
    ink = Image.new("RGBA", (SS_W, SS_H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    idraw = ImageDraw.Draw(ink)
    sp = SUIT_PIGMENT[suit_id]

    # 1. Hand-drawn outer broadsheet double border with deliberate pen tremor
    hand_line(idraw, (40, 44), (SS_W - 44, 42), fill=INK, width=6, seed=10 + idx, amp=3.2)
    hand_line(idraw, (SS_W - 44, 42), (SS_W - 42, SS_H - 46), fill=INK, width=6, seed=11 + idx, amp=3.2)
    hand_line(idraw, (SS_W - 42, SS_H - 46), (42, SS_H - 44), fill=INK, width=6, seed=12 + idx, amp=3.2)
    hand_line(idraw, (42, SS_H - 44), (40, 44), fill=INK, width=6, seed=13 + idx, amp=3.2)

    hand_line(wd, (64, 68), (SS_W - 66, 66), fill=sp["main"], width=5, seed=20 + idx, amp=3.4)
    hand_line(wd, (SS_W - 66, 66), (SS_W - 64, SS_H - 70), fill=sp["main"], width=5, seed=21 + idx, amp=3.4)
    hand_line(wd, (SS_W - 64, SS_H - 70), (66, SS_H - 68), fill=sp["main"], width=5, seed=22 + idx, amp=3.4)
    hand_line(wd, (66, SS_H - 68), (64, 68), fill=sp["main"], width=5, seed=23 + idx, amp=3.4)

    # 2. Asymmetric Sketchy Marginalia Vignette Window (y=210..1136)
    vx0, vy0, vx1, vy1 = 104, 210, SS_W - 104, 1136
    cham_l = int(rng.integers(58, 86))
    cham_r = int(rng.integers(48, 80))
    win_pts = [
        (vx0 + cham_l, vy0),
        (vx1 - cham_r, vy0 + int(rng.integers(-6, 7))),
        (vx1, vy0 + cham_r),
        (vx1 + int(rng.integers(-4, 5)), vy1),
        (vx0 + int(rng.integers(-4, 5)), vy1 + int(rng.integers(-5, 6))),
        (vx0, vy0 + cham_l),
    ]
    hand_poly(wd, win_pts, fill=(244, 232, 202, 165), outline=None, seed=30 + idx, amp=3.0)
    hand_poly(idraw, win_pts, outline=INK, width=5, seed=31 + idx, amp=3.2)

    # Subtle hand-sketched radial sunbeams inside vignette
    sun_x = int(SS_W * 0.5 + rng.integers(-48, 52))
    sun_y = int(vy0 + rng.integers(54, 110))
    for ri in range(13):
        a = math.radians(14 + ri * 12.5 + float(rng.uniform(-2.5, 2.5)))
        rx = max(vx0 + 18, min(vx1 - 18, sun_x + math.cos(a) * rng.uniform(220, 410)))
        ry = max(vy0 + 18, min(vy1 - 18, sun_y + math.sin(a) * rng.uniform(180, 320)))
        hand_line(idraw, (sun_x, sun_y), (rx, ry), fill=(68, 46, 26, 62), width=2, seed=200 + ri + idx, amp=2.2)

    draw_marginalia_sprig(idraw, wd, 82, 86, 1.05, False, 300 + idx, sp["wash"])
    draw_suit_sigil_hand(idraw, wd, SS_W - 122, 126, suit_id, 28.0, 350 + idx)

    wax_cx = int(SS_W * 0.5 + rng.integers(-90, 95))
    wax_cy = 148
    hand_circle(wd, wax_cx, wax_cy, 54, fill=sp["main"], outline=None, seed=400 + idx, amp=4.5, n=18)
    hand_circle(wd, wax_cx, wax_cy, 44, fill=(238, 224, 194, 248), outline=None, seed=401 + idx, amp=2.8, n=22)
    hand_circle(idraw, wax_cx, wax_cy, 54, outline=INK, width=5, seed=402 + idx, amp=4.2, n=18)
    hand_circle(idraw, wax_cx, wax_cy, 44, outline=INK, width=3, seed=403 + idx, amp=2.6, n=22)

    font_rom = ImageFont.truetype(str(FONT_DISPLAY), 38 if len(roman) <= 2 else (32 if len(roman) == 3 else 26))
    rom_tmp = Image.new("RGBA", (120, 80), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rom_tmp)
    bb = rd.textbbox((0, 0), roman, font=font_rom)
    rd.text((60 - (bb[0] + bb[2]) // 2, 40 - (bb[1] + bb[3]) // 2), roman, font=font_rom, fill=INK)
    rom_rot = rom_tmp.rotate(float(rng.uniform(-4.5, 4.5)), resample=Image.Resampling.BICUBIC)
    ink.alpha_composite(rom_rot, (wax_cx - 60, wax_cy - 40))

    # 3. Prepare Centerpiece Artwork (820x820 fitted cleanly inside vignette window y=225..1120)
    art_w, art_h = 820, 820
    art_x = (SS_W - art_w) // 2 + int(rng.integers(-10, 11))
    art_y = 264 + int(rng.integers(-10, 11))

    if spec_id in WHITE_WOODBLOCK_MAP:
        src_p = ARTIFACT_DIR / WHITE_WOODBLOCK_MAP[spec_id]
        art_rgba = prepare_white_woodblock_art(src_p, (art_w, art_h), seed=8100 + idx * 17)
        direct_art.alpha_composite(art_rgba, (art_x, art_y))
    elif spec_id in PARCHMENT_ARTIFACT_MAP:
        fname, c_fracs, tilt = PARCHMENT_ARTIFACT_MAP[spec_id]
        src_p = ARTIFACT_DIR / fname
        art_rgba = prepare_parchment_woodcut_art(src_p, c_fracs, tilt, (art_w, art_h), seed=8200 + idx * 19)
        direct_art.alpha_composite(art_rgba, (art_x, art_y))
    elif spec_id in BACKUP_WOODCUT_MAP:
        fname, crop_px, tilt = BACKUP_WOODCUT_MAP[spec_id]
        src_p = BACKUP_SPEC_DIR / fname
        art_wash, art_ink = prepare_reworked_backup_woodcut(src_p, crop_px, tilt, (art_w, art_h), suit_id, seed=8300 + idx * 23)
        wash.alpha_composite(art_wash, (art_x + 4, art_y + 3))
        ink.alpha_composite(art_ink, (art_x, art_y))
    else:
        render_path = RENDER_DIR / f"{spec_id}.png"
        art_wash, art_ink = convert_blender_render_to_woodcut(render_path, (art_w, art_h), suit_id, seed=8400 + idx * 29)
        # Subtle spectral prism beams radiating softly out of the crystal center
        prism_cols = [(186, 62, 46, 130), (206, 152, 42, 130), (48, 126, 78, 130), (54, 96, 154, 130)]
        for r_i, col in enumerate(prism_cols):
            ang = math.radians(-26 + r_i * 15)
            p_end = (int(SS_W * 0.5 + math.cos(ang) * 340), int(art_y + 390 + math.sin(ang) * 260))
            hand_line(wd, (SS_W // 2, art_y + 380), p_end, fill=col, width=14, seed=900 + r_i, amp=4.0)
            hand_line(idraw, (SS_W // 2, art_y + 380), p_end, fill=(48, 30, 18, 85), width=2, seed=920 + r_i, amp=3.0)
        wash.alpha_composite(art_wash, (art_x + 4, art_y + 3))
        ink.alpha_composite(art_ink, (art_x, art_y))

    # 4. Blank Rolled Parchment Cartouches aligned cleanly to Godot's 3D Label3Ds!
    # AbilityLabel sits in 540x810 at y=588..663 -> 2x is y=1176..1326
    scroll_pts = [(116, 1178), (SS_W - 116, 1174), (SS_W - 104, 1322), (108, 1326)]
    for tx, sx in [(112, -1), (SS_W - 112, 1)]:
        tail = [(tx, 1200), (tx + sx * 44, 1190), (tx + sx * 30, 1252), (tx + sx * 48, 1312), (tx, 1304)]
        hand_poly(wd, tail, fill=(198, 178, 140, 245), outline=None, seed=500 + sx + idx, amp=2.2)
        hand_poly(idraw, tail, outline=INK, width=4, seed=505 + sx + idx, amp=2.2)
    hand_poly(wd, scroll_pts, fill=(96, 68, 44, 242), outline=None, seed=510 + idx, amp=2.5)
    hand_poly(wd, [(126, 1188), (SS_W - 126, 1184), (SS_W - 116, 1312), (120, 1316)], fill=sp["main"], outline=None, seed=511 + idx, amp=2.2)
    hand_poly(idraw, scroll_pts, outline=INK, width=5, seed=512 + idx, amp=2.5)

    # Lower PtsLabel plaque spans y=683..740 -> 2x is y=1366..1480
    pts_pts = [(296, 1368), (SS_W - 296, 1366), (SS_W - 270, 1422), (SS_W - 302, 1478), (298, 1480), (272, 1424)]
    hand_poly(wd, pts_pts, fill=(76, 54, 34, 246), outline=None, seed=520 + idx, amp=2.2)
    hand_poly(idraw, pts_pts, outline=INK, width=5, seed=521 + idx, amp=2.2)
    hand_line(idraw, (190, 1422), (258, 1424), fill=INK_MID, width=3, seed=525 + idx)
    hand_line(idraw, (SS_W - 258, 1422), (SS_W - 190, 1420), fill=INK_MID, width=3, seed=526 + idx)

    # 5. Misregister hand-painted wash (+4, +3), composite crisp woodblock art & ink keyplate
    shifted_wash = Image.new("RGBA", (SS_W, SS_H), (0, 0, 0, 0))
    shifted_wash.paste(wash, (4, 3))
    shifted_wash = shifted_wash.filter(ImageFilter.GaussianBlur(radius=0.5))

    comp = Image.alpha_composite(ground, shifted_wash)
    comp = Image.alpha_composite(comp, direct_art)
    comp = Image.alpha_composite(comp, ink)

    out_540 = comp.resize((OUT_W, OUT_H), Image.Resampling.LANCZOS)
    mask = Image.new("L", (OUT_W, OUT_H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((3, 3, OUT_W - 4, OUT_H - 4), radius=24, fill=255)
    out_540.putalpha(mask)
    out_540.save(CARD_DIR / f"{spec_id}.png", "PNG")
    print(f"WOODCUT_POWER_CARD={spec_id}.png ({roman}, {suit_id})")


def main() -> None:
    ensure_spec_backup()
    for idx, (spec_id, roman, suit_id) in enumerate(SPEC_META):
        compose_power_card(spec_id, roman, suit_id, idx)
    print("All 16 Power Cards composited in cohesive 1480s woodblock style -> 540x810 RGBA!")


if __name__ == "__main__":
    main()
