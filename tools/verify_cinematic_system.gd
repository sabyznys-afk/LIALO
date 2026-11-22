extends SceneTree

const CineProfiles = preload("res://scripts/cinematic_profiles.gd")
const CineDirector = preload("res://scripts/cinematic_director.gd")

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _count_meshes(node: Node) -> int:
	var c := 1 if (node is MeshInstance3D and (node as MeshInstance3D).mesh != null) else 0
	for ch in node.get_children():
		c += _count_meshes(ch)
	return c


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for ch in node.get_children():
		var found := _find_anim_player(ch)
		if found != null:
			return found
	return null


func _max_anim_length(ap: AnimationPlayer) -> float:
	if ap == null:
		return 0.0
	var mx := 0.0
	for aname in ap.get_animation_list():
		if String(aname) == "RESET":
			continue
		var a := ap.get_animation(aname)
		if a != null:
			mx = maxf(mx, a.length)
	return mx


func _validate_profile_dict(label: String, prof: Dictionary) -> void:
	if prof.is_empty():
		_fail("%s profile is empty" % label)
		return
	var dur := float(prof.get("duration", 0.0))
	if dur < 4.2 or dur > 7.2:
		_fail("%s duration %.2f outside [4.2, 7.2]" % [label, dur])
	if str(prof.get("title_en", "")).strip_edges() == "" or str(prof.get("title_cs", "")).strip_edges() == "":
		_fail("%s missing title_en or title_cs" % label)
	var vfx_p := str(prof.get("vfx_glb_path", ""))
	if not (vfx_p in CineProfiles.ALL_VFX_GLB_PATHS):
		_fail("%s has invalid vfx_glb_path: %s" % [label, vfx_p])
	var shots: Variant = prof.get("camera_shots", [])
	if not (shots is Array) or (shots as Array).size() < 4:
		_fail("%s must define >= 4 camera_shots" % label)
	else:
		for si in range((shots as Array).size()):
			var s: Dictionary = (shots as Array)[si]
			if not (s.get("pos") is Vector3) or not (s.get("look_at") is Vector3):
				_fail("%s shot %d missing Vector3 pos/look_at" % [label, si])
			if float(s.get("fov", 0.0)) <= 20.0:
				_fail("%s shot %d invalid fov" % [label, si])
			if str(s.get("trans", "")) == "":
				_fail("%s shot %d missing trans" % [label, si])
	var hitstop := float(prof.get("hitstop_at", 0.0))
	if hitstop <= 0.4 or hitstop >= dur:
		_fail("%s invalid hitstop_at %.2f for dur %.2f" % [label, hitstop, dur])
	var pose_k := str(prof.get("opponent_pose_key", ""))
	if not (pose_k in CineProfiles.VALID_POSE_KEYS):
		_fail("%s invalid opponent_pose_key: %s" % [label, pose_k])


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	print("=== VERIFY CINEMATIC SYSTEM START ===")

	# 1. Verify all 6 Blender 5.3 Cinematic VFX GLBs load, have sculpted meshes, and AnimationPlayer >= 2.8s
	for gpath in CineProfiles.ALL_VFX_GLB_PATHS:
		var inst := CineDirector._instantiate_vfx_glb(gpath)
		if inst == null:
			_fail("Failed to load/instantiate GLB: %s" % gpath)
			continue
		var mcnt := _count_meshes(inst)
		var ap := _find_anim_player(inst)
		var dur := _max_anim_length(ap)
		if mcnt < 10:
			_fail("GLB %s has too few meshes (%d < 10)" % [gpath, mcnt])
		if ap == null:
			_fail("GLB %s missing AnimationPlayer" % gpath)
		elif dur < 5.0:
			_fail("GLB %s animation duration %.2fs < 5.00s" % [gpath, dur])
		else:
			print("OK Cinematic GLB: %s (meshes=%d, anim=%.2fs)" % [gpath, mcnt, dur])
		inst.free()

	# 2. Verify all 15 active SPEC_* card profiles (and confirm SPEC_PRISM is excluded)
	if CineProfiles.ACTIVE_SPECIAL_CARD_IDS.size() != 15:
		_fail("Expected 15 active SPEC_* card IDs, got %d" % CineProfiles.ACTIVE_SPECIAL_CARD_IDS.size())
	if CineProfiles.has_special_card_profile("SPEC_PRISM"):
		_fail("SPEC_PRISM must not be in active SPECIAL_CARD_PROFILES")

	for cid in CineProfiles.ACTIVE_SPECIAL_CARD_IDS:
		if not CineProfiles.has_special_card_profile(cid):
			_fail("Missing special card profile for %s" % cid)
			continue
		var prof := CineProfiles.get_special_card_profile(cid)
		_validate_profile_dict(cid, prof)
	print("OK All 15 active SPEC_* profiles validated")

	# 3. Verify all 5 Era Rival & Boss profiles (+ generic/endless)
	for eid in ["antika", "rim", "stredovek", "objavy", "prohibicia", "generic", "endless"]:
		for b_flag in [false, true]:
			var rprof := CineProfiles.get_rival_turn_profile(eid, b_flag)
			_validate_profile_dict("era_%s_boss_%s" % [eid, str(b_flag)], rprof)
	print("OK All 5 Era Rival + Boss profiles (+ generic/endless) validated")

	# 4. Live CinematicDirector simulation at shifted world offset (500, 0, 500)
	var host_table := Node3D.new()
	host_table.name = "MockBattleTable3D"
	root.add_child(host_table)
	host_table.global_position = Vector3(500.0, 0.0, 500.0)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.66, 1.52)
	cam.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	cam.fov = 60.0
	host_table.add_child(cam)
	var orig_cam_tx := cam.transform
	var orig_cam_fov := cam.fov

	var hud := Control.new()
	hud.size = Vector2(1920, 1080)
	host_table.add_child(hud)

	# Build mock Opponent 3D rig matching @opponents-3d pivot contract
	var opp_root := Node3D.new()
	opp_root.name = "OppSilhouetteRoot"
	opp_root.position = Vector3(0.0, 0.86, -1.50)
	host_table.add_child(opp_root)

	var pivots := {}
	for pname in ["TorsoPivot", "HeadPivot", "ArmLPivot", "ArmRPivot", "EyeL", "EyeR"]:
		var pnode := Node3D.new()
		pnode.name = pname
		opp_root.add_child(pnode)
		pivots[pname] = pnode
	(pivots["HeadPivot"] as Node3D).position = Vector3(0.0, 0.56, 0.01)
	(pivots["ArmLPivot"] as Node3D).position = Vector3(-0.26, 0.44, 0.02)
	(pivots["ArmRPivot"] as Node3D).position = Vector3(0.26, 0.44, 0.02)

	var director := CineDirector.new()
	host_table.add_child(director)
	director.setup(host_table, cam, hud, ThemeDB.fallback_font)
	director.set_opponent_rig(opp_root)

	var card_world := host_table.to_global(Vector3(0.14, 0.82, -0.02))
	var rival_world := host_table.to_global(Vector3(0.0, 0.95, -1.35))

	# 4A. Test full Special Card cutscene playback (SPEC_PHOENIX)
	var spec_state := {"impact": 0, "finished": 0}
	director.play_special_card_cinematic(
		"SPEC_PHOENIX",
		card_world,
		rival_world,
		true,
		func(): spec_state["impact"] += 1,
		func(): spec_state["finished"] += 1
	)
	if not director.is_playing():
		_fail("CinematicDirector should be playing after play_special_card_cinematic")

	var mid_torso_rot_changed := false
	var step_count := 0
	while director.is_playing() and step_count < 85:
		director._process(0.10)
		if (pivots["TorsoPivot"] as Node3D).rotation_degrees.length() > 0.5:
			mid_torso_rot_changed = true
		step_count += 1

	if director.is_playing():
		_fail("SPEC_PHOENIX cinematic did not finish within expected duration")
	if spec_state["impact"] != 1:
		_fail("SPEC_PHOENIX on_impact expected 1 call, got %d" % spec_state["impact"])
	if spec_state["finished"] != 1:
		_fail("SPEC_PHOENIX on_finished expected 1 call, got %d" % spec_state["finished"])
	if not mid_torso_rot_changed:
		_fail("SPEC_PHOENIX did not animate opponent TorsoPivot during playback")
	if not cam.transform.is_equal_approx(orig_cam_tx) or absf(cam.fov - orig_cam_fov) > 0.01:
		_fail("Camera3D transform/fov not restored cleanly after SPEC_PHOENIX cinematic")
	if (pivots["TorsoPivot"] as Node3D).rotation_degrees.length() > 0.01:
		_fail("TorsoPivot rotation not restored after SPEC_PHOENIX cinematic")
	print("OK CinematicDirector.play_special_card_cinematic full lifecycle verified")

	# 4B. Test full Rival Boss Turn cutscene playback (stredovek boss)
	var rival_state := {"impact": 0, "finished": 0}
	director.play_rival_turn_cinematic(
		"stredovek",
		true,
		"KING'S DECREE • +25",
		card_world,
		rival_world,
		false,
		func(): rival_state["impact"] += 1,
		func(): rival_state["finished"] += 1
	)
	if not director.is_playing():
		_fail("CinematicDirector should be playing after play_rival_turn_cinematic")

	var arm_r_moved := false
	step_count = 0
	while director.is_playing() and step_count < 85:
		director._process(0.10)
		if (pivots["ArmRPivot"] as Node3D).rotation_degrees.length() > 1.0:
			arm_r_moved = true
		step_count += 1

	if director.is_playing():
		_fail("Rival turn cinematic did not finish within expected duration")
	if rival_state["impact"] != 1 or rival_state["finished"] != 1:
		_fail("Rival turn callbacks mismatch: impact=%d finished=%d" % [rival_state["impact"], rival_state["finished"]])
	if not arm_r_moved:
		_fail("Rival turn cinematic did not animate ArmRPivot")
	if not cam.transform.is_equal_approx(orig_cam_tx):
		_fail("Camera3D transform not restored after Rival turn cinematic")
	print("OK CinematicDirector.play_rival_turn_cinematic full lifecycle verified")

	# 4C. Test skip_current() mid-cutscene before hitstop_at
	var skip_state := {"impact": 0, "finished": 0}
	director.play_special_card_cinematic(
		"SPEC_VAMPIRE",
		card_world,
		rival_world,
		false,
		func(): skip_state["impact"] += 1,
		func(): skip_state["finished"] += 1
	)
	director._process(0.35)
	director.skip_current()
	if director.is_playing():
		_fail("CinematicDirector should stop immediately on skip_current()")
	if skip_state["impact"] != 1 or skip_state["finished"] != 1:
		_fail("skip_current() must fire pending on_impact and on_finished exactly once (got %d, %d)" % [skip_state["impact"], skip_state["finished"]])
	if not cam.transform.is_equal_approx(orig_cam_tx) or (pivots["TorsoPivot"] as Node3D).rotation_degrees.length() > 0.01:
		_fail("skip_current() did not restore Camera3D or opponent pivots")
	print("OK CinematicDirector.skip_current() verified")

	host_table.free()

	if _failures.is_empty():
		print("VERIFY_CINEMATIC_SYSTEM_ALL_PASSED")
		quit(0)
	else:
		printerr("TOTAL FAILURES: %d" % _failures.size())
		quit(1)
