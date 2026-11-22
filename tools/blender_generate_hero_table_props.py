"""
Blender 5.3.0 headless generator for LIALO Hero Table Props (Task #5):
Upgrades the 3 hero tabletop prop families to close-up inspection quality
(for Table Items close-up camera toggle) while preserving exact scale, orientation,
tabletop resting pivot (Z=0), and all VFX/node contracts:

  1) Swords:
     - assets/models/sword_oath.glb
     - assets/models/swords/SWORD_IRON.glb
     - assets/models/swords/SWORD_GILDED.glb
     - assets/models/swords/SWORD_CRIMSON.glb
     - assets/models/swords/SWORD_RUNE.glb
     - assets/models/swords/SWORD_DRAGON.glb
     (Blade along Blender +Y = Godot -Z, hilt along Blender -Y = Godot +Z,
      resting flat on Z >= 0.0 with centerline at Z = 0.016m)

  2) Beer Mug:
     - assets/models/tavern_mug.glb
     (16 individual curved dark-oak staves with bevel gaps, two riveted hammered
      brass/iron barrel hoops, S-curved oak & brass handle with lever thumb rest,
      thick brass rim, front embossed tavern crest, recessed glowing golden-amber
      ale surface visible alongside a billowing sculpted creamy foam head & side
      foam drips; base at Z=0)

  3) Hellfire Phial:
     - assets/models/phial_ignis.glb
     - assets/models/vfx/hellfire_phial_hero.glb (MUST contain IgnitedPlume child node!)
     (16-faceted blown-glass alchemical bulb encased in curved wrought-iron filigree
      cage ribs & riveted waist band, twin scroll ear-handles, ringed brass neck collar
      with braided hemp cord & stamped alchemy tag, wax-dripped cork stopper + fuse wick,
      swirling glowing molten ember heart & 10 floating octahedral spark crystals inside,
      plus named child node IgnitedPlume at bottle mouth; base at Z=0)

  4) Studio close-up contact sheet preview:
     - C:/Users/arnos/.gemini/antigravity/brain/a7664877-b33a-48d0-8658-be5de670b3ca/scratch/hero_table_props_preview.png

Run via:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup --python D:/downpour-godot/tools/blender_generate_hero_table_props.py
"""
import math
import pathlib
import bpy
import bmesh
from mathutils import Vector, Euler

ROOT = pathlib.Path(r"D:\downpour-godot")
MODELS_DIR = ROOT / "assets" / "models"
SWORDS_DIR = MODELS_DIR / "swords"
VFX_DIR = MODELS_DIR / "vfx"
PREVIEW_PATH = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a7664877-b33a-48d0-8658-be5de670b3ca\scratch\hero_table_props_preview.png"
)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    return scene


def make_mat(
    name: str,
    color: tuple,
    metallic: float = 0.0,
    roughness: float = 0.5,
    emission: tuple = (0.0, 0.0, 0.0),
    emit_str: float = 0.0,
    alpha: float = 1.0,
):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
    bsdf.inputs["Emission Strength"].default_value = emit_str
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 0.999:
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"
    return mat


def get_mats():
    """
    Linear-RGB Principled BSDF materials tuned for LIALO's warm candlelight
    medieval tavern PBR aesthetic in Blender 5.3 & Godot 4.7.
    """
    return {
        # Tavern woods & organic materials (rich dark linear values)
        "oak": make_mat("MugOak", (0.068, 0.028, 0.011), roughness=0.56),
        "oak_alt": make_mat("MugOakAlt", (0.048, 0.019, 0.007), roughness=0.60),
        "walnut": make_mat("Walnut", (0.028, 0.013, 0.006), roughness=0.54),
        "leather": make_mat("SwordGripMat", (0.065, 0.022, 0.010), roughness=0.62),
        "charred_hide": make_mat("CharredHide", (0.028, 0.016, 0.014), roughness=0.66),
        "velvet": make_mat("VelvetRed", (0.18, 0.008, 0.014), roughness=0.72),
        "cork": make_mat("Mat_PhialCork", (0.24, 0.13, 0.058), roughness=0.74),
        "hemp": make_mat("HempCord", (0.32, 0.20, 0.09), roughness=0.78),
        "wax_red": make_mat("Mat_PhialWax", (0.36, 0.014, 0.018), roughness=0.26),
        # Metals
        "brass": make_mat("MugBrass", (0.76, 0.48, 0.12), metallic=0.92, roughness=0.23),
        "guard_brass": make_mat("SwordGuardMat", (0.76, 0.48, 0.12), metallic=0.92, roughness=0.23),
        "phial_brass": make_mat("Mat_PhialBrass", (0.76, 0.48, 0.12), metallic=0.92, roughness=0.23),
        "gold": make_mat("Gold", (0.94, 0.66, 0.14), metallic=0.95, roughness=0.18),
        "copper": make_mat("Copper", (0.70, 0.25, 0.09), metallic=0.90, roughness=0.24),
        "iron": make_mat("Iron", (0.075, 0.080, 0.092), metallic=0.86, roughness=0.36),
        "phial_iron": make_mat("Mat_PhialIron", (0.062, 0.066, 0.078), metallic=0.88, roughness=0.33),
        "smoked_iron": make_mat("SmokedIron", (0.042, 0.038, 0.046), metallic=0.89, roughness=0.30),
        "black_silver": make_mat("BlackSilver", (0.19, 0.22, 0.29), metallic=0.92, roughness=0.24),
        "steel": make_mat("SwordBladeMat", (0.58, 0.63, 0.72), metallic=0.94, roughness=0.20),
        "honed_edge": make_mat("SwordFullerMat", (0.20, 0.23, 0.28), metallic=0.92, roughness=0.28),
        "damascus": make_mat("Damascus", (0.68, 0.71, 0.80), metallic=0.95, roughness=0.16),
        # Ale, foam, glass, gems & glowing cores
        "ale": make_mat(
            "MugAle",
            (0.86, 0.32, 0.02),
            roughness=0.10,
            emission=(1.0, 0.42, 0.04),
            emit_str=1.65,
        ),
        "foam": make_mat(
            "MugFoam",
            (0.95, 0.89, 0.74),
            roughness=0.40,
            emission=(0.24, 0.20, 0.14),
            emit_str=0.18,
        ),
        "phial_glass": make_mat(
            "Mat_PhialGlass",
            (0.92, 0.48, 0.16),
            metallic=0.0,
            roughness=0.05,
            emission=(1.0, 0.36, 0.06),
            emit_str=0.22,
            alpha=0.15,
        ),
        "phial_magma": make_mat(
            "Mat_PhialMagma",
            (1.0, 0.22, 0.02),
            roughness=0.12,
            emission=(1.0, 0.24, 0.02),
            emit_str=7.5,
        ),
        "plasma_core": make_mat(
            "Mat_PlasmaCore",
            (1.0, 0.85, 0.25),
            roughness=0.08,
            emission=(1.0, 0.82, 0.20),
            emit_str=11.0,
        ),
        "flame_outer": make_mat(
            "Mat_FlameOuter",
            (1.0, 0.20, 0.02),
            roughness=0.18,
            emission=(1.0, 0.22, 0.02),
            emit_str=3.5,
        ),
        "crimson_glow": make_mat(
            "CrimsonGlow",
            (0.76, 0.015, 0.03),
            roughness=0.14,
            emission=(0.96, 0.03, 0.06),
            emit_str=2.8,
        ),
        "storm_cyan": make_mat(
            "StormCyan",
            (0.14, 0.80, 1.0),
            roughness=0.14,
            emission=(0.12, 0.78, 1.0),
            emit_str=3.2,
        ),
        "sapphire": make_mat(
            "SwordGemMat",
            (0.06, 0.28, 0.92),
            roughness=0.14,
            emission=(0.12, 0.44, 1.0),
            emit_str=2.2,
        ),
    }


def link_bm(
    parent,
    name: str,
    bm: bmesh.types.BMesh,
    mat,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    smooth: bool = True,
):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
    obj.parent = parent
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_box(parent, name: str, size: tuple, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel_amt=0.0, smooth=False):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel_amt > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel_amt, segments=2, affect="EDGES")
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth or (bevel_amt > 0.0))


