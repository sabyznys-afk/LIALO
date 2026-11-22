extends SceneTree

const LobbyOptions3DScript = preload("res://scripts/lobby_options_3d.gd")

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _load_glb_node(res_path: String) -> Node3D:
	if ResourceLoader.exists(res_path):
		var ps := ResourceLoader.load(res_path) as PackedScene
		if ps != null:
			var inst := ps.instantiate()
			if inst is Node3D:
				return inst as Node3D
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		if gltf.append_from_file(abs_p, state) == OK:
			var gen := gltf.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
	return null


func _count_meshes(node: Node) -> int:
	var c := 1 if (node is MeshInstance3D and (node as MeshInstance3D).mesh != null) else 0
	for ch in node.get_children():
		c += _count_meshes(ch)
	return c


func _find_class_node(node: Node, cls_name: String) -> Node:
	if node.get_class() == cls_name:
		return node
	for ch in node.get_children():
		var found := _find_class_node(ch, cls_name)
		if found != null:
			return found
	return null


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	print("=== VERIFY INTRO & LOBBY 3D START ===")

	# 1. Verify shader & scripts load and compile cleanly
	var mtn_sh := ResourceLoader.load("res://shaders/mountain_toon.gdshader") as Shader
	if mtn_sh == null:
		_fail("Failed to load res://shaders/mountain_toon.gdshader")
	else:
		var m_code := mtn_sh.code
		for u_name in ["snow_shadow_col", "snow_sun_tint", "wind_drift_strength", "sparkle_strength", "snow_time", "snow_line_ratio"]:
			if not m_code.contains(u_name):
				_fail("mountain_toon.gdshader missing uniform: %s" % u_name)
		print("OK shader: res://shaders/mountain_toon.gdshader")

	for spath in ["res://scripts/lobby_options_3d.gd", "res://scripts/downpour_root.gd"]:
		var res := ResourceLoader.load(spath)
		if res == null or (res is GDScript and not (res as GDScript).can_instantiate()):
			_fail("Failed to load/compile script: %s" % spath)
		else:
			print("OK script: %s" % spath)

	# 2. Verify animated 3D Chamois GLB (Mesh + Skeleton3D + LeapCycle + RidgeStand)
	var chamois_inst := _load_glb_node("res://assets/models/intro_chamois.glb")
	if chamois_inst == null:
		_fail("Failed to instantiate res://assets/models/intro_chamois.glb")
	else:
		var m_cnt := _count_meshes(chamois_inst)
		var skel := _find_class_node(chamois_inst, "Skeleton3D")
		var ap := _find_class_node(chamois_inst, "AnimationPlayer") as AnimationPlayer
		if m_cnt < 1:
			_fail("intro_chamois.glb has 0 meshes")
		if skel == null:
			_fail("intro_chamois.glb missing Skeleton3D")
		if ap == null:
			_fail("intro_chamois.glb missing AnimationPlayer")
		else:
			for req_anim in ["LeapCycle", "RidgeStand"]:
				if not ap.has_animation(req_anim):
					_fail("intro_chamois.glb missing animation: %s" % req_anim)
				else:
					var a := ap.get_animation(req_anim)
					if a == null or a.length < 1.0:
						_fail("intro_chamois.glb animation %s too short: %.2fs" % [req_anim, a.length if a else 0.0])
					else:
						print("OK chamois anim %s: %.2fs" % [req_anim, a.length])
		print("OK intro_chamois.glb (meshes=%d, skel=%s)" % [m_cnt, skel != null])
		chamois_inst.queue_free()

	# 3. Verify all 6 Lobby Options 3D GLBs and named animated child nodes
	var prop_reqs := {
		"res://assets/models/lobby_options/settings_desk_ledger.glb": [],
		"res://assets/models/lobby_options/settings_brass_dial.glb": ["DialKnob"],
		"res://assets/models/lobby_options/settings_wax_stamp.glb": ["StampHandle"],
		"res://assets/models/lobby_options/settings_lantern_prism.glb": ["LanternCore"],
		"res://assets/models/lobby_options/settings_hourglass.glb": ["HourglassBody"],
		"res://assets/models/lobby_options/settings_gramophone_bell.glb": ["BellHorn"],
	}
	for p_path in prop_reqs.keys():
		var p_inst := _load_glb_node(p_path)
		if p_inst == null:
			_fail("Failed to load prop GLB: %s" % p_path)
			continue
		var pm_cnt := _count_meshes(p_inst)
		if pm_cnt < 1:
			_fail("Prop GLB has 0 meshes: %s" % p_path)
		for child_name in prop_reqs[p_path]:
			if p_inst.find_child(child_name, true, false) == null:
				_fail("%s missing required child node: %s" % [p_path, child_name])
		print("OK prop GLB: %s (meshes=%d)" % [p_path, pm_cnt])
		p_inst.queue_free()

	# 4. Exercise LobbyOptions3D lifecycle, signal dispatch, and layout projection at 1366x768 & 1920x1080
	var opt_ui := LobbyOptions3DScript.new()
	root.add_child(opt_ui)
	opt_ui.setup(ThemeDB.fallback_font, ThemeDB.fallback_font)

	var counts := {"opt": 0, "diff": 0, "mute": 0, "vol": 0, "sfx": 0}
	opt_ui.option_changed.connect(func(_k, _v): counts["opt"] += 1)
	opt_ui.difficulty_toggled.connect(func(): counts["diff"] += 1)
	opt_ui.mute_toggled.connect(func(): counts["mute"] += 1)
	opt_ui.volume_changed.connect(func(_v): counts["vol"] += 1)
	opt_ui.sfx_requested.connect(func(_s): counts["sfx"] += 1)

	var dummy_opts := {
		"language": "en",
		"fullscreen": true,
		"visual_mode": 3,
		"high_fx": true,
		"game_pace": "relaxed",
		"cam_sensitivity": 1.0,
	}
	var dummy_prof := {"campaign_difficulty": "traveler"}
	opt_ui.sync_state(dummy_opts, dummy_prof, false, 85, "MAIN_MENU")
	opt_ui.open_3d()
	if not opt_ui.is_open():
		_fail("LobbyOptions3D.is_open() returned false after open_3d()")

	for st_key in ["language", "visual_mode", "fullscreen", "high_fx", "difficulty", "game_pace", "mute", "volume", "cam_sensitivity"]:
		opt_ui._trigger_station(st_key)

	if counts["opt"] != 6:
		_fail("Expected 6 option_changed signals, got %d" % counts["opt"])
	if counts["diff"] != 1 or counts["mute"] != 1 or counts["vol"] != 1:
		_fail("Signal dispatch mismatch: %s" % str(counts))
	print("OK LobbyOptions3D signal dispatch: %s" % str(counts))

	opt_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	opt_ui._vp_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	opt_ui._vp_container.stretch = false
	for res_sz in [Vector2(1366.0, 768.0), Vector2(1920.0, 1080.0)]:
		opt_ui.size = res_sz
		opt_ui._vp_container.size = res_sz
		opt_ui._vp.size = Vector2i(int(res_sz.x), int(res_sz.y))
		opt_ui._cam_open_blend = 1.0
		opt_ui._update_camera_pose(0.0, true)
		await process_frame
		await process_frame
		var rects: Dictionary = opt_ui.get_projected_station_rects()
		if rects.size() != 10:
			_fail("Expected 10 projected rects at %s, got %d (%s)" % [str(res_sz), rects.size(), str(rects.keys())])
			continue

		var keys := rects.keys()
		for k in keys:
			var r: Rect2 = rects[k]
			print("  [%dx%d] %-16s -> %s" % [int(res_sz.x), int(res_sz.y), k, str(r)])
			if r.position.x < 0.02 * res_sz.x - 1.0 or r.end.x > 0.98 * res_sz.x + 1.0:
				_fail("Rect '%s' out of horizontal bounds at %s: %s" % [k, str(res_sz), str(r)])
			if r.position.y < 74.0 or r.end.y > res_sz.y - 76.0:
				_fail("Rect '%s' out of vertical safe zone at %s: %s" % [k, str(res_sz), str(r)])

		var overlap_found := false
		for i in range(keys.size()):
			for j in range(i + 1, keys.size()):
				var ka: String = keys[i]
				var kb: String = keys[j]
				var ra: Rect2 = rects[ka]
				var rb: Rect2 = rects[kb]
				if ra.intersects(rb):
					overlap_found = true
					_fail("Badge overlap at %s between '%s' (%s) and '%s' (%s)" % [str(res_sz), ka, str(ra), kb, str(rb)])
		if not overlap_found:
			print("OK projection layout (10 rects, 0 overlaps) at %dx%d" % [int(res_sz.x), int(res_sz.y)])

	opt_ui.close_3d()
	opt_ui.queue_free()

	if _failures.is_empty():
		print("=== VERIFY INTRO & LOBBY 3D: ALL CHECKS PASSED ===")
		quit(0)
	else:
		printerr("=== VERIFY INTRO & LOBBY 3D FAILED (%d errors) ===" % _failures.size())
		quit(1)
