"""
Blender 5.3 headless procedural sculpting generator for LIALO's 4 Playable Multiplayer Duelists:
Generates 4 distinct, high-craft dark-fantasy seated character GLBs in
D:/downpour-godot/assets/models/mp/ sized for the circular tavern table (radius ~1.06m,
seated torso height ~0.72m above table):
  1. mp_char_guillotine.glb  — Kat / Guillotine Executioner
  2. mp_char_monarch.glb     — Panovník / Parry Monarch
  3. mp_char_jester.glb      — Šašek / Chaos Jester
  4. mp_char_mistblade.glb   — Rytíř mlhy / Mistblade Shadow

Exact Pivot & Anchor Contract on EVERY character GLB:
  - TorsoPivot (root Empty at 0,0,0)
  - HeadPivot  (under TorsoPivot at local Blender (0.0, -0.01, 0.562) -> Godot (0.0, 0.562, +0.01))
  - ArmLPivot  (under TorsoPivot at local Blender (-shoulder_x, -0.02, 0.44))
  - ArmRPivot  (under TorsoPivot at local Blender (+shoulder_x, -0.02, 0.44))
  - EyeL, EyeR (distinctive glowing eye MeshInstance3D nodes under HeadPivot)
  - HandLHold  (Empty under ArmLPivot, placed right at inner palm card-grip pocket: world Blender (-0.102, -0.398, 0.278))
  - HandRHold  (Empty under ArmRPivot, placed right at inner palm card-grip pocket: world Blender (+0.102, -0.398, 0.278))
    -> Spaced 0.204m apart, 0.22m clear in front of chest, nestled between sculpted fingers (front) & thumbs (back)
       so a 3D card fan sits cleanly in the hands with ZERO chest clipping!

Orientation Contract (with export_yup=True):
  - Blender (x, y, z) -> Godot (x, z, -y)
  - Front faces Blender -Y (= Godot +Z, toward center of circular tavern table).

Studio Lineup Preview PNG rendered to:
  C:/Users/arnos/.gemini/antigravity/brain/a20e3f18-d942-46fa-80e3-721c54108b6d/scratch/preview_mp_characters.png

Run via:
  & "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_mp_characters.py
"""
import math
import pathlib
import bpy
import bmesh
from mathutils import Vector, Euler

OUT_DIR = pathlib.Path(r"D:\downpour-godot\assets\models\mp")
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\scratch\preview_mp_characters.png"
)

# Exact world-space card grip pocket centers (Blender coords: +X right, -Y forward, +Z up)
HOLD_HALF_SPACING = 0.102  # 0.204m total spacing between left & right palm grips
HOLD_WORLD_Y = -0.398      # ~0.22m clear gap in front of chest for zero card-fan clipping
HOLD_WORLD_Z = 0.278       # comfortable chest height above table (Z=0) without obstructing mask/eyes


# =============================================================================
# MATH, MATERIALS & BMesh SCULPTING HELPERS
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
    coat: float = 0.0,
    subsurface: float = 0.0,
    double_sided: bool = False,
):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = not double_sided
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = float(metallic)
    bsdf.inputs["Roughness"].default_value = float(roughness)
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = float(coat)
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = float(subsurface)
    if emit_str > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = float(emit_str)
    return mat


def get_mats():
    return {
        # Shared dark-fantasy base tones
        "skin_pale":       make_mat("SkinPale",       (0.46, 0.34, 0.28), roughness=0.44, subsurface=0.06),
        "lip_noble":       make_mat("LipNoble",       (0.24, 0.09, 0.08), roughness=0.38),
        "socket_dark":     make_mat("SocketDark",     (0.008, 0.008, 0.012), roughness=0.95),
        "sclera":          make_mat("EyeSclera",      (0.64, 0.62, 0.58), roughness=0.20),
        "pupil_dark":      make_mat("EyePupil",       (0.01, 0.01, 0.015), roughness=0.08),
        "hair_obsidian":   make_mat("HairObsidian",   (0.016, 0.018, 0.024), roughness=0.58),
        "hair_silver_tip": make_mat("HairSilverTip",  (0.44, 0.52, 0.58), metallic=0.18, roughness=0.42),
        "leather_dark":    make_mat("LeatherDark",    (0.042, 0.022, 0.016), roughness=0.52),
        "leather_black":   make_mat("LeatherBlack",   (0.016, 0.016, 0.020), roughness=0.36, coat=0.18),

        # 1. Guillotine Executioner palette
        "exec_steel":      make_mat("ExecDarkSteel",  (0.11, 0.125, 0.145), metallic=0.92, roughness=0.30),
        "exec_steel_edge": make_mat("ExecBrushedEdge",(0.38, 0.42, 0.48), metallic=0.94, roughness=0.22),
        "exec_cowl":       make_mat("ExecCowlCloth",  (0.026, 0.028, 0.036), roughness=0.72, double_sided=True),
        "exec_crimson":    make_mat("ExecCrimsonTrim",(0.24, 0.014, 0.018), roughness=0.62, double_sided=True),
        "exec_rivet":      make_mat("ExecBrassRivet", (0.64, 0.44, 0.16), metallic=0.90, roughness=0.28),
        "eye_cyan":        make_mat("EyeExecCyan",    (0.35, 0.94, 1.0), roughness=0.08,
                                    emission=(0.24, 0.90, 1.0), emit_str=4.2),

        # 2. Parry Monarch palette
        "monarch_gold":    make_mat("MonarchGold",    (0.88, 0.62, 0.14), metallic=0.95, roughness=0.19, coat=0.15),
        "monarch_steel":   make_mat("MonarchSteel",   (0.48, 0.50, 0.56), metallic=0.93, roughness=0.22),
        "monarch_crimson": make_mat("MonarchVelvet",  (0.26, 0.012, 0.024), roughness=0.68, double_sided=True),
        "monarch_porcelain": make_mat("MonarchPorcelain", (0.86, 0.82, 0.74), roughness=0.18, coat=0.55),
        "monarch_ermine":  make_mat("MonarchErmine",  (0.84, 0.80, 0.74), roughness=0.82),
        "monarch_spot":    make_mat("ErmineSpot",     (0.015, 0.014, 0.018), roughness=0.85),
        "monarch_ruby":    make_mat("MonarchRuby",    (0.76, 0.02, 0.06), roughness=0.10, coat=0.6,
                                    emission=(0.72, 0.03, 0.06), emit_str=1.6),
        "monarch_sapphire":make_mat("MonarchSapphire",(0.04, 0.18, 0.78), roughness=0.10, coat=0.6,
                                    emission=(0.06, 0.24, 0.88), emit_str=1.4),
        "eye_gold":        make_mat("EyeMonarchGold", (1.0, 0.78, 0.18), roughness=0.08,
                                    emission=(1.0, 0.70, 0.14), emit_str=3.8),

        # 3. Chaos Jester palette
        "jester_crimson":  make_mat("JesterCrimson",  (0.36, 0.016, 0.032), roughness=0.58, double_sided=True),
        "jester_violet":   make_mat("JesterViolet",   (0.14, 0.018, 0.28), roughness=0.58, double_sided=True),
        "jester_mask_w":   make_mat("JesterPorcelain",(0.90, 0.87, 0.80), roughness=0.16, coat=0.60),
        "jester_mask_d":   make_mat("JesterLacquer",  (0.06, 0.016, 0.14), metallic=0.18, roughness=0.16, coat=0.65),
        "jester_grin":     make_mat("JesterGrinRed",  (0.58, 0.015, 0.025), roughness=0.22, coat=0.40),
        "jester_brass":    make_mat("JesterBellBrass",(0.86, 0.62, 0.14), metallic=0.94, roughness=0.20),
        "jester_glove":    make_mat("JesterGlove",    (0.032, 0.016, 0.052), roughness=0.40),
        "eye_jester_l":    make_mat("EyeJesterMag",   (0.95, 0.18, 0.88), roughness=0.08,
                                    emission=(0.95, 0.16, 0.85), emit_str=4.0),
        "eye_jester_r":    make_mat("EyeJesterGold",  (1.0, 0.82, 0.15), roughness=0.08,
                                    emission=(1.0, 0.78, 0.12), emit_str=4.0),

        # 4. Mistblade Shadow palette (Bleach TYBW inspired)
        "mist_obsidian":   make_mat("MistObsidian",   (0.014, 0.018, 0.026), roughness=0.56, double_sided=True),
        "mist_scarf":      make_mat("MistScarfIndigo",(0.032, 0.048, 0.075), roughness=0.72, double_sided=True),
        "mist_wrap":       make_mat("MistBandageWrap",(0.075, 0.085, 0.105), roughness=0.76),
        "mist_silver":     make_mat("MistSilverSteel",(0.62, 0.68, 0.74), metallic=0.95, roughness=0.19),
        "mist_plate_dark": make_mat("MistLamellar",   (0.08, 0.10, 0.13), metallic=0.88, roughness=0.28),
        "mist_teal_glow":  make_mat("MistIceTeal",    (0.18, 0.92, 0.96), roughness=0.12,
                                    emission=(0.14, 0.88, 0.95), emit_str=3.6),
        "eye_mist_teal":   make_mat("EyeMistTeal",    (0.22, 0.96, 1.0), roughness=0.08,
                                    emission=(0.18, 0.92, 1.0), emit_str=4.5),
    }


def make_pivot(parent, name: str, loc=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0)):
    piv = bpy.data.objects.new(name, None)
    piv.empty_display_size = 0.045
    bpy.context.scene.collection.objects.link(piv)
    piv.parent = parent
    piv.location = loc
    piv.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
    return piv


def box_uv_bm(bm: bmesh.types.BMesh, scale: float = 3.0):
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


def link_bm(parent, name: str, bm: bmesh.types.BMesh, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    if len(bm.faces) > 0:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    box_uv_bm(bm, scale=3.0)
    mesh = bpy.data.meshes.new(name + "_M")
    bm.to_mesh(mesh)
    bm.free()
    if isinstance(mat, (list, tuple)):
        for m in mat:
            mesh.materials.append(m)
    elif mat is not None:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    obj.rotation_euler = Euler(tuple(math.radians(a) for a in rot))
    return obj


def add_box(parent, name: str, size_xyz: tuple, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel_w: float = 0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size_xyz, verts=bm.verts)
    if bevel_w > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel_w, segments=2, affect="EDGES")
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=(bevel_w > 0.0))


