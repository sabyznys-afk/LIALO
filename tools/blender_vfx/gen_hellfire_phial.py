"""Generates hellfire_phial_hero.glb, hellfire_explosion_anim.glb (3.0s), and hellfire_burn_crown.glb."""

import math
import bmesh
import bpy
from mathutils import Vector
import blender_common as bc


def _phial_mats():
    mat_iron = bc.make_pbr_mat("Mat_PhialIron", base_color=(0.16, 0.14, 0.16, 1.0), metallic=0.82, roughness=0.38)
    mat_brass = bc.make_pbr_mat("Mat_PhialBrass", base_color=(0.88, 0.66, 0.22, 1.0), metallic=0.90, roughness=0.22)
    mat_glass = bc.make_pbr_mat(
        "Mat_PhialGlass",
        base_color=(0.88, 0.24, 0.08, 1.0),
        metallic=0.05,
        roughness=0.10,
        emission_color=(0.75, 0.16, 0.04, 1.0),
        emission_strength=0.45,
        alpha=0.58,
        transmission=0.65,
        ior=1.52,
    )
    mat_magma = bc.make_pbr_mat(
        "Mat_PhialMagma",
        base_color=(1.0, 0.36, 0.04, 1.0),
        metallic=0.0,
        roughness=0.18,
        emission_color=(1.0, 0.30, 0.02, 1.0),
        emission_strength=2.6,
    )
    mat_white_core = bc.make_pbr_mat(
        "Mat_PlasmaCore",
        base_color=(1.0, 0.86, 0.38, 1.0),
        metallic=0.0,
        roughness=0.12,
        emission_color=(1.0, 0.72, 0.18, 1.0),
        emission_strength=3.6,
    )
    mat_cork = bc.make_pbr_mat("Mat_PhialCork", base_color=(0.48, 0.30, 0.16, 1.0), metallic=0.0, roughness=0.72)
    mat_wax = bc.make_pbr_mat("Mat_PhialWax", base_color=(0.72, 0.11, 0.10, 1.0), metallic=0.05, roughness=0.34)
    mat_flame_outer = bc.make_pbr_mat(
        "Mat_FlameOuter",
        base_color=(0.98, 0.18, 0.02, 1.0),
        metallic=0.0,
        roughness=0.25,
        emission_color=(0.96, 0.16, 0.02, 1.0),
        emission_strength=2.4,
        alpha=0.82,
    )
    return {
        "iron": mat_iron,
        "brass": mat_brass,
        "glass": mat_glass,
        "magma": mat_magma,
        "core": mat_white_core,
        "cork": mat_cork,
        "wax": mat_wax,
        "flame_outer": mat_flame_outer,
    }


