class_name FujiraStudioIntro
extends Control

## Universal Portable Studio Intro for Fujira Studios (zero game-specific dependencies).
## Drop-in Control for ANY Fujira Studios game:
##   - Sunrise parchment sky + stylized jagged snow mountain peak (uses optional GLB or procedural mesh)
##   - Detailed ALL-BLACK articulated 3D soaring bird (shoulder + outer elbow wing joints, 7 splayed primaries, 7 tail feathers, ink outline)
##   - Crisp "FUJIRA STUDIOS" emblem reveal + optional internal studio audio player
##   - Supports skippable boot playback OR continuous loop preview in QA/Dev Inspector.

signal intro_finished()
signal sfx_requested(sfx_key: String)

const MOUNTAIN_SHADER_PATH := "res://shaders/mountain.gdshader"
const OUTLINE_SHADER_PATH := "res://shaders/outline.gdshader"
const MOUNTAIN_GLB_PATH := "res://assets/models/krivan_intro_massif.glb"
const ROCK_TEX_PATH := "res://assets/map/mountain_rock.png"
const STUDIO_SFX_PATH := "res://assets/audio/sfx_splash_fujara.wav"
const FONT_DISP_PATH := "res://assets/fonts/LialoDisplay.ttf"

const DURATION: float = 5.30

var skippable: bool = true
var play_internal_audio: bool = true
var loop_preview: bool = false

var _time: float = 0.0
var _active: bool = false
var _finished: bool = false
var _is_headless: bool = false
var _font_disp: Font = null

var _sky_canvas: Control = null
var _vp_container: SubViewportContainer = null
var _vp: SubViewport = null
var _cam: Camera3D = null
var _sun_light: DirectionalLight3D = null
var _rim_light: DirectionalLight3D = null
var _mtn_root: Node3D = null
var _mtn_mat: ShaderMaterial = null
var _snow_particles: GPUParticles3D = null

var _bird_root: Node3D = null
var _bird_wing_l_in: Node3D = null
var _bird_wing_l_out: Node3D = null
var _bird_wing_r_in: Node3D = null
var _bird_wing_r_out: Node3D = null
var _bird_tail_root: Node3D = null
var _bird_trails: Array[Dictionary] = []

var _fg_canvas: Control = null
var _audio_player: AudioStreamPlayer = null
var _snow_flakes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font_disp = load(FONT_DISP_PATH) as Font if ResourceLoader.exists(FONT_DISP_PATH) else ThemeDB.fallback_font
	_build_scene()


func _gui_input(event: InputEvent) -> void:
	if not skippable or not _active or _finished:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip_intro()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not skippable or not _active or _finished:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc := (event as InputEventKey).keycode
		if kc in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			skip_intro()
			get_viewport().set_input_as_handled()


func start_intro(with_audio: bool = true, loop_mode: bool = false) -> void:
	_time = 0.0
	_active = true
	_finished = false
	loop_preview = loop_mode
	visible = true
	if is_instance_valid(_vp):
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if _is_headless else SubViewport.UPDATE_ALWAYS
	if with_audio and play_internal_audio and not _is_headless and is_instance_valid(_audio_player):
		if ResourceLoader.exists(STUDIO_SFX_PATH):
			var st := load(STUDIO_SFX_PATH) as AudioStream
			if st != null:
				_audio_player.stream = st
				_audio_player.volume_db = -3.5
				_audio_player.play()
	sfx_requested.emit("splash_fujara")
	_update_visuals()


func stop_intro() -> void:
	_active = false
	if is_instance_valid(_audio_player):
		_audio_player.stop()
	if is_instance_valid(_vp):
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func skip_intro() -> void:
	if _finished:
		return
	_finished = true
	stop_intro()
	intro_finished.emit()


func set_audio_paused(paused: bool) -> void:
	if is_instance_valid(_audio_player):
		_audio_player.stream_paused = paused


func set_audio_volume_db(vol_db: float) -> void:
	if is_instance_valid(_audio_player):
		_audio_player.volume_db = vol_db


