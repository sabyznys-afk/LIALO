import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_bl as cb


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def build_skull_and_jaw():
    cb.clear_scene()
    bone_mat = cb.make_pbr_mat("BoneAged", (0.86, 0.81, 0.70), roughness=0.58, metallic=0.04, subsurface=0.08)
    cavity_mat = cb.make_pbr_mat("SkullCavity", (0.015, 0.02, 0.035), roughness=0.95, metallic=0.0)
    tooth_mat = cb.make_pbr_mat("BoneTeeth", (0.94, 0.90, 0.80), roughness=0.28, metallic=0.03)

    # Remember: Blender +X=Godot +X, Blender -Y=Godot +Z (FRONT), Blender +Z=Godot +Y (UP)
    def skull_eval(nx, ny, nz):
        # Forward amount toward face (Blender -Y)
        fwd = -ny

        # Base anatomical cranial egg tapering gently toward chin/maxilla
        rx = 0.061
        ry = 0.072 if ny > 0.0 else 0.063  # elongated occipital back
        rz = 0.074 if nz > 0.0 else 0.060

        # Upper cranium parietal fullness vs narrowed lower face
        if nz > 0.0:
            rx *= 1.0 + 0.07 * math.sin(min(1.0, nz) * math.pi)
        else:
            t_low = min(1.0, -nz)
            rx *= 1.0 - 0.36 * (t_low ** 1.15)
            if fwd < 0.1:
                ry *= 1.0 - 0.32 * t_low

        x = nx * rx
        y = ny * ry
        z = nz * rz

        # Occipital bun & base skull curvature
        if ny > 0.25 and nz < -0.1:
            back_t = smoothstep(0.25, 0.85, ny) * smoothstep(-0.1, -0.75, nz)
            y -= back_t * 0.016
            z += back_t * 0.012

        # Temporal fossa hollows on sides of cranium
        side_t = smoothstep(0.50, 0.92, abs(nx)) * smoothstep(-0.25, 0.45, fwd) * (1.0 - smoothstep(0.22, 0.58, abs(nz - 0.14)))
        x -= math.copysign(side_t * 0.0085, nx)

        # Frontal bone + Glabella + Supraorbital Brow Arch
        if fwd > 0.15:
            brow_band = math.exp(-((nz - 0.26) / 0.11) ** 2) * smoothstep(0.0, 0.72, 0.78 - abs(nx))
            brow_curve = math.exp(-((abs(nx) - 0.28) / 0.22) ** 2) * 0.5 + 0.5
            y -= brow_band * brow_curve * 0.0115 * smoothstep(0.15, 0.65, fwd)
            z += brow_band * 0.002

        # Deep Anatomical Eye Orbits (rounded-trapezoid recessed sockets)
        orbit_depth = 0.0
        orbit_rim = 0.0
        for sx in (-1.0, 1.0):
            # Target normalized center of each eye socket (maps ~ x=+-0.026, z=+0.009)
            dx = (nx - sx * 0.37) / 0.21
            dz = (nz - 0.09 + (abs(nx) - 0.35) * 0.06) / 0.18
            # Slightly squared skull orbit metric
            dist_sq = (abs(dx) ** 2.4 + abs(dz) ** 2.4) ** (1.0 / 2.4)
            if fwd > 0.25:
                f_mask = smoothstep(0.25, 0.55, fwd)
                hole = (1.0 - smoothstep(0.55, 1.05, dist_sq)) * f_mask
                rim = math.exp(-((dist_sq - 1.06) / 0.16) ** 2) * f_mask
                orbit_depth = max(orbit_depth, hole)
                orbit_rim = max(orbit_rim, rim)
        y += orbit_depth * 0.025
        y -= orbit_rim * 0.0042

        # Nasal bridge (high) & Recessed Piriform Nasal Cavity (below bridge)
        if fwd > 0.35:
            f_mask = smoothstep(0.35, 0.72, fwd)
            nose_bridge = math.exp(-(nx / 0.105) ** 2) * math.exp(-((nz - 0.08) / 0.14) ** 2) * f_mask
            y -= nose_bridge * 0.0125

            # Inverted teardrop / piriform nasal cavity
            nasal_w = 0.11 + 0.05 * smoothstep(-0.02, -0.26, nz)
            nd_x = nx / nasal_w
            nd_z = (nz - (-0.13)) / 0.14
            nd = (abs(nd_x) ** 2.1 + abs(nd_z) ** 2.3) ** (1.0 / 2.2)
            nasal_hole = (1.0 - smoothstep(0.42, 0.96, nd)) * f_mask
            y += nasal_hole * 0.022
            nasal_rim = math.exp(-((nd - 1.02) / 0.14) ** 2) * f_mask
            y -= nasal_rim * 0.0028

        # Prominent Zygomatic Cheekbones & Infraorbital Buccal Hollows
        if fwd > 0.15:
            f_mask = smoothstep(0.15, 0.52, fwd)
            cheek = math.exp(-((abs(nx) - 0.56) / 0.16) ** 2) * math.exp(-((nz - (-0.11)) / 0.13) ** 2) * f_mask
            x += math.copysign(cheek * 0.0075, nx)
            y -= cheek * 0.0095

            # Sub-malar hollow below cheekbone
            hollow = math.exp(-((abs(nx) - 0.52) / 0.16) ** 2) * math.exp(-((nz - (-0.34)) / 0.15) ** 2) * f_mask
            x -= math.copysign(hollow * 0.0072, nx)
            y += hollow * 0.0075

        # Projecting U-shaped Upper Maxilla & Alveolar Tooth Ridge
        if nz < -0.24 and fwd > 0.05:
            max_z = smoothstep(-0.24, -0.58, nz)
            max_f = smoothstep(0.05, 0.52, fwd)
            arch = math.exp(-(nx / 0.44) ** 2)
            y -= max_z * max_f * arch * 0.0155
            # Tooth root flute ripples near the alveolar border
            root_rib = math.cos(nx * 24.0) * 0.0012 * smoothstep(-0.42, -0.68, nz) * max_f * arch
            y -= root_rib

        # Subtle Cranial Sutures (Sagittal + Coronal grooves)
        if nz > 0.35:
            sag = math.exp(-(nx / 0.022) ** 2) * smoothstep(0.35, 0.65, nz) * (1.0 - smoothstep(-0.2, -0.6, ny))
            cor = math.exp(-((ny + 0.04) / 0.026) ** 2) * smoothstep(0.45, 0.80, nz)
            suture_d = max(sag, cor) * (0.65 + 0.35 * math.sin(nx * 140.0 + ny * 140.0))
            z -= suture_d * 0.0014

        return (x, y, z)

    skull_obj = cb.create_icosphere_sculpted("CraniumSculpt", subdivisions=5, eval_fn=skull_eval, mat=bone_mat, smooth=True, uv_scale=8.0)

    # True anatomical open Zygomatic Arches spanning from cheekbones to temporal bone
    for sx in (-1.0, 1.0):
        arch_pts = [
            (sx * 0.038, -0.044, -0.012),
            (sx * 0.051, -0.032, -0.014),
            (sx * 0.056, -0.014, -0.012),
            (sx * 0.055, +0.006, -0.008),
            (sx * 0.050, +0.020, -0.005),
        ]
        cb.tube_along_points(
            f"ZygomaticArch_{'L' if sx < 0 else 'R'}",
            arch_pts,
            [0.0055, 0.0062, 0.0050, 0.0046, 0.0052],
            ring_segs=10,
            mat=bone_mat,
            scale_xy_fn=lambda i, n: (0.65, 1.25),
        )

    # Thin central nasal vomer septum inside the piriform nasal cavity
    cb.make_box("NasalSeptum", (0.0022, 0.016, 0.020), center_xyz=(0.0, -0.050, -0.009), mat=bone_mat, bevel_w=0.0005)

    # Dark inner backing cups inside orbital sockets & nasal cavity so hollows look deeply shadowed
    for sx in (-1.0, 1.0):
        cb.make_sphere(
            f"OrbitShadow_{'L' if sx < 0 else 'R'}",
            0.0185,
            segments=16,
            rings=10,
            center_xyz=(sx * 0.0255, -0.046, 0.008),
            scale_xyz=(1.02, 0.55, 0.88),
            mat=cavity_mat,
        )
    cb.make_sphere(
        "NasalShadow",
        0.010,
        segments=14,
        rings=10,
        center_xyz=(0.0, -0.049, -0.009),
        scale_xyz=(0.82, 0.65, 1.35),
        mat=cavity_mat,
    )

    # Sculpted Upper Teeth (10 individual rounded beveled enamel teeth along maxilla arch)
    for ti in range(10):
        ang = -1.05 + (float(ti) / 9.0) * 2.10
        tx = math.sin(ang) * 0.0275
        ty = -0.036 - math.cos(ang) * 0.0245  # Blender -Y = front
        is_canine = (abs(ang) > 0.34 and abs(ang) < 0.56)
        w = 0.0048 if ti not in (4, 5) else 0.0056
        h = 0.0115 if is_canine else (0.0105 if ti in (4, 5) else 0.0090)
        d = 0.0056
        tooth = cb.make_box(
            f"MaxillaTooth_{ti}",
            (w, d, h),
            center_xyz=(tx, ty, -0.043 - (0.0012 if is_canine else 0.0)),
            mat=tooth_mat,
            bevel_w=0.0014,
            rot_deg=(6.0, 0.0, math.degrees(-ang)),
        )
        cb.set_obj_smooth(tooth, True)

    cb.export_glb("ghost_skull.glb")

    # ------------------------------------------------------------------
    # 2. GHOST LOWER MANDIBLE & TEETH (hinged at origin -> tutorial_ghost_jaw_root)
    # Relative to skull: tutorial_ghost_jaw_root is at (0, -0.034, +0.014) Godot
    # = (0, -0.014, -0.034) Blender relative to skull center!
    # So to align with upper teeth at (-0.0605 Front Y_bl, -0.048 Z_bl relative to skull),
    # jaw-local coords target Y_bl = -0.0465, Z_bl = -0.018!
    # ------------------------------------------------------------------
    cb.clear_scene()
    bone_mat = cb.make_pbr_mat("BoneAged", (0.86, 0.81, 0.70), roughness=0.58, metallic=0.04, subsurface=0.08)
    tooth_mat = cb.make_pbr_mat("BoneTeeth", (0.94, 0.90, 0.80), roughness=0.28, metallic=0.03)

    jaw_pts = [
        (-0.040, +0.004, +0.008),   # L Condyle pivot
        (-0.037, -0.002, -0.016),   # L Ramus
        (-0.034, -0.010, -0.025),   # L Gonial angle
        (-0.027, -0.030, -0.028),   # L Body
        (-0.014, -0.045, -0.030),   # L Parasymphysis
        (0.000, -0.049, -0.031),    # Chin symphysis
        (+0.014, -0.045, -0.030),   # R Parasymphysis
        (+0.027, -0.030, -0.028),   # R Body
        (+0.034, -0.010, -0.025),   # R Gonial angle
        (+0.037, -0.002, -0.016),   # R Ramus
        (+0.040, +0.004, +0.008),   # R Condyle pivot
    ]
    jaw_rads = [0.0050, 0.0072, 0.0092, 0.0088, 0.0092, 0.0102, 0.0092, 0.0088, 0.0092, 0.0072, 0.0050]
    cb.tube_along_points(
        "MandibleBody",
        jaw_pts,
        jaw_rads,
        ring_segs=14,
        mat=bone_mat,
        cap_ends=True,
        scale_xy_fn=lambda i, n: (0.72, 1.32) if 2 <= i <= 8 else (1.15, 0.68),
    )

    # Sculpted protruding square Chin (Mental Protuberance)
    cb.make_sphere("ChinBoss", 0.012, segments=16, rings=10, center_xyz=(0.0, -0.050, -0.033), scale_xyz=(1.22, 0.85, 0.92), mat=bone_mat)

    # Lower 8 sculpted beveled teeth
    for ti in range(8):
        ang = -0.92 + (float(ti) / 7.0) * 1.84
        tx = math.sin(ang) * 0.0235
        ty = -0.024 - math.cos(ang) * 0.0225
        is_canine = (ti in (1, 6))
        t_obj = cb.make_box(
            f"MandibleTooth_{ti}",
            (0.0046, 0.0052, 0.0095 if is_canine else 0.0082),
            center_xyz=(tx, ty, -0.0175 + (0.001 if is_canine else 0.0)),
            mat=tooth_mat,
            bevel_w=0.0012,
            rot_deg=(-8.0, 0.0, math.degrees(-ang)),
        )
        cb.set_obj_smooth(t_obj, True)

    cb.export_glb("ghost_jaw.glb")


