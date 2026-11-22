import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_bl as cb


def build_battle_table():
    """Carved heavy octagonal/round tavern duel table:
    - Recessed flat inner bed z=0.798 out to r=1.44 (so felt at y=0.805, r=1.38 & tabletop props at y=0.80..0.822 sit solidly!)
    - Sculpted dark-oak & tufted leather bolster rim rising from r=1.44..1.89 cresting at z=0.844
    - Forged iron clasp brackets, brass studs, carved gothic apron & massive pedestal with 4 arched feet.
    """
    cb.clear_scene()
    oak_mat = cb.make_pbr_mat("TableOak", (0.28, 0.17, 0.10), roughness=0.58)
    dark_oak_mat = cb.make_pbr_mat("TableDarkOak", (0.16, 0.095, 0.055), roughness=0.54)
    leather_mat = cb.make_pbr_mat("TableLeatherRim", (0.18, 0.085, 0.075), roughness=0.46, coat=0.22)
    iron_mat = cb.make_pbr_mat("TableIron", (0.15, 0.16, 0.19), roughness=0.42, metallic=0.84)
    brass_mat = cb.make_pbr_mat("TableBrass", (0.86, 0.65, 0.24), roughness=0.26, metallic=0.90)

    # Lathe the primary carved table slab + bolster + outer stepped molding (64 segments for silky round feel, 16-facet brass hardware)
    table_prof = [
        (0.28, 0.70),    # Underside neck
        (1.42, 0.72),    # Flat bottom under felt zone
        (1.66, 0.72),
        (1.80, 0.74),    # Lower bevel ogee
        (1.89, 0.775),   # Widest outer molding nose
        (1.88, 0.818),   # Upper outer edge
        (1.78, 0.836),   # Bolster outer crest
        (1.56, 0.838),   # Bolster armrest crown
        (1.46, 0.824),   # Inner drop lip toward tabletop
        (1.42, 0.798),   # Recessed flat play deck!
        (0.005, 0.798),
    ]
    cb.lathe_profile("TableBodySlab", table_prof, segments=64, mat=oak_mat, smooth=True, cap_bottom=False, cap_top=False)

    # Padded Stitched Leather Bolster Cushion inlaid around the armrest ring (r = 1.50 .. 1.82)
    bolster_prof = [
        (1.50, 0.825),
        (1.56, 0.848),
        (1.68, 0.854),
        (1.79, 0.846),
        (1.83, 0.826),
        (1.50, 0.825),
    ]
    cb.lathe_profile("TableBolsterLeather", bolster_prof, segments=64, mat=leather_mat, smooth=True, cap_bottom=False, cap_top=False)

    # Inner Beveled Burnished Brass Inlay Collar at r = 1.43
    cb.lathe_profile(
        "TableBrassInlay",
        [(1.40, 0.798), (1.425, 0.808), (1.455, 0.814), (1.475, 0.808), (1.475, 0.797)],
        segments=64,
        mat=brass_mat,
        smooth=True,
        cap_bottom=False,
        cap_top=False,
    )

    # 16 Forged Iron & Brass Corner Brackets + Domed Rivets around table edge
    for bi in range(16):
        ang = (bi / 16.0) * math.tau + math.pi / 16.0
        ca, sa = math.cos(ang), math.sin(ang)
        deg_z = math.degrees(ang)
        # Forged L-strap hugging edge
        cb.make_box("RimBracket_" + str(bi), (0.09, 0.14, 0.075), center_xyz=(ca * 1.855, sa * 1.855, 0.795), mat=iron_mat, bevel_w=0.006, rot_deg=(0, 0, deg_z))
        # Domed brass rivet stud on bolster transition
        cb.make_sphere("RimStud_" + str(bi), 0.015, segments=10, rings=6, center_xyz=(ca * 1.485, sa * 1.485, 0.830), scale_xyz=(1, 1, 0.55), mat=brass_mat)

    # Sculpted Carved Gothic Apron Skirt under slab (y = 0.56 .. 0.72, r = 1.44 .. 1.56)
    cb.lathe_profile(
        "TableGothicApron",
        [(1.42, 0.57), (1.53, 0.58), (1.56, 0.66), (1.55, 0.72), (1.40, 0.72)],
        segments=16,
        mat=dark_oak_mat,
        smooth=False,
        cap_bottom=False,
        cap_top=False,
    )
    for bi in range(16):
        ang = (bi / 16.0) * math.tau
        cb.make_box(f"ApronCorbel_{bi}", (0.10, 0.11, 0.15), center_xyz=(math.cos(ang) * 1.52, math.sin(ang) * 1.52, 0.64), mat=brass_mat if bi % 2 == 0 else dark_oak_mat, bevel_w=0.008, rot_deg=(0, 0, math.degrees(ang)))

    # Massive Baroque Turned Oak Central Pedestal (z = 0.14 .. 0.71)
    ped_prof = [
        (0.01, 0.12),
        (0.46, 0.14),
        (0.48, 0.19),
        (0.32, 0.25),
        (0.24, 0.34),
        (0.36, 0.43),  # Central turned urn bulb
        (0.26, 0.52),
        (0.38, 0.62),
        (0.48, 0.71),
    ]
    cb.lathe_profile("TablePedestal", ped_prof, segments=24, mat=dark_oak_mat, smooth=True)

    # 4 Carved Splayed Arched Buttress Feet resting firmly on floor (z = 0.0 .. 0.34, r out to 1.16)
    for fi in range(4):
        ang = (fi / 4.0) * math.tau + math.pi * 0.25
        ca, sa = math.cos(ang), math.sin(ang)
        pts = [
            (ca * 0.22, sa * 0.22, 0.30),
            (ca * 0.52, sa * 0.52, 0.24),
            (ca * 0.85, sa * 0.85, 0.14),
            (ca * 1.10, sa * 1.10, 0.045),
        ]
        cb.tube_along_points(
            f"TableFoot_{fi}",
            pts,
            [0.095, 0.088, 0.075, 0.092],
            ring_segs=10,
            mat=dark_oak_mat,
            scale_xy_fn=lambda i, n: (0.78, 1.35),
        )
        # Claw/iron shoe pad at floor contact
        cb.make_box(f"TableFootPad_{fi}", (0.18, 0.22, 0.055), center_xyz=(ca * 1.12, sa * 1.12, 0.028), mat=iron_mat, bevel_w=0.008, rot_deg=(0, 0, math.degrees(ang)))

    # Forged iron structural stretcher ring tying the 4 legs at z=0.22
    ring_pts = [(math.cos(a) * 0.62, math.sin(a) * 0.62, 0.22) for a in [i * math.tau / 24.0 for i in range(25)]]
    cb.tube_along_points("TableStretcherRing", ring_pts, 0.026, ring_segs=10, mat=iron_mat, cap_ends=False)

    cb.export_glb("battle_table.glb")


