"""
Blender 5.3 headless 3D Tatra Chamois generator, rigger & animator for LIALO Intro:
  - Builds a smooth, anatomically sculpted Rupicapra rupicapra tatrica (Tatra Chamois)
    facing +X with hooves resting on Z = 0.0, iconic backward-hooked ringed horns,
    and authentic winter coat markings (dark saddle, cream throat/rump/face mask).
  - Binds to a hierarchical Armature (ChamoisRig) with deterministic smooth weights.
  - Authors two looping NLA actions: 'LeapCycle' (36 frames @ 30fps) & 'RidgeStand' (48 frames @ 30fps).
  - Exports -> D:/downpour-godot/assets/models/intro_chamois.glb
  - Renders a 4-panel EEVEE inspection sheet -> scratch/intro_chamois_preview.png

Run via:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_intro_chamois.py
"""
import math
import pathlib
import bpy
import bmesh
from bpy_extras import anim_utils
from mathutils import Vector, Matrix

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_GLB = ROOT / "assets" / "models" / "intro_chamois.glb"
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a7664877-b33a-48d0-8658-be5de670b3ca\scratch\intro_chamois_preview.png"
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.fps = 30
    return scene


def make_mat(name: str, color: tuple, metallic: float = 0.0, roughness: float = 0.65,
             emission: tuple = (0.0, 0.0, 0.0), emit_str: float = 0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emit_str
    return mat


def get_materials():
    # Ordered palette matching Tatra alpine winter chamois + LIALO warm storybook contrast
    return {
        "coat_mid": make_mat("CoatMid", (0.36, 0.23, 0.14), roughness=0.76),
        "coat_dark": make_mat("CoatDark", (0.11, 0.075, 0.06), roughness=0.72),
        "coat_cream": make_mat("CoatCream", (0.93, 0.87, 0.72), roughness=0.70),
        "horn_hoof": make_mat("HornHoof", (0.048, 0.044, 0.046), metallic=0.08, roughness=0.28),
        "eye_amber": make_mat("EyeAmber", (0.96, 0.68, 0.18), roughness=0.10,
                              emission=(0.95, 0.62, 0.16), emit_str=0.45),
    }


def _orthonormal_frame(tangent: Vector, up_hint: Vector = Vector((0, 0, 1))):
    t = tangent.normalized()
    if abs(t.dot(up_hint)) > 0.96:
        up_hint = Vector((1, 0, 0))
    side = t.cross(up_hint).normalized()
    up = side.cross(t).normalized()
    return t, side, up


def create_loft_mesh(name: str, sections: list, materials: list, segs: int = 16,
                     cap_start: bool = True, cap_end: bool = True,
                     face_mat_fn=None, smooth: bool = True, subsurf_levels: int = 1):
    """
    sections: list of dicts {pos: Vector, ry: float, rz: float, up_hint: Vector(opt), mat_idx: int(opt)}
    """
    bm = bmesh.new()
    rings = []
    ring_meta = []

    for idx, sec in enumerate(sections):
        pos = Vector(sec["pos"])
        if idx == 0:
            tang = Vector(sections[1]["pos"]) - pos
        elif idx == len(sections) - 1:
            tang = pos - Vector(sections[idx - 1]["pos"])
        else:
            tang = Vector(sections[idx + 1]["pos"]) - Vector(sections[idx - 1]["pos"])
        if tang.length < 1e-6:
            tang = Vector((1, 0, 0))
        _, side, up = _orthonormal_frame(tang, Vector(sec.get("up_hint", (0, 0, 1))))
        ry = float(sec["ry"])
        rz = float(sec["rz"])
        skew_z = float(sec.get("skew_z", 0.0))

        ring_verts = []
        for s in range(segs):
            ang = (s / segs) * math.tau
            cy = math.sin(ang)  # left/right along 'side'
            cz = math.cos(ang)  # up/down along 'up' (0 = top dorsal crest!)
            # Slight anatomical keel sharpening on back/belly if requested
            r_offset = side * (cy * ry) + up * (cz * rz + skew_z * (1.0 - abs(cy)))
            ring_verts.append(bm.verts.new(pos + r_offset))
        rings.append(ring_verts)
        ring_meta.append(sec)

    for i in range(len(rings) - 1):
        r0 = rings[i]
        r1 = rings[i + 1]
        for s in range(segs):
            sn = (s + 1) % segs
            f = bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
            f.smooth = smooth
            if face_mat_fn is not None:
                f.material_index = face_mat_fn(i, s, segs, f.calc_center_median(), ring_meta[i])
            else:
                f.material_index = int(ring_meta[i].get("mat_idx", 0))

    if cap_start and len(rings) > 0:
        c0 = bm.verts.new(Vector(sections[0]["pos"]))
        r0 = rings[0]
        for s in range(segs):
            sn = (s + 1) % segs
            f = bm.faces.new((c0, r0[sn], r0[s]))
            f.smooth = smooth
            if face_mat_fn is not None:
                f.material_index = face_mat_fn(0, s, segs, f.calc_center_median(), ring_meta[0])
            else:
                f.material_index = int(ring_meta[0].get("mat_idx", 0))

    if cap_end and len(rings) > 0:
        ce = bm.verts.new(Vector(sections[-1]["pos"]))
        re = rings[-1]
        for s in range(segs):
            sn = (s + 1) % segs
            f = bm.faces.new((ce, re[s], re[sn]))
            f.smooth = smooth
            if face_mat_fn is not None:
                f.material_index = face_mat_fn(len(rings) - 1, s, segs, f.calc_center_median(), ring_meta[-1])
            else:
                f.material_index = int(ring_meta[-1].get("mat_idx", 0))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    for m in materials:
        mesh.materials.append(m)

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    if subsurf_levels > 0:
        mod = obj.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = subsurf_levels
        mod.render_levels = subsurf_levels
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)

    return obj


