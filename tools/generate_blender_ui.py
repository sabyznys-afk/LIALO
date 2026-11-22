"""
Blender 5.3.0 Headless 3D Sculpted HUD & Wager Asset Generator for LIALO.
Generates cohesive dark-fantasy medieval sculpted 3D UI plaques and hero icons
into D:/downpour-godot/assets/ui/blender/*.png and saves lialo_hud_assets.blend.

Run:
  "D:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --factory-startup --python "D:\downpour-godot\tools\generate_blender_ui.py"
"""

import math
import os
import pathlib
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_DIR = ROOT / "assets" / "ui" / "blender"
BLEND_DIR = ROOT / "tools" / "blender_ui"
OUT_DIR.mkdir(parents=True, exist_ok=True)
BLEND_DIR.mkdir(parents=True, exist_ok=True)
(BLEND_DIR / ".gdignore").touch()


# ---------------------------------------------------------------------------
# Scene & Studio Setup (Blender 5.3.0 BLENDER_EEVEE)
# ---------------------------------------------------------------------------

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    ee = scene.eevee
    ee.taa_render_samples = 64
    ee.use_raytracing = True
    ee.use_shadows = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    for vt in ("AgX", "Filmic", "Standard"):
        try:
            scene.view_settings.view_transform = vt
            break
        except Exception:
            pass
    try:
        scene.view_settings.look = "Medium High Contrast"
    except Exception:
        pass
    scene.view_settings.exposure = -0.85
    scene.view_settings.gamma = 1.22
    setup_studio_world(scene)
    return scene


def setup_studio_world(scene):
    world = bpy.data.worlds.new("LialoStudioWorld")
    scene.world = world
    if world.node_tree is None:
        world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = 0.75

    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tex_coord.outputs["Generated"], sep.inputs["Vector"])

    # Dark moody tavern studio dome with two crisp reflection strips for rich metal gleam
    ramp_z = nt.nodes.new("ShaderNodeValToRGB")
    ramp_z.color_ramp.elements[0].position = 0.25
    ramp_z.color_ramp.elements[0].color = (0.010, 0.008, 0.014, 1.0)
    ramp_z.color_ramp.elements[1].position = 0.85
    ramp_z.color_ramp.elements[1].color = (0.65, 0.44, 0.16, 1.0)
    mid = ramp_z.color_ramp.elements.new(0.55)
    mid.color = (0.035, 0.032, 0.048, 1.0)
    nt.links.new(sep.outputs["Z"], ramp_z.inputs["Fac"])

    ramp_x = nt.nodes.new("ShaderNodeValToRGB")
    ramp_x.color_ramp.elements[0].position = 0.18
    ramp_x.color_ramp.elements[0].color = (0.48, 0.28, 0.08, 1.0)
    ramp_x.color_ramp.elements[1].position = 0.82
    ramp_x.color_ramp.elements[1].color = (0.10, 0.20, 0.38, 1.0)
    mid_x = ramp_x.color_ramp.elements.new(0.50)
    mid_x.color = (0.015, 0.015, 0.022, 1.0)
    nt.links.new(sep.outputs["X"], ramp_x.inputs["Fac"])

    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "ADD"
    mix.inputs["Factor"].default_value = 0.55
    nt.links.new(ramp_z.outputs["Color"], mix.inputs[6])
    nt.links.new(ramp_x.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])


def ensure_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def link_obj(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def set_collection_visibility(col, visible):
    col.hide_render = not visible
    col.hide_viewport = not visible


def add_three_point_lights(col, center=(0, 0, 0), scale=1.0, ortho_mode=False):
    cx, cy, cz = center
    lights = []

    def make_area(name, loc, target, energy, color, size):
        ldata = bpy.data.lights.new(name=name, type="AREA")
        ldata.energy = energy
        ldata.color = color
        ldata.shape = "RECTANGLE"
        ldata.size = size
        ldata.size_y = size * 0.75
        lobj = bpy.data.objects.new(name, ldata)
        lobj.location = Vector(loc)
        direction = Vector(target) - lobj.location
        lobj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        link_obj(lobj, col)
        lights.append(lobj)
        return lobj

    if ortho_mode:
        # Crisp raking tavern lighting from upper-left to make bevels & reliefs shine
        make_area("KeyLight", (cx - 3.2 * scale, cy + 3.0 * scale, cz + 4.4 * scale), (cx, cy, cz), 185.0 * scale * scale, (1.0, 0.82, 0.56), 3.4 * scale)
        make_area("FillLight", (cx + 3.8 * scale, cy + 1.2 * scale, cz + 4.0 * scale), (cx, cy, cz), 55.0 * scale * scale, (0.48, 0.68, 1.0), 4.6 * scale)
        make_area("RimBottom", (cx + 0.4 * scale, cy - 3.6 * scale, cz + 3.2 * scale), (cx, cy, cz), 42.0 * scale * scale, (1.0, 0.62, 0.28), 3.2 * scale)
    else:
        make_area("KeyLight", (cx - 2.6 * scale, cy - 2.4 * scale, cz + 2.8 * scale), (cx, cy, cz), 115.0 * scale * scale, (1.0, 0.84, 0.58), 2.2 * scale)
        make_area("FillLight", (cx + 2.8 * scale, cy - 1.8 * scale, cz + 1.5 * scale), (cx, cy, cz), 42.0 * scale * scale, (0.45, 0.68, 1.0), 3.0 * scale)
        make_area("RimBack", (cx + 0.8 * scale, cy + 3.0 * scale, cz + 2.2 * scale), (cx, cy, cz), 105.0 * scale * scale, (1.0, 0.70, 0.36), 2.4 * scale)
    return lights


# ---------------------------------------------------------------------------
# Procedural PBR Material Library (Cavity AO + Micro-Grain Bump)
# ---------------------------------------------------------------------------

def _new_pbr_mat(
    name,
    base_color,
    cavity_color,
    metallic=0.0,
    roughness=0.45,
    bump_scale=45.0,
    bump_strength=0.08,
    stretch=(1.0, 1.0, 1.0),
    coat=0.0,
    coat_rough=0.1,
    sheen=0.0,
    emission=None,
    emission_strength=0.0,
    transmission=0.0,
    alpha=1.0,
    specular=0.5,
):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name=name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Specular IOR Level"].default_value = specular
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = coat_rough
    bsdf.inputs["Sheen Weight"].default_value = sheen
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["Alpha"].default_value = alpha
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission[:3], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    # AO cavity darkening
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 8
    ao.inputs["Distance"].default_value = 0.25

    ao_ramp = nt.nodes.new("ShaderNodeValToRGB")
    ao_ramp.color_ramp.elements[0].position = 0.28
    ao_ramp.color_ramp.elements[0].color = (*cavity_color[:3], 1.0)
    ao_ramp.color_ramp.elements[1].position = 0.92
    ao_ramp.color_ramp.elements[1].color = (*base_color[:3], 1.0)
    nt.links.new(ao.outputs["AO"], ao_ramp.inputs["Fac"])

    # Micro procedural noise for organic color + roughness + bump variation
    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = stretch
    nt.links.new(tex_coord.outputs["Object"], mapping.inputs["Vector"])

    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = bump_scale
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.62
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])

    mix_col = nt.nodes.new("ShaderNodeMix")
    mix_col.data_type = "RGBA"
    mix_col.blend_type = "MULTIPLY"
    mix_col.inputs["Factor"].default_value = 0.22
    nt.links.new(ao_ramp.outputs["Color"], mix_col.inputs[6])
    nt.links.new(noise.outputs["Color"], mix_col.inputs[7])
    nt.links.new(mix_col.outputs[2], bsdf.inputs["Base Color"])

    rough_ramp = nt.nodes.new("ShaderNodeValToRGB")
    rough_ramp.color_ramp.elements[0].position = 0.25
    r_lo = max(0.04, roughness - 0.10)
    r_hi = min(0.96, roughness + 0.12)
    rough_ramp.color_ramp.elements[0].color = (r_lo, r_lo, r_lo, 1.0)
    rough_ramp.color_ramp.elements[1].position = 0.80
    rough_ramp.color_ramp.elements[1].color = (r_hi, r_hi, r_hi, 1.0)
    nt.links.new(noise.outputs["Fac"], rough_ramp.inputs["Fac"])
    nt.links.new(rough_ramp.outputs["Color"], bsdf.inputs["Roughness"])

    if bump_strength > 0.001:
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = bump_strength
        bump.inputs["Distance"].default_value = 0.015
        nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def build_materials():
    return {
        "walnut_dark": _new_pbr_mat(
            "mat_walnut_dark", (0.042, 0.020, 0.010), (0.009, 0.004, 0.002),
            metallic=0.0, roughness=0.44, bump_scale=24.0, bump_strength=0.16, stretch=(1.0, 6.0, 1.0), coat=0.18
        ),
        "oak_warm": _new_pbr_mat(
            "mat_oak_warm", (0.095, 0.048, 0.020), (0.020, 0.009, 0.004),
            metallic=0.0, roughness=0.48, bump_scale=20.0, bump_strength=0.18, stretch=(1.0, 5.0, 1.0)
        ),
        "obsidian_slate": _new_pbr_mat(
            "mat_obsidian_slate", (0.014, 0.013, 0.020), (0.004, 0.003, 0.006),
            metallic=0.22, roughness=0.50, bump_scale=52.0, bump_strength=0.10, specular=0.6
        ),
        "iron_forged": _new_pbr_mat(
            "mat_iron_forged", (0.085, 0.090, 0.105), (0.014, 0.015, 0.020),
            metallic=0.92, roughness=0.34, bump_scale=64.0, bump_strength=0.12
        ),
        "brass_antique": _new_pbr_mat(
            "mat_brass_antique", (0.64, 0.42, 0.10), (0.14, 0.075, 0.014),
            metallic=0.96, roughness=0.24, bump_scale=46.0, bump_strength=0.07, coat=0.22
        ),
        "gold_bright": _new_pbr_mat(
            "mat_gold_bright", (0.94, 0.64, 0.12), (0.28, 0.14, 0.018),
            metallic=0.98, roughness=0.16, bump_scale=55.0, bump_strength=0.04, coat=0.32
        ),
        "copper_bronze": _new_pbr_mat(
            "mat_copper_bronze", (0.48, 0.21, 0.08), (0.11, 0.04, 0.015),
            metallic=0.92, roughness=0.28, bump_scale=44.0, bump_strength=0.08
        ),
        "crimson_velvet": _new_pbr_mat(
            "mat_crimson_velvet", (0.14, 0.012, 0.018), (0.032, 0.003, 0.005),
            metallic=0.0, roughness=0.80, bump_scale=110.0, bump_strength=0.12, sheen=0.75
        ),
        "burgundy_metal": _new_pbr_mat(
            "mat_burgundy_metal", (0.16, 0.020, 0.026), (0.04, 0.005, 0.007),
            metallic=0.64, roughness=0.32, bump_scale=48.0, bump_strength=0.08, coat=0.25
        ),
        "ruby_gem": _new_pbr_mat(
            "mat_ruby_gem", (0.45, 0.008, 0.018), (0.10, 0.001, 0.004),
            metallic=0.10, roughness=0.08, bump_scale=30.0, bump_strength=0.01,
            coat=0.95, coat_rough=0.03, emission=(0.55, 0.015, 0.030), emission_strength=0.65, specular=0.95
        ),
        "rival_ruby": _new_pbr_mat(
            "mat_rival_ruby", (0.32, 0.005, 0.025), (0.06, 0.001, 0.005),
            metallic=0.16, roughness=0.12, bump_scale=36.0, bump_strength=0.03,
            coat=0.88, emission=(0.35, 0.01, 0.04), emission_strength=0.45, specular=0.9
        ),
        "sapphire_glow": _new_pbr_mat(
            "mat_sapphire_glow", (0.04, 0.36, 0.92), (0.01, 0.10, 0.32),
            metallic=0.15, roughness=0.08, bump_scale=28.0, bump_strength=0.01,
            coat=0.92, emission=(0.12, 0.58, 1.0), emission_strength=1.75, specular=0.95
        ),
        "amethyst_flame": _new_pbr_mat(
            "mat_amethyst_flame", (0.92, 0.22, 0.85), (0.35, 0.04, 0.55),
            metallic=0.0, roughness=0.10, bump_scale=18.0, bump_strength=0.02,
            coat=0.7, emission=(1.0, 0.34, 0.68), emission_strength=5.2
        ),
        "crystal_glass": _new_pbr_mat(
            "mat_crystal_glass", (0.68, 0.86, 1.0), (0.24, 0.40, 0.56),
            metallic=0.08, roughness=0.05, bump_scale=20.0, bump_strength=0.01,
            coat=1.0, coat_rough=0.02, alpha=0.14, specular=1.0
        ),
        "steel_blade": _new_pbr_mat(
            "mat_steel_blade", (0.48, 0.52, 0.58), (0.14, 0.16, 0.20),
            metallic=0.97, roughness=0.19, bump_scale=85.0, bump_strength=0.05, stretch=(1.0, 9.0, 1.0), coat=0.18
        ),
        "leather_pouch": _new_pbr_mat(
            "mat_leather_pouch", (0.13, 0.060, 0.024), (0.035, 0.015, 0.005),
            metallic=0.0, roughness=0.62, bump_scale=72.0, bump_strength=0.18
        ),
        "wax_seal": _new_pbr_mat(
            "mat_wax_seal", (0.28, 0.012, 0.018), (0.075, 0.003, 0.005),
            metallic=0.0, roughness=0.32, bump_scale=40.0, bump_strength=0.09, coat=0.42
        ),
        "cork_wood": _new_pbr_mat(
            "mat_cork_wood", (0.28, 0.16, 0.07), (0.09, 0.045, 0.018),
            metallic=0.0, roughness=0.84, bump_scale=95.0, bump_strength=0.24
        ),
    }