def build_phial_ignis():
    """Ornate faceted blown-crystal alchemical Hellfire flask in wrought-iron cage (height ~0.195m)."""
    cb.clear_scene()
    glass_mat = cb.make_pbr_mat("PhialGlassMat", (0.72, 0.18, 0.05), roughness=0.10, metallic=0.05, alpha=0.80, coat=0.7, emission=(0.45, 0.12, 0.02), emission_strength=0.45)
    core_mat = cb.make_pbr_mat("PhialCoreMat", (1.0, 0.56, 0.10), roughness=0.18, emission=(1.0, 0.42, 0.06), emission_strength=3.8)
    iron_mat = cb.make_pbr_mat("PhialIronMat", (0.15, 0.15, 0.18), roughness=0.40, metallic=0.86)
    brass_mat = cb.make_pbr_mat("PhialBrassMat", (0.88, 0.66, 0.22), roughness=0.26, metallic=0.90)
    cork_mat = cb.make_pbr_mat("PhialCorkMat", (0.50, 0.34, 0.18), roughness=0.84)
    wax_mat = cb.make_pbr_mat("PhialWaxMat", (0.68, 0.08, 0.09), roughness=0.30, coat=0.4, emission=(0.24, 0.02, 0.02), emission_strength=0.3)

    # Fluted blown-glass flask body
    def glass_rad(r, z, ang, ri, np_):
        flute = 1.0 + (0.045 * math.cos(ang * 10.0) if 0.02 < z < 0.12 else 0.0)
        return (math.cos(ang) * r * flute, math.sin(ang) * r * flute, z)

    flask_prof = [
        (0.042, 0.010),
        (0.060, 0.032),
        (0.064, 0.062),
        (0.056, 0.092),
        (0.028, 0.122),
        (0.022, 0.154),
        (0.029, 0.165),  # flared glass lip
        (0.022, 0.168),
    ]
    cb.lathe_profile("PhialGlass", flask_prof, segments=30, mat=glass_mat, smooth=True, radial_fn=glass_rad)

    # Glowing molten ember sphere core inside belly
    cb.make_sphere("PhialCore", 0.038, segments=18, rings=12, center_xyz=(0, 0, 0.064), scale_xyz=(1.0, 1.0, 1.15), mat=core_mat)

    # Forged iron coaster foot + waist ring + collar
    cb.lathe_profile("PhialFoot", [(0.068, 0.0), (0.066, 0.010), (0.054, 0.016), (0.046, 0.012)], segments=16, mat=iron_mat)
    cb.lathe_profile("PhialWaistBand", [(0.061, 0.058), (0.067, 0.061), (0.067, 0.069), (0.061, 0.072)], segments=24, mat=iron_mat, cap_bottom=False, cap_top=False)
    cb.lathe_profile("PhialNeckCollar", [(0.024, 0.150), (0.031, 0.153), (0.031, 0.161), (0.024, 0.164)], segments=20, mat=brass_mat, cap_bottom=False, cap_top=False)

    # 4 Forged S-curve Vertical Cage Straps + twin brass scroll handles
    for si in range(4):
        ang = (si / 4.0) * math.tau + math.pi * 0.25
        ca, sa = math.cos(ang), math.sin(ang)
        pts = [
            (ca * 0.056, sa * 0.056, 0.012),
            (ca * 0.067, sa * 0.067, 0.048),
            (ca * 0.065, sa * 0.065, 0.082),
            (ca * 0.034, sa * 0.034, 0.122),
            (ca * 0.028, sa * 0.028, 0.156),
        ]
        cb.tube_along_points(f"PhialRib_{si}", pts, 0.0038, ring_segs=8, mat=iron_mat)

    for sx in (-1.0, 1.0):
        h_pts = [
            (sx * 0.030, 0.0, 0.145),
            (sx * 0.056, 0.0, 0.125),
            (sx * 0.076, 0.0, 0.095),
            (sx * 0.068, 0.0, 0.066),
        ]
        cb.tube_along_points(f"PhialHandle_{'L' if sx < 0 else 'R'}", h_pts, 0.0035, ring_segs=8, mat=brass_mat)

    # Tapered Cork + Sculpted Dripping Crimson Wax Seal Stamp
    cb.make_cylinder("PhialCork", 0.018, 0.021, 0.026, segments=14, center_xyz=(0, 0, 0.175), mat=cork_mat)
    cb.make_cylinder("PhialWaxCap", 0.023, 0.021, 0.012, segments=16, center_xyz=(0, 0, 0.189), mat=wax_mat, bevel_w=0.003)
    for di, dang in enumerate((0.4, 2.2, 4.3)):
        cb.tube_along_points(
            f"WaxDrip_{di}",
            [(math.cos(dang) * 0.021, math.sin(dang) * 0.021, 0.188), (math.cos(dang) * 0.024, math.sin(dang) * 0.024, 0.172 - (di % 2) * 0.008)],
            [0.0045, 0.0028],
            ring_segs=8,
            mat=wax_mat,
        )

    cb.export_glb("phial_ignis.glb")


