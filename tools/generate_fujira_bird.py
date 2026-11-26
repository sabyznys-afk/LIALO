"""Generate sculpted articulated 3D all-black raptor GLB + feather texture for Fujira Studios Intro (v0.197 Priorita #4)."""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

TOOLS_DIR = os.path.dirname(__file__)
ROOT = os.path.dirname(TOOLS_DIR)
sys.path.insert(0, TOOLS_DIR)

from generate_all_handdrawn_relics import (
    MeshData,
    add_ellipsoid,
    add_lathe,
    add_swept_3d,
    export_glb,
    finalize_mesh,
)

TEX_PATH = os.path.join(ROOT, "assets", "textures", "fujira_feather_ink.png")
GLB_PATH = os.path.join(ROOT, "assets", "models", "fujira_black_bird.glb")


def generate_feather_texture():
    os.makedirs(os.path.dirname(TEX_PATH), exist_ok=True)
    rng = random.Random(40197)
    img = Image.new("RGB", (1024, 1024), (16, 17, 22))
    d = ImageDraw.Draw(img)
    # Feather shafts & fine barbules with subtle midnight-indigo sheen
    for x in range(0, 1024, 16):
        d.line([(x, 0), (x, 1024)], fill=(28, 30, 38), width=2)
        for y in range(0, 1024, 8):
            barb = rng.randint(12, 26)
            col = (24 + rng.randint(0, 10), 26 + rng.randint(0, 10), 34 + rng.randint(0, 14))
            d.line([(x, y), (x - 8, y + 6)], fill=col, width=1)
            d.line([(x, y), (x + 8, y + 6)], fill=col, width=1)
    img = img.filter(ImageFilter.SMOOTH)
    img.save(TEX_PATH)
    print("Generated", TEX_PATH)


def _build_wing_in(side: float) -> MeshData:
    nm = "WingL_In" if side < 0 else "WingR_In"
    m = MeshData(nm)
    # Aerodynamic cambered inner wing arm + layered covert feathers
    pts = [
        (0.02, 0.0, 0.0),
        (0.0, 0.022, side * 0.16),
        (-0.02, 0.014, side * 0.32),
    ]
    add_swept_3d(m, pts, [0.068, 0.055, 0.042], segs=12, aspect_b=0.28)
    for fi in range(5):
        fz = side * (0.06 + fi * 0.055)
        f_pts = [
            (0.01, 0.010, fz),
            (-0.09, 0.004, fz + side * 0.015),
            (-0.19, -0.004, fz + side * 0.025),
        ]
        add_swept_3d(m, f_pts, [0.026, 0.020, 0.006], segs=8, aspect_b=0.18)
    return finalize_mesh(m)


def _build_wing_out(side: float) -> MeshData:
    nm = "WingL_Out" if side < 0 else "WingR_Out"
    m = MeshData(nm)
    # Outer pinion + 7 individually tapered swept primary flight feathers
    pts = [
        (0.0, 0.0, 0.0),
        (-0.04, 0.012, side * 0.18),
        (-0.10, 0.006, side * 0.36),
    ]
    add_swept_3d(m, pts, [0.040, 0.028, 0.014], segs=10, aspect_b=0.25)
    for pi in range(7):
        t = pi / 6.0
        pz = side * (0.04 + pi * 0.052)
        length = 0.28 - t * 0.06
        f_pts = [
            (-0.02 - t * 0.04, 0.008, pz),
            (-0.02 - t * 0.04 - length * 0.55, 0.004, pz + side * 0.035),
            (-0.02 - t * 0.04 - length, 0.012 * (1.0 - t * 0.5), pz + side * 0.065),
        ]
        add_swept_3d(m, f_pts, [0.020, 0.014, 0.003], segs=8, aspect_b=0.16)
    return finalize_mesh(m)


def build_bird_glb():
    # Body (Torso + Neck + Head + Hooked Beak + Tucked Talons)
    body = MeshData("Body")
    # Aerodynamic raptor fuselage swept along +X (head at +X, tail at -X)
    spine = [
        (-0.22, -0.01, 0.0),
        (-0.08, 0.01, 0.0),
        (0.06, 0.02, 0.0),
        (0.20, 0.06, 0.0),
        (0.29, 0.09, 0.0),
    ]
    add_swept_3d(body, spine, [0.045, 0.092, 0.105, 0.062, 0.048], segs=16, aspect_b=0.82)
    # Crested head & fierce brow
    add_ellipsoid(body, (0.31, 0.10, 0.0), (0.068, 0.052, 0.048), 14, 10, ao_bot=0.6, ao_top=1.0)
    # Hooked raptor beak
    beak_pts = [
        (0.36, 0.098, 0.0),
        (0.41, 0.094, 0.0),
        (0.445, 0.080, 0.0),
        (0.452, 0.066, 0.0),
    ]
    add_swept_3d(body, beak_pts, [0.024, 0.016, 0.009, 0.002], segs=8, aspect_b=0.75)
    # Tucked talons
    for tz in (-0.036, 0.036):
        add_swept_3d(body, [(-0.04, -0.06, tz), (-0.12, -0.082, tz), (-0.16, -0.072, tz)], [0.016, 0.012, 0.005], segs=8)

    # TailFan (7 radiating sculpted tail feathers)
    tail = MeshData("TailFan")
    for ti in range(-3, 4):
        ang = ti * 0.14
        t_pts = [
            (0.0, 0.0, 0.0),
            (-0.14 * math.cos(ang), 0.006, 0.14 * math.sin(ang)),
            (-0.30 * math.cos(ang), 0.012, 0.30 * math.sin(ang)),
        ]
        add_swept_3d(tail, t_pts, [0.022, 0.026, 0.008], segs=8, aspect_b=0.14)

    meshes = [
        finalize_mesh(body),
        _build_wing_in(-1.0),
        _build_wing_out(-1.0),
        _build_wing_in(1.0),
        _build_wing_out(1.0),
        finalize_mesh(tail),
    ]
    from pathlib import Path
    os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
    export_glb(meshes, Path(GLB_PATH))
    print("Exported", GLB_PATH)


if __name__ == "__main__":
    generate_feather_texture()
    build_bird_glb()