def build_shroud():
    cb.clear_scene()
    shroud_mat = cb.make_pbr_mat("ShroudPhantom", (0.28, 0.68, 0.90), roughness=0.38, alpha=0.55, double_sided=True)
    clasp_mat = cb.make_pbr_mat("ShroudClasp", (0.78, 0.92, 1.0), roughness=0.22, metallic=0.88, emission=(0.40, 0.88, 1.0), emission_strength=1.1)

    nu = 64
    nv = 40

    def shroud_eval(u, v):
        # v: 0.0 = hood apex (top), 1.0 = tattered bottom hem
        # In Godot UV: UV.y goes 0.0 top -> 1.0 bottom for phantom_shader!
        # Map Blender v (0 top -> 1 bottom) directly.
        t_up = 1.0 - v  # 0.0 bottom -> 1.0 top
        z_bl = -0.08 + t_up * 0.96  # -0.08 .. +0.88

        ang = u * math.tau
        # Front in Blender is -Y -> at ang = pi*0.5: sin=1 -> we want front = -y!
        # Let x = cos(ang)*r, y = -sin(ang)*r so front (ang=pi*0.5) is -y (Godot +Z)!
        front_w = max(0.0, math.sin(ang))

        if t_up < 0.34:
            tt = smoothstep(0.0, 0.34, t_up)
            base_r = 0.088 + (0.172 - 0.088) * tt
        elif t_up < 0.56:
            tt = smoothstep(0.36, 0.56, t_up)
            base_r = 0.165 + (0.205 - 0.165) * math.sin(tt * math.pi * 0.5)
        elif t_up < 0.67:
            tt = smoothstep(0.56, 0.67, t_up)
            base_r = 0.205 + (0.128 - 0.205) * tt
        elif t_up < 0.89:
            tt = smoothstep(0.67, 0.89, t_up)
            arch = math.sin(tt * math.pi)
            base_r = 0.128 + (0.086 - 0.128) * tt + arch * 0.042
        else:
            tt = smoothstep(0.89, 1.0, t_up)
            base_r = 0.086 + (0.006 - 0.086) * tt

        # Deep flowing gothic vertical cloth folds
        pleat_env = smoothstep(0.66, 0.22, t_up)
        pleat = (0.024 * math.sin(ang * 9.0 + t_up * 4.5) + 0.011 * math.cos(ang * 14.0 - t_up * 3.0)) * pleat_env

        # Dramatic jagged torn lower cloak ribbons
        tail_mask = max(0.0, 1.0 - t_up * 2.55) ** 1.35
        hem_tatter = (0.075 * math.sin(ang * 7.0) + 0.042 * math.cos(ang * 11.0 + 0.6) + 0.022 * math.sin(ang * 15.0)) * tail_mask
        tail_curl = math.sin(t_up * 7.8 + ang * 2.0) * 0.028 * tail_mask

        r = max(0.008, base_r + pleat)
        px = math.cos(ang) * r
        # Pointed gothic hood sweeps forward slightly over skull brow, tapering up cleanly!
        hood_sweep = (max(0.0, (t_up - 0.68) / 0.32) ** 1.35) * 0.095
        py = -math.sin(ang) * r * 0.88 - tail_curl + hood_sweep  # remember front is -y!
        pz = z_bl + hem_tatter

        # Sculpted Gothic Hood Face Aperture opening cleanly forward around skull at (0, -0.048_bl, 0.675_bl)
        if 0.66 < t_up < 0.91 and front_w > 0.25:
            hood_arch = math.sin(min(1.0, max(0.0, (t_up - 0.66) / 0.25)) * math.pi)
            face_depth = smoothstep(0.25, 0.85, front_w) * hood_arch
            # Push the front cowl back slightly (+y) to open a crisp hooded cowl frame around the skull!
            py += face_depth * 0.125
            px *= 1.0 + 0.10 * hood_arch * (1.0 - face_depth)
            # Crisp raised cowl fold edge around face
            cowl_lip = math.exp(-((front_w - 0.32) / 0.12) ** 2) * hood_arch
            py -= cowl_lip * 0.022

        return (px, py, pz)

    def shroud_uv(u, v):
        # glTF UV origin: flip Blender V so Godot reads UV.y = 0 at hood peak -> 1 at tattered bottom hem
        return (u, 1.0 - v)

    shroud_outer = cb.grid_cloth("ShroudOuter", nu, nv, shroud_eval, uv_fn=shroud_uv, mat=shroud_mat, closed_u=True, smooth=True)
    cb.add_subsurf(shroud_outer, levels=1)

    # Inner spectral cowl lining slightly offset back for ghostly depth
    inner_layer = cb.grid_cloth(
        "ShroudInner",
        40,
        24,
        lambda u, v: (shroud_eval(u, v)[0] * 0.90, shroud_eval(u, v)[1] * 0.90 + 0.012, shroud_eval(u, v)[2] + 0.01),
        uv_fn=shroud_uv,
        mat=shroud_mat,
        closed_u=True,
        smooth=True,
    )

    # Ornate Gothic Cloak Clasp / Pin at chest throat (Godot y=0.565, z=+0.115 -> Blender y=-0.115, z=0.565)
    cb.extrude_poly_3d(
        "ShroudClasp",
        [
            (0.0, 0.024),
            (0.010, 0.009),
            (0.028, 0.005),
            (0.014, -0.008),
            (0.0, -0.026),
            (-0.014, -0.008),
            (-0.028, 0.005),
            (-0.010, 0.009),
        ],
        depth=0.008,
        axis="Y",
        mat=clasp_mat,
        smooth=True,
        bevel_w=0.0018,
    )
    clasp = bpy.data.objects["ShroudClasp"]
    clasp.location = (0.0, -0.112, 0.565)

    cb.export_glb("ghost_shroud.glb")


