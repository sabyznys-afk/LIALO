"""Shared Blender 5.3 headless procedural mesh, PBR material, keyframe, and GLB export helpers for LIALO VFX."""

import math
import os
import pathlib
import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

BLENDER_VFX_DIR = pathlib.Path(__file__).resolve().parent
PROJECT_ROOT = BLENDER_VFX_DIR.parent.parent
OUT_VFX_DIR = PROJECT_ROOT / "assets" / "models" / "vfx"
PREVIEW_DIR = BLENDER_VFX_DIR / "previews"


def reset_scene(fps: int = 24, frame_start: int = 1, frame_end: int = 96) -> bpy.types.Scene:
    """Reset Blender to a clean empty scene configured at the given FPS and frame range."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = fps
    scene.render.fps_base = 1.0
    scene.frame_start = frame_start
    scene.frame_end = frame_end
    scene.frame_set(frame_start)
    return scene


def make_pbr_mat(
    name: str,
    base_color=(0.8, 0.7, 0.5, 1.0),
    metallic: float = 0.0,
    roughness: float = 0.45,
    emission_color=None,
    emission_strength: float = 0.0,
    alpha: float = 1.0,
    transmission: float = 0.0,
    ior: float = 1.45,
) -> bpy.types.Material:
    """Create a Blender 5.3 Principled BSDF PBR material compatible with glTF/Godot GL Compatibility."""
    mat = bpy.data.materials.new(name=name)
    if not mat.use_nodes:
        mat.use_nodes = True
    nt = mat.node_tree
    bsdf = None
    for node in nt.nodes:
        if node.type == "BSDF_PRINCIPLED":
            bsdf = node
            break
    if bsdf is None:
        bsdf = nt.nodes.new(type="ShaderNodeBsdfPrincipled")

    if len(base_color) == 3:
        rgba = (float(base_color[0]), float(base_color[1]), float(base_color[2]), 1.0)
    else:
        rgba = tuple(float(c) for c in base_color[:4])

    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Metallic"].default_value = max(0.0, min(1.0, float(metallic)))
    bsdf.inputs["Roughness"].default_value = max(0.02, min(1.0, float(roughness)))
    bsdf.inputs["Alpha"].default_value = max(0.0, min(1.0, float(alpha)))
    bsdf.inputs["IOR"].default_value = float(ior)
    if "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = max(0.0, min(1.0, float(transmission)))

    if emission_color is not None and emission_strength > 0.0:
        if len(emission_color) == 3:
            e_rgba = (float(emission_color[0]), float(emission_color[1]), float(emission_color[2]), 1.0)
        else:
            e_rgba = tuple(float(c) for c in emission_color[:4])
        bsdf.inputs["Emission Color"].default_value = e_rgba
        bsdf.inputs["Emission Strength"].default_value = float(emission_strength)

    if alpha < 0.99:
        mat.surface_render_method = "BLENDED"
    return mat


def link_object(obj: bpy.types.Object, parent: bpy.types.Object = None) -> bpy.types.Object:
    """Link an object to the active scene collection and optionally parent it."""
    coll = bpy.context.scene.collection
    if obj.name not in coll.objects:
        coll.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def create_empty(name: str, loc=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0), parent=None) -> bpy.types.Object:
    """Create an Empty transform node."""
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.08
    obj.location = Vector(loc)
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
    obj.scale = Vector(scale)
    return link_object(obj, parent)


def finalize_bmesh(name: str, bm: bmesh.types.BMesh, mat=None, smooth: bool = True, parent=None) -> bpy.types.Object:
    """Recalculate outward normals, convert BMesh to Object, apply material & shading."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if smooth and len(mesh.polygons) > 0:
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    if mat is not None:
        obj.data.materials.append(mat)
    obj.rotation_mode = "XYZ"
    return link_object(obj, parent)


def set_smooth(obj: bpy.types.Object, smooth: bool = True) -> None:
    """Toggle polygon smooth shading on a mesh object."""
    if obj and obj.type == "MESH" and obj.data and len(obj.data.polygons) > 0:
        obj.data.polygons.foreach_set("use_smooth", [smooth] * len(obj.data.polygons))
        obj.data.update()


def set_interp(obj: bpy.types.Object, interpolation: str = "BEZIER") -> None:
    """Safely set keyframe interpolation in Blender 5.3 (action.layers -> strips -> channelbags -> fcurves)."""
    if not obj or not obj.animation_data or not obj.animation_data.action:
        return
    act = obj.animation_data.action
    fcurves = []
    if hasattr(act, "layers"):
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    fcurves.extend(cb.fcurves)
    elif hasattr(act, "fcurves"):
        fcurves.extend(act.fcurves)

    for fc in fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = interpolation
            if interpolation == "BEZIER":
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"


