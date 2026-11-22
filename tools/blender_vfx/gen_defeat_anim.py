"""Generates defeat_execution_anim.glb (frames 1..108 @ 24fps = 4.5s) for LIALO."""

import math
import bmesh
import bpy
from mathutils import Vector
import blender_common as bc


def _build_crown_shard(idx: int, total: int, mat_crown, mat_gem, parent) -> bpy.types.Object:
    """Create one arc segment (1/12th) of a medieval jeweled crown centered on local origin."""
    piv = bc.create_empty(f"CrownShard_{idx}", parent=parent)
    a0 = (float(idx) / float(total)) * math.tau
    a1 = (float(idx + 1) / float(total)) * math.tau
    amid = 0.5 * (a0 + a1)

    r_in = 0.165
    r_out = 0.210
    z_bot = -0.045
    z_top = 0.045

    bm = bmesh.new()
    segs = 3
    verts_in_b = []
    verts_out_b = []
    verts_in_t = []
    verts_out_t = []
    for s in range(segs + 1):
        u = float(s) / float(segs)
        a = a0 + (a1 - a0) * u
        ca, sa = math.cos(a), math.sin(a)
        verts_in_b.append(bm.verts.new((ca * r_in, sa * r_in, z_bot)))
        verts_out_b.append(bm.verts.new((ca * r_out, sa * r_out, z_bot)))
        verts_in_t.append(bm.verts.new((ca * r_in, sa * r_in, z_top)))
        verts_out_t.append(bm.verts.new((ca * r_out, sa * r_out, z_top)))

    for s in range(segs):
        bm.faces.new((verts_out_b[s], verts_out_b[s + 1], verts_out_t[s + 1], verts_out_t[s]))
        bm.faces.new((verts_in_b[s + 1], verts_in_b[s], verts_in_t[s], verts_in_t[s + 1]))
        bm.faces.new((verts_in_t[s], verts_out_t[s], verts_out_t[s + 1], verts_in_t[s + 1]))
        bm.faces.new((verts_out_b[s], verts_in_b[s], verts_in_b[s + 1], verts_out_b[s + 1]))

    bm.faces.new((verts_in_b[0], verts_out_b[0], verts_out_t[0], verts_in_t[0]))
    bm.faces.new((verts_out_b[-1], verts_in_b[-1], verts_in_t[-1], verts_out_t[-1]))
    bc.finalize_bmesh(f"CrownBandArc_{idx}", bm, mat=mat_crown, smooth=False, parent=piv)

    # Rising gothic spire + gem on each crown shard
    spire_h = 0.145 if idx % 2 == 0 else 0.105
    spire = bc.create_faceted_crystal(f"CrownShardSpire_{idx}", radius=0.028, height=spire_h, sides=4, tip_ratio=0.58, bottom_taper=0.72, mat=mat_crown, parent=piv)
    spire.location = Vector((math.cos(amid) * 0.188, math.sin(amid) * 0.188, z_top - 0.01))

    gem = bc.create_faceted_crystal(f"CrownShardGem_{idx}", radius=0.017, height=0.042, sides=6, mat=mat_gem, parent=piv)
    gem.location = Vector((math.cos(amid) * 0.215, math.sin(amid) * 0.215, -0.018))
    return piv


