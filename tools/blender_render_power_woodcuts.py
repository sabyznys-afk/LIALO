"""
Blender 5.3 headless script that builds and renders 21 asymmetric 3D medieval dioramas/reliefs
using BLENDER_EEVEE + Freestyle ink linework (transparent RGBA):
  - 16 Power Card woodcut subjects -> tools/power_renders/SPEC_*.png
  -  5 Deck Back heraldic reliefs  -> tools/power_renders/DECK_*.png
Run via:
  blender --background --factory-startup --python tools/blender_render_power_woodcuts.py
"""
import math
import os
import pathlib
import random
import bpy
import bmesh
from mathutils import Vector, Euler, Matrix

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_DIR = ROOT / "tools" / "power_renders"


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"

    # Enable Freestyle ink contours for crisp medieval woodcut outlines & inner creases
    scene.render.use_freestyle = True
    vl = scene.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    fs.crease_angle = math.radians(132.0)
    if len(fs.linesets) == 0:
        ls = fs.linesets.new("WoodcutInk")
    else:
        ls = fs.linesets[0]
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("WoodcutInkStyle")
    ls.select_silhouette = True
    ls.select_crease = True
    ls.select_border = True
    ls.select_external_contour = True
    ls.select_edge_mark = False
    lstyle = ls.linestyle
    lstyle.color = (0.06, 0.035, 0.02)
    lstyle.thickness = 2.8
    lstyle.caps = "ROUND"

    # Dramatic chiaroscuro studio lighting for woodcut light/shadow separation
    cam_data = bpy.data.cameras.new("WoodcutCam")
    cam_data.lens = 42.0
    cam_obj = bpy.data.objects.new("WoodcutCam", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    key_d = bpy.data.lights.new("KeyLight", type="AREA")
    key_d.energy = 140.0
    key_d.size = 2.4
    key_d.color = (1.0, 0.96, 0.88)
    key_o = bpy.data.objects.new("KeyLight", key_d)
    key_o.location = (-2.4, -2.5, 2.8)
    key_o.rotation_euler = (math.radians(48), 0.0, math.radians(-38))
    scene.collection.objects.link(key_o)

    fill_d = bpy.data.lights.new("FillLight", type="AREA")
    fill_d.energy = 26.0
    fill_d.size = 3.5
    fill_d.color = (0.86, 0.90, 0.96)
    fill_o = bpy.data.objects.new("FillLight", fill_d)
    fill_o.location = (2.8, -1.8, 0.6)
    fill_o.rotation_euler = (math.radians(78), 0.0, math.radians(58))
    scene.collection.objects.link(fill_o)

    rim_d = bpy.data.lights.new("RimLight", type="AREA")
    rim_d.energy = 75.0
    rim_d.size = 2.0
    rim_d.color = (1.0, 0.88, 0.68)
    rim_o = bpy.data.objects.new("RimLight", rim_d)
    rim_o.location = (2.0, 2.6, 2.0)
    rim_o.rotation_euler = (math.radians(122), 0.0, math.radians(145))
    scene.collection.objects.link(rim_o)

    if scene.world is None:
        scene.world = bpy.data.worlds.new("WoodcutWorld")
    if scene.world.node_tree is None:
        scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.14, 0.12, 0.10, 1.0)
        bg.inputs["Strength"].default_value = 0.25
    return scene


def make_mat(name: str, color: tuple, metallic: float = 0.0, roughness: float = 0.55,
             emission: tuple = (0.0, 0.0, 0.0), emit_str: float = 0.0, noise_bump: float = 0.15):
    mat = bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emit_str
    if noise_bump > 0.0:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 18.0
        noise.inputs["Detail"].default_value = 6.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = noise_bump
        bump.inputs["Distance"].default_value = 0.015
        nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def palette():
    return {
        "gold": make_mat("Gold", (0.86, 0.64, 0.20), metallic=0.88, roughness=0.30, noise_bump=0.14),
        "brass": make_mat("Brass", (0.76, 0.54, 0.18), metallic=0.84, roughness=0.36, noise_bump=0.16),
        "copper": make_mat("Copper", (0.74, 0.36, 0.18), metallic=0.82, roughness=0.36, noise_bump=0.14),
        "iron": make_mat("Iron", (0.24, 0.25, 0.28), metallic=0.78, roughness=0.46, noise_bump=0.22),
        "steel": make_mat("Steel", (0.72, 0.76, 0.82), metallic=0.88, roughness=0.26, noise_bump=0.10),
        "silver": make_mat("Silver", (0.86, 0.88, 0.92), metallic=0.90, roughness=0.22, noise_bump=0.08),
        "oak": make_mat("Oak", (0.44, 0.27, 0.14), roughness=0.72, noise_bump=0.28),
        "dark_wood": make_mat("DarkWood", (0.24, 0.14, 0.08), roughness=0.76, noise_bump=0.30),
        "bone": make_mat("Bone", (0.90, 0.83, 0.66), roughness=0.48, noise_bump=0.12),
        "parchment": make_mat("Parchment", (0.86, 0.78, 0.60), roughness=0.78, noise_bump=0.20),
        "crimson": make_mat("Crimson", (0.64, 0.10, 0.11), roughness=0.52, noise_bump=0.14),
        "emerald": make_mat("Emerald", (0.14, 0.50, 0.24), roughness=0.44, noise_bump=0.14),
        "lapis": make_mat("Lapis", (0.12, 0.28, 0.62), roughness=0.46, noise_bump=0.14),
        "stone": make_mat("Stone", (0.44, 0.41, 0.38), roughness=0.85, noise_bump=0.34),
        "glass": make_mat("Glass", (0.64, 0.84, 0.90), roughness=0.14, metallic=0.12, emission=(0.14, 0.24, 0.28), emit_str=0.35, noise_bump=0.04),
        "amber": make_mat("Amber", (0.96, 0.56, 0.12), roughness=0.24, emission=(1.0, 0.44, 0.08), emit_str=1.2, noise_bump=0.06),
        "cyan_glow": make_mat("CyanGlow", (0.35, 0.88, 1.0), roughness=0.18, emission=(0.25, 0.84, 1.0), emit_str=1.8, noise_bump=0.04),
        "ruby": make_mat("Ruby", (0.82, 0.10, 0.16), roughness=0.22, emission=(0.65, 0.06, 0.10), emit_str=0.9, noise_bump=0.04),
        "leather": make_mat("Leather", (0.34, 0.19, 0.10), roughness=0.68, noise_bump=0.26),
        "rope": make_mat("Rope", (0.66, 0.52, 0.32), roughness=0.84, noise_bump=0.36),
        "burlap": make_mat("Burlap", (0.68, 0.58, 0.42), roughness=0.88, noise_bump=0.38),
    }


def add_bm_obj(name: str, bm: bmesh.types.BMesh, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True, bevel_amt=0.0):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    if bevel_amt > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel_amt
        mod.segments = 2
    return obj


