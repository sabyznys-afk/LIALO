class_name CinematicDirector
extends Node

## Reusable 3D Cutscene & Camera Director Engine for LIALO Task #9:
## Drives full 2.6-3.8s dramatic cutscenes for ALL 15 active Special Cards (SPEC_*)
## and ALL Opponent / Boss Turns with:
##   - Multi-shot Camera3D cuts, Dutch rolls, slow push-ins & climax camera shake
##   - Gold-trimmed dark-tavern letterbox cinema bars & engraved title/subtitle banner
##   - Temporary dramatic SpotLight3D + OmniLight3D mood lighting & table dimming
##   - Blender 5.3 animated 3D VFX GLB spawning, material tinting & AnimationPlayer sync
##   - Smooth procedural choreography of Opponent 3D rig pivots (TorsoPivot, HeadPivot,
##     ArmLPivot, ArmRPivot, EyeL, EyeR with graceful fallback to legacy opp_*_node)
##   - Exact climax hitstop on_impact trigger & safe instant skip_current() completion.

const CineProfiles = preload("res://scripts/cinematic_profiles.gd")
const Fx = preload("res://scripts/fx_lib.gd")
const SwordCardAnim = preload("res://scripts/sword_card_animator.gd")
const TYBW_IMPACT_SHADER := preload("res://shaders/tybw_impact.gdshader")

signal cinematic_started(profile_id: String)
signal cinematic_impact(profile_id: String)
signal cinematic_finished(profile_id: String, skipped: bool)
signal sfx_requested(sfx_key: String, vol_db: float, pitch: float)

static var _glb_cache: Dictionary = {}

var _host_table: Node3D = null
var _cam: Camera3D = null
var _hud_layer: Control = null
var _display_font: Font = null
var _opp_root: Node3D = null

# Resolved Opponent 3D Rig Pivots
var _torso_pivot: Node3D = null
var _head_pivot: Node3D = null
var _arm_l_pivot: Node3D = null
var _arm_r_pivot: Node3D = null
var _eye_l: Node3D = null
var _eye_r: Node3D = null
var _saved_pivot_transforms: Dictionary = {}

# Saved Camera & Host Lighting State
var _saved_cam_transform: Transform3D = Transform3D.IDENTITY
var _saved_cam_fov: float = 60.0
var _saved_cam_h_offset: float = 0.0
var _saved_cam_v_offset: float = 0.0
var _has_saved_cam: bool = false

# Active Playback State
var _playing: bool = false
var _active_profile: Dictionary = {}
var _active_profile_id: String = ""
var _is_rival_turn: bool = false
var _is_cs: bool = false
var _elapsed: float = 0.0
var _duration: float = 3.0
var _hitstop_at: float = 1.75
var _manifest_fired: bool = false
var _impact_fired: bool = false
var _tail_fired: bool = false
var _tybw_style: String = "getsuga"
var _vfx_scale: float = 1.5
var _impact_flash_t: float = 0.0
var _slash_t: float = 0.0
var _pose_key: String = "lean_slam"
var _card_world_pos: Vector3 = Vector3.ZERO
var _rival_world_pos: Vector3 = Vector3.ZERO
var _card_local_pos: Vector3 = Vector3(0.14, 0.82, -0.02)
var _rival_local_pos: Vector3 = Vector3(0.0, 0.95, -1.35)
var _shake_amp: float = 0.0
var _fov_punch: float = 0.0
var _on_impact_cb: Callable = Callable()
var _on_finished_cb: Callable = Callable()

# Spawned 3D Cutscene Nodes
var _active_vfx_node: Node3D = null
var _active_key_spot: SpotLight3D = null
var _active_rim_omni: OmniLight3D = null

# Letterbox & Banner UI Overlay Nodes + Fullscreen Impact Overlay
var _overlay_root: Control = null
var _tybw_rect: ColorRect = null
var _tybw_mat: ShaderMaterial = null
var _top_bar: Control = null
var _bottom_bar: Control = null
var _banner_container: Control = null
var _title_lbl: Label = null
var _subtitle_lbl: Label = null
var _bar_anim_t: float = 0.0
var _banner_accent: Color = Color(1.0, 0.82, 0.28)
var _saved_hud_vis: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	set_process(true)


func setup(host_table: Node3D, cam: Camera3D, hud_layer: Control, display_font: Font) -> void:
	_host_table = host_table
	_cam = cam
	_hud_layer = hud_layer
	_display_font = display_font if display_font != null else ThemeDB.fallback_font
	_build_letterbox_overlay()
	if _opp_root == null and is_instance_valid(_host_table):
		var opp_candidate: Variant = _host_table.get("opp_silhouette_root")
		if opp_candidate is Node3D and is_instance_valid(opp_candidate):
			set_opponent_rig(opp_candidate as Node3D)


func set_opponent_rig(opp_root: Node3D) -> void:
	_opp_root = opp_root
	_resolve_opponent_pivots()


func is_playing() -> bool:
	return _playing


func play_special_card_cinematic(
	card_id: String,
	card_pos: Vector3,
	rival_pos: Vector3,
	is_cs: bool,
	on_impact: Callable,
	on_finished: Callable
) -> void:
	var profile := CineProfiles.get_special_card_profile(card_id)
	_start_cinematic_from_profile(profile, false, "", card_pos, rival_pos, is_cs, on_impact, on_finished)


func play_rival_turn_cinematic(
	era_id: String,
	is_boss: bool,
	play_label: String,
	card_pos: Vector3,
	rival_pos: Vector3,
	is_cs: bool,
	on_impact: Callable,
	on_finished: Callable
) -> void:
	var profile := CineProfiles.get_rival_turn_profile(era_id, is_boss)
	_start_cinematic_from_profile(profile, true, play_label, card_pos, rival_pos, is_cs, on_impact, on_finished)


func skip_current() -> void:
	if not _playing:
		return
	var imp_cb := _on_impact_cb
	var fin_cb := _on_finished_cb
	var need_impact := not _impact_fired
	var pid := _active_profile_id
	_impact_fired = true
	_cleanup_active_cutscene(true)
	if need_impact and imp_cb.is_valid():
		imp_cb.call()
	emit_signal("cinematic_finished", pid, true)
	if fin_cb.is_valid():
		fin_cb.call()