def add_cyl(parent, name: str, r_bot: float, r_top: float, h: float, mat, segs=18, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r_bot, radius2=r_top, depth=h)
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_sphere(parent, name: str, radius: float, mat, scale_xyz=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), segs=18, rings=12, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=scale_xyz, verts=bm.verts)
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_lathe(parent, name: str, profile_rz: list, mat, segs=28, loc=(0, 0, 0), rot=(0, 0, 0),
              smooth=True, cap_bottom=True, cap_top=True, radial_fn=None):
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
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_tube(parent, name: str, points: list, radii, mat, segs=12, cap_ends=True, smooth=True, scale_xy_fn=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
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

    for i in range(n_pts - 1):
        r0, r1 = rings[i], rings[i + 1]
        for si in range(segs):
            sn = (si + 1) % segs
            try:
                bm.faces.new((r0[si], r0[sn], r1[sn], r1[si]))
            except ValueError:
                pass

    if cap_ends:
        try:
            bm.faces.new(list(reversed(rings[0])))
        except ValueError:
            pass
        try:
            bm.faces.new(rings[-1])
        except ValueError:
            pass
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_grid_cloth(parent, name: str, nu: int, nv: int, eval_fn, mat, closed_u=False, smooth=True, solidify: float = 0.0, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    grid = []
    for vi in range(nv + 1):
        v = float(vi) / float(nv)
        row = []
        u_count = nu if closed_u else nu + 1
        for ui in range(u_count):
            u = float(ui) / float(nu)
            row.append(bm.verts.new(eval_fn(u, v)))
        grid.append(row)

    for vi in range(nv):
        r0, r1 = grid[vi], grid[vi + 1]
        for ui in range(nu):
            un = (ui + 1) % nu if closed_u else (ui + 1)
            try:
                bm.faces.new((r0[ui], r0[un], r1[un], r1[ui]))
            except ValueError:
                pass

    if solidify > 0.0:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.solidify(bm, geom=bm.faces[:] + bm.verts[:] + bm.edges[:], thickness=solidify)

    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_extruded_poly(parent, name: str, pts_2d: list, depth: float, mat, axis="Y", loc=(0, 0, 0), rot=(0, 0, 0), bevel_w=0.002):
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
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=(bevel_w > 0.0))


# =============================================================================
# SHARED PIVOT RIG, SCULPTED HEAD, EYES (EyeL / EyeR), & CARD-HOLDING HANDS
# =============================================================================

def create_mp_pivots(shoulder_x: float = 0.258):
    """Creates exact required pivot hierarchy: TorsoPivot -> HeadPivot, ArmLPivot, ArmRPivot."""
    torso_piv = make_pivot(None, "TorsoPivot", loc=(0.0, 0.0, 0.0))
    head_piv = make_pivot(torso_piv, "HeadPivot", loc=(0.0, -0.01, 0.562))
    arm_l_piv = make_pivot(torso_piv, "ArmLPivot", loc=(-shoulder_x, -0.02, 0.44))
    arm_r_piv = make_pivot(torso_piv, "ArmRPivot", loc=( shoulder_x, -0.02, 0.44))
    return torso_piv, head_piv, arm_l_piv, arm_r_piv


def build_base_head_mesh(
    head_piv,
    skin_mat,
    lip_mat=None,
    socket_mat=None,
    jaw_width: float = 1.0,
    cheek_prominence: float = 1.0,
    nose_aquiline: float = 1.0,
    include_lower_features: bool = True,
):
    """Sculpts an anatomical base head + neck under HeadPivot."""
    def face_eval(nx, ny, nz):
        fwd = -ny
        rx = 0.092 * (jaw_width if nz < 0.0 else 1.0)
        ry = 0.108 if ny > 0.0 else 0.100
        rz = 0.112
        if nz < 0.0:
            t = min(1.0, -nz)
            rx *= 1.0 - (0.33 / max(0.85, jaw_width)) * (t ** 1.15)
            if fwd < 0.2:
                ry *= 1.0 - 0.22 * t
        x = nx * rx
        y = ny * ry
        z = 0.104 + nz * rz
        if fwd > 0.10:
            fm = smoothstep(0.10, 0.55, fwd)
            brow = math.exp(-((nz - 0.24) / 0.10) ** 2) * smoothstep(0.0, 0.65, 0.72 - abs(nx))
            y -= brow * 0.012 * fm
            sock = 0.0
            for sx in (-1.0, 1.0):
                dx = (nx - sx * 0.39) / 0.18
                dz = (nz - 0.02) / 0.14
                sock = max(sock, math.exp(-(dx * dx + dz * dz) * 1.45))
            y += sock * 0.024 * fm
            nose_line = math.exp(-(nx / 0.092) ** 2) * smoothstep(0.28, -0.05, nz) * smoothstep(-0.46, -0.22, nz)
            nose_peak = math.exp(-((nz + 0.18) / 0.14) ** 2)
            y -= nose_line * (0.012 + 0.016 * nose_peak * nose_aquiline) * fm
            cheek = math.exp(-((abs(nx) - 0.52) / 0.16) ** 2) * math.exp(-((nz + 0.20) / 0.14) ** 2)
            y -= cheek * 0.009 * cheek_prominence * fm
            x += math.copysign(cheek * 0.005 * cheek_prominence * fm, nx)
            chin = math.exp(-(nx / 0.22) ** 2) * math.exp(-((nz + 0.80) / 0.12) ** 2) * fm
            y -= chin * 0.012 * jaw_width
            z -= chin * 0.004
        return (x, y, z)

    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        v.co = Vector(face_eval(d.x, d.y, d.z))
    link_bm(head_piv, "SculptedHead", bm, skin_mat, smooth=True)

    add_lathe(head_piv, "SculptedNeck", [
        (0.072, -0.056), (0.063, -0.018), (0.058, 0.022), (0.061, 0.045)
    ], skin_mat, segs=22)

    if include_lower_features and lip_mat is not None and socket_mat is not None:
        add_tube(head_piv, "SculptedUpperLip",
                 [(-0.020, -0.095, 0.045), (-0.009, -0.104, 0.048), (0.0, -0.105, 0.047), (0.009, -0.104, 0.048), (0.020, -0.095, 0.045)],
                 [0.0030, 0.0048, 0.0046, 0.0048, 0.0030], lip_mat, segs=8)
        add_tube(head_piv, "SculptedLowerLip",
                 [(-0.018, -0.093, 0.038), (0.0, -0.103, 0.036), (0.018, -0.093, 0.038)],
                 [0.0032, 0.0052, 0.0032], lip_mat, segs=8)
        add_tube(head_piv, "SculptedMouthCrease",
                 [(-0.021, -0.095, 0.042), (0.0, -0.104, 0.042), (0.021, -0.095, 0.042)],
                 [0.0016, 0.0022, 0.0016], socket_mat, segs=6)


def add_glowing_eyes(
    head_piv,
    iris_l_mat,
    iris_r_mat,
    socket_mat,
    eye_x: float = 0.037,
    eye_y: float = -0.105,
    eye_z: float = 0.106,
    scale_xyz: tuple = (1.18, 0.56, 0.72),
    slit_style: bool = False,
):
    """Creates REQUIRED named EyeL and EyeR glowing MeshInstance3D nodes under HeadPivot."""
    for sx, eye_name, imat in ((-1.0, "EyeL", iris_l_mat), (1.0, "EyeR", iris_r_mat)):
        # Dark eye recess shadow behind eye
        add_sphere(
            head_piv, f"EyeSocket_{eye_name}", 0.018, socket_mat,
            scale_xyz=(1.32, 0.42, 0.80),
            loc=(sx * eye_x, eye_y + 0.010, eye_z), segs=14, rings=10
        )
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=10, radius=0.0108)
        for v in bm.verts:
            if slit_style:
                # Piercing fierce narrowed visor-eye silhouette
                v.co.x *= scale_xyz[0] * 1.25
                v.co.y *= scale_xyz[1]
                v.co.z *= scale_xyz[2] * 0.56
                # Subtle outer upward fierce slant
                v.co.z += (v.co.x * sx) * 0.16
            else:
                v.co.x *= scale_xyz[0]
                v.co.y *= scale_xyz[1]
                v.co.z *= scale_xyz[2]
                v.co.z += (v.co.x * sx) * 0.10
        link_bm(head_piv, eye_name, bm, imat, loc=(sx * eye_x, eye_y, eye_z), smooth=True)


def get_arm_path_and_hold_local(side: float, shoulder_x: float):
    """
    Returns (arm_pts, hold_local) in ArmPivot local coordinates such that the sculpted card-holding
    hand grip pocket ALWAYS sits at exact character-world (+-0.102, -0.398, 0.278) Blender!
    """
    # ArmPivot is at (side * shoulder_x, -0.02, 0.44)
    hold_local = Vector((
        side * (HOLD_HALF_SPACING - shoulder_x),
        HOLD_WORLD_Y - (-0.02),
        HOLD_WORLD_Z - 0.44,
    ))
    elbow_local = Vector((side * 0.014, -0.155, -0.205))
    mid_forearm = Vector((side * (0.190 - shoulder_x), -0.262, -0.194))
    wrist_local = Vector((side * (0.146 - shoulder_x), -0.344, -0.178))

    arm_pts = [
        (0.0, 0.0, 0.0),
        (side * 0.024, -0.068, -0.108),
        tuple(elbow_local),
        tuple(mid_forearm),
        tuple(wrist_local),
    ]
    return arm_pts, wrist_local, hold_local


def build_card_holding_hand_and_anchor(
    arm_piv,
    side: float,
    shoulder_x: float,
    hand_mat,
    knuckle_mat=None,
    ring_mat=None,
    armored: bool = False,
):
    """
    Builds a sculpted card-holding hand centered on a clean 34mm grip slot between the 4 front fingers
    and the rear opposable thumb, AND creates the exact required Empty node HandLHold / HandRHold
    right at the inner palm grip center!
    """
    s_ch = "L" if side < 0 else "R"
    _, wrist_local, hold_local = get_arm_path_and_hold_local(side, shoulder_x)

    # REQUIRED Empty anchor node right at inner palm card-grip pocket!
    hold_name = "HandLHold" if side < 0 else "HandRHold"
    # Slight natural inward yaw rotation toward the card fan center
    make_pivot(arm_piv, hold_name, loc=tuple(hold_local), rot=(12.0, 0.0, -side * 14.0))

    # Sculpted Palm cupping outer-lower side of the card-grip slot
    palm_c = hold_local + Vector((side * 0.022, 0.008, -0.012))
    # Bridge wrist seamlessly into palm heel
    add_tube(
        arm_piv, f"HandWristBridge_{s_ch}",
        [tuple(wrist_local), tuple(wrist_local.lerp(palm_c, 0.55)), tuple(palm_c)],
        [0.032, 0.028, 0.024], hand_mat, segs=12,
        scale_xy_fn=lambda i, n: (0.76, 1.18),
    )
    add_sphere(
        arm_piv, f"HandPalm_{s_ch}", 0.029, hand_mat,
        scale_xyz=(0.76, 1.24, 1.05), loc=tuple(palm_c),
        rot=(14.0, side * 12.0, -side * 18.0), segs=14, rings=10
    )

    if armored and knuckle_mat is not None:
        # Plated gauntlet backhand & raised knuckle ridge
        add_box(
            arm_piv, f"GauntletBackPlate_{s_ch}", (0.016, 0.044, 0.048), knuckle_mat,
            loc=(palm_c.x + side * 0.016, palm_c.y - 0.006, palm_c.z + 0.002),
            rot=(14.0, side * 8.0, -side * 16.0), bevel_w=0.004
        )

    # 4 Articulated Fingers curling around the FRONT (-Y) face of the held card fan!
    # Finger tips rest at Y = hold_local.y - 0.020 (leaving clean gap for cards right at hold_local.y!)
    z_offsets = (0.024, 0.009, -0.006, -0.020)
    f_lengths = (0.048, 0.054, 0.050, 0.040)
    for fi in range(4):
        zo = z_offsets[fi]
        fl = f_lengths[fi]
        p0 = Vector((palm_c.x + side * 0.006, palm_c.y - 0.022, palm_c.z + zo + 0.010))
        p1 = Vector((hold_local.x + side * 0.004, hold_local.y - 0.023, hold_local.z + zo + 0.006))
        p2 = Vector((hold_local.x - side * (fl * 0.34), hold_local.y - 0.020, hold_local.z + zo + 0.003))
        p3 = Vector((hold_local.x - side * (fl * 0.56), hold_local.y - 0.015, hold_local.z + zo - 0.002))
        add_tube(
            arm_piv, f"HandFinger_{s_ch}_{fi}",
            [tuple(p0), tuple(p1), tuple(p2), tuple(p3)],
            [0.0074, 0.0066, 0.0056, 0.0042], hand_mat, segs=8
        )
        if armored and knuckle_mat is not None:
            add_sphere(arm_piv, f"GauntletKnuckle_{s_ch}_{fi}", 0.0078, knuckle_mat,
                       loc=tuple(p0), segs=8, rings=6)
        elif ring_mat is not None and fi == 2:
            add_cyl(arm_piv, f"SignetRing_{s_ch}", 0.0080, 0.0080, 0.0055, ring_mat, segs=10,
                    loc=tuple(p0.lerp(p1, 0.5)), rot=(0, 82, 0))

    # Opposable Thumb bracing the BACK (+Y, character-facing) side of the card fan!
    # Thumb pad rests at Y = hold_local.y + 0.014 -> clean 34mm card pinch slot centered on hold_local!
    t0 = Vector((palm_c.x - side * 0.002, palm_c.y + 0.010, palm_c.z + 0.016))
    t1 = Vector((hold_local.x + side * 0.004, hold_local.y + 0.016, hold_local.z + 0.018))
    t2 = Vector((hold_local.x - side * 0.014, hold_local.y + 0.014, hold_local.z + 0.032))
    add_tube(
        arm_piv, f"HandThumb_{s_ch}",
        [tuple(t0), tuple(t1), tuple(t2)],
        [0.0086, 0.0072, 0.0054], hand_mat, segs=8
    )


