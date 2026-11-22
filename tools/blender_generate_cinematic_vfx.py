"""
Blender 5.3 headless 3D Bleach TYBW-Scale Cinematic VFX Generator for LIALO:
Generates 8 monumental, multi-phase sculpted 3D animated VFX rigs (5.75s - 6.33s @ 24fps) in:
  D:/downpour-godot/assets/models/vfx/
    1. cinematic_vampire_crimson.glb  (6.00s / 144f @ 24fps) - Crimson Ink-Blood Vortex & Giant Fang Jaws
    2. cinematic_storm_tempest.glb    (5.92s / 142f @ 24fps) - Towering Storm Coils & 8-Bolt Thunder Barrage
    3. cinematic_phoenix_inferno.glb  (6.25s / 150f @ 24fps) - 2.4m Wingspan Solar Phoenix & Ink-Flame Pillar
    4. cinematic_shadow_hex.glb       (5.83s / 140f @ 24fps) - Abyssal Arcane Eye, 12 Mirror Monoliths & Curse Chains
    5. cinematic_midas_vault.glb      (6.33s / 152f @ 24fps) - Sovereign Crown Stamp, 3 Astrolabes & 24-Florin Fountain
    6. cinematic_rival_slam.glb       (5.75s / 138f @ 24fps) - Colossal War-Crest Halberd Slam & Seismic Crater
    7. cinematic_tybw_getsuga.glb     (6.00s / 144f @ 24fps) - NEW: Bankai Crescent / Getsuga Cataclysm
    8. cinematic_tybw_quincy.glb      (6.00s / 144f @ 24fps) - NEW: Quincy Licht Regen / Starlight Volley

All 8 GLBs feature:
  - 1.6x-2.2x arena scale (1.8m-2.6m span, 1.8m-2.5m towering pillars & sky mandalas)
  - Bleach TYBW high-contrast aesthetic: pitch-black sumi-ink cores (Mat_CineInkBlack) wrapped
    in blazing neon/crimson/gold/cyan spiritual rims (Mat_CineAccent / Mat_CineGlow / Mat_CineWhiteHot)
  - 4-Phase multi-stage choreography:
      Phase 1 (0.0s - 1.4s): Buildup & spiritual gathering
      Phase 2 (1.4s - 3.3s): Towering manifestation, orbital lock & anticipation compression
      Phase 3 (3.4s - 4.2s): Explosive climax expansion / slash / dive volley
      Phase 4 (4.2s - 6.0s): Dramatic lingering aftermath & graceful dissipation
  - Full compatibility with CinematicDirector (_tint_vfx_materials & AnimationPlayer) and verify_cinematic_system.gd.

Renders an 8-panel (4x2, 2240x960) dark-arena EEVEE showcase contact sheet to:
  C:/Users/arnos/.gemini/antigravity/brain/a20e3f18-d942-46fa-80e3-721c54108b6d/scratch/preview_tybw_vfx.png

Run via:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_cinematic_vfx.py
"""

import math
import pathlib
import sys
import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

ROOT_DIR = pathlib.Path(r"D:\downpour-godot")
BLENDER_VFX_DIR = ROOT_DIR / "tools" / "blender_vfx"
if str(BLENDER_VFX_DIR) not in sys.path:
    sys.path.insert(0, str(BLENDER_VFX_DIR))

import blender_common as bc

OUT_VFX_DIR = ROOT_DIR / "assets" / "models" / "vfx"
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\scratch\preview_tybw_vfx.png"
)


# =============================================================================
# SHARED BLEACH TYBW HIGH-CONTRAST PBR & SPIRITUAL ENERGY PALETTE
# =============================================================================

def make_shared_palette(accent_rgb, glow_rgb, emit_str: float = 2.35):
    """
    Create Bleach TYBW high-contrast materials:
      - Mat_CineAccent / Mat_CineGlow keep exact names for CinematicDirector runtime tinting.
      - Mat_CineInkBlack (pitch-black sumi-ink void core) and Mat_CineWhiteHot (blinding edge core)
        stay untinted so every cinematic bursts with dramatic manga/anime contrast!
    """
    mat_accent = bc.make_pbr_mat(
        "Mat_CineAccent",
        base_color=(accent_rgb[0] * 0.45, accent_rgb[1] * 0.45, accent_rgb[2] * 0.45, 1.0),
        metallic=0.25,
        roughness=0.18,
        emission_color=(*accent_rgb, 1.0),
        emission_strength=emit_str,
    )
    mat_glow = bc.make_pbr_mat(
        "Mat_CineGlow",
        base_color=(glow_rgb[0] * 0.55, glow_rgb[1] * 0.55, glow_rgb[2] * 0.55, 1.0),
        metallic=0.15,
        roughness=0.12,
        emission_color=(*glow_rgb, 1.0),
        emission_strength=emit_str * 1.45,
    )
    mat_ink = bc.make_pbr_mat(
        "Mat_CineInkBlack",
        base_color=(0.003, 0.003, 0.005, 1.0),
        metallic=0.12,
        roughness=0.18,
    )
    mat_white_hot = bc.make_pbr_mat(
        "Mat_CineWhiteHot",
        base_color=(1.0, 0.99, 0.97, 1.0),
        metallic=0.0,
        roughness=0.08,
        emission_color=(1.0, 0.98, 0.95, 1.0),
        emission_strength=4.2,
    )
    mat_brass = bc.make_pbr_mat(
        "Mat_CineBrass",
        base_color=(0.48, 0.28, 0.06, 1.0),
        metallic=0.90,
        roughness=0.24,
        emission_color=(0.16, 0.08, 0.01, 1.0),
        emission_strength=0.22,
    )
    mat_gold = bc.make_pbr_mat(
        "Mat_CineGold",
        base_color=(0.82, 0.54, 0.08, 1.0),
        metallic=0.95,
        roughness=0.16,
        emission_color=(0.52, 0.30, 0.02, 1.0),
        emission_strength=0.38,
    )
    mat_obsidian = bc.make_pbr_mat(
        "Mat_CineObsidian",
        base_color=(0.018, 0.016, 0.026, 1.0),
        metallic=0.42,
        roughness=0.20,
    )
    mat_iron = bc.make_pbr_mat(
        "Mat_CineIron",
        base_color=(0.085, 0.092, 0.112, 1.0),
        metallic=0.88,
        roughness=0.28,
    )
    mat_silver = bc.make_pbr_mat(
        "Mat_CineSilver",
        base_color=(0.76, 0.82, 0.90, 1.0),
        metallic=0.94,
        roughness=0.16,
        emission_color=(0.25, 0.40, 0.52, 1.0),
        emission_strength=0.25,
    )
    return {
        "accent": mat_accent,
        "glow": mat_glow,
        "ink": mat_ink,
        "white": mat_white_hot,
        "brass": mat_brass,
        "gold": mat_gold,
        "obsidian": mat_obsidian,
        "iron": mat_iron,
        "silver": mat_silver,
    }


# =============================================================================
# SCULPTED TYBW GEOMETRY BUILDERS
# =============================================================================

