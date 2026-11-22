"""
Blender 5.3.0 headless generator for LIALO's 5 Era Opponent 3D Models (Task #3):
Generates 5 completely distinct, anatomically & sartorially sculpted seated upper-body
character models in D:/downpour-godot/assets/models/opponents/:
  1. opp_antika.glb     (Ancient Egypt - Temple Guard / High Scribe)
  2. opp_rim.glb        (Rome - Arena Gladiator / Centurion)
  3. opp_stredovek.glb  (Medieval - Knight / Tavern Squire)
  4. opp_objavy.glb     (Age of Sail - Corsair / Sea Navigator)
  5. opp_prohibicia.glb (1930s Prohibition - Syndicate Enforcer)

Each GLB exposes the exact required pivot hierarchy for Wave 2 battle-integrator & CinematicDirector:
  - TorsoPivot (root torso at local 0,0,0)
  - HeadPivot  (at neck/head base, local Godot ~(0.0, 0.562, 0.01))
  - ArmLPivot  (left shoulder pivot, local Godot ~(-shoulder_x, 0.44, 0.02))
  - ArmRPivot  (right shoulder pivot, local Godot ~(+shoulder_x, 0.44, 0.02))
  - EyeL, EyeR (glowing/distinctive eye MeshInstance3D nodes under HeadPivot)

Orientation & Coordinate Contract (with export_yup=True):
  - Blender (x, y, z) -> Godot (x, z, -y)
  - Front of character faces Blender -Y (= Godot +Z, directly toward player across the table).

Run via:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_era_opponents.py
"""
import math
import pathlib
import bpy
import bmesh
from mathutils import Vector, Euler

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_DIR = ROOT / "assets" / "models" / "opponents"
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a7664877-b33a-48d0-8658-be5de670b3ca\scratch\era_opponents_preview.png"
)


def smoothstep(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
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
    roughness: float = 0.55,
    emission: tuple = (0.0, 0.0, 0.0),
    emit_str: float = 0.0,
    coat: float = 0.0,
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
    if emit_str > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = float(emit_str)
    return mat


def get_mats():
    # True linear RGB values calibrated for LIALO's rich, high-contrast candlelight tavern PBR palette
    return {
        # Distinct era skin, lip & hair tones
        "skin_antika":     make_mat("SkinAntika",     (0.20, 0.092, 0.045), roughness=0.44),
        "skin_rim":        make_mat("SkinRim",        (0.26, 0.130, 0.072), roughness=0.48),
        "skin_stredovek":  make_mat("SkinStredovek",  (0.28, 0.150, 0.092), roughness=0.50),
        "skin_objavy":     make_mat("SkinObjavy",     (0.23, 0.115, 0.062), roughness=0.48),
        "skin_prohibicia": make_mat("SkinProhibicia", (0.27, 0.148, 0.095), roughness=0.46),

        "lip_antika":      make_mat("LipAntika",      (0.13, 0.048, 0.028), roughness=0.40),
        "lip_warm":        make_mat("LipWarm",        (0.18, 0.062, 0.045), roughness=0.42),

        "hair_dark":       make_mat("HairDark",       (0.018, 0.014, 0.012), roughness=0.70),
        "hair_brown":      make_mat("HairBrown",      (0.048, 0.025, 0.014), roughness=0.72),
        "hair_iron":       make_mat("HairIron",       (0.065, 0.052, 0.045), roughness=0.68),
        "stubble_noir":    make_mat("StubbleNoir",    (0.085, 0.062, 0.052), roughness=0.72),
        "socket_dark":     make_mat("SocketDark",     (0.010, 0.008, 0.010), roughness=0.90),
        "sclera":          make_mat("EyeSclera",      (0.58, 0.50, 0.40), roughness=0.22),
        "pupil_dark":      make_mat("EyePupil",       (0.01, 0.01, 0.015), roughness=0.10),
        "scar_red":        make_mat("ScarRed",        (0.18, 0.028, 0.028), roughness=0.50),

        # Distinctive glowing eye iris materials per era
        "eye_antika":      make_mat("EyeAntika",      (1.0, 0.65, 0.10), roughness=0.10,
                                    emission=(1.0, 0.60, 0.08), emit_str=3.2),
        "eye_rim":         make_mat("EyeRim",         (1.0, 0.48, 0.10), roughness=0.10,
                                    emission=(1.0, 0.42, 0.08), emit_str=3.0),
        "eye_stredovek":   make_mat("EyeStredovek",   (0.22, 0.78, 1.0), roughness=0.10,
                                    emission=(0.18, 0.74, 1.0), emit_str=3.2),
        "eye_objavy":      make_mat("EyeObjavy",      (0.14, 0.92, 0.62), roughness=0.10,
                                    emission=(0.10, 0.88, 0.58), emit_str=3.0),
        "eye_prohibicia":  make_mat("EyeProhibicia",  (1.0, 0.30, 0.08), roughness=0.10,
                                    emission=(1.0, 0.25, 0.06), emit_str=3.2),

        # Era 1: Antika (Ancient Egypt)
        "egypt_gold":      make_mat("EgyptGold",      (0.88, 0.56, 0.10), metallic=0.94, roughness=0.20, double_sided=True),
        "egypt_lapis":     make_mat("EgyptLapis",     (0.016, 0.048, 0.22), metallic=0.25, roughness=0.28, double_sided=True),
        "egypt_turq":      make_mat("EgyptTurquoise", (0.035, 0.38, 0.36), metallic=0.18, roughness=0.24,
                                    emission=(0.03, 0.32, 0.30), emit_str=0.55),
        "egypt_carnelian": make_mat("EgyptCarnelian", (0.36, 0.018, 0.012), roughness=0.20,
                                    emission=(0.35, 0.02, 0.01), emit_str=0.45),
        "egypt_linen":     make_mat("EgyptLinen",     (0.62, 0.53, 0.38), roughness=0.68, double_sided=True),
        "egypt_kohl":      make_mat("EgyptKohl",      (0.012, 0.012, 0.016), metallic=0.30, roughness=0.24),

        # Era 2: Rim (Ancient Rome)
        "roman_steel":     make_mat("RomanSteel",     (0.42, 0.45, 0.50), metallic=0.92, roughness=0.24),
        "roman_bronze":    make_mat("RomanBronze",    (0.74, 0.44, 0.12), metallic=0.91, roughness=0.23),
        "roman_crimson":   make_mat("RomanCrimson",   (0.18, 0.012, 0.015), roughness=0.66, double_sided=True),
        "roman_crest":     make_mat("RomanCrest",     (0.32, 0.018, 0.018), roughness=0.74, double_sided=True),
        "roman_leather":   make_mat("RomanLeather",   (0.075, 0.030, 0.014), roughness=0.54),
        "roman_iron":      make_mat("RomanIron",      (0.14, 0.15, 0.18), metallic=0.88, roughness=0.35),

        # Era 3: Stredovek (Medieval Knight)
        "knight_steel":    make_mat("KnightSteel",    (0.52, 0.56, 0.62), metallic=0.94, roughness=0.20),
        "knight_mail":     make_mat("KnightMail",     (0.11, 0.12, 0.14), metallic=0.86, roughness=0.44, double_sided=True),
        "knight_burgundy": make_mat("KnightBurgundy", (0.14, 0.010, 0.022), roughness=0.68, double_sided=True),
        "knight_gold":     make_mat("KnightGold",     (0.84, 0.52, 0.11), metallic=0.92, roughness=0.22),
        "knight_leather":  make_mat("KnightLeather",  (0.065, 0.026, 0.012), roughness=0.52),
        "knight_iron":     make_mat("KnightIron",     (0.18, 0.19, 0.22), metallic=0.90, roughness=0.32),

        # Era 4: Objavy (Age of Sail Corsair / Navigator)
        "corsair_navy":    make_mat("CorsairNavy",    (0.012, 0.042, 0.078), roughness=0.64, double_sided=True),
        "corsair_revers":  make_mat("CorsairRevers",  (0.14, 0.014, 0.022), roughness=0.60),
        "corsair_brass":   make_mat("CorsairBrass",   (0.78, 0.48, 0.11), metallic=0.91, roughness=0.23),
        "corsair_tricorn": make_mat("CorsairTricorn", (0.028, 0.022, 0.018), roughness=0.54, double_sided=True),
        "corsair_leather": make_mat("CorsairLeather", (0.088, 0.036, 0.015), roughness=0.50),
        "corsair_glove":   make_mat("CorsairGlove",   (0.055, 0.024, 0.011), roughness=0.46),
        "corsair_bandana": make_mat("CorsairBandana", (0.26, 0.016, 0.022), roughness=0.66),
        "corsair_linen":   make_mat("CorsairLinen",   (0.66, 0.58, 0.44), roughness=0.68),
        "corsair_compass": make_mat("CorsairCompass", (0.12, 0.85, 0.74), roughness=0.14,
                                    emission=(0.10, 0.82, 0.72), emit_str=2.1),

        # Era 5: Prohibicia (1930s Syndicate Enforcer)
        "noir_charcoal":   make_mat("NoirCharcoal",   (0.022, 0.023, 0.028), roughness=0.60, double_sided=True),
        "noir_lapel":      make_mat("NoirLapel",      (0.032, 0.034, 0.042), roughness=0.52, double_sided=True),
        "noir_pinstripe":  make_mat("NoirPinstripe",  (0.14, 0.15, 0.18), roughness=0.50),
        "noir_fedora":     make_mat("NoirFedora",     (0.034, 0.035, 0.042), roughness=0.58, double_sided=True),
        "noir_crimson":    make_mat("NoirCrimson",    (0.28, 0.014, 0.022), roughness=0.34, double_sided=True),
        "noir_ivory":      make_mat("NoirIvory",      (0.70, 0.64, 0.52), roughness=0.58),
        "noir_glove":      make_mat("NoirGlove",      (0.012, 0.012, 0.015), roughness=0.28, coat=0.28),
        "noir_ruby":       make_mat("NoirRuby",       (0.90, 0.04, 0.09), roughness=0.10,
                                    emission=(0.88, 0.04, 0.08), emit_str=2.6),
        "noir_cigar":      make_mat("NoirCigar",      (0.11, 0.048, 0.020), roughness=0.70),
        "noir_ash":        make_mat("NoirAsh",        (0.26, 0.25, 0.24), roughness=0.86),
        "noir_ember":      make_mat("NoirEmber",      (1.0, 0.25, 0.03), roughness=0.14,
                                    emission=(1.0, 0.24, 0.02), emit_str=5.6),
    }


# =============================================================================
# GEOMETRY & HIERARCHY HELPERS
# =============================================================================

def make_pivot(parent, name: str, loc=(0.0, 0.0, 0.0)):
    piv = bpy.data.objects.new(name, None)
    piv.empty_display_size = 0.05
    bpy.context.scene.collection.objects.link(piv)
    piv.parent = parent
    piv.location = loc
    return piv


def link_bm(parent, name: str, bm: bmesh.types.BMesh, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    if len(bm.faces) > 0:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
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


def add_cyl(parent, name: str, r_bot: float, r_top: float, h: float, mat, segs=20, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r_bot, radius2=r_top, depth=h)
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_sphere(parent, name: str, radius: float, mat, scale_xyz=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), segs=20, rings=12, smooth=True):
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
    if bevel_w > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel_w, segments=2, affect="EDGES")
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=(bevel_w > 0.0))


# =============================================================================
# SHARED SCULPTED HEAD, EYES (EyeL / EyeR) & BASE PIVOT RIG
# =============================================================================

def create_character_pivots(shoulder_x: float = 0.258):
    """Creates exact required pivot contract: TorsoPivot -> HeadPivot, ArmLPivot, ArmRPivot."""
    torso_piv = make_pivot(None, "TorsoPivot", loc=(0.0, 0.0, 0.0))
    head_piv = make_pivot(torso_piv, "HeadPivot", loc=(0.0, -0.01, 0.562))
    arm_l_piv = make_pivot(torso_piv, "ArmLPivot", loc=(-shoulder_x, -0.02, 0.44))
    arm_r_piv = make_pivot(torso_piv, "ArmRPivot", loc=(shoulder_x, -0.02, 0.44))
    return torso_piv, head_piv, arm_l_piv, arm_r_piv


