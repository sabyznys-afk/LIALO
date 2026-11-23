#!/usr/bin/env python3
"""Generate 512x512 hand-inked medieval woodcut/engraving 2D art for all LIALO Blades,
Table Relics, and visible Passive Relics into assets/relics/*.png.
"""

from __future__ import annotations

import math
import os
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "relics"
SIZE = 512
CX, CY = SIZE // 2, SIZE // 2
INK = (20, 13, 8, 255)
INK_SOFT = (28, 18, 12, 210)


def new_canvas() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def add_aura(img: Image.Image, color: tuple[int, int, int], radius: int = 190, strength: int = 110) -> None:
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    for r in range(radius, 20, -14):
        t = 1.0 - (r / float(radius))
        a = int(strength * (t ** 1.6))
        d.ellipse([CX - r, CY - r, CX + r, CY + r], fill=(color[0], color[1], color[2], a))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(glow)


def apply_woodcut_hatch(img: Image.Image, spacing: int = 10, alpha: int = 38) -> None:
    """Apply subtle diagonal woodcut engraving hatch lines only over opaque pixels."""
    hatch = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hatch)
    for offset in range(-SIZE, SIZE * 2, spacing):
        hd.line([(offset, 0), (offset - SIZE, SIZE)], fill=(20, 12, 8, alpha), width=2)
    # Mask hatch to existing alpha
    r, g, b, a = img.split()
    hr, hg, hb, ha = hatch.split()
    # Keep hatch only where img alpha > 160
    mask = a.point(lambda p: 255 if p > 160 else 0)
    masked_hatch = Image.composite(hatch, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), mask)
    img.alpha_composite(masked_hatch)


def draw_poly_ink(d: ImageDraw.Draw, pts: list[tuple[float, float]], fill, outline=INK, width: int = 7) -> None:
    d.polygon(pts, fill=fill)
    closed = pts + [pts[0]]
    d.line(closed, fill=outline, width=width, joint="curve")


def draw_circle_ink(d: ImageDraw.Draw, cx: float, cy: float, r: float, fill, outline=INK, width: int = 7) -> None:
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)


def rot_pt(x: float, y: float, angle_deg: float, cx: float = CX, cy: float = CY) -> tuple[float, float]:
    rad = math.radians(angle_deg)
    ca, sa = math.cos(rad), math.sin(rad)
    dx, dy = x - cx, y - cy
    return (cx + dx * ca - dy * sa, cy + dx * sa + dy * ca)


def draw_sparkle(d: ImageDraw.Draw, cx: float, cy: float, r: float, col: tuple[int, int, int, int]) -> None:
    pts = [
        (cx, cy - r), (cx + r * 0.25, cy - r * 0.25),
        (cx + r, cy), (cx + r * 0.25, cy + r * 0.25),
        (cx, cy + r), (cx - r * 0.25, cy + r * 0.25),
        (cx - r, cy), (cx - r * 0.25, cy - r * 0.25),
    ]
    d.polygon(pts, fill=col)


# ============================================================================
# 5 BLADES
# ============================================================================

def draw_sword(
    blade_light, blade_dark, guard_col, grip_col, pommel_col, aura_col,
    style: str = "iron"
) -> Image.Image:
    img = new_canvas()
    add_aura(img, aura_col, radius=200, strength=125)
    d = ImageDraw.Draw(img)
    ang = -42.0  # diagonal hero angle

    def P(x: float, y: float) -> tuple[float, float]:
        return rot_pt(CX + x, CY + y, ang)

    # Blade body
    if style == "crimson":
        # Curved saber
        pts = [
            P(-14, 72), P(-18, -30), P(-8, -120), P(16, -205),
            P(18, -110), P(10, -25), P(12, 72)
        ]
    elif style == "dragon":
        # Jagged greatsword
        pts = [
            P(-24, 70), P(-26, -10), P(-16, -35), P(-28, -60),
            P(-18, -120), P(0, -212), P(18, -120), P(28, -60),
            P(16, -35), P(26, -10), P(24, 70)
        ]
    elif style == "gilded":
        # Broad royal claymore
        pts = [P(-22, 72), P(-18, -135), P(0, -212), P(18, -135), P(22, 72)]
    elif style == "rune":
        # Runeblade
        pts = [P(-20, 72), P(-16, -130), P(0, -208), P(16, -130), P(20, 72)]
    else:
        # Tavern Falchion (slightly flared tip)
        pts = [P(-16, 72), P(-15, -70), P(-22, -135), P(6, -204), P(18, -125), P(14, 72)]

    draw_poly_ink(d, pts, blade_dark, width=8)
    # Left bevel highlight
    hi_pts = [pts[0], pts[1], pts[2] if len(pts) > 4 else pts[1], P(0, -192), P(0, 70)]
    if style in ("gilded", "rune", "iron"):
        hi_pts = [pts[0], pts[1], pts[2], P(0, 70)]
    d.polygon(hi_pts, fill=blade_light)
    d.line([P(0, 62), P(0, -172)], fill=INK_SOFT, width=5)

    # Blade details per style
    if style == "gilded":
        # Damascus waves
        for wy in range(-140, 50, 22):
            d.line([P(-12, wy), P(0, wy - 8), P(12, wy)], fill=(235, 240, 250, 170), width=3)
    elif style == "crimson":
        # Glowing crimson fuller + wisps
        d.line([P(-2, 55), P(4, -145)], fill=(255, 45, 70, 255), width=6)
        draw_sparkle(d, *P(-34, -85), 16, (255, 60, 80, 220))
        draw_sparkle(d, *P(36, -130), 14, (255, 60, 80, 220))
    elif style == "rune":
        # Cyan storm runes + lightning arcs
        for ry in (-130, -90, -50, -10, 30):
            d.line([P(-7, ry), P(7, ry - 8), P(-5, ry - 16), P(7, ry - 22)], fill=(90, 240, 255, 255), width=4)
        d.line([P(-38, -110), P(-18, -85), P(-42, -55)], fill=(120, 245, 255, 230), width=4)
        d.line([P(36, -140), P(18, -115), P(42, -90)], fill=(120, 245, 255, 230), width=4)
    elif style == "dragon":
        # Glowing magma veins
        for my in (-150, -100, -50, 0, 40):
            d.line([P(-14, my), P(2, my - 10), P(14, my - 4)], fill=(255, 115, 25, 255), width=5)
            d.line([P(-10, my), P(2, my - 10)], fill=(255, 220, 100, 255), width=2)

    # Crossguard
    if style == "dragon":
        guard_pts = [P(-78, 52), P(-45, 68), P(0, 68), P(45, 68), P(78, 52), P(52, 86), P(0, 92), P(-52, 86)]
    elif style == "gilded":
        guard_pts = [P(-72, 60), P(-32, 68), P(32, 68), P(72, 60), P(64, 86), P(0, 92), P(-64, 86)]
    else:
        guard_pts = [P(-64, 68), P(64, 68), P(58, 86), P(-58, 86)]
    draw_poly_ink(d, guard_pts, guard_col, width=7)

    # Grip
    grip_pts = [P(-11, 86), P(11, 86), P(10, 166), P(-10, 166)]
    draw_poly_ink(d, grip_pts, grip_col, width=7)
    for gy in range(98, 162, 14):
        d.line([P(-10, gy), P(10, gy + 5)], fill=INK, width=4)

    # Pommel
    px, py = P(0, 184)
    draw_circle_ink(d, px, py, 20, pommel_col, width=7)
    if style == "crimson":
        draw_circle_ink(d, px, py, 10, (240, 30, 60, 255), width=4)
    elif style in ("gilded", "rune", "dragon"):
        draw_circle_ink(d, px, py, 9, aura_col + (255,), width=4)

    apply_woodcut_hatch(img, spacing=12, alpha=26)
    return img