# ---------------------------------------------------------------------------
# Coordinate & BMesh Geometry Helpers
# ---------------------------------------------------------------------------

def px_to_bu(px, py, W, H):
    return Vector(((px - W * 0.5) / 100.0, (H * 0.5 - py) / 100.0, 0.0))


def _apply_smooth_and_mat(obj, mat, smooth=True):
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def _rounded_rect_pts(w, h, r, segs=8):
    r = min(r, w * 0.45, h * 0.45)
    hw, hh = w * 0.5, h * 0.5
    pts = []
    corners = [
        (hw - r, hh - r, 0.0, math.pi * 0.5),
        (-hw + r, hh - r, math.pi * 0.5, math.pi),
        (-hw + r, -hh + r, math.pi, math.pi * 1.5),
        (hw - r, -hh + r, math.pi * 1.5, math.tau),
    ]
    for cx, cy, a0, a1 in corners:
        for i in range(segs + 1):
            a = a0 + (a1 - a0) * (i / segs)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def make_bevelled_plate(name, col, center_xy, width, height, thickness, radius, bevel_w, mat, z_base=0.0, segs=8):
    mesh = bpy.data.meshes.new(name + "_mesh")
    bm = bmesh.new()
    pts = _rounded_rect_pts(width, height, radius, segs=segs)
    verts = [bm.verts.new((x, y, z_base)) for x, y in pts]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    top_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top_verts, vec=(0, 0, thickness))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel_w > 0.0005:
        top_edges = [e for e in bm.edges if all(v.co.z > z_base + thickness * 0.5 for v in e.verts)]
        bmesh.ops.bevel(bm, geom=top_edges, offset=bevel_w, segments=3, profile=0.5, affect="EDGES", clamp_overlap=True)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = Vector((center_xy[0], center_xy[1], 0.0))
    link_obj(obj, col)
    return _apply_smooth_and_mat(obj, mat, smooth=True)


def make_bevelled_frame(name, col, center_xy, outer_w, outer_h, frame_w, thickness, radius, bevel_w, mat, z_base=0.0, segs=8):
    """Creates a hollow rectangular bevelled frame (molding) cleanly using bridged loops."""
    mesh = bpy.data.meshes.new(name + "_mesh")
    bm = bmesh.new()
    outer_pts = _rounded_rect_pts(outer_w, outer_h, radius, segs=segs)
    inner_pts = _rounded_rect_pts(max(0.05, outer_w - frame_w * 2.0), max(0.05, outer_h - frame_w * 2.0), max(0.01, radius - frame_w * 0.7), segs=segs)

    v_out = [bm.verts.new((x, y, z_base)) for x, y in outer_pts]
    v_in = [bm.verts.new((x, y, z_base)) for x, y in inner_pts]
    n = len(v_out)
    ring_faces = []
    for i in range(n):
        ni = (i + 1) % n
        ring_faces.append(bm.faces.new([v_out[i], v_out[ni], v_in[ni], v_in[i]]))

    res = bmesh.ops.extrude_face_region(bm, geom=ring_faces)
    top_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top_verts, vec=(0, 0, thickness))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel_w > 0.0005:
        top_edges = [e for e in bm.edges if all(v.co.z > z_base + thickness * 0.5 for v in e.verts)]
        bmesh.ops.bevel(bm, geom=top_edges, offset=bevel_w, segments=3, profile=0.5, affect="EDGES", clamp_overlap=True)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = Vector((center_xy[0], center_xy[1], 0.0))
    link_obj(obj, col)
    return _apply_smooth_and_mat(obj, mat, smooth=True)


