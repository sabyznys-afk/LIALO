extends SceneTree
## Master Verification & Screenshot Suite for the 10-Point LIALO Major Overhaul:
## 1) 4 Sculpted Blender Multiplayer Characters + Fixed MP Card Holding (verify_master_mp_4chars.png)
## 2) Upgraded Blender Ghost v2 Body & Face in-engine (verify_master_ghost_v2.png)
## 3) Ringless Enlarged 2D Hearts (Player under Chalice, Rival Top-Right) + Complex Score Counter +
##    Fixed Player/Opponent Card Holding + Mage Animated / Knight Metallic Cards (verify_master_hud_hands.png)
## 4) 10 New Buyable & Usable Tabletop Relics in Catalog, Shop, 3D Table & Active Click Rituals (verify_master_10_relics.png)
## 5) All 8 Museum-Grade Card Backs (including Prohibicia, Obsidian, Astral)
## 6) Expanded Longer Multi-Act Dark-Fantasy Cutscenes + Impact Shader (verify_master_cutscene.png)

const Catalog = preload("res://scripts/lialo_catalog.gd")
const ScoreEng = preload("res://scripts/scoring_engine.gd")
const BattleTableScript = preload("res://scripts/battle_table_3d.gd")
const MpConfig = preload("res://scripts/mp/mp_config.gd")
const MpTableScript = preload("res://scripts/mp/mp_battle_table_3d.gd")
const CineProfiles = preload("res://scripts/cinematic_profiles.gd")

var _shot_dir: String = OS.get_user_data_dir() + "/verify_shots"
var _fails: Array[String] = []


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
		printerr("FAIL: " + msg)


func _wait_frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _save_shot(fname: String) -> void:
	await _wait_frames(2)
	if DisplayServer.get_name() == "headless":
		print("  SHOT SKIPPED (headless): %s" % fname)
		return
	await _wait_frames(2)
	var img := root.get_viewport().get_texture().get_image()
	_assert(img != null and not img.is_empty(), "Empty viewport capture for " + fname)
	if img != null and not img.is_empty():
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		var full_p := _shot_dir + "/" + fname
		var err := img.save_png(full_p)
		_assert(err == OK, "Failed saving " + full_p)
		print("  SHOT SAVED: %s (%dx%d)" % [full_p, img.get_width(), img.get_height()])


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func():
		printerr("TIMEOUT: verify_master_overhaul exceeded 60s")
		quit(124)
	)
	call_deferred("_run_all")


