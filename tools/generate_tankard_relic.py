#!/usr/bin/env python3
"""Generate ultra-detailed hand-drawn 3D prototype for TRELIC_WAR_HORN (Tavern Ale Tankard).

Outputs:
  - assets/textures/relics/tankard_oak_ink.png    (1024x1024)
  - assets/textures/relics/tankard_brass_ink.png  (1024x1024)
  - assets/textures/relics/tankard_crest_ink.png  (512x512)
  - assets/textures/relics/tankard_foam_ink.png   (1024x1024)
  - assets/models/relics/TRELIC_WAR_HORN.glb      (multi-mesh glTF 2.0 with baked vertex AO)
"""

from __future__ import annotations

import json
import math
import os
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(r"D:\downpour-godot")
TEX_DIR = ROOT / "assets" / "textures" / "relics"
MODEL_PATH = ROOT / "assets" / "models" / "relics" / "TRELIC_WAR_HORN.glb"

RNG = np.random.default_rng(4207)


def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


# ==============================================================================
# 1. HAND-INKED WOODCUT TEXTURES (PIL + NumPy)
# ==============================================================================

def _add_paper_grain(arr: np.ndarray, strength: float = 0.03) -> np.ndarray:
    h, w, _ = arr.shape
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    wave = (
        np.sin(x * 0.09 + y * 0.04) * 0.5
        + np.cos(y * 0.11 - x * 0.03) * 0.5
    ) * (strength * 255.0)
    noise = RNG.normal(0.0, strength * 95.0, (h, w, 1)).astype(np.float32)
    out = arr.astype(np.float32) + wave[..., None] + noise
    return np.clip(out, 0, 255).astype(np.uint8)