def add_cyl(parent, name: str, r1: float, r2: float, h: float, mat, segs=18, loc=(0, 0, 0), rot=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_sphere(parent, name: str, rad: float, mat, scale=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), sub=2, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=rad)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_torus(parent, name: str, maj: float, mn: float, mat, maj_s=24, min_s=10, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    bm = bmesh.new()
    rings = []
    for i in range(maj_s):
        a = (i / maj_s) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        ring = []
        for j in range(min_s):
            b = (j / min_s) * math.tau
            r = maj + math.cos(b) * mn
            pt = (ca * r * scale[0], sa * r * scale[1], math.sin(b) * mn * scale[2])
            ring.append(bm.verts.new(pt))
        rings.append(ring)
    for i in range(maj_s):
        ni = (i + 1) % maj_s
        for j in range(min_s):
            nj = (j + 1) % min_s
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][nj], rings[i][nj]))
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=True)


def add_lathe(
    parent,
    name: str,
    prof: list,
    mat,
    segs=24,
    loc=(0, 0, 0),
    rot=(0, 0, 0),
    smooth=True,
    flute_count=0,
    flute_amp=0.0,
):
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = (i / segs) * math.tau
        flute = 1.0 + (flute_amp * math.cos(flute_count * a) if flute_count > 0 else 0.0)
        rings.append([bm.verts.new((math.cos(a) * max(1e-4, r * flute), math.sin(a) * max(1e-4, r * flute), z)) for (r, z) in prof])
    for i in range(segs):
        ni = (i + 1) % segs
        for j in range(len(prof) - 1):
            bm.faces.new((rings[i][j], rings[ni][j], rings[ni][j + 1], rings[i][j + 1]))
    if prof[0][0] > 1e-4:
        bm.faces.new([rings[i][0] for i in range(segs)][::-1])
    if prof[-1][0] > 1e-4:
        bm.faces.new([rings[i][-1] for i in range(segs)])
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


def add_tube(
    parent,
    name: str,
    pts: list,
    radii: list,
    mat,
    segs=12,
    loc=(0, 0, 0),
    rot=(0, 0, 0),
    scale_uv=(1.0, 1.0),
    rib_amp=0.0,
    smooth=True,
):
    """
    Parallel-transport tube extruder: propagates the cross-section frame (u, v)
    smoothly from point to point so curves in any plane (XY, XZ, YZ, or 3D) never twist.
    """
    bm = bmesh.new()
    n = len(pts)
    rings = []
    prev_tang = None
    prev_u = None

    for idx, (pt, rad) in enumerate(zip(pts, radii)):
        p = Vector(pt)
        if idx == 0:
            tang = (Vector(pts[1]) - p).normalized()
        elif idx == n - 1:
            tang = (p - Vector(pts[-2])).normalized()
        else:
            tang = (Vector(pts[idx + 1]) - Vector(pts[idx - 1])).normalized()
        if tang.length_squared < 1e-8:
            tang = Vector((0, 0, 1))

        if prev_u is None:
            # Pick initial reference up vector least aligned with initial tangent
            ref = Vector((0, 0, 1)) if abs(tang.z) < 0.85 else Vector((0, 1, 0))
            u = tang.cross(ref).normalized()
        else:
            # Parallel-transport prev_u onto plane perpendicular to tang
            rot_q = prev_tang.rotation_difference(tang)
            u_cand = (rot_q @ prev_u)
            u_cand = u_cand - tang * u_cand.dot(tang)
            u = u_cand.normalized() if u_cand.length_squared > 1e-8 else prev_u
        v = tang.cross(u).normalized()
        prev_tang = tang
        prev_u = u

        r_eff = max(1e-4, rad * (1.0 + rib_amp * math.sin(idx * 2.4)))
        ring = []
        for k in range(segs):
            a = (k / segs) * math.tau
            off = u * (math.cos(a) * r_eff * scale_uv[0]) + v * (math.sin(a) * r_eff * scale_uv[1])
            ring.append(bm.verts.new(p + off))
        rings.append(ring)

    for idx in range(n - 1):
        for k in range(segs):
            nk = (k + 1) % segs
            bm.faces.new((rings[idx][k], rings[idx][nk], rings[idx + 1][nk], rings[idx + 1][k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    return link_bm(parent, name, bm, mat, loc=loc, rot=rot, smooth=smooth)


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
    print(f"EXPORTED_HERO_PROP={filepath.relative_to(ROOT)}")


# =============================================================================
# 1. HERO SWORDS (sword_oath.glb + 5 SWORD_*.glb)
#    Orientation contract:
#    - Blade points along Blender +Y (= Godot -Z), tip around Y = +0.665m
#    - Hilt points along Blender -Y (= Godot +Z), pommel around Y = -0.194m
#    - Lies flat on Z >= 0.0, sword plane centerline at Z = 0.016m
# =============================================================================

def sculpt_hero_blade(
    parent,
    name: str,
    stations_y: list,
    half_widths: list,
    center_xs: list,
    mat,
    z_center: float = 0.016,
    thick: float = 0.0072,
    fuller_end_y: float = 0.46,
    single_edge: bool = False,
    ricasso_notches: bool = True,
):
    """
    Sculpts a high-detail 10-vertex cross-section blade with:
      - Razor double-bevel cutting edges
      - Recessed concave fuller groove along both upper and lower faces
      - Optional ricasso parrying notches near the base (Y ~ 0.032..0.058)
      - Tapered acute point at stations_y[-1] + 0.088
    """
    bm = bmesh.new()
    rings = []
    for y, w, cx in zip(stations_y, half_widths, center_xs):
        w_eff = w
        if ricasso_notches and 0.030 <= y <= 0.056:
            notch_t = math.sin(((y - 0.030) / 0.026) * math.pi)
            w_eff = w * (1.0 - 0.28 * notch_t)
        elif ricasso_notches and 0.056 < y <= 0.080:
            lug_t = math.sin(((y - 0.056) / 0.024) * math.pi)
            w_eff = w * (1.0 + 0.18 * lug_t)

        in_fuller = (0.016 <= y <= fuller_end_y)
        fuller_fade = 0.0
        if in_fuller:
            u_f = (y - 0.016) / max(0.01, fuller_end_y - 0.016)
            fuller_fade = math.sin(min(1.0, max(0.0, u_f)) * math.pi) ** 0.45

        spine_shift = (w_eff * 0.36) if single_edge else 0.0
        w_bevel = w_eff * 0.64
        w_fuller = w_eff * 0.29
        t_bevel = thick * 0.70
        t_ridge = thick * 1.05
        t_trough = thick * (1.0 - 0.56 * fuller_fade)

        pts_xz = [
            (cx - w_eff, z_center),                                  # 0: Left sharp edge
            (cx - w_bevel + spine_shift * 0.3, z_center + t_bevel),  # 1: Upper-left bevel shoulder
            (cx - w_fuller + spine_shift * 0.7, z_center + t_ridge), # 2: Upper-left fuller ridge
            (cx + spine_shift * 0.85, z_center + t_trough),          # 3: Upper fuller trough
            (cx + w_fuller + spine_shift * 0.7, z_center + t_ridge), # 4: Upper-right fuller ridge
            (cx + w_bevel + spine_shift * 0.3, z_center + t_bevel),  # 5: Upper-right bevel shoulder
            (cx + w_eff, z_center),                                  # 6: Right edge / spine
            (cx + w_bevel + spine_shift * 0.3, z_center - t_bevel),  # 7: Lower-right bevel shoulder
            (cx + spine_shift * 0.85, z_center - t_trough),          # 8: Lower fuller trough
            (cx - w_bevel + spine_shift * 0.3, z_center - t_bevel),  # 9: Lower-left bevel shoulder
        ]
        rings.append([bm.verts.new((px, y, pz)) for (px, pz) in pts_xz])

    n_sec = len(rings[0])
    for i in range(len(rings) - 1):
        for k in range(n_sec):
            nk = (k + 1) % n_sec
            bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][nk], rings[i][nk]))

    tip_y = stations_y[-1] + 0.088
    tip_x = center_xs[-1] + (half_widths[-1] * 0.42 if single_edge else 0.0)
    tip_v = bm.verts.new((tip_x, tip_y, z_center))
    for k in range(n_sec):
        nk = (k + 1) % n_sec
        bm.faces.new((rings[-1][k], tip_v, rings[-1][nk]))

    bm.faces.new(rings[0][::-1])
    return link_bm(parent, name, bm, mat, smooth=False)


def add_fuller_inlay(
    parent,
    name: str,
    y_start: float,
    y_end: float,
    w_start: float,
    w_end: float,
    mat,
    curve_fn=None,
    z_center: float = 0.016,
    z_half: float = 0.0056,
    steps: int = 16,
):
    """Sculpts a double-sided raised/inlaid fuller strip seated inside the blade fuller trough."""
    pts = []
    rads = []
    for i in range(steps):
        u = i / (steps - 1)
        y = y_start + u * (y_end - y_start)
        cx = curve_fn(y) if curve_fn else 0.0
        pts.append((cx, y, z_center))
        rads.append(w_start * (1.0 - u) + w_end * u)
    return add_tube(parent, name, pts, rads, mat, segs=8, scale_uv=(1.0, z_half / max(1e-4, w_start)), smooth=False)