def build_sculpted_head_and_eyes(
    head_piv,
    skin_mat,
    lip_mat,
    brow_mat,
    socket_mat,
    sclera_mat,
    iris_mat,
    pupil_mat,
    jaw_width: float = 1.0,
    cheek_prominence: float = 1.0,
    brow_fierce: float = 1.0,
    nose_aquiline: float = 1.0,
):
    """
    Sculpts anatomical head, neck, ears, chiseled 3D nose bridge & lips, orbital sockets,
    brows, and named EyeL & EyeR meshes directly under HeadPivot.
    """
    def face_eval(nx, ny, nz):
        fwd = -ny  # Blender -Y = Godot +Z (FRONT)
        rx = 0.094 * (jaw_width if nz < 0.0 else 1.0)
        ry = 0.110 if ny > 0.0 else 0.102
        rz = 0.112

        if nz < 0.0:
            t = min(1.0, -nz)
            rx *= 1.0 - (0.31 / max(0.85, jaw_width)) * (t ** 1.15)
            if fwd < 0.2:
                ry *= 1.0 - 0.22 * t

        x = nx * rx
        y = ny * ry
        z = 0.104 + nz * rz

        if fwd > 0.10:
            fm = smoothstep(0.10, 0.55, fwd)
            # Supraorbital Brow Ridge
            brow = math.exp(-((nz - 0.24) / 0.10) ** 2) * smoothstep(0.0, 0.65, 0.72 - abs(nx))
            y -= brow * 0.013 * brow_fierce * fm

            # Recessed Orbital Sockets around (+-0.038, -0.104, 0.106)
            sock = 0.0
            for sx in (-1.0, 1.0):
                dx = (nx - sx * 0.39) / 0.17
                dz = (nz - 0.02) / 0.13
                sock = max(sock, math.exp(-(dx * dx + dz * dz) * 1.45))
            y += sock * 0.022 * fm

            # Aquiline Nose Bridge & Alar Wings
            nose_line = math.exp(-(nx / 0.095) ** 2) * smoothstep(0.28, -0.05, nz) * smoothstep(-0.46, -0.22, nz)
            nose_peak = math.exp(-((nz + 0.18) / 0.14) ** 2)
            y -= nose_line * (0.014 + 0.017 * nose_peak * nose_aquiline) * fm
            alae = math.exp(-((abs(nx) - 0.13) / 0.07) ** 2) * math.exp(-((nz + 0.26) / 0.09) ** 2)
            y -= alae * 0.009 * fm

            # Cheekbones & Hollow Cheeks
            cheek = math.exp(-((abs(nx) - 0.52) / 0.16) ** 2) * math.exp(-((nz + 0.20) / 0.14) ** 2)
            y -= cheek * 0.009 * cheek_prominence * fm
            x += math.copysign(cheek * 0.005 * cheek_prominence * fm, nx)

            hollow = math.exp(-((abs(nx) - 0.46) / 0.16) ** 2) * math.exp(-((nz + 0.48) / 0.16) ** 2)
            y += hollow * 0.0075 * fm
            x -= math.copysign(hollow * 0.0045 * fm, nx)

            # Chin
            chin = math.exp(-(nx / 0.22) ** 2) * math.exp(-((nz + 0.80) / 0.12) ** 2) * fm
            y -= chin * 0.013 * jaw_width
            z -= chin * 0.004

        return (x, y, z)

    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        v.co = Vector(face_eval(d.x, d.y, d.z))
    link_bm(head_piv, "SculptedHead", bm, skin_mat, smooth=True)

    # Distinct Chiseled 3D Nose Bridge, Tip & Nostril Wings so lighting catches the nose sharply
    nose_pts = [
        (0.0, -0.098, 0.118),
        (0.0, -0.114, 0.096),
        (0.0, -0.124 * nose_aquiline, 0.076),
        (0.0, -0.112, 0.068),
    ]
    add_tube(head_piv, "SculptedNoseBridge", nose_pts, [0.0075, 0.0095, 0.0110, 0.0080], skin_mat, segs=10,
             scale_xy_fn=lambda i, n: (0.85, 1.15))
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        add_sphere(head_piv, f"NoseNostrilWing_{s_ch}", 0.0085, skin_mat, scale_xyz=(1.1, 1.0, 0.75),
                   loc=(sx * 0.011, -0.112, 0.072), segs=10, rings=8)

    # Sculpted Upper & Lower Lip Ridges + Dark Mouth Line
    upper_lip_pts = [(-0.022, -0.098, 0.045), (-0.010, -0.107, 0.048), (0.0, -0.108, 0.047), (0.010, -0.107, 0.048), (0.022, -0.098, 0.045)]
    lower_lip_pts = [(-0.020, -0.096, 0.038), (0.0, -0.106, 0.036), (0.020, -0.096, 0.038)]
    mouth_seam_pts = [(-0.023, -0.098, 0.042), (0.0, -0.107, 0.042), (0.023, -0.098, 0.042)]
    add_tube(head_piv, "SculptedUpperLip", upper_lip_pts, [0.0032, 0.0052, 0.0050, 0.0052, 0.0032], lip_mat, segs=8)
    add_tube(head_piv, "SculptedLowerLip", lower_lip_pts, [0.0034, 0.0056, 0.0034], lip_mat, segs=8)
    add_tube(head_piv, "SculptedMouthCrease", mouth_seam_pts, [0.0018, 0.0024, 0.0018], socket_mat, segs=6)

    # Sculpted Neck column & sternocleidomastoid taper
    add_lathe(head_piv, "SculptedNeck", [
        (0.074, -0.055), (0.066, -0.018), (0.062, 0.022), (0.064, 0.045)
    ], skin_mat, segs=22)

    # Anatomical Ears
    for sx, side_ch in ((-1.0, "L"), (1.0, "R")):
        add_sphere(
            head_piv, f"SculptedEar_{side_ch}", 0.022, skin_mat,
            scale_xyz=(0.38, 0.65, 1.06),
            loc=(sx * 0.092 * jaw_width, 0.004, 0.098),
            rot=(0, sx * 12.0, -sx * 10.0),
            segs=14, rings=10,
        )

    # Furrowed Brows
    for sx, side_ch in ((-1.0, "L"), (1.0, "R")):
        brow_pts = [
            (sx * 0.013, -0.107, 0.120 - 0.003 * brow_fierce),
            (sx * 0.036, -0.110, 0.130),
            (sx * 0.062, -0.096, 0.126),
        ]
        add_tube(
            head_piv, f"SculptedBrow_{side_ch}", brow_pts,
            [0.0072, 0.0080, 0.0046], brow_mat, segs=8,
            scale_xy_fn=lambda i, n: (1.0, 0.72),
        )

    # Recessed Eye Sockets + REQUIRED Named EyeL & EyeR Meshes under HeadPivot
    for sx, eye_name in ((-1.0, "EyeL"), (1.0, "EyeR")):
        add_sphere(
            head_piv, f"EyeSocket_{eye_name}", 0.0165, socket_mat,
            scale_xyz=(1.24, 0.46, 0.78),
            loc=(sx * 0.038, -0.095, 0.106),
            segs=14, rings=10,
        )

        # Composite EyeL / EyeR mesh centered at eye origin (0: sclera, 1: glowing iris, 2: dark pupil)
        bm_eye = bmesh.new()
        res_s = bmesh.ops.create_uvsphere(bm_eye, u_segments=14, v_segments=10, radius=0.0115)
        for v in res_s["verts"]:
            v.co.x *= 1.16
            v.co.y *= 0.60
            v.co.z *= 0.78
            v.co.y += 0.003
        for f in bm_eye.faces:
            f.material_index = 0

        # Glowing Iris ring/dome forward along -Y (material index 1)
        bm_iris = bmesh.new()
        bmesh.ops.create_uvsphere(bm_iris, u_segments=14, v_segments=10, radius=0.0084)
        for v in bm_iris.verts:
            v.co.x *= 1.02
            v.co.y *= 0.55
            v.co.z *= 0.88
            v.co.y -= 0.0032
        for v_map_src, mat_idx in ((bm_iris, 1),):
            v_map = {v: bm_eye.verts.new(v.co) for v in v_map_src.verts}
            for f in v_map_src.faces:
                nf = bm_eye.faces.new(tuple(v_map[v] for v in f.verts))
                nf.material_index = mat_idx
        bm_iris.free()

        # Focused Dark Pupil slit/disc on front of iris (material index 2)
        bm_pup = bmesh.new()
        bmesh.ops.create_uvsphere(bm_pup, u_segments=10, v_segments=8, radius=0.0040)
        for v in bm_pup.verts:
            v.co.x *= 0.75
            v.co.y *= 0.42
            v.co.z *= 0.95
            v.co.y -= 0.0068
        v_map_p = {v: bm_eye.verts.new(v.co) for v in bm_pup.verts}
        for f in bm_pup.faces:
            nf = bm_eye.faces.new(tuple(v_map_p[v] for v in f.verts))
            nf.material_index = 2
        bm_pup.free()

        link_bm(
            head_piv, eye_name, bm_eye, [sclera_mat, iris_mat, pupil_mat],
            loc=(sx * 0.038, -0.104, 0.106), smooth=True
        )


def build_articulated_hand(arm_piv, side: float, hand_mat, ring_mat=None):
    """Builds sculpted palm, 4 curled table-poised fingers, and thumb at the wrist end of an arm."""
    p_c = (-side * 0.118, -0.405, -0.218)
    add_sphere(
        arm_piv, f"HandPalm_{'L' if side < 0 else 'R'}", 0.029, hand_mat,
        scale_xyz=(1.06, 1.26, 0.62), loc=p_c, rot=(0, 0, -side * 16.0), segs=14, rings=10
    )
    for fi in range(4):
        foff = (fi - 1.5) * 0.014
        fp0 = (p_c[0] + foff, p_c[1] - 0.024, p_c[2])
        fp1 = (p_c[0] + foff, p_c[1] - 0.052, p_c[2] - 0.012)
        fp2 = (p_c[0] + foff, p_c[1] - 0.072, p_c[2] - 0.026)
        add_tube(arm_piv, f"HandFinger_{'L' if side < 0 else 'R'}_{fi}", [fp0, fp1, fp2], [0.0070, 0.0056, 0.0042], hand_mat, segs=8)
        if ring_mat is not None and fi == 2:
            add_cyl(arm_piv, f"SignetRing_{'L' if side < 0 else 'R'}", 0.0082, 0.0082, 0.006, ring_mat, segs=10,
                    loc=(p_c[0] + foff, p_c[1] - 0.036, p_c[2] - 0.005), rot=(72, 0, 0))
    t0 = (p_c[0] - side * 0.024, p_c[1] - 0.010, p_c[2] - 0.004)
    t1 = (p_c[0] - side * 0.042, p_c[1] - 0.036, p_c[2] - 0.014)
    add_tube(arm_piv, f"HandThumb_{'L' if side < 0 else 'R'}", [t0, t1], [0.0078, 0.0052], hand_mat, segs=8)


# =============================================================================
# 1. OPP_ANTIKA.GLB — ANCIENT EGYPT (TEMPLE GUARD / HIGH SCRIBE)
# =============================================================================