# ============================================================================
# 10 TABLE RELICS
# ============================================================================

def draw_trelic_soul_bell() -> Image.Image:
    img = new_canvas()
    add_aura(img, (60, 230, 255), 195, 130)
    d = ImageDraw.Draw(img)
    # Shockwave rings
    for r in (185, 150):
        d.arc([CX - r, CY - r + 10, CX + r, CY + r + 10], 195, 345, fill=(90, 240, 255, 200), width=5)
        d.arc([CX - r, CY - r + 10, CX + r, CY + r + 10], 15, 165, fill=(90, 240, 255, 200), width=5)
    # Handle
    draw_poly_ink(d, [(CX - 14, 74), (CX + 14, 74), (CX + 18, 148), (CX - 18, 148)], (165, 128, 62, 255))
    draw_circle_ink(d, CX, 66, 22, (215, 175, 78, 255))
    # Bell dome
    bell_pts = [
        (CX - 66, 160), (CX - 38, 140), (CX + 38, 140), (CX + 66, 160),
        (CX + 98, 320), (CX + 122, 355), (CX - 122, 355), (CX - 98, 320)
    ]
    draw_poly_ink(d, bell_pts, (72, 138, 158, 255), width=8)
    # Highlight side
    d.polygon([(CX - 56, 164), (CX - 22, 146), (CX - 18, 346), (CX - 98, 346)], fill=(120, 205, 225, 210))
    # Clapper
    draw_circle_ink(d, CX, 372, 22, (70, 240, 255, 255), width=7)
    # Rune on bell
    d.line([(CX, 195), (CX, 295)], fill=(160, 255, 255, 255), width=6)
    d.line([(CX - 34, 235), (CX + 34, 235)], fill=(160, 255, 255, 255), width=6)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_blood_seal() -> Image.Image:
    img = new_canvas()
    add_aura(img, (240, 35, 60), 195, 130)
    d = ImageDraw.Draw(img)
    # Wax seal scalloped circle
    pts = []
    for i in range(24):
        a = i * (math.tau / 24.0)
        r = 148 if i % 2 == 0 else 132
        pts.append((CX + math.cos(a) * r, CY + 20 + math.sin(a) * r))
    draw_poly_ink(d, pts, (175, 24, 42, 255), width=8)
    draw_circle_ink(d, CX, CY + 20, 102, (215, 36, 56, 255), width=6)
    # Gothic cross emblem
    d.polygon([(CX - 14, CY - 55), (CX + 14, CY - 55), (CX + 14, CY + 95), (CX - 14, CY + 95)], fill=(255, 195, 165, 255))
    d.polygon([(CX - 65, CY + 6), (CX + 65, CY + 6), (CX + 65, CY + 34), (CX - 65, CY + 34)], fill=(255, 195, 165, 255))
    # Stamp handle on top
    draw_poly_ink(d, [(CX - 28, 56), (CX + 28, 56), (CX + 20, 125), (CX - 20, 125)], (92, 52, 34, 255), width=7)
    draw_circle_ink(d, CX, 56, 30, (215, 170, 70, 255), width=7)
    # Blood drips
    for dx, dy in [(-45, 165), (50, 155), (0, 178)]:
        draw_circle_ink(d, CX + dx, CY + dy, 12, (215, 25, 45, 255), width=5)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_star_bow() -> Image.Image:
    img = new_canvas()
    add_aura(img, (60, 220, 255), 195, 130)
    d = ImageDraw.Draw(img)
    # Outer brass astrolabe ring
    draw_circle_ink(d, CX, CY, 156, (212, 168, 66, 255), width=8)
    draw_circle_ink(d, CX, CY, 128, (24, 34, 52, 255), width=6)
    # Inner tilted orbit rings
    d.ellipse([CX - 115, CY - 45, CX + 115, CY + 45], outline=(90, 235, 255, 255), width=6)
    d.ellipse([CX - 45, CY - 115, CX + 45, CY + 115], outline=(240, 200, 90, 255), width=6)
    # Central starburst
    draw_sparkle(d, CX, CY, 92, (110, 245, 255, 255))
    draw_circle_ink(d, CX, CY, 26, (255, 245, 200, 255), width=6)
    # Top suspension ring
    draw_circle_ink(d, CX, 66, 24, (220, 180, 75, 255), width=7)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_ash_glass() -> Image.Image:
    img = new_canvas()
    add_aura(img, (180, 105, 255), 195, 130)
    d = ImageDraw.Draw(img)
    # Frame pillars
    for px in (CX - 94, CX + 94):
        draw_poly_ink(d, [(px - 10, 92), (px + 10, 92), (px + 10, 420), (px - 10, 420)], (140, 145, 160, 255), width=6)
    # Glass bulbs
    draw_poly_ink(d, [(CX - 76, 105), (CX + 76, 105), (CX + 16, CY), (CX - 16, CY)], (68, 52, 96, 235), width=7)
    draw_poly_ink(d, [(CX - 16, CY), (CX + 16, CY), (CX + 76, 405), (CX - 76, 405)], (68, 52, 96, 235), width=7)
    # Glowing violet ash/sand inside
    d.polygon([(CX - 54, 155), (CX + 54, 155), (CX + 10, CY - 4), (CX - 10, CY - 4)], fill=(195, 125, 255, 240))
    d.polygon([(CX - 62, 396), (CX + 62, 396), (CX + 12, 335), (CX - 12, 335)], fill=(195, 125, 255, 240))
    d.line([(CX, CY - 4), (CX, 345)], fill=(235, 195, 255, 255), width=5)
    # Top & bottom brass caps
    draw_poly_ink(d, [(CX - 115, 72), (CX + 115, 72), (CX + 105, 106), (CX - 105, 106)], (198, 156, 68, 255), width=7)
    draw_poly_ink(d, [(CX - 105, 406), (CX + 105, 406), (CX + 115, 440), (CX - 115, 440)], (198, 156, 68, 255), width=7)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_war_horn() -> Image.Image:
    img = new_canvas()
    add_aura(img, (150, 215, 255), 195, 125)
    d = ImageDraw.Draw(img)
    # Curved horn body
    horn_pts = [
        (115, 345), (155, 365), (260, 340), (355, 255), (402, 130),
        (340, 105), (305, 200), (225, 275), (135, 305)
    ]
    draw_poly_ink(d, horn_pts, (224, 214, 188, 255), width=8)
    # Steel bands
    draw_poly_ink(d, [(220, 270), (242, 255), (275, 330), (250, 345)], (135, 165, 195, 255), width=6)
    draw_poly_ink(d, [(334, 98), (410, 128), (398, 154), (324, 124)], (175, 205, 232, 255), width=7)
    # Sound waves
    for r in (48, 82):
        d.arc([375 - r, 95 - r, 375 + r, 95 + r], -60, 45, fill=(130, 230, 255, 240), width=6)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_hollow_mask() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 50, 75), 195, 130)
    d = ImageDraw.Draw(img)
    # Jagged bone-white mask with broken right edge
    mask_pts = [
        (CX - 115, 120), (CX, 86), (CX + 96, 126), (CX + 62, 210),
        (CX + 92, 275), (CX + 26, 395), (CX - 48, 412), (CX - 112, 315)
    ]
    draw_poly_ink(d, mask_pts, (236, 228, 214, 255), width=8)
    # Dark obsidian eye socket + glowing crimson eye
    draw_poly_ink(d, [(CX - 82, 200), (CX - 18, 212), (CX - 30, 246), (CX - 76, 236)], (22, 16, 22, 255), width=5)
    draw_circle_ink(d, CX - 48, 224, 10, (255, 45, 70, 255), width=3)
    # Crimson fang markings
    d.polygon([(CX - 94, 130), (CX - 62, 185), (CX - 86, 185)], fill=(205, 32, 48, 255))
    d.polygon([(CX - 75, 290), (CX - 50, 380), (CX - 86, 330)], fill=(205, 32, 48, 255))
    # Cracks
    d.line([(CX + 18, 132), (CX - 8, 200), (CX + 24, 265)], fill=INK, width=5)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_censer() -> Image.Image:
    img = new_canvas()
    add_aura(img, (60, 245, 165), 195, 125)
    d = ImageDraw.Draw(img)
    # Hanging chains
    d.line([(CX, 54), (CX - 82, 200)], fill=(195, 165, 85, 255), width=6)
    d.line([(CX, 54), (CX + 82, 200)], fill=(195, 165, 85, 255), width=6)
    d.line([(CX, 54), (CX, 165)], fill=(195, 165, 85, 255), width=6)
    draw_circle_ink(d, CX, 56, 18, (220, 182, 76, 255), width=6)
    # Emerald smoke plumes
    for sx, sy, sr in [(CX - 48, 155, 26), (CX + 46, 145, 28), (CX, 125, 32)]:
        d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(80, 245, 165, 155))
    # Censer dome & bowl
    draw_poly_ink(d, [(CX - 88, 235), (CX, 145), (CX + 88, 235)], (205, 162, 66, 255), width=8)
    draw_poly_ink(d, [(CX - 94, 245), (CX + 94, 245), (CX + 62, 355), (CX - 62, 355)], (168, 126, 48, 255), width=8)
    # Glowing emerald core slits
    for rx in (-36, 0, 36):
        d.ellipse([CX + rx - 10, 195, CX + rx + 10, 224], fill=(80, 255, 175, 255))
    # Base pedestal
    draw_poly_ink(d, [(CX - 46, 355), (CX + 46, 355), (CX + 64, 412), (CX - 64, 412)], (145, 108, 42, 255), width=7)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_gold_scales() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 210, 55), 195, 130)
    d = ImageDraw.Draw(img)
    # Pillar & base
    draw_poly_ink(d, [(CX - 14, 110), (CX + 14, 110), (CX + 18, 385), (CX - 18, 385)], (218, 175, 58, 255), width=7)
    draw_poly_ink(d, [(CX - 86, 385), (CX + 86, 385), (CX + 102, 425), (CX - 102, 425)], (188, 145, 42, 255), width=7)
    # Balance beam
    draw_poly_ink(d, [(CX - 148, 132), (CX + 148, 132), (CX + 138, 154), (CX - 138, 154)], (245, 202, 74, 255), width=7)
    draw_circle_ink(d, CX, 142, 20, (255, 225, 105, 255), width=6)
    # Left & Right pans
    for px in (CX - 134, CX + 134):
        d.line([(px, 154), (px - 44, 285)], fill=(210, 170, 68, 255), width=5)
        d.line([(px, 154), (px + 44, 285)], fill=(210, 170, 68, 255), width=5)
        draw_poly_ink(d, [(px - 54, 285), (px + 54, 285), (px + 38, 315), (px - 38, 315)], (228, 185, 64, 255), width=6)
    # Coins on left pan, card on right pan
    for cy in (270, 256, 242):
        draw_circle_ink(d, CX - 134, cy, 18, (255, 222, 80, 255), width=4)
    draw_poly_ink(d, [(CX + 114, 222), (CX + 156, 222), (CX + 156, 282), (CX + 114, 282)], (245, 235, 210, 255), width=5)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_iron_chain() -> Image.Image:
    img = new_canvas()
    add_aura(img, (105, 205, 255), 195, 125)
    d = ImageDraw.Draw(img)
    # Heavy crossed chain links
    for angle in (-38, 38):
        for offset in range(-150, 160, 48):
            x, y = rot_pt(CX + offset, CY, angle)
            p1 = rot_pt(CX + offset - 22, CY - 13, angle)
            p2 = rot_pt(CX + offset + 22, CY + 13, angle)
            bbox = [min(p1[0], p2[0]) - 10, min(p1[1], p2[1]) - 10, max(p1[0], p2[0]) + 10, max(p1[1], p2[1]) + 10]
            d.ellipse(bbox, outline=INK, width=16)
            d.ellipse(bbox, outline=(128, 148, 172, 255), width=9)
    # Central iron padlock with frost rune
    draw_poly_ink(d, [(CX - 54, CY - 32), (CX + 54, CY - 32), (CX + 54, CY + 68), (CX - 54, CY + 68)], (78, 92, 112, 255), width=8)
    d.arc([CX - 34, CY - 78, CX + 34, CY - 10], 180, 360, fill=(145, 168, 195, 255), width=12)
    draw_circle_ink(d, CX, CY + 12, 14, (105, 230, 255, 255), width=4)
    apply_woodcut_hatch(img)
    return img


