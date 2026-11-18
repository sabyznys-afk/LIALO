"""Konverzia vygenerovaných JPG assetov -> PNG s priehľadnosťou (magenta key) pre DOWNPOUR."""
import sys, glob, os
from PIL import Image

BRAIN = r"C:\Users\arnos\.gemini\antigravity\brain\2d118d48-87cb-48d3-9fcd-0a243d3e2458"
ASSETS = r"D:\downpour-godot\assets"

def find(prefix):
    files = sorted(glob.glob(os.path.join(BRAIN, prefix + "_*.jpg")) + glob.glob(os.path.join(BRAIN, prefix + "_*.png")))
    return files[-1] if files else None

def key_magenta(img, crop=True):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # vzdialenosť od magenty; mäkký okraj
            mag = min(r, b) - g
            if mag > 120:
                px[x, y] = (r, g, b, 0)
            elif mag > 60:
                alpha = int(255 * (1 - (mag - 60) / 60))
                # odfarbenie magenta lemu
                px[x, y] = (min(r, g + 40), g, min(b, g + 40), alpha)
    if crop:
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
    return img

# (prefix, cieľ, keying, max_size)
JOBS = [
    ("menu_bg", r"lobby\menu_bg.png", False, None),
    ("menu_bg_stredovek", r"lobby\menu_bg_stredovek.png", False, None),
    ("title_downpour", r"lobby\title_downpour.png", True, None),
    ("title_lialo", r"lobby\title_lialo.png", True, None),
    ("sign_wood_locked", r"lobby\sign_wood_locked.png", True, None),
    ("sign_wood", r"lobby\sign_wood.png", True, None),
    ("map_ground", r"map\map_ground.png", False, None),
    ("map_frame", r"map\map_frame.png", "frame", None),
    ("compass_needle", r"map\compass_needle.png", True, 512),
    ("mountain_rock", r"map\mountain_rock.png", False, 1024),
    ("tree_foliage", r"map\tree_foliage.png", False, 1024),
    ("era_icons", r"map\era_icons.png", True, None),
    ("table_wood", r"table\wood.png", False, 1024),
    ("table_felt", r"table\felt.png", False, 1024),
    ("card_back", r"table\card_back.png", False, None),
    ("stone_floor", r"table\stone_floor.png", False, 1024),
    ("glove_leather_fine", r"gloves\glove_leather.png", False, 1024),
    ("glove_iron", r"gloves\glove_iron.png", False, 1024),
]

only = set(sys.argv[1:])
for prefix, dest, keying, max_size in JOBS:
    if only and prefix not in only:
        continue
    src = find(prefix)
    if prefix == "sign_wood":
        # nechytiť sign_wood_locked
        cands = [f for f in glob.glob(os.path.join(BRAIN, "sign_wood_*.jpg")) if "locked" not in f]
        src = sorted(cands)[-1] if cands else None
    if not src:
        print("CHÝBA:", prefix)
        continue
    img = Image.open(src)
    if keying == "frame":
        img = key_magenta(img, crop=False)
    elif keying:
        img = key_magenta(img, crop=True)
    else:
        img = img.convert("RGB")
    if max_size:
        img.thumbnail((max_size, max_size))
    out = os.path.join(ASSETS, dest)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out)
    print("OK", prefix, "->", out, img.size)