def add_hero_hilt(
    root,
    grip_mat,
    metal_mat,
    gem_mat,
    wire_mat=None,
    grip_len: float = 0.148,
    z_center: float = 0.016,
    use_oath_names: bool = False,
    pommel_style: str = "wheel",
):
    if wire_mat is None:
        wire_mat = metal_mat

    # 1. Waisted elliptical grip core along -Y
    g_steps = 18
    g_pts = []
    g_rads = []
    for i in range(g_steps):
        u = i / (g_steps - 1)
        y = -0.008 - u * grip_len
        swell = 1.0 + 0.18 * math.sin(u * math.pi)
        flute = 1.0 + 0.03 * math.sin(u * math.tau * 5.0)
        g_pts.append((0.0, y, z_center))
        g_rads.append(0.0155 * swell * flute)
    grip_name = "GripCore" if use_oath_names else "Grip"
    add_tube(root, grip_name, g_pts, g_rads, grip_mat, segs=16, scale_uv=(1.15, 0.76), smooth=True)

    # 2. Top and bottom ferrule collars
    for idx, (fy, r_f) in enumerate([(-0.011, 0.0185), (-0.006 - grip_len, 0.0175)]):
        add_cyl(
            root,
            f"GripFerrule_{idx}",
            r_f,
            r_f * 0.92,
            0.010,
            metal_mat,
            segs=16,
            loc=(0.0, fy, z_center),
            rot=(90, 0, 0),
        )

    # 3. 5 Chased metallic grip ribs
    for ri in range(5):
        u = (ri + 0.8) / 5.6
        ry = -0.008 - u * grip_len
        swell = 1.0 + 0.18 * math.sin(u * math.pi)
        rib_name = f"GripRib_{ri}" if use_oath_names else f"GripRing{ri}"
        add_torus(
            root,
            rib_name,
            0.0162 * swell,
            0.0024,
            wire_mat,
            maj_s=20,
            min_s=8,
            loc=(0.0, ry, z_center),
            rot=(90, 0, 0),
            scale=(1.14, 0.78, 1.0),
        )

    # 4. Helical wire binding spiraling around the grip
    w_pts = []
    n_w = 44
    for k in range(n_w):
        u = k / (n_w - 1)
        y = -0.014 - u * (grip_len - 0.012)
        swell = 1.0 + 0.18 * math.sin(u * math.pi)
        ang = u * math.tau * 4.5
        rx = 0.0164 * swell * 1.15
        rz = 0.0164 * swell * 0.77
        w_pts.append((math.cos(ang) * rx, y, z_center + math.sin(ang) * rz))
    add_tube(root, "GripWireWrap", w_pts, [0.0014] * n_w, wire_mat, segs=6)

    # 5. Pommel assembly at Y = -grip_len - 0.028
    py = -grip_len - 0.028
    pom_name = "PommelBody" if use_oath_names else "PommelDisc"
    gem_name = "GemPommel" if use_oath_names else "PommelGem"

    if pommel_style == "crown":
        add_cyl(root, pom_name, 0.026, 0.022, 0.015, metal_mat, segs=10, loc=(0.0, py, z_center), smooth=False)
        for sp_i in range(5):
            a = (sp_i / 5.0) * math.tau - math.pi * 0.5
            sx = math.cos(a) * 0.022
            sy = py - 0.012 - abs(math.sin(a)) * 0.008
            add_cyl(root, f"PommelCrownSpire_{sp_i}", 0.005, 0.001, 0.018, metal_mat, segs=6, loc=(sx, sy, z_center), rot=(90, 0, math.degrees(a) * 0.3), smooth=False)
    elif pommel_style == "talon":
        add_sphere(root, pom_name, 0.022, metal_mat, scale=(1.1, 1.0, 0.58), loc=(0.0, py, z_center), sub=2)
        for c_i in range(4):
            ang = (c_i / 4.0) * math.tau + 0.4
            c_pts = [
                (math.cos(ang) * 0.014, py + 0.016, z_center + math.sin(ang) * 0.008),
                (math.cos(ang) * 0.026, py, z_center + math.sin(ang) * 0.013),
                (math.cos(ang) * 0.016, py - 0.018, z_center + math.sin(ang) * 0.009),
            ]
            add_tube(root, f"PommelTalon_{c_i}", c_pts, [0.0045, 0.0035, 0.0012], metal_mat, segs=6)
    else:
        add_lathe(
            root,
            pom_name,
            [(0.018, -0.008), (0.027, -0.005), (0.027, 0.005), (0.018, 0.008), (0.013, 0.010)],
            metal_mat,
            segs=16,
            loc=(0.0, py, z_center),
            smooth=False,
        )
        add_torus(root, "PommelBezel", 0.015, 0.0025, wire_mat, maj_s=18, min_s=8, loc=(0.0, py, z_center + 0.009))

    add_cyl(root, "PommelPeenNut", 0.007, 0.004, 0.014, wire_mat, segs=8, loc=(0.0, py - 0.024, z_center), rot=(-90, 0, 0), smooth=False)
    add_sphere(root, gem_name, 0.0125, gem_mat, scale=(1.0, 1.0, 0.55), loc=(0.0, py, z_center + 0.011), sub=2, smooth=False)


def build_sword_oath(M):
    """
    Knight's Oath Longsword (assets/models/sword_oath.glb):
    Preserves mesh/node substring contract ('blade', 'fuller', 'guard', 'grip', 'pommel', 'gem').
    """
    root = bpy.data.objects.new("SwordOathRoot", None)
    bpy.context.scene.collection.objects.link(root)
    z0 = 0.016

    ys = [0.0, 0.032, 0.044, 0.058, 0.082, 0.18, 0.34, 0.48, 0.58]
    ws = [0.026, 0.025, 0.021, 0.027, 0.025, 0.023, 0.020, 0.017, 0.013]
    cxs = [0.0] * len(ys)
    sculpt_hero_blade(root, "Blade", ys, ws, cxs, M["steel"], z_center=z0, thick=0.0072, fuller_end_y=0.47)
    add_fuller_inlay(root, "Fuller", 0.020, 0.46, 0.0062, 0.0026, M["honed_edge"], z_center=z0, z_half=0.0058)

    g_pts = [
        (-0.126, 0.028, z0),
        (-0.082, 0.010, z0),
        (-0.036, 0.002, z0),
        (0.0, 0.0, z0),
        (0.036, 0.002, z0),
        (0.082, 0.010, z0),
        (0.126, 0.028, z0),
    ]
    g_rads = [0.011, 0.0085, 0.011, 0.015, 0.011, 0.0085, 0.011]
    add_tube(root, "GuardCross", g_pts, g_rads, M["guard_brass"], segs=12, scale_uv=(1.0, 0.72))
    add_box(root, "GuardEcusson", (0.036, 0.034, 0.022), M["guard_brass"], loc=(0.0, 0.004, z0), bevel_amt=0.004)
    add_sphere(root, "GemCross", 0.0095, M["sapphire"], scale=(0.95, 1.15, 0.55), loc=(0.0, 0.004, z0 + 0.011), sub=2, smooth=False)

    for tag, sx in [("L", -1.0), ("R", 1.0)]:
        add_sphere(
            root,
            f"GuardFinial_{tag}",
            0.013,
            M["guard_brass"],
            scale=(1.1, 0.85, 0.68),
            loc=(sx * 0.128, 0.030, z0),
            sub=2,
            smooth=False,
        )

    add_hero_hilt(
        root,
        M["leather"],
        M["guard_brass"],
        M["sapphire"],
        wire_mat=M["gold"],
        grip_len=0.148,
        z_center=z0,
        use_oath_names=True,
        pommel_style="wheel",
    )
    return root