def kf_trs(obj: bpy.types.Object, frame: int, loc=None, rot_deg=None, scale=None) -> None:
    """Insert location, Euler XYZ rotation (degrees), and scale keyframes at frame."""
    if obj.rotation_mode != "XYZ":
        obj.rotation_mode = "XYZ"
    if loc is not None:
        obj.location = Vector(loc)
        obj.keyframe_insert(data_path="location", frame=frame)
    if rot_deg is not None:
        obj.rotation_euler = Euler([math.radians(float(a)) for a in rot_deg], "XYZ")
        obj.keyframe_insert(data_path="rotation_euler", frame=frame)
    if scale is not None:
        if isinstance(scale, (int, float)):
            obj.scale = Vector((float(scale), float(scale), float(scale)))
        else:
            obj.scale = Vector(scale)
        obj.keyframe_insert(data_path="scale", frame=frame)


def create_lathe_mesh(
    name: str,
    profile_rz,
    segments: int = 28,
    mat=None,
    smooth: bool = True,
    cap_bottom: bool = True,
    cap_top: bool = True,
    parent=None,
) -> bpy.types.Object:
    """Build a radially lathed mesh around Z axis from (radius, z) profile points."""
    bm = bmesh.new()
    rings = []
    for r, z in profile_rz:
        ring_verts = []
        r_safe = max(0.0004, float(r))
        for si in range(segments):
            ang = (float(si) / float(segments)) * math.tau
            v = bm.verts.new((math.cos(ang) * r_safe, math.sin(ang) * r_safe, float(z)))
            ring_verts.append(v)
        rings.append(ring_verts)

    for ri in range(len(rings) - 1):
        r0 = rings[ri]
        r1 = rings[ri + 1]
        for si in range(segments):
            sn = (si + 1) % segments
            bm.faces.new((r0[si], r0[sn], r1[sn], r1[si]))

    if cap_bottom and len(rings) > 0 and profile_rz[0][0] > 0.001:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and len(rings) > 0 and profile_rz[-1][0] > 0.001:
        bm.faces.new(rings[-1])

    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
    return finalize_bmesh(name, bm, mat=mat, smooth=smooth, parent=parent)


