extends SceneTree

const DownpourRootScript = preload("res://scripts/downpour_root.gd")
const BattleTableScript = preload("res://scripts/battle_table_3d.gd")
const ScoreEng = preload("res://scripts/scoring_engine.gd")
const QuillScript = preload("res://scripts/handwriting_quill.gd")
const HeartbeatHpDisplayScript = preload("res://scripts/heartbeat_hp_display.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")

const SHOT_DIR := "C:/Users/arnos/.gemini/antigravity/brain/a20e3f18-d942-46fa-80e3-721c54108b6d/scratch"

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	call_deferred("_run_all")


func _wait_frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _save_shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := root
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		_fail("Viewport texture null when saving " + filename)
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		_fail("Viewport image empty when saving " + filename)
		return
	var full_p := "%s/%s" % [SHOT_DIR, filename]
	var err := img.save_png(full_p)
	_assert(err == OK, "Failed to save screenshot %s (err=%d)" % [full_p, err])
	print("  SHOT SAVED: %s (%dx%d)" % [full_p, img.get_width(), img.get_height()])


func _run_all() -> void:
	print("=== VERIFY GAMEPLAY OVERHAUL (TRACK A + TRACK B + 6 SCREENSHOTS) ===")
	root.size = Vector2i(1366, 768)

	# -------------------------------------------------------------------------
	# 1. Simplified Scoring Engine Verification (1x8=8 .. 4x8=32, 2xE=40)
	# -------------------------------------------------------------------------
	var eights: Array = []
	for i in range(4):
		eights.append({"suit": "CERVEN", "rank": "8", "pts": 8, "rname": "Eight", "edition": "NORMAL", "power_id": ""})
		var res := ScoreEng.calculate_hand_score(eights.slice(0, i + 1), ["REL_GREED"], [], {"lang": "en"})
		var expected := 8 * (i + 1)
		_assert(int(res.get("final_score", -1)) == expected, "Expected %dx8=%d, got %s" % [i + 1, expected, str(res.get("final_score", -1))])
		_assert(int(res.get("card_value", 0)) == 8, "Expected card_value=8")
		_assert(int(res.get("card_count", 0)) == i + 1, "Expected card_count=%d" % (i + 1))

	var two_aces := [
		{"suit": "CERVEN", "rank": "E", "pts": 20, "rname": "Ace", "edition": "NORMAL", "power_id": ""},
		{"suit": "ZELEN", "rank": "E", "pts": 20, "rname": "Ace", "edition": "NORMAL", "power_id": ""},
	]
	var ace_res := ScoreEng.calculate_hand_score(two_aces, [], [], {"lang": "en"})
	_assert(int(ace_res.get("final_score", -1)) == 40, "Expected 2xE=40, got %s" % str(ace_res.get("final_score", -1)))
	_assert(int(ace_res.get("ace_hp_damage", 0)) == 4, "Expected 2xE ace_hp_damage=4")
	print("  OK Group 1: Simplified Scoring (1x8=8, 2x8=16, 3x8=24, 4x8=32, 2xE=40)")

	# -------------------------------------------------------------------------
	# 2. Track A: LialoQuill Font + HandwritingQuill + Intro Mist + Settings Codex
	# -------------------------------------------------------------------------
	_assert(FileAccess.file_exists("res://assets/fonts/LialoQuill.ttf"), "Missing res://assets/fonts/LialoQuill.ttf")
	var dr: Node = DownpourRootScript.new()
	dr.name = "DownpourRoot_Verify"
	root.add_child(dr)
	await _wait_frames(4)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1366, 768)
	await _wait_frames(2)

	var fq: Variant = dr.call("_get_quill_font")
	var fb: Variant = dr.call("_get_font", false)
	_assert(fq != null and fq is Font, "DownpourRoot._get_quill_font() must return Font")
	_assert(fq != fb, "DownpourRoot._get_quill_font() must load LialoQuill.ttf rather than fallback font")

	# Splash alpine mist + audio focus readiness
	dr.call("_switch_to", DownpourRootScript.ScreenState.SPLASH)
	dr.set("splash_time", 2.05)
	await _wait_frames(3)
	var sp_sfx := dr.get("splash_sfx_player") as AudioStreamPlayer
	_assert(is_instance_valid(sp_sfx), "splash_sfx_player missing")
	_assert(sp_sfx.stream != null, "splash_sfx_player.stream should be assigned on SPLASH")
	await _save_shot("verify_intro_mist.png")

	# HandwritingQuill stroke SFX & progression
	var q: Control = QuillScript.new()
	root.add_child(q)
	q.call("setup", fq as Font, 26)
	var stroke_hits := [0]
	q.quill_stroke_sfx.connect(func(_p): stroke_hits[0] += 1)
	q.call("start_text", "First rule of the tavern: inspect your relics before drawing steel.", 38.0, "relaxed", true)
	for _s in range(12):
		q.call("step_anim", 0.05)
	_assert(stroke_hits[0] > 0, "HandwritingQuill did not emit quill_stroke_sfx")
	_assert(bool(q.call("is_busy")), "HandwritingQuill should still be writing mid-sentence")
	q.call("finish_immediately")
	_assert(not bool(q.call("is_busy")), "HandwritingQuill finish_immediately() did not finish")
	q.queue_free()

	# LobbyOptions3D open + LialoQuill / buttons / sliders
	var opt3d: Variant = dr.get("options_3d")
	_assert(is_instance_valid(opt3d), "options_3d missing on DownpourRoot")
	opt3d.call("open_3d")
	await _wait_frames(22)
	_assert(bool(opt3d.call("is_open")), "options_3d should be open")
	_assert(opt3d.call("get_station_button", "language") != null, "options_3d missing language button")
	_assert(opt3d.call("get_slider", "volume") != null, "options_3d missing volume slider")
	await _save_shot("verify_settings_codex.png")
	opt3d.call("close_3d")
	await _wait_frames(3)
	dr.queue_free()
	await _wait_frames(3)
	print("  OK Group 2: Track A (LialoQuill, HandwritingQuill, Intro Mist + Audio, Settings Codex)")

	# -------------------------------------------------------------------------
	# 3. BattleTable3D: Buckshot Turn Flow, Camera Look, Immediate AI Score & UI
	# -------------------------------------------------------------------------
	var bt: Node3D = BattleTableScript.new()
	bt.name = "BattleTable3D_OverhaulVerify"
	root.add_child(bt)
	await _wait_frames(3)

	var test_era := {"id": "stredovek", "boss": "Iron Knight", "border_col": Color(0.82, 0.64, 0.28), "glove_col": Color(0.35, 0.26, 0.20), "target": 90}
	var test_deck := {"name": "Traveler's Deck", "use_iron": false, "glove_col": Color(0.45, 0.30, 0.18), "border_col": Color(0.85, 0.68, 0.26)}
	var loadout := {
		"player_gold": 120,
		"wager_type": "GOLD",
		"campaign_difficulty": "traveler",
		"target_score": 90,
		"active_relics": ["REL_GREED", "REL_ALEMBIC"],
		"stage_data": {"stage_idx": 0, "stage_name": "Tavern Duel"},
	}
	bt.call("start_3d_battle", test_era, test_deck, false, loadout)
	bt.call("set_active", true)
	bt.set("intro_animating", false)
	bt.set("busy_animating", false)
	var intro_t := bt.get("intro_title_grp") as Control
	if is_instance_valid(intro_t):
		intro_t.visible = false
	bt.call("_begin_player_item_review_stage", false)
	await _wait_frames(18)

	# Assert Buckshot ITEM_REVIEW state at start of turn
	_assert(int(bt.get("turn_stage")) == 0, "Expected TurnStage.ITEM_REVIEW (0) at turn start, got %s" % str(bt.get("turn_stage")))
	_assert(int(bt.get("cam_view_mode")) == 1, "Expected CameraViewMode.TABLE_ITEMS (1) at turn start")
	_assert(bool(bt.get("cards_tucked")), "Hand cards must be tucked during ITEM_REVIEW")
	var ir_bar := bt.get("item_review_bar") as Control
	_assert(is_instance_valid(ir_bar) and ir_bar.visible, "item_review_bar must be visible during ITEM_REVIEW")
	var opp_items := bt.get("opp_table_items_root") as Node3D
	_assert(is_instance_valid(opp_items) and opp_items.visible, "opp_table_items_root must be visible in duel")
	await _save_shot("verify_buckshot_item_review.png")

	# Press KEY_SPACE to transition from ITEM_REVIEW -> CARD_PLAY
	var sp_ev := InputEventKey.new()
	sp_ev.pressed = true
	sp_ev.keycode = KEY_SPACE
	bt._unhandled_input(sp_ev)
	await _wait_frames(28)

	_assert(int(bt.get("turn_stage")) == 1, "KEY_SPACE must advance to TurnStage.CARD_PLAY (1)")
	_assert(int(bt.get("cam_view_mode")) == 0, "KEY_SPACE must transition camera to CARDS (0)")
	_assert(not bool(bt.get("cards_tucked")), "Hand cards must untuck after KEY_SPACE")
	_assert(not ir_bar.visible, "item_review_bar must hide after confirming ITEM_REVIEW")
	print("  OK Group 3: Buckshot Turn Flow (ITEM_REVIEW -> KEY_SPACE -> CARD_PLAY)")

	# Assert Bare Larger Ringless 2D Hearts (Player Top-Left under Chalice, Rival Top-Right) + YOUR TURN bottom-left
	var p_heart := bt.get("player_hp_heart") as Control
	var r_heart := bt.get("rival_hp_heart") as Control
	var r_hud := bt.get("rival_hud_grp") as Control
	var turn_grp := bt.get("turn_banner_grp") as Control
	var turn_lbl := bt.get("turn_banner_lbl") as Label
	var bl_pill := bt.get("bottom_left_status_pill") as Control
	var carry_pill := bt.get("carry_out_pill") as Control
	_assert(is_instance_valid(p_heart) and p_heart.visible, "player_hp_heart must be visible")
	_assert(is_instance_valid(r_heart) and r_heart.visible, "rival_hp_heart must be visible")
	_assert(p_heart.call("get_heart_instance") == null, "player_hp_heart must not expose legacy 3D Node3D")
	_assert(p_heart.call("get_heart_texture_rect") is TextureRect, "player_hp_heart must use 2D TextureRect")
	var vp_rect := root.get_visible_rect().size
	_assert(p_heart.size.x >= 140.0 and r_heart.size.x >= 140.0, "Hearts must be enlarged (>=140px), got p=%s r=%s" % [str(p_heart.size), str(r_heart.size)])
	_assert(p_heart.position.x < 80.0 and p_heart.position.y >= 165.0 and p_heart.position.y < 260.0, "player_hp_heart must sit top-left directly under Chalice (pos=%s)" % str(p_heart.position))
	_assert(r_heart.global_position.x > vp_rect.x - 200.0 and r_heart.position.y < 32.0, "rival_hp_heart must sit in top-right corner (pos=%s, vp=%s)" % [str(r_heart.global_position), str(vp_rect)])
	if is_instance_valid(r_hud) and r_hud.visible:
		_assert(not r_heart.get_global_rect().intersects(r_hud.get_global_rect()), "rival_hp_heart overlaps rival_hud_grp")
	_assert(is_instance_valid(turn_grp) and turn_grp.visible, "turn_banner_grp must be visible during YOUR TURN")
	_assert("YOUR TURN" in turn_lbl.text or "TVŮJ TAH" in turn_lbl.text, "Expected prominent YOUR TURN text, got '%s'" % turn_lbl.text)
	if is_instance_valid(bl_pill) and bl_pill.visible:
		_assert(not p_heart.get_global_rect().intersects(bl_pill.get_global_rect()), "player_hp_heart overlaps bottom_left_status_pill")
		_assert(not turn_grp.get_global_rect().intersects(bl_pill.get_global_rect()), "YOUR TURN banner overlaps bottom_left_status_pill")
	if is_instance_valid(carry_pill) and carry_pill.visible:
		_assert(not p_heart.get_global_rect().intersects(carry_pill.get_global_rect()), "player_hp_heart overlaps carry_out_pill")
	await _save_shot("verify_cards_view_hud.png")
	print("  OK Group 4: Bare Enlarged 2D Hearts (Player under Chalice, Rival Top-Right) + YOUR TURN (zero collisions)")

	# Natural Camera Controls (NO RMB hold required; UP=UP, DOWN=DOWN, L/R persistent)
	var cam := bt.get("cam") as Camera3D
	_assert(is_instance_valid(cam), "Camera3D missing")
	var vp_w := maxf(800.0, float(root.get_visible_rect().size.x))
	var vp_h := maxf(600.0, float(root.get_visible_rect().size.y))
	var send_mouse_pos := func(pos: Vector2):
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		bt.call("_input", ev)
	send_mouse_pos.call(Vector2(vp_w * 0.5, vp_h * 0.5))
	await _wait_frames(40)
	var pitch_mid := cam.rotation_degrees.x
	var yaw_mid := cam.rotation_degrees.y

	send_mouse_pos.call(Vector2(vp_w * 0.5, vp_h * 0.10)) # Move UP without holding RMB
	await _wait_frames(40)
	var pitch_up := cam.rotation_degrees.x
	_assert(pitch_up > pitch_mid + 4.0, "Moving mouse UP must rotate camera UP (+pitch): mid=%.2f -> up=%.2f" % [pitch_mid, pitch_up])

	send_mouse_pos.call(Vector2(vp_w * 0.5, vp_h * 0.90)) # Move DOWN without holding RMB
	await _wait_frames(55)
	var pitch_down := cam.rotation_degrees.x
	_assert(pitch_down < pitch_mid - 4.0, "Moving mouse DOWN must rotate camera DOWN (-pitch): mid=%.2f -> down=%.2f" % [pitch_mid, pitch_down])

	# Persistence check (wait extra frames without moving mouse -> must stay looking down)
	await _wait_frames(15)
	_assert(absf(cam.rotation_degrees.x - pitch_down) < 0.75, "Camera pitch must persist without holding RMB")

	send_mouse_pos.call(Vector2(vp_w * 0.10, vp_h * 0.5)) # Move LEFT
	await _wait_frames(40)
	var yaw_left := cam.rotation_degrees.y
	send_mouse_pos.call(Vector2(vp_w * 0.90, vp_h * 0.5)) # Move RIGHT
	await _wait_frames(40)
	var yaw_right := cam.rotation_degrees.y
	_assert(yaw_left > yaw_mid + 4.0, "Moving mouse LEFT must turn camera LEFT (+yaw): mid=%.2f -> left=%.2f" % [yaw_mid, yaw_left])
	_assert(yaw_right < yaw_mid - 4.0, "Moving mouse RIGHT must turn camera RIGHT (-yaw): mid=%.2f -> right=%.2f" % [yaw_mid, yaw_right])
	send_mouse_pos.call(Vector2(vp_w * 0.5, vp_h * 0.5))
	await _wait_frames(12)
	print("  OK Group 5: Natural Camera Controls (pitch mid=%.1f up=%.1f down=%.1f | yaw left=%.1f right=%.1f)" % [pitch_mid, pitch_up, pitch_down, yaw_left, yaw_right])

	# Magical Card Draw Bezier Arc + Trail VFX
	var draw_done := [false]
	var test_draw_card := [{"suit": "CERVEN", "rank": "K", "pts": 18, "rname": "King", "edition": "NORMAL", "power_id": ""}]
	bt.call("_animate_magical_card_draw_3d", test_draw_card, true, func(): draw_done[0] = true)
	await _wait_frames(12)
	var found_trail := false
	for ch in bt.get_children():
		if ch.find_child("MagicalCardSparks", true, false) != null:
			found_trail = true
			break
	_assert(found_trail, "Magical card draw must attach MagicalCardSparks trail while flying")
	await _save_shot("verify_magical_card_draw.png")
	await _wait_frames(28)
	_assert(draw_done[0], "Magical card draw completion callback must fire on arrival")
	print("  OK Group 6: Magical Card Draw Bezier Arc + Particle/Light Trail")

	# Immediate Opponent Score Sync + Buckshot AI RIVAL_ITEMS view
	var ai_hand: Array = bt.get("ai_hand")
	ai_hand.insert(0, {"suit": "ZALUD", "rank": "8", "pts": 8, "rname": "Eight", "edition": "NORMAL", "power_id": ""})
	var ai_before := int(bt.get("ai_score"))
	var earned := int(bt.call("_apply_ai_card_play_state", 0))
	await _wait_frames(2)
	_assert(earned == 8, "Expected symmetric AI 1x8=8 pts, got %d" % earned)
	_assert(int(bt.get("ai_score")) == ai_before + 8, "AI score must update immediately upon card play (%d -> %d)" % [ai_before, int(bt.get("ai_score"))])
	_assert(int(bt.get("pending_ai_exchange_pts")) == 0, "pending_ai_exchange_pts must remain 0 (immediate update)")
	var ai_lbl := bt.get("ai_score_lbl") as Label
	_assert(is_instance_valid(ai_lbl) and ai_lbl.text.contains(str(ai_before + 8)), "ai_score_lbl must display updated AI score immediately, got '%s'" % (ai_lbl.text if ai_lbl else "null"))

	bt.call("set_camera_view_mode", 3, false) # CameraViewMode.RIVAL_ITEMS
	await _wait_frames(8)
	_assert(int(bt.get("cam_view_mode")) == 3, "AI Buckshot item review uses CameraViewMode.RIVAL_ITEMS (3)")
	print("  OK Group 7: Immediate AI Scoring + Symmetric Buckshot RIVAL_ITEMS")

	# 2D Heart Progressive Red-Color Drain Closeup (10/10, 5/10, 2/10, 0/10 side-by-side)
	var hc_layer := CanvasLayer.new()
	hc_layer.layer = 60
	root.add_child(hc_layer)
	var hc_bg := ColorRect.new()
	hc_bg.color = Color(0.055, 0.04, 0.045, 0.96)
	hc_bg.position = Vector2(150.0, 200.0)
	hc_bg.size = Vector2(1066.0, 350.0)
	hc_layer.add_child(hc_bg)

	var h_states := [
		{"hp": 10, "sh": 1, "x": 220.0, "lbl": "10/10 HP"},
		{"hp": 5,  "sh": 2, "x": 460.0, "lbl": "5/10 HP"},
		{"hp": 2,  "sh": 0, "x": 700.0, "lbl": "2/10 HP"},
		{"hp": 0,  "sh": 0, "x": 940.0, "lbl": "0/10 HP"},
	]
	var h_centers: Array[Vector2] = []
	for hs in h_states:
		var hw := HeartbeatHpDisplayScript.new()
		hc_layer.add_child(hw)
		hw.setup(ThemeDB.fallback_font, false, false)
		hw.set_hp_with_status(int(hs["hp"]), 10, int(hs["sh"]), "", false)
		hw.position = Vector2(float(hs["x"]), 275.0)
		hw.scale = Vector2(1.85, 1.85)
		var tag := Label.new()
		tag.text = str(hs["lbl"])
		tag.position = Vector2(float(hs["x"]), 490.0)
		tag.size = Vector2(200.0, 32.0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 22)
		tag.add_theme_color_override("font_color", Color(0.96, 0.90, 0.74))
		hc_layer.add_child(tag)
		h_centers.append(hw.position + hw.size * 0.5 * 1.85)
	await _wait_frames(6)
	await RenderingServer.frame_post_draw
	var hc_img := root.get_texture().get_image()
	_assert(hc_img != null and not hc_img.is_empty(), "Failed to capture heart closeup viewport image")
	if hc_img != null and not hc_img.is_empty():
		var redness := []
		for ctr in h_centers:
			var sum_red := 0.0
			var cnt_px := 0
			var cx := int(ctr.x)
			var cy := int(ctr.y)
			for dy in range(-28, 29, 4):
				for dx in range(-28, 29, 4):
					var px := hc_img.get_pixel(clampi(cx + dx, 0, hc_img.get_width() - 1), clampi(cy + dy, 0, hc_img.get_height() - 1))
					sum_red += px.r - (px.g + px.b) * 0.5
					cnt_px += 1
			redness.append(sum_red / maxf(1.0, float(cnt_px)))
		print("  Heart pixel redness (10->5->2->0 HP): %.3f -> %.3f -> %.3f -> %.3f" % [redness[0], redness[1], redness[2], redness[3]])
		_assert(redness[0] > redness[1] + 0.02, "10/10 heart must be significantly redder than 5/10 (%.3f vs %.3f)" % [redness[0], redness[1]])
		_assert(redness[1] > redness[2] + 0.02, "5/10 heart must be significantly redder than 2/10 (%.3f vs %.3f)" % [redness[1], redness[2]])
		_assert(redness[0] > redness[3] + 0.05, "10/10 heart must be much redder than 0/10 (%.3f vs %.3f)" % [redness[0], redness[3]])
		var shot_path := "%s/verify_heart_2d_closeup.png" % SHOT_DIR
		_assert(hc_img.save_png(shot_path) == OK, "Failed to save verify_heart_2d_closeup.png")
		print("  SHOT SAVED: %s (%dx%d)" % [shot_path, hc_img.get_width(), hc_img.get_height()])
	hc_layer.queue_free()

	bt.queue_free()
	await _wait_frames(3)

	if _failures.is_empty():
		print("=== VERIFY GAMEPLAY OVERHAUL: ALL 7 GROUPS & 6 SCREENSHOTS PASSED ===")
		quit(0)
	else:
		printerr("=== VERIFY GAMEPLAY OVERHAUL FAILED (%d ERROR(S)) ===" % _failures.size())
		quit(1)
