"""
Blender 5.3 headless 3D Tabletop Relics Generator for LIALO:
Exports 10 high-craft, organically sculpted buyable & usable 3D tabletop relics to:
  D:/downpour-godot/assets/models/relics/
    1. TRELIC_SOUL_BELL.glb    - Soul-Severing Bell
    2. TRELIC_BLOOD_SEAL.glb   - Blood-Ink Seal
    3. TRELIC_STAR_BOW.glb     - Quincy Astrolabe
    4. TRELIC_ASH_GLASS.glb    - Ashen Hourglass
    5. TRELIC_WAR_HORN.glb     - Templar War-Horn
    6. TRELIC_HOLLOW_MASK.glb  - Hollow Mask Fragment (Bleach TYBW tribute)
    7. TRELIC_CENSER.glb       - Alchemist's Censer
    8. TRELIC_GOLD_SCALES.glb  - Gilded Merchant Scales
    9. TRELIC_IRON_CHAIN.glb   - Executioner's Chain
   10. TRELIC_PHOENIX_BOX.glb  - Phoenix Reliquary

Conventions:
  - Base rests flush at Blender Z = 0.0 (Godot Y = 0.0 tabletop coaster surface).
  - Hero front faces Blender -Y (Godot +Z toward player in Buckshot ITEM_REVIEW view).
  - Width ~0.12-0.16m, Height ~0.11-0.18m.
  - Rich metallic, glass, bone, obsidian, and emissive PBR materials.
  - Renders a clean 2x5 studio EEVEE showcase PNG to:
      C:/Users/arnos/.gemini/antigravity/brain/a20e3f18-d942-46fa-80e3-721c54108b6d/scratch/preview_10_tabletop_relics.png

Run via:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_tabletop_relics.py
"""

import math
import pathlib
import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

ROOT = pathlib.Path(r"D:\downpour-godot")
RELIC_DIR = ROOT / "assets" / "models" / "relics"
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\scratch\preview_10_tabletop_relics.png"
)


# =============================================================================
# SCENE & PBR MATERIAL LIBRARY (Blender 5.3 + Godot 4.7 GL Compatibility)
# =============================================================================

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    return scene


def make_mat(
    name: str,
    color: tuple,
    metallic: float = 0.0,
    roughness: float = 0.45,
    emission: tuple = (0.0, 0.0, 0.0),
    emit_str: float = 0.0,
    alpha: float = 1.0,
    transmission: float = 0.0,
    coat: float = 0.0,
):
    mat = bpy.data.materials.new(name)
    if not mat.use_nodes:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emit_str
    bsdf.inputs["Alpha"].default_value = alpha
    if "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if "Coat Weight" in bsdf.inputs and coat > 0.0:
        bsdf.inputs["Coat Weight"].default_value = coat
    if alpha < 0.99:
        mat.surface_render_method = "BLENDED"
    return mat


def get_mats():
    return {
        # Rich metals
        "antique_bronze": make_mat("AntiqueBronze", (0.58, 0.37, 0.16), metallic=0.88, roughness=0.27),
        "dark_bronze": make_mat("DarkBronze", (0.34, 0.22, 0.10), metallic=0.84, roughness=0.34),
        "gilded_gold": make_mat("GildedGold", (0.96, 0.74, 0.18), metallic=0.95, roughness=0.17),
        "brushed_gold": make_mat("BrushedGold", (0.86, 0.65, 0.20), metallic=0.90, roughness=0.25),
        "cathedral_brass": make_mat("CathedralBrass", (0.78, 0.56, 0.17), metallic=0.89, roughness=0.23),
        "sterling_silver": make_mat("SterlingSilver", (0.84, 0.87, 0.93), metallic=0.94, roughness=0.16),
        "hammered_steel": make_mat("HammeredSteel", (0.54, 0.58, 0.64), metallic=0.90, roughness=0.27),
        "wrought_iron": make_mat("WroughtIron", (0.14, 0.15, 0.17), metallic=0.84, roughness=0.36),
        "dark_iron": make_mat("DarkIron", (0.09, 0.095, 0.11), metallic=0.80, roughness=0.40),
        "copper": make_mat("Copper", (0.76, 0.36, 0.16), metallic=0.88, roughness=0.26),
        # Stone, wood, organic
        "obsidian": make_mat("Obsidian", (0.032, 0.028, 0.042), metallic=0.24, roughness=0.14, coat=0.5),
        "ebony": make_mat("EbonyWood", (0.055, 0.038, 0.028), metallic=0.02, roughness=0.24, coat=0.3),
        "walnut": make_mat("WalnutWood", (0.20, 0.105, 0.052), metallic=0.0, roughness=0.52),
        "bone_ivory": make_mat("BoneIvory", (0.93, 0.88, 0.78), metallic=0.0, roughness=0.30, coat=0.2),
        "bone_shadow": make_mat("BoneShadow", (0.12, 0.09, 0.085), metallic=0.0, roughness=0.68),
        "horn_dark": make_mat("HornBody", (0.28, 0.19, 0.12), metallic=0.04, roughness=0.34, coat=0.25),
        "horn_tip": make_mat("HornTip", (0.12, 0.085, 0.06), metallic=0.06, roughness=0.30),
        "wax_crimson": make_mat("CrimsonWax", (0.54, 0.032, 0.045), metallic=0.04, roughness=0.20, coat=0.6),
        "tribal_crimson": make_mat(
            "HollowTribalCrimson", (0.74, 0.028, 0.038), metallic=0.06, roughness=0.26,
            emission=(0.68, 0.02, 0.03), emit_str=0.35
        ),
        "velvet_crimson": make_mat("CrimsonVelvet", (0.36, 0.035, 0.05), metallic=0.0, roughness=0.86),
        # Glass & translucent
        "blown_glass": make_mat(
            "BlownGlass", (0.76, 0.90, 0.98), metallic=0.08, roughness=0.06,
            emission=(0.12, 0.24, 0.34), emit_str=0.22, alpha=0.36, transmission=0.65, coat=0.8
        ),
        # Emissive jewels & spiritual energies (calibrated so facets & deep saturation gleam cleanly!)
        "reiatsu_cyan": make_mat(
            "ReiatsuCyan", (0.06, 0.78, 1.0), metallic=0.05, roughness=0.14,
            emission=(0.06, 0.78, 1.0), emit_str=2.1
        ),
        "cold_cyan": make_mat(
            "ColdKeyholeCyan", (0.04, 0.70, 0.98), metallic=0.04, roughness=0.14,
            emission=(0.05, 0.74, 1.0), emit_str=2.3
        ),
        "ruby_glow": make_mat(
            "RubyBloodCrystal", (0.62, 0.008, 0.022), metallic=0.16, roughness=0.10,
            emission=(0.88, 0.012, 0.025), emit_str=1.55, coat=0.7
        ),
        "sapphire_gem": make_mat(
            "SapphireGem", (0.03, 0.22, 0.88), metallic=0.18, roughness=0.11,
            emission=(0.05, 0.30, 0.98), emit_str=1.45, coat=0.7
        ),
        "hollow_gold_eye": make_mat(
            "HollowSlitGold", (1.0, 0.62, 0.02), metallic=0.0, roughness=0.12,
            emission=(1.0, 0.64, 0.02), emit_str=2.8
        ),
        "ash_sand": make_mat(
            "AshenVioletSand", (0.42, 0.05, 0.74), metallic=0.08, roughness=0.28,
            emission=(0.54, 0.08, 0.88), emit_str=1.35
        ),
        "ash_amber": make_mat(
            "AshenAmberSand", (0.94, 0.34, 0.02), metallic=0.06, roughness=0.22,
            emission=(0.98, 0.38, 0.03), emit_str=1.75
        ),
        "ash_ember": make_mat(
            "AshenEmberCore", (1.0, 0.38, 0.02), metallic=0.0, roughness=0.16,
            emission=(1.0, 0.42, 0.03), emit_str=2.4
        ),
        "censer_emerald": make_mat(
            "CenserEmeraldMist", (0.02, 0.76, 0.30), metallic=0.0, roughness=0.18,
            emission=(0.03, 0.84, 0.34), emit_str=1.75
        ),
        "censer_violet": make_mat(
            "CenserVioletMist", (0.40, 0.06, 0.86), metallic=0.0, roughness=0.20,
            emission=(0.48, 0.09, 0.94), emit_str=1.65, alpha=0.80
        ),
        "phoenix_flame": make_mat(
            "PhoenixFlameGold", (0.98, 0.48, 0.03), metallic=0.0, roughness=0.20,
            emission=(1.0, 0.42, 0.02), emit_str=1.85
        ),
        "phoenix_ember": make_mat(
            "PhoenixEmberDeep", (0.86, 0.14, 0.01), metallic=0.0, roughness=0.24,
            emission=(0.92, 0.16, 0.015), emit_str=1.60
        ),
        "phoenix_feather": make_mat(
            "PhoenixCrimsonFeather", (0.64, 0.035, 0.03), metallic=0.36, roughness=0.22,
            emission=(0.52, 0.04, 0.015), emit_str=0.45, coat=0.5
        ),
    }


# =============================================================================
# HIGH-CRAFT BMESH SCULPTING HELPERS
# =============================================================================

def link_part(parent, name: str, bm: bmesh.types.BMesh, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if smooth and len(mesh.polygons) > 0:
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = Vector(loc)
    obj.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    obj.scale = Vector(scale)
    if mat is not None:
        obj.data.materials.append(mat)
    obj.parent = parent
    bpy.context.scene.collection.objects.link(obj)
    return obj


def bm_lathe(parent, name: str, prof: list, mat, segs=32, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True, cap_bot=True, cap_top=True, flute_n=0, flute_amp=0.0):
    bm = bmesh.new()
    rings = []
    for j, (r, z) in enumerate(prof):
        ring = []
        r_safe = max(0.0003, float(r))
        for i in range(segs):
            a = (i / segs) * math.tau
            fl = 1.0 + (flute_amp * math.cos(a * flute_n) if flute_n > 0 else 0.0)
            ring.append(bm.verts.new((math.cos(a) * r_safe * fl, math.sin(a) * r_safe * fl, float(z))))
        rings.append(ring)
    for j in range(len(prof) - 1):
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((rings[j][i], rings[j][ni], rings[j + 1][ni], rings[j + 1][i]))
    if cap_bot and prof[0][0] > 1e-4:
        bm.faces.new(rings[0][::-1])
    if cap_top and prof[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00015)
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def bm_tube(parent, name: str, pts: list, radii: list, mat, segs=14, loc=(0, 0, 0), rot=(0, 0, 0), rib_amp=0.0, rib_freq=2.2, closed_loop=False, aspect_y=1.0):
    bm = bmesh.new()
    n = len(pts)
    rings = []
    prev_u = None
    for idx, (pt, rad) in enumerate(zip(pts, radii)):
        p = Vector(pt)
        if closed_loop:
            tang = (Vector(pts[(idx + 1) % n]) - Vector(pts[(idx - 1) % n])).normalized()
        elif idx == 0:
            tang = (Vector(pts[1]) - p).normalized()
        elif idx == n - 1:
            tang = (p - Vector(pts[-2])).normalized()
        else:
            tang = (Vector(pts[idx + 1]) - Vector(pts[idx - 1])).normalized()
        if prev_u is None:
            up = Vector((0, 0, 1)) if abs(tang.z) < 0.90 else Vector((1, 0, 0))
            u = tang.cross(up).normalized()
        else:
            u = (prev_u - tang * prev_u.dot(tang))
            if u.length < 1e-5:
                up = Vector((0, 0, 1)) if abs(tang.z) < 0.90 else Vector((1, 0, 0))
                u = tang.cross(up).normalized()
            else:
                u.normalize()
        v = tang.cross(u).normalized()
        prev_u = u
        r_eff = max(0.0005, float(rad)) * (1.0 + rib_amp * math.sin(idx * rib_freq))
        ring = []
        for k in range(segs):
            a = (k / segs) * math.tau
            ring.append(bm.verts.new(p + (u * math.cos(a) + v * (math.sin(a) * aspect_y)) * r_eff))
        rings.append(ring)
    limit = n if closed_loop else (n - 1)
    for idx in range(limit):
        nidx = (idx + 1) % n
        for k in range(segs):
            nk = (k + 1) % segs
            bm.faces.new((rings[idx][k], rings[idx][nk], rings[nidx][nk], rings[nidx][k]))
    if not closed_loop:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


def bm_bevel_box(parent, name: str, size: tuple, mat, bevel=0.003, segs=2, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect="EDGES", clamp_overlap=True)
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def bm_cyl(parent, name: str, r1: float, r2: float, h: float, mat, segs=20, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def bm_sphere(parent, name: str, rad: float, mat, scale=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), sub=3, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=rad)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def bm_torus(parent, name: str, maj: float, mn: float, mat, maj_s=32, min_s=12, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), wave_n=0, wave_amp=0.0):
    bm = bmesh.new()
    rings = []
    for i in range(maj_s):
        a = (i / maj_s) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        r_maj = maj + (wave_amp * math.cos(a * wave_n) if wave_n > 0 else 0.0)
        z_off = (wave_amp * 0.45 * math.sin(a * wave_n) if wave_n > 0 else 0.0)
        rings.append([
            bm.verts.new((
                ca * (r_maj + math.cos(j * math.tau / min_s) * mn),
                sa * (r_maj + math.cos(j * math.tau / min_s) * mn),
                z_off + math.sin(j * math.tau / min_s) * mn,
            ))
            for j in range(min_s)
        ])
    for i in range(maj_s):
        ni = (i + 1) % maj_s
        for j in range(min_s):
            nj = (j + 1) % min_s
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][nj], rings[i][nj]))
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, scale=scale, smooth=True)