def build_chamois_body_and_parts(mats: dict):
    mat_list = [
        mats["coat_mid"],    # 0
        mats["coat_dark"],   # 1
        mats["coat_cream"],  # 2
        mats["horn_hoof"],   # 3
        mats["eye_amber"],   # 4
    ]

    # 1. Seamless sculpted Torso -> Withers -> Arched Neck -> Sculpted Head -> Tapered Muzzle
    torso_head_sections = [
        {"pos": (-0.365, 0.0, 0.448), "ry": 0.042, "rz": 0.058, "tag": "rump"},
        {"pos": (-0.330, 0.0, 0.456), "ry": 0.078, "rz": 0.102, "tag": "rump"},
        {"pos": (-0.250, 0.0, 0.456), "ry": 0.104, "rz": 0.130, "tag": "hip"},
        {"pos": (-0.145, 0.0, 0.444), "ry": 0.092, "rz": 0.120, "tag": "loin"},
        {"pos": (-0.020, 0.0, 0.440), "ry": 0.095, "rz": 0.128, "tag": "belly"},
        {"pos": (0.105, 0.0, 0.448),  "ry": 0.106, "rz": 0.146, "tag": "rib"},
        {"pos": (0.205, 0.0, 0.470),  "ry": 0.098, "rz": 0.146, "tag": "withers", "skew_z": 0.014},
        {"pos": (0.268, 0.0, 0.520),  "ry": 0.074, "rz": 0.106, "tag": "neck_base"},
        {"pos": (0.315, 0.0, 0.588),  "ry": 0.056, "rz": 0.078, "tag": "neck"},
        {"pos": (0.356, 0.0, 0.656),  "ry": 0.048, "rz": 0.064, "tag": "neck_top"},
        {"pos": (0.388, 0.0, 0.714),  "ry": 0.054, "rz": 0.058, "tag": "cranium"},
        {"pos": (0.432, 0.0, 0.716),  "ry": 0.055, "rz": 0.056, "tag": "brow"},
        {"pos": (0.482, 0.0, 0.692),  "ry": 0.038, "rz": 0.042, "tag": "snout"},
        {"pos": (0.532, 0.0, 0.668),  "ry": 0.026, "rz": 0.028, "tag": "muzzle"},
        {"pos": (0.562, 0.0, 0.658),  "ry": 0.014, "rz": 0.016, "tag": "nose"},
    ]

    def torso_face_mat(i, s, segs, center: Vector, meta):
        # s=0 is top dorsal crest, s=segs/2 is ventral belly/throat
        ang = (s / segs) * math.tau
        up_cos = math.cos(ang)
        side_abs = abs(math.sin(ang))
        tag = meta["tag"]

        if tag in ("nose",):
            return 1  # dark muzzle nose leather
        if tag in ("muzzle", "snout"):
            # Iconic Tatra facial mask: cream muzzle/forehead with dark cheek-eye stripe
            if up_cos > 0.35 or up_cos < -0.55:
                return 2
            return 1 if side_abs > 0.62 else 2
        if tag in ("brow", "cranium"):
            if up_cos > 0.45:
                return 2  # pale forehead blaze
            if side_abs > 0.58 and up_cos > -0.35:
                return 1  # dark eye-band stripe
            return 2 if up_cos < -0.25 else 0
        if tag in ("neck", "neck_top", "neck_base"):
            if up_cos > 0.72:
                return 1  # dorsal dark mane line
            if up_cos < -0.22:
                return 2  # cream throat bib!
            return 0
        if tag in ("rump",):
            if up_cos > 0.12 and side_abs < 0.72:
                return 2  # crisp cream winter rump patch without clashing against flank
            if up_cos < -0.35:
                return 1
            return 0
        # Torso: dorsal dark ridge + dark lower flank/saddle band + rich mid-umber coat
        if up_cos > 0.80:
            return 1  # dorsal spine stripe
        if up_cos < -0.35:
            return 1  # dark winter flank/belly band
        return 0

    body_obj = create_loft_mesh(
        "TorsoHead", torso_head_sections, mat_list, segs=20,
        face_mat_fn=torso_face_mat, subsurf_levels=1
    )

    # 2. Sculpted Iconic Backward-Hooked Tatra Chamois Horns (with subtle keratin ring ridges)
    horn_objs = []
    for side_s, side_name in ((1.0, "L"), (-1.0, "R")):
        horn_pts = [
            Vector((0.415, side_s * 0.020, 0.742)),
            Vector((0.422, side_s * 0.023, 0.790)),
            Vector((0.424, side_s * 0.027, 0.842)),
            Vector((0.418, side_s * 0.032, 0.892)),
            Vector((0.398, side_s * 0.036, 0.928)),
            Vector((0.368, side_s * 0.039, 0.935)),
            Vector((0.342, side_s * 0.041, 0.916)),
            Vector((0.328, side_s * 0.042, 0.888)),
            Vector((0.326, side_s * 0.042, 0.866)),
        ]
        horn_rads = [0.0135, 0.0120, 0.0108, 0.0096, 0.0084, 0.0072, 0.0056, 0.0036, 0.0016]
        horn_secs = []
        for k, (hp, hr) in enumerate(zip(horn_pts, horn_rads)):
            ridge = 1.0 + (0.09 if (k % 2 == 1 and k < 6) else 0.0)
            horn_secs.append({
                "pos": hp, "ry": hr * 0.88 * ridge, "rz": hr * 1.06 * ridge,
                "up_hint": Vector((1, 0, 0)), "mat_idx": 3
            })
        h_obj = create_loft_mesh(
            f"Horn_{side_name}", horn_secs, mat_list, segs=12, subsurf_levels=1
        )
        horn_objs.append(h_obj)

    # 3. Alert Cupped Ears (separate left & right for ear flick bones)
    ear_objs = {}
    for side_s, side_name in ((1.0, "L"), (-1.0, "R")):
        ear_secs = [
            {"pos": (0.376, side_s * 0.042, 0.730), "ry": 0.011, "rz": 0.013, "mat_idx": 0},
            {"pos": (0.360, side_s * 0.068, 0.764), "ry": 0.015, "rz": 0.022, "mat_idx": 0},
            {"pos": (0.346, side_s * 0.092, 0.795), "ry": 0.012, "rz": 0.019, "mat_idx": 0},
            {"pos": (0.336, side_s * 0.110, 0.818), "ry": 0.004, "rz": 0.006, "mat_idx": 0},
        ]

        def ear_face_mat(_i, s, segs, _c, _m, ss=side_s):
            ang = (s / segs) * math.tau
            # Front-inner ear face is cream
            return 2 if math.cos(ang) < -0.25 else 0

        e_obj = create_loft_mesh(
            f"Ear_{side_name}", ear_secs, mat_list, segs=10,
            face_mat_fn=ear_face_mat, subsurf_levels=1
        )
        ear_objs[side_name] = e_obj

    # 4. Expressive Amber Eyes
    eye_objs = []
    for side_s, side_name in ((1.0, "L"), (-1.0, "R")):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.0115)
        for f in bm.faces:
            f.smooth = True
            f.material_index = 4
        m = bpy.data.meshes.new(f"Eye_{side_name}_M")
        bm.to_mesh(m)
        bm.free()
        for mt in mat_list:
            m.materials.append(mt)
        eo = bpy.data.objects.new(f"Eye_{side_name}", m)
        eo.location = (0.448, side_s * 0.044, 0.716)
        eo.scale = (1.05, 0.72, 1.0)
        bpy.context.scene.collection.objects.link(eo)
        eye_objs.append(eo)

    # 5. Short Tufted Tail
    tail_secs = [
        {"pos": (-0.345, 0.0, 0.468), "ry": 0.020, "rz": 0.020, "mat_idx": 1},
        {"pos": (-0.388, 0.0, 0.486), "ry": 0.018, "rz": 0.018, "mat_idx": 1},
        {"pos": (-0.424, 0.0, 0.506), "ry": 0.008, "rz": 0.009, "mat_idx": 1},
    ]
    tail_obj = create_loft_mesh("Tail", tail_secs, mat_list, segs=10, subsurf_levels=1)

    # 6. Four Articulated Tapered Legs (resting cleanly on Z = 0.0)
    leg_objs = {}
    for side_s, side_name in ((1.0, "L"), (-1.0, "R")):
        # Front leg (upper shoulder tucked seamlessly into ribcage -> tapered forearm -> dark cannon -> hoof)
        fl_secs = [
            {"pos": (0.185, side_s * 0.048, 0.455), "ry": 0.044, "rz": 0.064, "up_hint": (1, 0, 0), "mat_idx": 0},
            {"pos": (0.200, side_s * 0.062, 0.380), "ry": 0.036, "rz": 0.052, "up_hint": (1, 0, 0), "mat_idx": 0},
            {"pos": (0.215, side_s * 0.068, 0.305), "ry": 0.027, "rz": 0.036, "up_hint": (1, 0, 0), "mat_idx": 0},
            {"pos": (0.228, side_s * 0.068, 0.220), "ry": 0.020, "rz": 0.023, "up_hint": (1, 0, 0), "mat_idx": 1},
            {"pos": (0.232, side_s * 0.068, 0.125), "ry": 0.014, "rz": 0.017, "up_hint": (1, 0, 0), "mat_idx": 1},
            {"pos": (0.236, side_s * 0.068, 0.048), "ry": 0.015, "rz": 0.018, "up_hint": (1, 0, 0), "mat_idx": 1},
            {"pos": (0.252, side_s * 0.068, 0.018), "ry": 0.017, "rz": 0.022, "up_hint": (1, 0, 0), "mat_idx": 3},
            {"pos": (0.264, side_s * 0.068, 0.000), "ry": 0.016, "rz": 0.020, "up_hint": (1, 0, 0), "mat_idx": 3},
        ]
        leg_objs[f"Front_{side_name}"] = create_loft_mesh(
            f"LegFront_{side_name}", fl_secs, mat_list, segs=12, subsurf_levels=1
        )

        # Hind leg (muscular haunch nested smoothly into hip -> chamois hock angle -> slender cannon -> hoof)
        hl_secs = [
            {"pos": (-0.235, side_s * 0.052, 0.460), "ry": 0.048, "rz": 0.072, "up_hint": (1, 0, 0), "mat_idx": 0},
            {"pos": (-0.220, side_s * 0.066, 0.390), "ry": 0.040, "rz": 0.060, "up_hint": (1, 0, 0), "mat_idx": 0},
            {"pos": (-0.208, side_s * 0.072, 0.320), "ry": 0.032, "rz": 0.044, "up_hint": (1, 0, 0), "mat_idx": 0},
            {"pos": (-0.295, side_s * 0.070, 0.215), "ry": 0.022, "rz": 0.026, "up_hint": (1, 0, 0), "mat_idx": 1},
            {"pos": (-0.282, side_s * 0.070, 0.120), "ry": 0.014, "rz": 0.017, "up_hint": (1, 0, 0), "mat_idx": 1},
            {"pos": (-0.268, side_s * 0.070, 0.046), "ry": 0.015, "rz": 0.018, "up_hint": (1, 0, 0), "mat_idx": 1},
            {"pos": (-0.252, side_s * 0.070, 0.018), "ry": 0.017, "rz": 0.022, "up_hint": (1, 0, 0), "mat_idx": 3},
            {"pos": (-0.240, side_s * 0.070, 0.000), "ry": 0.016, "rz": 0.020, "up_hint": (1, 0, 0), "mat_idx": 3},
        ]
        leg_objs[f"Hind_{side_name}"] = create_loft_mesh(
            f"LegHind_{side_name}", hl_secs, mat_list, segs=12, subsurf_levels=1
        )

    return body_obj, horn_objs, ear_objs, eye_objs, tail_obj, leg_objs