# =============================================================================
# INTERNAL CUTSCENE LIFECYCLE & CHOREOGRAPHY
# =============================================================================
func _start_cinematic_from_profile(
	profile: Dictionary,
	is_rival: bool,
	play_label: String,
	card_pos: Vector3,
	rival_pos: Vector3,
	is_cs: bool,
	on_impact: Callable,
	on_finished: Callable
) -> void:
	if _playing:
		# Safely clean up any interrupted cutscene without losing original camera base
		_cleanup_active_cutscene(false)

	_active_profile = profile
	_active_profile_id = str(profile.get("id", "cinematic"))
	_is_rival_turn = is_rival
	_is_cs = is_cs
	_duration = clampf(float(profile.get("duration", 5.5)), 2.5, 8.0)
	_hitstop_at = clampf(float(profile.get("hitstop_at", _duration * 0.60)), 0.8, _duration - 0.35)
	_tybw_style = str(profile.get("tybw_style", "getsuga"))
	_vfx_scale = clampf(float(profile.get("vfx_scale", 1.50)), 1.0, 2.2)
	_pose_key = str(profile.get("opponent_pose_key", "lean_slam" if is_rival else "recoil_stagger"))
	_elapsed = 0.0
	_manifest_fired = false
	_impact_fired = false
	_tail_fired = false
	_impact_flash_t = 0.0
	_slash_t = 0.0
	_shake_amp = 0.0
	_fov_punch = 0.0
	_on_impact_cb = on_impact
	_on_finished_cb = on_finished

	_card_world_pos = card_pos
	_rival_world_pos = rival_pos
	if is_instance_valid(_host_table):
		_card_local_pos = _host_table.to_local(card_pos)
		_rival_local_pos = _host_table.to_local(rival_pos)
	else:
		_card_local_pos = card_pos
		_rival_local_pos = rival_pos

	# Save pre-cutscene camera state
	if is_instance_valid(_cam):
		_saved_cam_transform = _cam.transform
		_saved_cam_fov = _cam.fov
		_saved_cam_h_offset = _cam.h_offset
		_saved_cam_v_offset = _cam.v_offset
		_has_saved_cam = true

	# Resolve & snapshot opponent rig pivots
	_resolve_opponent_pivots()
	_snapshot_pivot_transforms()

	# Pure widescreen cinema: temporarily hide non-cinematic HUD siblings during the cutscene
	_set_sibling_hud_hidden(true)

	# Configure banner copy & accent color
	_banner_accent = profile.get("accent_color", Color(1.0, 0.82, 0.28))
	var title_txt := str(profile.get("title_cs" if is_cs else "title_en", "DRAMATIC PLAY"))
	var sub_txt := str(profile.get("subtitle_cs" if is_cs else "subtitle_en", ""))
	if play_label.strip_edges() != "":
		if sub_txt != "":
			sub_txt = play_label.strip_edges().to_upper() + "  •  " + sub_txt
		else:
			sub_txt = play_label.strip_edges().to_upper()
	_show_letterbox_banner(title_txt, sub_txt, _banner_accent)

	# Apply dramatic table dimming on host_table if supported
	_set_host_dramatic_lighting(0.76, _banner_accent)

	# Spawn dramatic mood lighting & 3D Blender VFX rig
	_spawn_cutscene_lights(profile)
	_spawn_cutscene_vfx_glb(profile)

	_playing = true
	_update_camera_choreography(0.0)
	_update_opponent_pose_choreography(0.0)
	if not _is_rival_turn:
		match _active_profile_id:
			"SPEC_VAMPIRE":
				emit_signal("sfx_requested", "power_vampire_cast", -2.5, 1.0)
			"SPEC_STORM":
				emit_signal("sfx_requested", "power_storm_cast", -2.5, 1.0)
	emit_signal("cinematic_started", _active_profile_id)


func _process(delta: float) -> void:
	if not _playing:
		return
	var dt := clampf(delta, 0.001, 0.1)
	_elapsed += dt

	# Animate letterbox bar reveal &退場
	var enter_u := clampf(_elapsed / 0.22, 0.0, 1.0)
	var exit_u := clampf((_duration - _elapsed) / 0.26, 0.0, 1.0)
	_bar_anim_t = minf(enter_u, exit_u)
	_update_letterbox_visuals()

	# Act II Manifestation burst (~34% through cutscene: soaring Aura Pillar / Astral Volley)
	if not _manifest_fired and _elapsed >= _duration * 0.34:
		_manifest_fired = true
		_shake_amp = maxf(_shake_amp, 0.022)
		_fov_punch = -2.2
		_trigger_tybw_manifest_fx()
		if not _is_rival_turn:
			if _active_profile_id == "SPEC_VAMPIRE":
				emit_signal("sfx_requested", "power_vampire_shift", -2.5, 1.0)
			elif _active_profile_id == "SPEC_STORM":
				emit_signal("sfx_requested", "power_storm_shift", -2.5, 1.0)

	# Check climax impact timestamp (Act III: Impact Frame + Diagonal Slash + Climax Strike!)
	if not _impact_fired and _elapsed >= _hitstop_at:
		_impact_fired = true
		_shake_amp = 0.056
		_fov_punch = -6.8
		_impact_flash_t = 1.0
		_slash_t = 1.0
		_pulse_lights_on_impact()
		_trigger_tybw_climax_fx()
		if not _is_rival_turn:
			if _active_profile_id == "SPEC_VAMPIRE":
				emit_signal("sfx_requested", "power_vampire_impact", -1.5, 1.0)
			elif _active_profile_id == "SPEC_STORM":
				emit_signal("sfx_requested", "power_storm_impact", -1.5, 1.0)
		emit_signal("cinematic_impact", _active_profile_id)
		if _on_impact_cb.is_valid():
			_on_impact_cb.call()

	# Act IV Aftermath tail stem
	if not _tail_fired and _impact_fired and _elapsed >= minf(_hitstop_at + 0.85, _duration - 0.35):
		_tail_fired = true
		if not _is_rival_turn:
			if _active_profile_id == "SPEC_VAMPIRE":
				emit_signal("sfx_requested", "power_vampire_tail", -3.0, 1.0)
			elif _active_profile_id == "SPEC_STORM":
				emit_signal("sfx_requested", "power_storm_tail", -3.0, 1.0)

	# Decay impact frame, slash line, camera shake & FOV punch
	_impact_flash_t = maxf(0.0, _impact_flash_t - dt * 4.6)
	_slash_t = maxf(0.0, _slash_t - dt * 2.1)
	_update_tybw_overlay_uniforms()
	_shake_amp = move_toward(_shake_amp, 0.0, dt * 0.088)
	_fov_punch = lerpf(_fov_punch, 0.0, clampf(dt * 7.5, 0.0, 1.0))

	_update_camera_choreography(dt)
	_update_opponent_pose_choreography(dt)

	if _elapsed >= _duration:
		var fin_cb := _on_finished_cb
		var pid := _active_profile_id
		_cleanup_active_cutscene(true)
		emit_signal("cinematic_finished", pid, false)
		if fin_cb.is_valid():
			fin_cb.call()


