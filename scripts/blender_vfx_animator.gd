class_name BlenderVfxAnimator
extends RefCounted

const FxLib = preload("res://scripts/fx_lib.gd")
const SwordCardAnim = preload("res://scripts/sword_card_animator.gd")

## Runtime loader, material tinting, and choreography driver for Blender 5.3
## headless-generated .glb 3D VFX rigs, sculpted scoring tokens, Hellfire Phial
## throws, and Execution/Defeat cinematics in LIALO.

const PATH_ASTROLABE := "res://assets/models/vfx/scoring_astrolabe_stage.glb"
const PATH_TOKENS_PACK := "res://assets/models/vfx/scoring_tokens_pack.glb"
const PATH_CARD_SEVEN := "res://assets/models/vfx/card_anim_seven_barrage.glb"
const PATH_CARD_ACE := "res://assets/models/vfx/card_anim_ace_chronos.glb"
const PATH_CARD_ROYAL := "res://assets/models/vfx/card_anim_royal_crown.glb"
const PATH_CARD_ARCANE := "res://assets/models/vfx/card_anim_arcane_conduit.glb"
const PATH_PHIAL_HERO := "res://assets/models/vfx/hellfire_phial_hero.glb"
const PATH_PHIAL_EXPLOSION := "res://assets/models/vfx/hellfire_explosion_anim.glb"
const PATH_PHIAL_BURN_CROWN := "res://assets/models/vfx/hellfire_burn_crown.glb"
const PATH_DEFEAT_EXEC := "res://assets/models/vfx/defeat_execution_anim.glb"

static var _scene_cache: Dictionary = {}


static func _load_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	if ps != null:
		_scene_cache[path] = ps
	return ps


static func _instantiate_glb(path: String) -> Node3D:
	var ps := _load_scene(path)
	if ps != null:
		var inst := ps.instantiate()
		if inst is Node3D:
			return inst as Node3D
		if inst != null:
			inst.queue_free()
	var global_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_p):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(global_p, state) == OK:
			var gen := doc.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
			if gen != null:
				gen.queue_free()
	return null


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for ch in root.get_children():
		var found := _find_animation_player(ch)
		if found != null:
			return found
	return null


static func _play_embedded_anim(root: Node, speed_scale: float = 1.0, loop_anim: bool = false) -> float:
	var ap := _find_animation_player(root)
	if ap == null:
		return 0.0
	var anim_list := ap.get_animation_list()
	var chosen := ""
	for aname in anim_list:
		if String(aname) != "RESET":
			chosen = String(aname)
			break
	if chosen == "" and not anim_list.is_empty():
		chosen = String(anim_list[0])
	if chosen == "":
		return 0.0
	var anim := ap.get_animation(chosen)
	var dur := anim.length if anim != null else 3.0
	if anim != null and loop_anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.speed_scale = maxf(0.15, speed_scale)
	ap.play(chosen)
	return dur / maxf(0.15, speed_scale)


static func _tint_materials(root: Node, target_substrings: PackedStringArray, col: Color, emission_energy: float = 2.4, also_albedo: bool = true) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				var sc := mi.mesh.get_surface_count()
				for si in range(sc):
					var base_mat := mi.get_surface_override_material(si)
					if base_mat == null:
						base_mat = mi.mesh.surface_get_material(si)
					if base_mat is BaseMaterial3D:
						var mname := base_mat.resource_name
						var matched := target_substrings.is_empty()
						for sub in target_substrings:
							if sub in mname:
								matched = true
								break
						if matched:
							var dup := base_mat.duplicate() as BaseMaterial3D
							if also_albedo:
								dup.albedo_color = Color(col.r, col.g, col.b, dup.albedo_color.a)
							dup.emission_enabled = true
							dup.emission = col
							dup.emission_energy_multiplier = emission_energy
							mi.set_surface_override_material(si, dup)
		for ch in cur.get_children():
			stack.append(ch)