def create_rig_and_bind(body_obj, horn_objs, ear_objs, eye_objs, tail_obj, leg_objs):
    arm_data = bpy.data.armatures.new("ChamoisArmature")
    arm_obj = bpy.data.objects.new("ChamoisRig", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    eb = arm_data.edit_bones
    bone_defs = [
        ("Root",         None,         (0.00, 0.0, 0.00), (0.00, 0.0, 0.22)),
        ("Pelvis",       "Root",       (-0.22, 0.0, 0.44), (-0.08, 0.0, 0.44)),
        ("Spine",        "Pelvis",     (-0.08, 0.0, 0.44), (0.10, 0.0, 0.45)),
        ("Chest",        "Spine",      (0.10, 0.0, 0.45),  (0.24, 0.0, 0.47)),
        ("Neck",         "Chest",      (0.25, 0.0, 0.49),  (0.38, 0.0, 0.69)),
        ("Head",         "Neck",       (0.38, 0.0, 0.69),  (0.54, 0.0, 0.67)),
        ("Tail",         "Pelvis",     (-0.34, 0.0, 0.468), (-0.43, 0.0, 0.51)),
        ("EarL",         "Head",       (0.376, 0.042, 0.730), (0.336, 0.110, 0.818)),
        ("EarR",         "Head",       (0.376, -0.042, 0.730), (0.336, -0.110, 0.818)),
        ("FrontUpperL",  "Chest",      (0.210, 0.073, 0.430), (0.228, 0.072, 0.225)),
        ("FrontLowerL",  "FrontUpperL",(0.228, 0.072, 0.225), (0.236, 0.070, 0.048)),
        ("FrontHoofL",   "FrontLowerL",(0.236, 0.070, 0.048), (0.268, 0.070, 0.000)),
        ("FrontUpperR",  "Chest",      (0.210, -0.073, 0.430), (0.228, -0.072, 0.225)),
        ("FrontLowerR",  "FrontUpperR",(0.228, -0.072, 0.225), (0.236, -0.070, 0.048)),
        ("FrontHoofR",   "FrontLowerR",(0.236, -0.070, 0.048), (0.268, -0.070, 0.000)),
        ("HindUpperL",   "Pelvis",     (-0.235, 0.078, 0.440), (-0.295, 0.074, 0.215)),
        ("HindLowerL",   "HindUpperL", (-0.295, 0.074, 0.215), (-0.268, 0.072, 0.046)),
        ("HindHoofL",    "HindLowerL", (-0.268, 0.072, 0.046), (-0.238, 0.072, 0.000)),
        ("HindUpperR",   "Pelvis",     (-0.235, -0.078, 0.440), (-0.295, -0.074, 0.215)),
        ("HindLowerR",   "HindUpperR", (-0.295, -0.074, 0.215), (-0.268, -0.072, 0.046)),
        ("HindHoofR",    "HindLowerR", (-0.268, -0.072, 0.046), (-0.238, -0.072, 0.000)),
    ]

    created_bones = {}
    for bname, pname, head, tail in bone_defs:
        b = eb.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if pname:
            b.parent = created_bones[pname]
        # Align bone local +Z toward world +Y (left) so Z rotation pitches cleanly in sagittal X-Z plane
        b.align_roll(Vector((0.0, 1.0, 0.0)))
        created_bones[bname] = b

    bpy.ops.object.mode_set(mode="OBJECT")

    # Assign deterministic per-part vertex groups BEFORE joining so zero weights leak across parts
    def add_vg_weights(obj, weights_fn):
        for bname, _, _, _ in bone_defs:
            if bname not in obj.vertex_groups:
                obj.vertex_groups.new(name=bname)
        for v in obj.data.vertices:
            w_dict = weights_fn(obj.matrix_world @ v.co)
            tot = sum(max(0.0, val) for val in w_dict.values())
            if tot <= 1e-6:
                w_dict = {"Chest": 1.0}
                tot = 1.0
            for bname, val in w_dict.items():
                if val > 1e-4:
                    obj.vertex_groups[bname].add([v.index], val / tot, "REPLACE")

    def smooth_ramp(val, a, b):
        t = max(0.0, min(1.0, (val - a) / (b - a)))
        return t * t * (3.0 - 2.0 * t)

    def torso_weights(p: Vector):
        # Z-dominant neck/head above shoulders, X-blended spine along back
        if p.z > 0.505 and p.x > 0.21:
            t_nh = smooth_ramp(p.z, 0.64, 0.71)
            t_cn = smooth_ramp(p.z, 0.49, 0.56)
            w_head = t_nh
            w_neck = t_cn * (1.0 - t_nh)
            w_chest = (1.0 - t_cn)
            return {"Chest": w_chest, "Neck": w_neck, "Head": w_head}
        if p.x < -0.10:
            t = smooth_ramp(p.x, -0.18, -0.02)
            return {"Pelvis": 1.0 - t, "Spine": t}
        if p.x < 0.12:
            t = smooth_ramp(p.x, 0.04, 0.18)
            return {"Spine": 1.0 - t, "Chest": t}
        return {"Chest": 1.0}

    add_vg_weights(body_obj, torso_weights)
    for ho in horn_objs:
        add_vg_weights(ho, lambda _p: {"Head": 1.0})
    for eo in eye_objs:
        add_vg_weights(eo, lambda _p: {"Head": 1.0})
    add_vg_weights(ear_objs["L"], lambda _p: {"EarL": 1.0})
    add_vg_weights(ear_objs["R"], lambda _p: {"EarR": 1.0})
    add_vg_weights(tail_obj, lambda p: {
        "Pelvis": 1.0 - smooth_ramp(p.x, -0.37, -0.34),
        "Tail": smooth_ramp(-p.x, 0.34, 0.38),
    })

    for side_name in ("L", "R"):
        def front_w(p: Vector, s=side_name):
            t_socket = smooth_ramp(p.z, 0.36, 0.45)
            t_up_lo = 1.0 - smooth_ramp(p.z, 0.19, 0.26)
            t_lo_hf = 1.0 - smooth_ramp(p.z, 0.032, 0.068)
            w_leg = 1.0 - t_socket * 0.72
            w_up = (1.0 - t_up_lo) * w_leg
            w_lo = t_up_lo * (1.0 - t_lo_hf) * w_leg
            w_hf = t_up_lo * t_lo_hf * w_leg
            return {"Chest": t_socket * 0.72, f"FrontUpper{s}": w_up, f"FrontLower{s}": w_lo, f"FrontHoof{s}": w_hf}

        def hind_w(p: Vector, s=side_name):
            t_socket = smooth_ramp(p.z, 0.37, 0.46)
            t_up_lo = 1.0 - smooth_ramp(p.z, 0.18, 0.25)
            t_lo_hf = 1.0 - smooth_ramp(p.z, 0.032, 0.068)
            w_leg = 1.0 - t_socket * 0.72
            w_up = (1.0 - t_up_lo) * w_leg
            w_lo = t_up_lo * (1.0 - t_lo_hf) * w_leg
            w_hf = t_up_lo * t_lo_hf * w_leg
            return {"Pelvis": t_socket * 0.72, f"HindUpper{s}": w_up, f"HindLower{s}": w_lo, f"HindHoof{s}": w_hf}

        add_vg_weights(leg_objs[f"Front_{side_name}"], front_w)
        add_vg_weights(leg_objs[f"Hind_{side_name}"], hind_w)

    # Join all parts into one clean skinned mesh
    all_parts = [
        body_obj, *horn_objs, ear_objs["L"], ear_objs["R"], *eye_objs, tail_obj,
        leg_objs["Front_L"], leg_objs["Front_R"], leg_objs["Hind_L"], leg_objs["Hind_R"],
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for part in all_parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = body_obj
    bpy.ops.object.join()
    body_obj.name = "ChamoisBodyMesh"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Parent mesh to Armature & bind modifier
    body_obj.parent = arm_obj
    arm_mod = body_obj.modifiers.new("Armature", "ARMATURE")
    arm_mod.object = arm_obj
    return arm_obj, body_obj


def _set_pose_keys(arm_obj, act, pose_table: dict):
    """
    pose_table: {frame_int: {bone_name: {"rot": (rx, ry, rz)_deg, "loc": (lx, ly, lz) opt}}}
    """
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = act

    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"

    # Reset all pose bones before keying each frame
    frames = sorted(pose_table.keys())
    for fr in frames:
        for pb in arm_obj.pose.bones:
            pb.location = (0.0, 0.0, 0.0)
            pb.rotation_euler = (0.0, 0.0, 0.0)
        frame_pose = pose_table[fr]
        for bname, vals in frame_pose.items():
            pb = arm_obj.pose.bones[bname]
            if "loc" in vals:
                pb.location = vals["loc"]
                pb.keyframe_insert("location", frame=fr)
            if "rot" in vals:
                rx, ry, rz = vals["rot"]
                pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
                pb.keyframe_insert("rotation_euler", frame=fr)

    slot = arm_obj.animation_data.action_slot
    cb = anim_utils.action_get_channelbag_for_slot(act, slot)
    if cb:
        for fc in cb.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"
    return slot


def author_animations(arm_obj):
    # Check sagittal pitch sign: since roll was aligned to +Y (left), rotating +Z swings tail forward (+X) or back (-X)?
    # Let's check: bone points roughly +X or -Z; right-hand rule around +Y:
    # +rot around +Y maps +Z -> +X, and +X -> -Z!
    # Wait: for downward leg bone (tail below head -> bone +Y points -Z):
    # Right-hand rule around +Y (bone local +Z): +angle rotates bone -Z toward -X (BACKWARD)!
    # And -angle rotates leg forward (+X)!
    # For forward-pointing torso/neck/head (bone +Y points +X/+Z):
    # +angle pitches nose DOWN, -angle lifts nose UP!

    # 1. LeapCycle (frames 1..36 = 1.20s @ 30fps): athletic mountain chamois bounding leap!
    leap_pose_start = {
        "Pelvis":      {"loc": (0.0, 0.0, -0.045), "rot": (0, 0, -14)},
        "Spine":       {"rot": (0, 0, -8)},
        "Chest":       {"rot": (0, 0, -6)},
        "Neck":        {"rot": (0, 0, 12)},
        "Head":        {"rot": (0, 0, 14)},
        "Tail":        {"rot": (0, 0, -18)},
        "EarL":        {"rot": (0, 0, -6)},
        "EarR":        {"rot": (0, 0, -6)},
        # Coiled hind springs ready to push off, front legs gathering under chest
        "HindUpperL":  {"rot": (0, 0, -34)},
        "HindLowerL":  {"rot": (0, 0, 56)},
        "HindHoofL":   {"rot": (0, 0, -20)},
        "HindUpperR":  {"rot": (0, 0, -28)},
        "HindLowerR":  {"rot": (0, 0, 48)},
        "HindHoofR":   {"rot": (0, 0, -18)},
        "FrontUpperL": {"rot": (0, 0, 26)},
        "FrontLowerL": {"rot": (0, 0, 48)},
        "FrontHoofL":  {"rot": (0, 0, 18)},
        "FrontUpperR": {"rot": (0, 0, 18)},
        "FrontLowerR": {"rot": (0, 0, 42)},
        "FrontHoofR":  {"rot": (0, 0, 14)},
    }
    leap_launch = {
        "Pelvis":      {"loc": (0.0, 0.0, 0.050), "rot": (0, 0, -20)},
        "Spine":       {"rot": (0, 0, -4)},
        "Chest":       {"rot": (0, 0, -6)},
        "Neck":        {"rot": (0, 0, 10)},
        "Head":        {"rot": (0, 0, 8)},
        "Tail":        {"rot": (0, 0, 12)},
        "EarL":        {"rot": (0, 0, 8)},
        "EarR":        {"rot": (0, 0, 8)},
        # Explosive hind push + front knees tucked forward-up
        "HindUpperL":  {"rot": (0, 0, 44)},
        "HindLowerL":  {"rot": (0, 0, -18)},
        "HindHoofL":   {"rot": (0, 0, 22)},
        "HindUpperR":  {"rot": (0, 0, 38)},
        "HindLowerR":  {"rot": (0, 0, -14)},
        "HindHoofR":   {"rot": (0, 0, 18)},
        "FrontUpperL": {"rot": (0, 0, -68)},
        "FrontLowerL": {"rot": (0, 0, 108)},
        "FrontHoofL":  {"rot": (0, 0, 24)},
        "FrontUpperR": {"rot": (0, 0, -56)},
        "FrontLowerR": {"rot": (0, 0, 96)},
        "FrontHoofR":  {"rot": (0, 0, 20)},
    }
    leap_apex = {
        "Pelvis":      {"loc": (0.0, 0.0, 0.145), "rot": (0, 0, 2)},
        "Spine":       {"rot": (0, 0, 8)},
        "Chest":       {"rot": (0, 0, -6)},
        "Neck":        {"rot": (0, 0, -10)},
        "Head":        {"rot": (0, 0, -6)},
        "Tail":        {"rot": (0, 0, 20)},
        "EarL":        {"rot": (0, 0, 12)},
        "EarR":        {"rot": (0, 0, 12)},
        # Classic heroic mid-air stretch: front legs reaching boldly forward, hind legs trailing back!
        "HindUpperL":  {"rot": (0, 0, 66)},
        "HindLowerL":  {"rot": (0, 0, 8)},
        "HindHoofL":   {"rot": (0, 0, 24)},
        "HindUpperR":  {"rot": (0, 0, 56)},
        "HindLowerR":  {"rot": (0, 0, 16)},
        "HindHoofR":   {"rot": (0, 0, 20)},
        "FrontUpperL": {"rot": (0, 0, -82)},
        "FrontLowerL": {"rot": (0, 0, 34)},
        "FrontHoofL":  {"rot": (0, 0, 18)},
        "FrontUpperR": {"rot": (0, 0, -70)},
        "FrontLowerR": {"rot": (0, 0, 46)},
        "FrontHoofR":  {"rot": (0, 0, 18)},
    }
    leap_land = {
        "Pelvis":      {"loc": (0.0, 0.0, 0.005), "rot": (0, 0, 18)},
        "Spine":       {"rot": (0, 0, -4)},
        "Chest":       {"rot": (0, 0, -10)},
        "Neck":        {"rot": (0, 0, 6)},
        "Head":        {"rot": (0, 0, 10)},
        "Tail":        {"rot": (0, 0, -8)},
        "EarL":        {"rot": (0, 0, 0)},
        "EarR":        {"rot": (0, 0, 0)},
        # Front hooves reaching down for touchdown while hind legs sweep under
        "HindUpperL":  {"rot": (0, 0, 10)},
        "HindLowerL":  {"rot": (0, 0, 38)},
        "HindHoofL":   {"rot": (0, 0, 8)},
        "HindUpperR":  {"rot": (0, 0, 4)},
        "HindLowerR":  {"rot": (0, 0, 34)},
        "HindHoofR":   {"rot": (0, 0, 6)},
        "FrontUpperL": {"rot": (0, 0, -30)},
        "FrontLowerL": {"rot": (0, 0, 14)},
        "FrontHoofL":  {"rot": (0, 0, -8)},
        "FrontUpperR": {"rot": (0, 0, -20)},
        "FrontLowerR": {"rot": (0, 0, 20)},
        "FrontHoofR":  {"rot": (0, 0, -4)},
    }

    act_leap = bpy.data.actions.new("LeapCycle")
    act_leap.use_fake_user = True
    slot_leap = _set_pose_keys(arm_obj, act_leap, {
        1: leap_pose_start,
        10: leap_launch,
        20: leap_apex,
        29: leap_land,
        36: leap_pose_start,
    })

    # 2. RidgeStand (frames 1..48 = 1.60s @ 30fps): noble mountain lookout idle + alert ear flick
    stand_a = {
        "Pelvis": {"loc": (0.0, 0.0, 0.0), "rot": (0, 0, 0)},
        "Spine":  {"rot": (0, 0, 0)},
        "Chest":  {"rot": (0, 0, 0)},
        "Neck":   {"rot": (0, 0, -3)},
        "Head":   {"rot": (0, -4, 2)},
        "EarL":   {"rot": (0, 0, 0)},
        "EarR":   {"rot": (0, 0, 0)},
        "Tail":   {"rot": (0, 0, 0)},
        "FrontUpperL": {"rot": (0, 0, 0)}, "FrontLowerL": {"rot": (0, 0, 0)}, "FrontHoofL": {"rot": (0, 0, 0)},
        "FrontUpperR": {"rot": (0, 0, 0)}, "FrontLowerR": {"rot": (0, 0, 0)}, "FrontHoofR": {"rot": (0, 0, 0)},
        "HindUpperL":  {"rot": (0, 0, 0)}, "HindLowerL":  {"rot": (0, 0, 0)}, "HindHoofL":  {"rot": (0, 0, 0)},
        "HindUpperR":  {"rot": (0, 0, 0)}, "HindLowerR":  {"rot": (0, 0, 0)}, "HindHoofR":  {"rot": (0, 0, 0)},
    }
    stand_b = {
        "Pelvis": {"loc": (0.0, 0.0, 0.008), "rot": (0, 0, 1.5)},
        "Spine":  {"rot": (0, 0, -1.5)},
        "Chest":  {"rot": (0, 0, 1.5)},
        "Neck":   {"rot": (0, 5, -6)},
        "Head":   {"rot": (0, 9, -2)},
        "EarL":   {"rot": (4, 0, -10)},
        "EarR":   {"rot": (-4, 0, 6)},
        "Tail":   {"rot": (0, 0, 8)},
        "FrontUpperL": {"rot": (0, 0, -2)}, "FrontLowerL": {"rot": (0, 0, 2)}, "FrontHoofL": {"rot": (0, 0, 0)},
        "FrontUpperR": {"rot": (0, 0, -2)}, "FrontLowerR": {"rot": (0, 0, 2)}, "FrontHoofR": {"rot": (0, 0, 0)},
        "HindUpperL":  {"rot": (0, 0, 2)},  "HindLowerL":  {"rot": (0, 0, -2)}, "HindHoofL": {"rot": (0, 0, 0)},
        "HindUpperR":  {"rot": (0, 0, 2)},  "HindLowerR":  {"rot": (0, 0, -2)}, "HindHoofR": {"rot": (0, 0, 0)},
    }
    act_stand = bpy.data.actions.new("RidgeStand")
    act_stand.use_fake_user = True
    slot_stand = _set_pose_keys(arm_obj, act_stand, {
        1: stand_a,
        24: stand_b,
        48: stand_a,
    })

    # Push both actions onto NLA tracks so glTF exporter exports both cleanly
    arm_obj.animation_data.action = None
    for tr_name, act, slot, end_fr in (
        ("LeapCycle", act_leap, slot_leap, 36),
        ("RidgeStand", act_stand, slot_stand, 48),
    ):
        tr = arm_obj.animation_data.nla_tracks.new()
        tr.name = tr_name
        strip = tr.strips.new(tr_name, 1, act)
        strip.action_frame_start = 1
        strip.action_frame_end = end_fr
        if hasattr(strip, "action_slot") and slot is not None:
            strip.action_slot = slot
        tr.mute = False

    return act_leap, act_stand


def export_chamois_glb(arm_obj, body_obj):
    bpy.ops.object.select_all(action="DESELECT")
    arm_obj.select_set(True)
    body_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    OUT_GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
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
    print("EXPORTED_CHAMOIS_GLB=", OUT_GLB)


def render_preview_sheet(scene, arm_obj, act_leap, act_stand):
    # Switch cleanly to evaluate LeapCycle at mid-air apex (frame 20) vs RidgeStand
    # Create a cozy mountain sunrise studio render showing 3 angles + mid-leap pose
    scene.world = bpy.data.worlds.new("ChamoisPreviewWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.14, 0.12, 0.11, 1.0)

    # Set up studio lighting
    l_key = bpy.data.lights.new("SunKey", "SUN")
    l_key.energy = 3.2
    l_key.color = (1.0, 0.90, 0.72)
    o_key = bpy.data.objects.new("SunKey", l_key)
    o_key.rotation_euler = (math.radians(52), math.radians(15), math.radians(38))
    scene.collection.objects.link(o_key)

    l_rim = bpy.data.lights.new("Rim", "AREA")
    l_rim.energy = 160.0
    l_rim.size = 2.0
    l_rim.color = (1.0, 0.78, 0.42)
    o_rim = bpy.data.objects.new("Rim", l_rim)
    o_rim.location = (-0.8, 1.2, 1.4)
    o_rim.rotation_euler = (Vector((0.1, 0.0, 0.5)) - o_rim.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o_rim)

    # Clear NLA temporarily on duplicate visual preview scene by setting active action on arm_obj
    arm_obj.animation_data.nla_tracks[0].mute = True
    arm_obj.animation_data.nla_tracks[1].mute = True

    # Place a snowy pedestal rock slab under standing view
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=4, y_segments=4, size=1.4)
    plinth_m = bpy.data.meshes.new("SnowPlinthM")
    bm.to_mesh(plinth_m)
    bm.free()
    plinth_mat = make_mat("SnowPlinthMat", (0.86, 0.85, 0.82), roughness=0.85)
    plinth_m.materials.append(plinth_mat)
    plinth = bpy.data.objects.new("SnowPlinth", plinth_m)
    scene.collection.objects.link(plinth)

    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 48.0
    cam_o = bpy.data.objects.new("PreviewCam", cam_d)
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Render 1: Side / 3-quarter Mid-Leap Apex hero pose
    arm_obj.animation_data.action = act_leap
    scene.frame_set(20)
    bpy.context.view_layer.update()
    cam_o.location = (0.12, -2.08, 0.72)
    cam_o.rotation_euler = (Vector((0.08, 0.0, 0.56)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    tmp_leap = PREVIEW_PATH.parent / "_chamois_leap.png"
    scene.render.filepath = str(tmp_leap)
    bpy.ops.render.render(write_still=True)

    # Render 2: Side-front 3/4 Standing lookout pose
    arm_obj.animation_data.action = act_stand
    scene.frame_set(18)
    bpy.context.view_layer.update()
    cam_o.location = (1.28, -1.68, 0.76)
    cam_o.rotation_euler = (Vector((0.08, 0.0, 0.48)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    tmp_stand = PREVIEW_PATH.parent / "_chamois_stand.png"
    scene.render.filepath = str(tmp_stand)
    bpy.ops.render.render(write_still=True)

    # Combine side-by-side in Blender compositor or Python image buffer
    img1 = bpy.data.images.load(str(tmp_leap))
    img2 = bpy.data.images.load(str(tmp_stand))
    w, h = img1.size
    out_img = bpy.data.images.new("ContactSheet", width=w * 2, height=h, alpha=False)
    p1 = list(img1.pixels[:])
    p2 = list(img2.pixels[:])
    row_stride_in = w * 4
    row_stride_out = (w * 2) * 4
    combined = [0.0] * (w * 2 * h * 4)
    for y in range(h):
        in_off = y * row_stride_in
        out_off = y * row_stride_out
        combined[out_off : out_off + row_stride_in] = p1[in_off : in_off + row_stride_in]
        combined[out_off + row_stride_in : out_off + row_stride_out] = p2[in_off : in_off + row_stride_in]
    out_img.pixels.foreach_set(combined)
    out_img.filepath_raw = str(PREVIEW_PATH)
    out_img.file_format = "PNG"
    out_img.save()
    print("RENDERED_CHAMOIS_PREVIEW=", PREVIEW_PATH)


def main():
    scene = reset_scene()
    mats = get_materials()
    body_obj, horn_objs, ear_objs, eye_objs, tail_obj, leg_objs = build_chamois_body_and_parts(mats)
    arm_obj, skinned_mesh = create_rig_and_bind(body_obj, horn_objs, ear_objs, eye_objs, tail_obj, leg_objs)
    act_leap, act_stand = author_animations(arm_obj)
    export_chamois_glb(arm_obj, skinned_mesh)
    render_preview_sheet(scene, arm_obj, act_leap, act_stand)


if __name__ == "__main__":
    main()