def build_sword_iron(M):
    """
    SWORD_IRON (Tavern Mercenary Falchion):
    Asymmetric widened single-edge cleaver belly + back-spine notches + S-curved iron/brass guard + side Nagel ring.
    """
    root = bpy.data.objects.new("SWORD_IRON", None)
    bpy.context.scene.collection.objects.link(root)
    z0 = 0.016

    ys = [0.0, 0.04, 0.12, 0.24, 0.36, 0.47, 0.56]
    ws = [0.021, 0.022, 0.024, 0.028, 0.034, 0.037, 0.025]
    cxs = [0.0, 0.001, 0.003, 0.006, 0.009, 0.008, 0.002]
    sculpt_hero_blade(
        root,
        "FalchionBlade",
        ys,
        ws,
        cxs,
        M["steel"],
        z_center=z0,
        thick=0.0068,
        fuller_end_y=0.45,
        single_edge=True,
        ricasso_notches=True,
    )
    add_fuller_inlay(
        root,
        "Fuller",
        0.022,
        0.44,
        0.0054,
        0.0032,
        M["iron"],
        curve_fn=lambda y: 0.007 + 0.006 * math.sin((y / 0.45) * math.pi),
        z_center=z0,
        z_half=0.0056,
    )

    add_box(root, "ForteCollar", (0.044, 0.026, 0.016), M["iron"], loc=(0.001, 0.015, z0), bevel_amt=0.003)
    for rx in (-0.013, 0.0, 0.013):
        add_sphere(root, f"ForteRivet_{rx:.3f}", 0.0032, M["brass"], loc=(rx, 0.015, z0 + 0.008), sub=1)

    s_pts = [
        (-0.114, 0.032, z0),
        (-0.088, 0.018, z0),
        (-0.048, -0.009, z0),
        (0.0, 0.0, z0),
        (0.048, 0.009, z0),
        (0.088, -0.018, z0),
        (0.114, -0.032, z0),
    ]
    s_rads = [0.012, 0.009, 0.010, 0.0145, 0.010, 0.009, 0.012]
    add_tube(root, "SGuard", s_pts, s_rads, M["brass"], segs=12, scale_uv=(1.0, 0.72))
    for tag, pt in [("L", s_pts[0]), ("R", s_pts[-1])]:
        add_torus(root, f"QuillonScroll_{tag}", 0.011, 0.0042, M["iron"], maj_s=16, min_s=8, loc=pt)
    add_torus(root, "NagelSideRing", 0.024, 0.0042, M["iron"], maj_s=20, min_s=8, loc=(0.0, 0.004, z0 + 0.008), scale=(1.2, 0.75, 0.6))

    add_hero_hilt(root, M["leather"], M["brass"], M["iron"], wire_mat=M["iron"], grip_len=0.148, z_center=z0, pommel_style="wheel")
    return root


def build_sword_gilded(M):
    """
    SWORD_GILDED (Royal Sovereign Claymore):
    Broad Damascus blade + golden fuller + V-swept crossguard with open quatrefoil clover rings
    + pas-d'ane parrying rings + crimson velvet grip + royal crown pommel with glowing ruby.
    """
    root = bpy.data.objects.new("SWORD_GILDED", None)
    bpy.context.scene.collection.objects.link(root)
    z0 = 0.016

    ys = [0.0, 0.035, 0.050, 0.075, 0.18, 0.34, 0.48, 0.58]
    ws = [0.030, 0.028, 0.024, 0.029, 0.026, 0.023, 0.019, 0.015]
    cxs = [0.0] * len(ys)
    sculpt_hero_blade(root, "ClaymoreBlade", ys, ws, cxs, M["damascus"], z_center=z0, thick=0.0074, fuller_end_y=0.48)
    add_fuller_inlay(root, "GoldFuller", 0.020, 0.46, 0.0068, 0.0028, M["gold"], z_center=z0, z_half=0.0060)

    add_box(root, "RoyalRicassoCollar", (0.056, 0.036, 0.017), M["gold"], loc=(0.0, 0.018, z0), bevel_amt=0.0035)
    add_sphere(root, "CrossRuby", 0.0095, M["crimson_glow"], scale=(0.9, 1.2, 0.55), loc=(0.0, 0.008, z0 + 0.010), sub=2, smooth=False)

    v_pts = [(-0.128, 0.052, z0), (-0.064, 0.020, z0), (0.0, -0.004, z0), (0.064, 0.020, z0), (0.128, 0.052, z0)]
    add_tube(root, "VGuard", v_pts, [0.0095, 0.0105, 0.0155, 0.0105, 0.0095], M["gold"], segs=12, scale_uv=(1.0, 0.72))

    for sx in (-1.0, 1.0):
        qx, qy = sx * 0.132, 0.055
        for lobe_i in range(4):
            la = (lobe_i / 4.0) * math.tau + math.pi * 0.25
            add_torus(
                root,
                f"Quatrefoil_{int(sx)}_{lobe_i}",
                0.0095,
                0.0032,
                M["gold"],
                maj_s=14,
                min_s=8,
                loc=(qx + math.cos(la) * 0.0085, qy + math.sin(la) * 0.0085, z0),
            )
        add_sphere(root, f"QuatrefoilGem_{int(sx)}", 0.006, M["crimson_glow"], scale=(1.0, 1.0, 0.6), loc=(qx, qy, z0 + 0.004), sub=1)
        p_pts = [(sx * 0.028, 0.005, z0), (sx * 0.052, 0.032, z0), (sx * 0.026, 0.055, z0)]
        add_tube(root, f"PasDAne_{int(sx)}", p_pts, [0.0045, 0.0042, 0.0032], M["gold"], segs=8)

    add_hero_hilt(root, M["velvet"], M["gold"], M["crimson_glow"], wire_mat=M["gold"], grip_len=0.156, z_center=z0, pommel_style="crown")
    return root


def build_sword_crimson(M):
    """
    SWORD_CRIMSON (Nosferatu Vampire Saber):
    Curved smoked-iron saber blade + pulsing crimson blood-vein fuller + swept vampire fang serrations
    + sculpted gothic bat-wing crossguard + sweeping D-ring knuckle-bow.
    """
    root = bpy.data.objects.new("SWORD_CRIMSON", None)
    bpy.context.scene.collection.objects.link(root)
    z0 = 0.016

    ys = [0.0, 0.08, 0.18, 0.30, 0.42, 0.52, 0.58]
    cxs = [0.0, 0.002, 0.008, 0.020, 0.038, 0.056, 0.072]
    ws = [0.024, 0.023, 0.022, 0.021, 0.019, 0.016, 0.012]
    sculpt_hero_blade(
        root,
        "SaberBlade",
        ys,
        ws,
        cxs,
        M["smoked_iron"],
        z_center=z0,
        thick=0.0066,
        fuller_end_y=0.48,
        single_edge=True,
        ricasso_notches=False,
    )

    vein_pts = [(cx - 0.002, y, z0) for cx, y in zip(cxs[:-1], ys[:-1])]
    add_tube(root, "BloodVein", vein_pts, [0.0058, 0.0052, 0.0046, 0.0042, 0.0035, 0.0025], M["crimson_glow"], segs=8, scale_uv=(0.88, 1.18))

    # 4 Swept crimson-tipped vampire fang barbs along lower cutting edge
    for bi in range(4):
        by = 0.060 + bi * 0.054
        bcx = 0.001 + (bi * 0.0032) - 0.021
        fang_pts = [(bcx + 0.004, by - 0.010, z0), (bcx - 0.009, by + 0.004, z0), (bcx - 0.016, by + 0.016, z0)]
        add_tube(root, f"BloodBarb_{bi}", fang_pts, [0.0055, 0.0035, 0.0008], M["crimson_glow"], segs=6, scale_uv=(1.0, 0.55), smooth=False)

    bow_pts = [
        (-0.112, 0.038, z0),
        (-0.068, 0.012, z0),
        (-0.028, 0.002, z0),
        (0.0, 0.0, z0),
        (0.048, -0.010, z0),
        (0.078, -0.042, z0),
        (0.082, -0.105, z0),
        (0.062, -0.152, z0),
        (0.018, -0.174, z0),
    ]
    bow_rads = [0.008, 0.011, 0.012, 0.015, 0.012, 0.0095, 0.0085, 0.008, 0.0075]
    add_tube(root, "BatKnuckleBow", bow_pts, bow_rads, M["guard_brass"], segs=10, scale_uv=(1.0, 0.72))

    for wi, wx in enumerate([-0.042, -0.072, -0.102]):
        w_pts = [(wx, 0.010 + wi * 0.009, z0), (wx - 0.010, -0.022 + wi * 0.005, z0)]
        add_tube(root, f"BatWingSpine_{wi}", w_pts, [0.0055, 0.0012], M["smoked_iron"], segs=6)
    add_sphere(root, "BatCenterRuby", 0.010, M["crimson_glow"], scale=(0.85, 1.25, 0.6), loc=(0.0, 0.004, z0 + 0.009), sub=2, smooth=False)

    add_hero_hilt(root, M["leather"], M["guard_brass"], M["crimson_glow"], wire_mat=M["smoked_iron"], grip_len=0.148, z_center=z0, pommel_style="talon")
    return root


