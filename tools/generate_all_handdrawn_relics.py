#!/usr/bin/env python3
"""Generate all remaining 9 Hand-Drawn ('Kreslené') 3D Tabletop Relics + Oath Blade GLB.

Follows the approved TRELIC_WAR_HORN ("Tankard Norm") pipeline:
  - 1024x1024 / 512x512 hand-inked woodcut PNG textures in assets/textures/relics/
  - Multi-part sculpted glTF 2.0 .glb meshes with analytical outward normals,
    outward winding enforcement, spatial normal welding, and baked vertex AO (COLOR_0).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from generate_tankard_relic import MeshData, _add_paper_grain, _clamp01, export_glb

ROOT = TOOLS_DIR.parent
TEX_DIR = ROOT / "assets" / "textures" / "relics"
MODEL_DIR = ROOT / "assets" / "models" / "relics"
SWORD_DIR = ROOT / "assets" / "models" / "swords"

RNG = np.random.default_rng(7719)


# ==============================================================================
# 1. MATH & GEOMETRY HELPERS (Outward-Safe + Welded Normals + Crevice AO)
# ==============================================================================

def _norm3(v: tuple[float, float, float]) -> tuple[float, float, float]:
    ln = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if ln < 1e-9:
        return (0.0, 1.0, 0.0)
    return (v[0] / ln, v[1] / ln, v[2] / ln)


def _cross(a: tuple[float, float, float], b: tuple[float, float, float]) -> tuple[float, float, float]:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _rot_mat(rx_deg: float, ry_deg: float, rz_deg: float) -> np.ndarray:
    rx, ry, rz = math.radians(rx_deg), math.radians(ry_deg), math.radians(rz_deg)
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]], dtype=np.float64)
    my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]], dtype=np.float64)
    mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]], dtype=np.float64)
    return my @ mx @ mz


def _xform_pt(p: tuple[float, float, float], offset: tuple[float, float, float], rmat: np.ndarray | None) -> tuple[float, float, float]:
    if rmat is not None:
        v = rmat @ np.array(p, dtype=np.float64)
        return (float(v[0]) + offset[0], float(v[1]) + offset[1], float(v[2]) + offset[2])
    return (p[0] + offset[0], p[1] + offset[1], p[2] + offset[2])


def _xform_n(n: tuple[float, float, float], rmat: np.ndarray | None) -> tuple[float, float, float]:
    if rmat is not None:
        v = rmat @ np.array(n, dtype=np.float64)
        return _norm3((float(v[0]), float(v[1]), float(v[2])))
    return _norm3(n)


def finalize_mesh(md: MeshData, smooth: bool = True, weld: bool = True) -> MeshData:
    md.enforce_outward_winding_from_normals()
    if smooth:
        md.recompute_smooth_normals(weld_positions=weld)
        md.enforce_outward_winding_from_normals()
    return md


def add_lathe(
    md: MeshData,
    profile: list[tuple[float, float, float]],  # (radius, y, ao)
    segs: int = 36,
    offset: tuple[float, float, float] = (0.0, 0.0, 0.0),
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    flute_amp: float = 0.0,
    flute_freq: int = 12,
    cap_bottom: bool = True,
    cap_top: bool = True,
    uv_v_scale: float = 1.0,
) -> None:
    rmat = _rot_mat(*rot_deg) if rot_deg != (0.0, 0.0, 0.0) else None
    n_p = len(profile)
    # Precompute 2D profile outward normals in (r, y)
    prof_n: list[tuple[float, float]] = []
    for i in range(n_p):
        if i == 0:
            dr = profile[1][0] - profile[0][0]
            dy = profile[1][1] - profile[0][1]
        elif i == n_p - 1:
            dr = profile[-1][0] - profile[-2][0]
            dy = profile[-1][1] - profile[-2][1]
        else:
            dr = profile[i + 1][0] - profile[i - 1][0]
            dy = profile[i + 1][1] - profile[i - 1][1]
        # As profile ascends (+y), outward radial normal is (+dy, -dr)
        ln = math.sqrt(dr * dr + dy * dy) or 1.0
        nr, ny = dy / ln, -dr / ln
        if profile[i][0] < 1e-5 and i == 0:
            nr, ny = 0.0, -1.0
        elif profile[i][0] < 1e-5 and i == n_p - 1:
            nr, ny = 0.0, 1.0
        prof_n.append((nr, ny))

    grid: list[list[int]] = []
    for pi, (rad, py, ao) in enumerate(profile):
        v_c = (pi / max(1, n_p - 1)) * uv_v_scale
        nr, ny = prof_n[pi]
        row: list[int] = []
        for si in range(segs + 1):
            ang = (si / segs) * math.tau
            flute = 1.0 + flute_amp * math.sin(ang * flute_freq) if (flute_amp != 0.0 and rad > 0.002) else 1.0
            r_eff = max(0.0, rad * flute)
            ca, sa = math.cos(ang), math.sin(ang)
            pt = _xform_pt((r_eff * ca, py, r_eff * sa), offset, rmat)
            nm = _xform_n((nr * ca, ny, nr * sa), rmat)
            row.append(md.add_vertex(pt, nm, (si / float(segs), v_c), ao))
        grid.append(row)

    for pi in range(n_p - 1):
        for si in range(segs):
            md.add_quad(grid[pi][si], grid[pi][si + 1], grid[pi + 1][si + 1], grid[pi + 1][si], flip=True)

    if cap_bottom and profile[0][0] > 1e-5:
        c0 = md.add_vertex(_xform_pt((0.0, profile[0][1], 0.0), offset, rmat), _xform_n((0.0, -1.0, 0.0), rmat), (0.5, 0.5), profile[0][2] * 0.75)
        for si in range(segs):
            md.add_tri(c0, grid[0][si], grid[0][si + 1], flip=False)

    if cap_top and profile[-1][0] > 1e-5:
        c1 = md.add_vertex(_xform_pt((0.0, profile[-1][1], 0.0), offset, rmat), _xform_n((0.0, 1.0, 0.0), rmat), (0.5, 0.5), profile[-1][2])
        for si in range(segs):
            md.add_tri(c1, grid[-1][si], grid[-1][si + 1], flip=True)


def add_ellipsoid(
    md: MeshData,
    center: tuple[float, float, float],
    radii: tuple[float, float, float],
    u_segs: int = 24,
    v_segs: int = 16,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ao_bot: float = 0.45,
    ao_top: float = 0.98,
    mod_fn=None,
) -> None:
    rmat = _rot_mat(*rot_deg) if rot_deg != (0.0, 0.0, 0.0) else None
    rx, ry, rz = radii
    grid: list[list[int]] = []
    for vi in range(v_segs + 1):
        vf = vi / v_segs
        phi = (vf - 0.5) * math.pi  # -pi/2 .. +pi/2
        cp, sp = math.cos(phi), math.sin(phi)
        ao = ao_bot + (ao_top - ao_bot) * vf
        row: list[int] = []
        for ui in range(u_segs + 1):
            uf = ui / u_segs
            theta = uf * math.tau
            ct, st = math.cos(theta), math.sin(theta)
            lx = rx * cp * ct
            ly = ry * sp
            lz = rz * cp * st
            if mod_fn is not None:
                lx, ly, lz, ao_m = mod_fn(lx, ly, lz, uf, vf, theta, phi)
                ao_here = ao * ao_m
            else:
                ao_here = ao
            pt = _xform_pt((lx, ly, lz), center, rmat)
            nm = _xform_n((cp * ct / max(rx, 1e-4), sp / max(ry, 1e-4), cp * st / max(rz, 1e-4)), rmat)
            row.append(md.add_vertex(pt, nm, (uf, vf), ao_here))
        grid.append(row)
    for vi in range(v_segs):
        for ui in range(u_segs):
            md.add_quad(grid[vi][ui], grid[vi][ui + 1], grid[vi + 1][ui + 1], grid[vi + 1][ui], flip=False)


def add_rounded_box(
    md: MeshData,
    center: tuple[float, float, float],
    half: tuple[float, float, float],
    bevel: float = 0.0022,
    subdiv: int = 4,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ao_bot: float = 0.52,
    ao_top: float = 0.96,
    sculpt_fn=None,
) -> None:
    """Subdivided rounded/chamfered prism mapped smoothly from a cube sphere projection."""
    rmat = _rot_mat(*rot_deg) if rot_deg != (0.0, 0.0, 0.0) else None
    hx, hy, hz = max(half[0] - bevel, 1e-4), max(half[1] - bevel, 1e-4), max(half[2] - bevel, 1e-4)

    # 6 cube faces mapped into inner box + smooth bevel normal offset
    face_axes = [
        ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
        ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
        ((1, 0, 0), (0, 0, -1), (0, 1, 0)),
        ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
        ((0, 1, 0), (1, 0, 0), (0, 0, -1)),
        ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    ]
    n = max(2, subdiv)
    for fn, ax_u, ax_v in face_axes:
        grid: list[list[int]] = []
        for iv in range(n + 1):
            v01 = iv / n
            sv = v01 * 2.0 - 1.0
            row: list[int] = []
            for iu in range(n + 1):
                u01 = iu / n
                su = u01 * 2.0 - 1.0
                cx = fn[0] + ax_u[0] * su + ax_v[0] * sv
                cy = fn[1] + ax_u[1] * su + ax_v[1] * sv
                cz = fn[2] + ax_u[2] * su + ax_v[2] * sv
                # Inner clamped core + smooth bevel vector
                ix = max(-1.0, min(1.0, cx)) * hx
                iy = max(-1.0, min(1.0, cy)) * hy
                iz = max(-1.0, min(1.0, cz)) * hz
                # Spherified outward offset along bevel
                # On interior face points (|su|<1, |sv|<1), direction is pure fn; near edges it blends smoothly
                bx = (cx * 0.5) if abs(cx) <= 1.0 else (cx - math.copysign(1.0, cx))
                by = (cy * 0.5) if abs(cy) <= 1.0 else (cy - math.copysign(1.0, cy))
                bz = (cz * 0.5) if abs(cz) <= 1.0 else (cz - math.copysign(1.0, cz))
                # Use smooth blend based on normalized direction of corner excess
                ex = cx - (max(-0.85, min(0.85, cx)) if abs(fn[0]) < 0.5 else 0.0)
                ey = cy - (max(-0.85, min(0.85, cy)) if abs(fn[1]) < 0.5 else 0.0)
                ez = cz - (max(-0.85, min(0.85, cz)) if abs(fn[2]) < 0.5 else 0.0)
                dx, dy, dz = _norm3((ex, ey, ez))
                px = ix + dx * bevel
                py = iy + dy * bevel
                pz = iz + dz * bevel
                ao_here = ao_bot + (ao_top - ao_bot) * ((py / max(half[1], 1e-4)) * 0.5 + 0.5)
                if sculpt_fn is not None:
                    px, py, pz, ao_m = sculpt_fn(px, py, pz)
                    ao_here *= ao_m
                pt = _xform_pt((px, py, pz), center, rmat)
                nm = _xform_n((dx, dy, dz), rmat)
                row.append(md.add_vertex(pt, nm, (u01, 1.0 - v01), ao_here))
            grid.append(row)
        for iv in range(n):
            for iu in range(n):
                md.add_quad(grid[iv][iu], grid[iv][iu + 1], grid[iv + 1][iu + 1], grid[iv + 1][iu], flip=False)


def add_swept_3d(
    md: MeshData,
    pts: list[tuple[float, float, float]],
    radii: list[float],
    segs: int = 12,
    aspect_b: float = 1.0,
    closed_caps: bool = True,
    ao_ends: float = 0.45,
) -> None:
    """Parallel-transport 3D curve sweep (no gimbal locks on any 3D curve)."""
    rings: list[list[int]] = []
    n_pts = len(pts)
    prev_n: tuple[float, float, float] | None = None
    for pi, p in enumerate(pts):
        if pi == 0:
            tan = (pts[1][0] - p[0], pts[1][1] - p[1], pts[1][2] - p[2])
        elif pi == n_pts - 1:
            tan = (p[0] - pts[pi - 1][0], p[1] - pts[pi - 1][1], p[2] - pts[pi - 1][2])
        else:
            tan = (pts[pi + 1][0] - pts[pi - 1][0], pts[pi + 1][1] - pts[pi - 1][1], pts[pi + 1][2] - pts[pi - 1][2])
        t_dir = _norm3(tan)
        if prev_n is None:
            ref = (0.0, 1.0, 0.0) if abs(t_dir[1]) < 0.88 else (1.0, 0.0, 0.0)
            n_dir = _norm3(_cross(ref, t_dir))
        else:
            # Project previous normal perpendicular to new tangent
            dot_val = prev_n[0] * t_dir[0] + prev_n[1] * t_dir[1] + prev_n[2] * t_dir[2]
            proj = (prev_n[0] - dot_val * t_dir[0], prev_n[1] - dot_val * t_dir[1], prev_n[2] - dot_val * t_dir[2])
            n_dir = _norm3(proj)
        b_dir = _norm3(_cross(t_dir, n_dir))
        prev_n = n_dir

        r = radii[pi]
        v_c = pi / max(1, n_pts - 1)
        end_fade = min(1.0, min(pi, n_pts - 1 - pi) / 2.0)
        ao_v = ao_ends + (0.95 - ao_ends) * end_fade
        ring: list[int] = []
        for si in range(segs + 1):
            a = (si / segs) * math.tau
            ca, sa = math.cos(a), math.sin(a)
            dx = (n_dir[0] * ca + b_dir[0] * sa * aspect_b) * r
            dy = (n_dir[1] * ca + b_dir[1] * sa * aspect_b) * r
            dz = (n_dir[2] * ca + b_dir[2] * sa * aspect_b) * r
            n_out = _norm3((n_dir[0] * ca + b_dir[0] * sa, n_dir[1] * ca + b_dir[1] * sa, n_dir[2] * ca + b_dir[2] * sa))
            ring.append(md.add_vertex((p[0] + dx, p[1] + dy, p[2] + dz), n_out, (si / float(segs), v_c * 2.0), ao_v))
        rings.append(ring)

    for pi in range(n_pts - 1):
        for si in range(segs):
            md.add_quad(rings[pi][si], rings[pi][si + 1], rings[pi + 1][si + 1], rings[pi + 1][si], flip=False)

    if closed_caps:
        t0 = _norm3((pts[0][0] - pts[1][0], pts[0][1] - pts[1][1], pts[0][2] - pts[1][2]))
        t1 = _norm3((pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1], pts[-1][2] - pts[-2][2]))
        c0 = md.add_vertex(pts[0], t0, (0.5, 0.5), ao_ends)
        c1 = md.add_vertex(pts[-1], t1, (0.5, 0.5), ao_ends)
        for si in range(segs):
            md.add_tri(c0, rings[0][si], rings[0][si + 1], flip=False)
            md.add_tri(c1, rings[-1][si], rings[-1][si + 1], flip=True)


def add_torus(
    md: MeshData,
    center: tuple[float, float, float],
    major_r: float,
    minor_r: float,
    maj_segs: int = 24,
    min_segs: int = 10,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ao_val: float = 0.85,
) -> None:
    rmat = _rot_mat(*rot_deg) if rot_deg != (0.0, 0.0, 0.0) else None
    grid: list[list[int]] = []
    for i in range(maj_segs + 1):
        u = i / maj_segs
        ang = u * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        row: list[int] = []
        for j in range(min_segs + 1):
            v = j / min_segs
            phi = v * math.tau
            cp, sp = math.cos(phi), math.sin(phi)
            rr = major_r + minor_r * cp
            lx = rr * ca
            ly = minor_r * sp
            lz = rr * sa
            pt = _xform_pt((lx, ly, lz), center, rmat)
            nm = _xform_n((cp * ca, sp, cp * sa), rmat)
            row.append(md.add_vertex(pt, nm, (u * 2.0, v), ao_val * (0.72 + 0.28 * max(0.0, sp))))
        grid.append(row)
    for i in range(maj_segs):
        for j in range(min_segs):
            md.add_quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j], flip=False)


# ==============================================================================
# 2. HAND-INKED WOODCUT TEXTURES (PIL + NumPy)
# ==============================================================================

def _gen_ivory_bone_tex(path: Path) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    base = np.array([232.0, 214.0, 174.0], dtype=np.float32)
    swirl = np.sin(u * 14.0 + np.cos(v * 9.0) * 1.4) * 9.0 + np.cos(v * 22.0) * 5.0
    arr = np.clip(base[None, None, :] + swirl[..., None], 0, 255)
    # Warm sepia bevel darkening along borders
    edge = np.maximum(np.abs(u - 0.5), np.abs(v - 0.5)) * 2.0
    arr *= (1.0 - np.clip((edge - 0.72) / 0.28, 0.0, 1.0)[..., None] * 0.34)
    img = Image.fromarray(_add_paper_grain(arr, 0.025), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (56, 38, 22)
    # Hairline bone cracks & stippling
    for ci in range(18):
        px = int(RNG.integers(80, W - 80))
        py = int(RNG.integers(80, H - 80))
        pts = [(px, py)]
        for _ in range(5):
            px += int(RNG.integers(-28, 29))
            py += int(RNG.integers(-28, 29))
            pts.append((px, py))
        draw.line(pts, fill=ink, width=1)
    for d in range(-W, W, 18):
        draw.line([(d, H - 48), (d + 48, H)], fill=ink, width=1)
        draw.line([(d, 0), (d + 48, 48)], fill=ink, width=1)
    img.save(path, "PNG")


def _gen_leather_stitched_tex(path: Path, tint: tuple[float, float, float] = (108.0, 62.0, 36.0)) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array(tint, dtype=np.float32)
    fold = np.sin(u * 18.0 + np.sin(v * 11.0) * 1.8) * 14.0 + np.cos(v * 15.0) * 8.0
    arr += fold[..., None]
    arr *= (0.78 + 0.22 * np.sin(v * math.pi))[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.032), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (30, 18, 12)
    stitch = (224, 186, 120)
    # Stitched leather borders & woodcut hatch folds
    for sy in (56, H - 56):
        draw.line([(0, sy), (W, sy)], fill=ink, width=4)
        for sx in range(12, W, 28):
            draw.line([(sx, sy - 10), (sx + 14, sy - 10)], fill=stitch, width=3)
    for _ in range(380):
        px = int(RNG.integers(10, W - 10))
        py = int(RNG.integers(70, H - 70))
        draw.line([(px, py), (px + int(RNG.integers(-12, 13)), py + int(RNG.integers(8, 22)))], fill=ink, width=1)
    img.save(path, "PNG")


def _gen_slate_stone_tex(path: Path) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([76.0, 82.0, 92.0], dtype=np.float32)
    strata = np.sin(v * 24.0 + np.sin(u * 9.0) * 2.1) * 14.0 + np.cos(u * 31.0 - v * 17.0) * 7.0
    arr += strata[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.035), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (18, 20, 26)
    hi = (142, 152, 168)
    for _ in range(44):
        px, py = int(RNG.integers(0, W)), int(RNG.integers(0, H))
        pts = [(px, py)]
        for _ in range(6):
            px += int(RNG.integers(-45, 46))
            py += int(RNG.integers(-35, 36))
            pts.append((px, py))
        draw.line(pts, fill=ink, width=2)
        draw.line([(a + 2, b + 1) for a, b in pts], fill=hi, width=1)
    img.save(path, "PNG")


def _gen_rune_glow_tex(path: Path) -> None:
    W, H = 512, 512
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([72.0, 212.0, 252.0], dtype=np.float32)
    pulse = np.sin(x * 0.05) * np.cos(y * 0.05) * 28.0
    arr += pulse[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.02), mode="RGB")
    draw = ImageDraw.Draw(img)
    for r in range(20, 250, 34):
        draw.ellipse([256 - r, 256 - r, 256 + r, 256 + r], outline=(210, 248, 255), width=3)
    img.save(path, "PNG")


def _gen_silver_filigree_tex(path: Path) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([196.0, 184.0, 158.0], dtype=np.float32)
    dimp = np.sin(u * 42.0) * np.cos(v * 36.0) * 18.0
    arr += dimp[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.024), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (36, 26, 20)
    gold = (224, 182, 86)
    for ry in (84, 112, H // 2, H - 112, H - 84):
        draw.line([(0, ry), (W, ry)], fill=ink, width=3)
        draw.line([(0, ry + 5), (W, ry + 5)], fill=gold, width=2)
    # Gothic arch engravings
    for ax in range(0, W, 64):
        draw.arc([ax, 140, ax + 64, 340], start=180, end=360, fill=ink, width=3)
        draw.arc([ax, H - 340, ax + 64, H - 140], start=0, end=180, fill=ink, width=3)
    img.save(path, "PNG")


def _gen_blood_wine_tex(path: Path) -> None:
    W, H = 512, 512
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((x / W) - 0.5) ** 2 + ((y / H) - 0.5) ** 2)
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[..., 0] = 164.0 - r * 110.0 + np.sin(r * 45.0) * 16.0
    arr[..., 1] = 18.0 + np.sin(r * 45.0) * 6.0
    arr[..., 2] = 26.0
    img = Image.fromarray(_add_paper_grain(arr, 0.02), mode="RGB")
    draw = ImageDraw.Draw(img)
    for rr in range(42, 230, 38):
        draw.arc([256 - rr, 256 - rr, 256 + rr, 256 + rr], start=20, end=210, fill=(240, 120, 110), width=2)
    img.save(path, "PNG")


def _gen_whetstone_granite_tex(path: Path) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([128.0, 124.0, 114.0], dtype=np.float32)
    wear = np.exp(-((v - 0.5) / 0.22) ** 2) * 32.0
    arr -= wear[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.045), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (36, 32, 28)
    for _ in range(700):
        px, py = int(RNG.integers(0, W)), int(RNG.integers(0, H))
        draw.ellipse([px, py, px + int(RNG.integers(2, 6)), py + int(RNG.integers(1, 4))], fill=ink)
    for sx in range(40, W - 40, 26):
        draw.line([(sx, 260), (sx + 48, 760)], fill=(54, 48, 42), width=1)
    img.save(path, "PNG")


def _gen_forged_steel_tex(path: Path) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([186.0, 194.0, 206.0], dtype=np.float32)
    damascus = np.sin((u * 18.0 + np.sin(v * 26.0) * 1.4) * math.pi) * 20.0
    arr += damascus[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.02), mode="RGB")
    draw = ImageDraw.Draw(img)
    draw.line([(W // 2, 0), (W // 2, H)], fill=(52, 56, 68), width=6)
    for hy in range(20, H, 18):
        draw.line([(W // 2 - 44, hy), (W // 2 + 44, hy + 10)], fill=(68, 74, 86), width=1)
    img.save(path, "PNG")


def _gen_gold_sand_tex(path: Path) -> None:
    W, H = 512, 512
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([232.0, 186.0, 74.0], dtype=np.float32)
    ripple = np.sin(v * 42.0 + np.sin(u * 12.0)) * 18.0
    arr += ripple[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.045), mode="RGB")
    draw = ImageDraw.Draw(img)
    for _ in range(500):
        px, py = int(RNG.integers(0, W)), int(RNG.integers(0, H))
        draw.point((px, py), fill=(116, 78, 22))
        draw.point((min(W - 1, px + 1), py), fill=(252, 232, 148))
    img.save(path, "PNG")


def _gen_glass_ink_tex(path: Path) -> None:
    W, H = 512, 512
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u = x / W
    arr = np.zeros((H, W, 3), dtype=np.float32)
    arr[:, :] = np.array([176.0, 214.0, 224.0], dtype=np.float32)
    rib = np.sin(u * math.tau * 12.0) * 18.0
    arr += rib[..., None]
    img = Image.fromarray(_add_paper_grain(arr, 0.015), mode="RGB")
    draw = ImageDraw.Draw(img)
    for rx in range(24, W, 42):
        draw.line([(rx, 0), (rx, H)], fill=(238, 250, 255), width=2)
    img.save(path, "PNG")


def _gen_florin_gold_tex(path: Path) -> None:
    W, H = 512, 512
    img = Image.new("RGB", (W, H), (226, 178, 56))
    draw = ImageDraw.Draw(img)
    ink = (54, 34, 14)
    hi = (250, 226, 134)
    draw.ellipse([18, 18, W - 18, H - 18], outline=ink, width=10)
    draw.ellipse([38, 38, W - 38, H - 38], outline=hi, width=5)
    for a_deg in range(0, 360, 12):
        a = math.radians(a_deg)
        x0, y0 = 256 + math.cos(a) * 204, 256 + math.sin(a) * 204
        x1, y1 = 256 + math.cos(a) * 224, 256 + math.sin(a) * 224
        draw.line([(x0, y0), (x1, y1)], fill=ink, width=3)
    # Central stamped crown
    pts = [(190, 290), (176, 210), (220, 245), (256, 182), (292, 245), (336, 210), (322, 290)]
    draw.polygon(pts, fill=hi, outline=ink)
    draw.line(pts + [pts[0]], fill=ink, width=6)
    Image.fromarray(_add_paper_grain(np.array(img), 0.024), mode="RGB").save(path, "PNG")


def _gen_cracked_bronze_tex(path: Path) -> None:
    W, H = 1024, 1024
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    patina = np.clip(np.sin(u * 13.0 + np.cos(v * 11.0) * 1.8) * 0.5 + 0.25, 0.0, 1.0)[..., None]
    bronze = np.array([154.0, 108.0, 56.0], dtype=np.float32)
    verd = np.array([78.0, 138.0, 118.0], dtype=np.float32)
    arr = bronze * (1.0 - patina * 0.42) + verd * (patina * 0.42)
    img = Image.fromarray(_add_paper_grain(arr, 0.028), mode="RGB")
    draw = ImageDraw.Draw(img)
    ink = (28, 20, 14)
    for band_y in (180, 820, 860):
        draw.line([(0, band_y), (W, band_y)], fill=ink, width=5)
    # Jagged toll-bell crack
    cx, cy = 420, 320
    c_pts = [(cx, cy)]
    for step in range(9):
        cx += int(RNG.integers(-22, 26))
        cy += 64
        c_pts.append((cx, cy))
    draw.line(c_pts, fill=ink, width=7)
    draw.line([(a + 3, b) for a, b in c_pts], fill=(42, 168, 178), width=2)
    img.save(path, "PNG")


def _gen_ember_coal_tex(path: Path) -> None:
    W, H = 512, 512
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    heat = np.clip(np.sin(u * 22.0) * np.cos(v * 20.0) * 0.5 + 0.5, 0.0, 1.0)[..., None]
    charcoal = np.array([42.0, 24.0, 20.0], dtype=np.float32)
    ember = np.array([252.0, 118.0, 24.0], dtype=np.float32)
    arr = charcoal * (1.0 - heat * 0.72) + ember * (heat * 0.72)
    img = Image.fromarray(_add_paper_grain(arr, 0.03), mode="RGB")
    draw = ImageDraw.Draw(img)
    for _ in range(90):
        px, py = int(RNG.integers(20, W - 20)), int(RNG.integers(20, H - 20))
        draw.line([(px, py), (px + int(RNG.integers(-30, 31)), py + int(RNG.integers(-30, 31)))], fill=(255, 210, 96), width=2)
    img.save(path, "PNG")


def _gen_ember_plume_tex(path: Path) -> None:
    W, H = 512, 512
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    v = y / H
    # Bright yellow-orange at bottom/core -> deep crimson at tips
    bot = np.array([255.0, 208.0, 64.0], dtype=np.float32)
    top = np.array([196.0, 34.0, 22.0], dtype=np.float32)
    t = np.clip(1.0 - v, 0.0, 1.0)[..., None]
    arr = bot * (1.0 - t) + top * t
    img = Image.fromarray(_add_paper_grain(arr, 0.022), mode="RGB")
    draw = ImageDraw.Draw(img)
    for fx in range(24, W, 34):
        pts = [(fx + int(math.sin(py * 0.03 + fx) * 14.0), py) for py in range(0, H + 16, 16)]
        draw.line(pts, fill=(84, 16, 12), width=2)
    img.save(path, "PNG")


# ==============================================================================
# 3. THE 9 SCULPTED RELICS + HAND-DRAWN OATH BLADE
# ==============================================================================

def build_trelic_hollow_mask() -> list[MeshData]:
    # Loaded Bone Dice — carved leather cup rim base + 2 stacked rounded ivory dice + inlaid pip bowls + brass corner caps
    cup = MeshData("CupRim")
    add_lathe(cup, [
        (0.033, 0.000, 0.45), (0.0345, 0.004, 0.72), (0.033, 0.011, 0.90),
        (0.029, 0.013, 0.96), (0.027, 0.004, 0.35), (0.000, 0.004, 0.25)
    ], segs=36, cap_bottom=True, cap_top=False)

    dice = MeshData("BoneDice")
    pips = MeshData("PipBowls")
    brass = MeshData("BrassBrackets")

    dice_specs = [
        ((-0.011, 0.022, 0.004), (10.0, 24.0, -8.0), 0.0165),
        ((0.011, 0.053, -0.004), (-16.0, -34.0, 18.0), 0.0158),
    ]
    pip_layouts = [
        # top (+Y), front (+Z), right (+X)
        ([(0, 0), (-0.48, -0.48), (0.48, 0.48), (-0.48, 0.48), (0.48, -0.48)], [(-0.42, -0.42), (0.42, 0.42)], [(-0.42, -0.42), (0, 0), (0.42, 0.42)]),
        ([(0, 0)], [(-0.44, -0.44), (0.44, -0.44), (-0.44, 0.44), (0.44, 0.44), (-0.44, 0.0), (0.44, 0.0)], [(-0.42, -0.42), (0.42, 0.42), (0, 0)]),
    ]
    for di, (d_pos, d_rot, hs) in enumerate(dice_specs):
        rmat = _rot_mat(*d_rot)
        add_rounded_box(dice, d_pos, (hs, hs, hs), bevel=0.0038, subdiv=6, rot_deg=d_rot, ao_bot=0.62, ao_top=0.98)
        # Carved pips sitting slightly recessed on faces
        top_p, fr_p, rt_p = pip_layouts[di]
        for u, v in top_p:
            lp = _xform_pt((u * hs * 0.92, hs * 0.99, v * hs * 0.92), d_pos, rmat)
            add_ellipsoid(pips, lp, (0.0032, 0.0012, 0.0032), 10, 6, rot_deg=d_rot, ao_bot=0.25, ao_top=0.65)
        for u, v in fr_p:
            lp = _xform_pt((u * hs * 0.92, v * hs * 0.92, hs * 0.99), d_pos, rmat)
            add_ellipsoid(pips, lp, (0.0030, 0.0030, 0.0012), 10, 6, rot_deg=d_rot, ao_bot=0.25, ao_top=0.65)
        for u, v in rt_p:
            lp = _xform_pt((hs * 0.99, v * hs * 0.92, u * hs * 0.92), d_pos, rmat)
            add_ellipsoid(pips, lp, (0.0012, 0.0030, 0.0030), 10, 6, rot_deg=d_rot, ao_bot=0.25, ao_top=0.65)
        # Inlaid brass corner studs on dice corners
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    cp = _xform_pt((sx * hs * 0.78, sy * hs * 0.78, sz * hs * 0.78), d_pos, rmat)
                    add_ellipsoid(brass, cp, (0.0026, 0.0026, 0.0026), 8, 6, ao_bot=0.5, ao_top=1.0)

    return [finalize_mesh(cup), finalize_mesh(dice), finalize_mesh(pips), finalize_mesh(brass)]


def build_trelic_star_bow() -> list[MeshData]:
    # Arcane Slate Rune — chiseled jagged slate monolith + glowing rune trenches + copper wire coil + 3 floating rune chips
    slate = MeshData("SlateMonolith")
    def sculpt_monolith(px: float, py: float, pz: float) -> tuple[float, float, float, float]:
        t = _clamp01((py + 0.044) / 0.088)
        taper = 1.0 - 0.34 * (t ** 1.45)
        chisel = 0.0020 * math.sin(py * 135.0 + px * 95.0) + 0.0014 * math.cos(pz * 180.0 - py * 65.0)
        peak_cut = max(0.0, (t - 0.72) / 0.28) * (0.009 if px > 0.0 else 0.0)
        # Carved beveled rune trench indentation on front & back faces
        trench_d = 0.0
        if abs(px) < 0.0026 and abs(py) < 0.028:
            trench_d = 0.0024 * (1.0 - abs(px) / 0.0026)
        ao = (0.44 + 0.56 * _clamp01(t * 0.8 + 0.2)) * (0.58 if trench_d > 0.0005 else 1.0)
        pz_carved = pz * (1.0 - 0.25 * t) - (trench_d if pz > 0.0 else -trench_d)
        return (px * taper + chisel, py - peak_cut, pz_carved + chisel * 0.5, ao)
    add_rounded_box(slate, (0.0, 0.044, 0.0), (0.022, 0.044, 0.011), bevel=0.0032, subdiv=10, rot_deg=(-4.0, 10.0, 2.0), sculpt_fn=sculpt_monolith)
    # Stepped mossy plinth
    add_rounded_box(slate, (0.0, 0.006, 0.0), (0.031, 0.006, 0.021), bevel=0.0024, subdiv=5, ao_bot=0.30, ao_top=0.80)
    add_rounded_box(slate, (0.0, 0.013, 0.0), (0.025, 0.004, 0.016), bevel=0.0018, subdiv=4, ao_bot=0.45, ao_top=0.86)

    glyphs = MeshData("RuneGlyphs")
    rmat = _rot_mat(-4.0, 10.0, 2.0)
    # Recessed luminous rune stroke branches front & back
    for side in (-1.0, 1.0):
        spine = [
            _xform_pt((0.0, -0.024, side * 0.0102), (0.0, 0.044, 0.0), rmat),
            _xform_pt((0.0, 0.004, side * 0.0100), (0.0, 0.044, 0.0), rmat),
            _xform_pt((0.0, 0.028, side * 0.0092), (0.0, 0.044, 0.0), rmat),
        ]
        add_swept_3d(glyphs, spine, [0.0024, 0.0026, 0.0020], segs=8)
        arm1 = [
            _xform_pt((-0.012, 0.016, side * 0.0094), (0.0, 0.044, 0.0), rmat),
            _xform_pt((0.0, 0.004, side * 0.0100), (0.0, 0.044, 0.0), rmat),
            _xform_pt((0.012, 0.018, side * 0.0092), (0.0, 0.044, 0.0), rmat),
        ]
        add_swept_3d(glyphs, arm1, [0.0018, 0.0022, 0.0018], segs=8)
        arm2 = [
            _xform_pt((-0.010, -0.012, side * 0.0098), (0.0, 0.044, 0.0), rmat),
            _xform_pt((0.011, -0.002, side * 0.0098), (0.0, 0.044, 0.0), rmat),
        ]
        add_swept_3d(glyphs, arm2, [0.0017, 0.0017], segs=8)

    wire = MeshData("CopperWire")
    # Spiral copper binding wire wrapping lower half of monolith
    coil_pts: list[tuple[float, float, float]] = []
    coil_rad: list[float] = []
    for ci in range(44):
        t = ci / 43.0
        ang = t * math.tau * 2.5
        cy = 0.018 + t * 0.024
        rx = 0.0225 * (1.0 - 0.12 * t)
        rz = 0.0118 * (1.0 - 0.08 * t)
        coil_pts.append(_xform_pt((math.cos(ang) * rx, cy - 0.044, math.sin(ang) * rz), (0.0, 0.044, 0.0), rmat))
        coil_rad.append(0.0014)
    add_swept_3d(wire, coil_pts, coil_rad, segs=8)

    shards: list[MeshData] = []
    for si in range(3):
        sm = MeshData(f"RuneShard_{si}")
        a = si * (math.tau / 3.0) + 0.5
        sx = math.cos(a) * 0.032
        sz = math.sin(a) * 0.028
        sy = 0.056 + si * 0.012
        # Sharp tapered chiseled crystal rock shard (not a box!)
        shard_prof = [
            (0.0010, -0.012, 0.45),
            (0.0052, -0.004, 0.82),
            (0.0062,  0.003, 0.96),
            (0.0036,  0.010, 0.90),
            (0.0006,  0.014, 1.00),
        ]
        add_lathe(sm, shard_prof, segs=5, offset=(sx, sy, sz), cap_bottom=True, cap_top=True)
        shards.append(finalize_mesh(sm))

    return [finalize_mesh(slate), finalize_mesh(glyphs), finalize_mesh(wire)] + shards


def build_trelic_blood_seal() -> list[MeshData]:
    # Crimson Blood Goblet — fluted Gothic silver/brass chalice + 4 claw-set rubies + brimming wine dome + wax ribbon
    body = MeshData("GobletBody")
    chalice_profile = [
        (0.028, 0.000, 0.36), (0.029, 0.004, 0.72), (0.021, 0.009, 0.65),
        (0.011, 0.015, 0.45), (0.0075, 0.022, 0.78),
        # Knopped stem bulge
        (0.0125, 0.028, 0.96), (0.014, 0.031, 1.00), (0.012, 0.034, 0.92),
        (0.0072, 0.039, 0.68), (0.0085, 0.046, 0.52),
        # Flared Gothic cup bowl
        (0.019, 0.052, 0.68), (0.0265, 0.062, 0.88), (0.0305, 0.075, 0.96),
        (0.0335, 0.089, 1.00), (0.0345, 0.092, 0.95),
        # Lip inward roll
        (0.0310, 0.093, 0.80), (0.0285, 0.088, 0.45), (0.024, 0.072, 0.30), (0.0, 0.062, 0.25),
    ]
    add_lathe(body, chalice_profile, segs=44, flute_amp=0.032, flute_freq=10, cap_bottom=True, cap_top=False, uv_v_scale=1.6)
    add_torus(body, (0.0, 0.090, 0.0), 0.0335, 0.0022, 36, 10, ao_val=0.95)
    add_torus(body, (0.0, 0.051, 0.0), 0.0155, 0.0024, 24, 10, ao_val=0.72)

    rubies = MeshData("RubyGems")
    for gi in range(4):
        ang = gi * (math.pi * 0.5) + 0.39
        gx, gz = math.cos(ang) * 0.0318, math.sin(ang) * 0.0318
        add_ellipsoid(rubies, (gx, 0.072, gz), (0.0044, 0.0064, 0.0044), 10, 8, ao_bot=0.45, ao_top=1.0)
        # Sculpted gothic bezel + 4 claw prongs cradling each ruby
        add_torus(body, (gx * 0.96, 0.072, gz * 0.96), 0.0052, 0.0015, 14, 8, rot_deg=(0.0, -math.degrees(ang), 90.0), ao_val=0.40)
        for ci in (-1.0, 1.0):
            ca = ang + ci * 0.14
            claw = [
                (math.cos(ca) * 0.0295, 0.066, math.sin(ca) * 0.0295),
                (math.cos(ca) * 0.0355, 0.072, math.sin(ca) * 0.0355),
                (math.cos(ang) * 0.0342, 0.078, math.sin(ang) * 0.0342),
            ]
            add_swept_3d(body, claw, [0.0012, 0.0011, 0.0008], segs=6)

    wine = MeshData("WineDome")
    def wine_ripple(lx, ly, lz, uf, vf, th, ph):
        rad = math.sqrt(lx * lx + lz * lz)
        dip = 0.0022 * math.cos(rad * 185.0) + 0.0014 * math.sin(th * 3.0) * (rad / 0.030)
        return (lx, ly + dip, lz, 0.70 + 0.30 * vf)
    add_ellipsoid(wine, (0.0, 0.0885, 0.0), (0.0295, 0.0054, 0.0295), 32, 12, mod_fn=wine_ripple)
    # Sculpted overflowing blood-wine drips & streams spilling down the chalice rim
    for di, dang in enumerate([0.42, 1.85, 3.25, 4.95]):
        dca, dsa = math.cos(dang), math.sin(dang)
        drop_len = 0.020 if di % 2 == 0 else 0.013
        drip_pts = [
            (dca * 0.0285, 0.091, dsa * 0.0285),
            (dca * 0.0352, 0.090, dsa * 0.0352),
            (dca * 0.0345, 0.082, dsa * 0.0345),
            (dca * 0.0315, 0.088 - drop_len, dsa * 0.0315),
        ]
        add_swept_3d(wine, drip_pts, [0.0018, 0.0024, 0.0017, 0.0023], segs=8)
        add_ellipsoid(wine, (dca * 0.0315, 0.087 - drop_len, dsa * 0.0315), (0.0026, 0.0034, 0.0026), 10, 8)

    wax = MeshData("WaxRibbon")
    # Stem crimson wax seal medallion + twin fluttering seal ribbons
    add_ellipsoid(wax, (0.0, 0.031, 0.0135), (0.0065, 0.0065, 0.0026), 14, 8, ao_bot=0.5, ao_top=0.98)
    for side in (-1.0, 1.0):
        rib = [
            (side * 0.002, 0.028, 0.0125),
            (side * 0.009, 0.020, 0.0175),
            (side * 0.013, 0.012, 0.0210),
            (side * 0.015, 0.005, 0.0195),
        ]
        add_swept_3d(wax, rib, [0.0024, 0.0022, 0.0020, 0.0015], segs=8, aspect_b=0.35)

    return [finalize_mesh(body), finalize_mesh(rubies), finalize_mesh(wine), finalize_mesh(wax)]


def build_trelic_iron_chain() -> list[MeshData]:
    # Executioner's Whetstone — mortised walnut cradle + hollowed beveled granite whetstone + leather strop + crossed dagger
    cradle = MeshData("TimberCradle")
    add_rounded_box(cradle, (0.0, 0.007, 0.0), (0.034, 0.007, 0.022), bevel=0.0020, subdiv=5, ao_bot=0.35, ao_top=0.88)
    for sx in (-0.025, 0.025):
        add_rounded_box(cradle, (sx, 0.016, 0.0), (0.0065, 0.009, 0.020), bevel=0.0016, subdiv=4, ao_bot=0.45, ao_top=0.92)

    stone = MeshData("WhetstoneBlock")
    def whet_wear(px, py, pz):
        # Dish-worn center hollow groove from years of sharpening blades
        if py > 0.0:
            dish = 0.0032 * math.exp(-(px / 0.018) ** 2) * math.exp(-(pz / 0.010) ** 2)
            return (px, py - dish, pz, 0.60 if dish > 0.0015 else 0.94)
        return (px, py, pz, 0.52)
    add_rounded_box(stone, (0.0, 0.022, 0.0), (0.028, 0.010, 0.016), bevel=0.0026, subdiv=7, rot_deg=(0.0, 8.0, -4.0), sculpt_fn=whet_wear)

    strop = MeshData("LeatherStrop")
    add_rounded_box(strop, (0.004, 0.0145, 0.018), (0.024, 0.0025, 0.0065), bevel=0.0009, subdiv=4, rot_deg=(0.0, -10.0, 0.0))

    blade = MeshData("SharpeningDagger")
    guard = MeshData("DaggerGuard")
    # Resting diagonally angled across the whetstone bevel
    b_rot = (10.0, -18.0, 32.0)
    b_off = (-0.004, 0.056, 0.002)
    rmat = _rot_mat(*b_rot)
    # Sculpted double-edged fullered steel dagger blade
    def dagger_blade_mod(px, py, pz):
        t = _clamp01((py + 0.030) / 0.060)
        w_taper = max(0.05, 1.0 - (t ** 1.8) * 0.94)
        # Diamond cross-section thickness taper near center spine
        edge_fade = max(0.25, 1.0 - abs(px) / 0.007)
        fuller = 0.0011 * math.exp(-(px / 0.0020) ** 2) * (1.0 - t * 0.7)
        return (px * w_taper, py, pz * edge_fade - math.copysign(fuller, pz) * 0.5, 0.78 if fuller > 0.0004 else 0.98)
    add_rounded_box(blade, b_off, (0.0068, 0.030, 0.0026), bevel=0.0008, subdiv=6, rot_deg=b_rot, sculpt_fn=dagger_blade_mod)

    # Brass S-crossguard, leather grip & pommel
    g_pos = _xform_pt((0.0, -0.030, 0.0), b_off, rmat)
    add_rounded_box(guard, g_pos, (0.015, 0.0028, 0.0044), bevel=0.0012, subdiv=4, rot_deg=b_rot)
    h_pts = [_xform_pt((0.0, -0.032 - i * 0.0042, 0.0), b_off, rmat) for i in range(6)]
    add_swept_3d(strop, h_pts, [0.0038, 0.0034, 0.0038, 0.0035, 0.0038, 0.0032], segs=10)
    p_pos = _xform_pt((0.0, -0.056, 0.0), b_off, rmat)
    add_ellipsoid(guard, p_pos, (0.0055, 0.0058, 0.0055), 12, 8, rot_deg=b_rot)

    return [finalize_mesh(cradle), finalize_mesh(stone), finalize_mesh(strop), finalize_mesh(blade), finalize_mesh(guard)]


def build_trelic_ash_glass() -> list[MeshData]:
    # Fate Hourglass — turned brass zodiac plates + 4 twisted barley-sugar pillars + open crystal cage + golden sand cones
    brass = MeshData("BrassFrame")
    # Bottom brass base plate (strictly ascending +Y so outward normals point out!)
    add_lathe(brass, [
        (0.032, 0.000, 0.42),
        (0.034, 0.003, 0.85),
        (0.031, 0.007, 0.96),
        (0.025, 0.009, 0.72),
    ], segs=32, cap_bottom=True, cap_top=True)
    # Top brass zodiac cap plate (strictly ascending +Y!)
    add_lathe(brass, [
        (0.025, 0.089, 0.72),
        (0.031, 0.091, 0.96),
        (0.034, 0.095, 0.85),
        (0.032, 0.098, 0.42),
    ], segs=32, cap_bottom=True, cap_top=True)
    # 4 twisted barley-sugar brass pillars
    for pi in range(4):
        ang = pi * (math.pi * 0.5) + math.pi * 0.25
        cx, cz = math.cos(ang) * 0.0265, math.sin(ang) * 0.0265
        pts = []
        rads = []
        for s in range(18):
            t = s / 17.0
            twist = t * math.tau * 2.0 + ang
            pts.append((cx + math.cos(twist) * 0.0014, 0.008 + t * 0.082, cz + math.sin(twist) * 0.0014))
            rads.append(0.0026 + 0.0006 * math.sin(t * math.pi))
        add_swept_3d(brass, pts, rads, segs=8)
    # Waist brass collar
    add_torus(brass, (0.0, 0.049, 0.0), 0.0065, 0.0020, 20, 8)

    glass = MeshData("GlassBulbs")
    # True continuous translucent hourglass glass bulbs (ascending +Y profile)
    glass_bulb_prof = [
        (0.0215, 0.009, 0.72),
        (0.0256, 0.020, 0.92),
        (0.0226, 0.032, 0.88),
        (0.0112, 0.043, 0.80),
        (0.0046, 0.049, 0.95),
        (0.0112, 0.055, 0.80),
        (0.0226, 0.066, 0.88),
        (0.0256, 0.078, 0.92),
        (0.0215, 0.089, 0.72),
    ]
    add_lathe(glass, glass_bulb_prof, segs=32, cap_bottom=False, cap_top=False, uv_v_scale=1.2)

    sand = MeshData("SandCones")
    # Lower golden sand mound + upper reservoir cone + continuous falling sand stream in waist
    add_lathe(sand, [
        (0.021, 0.010, 0.55), (0.020, 0.016, 0.82), (0.012, 0.024, 0.96), (0.002, 0.032, 1.00)
    ], segs=24, cap_bottom=True, cap_top=True)
    add_lathe(sand, [
        (0.002, 0.055, 0.78), (0.014, 0.064, 0.94), (0.0215, 0.070, 0.98), (0.0215, 0.074, 0.86)
    ], segs=24, cap_bottom=True, cap_top=True)
    add_swept_3d(sand, [(0.0, 0.055, 0.0), (0.0, 0.031, 0.0)], [0.0014, 0.0009], segs=8)

    return [finalize_mesh(brass), finalize_mesh(glass), finalize_mesh(sand)]


def build_trelic_gold_scales() -> list[MeshData]:
    # Guild Coin Purse — pleated stitched bulging leather pouch + braided drawstring cord + 14 stamped gold Florins spilling
    pouch = MeshData("LeatherPouch")
    def pouch_folds(lx, ly, lz, uf, vf, th, ph):
        # Sculpted radial gather creases toward drawstring neck
        t_top = _clamp01((ly + 0.028) / 0.056)
        crease = 0.0032 * math.sin(th * 9.0 + math.sin(vf * 5.0)) * (0.35 + 0.65 * t_top)
        neck_pinch = 1.0 - 0.58 * math.exp(-((t_top - 0.72) / 0.14) ** 2) + 0.25 * max(0.0, (t_top - 0.84) / 0.16)
        ao = 0.48 + 0.52 * _clamp01(0.5 + math.sin(th * 9.0) * 0.4)
        return (lx * neck_pinch + math.cos(th) * crease, ly, lz * neck_pinch + math.sin(th) * crease, ao)
    add_ellipsoid(pouch, (-0.010, 0.028, -0.004), (0.024, 0.030, 0.023), 36, 22, rot_deg=(0.0, 0.0, 6.0), mod_fn=pouch_folds)

    cord = MeshData("DrawstringCord")
    add_torus(cord, (-0.012, 0.044, -0.004), 0.0115, 0.0024, 24, 8, rot_deg=(0.0, 0.0, 6.0), ao_val=0.88)
    for side in (-1.0, 1.0):
        c_pts = [
            (-0.012 + side * 0.006, 0.044, 0.008),
            (-0.012 + side * 0.011, 0.036, 0.015),
            (-0.012 + side * 0.014, 0.026, 0.017),
        ]
        add_swept_3d(cord, c_pts, [0.0018, 0.0016, 0.0026], segs=8)

    coins = MeshData("GoldCoins")
    # 14 individually beveled stamped gold Florin coins stacked & spilling in foreground
    coin_spots = [
        (0.018, 0.0025, 0.010, 0, 8, -4),
        (0.019, 0.0065, 0.011, 2, -12, 6),
        (0.018, 0.0105, 0.009, -3, 18, 0),
        (0.020, 0.0145, 0.010, 4, 34, -5),
        (0.019, 0.0185, 0.008, -2, -22, 8),
        (0.030, 0.0025, -0.006, 0, 15, 3),
        (0.031, 0.0065, -0.005, 3, -18, -4),
        (0.030, 0.0105, -0.007, -4, 42, 6),
        (0.002, 0.0025, 0.024, 0, 12, 0),
        (0.004, 0.0065, 0.023, 2, -8, -4),
        (0.025, 0.0025, 0.022, 16, 20, -14),
        (-0.026, 0.0032, 0.022, 22, -28, 12),
        (-0.012, 0.056, -0.002, 58, 18, -22),
        (-0.007, 0.058, 0.003, 68, -24, 14),
    ]
    coin_prof = [(0.0095, -0.0014, 0.55), (0.0102, 0.0, 0.92), (0.0095, 0.0014, 1.00)]
    for cx, cy, cz, rx, ry, rz in coin_spots:
        add_lathe(coins, coin_prof, segs=22, offset=(cx, cy, cz), rot_deg=(rx, ry, rz), cap_bottom=True, cap_top=True)

    return [finalize_mesh(pouch), finalize_mesh(cord), finalize_mesh(coins)]


def build_trelic_soul_bell() -> list[MeshData]:
    # Graveyard Toll Bell — charred oak gallows + wrought-iron chain & brackets + true hollow open bronze bell + glowing crack & clapper
    timber = MeshData("GallowsPost")
    add_rounded_box(timber, (-0.022, 0.050, 0.0), (0.0066, 0.050, 0.0066), bevel=0.0018, subdiv=4, ao_bot=0.32, ao_top=0.88)
    add_rounded_box(timber, (-0.002, 0.097, 0.0), (0.028, 0.0064, 0.0064), bevel=0.0018, subdiv=4, ao_bot=0.52, ao_top=0.95)
    add_rounded_box(timber, (-0.012, 0.084, 0.0), (0.0044, 0.016, 0.0044), bevel=0.0012, subdiv=3, rot_deg=(0.0, 0.0, -45.0), ao_bot=0.48, ao_top=0.85)

    iron = MeshData("IronBraces")
    add_rounded_box(iron, (-0.022, 0.097, 0.0), (0.0078, 0.0078, 0.0078), bevel=0.0014, subdiv=3)
    add_rounded_box(iron, (-0.022, 0.006, 0.0), (0.012, 0.0065, 0.012), bevel=0.0016, subdiv=3)
    # 3 interlocking chain links suspending bell cleanly from gallows beam
    for li, ly, lrot in [(0, 0.092, (90.0, 0.0, 0.0)), (1, 0.0885, (0.0, 90.0, 0.0)), (2, 0.085, (90.0, 0.0, 0.0))]:
        add_torus(iron, (0.012, ly, 0.0), 0.0042, 0.0014, 16, 8, rot_deg=lrot)

    bell = MeshData("BronzeBell")
    # Single continuous closed hollow-bell profile: inner dome -> rounded bottom lip -> outer flared wall -> crown
    # Ordered so outward normals point inward on inner vault, downward on bottom lip, outward on outer wall!
    hollow_bell_prof = [
        # Inner vault descending from crown to lip (radius increases as Y decreases -> normals point IN/DOWN!)
        (0.0012, 0.080, 0.25),
        (0.0082, 0.077, 0.30),
        (0.0122, 0.068, 0.36),
        (0.0148, 0.055, 0.42),
        (0.0180, 0.043, 0.50),
        (0.0228, 0.034, 0.62),
        # Rounded bottom rim lip
        (0.0248, 0.031, 0.78),
        (0.0274, 0.0305, 0.88),
        (0.0290, 0.0325, 1.00),
        # Outer wall ascending (+Y)
        (0.0252, 0.0375, 0.96),
        (0.0200, 0.049, 0.90),
        (0.0168, 0.063, 0.94),
        (0.0142, 0.076, 0.94),
        (0.0086, 0.083, 0.88),
        (0.0012, 0.0845, 0.72),
    ]
    add_lathe(bell, hollow_bell_prof, segs=36, offset=(0.012, 0.0, 0.0), cap_bottom=False, cap_top=False, uv_v_scale=1.35)
    # Gothic relief bands around shoulder and soundbow
    add_torus(bell, (0.012, 0.0355, 0.0), 0.0266, 0.0021, 32, 8)
    add_torus(bell, (0.012, 0.0720, 0.0), 0.0148, 0.0015, 28, 8)

    clapper = MeshData("SoulClapper")
    add_swept_3d(clapper, [(0.012, 0.076, 0.0), (0.012, 0.031, 0.0)], [0.0017, 0.0020], segs=8)
    add_ellipsoid(clapper, (0.012, 0.027, 0.0), (0.0072, 0.0090, 0.0072), 14, 10, ao_bot=0.75, ao_top=1.0)
    # Glowing carved spectral crack along front wall of bell
    crack_pts = [(0.012, 0.068, 0.0155), (0.015, 0.056, 0.0185), (0.010, 0.044, 0.0228), (0.013, 0.034, 0.0268)]
    add_swept_3d(clapper, crack_pts, [0.0014, 0.0022, 0.0018, 0.0012], segs=8)

    return [finalize_mesh(timber), finalize_mesh(iron), finalize_mesh(bell), finalize_mesh(clapper)]


def build_trelic_censer() -> list[MeshData]:
    # Alchemist's Ember Censer — forged iron crane tripod + 3 delicate link chains + pierced lattice brass sphere + glowing coal core
    crane = MeshData("IronCrane")
    # Tripod iron feet + curved goose-neck arm
    for fi in range(3):
        a = fi * (math.tau / 3.0) + 2.2
        f_pts = [(-0.020, 0.012, 0.0), (-0.020 + math.cos(a) * 0.016, 0.005, math.sin(a) * 0.016), (-0.020 + math.cos(a) * 0.022, 0.0015, math.sin(a) * 0.022)]
        add_swept_3d(crane, f_pts, [0.0026, 0.0022, 0.0018], segs=8)
    arm_pts = [
        (-0.020, 0.008, 0.0), (-0.022, 0.048, 0.0), (-0.020, 0.088, 0.0),
        (-0.010, 0.104, 0.0), (0.006, 0.106, 0.0), (0.014, 0.098, 0.0),
    ]
    add_swept_3d(crane, arm_pts, [0.0036, 0.0032, 0.0029, 0.0026, 0.0024, 0.0020], segs=10)
    add_torus(crane, (0.014, 0.094, 0.0), 0.0042, 0.0014, 14, 6, rot_deg=(0.0, 90.0, 0.0))

    chains = MeshData("CenserChains")
    cx, cz = 0.014, 0.0
    for ci in range(3):
        a = ci * (math.tau / 3.0)
        p_top = (cx, 0.092, cz)
        p_bot = (cx + math.cos(a) * 0.016, 0.056, cz + math.sin(a) * 0.016)
        for li in range(5):
            t = (li + 0.5) / 5.0
            lp = (p_top[0] + (p_bot[0] - p_top[0]) * t, p_top[1] + (p_bot[1] - p_top[1]) * t, p_top[2] + (p_bot[2] - p_top[2]) * t)
            add_torus(chains, lp, 0.0026, 0.0009, 12, 6, rot_deg=(0.0 if li % 2 == 0 else 90.0, math.degrees(a), 0.0))

    brass = MeshData("BrassCenser")
    # Lower solid brass bowl + equatorial scalloped belt + arched lattice cage ribs + top crown finial
    bowl_prof = [
        (0.000, 0.025, 0.45), (0.005, 0.028, 0.72), (0.016, 0.036, 0.88),
        (0.022, 0.047, 0.98), (0.023, 0.052, 1.00), (0.020, 0.052, 0.65),
        (0.012, 0.040, 0.35), (0.000, 0.036, 0.25),
    ]
    add_lathe(brass, bowl_prof, segs=30, offset=(cx, 0.0, cz), cap_bottom=True, cap_top=False)
    add_torus(brass, (cx, 0.051, cz), 0.0225, 0.0022, 28, 8)
    # 6 arched openwork lattice cage ribs over glowing core
    for ri in range(6):
        a = ri * (math.tau / 6.0)
        rib_pts = []
        for s in range(10):
            t = s / 9.0
            phi = t * math.pi * 0.5
            r = 0.022 * math.cos(phi)
            y = 0.051 + 0.023 * math.sin(phi)
            rib_pts.append((cx + math.cos(a) * r, y, cz + math.sin(a) * r))
        add_swept_3d(brass, rib_pts, [0.0018] * 10, segs=6)
    add_ellipsoid(brass, (cx, 0.075, cz), (0.005, 0.006, 0.005), 10, 8)

    coals = MeshData("EmberCoals")
    def coal_crags(lx, ly, lz, uf, vf, th, ph):
        bump = 1.0 + 0.14 * math.sin(th * 7.0) * math.cos(vf * 12.0)
        return (lx * bump, ly * bump, lz * bump, 0.75 + 0.25 * vf)
    add_ellipsoid(coals, (cx, 0.053, cz), (0.0165, 0.0145, 0.0165), 20, 14, mod_fn=coal_crags)

    return [finalize_mesh(crane), finalize_mesh(chains), finalize_mesh(brass), finalize_mesh(coals)]


def build_trelic_phoenix_box() -> list[MeshData]:
    # Phoenix Ember Reliquary — brass-bound ebony chest with open hinged lid + phoenix wing brass reliefs + curling ember plume
    chest = MeshData("ChestBody")
    # Hollow open box (4 thick side walls + bottom base)
    add_rounded_box(chest, (0.0, 0.005, 0.0), (0.032, 0.005, 0.022), bevel=0.0016, subdiv=4, ao_bot=0.35, ao_top=0.80)
    add_rounded_box(chest, (0.0, 0.017, 0.019), (0.031, 0.012, 0.0032), bevel=0.0010, subdiv=4)
    add_rounded_box(chest, (0.0, 0.017, -0.019), (0.031, 0.012, 0.0032), bevel=0.0010, subdiv=4)
    add_rounded_box(chest, (-0.028, 0.017, 0.0), (0.0032, 0.012, 0.018), bevel=0.0010, subdiv=4)
    add_rounded_box(chest, (0.028, 0.017, 0.0), (0.0032, 0.012, 0.018), bevel=0.0010, subdiv=4)
    # Hinged open arched ebony chest lid leaning back at (-48 deg around hinge z=-0.019, y=0.029)
    add_rounded_box(chest, (0.0, 0.044, -0.029), (0.032, 0.0045, 0.021), bevel=0.0016, subdiv=5, rot_deg=(-52.0, 0.0, 0.0))

    brass = MeshData("ChestBrass")
    # Brass corner straps, lock hasp, hinge barrels & phoenix wing reliefs on front/sides
    for bx in (-0.024, 0.024):
        add_rounded_box(brass, (bx, 0.016, 0.0215), (0.0032, 0.013, 0.0016), bevel=0.0006, subdiv=3)
        add_rounded_box(brass, (bx, 0.016, -0.0215), (0.0032, 0.013, 0.0016), bevel=0.0006, subdiv=3)
    add_rounded_box(brass, (0.0, 0.019, 0.0222), (0.0065, 0.0085, 0.0020), bevel=0.0008, subdiv=3)  # lock plate
    add_torus(brass, (0.0, 0.016, 0.024), 0.0035, 0.0010, 14, 6, rot_deg=(90.0, 0.0, 0.0))
    # Winged phoenix crest embossed on open lid interior & front
    for sx in (-1.0, 1.0):
        w_pts = [(0.0, 0.018, 0.0226), (sx * 0.009, 0.021, 0.0228), (sx * 0.018, 0.024, 0.0224)]
        add_swept_3d(brass, w_pts, [0.0020, 0.0018, 0.0012], segs=6)

    plume = MeshData("PhoenixPlume")
    # Molten ember core inside chest + 5 curling flame-plume tongues arcing gracefully upward
    add_ellipsoid(plume, (0.0, 0.020, 0.0), (0.021, 0.009, 0.012), 20, 12, ao_bot=0.72, ao_top=1.0)
    plume_curves = [
        ([(0.0, 0.024, 0.0), (-0.004, 0.044, 0.002), (0.005, 0.066, -0.002), (-0.002, 0.088, 0.001)], 0.0068),
        ([(-0.008, 0.022, 0.004), (-0.016, 0.042, 0.008), (-0.012, 0.062, 0.004), (-0.018, 0.078, -0.002)], 0.0048),
        ([(0.008, 0.022, -0.003), (0.016, 0.040, -0.006), (0.013, 0.058, 0.002), (0.019, 0.074, 0.006)], 0.0048),
        ([(-0.003, 0.024, -0.006), (-0.009, 0.046, -0.010), (-0.004, 0.064, -0.006)], 0.0040),
        ([(0.004, 0.024, 0.006), (0.010, 0.045, 0.010), (0.006, 0.062, 0.005)], 0.0040),
    ]
    for pts, r0 in plume_curves:
        n = len(pts)
        rads = [r0 * (1.0 - (i / max(1, n - 1)) * 0.82) for i in range(n)]
        add_swept_3d(plume, pts, rads, segs=10, aspect_b=0.65)

    return [finalize_mesh(chest), finalize_mesh(brass), finalize_mesh(plume)]


def build_handdrawn_oathblade() -> list[MeshData]:
    # Fullered beveled steel sword + ornate engraved brass crossguard & pommel + wire-wrapped leather grip + oath gem
    blade = MeshData("BladeSteel")
    def sword_shape(px, py, pz):
        t = _clamp01((py + 0.28) / 0.64)
        # Leafed fuller edge + sharp tip over top 22%
        w = 1.0 if t < 0.78 else max(0.03, (1.0 - t) / 0.22)
        edge = max(0.18, 1.0 - (abs(px) / 0.028) ** 1.3)
        fuller = 0.0030 * math.exp(-(px / 0.006) ** 2) * (1.0 - max(0.0, t - 0.65) / 0.35)
        ao = 0.66 if fuller > 0.0012 else (0.98 if abs(px) > 0.016 else 0.90)
        return (px * w, py, pz * edge - math.copysign(fuller, pz) * 0.45, ao)
    add_rounded_box(blade, (0.0, 0.38, 0.0), (0.026, 0.32, 0.0085), bevel=0.0018, subdiv=8, sculpt_fn=sword_shape)

    guard = MeshData("BrassGuard")
    # Swept arched medieval crossguard + heavy scent-stopper pommel
    g_pts = [(-0.145, 0.068, 0.0), (-0.078, 0.054, 0.0), (0.0, 0.052, 0.0), (0.078, 0.054, 0.0), (0.145, 0.068, 0.0)]
    add_swept_3d(guard, g_pts, [0.007, 0.011, 0.016, 0.011, 0.007], segs=12, aspect_b=1.2)
    add_lathe(guard, [
        (0.000, -0.195, 0.65), (0.018, -0.182, 0.90), (0.030, -0.165, 1.00),
        (0.024, -0.148, 0.88), (0.014, -0.140, 0.55), (0.000, -0.138, 0.45)
    ], segs=24)

    grip = MeshData("LeatherGrip")
    add_lathe(grip, [
        (0.014, -0.140, 0.62), (0.017, -0.090, 0.88), (0.018, -0.040, 0.92),
        (0.016, 0.010, 0.88), (0.017, 0.048, 0.60)
    ], segs=20, flute_amp=0.03, flute_freq=8)
    for wy in (-0.115, -0.070, -0.025, 0.020):
        add_torus(guard, (0.0, wy, 0.0), 0.0178, 0.0022, 20, 8)

    gem = MeshData("OathGem")
    add_ellipsoid(gem, (0.0, 0.052, 0.014), (0.015, 0.019, 0.008), 14, 10)
    add_ellipsoid(gem, (0.0, 0.052, -0.014), (0.015, 0.019, 0.008), 14, 10)

    return [finalize_mesh(blade), finalize_mesh(guard), finalize_mesh(grip), finalize_mesh(gem)]


# ==============================================================================
# 4. MAIN PIPELINE
# ==============================================================================

def main() -> None:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    SWORD_DIR.mkdir(parents=True, exist_ok=True)

    print("1/2 Generating hand-inked woodcut textures...")
    _gen_ivory_bone_tex(TEX_DIR / "dice_ivory_ink.png")
    _gen_leather_stitched_tex(TEX_DIR / "dice_leather_ink.png", (98.0, 56.0, 34.0))
    _gen_slate_stone_tex(TEX_DIR / "rune_slate_ink.png")
    _gen_rune_glow_tex(TEX_DIR / "rune_glyph_ink.png")
    _gen_silver_filigree_tex(TEX_DIR / "goblet_silver_ink.png")
    _gen_blood_wine_tex(TEX_DIR / "blood_wine_ink.png")
    _gen_whetstone_granite_tex(TEX_DIR / "whetstone_granite_ink.png")
    _gen_forged_steel_tex(TEX_DIR / "forged_steel_ink.png")
    _gen_gold_sand_tex(TEX_DIR / "gold_sand_ink.png")
    _gen_glass_ink_tex(TEX_DIR / "hourglass_glass_ink.png")
    _gen_leather_stitched_tex(TEX_DIR / "purse_leather_ink.png", (118.0, 64.0, 32.0))
    _gen_florin_gold_tex(TEX_DIR / "florin_gold_ink.png")
    _gen_cracked_bronze_tex(TEX_DIR / "cracked_bronze_ink.png")
    _gen_leather_stitched_tex(TEX_DIR / "gallows_timber_ink.png", (86.0, 54.0, 34.0))
    _gen_ember_coal_tex(TEX_DIR / "ember_coal_ink.png")
    _gen_leather_stitched_tex(TEX_DIR / "reliquary_ebony_ink.png", (52.0, 34.0, 26.0))
    _gen_ember_plume_tex(TEX_DIR / "ember_plume_ink.png")

    print("2/2 Sculpting & exporting 9 TRELIC_*.glb + handdrawn_oathblade.glb...")
    relic_builders = {
        "TRELIC_HOLLOW_MASK": build_trelic_hollow_mask,
        "TRELIC_STAR_BOW": build_trelic_star_bow,
        "TRELIC_BLOOD_SEAL": build_trelic_blood_seal,
        "TRELIC_IRON_CHAIN": build_trelic_iron_chain,
        "TRELIC_ASH_GLASS": build_trelic_ash_glass,
        "TRELIC_GOLD_SCALES": build_trelic_gold_scales,
        "TRELIC_SOUL_BELL": build_trelic_soul_bell,
        "TRELIC_CENSER": build_trelic_censer,
        "TRELIC_PHOENIX_BOX": build_trelic_phoenix_box,
    }
    for rel_id, fn in relic_builders.items():
        meshes = fn()
        out_p = MODEL_DIR / f"{rel_id}.glb"
        export_glb(meshes, out_p)
        tot_tris = sum(len(m.indices) // 3 for m in meshes)
        tot_verts = sum(len(m.positions) for m in meshes)
        print(f"  + {rel_id}.glb: {len(meshes)} meshes, {tot_verts} verts, {tot_tris} tris ({out_p.stat().st_size} bytes)")

    sword_meshes = build_handdrawn_oathblade()
    sword_p = SWORD_DIR / "handdrawn_oathblade.glb"
    export_glb(sword_meshes, sword_p)
    print(f"  + handdrawn_oathblade.glb: {len(sword_meshes)} meshes, {sum(len(m.indices)//3 for m in sword_meshes)} tris ({sword_p.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