def add_jingle_bell(parent, name: str, loc: tuple, radius: float, brass_mat, dark_mat):
    """Sculpts a classic slotted brass jingle bell with sound slit & mounting loop."""
    add_sphere(parent, name, radius, brass_mat, loc=loc, segs=12, rings=10)
    add_box(parent, name + "_Slit", (radius * 1.45, radius * 0.42, radius * 0.28), dark_mat,
            loc=(loc[0], loc[1] - radius * 0.72, loc[2] - radius * 0.35), bevel_w=0.0005)
    add_cyl(parent, name + "_Rim", radius * 1.06, radius * 1.06, radius * 0.22, brass_mat,
            segs=12, loc=loc)


# =============================================================================
# 1. MP_CHAR_GUILLOTINE.GLB — KAT / GUILLOTINE EXECUTIONER
# =============================================================================

def build_mp_guillotine(M: dict):
    shoulder_x = 0.272
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_mp_pivots(shoulder_x=shoulder_x)

    # --- A. TORSO: Heavy Dark-Iron Cuirass + Crimson-Trimmed Battle Surcoat + Riveted Harness + 4-Lame Pauldrons ---
    def exec_torso_eval(u, v):
        ang = u * math.tau
        z = v * 0.55
        if v < 0.82:
            rx = 0.218 + 0.072 * smoothstep(0.18, 0.82, v)
            ry = 0.144 + 0.028 * math.sin(v * math.pi * 0.75)
        else:
            t = (v - 0.82) / 0.18
            rx = 0.290 * (1.0 - t) + 0.090 * t
            ry = 0.160 * (1.0 - t) + 0.082 * t
        ca, sa = math.cos(ang), math.sin(ang)
        # Subtle beveled iron chest keel
        keel = 0.012 * math.exp(-(ca / 0.28) ** 2) * max(0.0, sa) * math.sin(v * math.pi)
        return (ca * rx, -sa * ry - keel, z)

    add_grid_cloth(torso_piv, "ExecIronCuirass", 36, 18, exec_torso_eval, M["exec_steel"], closed_u=True)

    # Crimson-trimmed charcoal executioner battle surcoat draped front & back
    def surcoat_eval(u, v):
        un = (u - 0.5) * 2.0
        z = 0.015 + v * 0.505
        w = 0.168 - 0.018 * math.sin(v * math.pi * 0.6) + 0.028 * smoothstep(0.65, 1.0, v)
        px = un * w
        fold = 0.005 * math.sin(un * math.pi * 3.0) * (1.0 - v * 0.6)
        ry = 0.144 + 0.028 * math.sin(v * math.pi * 0.75)
        keel = 0.014 * (1.0 - min(1.0, (px / 0.18) ** 2)) * math.sin(v * math.pi * 0.85)
        return (px, -(ry + 0.014 + keel) - fold, z)

    add_grid_cloth(torso_piv, "ExecBattleSurcoat", 24, 18, surcoat_eval, M["exec_cowl"], closed_u=False, solidify=0.004)
    # Bold Crimson Surcoat Borders & Lower Hem Trim
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        b_pts = [surcoat_eval(0.0 if sx < 0 else 1.0, vi / 16.0) for vi in range(17)]
        add_tube(torso_piv, f"SurcoatCrimsonTrim_{s_ch}", b_pts, 0.011, M["exec_crimson"], segs=8)
    hem_pts = [surcoat_eval(ui / 14.0, 0.04) for ui in range(15)]
    add_tube(torso_piv, "SurcoatCrimsonHem", hem_pts, 0.010, M["exec_crimson"], segs=8)

    # Brushed-Steel Guillotine Diagonal Blade Emblem on Chest!
    blade_2d = [(-0.046, 0.435), (0.046, 0.435), (0.046, 0.305), (-0.046, 0.355)]
    add_extruded_poly(torso_piv, "GuillotineChestEmblem", blade_2d, 0.010, M["exec_steel_edge"],
                      axis="Y", loc=(0.0, -0.194, 0.0), bevel_w=0.0025)
    add_extruded_poly(torso_piv, "GuillotineEmblemFrame", [(-0.056, 0.445), (0.056, 0.445), (0.056, 0.292), (-0.056, 0.348)],
                      0.008, M["exec_crimson"], axis="Y", loc=(0.0, -0.190, 0.0), bevel_w=0.002)
    # Beveled brass rivets on chest blade emblem
    for rx, rz in ((-0.032, 0.418), (0.032, 0.418), (0.032, 0.330)):
        add_sphere(torso_piv, f"EmblemRivet_{int(rx*1000)}_{int(rz*1000)}", 0.0065, M["exec_rivet"],
                   loc=(rx, -0.200, rz), segs=8, rings=6)

    # Heavy Diagonal Leather Executioner X-Harness & Forged Iron Chain across Chest
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        strap_pts = []
        for si in range(9):
            t = si / 8.0
            bx = sx * (0.210 * (1.0 - t) - 0.195 * t)
            bz = 0.515 * (1.0 - t) + 0.135 * t
            by = -0.198 + 0.036 * ((t - 0.5) ** 2)
            strap_pts.append((bx, by, bz))
        add_tube(torso_piv, f"ExecHarnessStrap_{s_ch}", strap_pts, 0.020, M["leather_dark"], segs=8,
                 scale_xy_fn=lambda i, n: (1.5, 0.32))
    # Forged iron harness chest ring at X-junction
    ring_pts = [(math.cos(a) * 0.028, -0.206, 0.335 + math.sin(a) * 0.028) for a in [i * math.tau / 16.0 for i in range(17)]]
    add_tube(torso_piv, "ExecHarnessIronRing", ring_pts, 0.0055, M["exec_steel_edge"], segs=8, cap_ends=False)

    # Heavy Riveted Waist Belt & Forged Steel Buckle
    add_grid_cloth(torso_piv, "ExecWaistBelt", 32, 4,
                   lambda u, v: (math.cos(u * math.tau) * 0.236, -math.sin(u * math.tau) * 0.178, 0.105 + v * 0.065),
                   M["leather_dark"], closed_u=True)
    add_box(torso_piv, "ExecBeltBuckle", (0.082, 0.024, 0.084), M["exec_steel_edge"], loc=(0.0, -0.184, 0.138), bevel_w=0.005)
    add_box(torso_piv, "ExecBeltBuckleCut", (0.044, 0.028, 0.046), M["leather_dark"], loc=(0.0, -0.185, 0.138), bevel_w=0.002)

    # Colossal 4-Lame Riveted Dark-Iron Pauldrons + Upright Neck Breakers + Crimson Under-Fringe
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        for li in range(4):
            add_sphere(
                torso_piv, f"ExecPauldronLame_{s_ch}_{li}", 0.094 - li * 0.006,
                M["exec_steel"] if li % 2 == 0 else M["exec_steel_edge"],
                scale_xyz=(1.22, 1.08, 0.56),
                loc=(sx * (0.254 + li * 0.022), -0.008, 0.512 - li * 0.036),
                rot=(0, sx * (16.0 + li * 11.0), 0), segs=18, rings=12
            )
            # Twin brass rivets per lame
            for ry_off in (-0.074, 0.056):
                add_sphere(
                    torso_piv, f"ExecPauldronRivet_{s_ch}_{li}_{1 if ry_off < 0 else 0}", 0.0085, M["exec_rivet"],
                    loc=(sx * (0.268 + li * 0.022), ry_off, 0.514 - li * 0.036), segs=8, rings=6
                )
        # Sharp angled steel neck-guard blade (haute-piece)
        add_box(
            torso_piv, f"ExecHautePiece_{s_ch}", (0.015, 0.125, 0.088), M["exec_steel"],
            loc=(sx * 0.198, -0.006, 0.562), rot=(0, -sx * 16.0, 0), bevel_w=0.0035
        )
        add_box(
            torso_piv, f"ExecHauteTrim_{s_ch}", (0.017, 0.128, 0.012), M["exec_crimson"],
            loc=(sx * 0.186, -0.006, 0.602), rot=(0, -sx * 16.0, 0), bevel_w=0.002
        )

    # Heavy Charcoal & Crimson-Lined Back Cape
    def exec_cape_eval(u, v):
        un = (u - 0.5) * 2.0
        w = 0.29 + 0.12 * (v ** 0.85)
        fold = 0.020 * math.sin(un * math.pi * 3.5 + v * 2.0) * (0.25 + 0.75 * v)
        return (un * w, 0.118 + 0.072 * math.sin(v * math.pi * 0.65) + fold, 0.52 - v * 0.52)

    add_grid_cloth(torso_piv, "ExecBackCape", 24, 14, exec_cape_eval, M["exec_cowl"], closed_u=False, solidify=0.005)

    # --- B. HEAD: Hooded Dark-Steel Executioner Cowl + Riveted Iron Visor + Glowing Cyan Eye-Slit ---
    build_base_head_mesh(head_piv, M["socket_dark"], include_lower_features=False)

    # Sculpted Deep Hooded Executioner Cowl draping down past neck into draped shoulder collar
    def cowl_eval(u, v):
        ang = u * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        front_w = max(0.0, -sa)  # Blender -Y = front (sa < 0)
        # v = 0 at hood peak -> 1 at draped cowl mantle hem
        z = 0.278 - v * 0.355
        if v < 0.22:
            t = v / 0.22
            rx = 0.010 + 0.118 * math.sin(t * math.pi * 0.5)
            ry = 0.012 + 0.132 * math.sin(t * math.pi * 0.5)
        elif v < 0.68:
            t = (v - 0.22) / 0.46
            rx = 0.128 - 0.008 * math.sin(t * math.pi)
            ry = 0.144 - 0.010 * math.sin(t * math.pi)
        else:
            t = (v - 0.68) / 0.32
            rx = 0.126 + 0.105 * (t ** 1.15)
            ry = 0.140 + 0.075 * (t ** 1.15)

        fold = 0.007 * math.sin(ang * 8.0 + v * 5.0) * smoothstep(0.18, 0.9, v) * (1.0 - 0.6 * front_w)
        px = ca * (rx + fold)
        py = sa * (ry + fold)
        # Peak sweeps slightly back like medieval executioner hood
        if v < 0.35:
            pt = (0.35 - v) / 0.35
            py += (pt ** 1.4) * 0.075
            z += (pt ** 1.5) * 0.022
        # Front face opening cleanly frames the forged steel visor!
        if 0.22 < v < 0.72 and front_w > 0.32:
            arch = math.sin(clamp((v - 0.22) / 0.50, 0.0, 1.0) * math.pi)
            fw = smoothstep(0.32, 0.85, front_w) * arch
            py += fw * 0.032  # pull cowl edge tight against steel faceplate
            # Projecting pointed executioner brow overhang at top
            brow = math.exp(-((v - 0.30) / 0.09) ** 2) * front_w
            py -= brow * 0.034
        return (px, py, z)

    add_grid_cloth(head_piv, "ExecHoodCowl", 44, 24, cowl_eval, M["exec_cowl"], closed_u=True, solidify=0.005)
    # Crimson cowl hem piping
    cowl_hem = [cowl_eval(ui / 36.0, 0.98) for ui in range(37)]
    add_tube(head_piv, "ExecCowlCrimsonEdge", cowl_hem, 0.0065, M["exec_crimson"], segs=8, cap_ends=False)

    # Riveted Forged Dark-Steel Executioner Faceplate Visor (upper brow plate + lower jaw-guard plate + sharp eye-slit!)
    def visor_plate_eval(u, v, z_min, z_max, r_x, r_y):
        un = (u - 0.5) * 2.0  # -1..+1 around front arc
        ang = un * math.pi * 0.44
        z = z_min + v * (z_max - z_min)
        keel = 0.020 * (1.0 - abs(un)) ** 1.4
        px = math.sin(ang) * r_x
        py = -math.cos(ang) * r_y - keel
        return (px, py, z)

    # Upper brow visor plate (above eye-slit Z=0.118..0.185)
    add_grid_cloth(head_piv, "ExecVisorUpper", 20, 8,
                   lambda u, v: visor_plate_eval(u, v, 0.118, 0.186, 0.104, 0.112),
                   M["exec_steel"], closed_u=False, solidify=0.006)
    # Lower angular steel executioner mask-plate (below eye-slit Z=0.015..0.095)
    add_grid_cloth(head_piv, "ExecVisorLower", 20, 10,
                   lambda u, v: visor_plate_eval(u, v, 0.014, 0.095, 0.098 - (1.0 - v) * 0.016, 0.110 - (1.0 - v) * 0.010),
                   M["exec_steel"], closed_u=False, solidify=0.006)
    # Sharp brushed-steel central nasal ridge bridge dividing the glowing cyan eye-slit!
    add_box(head_piv, "ExecVisorNasalBar", (0.014, 0.018, 0.165), M["exec_steel_edge"],
            loc=(0.0, -0.128, 0.100), rot=(-5, 0, 0), bevel_w=0.0025)
    # Horizontal brushed-steel upper & lower eye-slit frames + brass rivets
    for rz, rname in ((0.118, "Top"), (0.095, "Bot")):
        slit_pts = [visor_plate_eval(ui / 12.0, 0.0 if rname == "Top" else 1.0, rz, rz + 0.002, 0.104, 0.114) for ui in range(13)]
        add_tube(head_piv, f"ExecEyeSlitRim_{rname}", slit_pts, 0.0042, M["exec_steel_edge"], segs=8)
    for sx in (-1.0, 1.0):
        for rz in (0.045, 0.076, 0.145):
            add_sphere(head_piv, f"VisorRivet_{'L' if sx < 0 else 'R'}_{int(rz*100)}", 0.0045, M["exec_rivet"],
                       loc=(sx * 0.072, -0.092, rz), segs=8, rings=6)
    # Vertical Breather Slots on lower visor
    for bi in (-2, -1, 1, 2):
        add_box(head_piv, f"VisorVent_{bi+3}", (0.0042, 0.012, 0.036), M["socket_dark"],
                loc=(bi * 0.016, -0.120 + abs(bi) * 0.005, 0.056), rot=(-6, 0, -bi * 10), bevel_w=0.0008)

    # REQUIRED Named EyeL & EyeR burning piercing cyan inside the visor eye-slit!
    add_glowing_eyes(
        head_piv, M["eye_cyan"], M["eye_cyan"], M["socket_dark"],
        eye_x=0.036, eye_y=-0.109, eye_z=0.106, scale_xyz=(1.28, 0.52, 0.72), slit_style=True
    )

    # --- C. ARMS: Heavy Dark-Steel Vambraces, Elbow Cops & Plated Executioner Gauntlets ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        arm_pts, wrist_local, _ = get_arm_path_and_hold_local(side, shoulder_x)
        add_tube(arm_piv, f"ExecSleeve_{s_ch}", arm_pts, [0.064, 0.056, 0.050, 0.045, 0.038], M["exec_cowl"], segs=16)
        # Riveted Iron Elbow Cop
        add_sphere(arm_piv, f"ExecElbowCop_{s_ch}", 0.058, M["exec_steel"], scale_xyz=(0.95, 1.15, 0.88),
                   loc=arm_pts[2], segs=14, rings=10)
        # Flared Riveted Steel Gauntlet Vambrace
        vamb_pts = [arm_pts[2], arm_pts[3], arm_pts[4]]
        add_tube(arm_piv, f"ExecGauntletVambrace_{s_ch}", vamb_pts, [0.054, 0.049, 0.046], M["exec_steel"], segs=14)
        add_tube(arm_piv, f"ExecGauntletCuffRim_{s_ch}", [arm_pts[3], arm_pts[4]], [0.052, 0.050], M["exec_steel_edge"], segs=14)
        add_sphere(arm_piv, f"ExecVambraceRivet_{s_ch}", 0.0075, M["exec_rivet"],
                   loc=(arm_pts[3][0] + side * 0.048, arm_pts[3][1], arm_pts[3][2]), segs=8, rings=6)

        build_card_holding_hand_and_anchor(
            arm_piv, side, shoulder_x, M["exec_steel"], knuckle_mat=M["exec_steel_edge"], armored=True
        )

    return torso_piv


