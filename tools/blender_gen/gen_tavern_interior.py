import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_bl as cb


def build_wall_crest_shield():
    """Original LIALO Fantasy Crest: Crossed Halberds + Convex Heater Shield + Crowned Chalice, Raven Wings & Astrolabe Star (NO SLOVAK CROSS!)."""
    cb.clear_scene()
    oak_mat = cb.make_pbr_mat("CrestOak", (0.24, 0.14, 0.08), roughness=0.65)
    iron_mat = cb.make_pbr_mat("CrestIron", (0.16, 0.17, 0.21), roughness=0.42, metallic=0.82)
    steel_mat = cb.make_pbr_mat("CrestSteel", (0.76, 0.80, 0.86), roughness=0.22, metallic=0.92)
    crimson_mat = cb.make_pbr_mat("CrestCrimson", (0.44, 0.08, 0.10), roughness=0.45, metallic=0.18, coat=0.35)
    gold_mat = cb.make_pbr_mat("CrestGold", (0.90, 0.70, 0.24), roughness=0.24, metallic=0.92)
    sapphire_mat = cb.make_pbr_mat("CrestSapphire", (0.14, 0.56, 0.96), roughness=0.12, metallic=0.15, emission=(0.18, 0.62, 1.0), emission_strength=1.4)

    # 1. Crossed Medieval Halberds behind the shield (Blender Y_back = +0.06, shield front = -0.05)
    for sx in (-1.0, 1.0):
        ang_rad = math.radians(sx * 33.0)
        ca, sa = math.cos(ang_rad), math.sin(ang_rad)
        # Helper maps halberd-local (u=side, v=along shaft) to Blender (X, Y_depth, Z_up)
        def hpt(u, v, y_off=0.055):
            px = (u * ca - v * sa)
            pz = (u * sa + v * ca)
            return (px, y_off, pz)

        cb.tube_along_points(
            f"HalberdShaft_{'L' if sx < 0 else 'R'}",
            [hpt(0, -1.08), hpt(0, 0.0), hpt(0, 1.02)],
            [0.022, 0.024, 0.022],
            ring_segs=14,
            mat=oak_mat,
        )
        # Butt ferrule & spear finial
        cb.tube_along_points(f"HalberdButt_{'L' if sx < 0 else 'R'}", [hpt(0, -1.16), hpt(0, -1.04)], [0.008, 0.025], ring_segs=12, mat=iron_mat)
        cb.tube_along_points(f"HalberdSpear_{'L' if sx < 0 else 'R'}", [hpt(0, 0.92), hpt(0, 1.08), hpt(0, 1.30)], [0.024, 0.018, 0.002], ring_segs=4, mat=steel_mat)
        # Crescent halberd axe blade pointing outward
        out_dir = -sx  # Left shaft points up-left (-X), right points up-right (+X)
        # Build flat halberd axe polygon in halberd-local coords then map
        axe_pts_local = [
            (out_dir * 0.02, 0.98),
            (out_dir * 0.24, 1.08),
            (out_dir * 0.30, 0.96),
            (out_dir * 0.28, 0.80),
            (out_dir * 0.20, 0.70),
            (out_dir * 0.02, 0.76),
            (-out_dir * 0.14, 0.85),  # back piercing beak!
            (-out_dir * 0.02, 0.91),
        ]
        bm = bmesh.new()
        fv, bv = [], []
        for u, v in axe_pts_local:
            p_f = hpt(u, v, 0.044)
            p_b = hpt(u, v, 0.066)
            fv.append(bm.verts.new(p_f))
            bv.append(bm.verts.new(p_b))
        bm.faces.new(fv)
        bm.faces.new(list(reversed(bv)))
        for i in range(len(axe_pts_local)):
            j = (i + 1) % len(axe_pts_local)
            bm.faces.new((fv[i], bv[i], bv[j], fv[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        axe_obj = cb.finish_bmesh(f"HalberdAxe_{'L' if sx < 0 else 'R'}", bm, mat=steel_mat, smooth=False)
        cb.add_bevel(axe_obj, width=0.005, segments=2)

        # Brass collar sleeve around shaft below axe
        cb.tube_along_points(f"HalberdCollar_{'L' if sx < 0 else 'R'}", [hpt(0, 0.68), hpt(0, 0.76)], [0.028, 0.028], ring_segs=14, mat=gold_mat)

    # 2. Convex Sculpted Gothic Heater Shield Body (front facing -Y Blender -> +Z Godot)
    # Outline function: z_norm in [-1..+1], half_width(z_norm)
    def shield_half_w(zn):
        # zn = +1 top (+0.62m), zn = -1 bottom tip (-0.64m)
        if zn >= 0.18:
            # Subtle arched shoulders
            return 0.48 - 0.02 * ((zn - 0.18) / 0.82) ** 2
        else:
            # Smooth pointed gothic heater curve to bottom apex
            t = (0.18 - zn) / 1.18  # 0..1
            return 0.48 * max(0.0, 1.0 - t ** 1.68) ** 0.72

    nu, nv = 28, 36
    # Build solid convex shield plate (front face + back face + side edge!)
    bm = bmesh.new()
    front_grid, back_grid = [], []
    for vi in range(nv + 1):
        v = float(vi) / float(nv)  # 0 top -> 1 bottom
        zn = 1.0 - 2.0 * v
        z_pos = zn * 0.62 + 0.04 * (1.0 - abs(zn))  # slightly tall top arch
        if v < 0.08:
            z_top_arch = 0.04 * math.cos((0.5) * math.pi)
        hw = max(0.004, shield_half_w(zn))
        frow, brow = [], []
        for ui in range(nu + 1):
            u_norm = -1.0 + 2.0 * (float(ui) / float(nu))
            x_pos = u_norm * hw
            # Top slight upward crown
            crown_lift = 0.042 * (1.0 - u_norm * u_norm) if zn > 0.75 else 0.0
            # Convex forward bulge (front = -y!)
            bulge = 0.075 * math.cos(u_norm * math.pi * 0.45) * math.cos(zn * math.pi * 0.35)
            y_front = -0.025 - bulge
            y_back = y_front + 0.048
            frow.append(bm.verts.new((x_pos, y_front, z_pos + crown_lift * ((zn - 0.75) / 0.25 if zn > 0.75 else 0.0))))
            brow.append(bm.verts.new((x_pos, y_back, z_pos + crown_lift * ((zn - 0.75) / 0.25 if zn > 0.75 else 0.0))))
        front_grid.append(frow)
        back_grid.append(brow)

    for vi in range(nv):
        for ui in range(nu):
            bm.faces.new((front_grid[vi][ui], front_grid[vi + 1][ui], front_grid[vi + 1][ui + 1], front_grid[vi][ui + 1]))
            bm.faces.new((back_grid[vi][ui], back_grid[vi][ui + 1], back_grid[vi + 1][ui + 1], back_grid[vi + 1][ui]))
    # Stitch outer perimeter border
    for ui in range(nu):
        bm.faces.new((front_grid[0][ui], front_grid[0][ui + 1], back_grid[0][ui + 1], back_grid[0][ui]))
        bm.faces.new((front_grid[nv][ui + 1], front_grid[nv][ui], back_grid[nv][ui], back_grid[nv][ui + 1]))
    for vi in range(nv):
        bm.faces.new((front_grid[vi + 1][0], front_grid[vi][0], back_grid[vi][0], back_grid[vi + 1][0]))
        bm.faces.new((front_grid[vi][nu], front_grid[vi + 1][nu], back_grid[vi + 1][nu], back_grid[vi][nu]))

    cb.finish_bmesh("ShieldField", bm, mat=crimson_mat, smooth=True)

    # Raised sculpted Gold-Brass Outer Perimeter Rim Frame following shield contour
    rim_pts = []
    # Top left -> top right -> right curve -> tip -> left curve -> close
    steps_top = 9
    for i in range(steps_top):
        un = -1.0 + 2.0 * (i / (steps_top - 1))
        crown = 0.042 * (1.0 - un * un)
        bulge = 0.075 * math.cos(un * math.pi * 0.45) * math.cos(math.pi * 0.35)
        rim_pts.append((un * shield_half_w(1.0), -0.030 - bulge, 0.62 + crown))
    for i in range(1, 15):
        v = i / 14.0
        zn = 1.0 - 2.0 * v
        hw = max(0.005, shield_half_w(zn))
        bulge = 0.075 * math.cos(math.pi * 0.45) * math.cos(zn * math.pi * 0.35)
        rim_pts.append((hw, -0.030 - bulge, zn * 0.62))
    for i in range(1, 15):
        v = 1.0 - i / 14.0
        zn = 1.0 - 2.0 * v
        hw = max(0.005, shield_half_w(zn))
        bulge = 0.075 * math.cos(math.pi * 0.45) * math.cos(zn * math.pi * 0.35)
        rim_pts.append((-hw, -0.030 - bulge, zn * 0.62))
    rim_pts.append(rim_pts[0])
    cb.tube_along_points("ShieldRim", rim_pts, 0.026, ring_segs=12, mat=gold_mat, cap_ends=False)

    # Domed Brass Studs along Shield Perimeter
    for idx in range(0, len(rim_pts) - 1, 2):
        rx, ry, rz = rim_pts[idx]
        cb.make_sphere(f"ShieldStud_{idx}", 0.014, segments=10, rings=6, center_xyz=(rx, ry - 0.018, rz), mat=gold_mat)

    # ------------------------------------------------------------------
    # 3. ORIGINAL LIALO HIGH-RELIEF GOLDEN EMBLEM (ZERO SLOVAK CROSS!)
    #    Crowned Arcane Chalice + Swept Sculpted Raven Wings + 8-Point Astrolabe Star
    # ------------------------------------------------------------------
    def front_y(x, z):
        u_n = max(-0.95, min(0.95, x / 0.48))
        z_n = max(-0.95, min(0.95, z / 0.62))
        return -0.025 - 0.075 * math.cos(u_n * math.pi * 0.45) * math.cos(z_n * math.pi * 0.35)

    # Central Carved Golden Chalice (Goblet of Fate)
    chalice_prof = [
        (0.115, -0.32),
        (0.095, -0.29),
        (0.032, -0.24),
        (0.046, -0.17),  # decorative knop
        (0.026, -0.12),
        (0.092, -0.04),  # flaring cup base
        (0.145, 0.14),   # cup lip!
        (0.132, 0.155),
        (0.115, 0.12),
    ]
    chalice = cb.lathe_profile("EmblemChalice", chalice_prof, segments=24, mat=gold_mat, smooth=True)
    chalice.scale = (1.0, 0.38, 1.0)
    chalice.location = (0.0, front_y(0.0, -0.06) - 0.015, 0.0)

    # Sapphire Arcane Flame-Orb hovering cleanly inside/above the Chalice rim
    cb.make_sphere("ChaliceJewel", 0.052, segments=18, rings=12, center_xyz=(0.0, front_y(0.0, 0.16) - 0.032, 0.18), scale_xyz=(1.0, 0.55, 1.35), mat=sapphire_mat)

    # Sweeping Layered Raven/Eagle Wings flanking Left & Right of the Chalice
    for sx in (-1.0, 1.0):
        for fi in range(5):
            t = fi / 4.0
            p0 = (sx * 0.085, front_y(sx * 0.085, -0.10 + t * 0.14) - 0.015, -0.12 + t * 0.075)
            p1 = (sx * (0.21 + t * 0.05), front_y(sx * 0.22, -0.02 + t * 0.16) - 0.020, -0.04 + t * 0.11)
            p2 = (sx * (0.31 + t * 0.045), front_y(sx * 0.32, 0.08 + t * 0.16) - 0.012, 0.06 + t * 0.14)
            cb.tube_along_points(
                f"WingFeather_{'L' if sx < 0 else 'R'}_{fi}",
                [p0, p1, p2],
                [0.018, 0.022, 0.007],
                ring_segs=10,
                mat=gold_mat,
                scale_xy_fn=lambda idx, n: (0.45, 1.45),
            )

    # Radiant 8-Point Astrolabe Star Crown above the Chalice (top center z ~ +0.42)
    star_pts = []
    for si in range(16):
        ang = (si / 16.0) * math.tau + math.pi * 0.5
        rad = 0.145 if (si % 2 == 0) else 0.052
        star_pts.append((math.cos(ang) * rad, 0.42 + math.sin(ang) * rad))
    star = cb.extrude_poly_3d("EmblemAstrolabeStar", star_pts, depth=0.036, axis="Y", mat=gold_mat, smooth=False, bevel_w=0.004)
    star.location = (0.0, front_y(0.0, 0.42) - 0.014, 0.0)
    cb.make_sphere("AstrolabeCoreGem", 0.034, segments=16, rings=10, center_xyz=(0.0, front_y(0.0, 0.42) - 0.036, 0.42), scale_xyz=(1.0, 0.5, 1.0), mat=sapphire_mat)

    # Small Crescent Moon filigree brackets under Chalice foot
    cresc_pts = []
    for ci in range(13):
        a = math.radians(-160.0 + ci * 20.0 * (140.0 / 120.0))
        cresc_pts.append((math.sin(a) * 0.16, front_y(math.sin(a) * 0.16, -0.44) - 0.014, -0.34 - math.cos(a) * 0.10))
    cb.tube_along_points("EmblemCrescent", cresc_pts, [0.005, 0.010, 0.016, 0.020, 0.022, 0.024, 0.024, 0.024, 0.022, 0.020, 0.016, 0.010, 0.005], ring_segs=10, mat=gold_mat)

    cb.export_glb("wall_crest_shield.glb")


def build_tavern_banner():
    """Origin at horizontal rod center (z_bl = 0). Hanging cloth drapes downward to z_bl = -1.70, facing Godot +Z (-Y_bl)."""
    cb.clear_scene()
    cloth_mat = cb.make_pbr_mat("BannerClothMat", (0.58, 0.14, 0.14), roughness=0.84, double_sided=True)
    trim_mat = cb.make_pbr_mat("BannerTrimMat", (0.88, 0.68, 0.24), roughness=0.28, metallic=0.84)
    wood_mat = cb.make_pbr_mat("BannerHardwareMat", (0.20, 0.13, 0.08), roughness=0.58)

    # Horizontal hanging rod + spear finials + top hanging cord
    cb.make_cylinder("BannerHardwareRod", 0.024, 0.024, 0.96, segments=16, center_xyz=(0, 0.015, 0.0), mat=wood_mat, rot_deg=(0, 90, 0))
    for sx in (-1.0, 1.0):
        cb.lathe_profile(
            f"BannerHardwareFinial_{'L' if sx < 0 else 'R'}",
            [(0.030, 0.0), (0.032, 0.02), (0.016, 0.045), (0.028, 0.075), (0.002, 0.13)],
            segments=12,
            mat=trim_mat,
        ).location = (sx * 0.48, 0.015, 0.0)
        obj = bpy.data.objects[f"BannerHardwareFinial_{'L' if sx < 0 else 'R'}"]
        obj.rotation_euler = (0.0, sx * math.pi * 0.5, 0.0)
        # Hanging bracket rings wrapping cloth top
        cb.make_cylinder(f"BannerHardwareLoop_{'L' if sx < 0 else 'R'}", 0.030, 0.030, 0.035, segments=14, center_xyz=(sx * 0.32, 0.015, 0.0), mat=trim_mat, rot_deg=(0, 90, 0))

    cb.tube_along_points("BannerHardwareCord", [(-0.34, 0.018, 0.02), (0.0, 0.025, 0.22), (0.34, 0.018, 0.02)], 0.007, ring_segs=8, mat=trim_mat)

    # Sculpted draped Swallow-Tail Cloth (nu=28, nv=36)
    def cloth_eval(u, v):
        # u: 0..1 left to right; v: 0 top -> 1 bottom hem
        un = (u - 0.5) * 2.0  # -1..+1
        w = 0.39 + 0.03 * math.sin(v * math.pi)
        px = un * w
        # Natural vertical gravity ripples growing deeper lower down, flattened slightly at top rod
        fold_amp = 0.024 * (v ** 0.75)
        fold = fold_amp * math.sin(un * math.pi * 2.5 + v * 1.4) + 0.010 * (v ** 0.9) * math.cos(un * math.pi * 5.0)
        sway_curve = -0.028 * math.sin(v * math.pi)
        py = -0.008 + fold + sway_curve  # facing -Y Blender (+Z Godot)
        # Swallow-tail V-notch cut in bottom! Center cuts higher than left/right points!
        swallow = 0.26 * (1.0 - abs(un) ** 1.3)
        length = 1.68 - swallow
        pz = -v * length
        return (px, py, pz)

    cloth = cb.grid_cloth("BannerCloth", 28, 36, cloth_eval, mat=cloth_mat, closed_u=False, smooth=True)
    cb.add_subsurf(cloth, levels=1)

    # Sculpted Embossed Stitched Gold Trim along left, right & bottom swallow-tail edges
    left_edge = [(cloth_eval(0.02, i / 20.0)[0], cloth_eval(0.02, i / 20.0)[1] - 0.010, cloth_eval(0.02, i / 20.0)[2]) for i in range(21)]
    right_edge = [(cloth_eval(0.98, i / 20.0)[0], cloth_eval(0.98, i / 20.0)[1] - 0.010, cloth_eval(0.98, i / 20.0)[2]) for i in range(21)]
    bot_edge = [(cloth_eval(i / 20.0, 1.0)[0], cloth_eval(i / 20.0, 1.0)[1] - 0.010, cloth_eval(i / 20.0, 1.0)[2]) for i in range(21)]
    cb.tube_along_points("BannerTrimL", left_edge, 0.013, ring_segs=8, mat=trim_mat)
    cb.tube_along_points("BannerTrimR", right_edge, 0.013, ring_segs=8, mat=trim_mat)
    cb.tube_along_points("BannerTrimBot", bot_edge, 0.014, ring_segs=8, mat=trim_mat)

    # Golden Fringed Tassels along swallow-tail hem
    for ti in range(9):
        u_t = 0.06 + (ti / 8.0) * 0.88
        px, py, pz = cloth_eval(u_t, 1.0)
        cb.lathe_profile(
            f"BannerTrimTassel_{ti}",
            [(0.012, 0.0), (0.015, -0.03), (0.008, -0.07), (0.002, -0.095)],
            segments=8,
            mat=trim_mat,
        ).location = (px, py - 0.010, pz)

    # Central Sculpted 8-Point Heraldic Star Medallion embossed on cloth chest
    med_z = -0.62
    _, med_y, _ = cloth_eval(0.5, 0.42)
    med_pts = []
    for si in range(16):
        a = (si / 16.0) * math.tau + math.pi * 0.5
        r = 0.165 if si % 2 == 0 else 0.068
        med_pts.append((math.cos(a) * r, med_z + math.sin(a) * r))
    med = cb.extrude_poly_3d("BannerTrimStar", med_pts, depth=0.026, axis="Y", mat=trim_mat, smooth=False, bevel_w=0.003)
    med.location = (0.0, med_y - 0.014, 0.0)
    cb.make_cylinder("BannerTrimRing", 0.11, 0.11, 0.022, segments=24, center_xyz=(0.0, med_y - 0.016, med_z), mat=trim_mat, rot_deg=(90, 0, 0))

    cb.export_glb("tavern_banner.glb")


def build_tavern_barrel():
    cb.clear_scene()
    wood_mat = cb.make_pbr_mat("BarrelWood", (0.34, 0.21, 0.12), roughness=0.72)
    iron_mat = cb.make_pbr_mat("BarrelIron", (0.16, 0.17, 0.20), roughness=0.44, metallic=0.82)
    brass_mat = cb.make_pbr_mat("BarrelBrass", (0.76, 0.56, 0.22), roughness=0.30, metallic=0.88)

    # 20 individual curved beveled oak staves around height 0..0.96
    n_staves = 20
    for si in range(n_staves):
        ang = (si / n_staves) * math.tau
        d_ang = (math.tau / n_staves) * 0.44
        bm = bmesh.new()
        rings_prof = [(0.305, 0.0), (0.342, 0.16), (0.376, 0.34), (0.388, 0.48), (0.376, 0.62), (0.342, 0.80), (0.305, 0.96)]
        ring_quads = []
        for r_out, z_p in rings_prof:
            r_in = r_out - 0.028
            c0, s0 = math.cos(ang - d_ang), math.sin(ang - d_ang)
            c1, s1 = math.cos(ang + d_ang), math.sin(ang + d_ang)
            v0 = bm.verts.new((c0 * r_out, s0 * r_out, z_p))
            v1 = bm.verts.new((c1 * r_out, s1 * r_out, z_p))
            v2 = bm.verts.new((c1 * r_in, s1 * r_in, z_p))
            v3 = bm.verts.new((c0 * r_in, s0 * r_in, z_p))
            ring_quads.append((v0, v1, v2, v3))
        for ri in range(len(ring_quads) - 1):
            a = ring_quads[ri]
            b = ring_quads[ri + 1]
            for k in range(4):
                kn = (k + 1) % 4
                bm.faces.new((a[k], a[kn], b[kn], b[k]))
        bm.faces.new(list(reversed(ring_quads[0])))
        bm.faces.new(ring_quads[-1])
        stave = cb.finish_bmesh(f"BarrelStave_{si}", bm, mat=wood_mat, smooth=True)
        cb.add_bevel(stave, width=0.0025, segments=1)

    # Top & bottom recessed wooden lids
    cb.make_cylinder("BarrelLidBot", 0.292, 0.292, 0.03, segments=20, center_xyz=(0, 0, 0.045), mat=wood_mat)
    cb.make_cylinder("BarrelLidTop", 0.292, 0.292, 0.03, segments=20, center_xyz=(0, 0, 0.915), mat=wood_mat)

    # 4 Forged Beveled Iron Hoops + Rivets
    for hz, hr in [(0.11, 0.335), (0.31, 0.376), (0.65, 0.376), (0.85, 0.335)]:
        cb.lathe_profile(
            f"BarrelHoop_{int(hz*100)}",
            [(hr - 0.004, hz - 0.025), (hr + 0.012, hz - 0.022), (hr + 0.012, hz + 0.022), (hr - 0.004, hz + 0.025)],
            segments=28,
            mat=iron_mat,
            smooth=False,
        )
        for ri in range(8):
            ra = (ri / 8.0) * math.tau + hz
            cb.make_sphere(f"HoopRivet_{int(hz*100)}_{ri}", 0.008, segments=8, rings=4, center_xyz=(math.cos(ra) * (hr + 0.012), math.sin(ra) * (hr + 0.012), hz), mat=iron_mat)

    # Wooden + Brass Tap Spigot facing front (-Y Blender -> +Z Godot)
    cb.make_cylinder("BarrelBung", 0.028, 0.024, 0.08, segments=12, center_xyz=(0.0, -0.375, 0.24), mat=brass_mat, rot_deg=(90, 0, 0))
    cb.make_cylinder("BarrelSpout", 0.012, 0.010, 0.04, segments=10, center_xyz=(0.0, -0.415, 0.22), mat=brass_mat)

    cb.export_glb("tavern_barrel.glb")


def build_tavern_chair():
    cb.clear_scene()
    wood_mat = cb.make_pbr_mat("ChairOak", (0.28, 0.17, 0.10), roughness=0.62)
    cushion_mat = cb.make_pbr_mat("ChairLeather", (0.36, 0.12, 0.10), roughness=0.72)
    brass_mat = cb.make_pbr_mat("ChairBrass", (0.82, 0.62, 0.22), roughness=0.30, metallic=0.88)

    # 4 turned legs
    for lx in (-0.23, 0.23):
        for ly in (-0.21, 0.21):
            is_back = (ly > 0.0)  # Blender +Y is back (-Z Godot)
            h_top = 1.15 if is_back else 0.48
            cb.lathe_profile(
                f"ChairLeg_{int(lx*10)}_{int(ly*10)}",
                [(0.022, 0.0), (0.032, 0.08), (0.024, 0.18), (0.034, 0.34), (0.032, h_top)],
                segments=12,
                mat=wood_mat,
            ).location = (lx, ly, 0.0)
            if is_back:
                cb.make_sphere(f"ChairFinial_{int(lx*10)}", 0.036, segments=12, rings=8, center_xyz=(lx, ly, h_top + 0.025), scale_xyz=(1, 1, 1.35), mat=brass_mat)

    # H-Stretcher rungs
    cb.make_cylinder("ChairRungL", 0.016, 0.016, 0.42, segments=10, center_xyz=(-0.23, 0.0, 0.18), mat=wood_mat, rot_deg=(90, 0, 0))
    cb.make_cylinder("ChairRungR", 0.016, 0.016, 0.42, segments=10, center_xyz=(0.23, 0.0, 0.18), mat=wood_mat, rot_deg=(90, 0, 0))
    cb.make_cylinder("ChairRungMid", 0.016, 0.016, 0.46, segments=10, center_xyz=(0.0, 0.0, 0.18), mat=wood_mat, rot_deg=(0, 90, 0))

    # Molded wooden seat + Tufted leather cushion
    cb.make_box("ChairSeat", (0.56, 0.50, 0.055), center_xyz=(0.0, 0.0, 0.48), mat=wood_mat, bevel_w=0.010)
    cb.make_box("ChairCushion", (0.48, 0.42, 0.042), center_xyz=(0.0, -0.01, 0.518), mat=cushion_mat, bevel_w=0.014)

    # Backrest arched top crest rail + 3 vertical carved slats
    crest = cb.make_box("ChairCrestRail", (0.52, 0.052, 0.12), center_xyz=(0.0, 0.21, 1.07), mat=wood_mat, bevel_w=0.008)
    cb.make_box("ChairBotRail", (0.48, 0.042, 0.06), center_xyz=(0.0, 0.21, 0.58), mat=wood_mat, bevel_w=0.006)
    for sx in (-0.13, 0.0, 0.13):
        cb.make_box(f"ChairSlat_{int(sx*100)}", (0.068, 0.028, 0.46), center_xyz=(sx, 0.21, 0.82), mat=wood_mat, bevel_w=0.005)
    cb.make_sphere("ChairMedallion", 0.032, segments=12, rings=8, center_xyz=(0.0, 0.18, 1.07), scale_xyz=(1.2, 0.4, 1.2), mat=brass_mat)

    cb.export_glb("tavern_chair.glb")


def build_tavern_chandelier():
    """Origin at ceiling hook (0,0,0), hanging down to z_bl = -1.48."""
    cb.clear_scene()
    iron_mat = cb.make_pbr_mat("ChandIron", (0.14, 0.15, 0.18), roughness=0.40, metallic=0.86)
    brass_mat = cb.make_pbr_mat("ChandBrass", (0.86, 0.66, 0.24), roughness=0.28, metallic=0.90)
    wax_mat = cb.make_pbr_mat("ChandWax", (0.94, 0.88, 0.74), roughness=0.48, subsurface=0.12)
    flame_mat = cb.make_pbr_mat("FlameGlow", (1.0, 0.86, 0.40), roughness=0.10, emission=(1.0, 0.72, 0.20), emission_strength=4.5)

    # Forged suspension chain links from z = -0.05 down to z = -0.92
    for li in range(9):
        lz = -0.08 - li * 0.10
        rot_z = 90.0 if (li % 2 == 1) else 0.0
        pts = [(math.cos(a) * 0.022 * math.cos(math.radians(rot_z)), math.cos(a) * 0.022 * math.sin(math.radians(rot_z)), lz + math.sin(a) * 0.048) for a in [i * math.tau / 12.0 for i in range(13)]]
        cb.tube_along_points(f"ChainLink_{li}", pts, 0.0065, ring_segs=6, mat=iron_mat, cap_ends=False)

    # Central forged boss + lower finial
    cb.lathe_profile(
        "ChandHub",
        [(0.012, -1.08), (0.042, -1.02), (0.095, -0.95), (0.072, -0.89), (0.024, -0.85)],
        segments=16,
        mat=iron_mat,
    )

    # Wheel ring at z = -1.36, radius = 0.66
    wheel_z = -1.36
    wheel_r = 0.66
    w_pts = [(math.cos(a) * wheel_r, math.sin(a) * wheel_r, wheel_z) for a in [i * math.tau / 24.0 for i in range(25)]]
    cb.tube_along_points("ChandWheel", w_pts, 0.030, ring_segs=10, mat=iron_mat, cap_ends=False, scale_xy_fn=lambda i, n: (0.65, 1.35))

    # 4 S-scroll diagonal iron hanger arms from hub to wheel
    for si in range(4):
        ang = (si / 4.0) * math.tau + math.pi * 0.25
        ca, sa = math.cos(ang), math.sin(ang)
        pts = [
            (ca * 0.06, sa * 0.06, -0.92),
            (ca * 0.24, sa * 0.24, -0.96),
            (ca * 0.44, sa * 0.44, -1.16),
            (ca * wheel_r, sa * wheel_r, wheel_z + 0.02),
        ]
        cb.tube_along_points(f"ChandArm_{si}", pts, [0.014, 0.012, 0.012, 0.015], ring_segs=8, mat=iron_mat)
        # Inner radial spoke bar
        cb.tube_along_points(f"ChandSpoke_{si}", [(0, 0, wheel_z), (ca * wheel_r, sa * wheel_r, wheel_z)], 0.012, ring_segs=8, mat=iron_mat)

    # 8 Scalloped Brass Drip Saucers + Candles + Flames around Wheel
    for ci in range(8):
        ang = (ci / 8.0) * math.tau
        cx, cy = math.cos(ang) * wheel_r, math.sin(ang) * wheel_r
        cb.lathe_profile(
            f"CandleCup_{ci}",
            [(0.016, wheel_z + 0.01), (0.062, wheel_z + 0.032), (0.068, wheel_z + 0.042), (0.026, wheel_z + 0.036)],
            segments=14,
            mat=brass_mat,
        ).location = (cx, cy, 0.0)
        ch = 0.13 + 0.035 * math.sin(ci * 2.1)
        cb.lathe_profile(
            f"CandleWax_{ci}",
            [(0.026, wheel_z + 0.038), (0.024, wheel_z + 0.038 + ch * 0.7), (0.022, wheel_z + 0.038 + ch)],
            segments=12,
            mat=wax_mat,
        ).location = (cx, cy, 0.0)
        cb.lathe_profile(
            f"FlameGlow_{ci}",
            [(0.002, wheel_z + 0.04 + ch), (0.016, wheel_z + 0.055 + ch), (0.012, wheel_z + 0.078 + ch), (0.002, wheel_z + 0.098 + ch)],
            segments=10,
            mat=flame_mat,
        ).location = (cx, cy, 0.0)

    cb.export_glb("tavern_chandelier.glb")


def build_tavern_lantern():
    cb.clear_scene()
    iron_mat = cb.make_pbr_mat("SconceIron", (0.14, 0.15, 0.18), roughness=0.42, metallic=0.84)
    glass_mat = cb.make_pbr_mat("SconceGlass", (1.0, 0.78, 0.34), roughness=0.14, emission=(1.0, 0.62, 0.18), emission_strength=2.6)

    # Wall mounting iron plate at y_bl = 0, facing -Y Blender (+Z Godot)
    cb.extrude_poly_3d(
        "SconceWallPlate",
        [(0.0, 0.18), (0.07, 0.10), (0.07, -0.10), (0.0, -0.18), (-0.07, -0.10), (-0.07, 0.10)],
        depth=0.025,
        axis="Y",
        mat=iron_mat,
        bevel_w=0.004,
    )
    # Scrolled crane arm extending toward -Y
    cb.tube_along_points("SconceArm", [(0, -0.01, 0.08), (0, -0.12, 0.16), (0, -0.22, 0.18), (0, -0.24, 0.13)], 0.012, ring_segs=8, mat=iron_mat)

    # Hanging hexagonal cage lantern centered at (0, -0.24, 0.0)
    lx, ly = 0.0, -0.24
    cb.lathe_profile("SconceRoof", [(0.008, 0.16), (0.032, 0.12), (0.115, 0.06), (0.122, 0.04)], segments=6, mat=iron_mat, smooth=False).location = (lx, ly, 0.0)
    cb.lathe_profile("SconceBot", [(0.008, -0.17), (0.088, -0.11), (0.085, -0.095)], segments=6, mat=iron_mat, smooth=False).location = (lx, ly, 0.0)
    cb.lathe_profile("SconceGlass", [(0.072, -0.095), (0.088, 0.042)], segments=6, mat=glass_mat, smooth=True).location = (lx, ly, 0.0)
    for bi in range(6):
        a = (bi / 6.0) * math.tau
        ca, sa = math.cos(a), math.sin(a)
        cb.tube_along_points(f"SconceBar_{bi}", [(lx + ca * 0.082, ly + sa * 0.082, -0.10), (lx + ca * 0.104, ly + sa * 0.104, 0.045)], 0.007, ring_segs=6, mat=iron_mat)

    cb.export_glb("tavern_lantern.glb")


def build_tavern_hearth_bar_trophy():
    # ------------------------------------------------------------------
    # TAVERN HEARTH (Placed at x=-5.05, facing +X into the room)
    # ------------------------------------------------------------------
    cb.clear_scene()
    stone_mat = cb.make_pbr_mat("HearthStone", (0.28, 0.27, 0.29), roughness=0.88)
    soot_mat = cb.make_pbr_mat("HearthSoot", (0.06, 0.055, 0.06), roughness=0.95)
    wood_mat = cb.make_pbr_mat("HearthMantel", (0.24, 0.15, 0.09), roughness=0.66)
    iron_mat = cb.make_pbr_mat("HearthIron", (0.14, 0.14, 0.16), roughness=0.45, metallic=0.84)
    ember_mat = cb.make_pbr_mat("HearthEmbers", (1.0, 0.42, 0.08), roughness=0.25, emission=(1.0, 0.46, 0.10), emission_strength=3.6)

    # Stepped ashlar stone base & side piers framing opening width Y=[-0.58..+0.58]
    cb.make_box("HearthSlab", (0.72, 2.25, 0.10), center_xyz=(0.12, 0.0, 0.05), mat=stone_mat, bevel_w=0.015)
    cb.make_box("HearthBack", (0.28, 2.05, 3.60), center_xyz=(-0.12, 0.0, 1.80), mat=soot_mat)
    for sy in (-0.82, 0.82):
        cb.make_box(f"HearthJamb_{'L' if sy < 0 else 'R'}", (0.48, 0.46, 1.42), center_xyz=(0.18, sy, 0.72), mat=stone_mat, bevel_w=0.02)
        cb.make_box(f"HearthCorbel_{'L' if sy < 0 else 'R'}", (0.62, 0.42, 0.22), center_xyz=(0.24, sy, 1.38), mat=stone_mat, bevel_w=0.02)
    # Stone chimney breast tapering toward ceiling
    cb.make_box("HearthHood", (0.52, 1.96, 2.05), center_xyz=(0.12, 0.0, 2.58), mat=stone_mat, bevel_w=0.025)
    # Keystone arch stones over firebox
    for ai in range(7):
        t = (ai / 6.0) - 0.5
        ya = t * 1.18
        za = 1.24 + 0.14 * (1.0 - (t * 2.0) ** 2)
        cb.make_box(f"ArchStone_{ai}", (0.50, 0.19, 0.22), center_xyz=(0.18, ya, za), mat=stone_mat, bevel_w=0.015, rot_deg=(t * -28.0, 0.0, 0.0))
    # Carved thick oak mantelpiece
    cb.make_box("HearthMantelBeam", (0.68, 2.28, 0.18), center_xyz=(0.26, 0.0, 1.54), mat=wood_mat, bevel_w=0.02)

    # Forged iron fire grate & andirons + stacked firewood logs + glowing coals
    for ay in (-0.34, 0.34):
        cb.make_box(f"AndironBar_{'L' if ay < 0 else 'R'}", (0.46, 0.04, 0.05), center_xyz=(0.22, ay, 0.14), mat=iron_mat, bevel_w=0.005)
        cb.make_cylinder(f"AndironPost_{'L' if ay < 0 else 'R'}", 0.025, 0.018, 0.32, segments=10, center_xyz=(0.40, ay, 0.26), mat=iron_mat)
        cb.make_sphere(f"AndironOrb_{'L' if ay < 0 else 'R'}", 0.036, segments=10, rings=8, center_xyz=(0.40, ay, 0.44), mat=iron_mat)
    for lx, ly, lz, r_d in [(0.16, -0.14, 0.22, 8.0), (0.20, 0.14, 0.22, -6.0), (0.18, 0.0, 0.31, 3.0)]:
        cb.make_cylinder(f"FireLog_{int(ly*100)}", 0.075, 0.085, 0.68, segments=10, center_xyz=(lx, ly, lz), mat=wood_mat, rot_deg=(90.0, r_d, 10.0))
    cb.make_sphere("HearthEmberCore", 0.22, segments=14, rings=10, center_xyz=(0.18, 0.0, 0.18), scale_xyz=(0.8, 1.35, 0.55), mat=ember_mat)

    cb.export_glb("tavern_hearth.glb")

    # ------------------------------------------------------------------
    # TAVERN BAR COUNTER (Paneled oak + brass footrail + bar bottles)
    # Placed at (4.2, 0.0, -2.2), room side faces -X!
    # ------------------------------------------------------------------
    cb.clear_scene()
    oak_mat = cb.make_pbr_mat("BarOak", (0.22, 0.14, 0.08), roughness=0.60)
    trim_mat = cb.make_pbr_mat("BarDarkOak", (0.14, 0.09, 0.05), roughness=0.58)
    brass_mat = cb.make_pbr_mat("BarBrass", (0.86, 0.66, 0.22), roughness=0.28, metallic=0.90)
    bottle_mats = [
        cb.make_pbr_mat("GlassEmerald", (0.12, 0.34, 0.18), roughness=0.14, alpha=0.88, coat=0.5),
        cb.make_pbr_mat("GlassRuby", (0.40, 0.10, 0.10), roughness=0.14, alpha=0.88, coat=0.5),
        cb.make_pbr_mat("GlassAmber", (0.36, 0.24, 0.10), roughness=0.14, alpha=0.88, coat=0.5),
    ]
    cork_mat = cb.make_pbr_mat("BottleCork", (0.48, 0.34, 0.20), roughness=0.82)

    cb.make_box("BarBody", (0.96, 2.72, 1.04), center_xyz=(0, 0, 0.52), mat=oak_mat, bevel_w=0.012)
    cb.make_box("BarPlinth", (1.06, 2.82, 0.10), center_xyz=(0, 0, 0.05), mat=trim_mat, bevel_w=0.008)
    cb.make_box("BarCounterTop", (1.18, 2.94, 0.09), center_xyz=(-0.04, 0, 1.08), mat=trim_mat, bevel_w=0.018)
    # Carved wainscoting front panels & pilasters on -X face
    for pi in range(5):
        py = -1.25 + pi * 0.625
        cb.make_box(f"BarPilaster_{pi}", (0.08, 0.12, 0.94), center_xyz=(-0.48, py, 0.54), mat=trim_mat, bevel_w=0.008)
    for qi in range(4):
        qy = -0.94 + qi * 0.625
        cb.make_box(f"BarPanel_{qi}", (0.04, 0.44, 0.66), center_xyz=(-0.48, qy, 0.54), mat=oak_mat, bevel_w=0.010)
    # Brass footrail on -X floor front
    cb.make_cylinder("BarFootrail", 0.022, 0.022, 2.75, segments=12, center_xyz=(-0.62, 0.0, 0.18), mat=brass_mat, rot_deg=(90, 0, 0))
    for b_y in (-1.15, 0.0, 1.15):
        cb.make_box(f"FootBracket_{int(b_y*10)}", (0.16, 0.03, 0.03), center_xyz=(-0.54, b_y, 0.18), mat=brass_mat)
    # Lathe wine bottles sitting atop bar counter (z = 1.125)
    for bi in range(6):
        by = -1.0 + bi * 0.38
        bx = -0.25 + (bi % 2) * 0.10
        bm = bottle_mats[bi % len(bottle_mats)]
        cb.lathe_profile(
            f"BarBottle_{bi}",
            [(0.048, 1.125), (0.052, 1.24), (0.022, 1.30), (0.020, 1.38), (0.024, 1.39)],
            segments=14,
            mat=bm,
        ).location = (bx, by, 0.0)
        cb.make_cylinder(f"BarCork_{bi}", 0.015, 0.013, 0.028, segments=10, center_xyz=(bx, by, 1.40), mat=cork_mat)

    cb.export_glb("tavern_bar.glb")

    # ------------------------------------------------------------------
    # WALL TROPHY PLAQUE (Carved oak shield plaque + Crossed engraved Swords)
    # ------------------------------------------------------------------
    cb.clear_scene()
    oak_mat = cb.make_pbr_mat("TrophyOak", (0.22, 0.13, 0.08), roughness=0.62)
    steel_mat = cb.make_pbr_mat("TrophySteel", (0.76, 0.80, 0.86), roughness=0.22, metallic=0.92)
    brass_mat = cb.make_pbr_mat("TrophyBrass", (0.88, 0.68, 0.24), roughness=0.26, metallic=0.90)

    plaque_pts = [(-0.28, 0.34), (0.28, 0.34), (0.30, -0.02), (0.20, -0.26), (0.0, -0.40), (-0.20, -0.26), (-0.30, -0.02)]
    cb.extrude_poly_3d("TrophyPlaque", plaque_pts, depth=0.055, axis="Y", mat=oak_mat, bevel_w=0.012)
    cb.make_sphere("TrophyBoss", 0.085, segments=16, rings=10, center_xyz=(0, -0.04, 0.0), scale_xyz=(1, 0.45, 1), mat=brass_mat)
    for ang_d in (-38.0, 38.0):
        rad = math.radians(ang_d)
        ca, sa = math.cos(rad), math.sin(rad)
        def spt(u, v):
            return (u * ca - v * sa, -0.02, u * sa + v * ca)
        cb.tube_along_points(f"TrophyBlade_{int(ang_d)}", [spt(0, -0.48), spt(0, 0.38), spt(0, 0.50)], [0.024, 0.018, 0.003], ring_segs=4, mat=steel_mat, scale_xy_fn=lambda i, n: (1.0, 0.25))
        cb.tube_along_points(f"TrophyGuard_{int(ang_d)}", [spt(-0.11, -0.34), spt(0, -0.32), spt(0.11, -0.34)], 0.012, ring_segs=8, mat=brass_mat)

    cb.export_glb("wall_trophy.glb")


if __name__ == "__main__":
    build_wall_crest_shield()
    build_tavern_banner()
    build_tavern_barrel()
    build_tavern_chair()
    build_tavern_chandelier()
    build_tavern_lantern()
    build_tavern_hearth_bar_trophy()
    print("[GEN_TAVERN_INTERIOR_DONE]")