func _build_scene() -> void:
	_sky_canvas = Control.new()
	_sky_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_canvas.draw.connect(_draw_sky)
	add_child(_sky_canvas)

	_vp_container = SubViewportContainer.new()
	_vp_container.anchor_left = 0.0
	_vp_container.anchor_top = 0.0
	_vp_container.anchor_right = 1.0
	_vp_container.anchor_bottom = 0.62
	_vp_container.stretch = true
	_vp_container.clip_contents = true
	_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp_container)

	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(1280, 446)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if _is_headless else SubViewport.UPDATE_ALWAYS
	_vp_container.add_child(_vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.62, 0.52)
	env.ambient_light_energy = 0.55
	we.environment = env
	_vp.add_child(we)

	_sun_light = DirectionalLight3D.new()
	_sun_light.light_color = Color(1.0, 0.86, 0.62)
	_sun_light.light_energy = 1.15
	_sun_light.rotation_degrees = Vector3(-28.0, 52.0, 0.0)
	_sun_light.shadow_enabled = true
	_vp.add_child(_sun_light)

	_rim_light = DirectionalLight3D.new()
	_rim_light.light_color = Color(1.0, 0.78, 0.42)
	_rim_light.light_energy = 0.90
	_rim_light.rotation_degrees = Vector3(14.0, 162.0, 0.0)
	_vp.add_child(_rim_light)

	_cam = Camera3D.new()
	_cam.fov = 26.5
	_cam.position = Vector3(0.0, 0.74, 8.35)
	_vp.add_child(_cam)
	_cam.look_at(Vector3(0.0, 1.30, 0.0), Vector3.UP)

	# Stylized Mountain Peak (portable procedural fallback if GLB absent)
	if ResourceLoader.exists(MOUNTAIN_SHADER_PATH):
		_mtn_mat = ShaderMaterial.new()
		_mtn_mat.shader = load(MOUNTAIN_SHADER_PATH) as Shader
		_mtn_mat.set_shader_parameter("rock_tint", Color(0.84, 0.44, 0.22))
		if ResourceLoader.exists(ROCK_TEX_PATH):
			_mtn_mat.set_shader_parameter("rock_tex", load(ROCK_TEX_PATH) as Texture2D)
		_mtn_mat.set_shader_parameter("uv_scale", Vector2(2.6, 2.6))
		_mtn_mat.set_shader_parameter("peak_height", 3.06)
		_mtn_mat.set_shader_parameter("snow_line_ratio", 1.28)
		_mtn_mat.set_shader_parameter("snow_col", Color(0.96, 0.94, 0.90))
		_mtn_mat.set_shader_parameter("snow_shadow_col", Color(0.50, 0.62, 0.80))
		_mtn_mat.set_shader_parameter("snow_sun_tint", Color(1.0, 0.95, 0.84))
		_mtn_mat.set_shader_parameter("wind_drift_strength", 0.60)
		_mtn_mat.set_shader_parameter("sparkle_strength", 0.55)
		_mtn_mat.set_shader_parameter("shadow_tint", Color(0.42, 0.24, 0.20))
		_mtn_mat.set_shader_parameter("band_soft", 0.055)
		if ResourceLoader.exists(OUTLINE_SHADER_PATH):
			var m_out := ShaderMaterial.new()
			m_out.shader = load(OUTLINE_SHADER_PATH) as Shader
			m_out.set_shader_parameter("thickness", 0.022)
			_mtn_mat.next_pass = m_out

	var loaded_mtn: Node3D = null
	if ResourceLoader.exists(MOUNTAIN_GLB_PATH):
		var ps := load(MOUNTAIN_GLB_PATH) as PackedScene
		if ps != null:
			var inst := ps.instantiate()
			if inst is Node3D:
				loaded_mtn = inst as Node3D
	if loaded_mtn != null:
		_mtn_root = loaded_mtn
		if _mtn_mat != null:
			_apply_mat_rec(_mtn_root, _mtn_mat)
	else:
		_mtn_root = Node3D.new()
		var fb := MeshInstance3D.new()
		fb.mesh = _build_procedural_peak()
		if _mtn_mat != null:
			fb.material_override = _mtn_mat
		else:
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.28, 0.24, 0.22)
			fb.material_override = sm
		_mtn_root.add_child(fb)
	_mtn_root.scale = Vector3.ONE * 0.72
	_mtn_root.position = Vector3(0.0, -2.85, 0.0)
	_vp.add_child(_mtn_root)

	# 3D Fine Summit Snow Particles
	_snow_particles = GPUParticles3D.new()
	_snow_particles.amount = 96
	_snow_particles.lifetime = 3.0
	_snow_particles.emitting = false
	_snow_particles.position = Vector3(-0.2, 2.55, 0.55)
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spm.emission_box_extents = Vector3(3.8, 0.90, 1.4)
	spm.direction = Vector3(0.38, -0.75, 0.08)
	spm.spread = 28.0
	spm.initial_velocity_min = 0.28
	spm.initial_velocity_max = 0.65
	spm.gravity = Vector3(0.14, -0.34, 0.02)
	_snow_particles.process_material = spm
	var sqm := QuadMesh.new()
	sqm.size = Vector2(0.015, 0.015)
	var sq_mat := StandardMaterial3D.new()
	sq_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sq_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sq_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sq_mat.albedo_color = Color(0.98, 0.98, 1.0, 0.50)
	sqm.material = sq_mat
	_snow_particles.draw_pass_1 = sqm
	_vp.add_child(_snow_particles)

	# Ultra-Detailed ALL-BLACK Articulated Soaring Bird ("celý černý")
	_build_all_black_bird()

	for _si in range(34):
		_snow_flakes.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"spd": _rng.randf_range(0.06, 0.16),
			"sz": _rng.randf_range(1.6, 3.8),
			"ph": _rng.randf_range(0.0, TAU),
		})

	_fg_canvas = Control.new()
	_fg_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fg_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg_canvas.draw.connect(_draw_foreground)
	add_child(_fg_canvas)

	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)


