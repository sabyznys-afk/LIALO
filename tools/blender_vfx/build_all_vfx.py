"""Master Blender 5.3 headless script generating all 10 LIALO 3D VFX GLB assets and preview renders."""

import sys
import pathlib

THIS_DIR = pathlib.Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

import blender_common as bc
import gen_scoring_vfx
import gen_card_anims
import gen_hellfire_phial
import gen_defeat_anim


EXPECTED_GLBS = [
    "scoring_astrolabe_stage.glb",
    "scoring_tokens_pack.glb",
    "card_anim_seven_barrage.glb",
    "card_anim_ace_chronos.glb",
    "card_anim_royal_crown.glb",
    "card_anim_arcane_conduit.glb",
    "hellfire_phial_hero.glb",
    "hellfire_explosion_anim.glb",
    "hellfire_burn_crown.glb",
    "defeat_execution_anim.glb",
]


def main() -> None:
    bc.OUT_VFX_DIR.mkdir(parents=True, exist_ok=True)
    bc.PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    gen_scoring_vfx.run()
    gen_card_anims.run()
    gen_hellfire_phial.run()
    gen_defeat_anim.run()

    print("=== GENERATED GLB SUMMARY ===")
    missing = []
    for name in EXPECTED_GLBS:
        p = bc.OUT_VFX_DIR / name
        if not p.exists():
            missing.append(name)
            print(f"MISSING: {p}")
        else:
            sz = p.stat().st_size
            print(f"OK: {name} ({sz} bytes)")
            if sz < 5000:
                print(f"WARNING: {name} is unusually small ({sz} bytes)")

    if missing:
        raise RuntimeError(f"Missing expected GLBs: {missing}")
    print("ALL_10_VFX_GLBS_READY")


if __name__ == "__main__":
    main()