def create_curved_fang(
    name: str,
    height: float = 1.05,
    base_r: float = 0.125,
    curve_x: float = -0.38,
    sides: int = 12,
    rings: int = 14,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Create a colossal sculpted curved fang/claw tapering to a razor tip."""
    bm = bmesh.new()
    ring_verts = []
    for ri in range(rings):
        u = float(ri) / float(rings)
        z = u * height
        r = max(0.004, base_r * (1.0 - (u ** 1.15) * 0.92) * (1.0 + 0.18 * math.sin(u * math.pi)))
        cx = (u ** 1.65) * curve_x
        tilt = u * 0.52
        row = []
        for si in range(sides):
            ang = (float(si) / float(sides)) * math.tau
            rx = r * (0.78 if math.cos(ang) > 0.3 else 1.10)
            ry = r * 0.86
            px = cx + math.cos(ang) * rx * math.cos(tilt)
            py = math.sin(ang) * ry
            pz = z - math.cos(ang) * rx * math.sin(tilt)
            row.append(bm.verts.new((px, py, pz)))
        ring_verts.append(row)

    v_tip = bm.verts.new((curve_x * 1.16, 0.0, height * 1.04))
    for ri in range(rings - 1):
        for si in range(sides):
            sn = (si + 1) % sides
            bm.faces.new((ring_verts[ri][si], ring_verts[ri][sn], ring_verts[ri + 1][sn], ring_verts[ri + 1][si]))
    for si in range(sides):
        sn = (si + 1) % sides
        bm.faces.new((ring_verts[-1][si], ring_verts[-1][sn], v_tip))
    bm.faces.new(list(reversed(ring_verts[0])))
    return bc.finalize_bmesh(name, bm, mat=mat, smooth=True, parent=parent)


def create_jagged_lightning_bolt(
    name: str,
    knots: list,
    radii: list,
    sides: int = 6,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Create a sharp faceted 3D jagged lightning bolt mesh through 3D knot coordinates."""
    bm = bmesh.new()
    rings = []
    for idx, (pt, rad) in enumerate(zip(knots, radii)):
        p = Vector(pt)
        if idx == 0:
            tang = (Vector(knots[1]) - p).normalized()
        elif idx == len(knots) - 1:
            tang = (p - Vector(knots[idx - 1])).normalized()
        else:
            tang = (Vector(knots[idx + 1]) - Vector(knots[idx - 1])).normalized()
        up = Vector((1.0, 0.0, 0.0)) if abs(tang.z) > 0.9 else Vector((0.0, 0.0, 1.0))
        side = tang.cross(up).normalized()
        binorm = side.cross(tang).normalized()
        row = []
        r_safe = max(0.004, float(rad))
        for si in range(sides):
            a = (float(si) / float(sides)) * math.tau
            flute = 1.26 if (si % 2 == 0) else 0.64
            v = p + (side * math.cos(a) + binorm * math.sin(a)) * (r_safe * flute)
            row.append(bm.verts.new(v))
        rings.append(row)
    for i in range(len(rings) - 1):
        for si in range(sides):
            sn = (si + 1) % sides
            bm.faces.new((rings[i][si], rings[i][sn], rings[i + 1][sn], rings[i + 1][si]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(list(rings[-1]))
    return bc.finalize_bmesh(name, bm, mat=mat, smooth=False, parent=parent)


def create_feather_blade(
    name: str,
    length: float = 1.10,
    width: float = 0.21,
    thickness: float = 0.036,
    curve_z: float = 0.26,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Create a sculpted diamond-section curved phoenix wing feather extending along +X."""
    bm = bmesh.new()
    steps = 12
    rings = []
    for i in range(steps):
        u = float(i) / float(steps)
        x = u * length
        z = (u ** 1.55) * curve_z
        w = width * math.sin(max(0.08, u * 0.92) * math.pi)
        th = thickness * (1.0 - 0.62 * u)
        v_top = bm.verts.new((x, 0.0, z + w * 0.5))
        v_front = bm.verts.new((x, -th * 0.5, z))
        v_bot = bm.verts.new((x, 0.0, z - w * 0.42))
        v_back = bm.verts.new((x, th * 0.5, z))
        rings.append((v_top, v_front, v_bot, v_back))
    v_tip = bm.verts.new((length * 1.10, 0.0, curve_z * 1.18))
    for i in range(steps - 1):
        for k in range(4):
            kn = (k + 1) % 4
            bm.faces.new((rings[i][k], rings[i][kn], rings[i + 1][kn], rings[i + 1][k]))
    for k in range(4):
        kn = (k + 1) % 4
        bm.faces.new((rings[-1][k], rings[-1][kn], v_tip))
    bm.faces.new(list(reversed(rings[0])))
    return bc.finalize_bmesh(name, bm, mat=mat, smooth=False, parent=parent)


def create_mirror_shard(
    name: str,
    w: float = 0.34,
    h: float = 0.72,
    th: float = 0.036,
    skew: float = 0.07,
    mat_face=None,
    mat_rim=None,
    parent=None,
) -> bpy.types.Object:
    """Create a fractured hexagonal obsidian mirror monolith shard with glowing inner mirror face."""
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    bm = bmesh.new()
    pts_2d = [
        (0.0, -h * 0.52),
        (w * 0.54, -h * 0.18 + skew),
        (w * 0.44, h * 0.28 + skew),
        (0.0, h * 0.52),
        (-w * 0.50, h * 0.22 - skew),
        (-w * 0.42, -h * 0.24 - skew),
    ]
    front_outer = [bm.verts.new((px, -th * 0.5, pz)) for (px, pz) in pts_2d]
    back_outer = [bm.verts.new((px, th * 0.5, pz)) for (px, pz) in pts_2d]
    n = len(pts_2d)
    for i in range(n):
        inext = (i + 1) % n
        bm.faces.new((front_outer[i], front_outer[inext], back_outer[inext], back_outer[i]))
    bm.faces.new(front_outer)
    bm.faces.new(list(reversed(back_outer)))
    bc.finalize_bmesh(name + "_Rim", bm, mat=mat_rim, smooth=False, parent=piv)

    bm_f = bmesh.new()
    f_pts = [bm_f.verts.new((px * 0.78, -th * 0.62, pz * 0.80)) for (px, pz) in pts_2d]
    b_pts = [bm_f.verts.new((px * 0.78, th * 0.62, pz * 0.80)) for (px, pz) in pts_2d]
    bm_f.faces.new(f_pts)
    bm_f.faces.new(list(reversed(b_pts)))
    bc.finalize_bmesh(name + "_Glass", bm_f, mat=mat_face, smooth=False, parent=piv)
    return piv


def create_heraldic_shield(
    name: str,
    w: float = 0.56,
    h: float = 0.70,
    th: float = 0.052,
    mat_body=None,
    mat_trim=None,
    parent=None,
) -> bpy.types.Object:
    """Create a colossal sculpted medieval heater shield with raised center ridge and gilded boss."""
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    bm = bmesh.new()
    profile = [
        (0.0, h * 0.48, -th * 0.35),
        (w * 0.50, h * 0.42, 0.0),
        (w * 0.48, h * 0.05, 0.0),
        (w * 0.32, -h * 0.28, 0.0),
        (0.0, -h * 0.52, -th * 0.35),
        (-w * 0.32, -h * 0.28, 0.0),
        (-w * 0.48, h * 0.05, 0.0),
        (-w * 0.50, h * 0.42, 0.0),
    ]
    v_front_c = bm.verts.new((0.0, 0.0, -th * 0.95))
    v_back_c = bm.verts.new((0.0, 0.0, th * 0.55))
    f_ring = [bm.verts.new((x, z, y - th * 0.42)) for (x, z, y) in profile]
    b_ring = [bm.verts.new((x, z, y + th * 0.42)) for (x, z, y) in profile]
    n = len(profile)
    for i in range(n):
        inext = (i + 1) % n
        bm.faces.new((v_front_c, f_ring[inext], f_ring[i]))
        bm.faces.new((v_back_c, b_ring[i], b_ring[inext]))
        bm.faces.new((f_ring[i], f_ring[inext], b_ring[inext], b_ring[i]))
    sh_obj = bc.finalize_bmesh(name + "_Body", bm, mat=mat_body, smooth=False, parent=piv)
    sh_obj.rotation_euler = (math.pi * 0.5, 0.0, 0.0)

    boss = bc.create_faceted_crystal(name + "_Boss", radius=w * 0.21, height=w * 0.32, sides=6, mat=mat_trim, parent=piv)
    boss.location = Vector((0.0, -th * 0.9, 0.0))
    boss.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    return piv


def create_ink_pillar(
    name: str,
    r_base: float = 0.42,
    r_mid: float = 0.24,
    r_top: float = 0.34,
    height: float = 2.15,
    flutes: int = 8,
    twist_rad: float = 2.2,
    mat_ink=None,
    mat_rim=None,
    parent=None,
) -> bpy.types.Object:
    """
    Create a towering Bleach TYBW fluted pitch-black sumi-ink spiritual pillar wrapped
    in razor-sharp twisted glowing spiritual energy ridges!
    """
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    levels = 16
    sides = flutes * 2

    # 1. Pitch-black fluted twisted ink column core
    bm = bmesh.new()
    rings = []
    for li in range(levels + 1):
        u = float(li) / float(levels)
        z = u * height
        if u < 0.35:
            t = u / 0.35
            rad = r_base * (1.0 - t) + r_mid * t
        else:
            t = (u - 0.35) / 0.65
            rad = r_mid * (1.0 - t) + r_top * t
        ang_off = u * twist_rad
        row = []
        for si in range(sides):
            a = (float(si) / float(sides)) * math.tau + ang_off
            fl = 1.24 if (si % 2 == 0) else 0.72
            row.append(bm.verts.new((math.cos(a) * rad * fl, math.sin(a) * rad * fl, z)))
        rings.append(row)
    for li in range(levels):
        for si in range(sides):
            sn = (si + 1) % sides
            bm.faces.new((rings[li][si], rings[li][sn], rings[li + 1][sn], rings[li + 1][si]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bc.finalize_bmesh(name + "_InkCore", bm, mat=mat_ink, smooth=True, parent=piv)

    # 2. High-contrast glowing outer energy mantle ribbons tracing the pillar crest flutes!
    if mat_rim is not None:
        for fi in range(3):
            bc.create_twisted_ribbon(
                f"{name}_EnergyVein_{fi}",
                radius_start=r_base * 1.18,
                radius_end=r_top * 1.16,
                height=height * 0.96,
                turns=1.15,
                width=0.055,
                thickness=0.018,
                steps=36,
                phase_deg=fi * 120.0,
                mat=mat_rim,
                parent=piv,
            )
    return piv


def create_shockwave_dome(
    name: str,
    radius: float = 1.25,
    height: float = 0.92,
    ribs: int = 12,
    mat_core=None,
    mat_rim=None,
    parent=None,
) -> bpy.types.Object:
    """Create a dramatic TYBW jagged hemispherical shockwave dome with ribbed ink & glowing energy arches."""
    piv = bc.create_empty(name + "_Pivot", parent=parent)

    # Equator jagged shockwave crown ring
    bc.create_ornate_ring(
        name + "_CrownRing", radius * 1.06, radius * 0.88, 0.045,
        notches=ribs, notch_depth=radius * 0.14, segments=ribs * 4, mat=mat_rim, parent=piv
    )

    # Arched dome energy meridian ribs meeting at apex
    bm = bmesh.new()
    for ri in range(ribs):
        a = (float(ri) / float(ribs)) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        tx, ty = -sa, ca
        steps = 9
        w = radius * 0.048
        th = radius * 0.025
        sec_list = []
        for s in range(steps + 1):
            u = float(s) / float(steps)
            el = u * (math.pi * 0.49)
            rr = math.cos(el) * radius
            zz = math.sin(el) * height
            taper = max(0.20, 1.0 - u * 0.72)
            c = Vector((ca * rr, sa * rr, zz))
            tang_w = Vector((tx, ty, 0.0)) * (w * taper)
            nrm = Vector((ca * math.cos(el), sa * math.cos(el), math.sin(el))).normalized() * (th * taper)
            sec_list.append((
                bm.verts.new(c + tang_w + nrm),
                bm.verts.new(c - tang_w + nrm),
                bm.verts.new(c - tang_w - nrm),
                bm.verts.new(c + tang_w - nrm),
            ))
        for s in range(steps):
            for k in range(4):
                kn = (k + 1) % 4
                bm.faces.new((sec_list[s][k], sec_list[s][kn], sec_list[s + 1][kn], sec_list[s + 1][k]))
        bm.faces.new(list(reversed(sec_list[0])))
        bm.faces.new(sec_list[-1])
    bc.finalize_bmesh(name + "_RibCage", bm, mat=mat_core if mat_core is not None else mat_rim, smooth=False, parent=piv)

    # Mid-altitude glowing latitude compression ring
    mid_ring = bc.create_ornate_ring(
        name + "_MidLatRing", radius * 0.74, radius * 0.66, 0.026,
        notches=ribs, notch_depth=radius * 0.06, segments=ribs * 3, mat=mat_rim, parent=piv
    )
    mid_ring.location = Vector((0.0, 0.0, height * 0.56))
    return piv


def create_crescent_blade_arc(
    name: str,
    radius: float = 1.25,
    span_deg: float = 162.0,
    width: float = 0.34,
    thick: float = 0.055,
    mat_ink=None,
    mat_edge=None,
    mat_white=None,
    parent=None,
) -> bpy.types.Object:
    """
    Create an iconic Bleach TYBW Getsuga Tensho sweeping 3D crescent blade wave:
      - Pitch-black sumi-ink razor core
      - Blazing crimson outer energy blade mantle
      - Blinding white-hot leading razor cutting edge!
    Constructed in the XY plane sweeping symmetrically around +Y.
    """
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    steps = 28
    half_span = math.radians(span_deg * 0.5)

    def build_crescent_layer(suffix, r_off, w_scale, th_scale, mat, jagged=0.0):
        bm = bmesh.new()
        rings = []
        for i in range(steps + 1):
            u = float(i) / float(steps)  # 0..1
            ang = math.pi * 0.5 - half_span + u * (half_span * 2.0)
            env = math.sin(u * math.pi) ** 0.72
            jag = 1.0 + jagged * math.sin(u * 26.0) * env
            w_cur = max(0.008, width * w_scale * env * jag)
            th_cur = max(0.004, thick * th_scale * env)
            r_out = radius + r_off + w_cur * 0.36
            r_in = radius + r_off - w_cur * 0.64
            r_mid = radius + r_off
            ca, sa = math.cos(ang), math.sin(ang)
            v_out = bm.verts.new((ca * r_out, sa * r_out, 0.0))
            v_top = bm.verts.new((ca * r_mid, sa * r_mid, th_cur * 0.5))
            v_in = bm.verts.new((ca * r_in, sa * r_in, 0.0))
            v_bot = bm.verts.new((ca * r_mid, sa * r_mid, -th_cur * 0.5))
            rings.append((v_out, v_top, v_in, v_bot))
        for i in range(steps):
            for k in range(4):
                kn = (k + 1) % 4
                bm.faces.new((rings[i][k], rings[i][kn], rings[i + 1][kn], rings[i + 1][k]))
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
        return bc.finalize_bmesh(f"{name}_{suffix}", bm, mat=mat, smooth=True, parent=piv)

    # Layer 1: Deep pitch-black ink crescent inner core
    build_crescent_layer("InkCore", r_off=-0.04, w_scale=0.82, th_scale=1.18, mat=mat_ink, jagged=0.05)
    # Layer 2: Blazing wide crimson outer energy wave (jagged spiritual fire!)
    build_crescent_layer("CrimsonWave", r_off=0.03, w_scale=1.16, th_scale=0.82, mat=mat_edge, jagged=0.14)
    # Layer 3: Razor blinding white-hot leading edge seam
    build_crescent_layer("WhiteEdge", r_off=0.12, w_scale=0.34, th_scale=0.52, mat=mat_white, jagged=0.06)
    return piv


def create_monolith_shard(
    name: str,
    w: float = 0.20,
    d: float = 0.14,
    h: float = 0.78,
    mat_body=None,
    mat_crack=None,
    parent=None,
) -> bpy.types.Object:
    """Create a brutalist fractured floating Bankai steel/obsidian monolith shard with glowing crack vein."""
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    bm = bmesh.new()
    # Irregular beveled 5-sided broken monolith prism
    pts_bot = [(-w * 0.45, -d * 0.35, -h * 0.46), (w * 0.48, -d * 0.42, -h * 0.52),
               (w * 0.52, d * 0.36, -h * 0.44), (-w * 0.12, d * 0.48, -h * 0.48), (-w * 0.52, d * 0.18, -h * 0.40)]
    pts_top = [(-w * 0.32, -d * 0.28, h * 0.44), (w * 0.38, -d * 0.32, h * 0.54),
               (w * 0.36, d * 0.28, h * 0.46), (-w * 0.08, d * 0.36, h * 0.50), (-w * 0.40, d * 0.14, h * 0.38)]
    vb = [bm.verts.new(p) for p in pts_bot]
    vt = [bm.verts.new(p) for p in pts_top]
    n = len(vb)
    for i in range(n):
        ni = (i + 1) % n
        bm.faces.new((vb[i], vb[ni], vt[ni], vt[i]))
    bm.faces.new(list(reversed(vb)))
    bm.faces.new(vt)
    bc.finalize_bmesh(name + "_Body", bm, mat=mat_body, smooth=False, parent=piv)

    if mat_crack is not None:
        vein = bc.create_faceted_crystal(name + "_Vein", radius=w * 0.16, height=h * 0.86, sides=4, mat=mat_crack, parent=piv)
        vein.location = Vector((w * 0.24, -d * 0.26, -h * 0.43))
    return piv


def create_quincy_star_mandala(
    name: str,
    radius: float = 1.28,
    mat_ink=None,
    mat_cyan=None,
    mat_white=None,
    mat_silver=None,
    parent=None,
) -> bpy.types.Object:
    """
    Create a colossal sacred Bleach TYBW 5-pointed Quincy Star Mandala (Vollstandig / Licht Regen):
      - Double outer celestial rings with 20 compass degree spikes
      - Razor-sharp 5-pointed hollow star frame + white-hot crosshair rays
      - High-contrast pitch-black ink backing ring so cyan energy blazes dramatically!
    """
    piv = bc.create_empty(name + "_Pivot", parent=parent)

    # Concentric outer celestial rings (Ink contrast backing + Cyan glow + Silver sacred border)
    bc.create_ornate_ring(name + "_OuterInk", radius * 1.04, radius * 0.90, 0.030, notches=10, notch_depth=0.075, segments=60, mat=mat_ink, parent=piv)
    r_cyan = bc.create_ornate_ring(name + "_OuterCyan", radius * 0.99, radius * 0.92, 0.036, notches=20, notch_depth=0.055, segments=60, mat=mat_cyan, parent=piv)
    r_cyan.location = Vector((0, 0, 0.008))
    r_mid = bc.create_ornate_ring(name + "_MidWhite", radius * 0.76, radius * 0.71, 0.028, notches=5, notch_depth=0.065, segments=50, mat=mat_white, parent=piv)
    r_mid.location = Vector((0, 0, -0.006))
    r_in = bc.create_ornate_ring(name + "_InnerSilver", radius * 0.42, radius * 0.36, 0.026, notches=10, notch_depth=0.035, segments=40, mat=mat_silver, parent=piv)
    r_in.location = Vector((0, 0, 0.006))

    # 5-Pointed Quincy Pentagram Star Rays (razor 3D diamond beams connecting the 5 vertices!)
    star_pts = [Vector((math.cos(i * math.tau / 5.0 + math.pi * 0.5) * radius * 0.96,
                        math.sin(i * math.tau / 5.0 + math.pi * 0.5) * radius * 0.96, 0.0)) for i in range(5)]

    def add_beam(bm_t, p0: Vector, p1: Vector, w: float, h: float):
        d = p1 - p0
        if d.length < 1e-4:
            return
        side = Vector((-d.y, d.x, 0.0)).normalized() * w
        up = Vector((0.0, 0.0, h))
        v0 = [bm_t.verts.new(p0 + side), bm_t.verts.new(p0 + up), bm_t.verts.new(p0 - side), bm_t.verts.new(p0 - up)]
        v1 = [bm_t.verts.new(p1 + side), bm_t.verts.new(p1 + up), bm_t.verts.new(p1 - side), bm_t.verts.new(p1 - up)]
        for k in range(4):
            kn = (k + 1) % 4
            bm_t.faces.new((v0[k], v0[kn], v1[kn], v1[k]))
        bm_t.faces.new(list(reversed(v0)))
        bm_t.faces.new(v1)

    bm_star = bmesh.new()
    for i in range(5):
        # Connect vertex i to i+2 to form iconic sharp Quincy pentagram star!
        add_beam(bm_star, star_pts[i], star_pts[(i + 2) % 5], w=0.034, h=0.024)
        # Radial sacred lance spoke from center to tip extending beyond outer ring!
        add_beam(bm_star, Vector((0, 0, 0)), star_pts[i] * 1.18, w=0.022, h=0.018)
    bc.finalize_bmesh(name + "_StarPentagram", bm_star, mat=mat_cyan, smooth=False, parent=piv)

    # White-hot center 5-pointed star gem prism
    bm_c = bmesh.new()
    v_top = bm_c.verts.new((0, 0, 0.14))
    v_bot = bm_c.verts.new((0, 0, -0.14))
    ring = []
    for i in range(10):
        a = (i / 10.0) * math.tau + math.pi * 0.5
        r = radius * 0.34 if i % 2 == 0 else radius * 0.13
        ring.append(bm_c.verts.new((math.cos(a) * r, math.sin(a) * r, 0.0)))
    for i in range(10):
        ni = (i + 1) % 10
        bm_c.faces.new((ring[i], ring[ni], v_top))
        bm_c.faces.new((ring[ni], ring[i], v_bot))
    bc.finalize_bmesh(name + "_WhiteCoreStar", bm_c, mat=mat_white, smooth=False, parent=piv)
    return piv


def create_quincy_lance(
    name: str,
    length: float = 0.96,
    radius: float = 0.038,
    mat_cyan=None,
    mat_white=None,
    mat_ink=None,
    parent=None,
) -> bpy.types.Object:
    """Create a gleaming Bleach Quincy Heilig Pfeil spiritual lance pointing along -Z (diving downward!)."""
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    # Razor elongated diamond spearhead pointing down toward Z = 0, shaft rising to +length
    bm = bmesh.new()
    v_tip = bm.verts.new((0, 0, 0.0))
    v_tail = bm.verts.new((0, 0, length))
    r_head = []
    r_neck = []
    r_rear = []
    for k in range(4):
        a = k * math.pi * 0.5
        ca, sa = math.cos(a), math.sin(a)
        r_head.append(bm.verts.new((ca * radius * 1.45, sa * radius * 1.45, length * 0.24)))
        r_neck.append(bm.verts.new((ca * radius * 0.42, sa * radius * 0.42, length * 0.34)))
        r_rear.append(bm.verts.new((ca * radius * 0.58, sa * radius * 0.58, length * 0.88)))
    for k in range(4):
        kn = (k + 1) % 4
        bm.faces.new((v_tip, r_head[kn], r_head[k]))
        bm.faces.new((r_head[k], r_head[kn], r_neck[kn], r_neck[k]))
        bm.faces.new((r_neck[k], r_neck[kn], r_rear[kn], r_rear[k]))
        bm.faces.new((r_rear[k], r_rear[kn], v_tail))
    bc.finalize_bmesh(name + "_ShaftCyan", bm, mat=mat_cyan, smooth=False, parent=piv)

    # Blinding white-hot needle core piercing the center
    core = bc.create_faceted_crystal(name + "_WhiteCore", radius=radius * 0.44, height=length * 0.92, sides=4, tip_ratio=0.18, bottom_taper=0.15, mat=mat_white, parent=piv)
    core.location = Vector((0, 0, length * 0.03))

    # Iconic Quincy Cross-Guard Fletching Fins near upper third
    for ax in (0.0, 90.0):
        fin = bc.create_faceted_crystal(name + f"_CrossFin_{int(ax)}", radius=radius * 0.55, height=radius * 6.8, sides=4, tip_ratio=0.45, bottom_taper=0.45, mat=mat_white, parent=piv)
        fin.location = Vector((0, 0, length * 0.72))
        fin.rotation_euler = (math.pi * 0.5, 0.0, math.radians(ax))
    collar = bc.create_ornate_ring(name + "_InkCollar", radius * 1.25, radius * 0.72, 0.035, notches=4, notch_depth=0.014, segments=16, mat=mat_ink, parent=piv)
    collar.location = Vector((0, 0, length * 0.72))
    return piv


def create_cross_impact_bloom(
    name: str,
    size: float = 0.65,
    mat_cyan=None,
    mat_white=None,
    parent=None,
) -> bpy.types.Object:
    """Create a blazing 3D Bleach Quincy piercing cross-shaped impact light bloom!"""
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    # Tall piercing vertical light spike
    v_beam = bc.create_faceted_crystal(name + "_VertSpike", radius=size * 0.11, height=size * 2.15, sides=4, tip_ratio=0.45, bottom_taper=0.22, mat=mat_white, parent=piv)
    v_beam.location = Vector((0, 0, 0.0))
    # Cross horizontal piercing blades (X and Y axes)
    for ang_z in (0.0, 90.0):
        h_beam = bc.create_faceted_crystal(name + f"_CrossArm_{int(ang_z)}", radius=size * 0.09, height=size * 1.35, sides=4, tip_ratio=0.48, bottom_taper=0.48, mat=mat_cyan, parent=piv)
        h_beam.location = Vector((-math.cos(math.radians(ang_z)) * size * 0.675, -math.sin(math.radians(ang_z)) * size * 0.675, size * 0.62))
        h_beam.rotation_euler = (0.0, math.pi * 0.5, math.radians(ang_z))
    # Ground cross-ring shock halo
    bc.create_ornate_ring(name + "_ImpactRing", size * 0.56, size * 0.44, 0.022, notches=4, notch_depth=size * 0.14, segments=32, mat=mat_cyan, parent=piv)
    return piv


def create_quincy_light_cage(
    name: str,
    radius: float = 0.96,
    height: float = 1.92,
    sides: int = 8,
    mat_cyan=None,
    mat_white=None,
    parent=None,
) -> bpy.types.Object:
    """Create a tall geometric cyan-white Quincy sacred light cage prism surrounding the arena target!"""
    piv = bc.create_empty(name + "_Pivot", parent=parent)
    # Bottom, Mid, and Top geometric octagon binding rings
    for tag, z_pos, r_sc, mat_r in [
        ("Bot", 0.06, 1.0, mat_cyan),
        ("Mid", height * 0.50, 1.04, mat_white),
        ("Top", height, 0.96, mat_cyan),
    ]:
        rr = bc.create_ornate_ring(f"{name}_Ring{tag}", radius * r_sc, radius * r_sc - 0.042, 0.030, notches=sides, notch_depth=0.05, segments=sides * 4, mat=mat_r, parent=piv)
        rr.location = Vector((0, 0, z_pos))
    # 8 Vertical glowing prison bars + diagonal lattice cross-bars
    bm = bmesh.new()
    for i in range(sides):
        a = (float(i) / float(sides)) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        p_bot = Vector((ca * radius, sa * radius, 0.04))
        p_top = Vector((ca * radius * 0.96, sa * radius * 0.96, height + 0.14))
        w = 0.022
        u_v = Vector((-sa, ca, 0.0)) * w
        r_v = Vector((ca, sa, 0.0)) * w
        vb = [bm.verts.new(p_bot + u_v), bm.verts.new(p_bot + r_v), bm.verts.new(p_bot - u_v), bm.verts.new(p_bot - r_v)]
        vt = [bm.verts.new(p_top + u_v), bm.verts.new(p_top + r_v), bm.verts.new(p_top - u_v), bm.verts.new(p_top - r_v)]
        for k in range(4):
            kn = (k + 1) % 4
            bm.faces.new((vb[k], vb[kn], vt[kn], vt[k]))
        bm.faces.new(list(reversed(vb)))
        bm.faces.new(vt)
    bc.finalize_bmesh(name + "_CageBars", bm, mat=mat_white, smooth=False, parent=piv)
    return piv


# =============================================================================
# 1. CINEMATIC VAMPIRE CRIMSON (144f @ 24fps = 6.00s) — UPGRADED TYBW SCALE!
#    Towering ink-blood pillar, 8 colossal ruby/obsidian fangs, twin orbital
#    blood-sigil rings, gilded chalice heart, 8 siphon spears & crimson dome!
# =============================================================================

def build_cinematic_vampire_crimson() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=145)
    M = make_shared_palette((0.76, 0.012, 0.028), (1.0, 0.05, 0.09), emit_str=2.35)
    root = bc.create_empty("CinematicVampireCrimsonRoot")

    # 1. Colossal 1.25m-radius Pitch-Black Ink & Crimson Blood-Sigil Floor Array
    outer_sigil = bc.create_ornate_ring(
        "BloodSigilOuter", 1.26, 1.04, 0.036, notches=12, notch_depth=0.11, segments=60, mat=M["ink"], parent=root
    )
    outer_glow = bc.create_ornate_ring(
        "BloodSigilOuterGlow", 1.08, 0.96, 0.028, notches=12, notch_depth=0.055, segments=60, mat=M["accent"], parent=outer_sigil
    )
    outer_glow.location = Vector((0, 0, 0.012))

    inner_sigil = bc.create_ornate_ring(
        "BloodSigilInner", 0.72, 0.56, 0.034, notches=8, notch_depth=0.062, segments=48, mat=M["gold"], parent=root
    )
    inner_glow = bc.create_ornate_ring(
        "BloodSigilInnerGlow", 0.60, 0.50, 0.024, notches=8, notch_depth=0.038, segments=48, mat=M["glow"], parent=inner_sigil
    )
    inner_glow.location = Vector((0, 0, 0.012))

    # 2. Towering Pitch-Black Sumi-Ink Blood Pillar (2.05m tall!) wrapped in blazing crimson veins
    ink_pillar = create_ink_pillar(
        "BloodInkPillar", r_base=0.38, r_mid=0.18, r_top=0.32, height=2.05, flutes=8, twist_rad=2.6,
        mat_ink=M["ink"], mat_rim=M["accent"], parent=root
    )

    # 3. Monumental Gilded Blood Chalice & Pitch-Black/Crimson Pulsing Heart Core + Wide Orbital Rings
    core_piv = bc.create_empty("BloodCorePivot", loc=(0, 0, 0.88), parent=root)
    bc.create_lathe_mesh(
        "BloodChaliceCup",
        [(0.16, -0.40), (0.065, -0.28), (0.052, -0.10), (0.22, 0.08), (0.28, 0.26), (0.24, 0.26), (0.18, 0.08)],
        segments=28, mat=M["gold"], smooth=True, parent=core_piv
    )
    core_orb = bc.create_faceted_crystal("BloodCoreOrb", radius=0.20, height=0.52, sides=8, tip_ratio=0.45, bottom_taper=0.35, mat=M["glow"], parent=core_piv)
    core_orb.location = Vector((0, 0, 0.05))
    core_white = bc.create_faceted_crystal("BloodCoreWhiteSeam", radius=0.10, height=0.62, sides=4, tip_ratio=0.45, bottom_taper=0.45, mat=M["white"], parent=core_piv)
    core_white.location = Vector((0, 0, 0.0))

    orb_ring_a = bc.create_ornate_ring("BloodOrbitalRing_A", 0.96, 0.86, 0.032, notches=12, notch_depth=0.052, segments=48, mat=M["accent"], parent=root)
    orb_ring_b = bc.create_ornate_ring("BloodOrbitalRing_B", 0.78, 0.70, 0.028, notches=8, notch_depth=0.042, segments=40, mat=M["ink"], parent=root)
    orb_ring_b_rim = bc.create_ornate_ring("BloodOrbitalRing_B_Rim", 0.72, 0.68, 0.034, notches=8, notch_depth=0.024, segments=40, mat=M["glow"], parent=orb_ring_b)
    orb_ring_b_rim.location = Vector((0, 0, 0.004))

    # 4. 8 Colossal Curved Ruby & Pitch-Black Obsidian Fangs (1.15m tall!) forming monstrous snap jaws
    fangs = []
    for fi in range(8):
        ang = (float(fi) / 8.0) * math.tau
        f_piv = bc.create_empty(f"RubyFangPivot_{fi}", loc=(math.cos(ang) * 0.96, math.sin(ang) * 0.96, 0.0), parent=root)
        fang = create_curved_fang(
            f"RubyFang_{fi}", height=1.18, base_r=0.132, curve_x=-0.42, sides=12, rings=14,
            mat=M["glow"] if fi % 2 == 0 else M["ink"], parent=f_piv
        )
        fang.rotation_euler = (0.0, 0.0, ang)
        if fi % 2 == 1:
            # Blazing crimson outer edge spine on black ink fangs!
            edge = create_curved_fang(f"RubyFangEdge_{fi}", height=1.22, base_r=0.055, curve_x=-0.46, sides=6, rings=10, mat=M["accent"], parent=f_piv)
            edge.rotation_euler = (0.0, 0.0, ang)
            edge.location = Vector((-math.cos(ang) * 0.05, -math.sin(ang) * 0.05, 0.02))
        collar = bc.create_ornate_ring(f"FangCollar_{fi}", 0.16, 0.10, 0.062, notches=6, notch_depth=0.024, segments=18, mat=M["gold"], parent=f_piv)
        collar.location = Vector((0, 0, 0.06))
        fangs.append((f_piv, ang))

    # 5. 4 Sweeping Helical Blood-Siphon Tendrils + 8 Streaking Siphon Orb Spears from Rival (+Y=1.75m)
    tendrils = []
    for ti in range(4):
        tendril = bc.create_twisted_ribbon(
            f"BloodTendril_{ti}", radius_start=0.88, radius_end=0.28, height=1.62, turns=1.35,
            width=0.068, thickness=0.018, steps=40, phase_deg=ti * 90.0,
            mat=M["accent"] if ti % 2 == 0 else M["glow"], parent=root
        )
        tendrils.append(tendril)

    siphon_orbs = []
    for oi in range(8):
        orb_piv = bc.create_empty(f"SiphonOrbPivot_{oi}", loc=(0, 1.75, 0.65), parent=root)
        orb = bc.create_faceted_crystal(f"SiphonOrb_{oi}", radius=0.095, height=0.30, sides=6, tip_ratio=0.45, bottom_taper=0.45, mat=M["glow"], parent=orb_piv)
        orb.location = Vector((0, 0, -0.15))
        halo = bc.create_ornate_ring(f"SiphonOrbHalo_{oi}", 0.145, 0.118, 0.020, notches=4, notch_depth=0.018, segments=16, mat=M["gold"], parent=orb_piv)
        halo.rotation_euler = (math.radians(60), 0, 0)
        siphon_orbs.append((orb_piv, oi))

    # 6. Climax Crimson Ink-Blood Shockwave Dome
    blood_dome = create_shockwave_dome("BloodClimaxDome", radius=1.38, height=1.08, ribs=12, mat_core=M["ink"], mat_rim=M["glow"], parent=root)

    # --- 4-PHASE ANIMATION (1..145 @ 24fps = 6.00s, Climax at frames 86-94 = 3.54-3.88s) ---
    bc.kf_trs(outer_sigil, 1, loc=(0, 0, 0.01), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(outer_sigil, 28, loc=(0, 0, 0.02), rot_deg=(0, 0, 110), scale=1.04)
    bc.kf_trs(outer_sigil, 76, loc=(0, 0, 0.02), rot_deg=(0, 0, 320), scale=0.92)
    bc.kf_trs(outer_sigil, 88, loc=(0, 0, 0.04), rot_deg=(0, 0, 420), scale=1.36)
    bc.kf_trs(outer_sigil, 122, loc=(0, 0, 0.02), rot_deg=(0, 0, 560), scale=1.18)
    bc.kf_trs(outer_sigil, 145, loc=(0, 0, 0.01), rot_deg=(0, 0, 680), scale=0.01)

    bc.kf_trs(inner_sigil, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(inner_sigil, 30, loc=(0, 0, 0.08), rot_deg=(0, 0, -140), scale=1.08)
    bc.kf_trs(inner_sigil, 78, loc=(0, 0, 0.28), rot_deg=(0, 0, -420), scale=1.16)
    bc.kf_trs(inner_sigil, 88, loc=(0, 0, 0.06), rot_deg=(0, 0, -540), scale=1.45)
    bc.kf_trs(inner_sigil, 124, loc=(0, 0, 0.14), rot_deg=(0, 0, -700), scale=1.15)
    bc.kf_trs(inner_sigil, 145, loc=(0, 0, 0.02), rot_deg=(0, 0, -840), scale=0.01)

    bc.kf_trs(ink_pillar, 1, loc=(0, 0, 0.0), rot_deg=(0, 0, 0), scale=(0.05, 0.05, 0.02))
    bc.kf_trs(ink_pillar, 34, loc=(0, 0, 0.0), rot_deg=(0, 0, 120), scale=(0.82, 0.82, 0.92))
    bc.kf_trs(ink_pillar, 78, loc=(0, 0, 0.0), rot_deg=(0, 0, 340), scale=(0.64, 0.64, 1.08))
    bc.kf_trs(ink_pillar, 88, loc=(0, 0, 0.0), rot_deg=(0, 0, 480), scale=(1.28, 1.28, 1.18))
    bc.kf_trs(ink_pillar, 122, loc=(0, 0, 0.0), rot_deg=(0, 0, 680), scale=(0.95, 0.95, 1.02))
    bc.kf_trs(ink_pillar, 145, loc=(0, 0, 0.0), rot_deg=(0, 0, 840), scale=(0.01, 0.01, 0.01))

    bc.kf_trs(core_piv, 1, loc=(0, 0, 0.20), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(core_piv, 34, loc=(0, 0, 0.84), rot_deg=(10, 0, 180), scale=1.06)
    bc.kf_trs(core_piv, 78, loc=(0, 0, 1.06), rot_deg=(-12, 10, 520), scale=0.88)
    bc.kf_trs(core_piv, 88, loc=(0, 0, 0.92), rot_deg=(0, 0, 720), scale=1.42)
    bc.kf_trs(core_piv, 122, loc=(0, 0, 0.98), rot_deg=(8, -6, 980), scale=1.18)
    bc.kf_trs(core_piv, 145, loc=(0, 0, 0.30), rot_deg=(0, 0, 1180), scale=0.01)

    bc.kf_trs(orb_ring_a, 1, loc=(0, 0, 0.22), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(orb_ring_a, 34, loc=(0, 0, 0.92), rot_deg=(54, -22, 180), scale=1.05)
    bc.kf_trs(orb_ring_a, 88, loc=(0, 0, 0.98), rot_deg=(-48, 34, 580), scale=1.32)
    bc.kf_trs(orb_ring_a, 122, loc=(0, 0, 1.02), rot_deg=(38, -28, 860), scale=1.14)
    bc.kf_trs(orb_ring_a, 145, loc=(0, 0, 0.25), rot_deg=(0, 0, 1060), scale=0.01)

    bc.kf_trs(orb_ring_b, 1, loc=(0, 0, 0.22), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(orb_ring_b, 34, loc=(0, 0, 0.92), rot_deg=(-58, 28, -210), scale=1.06)
    bc.kf_trs(orb_ring_b, 88, loc=(0, 0, 0.98), rot_deg=(52, -32, -640), scale=1.34)
    bc.kf_trs(orb_ring_b, 122, loc=(0, 0, 1.02), rot_deg=(-40, 26, -940), scale=1.12)
    bc.kf_trs(orb_ring_b, 145, loc=(0, 0, 0.25), rot_deg=(0, 0, -1140), scale=0.01)

    for fi, (f_piv, ang) in enumerate(fangs):
        ca, sa = math.cos(ang), math.sin(ang)
        bc.kf_trs(f_piv, 1, loc=(ca * 1.10, sa * 1.10, -0.25), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(f_piv, 32, loc=(ca * 0.96, sa * 0.96, 0.04), rot_deg=(0, 0, 30), scale=1.06)
        bc.kf_trs(f_piv, 76, loc=(ca * 1.18, sa * 1.18, 0.22), rot_deg=(ca * 18, sa * 18, 95), scale=1.18)
        # Violent Fang Jaw Snap inward at frame 86!
        bc.kf_trs(f_piv, 86, loc=(ca * 0.66, sa * 0.66, 0.24), rot_deg=(-ca * 26, -sa * 26, 155), scale=1.32)
        bc.kf_trs(f_piv, 120, loc=(ca * 0.92, sa * 0.92, 0.12), rot_deg=(0, 0, 235), scale=1.12)
        bc.kf_trs(f_piv, 145, loc=(ca * 1.08, sa * 1.08, -0.20), rot_deg=(0, 0, 310), scale=0.01)

    for ti, tendril in enumerate(tendrils):
        bc.kf_trs(tendril, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(tendril, 36, loc=(0, 0, 0.04), rot_deg=(0, 0, 220), scale=1.02)
        bc.kf_trs(tendril, 78, loc=(0, 0, 0.08), rot_deg=(0, 0, 560), scale=(0.78, 0.78, 1.18))
        bc.kf_trs(tendril, 90, loc=(0, 0, 0.10), rot_deg=(0, 0, 760), scale=(1.22, 1.22, 1.26))
        bc.kf_trs(tendril, 124, loc=(0, 0, 0.14), rot_deg=(0, 0, 1020), scale=(1.04, 1.04, 1.08))
        bc.kf_trs(tendril, 145, loc=(0, 0, 0.18), rot_deg=(0, 0, 1220), scale=0.01)

    for orb_piv, oi in siphon_orbs:
        f_start = 18 + oi * 7
        f_mid = f_start + 22
        f_arrive = min(98, f_start + 42)
        x_side = (0.58 if oi % 2 == 0 else -0.58) * (1.0 + 0.22 * (oi % 3))
        bc.kf_trs(orb_piv, 1, loc=(0, 1.75, 0.45), scale=0.01)
        bc.kf_trs(orb_piv, f_start, loc=(x_side * 0.4, 1.65, 0.62), rot_deg=(0, 0, 0), scale=1.12)
        bc.kf_trs(orb_piv, f_mid, loc=(x_side, 0.85, 1.35 + (oi % 2) * 0.22), rot_deg=(210, 140, 110), scale=1.38)
        bc.kf_trs(orb_piv, f_arrive, loc=(0.0, 0.0, 0.92), rot_deg=(420, 280, 220), scale=0.22)
        bc.kf_trs(orb_piv, 145, loc=(0.0, 0.0, 0.92), scale=0.01)

    bc.kf_trs(blood_dome, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.01)
    bc.kf_trs(blood_dome, 82, loc=(0, 0, 0.02), rot_deg=(0, 0, 40), scale=0.06)
    bc.kf_trs(blood_dome, 92, loc=(0, 0, 0.04), rot_deg=(0, 0, 140), scale=1.16)
    bc.kf_trs(blood_dome, 122, loc=(0, 0, 0.03), rot_deg=(0, 0, 260), scale=1.32)
    bc.kf_trs(blood_dome, 145, loc=(0, 0, 0.01), rot_deg=(0, 0, 340), scale=0.01)

    all_anim = [outer_sigil, inner_sigil, ink_pillar, core_piv, orb_ring_a, orb_ring_b, blood_dome]
    all_anim += [f[0] for f in fangs] + tendrils + [o[0] for o in siphon_orbs]
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_vampire_crimson.glb")
    return out_glb, 90


# =============================================================================
# 2. CINEMATIC STORM TEMPEST (142f @ 24fps = 5.92s) — UPGRADED TYBW SCALE!
#    4 towering storm-coil orbital rings, ink thunder-vortex core, 8 colossal
#    jagged super-bolts in staggered barrage & triple shockwave cascade!
# =============================================================================

def build_cinematic_storm_tempest() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=143)
    M = make_shared_palette((0.02, 0.44, 0.96), (0.14, 0.78, 1.0), emit_str=2.45)
    root = bc.create_empty("CinematicStormTempestRoot")

    # 1. Four Tiered Giant Brass/Ink/Electric Storm Coil Rings up to Z = 1.80m!
    coils = []
    coil_specs = [
        ("StormCoil_Floor", 1.24, 1.04, 0.042, 16, 0.06, M["ink"], M["accent"]),
        ("StormCoil_Low", 1.02, 0.86, 0.038, 12, 0.48, M["brass"], M["glow"]),
        ("StormCoil_Mid", 0.84, 0.70, 0.036, 10, 1.06, M["iron"], M["white"]),
        ("StormCoil_Sky", 0.68, 0.54, 0.032, 8, 1.68, M["gold"], M["glow"]),
    ]
    for cname, ro, ri, h, n_notches, z_base, mat_rim, mat_in in coil_specs:
        c_piv = bc.create_empty(cname + "_Pivot", loc=(0, 0, z_base), parent=root)
        bc.create_ornate_ring(cname, ro, ri, h, notches=n_notches, notch_depth=0.062, segments=48, mat=mat_rim, parent=c_piv)
        in_r = bc.create_ornate_ring(
            cname + "_Glow", ri + 0.02, ri - 0.05, h * 0.78, notches=n_notches, notch_depth=0.030, segments=48, mat=mat_in, parent=c_piv
        )
        in_r.location = Vector((0, 0, 0.008))
        coils.append((c_piv, z_base))

    # 2. Towering Pitch-Black Thunder-Vortex Ink Pillar + Central Magnetic Fulcrum Core
    thunder_pillar = create_ink_pillar(
        "StormThunderInkCore", r_base=0.34, r_mid=0.16, r_top=0.42, height=2.22, flutes=8, twist_rad=3.0,
        mat_ink=M["ink"], mat_rim=M["glow"], parent=root
    )
    core_piv = bc.create_empty("TempestCorePivot", loc=(0, 0, 0.92), parent=root)
    core_cryst = bc.create_faceted_crystal("TempestCore", radius=0.22, height=0.56, sides=8, tip_ratio=0.50, bottom_taper=0.50, mat=M["white"], parent=core_piv)
    core_cryst.location = Vector((0, 0, -0.28))
    gyro_a = bc.create_ornate_ring("TempestGyro_A", 0.44, 0.37, 0.032, notches=8, notch_depth=0.030, segments=32, mat=M["gold"], parent=core_piv)
    gyro_a.rotation_euler = (math.radians(64), 0, 0)
    gyro_b = bc.create_ornate_ring("TempestGyro_B", 0.54, 0.47, 0.032, notches=8, notch_depth=0.030, segments=32, mat=M["glow"], parent=core_piv)
    gyro_b.rotation_euler = (0, math.radians(64), 0)

    # 3. 8 Colossal Jagged Forged-Lightning Super-Bolts (up to 2.30m tall!) striking in thunder waves!
    bolts = []
    bolt_offsets = [
        (0.0, 0.0, 0),
        (-0.56, 0.38, 1), (0.56, 0.38, 2),
        (-0.52, -0.46, 3), (0.52, -0.46, 4),
        (0.0, 0.78, 5), (-0.82, 0.0, 6), (0.82, 0.0, 7),
    ]
    for bx, by, bi in bolt_offsets:
        b_piv = bc.create_empty(f"LightningBoltPivot_{bi}", loc=(bx, by, 0.0), parent=root)
        s = 1.0 if bi % 2 == 0 else -1.0
        h_top = 2.35 if bi == 0 else 2.05
        knots = [
            (0.0, 0.0, h_top),
            (s * 0.22, -s * 0.12, h_top * 0.80),
            (-s * 0.20, s * 0.14, h_top * 0.60),
            (s * 0.24, 0.06, h_top * 0.40),
            (-s * 0.14, -s * 0.10, h_top * 0.20),
            (0.0, 0.0, 0.02),
        ]
        rads = [0.105, 0.092, 0.082, 0.072, 0.056, 0.026] if bi == 0 else [0.072, 0.064, 0.054, 0.046, 0.034, 0.018]
        create_jagged_lightning_bolt(f"LightningBolt_{bi}", knots, rads, sides=6, mat=M["white"] if bi == 0 else (M["glow"] if bi % 2 == 1 else M["accent"]), parent=b_piv)
        bolts.append((b_piv, bx, by, bi))

    # 4. 8 Tall Perimeter Storm Capacitor Obelisks + Twin Shockwave Rings + Electric Dome
    pylons = []
    for pi in range(8):
        ang = (float(pi) / 8.0) * math.tau + math.pi / 8.0
        p_piv = bc.create_empty(f"StormPylonPivot_{pi}", loc=(math.cos(ang) * 1.12, math.sin(ang) * 1.12, 0.0), parent=root)
        bc.create_faceted_crystal(f"StormPylon_{pi}", radius=0.088, height=0.88, sides=6, tip_ratio=0.35, bottom_taper=0.65, mat=M["ink"] if pi % 2 == 0 else M["gold"], parent=p_piv)
        bc.create_faceted_crystal(f"StormPylonCore_{pi}", radius=0.052, height=0.96, sides=4, tip_ratio=0.30, bottom_taper=0.45, mat=M["glow"], parent=p_piv)
        band = bc.create_ornate_ring(f"StormPylonCollar_{pi}", 0.115, 0.086, 0.044, notches=4, notch_depth=0.016, segments=16, mat=M["brass"], parent=p_piv)
        band.location = Vector((0, 0, 0.32))
        pylons.append((p_piv, ang))

    shock_a = bc.create_ornate_ring("ElectricShockwave_A", 1.38, 1.18, 0.042, notches=20, notch_depth=0.11, segments=64, mat=M["glow"], parent=root)
    shock_b = bc.create_ornate_ring("ElectricShockwave_B", 1.05, 0.92, 0.032, notches=16, notch_depth=0.08, segments=48, mat=M["white"], parent=root)

    # --- 4-PHASE ANIMATION (1..143 @ 24fps = 5.92s, Thunder Barrage Climax frames 82-98) ---
    for ci, (c_piv, z_base) in enumerate(coils):
        dir_s = 1.0 if ci % 2 == 0 else -1.0
        tilt = 16.0 if ci == 1 else (-14.0 if ci == 2 else (10.0 if ci == 3 else 0.0))
        bc.kf_trs(c_piv, 1, loc=(0, 0, 0.04), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(c_piv, 32, loc=(0, 0, z_base), rot_deg=(tilt, 0, dir_s * 180), scale=1.05)
        bc.kf_trs(c_piv, 76, loc=(0, 0, z_base + 0.14 * ci), rot_deg=(-tilt, tilt * 0.6, dir_s * 540), scale=0.88)
        bc.kf_trs(c_piv, 86, loc=(0, 0, z_base * 0.78 + 0.04), rot_deg=(0, 0, dir_s * 720), scale=1.34)
        bc.kf_trs(c_piv, 118, loc=(0, 0, z_base), rot_deg=(tilt * 0.5, 0, dir_s * 980), scale=1.14)
        bc.kf_trs(c_piv, 143, loc=(0, 0, 0.04), rot_deg=(0, 0, dir_s * 1200), scale=0.01)

    bc.kf_trs(thunder_pillar, 1, loc=(0, 0, 0), rot_deg=(0, 0, 0), scale=(0.04, 0.04, 0.02))
    bc.kf_trs(thunder_pillar, 34, loc=(0, 0, 0), rot_deg=(0, 0, 160), scale=(0.75, 0.75, 0.85))
    bc.kf_trs(thunder_pillar, 78, loc=(0, 0, 0), rot_deg=(0, 0, 460), scale=(0.55, 0.55, 1.05))
    bc.kf_trs(thunder_pillar, 86, loc=(0, 0, 0), rot_deg=(0, 0, 620), scale=(1.25, 1.25, 1.15))
    bc.kf_trs(thunder_pillar, 120, loc=(0, 0, 0), rot_deg=(0, 0, 880), scale=(0.90, 0.90, 0.96))
    bc.kf_trs(thunder_pillar, 143, loc=(0, 0, 0), rot_deg=(0, 0, 1080), scale=(0.01, 0.01, 0.01))

    bc.kf_trs(core_piv, 1, loc=(0, 0, 0.16), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(core_piv, 34, loc=(0, 0, 0.92), rot_deg=(24, -18, 260), scale=1.10)
    bc.kf_trs(core_piv, 78, loc=(0, 0, 1.18), rot_deg=(-28, 22, 680), scale=0.82)
    bc.kf_trs(core_piv, 86, loc=(0, 0, 0.78), rot_deg=(0, 0, 880), scale=1.48)
    bc.kf_trs(core_piv, 118, loc=(0, 0, 0.94), rot_deg=(14, -12, 1160), scale=1.16)
    bc.kf_trs(core_piv, 143, loc=(0, 0, 0.20), rot_deg=(0, 0, 1380), scale=0.01)

    for b_piv, bx, by, bi in bolts:
        f_hit = 82 + (bi % 4) * 3
        bc.kf_trs(b_piv, 1, loc=(bx, by, 0.65), scale=0.005)
        bc.kf_trs(b_piv, f_hit - 5, loc=(bx, by, 0.45), rot_deg=(0, 0, 0), scale=(0.14, 0.14, 0.45))
        bc.kf_trs(b_piv, f_hit, loc=(bx, by, 0.0), rot_deg=(0, 0, bi * 40), scale=(1.32, 1.32, 1.04))
        bc.kf_trs(b_piv, f_hit + 6, loc=(bx, by, 0.0), rot_deg=(0, 0, bi * 40 + 18), scale=(0.78, 0.78, 0.96))
        bc.kf_trs(b_piv, f_hit + 12, loc=(bx, by, 0.0), rot_deg=(0, 0, bi * 40 + 36), scale=(1.38, 1.38, 1.08))
        bc.kf_trs(b_piv, 122, loc=(bx, by, 0.0), rot_deg=(0, 0, bi * 40 + 75), scale=(0.88, 0.88, 0.90))
        bc.kf_trs(b_piv, 143, loc=(bx, by, 0.0), scale=0.005)

    for pi, (p_piv, ang) in enumerate(pylons):
        ca, sa = math.cos(ang), math.sin(ang)
        bc.kf_trs(p_piv, 1, loc=(ca * 1.12, sa * 1.12, -0.25), scale=0.01)
        bc.kf_trs(p_piv, 28 + (pi % 4) * 3, loc=(ca * 0.98, sa * 0.98, 0.04), rot_deg=(0, 0, 75), scale=1.08)
        bc.kf_trs(p_piv, 86, loc=(ca * 1.24, sa * 1.24, 0.10), rot_deg=(ca * 16, sa * 16, 220), scale=1.34)
        bc.kf_trs(p_piv, 122, loc=(ca * 1.30, sa * 1.30, 0.06), rot_deg=(ca * 8, sa * 8, 300), scale=1.12)
        bc.kf_trs(p_piv, 143, loc=(ca * 1.42, sa * 1.42, -0.15), rot_deg=(0, 0, 380), scale=0.01)

    for sh, delay, msc in ((shock_a, 0, 1.42), (shock_b, 4, 1.32)):
        bc.kf_trs(sh, 1, loc=(0, 0, 0.03), scale=0.01)
        bc.kf_trs(sh, 80 + delay, loc=(0, 0, 0.03), scale=0.06)
        bc.kf_trs(sh, 90 + delay, loc=(0, 0, 0.08), rot_deg=(0, 0, 120), scale=msc * 0.86)
        bc.kf_trs(sh, 122 + delay, loc=(0, 0, 0.05), rot_deg=(0, 0, 260), scale=msc)
        bc.kf_trs(sh, 143, loc=(0, 0, 0.02), rot_deg=(0, 0, 340), scale=0.01)

    all_anim = [thunder_pillar, core_piv, shock_a, shock_b] + [c[0] for c in coils] + [b[0] for b in bolts] + [p[0] for p in pylons]
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_storm_tempest.glb")
    return out_glb, 90


# =============================================================================
# 3. CINEMATIC PHOENIX INFERNO (150f @ 24fps = 6.25s) — UPGRADED TYBW SCALE!
#    Colossal 2.4m-wingspan sculpted Phoenix Avatar (9 layered obsidian-gold-flame
#    feathers per wing), towering volcanic ink-solar pillar & solar flare dome!
# =============================================================================

def build_cinematic_phoenix_inferno() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=151)
    M = make_shared_palette((0.92, 0.16, 0.012), (1.0, 0.54, 0.04), emit_str=2.30)
    root = bc.create_empty("CinematicPhoenixInfernoRoot")

    # 1. Colossal Alchemical Crucible Ink-Gold Sigil Base
    crucible = bc.create_ornate_ring("CrucibleSigilRing", 1.24, 1.02, 0.038, notches=16, notch_depth=0.088, segments=64, mat=M["ink"], parent=root)
    crucible_glow = bc.create_ornate_ring("CrucibleSigilGlow", 1.06, 0.94, 0.028, notches=16, notch_depth=0.048, segments=64, mat=M["accent"], parent=crucible)
    crucible_glow.location = Vector((0, 0, 0.012))

    # 2. Towering Volcanic Ink-Solar Pillar (2.25m tall)
    solar_pillar = create_ink_pillar(
        "PhoenixSolarInkPillar", r_base=0.40, r_mid=0.20, r_top=0.38, height=2.25, flutes=8, twist_rad=2.4,
        mat_ink=M["ink"], mat_rim=M["glow"], parent=root
    )

    # 3. Monumental Sculpted Phoenix Avatar + 2.4m Wingspan Articulated Flame Wings (9 feathers each!)
    phoenix_piv = bc.create_empty("PhoenixAvatarPivot", loc=(0, 0, 0.96), parent=root)
    crest_core = bc.create_faceted_crystal("PhoenixBodyCore", radius=0.20, height=0.82, sides=6, tip_ratio=0.36, bottom_taper=0.35, mat=M["gold"], parent=phoenix_piv)
    crest_core.location = Vector((0, 0, -0.34))
    chest_gem = bc.create_faceted_crystal("PhoenixHeartGem", radius=0.135, height=0.36, sides=6, tip_ratio=0.48, bottom_taper=0.48, mat=M["white"], parent=phoenix_piv)
    chest_gem.location = Vector((0, -0.10, -0.08))
    beak_crown = bc.create_flame_tongue("PhoenixHeadPlume", radius=0.13, height=0.56, twist_rad=0.7, lean_x=0.0, sides=8, levels=10, mat=M["glow"], parent=phoenix_piv)
    beak_crown.location = Vector((0, -0.04, 0.36))

    wings = []
    for side_s, side_tag in ((-1.0, "L"), (1.0, "R")):
        w_piv = bc.create_empty(f"PhoenixWing_{side_tag}", loc=(side_s * 0.16, 0.0, 0.10), parent=phoenix_piv)
        for fi in range(9):
            u = float(fi) / 8.0
            flen = 1.24 - u * 0.44
            fw = 0.22 - u * 0.05
            fmat = M["gold"] if fi in (0, 4, 8) else (M["ink"] if fi in (2, 6) else (M["accent"] if fi in (1, 5) else M["glow"]))
            feather = create_feather_blade(
                f"PhoenixFeather_{side_tag}_{fi}", length=flen, width=fw, thickness=0.038,
                curve_z=0.28 - u * 0.10, mat=fmat, parent=w_piv
            )
            feather.location = Vector((0.0, u * 0.07, 0.18 - u * 0.34))
            feather.rotation_euler = (
                math.radians(7.0 * u),
                math.radians(-side_s * (34.0 - u * 58.0)),
                0.0 if side_s > 0 else math.pi,
            )
        wings.append((w_piv, side_s))

    # 4. Roaring Ember Cyclone Ribbons + 12 Perimeter Inferno Flame Pillars + Solar Crown Halo + Solar Dome!
    cyclone_ribbons = []
    for ri in range(4):
        rib = bc.create_twisted_ribbon(
            f"EmberCycloneRibbon_{ri}", radius_start=0.98, radius_end=0.38, height=1.22, turns=1.25,
            width=0.064, thickness=0.016, steps=36, phase_deg=ri * 90.0,
            mat=M["accent"] if ri % 2 == 0 else M["glow"], parent=root
        )
        cyclone_ribbons.append(rib)

    flame_tongues = []
    for ti in range(12):
        ang = (float(ti) / 12.0) * math.tau
        ft_piv = bc.create_empty(f"InfernoFlamePivot_{ti}", loc=(math.cos(ang) * 1.02, math.sin(ang) * 1.02, 0.0), parent=root)
        bc.create_flame_tongue(
            f"InfernoFlameTongue_{ti}", radius=0.115, height=0.78 + (ti % 3) * 0.18,
            twist_rad=2.0, lean_x=0.08, sides=8, levels=10,
            mat=M["ink"] if ti % 3 == 0 else (M["accent"] if ti % 3 == 1 else M["glow"]), parent=ft_piv
        )
        flame_tongues.append((ft_piv, ang))

    solar_halo = bc.create_ornate_ring("SolarCrownRing", 0.88, 0.74, 0.036, notches=20, notch_depth=0.075, segments=60, mat=M["gold"], parent=root)
    solar_dome = create_shockwave_dome("SolarFlareDome", radius=1.42, height=1.12, ribs=12, mat_core=M["accent"], mat_rim=M["glow"], parent=root)

    # --- 4-PHASE ANIMATION (1..151 @ 24fps = 6.25s, Climax Unfurl at frame 92 = 3.79s) ---
    bc.kf_trs(crucible, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(crucible, 32, loc=(0, 0, 0.03), rot_deg=(0, 0, 130), scale=1.06)
    bc.kf_trs(crucible, 80, loc=(0, 0, 0.03), rot_deg=(0, 0, 360), scale=0.94)
    bc.kf_trs(crucible, 92, loc=(0, 0, 0.05), rot_deg=(0, 0, 480), scale=1.38)
    bc.kf_trs(crucible, 128, loc=(0, 0, 0.03), rot_deg=(0, 0, 640), scale=1.18)
    bc.kf_trs(crucible, 151, loc=(0, 0, 0.02), rot_deg=(0, 0, 760), scale=0.01)

    bc.kf_trs(solar_pillar, 1, loc=(0, 0, 0), rot_deg=(0, 0, 0), scale=(0.04, 0.04, 0.02))
    bc.kf_trs(solar_pillar, 34, loc=(0, 0, 0), rot_deg=(0, 0, 140), scale=(0.80, 0.80, 0.88))
    bc.kf_trs(solar_pillar, 80, loc=(0, 0, 0), rot_deg=(0, 0, 380), scale=(0.60, 0.60, 1.06))
    bc.kf_trs(solar_pillar, 92, loc=(0, 0, 0), rot_deg=(0, 0, 520), scale=(1.28, 1.28, 1.18))
    bc.kf_trs(solar_pillar, 128, loc=(0, 0, 0), rot_deg=(0, 0, 740), scale=(0.94, 0.94, 1.02))
    bc.kf_trs(solar_pillar, 151, loc=(0, 0, 0), rot_deg=(0, 0, 900), scale=(0.01, 0.01, 0.01))

    bc.kf_trs(phoenix_piv, 1, loc=(0, 0, 0.18), rot_deg=(28, 0, 0), scale=0.02)
    bc.kf_trs(phoenix_piv, 36, loc=(0, 0, 0.78), rot_deg=(14, 0, 0), scale=0.96)
    bc.kf_trs(phoenix_piv, 78, loc=(0, 0, 0.66), rot_deg=(26, 0, 0), scale=0.86)
    bc.kf_trs(phoenix_piv, 92, loc=(0, 0, 1.06), rot_deg=(-10, 0, 16), scale=1.24)  # Heroic 2.4m Unfurl!
    bc.kf_trs(phoenix_piv, 128, loc=(0, 0, 1.22), rot_deg=(-6, 0, 0), scale=1.18)
    bc.kf_trs(phoenix_piv, 151, loc=(0, 0, 1.56), rot_deg=(-18, 0, 0), scale=0.01)

    for w_piv, side_s in wings:
        bc.kf_trs(w_piv, 1, rot_deg=(0, -side_s * 70, side_s * 48), scale=0.20)
        bc.kf_trs(w_piv, 36, rot_deg=(16, -side_s * 50, side_s * 32), scale=0.96)
        bc.kf_trs(w_piv, 78, rot_deg=(30, -side_s * 66, side_s * 52), scale=0.92)
        bc.kf_trs(w_piv, 92, rot_deg=(-10, side_s * 14, -side_s * 8), scale=1.20)
        bc.kf_trs(w_piv, 112, rot_deg=(10, -side_s * 14, side_s * 12), scale=1.14)
        bc.kf_trs(w_piv, 132, rot_deg=(-14, side_s * 20, -side_s * 10), scale=1.10)
        bc.kf_trs(w_piv, 151, rot_deg=(-26, side_s * 38, 0), scale=0.05)

    for ri, rib in enumerate(cyclone_ribbons):
        bc.kf_trs(rib, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(rib, 36, loc=(0, 0, 0.04), rot_deg=(0, 0, 220), scale=0.96)
        bc.kf_trs(rib, 80, loc=(0, 0, 0.06), rot_deg=(0, 0, 560), scale=(0.74, 0.74, 1.02))
        bc.kf_trs(rib, 92, loc=(0, 0, 0.08), rot_deg=(0, 0, 760), scale=(1.18, 1.18, 1.16))
        bc.kf_trs(rib, 128, loc=(0, 0, 0.12), rot_deg=(0, 0, 1020), scale=(1.02, 1.02, 1.04))
        bc.kf_trs(rib, 151, loc=(0, 0, 0.16), rot_deg=(0, 0, 1200), scale=0.01)

    for ti, (ft_piv, ang) in enumerate(flame_tongues):
        ca, sa = math.cos(ang), math.sin(ang)
        bc.kf_trs(ft_piv, 1, loc=(ca * 0.96, sa * 0.96, -0.10), scale=0.01)
        bc.kf_trs(ft_piv, 30 + (ti % 4) * 3, loc=(ca * 0.88, sa * 0.88, 0.04), rot_deg=(0, 0, 90), scale=1.04)
        bc.kf_trs(ft_piv, 92, loc=(ca * 1.16, sa * 1.16, 0.06), rot_deg=(0, 0, 260), scale=1.28)
        bc.kf_trs(ft_piv, 128, loc=(ca * 1.24, sa * 1.24, 0.04), rot_deg=(0, 0, 380), scale=1.10)
        bc.kf_trs(ft_piv, 151, loc=(ca * 1.38, sa * 1.38, 0.0), rot_deg=(0, 0, 480), scale=0.01)

    bc.kf_trs(solar_halo, 1, loc=(0, 0, 0.06), scale=0.01)
    bc.kf_trs(solar_halo, 78, loc=(0, 0, 0.56), rot_deg=(0, 0, 160), scale=0.72)
    bc.kf_trs(solar_halo, 92, loc=(0, 0, 1.16), rot_deg=(24, 0, 360), scale=1.34)
    bc.kf_trs(solar_halo, 128, loc=(0, 0, 1.48), rot_deg=(-10, 0, 580), scale=1.18)
    bc.kf_trs(solar_halo, 151, loc=(0, 0, 1.82), rot_deg=(0, 0, 740), scale=0.01)

    bc.kf_trs(solar_dome, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.01)
    bc.kf_trs(solar_dome, 84, loc=(0, 0, 0.02), rot_deg=(0, 0, 45), scale=0.06)
    bc.kf_trs(solar_dome, 96, loc=(0, 0, 0.04), rot_deg=(0, 0, 150), scale=1.18)
    bc.kf_trs(solar_dome, 130, loc=(0, 0, 0.03), rot_deg=(0, 0, 270), scale=1.34)
    bc.kf_trs(solar_dome, 151, loc=(0, 0, 0.01), rot_deg=(0, 0, 350), scale=0.01)

    all_anim = [crucible, solar_pillar, phoenix_piv, solar_halo, solar_dome]
    all_anim += [w[0] for w in wings] + cyclone_ribbons + [f[0] for f in flame_tongues]
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_phoenix_inferno.glb")
    return out_glb, 94


# =============================================================================
# 4. CINEMATIC SHADOW HEX (140f @ 24fps = 5.83s) — UPGRADED TYBW SCALE!
#    Towering abyssal void pillar, colossal All-Seeing Arcane Eye + 3 orbital
#    zodiac rings, 12 giant obsidian mirror monoliths & 8 whipping curse chains!
# =============================================================================

def build_cinematic_shadow_hex() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=141)
    M = make_shared_palette((0.40, 0.03, 0.92), (0.04, 0.84, 0.42), emit_str=2.35)
    root = bc.create_empty("CinematicShadowHexRoot")

    # 1. Colossal 1.24m-radius Occult Ink Nonagram Floor Seal
    hex_seal = bc.create_ornate_ring("ShadowHexagramSeal", 1.24, 1.02, 0.036, notches=9, notch_depth=0.105, segments=54, mat=M["ink"], parent=root)
    hex_glow = bc.create_ornate_ring("ShadowHexagramGlow", 1.06, 0.94, 0.026, notches=9, notch_depth=0.055, segments=54, mat=M["accent"], parent=hex_seal)
    hex_glow.location = Vector((0, 0, 0.012))

    # 2. Towering Pitch-Black Abyssal Void Pillar (2.10m tall)
    void_pillar = create_ink_pillar(
        "ShadowVoidInkPillar", r_base=0.36, r_mid=0.18, r_top=0.34, height=2.10, flutes=9, twist_rad=-2.6,
        mat_ink=M["ink"], mat_rim=M["accent"], parent=root
    )

    # 3. Monumental All-Seeing Arcane Eye + Triple Counter-Rotating Orbital Zodiac Rings!
    eye_piv = bc.create_empty("ArcaneEyeCore", loc=(0, 0, 1.02), parent=root)
    eye_frame = bc.create_ornate_ring("ArcaneEyeEyelid", 0.48, 0.34, 0.056, notches=4, notch_depth=0.088, segments=36, mat=M["gold"], parent=eye_piv)
    eye_frame.rotation_euler = (math.pi * 0.5, 0, 0)
    eye_frame.scale = Vector((1.38, 1.0, 0.78))
    iris = bc.create_ornate_ring("ArcaneEyeIris", 0.30, 0.14, 0.064, notches=12, notch_depth=0.024, segments=32, mat=M["glow"], parent=eye_piv)
    iris.rotation_euler = (math.pi * 0.5, 0, 0)
    pupil = bc.create_faceted_crystal("ArcaneEyePupil", radius=0.075, height=0.42, sides=4, tip_ratio=0.45, bottom_taper=0.45, mat=M["ink"], parent=eye_piv)
    pupil.location = Vector((0, 0, -0.21))
    pupil_glint = bc.create_faceted_crystal("ArcaneEyeGlint", radius=0.032, height=0.46, sides=4, tip_ratio=0.45, bottom_taper=0.45, mat=M["white"], parent=eye_piv)
    pupil_glint.location = Vector((0, -0.02, -0.23))

    rune_outer = bc.create_ornate_ring("HexRuneRing_Outer", 0.98, 0.88, 0.032, notches=16, notch_depth=0.052, segments=64, mat=M["accent"], parent=eye_piv)
    rune_mid = bc.create_ornate_ring("HexRuneRing_Mid", 0.76, 0.68, 0.028, notches=12, notch_depth=0.040, segments=48, mat=M["glow"], parent=eye_piv)
    rune_inner = bc.create_ornate_ring("HexRuneRing_Inner", 0.58, 0.51, 0.026, notches=8, notch_depth=0.030, segments=36, mat=M["ink"], parent=eye_piv)

    # 4. 12 Giant Fractured Obsidian & Emerald/Violet Mirror Shards in Kaleidoscopic Orbit
    shards = []
    for si in range(12):
        ang = (float(si) / 12.0) * math.tau
        sh = create_mirror_shard(
            f"MirrorShard_{si}", w=0.32, h=0.68, th=0.036,
            skew=0.068 if si % 2 == 0 else -0.068,
            mat_face=M["glow"] if si % 2 == 0 else M["accent"],
            mat_rim=M["ink"] if si % 2 == 0 else M["gold"],
            parent=root
        )
        shards.append((sh, ang))

    # 5. 8 Towering Forged Violet-Emerald Curse Chains
    chains = []
    for ci in range(8):
        ang = (float(ci) / 8.0) * math.tau + 0.20
        ch_piv = bc.create_empty(f"CurseChainPivot_{ci}", loc=(math.cos(ang) * 1.05, math.sin(ang) * 1.05, 0.0), parent=root)
        ch = bc.create_chain_strand(
            f"CurseChain_{ci}", link_count=12, link_len=0.145, link_w=0.072, wire_r=0.017,
            mat=M["accent"] if ci % 2 == 0 else M["iron"], parent=ch_piv
        )
        ch.rotation_euler = (math.radians(-24.0), 0.0, ang)
        chains.append((ch_piv, ang))

    # --- 4-PHASE ANIMATION (1..141 @ 24fps = 5.83s, Climax Shatter at frame 87 = 3.58s) ---
    bc.kf_trs(hex_seal, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(hex_seal, 30, loc=(0, 0, 0.03), rot_deg=(0, 0, -110), scale=1.06)
    bc.kf_trs(hex_seal, 76, loc=(0, 0, 0.03), rot_deg=(0, 0, -320), scale=0.92)
    bc.kf_trs(hex_seal, 87, loc=(0, 0, 0.05), rot_deg=(0, 0, -440), scale=1.38)
    bc.kf_trs(hex_seal, 118, loc=(0, 0, 0.03), rot_deg=(0, 0, -580), scale=1.18)
    bc.kf_trs(hex_seal, 141, loc=(0, 0, 0.02), rot_deg=(0, 0, -700), scale=0.01)

    bc.kf_trs(void_pillar, 1, loc=(0, 0, 0), rot_deg=(0, 0, 0), scale=(0.04, 0.04, 0.02))
    bc.kf_trs(void_pillar, 32, loc=(0, 0, 0), rot_deg=(0, 0, -140), scale=(0.78, 0.78, 0.88))
    bc.kf_trs(void_pillar, 78, loc=(0, 0, 0), rot_deg=(0, 0, -380), scale=(0.56, 0.56, 1.06))
    bc.kf_trs(void_pillar, 87, loc=(0, 0, 0), rot_deg=(0, 0, -520), scale=(1.26, 1.26, 1.18))
    bc.kf_trs(void_pillar, 118, loc=(0, 0, 0), rot_deg=(0, 0, -700), scale=(0.94, 0.94, 1.0))
    bc.kf_trs(void_pillar, 141, loc=(0, 0, 0), rot_deg=(0, 0, -860), scale=(0.01, 0.01, 0.01))

    bc.kf_trs(eye_piv, 1, loc=(0, 0, 0.24), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(eye_piv, 32, loc=(0, 0, 1.02), rot_deg=(0, 0, 26), scale=1.10)
    bc.kf_trs(eye_piv, 76, loc=(0, 0, 1.16), rot_deg=(-10, 0, 38), scale=0.88)
    bc.kf_trs(eye_piv, 87, loc=(0, 0, 1.06), rot_deg=(0, 0, 48), scale=1.40)
    bc.kf_trs(eye_piv, 118, loc=(0, 0, 1.10), rot_deg=(6, 0, 26), scale=1.18)
    bc.kf_trs(eye_piv, 141, loc=(0, 0, 0.30), rot_deg=(0, 0, 0), scale=0.01)

    bc.kf_trs(rune_outer, 1, rot_deg=(48, 0, 0))
    bc.kf_trs(rune_outer, 87, rot_deg=(48, 480, 240))
    bc.kf_trs(rune_outer, 141, rot_deg=(48, 920, 460))

    bc.kf_trs(rune_mid, 1, rot_deg=(-48, 0, 0))
    bc.kf_trs(rune_mid, 87, rot_deg=(-48, -520, -260))
    bc.kf_trs(rune_mid, 141, rot_deg=(-48, -980, -490))

    bc.kf_trs(rune_inner, 1, rot_deg=(0, 52, 0))
    bc.kf_trs(rune_inner, 87, rot_deg=(360, 52, 360))
    bc.kf_trs(rune_inner, 141, rot_deg=(720, 52, 720))

    for si, (sh, ang) in enumerate(shards):
        a1, a2, a3, a4 = ang + 0.65, ang + 1.55, ang + 2.25, ang + 2.95
        bc.kf_trs(sh, 1, loc=(math.cos(ang) * 1.06, math.sin(ang) * 1.06, 0.10), rot_deg=(0, 0, math.degrees(ang)), scale=0.02)
        bc.kf_trs(sh, 34, loc=(math.cos(a1) * 0.94, math.sin(a1) * 0.94, 0.72 + (si % 3) * 0.24), rot_deg=(16, 0, math.degrees(a1) + 90), scale=1.08)
        bc.kf_trs(sh, 76, loc=(math.cos(a2) * 0.72, math.sin(a2) * 0.72, 0.86 + (si % 2) * 0.22), rot_deg=(-20, 14, math.degrees(a2) + 90), scale=1.18)
        bc.kf_trs(sh, 90, loc=(math.cos(a3) * 1.32, math.sin(a3) * 1.32, 0.98 + (si % 3) * 0.22), rot_deg=(38, 28, math.degrees(a3) + 115), scale=1.28)
        bc.kf_trs(sh, 120, loc=(math.cos(a4) * 1.54, math.sin(a4) * 1.54, 0.42), rot_deg=(190 + si * 22, 130, math.degrees(a4) + 210), scale=0.96)
        bc.kf_trs(sh, 141, loc=(math.cos(a4) * 1.72, math.sin(a4) * 1.72, 0.04), rot_deg=(310, 210, 290), scale=0.01)

    for ci, (ch_piv, ang) in enumerate(chains):
        ca, sa = math.cos(ang), math.sin(ang)
        bc.kf_trs(ch_piv, 1, loc=(ca * 1.24, sa * 1.24, -0.35), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(ch_piv, 34, loc=(ca * 0.96, sa * 0.96, 0.04), rot_deg=(0, 0, 50), scale=1.06)
        bc.kf_trs(ch_piv, 76, loc=(ca * 0.70, sa * 0.70, 0.14), rot_deg=(-30, 0, 140), scale=1.18)
        bc.kf_trs(ch_piv, 88, loc=(ca * 1.18, sa * 1.18, 0.10), rot_deg=(20, 0, 210), scale=1.28)
        bc.kf_trs(ch_piv, 120, loc=(ca * 1.32, sa * 1.32, 0.04), rot_deg=(28, 0, 270), scale=1.04)
        bc.kf_trs(ch_piv, 141, loc=(ca * 1.48, sa * 1.48, -0.22), rot_deg=(42, 0, 320), scale=0.01)

    all_anim = [hex_seal, void_pillar, eye_piv, rune_outer, rune_mid, rune_inner] + [s[0] for s in shards] + [c[0] for c in chains]
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_shadow_hex.glb")
    return out_glb, 88


# =============================================================================
# 5. CINEMATIC MIDAS VAULT (152f @ 24fps = 6.33s) — UPGRADED TYBW SCALE!
#    Towering ink-gold sovereign beam, giant Sovereign Crown stamp, triple wide
#    astrolabe orbital gimbals, Bastion Shields/Hourglass & 24-Florin Fountain!
# =============================================================================

def build_cinematic_midas_vault() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=153)
    M = make_shared_palette((0.92, 0.50, 0.03), (1.0, 0.78, 0.10), emit_str=2.10)
    mat_ruby = bc.make_pbr_mat(
        "Mat_CineRubyGem", base_color=(0.78, 0.02, 0.04, 1.0), metallic=0.15, roughness=0.12,
        emission_color=(0.94, 0.03, 0.06, 1.0), emission_strength=2.4
    )
    root = bc.create_empty("CinematicMidasVaultRoot")

    # 1. Colossal 1.28m-radius Sovereign Decree Ink-Gold Astrolabe Base
    decree_ring = bc.create_ornate_ring("MidasDecreeRing", 1.28, 1.04, 0.042, notches=16, notch_depth=0.088, segments=64, mat=M["ink"], parent=root)
    decree_glow = bc.create_ornate_ring("MidasDecreeGlow", 1.08, 0.96, 0.030, notches=16, notch_depth=0.046, segments=64, mat=M["glow"], parent=decree_ring)
    decree_glow.location = Vector((0, 0, 0.012))

    # 2. Towering Pitch-Black & Molten-Gold Sovereign Vault Beam (2.20m tall)
    sovereign_beam = create_ink_pillar(
        "MidasSovereignPillar", r_base=0.38, r_mid=0.18, r_top=0.36, height=2.20, flutes=8, twist_rad=1.8,
        mat_ink=M["ink"], mat_rim=M["glow"], parent=root
    )

    # 3. Colossal Gilded Sovereign Crown hovering majestically above the Bastion!
    crown_piv = bc.create_empty("MidasCrownTier", loc=(0, 0, 1.38), parent=root)
    bc.create_ornate_ring("MidasCrownBand", 0.54, 0.44, 0.18, notches=10, notch_depth=0.048, segments=40, mat=M["gold"], parent=crown_piv)
    for si in range(10):
        ang = (float(si) / 10.0) * math.tau
        spire = bc.create_faceted_crystal(f"MidasCrownSpire_{si}", radius=0.075, height=0.38, sides=4, tip_ratio=0.55, bottom_taper=0.72, mat=M["gold"], parent=crown_piv)
        spire.location = Vector((math.cos(ang) * 0.49, math.sin(ang) * 0.49, 0.08))
        gem = bc.create_faceted_crystal(f"MidasCrownGem_{si}", radius=0.048, height=0.11, sides=6, mat=mat_ruby if si % 2 == 0 else M["white"], parent=crown_piv)
        gem.location = Vector((math.cos(ang) * 0.56, math.sin(ang) * 0.56, -0.02))

    # Triple Wide Orbital Astrolabe Gimbals
    astro_outer = bc.create_ornate_ring("AstrolabeOuterGimbal", 1.12, 0.98, 0.036, notches=16, notch_depth=0.056, segments=64, mat=M["brass"], parent=root)
    astro_mid = bc.create_ornate_ring("AstrolabeMidGimbal", 0.90, 0.78, 0.032, notches=12, notch_depth=0.044, segments=48, mat=M["gold"], parent=root)
    astro_inner = bc.create_ornate_ring("AstrolabeInnerGimbal", 0.72, 0.63, 0.028, notches=8, notch_depth=0.034, segments=40, mat=M["glow"], parent=root)

    # 4. Central Bastion Shields & Chronos Hourglass Fortress
    bastion_piv = bc.create_empty("BastionHourglassCore", loc=(0, 0, 0.56), parent=root)
    bc.create_lathe_mesh(
        "ChronosHourglassBulb",
        [(0.19, -0.32), (0.17, -0.20), (0.04, 0.0), (0.17, 0.20), (0.19, 0.32)],
        segments=28, mat=M["glow"], smooth=True, parent=bastion_piv
    )
    for ang_y, tag in [(0.0, "Front"), (180.0, "Back"), (90.0, "Right"), (-90.0, "Left")]:
        sh = create_heraldic_shield(f"BastionShield_{tag}", w=0.52, h=0.64, th=0.048, mat_body=M["ink"], mat_trim=M["gold"], parent=bastion_piv)
        rad_s = 0.34
        a = math.radians(ang_y)
        sh.location = Vector((math.sin(a) * rad_s, -math.cos(a) * rad_s, 0.0))
        sh.rotation_euler = (0.0, 0.0, a)

    # 5. 24 Large Sculpted 3D Golden Florins Fountain-Bursting across 1.6m Arena!
    coins = []
    for ci in range(24):
        ang = (float(ci) / 24.0) * math.tau
        c_piv = bc.create_empty(f"VaultCoinPivot_{ci}", loc=(0, 0, 0.45), parent=root)
        bc.create_lathe_mesh(
            f"VaultCoin_{ci}", [(0.105, -0.020), (0.114, 0.0), (0.105, 0.020)],
            segments=20, mat=M["gold"] if ci % 2 == 0 else M["glow"], smooth=False, parent=c_piv
        )
        coins.append((c_piv, ang, ci))

    # --- 4-PHASE ANIMATION (1..153 @ 24fps = 6.33s, Sovereign Stamp Climax at frame 92 = 3.79s) ---
    bc.kf_trs(decree_ring, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(decree_ring, 32, loc=(0, 0, 0.03), rot_deg=(0, 0, 140), scale=1.08)
    bc.kf_trs(decree_ring, 80, loc=(0, 0, 0.03), rot_deg=(0, 0, 380), scale=0.94)
    bc.kf_trs(decree_ring, 92, loc=(0, 0, 0.05), rot_deg=(0, 0, 490), scale=1.36)
    bc.kf_trs(decree_ring, 128, loc=(0, 0, 0.03), rot_deg=(0, 0, 660), scale=1.18)
    bc.kf_trs(decree_ring, 153, loc=(0, 0, 0.02), rot_deg=(0, 0, 800), scale=0.01)

    bc.kf_trs(sovereign_beam, 1, loc=(0, 0, 0), rot_deg=(0, 0, 0), scale=(0.04, 0.04, 0.02))
    bc.kf_trs(sovereign_beam, 34, loc=(0, 0, 0), rot_deg=(0, 0, 120), scale=(0.76, 0.76, 0.88))
    bc.kf_trs(sovereign_beam, 80, loc=(0, 0, 0), rot_deg=(0, 0, 320), scale=(0.56, 0.56, 1.04))
    bc.kf_trs(sovereign_beam, 92, loc=(0, 0, 0), rot_deg=(0, 0, 440), scale=(1.26, 1.26, 1.16))
    bc.kf_trs(sovereign_beam, 128, loc=(0, 0, 0), rot_deg=(0, 0, 620), scale=(0.94, 0.94, 1.00))
    bc.kf_trs(sovereign_beam, 153, loc=(0, 0, 0), rot_deg=(0, 0, 760), scale=(0.01, 0.01, 0.01))

    bc.kf_trs(crown_piv, 1, loc=(0, 0, 0.42), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(crown_piv, 36, loc=(0, 0, 1.42), rot_deg=(10, 0, 200), scale=1.10)
    bc.kf_trs(crown_piv, 80, loc=(0, 0, 1.72), rot_deg=(-12, 0, 460), scale=1.22)
    # Royal Vault Stamp at frame 92!
    bc.kf_trs(crown_piv, 92, loc=(0, 0, 1.24), rot_deg=(0, 0, 580), scale=1.36)
    bc.kf_trs(crown_piv, 128, loc=(0, 0, 1.32), rot_deg=(0, 0, 760), scale=1.20)
    bc.kf_trs(crown_piv, 153, loc=(0, 0, 0.35), rot_deg=(0, 0, 920), scale=0.01)

    for astro, r0, r1, r2, dir_s in [
        (astro_outer, (48, -24, 0), (-54, 34, 480), (62, -46, 860), 1.0),
        (astro_mid, (-52, 28, 0), (56, -32, -520), (-64, 42, -920), -1.0),
        (astro_inner, (22, 58, 0), (-32, -56, 600), (42, 62, 1080), 1.0),
    ]:
        bc.kf_trs(astro, 1, loc=(0, 0, 0.24), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(astro, 36, loc=(0, 0, 0.72), rot_deg=(r0[0], r0[1], dir_s * 180), scale=1.06)
        bc.kf_trs(astro, 92, loc=(0, 0, 0.68), rot_deg=r1, scale=1.28)
        bc.kf_trs(astro, 128, loc=(0, 0, 0.72), rot_deg=(r1[0] * 0.7, r1[1] * 0.7, r2[2] * 0.8), scale=1.14)
        bc.kf_trs(astro, 153, loc=(0, 0, 0.20), rot_deg=r2, scale=0.01)

    bc.kf_trs(bastion_piv, 1, loc=(0, 0, 0.20), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(bastion_piv, 36, loc=(0, 0, 0.58), rot_deg=(0, 0, 200), scale=1.06)
    bc.kf_trs(bastion_piv, 80, loc=(0, 0, 0.66), rot_deg=(180, 0, 440), scale=0.92)
    bc.kf_trs(bastion_piv, 92, loc=(0, 0, 0.56), rot_deg=(180, 0, 580), scale=1.28)
    bc.kf_trs(bastion_piv, 128, loc=(0, 0, 0.60), rot_deg=(360, 0, 780), scale=1.12)
    bc.kf_trs(bastion_piv, 153, loc=(0, 0, 0.16), rot_deg=(360, 0, 940), scale=0.01)

    for c_piv, ang, ci in coins:
        r_mid = 0.86 + (ci % 3) * 0.24
        r_far = 1.32 + (ci % 4) * 0.20
        z_apex = 0.84 + (ci % 4) * 0.26
        bc.kf_trs(c_piv, 1, loc=(0, 0, 0.34), scale=0.01)
        bc.kf_trs(c_piv, 82, loc=(math.cos(ang) * 0.36, math.sin(ang) * 0.36, 0.48), rot_deg=(45, 0, 0), scale=0.18)
        bc.kf_trs(c_piv, 96, loc=(math.cos(ang) * r_mid, math.sin(ang) * r_mid, z_apex), rot_deg=(75 + ci * 18, 45, math.degrees(ang)), scale=1.24)
        bc.kf_trs(c_piv, 130, loc=(math.cos(ang) * r_far, math.sin(ang) * r_far, 0.12), rot_deg=(390 + ci * 22, 240, 190), scale=1.04)
        bc.kf_trs(c_piv, 153, loc=(math.cos(ang) * (r_far + 0.18), math.sin(ang) * (r_far + 0.18), 0.04), rot_deg=(540, 340, 260), scale=0.01)

    all_anim = [decree_ring, sovereign_beam, crown_piv, astro_outer, astro_mid, astro_inner, bastion_piv] + [c[0] for c in coins]
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_midas_vault.glb")
    return out_glb, 96


# =============================================================================
# 6. CINEMATIC RIVAL SLAM (138f @ 24fps = 5.75s) — UPGRADED TYBW SCALE!
#    Colossal War-Crest & Crossed 1.6m Obsidian Greatswords slamming from Z=1.85m,
#    seismic TYBW shockwave dome, 12 radial cleave spikes & roaring ink-flame rings!
# =============================================================================

def build_cinematic_rival_slam() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=139)
    M = make_shared_palette((0.84, 0.05, 0.02), (1.0, 0.44, 0.04), emit_str=2.35)
    root = bc.create_empty("CinematicRivalSlamRoot")

    # 1. Colossal Dark-Ink & Gilded Rival War-Crest + Crossed 1.6m Halberd Greatswords!
    crest_piv = bc.create_empty("RivalWarCrest", loc=(0, 0, 0.88), parent=root)
    create_heraldic_shield("RivalCrestShield", w=0.78, h=0.96, th=0.072, mat_body=M["ink"], mat_trim=M["gold"], parent=crest_piv)
    crest_crown = bc.create_ornate_ring("RivalCrestCrown", 0.32, 0.24, 0.105, notches=8, notch_depth=0.046, segments=32, mat=M["gold"], parent=crest_piv)
    crest_crown.location = Vector((0, 0, 0.50))
    for sx in (-1.0, 1.0):
        blade = bc.create_medieval_sword(
            f"RivalCrestHalberd_{int(sx)}", blade_len=1.52, blade_w=0.165, guard_w=0.46, curved=True,
            mat_blade=M["ink"], mat_guard=M["gold"], mat_grip=M["obsidian"], mat_rune=M["glow"], parent=crest_piv
        )
        blade.location = Vector((sx * 0.28, 0.08, -0.28))
        blade.rotation_euler = (0.0, math.radians(sx * 36.0), 0.0)

    # 2. Colossal Floating Dark-Ink & Gold Boss Emblem Rings
    emblem_outer = bc.create_ornate_ring("RivalEmblemRing_Outer", 1.24, 1.02, 0.044, notches=16, notch_depth=0.098, segments=64, mat=M["ink"], parent=root)
    emblem_outer_glow = bc.create_ornate_ring("RivalEmblemRing_OuterGlow", 1.06, 0.94, 0.032, notches=16, notch_depth=0.052, segments=64, mat=M["accent"], parent=emblem_outer)
    emblem_outer_glow.location = Vector((0, 0, 0.012))
    emblem_inner = bc.create_ornate_ring("RivalEmblemRing_Inner", 0.78, 0.64, 0.038, notches=10, notch_depth=0.062, segments=48, mat=M["gold"], parent=root)

    # 3. 12 Colossal Radial Cleave Spikes erupting outward from the seismic slam crater!
    spikes = []
    for si in range(12):
        ang = (float(si) / 12.0) * math.tau
        sp_piv = bc.create_empty(f"SlamSpikePivot_{si}", loc=(math.cos(ang) * 0.74, math.sin(ang) * 0.74, 0.0), parent=root)
        sp = bc.create_faceted_crystal(
            f"SlamSpike_{si}", radius=0.105, height=1.02, sides=5, tip_ratio=0.45, bottom_taper=0.68,
            mat=M["ink"] if si % 3 == 0 else (M["accent"] if si % 3 == 1 else M["gold"]), parent=sp_piv
        )
        sp.rotation_euler = (math.radians(-36.0) * math.sin(ang), math.radians(36.0) * math.cos(ang), ang)
        spikes.append((sp_piv, ang))

    # 4. Seismic TYBW Impact Shockwave Dome + Twin Expanding Cleave Rings + Roaring Ribbons
    slam_dome = create_shockwave_dome("RivalSlamDome", radius=1.42, height=1.06, ribs=12, mat_core=M["ink"], mat_rim=M["glow"], parent=root)
    shock_a = bc.create_ornate_ring("SlamShockwave_A", 1.36, 1.18, 0.042, notches=20, notch_depth=0.098, segments=64, mat=M["glow"], parent=root)
    shock_b = bc.create_ornate_ring("SlamShockwave_B", 0.96, 0.82, 0.034, notches=16, notch_depth=0.072, segments=48, mat=M["white"], parent=root)
    ribbons = []
    for ri in range(3):
        rib = bc.create_twisted_ribbon(
            f"RivalBurstRibbon_{ri}", radius_start=0.88, radius_end=1.32, height=0.88, turns=1.05,
            width=0.062, thickness=0.018, steps=34, phase_deg=ri * 120.0,
            mat=M["accent"] if ri % 2 == 0 else M["glow"], parent=root
        )
        ribbons.append(rib)

    # --- 4-PHASE ANIMATION (1..139 @ 24fps = 5.75s, War-Crest Slam at frame 85 = 3.50s) ---
    bc.kf_trs(crest_piv, 1, loc=(0, -0.18, 0.16), rot_deg=(-16, 0, 0), scale=0.02)
    bc.kf_trs(crest_piv, 34, loc=(0, -0.08, 1.24), rot_deg=(14, 0, 0), scale=1.08)
    bc.kf_trs(crest_piv, 74, loc=(0, -0.16, 1.82), rot_deg=(28, 0, 0), scale=1.22)
    # Frame 85: COLOSSAL WAR-CREST SLAM INTO ARENA!
    bc.kf_trs(crest_piv, 85, loc=(0, 0.04, 0.72), rot_deg=(-14, 0, 12), scale=1.32)
    bc.kf_trs(crest_piv, 91, loc=(0, 0.04, 0.78), rot_deg=(-10, 4, 15), scale=1.26)
    bc.kf_trs(crest_piv, 98, loc=(0, 0.04, 0.72), rot_deg=(-13, -2, 12), scale=1.24)
    bc.kf_trs(crest_piv, 118, loc=(0, 0.04, 0.74), rot_deg=(-12, 0, 12), scale=1.18)
    bc.kf_trs(crest_piv, 139, loc=(0, 0.04, 0.12), rot_deg=(-12, 0, 0), scale=0.01)

    bc.kf_trs(emblem_outer, 1, loc=(0, 0, 0.03), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(emblem_outer, 34, loc=(0, 0, 0.28), rot_deg=(16, 0, 140), scale=1.06)
    bc.kf_trs(emblem_outer, 76, loc=(0, 0, 0.64), rot_deg=(24, 0, 340), scale=0.92)
    bc.kf_trs(emblem_outer, 85, loc=(0, 0, 0.05), rot_deg=(0, 0, 460), scale=1.36)
    bc.kf_trs(emblem_outer, 118, loc=(0, 0, 0.03), rot_deg=(0, 0, 620), scale=1.18)
    bc.kf_trs(emblem_outer, 139, loc=(0, 0, 0.02), rot_deg=(0, 0, 740), scale=0.01)

    bc.kf_trs(emblem_inner, 1, loc=(0, 0, 0.06), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(emblem_inner, 34, loc=(0, 0, 0.56), rot_deg=(-18, 0, -180), scale=1.10)
    bc.kf_trs(emblem_inner, 76, loc=(0, 0, 0.98), rot_deg=(-26, 0, -420), scale=0.95)
    bc.kf_trs(emblem_inner, 85, loc=(0, 0, 0.12), rot_deg=(0, 0, -560), scale=1.40)
    bc.kf_trs(emblem_inner, 118, loc=(0, 0, 0.08), rot_deg=(0, 0, -720), scale=1.18)
    bc.kf_trs(emblem_inner, 139, loc=(0, 0, 0.03), rot_deg=(0, 0, -860), scale=0.01)

    for si, (sp_piv, ang) in enumerate(spikes):
        ca, sa = math.cos(ang), math.sin(ang)
        bc.kf_trs(sp_piv, 1, loc=(ca * 0.56, sa * 0.56, -0.22), scale=0.01)
        bc.kf_trs(sp_piv, 78, loc=(ca * 0.56, sa * 0.56, -0.10), scale=0.06)
        bc.kf_trs(sp_piv, 89, loc=(ca * 1.06, sa * 1.06, 0.05), rot_deg=(0, 0, 48), scale=1.28)
        bc.kf_trs(sp_piv, 118, loc=(ca * 1.28, sa * 1.28, 0.04), rot_deg=(0, 0, 95), scale=1.14)
        bc.kf_trs(sp_piv, 139, loc=(ca * 1.46, sa * 1.46, -0.16), rot_deg=(0, 0, 140), scale=0.01)

    bc.kf_trs(slam_dome, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.01)
    bc.kf_trs(slam_dome, 80, loc=(0, 0, 0.02), rot_deg=(0, 0, 20), scale=0.06)
    bc.kf_trs(slam_dome, 91, loc=(0, 0, 0.05), rot_deg=(0, 0, 130), scale=1.18)
    bc.kf_trs(slam_dome, 120, loc=(0, 0, 0.03), rot_deg=(0, 0, 250), scale=1.34)
    bc.kf_trs(slam_dome, 139, loc=(0, 0, 0.01), rot_deg=(0, 0, 320), scale=0.01)

    for sh_obj, delay, max_sc in ((shock_a, 0, 1.42), (shock_b, 4, 1.32)):
        bc.kf_trs(sh_obj, 1, loc=(0, 0, 0.03), scale=0.01)
        bc.kf_trs(sh_obj, 82 + delay, loc=(0, 0, 0.03), scale=0.10)
        bc.kf_trs(sh_obj, 93 + delay, loc=(0, 0, 0.08), rot_deg=(0, 0, 120), scale=max_sc * 0.86)
        bc.kf_trs(sh_obj, 118 + delay, loc=(0, 0, 0.05), rot_deg=(0, 0, 250), scale=max_sc)
        bc.kf_trs(sh_obj, 139, loc=(0, 0, 0.02), rot_deg=(0, 0, 330), scale=0.01)

    for ri, rib in enumerate(ribbons):
        bc.kf_trs(rib, 1, loc=(0, 0, 0.03), scale=0.01)
        bc.kf_trs(rib, 80, loc=(0, 0, 0.03), rot_deg=(0, 0, 110), scale=0.28)
        bc.kf_trs(rib, 92, loc=(0, 0, 0.08), rot_deg=(0, 0, 380), scale=1.14)
        bc.kf_trs(rib, 118, loc=(0, 0, 0.12), rot_deg=(0, 0, 680), scale=1.02)
        bc.kf_trs(rib, 139, loc=(0, 0, 0.16), rot_deg=(0, 0, 860), scale=0.01)

    all_anim = [crest_piv, emblem_outer, emblem_inner, slam_dome, shock_a, shock_b] + [s[0] for s in spikes] + ribbons
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_rival_slam.glb")
    return out_glb, 90


# =============================================================================
# 7. NEW: CINEMATIC TYBW GETSUGA (144f @ 24fps = 6.00s) — Bankai Crescent / Getsuga Cataclysm
#    Pitch-black obsidian spiritual pillar erupting from carved ink-circle floor sigil,
#    twin towering crescent blade arcs sweeping violently with blazing crimson-and-white
#    energy edges, 10 orbiting broken steel monolith shards & explosive shockwave dome!
# =============================================================================

def build_cinematic_tybw_getsuga() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=145)
    M = make_shared_palette((0.88, 0.015, 0.035), (1.0, 0.12, 0.08), emit_str=2.65)
    root = bc.create_empty("CinematicTybwGetsugaRoot")

    # 1. Carved Pitch-Black Sumi-Ink Circle Floor Sigil with Blazing Crimson & White Hairline Rings
    ink_sigil = bc.create_ornate_ring("GetsugaInkSigilOuter", 1.36, 1.06, 0.038, notches=16, notch_depth=0.14, segments=64, mat=M["ink"], parent=root)
    sigil_red = bc.create_ornate_ring("GetsugaSigilCrimsonRim", 1.12, 1.00, 0.030, notches=16, notch_depth=0.07, segments=64, mat=M["accent"], parent=ink_sigil)
    sigil_red.location = Vector((0, 0, 0.014))
    sigil_white = bc.create_ornate_ring("GetsugaSigilWhiteHair", 0.72, 0.67, 0.024, notches=8, notch_depth=0.05, segments=48, mat=M["white"], parent=ink_sigil)
    sigil_white.location = Vector((0, 0, 0.018))

    # 2. Towering Pitch-Black Obsidian Spiritual Pillar (2.35m tall!) wrapped in crimson & white-hot ribbons
    getsuga_pillar = create_ink_pillar(
        "GetsugaObsidianPillar", r_base=0.46, r_mid=0.22, r_top=0.44, height=2.35, flutes=10, twist_rad=3.2,
        mat_ink=M["ink"], mat_rim=M["accent"], parent=root
    )
    pillar_white_rib = bc.create_twisted_ribbon(
        "GetsugaPillarWhiteSpiral", radius_start=0.52, radius_end=0.48, height=2.25, turns=1.65,
        width=0.042, thickness=0.014, steps=44, phase_deg=45.0, mat=M["white"], parent=getsuga_pillar
    )

    # 3. TWIN TOWERING CRESCENT BLADE ARCS (Getsuga Jujisho X-Cross Cataclysm!)
    crescent_a_piv = bc.create_empty("GetsugaCrescent_A_Pivot", loc=(0, 0, 1.05), parent=root)
    crescent_a = create_crescent_blade_arc(
        "GetsugaCrescent_A", radius=1.28, span_deg=168.0, width=0.42, thick=0.068,
        mat_ink=M["ink"], mat_edge=M["accent"], mat_white=M["white"], parent=crescent_a_piv
    )
    crescent_a.rotation_euler = (math.radians(38.0), math.radians(-26.0), 0.0)

    crescent_b_piv = bc.create_empty("GetsugaCrescent_B_Pivot", loc=(0, 0, 1.18), parent=root)
    crescent_b = create_crescent_blade_arc(
        "GetsugaCrescent_B", radius=1.34, span_deg=168.0, width=0.44, thick=0.068,
        mat_ink=M["ink"], mat_edge=M["glow"], mat_white=M["white"], parent=crescent_b_piv
    )
    crescent_b.rotation_euler = (math.radians(-38.0), math.radians(26.0), math.radians(180.0))

    # 4. 10 Orbiting Broken Steel & Obsidian Monolith Shards with Crimson Fracture Veins!
    monoliths = []
    for mi in range(10):
        ang = (float(mi) / 10.0) * math.tau
        m_piv = bc.create_empty(f"GetsugaMonolithPivot_{mi}", loc=(math.cos(ang) * 1.18, math.sin(ang) * 1.18, 0.65), parent=root)
        create_monolith_shard(
            f"GetsugaMonolith_{mi}", w=0.20 + (mi % 3) * 0.05, d=0.14 + (mi % 2) * 0.04, h=0.72 + (mi % 3) * 0.22,
            mat_body=M["iron"] if mi % 2 == 0 else M["ink"], mat_crack=M["accent"] if mi % 2 == 0 else M["white"], parent=m_piv
        )
        monoliths.append((m_piv, ang, mi))

    # 5. Explosive Climax Shockwave Dome + Double Jagged Outer Cleave Rings
    cataclysm_dome = create_shockwave_dome("GetsugaCataclysmDome", radius=1.52, height=1.24, ribs=16, mat_core=M["ink"], mat_rim=M["accent"], parent=root)
    outer_cleave = bc.create_ornate_ring("GetsugaOuterCleaveRing", 1.56, 1.38, 0.036, notches=24, notch_depth=0.14, segments=72, mat=M["white"], parent=root)

    # --- 4-PHASE ANIMATION (1..145 @ 24fps = 6.00s, Twin Crescent Slash Climax frames 82-98!) ---
    # Phase 1 (1..34): Ink sigil cracks open, pillar erupts, monoliths lift off floor
    # Phase 2 (34..78): Pillar charges black-red spiritual pressure, monoliths orbit tightly, crescents wind up
    # Phase 3 (78..100): TWIN CRESCENT BLADE ARCS SWEEP VIOLENTLY ACROSS ARENA + EXPLOSIVE SHOCKWAVE DOME!
    # Phase 4 (100..145): Dramatic lingering crimson-ink aftermath -> graceful dissipation
    bc.kf_trs(ink_sigil, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(ink_sigil, 30, loc=(0, 0, 0.03), rot_deg=(0, 0, 95), scale=1.08)
    bc.kf_trs(ink_sigil, 78, loc=(0, 0, 0.03), rot_deg=(0, 0, 290), scale=0.92)
    bc.kf_trs(ink_sigil, 90, loc=(0, 0, 0.05), rot_deg=(0, 0, 410), scale=1.42)
    bc.kf_trs(ink_sigil, 124, loc=(0, 0, 0.03), rot_deg=(0, 0, 540), scale=1.20)
    bc.kf_trs(ink_sigil, 145, loc=(0, 0, 0.02), rot_deg=(0, 0, 650), scale=0.01)

    bc.kf_trs(getsuga_pillar, 1, loc=(0, 0, 0.0), rot_deg=(0, 0, 0), scale=(0.05, 0.05, 0.02))
    bc.kf_trs(getsuga_pillar, 32, loc=(0, 0, 0.0), rot_deg=(0, 0, 140), scale=(0.86, 0.86, 0.92))
    bc.kf_trs(getsuga_pillar, 78, loc=(0, 0, 0.0), rot_deg=(0, 0, 420), scale=(0.62, 0.62, 1.12))
    bc.kf_trs(getsuga_pillar, 88, loc=(0, 0, 0.0), rot_deg=(0, 0, 590), scale=(1.38, 1.38, 1.24))
    bc.kf_trs(getsuga_pillar, 122, loc=(0, 0, 0.0), rot_deg=(0, 0, 820), scale=(1.02, 1.02, 1.04))
    bc.kf_trs(getsuga_pillar, 145, loc=(0, 0, 0.0), rot_deg=(0, 0, 1020), scale=(0.01, 0.01, 0.01))

    # Crescent A: winds up low-left, slashes violently across arena at f84-94, hovers dramatically!
    bc.kf_trs(crescent_a_piv, 1, loc=(0, 0, 0.45), rot_deg=(0, 0, -140), scale=0.01)
    bc.kf_trs(crescent_a_piv, 42, loc=(0, 0, 0.88), rot_deg=(12, -10, -85), scale=0.78)
    bc.kf_trs(crescent_a_piv, 78, loc=(0, -0.15, 0.96), rot_deg=(24, -18, -30), scale=0.92)
    bc.kf_trs(crescent_a_piv, 90, loc=(0, 0.10, 1.12), rot_deg=(-12, 10, 215), scale=1.34)
    bc.kf_trs(crescent_a_piv, 122, loc=(0, 0.14, 1.26), rot_deg=(-8, 6, 320), scale=1.18)
    bc.kf_trs(crescent_a_piv, 145, loc=(0, 0.18, 1.48), rot_deg=(0, 0, 420), scale=0.01)

    # Crescent B: counter-slashes from opposite diagonal forming an iconic X-Jujisho clash at f88-96!
    bc.kf_trs(crescent_b_piv, 1, loc=(0, 0, 0.55), rot_deg=(0, 0, 140), scale=0.01)
    bc.kf_trs(crescent_b_piv, 46, loc=(0, 0, 1.08), rot_deg=(-14, 12, 80), scale=0.78)
    bc.kf_trs(crescent_b_piv, 80, loc=(0, 0.15, 1.18), rot_deg=(-26, 20, 20), scale=0.94)
    bc.kf_trs(crescent_b_piv, 92, loc=(0, -0.08, 1.24), rot_deg=(14, -12, -225), scale=1.38)
    bc.kf_trs(crescent_b_piv, 124, loc=(0, -0.12, 1.38), rot_deg=(10, -8, -335), scale=1.20)
    bc.kf_trs(crescent_b_piv, 145, loc=(0, -0.16, 1.62), rot_deg=(0, 0, -440), scale=0.01)

    for m_piv, ang, mi in monoliths:
        a1, a2, a3, a4 = ang + 0.75, ang + 1.85, ang + 2.65, ang + 3.45
        z_mid = 0.72 + (mi % 3) * 0.34
        bc.kf_trs(m_piv, 1, loc=(math.cos(ang) * 1.12, math.sin(ang) * 1.12, -0.20), rot_deg=(0, 0, math.degrees(ang)), scale=0.01)
        bc.kf_trs(m_piv, 34, loc=(math.cos(a1) * 1.06, math.sin(a1) * 1.06, z_mid), rot_deg=(24, -16, math.degrees(a1)), scale=1.04)
        bc.kf_trs(m_piv, 78, loc=(math.cos(a2) * 0.82, math.sin(a2) * 0.82, z_mid + 0.28), rot_deg=(68, 42, math.degrees(a2) + 90), scale=1.16)
        # Blasted violently outward by twin Getsuga slash!
        bc.kf_trs(m_piv, 92, loc=(math.cos(a3) * 1.54, math.sin(a3) * 1.54, z_mid + 0.42), rot_deg=(160 + mi * 18, 95, math.degrees(a3) + 180), scale=1.28)
        bc.kf_trs(m_piv, 124, loc=(math.cos(a4) * 1.72, math.sin(a4) * 1.72, z_mid + 0.12), rot_deg=(260 + mi * 24, 170, math.degrees(a4) + 270), scale=1.02)
        bc.kf_trs(m_piv, 145, loc=(math.cos(a4) * 1.88, math.sin(a4) * 1.88, 0.05), rot_deg=(340, 240, 340), scale=0.01)

    bc.kf_trs(cataclysm_dome, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.01)
    bc.kf_trs(cataclysm_dome, 82, loc=(0, 0, 0.02), rot_deg=(0, 0, 30), scale=0.06)
    bc.kf_trs(cataclysm_dome, 92, loc=(0, 0, 0.05), rot_deg=(0, 0, 140), scale=1.16)
    bc.kf_trs(cataclysm_dome, 124, loc=(0, 0, 0.04), rot_deg=(0, 0, 260), scale=1.34)
    bc.kf_trs(cataclysm_dome, 145, loc=(0, 0, 0.01), rot_deg=(0, 0, 340), scale=0.01)

    bc.kf_trs(outer_cleave, 1, loc=(0, 0, 0.04), rot_deg=(0, 0, 0), scale=0.01)
    bc.kf_trs(outer_cleave, 84, loc=(0, 0, 0.04), rot_deg=(0, 0, 45), scale=0.08)
    bc.kf_trs(outer_cleave, 94, loc=(0, 0, 0.12), rot_deg=(8, -6, 180), scale=1.24)
    bc.kf_trs(outer_cleave, 126, loc=(0, 0, 0.08), rot_deg=(-4, 4, 320), scale=1.42)
    bc.kf_trs(outer_cleave, 145, loc=(0, 0, 0.02), rot_deg=(0, 0, 420), scale=0.01)

    all_anim = [ink_sigil, getsuga_pillar, crescent_a_piv, crescent_b_piv, cataclysm_dome, outer_cleave] + [m[0] for m in monoliths]
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_tybw_getsuga.glb")
    return out_glb, 91


# =============================================================================
# 8. NEW: CINEMATIC TYBW QUINCY (144f @ 24fps = 6.00s) — Quincy Licht Regen / Starlight Volley
#    Massive elevated electric-cyan 5-pointed sacred star mandala rotating overhead,
#    conjuring 16 gleaming cyan spiritual lances that lock on and dive in staggered waves
#    with piercing cross-shaped impact blooms & geometric cyan-white light cages!
# =============================================================================

def build_cinematic_tybw_quincy() -> tuple:
    bc.reset_scene(fps=24, frame_start=1, frame_end=145)
    M = make_shared_palette((0.04, 0.72, 1.0), (0.36, 0.94, 1.0), emit_str=2.60)
    root = bc.create_empty("CinematicTybwQuincyRoot")

    # 1. Massive Elevated Electric-Cyan 5-Pointed Sacred Star Mandala rotating overhead at Z = 2.02m!
    sky_mandala = create_quincy_star_mandala(
        "QuincySkyStarMandala", radius=1.34, mat_ink=M["ink"], mat_cyan=M["accent"],
        mat_white=M["white"], mat_silver=M["silver"], parent=root
    )
    # Matching ground lock-on target star mandala at Z = 0.03m!
    ground_mandala = create_quincy_star_mandala(
        "QuincyGroundTargetMandala", radius=1.18, mat_ink=M["ink"], mat_cyan=M["glow"],
        mat_white=M["white"], mat_silver=M["silver"], parent=root
    )

    # 2. Geometric Cyan-White Sacred Light Cage snapping around the target arena!
    light_cage = create_quincy_light_cage(
        "QuincySacredLightCage", radius=1.02, height=1.96, sides=8, mat_cyan=M["accent"], mat_white=M["white"], parent=root
    )

    # 3. 16 Gleaming Cyan Spiritual Lances (Heilig Pfeil) diving in 3 Staggered Volley Waves!
    lances = []
    # Wave 0 (4 inner), Wave 1 (6 mid), Wave 2 (6 outer) = 16 total lances!
    wave_configs = [
        (0, 4, 0.42, 0.24, 1.04),
        (1, 6, 0.84, 0.56, 0.96),
        (2, 6, 1.24, 0.88, 0.90),
    ]
    lance_idx = 0
    for wave_id, count, r_sky, r_land, l_len in wave_configs:
        for k in range(count):
            ang = (float(k) / float(count)) * math.tau + wave_id * 0.42
            l_piv = bc.create_empty(f"QuincyLancePivot_{lance_idx}", loc=(math.cos(ang) * r_sky, math.sin(ang) * r_sky, 2.05), parent=root)
            create_quincy_lance(
                f"QuincyLance_{lance_idx}", length=l_len, radius=0.042,
                mat_cyan=M["accent"] if lance_idx % 2 == 0 else M["glow"],
                mat_white=M["white"], mat_ink=M["ink"], parent=l_piv
            )
            lances.append((l_piv, wave_id, ang, r_sky, r_land, lance_idx))
            lance_idx += 1

    # 4. 6 Piercing Cross-Shaped Impact Blooms erupting where the lance waves strike!
    bloom_locs = [
        (0.0, 0.0, 0.84, 0),
        (0.54, 0.34, 0.62, 1), (-0.54, 0.34, 0.62, 1),
        (0.0, -0.62, 0.65, 1), (0.76, -0.44, 0.58, 2), (-0.76, -0.44, 0.58, 2),
    ]
    blooms = []
    for bi, (bx, by, bsz, bwave) in enumerate(bloom_locs):
        b_piv = create_cross_impact_bloom(f"QuincyCrossBloom_{bi}", size=bsz, mat_cyan=M["glow"], mat_white=M["white"], parent=root)
        b_piv.location = Vector((bx, by, 0.02))
        blooms.append((b_piv, bx, by, bwave, bi))

    # --- 4-PHASE ANIMATION (1..145 @ 24fps = 6.00s, Staggered Volley Climax frames 80-100!) ---
    # Overhead Sacred Star Mandala
    bc.kf_trs(sky_mandala, 1, loc=(0, 0, 2.30), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(sky_mandala, 30, loc=(0, 0, 2.06), rot_deg=(0, 0, 120), scale=1.08)
    bc.kf_trs(sky_mandala, 76, loc=(0, 0, 2.12), rot_deg=(6, -4, 340), scale=1.18)
    bc.kf_trs(sky_mandala, 90, loc=(0, 0, 1.98), rot_deg=(0, 0, 480), scale=1.34)
    bc.kf_trs(sky_mandala, 124, loc=(0, 0, 2.04), rot_deg=(0, 0, 660), scale=1.16)
    bc.kf_trs(sky_mandala, 145, loc=(0, 0, 2.35), rot_deg=(0, 0, 780), scale=0.01)

    # Ground Lock-On Target Mandala
    bc.kf_trs(ground_mandala, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(ground_mandala, 32, loc=(0, 0, 0.03), rot_deg=(0, 0, -100), scale=1.04)
    bc.kf_trs(ground_mandala, 76, loc=(0, 0, 0.03), rot_deg=(0, 0, -300), scale=0.96)
    bc.kf_trs(ground_mandala, 90, loc=(0, 0, 0.04), rot_deg=(0, 0, -440), scale=1.32)
    bc.kf_trs(ground_mandala, 124, loc=(0, 0, 0.03), rot_deg=(0, 0, -600), scale=1.14)
    bc.kf_trs(ground_mandala, 145, loc=(0, 0, 0.02), rot_deg=(0, 0, -720), scale=0.01)

    # Geometric Cyan-White Sacred Light Cage
    bc.kf_trs(light_cage, 1, loc=(0, 0, 0.0), rot_deg=(0, 0, 0), scale=(0.04, 0.04, 0.02))
    bc.kf_trs(light_cage, 42, loc=(0, 0, 0.0), rot_deg=(0, 0, 45), scale=(1.18, 1.18, 0.85))
    bc.kf_trs(light_cage, 78, loc=(0, 0, 0.0), rot_deg=(0, 0, 120), scale=(1.24, 1.24, 1.02))
    # Snaps tight around target at climax volley!
    bc.kf_trs(light_cage, 88, loc=(0, 0, 0.0), rot_deg=(0, 0, 180), scale=(0.98, 0.98, 1.10))
    bc.kf_trs(light_cage, 124, loc=(0, 0, 0.0), rot_deg=(0, 0, 260), scale=(1.08, 1.08, 1.04))
    bc.kf_trs(light_cage, 145, loc=(0, 0, 0.0), rot_deg=(0, 0, 340), scale=(0.01, 0.01, 0.01))

    # 16 Spiritual Lances: materialize overhead -> fan & lock on -> pull back -> DIVE IN STAGGERED WAVES!
    for l_piv, wave_id, ang, r_sky, r_land, li in lances:
        ca, sa = math.cos(ang), math.sin(ang)
        f_spawn = 16 + wave_id * 8 + (li % 3) * 2
        f_draw = 72 + wave_id * 5
        f_dive_end = f_draw + 9
        # Tilt inward slightly along radial path so lances visibly aim at arena!
        tilt_x = sa * 14.0
        tilt_y = -ca * 14.0
        bc.kf_trs(l_piv, 1, loc=(ca * r_sky, sa * r_sky, 2.40), rot_deg=(tilt_x, tilt_y, math.degrees(ang)), scale=0.01)
        bc.kf_trs(l_piv, f_spawn, loc=(ca * r_sky, sa * r_sky, 1.92), rot_deg=(tilt_x, tilt_y, math.degrees(ang)), scale=0.92)
        bc.kf_trs(l_piv, f_draw, loc=(ca * (r_sky * 1.12), sa * (r_sky * 1.12), 2.18), rot_deg=(tilt_x * 1.2, tilt_y * 1.2, math.degrees(ang)), scale=1.12)
        # Rapid plunging dive onto arena floor!
        bc.kf_trs(l_piv, f_dive_end, loc=(ca * r_land, sa * r_land, 0.04), rot_deg=(tilt_x * 0.85, tilt_y * 0.85, math.degrees(ang)), scale=1.18)
        # Quivering embedded in arena floor during Phase 4 aftermath
        bc.kf_trs(l_piv, 124, loc=(ca * r_land, sa * r_land, 0.04), rot_deg=(tilt_x * 0.85, tilt_y * 0.85, math.degrees(ang)), scale=1.08)
        bc.kf_trs(l_piv, 145, loc=(ca * r_land, sa * r_land, -0.10), rot_deg=(tilt_x * 0.85, tilt_y * 0.85, math.degrees(ang)), scale=0.01)

    # 6 Piercing Cross-Shaped Impact Blooms erupting as each wave lands!
    for b_piv, bx, by, bwave, bi in blooms:
        f_hit = 80 + bwave * 5
        bc.kf_trs(b_piv, 1, loc=(bx, by, 0.02), rot_deg=(0, 0, bi * 30), scale=0.01)
        bc.kf_trs(b_piv, f_hit - 3, loc=(bx, by, 0.02), rot_deg=(0, 0, bi * 30), scale=0.04)
        bc.kf_trs(b_piv, f_hit + 4, loc=(bx, by, 0.04), rot_deg=(0, 0, bi * 30 + 45), scale=1.32)
        bc.kf_trs(b_piv, 124, loc=(bx, by, 0.03), rot_deg=(0, 0, bi * 30 + 120), scale=1.06)
        bc.kf_trs(b_piv, 145, loc=(bx, by, 0.01), rot_deg=(0, 0, bi * 30 + 180), scale=0.01)

    all_anim = [sky_mandala, ground_mandala, light_cage] + [l[0] for l in lances] + [b[0] for b in blooms]
    for obj in all_anim:
        bc.set_interp(obj, "BEZIER")

    out_glb = bc.export_glb(OUT_VFX_DIR / "cinematic_tybw_quincy.glb")
    return out_glb, 92


# =============================================================================
# 4x2 STUDIO SHOWCASE RENDERER (ALL 8 TYBW CINEMATIC VFX GLBs)
# =============================================================================

def render_tile(png_path: pathlib.Path, frame: int) -> pathlib.Path:
    """Render a 560x480 dark-arena EEVEE preview tile framed for massive 2.3m Bleach TYBW scale."""
    scene = bpy.context.scene
    scene.frame_set(frame)
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scene.render.resolution_x = 560
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(png_path)

    world = bpy.data.worlds.new("TybwTileWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.010, 0.008, 0.014, 1.0)
        bg.inputs[1].default_value = 0.45

    # Dark oak arena stage disc so colossal 2.4m TYBW scale reads clearly
    mat_table = bc.make_pbr_mat("Mat_PreviewTable", base_color=(0.048, 0.022, 0.012, 1.0), metallic=0.06, roughness=0.52)
    mat_rim = bc.make_pbr_mat("Mat_PreviewBrassRim", base_color=(0.52, 0.30, 0.06, 1.0), metallic=0.92, roughness=0.24)
    bc.create_lathe_mesh("PreviewTableDisc", [(1.68, -0.06), (1.72, 0.0)], segments=56, mat=mat_table, smooth=False)
    rim = bc.create_ornate_ring("PreviewTableRim", 1.76, 1.66, 0.035, notches=24, notch_depth=0.022, segments=64, mat=mat_rim)
    rim.location = Vector((0, 0, -0.015))

    cam_data = bpy.data.cameras.new("TileCam")
    cam_data.lens = 33.0
    cam_obj = bpy.data.objects.new("TileCam", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_loc = Vector((2.85, -3.35, 2.22))
    cam_target = Vector((0.0, 0.0, 0.96))
    cam_obj.location = cam_loc
    cam_obj.rotation_euler = (cam_target - cam_loc).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    key_data = bpy.data.lights.new("TileKey", type="AREA")
    key_data.energy = 240.0
    key_data.color = (1.0, 0.86, 0.66)
    key_data.size = 3.8
    key_obj = bpy.data.objects.new("TileKey", key_data)
    scene.collection.objects.link(key_obj)
    key_obj.location = Vector((3.2, -3.6, 4.4))
    key_obj.rotation_euler = (Vector((0, 0, 0.8)) - key_obj.location).normalized().to_track_quat("-Z", "Y").to_euler()

    rim_data = bpy.data.lights.new("TileRim", type="POINT")
    rim_data.energy = 180.0
    rim_data.color = (0.62, 0.78, 1.0)
    rim_obj = bpy.data.objects.new("TileRim", rim_data)
    scene.collection.objects.link(rim_obj)
    rim_obj.location = Vector((-2.8, 3.0, 2.9))

    bpy.ops.render.render(write_still=True)
    return png_path


def stitch_contact_sheet(tile_paths: list, out_path: pathlib.Path, cols: int = 4, rows: int = 2) -> None:
    """Combine 8 (560x480) PNG tiles into a crisp 4x2 (2240x960) showcase contact sheet."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    imgs = [bpy.data.images.load(str(p)) for p in tile_paths]
    tw, th = imgs[0].size
    full_w = tw * cols
    full_h = th * rows
    sheet = bpy.data.images.new("TybwCinematicVfxContactSheet", width=full_w, height=full_h, alpha=False)
    buf = [0.0] * (full_w * full_h * 4)
    row_stride_tile = tw * 4
    row_stride_full = full_w * 4

    for idx, img in enumerate(imgs):
        px = list(img.pixels[:])
        c = idx % cols
        r_inv = (rows - 1) - (idx // cols)
        x_off = c * tw * 4
        y_base = r_inv * th
        for y in range(th):
            in_off = y * row_stride_tile
            out_off = (y_base + y) * row_stride_full + x_off
            buf[out_off : out_off + row_stride_tile] = px[in_off : in_off + row_stride_tile]

    sheet.pixels.foreach_set(buf)
    sheet.filepath_raw = str(out_path)
    sheet.file_format = "PNG"
    sheet.save()
    for p in tile_paths:
        try:
            p.unlink(missing_ok=True)
        except Exception:
            pass
    print("RENDERED_TYBW_VFX_PREVIEW=", out_path)


def main():
    builders = [
        ("vampire", build_cinematic_vampire_crimson),
        ("storm", build_cinematic_storm_tempest),
        ("phoenix", build_cinematic_phoenix_inferno),
        ("hex", build_cinematic_shadow_hex),
        ("midas", build_cinematic_midas_vault),
        ("rival", build_cinematic_rival_slam),
        ("tybw_getsuga", build_cinematic_tybw_getsuga),
        ("tybw_quincy", build_cinematic_tybw_quincy),
    ]
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    tile_paths = []
    for tag, fn in builders:
        glb_path, peak_frame = fn()
        scene = bpy.context.scene
        dur_s = (scene.frame_end - scene.frame_start) / float(scene.render.fps)
        print(
            f"EXPORTED_CINEMATIC_GLB={glb_path.name} "
            f"(size={glb_path.stat().st_size}B, frames={scene.frame_start}..{scene.frame_end}@{scene.render.fps}fps, dur={dur_s:.2f}s, peak={peak_frame})"
        )
        tpath = PREVIEW_PATH.parent / f"_tmp_tybw_{tag}.png"
        render_tile(tpath, peak_frame)
        tile_paths.append(tpath)
    stitch_contact_sheet(tile_paths, PREVIEW_PATH, cols=4, rows=2)
    print("ALL_8_TYBW_CINEMATIC_VFX_DONE")


if __name__ == "__main__":
    main()
