"""
Blender 5.3 headless procedural sculpting generator for LIALO's Upgraded Ghost Companion (V2):
Overhauls all 6 modular Ghost GLBs in D:/downpour-godot/assets/models/ to match the exact
attachment hierarchy, UV contract, and mesh-name material-override keywords in
scripts/battle_table_3d.gd (lines 5500-5688):
  1. ghost_shroud.glb  (ShroudOuter*, ShroudInner*, ShroudClasp + ClaspBrassFiligree, ClaspEmeraldGem)
  2. ghost_skull.glb   (Cranium*, Zygomatic*, Nasal*, *Shadow*, MaxillaTooth_* + CrownScarGlow, SpectralWisp_*)
  3. ghost_jaw.glb     (Mandible*, Chin*, MandibleTooth_*)
  4. ghost_hand_r.glb  (GhostSleeve*, Spectral*, Finger_*, Thumb*)
  5. ghost_hand_l.glb  (GhostSleeve*, Spectral*, Finger_*, Thumb*)
  6. ghost_lantern.glb (LanternCore + octagonal gothic wrought-iron hood/base/struts/filigree/bail/glass)

Orientation & Coordinate Contract (with export_yup=True):
  - Blender (+X, -Y, +Z) -> Godot (+X, +Z, +Y)
  - Front of Ghost faces Blender -Y (= Godot +Z, directly toward player).
  - Shroud/Sleeve UV contract: Godot phantom_shader reads UV.y = 0 at hood peak/shoulder -> 1 at tattered hem.
    Because glTF flips V relative to Blender, Blender UV.y = 1.0 at top -> 0.0 at bottom!

Studio Preview PNG rendered to:
  C:/Users/arnos/.gemini/antigravity/brain/a20e3f18-d942-46fa-80e3-721c54108b6d/scratch/preview_ghost_v2.png

Run via:
  & "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_ghost_v2.py
"""
import math
import pathlib
import bpy
import bmesh
from mathutils import Vector, Euler

OUT_DIR = pathlib.Path(r"D:\downpour-godot\assets\models")
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\scratch\preview_ghost_v2.png"
)


# =============================================================================
# MATH & SCENE UTILITIES
# =============================================================================

def clamp(x: float, lo: float, hi: float) -> float:
    return lo if x < lo else (hi if x > hi else x)


