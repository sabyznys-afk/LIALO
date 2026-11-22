"""
Upgrades all 32 classic Czech playing cards (CERVEN, ZALUD, ZELEN, GULA x 7,8,9,10,D,H,K,E)
from tools/backup_cards_orig/ (360x540 -> 540x810 RGBA):
  - Preserves 100% of authentic etched borders, side diamond chains, central watermarks,
    baroque hearts/acorns/leaves pips, and detailed court card illustrations.
  - Replaces GULA (Bells/Koule) diamonds across 7..10, D/H/K/E inner pips, and GULA_E center shield
    with copperplate-engraved golden Czech Hawk-Bells (Rolnicka / Koule) with zero ghost remnants.
  - Enlarges corner indices & woodcut suit icons cleanly using soft-feathered local parchment matching.
  - Preserves upgraded SPEC_*.png illustrations.
"""
import pathlib
import sys
import numpy as np
import scipy.ndimage as ndi
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = pathlib.Path(r"D:\downpour-godot")
TOOLS_DIR = ROOT / "tools"
ORIG_DIR = TOOLS_DIR / "backup_cards_orig"
OUT_DIR = ROOT / "assets" / "cards"
FONT_DISPLAY = ROOT / "assets" / "fonts" / "LialoDisplay.ttf"

if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
from build_detailed_relics_and_cards import draw_engraved_koule

CARD_W, CARD_H = 540, 810
SUITS = ["CERVEN", "ZALUD", "ZELEN", "GULA"]
RANKS = ["7", "8", "9", "10", "D", "H", "K", "E"]

SUIT_INK_RGB = {
    "CERVEN": (176, 26, 32, 255),
    "ZALUD": (118, 62, 22, 255),
    "ZELEN": (28, 98, 46, 255),
    "GULA": (178, 108, 18, 255),
}


def detect_gula_pip_boxes_360() -> dict:
    """Finds exact diamond pip centers & tight boxes in backup_cards_orig/GULA_{7,8,9,10} (360x540)."""
    res = {}
    for rank in ["7", "8", "9", "10"]:
        arr = np.array(Image.open(ORIG_DIR / f"GULA_{rank}.png").convert("RGB"))
        hsv = np.array(Image.open(ORIG_DIR / f"GULA_{rank}.png").convert("HSV"))
        mask = np.zeros((540, 360), dtype=bool)
        mask[74:446, 78:282] = (hsv[74:446, 78:282, 1] > 105) & (np.mean(arr[74:446, 78:282], axis=-1) < 185)
        mask = ndi.binary_dilation(mask, iterations=2)
        lab, n = ndi.label(mask)
        pips = []
        for k in range(1, n + 1):
            ys, xs = np.where(lab == k)
            if len(ys) > 120:
                pips.append((float(xs.mean()), float(ys.mean()), int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())))
        res[rank] = pips
    return res


