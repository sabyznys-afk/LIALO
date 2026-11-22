"""Generates scoring_astrolabe_stage.glb (4.0s) and scoring_tokens_pack.glb using Blender 5.3."""

import math
import bmesh
import bpy
from mathutils import Matrix, Vector
import blender_common as bc


def build_scoring_astrolabe_stage() -> None:
    bc.reset_scene(fps=24, frame_start=1, frame_end=96)

    mat_accent = bc.make_pbr_mat(
        "Mat_AccentGlow",
        base_color=(0.35, 0.88, 1.0, 1.0),
        metallic=0.15,
        roughness=0.22,
        emission_color=(0.35, 0.88, 1.0, 1.0),
        emission_strength=3.2,
    )
    mat_brass = bc.make_pbr_mat(
        "Mat_Brass",
        base_color=(0.86, 0.64, 0.22, 1.0),
        metallic=0.88,
        roughness=0.26,
    )
    mat_obsidian = bc.make_pbr_mat(
        "Mat_Obsidian",
        base_color=(0.07, 0.06, 0.09, 1.0),
        metallic=0.35,
        roughness=0.38,
    )
    mat_rune_gold = bc.make_pbr_mat(
        "Mat_RuneGold",
        base_color=(1.0, 0.84, 0.30, 1.0),
        metallic=0.72,
        roughness=0.25,
        emission_color=(1.0, 0.72, 0.20, 1.0),
        emission_strength=2.2,
    )

    root = bc.create_empty("AstrolabeStageRoot")

    # 1. Floor Seal Ring (obsidian base + inlaid glowing ring)
    floor_seal = bc.create_ornate_ring(
        "FloorSealRing",
        r_outer=0.52,
        r_inner=0.45,
        height=0.016,
        notches=16,
        notch_depth=0.024,
        segments=48,
        mat=mat_obsidian,
        parent=root,
    )
    floor_seal.location = Vector((0.0, 0.0, 0.010))

    floor_glow = bc.create_ornate_ring(
        "FloorSealGlow",
        r_outer=0.46,
        r_inner=0.43,
        height=0.012,
        notches=8,
        notch_depth=0.012,
        segments=48,
        mat=mat_accent,
        parent=floor_seal,
    )
    floor_glow.location = Vector((0.0, 0.0, 0.004))

    # 2. Outer Notched Brass Astrolabe Ring (12 raised rune lugs)
    outer_ring = bc.create_ornate_ring(
        "OuterAstrolabeRing",
        r_outer=0.41,
        r_inner=0.355,
        height=0.026,
        notches=12,
        notch_depth=0.022,
        segments=48,
        mat=mat_brass,
        parent=root,
    )
    for ni in range(12):
        ang = (float(ni) / 12.0) * math.tau
        lug = bc.create_faceted_crystal(
            f"AstrolabeLug_{ni}",
            radius=0.014,
            height=0.036,
            sides=4,
            mat=mat_rune_gold if ni % 3 == 0 else mat_accent,
            parent=outer_ring,
        )
        lug.location = Vector((math.cos(ang) * 0.382, math.sin(ang) * 0.382, 0.008))

    # 3. Counter-Rotating Inner Celestial Armillary Ring + 4 Crystal Nodes
    inner_ring = bc.create_ornate_ring(
        "InnerArmillaryRing",
        r_outer=0.295,
        r_inner=0.255,
        height=0.022,
        notches=4,
        notch_depth=0.018,
        segments=36,
        mat=mat_brass,
        parent=root,
    )
    for ci in range(4):
        ang = (float(ci) / 4.0) * math.tau
        node = bc.create_faceted_crystal(
            f"ArmillaryNode_{ci}",
            radius=0.022,
            height=0.075,
            sides=6,
            mat=mat_accent,
            parent=inner_ring,
        )
        node.location = Vector((math.cos(ang) * 0.275, math.sin(ang) * 0.275, -0.02))

    # 4. Four Hinged Gilded Multiplier Vanes blossoming outward
    vanes = []
    for vi in range(4):
        ang = (float(vi) / 4.0) * math.tau + math.pi * 0.25
        pivot = bc.create_empty(f"MultVanePivot_{vi}", loc=(math.cos(ang) * 0.33, math.sin(ang) * 0.33, 0.06), rot_deg=(0.0, 0.0, math.degrees(ang)), parent=root)
        bm = bmesh.new()
        verts = [
            bm.verts.new((0.0, -0.024, 0.0)),
            bm.verts.new((0.0, 0.024, 0.0)),
            bm.verts.new((0.18, 0.010, 0.06)),
            bm.verts.new((0.18, -0.010, 0.06)),
            bm.verts.new((0.24, 0.0, 0.14)),
            bm.verts.new((0.02, 0.0, 0.028)),
        ]
        bm.faces.new((verts[0], verts[1], verts[2], verts[3]))
        bm.faces.new((verts[3], verts[2], verts[4]))
        bm.faces.new((verts[0], verts[3], verts[4], verts[5]))
        bm.faces.new((verts[1], verts[5], verts[4], verts[2]))
        bm.faces.new((verts[0], verts[5], verts[1]))
        bc.finalize_bmesh(f"MultVane_{vi}", bm, mat=mat_rune_gold, smooth=False, parent=pivot)
        vanes.append((pivot, math.degrees(ang)))

    # 5. Central Levitating Faceted Focus Prism inside brass claws
    prism_pivot = bc.create_empty("FocusPrismPivot", loc=(0.0, 0.0, 0.14), parent=root)
    bc.create_faceted_crystal(
        "FocusPrism",
        radius=0.072,
        height=0.22,
        sides=6,
        tip_ratio=0.38,
        bottom_taper=0.35,
        mat=mat_accent,
        parent=prism_pivot,
    )
    claw_ring = bc.create_ornate_ring(
        "FocusClawRing",
        r_outer=0.11,
        r_inner=0.088,
        height=0.014,
        notches=3,
        notch_depth=0.014,
        segments=24,
        mat=mat_brass,
        parent=prism_pivot,
    )
    claw_ring.location = Vector((0.0, 0.0, 0.09))

    # Animate 4.0s (96 frames @ 24fps): emerge -> hypnotic spin/float -> climax surge -> retract
    bc.kf_trs(floor_seal, 1, loc=(0, 0, 0.01), scale=0.02)
    bc.kf_trs(floor_seal, 12, loc=(0, 0, 0.01), scale=1.06)
    bc.kf_trs(floor_seal, 18, loc=(0, 0, 0.01), scale=1.0)
    bc.kf_trs(floor_seal, 78, loc=(0, 0, 0.01), rot_deg=(0, 0, 120), scale=1.04)
    bc.kf_trs(floor_seal, 84, loc=(0, 0, 0.01), rot_deg=(0, 0, 145), scale=1.18)
    bc.kf_trs(floor_seal, 96, loc=(0, 0, 0.01), rot_deg=(0, 0, 180), scale=0.01)

    bc.kf_trs(outer_ring, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(outer_ring, 14, loc=(0, 0, 0.045), rot_deg=(0, 0, 45), scale=1.05)
    bc.kf_trs(outer_ring, 20, loc=(0, 0, 0.042), rot_deg=(0, 0, 65), scale=1.0)
    bc.kf_trs(outer_ring, 76, loc=(0, 0, 0.055), rot_deg=(0, 0, 310), scale=1.02)
    bc.kf_trs(outer_ring, 84, loc=(0, 0, 0.085), rot_deg=(0, 0, 390), scale=1.16)
    bc.kf_trs(outer_ring, 96, loc=(0, 0, 0.02), rot_deg=(0, 0, 460), scale=0.01)

    bc.kf_trs(inner_ring, 1, loc=(0, 0, 0.04), rot_deg=(12, 0, 0), scale=0.02)
    bc.kf_trs(inner_ring, 16, loc=(0, 0, 0.11), rot_deg=(18, -14, -85), scale=1.04)
    bc.kf_trs(inner_ring, 48, loc=(0, 0, 0.13), rot_deg=(-15, 18, -260), scale=1.02)
    bc.kf_trs(inner_ring, 76, loc=(0, 0, 0.12), rot_deg=(12, -10, -450), scale=1.06)
    bc.kf_trs(inner_ring, 84, loc=(0, 0, 0.18), rot_deg=(0, 0, -540), scale=1.20)
    bc.kf_trs(inner_ring, 96, loc=(0, 0, 0.03), rot_deg=(0, 0, -640), scale=0.01)

    for pivot, base_z in vanes:
        bc.kf_trs(pivot, 1, rot_deg=(0, 75, base_z), scale=0.02)
        bc.kf_trs(pivot, 16, rot_deg=(0, 12, base_z), scale=1.0)
        bc.kf_trs(pivot, 48, rot_deg=(0, -8, base_z), scale=1.05)
        bc.kf_trs(pivot, 76, rot_deg=(0, -18, base_z), scale=1.10)
        bc.kf_trs(pivot, 84, rot_deg=(0, -35, base_z), scale=1.22)
        bc.kf_trs(pivot, 96, rot_deg=(0, 70, base_z), scale=0.01)

    bc.kf_trs(prism_pivot, 1, loc=(0, 0, 0.04), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(prism_pivot, 15, loc=(0, 0, 0.16), rot_deg=(0, 0, 90), scale=1.05)
    bc.kf_trs(prism_pivot, 46, loc=(0, 0, 0.21), rot_deg=(0, 0, 290), scale=1.08)
    bc.kf_trs(prism_pivot, 76, loc=(0, 0, 0.18), rot_deg=(0, 0, 500), scale=1.12)
    bc.kf_trs(prism_pivot, 84, loc=(0, 0, 0.28), rot_deg=(0, 0, 620), scale=1.35)
    bc.kf_trs(prism_pivot, 96, loc=(0, 0, 0.06), rot_deg=(0, 0, 760), scale=0.01)

    for obj in [floor_seal, outer_ring, inner_ring, prism_pivot] + [v[0] for v in vanes]:
        bc.set_interp(obj, "BEZIER")

    bc.export_glb(bc.OUT_VFX_DIR / "scoring_astrolabe_stage.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_astrolabe.png", frame=46, cam_loc=(1.1, -1.1, 0.9), cam_target=(0.0, 0.0, 0.16))


def build_scoring_tokens_pack() -> None:
    bc.reset_scene(fps=24, frame_start=1, frame_end=2)

    mat_accent = bc.make_pbr_mat(
        "Mat_TokenAccent",
        base_color=(0.40, 0.90, 1.0, 1.0),
        metallic=0.25,
        roughness=0.20,
        emission_color=(0.40, 0.90, 1.0, 1.0),
        emission_strength=3.0,
    )
    mat_gold = bc.make_pbr_mat(
        "Mat_TokenGold",
        base_color=(0.98, 0.78, 0.24, 1.0),
        metallic=0.90,
        roughness=0.22,
        emission_color=(0.85, 0.56, 0.12, 1.0),
        emission_strength=0.65,
    )
    mat_ruby = bc.make_pbr_mat(
        "Mat_TokenRuby",
        base_color=(0.96, 0.22, 0.34, 1.0),
        metallic=0.10,
        roughness=0.16,
        emission_color=(0.96, 0.20, 0.30, 1.0),
        emission_strength=2.4,
    )

    # 1. Token_ChipCoin: beveled thick medieval medallion + embossed 8-point crest
    t_coin = bc.create_empty("Token_ChipCoin", loc=(-0.4, 0.0, 0.05))
    bc.create_lathe_mesh(
        "ChipCoin_Disc",
        [(0.042, -0.008), (0.046, -0.004), (0.046, 0.004), (0.042, 0.008)],
        segments=24,
        mat=mat_gold,
        smooth=False,
        parent=t_coin,
    )
    bc.create_ornate_ring(
        "ChipCoin_Crest",
        r_outer=0.032,
        r_inner=0.012,
        height=0.020,
        notches=8,
        notch_depth=0.008,
        segments=24,
        mat=mat_accent,
        parent=t_coin,
    )

    # 2. Token_MultSigil: 3D faceted heraldic starburst + ringed brass rim
    t_mult = bc.create_empty("Token_MultSigil", loc=(-0.2, 0.0, 0.06))
    bc.create_ornate_ring(
        "MultSigil_Rim",
        r_outer=0.052,
        r_inner=0.038,
        height=0.014,
        notches=6,
        notch_depth=0.014,
        segments=24,
        mat=mat_gold,
        parent=t_mult,
    )
    for si in range(2):
        sp = bc.create_faceted_crystal(
            f"MultSigil_Star_{si}",
            radius=0.022,
            height=0.088,
            sides=4,
            tip_ratio=0.48,
            bottom_taper=0.25,
            mat=mat_accent,
            parent=t_mult,
        )
        sp.location = Vector((0.0, 0.0, -0.044)) if si == 0 else Vector((-0.044, 0.0, 0.0))
        if si == 1:
            sp.rotation_euler = (0.0, math.radians(90.0), 0.0)

    # 3. Token_XMultPrism: double-pyramid diamond inside twin brass gimbal rings
    t_xmult = bc.create_empty("Token_XMultPrism", loc=(0.0, 0.0, 0.08))
    x_core = bc.create_faceted_crystal(
        "XMult_Core",
        radius=0.034,
        height=0.11,
        sides=4,
        tip_ratio=0.50,
        bottom_taper=0.05,
        mat=mat_accent,
        parent=t_xmult,
    )
    x_core.location = Vector((0.0, 0.0, -0.055))
    g1 = bc.create_ornate_ring("XMult_GimbalA", 0.058, 0.048, 0.009, notches=4, notch_depth=0.006, segments=24, mat=mat_gold, parent=t_xmult)
    g1.rotation_euler = (math.radians(35.0), 0.0, 0.0)
    g2 = bc.create_ornate_ring("XMult_GimbalB", 0.052, 0.043, 0.009, notches=4, notch_depth=0.006, segments=24, mat=mat_gold, parent=t_xmult)
    g2.rotation_euler = (0.0, math.radians(55.0), math.radians(30.0))

    # 4. Token_RelicBeamOrb: winged filigree mana orb
    t_orb = bc.create_empty("Token_RelicBeamOrb", loc=(0.2, 0.0, 0.06))
    bc.create_lathe_mesh(
        "RelicOrb_Sphere",
        [(0.001, -0.032), (0.026, -0.020), (0.034, 0.0), (0.026, 0.020), (0.001, 0.032)],
        segments=18,
        mat=mat_accent,
        smooth=True,
        cap_bottom=False,
        cap_top=False,
        parent=t_orb,
    )
    r_halo = bc.create_ornate_ring("RelicOrb_Band", 0.046, 0.038, 0.010, notches=4, notch_depth=0.010, segments=20, mat=mat_gold, parent=t_orb)
    r_halo.rotation_euler = (math.radians(72.0), 0.0, 0.0)

    # 5. Token_ScoreCrown: miniature jeweled medieval heraldic crown
    t_crown = bc.create_empty("Token_ScoreCrown", loc=(0.4, 0.0, 0.05))
    bc.create_ornate_ring("ScoreCrown_Band", 0.052, 0.042, 0.024, notches=8, notch_depth=0.006, segments=24, mat=mat_gold, parent=t_crown)
    for pi in range(6):
        ang = (float(pi) / 6.0) * math.tau
        pt = bc.create_faceted_crystal(f"ScoreCrown_Pt_{pi}", radius=0.012, height=0.048, sides=4, mat=mat_gold, parent=t_crown)
        pt.location = Vector((math.cos(ang) * 0.046, math.sin(ang) * 0.046, 0.010))
        gem = bc.create_faceted_crystal(f"ScoreCrown_Gem_{pi}", radius=0.007, height=0.018, sides=4, mat=mat_ruby if pi % 2 == 0 else mat_accent, parent=t_crown)
        gem.location = Vector((math.cos(ang) * 0.048, math.sin(ang) * 0.048, 0.002))

    bc.export_glb(bc.OUT_VFX_DIR / "scoring_tokens_pack.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_tokens.png", frame=1, cam_loc=(0.0, -0.95, 0.45), cam_target=(0.0, 0.0, 0.06))


def run() -> None:
    build_scoring_astrolabe_stage()
    build_scoring_tokens_pack()
    print("GEN_SCORING_VFX_OK")


if __name__ == "__main__":
    run()