def build_sword_oath():
    """Sculpted diamond-beveled Longsword laying flat on table:
    - Tip toward Godot -Z (Blender +Y = +0.68m)
    - Crossguard near Y_bl = 0.015, Grip & Pommel toward Y_bl = -0.20 (Godot +Z)
    - Named sub-meshes: Blade, Fuller, Guard, Grip, Pommel, Gem for dynamic skin tinting!
    """
    cb.clear_scene()
    blade_mat = cb.make_pbr_mat("SwordBladeMat", (0.76, 0.80, 0.86), roughness=0.20, metallic=0.92)
    fuller_mat = cb.make_pbr_mat("SwordFullerMat", (0.90, 0.94, 1.0), roughness=0.14, metallic=0.80, emission=(0.45, 0.72, 1.0), emission_strength=0.9)
    guard_mat = cb.make_pbr_mat("SwordGuardMat", (0.86, 0.64, 0.22), roughness=0.25, metallic=0.90)
    grip_mat = cb.make_pbr_mat("SwordGripMat", (0.30, 0.16, 0.09), roughness=0.72)
    gem_mat = cb.make_pbr_mat("SwordGemMat", (0.95, 0.78, 0.28), roughness=0.10, emission=(0.95, 0.65, 0.18), emission_strength=2.2)

    z_c = 0.016  # laying center height on table

    # 1. Real Diamond Cross-Section Tapered Longsword Blade (Tip -> +Y Blender -> -Z Godot!)
    bm = bmesh.new()
    # Cross-section stations along Y_bl: (y_bl, half_width, spine_half_thick)
    stations = [
        (0.015, 0.024, 0.0075),
        (0.070, 0.023, 0.0068),
        (0.280, 0.020, 0.0060),
        (0.480, 0.016, 0.0052),
        (0.580, 0.011, 0.0040),
        (0.655, 0.005, 0.0024),
    ]
    rings = []
    for yb, hw, st in stations:
        v_top = bm.verts.new((0.0, yb, z_c + st))
        v_r = bm.verts.new((hw, yb, z_c))
        v_bot = bm.verts.new((0.0, yb, z_c - st))
        v_l = bm.verts.new((-hw, yb, z_c))
        rings.append((v_top, v_r, v_bot, v_l))
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(4):
            kn = (k + 1) % 4
            bm.faces.new((a[k], a[kn], b[kn], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    # Taper to needle tip at (0, +0.695, z_c)
    v_tip = bm.verts.new((0.0, 0.695, z_c))
    last = rings[-1]
    for k in range(4):
        kn = (k + 1) % 4
        bm.faces.new((last[k], last[kn], v_tip))
    cb.finish_bmesh("Blade", bm, mat=blade_mat, smooth=False)

    # 2. Fuller Rune Channel Bar inlaid cleanly along upper & lower faces
    cb.tube_along_points(
        "Fuller",
        [(0.0, 0.045, z_c), (0.0, 0.28, z_c), (0.0, 0.49, z_c)],
        [0.0055, 0.0046, 0.0028],
        ring_segs=6,
        mat=fuller_mat,
        scale_xy_fn=lambda i, n: (1.0, 1.45),
    )

    # 3. Sculpted S-Curved Gothic Crossguard + Trefoil Quillon Tips + Central Shield Ecusson
    g_pts = [
        (-0.115, 0.032, z_c),
        (-0.075, 0.020, z_c),
        (-0.032, 0.010, z_c),
        (0.0, 0.008, z_c),
        (0.032, 0.010, z_c),
        (0.075, 0.020, z_c),
        (0.115, 0.032, z_c),
    ]
    cb.tube_along_points(
        "GuardCross",
        g_pts,
        [0.012, 0.008, 0.009, 0.013, 0.009, 0.008, 0.012],
        ring_segs=10,
        mat=guard_mat,
        scale_xy_fn=lambda i, n: (0.85, 1.35),
    )
    for sx in (-1.0, 1.0):
        cb.make_sphere(f"GuardFinial_{'L' if sx < 0 else 'R'}", 0.014, segments=12, rings=8, center_xyz=(sx * 0.120, 0.034, z_c), mat=guard_mat)
    cb.make_box("GuardEcusson", (0.044, 0.034, 0.024), center_xyz=(0.0, 0.012, z_c), mat=guard_mat, bevel_w=0.004)

    # 4. Ribbed Leather-Wrapped Grip + Spacer Rings (y_bl = -0.155 .. +0.004)
    cb.tube_along_points(
        "GripCore",
        [(0.0, 0.002, z_c), (0.0, -0.075, z_c), (0.0, -0.154, z_c)],
        [0.0155, 0.0135, 0.0160],
        ring_segs=12,
        mat=grip_mat,
        scale_xy_fn=lambda i, n: (0.88, 1.12),
    )
    for ri, ry in enumerate((-0.022, -0.048, -0.075, -0.102, -0.128)):
        cb.make_cylinder(f"GripRib_{ri}", 0.0155 if ri != 2 else 0.0175, 0.0155 if ri != 2 else 0.0175, 0.007, segments=14, center_xyz=(0.0, ry, z_c), mat=guard_mat if ri == 2 else grip_mat, rot_deg=(90, 0, 0))

    # 5. Fluted Scent-Stopper Pommel (y_bl = -0.154 .. -0.208)
    pom_p = cb.lathe_profile(
        "PommelBody",
        [(0.015, 0.0), (0.028, 0.022), (0.031, 0.036), (0.020, 0.048), (0.006, 0.056)],
        segments=8,
        mat=guard_mat,
        smooth=False,
    )
    pom_p.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    pom_p.location = (0.0, -0.154, z_c)
    cb.add_bevel(pom_p, width=0.002, segments=1)

    # 6. Inset Arcane Crystals in Ecusson & Pommel
    cb.make_sphere("GemCross", 0.011, segments=8, rings=6, center_xyz=(0.0, 0.012, z_c + 0.013), scale_xyz=(1.1, 1.3, 0.55), mat=gem_mat)
    cb.make_sphere("GemPommel", 0.010, segments=8, rings=6, center_xyz=(0.0, -0.184, z_c + 0.018), scale_xyz=(1.0, 1.0, 0.6), mat=gem_mat)

    cb.export_glb("sword_oath.glb")


def build_deck_shoe():
    """Carved mahogany & brass-bracketed tarot card tray holding layered parchment stack + planar DeckTopCard with clean UV."""
    cb.clear_scene()
    wood_mat = cb.make_pbr_mat("ShoeMahogany", (0.24, 0.13, 0.075), roughness=0.56)
    brass_mat = cb.make_pbr_mat("ShoeBrass", (0.86, 0.66, 0.24), roughness=0.28, metallic=0.90)
    edge_mat = cb.make_pbr_mat("DeckParchmentEdge", (0.86, 0.80, 0.66), roughness=0.78)
    edge_alt_mat = cb.make_pbr_mat("DeckParchmentEdgeAlt", (0.76, 0.68, 0.52), roughness=0.82)
    top_mat = cb.make_pbr_mat("DeckTopMat", (0.20, 0.24, 0.36), roughness=0.60)

    # Tray floor & beveled side walls wrapping the deck (cards ~ 0.194 x 0.282, stack z = 0.008..0.068)
    cb.make_box("ShoeBase", (0.224, 0.312, 0.012), center_xyz=(0, 0, 0.006), mat=wood_mat, bevel_w=0.003)
    # Back wall (+Y Blender = -Z Godot), Left & Right walls, split Front thumb-notch walls
    cb.make_box("ShoeWallBack", (0.224, 0.016, 0.048), center_xyz=(0, 0.148, 0.028), mat=wood_mat, bevel_w=0.003)
    for sx in (-1.0, 1.0):
        cb.make_box(f"ShoeWallSide_{'L' if sx < 0 else 'R'}", (0.016, 0.312, 0.046), center_xyz=(sx * 0.104, 0.0, 0.027), mat=wood_mat, bevel_w=0.003)
        cb.make_box(f"ShoeWallFrontTab_{'L' if sx < 0 else 'R'}", (0.056, 0.016, 0.044), center_xyz=(sx * 0.084, -0.148, 0.026), mat=wood_mat, bevel_w=0.003)
        for sy in (-1.0, 1.0):
            cb.make_box(f"ShoeCornerBrass_{int(sx)}_{int(sy)}", (0.028, 0.028, 0.052), center_xyz=(sx * 0.105, sy * 0.149, 0.028), mat=brass_mat, bevel_w=0.003)

    # 12 Stacked Parchment Card Layers with fine subtle rotation offsets so stack edges look physically real!
    for li in range(12):
        lz = 0.014 + li * 0.0044
        yaw = math.sin(li * 1.9) * 1.1
        cb.make_box(
            f"DeckCardLayer_{li}",
            (0.188, 0.276, 0.0040),
            center_xyz=(math.cos(li) * 0.0012, math.sin(li) * 0.0012, lz),
            mat=edge_mat if (li % 2 == 0) else edge_alt_mat,
            rot_deg=(0, 0, yaw),
        )

    # Planar Beveled Top Card (DeckTopCard) at z = 0.067m with exact 0..1 UVs facing UP (+Z_bl = +Y_godot)!
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    hw, hd = 0.095, 0.139
    z_top, z_bot = 0.0682, 0.0645
    # Corners: Front in Blender is -Y (bottom of card), Back is +Y (top of card)
    t0 = bm.verts.new((-hw, -hd, z_top))
    t1 = bm.verts.new((+hw, -hd, z_top))
    t2 = bm.verts.new((+hw, +hd, z_top))
    t3 = bm.verts.new((-hw, +hd, z_top))
    b0 = bm.verts.new((-hw, -hd, z_bot))
    b1 = bm.verts.new((+hw, -hd, z_bot))
    b2 = bm.verts.new((+hw, +hd, z_bot))
    b3 = bm.verts.new((-hw, +hd, z_bot))

    f_top = bm.faces.new((t0, t1, t2, t3))
    for loop, uv in zip(f_top.loops, [(0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)]):
        loop[uv_layer].uv = uv
    bm.faces.new((b3, b2, b1, b0))
    for p, q, r, s in [(t0, b0, b1, t1), (t1, b1, b2, t2), (t2, b2, b3, t3), (t3, b3, b0, t0)]:
        sf = bm.faces.new((p, q, r, s))
        for loop in sf.loops:
            loop[uv_layer].uv = (0.02, 0.02)
    cb.finish_bmesh("DeckTopCard", bm, mat=top_mat, smooth=False, auto_uv=False)

    cb.export_glb("deck_shoe.glb")


def build_supporting_props():
    # ------------------------------------------------------------------
    # 1. STAVED OAK TAVERN TANKARD + ALE FOAM CROWN
    # ------------------------------------------------------------------
    cb.clear_scene()
    oak_mat = cb.make_pbr_mat("MugOak", (0.36, 0.22, 0.12), roughness=0.60)
    brass_mat = cb.make_pbr_mat("MugBrass", (0.86, 0.66, 0.24), roughness=0.26, metallic=0.90)
    foam_mat = cb.make_pbr_mat("MugFoam", (0.96, 0.91, 0.78), roughness=0.52, subsurface=0.15)
    ale_mat = cb.make_pbr_mat("MugAle", (0.76, 0.44, 0.10), roughness=0.18, coat=0.4)

    # 14 Staved oak planks
    n_st = 14
    for si in range(n_st):
        ang = (si / n_st) * math.tau
        da = (math.tau / n_st) * 0.44
        bm = bmesh.new()
        r_b, r_t = 0.058, 0.050
        rings = [(r_b, 0.0), (0.056, 0.065), (r_t, 0.136)]
        rq = []
        for r_o, zp in rings:
            r_i = r_o - 0.008
            c0, s0 = math.cos(ang - da), math.sin(ang - da)
            c1, s1 = math.cos(ang + da), math.sin(ang + da)
            rq.append((
                bm.verts.new((c0 * r_o, s0 * r_o, zp)),
                bm.verts.new((c1 * r_o, s1 * r_o, zp)),
                bm.verts.new((c1 * r_i, s1 * r_i, zp)),
                bm.verts.new((c0 * r_i, s0 * r_i, zp)),
            ))
        for ri in range(len(rq) - 1):
            a, b = rq[ri], rq[ri + 1]
            for k in range(4):
                kn = (k + 1) % 4
                bm.faces.new((a[k], a[kn], b[kn], b[k]))
        bm.faces.new(list(reversed(rq[0])))
        bm.faces.new(rq[-1])
        cb.finish_bmesh(f"MugStave_{si}", bm, mat=oak_mat, smooth=True)

    cb.make_cylinder("MugBottomDisc", 0.054, 0.054, 0.012, segments=16, center_xyz=(0, 0, 0.012), mat=oak_mat)
    # 2 brass hoops + front crest medallion
    for hz, hr in ((0.025, 0.059), (0.104, 0.054)):
        cb.lathe_profile(f"MugHoop_{int(hz*100)}", [(hr - 0.002, hz - 0.007), (hr + 0.003, hz - 0.006), (hr + 0.003, hz + 0.006), (hr - 0.002, hz + 0.007)], segments=24, mat=brass_mat, smooth=False)
    cb.make_box("MugCrest", (0.028, 0.008, 0.036), center_xyz=(0.0, -0.057, 0.065), mat=brass_mat, bevel_w=0.003)

    # Ergonomic Curved Oak Handle on +X side
    h_pts = [(0.048, 0.0, 0.112), (0.088, 0.0, 0.102), (0.092, 0.0, 0.064), (0.082, 0.0, 0.032), (0.052, 0.0, 0.026)]
    cb.tube_along_points("MugHandle", h_pts, 0.009, ring_segs=10, mat=oak_mat, scale_xy_fn=lambda i, n: (0.75, 1.25))

    # Golden Ale surface + overflowing frothy foam crown
    cb.make_cylinder("MugAleSurface", 0.044, 0.044, 0.010, segments=18, center_xyz=(0, 0, 0.122), mat=ale_mat)
    cb.lathe_profile("MugFoamCap", [(0.002, 0.148), (0.028, 0.145), (0.045, 0.136), (0.046, 0.126)], segments=20, mat=foam_mat)
    for fi, (fx, fy, fr, fz) in enumerate([(0.018, -0.022, 0.016, 0.140), (-0.020, 0.018, 0.018, 0.138), (0.032, 0.028, 0.014, 0.134), (-0.038, -0.024, 0.012, 0.134), (0.044, -0.018, 0.008, 0.116)]):
        cb.make_sphere(f"FoamBubble_{fi}", fr, segments=12, rings=8, center_xyz=(fx, fy, fz), mat=foam_mat)

    cb.export_glb("tavern_mug.glb")

    # ------------------------------------------------------------------
    # 2. PEDDLER BRASS COUNTER BELL
    # ------------------------------------------------------------------
    cb.clear_scene()
    ebony_mat = cb.make_pbr_mat("BellEbony", (0.12, 0.075, 0.055), roughness=0.48)
    brass_mat = cb.make_pbr_mat("BellBrass", (0.92, 0.72, 0.26), roughness=0.20, metallic=0.92)
    copper_mat = cb.make_pbr_mat("BellCopper", (0.78, 0.44, 0.22), roughness=0.26, metallic=0.86)

    # Turned Mahogany/Ebony Base Plinth
    cb.lathe_profile("BellPlinth", [(0.072, 0.0), (0.070, 0.008), (0.060, 0.016), (0.058, 0.021)], segments=28, mat=ebony_mat)
    # Engraved Brass Bell Dome
    cb.lathe_profile(
        "BellDome",
        [(0.056, 0.019), (0.052, 0.025), (0.042, 0.048), (0.034, 0.068), (0.022, 0.080), (0.010, 0.084)],
        segments=32,
        mat=brass_mat,
    )
    cb.lathe_profile("BellCopperTrim", [(0.050, 0.024), (0.054, 0.027), (0.052, 0.032), (0.048, 0.030)], segments=28, mat=copper_mat, cap_bottom=False, cap_top=False)
    # Plunger button
    cb.lathe_profile("BellPlunger", [(0.006, 0.083), (0.006, 0.098), (0.014, 0.101), (0.012, 0.107), (0.002, 0.109)], segments=16, mat=brass_mat)

    cb.export_glb("shop_bell.glb")

    # ------------------------------------------------------------------
    # 3. TWIN-ARM BRASS CANDELABRA WITH MELTED WAX DRIPS
    # ------------------------------------------------------------------
    cb.clear_scene()
    brass_mat = cb.make_pbr_mat("CandBrass", (0.84, 0.62, 0.22), roughness=0.24, metallic=0.90)
    wax_mat = cb.make_pbr_mat("CandWax", (0.94, 0.88, 0.74), roughness=0.45, subsurface=0.14)

    cb.lathe_profile(
        "CandelabraStem",
        [(0.074, 0.0), (0.068, 0.012), (0.036, 0.024), (0.018, 0.042), (0.028, 0.064), (0.014, 0.086), (0.020, 0.118)],
        segments=24,
        mat=brass_mat,
    )
    for sx in (-1.0, 1.0):
        # Sweeping S-scroll arm
        cb.tube_along_points(
            f"CandArm_{'L' if sx < 0 else 'R'}",
            [(0.0, 0.0, 0.096), (sx * 0.034, 0.0, 0.092), (sx * 0.066, 0.0, 0.108), (sx * 0.074, 0.0, 0.128)],
            [0.009, 0.007, 0.0065, 0.008],
            ring_segs=10,
            mat=brass_mat,
        )
        # Drip saucer + uneven melted wax pillar (leaves space for flames at top in Godot!)
        cb.lathe_profile(f"CandCup_{'L' if sx < 0 else 'R'}", [(0.008, 0.125), (0.032, 0.134), (0.034, 0.140), (0.022, 0.136)], segments=16, mat=brass_mat).location = (sx * 0.074, 0.0, 0.0)
        ch = 0.095 if sx < 0 else 0.108
        cb.lathe_profile(f"CandWax_{'L' if sx < 0 else 'R'}", [(0.019, 0.134), (0.018, 0.134 + ch * 0.7), (0.016, 0.134 + ch)], segments=14, mat=wax_mat).location = (sx * 0.074, 0.0, 0.0)
        # Side wax drip
        cb.tube_along_points(
            f"WaxDripC_{'L' if sx < 0 else 'R'}",
            [(sx * 0.074 + sx * 0.016, 0.005, 0.134 + ch), (sx * 0.074 + sx * 0.019, 0.005, 0.134 + ch * 0.62)],
            [0.0038, 0.0022],
            ring_segs=6,
            mat=wax_mat,
        )

    cb.export_glb("candelabra.glb")

    # ------------------------------------------------------------------
    # 4. LEATHER FLORIN POUCH + EMBOSSED COIN STACKS
    # ------------------------------------------------------------------
    cb.clear_scene()
    leather_mat = cb.make_pbr_mat("PouchLeather", (0.34, 0.18, 0.10), roughness=0.72)
    cord_mat = cb.make_pbr_mat("PouchCord", (0.86, 0.66, 0.24), roughness=0.40, metallic=0.35)
    gold_mat = cb.make_pbr_mat("CoinGold", (0.96, 0.75, 0.24), roughness=0.22, metallic=0.92)
    silver_mat = cb.make_pbr_mat("CoinSilver", (0.82, 0.86, 0.92), roughness=0.24, metallic=0.90)

    # Pleated gathered drawstring pouch centered at (-0.065, -0.015_bl, 0)
    def pouch_rad(r, z, ang, ri, np_):
        fold_env = 0.35 + 0.65 * max(0.0, min(1.0, (z - 0.02) / 0.08))
        fold = 1.0 + 0.12 * math.sin(ang * 9.0 + z * 22.0) * fold_env
        return (-0.065 + math.cos(ang) * r * fold, 0.015 + math.sin(ang) * r * fold, z)

    cb.lathe_profile(
        "CoinsPouchBag",
        [(0.048, 0.0), (0.074, 0.024), (0.070, 0.056), (0.032, 0.076), (0.026, 0.082), (0.042, 0.104), (0.020, 0.102)],
        segments=28,
        mat=leather_mat,
        radial_fn=pouch_rad,
    )
    # Tied drawstring cord
    cord_pts = [(-0.065 + math.cos(a) * 0.029, 0.015 + math.sin(a) * 0.029, 0.080) for a in [i * math.tau / 16.0 for i in range(17)]]
    cb.tube_along_points("PouchDrawstring", cord_pts, 0.0045, ring_segs=6, mat=cord_mat, cap_ends=False)

    # 3 Staggered Stacks of Beveled Embossed Gold & Silver Florins
    stacks = [(0.038, -0.02, 5, gold_mat), (0.088, 0.012, 4, silver_mat), (0.062, -0.056, 3, gold_mat)]
    for si, (sx, sy, cnt, cm) in enumerate(stacks):
        for ci in range(cnt):
            jx = math.sin(ci * 2.4 + si) * 0.003
            jy = math.cos(ci * 1.8 + si) * 0.003
            coin = cb.lathe_profile(
                f"FlorinCoin_{si}_{ci}",
                [(0.022, 0.0), (0.022, 0.0055), (0.017, 0.0062)],
                segments=18,
                mat=cm,
            )
            coin.location = (sx + jx, sy + jy, ci * 0.0062)

    cb.export_glb("coins_pouch.glb")

    # ------------------------------------------------------------------
    # 5. BEVELED IVORY BONE DICE PAIR WITH RECESSED CHARCOAL PIPS
    # ------------------------------------------------------------------
    cb.clear_scene()
    bone_mat = cb.make_pbr_mat("BoneDiceMat", (0.93, 0.87, 0.72), roughness=0.38)
    pip_mat = cb.make_pbr_mat("DicePipMat", (0.10, 0.08, 0.07), roughness=0.80)

    dice_specs = [
        ((-0.026, -0.010, 0.017), (0, 0, 18.0), [(-0.008, -0.008), (0.0, 0.0), (0.008, 0.008)]),
        ((0.026, 0.012, 0.017), (0, 0, -28.0), [(-0.008, -0.008), (0.008, -0.008), (-0.008, 0.008), (0.008, 0.008)]),
    ]
    for di, (d_pos, d_rot, pips) in enumerate(dice_specs):
        # Rounded-bevel bone cube via heavy bevel + smooth shading
        die = cb.make_box(f"BoneDie_{di}", (0.034, 0.034, 0.034), center_xyz=d_pos, mat=bone_mat, bevel_w=0.0045, rot_deg=d_rot)
        cb.set_obj_smooth(die, True)
        ang_z = math.radians(d_rot[2])
        ca, sa = math.cos(ang_z), math.sin(ang_z)
        for pi, (px, py) in enumerate(pips):
            wx = d_pos[0] + px * ca - py * sa
            wy = d_pos[1] + px * sa + py * ca
            cb.make_cylinder(f"DiePipTop_{di}_{pi}", 0.0038, 0.0038, 0.0022, segments=10, center_xyz=(wx, wy, d_pos[2] + 0.0168), mat=pip_mat)
        # Front face (-Y local) 2 pips
        for pi, (px, pz) in enumerate(((-0.007, -0.007), (0.007, 0.007))):
            ly = -0.0168
            wx = d_pos[0] + px * ca - ly * sa
            wy = d_pos[1] + px * sa + ly * ca
            cb.make_cylinder(f"DiePipFront_{di}_{pi}", 0.0035, 0.0035, 0.0022, segments=10, center_xyz=(wx, wy, d_pos[2] + pz), mat=pip_mat, rot_deg=(90.0, 0.0, d_rot[2]))

    cb.export_glb("bone_dice.glb")


if __name__ == "__main__":
    build_battle_table()
    build_phial_ignis()
    build_sword_oath()
    build_deck_shoe()
    build_supporting_props()
    print("[GEN_TABLE_AND_PROPS_DONE]")
