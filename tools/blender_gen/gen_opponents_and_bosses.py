import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_bl as cb


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def build_base_opponent_parts():
    # ==================================================================
    # 1. SCULPTED ANATOMICAL OPPONENT HEAD (Origin matches opp_head_node)
    # Godot eyes sit at (+-0.038, +0.106, +0.106) -> Blender (+-0.038, -0.106, +0.106)
    # ==================================================================
    cb.clear_scene()
    skin_mat = cb.make_pbr_mat("SkinHeadMat", (0.74, 0.56, 0.44), roughness=0.55, subsurface=0.12)
    brow_mat = cb.make_pbr_mat("BrowsMat", (0.14, 0.10, 0.08), roughness=0.72)

    def face_eval(nx, ny, nz):
        fwd = -ny  # Blender -Y = Godot +Z (FRONT)
        # Base head oval centered around z_bl = +0.106, width ~ 0.094, depth ~ 0.110
        rx = 0.094
        ry = 0.110 if ny > 0.0 else 0.102
        rz = 0.112

        # Narrow gracefully below cheekbones into defined masculine/noble jawline
        if nz < 0.0:
            t = min(1.0, -nz)
            rx *= 1.0 - 0.30 * (t ** 1.15)
            if fwd < 0.2:
                ry *= 1.0 - 0.22 * t

        x = nx * rx
        y = ny * ry
        z = 0.104 + nz * rz

        # Face sculpting when facing forward
        if fwd > 0.10:
            fm = smoothstep(0.10, 0.55, fwd)
            # Stern Supraorbital Brow Ridge (z ~ +0.132, nz ~ +0.25)
            brow = math.exp(-((nz - 0.24) / 0.10) ** 2) * smoothstep(0.0, 0.65, 0.72 - abs(nx))
            y -= brow * 0.011 * fm

            # Recessed Orbital Sockets (centered around x=+-0.038, z=+0.106 -> nz ~ +0.02, nx ~ +-0.40)
            # So Godot's eye spheres at z_godot=0.106 (y_bl=-0.106) nestle inside without z-fighting!
            sock = 0.0
            for sx in (-1.0, 1.0):
                dx = (nx - sx * 0.39) / 0.17
                dz = (nz - 0.02) / 0.13
                d2 = dx * dx + dz * dz
                sock = max(sock, math.exp(-d2 * 1.45))
            y += sock * 0.022 * fm

            # Strong Aquiline Nose Bridge & Nasal Tip (z ~ +0.068..+0.110 -> nz ~ -0.32..+0.08)
            nose_line = math.exp(-(nx / 0.095) ** 2) * smoothstep(0.28, -0.05, nz) * smoothstep(-0.46, -0.22, nz)
            nose_peak = math.exp(-((nz + 0.18) / 0.14) ** 2)
            y -= nose_line * (0.012 + 0.015 * nose_peak) * fm
            # Nasal wings (alar flares)
            alae = math.exp(-((abs(nx) - 0.13) / 0.07) ** 2) * math.exp(-((nz + 0.26) / 0.09) ** 2)
            y -= alae * 0.008 * fm

            # Sculpted Zygomatic Cheekbones & Hollow Cheeks
            cheek = math.exp(-((abs(nx) - 0.52) / 0.16) ** 2) * math.exp(-((nz + 0.20) / 0.14) ** 2)
            y -= cheek * 0.0075 * fm
            x += math.copysign(cheek * 0.004 * fm, nx)

            hollow = math.exp(-((abs(nx) - 0.46) / 0.16) ** 2) * math.exp(-((nz + 0.48) / 0.16) ** 2)
            y += hollow * 0.0065 * fm
            x -= math.copysign(hollow * 0.004 * fm, nx)

            # Upper & Lower Lips + Chin Prominence
            lip_arch = math.exp(-(nx / 0.24) ** 2) * fm
            upper_lip = math.exp(-((nz + 0.46) / 0.055) ** 2) * lip_arch
            lower_lip = math.exp(-((nz + 0.58) / 0.055) ** 2) * lip_arch
            mouth_crease = math.exp(-((nz + 0.52) / 0.025) ** 2) * math.exp(-(nx / 0.20) ** 2) * fm
            y -= (upper_lip * 0.007 + lower_lip * 0.006)
            y += mouth_crease * 0.005

            chin = math.exp(-(nx / 0.22) ** 2) * math.exp(-((nz + 0.80) / 0.12) ** 2) * fm
            y -= chin * 0.011
            z -= chin * 0.004

        return (x, y, z)

    cb.create_icosphere_sculpted("SkinHead", subdivisions=4, eval_fn=face_eval, mat=skin_mat, smooth=True, uv_scale=4.0)

    # Sculpted Anatomical Ears
    for sx in (-1.0, 1.0):
        cb.make_sphere(f"SkinEar_{'L' if sx < 0 else 'R'}", 0.022, segments=12, rings=8, center_xyz=(sx * 0.092, 0.004, 0.098), scale_xyz=(0.38, 0.65, 1.05), mat=skin_mat, rot_deg=(0, sx * 12.0, -sx * 10.0))

    # Proportional Sculpted Neck blending cleanly into collar
    cb.lathe_profile("SkinNeck", [(0.072, -0.048), (0.064, -0.008), (0.062, 0.026)], segments=20, mat=skin_mat)

    # Sculpted Expressive Furrowed Eyebrows (named Brows for hair color matching)
    for sx in (-1.0, 1.0):
        brow_pts = [
            (sx * 0.016, -0.105, 0.124),
            (sx * 0.036, -0.106, 0.132),
            (sx * 0.058, -0.094, 0.130),
        ]
        cb.tube_along_points(f"Brows_{'L' if sx < 0 else 'R'}", brow_pts, [0.0065, 0.0072, 0.0042], ring_segs=8, mat=brow_mat, scale_xy_fn=lambda i, n: (1.0, 0.7))

    cb.export_glb("opp_head.glb")

    # ==================================================================
    # 2. SCULPTED ANATOMICAL UPPER TORSO & CLOAK (opp_torso.glb)
    # Named parts: CoatBody, CoatTrim, ShirtInner, BeltStrap, BeltBuckle, MantleCloak
    # ==================================================================
    cb.clear_scene()
    coat_mat = cb.make_pbr_mat("CoatBodyMat", (0.24, 0.14, 0.14), roughness=0.62)
    trim_mat = cb.make_pbr_mat("CoatTrimMat", (0.48, 0.14, 0.18), roughness=0.52)
    shirt_mat = cb.make_pbr_mat("ShirtInnerMat", (0.88, 0.84, 0.76), roughness=0.72)
    belt_mat = cb.make_pbr_mat("BeltStrapMat", (0.20, 0.12, 0.07), roughness=0.50)
    buckle_mat = cb.make_pbr_mat("BeltBuckleMat", (0.86, 0.66, 0.24), roughness=0.26, metallic=0.90)
    cloak_mat = cb.make_pbr_mat("MantleCloakMat", (0.16, 0.09, 0.10), roughness=0.78, double_sided=True)

    # Contoured Anatomical Torso Mesh (y_godot 0.0..0.55)
    nu, nv = 36, 18
    def torso_eval(u, v):
        ang = u * math.tau
        # v: 0 waist (z=0.0) -> 1 collar base (z=0.55)
        z = v * 0.55
        if v < 0.28:
            # Subtle flared coat bottom over waist
            t = v / 0.28
            rx = 0.22 - 0.025 * math.sin(t * math.pi * 0.5)
            ry = 0.145 - 0.015 * math.sin(t * math.pi * 0.5)
        elif v < 0.80:
            # Athletic V-taper broadening to chest & broad shoulders
            t = (v - 0.28) / 0.52
            rx = 0.195 + 0.088 * smoothstep(0.0, 1.0, t)
            ry = 0.130 + 0.036 * math.sin(t * math.pi * 0.65)
        else:
            # Slope cleanly inward into collar neck opening
            t = (v - 0.80) / 0.20
            rx = 0.283 * (1.0 - t) + 0.082 * t
            ry = 0.155 * (1.0 - t) + 0.072 * t

        ca, sa = math.cos(ang), math.sin(ang)
        px = ca * rx
        py = -sa * ry  # front = -Y Blender
        # Anatomical chest pectoral curve (front) & subtle spinal hollow (back)
        if sa > 0.2 and 0.48 < v < 0.86:
            pect = math.sin(smoothstep(0.48, 0.86, v) * math.pi) * (sa ** 1.5)
            py -= pect * 0.024
        if sa < -0.35 and 0.35 < v < 0.85:
            py -= 0.012 * abs(sa) * math.exp(-(ca / 0.28) ** 2)
        return (px, py, z)

    cb.grid_cloth("CoatBody", nu, nv, torso_eval, mat=coat_mat, closed_u=True, smooth=True)

    # Standing Tailored Collar Ring & Structured Folded Lapels (CoatTrim)
    cb.lathe_profile("CoatTrimCollar", [(0.098, 0.525), (0.106, 0.545), (0.095, 0.585), (0.082, 0.585)], segments=24, mat=trim_mat)
    for sx in (-1.0, 1.0):
        l_pts = [
            (sx * 0.088, -0.068, 0.545),
            (sx * 0.095, -0.145, 0.455),
            (sx * 0.068, -0.162, 0.360),
            (sx * 0.032, -0.156, 0.275),
        ]
        cb.tube_along_points(f"CoatTrimLapel_{'L' if sx < 0 else 'R'}", l_pts, [0.024, 0.032, 0.026, 0.016], ring_segs=8, mat=trim_mat, scale_xy_fn=lambda i, n: (1.25, 0.38))
        # Rounded Tailored Shoulder Caps blending naturally with coat
        cb.make_sphere(f"CoatTrimShoulder_{'L' if sx < 0 else 'R'}", 0.068, segments=16, rings=10, center_xyz=(sx * 0.258, 0.0, 0.468), scale_xyz=(0.95, 0.92, 0.80), mat=coat_mat)

    # V-Neck Inner Shirt Front
    cb.extrude_poly_3d("ShirtInner", [(-0.072, 0.54), (0.072, 0.54), (0.042, 0.39), (0.0, 0.28), (-0.042, 0.39)], depth=0.04, axis="Y", mat=shirt_mat, bevel_w=0.008).location = (0.0, -0.135, 0.0)

    # Heavy Waist Belt & Embossed Ornate Buckle (z = 0.165)
    cb.grid_cloth("BeltStrap", 28, 4, lambda u, v: (math.cos(u * math.tau) * 0.206, -math.sin(u * math.tau) * 0.138, 0.135 + v * 0.060), mat=belt_mat, closed_u=True, smooth=True)
    cb.make_box("BeltBuckle", (0.068, 0.022, 0.074), center_xyz=(0.0, -0.144, 0.165), mat=buckle_mat, bevel_w=0.006)
    cb.make_box("BeltBuckleInner", (0.036, 0.026, 0.042), center_xyz=(0.0, -0.145, 0.165), mat=belt_mat, bevel_w=0.003)

    # Flowing Draped Back Mantle Cloak falling naturally with gravity ripples behind back!
    def cloak_eval(u, v):
        un = (u - 0.5) * 2.0  # -1..+1 left-to-right across shoulders
        w = 0.28 + 0.11 * (v ** 0.75)
        px = un * w
        pz = 0.53 - v * 0.54
        fold = 0.018 * math.sin(un * math.pi * 3.0 + v * 2.2) * (0.25 + 0.75 * v)
        curve_back = 0.095 + 0.08 * math.sin(v * math.pi * 0.65) + 0.06 * (1.0 - un * un)
        py = curve_back + fold  # +Y Blender = behind back in Godot (-Z)!
        return (px, py, pz)

    cb.grid_cloth("MantleCloak", 24, 18, cloak_eval, mat=cloak_mat, closed_u=False, smooth=True)

    cb.export_glb("opp_torso.glb")

    # ==================================================================
    # 3. SCULPTED ARTICULATED OPPONENT ARMS (opp_arm_l.glb & opp_arm_r.glb)
    # Origin at shoulder joint (opp_arm_left_node / right_node at y=0.44)
    # Reaching down & forward toward tabletop (-Z_bl down, -Y_bl forward!)
    # ==================================================================
    for side, fname in ((-1.0, "opp_arm_l.glb"), (1.0, "opp_arm_r.glb")):
        cb.clear_scene()
        coat_mat = cb.make_pbr_mat("ArmCoatMat", (0.24, 0.14, 0.14), roughness=0.62)
        cuff_mat = cb.make_pbr_mat("ArmCuffMat", (0.48, 0.14, 0.18), roughness=0.42, metallic=0.25)
        hand_mat = cb.make_pbr_mat("ArmHandMat", (0.74, 0.56, 0.44), roughness=0.55)

        arm_pts = [
            (0.0, 0.0, 0.0),
            (side * 0.025, -0.055, -0.105),
            (-side * 0.025, -0.145, -0.195),   # elbow bent forward toward table!
            (-side * 0.072, -0.265, -0.205),
            (-side * 0.105, -0.365, -0.215),   # wrist near table!
        ]
        cb.tube_along_points("ArmSleeve", arm_pts, [0.064, 0.056, 0.050, 0.044, 0.038], ring_segs=16, mat=coat_mat)
        # Flared Folded Arm Cuff / Bracer
        cuff_pts = [(-side * 0.088, -0.315, -0.210), (-side * 0.108, -0.372, -0.215)]
        cb.tube_along_points("ArmCuff", cuff_pts, [0.048, 0.044], ring_segs=16, mat=cuff_mat)

        # Articulated Palm + 5 Curved Fingers hovering poised over Opponent's Table Zone
        p_c = (-side * 0.118, -0.405, -0.218)
        cb.make_sphere("ArmHandPalm", 0.028, segments=14, rings=10, center_xyz=p_c, scale_xyz=(1.05, 1.25, 0.62), mat=hand_mat, rot_deg=(0, 0, -side * 16.0))
        for fi in range(4):
            foff = (fi - 1.5) * 0.014
            fp0 = (p_c[0] + foff, p_c[1] - 0.024, p_c[2])
            fp1 = (p_c[0] + foff, p_c[1] - 0.052, p_c[2] - 0.012)
            fp2 = (p_c[0] + foff, p_c[1] - 0.072, p_c[2] - 0.026)
            cb.tube_along_points(f"ArmHandFinger_{fi}", [fp0, fp1, fp2], [0.0068, 0.0055, 0.0040], ring_segs=8, mat=hand_mat)
        t0 = (p_c[0] - side * 0.024, p_c[1] - 0.010, p_c[2] - 0.004)
        t1 = (p_c[0] - side * 0.042, p_c[1] - 0.036, p_c[2] - 0.014)
        cb.tube_along_points("ArmHandThumb", [t0, t1], [0.0075, 0.0050], ring_segs=8, mat=hand_mat)

        cb.export_glb(fname)