def add_lathe(name: str, profile_rz: list, mat, segs=28, loc=(0, 0, 0), rot=(0, 0, 0), wobble=0.0, seed=1):
    bm = bmesh.new()
    rng = random.Random(seed)
    rings = []
    for i in range(segs):
        a = (i / segs) * math.tau
        ring = []
        for (r, z) in profile_rz:
            rr = r * (1.0 + wobble * math.sin(a * 3.0 + z * 8.0) + wobble * 0.35 * rng.uniform(-1, 1)) if r > 0.002 else r
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring)
    for i in range(segs):
        ni = (i + 1) % segs
        for j in range(len(profile_rz) - 1):
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][j + 1], rings[i][j + 1]))
    # Cap top/bottom if center not 0
    if profile_rz[0][0] > 0.003:
        bm.faces.new([rings[i][0] for i in range(segs)][::-1])
    if profile_rz[-1][0] > 0.003:
        bm.faces.new([rings[i][-1] for i in range(segs)])
    return add_bm_obj(name, bm, mat, loc=loc, rot=rot, smooth=True)


def add_tube_curve(name: str, pts: list, radii: list, mat, segs=12, bevel_res=1, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    n = len(pts)
    rings = []
    prev_u = None
    for idx, (pt, rad) in enumerate(zip(pts, radii)):
        p = Vector(pt)
        if idx == 0:
            tang = (Vector(pts[1]) - p).normalized()
        elif idx == n - 1:
            tang = (p - Vector(pts[-2])).normalized()
        else:
            tang = (Vector(pts[idx + 1]) - Vector(pts[idx - 1])).normalized()
        if prev_u is None:
            ref = Vector((0, 0, 1)) if abs(tang.z) < 0.85 else Vector((0, 1, 0))
            u = tang.cross(ref).normalized()
        else:
            # Smooth parallel transport eliminates any ribbon flip when tangent turns!
            u = prev_u - tang * prev_u.dot(tang)
            if u.length < 1e-4:
                u = tang.cross(Vector((1, 0, 0)))
            u.normalize()
        prev_u = u
        v = tang.cross(u).normalized()
        ring = []
        for k in range(segs):
            a = (k / segs) * math.tau
            pos = p + (u * math.cos(a) + v * math.sin(a)) * rad
            ring.append(bm.verts.new(pos))
        rings.append(ring)
    for idx in range(n - 1):
        for k in range(segs):
            nk = (k + 1) % segs
            bm.faces.new((rings[idx][k], rings[idx][nk], rings[idx + 1][nk], rings[idx + 1][k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    return add_bm_obj(name, bm, mat, loc=loc, rot=rot, smooth=True)


def add_box(name: str, size: tuple, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel_amt=0.015):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    return add_bm_obj(name, bm, mat, loc=loc, rot=rot, smooth=False, bevel_amt=bevel_amt)


def add_sphere(name: str, radius: float, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), sub=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return add_bm_obj(name, bm, mat, loc=loc, rot=rot, smooth=True)


def add_cyl(name: str, r1: float, r2: float, depth: float, mat, loc=(0, 0, 0), rot=(0, 0, 0), segs=18):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return add_bm_obj(name, bm, mat, loc=loc, rot=rot, smooth=True)


def add_torus(name: str, maj_r: float, min_r: float, mat, loc=(0, 0, 0), rot=(0, 0, 0), maj_seg=28, min_seg=10):
    bm = bmesh.new()
    rings = []
    for i in range(maj_seg):
        a = (i / maj_seg) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        ring = []
        for j in range(min_seg):
            b = (j / min_seg) * math.tau
            rr = maj_r + math.cos(b) * min_r
            zz = math.sin(b) * min_r
            ring.append(bm.verts.new((ca * rr, sa * rr, zz)))
        rings.append(ring)
    for i in range(maj_seg):
        ni = (i + 1) % maj_seg
        for j in range(min_seg):
            nj = (j + 1) % min_seg
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][nj], rings[i][nj]))
    return add_bm_obj(name, bm, mat, loc=loc, rot=rot, smooth=True)


def frame_camera(cam_obj, target=(0, 0, 0.35), dist=2.55, elev_deg=20.0, yaw_deg=12.0):
    er = math.radians(elev_deg)
    yr = math.radians(yaw_deg)
    dx = dist * math.cos(er) * math.sin(yr)
    dy = -dist * math.cos(er) * math.cos(yr)
    dz = dist * math.sin(er)
    t = Vector(target)
    cam_obj.location = t + Vector((dx, dy, dz))
    direction = t - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


# =============================================================================
# 16 ASYMMETRIC MEDIEVAL POWER CARD DIORAMAS
# =============================================================================

def scene_spec_vampire(P):
    # Tilted ornate chalice spilling crimson wine stream from its rim + coiled serpent + crooked moon
    add_lathe("Chalice", [
        (0.01, -0.52), (0.34, -0.52), (0.30, -0.45), (0.09, -0.36), (0.07, -0.10),
        (0.14, 0.02), (0.08, 0.08), (0.11, 0.18), (0.36, 0.34), (0.40, 0.56),
        (0.35, 0.56), (0.30, 0.36), (0.08, 0.22), (0.01, 0.22)
    ], P["brass"], loc=(-0.10, 0.0, 0.42), rot=(8, -24, -18), wobble=0.04, seed=11)
    # Coiled horned serpent wrapping around lower stem
    s_pts = [(-0.46 + 0.30 * math.cos(t), 0.28 * math.sin(t) - 0.06, -0.04 + t * 0.14) for t in [k * 0.28 for k in range(18)]]
    s_rad = [0.066 * (1.0 - 0.55 * (i / 17.0)) for i in range(18)]
    add_tube_curve("Serpent", s_pts, s_rad, P["iron"])
    add_sphere("SerpHead", 0.072, P["iron"], loc=s_pts[-1], scale=(1.35, 0.9, 0.78))
    # Spilling crimson wine stream arcing directly out of upper-right chalice lip!
    w_pts = [(0.16, -0.14, 0.84), (0.34, -0.16, 0.68), (0.42, -0.18, 0.38), (0.38, -0.16, 0.06)]
    add_tube_curve("BloodStream", w_pts, [0.060, 0.045, 0.032, 0.020], P["crimson"])
    add_sphere("Drop1", 0.046, P["crimson"], loc=(0.38, -0.16, -0.06), scale=(0.8, 0.8, 1.45))
    # Smooth untwisted Crescent Moon framing upper-right
    m_pts = [(0.44 + math.cos(math.radians(d)) * 0.30, 0.28, 0.92 + math.sin(math.radians(d)) * 0.30) for d in range(-75, 115, 12)]
    m_rad = [0.072 * math.sin(math.pi * i / (len(m_pts) - 1)) + 0.010 for i in range(len(m_pts))]
    add_tube_curve("Moon", m_pts, m_rad, P["gold"])
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.36), dist=2.35, elev_deg=14, yaw_deg=10)


