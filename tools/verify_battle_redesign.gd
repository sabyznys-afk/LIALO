extends SceneTree

const BattleTableScript = preload("res://scripts/battle_table_3d.gd")
const MpBattleTableScript = preload("res://scripts/mp/mp_battle_table_3d.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _assert_true(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): printerr("TIMEOUT: verify_battle_redesign exceeded 60s"); quit(124))
	call_deferred("_run_verification")


func _run_verification() -> void:
	print("=== VERIFY BATTLE REDESIGN (Tasks #3, #4, #6, #7, #8, #9) ===")

	# 1. Script compilation sanity (both single-player and multiplayer battle tables)
	_assert_true(BattleTableScript != null, "battle_table_3d.gd failed to preload/compile")
	_assert_true(MpBattleTableScript != null, "mp_battle_table_3d.gd failed to preload/compile")
	if BattleTableScript == null:
		quit(1)
		return

	var mp_inst: Node = MpBattleTableScript.new()
	_assert_true(mp_inst != null, "MpBattleTable3D failed to instantiate")
	if is_instance_valid(mp_inst):
		mp_inst.free()

	# 2. Instantiate BattleTable3D inside SceneTree
	var bt: Node3D = BattleTableScript.new()
	bt.name = "BattleTable3D_Verify"
	root.add_child(bt)
	await process_frame
	await process_frame

	# 2a. Verify Task #6 Prism cleanup in battle_table_3d.gd
	_assert_true(not ("run_prism_pts_bonus" in bt), "Legacy run_prism_pts_bonus still exists on BattleTable3D")

	# 2b. Verify Task #4 HeartbeatHpDisplay mounted & legacy 2D HP bars removed
	var p_heart: Variant = bt.get("player_hp_heart")
	var r_heart: Variant = bt.get("rival_hp_heart")
	_assert_true(p_heart != null and is_instance_valid(p_heart), "player_hp_heart not mounted")
	_assert_true(r_heart != null and is_instance_valid(r_heart), "rival_hp_heart not mounted")
	_assert_true(bt.get("player_hp_pill") == null, "Legacy player_hp_pill should be null")
	_assert_true(bt.get("player_hp_lbl") == null, "Legacy player_hp_lbl should be null")
	_assert_true(bt.get("ai_hp_lbl") == null, "Legacy ai_hp_lbl should be null")

	# 2c. Verify Task #7 Betting window removed & compact indicator + standalone Veto pill present
	_assert_true(bt.get("wager_bar_panel") == null, "Old 5-button wager_bar_panel must be removed (null)")
	_assert_true(bt.get("wager_gold_btn") == null, "Old wager_gold_btn must be null")
	_assert_true(bt.get("wager_item_btn") == null, "Old wager_item_btn must be null")
	_assert_true(bt.get("wager_sword_btn") == null, "Old wager_sword_btn must be null")
	_assert_true(is_instance_valid(bt.get("wager_indicator_pill")), "wager_indicator_pill missing")
	_assert_true(is_instance_valid(bt.get("wager_indicator_lbl")), "wager_indicator_lbl missing")
	_assert_true(is_instance_valid(bt.get("veto_standalone_panel")), "veto_standalone_panel missing")
	_assert_true(is_instance_valid(bt.get("wager_veto_hand_btn")), "wager_veto_hand_btn missing")
	_assert_true(is_instance_valid(bt.get("wager_veto_duel_btn")), "wager_veto_duel_btn missing")

	# 2d. Verify Task #8 View toggle button & Task #9 CinematicDirector mounted
	_assert_true(is_instance_valid(bt.get("view_toggle_btn")), "view_toggle_btn missing")
	var cd: Variant = bt.get("cinematic_director")
	_assert_true(cd != null and is_instance_valid(cd), "cinematic_director not mounted")

	# 3. Verify all 5 Eras + Boss stage via start_3d_battle()
	var eras := [
		{"id": "antika", "boss": "High Scribe", "border_col": Color(0.95, 0.78, 0.25), "glove_col": Color(0.55, 0.38, 0.22)},
		{"id": "rim", "boss": "Arena Centurion", "border_col": Color(0.88, 0.24, 0.20), "glove_col": Color(0.45, 0.22, 0.18)},
		{"id": "stredovek", "boss": "Iron Knight", "border_col": Color(0.76, 0.62, 0.30), "glove_col": Color(0.35, 0.26, 0.20)},
		{"id": "objavy", "boss": "Sea Corsair", "border_col": Color(0.24, 0.68, 0.78), "glove_col": Color(0.22, 0.30, 0.36)},
		{"id": "prohibicia", "boss": "Syndicate Don", "border_col": Color(0.82, 0.22, 0.28), "glove_col": Color(0.18, 0.16, 0.20)},
	]
	var test_deck := {"name": "Traveler's Deck", "use_iron": false, "glove_col": Color(0.45, 0.30, 0.18), "border_col": Color(0.85, 0.68, 0.26)}

	for ei in range(eras.size()):
		var era_d: Dictionary = eras[ei]
		var is_boss_case := (ei == eras.size() - 1)
		var loadout := {
			"player_gold": 120,
			"wager_type": "GOLD",
			"campaign_difficulty": "traveler",
			"stage_data": {
				"stage_idx": 2 if is_boss_case else 0,
				"stage_name": "Boss Stage (BOSS)" if is_boss_case else "Stage 1",
			},
		}
		bt.call("start_3d_battle", era_d, test_deck, false, loadout)
		await process_frame

		var eid := str(era_d["id"])
		var torso: Variant = bt.get("opp_torso_node")
		var head: Variant = bt.get("opp_head_node")
		var arm_l: Variant = bt.get("opp_arm_left_node")
		var arm_r: Variant = bt.get("opp_arm_right_node")
		var eyes: Variant = bt.get("opp_eye_nodes")
		_assert_true(torso != null and is_instance_valid(torso), "[%s] opp_torso_node (TorsoPivot) missing" % eid)
		_assert_true(head != null and is_instance_valid(head), "[%s] opp_head_node (HeadPivot) missing" % eid)
		_assert_true(arm_l != null and is_instance_valid(arm_l), "[%s] opp_arm_left_node (ArmLPivot) missing" % eid)
		_assert_true(arm_r != null and is_instance_valid(arm_r), "[%s] opp_arm_right_node (ArmRPivot) missing" % eid)
		_assert_true(eyes is Array and (eyes as Array).size() >= 2, "[%s] opp_eye_nodes must contain EyeL & EyeR" % eid)

		# Verify boss heart mode matches stage
		var r_boss_flag := bool(r_heart.get("_is_boss"))
		_assert_true(r_boss_flag == is_boss_case, "[%s] rival_hp_heart _is_boss expected %s got %s" % [eid, str(is_boss_case), str(r_boss_flag)])
		print("  OK era=%s boss=%s pivots=bound" % [eid, str(is_boss_case)])

	# Finish intro animation state for gameplay UI/interaction checks
	bt.set("intro_animating", false)
	bt.set("busy_animating", false)
	bt.set("is_player_turn", true)
	bt.set("opening_turn_committed", false)
	bt.set("current_round_num", 1)
	bt.call("_sync_peek_ui_visibility")
	await process_frame

	# 4. Verify Task #7 Compact Wager Indicator (hidden in Campaign SP v0.193) + Standalone Veto Pill + 3D Table Prop Wager Selection
	var veto_p: Control = bt.get("veto_standalone_panel")
	var wager_p: Control = bt.get("wager_indicator_pill")
	_assert_true(veto_p.visible, "veto_standalone_panel must be visible before Turn 1")
	_assert_true(not wager_p.visible, "wager_indicator_pill must stay hidden in Campaign SP (v0.193)")

	bt.call("_trigger_tavern_prop_click", "phial")
	_assert_true(str(bt.get("active_wager_type")) == "ITEM", "Clicking phial before Turn 1 should select ITEM wager")
	bt.call("_trigger_tavern_prop_click", "sword")
	_assert_true(str(bt.get("active_wager_type")) == "SWORD", "Clicking sword before Turn 1 should select SWORD wager")
	bt.call("_trigger_tavern_prop_click", "coins")
	_assert_true(str(bt.get("active_wager_type")) == "GOLD", "Clicking coins before Turn 1 should select GOLD wager")
	bt.call("_cycle_opening_wager")
	_assert_true(str(bt.get("active_wager_type")) == "ITEM", "Clicking wager_indicator_pill should cycle GOLD -> ITEM")
	print("  OK Task #7 wager indicator + 3D prop wager clicks + standalone Veto pill")

	# 5. Verify Task #4 HP Damage & Shield updates on HeartbeatHpDisplay
	bt.set("player_shields", 1)
	bt.call("_apply_hp_damage", true, 1, "Shield Test")
	_assert_true(int(bt.get("player_shields")) == 0, "Shield should block 1 HP damage")
	var hp_before := int(bt.get("player_hp"))
	bt.call("_apply_hp_damage", true, 2, "Damage Test")
	_assert_true(int(bt.get("player_hp")) == hp_before - 2, "Player HP should decrease by 2")
	var ai_hp_before := int(bt.get("ai_hp"))
	bt.call("_apply_hp_damage", false, 3, "Rival Damage Test")
	_assert_true(int(bt.get("ai_hp")) == ai_hp_before - 3, "Rival HP should decrease by 3")
	print("  OK Task #4 HeartbeatHpDisplay damage & shield updates")

	# 6. Verify Task #8 CameraViewMode CARDS <-> TABLE_ITEMS toggle
	bt.call("set_camera_view_mode", 0, false) # CARDS
	_assert_true(int(bt.get("cam_view_mode")) == 0 and not bool(bt.get("cards_tucked")), "CARDS mode should untuck hand")
	bt.call("toggle_camera_view_mode", false)
	_assert_true(int(bt.get("cam_view_mode")) == 1 and bool(bt.get("cards_tucked")), "toggle_camera_view_mode should enter TABLE_ITEMS & tuck hand")
	var vbtn: Button = bt.get("view_toggle_btn")
	_assert_true("Cards" in vbtn.text or "Karty" in vbtn.text, "view_toggle_btn text should prompt back to Cards in TABLE_ITEMS mode")
	bt.call("toggle_camera_view_mode", false)
	_assert_true(int(bt.get("cam_view_mode")) == 0 and not bool(bt.get("cards_tucked")), "Second toggle should return to CARDS mode")
	_assert_true("Items" in vbtn.text or "Itemy" in vbtn.text, "view_toggle_btn text should prompt Items in CARDS mode")
	print("  OK Task #8 CameraViewMode CARDS <-> TABLE_ITEMS toggle")

	# 7. Verify Task #9 Special Card Cinematic + skip_current() zero soft-lock!
	var pc := Catalog.get_power_card("SPEC_SHIELD")
	_assert_true(not pc.is_empty(), "Catalog.get_power_card('SPEC_SHIELD') returned empty")
	var shield_card := {
		"suit": pc["suit"],
		"rank": "PWR",
		"pts": pc["pts"],
		"rname": pc["name"],
		"short": pc["short"],
		"power_id": pc["id"],
		"wild": true,
		"accent": pc["accent"],
		"power_line": pc["power_line"],
		"desc": pc["desc"],
		"edition": "NORMAL",
	}
	var p_hand: Array = bt.get("player_hand")
	p_hand.insert(0, shield_card)
	bt.call("_rebuild_all_3d_hands")
	await process_frame

	var shields_before_spec := int(bt.get("player_shields"))
	bt.call("_play_player_cards_3d", [0], str(shield_card.get("suit", "CERVEN")))
	await process_frame
	_assert_true(bool(cd.call("is_playing")), "CinematicDirector must be playing immediately after SPEC_SHIELD play")
	_assert_true(int(bt.get("cam_view_mode")) == 2, "cam_view_mode must be CINEMATIC (2) while special card cutscene plays")
	_assert_true(not veto_p.visible, "veto_standalone_panel must hide once Turn 1 is committed / cinematic active")

	# Skip mid-cutscene and verify on_impact fired (+2 shields) and camera unlocked cleanly
	cd.call("skip_current")
	await process_frame
	_assert_true(not bool(cd.call("is_playing")), "CinematicDirector must stop playing after skip_current()")
	_assert_true(int(bt.get("cam_view_mode")) != 2, "cam_view_mode must exit CINEMATIC after skip_current()")
	_assert_true(int(bt.get("player_shields")) >= shields_before_spec + 2, "SPEC_SHIELD on_impact must grant +2 shields even when skipped")
	print("  OK Task #9 Special Card (SPEC_SHIELD) Cinematic + skip_current() recovery")

	# Cancel pending stagger timeline cleanly before testing Opponent Turn cinematic
	bt.set("_stagger_seq_token", int(bt.get("_stagger_seq_token")) + 1)

	# 8. Verify Task #9 Opponent Turn Cinematic + skip_current() zero soft-lock!
	var a_hand: Array = bt.get("ai_hand")
	a_hand.insert(0, shield_card.duplicate())
	bt.set("busy_animating", true)
	bt.set("is_player_turn", false)
	var next_ai_seq := int(bt.get("_ai_turn_seq")) + 1
	bt.set("_ai_turn_seq", next_ai_seq)
	var discard_before := (bt.get("discard_pile") as Array).size()
	var ai_hand_before := (bt.get("ai_hand") as Array).size()
	bt.call("_execute_ai_turn_body", next_ai_seq)
	await process_frame
	_assert_true(bool(cd.call("is_playing")), "CinematicDirector must be playing during single-player Opponent Turn")
	_assert_true(int(bt.get("cam_view_mode")) == 2, "cam_view_mode must be CINEMATIC (2) during Opponent Turn cutscene")

	cd.call("skip_current")
	await process_frame
	_assert_true(not bool(cd.call("is_playing")), "CinematicDirector must stop playing after Opponent Turn skip_current()")
	_assert_true(int(bt.get("cam_view_mode")) != 2, "cam_view_mode must exit CINEMATIC after Opponent Turn skip_current()")
	var discard_after := (bt.get("discard_pile") as Array).size()
	var ai_hand_after := (bt.get("ai_hand") as Array).size()
	_assert_true(discard_after != discard_before or ai_hand_after != ai_hand_before, "Opponent Turn on_impact must execute play or draw even when skipped")
	print("  OK Task #9 Opponent Turn Cinematic + skip_current() recovery")

	# 9. Verify safe cancellation on set_active(false)
	var a_hand2: Array = bt.get("ai_hand")
	a_hand2.insert(0, shield_card.duplicate())
	var cancel_ai_seq := int(bt.get("_ai_turn_seq")) + 1
	bt.set("_ai_turn_seq", cancel_ai_seq)
	bt.call("_execute_ai_turn_body", cancel_ai_seq)
	await process_frame
	_assert_true(bool(cd.call("is_playing")), "CinematicDirector should be active before set_active(false) cancel test")
	bt.call("set_active", false)
	await process_frame
	_assert_true(not bool(cd.call("is_playing")), "set_active(false) must cleanly cancel active cinematic")
	print("  OK Safe cinematic cancellation on set_active(false)")

	bt.queue_free()
	await process_frame

	if _failures.is_empty():
		print("ALL VERIFY_BATTLE_REDESIGN CHECKS PASSED!")
		quit(0)
	else:
		printerr("VERIFY_BATTLE_REDESIGN FAILED WITH %d ERROR(S)." % _failures.size())
		quit(1)