static func _disable_shadows_recursive(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is GeometryInstance3D:
			(cur as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for ch in cur.get_children():
			stack.append(ch)


static func _auto_free_after(parent: Node, target: Node, delay_sec: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var wr: WeakRef = weakref(target)
	parent.get_tree().create_timer(maxf(0.1, delay_sec), true, false, true).timeout.connect(func():
		var n := wr.get_ref() as Node
		if is_instance_valid(n):
			n.queue_free()
	)


static func build_hero_hellfire_phial(parent: Node3D) -> Node3D:
	if not is_instance_valid(parent):
		return null
	var model := _instantiate_glb(PATH_PHIAL_HERO)
	if model == null:
		return null
	model.name = "BlenderHellfirePhial"
	var plume := model.find_child("IgnitedPlume", true, false) as Node3D
	if plume != null:
		plume.visible = false
	parent.add_child(model)
	return model


static func build_burn_crown_aura(parent: Node3D) -> Node3D:
	if not is_instance_valid(parent):
		return null
	var crown := _instantiate_glb(PATH_PHIAL_BURN_CROWN)
	if crown == null:
		return null
	crown.name = "BlenderBurnCrown"
	crown.scale = Vector3(0.42, 0.34, 0.42)
	_disable_shadows_recursive(crown)
	var stack: Array[Node] = [crown]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				for si in range(mi.mesh.get_surface_count()):
					var base_mat := mi.get_surface_override_material(si)
					if base_mat == null:
						base_mat = mi.mesh.surface_get_material(si)
					if base_mat is BaseMaterial3D:
						var dup := base_mat.duplicate() as BaseMaterial3D
						if dup.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
							dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						dup.albedo_color.a = clampf(dup.albedo_color.a * 0.52, 0.15, 0.65)
						if dup.emission_enabled:
							dup.emission_energy_multiplier = clampf(dup.emission_energy_multiplier * 0.40, 0.25, 1.1)
						mi.set_surface_override_material(si, dup)
		for ch in cur.get_children():
			stack.append(ch)
	parent.add_child(crown)
	_play_embedded_anim(crown, 1.0, true)
	return crown


static func spawn_scoring_astrolabe(table_node: Node3D, world_pos: Vector3, accent_col: Color, duration_sec: float = 3.6) -> Node3D:
	if not is_instance_valid(table_node) or not table_node.is_inside_tree():
		return null
	var stage := _instantiate_glb(PATH_ASTROLABE)
	if stage == null:
		return null
	stage.name = "BlenderScoringAstrolabe"
	_disable_shadows_recursive(stage)
	_tint_materials(stage, PackedStringArray(["Mat_AccentGlow"]), accent_col, 3.0)

	var lgt := OmniLight3D.new()
	lgt.name = "StageLight"
	lgt.position = Vector3(0.0, 0.34, 0.0)
	lgt.light_color = accent_col.lightened(0.2)
	lgt.light_energy = 2.2
	lgt.omni_range = 2.1
	lgt.omni_attenuation = 1.4
	stage.add_child(lgt)

	table_node.add_child(stage)
	stage.global_position = Vector3(world_pos.x, maxf(table_node.global_position.y + 0.818, world_pos.y), world_pos.z)
	stage.set_meta("base_scale", 1.0)

	var speed := clampf(4.0 / maxf(1.2, duration_sec), 0.45, 1.6)
	var real_dur := _play_embedded_anim(stage, speed, false)
	if real_dur <= 0.0:
		real_dur = duration_sec
	_auto_free_after(table_node, stage, real_dur + 0.25)
	return stage


static func pulse_astrolabe(stage_node: Node3D, col: Color, intensity: float = 1.0) -> void:
	if not is_instance_valid(stage_node):
		return
	_tint_materials(stage_node, PackedStringArray(["Mat_AccentGlow"]), col, clampf(2.6 + intensity * 1.4, 2.2, 6.0))
	var lgt := stage_node.get_node_or_null("StageLight") as OmniLight3D
	if is_instance_valid(lgt):
		lgt.light_color = col.lightened(0.25)
		lgt.light_energy = clampf(2.4 + intensity * 1.6, 2.0, 5.5)
		var ltw := lgt.create_tween()
		ltw.tween_property(lgt, "light_energy", 1.6, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tw := stage_node.create_tween()
	var peak := 1.0 + clampf(intensity * 0.08, 0.05, 0.20)
	tw.tween_property(stage_node, "scale", Vector3.ONE * peak, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stage_node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


static func spawn_scoring_token_arc(
	table_node: Node3D,
	token_name: String,
	from_global: Vector3,
	to_global: Vector3,
	accent_col: Color,
	dur: float = 0.52,
	arc_h: float = 0.28,
	count: int = 1
) -> void:
	if not is_instance_valid(table_node) or not table_node.is_inside_tree():
		return
	var pack := _instantiate_glb(PATH_TOKENS_PACK)
	if pack == null:
		return
	var proto := pack.find_child(token_name, true, false) as Node3D
	if proto == null:
		pack.queue_free()
		return

	var n := clampi(count, 1, 6)
	for i in range(n):
		var tok := proto.duplicate() as Node3D
		if tok == null:
			continue
		tok.position = Vector3.ZERO
		tok.rotation = Vector3.ZERO
		tok.scale = Vector3.ONE * 1.25
		_disable_shadows_recursive(tok)
		_tint_materials(tok, PackedStringArray(["Mat_TokenAccent"]), accent_col, 3.2)
		table_node.add_child(tok)

		var jitter := Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.06, 0.06)) if n > 1 else Vector3.ZERO
		var p0 := from_global + jitter
		var p2 := to_global + Vector3(0.0, 0.06, 0.0)
		var p1 := p0.lerp(p2, 0.5) + Vector3(randf_range(-0.12, 0.12), arc_h + float(i % 2) * 0.08, randf_range(-0.08, 0.08))
		tok.global_position = p0

		var delay_i := float(i) * 0.055
		var tok_wr: WeakRef = weakref(tok)
		var tw := tok.create_tween()
		if delay_i > 0.0:
			tw.tween_interval(delay_i)
		tw.tween_method(func(u: float):
			var inst := tok_wr.get_ref() as Node3D
			if not is_instance_valid(inst):
				return
			var a := p0.lerp(p1, u)
			var b := p1.lerp(p2, u)
			inst.global_position = a.lerp(b, u)
			inst.rotation_degrees = Vector3(u * 360.0, u * 540.0, u * 180.0)
			var sc := 1.25 * sin(clampf(u, 0.05, 0.95) * PI * 0.85 + 0.15)
			inst.scale = Vector3.ONE * maxf(0.35, sc)
		, 0.0, 1.0, maxf(0.18, dur)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			var inst := tok_wr.get_ref() as Node3D
			if is_instance_valid(inst):
				inst.queue_free()
		)
	pack.queue_free()


static func _pick_card_glb_and_color(card_data: Dictionary) -> Dictionary:
	var rank := str(card_data.get("rank", ""))
	var pid := str(card_data.get("power_id", ""))
	var suit := str(card_data.get("suit", "CERVEN"))
	var cls := str(card_data.get("edition", card_data.get("card_class", "NORMAL")))

	var suit_cols := {
		"CERVEN": Color(0.96, 0.24, 0.28),
		"GULA": Color(1.0, 0.78, 0.22),
		"ZELEN": Color(0.28, 0.88, 0.48),
		"ZALUD": Color(0.76, 0.56, 0.26),
	}
	var col: Color = card_data.get("accent", suit_cols.get(suit, Color(0.45, 0.88, 1.0)))
	if cls == "MAGE":
		col = Color(0.68, 0.44, 1.0)
	elif cls == "KNIGHT":
		col = Color(0.45, 0.90, 1.0)
	elif cls == "MERCHANT":
		col = Color(1.0, 0.82, 0.24)
	elif cls == "THIEF":
		col = Color(0.28, 0.94, 0.56)

	var path := PATH_CARD_ARCANE
	if rank == "7" or pid == "SPEC_HEX" or cls == "THIEF":
		path = PATH_CARD_SEVEN
	elif rank == "E" or pid == "SPEC_CHRONOS" or pid == "SPEC_PLAGUE":
		path = PATH_CARD_ACE
	elif rank in ["K", "H", "D", "10"] or pid in ["SPEC_CROWN", "SPEC_MIDAS", "SPEC_SHIELD"] or cls == "MERCHANT":
		path = PATH_CARD_ROYAL
	return {"path": path, "color": col}


static func play_card_effect_anim(
	table_node: Node3D,
	card_data: Dictionary,
	impact_global: Vector3,
	rival_global: Vector3,
	count: int = 1,
	_speed_scale: float = 1.0
) -> Node3D:
	if not is_instance_valid(table_node) or not table_node.is_inside_tree():
		return null
	var cls := str(card_data.get("edition", card_data.get("card_class", "NORMAL"))).to_upper()
	var is_knight := (cls == "KNIGHT")
	var local_impact := table_node.to_local(impact_global)
	var local_rival := table_node.to_local(rival_global)
	var attacker_is_player := (local_rival.z <= local_impact.z)
	var score_pts := 20 + maxi(0, count - 1) * 15
	var eff_mult := 1.0 + maxf(0.0, float(count - 1)) * 0.5
	return SwordCardAnim.play_sword_card_score_anim(
		table_node,
		card_data,
		null,
		attacker_is_player,
		impact_global,
		score_pts,
		eff_mult,
		is_knight
	)


static func play_hellfire_phial_throw(
	table_node: Node3D,
	coaster_global: Vector3,
	target_global: Vector3,
	pace_mult: float = 1.0,
	on_impact_cb: Callable = Callable(),
	on_complete_cb: Callable = Callable()
) -> Node3D:
	if not is_instance_valid(table_node) or not table_node.is_inside_tree():
		return null

	var holder := Node3D.new()
	holder.name = "BlenderHellfireThrowRig"
	table_node.add_child(holder)

	var flask := _instantiate_glb(PATH_PHIAL_HERO)
	if flask == null:
		holder.queue_free()
		return null
	_disable_shadows_recursive(flask)
	var plume := flask.find_child("IgnitedPlume", true, false) as Node3D
	if plume != null:
		plume.visible = true
	holder.add_child(flask)
	flask.global_position = coaster_global

	var flask_light := OmniLight3D.new()
	flask_light.position = Vector3(0.0, 0.14, 0.0)
	flask_light.light_color = Color(1.0, 0.48, 0.12)
	flask_light.light_energy = 3.2
	flask_light.omni_range = 2.6
	flask.add_child(flask_light)

	var pm := clampf(pace_mult, 0.35, 1.5)
	var act1_dur := 0.95 * pm
	var act2_dur := 1.10 * pm
	var act3_dur := 1.55 * pm
	var act4_dur := 0.55 * pm

	var lift_pos := coaster_global + Vector3(-0.04, 0.34, -0.08)
	var apex_mid := lift_pos.lerp(target_global, 0.5) + Vector3(0.0, 0.56, 0.0)

	var holder_wr: WeakRef = weakref(holder)
	var flask_wr: WeakRef = weakref(flask)
	var trail_acc := {"t": 0.0}

	# Act I: Ignite & lift off coaster with dramatic swirl
	FxLib.ring(table_node, coaster_global + Vector3(0.0, 0.015, 0.0), Color(1.0, 0.46, 0.12), 0.42, act1_dur * 0.9, 0.10, 2.2, 8.0)
	FxLib.embers(table_node, coaster_global + Vector3(0.0, 0.12, 0.0), 22, 0.9)

	var tw := holder.create_tween()
	tw.tween_method(func(u: float):
		var f := flask_wr.get_ref() as Node3D
		if not is_instance_valid(f):
			return
		var ease_u := 1.0 - pow(1.0 - u, 2.5)
		f.global_position = coaster_global.lerp(lift_pos, ease_u)
		f.rotation_degrees = Vector3(sin(u * PI) * 14.0, u * 360.0, sin(u * TAU) * 8.0)
		f.scale = Vector3.ONE * lerpf(1.0, 1.24, ease_u)
	, 0.0, 1.0, act1_dur)

	# Act II: Parabolic heroic throw across table leaving flame sparks
	tw.tween_method(func(u: float):
		var f := flask_wr.get_ref() as Node3D
		var h := holder_wr.get_ref() as Node3D
		if not is_instance_valid(f) or not is_instance_valid(h):
			return
		var a := lift_pos.lerp(apex_mid, u)
		var b := apex_mid.lerp(target_global, u)
		f.global_position = a.lerp(b, u)
		f.rotation_degrees = Vector3(u * 540.0, 360.0 + u * 720.0, u * 360.0)
		f.scale = Vector3.ONE * lerpf(1.24, 1.35, sin(u * PI * 0.5))
		trail_acc["t"] += 1.0
		if int(trail_acc["t"]) % 3 == 0 and is_instance_valid(table_node):
			FxLib.embers(table_node, f.global_position, 5, 0.6)
	, 0.0, 1.0, act2_dur)

	# Act III: Impact hitstop + Blender Hellfire Explosion GLB detonation
	tw.tween_callback(func():
		var f := flask_wr.get_ref() as Node3D
		var h := holder_wr.get_ref() as Node3D
		if is_instance_valid(f):
			f.visible = false
		if on_impact_cb.is_valid():
			on_impact_cb.call()
		if is_instance_valid(h) and is_instance_valid(table_node) and table_node.is_inside_tree():
			var expl := _instantiate_glb(PATH_PHIAL_EXPLOSION)
			if expl != null:
				_disable_shadows_recursive(expl)
				var exp_lgt := OmniLight3D.new()
				exp_lgt.position = Vector3(0.0, 0.35, 0.0)
				exp_lgt.light_color = Color(1.0, 0.46, 0.12)
				exp_lgt.light_energy = 7.5
				exp_lgt.omni_range = 3.8
				expl.add_child(exp_lgt)
				h.add_child(expl)
				expl.global_position = target_global
				_play_embedded_anim(expl, 3.0 / maxf(1.2, act3_dur + act4_dur), false)
				var ltw := exp_lgt.create_tween()
				ltw.tween_property(exp_lgt, "light_energy", 0.0, act3_dur + act4_dur * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	tw.tween_interval(act3_dur + act4_dur)
	tw.tween_callback(func():
		if on_complete_cb.is_valid():
			on_complete_cb.call()
		var h := holder_wr.get_ref() as Node3D
		if is_instance_valid(h):
			h.queue_free()
	)
	return holder


static func play_defeat_execution_anim(
	table_node: Node3D,
	loser_is_player: bool,
	center_global: Vector3,
	loser_global: Vector3,
	on_impact_cb: Callable = Callable(),
	on_complete_cb: Callable = Callable()
) -> Node3D:
	if not is_instance_valid(table_node) or not table_node.is_inside_tree():
		return null

	var rig := _instantiate_glb(PATH_DEFEAT_EXEC)
	if rig == null:
		return null
	rig.name = "BlenderDefeatExecutionRig"
	_disable_shadows_recursive(rig)

	if loser_is_player:
		# Crimson-Obsidian Doom palette when Player loses
		_tint_materials(rig, PackedStringArray(["Mat_BladeRune"]), Color(1.0, 0.16, 0.22), 5.2)
		_tint_materials(rig, PackedStringArray(["Mat_EclipseGlow"]), Color(0.95, 0.12, 0.18), 4.0)
		_tint_materials(rig, PackedStringArray(["Mat_ShadowFlame"]), Color(0.75, 0.08, 0.14), 3.2)
		_tint_materials(rig, PackedStringArray(["Mat_CrownGold"]), Color(0.98, 0.80, 0.28), 0.7)
	else:
		# Solar Gold-Crimson Sovereign Triumph palette when Rival loses
		_tint_materials(rig, PackedStringArray(["Mat_BladeRune"]), Color(1.0, 0.84, 0.24), 5.2)
		_tint_materials(rig, PackedStringArray(["Mat_EclipseGlow"]), Color(1.0, 0.56, 0.18), 3.8)
		_tint_materials(rig, PackedStringArray(["Mat_ShadowFlame"]), Color(1.0, 0.42, 0.12), 3.0)
		_tint_materials(rig, PackedStringArray(["Mat_CrownGold"]), Color(0.24, 0.18, 0.28), 0.4)

	var exec_lgt := OmniLight3D.new()
	exec_lgt.position = Vector3(0.0, 0.65, 0.0)
	exec_lgt.light_color = Color(1.0, 0.22, 0.22) if loser_is_player else Color(1.0, 0.78, 0.26)
	exec_lgt.light_energy = 3.2
	exec_lgt.omni_range = 3.8
	rig.add_child(exec_lgt)

	table_node.add_child(rig)
	var stage_pos := center_global.lerp(loser_global, 0.35)
	rig.global_position = Vector3(stage_pos.x, maxf(table_node.global_position.y + 0.82, center_global.y), stage_pos.z)

	var dir_xz := Vector3(loser_global.x - center_global.x, 0.0, loser_global.z - center_global.z)
	if dir_xz.length_squared() > 0.001:
		dir_xz = dir_xz.normalized()
		rig.rotation.y = atan2(-dir_xz.x, -dir_xz.z)
	else:
		rig.rotation.y = PI if loser_is_player else 0.0

	var dur := _play_embedded_anim(rig, 1.0, false)
	if dur <= 0.0:
		dur = 4.5

	# Frame 55 of 108 @ 24fps is exact cleave & crown shatter (~2.28s)
	var impact_delay := clampf(dur * (55.0 / 108.0), 1.6, 2.6)
	var complete_delay := maxf(4.30, dur - 0.15)
	var lgt_wr: WeakRef = weakref(exec_lgt)
	var rig_wr: WeakRef = weakref(rig)

	table_node.get_tree().create_timer(impact_delay, true, false, true).timeout.connect(func():
		var l_inst := lgt_wr.get_ref() as OmniLight3D
		if is_instance_valid(l_inst):
			l_inst.light_energy = 8.5
			var ltw := l_inst.create_tween()
			ltw.tween_property(l_inst, "light_energy", 1.8, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if on_impact_cb.is_valid():
			on_impact_cb.call()
	)
	table_node.get_tree().create_timer(complete_delay, true, false, true).timeout.connect(func():
		if on_complete_cb.is_valid():
			on_complete_cb.call()
	)
	_auto_free_after(table_node, rig, dur + 0.5)
	return rig