def build_opp_antika(M):
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_character_pivots(shoulder_x=0.256)

    # --- A. TORSO: Sculpted Bronze Muscular Torso + Pleated Linen Pectoral + Layered Usekh Collar ---
    def muscular_torso_eval(u, v):
        ang = u * math.tau
        z = v * 0.55
        if v < 0.26:
            t = v / 0.26
            rx = 0.195 - 0.018 * math.sin(t * math.pi * 0.5)
            ry = 0.128 - 0.010 * math.sin(t * math.pi * 0.5)
        elif v < 0.80:
            t = (v - 0.26) / 0.54
            rx = 0.177 + 0.098 * smoothstep(0.0, 1.0, t)
            ry = 0.118 + 0.036 * math.sin(t * math.pi * 0.7)
        else:
            t = (v - 0.80) / 0.20
            rx = 0.275 * (1.0 - t) + 0.076 * t
            ry = 0.146 * (1.0 - t) + 0.068 * t

        ca, sa = math.cos(ang), math.sin(ang)
        px = ca * rx
        py = -sa * ry
        # Sculpted muscular pectoral slabs, sternum furrow & abdominal definition on front (sa > 0)
        if sa > 0.22 and 0.46 < v < 0.84:
            pec_h = math.sin(smoothstep(0.46, 0.84, v) * math.pi)
            sternum_groove = 1.0 - 0.58 * math.exp(-(ca / 0.16) ** 2)
            py -= pec_h * (sa ** 1.4) * sternum_groove * 0.030
        if sa > 0.35 and 0.18 < v < 0.46:
            ab_rib = 0.007 * math.sin(v * math.pi * 12.0) * (1.0 - 0.65 * math.exp(-(ca / 0.12) ** 2))
            py -= ab_rib * sa
        return (px, py, z)

    add_grid_cloth(torso_piv, "EgyptMuscularTorso", 44, 24, muscular_torso_eval, M["skin_antika"], closed_u=True)

    # Pleated Linen Shendyt Waist Girdle & Fluted Linen Pectoral Sash sitting cleanly outside skin
    def pleated_pectoral_eval(u, v):
        ang = u * math.tau
        z = v * 0.24
        pleat = 0.0045 * math.sin(u * 48.0 * math.tau)
        rx = 0.206 + 0.012 * (1.0 - v) + pleat
        ry = 0.140 + 0.010 * (1.0 - v) + pleat
        return (math.cos(ang) * rx, -math.sin(ang) * ry, z)

    add_grid_cloth(torso_piv, "LinenPleatedWaist", 64, 8, pleated_pectoral_eval, M["egypt_linen"], closed_u=True)

    def pleated_chest_band(u, v):
        ang = -0.10 + u * (math.pi + 0.20)
        z = 0.23 + v * 0.14
        pleat = 0.0040 * math.sin(u * 36.0 * math.pi)
        rx = 0.218 + v * 0.022 + pleat
        ry = 0.152 + v * 0.014 + pleat
        return (math.cos(ang) * rx, -math.sin(ang) * ry, z)

    add_grid_cloth(torso_piv, "LinenPleatedPectoral", 48, 8, pleated_chest_band, M["egypt_linen"], closed_u=False)

    # Trapezoidal Golden Pectoral Plaque with Lapis Winged Scarab & Turquoise Sun Disc
    pec_2d = [(-0.088, 0.26), (0.088, 0.26), (0.072, 0.39), (-0.072, 0.39)]
    add_extruded_poly(torso_piv, "GoldPectoralPlaque", pec_2d, 0.016, M["egypt_gold"], axis="Y", loc=(0.0, -0.168, 0.0), bevel_w=0.003)
    add_extruded_poly(torso_piv, "LapisPectoralInlay", [(-0.072, 0.275), (0.072, 0.275), (0.058, 0.375), (-0.058, 0.375)], 0.018, M["egypt_lapis"], axis="Y", loc=(0.0, -0.170, 0.0), bevel_w=0.002)
    add_sphere(torso_piv, "ScarabBody", 0.022, M["egypt_turq"], scale_xyz=(0.85, 0.55, 1.25), loc=(0.0, -0.180, 0.325), segs=14, rings=10)
    add_sphere(torso_piv, "ScarabSunDisc", 0.013, M["egypt_carnelian"], scale_xyz=(1.0, 0.5, 1.0), loc=(0.0, -0.180, 0.362), segs=12, rings=8)
    for sx in (-1.0, 1.0):
        wing_pts = [(sx * 0.016, -0.178, 0.325), (sx * 0.044, -0.176, 0.338), (sx * 0.068, -0.170, 0.348)]
        add_tube(torso_piv, f"ScarabWing_{'L' if sx < 0 else 'R'}", wing_pts, [0.014, 0.018, 0.008], M["egypt_gold"], segs=8, scale_xy_fn=lambda i, n: (0.45, 1.35))

    # Gilded Royal Belt & Striped Gold/Lapis Hanging Shendyt Apron
    add_grid_cloth(torso_piv, "GoldWaistBelt", 32, 4, lambda u, v: (math.cos(u * math.tau) * 0.218, -math.sin(u * math.tau) * 0.148, 0.205 + v * 0.046), M["egypt_gold"], closed_u=True)
    for bi in range(5):
        bx = (bi - 2) * 0.022
        b_mat = M["egypt_gold"] if bi % 2 == 0 else M["egypt_lapis"]
        add_box(torso_piv, f"ApronStripe_{bi}", (0.020, 0.018, 0.20), b_mat, loc=(bx, -0.154, 0.110), bevel_w=0.002)

    # Broad 4-Tier Gold/Lapis/Turquoise/Carnelian Usekh Collar across Shoulders & Chest
    usekh_tiers = [
        (0.118, 0.532, 0.015, M["egypt_gold"]),
        (0.152, 0.512, 0.016, M["egypt_lapis"]),
        (0.188, 0.488, 0.016, M["egypt_turq"]),
        (0.224, 0.462, 0.017, M["egypt_gold"]),
    ]
    for ti, (rad_w, z_top, r_tube, t_mat) in enumerate(usekh_tiers):
        u_pts = []
        for si in range(29):
            a = (si / 28.0) * math.tau
            front_dip = max(0.0, math.sin(a)) * (0.020 + ti * 0.012)
            u_pts.append((math.cos(a) * rad_w * 1.18, -math.sin(a) * (rad_w * 0.80 + 0.015), z_top - front_dip))
        add_tube(torso_piv, f"UsekhCollarTier_{ti}", u_pts, r_tube, t_mat, segs=10, cap_ends=False, scale_xy_fn=lambda i, n: (1.15, 0.72))

    # Beaded Drop Jewels around the outer Usekh rim
    for gi in range(11):
        ga = -1.15 + (gi / 10.0) * 2.30
        g_mat = M["egypt_carnelian"] if gi % 2 == 0 else M["egypt_turq"]
        add_sphere(torso_piv, f"UsekhDropJewel_{gi}", 0.011, g_mat, scale_xyz=(0.8, 0.6, 1.3),
                   loc=(math.sin(ga) * 0.242, -math.cos(ga) * 0.172, 0.432 - 0.028 * math.cos(ga)), segs=10, rings=8)

    # Pleated Linen Temple Back Cloak draping from shoulders
    def egypt_cloak_eval(u, v):
        un = (u - 0.5) * 2.0
        w = 0.25 + 0.09 * (v ** 0.8)
        px = un * w
        pz = 0.51 - v * 0.50
        pleat = 0.012 * math.sin(un * math.pi * 6.0) * (0.2 + 0.8 * v)
        py = 0.105 + 0.065 * math.sin(v * math.pi * 0.65) + pleat
        return (px, py, pz)

    add_grid_cloth(torso_piv, "EgyptLinenMantle", 32, 16, egypt_cloak_eval, M["egypt_linen"], closed_u=False)

    # --- B. HEAD: Bronze Noble Head, Kohl Eyeliner Wings, Braided Beard & Sculpted Nemes with Uraeus Cobra ---
    build_sculpted_head_and_eyes(
        head_piv, M["skin_antika"], M["lip_antika"], M["egypt_kohl"], M["socket_dark"],
        M["sclera"], M["eye_antika"], M["pupil_dark"],
        jaw_width=0.96, cheek_prominence=1.22, brow_fierce=1.10, nose_aquiline=1.15
    )

    # Winged Obsidian Kohl Eyeliner framing EyeL and EyeR
    for sx, side_ch in ((-1.0, "L"), (1.0, "R")):
        upper_kohl = [
            (sx * 0.020, -0.106, 0.110),
            (sx * 0.038, -0.112, 0.116),
            (sx * 0.056, -0.104, 0.112),
            (sx * 0.078, -0.078, 0.115),
        ]
        lower_kohl = [
            (sx * 0.022, -0.106, 0.101),
            (sx * 0.038, -0.111, 0.097),
            (sx * 0.056, -0.103, 0.103),
        ]
        add_tube(head_piv, f"KohlWingUpper_{side_ch}", upper_kohl, [0.0030, 0.0038, 0.0036, 0.0020], M["egypt_kohl"], segs=6)
        add_tube(head_piv, f"KohlRimLower_{side_ch}", lower_kohl, [0.0026, 0.0032, 0.0026], M["egypt_kohl"], segs=6)

    # Braided Ceremonial Gold & Kohl Pharaoh/Guard Beard
    add_tube(head_piv, "CeremonialBeard", [
        (0.0, -0.074, 0.012), (0.0, -0.086, -0.032), (0.0, -0.100, -0.068), (0.0, -0.112, -0.076)
    ], [0.015, 0.013, 0.011, 0.009], M["egypt_gold"], segs=10)
    for bi in range(3):
        add_cyl(head_piv, f"BeardKohlRing_{bi}", 0.0148, 0.0148, 0.007, M["egypt_kohl"], segs=10,
                loc=(0.0, -0.082 - bi * 0.007, -0.008 - bi * 0.020), rot=(15, 0, 0))

    # Sculpted Vaulted Trapezoidal Nemes Headdress with Solid 3D Hood Crown & Symmetrical Striped Gold/Lapis Wings
    # Top skull cap of the Nemes cloth seated strictly ABOVE the gold brow band (z >= 0.155) so forehead & brows stay 100% clear!
    add_lathe(
        head_piv, "NemesCrownCap",
        [(0.104, 0.155), (0.106, 0.182), (0.092, 0.215), (0.056, 0.238), (0.008, 0.246)],
        M["egypt_lapis"], segs=28, loc=(0.0, 0.006, 0.0)
    )
    for ci, z_c in enumerate((0.180, 0.198, 0.216, 0.232)):
        r_c = 0.105 * math.sqrt(max(0.05, 1.0 - ((z_c - 0.155) / 0.095) ** 1.7))
        arc_pts = [
            (math.cos(a) * r_c, -math.sin(a) * r_c + 0.006, z_c)
            for a in [math.pi * (0.08 + 0.84 * (k / 18.0)) for k in range(19)]
        ]
        add_tube(head_piv, f"NemesCrownGoldBand_{ci}", arc_pts, 0.0042, M["egypt_gold"], segs=6)

    # Monotonic Non-Self-Intersecting Trapezoidal Nemes Wings (sweeping smoothly from Left Wing un=-1 across Crown un=0 to Right Wing un=+1)
    def nemes_hood_pt(u, v, y_offset=0.0):
        un = (u - 0.5) * 2.0  # -1.0 (left wing) .. 0.0 (center crown) .. +1.0 (right wing)
        z = 0.032 + v * 0.215
        # Dramatic trapezoidal Egyptian Nemes wing flare at mid-height
        wing_arch = math.sin(v * math.pi * 0.80) ** 0.72
        half_w = 0.128 + 0.105 * wing_arch
        if v > 0.74:
            t_top = (v - 0.74) / 0.26
            half_w *= 1.0 - 0.34 * t_top
            z += 0.022 * t_top * (1.0 - 0.4 * un * un)
        px = un * half_w
        # Outer wings frame the head at y ~ -0.015, while the center curves behind the head (+Y) so the face is completely open!
        center_back_curve = (1.0 - un * un) * (0.095 - 0.035 * v)
        wing_cup = -0.018 * (un * un) * math.sin(v * math.pi)
        py = -0.012 + center_back_curve + wing_cup + y_offset
        return (px, py, z)

    add_grid_cloth(head_piv, "NemesHeaddressHoodFront", 36, 18, lambda u, v: nemes_hood_pt(u, v, 0.0), M["egypt_lapis"], closed_u=False)
    add_grid_cloth(head_piv, "NemesHeaddressHoodBack", 36, 18, lambda u, v: nemes_hood_pt(u, v, 0.016), M["egypt_lapis"], closed_u=False)

    # Gold Striped Horizontal Ribs across Both Nemes Wings & Outer Gold Wing Border
    for ri in range(6):
        vf = 0.14 + ri * 0.13
        # Left wing stripe (-1.0 .. -0.42) and Right wing stripe (+0.42 .. +1.0) visible framing the head
        for s_name, u0, u1 in (("L", 0.0, 0.30), ("R", 0.70, 1.0)):
            rib_pts = [nemes_hood_pt(u0 + (u1 - u0) * (ui / 12.0), vf, -0.004) for ui in range(13)]
            add_tube(head_piv, f"NemesGoldStripe_{s_name}_{ri}", rib_pts, 0.0058, M["egypt_gold"], segs=6)

    outer_border_pts = (
        [nemes_hood_pt(0.0, vi / 18.0, 0.004) for vi in range(19)]
        + [nemes_hood_pt(ui / 24.0, 1.0, 0.004) for ui in range(1, 24)]
        + [nemes_hood_pt(1.0, 1.0 - vi / 18.0, 0.004) for vi in range(19)]
    )
    add_tube(head_piv, "NemesOuterGoldBorder", outer_border_pts, 0.0105, M["egypt_gold"], segs=8)

    # Chased Gold Forehead Brow Diadem
    add_lathe(head_piv, "NemesGoldBrowBand", [
        (0.104, 0.138), (0.112, 0.148), (0.111, 0.172), (0.102, 0.178)
    ], M["egypt_gold"], segs=28)

    # Striated Gold & Lapis Front Lappets framing neck & chest
    for sx, side_ch in ((-1.0, "L"), (1.0, "R")):
        for si in range(6):
            l_mat = M["egypt_gold"] if si % 2 == 0 else M["egypt_lapis"]
            add_box(
                head_piv, f"NemesLappet_{side_ch}_{si}", (0.056, 0.022, 0.036), l_mat,
                loc=(sx * (0.134 - si * 0.006), -0.054 - si * 0.010, 0.095 - si * 0.036),
                rot=(-12.0, 0.0, sx * 10.0), bevel_w=0.003
            )
    add_tube(head_piv, "NemesBackQueue", [
        (0.0, 0.115, 0.065), (0.0, 0.135, 0.0), (0.0, 0.142, -0.065)
    ], [0.028, 0.022, 0.016], M["egypt_gold"], segs=10)

    # Sculpted Golden Uraeus Cobra Crest rearing at forehead center
    cobra_pts = [
        (0.0, -0.108, 0.155),
        (0.0, -0.132, 0.178),
        (0.0, -0.126, 0.212),
        (0.0, -0.138, 0.242),
        (0.0, -0.154, 0.248),
    ]
    add_tube(
        head_piv, "UraeusCobraBody", cobra_pts,
        [0.009, 0.015, 0.024, 0.016, 0.008], M["egypt_gold"], segs=12,
        scale_xy_fn=lambda i, n: (2.2 if i == 2 else 1.2, 0.65)
    )
    add_sphere(head_piv, "UraeusSunCrown", 0.015, M["egypt_carnelian"], scale_xyz=(1.0, 0.55, 1.0), loc=(0.0, -0.136, 0.265), segs=12, rings=8)
    for sx in (-1.0, 1.0):
        add_sphere(head_piv, f"UraeusEye_{int(sx)}", 0.0040, M["eye_antika"], loc=(sx * 0.007, -0.152, 0.248), segs=8, rings=6)

    # --- C. ARMS: Bare Muscular Bronze Arms, Golden Serpent Armlets & Hammered Gold/Lapis Bracers ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        arm_pts = [
            (0.0, 0.0, 0.0),
            (side * 0.026, -0.055, -0.105),
            (-side * 0.024, -0.145, -0.195),
            (-side * 0.072, -0.265, -0.205),
            (-side * 0.105, -0.365, -0.215),
        ]
        add_tube(arm_piv, f"BronzeArm_{s_ch}", arm_pts, [0.062, 0.055, 0.048, 0.041, 0.034], M["skin_antika"], segs=16)
        armlet_pts = [(side * 0.016, -0.036, -0.068), (side * 0.022, -0.052, -0.098)]
        add_tube(arm_piv, f"GoldArmlet_{s_ch}", armlet_pts, [0.060, 0.058], M["egypt_gold"], segs=16)
        bracer_pts = [
            (-side * 0.052, -0.215, -0.201),
            (-side * 0.078, -0.285, -0.208),
            (-side * 0.104, -0.362, -0.215),
        ]
        add_tube(arm_piv, f"GoldBracer_{s_ch}", bracer_pts, [0.051, 0.047, 0.042], M["egypt_gold"], segs=16)
        lapis_pts = [(-side * 0.064, -0.246, -0.204), (-side * 0.092, -0.326, -0.211)]
        add_tube(arm_piv, f"BracerLapisInlay_{s_ch}", lapis_pts, [0.0525, 0.0465], M["egypt_lapis"], segs=16)
        build_articulated_hand(arm_piv, side, M["skin_antika"], ring_mat=M["egypt_gold"])

    return torso_piv