def smoothstep(e0: float, e1: float, x: float) -> float:
    if abs(e1 - e0) < 1e-9:
        return 0.0 if x < e0 else 1.0
    t = clamp((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    return scene


def make_mat(
    name: str,
    color: tuple,
    metallic: float = 0.0,
    roughness: float = 0.50,
    emission: tuple = (0.0, 0.0, 0.0),
    emit_str: float = 0.0,
    alpha: float = 1.0,
    coat: float = 0.0,
    subsurface: float = 0.0,
    double_sided: bool = False,
):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = not double_sided
    if alpha < 0.999 and hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = float(metallic)
    bsdf.inputs["Roughness"].default_value = float(roughness)
    if "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = float(alpha)
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = float(coat)
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = float(subsurface)
    if emit_str > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = float(emit_str)
    return mat


def box_uv_bm(bm: bmesh.types.BMesh, scale: float = 1.0):
    uv_layer = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x * scale, co.y * scale
            elif ax >= ay and ax >= az:
                u, v = co.y * scale, co.z * scale
            else:
                u, v = co.x * scale, co.z * scale
            loop[uv_layer].uv = (u, v)


def link_bm(
    name: str,
    bm: bmesh.types.BMesh,
    mat=None,
    parent=None,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    smooth: bool = True,
    auto_uv: bool = True,
    uv_scale: float = 4.0,
    recalc_normals: bool = True,
):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    if recalc_normals and len(bm.faces) > 0:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    if auto_uv:
        box_uv_bm(bm, scale=uv_scale)
    mesh = bpy.data.meshes.new(name + "_M")
    bm.to_mesh(mesh)
    bm.free()
    if mat is not None:
        if isinstance(mat, (list, tuple)):
            for m in mat:
                mesh.materials.append(m)
        else:
            mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    obj.location = loc
    obj.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
    return obj


def add_subsurf(obj, levels: int = 1):
    mod = obj.modifiers.new(name="Subsurf", type="SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return mod


def add_bevel(obj, width: float = 0.002, segments: int = 2, angle_deg: float = 35.0):
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle_deg)
    mod.use_clamp_overlap = True
    return mod


def create_grid_cloth(
    name: str,
    nu: int,
    nv: int,
    eval_fn,
    uv_fn=None,
    mat=None,
    parent=None,
    closed_u: bool = False,
    smooth: bool = True,
    recalc_normals: bool = True,
    flip_normals: bool = False,
    solidify: float = 0.0,
):
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    grid = []
    for vi in range(nv + 1):
        v = float(vi) / float(nv)
        row = []
        u_count = nu if closed_u else nu + 1
        for ui in range(u_count):
            u = float(ui) / float(nu)
            pos = eval_fn(u, v)
            row.append((bm.verts.new(pos), u, v))
        grid.append(row)

    for vi in range(nv):
        r0, r1 = grid[vi], grid[vi + 1]
        for ui in range(nu):
            un = (ui + 1) % nu if closed_u else (ui + 1)
            u0 = float(ui) / float(nu)
            u1 = float(ui + 1) / float(nu)
            v0 = float(vi) / float(nv)
            v1 = float(vi + 1) / float(nv)
            verts = (r0[ui][0], r0[un][0], r1[un][0], r1[ui][0])
            if flip_normals:
                verts = (verts[0], verts[3], verts[2], verts[1])
            try:
                f = bm.faces.new(verts)
                uvs = (
                    uv_fn(u0, v0) if uv_fn else (u0, 1.0 - v0),
                    uv_fn(u1, v0) if uv_fn else (u1, 1.0 - v0),
                    uv_fn(u1, v1) if uv_fn else (u1, 1.0 - v1),
                    uv_fn(u0, v1) if uv_fn else (u0, 1.0 - v1),
                )
                if flip_normals:
                    uvs = (uvs[0], uvs[3], uvs[2], uvs[1])
                for loop, uv in zip(f.loops, uvs):
                    loop[uv_layer].uv = uv
            except ValueError:
                pass

    if solidify > 0.0:
        if recalc_normals and len(bm.faces) > 0:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.solidify(bm, geom=bm.faces[:] + bm.verts[:] + bm.edges[:], thickness=solidify)
        recalc_normals = True

    return link_bm(
        name, bm, mat=mat, parent=parent, smooth=smooth, auto_uv=False, recalc_normals=recalc_normals
    )


def create_tube(
    name: str,
    points: list,
    radii,
    mat=None,
    parent=None,
    segs: int = 12,
    cap_ends: bool = True,
    smooth: bool = True,
    scale_xy_fn=None,
    uv_v_range=None,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
):
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    pts = [Vector(p) for p in points]
    n_pts = len(pts)
    rads = [float(radii)] * n_pts if isinstance(radii, (int, float)) else [float(r) for r in radii]

    tangents = []
    for i in range(n_pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n_pts - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        t = Vector((0, 0, 1)) if t.length < 1e-7 else t.normalized()
        tangents.append(t)

    ref = Vector((1, 0, 0)) if abs(tangents[0].x) < 0.85 else Vector((0, 1, 0))
    normal = tangents[0].cross(ref).normalized()
    binormal = tangents[0].cross(normal).normalized()

    rings = []
    for i in range(n_pts):
        if i > 0:
            rot_q = tangents[i - 1].rotation_difference(tangents[i])
            normal = (rot_q @ normal).normalized()
            binormal = tangents[i].cross(normal).normalized()
        sx, sy = scale_xy_fn(i, n_pts) if scale_xy_fn is not None else (1.0, 1.0)
        r = rads[i]
        ring = []
        for si in range(segs):
            ang = (float(si) / float(segs)) * math.tau
            offset = normal * (math.cos(ang) * r * sx) + binormal * (math.sin(ang) * r * sy)
            ring.append(bm.verts.new(pts[i] + offset))
        rings.append(ring)

    v_start, v_end = uv_v_range if uv_v_range is not None else (1.0, 0.0)
    for i in range(n_pts - 1):
        r0, r1 = rings[i], rings[i + 1]
        t0 = float(i) / max(1, n_pts - 1)
        t1 = float(i + 1) / max(1, n_pts - 1)
        vv0 = v_start + (v_end - v_start) * t0
        vv1 = v_start + (v_end - v_start) * t1
        for si in range(segs):
            sn = (si + 1) % segs
            u0 = float(si) / float(segs)
            u1 = float(si + 1) / float(segs)
            try:
                f = bm.faces.new((r0[si], r0[sn], r1[sn], r1[si]))
                for loop, uv in zip(f.loops, ((u0, vv0), (u1, vv0), (u1, vv1), (u0, vv1))):
                    loop[uv_layer].uv = uv
            except ValueError:
                pass

    if cap_ends:
        for cap_verts, vv in ((list(reversed(rings[0])), v_start), (rings[-1], v_end)):
            try:
                f = bm.faces.new(cap_verts)
                for loop in f.loops:
                    loop[uv_layer].uv = (0.5, vv)
            except ValueError:
                pass

    return link_bm(
        name, bm, mat=mat, parent=parent, loc=loc, rot=rot, smooth=smooth,
        auto_uv=(uv_v_range is None), uv_scale=6.0,
    )


def create_lathe(
    name: str,
    profile_rz: list,
    mat=None,
    parent=None,
    segs: int = 24,
    smooth: bool = True,
    cap_bottom: bool = True,
    cap_top: bool = True,
    radial_fn=None,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
):
    bm = bmesh.new()
    rings = []
    n_prof = len(profile_rz)
    for ri, (r_base, z_base) in enumerate(profile_rz):
        ring_verts = []
        for si in range(segs):
            ang = (float(si) / float(segs)) * math.tau
            if radial_fn is not None:
                px, py, pz = radial_fn(r_base, z_base, ang, ri, n_prof)
            else:
                px = math.cos(ang) * r_base
                py = math.sin(ang) * r_base
                pz = z_base
            ring_verts.append(bm.verts.new((px, py, pz)))
        rings.append(ring_verts)

    for ri in range(n_prof - 1):
        r0, r1 = rings[ri], rings[ri + 1]
        for si in range(segs):
            sn = (si + 1) % segs
            try:
                bm.faces.new((r0[si], r0[sn], r1[sn], r1[si]))
            except ValueError:
                pass

    if cap_bottom and profile_rz[0][0] > 1e-5:
        try:
            bm.faces.new(list(reversed(rings[0])))
        except ValueError:
            pass
    if cap_top and profile_rz[-1][0] > 1e-5:
        try:
            bm.faces.new(rings[-1])
        except ValueError:
            pass

    return link_bm(name, bm, mat=mat, parent=parent, loc=loc, rot=rot, smooth=smooth, uv_scale=6.0)


def create_sphere(
    name: str,
    radius: float,
    mat=None,
    parent=None,
    loc=(0.0, 0.0, 0.0),
    scale=(1.0, 1.0, 1.0),
    rot=(0.0, 0.0, 0.0),
    segs: int = 18,
    rings: int = 12,
    smooth: bool = True,
    uv_const_v=None,
):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    if uv_const_v is not None:
        uv_layer = bm.loops.layers.uv.verify()
        for f in bm.faces:
            for loop in f.loops:
                loop[uv_layer].uv = (0.5, uv_const_v)
    return link_bm(
        name, bm, mat=mat, parent=parent, loc=loc, rot=rot, smooth=smooth,
        auto_uv=(uv_const_v is None), uv_scale=6.0,
    )


def create_box(
    name: str,
    size_xyz: tuple,
    mat=None,
    parent=None,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    bevel_w: float = 0.0,
    smooth: bool = True,
):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size_xyz, verts=bm.verts)
    if bevel_w > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel_w, segments=2, affect="EDGES")
    return link_bm(name, bm, mat=mat, parent=parent, loc=loc, rot=rot, smooth=smooth, uv_scale=6.0)


def create_extruded_poly(
    name: str,
    pts_2d: list,
    depth: float,
    mat=None,
    parent=None,
    axis: str = "Y",
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    bevel_w: float = 0.0014,
    smooth: bool = True,
):
    bm = bmesh.new()
    half = depth * 0.5
    front_v, back_v = [], []
    for x, y in pts_2d:
        if axis == "Z":
            front_v.append(bm.verts.new((x, y, half)))
            back_v.append(bm.verts.new((x, y, -half)))
        elif axis == "Y":
            front_v.append(bm.verts.new((x, half, y)))
            back_v.append(bm.verts.new((x, -half, y)))
        else:
            front_v.append(bm.verts.new((half, x, y)))
            back_v.append(bm.verts.new((-half, x, y)))
    bm.faces.new(front_v)
    bm.faces.new(list(reversed(back_v)))
    n = len(pts_2d)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front_v[i], back_v[i], back_v[j], front_v[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel_w > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel_w, segments=2, affect="EDGES")
    return link_bm(name, bm, mat=mat, parent=parent, loc=loc, rot=rot, smooth=smooth, uv_scale=6.0)


def create_sculpted_tooth(
    name: str,
    width: float,
    depth: float,
    height: float,
    mat,
    parent=None,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    is_canine: bool = False,
    is_upper: bool = True,
    chip: float = 0.0,
):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in bm.verts:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        crown_t = -nz if is_upper else nz
        w_mod = 1.0 - 0.24 * smoothstep(0.1, 1.0, -crown_t)
        if is_canine:
            w_mod *= 1.0 - 0.58 * smoothstep(0.25, 1.0, crown_t)
        else:
            w_mod *= 1.0 + 0.06 * smoothstep(0.2, 0.9, crown_t)
        d_mod = 1.0 - 0.55 * smoothstep(0.35, 1.0, crown_t)
        ny = ny * 1.08 if ny < 0.0 else ny * 0.80
        px = nx * (width * 0.5) * w_mod
        py = ny * (depth * 0.5) * d_mod
        pz = nz * (height * 0.5)
        if chip > 0.0 and crown_t > 0.45 and nx > 0.15:
            pz += (1.0 if is_upper else -1.0) * chip * smoothstep(0.45, 0.95, crown_t)
        v.co = Vector((px, py, pz))
    return link_bm(name, bm, mat=mat, parent=parent, loc=loc, rot=rot, smooth=True, uv_scale=12.0)


def make_ghost_materials():
    return {
        "shroud": make_mat(
            "GhostShroudPhantom", (0.10, 0.42, 0.64), roughness=0.34, alpha=0.52,
            emission=(0.18, 0.70, 0.92), emit_str=0.36, double_sided=True
        ),
        "shroud_inner": make_mat(
            "GhostShroudInner", (0.04, 0.18, 0.32), roughness=0.42, alpha=0.62,
            emission=(0.08, 0.44, 0.66), emit_str=0.22, double_sided=True
        ),
        "rib_ectoplasm": make_mat(
            "GhostRibEctoplasm", (0.50, 0.92, 1.0), roughness=0.24, alpha=0.62,
            emission=(0.34, 0.86, 1.0), emit_str=0.90, double_sided=True
        ),
        "clasp_frame": make_mat(
            "ClaspSilverFiligree", (0.76, 0.92, 1.0), metallic=0.90, roughness=0.20,
            emission=(0.24, 0.76, 0.94), emit_str=0.45
        ),
        "brass": make_mat(
            "AntiqueFiligreeBrass", (0.80, 0.56, 0.16), metallic=0.93, roughness=0.22, coat=0.15
        ),
        "emerald": make_mat(
            "ClaspEmerald", (0.03, 0.68, 0.30), metallic=0.06, roughness=0.09, coat=0.75,
            emission=(0.04, 0.86, 0.40), emit_str=2.0
        ),
        "bone": make_mat(
            "GhostSkullBone", (0.84, 0.78, 0.66), metallic=0.03, roughness=0.56, subsurface=0.08,
            emission=(0.05, 0.13, 0.17), emit_str=0.14
        ),
        "tooth": make_mat(
            "GhostToothEnamel", (0.94, 0.90, 0.80), metallic=0.04, roughness=0.26, coat=0.22,
            emission=(0.04, 0.09, 0.12), emit_str=0.08
        ),
        "shadow": make_mat(
            "GhostCavityShadow", (0.008, 0.012, 0.022), metallic=0.0, roughness=0.96
        ),
        "scar_glow": make_mat(
            "GhostCrownScarGlow", (0.38, 0.95, 1.0), metallic=0.0, roughness=0.14,
            emission=(0.36, 0.94, 1.0), emit_str=3.4
        ),
        "wisp_hair": make_mat(
            "GhostSpectralHair", (0.40, 0.90, 1.0), metallic=0.0, roughness=0.22, alpha=0.44,
            emission=(0.34, 0.88, 1.0), emit_str=1.25, double_sided=True
        ),
        "spec_hand": make_mat(
            "GhostSpectralHand", (0.72, 0.95, 1.0), metallic=0.05, roughness=0.28, alpha=0.78,
            emission=(0.38, 0.88, 1.0), emit_str=0.90
        ),
        "iron": make_mat(
            "LanternWroughtIron", (0.08, 0.09, 0.11), metallic=0.88, roughness=0.38
        ),
        "lantern_glass": make_mat(
            "LanternSpiritGlass", (0.44, 0.90, 1.0), metallic=0.02, roughness=0.12, alpha=0.36,
            emission=(0.28, 0.82, 0.96), emit_str=1.05, double_sided=True
        ),
        "lantern_core": make_mat(
            "LanternSoulFlame", (0.86, 0.98, 1.0), metallic=0.0, roughness=0.08,
            emission=(1.0, 0.86, 0.40), emit_str=5.2
        ),
        "preview_eye": make_mat(
            "PreviewEyeCyan", (0.48, 0.96, 1.0), roughness=0.08,
            emission=(0.36, 0.92, 1.0), emit_str=4.5
        ),
        "preview_pupil": make_mat(
            "PreviewPupilGold", (1.0, 0.96, 0.58), roughness=0.04,
            emission=(1.0, 0.88, 0.34), emit_str=6.0
        ),
        "preview_core": make_mat(
            "PreviewSoulCore", (0.38, 0.92, 1.0), roughness=0.20, alpha=0.24,
            emission=(0.38, 0.92, 1.0), emit_str=2.0
        ),
    }


def export_selected_glb(objs: list, filepath: pathlib.Path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]
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
    sz_kb = filepath.stat().st_size / 1024.0 if filepath.exists() else 0.0
    print(f"[GHOST_V2_EXPORTED] {filepath.name:20s} ({sz_kb:.1f} KB, {len(objs)} meshes)")


# =============================================================================
# 1. GHOST SHROUD (Refined Silky Layered Cloak, Graceful Peaked Hood, Mantle, Ribcage, Clasp)
# =============================================================================

def build_ghost_shroud(M: dict, parent=None) -> list:
    objs = []

    # --- A. Main Layered Tattered Medieval Wraith Cloak & Seamless Organic Peaked Hood ---
    def outer_cloak_eval(u: float, v: float):
        # v = 0.0 at hood peak -> 1.0 at tattered lower hem
        t_up = 1.0 - v  # 0.0 bottom -> 1.0 peak
        ang = u * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        front_w = max(0.0, sa)   # Blender -Y = front
        back_w = max(0.0, -sa)

        z_bl = -0.10 + t_up * 1.02  # -0.10 .. +0.92

        # Smooth, organic gothic silhouette: billowing torn skirt -> slim waist -> draped shoulders -> graceful peaked hood
        if t_up < 0.30:
            tt = smoothstep(0.0, 0.30, t_up)
            rx = 0.145 + (0.168 - 0.145) * tt
            ry = 0.125 + (0.142 - 0.125) * tt
        elif t_up < 0.56:
            tt = smoothstep(0.30, 0.56, t_up)
            waist_cinch = -0.018 * math.sin(tt * math.pi)
            rx = 0.168 + (0.212 - 0.168) * smoothstep(0.0, 1.0, tt) + waist_cinch
            ry = 0.142 + (0.158 - 0.142) * smoothstep(0.0, 1.0, tt) + waist_cinch * 0.7
        elif t_up < 0.67:
            tt = smoothstep(0.56, 0.67, t_up)
            rx = 0.212 + (0.118 - 0.212) * smoothstep(0.0, 1.0, tt)
            ry = 0.158 + (0.114 - 0.158) * smoothstep(0.0, 1.0, tt)
        elif t_up < 0.90:
            tt = smoothstep(0.67, 0.90, t_up)
            arch = math.sin(tt * math.pi)
            # Clean, naturally proportioned medieval cowl framing the skull (not ballooned!)
            rx = 0.118 + (0.060 - 0.118) * tt + arch * 0.032
            ry = 0.114 + (0.072 - 0.114) * tt + arch * 0.034
        else:
            tt = smoothstep(0.90, 1.0, t_up)
            rx = 0.060 * (1.0 - tt) + 0.004 * tt
            ry = 0.072 * (1.0 - tt) + 0.004 * tt

        # Silky vertical cloth pleats (deep sculptural drapery folds, zero faceted noise!)
        pleat_env = smoothstep(0.66, 0.16, t_up)
        pleat = (
            0.022 * math.sin(ang * 8.0 + t_up * 3.2)
            + 0.011 * math.cos(ang * 13.0 - t_up * 4.4)
        ) * pleat_env

        # Soft cowl drapery gathers along back & sides of hood
        hood_fold_env = smoothstep(0.65, 0.76, t_up) * smoothstep(0.95, 0.82, t_up)
        hood_fold = 0.0075 * math.sin(ang * 7.0 + t_up * 7.5) * hood_fold_env * (1.0 - 0.85 * front_w)

        # Flowing ragged lower cloak ribbons billowing gently backward
        tail_mask = (max(0.0, 1.0 - t_up * 2.40) ** 1.4)
        hem_tatter = (
            0.078 * math.sin(ang * 6.0 + 0.25)
            + 0.042 * math.cos(ang * 9.0 - 0.5)
            + 0.020 * math.sin(ang * 13.0 + 0.8)
        ) * tail_mask
        breeze_y = 0.052 * (tail_mask ** 1.15) + 0.018 * math.sin(t_up * 6.5 + ang * 2.0) * tail_mask
        breeze_x = 0.018 * (tail_mask ** 1.2) * math.sin(ang + 0.4)

        px = ca * max(0.004, rx + pleat + hood_fold) + breeze_x
        py = -sa * max(0.004, ry + pleat * 0.85 + hood_fold) + breeze_y
        pz = z_bl + hem_tatter

        # Single graceful back-sweeping medieval gothic hood peak!
        if t_up > 0.70:
            peak_t = (t_up - 0.70) / 0.30
            py += (peak_t ** 1.75) * 0.145
            pz += (peak_t ** 1.7) * 0.022 * back_w

        # Clean Gothic Lancet Face Aperture cleanly framing skull at (0, -0.048, 0.675)!
        if 0.63 < t_up < 0.90 and front_w > 0.16:
            vt = clamp((t_up - 0.63) / 0.27, 0.0, 1.0)
            arch_h = math.sin(vt * math.pi) ** 0.80
            open_w = smoothstep(0.22, 0.82, front_w) * arch_h
            # Recess opening cleanly back behind skull plane
            py += open_w * 0.148
            px *= 1.0 + 0.08 * arch_h * (1.0 - open_w)
            # Crisp forward-swept gothic cowl overhang framing brow & temples
            brow_overhang = math.exp(-((vt - 0.78) / 0.18) ** 2) * math.exp(-((front_w - 0.55) / 0.30) ** 2)
            py -= brow_overhang * 0.042
            pz += brow_overhang * 0.014
            # Turned rolled cowl cheek margin catching bright cyan rim light
            cowl_lip = math.exp(-((front_w - 0.28) / 0.11) ** 2) * arch_h
            py -= cowl_lip * 0.026
            px += math.copysign(cowl_lip * 0.008, ca)

        # Throat tuck directly under ornate clasp at (0, -0.116, 0.564)
        if 0.46 < t_up < 0.66 and front_w > 0.55:
            collar_t = smoothstep(0.46, 0.62, t_up) * smoothstep(0.55, 0.96, front_w)
            py += collar_t * 0.016 * math.exp(-(ca / 0.18) ** 2)

        return (px, py, pz)

    def shroud_uv(u: float, v: float):
        return (u, 1.0 - v)

    shroud_outer = create_grid_cloth(
        "ShroudOuter_Cloak", 88, 60, outer_cloak_eval, uv_fn=shroud_uv,
        mat=M["shroud"], parent=parent, closed_u=True, smooth=True
    )
    add_subsurf(shroud_outer, levels=1)
    objs.append(shroud_outer)

    # --- B. Asymmetric Layered Medieval Shoulder Mantle (Silky Flowing Capelet) ---
    def mantle_eval(u: float, v: float):
        ang = math.pi * 0.57 + u * (math.tau - 0.34)
        ca, sa = math.cos(ang), math.sin(ang)

        asym_len = 0.23 + 0.068 * max(0.0, -ca) + 0.052 * max(0.0, -sa) - 0.042 * max(0.0, ca)
        tatter_edge = (
            0.030 * math.sin(u * math.tau * 7.0 + 0.4)
            + 0.016 * math.cos(u * math.tau * 12.0)
        ) * (v ** 1.65)

        z_top = 0.586 + 0.016 * max(0.0, -sa)
        pz = z_top - v * asym_len + tatter_edge

        rx = 0.114 + 0.132 * (v ** 0.72)
        ry = 0.106 + 0.098 * (v ** 0.78)
        fold = (0.015 * math.sin(u * math.tau * 10.0 + v * 2.2) + 0.006 * math.cos(u * math.tau * 16.0)) * (v ** 0.85)
        flare = 0.022 * (v ** 1.8)
        px = ca * (rx + fold + flare)
        py = -sa * (ry + fold * 0.85 + flare * 0.8) + 0.014 * (v ** 1.4)
        return (px, py, pz)

    def mantle_uv(u: float, v: float):
        return (u, 1.0 - (0.18 + v * 0.62))

    mantle = create_grid_cloth(
        "ShroudOuter_Mantle", 72, 24, mantle_eval, uv_fn=mantle_uv,
        mat=M["shroud"], parent=parent, closed_u=False, smooth=True
    )
    add_subsurf(mantle, levels=1)
    objs.append(mantle)

    # --- C. Flowing Sculpted Tattered Hem Ribbons ---
    for ri in range(7):
        ang = (float(ri) / 7.0) * math.tau + 0.35
        ca, sa = math.cos(ang), math.sin(ang)
        r_len = 0.23 + 0.07 * math.sin(ri * 2.3)
        r_w = 0.028 + 0.010 * math.cos(ri * 1.7)

        def ribbon_eval(u, v, _ca=ca, _sa=sa, _rlen=r_len, _rw=r_w, _ri=ri):
            un = (u - 0.5) * 2.0
            width_t = _rw * (1.0 - 0.88 * (v ** 1.25))
            rad = 0.158 + 0.032 * math.sin(v * math.pi * 0.9 + _ri) + 0.020 * v
            swirl_ang = math.atan2(_sa, _ca) + 0.26 * v * (1.0 if _ri % 2 == 0 else -1.0)
            tx = -math.sin(swirl_ang)
            ty = -math.cos(swirl_ang)
            cx = math.cos(swirl_ang) * rad
            cy = -math.sin(swirl_ang) * rad + 0.036 * (v ** 1.3)
            pz = 0.21 - v * _rlen
            return (cx + tx * un * width_t, cy + ty * un * width_t, pz)

        rib = create_grid_cloth(
            f"ShroudOuter_HemRibbon_{ri}", 6, 14, ribbon_eval,
            uv_fn=lambda u, v: (u, 1.0 - (0.52 + v * 0.44)),
            mat=M["shroud"], parent=parent, closed_u=False, smooth=True
        )
        objs.append(rib)

    # --- D. Inner Spectral Hood/Cloak Lining (inward-facing so front camera sees shadowed cowl depth) ---
    def inner_lining_eval(u: float, v: float):
        px, py, pz = outer_cloak_eval(u, v)
        return (px * 0.92, py * 0.92 + 0.012, pz + 0.005)

    shroud_inner = create_grid_cloth(
        "ShroudInner_Lining", 48, 30, inner_lining_eval, uv_fn=shroud_uv,
        mat=M["shroud_inner"], parent=parent, closed_u=True, smooth=True,
        recalc_normals=False, flip_normals=True,
    )
    objs.append(shroud_inner)

    # --- E. Subtle Ghostly Anatomical Ribcage, Sternum & Collarbones inside the Chest (ShroudInner*) ---
    sternum_pts = [
        (0.0, -0.068, 0.560),
        (0.0, -0.076, 0.522),
        (0.0, -0.078, 0.480),
        (0.0, -0.072, 0.434),
        (0.0, -0.062, 0.400),
    ]
    objs.append(create_tube(
        "ShroudInner_Sternum", sternum_pts, [0.013, 0.011, 0.010, 0.0085, 0.0045],
        mat=M["rib_ectoplasm"], parent=parent, segs=10,
        scale_xy_fn=lambda i, n: (1.50, 0.40), uv_v_range=(0.72, 0.62)
    ))
    spine_pts = [
        (0.0, 0.056, 0.340),
        (0.0, 0.064, 0.420),
        (0.0, 0.066, 0.500),
        (0.0, 0.050, 0.575),
        (0.0, 0.016, 0.625),
    ]
    objs.append(create_tube(
        "ShroudInner_Spine", spine_pts, [0.0095, 0.0115, 0.0125, 0.0115, 0.0095],
        mat=M["rib_ectoplasm"], parent=parent, segs=10, uv_v_range=(0.60, 0.74)
    ))
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        clav_pts = [
            (sx * 0.014, -0.066, 0.562),
            (sx * 0.056, -0.070, 0.570),
            (sx * 0.104, -0.050, 0.566),
            (sx * 0.140, -0.020, 0.554),
        ]
        objs.append(create_tube(
            f"ShroudInner_Clavicle_{s_ch}", clav_pts, [0.0064, 0.0058, 0.0056, 0.0068],
            mat=M["rib_ectoplasm"], parent=parent, segs=8, uv_v_range=(0.74, 0.72)
        ))
    rib_specs = [
        (0.544, 0.530, 0.095, -0.072, 0.0052, True),
        (0.510, 0.492, 0.110, -0.076, 0.0054, True),
        (0.476, 0.454, 0.116, -0.074, 0.0052, True),
        (0.440, 0.416, 0.112, -0.066, 0.0048, True),
        (0.404, 0.380, 0.100, -0.052, 0.0042, False),
    ]
    for r_idx, (zb, zf, wx, fy, rr, attached) in enumerate(rib_specs):
        for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
            pts = [
                (sx * 0.012, 0.062, zb),
                (sx * (wx * 0.65), 0.054, zb - 0.004),
                (sx * wx, 0.006, (zb + zf) * 0.5 - 0.004),
                (sx * (wx * 0.82), fy * 0.72, zf - 0.006),
            ]
            if attached:
                pts.append((sx * 0.014, fy, zf))
            else:
                pts.append((sx * 0.050, fy * 0.85, zf - 0.012))
            objs.append(create_tube(
                f"ShroudInner_Rib_{s_ch}_{r_idx}", pts,
                [rr * 0.85, rr, rr * 1.05, rr * 0.95, rr * 0.65],
                mat=M["rib_ectoplasm"], parent=parent, segs=8,
                scale_xy_fn=lambda i, n: (0.55, 1.35),
                uv_v_range=(0.68 - r_idx * 0.03, 0.64 - r_idx * 0.03),
            ))

    # --- F. Ornate Filigree Brass-and-Emerald Cloak Clasp at Throat (0.0, -0.116, 0.562) ---
    clasp_loc = (0.0, -0.116, 0.562)
    clasp_pts_2d = [
        (0.000,  0.032), (0.008,  0.016), (0.022,  0.022), (0.016,  0.009),
        (0.038,  0.004), (0.020, -0.006), (0.025, -0.018), (0.010, -0.014),
        (0.000, -0.034), (-0.010, -0.014), (-0.025, -0.018), (-0.020, -0.006),
        (-0.038,  0.004), (-0.016,  0.009), (-0.022,  0.022), (-0.008,  0.016),
    ]
    objs.append(create_extruded_poly(
        "ShroudClasp", clasp_pts_2d, depth=0.009, mat=M["clasp_frame"], parent=parent,
        axis="Y", loc=clasp_loc, bevel_w=0.0016, smooth=True
    ))
    bezel_pts = [
        (
            clasp_loc[0] + math.cos(i * math.tau / 20.0) * 0.0155,
            clasp_loc[1] - 0.0045,
            clasp_loc[2] + math.sin(i * math.tau / 20.0) * 0.0185,
        )
        for i in range(21)
    ]
    objs.append(create_tube("ClaspBrassBezel", bezel_pts, 0.0028, mat=M["brass"], parent=parent, segs=8, cap_ends=False))
    for a_deg in (45.0, 135.0, 225.0, 315.0):
        ar = math.radians(a_deg)
        p0 = (clasp_loc[0] + math.cos(ar) * 0.016, clasp_loc[1] - 0.003, clasp_loc[2] + math.sin(ar) * 0.019)
        p1 = (clasp_loc[0] + math.cos(ar) * 0.011, clasp_loc[1] - 0.010, clasp_loc[2] + math.sin(ar) * 0.013)
        objs.append(create_tube(f"ClaspBrassProng_{int(a_deg)}", [p0, p1], [0.0022, 0.0014], mat=M["brass"], parent=parent, segs=6))

    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        scroll_pts = [
            (sx * 0.016, clasp_loc[1] - 0.004, clasp_loc[2] + 0.008),
            (sx * 0.036, clasp_loc[1] - 0.002, clasp_loc[2] + 0.016),
            (sx * 0.054, clasp_loc[1] + 0.006, clasp_loc[2] + 0.006),
            (sx * 0.044, clasp_loc[1] + 0.002, clasp_loc[2] - 0.010),
            (sx * 0.026, clasp_loc[1] - 0.003, clasp_loc[2] - 0.006),
        ]
        objs.append(create_tube(
            f"ClaspBrassScroll_{s_ch}", scroll_pts, [0.0026, 0.0032, 0.0028, 0.0022, 0.0018],
            mat=M["brass"], parent=parent, segs=8
        ))
        chain_pts = [
            (sx * 0.034, clasp_loc[1] - 0.001, clasp_loc[2] + 0.004),
            (sx * 0.068, clasp_loc[1] + 0.010, clasp_loc[2] - 0.016),
            (sx * 0.102, clasp_loc[1] + 0.026, clasp_loc[2] - 0.010),
            (sx * 0.126, clasp_loc[1] + 0.048, clasp_loc[2] + 0.010),
        ]
        objs.append(create_tube(f"ClaspBrassChain_{s_ch}", chain_pts, 0.0026, mat=M["brass"], parent=parent, segs=8))
        objs.append(create_sphere(
            f"ClaspBrassShoulderPin_{s_ch}", 0.0075, mat=M["brass"], parent=parent,
            loc=(sx * 0.126, clasp_loc[1] + 0.048, clasp_loc[2] + 0.010), segs=10, rings=8
        ))

    gem_prof = [
        (0.001, -0.014), (0.011, -0.009), (0.0135, 0.000), (0.011, 0.009), (0.001, 0.014),
    ]
    gem = create_lathe(
        "ClaspEmeraldGem", gem_prof, mat=M["emerald"], parent=parent, segs=8, smooth=False,
        loc=(clasp_loc[0], clasp_loc[1] - 0.0072, clasp_loc[2]),
    )
    for v in gem.data.vertices:
        v.co.y *= 0.56
    gem.data.update()
    objs.append(gem)

    return objs


# =============================================================================
# 2. GHOST SKULL (Refined Haunted Orbits, Recessed Cheek Shadows, Sleek Wisps)
# =============================================================================

def build_ghost_skull(M: dict, parent=None) -> list:
    objs = []

    def skull_eval(nx: float, ny: float, nz: float):
        fwd = -ny
        rx = 0.062
        ry = 0.075 if ny > 0.0 else 0.065
        rz = 0.076 if nz > 0.0 else 0.060

        if nz > 0.0:
            rx *= 1.0 + 0.08 * math.sin(min(1.0, nz) * math.pi)
        else:
            t_low = min(1.0, -nz)
            rx *= 1.0 - 0.37 * (t_low ** 1.15)
            if fwd < 0.12:
                ry *= 1.0 - 0.34 * t_low

        x = nx * rx
        y = ny * ry
        z = nz * rz

        if ny > 0.25 and nz < -0.05:
            back_t = smoothstep(0.25, 0.85, ny) * smoothstep(-0.05, -0.75, nz)
            y -= back_t * 0.017
            z += back_t * 0.012

        side_t = (
            smoothstep(0.46, 0.90, abs(nx))
            * smoothstep(-0.22, 0.48, fwd)
            * (1.0 - smoothstep(0.20, 0.56, abs(nz - 0.15)))
        )
        x -= math.copysign(side_t * 0.0105, nx)

        # Expressive Furrowed Supraorbital Brow Ridge
        if fwd > 0.12:
            f_mask = smoothstep(0.12, 0.58, fwd)
            brow_z_target = 0.275 + 0.095 * smoothstep(0.08, 0.56, abs(nx)) - 0.035 * smoothstep(0.56, 0.82, abs(nx))
            brow_band = math.exp(-((nz - brow_z_target) / 0.095) ** 2) * smoothstep(0.0, 0.72, 0.82 - abs(nx))
            glabella_dip = 1.0 - 0.28 * math.exp(-(nx / 0.09) ** 2)
            y -= brow_band * glabella_dip * 0.0165 * f_mask
            z += brow_band * 0.0025 * f_mask
            furrow = math.exp(-((abs(nx) - 0.065) / 0.032) ** 2) * math.exp(-((nz - 0.34) / 0.10) ** 2) * f_mask
            y += furrow * 0.0028

        # Deeply Sculpted Orbital Sockets around (+-0.0245, -0.051, +0.008)
        orbit_depth = 0.0
        orbit_rim = 0.0
        for sx in (-1.0, 1.0):
            tilt_z = (abs(nx) - 0.36) * 0.085
            dx = (nx - sx * 0.385) / 0.235
            dz = (nz - 0.105 + tilt_z) / 0.205
            dist_sq = (abs(dx) ** 2.35 + abs(dz) ** 2.35) ** (1.0 / 2.35)
            if fwd > 0.22:
                f_mask = smoothstep(0.22, 0.54, fwd)
                hole = (1.0 - smoothstep(0.48, 1.04, dist_sq)) * f_mask
                rim = math.exp(-((dist_sq - 1.06) / 0.15) ** 2) * f_mask
                orbit_depth = max(orbit_depth, hole)
                orbit_rim = max(orbit_rim, rim)
        y += orbit_depth * 0.030
        y -= orbit_rim * 0.0054

        # Sculpted Nasal Bridge & Piriform Nasal Cavity
        if fwd > 0.32:
            f_mask = smoothstep(0.32, 0.68, fwd)
            nose_bridge = math.exp(-(nx / 0.095) ** 2) * math.exp(-((nz - 0.11) / 0.145) ** 2) * f_mask
            y -= nose_bridge * 0.0145
            nasal_w = 0.105 + 0.055 * smoothstep(-0.01, -0.26, nz)
            nd_x = nx / nasal_w
            nd_z = (nz - (-0.125)) / 0.145
            nd = (abs(nd_x) ** 2.1 + abs(nd_z) ** 2.3) ** (1.0 / 2.2)
            nasal_hole = (1.0 - smoothstep(0.40, 0.96, nd)) * f_mask
            y += nasal_hole * 0.025
            nasal_rim = math.exp(-((nd - 1.03) / 0.13) ** 2) * f_mask
            y -= nasal_rim * 0.0036

        # High Zygomatic Cheekbones & Sculpted Hollow Cheeks
        if fwd > 0.10:
            f_mask = smoothstep(0.10, 0.48, fwd)
            cheek = math.exp(-((abs(nx) - 0.57) / 0.155) ** 2) * math.exp(-((nz - (-0.10)) / 0.125) ** 2) * f_mask
            x += math.copysign(cheek * 0.0098, nx)
            y -= cheek * 0.0115
            z += cheek * 0.0022
            hollow = math.exp(-((abs(nx) - 0.51) / 0.165) ** 2) * math.exp(-((nz - (-0.36)) / 0.16) ** 2) * f_mask
            x -= math.copysign(hollow * 0.0096, nx)
            y += hollow * 0.0105

        if nz < -0.22 and fwd > 0.05:
            max_z = smoothstep(-0.22, -0.56, nz)
            max_f = smoothstep(0.05, 0.50, fwd)
            arch = math.exp(-(nx / 0.43) ** 2)
            y -= max_z * max_f * arch * 0.0165
            root_rib = math.cos(nx * 25.0) * 0.0015 * smoothstep(-0.38, -0.68, nz) * max_f * arch
            y -= root_rib

        if nz > 0.34:
            sag = math.exp(-(nx / 0.020) ** 2) * smoothstep(0.34, 0.64, nz) * (1.0 - smoothstep(-0.15, -0.58, ny))
            cor = math.exp(-((ny + 0.04) / 0.024) ** 2) * smoothstep(0.42, 0.78, nz)
            suture_d = max(sag, cor) * (0.62 + 0.38 * math.sin(nx * 145.0 + ny * 145.0))
            z -= suture_d * 0.0016

        # Weathered Diagonal Crown-Scar Fracture
        if fwd > 0.15 and nz > 0.22:
            t_sc = clamp((nz - 0.28) / 0.44, 0.0, 1.0)
            scar_cx = 0.23 - 0.20 * t_sc + 0.032 * math.sin(t_sc * 14.0)
            scar_dist = abs(nx - scar_cx)
            scar_env = smoothstep(0.25, 0.34, nz) * smoothstep(0.76, 0.64, nz) * smoothstep(0.18, 0.55, fwd)
            scar_groove = math.exp(-(scar_dist / 0.024) ** 2) * scar_env
            scar_lip = math.exp(-((scar_dist - 0.042) / 0.020) ** 2) * scar_env
            y += scar_groove * 0.0046
            z -= scar_groove * 0.0022
            y -= scar_lip * 0.0014

        return (x, y, z)

    bm_cran = bmesh.new()
    bmesh.ops.create_icosphere(bm_cran, subdivisions=5, radius=1.0)
    for v in bm_cran.verts:
        d = v.co.normalized()
        v.co = Vector(skull_eval(d.x, d.y, d.z))
    objs.append(link_bm("CraniumSculpt", bm_cran, mat=M["bone"], parent=parent, smooth=True, uv_scale=8.0))

    # Open Zygomatic Arches & Malar Crests ("zygomatic" -> bone_mat)
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        arch_pts = [
            (sx * 0.036, -0.046, -0.011),
            (sx * 0.053, -0.033, -0.012),
            (sx * 0.060, -0.014, -0.011),
            (sx * 0.058,  0.007, -0.007),
            (sx * 0.051,  0.022, -0.004),
        ]
        objs.append(create_tube(
            f"ZygomaticArch_{s_ch}", arch_pts,
            [0.0062, 0.0072, 0.0054, 0.0048, 0.0054],
            mat=M["bone"], parent=parent, segs=10,
            scale_xy_fn=lambda i, n: (0.62, 1.32),
        ))
        malar_pts = [
            (sx * 0.044, -0.044,  0.014),
            (sx * 0.048, -0.046, -0.002),
            (sx * 0.034, -0.050, -0.012),
        ]
        objs.append(create_tube(
            f"ZygomaticOrbitalRim_{s_ch}", malar_pts, [0.0042, 0.0052, 0.0045],
            mat=M["bone"], parent=parent, segs=8
        ))

    # Sculpted Nasal Bridge Crest & Vomer Septum ("nasal" -> bone_mat)
    objs.append(create_tube(
        "NasalBridgeCrest",
        [(0.0, -0.060, 0.018), (0.0, -0.066, 0.007), (0.0, -0.062, -0.002)],
        [0.0044, 0.0048, 0.0026], mat=M["bone"], parent=parent, segs=8,
        scale_xy_fn=lambda i, n: (1.15, 0.72),
    ))
    objs.append(create_box(
        "NasalSeptum", (0.0022, 0.016, 0.021), mat=M["bone"], parent=parent,
        loc=(0.0, -0.049, -0.009), bevel_w=0.0005
    ))

    # Deep Shadow Backing Cavities ("shadow" -> socket_dark_mat)
    # Recessed cleanly inside eye orbits & behind zygomatic arches (zero cheek protrusion!)
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        objs.append(create_sphere(
            f"OrbitShadow_{s_ch}", 0.0205, mat=M["shadow"], parent=parent,
            loc=(sx * 0.0250, -0.0395, 0.0082), scale=(1.08, 0.30, 0.94), segs=16, rings=10
        ))
        # Subtle recessed infratemporal hollow shadow tucked cleanly INSIDE behind zygomatic arch!
        objs.append(create_sphere(
            f"CheekShadow_{s_ch}", 0.0105, mat=M["shadow"], parent=parent,
            loc=(sx * 0.033, -0.014, -0.018), scale=(0.68, 0.95, 0.72), segs=12, rings=8
        ))
    objs.append(create_sphere(
        "NasalShadow", 0.0105, mat=M["shadow"], parent=parent,
        loc=(0.0, -0.048, -0.009), scale=(0.84, 0.62, 1.38), segs=14, rings=10
    ))
    objs.append(create_sphere(
        "PalateShadow", 0.024, mat=M["shadow"], parent=parent,
        loc=(0.0, -0.034, -0.036), scale=(1.02, 0.85, 0.62), segs=14, rings=8
    ))

    # 10 Crisp Anatomically Sculpted Upper Maxilla Teeth ("tooth" -> tooth_mat)
    for ti in range(10):
        ang = -1.04 + (float(ti) / 9.0) * 2.08
        tx = math.sin(ang) * 0.0278
        ty = -0.0355 - math.cos(ang) * 0.0248
        is_canine = ti in (2, 7)
        is_central = ti in (4, 5)
        w = 0.0058 if is_central else (0.0049 if is_canine else 0.0048)
        h = 0.0124 if is_canine else (0.0112 if is_central else 0.0094)
        chip = 0.0014 if ti == 3 else 0.0
        objs.append(create_sculpted_tooth(
            f"MaxillaTooth_{ti}", w, 0.0056, h, mat=M["tooth"], parent=parent,
            loc=(tx, ty, -0.0435 - (0.0011 if is_canine else 0.0)),
            rot=(6.5, 0.0, math.degrees(-ang)),
            is_canine=is_canine, is_upper=True, chip=chip,
        ))

    # Glowing Cyan Crown-Scar Fracture Inlay
    scar_pts = []
    for si in range(9):
        t = float(si) / 8.0
        nz = 0.28 + t * 0.42
        nx = 0.23 - 0.20 * t + 0.032 * math.sin(t * 14.0)
        ny = -math.sqrt(max(0.05, 1.0 - nx * nx - nz * nz))
        px, py, pz = skull_eval(nx, ny, nz)
        scar_pts.append((px, py - 0.0010, pz + 0.0006))
    objs.append(create_tube(
        "CrownScarGlow", scar_pts, [0.0008, 0.0015, 0.0018, 0.0017, 0.0018, 0.0015, 0.0013, 0.0009, 0.0005],
        mat=M["scar_glow"], parent=parent, segs=6
    ))

    # Sleek Flowing Ethereal Spectral Hair Wisps sweeping back smoothly along skull into hood shadow!
    wisp_seeds = [
        ((-0.038, -0.044, 0.048), (-0.062,  0.006, 0.062), (-0.044, 0.088, 0.072), 0.0075),
        (( 0.038, -0.044, 0.048), ( 0.062,  0.006, 0.062), ( 0.044, 0.088, 0.072), 0.0075),
        ((-0.052, -0.024, 0.030), (-0.068,  0.024, 0.032), (-0.050, 0.096, 0.026), 0.0068),
        (( 0.052, -0.024, 0.030), ( 0.068,  0.024, 0.032), ( 0.050, 0.096, 0.026), 0.0068),
        ((-0.018, -0.042, 0.064), (-0.026,  0.010, 0.084), (-0.016, 0.088, 0.092), 0.0080),
        (( 0.018, -0.042, 0.064), ( 0.026,  0.010, 0.084), ( 0.016, 0.088, 0.092), 0.0080),
        (( 0.000, -0.046, 0.067), ( 0.004,  0.006, 0.088), ( 0.006, 0.092, 0.098), 0.0085),
    ]
    for wi, (p0, p1, p2, ww) in enumerate(wisp_seeds):
        v0, v1, v2 = Vector(p0), Vector(p1), Vector(p2)
        pts = []
        rads = []
        for k in range(8):
            t = float(k) / 7.0
            pt = ((1 - t) ** 2) * v0 + 2 * (1 - t) * t * v1 + (t ** 2) * v2
            pt.z += 0.003 * math.sin(t * math.pi * 2.0 + wi)
            pts.append(pt)
            rads.append(ww * 0.45 * math.sin(max(0.06, t) * math.pi * 0.85) * (1.0 - 0.72 * (t ** 1.4)) + 0.0007)
        objs.append(create_tube(
            f"SpectralWisp_{wi}", pts, rads, mat=M["wisp_hair"], parent=parent, segs=6,
            scale_xy_fn=lambda i, n: (1.6, 0.28),
        ))

    return objs


# =============================================================================
# 3. GHOST JAW (Articulated Mandible hinged cleanly at local origin)
# =============================================================================

def build_ghost_jaw(M: dict, parent=None) -> list:
    objs = []

    jaw_pts = [
        (-0.041,  0.008,  0.015), (-0.039,  0.000, -0.008), (-0.036, -0.011, -0.024),
        (-0.028, -0.030, -0.028), (-0.015, -0.045, -0.031), ( 0.000, -0.049, -0.032),
        ( 0.015, -0.045, -0.031), ( 0.028, -0.030, -0.028), ( 0.036, -0.011, -0.024),
        ( 0.039,  0.000, -0.008), ( 0.041,  0.008,  0.015),
    ]
    jaw_rads = [0.0046, 0.0074, 0.0098, 0.0092, 0.0096, 0.0108, 0.0096, 0.0092, 0.0098, 0.0074, 0.0046]
    objs.append(create_tube(
        "MandibleBody", jaw_pts, jaw_rads, mat=M["bone"], parent=parent, segs=14,
        scale_xy_fn=lambda i, n: (0.68, 1.38) if 2 <= i <= 8 else (1.15, 0.65),
    ))

    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        cor_pts = [(sx * 0.036, -0.012, -0.016), (sx * 0.037, -0.013, 0.001), (sx * 0.036, -0.010, 0.014)]
        objs.append(create_tube(
            f"MandibleCoronoid_{s_ch}", cor_pts, [0.0068, 0.0056, 0.0028],
            mat=M["bone"], parent=parent, segs=8, scale_xy_fn=lambda i, n: (0.48, 1.4)
        ))
        objs.append(create_sphere(
            f"MandibleCondyle_{s_ch}", 0.0052, mat=M["bone"], parent=parent,
            loc=(sx * 0.041, 0.008, 0.015), scale=(1.25, 0.85, 0.85), segs=10, rings=8
        ))

    bm_chin = bmesh.new()
    bmesh.ops.create_icosphere(bm_chin, subdivisions=3, radius=1.0)
    for v in bm_chin.verts:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        cleft = 0.0016 * math.exp(-(nx / 0.22) ** 2) * smoothstep(0.0, 0.8, -ny)
        tubercle = 0.0022 * math.exp(-((abs(nx) - 0.55) / 0.26) ** 2) * smoothstep(0.0, 0.8, -ny)
        v.co = Vector((
            nx * 0.0165,
            ny * 0.0108 + cleft - tubercle - 0.050,
            nz * 0.0115 - 0.0335,
        ))
    objs.append(link_bm("ChinBoss", bm_chin, mat=M["bone"], parent=parent, smooth=True, uv_scale=10.0))

    for ti in range(8):
        ang = -0.92 + (float(ti) / 7.0) * 1.84
        tx = math.sin(ang) * 0.0235
        ty = -0.0235 - math.cos(ang) * 0.0225
        is_canine = ti in (1, 6)
        w = 0.0046 if not is_canine else 0.0048
        h = 0.0102 if is_canine else 0.0086
        objs.append(create_sculpted_tooth(
            f"MandibleTooth_{ti}", w, 0.0052, h, mat=M["tooth"], parent=parent,
            loc=(tx, ty, -0.0178 + (0.0010 if is_canine else 0.0)),
            rot=(-8.5, 0.0, math.degrees(-ang)),
            is_canine=is_canine, is_upper=False,
        ))

    return objs


# =============================================================================
# 4. GHOST HANDS & SILKY FLOWING SHREDDED SLEEVES (No shoulder cap artifact!)
# =============================================================================

def build_ghost_hand(M: dict, is_right: bool = True, parent=None) -> list:
    objs = []
    sx = 1.0 if is_right else -1.0

    # Silky Flowing Shredded Medieval Bell Sleeve ("GhostSleeve" -> shroud_mat)
    # Tapered smoothly into torso at v=0 (NO flat circle disc!), flaring into hanging shredded medieval bell cuff!
    def sleeve_eval(u: float, v: float):
        ang = u * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        cx = sx * (-0.018 * (1.0 - v) + 0.038 * (v ** 1.1))
        cy = 0.015 * (1.0 - v) - 0.205 * v
        cz = 0.012 * (1.0 - v) - 0.068 * (v ** 0.90)

        r_base = 0.036 + 0.036 * (v ** 1.45)
        down_w = max(0.0, -sa)
        droop = (down_w ** 1.4) * 0.115 * (v ** 1.65)
        pleat = (0.0065 * math.sin(ang * 7.0 + v * 3.5) + 0.0032 * math.cos(ang * 11.0)) * smoothstep(0.18, 0.92, v)
        tatter_ext = (
            0.030 * math.sin(ang * 5.0 + (0.4 if is_right else 1.2))
            + 0.015 * math.cos(ang * 9.0)
        ) * (v ** 2.3)

        px = cx + ca * (r_base + pleat)
        py = cy - tatter_ext * 0.45 - 0.005 * math.sin(ang * 4.0) * v
        pz = cz + sa * (r_base * 0.90 + pleat) - droop - abs(tatter_ext) * 0.65 * down_w
        return (px, py, pz)

    def sleeve_uv(u: float, v: float):
        return (u, 1.0 - (0.16 + v * 0.72))

    sleeve = create_grid_cloth(
        "GhostSleeve", 48, 28, sleeve_eval, uv_fn=sleeve_uv,
        mat=M["shroud"], parent=parent, closed_u=True, smooth=True
    )
    add_subsurf(sleeve, levels=1)
    objs.append(sleeve)

    # Sculpted Bony Spectral Wrist, Palm & Articulated Long Fingers ("spectral", "finger", "thumb")
    palm_c = Vector((sx * 0.038, -0.205, -0.066))

    objs.append(create_tube(
        "SpectralWrist",
        [
            (sx * 0.028, -0.148, -0.056),
            (sx * 0.035, -0.180, -0.063),
            (palm_c.x, palm_c.y + 0.010, palm_c.z),
        ],
        [0.013, 0.011, 0.014], mat=M["spec_hand"], parent=parent, segs=12,
        scale_xy_fn=lambda i, n: (1.28, 0.68),
    ))

    bm_palm = bmesh.new()
    bmesh.ops.create_icosphere(bm_palm, subdivisions=3, radius=1.0)
    for v in bm_palm.verts:
        nx, ny, nz = v.co.x, v.co.y, v.co.z
        ridge = 0.0018 * (0.5 + 0.5 * math.cos(nx * math.pi * 4.2)) * smoothstep(0.0, 0.7, nz)
        w_mod = 1.0 + 0.14 * smoothstep(0.0, 0.8, -ny) - 0.22 * smoothstep(0.0, 0.9, ny)
        v.co = Vector((
            palm_c.x + nx * 0.0225 * w_mod,
            palm_c.y + ny * 0.0255,
            palm_c.z + nz * 0.0105 + ridge,
        ))
    objs.append(link_bm("SpectralPalm", bm_palm, mat=M["spec_hand"], parent=parent, smooth=True, uv_scale=10.0))

    finger_lens = (0.044, 0.050, 0.046, 0.036) if is_right else (0.036, 0.046, 0.050, 0.044)
    for fi in range(4):
        f_off = (fi - 1.5) * 0.0108
        f_len = finger_lens[fi]
        p0 = Vector((palm_c.x + f_off, palm_c.y - 0.018, palm_c.z - 0.001 + (0.002 if fi in (1, 2) else 0.0)))

        if is_right:
            p1 = p0 + Vector((f_off * 0.10, -f_len * 0.44, -0.004))
            p2 = p1 + Vector((f_off * 0.08, -f_len * 0.20, -f_len * 0.42))
            p3 = p2 + Vector((f_off * 0.04,  f_len * 0.16, -f_len * 0.28))
        else:
            curl_amt = 0.20 if fi in (2, 3) else 0.58
            splay = (fi - 1.5) * 0.0045
            p1 = p0 + Vector((splay,       -f_len * 0.46,  0.006 - 0.008 * curl_amt))
            p2 = p1 + Vector((splay * 0.9, -f_len * 0.36,  0.004 - 0.016 * curl_amt))
            p3 = p2 + Vector((splay * 0.6, -f_len * 0.24, -0.004 - 0.018 * curl_amt))

        pts = [p0, p0.lerp(p1, 0.5), p1, p1.lerp(p2, 0.5), p2, p2.lerp(p3, 0.55), p3]
        rads = [0.0046, 0.0036, 0.0043, 0.0031, 0.0036, 0.0024, 0.0014]
        objs.append(create_tube(f"Finger_{fi}", pts, rads, mat=M["spec_hand"], parent=parent, segs=8))

    t0 = Vector((palm_c.x - sx * 0.018, palm_c.y - 0.002, palm_c.z - 0.002))
    if is_right:
        t1 = t0 + Vector((-sx * 0.012, -0.016, -0.006))
        t2 = t1 + Vector(( sx * 0.006, -0.014, -0.012))
    else:
        t1 = t0 + Vector((-sx * 0.016, -0.018,  0.002))
        t2 = t1 + Vector((-sx * 0.008, -0.015,  0.004))

    objs.append(create_tube(
        "Thumb", [t0, t0.lerp(t1, 0.5), t1, t1.lerp(t2, 0.5), t2],
        [0.0052, 0.0040, 0.0046, 0.0034, 0.0019], mat=M["spec_hand"], parent=parent, segs=8
    ))

    return objs


# =============================================================================
# 5. GOTHIC WROUGHT-IRON OCTAGONAL TAVERN LANTERN
# =============================================================================

def build_ghost_lantern(M: dict, parent=None) -> list:
    objs = []

    roof_prof = [
        (0.056, 0.044), (0.062, 0.046), (0.060, 0.050), (0.048, 0.058),
        (0.036, 0.068), (0.022, 0.078), (0.016, 0.084), (0.020, 0.088),
        (0.014, 0.095), (0.004, 0.108),
    ]
    hood = create_lathe("LanternHood", roof_prof, mat=M["iron"], parent=parent, segs=8, smooth=False)
    add_bevel(hood, width=0.0014, segments=1)
    objs.append(hood)

    objs.append(create_lathe(
        "LanternBrassRoofTrim", [(0.057, 0.043), (0.0625, 0.0455), (0.058, 0.0485)],
        mat=M["brass"], parent=parent, segs=8, smooth=False
    ))
    objs.append(create_lathe(
        "LanternBrassVentRing", [(0.017, 0.083), (0.0215, 0.087), (0.016, 0.091)],
        mat=M["brass"], parent=parent, segs=8, smooth=False
    ))

    base_prof = [
        (0.002, -0.096), (0.010, -0.086), (0.007, -0.079), (0.024, -0.072),
        (0.042, -0.062), (0.055, -0.051), (0.056, -0.046), (0.050, -0.043),
    ]
    base = create_lathe("LanternBase", base_prof, mat=M["iron"], parent=parent, segs=8, smooth=False)
    add_bevel(base, width=0.0013, segments=1)
    objs.append(base)

    objs.append(create_lathe(
        "LanternBrassBaseTrim", [(0.052, -0.049), (0.057, -0.0465), (0.052, -0.0435)],
        mat=M["brass"], parent=parent, segs=8, smooth=False
    ))

    for bi in range(8):
        ang = bi * (math.tau / 8.0)
        ang_next = (bi + 1) * (math.tau / 8.0)
        ang_mid = (ang + ang_next) * 0.5
        ca, sa = math.cos(ang), math.sin(ang)
        cn, sn = math.cos(ang_next), math.sin(ang_next)
        cm, sm = math.cos(ang_mid), math.sin(ang_mid)

        strut_pts = [
            (ca * 0.054, sa * 0.054,  0.046), (ca * 0.058, sa * 0.058,  0.018),
            (ca * 0.056, sa * 0.056, -0.016), (ca * 0.052, sa * 0.052, -0.046),
        ]
        objs.append(create_tube(
            f"LanternStrut_{bi}", strut_pts, [0.0032, 0.0036, 0.0034, 0.0030],
            mat=M["iron"], parent=parent, segs=8
        ))
        for rz in (0.045, -0.046):
            objs.append(create_sphere(
                f"LanternRivet_{bi}_{1 if rz > 0 else 0}", 0.0038, mat=M["brass"], parent=parent,
                loc=(ca * 0.056, sa * 0.056, rz), segs=8, rings=6
            ))

        r_fil = 0.0525
        arch_pts = [
            (ca * r_fil, sa * r_fil, 0.022),
            ((ca * 0.72 + cm * 0.28) * r_fil, (sa * 0.72 + sm * 0.28) * r_fil, 0.035),
            (cm * (r_fil * 0.96), sm * (r_fil * 0.96), 0.043),
            ((cn * 0.72 + cm * 0.28) * r_fil, (sn * 0.72 + sm * 0.28) * r_fil, 0.035),
            (cn * r_fil, sn * r_fil, 0.022),
        ]
        objs.append(create_tube(
            f"LanternFiligreeTop_{bi}", arch_pts, 0.0020,
            mat=M["brass"] if bi % 2 == 0 else M["iron"], parent=parent, segs=6
        ))
        low_pts = [
            (ca * (r_fil * 0.97), sa * (r_fil * 0.97), -0.028),
            (cm * (r_fil * 0.94), sm * (r_fil * 0.94), -0.040),
            (cn * (r_fil * 0.97), sn * (r_fil * 0.97), -0.028),
        ]
        objs.append(create_tube(
            f"LanternFiligreeBot_{bi}", low_pts, 0.0018, mat=M["iron"], parent=parent, segs=6
        ))

    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        objs.append(create_sphere(
            f"LanternBailLug_{s_ch}", 0.0062, mat=M["brass"], parent=parent,
            loc=(sx * 0.056, 0.0, 0.052), segs=10, rings=8
        ))
    bail_pts = []
    for i in range(19):
        t = float(i) / 18.0
        a = t * math.pi
        bx = math.cos(a) * 0.056
        bz = 0.052 + math.sin(a) * 0.063 + 0.004 * math.exp(-((t - 0.5) / 0.14) ** 2)
        bail_pts.append((bx, 0.0, bz))
    objs.append(create_tube("LanternBail", bail_pts, 0.0034, mat=M["brass"], parent=parent, segs=10))

    ring_pts = [
        (math.cos(i * math.tau / 16.0) * 0.013, 0.0, 0.114 + math.sin(i * math.tau / 16.0) * 0.013)
        for i in range(17)
    ]
    objs.append(create_tube("LanternRing", ring_pts, 0.0028, mat=M["brass"], parent=parent, segs=8, cap_ends=False))

    objs.append(create_lathe(
        "LanternGlass", [(0.041, -0.042), (0.047, -0.014), (0.048, 0.018), (0.042, 0.043)],
        mat=M["lantern_glass"], parent=parent, segs=8, smooth=False
    ))

    def flame_radial(r_base, z_base, ang, ri, n_prof):
        t = float(ri) / max(1, n_prof - 1)
        flute = 1.0 + 0.18 * math.sin(ang * 3.0 + t * 2.2) * math.sin(t * math.pi)
        sway_x = 0.004 * math.sin(t * math.pi * 1.4) * (t ** 1.3)
        sway_y = 0.003 * math.cos(t * math.pi * 1.2) * (t ** 1.3)
        return (math.cos(ang) * r_base * flute + sway_x, math.sin(ang) * r_base * flute + sway_y, z_base)

    flame_prof = [
        (0.001, -0.028), (0.013, -0.020), (0.021, -0.008), (0.022, 0.004),
        (0.016,  0.018), (0.009,  0.028), (0.001,  0.038),
    ]
    objs.append(create_lathe(
        "LanternCore", flame_prof, mat=M["lantern_core"], parent=parent, segs=18,
        smooth=True, radial_fn=flame_radial
    ))

    return objs


# =============================================================================
# STUDIO SHOWCASE RENDER (Front + 3/4 Heroic View Side-by-Side)
# =============================================================================

def assemble_full_ghost_for_preview(M: dict, loc=(0.0, 0.0, 0.0), rot_z_deg: float = 0.0, suffix: str = "A"):
    root = bpy.data.objects.new(f"GhostPreview_{suffix}", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = loc
    root.rotation_euler = Euler((0.0, 0.0, math.radians(rot_z_deg)))

    build_ghost_shroud(M, parent=root)

    create_sphere(
        f"PreviewSoulCore_{suffix}", 0.080, mat=M["preview_core"], parent=root,
        loc=(0.0, 0.0, 0.44), scale=(0.90, 0.70, 1.80), segs=16, rings=12
    )

    skull_root = bpy.data.objects.new(f"SkullRoot_{suffix}", None)
    bpy.context.scene.collection.objects.link(skull_root)
    skull_root.parent = root
    skull_root.location = (0.0, -0.048, 0.675)
    build_ghost_skull(M, parent=skull_root)

    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        create_sphere(
            f"PreviewEye_{s_ch}_{suffix}", 0.0105, mat=M["preview_eye"], parent=skull_root,
            loc=(sx * 0.0245, -0.051, 0.008), scale=(1.08, 0.72, 0.90), segs=14, rings=10
        )
        create_sphere(
            f"PreviewPupil_{s_ch}_{suffix}", 0.0052, mat=M["preview_pupil"], parent=skull_root,
            loc=(sx * 0.0245, -0.0578, 0.008), segs=12, rings=8
        )

    jaw_root = bpy.data.objects.new(f"JawRoot_{suffix}", None)
    bpy.context.scene.collection.objects.link(jaw_root)
    jaw_root.parent = skull_root
    jaw_root.location = (0.0, -0.014, -0.034)
    jaw_root.rotation_euler = Euler((math.radians(6.0), 0.0, 0.0))
    build_ghost_jaw(M, parent=jaw_root)

    arm_r = bpy.data.objects.new(f"ArmR_{suffix}", None)
    bpy.context.scene.collection.objects.link(arm_r)
    arm_r.parent = root
    arm_r.location = (0.15, -0.06, 0.48)
    build_ghost_hand(M, is_right=True, parent=arm_r)

    lan_grp = bpy.data.objects.new(f"LanternGrp_{suffix}", None)
    bpy.context.scene.collection.objects.link(lan_grp)
    lan_grp.parent = arm_r
    lan_grp.location = (0.038, -0.215, -0.178)
    build_ghost_lantern(M, parent=lan_grp)

    arm_l = bpy.data.objects.new(f"ArmL_{suffix}", None)
    bpy.context.scene.collection.objects.link(arm_l)
    arm_l.parent = root
    arm_l.location = (-0.15, -0.05, 0.48)
    build_ghost_hand(M, is_right=False, parent=arm_l)

    return root


def render_ghost_preview():
    scene = reset_scene()
    M = make_ghost_materials()

    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1040
    scene.render.film_transparent = False

    scene.world = bpy.data.worlds.new("GhostStudioWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.010, 0.015, 0.025, 1.0)
    bg.inputs["Strength"].default_value = 0.65

    floor_mat = make_mat("StudioFloor", (0.018, 0.024, 0.034), roughness=0.72)
    create_box("StudioFloor", (4.5, 3.2, 0.05), mat=floor_mat, loc=(0.0, 0.2, -0.26), bevel_w=0.005)

    assemble_full_ghost_for_preview(M, loc=(-0.38, 0.0, 0.0), rot_z_deg=0.0, suffix="Front")
    assemble_full_ghost_for_preview(M, loc=( 0.38, 0.0, 0.0), rot_z_deg=-34.0, suffix="ThreeQuarter")

    cam_d = bpy.data.cameras.new("GhostCam")
    cam_d.lens = 38.0
    cam_o = bpy.data.objects.new("GhostCam", cam_d)
    cam_o.location = (0.0, -2.18, 0.44)
    cam_o.rotation_euler = (Vector((0.0, 0.0, 0.40)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    def add_area_light(name, loc, target, energy, size, color):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = size
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)

    add_area_light("KeyCyan", (-1.1, -1.6, 1.35), (0.0, 0.0, 0.42), 95.0, 1.8, (0.76, 0.94, 1.0))
    add_area_light("WarmLanternFill", (1.2, -1.2, 0.55), (0.0, 0.0, 0.40), 75.0, 1.4, (1.0, 0.80, 0.48))
    add_area_light("BackRim", (0.0, 1.3, 1.25), (0.0, 0.0, 0.44), 155.0, 2.5, (0.48, 0.92, 1.0))

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    print(f"[GHOST_V2_PREVIEW_RENDERED] {PREVIEW_PATH}")


def main():
    for fname, fn in (
        ("ghost_shroud.glb",  lambda M: build_ghost_shroud(M)),
        ("ghost_skull.glb",   lambda M: build_ghost_skull(M)),
        ("ghost_jaw.glb",     lambda M: build_ghost_jaw(M)),
        ("ghost_hand_r.glb",  lambda M: build_ghost_hand(M, is_right=True)),
        ("ghost_hand_l.glb",  lambda M: build_ghost_hand(M, is_right=False)),
        ("ghost_lantern.glb", lambda M: build_ghost_lantern(M)),
    ):
        reset_scene()
        M = make_ghost_materials()
        objs = fn(M)
        export_selected_glb(objs, OUT_DIR / fname)

    render_ghost_preview()
    print("[GHOST_V2_ALL_DONE]")


if __name__ == "__main__":
    main()