def draw_trelic_phoenix_box() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 130, 35), 200, 140)
    d = ImageDraw.Draw(img)
    # Blazing phoenix wings erupting from top
    for side in (-1, 1):
        w_pts = [
            (CX, 225), (CX + side * 65, 130), (CX + side * 155, 85),
            (CX + side * 130, 175), (CX + side * 165, 190), (CX + side * 95, 245)
        ]
        draw_poly_ink(d, w_pts, (255, 125, 32, 255), width=7)
        d.polygon([(CX, 225), (CX + side * 55, 155), (CX + side * 115, 135), (CX + side * 75, 215)], fill=(255, 215, 80, 255))
    # Reliquary chest
    draw_poly_ink(d, [(CX - 94, 245), (CX + 94, 245), (CX + 82, 395), (CX - 82, 395)], (152, 62, 34, 255), width=8)
    draw_poly_ink(d, [(CX - 94, 245), (CX + 94, 245), (CX + 94, 272), (CX - 94, 272)], (228, 176, 56, 255), width=7)
    draw_circle_ink(d, CX, 315, 24, (255, 195, 65, 255), width=6)
    apply_woodcut_hatch(img)
    return img


# ============================================================================
# 21 VISIBLE PASSIVE RELICS
# ============================================================================

def draw_rel_fujara() -> Image.Image:
    img = new_canvas()
    add_aura(img, (240, 140, 65), 190, 120)
    d = ImageDraw.Draw(img)
    # Tall diagonal copper-bound fujara flute
    pts = [rot_pt(CX - 16, CY - 180, -32), rot_pt(CX + 16, CY - 180, -32),
           rot_pt(CX + 24, CY + 185, -32), rot_pt(CX - 24, CY + 185, -32)]
    draw_poly_ink(d, pts, (195, 108, 48, 255), width=8)
    for y in (-110, -30, 50, 125):
        b1 = rot_pt(CX - 22, CY + y, -32)
        b2 = rot_pt(CX + 22, CY + y, -32)
        d.line([b1, b2], fill=(235, 185, 85, 255), width=10)
    for hy in (10, 45, 80):
        hx, hy2 = rot_pt(CX, CY + hy, -32)
        draw_circle_ink(d, hx, hy2, 8, (32, 18, 10, 255), width=3)
    apply_woodcut_hatch(img)
    return img