def make_torus_ring(name, col, center, major_r, minor_r, mat, maj_seg=48, min_seg=16, rot_euler=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name + "_mesh")
    bm = bmesh.new()
    rings = []
    for i in range(maj_seg):
        theta = (i / maj_seg) * math.tau
        ct, st = math.cos(theta), math.sin(theta)
        ring = []
        for j in range(min_seg):
            phi = (j / min_seg) * math.tau
            r = major_r + minor_r * math.cos(phi)
            z = minor_r * math.sin(phi)
            ring.append(bm.verts.new((r * ct, r * st, z)))
        rings.append(ring)
    for i in range(maj_seg):
        ni = (i + 1) % maj_seg
        for j in range(min_seg):
            nj = (j + 1) % min_seg
            bm.faces.new([rings[i][j], rings[ni][j], rings[ni][nj], rings[i][nj]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = Vector(center)
    obj.rotation_euler = Euler(rot_euler)
    link_obj(obj, col)
    return _apply_smooth_and_mat(obj, mat, smooth=True)


def make_disc_well(name, col, center_xy, radius, height, mat_well, mat_rim, rim_w, z_base=0.0):
    objs = []
    mesh = bpy.data.meshes.new(name + "_disc")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=48, radius1=radius, radius2=radius, depth=height)
    bm.to_mesh(mesh)
    bm.free()
    disc = bpy.data.objects.new(name + "_well", mesh)
    disc.location = Vector((center_xy[0], center_xy[1], z_base + height * 0.5))
    link_obj(disc, col)
    _apply_smooth_and_mat(disc, mat_well, smooth=True)
    objs.append(disc)
    if mat_rim is not None and rim_w > 0.001:
        ring = make_torus_ring(name + "_rim", col, (center_xy[0], center_xy[1], z_base + height + rim_w * 0.35), radius + rim_w * 0.3, rim_w, mat_rim, maj_seg=56, min_seg=18)
        objs.append(ring)
    return objs


def make_rivet(name, col, loc, radius, mat, height_scale=0.65):
    mesh = bpy.data.meshes.new(name + "_mesh")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=radius)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = Vector(loc)
    obj.scale = Vector((1.0, 1.0, height_scale))
    link_obj(obj, col)
    return _apply_smooth_and_mat(obj, mat, smooth=True)


def make_corner_brackets(prefix, col, cx, cy, w, h, z_top, br_len, br_thick, mat_metal, mat_rivet):
    hw, hh = w * 0.5, h * 0.5
    signs = [(-1, 1), (1, 1), (-1, -1), (1, -1)]
    for idx, (sx, sy) in enumerate(signs):
        bx = cx + sx * (hw - br_len * 0.45)
        by = cy + sy * (hh - br_thick * 0.45)
        make_bevelled_plate(f"{prefix}_bh_{idx}", col, (bx, by), br_len, br_thick, br_thick * 0.55, br_thick * 0.25, 0.008, mat_metal, z_base=z_top)
        bx2 = cx + sx * (hw - br_thick * 0.45)
        by2 = cy + sy * (hh - br_len * 0.45)
        make_bevelled_plate(f"{prefix}_bv_{idx}", col, (bx2, by2), br_thick, br_len, br_thick * 0.55, br_thick * 0.25, 0.008, mat_metal, z_base=z_top)
        make_rivet(f"{prefix}_riv_{idx}", col, (cx + sx * (hw - br_thick * 0.55), cy + sy * (hh - br_thick * 0.55), z_top + br_thick * 0.55), br_thick * 0.36, mat_rivet)


def setup_ortho_camera(col, W, H, name="OrthoCam"):
    cam_data = bpy.data.cameras.new(name)
    cam_data.type = "ORTHO"
    cam_data.sensor_fit = "AUTO"
    cam_data.ortho_scale = max(W, H) / 100.0
    cam_data.clip_start = 0.1
    cam_data.clip_end = 100.0
    cam_obj = bpy.data.objects.new(name, cam_data)
    cam_obj.location = Vector((0.0, 0.0, 10.0))
    cam_obj.rotation_euler = Euler((0.0, 0.0, 0.0))
    link_obj(cam_obj, col)
    return cam_obj


def setup_persp_camera(col, loc, target, lens=60.0, name="PerspCam"):
    cam_data = bpy.data.cameras.new(name)
    cam_data.type = "PERSP"
    cam_data.lens = lens
    cam_data.clip_start = 0.05
    cam_data.clip_end = 100.0
    cam_obj = bpy.data.objects.new(name, cam_data)
    cam_obj.location = Vector(loc)
    direction = Vector(target) - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    link_obj(cam_obj, col)
    return cam_obj


def render_collection(scene, col, cam_obj, out_name, res_x, res_y):
    set_collection_visibility(col, True)
    scene.camera = cam_obj
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUT_DIR / out_name)
    bpy.ops.render.render(write_still=True)
    set_collection_visibility(col, False)


# ---------------------------------------------------------------------------
# 1. Hero Chalice (chalice_3d.png, 512x512)
# ---------------------------------------------------------------------------