def scene_spec_storm(P):
    # Leaning craggy watchtower on basalt rock struck diagonally by forked lightning + cloud scrolls
    add_sphere("RockBase", 0.55, P["stone"], loc=(-0.15, 0.05, -0.28), scale=(1.2, 0.9, 0.45), sub=2)
    add_cyl("Tower", 0.28, 0.22, 0.88, P["stone"], loc=(-0.22, 0.04, 0.32), rot=(4, -9, 6), segs=12)
    add_cyl("Roof", 0.31, 0.02, 0.36, P["iron"], loc=(-0.29, 0.02, 0.90), rot=(4, -9, 6), segs=12)
    for k in range(5):
        a = k * math.tau / 5.0
        add_box(f"Merlon{k}", (0.09, 0.09, 0.11), P["stone"], loc=(-0.25 + math.cos(a) * 0.21, 0.04 + math.sin(a) * 0.21, 0.74), rot=(4, -9, 0), bevel_amt=0.01)
    # Jagged diagonal lightning bolt striking from upper-right!
    bolt_pts = [(0.58, -0.05, 1.24), (0.30, -0.08, 0.96), (0.44, -0.10, 0.88), (0.04, -0.06, 0.58), (0.14, -0.06, 0.52), (-0.18, 0.0, 0.36)]
    add_tube_curve("BoltMain", bolt_pts, [0.065, 0.055, 0.050, 0.042, 0.036, 0.022], P["amber"], segs=6)
    add_tube_curve("BoltFork", [(0.30, -0.08, 0.96), (0.48, -0.12, 0.62), (0.42, -0.10, 0.44)], [0.032, 0.024, 0.012], P["amber"], segs=6)
    # Swirling tempest cloud puffs upper-right/left
    for cx, cz, r in [(0.45, 1.18, 0.18), (0.28, 1.14, 0.15), (-0.42, 1.06, 0.14)]:
        add_sphere(f"Cloud{cx}", r, P["steel"], loc=(cx, 0.12, cz), scale=(1.35, 0.8, 0.75))
    frame_camera(bpy.context.scene.camera, target=(0.04, 0.0, 0.48), dist=2.55, elev_deg=12, yaw_deg=12)


def scene_spec_mirror(P):
    # Ornate leaning oval hand-mirror on carved stand with a diagonal crack & asymmetric crescent emblem
    add_lathe("Stand", [(0.01, 0), (0.28, 0), (0.24, 0.06), (0.08, 0.14), (0.06, 0.30), (0.10, 0.34)], P["dark_wood"], loc=(0.06, 0.0, -0.30))
    add_torus("FrameOuter", 0.44, 0.065, P["brass"], loc=(0.02, 0.0, 0.46), rot=(82, 8, -18), maj_seg=32, min_seg=12)
    add_torus("FrameInner", 0.38, 0.025, P["gold"], loc=(0.02, -0.02, 0.46), rot=(82, 8, -18), maj_seg=28, min_seg=8)
    add_cyl("GlassDisc", 0.39, 0.39, 0.03, P["glass"], loc=(0.02, 0.01, 0.46), rot=(82, 8, -18), segs=28)
    # Raised baroque finials asymmetrically around rim + diagonal crack shard
    for k in range(7):
        a = k * math.tau / 7.0 + 0.35
        add_sphere(f"Scroll{k}", 0.065 if k % 2 == 0 else 0.045, P["gold"], loc=(0.02 + math.cos(a) * 0.48, 0.0, 0.46 + math.sin(a) * 0.48))
    add_tube_curve("MirrorCrack", [(-0.24, -0.04, 0.74), (-0.04, -0.05, 0.50), (0.14, -0.05, 0.42), (0.28, -0.04, 0.22)], [0.016, 0.014, 0.012, 0.008], P["iron"], segs=6)
    add_sphere("InnerEye", 0.11, P["cyan_glow"], loc=(-0.06, -0.02, 0.50), scale=(1.2, 0.35, 0.7))
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.34), dist=2.30, elev_deg=10, yaw_deg=14)


def scene_spec_alchemist(P):
    # Crooked tripod holding cauldron over logs + suspended tilted swan-neck glass retort
    for k in range(3):
        a = math.radians(30 + k * 120)
        add_cyl(f"Leg{k}", 0.028, 0.018, 0.68, P["iron"], loc=(math.cos(a) * 0.28, math.sin(a) * 0.28, 0.14), rot=(math.sin(a) * 20, -math.cos(a) * 20, 0), segs=8)
    add_lathe("Cauldron", [
        (0.01, -0.10), (0.24, -0.06), (0.36, 0.08), (0.34, 0.24), (0.28, 0.32), (0.33, 0.36), (0.29, 0.38), (0.24, 0.32), (0.01, 0.22)
    ], P["iron"], loc=(0.04, 0.0, -0.02), rot=(4, -5, 10))
    for fi, ang in enumerate([-28, 12, 54]):
        add_cyl(f"Log{fi}", 0.042, 0.036, 0.56, P["dark_wood"], loc=(0.02, 0.0, -0.18), rot=(86, ang, fi * 35), segs=8)
    add_sphere("FireCore", 0.16, P["amber"], loc=(0.02, -0.04, -0.08), scale=(1.3, 1.0, 0.85))
    # Suspended glass retort tilted upper-left pouring glowing spiral down
    add_sphere("RetortBulb", 0.24, P["glass"], loc=(-0.18, 0.0, 0.84))
    neck_pts = [(-0.08, 0.0, 1.04), (0.14, -0.04, 1.02), (0.32, -0.06, 0.78), (0.38, -0.06, 0.58)]
    add_tube_curve("RetortNeck", neck_pts, [0.08, 0.055, 0.038, 0.024], P["glass"])
    # Coiled vapor fume spiral
    vap = [(0.10 + math.cos(t * 2.2) * (0.14 - t * 0.02), math.sin(t * 2.2) * 0.10, 0.34 + t * 0.14) for t in [i * 0.35 for i in range(10)]]
    add_tube_curve("Vapor", vap, [0.035] * 10, P["amber"])
    frame_camera(bpy.context.scene.camera, target=(0.04, 0.0, 0.40), dist=2.45, elev_deg=16, yaw_deg=14)


