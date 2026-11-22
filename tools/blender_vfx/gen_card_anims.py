"""Generates 4 animated 3.25s-3.42s Blender 5.3 card-play VFX GLBs for LIALO."""

import math
import bmesh
import bpy
from mathutils import Vector
import blender_common as bc


def _base_card_mats(accent=(0.95, 0.16, 0.16, 1.0), em_str=2.2):
    mat_accent = bc.make_pbr_mat(
        "Mat_CardAccent",
        base_color=accent,
        metallic=0.15,
        roughness=0.22,
        emission_color=accent,
        emission_strength=em_str,
    )
    mat_brass = bc.make_pbr_mat("Mat_CardBrass", base_color=(0.88, 0.68, 0.24, 1.0), metallic=0.88, roughness=0.24)
    mat_steel = bc.make_pbr_mat("Mat_CardSteel", base_color=(0.76, 0.80, 0.86, 1.0), metallic=0.92, roughness=0.20)
    mat_iron = bc.make_pbr_mat("Mat_CardIron", base_color=(0.16, 0.16, 0.20, 1.0), metallic=0.76, roughness=0.42)
    mat_dark = bc.make_pbr_mat("Mat_CardObsidian", base_color=(0.06, 0.05, 0.08, 1.0), metallic=0.25, roughness=0.45)
    mat_gold = bc.make_pbr_mat(
        "Mat_CardGoldGlow",
        base_color=(1.0, 0.84, 0.28, 1.0),
        metallic=0.85,
        roughness=0.20,
        emission_color=(1.0, 0.72, 0.18, 1.0),
        emission_strength=1.4,
    )
    return mat_accent, mat_brass, mat_steel, mat_iron, mat_dark, mat_gold