def extract_suit_emblem_from_orig(suit: str, size: int) -> Image.Image:
    """Extracts crisp woodcut emblem for CERVEN/ZALUD/ZELEN from backup_cards_orig/<SUIT>_7.png cleanly with zero paper fringe."""
    if suit == "GULA":
        return draw_engraved_koule(size)

    src = Image.open(ORIG_DIR / f"{suit}_7.png").convert("RGB")
    crops = {
        "CERVEN": (90, 108, 145, 169),
        "ZALUD": (90, 104, 145, 164),
        "ZELEN": (85, 106, 139, 168),
    }
    sub = src.crop(crops[suit])
    arr = np.array(sub, dtype=np.float32)
    h, w, _ = arr.shape
    lum = np.mean(arr, axis=-1)
    chroma = np.max(arr, axis=-1) - np.min(arr, axis=-1)

    # Paper is brighter than ink/leaves and weakly saturated
    is_paper = (lum > 152.0) & (chroma < 48.0)
    seed = np.zeros((h, w), dtype=bool)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    lab, _ = ndi.label(is_paper, structure=np.ones((3, 3), dtype=bool))
    bg_labels = set(np.unique(lab[seed])) - {0}
    bg_mask = np.isin(lab, list(bg_labels))

    alpha = np.where(bg_mask, 0.0, 255.0).astype(np.float32)
    # De-fringe anti-aliased edge pixels touching paper
    near = ndi.binary_dilation(bg_mask, iterations=1) & (~bg_mask)
    fringe = near & (lum > 118.0) & (chroma < 56.0)
    alpha[fringe] = np.clip((165.0 - lum[fringe]) / 47.0 * 255.0, 0.0, 255.0)

    rgba = np.dstack([arr, alpha]).astype(np.uint8)
    ys, xs = np.where(rgba[:, :, 3] > 28)
    if len(xs) > 0:
        crop = Image.fromarray(rgba[int(ys.min()):int(ys.max()) + 1, int(xs.min()):int(xs.max()) + 1], "RGBA")
    else:
        crop = Image.fromarray(rgba, "RGBA")

    cw, ch = crop.size
    sc = (size * 0.90) / max(cw, ch)
    nw, nh = max(1, int(round(cw * sc))), max(1, int(round(ch * sc)))
    res = crop.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(res, ((size - nw) // 2, (size - nh) // 2), res)
    return canvas


def build_gula_clean_pip_base_360(pips_map: dict) -> np.ndarray:
    """
    Reconstructs a 100% spotless GULA base (aged parchment, ornate diamond borders, side chains,
    and central radial compass watermark) starting from GULA_10 (whose central compass at
    x=145..215, y=215..320 has zero pips!) and cleanly filling every pip bounding box from sibling
    cards or smooth distance-weighted clean paper.
    """
    imgs = {r: np.array(Image.open(ORIG_DIR / f"GULA_{r}.png").convert("RGB"), dtype=np.float32) for r in ["7", "8", "9", "10"]}
    clean_mask = {}
    for r in ["7", "8", "9", "10"]:
        hsv = np.array(Image.open(ORIG_DIR / f"GULA_{r}.png").convert("HSV"))
        m_pip = np.zeros((540, 360), dtype=bool)
        for (_, _, x0, x1, y0, y1) in pips_map[r]:
            # Mask strictly the crisp diamond ink & gold interior without smudging light gray watermark rays
            bx0, bx1 = max(76, x0 - 3), min(284, x1 + 3)
            by0, by1 = max(72, y0 - 3), min(450, y1 + 3)
            sub_hsv = hsv[by0:by1, bx0:bx1]
            sub_lum = np.mean(imgs[r][by0:by1, bx0:bx1], axis=-1)
            m_local = (sub_hsv[:, :, 1] > 86) | (sub_lum < 142.0)
            m_local = ndi.binary_dilation(m_local, iterations=2)
            m_pip[by0:by1, bx0:bx1] |= m_local
        clean_mask[r] = ~m_pip

    # Base starts from GULA_10 (untouched central compass!), then borrows clean pixels from siblings
    out = imgs["10"].copy()
    valid_base = clean_mask["10"].copy()
    for sibling in ["8", "7", "9"]:
        use_sib = (~valid_base) & clean_mask[sibling]
        out[use_sib] = imgs[sibling][use_sib]
        valid_base |= use_sib

    # Any pixel masked across all 4 cards (tiny extreme outer corner pixels) gets nearest clean paper + fine grain
    if np.any(~valid_base):
        _dist, indices = ndi.distance_transform_edt(~valid_base, return_indices=True)
        nearest_filled = out[indices[0], indices[1]]
        blurred = ndi.gaussian_filter(nearest_filled, sigma=(1.2, 1.2, 0.0))
        rng = np.random.default_rng(707)
        grain = rng.normal(0.0, 2.0, (540, 360, 1)).astype(np.float32)
        hole = ~valid_base
        out[hole] = np.clip(blurred[hole] + grain[hole], 0, 255)

    return np.clip(out, 0, 255).astype(np.uint8)


def sample_local_parchment_color(arr: np.ndarray, x0: int, y0: int, x1: int, y1: int) -> tuple:
    """Samples median paper color from immediate safe parchment strip without borders."""
    strip = arr[24:46, 100:260, :3].reshape(-1, 3).astype(np.float32)
    lum = np.mean(strip, axis=-1)
    bright = strip[lum > 185.0]
    if len(bright) < 20:
        return np.array([236.0, 226.0, 204.0], dtype=np.float32), np.array([3.5, 3.5, 3.5], dtype=np.float32)
    return np.median(bright, axis=0), np.std(bright, axis=0) * 0.4


def erase_rect_soft_parchment(arr: np.ndarray, x0: int, y0: int, x1: int, y1: int, feather: int = 8, seed: int = 9) -> None:
    """
    Erases corner indices on 540x810 cards via feathered local margin-strip texture cloning,
    or in-paints small inner diamond pips on 360x540 GULA court cards from safe surrounding paper.
    """
    h, w, _ = arr.shape
    x0c, y0c = max(21, x0), max(21, y0)
    x1c, y1c = min(w - 21, x1), min(h - 21, y1)
    if x1c <= x0c or y1c <= y0c:
        return

    is_tl = (x0c <= 30 and y0c <= 30)
    is_br = (x1c >= w - 30 and y1c >= h - 30)
    if h >= 700 and (is_tl or is_br):
        th, tw = y1c - y0c, x1c - x0c
        dst = arr[y0c:y1c, x0c:x1c, :3].astype(np.float32)
        d_lum = np.mean(dst, axis=-1)
        d_chr = np.max(dst, axis=-1) - np.min(dst, axis=-1)

        # Warm paper has chroma ~22-34; old black outlines have lum < 145 and vivid pips have chroma > 44
        target = ndi.binary_dilation((d_lum < 146.0) | (d_chr > 42.0), iterations=4)
        # Ensure clean untouched border ring at the edges closest to adjacent artwork
        if np.all(target):
            target = (d_lum < 146.0) | (d_chr > 42.0)
        if not np.any(target):
            return

        _dist, indices = ndi.distance_transform_edt(target, return_indices=True)
        nearest_paper = dst[indices[0], indices[1]]
        smooth_paper = ndi.gaussian_filter(nearest_paper, sigma=(2.2, 2.2, 0.0))
        rng_s = np.random.default_rng(seed)
        grain = rng_s.normal(0.0, 2.1, (th, tw, 1)).astype(np.float32)
        patch = np.clip(smooth_paper + grain, 0.0, 255.0)

        alpha = np.clip(ndi.gaussian_filter(target.astype(np.float32), sigma=1.2), 0.0, 1.0)
        blended = dst * (1.0 - alpha[:, :, None]) + patch * alpha[:, :, None]
        arr[y0c:y1c, x0c:x1c, :3] = np.clip(blended, 0, 255).astype(np.uint8)
        return

    # Define a safe paper-sampling ROI strictly inside the outer border [21..w-21, 21..h-21]
    sx0 = x0c
    sy0 = y0c
    sx1 = min(w - 21, x1c + 12)
    sy1 = min(h - 21, y1c + 64)
    if x0c > w // 2:
        sx0 = max(21, x0c - 12)
        sy0 = max(21, y0c - 64)
        sx1 = x1c
        sy1 = y1c

    roi = arr[sy0:sy1, sx0:sx1, :3].astype(np.float32)
    lum = np.mean(roi, axis=-1)
    chroma = np.max(roi, axis=-1) - np.min(roi, axis=-1)

    target = np.zeros((sy1 - sy0, sx1 - sx0), dtype=bool)
    ry0, ry1 = y0c - sy0, y1c - sy0
    rx0, rx1 = x0c - sx0, x1c - sx0
    is_fg = (lum < 178.0) | (chroma > 28.0)
    target[ry0:ry1, rx0:rx1] = is_fg[ry0:ry1, rx0:rx1]
    target = ndi.binary_dilation(target, iterations=3)
    outside = np.ones_like(target)
    outside[ry0:ry1, rx0:rx1] = False
    target[outside] = False

    if not np.any(target):
        return

    valid_paper = (~target) & (lum >= 145.0) & (chroma <= 34.0)
    if np.sum(valid_paper) < 30:
        valid_paper = (~target) & (lum >= 140.0)
    if np.sum(valid_paper) < 15:
        valid_paper = ~target
    vp_f = valid_paper.astype(np.float32)
    den = ndi.gaussian_filter(vp_f, sigma=16.0)
    filled = np.empty_like(roi)
    for ch_i in range(3):
        num = ndi.gaussian_filter(roi[:, :, ch_i] * vp_f, sigma=16.0)
        filled[:, :, ch_i] = np.where(den > 1e-4, num / np.maximum(den, 1e-4), float(np.median(roi[:, :, ch_i])))

    rng = np.random.default_rng(seed)
    grain = rng.normal(0.0, 2.6, (roi.shape[0], roi.shape[1], 1)).astype(np.float32)
    blended = np.clip(filled + grain, 0, 255)
    alpha = ndi.gaussian_filter(target.astype(np.float32), sigma=1.6)[:, :, None]
    out_roi = roi * (1.0 - alpha) + blended * alpha
    arr[sy0:sy1, sx0:sx1, :3] = np.clip(out_roi, 0, 255).astype(np.uint8)


def apply_organic_woodblock_wobble(card_540: Image.Image, seed: int) -> Image.Image:
    """
    Applies a continuous pearwood-block carving wobble (~1.1-1.9 px) across the printed card
    so straight computer frame lines & pip edges look genuinely hand-carved and hand-printed.
    """
    arr = np.array(card_540.convert("RGBA"), dtype=np.float32)
    h, w, c = arr.shape
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    low_dx = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=18.0)
    low_dy = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=18.0)
    hi_dx = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=3.8)
    hi_dy = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=3.8)

    # Normalize & combine multi-scale woodcut tremor
    low_dx /= max(1e-4, float(np.std(low_dx)))
    low_dy /= max(1e-4, float(np.std(low_dy)))
    hi_dx /= max(1e-4, float(np.std(hi_dx)))
    hi_dy /= max(1e-4, float(np.std(hi_dy)))

    # Keep outer card perimeter alpha crisp by fading displacement near outer 12px margin
    edge_d = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    env = np.clip((edge_d - 6.0) / 14.0, 0.0, 1.0)

    dx = (low_dx * 1.15 + hi_dx * 0.45) * env
    dy = (low_dy * 1.15 + hi_dy * 0.45) * env

    map_y = np.clip(yy + dy, 0.0, h - 1.0)
    map_x = np.clip(xx + dx, 0.0, w - 1.0)

    out = arr.copy()
    for ch in range(3):
        out[:, :, ch] = ndi.map_coordinates(arr[:, :, ch], [map_y, map_x], order=1, mode="nearest")
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def refine_court_card_woodcut_aging(card_540: Image.Image, suit: str, rank: str) -> Image.Image:
    """
    Transforms Classic Court portraits (D, H, K) from overly smooth AI symmetry into
    characterful hand-drawn 15th-century woodcut illustrations:
      - Breaks facial & head symmetry (asymmetric brow/eye height, organic jawline lean, crooked quill contour)
      - Separates & misregisters mineral pigment wash (+2.5px, +1.5px) against the black ink keyplate
      - Carves irregular diagonal burin cross-hatching in cheeks, brow shadows, beard & drapery folds
      - Quantizes smooth AI flesh/fabric gradients into coarse woodblock pigment tones + silvered hair
    """
    arr = np.array(card_540.convert("RGBA"), dtype=np.float32)
    sub = arr[120:650, 90:450, :3].copy()
    sh, sw, _ = sub.shape
    yy, xx = np.mgrid[0:sh, 0:sw].astype(np.float32)
    wy = yy + 120.0
    wx = xx + 90.0

    seed = 4100 + sum(ord(ch) * (i + 1) for i, ch in enumerate(suit + rank))
    rng = np.random.default_rng(seed)

    head_bounds = {
        "D": (192, 180, 326, 318),
        "H": (228, 240, 348, 362),
        "K": (218, 265, 342, 412),
    }
    hx0, hy0, hx1, hy1 = head_bounds.get(rank, (215, 220, 335, 360))
    cx_h = 0.5 * (hx0 + hx1)
    cy_h = 0.5 * (hy0 + hy1)

    # 1. Deterministic asymmetric warp field inside the portrait box (vanishes cleanly at ROI border)
    pad_w = np.sin(np.clip((xx) / max(1.0, sw - 1), 0.0, 1.0) * np.pi)
    pad_h = np.sin(np.clip((yy) / max(1.0, sh - 1), 0.0, 1.0) * np.pi)
    roi_env = np.sqrt(np.clip(pad_w * pad_h, 0.0, 1.0))

    face_dist = np.sqrt(((wx - cx_h) / 72.0) ** 2 + ((wy - cy_h) / 86.0) ** 2)
    face_env = np.exp(-0.5 * (face_dist ** 2))

    # Deliberate asymmetric brow/eye tilt + jaw nudge + slight hand-drawn figure lean
    eye_asym = np.tanh((wx - cx_h) / 28.0) * rng.choice([-1.0, 1.0]) * rng.uniform(2.1, 3.2)
    nose_skew = np.sin((wy - cy_h) / 22.0) * rng.choice([-1.0, 1.0]) * rng.uniform(1.8, 2.8)
    head_lean_x = (wy - (hy1 + 40.0)) * rng.choice([-1.0, 1.0]) * rng.uniform(0.018, 0.032)

    low_u = ndi.gaussian_filter(rng.normal(0.0, 1.0, (sh, sw)).astype(np.float32), sigma=16.0)
    low_v = ndi.gaussian_filter(rng.normal(0.0, 1.0, (sh, sw)).astype(np.float32), sigma=16.0)
    low_u /= max(1e-4, float(np.std(low_u)))
    low_v /= max(1e-4, float(np.std(low_v)))

    quill_u = ndi.gaussian_filter(rng.normal(0.0, 1.0, (sh, sw)).astype(np.float32), sigma=2.9)
    quill_v = ndi.gaussian_filter(rng.normal(0.0, 1.0, (sh, sw)).astype(np.float32), sigma=2.9)
    quill_u /= max(1e-4, float(np.std(quill_u)))
    quill_v /= max(1e-4, float(np.std(quill_v)))

    # Mask warp gently so near-border card ornaments don't shear off
    r, g, b = sub[:, :, 0], sub[:, :, 1], sub[:, :, 2]
    lum0 = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    chroma0 = np.max(sub, axis=-1) - np.min(sub, axis=-1)
    art_rough = ndi.binary_dilation((lum0 < 0.78) | (chroma0 > 32.0), iterations=3).astype(np.float32)
    art_soft = ndi.gaussian_filter(art_rough, sigma=5.0) * roi_env

    disp_x = (low_u * 2.2 + nose_skew * face_env + head_lean_x * face_env + quill_u * 1.15) * art_soft
    disp_y = (low_v * 2.0 + eye_asym * face_env + quill_v * 1.10) * art_soft

    map_y = np.clip(yy + disp_y, 0.0, sh - 1.0)
    map_x = np.clip(xx + disp_x, 0.0, sw - 1.0)
    warped = sub.copy()
    for ch in range(3):
        warped[:, :, ch] = ndi.map_coordinates(sub[:, :, ch], [map_y, map_x], order=1, mode="nearest")

    # 2. Separate Ink Keyplate vs. Misregistered Mineral Pigment Wash
    wr, wg, wb = warped[:, :, 0], warped[:, :, 1], warped[:, :, 2]
    lum = (0.299 * wr + 0.587 * wg + 0.114 * wb) / 255.0
    chroma = np.max(warped, axis=-1) - np.min(warped, axis=-1)
    is_art = ndi.binary_dilation(ndi.binary_opening((lum < 0.78) | (chroma > 34.0), iterations=1), iterations=1)

    in_head = is_art & (wx >= hx0) & (wx <= hx1) & (wy >= hy0) & (wy <= hy1)
    in_face = in_head & (wx >= hx0 + 10) & (wx <= hx1 - 10) & (wy >= hy0 + 16) & (wy <= hy1 - 8)

    # Extract crisp ink linework (dark outlines + Sobel strokes)
    gx = ndi.sobel(lum, axis=1)
    gy = ndi.sobel(lum, axis=0)
    edge_mag = np.hypot(gx, gy)
    ink_strength = np.clip((0.36 - lum) * 3.0 + edge_mag * 0.48, 0.0, 1.0) * is_art.astype(np.float32)

    # Quantize painted tones slightly to break silky AI airbrushing (preserve warmth & woodblock character)
    q_step = 28.0
    quant = np.round(warped / q_step) * q_step
    pigment = warped * 0.56 + quant * 0.44

    # Weather rosy modern skin slightly toward antique vellum-ochre with subtle uneven cheek flush
    skin_mask = in_face & (wr > wg + 6.0) & (wg >= wb - 5.0) & (lum > 0.34) & (lum < 0.82)
    ivory = np.array([222.0, 203.0, 170.0], dtype=np.float32)
    for ci in range(3):
        pigment[:, :, ci] = np.where(skin_mask, pigment[:, :, ci] * 0.72 + ivory[ci] * 0.28, pigment[:, :, ci])

    # Subtle suit-livery hand-tinted gouache on garments
    suit_livery = {
        "CERVEN": np.array([154.0, 42.0, 40.0], dtype=np.float32),
        "ZALUD":  np.array([136.0, 86.0, 36.0], dtype=np.float32),
        "ZELEN":  np.array([48.0, 104.0, 58.0], dtype=np.float32),
        "GULA":   np.array([166.0, 120.0, 34.0], dtype=np.float32),
    }
    tunic_mask = is_art & (~in_face) & (wy > hy0 + 34.0) & (lum > 0.20) & (lum < 0.68)
    w_col = suit_livery.get(suit, np.array([140.0, 110.0, 70.0], dtype=np.float32))
    for ci in range(3):
        pigment[:, :, ci] = np.where(tunic_mask, pigment[:, :, ci] * 0.82 + w_col[ci] * 0.18, pigment[:, :, ci])

    # Misregister pigment wash by (+2.4px, +1.4px) inside art interior
    mis_x = rng.choice([-2.4, 2.4])
    mis_y = rng.uniform(1.1, 1.8)
    pig_shifted = pigment.copy()
    shift_m_x = np.clip(xx - mis_x * is_art.astype(np.float32), 0.0, sw - 1.0)
    shift_m_y = np.clip(yy - mis_y * is_art.astype(np.float32), 0.0, sh - 1.0)
    for ci in range(3):
        pig_shifted[:, :, ci] = ndi.map_coordinates(pigment[:, :, ci], [shift_m_y, shift_m_x], order=1, mode="nearest")
    comp = np.where(is_art[:, :, None], pigment * 0.45 + pig_shifted * 0.55, warped)

    # 3. Hand-carved diagonal burin hatching (2 angled passes, broken uneven spacing — zero scanlines!)
    h_warp = ndi.gaussian_filter(rng.normal(0.0, 1.0, (sh, sw)).astype(np.float32), sigma=4.5) * 3.4
    hatch_break = ndi.gaussian_filter(rng.normal(0.0, 1.0, (sh, sw)).astype(np.float32), sigma=2.2)
    diag1 = np.sin((xx * 0.80 + yy * 0.60 + h_warp) * (3.14159 / 3.9)) > (0.50 + hatch_break * 0.18)
    diag2 = np.sin((xx * 0.62 - yy * 0.78 - h_warp * 0.8) * (3.14159 / 4.3)) > (0.54 + hatch_break * 0.18)

    eye_y0 = hy0 + (hy1 - hy0) * 0.32
    eye_y1 = hy0 + (hy1 - hy0) * 0.52
    skip_eyes = (wy >= eye_y0) & (wy <= eye_y1)
    ink_rgb = np.array([28.0, 19.0, 12.0], dtype=np.float32)

    face_hatch = in_face & (~skip_eyes) & (lum > 0.30) & (lum < 0.64) & diag1
    robe_mid_hatch = is_art & (~in_face) & (lum > 0.24) & (lum < 0.54) & diag1
    robe_deep_hatch = is_art & (~in_face) & (lum > 0.15) & (lum < 0.36) & diag2

    for ci in range(3):
        comp[:, :, ci] = np.where(face_hatch, comp[:, :, ci] * 0.66 + ink_rgb[ci] * 0.34, comp[:, :, ci])
        comp[:, :, ci] = np.where(robe_mid_hatch, comp[:, :, ci] * 0.72 + ink_rgb[ci] * 0.28, comp[:, :, ci])
        comp[:, :, ci] = np.where(robe_deep_hatch, comp[:, :, ci] * 0.64 + ink_rgb[ci] * 0.36, comp[:, :, ci])

    # 4. Silver/aged hair & beard highlights (strongest on King K & Watchman D)
    hair_dark = in_head & (~skin_mask) & (lum > 0.13) & (lum < 0.44) & (wr >= wb)
    strand = np.sin((xx * 1.4 + h_warp * 1.2) * (3.14159 / 3.3)) > 0.54
    silver_amt = 0.28 if rank == "K" else (0.20 if rank == "D" else 0.14)
    silver_col = np.array([180.0, 174.0, 160.0], dtype=np.float32)
    for ci in range(3):
        comp[:, :, ci] = np.where(hair_dark & strand, comp[:, :, ci] * (1.0 - silver_amt) + silver_col[ci] * silver_amt, comp[:, :, ci])

    # 5. Re-stamp warped crisp espresso woodcut ink keyplate on top for tactile pen contrast
    ink_mix = np.clip(ink_strength * 0.42, 0.0, 0.46)[:, :, None]
    comp = comp * (1.0 - ink_mix) + ink_rgb[None, None, :] * ink_mix

    arr[120:650, 90:450, :3] = np.clip(comp, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def draw_clean_corner_index(card_540: Image.Image, suit: str, rank: str, suit_icon: Image.Image) -> Image.Image:
    """
    In-paints original corner glyphs seamlessly into surrounding real card paper (zero box seam!)
    and stamps bold, slightly hand-stamped corner digits/emblems inside x=[19..81], y=[20..150].
    """
    arr = np.array(card_540.convert("RGBA"))
    seed_base = sum(ord(c) for c in (suit + rank))
    erase_rect_soft_parchment(arr, 21, 21, 80, 152, feather=4, seed=101 + seed_base)
    erase_rect_soft_parchment(arr, CARD_W - 80, CARD_H - 152, CARD_W - 21, CARD_H - 21, feather=4, seed=202 + seed_base)
    base = Image.fromarray(arr, "RGBA")

    rng = np.random.default_rng(505 + seed_base)

    def render_corner_stamp(tilt_deg: float) -> Image.Image:
        sw, sh = 122, 266
        stamp = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
        sd = ImageDraw.Draw(stamp)
        fsize = 84 if rank == "10" else 96
        font = ImageFont.truetype(str(FONT_DISPLAY), fsize)
        col = SUIT_INK_RGB[suit]

        bb = sd.textbbox((0, 0), rank, font=font, stroke_width=3)
        tw, th = bb[2] - bb[0], bb[3] - bb[1]

        if rank == "10":
            tmp = Image.new("RGBA", (tw + 24, th + 28), (0, 0, 0, 0))
            td = ImageDraw.Draw(tmp)
            td.text((12 - bb[0], 10 - bb[1]), rank, font=font, fill=col,
                    stroke_width=3, stroke_fill=(24, 15, 10, 255))
            cond = tmp.resize((int(round((tw + 24) * 0.76)), th + 28), Image.Resampling.LANCZOS)
            stamp.alpha_composite(cond, ((sw - cond.width) // 2, 6))
        else:
            tx = (sw - tw) // 2 - bb[0]
            ty = 12 - bb[1]
            sd.text((tx + 2, ty + 3), rank, font=font, fill=(24, 15, 10, 118))
            sd.text((tx, ty), rank, font=font, fill=col, stroke_width=3, stroke_fill=(24, 15, 10, 255))

        icon_up = suit_icon.resize((84, 84), Image.Resampling.LANCZOS)
        stamp.alpha_composite(icon_up, ((sw - 84) // 2, 130))
        small = stamp.resize((61, 133), Image.Resampling.LANCZOS)
        return small.rotate(tilt_deg, resample=Image.Resampling.BICUBIC, expand=False)

    tl_stamp = render_corner_stamp(float(rng.uniform(-1.3, 1.3)))
    br_stamp = render_corner_stamp(float(rng.uniform(-1.3, 1.3))).rotate(180)
    dx1, dy1 = int(rng.integers(-1, 2)), int(rng.integers(-1, 2))
    dx2, dy2 = int(rng.integers(-1, 2)), int(rng.integers(-1, 2))
    base.alpha_composite(tl_stamp, (18 + dx1, 19 + dy1))
    base.alpha_composite(br_stamp, (CARD_W - 79 + dx2, CARD_H - 152 + dy2))
    return base


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    assert ORIG_DIR.exists(), f"Missing {ORIG_DIR}"

    suit_icons = {s: extract_suit_emblem_from_orig(s, 96) for s in SUITS}
    gula_pip_map = detect_gula_pip_boxes_360()
    gula_clean_base_360 = build_gula_clean_pip_base_360(gula_pip_map)

    bell_corner_48 = draw_engraved_koule(48)
    bell_inner_44 = draw_engraved_koule(44)
    bell_pip_82 = draw_engraved_koule(82)
    bell_shield_126 = draw_engraved_koule(126)

    for suit in SUITS:
        for rank in RANKS:
            orig_path = ORIG_DIR / f"{suit}_{rank}.png"
            out_path = OUT_DIR / f"{suit}_{rank}.png"

            if suit == "GULA" and rank in ["7", "8", "9", "10"]:
                base_540 = Image.fromarray(gula_clean_base_360, "RGB").convert("RGBA").resize((CARD_W, CARD_H), Image.Resampling.LANCZOS)
                base_540 = ImageEnhance.Sharpness(base_540).enhance(1.16)
                for (px, py, _x0, _x1, _y0, _y1) in gula_pip_map[rank]:
                    cx = int(round(px * 1.5))
                    cy = int(round(py * 1.5))
                    base_540.alpha_composite(bell_pip_82, (cx - bell_pip_82.width // 2, cy - bell_pip_82.height // 2))
            elif suit == "GULA" and rank in ["D", "H", "K", "E"]:
                orig_arr = np.array(Image.open(orig_path).convert("RGBA"))
                # Erase inner top-right & bottom-left diamonds softly at 360x540
                for (cx3, cy3) in [(276, 77), (83, 463)]:
                    erase_rect_soft_parchment(orig_arr, cx3 - 17, cy3 - 20, cx3 + 17, cy3 + 20, feather=4, seed=303 + cx3)

                if rank == "E":
                    # Mirror clean right half of the heraldic shield & sunburst (x:180..226) onto left half (x:134..180)
                    # across y:214..324 so the protruding tilted diamond corner vanishes cleanly while oak leaves outside x<138 stay!
                    shield_y0, shield_y1 = 216, 323
                    for yy in range(shield_y0, shield_y1):
                        # Only replace up to left rim edge (~x=139 at top -> 180 at bottom tip)
                        t_y = (yy - 220) / max(1.0, (322 - 220))
                        left_lim = 142 if yy < 286 else int(round(142 + ((yy - 286) / 36.0) * 38.0))
                        # Avoid erasing green oak leaves at outer left
                        for xx in range(left_lim, 181):
                            mir_x = 360 - xx
                            orig_arr[yy, xx, :3] = orig_arr[yy, mir_x, :3]
                    # Fill symmetrical heraldic shield interior with clean warm ivory gradient
                    sub_rgb = orig_arr[200:340, 125:235, :3]
                    lum = np.mean(sub_rgb, axis=-1)
                    rim = lum < 65.0
                    filled = ndi.binary_fill_holes(rim)
                    inside = filled & (~rim)
                    inside_eroded = ndi.binary_erosion(inside, iterations=2)
                    lab, nlab = ndi.label(inside_eroded)
                    if nlab > 0:
                        best_k = max(range(1, nlab + 1), key=lambda k: int(np.sum(lab == k)))
                        smask = ndi.binary_dilation(lab == best_k, iterations=1) & (~rim)
                        yy, xx = np.mgrid[0:sub_rgb.shape[0], 0:sub_rgb.shape[1]].astype(np.float32)
                        radial = np.clip(np.sqrt(((xx - 55.0) / 48.0) ** 2 + ((yy - 64.0) / 52.0) ** 2), 0.0, 1.0)
                        iv_r = np.clip(246.0 - radial * 22.0, 0, 255)
                        iv_g = np.clip(236.0 - radial * 28.0, 0, 255)
                        iv_b = np.clip(208.0 - radial * 38.0, 0, 255)
                        for ch_idx, vals in enumerate([iv_r, iv_g, iv_b]):
                            sub_rgb[:, :, ch_idx] = np.where(smask, vals.astype(np.uint8), sub_rgb[:, :, ch_idx])
                        orig_arr[200:340, 125:235, :3] = sub_rgb

                base_540 = Image.fromarray(orig_arr, "RGBA").resize((CARD_W, CARD_H), Image.Resampling.LANCZOS)
                base_540 = ImageEnhance.Sharpness(base_540).enhance(1.16)
                base_540.alpha_composite(bell_inner_44, (int(round(276.5 * 1.5)) - 22, int(round(77.3 * 1.5)) - 22))
                base_540.alpha_composite(bell_inner_44.rotate(180), (int(round(82.5 * 1.5)) - 22, int(round(462.7 * 1.5)) - 22))
                if rank == "E":
                    base_540.alpha_composite(bell_shield_126, (270 - bell_shield_126.width // 2, 405 - bell_shield_126.height // 2))
            else:
                base_540 = Image.open(orig_path).convert("RGBA").resize((CARD_W, CARD_H), Image.Resampling.LANCZOS)
                base_540 = ImageEnhance.Sharpness(base_540).enhance(1.18)

            if rank in ["D", "H", "K"]:
                base_540 = refine_court_card_woodcut_aging(base_540, suit, rank)

            base_540 = draw_clean_corner_index(base_540, suit, rank, bell_corner_48 if suit == "GULA" else suit_icons[suit])
            final_card = apply_organic_woodblock_wobble(base_540, 9100 + sum(ord(ch) * (k + 1) for k, ch in enumerate(suit + rank)))
            final_card.save(out_path, "PNG")
        print(f"Upgraded 8 classic cards for {suit}")

    print("Classic deck Czech antique copperplate upgrade v2 complete (32 cards -> 540x810 RGBA).")


if __name__ == "__main__":
    main()