def scene_spec_oracle(P):
    # Open illuminated medieval grimoire + suspended tilted astrolabe eye & quill
    add_box("BookL", (0.48, 0.56, 0.07), P["leather"], loc=(-0.22, 0.0, -0.02), rot=(18, -22, 6), bevel_amt=0.015)
    add_box("BookR", (0.48, 0.56, 0.07), P["parchment"], loc=(0.20, 0.02, -0.04), rot=(18, 18, 6), bevel_amt=0.012)
    add_cyl("Spine", 0.055, 0.055, 0.58, P["dark_wood"], loc=(-0.01, 0.01, -0.07), rot=(72, 0, -6), segs=12)
    # Tilted brass astrolabe rings & All-Seeing Iris above book
    add_torus("RingA", 0.36, 0.032, P["brass"], loc=(0.04, 0.0, 0.64), rot=(74, 16, -24))
    add_torus("RingB", 0.27, 0.024, P["gold"], loc=(0.04, 0.0, 0.64), rot=(58, -32, 18))
    add_sphere("EyeWhite", 0.16, P["bone"], loc=(0.04, -0.02, 0.64), scale=(1.25, 0.52, 0.88))
    add_sphere("Iris", 0.075, P["cyan_glow"], loc=(0.04, -0.09, 0.64), scale=(1.0, 0.4, 1.0))
    # Tilted quill resting across right page
    add_tube_curve("Quill", [(0.16, -0.18, 0.05), (0.34, 0.02, 0.24), (0.48, 0.14, 0.48)], [0.012, 0.038, 0.008], P["bone"])
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.34), dist=2.35, elev_deg=22, yaw_deg=15)


def scene_spec_phoenix(P):
    # Sweeping heraldic winged firebird rising diagonally from shallow burning brass brazier
    add_lathe("Brazier", [(0.01, -0.36), (0.34, -0.36), (0.24, -0.24), (0.44, -0.08), (0.36, -0.06), (0.18, -0.18), (0.01, -0.18)], P["brass"], loc=(0.0, 0.0, -0.04))
    add_sphere("EmberBed", 0.25, P["amber"], loc=(0.0, 0.0, -0.16), scale=(1.0, 1.0, 0.42))
    # Sculpted arched firebird neck, chest & hooked crest beak
    body = [(0.0, 0.0, -0.04), (0.04, -0.04, 0.22), (-0.04, -0.06, 0.56), (-0.16, -0.08, 0.82), (-0.28, -0.10, 0.78)]
    add_tube_curve("BirdBody", body, [0.15, 0.11, 0.085, 0.068, 0.018], P["crimson"])
    add_tube_curve("CrestPlume", [(-0.14, -0.06, 0.86), (-0.02, -0.02, 1.02), (0.10, 0.02, 0.96)], [0.032, 0.022, 0.008], P["gold"])
    # Asymmetric spreading fanned pinion feathers (wider silhouette!)
    for idx in range(7):
        t = idx / 6.0
        ang = math.radians(15 + t * 55)
        pts = [(0.04, 0.0, 0.34 - t * 0.06), (0.28 + math.cos(ang) * 0.24, 0.04, 0.48 + math.sin(ang) * 0.34), (0.42 + math.cos(ang) * 0.34, 0.08, 0.54 + math.sin(ang) * 0.48)]
        add_tube_curve(f"WingR{idx}", pts, [0.048, 0.036, 0.012], P["gold"] if idx % 2 == 0 else P["amber"])
    for idx in range(6):
        t = idx / 5.0
        ang = math.radians(20 + t * 52)
        pts = [(-0.06, 0.0, 0.32 - t * 0.06), (-0.26 - math.cos(ang) * 0.22, 0.04, 0.40 + math.sin(ang) * 0.28), (-0.38 - math.cos(ang) * 0.28, 0.08, 0.46 + math.sin(ang) * 0.36)]
        add_tube_curve(f"WingL{idx}", pts, [0.044, 0.032, 0.010], P["crimson"] if idx % 2 == 0 else P["gold"])
    for ti in range(3):
        add_tube_curve(f"Tail{ti}", [(0.02, 0.02, 0.14), (0.16 + ti * 0.10, 0.08, -0.10), (0.28 + ti * 0.11, 0.12, -0.32)], [0.044, 0.030, 0.010], P["amber"])
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.36), dist=2.55, elev_deg=14, yaw_deg=12)


def scene_spec_midas(P):
    # Tipped ironbound coffer spilling minted Florins across crooked stone shelf
    add_box("ChestBody", (0.64, 0.44, 0.34), P["oak"], loc=(-0.14, 0.06, 0.04), rot=(12, -14, -22), bevel_amt=0.02)
    add_cyl("ChestLid", 0.22, 0.22, 0.64, P["dark_wood"], loc=(-0.22, 0.24, 0.36), rot=(32, 76, -22), segs=14)
    for bx in [-0.30, -0.14, 0.02]:
        add_box(f"Band{bx}", (0.045, 0.47, 0.37), P["iron"], loc=(bx, 0.06, 0.04), rot=(12, -14, -22), bevel_amt=0.008)
    # Cascading heap of golden Florin coins spilling out right & forward
    rng = random.Random(77)
    for ci in range(22):
        cx = -0.02 + ci * 0.028 + rng.uniform(-0.08, 0.08)
        cy = -0.18 + rng.uniform(-0.14, 0.12)
        cz = max(-0.26, 0.22 - ci * 0.022 + rng.uniform(-0.04, 0.04))
        add_cyl(f"Coin{ci}", 0.068, 0.068, 0.022, P["gold"], loc=(cx, cy, cz), rot=(rng.uniform(-35, 35), rng.uniform(-35, 35), rng.uniform(0, 180)), segs=14)
    # Tilted brass Crown atop gold pile
    add_torus("MidasRing", 0.19, 0.036, P["gold"], loc=(0.14, -0.04, 0.44), rot=(68, -22, 16))
    for k in range(5):
        a = k * math.tau / 5.0
        add_cyl(f"Spike{k}", 0.032, 0.006, 0.14, P["gold"], loc=(0.14 + math.cos(a) * 0.17, -0.04 + math.sin(a) * 0.17, 0.56), rot=(-18, -22, 0), segs=6)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.18), dist=2.25, elev_deg=24, yaw_deg=16)


def scene_spec_chronos(P):
    # Tilted turned-wood hourglass entwined by gnarled vine + broken iron clock gear + curved sickle
    rot_hg = (10, 16, -12)
    add_lathe("GlassSand", [
        (0.01, -0.44), (0.28, -0.44), (0.30, -0.26), (0.04, 0.0), (0.30, 0.26), (0.28, 0.44), (0.01, 0.44)
    ], P["glass"], rot=rot_hg, loc=(0.0, 0.0, 0.36))
    add_lathe("SandHeap", [(0.01, -0.42), (0.25, -0.42), (0.16, -0.32), (0.01, -0.22)], P["amber"], rot=rot_hg, loc=(0.0, 0.0, 0.36))
    add_cyl("CapBot", 0.38, 0.38, 0.06, P["dark_wood"], loc=(0.14, -0.06, -0.10), rot=rot_hg, segs=18)
    add_cyl("CapTop", 0.38, 0.38, 0.06, P["dark_wood"], loc=(-0.10, 0.04, 0.84), rot=rot_hg, segs=18)
    for ang in [25, 145, 265]:
        r = math.radians(ang)
        add_cyl(f"Pillar{ang}", 0.028, 0.028, 0.94, P["brass"], loc=(math.cos(r) * 0.32, math.sin(r) * 0.32, 0.37), rot=rot_hg, segs=10)
    # Jagged clock cog wheel leaning left
    add_torus("GearRim", 0.28, 0.036, P["iron"], loc=(-0.30, 0.16, 0.12), rot=(74, 24, 30), maj_seg=24)
    for ti in range(10):
        a = ti * math.tau / 10.0
        add_box(f"Tooth{ti}", (0.06, 0.06, 0.05), P["iron"], loc=(-0.30 + math.cos(a) * 0.31, 0.16, 0.12 + math.sin(a) * 0.31), bevel_amt=0.005)
    # Curved crescent sickle behind right
    sk_pts = [(0.18, 0.10, -0.14), (0.44, 0.04, 0.30), (0.42, 0.0, 0.72), (0.12, -0.04, 0.96)]
    add_tube_curve("Sickle", sk_pts, [0.025, 0.045, 0.038, 0.012], P["steel"])
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.36), dist=2.45, elev_deg=14, yaw_deg=12)


