"""
Processes the 8 newly generated museum-grade card back artworks into crisp 540x810 RGBA full-bleed PNGs
in D:/downpour-godot/assets/table/deck_back_<id>.png (and updates card_back.png from klasic).
"""
import pathlib
import shutil
from PIL import Image, ImageDraw, ImageEnhance

ART_DIR = pathlib.Path(r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d")
OUT_DIR = pathlib.Path(r"D:\downpour-godot\assets\table")
OUT_W, OUT_H = 540, 810

# (deck_id, source_filename, crop_frac=(left, top, right, bottom), edge_color)
SPECS = [
    ("klasic",     "deck_back_klasic_raw_1795191014513.jpg",     (0.005, 0.005, 0.995, 0.995), (36, 22, 12, 255)),
    ("antika",     "deck_back_antika_raw_1795190955023.jpg",     (0.036, 0.025, 0.964, 0.975), (20, 24, 34, 255)),
    ("rim",        "deck_back_rim_raw_1795190975337.jpg",        (0.045, 0.036, 0.955, 0.964), (58, 22, 16, 255)),
    ("stredovek",  "deck_back_stredovek_raw_1795190987052.jpg",  (0.038, 0.026, 0.962, 0.974), (24, 28, 26, 255)),
    ("objavy",     "deck_back_objavy_raw_1795190934577.jpg",     (0.008, 0.008, 0.992, 0.992), (16, 36, 46, 255)),
    ("prohibicia", "deck_back_prohibicia_raw_1795190947576.jpg", (0.024, 0.018, 0.976, 0.982), (16, 14, 12, 255)),
    ("reaper",     "deck_back_reaper_raw_1795191007744.jpg",     (0.022, 0.018, 0.978, 0.982), (14, 10, 12, 255)),
    ("quincy",     "deck_back_quincy_raw_1795190968184.jpg",     (0.010, 0.010, 0.990, 0.990), (14, 24, 48, 255)),
]


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for deck_id, fname, (l, t, r, b), edge_col in SPECS:
        src = ART_DIR / fname
        if not src.exists():
            raise FileNotFoundError(f"Missing generated art: {src}")
        im = Image.open(src).convert("RGBA")
        w, h = im.size
        box = (int(round(w * l)), int(round(h * t)), int(round(w * r)), int(round(h * b)))
        cropped = im.crop(box)
        # Preserve exact 2:3 framing via clean centered aspect crop then LANCZOS resize
        cw, ch = cropped.size
        target_ratio = OUT_W / OUT_H
        cur_ratio = cw / ch
        if cur_ratio > target_ratio:
            nw = int(round(ch * target_ratio))
            x0 = (cw - nw) // 2
            cropped = cropped.crop((x0, 0, x0 + nw, ch))
        elif cur_ratio < target_ratio:
            nh = int(round(cw / target_ratio))
            y0 = (ch - nh) // 2
            cropped = cropped.crop((0, y0, cw, y0 + nh))
        final_im = cropped.resize((OUT_W, OUT_H), Image.Resampling.LANCZOS)
        # Gentle crispness boost + ultra-thin dark artisanal bleed rim so 3D card edges never show white pixels
        final_im = ImageEnhance.Sharpness(final_im).enhance(1.12)
        draw = ImageDraw.Draw(final_im)
        for inset in range(3):
            draw.rectangle([inset, inset, OUT_W - 1 - inset, OUT_H - 1 - inset], outline=edge_col)
        dst = OUT_DIR / f"deck_back_{deck_id}.png"
        final_im.save(dst, "PNG", optimize=True)
        print(f"SAVED {dst} ({final_im.size[0]}x{final_im.size[1]})")

    shutil.copy2(OUT_DIR / "deck_back_klasic.png", OUT_DIR / "card_back.png")
    print(f"UPDATED {OUT_DIR / 'card_back.png'}")


if __name__ == "__main__":
    main()
