extends SceneTree

const BlenderVfx = preload("res://scripts/blender_vfx_animator.gd")

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


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=== VERIFY BLENDER VFX START ===")

	# 1. Verify all modified/new scripts load & compile cleanly
	for spath in [
		"res://scripts/blender_vfx_animator.gd",
		"res://scripts/relic_mesh_factory.gd",
		"res://scripts/battle_table_3d.gd",
		"res://scripts/mp/mp_battle_table_3d.gd",
		"res://scripts/downpour_root.gd",
	]:
		var res := ResourceLoader.load(spath)
		if res == null or (res is GDScript and not (res as GDScript).can_instantiate()):
			_fail("Failed to load/compile script: %s" % spath)
		else:
			print("OK script: %s" % spath)

	# 2. Verify all 10 GLB files load, contain meshes, and meet animation duration targets
	var glb_reqs := {
		"res://assets/models/vfx/scoring_astrolabe_stage.glb": 3.5,
		"res://assets/models/vfx/scoring_tokens_pack.glb": 0.0,
		"res://assets/models/vfx/card_anim_seven_barrage.glb": 3.1,
		"res://assets/models/vfx/card_anim_ace_chronos.glb": 3.1,
		"res://assets/models/vfx/card_anim_royal_crown.glb": 3.1,
		"res://assets/models/vfx/card_anim_arcane_conduit.glb": 3.1,
		"res://assets/models/vfx/hellfire_phial_hero.glb": 0.0,
		"res://assets/models/vfx/hellfire_explosion_anim.glb": 2.8,
		"res://assets/models/vfx/hellfire_burn_crown.glb": 1.5,
		"res://assets/models/vfx/defeat_execution_anim.glb": 4.2,
	}

	for gpath in glb_reqs.keys():
		var min_dur := float(glb_reqs[gpath])
		var ps := ResourceLoader.load(gpath) as PackedScene
		if ps == null:
			_fail("Failed to load GLB PackedScene: %s" % gpath)
			continue
		var inst := ps.instantiate()
		if inst == null:
			_fail("Failed to instantiate GLB: %s" % gpath)
			continue
		var mcnt := _count_meshes(inst)
		if mcnt <= 0:
			_fail("GLB has 0 meshes: %s" % gpath)
		if min_dur > 0.0:
			var ap := _find_anim_player(inst)
			var dur := _max_anim_length(ap)
			if ap == null:
				_fail("Animated GLB missing AnimationPlayer: %s" % gpath)
			elif dur < min_dur:
				_fail("Animated GLB duration %.2fs < %.2fs: %s" % [dur, min_dur, gpath])
			else:
				print("OK GLB: %s (meshes=%d, anim=%.2fs)" % [gpath, mcnt, dur])
		else:
			print("OK GLB: %s (meshes=%d, static)" % [gpath, mcnt])

		if gpath.ends_with("hellfire_phial_hero.glb"):
			if inst.find_child("IgnitedPlume", true, false) == null:
				_fail("hellfire_phial_hero.glb missing IgnitedPlume node")
		if gpath.ends_with("scoring_tokens_pack.glb"):
			for tname in ["Token_ChipCoin", "Token_MultSigil", "Token_XMultPrism", "Token_RelicBeamOrb", "Token_ScoreCrown"]:
				if inst.find_child(tname, true, false) == null:
					_fail("scoring_tokens_pack.glb missing %s" % tname)
		inst.queue_free()

	# 3. Exercise every BlenderVfxAnimator public API in a live SceneTree node
	var stage := Node3D.new()
	root.add_child(stage)

	var phial := BlenderVfx.build_hero_hellfire_phial(stage)
	if phial == null:
		_fail("build_hero_hellfire_phial returned null")
	var plume := phial.find_child("IgnitedPlume", true, false) as Node3D if phial != null else null
	if plume != null and plume.visible:
		_fail("IgnitedPlume should start hidden on idle hero phial")

	var burn_crown := BlenderVfx.build_burn_crown_aura(stage)
	if burn_crown == null:
		_fail("build_burn_crown_aura returned null")

	var astrolabe := BlenderVfx.spawn_scoring_astrolabe(stage, Vector3(0.14, 0.82, -0.02), Color(0.35, 0.9, 1.0), 3.6)
	if astrolabe == null:
		_fail("spawn_scoring_astrolabe returned null")
	else:
		BlenderVfx.pulse_astrolabe(astrolabe, Color(1.0, 0.8, 0.25), 1.4)

	for tok in ["Token_ChipCoin", "Token_MultSigil", "Token_XMultPrism", "Token_RelicBeamOrb", "Token_ScoreCrown"]:
		BlenderVfx.spawn_scoring_token_arc(stage, tok, Vector3(0, 0.9, 0.4), Vector3(0.14, 0.85, 0.0), Color(1.0, 0.84, 0.3), 0.45, 0.25, 2)

	var card_samples := [
		{"rank": "7", "suit": "CERVEN", "edition": "NORMAL"},
		{"rank": "E", "suit": "ZELEN", "edition": "NORMAL"},
		{"rank": "K", "suit": "GULA", "edition": "MERCHANT"},
		{"rank": "9", "suit": "ZALUD", "edition": "MAGE"},
	]
	for cs in card_samples:
		var c_rig := BlenderVfx.play_card_effect_anim(stage, cs, Vector3(0.14, 0.82, 0.0), Vector3(0.0, 0.95, -1.05), 2, 1.0)
		if c_rig == null:
			_fail("play_card_effect_anim returned null for %s" % str(cs))

	var throw_rig := BlenderVfx.play_hellfire_phial_throw(stage, Vector3(0.76, 0.82, 0.34), Vector3(0.0, 0.95, -1.0))
	if throw_rig == null:
		_fail("play_hellfire_phial_throw returned null")

	for loser_flag in [true, false]:
		var def_rig := BlenderVfx.play_defeat_execution_anim(stage, loser_flag, Vector3(0.0, 0.82, -0.1), Vector3(0.0, 1.05, 0.95 if loser_flag else -1.5))
		if def_rig == null:
			_fail("play_defeat_execution_anim returned null for loser_is_player=%s" % str(loser_flag))

	stage.queue_free()

	# 4. Instantiate full BattleTable3D at shifted world offset (500, 0, 500) matching downpour_root.gd
	var bt_script := ResourceLoader.load("res://scripts/battle_table_3d.gd") as GDScript
	var bt := bt_script.new() as Node3D
	if bt == null:
		_fail("Failed to instantiate BattleTable3D")
	else:
		root.add_child(bt)
		bt.position = Vector3(500.0, 0.0, 500.0)
		bt.visible = true
		if bt.magic_puf_bottle == null or bt.magic_puf_bottle.find_child("BlenderHellfirePhial", true, false) == null:
			_fail("BattleTable3D missing BlenderHellfirePhial inside magic_puf_bottle")
		if bt.opp_fire_fx_root == null or bt.opp_fire_fx_root.find_child("BlenderBurnCrown", true, false) == null:
			_fail("BattleTable3D missing BlenderBurnCrown inside opp_fire_fx_root")
		if bt.defeat_summary_overlay == null:
			_fail("BattleTable3D missing defeat_summary_overlay")
		if bt.stagger_eq_chips_lbl == null or bt.stagger_eq_mult_lbl == null:
			_fail("BattleTable3D missing Live Scoring Theatre labels")
		else:
			bt._show_stagger_callout("Test Step", Color(0.4, 0.9, 1.0), 1.2)
			bt._update_stagger_equation_theatre(68, 1.8, 1.5, 184, 2, 4, "xmult")
			if bt.stagger_eq_mult_lbl.text != "1.8":
				_fail("Expected stagger_eq_mult_lbl.text == '1.8', got '%s'" % bt.stagger_eq_mult_lbl.text)
			if bt.stagger_callout_pill.position.x < 490.0:
				_fail("stagger_callout_pill overlaps left player_hud_grp: x=%.1f" % bt.stagger_callout_pill.position.x)
		var sig_cards: Array[Dictionary] = [{"rank": "7", "suit": "CERVEN", "edition": "MAGE"}]
		bt._spawn_signature_play_vfx(sig_cards, bt.discard_pile_root.global_position, 2)
		bt.player_score = 50
		bt.puf_charges = 2
		bt._activate_magic_puf_3d()
		bt._play_sword_execution_finisher(false)
		bt._show_defeat_summary_overlay(false, 90)
		bt._play_sword_execution_finisher(true)
		if bt._active_blender_vfx_nodes.size() < 4:
			_fail("Expected >= 4 active Blender VFX rigs, got %d" % bt._active_blender_vfx_nodes.size())
		for vn in bt._active_blender_vfx_nodes:
			if is_instance_valid(vn):
				var dist: float = vn.global_position.distance_to(bt.global_position)
				if dist >= 4.0:
					_fail("Blender VFX %s spawned off-table at %s (dist=%.2f from %s)" % [vn.name, str(vn.global_position), dist, str(bt.global_position)])
		bt.set_active(false)
		if not bt._active_blender_vfx_nodes.is_empty():
			_fail("Expected _active_blender_vfx_nodes cleared on set_active(false)")
		bt.queue_free()
		print("OK BattleTable3D (500,0,500) world-space checks")

	if _failures.is_empty():
		print("VERIFY_BLENDER_VFX_ALL_PASSED")
		quit(0)
	else:
		printerr("TOTAL FAILURES: %d" % _failures.size())
		quit(1)