def build_lantern_and_hands():
    # ------------------------------------------------------------------
    # GHOST LANTERN (Origin at lantern center; handle ring top at +0.095 Z_bl)
    # ------------------------------------------------------------------
    cb.clear_scene()
    iron_mat = cb.make_pbr_mat("LanternIron", (0.14, 0.15, 0.18), roughness=0.40, metallic=0.85)
    brass_mat = cb.make_pbr_mat("LanternBrass", (0.86, 0.66, 0.24), roughness=0.28, metallic=0.90)
    glass_mat = cb.make_pbr_mat("LanternGlass", (0.48, 0.92, 1.0), roughness=0.14, alpha=0.42, emission=(0.35, 0.88, 1.0), emission_strength=1.4)
    core_mat = cb.make_pbr_mat("LanternCore", (0.75, 0.98, 1.0), roughness=0.10, emission=(1.0, 0.86, 0.42), emission_strength=4.5)

    # Lathe pagoda roof + finial spire
    roof_prof = [
        (0.056, 0.045),
        (0.058, 0.049),
        (0.044, 0.058),
        (0.024, 0.072),
        (0.012, 0.084),
        (0.015, 0.092),
        (0.005, 0.104),
    ]
    cb.lathe_profile("LanternHood", roof_prof, segments=6, mat=iron_mat, smooth=False)
    cb.add_bevel(bpy.data.objects["LanternHood"], width=0.0018, segments=1)

    base_prof = [
        (0.008, -0.085),
        (0.024, -0.074),
        (0.042, -0.062),
        (0.052, -0.050),
        (0.050, -0.044),
    ]
    cb.lathe_profile("LanternBase", base_prof, segments=6, mat=iron_mat, smooth=False)
    cb.add_bevel(bpy.data.objects["LanternBase"], width=0.0016, segments=1)

    # Top suspension ring
    ring_pts = [(math.cos(a) * 0.014, 0.0, 0.114 + math.sin(a) * 0.014) for a in [i * math.tau / 16.0 for i in range(17)]]
    cb.tube_along_points("LanternRing", ring_pts, 0.0032, ring_segs=8, mat=brass_mat, cap_ends=False)

    # 6 Curved forged corner ribs with brass rivets
    for bi in range(6):
        ang = bi * (math.tau / 6.0)
        ca, sa = math.cos(ang), math.sin(ang)
        rib_pts = [
            (ca * 0.052, sa * 0.052, 0.048),
            (ca * 0.056, sa * 0.056, 0.018),
            (ca * 0.054, sa * 0.054, -0.018),
            (ca * 0.048, sa * 0.048, -0.046),
        ]
        cb.tube_along_points(f"LanternRib_{bi}", rib_pts, 0.0034, ring_segs=8, mat=brass_mat if bi % 2 == 0 else iron_mat)

    # Hexagonal beveled spirit glass vessel
    cb.lathe_profile("LanternGlass", [(0.038, -0.042), (0.044, -0.012), (0.045, 0.020), (0.039, 0.044)], segments=6, mat=glass_mat, smooth=True)

    # Teardrop soul flame core inside
    cb.lathe_profile(
        "LanternCore",
        [(0.002, -0.025), (0.018, -0.014), (0.022, 0.0), (0.014, 0.018), (0.002, 0.032)],
        segments=14,
        mat=core_mat,
        smooth=True,
    )

    cb.export_glb("ghost_lantern.glb")

    # ------------------------------------------------------------------
    # GHOST RIGHT HAND & SLEEVE (holding lantern) + LEFT BECKONING HAND
    # ------------------------------------------------------------------
    def make_spectral_hand_glb(fname, is_right=True):
        cb.clear_scene()
        sleeve_mat = cb.make_pbr_mat("GhostSleeve", (0.28, 0.68, 0.90), roughness=0.40, alpha=0.55, double_sided=True)
        hand_mat = cb.make_pbr_mat("SpectralBone", (0.78, 0.95, 1.0), roughness=0.35, alpha=0.72, emission=(0.40, 0.88, 1.0), emission_strength=0.95)

        sx = 1.0 if is_right else -1.0
        # Flared draped sleeve reaching forward (-Y in Blender = +Z in Godot)
        sleeve_pts = [
            (0.0, 0.0, 0.0),
            (sx * 0.015, -0.065, -0.030),
            (sx * 0.028, -0.145, -0.055),
            (sx * 0.036, -0.195, -0.065),
        ]
        cb.tube_along_points("GhostSleeve", sleeve_pts, [0.028, 0.040, 0.056, 0.068], ring_segs=18, mat=sleeve_mat)

        # Articulated metacarpal palm & 5 skeletal finger phalanges
        palm_pos = (sx * 0.038, -0.205, -0.066)
        cb.make_sphere("SpectralPalm", 0.020, segments=14, rings=10, center_xyz=palm_pos, scale_xyz=(1.05, 1.25, 0.65), mat=hand_mat)

        for fi in range(4):
            f_off = (fi - 1.5) * 0.010
            p0 = (palm_pos[0] + f_off, palm_pos[1] - 0.012, palm_pos[2] - 0.002)
            curl_z = -0.024 if is_right else -0.005
            p1 = (p0[0] + f_off * 0.15, p0[1] - 0.020, p0[2] + curl_z * 0.45)
            p2 = (p1[0] + f_off * 0.15, p1[1] - 0.014 if not is_right else p1[1] - 0.004, p1[2] + curl_z * 0.85)
            cb.tube_along_points(f"Finger_{fi}", [p0, p1, p2], [0.0042, 0.0034, 0.0022], ring_segs=8, mat=hand_mat)
        # Thumb
        t0 = (palm_pos[0] - sx * 0.016, palm_pos[1] - 0.004, palm_pos[2] + 0.004)
        t1 = (t0[0] - sx * 0.012, t0[1] - 0.015, t0[2] - 0.008)
        t2 = (t1[0] - sx * 0.006, t1[1] - 0.010, t1[2] - 0.010)
        cb.tube_along_points("Thumb", [t0, t1, t2], [0.0045, 0.0036, 0.0025], ring_segs=8, mat=hand_mat)

        cb.export_glb(fname)

    make_spectral_hand_glb("ghost_hand_r.glb", is_right=True)
    make_spectral_hand_glb("ghost_hand_l.glb", is_right=False)


if __name__ == "__main__":
    build_skull_and_jaw()
    build_shroud()
    build_lantern_and_hands()
    print("[GEN_GHOST_ASSETS_DONE]")