# =============================================================================
# 2. MP_CHAR_MONARCH.GLB — PANOVNÍK / PARRY MONARCH
# =============================================================================

def build_mp_monarch(M: dict):
    shoulder_x = 0.256
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_mp_pivots(shoulder_x=shoulder_x)

    # --- A. TORSO: Engraved Gilded Steel Breastplate + Royal Crimson Velvet Mantle + Lush Ermine Collar ---
    def monarch_cuirass_eval(u, v):
        ang = u * math.tau
        z = v * 0.55
        if v < 0.82:
            rx = 0.194 + 0.068 * smoothstep(0.18, 0.82, v)
            ry = 0.130 + 0.026 * math.sin(v * math.pi * 0.72)
        else:
            t = (v - 0.82) / 0.18
            rx = 0.262 * (1.0 - t) + 0.080 * t
            ry = 0.146 * (1.0 - t) + 0.072 * t
        ca, sa = math.cos(ang), math.sin(ang)
        # Gothic vertical armor fluting & regal central chest crest
        flute = 0.0038 * math.cos(ang * 14.0) * max(0.0, sa) * math.sin(v * math.pi)
        keel = 0.015 * math.exp(-(ca / 0.24) ** 2) * max(0.0, sa) * math.sin(v * math.pi)
        return (ca * (rx + flute), -sa * (ry + flute) - keel, z)

    add_grid_cloth(torso_piv, "MonarchEngravedBreastplate", 40, 20, monarch_cuirass_eval, M["monarch_steel"], closed_u=True)

    # Engraved Gilded Filigree Chest Relief (Gold Sunburst & Crossed Parry Blades on Breastplate)
    add_sphere(torso_piv, "MonarchSunCrest", 0.036, M["monarch_gold"], scale_xyz=(1.0, 0.26, 1.0),
               loc=(0.0, -0.172, 0.365), segs=16, rings=10)
    add_sphere(torso_piv, "MonarchChestRuby", 0.016, M["monarch_ruby"], scale_xyz=(0.95, 0.45, 1.15),
               loc=(0.0, -0.180, 0.365), segs=12, rings=8)
    for a_deg in (-38.0, 38.0):
        add_box(torso_piv, f"MonarchCrossBlade_{int(a_deg)}", (0.012, 0.009, 0.175), M["monarch_gold"],
                loc=(0.0, -0.171, 0.362), rot=(0, a_deg, 0), bevel_w=0.002)
    # Gilded Waist Belt & Engraved Fauld Trim
    add_grid_cloth(torso_piv, "MonarchGildedBelt", 34, 4,
                   lambda u, v: (math.cos(u * math.tau) * 0.214, -math.sin(u * math.tau) * 0.156, 0.118 + v * 0.048),
                   M["monarch_gold"], closed_u=True)
    add_sphere(torso_piv, "MonarchBeltJewel", 0.018, M["monarch_ruby"], scale_xyz=(1.1, 0.45, 1.25),
               loc=(0.0, -0.162, 0.142), segs=12, rings=8)

    # Royal Crimson Velvet Mantle draping dramatically over shoulders & down back + twin front panels!
    def velvet_mantle_eval(u, v):
        # Wraps from front-left chest around shoulders & back to front-right chest (leaves center breastplate gleaming!)
        ang = math.pi * 0.68 + u * (math.tau - 0.72)
        ca, sa = math.cos(ang), math.sin(ang)
        z = 0.54 - v * 0.54
        rx = 0.268 + 0.092 * (v ** 0.80)
        ry = 0.174 + 0.072 * (v ** 0.85)
        fold = 0.022 * math.sin(u * math.tau * 7.0 + v * 1.8) * (0.25 + 0.75 * v)
        return (ca * (rx + fold), -sa * (ry + fold) + 0.028 * v, z)

    add_grid_cloth(torso_piv, "MonarchCrimsonMantle", 44, 16, velvet_mantle_eval, M["monarch_crimson"],
                   closed_u=False, solidify=0.006)
    # Gilded Mantle Front Borders & Draped Royal Chain between Twin Medallion Brooches
    for ui_edge, s_ch in ((0.0, "L"), (1.0, "R")):
        e_pts = [velvet_mantle_eval(ui_edge, vi / 14.0) for vi in range(15)]
        add_tube(torso_piv, f"MantleGoldTrim_{s_ch}", e_pts, 0.010, M["monarch_gold"], segs=8)
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        add_sphere(torso_piv, f"MantleGoldBrooch_{s_ch}", 0.026, M["monarch_gold"], scale_xyz=(1.0, 0.42, 1.0),
                   loc=(sx * 0.155, -0.152, 0.482), segs=14, rings=10)
        add_sphere(torso_piv, f"MantleBroochRuby_{s_ch}", 0.011, M["monarch_ruby"], scale_xyz=(1.0, 0.5, 1.0),
                   loc=(sx * 0.155, -0.162, 0.482), segs=10, rings=8)
    chain_pts = [(-0.148, -0.156, 0.480), (-0.072, -0.172, 0.448), (0.0, -0.178, 0.438), (0.072, -0.172, 0.448), (0.148, -0.156, 0.480)]
    add_tube(torso_piv, "MonarchRoyalChain", chain_pts, 0.0065, M["monarch_gold"], segs=8)

    # Lush Sculpted White Ermine-Fur Royal Collar wrapping richly around Shoulders & Neck + Black Ermine Spots!
    def ermine_collar_eval(u, v):
        ang = math.pi * 0.64 + u * (math.tau - 0.58)
        ca, sa = math.cos(ang), math.sin(ang)
        # Puff cross-section around collar ring
        r_ring_x = 0.188 + 0.088 * math.sin(v * math.pi * 0.85)
        r_ring_y = 0.142 + 0.056 * math.sin(v * math.pi * 0.85)
        z = 0.582 - v * 0.145 + 0.024 * max(0.0, -sa) * (1.0 - v)  # raised regal collar behind neck!
        fluff = 0.010 * math.sin(u * math.tau * 18.0 + v * 6.0) * math.sin(v * math.pi)
        return (ca * (r_ring_x + fluff), -sa * (r_ring_y + fluff) + 0.010, z)

    add_grid_cloth(torso_piv, "MonarchErmineCollar", 44, 12, ermine_collar_eval, M["monarch_ermine"],
                   closed_u=False, solidify=0.016)
    # Characteristic sculpted dark ermine fur tail-spots dotted cleanly over the white ermine capelet!
    for si in range(13):
        u_sp = 0.06 + (si / 12.0) * 0.88
        v_sp = 0.42 if si % 2 == 0 else 0.72
        sp_loc = Vector(ermine_collar_eval(u_sp, v_sp))
        # Push slightly outward from center axis so spot sits cleanly on fur exterior
        out_dir = Vector((sp_loc.x, sp_loc.y, 0.0)).normalized()
        add_sphere(torso_piv, f"ErmineTailSpot_{si}", 0.0095, M["monarch_spot"],
                   scale_xyz=(0.68, 0.58, 1.55), loc=tuple(sp_loc + out_dir * 0.014), segs=8, rings=6)

    # --- B. HEAD: Sculpted Porcelain-and-Gold Venetian Half-Mask + High-Crested Gilded Gothic Crown ---
    build_base_head_mesh(
        head_piv, M["skin_pale"], lip_mat=M["lip_noble"], socket_mat=M["socket_dark"],
        jaw_width=0.94, cheek_prominence=1.08, nose_aquiline=1.15, include_lower_features=True
    )

    # Swept dark aristocratic hair framing sides & back of head beneath crown
    def noble_hair_eval(u, v):
        ang = u * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        front_w = max(0.0, -sa)
        # Open across face front, flowing gracefully down temples & back nape
        z_top = 0.215
        z_bot = 0.010 + front_w * 0.145
        z = z_top + (z_bot - z_top) * v
        rx = 0.106 + 0.016 * math.sin(v * math.pi)
        ry = 0.118 + 0.016 * math.sin(v * math.pi)
        wave = 0.005 * math.sin(ang * 12.0 + v * 4.0)
        return (ca * (rx + wave), sa * (ry + wave) + 0.006, z)

    add_grid_cloth(head_piv, "MonarchNobleHair", 36, 12, noble_hair_eval, M["hair_obsidian"], closed_u=True)

    # Sculpted Porcelain-and-Gold Venetian Half-Mask (covers upper face & cheeks cleanly, leaves composed chin/lips!)
    def venetian_mask_eval(u, v):
        # u: -1..+1 left temple -> nose -> right temple; v: 0 lower scalloped cheek edge -> 1 arched brow crown
        un = (u - 0.5) * 2.0
        ang = un * math.pi * 0.47
        # Aristocratic Venetian scalloped butterfly contour: rises at cheekbones & center brow peak!
        z_bot = 0.068 + 0.014 * math.cos(un * math.pi * 2.0) - 0.012 * math.exp(-(un / 0.25) ** 2)
        z_top = 0.168 + 0.022 * math.exp(-(un / 0.30) ** 2) - 0.018 * (abs(un) ** 1.6)
        z = z_bot + v * (z_top - z_bot)
        rx = 0.101
        ry = 0.108
        # Sculpted aquiline Venetian mask nose ridge & graceful cheek swells
        nose = 0.022 * math.exp(-(un / 0.12) ** 2) * math.sin(v * math.pi * 0.85)
        cheek = 0.007 * math.exp(-((abs(un) - 0.52) / 0.20) ** 2) * math.exp(-((v - 0.32) / 0.24) ** 2)
        # Subtle recessed eye bevels around un = +-0.37, v = 0.55 so EyeL & EyeR shine crisply!
        eye_recess = 0.0
        for sx in (-1.0, 1.0):
            dx = (un - sx * 0.37) / 0.16
            dv = (v - 0.56) / 0.20
            eye_recess = max(eye_recess, math.exp(-(dx * dx + dv * dv) * 2.2))
        px = math.sin(ang) * rx
        py = -math.cos(ang) * ry - nose - cheek + eye_recess * 0.018
        return (px, py, z)

    add_grid_cloth(head_piv, "MonarchVenetianMask", 32, 14, venetian_mask_eval, M["monarch_porcelain"],
                   closed_u=False, solidify=0.005)
    # Delicate Gilded Baroque Border Trim around Upper & Lower Venetian Mask Edges + Eye-Rim Filigree
    top_mask_rim = [venetian_mask_eval(ui / 24.0, 1.0) for ui in range(25)]
    bot_mask_rim = [venetian_mask_eval(ui / 24.0, 0.0) for ui in range(25)]
    add_tube(head_piv, "MaskGoldTopTrim", top_mask_rim, 0.0046, M["monarch_gold"], segs=8)
    add_tube(head_piv, "MaskGoldBotTrim", bot_mask_rim, 0.0042, M["monarch_gold"], segs=8)
    # Gilded forehead teardrop gem on mask apex
    add_sphere(head_piv, "MaskBrowRuby", 0.009, M["monarch_ruby"], scale_xyz=(0.78, 0.45, 1.35),
               loc=(0.0, -0.114, 0.158), segs=10, rings=8)

    # REQUIRED Named EyeL & EyeR (glowing royal amber-gold peering crisply through Venetian mask!)
    add_glowing_eyes(
        head_piv, M["eye_gold"], M["eye_gold"], M["socket_dark"],
        eye_x=0.036, eye_y=-0.108, eye_z=0.112, scale_xyz=(1.18, 0.56, 0.68), slit_style=False
    )

    # High-Crested Gilded Gothic Crown (Chased Circlet + 7 Soaring Gothic Fleur-de-Lis Spires + Gems!)
    crown_prof = [
        (0.104, 0.168),
        (0.110, 0.174),
        (0.108, 0.205),
        (0.116, 0.214),
        (0.112, 0.220),
        (0.104, 0.218),
    ]
    add_lathe(head_piv, "MonarchCrownBand", crown_prof, M["monarch_gold"], segs=28, smooth=True)
    # Deep crimson velvet royal cap lining inside crown
    add_sphere(head_piv, "MonarchCrownVelvetCap", 0.104, M["monarch_crimson"], scale_xyz=(1.0, 1.08, 0.72),
               loc=(0.0, 0.004, 0.195), segs=20, rings=10)

    # 7 Towering Gothic Crown Spires (Tallest Soaring Sovereign Crest at Front Center!)
    n_spires = 7
    for si in range(n_spires):
        # Place si=0 right at front (-Y -> ang = -pi/2)
        ang = -math.pi * 0.5 + (float(si) / float(n_spires)) * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        is_front = (si == 0)
        is_flank = si in (1, 6)
        spire_h = 0.135 if is_front else (0.102 if is_flank else 0.082)
        r_base = 0.112
        # Curved soaring Gothic spire flaring subtly outward at tip
        s_pts = [
            (ca * r_base, sa * r_base, 0.212),
            (ca * (r_base * 1.06), sa * (r_base * 1.06), 0.212 + spire_h * 0.55),
            (ca * (r_base * 1.14), sa * (r_base * 1.14), 0.212 + spire_h),
        ]
        add_tube(head_piv, f"CrownGothicSpire_{si}", s_pts,
                 [0.015 if is_front else 0.011, 0.010 if is_front else 0.008, 0.003],
                 M["monarch_gold"], segs=8, scale_xy_fn=lambda i, n: (1.25, 0.52))
        # Fleur-de-lis gilded finial orb at apex + crown band gemstone
        add_sphere(head_piv, f"CrownSpireOrb_{si}", 0.0095 if is_front else 0.0070, M["monarch_gold"],
                   loc=s_pts[-1], segs=10, rings=8)
        gem_m = M["monarch_ruby"] if si % 2 == 0 else M["monarch_sapphire"]
        add_sphere(head_piv, f"CrownGem_{si}", 0.010 if is_front else 0.0075, gem_m,
                   loc=(ca * 0.114, sa * 0.114, 0.194), segs=10, rings=8)
        # Side fleur-de-lis curls on the central sovereign crest
        if is_front:
            for fx in (-1.0, 1.0):
                add_tube(head_piv, f"CrownCrestWing_{'L' if fx < 0 else 'R'}",
                         [(0.0, -0.118, 0.270), (fx * 0.024, -0.124, 0.296), (fx * 0.036, -0.122, 0.278)],
                         [0.007, 0.008, 0.004], M["monarch_gold"], segs=8)

    # --- C. ARMS: Puffed Crimson Velvet Sleeves + Engraved Gilded Cuffs + Ivory Duelist Gloves ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        arm_pts, wrist_local, _ = get_arm_path_and_hold_local(side, shoulder_x)
        # Slashed royal crimson puffed upper sleeve
        add_sphere(arm_piv, f"MonarchPuffShoulder_{s_ch}", 0.082, M["monarch_crimson"], scale_xyz=(0.95, 0.95, 1.12),
                   loc=(side * 0.012, -0.025, -0.036), segs=16, rings=12)
        for ri in range(4):
            ang = ri * (math.tau / 4.0) + 0.4
            add_tube(arm_piv, f"SleeveGoldSlash_{s_ch}_{ri}",
                     [(side * 0.012 + math.cos(ang) * 0.068, -0.025 + math.sin(ang) * 0.068, 0.032),
                      (side * 0.018 + math.cos(ang) * 0.076, -0.045 + math.sin(ang) * 0.076, -0.045),
                      (side * 0.020 + math.cos(ang) * 0.058, -0.068 + math.sin(ang) * 0.058, -0.105)],
                     0.0065, M["monarch_gold"], segs=6)
        add_tube(arm_piv, f"MonarchVelvetSleeve_{s_ch}", arm_pts, [0.062, 0.055, 0.048, 0.041, 0.035], M["monarch_crimson"], segs=16)
        # Engraved Gilded Vambrace Cuff
        add_tube(arm_piv, f"MonarchGildedCuff_{s_ch}", [arm_pts[3], arm_pts[4]], [0.048, 0.044], M["monarch_gold"], segs=16)
        add_sphere(arm_piv, f"MonarchCuffRuby_{s_ch}", 0.008, M["monarch_ruby"],
                   loc=(arm_pts[4][0] + side * 0.040, arm_pts[4][1], arm_pts[4][2] + 0.012), segs=8, rings=6)

        build_card_holding_hand_and_anchor(
            arm_piv, side, shoulder_x, M["monarch_porcelain"], ring_mat=M["monarch_gold"], armored=False
        )

    return torso_piv