def build_hellfire_phial_hero() -> None:
    """Tabletop hero flask (~0.21m tall) with coaster, fluted glass, iron strapwork cage, magma core & IgnitedPlume."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=2)
    m = _phial_mats()

    root = bc.create_empty("HellfirePhialRoot")

    # 1. Octagonal iron-and-brass coaster
    bc.create_lathe_mesh(
        "PhialCoaster",
        [(0.068, 0.0), (0.065, 0.008), (0.056, 0.011), (0.052, 0.011)],
        segments=8,
        mat=m["iron"],
        smooth=False,
        parent=root,
    )
    coaster_rim = bc.create_ornate_ring("PhialCoasterRim", 0.064, 0.056, 0.006, notches=8, notch_depth=0.004, segments=8, mat=m["brass"], parent=root)
    coaster_rim.location = Vector((0, 0, 0.011))

    # 2. Inner molten magma sphere + 6 suspended ember bubbles
    magma = bc.create_lathe_mesh(
        "PhialMagmaCore",
        [(0.001, 0.032), (0.036, 0.044), (0.046, 0.066), (0.034, 0.088), (0.001, 0.098)],
        segments=20,
        mat=m["magma"],
        smooth=True,
        cap_bottom=False,
        cap_top=False,
        parent=root,
    )
    for ei in range(6):
        ang = (float(ei) / 6.0) * math.tau
        rad = 0.028 if ei % 2 == 0 else 0.020
        z_eb = 0.050 + (ei % 3) * 0.016
        emb = bc.create_faceted_crystal(f"PhialEmber_{ei}", radius=0.0065, height=0.014, sides=6, mat=m["core"], parent=magma)
        emb.location = Vector((math.cos(ang) * rad, math.sin(ang) * rad, z_eb))

    # 3. Sculpted fluted glass flask
    glass_prof = [
        (0.034, 0.014),
        (0.058, 0.038),
        (0.064, 0.066),
        (0.056, 0.094),
        (0.032, 0.116),
        (0.024, 0.140),
        (0.025, 0.162),
        (0.031, 0.168),
        (0.026, 0.173),
    ]
    bc.create_lathe_mesh("PhialGlass", glass_prof, segments=24, mat=m["glass"], smooth=True, parent=root)

    # 4. Wrought-iron riveted cage strapwork (equator + 2 meridian hoops)
    cage = bc.create_empty("PhialIronCage", parent=root)
    eq = bc.create_ornate_ring("CageEquator", 0.068, 0.062, 0.010, notches=8, notch_depth=0.004, segments=24, mat=m["iron"], parent=cage)
    eq.location = Vector((0, 0, 0.066))
    for mi in range(2):
        mer = bc.create_ornate_ring(f"CageMeridian_{mi}", 0.067, 0.061, 0.008, notches=0, notch_depth=0.0, segments=24, mat=m["iron"], parent=cage)
        mer.location = Vector((0, 0, 0.066))
        mer.rotation_euler = (math.pi * 0.5, 0.0, float(mi) * math.pi * 0.5)

    # 5. Brass shoulder collar, cork stopper, dripping red wax seal & curved wick
    collar = bc.create_ornate_ring("PhialCollar", 0.033, 0.024, 0.016, notches=8, notch_depth=0.003, segments=18, mat=m["brass"], parent=root)
    collar.location = Vector((0, 0, 0.164))
    bc.create_lathe_mesh(
        "PhialCork",
        [(0.017, 0.164), (0.020, 0.188), (0.018, 0.192)],
        segments=14,
        mat=m["cork"],
        smooth=True,
        parent=root,
    )
    bc.create_lathe_mesh(
        "PhialWaxSeal",
        [(0.023, 0.172), (0.025, 0.182), (0.021, 0.194), (0.001, 0.196)],
        segments=14,
        mat=m["wax"],
        smooth=True,
        cap_top=False,
        parent=root,
    )
    wick = bc.create_twisted_ribbon("PhialWick", 0.004, 0.012, 0.028, turns=0.4, width=0.005, thickness=0.004, steps=10, mat=m["cork"], parent=root)
    wick.location = Vector((0, 0, 0.192))
    tip = bc.create_flame_tongue("PhialWickFlame", radius=0.010, height=0.028, twist_rad=1.0, lean_x=0.005, sides=6, levels=6, mat=m["magma"], parent=root)
    tip.location = Vector((0.008, 0.0, 0.214))

    # 6. IgnitedPlume node (hidden while idle on table; sleek flame plume shown during throw!)
    plume = bc.create_empty("IgnitedPlume", loc=(0.0, 0.0, 0.16), parent=root)
    for fi in range(4):
        ang = (float(fi) / 4.0) * math.tau
        ft = bc.create_flame_tongue(
            f"IgniteTongue_{fi}",
            radius=0.022 if fi % 2 == 0 else 0.016,
            height=0.15 if fi % 2 == 0 else 0.11,
            twist_rad=2.4,
            lean_x=0.018,
            sides=8,
            levels=8,
            mat=m["flame_outer"] if fi % 2 == 0 else m["magma"],
            parent=plume,
        )
        ft.location = Vector((math.cos(ang) * 0.010, math.sin(ang) * 0.010, 0.03))
        ft.rotation_euler = (math.radians(-8.0), 0.0, ang)
    plume_rib = bc.create_twisted_ribbon("IgniteSpiral", 0.038, 0.014, 0.16, turns=1.6, width=0.014, thickness=0.005, steps=22, mat=m["core"], parent=plume)
    plume_rib.location = Vector((0.0, 0.0, 0.01))

    bc.export_glb(bc.OUT_VFX_DIR / "hellfire_phial_hero.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_phial.png", frame=1, cam_loc=(0.38, -0.42, 0.28), cam_target=(0.0, 0.0, 0.11))


def build_hellfire_explosion_anim() -> None:
    """frames 1..72 @ 24fps = 3.0s detonation rig at target_global: 18 glass shards, 3 broken hoops, fireball & pillars."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=72)
    m = _phial_mats()

    root = bc.create_empty("HellfireExplosionRoot")

    # 1. White-gold plasma core flash
    core_flash = bc.create_lathe_mesh(
        "PlasmaCoreFlash",
        [(0.001, -0.22), (0.20, -0.10), (0.24, 0.0), (0.20, 0.10), (0.001, 0.22)],
        segments=20,
        mat=m["core"],
        smooth=True,
        cap_bottom=False,
        cap_top=False,
        parent=root,
    )
    core_flash.location = Vector((0, 0, 0.16))

    # 2. Nested jagged sculpted fireball crowns
    crown_inner = bc.create_empty("FireballCrown_Inner", loc=(0, 0, 0.05), parent=root)
    crown_outer = bc.create_empty("FireballCrown_Outer", loc=(0, 0, 0.02), parent=root)
    for fi in range(8):
        ang = (float(fi) / 8.0) * math.tau
        t_in = bc.create_flame_tongue(f"FireCrownIn_{fi}", radius=0.14, height=0.46, twist_rad=1.4, lean_x=0.10, sides=7, levels=8, mat=m["magma"], parent=crown_inner)
        t_in.location = Vector((math.cos(ang) * 0.08, math.sin(ang) * 0.08, 0.0))
        t_in.rotation_euler = (math.radians(16.0), 0.0, ang)

        t_out = bc.create_flame_tongue(f"FireCrownOut_{fi}", radius=0.18, height=0.64, twist_rad=-1.8, lean_x=0.18, sides=8, levels=9, mat=m["flame_outer"], parent=crown_outer)
        t_out.location = Vector((math.cos(ang + 0.35) * 0.14, math.sin(ang + 0.35) * 0.14, 0.0))
        t_out.rotation_euler = (math.radians(26.0), 0.0, ang + 0.35)

    # 3. 6 Spiraling rising flame pillars
    pillars = []
    for pi in range(6):
        ang = (float(pi) / 6.0) * math.tau
        p_rib = bc.create_twisted_ribbon(
            f"FlamePillar_{pi}",
            radius_start=0.16,
            radius_end=0.46,
            height=0.88,
            turns=1.35,
            width=0.085,
            thickness=0.012,
            steps=30,
            phase_deg=pi * 60.0,
            mat=m["flame_outer"] if pi % 2 == 0 else m["magma"],
            parent=root,
        )
        pillars.append(p_rib)

    # 4. 18 Sculpted amber/ruby glass shatter shards flying radially outward
    shards = []
    for si in range(18):
        ang = (float(si) / 18.0) * math.tau + (si % 3) * 0.14
        elev = 0.25 + (si % 4) * 0.22
        sh = bc.create_faceted_crystal(
            f"GlassShard_{si}",
            radius=0.032 + (si % 3) * 0.008,
            height=0.095 + (si % 2) * 0.035,
            sides=4,
            tip_ratio=0.45,
            bottom_taper=0.25,
            mat=m["glass"] if si % 3 != 0 else m["magma"],
            parent=root,
        )
        shards.append((sh, ang, elev, si))

    # 5. 3 Tumbling broken iron cage hoops
    hoops = []
    for hi in range(3):
        ang = (float(hi) / 3.0) * math.tau + 0.4
        hp = bc.create_ornate_ring(f"BrokenCage_{hi}", 0.085, 0.072, 0.014, notches=6, notch_depth=0.008, segments=18, mat=m["iron"], parent=root)
        hoops.append((hp, ang, hi))

    # 6. Two concentric molten magma shockwave rings
    wave_a = bc.create_ornate_ring("MagmaWave_A", 0.55, 0.44, 0.022, notches=16, notch_depth=0.04, segments=48, mat=m["magma"], parent=root)
    wave_b = bc.create_ornate_ring("MagmaWave_B", 0.42, 0.36, 0.018, notches=12, notch_depth=0.025, segments=40, mat=m["core"], parent=root)

    # Keyframe 3.0s explosion (frames 1..72)
    bc.kf_trs(core_flash, 1, loc=(0, 0, 0.14), scale=0.08)
    bc.kf_trs(core_flash, 5, loc=(0, 0, 0.22), scale=1.65)
    bc.kf_trs(core_flash, 16, loc=(0, 0, 0.26), scale=1.10)
    bc.kf_trs(core_flash, 38, loc=(0, 0, 0.22), scale=0.45)
    bc.kf_trs(core_flash, 72, loc=(0, 0, 0.14), scale=0.01)

    bc.kf_trs(crown_inner, 1, loc=(0, 0, 0.04), rot_deg=(0, 0, 0), scale=0.05)
    bc.kf_trs(crown_inner, 8, loc=(0, 0, 0.08), rot_deg=(0, 0, 45), scale=1.35)
    bc.kf_trs(crown_inner, 28, loc=(0, 0, 0.12), rot_deg=(0, 0, 140), scale=1.20)
    bc.kf_trs(crown_inner, 54, loc=(0, 0, 0.10), rot_deg=(0, 0, 240), scale=0.75)
    bc.kf_trs(crown_inner, 72, loc=(0, 0, 0.04), rot_deg=(0, 0, 320), scale=0.01)

    bc.kf_trs(crown_outer, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.05)
    bc.kf_trs(crown_outer, 11, loc=(0, 0, 0.05), rot_deg=(0, 0, -55), scale=1.42)
    bc.kf_trs(crown_outer, 34, loc=(0, 0, 0.08), rot_deg=(0, 0, -165), scale=1.30)
    bc.kf_trs(crown_outer, 58, loc=(0, 0, 0.06), rot_deg=(0, 0, -270), scale=0.72)
    bc.kf_trs(crown_outer, 72, loc=(0, 0, 0.02), rot_deg=(0, 0, -340), scale=0.01)

    for pi, p_rib in enumerate(pillars):
        bc.kf_trs(p_rib, 1, loc=(0, 0, 0.04), rot_deg=(0, 0, 0), scale=0.04)
        bc.kf_trs(p_rib, 14, loc=(0, 0, 0.08), rot_deg=(0, 0, 140), scale=1.22)
        bc.kf_trs(p_rib, 42, loc=(0, 0, 0.22), rot_deg=(0, 0, 380), scale=(1.35, 1.35, 1.15))
        bc.kf_trs(p_rib, 72, loc=(0, 0, 0.36), rot_deg=(0, 0, 580), scale=0.01)

    for sh, ang, elev, si in shards:
        r1 = 0.42 + (si % 3) * 0.12
        r2 = 0.88 + (si % 4) * 0.16
        bc.kf_trs(sh, 1, loc=(0, 0, 0.12), rot_deg=(si * 22, si * 35, 0), scale=0.1)
        bc.kf_trs(sh, 9, loc=(math.cos(ang) * r1, math.sin(ang) * r1, 0.20 + elev * 0.7), rot_deg=(180 + si * 30, 120, 90), scale=1.25)
        bc.kf_trs(sh, 36, loc=(math.cos(ang) * r2, math.sin(ang) * r2, 0.10 + elev * 0.2), rot_deg=(480, 340, 260), scale=0.95)
        bc.kf_trs(sh, 72, loc=(math.cos(ang) * (r2 + 0.16), math.sin(ang) * (r2 + 0.16), 0.02), rot_deg=(680, 500, 380), scale=0.01)

    for hp, ang, hi in hoops:
        r_h = 0.56 + hi * 0.14
        bc.kf_trs(hp, 1, loc=(0, 0, 0.12), rot_deg=(45 * hi, 0, 0), scale=0.2)
        bc.kf_trs(hp, 14, loc=(math.cos(ang) * r_h * 0.5, math.sin(ang) * r_h * 0.5, 0.42 + hi * 0.08), rot_deg=(210, 140, 80), scale=1.15)
        bc.kf_trs(hp, 46, loc=(math.cos(ang) * r_h, math.sin(ang) * r_h, 0.06), rot_deg=(420, 310, 190), scale=0.95)
        bc.kf_trs(hp, 72, loc=(math.cos(ang) * (r_h + 0.08), math.sin(ang) * (r_h + 0.08), 0.02), rot_deg=(490, 360, 220), scale=0.01)

    bc.kf_trs(wave_a, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.05)
    bc.kf_trs(wave_a, 12, loc=(0, 0, 0.03), rot_deg=(0, 0, 60), scale=1.45)
    bc.kf_trs(wave_a, 44, loc=(0, 0, 0.03), rot_deg=(0, 0, 150), scale=1.95)
    bc.kf_trs(wave_a, 72, loc=(0, 0, 0.02), rot_deg=(0, 0, 220), scale=0.01)

    bc.kf_trs(wave_b, 1, loc=(0, 0, 0.06), rot_deg=(0, 0, 0), scale=0.05)
    bc.kf_trs(wave_b, 9, loc=(0, 0, 0.10), rot_deg=(0, 0, -80), scale=1.35)
    bc.kf_trs(wave_b, 38, loc=(0, 0, 0.16), rot_deg=(0, 0, -210), scale=1.75)
    bc.kf_trs(wave_b, 72, loc=(0, 0, 0.18), rot_deg=(0, 0, -320), scale=0.01)

    for obj in [core_flash, crown_inner, crown_outer, wave_a, wave_b] + pillars + [s[0] for s in shards] + [h[0] for h in hoops]:
        bc.set_interp(obj, "BEZIER")

    bc.export_glb(bc.OUT_VFX_DIR / "hellfire_explosion_anim.glb")
    bc.render_preview(bc.PREVIEW_DIR / "preview_explosion.png", frame=12, cam_loc=(1.5, -1.6, 1.15), cam_target=(0.0, 0.0, 0.28))


