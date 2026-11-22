"""
Blender 5.3 headless 3D Animated Hearts generator for LIALO Heartbeat HP System (Task #4):
  1. heart_standard.glb:
     - Richly sculpted stylized-anatomical heraldic 3D heart (lush crimson-ruby dual chamber lobes,
       deep interventricular sulcus groove, sculpted muscular contours).
     - Recessed glowing fissure veins in a dedicated named mesh node 'CrackVeins' (projected via
       closest_point_on_mesh onto the subdivided heart surface) so Godot can dynamically drive
       crack emission/glow as HP drops.
     - Gilded antique-brass aortic arch, pulmonary vessels, heraldic filigree straps & rivets ('ArterialFiligree').
     - Skinned to HeartRig Armature with 2 NLA tracks @ 30fps:
       * 'Heartbeat' (frames 0..30 = 1.00s authentic two-pulse lub-dub contraction/expansion)
       * 'DamageHit' (frames 0..18 = 0.60s violent recoil shudder + inward crunch)
  2. heart_boss.glb:
     - Imposing gothic-royal Boss Heart (~1.4x larger silhouette): deeper dark-obsidian & blood-crimson
       sculpted heart chambers clasped in a thorny forged-iron & ancient-gold rib cage ('ThornyRibCage'),
       central blazing jewel/furnace core ('EmberCore'), glowing fissure network ('CrackVeins'),
       and gothic royal crown spikes atop the ventricles ('RoyalCrown').
     - Skinned to HeartRig Armature with 2 NLA tracks @ 30fps:
       * 'Heartbeat' (frames 0..36 = 1.20s heavy booming lub-dub + rib cage flare)
       * 'DamageHit' (frames 0..20 = 0.67s dramatic shatter-stagger + cage rattle)
  3. Renders a side-by-side EEVEE studio inspection sheet -> scratch/hearts_3d_preview.png

Run via:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_hearts_3d.py
"""
import math
import pathlib
import bpy
import bmesh
from bpy_extras import anim_utils
from mathutils import Vector, Euler

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_DIR = ROOT / "assets" / "models" / "ui"
OUT_STANDARD = OUT_DIR / "heart_standard.glb"
OUT_BOSS = OUT_DIR / "heart_boss.glb"
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a7664877-b33a-48d0-8658-be5de670b3ca\scratch\hearts_3d_preview.png"
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.fps = 30
    return scene


def make_mat(name: str, color: tuple, metallic: float = 0.0, roughness: float = 0.45,
             emission: tuple = (0.0, 0.0, 0.0), emit_str: float = 0.0):
    mat = bpy.data.materials.new(name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emit_str
    return mat


def get_materials():
    # Linear RGB tuned for LIALO warm dark-tavern candlelight PBR (avoiding pale blowouts)
    return {
        "ruby_flesh": make_mat(
            "HeartRubyMat", (0.32, 0.014, 0.022), metallic=0.10, roughness=0.28,
            emission=(0.16, 0.008, 0.012), emit_str=0.14
        ),
        "crack_veins": make_mat(
            "CrackVeinsMat", (0.42, 0.018, 0.010), metallic=0.05, roughness=0.35,
            emission=(0.90, 0.08, 0.015), emit_str=0.80
        ),
        "crack_veins_boss": make_mat(
            "BossCrackVeinsMat", (0.52, 0.025, 0.012), metallic=0.05, roughness=0.30,
            emission=(0.98, 0.11, 0.018), emit_str=1.15
        ),
        "brass": make_mat(
            "GildedBrassMat", (0.76, 0.49, 0.13), metallic=0.90, roughness=0.24
        ),
        "ancient_gold": make_mat(
            "AncientGoldMat", (0.86, 0.58, 0.13), metallic=0.93, roughness=0.21,
            emission=(0.22, 0.13, 0.02), emit_str=0.08
        ),
        "forged_iron": make_mat(
            "ForgedIronMat", (0.048, 0.050, 0.060), metallic=0.88, roughness=0.32
        ),
        "boss_obsidian": make_mat(
            "BossObsidianHeartMat", (0.14, 0.011, 0.018), metallic=0.25, roughness=0.26,
            emission=(0.20, 0.010, 0.016), emit_str=0.18
        ),
        "ember_core": make_mat(
            "EmberCoreMat", (0.58, 0.03, 0.018), metallic=0.10, roughness=0.18,
            emission=(0.95, 0.09, 0.02), emit_str=1.25
        ),
        "ember_nucleus": make_mat(
            "EmberNucleusMat", (0.95, 0.28, 0.04), metallic=0.05, roughness=0.15,
            emission=(1.0, 0.34, 0.05), emit_str=1.80
        ),
        "crown_gem": make_mat(
            "CrownRubyGemMat", (0.64, 0.018, 0.035), metallic=0.12, roughness=0.14,
            emission=(0.88, 0.04, 0.07), emit_str=0.95
        ),
    }


def _create_mesh_obj(name: str, bm: bmesh.types.BMesh, materials: list, subsurf: int = 0):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    for m in materials:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if subsurf > 0:
        mod = obj.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)
    return obj


def _project_onto_surface(surface_obj, pt: Vector, offset: float = 0.0) -> Vector:
    ok, loc, norm, _ = surface_obj.closest_point_on_mesh(pt)
    if ok:
        # Ensure normal points outward from heart center
        if norm.dot(Vector((loc.x, loc.y, loc.z * 0.4))) < 0.0:
            norm = -norm
        return loc + norm * offset
    return pt


def _add_tube_to_bm(bm: bmesh.types.BMesh, pts: list, rads: list, segs: int = 12,
                    mat_idx: int = 0, cap_ends: bool = True):
    rings = []
    for idx, (pt, rad) in enumerate(zip(pts, rads)):
        p = Vector(pt)
        if idx == 0:
            t = (Vector(pts[1]) - p).normalized()
        elif idx == len(pts) - 1:
            t = (p - Vector(pts[idx - 1])).normalized()
        else:
            t = (Vector(pts[idx + 1]) - Vector(pts[idx - 1])).normalized()
        if t.length < 1e-6:
            t = Vector((0, 0, 1))
        up = Vector((0, 1, 0)) if abs(t.y) < 0.92 else Vector((1, 0, 0))
        side = t.cross(up).normalized()
        binorm = side.cross(t).normalized()
        ring = []
        for s in range(segs):
            a = (s / segs) * math.tau
            offset = side * (math.cos(a) * rad) + binorm * (math.sin(a) * rad)
            ring.append(bm.verts.new(p + offset))
        rings.append(ring)

    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segs):
            sn = (s + 1) % segs
            f = bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
            f.material_index = mat_idx
            f.smooth = True

    if cap_ends and len(rings) >= 2:
        c0 = bm.verts.new(Vector(pts[0]))
        ce = bm.verts.new(Vector(pts[-1]))
        for s in range(segs):
            sn = (s + 1) % segs
            f0 = bm.faces.new((c0, rings[0][sn], rings[0][s]))
            f0.material_index = mat_idx
            fe = bm.faces.new((ce, rings[-1][s], rings[-1][sn]))
            fe.material_index = mat_idx