# =============================================================================
# 3. MP_CHAR_JESTER.GLB — ŠAŠEK / CHAOS JESTER
# =============================================================================

def build_mp_jester(M: dict):
    shoulder_x = 0.244
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_mp_pivots(shoulder_x=shoulder_x)

    # --- A. TORSO: Split Crimson-and-Violet Harlequin Tunic + Dramatic Jagged Pleated Diamond Ruff Collar ---
    def jester_half_torso_eval(u, v, is_right: bool):
        # Covers half circumference cleanly: left (-X) = crimson, right (+X) = violet!
        # Front = -Y (sin > 0 -> ang = pi/2), Back = +Y (ang = -pi/2)
        if is_right:
            ang = -math.pi * 0.5 + u * math.pi  # -pi/2 -> 0 (+X) -> +pi/2
        else:
            ang = math.pi * 0.5 + u * math.pi   # +pi/2 -> pi (-X) -> +3pi/2
        z = v * 0.55
        if v < 0.80:
            # Lithe theatrical cinched-waist jester torso
            waist = -0.022 * math.sin(smoothstep(0.0, 0.65, v) * math.pi)
            rx = 0.175 + 0.070 * smoothstep(0.20, 0.80, v) + waist
            ry = 0.122 + 0.024 * math.sin(v * math.pi * 0.75) + waist * 0.6
        else:
            t = (v - 0.80) / 0.20
            rx = 0.245 * (1.0 - t) + 0.072 * t
            ry = 0.138 * (1.0 - t) + 0.068 * t
        return (math.cos(ang) * rx, -math.sin(ang) * ry, z)

    add_grid_cloth(torso_piv, "JesterTunicLeftCrimson", 20, 18,
                   lambda u, v: jester_half_torso_eval(u, v, False), M["jester_crimson"], closed_u=False)
    add_grid_cloth(torso_piv, "JesterTunicRightViolet", 20, 18,
                   lambda u, v: jester_half_torso_eval(u, v, True), M["jester_violet"], closed_u=False)

    # Central Gold Seam Piping & 4 Sculpted Diamond Harlequin Chest Buttons + Contrasting Diamond Patches!
    seam_pts = [jester_half_torso_eval(1.0, vi / 14.0, True) for vi in range(15)]
    seam_pts = [(p[0], p[1] - 0.004, p[2]) for p in seam_pts]
    add_tube(torso_piv, "JesterCenterGoldSeam", seam_pts, 0.0065, M["jester_brass"], segs=8)
    diamond_2d = [(0.0, 0.022), (0.014, 0.0), (0.0, -0.022), (-0.014, 0.0)]
    for bi, bz in enumerate((0.20, 0.28, 0.36, 0.44)):
        add_extruded_poly(torso_piv, f"JesterGoldButton_{bi}", [(x * 0.72, y * 0.72) for x, y in diamond_2d],
                          0.010, M["jester_brass"], axis="Y", loc=(0.0, -0.156 - (0.008 if bi in (1, 2) else 0.0), bz), bevel_w=0.002)
    # Contrasting harlequin diamond patches on opposite chest halves!
    for sx, pmat, pz in ((-1.0, M["jester_violet"], 0.34), (-1.0, M["jester_violet"], 0.23),
                         ( 1.0, M["jester_crimson"], 0.38), ( 1.0, M["jester_crimson"], 0.26)):
        add_extruded_poly(torso_piv, f"HarlequinPatch_{'L' if sx < 0 else 'R'}_{int(pz*100)}",
                          [(x * 2.2, y * 2.1) for x, y in diamond_2d],
                          0.008, pmat, axis="Y", loc=(sx * 0.088, -0.144, pz), rot=(0, 0, -sx * 24), bevel_w=0.0015)

    # Asymmetric Tilted Jester Waist Sash & Gilded Buckle
    add_grid_cloth(torso_piv, "JesterWaistSash", 32, 4,
                   lambda u, v: (math.cos(u * math.tau) * 0.188, -math.sin(u * math.tau) * 0.142,
                                 0.108 + v * 0.048 + 0.022 * math.cos(u * math.tau)),
                   M["leather_black"], closed_u=True)
    add_extruded_poly(torso_piv, "JesterBeltBuckle", [(x * 2.0, y * 1.8) for x, y in diamond_2d],
                      0.014, M["jester_brass"], axis="Y", loc=(0.0, -0.148, 0.132), bevel_w=0.003)

    # Iconic Pleated Jagged Diamond Ruff Collar (14 Sharp Alternating Crimson & Violet Points with Brass Bells!)
    n_peaks = 14
    for pi in range(n_peaks):
        ang = (float(pi) / float(n_peaks)) * math.tau
        ang_l = ang - (math.tau / n_peaks) * 0.56
        ang_r = ang + (math.tau / n_peaks) * 0.56
        mat_p = M["jester_crimson"] if pi % 2 == 0 else M["jester_violet"]

        def ruff_petal_eval(u, v, _a=ang, _al=ang_l, _ar=ang_r, _pi=pi):
            # v = 0 at neck collar -> 1 at sharp jagged diamond tip!
            # Width narrows sharply to a crisp point at v=1
            spread = 1.0 - (v ** 1.25)
            cur_a = _a + (u - 0.5) * (_ar - _al) * spread
            r = 0.085 + v * (0.195 + 0.018 * (1 if _pi % 2 == 0 else -1))
            # Dramatic pleated wave ridge down center of each jagged diamond point!
            pleat_z = 0.016 * (1.0 - abs(u - 0.5) * 2.0) * math.sin(v * math.pi * 0.85)
            # Drape smoothly down over shoulders & chest while keeping collar ruff perked upward
            z = 0.556 + 0.022 * math.sin(v * math.pi * 0.7) - 0.125 * (v ** 1.35) + pleat_z
            return (math.cos(cur_a) * r, -math.sin(cur_a) * (r * 0.86), z)

        add_grid_cloth(torso_piv, f"JesterRuffPoint_{pi}", 6, 8, ruff_petal_eval, mat_p, closed_u=False, solidify=0.0045)
        # Gold trim on outer edges & tiny brass jingle bell dangling from every jagged point!
        tip_pos = Vector(ruff_petal_eval(0.5, 1.0))
        add_jingle_bell(torso_piv, f"RuffBell_{pi}", tuple(tip_pos + Vector((0, 0, -0.010))),
                        0.0095, M["jester_brass"], M["socket_dark"])

    # --- B. HEAD: Asymmetrical Porcelain Jester Mask + Sharp Painted Grin + Twin-Horned Curved Harlequin Cap ---
    build_base_head_mesh(head_piv, M["jester_mask_d"], include_lower_features=False)

    # Expressive Asymmetrical Porcelain Jester Mask (Left = Ivory Porcelain, Right = Twilight Violet Lacquer!)
    def jester_mask_half_eval(u, v, is_right: bool):
        # u: 0 at center nose bridge -> 1 at outer temple/cheek
        sx = 1.0 if is_right else -1.0
        ang = sx * u * math.pi * 0.48
        # Elongated theatrical jester chin & sculpted mischievous brow
        z = -0.006 + v * 0.205
        # Cheekbone swell & sharp pointed theatrical jester chin
        rx = 0.098 * (1.0 - 0.34 * max(0.0, 0.42 - v) ** 1.2)
        ry = 0.106
        nose = 0.024 * math.exp(-(u / 0.15) ** 2) * math.exp(-((v - 0.48) / 0.18) ** 2)
        cheek = 0.013 * math.exp(-((u - 0.54) / 0.22) ** 2) * math.exp(-((v - 0.42) / 0.18) ** 2)
        chin_pt = 0.018 * math.exp(-(u / 0.22) ** 2) * math.exp(-(v / 0.14) ** 2)
        # Slanted mischievous mask eye recess around u=0.38, v=0.58
        ey = math.exp(-(((u - 0.38) / 0.16) ** 2 + ((v - 0.58 - u * 0.08) / 0.12) ** 2) * 2.0)
        px = math.sin(ang) * rx
        py = -math.cos(ang) * ry - nose - cheek - chin_pt + ey * 0.020
        return (px, py, z)

    add_grid_cloth(head_piv, "JesterMaskLeftPorcelain", 18, 16,
                   lambda u, v: jester_mask_half_eval(u, v, False), M["jester_mask_w"], closed_u=False, solidify=0.004)
    add_grid_cloth(head_piv, "JesterMaskRightLacquer", 18, 16,
                   lambda u, v: jester_mask_half_eval(u, v, True), M["jester_mask_d"], closed_u=False, solidify=0.004)
    # Fine gold filigree seam splitting the asymmetric mask cleanly down the nose!
    split_pts = [jester_mask_half_eval(0.0, vi / 12.0, True) for vi in range(13)]
    split_pts = [(p[0], p[1] - 0.003, p[2]) for p in split_pts]
    add_tube(head_piv, "JesterMaskGoldSeam", split_pts, 0.0028, M["jester_brass"], segs=6)

    # Razor-Sharp Wide Painted Crimson-and-Black Mischievous Grin!
    grin_pts = [
        (-0.056, -0.094, 0.068),
        (-0.036, -0.107, 0.050),
        (-0.016, -0.114, 0.043),
        ( 0.000, -0.116, 0.042),
        ( 0.016, -0.114, 0.043),
        ( 0.036, -0.107, 0.050),
        ( 0.056, -0.094, 0.068),
    ]
    add_tube(head_piv, "JesterPaintedGrinRed", grin_pts, [0.0025, 0.0056, 0.0072, 0.0078, 0.0072, 0.0056, 0.0025],
             M["jester_grin"], segs=8, scale_xy_fn=lambda i, n: (1.2, 0.6))
    grin_cut = [(p[0], p[1] - 0.003, p[2]) for p in grin_pts]
    add_tube(head_piv, "JesterPaintedGrinLine", grin_cut, [0.0014, 0.0028, 0.0034, 0.0036, 0.0034, 0.0028, 0.0014],
             M["socket_dark"], segs=6)
    # Asymmetric painted tear-diamond under left eye & gold flourish under right eye
    add_extruded_poly(head_piv, "JesterMaskTearL", [(0, 0.012), (0.007, 0), (0, -0.014), (-0.007, 0)],
                      0.004, M["jester_violet"], axis="Y", loc=(-0.036, -0.108, 0.088), rot=(0, 0, 14), bevel_w=0.0008)
    add_extruded_poly(head_piv, "JesterMaskStarR", [(0, 0.012), (0.007, 0), (0, -0.014), (-0.007, 0)],
                      0.004, M["jester_brass"], axis="Y", loc=( 0.036, -0.108, 0.088), rot=(0, 0, -14), bevel_w=0.0008)

    # REQUIRED Named EyeL & EyeR (Asymmetrical Chaos Jester Eyes: Neon Amethyst Left + Electric Gold Right!)
    add_glowing_eyes(
        head_piv, M["eye_jester_l"], M["eye_jester_r"], M["socket_dark"],
        eye_x=0.036, eye_y=-0.106, eye_z=0.114, scale_xyz=(1.22, 0.54, 0.64), slit_style=True
    )

    # Iconic Twin-Horned Curved Harlequin Cap (Split Crimson & Violet + Central Mini Horn + Brass Jingle Bells!)
    # Sculpted fitted split harlequin skullcap hood
    for is_r, cmat in ((False, M["jester_crimson"]), (True, M["jester_violet"])):
        def cap_eval(u, v, _r=is_r):
            ang = (-math.pi * 0.5 + u * math.pi) if _r else (math.pi * 0.5 + u * math.pi)
            # Covers top & rear of head above mask brow
            phi = v * math.pi * 0.54
            r = 0.108 + 0.006 * math.sin(v * math.pi)
            px = math.cos(ang) * math.sin(phi) * r
            py = -math.sin(ang) * math.sin(phi) * (r * 1.06) + 0.005
            pz = 0.145 + math.cos(phi) * 0.088
            return (px, py, pz)
        add_grid_cloth(head_piv, f"JesterCapBase_{'R' if is_r else 'L'}", 16, 10, cap_eval, cmat, closed_u=False, solidify=0.004)

    # Gilded braided brow headband
    band_pts = [(math.cos(a) * 0.108, -math.sin(a) * 0.114 + 0.004, 0.168 - 0.016 * max(0.0, math.sin(a)))
                for a in [i * math.tau / 28.0 for i in range(29)]]
    add_tube(head_piv, "JesterCapGoldBand", band_pts, 0.0085, M["jester_brass"], segs=8, cap_ends=False)

    # Twin Dramatic Sweeping Curved Harlequin Horns (curling up, wide outward, then forward & down at tips!)
    for sx, s_ch, hmat in ((-1.0, "L", M["jester_crimson"]), (1.0, "R", M["jester_violet"])):
        horn_pts = [
            (sx * 0.048,  0.005, 0.195),
            (sx * 0.102,  0.000, 0.278),
            (sx * 0.178, -0.015, 0.342),
            (sx * 0.258, -0.046, 0.348),
            (sx * 0.312, -0.092, 0.296),
            (sx * 0.320, -0.132, 0.228),
        ]
        horn_rads = [0.052, 0.045, 0.036, 0.026, 0.017, 0.009]
        add_tube(head_piv, f"JesterHorn_{s_ch}", horn_pts, horn_rads, hmat, segs=14)
        # Decorative gold spiral ring midway along each horn
        add_sphere(head_piv, f"JesterHornBand_{s_ch}", 0.032, M["jester_brass"], scale_xyz=(0.55, 1.05, 1.05),
                   loc=horn_pts[2], rot=(0, sx * 25, 0), segs=12, rings=8)
        # Slotted Brass Jingle Bell dangling right at curved horn tip!
        tip = Vector(horn_pts[-1]) + Vector((0.0, -0.004, -0.018))
        add_jingle_bell(head_piv, f"JesterHornBell_{s_ch}", tuple(tip), 0.017, M["jester_brass"], M["socket_dark"])

    # Central Curled Rear-Crest Jester Tail Horn + Brass Bell
    mid_horn_pts = [
        (0.0, 0.040, 0.205),
        (0.0, 0.115, 0.285),
        (0.0, 0.195, 0.305),
        (0.0, 0.242, 0.252),
    ]
    add_tube(head_piv, "JesterRearHorn", mid_horn_pts, [0.040, 0.032, 0.020, 0.008], M["jester_crimson"], segs=12)
    add_jingle_bell(head_piv, "JesterRearHornBell", (0.0, 0.246, 0.236), 0.014, M["jester_brass"], M["socket_dark"])

    # --- C. ARMS: Split Crimson/Violet Sleeves + Jagged Diamond Wrist Cuffs + Slender Jester Gloves ---
    for side, arm_piv, s_ch, smat, trim_mat in (
        (-1.0, arm_l_piv, "L", M["jester_crimson"], M["jester_violet"]),
        ( 1.0, arm_r_piv, "R", M["jester_violet"],  M["jester_crimson"]),
    ):
        arm_pts, wrist_local, _ = get_arm_path_and_hold_local(side, shoulder_x)
        # Puffed harlequin shoulder ball with contrasting stripes
        add_sphere(arm_piv, f"JesterShoulderPuff_{s_ch}", 0.072, smat, scale_xyz=(0.95, 0.95, 1.08),
                   loc=(side * 0.010, -0.018, -0.025), segs=14, rings=10)
        add_tube(arm_piv, f"JesterSleeve_{s_ch}", arm_pts, [0.056, 0.048, 0.042, 0.036, 0.031], smat, segs=14)
        # Flared Jagged Diamond Wrist Cuff (6 pointed pleats radiating around wrist!)
        wc = Vector(arm_pts[4])
        for ci in range(6):
            ca = ci * (math.tau / 6.0)
            p_base = wc + Vector((math.cos(ca) * 0.030, 0.018, math.sin(ca) * 0.030))
            p_tip = wc + Vector((math.cos(ca) * 0.062, 0.046, math.sin(ca) * 0.062))
            add_tube(arm_piv, f"JesterCuffSpike_{s_ch}_{ci}", [tuple(p_base), tuple(p_tip)],
                     [0.015, 0.003], trim_mat if ci % 2 == 0 else M["jester_brass"], segs=6)
        add_tube(arm_piv, f"JesterWristGoldBand_{s_ch}", [arm_pts[3], arm_pts[4]], [0.038, 0.036], M["jester_brass"], segs=12)

        build_card_holding_hand_and_anchor(
            arm_piv, side, shoulder_x, M["jester_glove"], ring_mat=M["jester_brass"], armored=False
        )

    return torso_piv