def bm_flat_ring(parent, name: str, r_out: float, r_in: float, h: float, mat, segs=48, notches=0, notch_d=0.0, loc=(0, 0, 0), rot=(0, 0, 0), smooth=False):
    bm = bmesh.new()
    hh = h * 0.5
    to, ti, bo, bi = [], [], [], []
    for i in range(segs):
        u = i / segs
        a = u * math.tau
        ca, sa = math.cos(a), math.sin(a)
        lug = notch_d if (notches > 0 and math.cos(u * notches * math.tau) > 0.62) else 0.0
        ro = r_out + lug
        to.append(bm.verts.new((ca * ro, sa * ro, hh)))
        ti.append(bm.verts.new((ca * r_in, sa * r_in, hh)))
        bo.append(bm.verts.new((ca * ro, sa * ro, -hh)))
        bi.append(bm.verts.new((ca * r_in, sa * r_in, -hh)))
    for i in range(segs):
        ni = (i + 1) % segs
        bm.faces.new((ti[i], to[i], to[ni], ti[ni]))
        bm.faces.new((bo[i], bi[i], bi[ni], bo[ni]))
        bm.faces.new((bo[i], to[i], to[ni], bo[ni]))
        bm.faces.new((ti[i], bi[i], bi[ni], ti[ni]))
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def bm_faceted_gem(parent, name: str, rad: float, h: float, mat, sides=8, tip_r=0.35, bot_r=0.35, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    v_bot = bm.verts.new((0, 0, -h * 0.5))
    v_top = bm.verts.new((0, 0, h * 0.5))
    z_low = -h * (0.5 - bot_r)
    z_hi = h * (0.5 - tip_r)
    r_low, r_hi = [], []
    for i in range(sides):
        a = (i / sides) * math.tau
        a2 = a + math.pi / sides
        r_low.append(bm.verts.new((math.cos(a) * rad * 0.88, math.sin(a) * rad * 0.88, z_low)))
        r_hi.append(bm.verts.new((math.cos(a2) * rad, math.sin(a2) * rad, z_hi)))
    for i in range(sides):
        ni = (i + 1) % sides
        bm.faces.new((v_bot, r_low[ni], r_low[i]))
        bm.faces.new((r_low[i], r_low[ni], r_hi[i]))
        bm.faces.new((r_low[ni], r_hi[ni], r_hi[i]))
        bm.faces.new((r_hi[i], r_hi[ni], v_top))
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=False)


def bm_star_3d(parent, name: str, points: int, r_out: float, r_in: float, thickness: float, mat, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Build a razor-sharp faceted 3D celestial star prism facing along Y (-Y front / +Y back)."""
    bm = bmesh.new()
    v_front = bm.verts.new((0.0, -thickness * 0.5, 0.0))
    v_back = bm.verts.new((0.0, thickness * 0.5, 0.0))
    ring = []
    n = points * 2
    for i in range(n):
        a = (i / n) * math.tau + math.pi * 0.5  # Top point straight up (+Z)
        r = r_out if (i % 2 == 0) else r_in
        ring.append(bm.verts.new((math.cos(a) * r, 0.0, math.sin(a) * r)))
    for i in range(n):
        ni = (i + 1) % n
        bm.faces.new((v_front, ring[i], ring[ni]))
        bm.faces.new((v_back, ring[ni], ring[i]))
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=False)


def bm_stadium_link(parent, name: str, length: float, width: float, wire_r: float, mat, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Build an authentic forged stadium-shaped oval iron chain link in the XZ plane."""
    bm = bmesh.new()
    segs = 20
    sec_s = 8
    straight = max(0.001, (length - width) * 0.5)
    rx = width * 0.5
    pts = []
    for i in range(segs):
        a = (i / segs) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        x = ca * rx
        z = sa * rx + (straight if sa >= 0 else -straight)
        pts.append(Vector((x, 0.0, z)))
    rings = []
    for i in range(segs):
        p = pts[i]
        tang = (pts[(i + 1) % segs] - pts[(i - 1) % segs]).normalized()
        side = Vector((0.0, 1.0, 0.0))
        nrm = tang.cross(side).normalized()
        ring = []
        for j in range(sec_s):
            ja = (j / sec_s) * math.tau
            ring.append(bm.verts.new(p + (nrm * math.cos(ja) + side * math.sin(ja)) * wire_r))
        rings.append(ring)
    for i in range(segs):
        ni = (i + 1) % segs
        for j in range(sec_s):
            nj = (j + 1) % sec_s
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][nj], rings[i][nj]))
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