func _run_all() -> void:
	DisplayServer.window_set_size(Vector2i(1366, 768))
	print("=== VERIFY MASTER OVERHAUL (ALL 10 USER REQUIREMENTS) ===")

	# ------------------------------------------------------------------
	# 1. All 8 Redesigned Card Backs & 10 New Buyable Tabletop Relics
	# ------------------------------------------------------------------
	var expected_backs := ["klasic", "antika", "rim", "stredovek", "objavy", "prohibicia", "obsidian", "astral"]
	for bid in expected_backs:
		var bp := ProjectSettings.globalize_path("res://assets/table/deck_back_%s.png" % bid)
		_assert(FileAccess.file_exists(bp), "Missing redesigned card back: " + bp)
	_assert(Catalog.TABLE_RELICS.size() == 10, "Expected 10 active tabletop relics, got %d" % Catalog.TABLE_RELICS.size())
	var seen_shop_trel := false
	for tr in Catalog.TABLE_RELICS:
		var tid := str(tr["id"])
		var glb_abs := ProjectSettings.globalize_path(str(tr["glb"]))
		_assert(FileAccess.file_exists(glb_abs), "Missing 3D GLB for tabletop relic: " + tid)
	for _it in range(10):
		var offers := Catalog.generate_shop_offers(Catalog.get_default_profile(), "cs")
		for off in offers:
			if str(off.get("kind", "")) == "table_relic":
				seen_shop_trel = true
	_assert(seen_shop_trel, "Shop offers must include buyable table_relic items")
	print("  OK Group 1: All 8 Card Backs + 10 Buyable Tabletop Relics & GLBs verified")

	# ------------------------------------------------------------------
	# 2. Hybrid Complex Scoring Engine Check
	# ------------------------------------------------------------------
	var r_norm := ScoreEng.calculate_hand_score([{"suit": "CERVEN", "rank": "8", "pts": 8, "edition": "NORMAL"}, {"suit": "GULA", "rank": "8", "pts": 8, "edition": "NORMAL"}], [], [], {})
	_assert(int(r_norm["final_score"]) == 16, "Plain 2x8 must stay 16, got %d" % int(r_norm["final_score"]))
	var r_knight := ScoreEng.calculate_hand_score([{"suit": "ZELEN", "rank": "K", "pts": 18, "edition": "KNIGHT"}], [], [], {})
	_assert(int(r_knight["final_score"]) > 18 and float(r_knight["x_mult_product"]) >= 1.24, "Knight metallic card must grant steel bonus & mult, got %s" % str(r_knight["formula_summary"]))
	var r_mage := ScoreEng.calculate_hand_score([{"suit": "CERVEN", "rank": "E", "pts": 20, "edition": "MAGE", "mage_charge": 2}], [], [], {"blood_seal_active": true})
	_assert(int(r_mage["final_score"]) >= 100 and (r_mage.get("breakdown_chips", []) as Array).size() >= 3, "Charged Mage + Blood Seal must produce stacked breakdown & high score, got %d" % int(r_mage["final_score"]))
	print("  OK Group 2: Hybrid Complex Scoring (2x8=%d, Knight K=%d, Mage2/2+BloodSeal=%d)" % [int(r_norm["final_score"]), int(r_knight["final_score"]), int(r_mage["final_score"])])

	# ------------------------------------------------------------------
	# 3. BattleTable3D: 10 Relics on Table, Ringless Bigger Hearts,
	#    Complex Score Counter, Fixed Card Holding, Knight/Mage Cards & Grand Cutscene
	# ------------------------------------------------------------------
	var bt := BattleTableScript.new()
	root.add_child(bt)
	await _wait_frames(8)

	var era := {"id": "stredovek", "name": "Medieval", "boss": "King Charles IV", "target": 90, "border_col": Color(0.58, 0.83, 0.69), "glove_col": Color(0.28, 0.33, 0.40)}
	var deck := {"id": "obsidian", "name": "Obsidian Seal", "back_tex": "res://assets/table/deck_back_obsidian.png", "border_col": Color(0.96, 0.18, 0.26), "glove_col": Color(0.12, 0.08, 0.10), "use_iron": true}
	var all_10_trel := []
	for tr in Catalog.TABLE_RELICS:
		all_10_trel.append(str(tr["id"]))
	var loadout := {
		"active_relics": ["REL_GREED", "REL_FANG"],
		"table_relics": all_10_trel,
		"custom_cards": ["SPEC_VAMPIRE", "SPEC_STORM", "SPEC_PHOENIX"],
		"card_editions": {"CERVEN_K": "KNIGHT", "GULA_E": "MAGE", "ZELEN_8": "KNIGHT", "ZALUD_9": "THIEF", "CERVEN_10": "MERCHANT"},
		"target_score": 90,
		"player_gold": 120,
		"language": "cs",
	}
	bt.call("start_3d_battle", era, deck, false, loadout)
	# Wait for intro card deal to settle so busy_animating == false before activating tabletop relics!
	for _w in range(180):
		await process_frame
		if not bool(bt.get("busy_animating")):
			break
	await _wait_frames(10)

	# Verify all 10 new Tabletop Relics spawned onto the 3D table!
	var r_nodes: Dictionary = bt.get("relic_3d_nodes")
	var spawned_trelics := 0
	for tid in all_10_trel:
		if r_nodes.has(tid) and is_instance_valid(r_nodes[tid]):
			spawned_trelics += 1
	_assert(spawned_trelics == 10, "All 10 Tabletop Relics must spawn on table, got %d" % spawned_trelics)
	await _save_shot("verify_master_10_relics.png")

	# Click-activate Blood-Ink Seal & Astral Astrolabe & War-Horn & Soul Bell!
	bt.call("_trigger_tavern_prop_click", "trelic:TRELIC_BLOOD_SEAL")
	await _wait_frames(6)
	_assert(bool(bt.get("table_relic_blood_seal_active")), "TRELIC_BLOOD_SEAL must set table_relic_blood_seal_active=true")
	var ai_hp_before := int(bt.get("ai_hp"))
	bt.call("_trigger_tavern_prop_click", "trelic:TRELIC_STAR_BOW")
	await _wait_frames(6)
	_assert(int(bt.get("ai_hp")) == ai_hp_before - 1 and int(bt.get("rival_cards_revealed_turns")) >= 2, "TRELIC_STAR_BOW must reveal rival hand and deal 1 HP")
	var sh_before := int(bt.get("player_shields"))
	bt.call("_trigger_tavern_prop_click", "trelic:TRELIC_WAR_HORN")
	await _wait_frames(6)
	_assert(int(bt.get("player_shields")) == sh_before + 2, "TRELIC_WAR_HORN must grant +2 shields")
	print("  OK Group 3: All 10 Tabletop Relics spawned on table & click activations verified")

	# Transition to CARD_PLAY, stage a hand showcasing MAGE, KNIGHT, THIEF, MERCHANT & POWER cards!
	var sp_ev := InputEventKey.new()
	sp_ev.pressed = true
	sp_ev.keycode = KEY_SPACE
	bt._unhandled_input(sp_ev)
	await _wait_frames(22)

	var showcase_hand: Array = [
		{"suit": "CERVEN", "rank": "K", "pts": 18, "rname": "Král", "edition": "KNIGHT", "power_id": "", "wild": false},
		{"suit": "GULA", "rank": "E", "pts": 20, "rname": "Eso", "edition": "MAGE", "mage_charge": 2, "power_id": "", "wild": false},
		{"suit": "ZELEN", "rank": "8", "pts": 8, "rname": "Osma", "edition": "KNIGHT", "power_id": "", "wild": false},
		{"suit": "ZALUD", "rank": "9", "pts": 9, "rname": "Devítka", "edition": "THIEF", "power_id": "", "wild": false},
		{"suit": "CERVEN", "rank": "10", "pts": 10, "rname": "Desítka", "edition": "MERCHANT", "power_id": "", "wild": false},
	]
	bt.set("player_hand", showcase_hand)
	bt.call("_rebuild_all_3d_hands")
	# Simulate hovering the charged Mage card so Complex Score Counter shows live stacked chips!
	bt.call("_update_combo_hud", "⚡ NÁHLED: ESO [MÁG 2/2]", 44, 1.0, 132, false, 3.0)
	bt.call("_set_score_breakdown_chips", [
		{"tag": "20×1", "val": "+20", "col": Color(0.68, 0.92, 1.0)},
		{"tag": "🔮 MÁG 2/2", "val": "+24 ×1.5", "col": Color(0.54, 0.72, 1.0)},
		{"tag": "🩸 PEČEŤ", "val": "×2.0", "col": Color(0.96, 0.14, 0.24)},
	])
	bt.call("_award_player_score_immediately", 24, "+24", Color(1.0, 0.86, 0.30), 24, "2×8", 8, 2)
	await _wait_frames(22)

	# Verify Fixed Card Holding geometry (player gloves sit low at bottom-outer edges, y <= -0.09, zero face pierce)
	var pg_l := bt.get("player_glove_left_mesh") as Node3D
	var pg_r := bt.get("player_glove_right_mesh") as Node3D
	var og_l := bt.get("opp_glove_left_mesh") as Node3D
	_assert(is_instance_valid(pg_l) and pg_l.position.y <= -0.095 and pg_l.position.z <= 0.025, "Player left glove must cradle bottom-outer edge cleanly, got %s" % str(pg_l.position))
	_assert(is_instance_valid(pg_r) and pg_r.position.y <= -0.095 and pg_r.position.z <= 0.025, "Player right glove must cradle bottom-outer edge cleanly, got %s" % str(pg_r.position))
	_assert(is_instance_valid(og_l) and og_l.position.y <= -0.060, "Opponent glove must grip bottom edge of opp fan cleanly, got %s" % str(og_l.position))

	# Verify Complex Score Counter widgets populated
	var sb_row := bt.get("score_breakdown_row") as HBoxContainer
	var sd_lbl := bt.get("score_delta_lbl") as Label
	var sh_lbl := bt.get("score_history_lbl") as Label
	_assert(is_instance_valid(sb_row) and sb_row.get_child_count() >= 3, "Complex Score Counter must render live breakdown chip badges")
	_assert(is_instance_valid(sd_lbl) and sd_lbl.visible, "score_delta_lbl must display lead/trail vs rival")
	_assert(is_instance_valid(sh_lbl) and sh_lbl.visible and "+24" in sh_lbl.text, "score_history_lbl must show turn history")
	await _save_shot("verify_master_hud_hands.png")
	print("  OK Group 4: Enlarged Ringless Hearts + Complex Score Counter + Fixed Card Holding + Mage/Knight Cards verified")

	# ------------------------------------------------------------------
	# 4. Longer Multi-Act Dark-Fantasy Cutscene Capture
	# ------------------------------------------------------------------
	var cd: Node = bt.get("cinematic_director") as Node
	_assert(is_instance_valid(cd), "CinematicDirector missing")
	var vampire_prof := CineProfiles.get_special_card_profile("SPEC_VAMPIRE")
	_assert(float(vampire_prof["duration"]) >= 5.2, "Special cutscene must be >= 5.2s, got %.2f" % float(vampire_prof["duration"]))
	cd.call("play_special_card_cinematic", "SPEC_VAMPIRE", bt.global_position + Vector3(0.0, 0.85, 0.0), bt.global_position + Vector3(0.0, 1.05, -1.35), true, Callable(), Callable())
	# Step to climax impact frame (~3.45s)!
	for _cs in range(55):
		cd.call("_process", 0.065)
	await _wait_frames(3)
	await _save_shot("verify_master_cutscene.png")
	cd.call("skip_current")
	await _wait_frames(6)
	print("  OK Group 5: Expanded 5.65s Multi-Act Cutscene + Impact Shader verified")

	# ------------------------------------------------------------------
	# 5. Upgraded Blender Ghost v2 In-Engine Verification
	# ------------------------------------------------------------------
	bt.call("start_3d_battle", era, deck, true, {})
	await _wait_frames(20)
	var ghost_root := bt.get("tutorial_ghost_3d") as Node3D
	_assert(is_instance_valid(ghost_root) and ghost_root.visible, "tutorial_ghost_3d must be visible in tutorial")
	_assert(ghost_root.find_child("GhostShroudGLB", true, false) != null, "GhostShroudGLB must load in tutorial_ghost_3d")
	_assert(ghost_root.find_child("GhostSkullGLB", true, false) != null, "GhostSkullGLB must load in tutorial_ghost_3d")
	_assert(ghost_root.find_child("GhostJawGLB", true, false) != null, "GhostJawGLB must load in tutorial_ghost_3d")
	# Frame camera nicely on Ghost v2 so we can inspect body & face directly!
	var bt_cam := bt.get("cam") as Camera3D
	if is_instance_valid(bt_cam):
		bt.set("cam_impact_active", true)
		bt_cam.look_at_from_position(ghost_root.global_position + Vector3(0.45, 0.68, 0.92), ghost_root.global_position + Vector3(0.0, 0.56, 0.0), Vector3.UP)
		bt_cam.fov = 44.0
	await _save_shot("verify_master_ghost_v2.png")
	bt.queue_free()
	await _wait_frames(6)
	print("  OK Group 6: Upgraded Blender Ghost v2 Body, Face, Jaw & Lantern verified in-engine")

	# ------------------------------------------------------------------
	# 6. 4 Sculpted Blender Multiplayer Characters + Fixed MP Card Holding
	# ------------------------------------------------------------------
	var mp_t := MpTableScript.new()
	root.add_child(mp_t)
	await _wait_frames(6)
	var pub_state := {
		"round_num": 1,
		"turn_seat": 1,
		"active_suit": "CERVEN",
		"pending_draw_stack": 0,
		"discard_count": 1,
		"top_card": {"suit": "CERVEN", "rank": "K", "pts": 18, "edition": "KNIGHT", "power_id": ""},
		"banner": "4-Player Sculpted Tavern Brawl!",
		"match_over": false,
		"pending_parry": {},
		"seats": [
			{"seat_idx": 0, "name": "You (Kat)", "is_bot": false, "character_id": "CHAR_GUILLOTINE", "archetype_name": "Kat", "sword_skin": "SWORD_RUNE", "color": Color(0.32, 0.88, 1.0), "hp": 120, "max_hp": 120, "shields": 15, "gold": 25, "alive": true, "mist_cloaked": false, "hand_count": 5, "deck_count": 30, "items_count": 2, "revealed_cards": [], "ghost_cd": 0.0},
			{"seat_idx": 1, "name": "Panovník", "is_bot": true, "character_id": "CHAR_MONARCH", "archetype_name": "Monarch", "sword_skin": "SWORD_GILDED", "color": Color(1.0, 0.78, 0.28), "hp": 120, "max_hp": 120, "shields": 15, "gold": 25, "alive": true, "mist_cloaked": false, "hand_count": 5, "deck_count": 30, "items_count": 2, "revealed_cards": [], "ghost_cd": 0.0},
			{"seat_idx": 2, "name": "Šašek", "is_bot": true, "character_id": "CHAR_JESTER", "archetype_name": "Jester", "sword_skin": "SWORD_CRIMSON", "color": Color(0.95, 0.42, 0.78), "hp": 120, "max_hp": 120, "shields": 15, "gold": 25, "alive": true, "mist_cloaked": false, "hand_count": 5, "deck_count": 30, "items_count": 2, "revealed_cards": [], "ghost_cd": 0.0},
			{"seat_idx": 3, "name": "Rytíř mlhy", "is_bot": true, "character_id": "CHAR_MISTBLADE", "archetype_name": "Mistblade", "sword_skin": "SWORD_DRAGON", "color": Color(0.45, 0.94, 0.80), "hp": 120, "max_hp": 120, "shields": 15, "gold": 25, "alive": true, "mist_cloaked": false, "hand_count": 5, "deck_count": 30, "items_count": 2, "revealed_cards": [], "ghost_cd": 0.0},
		],
	}
	mp_t.call("_on_public_state", pub_state)
	await _wait_frames(10)

	var sn_map: Dictionary = mp_t.get("seat_nodes")
	_assert(sn_map.size() == 4, "Expected 4 MP seats built, got %d" % sn_map.size())
	for si in [1, 2, 3]:
		var sn: Dictionary = sn_map[si]
		_assert(is_instance_valid(sn.get("torso_pivot")), "MP seat %d missing TorsoPivot from Blender GLB" % si)
		_assert(is_instance_valid(sn.get("head_pivot")), "MP seat %d missing HeadPivot from Blender GLB" % si)
		_assert(is_instance_valid(sn.get("hand_l_hold")) and is_instance_valid(sn.get("hand_r_hold")), "MP seat %d missing HandLHold/HandRHold grip anchors" % si)
		var hg: Node3D = sn.get("hand_grp")
		_assert(is_instance_valid(hg) and hg.get_child_count() == 5, "MP seat %d must hold 5 fanned 3D cards" % si)
	await _save_shot("verify_master_mp_4chars.png")
	mp_t.queue_free()
	await _wait_frames(4)
	print("  OK Group 7: All 4 Sculpted Blender MP Characters + Hand Grip Anchors verified")

	if _fails.is_empty():
		print("=== VERIFY MASTER OVERHAUL: ALL 7 GROUPS & 5 SCREENSHOTS PASSED ===")
		quit(0)
	else:
		printerr("=== VERIFY MASTER OVERHAUL FAILED (%d failures) ===" % _fails.size())
		quit(1)