def _eval_heart_surface(u_val: float, angle: float, scale_mult: float = 1.0, is_boss: bool = False):
    ca = math.cos(angle)
    sa = math.sin(angle)
    side_abs = abs(ca)
    front_back = abs(sa)

    profile = math.sin(u_val * math.pi * 0.86) ** 0.78
    lobe_lift = (u_val ** 1.75) * (0.20 * (side_abs ** 1.35) - 0.11 * (front_back ** 1.8))
    asym_z = 0.020 * (-ca) * (u_val ** 1.3)
    z = (-0.50 + u_val * 0.82 + lobe_lift + asym_z) * scale_mult

    rx = (0.03 + 0.45 * profile) * (1.0 + 0.14 * (u_val ** 1.4) * (side_abs ** 0.8))
    ry = (0.025 + 0.33 * profile) * (1.0 - 0.06 * (u_val ** 1.6))

    sulcus_shift = 0.10 * (u_val - 0.45)
    sulcus_dist_front = abs(ca - sulcus_shift)
    sulcus_dist_back = abs(ca + sulcus_shift * 0.7)
    groove_f = math.exp(-((sulcus_dist_front / 0.24) ** 2)) * max(0.0, -sa) * (u_val ** 0.65)
    groove_b = math.exp(-((sulcus_dist_back / 0.28) ** 2)) * max(0.0, sa) * (u_val ** 0.65)
    cleft_top = math.exp(-((abs(ca) / 0.32) ** 2)) * (max(0.0, u_val - 0.62) / 0.38) ** 1.5
    groove_total = min(0.45, 0.22 * groove_f + 0.16 * groove_b + 0.26 * cleft_top)

    if is_boss:
        ridge_bump = 0.018 * math.sin(u_val * math.pi * 7.0) * (side_abs ** 0.7) * math.sin(u_val * math.pi)
    else:
        ridge_bump = 0.007 * math.sin(u_val * math.pi * 5.0) * (side_abs ** 0.8) * math.sin(u_val * math.pi)

    rad_scale = (1.0 - groove_total) + ridge_bump
    x = ca * rx * rad_scale * scale_mult
    y = sa * ry * rad_scale * scale_mult

    twist = 0.08 * (1.0 - u_val) * math.sin(u_val * math.pi)
    xt = x * math.cos(twist) - y * math.sin(twist)
    yt = x * math.sin(twist) + y * math.cos(twist)
    return Vector((xt, yt, z)), groove_total


def build_heart_chambers(name: str, mats: list, scale_mult: float = 1.0, is_boss: bool = False):
    bm = bmesh.new()
    u_steps = 32
    a_steps = 52
    rings = []

    for ui in range(1, u_steps):
        u_val = ui / float(u_steps)
        ring = []
        for ai in range(a_steps):
            ang = (ai / float(a_steps)) * math.tau
            pt, _ = _eval_heart_surface(u_val, ang, scale_mult=scale_mult, is_boss=is_boss)
            ring.append(bm.verts.new(pt))
        rings.append(ring)

    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(a_steps):
            sn = (s + 1) % a_steps
            f = bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
            f.material_index = 0

    v_bot = bm.verts.new(Vector((0.0, 0.0, -0.515 * scale_mult)))
    for s in range(a_steps):
        sn = (s + 1) % a_steps
        f = bm.faces.new((v_bot, rings[0][sn], rings[0][s]))
        f.material_index = 0

    top_ring = rings[-1]
    v_top_l = bm.verts.new(Vector((-0.23 * scale_mult, 0.0, 0.37 * scale_mult)))
    v_top_c = bm.verts.new(Vector((0.0, 0.0, 0.25 * scale_mult)))
    v_top_r = bm.verts.new(Vector((0.23 * scale_mult, 0.0, 0.38 * scale_mult)))
    for s in range(a_steps):
        sn = (s + 1) % a_steps
        ang = ((s + 0.5) / float(a_steps)) * math.tau
        ca = math.cos(ang)
        if ca > 0.32:
            hub = v_top_r
        elif ca < -0.32:
            hub = v_top_l
        else:
            hub = v_top_c
        f = bm.faces.new((hub, top_ring[s], top_ring[sn]))
        f.material_index = 0

    return _create_mesh_obj(name, bm, mats, subsurf=1)


def build_crack_veins(name: str, surface_obj, vein_mat, scale_mult: float = 1.0, is_boss: bool = False):
    """
    Builds a sharp, organic lightning-like network of recessed glowing fissure veins ('CrackVeins')
    projected directly onto the subdivided HeartChambers mesh surface via closest_point_on_mesh.
    """
    bm = bmesh.new()
    base_r = (0.0082 if not is_boss else 0.0115) * scale_mult

    vein_paths_ua = [
        # Main front interventricular fissure (from upper cleft down to apex)
        [(0.88, 1.50 * math.pi), (0.74, 1.52 * math.pi), (0.58, 1.49 * math.pi),
         (0.42, 1.51 * math.pi), (0.26, 1.49 * math.pi), (0.12, 1.50 * math.pi)],
        # Front-left chamber branching fissure
        [(0.72, 1.51 * math.pi), (0.67, 1.37 * math.pi), (0.59, 1.23 * math.pi),
         (0.49, 1.14 * math.pi), (0.37, 1.19 * math.pi)],
        # Front-left upper fork
        [(0.66, 1.34 * math.pi), (0.76, 1.20 * math.pi), (0.85, 1.10 * math.pi)],
        # Front-right chamber branching fissure
        [(0.63, 1.50 * math.pi), (0.57, 1.65 * math.pi), (0.49, 1.79 * math.pi),
         (0.39, 1.86 * math.pi), (0.27, 1.77 * math.pi)],
        # Front-right upper fork
        [(0.75, 1.52 * math.pi), (0.74, 1.70 * math.pi), (0.83, 1.84 * math.pi)],
        # Lower front fork
        [(0.34, 1.50 * math.pi), (0.27, 1.35 * math.pi), (0.18, 1.25 * math.pi)],
        # Main back dorsal fissure
        [(0.86, 0.50 * math.pi), (0.68, 0.48 * math.pi), (0.50, 0.52 * math.pi),
         (0.30, 0.49 * math.pi), (0.14, 0.50 * math.pi)],
        # Back-left & back-right branches
        [(0.65, 0.49 * math.pi), (0.57, 0.67 * math.pi), (0.45, 0.80 * math.pi)],
        [(0.59, 0.51 * math.pi), (0.51, 0.34 * math.pi), (0.39, 0.21 * math.pi)],
    ]

    if is_boss:
        vein_paths_ua.extend([
            [(0.53, 1.50 * math.pi), (0.54, 1.32 * math.pi), (0.56, 1.10 * math.pi), (0.52, 0.92 * math.pi)],
            [(0.53, 1.50 * math.pi), (0.54, 1.68 * math.pi), (0.56, 1.90 * math.pi), (0.52, 2.08 * math.pi)],
            [(0.40, 1.50 * math.pi), (0.33, 1.67 * math.pi), (0.22, 1.82 * math.pi)],
            [(0.78, 1.36 * math.pi), (0.84, 1.26 * math.pi), (0.90, 1.18 * math.pi)],
            [(0.78, 1.64 * math.pi), (0.84, 1.74 * math.pi), (0.90, 1.82 * math.pi)],
        ])

    for path in vein_paths_ua:
        dense_pts = []
        dense_rads = []
        total_segs = (len(path) - 1) * 6
        for step in range(total_segs + 1):
            t_all = step / float(total_segs)
            seg_f = t_all * (len(path) - 1)
            idx = min(len(path) - 2, int(seg_f))
            frac = seg_f - idx
            u0, a0 = path[idx]
            u1, a1 = path[idx + 1]
            u_cur = u0 + (u1 - u0) * frac
            a_cur = a0 + (a1 - a0) * frac
            zig = 0.020 * math.sin(step * 2.9 + u0 * 13.0) * math.sin(t_all * math.pi)
            raw_pt, _ = _eval_heart_surface(u_cur, a_cur + zig, scale_mult=scale_mult, is_boss=is_boss)
            taper = (1.0 - 0.72 * (t_all ** 1.35)) * (0.65 + 0.35 * math.sin(max(0.1, t_all) * math.pi))
            rad = base_r * max(0.24, taper)
            # Half-recessed into the actual mesh surface!
            proj_pt = _project_onto_surface(surface_obj, raw_pt, offset=rad * 0.35)
            dense_pts.append(proj_pt)
            dense_rads.append(rad)
        _add_tube_to_bm(bm, dense_pts, dense_rads, segs=7, mat_idx=0, cap_ends=True)

    return _create_mesh_obj(name, bm, [vein_mat], subsurf=0)