# =============================================================================
# 4. MP_CHAR_MISTBLADE.GLB — RYTÍŘ MLHY / MISTBLADE SHADOW (BLEACH TYBW INSPIRED)
# =============================================================================

def build_mp_mistblade(M: dict):
    shoulder_x = 0.256
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_mp_pivots(shoulder_x=shoulder_x)

    # --- A. TORSO: TYBW-Inspired High-Collared Obsidian War-Coat + Flowing Scarf + Lamellar Shoulder Guards ---
    def warcoat_eval(u, v):
        ang = u * math.tau
        z = v * 0.555
        if v < 0.25:
            # Subtle flared battle coat hem
            t = v / 0.25
            rx = 0.218 - 0.034 * t
            ry = 0.144 - 0.020 * t
        elif v < 0.82:
            t = (v - 0.25) / 0.57
            rx = 0.184 + 0.086 * smoothstep(0.0, 1.0, t)
            ry = 0.124 + 0.034 * math.sin(t * math.pi * 0.72)
        else:
            t = (v - 0.82) / 0.18
            rx = 0.270 * (1.0 - t) + 0.086 * t
            ry = 0.152 * (1.0 - t) + 0.080 * t
        ca, sa = math.cos(ang), math.sin(ang)
        fold = 0.005 * math.sin(ang * 10.0) * smoothstep(0.45, 0.0, v)
        return (ca * (rx + fold), -sa * (ry + fold), z)

    add_grid_cloth(torso_piv, "MistObsidianWarCoat", 38, 20, warcoat_eval, M["mist_obsidian"], closed_u=True)

    # Crisp Asymmetrical Double-Breasted War-Coat Front Lapel Panel with Silver & Glowing Ice-Teal Edge Trim!
    def lapel_panel_eval(u, v):
        # Sweeps diagonally across front chest from left shoulder down to right hip!
        z = 0.04 + v * 0.495
        x_left = -0.145 + 0.025 * (1.0 - v)
        x_right = 0.020 + 0.095 * (1.0 - v) + 0.025 * math.sin(v * math.pi)
        px = x_left + u * (x_right - x_left)
        ry = 0.150 + 0.026 * math.sin(v * math.pi * 0.75)
        py = -(ry + 0.012) + 0.022 * ((px / 0.18) ** 2)
        return (px, py, z)

    add_grid_cloth(torso_piv, "MistCoatFrontFlap", 16, 16, lapel_panel_eval, M["mist_obsidian"], closed_u=False, solidify=0.005)
    # Glowing Ice-Teal Inner Seam Piping + Silver Clasp Toggles down Coat Opening!
    edge_pts = [lapel_panel_eval(1.0, vi / 14.0) for vi in range(15)]
    add_tube(torso_piv, "MistCoatTealPiping", [(p[0] + 0.003, p[1] - 0.003, p[2]) for p in edge_pts],
             0.0042, M["mist_teal_glow"], segs=6)
    for ti in (3, 6, 9, 12):
        ep = edge_pts[ti]
        add_box(torso_piv, f"MistSilverToggle_{ti}", (0.042, 0.009, 0.009), M["mist_silver"],
                loc=(ep[0] + 0.008, ep[1] - 0.006, ep[2]), rot=(0, -6, 0), bevel_w=0.002)

    # Structured Obi-Sash Belt with Silver Katana-Guard (Tsuba) Buckle!
    add_grid_cloth(torso_piv, "MistObiSash", 34, 5,
                   lambda u, v: (math.cos(u * math.tau) * 0.204, -math.sin(u * math.tau) * 0.146, 0.135 + v * 0.072),
                   M["mist_scarf"], closed_u=True)
    add_cyl(torso_piv, "MistTsubaBuckle", 0.036, 0.036, 0.010, M["mist_silver"], segs=16,
            loc=(0.0, -0.152, 0.170), rot=(90, 0, 0))
    add_box(torso_piv, "MistTsubaSlot", (0.010, 0.014, 0.034), M["mist_teal_glow"],
            loc=(0.0, -0.154, 0.170), bevel_w=0.001)

    # ICONIC TYBW HIGH-STANDING FLARED OBSIDIAN WAR-COLLAR framing lower face cleanly!
    def high_collar_eval(u, v):
        # Wraps from front-left chest around neck/jaw/back to front-right, with crisp V-notch at chin front!
        ang = math.pi * 0.60 + u * (math.tau - 0.40)
        ca, sa = math.cos(ang), math.sin(ang)
        front_w = max(0.0, sa)
        # Soars high behind & along cheeks (z=0.52 -> 0.678!), dipping gracefully at front chin V
        z_bot = 0.510
        z_top = 0.678 - 0.056 * (front_w ** 1.6)
        z = z_bot + v * (z_top - z_bot)
        # Dramatic sleek outward flare like a TYBW Sternritter / Shinigami high collar!
        rx = 0.118 + 0.062 * (v ** 1.25)
        ry = 0.116 + 0.056 * (v ** 1.25)
        return (ca * rx, -sa * ry + 0.008, z)

    add_grid_cloth(torso_piv, "MistHighWarCollar", 42, 12, high_collar_eval, M["mist_obsidian"],
                   closed_u=False, solidify=0.007)
    # Crisp Silver & Glowing Ice-Teal Upper Collar Rim
    collar_top = [high_collar_eval(ui / 36.0, 1.0) for ui in range(37)]
    add_tube(torso_piv, "MistCollarSilverRim", collar_top, 0.0055, M["mist_silver"], segs=8)
    add_tube(torso_piv, "MistCollarTealInner", [(p[0] * 0.96, p[1] * 0.96, p[2] - 0.005) for p in collar_top],
             0.0032, M["mist_teal_glow"], segs=6)

    # Layered Dark-Indigo Battle Scarf coiled around throat + Two Dramatic Billowing Scarf Tails!
    for ri in range(2):
        rz = 0.548 + ri * 0.036
        add_grid_cloth(
            torso_piv, f"MistScarfCoil_{ri}", 36, 6,
            lambda u, v, _rz=rz, _ri=ri: (
                math.cos(u * math.tau) * (0.112 + 0.012 * math.sin(v * math.pi) + 0.005 * math.sin(u * math.tau * 5.0 + _ri)),
                -math.sin(u * math.tau) * (0.114 + 0.012 * math.sin(v * math.pi)) - 0.006,
                _rz + (v - 0.5) * 0.044 + 0.006 * math.cos(u * math.tau * 3.0),
            ),
            M["mist_scarf"], closed_u=True, solidify=0.005
        )
    # Two dramatic flowing wind-whipped scarf tails sweeping backward & out past right shoulder!
    for ti, (z_off, x_sweep, length_scale) in enumerate(((0.02, 0.18, 1.0), (-0.04, 0.10, 0.82))):
        def scarf_tail_eval(u, v, _zo=z_off, _xs=x_sweep, _ls=length_scale, _ti=ti):
            un = (u - 0.5) * 2.0
            w = (0.048 + 0.026 * (v ** 0.7)) * (1.0 - 0.35 * (v ** 2.0))
            px = 0.145 + v * _xs + 0.024 * math.sin(v * math.pi * 1.8 + _ti) + un * w * 0.45
            py = 0.055 + v * 0.285 * _ls + 0.028 * math.cos(v * math.pi * 1.5)
            pz = 0.560 + _zo - v * 0.240 * _ls + 0.035 * math.sin(v * math.pi * 1.4) + un * w * 0.85
            return (px, py, pz)
        add_grid_cloth(torso_piv, f"MistFlowingScarfTail_{ti}", 8, 16, scarf_tail_eval, M["mist_scarf"],
                       closed_u=False, solidify=0.0045)

    # Sleek Overlapping Lamellar Silver-and-Obsidian Steel Shoulder Guards (Sode) with Glowing Teal Lacing!
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        for li in range(4):
            def lame_eval(u, v, _sx=sx, _li=li):
                un = (u - 0.5) * 2.0  # front-to-back curve
                z_base = 0.525 - _li * 0.036
                r_out = 0.246 + _li * 0.022 + v * 0.024
                px = _sx * (r_out - 0.028 * (un ** 2))
                py = un * (0.095 - _li * 0.005) - 0.008
                pz = z_base - v * 0.042 - 0.012 * (un ** 2)
                return (px, py, pz)
            p_mat = M["mist_silver"] if li in (0, 3) else M["mist_plate_dark"]
            add_grid_cloth(torso_piv, f"MistLamellarSode_{s_ch}_{li}", 12, 4, lame_eval, p_mat,
                           closed_u=False, solidify=0.0055)
            # Glowing ice-teal lamellar cord lacing knots on front & rear of each plate!
            for uy in (-0.48, 0.48):
                knot_p = lame_eval(0.5 + uy * 0.5, 0.55)
                add_box(torso_piv, f"MistSodeLace_{s_ch}_{li}_{1 if uy > 0 else 0}",
                        (0.010, 0.012, 0.018), M["mist_teal_glow"],
                        loc=(knot_p[0] + sx * 0.005, knot_p[1], knot_p[2]), bevel_w=0.002)

    # --- B. HEAD: Spiky Swept Hair + Cracked Silver-Steel Knight Half-Visor + Fierce Ice-Teal Eyes ---
    build_base_head_mesh(head_piv, M["skin_pale"], include_lower_features=False)

    # Dark lower face-mask cowl tucking smoothly into the high war-coat collar
    add_lathe(head_piv, "MistLowerFaceWrap", [
        (0.088, -0.020), (0.096, 0.015), (0.099, 0.052), (0.096, 0.072),
    ], M["mist_scarf"], segs=24)

    # Cracked Silver-Steel Knight Half-Visor covering brow, nose bridge, left temple & cheek with Jagged Glowing Fracture!
    def half_visor_eval(u, v):
        un = (u - 0.5) * 2.0  # -1 (left temple) -> 0 (nose) -> +1 (right temple)
        ang = un * math.pi * 0.50
        # Asymmetric sleek anime-knight half-visor: sweeps lower on left cheek (-X), angled sharper on right!
        z_top = 0.188 + 0.018 * math.exp(-(un / 0.35) ** 2) - 0.022 * (abs(un) ** 1.4)
        z_bot = 0.078 - 0.036 * smoothstep(-0.1, -0.85, un) + 0.016 * smoothstep(0.1, 0.85, un)
        # Sharp eye-slit notches leaving glowing ice-teal eyes fiercely visible!
        z = z_bot + v * (z_top - z_bot)
        rx = 0.104
        ry = 0.112
        keel = 0.022 * math.exp(-(un / 0.18) ** 2)
        # Recess cleanly behind eye slits
        eye_cut = 0.0
        for sx in (-1.0, 1.0):
            dx = (un - sx * 0.37) / 0.17
            dz = (z - 0.106) / 0.016
            eye_cut = max(eye_cut, math.exp(-(dx * dx + dz * dz) * 1.8))
        px = math.sin(ang) * rx
        py = -math.cos(ang) * ry - keel + eye_cut * 0.019
        return (px, py, z)

    add_grid_cloth(head_piv, "MistCrackedHalfVisor", 30, 14, half_visor_eval, M["mist_silver"],
                   closed_u=False, solidify=0.0055)
    # Angular Dark-Steel Knight Brow Crest over Visor
    brow_crest = [half_visor_eval(ui / 18.0, 0.88) for ui in range(19)]
    add_tube(head_piv, "MistVisorBrowRidge", [(p[0], p[1] - 0.005, p[2] + 0.004) for p in brow_crest],
             0.0068, M["mist_plate_dark"], segs=8)

    # Dramatic Jagged Glowing Ice-Teal Fracture Crack cutting across Left-Center Half-Visor!
    crack_uvs = [
        (0.24, 0.96), (0.30, 0.78), (0.27, 0.62), (0.34, 0.44), (0.31, 0.24), (0.38, 0.06)
    ]
    crack_pts = [Vector(half_visor_eval(cu, cv)) + Vector((0.0, -0.0042, 0.0)) for cu, cv in crack_uvs]
    add_tube(head_piv, "MistVisorFractureGlow", crack_pts,
             [0.0014, 0.0028, 0.0032, 0.0026, 0.0022, 0.0010], M["mist_teal_glow"], segs=6)
    # Secondary hairline fracture branch
    branch_pts = [crack_pts[2], Vector(half_visor_eval(0.18, 0.48)) + Vector((0.0, -0.0040, 0.0)),
                  Vector(half_visor_eval(0.12, 0.34)) + Vector((0.0, -0.0038, 0.0))]
    add_tube(head_piv, "MistVisorFractureBranch", branch_pts, [0.0024, 0.0018, 0.0008], M["mist_teal_glow"], segs=6)

    # REQUIRED Named EyeL & EyeR (Piercing Ice-Teal Shadow-Knight Eyes!)
    add_glowing_eyes(
        head_piv, M["eye_mist_teal"], M["eye_mist_teal"], M["socket_dark"],
        eye_x=0.036, eye_y=-0.109, eye_z=0.106, scale_xyz=(1.26, 0.54, 0.64), slit_style=True
    )

    # Spiky Swept Anime/Dark-Fantasy Obsidian Hair with Silver-Tipped Locks rising above the Half-Visor!
    add_sphere(head_piv, "MistHairCrownBase", 0.104, M["hair_obsidian"], scale_xyz=(0.98, 1.08, 0.96),
               loc=(0.0, 0.010, 0.145), segs=18, rings=12)
    hair_spikes = [
        # (pts, rads, use_silver_tip)
        ([( 0.00, -0.06, 0.20), ( 0.01, -0.02, 0.28), ( 0.02,  0.08, 0.30)], [0.032, 0.024, 0.004], True),
        ([(-0.04, -0.06, 0.19), (-0.08, -0.01, 0.27), (-0.11,  0.08, 0.27)], [0.028, 0.020, 0.004], False),
        ([( 0.04, -0.06, 0.19), ( 0.08, -0.01, 0.27), ( 0.11,  0.08, 0.27)], [0.028, 0.020, 0.004], True),
        ([(-0.07, -0.03, 0.17), (-0.13,  0.03, 0.22), (-0.15,  0.11, 0.20)], [0.026, 0.018, 0.004], False),
        ([( 0.07, -0.03, 0.17), ( 0.13,  0.03, 0.22), ( 0.15,  0.11, 0.20)], [0.026, 0.018, 0.004], False),
        ([(-0.08,  0.02, 0.13), (-0.13,  0.09, 0.14), (-0.14,  0.16, 0.09)], [0.026, 0.018, 0.004], False),
        ([( 0.08,  0.02, 0.13), ( 0.13,  0.09, 0.14), ( 0.14,  0.16, 0.09)], [0.026, 0.018, 0.004], False),
        ([( 0.00,  0.04, 0.18), ( 0.00,  0.12, 0.23), ( 0.00,  0.19, 0.18)], [0.032, 0.022, 0.005], False),
        # Swept front bangs framing visor edge
        ([( 0.02, -0.08, 0.18), ( 0.05, -0.118, 0.14), ( 0.07, -0.112, 0.10)], [0.018, 0.012, 0.003], True),
        ([(-0.03, -0.08, 0.18), (-0.06, -0.116, 0.15), (-0.08, -0.108, 0.12)], [0.016, 0.010, 0.003], False),
    ]
    for hi, (hpts, hrads, silver_tip) in enumerate(hair_spikes):
        add_tube(head_piv, f"MistHairSpike_{hi}", hpts, hrads,
                 M["hair_silver_tip"] if silver_tip else M["hair_obsidian"], segs=8,
                 scale_xy_fn=lambda i, n: (1.25, 0.55))

    # --- C. ARMS: Obsidian Sleeves + Criss-Crossed Cloth-Wrapped Forearms + Armored Finger-Gloves ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        arm_pts, wrist_local, _ = get_arm_path_and_hold_local(side, shoulder_x)
        # Sleek obsidian upper coat sleeve down to elbow
        add_tube(arm_piv, f"MistCoatSleeve_{s_ch}", arm_pts[:3], [0.060, 0.052, 0.046], M["mist_obsidian"], segs=16)
        # Forearm base beneath cloth wraps
        add_tube(arm_piv, f"MistForearmCore_{s_ch}", arm_pts[2:], [0.044, 0.039, 0.034], M["mist_obsidian"], segs=14)
        # Sculpted Spiral Cloth Bandage Wraps along Forearm!
        p_elb = Vector(arm_pts[2])
        p_wri = Vector(arm_pts[4])
        fore_dir = (p_wri - p_elb).normalized()
        ref = Vector((0, 0, 1))
        n_vec = fore_dir.cross(ref).normalized()
        b_vec = fore_dir.cross(n_vec).normalized()
        wrap_pts = []
        n_wrap = 38
        for wi in range(n_wrap):
            t = float(wi) / float(n_wrap - 1)
            ang = t * math.tau * 5.2
            r = 0.045 * (1.0 - t) + 0.036 * t
            center = p_elb.lerp(p_wri, t)
            wrap_pts.append(tuple(center + n_vec * (math.cos(ang) * r) + b_vec * (math.sin(ang) * r)))
        add_tube(arm_piv, f"MistClothBandageWrap_{s_ch}", wrap_pts, 0.0085, M["mist_wrap"], segs=6,
                 scale_xy_fn=lambda i, n: (0.55, 1.45))
        # Sleek Silver Wrist Guard Plate with Teal Accent Line
        add_box(arm_piv, f"MistSilverWristPlate_{s_ch}", (0.016, 0.068, 0.044), M["mist_silver"],
                loc=(arm_pts[3][0] + side * 0.038, arm_pts[3][1] - 0.025, arm_pts[3][2] + 0.008),
                rot=(6, 0, -side * 22), bevel_w=0.003)

        build_card_holding_hand_and_anchor(
            arm_piv, side, shoulder_x, M["mist_obsidian"], knuckle_mat=M["mist_silver"], armored=True
        )

    return torso_piv