def draw_rel_knuckle() -> Image.Image:
    img = new_canvas()
    add_aura(img, (245, 215, 145), 190, 120)
    d = ImageDraw.Draw(img)
    pts = [
        (CX - 95, CY - 75), (CX - 35, CY - 115), (CX + 45, CY - 95), (CX + 115, CY - 45),
        (CX + 95, CY + 65), (CX + 25, CY + 110), (CX - 65, CY + 85), (CX - 115, CY + 15)
    ]
    draw_poly_ink(d, pts, (234, 218, 180, 255), width=8)
    for px, py in [(CX - 38, CY - 24), (CX + 28, CY - 18), (CX - 6, CY + 28)]:
        draw_circle_ink(d, px, py, 14, (195, 145, 52, 255), width=4)
    draw_sparkle(d, CX + 95, CY - 110, 26, (255, 235, 130, 255))
    apply_woodcut_hatch(img)
    return img


def draw_rel_phoenix_f() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 110, 45), 195, 130)
    d = ImageDraw.Draw(img)
    pts = [
        (135, 395), (155, 275), (215, 175), (325, 85), (385, 78),
        (355, 165), (305, 255), (235, 335), (165, 385)
    ]
    draw_poly_ink(d, pts, (245, 92, 34, 255), width=8)
    d.polygon([(170, 355), (225, 235), (345, 112), (285, 235)], fill=(255, 198, 62, 255))
    d.line([(120, 412), (370, 96)], fill=(255, 238, 165, 255), width=7)
    apply_woodcut_hatch(img)
    return img