def build_standard_filigree(surface_obj, mats: dict):
    """
    Builds the gilded brass aortic vessels, flared arterial collars, diagonal heraldic filigree bands
    (projected cleanly onto the chamber surface), central front heraldic diamond clasp, and lower apex finial.
    """
    bm = bmesh.new()

    # 1. Primary Ascending Aortic Arch
    aorta_pts = [
        Vector((-0.05, -0.01, 0.22)),
        Vector((-0.04, -0.01, 0.34)),
        Vector((-0.01, -0.01, 0.45)),
        Vector((0.04, 0.00, 0.54)),
        Vector((0.08, 0.01, 0.60)),
    ]
    aorta_rads = [0.092, 0.085, 0.078, 0.075, 0.084]
    _add_tube_to_bm(bm, aorta_pts, aorta_rads, segs=18, mat_idx=0, cap_ends=True)

    lip_pts = [Vector((0.065, 0.01, 0.57)), Vector((0.08, 0.01, 0.60)), Vector((0.09, 0.01, 0.618))]
    lip_rads = [0.085, 0.098, 0.068]
    _add_tube_to_bm(bm, lip_pts, lip_rads, segs=18, mat_idx=0, cap_ends=True)

    # 2. Secondary Pulmonary Arterial Trunk
    pulm_pts = [
        Vector((0.07, -0.04, 0.24)),
        Vector((0.01, -0.05, 0.34)),
        Vector((-0.08, -0.04, 0.43)),
        Vector((-0.15, -0.02, 0.50)),
    ]
    pulm_rads = [0.068, 0.064, 0.060, 0.072]
    _add_tube_to_bm(bm, pulm_pts, pulm_rads, segs=16, mat_idx=0, cap_ends=True)

    # 3. Superior Vena Cava Chimney
    svc_pts = [
        Vector((0.19, 0.03, 0.28)),
        Vector((0.22, 0.03, 0.39)),
        Vector((0.24, 0.03, 0.48)),
    ]
    svc_rads = [0.054, 0.050, 0.060]
    _add_tube_to_bm(bm, svc_pts, svc_rads, segs=14, mat_idx=0, cap_ends=True)

    # 4. Heraldic Gilded Filigree Bands projected cleanly outside the subsurfed surface
    for side_s in (-1.0, 1.0):
        band_pts = []
        band_rads = []
        for k in range(25):
            t = k / 24.0
            ang = 1.50 * math.pi + side_s * (0.04 + t * 0.94) * math.pi
            u_val = 0.68 - 0.14 * math.sin(t * math.pi)
            raw_pt, _ = _eval_heart_surface(u_val, ang, scale_mult=1.0, is_boss=False)
            band_pts.append(_project_onto_surface(surface_obj, raw_pt, offset=0.012))
            band_rads.append(0.017)
        _add_tube_to_bm(bm, band_pts, band_rads, segs=10, mat_idx=0, cap_ends=True)

    # Lower ventricular filigree V-cradle & bottom apex brass finial
    for side_s in (-1.0, 1.0):
        cradle_pts = []
        cradle_rads = []
        for k in range(19):
            t = k / 18.0
            ang = 1.50 * math.pi + side_s * (t * 0.56) * math.pi
            u_val = 0.16 + t * 0.32
            raw_pt, _ = _eval_heart_surface(u_val, ang, scale_mult=1.0, is_boss=False)
            cradle_pts.append(_project_onto_surface(surface_obj, raw_pt, offset=0.011))
            cradle_rads.append(0.015)
        _add_tube_to_bm(bm, cradle_pts, cradle_rads, segs=8, mat_idx=0, cap_ends=True)

    # Bottom Apex Gilded Finial Cone
    apex_pts = [
        Vector((0.0, 0.0, -0.45)),
        Vector((0.0, 0.0, -0.51)),
        Vector((0.0, 0.0, -0.58)),
    ]
    apex_rads = [0.074, 0.048, 0.010]
    _add_tube_to_bm(bm, apex_pts, apex_rads, segs=12, mat_idx=0, cap_ends=True)

    # Central Front Heraldic Diamond Bezel with Glowing Ruby Cabochon
    raw_bezel, _ = _eval_heart_surface(0.68, 1.50 * math.pi, scale_mult=1.0, is_boss=False)
    bezel_center = _project_onto_surface(surface_obj, raw_bezel, offset=0.018)
    diamond_pts = [
        bezel_center + Vector((0.0, -0.008, 0.072)),
        bezel_center + Vector((0.065, 0.010, 0.0)),
        bezel_center + Vector((0.0, -0.008, -0.072)),
        bezel_center + Vector((-0.065, 0.010, 0.0)),
        bezel_center + Vector((0.0, -0.008, 0.072)),
    ]
    _add_tube_to_bm(bm, diamond_pts, [0.018] * 5, segs=8, mat_idx=0, cap_ends=False)

    gem_res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.034)
    bmesh.ops.scale(bm, vec=(1.0, 0.55, 1.25), verts=gem_res["verts"])
    bmesh.ops.translate(bm, vec=bezel_center + Vector((0.0, -0.014, 0.0)), verts=gem_res["verts"])
    gem_set = set(gem_res["verts"])
    for f in bm.faces:
        if all(v in gem_set for v in f.verts):
            f.material_index = 1

    return _create_mesh_obj("ArterialFiligree", bm, [mats["brass"], mats["crown_gem"]], subsurf=0)