def build_seven_barrage() -> None:
    """frames 1..78 @ 24fps = 3.25s: Etched sigil -> crossed curved cursed daggers + 4 chains + X-slash -> lunge forward (+Y) -> impact ring."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=78)
    mat_accent, mat_brass, mat_steel, mat_iron, mat_dark, _ = _base_card_mats((0.98, 0.26, 0.22, 1.0), 3.6)

    root = bc.create_empty("SevenBarrageRoot")

    # Dark etched floor sigil + glowing inner rune ring
    sigil = bc.create_ornate_ring("Seven_FloorSigil", 0.50, 0.42, 0.014, notches=7, notch_depth=0.032, segments=42, mat=mat_dark, parent=root)
    sigil_glow = bc.create_ornate_ring("Seven_FloorGlow", 0.43, 0.39, 0.010, notches=7, notch_depth=0.015, segments=42, mat=mat_accent, parent=sigil)
    sigil_glow.location = Vector((0, 0, 0.004))

    # Twin sculpted curved daggers
    dag_l = bc.create_medieval_sword("Dagger_L", blade_len=0.52, blade_w=0.068, guard_w=0.18, curved=True, mat_blade=mat_steel, mat_guard=mat_brass, mat_grip=mat_iron, mat_rune=mat_accent, parent=root)
    dag_r = bc.create_medieval_sword("Dagger_R", blade_len=0.52, blade_w=0.068, guard_w=0.18, curved=True, mat_blade=mat_steel, mat_guard=mat_brass, mat_grip=mat_iron, mat_rune=mat_accent, parent=root)

    # 4 coiled iron doom chains rising around center
    chains = []
    for ci in range(4):
        ang = (float(ci) / 4.0) * math.tau + math.pi * 0.25
        ch_piv = bc.create_empty(f"SevenChainPivot_{ci}", loc=(math.cos(ang) * 0.38, math.sin(ang) * 0.38, 0.0), parent=root)
        ch = bc.create_chain_strand(f"SevenChain_{ci}", link_count=7, link_len=0.075, link_w=0.038, wire_r=0.008, mat=mat_iron, parent=ch_piv)
        ch.rotation_euler = (math.radians(18.0), 0.0, ang)
        chains.append((ch_piv, ang))

    # Twin X-slash ribbons
    slash_a = bc.create_twisted_ribbon("SlashRibbon_A", 0.22, 0.44, 0.32, turns=0.65, width=0.075, thickness=0.010, steps=28, phase_deg=0.0, mat=mat_accent, parent=root)
    slash_b = bc.create_twisted_ribbon("SlashRibbon_B", 0.22, 0.44, 0.32, turns=-0.65, width=0.075, thickness=0.010, steps=28, phase_deg=180.0, mat=mat_accent, parent=root)

    # Impact shatter ring at Rival end (+Y = 1.05m)
    impact_ring = bc.create_ornate_ring("Seven_ImpactRing", 0.48, 0.41, 0.022, notches=14, notch_depth=0.035, segments=42, mat=mat_accent, parent=root)

    # Keyframes: 1..14 emerge, 14..38 cross & coil, 38..50 tension, 50..64 lunge forward, 64..78 impact burst & fade
    bc.kf_trs(sigil, 1, loc=(0, 0, 0.01), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(sigil, 14, loc=(0, 0, 0.01), rot_deg=(0, 0, 40), scale=1.05)
    bc.kf_trs(sigil, 48, loc=(0, 0, 0.01), rot_deg=(0, 0, 140), scale=1.0)
    bc.kf_trs(sigil, 64, loc=(0, 0, 0.01), rot_deg=(0, 0, 210), scale=1.15)
    bc.kf_trs(sigil, 78, loc=(0, 0, 0.01), rot_deg=(0, 0, 260), scale=0.01)

    for sign, dag in ((-1.0, dag_l), (1.0, dag_r)):
        bc.kf_trs(dag, 1, loc=(sign * 0.42, 0.0, 0.04), rot_deg=(12, sign * 25, 0), scale=0.02)
        bc.kf_trs(dag, 16, loc=(sign * 0.36, -0.05, 0.44), rot_deg=(24, -sign * 42, sign * 18), scale=1.05)
        bc.kf_trs(dag, 34, loc=(sign * 0.08, 0.06, 0.42), rot_deg=(-35, sign * 38, sign * 12), scale=1.12)
        bc.kf_trs(dag, 46, loc=(sign * 0.22, -0.18, 0.56), rot_deg=(-58, -sign * 16, 0), scale=1.15)
        bc.kf_trs(dag, 58, loc=(sign * 0.10, 1.05, 0.36), rot_deg=(-88, sign * 12, 0), scale=1.25)
        bc.kf_trs(dag, 68, loc=(sign * 0.12, 1.10, 0.32), rot_deg=(-94, sign * 8, 0), scale=1.18)
        bc.kf_trs(dag, 78, loc=(sign * 0.14, 1.15, 0.20), rot_deg=(-100, sign * 12, 0), scale=0.01)

    for ch_piv, ang in chains:
        bc.kf_trs(ch_piv, 1, loc=(math.cos(ang) * 0.42, math.sin(ang) * 0.42, -0.15), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(ch_piv, 22, loc=(math.cos(ang) * 0.30, math.sin(ang) * 0.30, 0.02), rot_deg=(0, 0, 45), scale=1.0)
        bc.kf_trs(ch_piv, 48, loc=(math.cos(ang) * 0.20, math.sin(ang) * 0.20, 0.10), rot_deg=(0, 0, 110), scale=1.08)
        bc.kf_trs(ch_piv, 60, loc=(math.cos(ang) * 0.45, 0.72 + math.sin(ang) * 0.28, 0.18), rot_deg=(-45, 0, 160), scale=0.95)
        bc.kf_trs(ch_piv, 78, loc=(math.cos(ang) * 0.55, 0.95 + math.sin(ang) * 0.35, 0.05), rot_deg=(-65, 0, 210), scale=0.01)

    for s_obj, yaw in ((slash_a, 28.0), (slash_b, -28.0)):
        bc.kf_trs(s_obj, 1, loc=(0, 0, 0.12), rot_deg=(0, yaw, 0), scale=0.01)
        bc.kf_trs(s_obj, 28, loc=(0, 0.05, 0.22), rot_deg=(25, yaw, 0), scale=0.01)
        bc.kf_trs(s_obj, 36, loc=(0, 0.12, 0.26), rot_deg=(45, yaw, 90), scale=1.18)
        bc.kf_trs(s_obj, 54, loc=(0, 0.65, 0.30), rot_deg=(65, yaw, 220), scale=1.28)
        bc.kf_trs(s_obj, 78, loc=(0, 1.05, 0.24), rot_deg=(75, yaw, 310), scale=0.01)

    bc.kf_trs(impact_ring, 1, loc=(0, 1.05, 0.08), scale=0.01)
    bc.kf_trs(impact_ring, 54, loc=(0, 1.05, 0.08), scale=0.01)
    bc.kf_trs(impact_ring, 62, loc=(0, 1.05, 0.18), rot_deg=(0, 0, 70), scale=1.35)
    bc.kf_trs(impact_ring, 78, loc=(0, 1.05, 0.12), rot_deg=(0, 0, 140), scale=0.01)

    for obj in [sigil, dag_l, dag_r, slash_a, slash_b, impact_ring] + [c[0] for c in chains]:
        bc.set_interp(obj, "BEZIER")

    bc.export_glb(bc.OUT_VFX_DIR / "card_anim_seven_barrage.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_seven.png", frame=36, cam_loc=(1.4, -1.5, 1.15), cam_target=(0.0, 0.25, 0.32))


def build_ace_chronos() -> None:
    """frames 1..82 @ 24fps = 3.42s: Brass clock dial + cogwheel + whipping hands + 8 crystal spires + strike slam."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=82)
    mat_accent, mat_brass, mat_steel, _, mat_dark, mat_gold = _base_card_mats((0.42, 0.88, 1.0, 1.0), 3.6)

    root = bc.create_empty("AceChronosRoot")
    dial_group = bc.create_empty("ClockDialGroup", loc=(0.0, 0.0, 0.05), parent=root)

    # Brass outer dial ring + dark clock plate + 12 raised Roman hour crystals
    bc.create_ornate_ring("Clock_OuterRim", 0.54, 0.45, 0.024, notches=12, notch_depth=0.022, segments=48, mat=mat_brass, parent=dial_group)
    bc.create_lathe_mesh("Clock_Plate", [(0.45, -0.008), (0.45, 0.006)], segments=36, mat=mat_dark, smooth=False, parent=dial_group)
    for hi in range(12):
        ang = (float(hi) / 12.0) * math.tau
        mk = bc.create_faceted_crystal(f"HourMarker_{hi}", radius=0.014, height=0.042, sides=4, mat=mat_gold if hi % 3 == 0 else mat_accent, parent=dial_group)
        mk.location = Vector((math.cos(ang) * 0.41, math.sin(ang) * 0.41, 0.005))

    # Inner meshing cogwheel
    cog = bc.create_ornate_ring("Clock_InnerCog", 0.26, 0.16, 0.018, notches=10, notch_depth=0.032, segments=40, mat=mat_brass, parent=dial_group)
    cog.location = Vector((0.0, 0.0, 0.022))

    # Filigree minute & hour hands
    minute_piv = bc.create_empty("MinuteHandPivot", loc=(0.0, 0.0, 0.05), parent=dial_group)
    min_blade = bc.create_faceted_crystal("MinuteHand", radius=0.020, height=0.39, sides=4, tip_ratio=0.25, bottom_taper=0.75, mat=mat_accent, parent=minute_piv)
    min_blade.rotation_euler = (-math.pi * 0.5, 0.0, 0.0)

    hour_piv = bc.create_empty("HourHandPivot", loc=(0.0, 0.0, 0.065), parent=dial_group)
    hr_blade = bc.create_faceted_crystal("HourHand", radius=0.024, height=0.25, sides=4, tip_ratio=0.30, bottom_taper=0.75, mat=mat_gold, parent=hour_piv)
    hr_blade.rotation_euler = (-math.pi * 0.5, 0.0, 0.0)

    # 8 perimeter crystalline frost/lightning spires erupting upward & outward
    spires = []
    for si in range(8):
        ang = (float(si) / 8.0) * math.tau
        sp_piv = bc.create_empty(f"SpirePivot_{si}", loc=(math.cos(ang) * 0.52, math.sin(ang) * 0.52, 0.0), rot_deg=(0.0, 0.0, math.degrees(ang)), parent=root)
        sp = bc.create_faceted_crystal(f"ClockSpire_{si}", radius=0.040, height=0.40, sides=6, tip_ratio=0.45, bottom_taper=0.72, mat=mat_accent if si % 2 == 0 else mat_gold, parent=sp_piv)
        sp.rotation_euler = (0.0, math.radians(18.0), 0.0)
        spires.append((sp_piv, ang))

    # Forward stun lance rocketing toward Rival on clock strike
    lance = bc.create_faceted_crystal("TimeStrikeLance", radius=0.055, height=0.62, sides=6, tip_ratio=0.35, bottom_taper=0.35, mat=mat_accent, parent=root)

    # Animation (82 frames = 3.42s)
    bc.kf_trs(dial_group, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(dial_group, 16, loc=(0, 0, 0.09), rot_deg=(0, 0, 20), scale=1.08)
    bc.kf_trs(dial_group, 46, loc=(0, 0, 0.22), rot_deg=(-22, 0, 45), scale=1.04)
    bc.kf_trs(dial_group, 54, loc=(0, 0.06, 0.05), rot_deg=(0, 0, 60), scale=1.18)
    bc.kf_trs(dial_group, 72, loc=(0, 0.06, 0.05), rot_deg=(0, 0, 75), scale=1.10)
    bc.kf_trs(dial_group, 82, loc=(0, 0.06, 0.02), rot_deg=(0, 0, 90), scale=0.01)

    bc.kf_trs(cog, 1, rot_deg=(0, 0, 0))
    bc.kf_trs(cog, 50, rot_deg=(0, 0, -540))
    bc.kf_trs(cog, 82, rot_deg=(0, 0, -600))

    bc.kf_trs(minute_piv, 1, rot_deg=(0, 0, 0))
    bc.kf_trs(minute_piv, 50, rot_deg=(0, 0, -1080))
    bc.kf_trs(minute_piv, 56, rot_deg=(0, 0, -1105))
    bc.kf_trs(minute_piv, 82, rot_deg=(0, 0, -1120))

    bc.kf_trs(hour_piv, 1, rot_deg=(0, 0, 0))
    bc.kf_trs(hour_piv, 50, rot_deg=(0, 0, 270))
    bc.kf_trs(hour_piv, 82, rot_deg=(0, 0, 300))

    for idx, (sp_piv, ang) in enumerate(spires):
        bc.kf_trs(sp_piv, 1, loc=(math.cos(ang) * 0.52, math.sin(ang) * 0.52, -0.05), scale=0.01)
        bc.kf_trs(sp_piv, 24, loc=(math.cos(ang) * 0.52, math.sin(ang) * 0.52, 0.0), scale=0.01)
        bc.kf_trs(sp_piv, 36 + (idx % 3) * 3, loc=(math.cos(ang) * 0.52, math.sin(ang) * 0.52, 0.02), scale=1.14)
        bc.kf_trs(sp_piv, 55, loc=(math.cos(ang) * 0.58, math.sin(ang) * 0.58, 0.05), scale=1.22)
        bc.kf_trs(sp_piv, 82, loc=(math.cos(ang) * 0.65, math.sin(ang) * 0.65, -0.08), scale=0.01)

    bc.kf_trs(lance, 1, loc=(0, 0.0, 0.30), rot_deg=(-90, 0, 0), scale=0.01)
    bc.kf_trs(lance, 48, loc=(0, 0.0, 0.35), rot_deg=(-90, 0, 0), scale=0.01)
    bc.kf_trs(lance, 55, loc=(0, 0.22, 0.32), rot_deg=(-90, 180, 0), scale=1.20)
    bc.kf_trs(lance, 68, loc=(0, 1.08, 0.22), rot_deg=(-90, 540, 0), scale=1.30)
    bc.kf_trs(lance, 82, loc=(0, 1.25, 0.14), rot_deg=(-90, 720, 0), scale=0.01)

    for obj in [dial_group, cog, minute_piv, hour_piv, lance] + [s[0] for s in spires]:
        bc.set_interp(obj, "BEZIER")

    bc.export_glb(bc.OUT_VFX_DIR / "card_anim_ace_chronos.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_ace.png", frame=42, cam_loc=(1.4, -1.5, 1.25), cam_target=(0.0, 0.0, 0.24))


def build_royal_crown() -> None:
    """frames 1..80 @ 24fps = 3.33s: Jeweled Crown + 4-petal compass rose + shield crest + 10 gold coins burst."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=80)
    mat_accent, mat_brass, mat_steel, _, mat_dark, mat_gold = _base_card_mats((1.0, 0.78, 0.24, 1.0), 3.2)

    root = bc.create_empty("RoyalCrownRoot")

    # 4-petal compass rose floor base
    compass = bc.create_empty("CompassRose", loc=(0.0, 0.0, 0.018), parent=root)
    bc.create_ornate_ring("Compass_Ring", 0.50, 0.43, 0.016, notches=8, notch_depth=0.025, segments=40, mat=mat_brass, parent=compass)
    for pi in range(4):
        ang = (float(pi) / 4.0) * math.tau
        petal = bc.create_faceted_crystal(f"CompassPetal_{pi}", radius=0.055, height=0.38, sides=4, tip_ratio=0.65, bottom_taper=0.35, mat=mat_accent if pi % 2 == 0 else mat_gold, parent=compass)
        petal.location = Vector((math.cos(ang) * 0.16, math.sin(ang) * 0.16, 0.015))
        petal.rotation_euler = (-math.pi * 0.5, 0.0, ang - math.pi * 0.5)

    # Sculpted Jeweled Sovereign Crown
    crown_piv = bc.create_empty("SovereignCrownPivot", loc=(0.0, 0.0, 0.28), parent=root)
    bc.create_ornate_ring("Crown_Band", 0.22, 0.18, 0.075, notches=8, notch_depth=0.014, segments=32, mat=mat_gold, parent=crown_piv)
    for si in range(8):
        ang = (float(si) / 8.0) * math.tau
        spire = bc.create_faceted_crystal(f"CrownSpire_{si}", radius=0.032, height=0.145, sides=4, tip_ratio=0.55, bottom_taper=0.70, mat=mat_gold, parent=crown_piv)
        spire.location = Vector((math.cos(ang) * 0.20, math.sin(ang) * 0.20, 0.03))
        gem = bc.create_faceted_crystal(f"CrownGem_{si}", radius=0.018, height=0.042, sides=6, mat=mat_accent, parent=crown_piv)
        gem.location = Vector((math.cos(ang) * 0.225, math.sin(ang) * 0.225, -0.01))

    # Rising light column halo rings
    halo_low = bc.create_ornate_ring("RoyalHalo_Low", 0.34, 0.31, 0.014, notches=0, notch_depth=0.0, segments=36, mat=mat_accent, parent=root)
    halo_high = bc.create_ornate_ring("RoyalHalo_High", 0.26, 0.23, 0.014, notches=0, notch_depth=0.0, segments=36, mat=mat_accent, parent=root)

    # 10 sculpted 3D florin gold coins fanning out on royal decree slam
    coins = []
    for ci in range(10):
        ang = (float(ci) / 10.0) * math.tau
        coin = bc.create_lathe_mesh(f"RoyalCoin_{ci}", [(0.045, -0.008), (0.048, 0.0), (0.045, 0.008)], segments=18, mat=mat_gold, smooth=False, parent=root)
        coins.append((coin, ang))

    # Timeline (80 frames = 3.33s)
    bc.kf_trs(compass, 1, loc=(0, 0, 0.015), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(compass, 18, loc=(0, 0, 0.02), rot_deg=(0, 0, 180), scale=1.08)
    bc.kf_trs(compass, 42, loc=(0, 0, 0.02), rot_deg=(0, 0, 420), scale=1.0)
    bc.kf_trs(compass, 50, loc=(0, 0, 0.02), rot_deg=(0, 0, 450), scale=1.22)
    bc.kf_trs(compass, 80, loc=(0, 0, 0.02), rot_deg=(0, 0, 480), scale=0.01)

    bc.kf_trs(crown_piv, 1, loc=(0, 0, 0.14), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(crown_piv, 20, loc=(0, 0, 0.42), rot_deg=(8, 0, 140), scale=1.12)
    bc.kf_trs(crown_piv, 40, loc=(0, 0, 0.56), rot_deg=(-10, 0, 340), scale=1.18)
    bc.kf_trs(crown_piv, 49, loc=(0, 0, 0.09), rot_deg=(0, 0, 450), scale=1.26)
    bc.kf_trs(crown_piv, 68, loc=(0, 0, 0.11), rot_deg=(0, 0, 510), scale=1.15)
    bc.kf_trs(crown_piv, 80, loc=(0, 0, 0.04), rot_deg=(0, 0, 560), scale=0.01)

    for hi, h_obj in ((0, halo_low), (1, halo_high)):
        z_peak = 0.48 + hi * 0.24
        bc.kf_trs(h_obj, 1, loc=(0, 0, 0.02), scale=0.02)
        bc.kf_trs(h_obj, 22, loc=(0, 0, z_peak * 0.5), scale=1.05)
        bc.kf_trs(h_obj, 49, loc=(0, 0, z_peak), scale=1.18)
        bc.kf_trs(h_obj, 62, loc=(0, 0, 0.06), scale=1.45)
        bc.kf_trs(h_obj, 80, loc=(0, 0, 0.02), scale=0.01)

    for ci, (coin, ang) in enumerate(coins):
        r_mid = 0.34
        r_far = 0.68
        bc.kf_trs(coin, 1, loc=(0, 0, 0.12), scale=0.01)
        bc.kf_trs(coin, 47, loc=(math.cos(ang) * 0.12, math.sin(ang) * 0.12, 0.15), rot_deg=(45, 0, 0), scale=0.01)
        bc.kf_trs(coin, 58, loc=(math.cos(ang) * r_mid, math.sin(ang) * r_mid, 0.32 + (ci % 3) * 0.06), rot_deg=(180, 120, 90), scale=1.15)
        bc.kf_trs(coin, 72, loc=(math.cos(ang) * r_far, math.sin(ang) * r_far, 0.05), rot_deg=(360, 240, 180), scale=0.95)
        bc.kf_trs(coin, 80, loc=(math.cos(ang) * (r_far + 0.08), math.sin(ang) * (r_far + 0.08), 0.02), rot_deg=(420, 300, 220), scale=0.01)

    for obj in [compass, crown_piv, halo_low, halo_high] + [c[0] for c in coins]:
        bc.set_interp(obj, "BEZIER")

    bc.export_glb(bc.OUT_VFX_DIR / "card_anim_royal_crown.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_royal.png", frame=49, cam_loc=(1.4, -1.5, 1.15), cam_target=(0.0, 0.0, 0.24))


def build_arcane_conduit() -> None:
    """frames 1..82 @ 24fps = 3.42s: 6 rising rune obelisks + 3 twisted vortex ribbons + central arcane core + burst."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=82)
    mat_accent, mat_brass, _, _, mat_dark, mat_gold = _base_card_mats((0.68, 0.42, 1.0, 1.0), 3.6)

    root = bc.create_empty("ArcaneConduitRoot")

    # Central double-faceted Arcane Core + orbiting brass gimbal ring
    core_piv = bc.create_empty("ArcaneCorePivot", loc=(0.0, 0.0, 0.32), parent=root)
    c_core = bc.create_faceted_crystal("ArcaneCore", radius=0.095, height=0.28, sides=8, tip_ratio=0.45, bottom_taper=0.25, mat=mat_accent, parent=core_piv)
    c_core.location = Vector((0.0, 0.0, -0.14))
    c_gimbal = bc.create_ornate_ring("ArcaneCoreGimbal", 0.16, 0.135, 0.014, notches=6, notch_depth=0.012, segments=24, mat=mat_brass, parent=core_piv)
    c_gimbal.rotation_euler = (math.radians(52.0), 0.0, 0.0)

    # 6 Floating Rune Obelisk Crystals arranged in a ring
    obelisks = []
    for oi in range(6):
        ang = (float(oi) / 6.0) * math.tau
        ob_piv = bc.create_empty(f"RuneObeliskPivot_{oi}", loc=(math.cos(ang) * 0.38, math.sin(ang) * 0.38, 0.05), parent=root)
        bc.create_faceted_crystal(f"RuneObelisk_{oi}", radius=0.036, height=0.26, sides=4, tip_ratio=0.35, bottom_taper=0.45, mat=mat_dark, parent=ob_piv)
        band = bc.create_ornate_ring(f"ObeliskRuneBand_{oi}", 0.042, 0.034, 0.018, notches=4, notch_depth=0.008, segments=16, mat=mat_accent, parent=ob_piv)
        band.location = Vector((0.0, 0.0, 0.13))
        obelisks.append((ob_piv, ang))

    # 3 Twisted Elemental Vortex Ribbons spiraling upward cleanly around obelisks
    ribbons = []
    for ri in range(3):
        rib = bc.create_twisted_ribbon(
            f"ArcaneVortexRibbon_{ri}",
            radius_start=0.52,
            radius_end=0.22,
            height=0.68,
            turns=1.45,
            width=0.048,
            thickness=0.008,
            steps=38,
            phase_deg=ri * 120.0,
            mat=mat_accent if ri != 1 else mat_gold,
            parent=root,
        )
        ribbons.append(rib)

    # Expanding floor halo
    floor_halo = bc.create_ornate_ring("ArcaneFloorHalo", 0.52, 0.46, 0.014, notches=12, notch_depth=0.022, segments=48, mat=mat_accent, parent=root)

    # Animation (82 frames = 3.42s): rise helix -> compress anticipation (44..54) -> explosive burst (54..66) -> fade (66..82)
    bc.kf_trs(core_piv, 1, loc=(0, 0, 0.08), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(core_piv, 18, loc=(0, 0, 0.34), rot_deg=(0, 0, 180), scale=1.08)
    bc.kf_trs(core_piv, 44, loc=(0, 0, 0.42), rot_deg=(18, 0, 420), scale=1.18)
    bc.kf_trs(core_piv, 52, loc=(0, 0, 0.30), rot_deg=(0, 0, 520), scale=0.68)  # compression anticipation!
    bc.kf_trs(core_piv, 62, loc=(0, 0, 0.46), rot_deg=(0, 0, 700), scale=1.55)  # radial burst!
    bc.kf_trs(core_piv, 82, loc=(0, 0, 0.32), rot_deg=(0, 0, 880), scale=0.01)

    for oi, (ob_piv, ang) in enumerate(obelisks):
        z_bob = 0.08 + (oi % 2) * 0.08
        bc.kf_trs(ob_piv, 1, loc=(math.cos(ang) * 0.46, math.sin(ang) * 0.46, -0.04), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(ob_piv, 20, loc=(math.cos(ang + 0.5) * 0.36, math.sin(ang + 0.5) * 0.36, z_bob), rot_deg=(0, 0, 60), scale=1.05)
        bc.kf_trs(ob_piv, 50, loc=(math.cos(ang + 1.4) * 0.22, math.sin(ang + 1.4) * 0.22, z_bob + 0.14), rot_deg=(18, 0, 180), scale=1.10)
        bc.kf_trs(ob_piv, 64, loc=(math.cos(ang + 1.8) * 0.64, math.sin(ang + 1.8) * 0.64, z_bob + 0.24), rot_deg=(-35, 0, 240), scale=1.22)
        bc.kf_trs(ob_piv, 82, loc=(math.cos(ang + 2.0) * 0.72, math.sin(ang + 2.0) * 0.72, 0.04), rot_deg=(-45, 0, 290), scale=0.01)

    for ri, rib in enumerate(ribbons):
        bc.kf_trs(rib, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(rib, 20, loc=(0, 0, 0.04), rot_deg=(0, 0, 180), scale=1.05)
        bc.kf_trs(rib, 50, loc=(0, 0, 0.06), rot_deg=(0, 0, 480), scale=(0.72, 0.72, 1.15))
        bc.kf_trs(rib, 64, loc=(0, 0, 0.10), rot_deg=(0, 0, 680), scale=(1.55, 1.55, 1.25))
        bc.kf_trs(rib, 82, loc=(0, 0, 0.16), rot_deg=(0, 0, 820), scale=0.01)

    bc.kf_trs(floor_halo, 1, loc=(0, 0, 0.015), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(floor_halo, 20, loc=(0, 0, 0.015), rot_deg=(0, 0, -90), scale=1.0)
    bc.kf_trs(floor_halo, 52, loc=(0, 0, 0.015), rot_deg=(0, 0, -240), scale=0.88)
    bc.kf_trs(floor_halo, 64, loc=(0, 0, 0.015), rot_deg=(0, 0, -340), scale=1.45)
    bc.kf_trs(floor_halo, 82, loc=(0, 0, 0.015), rot_deg=(0, 0, -420), scale=0.01)

    for obj in [core_piv, floor_halo] + [o[0] for o in obelisks] + ribbons:
        bc.set_interp(obj, "BEZIER")

    bc.export_glb(bc.OUT_VFX_DIR / "card_anim_arcane_conduit.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_arcane.png", frame=42, cam_loc=(1.4, -1.5, 1.25), cam_target=(0.0, 0.0, 0.30))


def run() -> None:
    build_seven_barrage()
    build_ace_chronos()
    build_royal_crown()
    build_arcane_conduit()
    print("GEN_CARD_ANIMS_OK")


if __name__ == "__main__":
    run()