def scene_spec_jester(P):
    # Leaning fool's horned bauble cap & belled marotte scepter tumbling across skewed cards
    add_cyl("MarotteStaff", 0.034, 0.042, 1.05, P["oak"], loc=(-0.14, 0.0, 0.26), rot=(8, -22, 0), segs=10)
    add_sphere("FoolHead", 0.16, P["gold"], loc=(0.06, -0.02, 0.72), scale=(1.0, 0.92, 1.15))
    # Two asymmetrical floppy jester horns with brass bells!
    h1 = [(0.02, 0.0, 0.84), (-0.20, -0.04, 1.06), (-0.42, 0.0, 0.92)]
    h2 = [(0.12, 0.0, 0.84), (0.36, 0.04, 1.04), (0.48, -0.04, 0.74)]
    add_tube_curve("HornL", h1, [0.085, 0.055, 0.022], P["crimson"])
    add_tube_curve("HornR", h2, [0.085, 0.055, 0.022], P["lapis"])
    add_sphere("BellL", 0.065, P["gold"], loc=h1[-1])
    add_sphere("BellR", 0.065, P["gold"], loc=h2[-1])
    # Skewed tumbling playing cards near lower rim
    for ci, (cx, cy, cz, rz) in enumerate([(-0.28, -0.10, -0.14, -22), (0.04, -0.14, -0.20, 14), (0.32, -0.08, -0.12, 34)]):
        add_box(f"Card{ci}", (0.26, 0.02, 0.38), P["parchment"], loc=(cx, cy, cz), rot=(62, rz, -12), bevel_amt=0.008)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.38), dist=2.35, elev_deg=15, yaw_deg=12)


def scene_spec_hex(P):
    # Tilted burlap voodoo effigy bound in rope & pierced asymmetrically by 3 steel needles over crooked wheel
    add_torus("HexWheel", 0.46, 0.032, P["dark_wood"], loc=(0.06, 0.16, 0.34), rot=(78, 12, -16))
    for si in range(5):
        a = si * math.tau / 5.0 + 0.2
        add_cyl(f"HexSpoke{si}", 0.016, 0.016, 0.90, P["dark_wood"], loc=(0.06, 0.16, 0.34), rot=(0, math.degrees(a), 0), segs=6)
    doll_rot = (8, -18, 10)
    add_sphere("DollHead", 0.19, P["burlap"], loc=(-0.10, -0.04, 0.72), rot=doll_rot, scale=(0.92, 0.85, 1.05))
    add_sphere("DollTorso", 0.20, P["burlap"], loc=(-0.02, -0.02, 0.34), rot=doll_rot, scale=(0.88, 0.65, 1.35))
    for sx in (-1, 1):
        add_cyl(f"Arm{sx}", 0.065, 0.055, 0.38, P["burlap"], loc=(-0.04 + sx * 0.24, -0.02, 0.44 + sx * 0.05), rot=(0, sx * 55, 0))
        add_cyl(f"Leg{sx}", 0.072, 0.055, 0.42, P["burlap"], loc=(0.02 + sx * 0.12, -0.02, -0.02), rot=(0, sx * 14, 0))
    # Rope coils + 3 long steel sewing needles piercing at odd angles
    for zi in [0.24, 0.34, 0.42]:
        add_torus(f"Cord{zi}", 0.16, 0.022, P["rope"], loc=(-0.02, -0.02, zi), rot=(12, -18, 0))
    for np_loc, np_rot in [((-0.02, -0.04, 0.42), (18, 62, 12)), ((0.06, -0.04, 0.24), (24, -54, -18)), ((-0.12, -0.06, 0.68), (44, 48, 22))]:
        add_cyl(f"Needle{np_loc[2]}", 0.024, 0.004, 0.82, P["steel"], loc=np_loc, rot=np_rot, segs=8)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.36), dist=2.35, elev_deg=12, yaw_deg=14)


def scene_spec_magnet(P):
    # Weathered horseshoe lodestone angled diagonally pulling bent iron nails, key & gold coin midair
    hs_pts = []
    for i in range(17):
        a = math.radians(-10 + (i / 16.0) * 200.0)
        if i <= 3:
            hs_pts.append((0.28, 0.0, 0.08 + i * 0.10))
        elif i >= 13:
            hs_pts.append((-0.28, 0.0, 0.38 - (i - 13) * 0.10))
        else:
            ang = math.radians(((i - 3) / 10.0) * 180.0)
            hs_pts.append((math.cos(ang) * 0.28, 0.0, 0.38 + math.sin(ang) * 0.32))
    mag = add_tube_curve("Lodestone", hs_pts, [0.10] * len(hs_pts), P["crimson"], loc=(-0.12, 0.0, 0.36), rot=(14, -28, 12))
    # Iron silver tips
    add_box("TipL", (0.21, 0.21, 0.12), P["steel"], loc=(-0.38, 0.04, 0.16), rot=(14, -28, 12))
    add_box("TipR", (0.21, 0.21, 0.12), P["steel"], loc=(0.12, -0.02, -0.02), rot=(14, -28, 12))
    # Pulled iron nails, skeleton key, and spinning gold Florins leaping up toward poles!
    for idx, (nx, ny, nz, rx, ry) in enumerate([(-0.14, -0.14, -0.12, 35, 18), (0.34, -0.10, 0.06, -48, 22), (0.22, 0.08, -0.24, 62, -15), (-0.30, -0.08, -0.28, 14, -42)]):
        add_cyl(f"Nail{idx}", 0.022, 0.004, 0.26, P["iron"], loc=(nx, ny, nz), rot=(rx, ry, idx * 25), segs=6)
    add_torus("KeyBow", 0.09, 0.022, P["brass"], loc=(0.36, -0.06, 0.32), rot=(68, 22, 35))
    add_cyl("KeyStem", 0.020, 0.020, 0.30, P["brass"], loc=(0.24, -0.04, 0.24), rot=(48, 42, 0), segs=8)
    add_cyl("PullCoin", 0.085, 0.085, 0.025, P["gold"], loc=(-0.02, -0.12, -0.32), rot=(42, -32, 18), segs=16)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.24), dist=2.25, elev_deg=14, yaw_deg=14)