def build_boss_ember_core(surface_obj, mats: dict, scale_mult: float = 1.38):
    """
    Central blazing Ember Core nestled in the front ventricular cavity of heart_boss.glb,
    with a rich faceted crimson-fire outer crystal, golden inner nucleus, and forged-iron/gold bezel ring.
    """
    bm = bmesh.new()
    raw_core, _ = _eval_heart_surface(0.56, 1.50 * math.pi, scale_mult=scale_mult, is_boss=True)
    core_pos = _project_onto_surface(surface_obj, raw_core, offset=0.015 * scale_mult)

    # Forged-Iron Recessed Bezel Ring framing the core cavity
    bezel_steps = 16
    bezel_pts = []
    for k in range(bezel_steps + 1):
        ang = (k / float(bezel_steps)) * math.tau
        bezel_pts.append(
            core_pos + Vector((math.cos(ang) * 0.105 * scale_mult, 0.018 * scale_mult, math.sin(ang) * 0.128 * scale_mult))
        )
    _add_tube_to_bm(bm, bezel_pts, [0.022 * scale_mult] * len(bezel_pts), segs=8, mat_idx=2, cap_ends=False)

    # Faceted Crimson-Ember Crystal Core
    core_res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.090 * scale_mult)
    bmesh.ops.scale(bm, vec=(0.92, 0.52, 1.22), verts=core_res["verts"])
    bmesh.ops.translate(bm, vec=core_pos, verts=core_res["verts"])
    core_set = set(core_res["verts"])
    for f in bm.faces:
        if all(v in core_set for v in f.verts):
            f.material_index = 0

    # Inner Golden-Flame Nucleus Orb slightly proud at center
    nuc_res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.044 * scale_mult)
    bmesh.ops.scale(bm, vec=(0.85, 0.60, 1.15), verts=nuc_res["verts"])
    bmesh.ops.translate(bm, vec=core_pos + Vector((0.0, -0.026 * scale_mult, 0.0)), verts=nuc_res["verts"])
    nuc_set = set(nuc_res["verts"])
    for f in bm.faces:
        if all(v in nuc_set for v in f.verts):
            f.material_index = 3

    # 6 Ancient-Gold Claw Prongs clasping the EmberCore
    for k in range(6):
        ang = (k / 6.0) * math.tau + math.pi / 6.0
        ca, sa = math.cos(ang), math.sin(ang)
        p0 = core_pos + Vector((ca * 0.115 * scale_mult, 0.03 * scale_mult, sa * 0.138 * scale_mult))
        p1 = core_pos + Vector((ca * 0.102 * scale_mult, -0.032 * scale_mult, sa * 0.122 * scale_mult))
        p2 = core_pos + Vector((ca * 0.056 * scale_mult, -0.060 * scale_mult, sa * 0.068 * scale_mult))
        _add_tube_to_bm(bm, [p0, p1, p2], [0.022 * scale_mult, 0.017 * scale_mult, 0.006 * scale_mult],
                        segs=8, mat_idx=1, cap_ends=True)

    return _create_mesh_obj(
        "EmberCore",
        bm,
        [mats["ember_core"], mats["ancient_gold"], mats["forged_iron"], mats["ember_nucleus"]],
        subsurf=0
    )


def build_boss_thorny_rib_cage(surface_obj, mats: dict, scale_mult: float = 1.38):
    """
    Thorny forged-iron & ancient-gold crowned rib cage clasping the Boss Heart.
    """
    bm = bmesh.new()

    # Dorsal Spine Pillar on the back (+Y) + Lower Executioner Tail Spike
    spine_pts = [
        Vector((0.0, 0.34 * scale_mult, 0.34 * scale_mult)),
        Vector((0.0, 0.36 * scale_mult, 0.10 * scale_mult)),
        Vector((0.0, 0.33 * scale_mult, -0.18 * scale_mult)),
        Vector((0.0, 0.22 * scale_mult, -0.44 * scale_mult)),
        Vector((0.0, 0.04 * scale_mult, -0.56 * scale_mult)),
        Vector((0.0, -0.02 * scale_mult, -0.68 * scale_mult)),
    ]
    spine_rads = [r * scale_mult for r in (0.052, 0.058, 0.052, 0.045, 0.035, 0.008)]
    _add_tube_to_bm(bm, spine_pts, spine_rads, segs=12, mat_idx=0, cap_ends=True)

    # 4 Pairs of Heavy Forged-Iron Ribs projected smoothly outside the Left & Right chambers
    rib_u_levels = [0.75, 0.57, 0.39, 0.22]
    for r_idx, u_lvl in enumerate(rib_u_levels):
        for side_s in (-1.0, 1.0):
            rib_pts = []
            rib_rads = []
            steps = 20
            for k in range(steps + 1):
                t = k / float(steps)
                stop_span = 0.80 if r_idx in (1, 2) else 0.88
                ang = 0.50 * math.pi - side_s * (t * stop_span * math.pi)
                u_cur = u_lvl - 0.05 * math.sin(t * math.pi) - 0.03 * t
                raw_pt, _ = _eval_heart_surface(u_cur, ang, scale_mult=scale_mult, is_boss=True)
                rib_pts.append(_project_onto_surface(surface_obj, raw_pt, offset=0.022 * scale_mult))
                taper = 1.0 - 0.52 * (t ** 1.8)
                rib_rads.append((0.032 - r_idx * 0.0025) * scale_mult * taper)
            _add_tube_to_bm(bm, rib_pts, rib_rads, segs=10, mat_idx=0, cap_ends=True)

            # Ancient-Gold Joint Collars & Sharp Outward Iron/Gold Thorns along each Rib
            for thorn_t, mat_id, thorn_len in ((0.36, 0, 0.095), (0.64, 1, 0.115), (0.88, 1, 0.085)):
                idx_p = min(len(rib_pts) - 1, int(thorn_t * steps))
                base_p = rib_pts[idx_p]
                out_dir = Vector((base_p.x, base_p.y, base_p.z * 0.25 + 0.08)).normalized()
                c0 = base_p - Vector((0, 0, 0.014 * scale_mult))
                c1 = base_p + Vector((0, 0, 0.014 * scale_mult))
                _add_tube_to_bm(bm, [c0, c1], [0.036 * scale_mult, 0.036 * scale_mult], segs=10, mat_idx=1, cap_ends=True)
                mid_p = base_p + out_dir * (thorn_len * 0.55 * scale_mult) + Vector((0, 0, 0.022 * scale_mult))
                tip_p = base_p + out_dir * (thorn_len * scale_mult) + Vector((0, -0.018 * scale_mult, 0.050 * scale_mult))
                _add_tube_to_bm(
                    bm, [base_p, mid_p, tip_p],
                    [0.024 * scale_mult, 0.014 * scale_mult, 0.003 * scale_mult],
                    segs=8, mat_idx=mat_id, cap_ends=True
                )

    # Diagonal Gold Straps linking the Rib Arches along both flanks
    for side_s in (-1.0, 1.0):
        brace_pts = []
        for k in range(17):
            t = k / 16.0
            u_lvl = 0.76 - t * 0.55
            ang = 0.50 * math.pi - side_s * (0.55 * math.pi)
            raw_pt, _ = _eval_heart_surface(u_lvl, ang, scale_mult=scale_mult, is_boss=True)
            brace_pts.append(_project_onto_surface(surface_obj, raw_pt, offset=0.020 * scale_mult))
        _add_tube_to_bm(bm, brace_pts, [0.018 * scale_mult] * len(brace_pts), segs=8, mat_idx=1, cap_ends=True)

    return _create_mesh_obj("ThornyRibCage", bm, [mats["forged_iron"], mats["ancient_gold"]], subsurf=0)