def draw_rel_fang() -> Image.Image:
    img = new_canvas()
    add_aura(img, (235, 40, 70), 190, 130)
    d = ImageDraw.Draw(img)
    pts = [(CX - 78, 95), (CX + 18, 85), (CX + 68, 225), (CX + 32, 395), (CX - 36, 265)]
    draw_poly_ink(d, pts, (236, 226, 206, 255), width=8)
    d.polygon([(CX + 26, 265), (CX + 56, 280), (CX + 32, 395), (CX - 8, 308)], fill=(205, 24, 48, 255))
    draw_circle_ink(d, CX + 34, 422, 14, (220, 28, 52, 255), width=5)
    apply_woodcut_hatch(img)
    return img


def draw_rel_greed() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 210, 50), 190, 125)
    d = ImageDraw.Draw(img)
    # Overflowing pouch/pile of gold florins + bell crest
    for ox, oy, r in [(CX - 60, 310, 46), (CX + 60, 310, 46), (CX, 275, 52), (CX - 34, 215, 42), (CX + 36, 220, 42), (CX, 165, 44)]:
        draw_circle_ink(d, ox, oy, r, (248, 202, 58, 255), width=6)
        draw_circle_ink(d, ox, oy, r - 12, (212, 162, 36, 255), width=3)
    draw_sparkle(d, CX - 95, 145, 24, (255, 245, 160, 255))
    draw_sparkle(d, CX + 95, 155, 20, (255, 245, 160, 255))
    apply_woodcut_hatch(img)
    return img


def draw_rel_alembic() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 110, 35), 195, 130)
    d = ImageDraw.Draw(img)
    # Coiled spout
    d.line([(CX + 20, 155), (CX + 125, 135), (CX + 145, 220)], fill=(208, 135, 62, 255), width=16)
    # Glass bulb
    draw_circle_ink(d, CX - 18, 295, 108, (88, 128, 145, 225), width=8)
    d.chord([CX - 116, 198, CX + 80, 392], 15, 165, fill=(255, 95, 28, 245))
    draw_poly_ink(d, [(CX - 46, 115), (CX + 10, 115), (CX + 16, 202), (CX - 52, 202)], (198, 154, 68, 255), width=7)
    apply_woodcut_hatch(img)
    return img


def draw_rel_royal() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 215, 75), 190, 125)
    d = ImageDraw.Draw(img)
    # Signet ring band
    draw_circle_ink(d, CX, 285, 112, (232, 184, 54, 255), width=8)
    draw_circle_ink(d, CX, 295, 68, (20, 13, 8, 255), width=6)
    # Bezel & ruby crown
    draw_poly_ink(d, [(CX - 68, 135), (CX + 68, 135), (CX + 56, 222), (CX - 56, 222)], (245, 204, 72, 255), width=8)
    draw_circle_ink(d, CX, 178, 24, (220, 32, 54, 255), width=5)
    apply_woodcut_hatch(img)
    return img


def draw_rel_chrono_p() -> Image.Image:
    img = new_canvas()
    add_aura(img, (125, 215, 255), 190, 125)
    d = ImageDraw.Draw(img)
    draw_circle_ink(d, CX, 120, 26, (212, 172, 68, 255), width=7)
    draw_circle_ink(d, CX, 275, 126, (212, 172, 68, 255), width=8)
    draw_circle_ink(d, CX, 275, 102, (242, 232, 205, 255), width=6)
    d.line([(CX, 275), (CX, 198)], fill=INK, width=8)
    d.line([(CX, 275), (CX + 58, 305)], fill=(45, 145, 205, 255), width=7)
    draw_circle_ink(d, CX, 275, 12, (105, 225, 255, 255), width=4)
    apply_woodcut_hatch(img)
    return img