def build_sword_rune(M):
    """
    SWORD_RUNE (Tempest Runeblade):
    Geometric notched high-steel blade + glowing storm-cyan crystal fuller channel + 6 inlaid Nordic rune sigils
    + twin bifurcated lightning-fork quillons in blackened silver with suspended crystal shards.
    """
    root = bpy.data.objects.new("SWORD_RUNE", None)
    bpy.context.scene.collection.objects.link(root)
    z0 = 0.016

    ys = [0.0, 0.036, 0.052, 0.074, 0.16, 0.32, 0.46, 0.57]
    ws = [0.028, 0.024, 0.022, 0.028, 0.025, 0.022, 0.018, 0.014]
    cxs = [0.0] * len(ys)
    sculpt_hero_blade(root, "RuneBlade", ys, ws, cxs, M["steel"], z_center=z0, thick=0.0072, fuller_end_y=0.47)
    add_fuller_inlay(root, "RuneInlay", 0.018, 0.46, 0.0064, 0.0032, M["storm_cyan"], z_center=z0, z_half=0.0060)

    for ri in range(6):
        ry = 0.085 + ri * 0.062
        ang = 32 if (ri % 2 == 0) else -32
        add_box(root, f"RuneGlyph_{ri}", (0.018, 0.0040, 0.0128), M["storm_cyan"], loc=(0.0, ry, z0), rot=(0, 0, ang))

    for sx in (-1.0, 1.0):
        main_fork = [
            (0.0, 0.0, z0),
            (sx * 0.048, 0.018, z0),
            (sx * 0.088, 0.004, z0),
            (sx * 0.128, 0.042, z0),
        ]
        sub_fork = [
            (sx * 0.052, 0.016, z0),
            (sx * 0.092, 0.042, z0),
            (sx * 0.118, 0.066, z0),
        ]
        add_tube(root, f"StormQuillon_{int(sx)}", main_fork, [0.014, 0.010, 0.0085, 0.0045], M["black_silver"], segs=8, scale_uv=(1.0, 0.72), smooth=False)
        add_tube(root, f"StormTine_{int(sx)}", sub_fork, [0.0085, 0.0065, 0.0035], M["black_silver"], segs=8, scale_uv=(1.0, 0.72), smooth=False)
        add_sphere(
            root,
            f"QuillonCrystal_{int(sx)}",
            0.0085,
            M["storm_cyan"],
            scale=(0.7, 1.4, 0.55),
            loc=(sx * 0.104, 0.036, z0),
            rot=(0, 0, sx * -28),
            sub=1,
            smooth=False,
        )

    add_box(root, "RuneEcusson", (0.042, 0.038, 0.020), M["black_silver"], loc=(0.0, 0.008, z0), rot=(0, 0, 45), bevel_amt=0.003)
    add_sphere(root, "RuneCenterCore", 0.010, M["storm_cyan"], scale=(1.0, 1.0, 0.6), loc=(0.0, 0.008, z0 + 0.009), sub=1, smooth=False)

    add_hero_hilt(root, M["smoked_iron"], M["black_silver"], M["sapphire"], wire_mat=M["storm_cyan"], grip_len=0.150, z_center=z0, pommel_style="wheel")
    return root


def build_sword_dragon(M):
    """
    SWORD_DRAGON (Dragonfire Flamberge Greatsword):
    Volcanic smoked-iron blade + blazing molten magma fuller core + 6 pairs of sculpted sawtooth
    dragon-scale serrations + sweeping sculpted dragon-wing & horned dragon-skull crossguard.
    """
    root = bpy.data.objects.new("SWORD_DRAGON", None)
    bpy.context.scene.collection.objects.link(root)
    z0 = 0.016

    ys = [0.0, 0.05, 0.14, 0.26, 0.38, 0.49, 0.58]
    ws = [0.033, 0.031, 0.030, 0.028, 0.025, 0.021, 0.016]
    cxs = [0.0] * len(ys)
    sculpt_hero_blade(root, "DragonBlade", ys, ws, cxs, M["smoked_iron"], z_center=z0, thick=0.0078, fuller_end_y=0.49)
    add_fuller_inlay(root, "LavaCore", 0.018, 0.48, 0.0075, 0.0032, M["phial_magma"], z_center=z0, z_half=0.0064)

    for k in range(6):
        sy = 0.085 + k * 0.074
        bw = 0.029 - k * 0.0018
        for sx in (-1.0, 1.0):
            add_box(
                root,
                f"Serr_{int(sx)}_{k}",
                (0.018, 0.022, 0.0068),
                M["smoked_iron"],
                loc=(sx * bw, sy, z0),
                rot=(0, 0, sx * 34),
                bevel_amt=0.0015,
            )
            add_sphere(
                root,
                f"LavaVent_{int(sx)}_{k}",
                0.0045,
                M["plasma_core"],
                scale=(1.4, 0.7, 0.85),
                loc=(sx * 0.011, sy, z0 + 0.0045),
                sub=1,
            )

    for sx in (-1.0, 1.0):
        wing_upper = [
            (0.0, 0.004, z0),
            (sx * 0.058, 0.034, z0 + 0.002),
            (sx * 0.118, 0.068, z0 + 0.003),
            (sx * 0.146, 0.024, z0),
        ]
        wing_lower = [
            (sx * 0.026, -0.004, z0),
            (sx * 0.074, 0.014, z0),
            (sx * 0.112, -0.014, z0),
        ]
        add_tube(root, f"DragonWing_{int(sx)}", wing_upper, [0.015, 0.012, 0.009, 0.0035], M["gold"], segs=10, scale_uv=(1.0, 0.68))
        add_tube(root, f"DragonWingLower_{int(sx)}", wing_lower, [0.010, 0.008, 0.003], M["copper"], segs=8, scale_uv=(1.0, 0.65))
        horn_pts = [(sx * 0.014, 0.005, z0 + 0.008), (sx * 0.034, 0.045, z0 + 0.011), (sx * 0.024, 0.078, z0 + 0.007)]
        add_tube(root, f"DragonHorn_{int(sx)}", horn_pts, [0.0065, 0.0045, 0.0015], M["gold"], segs=8)

    add_sphere(root, "DragonSkullCrest", 0.022, M["gold"], scale=(1.05, 1.25, 0.58), loc=(0.0, 0.010, z0), sub=2, smooth=False)
    add_sphere(root, "DragonHeartGem", 0.011, M["plasma_core"], scale=(0.85, 1.25, 0.58), loc=(0.0, 0.012, z0 + 0.010), sub=2, smooth=False)

    add_hero_hilt(root, M["charred_hide"], M["gold"], M["phial_magma"], wire_mat=M["copper"], grip_len=0.158, z_center=z0, pommel_style="talon")
    return root


# =============================================================================
# 2. HERO BEER MUG (assets/models/tavern_mug.glb)
#    Base at Z = 0.0, radius ~0.060m, height ~0.156m, handle on +X
# =============================================================================