# =============================================================================
# 2. OPP_RIM.GLB — ROME (ARENA GLADIATOR / CENTURION)
# =============================================================================

def build_opp_rim(M):
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_character_pivots(shoulder_x=0.268)

    # --- A. TORSO: Lorica Segmentata Steel/Bronze Cuirass + Shoulder Plates + Crimson Paludamentum Cloak ---
    def lorica_rx_ry(v):
        if v < 0.82:
            rx = 0.204 + 0.066 * smoothstep(0.18, 0.82, v)
            ry = 0.136 + 0.028 * math.sin(v * math.pi * 0.75)
        else:
            t = (v - 0.82) / 0.18
            rx = 0.270 * (1.0 - t) + 0.088 * t
            ry = 0.154 * (1.0 - t) + 0.076 * t
        return rx, ry

    def lorica_base_eval(u, v):
        ang = u * math.tau
        z = v * 0.55
        rx, ry = lorica_rx_ry(v)
        return (math.cos(ang) * rx, -math.sin(ang) * ry, z)

    # Crimson Tunica Underlayer
    add_grid_cloth(torso_piv, "RomanTunicaBase", 32, 16, lorica_base_eval, M["roman_crimson"], closed_u=True)

    # 5 Overlapping Horizontal Articulated Lorica Segmentata Steel Hoop Bands OUTSIDE the tunic!
    for hi in range(5):
        z_bot = 0.14 + hi * 0.052
        v_mid = (z_bot + 0.026) / 0.55
        rx_base, ry_base = lorica_rx_ry(v_mid)
        rx_h = rx_base + 0.012 + hi * 0.002
        ry_h = ry_base + 0.012 + hi * 0.002
        add_grid_cloth(
            torso_piv, f"LoricaGirthHoop_{hi}", 36, 4,
            lambda u, v, rxh=rx_h, ryh=ry_h, zb=z_bot: (
                math.cos(u * math.tau) * (rxh + v * 0.005),
                -math.sin(u * math.tau) * (ryh + v * 0.005),
                zb + v * 0.048
            ),
            M["roman_steel"], closed_u=True
        )
        # Bronze Trim Rim along bottom of each girth hoop
        hoop_rim_pts = [
            (math.cos(i * math.tau / 32.0) * (rx_h + 0.003), -math.sin(i * math.tau / 32.0) * (ry_h + 0.003), z_bot + 0.002)
            for i in range(33)
        ]
        add_tube(torso_piv, f"LoricaHoopBronzeRim_{hi}", hoop_rim_pts, 0.0042, M["roman_bronze"], segs=6, cap_ends=False)
        # Bronze Hinge Bosses & Leather Lacing on Front Center
        for sx in (-1.0, 1.0):
            add_box(torso_piv, f"LoricaBronzeHasps_{hi}_{int(sx)}", (0.028, 0.014, 0.022), M["roman_bronze"],
                    loc=(sx * 0.030, -ry_h - 0.008, z_bot + 0.024), bevel_w=0.002)
        add_cyl(torso_piv, f"LoricaLace_{hi}", 0.0045, 0.0045, 0.052, M["roman_leather"], segs=8,
                loc=(0.0, -ry_h - 0.010, z_bot + 0.024), rot=(0, 90, 0))

    # Upper Chest Plates & Embossed Bronze Aquila Eagle Gorgoneion Medallion sitting cleanly OUTSIDE
    add_extruded_poly(torso_piv, "LoricaChestPlateL", [(-0.165, 0.385), (-0.018, 0.385), (-0.018, 0.515), (-0.145, 0.530)], 0.022, M["roman_steel"], axis="Y", loc=(0.0, -0.172, 0.0), bevel_w=0.004)
    add_extruded_poly(torso_piv, "LoricaChestPlateR", [(0.018, 0.385), (0.165, 0.385), (0.145, 0.530), (0.018, 0.515)], 0.022, M["roman_steel"], axis="Y", loc=(0.0, -0.172, 0.0), bevel_w=0.004)
    add_cyl(torso_piv, "AquilaChestMedallion", 0.048, 0.048, 0.018, M["roman_bronze"], segs=18, loc=(0.0, -0.184, 0.445), rot=(85, 0, 0))
    for sx in (-1.0, 1.0):
        add_tube(torso_piv, f"AquilaReliefWing_{'L' if sx < 0 else 'R'}", [
            (sx * 0.015, -0.188, 0.445), (sx * 0.072, -0.182, 0.465), (sx * 0.128, -0.168, 0.482)
        ], [0.014, 0.018, 0.008], M["roman_bronze"], segs=8, scale_xy_fn=lambda i, n: (0.45, 1.4))

    # Layered Lorica Segmentata Curved Shoulder Plates (3 smooth curved grid_cloth plates per shoulder — zero tube twist!)
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        for pi in range(3):
            x_in = sx * (0.175 + pi * 0.044)
            x_out = sx * (0.238 + pi * 0.044)
            z_peak = 0.545 - pi * 0.024

            def shoulder_plate_eval(u, v, xi=x_in, xo=x_out, zp=z_peak):
                # u: 0..1 from inner to outer shoulder; v: 0..1 from front (-Y) over top to back (+Y)
                ang = (v - 0.5) * math.pi * 0.92
                px = xi + (xo - xi) * u
                py = math.sin(ang) * 0.142
                pz = zp - 0.068 * (1.0 - math.cos(ang)) - u * 0.018
                return (px, py, pz)

            p_mat = M["roman_steel"] if pi != 1 else M["roman_bronze"]
            add_grid_cloth(torso_piv, f"LoricaShoulderPlate_{s_ch}_{pi}", 8, 14, shoulder_plate_eval, p_mat, closed_u=False)
            outer_rim = [shoulder_plate_eval(1.0, vi / 14.0) for vi in range(15)]
            add_tube(torso_piv, f"LoricaShoulderRim_{s_ch}_{pi}", outer_rim, 0.0048, M["roman_bronze"], segs=6)

        # Leather & Bronze Pteruges (fringed military strips) under shoulder
        for pti in range(4):
            add_box(torso_piv, f"ShoulderPteruge_{s_ch}_{pti}", (0.024, 0.012, 0.088),
                    M["roman_leather"] if pti % 2 == 0 else M["roman_bronze"],
                    loc=(sx * 0.285, -0.055 + pti * 0.036, 0.395),
                    rot=(0, -sx * 20.0, 0), bevel_w=0.002)

    # Wide Leather & Bronze Cingulum Militare Waist Belt
    add_grid_cloth(torso_piv, "RomanCingulumBelt", 32, 4, lambda u, v: (math.cos(u * math.tau) * 0.228, -math.sin(u * math.tau) * 0.156, 0.080 + v * 0.058), M["roman_leather"], closed_u=True)
    for bi in range(8):
        ba = (bi / 8.0) * math.tau
        add_box(torso_piv, f"CingulumBronzePlate_{bi}", (0.044, 0.016, 0.046), M["roman_bronze"],
                loc=(math.cos(ba) * 0.230, -math.sin(ba) * 0.158, 0.109),
                rot=(0, 0, math.degrees(-ba) + 90), bevel_w=0.003)

    # Draped Crimson Paludamentum Officer Cloak + Golden Eagle Fibula Clasp on Right Shoulder
    add_cyl(torso_piv, "GoldFibulaBrooch", 0.038, 0.034, 0.018, M["roman_bronze"], segs=16, loc=(0.188, -0.145, 0.515), rot=(72, 0, -14))
    add_sphere(torso_piv, "FibulaBoss", 0.018, M["egypt_gold"], scale_xyz=(1.0, 0.55, 1.0), loc=(0.188, -0.154, 0.515), segs=12, rings=8)

    # Sculpted Pleated Crimson Paludamentum Shoulder/Collarbone Drape (draping cleanly over upper collarbone outside chest plates!)
    def paludamentum_front_drape(u, v):
        # Sweeps from right shoulder Fibula (u=1) across upper collarbone to left shoulder (u=0)
        un = (u - 0.5) * 2.0
        px = un * 0.215
        sag = (1.0 - un * un) * (0.022 + v * 0.024)
        pz = 0.542 - sag - v * 0.036
        pleat = 0.005 * math.sin(v * math.pi * 3.0)
        py = -0.184 - (1.0 - un * un) * 0.022 - pleat
        return (px, py, pz)

    add_grid_cloth(torso_piv, "PaludamentumChestDrape", 24, 8, paludamentum_front_drape, M["roman_crimson"], closed_u=False)

    def paludamentum_back_eval(u, v):
        un = (u - 0.5) * 2.0
        w = 0.29 + 0.12 * (v ** 0.75)
        px = un * w
        pz = 0.53 - v * 0.53
        fold = 0.022 * math.sin(un * math.pi * 3.5 + v * 2.0) * (0.25 + 0.75 * v)
        py = 0.105 + 0.075 * math.sin(v * math.pi * 0.65) + 0.055 * (1.0 - un * un) + fold
        return (px, py, pz)

    add_grid_cloth(torso_piv, "PaludamentumBackCloak", 28, 18, paludamentum_back_eval, M["roman_crimson"], closed_u=False)

    # --- B. HEAD: Scarred Centurion Head + Roman Galea Helmet + Cheek Guards + Crimson Transverse Horsehair Crest ---
    build_sculpted_head_and_eyes(
        head_piv, M["skin_rim"], M["lip_warm"], M["hair_brown"], M["socket_dark"],
        M["sclera"], M["eye_rim"], M["pupil_dark"],
        jaw_width=1.08, cheek_prominence=1.08, brow_fierce=1.32, nose_aquiline=1.22
    )
    add_tube(head_piv, "GladiatorCheekScar", [(0.042, -0.098, 0.088), (0.056, -0.092, 0.062), (0.052, -0.085, 0.036)], 0.0036, M["scar_red"], segs=6)

    # Roman Imperial Galea Helmet Bowl
    add_lathe(head_piv, "GaleaSteelBowl", [
        (0.114, 0.118), (0.120, 0.155), (0.114, 0.195), (0.088, 0.232), (0.012, 0.248)
    ], M["roman_steel"], segs=28)

    # Brass Brow Deflector Peak & Embossed Eyebrow Relief Ridges
    brow_peak_pts = [(-0.112, -0.015, 0.132), (-0.068, -0.102, 0.138), (0.0, -0.128, 0.135), (0.068, -0.102, 0.138), (0.112, -0.015, 0.132)]
    add_tube(head_piv, "GaleaBrassBrowGuard", brow_peak_pts, [0.009, 0.013, 0.015, 0.013, 0.009], M["roman_bronze"], segs=10, scale_xy_fn=lambda i, n: (0.7, 1.35))

    # Flared Rear Lobster Neck Flange (Galea Neck Guard)
    def galea_neck_guard(u, v):
        ang = math.pi * 0.18 + u * (math.pi * 0.64)
        r = 0.114 + v * 0.048
        z = 0.118 - v * 0.055
        return (math.cos(ang) * r, math.sin(ang) * r, z)

    add_grid_cloth(head_piv, "GaleaNeckFlange", 20, 6, galea_neck_guard, M["roman_steel"], closed_u=False)

    # Hinged Sculpted Galea Cheek Guards (Bucculae) with Brass Border & Rivets
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        cheek_pts = [
            (sx * 0.106, -0.018, 0.122),
            (sx * 0.102, -0.052, 0.072),
            (sx * 0.084, -0.078, 0.024),
            (sx * 0.058, -0.086, -0.006),
        ]
        add_tube(head_piv, f"GaleaCheekGuard_{s_ch}", cheek_pts, [0.032, 0.036, 0.030, 0.018], M["roman_steel"], segs=10, scale_xy_fn=lambda i, n: (0.32, 1.35))
        add_tube(head_piv, f"GaleaCheekBrassTrim_{s_ch}", cheek_pts, [0.034, 0.038, 0.032, 0.020], M["roman_bronze"], segs=8, scale_xy_fn=lambda i, n: (0.22, 1.42))

    # Brass Crest Holder Fork & Crimson Transverse Horsehair Crest (Crista Transversa)
    add_box(head_piv, "GaleaCrestMount", (0.044, 0.032, 0.040), M["roman_bronze"], loc=(0.0, 0.0, 0.254), bevel_w=0.003)

    # Sculpted Fan-Shaped Transverse Horsehair Plume sweeping Left-to-Right
    bm_crest = bmesh.new()
    nu_c, nv_c = 40, 8
    front_grid, back_grid = [], []
    for vi in range(nv_c + 1):
        v = vi / float(nv_c)
        f_row, b_row = [], []
        for ui in range(nu_c + 1):
            u = ui / float(nu_c)
            ang = (u - 0.5) * math.pi * 0.94
            r_in = 0.078
            r_out = 0.178 + 0.018 * math.cos(ang * 1.5)
            r = r_in + (r_out - r_in) * v
            hair_flute = 0.004 * math.sin(u * 36.0 * math.pi) * v
            px = math.sin(ang) * r
            pz = 0.184 + math.cos(ang) * r * 0.84
            half_thick = 0.020 * (1.0 - 0.35 * v)
            f_row.append(bm_crest.verts.new((px, -half_thick + hair_flute, pz)))
            b_row.append(bm_crest.verts.new((px, half_thick + hair_flute, pz)))
        front_grid.append(f_row)
        back_grid.append(b_row)
    for vi in range(nv_c):
        for ui in range(nu_c):
            bm_crest.faces.new((front_grid[vi][ui], front_grid[vi][ui + 1], front_grid[vi + 1][ui + 1], front_grid[vi + 1][ui]))
            bm_crest.faces.new((back_grid[vi][ui], back_grid[vi + 1][ui], back_grid[vi + 1][ui + 1], back_grid[vi][ui + 1]))
    for ui in range(nu_c):
        bm_crest.faces.new((front_grid[nv_c][ui], front_grid[nv_c][ui + 1], back_grid[nv_c][ui + 1], back_grid[nv_c][ui]))
    for vi in range(nv_c):
        bm_crest.faces.new((back_grid[vi][0], back_grid[vi + 1][0], front_grid[vi + 1][0], front_grid[vi][0]))
        bm_crest.faces.new((front_grid[vi][nu_c], front_grid[vi + 1][nu_c], back_grid[vi + 1][nu_c], back_grid[vi][nu_c]))
    link_bm(head_piv, "TransverseHorsehairCrest", bm_crest, M["roman_crest"], smooth=True)

    inner_arc = [
        (math.sin((ui / 24.0 - 0.5) * math.pi * 0.94) * 0.080, 0.0, 0.184 + math.cos((ui / 24.0 - 0.5) * math.pi * 0.94) * 0.080 * 0.84)
        for ui in range(25)
    ]
    add_tube(head_piv, "CrestBrassHolderArc", inner_arc, 0.014, M["roman_bronze"], segs=10)

    # --- C. ARMS: Muscular Arms + Iron-Studded Leather & Bronze Vambraces ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        upper_pts = [(0.0, 0.0, 0.0), (side * 0.020, -0.042, -0.080)]
        add_tube(arm_piv, f"TunicaSleeve_{s_ch}", upper_pts, [0.065, 0.058], M["roman_crimson"], segs=16)

        arm_pts = [
            (side * 0.016, -0.035, -0.068),
            (side * 0.025, -0.055, -0.105),
            (-side * 0.025, -0.145, -0.195),
            (-side * 0.072, -0.265, -0.205),
            (-side * 0.105, -0.365, -0.215),
        ]
        add_tube(arm_piv, f"GladiatorArm_{s_ch}", arm_pts, [0.056, 0.054, 0.049, 0.042, 0.035], M["skin_rim"], segs=16)

        # Iron-Studded Leather Vambrace with Bronze Edge Rings
        vambrace_pts = [
            (-side * 0.042, -0.188, -0.198),
            (-side * 0.074, -0.272, -0.206),
            (-side * 0.104, -0.358, -0.214),
        ]
        add_tube(arm_piv, f"LeatherVambrace_{s_ch}", vambrace_pts, [0.053, 0.048, 0.043], M["roman_leather"], segs=16)
        for ri, t_v in enumerate((0.12, 0.50, 0.88)):
            p0 = Vector(vambrace_pts[0]).lerp(Vector(vambrace_pts[-1]), t_v)
            p1 = Vector(vambrace_pts[0]).lerp(Vector(vambrace_pts[-1]), min(1.0, t_v + 0.08))
            r_ring = 0.054 - t_v * 0.009
            add_tube(arm_piv, f"VambraceIronBand_{s_ch}_{ri}", [p0, p1], [r_ring, r_ring], M["roman_iron"], segs=14)
            for sa in (-0.8, 0.0, 0.8):
                stud_pos = p0 + Vector((-side * math.cos(sa) * r_ring, math.sin(sa) * 0.015, math.sin(sa) * r_ring))
                add_sphere(arm_piv, f"VambraceStud_{s_ch}_{ri}_{int(sa*10)}", 0.0085, M["roman_bronze"] if ri == 1 else M["roman_iron"], loc=tuple(stud_pos), segs=10, rings=8)

        build_articulated_hand(arm_piv, side, M["skin_rim"], ring_mat=M["roman_iron"])

    return torso_piv


