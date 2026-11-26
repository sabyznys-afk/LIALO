#!/usr/bin/env python3
"""Generate distinct hand-inked dark woodcut Multiplayer Tavern Arena backdrop (mp_arena_bg.png)."""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(r"D:\downpour-godot")
OUT_PATH = ROOT / "assets" / "ui" / "mp_arena_bg.png"
RNG = np.random.default_rng(1904)


def main() -> None:
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    W, H = 1920, 1080
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H

    # Deep slate-obsidian cathedral tavern hall with warm ember glow near lower center & torch recesses
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[..., 0] = 24.0 + 18.0 * np.exp(-((u - 0.5) / 0.42) ** 2) * np.exp(-((v - 0.72) / 0.48) ** 2)
    arr[..., 1] = 20.0 + 10.0 * np.exp(-((u - 0.5) / 0.45) ** 2) * np.exp(-((v - 0.75) / 0.52) ** 2)
    arr[..., 2] = 28.0 + 12.0 * (1.0 - v)

    # Stone masonry block grid shading + vignette
    brick_y = np.floor(v * 14.0)
    brick_x = np.floor(u * 16.0 + (brick_y % 2) * 0.5)
    mortar_y = np.abs((v * 14.0) - np.round(v * 14.0)) < 0.045
    mortar_x = np.abs((u * 16.0 + (brick_y % 2) * 0.5) - np.round(u * 16.0 + (brick_y % 2) * 0.5)) < 0.035
    stone_shade = 1.0 + 0.12 * np.sin(brick_x * 2.1 + brick_y * 3.7)
    arr *= stone_shade[..., None]
    arr *= np.where((mortar_y | mortar_x)[..., None], 0.62, 1.0)

    vig = 1.0 - 0.55 * ((u - 0.5) ** 2 + (v - 0.5) ** 2)
    arr *= vig[..., None]
    arr += RNG.normal(0.0, 3.2, (H, W, 1)).astype(np.float32)

    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (10, 8, 12)
    gold_dim = (92, 68, 32)
    crimson_dim = (84, 24, 26)

    # 3 Vaulted Gothic Dueling Arches in depth
    for ax in (W // 4, W // 2, 3 * W // 4):
        aw = 240
        draw.arc([ax - aw, 110, ax + aw, 640], start=180, end=360, fill=ink, width=10)
        draw.arc([ax - aw + 18, 128, ax + aw - 18, 622], start=180, end=360, fill=gold_dim, width=3)
        draw.line([(ax - aw, 375), (ax - aw, H)], fill=ink, width=12)
        draw.line([(ax + aw, 375), (ax + aw, H)], fill=ink, width=12)

    # Distant Hanging Crimson Arena Banners on flanking pillars
    for bx in (260, W - 260):
        draw.polygon([(bx - 64, 150), (bx + 64, 150), (bx + 58, 560), (bx, 620), (bx - 58, 560)], fill=crimson_dim, outline=ink)
        draw.line([(bx - 64, 150), (bx + 64, 150)], fill=gold_dim, width=6)
        draw.line([(bx, 180), (bx, 560)], fill=gold_dim, width=3)

    # Distant Overhead Iron Chandelier Silhouette
    cx, cy = W // 2, 110
    draw.line([(cx, 0), (cx, cy)], fill=ink, width=10)
    draw.ellipse([cx - 210, cy - 26, cx + 210, cy + 44], outline=ink, width=12)
    draw.ellipse([cx - 206, cy - 22, cx + 206, cy + 40], outline=gold_dim, width=3)

    # Lower foreground oak dueling gallery rail silhouette
    draw.rectangle([0, H - 150, W, H], fill=(16, 11, 9), outline=ink, width=4)
    draw.line([(0, H - 150), (W, H - 150)], fill=gold_dim, width=3)

    # Hand-inked diagonal woodcut hatch shadows in upper corners
    for d in range(0, 480, 18):
        draw.line([(0, d), (d, 0)], fill=ink, width=2)
        draw.line([(W, d), (W - d, 0)], fill=ink, width=2)

    img.save(OUT_PATH, "PNG")
    print(f"Generated {OUT_PATH} ({OUT_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
