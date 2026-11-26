# LIALO — Hand-Drawn ("Kreslené") 3D Relics & Textures Rework Standard (v0.196 Blueprint)

> **Official Visual Reference:** `TRELIC_WAR_HORN` (Tavern Ale Tankard / Krčmový korbel piva)
> - Reference Generator: [`tools/generate_tankard_relic.py`](../tools/generate_tankard_relic.py)
> - Reference Mesh: `assets/models/relics/TRELIC_WAR_HORN.glb` (9,494 tris, 7 sub-meshes, baked crevice AO)
> - Reference Textures: `assets/textures/relics/tankard_{oak,brass,crest,foam}_ink.png`
> - Reference Living FX: [`scripts/battle/tankard_bubbles_fx.gd`](../scripts/battle/tankard_bubbles_fx.gd)
> - Reference Shaders: [`shaders/handdrawn_relic_3d.gdshader`](../shaders/handdrawn_relic_3d.gdshader) + [`shaders/handdrawn_outline_3d.gdshader`](../shaders/handdrawn_outline_3d.gdshader)
> - Reference GPU QA Capture: [`tools/capture_relic_screenshot.gd`](../tools/capture_relic_screenshot.gd)

---

## 1. Mandatory Quality Standard (The "Tankard Norm")

Every reworked 3D relic, weapon, and table texture MUST follow these 5 rules so the entire tavern table shares one cohesive illustrated hand-drawn 3D look:

1. **Custom Hand-Drawn Woodcut Shaders (Zero Plain PBR):**
   - Surface pass: `shaders/handdrawn_relic_3d.gdshader` (3-band painterly cel ramp, UV-locked `45° / -45°` engraved crosshatching that never swims on 360° rotation, baked vertex AO ink creases, stepped gouache highlights, and dual candlelight Fresnel contours).
   - Outline pass (`next_pass`): `shaders/handdrawn_outline_3d.gdshader` (distance-compensated sepia-black nib contour `thickness = 0.0005..0.0012` with organic vertex wobble).
2. **Sculpted Multi-Part Binary `.glb` Geometry (Zero Primitive-Looking Shapes):**
   - Target `6,000–12,000` triangles per hero relic generated cleanly via Python (`NumPy` + `PIL`) or Blender.
   - Real beveled edges, carved seams, recessed grooves, domed rivets, swept handle/chain/ribbon profiles — never bare spheres/boxes.
   - Mandatory spatial vertex-normal welding on curved/organic meshes (`recompute_smooth_normals(weld_positions=True)`) and mathematical outward winding enforcement (`enforce_outward_winding_from_normals()`) so no faces ever render inside-out.
   - **Baked Crevice Vertex AO (`COLOR_0`):** darken recessed seams, rivet collars, and overhangs (`0.25..0.55`) so the ink shader draws rich manual shadows inside every fold.
3. **1024×1024 Hand-Inked Woodcut Textures (`assets/textures/relics/`):**
   - Generated/painted with distinct plank/stone/cloth value variation, reed-pen woodgrain/stippling/scuffs, dark ink seams, contact shadows, and paper grain tooth.
4. **Living 3D Hand-Drawn FX Per Relic (`scripts/battle/<relic>_fx.gd`):**
   - Every relic carries a signature, subtle, always-living hand-drawn 3D micro-animation mounted under `SpinPivot` (just like `TankardBubblesFx` rising & popping ink-outlined ale bubbles on `TRELIC_WAR_HORN`).
5. **Mandatory Visual Multi-Angle GPU Screenshot QA:**
   - Capture every reworked relic from Hero 3/4, Back/Detail, and Tabletop Duel angles using a non-headless GPU script (like `tools/capture_relic_screenshot.gd`), inspect via `read_file`, fix any silhouette/normal/outline/contrast issue, then verify headless tests pass.

---

## 2. Detailed Rework Plan for the Remaining 9 Tabletop Relics (`TRELIC_*`)