def build_tavern_mug(M):
    """
    Sculpts a close-up hero medieval tavern tankard:
      - 16 individually curved & beveled dark-oak staves with visible shadow gaps
      - Coopered recessed oak bottom disc
      - 2 wide hammered-brass & forged-iron barrel hoops studded with 32 domed rivets
      - Thick rolled brass drinking rim + embossed front heraldic tavern crest shield
      - Sculpted S-curved dark-oak & brass handle with riveted brackets & lever thumb-rest
      - Recessed glowing golden-amber ale liquid surface clearly visible in front crescent
      - Billowing multi-lobed creamy foam crown + 4 foam drips running down the side
    """
    root = bpy.data.objects.new("TavernMugRoot", None)
    bpy.context.scene.collection.objects.link(root)

    n_staves = 16
    mug_h = 0.134
    z_rings_n = 10
    gap_rad = 0.010  # Crisp angular bevel gap between staves

    # 1. 16 Individual curved barrel-bellied dark-oak staves
    for si in range(n_staves):
        bm = bmesh.new()
        a_mid = (si / n_staves) * math.tau
        half_span = (math.tau / n_staves) * 0.5 - gap_rad
        a0 = a_mid - half_span
        a1 = a_mid + half_span
        a_bevel = half_span * 0.16

        rings = []
        for zi in range(z_rings_n):
            u = zi / (z_rings_n - 1)
            z = u * mug_h
            belly = math.sin(u * math.pi) * 0.0048 - u * 0.0042
            r_out = 0.0575 + belly
            r_in = 0.0475 + belly * 0.85

            pts = [
                (math.cos(a0) * (r_out - 0.0018), math.sin(a0) * (r_out - 0.0018), z),
                (math.cos(a0 + a_bevel) * r_out, math.sin(a0 + a_bevel) * r_out, z),
                (math.cos(a1 - a_bevel) * r_out, math.sin(a1 - a_bevel) * r_out, z),
                (math.cos(a1) * (r_out - 0.0018), math.sin(a1) * (r_out - 0.0018), z),
                (math.cos(a1) * r_in, math.sin(a1) * r_in, z),
                (math.cos(a0) * r_in, math.sin(a0) * r_in, z),
            ]
            rings.append([bm.verts.new(p) for p in pts])

        for zi in range(z_rings_n - 1):
            for k in range(6):
                nk = (k + 1) % 6
                bm.faces.new((rings[zi][k], rings[zi][nk], rings[zi + 1][nk], rings[zi + 1][k]))
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
        stave_mat = M["oak"] if (si % 2 == 0) else M["oak_alt"]
        link_bm(root, f"MugStave_{si}", bm, stave_mat, smooth=False)

    # 2. Recessed coopered bottom oak disc
    add_cyl(root, "MugBottomDisc", 0.049, 0.049, 0.010, M["walnut"], segs=24, loc=(0.0, 0.0, 0.012))

    # 3. Two hammered-brass & forged-iron barrel hoops with 16 domed rivets each
    hoop_specs = [
        ("MugHoop_2", 0.028, 0.0605, 0.0612, 0.015),
        ("MugHoop_10", 0.102, 0.0588, 0.0575, 0.015),
    ]
    for h_name, hz, r_bot, r_top, hh in hoop_specs:
        add_lathe(
            root,
            h_name,
            [
                (r_bot - 0.003, hz - hh * 0.5),
                (r_bot, hz - hh * 0.38),
                (r_top, hz + hh * 0.38),
                (r_top - 0.003, hz + hh * 0.5),
            ],
            M["brass"],
            segs=32,
            smooth=True,
        )
        for trim_idx, dz in enumerate((-hh * 0.45, hh * 0.45)):
            add_torus(root, f"{h_name}_IronTrim_{trim_idx}", (r_bot + r_top) * 0.5, 0.0018, M["iron"], maj_s=32, min_s=8, loc=(0.0, 0.0, hz + dz))
        r_riv = (r_bot + r_top) * 0.5 + 0.0005
        for ri in range(16):
            ra = (ri + 0.5) / 16.0 * math.tau
            add_sphere(
                root,
                f"{h_name}_Rivet_{ri}",
                0.0024,
                M["iron"] if (ri % 2 == 0) else M["gold"],
                loc=(math.cos(ra) * r_riv, math.sin(ra) * r_riv, hz),
                sub=1,
            )

    # 4. Thick molded brass drinking rim at Z = 0.133m
    add_torus(root, "MugBrassRim", 0.0505, 0.0046, M["brass"], maj_s=32, min_s=12, loc=(0.0, 0.0, 0.133))

    # 5. Embossed front heraldic tavern crest shield plaque (on -Y front & +Y back)
    for tag, sy in [("Front", -1.0), ("Back", 1.0)]:
        cy = sy * 0.060
        add_box(root, f"MugCrest_{tag}", (0.034, 0.007, 0.040), M["brass"], loc=(0.0, cy, 0.066), bevel_amt=0.0025)
        add_box(root, f"MugCrestInlay_{tag}", (0.024, 0.0085, 0.028), M["iron"], loc=(0.0, cy + sy * 0.001, 0.066), bevel_amt=0.0015)
        add_sphere(root, f"MugCrestGem_{tag}", 0.0065, M["gold"], scale=(1.0, 0.55, 1.25), loc=(0.0, cy + sy * 0.004, 0.066), sub=2)

    # 6. Sculpted S-curved dark-oak & brass handle on +X with thumb rest (parallel-transport twist-free!)
    h_pts = [
        (0.055, 0.0, 0.106),
        (0.082, 0.0, 0.114),
        (0.098, 0.0, 0.094),
        (0.097, 0.0, 0.062),
        (0.084, 0.0, 0.036),
        (0.057, 0.0, 0.028),
    ]
    h_rads = [0.0085, 0.0095, 0.0102, 0.0098, 0.0090, 0.0085]
    add_tube(root, "MugHandle", h_pts, h_rads, M["oak"], segs=16, scale_uv=(0.85, 1.15))

    add_box(root, "HandleBracketTop", (0.022, 0.020, 0.016), M["brass"], loc=(0.061, 0.0, 0.106), bevel_amt=0.0025)
    add_box(root, "HandleBracketBot", (0.022, 0.020, 0.016), M["brass"], loc=(0.061, 0.0, 0.028), bevel_amt=0.0025)
    add_torus(root, "HandleMidBand", 0.0108, 0.0024, M["brass"], maj_s=16, min_s=8, loc=(0.097, 0.0, 0.066), rot=(90, 0, 0))
    thumb_pts = [(0.066, 0.0, 0.112), (0.077, 0.0, 0.127), (0.089, 0.0, 0.135)]
    add_tube(root, "MugThumbRest", thumb_pts, [0.0048, 0.0056, 0.0070], M["brass"], segs=10)

    # 7. Recessed glowing golden-amber ale liquid surface inside rim (at Z = 0.129m)
    add_cyl(root, "MugAleSurface", 0.0485, 0.0485, 0.008, M["ale"], segs=32, loc=(0.0, 0.0, 0.129))

    # 8. Billowing sculpted creamy foam head shifted slightly toward +Y/-X so a gleaming
    #    golden-amber crescent window of MugAleSurface is clearly visible inside the rim!
    add_lathe(
        root,
        "MugFoamCap",
        [(0.036, 0.129), (0.038, 0.136), (0.032, 0.145), (0.020, 0.151), (0.001, 0.154)],
        M["foam"],
        segs=24,
        loc=(-0.007, 0.009, 0.0),
        flute_count=8,
        flute_amp=0.06,
    )

    foam_bubbles = [
        (-0.006, 0.012, 0.147, 0.021, (1.15, 1.05, 0.72)),
        (0.014, 0.022, 0.143, 0.018, (1.1, 1.0, 0.78)),
        (-0.024, 0.016, 0.144, 0.019, (1.0, 1.15, 0.76)),
        (-0.026, -0.014, 0.142, 0.018, (1.05, 1.1, 0.74)),
        (0.030, 0.010, 0.138, 0.015, (1.0, 1.1, 0.72)),
        (-0.035, -0.002, 0.139, 0.016, (1.05, 1.0, 0.75)),
        (-0.002, 0.033, 0.138, 0.015, (1.1, 1.0, 0.72)),
        (-0.018, -0.029, 0.138, 0.015, (1.15, 0.95, 0.76)),
        (-0.028, 0.024, 0.137, 0.014, (1.05, 1.05, 0.74)),
        (0.022, 0.026, 0.137, 0.014, (1.0, 1.0, 0.72)),
        # Small floating foam islets on the exposed golden-amber ale crescent!
        (0.020, -0.020, 0.133, 0.009, (1.1, 1.1, 0.45)),
        (0.004, -0.028, 0.133, 0.0075, (1.0, 1.0, 0.42)),
    ]
    for bi, (bx, by, bz, brad, bsc) in enumerate(foam_bubbles):
        add_sphere(root, f"FoamBubble_{bi}", brad, M["foam"], scale=bsc, loc=(bx, by, bz), sub=2)

    # 4 Creamy foam drips cascading over the brass rim down the dark-oak staves
    drip_specs = [
        (-2.25, 0.078),  # Front-left long foam cascade
        (-0.95, 0.100),  # Front-right foam drip
        (2.35, 0.088),   # Back-left foam stream
        (1.05, 0.108),   # Side foam bead
    ]
    for di, (d_ang, z_tip) in enumerate(drip_specs):
        ca, sa = math.cos(d_ang), math.sin(d_ang)
        d_pts = []
        d_rads = []
        n_d = 9
        for k in range(n_d):
            u = k / (n_d - 1)
            z = 0.138 * (1.0 - u) + z_tip * u
            r_surface = 0.049 + 0.0125 * math.sin(min(1.0, u * 2.4) * math.pi * 0.5)
            d_pts.append((ca * r_surface, sa * r_surface, z))
            rad = 0.0068 * (1.0 - 0.45 * u) + (0.0026 * math.sin(u * math.pi) if u > 0.55 else 0.0)
            d_rads.append(rad)
        add_tube(root, f"FoamDrip_{di}", d_pts, d_rads, M["foam"], segs=10)
        add_sphere(root, f"FoamDropBead_{di}", 0.0050, M["foam"], scale=(1.0, 1.0, 1.35), loc=(ca * 0.0615, sa * 0.0615, z_tip - 0.002), sub=2)

    return root