def create_ornate_ring(
    name: str,
    r_outer: float,
    r_inner: float,
    height: float,
    notches: int = 12,
    notch_depth: float = 0.015,
    segments: int = 48,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Create a beveled medieval astrolabe/rune ring with optional radial notched crenellations."""
    bm = bmesh.new()
    half_h = height * 0.5
    top_outer = []
    top_inner = []
    bot_outer = []
    bot_inner = []

    for si in range(segments):
        u = float(si) / float(segments)
        ang = u * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        lug = 0.0
        if notches > 0 and notch_depth > 0.0:
            wave = math.cos(u * notches * math.tau)
            if wave > 0.55:
                lug = notch_depth
        ro = r_outer + lug
        ri = r_inner
        top_outer.append(bm.verts.new((ca * ro, sa * ro, half_h)))
        top_inner.append(bm.verts.new((ca * ri, sa * ri, half_h)))
        bot_outer.append(bm.verts.new((ca * ro, sa * ro, -half_h)))
        bot_inner.append(bm.verts.new((ca * ri, sa * ri, -half_h)))

    for si in range(segments):
        sn = (si + 1) % segments
        bm.faces.new((top_inner[si], top_outer[si], top_outer[sn], top_inner[sn]))
        bm.faces.new((bot_outer[si], bot_inner[si], bot_inner[sn], bot_outer[sn]))
        bm.faces.new((bot_outer[si], top_outer[si], top_outer[sn], bot_outer[sn]))
        bm.faces.new((top_inner[si], bot_inner[si], bot_inner[sn], top_inner[sn]))

    return finalize_bmesh(name, bm, mat=mat, smooth=False, parent=parent)


def create_twisted_ribbon(
    name: str,
    radius_start: float,
    radius_end: float,
    height: float,
    turns: float = 1.8,
    width: float = 0.06,
    thickness: float = 0.008,
    steps: int = 44,
    phase_deg: float = 0.0,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Build a tapered 3D helical energy ribbon with thickness so it renders cleanly from all angles."""
    bm = bmesh.new()
    phase = math.radians(phase_deg)
    ring_sections = []
    for i in range(steps + 1):
        u = float(i) / float(steps)
        taper = math.sin(u * math.pi)
        ang = phase + u * turns * math.tau
        rad = radius_start + (radius_end - radius_start) * u
        z = u * height
        cx = math.cos(ang) * rad
        cy = math.sin(ang) * rad
        radial = Vector((math.cos(ang), math.sin(ang), 0.0))
        up = Vector((0.0, 0.0, 1.0))
        w = max(0.002, width * (0.35 + 0.65 * taper))
        th = max(0.0015, thickness * (0.4 + 0.6 * taper))
        c = Vector((cx, cy, z))
        v0 = bm.verts.new(c + radial * (th * 0.5) + up * (w * 0.5))
        v1 = bm.verts.new(c - radial * (th * 0.5) + up * (w * 0.5))
        v2 = bm.verts.new(c - radial * (th * 0.5) - up * (w * 0.5))
        v3 = bm.verts.new(c + radial * (th * 0.5) - up * (w * 0.5))
        ring_sections.append((v0, v1, v2, v3))

    for i in range(steps):
        a = ring_sections[i]
        b = ring_sections[i + 1]
        for k in range(4):
            kn = (k + 1) % 4
            bm.faces.new((a[k], a[kn], b[kn], b[k]))

    bm.faces.new(list(reversed(ring_sections[0])))
    bm.faces.new(list(ring_sections[-1]))
    return finalize_bmesh(name, bm, mat=mat, smooth=True, parent=parent)


def create_faceted_crystal(
    name: str,
    radius: float = 0.08,
    height: float = 0.24,
    sides: int = 6,
    tip_ratio: float = 0.30,
    bottom_taper: float = 0.55,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Create a double-terminated medieval arcane shard or obelisk crystal."""
    bm = bmesh.new()
    z_bot = 0.0
    z_low = height * 0.22
    z_high = height * (1.0 - tip_ratio)
    z_top = height

    v_bot = bm.verts.new((0.0, 0.0, z_bot))
    v_top = bm.verts.new((0.0, 0.0, z_top))
    low_ring = []
    high_ring = []
    for i in range(sides):
        ang = (float(i) / float(sides)) * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        low_ring.append(bm.verts.new((ca * radius * bottom_taper, sa * radius * bottom_taper, z_low)))
        high_ring.append(bm.verts.new((ca * radius, sa * radius, z_high)))

    for i in range(sides):
        inext = (i + 1) % sides
        bm.faces.new((v_bot, low_ring[inext], low_ring[i]))
        bm.faces.new((low_ring[i], low_ring[inext], high_ring[inext], high_ring[i]))
        bm.faces.new((high_ring[i], high_ring[inext], v_top))

    return finalize_bmesh(name, bm, mat=mat, smooth=False, parent=parent)


def create_medieval_sword(
    name_prefix: str,
    blade_len: float = 0.85,
    blade_w: float = 0.085,
    guard_w: float = 0.26,
    curved: bool = False,
    mat_blade=None,
    mat_guard=None,
    mat_grip=None,
    mat_rune=None,
    parent=None,
) -> bpy.types.Object:
    """Create a sculpted gothic sword or curved dagger centered at its crossguard (Z=0), blade extending +Z."""
    root = create_empty(f"{name_prefix}_Root", parent=parent)

    # 1. Diamond cross-section blade (+Z up, grip -Z down)
    bm_b = bmesh.new()
    steps = 10
    thick = blade_w * 0.24
    rings = []
    for i in range(steps):
        u = float(i) / float(steps)
        z = 0.02 + u * (blade_len * 0.86)
        w = blade_w * (1.0 - 0.34 * u)
        th = thick * (1.0 - 0.45 * u)
        x_curve = (u * u * blade_w * 1.15) if curved else 0.0
        v_l = bm_b.verts.new((x_curve - w * 0.5, 0.0, z))
        v_f = bm_b.verts.new((x_curve, th * 0.5, z))
        v_r = bm_b.verts.new((x_curve + w * 0.5, 0.0, z))
        v_k = bm_b.verts.new((x_curve, -th * 0.5, z))
        rings.append((v_l, v_f, v_r, v_k))

    tip_x = (blade_w * 1.65) if curved else 0.0
    v_tip = bm_b.verts.new((tip_x, 0.0, blade_len))
    for i in range(steps - 1):
        a = rings[i]
        b = rings[i + 1]
        for k in range(4):
            kn = (k + 1) % 4
            bm_b.faces.new((a[k], a[kn], b[kn], b[k]))
    last = rings[-1]
    for k in range(4):
        kn = (k + 1) % 4
        bm_b.faces.new((last[k], last[kn], v_tip))
    bm_b.faces.new(list(reversed(rings[0])))
    finalize_bmesh(f"{name_prefix}_Blade", bm_b, mat=mat_blade, smooth=False, parent=root)

    # 2. Glowing inlaid rune fuller spine along center of blade
    if mat_rune is not None:
        bm_r = bmesh.new()
        r_rings = []
        for i in range(8):
            u = float(i) / 7.0
            z = 0.06 + u * (blade_len * 0.62)
            rw = blade_w * 0.16 * (1.0 - 0.35 * u)
            rth = thick * 0.58 * (1.0 - 0.35 * u)
            xc = (u * u * blade_w * 0.65) if curved else 0.0
            r_rings.append((
                bm_r.verts.new((xc - rw, 0.0, z)),
                bm_r.verts.new((xc, rth, z)),
                bm_r.verts.new((xc + rw, 0.0, z)),
                bm_r.verts.new((xc, -rth, z)),
            ))
        for i in range(7):
            for k in range(4):
                kn = (k + 1) % 4
                bm_r.faces.new((r_rings[i][k], r_rings[i][kn], r_rings[i + 1][kn], r_rings[i + 1][k]))
        bm_r.faces.new(list(reversed(r_rings[0])))
        bm_r.faces.new(list(r_rings[-1]))
        finalize_bmesh(f"{name_prefix}_Rune", bm_r, mat=mat_rune, smooth=False, parent=root)

    # 3. Horned gothic crossguard
    bm_g = bmesh.new()
    g_segs = 8
    g_rings = []
    for i in range(g_segs + 1):
        u = (float(i) / float(g_segs)) * 2.0 - 1.0  # -1..1
        gx = u * guard_w * 0.5
        gz = 0.015 + abs(u) * (guard_w * 0.14)
        gw_y = blade_w * (0.28 - 0.14 * abs(u))
        gh = blade_w * (0.24 - 0.10 * abs(u))
        g_rings.append((
            bm_g.verts.new((gx, -gw_y, gz - gh)),
            bm_g.verts.new((gx, gw_y, gz - gh)),
            bm_g.verts.new((gx, gw_y, gz + gh)),
            bm_g.verts.new((gx, -gw_y, gz + gh)),
        ))
    for i in range(g_segs):
        for k in range(4):
            kn = (k + 1) % 4
            bm_g.faces.new((g_rings[i][k], g_rings[i][kn], g_rings[i + 1][kn], g_rings[i + 1][k]))
    bm_g.faces.new(list(reversed(g_rings[0])))
    bm_g.faces.new(list(g_rings[-1]))
    finalize_bmesh(f"{name_prefix}_Guard", bm_g, mat=mat_guard, smooth=False, parent=root)

    # 4. Ribbed grip & faceted pommel extending down (-Z)
    grip_len = max(0.14, blade_len * 0.25)
    create_lathe_mesh(
        f"{name_prefix}_Grip",
        [
            (blade_w * 0.26, -grip_len - 0.045),
            (blade_w * 0.42, -grip_len - 0.022),
            (blade_w * 0.24, -grip_len),
            (blade_w * 0.18, -grip_len * 0.55),
            (blade_w * 0.21, -0.015),
            (blade_w * 0.28, 0.0),
        ],
        segments=12,
        mat=mat_grip if mat_grip is not None else mat_guard,
        smooth=True,
        parent=root,
    )
    return root


def create_chain_strand(
    name: str,
    link_count: int = 8,
    link_len: float = 0.075,
    link_w: float = 0.036,
    wire_r: float = 0.008,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Create a forged medieval iron chain extending along +Z."""
    bm = bmesh.new()
    for li in range(link_count):
        z_off = li * (link_len * 0.68)
        rot_z = (math.pi * 0.5) if (li % 2 == 1) else 0.0
        rot_m = Matrix.Rotation(rot_z, 4, "Z")
        segs = 14
        loop_rings = []
        for s in range(segs):
            a = (float(s) / float(segs)) * math.tau
            px = math.cos(a) * (link_w * 0.5)
            pz = math.sin(a) * (link_len * 0.5)
            tang = Vector((-math.sin(a) * link_w * 0.5, 0.0, math.cos(a) * link_len * 0.5)).normalized()
            side = Vector((0.0, 1.0, 0.0))
            nrm = tang.cross(side).normalized()
            center = Vector((px, 0.0, pz))
            sec = []
            for cs in range(6):
                ca = (float(cs) / 6.0) * math.tau
                pt = center + (nrm * math.cos(ca) + side * math.sin(ca)) * wire_r
                pt = rot_m @ pt + Vector((0.0, 0.0, z_off))
                sec.append(bm.verts.new(pt))
            loop_rings.append(sec)
        for s in range(segs):
            sn = (s + 1) % segs
            for cs in range(6):
                cn = (cs + 1) % 6
                bm.faces.new((loop_rings[s][cs], loop_rings[sn][cs], loop_rings[sn][cn], loop_rings[s][cn]))
    return finalize_bmesh(name, bm, mat=mat, smooth=True, parent=parent)


def create_flame_tongue(
    name: str,
    radius: float = 0.14,
    height: float = 0.45,
    twist_rad: float = 1.6,
    lean_x: float = 0.08,
    sides: int = 8,
    levels: int = 10,
    mat=None,
    parent=None,
) -> bpy.types.Object:
    """Build a stylized sculpted 3D flame tongue tapering & twisting upward."""
    bm = bmesh.new()
    rings = []
    for li in range(levels):
        u = float(li) / float(levels)
        z = u * height
        swell = math.sin(min(1.0, u * 1.25) * math.pi * 0.88)
        r = max(0.004, radius * (0.42 + 0.72 * swell) * (1.0 - 0.85 * (u ** 1.4)))
        ang_off = u * twist_rad
        cx = math.sin(u * math.pi * 1.2) * lean_x
        cy = math.cos(u * math.pi * 0.9) * (lean_x * 0.35)
        ring = []
        for si in range(sides):
            a = (float(si) / float(sides)) * math.tau + ang_off
            flute = 1.0 + 0.24 * math.sin(a * 3.0)
            ring.append(bm.verts.new((cx + math.cos(a) * r * flute, cy + math.sin(a) * r * flute, z)))
        rings.append(ring)
    v_tip = bm.verts.new((lean_x * 0.9, 0.0, height))
    for li in range(levels - 1):
        for si in range(sides):
            sn = (si + 1) % sides
            bm.faces.new((rings[li][si], rings[li][sn], rings[li + 1][sn], rings[li + 1][si]))
    for si in range(sides):
        sn = (si + 1) % sides
        bm.faces.new((rings[-1][si], rings[-1][sn], v_tip))
    bm.faces.new(list(reversed(rings[0])))
    return finalize_bmesh(name, bm, mat=mat, smooth=True, parent=parent)


def export_glb(filepath) -> pathlib.Path:
    """Export the current Blender scene to a Y-up binary glTF (.glb) with baked scene animation."""
    out_path = pathlib.Path(filepath)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        export_yup=True,
        export_animations=True,
        export_animation_mode="SCENE",
        export_bake_animation=True,
        export_materials="EXPORT",
    )
    return out_path


def render_preview(
    png_path,
    frame: int = 1,
    cam_loc=(1.55, -1.75, 1.25),
    cam_target=(0.0, 0.0, 0.35),
    res: int = 512,
) -> pathlib.Path:
    """Render a quick Blender EEVEE preview PNG on a dark tavern stage for visual inspection."""
    out_png = pathlib.Path(png_path)
    out_png.parent.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.frame_set(frame)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(out_png)

    # Dark moody tavern world
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    if not world.use_nodes:
        world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.028, 0.025, 0.036, 1.0)
        bg.inputs[1].default_value = 0.85

    # Temporary camera + key/rim lighting
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 42.0
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_obj.location = Vector(cam_loc)
    direction = (Vector(cam_target) - Vector(cam_loc)).normalized()
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    key_data = bpy.data.lights.new("PreviewKey", type="AREA")
    key_data.energy = 140.0
    key_data.color = (1.0, 0.90, 0.76)
    key_data.size = 2.0
    key_obj = bpy.data.objects.new("PreviewKey", key_data)
    scene.collection.objects.link(key_obj)
    key_obj.location = Vector((1.8, -2.0, 2.6))
    key_obj.rotation_euler = (Vector((0.0, 0.0, 0.2)) - key_obj.location).normalized().to_track_quat("-Z", "Y").to_euler()

    rim_data = bpy.data.lights.new("PreviewRim", type="POINT")
    rim_data.energy = 85.0
    rim_data.color = (0.55, 0.78, 1.0)
    rim_obj = bpy.data.objects.new("PreviewRim", rim_data)
    scene.collection.objects.link(rim_obj)
    rim_obj.location = Vector((-1.6, 1.8, 1.7))

    bpy.ops.render.render(write_still=True)

    # Cleanup temporary camera/lights so subsequent export stays clean if needed
    for tmp in (cam_obj, key_obj, rim_obj):
        bpy.data.objects.remove(tmp, do_unlink=True)
    return out_png