func _cleanup_active_cutscene(restore_cam: bool) -> void:
	_playing = false
	_on_impact_cb = Callable()
	_on_finished_cb = Callable()

	if is_instance_valid(_active_vfx_node):
		_active_vfx_node.queue_free()
	_active_vfx_node = null

	if is_instance_valid(_active_key_spot):
		_active_key_spot.queue_free()
	_active_key_spot = null

	if is_instance_valid(_active_rim_omni):
		_active_rim_omni.queue_free()
	_active_rim_omni = null

	_restore_pivot_transforms()
	_set_host_dramatic_lighting(0.0, Color(0.85, 0.16, 0.18))

	if restore_cam and _has_saved_cam and is_instance_valid(_cam):
		_cam.transform = _saved_cam_transform
		_cam.fov = _saved_cam_fov
		_cam.h_offset = _saved_cam_h_offset
		_cam.v_offset = _saved_cam_v_offset
	_has_saved_cam = false

	if is_instance_valid(_tybw_mat):
		_tybw_mat.set_shader_parameter("impact_amount", 0.0)
		_tybw_mat.set_shader_parameter("invert_flash", 0.0)
		_tybw_mat.set_shader_parameter("speedline_strength", 0.0)
		_tybw_mat.set_shader_parameter("slash_strength", 0.0)
		_tybw_mat.set_shader_parameter("pressure_darkness", 0.0)

	if is_instance_valid(_overlay_root):
		_overlay_root.visible = false
	_set_sibling_hud_hidden(false)


func _set_sibling_hud_hidden(hide_siblings: bool) -> void:
	if not is_instance_valid(_hud_layer):
		return
	if hide_siblings:
		if _saved_hud_vis.is_empty():
			for ch in _hud_layer.get_children():
				if ch == _overlay_root:
					continue
				if ch is CanvasItem:
					var ci := ch as CanvasItem
					_saved_hud_vis[ci.get_instance_id()] = {"node": ci, "vis": ci.visible}
					ci.visible = false
	else:
		for k in _saved_hud_vis.keys():
			var e: Dictionary = _saved_hud_vis[k]
			var ci := e.get("node") as CanvasItem
			if is_instance_valid(ci):
				ci.visible = bool(e.get("vis", true))
		_saved_hud_vis.clear()


# =============================================================================
# CAMERA 3D MULTI-SHOT CHOREOGRAPHY
# =============================================================================
func _update_camera_choreography(_dt: float) -> void:
	if not is_instance_valid(_cam):
		return
	var shots: Array = _active_profile.get("camera_shots", [])
	if shots.is_empty():
		return

	var active_idx := 0
	for i in range(shots.size()):
		var st := float((shots[i] as Dictionary).get("time", 0.0))
		if _elapsed >= st:
			active_idx = i
		else:
			break

	var cur_shot: Dictionary = shots[active_idx]
	var shot_start := float(cur_shot.get("time", 0.0))
	var shot_end := _duration
	if active_idx + 1 < shots.size():
		shot_end = float((shots[active_idx + 1] as Dictionary).get("time", _duration))
	var shot_span := maxf(0.08, shot_end - shot_start)
	var shot_u := clampf((_elapsed - shot_start) / shot_span, 0.0, 1.0)

	var target_local_pos: Vector3 = cur_shot.get("pos", Vector3(0.0, 1.45, 1.15))
	var target_local_look: Vector3 = cur_shot.get("look_at", Vector3(0.0, 0.95, -0.35))
	var target_fov: float = float(cur_shot.get("fov", 46.0))
	var target_roll: float = float(cur_shot.get("roll", 0.0))
	var trans_mode := str(cur_shot.get("trans", "cut")).to_lower()

	if (trans_mode == "cubic" or trans_mode == "orbit") and active_idx > 0:
		var prev_shot: Dictionary = shots[active_idx - 1]
		var prev_pos: Vector3 = prev_shot.get("pos", target_local_pos)
		var prev_look: Vector3 = prev_shot.get("look_at", target_local_look)
		var prev_fov: float = float(prev_shot.get("fov", target_fov))
		var prev_roll: float = float(prev_shot.get("roll", 0.0))
		var s_u := shot_u * shot_u * (3.0 - 2.0 * shot_u)
		if trans_mode == "orbit":
			# Dramatic curved crane arc sweeping around the arena centerpiece
			var mid_arc := prev_pos.lerp(target_local_pos, 0.5) + Vector3(0.0, 0.24, 0.34)
			var p0 := prev_pos.lerp(mid_arc, s_u)
			var p1 := mid_arc.lerp(target_local_pos, s_u)
			target_local_pos = p0.lerp(p1, s_u)
		else:
			target_local_pos = prev_pos.lerp(target_local_pos, s_u)
		target_local_look = prev_look.lerp(target_local_look, s_u)
		target_fov = lerpf(prev_fov, target_fov, s_u)
		target_roll = lerpf(prev_roll, target_roll, s_u)
	else:
		# Dramatic slow push-in during hard-cut shots so every camera angle breathes
		var push_dir := (target_local_look - target_local_pos)
		target_local_pos = target_local_pos + push_dir * (shot_u * 0.095)
		target_fov = target_fov - shot_u * 2.4

	var world_pos := _host_table.to_global(target_local_pos) if is_instance_valid(_host_table) else target_local_pos
	var world_look := _host_table.to_global(target_local_look) if is_instance_valid(_host_table) else target_local_look

	if _shake_amp > 0.0005:
		var t_s := _elapsed * 58.0
		world_pos += Vector3(
			sin(t_s * 1.3) * _shake_amp,
			cos(t_s * 1.7) * _shake_amp * 0.85,
			sin(t_s * 0.9) * _shake_amp * 0.5
		)

	if world_pos.distance_squared_to(world_look) > 0.0004:
		_cam.look_at_from_position(world_pos, world_look, Vector3.UP)
		if absf(target_roll) > 0.01:
			_cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(target_roll))
	_cam.fov = clampf(target_fov + _fov_punch, 28.0, 78.0)
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0