def build_campaign_boss_regalia():
    # ==================================================================
    # BOSS 1: KING CHARLES IV (Medieval Bohemia)
    # ==================================================================
    cb.clear_scene()
    gold_mat = cb.make_pbr_mat("BossGold", (0.94, 0.74, 0.24), roughness=0.20, metallic=0.92)
    hair_mat = cb.make_pbr_mat("BossHair", (0.20, 0.14, 0.10), roughness=0.76)
    ruby_mat = cb.make_pbr_mat("BossRuby", (0.92, 0.10, 0.18), roughness=0.10, metallic=0.15, emission=(0.75, 0.08, 0.12), emission_strength=1.2)
    sapphire_mat = cb.make_pbr_mat("BossSapphire", (0.14, 0.45, 0.96), roughness=0.10, metallic=0.15, emission=(0.12, 0.40, 0.90), emission_strength=1.1)

    # Flowing sculpted royal locks framing sides & back of head
    for sx in (-1.0, 1.0):
        cb.tube_along_points(
            f"CharlesHair_{'L' if sx < 0 else 'R'}",
            [(sx * 0.075, 0.02, 0.16), (sx * 0.102, 0.025, 0.09), (sx * 0.105, 0.032, 0.01), (sx * 0.092, 0.038, -0.05)],
            [0.032, 0.036, 0.034, 0.022],
            ring_segs=10,
            mat=hair_mat,
        )
    cb.make_sphere("CharlesHairBack", 0.105, segments=16, rings=10, center_xyz=(0.0, 0.028, 0.115), scale_xyz=(0.98, 0.95, 1.05), mat=hair_mat)

    # Curled royal Mustache + sculpted Full Pointed Beard (leaving upper mouth/eyes crisp!)
    for sx in (-1.0, 1.0):
        cb.tube_along_points(
            f"CharlesStache_{'L' if sx < 0 else 'R'}",
            [(0.0, -0.104, 0.056), (sx * 0.022, -0.100, 0.052), (sx * 0.044, -0.086, 0.046)],
            [0.0085, 0.0095, 0.0045],
            ring_segs=8,
            mat=hair_mat,
        )
    # Sculpted goatee/full beard hugging chin
    cb.lathe_profile(
        "CharlesBeard",
        [(0.012, -0.095), (0.042, -0.055), (0.068, -0.010), (0.072, 0.025)],
        segments=16,
        mat=hair_mat,
        radial_fn=lambda r, z, ang, ri, np_: (math.cos(ang) * r * 0.88, -0.042 + math.sin(ang) * r * 0.68, z),
    )

    # St. Wenceslas Crown seated cleanly at z = 0.175 .. 0.365 (above eyes at z=0.106!)
    crown_z = 0.180
    cb.lathe_profile("CrownCirclet", [(0.108, crown_z), (0.114, crown_z + 0.008), (0.116, crown_z + 0.052), (0.110, crown_z + 0.058), (0.102, crown_z + 0.052)], segments=16, mat=gold_mat, smooth=False)
    # 4 High-relief Sculpted Fleur-de-Lis Spires around circlet
    fleur_2d = [(0.0, 0.0), (0.018, 0.022), (0.036, 0.018), (0.028, 0.045), (0.012, 0.042), (0.016, 0.068), (0.0, 0.092), (-0.016, 0.068), (-0.012, 0.042), (-0.028, 0.045), (-0.036, 0.018), (-0.018, 0.022)]
    for fi in range(4):
        ang = (fi / 4.0) * math.tau
        fl = cb.extrude_poly_3d(f"CrownFleur_{fi}", fleur_2d, depth=0.016, axis="Y", mat=gold_mat, bevel_w=0.002)
        fl.location = (math.sin(ang) * 0.112, -math.cos(ang) * 0.112, crown_z + 0.046)
        fl.rotation_euler = (0.0, 0.0, ang)
        # Bezel-set crown jewels between spires
        ja = ang + math.pi * 0.25
        cb.make_sphere(f"CrownJewel_{fi}", 0.014, segments=10, rings=6, center_xyz=(math.sin(ja) * 0.116, -math.cos(ja) * 0.116, crown_z + 0.028), scale_xyz=(1, 0.6, 1.2), mat=ruby_mat if fi % 2 == 0 else sapphire_mat)

    # 2 Crossed Arched Gold Crown Bows + Royal Orb + Finial Cross
    for bi in range(2):
        ang = bi * math.pi * 0.5
        ca, sa = math.cos(ang), math.sin(ang)
        bow_pts = []
        for si in range(13):
            t = (si / 12.0 - 0.5) * math.pi
            r_x = math.sin(t) * 0.106
            z_b = crown_z + 0.048 + math.cos(t) * 0.102
            bow_pts.append((r_x * ca, r_x * sa, z_b))
        cb.tube_along_points(f"CrownArch_{bi}", bow_pts, 0.011, ring_segs=8, mat=gold_mat)

    cb.make_sphere("CrownOrb", 0.020, segments=12, rings=8, center_xyz=(0, 0, crown_z + 0.158), mat=gold_mat)
    cb.make_box("CrownCrossV", (0.012, 0.012, 0.056), center_xyz=(0, 0, crown_z + 0.194), mat=gold_mat, bevel_w=0.002)
    cb.make_box("CrownCrossH", (0.042, 0.012, 0.012), center_xyz=(0, 0, crown_z + 0.204), mat=gold_mat, bevel_w=0.002)

    cb.export_glb("boss_charles_iv.glb")

    # Charles IV Torso Regalia (Ermine Mantel + Bohemian Medallion + Royal Greatsword behind left shoulder)
    cb.clear_scene()
    gold_mat = cb.make_pbr_mat("BossGold", (0.94, 0.74, 0.24), roughness=0.20, metallic=0.92)
    fur_mat = cb.make_pbr_mat("ErmineFur", (0.95, 0.94, 0.91), roughness=0.88)
    spot_mat = cb.make_pbr_mat("ErmineSpot", (0.08, 0.07, 0.08), roughness=0.75)
    steel_mat = cb.make_pbr_mat("SwordSteel", (0.76, 0.80, 0.86), roughness=0.20, metallic=0.92)

    ermine_pts = [(math.cos(a) * 0.235, -math.sin(a) * 0.175, 0.505 - 0.03 * math.sin(a)) for a in [i * math.tau / 20.0 for i in range(21)]]
    cb.tube_along_points("CharlesErmineCollar", ermine_pts, 0.052, ring_segs=12, mat=fur_mat, cap_ends=False, scale_xy_fn=lambda i, n: (1.15, 0.85))
    for ei in range(6):
        ea = -1.1 + (ei / 5.0) * 2.2
        cb.make_sphere(f"ErmineSpot_{ei}", 0.011, segments=8, rings=6, center_xyz=(math.sin(ea) * 0.23, -0.178 * math.cos(ea), 0.485), mat=spot_mat)
    cb.make_cylinder("CharlesChainMedallion", 0.054, 0.054, 0.018, segments=8, center_xyz=(0.0, -0.165, 0.385), mat=gold_mat, rot_deg=(82.0, 0.0, 0.0), bevel_w=0.003)

    # Royal Greatsword hilt rising behind Left shoulder (-X_bl, +Y_bl back)
    sw_rot = (0.0, -14.0, 0.0)
    cb.make_cylinder("GreatSwordHilt", 0.014, 0.016, 0.36, segments=12, center_xyz=(-0.38, 0.10, 0.66), mat=steel_mat, rot_deg=sw_rot)
    cb.tube_along_points("GreatSwordCross", [(-0.49, 0.10, 0.72), (-0.38, 0.10, 0.69), (-0.27, 0.10, 0.74)], 0.014, ring_segs=8, mat=gold_mat)
    cb.make_sphere("GreatSwordPommel", 0.028, segments=12, rings=8, center_xyz=(-0.42, 0.10, 0.84), mat=gold_mat)

    cb.export_glb("boss_charles_iv_torso.glb")

    # ==================================================================
    # BOSS 2: PHARAOH RAMESSES II (Egypt)
    # ==================================================================
    cb.clear_scene()
    gold_mat = cb.make_pbr_mat("PharaohGold", (0.96, 0.76, 0.22), roughness=0.20, metallic=0.92)
    lapis_mat = cb.make_pbr_mat("PharaohLapis", (0.10, 0.28, 0.64), roughness=0.35, metallic=0.20)
    ruby_mat = cb.make_pbr_mat("PharaohRuby", (0.94, 0.12, 0.18), roughness=0.12, emission=(0.8, 0.12, 0.14), emission_strength=1.4)

    # Sculpted Vaulted Pharaoh Nemes Headdress Crown + Swept Side Wings
    def nemes_eval(u, v):
        ang = -math.pi * 0.12 + u * (math.pi * 1.24)  # sweeps back across dome from left wing -> back -> right wing!
        z = 0.06 + v * 0.175
        # Flare out mid-sides dramatically like an authentic Cobra-hood Nemes
        flare = 0.115 + 0.072 * math.sin(v * math.pi * 0.82) * (0.4 + 0.6 * abs(math.cos(ang)))
        px = -math.cos(ang) * flare
        py = math.sin(ang) * flare * 0.95 - 0.012
        # Slightly arched back/top crown
        if v > 0.75:
            t = (v - 0.75) / 0.25
            px *= 1.0 - 0.42 * t
            py *= 1.0 - 0.35 * t
            z += 0.025 * t
        return (px, py, z)

    cb.grid_cloth("NemesHoodWing", 28, 16, nemes_eval, mat=lapis_mat, smooth=True)

    # Ribbed Horizontal Gold Brow Band & Striated Gold/Lapis Lappets falling over shoulders
    cb.lathe_profile("NemesBrowBand", [(0.104, 0.142), (0.110, 0.156), (0.108, 0.176), (0.098, 0.182)], segments=24, mat=gold_mat)
    for sx in (-1.0, 1.0):
        for si in range(4):
            zl_off = si * 0.048
            cb.make_box(
                f"NemesLappet_{'L' if sx < 0 else 'R'}_{si}",
                (0.056, 0.024, 0.044),
                center_xyz=(sx * (0.128 - si * 0.008), -0.055 - si * 0.012, 0.085 - zl_off),
                mat=gold_mat if (si % 2 == 0) else lapis_mat,
                bevel_w=0.004,
                rot_deg=(-14.0, 0.0, sx * 12.0),
            )

    # 3D Sculpted Uraeus Cobra rearing above forehead + Double Pschent Crown Cone
    cobra_pts = [(0.0, -0.105, 0.165), (0.0, -0.124, 0.195), (0.0, -0.120, 0.228), (0.0, -0.138, 0.242)]
    cb.tube_along_points("NemesCobraBody", cobra_pts, [0.008, 0.016, 0.014, 0.006], ring_segs=10, mat=gold_mat, scale_xy_fn=lambda i, n: (1.8 if i == 1 else 1.1, 0.7))
    cb.make_sphere("CobraJewelEye", 0.009, segments=10, rings=6, center_xyz=(0.0, -0.132, 0.232), mat=ruby_mat)

    cb.lathe_profile("PharaohPschent", [(0.084, 0.220), (0.072, 0.265), (0.044, 0.345), (0.028, 0.375), (0.036, 0.388)], segments=20, mat=lapis_mat)
    cb.lathe_profile("PschentRim", [(0.078, 0.214), (0.092, 0.220), (0.088, 0.234)], segments=22, mat=gold_mat)

    # Braided Curved Ceremonial Pharaoh Beard
    cb.tube_along_points("PharaohBeard", [(0.0, -0.072, 0.012), (0.0, -0.082, -0.036), (0.0, -0.102, -0.076)], [0.017, 0.014, 0.012], ring_segs=10, mat=gold_mat)

    cb.export_glb("boss_ramesses.glb")

    # Ramesses Torso Regalia (3-tier Usekh Collar + Was/Ankh Scepter)
    cb.clear_scene()
    gold_mat = cb.make_pbr_mat("PharaohGold", (0.96, 0.76, 0.22), roughness=0.20, metallic=0.92)
    lapis_mat = cb.make_pbr_mat("PharaohLapis", (0.10, 0.38, 0.72), roughness=0.30, metallic=0.35)
    turq_mat = cb.make_pbr_mat("PharaohTurquoise", (0.14, 0.78, 0.76), roughness=0.25, emission=(0.12, 0.65, 0.68), emission_strength=0.6)

    for ti, rad_w in enumerate((0.125, 0.162, 0.200)):
        u_pts = [(math.cos(a) * rad_w * 1.15, -math.sin(a) * rad_w * 0.78, 0.515 - ti * 0.024) for a in [i * math.tau / 24.0 for i in range(25)]]
        cb.tube_along_points(f"UsekhTier_{ti}", u_pts, 0.013, ring_segs=8, mat=(gold_mat if ti != 1 else lapis_mat), cap_ends=False)
    for gi in range(7):
        ga = -0.9 + (gi / 6.0) * 1.8
        cb.make_sphere(f"UsekhGem_{gi}", 0.011, segments=8, rings=6, center_xyz=(math.sin(ga) * 0.19, -math.cos(ga) * 0.14, 0.45), mat=turq_mat)

    # Golden Ankh Scepter rising behind right shoulder (+X_bl)
    cb.make_cylinder("WasShaft", 0.013, 0.015, 0.76, segments=12, center_xyz=(0.40, 0.09, 0.46), mat=gold_mat, rot_deg=(0, 8.0, 0))
    ankh_pts = [(0.45 + math.cos(a) * 0.036, 0.09, 0.89 + math.sin(a) * 0.048) for a in [i * math.tau / 16.0 for i in range(17)]]
    cb.tube_along_points("WasAnkhLoop", ankh_pts, 0.010, ring_segs=8, mat=gold_mat, cap_ends=False)
    cb.make_box("WasAnkhCross", (0.096, 0.018, 0.018), center_xyz=(0.445, 0.09, 0.835), mat=gold_mat, bevel_w=0.003, rot_deg=(0, 8.0, 0))

    cb.export_glb("boss_ramesses_torso.glb")

    # ==================================================================
    # BOSS 3: JULIUS CAESAR (Rome)
    # ==================================================================
    cb.clear_scene()
    gold_mat = cb.make_pbr_mat("CaesarGold", (0.96, 0.76, 0.24), roughness=0.20, metallic=0.92)
    hair_mat = cb.make_pbr_mat("CaesarHair", (0.24, 0.20, 0.18), roughness=0.72)
    ruby_mat = cb.make_pbr_mat("CaesarRuby", (0.92, 0.12, 0.18), roughness=0.14, emission=(0.75, 0.10, 0.12), emission_strength=1.1)

    cb.make_sphere("CaesarHairCap", 0.104, segments=18, rings=12, center_xyz=(0.0, 0.012, 0.135), scale_xyz=(0.94, 1.02, 0.88), mat=hair_mat)
    # Golden Imperial Laurel Wreath Band + 20 Individually Carved Gold Laurel Leaves!
    w_pts = [(math.cos(a) * 0.106, -math.sin(a) * 0.108, 0.145 + math.sin(a) * 0.025) for a in [i * math.tau / 22.0 for i in range(23)]]
    cb.tube_along_points("LaurelStemBand", w_pts, 0.0055, ring_segs=8, mat=gold_mat, cap_ends=False)

    leaf_2d = [(0.0, 0.0), (0.012, 0.016), (0.010, 0.036), (0.0, 0.048), (-0.010, 0.036), (-0.012, 0.016)]
    for sx in (-1.0, 1.0):
        for li in range(9):
            t = li / 8.0
            ang = math.radians(10.0 + t * 145.0)
            lx = sx * math.sin(ang) * 0.108
            ly = math.cos(ang) * 0.110 + 0.005
            lz = 0.145 + (1.0 - t) * 0.026
            lf = cb.extrude_poly_3d(f"LaurelLeaf_{'L' if sx < 0 else 'R'}_{li}", leaf_2d, depth=0.004, axis="Y", mat=gold_mat, bevel_w=0.001)
            lf.location = (lx, ly, lz)
            lf.rotation_euler = (math.radians(32.0), math.radians(-sx * 25.0), math.radians(sx * (48.0 - t * 90.0)))
    cb.make_sphere("LaurelForeheadGem", 0.013, segments=10, rings=6, center_xyz=(0.0, -0.114, 0.172), scale_xyz=(1, 0.6, 1.2), mat=ruby_mat)

    cb.export_glb("boss_caesar.glb")

    # Caesar Torso Regalia (Sculpted Golden Lorica Musculata + Eagle Medallion + Fibula Cloak Brooch + Golden Aquila Standard)
    cb.clear_scene()
    gold_mat = cb.make_pbr_mat("CaesarGold", (0.96, 0.76, 0.24), roughness=0.22, metallic=0.92)
    leather_mat = cb.make_pbr_mat("RomanLeather", (0.34, 0.16, 0.09), roughness=0.58)
    crimson_mat = cb.make_pbr_mat("RomanCrimson", (0.58, 0.08, 0.12), roughness=0.68)

    # Embossed Gold Eagle Chest Medallion + Wing Reliefs
    cb.make_cylinder("CaesarEagleShield", 0.056, 0.056, 0.018, segments=16, center_xyz=(0.0, -0.158, 0.41), mat=gold_mat, rot_deg=(84.0, 0.0, 0.0), bevel_w=0.004)
    for sx in (-1.0, 1.0):
        cb.tube_along_points(f"CaesarChestWing_{'L' if sx < 0 else 'R'}", [(0.0, -0.162, 0.405), (sx * 0.075, -0.145, 0.428), (sx * 0.145, -0.110, 0.448)], [0.016, 0.022, 0.008], ring_segs=8, mat=gold_mat, scale_xy_fn=lambda i, n: (0.4, 1.4))
        # Leather + Gold Pteruges shoulder straps
        for pi in range(4):
            cb.make_box(f"PterugeStrap_{'L' if sx < 0 else 'R'}_{pi}", (0.024, 0.014, 0.086), center_xyz=(sx * (0.28 + pi * 0.010), 0.03 - pi * 0.026, 0.37), mat=leather_mat if pi % 2 == 0 else gold_mat, bevel_w=0.002, rot_deg=(0, sx * 22.0, sx * 42.0))

    # Ornate Fibula Cloak Brooch on right shoulder
    cb.make_cylinder("CaesarFibula", 0.034, 0.034, 0.016, segments=14, center_xyz=(0.19, -0.125, 0.48), mat=gold_mat, rot_deg=(75.0, 0.0, 0.0), bevel_w=0.003)

    # Golden Roman Legionary Aquila Eagle Standard behind left shoulder
    cb.make_cylinder("AquilaPole", 0.012, 0.014, 0.84, segments=12, center_xyz=(-0.42, 0.09, 0.46), mat=gold_mat, rot_deg=(0, 6.0, 0))
    cb.make_box("AquilaPerch", (0.14, 0.025, 0.025), center_xyz=(-0.455, 0.09, 0.84), mat=gold_mat, bevel_w=0.004)
    cb.make_sphere("AquilaBody", 0.028, segments=12, rings=8, center_xyz=(-0.455, 0.09, 0.88), scale_xyz=(0.8, 0.8, 1.4), mat=gold_mat)
    for sx in (-1.0, 1.0):
        cb.tube_along_points(f"AquilaWing_{'L' if sx < 0 else 'R'}", [(-0.455, 0.09, 0.88), (-0.455 + sx * 0.08, 0.09, 0.925), (-0.455 + sx * 0.14, 0.09, 0.955)], [0.020, 0.026, 0.010], ring_segs=8, mat=gold_mat, scale_xy_fn=lambda i, n: (0.4, 1.5))

    cb.export_glb("boss_caesar_torso.glb")

    # ==================================================================
    # BOSS 4: PIRATE QUEEN ANNE (Age of Sail)
    # ==================================================================
    cb.clear_scene()
    hat_mat = cb.make_pbr_mat("TricorneMat", (0.11, 0.09, 0.11), roughness=0.52)
    gold_mat = cb.make_pbr_mat("PirateGold", (0.94, 0.72, 0.24), roughness=0.22, metallic=0.90)
    hair_mat = cb.make_pbr_mat("PirateHair", (0.18, 0.09, 0.06), roughness=0.72)
    plume_red = cb.make_pbr_mat("PiratePlumeRed", (0.72, 0.10, 0.16), roughness=0.68)
    plume_ivory = cb.make_pbr_mat("PiratePlumeIvory", (0.94, 0.90, 0.82), roughness=0.66)
    leather_mat = cb.make_pbr_mat("PirateLeather", (0.07, 0.06, 0.07), roughness=0.45)

    # Flowing Wavy Hair Locks + Gold Hoop Earrings + Curved Leather Eyepatch over Left Eye
    for sx in (-1.0, 1.0):
        cb.tube_along_points(f"PirateHair_{'L' if sx < 0 else 'R'}", [(sx * 0.085, 0.015, 0.155), (sx * 0.118, 0.010, 0.080), (sx * 0.122, 0.020, 0.0), (sx * 0.110, 0.025, -0.075)], [0.028, 0.036, 0.032, 0.022], ring_segs=10, mat=hair_mat)
        e_pts = [(sx * 0.104, math.cos(a) * 0.018, 0.064 + math.sin(a) * 0.018) for a in [i * math.tau / 14.0 for i in range(15)]]
        cb.tube_along_points(f"PirateEarring_{'L' if sx < 0 else 'R'}", e_pts, 0.0038, ring_segs=6, mat=gold_mat, cap_ends=False)

    # Eyepatch over Left Eye (-0.038, -0.114, 0.106) + diagonal strap
    cb.make_sphere("PirateEyepatch", 0.024, segments=14, rings=8, center_xyz=(-0.038, -0.114, 0.106), scale_xyz=(1.12, 0.40, 0.92), mat=leather_mat)
    cb.tube_along_points("EyepatchStrap", [(-0.085, -0.055, 0.145), (-0.038, -0.112, 0.114), (0.042, -0.095, 0.165), (0.090, 0.02, 0.155)], 0.0042, ring_segs=6, mat=leather_mat)

    # Authentic Sweeping 3-Cornered Upturned Captain's Tricorne Hat (sculpted lofted brim!)
    hat_crown = cb.lathe_profile("TricorneCrown", [(0.112, 0.175), (0.118, 0.215), (0.102, 0.275), (0.020, 0.285)], segments=24, mat=hat_mat)
    hat_crown.location = (0.0, 0.002, 0.0)
    # Continuous Curved 3-lobed Upturned Brim (front peak points straight forward -Y_bl!)
    def tricorne_brim(u, v):
        ang = u * math.tau  # front peak at -pi/2 (-Y)!
        r_in = 0.108
        # 3 lobes: front (ang = -pi/2), back-left, back-right
        lobe = math.cos(3.0 * (ang + math.pi * 0.5))  # +1 at 3 Tricorne points, -1 between!
        r_out = 0.215 + 0.075 * lobe
        r = r_in + (r_out - r_in) * v
        px = math.cos(ang) * r
        py = math.sin(ang) * r
        # Upturned curved hat sides between peaks!
        curl = (v ** 1.35) * (0.045 + 0.052 * (1.0 - lobe) * 0.5)
        pz = 0.178 + curl
        return (px, py, pz)

    cb.grid_cloth("TricorneBrim", 48, 8, tricorne_brim, mat=hat_mat, closed_u=True, smooth=True)
    # Braided Gold Piping tracing outer upturned brim edge!
    pipe_pts = [tricorne_brim(i / 48.0, 1.0) for i in range(49)]
    cb.tube_along_points("TricorneGoldTrim", pipe_pts, 0.0085, ring_segs=8, mat=gold_mat, cap_ends=False)

    # Sweeping Sculpted Ostrich Plumes curving over right hat brim
    cb.tube_along_points("TricornePlumeRed", [(0.10, -0.02, 0.24), (0.17, 0.01, 0.30), (0.24, 0.06, 0.29), (0.28, 0.12, 0.24)], [0.014, 0.026, 0.022, 0.008], ring_segs=10, mat=plume_red, scale_xy_fn=lambda i, n: (1.4, 0.5))
    cb.tube_along_points("TricornePlumeIvory", [(0.08, 0.0, 0.25), (0.14, 0.04, 0.33), (0.21, 0.09, 0.33)], [0.012, 0.020, 0.007], ring_segs=10, mat=plume_ivory, scale_xy_fn=lambda i, n: (1.4, 0.5))

    cb.export_glb("boss_pirate_anne.glb")

    # Pirate Anne Torso Regalia (Lace Jabot + Gold Fringed Epaulettes + Cutlass)
    cb.clear_scene()
    gold_mat = cb.make_pbr_mat("PirateGold", (0.94, 0.72, 0.24), roughness=0.22, metallic=0.90)
    lace_mat = cb.make_pbr_mat("PirateLace", (0.94, 0.91, 0.85), roughness=0.72)

    for ji in range(5):
        w_j = 0.036 + ji * 0.012
        cb.make_box(f"PirateJabotRuffle_{ji}", (w_j * 2.0, 0.028, 0.034), center_xyz=(0.0, -0.145 + ji * 0.002, 0.51 - ji * 0.030), mat=lace_mat, bevel_w=0.006)
    for sx in (-1.0, 1.0):
        cb.make_box(f"AdmiralEpaulette_{'L' if sx < 0 else 'R'}", (0.135, 0.105, 0.028), center_xyz=(sx * 0.29, 0.0, 0.535), mat=gold_mat, bevel_w=0.006, rot_deg=(0, sx * 14.0, 0))
        for fri in range(6):
            cb.make_cylinder(f"EpauletteFringe_{'L' if sx < 0 else 'R'}_{fri}", 0.006, 0.006, 0.045, segments=8, center_xyz=(sx * 0.355, -0.04 + fri * 0.016, 0.495), mat=gold_mat)

    cb.export_glb("boss_pirate_anne_torso.glb")

    # ==================================================================
    # BOSS 5: AL CAPONE (1920s Noir Mafia Boss)
    # ==================================================================
    cb.clear_scene()
    fedora_mat = cb.make_pbr_mat("FedoraFelt", (0.86, 0.83, 0.78), roughness=0.68)
    ribbon_mat = cb.make_pbr_mat("FedoraRibbon", (0.62, 0.10, 0.14), roughness=0.45)
    hair_mat = cb.make_pbr_mat("CaponeHair", (0.09, 0.08, 0.09), roughness=0.68)
    scar_mat = cb.make_pbr_mat("CaponeScar", (0.58, 0.14, 0.16), roughness=0.52)
    cigar_mat = cb.make_pbr_mat("CigarTobacco", (0.34, 0.18, 0.09), roughness=0.78)
    ember_mat = cb.make_pbr_mat("CigarEmber", (1.0, 0.38, 0.06), roughness=0.18, emission=(1.0, 0.35, 0.04), emission_strength=4.5)

    cb.make_sphere("CaponeHairBack", 0.102, segments=16, rings=10, center_xyz=(0.0, 0.012, 0.115), scale_xyz=(0.94, 0.96, 0.95), mat=hair_mat)
    # Sculpted Left Cheek Scar
    cb.tube_along_points("CaponeScar", [(-0.046, -0.098, 0.088), (-0.056, -0.094, 0.062), (-0.058, -0.088, 0.038)], 0.0038, ring_segs=6, mat=scar_mat)

    # Lit Cuban Cigar clenched at mouth right corner
    cb.tube_along_points("CaponeCigar", [(0.028, -0.104, 0.040), (0.052, -0.148, 0.028), (0.068, -0.184, 0.020)], [0.009, 0.0095, 0.009], ring_segs=10, mat=cigar_mat)
    cb.make_sphere("CaponeCigarEmber", 0.0095, segments=10, rings=8, center_xyz=(0.070, -0.188, 0.019), mat=ember_mat)

    # Pinched-Crown Snap-Brim Mafioso Fedora tilted slightly (-7 deg X roll/pitch, +7 deg Z)
    def fedora_crown(u, v):
        ang = u * math.tau
        # Oval tapered fedora crown
        r_x = 0.116 * (1.0 - 0.18 * v)
        r_y = 0.128 * (1.0 - 0.18 * v)
        px = math.cos(ang) * r_x
        py = math.sin(ang) * r_y
        # Center teardrop crown dent + front pinched sides!
        pz = 0.180 + v * 0.112
        if v > 0.72:
            # Front pinch near -Y!
            if math.sin(ang) < -0.2:
                pinch = math.sin((v - 0.72) / 0.28 * math.pi * 0.5) * (-math.sin(ang))
                px *= 1.0 - 0.26 * pinch
        return (px, py, pz)

    def fedora_brim(u, v):
        ang = u * math.tau
        r = 0.112 + v * 0.115
        px = math.cos(ang) * r
        py = math.sin(ang) * r
        # Snap brim dips cleanly in front (-Y_bl) and curves up slightly in back (+Y_bl)!
        dip = -0.028 * max(0.0, -math.sin(ang)) + 0.018 * max(0.0, math.sin(ang))
        pz = 0.180 + (v ** 1.2) * dip
        return (px, py, pz)

    fc = cb.grid_cloth("FedoraCrown", 32, 12, fedora_crown, mat=fedora_mat, closed_u=True, smooth=True)
    fb = cb.grid_cloth("FedoraBrim", 36, 6, fedora_brim, mat=fedora_mat, closed_u=True, smooth=True)
    fr = cb.lathe_profile("FedoraRibbon", [(0.116, 0.182), (0.114, 0.208), (0.110, 0.210)], segments=28, mat=ribbon_mat)
    # Tilt fedora rakishly on Capone's brow
    for fobj in (fc, fb, fr):
        fobj.rotation_euler = (math.radians(-10.0), math.radians(-6.0), 0.0)
        fobj.location = (-0.008, -0.008, 0.012)

    cb.export_glb("boss_al_capone.glb")

    # Al Capone Torso Regalia (Fur-trimmed Coat Collar + Crimson Tie + Lapel Rose + Gold Watch Chain)
    cb.clear_scene()
    fur_mat = cb.make_pbr_mat("CaponeFur", (0.09, 0.08, 0.09), roughness=0.86)
    crimson_mat = cb.make_pbr_mat("CaponeCrimson", (0.72, 0.09, 0.14), roughness=0.45)
    gold_mat = cb.make_pbr_mat("CaponeGold", (0.94, 0.76, 0.26), roughness=0.22, metallic=0.92)
    diamond_mat = cb.make_pbr_mat("CaponeDiamond", (0.90, 0.96, 1.0), roughness=0.08, emission=(0.7, 0.9, 1.0), emission_strength=1.5)

    f_pts = [(math.cos(a) * 0.155, -math.sin(a) * 0.125, 0.545 - 0.02 * math.sin(a)) for a in [i * math.tau / 20.0 for i in range(21)]]
    cb.tube_along_points("CaponeFurCollar", f_pts, 0.044, ring_segs=10, mat=fur_mat, cap_ends=False)
    # Silk Tie & Diamond Pin
    cb.extrude_poly_3d("CaponeTie", [(0, 0.53), (0.022, 0.44), (0.028, 0.31), (0, 0.28), (-0.028, 0.31), (-0.022, 0.44)], depth=0.014, axis="Y", mat=crimson_mat, bevel_w=0.003).location = (0, -0.142, 0)
    cb.make_sphere("CaponeTiePin", 0.009, segments=10, rings=6, center_xyz=(0, -0.150, 0.43), mat=diamond_mat)
    # Crimson Lapel Rose Boutonniere (layered petals!)
    for pi in range(5):
        pa = (pi / 5.0) * math.tau
        cb.make_sphere(f"CaponeRosePetal_{pi}", 0.012, segments=8, rings=6, center_xyz=(0.105 + math.cos(pa) * 0.010, -0.145, 0.45 + math.sin(pa) * 0.010), scale_xyz=(1, 0.5, 1), mat=crimson_mat)
    # Draped Gold Pocket-Watch Chain
    chain_pts = [(-0.01, -0.148, 0.29), (0.05, -0.156, 0.25), (0.11, -0.142, 0.27)]
    cb.tube_along_points("CaponeWatchChain", chain_pts, 0.0055, ring_segs=6, mat=gold_mat)

    cb.export_glb("boss_al_capone_torso.glb")