def bm_flame_plume(parent, name: str, rad: float, h: float, mat, twist=1.8, lean_x=0.012, lean_y=-0.006, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    levels, sides = 12, 10
    rings = []
    for li in range(levels):
        u = li / levels
        z = u * h
        swell = math.sin(min(1.0, u * 1.25) * math.pi * 0.88)
        r = max(0.0008, rad * (0.45 + 0.72 * swell) * (1.0 - 0.86 * (u ** 1.35)))
        cx = math.sin(u * math.pi * 1.25) * lean_x
        cy = math.sin(u * math.pi * 0.95) * lean_y
        ang_off = u * twist
        ring = []
        for si in range(sides):
            a = (si / sides) * math.tau + ang_off
            flute = 1.0 + 0.25 * math.sin(a * 3.0)
            ring.append(bm.verts.new((cx + math.cos(a) * r * flute, cy + math.sin(a) * r * flute, z)))
        rings.append(ring)
    v_tip = bm.verts.new((lean_x * 0.85, lean_y * 0.85, h))
    for li in range(levels - 1):
        for si in range(sides):
            sn = (si + 1) % sides
            bm.faces.new((rings[li][si], rings[li][sn], rings[li + 1][sn], rings[li + 1][si]))
    for si in range(sides):
        sn = (si + 1) % sides
        bm.faces.new((rings[-1][si], rings[-1][sn], v_tip))
    bm.faces.new(rings[0][::-1])
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


def ground_and_report(root, label: str):
    """Snap relic cleanly so its lowest world vertex rests at Z = 0.0 and print exact bounding dimensions."""
    bpy.context.view_layer.update()
    xs, ys, zs = [], [], []
    for ch in root.children_recursive:
        if ch.type == "MESH" and ch.data:
            mw = ch.matrix_world
            for v in ch.data.vertices:
                co = mw @ v.co
                xs.append(co.x)
                ys.append(co.y)
                zs.append(co.z)
    if not zs:
        return
    min_z = min(zs)
    if abs(min_z) > 1e-5:
        for ch in root.children:
            ch.location.z -= min_z
        bpy.context.view_layer.update()
    w = max(xs) - min(xs)
    d = max(ys) - min(ys)
    h = max(zs) - min(zs)
    print(f"  [BBOX] {label}: W={w:.3f}m D={d:.3f}m H={h:.3f}m (shifted Z by {-min_z:+.4f}m)")


def export_glb(root, filepath: pathlib.Path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    filepath.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(filepath),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_materials="EXPORT",
    )


# =============================================================================
# 1. TRELIC_SOUL_BELL — Soul-Severing Bell
#    Engraved antique bronze gothic hand-bell, turned ebony handle, rune-etched
#    flaring skirt, ornate clapper, and glowing electric-cyan reiatsu sound-ring.
# =============================================================================

def build_trelic_soul_bell(M):
    root = bpy.data.objects.new("TRELIC_SOUL_BELL", None)
    bpy.context.scene.collection.objects.link(root)

    # Low sculpted obsidian & brass acoustic plinth cradle so clapper & glowing sound-ring gleam cleanly
    bm_lathe(root, "AcousticBase", [
        (0.056, 0.0), (0.058, 0.005), (0.052, 0.010), (0.046, 0.011),
        (0.044, 0.006), (0.036, 0.006), (0.001, 0.005)
    ], M["obsidian"], segs=32)
    bm_torus(root, "BaseBrassInlay", 0.052, 0.0024, M["cathedral_brass"], maj_s=36, min_s=10, loc=(0, 0, 0.010))
    for k in range(4):
        a = k * math.tau / 4.0 + math.pi * 0.25
        bm_sphere(root, f"ClawFoot_{k}", 0.0055, M["antique_bronze"], scale=(1.2, 0.85, 0.75),
                  loc=(math.cos(a) * 0.055, math.sin(a) * 0.055, 0.0042), rot=(0, 0, math.degrees(a)))

    # Main bell assembly hovering slightly inside the plinth cradle at subtle heroic 5° tilt
    bell_z = 0.017
    bell_prof = [
        # Outer flaring gothic skirt -> waist -> domed crown
        (0.043, 0.000), (0.046, 0.004), (0.041, 0.012), (0.033, 0.025),
        (0.028, 0.042), (0.026, 0.058), (0.024, 0.072), (0.017, 0.082),
        (0.011, 0.086),
        # Inner cavity wall looping back down to bottom rim!
        (0.011, 0.078), (0.021, 0.068), (0.024, 0.044), (0.034, 0.016),
        (0.040, 0.003), (0.043, 0.000),
    ]
    bm_lathe(root, "BellSkirtBody", bell_prof, M["antique_bronze"], segs=40, loc=(0, 0, bell_z), cap_bot=False, cap_top=False)

    # Raised bronze decorative moldings & gothic sound-bow ribs around skirt
    bm_torus(root, "BellRimBead", 0.0445, 0.0026, M["gilded_gold"], maj_s=40, min_s=10, loc=(0, 0, bell_z + 0.004))
    bm_torus(root, "BellWaistBead", 0.0285, 0.0022, M["gilded_gold"], maj_s=36, min_s=10, loc=(0, 0, bell_z + 0.042))
    bm_torus(root, "BellCrownCollar", 0.0245, 0.0024, M["gilded_gold"], maj_s=32, min_s=10, loc=(0, 0, bell_z + 0.072))

    # 8 Gothic vertical relief ribs + glowing cyan engraved runes etched around the flaring skirt
    for k in range(8):
        a = (k / 8.0) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        rib_pts = [
            (ca * 0.044, sa * 0.044, bell_z + 0.005),
            (ca * 0.034, sa * 0.034, bell_z + 0.024),
            (ca * 0.028, sa * 0.028, bell_z + 0.048),
            (ca * 0.024, sa * 0.024, bell_z + 0.072),
        ]
        bm_tube(root, f"BellRib_{k}", rib_pts, [0.0022, 0.0020, 0.0018, 0.0016], M["dark_bronze"], segs=8)
        # Rune glyph diamond etched between ribs
        ra = a + math.tau / 16.0
        rca, rsa = math.cos(ra), math.sin(ra)
        bm_faceted_gem(root, f"BellRune_{k}", rad=0.0036, h=0.011, mat=M["reiatsu_cyan"], sides=4,
                       loc=(rca * 0.0345, rsa * 0.0345, bell_z + 0.026), rot=(math.degrees(-rsa * 0.35), math.degrees(rca * 0.35), math.degrees(ra)))

    # Ornate bronze clapper peeking out below bell skirt
    bm_cyl(root, "ClapperRod", 0.0022, 0.0028, 0.072, M["dark_bronze"], segs=10, loc=(0, 0, bell_z + 0.036))
    bm_sphere(root, "ClapperBall", 0.0085, M["gilded_gold"], scale=(1.0, 1.0, 1.15), loc=(0, 0, bell_z - 0.002), sub=3)
    bm_torus(root, "ClapperRing", 0.0086, 0.0016, M["antique_bronze"], maj_s=20, min_s=8, loc=(0, 0, bell_z - 0.002))

    # Turned ebony baluster handle with brass ferrules & gothic finial spire (kept compact H ~0.174m!)
    handle_z = bell_z + 0.082
    bm_lathe(root, "BronzeNeckCollar", [
        (0.014, 0.0), (0.016, 0.004), (0.009, 0.009), (0.011, 0.013)
    ], M["cathedral_brass"], segs=24, loc=(0, 0, handle_z))
    bm_lathe(root, "EbonyHandle", [
        (0.009, 0.011), (0.011, 0.016), (0.0078, 0.025), (0.0115, 0.036),
        (0.0125, 0.045), (0.0095, 0.053), (0.007, 0.057)
    ], M["ebony"], segs=28, loc=(0, 0, handle_z))
    bm_torus(root, "HandleMidFerrule", 0.0102, 0.0018, M["gilded_gold"], maj_s=24, min_s=8, loc=(0, 0, handle_z + 0.028))
    bm_lathe(root, "HandleFinial", [
        (0.0085, 0.056), (0.011, 0.060), (0.006, 0.065), (0.009, 0.070), (0.001, 0.077)
    ], M["gilded_gold"], segs=20, loc=(0, 0, handle_z))

    # Glowing electric-cyan reiatsu sound-ring + secondary acoustic shock ripple at rim!
    bm_torus(root, "ReiatsuSoundRingMain", 0.056, 0.0030, M["reiatsu_cyan"], maj_s=48, min_s=10,
             loc=(0, 0, bell_z + 0.003), wave_n=8, wave_amp=0.0032)
    bm_torus(root, "ReiatsuSoundRingOuter", 0.068, 0.0016, M["reiatsu_cyan"], maj_s=56, min_s=8,
             loc=(0, 0, bell_z + 0.008), rot=(5, -4, 0), wave_n=12, wave_amp=0.0022)

    ground_and_report(root, "TRELIC_SOUL_BELL")
    return root


# =============================================================================
# 2. TRELIC_BLOOD_SEAL — Blood-Ink Seal
#    Carved obsidian pedestal holding a gilded medieval wax-seal stamp with
#    glowing ruby-crimson blood crystal & sculpted wax-drip crest around base.
# =============================================================================

def build_trelic_blood_seal(M):
    root = bpy.data.objects.new("TRELIC_BLOOD_SEAL", None)
    bpy.context.scene.collection.objects.link(root)

    # Carved octagonal stepped obsidian pedestal with concave gothic cove
    bm_lathe(root, "ObsidianPedestal", [
        (0.062, 0.000), (0.064, 0.008), (0.056, 0.014), (0.050, 0.022),
        (0.048, 0.036), (0.055, 0.044), (0.053, 0.048), (0.001, 0.048)
    ], M["obsidian"], segs=8, smooth=False)
    # Gilded corner fillet brackets around the octagonal plinth
    for k in range(8):
        a = (k / 8.0) * math.tau + math.pi / 8.0
        ca, sa = math.cos(a), math.sin(a)
        bm_bevel_box(root, f"PlinthTrim_{k}", (0.006, 0.006, 0.032), M["gilded_gold"], bevel=0.0012,
                     loc=(ca * 0.050, sa * 0.050, 0.024), rot=(0, 0, math.degrees(a)))
    bm_flat_ring(root, "PedestalRimGold", 0.057, 0.050, 0.004, M["gilded_gold"], segs=8, loc=(0, 0, 0.047))

    # Sculpted crimson wax-drip crest pooling atop pedestal & cascading organically down front (-Y)
    bm_wax = bmesh.new()
    bmesh.ops.create_uvsphere(bm_wax, u_segments=32, v_segments=16, radius=0.045)
    for v in bm_wax.verts:
        ang = math.atan2(v.co.y, v.co.x)
        r = math.hypot(v.co.x, v.co.y)
        lobe = 1.0 + 0.16 * math.sin(ang * 5.0 + 0.4) + 0.09 * math.cos(ang * 8.0)
        v.co.x *= lobe
        v.co.y *= lobe
        if v.co.z > 0:
            # Raised lip rim like freshly pressed wax seal
            rim_swell = 0.0055 * math.exp(-((r - 0.034) ** 2) / 0.00009)
            v.co.z = v.co.z * 0.18 + rim_swell
        else:
            v.co.z *= 0.06
    link_part(root, "WaxSealPool", bm_wax, M["wax_crimson"], loc=(0, 0, 0.050), smooth=True)

    # 5 Organic wax drip rivulets cascading down the pedestal front & sides
    drip_angles = [-95, -72, -118, -42, -142]
    drip_lens = [0.036, 0.028, 0.031, 0.022, 0.024]
    for idx, (deg, dlen) in enumerate(zip(drip_angles, drip_lens)):
        a = math.radians(deg)
        ca, sa = math.cos(a), math.sin(a)
        pts = [
            (ca * 0.046, sa * 0.046, 0.050),
            (ca * 0.055, sa * 0.055, 0.046),
            (ca * 0.054, sa * 0.054, 0.046 - dlen * 0.55),
            (ca * 0.056, sa * 0.056, 0.046 - dlen),
        ]
        bm_tube(root, f"WaxDrip_{idx}", pts, [0.0042, 0.0038, 0.0028, 0.0048], M["wax_crimson"], segs=10)

    # Front heraldic wax-crest medallion stamped on pedestal front face (-Y)
    bm_torus(root, "FrontCrestWaxRim", 0.015, 0.0032, M["wax_crimson"], maj_s=24, min_s=8,
             loc=(0, -0.051, 0.026), rot=(90, 0, 0))
    bm_faceted_gem(root, "FrontCrestRuby", rad=0.0075, h=0.007, mat=M["ruby_glow"], sides=6,
                   loc=(0, -0.052, 0.026), rot=(90, 0, 0))

    # Gilded medieval wax-seal stamp standing heroically in the wax pool (slight regal 6° tilt)
    stamp_piv = bpy.data.objects.new("StampPivot", None)
    stamp_piv.location = (0.0, 0.0, 0.051)
    stamp_piv.rotation_euler = Euler((math.radians(-6), math.radians(4), 0), "XYZ")
    stamp_piv.parent = root
    bpy.context.scene.collection.objects.link(stamp_piv)

    # Ornate flared gilded stamp die + baroque waisted handle
    bm_lathe(stamp_piv, "StampBodyGold", [
        (0.028, 0.000), (0.030, 0.005), (0.025, 0.011), (0.015, 0.022),
        (0.011, 0.034), (0.015, 0.042), (0.010, 0.050), (0.013, 0.062),
        (0.020, 0.072), (0.016, 0.078), (0.012, 0.078)
    ], M["gilded_gold"], segs=32, flute_n=8, flute_amp=0.05)
    bm_torus(stamp_piv, "StampCollarMid", 0.0155, 0.0025, M["cathedral_brass"], maj_s=24, min_s=8, loc=(0, 0, 0.042))

    # 4 Baroque gilded crown prongs embracing the glowing ruby-crimson blood crystal!
    for k in range(4):
        a = (k / 4.0) * math.tau + math.pi * 0.25
        ca, sa = math.cos(a), math.sin(a)
        prong_pts = [
            (ca * 0.018, sa * 0.018, 0.072),
            (ca * 0.023, sa * 0.023, 0.088),
            (ca * 0.016, sa * 0.016, 0.104),
            (ca * 0.008, sa * 0.008, 0.112),
        ]
        bm_tube(stamp_piv, f"CrownProng_{k}", prong_pts, [0.0032, 0.0028, 0.0022, 0.0012], M["gilded_gold"], segs=8)

    # Large faceted glowing ruby-crimson blood crystal apex!
    bm_faceted_gem(stamp_piv, "BloodRubyCrystal", rad=0.0185, h=0.048, mat=M["ruby_glow"], sides=8,
                   tip_r=0.42, bot_r=0.35, loc=(0, 0, 0.094))
    # Tiny glowing blood-crystal shards flanking the stamp base
    for k in range(6):
        a = (k / 6.0) * math.tau + 0.3
        bm_faceted_gem(root, f"BloodDropGem_{k}", rad=0.0042, h=0.010, mat=M["ruby_glow"], sides=6,
                       loc=(math.cos(a) * 0.036, math.sin(a) * 0.036, 0.056), rot=(15 * math.sin(a), -15 * math.cos(a), 0))

    ground_and_report(root, "TRELIC_BLOOD_SEAL")
    return root


# =============================================================================
# 3. TRELIC_STAR_BOW — Quincy Astrolabe
#    Nested brushed-gold & silver celestial armillary rings on turned stand
#    with razor-sharp glowing electric-cyan 5-pointed Quincy star core.
# =============================================================================

def build_trelic_star_bow(M):
    root = bpy.data.objects.new("TRELIC_STAR_BOW", None)
    bpy.context.scene.collection.objects.link(root)

    # Turned brushed-gold & sterling silver stepped pedestal stand
    bm_lathe(root, "AstrolabeFoot", [
        (0.048, 0.000), (0.050, 0.005), (0.044, 0.011), (0.032, 0.016),
        (0.020, 0.022), (0.011, 0.030), (0.009, 0.044), (0.014, 0.050),
        (0.008, 0.056)
    ], M["brushed_gold"], segs=32)
    bm_torus(root, "FootSilverRing", 0.045, 0.0022, M["sterling_silver"], maj_s=32, min_s=8, loc=(0, 0, 0.010))
    bm_torus(root, "StemSilverCollar", 0.013, 0.0024, M["sterling_silver"], maj_s=24, min_s=8, loc=(0, 0, 0.049))

    # Twin curved silver meridian cradle arms rising from stem to embrace outer armillary ring
    center_z = 0.112
    for sx in (-1.0, 1.0):
        arm_pts = []
        for i in range(12):
            t = i / 11.0
            ang = math.radians(-90.0 + t * 92.0)  # Bottom (-90 deg) sweeping to equator (0 deg)
            r_arm = 0.0615
            x = sx * math.cos(ang) * r_arm * (0.18 + 0.82 * math.sin(t * math.pi * 0.5))
            z = center_z + math.sin(ang) * r_arm
            arm_pts.append((x, 0.0, z))
        bm_tube(root, f"CradleArm_{int(sx)}", arm_pts, [0.0038 - 0.0010 * (i / 11.0) for i in range(12)], M["sterling_silver"], segs=10)
        # Pivot trunnion knob holding outer ring
        bm_sphere(root, f"TrunnionKnob_{int(sx)}", 0.0052, M["gilded_gold"], loc=(sx * 0.060, 0.0, center_z), sub=2)

    # Nested Celestial Armillary Rings centered at (0, 0, 0.112)
    # Ring 1: Outer Meridian Ring (Brushed Gold, vertical XZ plane facing -Y) with 12 compass lugs
    bm_flat_ring(root, "ArmillaryOuterGold", 0.058, 0.051, 0.0065, M["brushed_gold"], segs=56,
                 notches=12, notch_d=0.0038, loc=(0, 0, center_z), rot=(90, 0, 0))
    # Top spire finial atop outer meridian ring
    bm_lathe(root, "AstrolabeCrownFinial", [
        (0.0055, 0.0), (0.007, 0.004), (0.003, 0.010), (0.001, 0.017)
    ], M["gilded_gold"], segs=16, loc=(0, 0, center_z + 0.057))

    # Ring 2: Tilted Celestial Ecliptic Band (Sterling Silver, wide engraved band)
    bm_flat_ring(root, "ArmillaryEclipticSilver", 0.049, 0.042, 0.0075, M["sterling_silver"], segs=48,
                 notches=8, notch_d=0.0024, loc=(0, 0, center_z), rot=(58, 22, 16))

    # Ring 3: Counter-tilted Equatorial Ring (Brushed Gold)
    bm_flat_ring(root, "ArmillaryEquatorGold", 0.041, 0.036, 0.0052, M["gilded_gold"], segs=48,
                 notches=6, notch_d=0.0020, loc=(0, 0, center_z), rot=(-46, -34, -20))

    # Ring 4: Fine Inner Celestial Gimbal (Sterling Silver)
    bm_torus(root, "ArmillaryInnerSilver", 0.032, 0.0020, M["sterling_silver"], maj_s=40, min_s=10,
             loc=(0, 0, center_z), rot=(74, -18, 12))

    # Glowing electric-cyan Quincy halo thread + Razor-sharp 5-pointed Quincy Star floating at exact center!
    bm_torus(root, "QuincyEnergyHalo", 0.0265, 0.0014, M["reiatsu_cyan"], maj_s=40, min_s=8,
             loc=(0, 0, center_z), rot=(90, 0, 0))
    bm_star_3d(root, "QuincyStarCore", points=5, r_out=0.026, r_in=0.0085, thickness=0.010,
               mat=M["reiatsu_cyan"], loc=(0, 0, center_z), rot=(0, 0, 0))
    # Secondary orthogonal star cross-plane so the star reads razor-sharp from 3/4 & side angles too!
    bm_star_3d(root, "QuincyStarCross", points=5, r_out=0.022, r_in=0.007, thickness=0.006,
               mat=M["reiatsu_cyan"], loc=(0, 0, center_z), rot=(0, 0, 90))
    # Tiny glowing star-pin satellites on outer meridian
    for k in range(5):
        a = (k / 5.0) * math.tau + math.pi * 0.5
        bm_sphere(root, f"StarPin_{k}", 0.0028, M["reiatsu_cyan"],
                  loc=(math.cos(a) * 0.0545, -0.0038, center_z + math.sin(a) * 0.0545), sub=2)

    ground_and_report(root, "TRELIC_STAR_BOW")
    return root


# =============================================================================
# 4. TRELIC_ASH_GLASS — Ashen Hourglass
#    Dark wrought-iron gothic twin-pillar hourglass with curved blown-glass
#    bulbs, glowing violet-amber hourglass sand, and hovering ember ash core.
# =============================================================================

def build_trelic_ash_glass(M):
    root = bpy.data.objects.new("TRELIC_ASH_GLASS", None)
    bpy.context.scene.collection.objects.link(root)

    # Heavy dark wrought-iron hexagonal gothic bottom & top end-plates
    bm_lathe(root, "HourglassBottomPlate", [
        (0.052, 0.000), (0.054, 0.006), (0.048, 0.012), (0.042, 0.015), (0.001, 0.015)
    ], M["wrought_iron"], segs=6, smooth=False)
    bm_torus(root, "BottomBrassRim", 0.044, 0.0022, M["dark_bronze"], maj_s=36, min_s=8, loc=(0, 0, 0.015))

    top_z = 0.146
    bm_lathe(root, "HourglassTopPlate", [
        (0.001, top_z), (0.042, top_z), (0.048, top_z + 0.003),
        (0.054, top_z + 0.009), (0.052, top_z + 0.014), (0.022, top_z + 0.018),
        (0.008, top_z + 0.024), (0.001, top_z + 0.032)
    ], M["wrought_iron"], segs=6, smooth=False)
    bm_torus(root, "TopBrassRim", 0.044, 0.0022, M["dark_bronze"], maj_s=36, min_s=8, loc=(0, 0, top_z))

    # Twin primary fluted gothic wrought-iron pillars (left & right on X) + twin curved back/front buttress scrolls
    for sx in (-1.0, 1.0):
        px = sx * 0.044
        bm_lathe(root, f"GothicPillar_{int(sx)}", [
            (0.0085, 0.012), (0.0060, 0.020), (0.0046, 0.042), (0.0068, 0.078),
            (0.0046, 0.114), (0.0060, 0.138), (0.0085, top_z + 0.002)
        ], M["wrought_iron"], segs=12, loc=(px, 0.0, 0.0), flute_n=6, flute_amp=0.10)
        # Gothic S-scroll filigree wing outside each primary pillar!
        s_pts = [
            (sx * 0.046, 0.0, 0.016),
            (sx * 0.060, 0.0, 0.036),
            (sx * 0.052, 0.0, 0.078),
            (sx * 0.060, 0.0, 0.122),
            (sx * 0.046, 0.0, top_z - 0.002),
        ]
        bm_tube(root, f"PillarScroll_{int(sx)}", s_pts, [0.0028, 0.0024, 0.0022, 0.0024, 0.0028], M["dark_iron"], segs=8)
        # Pillar cap finials above top plate
        bm_lathe(root, f"PillarFinial_{int(sx)}", [
            (0.0055, top_z + 0.012), (0.0065, top_z + 0.017), (0.001, top_z + 0.025)
        ], M["cathedral_brass"], segs=10, loc=(px, 0.0, 0.0))

    # Rear slender iron support rod so frame feels architecturally sound without obstructing front view (-Y)
    bm_cyl(root, "RearSupportRod", 0.0032, 0.0032, top_z - 0.012, M["dark_iron"], segs=10, loc=(0.0, 0.042, (top_z + 0.012) * 0.5))

    # Curved blown-glass double bulbs (lathed with waist pinch at Z=0.080)
    waist_z = 0.080
    glass_prof = [
        (0.032, 0.016), (0.037, 0.026), (0.036, 0.042), (0.028, 0.058),
        (0.014, 0.071), (0.0075, waist_z), (0.014, 0.089), (0.028, 0.102),
        (0.036, 0.118), (0.037, 0.134), (0.032, 0.145),
    ]
    bm_lathe(root, "BlownGlassBulbs", glass_prof, M["blown_glass"], segs=36, cap_bot=True, cap_top=True)
    # Delicate iron gothic waist collar clasping the hourglass pinch
    bm_torus(root, "WaistIronCollar", 0.010, 0.0020, M["cathedral_brass"], maj_s=24, min_s=8, loc=(0, 0, waist_z))

    # Glowing violet-amber hourglass sand inside bulbs (layered deep violet + molten amber rim!)
    # Lower conical sand pile
    bm_lathe(root, "LowerAshSand", [
        (0.029, 0.017), (0.031, 0.023), (0.024, 0.034), (0.013, 0.044), (0.001, 0.050)
    ], M["ash_sand"], segs=28)
    bm_torus(root, "LowerAmberSandRing", 0.026, 0.0036, M["ash_amber"], maj_s=28, min_s=8, loc=(0, 0, 0.024))
    # Upper draining violet-amber sand funnel
    bm_lathe(root, "UpperAshSand", [
        (0.0025, 0.084), (0.012, 0.095), (0.025, 0.108), (0.030, 0.118), (0.020, 0.115), (0.002, 0.106)
    ], M["ash_amber"], segs=28)
    bm_torus(root, "UpperVioletSandRim", 0.027, 0.0034, M["ash_sand"], maj_s=28, min_s=8, loc=(0, 0, 0.115))
    # Thin glowing falling sand stream
    bm_cyl(root, "FallingSandStream", 0.0018, 0.0024, 0.042, M["ash_ember"], segs=10, loc=(0, 0, 0.068))

    # Hovering glowing ember-ash core suspended in the waist/lower chamber + tiny floating ash motes!
    bm_faceted_gem(root, "HoveringEmberCore", rad=0.0115, h=0.024, mat=M["ash_ember"], sides=6,
                   loc=(0.0, 0.0, 0.060))
    for k in range(6):
        a = (k / 6.0) * math.tau + 0.4
        r_m = 0.018 + (k % 2) * 0.005
        z_m = 0.048 + (k % 3) * 0.016
        bm_sphere(root, f"AshMote_{k}", 0.0024, M["ash_ember"] if k % 2 == 0 else M["ash_sand"],
                  loc=(math.cos(a) * r_m, math.sin(a) * r_m, z_m), sub=1)

    ground_and_report(root, "TRELIC_ASH_GLASS")
    return root


# =============================================================================
# 5. TRELIC_WAR_HORN — Templar War-Horn
#    Curved organic hunting/battle horn wrapped in riveted hammered-steel bands
#    and gilded cross engravings resting on a dark iron cradle.
# =============================================================================

def build_trelic_war_horn(M):
    root = bpy.data.objects.new("TRELIC_WAR_HORN", None)
    bpy.context.scene.collection.objects.link(root)

    # Dark wrought-iron gothic cradle base resting flush on Z = 0.0
    bm_bevel_box(root, "CradleSpineBar", (0.102, 0.020, 0.009), M["wrought_iron"], bevel=0.002, loc=(0.0, 0.0, 0.0045))
    for sx in (-0.044, 0.044):
        # Crossed scroll feet
        bm_bevel_box(root, f"CradleFoot_{sx}", (0.014, 0.056, 0.009), M["wrought_iron"], bevel=0.002, loc=(sx, 0.0, 0.0045))
        # U-shaped forged cradle forks holding the horn aloft
        fork_z = 0.036 if sx < 0 else 0.048
        fork_w = 0.026 if sx < 0 else 0.019
        u_pts = [
            (sx, -fork_w, fork_z + 0.016),
            (sx, -fork_w * 0.72, fork_z - 0.004),
            (sx, 0.0, fork_z - 0.012),
            (sx, fork_w * 0.72, fork_z - 0.004),
            (sx, fork_w, fork_z + 0.016),
        ]
        bm_tube(root, f"CradleFork_{sx}", u_pts, [0.0032] * 5, M["wrought_iron"], segs=8)
        bm_cyl(root, f"CradlePost_{sx}", 0.0045, 0.0040, fork_z - 0.014, M["dark_iron"], segs=10,
               loc=(sx, 0.0, (fork_z - 0.014) * 0.5 + 0.006))

    # Sweeping curved organic battle horn curve (wide bell on left-front, tapering upward to right mouthpiece!)
    n_pts = 28
    pts, rads = [], []
    for i in range(n_pts):
        t = i / (n_pts - 1)
        x = -0.058 + t * 0.118 + math.sin(t * math.pi) * 0.008
        y = -0.014 * (1.0 - t) + math.sin(t * math.pi) * 0.024
        z = 0.044 + (t ** 1.45) * 0.068 - math.sin(t * math.pi) * 0.012
        pts.append((x, y, z))
        rads.append(0.029 * ((1.0 - t) ** 0.78) + 0.0055)
    bm_tube(root, "BattleHornBody", pts, rads, M["horn_dark"], segs=22, rib_amp=0.035, rib_freq=2.6)

    # Helper to compute local orientation matrix along horn spine
    def horn_frame(idx):
        p = Vector(pts[idx])
        if idx == 0:
            tang = (Vector(pts[1]) - p).normalized()
        elif idx == n_pts - 1:
            tang = (p - Vector(pts[-2])).normalized()
        else:
            tang = (Vector(pts[idx + 1]) - Vector(pts[idx - 1])).normalized()
        quat = tang.to_track_quat("Z", "Y")
        return p, quat.to_euler("XYZ"), tang

    # Flared hammered-steel bell rim with scalloped gilded inner lip at idx=0
    p0, rot0, t0 = horn_frame(0)
    rot0_deg = tuple(math.degrees(a) for a in rot0)
    bm_lathe(root, "HornSteelBell", [
        (0.031, -0.008), (0.035, -0.002), (0.033, 0.006), (0.029, 0.012),
        (0.025, 0.005), (0.028, -0.004), (0.031, -0.008)
    ], M["hammered_steel"], segs=28, loc=tuple(p0), rot=rot0_deg, cap_bot=False, cap_top=False)
    bm_torus(root, "BellGoldLip", 0.034, 0.0022, M["gilded_gold"], maj_s=28, min_s=8, loc=tuple(p0), rot=rot0_deg)

    # Turned gilded mouthpiece at idx = n_pts - 1
    p_end, rot_end, _ = horn_frame(n_pts - 1)
    rot_end_deg = tuple(math.degrees(a) for a in rot_end)
    bm_lathe(root, "GildedMouthpiece", [
        (0.0065, -0.004), (0.0085, 0.002), (0.0055, 0.010), (0.0095, 0.019), (0.0072, 0.020), (0.0045, 0.012)
    ], M["gilded_gold"], segs=20, loc=tuple(p_end), rot=rot_end_deg)

    # 3 Riveted Hammered-Steel Bands wrapping snugly around horn + 3D rivets + Gilded Templar Cross engravings!
    for bi, b_idx in enumerate([5, 12, 19]):
        pb, rotb, tb = horn_frame(b_idx)
        rotb_deg = tuple(math.degrees(a) for a in rotb)
        rb = rads[b_idx]
        bw = 0.014 if bi == 1 else 0.010
        bm_cyl(root, f"SteelBand_{bi}", rb + 0.0026, rb + 0.0022, bw, M["hammered_steel"], segs=24, loc=tuple(pb), rot=rotb_deg)
        # Gold edge wire collars on each band
        rot_m = rotb.to_matrix()
        for dz in (-bw * 0.45, bw * 0.45):
            bm_torus(root, f"BandGoldTrim_{bi}_{dz:+.3f}", rb + 0.0028, 0.0012, M["gilded_gold"],
                     maj_s=24, min_s=6, loc=tuple(pb + rot_m @ Vector((0, 0, dz))), rot=rotb_deg)
        # 8 Rivet studs around band
        for rv in range(8):
            ra = (rv / 8.0) * math.tau
            rloc = pb + rot_m @ Vector((math.cos(ra) * (rb + 0.0032), math.sin(ra) * (rb + 0.0032), 0.0))
            bm_sphere(root, f"Rivet_{bi}_{rv}", 0.0018, M["sterling_silver"], loc=tuple(rloc), sub=1)

    # Sculpted raised Gilded Templar Cross Pattée on the central steel band facing front (-Y)!
    p_mid, rot_mid, _ = horn_frame(11)
    rm_m = rot_mid.to_matrix()
    # Find direction closest to -Y perpendicular to horn tangent
    front_dir = Vector((0.0, -1.0, 0.15))
    front_dir = (front_dir - rm_m @ Vector((0, 0, 1)) * front_dir.dot(rm_m @ Vector((0, 0, 1)))).normalized()
    cross_center = p_mid + front_dir * (rads[11] + 0.0040)
    cross_quat = (-front_dir).to_track_quat("-Y", "Z")
    cross_piv = bpy.data.objects.new("TemplarCrossPivot", None)
    cross_piv.location = cross_center
    cross_piv.rotation_euler = cross_quat.to_euler("XYZ")
    cross_piv.parent = root
    bpy.context.scene.collection.objects.link(cross_piv)
    for arm_ang in (0, 90, 180, 270):
        # Flared Templar cross pattée trapezoid arm
        bm_a = bmesh.new()
        w0, w1, l1, th = 0.0022, 0.0052, 0.0115, 0.0022
        pts_c = [(-w0, -th, 0), (w0, -th, 0), (w1, -th, l1), (-w1, -th, l1)]
        f_v = [bm_a.verts.new(v) for v in pts_c]
        b_v = [bm_a.verts.new((v[0], th, v[2])) for v in pts_c]
        bm_a.faces.new(f_v)
        bm_a.faces.new(b_v[::-1])
        for k in range(4):
            nk = (k + 1) % 4
            bm_a.faces.new((f_v[k], f_v[nk], b_v[nk], b_v[k]))
        link_part(cross_piv, f"TemplarArm_{arm_ang}", bm_a, M["gilded_gold"], rot=(0, arm_ang, 0), smooth=False)
    bm_sphere(cross_piv, "TemplarCenterBoss", 0.0032, M["ruby_glow"], scale=(1.0, 0.55, 1.0), loc=(0, -0.0018, 0), sub=2)

    ground_and_report(root, "TRELIC_WAR_HORN")
    return root


# =============================================================================
# 6. TRELIC_HOLLOW_MASK — Hollow Mask Fragment (Bleach TYBW Tribute)
#    Cracked bone-ivory theatrical half-mask with jagged crimson tribal stripes,
#    clenched stylized teeth edge, and intense golden slit-eye glow on obsidian
#    reliquary stand.
# =============================================================================

def build_trelic_hollow_mask(M):
    root = bpy.data.objects.new("TRELIC_HOLLOW_MASK", None)
    bpy.context.scene.collection.objects.link(root)

    # Carved angular obsidian reliquary monolith stand
    bm_lathe(root, "ReliquaryPlinth", [
        (0.056, 0.000), (0.058, 0.008), (0.048, 0.016), (0.044, 0.022), (0.001, 0.022)
    ], M["obsidian"], segs=6, smooth=False)
    bm_flat_ring(root, "ReliquaryTrimGold", 0.052, 0.046, 0.0035, M["gilded_gold"], segs=6, loc=(0, 0, 0.017))
    # Rear blackened-iron reliquary mast holding mask upright
    bm_cyl(root, "StandSpinePost", 0.0048, 0.0038, 0.095, M["dark_iron"], segs=12, loc=(0.0, 0.018, 0.068))
    bm_tube(root, "StandCradlePinLow", [(0.0, 0.018, 0.052), (0.0, 0.002, 0.058)], [0.0032, 0.0026], M["wrought_iron"], segs=8)
    bm_tube(root, "StandCradlePinHigh", [(0.0, 0.018, 0.112), (-0.006, -0.002, 0.116)], [0.0032, 0.0026], M["wrought_iron"], segs=8)

    # Mask container mounted heroically facing -Y (slight dramatic 7° yaw & 6° chin tilt)
    mask_piv = bpy.data.objects.new("HollowMaskPivot", None)
    mask_piv.location = (0.0, -0.006, 0.098)
    mask_piv.rotation_euler = Euler((math.radians(-6), math.radians(-4), math.radians(8)), "XYZ")
    mask_piv.parent = root
    bpy.context.scene.collection.objects.link(mask_piv)

    # Sculpted curved 3D Bone-Ivory Hollow Half-Mask Shell with SILKY-SMOOTH left oval contour
    # and sharp jagged diagonal fracture break on the right side!
    nu, nv = 24, 30

    def crack_limit(v_val):
        # Sharp asymmetric diagonal Hollow fracture break along +X edge
        jagged = 0.15 * math.sin(v_val * 10.5 + 0.5) + 0.08 * math.cos(v_val * 19.0)
        return 0.34 - 0.36 * v_val + jagged

    def mask_surface(u_val, v_val, thick_off=0.0):
        jaw_taper = 0.80 + 0.20 * (v_val + 1.0) * 0.5
        if v_val < -0.25:
            jaw_taper *= max(0.36, 1.0 - ((-0.25 - v_val) ** 1.38) * 0.72)
        x = u_val * 0.054 * jaw_taper
        z = v_val * 0.071
        r2 = min(1.32, (u_val * 0.92) ** 2 + (v_val * 0.78) ** 2)
        y = -0.036 * math.cos(min(1.42, r2 * 0.95)) + 0.012
        brow = -0.0058 * math.exp(-((v_val - 0.34) ** 2) / 0.035) * math.exp(-(u_val ** 2) / 0.65)
        nose = -0.0072 * math.exp(-((u_val) ** 2) / 0.035) * math.exp(-((v_val - 0.04) ** 2) / 0.12)
        cheek = -0.0054 * math.exp(-((u_val + 0.42) ** 2) / 0.08) * math.exp(-((v_val + 0.06) ** 2) / 0.06)
        eye_d = -0.0092 * math.exp(-(((u_val + 0.34) / 0.20) ** 2 + ((v_val - 0.16) / 0.11) ** 2))
        return Vector((x, y + brow + nose + cheek - eye_d + thick_off, z))

    bm_m = bmesh.new()
    front_grid = [[None] * (nu + 1) for _ in range(nv + 1)]
    back_grid = [[None] * (nu + 1) for _ in range(nv + 1)]

    # Parameterize every horizontal slice strictly from smooth left ellipse edge (-sqrt(1-v^2)) to jagged right crack!
    for iv in range(nv + 1):
        v_val = -0.96 + 1.92 * (iv / nv)
        u_oval = math.sqrt(max(0.02, 1.0 - (v_val * 0.99) ** 2))
        u_left = -u_oval
        u_right = max(u_left + 0.14, min(u_oval, crack_limit(v_val)))
        for iu in range(nu + 1):
            t_u = iu / nu
            u_val = u_left + t_u * (u_right - u_left)
            front_grid[iv][iu] = bm_m.verts.new(mask_surface(u_val, v_val, 0.0))
            back_grid[iv][iu] = bm_m.verts.new(mask_surface(u_val, v_val, 0.0072))

    for iv in range(nv):
        for iu in range(nu):
            bm_m.faces.new((front_grid[iv][iu], front_grid[iv][iu + 1], front_grid[iv + 1][iu + 1], front_grid[iv + 1][iu]))
            bm_m.faces.new((back_grid[iv][iu], back_grid[iv + 1][iu], back_grid[iv + 1][iu + 1], back_grid[iv][iu + 1]))

    # Cleanly close all 4 boundary perimeter edges (left smooth rim, right jagged crack, chin, crown)
    for iv in range(nv):
        bm_m.faces.new((front_grid[iv + 1][0], back_grid[iv + 1][0], back_grid[iv][0], front_grid[iv][0]))
        bm_m.faces.new((front_grid[iv][nu], back_grid[iv][nu], back_grid[iv + 1][nu], front_grid[iv + 1][nu]))
    for iu in range(nu):
        bm_m.faces.new((front_grid[0][iu], back_grid[0][iu], back_grid[0][iu + 1], front_grid[0][iu + 1]))
        bm_m.faces.new((front_grid[nv][iu + 1], back_grid[nv][iu + 1], back_grid[nv][iu], front_grid[nv][iu]))

    link_part(mask_piv, "HollowMaskBoneShell", bm_m, M["bone_ivory"], smooth=True)

    # Deep black sunken almond eye socket + RAZOR BLAZING GOLDEN SLIT EYE GLOW!
    eye_c = mask_surface(-0.34, 0.16, -0.0018)
    bm_sphere(mask_piv, "HollowEyeSocketDark", 0.0155, M["obsidian"], scale=(1.38, 0.34, 0.64),
              loc=tuple(eye_c + Vector((0, 0.0005, 0))), rot=(0, -14, 16), sub=3)
    bm_sphere(mask_piv, "HollowGoldenSlitEye", 0.0108, M["hollow_gold_eye"], scale=(1.32, 0.30, 0.24),
              loc=tuple(eye_c + Vector((0, -0.0024, 0))), rot=(0, -14, 16), sub=3)
    bm_faceted_gem(mask_piv, "HollowEyeIrisCore", rad=0.0038, h=0.007, mat=M["obsidian"], sides=4,
                   loc=tuple(eye_c + Vector((0, -0.0040, 0))), rot=(90, 0, 14))

    # Jagged Crimson Tribal Stripes sweeping dramatically across left brow, cheek, and temple (Bleach TYBW!)
    stripe_paths = [
        [(-0.74, 0.52), (-0.54, 0.44), (-0.30, 0.35), (-0.12, 0.48)],
        [(-0.80, 0.32), (-0.58, 0.27), (-0.42, 0.24)],
        [(-0.72, 0.02), (-0.50, -0.08), (-0.28, -0.18), (-0.08, -0.10)],
        [(-0.62, -0.22), (-0.40, -0.34), (-0.18, -0.44)],
        [(-0.38, 0.74), (-0.30, 0.56), (-0.20, 0.44)],
    ]
    for si, spath in enumerate(stripe_paths):
        s_pts = [tuple(mask_surface(u, v, -0.0022)) for (u, v) in spath]
        s_rads = [0.0022, 0.0038, 0.0032, 0.0016][:len(spath)]
        bm_tube(mask_piv, f"TribalCrimsonStripe_{si}", s_pts, s_rads, M["tribal_crimson"], segs=8, aspect_y=0.45)

    # Dark recessed mouth grin slit + 7 stylized clenched bone-ivory Hollow teeth along lower jaw!
    mouth_pts = [tuple(mask_surface(u, -0.46 - 0.10 * abs(u + 0.15), -0.0015)) for u in [-0.62, -0.42, -0.22, -0.02, 0.18, 0.34]]
    bm_tube(mask_piv, "MouthCavityRecess", mouth_pts, [0.004, 0.0068, 0.0076, 0.0078, 0.0070, 0.0045], M["bone_shadow"], segs=8, aspect_y=0.55)
    for ti in range(7):
        tu = -0.52 + ti * 0.135
        tv = -0.46 - 0.09 * abs(tu + 0.15)
        tp = mask_surface(tu, tv, -0.0046)
        # Upper & lower interlocked clenched teeth blocks with crisp bevel
        bm_bevel_box(mask_piv, f"HollowToothUpper_{ti}", (0.0064, 0.0055, 0.0072), M["bone_ivory"], bevel=0.0012,
                     loc=tuple(tp + Vector((0, 0, 0.0038))), rot=(0, 0, -tu * 22))
        bm_bevel_box(mask_piv, f"HollowToothLower_{ti}", (0.0060, 0.0052, 0.0068), M["bone_ivory"], bevel=0.0012,
                     loc=tuple(tp + Vector((0.0015, 0.0004, -0.0036))), rot=(0, 0, -tu * 22))

    # Detached floating jagged ivory fracture shard hovering beside the crack!
    bm_faceted_gem(mask_piv, "CrackedShard_A", rad=0.0085, h=0.022, mat=M["bone_ivory"], sides=3,
                   loc=(0.036, -0.008, 0.024), rot=(14, -26, 20))
    bm_faceted_gem(mask_piv, "CrackedShard_B", rad=0.0055, h=0.015, mat=M["bone_ivory"], sides=3,
                   loc=(0.044, -0.002, -0.012), rot=(-12, 32, -14))

    ground_and_report(root, "TRELIC_HOLLOW_MASK")
    return root


# =============================================================================
# 7. TRELIC_CENSER — Alchemist's Censer
#    Pierced gothic cathedral brass incense thurible with scalloped dome,
#    triple hanging support chains on brass stand, and glowing emerald-violet
#    arcane mist core inside.
# =============================================================================

def build_trelic_censer(M):
    root = bpy.data.objects.new("TRELIC_CENSER", None)
    bpy.context.scene.collection.objects.link(root)

    # Ornate cathedral brass stand: stepped trefoil base + curved swan-neck suspension mast!
    bm_lathe(root, "CenserStandBase", [
        (0.050, 0.000), (0.052, 0.005), (0.044, 0.011), (0.034, 0.015), (0.001, 0.015)
    ], M["cathedral_brass"], segs=30, flute_n=6, flute_amp=0.06)
    bm_torus(root, "StandBaseRim", 0.046, 0.0022, M["gilded_gold"], maj_s=36, min_s=8, loc=(0, 0, 0.010))

    # Sweeping curved gothic swan-neck mast rising behind (+Y) and arching over center to hook at Z = 0.166!
    mast_pts = [
        (0.0, 0.036, 0.012),
        (0.0, 0.048, 0.046),
        (0.0, 0.052, 0.092),
        (0.0, 0.044, 0.138),
        (0.0, 0.022, 0.165),
        (0.0, 0.000, 0.170),
        (0.0, -0.004, 0.158),
    ]
    bm_tube(root, "CenserStandMast", mast_pts, [0.0062, 0.0052, 0.0046, 0.0042, 0.0038, 0.0035, 0.0024], M["cathedral_brass"], segs=12)
    bm_torus(root, "SuspensionRingTop", 0.0085, 0.0020, M["gilded_gold"], maj_s=20, min_s=8, loc=(0, 0, 0.153), rot=(90, 0, 0))
    # Decorative baroque scroll bracing the lower mast
    brace_pts = [(0.0, 0.046, 0.042), (0.0, 0.032, 0.028), (0.0, 0.018, 0.014)]
    bm_tube(root, "StandScrollBrace", brace_pts, [0.0032, 0.0028, 0.0032], M["gilded_gold"], segs=8)

    # Hanging Pierced Gothic Cathedral Brass Thurible (centered at X=0, Y=0, Z=0.034..0.118)
    bowl_z = 0.034
    bm_lathe(root, "ThuribleBowl", [
        (0.001, bowl_z - 0.008), (0.008, bowl_z), (0.016, bowl_z + 0.006),
        (0.030, bowl_z + 0.016), (0.036, bowl_z + 0.028), (0.033, bowl_z + 0.036),
        (0.029, bowl_z + 0.036), (0.026, bowl_z + 0.022), (0.010, bowl_z + 0.012), (0.001, bowl_z + 0.012)
    ], M["cathedral_brass"], segs=32, flute_n=8, flute_amp=0.05)
    # Hanging finial acorn tassel underneath the thurible
    bm_sphere(root, "BottomTassel", 0.0055, M["gilded_gold"], scale=(0.85, 0.85, 1.45), loc=(0, 0, bowl_z - 0.011), sub=2)
    # Scalloped gallery collar ring at thurible waist
    bm_flat_ring(root, "ThuribleGalleryRim", 0.038, 0.031, 0.0055, M["gilded_gold"], segs=32, notches=8, notch_d=0.0035, loc=(0, 0, bowl_z + 0.035))

    # Pierced Scalloped Gothic Cathedral Dome (8 open arched ribs revealing glowing arcane mist core!)
    dome_z0 = bowl_z + 0.036
    dome_top = dome_z0 + 0.048
    for k in range(8):
        a = (k / 8.0) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        rib_pts = [
            (ca * 0.034, sa * 0.034, dome_z0),
            (ca * 0.031, sa * 0.031, dome_z0 + 0.016),
            (ca * 0.022, sa * 0.022, dome_z0 + 0.032),
            (ca * 0.011, sa * 0.011, dome_z0 + 0.043),
            (ca * 0.004, sa * 0.004, dome_top),
        ]
        bm_tube(root, f"CathedralDomeRib_{k}", rib_pts, [0.0030, 0.0028, 0.0026, 0.0024, 0.0020], M["cathedral_brass"], segs=8)
        # Pointed gothic arch cusp connecting neighboring ribs at mid-dome
        a2 = ((k + 0.5) / 8.0) * math.tau
        bm_sphere(root, f"DomeCusp_{k}", 0.0028, M["gilded_gold"], loc=(math.cos(a2) * 0.026, math.sin(a2) * 0.026, dome_z0 + 0.024), sub=1)
    # Cathedral Spire Crown atop dome
    bm_lathe(root, "DomeSpireFinial", [
        (0.010, dome_top - 0.003), (0.012, dome_top + 0.002), (0.005, dome_top + 0.009),
        (0.007, dome_top + 0.013), (0.001, dome_top + 0.022)
    ], M["gilded_gold"], segs=16)

    # Triple Hanging Brass Support Chains descending symmetrically from top ring to thurible rim lugs!
    for ci in range(3):
        a = (ci / 3.0) * math.tau - math.pi * 0.5 + math.pi / 3.0  # None directly blocking front center
        p_top = Vector((math.cos(a) * 0.007, math.sin(a) * 0.007, 0.150))
        p_bot = Vector((math.cos(a) * 0.036, math.sin(a) * 0.036, dome_z0 + 0.001))
        bm_torus(root, f"ChainLug_{ci}", 0.0042, 0.0014, M["gilded_gold"], maj_s=14, min_s=6, loc=tuple(p_bot), rot=(90, 0, math.degrees(a)))
        n_links = 10
        for li in range(n_links):
            t = (li + 0.5) / n_links
            lp = p_top.lerp(p_bot, t)
            dir_v = (p_bot - p_top).normalized()
            q = dir_v.to_track_quat("Z", "Y")
            twist_m = Matrix.Rotation(math.pi * 0.5 if li % 2 == 1 else 0.0, 3, "Z")
            eul = (q.to_matrix() @ twist_m).to_euler("XYZ")
            bm_stadium_link(root, f"CenserChain_{ci}_{li}", 0.0115, 0.0058, 0.0012, M["gilded_gold"],
                            loc=tuple(lp), rot=tuple(math.degrees(ang) for ang in eul))

    # Glowing Emerald-Violet Arcane Mist Core inside the pierced cathedral dome + smooth curling mist wisps!
    bm_sphere(root, "EmeraldArcaneCore", 0.016, M["censer_emerald"], scale=(1.0, 1.0, 1.35),
              loc=(0.0, 0.0, dome_z0 + 0.016), sub=3)
    for wi in range(4):
        wa = (wi / 4.0) * math.tau + 0.35
        w_pts, w_rads = [], []
        for s in range(14):
            u = s / 13.0
            ang = wa + u * 1.45
            rr = 0.010 + 0.032 * math.sin(u * math.pi * 0.72)
            zz = dome_z0 + 0.012 + u * 0.056
            w_pts.append((math.cos(ang) * rr, math.sin(ang) * rr, zz))
            w_rads.append(0.0034 * math.sin(max(0.10, u) * math.pi * 0.92) + 0.0007)
        bm_tube(root, f"ArcaneMistWisp_{wi}", w_pts, w_rads,
                M["censer_violet"] if wi % 2 == 0 else M["censer_emerald"], segs=12)

    ground_and_report(root, "TRELIC_CENSER")
    return root


# =============================================================================
# 8. TRELIC_GOLD_SCALES — Gilded Merchant Scales
#    Ornate balance column with carved lion/fleur finial, balanced gilded beam,
#    twin hanging brass pans heaped with sculpted gold florins and faceted
#    ruby/sapphire counterweights.
# =============================================================================

def build_trelic_gold_scales(M):
    root = bpy.data.objects.new("TRELIC_GOLD_SCALES", None)
    bpy.context.scene.collection.objects.link(root)

    # Stepped octagonal obsidian & gilded-brass balance base
    bm_lathe(root, "ScalesBaseObsidian", [
        (0.044, 0.000), (0.046, 0.006), (0.039, 0.012), (0.001, 0.012)
    ], M["obsidian"], segs=8, smooth=False)
    bm_lathe(root, "ScalesColumn", [
        (0.036, 0.011), (0.038, 0.015), (0.024, 0.022), (0.011, 0.032),
        (0.0085, 0.056), (0.0125, 0.070), (0.0075, 0.084), (0.0070, 0.120),
        (0.013, 0.130), (0.009, 0.138)
    ], M["cathedral_brass"], segs=28, flute_n=8, flute_amp=0.05)
    bm_torus(root, "ColumnGoldRingLow", 0.0135, 0.0022, M["gilded_gold"], maj_s=24, min_s=8, loc=(0, 0, 0.070))
    bm_torus(root, "ColumnGoldRingHigh", 0.0135, 0.0024, M["gilded_gold"], maj_s=24, min_s=8, loc=(0, 0, 0.130))

    # Carved Heraldic Fleur-de-Lis / Lion-Crest Finial crowning the balance column!
    fin_z = 0.138
    bm_lathe(root, "FleurCenterPetal", [
        (0.0055, fin_z), (0.0085, fin_z + 0.010), (0.0055, fin_z + 0.020), (0.001, fin_z + 0.030)
    ], M["gilded_gold"], segs=12)
    for sx in (-1.0, 1.0):
        f_pts = [
            (0.0, 0.0, fin_z + 0.004),
            (sx * 0.011, 0.0, fin_z + 0.014),
            (sx * 0.016, 0.0, fin_z + 0.020),
            (sx * 0.013, 0.0, fin_z + 0.008),
        ]
        bm_tube(root, f"FleurWing_{int(sx)}", f_pts, [0.0032, 0.0036, 0.0026, 0.0014], M["gilded_gold"], segs=8)
    bm_torus(root, "FleurCollar", 0.009, 0.0020, M["gilded_gold"], maj_s=18, min_s=8, loc=(0, 0, fin_z + 0.005))

    # Gracefully arched balanced gilded beam (compact ~0.156m total span!)
    beam_z = 0.132
    beam_pts = [
        (-0.052, 0.0, beam_z - 0.004),
        (-0.036, 0.0, beam_z + 0.004),
        (-0.018, 0.0, beam_z + 0.002),
        (0.000, 0.0, beam_z + 0.005),
        (0.018, 0.0, beam_z + 0.004),
        (0.036, 0.0, beam_z + 0.008),
        (0.052, 0.0, beam_z + 0.003),
    ]
    bm_tube(root, "GildedBalanceBeam", beam_pts, [0.0026, 0.0034, 0.0044, 0.0052, 0.0044, 0.0034, 0.0026], M["gilded_gold"], segs=12)
    bm_sphere(root, "BeamCenterJewel", 0.0052, M["ruby_glow"], scale=(1.0, 0.6, 1.2), loc=(0, -0.0045, beam_z + 0.005), sub=2)

    # Twin Hanging Brass Pans suspended by 3 gilded chains each!
    pan_specs = [
        ("Left", -0.050, beam_z - 0.004, 0.056, True),   # Left pan: heaped with gold florins
        ("Right", 0.050, beam_z + 0.003, 0.063, False),  # Right pan: ruby & sapphire counterweights
    ]
    for tag, px, top_z, pan_z, is_coins in pan_specs:
        bm_torus(root, f"BeamHook_{tag}", 0.0045, 0.0014, M["gilded_gold"], maj_s=16, min_s=6,
                 loc=(px, 0.0, top_z - 0.003), rot=(90, 0, 0))
        # Dished scalloped brass pan
        bm_lathe(root, f"ScalePan_{tag}", [
            (0.001, pan_z - 0.004), (0.016, pan_z - 0.002), (0.026, pan_z + 0.004),
            (0.029, pan_z + 0.010), (0.027, pan_z + 0.010), (0.023, pan_z + 0.004),
            (0.012, pan_z + 0.001), (0.001, pan_z + 0.001)
        ], M["cathedral_brass"], segs=28)
        bm_torus(root, f"PanGoldLip_{tag}", 0.028, 0.0016, M["gilded_gold"], maj_s=28, min_s=6, loc=(px, 0.0, pan_z + 0.010))
        # 3 Suspension chains per pan
        for ci in range(3):
            ca = (ci / 3.0) * math.tau + math.pi / 6.0
            c_pts = [
                (px, 0.0, top_z - 0.006),
                (px + math.cos(ca) * 0.027, math.sin(ca) * 0.027, pan_z + 0.010),
            ]
            bm_tube(root, f"PanChain_{tag}_{ci}", c_pts, [0.0013, 0.0013], M["gilded_gold"], segs=6)

        if is_coins:
            # 12 Individually placed sculpted gold florins heaped generously in the left pan!
            coin_offsets = [
                (0.000, 0.000, 0.002, 0, 0),
                (-0.010, -0.006, 0.003, 8, -5),
                (0.011, -0.005, 0.003, -6, 9),
                (0.001, 0.010, 0.003, -10, 4),
                (-0.009, 0.008, 0.005, 14, 12),
                (0.010, 0.008, 0.005, -12, -10),
                (-0.002, -0.009, 0.006, 18, 6),
                (0.004, 0.002, 0.007, -15, 16),
                (-0.006, 0.001, 0.009, 20, -14),
                (0.006, -0.004, 0.010, -22, 8),
                (-0.001, 0.004, 0.012, 16, 22),
                (0.001, -0.001, 0.015, -28, 12),
            ]
            for ci, (ox, oy, oz, rx, ry) in enumerate(coin_offsets):
                bm_cyl(root, f"GoldFlorin_{ci}", 0.0082, 0.0082, 0.0026, M["gilded_gold"], segs=18,
                       loc=(px + ox, oy, pan_z + oz), rot=(rx, ry, ci * 27))
        else:
            # Faceted Ruby & Sapphire royal counterweights + turned brass apothecary gram weight!
            bm_faceted_gem(root, "RubyCounterweight", rad=0.0115, h=0.022, mat=M["ruby_glow"], sides=8,
                           loc=(px - 0.007, -0.004, pan_z + 0.013), rot=(8, -10, 15))
            bm_faceted_gem(root, "SapphireCounterweight", rad=0.0105, h=0.020, mat=M["sapphire_gem"], sides=6,
                           loc=(px + 0.008, 0.004, pan_z + 0.012), rot=(-10, 14, -20))
            bm_lathe(root, "BrassGramWeight", [
                (0.0065, 0.0), (0.0060, 0.008), (0.0032, 0.011), (0.0048, 0.014), (0.001, 0.016)
            ], M["brushed_gold"], segs=16, loc=(px + 0.001, -0.010, pan_z + 0.002))

    ground_and_report(root, "TRELIC_GOLD_SCALES")
    return root


# =============================================================================
# 9. TRELIC_IRON_CHAIN — Executioner's Chain
#    Heavy coiled forged-iron shackle links looping organically around a massive
#    rune-stamped iron padlock with eerie cold-cyan glowing keyhole.
# =============================================================================

def build_trelic_iron_chain(M):
    root = bpy.data.objects.new("TRELIC_IRON_CHAIN", None)
    bpy.context.scene.collection.objects.link(root)

    # Coiled organic forged-iron chain links spiraling around the padlock on Z = 0.0
    n_links = 18
    for li in range(n_links):
        t = li / (n_links - 1)
        ang = -0.35 + t * math.tau * 1.38
        rad = 0.056 - t * 0.010 + math.sin(t * 9.0) * 0.003
        lx = math.cos(ang) * rad
        ly = math.sin(ang) * rad
        # Second layer rises organically over first coil!
        lz = 0.011 + (0.016 if t > 0.72 else 0.0) + (0.003 if li % 2 == 1 else 0.0)
        tang_deg = math.degrees(ang) + 90.0
        roll_deg = 78.0 if (li % 2 == 0) else 14.0
        mat_l = M["wrought_iron"] if (li % 3 != 0) else M["hammered_steel"]
        bm_stadium_link(root, f"ChainLink_{li}", length=0.032, width=0.019, wire_r=0.0044, mat=mat_l,
                        loc=(lx, ly, lz), rot=(roll_deg, 10.0 * math.sin(ang), tang_deg))

    # Heavy hinged forged-iron executioner wrist shackle propped dramatically on left-back!
    sh_piv = bpy.data.objects.new("ShackleCuffPivot", None)
    sh_piv.location = (-0.044, 0.014, 0.036)
    sh_piv.rotation_euler = Euler((math.radians(52), math.radians(-28), math.radians(24)), "XYZ")
    sh_piv.parent = root
    bpy.context.scene.collection.objects.link(sh_piv)
    bm_flat_ring(sh_piv, "IronShackleCuff", 0.028, 0.021, 0.016, M["wrought_iron"], segs=24, notches=4, notch_d=0.0025)
    bm_cyl(sh_piv, "ShackleHingePin", 0.0042, 0.0042, 0.022, M["hammered_steel"], segs=10, loc=(0.027, 0.0, 0.0))

    # Massive Rune-Stamped Gothic Iron Padlock leaning heroically upright in center facing -Y!
    lock_piv = bpy.data.objects.new("PadlockPivot", None)
    lock_piv.location = (0.006, -0.004, 0.016)
    lock_piv.rotation_euler = Euler((math.radians(-16), math.radians(5), math.radians(-8)), "XYZ")
    lock_piv.parent = root
    bpy.context.scene.collection.objects.link(lock_piv)

    # Sculpted beveled gothic shield-profile padlock body
    bm_p = bmesh.new()
    profile_xz = [
        (-0.026, 0.062), (0.026, 0.062),
        (0.032, 0.048), (0.030, 0.018),
        (0.018, 0.002), (0.000, -0.002), (-0.018, 0.002),
        (-0.030, 0.018), (-0.032, 0.048),
    ]
    th = 0.014
    f_v = [bm_p.verts.new((px, -th, pz)) for (px, pz) in profile_xz]
    b_v = [bm_p.verts.new((px, th, pz)) for (px, pz) in profile_xz]
    n_p = len(profile_xz)
    bm_p.faces.new(f_v)
    bm_p.faces.new(b_v[::-1])
    for i in range(n_p):
        ni = (i + 1) % n_p
        bm_p.faces.new((f_v[i], f_v[ni], b_v[ni], b_v[i]))
    bmesh.ops.bevel(bm_p, geom=list(bm_p.edges), offset=0.0032, segments=2, affect="EDGES", clamp_overlap=True)
    link_part(lock_piv, "PadlockBody", bm_p, M["wrought_iron"], smooth=True)

    # Riveted hammered-steel edge strap bands + corner studs across padlock front
    bm_bevel_box(lock_piv, "LockBandTop", (0.056, 0.031, 0.0085), M["hammered_steel"], bevel=0.0014, loc=(0, 0, 0.056))
    bm_bevel_box(lock_piv, "LockBandBot", (0.052, 0.031, 0.0075), M["hammered_steel"], bevel=0.0014, loc=(0, 0, 0.016))
    for sx in (-0.022, 0.022):
        for sz in (0.056, 0.016):
            bm_sphere(lock_piv, f"LockRivet_{sx}_{sz}", 0.0026, M["sterling_silver"], loc=(sx, -0.016, sz), sub=1)

    # Heavy forged arched U-shackle looping out top of padlock!
    shackle_pts = []
    for i in range(15):
        t = i / 14.0
        a = math.pi * (1.0 - t)
        sx = math.cos(a) * 0.018
        sz = 0.062 + (0.014 if 0 < i < 14 else 0.0) + math.sin(a) * 0.026
        shackle_pts.append((sx, 0.0, sz))
    bm_tube(lock_piv, "PadlockUShackle", shackle_pts, [0.0052] * 15, M["hammered_steel"], segs=12)

    # Eerie Cold-Cyan Glowing Keyhole + Escutcheon Plate + Stamped glowing micro-runes!
    bm_bevel_box(lock_piv, "KeyholeEscutcheon", (0.019, 0.004, 0.027), M["dark_iron"], bevel=0.0012, loc=(0, -0.0145, 0.036))
    # Classic gothic keyhole silhouette (round top + flared trapezoid slot) glowing intense cold-cyan!
    bm_cyl(lock_piv, "KeyholeGlowTop", 0.0046, 0.0046, 0.0045, M["cold_cyan"], segs=16, loc=(0, -0.0162, 0.041), rot=(90, 0, 0))
    bm_a = bmesh.new()
    kh = [(-0.0022, -0.002, 0.000), (0.0022, -0.002, 0.000), (0.0042, -0.002, -0.013), (-0.0042, -0.002, -0.013)]
    fv = [bm_a.verts.new(v) for v in kh]
    bv = [bm_a.verts.new((v[0], 0.002, v[2])) for v in kh]
    bm_a.faces.new(fv)
    bm_a.faces.new(bv[::-1])
    for k in range(4):
        nk = (k + 1) % 4
        bm_a.faces.new((fv[k], fv[nk], bv[nk], bv[k]))
    link_part(lock_piv, "KeyholeGlowSlot", bm_a, M["cold_cyan"], loc=(0, -0.0162, 0.039), smooth=False)

    # Stamped glowing cyan runes flanking the keyhole
    for sx in (-0.017, 0.017):
        bm_faceted_gem(lock_piv, f"LockRune_{sx}", rad=0.0032, h=0.012, mat=M["cold_cyan"], sides=4,
                       loc=(sx, -0.0156, 0.036))

    ground_and_report(root, "TRELIC_IRON_CHAIN")
    return root


# =============================================================================
# 10. TRELIC_PHOENIX_BOX — Phoenix Reliquary
#     Ornate gilded gothic miniature casket with hinged lid propped open,
#     revealing blazing sculpted golden-orange flame plumes and iridescent
#     crimson feathers rising from inside.
# =============================================================================

def build_trelic_phoenix_box(M):
    root = bpy.data.objects.new("TRELIC_PHOENIX_BOX", None)
    bpy.context.scene.collection.objects.link(root)

    # 4 Sculpted brass claw feet resting cleanly at Z = 0.0
    bw, bd, bh = 0.108, 0.072, 0.048
    for sx in (-1, 1):
        for sy in (-1, 1):
            bm_sphere(root, f"CasketFoot_{sx}_{sy}", 0.0085, M["gilded_gold"], scale=(1.1, 1.1, 0.72),
                      loc=(sx * (bw * 0.44), sy * (bd * 0.44), 0.006), sub=2)

    # Hollow obsidian/ebony miniature casket box (4 solid beveled walls + bottom floor + crimson velvet liner)
    base_z = 0.011
    wall_t = 0.008
    bm_bevel_box(root, "CasketFloor", (bw, bd, 0.009), M["obsidian"], bevel=0.0015, loc=(0, 0, base_z + 0.004))
    bm_bevel_box(root, "CasketWallFront", (bw, wall_t, bh), M["obsidian"], bevel=0.0015, loc=(0, -bd * 0.5 + wall_t * 0.5, base_z + bh * 0.5))
    bm_bevel_box(root, "CasketWallBack", (bw, wall_t, bh), M["obsidian"], bevel=0.0015, loc=(0, bd * 0.5 - wall_t * 0.5, base_z + bh * 0.5))
    bm_bevel_box(root, "CasketWallLeft", (wall_t, bd - wall_t * 1.5, bh), M["obsidian"], bevel=0.0015, loc=(-bw * 0.5 + wall_t * 0.5, 0, base_z + bh * 0.5))
    bm_bevel_box(root, "CasketWallRight", (wall_t, bd - wall_t * 1.5, bh), M["obsidian"], bevel=0.0015, loc=(bw * 0.5 - wall_t * 0.5, 0, base_z + bh * 0.5))
    bm_bevel_box(root, "VelvetBed", (bw - wall_t * 2.1, bd - wall_t * 2.1, 0.008), M["velvet_crimson"], bevel=0.001, loc=(0, 0, base_z + 0.012))

    # Gilded gothic casket trim: corner buttress pilasters, lower/upper molding frames, front trefoil arch & lock clasp!
    bm_bevel_box(root, "LowerMoldingGold", (bw + 0.007, bd + 0.007, 0.0065), M["gilded_gold"], bevel=0.0015, loc=(0, 0, base_z + 0.004))
    bm_bevel_box(root, "UpperLipGoldFront", (bw + 0.006, 0.009, 0.0055), M["gilded_gold"], bevel=0.0012, loc=(0, -bd * 0.5, base_z + bh))
    bm_bevel_box(root, "UpperLipGoldBack", (bw + 0.006, 0.009, 0.0055), M["gilded_gold"], bevel=0.0012, loc=(0, bd * 0.5, base_z + bh))
    for sx in (-1, 1):
        bm_bevel_box(root, f"UpperLipGoldSide_{sx}", (0.009, bd + 0.004, 0.0055), M["gilded_gold"], bevel=0.0012, loc=(sx * bw * 0.5, 0, base_z + bh))
        for sy in (-1, 1):
            bm_cyl(root, f"CornerPilaster_{sx}_{sy}", 0.0055, 0.0055, bh + 0.004, M["gilded_gold"], segs=8,
                   loc=(sx * (bw * 0.49), sy * (bd * 0.49), base_z + bh * 0.5))
    # Front gothic filigree clasp plate + glowing ruby jewel
    bm_bevel_box(root, "FrontClaspPlate", (0.024, 0.005, 0.022), M["gilded_gold"], bevel=0.0014, loc=(0, -bd * 0.5 - 0.002, base_z + bh * 0.62))
    bm_faceted_gem(root, "ClaspRuby", rad=0.0052, h=0.005, mat=M["ruby_glow"], sides=6,
                   loc=(0, -bd * 0.5 - 0.0045, base_z + bh * 0.62), rot=(90, 0, 0))
    # Side gothic filigree bars on front wall
    for sx in (-0.032, 0.032):
        bm_torus(root, f"FrontFiligreeArch_{sx}", 0.011, 0.0018, M["cathedral_brass"], maj_s=18, min_s=6,
                 loc=(sx, -bd * 0.5 - 0.0015, base_z + bh * 0.5), rot=(90, 0, 0))

    # Rear Hinged Arched Gothic Lid propped heroically open (~64°) on twin brass barrel hinges!
    hinge_z = base_z + bh + 0.002
    hinge_y = bd * 0.5
    for sx in (-0.030, 0.030):
        bm_cyl(root, f"BrassHinge_{sx}", 0.0042, 0.0042, 0.016, M["gilded_gold"], segs=12,
               loc=(sx, hinge_y + 0.002, hinge_z), rot=(0, 90, 0))

    lid_piv = bpy.data.objects.new("ReliquaryLidPivot", None)
    lid_piv.location = (0.0, hinge_y, hinge_z)
    lid_piv.rotation_euler = Euler((math.radians(82.0), 0.0, 0.0), "XYZ")
    lid_piv.parent = root
    bpy.context.scene.collection.objects.link(lid_piv)

    # Vaulted gothic coffer lid (curved arched roof + gilded ribs + inner crimson velvet!)
    bm_l = bmesh.new()
    n_arc = 12
    lid_rings = []
    for ix, lx in enumerate([-bw * 0.51, bw * 0.51]):
        row = []
        for ia in range(n_arc + 1):
            u = ia / n_arc
            ly = -u * bd
            lz = math.sin(u * math.pi) * 0.025
            row.append(bm_l.verts.new((lx, ly, lz)))
        lid_rings.append(row)
    for ia in range(n_arc):
        bm_l.faces.new((lid_rings[0][ia], lid_rings[0][ia + 1], lid_rings[1][ia + 1], lid_rings[1][ia]))
    bm_l.faces.new(lid_rings[0])
    bm_l.faces.new(lid_rings[1][::-1])
    bmesh.ops.solidify(bm_l, geom=list(bm_l.faces), thickness=0.0055)
    link_part(lid_piv, "VaultedLidShell", bm_l, M["obsidian"], smooth=True)

    # 3 Gilded ribs arching across the vaulted lid + gilded top crest ridge!
    for rx in (-bw * 0.46, 0.0, bw * 0.46):
        r_pts = [(rx, -(ia / 10.0) * bd, math.sin((ia / 10.0) * math.pi) * 0.0265) for ia in range(11)]
        bm_tube(lid_piv, f"LidGoldRib_{rx:.3f}", r_pts, [0.0030] * 11, M["gilded_gold"], segs=8)
    bm_bevel_box(lid_piv, "LidGoldFrontLip", (bw + 0.005, 0.006, 0.006), M["gilded_gold"], bevel=0.0012, loc=(0, -bd, 0.0))

    # Glowing molten ember bed inside the open reliquary
    bm_sphere(root, "PhoenixEmberBed", 0.032, M["phoenix_ember"], scale=(1.15, 0.70, 0.36),
              loc=(0, 0, base_z + 0.026), sub=3)

    # 7 Slender Sinuous Blazing Golden-Orange & Deep Ember Flame Plumes licking gracefully out of casket!
    flame_specs = [
        (0.000, -0.008, 0.034, 0.0115, 0.082, 2.8, 0.009, -0.008, "phoenix_flame"),
        (-0.020, -0.010, 0.032, 0.0095, 0.066, -2.2, -0.012, -0.006, "phoenix_ember"),
        (0.021, -0.009, 0.032, 0.0100, 0.070, 2.4, 0.013, -0.007, "phoenix_flame"),
        (-0.010, 0.002, 0.036, 0.0090, 0.074, 3.0, -0.007, -0.010, "phoenix_ember"),
        (0.012, 0.001, 0.036, 0.0085, 0.062, -2.6, 0.009, -0.008, "phoenix_flame"),
        (-0.029, -0.003, 0.030, 0.0072, 0.048, 2.0, -0.012, -0.004, "phoenix_flame"),
        (0.030, -0.003, 0.030, 0.0072, 0.050, -2.0, 0.012, -0.004, "phoenix_ember"),
    ]
    for fi, (fx, fy, fz, fr, fh, tw, lx, ly, mkey) in enumerate(flame_specs):
        bm_flame_plume(root, f"PhoenixFlame_{fi}", fr, fh, M[mkey], twist=tw, lean_x=lx, lean_y=ly,
                       loc=(fx, fy, base_z + fz))

    # 5 Sleek Curved Iridescent Crimson Phoenix Feathers with golden rachis shafts fanning heroically!
    feather_specs = [
        (0.000, 0.002, 0.0, 8.0, 0.0, 0.114, 0.0145),
        (-0.014, 0.000, -18.0, 10.0, -6.0, 0.102, 0.0130),
        (0.014, 0.000, 18.0, 10.0, 6.0, 0.102, 0.0130),
        (-0.025, -0.003, -33.0, 8.0, -10.0, 0.086, 0.0115),
        (0.025, -0.003, 33.0, 8.0, 10.0, 0.086, 0.0115),
    ]
    for fi, (fx, fy, ry, rx, rz, flen, fw) in enumerate(feather_specs):
        fpiv = bpy.data.objects.new(f"PhoenixFeatherPiv_{fi}", None)
        fpiv.location = (fx, fy, base_z + 0.036)
        fpiv.rotation_euler = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ")
        fpiv.parent = root
        bpy.context.scene.collection.objects.link(fpiv)
        # Sweeping S-curved golden quill shaft
        q_pts = [(math.sin((i / 8.0) * math.pi) * (0.004 if ry >= 0 else -0.004), -0.012 * ((i / 8.0) ** 1.7), (i / 8.0) * flen) for i in range(9)]
        bm_tube(fpiv, f"FeatherQuill_{fi}", q_pts, [0.0018 - 0.0012 * (i / 8.0) for i in range(9)], M["gilded_gold"], segs=8)
        # Thin sculpted diamond-section curved iridescent crimson vane with crisp barb notches!
        bm_v = bmesh.new()
        rows = []
        for i in range(15):
            t = i / 14.0
            cx = math.sin(t * math.pi) * (0.004 if ry >= 0 else -0.004)
            sp = Vector((cx, -0.012 * (t ** 1.7), t * flen))
            w = fw * (math.sin(max(0.02, (t - 0.10) / 0.90) * math.pi) ** 0.78) * (1.0 - 0.25 * t)
            if i in (6, 10):
                w *= 0.62  # Crisp phoenix barb notch
            th_v = 0.0014 * (1.0 - 0.55 * t)
            vL = bm_v.verts.new(sp + Vector((-w, 0.0022, 0.0)))
            vF = bm_v.verts.new(sp + Vector((0.0, -th_v, 0.0)))
            vR = bm_v.verts.new(sp + Vector((w, 0.0022, 0.0)))
            vB = bm_v.verts.new(sp + Vector((0.0, th_v, 0.0)))
            rows.append((vL, vF, vR, vB))
        tip_v = bm_v.verts.new(Vector((0.0, -0.014, flen * 1.05)))
        for i in range(14):
            for k in range(4):
                kn = (k + 1) % 4
                bm_v.faces.new((rows[i][k], rows[i][kn], rows[i + 1][kn], rows[i + 1][k]))
        for k in range(4):
            kn = (k + 1) % 4
            bm_v.faces.new((rows[-1][k], rows[-1][kn], tip_v))
        link_part(fpiv, f"FeatherVane_{fi}", bm_v, M["phoenix_feather"], smooth=True)
        # Sleek golden-flame chevron eye-spot near feather tip!
        bm_faceted_gem(fpiv, f"FeatherEyeSpot_{fi}", rad=0.0032, h=0.009, mat=M["phoenix_flame"], sides=4,
                       loc=(0.0, -0.010, flen * 0.84), rot=(12, 0, 0))

    ground_and_report(root, "TRELIC_PHOENIX_BOX")
    return root


# =============================================================================
# 2x5 INDIVIDUAL STUDIO TILE RENDERING & CONTACT SHEET STITCHING
# =============================================================================

def render_relic_tile(builder_fn, tag: str, out_png: pathlib.Path):
    scene = reset_scene()
    M = get_mats()
    root = builder_fn(M)

    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scene.render.resolution_x = 384
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(out_png)

    # Moody dark-tavern background world
    world = bpy.data.worlds.new(f"StudioWorld_{tag}")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.022, 0.016, 0.014, 1.0)
        bg.inputs[1].default_value = 0.72

    # Dark walnut tavern tabletop + subtle brass coaster ring so tabletop contact & reflections shine!
    mat_tbl = make_mat("StudioWalnut", (0.085, 0.042, 0.020), metallic=0.04, roughness=0.42)
    mat_coaster = make_mat("CoasterBrass", (0.58, 0.38, 0.12), metallic=0.90, roughness=0.25)
    tbl_root = bpy.data.objects.new("StudioStage", None)
    scene.collection.objects.link(tbl_root)
    bm_cyl(tbl_root, "TableDisc", 0.42, 0.42, 0.016, mat_tbl, segs=48, loc=(0, 0, -0.008))
    bm_torus(tbl_root, "CoasterRim", 0.086, 0.0022, mat_coaster, maj_s=48, min_s=8, loc=(0, 0, 0.0012))

    # Measure relic bounding center for crisp framing
    bpy.context.view_layer.update()
    zs = []
    for ch in root.children_recursive:
        if ch.type == "MESH" and ch.data:
            mw = ch.matrix_world
            for v in ch.data.vertices:
                zs.append((mw @ v.co).z)
    h_mid = (max(zs) * 0.49) if zs else 0.075

    cam_d = bpy.data.cameras.new("TileCam")
    cam_d.lens = 58.0
    cam_o = bpy.data.objects.new("TileCam", cam_d)
    cam_o.location = Vector((0.125, -0.325, h_mid + 0.115))
    cam_o.rotation_euler = (Vector((0.0, 0.0, h_mid)) - cam_o.location).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    # Warm tavern key light + cool steel rim + soft front-fill bounce
    l_key = bpy.data.lights.new("Key", "AREA")
    l_key.energy = 14.0
    l_key.color = (1.0, 0.88, 0.72)
    l_key.size = 0.55
    o_key = bpy.data.objects.new("Key", l_key)
    o_key.location = Vector((0.36, -0.42, 0.52))
    o_key.rotation_euler = (Vector((0, 0, h_mid)) - o_key.location).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_key)

    l_rim = bpy.data.lights.new("Rim", "AREA")
    l_rim.energy = 11.0
    l_rim.color = (0.68, 0.82, 1.0)
    l_rim.size = 0.45
    o_rim = bpy.data.objects.new("Rim", l_rim)
    o_rim.location = Vector((-0.38, 0.34, 0.36))
    o_rim.rotation_euler = (Vector((0, 0, h_mid)) - o_rim.location).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_rim)

    l_fill = bpy.data.lights.new("Fill", "POINT")
    l_fill.energy = 3.2
    l_fill.color = (1.0, 0.76, 0.52)
    o_fill = bpy.data.objects.new("Fill", l_fill)
    o_fill.location = Vector((-0.26, -0.32, 0.16))
    scene.collection.objects.link(o_fill)

    bpy.ops.render.render(write_still=True)