| Relic ID | Name | Sculpted Multi-Mesh Anatomy (`.glb`) | Hand-Inked Textures (`1024×1024`) | Signature Living 3D FX |
| :--- | :--- | :--- | :--- | :--- |
| **`TRELIC_HOLLOW_MASK`** | **Loaded Bone Dice** | Carved ivory twin dice with beveled edges & corners, deeply recessed ink pip bowls, inlaid brass corner brackets, and a carved leather/walnut dice cup rim base. | `dice_ivory_ink.png` (cracked antique bone grain, crosshatched bevels), `dice_pip_ink.png`, `leather_ink.png`. | Subtle levitating dice shimmer + spinning inked golden luck sparks arcing between the twin pips. |
| **`TRELIC_STAR_BOW`** | **Arcane Slate Rune** | Cracked split obsidian/slate standing stone with chiseled bevel fractures, recessed glowing rune trenches, copper binding wire, and 3 hovering carved rune chips. | `rune_slate_ink.png` (hand-hatched stone fractures, chisel marks), `rune_glyph_ink.png` (azure luminous ink veins). | 3 orbiting chiseled stone shards bobbing at staggered speeds + pulsing rune dust specks rising along the crack. |
| **`TRELIC_BLOOD_SEAL`** | **Crimson Blood Goblet** | Ornate fluted Gothic chalice, knopped stem with hammered filigree collar, 4 claw-set faceted rubies, brimming rippled crimson wine dome, and wax seal ribbon around stem. | `goblet_silver_ink.png`, `goblet_ruby_ink.png`, `blood_wine_ink.png`. | Thick hand-inked crimson blood/wine droplets swelling & hovering gently over the rim + slow ripple pulse on the liquid dome. |
| **`TRELIC_IRON_CHAIN`** | **Executioner's Whetstone** | Mortised timber cradle with brass pins, chipped angled stone wheel/block with hollow grind groove, leather strop strip, and crossed steel sharpening dagger. | `whetstone_granite_ink.png`, `oak_cradle_ink.png`, `forged_steel_ink.png`. | Crisp hand-inked amber sharpening sparks flying rhythmically off the steel blade bevel + faint dust motes. |
| **`TRELIC_ASH_GLASS`** | **Fate Hourglass** | Lathe-turned brass top & bottom plates with engraved zodiac notches, 4 twisted barley-sugar brass pillars, faceted blown glass twin bulbs, and sculpted hourglass sand cones. | `hourglass_brass_ink.png`, `hourglass_glass_ink.png`, `gold_sand_ink.png`. | Continuous thin golden-sand stream trickling through the center pinch + shimmering cyan/gold sand grains curling at the cone base. |
| **`TRELIC_GOLD_SCALES`** | **Guild Coin Purse** | Sewn pleated leather pouch with sculpted folds & drawstring throat, twisted hemp/brass cord, and 14 individually beveled stamped gold Florin coins spilling out. | `purse_leather_ink.png` (stitched seams, crosshatched folds), `florin_gold_ink.png` (crowned relief stamping). | Gleaming inked gold coin sparkles + tiny tumbling Florin aura glint rising off the open pouch rim. |
| **`TRELIC_SOUL_BELL`** | **Graveyard Toll Bell** | Timber gallows post with wrought-iron corner braces & bolts, flared notched cracked-bronze bell with Latin rim relief, iron chain link, and swinging crystal clapper. | `gallows_timber_ink.png`, `cracked_bronze_ink.png` (patina + fracture ink), `soul_clapper_ink.png`. | Slow ominous pendulum sway of the bell & clapper + spectral cyan-ink smoke wisps drifting out from beneath the flared rim. |
| **`TRELIC_CENSER`** | **Alchemist's Ember Censer** | Forged iron crane hook & tripod base, 3 delicate link chains, hinged openwork lattice brass censer sphere (upper filigree perforations revealing glowing coals inside). | `censer_iron_ink.png`, `censer_filigree_ink.png`, `ember_coal_ink.png`. | Gentle chain-sway micro-swing + 12 curling hand-inked incense smoke puffs & ember sparks rising through the upper perforations. |
| **`TRELIC_PHOENIX_BOX`** | **Phoenix Ember Reliquary** | Carved brass-bound hardwood reliquary chest with hinged open lid, iron lock hasp, sculpted curling phoenix wing reliefs on side panels, and sculpted flame-plume ember crest inside. | `reliquary_ebony_ink.png`, `phoenix_brass_ink.png`, `ember_plume_ink.png`. | Breathing molten ember core + spiraling ink-outlined phoenix feathers & ember sparks drifting above the open chest. |

---

## 3. Global 3D Texture & Tavern Prop Upgrade Plan

Once the 9 remaining `TRELIC_*` relics are converted, apply this exact same hand-drawn 3D standard across shared table textures and interactive props:

1. **Coaster Pedestal Standardization (`scripts/relic_mesh_factory.gd`):**
   - Route ALL relics' octagonal coaster base (`walnut`, `brass`, `ReadyHalo`) through `_apply_handdrawn_coaster(root)` with `handdrawn_relic_3d.gdshader` + beveled coaster geometry so every relic rests on an illustrated base.
2. **Oath Blades (`SWORD_*` in `RelicMeshFactory.build_sword_3d_mesh`):**
   - Sculpt true fullered blades, twisted wire-wrapped leather grips, engraved crossguards & pommels as `.glb` assets with `handdrawn_relic_3d.gdshader` + hand-inked steel/gold/runic blade textures (replacing plain PBR colors).
3. **Interactive Tavern Table Props (`mug`, `coins`, `dice`, `bell`, `phial`):**
   - Share the new sculpted `.glb` + hand-inked textures directly between `TABLE_RELICS` and the interactive tabletop props (`mug` <-> Tankard base mesh, `dice` <-> Bone Dice, `coins` <-> Coin Purse, `bell` <-> Toll Bell) so bothDuel Table and `RelicInspect3D` look consistently illustrated.
4. **Tavern Environment Wood / Stone / Felt Pass (`assets/table/`):**
   - Upgrade `wood.png` and table trim shaders toward warm crosshatched woodcut planks and subtle edge ink wear so the sculpted relics sit naturally on the table surface without lighting contrast clashing.