# =============================================================================
# OPPONENT 3D RIG PIVOT RESOLUTION & CHOREOGRAPHY
# Supports @opponents-3d contract: TorsoPivot, HeadPivot, ArmLPivot, ArmRPivot, EyeL, EyeR
# with graceful fallback to legacy opp_torso_node, opp_head_node, opp_arm_left_node, opp_arm_right_node
# =============================================================================
func _resolve_opponent_pivots() -> void:
	_torso_pivot = null
	_head_pivot = null
	_arm_l_pivot = null
	_arm_r_pivot = null
	_eye_l = null
	_eye_r = null

	if not is_instance_valid(_opp_root) and is_instance_valid(_host_table):
		var cand: Variant = _host_table.get("opp_silhouette_root")
		if cand is Node3D and is_instance_valid(cand):
			_opp_root = cand as Node3D

	if is_instance_valid(_opp_root):
		_torso_pivot = _opp_root.find_child("TorsoPivot", true, false) as Node3D
		_head_pivot = _opp_root.find_child("HeadPivot", true, false) as Node3D
		_arm_l_pivot = _opp_root.find_child("ArmLPivot", true, false) as Node3D
		_arm_r_pivot = _opp_root.find_child("ArmRPivot", true, false) as Node3D
		_eye_l = _opp_root.find_child("EyeL", true, false) as Node3D
		_eye_r = _opp_root.find_child("EyeR", true, false) as Node3D

	if is_instance_valid(_host_table):
		if _torso_pivot == null:
			var tn: Variant = _host_table.get("opp_torso_node")
			if tn is Node3D and is_instance_valid(tn):
				_torso_pivot = tn as Node3D
		if _head_pivot == null:
			var hn: Variant = _host_table.get("opp_head_node")
			if hn is Node3D and is_instance_valid(hn):
				_head_pivot = hn as Node3D
		if _arm_l_pivot == null:
			var aln: Variant = _host_table.get("opp_arm_left_node")
			if aln is Node3D and is_instance_valid(aln):
				_arm_l_pivot = aln as Node3D
		if _arm_r_pivot == null:
			var arn: Variant = _host_table.get("opp_arm_right_node")
			if arn is Node3D and is_instance_valid(arn):
				_arm_r_pivot = arn as Node3D
		if _eye_l == null:
			var el: Variant = _host_table.get("boss_eye_left")
			if el is Node3D and is_instance_valid(el):
				_eye_l = el as Node3D
		if _eye_r == null:
			var er: Variant = _host_table.get("boss_eye_right")
			if er is Node3D and is_instance_valid(er):
				_eye_r = er as Node3D


func _snapshot_pivot_transforms() -> void:
	_saved_pivot_transforms.clear()
	for piv in [_torso_pivot, _head_pivot, _arm_l_pivot, _arm_r_pivot, _eye_l, _eye_r]:
		if is_instance_valid(piv):
			_saved_pivot_transforms[piv.get_instance_id()] = {
				"node": piv,
				"pos": piv.position,
				"rot": piv.rotation_degrees,
				"scale": piv.scale,
			}


func _restore_pivot_transforms() -> void:
	for k in _saved_pivot_transforms.keys():
		var entry: Dictionary = _saved_pivot_transforms[k]
		var n := entry.get("node") as Node3D
		if is_instance_valid(n):
			n.position = entry["pos"]
			n.rotation_degrees = entry["rot"]
			n.scale = entry["scale"]
	_saved_pivot_transforms.clear()


func _apply_pivot_offset(piv: Node3D, pos_off: Vector3, rot_off: Vector3, scale_mult: Vector3 = Vector3.ONE) -> void:
	if not is_instance_valid(piv):
		return
	var id := piv.get_instance_id()
	if not _saved_pivot_transforms.has(id):
		return
	var base: Dictionary = _saved_pivot_transforms[id]
	var b_pos: Vector3 = base["pos"]
	var b_rot: Vector3 = base["rot"]
	var b_sc: Vector3 = base["scale"]
	piv.position = b_pos + pos_off
	piv.rotation_degrees = b_rot + rot_off
	piv.scale = Vector3(b_sc.x * scale_mult.x, b_sc.y * scale_mult.y, b_sc.z * scale_mult.z)