def scene_spec_shield(P):
    # Battle-dented oak/iron heater shield propped crookedly on split stone beside diagonal halberd
    add_box("Boulder", (0.88, 0.60, 0.26), P["stone"], loc=(0.0, 0.06, -0.24), rot=(4, -6, 12), bevel_amt=0.04)
    # Crossed wooden-and-steel halberd angled behind shield
    add_cyl("HalberdPole", 0.028, 0.028, 1.38, P["dark_wood"], loc=(0.24, 0.14, 0.38), rot=(8, -28, 0), segs=10)
    add_box("HalberdBlade", (0.22, 0.025, 0.32), P["steel"], loc=(-0.04, 0.12, 0.90), rot=(8, -28, 0), bevel_amt=0.008)
    # Tilted heater shield body + riveted iron rim straps + embossed umbo boss
    sh_pts = [(-0.34, 0.62), (0.34, 0.62), (0.36, 0.18), (0.24, -0.22), (0.0, -0.46), (-0.24, -0.22), (-0.36, 0.18)]
    bm = bmesh.new()
    v_top = [bm.verts.new((x * 0.95, -0.03 - abs(x) * 0.16, z)) for (x, z) in sh_pts]
    v_bot = [bm.verts.new((x * 0.95, 0.05 - abs(x) * 0.16, z)) for (x, z) in sh_pts]
    bm.faces.new(v_top)
    bm.faces.new(v_bot[::-1])
    for i in range(len(sh_pts)):
        ni = (i + 1) % len(sh_pts)
        bm.faces.new((v_top[i], v_bot[i], v_bot[ni], v_top[ni]))
    add_bm_obj("HeaterShield", bm, P["oak"], loc=(-0.04, -0.02, 0.28), rot=(12, 16, -8), smooth=False, bevel_amt=0.015)
    add_sphere("ShieldBoss", 0.14, P["iron"], loc=(-0.04, -0.08, 0.34), rot=(12, 16, -8), scale=(1.0, 0.65, 1.0))
    add_box("CrossStrap", (0.64, 0.06, 0.075), P["iron"], loc=(-0.02, -0.05, 0.54), rot=(12, 16, -8), bevel_amt=0.008)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.32), dist=2.35, elev_deg=12, yaw_deg=12)


def scene_spec_gambler(P):
    # Corner of scarred oak tavern table with pinned dagger & 3 bone dice mid-tumble in air
    add_box("TableSlab", (1.05, 0.72, 0.14), P["oak"], loc=(-0.06, 0.10, -0.24), rot=(18, -14, 24), bevel_amt=0.02)
    # Pinned dagger jammed obliquely into table corner
    add_cyl("DagBlade", 0.042, 0.008, 0.42, P["steel"], loc=(-0.34, -0.02, 0.06), rot=(14, -24, 0), segs=4)
    add_box("DagGuard", (0.20, 0.04, 0.03), P["brass"], loc=(-0.42, -0.04, 0.26), rot=(14, -24, 0), bevel_amt=0.008)
    add_cyl("DagGrip", 0.026, 0.022, 0.18, P["leather"], loc=(-0.46, -0.05, 0.36), rot=(14, -24, 0), segs=10)
    # Three beveled bone dice tumbling above table at vivid asymmetric angles
    for idx, (dx, dy, dz, rx, ry, rz) in enumerate([
        (-0.16, -0.10, 0.56, 28, -36, 18),
        (0.24, -0.04, 0.36, -42, 24, 48),
        (0.06, 0.06, 0.88, 16, 48, -28),
    ]):
        add_box(f"Die{idx}", (0.24, 0.24, 0.24), P["bone"], loc=(dx, dy, dz), rot=(rx, ry, rz), bevel_amt=0.035)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.28), dist=2.35, elev_deg=16, yaw_deg=14)


def scene_spec_plague(P):
    # Hanging iron plague lantern on gnarled wooden crook + mortar, pestle & drooping nightshade branch
    crook = [(-0.42, 0.12, -0.32), (-0.44, 0.10, 0.34), (-0.36, 0.08, 0.88), (-0.06, 0.04, 1.06), (0.22, 0.0, 0.94)]
    add_tube_curve("GnarledCrook", crook, [0.065, 0.052, 0.042, 0.034, 0.022], P["dark_wood"])
    # Hanging iron cage lantern swinging off-vertical
    lrot = (4, 10, -8)
    add_cyl("LanternCap", 0.22, 0.04, 0.18, P["iron"], loc=(0.24, 0.0, 0.72), rot=lrot, segs=6)
    add_cyl("LanternGlass", 0.14, 0.11, 0.28, P["amber"], loc=(0.24, 0.0, 0.52), rot=lrot, segs=6)
    add_cyl("LanternBase", 0.14, 0.18, 0.06, P["iron"], loc=(0.24, 0.0, 0.36), rot=lrot, segs=6)
    for k in range(4):
        a = k * math.tau / 4.0
        add_cyl(f"CageRib{k}", 0.014, 0.014, 0.30, P["iron"], loc=(0.24 + math.cos(a) * 0.15, math.sin(a) * 0.15, 0.52), rot=lrot, segs=6)
    # Stone mortar + tilted pestle below left
    add_lathe("Mortar", [(0.01, -0.32), (0.18, -0.32), (0.24, -0.14), (0.26, 0.0), (0.20, 0.0), (0.14, -0.22), (0.01, -0.22)], P["stone"], loc=(-0.12, -0.06, 0.04))
    add_cyl("Pestle", 0.052, 0.034, 0.34, P["stone"], loc=(-0.02, -0.06, 0.06), rot=(18, 34, 0), segs=12)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.36), dist=2.45, elev_deg=14, yaw_deg=12)