def build_stage_headgear():
    """Sculpted non-boss headgear for Stage 0 and Stage 1 opponents so every opponent is Blender-crafted."""
    # 1. Medieval Knight Sallet / Greathelm (Stage 1)
    cb.clear_scene()
    steel_mat = cb.make_pbr_mat("HelmSteel", (0.70, 0.74, 0.80), roughness=0.24, metallic=0.90)
    gold_mat = cb.make_pbr_mat("HelmGold", (0.86, 0.66, 0.24), roughness=0.26, metallic=0.90)
    plume_mat = cb.make_pbr_mat("HelmPlume", (0.64, 0.10, 0.14), roughness=0.68)
    cb.lathe_profile("KnightHelmDome", [(0.118, 0.110), (0.122, 0.155), (0.102, 0.215), (0.048, 0.242), (0.004, 0.252)], segments=20, mat=steel_mat)
    cb.make_box("KnightHelmComb", (0.022, 0.16, 0.042), center_xyz=(0, 0.005, 0.245), mat=gold_mat, bevel_w=0.004)
    cb.tube_along_points("KnightHelmVisorRim", [(-0.108, -0.02, 0.132), (0.0, -0.132, 0.128), (0.108, -0.02, 0.132)], 0.011, ring_segs=8, mat=gold_mat)
    cb.tube_along_points("KnightHelmPlume", [(0.0, 0.01, 0.252), (0.0, 0.09, 0.275), (0.0, 0.15, 0.210)], [0.018, 0.026, 0.010], ring_segs=10, mat=plume_mat)
    cb.export_glb("helm_knight_visor.glb")

    # 2. Medieval Squire Draped Hood (Stage 0)
    cb.clear_scene()
    hood_mat = cb.make_pbr_mat("SquireHood", (0.28, 0.16, 0.12), roughness=0.78, double_sided=True)
    cb.grid_cloth(
        "MedievalHood",
        24,
        14,
        lambda u, v: (math.cos(u * math.tau) * (0.118 - 0.04 * (v ** 1.4)), math.sin(u * math.tau) * (0.118 - 0.04 * (v ** 1.4)) + 0.055 * v + (0.065 * max(0, -math.sin(u * math.tau)) if v < 0.7 else 0.0), 0.05 + v * 0.21),
        mat=hood_mat,
        closed_u=True,
        smooth=True,
    )
    cb.export_glb("hat_medieval_hood.glb")

    # 3. Egypt Khat Headcloth & Circlet
    cb.clear_scene()
    khat_mat = cb.make_pbr_mat("KhatCloth", (0.82, 0.75, 0.60), roughness=0.74)
    copper_mat = cb.make_pbr_mat("KhatBand", (0.82, 0.56, 0.20), roughness=0.28, metallic=0.86)
    cb.make_sphere("KhatDraped", 0.118, segments=18, rings=12, center_xyz=(0, 0.022, 0.125), scale_xyz=(1.04, 1.06, 0.96), mat=khat_mat)
    cb.lathe_profile("KhatCirclet", [(0.105, 0.140), (0.114, 0.145), (0.114, 0.160), (0.104, 0.162)], segments=22, mat=copper_mat)
    cb.export_glb("hat_egypt_khat.glb")

    # 4. Roman Centurion Galea Helmet & Transverse Crest
    cb.clear_scene()
    steel_mat = cb.make_pbr_mat("GaleaSteel", (0.72, 0.76, 0.82), roughness=0.22, metallic=0.92)
    crest_mat = cb.make_pbr_mat("GaleaCrest", (0.68, 0.10, 0.12), roughness=0.70)
    cb.lathe_profile("GaleaBowl", [(0.115, 0.120), (0.118, 0.165), (0.092, 0.225), (0.006, 0.242)], segments=22, mat=steel_mat)
    cb.tube_along_points("GaleaBrowPeak", [(-0.105, -0.02, 0.135), (0.0, -0.128, 0.132), (0.105, -0.02, 0.135)], 0.010, ring_segs=8, mat=steel_mat)
    # Transverse crimson Centurion crest (runs left-to-right X)
    cb.tube_along_points("GaleaCrestFan", [(-0.135, 0.0, 0.225), (-0.07, 0.0, 0.285), (0.0, 0.0, 0.302), (0.07, 0.0, 0.285), (0.135, 0.0, 0.225)], [0.016, 0.028, 0.032, 0.028, 0.016], ring_segs=10, mat=crest_mat, scale_xy_fn=lambda i, n: (1.5, 0.6))
    cb.export_glb("helm_centurion.glb")

    # 5. Pirate Bandana & Brass Buckle Ring
    cb.clear_scene()
    band_mat = cb.make_pbr_mat("BandanaCloth", (0.56, 0.12, 0.16), roughness=0.72)
    cb.make_sphere("BandanaCap", 0.110, segments=16, rings=10, center_xyz=(0, 0.010, 0.145), scale_xyz=(1.0, 1.04, 0.82), mat=band_mat)
    cb.lathe_profile("BandanaFold", [(0.106, 0.128), (0.116, 0.136), (0.114, 0.156), (0.102, 0.160)], segments=20, mat=band_mat)
    cb.tube_along_points("BandanaKnotL", [(0.04, 0.105, 0.125), (0.095, 0.145, 0.095)], [0.014, 0.008], ring_segs=8, mat=band_mat)
    cb.tube_along_points("BandanaKnotR", [(-0.04, 0.105, 0.125), (-0.095, 0.145, 0.085)], [0.014, 0.008], ring_segs=8, mat=band_mat)
    cb.export_glb("hat_pirate_bandana.glb")

    # 6. 1920s Newsboy / Syndicate Cap
    cb.clear_scene()
    cap_mat = cb.make_pbr_mat("CapWool", (0.20, 0.18, 0.20), roughness=0.78)
    cb.make_sphere("NewsboyCrown", 0.116, segments=18, rings=10, center_xyz=(0, 0.004, 0.158), scale_xyz=(1.04, 1.12, 0.62), mat=cap_mat)
    cb.make_cylinder("NewsboyVisor", 0.108, 0.108, 0.012, segments=16, center_xyz=(0, -0.072, 0.136), mat=cap_mat, rot_deg=(12.0, 0.0, 0.0))
    cb.export_glb("hat_1920s_cap.glb")


if __name__ == "__main__":
    build_base_opponent_parts()
    build_campaign_boss_regalia()
    build_stage_headgear()
    print("[GEN_OPPONENTS_AND_BOSSES_DONE]")