def build_chalice(scene, mats):
    col = ensure_collection("01_Chalice")
    add_three_point_lights(col, center=(0, 0, 0.65), scale=0.85, ortho_mode=False)

    # Lathed goblet profile (outer silhouette -> inner dark bowl cavity)
    profile = [
        (0.00, 0.00), (0.39, 0.00), (0.40, 0.035), (0.36, 0.07),
        (0.32, 0.11), (0.20, 0.19), (0.11, 0.29), (0.085, 0.39),
        (0.145, 0.48), (0.155, 0.53), (0.145, 0.58), (0.09, 0.66),
        (0.11, 0.76), (0.26, 0.82), (0.41, 0.94), (0.47, 1.12),
        (0.49, 1.32), (0.53, 1.40), (0.535, 1.45), (0.49, 1.46),
        (0.455, 1.43), (0.445, 1.34), (0.42, 1.12), (0.34, 0.95),
        (0.16, 0.87), (0.00, 0.85),
    ]
    mesh = bpy.data.meshes.new("ChaliceBody_mesh")
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=64)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    chalice_body = bpy.data.objects.new("ChaliceBody", mesh)
    link_obj(chalice_body, col)
    _apply_smooth_and_mat(chalice_body, mats["iron_forged"], smooth=True)
    sub = chalice_body.modifiers.new("Subd", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1

    # Gilded Beaded Rings & Rim Collar
    make_torus_ring("ChaliceRimGold", col, (0, 0, 1.425), 0.505, 0.036, mats["gold_bright"], maj_seg=64, min_seg=18)
    make_torus_ring("ChaliceRimSub", col, (0, 0, 1.33), 0.49, 0.022, mats["brass_antique"], maj_seg=64, min_seg=14)
    make_torus_ring("ChaliceBaseRing1", col, (0, 0, 0.045), 0.39, 0.026, mats["brass_antique"], maj_seg=64, min_seg=14)
    make_torus_ring("ChaliceBaseRing2", col, (0, 0, 0.125), 0.305, 0.020, mats["gold_bright"], maj_seg=56, min_seg=14)
    make_torus_ring("ChaliceStemTop", col, (0, 0, 0.76), 0.135, 0.024, mats["gold_bright"], maj_seg=48, min_seg=14)
    make_torus_ring("ChaliceKnopBelt", col, (0, 0, 0.53), 0.158, 0.022, mats["gold_bright"], maj_seg=48, min_seg=14)

    # 8 Ruby Cabochons around central Knop
    for i in range(8):
        ang = i * (math.tau / 8.0)
        rx, ry = math.cos(ang) * 0.165, math.sin(ang) * 0.165
        make_rivet(f"KnopBezel_{i}", col, (rx, ry, 0.53), 0.032, mats["gold_bright"], height_scale=1.0)
        make_rivet(f"KnopRuby_{i}", col, (rx * 1.08, ry * 1.08, 0.53), 0.023, mats["ruby_gem"], height_scale=1.0)

    # 8 Sculpted Gothic Filigree Ribs wrapping the Bowl & Base
    for i in range(8):
        ang = i * (math.tau / 8.0)
        # Foot rib
        rib_b_mesh = bpy.data.meshes.new(f"FootRib_{i}_mesh")
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bm.to_mesh(rib_b_mesh)
        bm.free()
        rb = bpy.data.objects.new(f"FootRib_{i}", rib_b_mesh)
        rb.location = Vector((math.cos(ang) * 0.24, math.sin(ang) * 0.24, 0.16))
        rb.rotation_euler = Euler((0.0, math.radians(-42), ang))
        rb.scale = Vector((0.026, 0.038, 0.26))
        link_obj(rb, col)
        _apply_smooth_and_mat(rb, mats["brass_antique"], smooth=True)

        # Bowl filigree arch rib
        arc_pts = [
            (0.14, 0.80), (0.29, 0.87), (0.43, 0.99), (0.48, 1.18), (0.495, 1.33)
        ]
        for s in range(len(arc_pts) - 1):
            r0, z0 = arc_pts[s]
            r1, z1 = arc_pts[s + 1]
            p0 = Vector((math.cos(ang) * r0, math.sin(ang) * r0, z0))
            p1 = Vector((math.cos(ang) * r1, math.sin(ang) * r1, z1))
            seg_len = (p1 - p0).length
            seg_m = bpy.data.meshes.new(f"BowlRib_{i}_{s}_mesh")
            bm2 = bmesh.new()
            bmesh.ops.create_cone(bm2, cap_ends=True, segments=10, radius1=0.024, radius2=0.020, depth=seg_len * 1.08)
            bm2.to_mesh(seg_m)
            bm2.free()
            so = bpy.data.objects.new(f"BowlRib_{i}_{s}", seg_m)
            so.location = (p0 + p1) * 0.5
            so.rotation_euler = (p1 - p0).to_track_quat("Z", "Y").to_euler()
            link_obj(so, col)
            _apply_smooth_and_mat(so, mats["gold_bright"] if i % 2 == 0 else mats["brass_antique"], smooth=True)

    # Front Solar Medallion Crest & Center Ruby on Chalice Bowl
    crest = make_torus_ring("BowlFrontCrestRing", col, (0, -0.465, 1.12), 0.13, 0.020, mats["gold_bright"], maj_seg=36, min_seg=12, rot_euler=(math.radians(82), 0, 0))
    make_rivet("BowlFrontRuby", col, (0, -0.475, 1.12), 0.072, mats["ruby_gem"], height_scale=0.75)

    # Hero camera slightly above looking into the bowl rim
    cam = setup_persp_camera(col, (0.0, -2.78, 1.72), (0.0, 0.0, 0.74), lens=64.0, name="ChaliceCam")
    render_collection(scene, col, cam, "chalice_3d.png", 512, 512)


# ---------------------------------------------------------------------------
# 2. Score Board (ui_score_board_3d.png, HUD 474x168 -> 948x336)
# ---------------------------------------------------------------------------

def build_score_board(scene, mats):
    W, H = 474.0, 168.0
    col = ensure_collection("02_ScoreBoard")
    add_three_point_lights(col, center=(0, 0, 0), scale=1.4, ortho_mode=True)

    # Base walnut & forged iron slab
    make_bevelled_plate("SB_WoodBase", col, (0, 0), W / 100.0 - 0.04, H / 100.0 - 0.04, 0.14, 0.20, 0.032, mats["walnut_dark"], z_base=0.0, segs=10)
    make_bevelled_frame("SB_OuterBrass", col, (0, 0), W / 100.0 - 0.04, H / 100.0 - 0.04, 0.065, 0.065, 0.20, 0.022, mats["brass_antique"], z_base=0.125, segs=10)
    make_corner_brackets("SB", col, 0, 0, W / 100.0 - 0.04, H / 100.0 - 0.04, 0.175, 0.24, 0.055, mats["iron_forged"], mats["gold_bright"])

    # Left Chalice Sanctuary Well centered at exact pixel (80, 84)
    c_well = px_to_bu(80, 84, W, H)
    make_disc_well("SB_Chalice", col, (c_well.x, c_well.y), 0.58, 0.04, mats["obsidian_slate"], mats["brass_antique"], 0.048, z_base=0.115)
    # 12 raised gold rune studs around chalice bezel (r=0.615)
    for i in range(12):
        ang = i * (math.tau / 12.0)
        make_rivet(f"SB_RuneStud_{i}", col, (c_well.x + math.cos(ang) * 0.615, c_well.y + math.sin(ang) * 0.615, 0.195), 0.022 if i % 3 == 0 else 0.015, mats["gold_bright"])

    # Vertical Carved Brass Divider Pillar at x = 156 (y: 12..156)
    c_div = px_to_bu(156, 84, W, H)
    make_bevelled_plate("SB_Divider", col, (c_div.x, c_div.y), 0.045, 1.44, 0.06, 0.018, 0.014, mats["brass_antique"], z_base=0.13)
    for py in (14, 154):
        p_cap = px_to_bu(156, py, W, H)
        make_rivet(f"SB_DivCap_{py}", col, (p_cap.x, p_cap.y, 0.195), 0.032, mats["gold_bright"])

    # Top Goal Progress Channel: Rect2(164, 34, 298, 12) -> center (313, 40)
    c_bar = px_to_bu(313, 40, W, H)
    make_bevelled_plate("SB_GoalTrough", col, (c_bar.x, c_bar.y), 2.98, 0.125, 0.02, 0.04, 0.008, mats["obsidian_slate"], z_base=0.13)
    make_bevelled_frame("SB_GoalFrame", col, (c_bar.x, c_bar.y), 3.04, 0.165, 0.028, 0.045, 0.05, 0.012, mats["brass_antique"], z_base=0.135)

    # Recessed Equation Ledger Slate: Rect2(162, 52, 302, 106) -> center (313, 105)
    c_led = px_to_bu(313, 105, W, H)
    make_bevelled_plate("SB_LedgerWell", col, (c_led.x, c_led.y), 3.00, 1.04, 0.02, 0.11, 0.012, mats["obsidian_slate"], z_base=0.125)
    make_bevelled_frame("SB_LedgerFrame", col, (c_led.x, c_led.y), 3.04, 1.08, 0.042, 0.055, 0.12, 0.018, mats["brass_antique"], z_base=0.135)
    make_corner_brackets("SB_Led", col, c_led.x, c_led.y, 3.04, 1.08, 0.18, 0.16, 0.036, mats["gold_bright"], mats["ruby_gem"])

    cam = setup_ortho_camera(col, W, H, "ScoreBoardCam")
    render_collection(scene, col, cam, "ui_score_board_3d.png", int(W * 2), int(H * 2))


# ---------------------------------------------------------------------------
# 3. Player HP Plaque (ui_hp_plaque_3d.png, HUD 184x44 -> 368x88)
# ---------------------------------------------------------------------------

def build_hp_plaque(scene, mats):
    W, H = 184.0, 44.0
    col = ensure_collection("03_HpPlaque")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.65, ortho_mode=True)

    make_bevelled_plate("HP_Base", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.09, 0.15, 0.022, mats["iron_forged"], z_base=0.0)
    make_bevelled_frame("HP_BrassRim", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.042, 0.045, 0.15, 0.015, mats["copper_bronze"], z_base=0.08)

    # Left Heart Medallion Socket centered at (24, 22)
    c_hs = px_to_bu(24, 22, W, H)
    make_disc_well("HP_HeartWell", col, (c_hs.x, c_hs.y), 0.155, 0.03, mats["obsidian_slate"], mats["brass_antique"], 0.028, z_base=0.078)

    # Recessed HP Meter Trough at Rect2(48, 26, 124, 9) -> center (110, 30.5)
    c_tr = px_to_bu(110, 30.5, W, H)
    make_bevelled_plate("HP_MeterWell", col, (c_tr.x, c_tr.y), 1.24, 0.095, 0.018, 0.035, 0.006, mats["obsidian_slate"], z_base=0.082)
    make_bevelled_frame("HP_MeterRim", col, (c_tr.x, c_tr.y), 1.29, 0.135, 0.022, 0.036, 0.045, 0.010, mats["brass_antique"], z_base=0.086)

    for rx, ry in [(175, 8), (175, 36)]:
        rp = px_to_bu(rx, ry, W, H)
        make_rivet(f"HP_Riv_{rx}_{ry}", col, (rp.x, rp.y, 0.125), 0.015, mats["gold_bright"])

    cam = setup_ortho_camera(col, W, H, "HpPlaqueCam")
    render_collection(scene, col, cam, "ui_hp_plaque_3d.png", int(W * 2), int(H * 2))


# ---------------------------------------------------------------------------
# 4. Sculpted 3D Player Heart (ui_heart_3d.png, 256x256) & Rival Heart (ui_rival_heart_3d.png)
# ---------------------------------------------------------------------------