func _build_all_black_bird() -> void:
	_bird_root = Node3D.new()
	_bird_root.visible = false
	_bird_root.scale = Vector3.ONE * 0.78
	_vp.add_child(_bird_root)

	# Pure deep matte charcoal-obsidian black + subtle sunrise rim outline
	var mat_black := StandardMaterial3D.new()
	mat_black.albedo_color = Color(0.024, 0.024, 0.028, 1.0)
	mat_black.roughness = 0.72
	mat_black.metallic = 0.05
	if ResourceLoader.exists(OUTLINE_SHADER_PATH):
		var out_m := ShaderMaterial.new()
		out_m.shader = load(OUTLINE_SHADER_PATH) as Shader
		out_m.set_shader_parameter("thickness", 0.007)
		out_m.set_shader_parameter("outline_color", Color(0.01, 0.01, 0.01, 1.0))
		mat_black.next_pass = out_m

	var mat_eye := StandardMaterial3D.new()
	mat_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_eye.albedo_color = Color(0.95, 0.76, 0.26, 1.0)

	# 1. Aerodynamic sculpted torso & breast keel
	var torso := MeshInstance3D.new()
	var t_m := SphereMesh.new()
	t_m.radius = 0.105
	t_m.height = 0.44
	torso.mesh = t_m
	torso.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	torso.scale = Vector3(0.76, 1.0, 0.80)
	torso.material_override = mat_black
	_bird_root.add_child(torso)

	# 2. Curved neck, crested raptor head, fierce brow & hooked black beak
	var neck := MeshInstance3D.new()
	var n_m := CylinderMesh.new()
	n_m.top_radius = 0.052
	n_m.bottom_radius = 0.082
	n_m.height = 0.14
	neck.mesh = n_m
	neck.position = Vector3(0.18, 0.025, 0.0)
	neck.rotation_degrees = Vector3(0.0, 0.0, -76.0)
	neck.material_override = mat_black
	_bird_root.add_child(neck)

	var head := MeshInstance3D.new()
	var h_m := SphereMesh.new()
	h_m.radius = 0.068
	h_m.height = 0.145
	head.mesh = h_m
	head.position = Vector3(0.265, 0.052, 0.0)
	head.rotation_degrees = Vector3(0.0, 0.0, -82.0)
	head.material_override = mat_black
	_bird_root.add_child(head)

	# Swept-back head crest feathers
	for ci in range(3):
		var cr := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.10 - float(ci) * 0.02, 0.012, 0.032)
		cr.mesh = cm
		cr.position = Vector3(0.21 - float(ci) * 0.02, 0.10 - float(ci) * 0.012, 0.0)
		cr.rotation_degrees = Vector3(0.0, 0.0, -18.0)
		cr.material_override = mat_black
		_bird_root.add_child(cr)

	var beak_upper := MeshInstance3D.new()
	var bk := PrismMesh.new()
	bk.size = Vector3(0.048, 0.105, 0.036)
	beak_upper.mesh = bk
	beak_upper.position = Vector3(0.355, 0.042, 0.0)
	beak_upper.rotation_degrees = Vector3(0.0, 0.0, -98.0)
	beak_upper.material_override = mat_black
	_bird_root.add_child(beak_upper)

	var beak_tip := MeshInstance3D.new()
	var bt := PrismMesh.new()
	bt.size = Vector3(0.022, 0.042, 0.020)
	beak_tip.mesh = bt
	beak_tip.position = Vector3(0.402, 0.022, 0.0)
	beak_tip.rotation_degrees = Vector3(0.0, 0.0, -138.0)
	beak_tip.material_override = mat_black
	_bird_root.add_child(beak_tip)

	for side_e in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.011
		em.height = 0.022
		eye.mesh = em
		eye.position = Vector3(0.295, 0.064, side_e * 0.046)
		eye.material_override = mat_eye
		_bird_root.add_child(eye)

		# Tucked dark talons
		var talon := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.016
		tm.bottom_radius = 0.006
		tm.height = 0.11
		talon.mesh = tm
		talon.position = Vector3(-0.08, -0.072, side_e * 0.042)
		talon.rotation_degrees = Vector3(0.0, 0.0, 62.0)
		talon.material_override = mat_black
		_bird_root.add_child(talon)

	# 3. 7 Splayed Black Tail Feathers
	_bird_tail_root = Node3D.new()
	_bird_tail_root.position = Vector3(-0.20, 0.0, 0.0)
	_bird_root.add_child(_bird_tail_root)
	for ti in range(-3, 4):
		var tf := MeshInstance3D.new()
		var tfb := BoxMesh.new()
		tfb.size = Vector3(0.30 - float(abs(ti)) * 0.022, 0.009, 0.048)
		tf.mesh = tfb
		tf.position = Vector3(-0.14, 0.0, float(ti) * 0.036)
		tf.rotation_degrees = Vector3(0.0, float(ti) * -9.5, 4.0)
		tf.material_override = mat_black
		_bird_tail_root.add_child(tf)

	# 4. Two-Joint Articulated All-Black Wings (Shoulder + Elbow + 7 Fanned Primaries each!)
	for side_s in [-1.0, 1.0]:
		var shoulder_piv := Node3D.new()
		shoulder_piv.position = Vector3(0.04, 0.04, side_s * 0.068)
		_bird_root.add_child(shoulder_piv)

		var inner_w := MeshInstance3D.new()
		var iw_b := BoxMesh.new()
		iw_b.size = Vector3(0.24, 0.018, 0.44)
		inner_w.mesh = iw_b
		inner_w.position = Vector3(-0.02, 0.0, side_s * 0.21)
		inner_w.rotation_degrees = Vector3(0.0, side_s * -8.0, 0.0)
		inner_w.material_override = mat_black
		shoulder_piv.add_child(inner_w)

		# Secondary wing coverts
		for sc_i in range(4):
			var cov := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(0.14, 0.010, 0.09)
			cov.mesh = cb
			cov.position = Vector3(-0.14, 0.004, side_s * (0.10 + float(sc_i) * 0.088))
			cov.rotation_degrees = Vector3(0.0, side_s * -10.0, 0.0)
			cov.material_override = mat_black
			shoulder_piv.add_child(cov)

		var elbow_piv := Node3D.new()
		elbow_piv.position = Vector3(-0.04, 0.0, side_s * 0.41)
		shoulder_piv.add_child(elbow_piv)

		var outer_w := MeshInstance3D.new()
		var ow_b := BoxMesh.new()
		ow_b.size = Vector3(0.18, 0.014, 0.42)
		outer_w.mesh = ow_b
		outer_w.position = Vector3(-0.07, 0.006, side_s * 0.19)
		outer_w.rotation_degrees = Vector3(side_s * 4.0, side_s * -18.0, 0.0)
		outer_w.material_override = mat_black
		elbow_piv.add_child(outer_w)

		for pf_i in range(7):
			var pf := MeshInstance3D.new()
			var pf_b := BoxMesh.new()
			pf_b.size = Vector3(0.046, 0.008, 0.25 - float(pf_i) * 0.018)
			pf.mesh = pf_b
			pf.position = Vector3(-0.03 - float(pf_i) * 0.038, 0.012 + float(pf_i) * 0.002, side_s * (0.40 - float(pf_i) * 0.036))
			pf.rotation_degrees = Vector3(side_s * 10.0, side_s * (-10.0 - float(pf_i) * 10.0), 0.0)
			pf.material_override = mat_black
			elbow_piv.add_child(pf)

		if side_s < 0.0:
			_bird_wing_l_in = shoulder_piv
			_bird_wing_l_out = elbow_piv
		else:
			_bird_wing_r_in = shoulder_piv
			_bird_wing_r_out = elbow_piv