def build_boss_royal_crown(mats: dict, scale_mult: float = 1.38):
    """
    Royal gothic crown spikes & armored aortic chimneys seated organically atop the ventricles of heart_boss.glb.
    """
    bm = bmesh.new()

    # 1. Triple Armored Gothic Aortic Chimneys rising from the central atrial saddle
    for x_off, y_off, h_top, rad in (
        (0.0, 0.02, 0.60, 0.088),
        (-0.15, -0.01, 0.53, 0.068),
        (0.15, -0.01, 0.54, 0.068),
    ):
        c_pts = [
            Vector((x_off * scale_mult, y_off * scale_mult, 0.22 * scale_mult)),
            Vector((x_off * 1.06 * scale_mult, y_off * scale_mult, 0.38 * scale_mult)),
            Vector((x_off * 1.12 * scale_mult, y_off * scale_mult, h_top * scale_mult)),
        ]
        c_rads = [rad * scale_mult, rad * 0.92 * scale_mult, rad * 1.05 * scale_mult]
        _add_tube_to_bm(bm, c_pts, c_rads, segs=14, mat_idx=1, cap_ends=True)

    # 2. Contoured Gothic Royal Crown Circlet with V-Brow Dip seating directly on the upper heart lobes
    def _crown_ring_pt(ang: float, z_offset: float):
        ca, sa = math.cos(ang), math.sin(ang)
        rx = 0.28 * scale_mult * (1.0 + 0.14 * abs(ca))
        ry = 0.20 * scale_mult
        z_saddle = (0.37 + 0.055 * (abs(ca) ** 1.3) - 0.055 * (abs(sa) ** 1.8) + z_offset) * scale_mult
        return Vector((ca * rx, sa * ry, z_saddle))

    circ_steps = 32
    for z_off, band_r_scale, mat_id in ((0.0, 0.026, 0), (0.045, 0.020, 1), (0.088, 0.025, 0)):
        ring_pts = [_crown_ring_pt((k / float(circ_steps)) * math.tau, z_off) for k in range(circ_steps + 1)]
        _add_tube_to_bm(bm, ring_pts, [band_r_scale * scale_mult] * len(ring_pts), segs=10, mat_idx=mat_id, cap_ends=False)

    # 3. 8 Sharp Gothic Royal Crown Spires + Ruby Cabochon Gems around the Contoured Circlet
    num_spires = 8
    for i in range(num_spires):
        ang = 1.50 * math.pi + (i / float(num_spires)) * math.tau
        ca, sa = math.cos(ang), math.sin(ang)
        base_pt = _crown_ring_pt(ang, 0.075)
        out_dir = Vector((ca, sa, 0.0)).normalized()

        is_hero = (i == 0)
        is_flank = (i in (1, num_spires - 1, num_spires // 2))
        spire_h = (0.28 if is_hero else (0.22 if is_flank else 0.16)) * scale_mult
        spire_w = (0.046 if is_hero else 0.036) * scale_mult

        mid_pt = base_pt + out_dir * (0.032 * scale_mult) + Vector((0, 0, spire_h * 0.52))
        tip_pt = base_pt + out_dir * (0.060 * scale_mult) + Vector((0, 0, spire_h))
        _add_tube_to_bm(
            bm, [base_pt, mid_pt, tip_pt],
            [spire_w, spire_w * 0.56, 0.005 * scale_mult],
            segs=6, mat_idx=0, cap_ends=True
        )

        if i in (0, 1, num_spires - 1):
            gem_pos = _crown_ring_pt(ang, 0.044) + out_dir * (0.026 * scale_mult)
            g_res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.024 * scale_mult)
            bmesh.ops.translate(bm, vec=gem_pos, verts=g_res["verts"])
            g_set = set(g_res["verts"])
            for f in bm.faces:
                if all(v in g_set for v in f.verts):
                    f.material_index = 2

    return _create_mesh_obj(
        "RoyalCrown", bm, [mats["ancient_gold"], mats["forged_iron"], mats["crown_gem"]], subsurf=0
    )


def create_heart_rig_and_bind(rig_name: str, part_objs: list, scale_mult: float = 1.0, is_boss: bool = False):
    arm_data = bpy.data.armatures.new(rig_name + "Data")
    arm_obj = bpy.data.objects.new(rig_name, arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    eb = arm_data.edit_bones
    bone_defs = [
        ("Root",           None,   (0.0, 0.0, 0.0),                        (0.0, 0.0, 0.20 * scale_mult)),
        ("UpperAtriaL",    "Root", (-0.12 * scale_mult, 0.0, 0.08 * scale_mult), (-0.34 * scale_mult, 0.0, 0.34 * scale_mult)),
        ("UpperAtriaR",    "Root", (0.12 * scale_mult, 0.0, 0.08 * scale_mult),  (0.34 * scale_mult, 0.0, 0.34 * scale_mult)),
        ("LowerVentricle", "Root", (0.0, 0.0, -0.04 * scale_mult),         (0.0, 0.0, -0.50 * scale_mult)),
        ("AortaCrown",     "Root", (0.0, 0.0, 0.24 * scale_mult),          (0.0, 0.0, 0.62 * scale_mult)),
    ]
    if is_boss:
        bone_defs.extend([
            ("CageL",    "Root", (-0.16 * scale_mult, 0.0, 0.0), (-0.48 * scale_mult, 0.0, 0.0)),
            ("CageR",    "Root", (0.16 * scale_mult, 0.0, 0.0),  (0.48 * scale_mult, 0.0, 0.0)),
            ("CoreBone", "Root", (0.0, -0.25 * scale_mult, 0.04 * scale_mult), (0.0, -0.45 * scale_mult, 0.04 * scale_mult)),
        ])

    created = {}
    for bname, pname, head, tail in bone_defs:
        b = eb.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if pname:
            b.parent = created[pname]
        b.align_roll(Vector((0.0, 1.0, 0.0)))
        created[bname] = b

    bpy.ops.object.mode_set(mode="OBJECT")

    def smooth_step(val, a, b):
        t = max(0.0, min(1.0, (val - a) / (b - a)))
        return t * t * (3.0 - 2.0 * t)

    def chamber_weights(p: Vector):
        zn = p.z / scale_mult
        xn = p.x / scale_mult
        if zn > 0.33:
            t_cr = smooth_step(zn, 0.33, 0.45)
            side_w = (1.0 - t_cr) * 0.5
            return {"AortaCrown": t_cr, "UpperAtriaL": side_w if xn < 0 else 0.1, "UpperAtriaR": side_w if xn >= 0 else 0.1}
        if zn < -0.06:
            t_lo = smooth_step(-zn, 0.06, 0.26)
            return {"LowerVentricle": t_lo, "Root": 1.0 - t_lo}
        t_lr = smooth_step(xn, -0.16, 0.16)
        return {"UpperAtriaL": (1.0 - t_lr) * 0.78, "UpperAtriaR": t_lr * 0.78, "Root": 0.22}

    for obj in part_objs:
        for bname, _, _, _ in bone_defs:
            if bname not in obj.vertex_groups:
                obj.vertex_groups.new(name=bname)
        for v in obj.data.vertices:
            wp = obj.matrix_world @ v.co
            if is_boss and obj.name == "EmberCore":
                w_dict = {"CoreBone": 0.85, "Root": 0.15}
            elif is_boss and obj.name == "ThornyRibCage":
                xn = wp.x / scale_mult
                t_lr = smooth_step(xn, -0.14, 0.14)
                w_dict = {"CageL": (1.0 - t_lr) * 0.82, "CageR": t_lr * 0.82, "Root": 0.18}
            elif is_boss and obj.name == "RoyalCrown":
                w_dict = {"AortaCrown": 0.88, "Root": 0.12}
            else:
                w_dict = chamber_weights(wp)
            tot = sum(max(0.0, val) for val in w_dict.values())
            if tot <= 1e-6:
                w_dict = {"Root": 1.0}
                tot = 1.0
            for bname, val in w_dict.items():
                if val > 1e-4:
                    obj.vertex_groups[bname].add([v.index], val / tot, "REPLACE")

        obj.parent = arm_obj
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm_obj

    return arm_obj


def _set_pose_keys(arm_obj, act, pose_table: dict):
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = act

    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    frames = sorted(pose_table.keys())
    for fr in frames:
        for pb in arm_obj.pose.bones:
            pb.location = (0.0, 0.0, 0.0)
            pb.rotation_euler = (0.0, 0.0, 0.0)
            pb.scale = (1.0, 1.0, 1.0)
        frame_pose = pose_table[fr]
        for bname, vals in frame_pose.items():
            if bname not in arm_obj.pose.bones:
                continue
            pb = arm_obj.pose.bones[bname]
            if "loc" in vals:
                pb.location = vals["loc"]
            if "rot" in vals:
                rx, ry, rz = vals["rot"]
                pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
            if "scale" in vals:
                pb.scale = vals["scale"]
            pb.keyframe_insert("location", frame=fr)
            pb.keyframe_insert("rotation_euler", frame=fr)
            pb.keyframe_insert("scale", frame=fr)

    slot = arm_obj.animation_data.action_slot
    cb = anim_utils.action_get_channelbag_for_slot(act, slot)
    if cb:
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"
    return slot


def author_standard_animations(arm_obj):
    rest = {
        "Root":           {"loc": (0.0, 0.0, 0.0), "rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "UpperAtriaL":    {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "UpperAtriaR":    {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "LowerVentricle": {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "AortaCrown":     {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
    }
    lub_peak = {
        "Root":           {"loc": (0.0, -0.024, 0.018), "rot": (-4, 2, -2), "scale": (1.13, 1.16, 1.10)},
        "UpperAtriaL":    {"rot": (0, -6, 5),  "scale": (1.15, 1.16, 1.12)},
        "UpperAtriaR":    {"rot": (0, 6, -5),  "scale": (1.15, 1.16, 1.12)},
        "LowerVentricle": {"rot": (6, 0, 4),   "scale": (1.08, 1.12, 1.06)},
        "AortaCrown":     {"rot": (-4, 0, 0),  "scale": (1.08, 1.08, 1.14)},
    }
    inter_dip = {
        "Root":           {"loc": (0.0, 0.012, -0.010), "rot": (2, -1, 1), "scale": (0.93, 0.92, 0.95)},
        "UpperAtriaL":    {"rot": (0, 4, -3),  "scale": (0.92, 0.92, 0.94)},
        "UpperAtriaR":    {"rot": (0, -4, 3),  "scale": (0.92, 0.92, 0.94)},
        "LowerVentricle": {"rot": (-4, 0, -3), "scale": (0.95, 0.94, 0.96)},
        "AortaCrown":     {"rot": (2, 0, 0),   "scale": (0.96, 0.96, 0.94)},
    }
    dub_peak = {
        "Root":           {"loc": (0.0, -0.018, 0.014), "rot": (-3, -2, 2), "scale": (1.09, 1.12, 1.08)},
        "UpperAtriaL":    {"rot": (0, -4, 3),  "scale": (1.08, 1.10, 1.06)},
        "UpperAtriaR":    {"rot": (0, 4, -3),  "scale": (1.08, 1.10, 1.06)},
        "LowerVentricle": {"rot": (5, 0, -4),  "scale": (1.14, 1.16, 1.11)},
        "AortaCrown":     {"rot": (-5, 0, 0),  "scale": (1.15, 1.15, 1.18)},
    }
    diastole = {
        "Root":           {"loc": (0.0, 0.005, -0.004), "rot": (1, 0, 0), "scale": (0.97, 0.97, 0.98)},
        "UpperAtriaL":    {"rot": (0, 1, -1), "scale": (0.98, 0.98, 0.98)},
        "UpperAtriaR":    {"rot": (0, -1, 1), "scale": (0.98, 0.98, 0.98)},
        "LowerVentricle": {"rot": (-1, 0, 0), "scale": (0.97, 0.97, 0.98)},
        "AortaCrown":     {"rot": (1, 0, 0),  "scale": (0.98, 0.98, 0.98)},
    }

    act_hb = bpy.data.actions.new("Heartbeat")
    act_hb.use_fake_user = True
    slot_hb = _set_pose_keys(arm_obj, act_hb, {
        0: rest,
        5: lub_peak,
        9: inter_dip,
        14: dub_peak,
        21: diastole,
        30: rest,
    })

    hit_crunch = {
        "Root":           {"loc": (0.045, 0.075, -0.038), "rot": (14, -12, 16), "scale": (0.81, 0.76, 0.84)},
        "UpperAtriaL":    {"rot": (8, 12, -10), "scale": (0.82, 0.80, 0.85)},
        "UpperAtriaR":    {"rot": (8, -12, 10), "scale": (0.82, 0.80, 0.85)},
        "LowerVentricle": {"rot": (-14, 8, -12), "scale": (0.80, 0.78, 0.86)},
        "AortaCrown":     {"rot": (16, -8, 10), "scale": (0.86, 0.86, 0.82)},
    }
    hit_rebound = {
        "Root":           {"loc": (-0.052, -0.040, 0.028), "rot": (-12, 14, -18), "scale": (1.18, 1.22, 1.14)},
        "UpperAtriaL":    {"rot": (-6, -10, 12), "scale": (1.16, 1.18, 1.12)},
        "UpperAtriaR":    {"rot": (-6, 10, -12), "scale": (1.16, 1.18, 1.12)},
        "LowerVentricle": {"rot": (12, -8, 10),  "scale": (1.16, 1.18, 1.12)},
        "AortaCrown":     {"rot": (-12, 10, -8), "scale": (1.14, 1.14, 1.18)},
    }
    hit_shudder = {
        "Root":           {"loc": (0.028, 0.022, -0.015), "rot": (7, -8, 10), "scale": (0.91, 0.89, 0.93)},
        "UpperAtriaL":    {"rot": (3, 5, -5), "scale": (0.92, 0.92, 0.94)},
        "UpperAtriaR":    {"rot": (3, -5, 5), "scale": (0.92, 0.92, 0.94)},
        "LowerVentricle": {"rot": (-6, 4, -6), "scale": (0.92, 0.90, 0.94)},
        "AortaCrown":     {"rot": (6, -4, 4), "scale": (0.94, 0.94, 0.92)},
    }
    hit_settle = {
        "Root":           {"loc": (-0.012, -0.008, 0.006), "rot": (-3, 4, -5), "scale": (1.04, 1.05, 1.02)},
        "UpperAtriaL":    {"rot": (0, -2, 2), "scale": (1.03, 1.03, 1.02)},
        "UpperAtriaR":    {"rot": (0, 2, -2), "scale": (1.03, 1.03, 1.02)},
        "LowerVentricle": {"rot": (2, 0, 2),  "scale": (1.03, 1.04, 1.02)},
        "AortaCrown":     {"rot": (-2, 0, 0), "scale": (1.02, 1.02, 1.04)},
    }

    act_dmg = bpy.data.actions.new("DamageHit")
    act_dmg.use_fake_user = True
    slot_dmg = _set_pose_keys(arm_obj, act_dmg, {
        0: rest,
        2: hit_crunch,
        6: hit_rebound,
        10: hit_shudder,
        14: hit_settle,
        18: rest,
    })

    arm_obj.animation_data.action = None
    for tr_name, act, slot, end_fr in (
        ("Heartbeat", act_hb, slot_hb, 30),
        ("DamageHit", act_dmg, slot_dmg, 18),
    ):
        tr = arm_obj.animation_data.nla_tracks.new()
        tr.name = tr_name
        strip = tr.strips.new(tr_name, 0, act)
        strip.action_frame_start = 0
        strip.action_frame_end = end_fr
        if hasattr(strip, "action_slot") and slot is not None:
            strip.action_slot = slot
        tr.mute = False

    return act_hb, act_dmg


def author_boss_animations(arm_obj):
    rest = {
        "Root":           {"loc": (0.0, 0.0, 0.0), "rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "UpperAtriaL":    {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "UpperAtriaR":    {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "LowerVentricle": {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "AortaCrown":     {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "CageL":          {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "CageR":          {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
        "CoreBone":       {"rot": (0, 0, 0), "scale": (1.0, 1.0, 1.0)},
    }
    lub_boom = {
        "Root":           {"loc": (0.0, -0.032, 0.024), "rot": (-5, 2, -2), "scale": (1.15, 1.18, 1.12)},
        "UpperAtriaL":    {"rot": (0, -8, 6),  "scale": (1.16, 1.18, 1.14)},
        "UpperAtriaR":    {"rot": (0, 8, -6),  "scale": (1.16, 1.18, 1.14)},
        "LowerVentricle": {"rot": (7, 0, 5),   "scale": (1.10, 1.14, 1.08)},
        "AortaCrown":     {"rot": (-5, 0, 0),  "scale": (1.10, 1.10, 1.16)},
        "CageL":          {"rot": (0, -9, 7),  "scale": (1.08, 1.10, 1.06)},
        "CageR":          {"rot": (0, 9, -7),  "scale": (1.08, 1.10, 1.06)},
        "CoreBone":       {"rot": (0, 0, 10),  "scale": (1.28, 1.32, 1.28)},
    }
    inter_clamp = {
        "Root":           {"loc": (0.0, 0.016, -0.014), "rot": (3, -1, 1), "scale": (0.92, 0.90, 0.94)},
        "UpperAtriaL":    {"rot": (0, 5, -4),  "scale": (0.91, 0.90, 0.93)},
        "UpperAtriaR":    {"rot": (0, -5, 4),  "scale": (0.91, 0.90, 0.93)},
        "LowerVentricle": {"rot": (-5, 0, -3), "scale": (0.94, 0.92, 0.95)},
        "AortaCrown":     {"rot": (3, 0, 0),   "scale": (0.95, 0.95, 0.93)},
        "CageL":          {"rot": (0, 6, -5),  "scale": (0.94, 0.93, 0.95)},
        "CageR":          {"rot": (0, -6, 5),  "scale": (0.94, 0.93, 0.95)},
        "CoreBone":       {"rot": (0, 0, -6),  "scale": (0.86, 0.85, 0.86)},
    }
    dub_boom = {
        "Root":           {"loc": (0.0, -0.025, 0.020), "rot": (-4, -3, 3), "scale": (1.11, 1.14, 1.10)},
        "UpperAtriaL":    {"rot": (0, -5, 4),  "scale": (1.10, 1.12, 1.08)},
        "UpperAtriaR":    {"rot": (0, 5, -4),  "scale": (1.10, 1.12, 1.08)},
        "LowerVentricle": {"rot": (6, 0, -5),  "scale": (1.16, 1.18, 1.14)},
        "AortaCrown":     {"rot": (-7, 0, 0),  "scale": (1.18, 1.18, 1.22)},
        "CageL":          {"rot": (0, -12, 9), "scale": (1.14, 1.16, 1.10)},
        "CageR":          {"rot": (0, 12, -9), "scale": (1.14, 1.16, 1.10)},
        "CoreBone":       {"rot": (0, 0, -12), "scale": (1.22, 1.26, 1.22)},
    }
    diastole = {
        "Root":           {"loc": (0.0, 0.008, -0.006), "rot": (1, 0, 0), "scale": (0.97, 0.96, 0.98)},
        "UpperAtriaL":    {"rot": (0, 2, -1), "scale": (0.97, 0.97, 0.98)},
        "UpperAtriaR":    {"rot": (0, -2, 1), "scale": (0.97, 0.97, 0.98)},
        "LowerVentricle": {"rot": (-2, 0, 0), "scale": (0.97, 0.97, 0.98)},
        "AortaCrown":     {"rot": (1, 0, 0),  "scale": (0.98, 0.98, 0.97)},
        "CageL":          {"rot": (0, 3, -2), "scale": (0.97, 0.97, 0.98)},
        "CageR":          {"rot": (0, -3, 2), "scale": (0.97, 0.97, 0.98)},
        "CoreBone":       {"rot": (0, 0, 0),  "scale": (0.94, 0.94, 0.94)},
    }

    act_hb = bpy.data.actions.new("Heartbeat")
    act_hb.use_fake_user = True
    slot_hb = _set_pose_keys(arm_obj, act_hb, {
        0: rest,
        6: lub_boom,
        11: inter_clamp,
        17: dub_boom,
        26: diastole,
        36: rest,
    })

    shatter_in = {
        "Root":           {"loc": (0.06, 0.095, -0.048), "rot": (16, -15, 18), "scale": (0.79, 0.74, 0.82)},
        "UpperAtriaL":    {"rot": (10, 14, -12), "scale": (0.80, 0.78, 0.84)},
        "UpperAtriaR":    {"rot": (10, -14, 12), "scale": (0.80, 0.78, 0.84)},
        "LowerVentricle": {"rot": (-16, 10, -14), "scale": (0.78, 0.76, 0.84)},
        "AortaCrown":     {"rot": (18, -10, 12), "scale": (0.84, 0.84, 0.80)},
        "CageL":          {"rot": (-8, -18, 14), "scale": (1.16, 1.14, 1.08)},
        "CageR":          {"rot": (-8, 18, -14), "scale": (1.16, 1.14, 1.08)},
        "CoreBone":       {"rot": (0, 0, 25),    "scale": (1.38, 1.42, 1.38)},
    }
    shatter_out = {
        "Root":           {"loc": (-0.068, -0.052, 0.036), "rot": (-14, 16, -20), "scale": (1.20, 1.25, 1.16)},
        "UpperAtriaL":    {"rot": (-8, -12, 14), "scale": (1.18, 1.20, 1.14)},
        "UpperAtriaR":    {"rot": (-8, 12, -14), "scale": (1.18, 1.20, 1.14)},
        "LowerVentricle": {"rot": (14, -10, 12), "scale": (1.18, 1.20, 1.14)},
        "AortaCrown":     {"rot": (-14, 12, -10), "scale": (1.16, 1.16, 1.22)},
        "CageL":          {"rot": (6, 12, -10),  "scale": (0.88, 0.88, 0.92)},
        "CageR":          {"rot": (6, -12, 10),  "scale": (0.88, 0.88, 0.92)},
        "CoreBone":       {"rot": (0, 0, -20),   "scale": (0.76, 0.76, 0.76)},
    }
    shatter_rattle = {
        "Root":           {"loc": (0.035, 0.028, -0.018), "rot": (8, -9, 12), "scale": (0.90, 0.88, 0.92)},
        "UpperAtriaL":    {"rot": (4, 6, -6), "scale": (0.92, 0.92, 0.94)},
        "UpperAtriaR":    {"rot": (4, -6, 6), "scale": (0.92, 0.92, 0.94)},
        "LowerVentricle": {"rot": (-8, 5, -7), "scale": (0.91, 0.89, 0.93)},
        "AortaCrown":     {"rot": (8, -5, 5), "scale": (0.92, 0.92, 0.90)},
        "CageL":          {"rot": (0, -8, 6), "scale": (1.06, 1.06, 1.04)},
        "CageR":          {"rot": (0, 8, -6), "scale": (1.06, 1.06, 1.04)},
        "CoreBone":       {"rot": (0, 0, 10), "scale": (1.12, 1.12, 1.12)},
    }
    shatter_settle = {
        "Root":           {"loc": (-0.014, -0.010, 0.008), "rot": (-4, 4, -5), "scale": (1.05, 1.06, 1.03)},
        "UpperAtriaL":    {"rot": (0, -2, 2), "scale": (1.03, 1.03, 1.02)},
        "UpperAtriaR":    {"rot": (0, 2, -2), "scale": (1.03, 1.03, 1.02)},
        "LowerVentricle": {"rot": (3, 0, 2),  "scale": (1.03, 1.04, 1.02)},
        "AortaCrown":     {"rot": (-3, 0, 0), "scale": (1.03, 1.03, 1.05)},
        "CageL":          {"rot": (0, 2, -2), "scale": (0.98, 0.98, 0.99)},
        "CageR":          {"rot": (0, -2, 2), "scale": (0.98, 0.98, 0.99)},
        "CoreBone":       {"rot": (0, 0, -4), "scale": (0.96, 0.96, 0.96)},
    }

    act_dmg = bpy.data.actions.new("DamageHit")
    act_dmg.use_fake_user = True
    slot_dmg = _set_pose_keys(arm_obj, act_dmg, {
        0: rest,
        2: shatter_in,
        7: shatter_out,
        12: shatter_rattle,
        16: shatter_settle,
        20: rest,
    })

    arm_obj.animation_data.action = None
    for tr_name, act, slot, end_fr in (
        ("Heartbeat", act_hb, slot_hb, 36),
        ("DamageHit", act_dmg, slot_dmg, 20),
    ):
        tr = arm_obj.animation_data.nla_tracks.new()
        tr.name = tr_name
        strip = tr.strips.new(tr_name, 0, act)
        strip.action_frame_start = 0
        strip.action_frame_end = end_fr
        if hasattr(strip, "action_slot") and slot is not None:
            strip.action_slot = slot
        tr.mute = False

    return act_hb, act_dmg


def export_rig_glb(arm_obj, part_objs: list, out_path: pathlib.Path):
    bpy.ops.object.select_all(action="DESELECT")
    arm_obj.select_set(True)
    for po in part_objs:
        po.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_skins=True,
        export_bake_animation=True,
        export_anim_single_armature=True,
    )
    print("EXPORTED_HEART_GLB=", out_path)


def render_preview(scene, std_rig, boss_rig):
    scene.world = bpy.data.worlds.new("HeartsPreviewWorld")
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.028, 0.018, 0.020, 1.0)

    # Place Standard Heart on Left (X = -1.02) and Boss Heart on Right (X = +0.86)
    std_rig.location = (-1.02, 0.0, 0.0)
    std_rig.rotation_euler = Euler((math.radians(4), 0.0, math.radians(-10)))

    boss_rig.location = (0.86, 0.0, 0.02)
    boss_rig.rotation_euler = Euler((math.radians(4), 0.0, math.radians(10)))

    plinth_mat = make_mat("PreviewPlinthMat", (0.048, 0.026, 0.024), metallic=0.15, roughness=0.55)
    rim_mat = make_mat("PreviewRimMat", (0.74, 0.48, 0.14), metallic=0.90, roughness=0.25)
    for px, rad in ((-1.02, 0.56), (0.86, 0.78)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=32, radius1=rad, radius2=rad * 0.92, depth=0.10)
        p_obj = _create_mesh_obj("PreviewPedestal", bm, [plinth_mat], subsurf=0)
        p_obj.location = (px, 0.0, -1.04)
        bm_r = bmesh.new()
        bmesh.ops.create_cone(bm_r, cap_ends=True, cap_tris=False, segments=32, radius1=rad * 1.03, radius2=rad * 1.03, depth=0.025)
        r_obj = _create_mesh_obj("PreviewPedestalRim", bm_r, [rim_mat], subsurf=0)
        r_obj.location = (px, 0.0, -0.99)

    l_key = bpy.data.lights.new("WarmKey", "AREA")
    l_key.energy = 175.0
    l_key.size = 2.8
    l_key.color = (1.0, 0.86, 0.64)
    o_key = bpy.data.objects.new("WarmKey", l_key)
    o_key.location = (-1.5, -3.0, 2.0)
    o_key.rotation_euler = (Vector((0.0, 0.0, 0.0)) - o_key.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_key)

    l_fill = bpy.data.lights.new("GoldFill", "AREA")
    l_fill.energy = 95.0
    l_fill.size = 2.5
    l_fill.color = (1.0, 0.70, 0.36)
    o_fill = bpy.data.objects.new("GoldFill", l_fill)
    o_fill.location = (2.2, -2.6, 0.9)
    o_fill.rotation_euler = (Vector((0.2, 0.0, 0.0)) - o_fill.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_fill)

    l_rim = bpy.data.lights.new("CrimsonRim", "AREA")
    l_rim.energy = 240.0
    l_rim.size = 3.2
    l_rim.color = (1.0, 0.22, 0.26)
    o_rim = bpy.data.objects.new("CrimsonRim", l_rim)
    o_rim.location = (0.0, 2.5, 1.7)
    o_rim.rotation_euler = (Vector((0.0, 0.0, 0.0)) - o_rim.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_rim)

    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 45.0
    cam_o = bpy.data.objects.new("PreviewCam", cam_d)
    cam_o.location = (-0.06, -4.85, 0.32)
    cam_o.rotation_euler = (Vector((-0.06, 0.0, 0.04)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    scene.frame_set(0)
    bpy.context.view_layer.update()

    scene.render.resolution_x = 1440
    scene.render.resolution_y = 840
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    print("RENDERED_HEARTS_PREVIEW=", PREVIEW_PATH)


def main():
    scene = reset_scene()
    mats = get_materials()

    # 1. Build & Export Standard Heart (heart_standard.glb)
    std_chambers = build_heart_chambers(
        "HeartChambers", [mats["ruby_flesh"]], scale_mult=1.0, is_boss=False
    )
    bpy.context.view_layer.update()
    std_cracks = build_crack_veins("CrackVeins", std_chambers, mats["crack_veins"], scale_mult=1.0, is_boss=False)
    std_filigree = build_standard_filigree(std_chambers, mats)
    std_parts = [std_chambers, std_cracks, std_filigree]
    std_rig = create_heart_rig_and_bind("HeartRig", std_parts, scale_mult=1.0, is_boss=False)
    author_standard_animations(std_rig)
    export_rig_glb(std_rig, std_parts, OUT_STANDARD)

    # Rename standard objects in Blender scene after export so Boss Heart gets exact un-suffixed names
    std_chambers.name = "Std_HeartChambers"
    std_chambers.data.name = "Std_HeartChambers_Mesh"
    std_cracks.name = "Std_CrackVeins"
    std_cracks.data.name = "Std_CrackVeins_Mesh"
    std_rig.location = (-10.0, 0.0, 0.0)
    bpy.context.view_layer.update()

    # 2. Build & Export Boss Heart (heart_boss.glb) (~1.38x silhouette scale + crown & thorny cage)
    boss_scale = 1.38
    boss_chambers = build_heart_chambers(
        "HeartChambers", [mats["boss_obsidian"]], scale_mult=boss_scale, is_boss=True
    )
    bpy.context.view_layer.update()
    boss_cracks = build_crack_veins("CrackVeins", boss_chambers, mats["crack_veins_boss"], scale_mult=boss_scale, is_boss=True)
    boss_core = build_boss_ember_core(boss_chambers, mats, scale_mult=boss_scale)
    boss_cage = build_boss_thorny_rib_cage(boss_chambers, mats, scale_mult=boss_scale)
    boss_crown = build_boss_royal_crown(mats, scale_mult=boss_scale)
    boss_parts = [boss_chambers, boss_cracks, boss_core, boss_cage, boss_crown]
    boss_rig = create_heart_rig_and_bind("HeartRig", boss_parts, scale_mult=boss_scale, is_boss=True)
    author_boss_animations(boss_rig)
    export_rig_glb(boss_rig, boss_parts, OUT_BOSS)

    # 3. Render Side-by-Side Preview Inspection Sheet
    render_preview(scene, std_rig, boss_rig)


if __name__ == "__main__":
    main()