def _create_heart_mesh(name, scale=0.45):
    mesh = bpy.data.meshes.new(name + "_mesh")
    bm = bmesh.new()
    segs = 48
    ring_verts = []
    # Smooth parametric heart outline extruded into cushioned faceted ruby volume
    for i in range(segs):
        t = (i / segs) * math.tau
        hx = 16.0 * (math.sin(t) ** 3)
        hy = 13.0 * math.cos(t) - 5.0 * math.cos(2 * t) - 2.0 * math.cos(3 * t) - math.cos(4 * t)
        ring_verts.append((hx / 17.5 * scale, hy / 17.5 * scale))

    front_center = bm.verts.new((0.0, 0.02 * scale, 0.36 * scale))
    back_center = bm.verts.new((0.0, 0.02 * scale, -0.26 * scale))
    mid_ring = [bm.verts.new((x, y, 0.0)) for x, y in ring_verts]
    inner_front = [bm.verts.new((x * 0.62, y * 0.62 + 0.02 * scale, 0.24 * scale)) for x, y in ring_verts]
    inner_back = [bm.verts.new((x * 0.62, y * 0.62 + 0.02 * scale, -0.18 * scale)) for x, y in ring_verts]

    for i in range(segs):
        ni = (i + 1) % segs
        bm.faces.new([mid_ring[i], mid_ring[ni], inner_front[ni], inner_front[i]])
        bm.faces.new([inner_front[i], inner_front[ni], front_center])
        bm.faces.new([mid_ring[ni], mid_ring[i], inner_back[i], inner_back[ni]])
        bm.faces.new([inner_back[ni], inner_back[i], back_center])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_player_heart(scene, mats):
    col = ensure_collection("04_PlayerHeart")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.75, ortho_mode=False)

    h_mesh = _create_heart_mesh("PlayerHeart", scale=0.56)
    heart = bpy.data.objects.new("PlayerHeartObj", h_mesh)
    link_obj(heart, col)
    _apply_smooth_and_mat(heart, mats["ruby_gem"], smooth=True)
    sub = heart.modifiers.new("Subd", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2

    # Antique gold filigree crown arch hugging the top cleft cleanly
    for ang_deg, cx, cy in [(-24, -0.10, 0.25), (24, 0.10, 0.25)]:
        wing = make_bevelled_plate(f"HeartCrownWing_{ang_deg}", col, (cx, cy), 0.18, 0.052, 0.22, 0.02, 0.012, mats["gold_bright"], z_base=-0.10)
        wing.rotation_euler = Euler((0, 0, math.radians(ang_deg)))
    for cx, cy, sz in [(-0.11, 0.32, 0.044), (0.0, 0.29, 0.058), (0.11, 0.32, 0.044)]:
        make_rivet(f"HeartCrownSpire_{cx}", col, (cx, cy, 0.02), sz, mats["gold_bright"], height_scale=0.85)
    make_rivet("HeartCenterStud", col, (0.0, 0.14, 0.19), 0.055, mats["gold_bright"], height_scale=0.65)
    make_rivet("HeartCenterGem", col, (0.0, 0.14, 0.23), 0.032, mats["sapphire_glow"], height_scale=0.65)

    cam = setup_persp_camera(col, (0.04, -0.28, 2.02), (0.0, 0.02, 0.0), lens=62.0, name="PlayerHeartCam")
    render_collection(scene, col, cam, "ui_heart_3d.png", 256, 256)


def build_rival_heart(scene, mats):
    col = ensure_collection("10_RivalHeart")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.75, ortho_mode=False)

    h_mesh = _create_heart_mesh("RivalHeart", scale=0.55)
    heart = bpy.data.objects.new("RivalHeartObj", h_mesh)
    link_obj(heart, col)
    _apply_smooth_and_mat(heart, mats["rival_ruby"], smooth=True)
    sub = heart.modifiers.new("Subd", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2

    # Fitted wrought-iron cage bands hugging the rival heart tightly + brass studs
    band1 = make_torus_ring("RivalBand1", col, (0, 0.02, 0.01), 0.34, 0.034, mats["iron_forged"], maj_seg=42, min_seg=12, rot_euler=(math.radians(78), math.radians(32), 0))
    band1.scale = Vector((1.05, 1.0, 0.72))
    band2 = make_torus_ring("RivalBand2", col, (0, 0.02, 0.01), 0.34, 0.034, mats["iron_forged"], maj_seg=42, min_seg=12, rot_euler=(math.radians(78), math.radians(-32), 0))
    band2.scale = Vector((1.05, 1.0, 0.72))
    make_rivet("RivalCageBoss", col, (0.0, 0.02, 0.20), 0.088, mats["iron_forged"], height_scale=0.75)
    make_rivet("RivalCageStud", col, (0.0, 0.02, 0.25), 0.048, mats["brass_antique"], height_scale=0.75)

    cam = setup_persp_camera(col, (-0.04, -0.28, 2.02), (0.0, 0.02, 0.0), lens=62.0, name="RivalHeartCam")
    render_collection(scene, col, cam, "ui_rival_heart_3d.png", 256, 256)


# ---------------------------------------------------------------------------
# 5. Sculpted 3D Heater Shield (ui_shield_3d.png, 256x256)
# ---------------------------------------------------------------------------

def build_shield(scene, mats):
    col = ensure_collection("05_Shield")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.80, ortho_mode=False)

    contour = [
        (-0.42, 0.48), (0.0, 0.52), (0.42, 0.48),
        (0.43, 0.18), (0.37, -0.12), (0.22, -0.38),
        (0.0, -0.58), (-0.22, -0.38), (-0.37, -0.12), (-0.43, 0.18),
    ]

    def make_shield_layer(name, scale_xy, z_off, thickness, convex_z, mat):
        mesh = bpy.data.meshes.new(name + "_mesh")
        bm = bmesh.new()
        outer = [bm.verts.new((x * scale_xy, y * scale_xy, z_off)) for x, y in contour]
        inner = [bm.verts.new((x * scale_xy * 0.52, y * scale_xy * 0.52, z_off + convex_z)) for x, y in contour]
        center_v = bm.verts.new((0.0, 0.0, z_off + convex_z * 1.45))
        n = len(outer)
        for i in range(n):
            ni = (i + 1) % n
            bm.faces.new([outer[i], outer[ni], inner[ni], inner[i]])
            bm.faces.new([inner[i], inner[ni], center_v])
        res = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
        back_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=back_verts, vec=(0, 0, -thickness))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        link_obj(obj, col)
        return _apply_smooth_and_mat(obj, mat, smooth=True)

    make_shield_layer("ShieldGoldRim", 1.0, 0.0, 0.07, 0.06, mats["gold_bright"])
    make_shield_layer("ShieldSteelBody", 0.87, 0.025, 0.06, 0.10, mats["iron_forged"])

    # Raised antique-gold gothic cross cleanly proud of the convex shield belly
    make_bevelled_plate("ShieldCrossV", col, (0, -0.02), 0.085, 0.86, 0.055, 0.02, 0.015, mats["gold_bright"], z_base=0.145)
    make_bevelled_plate("ShieldCrossH", col, (0, 0.12), 0.64, 0.085, 0.055, 0.02, 0.015, mats["gold_bright"], z_base=0.145)
    make_rivet("ShieldBossCup", col, (0.0, 0.12, 0.21), 0.15, mats["gold_bright"], height_scale=0.65)
    make_rivet("ShieldSapphire", col, (0.0, 0.12, 0.25), 0.102, mats["sapphire_glow"], height_scale=0.75)

    for rx, ry in [(-0.34, 0.40), (0.34, 0.40), (-0.36, 0.05), (0.36, 0.05), (-0.18, -0.32), (0.18, -0.32)]:
        make_rivet(f"ShieldRiv_{rx}_{ry}", col, (rx, ry, 0.075), 0.022, mats["gold_bright"])

    cam = setup_persp_camera(col, (0.04, -0.22, 2.02), (0.0, -0.02, 0.06), lens=62.0, name="ShieldCam")
    render_collection(scene, col, cam, "ui_shield_3d.png", 256, 256)


# ---------------------------------------------------------------------------
# 6. Carry-Out Spoils Plaque & 3D Coins (ui_carry_plaque_3d.png, ui_coin_3d.png)
# ---------------------------------------------------------------------------

def build_carry_plaque(scene, mats):
    W, H = 178.0, 44.0
    col = ensure_collection("06_CarryPlaque")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.65, ortho_mode=True)

    make_bevelled_plate("CP_Base", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.09, 0.15, 0.022, mats["walnut_dark"], z_base=0.0)
    make_bevelled_frame("CP_GoldRim", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.042, 0.045, 0.15, 0.015, mats["brass_antique"], z_base=0.08)

    c_cs = px_to_bu(23, 22, W, H)
    make_disc_well("CP_CoinWell", col, (c_cs.x, c_cs.y), 0.155, 0.03, mats["obsidian_slate"], mats["gold_bright"], 0.026, z_base=0.078)

    c_ch = px_to_bu(107, 22, W, H)
    make_bevelled_plate("CP_TextWell", col, (c_ch.x, c_ch.y), 1.24, 0.28, 0.016, 0.06, 0.008, mats["obsidian_slate"], z_base=0.082)
    make_bevelled_frame("CP_TextFrame", col, (c_ch.x, c_ch.y), 1.28, 0.31, 0.018, 0.030, 0.07, 0.008, mats["brass_antique"], z_base=0.086)

    for rx, ry in [(169, 8), (169, 36)]:
        rp = px_to_bu(rx, ry, W, H)
        make_rivet(f"CP_Riv_{rx}_{ry}", col, (rp.x, rp.y, 0.125), 0.014, mats["gold_bright"])

    cam = setup_ortho_camera(col, W, H, "CarryPlaqueCam")
    render_collection(scene, col, cam, "ui_carry_plaque_3d.png", int(W * 2), int(H * 2))


