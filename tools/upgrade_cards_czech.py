"""Upgrade all 32 Czech Prsi cards to oversized rank typography + smooth curved authentic Srdce/Zaludy/Listi/Koule symbols
AND generate detailed 256x256 Shop Item illustrations while cleanly preserving court woodcut portraits.
"""
import os
import shutil
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

CARDS_DIR = r"D:\downpour-godot\assets\cards"
BACKUP_DIR = r"D:\downpour-godot\tools\backup_cards_orig"
SHOP_DIR = r"D:\downpour-godot\assets\shop"
FONT_DISPLAY = r"D:\downpour-godot\assets\fonts\LialoDisplay.ttf"
FONT_ANT = r"D:\downpour-godot\assets\fonts\ANTQUAB.TTF"

W, H = 540, 810
S = 2
CW, CH = W * S, H * S

SUIT_META = {
    "CERVEN": {
        "primary": (182, 24, 34),
        "hi": (244, 102, 108),
        "shade": (98, 12, 18),
        "trim": (162, 34, 38),
    },
    "ZALUD": {
        "primary": (148, 86, 32),
        "hi": (218, 158, 76),
        "shade": (82, 44, 16),
        "trim": (128, 88, 40),
    },
    "ZELEN": {
        "primary": (28, 134, 62),
        "hi": (106, 208, 124),
        "shade": (14, 72, 34),
        "trim": (34, 114, 58),
    },
    "GULA": {
        "primary": (222, 148, 24),
        "hi": (255, 228, 122),
        "shade": (128, 72, 10),
        "trim": (188, 130, 28),
    },
}


def ensure_backup():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    for fname in os.listdir(CARDS_DIR):
        if fname.lower().endswith(".png"):
            dst = os.path.join(BACKUP_DIR, fname)
            if not os.path.exists(dst):
                shutil.copy2(os.path.join(CARDS_DIR, fname), dst)


