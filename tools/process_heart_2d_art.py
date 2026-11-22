#!/usr/bin/env python3
"""Post-process the 2D medieval illuminated heart illustrations into transparent 512x512 UI sprites
and synthesize a matching branching fracture mask for HP-driven glowing cracks."""

import math
import os
import random
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PLAYER_RAW = r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\heart_2d_player_raw_1795184906765.jpg"
BOSS_RAW = r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\heart_2d_boss_raw_1795184916695.jpg"

OUT_DIR = r"D:\downpour-godot\assets\ui"
PLAYER_OUT = os.path.join(OUT_DIR, "heart_2d_player.png")
BOSS_OUT = os.path.join(OUT_DIR, "heart_2d_boss.png")
CRACKS_OUT = os.path.join(OUT_DIR, "heart_2d_cracks.png")


def extract_silhouette_rgba(img_path: str, out_path: str, out_size: int = 512, fill_frac: float = 0.88) -> None:
    img = Image.open(img_path).convert("RGB")
    arr = np.asarray(img, dtype=np.uint8)
    h, w, _ = arr.shape

    # Seal thin dark ink borders (<=3px gaps) before exterior flood-fill so interior black ink never leaks transparent
    lum = np.max(arr, axis=2)
    fg_raw = (lum > 24).astype(np.uint8) * 255
    fg_sealed = Image.fromarray(fg_raw, mode="L").filter(ImageFilter.MaxFilter(size=5)).filter(ImageFilter.MinFilter(size=5))
    sealed_wall = np.asarray(fg_sealed, dtype=np.uint8) > 128

    bg_mask = np.zeros((h, w), dtype=bool)
    q = deque()

    def try_seed(y: int, x: int) -> None:
        if not bg_mask[y, x] and not sealed_wall[y, x] and lum[y, x] <= 24:
            bg_mask[y, x] = True
            q.append((y, x))

    for x in range(w):
        try_seed(0, x)
        try_seed(h - 1, x)
    for y in range(h):
        try_seed(y, 0)
        try_seed(y, w - 1)

    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not bg_mask[ny, nx]:
                if (not sealed_wall[ny, nx]) and lum[ny, nx] <= 28:
                    bg_mask[ny, nx] = True
                    q.append((ny, nx))

    # Expand bg cleanly into immediately adjacent near-black halo pixels outside the sealed silhouette
    for _pass in range(2):
        padded = np.pad(bg_mask, 1, mode="edge")
        nbr_bg = padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
        bg_mask = bg_mask | (nbr_bg & (lum <= 22))

    alpha = np.where(bg_mask, 0, 255).astype(np.uint8)

    # Anti-aliased soft edge feathering on the outer boundary ring
    alpha_img = Image.fromarray(alpha, mode="L")
    alpha_blur = alpha_img.filter(ImageFilter.GaussianBlur(radius=1.15))
    ab_arr = np.asarray(alpha_blur, dtype=np.float32)

    # Smooth transition strictly near boundary: keep interior rock-solid 255, outer 0
    fg = ~bg_mask
    soft_a = np.where(fg, np.clip((ab_arr - 55.0) * (255.0 / 160.0), 0.0, 255.0), 0.0)
    # Restore inner solid pixels (more than 2px from bg) to 255
    eroded = alpha_img.filter(ImageFilter.MinFilter(size=5))
    solid_inner = np.asarray(eroded, dtype=np.uint8) > 128
    final_a = np.where(solid_inner, 255.0, soft_a).astype(np.uint8)

    # Gently lift border RGB against black background premultiply
    rgb = arr.astype(np.float32)
    edge_band = (final_a > 12) & (final_a < 245) & fg
    scale = np.where(edge_band, np.clip(255.0 / np.maximum(final_a.astype(np.float32), 90.0), 1.0, 2.0), 1.0)
    rgb = np.clip(rgb * scale[:, :, None], 0.0, 255.0).astype(np.uint8)

    rgba = np.dstack([rgb, final_a])
    res_img = Image.fromarray(rgba, mode="RGBA")

    # Tight bbox crop with square centering on 512x512 canvas
    bbox = res_img.getbbox()
    if bbox:
        res_img = res_img.crop(bbox)
    cw, ch = res_img.size
    target_dim = int(round(out_size * fill_frac))
    scale_f = float(target_dim) / float(max(cw, ch))
    nw = max(1, int(round(cw * scale_f)))
    nh = max(1, int(round(ch * scale_f)))
    res_img = res_img.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (out_size, out_size), (0, 0, 0, 0))
    ox = (out_size - nw) // 2
    oy = (out_size - nh) // 2
    canvas.paste(res_img, (ox, oy), res_img)
    canvas.save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path} ({out_size}x{out_size}, sprite={nw}x{nh})")


def build_crack_mask(out_path: str, size: int = 512) -> None:
    rng = random.Random(20261120)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    cx, cy = size * 0.50, size * 0.49

    def trace_branch(x: float, y: float, angle: float, steps: int, step_len: float, width: float, depth: int) -> None:
        if depth > 2 or steps <= 0:
            return
        cur_x, cur_y = x, y
        cur_a = angle
        for s in range(steps):
            cur_a += rng.uniform(-0.42, 0.42)
            nx = cur_x + math.cos(cur_a) * step_len
            ny = cur_y + math.sin(cur_a) * step_len
            # Stay cleanly inside inner heart chamber (~33% radius)
            if math.hypot(nx - cx, ny - cy) > size * 0.31:
                break
            w_now = max(1, int(round(width * (1.0 - 0.55 * (s / max(1, steps))))))
            intensity = int(round(255 * (1.0 - 0.25 * depth)))
            draw.line([(cur_x, cur_y), (nx, ny)], fill=intensity, width=w_now)
            if depth < 2 and s >= 2 and rng.random() < 0.34:
                fork_dir = rng.choice((-1.0, 1.0)) * rng.uniform(0.45, 0.95)
                trace_branch(nx, ny, cur_a + fork_dir, max(3, steps - s - 1), step_len * 0.85, max(1.0, width * 0.65), depth + 1)
            cur_x, cur_y = nx, ny

    for root_i in range(7):
        base_a = (root_i / 7.0) * math.tau + rng.uniform(-0.2, 0.2)
        trace_branch(cx + math.cos(base_a) * 14.0, cy + math.sin(base_a) * 14.0, base_a, 11, 14.5, 4.2, 0)

    # Combine crisp crack lines with subtle radial glow halo in RGB+A
    glow = mask.filter(ImageFilter.GaussianBlur(radius=3.5))
    m_arr = np.asarray(mask, dtype=np.float32)
    g_arr = np.asarray(glow, dtype=np.float32)
    combined = np.clip(np.maximum(m_arr, g_arr * 0.65), 0.0, 255.0).astype(np.uint8)
    rgba = np.dstack([combined, combined, combined, combined])
    Image.fromarray(rgba, mode="RGBA").save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path} ({size}x{size})")


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    extract_silhouette_rgba(PLAYER_RAW, PLAYER_OUT, 512, 0.88)
    extract_silhouette_rgba(BOSS_RAW, BOSS_OUT, 512, 0.92)
    build_crack_mask(CRACKS_OUT, 512)


if __name__ == "__main__":
    main()