func _update_opponent_pose_choreography(_dt: float) -> void:
	var pre_u := clampf(_elapsed / maxf(0.25, _hitstop_at), 0.0, 1.0)
	var post_u := clampf((_elapsed - _hitstop_at) / maxf(0.25, _duration - _hitstop_at), 0.0, 1.0)
	var windup := sin(pre_u * PI * 0.5)
	var strike := 0.0
	if _elapsed < _hitstop_at:
		strike = pow(pre_u, 2.4) * 0.35
	else:
		strike = 1.0 - smoothstep(0.0, 1.0, post_u)

	var torso_pos := Vector3.ZERO
	var torso_rot := Vector3.ZERO
	var head_rot := Vector3.ZERO
	var arm_l_rot := Vector3.ZERO
	var arm_r_rot := Vector3.ZERO
	var eye_scale := Vector3.ONE

	match _pose_key:
		"lean_slam":
			if _elapsed < _hitstop_at:
				torso_rot = Vector3(-10.0 * windup, -4.0 * windup, 0.0)
				head_rot = Vector3(12.0 * windup, 4.0 * windup, 0.0)
				arm_l_rot = Vector3(-16.0 * windup, 10.0 * windup, -12.0 * windup)
				arm_r_rot = Vector3(-54.0 * windup, -14.0 * windup, 22.0 * windup)
			else:
				torso_pos = Vector3(0.0, -0.02 * strike, 0.08 * strike)
				torso_rot = Vector3(18.0 * strike, 3.0 * strike, 0.0)
				head_rot = Vector3(-8.0 * strike, 0.0, 0.0)
				arm_l_rot = Vector3(14.0 * strike, -8.0 * strike, -10.0 * strike)
				arm_r_rot = Vector3(32.0 * strike, 10.0 * strike, -14.0 * strike)
				eye_scale = Vector3.ONE * (1.0 + 0.32 * strike)

		"taunt_raise":
			if _elapsed < _hitstop_at:
				torso_rot = Vector3(-7.0 * windup, -11.0 * windup, 3.0 * windup)
				head_rot = Vector3(-10.0 * windup, 15.0 * windup, -7.0 * windup)
				arm_l_rot = Vector3(-38.0 * windup, 18.0 * windup, -22.0 * windup)
				arm_r_rot = Vector3(-46.0 * windup, -16.0 * windup, 24.0 * windup)
			else:
				torso_pos = Vector3(0.0, 0.0, 0.06 * strike)
				torso_rot = Vector3(14.0 * strike, 6.0 * strike, -2.0 * strike)
				head_rot = Vector3(6.0 * strike, -8.0 * strike, 4.0 * strike)
				arm_l_rot = Vector3(-18.0 * strike, 12.0 * strike, -14.0 * strike)
				arm_r_rot = Vector3(26.0 * strike, -14.0 * strike, -10.0 * strike)
				eye_scale = Vector3.ONE * (1.0 + 0.28 * strike)

		"command_wave":
			if _elapsed < _hitstop_at:
				torso_rot = Vector3(-9.0 * windup, 6.0 * windup, 0.0)
				head_rot = Vector3(-8.0 * windup, -6.0 * windup, 0.0)
				arm_l_rot = Vector3(-48.0 * windup, 22.0 * windup, -18.0 * windup)
				arm_r_rot = Vector3(-28.0 * windup, -30.0 * windup, 16.0 * windup)
			else:
				torso_pos = Vector3(0.0, 0.01 * strike, 0.06 * strike)
				torso_rot = Vector3(14.0 * strike, -4.0 * strike, 0.0)
				head_rot = Vector3(10.0 * strike, 4.0 * strike, 0.0)
				arm_l_rot = Vector3(-16.0 * strike, 8.0 * strike, -10.0 * strike)
				arm_r_rot = Vector3(22.0 * strike, 24.0 * strike, -14.0 * strike)
				eye_scale = Vector3.ONE * (1.0 + 0.35 * strike)

		"boss_wrath":
			if _elapsed < _hitstop_at:
				torso_pos = Vector3(0.0, 0.035 * windup, -0.04 * windup)
				torso_rot = Vector3(-15.0 * windup, 0.0, 0.0)
				head_rot = Vector3(-14.0 * windup, sin(_elapsed * 10.0) * 4.0, 0.0)
				arm_l_rot = Vector3(-62.0 * windup, 24.0 * windup, -28.0 * windup)
				arm_r_rot = Vector3(-64.0 * windup, -24.0 * windup, 28.0 * windup)
				eye_scale = Vector3.ONE * (1.0 + 0.45 * windup)
			else:
				var tremor := sin(_elapsed * 42.0) * 3.5 * strike
				torso_pos = Vector3(0.0, -0.025 * strike, 0.11 * strike)
				torso_rot = Vector3(24.0 * strike, tremor * 0.5, 0.0)
				head_rot = Vector3(16.0 * strike, -tremor, 0.0)
				arm_l_rot = Vector3(32.0 * strike, -12.0 * strike, 14.0 * strike)
				arm_r_rot = Vector3(34.0 * strike, 12.0 * strike, -14.0 * strike)
				eye_scale = Vector3.ONE * (1.0 + 0.55 * strike)

		_: # "recoil_stagger" (Player Special Card striking Rival)
			if _elapsed < _hitstop_at:
				torso_rot = Vector3(8.0 * windup, 0.0, 0.0)
				head_rot = Vector3(10.0 * windup, sin(_elapsed * 6.0) * 4.0, 0.0)
				arm_l_rot = Vector3(-14.0 * windup, 8.0 * windup, -8.0 * windup)
				arm_r_rot = Vector3(-14.0 * windup, -8.0 * windup, 8.0 * windup)
			else:
				var stagger_vib := sin(_elapsed * 48.0) * 5.0 * strike
				torso_pos = Vector3(stagger_vib * 0.004, 0.0, -0.09 * strike)
				torso_rot = Vector3(-22.0 * strike, 8.0 * strike + stagger_vib, -6.0 * strike)
				head_rot = Vector3(-25.0 * strike, -14.0 * strike - stagger_vib, 10.0 * strike)
				arm_l_rot = Vector3(-42.0 * strike, 28.0 * strike, -30.0 * strike)
				arm_r_rot = Vector3(-38.0 * strike, -24.0 * strike, 28.0 * strike)
				eye_scale = Vector3(1.0 + 0.25 * strike, maxf(0.35, 1.0 - 0.55 * strike), 1.0)

	_apply_pivot_offset(_torso_pivot, torso_pos, torso_rot)
	_apply_pivot_offset(_head_pivot, Vector3.ZERO, head_rot)
	_apply_pivot_offset(_arm_l_pivot, Vector3.ZERO, arm_l_rot)
	_apply_pivot_offset(_arm_r_pivot, Vector3.ZERO, arm_r_rot)
	_apply_pivot_offset(_eye_l, Vector3.ZERO, Vector3.ZERO, eye_scale)
	_apply_pivot_offset(_eye_r, Vector3.ZERO, Vector3.ZERO, eye_scale)


