# Archive: Prism Items (`SPEC_PRISM`, `REL_PRISM_ORB`) & Temporarily Hidden Relics (`REL_CHAMOIS`, `REL_STORMCAP`)

This document preserves the complete original definitions, scoring logic, save-state hooks, and art asset paths for the archived Prism items (`SPEC_PRISM` and `REL_PRISM_ORB`), as well as instructions for unhiding the temporarily hidden relics (`REL_CHAMOIS` and `REL_STORMCAP`).

---

## 1. Archived & Removed Items (Prism)

Both Prism items have been **completely removed** from active gameplay (`LialoCatalog.POWER_CARDS`, `LialoCatalog.RELICS`, `ScoringEngine`, starter loadouts, Quick Showcase, and shop/collection pools). Legacy save files are automatically sanitized on load via `LialoCatalog.sanitize_profile()` / `LialoCatalog.load_profile()`.

The original 2D art assets remain untouched on disk for potential future revival:
- Power Card Art: `res://assets/cards/SPEC_PRISM.png` (`assets/cards/SPEC_PRISM.png`)
- Relic Icon Art: `res://assets/relics/REL_PRISM_ORB.png` (`assets/relics/REL_PRISM_ORB.png`)

### 1.1 `SPEC_PRISM` — Prismatic Core / Prizmatické jádro

#### Original `scripts/lialo_catalog.gd` Entry (`POWER_CARDS`)
```gdscript
	{
		"id": "SPEC_PRISM", "name": "Prismatic Core", "name_cs": "Prizmatické jádro", "short": "PRISM", "short_cs": "PRISMA", "suit": "CERVEN",
		"pts": 22, "cost": 25, "rarity": "Mythic", "rarity_cs": "Mýtická", "wild": true,
		"accent": Color(0.94, 0.56, 1.0), "art_file": "SPEC_PRISM.png",
		"power_line": "+0.6× per Card Played", "power_line_cs": "+0.6× za každou kartu",
		"desc": "WILD: Gains +0.6× Mult per card played & permanently gets +4 pts!",
		"desc_cs": "DIVOKÁ: Přidá +0.6× za každou zahranou kartu a trvale posílí o +4 b.!"
	},
```

#### Original `scripts/scoring_engine.gd` Branch (`_apply_power_scoring`)
```gdscript
		"SPEC_PRISM":
			var add_m := 0.6 * float(cnt)
			res["flat_mult"] = add_m
			res["lightning"] = true
			res["label"] = ("💎 Prizma: +%.1f× & +4 b.!" if cs else "💎 Prism Core: +%.1f× & +4 Pts!") % add_m
```

#### Original `scripts/battle_table_3d.gd` Hooks (for reference)
```gdscript
# Impact VFX (lines 2474-2476):
		"SPEC_PRISM":
			for pc in [Color(1, 0.3, 0.3), Color(1, 0.85, 0.3), Color(0.3, 1, 0.5), Color(0.4, 0.6, 1)]:
				Fx.shard_burst(self, impact_pos, pc, 5, 0.42)

# Deck injection scaling (line 8715):
		var p_pts := int(pc["pts"]) + (run_prism_pts_bonus if str(pc["id"]) == "SPEC_PRISM" else 0)

# Side effect on play (lines 10752-10754):
		"SPEC_PRISM":
			run_prism_pts_bonus += 4
			card["pts"] = int(card.get("pts", 22)) + 4
```

---

### 1.2 `REL_PRISM_ORB` — Guild Astral Seal / Cechovní krystal

#### Original `scripts/lialo_catalog.gd` Entry (`RELICS`)
```gdscript
	{
		"id": "REL_PRISM_ORB", "name": "Guild Astral Seal", "name_cs": "Cechovní krystal", "icon": "Prism", "cost": 30,
		"category": "X-Mult", "category_cs": "×Násobič", "col": Color(0.95, 0.52, 0.94),
		"desc": "Each Class card (Mage/Knight/Merchant/Thief) adds ×1.25!",
		"desc_cs": "Každá speciální třída (Mág, Rytíř, Kupec, Zloděj) přidá ×1.25!"
	},
```

#### Original `scripts/scoring_engine.gd` Branch (`calculate_hand_score`)
```gdscript
			if "REL_PRISM_ORB" in active_relics and ed_card_count > 0:
				var p_x := pow(1.25, float(ed_card_count))
				x_mult_product *= p_x
				steps.append(_make_step("relic", "×%.2f Seal" % p_x, "Guild Astral Seal (%d Cls)" % ed_card_count, 0, 0.0, p_x, chips, flat_mult, x_mult_product, Color(0.95, 0.52, 0.94), "REL_PRISM_ORB", true))
```

---

## 2. Temporarily Hidden Relics (`REL_CHAMOIS`, `REL_STORMCAP`)

`REL_CHAMOIS` (**Chamois Horn / Kamzičí roh**) and `REL_STORMCAP` (**Storm Capacitor / Bouřková cívka**) remain defined in `LialoCatalog.RELICS` and their scoring branches remain intact in `ScoringEngine.calculate_hand_score()`, but they are temporarily hidden from:
- Default starter profile (`LialoCatalog.get_default_profile()`)
- Loaded legacy save profiles (`LialoCatalog.sanitize_profile()` / `LialoCatalog.load_profile()`)
- Shop offer generation (`LialoCatalog.generate_shop_offers()` and `LialoCatalog.get_visible_relics()`)
- Quick Showcase loadout (`downpour_root.gd` -> `_build_roguelite_loadout_for_era()`)
- Arsenal & Card Collection view (`downpour_root.gd` -> `_rebuild_collection_view()`)
- LIALO Grimoire / Almanac view (`downpour_root.gd` -> `_rebuild_almanac_ui()`)
- Map HUD active relic row (`downpour_root.gd` -> `_refresh_map_roguelite_hud()`)

### Preserved Definitions & Assets
- **`REL_CHAMOIS`**:
  - 2D Icon: `res://assets/relics/REL_CHAMOIS.png`
  - 3D Model: `res://assets/models/relics/REL_CHAMOIS.glb`
  - Effect: `+25 Chips whenever a Clubs (♣) or Power Card scores.`
- **`REL_STORMCAP`**:
  - 2D Icon: `res://assets/relics/REL_STORMCAP.png`
  - 3D Model: `res://assets/models/relics/REL_STORMCAP.glb`
  - Effect: `+3.5 Flat Mult & Lightning on every Pair+ Slam.`

### How to Unhide `REL_CHAMOIS` and/or `REL_STORMCAP` Later

1. Open `scripts/lialo_catalog.gd`.
2. Edit the single feature-flag constant `TEMPORARILY_HIDDEN_RELICS`:
   ```gdscript
   # Currently hidden:
   const TEMPORARILY_HIDDEN_RELICS: Array[String] = ["REL_CHAMOIS", "REL_STORMCAP"]

   # To unhide both:
   const TEMPORARILY_HIDDEN_RELICS: Array[String] = []
   ```
3. (Optional) If you want them back in the starter profile (`get_default_profile()`) or Quick Showcase (`downpour_root.gd` -> `_build_roguelite_loadout_for_era()`), add `"REL_CHAMOIS"` / `"REL_STORMCAP"` back to `active_relics` / `q_rel`.
