"""
Builds all 24 detailed copperplate/woodcut relic icons (assets/relics/REL_*.png, 256x256 RGBA)
and upgrades SPEC_CROWN.png, SPEC_PLAGUE.png, and SPEC_PRISM.png (360x540 RGBA)
plus exports an engraved Golden Hawk-Bell renderer for GULA cards.
"""
import math
import pathlib
import numpy as np
import scipy.ndimage as ndi
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont

ROOT = pathlib.Path(r"D:\downpour-godot")
RELIC_DIR = ROOT / "assets" / "relics"
CARD_DIR = ROOT / "assets" / "cards"
ART_DIR = pathlib.Path(r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d")
FONT_DISPLAY = ROOT / "assets" / "fonts" / "LialoDisplay.ttf"

INK = (26, 17, 12, 255)
INK_SOFT = (44, 29, 20, 225)
GOLD_LIGHT = (248, 220, 128, 255)
GOLD_MID = (204, 152, 54, 255)
GOLD_DARK = (128, 82, 22, 255)
COPPER_LIGHT = (232, 146, 92, 255)
COPPER_DARK = (138, 66, 34, 255)
STEEL_LIGHT = (212, 222, 232, 255)
STEEL_MID = (138, 152, 166, 255)
STEEL_DARK = (64, 74, 86, 255)
CRIMSON_LIGHT = (212, 58, 64, 255)
CRIMSON_DARK = (118, 22, 30, 255)
EMERALD_LIGHT = (116, 186, 98, 255)
EMERALD_DARK = (46, 96, 48, 255)
AZURE_LIGHT = (128, 214, 255, 255)
AZURE_DARK = (46, 112, 176, 255)
PARCH_LIGHT = (242, 230, 202, 255)
PARCH_DARK = (188, 164, 124, 255)


def extract_ai_relic_transparent(src_path: pathlib.Path, out_path: pathlib.Path, target_size: int = 256) -> None:
    """Removes clean white studio background from AI-generated artwork via flood-fill and edge de-fringe."""
    im = Image.open(src_path).convert("RGB")
    arr = np.array(im, dtype=np.float32)
    h, w, _ = arr.shape

    lum = np.mean(arr, axis=-1)
    chroma = np.max(arr, axis=-1) - np.min(arr, axis=-1)
    is_bg_cand = (lum >= 232.0) & (chroma <= 24.0)

    # Flood fill strictly connected to image borders so interior white highlights stay intact
    bg_seed = np.zeros((h, w), dtype=bool)
    bg_seed[0, :] = True
    bg_seed[-1, :] = True
    bg_seed[:, 0] = True
    bg_seed[:, -1] = True

    lab, _ = ndi.label(is_bg_cand, structure=np.ones((3, 3), dtype=bool))
    border_labels = set(np.unique(lab[bg_seed])) - {0}
    bg_mask = np.isin(lab, list(border_labels))

    # Expand 1px soft matte and compute smooth alpha from brightness/distance on fringe
    bg_near = ndi.binary_dilation(bg_mask, iterations=2) & (~bg_mask)
    alpha = np.where(bg_mask, 0.0, 255.0).astype(np.float32)
    # Feather partial white halo pixels touching bg
    fringe = bg_near & (lum > 185.0) & (chroma < 32.0)
    alpha[fringe] = np.clip((242.0 - lum[fringe]) / 57.0 * 255.0, 0.0, 255.0)

    # De-fringe white contamination on semi-transparent boundary pixels
    semi = (alpha > 0) & (alpha < 245)
    for c in range(3):
        a_f = np.maximum(alpha[semi] / 255.0, 0.15)
        arr[semi, c] = np.clip((arr[semi, c] - 255.0 * (1.0 - a_f)) / a_f, 0.0, 255.0)

    # Tiny alpha anti-alias blur
    alpha_sm = ndi.gaussian_filter(alpha, sigma=0.55)
    alpha = np.where(bg_mask, 0.0, np.where(alpha > 240.0, 255.0, alpha_sm))

    rgba = np.dstack([np.clip(arr, 0, 255), np.clip(alpha, 0, 255)]).astype(np.uint8)

    # Tight crop around opaque content
    ys, xs = np.where(rgba[:, :, 3] > 20)
    if len(xs) > 0:
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        crop = Image.fromarray(rgba[y0 : y1 + 1, x0 : x1 + 1], "RGBA")
    else:
        crop = Image.fromarray(rgba, "RGBA")

    inner = int(round(target_size * 0.86))
    cw, ch = crop.size
    scale = min(inner / max(1, cw), inner / max(1, ch))
    nw, nh = max(1, int(round(cw * scale))), max(1, int(round(ch * scale)))
    resized = crop.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    canvas.paste(resized, ((target_size - nw) // 2, (target_size - nh) // 2), resized)
    canvas = ImageEnhance.Contrast(canvas).enhance(1.06)
    canvas.save(out_path, "PNG")


def copperplate_shade_and_ink(img: Image.Image, seed: int = 42, add_outer_ink: bool = True, ink_px: int = 3) -> Image.Image:
    """
    Applies directional 3D lighting, copperplate diagonal hatching in shadow tones,
    subtle organic grain, and bold outer dark-ink contour outline to a 512x512 RGBA sprite.
    """
    arr = np.array(img, dtype=np.float32)
    h, w, _ = arr.shape
    alpha = arr[:, :, 3]
    opaque = alpha > 24

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # Normalized object-space coordinates for soft directional curvature shading
    ys, xs = np.where(opaque)
    if len(xs) > 10:
        cx, cy = float(xs.mean()), float(ys.mean())
        rad = max(20.0, float(max(xs.ptp() if hasattr(xs, "ptp") else np.ptp(xs), np.ptp(ys))) * 0.55)
        nx = (xx - cx) / rad
        ny = (yy - cy) / rad
        # Upper-left warm key, lower-right deep engraved shadow
        dir_light = np.clip(0.98 - (nx * 0.14 + ny * 0.18), 0.72, 1.14)
        for c in range(3):
            arr[:, :, c] = np.where(opaque, np.clip(arr[:, :, c] * dir_light, 0, 255), arr[:, :, c])

    # Copperplate hatching lines keyed to midtone/shadow areas (skip already near-black ink lines!)
    lum = (0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]) / 255.0
    p1 = np.sin((xx * 0.72 + yy * 0.69) * (math.pi / 4.2))
    p2 = np.sin((xx * 0.68 - yy * 0.73) * (math.pi / 4.6))
    hatch1 = p1 > 0.58
    hatch2 = p2 > 0.64

    shade_mask_1 = opaque & (lum > 0.18) & (lum < 0.66) & hatch1
    shade_mask_2 = opaque & (lum > 0.18) & (lum < 0.42) & hatch2
    hatch_dark = np.where(shade_mask_2, 0.52, np.where(shade_mask_1, 0.68, 1.0))

    # Subtle hand-engraved ink speckle grain
    rng = np.random.default_rng(seed)
    grain = rng.normal(1.0, 0.028, (h, w)).astype(np.float32)
    grain = ndi.gaussian_filter(grain, sigma=0.45)

    for c in range(3):
        arr[:, :, c] = np.where(opaque, np.clip(arr[:, :, c] * hatch_dark * grain, 0, 255), arr[:, :, c])

    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    if add_outer_ink and ink_px > 0:
        mask_img = out.getchannel("A")
        dil = mask_img.filter(ImageFilter.MaxFilter(ink_px * 2 + 1))
        border_a = np.maximum(np.array(dil, dtype=np.int16) - np.array(mask_img, dtype=np.int16), 0)
        ink_layer = Image.new("RGBA", (w, h), INK)
        ink_layer.putalpha(Image.fromarray(np.clip(border_a, 0, 255).astype(np.uint8)))
        # Composite crisp object on top of outer sepia-ink contour
        combined = Image.alpha_composite(ink_layer, out)
        return combined
    return out


def finalize_relic(im_512: Image.Image, out_path: pathlib.Path, seed: int, ink_px: int = 3) -> None:
    """Shades/inks at 512x512, centers cleanly, and downsamples to crisp 256x256 RGBA."""
    shaded = copperplate_shade_and_ink(im_512, seed=seed, add_outer_ink=True, ink_px=ink_px)
    arr = np.array(shaded)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) > 0:
        pad = 8
        x0 = max(0, int(xs.min()) - pad)
        y0 = max(0, int(ys.min()) - pad)
        x1 = min(arr.shape[1] - 1, int(xs.max()) + pad)
        y1 = min(arr.shape[0] - 1, int(ys.max()) + pad)
        crop = Image.fromarray(arr[y0 : y1 + 1, x0 : x1 + 1], "RGBA")
        cw, ch = crop.size
        target_inner = 224
        scale = min(target_inner / max(1, cw), target_inner / max(1, ch))
        nw, nh = max(1, int(round(cw * scale))), max(1, int(round(ch * scale)))
        res = crop.resize((nw, nh), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        canvas.paste(res, ((256 - nw) // 2, (256 - nh) // 2), res)
    else:
        canvas = shaded.resize((256, 256), Image.Resampling.LANCZOS)
    canvas = ImageEnhance.Sharpness(canvas).enhance(1.12)
    canvas.save(out_path, "PNG")


def radial_fill_ellipse(canvas: Image.Image, bbox: tuple, col_inner: tuple, col_outer: tuple,
                        outline=INK, width: int = 5, light_off=(-0.28, -0.32)) -> None:
    """Draws an elliptical metallic/organic volume filled with off-center 3D radial shading."""
    x0, y0, x1, y1 = [float(v) for v in bbox]
    w_box = max(2, int(math.ceil(x1 - x0)))
    h_box = max(2, int(math.ceil(y1 - y0)))
    yy, xx = np.mgrid[0:h_box, 0:w_box].astype(np.float32)
    cx = w_box * (0.5 + light_off[0] * 0.45)
    cy = h_box * (0.5 + light_off[1] * 0.45)
    rx = max(1.0, w_box * 0.52)
    ry = max(1.0, h_box * 0.52)
    t = np.clip(np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2), 0.0, 1.0)
    t = t ** 1.15
    grad = np.zeros((h_box, w_box, 4), dtype=np.uint8)
    for c in range(4):
        grad[:, :, c] = np.clip(col_inner[c] * (1.0 - t) + col_outer[c] * t, 0, 255).astype(np.uint8)
    mask = Image.new("L", (w_box, h_box), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse((0, 0, w_box - 1, h_box - 1), fill=255)
    patch = Image.fromarray(grad, "RGBA")
    patch.putalpha(mask)
    canvas.alpha_composite(patch, (int(round(x0)), int(round(y0))))
    if outline is not None and width > 0:
        d = ImageDraw.Draw(canvas)
        d.ellipse((x0, y0, x1, y1), outline=outline, width=width)


def fill_poly_shaded(canvas: Image.Image, pts: list, col_a: tuple, col_b: tuple,
                     p_a: tuple, p_b: tuple, outline=INK, width: int = 4) -> None:
    """Fills a polygon with linear directional gradient shading + inked contour."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, y0 = max(0, int(math.floor(min(xs))) - 2), max(0, int(math.floor(min(ys))) - 2)
    x1, y1 = min(canvas.width - 1, int(math.ceil(max(xs))) + 2), min(canvas.height - 1, int(math.ceil(max(ys))) + 2)
    bw, bh = max(2, x1 - x0 + 1), max(2, y1 - y0 + 1)

    mask = Image.new("L", (bw, bh), 0)
    md = ImageDraw.Draw(mask)
    md.polygon([(p[0] - x0, p[1] - y0) for p in pts], fill=255)

    yy, xx = np.mgrid[0:bh, 0:bw].astype(np.float32)
    wx = xx + x0
    wy = yy + y0
    vx, vy = (p_b[0] - p_a[0]), (p_b[1] - p_a[1])
    vlen2 = max(1.0, vx * vx + vy * vy)
    t = np.clip(((wx - p_a[0]) * vx + (wy - p_a[1]) * vy) / vlen2, 0.0, 1.0)
    grad = np.zeros((bh, bw, 4), dtype=np.uint8)
    for c in range(4):
        grad[:, :, c] = np.clip(col_a[c] * (1.0 - t) + col_b[c] * t, 0, 255).astype(np.uint8)
    patch = Image.fromarray(grad, "RGBA")
    patch.putalpha(mask)
    canvas.alpha_composite(patch, (x0, y0))
    if outline is not None and width > 0:
        d = ImageDraw.Draw(canvas)
        d.polygon(pts, outline=outline, width=width)


def draw_star_spark(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, col=(255, 246, 200, 255), outline=INK):
    pts = []
    for i in range(8):
        ang = i * math.pi / 4.0
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    d.polygon(pts, fill=col, outline=outline, width=max(1, int(r * 0.1)))


def draw_engraved_koule(size: int) -> Image.Image:
    """
    Renders a rich copperplate-engraved golden Czech Hawk-Bell (Rolnicka / Koule)
    at 2x supersampling then downsamples cleanly to (size, size) RGBA.
    """
    ss = size * 2
    im = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = ss * 0.5, ss * 0.53
    r = ss * 0.36

    # Top suspension crown loop
    loop_r = r * 0.23
    d.ellipse((cx - loop_r, cy - r * 1.18 - loop_r, cx + loop_r, cy - r * 1.18 + loop_r),
              fill=GOLD_DARK, outline=INK, width=max(3, ss // 42))
    d.ellipse((cx - loop_r * 0.45, cy - r * 1.18 - loop_r * 0.45, cx + loop_r * 0.45, cy - r * 1.18 + loop_r * 0.45),
              fill=(0, 0, 0, 0), outline=INK, width=max(2, ss // 56))
    # Flared bell collar
    d.rounded_rectangle((cx - r * 0.32, cy - r * 1.06, cx + r * 0.32, cy - r * 0.84),
                        radius=int(r * 0.08), fill=GOLD_MID, outline=INK, width=max(3, ss // 44))

    # Main spherical bell body with 3D radial highlight
    radial_fill_ellipse(im, (cx - r, cy - r, cx + r, cy + r), (255, 236, 152, 255), GOLD_DARK,
                        outline=INK, width=max(4, ss // 36), light_off=(-0.38, -0.38))

    # Equatorial molded brass ridge ribs (triple-banded rim!)
    d = ImageDraw.Draw(im)
    for dy, h_band, fill_c in [
        (-r * 0.12, r * 0.10, GOLD_DARK),
        (-r * 0.02, r * 0.12, GOLD_LIGHT),
        (r * 0.08, r * 0.09, (110, 68, 18, 255)),
    ]:
        # Clip band nicely within sphere width at y=dy
        bw = math.sqrt(max(0.1, r * r - dy * dy)) * 0.99
        d.rounded_rectangle((cx - bw, cy + dy - h_band * 0.5, cx + bw, cy + dy + h_band * 0.5),
                            radius=int(h_band * 0.4), fill=fill_c, outline=INK, width=max(2, ss // 55))

    # Lower acoustic keyhole sound-slit & circular resonant bores
    hole_y = cy + r * 0.48
    hole_r = r * 0.16
    slit_w = r * 0.48
    d.line([(cx - slit_w, hole_y), (cx + slit_w, hole_y)], fill=INK, width=max(4, ss // 30))
    d.ellipse((cx - slit_w - hole_r * 0.85, hole_y - hole_r * 0.85,
               cx - slit_w + hole_r * 0.85, hole_y + hole_r * 0.85), fill=INK)
    d.ellipse((cx + slit_w - hole_r * 0.85, hole_y - hole_r * 0.85,
               cx + slit_w + hole_r * 0.85, hole_y + hole_r * 0.85), fill=INK)
    # Metallic rim glint around acoustic bore holes
    d.arc((cx - slit_w - hole_r, hole_y - hole_r, cx - slit_w + hole_r, hole_y + hole_r),
          20, 190, fill=GOLD_LIGHT, width=max(2, ss // 64))
    d.arc((cx + slit_w - hole_r, hole_y - hole_r, cx + slit_w + hole_r, hole_y + hole_r),
          350, 170, fill=GOLD_LIGHT, width=max(2, ss // 64))

    # Engraved upper hemisphere meridian lines + specular glint crescent
    for ang_x in (-0.42, -0.18, 0.18, 0.42):
        d.arc((cx - r * abs(ang_x) - r * 0.12, cy - r * 0.96, cx + r * abs(ang_x) + r * 0.12, cy - r * 0.14),
              210 if ang_x < 0 else 285, 255 if ang_x < 0 else 330, fill=INK_SOFT, width=max(2, ss // 68))

    # Curved white-gold specular gleam top-left
    d.arc((cx - r * 0.78, cy - r * 0.78, cx + r * 0.20, cy + r * 0.16),
          195, 255, fill=(255, 252, 224, 240), width=max(3, ss // 38))
    # Tiny inner brass clapper pea peeking in center keyhole notch
    d.ellipse((cx - r * 0.13, hole_y - r * 0.13, cx + r * 0.13, hole_y + r * 0.13), fill=INK)
    d.ellipse((cx - r * 0.07, hole_y - r * 0.07, cx + r * 0.07, hole_y + r * 0.07), fill=GOLD_LIGHT)

    im = copperplate_shade_and_ink(im, seed=77, add_outer_ink=False)
    out = im.resize((size, size), Image.Resampling.LANCZOS)
    return ImageEnhance.Sharpness(out).enhance(1.15)


# ==============================================================================
# Individual 18 Synthesized Copperplate Relics (each drawn on 512x512 RGBA)
# ==============================================================================

def art_stormcap() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Azure lightning arcs crackling from brass top sphere
    bolt1 = [(256, 76), (190, 128), (222, 148), (118, 226), (178, 228), (122, 306), (206, 210), (166, 206), (242, 134)]
    bolt2 = [(256, 76), (322, 128), (294, 150), (392, 230), (336, 232), (382, 314), (304, 212), (344, 208), (272, 136)]
    d.polygon(bolt1, fill=AZURE_LIGHT, outline=INK, width=4)
    d.polygon(bolt2, fill=AZURE_LIGHT, outline=INK, width=4)
    # Leyden glass cylinder + inner glowing plasma core
    fill_poly_shaded(im, [(172, 178), (340, 178), (350, 424), (162, 424)],
                     (112, 198, 240, 220), (32, 86, 134, 240), (170, 200), (350, 420), width=5)
    # Copper foil jacket around lower half
    fill_poly_shaded(im, [(166, 276), (346, 276), (354, 426), (158, 426)],
                     COPPER_LIGHT, COPPER_DARK, (165, 280), (348, 425), width=5)
    d = ImageDraw.Draw(im)
    # Ribbed copper coil windings
    for y in range(288, 404, 22):
        d.rounded_rectangle((156, y, 356, y + 10), radius=4, fill=GOLD_MID, outline=INK, width=3)
    # Brass rim cap & insulator pedestal + riveted base
    d.rounded_rectangle((150, 162, 362, 196), radius=10, fill=GOLD_MID, outline=INK, width=5)
    d.rounded_rectangle((144, 420, 368, 458), radius=12, fill=GOLD_DARK, outline=INK, width=5)
    for rx in range(172, 350, 42):
        d.ellipse((rx - 6, 433, rx + 6, 445), fill=GOLD_LIGHT, outline=INK, width=2)
    # Vertical discharge rod + electrode sphere
    d.rectangle((244, 78, 268, 168), fill=GOLD_MID, outline=INK, width=4)
    radial_fill_ellipse(im, (218, 44, 294, 120), GOLD_LIGHT, GOLD_DARK, width=5)
    d = ImageDraw.Draw(im)
    draw_star_spark(d, 256, 82, 22, (230, 252, 255, 255))
    return im


def art_knuckle() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Weighted isometric carved ivory knucklebone / weighted hexed bone die
    # Faceted ivory polyhedron shape (knucklebone astragalus silhouette)
    pts_body = [
        (132, 120), (192, 96), (256, 126), (320, 96), (380, 120),
        (408, 178), (376, 256), (402, 344), (364, 408), (296, 422),
        (256, 386), (216, 422), (148, 408), (110, 344), (136, 256), (104, 178)
    ]
    fill_poly_shaded(im, pts_body, (248, 238, 214, 255), (168, 146, 114, 255), (130, 120), (390, 400), width=6)
    d = ImageDraw.Draw(im)
    # Articulated ridge saddle across waist
    d.line([(136, 256), (196, 272), (256, 248), (316, 272), (376, 256)], fill=INK, width=5)
    d.line([(256, 126), (242, 210), (256, 248), (266, 326), (256, 386)], fill=INK_SOFT, width=4)
    # Gold inlay core plate & crimson bone pips
    radial_fill_ellipse(im, (218, 218, 294, 294), GOLD_LIGHT, GOLD_DARK, width=5)
    for px, py, r in [(176, 152, 13), (336, 152, 13), (176, 348, 13), (336, 348, 13)]:
        radial_fill_ellipse(im, (px - r, py - r, px + r, py + r), CRIMSON_LIGHT, CRIMSON_DARK, width=3)
    d = ImageDraw.Draw(im)
    # Bone fissures & brass corner rivets
    d.line([(168, 202), (196, 224), (186, 242)], fill=INK, width=3)
    d.line([(344, 292), (318, 314), (330, 336)], fill=INK, width=3)
    # Floating tiny golden die accent
    fill_poly_shaded(im, [(348, 66), (420, 90), (420, 156), (348, 132)], GOLD_LIGHT, GOLD_MID, (348, 66), (420, 156), width=4)
    fill_poly_shaded(im, [(420, 90), (464, 68), (464, 134), (420, 156)], GOLD_MID, GOLD_DARK, (420, 90), (464, 156), width=4)
    fill_poly_shaded(im, [(348, 66), (392, 44), (464, 68), (420, 90)], (255, 242, 182, 255), GOLD_LIGHT, (348, 44), (464, 90), width=4)
    d = ImageDraw.Draw(im)
    d.ellipse((380, 98, 394, 112), fill=CRIMSON_DARK)
    return im


def art_phoenix_f() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Main sweeping scalloped feather vane built with overlapping organic notches
    spine = [(118, 434), (174, 344), (242, 246), (318, 154), (402, 74)]
    left_vane = [
        (146, 392), (126, 348), (154, 326), (138, 274), (176, 256),
        (170, 198), (212, 184), (222, 126), (272, 118), (304, 72), (402, 74)
    ]
    right_vane = [
        (402, 74), (382, 152), (344, 168), (352, 218), (308, 236),
        (312, 288), (262, 300), (252, 348), (196, 358), (160, 394)
    ]
    vane_poly = left_vane + list(reversed(right_vane[1:]))
    # Draw barb engraving strokes on a separate layer clipped cleanly inside the filled vane silhouette
    fill_poly_shaded(im, left_vane + list(reversed(spine)), (255, 198, 72, 255), CRIMSON_DARK, (390, 80), (140, 390), width=5)
    fill_poly_shaded(im, spine + right_vane, (255, 146, 48, 255), (148, 26, 22, 255), (390, 80), (160, 390), width=5)
    vane_mask = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(vane_mask).polygon(vane_poly, fill=255)
    barb_layer = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    bd = ImageDraw.Draw(barb_layer)
    for t_i in range(1, 20):
        t = t_i / 20.0
        sx = 128 + t * 256
        sy = 418 - t * 324 - math.sin(t * math.pi) * 26
        bd.line([(sx, sy), (sx - 64, sy - 58)], fill=INK, width=3)
        bd.line([(sx, sy), (sx + 66, sy + 32)], fill=INK, width=3)
    barb_layer.putalpha(Image.fromarray(np.minimum(np.array(barb_layer.getchannel("A")), np.array(vane_mask))))
    im = Image.alpha_composite(im, barb_layer)
    d = ImageDraw.Draw(im)
    # Golden quill shaft
    d.line([(90, 458), (168, 350), (258, 232), (398, 78)], fill=INK, width=12)
    d.line([(90, 458), (168, 350), (258, 232), (398, 78)], fill=GOLD_LIGHT, width=6)
    # Glowing cinder sparks
    for cx, cy, rr in [(104, 190, 14), (364, 336, 16), (416, 172, 12), (242, 84, 12), (206, 412, 11)]:
        draw_star_spark(d, cx, cy, rr, (255, 220, 96, 255))
    return im


def art_fang() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Dark gothic iron filigree collar socket at top-left
    collar_pts = [(134, 88), (246, 54), (294, 134), (240, 176), (138, 172)]
    fill_poly_shaded(im, collar_pts, STEEL_LIGHT, STEEL_DARK, (134, 60), (294, 180), width=6)
    d = ImageDraw.Draw(im)
    # Hanging chain ring on collar
    d.ellipse((142, 46, 198, 102), outline=INK, width=10)
    d.ellipse((142, 46, 198, 102), outline=GOLD_MID, width=5)
    # Scalloped silver bezel claws gripping ivory tooth
    fill_poly_shaded(im, [(146, 152), (274, 132), (284, 166), (256, 200), (222, 178), (186, 206), (144, 174)],
                     GOLD_LIGHT, GOLD_DARK, (144, 132), (284, 206), width=5)
    # Curved ivory fang curving cleanly down to sharp point bottom-right
    fang_pts = [
        (166, 174), (268, 158), (284, 224), (316, 304), (368, 396),
        (388, 434), (344, 414), (276, 358), (218, 286), (174, 220)
    ]
    fill_poly_shaded(im, fang_pts, (252, 246, 228, 255), (178, 158, 128, 255), (170, 170), (370, 420), width=6)
    d = ImageDraw.Draw(im)
    # Carved blood runes etched on fang enamel
    for rx, ry in [(226, 212), (248, 254), (278, 298)]:
        d.line([(rx - 8, ry), (rx + 12, ry - 12)], fill=CRIMSON_DARK, width=4)
        d.line([(rx + 2, ry - 14), (rx + 4, ry + 10)], fill=CRIMSON_DARK, width=4)
    # Glistening crimson blood droplets falling from fang tip
    fill_poly_shaded(im, [(386, 432), (402, 466), (392, 480), (376, 474), (372, 456)],
                     CRIMSON_LIGHT, CRIMSON_DARK, (372, 432), (402, 480), width=3)
    radial_fill_ellipse(im, (278, 378, 314, 420), CRIMSON_LIGHT, CRIMSON_DARK, width=4)
    radial_fill_ellipse(im, (194, 90, 232, 128), CRIMSON_LIGHT, CRIMSON_DARK, width=4)
    return im


def art_greed() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Heavy circular tiered pedestal base
    fill_poly_shaded(im, [(158, 418), (354, 418), (378, 456), (134, 456)], GOLD_LIGHT, GOLD_DARK, (150, 418), (360, 456), width=5)
    fill_poly_shaded(im, [(196, 392), (316, 392), (344, 420), (168, 420)], GOLD_MID, GOLD_DARK, (196, 392), (344, 420), width=5)
    # Central turned brass pillar & finial
    fill_poly_shaded(im, [(244, 126), (268, 126), (276, 396), (236, 396)], GOLD_LIGHT, GOLD_DARK, (236, 126), (276, 396), width=5)
    radial_fill_ellipse(im, (232, 86, 280, 134), GOLD_LIGHT, GOLD_DARK, width=5)
    d = ImageDraw.Draw(im)
    # Tilted crossbeam slightly weighted by left pan of gold coins
    d.polygon([(82, 156), (256, 122), (430, 120), (430, 138), (256, 142), (82, 174)], fill=GOLD_MID, outline=INK, width=5)
    # Suspension chains left & right
    for dx in (-58, 0, 58):
        d.line([(106, 166), (106 + dx, 314)], fill=INK, width=4)
        d.line([(406, 130), (406 + dx, 286)], fill=INK, width=4)
    # Left pan heaped with stamped florins
    for cx, cy in [(74, 294), (104, 296), (134, 294), (88, 276), (120, 278), (104, 260)]:
        radial_fill_ellipse(im, (cx - 18, cy - 18, cx + 18, cy + 18), (255, 232, 112, 255), GOLD_DARK, width=3)
    fill_poly_shaded(im, [(38, 312), (174, 312), (150, 344), (62, 344)], GOLD_LIGHT, GOLD_DARK, (38, 312), (174, 344), width=5)
    # Right pan with faceted crimson ruby jewel counterweight
    fill_poly_shaded(im, [(376, 252), (406, 224), (436, 252), (424, 282), (388, 282)], CRIMSON_LIGHT, CRIMSON_DARK, (376, 224), (436, 282), width=4)
    fill_poly_shaded(im, [(338, 284), (474, 284), (450, 316), (362, 316)], GOLD_LIGHT, GOLD_DARK, (338, 284), (474, 316), width=5)
    return im


def art_alembic() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Iron tripod trivet stand + glowing hearth embers below
    d.line([(134, 444), (190, 350), (308, 350), (356, 444)], fill=INK, width=10)
    d.ellipse((178, 412, 314, 456), fill=(192, 56, 24, 255), outline=INK, width=4)
    # Rising stylized flame tongues under cauldron belly
    for fx, fh in [(206, 56), (242, 74), (278, 52)]:
        fill_poly_shaded(im, [(fx - 18, 424), (fx, 424 - fh), (fx + 18, 424)], (255, 224, 86, 255), CRIMSON_LIGHT, (fx, 424 - fh), (fx, 424), width=3)
    # Large bulbous copper & blown glass alembic flask
    radial_fill_ellipse(im, (132, 184, 346, 398), (244, 152, 86, 255), COPPER_DARK, width=6, light_off=(-0.35, -0.35))
    # Glowing bubbling molten amber porthole in belly
    radial_fill_ellipse(im, (164, 232, 314, 372), (255, 226, 98, 255), (192, 64, 18, 255), width=4)
    d = ImageDraw.Draw(im)
    # Domed helm cap & long curved swan-neck condenser spout dripping emerald/gold distillate
    radial_fill_ellipse(im, (176, 94, 304, 212), COPPER_LIGHT, COPPER_DARK, width=5)
    d.rounded_rectangle((174, 180, 304, 206), radius=6, fill=GOLD_MID, outline=INK, width=4)
    spout = [(284, 130), (364, 152), (420, 224), (442, 318), (416, 326), (392, 238), (346, 178), (276, 162)]
    fill_poly_shaded(im, spout, COPPER_LIGHT, COPPER_DARK, (280, 130), (440, 320), width=5)
    # Small collecting receiver phial on right
    radial_fill_ellipse(im, (382, 354, 464, 444), (255, 222, 92, 255), (186, 86, 18, 255), width=5)
    d = ImageDraw.Draw(im)
    draw_star_spark(d, 238, 294, 18, (255, 250, 210, 255))
    return im


def art_prism_orb() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Brass interlocking celestial astrolabe rings with cardinal star points
    d.ellipse((54, 54, 458, 458), outline=INK, width=16)
    d.ellipse((54, 54, 458, 458), outline=GOLD_MID, width=9)
    for deg in range(0, 360, 30):
        ang = math.radians(deg)
        r0, r1 = 188, 214
        d.line([(256 + math.cos(ang) * r0, 256 + math.sin(ang) * r0),
                (256 + math.cos(ang) * r1, 256 + math.sin(ang) * r1)], fill=INK, width=4)
    # Tilted orbital ellipses
    for rot_w, rot_h in [(400, 170), (170, 400)]:
        x0, y0 = 256 - rot_w // 2, 256 - rot_h // 2
        d.ellipse((x0, y0, x0 + rot_w, y0 + rot_h), outline=INK, width=10)
        d.ellipse((x0, y0, x0 + rot_w, y0 + rot_h), outline=GOLD_LIGHT, width=4)
    # Faceted octagonal astral prism crystal in center
    pts_outer = [(256, 108), (356, 198), (336, 326), (256, 404), (176, 326), (156, 198)]
    fill_poly_shaded(im, pts_outer, (226, 172, 255, 255), (84, 52, 148, 255), (156, 110), (356, 404), width=6)
    # Bright cyan/rose internal crystal facets
    fill_poly_shaded(im, [(256, 108), (256, 256), (156, 198)], (242, 248, 255, 240), (144, 202, 252, 240), (160, 110), (256, 256), width=4)
    fill_poly_shaded(im, [(256, 108), (356, 198), (256, 256)], (255, 196, 224, 240), (168, 92, 186, 240), (256, 108), (356, 256), width=4)
    fill_poly_shaded(im, [(256, 256), (336, 326), (256, 404)], (118, 72, 168, 240), (62, 34, 102, 240), (256, 256), (336, 404), width=4)
    d = ImageDraw.Draw(im)
    draw_star_spark(d, 256, 252, 36, (255, 252, 232, 255))
    return im


def art_hex_doll() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Stitched linen & burlap voodoo effigy doll silhouette
    burlap_l, burlap_d = (214, 186, 142, 255), (126, 98, 68, 255)
    # Outstretched arms & legs + plump torso
    body = [
        (194, 200), (76, 184), (66, 236), (174, 254), (170, 338),
        (126, 434), (178, 458), (234, 372), (278, 372), (334, 458),
        (386, 434), (342, 338), (338, 254), (446, 236), (436, 184), (318, 200)
    ]
    fill_poly_shaded(im, body, burlap_l, burlap_d, (90, 180), (400, 440), width=6)
    # Slightly lop-sided round stitched head
    radial_fill_ellipse(im, (168, 56, 344, 224), (228, 200, 156, 255), burlap_d, width=6)
    d = ImageDraw.Draw(im)
    # Button X eyes & stitched crooked mouth + twine waist wraps
    for ex, ey in [(216, 134), (294, 130)]:
        d.ellipse((ex - 20, ey - 20, ex + 20, ey + 20), fill=PARCH_LIGHT, outline=INK, width=4)
        d.line([(ex - 10, ey - 10), (ex + 10, ey + 10)], fill=INK, width=5)
        d.line([(ex + 10, ey - 10), (ex - 10, ey + 10)], fill=INK, width=5)
    d.arc((218, 162, 294, 198), 10, 170, fill=INK, width=5)
    for sx in range(226, 290, 16):
        d.line([(sx, 174), (sx, 194)], fill=INK, width=3)
    # Crimson cloth heart patch stitched onto chest
    fill_poly_shaded(im, [(256, 266), (230, 240), (206, 260), (226, 304), (256, 326), (286, 304), (306, 260), (282, 240)],
                     CRIMSON_LIGHT, CRIMSON_DARK, (206, 240), (306, 326), width=4)
    d = ImageDraw.Draw(im)
    # Hemp twine coils around waist & wrist
    for ry in (322, 336, 350):
        d.line([(168, ry), (344, ry + 6)], fill=(104, 72, 42, 255), width=6)
    # Two brass-headed curse pins piercing doll & glowing purple-gold needle heads
    for (x0, y0, x1, y1, head_col) in [(162, 108, 214, 164, (192, 86, 232, 255)), (394, 186, 274, 274, GOLD_LIGHT), (364, 314, 266, 292, CRIMSON_LIGHT)]:
        d.line([(x0, y0), (x1, y1)], fill=STEEL_LIGHT, width=6)
        d.line([(x0, y0), (x1, y1)], fill=INK, width=2)
        radial_fill_ellipse(im, (x0 - 14, y0 - 14, x0 + 14, y0 + 14), head_col, INK, width=4)
        d = ImageDraw.Draw(im)
    return im


def art_iron_boot() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Armored medieval knight's fluted steel greave & articulated sabaton boot
    shin_pts = [(158, 72), (288, 60), (302, 294), (424, 344), (446, 398), (416, 434), (132, 434), (126, 376), (144, 286)]
    fill_poly_shaded(im, shin_pts, STEEL_LIGHT, STEEL_DARK, (130, 70), (430, 430), width=6)
    d = ImageDraw.Draw(im)
    # Knee poleyn boss & articulated lobster plates across instep
    radial_fill_ellipse(im, (144, 48, 304, 148), (234, 244, 254, 255), STEEL_DARK, width=6)
    d = ImageDraw.Draw(im)
    for ay in (268, 298, 326):
        d.arc((134, ay - 22, 324, ay + 28), 190, 355, fill=INK, width=5)
        d.arc((134, ay - 18, 324, ay + 32), 190, 355, fill=STEEL_LIGHT, width=3)
    # Diagonal leather buckle straps & brass buckles
    for sy in (176, 234):
        d.polygon([(142, sy), (300, sy + 18), (300, sy + 40), (142, sy + 22)], fill=(122, 74, 40, 255), outline=INK, width=4)
        d.rectangle((226, sy + 4, 256, sy + 36), outline=GOLD_LIGHT, width=5)
    # Heavy brass toe cap & heel spur
    fill_poly_shaded(im, [(358, 336), (434, 358), (448, 408), (418, 434), (350, 434)], GOLD_LIGHT, GOLD_DARK, (358, 336), (448, 434), width=5)
    d = ImageDraw.Draw(im)
    for rx, ry in [(164, 96), (278, 92), (154, 392), (242, 392), (322, 392)]:
        d.ellipse((rx - 6, ry - 6, rx + 6, ry + 6), fill=GOLD_LIGHT, outline=INK, width=2)
    return im


def art_overcharge() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Branching crackling violet-azure lightning aura around High-Tatra spire
    arcs = [
        [(256, 70), (168, 118), (194, 148), (94, 224), (152, 236), (110, 304)],
        [(256, 70), (344, 118), (318, 148), (418, 224), (360, 236), (402, 304)],
    ]
    for a in arcs:
        d.line(a, fill=INK, width=12)
        d.line(a, fill=AZURE_LIGHT, width=6)
    # Alpine granite pedestal base & fluted forged-iron lightning rod spire
    fill_poly_shaded(im, [(134, 406), (206, 358), (306, 358), (378, 406), (394, 460), (118, 460)],
                     STEEL_MID, (44, 48, 58, 255), (140, 360), (380, 460), width=6)
    fill_poly_shaded(im, [(232, 92), (280, 92), (298, 370), (214, 370)], COPPER_LIGHT, COPPER_DARK, (214, 92), (298, 370), width=5)
    d = ImageDraw.Draw(im)
    # Twin copper capacitor insulator rings + trident crown
    for ry, rw in [(152, 48), (212, 62), (274, 74)]:
        d.rounded_rectangle((256 - rw, ry, 256 + rw, ry + 18), radius=8, fill=GOLD_MID, outline=INK, width=4)
    # Glowing plasma orb at apex
    radial_fill_ellipse(im, (216, 38, 296, 118), (234, 250, 255, 255), AZURE_DARK, width=5)
    d = ImageDraw.Draw(im)
    draw_star_spark(d, 256, 78, 28, (255, 255, 255, 255))
    return im


def art_woodcutter() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Carpathian ash-wood haft running diagonally from bottom-left to top-right
    haft = [(92, 444), (118, 464), (392, 108), (366, 88)]
    fill_poly_shaded(im, haft, (176, 118, 66, 255), (86, 48, 24, 255), (92, 444), (392, 108), width=6)
    d = ImageDraw.Draw(im)
    # Leather grip wrap on lower shaft
    for i in range(6):
        px = 114 + i * 18
        py = 420 - i * 24
        d.line([(px - 14, py - 8), (px + 14, py + 12)], fill=CRIMSON_DARK, width=8)
    # Broad bearded steel cleaver axe head with etched fuller groove & bevelled cutting edge
    blade = [(266, 140), (350, 90), (414, 152), (434, 260), (362, 344), (274, 272), (288, 200)]
    fill_poly_shaded(im, blade, STEEL_MID, STEEL_DARK, (266, 140), (362, 344), width=6)
    # Gleaming honed steel edge arc
    edge = [(392, 130), (424, 198), (432, 260), (362, 344), (344, 314), (398, 246), (392, 184)]
    fill_poly_shaded(im, edge, (242, 248, 255, 255), STEEL_MID, (350, 140), (432, 344), width=4)
    # Brass collar ferrule & Carpathian forest oak leaf spray around socket
    d = ImageDraw.Draw(im)
    d.polygon([(316, 114), (366, 76), (398, 102), (348, 142)], fill=GOLD_MID, outline=INK, width=5)
    fill_poly_shaded(im, [(200, 126), (264, 96), (296, 144), (236, 178)], EMERALD_LIGHT, EMERALD_DARK, (200, 96), (296, 178), width=4)
    return im


def art_forgemaster() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Heavy horned blacksmith's iron anvil
    anvil = [
        (68, 224), (176, 210), (394, 210), (416, 254), (350, 272),
        (344, 344), (402, 418), (132, 418), (186, 344), (186, 276), (112, 258)
    ]
    fill_poly_shaded(im, anvil, STEEL_MID, (38, 42, 48, 255), (120, 210), (360, 418), width=6)
    d = ImageDraw.Draw(im)
    # Highlighted steel striking face + glowing carved tally runes (I II III IV V)
    d.polygon([(176, 206), (394, 206), (402, 226), (176, 226)], fill=STEEL_LIGHT, outline=INK, width=4)
    for tx in range(214, 306, 16):
        d.line([(tx, 294), (tx, 336)], fill=(255, 198, 72, 255), width=4)
    d.line([(204, 330), (304, 298)], fill=(255, 172, 54, 255), width=4)
    # Crossed blacksmith peen hammer descending from upper right
    fill_poly_shaded(im, [(212, 180), (418, 66), (434, 94), (228, 206)], (164, 108, 60, 255), (78, 42, 22, 255), (212, 66), (434, 206), width=5)
    fill_poly_shaded(im, [(186, 128), (242, 98), (290, 172), (228, 204)], STEEL_LIGHT, STEEL_DARK, (186, 98), (290, 204), width=5)
    d = ImageDraw.Draw(im)
    # Glowing hot sparks exploding from face
    for sx, sy, sr in [(164, 186, 14), (298, 172, 16), (354, 190, 12), (128, 212, 10)]:
        draw_star_spark(d, sx, sy, sr, (255, 224, 98, 255))
    return im


def art_green_canopy() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Braided living oak bough circlet ring
    d.ellipse((98, 102, 414, 418), outline=INK, width=28)
    d.ellipse((98, 102, 414, 418), outline=(126, 86, 46, 255), width=18)
    # Arrange 8 large richly veined oak/linden leaves around canopy crest + golden acorns
    for idx in range(8):
        ang = math.radians(idx * 45.0 - 90.0)
        lx = 256 + math.cos(ang) * 144
        ly = 256 + math.sin(ang) * 144
        tx = 256 + math.cos(ang + 0.38) * 196
        ty = 256 + math.sin(ang + 0.38) * 196
        nx, ny = -math.sin(ang + 0.2), math.cos(ang + 0.2)
        leaf_pts = [
            (lx - math.cos(ang) * 26, ly - math.sin(ang) * 26),
            (lx + nx * 38, ly + ny * 38),
            (tx, ty),
            (lx - nx * 38, ly - ny * 38),
        ]
        fill_poly_shaded(im, leaf_pts, EMERALD_LIGHT, EMERALD_DARK, (lx, ly), (tx, ty), width=4)
        d = ImageDraw.Draw(im)
        d.line([(lx, ly), (tx, ty)], fill=GOLD_LIGHT, width=2)
    # Pair of golden acorns at bottom clasp + glowing forest emblem center
    for ax in (218, 294):
        radial_fill_ellipse(im, (ax - 22, 384, ax + 22, 434), COPPER_LIGHT, COPPER_DARK, width=4)
        d = ImageDraw.Draw(im)
        d.arc((ax - 24, 374, ax + 24, 410), 180, 360, fill=GOLD_DARK, width=8)
    draw_star_spark(d, 256, 256, 26, (214, 255, 174, 255))
    return im


def art_prsi_purist() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Brass curved tankard handle on right
    d.arc((278, 172, 430, 372), 270, 90, fill=INK, width=32)
    d.arc((278, 172, 430, 372), 270, 90, fill=GOLD_MID, width=20)
    # Tapered oak-staved tavern mug body
    mug_pts = [(126, 152), (324, 152), (344, 434), (106, 434)]
    fill_poly_shaded(im, mug_pts, (178, 114, 62, 255), (94, 52, 24, 255), (120, 152), (344, 434), width=6)
    d = ImageDraw.Draw(im)
    # Vertical oak stave plank lines
    for st in (-62, -22, 22, 62):
        d.line([(225 + st * 0.85, 154), (225 + st * 1.05, 432)], fill=INK_SOFT, width=3)
    # Twin riveted brass barrel hoops
    for hy in (198, 378):
        d.rounded_rectangle((106, hy, 344, hy + 24), radius=6, fill=GOLD_MID, outline=INK, width=5)
        for rx in range(134, 330, 44):
            d.ellipse((rx - 5, hy + 7, rx + 5, hy + 17), fill=GOLD_LIGHT, outline=INK, width=2)
    # Overflowing frothy cream-white ale foam crown + wheat stalks
    for fx, fy, fr in [(146, 146, 36), (194, 128, 42), (248, 124, 44), (298, 144, 34), (166, 172, 26), (268, 186, 22)]:
        radial_fill_ellipse(im, (fx - fr, fy - fr, fx + fr, fy + fr), (255, 250, 232, 255), (214, 198, 158, 255), width=4)
    # Shield house crest on tankard belly
    fill_poly_shaded(im, [(190, 244), (260, 244), (256, 308), (225, 342), (194, 308)], GOLD_LIGHT, GOLD_DARK, (190, 244), (260, 342), width=4)
    return im


def art_seven_grimoire() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Heavy leather-bound angled tome with gilded page fore-edges
    cover_b = [(94, 108), (370, 74), (424, 412), (148, 448)]
    fill_poly_shaded(im, cover_b, (108, 38, 34, 255), (48, 18, 18, 255), (94, 108), (424, 412), width=6)
    pages = [(126, 408), (398, 374), (424, 412), (148, 448)]
    fill_poly_shaded(im, pages, PARCH_LIGHT, PARCH_DARK, (126, 374), (424, 448), width=4)
    cover_f = [(86, 88), (362, 54), (402, 384), (126, 418)]
    fill_poly_shaded(im, cover_f, (132, 42, 40, 255), (62, 20, 22, 255), (86, 88), (402, 384), width=6)
    d = ImageDraw.Draw(im)
    # Ornate brass corner clasps & belt strap lock
    for (cx, cy) in [(94, 96), (354, 62), (394, 376), (134, 410)]:
        d.ellipse((cx - 22, cy - 22, cx + 22, cy + 22), fill=GOLD_MID, outline=INK, width=4)
    d.polygon([(352, 198), (426, 188), (434, 254), (360, 264)], fill=GOLD_LIGHT, outline=INK, width=5)
    # Glowing mystic gold/crimson VII circle inscribed on front cover
    d.ellipse((158, 152, 336, 330), outline=GOLD_LIGHT, width=6)
    d.ellipse((174, 168, 320, 314), outline=GOLD_DARK, width=3)
    # Big hand-drawn bold "7" & "VII" emblem in glowing gold
    d.polygon([(206, 192), (288, 192), (288, 214), (242, 300), (218, 294), (260, 214), (206, 214)], fill=GOLD_LIGHT, outline=INK, width=4)
    draw_star_spark(d, 246, 240, 14, (255, 250, 210, 255))
    return im


def art_merchant_ledger() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Unrolled parchment ledger scroll curled top and bottom
    body = [(118, 108), (376, 82), (392, 390), (134, 416)]
    fill_poly_shaded(im, body, PARCH_LIGHT, (206, 184, 144, 255), (118, 82), (392, 416), width=6)
    # Top & bottom parchment curls + wooden scroll rods
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((84, 78, 396, 118), radius=18, fill=PARCH_DARK, outline=INK, width=5)
    d.rounded_rectangle((112, 384, 424, 424), radius=18, fill=PARCH_DARK, outline=INK, width=5)
    # Etched calligraphy ledger lines & numeric tally column
    for i, ry in enumerate(range(150, 336, 28)):
        w_line = 156 if i % 2 == 0 else 120
        d.line([(152, ry), (152 + w_line, ry - 12)], fill=INK_SOFT, width=4)
        d.ellipse((326, ry - 20, 344, ry - 4), fill=GOLD_MID, outline=INK, width=2)
    # Emerald wax merchant seal + crimson hanging ribbon at bottom
    d.polygon([(284, 346), (272, 456), (298, 434), (324, 456), (316, 346)], fill=CRIMSON_LIGHT, outline=INK, width=4)
    radial_fill_ellipse(im, (260, 304, 342, 386), CRIMSON_LIGHT, CRIMSON_DARK, width=5)
    # Gilded goose quill angled diagonally across scroll
    d = ImageDraw.Draw(im)
    d.line([(298, 258), (446, 54)], fill=INK, width=10)
    d.line([(298, 258), (446, 54)], fill=GOLD_LIGHT, width=4)
    fill_poly_shaded(im, [(358, 176), (402, 74), (456, 46), (434, 118), (382, 184)], (248, 246, 232, 255), GOLD_MID, (358, 176), (456, 46), width=4)
    return im


def art_final_toll() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Executioner's broad double-edged sword diagonal bottom-left -> top-right + scarlet oath ribbon wrapped around blade
    blade = [(164, 344), (394, 62), (436, 62), (436, 104), (206, 384)]
    fill_poly_shaded(im, blade, STEEL_LIGHT, STEEL_DARK, (164, 344), (436, 62), width=6)
    d = ImageDraw.Draw(im)
    # Fuller groove along center spine
    d.line([(194, 354), (406, 94)], fill=INK, width=6)
    # Flowing scarlet oath parchment banner wrapped across blade
    rib1 = [(194, 210), (344, 148), (366, 188), (218, 252)]
    rib2 = [(236, 290), (414, 236), (430, 278), (254, 330)]
    fill_poly_shaded(im, rib1, CRIMSON_LIGHT, CRIMSON_DARK, (194, 148), (366, 252), width=4)
    fill_poly_shaded(im, rib2, CRIMSON_LIGHT, CRIMSON_DARK, (236, 236), (430, 330), width=4)
    # Engraved brass crossguard + leather grip + skull/sunburst pommel
    guard = [(126, 280), (144, 260), (264, 380), (244, 400)]
    fill_poly_shaded(im, guard, GOLD_LIGHT, GOLD_DARK, (126, 260), (264, 400), width=5)
    d = ImageDraw.Draw(im)
    d.line([(96, 416), (178, 334)], fill=INK, width=22)
    d.line([(96, 416), (178, 334)], fill=(116, 42, 34, 255), width=14)
    radial_fill_ellipse(im, (54, 400, 118, 464), GOLD_LIGHT, GOLD_DARK, width=5)
    return im


def art_court_sovereign() -> Image.Image:
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    # Iron-bound velvet royal chest brimming with stamped florins & jewels
    # Open lid tilted behind chest
    fill_poly_shaded(im, [(92, 168), (132, 92), (380, 92), (420, 168)], (134, 48, 38, 255), (68, 24, 22, 255), (92, 92), (420, 168), width=6)
    d = ImageDraw.Draw(im)
    for lx in (176, 336):
        d.line([(lx, 94), (lx, 168)], fill=GOLD_MID, width=10)
    # Overflowing mound of gold florins, sapphire & ruby gems
    coins = [(152, 206), (192, 190), (236, 178), (282, 182), (328, 194), (362, 210),
             (176, 222), (222, 212), (268, 214), (316, 220), (254, 158)]
    for cx, cy in coins:
        radial_fill_ellipse(im, (cx - 24, cy - 24, cx + 24, cy + 24), (255, 234, 118, 255), GOLD_DARK, width=4)
    # Gemstones nestled in coin hoard
    fill_poly_shaded(im, [(200, 162), (218, 144), (236, 162), (218, 182)], CRIMSON_LIGHT, CRIMSON_DARK, (200, 144), (236, 182), width=3)
    fill_poly_shaded(im, [(292, 168), (310, 150), (328, 168), (310, 188)], AZURE_LIGHT, AZURE_DARK, (292, 150), (328, 188), width=3)
    # Heavy chest lower box with brass ironwork bands & keyhole lockplate
    box = [(74, 226), (438, 226), (414, 434), (98, 434)]
    fill_poly_shaded(im, box, (152, 86, 48, 255), (76, 38, 20, 255), (74, 226), (438, 434), width=6)
    d = ImageDraw.Draw(im)
    for bx in (154, 344):
        d.polygon([(bx - 12, 226), (bx + 12, 226), (bx + 6, 434), (bx - 18, 434)], fill=GOLD_MID, outline=INK, width=4)
    d.rounded_rectangle((70, 216, 442, 246), radius=8, fill=GOLD_LIGHT, outline=INK, width=5)
    # Central escutcheon lockplate
    fill_poly_shaded(im, [(224, 224), (288, 224), (282, 294), (256, 314), (230, 294)], GOLD_LIGHT, GOLD_DARK, (224, 224), (288, 314), width=4)
    d = ImageDraw.Draw(im)
    d.ellipse((248, 248, 264, 264), fill=INK)
    d.polygon([(254, 260), (258, 260), (263, 284), (249, 284)], fill=INK)
    return im


def build_engraved_parchment_card_base(w: int = 720, h: int = 1080, seed: int = 108) -> Image.Image:
    """Builds antique stained parchment background matching SPEC_VAMPIRE.png with dark hairline frame."""
    rng = np.random.default_rng(seed)
    # Multi-scale smooth fbm stain noise
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    low = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h // 8, w // 8)).astype(np.float32), sigma=3.5)
    low = np.array(Image.fromarray(((low - low.min()) / max(1e-5, (low.max() - low.min())) * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0
    mid = ndi.gaussian_filter(rng.normal(0.0, 1.0, (h, w)).astype(np.float32), sigma=4.2)
    mid = (mid - mid.min()) / max(1e-5, (mid.max() - mid.min()))
    fine = rng.normal(0.0, 0.018, (h, w)).astype(np.float32)

    # Radial aging vignette darker along paper edges
    dist = np.sqrt(((xx - w * 0.5) / (w * 0.5)) ** 2 + ((yy - h * 0.5) / (h * 0.5)) ** 2)
    vign = np.clip((dist - 0.35) * 0.24, 0.0, 0.22)
    stain = 0.72 * low + 0.28 * mid - 0.5

    r = np.clip(241.0 - vign * 75.0 + stain * 22.0 + fine * 255.0, 175, 252)
    g = np.clip(230.0 - vign * 95.0 + stain * 24.0 + fine * 255.0, 150, 244)
    b = np.clip(204.0 - vign * 125.0 + stain * 28.0 + fine * 255.0, 118, 224)

    arr = np.dstack([r, g, b, np.full((h, w), 255.0)]).astype(np.uint8)
    card = Image.fromarray(arr, "RGBA")
    d = ImageDraw.Draw(card)
    # Fine antique ink foxing specks
    for _ in range(95):
        fx, fy = int(rng.integers(24, w - 24)), int(rng.integers(24, h - 24))
        fr = int(rng.integers(1, 5))
        d.ellipse((fx - fr, fy - fr, fx + fr, fy + fr), fill=(158, 126, 86, int(rng.integers(22, 62))))
    # Clean aged inner border frame matching SPEC_VAMPIRE / SPEC_CROWN / SPEC_PLAGUE
    m = 36
    d.rectangle((m, m, w - m, h - m), outline=(42, 30, 22, 210), width=3)
    # Corner hairline ticks
    for cx, cy, sx, sy in [(m, m, 1, 1), (w - m, m, -1, 1), (m, h - m, 1, -1), (w - m, h - m, -1, -1)]:
        d.line([(cx - sx * 14, cy + sy * 14), (cx + sx * 18, cy + sy * 14)], fill=(42, 30, 22, 160), width=2)
        d.line([(cx + sx * 14, cy - sy * 14), (cx + sx * 14, cy + sy * 18)], fill=(42, 30, 22, 160), width=2)
    return card


def upgrade_spec_cards() -> None:
    # 1. Process AI-generated SPEC_CROWN & SPEC_PLAGUE -> 360x540 RGBA
    for out_name, src_name in [
        ("SPEC_CROWN.png", "spec_crown_1795039043589.jpg"),
        ("SPEC_PLAGUE.png", "spec_plague_1795039052086.jpg"),
    ]:
        src = ART_DIR / src_name
        im = Image.open(src).convert("RGBA").resize((360, 540), Image.Resampling.LANCZOS)
        im = ImageEnhance.Sharpness(im).enhance(1.08)
        im.save(CARD_DIR / out_name, "PNG")
        print(f"Upgraded {out_name} from AI art -> 360x540 PNG")

    # 2. Synthesize rich copperplate woodcut SPEC_PRISM.png at 720x1080 -> 360x540 RGBA
    w, h = 720, 1080
    card = build_engraved_parchment_card_base(w, h, seed=314)
    art_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(art_layer)
    cx, cy = w // 2, h // 2

    # 12 engraved watercolor-washed prism refraction rays radiating outward (4 Czech suits palette!)
    ray_cols = [
        (206, 52, 58, 175),   # Crimson Srdce
        (224, 168, 52, 175),  # Gold Koule
        (68, 152, 92, 175),   # Emerald Listi
        (64, 128, 206, 175),  # Astral Sapphire
    ]
    for i in range(12):
        ang = math.radians(i * 30.0 - 90.0)
        da = 0.088
        r_in, r_out = 96.0, (292.0 if i % 2 == 0 else 258.0)
        pts = [
            (cx + math.cos(ang - da * 0.5) * r_in, cy + math.sin(ang - da * 0.5) * r_in),
            (cx + math.cos(ang - da) * r_out, cy + math.sin(ang - da) * r_out),
            (cx + math.cos(ang + da) * r_out, cy + math.sin(ang + da) * r_out),
            (cx + math.cos(ang + da * 0.5) * r_in, cy + math.sin(ang + da * 0.5) * r_in),
        ]
        col = ray_cols[i % 4]
        d.polygon(pts, fill=col, outline=INK, width=3)
        # Parallel engraving line along ray center
        d.line([(cx + math.cos(ang) * r_in, cy + math.sin(ang) * r_in),
                (cx + math.cos(ang) * (r_out - 8), cy + math.sin(ang) * (r_out - 8))], fill=INK_SOFT, width=2)

    # Double brass armillary zodiac astrolabe circles + degree tick notches + riveted trunnions
    for rad in (228, 198, 164):
        d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), outline=INK, width=10 if rad == 228 else 7)
        d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), outline=GOLD_MID if rad != 164 else GOLD_LIGHT, width=5 if rad == 228 else 3)
    for deg in range(0, 360, 10):
        ang = math.radians(deg)
        r0 = 198 if deg % 30 != 0 else 164
        d.line([(cx + math.cos(ang) * r0, cy + math.sin(ang) * r0),
                (cx + math.cos(ang) * 228, cy + math.sin(ang) * 228)], fill=INK, width=3 if deg % 30 == 0 else 2)
    # Tilted brass celestial rings crossing behind prism
    d.ellipse((cx - 248, cy - 92, cx + 248, cy + 92), outline=INK, width=11)
    d.ellipse((cx - 248, cy - 92, cx + 248, cy + 92), outline=GOLD_MID, width=5)
    d.ellipse((cx - 92, cy - 248, cx + 92, cy + 248), outline=INK, width=11)
    d.ellipse((cx - 92, cy - 248, cx + 92, cy + 248), outline=GOLD_MID, width=5)

    # Top astrolabe crown ring & bottom pendant plumb finial
    d.ellipse((cx - 28, cy - 282, cx + 28, cy - 226), outline=INK, width=9)
    d.ellipse((cx - 28, cy - 282, cx + 28, cy - 226), outline=GOLD_MID, width=4)
    fill_poly_shaded(art_layer, [(cx, cy + 296), (cx - 22, cy + 240), (cx, cy + 224), (cx + 22, cy + 240)],
                     GOLD_LIGHT, GOLD_DARK, (cx - 22, cy + 224), (cx + 22, cy + 296), width=4)

    # Monumental multi-faceted Crystal Prism Core
    p_top = (cx, cy - 178)
    p_bot = (cx, cy + 178)
    p_tl, p_tr = (cx - 108, cy - 82), (cx + 108, cy - 82)
    p_bl, p_br = (cx - 108, cy + 82), (cx + 108, cy + 82)
    p_mid_l, p_mid_r = (cx - 48, cy), (cx + 48, cy)
    p_ct, p_cb = (cx, cy - 72), (cx, cy + 72)

    facets = [
        ([p_top, p_ct, p_mid_l, p_tl], (242, 250, 255, 252), (174, 214, 248, 252)),
        ([p_top, p_tr, p_mid_r, p_ct], (255, 224, 234, 252), (198, 128, 178, 252)),
        ([p_tl, p_mid_l, p_bl], (148, 218, 246, 252), (68, 134, 186, 252)),
        ([p_tr, p_br, p_mid_r], (218, 114, 138, 252), (132, 46, 76, 252)),
        ([p_mid_l, p_ct, p_cb, p_bl], (148, 226, 176, 252), (64, 142, 98, 252)),
        ([p_ct, p_mid_r, p_br, p_cb], (248, 206, 108, 252), (176, 112, 42, 252)),
        ([p_bl, p_cb, p_bot], (82, 148, 172, 252), (42, 74, 118, 252)),
        ([p_cb, p_br, p_bot], (162, 92, 168, 252), (82, 36, 106, 252)),
        ([p_ct, p_mid_r, p_cb, p_mid_l], (255, 255, 255, 255), (224, 238, 255, 255)),
    ]
    for poly, ca, cb in facets:
        fill_poly_shaded(art_layer, poly, ca, cb, (cx - 108, cy - 178), (cx + 108, cy + 178), outline=INK, width=5)

    art_layer = copperplate_shade_and_ink(art_layer, seed=99, add_outer_ink=False)
    d = ImageDraw.Draw(art_layer)
    draw_star_spark(d, cx, cy, 34, (255, 255, 245, 255))
    # Subtle stars top/bottom in sky around prism
    for sx, sy, sr in [(164, 198, 12), (556, 212, 12), (154, 858, 11), (566, 846, 13), (cx, 188, 14), (cx, 886, 14)]:
        draw_star_spark(d, sx, sy, sr, (250, 232, 174, 230))

    card = Image.alpha_composite(card, art_layer)
    out = card.resize((360, 540), Image.Resampling.LANCZOS)
    out = ImageEnhance.Sharpness(out).enhance(1.10)
    out.save(CARD_DIR / "SPEC_PRISM.png", "PNG")
    print("Synthesized copperplate SPEC_PRISM.png -> 360x540 PNG")


def main():
    RELIC_DIR.mkdir(parents=True, exist_ok=True)
    # 1. Convert the 6 AI-generated relics to 256x256 RGBA transparent PNGs
    ai_relics = {
        "REL_CHAMOIS": "rel_chamois_1795039035436.jpg",
        "REL_FUJARA": "rel_fujara_1795039044388.jpg",
        "REL_ROYAL": "rel_royal_1795039037073.jpg",
        "REL_CHRONO_P": "rel_chrono_p_1795039045996.jpg",
        "REL_RED_SEAL": "rel_red_seal_1795039042089.jpg",
        "REL_CRIMSON_CHOIR": "rel_crimson_choir_1795039050944.jpg",
    }
    for rel_id, fn in ai_relics.items():
        extract_ai_relic_transparent(ART_DIR / fn, RELIC_DIR / f"{rel_id}.png", 256)
        print(f"Processed AI relic {rel_id}.png")

    # 2. Synthesize the remaining 18 detailed copperplate-etched relics
    builders = {
        "REL_STORMCAP": (art_stormcap, 101),
        "REL_KNUCKLE": (art_knuckle, 102),
        "REL_PHOENIX_F": (art_phoenix_f, 103),
        "REL_FANG": (art_fang, 104),
        "REL_GREED": (art_greed, 105),
        "REL_ALEMBIC": (art_alembic, 106),
        "REL_PRISM_ORB": (art_prism_orb, 107),
        "REL_HEX_DOLL": (art_hex_doll, 108),
        "REL_IRON_BOOT": (art_iron_boot, 109),
        "REL_OVERCHARGE": (art_overcharge, 110),
        "REL_WOODCUTTER": (art_woodcutter, 111),
        "REL_FORGEMASTER": (art_forgemaster, 112),
        "REL_GREEN_CANOPY": (art_green_canopy, 113),
        "REL_PRSI_PURIST": (art_prsi_purist, 114),
        "REL_SEVEN_GRIMOIRE": (art_seven_grimoire, 115),
        "REL_MERCHANT_LEDGER": (art_merchant_ledger, 116),
        "REL_FINAL_TOLL": (art_final_toll, 117),
        "REL_COURT_SOVEREIGN": (art_court_sovereign, 118),
    }
    for rel_id, (fn, seed) in builders.items():
        raw_512 = fn()
        finalize_relic(raw_512, RELIC_DIR / f"{rel_id}.png", seed=seed, ink_px=3)
        print(f"Synthesized copperplate relic {rel_id}.png")

    # 3. Upgrade SPEC_CROWN, SPEC_PLAGUE, SPEC_PRISM
    upgrade_spec_cards()


if __name__ == "__main__":
    main()