# =============================================================================
# 3. HERO HELLFIRE PHIAL (phial_ignis.glb & assets/models/vfx/hellfire_phial_hero.glb)
#    Base at Z = 0.0, radius ~0.072m, height ~0.242m (with IgnitedPlume)
#    CRITICAL CONTRACT: Must include named child node "IgnitedPlume"!
# =============================================================================

def build_hellfire_phial_hero(M, root_name: str = "HellfirePhialRoot"):
    root = bpy.data.objects.new(root_name, None)
    bpy.context.scene.collection.objects.link(root)

    # 1. Wrought-iron & brass alchemical foot coaster at Z = 0.0
    add_lathe(
        root,
        "PhialCoaster",
        [(0.066, 0.0), (0.068, 0.006), (0.060, 0.013), (0.044, 0.016)],
        M["phial_iron"],
        segs=16,
        smooth=False,
    )
    add_torus(root, "PhialCoasterRim", 0.062, 0.0038, M["phial_brass"], maj_s=24, min_s=10, loc=(0.0, 0.0, 0.011))
    for ri in range(8):
        ra = (ri / 8.0) * math.tau
        add_sphere(root, f"CoasterRivet_{ri}", 0.0026, M["gold"], loc=(math.cos(ra) * 0.062, math.sin(ra) * 0.062, 0.014), sub=1)

    # 2. Swirling Glowing Molten Ember Heart & Floating Spark Crystals suspended inside
    magma_root = add_sphere(
        root,
        "PhialMagmaCore",
        0.033,
        M["phial_magma"],
        scale=(1.0, 1.0, 0.92),
        loc=(0.0, 0.0, 0.065),
        sub=3,
    )
    add_sphere(magma_root, "MagmaInnerNucleus", 0.021, M["plasma_core"], loc=(0.0, 0.0, 0.0), sub=2)

    # Dual helical plasma swirl ribbons rising around the molten core
    for h_idx in range(2):
        sw_pts = []
        sw_rads = []
        n_sw = 24
        phase = h_idx * math.pi
        for k in range(n_sw):
            u = k / (n_sw - 1)
            ang = phase + u * math.tau * 1.65
            r_sw = 0.040 * math.sin(max(0.08, min(0.95, u)) * math.pi)
            z_sw = -0.032 + u * 0.070
            sw_pts.append((math.cos(ang) * r_sw, math.sin(ang) * r_sw, z_sw))
            sw_rads.append(0.0052 * math.sin(u * math.pi) + 0.0014)
        add_tube(magma_root, f"MagmaSwirl_{h_idx}", sw_pts, sw_rads, M["plasma_core"], segs=8)

    # 10 Faceted octahedral spark crystals orbiting inside the bulb
    spark_coords = [
        (0.042, 0.010, -0.012, 0.0075),
        (-0.040, 0.014, -0.008, 0.0072),
        (0.014, -0.043, -0.003, 0.0074),
        (-0.016, 0.041, 0.008, 0.0070),
        (0.036, 0.026, 0.015, 0.0068),
        (-0.035, -0.028, 0.018, 0.0068),
        (0.022, -0.022, 0.032, 0.0062),
        (-0.020, 0.022, 0.035, 0.0060),
        (0.008, -0.012, 0.052, 0.0052),
        (-0.008, 0.010, 0.066, 0.0048),
    ]
    for ei, (ex, ey, ez, erad) in enumerate(spark_coords):
        add_sphere(
            magma_root,
            f"PhialEmber_{ei}",
            erad,
            M["plasma_core"] if (ei % 2 == 0) else M["phial_magma"],
            scale=(0.8, 0.8, 1.48),
            loc=(ex, ey, ez),
            rot=(ei * 27, ei * 41, ei * 19),
            sub=1,
            smooth=False,
        )

    # 3. 16-Faceted Hand-Blown Alchemical Glass Bulb & Fluted Neck
    glass_prof = [
        (0.034, 0.012),
        (0.050, 0.028),
        (0.059, 0.048),
        (0.061, 0.066),
        (0.057, 0.086),
        (0.046, 0.106),
        (0.030, 0.122),
        (0.022, 0.136),
        (0.021, 0.156),
        (0.026, 0.166),
        (0.023, 0.170),
    ]
    add_lathe(
        root,
        "PhialGlass",
        glass_prof,
        M["phial_glass"],
        segs=32,
        smooth=False,
        flute_count=16,
        flute_amp=0.018,
    )

    # 4. Intricate Wrought-Iron Filigree Cage Ribs, Riveted Waist Band & S-Scroll Handles
    cage_root = bpy.data.objects.new("PhialIronCage", None)
    cage_root.parent = root
    bpy.context.scene.collection.objects.link(cage_root)

    add_torus(cage_root, "CageEquator", 0.0625, 0.0048, M["phial_iron"], maj_s=32, min_s=10, loc=(0.0, 0.0, 0.066), scale=(1.0, 1.0, 1.45))
    add_torus(cage_root, "CageShoulderBand", 0.0475, 0.0036, M["phial_iron"], maj_s=28, min_s=8, loc=(0.0, 0.0, 0.106), scale=(1.0, 1.0, 1.25))

    for mi in range(8):
        ma = (mi / 8.0) * math.tau
        ca, sa = math.cos(ma), math.sin(ma)
        rib_pts = []
        rib_rads = []
        for r_p, z_p in glass_prof[:7]:
            r_c = r_p + 0.0026
            rib_pts.append((ca * r_c, sa * r_c, z_p))
            rib_rads.append(0.0032 if (mi % 2 == 0) else 0.0024)
        add_tube(cage_root, f"CageMeridian_{mi}", rib_pts, rib_rads, M["phial_iron"], segs=8)
        add_sphere(
            cage_root,
            f"CageWaistRivet_{mi}",
            0.0034,
            M["phial_brass"],
            loc=(ca * 0.0668, sa * 0.0668, 0.066),
            sub=1,
        )

    for tag, sx in [("L", -1.0), ("R", 1.0)]:
        ear_pts = [
            (sx * 0.046, 0.0, 0.106),
            (sx * 0.070, 0.0, 0.122),
            (sx * 0.076, 0.0, 0.102),
            (sx * 0.068, 0.0, 0.078),
            (sx * 0.062, 0.0, 0.066),
        ]
        add_tube(cage_root, f"PhialHandle_{tag}", ear_pts, [0.0040, 0.0046, 0.0048, 0.0042, 0.0040], M["phial_brass"], segs=10)
        add_torus(cage_root, f"HandleScroll_{tag}", 0.0075, 0.0028, M["phial_iron"], maj_s=14, min_s=8, loc=(sx * 0.069, 0.0, 0.114), rot=(90, 0, 0))

    # 5. Ringed Brass Neck Collar, Braided Hemp Cord & Hanging Alchemical Tag
    add_lathe(
        root,
        "PhialCollar",
        [(0.027, -0.016), (0.030, -0.011), (0.026, -0.004), (0.029, 0.002), (0.028, 0.008)],
        M["phial_brass"],
        segs=24,
        loc=(0.0, 0.0, 0.156),
    )
    for hi in range(4):
        add_torus(root, f"HempCord_{hi}", 0.0275, 0.0022, M["hemp"], maj_s=22, min_s=8, loc=(0.0, 0.0, 0.129 + hi * 0.0036))
    tag_cord = [(0.020, -0.020, 0.134), (0.032, -0.034, 0.118), (0.038, -0.042, 0.098)]
    add_tube(root, "AlchemicalTagCord", tag_cord, [0.0018, 0.0016, 0.0016], M["hemp"], segs=6)
    add_cyl(root, "AlchemicalTagSeal", 0.011, 0.011, 0.0035, M["wax_red"], segs=14, loc=(0.039, -0.044, 0.094), rot=(58, 18, 35))

    # 6. Tapered Cork Stopper, Dripping Crimson Sealing Wax & Braided Fuse Wick
    add_cyl(root, "PhialCork", 0.020, 0.023, 0.026, M["cork"], segs=18, loc=(0.0, 0.0, 0.176))
    add_lathe(
        root,
        "PhialWaxSeal",
        [(0.025, 0.180), (0.026, 0.187), (0.022, 0.193), (0.008, 0.196)],
        M["wax_red"],
        segs=20,
        flute_count=7,
        flute_amp=0.05,
    )

    wax_drips = [
        (0.25, 0.148, 0.0046),
        (1.30, 0.156, 0.0040),
        (2.35, 0.144, 0.0048),
        (3.45, 0.158, 0.0038),
        (4.40, 0.150, 0.0044),
        (5.45, 0.160, 0.0036),
    ]
    for wi, (wa, wz_end, wrad) in enumerate(wax_drips):
        ca, sa = math.cos(wa), math.sin(wa)
        w_pts = []
        w_rads = []
        for k in range(7):
            u = k / 6.0
            z = 0.189 * (1.0 - u) + wz_end * u
            r = 0.0235 + 0.0055 * math.sin(min(1.0, u * 1.8) * math.pi * 0.5)
            w_pts.append((ca * r, sa * r, z))
            w_rads.append(wrad * (1.0 - 0.3 * u) + (0.0016 if k == 5 else 0.0))
        add_tube(root, f"WaxDrip_{wi}", w_pts, w_rads, M["wax_red"], segs=8)

    wick_pts = [(0.0, 0.0, 0.192), (0.003, -0.002, 0.203), (0.008, -0.004, 0.214)]
    add_tube(root, "PhialWick", wick_pts, [0.0030, 0.0026, 0.0022], M["hemp"], segs=8)
    add_sphere(root, "PhialWickFlame", 0.0055, M["plasma_core"], scale=(0.85, 0.85, 1.45), loc=(0.008, -0.004, 0.216), sub=2)

    # 7. CRITICAL CONTRACT: Named child node "IgnitedPlume" at bottle mouth (0, 0, 0.160)
    plume = bpy.data.objects.new("IgnitedPlume", None)
    plume.location = (0.0, 0.0, 0.160)
    plume.parent = root
    bpy.context.scene.collection.objects.link(plume)

    sp_pts = []
    sp_rads = []
    for k in range(14):
        u = k / 13.0
        ang = u * math.tau * 1.8
        rad_xy = 0.007 * math.sin(u * math.pi)
        sp_pts.append((math.cos(ang) * rad_xy, math.sin(ang) * rad_xy, 0.015 + u * 0.072))
        sp_rads.append(0.013 * ((1.0 - u) ** 0.72) + 0.001)
    add_tube(plume, "IgniteSpiral", sp_pts, sp_rads, M["plasma_core"], segs=10)

    # 4 Dancing outer flame tongues flaring out into sharp asymmetric tips
    tongue_heights = [0.078, 0.066, 0.082, 0.070]
    for ti in range(4):
        ta = (ti / 4.0) * math.tau + 0.35
        ca, sa = math.cos(ta), math.sin(ta)
        th = tongue_heights[ti]
        t_pts = [
            (ca * 0.007, sa * 0.007, 0.020),
            (ca * 0.019, sa * 0.019, 0.042),
            (ca * 0.015, sa * 0.015, 0.060),
            (ca * 0.022, sa * 0.022, th),
        ]
        add_tube(plume, f"IgniteTongue_{ti}", t_pts, [0.0085, 0.0072, 0.0040, 0.0008], M["flame_outer"], segs=8)

    return root