# =============================================================================
# BLENDER 3D VFX GLB LOADER, MATERIAL TINTING & DRAMATIC MOOD LIGHTING
# =============================================================================
static func _instantiate_vfx_glb(path: String) -> Node3D:
	if _glb_cache.has(path):
		var cached := _glb_cache[path] as PackedScene
		if cached != null:
			var inst := cached.instantiate()
			if inst is Node3D:
				return inst as Node3D
			if inst != null:
				inst.queue_free()
	if ResourceLoader.exists(path):
		var ps := ResourceLoader.load(path) as PackedScene
		if ps != null:
			_glb_cache[path] = ps
			var inst2 := ps.instantiate()
			if inst2 is Node3D:
				return inst2 as Node3D
			if inst2 != null:
				inst2.queue_free()
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


static func _disable_shadows_recursive(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is GeometryInstance3D:
			(cur as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for ch in cur.get_children():
			stack.append(ch)


static func _tint_vfx_materials(root: Node, accent_col: Color) -> void:
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
						var is_accent := ("Mat_CineAccent" in mname) or ("Mat_CardAccent" in mname)
						var is_glow := ("Mat_CineGlow" in mname)
						if is_accent or is_glow:
							var dup := base_mat.duplicate() as BaseMaterial3D
							var c := accent_col.lightened(0.18) if is_glow else accent_col
							dup.albedo_color = Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, dup.albedo_color.a)
							dup.emission_enabled = true
							dup.emission = c
							dup.emission_energy_multiplier = 2.6 if is_glow else 2.1
							mi.set_surface_override_material(si, dup)
		for ch in cur.get_children():
			stack.append(ch)


func _spawn_cutscene_vfx_glb(profile: Dictionary) -> void:
	var parent_3d: Node3D = _host_table if is_instance_valid(_host_table) else (get_parent() as Node3D)
	if not is_instance_valid(parent_3d):
		return
	var glb_path := str(profile.get("vfx_glb_path", CineProfiles.PATH_RIVAL_SLAM))
	var rig := _instantiate_vfx_glb(glb_path)
	if rig == null:
		return
	rig.name = "CinematicDirectorVfxRig"
	_disable_shadows_recursive(rig)
	var accent_col: Color = profile.get("accent_color", Color(1.0, 0.80, 0.24))
	_tint_vfx_materials(rig, accent_col)

	parent_3d.add_child(rig)
	var table_y := parent_3d.global_position.y + 0.818
	rig.global_position = Vector3(_card_world_pos.x, maxf(table_y, _card_world_pos.y), _card_world_pos.z)
	rig.scale = Vector3.ONE * _vfx_scale

	var dir_xz := Vector3(_rival_world_pos.x - _card_world_pos.x, 0.0, _rival_world_pos.z - _card_world_pos.z)
	if dir_xz.length_squared() > 0.001:
		dir_xz = dir_xz.normalized()
		if _is_rival_turn:
			# Rival turn VFX faces from table toward player (+Z)
			rig.rotation.y = atan2(dir_xz.x, dir_xz.z)
		else:
			# Special card VFX faces from table toward rival (-Z)
			rig.rotation.y = atan2(-dir_xz.x, -dir_xz.z)

	var ap := _find_animation_player(rig)
	if ap != null:
		var anim_list := ap.get_animation_list()
		var chosen := ""
		for aname in anim_list:
			if String(aname) != "RESET":
				chosen = String(aname)
				break
		if chosen == "" and not anim_list.is_empty():
			chosen = String(anim_list[0])
		if chosen != "":
			var anim := ap.get_animation(chosen)
			var anim_len := anim.length if anim != null else 3.3
			ap.speed_scale = clampf(anim_len / maxf(1.0, _duration), 0.5, 2.0)
			ap.play(chosen)

	_active_vfx_node = rig


func _spawn_cutscene_lights(profile: Dictionary) -> void:
	var parent_3d: Node3D = _host_table if is_instance_valid(_host_table) else (get_parent() as Node3D)
	if not is_instance_valid(parent_3d):
		return
	var l_col: Color = profile.get("light_color", profile.get("accent_color", Color(1.0, 0.78, 0.28)))
	var l_energy: float = float(profile.get("light_energy", 6.2))

	var spot := SpotLight3D.new()
	spot.name = "CinematicDirectorKeySpot"
	spot.light_color = l_col
	spot.light_energy = l_energy
	spot.spot_range = 5.5
	spot.spot_angle = 42.0
	spot.spot_angle_attenuation = 1.6
	parent_3d.add_child(spot)
	var spot_origin := _card_world_pos + Vector3(0.0, 1.85, 0.35)
	var spot_target := _rival_world_pos if _is_rival_turn else _card_world_pos
	if spot_origin.distance_squared_to(spot_target) > 0.01:
		spot.look_at_from_position(spot_origin, spot_target, Vector3.UP)
	else:
		spot.global_position = spot_origin
	_active_key_spot = spot

	var omni := OmniLight3D.new()
	omni.name = "CinematicDirectorRimOmni"
	omni.light_color = l_col.lightened(0.22)
	omni.light_energy = l_energy * 0.58
	omni.omni_range = 3.2
	omni.omni_attenuation = 1.35
	parent_3d.add_child(omni)
	omni.global_position = (_rival_world_pos + Vector3(0.0, 0.55, 0.25)) if _is_rival_turn else (_card_world_pos + Vector3(0.0, 0.42, 0.0))
	_active_rim_omni = omni


func _pulse_lights_on_impact() -> void:
	var base_e := float(_active_profile.get("light_energy", 6.2))
	if is_instance_valid(_active_key_spot):
		_active_key_spot.light_energy = base_e * 1.55
		var tw := _active_key_spot.create_tween()
		tw.tween_property(_active_key_spot, "light_energy", base_e * 0.65, maxf(0.3, _duration - _hitstop_at)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_active_rim_omni):
		_active_rim_omni.light_energy = base_e * 1.15
		var tw2 := _active_rim_omni.create_tween()
		tw2.tween_property(_active_rim_omni, "light_energy", 0.0, maxf(0.3, _duration - _hitstop_at)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_host_dramatic_lighting(dim_val: float, tint_col: Color) -> void:
	if not is_instance_valid(_host_table):
		return
	if "dramatic_lighting_dim" in _host_table:
		_host_table.set("dramatic_lighting_dim", dim_val)
	if "dramatic_lighting_tint" in _host_table:
		_host_table.set("dramatic_lighting_tint", tint_col)


# =============================================================================
# GOLD-TRIMMED CINEMA LETTERBOX BARS & WOODCUT CALLIGRAPHIC TITLE BANNER
# =============================================================================
func _build_letterbox_overlay() -> void:
	if is_instance_valid(_overlay_root):
		_overlay_root.queue_free()
	_overlay_root = null
	if not is_instance_valid(_hud_layer):
		return

	_overlay_root = Control.new()
	_overlay_root.name = "CinematicDirectorOverlay"
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.z_index = 40
	_overlay_root.visible = false
	_hud_layer.add_child(_overlay_root)

	_tybw_mat = ShaderMaterial.new()
	_tybw_mat.shader = TYBW_IMPACT_SHADER
	_tybw_rect = ColorRect.new()
	_tybw_rect.name = "CinematicImpactOverlay"
	_tybw_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tybw_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tybw_rect.material = _tybw_mat
	_overlay_root.add_child(_tybw_rect)

	_top_bar = Control.new()
	_top_bar.name = "TopCinemaBar"
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_top = 0.0
	_top_bar.offset_bottom = 66.0
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.draw.connect(func(): _draw_cinema_bar(_top_bar, true))
	_overlay_root.add_child(_top_bar)

	_bottom_bar = Control.new()
	_bottom_bar.name = "BottomCinemaBar"
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_top = -66.0
	_bottom_bar.offset_bottom = 0.0
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.draw.connect(func(): _draw_cinema_bar(_bottom_bar, false))
	_overlay_root.add_child(_bottom_bar)

	_banner_container = Control.new()
	_banner_container.name = "CinematicTitlePlaque"
	_banner_container.anchor_left = 0.5
	_banner_container.anchor_right = 0.5
	_banner_container.anchor_top = 1.0
	_banner_container.anchor_bottom = 1.0
	_banner_container.offset_left = -340.0
	_banner_container.offset_right = 340.0
	_banner_container.offset_top = -142.0
	_banner_container.offset_bottom = -74.0
	_banner_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_container.draw.connect(func(): _draw_banner_plaque(_banner_container))
	_overlay_root.add_child(_banner_container)

	var f := _display_font if _display_font != null else ThemeDB.fallback_font

	_title_lbl = Label.new()
	_title_lbl.name = "TitleLabel"
	_title_lbl.position = Vector2(16.0, 6.0)
	_title_lbl.size = Vector2(648.0, 32.0)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", f)
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	_title_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.02, 0.98))
	_title_lbl.add_theme_constant_override("outline_size", 7)
	_banner_container.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.name = "SubtitleLabel"
	_subtitle_lbl.position = Vector2(16.0, 38.0)
	_subtitle_lbl.size = Vector2(648.0, 22.0)
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_lbl.add_theme_font_override("font", f)
	_subtitle_lbl.add_theme_font_size_override("font_size", 13)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.96, 0.82, 0.48))
	_subtitle_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.02, 0.96))
	_subtitle_lbl.add_theme_constant_override("outline_size", 5)
	_banner_container.add_child(_subtitle_lbl)