def scene_spec_crown(P):
    # Jeweled Bohemian royal crown resting askew atop draped ermine/crimson folds + diagonal scepter
    add_sphere("CloakFold1", 0.42, P["crimson"], loc=(-0.08, 0.06, -0.08), scale=(1.3, 0.9, 0.45))
    add_sphere("ErmineTrim", 0.32, P["parchment"], loc=(0.14, -0.08, -0.16), scale=(1.2, 0.75, 0.35))
    # Tilted diagonal royal scepter with orb finial
    add_cyl("Scepter", 0.026, 0.020, 1.15, P["brass"], loc=(0.06, 0.10, 0.24), rot=(12, 48, 0), segs=12)
    add_sphere("ScepterOrb", 0.085, P["gold"], loc=(0.48, 0.02, 0.62))
    # Grand Crown tilted asymmetrically!
    c_rot = (14, -15, 18)
    add_lathe("CrownBand", [
        (0.28, -0.02), (0.31, 0.02), (0.33, 0.22), (0.29, 0.24), (0.26, 0.02)
    ], P["gold"], loc=(-0.02, -0.04, 0.32), rot=c_rot)
    add_sphere("CrownCap", 0.26, P["crimson"], loc=(-0.04, -0.05, 0.48), rot=c_rot, scale=(1.0, 1.0, 0.75))
    # Arches + fleur-de-lis spires + cross finial
    add_torus("Arch1", 0.27, 0.024, P["gold"], loc=(-0.04, -0.05, 0.48), rot=(90 + 14, -15, 18))
    add_torus("Arch2", 0.27, 0.024, P["gold"], loc=(-0.04, -0.05, 0.48), rot=(90 + 14, -15, 108))
    add_box("CrossV", (0.04, 0.04, 0.16), P["gold"], loc=(-0.10, -0.10, 0.80), rot=c_rot, bevel_amt=0.005)
    add_box("CrossH", (0.12, 0.04, 0.04), P["gold"], loc=(-0.10, -0.10, 0.82), rot=c_rot, bevel_amt=0.005)
    for k in range(6):
        a = k * math.tau / 6.0
        col_g = P["ruby"] if k % 2 == 0 else P["emerald"]
        add_sphere(f"Jewel{k}", 0.042, col_g, loc=(-0.02 + math.cos(a) * 0.31, -0.04 + math.sin(a) * 0.31, 0.42))
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.28), dist=2.30, elev_deg=18, yaw_deg=14)


def scene_spec_prism(P):
    # Faceted crystal triangular prism floating off-center inside tilted brass armillary sphere + ray wedges
    add_lathe("ArmBase", [(0.01, -0.34), (0.30, -0.34), (0.24, -0.26), (0.07, -0.16), (0.05, -0.04)], P["dark_wood"], loc=(-0.06, 0.0, -0.10))
    for rx, ry, rz, r, mat in [(74, 18, -14, 0.46, P["brass"]), (52, -32, 24, 0.38, P["gold"]), (84, -8, 48, 0.31, P["brass"])]:
        add_torus(f"ArmRing{r}", r, 0.024, mat, loc=(0.0, 0.0, 0.38), rot=(rx, ry, rz), maj_seg=32)
    # Sculpted crystal triangular prism off-center!
    add_cyl("CrystalPrism", 0.22, 0.22, 0.46, P["cyan_glow"], loc=(-0.02, -0.04, 0.40), rot=(22, -26, 38), segs=3)
    # Refracted shard beams shooting lower-right & upper-left
    add_cyl("BeamR", 0.10, 0.02, 0.64, P["amber"], loc=(0.36, -0.06, 0.24), rot=(10, 70, -14), segs=6)
    add_cyl("BeamL", 0.07, 0.02, 0.50, P["cyan_glow"], loc=(-0.38, 0.04, 0.56), rot=(-12, 68, -16), segs=6)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.32), dist=2.35, elev_deg=14, yaw_deg=14)


# =============================================================================
# 5 BLENDER 3D HERALDIC RELIEFS FOR DECK BACK CENTERPIECES
# =============================================================================

def scene_deck_klasic(P):
    # Turned wooden/pewter tavern tankard with foaming rim + crossed oak twigs & two detailed acorns
    add_lathe("Tankard", [
        (0.01, -0.28), (0.32, -0.28), (0.30, -0.22), (0.26, 0.16), (0.28, 0.24),
        (0.24, 0.26), (0.21, 0.18), (0.01, 0.18)
    ], P["oak"], rot=(4, -8, 6))
    for hz in [-0.14, 0.12]:
        add_torus(f"Hoop{hz}", 0.28, 0.024, P["iron"], loc=(0, 0, hz), rot=(4, -8, 6))
    h_pts = [(0.26, 0.0, 0.16), (0.44, 0.0, 0.14), (0.45, 0.0, -0.14), (0.27, 0.0, -0.18)]
    add_tube_curve("Handle", h_pts, [0.042] * 4, P["brass"])
    add_sphere("Foam", 0.24, P["bone"], loc=(-0.02, -0.02, 0.28), scale=(1.08, 1.0, 0.62))
    # Pair of sculpted oak acorns flanking base asymmetrically
    for sx, ax, az, r_y in [(-1, -0.44, -0.16, -26), (1, 0.42, -0.18, 28)]:
        add_sphere(f"AcornNut{sx}", 0.11, P["gold"], loc=(ax, -0.08, az), rot=(0, r_y, 0), scale=(0.82, 0.82, 1.25))
        add_sphere(f"AcornCap{sx}", 0.12, P["dark_wood"], loc=(ax - sx * 0.03, -0.08, az + 0.08), rot=(0, r_y, 0), scale=(1.05, 1.05, 0.62))
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.04), dist=2.25, elev_deg=18, yaw_deg=12)


def scene_deck_antika(P):
    # Solar-winged lapis Scarab beetle pushing sun-disc above carved Eye of Horus shrine
    add_sphere("SunDisc", 0.22, P["gold"], loc=(0.0, -0.04, 0.46), scale=(1.0, 0.45, 1.0))
    add_sphere("ScarabBody", 0.20, P["lapis"], loc=(0.0, -0.02, 0.12), scale=(0.86, 0.55, 1.15))
    for side in (-1, 1):
        for r_i, mat in enumerate([P["gold"], P["emerald"], P["crimson"]]):
            pts = [(side * 0.14, 0.0, 0.18 - r_i * 0.05), (side * (0.48 - r_i * 0.06), 0.02, 0.28 - r_i * 0.08), (side * (0.68 - r_i * 0.10), 0.04, 0.20 - r_i * 0.09)]
            add_tube_curve(f"SWing{side}{r_i}", pts, [0.055, 0.046, 0.020], mat)
    add_sphere("EyeWhite", 0.22, P["bone"], loc=(0.0, -0.04, -0.30), scale=(1.25, 0.45, 0.68))
    add_sphere("EyePupil", 0.09, P["iron"], loc=(0.0, -0.11, -0.30), scale=(1.0, 0.4, 1.0))
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.06), dist=2.35, elev_deg=12, yaw_deg=10)


def scene_deck_rim(P):
    # Roman hammered bronze scutum boss (umbo) + diagonal winged thunderbolts + perched Aquila eagle
    add_cyl("BossRim", 0.44, 0.48, 0.06, P["brass"], loc=(0, 0.04, 0), rot=(90, 0, 0), segs=28)
    add_sphere("UmboDome", 0.26, P["gold"], loc=(0, -0.02, 0), scale=(1.0, 0.55, 1.0))
    for (sx, sy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        pts = [(sx * 0.16, 0.0, sy * 0.16), (sx * 0.36, -0.02, sy * 0.42), (sx * 0.26, -0.02, sy * 0.48), (sx * 0.58, -0.04, sy * 0.72)]
        add_tube_curve(f"Fulmen{sx}{sy}", pts, [0.045, 0.036, 0.030, 0.012], P["amber"], segs=6)
    # Perched Aquila silhouette centered above boss
    add_sphere("EagleTorso", 0.12, P["gold"], loc=(0, -0.10, 0.06), scale=(0.8, 0.6, 1.5))
    add_sphere("EagleHead", 0.08, P["gold"], loc=(-0.03, -0.12, 0.24), rot=(0, -18, 0), scale=(1.1, 0.8, 0.9))
    for sx in (-1, 1):
        add_tube_curve(f"AqW{sx}", [(sx * 0.06, -0.08, 0.14), (sx * 0.34, -0.04, 0.32), (sx * 0.54, 0.0, 0.22)], [0.065, 0.052, 0.018], P["brass"])
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.04), dist=2.35, elev_deg=10, yaw_deg=10)