func _build_procedural_peak() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0.0, 3.0, 0.0)
	var segs := 14
	for i in range(segs):
		var a0 := float(i) * (TAU / float(segs))
		var a1 := float(i + 1) * (TAU / float(segs))
		var r0 := 2.2 + sin(float(i) * 2.1) * 0.35
		var r1 := 2.2 + sin(float(i + 1) * 2.1) * 0.35
		var p0 := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
		st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(apex)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p1)
	st.generate_normals()
	return st.commit()


func _apply_mat_rec(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for ch in node.get_children():
		_apply_mat_rec(ch, mat)


func _bird_flight_pos(gp: float) -> Vector3:
	var x := lerpf(-3.25, 3.20, gp)
	var dip := -sin(gp * PI) * 0.42 + pow(maxf(0.0, gp - 0.45), 1.6) * 0.85
	var y := 2.28 + dip
	var z := lerpf(1.45, 0.72, gp) + sin(gp * PI * 1.4) * 0.22
	return Vector3(x, y, z)


func _process(delta: float) -> void:
	if not _active or _finished:
		return
	_time += minf(delta, 0.05)
	if _time >= DURATION:
		if loop_preview:
			_time = 0.0
		else:
			_finished = true
			stop_intro()
			intro_finished.emit()
			return
	_update_visuals()


func _update_visuals() -> void:
	var t := _time * 0.88
	var rise_p := clampf((t - 0.38) / 0.92, 0.0, 1.0)
	var rise_ease := clampf(ease(rise_p, 0.32), 0.0, 1.05)
	if rise_p > 0.75:
		rise_ease = 1.0 + sin(((rise_p - 0.75) / 0.25) * PI) * 0.032

	if is_instance_valid(_mtn_root):
		_mtn_root.position.y = lerpf(-2.85, -0.06, rise_ease)
		_mtn_root.rotation_degrees.y = sin(t * 0.42) * 3.5

	if is_instance_valid(_cam):
		var cd := clampf(t / 4.2, 0.0, 1.0)
		_cam.position = Vector3(sin(t * 0.35) * 0.18, lerpf(0.76, 0.84, cd), lerpf(8.85, 8.25, cd))
		_cam.look_at(Vector3(0.0, lerpf(1.24, 1.18, cd), 0.0), Vector3.UP)

	if _mtn_mat != null:
		var snow_cov := clampf((t - 1.05) / 1.30, 0.0, 1.0)
		_mtn_mat.set_shader_parameter("snow_line_ratio", lerpf(1.28, 0.36, ease(snow_cov, 0.54)))
		_mtn_mat.set_shader_parameter("snow_time", t)

	if is_instance_valid(_snow_particles):
		_snow_particles.emitting = (t >= 0.90 and t <= 4.10)

	# All-Black Articulated Bird Wingbeat + Soar Animation
	_bird_trails.clear()
	if is_instance_valid(_bird_root):
		var bp := (t - 1.45) / 2.35
		if bp > 0.005 and bp < 0.995:
			_bird_root.visible = true
			var p_now := _bird_flight_pos(bp)
			var p_next := _bird_flight_pos(minf(bp + 0.025, 1.0))
			var vel := p_next - p_now
			_bird_root.position = p_now
			var pitch_deg := rad_to_deg(atan2(vel.y, maxf(0.001, vel.x)))
			var bank_deg := sin(bp * PI * 1.5) * 18.0
			_bird_root.rotation_degrees = Vector3(bank_deg, -10.0, clampf(pitch_deg, -28.0, 28.0))

			var flap_env := 1.0 if (bp < 0.40 or bp > 0.72) else 0.18
			var flap_in := sin(t * 11.5) * 34.0 * flap_env + 6.0
			var flap_out := sin(t * 11.5 - 0.65) * 26.0 * flap_env
			if is_instance_valid(_bird_wing_l_in):
				_bird_wing_l_in.rotation_degrees.x = flap_in
			if is_instance_valid(_bird_wing_r_in):
				_bird_wing_r_in.rotation_degrees.x = -flap_in
			if is_instance_valid(_bird_wing_l_out):
				_bird_wing_l_out.rotation_degrees.x = flap_out
			if is_instance_valid(_bird_wing_r_out):
				_bird_wing_r_out.rotation_degrees.x = -flap_out
			if is_instance_valid(_bird_tail_root):
				_bird_tail_root.rotation_degrees.z = -sin(t * 11.5) * 6.0 * flap_env

			if is_instance_valid(_cam) and is_instance_valid(_vp) and is_instance_valid(_vp_container) and _vp.size.x > 0 and _vp.size.y > 0:
				var scale_v := _vp_container.size / Vector2(_vp.size)
				var edge_fade := clampf(sin(bp * PI) * 2.4, 0.0, 1.0)
				for tr_i in range(1, 9):
					var tp := clampf(bp - float(tr_i) * 0.022, 0.0, 1.0)
					var w_tr := _bird_flight_pos(tp) + Vector3(-0.18, 0.02, 0.0)
					if not _cam.is_position_behind(w_tr):
						_bird_trails.append({"pos": _cam.unproject_position(w_tr) * scale_v, "step": tr_i, "alpha": edge_fade})
		else:
			_bird_root.visible = false

	if is_instance_valid(_sky_canvas):
		_sky_canvas.queue_redraw()
	if is_instance_valid(_fg_canvas):
		_fg_canvas.queue_redraw()


func _draw_sky() -> void:
	if not is_instance_valid(_sky_canvas):
		return
	var rect := _sky_canvas.get_viewport_rect()
	var cx := rect.size.x * 0.5
	var horizon_y := rect.size.y * 0.62
	var t := _time * 0.88
	var sun_rise := clampf((t - 0.05) / 0.85, 0.0, 1.0)
	var bg_col := Color(0.11, 0.10, 0.12).lerp(Color(0.95, 0.92, 0.87), ease(sun_rise, 0.45))
	_sky_canvas.draw_rect(rect, bg_col)
	var sun_y := lerpf(horizon_y + 50.0, horizon_y - 225.0, ease(clampf(t / 1.15, 0.0, 1.0), 0.4))
	var sun_pos := Vector2(cx + 68.0, sun_y)
	_sky_canvas.draw_circle(sun_pos, 148.0 * sun_rise, Color(1.0, 0.78, 0.36, 0.36 * sun_rise))
	_sky_canvas.draw_circle(sun_pos, 82.0 * sun_rise, Color(1.0, 0.88, 0.54, 0.82 * sun_rise))


func _draw_foreground() -> void:
	if not is_instance_valid(_fg_canvas):
		return
	var rect := _fg_canvas.get_viewport_rect()
	var w := rect.size.x
	var h := rect.size.y
	var cx := w * 0.5
	var horizon_y := h * 0.62
	var t := _time * 0.88

	var col_ground := Color(0.12, 0.10, 0.10).lerp(Color(0.89, 0.85, 0.78), ease(clampf((t - 0.05) / 0.85, 0.0, 1.0), 0.45))
	_fg_canvas.draw_rect(Rect2(0.0, horizon_y, w, h - horizon_y), col_ground)
	_fg_canvas.draw_line(Vector2(cx - 420.0, horizon_y), Vector2(cx + 420.0, horizon_y), Color(0.12, 0.10, 0.09, 0.88), 2.5)

	# Wingtip Wind Ink Trails
	if _bird_trails.size() >= 2:
		for ti in range(_bird_trails.size() - 1):
			var p0: Vector2 = _bird_trails[ti]["pos"]
			var p1: Vector2 = _bird_trails[ti + 1]["pos"]
			var a := float(_bird_trails[ti]["alpha"]) * (1.0 - float(ti) / float(_bird_trails.size())) * 0.52
			_fg_canvas.draw_line(p0, p1, Color(0.08, 0.07, 0.07, a), 3.0)

	# Drifting Foreground Snow Flakes
	if t >= 1.0:
		var snow_fade := clampf((t - 1.0) / 0.6, 0.0, 1.0) * (1.0 if t < 3.9 else clampf(1.0 - (t - 3.9) / 0.7, 0.0, 1.0))
		for sf in _snow_flakes:
			var fx := fmod(float(sf["x"]) * w + t * 55.0 * float(sf["spd"]) * 8.0, w)
			var fy := fmod(float(sf["y"]) * h + t * 420.0 * float(sf["spd"]), h)
			_fg_canvas.draw_circle(Vector2(fx, fy), float(sf["sz"]), Color(0.98, 0.98, 1.0, 0.55 * snow_fade))

	# Universal Fujira Studios Brand Title Reveal (zero game-specific strings!)
	var title_a := clampf((t - 1.35) / 0.55, 0.0, 1.0)
	if title_a > 0.01 and _font_disp != null:
		var ty := horizon_y + 72.0
		var title := "FUJIRA STUDIOS"
		_fg_canvas.draw_string(_font_disp, Vector2(cx - 280.0, ty + 2.0), title, HORIZONTAL_ALIGNMENT_CENTER, 560, 44, Color(0.98, 0.94, 0.86, 0.7 * title_a))
		_fg_canvas.draw_string(_font_disp, Vector2(cx - 280.0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, 560, 44, Color(0.11, 0.08, 0.06, title_a))
		var line_w := 190.0 * ease(title_a, 0.4)
		_fg_canvas.draw_line(Vector2(cx - line_w, ty + 18.0), Vector2(cx + line_w, ty + 18.0), Color(0.56, 0.36, 0.14, 0.88 * title_a), 2.2)

	# Clean Entrance & Exit Fade Curtain
	if t < 0.28:
		_fg_canvas.draw_rect(rect, Color(0.03, 0.025, 0.02, 1.0 - t / 0.28))
	elif t > 4.05:
		_fg_canvas.draw_rect(rect, Color(0.03, 0.025, 0.02, clampf((t - 4.05) / 0.60, 0.0, 1.0)))