def build_hellfire_burn_crown() -> None:
    """Persistent sculpted 3D fiery crown & swirling flames mounted on burning Rival."""
    bc.reset_scene(fps=24, frame_start=1, frame_end=48)
    m = _phial_mats()

    root = bc.create_empty("BurnCrownRoot")
    ring = bc.create_ornate_ring("BurnBaseRing", 0.34, 0.29, 0.018, notches=8, notch_depth=0.022, segments=36, mat=m["magma"], parent=root)
    for fi in range(8):
        ang = (float(fi) / 8.0) * math.tau
        ft = bc.create_flame_tongue(
            f"BurnTongue_{fi}",
            radius=0.068 if fi % 2 == 0 else 0.052,
            height=0.38 if fi % 2 == 0 else 0.28,
            twist_rad=1.8,
            lean_x=0.05,
            sides=7,
            levels=8,
            mat=m["flame_outer"] if fi % 2 == 0 else m["magma"],
            parent=ring,
        )
        ft.location = Vector((math.cos(ang) * 0.31, math.sin(ang) * 0.31, 0.0))
        ft.rotation_euler = (math.radians(-10.0), 0.0, ang)

    bc.kf_trs(ring, 1, loc=(0, 0, 0.02), rot_deg=(0, 0, 0), scale=0.96)
    bc.kf_trs(ring, 24, loc=(0, 0, 0.05), rot_deg=(0, 0, 180), scale=1.06)
    bc.kf_trs(ring, 48, loc=(0, 0, 0.02), rot_deg=(0, 0, 360), scale=0.96)
    bc.set_interp(ring, "LINEAR")

    bc.export_glb(bc.OUT_VFX_DIR / "hellfire_burn_crown.glb")


def run() -> None:
    build_hellfire_phial_hero()
    build_hellfire_explosion_anim()
    build_hellfire_burn_crown()
    print("GEN_HELLFIRE_PHIAL_OK")


if __name__ == "__main__":
    run()
