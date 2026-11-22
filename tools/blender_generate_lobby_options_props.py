"""
Blender 5.3 headless 3D prop generator for LIALO Immersive 3D Lobby Settings:
Generates 6 detailed tavern-study desk props with preserved animated child nodes
in D:/downpour-godot/assets/models/lobby_options/*.glb:
  1. settings_desk_ledger.glb     (Open leather codex, parchment pages, bookmark, inkwell & quill)
  2. settings_brass_dial.glb      (Walnut base, brass scale ticks + DialKnob child)
  3. settings_wax_stamp.glb       (Oak coaster, wax disc + StampHandle child)
  4. settings_lantern_prism.glb   (Wrought-iron/brass filigree lantern + LanternCore child)
  5. settings_hourglass.glb       (Brass gimbal cradle + HourglassBody child for 180° flip)
  6. settings_gramophone_bell.glb (Mahogany plinth, acoustic elbow + BellHorn child)

Run via:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_lobby_options_props.py
"""
import math
import pathlib
import bpy
import bmesh
from mathutils import Vector, Euler

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_DIR = ROOT / "assets" / "models" / "lobby_options"
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a7664877-b33a-48d0-8658-be5de670b3ca\scratch\lobby_options_props_preview.png"
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    return scene


def make_mat(name: str, color: tuple, metallic: float = 0.0, roughness: float = 0.5,
             emission: tuple = (0.0, 0.0, 0.0), emit_str: float = 0.0, alpha: float = 1.0):
    mat = bpy.data.materials.new(name)
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
    # Values are linear RGB so sRGB glTF/Godot & Blender EEVEE render rich dark tavern oak, brass & crimson wax
    return {
        "oak":        make_mat("Oak",        (0.11, 0.055, 0.025), roughness=0.62),
        "walnut":     make_mat("Walnut",     (0.048, 0.024, 0.013), roughness=0.55),
        "mahogany":   make_mat("Mahogany",   (0.095, 0.024, 0.016), roughness=0.44),
        "leather":    make_mat("Leather",    (0.075, 0.022, 0.016), roughness=0.66),
        "parchment":  make_mat("Parchment",  (0.84, 0.74, 0.54), roughness=0.76),
        "ink_line":   make_mat("InkLine",    (0.04, 0.03, 0.025), roughness=0.80),
        "brass":      make_mat("Brass",      (0.76, 0.52, 0.14), metallic=0.90, roughness=0.25),
        "gold":       make_mat("Gold",       (0.92, 0.68, 0.16), metallic=0.94, roughness=0.20),
        "iron":       make_mat("Iron",       (0.07, 0.072, 0.082), metallic=0.82, roughness=0.36),
        "wax_red":    make_mat("WaxRed",     (0.42, 0.026, 0.028), roughness=0.34),
        "ribbon":     make_mat("Ribbon",     (0.46, 0.032, 0.038), roughness=0.60),
        "glass":      make_mat("Glass",      (0.82, 0.90, 0.96), roughness=0.10, alpha=0.34),
        "sand":       make_mat("GoldSand",   (0.88, 0.62, 0.18), roughness=0.70,
                               emission=(0.95, 0.70, 0.22), emit_str=0.32),
        "prism_core": make_mat("PrismCore",  (1.0, 0.74, 0.28), roughness=0.14,
                               emission=(1.0, 0.74, 0.26), emit_str=2.2),
        "quill":      make_mat("Quill",      (0.88, 0.82, 0.68), roughness=0.62),
        "obsidian":   make_mat("Obsidian",   (0.025, 0.025, 0.032), metallic=0.18, roughness=0.22),
    }


def _link_bm(parent, name: str, bm: bmesh.types.BMesh, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    for f in bm.faces:
        f.smooth = smooth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = bpy.data.meshes.new(name + "_M")
    bm.to_mesh(m)
    bm.free()
    m.materials.append(mat)
    o = bpy.data.objects.new(name, m)
    o.location = loc
    o.rotation_euler = Euler((math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])))
    bpy.context.scene.collection.objects.link(o)
    o.parent = parent
    return o