def _make_coin_unit(name, col, loc, rot_euler, radius, thickness, mats):
    piv = bpy.data.objects.new(name + "_Pivot", None)
    piv.location = Vector(loc)
    piv.rotation_euler = Euler(rot_euler)
    link_obj(piv, col)

    mesh = bpy.data.meshes.new(name + "_mesh")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=36, radius1=radius, radius2=radius, depth=thickness)
    bm.to_mesh(mesh)
    bm.free()
    coin = bpy.data.objects.new(name, mesh)
    coin.parent = piv
    link_obj(coin, col)
    _apply_smooth_and_mat(coin, mats["gold_bright"], smooth=True)

    rim = make_torus_ring(name + "_rim", col, (0, 0, thickness * 0.48), radius * 0.88, radius * 0.10, mats["brass_antique"], maj_seg=36, min_seg=10)
    rim.parent = piv
    boss = make_rivet(name + "_boss", col, (0, 0, thickness * 0.48), radius * 0.44, mats["gold_bright"], height_scale=0.32)
    boss.parent = piv
    return piv


def build_coin_icon(scene, mats):
    col = ensure_collection("07_CoinIcon")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.72, ortho_mode=False)

    _make_coin_unit("Coin1", col, (-0.16, -0.08, -0.18), (math.radians(8), math.radians(-12), 0.1), 0.30, 0.072, mats)
    _make_coin_unit("Coin2", col, (0.16, -0.10, 0.00), (math.radians(10), math.radians(12), -0.2), 0.30, 0.072, mats)
    _make_coin_unit("Coin3", col, (0.00, 0.12, 0.18), (math.radians(6), math.radians(0), 0.0), 0.32, 0.078, mats)

    cam = setup_persp_camera(col, (0.04, -0.46, 2.05), (0.0, 0.0, 0.02), lens=62.0, name="CoinIconCam")
    render_collection(scene, col, cam, "ui_coin_3d.png", 256, 256)


# ---------------------------------------------------------------------------
# 8. Cancel Button Plaque (ui_btn_cancel_3d.png, HUD 100x44 -> 200x88)
# ---------------------------------------------------------------------------

def build_btn_cancel(scene, mats):
    W, H = 100.0, 44.0
    col = ensure_collection("08_BtnCancel")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.52, ortho_mode=True)

    make_bevelled_plate("BC_Base", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.09, 0.15, 0.022, mats["burgundy_metal"], z_base=0.0)
    make_bevelled_frame("BC_Frame", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.044, 0.046, 0.15, 0.016, mats["copper_bronze"], z_base=0.08)
    for sx in (-1, 1):
        for sy in (-1, 1):
            make_rivet(f"BC_Riv_{sx}_{sy}", col, (sx * 0.40, sy * 0.14, 0.128), 0.016, mats["gold_bright"])

    cam = setup_ortho_camera(col, W, H, "BtnCancelCam")
    render_collection(scene, col, cam, "ui_btn_cancel_3d.png", int(W * 2), int(H * 2))


# ---------------------------------------------------------------------------
# 9. Rival HUD Crest (ui_rival_hud_3d.png, HUD 356x74 -> 712x148)
# ---------------------------------------------------------------------------

def build_rival_hud(scene, mats):
    W, H = 356.0, 74.0
    col = ensure_collection("09_RivalHud")
    add_three_point_lights(col, center=(0, 0, 0), scale=1.18, ortho_mode=True)

    make_bevelled_plate("RH_Base", col, (0, 0), W / 100.0 - 0.04, H / 100.0 - 0.04, 0.11, 0.16, 0.024, mats["iron_forged"], z_base=0.0, segs=10)
    make_bevelled_frame("RH_OuterTrim", col, (0, 0), W / 100.0 - 0.04, H / 100.0 - 0.04, 0.052, 0.052, 0.16, 0.018, mats["copper_bronze"], z_base=0.095, segs=10)
    make_corner_brackets("RH", col, 0, 0, W / 100.0 - 0.04, H / 100.0 - 0.04, 0.135, 0.18, 0.042, mats["brass_antique"], mats["rival_ruby"])

    # Round Cartouche at top-right: Rect2(208, 6, 134, 24) -> center (275, 18)
    c_rc = px_to_bu(275, 18, W, H)
    make_bevelled_plate("RH_RoundWell", col, (c_rc.x, c_rc.y), 1.30, 0.21, 0.020, 0.07, 0.009, mats["obsidian_slate"], z_base=0.10)
    make_bevelled_frame("RH_RoundRim", col, (c_rc.x, c_rc.y), 1.34, 0.24, 0.024, 0.036, 0.08, 0.011, mats["brass_antique"], z_base=0.105)

    # Rival Score Meter Channel: Rect2(16, 41, 198, 16) -> center (115, 49)
    c_sc = px_to_bu(115, 49, W, H)
    make_bevelled_plate("RH_ScoreWell", col, (c_sc.x, c_sc.y), 1.94, 0.13, 0.018, 0.035, 0.006, mats["obsidian_slate"], z_base=0.10)
    make_bevelled_frame("RH_ScoreRim", col, (c_sc.x, c_sc.y), 1.99, 0.165, 0.024, 0.036, 0.045, 0.010, mats["copper_bronze"], z_base=0.105)

    # Bottom-right Card-Count Tablet: Rect2(226, 39, 116, 22) -> center (284, 50)
    c_cd = px_to_bu(284, 50, W, H)
    make_bevelled_plate("RH_CardsWell", col, (c_cd.x, c_cd.y), 1.12, 0.19, 0.018, 0.065, 0.008, mats["obsidian_slate"], z_base=0.10)
    make_bevelled_frame("RH_CardsRim", col, (c_cd.x, c_cd.y), 1.16, 0.22, 0.022, 0.034, 0.075, 0.010, mats["brass_antique"], z_base=0.105)

    cam = setup_ortho_camera(col, W, H, "RivalHudCam")
    render_collection(scene, col, cam, "ui_rival_hud_3d.png", int(W * 2), int(H * 2))


# ---------------------------------------------------------------------------
# 11 & 12. Redesigned 3D Wager Board & Slots (474x172 -> 948x344, slots 140x88)
# ---------------------------------------------------------------------------

def build_wager_board(scene, mats):
    W, H = 474.0, 172.0
    col = ensure_collection("11_WagerBoard")
    add_three_point_lights(col, center=(0, 0, 0), scale=1.45, ortho_mode=True)

    # Heavy oak & forged-iron Pact Altar slab with crimson velvet center inlay
    make_bevelled_plate("WB_WoodBase", col, (0, 0), W / 100.0 - 0.04, H / 100.0 - 0.04, 0.14, 0.20, 0.032, mats["walnut_dark"], z_base=0.0, segs=10)
    make_bevelled_plate("WB_VelvetField", col, (0, 0.16), W / 100.0 - 0.22, 1.00, 0.02, 0.12, 0.010, mats["crimson_velvet"], z_base=0.125, segs=8)
    make_bevelled_plate("WB_LowerIronLedge", col, (0, -0.60), W / 100.0 - 0.18, 0.42, 0.024, 0.10, 0.012, mats["iron_forged"], z_base=0.124, segs=8)
    make_bevelled_frame("WB_BrassTrim", col, (0, 0), W / 100.0 - 0.04, H / 100.0 - 0.04, 0.070, 0.070, 0.20, 0.024, mats["brass_antique"], z_base=0.125, segs=10)
    make_corner_brackets("WB", col, 0, 0, W / 100.0 - 0.04, H / 100.0 - 0.04, 0.185, 0.26, 0.058, mats["iron_forged"], mats["gold_bright"])

    # Raised Header Cartouche across top: Rect2(58, 4, 358, 24) -> center (237, 16)
    c_hdr = px_to_bu(237, 16, W, H)
    make_bevelled_plate("WB_HeaderPlate", col, (c_hdr.x, c_hdr.y), 3.58, 0.24, 0.055, 0.08, 0.018, mats["obsidian_slate"], z_base=0.135)
    make_bevelled_frame("WB_HeaderBrass", col, (c_hdr.x, c_hdr.y), 3.64, 0.28, 0.032, 0.068, 0.09, 0.015, mats["gold_bright"], z_base=0.145)
    for sx in (-1.78, 1.78):
        make_rivet(f"WB_HdrGem_{sx}", col, (c_hdr.x + sx, c_hdr.y, 0.215), 0.028, mats["ruby_gem"])

    # 3 Pedestal Niches at x-centers (86, 237, 388), y-center 78 (y: 34..122, 140x88)
    for idx, cx_px in enumerate((86.0, 237.0, 388.0)):
        c_n = px_to_bu(cx_px, 78.0, W, H)
        make_bevelled_plate(f"WB_Niche_{idx}", col, (c_n.x, c_n.y), 1.38, 0.86, 0.015, 0.10, 0.010, mats["obsidian_slate"], z_base=0.132)
        make_bevelled_frame(f"WB_NicheRim_{idx}", col, (c_n.x, c_n.y), 1.42, 0.90, 0.022, 0.028, 0.11, 0.008, mats["iron_forged"], z_base=0.136)

    # 2 Brass Pilasters dividing the 3 niches at x = 161.5 and x = 312.5
    for idx, px_div in enumerate((161.5, 312.5)):
        c_p = px_to_bu(px_div, 78.0, W, H)
        make_bevelled_plate(f"WB_Pilaster_{idx}", col, (c_p.x, c_p.y), 0.046, 0.88, 0.055, 0.018, 0.012, mats["brass_antique"], z_base=0.138)
        for py in (36.0, 120.0):
            cp_cap = px_to_bu(px_div, py, W, H)
            make_rivet(f"WB_PilCap_{idx}_{py}", col, (cp_cap.x, cp_cap.y, 0.195), 0.025, mats["gold_bright"])

    # Lower Forged Iron Ledge divider & Veto slot recesses: (123, 146) and (351, 146)
    c_ledge = px_to_bu(237, 126, W, H)
    make_bevelled_plate("WB_LedgeBar", col, (c_ledge.x, c_ledge.y), 4.46, 0.035, 0.045, 0.012, 0.010, mats["brass_antique"], z_base=0.135)
    for idx, vx_px in enumerate((123.0, 351.0)):
        c_v = px_to_bu(vx_px, 146.0, W, H)
        make_bevelled_plate(f"WB_VetoWell_{idx}", col, (c_v.x, c_v.y), 2.18, 0.32, 0.016, 0.08, 0.008, mats["obsidian_slate"], z_base=0.128)

    cam = setup_ortho_camera(col, W, H, "WagerBoardCam")
    render_collection(scene, col, cam, "ui_wager_board_3d.png", int(W * 2), int(H * 2))