def draw_rel_hex_doll() -> Image.Image:
    img = new_canvas()
    add_aura(img, (165, 75, 235), 190, 125)
    d = ImageDraw.Draw(img)
    # Arms & legs
    draw_poly_ink(d, [(CX - 125, 215), (CX + 125, 215), (CX + 115, 258), (CX - 115, 258)], (178, 148, 108, 255), width=7)
    draw_poly_ink(d, [(CX - 64, 295), (CX - 18, 295), (CX - 34, 415), (CX - 82, 415)], (178, 148, 108, 255), width=7)
    draw_poly_ink(d, [(CX + 18, 295), (CX + 64, 295), (CX + 82, 415), (CX + 34, 415)], (178, 148, 108, 255), width=7)
    # Torso & head
    draw_poly_ink(d, [(CX - 54, 195), (CX + 54, 195), (CX + 62, 325), (CX - 62, 325)], (192, 162, 118, 255), width=8)
    draw_circle_ink(d, CX, 142, 58, (205, 175, 132, 255), width=8)
    # Button eyes & pins
    d.line([(CX - 28, 128), (CX - 10, 146)], fill=INK, width=6)
    d.line([(CX - 10, 128), (CX - 28, 146)], fill=INK, width=6)
    draw_circle_ink(d, CX + 20, 138, 10, (175, 80, 245, 255), width=4)
    d.line([(CX + 24, 252), (CX + 98, 195)], fill=(210, 225, 240, 255), width=6)
    draw_circle_ink(d, CX + 98, 195, 10, (195, 65, 245, 255), width=4)
    apply_woodcut_hatch(img)
    return img


def draw_rel_iron_boot() -> Image.Image:
    img = new_canvas()
    add_aura(img, (155, 185, 215), 190, 120)
    d = ImageDraw.Draw(img)
    pts = [
        (CX - 64, 92), (CX + 46, 92), (CX + 42, 295), (CX + 118, 345),
        (CX + 118, 405), (CX - 76, 405), (CX - 64, 265)
    ]
    draw_poly_ink(d, pts, (148, 162, 182, 255), width=8)
    for ry in (145, 215, 285):
        d.line([(CX - 62, ry), (CX + 42, ry)], fill=INK, width=6)
        draw_circle_ink(d, CX - 38, ry - 18, 6, (215, 225, 240, 255), width=3)
    apply_woodcut_hatch(img)
    return img


def draw_rel_overcharge() -> Image.Image:
    img = new_canvas()
    add_aura(img, (80, 235, 255), 195, 130)
    d = ImageDraw.Draw(img)
    draw_poly_ink(d, [(CX - 16, 125), (CX + 16, 125), (CX + 38, 415), (CX - 38, 415)], (118, 135, 156, 255), width=8)
    draw_poly_ink(d, [(CX - 48, 185), (CX + 48, 185), (CX + 48, 208), (CX - 48, 208)], (215, 145, 65, 255), width=6)
    draw_circle_ink(d, CX, 108, 26, (110, 245, 255, 255), width=6)
    d.line([(CX - 110, 95), (CX - 52, 135), (CX - 82, 170), (CX - 28, 195)], fill=(120, 245, 255, 255), width=7)
    d.line([(CX + 110, 95), (CX + 52, 135), (CX + 82, 170), (CX + 28, 195)], fill=(120, 245, 255, 255), width=7)
    apply_woodcut_hatch(img)
    return img


def draw_rel_woodcutter() -> Image.Image:
    img = new_canvas()
    add_aura(img, (195, 155, 75), 190, 120)
    d = ImageDraw.Draw(img)
    # Haft
    draw_poly_ink(d, [(CX - 18, 86), (CX + 14, 86), (CX + 16, 425), (CX - 22, 425)], (132, 82, 44, 255), width=8)
    # Broad bearded axe head
    axe_pts = [
        (CX - 10, 118), (CX + 118, 92), (CX + 134, 175),
        (CX + 105, 265), (CX + 24, 225), (CX - 10, 195)
    ]
    draw_poly_ink(d, axe_pts, (165, 176, 192, 255), width=8)
    d.polygon([(CX + 98, 102), (CX + 118, 92), (CX + 134, 175), (CX + 105, 265), (CX + 88, 248)], fill=(228, 236, 248, 255))
    apply_woodcut_hatch(img)
    return img


def draw_rel_forgemaster() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 165, 65), 190, 125)
    d = ImageDraw.Draw(img)
    # Heavy blacksmith anvil
    anvil_pts = [
        (90, 200), (355, 200), (425, 228), (335, 268),
        (335, 345), (378, 395), (134, 395), (178, 345),
        (178, 268), (112, 245)
    ]
    draw_poly_ink(d, anvil_pts, (108, 116, 128, 255), width=8)
    d.polygon([(115, 204), (350, 204), (335, 225), (125, 225)], fill=(178, 188, 204, 255))
    draw_sparkle(d, 260, 145, 28, (255, 195, 75, 255))
    draw_sparkle(d, 325, 165, 20, (255, 145, 55, 255))
    apply_woodcut_hatch(img)
    return img


def draw_rel_red_seal() -> Image.Image:
    img = new_canvas()
    add_aura(img, (240, 80, 75), 190, 125)
    d = ImageDraw.Draw(img)
    # Trailing ribbons
    draw_poly_ink(d, [(CX - 54, 275), (CX - 10, 275), (CX - 34, 425), (CX - 76, 395)], (175, 38, 38, 255), width=7)
    draw_poly_ink(d, [(CX + 10, 275), (CX + 54, 275), (CX + 76, 395), (CX + 34, 425)], (175, 38, 38, 255), width=7)
    # Wax medallion
    draw_circle_ink(d, CX, 215, 122, (218, 52, 48, 255), width=8)
    draw_circle_ink(d, CX, 215, 88, (182, 34, 34, 255), width=5)
    # Heart emblem inside
    draw_poly_ink(d, [(CX, 262), (CX - 42, 215), (CX - 22, 182), (CX, 202), (CX + 22, 182), (CX + 42, 215)], (255, 215, 175, 255), width=5)
    apply_woodcut_hatch(img)
    return img