# =============================================================================
# 3. OPP_STREDOVEK.GLB — MEDIEVAL (KNIGHT / TAVERN SQUIRE)
# =============================================================================

def build_opp_stredovek(M):
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_character_pivots(shoulder_x=0.270)

    # --- A. TORSO: Steel Breastplate + Heraldic Burgundy/Gold Surcoat Tabard + Layered Steel Pauldrons + Leather Baldric ---
    def knight_cuirass_rx_ry(v):
        if v < 0.82:
            rx = 0.212 + 0.070 * smoothstep(0.22, 0.82, v)
            ry = 0.140 + 0.026 * math.sin(v * math.pi * 0.72)
        else:
            t = (v - 0.82) / 0.18
            rx = 0.282 * (1.0 - t) + 0.086 * t
            ry = 0.155 * (1.0 - t) + 0.076 * t
        return rx, ry

    def knight_cuirass_eval(u, v):
        ang = u * math.tau
        z = v * 0.55
        rx, ry = knight_cuirass_rx_ry(v)
        ca, sa = math.cos(ang), math.sin(ang)
        keel = 0.010 * math.exp(-(ca / 0.22) ** 2) * max(0.0, sa) * math.sin(v * math.pi)
        return (ca * rx, -sa * ry - keel, z)

    add_grid_cloth(torso_piv, "GothicSteelCuirass", 36, 18, knight_cuirass_eval, M["knight_steel"], closed_u=True)

    def surcoat_y_at(px, v):
        _, ry = knight_cuirass_rx_ry(v)
        keel = 0.012 * (1.0 - min(1.0, (px / 0.18) ** 2)) * math.sin(v * math.pi * 0.85)
        return -(ry + 0.012 + keel)

    # Heraldic Burgundy Surcoat Tabard draped cleanly OUTSIDE the steel cuirass (zero poke-through!)
    def surcoat_front_eval(u, v):
        un = (u - 0.5) * 2.0
        z = 0.02 + v * 0.50
        w = 0.155 - 0.022 * math.sin(v * math.pi * 0.5) + (0.024 * max(0.0, v - 0.65) / 0.35)
        px = un * w
        fold = 0.004 * math.sin(un * math.pi * 3.0) * (1.0 - v)
        py = surcoat_y_at(px, v) - fold
        return (px, py, z)

    add_grid_cloth(torso_piv, "HeraldicSurcoatFront", 24, 18, surcoat_front_eval, M["knight_burgundy"], closed_u=False)

    # Gold Embroidered Tabard Borders & Neck Collar Trim
    for sx in (-1.0, 1.0):
        border_pts = [surcoat_front_eval(0.0 if sx < 0 else 1.0, vi / 16.0) for vi in range(17)]
        add_tube(torso_piv, f"SurcoatGoldBorder_{'L' if sx < 0 else 'R'}", border_pts, 0.0075, M["knight_gold"], segs=8)
    top_trim_pts = [surcoat_front_eval(ui / 12.0, 1.0) for ui in range(13)]
    add_tube(torso_piv, "SurcoatCollarGoldTrim", top_trim_pts, 0.0080, M["knight_gold"], segs=8)

    # Embossed Gold Heraldic Shield & Fleur-Cross mounted OUTSIDE Surcoat Chest
    y_crest = surcoat_y_at(0.0, 0.65) - 0.010
    shield_2d = [(-0.062, 0.44), (0.062, 0.44), (0.054, 0.33), (0.0, 0.27), (-0.054, 0.33)]
    add_extruded_poly(torso_piv, "HeraldicChestCrest", shield_2d, 0.012, M["knight_gold"], axis="Y", loc=(0.0, y_crest, 0.0), bevel_w=0.003)
    add_extruded_poly(torso_piv, "HeraldicCrestInner", [(-0.048, 0.425), (0.048, 0.425), (0.040, 0.340), (0.0, 0.288), (-0.040, 0.340)], 0.014, M["knight_burgundy"], axis="Y", loc=(0.0, y_crest - 0.002, 0.0), bevel_w=0.002)
    add_box(torso_piv, "HeraldicCrossV", (0.016, 0.014, 0.112), M["knight_gold"], loc=(0.0, y_crest - 0.008, 0.362), bevel_w=0.002)
    add_box(torso_piv, "HeraldicCrossH", (0.076, 0.014, 0.016), M["knight_gold"], loc=(0.0, y_crest - 0.008, 0.376), bevel_w=0.002)

    # Wide Diagonal Leather Baldric arching cleanly OUTSIDE the Surcoat & Heraldic Crest + Forged Iron Buckle
    baldric_pts = []
    for bi in range(11):
        t = bi / 10.0
        bx = 0.205 * (1.0 - t) + (-0.215) * t
        bz = 0.525 * (1.0 - t) + 0.135 * t
        bv = bz / 0.55
        by = surcoat_y_at(bx, bv) - 0.020 + 0.032 * (t - 0.5) ** 2
        baldric_pts.append((bx, by, bz))
    add_tube(torso_piv, "LeatherSwordBaldric", baldric_pts, 0.026, M["knight_leather"], segs=10, scale_xy_fn=lambda i, n: (1.55, 0.32))

    # Forged Iron Baldric Buckle & Gold Studs at Upper-Right Chest
    b_p = baldric_pts[3]
    add_box(torso_piv, "BaldricIronBuckle", (0.056, 0.022, 0.056), M["knight_iron"], loc=(b_p[0], b_p[1] - 0.004, b_p[2]), rot=(0, 42, 0), bevel_w=0.004)
    add_box(torso_piv, "BaldricBuckleInner", (0.030, 0.025, 0.030), M["knight_leather"], loc=(b_p[0], b_p[1] - 0.005, b_p[2]), rot=(0, 42, 0), bevel_w=0.002)

    # Heavy Waist Belt with Forged Iron Buckle sitting outside surcoat
    add_grid_cloth(torso_piv, "KnightWaistBelt", 32, 4, lambda u, v: (math.cos(u * math.tau) * 0.228, -math.sin(u * math.tau) * 0.168, 0.115 + v * 0.058), M["knight_leather"], closed_u=True)
    add_box(torso_piv, "WaistForgedBuckle", (0.074, 0.024, 0.078), M["knight_iron"], loc=(0.0, -0.174, 0.144), bevel_w=0.005)
    add_box(torso_piv, "WaistBuckleTongue", (0.042, 0.028, 0.012), M["knight_gold"], loc=(0.012, -0.178, 0.144), bevel_w=0.002)

    # Layered Gothic Steel Pauldrons (3 articulated lames + upright Haute-Piece Sword-Breaker Neck Guards)
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        for li in range(3):
            add_sphere(
                torso_piv, f"GothicPauldronLame_{s_ch}_{li}", 0.088 - li * 0.006, M["knight_steel"],
                scale_xyz=(1.18, 1.05, 0.62),
                loc=(sx * (0.252 + li * 0.024), -0.008, 0.505 - li * 0.042),
                rot=(0, sx * (18.0 + li * 12.0), 0), segs=18, rings=12
            )
            add_sphere(
                torso_piv, f"PauldronGoldRivet_{s_ch}_{li}", 0.009, M["knight_gold"],
                loc=(sx * (0.265 + li * 0.024), -0.075, 0.505 - li * 0.042), segs=10, rings=8
            )
        add_box(
            torso_piv, f"PauldronHauteGuard_{s_ch}", (0.014, 0.115, 0.078), M["knight_steel"],
            loc=(sx * 0.205, -0.008, 0.558), rot=(0, -sx * 12.0, 0), bevel_w=0.003
        )

    # Heavy Burgundy & Maille Back Mantle
    def knight_cloak_eval(u, v):
        un = (u - 0.5) * 2.0
        w = 0.28 + 0.11 * (v ** 0.8)
        px = un * w
        pz = 0.52 - v * 0.52
        fold = 0.018 * math.sin(un * math.pi * 3.0 + v * 2.2) * (0.25 + 0.75 * v)
        py = 0.105 + 0.072 * math.sin(v * math.pi * 0.65) + fold
        return (px, py, pz)

    add_grid_cloth(torso_piv, "KnightBackMantle", 26, 16, knight_cloak_eval, M["knight_burgundy"], closed_u=False)

    # --- B. HEAD: Knight Head + Mustache/Beard + Aventail Chainmail Coif + Fluted Gothic Sallet Helm with Raised Visor ---
    build_sculpted_head_and_eyes(
        head_piv, M["skin_stredovek"], M["lip_warm"], M["hair_iron"], M["socket_dark"],
        M["sclera"], M["eye_stredovek"], M["pupil_dark"],
        jaw_width=1.05, cheek_prominence=1.05, brow_fierce=1.28, nose_aquiline=1.08
    )

    # Rugged Knight Mustache & Trimmed Chin Beard
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        add_tube(head_piv, f"KnightMustache_{s_ch}", [
            (0.0, -0.106, 0.052), (sx * 0.022, -0.102, 0.048), (sx * 0.042, -0.088, 0.036)
        ], [0.008, 0.009, 0.0045], M["hair_iron"], segs=8)
    add_sphere(head_piv, "KnightChinBeard", 0.036, M["hair_iron"], scale_xyz=(1.1, 0.85, 0.95), loc=(0.0, -0.082, 0.006), segs=14, rings=10)

    # Full Flared Aventail Chainmail Coif Mantle wrapping around lower jaw, chin/throat & shoulders with Concentric Maille Ring Ridges
    def aventail_coif_eval(u, v):
        ang = u * math.tau
        front_factor = max(0.0, -math.sin(ang))
        z_top = 0.105 - 0.118 * (front_factor ** 1.6)
        z_bot = -0.068 - 0.022 * front_factor
        z = z_top + (z_bot - z_top) * v
        r_x = 0.106 + v * 0.072
        r_y = 0.108 + v * 0.056
        mail_ripple = 0.0042 * math.sin(u * 36.0 * math.tau) + 0.0035 * math.sin(v * 14.0 * math.pi)
        return (math.cos(ang) * (r_x + mail_ripple), math.sin(ang) * (r_y + mail_ripple), z)

    add_grid_cloth(head_piv, "AventailChainmailCoif", 48, 14, aventail_coif_eval, M["knight_mail"], closed_u=True)
    for ti, vf in enumerate((0.35, 0.68, 1.0)):
        ring_pts = [aventail_coif_eval(ui / 36.0, vf) for ui in range(37)]
        add_tube(head_piv, f"AventailMailTier_{ti}", ring_pts, 0.0065 if ti < 2 else 0.0085,
                 M["knight_mail"] if ti < 2 else M["knight_gold"], segs=8, cap_ends=False)

    # Sculpted Fluted Gothic Sallet Knight Helm with Swept Lobster Tail & Raised Brow Ridge Visor
    def sallet_dome_eval(u, v):
        ang = u * math.tau
        z = 0.118 + v * 0.148
        r_base = 0.118 * (1.0 - 0.88 * (v ** 1.85))
        flute = 0.0040 * math.cos(ang * 10.0) * math.sin(v * math.pi)
        tail_flare = max(0.0, math.sin(ang)) * (1.0 - v) * 0.062
        px = math.cos(ang) * (r_base + flute)
        py = math.sin(ang) * (r_base + flute) + tail_flare
        if v < 0.25 and math.sin(ang) > 0.2:
            z -= (0.25 - v) * math.sin(ang) * 0.14
        return (px, py, z)

    add_grid_cloth(head_piv, "FlutedSalletDome", 40, 16, sallet_dome_eval, M["knight_steel"], closed_u=True)

    # Central Raised Gilded Comb Ridge over Crown
    comb_pts = [(0.0, -0.112, 0.155), (0.0, -0.045, 0.252), (0.0, 0.035, 0.268), (0.0, 0.125, 0.205), (0.0, 0.172, 0.105)]
    add_tube(head_piv, "SalletCentralComb", comb_pts, [0.010, 0.018, 0.020, 0.016, 0.010], M["knight_gold"], segs=10, scale_xy_fn=lambda i, n: (0.42, 1.35))

    # Hinged Raised Bellows Visor & Heavy Brass-Trimmed Brow Ridge above Eyes + Cheek-Side Helm Flanges
    visor_arch = [
        (-0.116, -0.005, 0.122),
        (-0.084, -0.098, 0.132),
        (0.0, -0.145, 0.128),
        (0.084, -0.098, 0.132),
        (0.116, -0.005, 0.122),
    ]
    add_tube(head_piv, "SalletRaisedVisorPlate", visor_arch, [0.020, 0.030, 0.034, 0.030, 0.020], M["knight_steel"], segs=10, scale_xy_fn=lambda i, n: (0.65, 1.35))
    add_tube(head_piv, "SalletVisorBrassRidge", visor_arch, [0.011, 0.014, 0.016, 0.014, 0.011], M["knight_gold"], segs=8, loc=(0.0, -0.006, -0.010))
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        add_cyl(head_piv, f"VisorHingePivot_{s_ch}", 0.018, 0.018, 0.016, M["knight_gold"], segs=12, loc=(sx * 0.118, -0.005, 0.122), rot=(0, 90, 0))
        add_tube(head_piv, f"SalletTempleGuard_{s_ch}", [
            (sx * 0.110, -0.025, 0.118), (sx * 0.104, -0.055, 0.068), (sx * 0.088, -0.072, 0.025)
        ], [0.024, 0.026, 0.016], M["knight_steel"], segs=8, scale_xy_fn=lambda i, n: (0.35, 1.3))

    # --- C. ARMS: Chainmail Sleeves + Steel Elbow Cops + Articulated Gothic Steel Gauntlets ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        arm_pts = [
            (0.0, 0.0, 0.0),
            (side * 0.025, -0.055, -0.105),
            (-side * 0.025, -0.145, -0.195),
            (-side * 0.072, -0.265, -0.205),
            (-side * 0.105, -0.365, -0.215),
        ]
        add_tube(arm_piv, f"ChainmailSleeve_{s_ch}", arm_pts, [0.062, 0.054, 0.048, 0.042, 0.036], M["knight_mail"], segs=16)

        add_sphere(arm_piv, f"SteelElbowCop_{s_ch}", 0.056, M["knight_steel"], scale_xyz=(0.95, 1.15, 0.85),
                   loc=(-side * 0.020, -0.140, -0.202), segs=14, rings=10)

        gaunt_pts = [
            (-side * 0.045, -0.195, -0.199),
            (-side * 0.072, -0.268, -0.206),
            (-side * 0.092, -0.322, -0.211),
            (-side * 0.106, -0.368, -0.215),
        ]
        add_tube(arm_piv, f"SteelGauntletCuff_{s_ch}", gaunt_pts, [0.054, 0.046, 0.043, 0.048], M["knight_steel"], segs=14)
        add_tube(arm_piv, f"GauntletGoldRim_{s_ch}", [gaunt_pts[0], gaunt_pts[1]], [0.056, 0.047], M["knight_gold"], segs=14)

        build_articulated_hand(arm_piv, side, M["knight_steel"], ring_mat=M["knight_gold"])

    return torso_piv