def make_parchment_canvas():
    # Solid opaque warm antique parchment (matched cleanly to original woodcut card background)
    img = Image.new("RGBA", (CW, CH), (238, 231, 212, 255))
    draw = ImageDraw.Draw(img)
    for i in range(44):
        t = i / 44.0
        col = (
            int(214 + t * 24),
            int(202 + t * 29),
            int(176 + t * 36),
            255,
        )
        m = i * 4
        draw.rounded_rectangle([m, m, CW - m, CH - m], radius=max(8, 52 - m // 2), outline=col, width=5)
    # Subtle opaque sepia foxing spots (alpha=255, never transparent pinholes!)
    rng_seed = 42
    for k in range(140):
        rng_seed = (rng_seed * 1103515245 + 12345) & 0x7FFFFFFF
        px = 28 + (rng_seed % (CW - 56))
        rng_seed = (rng_seed * 1103515245 + 12345) & 0x7FFFFFFF
        py = 28 + (rng_seed % (CH - 56))
        r = 2 + (k % 5)
        tint = 204 + (k % 18)
        draw.ellipse([px - r, py - r, px + r, py + r], fill=(tint, int(tint * 0.94), int(tint * 0.84), 255))
    return img


def draw_heart(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, meta: dict):
    ink = (26, 14, 12, 255)
    pts = []
    for i in range(56):
        t = (i / 56.0) * math.tau
        hx = 16.0 * (math.sin(t) ** 3)
        hy = -(13.0 * math.cos(t) - 5.0 * math.cos(2 * t) - 2.0 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + hx * (radius / 16.2), cy + hy * (radius / 16.2) - radius * 0.08))
    draw.polygon(pts, fill=meta["primary"] + (255,))
    draw.line(pts + [pts[0]], fill=ink, width=max(4, int(radius * 0.11)), joint="curve")
    inner_pts = [(cx + (px - cx) * 0.72, cy + (py - cy) * 0.72 + radius * 0.05) for (px, py) in pts]
    draw.line(inner_pts + [inner_pts[0]], fill=meta["shade"] + (210,), width=max(2, int(radius * 0.06)), joint="curve")
    draw.ellipse([cx - radius * 0.56, cy - radius * 0.52, cx - radius * 0.15, cy - radius * 0.12], fill=meta["hi"] + (235,))


def draw_acorn(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, meta: dict):
    ink = (26, 14, 12, 255)
    stroke = max(4, int(radius * 0.11))
    stem = [
        (cx - radius * 0.06, cy - radius * 0.50),
        (cx + radius * 0.04, cy - radius * 0.88),
        (cx + radius * 0.24, cy - radius * 0.94),
        (cx + radius * 0.14, cy - radius * 0.48),
    ]
    draw.polygon(stem, fill=(92, 62, 28, 255))
    draw.line(stem + [stem[0]], fill=ink, width=max(2, stroke // 2))
    nut_pts = []
    for i in range(40):
        t = (i / 40.0) * math.tau
        nx = math.sin(t) * radius * 0.58 * (1.0 - 0.15 * max(0.0, math.cos(t)))
        ny = math.cos(t) * radius * 0.74 + radius * 0.12
        nut_pts.append((cx + nx, cy + ny))
    draw.polygon(nut_pts, fill=(196, 124, 48, 255))
    draw.line(nut_pts + [nut_pts[0]], fill=ink, width=stroke, joint="curve")
    draw.polygon([(cx - radius * 0.10, cy + radius * 0.82), (cx + radius * 0.10, cy + radius * 0.82), (cx, cy + radius * 0.99)], fill=ink)
    draw.ellipse([cx - radius * 0.34, cy - radius * 0.02, cx - radius * 0.06, cy + radius * 0.48], fill=(244, 186, 102, 220))
    cap_pts = []
    for i in range(25):
        u = i / 24.0
        ang = math.pi * (1.0 - u)
        px = cx + math.cos(ang) * radius * 0.68
        py = cy - radius * 0.12 - math.sin(ang) * radius * 0.52
        cap_pts.append((px, py))
    cap_pts.append((cx + radius * 0.62, cy - radius * 0.03))
    cap_pts.append((cx, cy + radius * 0.02))
    cap_pts.append((cx - radius * 0.62, cy - radius * 0.03))
    draw.polygon(cap_pts, fill=(108, 66, 26, 255))
    draw.line(cap_pts + [cap_pts[0]], fill=ink, width=stroke, joint="curve")
    for hx_f in [-0.36, -0.14, 0.10, 0.34]:
        draw.line([(cx + radius * (hx_f - 0.12), cy - radius * 0.45), (cx + radius * (hx_f + 0.14), cy - radius * 0.06)], fill=(62, 34, 14, 210), width=max(2, stroke // 2))
        draw.line([(cx + radius * (hx_f + 0.14), cy - radius * 0.45), (cx + radius * (hx_f - 0.12), cy - radius * 0.06)], fill=(62, 34, 14, 210), width=max(2, stroke // 2))


def draw_leaf(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, meta: dict):
    """Smooth curved botanical Linden/Oak Leaf (Listi) with crisp veins."""
    ink = (18, 28, 18, 255)
    stroke = max(4, int(radius * 0.11))
    stem = [
        (cx - radius * 0.05, cy + radius * 0.50),
        (cx - radius * 0.02, cy + radius * 0.90),
        (cx + radius * 0.16, cy + radius * 0.94),
        (cx + radius * 0.07, cy + radius * 0.48),
    ]
    draw.polygon(stem, fill=(46, 86, 36, 255))
    draw.line(stem + [stem[0]], fill=ink, width=max(2, stroke // 2))

    # Smooth parametric wide heart-leaf silhouette with gentle organic wave
    pts = []
    for i in range(48):
        t = (i / 48.0) * math.tau
        # Peak at t=0 (-y), wide rounded base around t=pi/2..3pi/2
        # Vertical -0.92 at t=0, +0.56 bottom lobes, +0.46 cleft at base
        sin_t = math.sin(t)
        cos_t = math.cos(t)
        # Wave modulation mimics oak/linden leaf scallops gently
        lobe = 1.0 + 0.06 * math.cos(6.0 * t)
        rx = (sin_t * (0.76 - 0.18 * cos_t)) * radius * lobe
        if cos_t >= 0:
            ry = -(cos_t ** 0.78) * radius * 0.92
        else:
            ry = (abs(cos_t) ** 0.75) * radius * 0.62 - 0.12 * radius * (abs(cos_t) ** 2.2)
        pts.append((cx + rx, cy + ry))

    draw.polygon(pts, fill=meta["primary"] + (255,))
    # Right side deeper botanical green shadow
    right_pts = pts[:25]
    draw.polygon(right_pts, fill=(20, 102, 50, 255))
    draw.line(pts + [pts[0]], fill=ink, width=stroke, joint="curve")
    vein_col = (186, 238, 162, 235)
    vw = max(2, stroke // 2)
    draw.line([(cx, cy + radius * 0.50), (cx, cy - radius * 0.76)], fill=vein_col, width=max(3, vw + 1))
    for vy, vx in [(0.26, 0.48), (0.0, 0.56), (-0.28, 0.38)]:
        draw.line([(cx, cy + radius * (vy + 0.14)), (cx - radius * vx, cy + radius * vy)], fill=vein_col, width=vw)
        draw.line([(cx, cy + radius * (vy + 0.14)), (cx + radius * vx, cy + radius * vy)], fill=vein_col, width=vw)


def draw_koule(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, meta: dict):
    """Authentic round golden Czech Koule (Hawk-Bell / Sphere — NEVER diamond!)."""
    ink = (28, 18, 10, 255)
    stroke = max(4, int(radius * 0.11))
    r = radius * 0.82
    draw.ellipse([cx - r * 0.24, cy - r * 1.16, cx + r * 0.24, cy - r * 0.72], fill=meta["shade"] + (255,), outline=ink, width=max(2, stroke - 1))
    draw.ellipse([cx - r * 0.10, cy - r * 1.04, cx + r * 0.10, cy - r * 0.84], fill=(238, 231, 212, 255))
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=meta["primary"] + (255,), outline=ink, width=stroke)
    # Dark lower shading crescent + bright golden rim
    draw.chord([cx - r * 0.94, cy - r * 0.94, cx + r * 0.94, cy + r * 0.94], 15, 165, fill=(192, 118, 16, 255))
    draw.rectangle([cx - r * 0.96, cy - r * 0.11, cx + r * 0.96, cy + r * 0.11], fill=meta["shade"] + (255,))
    draw.line([(cx - r * 0.96, cy - r * 0.11), (cx + r * 0.96, cy - r * 0.11)], fill=ink, width=max(2, stroke // 2))
    draw.line([(cx - r * 0.96, cy + r * 0.11), (cx + r * 0.96, cy + r * 0.11)], fill=ink, width=max(2, stroke // 2))
    draw.line([(cx - r * 0.42, cy + r * 0.46), (cx + r * 0.42, cy + r * 0.46)], fill=ink, width=max(4, int(r * 0.16)))
    draw.ellipse([cx - r * 0.56, cy + r * 0.30, cx - r * 0.26, cy + r * 0.62], fill=ink)
    draw.ellipse([cx + r * 0.26, cy + r * 0.30, cx + r * 0.56, cy + r * 0.62], fill=ink)
    draw.ellipse([cx - r * 0.56, cy - r * 0.68, cx + r * 0.06, cy - r * 0.22], fill=meta["hi"] + (240,))


def draw_suit(draw: ImageDraw.ImageDraw, suit: str, cx: float, cy: float, radius: float):
    meta = SUIT_META[suit]
    if suit == "CERVEN":
        draw_heart(draw, cx, cy, radius, meta)
    elif suit == "ZALUD":
        draw_acorn(draw, cx, cy, radius, meta)
    elif suit == "ZELEN":
        draw_leaf(draw, cx, cy, radius, meta)
    else:
        draw_koule(draw, cx, cy, radius, meta)


def draw_card_frame(draw: ImageDraw.ImageDraw, suit: str):
    meta = SUIT_META[suit]
    trim = meta["trim"] + (255,)
    ink = (26, 18, 14, 255)
    draw.rounded_rectangle([18, 18, CW - 18, CH - 18], radius=48, outline=ink, width=9)
    draw.rounded_rectangle([32, 32, CW - 32, CH - 32], radius=38, outline=trim, width=5)
    draw.rectangle([168, 146, CW - 168, CH - 146], outline=ink, width=4)
    draw.rectangle([178, 156, CW - 178, CH - 156], outline=trim, width=3)


def draw_huge_corners(base: Image.Image, suit: str, rank: str):
    meta = SUIT_META[suit]
    font_path = FONT_DISPLAY if os.path.exists(FONT_DISPLAY) else FONT_ANT
    f_size = 142 if rank != "10" else 112
    font = ImageFont.truetype(font_path, f_size)
    ink = (20, 12, 10, 255)
    fill_col = meta["primary"] + (255,)

    def paint_corner(target_img):
        d = ImageDraw.Draw(target_img)
        d.rounded_rectangle([24, 24, 174, 336], radius=24, fill=(242, 234, 214, 255))
        tx = 99
        ty = 96
        bbox = d.textbbox((0, 0), rank, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        bx = tx - tw / 2 - bbox[0]
        by = ty - th / 2 - bbox[1]
        for ox in [-5, 0, 5]:
            for oy in [-5, 0, 5]:
                if ox != 0 or oy != 0:
                    d.text((bx + ox, by + oy), rank, font=font, fill=ink)
        d.text((bx, by), rank, font=font, fill=fill_col)
        draw_suit(d, suit, tx, 248, 60)

    paint_corner(base)
    corner_patch = Image.new("RGBA", (196, 356), (0, 0, 0, 0))
    paint_corner(corner_patch)
    rot = corner_patch.rotate(180)
    base.alpha_composite(rot, (CW - 196, CH - 356))


def build_classic_card(suit: str, rank: str):
    canvas = make_parchment_canvas()
    orig_path = os.path.join(BACKUP_DIR, f"{suit}_{rank}.png")
    orig = Image.open(orig_path).convert("RGBA").resize((CW, CH), Image.Resampling.LANCZOS)

    draw_card_frame(ImageDraw.Draw(canvas), suit)

    if rank in ("D", "H", "K"):
        crop_box = (int(CW * 0.175), int(CH * 0.18), int(CW * 0.825), int(CH * 0.81))
        court_patch = orig.crop(crop_box)
        mask = Image.new("L", court_patch.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([16, 16, court_patch.width - 16, court_patch.height - 16], radius=34, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(7))
        canvas.paste(court_patch, (crop_box[0], crop_box[1]), mask)
        d = ImageDraw.Draw(canvas)
        for sx, sy in [(CW - 228, 224), (228, CH - 224)]:
            d.ellipse([sx - 46, sy - 46, sx + 46, sy + 46], fill=(238, 231, 212, 255))
            draw_suit(d, suit, sx, sy, 44)
    elif rank == "E":
        wreath_orig_path = os.path.join(BACKUP_DIR, "CERVEN_E.png")
        w_orig = Image.open(wreath_orig_path).convert("RGBA").resize((CW, CH), Image.Resampling.LANCZOS)
        crop_box = (int(CW * 0.165), int(CH * 0.23), int(CW * 0.835), int(CH * 0.77))
        crest_patch = w_orig.crop(crop_box)
        mask = Image.new("L", crest_patch.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([12, 12, crest_patch.width - 12, crest_patch.height - 12], radius=32, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(7))
        canvas.paste(crest_patch, (crop_box[0], crop_box[1]), mask)
        d = ImageDraw.Draw(canvas)
        cx, cy = CW // 2, CH // 2 - 4
        # Clean heraldic crest shield drawn directly over CERVEN_E's shield center (completely covers heart + matches woodcut border)
        shield_poly = [
            (cx - 126, cy - 132),
            (cx - 52, cy - 118),
            (cx, cy - 144),
            (cx + 52, cy - 118),
            (cx + 126, cy - 132),
            (cx + 128, cy + 14),
            (cx + 98, cy + 88),
            (cx, cy + 142),
            (cx - 98, cy + 88),
            (cx - 128, cy + 14),
        ]
        d.polygon(shield_poly, fill=(244, 236, 214, 255))
        d.line(shield_poly + [shield_poly[0]], fill=(30, 20, 14, 255), width=9, joint="curve")
        draw_suit(d, suit, cx, cy + 2, 86)
    else:
        d = ImageDraw.Draw(canvas)
        wm = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        wmd = ImageDraw.Draw(wm)
        wmd.ellipse([CW // 2 - 150, CH // 2 - 150, CW // 2 + 150, CH // 2 + 150], outline=SUIT_META[suit]["trim"] + (180,), width=6)
        draw_suit(wmd, suit, CW // 2, CH // 2, 134)
        alpha = wm.split()[3].point(lambda p: int(p * 0.16))
        wm.putalpha(alpha)
        canvas.alpha_composite(wm)

        layouts = {
            "7": [(0.34, 0.26), (0.66, 0.26), (0.50, 0.40), (0.34, 0.54), (0.66, 0.54), (0.34, 0.74), (0.66, 0.74)],
            "8": [(0.34, 0.25), (0.66, 0.25), (0.50, 0.39), (0.34, 0.50), (0.66, 0.50), (0.50, 0.61), (0.34, 0.75), (0.66, 0.75)],
            "9": [(0.34, 0.24), (0.66, 0.24), (0.34, 0.41), (0.66, 0.41), (0.50, 0.50), (0.34, 0.59), (0.66, 0.59), (0.34, 0.76), (0.66, 0.76)],
            "10": [(0.34, 0.23), (0.66, 0.23), (0.50, 0.34), (0.34, 0.43), (0.66, 0.43), (0.34, 0.57), (0.66, 0.57), (0.50, 0.66), (0.34, 0.77), (0.66, 0.77)],
        }
        pip_r = 76 if rank in ("7", "8") else 68
        for (fx, fy) in layouts[rank]:
            draw_suit(d, suit, CW * fx, CH * fy, pip_r)

    draw_huge_corners(canvas, suit, rank)
    out_img = canvas.resize((W, H), Image.Resampling.LANCZOS)
    out_img.save(os.path.join(CARDS_DIR, f"{suit}_{rank}.png"))


def build_shop_illustrations():
    os.makedirs(SHOP_DIR, exist_ok=True)
    items = [
        ("urn", (240, 128, 42)),
        ("chalice", (222, 48, 62)),
        ("gauntlet", (152, 184, 218)),
        ("phial", (250, 108, 36)),
        ("eye", (88, 224, 246)),
        ("scroll", (244, 206, 84)),
        ("mirror", (164, 104, 250)),
        ("key", (224, 178, 82)),
        ("whetstone", (236, 94, 72)),
        ("bell", (248, 192, 54)),
    ]
    sz = 512
    for key, accent in items:
        img = Image.new("RGBA", (sz, sz), (24, 18, 16, 255))
        d = ImageDraw.Draw(img)
        cx, cy = sz // 2, sz // 2
        for r_i in range(18, 0, -1):
            frac = r_i / 18.0
            bg = (
                int(18 + (1.0 - frac) * accent[0] * 0.34),
                int(14 + (1.0 - frac) * accent[1] * 0.28),
                int(12 + (1.0 - frac) * accent[2] * 0.24),
                255,
            )
            rad = int(242 * frac)
            d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=bg)
        # Ornate corner brackets & metallic brass border
        d.rounded_rectangle([14, 14, sz - 14, sz - 14], radius=42, outline=accent + (240,), width=8)
        d.rounded_rectangle([30, 30, sz - 30, sz - 30], radius=30, outline=(138, 106, 56, 210), width=4)
        ink = (16, 10, 8, 255)
        hi = tuple(min(255, int(c + 64)) for c in accent) + (255,)
        mid = accent + (255,)
        dk = tuple(max(22, int(c * 0.42)) for c in accent) + (255,)

        if key == "urn":
            poly = [(cx - 64, cy - 78), (cx + 64, cy - 78), (cx + 104, cy + 16), (cx + 62, cy + 132), (cx - 62, cy + 132), (cx - 104, cy + 16)]
            d.polygon(poly, fill=dk)
            d.polygon([(cx - 48, cy - 78), (cx + 10, cy - 78), (cx + 22, cy + 132), (cx - 42, cy + 132)], fill=mid)
            d.line(poly + [poly[0]], fill=ink, width=10, joint="curve")
            d.rounded_rectangle([cx - 82, cy - 106, cx + 82, cy - 74], radius=12, fill=hi, outline=ink, width=8)
            d.polygon([(cx, cy - 196), (cx + 42, cy - 110), (cx, cy - 96), (cx - 42, cy - 110)], fill=(255, 132, 34, 255), outline=ink)
            d.ellipse([cx - 22, cy - 146, cx + 22, cy - 104], fill=(255, 232, 118, 255))
        elif key == "chalice":
            # Ornate curved goblet bowl + fluted stem + ruby jewel
            bowl_pts = []
            for i in range(25):
                u = (i / 24.0) * math.pi
                bx = cx + math.cos(u) * 102
                by = cy - 102 + math.sin(u) * 124
                bowl_pts.append((bx, by))
            d.polygon(bowl_pts, fill=(182, 138, 52, 255))
            d.chord([cx - 88, cy - 226, cx + 88, cy + 20], 20, 160, fill=dk)
            d.line(bowl_pts + [bowl_pts[0]], fill=ink, width=10, joint="curve")
            d.ellipse([cx - 102, cy - 122, cx + 102, cy - 82], fill=(146, 18, 28, 255), outline=ink, width=8)
            d.ellipse([cx - 82, cy - 114, cx + 82, cy - 90], fill=(224, 34, 46, 255))
            d.rectangle([cx - 18, cy + 20, cx + 18, cy + 114], fill=(208, 164, 68, 255), outline=ink, width=8)
            d.ellipse([cx - 32, cy + 44, cx + 32, cy + 78], fill=(244, 206, 98, 255), outline=ink, width=7)
            d.polygon([(cx - 88, cy + 140), (cx + 88, cy + 140), (cx + 52, cy + 108), (cx - 52, cy + 108)], fill=(214, 170, 74, 255), outline=ink)
            d.line([(cx - 88, cy + 140), (cx + 88, cy + 140)], fill=ink, width=10)
            d.ellipse([cx - 24, cy - 68, cx + 24, cy - 20], fill=(238, 34, 52, 255), outline=ink, width=6)
            d.ellipse([cx - 14, cy - 58, cx - 2, cy - 46], fill=(255, 204, 204, 255))
        elif key == "gauntlet":
            poly = [(cx - 64, cy - 124), (cx + 64, cy - 124), (cx + 96, cy + 28), (cx + 56, cy + 138), (cx - 56, cy + 138), (cx - 96, cy + 28)]
            d.polygon(poly, fill=dk)
            d.polygon([(cx - 52, cy - 124), (cx + 12, cy - 124), (cx + 22, cy + 138), (cx - 46, cy + 138)], fill=mid)
            d.line(poly + [poly[0]], fill=ink, width=10, joint="curve")
            for ry in [-62, -14, 34, 82]:
                d.line([(cx - 78, cy + ry), (cx + 78, cy + ry)], fill=ink, width=8)
                d.line([(cx - 70, cy + ry - 8), (cx + 20, cy + ry - 8)], fill=hi, width=5)
        elif key == "phial":
            d.rounded_rectangle([cx - 34, cy - 156, cx + 34, cy - 72], radius=8, fill=(178, 126, 68, 255), outline=ink, width=8)
            d.ellipse([cx - 112, cy - 74, cx + 112, cy + 150], fill=(78, 22, 16, 255), outline=ink, width=10)
            d.chord([cx - 102, cy - 64, cx + 102, cy + 140], 8, 172, fill=mid)
            d.chord([cx - 92, cy - 54, cx + 92, cy + 130], 24, 156, fill=(255, 164, 52, 255))
            d.ellipse([cx - 62, cy - 34, cx - 12, cy + 16], fill=(255, 224, 152, 235))
        elif key == "eye":
            pts = [(cx - 144, cy), (cx - 58, cy - 76), (cx, cy - 92), (cx + 58, cy - 76), (cx + 144, cy), (cx + 58, cy + 76), (cx, cy + 92), (cx - 58, cy + 76)]
            d.polygon(pts, fill=(236, 240, 246, 255))
            d.line(pts + [pts[0]], fill=ink, width=10, joint="curve")
            d.ellipse([cx - 68, cy - 68, cx + 68, cy + 68], fill=mid, outline=ink, width=8)
            d.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=ink)
            d.ellipse([cx - 20, cy - 44, cx + 14, cy - 10], fill=(255, 255, 255, 245))
        elif key == "scroll":
            d.rectangle([cx - 94, cy - 116, cx + 94, cy + 116], fill=(236, 218, 174, 255), outline=ink, width=9)
            d.rounded_rectangle([cx - 114, cy - 140, cx + 114, cy - 92], radius=22, fill=mid, outline=ink, width=8)
            d.rounded_rectangle([cx - 114, cy + 92, cx + 114, cy + 140], radius=22, fill=mid, outline=ink, width=8)
            for ly in [-52, -16, 20, 56]:
                d.line([(cx - 62, cy + ly), (cx + 62, cy + ly)], fill=(96, 36, 24, 225), width=7)
            d.ellipse([cx + 22, cy + 30, cx + 76, cy + 84], fill=(186, 26, 34, 255), outline=ink, width=7)
        elif key == "mirror":
            d.ellipse([cx - 104, cy - 126, cx + 104, cy + 82], fill=dk, outline=ink, width=10)
            d.ellipse([cx - 80, cy - 102, cx + 80, cy + 58], fill=(78, 174, 224, 255), outline=hi, width=6)
            d.line([(cx - 46, cy - 66), (cx + 28, cy + 14)], fill=(238, 248, 255, 220), width=14)
            d.rounded_rectangle([cx - 20, cy + 78, cx + 20, cy + 172], radius=10, fill=mid, outline=ink, width=8)
        elif key == "key":
            d.ellipse([cx - 72, cy - 144, cx + 72, cy - 12], fill=mid, outline=ink, width=10)
            d.ellipse([cx - 32, cy - 108, cx + 32, cy - 48], fill=(24, 18, 16, 255), outline=ink, width=6)
            d.rectangle([cx - 16, cy - 16, cx + 16, cy + 150], fill=mid, outline=ink, width=8)
            d.rectangle([cx + 14, cy + 78, cx + 74, cy + 108], fill=hi, outline=ink, width=6)
            d.rectangle([cx + 14, cy + 122, cx + 56, cy + 148], fill=hi, outline=ink, width=6)
        elif key == "whetstone":
            stone = [(cx - 126, cy + 44), (cx - 18, cy - 92), (cx + 126, cy - 48), (cx + 18, cy + 92)]
            d.polygon(stone, fill=(138, 144, 158, 255))
            d.line(stone + [stone[0]], fill=ink, width=10, joint="curve")
            d.line([(cx - 66, cy - 18), (cx + 66, cy + 18)], fill=hi, width=10)
            for sx, sy in [(-64, -74), (48, -96), (92, -16)]:
                d.ellipse([cx + sx - 12, cy + sy - 12, cx + sx + 12, cy + sy + 12], fill=(255, 214, 78, 255))
        else:
            bell = [(cx - 98, cy + 92), (cx - 70, cy - 64), (cx, cy - 118), (cx + 70, cy - 64), (cx + 98, cy + 92)]
            d.polygon(bell, fill=mid)
            d.line(bell + [bell[0]], fill=ink, width=10, joint="curve")
            d.ellipse([cx - 28, cy + 74, cx + 28, cy + 130], fill=hi, outline=ink, width=8)
            d.ellipse([cx - 48, cy - 72, cx - 10, cy - 20], fill=hi)

        out = img.resize((256, 256), Image.Resampling.LANCZOS)
        out.save(os.path.join(SHOP_DIR, f"{key}.png"))


def main():
    ensure_backup()
    for suit in ["CERVEN", "ZALUD", "ZELEN", "GULA"]:
        for rank in ["7", "8", "9", "10", "D", "H", "K", "E"]:
            build_classic_card(suit, rank)
    build_shop_illustrations()
    print("UPGRADE_CARDS_AND_SHOP_DONE: 32 cards + 10 shop PNGs generated cleanly.")


if __name__ == "__main__":
    main()