def draw_rel_crimson_choir() -> Image.Image:
    img = new_canvas()
    add_aura(img, (245, 70, 105), 190, 125)
    d = ImageDraw.Draw(img)
    # Lyre arms & base
    draw_poly_ink(d, [(CX - 64, 345), (CX + 64, 345), (CX + 82, 395), (CX - 82, 395)], (218, 172, 62, 255), width=8)
    d.arc([CX - 125, 105, CX + 125, 375], 150, 390, fill=(228, 182, 68, 255), width=22)
    draw_poly_ink(d, [(CX - 108, 125), (CX + 108, 125), (CX + 108, 148), (CX - 108, 148)], (218, 172, 62, 255), width=7)
    for sx in range(CX - 54, CX + 55, 22):
        d.line([(sx, 148), (sx, 345)], fill=(255, 95, 125, 255), width=4)
    apply_woodcut_hatch(img)
    return img


def draw_rel_green_canopy() -> Image.Image:
    img = new_canvas()
    add_aura(img, (65, 215, 130), 190, 125)
    d = ImageDraw.Draw(img)
    # Three intertwined highland leaves
    for ang, col in [(-34, (48, 165, 92, 255)), (34, (48, 165, 92, 255)), (0, (72, 208, 125, 255))]:
        pts = [
            rot_pt(CX, CY + 135, ang), rot_pt(CX - 68, CY + 25, ang),
            rot_pt(CX - 48, CY - 95, ang), rot_pt(CX, CY - 155, ang),
            rot_pt(CX + 48, CY - 95, ang), rot_pt(CX + 68, CY + 25, ang),
        ]
        draw_poly_ink(d, pts, col, width=7)
        d.line([rot_pt(CX, CY + 135, ang), rot_pt(CX, CY - 135, ang)], fill=INK, width=4)
    apply_woodcut_hatch(img)
    return img


def draw_rel_prsi_purist() -> Image.Image:
    img = new_canvas()
    add_aura(img, (245, 200, 85), 190, 120)
    d = ImageDraw.Draw(img)
    # Handle
    d.arc([CX + 45, 185, CX + 138, 335], 270, 90, fill=(210, 168, 65, 255), width=22)
    # Oak tankard
    draw_poly_ink(d, [(CX - 82, 165), (CX + 78, 165), (CX + 88, 395), (CX - 92, 395)], (156, 98, 48, 255), width=8)
    for by in (205, 345):
        d.line([(CX - 85, by), (CX + 82, by)], fill=(215, 175, 72, 255), width=14)
    # Frothy foam
    for fx, fy, fr in [(CX - 55, 152, 34), (CX, 140, 42), (CX + 52, 152, 34)]:
        draw_circle_ink(d, fx, fy, fr, (248, 242, 224, 255), width=6)
    apply_woodcut_hatch(img)
    return img


def draw_rel_seven_grimoire() -> Image.Image:
    img = new_canvas()
    add_aura(img, (205, 115, 255), 190, 130)
    d = ImageDraw.Draw(img)
    draw_poly_ink(d, [(CX - 115, 95), (CX + 115, 95), (CX + 115, 415), (CX - 115, 415)], (86, 46, 122, 255), width=8)
    draw_poly_ink(d, [(CX - 115, 95), (CX - 76, 95), (CX - 76, 415), (CX - 115, 415)], (54, 26, 82, 255), width=7)
    d.rectangle([CX - 54, 135, CX + 92, 375], outline=(228, 185, 72, 255), width=5)
    # Glowing VII
    d.line([(CX - 25, 200), (CX, 285), (CX + 25, 200)], fill=(215, 145, 255, 255), width=10)
    d.line([(CX + 46, 200), (CX + 46, 285)], fill=(215, 145, 255, 255), width=10)
    d.line([(CX + 68, 200), (CX + 68, 285)], fill=(215, 145, 255, 255), width=10)
    apply_woodcut_hatch(img)
    return img


def draw_rel_merchant_ledger() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 215, 80), 190, 120)
    d = ImageDraw.Draw(img)
    # Unrolled parchment scroll
    draw_poly_ink(d, [(CX - 102, 115), (CX + 102, 115), (CX + 102, 395), (CX - 102, 395)], (236, 216, 172, 255), width=8)
    draw_poly_ink(d, [(CX - 122, 95), (CX + 122, 95), (CX + 122, 132), (CX - 122, 132)], (198, 152, 66, 255), width=7)
    draw_poly_ink(d, [(CX - 122, 378), (CX + 122, 378), (CX + 122, 415), (CX - 122, 415)], (198, 152, 66, 255), width=7)
    for ly in (175, 215, 255, 295, 335):
        d.line([(CX - 68, ly), (CX + 68, ly)], fill=(120, 88, 52, 220), width=5)
    draw_circle_ink(d, CX + 52, 325, 24, (248, 202, 58, 255), width=5)
    apply_woodcut_hatch(img)
    return img


