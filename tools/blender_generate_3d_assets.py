"""
Blender 5.3 headless 3D asset generator for LIALO:
  1) Exports the first 8 Relics as multi-part PBR .glb models -> assets/models/relics/<REL_ID>.glb
     - Base rests at Blender Z = 0.0 (tabletop coaster surface), bounding width ~0.11-0.14m, height ~0.10-0.16m.
  2) Exports all 5 Swords as multi-part PBR .glb models -> assets/models/swords/<SKIN_ID>.glb
     - Blade points along Blender +Y (= Godot -Z), hilt along Blender -Y (= Godot +Z), flat on Z = +0.014 (= Godot Y = +0.014).
  3) Renders a studio EEVEE showcase sheet -> blender_models_preview.png in scratch dir.
Run via:
  blender --background --factory-startup --python tools/blender_generate_3d_assets.py
"""
import math
import pathlib
import random
import bpy
import bmesh
from mathutils import Vector, Euler

ROOT = pathlib.Path(r"D:\downpour-godot")
RELIC_DIR = ROOT / "assets" / "models" / "relics"
SWORD_DIR = ROOT / "assets" / "models" / "swords"
PREVIEW_PATH = pathlib.Path(r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\scratch\blender_models_preview.png")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    return scene


def make_mat(name: str, color: tuple, metallic: float = 0.0, roughness: float = 0.5,
             emission: tuple = (0.0, 0.0, 0.0), emit_str: float = 0.0, alpha: float = 1.0):
    mat = bpy.data.materials.new(name)
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emit_str
    bsdf.inputs["Alpha"].default_value = alpha
    return mat


def get_mats():
    return {
        "brass": make_mat("Brass", (0.85, 0.65, 0.22), metallic=0.88, roughness=0.26),
        "gold": make_mat("Gold", (0.96, 0.78, 0.24), metallic=0.92, roughness=0.22),
        "copper": make_mat("Copper", (0.82, 0.42, 0.20), metallic=0.86, roughness=0.28),
        "steel": make_mat("Steel", (0.76, 0.80, 0.86), metallic=0.92, roughness=0.22),
        "damascus": make_mat("Damascus", (0.84, 0.86, 0.92), metallic=0.94, roughness=0.18),
        "smoked_iron": make_mat("SmokedIron", (0.26, 0.22, 0.24), metallic=0.82, roughness=0.38),
        "iron": make_mat("Iron", (0.22, 0.23, 0.26), metallic=0.78, roughness=0.44),
        "black_silver": make_mat("BlackSilver", (0.44, 0.46, 0.52), metallic=0.88, roughness=0.32),
        "oak": make_mat("Oak", (0.42, 0.25, 0.13), metallic=0.0, roughness=0.66),
        "walnut": make_mat("Walnut", (0.24, 0.14, 0.08), metallic=0.0, roughness=0.68),
        "leather": make_mat("Leather", (0.30, 0.17, 0.10), metallic=0.0, roughness=0.70),
        "bone": make_mat("Bone", (0.91, 0.84, 0.68), metallic=0.0, roughness=0.42),
        "ivory": make_mat("Ivory", (0.95, 0.90, 0.78), metallic=0.0, roughness=0.34),
        "horn": make_mat("Horn", (0.36, 0.26, 0.18), metallic=0.0, roughness=0.48),
        "velvet": make_mat("VelvetRed", (0.56, 0.10, 0.12), metallic=0.0, roughness=0.86),
        "slate": make_mat("Slate", (0.26, 0.26, 0.28), metallic=0.05, roughness=0.78),
        "porcelain": make_mat("Porcelain", (0.90, 0.90, 0.94), metallic=0.0, roughness=0.24),
        "glass": make_mat("BlownGlass", (0.66, 0.88, 0.94), metallic=0.10, roughness=0.12, emission=(0.14, 0.28, 0.34), emit_str=0.4),
        "amber": make_mat("EmberGlow", (1.0, 0.54, 0.12), metallic=0.0, roughness=0.24, emission=(1.0, 0.42, 0.08), emit_str=2.2),
        "cyan": make_mat("StormCyan", (0.36, 0.90, 1.0), metallic=0.0, roughness=0.18, emission=(0.24, 0.84, 1.0), emit_str=2.5),
        "crimson_glow": make_mat("CrimsonGlow", (0.86, 0.12, 0.18), metallic=0.0, roughness=0.20, emission=(0.90, 0.10, 0.16), emit_str=1.9),
        "plumage": make_mat("PhoenixRed", (0.82, 0.20, 0.10), metallic=0.15, roughness=0.42, emission=(0.60, 0.16, 0.04), emit_str=0.5),
        "sapphire": make_mat("Sapphire", (0.16, 0.46, 0.94), metallic=0.10, roughness=0.18, emission=(0.18, 0.54, 1.0), emit_str=1.5),
    }


def link_part(parent, name: str, bm: bmesh.types.BMesh, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
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
    obj.parent = parent
    bpy.context.scene.collection.objects.link(obj)
    return obj


def bm_lathe(parent, name: str, prof: list, mat, segs=24, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = (i / segs) * math.tau
        rings.append([bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for (r, z) in prof])
    for i in range(segs):
        ni = (i + 1) % segs
        for j in range(len(prof) - 1):
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][j + 1], rings[i][j + 1]))
    if prof[0][0] > 1e-4:
        bm.faces.new([rings[i][0] for i in range(segs)][::-1])
    if prof[-1][0] > 1e-4:
        bm.faces.new([rings[i][-1] for i in range(segs)])
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def bm_tube(parent, name: str, pts: list, radii: list, mat, segs=12, loc=(0, 0, 0), rot=(0, 0, 0), rib_amp=0.0):
    bm = bmesh.new()
    n = len(pts)
    rings = []
    for idx, (pt, rad) in enumerate(zip(pts, radii)):
        p = Vector(pt)
        if idx == 0:
            tang = (Vector(pts[1]) - p).normalized()
        elif idx == n - 1:
            tang = (p - Vector(pts[-2])).normalized()
        else:
            tang = (Vector(pts[idx + 1]) - Vector(pts[idx - 1])).normalized()
        up = Vector((0, 0, 1)) if abs(tang.z) < 0.92 else Vector((1, 0, 0))
        u = tang.cross(up).normalized()
        v = tang.cross(u).normalized()
        r_eff = rad * (1.0 + rib_amp * math.sin(idx * 2.2))
        ring = []
        for k in range(segs):
            a = (k / segs) * math.tau
            ring.append(bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * r_eff))
        rings.append(ring)
    for idx in range(n - 1):
        for k in range(segs):
            nk = (k + 1) % segs
            bm.faces.new((rings[idx][k], rings[idx][nk], rings[idx + 1][nk], rings[idx + 1][k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


def bm_box(parent, name: str, size: tuple, mat, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=False)


def bm_cyl(parent, name: str, r1: float, r2: float, h: float, mat, segs=16, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


def bm_sphere(parent, name: str, rad: float, mat, scale=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), sub=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=rad)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


def bm_torus(parent, name: str, maj: float, mn: float, mat, maj_s=24, min_s=10, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    rings = []
    for i in range(maj_s):
        a = (i / maj_s) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        rings.append([
            bm.verts.new((ca * (maj + math.cos(j * math.tau / min_s) * mn),
                          sa * (maj + math.cos(j * math.tau / min_s) * mn),
                          math.sin(j * math.tau / min_s) * mn))
            for j in range(min_s)
        ])
    for i in range(maj_s):
        ni = (i + 1) % maj_s
        for j in range(min_s):
            nj = (j + 1) % min_s
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][nj], rings[i][nj]))
    return link_part(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


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
# FIRST 8 RELICS (base Z=0.0, diameter ~0.10-0.14m, height ~0.10-0.15m)
# =============================================================================

def build_rel_chamois(M):
    root = bpy.data.objects.new("REL_CHAMOIS", None)
    bpy.context.scene.collection.objects.link(root)
    # Forked carved oak cradle
    bm_box(root, "CradleBase", (0.075, 0.044, 0.014), M["oak"], loc=(0, 0, 0.007))
    for sx in (-0.022, 0.022):
        bm_cyl(root, f"Fork{sx}", 0.006, 0.004, 0.042, M["oak"], loc=(sx, 0, 0.032), rot=(0, sx * 260, 0), segs=10)
    # Sweeping ribbed hunting horn curve with brass bell + mouthpiece
    n_pts = 20
    pts, rads = [], []
    for i in range(n_pts):
        t = i / (n_pts - 1)
        x = -0.045 + t * 0.095
        y = math.sin(t * math.pi) * 0.022
        z = 0.042 + math.sin(t * 1.1) * 0.024 + t * 0.048
        pts.append((x, y, z))
        rads.append(0.022 * ((1.0 - t) ** 0.72) + 0.005)
    bm_tube(root, "HornBody", pts, rads, M["horn"], segs=18, rib_amp=0.07)
    bm_lathe(root, "BrassBell", [(0.019, 0.0), (0.024, 0.012), (0.030, 0.022), (0.026, 0.023), (0.018, 0.004)], M["brass"], loc=pts[0], rot=(-38, -72, 0))
    bm_lathe(root, "BrassMouthpiece", [(0.006, 0.0), (0.009, 0.010), (0.005, 0.018), (0.008, 0.024)], M["gold"], loc=pts[-1], rot=(25, 58, 0))
    bm_torus(root, "LeatherCollar", 0.017, 0.0045, M["leather"], loc=pts[6], rot=(0, 68, 12))
    bm_torus(root, "BrassStrapRing", 0.013, 0.003, M["brass"], loc=pts[11], rot=(0, 56, 8))
    return root


def build_rel_fujara(M):
    root = bpy.data.objects.new("REL_FUJARA", None)
    bpy.context.scene.collection.objects.link(root)
    bm_cyl(root, "StandFoot", 0.042, 0.036, 0.014, M["walnut"], loc=(0, 0, 0.007), segs=12)
    bm_cyl(root, "StandPeg", 0.012, 0.016, 0.036, M["walnut"], loc=(-0.014, 0, 0.028), segs=10)
    # Tilted carved shepherd fujara main pipe + slender air-pipe + 4 chased copper bands aligned to axis
    tilt = (8, -22, 10)
    rot_m = Euler([math.radians(a) for a in tilt], "XYZ").to_matrix()
    base_pt = Vector((-0.012, 0, 0.016))
    bm_lathe(root, "MainPipe", [
        (0.016, 0.0), (0.020, 0.012), (0.015, 0.026), (0.014, 0.135), (0.017, 0.148), (0.012, 0.148), (0.012, 0.02)
    ], M["oak"], loc=tuple(base_pt), rot=tilt, segs=20)
    air_loc = base_pt + rot_m @ Vector((0.021, 0.0, 0.068))
    bm_cyl(root, "AirPipe", 0.0052, 0.0052, 0.095, M["oak"], loc=tuple(air_loc), rot=tilt, segs=12)
    for zi in [0.022, 0.056, 0.092, 0.126]:
        b_loc = base_pt + rot_m @ Vector((0.0, 0.0, zi))
        bm_torus(root, f"CopperBand{zi}", 0.0165, 0.0028, M["copper"], loc=tuple(b_loc), rot=tilt)
    crown_loc = base_pt + rot_m @ Vector((0.0, 0.0, 0.138))
    bm_lathe(root, "BrassCrown", [(0.014, 0.0), (0.018, 0.010), (0.015, 0.012)], M["brass"], loc=tuple(crown_loc), rot=tilt)
    win_loc = base_pt + rot_m @ Vector((0.002, -0.014, 0.072))
    bm_box(root, "SoundWindow", (0.008, 0.004, 0.018), M["walnut"], loc=tuple(win_loc), rot=tilt)
    return root


def build_rel_stormcap(M):
    root = bpy.data.objects.new("REL_STORMCAP", None)
    bpy.context.scene.collection.objects.link(root)
    bm_lathe(root, "LeydenBase", [(0.046, 0.0), (0.048, 0.014), (0.042, 0.024)], M["walnut"], loc=(0, 0, 0.0), segs=24)
    bm_torus(root, "BaseBrassRim", 0.044, 0.004, M["brass"], loc=(0, 0, 0.024))
    bm_cyl(root, "LeydenJar", 0.038, 0.038, 0.068, M["glass"], loc=(0, 0, 0.058), segs=24)
    # Real 3D helical wound copper coil around jar!
    c_pts = []
    for k in range(52):
        t = k / 51.0
        a = t * math.tau * 4.5
        c_pts.append((math.cos(a) * 0.041, math.sin(a) * 0.041, 0.030 + t * 0.056))
    bm_tube(root, "CopperHelix", c_pts, [0.0032] * 52, M["copper"], segs=8)
    # Porcelain insulator stack & brass cap
    bm_lathe(root, "Insulator", [(0.040, 0.092), (0.028, 0.098), (0.034, 0.106), (0.022, 0.114), (0.030, 0.120)], M["porcelain"], segs=20)
    # Twin arcing brass spark rods flanking emissive cyan plasma sphere!
    for sx in (-1, 1):
        arc = [(sx * 0.024, 0, 0.114), (sx * 0.034, 0, 0.132), (sx * 0.018, 0, 0.146)]
        bm_tube(root, f"SparkRod{sx}", arc, [0.0035, 0.0030, 0.0024], M["brass"], segs=8)
        bm_sphere(root, f"RodTip{sx}", 0.005, M["gold"], loc=arc[-1], sub=2)
    bm_sphere(root, "PlasmaOrb", 0.015, M["cyan"], loc=(0, 0, 0.144), sub=2)
    return root


def build_rel_knuckle(M):
    root = bpy.data.objects.new("REL_KNUCKLE", None)
    bpy.context.scene.collection.objects.link(root)
    # Velvet-lined walnut tray
    bm_lathe(root, "TrayRim", [(0.054, 0.0), (0.056, 0.008), (0.050, 0.014), (0.046, 0.010)], M["walnut"], segs=20)
    bm_cyl(root, "VelvetPad", 0.048, 0.048, 0.006, M["velvet"], loc=(0, 0, 0.008), segs=20)
    # Organic sculpted sheep astragalus bone (waisted central saddle + 4 asymmetric condyle lobes + silver collar + gold pips)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=0.028)
    for v in bm.verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        # Sculpt characteristic saddle pinch & four bulbous articular condyles
        waist = 1.0 - 0.34 * math.exp(-(z * z) / 0.00025)
        condyle = 1.0 + 0.24 * math.cos(math.atan2(y, x) * 2.0) * abs(z / 0.028)
        v.co.x = x * waist * condyle * 1.15
        v.co.y = y * waist * 0.72
        v.co.z = z * 1.48
    link_part(root, "AstragalusBone", bm, M["ivory"], loc=(0, 0, 0.048), rot=(18, -22, 14), smooth=True)
    bm_torus(root, "SilverRuneBand", 0.024, 0.0032, M["black_silver"], loc=(0, 0, 0.048), rot=(18, -22, 14))
    for px, py, pz in [(0.014, -0.016, 0.068), (-0.012, -0.018, 0.062), (0.010, -0.020, 0.036)]:
        bm_sphere(root, f"GoldPip{px}", 0.0045, M["gold"], loc=(px, py, pz), sub=1)
    return root


def build_rel_phoenix_f(M):
    root = bpy.data.objects.new("REL_PHOENIX_F", None)
    bpy.context.scene.collection.objects.link(root)
    # Filigree brass inkwell brazier
    bm_lathe(root, "Inkwell", [(0.036, 0.0), (0.038, 0.008), (0.022, 0.018), (0.030, 0.036), (0.018, 0.044)], M["brass"], loc=(0.012, 0, 0.0), segs=18)
    bm_sphere(root, "InkEmber", 0.016, M["amber"], loc=(0.012, 0, 0.040), scale=(1.0, 1.0, 0.55))
    # Arched S-curved gold quill shaft rising out of inkwell
    q_pts = [(0.012, 0, 0.036), (0.004, 0.006, 0.072), (-0.014, -0.004, 0.112), (-0.030, -0.010, 0.152)]
    bm_tube(root, "QuillShaft", q_pts, [0.0038, 0.0032, 0.0024, 0.0014], M["gold"], segs=8)
    # Sculpted curved notched phoenix feather vane + glowing ember tip barbs
    bm_vane = bmesh.new()
    rows = []
    for i in range(14):
        t = i / 13.0
        spine = Vector(q_pts[0]).lerp(Vector(q_pts[-1]), t)
        spine.x += math.sin(t * math.pi) * (-0.008)
        w = 0.026 * math.sin(max(0.0, (t - 0.12) / 0.88) * math.pi) ** 0.72
        if i in (6, 10):
            w *= 0.65  # Characteristic asymmetric feather vane notch!
        vL = bm_vane.verts.new(spine + Vector((-w * 0.9, 0.008, 0.004)))
        vC = bm_vane.verts.new(spine + Vector((0, -0.003, 0)))
        vR = bm_vane.verts.new(spine + Vector((w * 1.1, 0.009, 0.003)))
        rows.append((vL, vC, vR))
    for i in range(13):
        bm_vane.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
        bm_vane.faces.new((rows[i][1], rows[i][2], rows[i + 1][2], rows[i + 1][1]))
    link_part(root, "PhoenixVane", bm_vane, M["plumage"], smooth=True)
    bm_sphere(root, "TipEmber", 0.011, M["amber"], loc=(-0.030, -0.010, 0.152), scale=(0.8, 0.5, 1.5), sub=2)
    return root


def build_rel_fang(M):
    root = bpy.data.objects.new("REL_FANG", None)
    bpy.context.scene.collection.objects.link(root)
    # Chipped dark slate plinth
    bm_cyl(root, "SlatePlinth", 0.048, 0.044, 0.018, M["slate"], loc=(0, 0, 0.009), segs=7)
    # Swept fluted ivory beast fang rising & curving dramatically
    f_pts, f_rad = [], []
    for i in range(16):
        t = i / 15.0
        f_pts.append((-0.010 + math.sin(t * 1.7) * 0.032, -0.004 + math.sin(t * 2.2) * 0.010, 0.026 + t * 0.118))
        f_rad.append(0.019 * ((1.0 - t) ** 0.82) + 0.002)
    bm_tube(root, "BeastFang", f_pts, f_rad, M["ivory"], segs=16)
    bm_sphere(root, "BloodTip", 0.006, M["crimson_glow"], loc=f_pts[-1], scale=(0.9, 0.9, 1.8))
    # 4-Talon blackened silver clasp gripping fang base + chain links onto plinth
    bm_lathe(root, "SilverSocket", [(0.024, 0.018), (0.022, 0.042), (0.018, 0.048)], M["black_silver"], segs=14)
    for k in range(4):
        a = k * math.tau / 4.0 + 0.4
        claw = [(math.cos(a) * 0.022, math.sin(a) * 0.022, 0.040), (math.cos(a) * 0.018, math.sin(a) * 0.018, 0.068)]
        bm_tube(root, f"Talon{k}", claw, [0.004, 0.0015], M["black_silver"], segs=6)
    for li in range(4):
        bm_torus(root, f"Chain{li}", 0.009, 0.0026, M["iron"], loc=(0.024 + li * 0.008, -0.012, 0.022), rot=(55, li * 65, 20))
    return root


def build_rel_greed(M):
    root = bpy.data.objects.new("REL_GREED", None)
    bpy.context.scene.collection.objects.link(root)
    # Turned apothecary balance pillar
    bm_lathe(root, "ScaleBase", [(0.038, 0.0), (0.040, 0.008), (0.024, 0.018), (0.008, 0.030), (0.006, 0.125), (0.011, 0.138), (0.003, 0.150)], M["brass"], segs=18)
    # Tilted cross-beam (heavy with coins on left!)
    tilt_deg = 11.0
    bm_box(root, "BalanceBeam", (0.118, 0.007, 0.007), M["gold"], loc=(0, 0, 0.128), rot=(0, tilt_deg, 0))
    # Two dished brass pans suspended by fine twin cords
    for side, dz, has_coins in [(-1, -0.011, True), (1, 0.011, False)]:
        top_x = side * 0.054
        top_z = 0.128 + dz
        pan_z = top_z - 0.062
        for sy in (-0.014, 0.014):
            bm_tube(root, f"Chain{side}{sy}", [(top_x, 0, top_z), (top_x, sy, pan_z + 0.006)], [0.0016, 0.0016], M["brass"], segs=6)
        bm_lathe(root, f"Pan{side}", [(0.001, 0.0), (0.022, 0.002), (0.026, 0.009), (0.024, 0.010)], M["brass"], loc=(top_x, 0, pan_z), segs=16)
        if has_coins:
            for ci in range(5):
                bm_cyl(root, f"Florin{ci}", 0.009, 0.009, 0.0032, M["gold"], loc=(top_x + (ci % 2 - 0.5) * 0.007, ((ci // 2) % 2 - 0.5) * 0.006, pan_z + 0.004 + (ci // 2) * 0.0034), segs=12)
        else:
            bm_cyl(root, "CounterWeight", 0.008, 0.006, 0.014, M["copper"], loc=(top_x, 0, pan_z + 0.010), segs=8)
    return root


def build_rel_alembic(M):
    root = bpy.data.objects.new("REL_ALEMBIC", None)
    bpy.context.scene.collection.objects.link(root)
    # Glowing brazier coal bed & 3-legged riveted wrought iron tripod
    bm_sphere(root, "CoalBed", 0.024, M["amber"], loc=(-0.012, 0, 0.012), scale=(1.2, 1.2, 0.45))
    for k in range(3):
        a = k * math.tau / 3.0 + 0.3
        bm_tube(root, f"TripodLeg{k}", [(-0.012 + math.cos(a) * 0.044, math.sin(a) * 0.044, 0.0), (-0.012 + math.cos(a) * 0.028, math.sin(a) * 0.028, 0.056)], [0.004, 0.0035], M["iron"], segs=8)
    bm_torus(root, "TripodRing", 0.030, 0.004, M["iron"], loc=(-0.012, 0, 0.056))
    # Blown glass retort sphere + tapering swan-neck condenser dripping amber potion into vial!
    bm_sphere(root, "RetortBulb", 0.034, M["glass"], loc=(-0.012, 0, 0.088), sub=2)
    bm_sphere(root, "PotionCore", 0.024, M["amber"], loc=(-0.012, 0, 0.080), scale=(1.0, 1.0, 0.7))
    neck_pts = [(-0.012, 0, 0.120), (0.008, 0, 0.134), (0.034, -0.004, 0.118), (0.044, -0.004, 0.072)]
    bm_tube(root, "SwanNeck", neck_pts, [0.011, 0.008, 0.0055, 0.0038], M["glass"], segs=12)
    bm_lathe(root, "ReceiverVial", [(0.016, 0.0), (0.018, 0.012), (0.014, 0.034), (0.008, 0.046), (0.011, 0.050)], M["glass"], loc=(0.044, -0.004, 0.0), segs=16)
    bm_sphere(root, "DropElixir", 0.0045, M["amber"], loc=(0.044, -0.004, 0.058), scale=(0.8, 0.8, 1.5))
    return root


# =============================================================================
# ALL 5 SWORDS (+Y = tip / Godot -Z, -Y = grip / Godot +Z, Z = +0.014)
# =============================================================================

def make_sword_blade(parent, name: str, pts_y: list, widths: list, curve_x: list, mat, thick=0.006, back_spine=False):
    """Sculpts a crisp diamond/wedge cross-section sword blade extending along Blender +Y."""
    bm = bmesh.new()
    rings = []
    for y, w, cx in zip(pts_y, widths, curve_x):
        vL = bm.verts.new((cx - w, y, 0.0))
        vT = bm.verts.new((cx + (w * 0.35 if back_spine else 0.0), y, thick))
        vR = bm.verts.new((cx + w, y, 0.0))
        vB = bm.verts.new((cx + (w * 0.35 if back_spine else 0.0), y, -thick))
        rings.append((vL, vT, vR, vB))
    for i in range(len(rings) - 1):
        for k in range(4):
            nk = (k + 1) % 4
            bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][nk], rings[i][nk]))
    # Tip pinch
    tip_y = pts_y[-1] + 0.095
    tip_v = bm.verts.new((curve_x[-1] + (widths[-1] * 0.45 if back_spine else 0.0), tip_y, 0.0))
    for k in range(4):
        nk = (k + 1) % 4
        bm.faces.new((rings[-1][k], tip_v, rings[-1][nk]))
    bm.faces.new(rings[0][::-1])
    return link_part(parent, name, bm, mat, loc=(0, 0, 0.014), smooth=False)


def add_hilt_common(root, grip_mat, guard_mat, gem_mat, grip_len=0.155, ribbed=True):
    bm_cyl(root, "Grip", 0.015, 0.018, grip_len, grip_mat, loc=(0, -grip_len * 0.52, 0.014), rot=(90, 0, 0), segs=14)
    if ribbed:
        for ri in range(4):
            bm_torus(root, f"GripRing{ri}", 0.017, 0.003, guard_mat, loc=(0, -0.028 - ri * 0.032, 0.014), rot=(90, 0, 0))
    bm_cyl(root, "PommelDisc", 0.027, 0.027, 0.022, guard_mat, loc=(0, -grip_len - 0.014, 0.014), rot=(0, 0, 0), segs=16)
    bm_sphere(root, "PommelGem", 0.012, gem_mat, loc=(0, -grip_len - 0.014, 0.028), scale=(1.0, 1.0, 0.65), sub=2)


def build_sword_iron(M):
    # Tavern Falchion: single-edged widened cleaver belly + S-curved iron crossguard + brass rivets
    root = bpy.data.objects.new("SWORD_IRON", None)
    bpy.context.scene.collection.objects.link(root)
    make_sword_blade(root, "FalchionBlade", [0.0, 0.14, 0.34, 0.48, 0.56], [0.020, 0.022, 0.028, 0.035, 0.026], [0.0, 0.002, 0.006, 0.008, 0.002], M["steel"], thick=0.0055, back_spine=True)
    bm_cyl(root, "Fuller", 0.004, 0.004, 0.42, M["iron"], loc=(0.006, 0.25, 0.017), rot=(90, 0, 0), segs=6)
    guard_pts = [(-0.105, 0.015, 0.014), (-0.055, -0.008, 0.014), (0.0, 0.0, 0.014), (0.055, 0.008, 0.014), (0.105, -0.015, 0.014)]
    bm_tube(root, "SGuard", guard_pts, [0.012, 0.010, 0.013, 0.010, 0.012], M["brass"], segs=10)
    add_hilt_common(root, M["leather"], M["brass"], M["iron"])
    return root


def build_sword_gilded(M):
    # Royal Claymore: wide Damascus blade + V-swept gilded crossguard ending in quatrefoil rings + crown pommel
    root = bpy.data.objects.new("SWORD_GILDED", None)
    bpy.context.scene.collection.objects.link(root)
    make_sword_blade(root, "ClaymoreBlade", [0.0, 0.18, 0.38, 0.56], [0.028, 0.025, 0.022, 0.017], [0, 0, 0, 0], M["damascus"], thick=0.007)
    bm_cyl(root, "GoldFuller", 0.005, 0.003, 0.44, M["gold"], loc=(0, 0.24, 0.018), rot=(90, 0, 0), segs=6)
    bm_tube(root, "VGuard", [(-0.125, 0.048, 0.014), (0.0, -0.006, 0.014), (0.125, 0.048, 0.014)], [0.010, 0.015, 0.010], M["gold"], segs=10)
    for sx in (-0.128, 0.128):
        bm_torus(root, f"Quatrefoil{sx}", 0.016, 0.005, M["gold"], loc=(sx, 0.052, 0.014))
    add_hilt_common(root, M["velvet"], M["gold"], M["crimson_glow"], grip_len=0.175)
    return root


def build_sword_crimson(M):
    # Vampire Saber: curved smoked-iron saber blade + crimson glowing fuller vein + swept bat-wing knuckle-bow
    root = bpy.data.objects.new("SWORD_CRIMSON", None)
    bpy.context.scene.collection.objects.link(root)
    ys = [0.0, 0.15, 0.30, 0.45, 0.58]
    cx = [0.0, 0.006, 0.020, 0.044, 0.072]
    ws = [0.022, 0.022, 0.021, 0.018, 0.013]
    make_sword_blade(root, "SaberBlade", ys, ws, cx, M["smoked_iron"], thick=0.006, back_spine=True)
    vein = [(x, y, 0.017) for x, y in zip(cx[:-1], ys[:-1])]
    bm_tube(root, "BloodVein", vein, [0.0045, 0.004, 0.0035, 0.0025], M["crimson_glow"], segs=6)
    bow_pts = [(-0.10, 0.032, 0.014), (-0.05, 0.005, 0.014), (0.0, 0.0, 0.014), (0.068, -0.022, 0.014), (0.076, -0.105, 0.014), (0.022, -0.172, 0.014)]
    bm_tube(root, "BatKnuckleBow", bow_pts, [0.010, 0.011, 0.014, 0.010, 0.008, 0.008], M["brass"], segs=10)
    add_hilt_common(root, M["leather"], M["brass"], M["crimson_glow"])
    return root


def build_sword_rune(M):
    # Tempest Runeblade: notched steel ricasso + glowing cyan crystal fuller inlay + twin lightning-fork quillons
    root = bpy.data.objects.new("SWORD_RUNE", None)
    bpy.context.scene.collection.objects.link(root)
    make_sword_blade(root, "RuneBlade", [0.0, 0.12, 0.34, 0.57], [0.027, 0.025, 0.021, 0.015], [0, 0, 0, 0], M["steel"], thick=0.007)
    bm_cyl(root, "RuneInlay", 0.0055, 0.003, 0.45, M["cyan"], loc=(0, 0.25, 0.018), rot=(90, 0, 0), segs=6)
    for sx in (-1, 1):
        fork = [(0, 0, 0.014), (sx * 0.055, 0.016, 0.014), (sx * 0.095, 0.002, 0.014), (sx * 0.126, 0.038, 0.014)]
        bm_tube(root, f"StormQuillon{sx}", fork, [0.013, 0.010, 0.009, 0.006], M["black_silver"], segs=8)
    add_hilt_common(root, M["smoked_iron"], M["black_silver"], M["sapphire"])
    return root


def build_sword_dragon(M):
    # Dragonfire Greatsword: volcanic iron serrated blade + glowing ember vein + sweeping dragon-wing crossguard
    root = bpy.data.objects.new("SWORD_DRAGON", None)
    bpy.context.scene.collection.objects.link(root)
    make_sword_blade(root, "DragonBlade", [0.0, 0.16, 0.36, 0.58], [0.032, 0.029, 0.025, 0.018], [0, 0, 0, 0], M["smoked_iron"], thick=0.008)
    bm_cyl(root, "LavaCore", 0.006, 0.0025, 0.46, M["amber"], loc=(0, 0.26, 0.019), rot=(90, 0, 0), segs=6)
    for k in range(5):
        for sx in (-1, 1):
            bm_box(root, f"Serr{sx}{k}", (0.016, 0.018, 0.008), M["iron"], loc=(sx * 0.030, 0.10 + k * 0.088, 0.014), rot=(0, 0, sx * 36))
    for sx in (-1, 1):
        wing = [(0, 0, 0.014), (sx * 0.06, 0.032, 0.018), (sx * 0.135, 0.068, 0.022), (sx * 0.148, 0.012, 0.014)]
        bm_tube(root, f"DragonWing{sx}", wing, [0.016, 0.013, 0.009, 0.004], M["gold"], segs=10)
    add_hilt_common(root, M["leather"], M["gold"], M["amber"], grip_len=0.185)
    return root


def render_contact_sheet():
    scene = reset_scene()
    M = get_mats()
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 900
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("StudioWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.06, 0.045, 0.035, 1.0)

    # Dark oak studio table plane
    tbl = bpy.data.objects.new("StudioTable", bpy.data.meshes.new("StudioTableM"))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=4, y_segments=4, size=3.0)
    bm.to_mesh(tbl.data)
    bm.free()
    tbl.data.materials.append(M["walnut"])
    scene.collection.objects.link(tbl)

    # Place all 8 Relics (scaled 2.2x so intricate geometry fills frame cleanly) in upper row
    relic_builders = [
        build_rel_chamois, build_rel_fujara, build_rel_stormcap, build_rel_knuckle,
        build_rel_phoenix_f, build_rel_fang, build_rel_greed, build_rel_alembic,
    ]
    for idx, fn in enumerate(relic_builders):
        r_obj = fn(M)
        x = -1.22 + idx * 0.35
        r_obj.location = (x, 0.28, 0.0)
        r_obj.scale = (2.15, 2.15, 2.15)

    # Place all 5 Swords upright/fanned slightly forward in foreground row
    sword_builders = [build_sword_iron, build_sword_gilded, build_sword_crimson, build_sword_rune, build_sword_dragon]
    for idx, fn in enumerate(sword_builders):
        s_obj = fn(M)
        s_obj.location = (-0.90 + idx * 0.45, -0.58, 0.005)
        s_obj.scale = (1.15, 1.15, 1.15)

    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 38.0
    cam_o = bpy.data.objects.new("PreviewCam", cam_d)
    cam_o.location = (0.0, -2.05, 1.48)
    cam_o.rotation_euler = (Vector((0, -0.05, 0.14)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    l1 = bpy.data.lights.new("Key", "AREA"); l1.energy = 260; l1.size = 3.0
    o1 = bpy.data.objects.new("Key", l1); o1.location = (-1.8, -1.6, 2.4)
    o1.rotation_euler = (Vector((0, 0, 0)) - o1.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o1)

    l2 = bpy.data.lights.new("Fill", "AREA"); l2.energy = 110; l2.size = 3.5; l2.color = (0.85, 0.92, 1.0)
    o2 = bpy.data.objects.new("Fill", l2); o2.location = (2.2, -1.2, 1.6)
    o2.rotation_euler = (Vector((0, 0, 0)) - o2.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o2)

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    print("RENDERED_CONTACT_SHEET=", PREVIEW_PATH)


def main():
    relic_map = {
        "REL_CHAMOIS": build_rel_chamois,
        "REL_FUJARA": build_rel_fujara,
        "REL_STORMCAP": build_rel_stormcap,
        "REL_KNUCKLE": build_rel_knuckle,
        "REL_PHOENIX_F": build_rel_phoenix_f,
        "REL_FANG": build_rel_fang,
        "REL_GREED": build_rel_greed,
        "REL_ALEMBIC": build_rel_alembic,
    }
    sword_map = {
        "SWORD_IRON": build_sword_iron,
        "SWORD_GILDED": build_sword_gilded,
        "SWORD_CRIMSON": build_sword_crimson,
        "SWORD_RUNE": build_sword_rune,
        "SWORD_DRAGON": build_sword_dragon,
    }
    for rid, fn in relic_map.items():
        reset_scene()
        M = get_mats()
        root = fn(M)
        out = RELIC_DIR / f"{rid}.glb"
        export_glb(root, out)
        print(f"EXPORTED_RELIC_GLB={out.name}")

    for sid, fn in sword_map.items():
        reset_scene()
        M = get_mats()
        root = fn(M)
        out = SWORD_DIR / f"{sid}.glb"
        export_glb(root, out)
        print(f"EXPORTED_SWORD_GLB={out.name}")

    render_contact_sheet()


if __name__ == "__main__":
    main()
