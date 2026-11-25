"""Generate 64x64 dark-fantasy woodcut/brass/parchment UI icons for LIALO.
Replaces all system/Unicode emojis across the UI with cohesive hand-crafted icons.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "ui", "icons")
SIZE = 64

INK = (26, 20, 16, 255)
INK_SOFT = (46, 36, 28, 220)
BRASS = (214, 172, 92, 255)
BRASS_HI = (244, 212, 138, 255)
BRASS_DK = (138, 102, 46, 255)
PARCHMENT = (232, 216, 184, 255)
CRIMSON = (196, 54, 48, 255)
CRIMSON_HI = (236, 98, 78, 255)
EMERALD = (74, 168, 112, 255)
AZURE = (92, 166, 216, 255)
FLAME_CORE = (255, 226, 128, 255)
SHADOW = (10, 8, 6, 140)


def new_canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def add_woodcut_rim(img: Image.Image) -> Image.Image:
    # Subtle drop shadow for contrast on dark panels
    alpha = img.split()[3]
    shadow = Image.new("RGBA", (SIZE, SIZE), SHADOW)
    shadow_mask = alpha.filter(ImageFilter.GaussianBlur(1.4))
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(shadow, (1, 2), shadow_mask)
    out = Image.alpha_composite(out, img)
    return out


def draw_poly_outline(d: ImageDraw.ImageDraw, pts, fill, outline=INK, width=2):
    d.polygon(pts, fill=fill)
    d.line(list(pts) + [pts[0]], fill=outline, width=width, joint="curve")


def icon_sword(d: ImageDraw.ImageDraw):
    # Diagonal broadsword
    blade = [(48, 10), (54, 10), (54, 16), (26, 44), (20, 38)]
    draw_poly_outline(d, blade, PARCHMENT, INK, 2)
    d.line([(49, 15), (24, 40)], fill=BRASS_DK, width=2)
    # Crossguard
    guard = [(14, 34), (18, 30), (34, 46), (30, 50)]
    draw_poly_outline(d, guard, BRASS, INK, 2)
    # Grip + Pommel
    d.line([(21, 43), (13, 51)], fill=BRASS_DK, width=5)
    d.ellipse([9, 47, 17, 55], fill=BRASS_HI, outline=INK, width=2)


def icon_dagger(d: ImageDraw.ImageDraw):
    blade = [(44, 14), (50, 14), (48, 22), (28, 42), (22, 36)]
    draw_poly_outline(d, blade, PARCHMENT, INK, 2)
    guard = [(17, 34), (21, 30), (34, 43), (30, 47)]
    draw_poly_outline(d, guard, BRASS, INK, 2)
    d.line([(23, 41), (15, 49)], fill=BRASS_DK, width=4)
    d.ellipse([11, 45, 19, 53], fill=CRIMSON, outline=INK, width=2)


def icon_shield(d: ImageDraw.ImageDraw):
    pts = [(14, 12), (50, 12), (50, 32), (32, 54), (14, 32)]
    draw_poly_outline(d, pts, BRASS_DK, INK, 3)
    inner = [(18, 16), (46, 16), (46, 31), (32, 49), (18, 31)]
    draw_poly_outline(d, inner, BRASS, INK, 2)
    d.line([(32, 16), (32, 48)], fill=INK, width=2)
    d.line([(18, 28), (46, 28)], fill=INK, width=2)


def icon_hourglass(d: ImageDraw.ImageDraw):
    # Frame bars
    d.rectangle([16, 10, 48, 15], fill=BRASS, outline=INK, width=2)
    d.rectangle([16, 49, 48, 54], fill=BRASS, outline=INK, width=2)
    # Glass bulbs
    top = [(20, 15), (44, 15), (34, 32), (30, 32)]
    bot = [(30, 32), (34, 32), (44, 49), (20, 49)]
    draw_poly_outline(d, top, PARCHMENT, INK, 2)
    draw_poly_outline(d, bot, PARCHMENT, INK, 2)
    # Sand
    d.polygon([(25, 22), (39, 22), (32, 31)], fill=BRASS_HI)
    d.polygon([(23, 48), (41, 48), (32, 39)], fill=BRASS)


def icon_bolt(d: ImageDraw.ImageDraw):
    pts = [(36, 8), (18, 34), (30, 34), (24, 56), (46, 28), (34, 28)]
    draw_poly_outline(d, pts, BRASS_HI, INK, 2)


def icon_redraw(d: ImageDraw.ImageDraw):
    d.arc([12, 12, 52, 52], start=35, end=310, fill=BRASS, width=6)
    d.arc([12, 12, 52, 52], start=35, end=310, fill=INK, width=2)
    # Arrowhead
    draw_poly_outline(d, [(44, 10), (54, 20), (40, 24)], BRASS_HI, INK, 2)


def icon_gear(d: ImageDraw.ImageDraw):
    cx, cy = 32, 32
    pts = []
    for i in range(16):
        ang = i * math.pi / 8.0
        r = 22 if i % 2 == 0 else 16
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw_poly_outline(d, pts, BRASS, INK, 2)
    d.ellipse([23, 23, 41, 41], fill=INK, outline=BRASS_HI, width=2)
    d.ellipse([27, 27, 37, 37], fill=(0, 0, 0, 0), outline=BRASS_DK, width=1)


def icon_fire(d: ImageDraw.ImageDraw):
    outer = [(32, 8), (44, 22), (48, 36), (42, 50), (32, 54), (20, 50), (16, 36), (22, 22)]
    draw_poly_outline(d, outer, CRIMSON, INK, 2)
    mid = [(32, 18), (40, 30), (38, 48), (26, 48), (24, 30)]
    draw_poly_outline(d, mid, BRASS_HI, INK, 1)
    d.ellipse([27, 36, 37, 48], fill=FLAME_CORE)


def icon_crown(d: ImageDraw.ImageDraw):
    pts = [(10, 44), (10, 20), (22, 32), (32, 14), (42, 32), (54, 20), (54, 44)]
    draw_poly_outline(d, pts, BRASS_HI, INK, 2)
    d.rectangle([10, 44, 54, 50], fill=BRASS_DK, outline=INK, width=2)
    for x, y in [(10, 18), (32, 12), (54, 18)]:
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=CRIMSON_HI, outline=INK, width=1)


def icon_cards(d: ImageDraw.ImageDraw):
    # Back card tilted
    c1 = [(14, 16), (38, 12), (44, 44), (20, 48)]
    draw_poly_outline(d, c1, BRASS_DK, INK, 2)
    # Front card
    c2 = [(24, 16), (50, 16), (50, 52), (24, 52)]
    draw_poly_outline(d, c2, PARCHMENT, INK, 2)
    d.rectangle([28, 20, 46, 48], outline=BRASS_DK, width=1)
    d.polygon([(37, 27), (42, 34), (37, 41), (32, 34)], fill=CRIMSON)


def icon_mist(d: ImageDraw.ImageDraw):
    for y, x0, x1 in [(20, 12, 48), (30, 16, 52), (40, 10, 44), (48, 20, 50)]:
        d.line([(x0, y), (x1, y)], fill=INK, width=6)
        d.line([(x0, y), (x1, y)], fill=PARCHMENT, width=3)


def icon_tavern(d: ImageDraw.ImageDraw):
    # Archway / tavern roof
    roof = [(8, 28), (32, 10), (56, 28)]
    draw_poly_outline(d, roof, BRASS, INK, 2)
    d.rectangle([14, 28, 50, 52], fill=PARCHMENT, outline=INK, width=2)
    # Door
    d.pieslice([24, 34, 40, 54], 180, 360, fill=BRASS_DK, outline=INK, width=2)
    d.rectangle([24, 42, 40, 52], fill=BRASS_DK, outline=INK, width=2)


def icon_scroll(d: ImageDraw.ImageDraw):
    d.rectangle([16, 14, 48, 50], fill=PARCHMENT, outline=INK, width=2)
    d.rectangle([12, 10, 52, 16], fill=BRASS, outline=INK, width=2)
    d.rectangle([12, 48, 52, 54], fill=BRASS, outline=INK, width=2)
    for y in (24, 32, 40):
        d.line([(22, y), (42, y)], fill=INK_SOFT, width=2)


def icon_coin(d: ImageDraw.ImageDraw):
    d.ellipse([12, 12, 52, 52], fill=BRASS, outline=INK, width=3)
    d.ellipse([17, 17, 47, 47], fill=BRASS_HI, outline=BRASS_DK, width=2)
    d.polygon([(32, 23), (38, 32), (32, 41), (26, 32)], fill=BRASS_DK, outline=INK)


def icon_blood(d: ImageDraw.ImageDraw):
    pts = [(32, 10), (46, 34), (44, 46), (32, 54), (20, 46), (18, 34)]
    draw_poly_outline(d, pts, CRIMSON, INK, 2)
    d.ellipse([24, 34, 32, 44], fill=CRIMSON_HI)


def icon_check(d: ImageDraw.ImageDraw):
    pts = [(12, 34), (18, 28), (27, 38), (46, 16), (52, 22), (27, 50)]
    draw_poly_outline(d, pts, EMERALD, INK, 2)


def icon_cross(d: ImageDraw.ImageDraw):
    d.line([(16, 16), (48, 48)], fill=INK, width=9)
    d.line([(48, 16), (16, 48)], fill=INK, width=9)
    d.line([(16, 16), (48, 48)], fill=CRIMSON_HI, width=5)
    d.line([(48, 16), (16, 48)], fill=CRIMSON_HI, width=5)


def icon_star(d: ImageDraw.ImageDraw):
    cx, cy = 32, 32
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5.0
        r = 22 if i % 2 == 0 else 9
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw_poly_outline(d, pts, BRASS_HI, INK, 2)


def icon_diamond(d: ImageDraw.ImageDraw):
    pts = [(32, 10), (52, 32), (32, 54), (12, 32)]
    draw_poly_outline(d, pts, BRASS_HI, INK, 2)
    inner = [(32, 18), (44, 32), (32, 46), (20, 32)]
    draw_poly_outline(d, inner, BRASS, INK, 1)


def icon_dice(d: ImageDraw.ImageDraw):
    d.rounded_rectangle([12, 12, 52, 52], radius=8, fill=PARCHMENT, outline=INK, width=3)
    for x, y in [(22, 22), (42, 22), (32, 32), (22, 42), (42, 42)]:
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=INK)


def icon_trophy(d: ImageDraw.ImageDraw):
    cup = [(18, 12), (46, 12), (42, 34), (32, 40), (22, 34)]
    draw_poly_outline(d, cup, BRASS_HI, INK, 2)
    d.arc([10, 14, 22, 28], 90, 270, fill=BRASS, width=3)
    d.arc([42, 14, 54, 28], 270, 90, fill=BRASS, width=3)
    d.rectangle([29, 39, 35, 48], fill=BRASS, outline=INK, width=2)
    d.rectangle([20, 48, 44, 54], fill=BRASS_DK, outline=INK, width=2)


def icon_players(d: ImageDraw.ImageDraw):
    for cx, fill in [(23, BRASS_DK), (41, BRASS_HI)]:
        d.ellipse([cx - 7, 14, cx + 7, 28], fill=fill, outline=INK, width=2)
        d.pieslice([cx - 12, 28, cx + 12, 52], 180, 360, fill=fill, outline=INK, width=2)


def icon_lock(d: ImageDraw.ImageDraw):
    d.arc([20, 10, 44, 34], 180, 360, fill=BRASS, width=5)
    d.rectangle([16, 26, 48, 52], fill=BRASS_DK, outline=INK, width=2)
    d.ellipse([29, 34, 35, 40], fill=INK)


def icon_unlock(d: ImageDraw.ImageDraw):
    d.arc([26, 8, 50, 32], 180, 360, fill=BRASS, width=5)
    d.rectangle([14, 26, 46, 52], fill=EMERALD, outline=INK, width=2)
    d.ellipse([27, 34, 33, 40], fill=INK)


def icon_seal(d: ImageDraw.ImageDraw):
    # Wax / Grand Seal crest
    cx, cy = 32, 32
    pts = []
    for i in range(16):
        ang = i * math.pi / 8.0
        r = 22 if i % 2 == 0 else 19
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw_poly_outline(d, pts, CRIMSON, INK, 2)
    d.ellipse([18, 18, 46, 46], fill=BRASS_DK, outline=BRASS_HI, width=2)
    d.polygon([(32, 21), (41, 32), (32, 43), (23, 32)], fill=BRASS_HI, outline=INK)


def icon_relic(d: ImageDraw.ImageDraw):
    # Ornate chalice / relic
    d.polygon([(20, 14), (44, 14), (38, 32), (26, 32)], fill=BRASS_HI, outline=INK)
    d.rectangle([29, 32, 35, 46], fill=BRASS, outline=INK, width=2)
    d.rectangle([20, 46, 44, 52], fill=BRASS_DK, outline=INK, width=2)
    d.ellipse([29, 20, 35, 26], fill=CRIMSON)


def icon_sound_on(d: ImageDraw.ImageDraw):
    draw_poly_outline(d, [(12, 26), (22, 26), (34, 14), (34, 50), (22, 38), (12, 38)], BRASS, INK, 2)
    d.arc([32, 20, 44, 44], 300, 60, fill=BRASS_HI, width=3)
    d.arc([34, 14, 52, 50], 300, 60, fill=BRASS_HI, width=3)


def icon_sound_off(d: ImageDraw.ImageDraw):
    draw_poly_outline(d, [(12, 26), (22, 26), (34, 14), (34, 50), (22, 38), (12, 38)], BRASS_DK, INK, 2)
    d.line([(38, 24), (52, 40)], fill=CRIMSON_HI, width=4)
    d.line([(52, 24), (38, 40)], fill=CRIMSON_HI, width=4)


def icon_sort(d: ImageDraw.ImageDraw):
    for y, w in [(18, 36), (32, 26), (46, 16)]:
        d.rectangle([14, y - 3, 14 + w, y + 3], fill=BRASS_HI, outline=INK, width=2)


def icon_help(d: ImageDraw.ImageDraw):
    d.ellipse([12, 12, 52, 52], fill=BRASS_DK, outline=INK, width=3)
    d.arc([22, 18, 42, 34], 180, 45, fill=PARCHMENT, width=4)
    d.line([(32, 32), (32, 38)], fill=PARCHMENT, width=4)
    d.ellipse([29, 42, 35, 48], fill=BRASS_HI)


def icon_globe(d: ImageDraw.ImageDraw):
    d.ellipse([12, 12, 52, 52], fill=AZURE, outline=INK, width=3)
    d.ellipse([22, 12, 42, 52], outline=INK, width=2)
    d.line([(12, 32), (52, 32)], fill=INK, width=2)
    d.line([(16, 22), (48, 22)], fill=INK, width=1)
    d.line([(16, 42), (48, 42)], fill=INK, width=1)


def icon_warning(d: ImageDraw.ImageDraw):
    draw_poly_outline(d, [(32, 10), (54, 50), (10, 50)], BRASS_HI, INK, 3)
    d.line([(32, 23), (32, 37)], fill=INK, width=4)
    d.ellipse([29, 41, 35, 47], fill=INK)


def icon_heart(d: ImageDraw.ImageDraw):
    d.ellipse([14, 16, 33, 35], fill=CRIMSON, outline=INK, width=2)
    d.ellipse([31, 16, 50, 35], fill=CRIMSON, outline=INK, width=2)
    d.polygon([(15, 29), (49, 29), (32, 52)], fill=CRIMSON)
    d.line([(15, 29), (32, 52), (49, 29)], fill=INK, width=2)


def icon_leaves(d: ImageDraw.ImageDraw):
    pts = [(32, 10), (46, 24), (44, 42), (32, 46), (20, 42), (18, 24)]
    draw_poly_outline(d, pts, EMERALD, INK, 2)
    d.line([(32, 46), (32, 54)], fill=INK, width=3)


def icon_acorn(d: ImageDraw.ImageDraw):
    d.ellipse([18, 24, 46, 52], fill=BRASS, outline=INK, width=2)
    d.pieslice([14, 14, 50, 34], 180, 360, fill=BRASS_DK, outline=INK, width=2)
    d.line([(32, 8), (32, 16)], fill=INK, width=3)


def icon_bell(d: ImageDraw.ImageDraw):
    d.ellipse([16, 14, 48, 46], fill=BRASS_HI, outline=INK, width=2)
    d.line([(16, 30), (48, 30)], fill=INK, width=2)
    d.ellipse([29, 36, 35, 42], fill=INK)


ICONS = {
    "sound_on": icon_sound_on,
    "sound_off": icon_sound_off,
    "sword": icon_sword,
    "hourglass": icon_hourglass,
    "bolt": icon_bolt,
    "dagger": icon_dagger,
    "redraw": icon_redraw,
    "gear": icon_gear,
    "fire": icon_fire,
    "crown": icon_crown,
    "cards": icon_cards,
    "mist": icon_mist,
    "tavern": icon_tavern,
    "scroll": icon_scroll,
    "coin": icon_coin,
    "blood": icon_blood,
    "shield": icon_shield,
    "check": icon_check,
    "cross": icon_cross,
    "star": icon_star,
    "diamond": icon_diamond,
    "dice": icon_dice,
    "trophy": icon_trophy,
    "players": icon_players,
    "lock": icon_lock,
    "unlock": icon_unlock,
    "seal": icon_seal,
    "relic": icon_relic,
    "sort": icon_sort,
    "help": icon_help,
    "globe": icon_globe,
    "warning": icon_warning,
    "heart": icon_heart,
    "leaves": icon_leaves,
    "acorn": icon_acorn,
    "bell": icon_bell,
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in ICONS.items():
        img = new_canvas()
        d = ImageDraw.Draw(img)
        fn(d)
        final_img = add_woodcut_rim(img)
        final_img.save(os.path.join(OUT_DIR, f"icon_{name}.png"))
    print(f"Generated {len(ICONS)} woodcut UI icons in {OUT_DIR}")


if __name__ == "__main__":
    main()