# =============================================================================
# 4. STUDIO CLOSE-UP CONTACT SHEET PREVIEW RENDER
# =============================================================================

def render_hero_contact_sheet():
    scene = reset_scene()
    M = get_mats()
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.film_transparent = False

    scene.world = bpy.data.worlds.new("TavernStudioWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.020, 0.013, 0.009, 1.0)
    bg.inputs["Strength"].default_value = 1.0

    # Rich dark walnut studio tabletop surface + stepped rear showcase plinth
    add_box(None, "TavernTabletop", (3.6, 2.8, 0.04), M["walnut"], loc=(0.0, 0.0, -0.022), bevel_amt=0.006)
    add_box(None, "ShowcasePlinth", (2.45, 0.62, 0.16), M["oak_alt"], loc=(0.0, 0.58, 0.08), bevel_amt=0.008)

    # Upper Row on plinth (y = 0.54, z = 0.16): Close-up Beer Mug (2 angles) & Hellfire Phial (idle + ignited)
    mug_a = build_tavern_mug(M)
    mug_a.location = (-0.82, 0.54, 0.16)
    mug_a.rotation_euler = Euler((math.radians(6.0), 0.0, math.radians(-16.0)))
    mug_a.scale = (2.30, 2.30, 2.30)

    mug_b = build_tavern_mug(M)
    mug_b.location = (-0.30, 0.54, 0.16)
    mug_b.rotation_euler = Euler((math.radians(14.0), 0.0, math.radians(125.0)))
    mug_b.scale = (2.25, 2.25, 2.25)

    phial_idle = build_hellfire_phial_hero(M, "PreviewPhialIdle")
    for ch in phial_idle.children_recursive:
        if ch.name == "IgnitedPlume" or (ch.parent and ch.parent.name == "IgnitedPlume"):
            ch.hide_render = True
    phial_idle.location = (0.28, 0.54, 0.16)
    phial_idle.rotation_euler = Euler((0.0, 0.0, math.radians(22.5)))
    phial_idle.scale = (2.10, 2.10, 2.10)

    phial_lit = build_hellfire_phial_hero(M, "PreviewPhialLit")
    phial_lit.location = (0.82, 0.54, 0.16)
    phial_lit.rotation_euler = Euler((math.radians(6.0), 0.0, math.radians(-22.5)))
    phial_lit.scale = (2.00, 2.00, 2.00)

    # Lower Foreground Row (y = -0.44): All 6 Hero Swords framed with zero overlap and full pommels visible!
    sword_builders = [
        build_sword_oath,
        build_sword_iron,
        build_sword_gilded,
        build_sword_crimson,
        build_sword_rune,
        build_sword_dragon,
    ]
    for idx, fn in enumerate(sword_builders):
        sw = fn(M)
        x = -0.825 + idx * 0.33
        sw.location = (x, -0.44, 0.07)
        sw.rotation_euler = Euler((math.radians(10.0), math.radians(-10.0), math.radians(-4.0)))
        sw.scale = (0.94, 0.94, 0.94)

    cam_d = bpy.data.cameras.new("HeroPreviewCam")
    cam_d.lens = 35.0
    cam_o = bpy.data.objects.new("HeroPreviewCam", cam_d)
    cam_o.location = (0.0, -1.96, 1.42)
    cam_o.rotation_euler = (Vector((0.0, 0.02, 0.16)) - cam_o.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam_o)
    scene.camera = cam_o

    lights = [
        ("KeyLight", (-1.8, -1.6, 2.3), 310.0, 2.8, (1.0, 0.88, 0.72)),
        ("FillLight", (2.0, -1.4, 1.6), 150.0, 3.2, (0.82, 0.90, 1.0)),
        ("TopSpecLight", (0.0, 0.5, 2.4), 230.0, 2.5, (1.0, 0.95, 0.86)),
    ]
    for lname, lpos, lenergy, lsize, lcol in lights:
        ld = bpy.data.lights.new(lname, "AREA")
        ld.energy = lenergy
        ld.size = lsize
        ld.color = lcol
        lo = bpy.data.objects.new(lname, ld)
        lo.location = lpos
        lo.rotation_euler = (Vector((0.0, -0.04, 0.12)) - lo.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)

    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    print(f"RENDERED_HERO_PREVIEW={PREVIEW_PATH}")


def main():
    # 1. Export sword_oath.glb + all 5 SWORD_*.glb
    reset_scene()
    M = get_mats()
    oath_root = build_sword_oath(M)
    export_glb(oath_root, MODELS_DIR / "sword_oath.glb")

    sword_skins = {
        "SWORD_IRON": build_sword_iron,
        "SWORD_GILDED": build_sword_gilded,
        "SWORD_CRIMSON": build_sword_crimson,
        "SWORD_RUNE": build_sword_rune,
        "SWORD_DRAGON": build_sword_dragon,
    }
    for sid, fn in sword_skins.items():
        reset_scene()
        M = get_mats()
        s_root = fn(M)
        export_glb(s_root, SWORDS_DIR / f"{sid}.glb")

    # 2. Export tavern_mug.glb
    reset_scene()
    M = get_mats()
    mug_root = build_tavern_mug(M)
    export_glb(mug_root, MODELS_DIR / "tavern_mug.glb")

    # 3. Export phial_ignis.glb & assets/models/vfx/hellfire_phial_hero.glb (both containing IgnitedPlume)
    for out_path in [MODELS_DIR / "phial_ignis.glb", VFX_DIR / "hellfire_phial_hero.glb"]:
        reset_scene()
        M = get_mats()
        p_root = build_hellfire_phial_hero(M, "HellfirePhialRoot")
        export_glb(p_root, out_path)

    # 4. Render studio close-up showcase contact sheet
    render_hero_contact_sheet()


if __name__ == "__main__":
    main()