# =============================================================================
# GLB EXPORT & 4-CHARACTER STUDIO LINEUP SHOWCASE RENDER
# =============================================================================

def export_character_glb(root, filepath: pathlib.Path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for ch in root.children_recursive:
        ch.select_set(True)
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
    sz_kb = filepath.stat().st_size / 1024.0 if filepath.exists() else 0.0
    # Verify all required contract nodes exist in hierarchy!
    names = {root.name} | {ch.name for ch in root.children_recursive}
    required = {"TorsoPivot", "HeadPivot", "ArmLPivot", "ArmRPivot", "EyeL", "EyeR", "HandLHold", "HandRHold"}
    missing = required - names
    status = "OK" if not missing else f"MISSING {missing}"
    print(f"[MP_CHAR_EXPORTED] {filepath.name:24s} ({sz_kb:.1f} KB, contract={status})")
    if missing:
        raise RuntimeError(f"{filepath.name} missing required nodes: {missing}")


def add_preview_card_fan(parent, M: dict):
    """Preview-only subtle fanned cards seated right between HandLHold & HandRHold to prove zero chest clipping!"""
    card_mat = make_mat("PreviewCardBack", (0.18, 0.04, 0.04), roughness=0.45)
    card_trim = make_mat("PreviewCardTrim", (0.82, 0.62, 0.22), metallic=0.85, roughness=0.25)
    for ci in range(5):
        t = (ci - 2.0) / 2.0  # -1..+1
        cx = t * 0.056
        cy = HOLD_WORLD_Y + abs(t) * 0.008 - ci * 0.0022
        cz = HOLD_WORLD_Z + 0.030 - abs(t) * 0.008
        add_box(parent, f"PreviewCard_{ci}", (0.068, 0.0022, 0.102), card_mat,
                loc=(cx, cy, cz), rot=(22.0, -t * 14.0, t * 8.0), bevel_w=0.0006)
        add_box(parent, f"PreviewCardRim_{ci}", (0.058, 0.0028, 0.090), card_trim,
                loc=(cx, cy, cz), rot=(22.0, -t * 14.0, t * 8.0), bevel_w=0.0004)


def render_mp_lineup_preview(builders: list):
    scene = reset_scene()
    M = get_mats()
    scene.render.resolution_x = 2048
    scene.render.resolution_y = 980
    scene.render.film_transparent = False

    scene.world = bpy.data.worlds.new("MPStudioWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.014, 0.012, 0.018, 1.0)
    bg.inputs["Strength"].default_value = 0.70

    # Dark Tavern Oak & Velvet Duel Table Surface
    oak_mat = make_mat("PreviewOak", (0.046, 0.022, 0.011), roughness=0.52)
    felt_mat = make_mat("PreviewFelt", (0.024, 0.014, 0.016), roughness=0.78)
    add_box(None, "PreviewTableOak", (4.8, 1.4, 0.08), oak_mat, loc=(0.0, -0.45, -0.02), bevel_w=0.01)
    add_box(None, "PreviewTableFelt", (4.5, 1.08, 0.02), felt_mat, loc=(0.0, -0.45, 0.024), bevel_w=0.005)

    # Line up all 4 MP Duelists facing the camera (-Y) with slight heroic 12-deg turns for depth!
    spacing = 0.84
    yaw_angles = (-10.0, -4.0, 4.0, 10.0)
    for idx, (_fname, build_fn) in enumerate(builders):
        x_pos = (idx - 1.5) * spacing
        root = build_fn(M)
        root.location = (x_pos, 0.0, 0.0)
        root.rotation_euler = Euler((0.0, 0.0, math.radians(yaw_angles[idx])))
        # Place preview card fan right in the HandLHold / HandRHold grip pocket!
        add_preview_card_fan(root, M)

    # Studio Camera framing all 4 characters cleanly from crowns/horns to table
    cam_d = bpy.data.cameras.new("MPLineupCam")
    cam_d.lens = 32.0
    cam_o = bpy.data.objects.new("MPLineupCam", cam_d)
    cam_o.location = (0.0, -2.92, 0.68)
    cam_o.rotation_euler = (Vector((0.0, 0.0, 0.42)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
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

    # Rich Warm Tavern Candle Key + Cool Moonlight Fill + Dramatic Gold/Cyan Rim Separation
    add_area_light("WarmTavernKey", (-1.8, -2.3, 1.95), (0.0, 0.0, 0.42), 260.0, 3.0, (1.0, 0.85, 0.65))
    add_area_light("CoolMoonFill", (2.0, -2.1, 1.25), (0.0, 0.0, 0.40), 115.0, 3.2, (0.72, 0.86, 1.0))
    add_area_light("BackRim", (0.0, 1.65, 1.80), (0.0, 0.0, 0.45), 250.0, 4.4, (0.86, 0.92, 1.0))

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    print(f"[MP_CHARS_PREVIEW_RENDERED] {PREVIEW_PATH}")


def main():
    builders = [
        ("mp_char_guillotine.glb", build_mp_guillotine),
        ("mp_char_monarch.glb",    build_mp_monarch),
        ("mp_char_jester.glb",     build_mp_jester),
        ("mp_char_mistblade.glb",  build_mp_mistblade),
    ]
    for fname, build_fn in builders:
        reset_scene()
        M = get_mats()
        root = build_fn(M)
        export_character_glb(root, OUT_DIR / fname)

    render_mp_lineup_preview(builders)
    print("[MP_CHARS_ALL_DONE]")


if __name__ == "__main__":
    main()