def generate_oak_texture(path: Path) -> None:
    W, H = 1024, 1024
    # Base warm aged oak wash
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([124.0, 80.0, 48.0], dtype=np.float32)

    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u = x / W
    v = y / H

    # 14 distinct staves with slight per-plank value & hue variation
    stave_f = u * 14.0
    stave_idx = np.floor(stave_f).astype(np.int32)
    stave_u = stave_f - stave_idx

    plank_shifts = np.array([
        0.92, 1.06, 0.96, 1.09, 0.89, 1.03, 0.95,
        1.08, 0.91, 1.04, 0.97, 1.10, 0.90, 1.02
    ], dtype=np.float32)
    arr *= plank_shifts[stave_idx % 14][..., None]

    # Woodgrain flow per stave + organic swirl
    phase = (stave_idx * 1.73) % 6.28
    grain_field = (
        np.sin((stave_u * 9.0 + np.sin(v * 7.5 + phase) * 0.75) * math.pi) * 0.5
        + np.sin((stave_u * 23.0 + np.cos(v * 14.0 + phase * 1.3) * 0.45) * math.pi) * 0.3
    )
    arr[..., 0] += grain_field * 14.0
    arr[..., 1] += grain_field * 9.0
    arr[..., 2] += grain_field * 5.0

    # Vertical ink seams between adjacent oak staves
    seam_dist = np.minimum(stave_u, 1.0 - stave_u)
    seam_mask = np.clip(1.0 - seam_dist / 0.065, 0.0, 1.0)
    arr *= (1.0 - seam_mask[..., None] * 0.76)

    # Darkened contact shadows + ink wear near top & bottom & hoop seats (v=0.14, 0.45, 0.82)
    for hy, hw, ds in [(0.14, 0.09, 0.42), (0.47, 0.08, 0.36), (0.81, 0.09, 0.44), (0.98, 0.06, 0.32)]:
        band = np.exp(-((v - hy) / hw) ** 2)
        arr *= (1.0 - band[..., None] * ds)

    img = Image.fromarray(_add_paper_grain(arr, 0.028), mode="RGB")
    draw = ImageDraw.Draw(img)

    # Hand-inked burin woodgrain curves, knotholes & short hoop contact hatch marks
    ink = (30, 18, 12)
    ink_soft = (56, 35, 22)
    for si in range(14):
        sx0 = int(si * W / 14)
        sx1 = int((si + 1) * W / 14)
        cx = (sx0 + sx1) // 2
        # Vertical stave ink border
        draw.line([(sx0, 0), (sx0, H)], fill=ink, width=3)
        # Sketchy parallel grain strokes inside each plank
        for gi in range(5):
            off = int((gi - 2) * 11 + RNG.integers(-3, 4))
            pts = []
            for py in range(0, H + 32, 32):
                wob = int(math.sin(py * 0.014 + si * 1.4 + gi) * 5.0)
                pts.append((max(sx0 + 3, min(sx1 - 3, cx + off + wob)), py))
            draw.line(pts, fill=ink_soft, width=2 if gi == 2 else 1)

        # Occasional hand-drawn oak knot on alternate staves
        if si % 3 == 1:
            ky = int((0.28 + (si * 0.19) % 0.42) * H)
            kx = cx + int(RNG.integers(-10, 11))
            for kr in (14, 9, 4):
                draw.ellipse([kx - kr // 2, ky - kr, kx + kr // 2, ky + kr], outline=ink, width=2)

        # Crosshatch ink strokes around the 3 brass hoop grooves
        for hy in (int(0.14 * H), int(0.47 * H), int(0.81 * H)):
            for hx in range(sx0 + 6, sx1 - 4, 7):
                h_len = int(RNG.integers(14, 26))
                draw.line([(hx, hy - h_len), (hx + 4, hy + h_len)], fill=ink, width=1)

    img.save(path, "PNG")


def generate_brass_texture(path: Path) -> None:
    W, H = 1024, 1024
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([204.0, 152.0, 62.0], dtype=np.float32)

    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u = x / W
    v = y / H

    # Hammered metal dimple cellular pattern + aged bronze patina along edges
    dimples = (
        np.sin(u * 38.0 + np.cos(v * 29.0) * 1.4)
        * np.cos(v * 34.0 - np.sin(u * 23.0) * 1.4)
    )
    arr[..., 0] += dimples * 18.0
    arr[..., 1] += dimples * 15.0
    arr[..., 2] += dimples * 8.0

    # Warm bronze edge patina near v=0 and v=1 (band rims)
    edge = np.exp(-((v - 0.5) * 2.0) ** 4)
    patina = 1.0 - edge
    arr[..., 0] = arr[..., 0] * (1.0 - 0.36 * patina) + 52.0 * patina
    arr[..., 1] = arr[..., 1] * (1.0 - 0.24 * patina) + 48.0 * patina
    arr[..., 2] = arr[..., 2] * (1.0 - 0.22 * patina) + 34.0 * patina

    img = Image.fromarray(_add_paper_grain(arr, 0.025), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (42, 28, 16)
    hi = (248, 224, 154)

    # Double hand-inked border lines along hoop rims
    for ry in (44, 68, H - 68, H - 44):
        pts = [(px, ry + int(math.sin(px * 0.03) * 2.0)) for px in range(0, W + 16, 16)]
        draw.line(pts, fill=ink, width=3)
    # Brushed painterly highlight streaks along center belly
    for sy in range(180, H - 180, 64):
        pts = [(px, sy + int(math.cos(px * 0.02 + sy) * 3.0)) for px in range(0, W + 32, 32)]
        draw.line(pts, fill=hi, width=2)
    # Subtle hammered pen-dot stipples
    for _ in range(420):
        px = int(RNG.integers(8, W - 8))
        py = int(RNG.integers(80, H - 80))
        r = int(RNG.integers(2, 5))
        draw.arc([px - r, py - r, px + r, py + r], start=20, end=195, fill=ink, width=1)

    img.save(path, "PNG")


def generate_crest_texture(path: Path) -> None:
    W, H = 512, 512
    img = Image.new("RGB", (W, H), (222, 184, 96))
    draw = ImageDraw.Draw(img)

    ink = (26, 18, 14)
    crimson = (146, 36, 34)
    cream = (238, 222, 186)
    gold = (224, 174, 68)

    # Quartered shield interior
    draw.rectangle([0, 0, W // 2, H // 2], fill=crimson)
    draw.rectangle([W // 2, H // 2, W, H], fill=crimson)
    draw.rectangle([W // 2, 0, W, H // 2], fill=cream)
    draw.rectangle([0, H // 2, W // 2, H], fill=cream)

    # Diagonal woodcut hatching on crimson quarters
    for d in range(-256, 512, 12):
        draw.line([(max(0, d), 0), (min(W // 2, d + 256), min(H // 2, 256))], fill=(72, 16, 16), width=2)
        draw.line([(W // 2 + max(0, d), H // 2), (W // 2 + min(W // 2, d + 256), H)], fill=(72, 16, 16), width=2)

    # Crossbars & ornate beveled brass frame
    draw.line([(W // 2, 0), (W // 2, H)], fill=ink, width=8)
    draw.line([(0, H // 2), (W, H // 2)], fill=ink, width=8)
    draw.rectangle([10, 10, W - 11, H - 11], outline=ink, width=14)
    draw.rectangle([26, 26, W - 27, H - 27], outline=gold, width=6)

    # Central inked tavern chalice emblem
    cx, cy = W // 2, H // 2
    cup = [(cx - 56, cy - 58), (cx + 56, cy - 58), (cx + 32, cy + 8), (cx - 32, cy + 8)]
    draw.polygon(cup, fill=gold, outline=ink)
    draw.line(cup + [cup[0]], fill=ink, width=6)
    draw.rectangle([cx - 10, cy + 8, cx + 10, cy + 56], fill=gold, outline=ink, width=5)
    base = [(cx - 42, cy + 78), (cx + 42, cy + 78), (cx + 26, cy + 54), (cx - 26, cy + 54)]
    draw.polygon(base, fill=gold, outline=ink)
    draw.line(base + [base[0]], fill=ink, width=6)
    # 3-pointed crown above chalice
    crown = [(cx - 40, cy - 72), (cx - 46, cy - 106), (cx - 18, cy - 86), (cx, cy - 114),
             (cx + 18, cy - 86), (cx + 46, cy - 106), (cx + 40, cy - 72)]
    draw.polygon(crown, fill=gold, outline=ink)
    draw.line(crown + [crown[0]], fill=ink, width=5)

    arr = _add_paper_grain(np.array(img), 0.025)
    Image.fromarray(arr, mode="RGB").save(path, "PNG")


def generate_foam_texture(path: Path) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u = x / W
    v = y / H

    # Creamy ivory highlight at top (v=0..0.65) -> warm amber ale bleed near lower drip tips (v=0.75..1.0)
    top_col = np.array([248.0, 239.0, 214.0], dtype=np.float32)
    amber_col = np.array([218.0, 146.0, 56.0], dtype=np.float32)
    blend = np.clip((v - 0.62) / 0.36, 0.0, 1.0)[..., None]
    arr = top_col * (1.0 - blend) + amber_col * blend

    cloud = (
        np.sin(u * 26.0 + np.cos(v * 21.0) * 1.5)
        * np.cos(v * 24.0 + np.sin(u * 19.0) * 1.5)
    )
    arr -= np.clip(-cloud, 0.0, 1.0)[..., None] * 18.0

    img = Image.fromarray(_add_paper_grain(arr, 0.018), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink_sepia = (128, 96, 60)
    ink_dark = (72, 48, 28)

    # Hand-drawn bubbly foam rings + crisp ink shading arcs
    for _ in range(260):
        bx = int(RNG.integers(14, W - 14))
        by = int(RNG.integers(14, H - 14))
        br = int(RNG.integers(5, 22))
        col = ink_dark if br >= 15 else ink_sepia
        draw.arc([bx - br, by - br, bx + br, by + br], start=15, end=235, fill=col, width=2 if br >= 14 else 1)
        if br >= 14:
            draw.ellipse([bx - br + 2, by - br + 2, bx - br + 7, by - br + 7], fill=(255, 252, 244))

    img.save(path, "PNG")


# ==============================================================================
# 2. MESH BUILDER & VERTEX AO / GLB PACKER
# ==============================================================================

class MeshData:
    def __init__(self, name: str):
        self.name = name
        self.positions: list[tuple[float, float, float]] = []
        self.normals: list[tuple[float, float, float]] = []
        self.uvs: list[tuple[float, float]] = []
        self.colors: list[tuple[float, float, float, float]] = []
        self.indices: list[int] = []

    def add_vertex(
        self,
        pos: tuple[float, float, float],
        norm: tuple[float, float, float],
        uv: tuple[float, float],
        ao: float = 1.0,
    ) -> int:
        idx = len(self.positions)
        nx, ny, nz = norm
        ln = math.sqrt(nx * nx + ny * ny + nz * nz)
        if ln > 1e-8:
            norm = (nx / ln, ny / ln, nz / ln)
        else:
            norm = (0.0, 1.0, 0.0)
        self.positions.append(pos)
        self.normals.append(norm)
        self.uvs.append(uv)
        ao = _clamp01(ao)
        self.colors.append((ao, ao, ao, 1.0))
        return idx

    def add_tri(self, a: int, b: int, c: int, flip: bool = False) -> None:
        if flip:
            self.indices.extend((a, c, b))
        else:
            self.indices.extend((a, b, c))

    def add_quad(self, i00: int, i10: int, i11: int, i01: int, flip: bool = False) -> None:
        # CCW: (0,0) -> (1,0) -> (1,1) and (0,0) -> (1,1) -> (0,1)
        self.add_tri(i00, i10, i11, flip=flip)
        self.add_tri(i00, i11, i01, flip=flip)

    def enforce_outward_winding_from_normals(self) -> int:
        flipped = 0
        for ti in range(0, len(self.indices), 3):
            ia, ib, ic = self.indices[ti], self.indices[ti + 1], self.indices[ti + 2]
            pa, pb, pc = self.positions[ia], self.positions[ib], self.positions[ic]
            e1 = (pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2])
            e2 = (pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2])
            fn = (
                e1[1] * e2[2] - e1[2] * e2[1],
                e1[2] * e2[0] - e1[0] * e2[2],
                e1[0] * e2[1] - e1[1] * e2[0],
            )
            na, nb, nc = self.normals[ia], self.normals[ib], self.normals[ic]
            n_avg = (na[0] + nb[0] + nc[0], na[1] + nb[1] + nc[1], na[2] + nb[2] + nc[2])
            if fn[0] * n_avg[0] + fn[1] * n_avg[1] + fn[2] * n_avg[2] < 0.0:
                self.indices[ti + 1], self.indices[ti + 2] = ic, ib
                flipped += 1
        return flipped

    def recompute_smooth_normals(self, weld_positions: bool = True) -> None:
        # Weighted area normals with optional spatial position welding across UV seams
        n_arr = np.zeros((len(self.positions), 3), dtype=np.float64)
        p_arr = np.array(self.positions, dtype=np.float64)
        for ti in range(0, len(self.indices), 3):
            ia, ib, ic = self.indices[ti], self.indices[ti + 1], self.indices[ti + 2]
            e1 = p_arr[ib] - p_arr[ia]
            e2 = p_arr[ic] - p_arr[ia]
            fn = np.cross(e1, e2)
            n_arr[ia] += fn
            n_arr[ib] += fn
            n_arr[ic] += fn
        if weld_positions:
            buckets: dict[tuple[int, int, int], np.ndarray] = {}
            for vi, p in enumerate(self.positions):
                key = (round(p[0] * 20000.0), round(p[1] * 20000.0), round(p[2] * 20000.0))
                if key in buckets:
                    buckets[key] = buckets[key] + n_arr[vi]
                else:
                    buckets[key] = n_arr[vi].copy()
            for vi, p in enumerate(self.positions):
                key = (round(p[0] * 20000.0), round(p[1] * 20000.0), round(p[2] * 20000.0))
                n_arr[vi] = buckets[key]
        lens = np.linalg.norm(n_arr, axis=1, keepdims=True)
        lens = np.where(lens > 1e-9, lens, 1.0)
        n_arr /= lens
        self.normals = [tuple(map(float, row)) for row in n_arr]


def _tankard_profile_r(y_frac: float) -> float:
    """Classic curved medieval wooden barrel tankard silhouette (y in 0..1)."""
    # Bottom skirt -> belly bulge at 0.34 -> slight waist at 0.72 -> gently flared lip
    if y_frac < 0.36:
        t = y_frac / 0.36
        return 0.0325 + 0.0062 * math.sin(t * math.pi * 0.5)
    t = (y_frac - 0.36) / 0.64
    return 0.0387 - 0.0062 * math.sin(t * math.pi * 0.78) + 0.0018 * (t ** 2)


def _hoop_ao(y_abs: float) -> float:
    """Crevice AO shadow cast onto oak staves beneath the 3 iron/brass bands."""
    ao = 1.0
    for hy, hw in [(0.015, 0.007), (0.048, 0.0065), (0.083, 0.007)]:
        d = abs(y_abs - hy)
        if d < hw * 1.8:
            ao = min(ao, 0.34 + 0.66 * (d / (hw * 1.8)) ** 1.4)
    return ao


def build_oak_staves(H: float = 0.098) -> MeshData:
    md = MeshData("OakStaves")
    n_staves = 14
    y_steps = 16
    wall_t = 0.0052
    inner_bot = 0.016

    # Build 14 individual chamfered oak barrel staves around full circle (visible seams!)
    for si in range(n_staves):
        a0 = (si / n_staves) * math.tau
        a1 = ((si + 1) / n_staves) * math.tau
        gap = 0.014  # distinct groove angle between adjacent planks
        chamfer = 0.016
        # Cross-section angles across width of stave (left groove -> left bevel -> flat face -> right bevel -> right groove)
        ang_samples = [
            (a0 + gap * 0.35, 0.87, 0.28),          # recessed groove left
            (a0 + gap * 0.35 + chamfer, 0.992, 0.78),
            (a0 + (a1 - a0) * 0.36, 1.00, 1.00),
            (a0 + (a1 - a0) * 0.64, 1.00, 1.00),
            (a1 - gap * 0.35 - chamfer, 0.992, 0.78),
            (a1 - gap * 0.35, 0.87, 0.28),          # recessed groove right
        ]

        # Subtle hand-crafted top stave height ripple (+/- 0.7mm)
        top_jit = 0.0007 * math.sin(si * 2.3 + 0.5)
        grid_idx: list[list[int]] = []

        for yi in range(y_steps + 1):
            yf = yi / y_steps
            y_abs = yf * (H + top_jit * yf)
            r_base = _tankard_profile_r(yf)
            ao_hoop = _hoop_ao(y_abs)
            # Darken under top foam lip
            ao_foam = 0.45 + 0.55 * _clamp01((0.96 - yf) / 0.14) if yf > 0.82 else 1.0
            row_ids = []
            for ai, (ang, r_mul, ao_groove) in enumerate(ang_samples):
                r = r_base * r_mul
                px = r * math.cos(ang)
                pz = r * math.sin(ang)
                # Outward normal including bevel tilt on side edges
                n_tilt = (-0.38 if ai == 0 else (-0.16 if ai == 1 else (0.16 if ai == 4 else (0.38 if ai == 5 else 0.0))))
                ca, sa = math.cos(ang + n_tilt), math.sin(ang + n_tilt)
                norm = (ca, 0.04, sa)
                u_coord = (si + ai / (len(ang_samples) - 1)) / float(n_staves)
                ao = min(ao_hoop, ao_foam) * ao_groove
                row_ids.append(md.add_vertex((px, y_abs, pz), norm, (u_coord, 1.0 - yf), ao))
            grid_idx.append(row_ids)

        for yi in range(y_steps):
            for ai in range(len(ang_samples) - 1):
                # +Y up and +theta goes clockwise from +X to +Z, so flip=True gives outward normals
                md.add_quad(
                    grid_idx[yi][ai],
                    grid_idx[yi][ai + 1],
                    grid_idx[yi + 1][ai + 1],
                    grid_idx[yi + 1][ai],
                    flip=False,
                )

    # Smooth wooden top rim ring + deep inner oak cavity wall + bottom disk
    rim_segs = 56
    rim_top_y = H
    prev_out: list[int] = []
    prev_in_top: list[int] = []
    prev_in_bot: list[int] = []
    for ri in range(rim_segs + 1):
        ang = (ri / rim_segs) * math.tau
        r_out = _tankard_profile_r(1.0) * 0.99
        r_in = r_out - wall_t
        ca, sa = math.cos(ang), math.sin(ang)
        u_c = ri / rim_segs
        prev_out.append(md.add_vertex((r_out * ca, rim_top_y, r_out * sa), (0.0, 1.0, 0.0), (u_c, 0.02), 0.72))
        prev_in_top.append(md.add_vertex((r_in * ca, rim_top_y, r_in * sa), (-ca * 0.4, 0.85, -sa * 0.4), (u_c, 0.08), 0.45))
        prev_in_bot.append(md.add_vertex((r_in * ca * 0.9, inner_bot, r_in * sa * 0.9), (-ca, 0.1, -sa), (u_c, 0.88), 0.25))

    for ri in range(rim_segs):
        md.add_quad(prev_out[ri], prev_out[ri + 1], prev_in_top[ri + 1], prev_in_top[ri], flip=False)
        md.add_quad(prev_in_top[ri], prev_in_top[ri + 1], prev_in_bot[ri + 1], prev_in_bot[ri], flip=False)

    # Bottom wooden base cap
    c_bot = md.add_vertex((0.0, 0.0, 0.0), (0.0, -1.0, 0.0), (0.5, 0.5), 0.25)
    bot_ring: list[int] = []
    r_bot = _tankard_profile_r(0.0) * 0.96
    for ri in range(rim_segs + 1):
        ang = (ri / rim_segs) * math.tau
        bot_ring.append(md.add_vertex((r_bot * math.cos(ang), 0.0, r_bot * math.sin(ang)), (0.0, -1.0, 0.0), (0.5 + 0.4 * math.cos(ang), 0.5 + 0.4 * math.sin(ang)), 0.35))
    for ri in range(rim_segs):
        md.add_tri(c_bot, bot_ring[ri], bot_ring[ri + 1], flip=True)

    return md


def _add_chamfered_box_to(
    md: MeshData,
    cx: float, cy: float, cz: float,
    hx: float, hy: float, hz: float,
    ao: float = 0.85,
    rot_z: float = 0.0,
) -> None:
    """Append an oriented rectangular plate/strap into MeshData with clean per-face UVs."""
    cz_r, sz_r = math.cos(rot_z), math.sin(rot_z)

    def xform(lx: float, ly: float, lz: float) -> tuple[float, float, float]:
        rx = lx * cz_r - ly * sz_r
        ry = lx * sz_r + ly * cz_r
        return (cx + rx, cy + ry, cz + lz)

    def xform_n(lx: float, ly: float, lz: float) -> tuple[float, float, float]:
        rx = lx * cz_r - ly * sz_r
        ry = lx * sz_r + ly * cz_r
        return (rx, ry, lz)

    faces = [
        ((0, 0, 1), (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)),
        ((0, 0, -1), (hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz)),
        ((1, 0, 0), (hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz)),
        ((-1, 0, 0), (-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)),
        ((0, 1, 0), (-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz), (-hx, hy, -hz)),
        ((0, -1, 0), (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)),
    ]
    for n, p0, p1, p2, p3 in faces:
        nm = xform_n(*n)
        i0 = md.add_vertex(xform(*p0), nm, (0.05, 0.95), ao)
        i1 = md.add_vertex(xform(*p1), nm, (0.95, 0.95), ao)
        i2 = md.add_vertex(xform(*p2), nm, (0.95, 0.05), ao)
        i3 = md.add_vertex(xform(*p3), nm, (0.05, 0.05), ao)
        md.add_quad(i0, i1, i2, i3, flip=True)


def _add_domed_rivet_to(md: MeshData, center: tuple[float, float, float], normal: tuple[float, float, float], radius: float = 0.0021, height: float = 0.0018) -> None:
    nx, ny, nz = normal
    ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    up = (0.0, 1.0, 0.0) if abs(ny) < 0.9 else (1.0, 0.0, 0.0)
    # Build tangent frame
    tx = up[1] * nz - up[2] * ny
    ty = up[2] * nx - up[0] * nz
    tz = up[0] * ny - up[1] * nx
    tl = math.sqrt(tx * tx + ty * ty + tz * tz) or 1.0
    tx, ty, tz = tx / tl, ty / tl, tz / tl
    bx = ny * tz - nz * ty
    by = nz * tx - nx * tz
    bz = nx * ty - ny * tx

    segs = 10
    ring_base: list[int] = []
    ring_mid: list[int] = []
    for i in range(segs + 1):
        a = (i / segs) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        vx = ca * tx + sa * bx
        vy = ca * ty + sa * by
        vz = ca * tz + sa * bz
        ring_base.append(md.add_vertex(
            (center[0] + vx * radius, center[1] + vy * radius, center[2] + vz * radius),
            (vx * 0.8 + nx * 0.4, vy * 0.8 + ny * 0.4, vz * 0.8 + nz * 0.4),
            (0.5 + 0.35 * ca, 0.5 + 0.35 * sa),
            0.38,  # dark collar shadow around rivet!
        ))
        r_m = radius * 0.64
        ring_mid.append(md.add_vertex(
            (center[0] + vx * r_m + nx * height * 0.72, center[1] + vy * r_m + ny * height * 0.72, center[2] + vz * r_m + nz * height * 0.72),
            (vx * 0.4 + nx * 0.88, vy * 0.4 + ny * 0.88, vz * 0.4 + nz * 0.88),
            (0.5 + 0.22 * ca, 0.5 + 0.22 * sa),
            0.94,
        ))
    tip = md.add_vertex((center[0] + nx * height, center[1] + ny * height, center[2] + nz * height), (nx, ny, nz), (0.5, 0.5), 1.0)
    for i in range(segs):
        md.add_quad(ring_base[i], ring_base[i + 1], ring_mid[i + 1], ring_mid[i], flip=True)
        md.add_tri(ring_mid[i], ring_mid[i + 1], tip, flip=True)


def build_brass_hoops(H: float = 0.098) -> MeshData:
    md = MeshData("BrassHoops")
    segs = 56
    # 3 chamfered hammered-brass bands: base rim, center waist band, top rim collar
    bands = [
        (0.015, 0.0085, 0.0022),
        (0.048, 0.0076, 0.0021),
        (0.083, 0.0082, 0.0022),
    ]
    for cy, band_h, thick in bands:
        y_bot = cy - band_h * 0.5
        y_top = cy + band_h * 0.5
        r_in_bot = _tankard_profile_r(y_bot / H) * 0.985
        r_in_top = _tankard_profile_r(y_top / H) * 0.985
        r_mid = (_tankard_profile_r(cy / H) + thick)

        rows_prof = [
            (y_bot, r_in_bot, -0.7, 0.36),
            (y_bot + band_h * 0.14, r_mid * 0.995, -0.18, 0.78),
            (cy, r_mid * 1.005, 0.0, 1.00),
            (y_top - band_h * 0.14, r_mid * 0.995, 0.18, 0.82),
            (y_top, r_in_top, 0.7, 0.36),
        ]

        grid: list[list[int]] = []
        for pi, (py, pr, ny_t, ao_v) in enumerate(rows_prof):
            row_ids: list[int] = []
            for si in range(segs + 1):
                ang = (si / segs) * math.tau
                hammer = 1.0 + 0.009 * math.sin(ang * 9.0 + cy * 90.0)
                r = pr * hammer
                ca, sa = math.cos(ang), math.sin(ang)
                row_ids.append(md.add_vertex((r * ca, py, r * sa), (ca, ny_t, sa), (si / float(segs), pi / 4.0), ao_v))
            grid.append(row_ids)
        for pi in range(len(rows_prof) - 1):
            for si in range(segs):
                md.add_quad(grid[pi][si], grid[pi][si + 1], grid[pi + 1][si + 1], grid[pi + 1][si], flip=False)

        # 12 domed brass rivets per band (skip front crest zone around +Z and handle around +X slightly avoided naturally)
        for ri in range(12):
            ang = (ri / 12.0) * math.tau + 0.18
            # Skip front shield area on mid band
            if abs(cy - 0.048) < 0.01 and abs(math.atan2(math.cos(ang), math.sin(ang))) < 0.42:
                continue
            r = (_tankard_profile_r(cy / H) + thick) * 1.002
            ca, sa = math.cos(ang), math.sin(ang)
            _add_domed_rivet_to(md, (r * ca, cy, r * sa), (ca, 0.0, sa), radius=0.0019, height=0.0016)

        # Forged lap clasp plate on left (-X) side for authentic barrel craftsmanship
        r_clasp = _tankard_profile_r(cy / H) + thick + 0.0014
        _add_chamfered_box_to(md, -r_clasp, cy, 0.0, 0.0016, band_h * 0.56, 0.0065, ao=0.88)
        _add_domed_rivet_to(md, (-r_clasp - 0.0014, cy, -0.0032), (-1.0, 0.0, 0.0), radius=0.0015, height=0.0013)
        _add_domed_rivet_to(md, (-r_clasp - 0.0014, cy, 0.0032), (-1.0, 0.0, 0.0), radius=0.0015, height=0.0013)

    # Top & Bottom forged handle mounting strap brackets (+X side)
    for strap_y in (0.016, 0.083):
        r_st = _tankard_profile_r(strap_y / H) + 0.0028
        _add_chamfered_box_to(md, r_st, strap_y, 0.0, 0.0026, 0.0062, 0.0075, ao=0.82)
        _add_domed_rivet_to(md, (r_st + 0.0025, strap_y, -0.0042), (1.0, 0.0, 0.0), radius=0.0017, height=0.0014)
        _add_domed_rivet_to(md, (r_st + 0.0025, strap_y, 0.0042), (1.0, 0.0, 0.0), radius=0.0017, height=0.0014)

    # Curled brass thumb-rest spur atop the handle junction (14-step smooth ornate scroll)
    thumb_pts: list[tuple[float, float, float]] = []
    thumb_rad: list[float] = []
    t_steps = 13
    for ti in range(t_steps + 1):
        u = ti / t_steps
        if u < 0.55:
            s = u / 0.55
            px = 0.036 + s * 0.0155
            py = 0.084 + math.sin(s * math.pi * 0.5) * 0.015
            rad = 0.0033 + 0.0005 * math.sin(s * math.pi)
        else:
            s = (u - 0.55) / 0.45
            ang = s * math.pi * 1.45
            c_rad = 0.0046 * (1.0 - 0.35 * s)
            px = 0.0472 + math.cos(ang) * c_rad
            py = 0.1012 + math.sin(ang) * c_rad
            rad = 0.0028 * (1.0 - 0.48 * s)
        thumb_pts.append((px, py, 0.0))
        thumb_rad.append(rad)
    _add_swept_tube_to(md, thumb_pts, thumb_rad, segs=12, aspect_z=1.35)

    return md


def _add_swept_tube_to(
    md: MeshData,
    pts: list[tuple[float, float, float]],
    radii: list[float],
    segs: int = 10,
    aspect_z: float = 1.0,
) -> None:
    rings: list[list[int]] = []
    n_pts = len(pts)
    for pi, p in enumerate(pts):
        if pi == 0:
            tan = (pts[1][0] - p[0], pts[1][1] - p[1], pts[1][2] - p[2])
        elif pi == n_pts - 1:
            tan = (p[0] - pts[pi - 1][0], p[1] - pts[pi - 1][1], p[2] - pts[pi - 1][2])
        else:
            tan = (pts[pi + 1][0] - pts[pi - 1][0], pts[pi + 1][1] - pts[pi - 1][1], pts[pi + 1][2] - pts[pi - 1][2])
        tl = math.sqrt(tan[0] ** 2 + tan[1] ** 2 + tan[2] ** 2) or 1.0
        tx, ty, tz = tan[0] / tl, tan[1] / tl, tan[2] / tl

        # Robust frame in XY plane since handles sweep in XY (Z is constant lateral)
        bx, by, bz = 0.0, 0.0, 1.0
        nx = ty * bz - tz * by
        ny = tz * bx - tx * bz
        nz = tx * by - ty * bx
        nl = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        nx, ny, nz = nx / nl, ny / nl, nz / nl

        r = radii[pi]
        v_c = pi / max(1, n_pts - 1)
        ring: list[int] = []
        for si in range(segs + 1):
            a = (si / segs) * math.tau
            ca, sa = math.cos(a), math.sin(a)
            # Slightly chamfered octagonal feel via radius modulation
            chamf = 1.0 - 0.06 * abs(math.sin(a * 2.0))
            dx = (nx * ca + bx * sa * aspect_z) * r * chamf
            dy = (ny * ca + by * sa * aspect_z) * r * chamf
            dz = (nz * ca + bz * sa * aspect_z) * r * chamf
            ao_v = 0.55 if (pi == 0 or pi == n_pts - 1) else (0.78 + 0.22 * max(0.0, ca * 0.5 + 0.5))
            ring.append(md.add_vertex((p[0] + dx, p[1] + dy, p[2] + dz), (nx * ca + bx * sa, ny * ca + by * sa, nz * ca + bz * sa), (si / float(segs), v_c * 2.5), ao_v))
        rings.append(ring)

    for pi in range(n_pts - 1):
        for si in range(segs):
            md.add_quad(rings[pi][si], rings[pi][si + 1], rings[pi + 1][si + 1], rings[pi + 1][si], flip=True)

    # End caps
    c0 = md.add_vertex(pts[0], (-1.0, 0.0, 0.0), (0.5, 0.5), 0.5)
    c1 = md.add_vertex(pts[-1], (0.0, 1.0, 0.0), (0.5, 0.5), 0.9)
    for si in range(segs):
        md.add_tri(c0, rings[0][si], rings[0][si + 1], flip=False)
        md.add_tri(c1, rings[-1][si], rings[-1][si + 1], flip=True)


def build_scroll_handle() -> MeshData:
    md = MeshData("ScrollHandle")
    # Graceful 24-segment curved oak tavern S-scroll handle (+X side)
    pts: list[tuple[float, float, float]] = []
    rads: list[float] = []
    steps = 22
    for i in range(steps + 1):
        t = i / steps
        # Upper attachment at (0.034, 0.082) bowing cleanly out to x=0.067 around mid-height, returning to (0.035, 0.016)
        y = 0.082 - t * 0.066 - math.sin(t * math.pi * 2.0) * 0.0025
        bulge = math.sin(t * math.pi)
        s_curve = math.sin(t * math.pi * 2.0) * 0.0055
        x = 0.034 + 0.031 * (bulge ** 0.78) + s_curve
        pts.append((x, y, 0.0))
        r = 0.0048 + 0.0020 * math.sin(t * math.pi)
        rads.append(r)
    _add_swept_tube_to(md, pts, rads, segs=10, aspect_z=1.22)
    return md


def build_heraldic_crest(H: float = 0.098) -> MeshData:
    md = MeshData("HeraldicCrest")
    # Curved shield crest plaque hugging the front (+Z) oak barrel belly
    cy = 0.049
    w_segs, h_segs = 10, 12
    crest_w = 0.029
    crest_h = 0.034

    def shield_half_w(v01: float) -> float:
        # 0 = top rim, 1 = pointed bottom tip of medieval kite shield
        if v01 < 0.45:
            return 1.0
        t = (v01 - 0.45) / 0.55
        return max(0.08, math.cos(t * math.pi * 0.48))

    # Build thick front beveled face + back rim + side walls
    front_grid: list[list[int]] = []
    back_grid: list[list[int]] = []
    for hi in range(h_segs + 1):
        v01 = hi / h_segs
        ly = cy + (0.5 - v01) * crest_h
        hw = crest_w * 0.5 * shield_half_w(v01)
        f_row: list[int] = []
        b_row: list[int] = []
        for wi in range(w_segs + 1):
            u01 = wi / w_segs
            lx = (u01 - 0.5) * 2.0 * hw
            r_cyl = _tankard_profile_r(_clamp01(ly / H)) + 0.0028
            ang = lx / r_cyl
            px = r_cyl * math.sin(ang)
            pz_back = r_cyl * math.cos(ang)
            # Thick plaque center (+0.0042 front bevel proud of the middle brass hoop)
            is_edge = (wi == 0 or wi == w_segs or hi == 0 or hi == h_segs)
            extrude = 0.0014 if is_edge else 0.0044
            pz_front = pz_back + extrude
            nx, nz = math.sin(ang), math.cos(ang)
            f_row.append(md.add_vertex((px, ly, pz_front), (nx, 0.05, nz), (u01, v01), 0.72 if is_edge else 1.0))
            b_row.append(md.add_vertex((px, ly, pz_back), (nx, -0.05, nz), (u01, v01), 0.34))
        front_grid.append(f_row)
        back_grid.append(b_row)

    for hi in range(h_segs):
        for wi in range(w_segs):
            # Front face (+Z): u goes -X..+X, v goes top(+Y)..bot(-Y), so (hi,wi)->(hi+1,wi)->(hi+1,wi+1)->(hi,wi+1) is CCW from +Z!
            md.add_quad(front_grid[hi][wi], front_grid[hi + 1][wi], front_grid[hi + 1][wi + 1], front_grid[hi][wi + 1], flip=False)
            md.add_quad(back_grid[hi][wi], back_grid[hi][wi + 1], back_grid[hi + 1][wi + 1], back_grid[hi + 1][wi], flip=False)

    # Perimeter thickness walls
    for wi in range(w_segs):
        md.add_quad(back_grid[0][wi], front_grid[0][wi], front_grid[0][wi + 1], back_grid[0][wi + 1], flip=False)
        md.add_quad(front_grid[h_segs][wi], back_grid[h_segs][wi], back_grid[h_segs][wi + 1], front_grid[h_segs][wi + 1], flip=False)
    for hi in range(h_segs):
        md.add_quad(back_grid[hi][0], back_grid[hi + 1][0], front_grid[hi + 1][0], front_grid[hi][0], flip=False)
        md.add_quad(front_grid[hi][w_segs], front_grid[hi + 1][w_segs], back_grid[hi + 1][w_segs], back_grid[hi][w_segs], flip=False)

    return md


def build_ale_liquid(H: float = 0.098) -> MeshData:
    md = MeshData("AleLiquid")
    liq_y = H - 0.008
    r_liq = _tankard_profile_r(0.95) - 0.0050
    segs = 32
    center = md.add_vertex((0.0, liq_y, 0.0), (0.0, 1.0, 0.0), (0.5, 0.5), 0.72)
    ring: list[int] = []
    for i in range(segs + 1):
        a = (i / segs) * math.tau
        ring.append(md.add_vertex((r_liq * math.cos(a), liq_y, r_liq * math.sin(a)), (0.0, 1.0, 0.0), (0.5 + 0.45 * math.cos(a), 0.5 + 0.45 * math.sin(a)), 0.45))
    for i in range(segs):
        md.add_tri(center, ring[i], ring[i + 1], flip=True)
    return md


def build_ale_foam(H: float = 0.098) -> MeshData:
    md = MeshData("AleFoam")
    # 1. Sculpted billowing multi-lobe foam crown overhanging upper lip (52 x 20 grid)
    a_segs = 52
    r_segs = 18
    r_lip = _tankard_profile_r(1.0)
    grid: list[list[int]] = []

    for ri in range(r_segs + 1):
        rt = ri / r_segs  # 0 at apex -> 1 at outer tucked rim below lip
        row: list[int] = []
        for ai in range(a_segs + 1):
            ang = (ai / a_segs) * math.tau
            ca, sa = math.cos(ang), math.sin(ang)

            # Organic multi-lobe bubbly foam dome + overhanging skirt (smooth near apex to prevent creases!)
            apex_damp = math.sin(min(1.0, rt / 0.85) * math.pi) ** 1.15
            lobe = (
                0.0032 * math.sin(ang * 5.0 + 0.7)
                + 0.0018 * math.cos(ang * 9.0 - 1.1)
                + 0.0010 * math.sin(ang * 13.0)
            ) * apex_damp
            if rt < 0.76:
                u = rt / 0.76
                r = (r_lip + 0.0038) * math.sin(u * math.pi * 0.5) * (1.0 + 0.05 * math.sin(ang * 5.0) * u)
                y = H - 0.003 + 0.023 * math.cos(u * math.pi * 0.5) + lobe
                ao = 0.94 + 0.06 * (1.0 - u)
            else:
                # Overhanging puffy skirt tucking neatly back against the oak wall
                u = (rt - 0.76) / 0.24
                r = (r_lip + 0.0044) * (1.0 - 0.16 * (u ** 1.4)) * (1.0 + 0.045 * math.sin(ang * 5.0))
                y = H - 0.003 - 0.009 * (u ** 1.15) + lobe * (1.0 - u * 0.6)
                ao = 0.85 - 0.42 * u

            row.append(md.add_vertex((r * ca, y, r * sa), (ca, 0.5, sa), (ai / float(a_segs) * 2.0, rt * 0.72), ao))
        grid.append(row)

    for ri in range(r_segs):
        for ai in range(a_segs):
            # Flip=True so outward normals point UP/OUT from apex!
            md.add_quad(grid[ri][ai], grid[ri][ai + 1], grid[ri + 1][ai + 1], grid[ri + 1][ai], flip=True)

    # 2. 5 Sculpted cascading thick foam drip trails running down the staves & hoops
    drip_specs = [
        (math.radians(66.0), 0.028, 0.0054),   # front-right hero drip
        (math.radians(114.0), 0.022, 0.0046),  # front-left drip near crest
        (math.radians(32.0), 0.017, 0.0042),   # near handle side
        (math.radians(172.0), 0.025, 0.0048),  # left side drip
        (math.radians(242.0), 0.019, 0.0044),  # back drip
    ]
    for d_ang, d_len, d_w in drip_specs:
        d_steps = 12
        d_cols = 8
        d_grid: list[list[int]] = []
        for yi in range(d_steps + 1):
            t = yi / d_steps
            y = H - 0.004 - t * d_len
            # Teardrop bulbous tip at bottom t=0.80..1.0
            bulb = 1.0 + 0.48 * math.exp(-((t - 0.84) / 0.14) ** 2) - 0.88 * max(0.0, (t - 0.92) / 0.08) ** 2
            w_rad = d_w * bulb * (1.0 - 0.15 * t)
            # Sit flush over staves + upper brass hoop bump around y=0.083
            hoop_bump = 0.0024 * math.exp(-((y - 0.083) / 0.0048) ** 2)
            r_surf = _tankard_profile_r(_clamp01(y / H)) + hoop_bump - 0.0004
            d_row: list[int] = []
            for wi in range(d_cols + 1):
                wt = (wi / d_cols) * 2.0 - 1.0  # -1 .. +1
                ang_off = d_ang + wt * (w_rad / r_surf)
                arch = math.sqrt(max(0.0, 1.0 - wt * wt))
                thick = (0.0026 * bulb + 0.0006 * math.sin(t * math.pi)) * arch
                r_pt = r_surf + thick
                px = r_pt * math.cos(ang_off)
                pz = r_pt * math.sin(ang_off)
                # Bottom edge fades into amber foam UV range (v = 0.72..0.98)
                ao_d = 0.48 + 0.52 * arch
                d_row.append(md.add_vertex((px, y, pz), (math.cos(ang_off), -0.1, math.sin(ang_off)), (0.5 + wt * 0.25, 0.70 + t * 0.28), ao_d))
            d_grid.append(d_row)
        for yi in range(d_steps):
            for wi in range(d_cols):
                md.add_quad(d_grid[yi][wi], d_grid[yi][wi + 1], d_grid[yi + 1][wi + 1], d_grid[yi + 1][wi], flip=True)

    md.enforce_outward_winding_from_normals()
    md.recompute_smooth_normals()
    return md


def build_spilled_ale() -> MeshData:
    md = MeshData("SpilledAle")
    # Small stylized ale splash drop neatly inside the walnut coaster tray
    segs = 22
    cx, cy, cz = -0.022, 0.0016, 0.025
    center = md.add_vertex((cx, cy + 0.0008, cz), (0.0, 1.0, 0.0), (0.5, 0.5), 0.92)
    ring: list[int] = []
    for i in range(segs + 1):
        a = (i / segs) * math.tau
        rad = 0.0062 * (1.0 + 0.28 * math.sin(a * 3.0 + 0.4) + 0.16 * math.cos(a * 5.0))
        ring.append(md.add_vertex((cx + rad * math.cos(a), cy, cz + rad * math.sin(a)), (0.0, 1.0, 0.0), (0.5 + 0.4 * math.cos(a), 0.5 + 0.4 * math.sin(a)), 0.52))
    for i in range(segs):
        md.add_tri(center, ring[i], ring[i + 1], flip=True)
    return md


def export_glb(meshes: list[MeshData], out_path: Path) -> None:
    bin_buf = bytearray()
    buffer_views: list[dict] = []
    accessors: list[dict] = []
    gltf_meshes: list[dict] = []
    gltf_nodes: list[dict] = []

    def append_bytes(raw: bytes, target: int | None = None) -> int:
        while len(bin_buf) % 4 != 0:
            bin_buf.append(0)
        offset = len(bin_buf)
        bin_buf.extend(raw)
        bv = {"buffer": 0, "byteOffset": offset, "byteLength": len(raw)}
        if target is not None:
            bv["target"] = target
        bv_idx = len(buffer_views)
        buffer_views.append(bv)
        return bv_idx

    for mi, md in enumerate(meshes):
        pos_np = np.array(md.positions, dtype=np.float32)
        nrm_np = np.array(md.normals, dtype=np.float32)
        uv_np = np.array(md.uvs, dtype=np.float32)
        col_np = np.array(md.colors, dtype=np.float32)
        idx_np = np.array(md.indices, dtype=np.uint32)

        bv_pos = append_bytes(pos_np.tobytes(), 34962)
        bv_nrm = append_bytes(nrm_np.tobytes(), 34962)
        bv_uv = append_bytes(uv_np.tobytes(), 34962)
        bv_col = append_bytes(col_np.tobytes(), 34962)
        bv_idx = append_bytes(idx_np.tobytes(), 34963)

        acc_pos = len(accessors)
        accessors.append({
            "bufferView": bv_pos,
            "componentType": 5126,
            "count": len(md.positions),
            "type": "VEC3",
            "min": [float(v) for v in pos_np.min(axis=0)],
            "max": [float(v) for v in pos_np.max(axis=0)],
        })
        acc_nrm = len(accessors)
        accessors.append({"bufferView": bv_nrm, "componentType": 5126, "count": len(md.normals), "type": "VEC3"})
        acc_uv = len(accessors)
        accessors.append({"bufferView": bv_uv, "componentType": 5126, "count": len(md.uvs), "type": "VEC2"})
        acc_col = len(accessors)
        accessors.append({"bufferView": bv_col, "componentType": 5126, "count": len(md.colors), "type": "VEC4"})
        acc_idx = len(accessors)
        accessors.append({
            "bufferView": bv_idx,
            "componentType": 5125,
            "count": len(md.indices),
            "type": "SCALAR",
            "min": [int(idx_np.min())],
            "max": [int(idx_np.max())],
        })

        gltf_meshes.append({
            "name": md.name,
            "primitives": [{
                "attributes": {
                    "POSITION": acc_pos,
                    "NORMAL": acc_nrm,
                    "TEXCOORD_0": acc_uv,
                    "COLOR_0": acc_col,
                },
                "indices": acc_idx,
                "mode": 4,
            }],
        })
        gltf_nodes.append({"name": md.name, "mesh": mi})

    while len(bin_buf) % 4 != 0:
        bin_buf.append(0)

    gltf_doc = {
        "asset": {"version": "2.0", "generator": "LIALO HandDrawn Relic Sculptor v1.0"},
        "scene": 0,
        "scenes": [{"name": "TankardRelic", "nodes": list(range(len(gltf_nodes)))}],
        "nodes": gltf_nodes,
        "meshes": gltf_meshes,
        "buffers": [{"byteLength": len(bin_buf)}],
        "bufferViews": buffer_views,
        "accessors": accessors,
    }
    json_bytes = json.dumps(gltf_doc, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4 != 0:
        json_bytes += b" "

    total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_buf)
    header = struct.pack("<III", 0x46546C67, 2, total_len)
    c_json = struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    c_bin = struct.pack("<II", len(bin_buf), 0x004E4942) + bytes(bin_buf)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(header + c_json + c_bin)


def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    print("Generating hand-inked tankard textures...")
    generate_oak_texture(TEX_DIR / "tankard_oak_ink.png")
    generate_brass_texture(TEX_DIR / "tankard_brass_ink.png")
    generate_crest_texture(TEX_DIR / "tankard_crest_ink.png")
    generate_foam_texture(TEX_DIR / "tankard_foam_ink.png")

    print("Sculpting multi-part 3D Tankard geometry with baked crevice AO...")
    meshes = [
        build_oak_staves(),
        build_brass_hoops(),
        build_scroll_handle(),
        build_heraldic_crest(),
        build_ale_liquid(),
        build_ale_foam(),
        build_spilled_ale(),
    ]
    for m in meshes:
        if m.name != "AleFoam":
            fl = m.enforce_outward_winding_from_normals()
            if fl > 0:
                print(f"  * Fixed outward winding on {m.name}: {fl} tris")
    export_glb(meshes, MODEL_PATH)

    total_tris = sum(len(m.indices) // 3 for m in meshes)
    total_verts = sum(len(m.positions) for m in meshes)
    print(f"Exported {MODEL_PATH} ({MODEL_PATH.stat().st_size} bytes, {len(meshes)} meshes, {total_verts} verts, {total_tris} tris)")
    for m in meshes:
        print(f"  - {m.name}: {len(m.positions)} verts, {len(m.indices) // 3} tris")


if __name__ == "__main__":
    main()