def stitch_2x5_sheet(tile_paths: list, out_path: pathlib.Path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    imgs = [bpy.data.images.load(str(p)) for p in tile_paths]
    tw, th = imgs[0].size
    cols, rows = 5, 2
    full_w, full_h = tw * cols, th * rows
    sheet = bpy.data.images.new("TabletopRelics2x5", width=full_w, height=full_h, alpha=False)
    buf = [0.0] * (full_w * full_h * 4)
    row_tile = tw * 4
    row_full = full_w * 4
    for idx, img in enumerate(imgs):
        px = list(img.pixels[:])
        c = idx % cols
        r_inv = (rows - 1) - (idx // cols)
        x_off = c * tw * 4
        y_base = r_inv * th
        for y in range(th):
            in_off = y * row_tile
            out_off = (y_base + y) * row_full + x_off
            buf[out_off : out_off + row_tile] = px[in_off : in_off + row_tile]
    sheet.pixels.foreach_set(buf)
    sheet.filepath_raw = str(out_path)
    sheet.file_format = "PNG"
    sheet.save()
    for p in tile_paths:
        try:
            p.unlink(missing_ok=True)
        except Exception:
            pass
    print("RENDERED_RELICS_PREVIEW=", out_path)


def main():
    relics = [
        ("TRELIC_SOUL_BELL", build_trelic_soul_bell),
        ("TRELIC_BLOOD_SEAL", build_trelic_blood_seal),
        ("TRELIC_STAR_BOW", build_trelic_star_bow),
        ("TRELIC_ASH_GLASS", build_trelic_ash_glass),
        ("TRELIC_WAR_HORN", build_trelic_war_horn),
        ("TRELIC_HOLLOW_MASK", build_trelic_hollow_mask),
        ("TRELIC_CENSER", build_trelic_censer),
        ("TRELIC_GOLD_SCALES", build_trelic_gold_scales),
        ("TRELIC_IRON_CHAIN", build_trelic_iron_chain),
        ("TRELIC_PHOENIX_BOX", build_trelic_phoenix_box),
    ]

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    tile_paths = []

    for rid, fn in relics:
        reset_scene()
        M = get_mats()
        root = fn(M)
        out_glb = RELIC_DIR / f"{rid}.glb"
        export_glb(root, out_glb)
        print(f"EXPORTED_TABLETOP_RELIC={out_glb.name} ({out_glb.stat().st_size} bytes)")

        tpath = PREVIEW_PATH.parent / f"_tmp_trelic_{rid}.png"
        render_relic_tile(fn, rid, tpath)
        tile_paths.append(tpath)

    stitch_2x5_sheet(tile_paths, PREVIEW_PATH)
    print("ALL_10_TABLETOP_RELICS_DONE")


if __name__ == "__main__":
    main()