def build_defeat_execution_anim() -> None:
    """frames 1..108 @ 24fps = 4.5s dramatic execution greatsword cleave + 12-piece shattering crown."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=108)

    mat_blade_rune = bc.make_pbr_mat(
        "Mat_BladeRune",
        base_color=(0.98, 0.12, 0.16, 1.0),
        metallic=0.15,
        roughness=0.20,
        emission_color=(0.98, 0.10, 0.14, 1.0),
        emission_strength=2.6,
    )
    mat_eclipse = bc.make_pbr_mat(
        "Mat_EclipseGlow",
        base_color=(0.90, 0.10, 0.14, 1.0),
        metallic=0.10,
        roughness=0.24,
        emission_color=(0.88, 0.09, 0.14, 1.0),
        emission_strength=2.2,
    )
    mat_crown_gold = bc.make_pbr_mat(
        "Mat_CrownGold",
        base_color=(0.98, 0.78, 0.26, 1.0),
        metallic=0.90,
        roughness=0.22,
        emission_color=(0.65, 0.42, 0.08, 1.0),
        emission_strength=0.65,
    )
    mat_shadow_flame = bc.make_pbr_mat(
        "Mat_ShadowFlame",
        base_color=(0.74, 0.06, 0.10, 1.0),
        metallic=0.05,
        roughness=0.30,
        emission_color=(0.76, 0.06, 0.10, 1.0),
        emission_strength=2.0,
        alpha=0.84,
    )
    mat_steel = bc.make_pbr_mat("Mat_ExecSteel", base_color=(0.66, 0.70, 0.78, 1.0), metallic=0.92, roughness=0.20)
    mat_dark_iron = bc.make_pbr_mat("Mat_ExecDarkIron", base_color=(0.14, 0.12, 0.15, 1.0), metallic=0.80, roughness=0.38)
    mat_grip = bc.make_pbr_mat("Mat_ExecGrip", base_color=(0.24, 0.10, 0.10, 1.0), metallic=0.10, roughness=0.68)

    root = bc.create_empty("DefeatExecutionRoot")

    # 1. Sculpted 1.25m Gothic Executioner Greatsword + twin blade trail ribbons
    sword = bc.create_medieval_sword(
        "ExecSword",
        blade_len=1.25,
        blade_w=0.145,
        guard_w=0.40,
        curved=False,
        mat_blade=mat_steel,
        mat_guard=mat_dark_iron,
        mat_grip=mat_grip,
        mat_rune=mat_blade_rune,
        parent=root,
    )
    rib0 = bc.create_twisted_ribbon("BladeRibbon_0", 0.22, 0.56, 0.72, turns=1.1, width=0.09, thickness=0.010, steps=34, phase_deg=0.0, mat=mat_shadow_flame, parent=root)
    rib1 = bc.create_twisted_ribbon("BladeRibbon_1", 0.26, 0.62, 0.78, turns=-1.1, width=0.08, thickness=0.010, steps=34, phase_deg=180.0, mat=mat_eclipse, parent=root)

    # 2. Pre-Fractured 12-Piece Sovereign Crown + inner glowing CrownCoreCrack
    crown_center = (0.0, 0.0, 0.36)
    shards = [_build_crown_shard(i, 12, mat_crown_gold, mat_eclipse, root) for i in range(12)]
    crack_core = bc.create_faceted_crystal("CrownCoreCrack", radius=0.10, height=0.24, sides=8, tip_ratio=0.45, bottom_taper=0.25, mat=mat_blade_rune, parent=root)

    # 3. Jagged Eclipse Halo Ring + 6 Forged Iron Doom Chains + 4 Shadow-Ember Pillars
    eclipse_halo = bc.create_ornate_ring("EclipseHalo", 0.76, 0.66, 0.026, notches=16, notch_depth=0.055, segments=48, mat=mat_eclipse, parent=root)

    chains = []
    for ci in range(6):
        ang = (float(ci) / 6.0) * math.tau + 0.25
        ch_piv = bc.create_empty(f"DoomChainPivot_{ci}", loc=(math.cos(ang) * 0.68, math.sin(ang) * 0.68, 0.0), parent=root)
        ch = bc.create_chain_strand(f"DoomChain_{ci}", link_count=10, link_len=0.085, link_w=0.042, wire_r=0.009, mat=mat_dark_iron, parent=ch_piv)
        ch.rotation_euler = (math.radians(-26.0), 0.0, ang)
        chains.append((ch_piv, ang))

    pillars = []
    for pi in range(4):
        ang = (float(pi) / 4.0) * math.tau + math.pi * 0.25
        pl_piv = bc.create_empty(f"DoomPillarPivot_{pi}", loc=(math.cos(ang) * 0.78, math.sin(ang) * 0.78, 0.0), parent=root)
        bc.create_flame_tongue(f"DoomPillarFlame_{pi}", radius=0.082, height=0.78, twist_rad=2.4, lean_x=0.07, sides=8, levels=10, mat=mat_shadow_flame, parent=pl_piv)
        pillars.append((pl_piv, ang))

    # --- KEYFRAME CHOREOGRAPHY (frames 1..108 @ 24fps = 4.5s) ---
    # Beat 1 (1..28): Rise from darkness
    # Beat 2 (28..52): Coil high overhead, crown trembles & cracks
    # Beat 3 (52..60): Diagonal downward cleave straight through Crown at frame 55 (t=2.28s)
    # Beat 4 (60..108): Blade stabbed diagonally into table felt (crossguard ~0.72m high, blade tip anchored into table!)
    bc.kf_trs(sword, 1, loc=(0.15, -0.35, -0.25), rot_deg=(0, 0, 12), scale=0.05)
    bc.kf_trs(sword, 28, loc=(0.18, -0.22, 0.62), rot_deg=(14, -22, 22), scale=1.08)
    bc.kf_trs(sword, 48, loc=(0.28, -0.38, 0.96), rot_deg=(36, -30, -24), scale=1.16)
    bc.kf_trs(sword, 52, loc=(0.24, -0.32, 1.04), rot_deg=(44, -26, -30), scale=1.20)
    bc.kf_trs(sword, 55, loc=(0.04, 0.02, 0.84), rot_deg=(140, -16, 12), scale=1.24)  # Impact through crown!
    bc.kf_trs(sword, 59, loc=(-0.02, 0.08, 0.72), rot_deg=(152, -12, 16), scale=1.18)  # Embedded diagonally into table!
    # Steel vibration tremor
    bc.kf_trs(sword, 62, loc=(-0.02, 0.08, 0.72), rot_deg=(148, -10, 13), scale=1.16)
    bc.kf_trs(sword, 65, loc=(-0.02, 0.08, 0.72), rot_deg=(155, -13, 18), scale=1.15)
    bc.kf_trs(sword, 70, loc=(-0.02, 0.08, 0.72), rot_deg=(152, -12, 15), scale=1.14)
    bc.kf_trs(sword, 94, loc=(-0.02, 0.08, 0.72), rot_deg=(152, -12, 16), scale=1.10)
    bc.kf_trs(sword, 108, loc=(-0.02, 0.08, 0.56), rot_deg=(152, -12, 16), scale=0.01)

    for r_obj, yaw_end in ((rib0, 420.0), (rib1, -420.0)):
        bc.kf_trs(r_obj, 1, loc=(0, 0, 0.05), scale=0.01)
        bc.kf_trs(r_obj, 48, loc=(0, 0, 0.18), rot_deg=(0, 0, 120), scale=0.85)
        bc.kf_trs(r_obj, 57, loc=(0, 0, 0.10), rot_deg=(0, 0, yaw_end * 0.65), scale=1.45)
        bc.kf_trs(r_obj, 86, loc=(0, 0, 0.16), rot_deg=(0, 0, yaw_end), scale=0.80)
        bc.kf_trs(r_obj, 108, loc=(0, 0, 0.22), rot_deg=(0, 0, yaw_end * 1.15), scale=0.01)

    # Crown Core Crack
    bc.kf_trs(crack_core, 1, loc=(0, 0, 0.24), scale=0.01)
    bc.kf_trs(crack_core, 30, loc=crown_center, rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(crack_core, 53, loc=crown_center, rot_deg=(0, 0, 180), scale=1.25)
    bc.kf_trs(crack_core, 56, loc=crown_center, rot_deg=(0, 0, 220), scale=2.10)
    bc.kf_trs(crack_core, 68, loc=crown_center, rot_deg=(0, 0, 300), scale=0.01)

    # 12 Pre-fractured Crown Shards
    for idx, sh in enumerate(shards):
        ang = ((float(idx) + 0.5) / 12.0) * math.tau
        bc.kf_trs(sh, 1, loc=(0, 0, 0.04), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(sh, 26, loc=crown_center, rot_deg=(0, 0, 45), scale=1.05)
        # Violent pre-shatter tremble frames 32..53
        bc.kf_trs(sh, 36, loc=(math.cos(ang) * 0.015, math.sin(ang) * 0.015, 0.37), rot_deg=(3, -3, 52), scale=1.06)
        bc.kf_trs(sh, 44, loc=(-math.cos(ang) * 0.015, -math.sin(ang) * 0.015, 0.35), rot_deg=(-4, 4, 58), scale=1.08)
        bc.kf_trs(sh, 53, loc=(math.cos(ang) * 0.022, math.sin(ang) * 0.022, 0.38), rot_deg=(5, -5, 65), scale=1.10)
        # Exact frame 55 explosion outward along ballistic trajectories!
        dist_mid = 0.65 + (idx % 3) * 0.16
        dist_far = 1.05 + (idx % 4) * 0.22
        z_apex = 0.58 + (idx % 3) * 0.14
        bc.kf_trs(sh, 64, loc=(math.cos(ang) * dist_mid, math.sin(ang) * dist_mid, z_apex), rot_deg=(190 + idx * 35, 130, 120), scale=1.05)
        bc.kf_trs(sh, 86, loc=(math.cos(ang) * dist_far, math.sin(ang) * dist_far, 0.04), rot_deg=(460 + idx * 45, 310, 260), scale=0.88)
        bc.kf_trs(sh, 108, loc=(math.cos(ang) * (dist_far + 0.12), math.sin(ang) * (dist_far + 0.12), 0.02), rot_deg=(540 + idx * 45, 380, 310), scale=0.01)

    # Eclipse Halo
    bc.kf_trs(eclipse_halo, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.02)
    bc.kf_trs(eclipse_halo, 24, loc=(0, 0, 0.03), rot_deg=(0, 0, 75), scale=1.0)
    bc.kf_trs(eclipse_halo, 53, loc=(0, 0, 0.03), rot_deg=(0, 0, 160), scale=0.92)
    bc.kf_trs(eclipse_halo, 62, loc=(0, 0, 0.04), rot_deg=(0, 0, 220), scale=1.42)
    bc.kf_trs(eclipse_halo, 96, loc=(0, 0, 0.03), rot_deg=(0, 0, 320), scale=1.18)
    bc.kf_trs(eclipse_halo, 108, loc=(0, 0, 0.02), rot_deg=(0, 0, 360), scale=0.01)

    # 6 Iron Doom Chains
    for ci, (ch_piv, ang) in enumerate(chains):
        bc.kf_trs(ch_piv, 1, loc=(math.cos(ang) * 0.95, math.sin(ang) * 0.95, -0.30), rot_deg=(0, 0, 0), scale=0.02)
        bc.kf_trs(ch_piv, 24, loc=(math.cos(ang) * 0.68, math.sin(ang) * 0.68, 0.02), rot_deg=(0, 0, 0), scale=1.0)
        bc.kf_trs(ch_piv, 54, loc=(math.cos(ang) * 0.48, math.sin(ang) * 0.48, 0.04), rot_deg=(-25, 0, 14), scale=1.08)
        bc.kf_trs(ch_piv, 62, loc=(math.cos(ang) * 0.72, math.sin(ang) * 0.72, 0.02), rot_deg=(12, 0, 18), scale=1.02)
        bc.kf_trs(ch_piv, 96, loc=(math.cos(ang) * 0.76, math.sin(ang) * 0.76, 0.0), rot_deg=(16, 0, 22), scale=0.95)
        bc.kf_trs(ch_piv, 108, loc=(math.cos(ang) * 0.85, math.sin(ang) * 0.85, -0.15), rot_deg=(24, 0, 28), scale=0.01)

    # 4 Shadow-Ember Pillars
    for pi, (pl_piv, ang) in enumerate(pillars):
        bc.kf_trs(pl_piv, 1, loc=(math.cos(ang) * 0.78, math.sin(ang) * 0.78, 0.0), scale=0.01)
        bc.kf_trs(pl_piv, 24, loc=(math.cos(ang) * 0.78, math.sin(ang) * 0.78, 0.0), scale=0.65)
        bc.kf_trs(pl_piv, 55, loc=(math.cos(ang) * 0.86, math.sin(ang) * 0.86, 0.02), rot_deg=(0, 0, 60), scale=1.32)
        bc.kf_trs(pl_piv, 92, loc=(math.cos(ang) * 0.86, math.sin(ang) * 0.86, 0.02), rot_deg=(0, 0, 140), scale=0.95)
        bc.kf_trs(pl_piv, 108, loc=(math.cos(ang) * 0.90, math.sin(ang) * 0.90, 0.0), rot_deg=(0, 0, 180), scale=0.01)

    for obj in [sword, rib0, rib1, crack_core, eclipse_halo] + shards + [c[0] for c in chains] + [p[0] for p in pillars]:
        bc.set_interp(obj, "BEZIER")

    bc.export_glb(bc.OUT_VFX_DIR / "defeat_execution_anim.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_defeat.png", frame=58, cam_loc=(1.75, -1.95, 1.35), cam_target=(0.0, 0.0, 0.34))


def run() -> None:
    build_defeat_execution_anim()
    print("GEN_DEFEAT_ANIM_OK")


if __name__ == "__main__":
    run()