# =============================================================================
# 4. OPP_OBJAVY.GLB — AGE OF SAIL (CORSAIR / SEA NAVIGATOR)
# =============================================================================

def build_opp_objavy(M):
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_character_pivots(shoulder_x=0.264)

    # --- A. TORSO: High-Collared Navy-Teal Naval Longcoat + Brass Buttons & Epaulettes + Crossed Bandolier & Compass ---
    def naval_coat_rx_ry(v):
        if v < 0.28:
            t = v / 0.28
            rx = 0.228 - 0.025 * math.sin(t * math.pi * 0.5)
            ry = 0.150 - 0.015 * math.sin(t * math.pi * 0.5)
        elif v < 0.82:
            t = (v - 0.28) / 0.54
            rx = 0.203 + 0.082 * smoothstep(0.0, 1.0, t)
            ry = 0.135 + 0.034 * math.sin(t * math.pi * 0.65)
        else:
            t = (v - 0.82) / 0.18
            rx = 0.285 * (1.0 - t) + 0.088 * t
            ry = 0.155 * (1.0 - t) + 0.076 * t
        return rx, ry

    def naval_coat_eval(u, v):
        ang = u * math.tau
        z = v * 0.55
        rx, ry = naval_coat_rx_ry(v)
        return (math.cos(ang) * rx, -math.sin(ang) * ry, z)

    add_grid_cloth(torso_piv, "NavalLongcoatBody", 36, 18, naval_coat_eval, M["corsair_navy"], closed_u=True)

    # High Stiffened Standing Admiral Collar with Front V-Notch & Gold Braid Trim (leaving chin & braided beard visible!)
    def admiral_collar_eval(u, v):
        ang = -math.pi * 0.22 + u * (math.pi * 1.44)
        z = 0.515 + v * 0.092
        r = 0.098 + v * 0.016
        return (-math.cos(ang) * r * 1.06, math.sin(ang) * r * 0.96 - 0.006, z)

    add_grid_cloth(torso_piv, "AdmiralHighCollar", 28, 6, admiral_collar_eval, M["corsair_navy"], closed_u=False)
    collar_gold_pts = [admiral_collar_eval(ui / 24.0, 1.0) for ui in range(25)]
    add_tube(torso_piv, "AdmiralCollarGoldTrim", collar_gold_pts, 0.0065, M["corsair_brass"], segs=8)

    # Wide Folded Crimson-Wine Coat Revers (Lapels) + 10 Double-Breasted Brass Naval Buttons
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        revers_pts = [
            (sx * 0.082, -0.105, 0.545),
            (sx * 0.108, -0.162, 0.455),
            (sx * 0.092, -0.172, 0.335),
            (sx * 0.056, -0.162, 0.215),
        ]
        add_tube(torso_piv, f"CoatRevers_{s_ch}", revers_pts, [0.024, 0.036, 0.032, 0.022], M["corsair_revers"], segs=8, scale_xy_fn=lambda i, n: (1.35, 0.35))
        for bi in range(5):
            bz = 0.235 + bi * 0.062
            bx = sx * (0.058 + bi * 0.008)
            add_sphere(torso_piv, f"NavalBrassButton_{s_ch}_{bi}", 0.011, M["corsair_brass"], scale_xyz=(1.0, 0.55, 1.0), loc=(bx, -0.176, bz), segs=10, rings=8)

    # Ruffled Ivory Linen Jabot Cravat at Chest V-Throat
    for ji in range(5):
        jw = 0.038 + ji * 0.008
        add_box(torso_piv, f"JabotRuffle_{ji}", (jw * 1.8, 0.024, 0.028), M["corsair_linen"],
                loc=(0.0, -0.152 - ji * 0.003, 0.515 - ji * 0.028), bevel_w=0.005)

    # Brass & Gold-Fringed Naval Epaulettes on Both Shoulders
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        add_box(torso_piv, f"NavalEpauletteBoard_{s_ch}", (0.125, 0.096, 0.024), M["corsair_brass"],
                loc=(sx * 0.258, -0.005, 0.518), rot=(0, sx * 15.0, 0), bevel_w=0.006)
        add_torus_pts = [
            (sx * 0.312 + math.cos(a) * 0.025, math.sin(a) * 0.052, 0.502)
            for a in [i * math.tau / 16.0 for i in range(17)]
        ]
        add_tube(torso_piv, f"EpauletteCrescent_{s_ch}", add_torus_pts, 0.012, M["corsair_brass"], segs=8, cap_ends=False)
        for fi in range(7):
            fa = -0.85 + (fi / 6.0) * 1.70
            add_cyl(torso_piv, f"EpauletteFringe_{s_ch}_{fi}", 0.0055, 0.0045, 0.048, M["corsair_brass"], segs=8,
                    loc=(sx * 0.328, math.sin(fa) * 0.048, 0.472), rot=(0, -sx * 12.0, 0))

    # Outward-Curved Crossed Leather Bandolier Belts (zero clipping into chest/revers!) + Center Sculpted Brass Compass Medallion
    for sx_dir, b_idx in ((1.0, 1), (-1.0, 2)):
        b_pts = []
        for si in range(11):
            t = si / 10.0
            bx = sx_dir * (0.195 * (1.0 - t) + (-0.205) * t)
            bz = 0.525 * (1.0 - t) + 0.145 * t
            bv = bz / 0.55
            rx_c, ry_c = naval_coat_rx_ry(bv)
            ellipse_y = ry_c * math.sqrt(max(0.15, 1.0 - (bx / (rx_c + 0.04)) ** 2))
            by = -(ellipse_y + 0.026)
            b_pts.append((bx, by, bz))
        add_tube(torso_piv, f"CrossedBandolier_{b_idx}", b_pts, 0.023, M["corsair_leather"], segs=10, scale_xy_fn=lambda i, n: (1.45, 0.32))

    # Multi-layered Brass Compass Rose Medallion at Bandolier Crossing (0.0, -0.196, 0.335)
    add_cyl(torso_piv, "BrassCompassBezel", 0.052, 0.052, 0.018, M["corsair_brass"], segs=22, loc=(0.0, -0.196, 0.335), rot=(86, 0, 0))
    add_sphere(torso_piv, "CompassGlassDial", 0.038, M["corsair_compass"], scale_xyz=(1.0, 0.35, 1.0), loc=(0.0, -0.204, 0.335), segs=16, rings=10)
    add_box(torso_piv, "CompassStarNS", (0.010, 0.010, 0.072), M["corsair_brass"], loc=(0.0, -0.208, 0.335), bevel_w=0.001)
    add_box(torso_piv, "CompassStarEW", (0.072, 0.010, 0.010), M["corsair_brass"], loc=(0.0, -0.208, 0.335), bevel_w=0.001)

    # Wide Corsair Leather Waist Belt & Brass Frame Buckle
    add_grid_cloth(torso_piv, "CorsairWaistBelt", 32, 4, lambda u, v: (math.cos(u * math.tau) * 0.222, -math.sin(u * math.tau) * 0.148, 0.115 + v * 0.058), M["corsair_leather"], closed_u=True)
    add_box(torso_piv, "CorsairBeltBuckle", (0.068, 0.022, 0.072), M["corsair_brass"], loc=(0.0, -0.156, 0.144), bevel_w=0.005)

    # --- B. HEAD: Sea Captain Head + Braided Beard + Crimson Bandana + Weathered Upturned Tricorn Hat & Plume ---
    build_sculpted_head_and_eyes(
        head_piv, M["skin_objavy"], M["lip_warm"], M["hair_dark"], M["socket_dark"],
        M["sclera"], M["eye_objavy"], M["pupil_dark"],
        jaw_width=1.04, cheek_prominence=1.08, brow_fierce=1.22, nose_aquiline=1.18
    )

    # Sea-Captain Mustache, Full Jaw Beard & Twin Braided Beard Tails with Brass Beads
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        add_tube(head_piv, f"CorsairMustache_{s_ch}", [
            (0.0, -0.106, 0.054), (sx * 0.024, -0.102, 0.048), (sx * 0.050, -0.086, 0.034)
        ], [0.009, 0.010, 0.005], M["hair_dark"], segs=8)
        add_tube(head_piv, f"CorsairJawBeard_{s_ch}", [
            (sx * 0.075, -0.045, 0.045), (sx * 0.055, -0.078, 0.015), (sx * 0.022, -0.096, 0.002)
        ], [0.014, 0.018, 0.020], M["hair_dark"], segs=8)
        add_tube(head_piv, f"CorsairBeardBraid_{s_ch}", [
            (sx * 0.016, -0.092, 0.006), (sx * 0.020, -0.100, -0.030), (sx * 0.018, -0.106, -0.064)
        ], [0.016, 0.013, 0.008], M["hair_dark"], segs=8)
        add_cyl(head_piv, f"BeardBrassBead_{s_ch}", 0.011, 0.011, 0.008, M["corsair_brass"], segs=10,
                loc=(sx * 0.019, -0.102, -0.044))

    # Gold Hoop Earring on Left Ear
    ear_ring_pts = [(-0.104, math.cos(a) * 0.018, 0.064 + math.sin(a) * 0.018) for a in [i * math.tau / 14.0 for i in range(15)]]
    add_tube(head_piv, "CorsairGoldEarring", ear_ring_pts, 0.0042, M["corsair_brass"], segs=6, cap_ends=False)

    # Crimson Bandana Wrapped around Forehead beneath Tricorn Hat + Trailing Knot Tails
    add_lathe(head_piv, "ForeheadBandanaWrap", [
        (0.104, 0.132), (0.112, 0.144), (0.111, 0.168), (0.102, 0.174)
    ], M["corsair_bandana"], segs=26)
    add_tube(head_piv, "BandanaTail_1", [(-0.085, 0.065, 0.142), (-0.138, 0.108, 0.105), (-0.168, 0.128, 0.055)], [0.016, 0.014, 0.008], M["corsair_bandana"], segs=8)
    add_tube(head_piv, "BandanaTail_2", [(-0.092, 0.055, 0.135), (-0.148, 0.082, 0.085)], [0.014, 0.007], M["corsair_bandana"], segs=8)

    # Weathered Upturned 3-Cornered Tricorn Captain's Hat
    add_lathe(head_piv, "TricornCrown", [
        (0.110, 0.162), (0.116, 0.205), (0.100, 0.262), (0.018, 0.270)
    ], M["corsair_tricorn"], segs=26)

    def tricorn_brim_eval(u, v):
        ang = u * math.tau
        r_in = 0.106
        lobe = math.cos(3.0 * (ang + math.pi * 0.5))
        r_out = 0.228 + 0.084 * lobe
        r = r_in + (r_out - r_in) * v
        px = math.cos(ang) * r
        py = math.sin(ang) * r
        upturn = (v ** 1.30) * (0.046 + 0.068 * (1.0 - lobe) * 0.5)
        pz = 0.162 + upturn
        return (px, py, pz)

    add_grid_cloth(head_piv, "TricornUpturnedBrim", 54, 8, tricorn_brim_eval, M["corsair_tricorn"], closed_u=True)

    # Braided Brass Piping tracing the 3-Cornered Tricorn Brim & Brass Cockade Pin
    rim_pts = [tricorn_brim_eval(i / 54.0, 1.0) for i in range(55)]
    add_tube(head_piv, "TricornBrassEdgeTrim", rim_pts, 0.0085, M["corsair_brass"], segs=8, cap_ends=False)
    add_cyl(head_piv, "TricornCockadeRosette", 0.026, 0.026, 0.012, M["corsair_bandana"], segs=16, loc=(-0.108, -0.092, 0.215), rot=(65, 0, -40))
    add_sphere(head_piv, "TricornCockadeButton", 0.012, M["corsair_brass"], loc=(-0.112, -0.096, 0.215), segs=10, rings=8)

    # Sweeping Tattered Feather Plumes arching over the Tricorn Crown
    plume_main = [(-0.085, -0.065, 0.225), (-0.155, -0.010, 0.295), (-0.215, 0.065, 0.305), (-0.255, 0.145, 0.255)]
    plume_sec = [(0.075, -0.045, 0.225), (0.145, 0.015, 0.288), (0.205, 0.085, 0.275)]
    add_tube(head_piv, "TatteredPlumeCrimson", plume_main, [0.014, 0.028, 0.024, 0.009], M["corsair_bandana"], segs=10, scale_xy_fn=lambda i, n: (1.5, 0.45))
    add_tube(head_piv, "TatteredPlumeIvory", plume_sec, [0.012, 0.022, 0.008], M["corsair_linen"], segs=10, scale_xy_fn=lambda i, n: (1.45, 0.45))

    # --- C. ARMS: Naval Coat Sleeves + Folded Turnback Cuffs + Ruffled Shirt Cuffs + Weathered Leather Gloves ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        arm_pts = [
            (0.0, 0.0, 0.0),
            (side * 0.025, -0.055, -0.105),
            (-side * 0.025, -0.145, -0.195),
            (-side * 0.072, -0.265, -0.205),
            (-side * 0.095, -0.335, -0.212),
        ]
        add_tube(arm_piv, f"NavalCoatSleeve_{s_ch}", arm_pts, [0.065, 0.057, 0.051, 0.046, 0.044], M["corsair_navy"], segs=16)

        cuff_pts = [(-side * 0.068, -0.255, -0.204), (-side * 0.094, -0.332, -0.212)]
        add_tube(arm_piv, f"NavalTurnbackCuff_{s_ch}", cuff_pts, [0.054, 0.051], M["corsair_revers"], segs=16)
        add_sphere(arm_piv, f"CuffBrassBtn_{s_ch}", 0.009, M["corsair_brass"], loc=(-side * 0.082, -0.292, -0.162), segs=8, rings=6)

        ruffle_pts = [(-side * 0.092, -0.328, -0.211), (-side * 0.108, -0.372, -0.216)]
        add_tube(arm_piv, f"RuffledShirtCuff_{s_ch}", ruffle_pts, [0.043, 0.048], M["corsair_linen"], segs=14)

        build_articulated_hand(arm_piv, side, M["corsair_glove"], ring_mat=M["corsair_brass"])

    return torso_piv