def build_wager_slots(scene, mats):
    W, H = 140.0, 88.0
    for active, out_name in ((False, "ui_wager_slot_idle_3d.png"), (True, "ui_wager_slot_active_3d.png")):
        col_name = "12_WagerSlotActive" if active else "12_WagerSlotIdle"
        col = ensure_collection(col_name)
        add_three_point_lights(col, center=(0, 0, 0), scale=0.60, ortho_mode=True)

        mat_tray = mats["crimson_velvet"] if active else mats["obsidian_slate"]
        mat_rim = mats["gold_bright"] if active else mats["iron_forged"]
        mat_ring = mats["gold_bright"] if active else mats["copper_bronze"]

        make_bevelled_plate(f"WS_{active}_Base", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.06, 0.11, 0.018, mat_tray, z_base=0.0)
        make_bevelled_frame(f"WS_{active}_Rim", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.048 if active else 0.036, 0.055 if active else 0.036, 0.11, 0.016, mat_rim, z_base=0.05)

        # Raised circular medallion pedestal centered at top-half (70, 30) where the 3D prop sits
        c_ped = px_to_bu(70, 31, W, H)
        make_disc_well(f"WS_{active}_Ped", col, (c_ped.x, c_ped.y), 0.255, 0.026, mats["walnut_dark"] if not active else mats["burgundy_metal"], mat_ring, 0.024 if active else 0.018, z_base=0.052)

        if active:
            make_corner_brackets(f"WS_{active}", col, 0, 0, W / 100.0 - 0.02, H / 100.0 - 0.02, 0.098, 0.18, 0.036, mats["gold_bright"], mats["ruby_gem"])

        cam = setup_ortho_camera(col, W, H, f"WagerSlotCam_{active}")
        render_collection(scene, col, cam, out_name, int(W * 2), int(H * 2))


# ---------------------------------------------------------------------------
# 13. Three 3D Wager Centerpiece Props (256x256 each)
# ---------------------------------------------------------------------------

def build_wager_gold_prop(scene, mats):
    col = ensure_collection("13a_WagerGoldProp")
    add_three_point_lights(col, center=(0, 0, 0.15), scale=0.80, ortho_mode=False)

    # Bevelled brass coaster underneath
    make_disc_well("WG_Coaster", col, (0, 0), 0.56, 0.05, mats["walnut_dark"], mats["brass_antique"], 0.032, z_base=-0.02)

    # Lathed leather drawstring coin pouch (left-back)
    pouch_prof = [
        (0.00, 0.02), (0.23, 0.03), (0.28, 0.14), (0.26, 0.30),
        (0.17, 0.42), (0.12, 0.48), (0.18, 0.59), (0.13, 0.62), (0.00, 0.48),
    ]
    pm = bpy.data.meshes.new("WG_Pouch_mesh")
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in pouch_prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=36)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(pm)
    bm.free()
    pouch = bpy.data.objects.new("WG_Pouch", pm)
    pouch.location = Vector((-0.20, 0.14, 0.02))
    link_obj(pouch, col)
    _apply_smooth_and_mat(pouch, mats["leather_pouch"], smooth=True)
    make_torus_ring("WG_Cord", col, (-0.20, 0.14, 0.49), 0.130, 0.022, mats["gold_bright"], maj_seg=32, min_seg=10)

    # Stack of 4 gleaming gold florins on right + non-overlapping leaning coin in front
    for k in range(4):
        _make_coin_unit(f"WG_Coin_{k}", col, (0.22 + (k % 2) * 0.015, 0.04 + k * 0.01, 0.06 + k * 0.060), (math.radians(3 * k), math.radians(-4 if k == 2 else 3), 0.2 * k), 0.175, 0.044, mats)
    _make_coin_unit("WG_LeanCoin", col, (0.00, -0.32, 0.14), (math.radians(38), math.radians(10), -0.20), 0.160, 0.040, mats)

    cam = setup_persp_camera(col, (0.24, -2.02, 1.38), (0.0, 0.0, 0.28), lens=60.0, name="WagerGoldCam")
    render_collection(scene, col, cam, "ui_wager_gold_3d.png", 256, 256)