def add_box(parent, name, size, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel_amt=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel_amt > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel_amt, segments=2, affect="EDGES")
    return _link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=(bevel_amt > 0.0))


def add_cyl(parent, name, r1, r2, h, mat, segs=24, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
    return _link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_lathe(parent, name, profile_rz: list, mat, segs=24, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    """profile_rz: list of (radius, z) from bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, z in profile_rz:
        if r <= 1e-5:
            r = 1e-4
        ring = []
        for s in range(segs):
            a = (s / segs) * math.tau
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segs):
            sn = (s + 1) % segs
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    # Cap bottom & top
    c_bot = bm.verts.new((0, 0, profile_rz[0][1]))
    c_top = bm.verts.new((0, 0, profile_rz[-1][1]))
    for s in range(segs):
        sn = (s + 1) % segs
        bm.faces.new((c_bot, rings[0][sn], rings[0][s]))
        bm.faces.new((c_top, rings[-1][s], rings[-1][sn]))
    return _link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_tube(parent, name, pts: list, rads: list, mat, segs=12):
    bm = bmesh.new()
    rings = []
    for idx, (pt, rad) in enumerate(zip(pts, rads)):
        p = Vector(pt)
        if idx == 0:
            t = (Vector(pts[1]) - p).normalized()
        elif idx == len(pts) - 1:
            t = (p - Vector(pts[idx - 1])).normalized()
        else:
            t = (Vector(pts[idx + 1]) - Vector(pts[idx - 1])).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < 0.94 else Vector((1, 0, 0))
        side = t.cross(up).normalized()
        binorm = side.cross(t).normalized()
        ring = []
        for s in range(segs):
            a = (s / segs) * math.tau
            ring.append(bm.verts.new(p + side * (math.cos(a) * rad) + binorm * (math.sin(a) * rad)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segs):
            sn = (s + 1) % segs
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    # Cap ends
    c0 = bm.verts.new(Vector(pts[0]))
    ce = bm.verts.new(Vector(pts[-1]))
    for s in range(segs):
        sn = (s + 1) % segs
        bm.faces.new((c0, rings[0][sn], rings[0][s]))
        bm.faces.new((ce, rings[-1][s], rings[-1][sn]))
    return _link_bm(parent, name, bm, mat, smooth=True)


def export_glb(root, filepath: pathlib.Path):
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
    print(f"EXPORTED_PROP_GLB={filepath.name}")


# =============================================================================
# 1. OPEN TAVERN CODEX / DESK LEDGER + INKWELL & QUILL
# =============================================================================
def build_desk_ledger(M):
    root = bpy.data.objects.new("DeskLedgerRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # Sloped carved oak lectern base
    add_box(root, "LecternBase", (0.56, 0.34, 0.022), M["walnut"], loc=(0, 0, 0.011), bevel_amt=0.005)
    add_box(root, "LecternSlope", (0.52, 0.30, 0.018), M["oak"], loc=(0, -0.01, 0.052), rot=(18, 0, 0), bevel_amt=0.004)
    add_box(root, "LecternLip", (0.52, 0.024, 0.028), M["brass"], loc=(0, -0.155, 0.024), rot=(18, 0, 0), bevel_amt=0.003)

    # Leather covers angled open
    tilted_holder = bpy.data.objects.new("BookTilt", None)
    bpy.context.scene.collection.objects.link(tilted_holder)
    tilted_holder.parent = root
    tilted_holder.location = (0, -0.01, 0.068)
    tilted_holder.rotation_euler = Euler((math.radians(18), 0, 0))

    add_box(tilted_holder, "SpineLeather", (0.048, 0.275, 0.014), M["leather"], loc=(0, 0, 0.002), bevel_amt=0.003)
    for sx, ang in ((-1.0, 7.0), (1.0, -7.0)):
        add_box(tilted_holder, f"Cover_{int(sx)}", (0.225, 0.275, 0.010), M["leather"],
                loc=(sx * 0.122, 0, 0.014), rot=(0, ang, 0), bevel_amt=0.002)
        # Brass corner guards
        for cy in (-0.126, 0.126):
            add_box(tilted_holder, f"Corner_{int(sx)}_{int(cy*10)}", (0.032, 0.028, 0.014), M["brass"],
                    loc=(sx * 0.220, cy, 0.026), rot=(0, ang, 0), bevel_amt=0.002)

        # Curved fanned parchment page stack
        bm = bmesh.new()
        cols = 8
        rows = 4
        verts_top = []
        verts_bot = []
        for r in range(rows + 1):
            y = -0.128 + (r / rows) * 0.256
            vt_row, vb_row = [], []
            for c in range(cols + 1):
                u = c / cols  # 0 at spine, 1 at outer page edge
                px = sx * (0.012 + u * 0.205)
                arch = math.sin(u * math.pi) * 0.026 + (0.008 * u)
                pz_top = 0.032 + arch + (u * -math.sin(math.radians(7.0)) * 0.18 if False else 0.0)
                pz_bot = 0.012 + u * 0.016
                vt_row.append(bm.verts.new((px, y, pz_top)))
                vb_row.append(bm.verts.new((px, y, pz_bot)))
            verts_top.append(vt_row)
            verts_bot.append(vb_row)
        for r in range(rows):
            for c in range(cols):
                if sx > 0:
                    bm.faces.new((verts_top[r][c], verts_top[r][c+1], verts_top[r+1][c+1], verts_top[r+1][c]))
                    bm.faces.new((verts_bot[r][c], verts_bot[r+1][c], verts_bot[r+1][c+1], verts_bot[r][c+1]))
                else:
                    bm.faces.new((verts_top[r][c], verts_top[r+1][c], verts_top[r+1][c+1], verts_top[r][c+1]))
                    bm.faces.new((verts_bot[r][c], verts_bot[r][c+1], verts_bot[r+1][c+1], verts_bot[r+1][c]))
        # Stitch outer & front/back edges
        for r in range(rows):
            if sx > 0:
                bm.faces.new((verts_bot[r][cols], verts_top[r][cols], verts_top[r+1][cols], verts_bot[r+1][cols]))
            else:
                bm.faces.new((verts_bot[r][cols], verts_bot[r+1][cols], verts_top[r+1][cols], verts_top[r][cols]))
        for c in range(cols):
            if sx > 0:
                bm.faces.new((verts_bot[0][c], verts_bot[0][c+1], verts_top[0][c+1], verts_top[0][c]))
                bm.faces.new((verts_bot[rows][c], verts_top[rows][c], verts_top[rows][c+1], verts_bot[rows][c+1]))
            else:
                bm.faces.new((verts_bot[0][c], verts_top[0][c], verts_top[0][c+1], verts_bot[0][c+1]))
                bm.faces.new((verts_bot[rows][c], verts_bot[rows][c+1], verts_top[rows][c+1], verts_top[rows][c]))
        _link_bm(tilted_holder, f"Pages_{int(sx)}", bm, M["parchment"], smooth=True)

    # Silk bookmark ribbon draping over spine
    rib_pts = [(0.0, 0.11, 0.030), (0.0, 0.0, 0.032), (0.012, -0.145, 0.025), (0.022, -0.195, -0.025)]
    add_tube(tilted_holder, "BookmarkRibbon", rib_pts, [0.008, 0.008, 0.007, 0.006], M["ribbon"], segs=8)

    # Brass Inkwell & Curved Feather Quill beside the right edge of the lectern
    add_lathe(root, "InkwellBody", [
        (0.032, 0.0), (0.036, 0.010), (0.030, 0.032), (0.022, 0.044),
        (0.026, 0.050), (0.018, 0.054), (0.012, 0.042)
    ], M["brass"], segs=16, loc=(0.335, -0.08, 0.0))
    add_cyl(root, "InkPool", 0.013, 0.013, 0.004, M["obsidian"], segs=12, loc=(0.335, -0.08, 0.050))
    quill_pts = [(0.335, -0.08, 0.048), (0.352, -0.06, 0.115), (0.376, -0.03, 0.195), (0.402, -0.005, 0.255)]
    add_tube(root, "QuillShaft", quill_pts, [0.0022, 0.0032, 0.0026, 0.0012], M["quill"], segs=8)
    # Sculpted curved tapered feather plume along upper quill shaft
    bm_q = bmesh.new()
    q_steps = 8
    q_rings = []
    for qi in range(q_steps + 1):
        u = qi / q_steps
        qp = Vector((0.352 + u * 0.050, -0.06 + u * 0.055, 0.112 + u * 0.142))
        half_w = math.sin(u * math.pi) * 0.019 + (0.002 if u < 0.95 else 0.0005)
        v_l = bm_q.verts.new(qp + Vector((-half_w * 0.75, -0.002, 0.004)))
        v_c = bm_q.verts.new(qp + Vector((0.0, 0.002, 0.0)))
        v_r = bm_q.verts.new(qp + Vector((half_w * 0.95, -0.002, -0.004)))
        q_rings.append((v_l, v_c, v_r))
    for qi in range(q_steps):
        a0, a1 = q_rings[qi], q_rings[qi + 1]
        bm_q.faces.new((a0[0], a0[1], a1[1], a1[0]))
        bm_q.faces.new((a0[1], a0[2], a1[2], a1[1]))
    _link_bm(root, "QuillVane", bm_q, M["quill"], smooth=True)
    return root


# =============================================================================
# 2. BRASS DIAL (WITH ANIMATED DialKnob CHILD)
# =============================================================================
def build_brass_dial(M):
    root = bpy.data.objects.new("BrassDialRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # Stepped octagonal walnut & brass baseplate
    add_cyl(root, "BaseWalnut", 0.105, 0.098, 0.024, M["walnut"], segs=8, loc=(0, 0, 0.012), smooth=False)
    add_cyl(root, "BezelRing", 0.088, 0.085, 0.012, M["brass"], segs=32, loc=(0, 0, 0.028))
    add_cyl(root, "FacePlate", 0.078, 0.078, 0.006, M["obsidian"], segs=32, loc=(0, 0, 0.032))

    # 9 Brass scale tick studs sweeping 270 deg around face (-135..+135 around Z, 0 = -Y front)
    for k in range(9):
        frac = k / 8.0
        ang = math.radians(-135.0 + frac * 270.0)
        # 0 deg points toward -Y (front towards player), clockwise sweep from bottom-left to bottom-right
        tx = math.sin(ang) * 0.068
        ty = math.cos(ang) * 0.068
        r_tick = 0.0045 if (k % 2 == 0) else 0.0032
        add_cyl(root, f"Tick_{k}", r_tick, r_tick, 0.008, M["gold"], segs=10, loc=(tx, ty, 0.037))

    # Rotating DialKnob child centered at (0,0,0.036)
    knob = bpy.data.objects.new("DialKnob", None)
    bpy.context.scene.collection.objects.link(knob)
    knob.parent = root
    knob.location = (0.0, 0.0, 0.036)

    add_lathe(knob, "KnobDrum", [
        (0.044, 0.0), (0.046, 0.014), (0.040, 0.034), (0.032, 0.042), (0.0, 0.043)
    ], M["brass"], segs=28)
    # Central grip bar & directional gold pointer arrow (points toward +Y at 0 deg)
    add_box(knob, "KnobGrip", (0.016, 0.072, 0.018), M["gold"], loc=(0, 0.004, 0.044), bevel_amt=0.003)
    add_cyl(knob, "PointerTip", 0.010, 0.001, 0.034, M["gold"], segs=4, loc=(0, 0.048, 0.024), rot=(-90, 0, 0), smooth=False)
    return root


# =============================================================================
# 3. WAX STAMP (WITH ANIMATED StampHandle CHILD)
# =============================================================================
def build_wax_stamp(M):
    root = bpy.data.objects.new("WaxStampRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # Dark oak circular coaster + stamped crimson wax disc
    add_cyl(root, "CoasterOak", 0.095, 0.090, 0.016, M["walnut"], segs=28, loc=(0, 0, 0.008))
    add_cyl(root, "CoasterTrim", 0.088, 0.088, 0.004, M["brass"], segs=28, loc=(0, 0, 0.017))
    add_lathe(root, "WaxDisc", [
        (0.066, 0.017), (0.070, 0.023), (0.060, 0.028), (0.046, 0.025), (0.046, 0.028), (0.0, 0.028)
    ], M["wax_red"], segs=24)

    # Pressable StampHandle child resting cleanly just above the wax seal
    handle = bpy.data.objects.new("StampHandle", None)
    bpy.context.scene.collection.objects.link(handle)
    handle.parent = root
    handle.location = (0.0, 0.0, 0.032)

    add_lathe(handle, "BrassDie", [
        (0.036, 0.0), (0.038, 0.010), (0.024, 0.022), (0.020, 0.034)
    ], M["brass"], segs=24)
    add_lathe(handle, "WoodGrip", [
        (0.020, 0.034), (0.015, 0.048), (0.028, 0.082), (0.034, 0.112),
        (0.026, 0.138), (0.012, 0.150), (0.0, 0.152)
    ], M["mahogany"], segs=24)
    add_cyl(handle, "FinialCap", 0.016, 0.010, 0.012, M["gold"], segs=16, loc=(0, 0, 0.154))
    return root


# =============================================================================
# 4. ALCHEMICAL PRISM LANTERN (WITH LanternCore CHILD)
# =============================================================================
def build_lantern_prism(M):
    root = bpy.data.objects.new("LanternPrismRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # Hexagonal footed iron & brass base
    add_cyl(root, "FootBase", 0.095, 0.084, 0.022, M["iron"], segs=6, loc=(0, 0, 0.011), smooth=False)
    add_cyl(root, "BrassPlinth", 0.078, 0.072, 0.014, M["brass"], segs=6, loc=(0, 0, 0.028), smooth=False)

    # 6 slim corner wrought-iron pillars + pagoda roof + top finial ring
    for k in range(6):
        a = (k / 6.0) * math.tau
        px, py = math.cos(a) * 0.068, math.sin(a) * 0.068
        add_cyl(root, f"Pillar_{k}", 0.006, 0.005, 0.175, M["iron"], segs=8, loc=(px, py, 0.120))
    add_cyl(root, "UpperCollar", 0.076, 0.082, 0.014, M["brass"], segs=6, loc=(0, 0, 0.212), smooth=False)
    add_cyl(root, "PagodaRoof", 0.086, 0.024, 0.056, M["iron"], segs=6, loc=(0, 0, 0.246), smooth=False)
    add_cyl(root, "RoofFinial", 0.018, 0.006, 0.022, M["gold"], segs=12, loc=(0, 0, 0.282))

    # Glowing faceted crystal LanternCore inside cage
    core = bpy.data.objects.new("LanternCore", None)
    bpy.context.scene.collection.objects.link(core)
    core.parent = root
    core.location = (0.0, 0.0, 0.118)

    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.044)
    bmesh.ops.scale(bm, vec=(0.82, 0.82, 1.48), verts=bm.verts)
    _link_bm(core, "CrystalCore", bm, M["prism_core"], smooth=False)
    add_cyl(core, "CrystalGlassShell", 0.056, 0.052, 0.165, M["glass"], segs=6, smooth=False)
    return root


# =============================================================================
# 5. BRASS GIMBAL HOURGLASS (WITH HourglassBody CHILD)
# =============================================================================
def build_hourglass(M):
    root = bpy.data.objects.new("HourglassRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # Walnut base & U-shaped brass gimbal yoke supporting HourglassBody at z=0.145
    add_cyl(root, "StandBase", 0.088, 0.080, 0.018, M["walnut"], segs=24, loc=(0, 0, 0.009))
    add_cyl(root, "YokeStem", 0.016, 0.012, 0.024, M["brass"], segs=16, loc=(0, 0, 0.028))
    yoke_pts = [(-0.072, 0.0, 0.145), (-0.068, 0.0, 0.058), (0.0, 0.0, 0.036), (0.068, 0.0, 0.058), (0.072, 0.0, 0.145)]
    add_tube(root, "GimbalYoke", yoke_pts, [0.007, 0.007, 0.010, 0.007, 0.007], M["brass"], segs=10)
    for sx in (-1.0, 1.0):
        add_cyl(root, f"PivotCap_{int(sx)}", 0.010, 0.010, 0.014, M["gold"], segs=14,
                loc=(sx * 0.074, 0.0, 0.145), rot=(0, 90, 0))

    # Flippable HourglassBody centered cleanly at (0, 0, 0.145)
    body = bpy.data.objects.new("HourglassBody", None)
    bpy.context.scene.collection.objects.link(body)
    body.parent = root
    body.location = (0.0, 0.0, 0.145)

    # Central brass waist gimbal ring + axle pins connecting to pillars
    add_cyl(body, "WaistRing", 0.056, 0.056, 0.010, M["brass"], segs=24, loc=(0, 0, 0.0))
    for sx in (-1.0, 1.0):
        add_cyl(body, f"WaistAxle_{int(sx)}", 0.005, 0.005, 0.024, M["gold"], segs=10,
                loc=(sx * 0.058, 0.0, 0.0), rot=(0, 90, 0))

    for sz in (-1.0, 1.0):
        add_cyl(body, f"Cap_{int(sz)}", 0.062, 0.062, 0.012, M["walnut"], segs=24, loc=(0, 0, sz * 0.098))
        add_cyl(body, f"Trim_{int(sz)}", 0.064, 0.064, 0.005, M["brass"], segs=24, loc=(0, 0, sz * 0.091))
    for k in range(3):
        a = (k / 3.0) * math.tau + math.radians(30)
        add_cyl(body, f"Pillar_{k}", 0.0055, 0.0055, 0.188, M["brass"], segs=10,
                loc=(math.cos(a) * 0.050, math.sin(a) * 0.050, 0.0))

    # Double glass bulb + glowing golden sand cones
    add_lathe(body, "GlassBulbs", [
        (0.044, -0.088), (0.046, -0.055), (0.028, -0.022), (0.009, 0.0),
        (0.028, 0.022), (0.046, 0.055), (0.044, 0.088)
    ], M["glass"], segs=24)
    add_cyl(body, "BottomSand", 0.038, 0.006, 0.054, M["sand"], segs=20, loc=(0, 0, -0.060))
    add_cyl(body, "TopSand", 0.006, 0.028, 0.036, M["sand"], segs=20, loc=(0, 0, 0.050))
    return root


# =============================================================================
# 6. TAVERN GRAMOPHONE BELL (WITH BellHorn CHILD)
# =============================================================================
def build_gramophone_bell(M):
    root = bpy.data.objects.new("GramophoneBellRoot", None)
    bpy.context.scene.collection.objects.link(root)

    # Mahogany octagonal plinth + brass acoustic elbow
    add_cyl(root, "PlinthBase", 0.096, 0.088, 0.026, M["mahogany"], segs=8, loc=(0, 0, 0.013), smooth=False)
    add_cyl(root, "PlinthRim", 0.072, 0.068, 0.010, M["brass"], segs=24, loc=(0, 0, 0.030))
    elbow_pts = [(0.0, 0.012, 0.034), (0.0, 0.028, 0.078), (0.0, 0.018, 0.118)]
    add_tube(root, "AcousticElbow", elbow_pts, [0.022, 0.019, 0.017], M["brass"], segs=16)

    # Flared fluted brass BellHorn child pivoted at elbow top (0, 0.018, 0.118)
    horn = bpy.data.objects.new("BellHorn", None)
    bpy.context.scene.collection.objects.link(horn)
    horn.parent = root
    horn.location = (0.0, 0.018, 0.118)

    # Horn flares toward -Y (toward camera/player) and slightly upward
    horn_prof = [
        (0.016, 0.0), (0.020, 0.032), (0.032, 0.064), (0.056, 0.094),
        (0.088, 0.118), (0.096, 0.124), (0.086, 0.124), (0.050, 0.094), (0.014, 0.032)
    ]
    add_lathe(horn, "FlaredBell", horn_prof, M["gold"], segs=24, rot=(72, 0, 0))
    add_cyl(horn, "BellCollar", 0.022, 0.022, 0.014, M["brass"], segs=18, rot=(72, 0, 0))
    return root


def render_contact_sheet():
    scene = reset_scene()
    M = get_mats()
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 840
    scene.world = bpy.data.worlds.new("StudyWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.05, 0.035, 0.028, 1.0)

    # Warm carved oak studio tabletop
    add_box(None, "DeskTop", (2.6, 1.4, 0.06), M["oak"], loc=(0, 0, -0.03))
    # Unlink parent=None works via _link_bm? Wait: _link_bm sets o.parent = None cleanly!

    builders = [
        (build_wax_stamp,       (-0.62, -0.18, 0.0)),
        (build_lantern_prism,   (-0.42,  0.14, 0.0)),
        (build_desk_ledger,     ( 0.00,  0.04, 0.0)),
        (build_hourglass,       ( 0.44,  0.14, 0.0)),
        (build_gramophone_bell, ( 0.65, -0.16, 0.0)),
        (build_brass_dial,      ( 0.36, -0.28, 0.0)),
    ]
    for fn, loc in builders:
        obj = fn(M)
        obj.location = loc

    cam_d = bpy.data.cameras.new("DeskCam")
    cam_d.lens = 36.0
    cam_o = bpy.data.objects.new("DeskCam", cam_d)
    cam_o.location = (0.0, -1.78, 1.04)
    cam_o.rotation_euler = (Vector((0.0, 0.0, 0.08)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    l1 = bpy.data.lights.new("WarmCandle", "AREA")
    l1.energy = 190.0; l1.size = 1.8; l1.color = (1.0, 0.82, 0.56)
    o1 = bpy.data.objects.new("WarmCandle", l1)
    o1.location = (-1.1, -0.8, 1.4)
    o1.rotation_euler = (Vector((0, 0, 0)) - o1.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o1)

    l2 = bpy.data.lights.new("CoolRim", "AREA")
    l2.energy = 75.0; l2.size = 2.2; l2.color = (0.72, 0.84, 1.0)
    o2 = bpy.data.objects.new("CoolRim", l2)
    o2.location = (1.2, 0.9, 1.1)
    o2.rotation_euler = (Vector((0, 0, 0)) - o2.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o2)

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    print("RENDERED_LOBBY_PROPS_PREVIEW=", PREVIEW_PATH)


def main():
    prop_map = {
        "settings_desk_ledger": build_desk_ledger,
        "settings_brass_dial": build_brass_dial,
        "settings_wax_stamp": build_wax_stamp,
        "settings_lantern_prism": build_lantern_prism,
        "settings_hourglass": build_hourglass,
        "settings_gramophone_bell": build_gramophone_bell,
    }
    for fname, fn in prop_map.items():
        reset_scene()
        M = get_mats()
        root = fn(M)
        export_glb(root, OUT_DIR / f"{fname}.glb")

    render_contact_sheet()


if __name__ == "__main__":
    main()