# =============================================================================
# 5. OPP_PROHIBICIA.GLB — 1930s PROHIBITION (SYNDICATE ENFORCER)
# =============================================================================

def build_opp_prohibicia(M):
    torso_piv, head_piv, arm_l_piv, arm_r_piv = create_character_pivots(shoulder_x=0.262)

    # --- A. TORSO: Crisp Double-Breasted Charcoal-Pinstripe Coat + Peaked Lapels + Upturned Trench Collar + Ivory Shirt & Ruby-Pinned Tie ---
    def pinstripe_coat_eval(u, v):
        ang = u * math.tau
        z = v * 0.55
        if v < 0.25:
            t = v / 0.25
            rx = 0.222 - 0.020 * math.sin(t * math.pi * 0.5)
            ry = 0.145 - 0.012 * math.sin(t * math.pi * 0.5)
        elif v < 0.84:
            t = (v - 0.25) / 0.59
            rx = 0.202 + 0.088 * smoothstep(0.0, 1.0, t)
            ry = 0.133 + 0.032 * math.sin(t * math.pi * 0.65)
        else:
            t = (v - 0.84) / 0.16
            rx = 0.290 * (1.0 - t) + 0.092 * t
            ry = 0.152 * (1.0 - t) + 0.080 * t
        return (math.cos(ang) * rx, -math.sin(ang) * ry, z)

    add_grid_cloth(torso_piv, "CharcoalSuitBody", 36, 18, pinstripe_coat_eval, M["noir_charcoal"], closed_u=True)

    # 3D Vertical Chalk-Pinstripe Threads across the Front & Back of the Double-Breasted Coat
    for pi in range(18):
        ang = (pi / 18.0) * math.tau
        v_max = 0.54 if (math.sin(ang) > 0.72 and abs(math.cos(ang)) < 0.34) else 0.84
        p_pts = []
        for vi in range(10):
            vf = 0.04 + (vi / 9.0) * (v_max - 0.04)
            bx, by, bz = pinstripe_coat_eval(pi / 18.0, vf)
            p_pts.append((bx * 1.015, by * 1.015, bz))
        add_tube(torso_piv, f"PinstripeThread_{pi}", p_pts, 0.0028, M["noir_pinstripe"], segs=6)

    # High Dramatic Upturned Trench/Overcoat Storm Collar framing Jaw & Neck
    def upturned_collar_eval(u, v):
        ang = -math.pi * 0.18 + u * (math.pi * 1.36)
        z = 0.505 + v * 0.125
        flare = 0.108 + v * 0.034
        return (-math.cos(ang) * flare * 1.12, math.sin(ang) * flare * 0.94 - 0.010, z)

    add_grid_cloth(torso_piv, "UpturnedTrenchCollar", 28, 8, upturned_collar_eval, M["noir_lapel"], closed_u=False)
    collar_rim = [upturned_collar_eval(ui / 24.0, 1.0) for ui in range(25)]
    add_tube(torso_piv, "TrenchCollarEdgePiping", collar_rim, 0.0055, M["noir_pinstripe"], segs=6)

    # Crisp Ivory Dress Shirt V-Front + Crimson Silk Necktie + Faceted Glowing Ruby Tie-Pin
    shirt_2d = [(-0.085, 0.55), (0.085, 0.55), (0.048, 0.36), (0.0, 0.24), (-0.048, 0.36)]
    add_extruded_poly(torso_piv, "IvoryDressShirt", shirt_2d, 0.035, M["noir_ivory"], axis="Y", loc=(0.0, -0.148, 0.0), bevel_w=0.004)
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        add_box(torso_piv, f"IvoryShirtCollar_{s_ch}", (0.048, 0.018, 0.042), M["noir_ivory"],
                loc=(sx * 0.038, -0.140, 0.532), rot=(14, sx * 22, -sx * 28), bevel_w=0.003)

    add_sphere(torso_piv, "SilkTieKnot", 0.022, M["noir_crimson"], scale_xyz=(1.05, 0.65, 0.95), loc=(0.0, -0.160, 0.515), segs=12, rings=8)
    tie_2d = [(-0.016, 0.505), (0.016, 0.505), (0.028, 0.315), (0.0, 0.255), (-0.028, 0.315)]
    add_extruded_poly(torso_piv, "CrimsonSilkTie", tie_2d, 0.016, M["noir_crimson"], axis="Y", loc=(0.0, -0.162, 0.0), bevel_w=0.003)
    add_box(torso_piv, "GoldTieClipBar", (0.044, 0.012, 0.008), M["egypt_gold"], loc=(0.0, -0.171, 0.405), bevel_w=0.002)
    add_sphere(torso_piv, "RubyTiePin", 0.011, M["noir_ruby"], scale_xyz=(0.9, 0.65, 1.25), loc=(0.0, -0.176, 0.405), segs=12, rings=8)

    # Broad Peaked Suit Lapels + 6 Double-Breasted Buttons + Crimson Pocket Square
    for sx, s_ch in ((-1.0, "L"), (1.0, "R")):
        lapel_2d = [
            (sx * 0.005, 0.23),
            (sx * 0.068, 0.35),
            (sx * 0.145, 0.495),
            (sx * 0.088, 0.485),
            (sx * 0.082, 0.535),
            (sx * 0.045, 0.425),
        ]
        if sx < 0:
            lapel_2d = list(reversed(lapel_2d))
        add_extruded_poly(torso_piv, f"BroadPeakedLapel_{s_ch}", lapel_2d, 0.018, M["noir_lapel"], axis="Y", loc=(0.0, -0.164, 0.0), bevel_w=0.003)

        for bi in range(3):
            add_cyl(torso_piv, f"DoubleBreastedBtn_{s_ch}_{bi}", 0.012, 0.012, 0.008, M["noir_glove"], segs=14,
                    loc=(sx * 0.068, -0.170, 0.115 + bi * 0.072), rot=(86, 0, 0))

    add_box(torso_piv, "BreastPocketWelt", (0.062, 0.012, 0.014), M["noir_lapel"], loc=(0.118, -0.158, 0.375), rot=(0, -8, 0), bevel_w=0.002)
    pocket_sq_2d = [(0.095, 0.378), (0.142, 0.375), (0.135, 0.418), (0.116, 0.398), (0.102, 0.422)]
    add_extruded_poly(torso_piv, "CrimsonPocketSquare", pocket_sq_2d, 0.010, M["noir_crimson"], axis="Y", loc=(0.0, -0.160, 0.0), bevel_w=0.002)

    add_tube(torso_piv, "GoldWatchChain", [(0.0, -0.170, 0.215), (0.058, -0.174, 0.178), (0.115, -0.158, 0.205)], 0.0048, M["egypt_gold"], segs=8)

    # --- B. HEAD: Syndicate Enforcer Head + Smoldering Ember Cigar Stub + Sharp Tilted Gangster Fedora ---
    build_sculpted_head_and_eyes(
        head_piv, M["skin_prohibicia"], M["lip_warm"], M["hair_dark"], M["socket_dark"],
        M["sclera"], M["eye_prohibicia"], M["pupil_dark"],
        jaw_width=1.06, cheek_prominence=1.12, brow_fierce=1.28, nose_aquiline=1.10
    )

    add_sphere(head_piv, "SlickedBackHair", 0.102, M["hair_dark"], scale_xyz=(0.94, 0.98, 0.94), loc=(0.0, 0.014, 0.112), segs=18, rings=12)
    add_tube(head_piv, "EnforcerScar", [(-0.048, -0.096, 0.088), (-0.058, -0.090, 0.058), (-0.054, -0.084, 0.032)], 0.0034, M["scar_red"], segs=6)

    # Smoldering Ember Cigar Stub clenched at Right Mouth Corner
    cigar_pts = [(0.026, -0.104, 0.040), (0.054, -0.148, 0.030), (0.074, -0.184, 0.022)]
    add_tube(head_piv, "HavanaCigarBody", cigar_pts, [0.0088, 0.0102, 0.0100], M["noir_cigar"], segs=12)
    add_cyl(head_piv, "CigarGoldBand", 0.0108, 0.0108, 0.008, M["egypt_gold"], segs=12, loc=(0.042, -0.128, 0.034), rot=(75, 0, -28))
    add_cyl(head_piv, "CigarAshTip", 0.0100, 0.0096, 0.012, M["noir_ash"], segs=12, loc=(0.077, -0.190, 0.021), rot=(75, 0, -28))
    add_sphere(head_piv, "CigarGlowingEmber", 0.0102, M["noir_ember"], scale_xyz=(1.0, 0.85, 1.0), loc=(0.082, -0.197, 0.020), segs=12, rings=10)

    # Sharp Tilted Gangster Fedora with Pinched Crown, Snap Brim & Crimson Silk Hatband
    fedora_holder = make_pivot(head_piv, "FedoraTiltHolder", loc=(-0.006, -0.008, 0.008))
    fedora_holder.rotation_euler = Euler((math.radians(-8.0), math.radians(-6.0), math.radians(3.0)))

    def fedora_crown_eval(u, v):
        ang = u * math.tau
        rx = 0.114 * (1.0 - 0.18 * v)
        ry = 0.128 * (1.0 - 0.16 * v)
        px = math.cos(ang) * rx
        py = math.sin(ang) * ry
        pz = 0.165 + v * 0.118
        if v > 0.55 and math.sin(ang) < -0.15:
            pinch = math.sin(((v - 0.55) / 0.45) * math.pi * 0.5) * (-math.sin(ang)) * abs(math.cos(ang))
            px *= 1.0 - 0.42 * pinch
        if v > 0.85:
            crease = ((v - 0.85) / 0.15) * (1.0 - min(1.0, (abs(px) / 0.048) ** 2))
            pz -= 0.022 * crease
        return (px, py, pz)

    def fedora_brim_eval(u, v):
        ang = u * math.tau
        r_in = 0.110
        r_out = 0.228
        r = r_in + (r_out - r_in) * v
        px = math.cos(ang) * (r * 0.94)
        py = math.sin(ang) * (r * 1.05)
        front_dip = -0.036 * (max(0.0, -math.sin(ang)) ** 1.3)
        back_curl = 0.024 * (max(0.0, math.sin(ang)) ** 1.2)
        side_curl = 0.014 * (abs(math.cos(ang)) ** 1.5) * (v ** 1.8)
        pz = 0.166 + (v ** 1.15) * (front_dip + back_curl) + side_curl
        return (px, py, pz)

    add_grid_cloth(fedora_holder, "FedoraPinchedCrown", 36, 14, fedora_crown_eval, M["noir_fedora"], closed_u=True)
    add_grid_cloth(fedora_holder, "FedoraSnapBrim", 44, 8, fedora_brim_eval, M["noir_fedora"], closed_u=True)
    fedora_rim = [fedora_brim_eval(ui / 44.0, 1.0) for ui in range(45)]
    add_tube(fedora_holder, "FedoraBrimBinding", fedora_rim, 0.0045, M["noir_lapel"], segs=6, cap_ends=False)

    def hatband_eval(u, v):
        ang = u * math.tau
        t = v * 0.28
        rx = 0.117 * (1.0 - 0.18 * t)
        ry = 0.131 * (1.0 - 0.16 * t)
        return (math.cos(ang) * rx, math.sin(ang) * ry, 0.167 + v * 0.034)

    add_grid_cloth(fedora_holder, "CrimsonSilkHatband", 36, 4, hatband_eval, M["noir_crimson"], closed_u=True)
    add_box(fedora_holder, "HatbandSilkBowL", (0.012, 0.026, 0.024), M["noir_crimson"], loc=(-0.118, -0.018, 0.184), rot=(12, 0, 8), bevel_w=0.003)
    add_box(fedora_holder, "HatbandSilkBowR", (0.012, 0.026, 0.024), M["noir_crimson"], loc=(-0.118, 0.014, 0.184), rot=(-12, 0, -8), bevel_w=0.003)
    add_box(fedora_holder, "HatbandGoldKnot", (0.014, 0.012, 0.026), M["egypt_gold"], loc=(-0.120, -0.002, 0.184), bevel_w=0.002)

    # --- C. ARMS: Charcoal-Pinstripe Coat Sleeves + Ivory French Cuffs + Sleek Black Leather Gloves ---
    for side, arm_piv, s_ch in ((-1.0, arm_l_piv, "L"), (1.0, arm_r_piv, "R")):
        arm_pts = [
            (0.0, 0.0, 0.0),
            (side * 0.025, -0.055, -0.105),
            (-side * 0.025, -0.145, -0.195),
            (-side * 0.072, -0.265, -0.205),
            (-side * 0.098, -0.342, -0.213),
        ]
        add_tube(arm_piv, f"PinstripeCoatSleeve_{s_ch}", arm_pts, [0.064, 0.056, 0.050, 0.045, 0.041], M["noir_charcoal"], segs=16)

        cuff_pts = [(-side * 0.094, -0.334, -0.212), (-side * 0.108, -0.372, -0.216)]
        add_tube(arm_piv, f"IvoryFrenchCuff_{s_ch}", cuff_pts, [0.040, 0.038], M["noir_ivory"], segs=14)
        add_sphere(arm_piv, f"GoldCufflink_{s_ch}", 0.0075, M["egypt_gold"], loc=(-side * 0.102, -0.354, -0.176), segs=8, rings=6)

        build_articulated_hand(arm_piv, side, M["noir_glove"], ring_mat=M["egypt_gold"])

    return torso_piv