def build_wager_phial_prop(scene, mats):
    col = ensure_collection("13b_WagerPhialProp")
    add_three_point_lights(col, center=(0, 0, 0.35), scale=0.82, ortho_mode=False)

    # Outer faceted crystal flask with translucent glass alpha so glowing core shines through
    flask_prof = [
        (0.00, 0.00), (0.22, 0.00), (0.34, 0.14), (0.38, 0.36),
        (0.30, 0.58), (0.11, 0.74), (0.11, 0.94), (0.16, 0.98),
        (0.16, 1.03), (0.09, 1.03), (0.08, 0.74), (0.24, 0.56),
        (0.30, 0.36), (0.26, 0.16), (0.16, 0.06), (0.00, 0.05),
    ]
    fm = bpy.data.meshes.new("WP_Flask_mesh")
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in flask_prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=12)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(fm)
    bm.free()
    flask = bpy.data.objects.new("WP_Flask", fm)
    flask.rotation_euler = Euler((0.0, math.radians(-10), math.radians(15)))
    link_obj(flask, col)
    _apply_smooth_and_mat(flask, mats["crystal_glass"], smooth=False)

    # Glowing Ignis Liquid Core inside flask (shrunk cleanly inward so zero z-fighting with inner glass wall)
    liq_prof = [(0.00, 0.09), (0.19, 0.11), (0.26, 0.34), (0.20, 0.50), (0.00, 0.52)]
    lm = bpy.data.meshes.new("WP_Liquid_mesh")
    bm2 = bmesh.new()
    lvs = [bm2.verts.new((r, 0, z)) for r, z in liq_prof]
    les = [bm2.edges.new((lvs[i], lvs[i + 1])) for i in range(len(lvs) - 1)]
    bmesh.ops.spin(bm2, geom=lvs + les, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=12)
    bmesh.ops.remove_doubles(bm2, verts=bm2.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
    bm2.to_mesh(lm)
    bm2.free()
    liq = bpy.data.objects.new("WP_Liquid", lm)
    liq.parent = flask
    link_obj(liq, col)
    _apply_smooth_and_mat(liq, mats["amethyst_flame"], smooth=True)

    # Cork stopper
    cm = bpy.data.meshes.new("WP_Cork_mesh")
    bm3 = bmesh.new()
    bmesh.ops.create_cone(bm3, cap_ends=True, segments=16, radius1=0.095, radius2=0.125, depth=0.22)
    bm3.to_mesh(cm)
    bm3.free()
    cork = bpy.data.objects.new("WP_Cork", cm)
    cork.location = Vector((0, 0, 1.07))
    cork.parent = flask
    link_obj(cork, col)
    _apply_smooth_and_mat(cork, mats["cork_wood"], smooth=True)

    # Antique brass filigree collar, waist band & base foot
    make_torus_ring("WP_NeckBand", col, (0, 0, 0.80), 0.135, 0.026, mats["gold_bright"], maj_seg=32, min_seg=10).parent = flask
    make_torus_ring("WP_WaistBand", col, (0, 0, 0.36), 0.392, 0.024, mats["brass_antique"], maj_seg=16, min_seg=10).parent = flask
    make_torus_ring("WP_FootBand", col, (0, 0, 0.03), 0.235, 0.022, mats["brass_antique"], maj_seg=16, min_seg=10).parent = flask
    make_rivet("WP_FrontGem", col, (0.0, -0.395, 0.36), 0.060, mats["gold_bright"], height_scale=0.6).parent = flask

    cam = setup_persp_camera(col, (0.0, -2.42, 0.96), (0.0, 0.0, 0.54), lens=62.0, name="WagerPhialCam")
    render_collection(scene, col, cam, "ui_wager_phial_3d.png", 256, 256)


def build_wager_sword_prop(scene, mats):
    col = ensure_collection("13c_WagerSwordProp")
    add_three_point_lights(col, center=(0, 0, 0.32), scale=0.85, ortho_mode=False)

    # Crimson Blood-Oath Wax Seal at the base
    make_disc_well("WSW_WaxBase", col, (0, 0), 0.38, 0.075, mats["wax_seal"], mats["ruby_gem"], 0.028, z_base=0.0)
    make_torus_ring("WSW_WaxRim", col, (0, 0, 0.08), 0.31, 0.042, mats["wax_seal"], maj_seg=36, min_seg=12)

    # Sword assembly angled diagonally heroically into the wax seal
    sw_pivot = bpy.data.objects.new("WSW_Pivot", None)
    sw_pivot.location = Vector((0.0, 0.0, 0.06))
    sw_pivot.rotation_euler = Euler((math.radians(-6), math.radians(16), math.radians(-10)))
    link_obj(sw_pivot, col)

    # Tapered diamond-section steel blade rising into crossguard
    bm_b = bmesh.new()
    m_b = bpy.data.meshes.new("WSW_Blade_mesh")
    bmesh.ops.create_cone(bm_b, cap_ends=True, segments=4, radius1=0.042, radius2=0.095, depth=0.46)
    bm_b.to_mesh(m_b)
    bm_b.free()
    blade = bpy.data.objects.new("WSW_Blade", m_b)
    blade.location = Vector((0, 0, 0.22))
    blade.scale = Vector((1.0, 0.26, 1.0))
    blade.parent = sw_pivot
    link_obj(blade, col)
    _apply_smooth_and_mat(blade, mats["steel_blade"], smooth=False)

    # Sleek medieval horizontal gold crossguard + tapered quillon tips
    guard = make_bevelled_plate("WSW_Guard", col, (0, 0), 0.70, 0.088, 0.068, 0.025, 0.015, mats["gold_bright"], z_base=0.0)
    guard.rotation_euler = Euler((math.radians(90), 0, 0))
    guard.location = Vector((0, 0.044, 0.48))
    guard.parent = sw_pivot
    for sx in (-0.36, 0.36):
        make_rivet(f"WSW_Quil_{sx}", col, (sx, 0.0, 0.45), 0.056, mats["gold_bright"], height_scale=1.0).parent = sw_pivot

    # Leather ribbed grip
    gm = bpy.data.meshes.new("WSW_Grip_mesh")
    bm_g = bmesh.new()
    bmesh.ops.create_cone(bm_g, cap_ends=True, segments=16, radius1=0.046, radius2=0.040, depth=0.34)
    bm_g.to_mesh(gm)
    bm_g.free()
    grip = bpy.data.objects.new("WSW_Grip", gm)
    grip.location = Vector((0, 0, 0.68))
    grip.parent = sw_pivot
    link_obj(grip, col)
    _apply_smooth_and_mat(grip, mats["leather_pouch"], smooth=True)
    for gz in (0.58, 0.65, 0.72, 0.79):
        make_torus_ring(f"WSW_Wrap_{gz}", col, (0, 0, gz), 0.046, 0.010, mats["brass_antique"], maj_seg=20, min_seg=8).parent = sw_pivot

    # Pommel & glowing crimson ruby gem
    make_rivet("WSW_Pommel", col, (0, 0, 0.89), 0.095, mats["gold_bright"], height_scale=0.85).parent = sw_pivot
    make_rivet("WSW_PommelRuby", col, (0, -0.058, 0.89), 0.056, mats["ruby_gem"], height_scale=0.75).parent = sw_pivot

    cam = setup_persp_camera(col, (0.04, -2.42, 0.96), (0.0, 0.0, 0.48), lens=62.0, name="WagerSwordCam")
    render_collection(scene, col, cam, "ui_wager_sword_3d.png", 256, 256)


# ---------------------------------------------------------------------------
# 14. Wager Veto Button (218x32) & Bottom-Left Status Pill (266x42)
# ---------------------------------------------------------------------------

def build_wager_veto_btn(scene, mats):
    W, H = 218.0, 32.0
    col = ensure_collection("14a_WagerVetoBtn")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.80, ortho_mode=True)

    make_bevelled_plate("WV_Base", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.075, 0.11, 0.018, mats["iron_forged"], z_base=0.0)
    make_bevelled_frame("WV_Rim", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.036, 0.038, 0.11, 0.012, mats["copper_bronze"], z_base=0.068)
    for sx in (-0.98, 0.98):
        make_rivet(f"WV_Riv_{sx}", col, (sx, 0.0, 0.105), 0.018, mats["gold_bright"])

    cam = setup_ortho_camera(col, W, H, "WagerVetoCam")
    render_collection(scene, col, cam, "ui_wager_veto_btn_3d.png", int(W * 2), int(H * 2))


def build_status_pill(scene, mats):
    W, H = 266.0, 42.0
    col = ensure_collection("14b_StatusPill")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.90, ortho_mode=True)

    make_bevelled_plate("SP_Base", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.085, 0.15, 0.020, mats["walnut_dark"], z_base=0.0)
    make_bevelled_frame("SP_Rim", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.042, 0.042, 0.15, 0.014, mats["brass_antique"], z_base=0.078)
    for sx in (-1.20, 1.20):
        make_rivet(f"SP_Riv_{sx}", col, (sx, 0.0, 0.12), 0.018, mats["gold_bright"])

    cam = setup_ortho_camera(col, W, H, "StatusPillCam")
    render_collection(scene, col, cam, "ui_status_pill_3d.png", int(W * 2), int(H * 2))


def build_wager_pill(scene, mats):
    W, H = 194.0, 36.0
    col = ensure_collection("14c_WagerPill")
    add_three_point_lights(col, center=(0, 0, 0), scale=0.72, ortho_mode=True)

    make_bevelled_plate("WP_Base", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.085, 0.14, 0.020, mats["crimson_velvet"], z_base=0.0)
    make_bevelled_frame("WP_Rim", col, (0, 0), W / 100.0 - 0.02, H / 100.0 - 0.02, 0.038, 0.042, 0.14, 0.014, mats["gold_bright"], z_base=0.075)

    # Left circular gilded medallion pedestal well for 3D wager prop at (20, 18)
    c_well = px_to_bu(20, 18, W, H)
    make_disc_well("WP_PropWell", col, (c_well.x, c_well.y), 0.135, 0.024, mats["burgundy_metal"], mats["gold_bright"], 0.024, z_base=0.072)

    # Right recessed obsidian nameplate tablet at (114, 18)
    c_tab = px_to_bu(114, 18, W, H)
    make_bevelled_plate("WP_NameWell", col, (c_tab.x, c_tab.y), 1.42, 0.23, 0.016, 0.055, 0.008, mats["obsidian_slate"], z_base=0.076)
    make_bevelled_frame("WP_NameRim", col, (c_tab.x, c_tab.y), 1.46, 0.26, 0.018, 0.028, 0.065, 0.008, mats["brass_antique"], z_base=0.080)

    for rx, ry in [(188, 7), (188, 29)]:
        rp = px_to_bu(rx, ry, W, H)
        make_rivet(f"WP_Ruby_{rx}_{ry}", col, (rp.x, rp.y, 0.120), 0.013, mats["ruby_gem"])

    cam = setup_ortho_camera(col, W, H, "WagerPillCam")
    render_collection(scene, col, cam, "ui_wager_pill_3d.png", int(W * 2), int(H * 2))


# ---------------------------------------------------------------------------
# Main Pipeline
# ---------------------------------------------------------------------------

def main():
    scene = clear_scene()
    mats = build_materials()

    builders = [
        build_chalice,
        build_score_board,
        build_hp_plaque,
        build_player_heart,
        build_rival_heart,
        build_shield,
        build_carry_plaque,
        build_coin_icon,
        build_btn_cancel,
        build_rival_hud,
        build_wager_board,
        build_wager_slots,
        build_wager_gold_prop,
        build_wager_phial_prop,
        build_wager_sword_prop,
        build_wager_veto_btn,
        build_status_pill,
        build_wager_pill,
    ]
    # Build all collections first (hidden during creation), then render one by one
    # Note: each builder currently calls render_collection at the end, so hide collections first
    for c in list(bpy.data.collections):
        set_collection_visibility(c, False)

    for bfn in builders:
        bfn(scene, mats)

    # Reveal all collections in saved .blend for interactive inspection
    for c in bpy.data.collections:
        c.hide_render = False
        c.hide_viewport = False

    blend_path = BLEND_DIR / "lialo_hud_assets.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print("BLENDER_UI_GENERATION_COMPLETE:", OUT_DIR)


if __name__ == "__main__":
    main()