def draw_rel_final_toll() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 60, 72), 195, 130)
    d = ImageDraw.Draw(img)
    # Heavy executioner's cleaver blade
    pts = [(CX - 34, 86), (CX + 68, 86), (CX + 78, 325), (CX - 28, 325)]
    draw_poly_ink(d, pts, (128, 136, 150, 255), width=8)
    d.polygon([(CX + 44, 86), (CX + 68, 86), (CX + 78, 325), (CX + 48, 325)], fill=(215, 224, 236, 255))
    draw_poly_ink(d, [(CX - 16, 325), (CX + 18, 325), (CX + 18, 425), (CX - 16, 425)], (98, 56, 32, 255), width=7)
    # Crimson oath ribbon
    d.line([(CX - 95, 165), (CX + 115, 265)], fill=(225, 35, 55, 255), width=18)
    apply_woodcut_hatch(img)
    return img


def draw_rel_court_sovereign() -> Image.Image:
    img = new_canvas()
    add_aura(img, (255, 215, 70), 195, 130)
    d = ImageDraw.Draw(img)
    # Sovereign crown
    pts = [
        (CX - 125, 335), (CX - 142, 165), (CX - 64, 235), (CX, 125),
        (CX + 64, 235), (CX + 142, 165), (CX + 125, 335)
    ]
    draw_poly_ink(d, pts, (242, 198, 56, 255), width=8)
    draw_poly_ink(d, [(CX - 128, 335), (CX + 128, 335), (CX + 128, 378), (CX - 128, 378)], (210, 162, 42, 255), width=8)
    for gx, col in [(CX - 68, (55, 175, 245, 255)), (CX, (225, 38, 62, 255)), (CX + 68, (55, 175, 245, 255))]:
        draw_circle_ink(d, gx, 356, 14, col, width=4)
    apply_woodcut_hatch(img)
    return img


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    jobs: dict[str, Image.Image] = {
        # 5 Blades
        "SWORD_IRON.png": draw_sword((214, 222, 234, 255), (144, 154, 168, 255), (168, 124, 52, 255), (92, 54, 32, 255), (188, 145, 68, 255), (185, 200, 220), "iron"),
        "SWORD_GILDED.png": draw_sword((238, 242, 252, 255), (175, 185, 202, 255), (242, 194, 62, 255), (125, 28, 34, 255), (245, 205, 72, 255), (255, 215, 85), "gilded"),
        "SWORD_CRIMSON.png": draw_sword((115, 92, 102, 255), (68, 52, 60, 255), (195, 138, 52, 255), (48, 16, 20, 255), (208, 152, 58, 255), (255, 45, 65), "crimson"),
        "SWORD_RUNE.png": draw_sword((172, 218, 248, 255), (108, 158, 204, 255), (138, 165, 198, 255), (36, 52, 78, 255), (150, 185, 220, 255), (75, 230, 255), "rune"),
        "SWORD_DRAGON.png": draw_sword((76, 54, 50, 255), (48, 34, 30, 255), (225, 156, 52, 255), (68, 22, 14, 255), (235, 165, 56, 255), (255, 120, 30), "dragon"),

        # 10 Table Relics
        "TRELIC_SOUL_BELL.png": draw_trelic_soul_bell(),
        "TRELIC_BLOOD_SEAL.png": draw_trelic_blood_seal(),
        "TRELIC_STAR_BOW.png": draw_trelic_star_bow(),
        "TRELIC_ASH_GLASS.png": draw_trelic_ash_glass(),
        "TRELIC_WAR_HORN.png": draw_trelic_war_horn(),
        "TRELIC_HOLLOW_MASK.png": draw_trelic_hollow_mask(),
        "TRELIC_CENSER.png": draw_trelic_censer(),
        "TRELIC_GOLD_SCALES.png": draw_trelic_gold_scales(),
        "TRELIC_IRON_CHAIN.png": draw_trelic_iron_chain(),
        "TRELIC_PHOENIX_BOX.png": draw_trelic_phoenix_box(),

        # 21 Visible Passive Relics
        "REL_FUJARA.png": draw_rel_fujara(),
        "REL_KNUCKLE.png": draw_rel_knuckle(),
        "REL_PHOENIX_F.png": draw_rel_phoenix_f(),
        "REL_FANG.png": draw_rel_fang(),
        "REL_GREED.png": draw_rel_greed(),
        "REL_ALEMBIC.png": draw_rel_alembic(),
        "REL_ROYAL.png": draw_rel_royal(),
        "REL_CHRONO_P.png": draw_rel_chrono_p(),
        "REL_HEX_DOLL.png": draw_rel_hex_doll(),
        "REL_IRON_BOOT.png": draw_rel_iron_boot(),
        "REL_OVERCHARGE.png": draw_rel_overcharge(),
        "REL_WOODCUTTER.png": draw_rel_woodcutter(),
        "REL_FORGEMASTER.png": draw_rel_forgemaster(),
        "REL_RED_SEAL.png": draw_rel_red_seal(),
        "REL_CRIMSON_CHOIR.png": draw_rel_crimson_choir(),
        "REL_GREEN_CANOPY.png": draw_rel_green_canopy(),
        "REL_PRSI_PURIST.png": draw_rel_prsi_purist(),
        "REL_SEVEN_GRIMOIRE.png": draw_rel_seven_grimoire(),
        "REL_MERCHANT_LEDGER.png": draw_rel_merchant_ledger(),
        "REL_FINAL_TOLL.png": draw_rel_final_toll(),
        "REL_COURT_SOVEREIGN.png": draw_rel_court_sovereign(),
    }

    for fname, im in jobs.items():
        path = OUT_DIR / fname
        im.save(path, format="PNG")
    print(f"Generated {len(jobs)} 512x512 woodcut PNGs in {OUT_DIR}")


if __name__ == "__main__":
    main()