def scene_deck_stredovek(P):
    # Gothic cathedral rose wheel + crossed halberds + jeweled St. Wenceslas crown
    add_torus("RoseOuter", 0.52, 0.04, P["iron"], loc=(0, 0.10, 0.02), rot=(90, 0, 0))
    for si in range(8):
        a = si * math.tau / 8.0
        add_cyl(f"RoseSpoke{si}", 0.016, 0.016, 1.00, P["iron"], loc=(0, 0.10, 0.02), rot=(0, math.degrees(a), 0), segs=6)
    for sx in (-1, 1):
        add_cyl(f"HalbShaft{sx}", 0.026, 0.026, 1.38, P["dark_wood"], loc=(0, 0.02, 0.06), rot=(0, sx * 28, 0), segs=8)
        add_box(f"HalbHead{sx}", (0.24, 0.025, 0.32), P["steel"], loc=(sx * 0.34, 0.02, 0.58), rot=(0, sx * 28, 0), bevel_amt=0.008)
    add_lathe("WencBand", [(0.26, -0.10), (0.30, -0.06), (0.31, 0.14), (0.27, 0.16)], P["gold"], loc=(0, -0.06, 0.02), rot=(8, -6, 0))
    add_sphere("WencCap", 0.25, P["crimson"], loc=(0, -0.06, 0.12), scale=(1.0, 1.0, 0.7))
    add_box("WencCrossV", (0.04, 0.04, 0.16), P["gold"], loc=(0, -0.06, 0.36), bevel_amt=0.005)
    add_box("WencCrossH", (0.12, 0.04, 0.04), P["gold"], loc=(0, -0.06, 0.38), bevel_amt=0.005)
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.12), dist=2.35, elev_deg=12, yaw_deg=12)


def scene_deck_objavy(P):
    # Full-rigged medieval Caravel galleon leaning into waves beside 16-pt brass compass rose & iron anchor
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.42)
    for v in bm.verts:
        if v.co.z > 0.06:
            v.co.z = 0.06
        v.co.y *= 0.48
        v.co.x *= 1.15
    add_bm_obj("ShipHull", bm, P["oak"], loc=(0.10, 0.0, -0.08), rot=(8, -10, -8), smooth=True)
    add_cyl("MastMain", 0.026, 0.018, 0.88, P["dark_wood"], loc=(0.12, 0.0, 0.32), rot=(8, -10, -8), segs=10)
    # Billowing canvas main sail (curved outward along -Y)
    s_bm = bmesh.new()
    gx, gz = 6, 6
    verts_grid = []
    for iz in range(gz + 1):
        row = []
        tz = iz / gz
        for ix in range(gx + 1):
            tx = ix / gx
            px = (tx - 0.5) * 0.44
            pz = tz * 0.50
            py = -0.14 * math.sin(tx * math.pi) * math.sin(tz * math.pi)
            row.append(s_bm.verts.new((px, py, pz)))
        verts_grid.append(row)
    for iz in range(gz):
        for ix in range(gx):
            s_bm.faces.new((verts_grid[iz][ix], verts_grid[iz][ix + 1], verts_grid[iz + 1][ix + 1], verts_grid[iz + 1][ix]))
    add_bm_obj("BillowSail", s_bm, P["bone"], loc=(0.10, -0.04, 0.14), rot=(8, -10, -8), smooth=True)
    # Brass Compass Rose off-center upper-left & Anchor lower-left
    add_torus("CompassRim", 0.26, 0.022, P["brass"], loc=(-0.34, 0.14, 0.46), rot=(82, 8, -12))
    for pi in range(8):
        a = pi * math.tau / 8.0
        add_cyl(f"CompPt{pi}", 0.036, 0.004, 0.28 if pi % 2 == 0 else 0.18, P["gold"] if pi % 2 == 0 else P["crimson"], loc=(-0.34 + math.cos(a) * 0.14, 0.14, 0.46 + math.sin(a) * 0.14), rot=(0, 90 - math.degrees(a), 0), segs=4)
    # Forged Anchor resting foreground left
    add_cyl("AnchShank", 0.024, 0.020, 0.52, P["iron"], loc=(-0.32, -0.14, -0.22), rot=(14, -22, 18), segs=8)
    add_tube_curve("AnchFluke", [(-0.46, -0.14, -0.34), (-0.30, -0.14, -0.46), (-0.12, -0.14, -0.36)], [0.026, 0.036, 0.026], P["iron"])
    frame_camera(bpy.context.scene.camera, target=(0.0, 0.0, 0.14), dist=2.35, elev_deg=15, yaw_deg=14)


BUILDERS = {
    "SPEC_VAMPIRE": scene_spec_vampire,
    "SPEC_STORM": scene_spec_storm,
    "SPEC_MIRROR": scene_spec_mirror,
    "SPEC_ALCHEMIST": scene_spec_alchemist,
    "SPEC_ORACLE": scene_spec_oracle,
    "SPEC_PHOENIX": scene_spec_phoenix,
    "SPEC_MIDAS": scene_spec_midas,
    "SPEC_CHRONOS": scene_spec_chronos,
    "SPEC_JESTER": scene_spec_jester,
    "SPEC_HEX": scene_spec_hex,
    "SPEC_MAGNET": scene_spec_magnet,
    "SPEC_SHIELD": scene_spec_shield,
    "SPEC_GAMBLER": scene_spec_gambler,
    "SPEC_PLAGUE": scene_spec_plague,
    "SPEC_CROWN": scene_spec_crown,
    "SPEC_PRISM": scene_spec_prism,
    "DECK_klasic": scene_deck_klasic,
    "DECK_antika": scene_deck_antika,
    "DECK_rim": scene_deck_rim,
    "DECK_stredovek": scene_deck_stredovek,
    "DECK_objavy": scene_deck_objavy,
}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for key, fn in BUILDERS.items():
        scene = clear_scene()
        P = palette()
        fn(P)
        out_path = str(OUT_DIR / f"{key}.png")
        scene.render.filepath = out_path
        bpy.ops.render.render(write_still=True)
        print(f"RENDERED_WOODCUT={key} -> {out_path}")


if __name__ == "__main__":
    main()