func _show_letterbox_banner(title_txt: String, sub_txt: String, accent_col: Color) -> void:
	if not is_instance_valid(_overlay_root):
		_build_letterbox_overlay()
	if not is_instance_valid(_overlay_root):
		return
	if is_instance_valid(_title_lbl):
		_title_lbl.text = "✦  " + title_txt + "  ✦"
		_title_lbl.add_theme_color_override("font_color", accent_col.lightened(0.55))
	if is_instance_valid(_subtitle_lbl):
		_subtitle_lbl.text = sub_txt
		_subtitle_lbl.add_theme_color_override("font_color", accent_col.lightened(0.25))
	_bar_anim_t = 0.0
	_overlay_root.visible = true
	_update_letterbox_visuals()


func _update_letterbox_visuals() -> void:
	if not is_instance_valid(_overlay_root):
		return
	var h := 64.0 * _bar_anim_t
	if is_instance_valid(_top_bar):
		_top_bar.offset_top = 0.0
		_top_bar.offset_bottom = h
		_top_bar.queue_redraw()
	if is_instance_valid(_bottom_bar):
		_bottom_bar.offset_top = -h
		_bottom_bar.offset_bottom = 0.0
		_bottom_bar.queue_redraw()
	if is_instance_valid(_banner_container):
		_banner_container.modulate.a = clampf(_bar_anim_t * 1.15, 0.0, 1.0)
		_banner_container.queue_redraw()


func _draw_cinema_bar(ctrl: Control, is_top: bool) -> void:
	var sz := ctrl.size
	if sz.x < 4.0 or sz.y < 2.0:
		return
	ctrl.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.016, 0.012, 0.020, 0.94))
	var edge_y := sz.y - 2.0 if is_top else 2.0
	var inner_y := sz.y - 5.0 if is_top else 5.0
	var brass := _banner_accent.lerp(Color(0.86, 0.66, 0.26), 0.55)
	ctrl.draw_line(Vector2(0.0, edge_y), Vector2(sz.x, edge_y), Color(brass.r, brass.g, brass.b, 0.88), 2.0)
	ctrl.draw_line(Vector2(24.0, inner_y), Vector2(sz.x - 24.0, inner_y), Color(brass.r, brass.g, brass.b, 0.36), 1.0)
	var cx := sz.x * 0.5
	var r := 4.5
	var diamond := PackedVector2Array([
		Vector2(cx, edge_y - r),
		Vector2(cx + r * 1.6, edge_y),
		Vector2(cx, edge_y + r),
		Vector2(cx - r * 1.6, edge_y),
	])
	ctrl.draw_colored_polygon(diamond, brass.lightened(0.25))