# =============================================================================
# EXPORT & 5-CHARACTER STUDIO CONTACT SHEET RENDER
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
    print(f"[ERA_OPPONENT_EXPORTED] {filepath.name} ({sz_kb:.1f} KB)")


def render_contact_sheet(builders: list):
    scene = reset_scene()
    M = get_mats()
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 920
    scene.render.film_transparent = False

    scene.world = bpy.data.worlds.new("TavernPreviewWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.018, 0.012, 0.010, 1.0)

    # Dark Carved Oak Tavern Duel Table & Warm Backdrop
    oak_mat = make_mat("PreviewOak", (0.048, 0.022, 0.010), roughness=0.55)
    felt_mat = make_mat("PreviewFelt", (0.025, 0.012, 0.009), roughness=0.78)
    add_box(None, "PreviewTableTop", (5.4, 1.35, 0.08), oak_mat, loc=(0.0, -0.45, -0.02), bevel_w=0.01)
    add_box(None, "PreviewTableFelt", (5.1, 1.02, 0.02), felt_mat, loc=(0.0, -0.45, 0.025), bevel_w=0.005)

    # Line up all 5 Era Opponents facing the camera (-Y) with comfortable spacing so all 5 fit with outer margins!
    spacing = 0.72
    for idx, (_fname, build_fn) in enumerate(builders):
        x_pos = (idx - 2.0) * spacing
        root = build_fn(M)
        root.location = (x_pos, 0.0, 0.0)

    # Studio Camera framing ALL 5 busts head-to-hands with margin on both left & right!
    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 28.0
    cam_o = bpy.data.objects.new("PreviewCam", cam_d)
    cam_o.location = (0.0, -3.05, 0.68)
    cam_o.rotation_euler = (Vector((0.0, 0.0, 0.36)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    # Warm Tavern Candlelight Key + Rim + Subtle Cool Fill Lights
    l_key = bpy.data.lights.new("WarmKey", "AREA")
    l_key.energy = 240.0
    l_key.size = 3.2
    l_key.color = (1.0, 0.84, 0.62)
    o_key = bpy.data.objects.new("WarmKey", l_key)
    o_key.location = (-1.6, -2.2, 1.95)
    o_key.rotation_euler = (Vector((0.0, 0.0, 0.36)) - o_key.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_key)

    l_fill = bpy.data.lights.new("CoolFill", "AREA")
    l_fill.energy = 85.0
    l_fill.size = 3.6
    l_fill.color = (0.78, 0.86, 1.0)
    o_fill = bpy.data.objects.new("CoolFill", l_fill)
    o_fill.location = (1.9, -2.1, 1.15)
    o_fill.rotation_euler = (Vector((0.0, 0.0, 0.35)) - o_fill.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_fill)

    l_rim = bpy.data.lights.new("BackRim", "AREA")
    l_rim.energy = 210.0
    l_rim.size = 4.5
    l_rim.color = (1.0, 0.72, 0.40)
    o_rim = bpy.data.objects.new("BackRim", l_rim)
    o_rim.location = (0.0, 1.55, 1.75)
    o_rim.rotation_euler = (Vector((0.0, 0.0, 0.40)) - o_rim.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_rim)

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    print(f"[ERA_OPPONENTS_PREVIEW_RENDERED] {PREVIEW_PATH}")


def main():
    builders = [
        ("opp_antika.glb",     build_opp_antika),
        ("opp_rim.glb",        build_opp_rim),
        ("opp_stredovek.glb",  build_opp_stredovek),
        ("opp_objavy.glb",     build_opp_objavy),
        ("opp_prohibicia.glb", build_opp_prohibicia),
    ]
    for fname, build_fn in builders:
        reset_scene()
        M = get_mats()
        root = build_fn(M)
        export_character_glb(root, OUT_DIR / fname)

    render_contact_sheet(builders)


if __name__ == "__main__":
    main()