func _trigger_tybw_manifest_fx() -> void:
	var parent_3d: Node3D = _host_table if is_instance_valid(_host_table) else (get_parent() as Node3D)
	if not is_instance_valid(parent_3d):
		return
	var origin := _rival_world_pos if _is_rival_turn else _card_world_pos
	var target := _card_world_pos if _is_rival_turn else _rival_world_pos
	if _tybw_style == "quincy":
		Fx.tybw_quincy_volley(parent_3d, origin, target, 10, _banner_accent)
	else:
		Fx.tybw_reiatsu_pillar(parent_3d, origin, _banner_accent, 2.8, 0.42, 1.35)


func _trigger_tybw_climax_fx() -> void:
	var parent_3d: Node3D = _host_table if is_instance_valid(_host_table) else (get_parent() as Node3D)
	if not is_instance_valid(parent_3d):
		return
	var origin := _rival_world_pos if _is_rival_turn else _card_world_pos
	var target := _card_world_pos if _is_rival_turn else _rival_world_pos
	SwordCardAnim.play_sword_card_score_anim(
		parent_3d,
		{"suit": "CERVEN", "rank": "K", "edition": "NORMAL", "power_id": _active_profile_id, "accent": _banner_accent},
		null,
		not _is_rival_turn,
		_card_world_pos,
		40,
		1.5,
		false
	)
	if _tybw_style == "quincy":
		Fx.tybw_quincy_volley(parent_3d, origin + Vector3(0.0, 0.25, 0.0), target, 12, _banner_accent)
		Fx.tybw_reiatsu_pillar(parent_3d, target, _banner_accent, 2.5, 0.38, 1.10)
	elif _tybw_style == "inferno":
		Fx.tybw_reiatsu_pillar(parent_3d, target, _banner_accent, 3.0, 0.50, 1.25)
		Fx.tybw_slash_arc(parent_3d, origin + Vector3(0.0, 0.28, 0.0), target + Vector3(0.0, 0.25, 0.0), _banner_accent, true, 1.45, -26.0)
	else:
		Fx.tybw_slash_arc(parent_3d, origin + Vector3(0.0, 0.28, 0.0), target + Vector3(0.0, 0.25, 0.0), _banner_accent, true, 1.55, -24.0)
		Fx.tybw_slash_arc(parent_3d, origin + Vector3(0.0, 0.34, 0.0), target + Vector3(0.0, 0.20, 0.0), _banner_accent.lightened(0.25), true, 1.25, 28.0)


func _update_tybw_overlay_uniforms() -> void:
	if not is_instance_valid(_tybw_mat):
		return
	var pre_u := clampf(_elapsed / maxf(0.25, _hitstop_at), 0.0, 1.0)
	var exit_u := clampf((_duration - _elapsed) / 0.55, 0.0, 1.0)
	var pressure := clampf(lerpf(0.26, 0.84, pow(pre_u, 0.7)) * exit_u, 0.0, 0.88)
	var speedlines := 0.0
	if pre_u > 0.42 and not _impact_fired:
		speedlines = clampf((pre_u - 0.42) / 0.58 * 0.72, 0.0, 0.72)
	elif _impact_fired:
		speedlines = clampf(_slash_t * 0.92, 0.0, 0.92)
	# Brief crisp 2-3 frame invert flash right on hitstop impact
	var invert_val := 1.0 if _impact_flash_t > 0.72 else 0.0
	_tybw_mat.set_shader_parameter("accent_col", _banner_accent)
	_tybw_mat.set_shader_parameter("pressure_darkness", pressure)
	_tybw_mat.set_shader_parameter("speedline_strength", speedlines)
	_tybw_mat.set_shader_parameter("impact_amount", _impact_flash_t)
	_tybw_mat.set_shader_parameter("invert_flash", invert_val)
	_tybw_mat.set_shader_parameter("slash_strength", _slash_t)
	_tybw_mat.set_shader_parameter("slash_angle", -0.34 if not _is_rival_turn else 0.34)
	_tybw_mat.set_shader_parameter("slash_progress", clampf(1.2 - _slash_t * 0.95, 0.0, 1.0))


func _draw_banner_plaque(ctrl: Control) -> void:
	var sz := ctrl.size
	if sz.x < 16.0 or sz.y < 12.0:
		return
	# Stark angled ink-slash title card!
	var slant := 22.0
	var poly := PackedVector2Array([
		Vector2(slant, 0.0),
		Vector2(sz.x, 0.0),
		Vector2(sz.x - slant, sz.y),
		Vector2(0.0, sz.y),
	])
	var bg := Color(0.015, 0.010, 0.020, 0.96)
	var accent := _banner_accent
	ctrl.draw_colored_polygon(poly, bg)
	# Blazing razor slash edge top & bottom
	ctrl.draw_line(Vector2(slant, 2.0), Vector2(sz.x, 2.0), accent.lightened(0.18), 3.0)
	ctrl.draw_line(Vector2(0.0, sz.y - 2.0), Vector2(sz.x - slant, sz.y - 2.0), accent, 2.5)
	# Bold vertical crimson/accent ink accent bar on left
	var bar := PackedVector2Array([
		Vector2(slant + 6.0, 4.0),
		Vector2(slant + 16.0, 4.0),
		Vector2(16.0, sz.y - 4.0),
		Vector2(6.0, sz.y - 4.0),
	])
	ctrl.draw_colored_polygon(bar, accent)
	# Subtle white inner highlight line
	ctrl.draw_line(Vector2(slant + 24.0, sz.y * 0.56), Vector2(sz.x - slant - 18.0, sz.y * 0.56), Color(1.0, 0.98, 0.94, 0.28), 1.2)
