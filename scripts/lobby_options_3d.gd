class_name LobbyOptions3D
extends Control

## Hybrid 3D Tavern Study + Fixed Medieval Parchment Codex Options Desk for LIALO.
## - Upper 3D viewport frames the live flickering candlelight desk with 9 interactive
##   Blender props (wax stamps, crystal prism lantern, hourglass, brass dials, gramophone
##   bell, ember brazier) that react dynamically when hovered or toggled.
## - Foreground holds a rock-solid, zero-drift open Medieval Parchment Codex book with
##   clean two-page controls & stationary sliders (never sliding under the mouse).

signal option_changed(key: String, value: Variant)
signal difficulty_toggled()
signal mute_toggled()
signal volume_changed(vol_pct: int)
signal replay_tutorial_requested()
signal return_requested()
signal close_requested()
signal sfx_requested(sfx_name: String)

const Toon := preload("res://scripts/toon_style.gd")
const WOODCUT_POST_SHADER := preload("res://shaders/woodcut_post.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const FONT_QUILL_PATH := "res://assets/fonts/LialoQuill.ttf"

const PATH_LEDGER := "res://assets/models/lobby_options/settings_desk_ledger.glb"
const PATH_DIAL := "res://assets/models/lobby_options/settings_brass_dial.glb"
const PATH_STAMP := "res://assets/models/lobby_options/settings_wax_stamp.glb"
const PATH_LANTERN := "res://assets/models/lobby_options/settings_lantern_prism.glb"
const PATH_HOURGLASS := "res://assets/models/lobby_options/settings_hourglass.glb"
const PATH_BELL := "res://assets/models/lobby_options/settings_gramophone_bell.glb"

const CAM_BASE_POS := Vector3(0.0, 0.96, 1.72)
const CAM_OPEN_START_POS := Vector3(0.0, 1.48, 2.15)
const CAM_BASE_TARGET := Vector3(0.0, -0.18, -0.26)

var _disp_font: Font
var _body_font: Font
var _quill_font: Font

# 3D Scene hierarchy
var _vp_container: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _world_env: WorldEnvironment
var _candle_light: OmniLight3D
var _key_spot: SpotLight3D
var _hover_spot: SpotLight3D
var _rim_light: DirectionalLight3D
var _dust_particles: GPUParticles3D
var _post_rect: ColorRect
var _post_mat: ShaderMaterial

# Animated prop sub-nodes
var _lantern_core_node: Node3D
var _lantern_light: OmniLight3D
var _fx_flame_node: Node3D
var _fx_light: OmniLight3D
var _hourglass_body: Node3D
var _hourglass_flip_deg: float = 0.0
var _bell_horn: Node3D
var _vol_knob: Node3D
var _sens_knob: Node3D
var _stamp_handles: Dictionary = {}
var _wax_meshes: Dictionary = {}

# Stations registry: key -> Dictionary
var _stations: Dictionary = {}
var _station_order: Array[String] = []
var _hovered_station: String = ""
var _ui_hovered_station: String = ""

# Camera & Modal animation state
var _is_open_state: bool = false
var _cam_open_blend: float = 1.0
var _cam_open_tw: Tween
var _fade_tw: Tween
var _mouse_nx: float = 0.0
var _mouse_ny: float = 0.0
var _smooth_mouse_nx: float = 0.0
var _smooth_mouse_ny: float = 0.0
var _cam_cur_target: Vector3 = CAM_BASE_TARGET
var _spot_cur_target: Vector3 = Vector3(0.0, 0.08, -0.40)
var _pending_hover_key: String = ""
var _hover_debounce_t: float = 0.0
var _last_hover_sfx_ms: int = 0
var _time_acc: float = 0.0

const HOVER_DEBOUNCE_SEC := 0.055
const HOVER_SFX_COOLDOWN_MS := 75

# Synced state cache
var _opts: Dictionary = {}
var _profile: Dictionary = {}
var _muted: bool = false
var _vol_pct: int = 85
var _screen_kind: String = "MAIN_MENU"

# Foreground Hybrid Parchment Codex UI (fixed coordinates, zero drift!)
var _ui_overlay: Control
var _title_lbl: Label
var _close_btn: Button
var _book_panel: Control
var _left_hdr_lbl: Label
var _right_hdr_lbl: Label
var _codex_hdr_lbl: Label
var _codex_keys_lbl: Label
var _replay_tut_btn: Button
var _return_btn: Button
var _done_btn: Button
var _vol_slider: HSlider
var _sens_slider: HSlider
var _row_widgets: Dictionary = {}  # key -> {"row": Control, "name_lbl": Label, "btn": Button, "slider": HSlider, "val_lbl": Label}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	modulate.a = 0.0


func setup(display_font: Font, body_font: Font, quill_font: Font = null) -> void:
	_disp_font = display_font if display_font != null else ThemeDB.fallback_font
	_body_font = body_font if body_font != null else ThemeDB.fallback_font
	if quill_font != null:
		_quill_font = quill_font
	elif ResourceLoader.exists(FONT_QUILL_PATH):
		_quill_font = load(FONT_QUILL_PATH) as Font
	else:
		_quill_font = _body_font
	if _vp_container != null:
		return
	_build_3d_study_scene()
	_build_hybrid_codex_overlay()


func is_open() -> bool:
	return _is_open_state and visible


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		sfx_requested.emit("ui_click")
		close_requested.emit()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func get_station_button(key: String) -> Button:
	if _row_widgets.has(key):
		return _row_widgets[key].get("btn", null) as Button
	return null


func get_slider(key: String) -> HSlider:
	if _row_widgets.has(key):
		return _row_widgets[key].get("slider", null) as HSlider
	return null


func open_3d() -> void:
	if _vp_container == null:
		setup(_disp_font, _body_font, _quill_font)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if get_viewport() != null:
		var vp_r := get_viewport().get_visible_rect().size
		if vp_r.x >= 100.0 and size.x < 100.0:
			size = vp_r
	_is_open_state = true
	visible = true
	if is_instance_valid(_vp):
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	if _cam_open_tw and _cam_open_tw.is_valid():
		_cam_open_tw.kill()

	modulate.a = 0.0
	_cam_open_blend = 0.0
	_update_camera_pose(0.0, true)

	_fade_tw = create_tween()
	_fade_tw.tween_property(self, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_cam_open_tw = create_tween()
	_cam_open_tw.tween_property(self, "_cam_open_blend", 1.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close_3d() -> void:
	if not _is_open_state:
		return
	_is_open_state = false
	_hovered_station = ""
	_pending_hover_key = ""
	_hover_debounce_t = 0.0
	_ui_hovered_station = ""
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	if _cam_open_tw and _cam_open_tw.is_valid():
		_cam_open_tw.kill()

	_cam_open_tw = create_tween()
	_cam_open_tw.tween_property(self, "_cam_open_blend", 0.15, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_fade_tw = create_tween()
	_fade_tw.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fade_tw.tween_callback(func():
		visible = false
		if is_instance_valid(_vp):
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	)


func sync_state(opts: Dictionary, profile: Dictionary, is_muted: bool, vol_pct: int, screen_kind: String) -> void:
	_opts = opts.duplicate(true)
	_profile = profile.duplicate(true)
	_muted = is_muted
	_vol_pct = clampi(vol_pct, 0, 100)
	_screen_kind = screen_kind
	_refresh_all_visuals()


func get_projected_station_rects() -> Dictionary:
	## Returns the actual stationary screen-space Rect2s for all Codex book controls (diagnostics & zero-overlap checks).
	var res := {}
	for key in _row_widgets.keys():
		var w_row: Control = _row_widgets[key].get("row", null) as Control
		if is_instance_valid(w_row):
			res[key] = w_row.get_global_rect()
	if is_instance_valid(_codex_keys_lbl):
		res["codex"] = _codex_keys_lbl.get_global_rect()
	return res


# =============================================================================
# 3D SCENE CONSTRUCTION
# =============================================================================
func _load_glb(res_path: String) -> Node3D:
	if ResourceLoader.exists(res_path):
		var packed := load(res_path) as PackedScene
		if packed:
			var inst := packed.instantiate()
			if inst is Node3D:
				return inst as Node3D
	if FileAccess.file_exists(res_path):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		var abs_path := ProjectSettings.globalize_path(res_path)
		if gltf.append_from_file(abs_path, state) == OK:
			var gen := gltf.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
	return null


func _attach_subtle_outline(node: Node, thickness: float = 0.004) -> void:
	var out_mat := ShaderMaterial.new()
	out_mat.shader = OUTLINE_SHADER
	out_mat.set_shader_parameter("thickness", thickness)
	out_mat.set_shader_parameter("outline_color", Color(0.04, 0.028, 0.02, 1.0))
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.material_override != null:
				var dup := mi.material_override.duplicate() as Material
				if dup != null:
					dup.next_pass = out_mat
					mi.material_override = dup
			elif mi.mesh != null:
				for si in range(mi.mesh.get_surface_count()):
					var m := mi.get_active_material(si)
					if m != null:
						var dup := m.duplicate() as Material
						if dup != null:
							dup.next_pass = out_mat
							mi.set_surface_override_material(si, dup)
		for ch in cur.get_children():
			stack.append(ch)


func _tint_named_mesh(root: Node, name_sub: String, albedo_col: Color, emit_col: Color = Color.BLACK, emit_energy: float = 0.0) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and cur.name.to_lower().contains(name_sub.to_lower()):
			var mi := cur as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = albedo_col
			mat.roughness = 0.34
			if emit_col != Color.BLACK:
				mat.emission_enabled = true
				mat.emission = emit_col
				mat.emission_energy_multiplier = emit_energy
			mi.material_override = mat
		for ch in cur.get_children():
			stack.append(ch)


func _build_3d_study_scene() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp_container = SubViewportContainer.new()
	_vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp_container.stretch = true
	_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp_container)

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(1366, 768)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp_container.add_child(_vp)

	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.032, 0.022, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.28, 0.22)
	env.ambient_light_energy = 0.54
	_world_env.environment = env
	_vp.add_child(_world_env)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_vp.add_child(_cam)
	_cam.look_at_from_position(CAM_BASE_POS, CAM_BASE_TARGET, Vector3.UP)

	# Warm candlelight + golden desk key + cool stone rim
	_candle_light = OmniLight3D.new()
	_candle_light.position = Vector3(-1.18, 0.54, -0.52)
	_candle_light.light_color = Color(1.0, 0.68, 0.28)
	_candle_light.light_energy = 2.6
	_candle_light.omni_range = 3.6
	_candle_light.shadow_enabled = true
	_vp.add_child(_candle_light)

	_key_spot = SpotLight3D.new()
	_key_spot.light_color = Color(1.0, 0.88, 0.66)
	_key_spot.light_energy = 2.3
	_key_spot.spot_range = 4.6
	_key_spot.spot_angle = 56.0
	_key_spot.shadow_enabled = true
	_vp.add_child(_key_spot)
	_key_spot.look_at_from_position(Vector3(0.08, 1.48, 0.72), Vector3(0.0, 0.0, -0.32), Vector3.UP)

	_hover_spot = SpotLight3D.new()
	_hover_spot.position = Vector3(0.0, 0.86, 0.20)
	_hover_spot.light_color = Color(1.0, 0.86, 0.44)
	_hover_spot.light_energy = 0.0
	_hover_spot.spot_range = 2.8
	_hover_spot.spot_angle = 22.0
	_vp.add_child(_hover_spot)

	_rim_light = DirectionalLight3D.new()
	_rim_light.light_color = Color(0.54, 0.66, 0.92)
	_rim_light.light_energy = 0.46
	_rim_light.rotation_degrees = Vector3(-34.0, -142.0, 0.0)
	_vp.add_child(_rim_light)

	# Carved Oak Study Desk & Stone Tavern Backdrop
	var desk_root := Node3D.new()
	desk_root.name = "TavernStudyDesk"
	_vp.add_child(desk_root)

	var oak_mat := Toon.pbr(Color(0.32, 0.21, 0.13), "res://assets/table/wood.png", 0.64, 0.04, Vector2(3.2, 2.0))
	var trim_mat := Toon.pbr(Color(0.16, 0.10, 0.06), "res://assets/table/wood.png", 0.56, 0.08, Vector2(2.0, 1.0))
	var brass_mat := Toon.pbr(Color(0.86, 0.66, 0.22), "", 0.25, 0.90)
	var stone_mat := Toon.pbr(Color(0.24, 0.20, 0.18), "res://assets/table/stone_floor.png", 0.82, 0.02, Vector2(4.0, 2.5))

	var table_top := MeshInstance3D.new()
	var t_box := BoxMesh.new()
	t_box.size = Vector3(3.8, 0.14, 2.2)
	table_top.mesh = t_box
	table_top.position = Vector3(0.0, -0.07, -0.18)
	table_top.material_override = oak_mat
	desk_root.add_child(table_top)

	var rear_wall := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(4.8, 2.5, 0.12)
	rear_wall.mesh = w_box
	rear_wall.position = Vector3(0.0, 0.95, -1.16)
	rear_wall.material_override = stone_mat
	desk_root.add_child(rear_wall)

	var wainscot := MeshInstance3D.new()
	var ws_b := BoxMesh.new()
	ws_b.size = Vector3(4.7, 0.10, 0.16)
	wainscot.mesh = ws_b
	wainscot.position = Vector3(0.0, 0.36, -1.10)
	wainscot.material_override = trim_mat
	desk_root.add_child(wainscot)

	# Decorative outer framing props clearly separated from interactive showcase arc
	var candle_prop := _load_glb("res://assets/models/candelabra.glb")
	if candle_prop == null:
		candle_prop = _load_glb("res://assets/models/tavern_lantern.glb")
	if candle_prop != null:
		candle_prop.position = Vector3(-1.34, 0.0, -0.66)
		candle_prop.scale = Vector3.ONE * 0.72
		_vp.add_child(candle_prop)

	var mug_prop := _load_glb("res://assets/models/tavern_mug.glb")
	if mug_prop != null:
		mug_prop.position = Vector3(1.34, 0.0, -0.60)
		mug_prop.rotation_degrees = Vector3(0.0, -28.0, 0.0)
		mug_prop.scale = Vector3.ONE * 0.85
		_vp.add_child(mug_prop)

	var pouch_prop := _load_glb("res://assets/models/coins_pouch.glb")
	if pouch_prop != null:
		pouch_prop.position = Vector3(1.16, 0.0, -0.74)
		pouch_prop.rotation_degrees = Vector3(0.0, 18.0, 0.0)
		pouch_prop.scale = Vector3.ONE * 0.75
		_vp.add_child(pouch_prop)

	var ledger := _load_glb(PATH_LEDGER)
	if ledger != null:
		ledger.position = Vector3(0.0, 0.008, -0.22)
		ledger.scale = Vector3.ONE * 0.86
		_attach_subtle_outline(ledger, 0.003)
		_vp.add_child(ledger)

	# Upper Gallery Showcase Arc: 9 cleanly spaced interactive 3D props above the foreground Codex
	_spawn_stamp_station("language",        Vector3(-0.98, 0.0, -0.32), Color(0.68, 0.10, 0.12), 1.04)
	_spawn_stamp_station("fullscreen",      Vector3(-0.68, 0.0, -0.46), Color(0.14, 0.34, 0.56), 1.04)
	_spawn_lantern_station("visual_mode",   Vector3(-0.36, 0.0, -0.52))
	_spawn_fx_brazier_station("high_fx",    Vector3(-0.04, 0.0, -0.52), brass_mat)
	_spawn_stamp_station("difficulty",      Vector3( 0.28, 0.0, -0.52), Color(0.14, 0.44, 0.24), 1.04)
	_spawn_hourglass_station("game_pace",   Vector3( 0.60, 0.0, -0.44))
	_spawn_bell_station("mute",             Vector3( 0.92, 0.0, -0.32))
	_spawn_dial_station("cam_sensitivity",  Vector3(-1.12, 0.0, -0.02))
	_spawn_dial_station("volume",           Vector3( 1.12, 0.0, -0.02))

	# Floating golden dust motes above the desk (toggled by high_fx)
	_dust_particles = GPUParticles3D.new()
	_dust_particles.amount = 60
	_dust_particles.lifetime = 4.5
	_dust_particles.position = Vector3(0.0, 0.32, -0.30)
	var d_pm := ParticleProcessMaterial.new()
	d_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	d_pm.emission_box_extents = Vector3(1.35, 0.28, 0.55)
	d_pm.direction = Vector3(0.15, 0.45, 0.05)
	d_pm.spread = 45.0
	d_pm.initial_velocity_min = 0.03
	d_pm.initial_velocity_max = 0.09
	d_pm.gravity = Vector3(0.0, 0.015, 0.0)
	d_pm.turbulence_enabled = true
	d_pm.turbulence_noise_strength = 0.35
	_dust_particles.process_material = d_pm
	var d_qm := QuadMesh.new()
	d_qm.size = Vector2(0.015, 0.015)
	var d_qmat := StandardMaterial3D.new()
	d_qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	d_qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	d_qmat.albedo_color = Color(1.0, 0.86, 0.48, 0.65)
	d_qm.material = d_qmat
	_dust_particles.draw_pass_1 = d_qm
	_vp.add_child(_dust_particles)

	# Live Post-Processing Visual Mode Preview on the 3D Study Viewport
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	_vp.add_child(post_layer)
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = WOODCUT_POST_SHADER
	_post_mat.set_shader_parameter("print_mode", 3)
	_post_rect.material = _post_mat
	post_layer.add_child(_post_rect)


func _register_station(key: String, root: Node3D, pos: Vector3, hit_radius: float = 0.16) -> void:
	root.position = pos
	root.set_meta("base_y", pos.y)
	root.set_meta("base_scale", root.scale)
	_vp.add_child(root)
	_stations[key] = {
		"key": key,
		"root": root,
		"base_pos": pos,
		"hit_center": pos + Vector3(0.0, 0.09, 0.0),
		"hit_radius": hit_radius,
	}
	if not (key in _station_order):
		_station_order.append(key)


func _spawn_stamp_station(key: String, pos: Vector3, wax_col: Color, sc: float) -> void:
	var root := _load_glb(PATH_STAMP)
	if root == null:
		root = Node3D.new()
	root.scale = Vector3.ONE * sc
	_tint_named_mesh(root, "WaxDisc", wax_col)
	_attach_subtle_outline(root, 0.003)
	var handle := root.find_child("StampHandle", true, false) as Node3D
	if handle != null:
		handle.set_meta("base_y", handle.position.y)
		_stamp_handles[key] = handle
	var wax_m := root.find_child("WaxDisc", true, false) as MeshInstance3D
	if wax_m != null:
		_wax_meshes[key] = wax_m
	_register_station(key, root, pos, 0.15)


func _spawn_lantern_station(key: String, pos: Vector3) -> void:
	var root := _load_glb(PATH_LANTERN)
	if root == null:
		root = Node3D.new()
	root.scale = Vector3.ONE * 1.10
	_attach_subtle_outline(root, 0.003)
	_lantern_core_node = root.find_child("LanternCore", true, false) as Node3D
	_lantern_light = OmniLight3D.new()
	_lantern_light.position = Vector3(0.0, 0.14, 0.0)
	_lantern_light.light_color = Color(1.0, 0.78, 0.34)
	_lantern_light.light_energy = 1.65
	_lantern_light.omni_range = 1.15
	root.add_child(_lantern_light)
	_register_station(key, root, pos, 0.17)


func _spawn_fx_brazier_station(key: String, pos: Vector3, brass_mat: Material) -> void:
	var root := Node3D.new()
	var cup := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.072; cyl.bottom_radius = 0.052; cyl.height = 0.052; cyl.radial_segments = 16
	cup.mesh = cyl
	cup.position = Vector3(0.0, 0.026, 0.0)
	cup.material_override = brass_mat
	root.add_child(cup)

	var base := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.088; b_cyl.bottom_radius = 0.094; b_cyl.height = 0.016; b_cyl.radial_segments = 16
	base.mesh = b_cyl
	base.position = Vector3(0.0, 0.008, 0.0)
	base.material_override = Toon.pbr(Color(0.16, 0.10, 0.06), "", 0.56, 0.04)
	root.add_child(base)

	var flame_piv := Node3D.new()
	flame_piv.position = Vector3(0.0, 0.068, 0.0)
	var fl_mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.044; sph.height = 0.105
	fl_mesh.mesh = sph
	var fl_mat := StandardMaterial3D.new()
	fl_mat.albedo_color = Color(1.0, 0.78, 0.28)
	fl_mat.emission_enabled = true
	fl_mat.emission = Color(1.0, 0.60, 0.16)
	fl_mat.emission_energy_multiplier = 2.6
	fl_mesh.material_override = fl_mat
	flame_piv.add_child(fl_mesh)
	root.add_child(flame_piv)
	_fx_flame_node = flame_piv

	_fx_light = OmniLight3D.new()
	_fx_light.position = Vector3(0.0, 0.12, 0.0)
	_fx_light.light_color = Color(1.0, 0.68, 0.24)
	_fx_light.light_energy = 1.45
	_fx_light.omni_range = 1.05
	root.add_child(_fx_light)

	_attach_subtle_outline(root, 0.003)
	_register_station(key, root, pos, 0.15)


func _spawn_hourglass_station(key: String, pos: Vector3) -> void:
	var root := _load_glb(PATH_HOURGLASS)
	if root == null:
		root = Node3D.new()
	root.scale = Vector3.ONE * 1.10
	root.rotation_degrees = Vector3(0.0, -14.0, 0.0)
	_attach_subtle_outline(root, 0.003)
	_hourglass_body = root.find_child("HourglassBody", true, false) as Node3D
	_register_station(key, root, pos, 0.16)


func _spawn_bell_station(key: String, pos: Vector3) -> void:
	var root := _load_glb(PATH_BELL)
	if root == null:
		root = Node3D.new()
	root.scale = Vector3.ONE * 1.06
	root.rotation_degrees = Vector3(0.0, -22.0, 0.0)
	_attach_subtle_outline(root, 0.003)
	_bell_horn = root.find_child("BellHorn", true, false) as Node3D
	_register_station(key, root, pos, 0.16)


func _spawn_dial_station(key: String, pos: Vector3) -> void:
	var root := _load_glb(PATH_DIAL)
	if root == null:
		root = Node3D.new()
	root.scale = Vector3.ONE * 1.12
	_attach_subtle_outline(root, 0.003)
	var knob := root.find_child("DialKnob", true, false) as Node3D
	if key == "volume":
		_vol_knob = knob
	elif key == "cam_sensitivity":
		_sens_knob = knob
	_register_station(key, root, pos, 0.15)


# =============================================================================
# FOREGROUND FIXED MEDIEVAL PARCHMENT CODEX OVERLAY (ZERO OVERLAP / ZERO DRIFT)
# =============================================================================
func _make_badge_style(bg_col: Color, border_col: Color, bottom_lip: int = 3, radius: int = 9) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.border_width_bottom = bottom_lip
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


func _build_hybrid_codex_overlay() -> void:
	_ui_overlay = Control.new()
	_ui_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_overlay)

	# 1. Compact Header Bar at very top (leaving y=64..280 wide open for 3D Tavern Study props!)
	var top_bar := PanelContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 24
	top_bar.offset_top = 12
	top_bar.offset_right = -24
	top_bar.offset_bottom = 62
	top_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	top_bar.add_theme_stylebox_override("panel", _make_badge_style(Color(0.045, 0.034, 0.028, 0.88), Color(0.84, 0.64, 0.26, 0.90), 3, 10))
	_ui_overlay.add_child(top_bar)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	top_bar.add_child(hdr)

	_title_lbl = Label.new()
	_title_lbl.text = "⚙ LIALO — OPTIONS"
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", _disp_font)
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.38))
	hdr.add_child(_title_lbl)

	_close_btn = Button.new()
	_close_btn.text = "✕ Close [ESC]"
	_close_btn.custom_minimum_size = Vector2(148, 36)
	_close_btn.add_theme_font_override("font", _disp_font)
	_close_btn.add_theme_font_size_override("font_size", 15)
	_close_btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.70))
	_close_btn.pressed.connect(func():
		emit_signal("sfx_requested", "ui_click")
		emit_signal("close_requested")
	)
	hdr.add_child(_close_btn)

	# 2. Fixed Open Medieval Parchment Codex (bottom-center, zero movement under cursor!)
	var book_wrap := PanelContainer.new()
	book_wrap.name = "MedievalCodexBook"
	book_wrap.anchor_left = 0.5
	book_wrap.anchor_top = 1.0
	book_wrap.anchor_right = 0.5
	book_wrap.anchor_bottom = 1.0
	book_wrap.offset_left = -530
	book_wrap.offset_right = 530
	book_wrap.offset_top = -486
	book_wrap.offset_bottom = -82
	book_wrap.custom_minimum_size = Vector2(1060, 404)
	book_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var leather_sb := StyleBoxFlat.new()
	leather_sb.bg_color = Color(0.18, 0.11, 0.065, 0.97)
	leather_sb.border_color = Color(0.78, 0.58, 0.24, 0.96)
	leather_sb.set_border_width_all(3)
	leather_sb.border_width_bottom = 6
	leather_sb.set_corner_radius_all(16)
	leather_sb.set_content_margin_all(0)
	leather_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.76)
	leather_sb.shadow_size = 18
	leather_sb.shadow_offset = Vector2(0, 6)
	book_wrap.add_theme_stylebox_override("panel", leather_sb)
	_ui_overlay.add_child(book_wrap)
	_book_panel = book_wrap

	var book_art := Control.new()
	book_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	book_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_art.draw.connect(func():
		_draw_open_parchment_book(book_art)
	)
	book_wrap.add_child(book_art)

	var book_margin := MarginContainer.new()
	book_margin.add_theme_constant_override("margin_left", 28)
	book_margin.add_theme_constant_override("margin_right", 28)
	book_margin.add_theme_constant_override("margin_top", 20)
	book_margin.add_theme_constant_override("margin_bottom", 18)
	book_wrap.add_child(book_margin)

	var pages_hb := HBoxContainer.new()
	pages_hb.add_theme_constant_override("separation", 44)
	book_margin.add_child(pages_hb)

	# --- LEFT PAGE: Display & Atmosphere + Controls Legend ---
	var left_page := VBoxContainer.new()
	left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_page.add_theme_constant_override("separation", 8)
	pages_hb.add_child(left_page)

	_left_hdr_lbl = Label.new()
	_left_hdr_lbl.text = "DISPLAY & ATMOSPHERE"
	_left_hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_hdr_lbl.add_theme_font_override("font", _disp_font)
	_left_hdr_lbl.add_theme_font_size_override("font_size", 19)
	_left_hdr_lbl.add_theme_color_override("font_color", Color(0.24, 0.12, 0.06))
	left_page.add_child(_left_hdr_lbl)

	left_page.add_child(_make_parchment_divider())

	left_page.add_child(_create_book_button_row("language"))
	left_page.add_child(_create_book_button_row("fullscreen"))
	left_page.add_child(_create_book_button_row("visual_mode"))
	left_page.add_child(_create_book_button_row("high_fx"))
	left_page.add_child(_create_book_button_row("turn_timer_sec"))

	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_child(left_spacer)

	var codex_box := PanelContainer.new()
	codex_box.add_theme_stylebox_override("panel", _make_badge_style(Color(0.84, 0.77, 0.62, 0.92), Color(0.46, 0.31, 0.17, 0.85), 2, 8))
	left_page.add_child(codex_box)
	var c_vb := VBoxContainer.new()
	c_vb.add_theme_constant_override("separation", 2)
	codex_box.add_child(c_vb)

	_codex_hdr_lbl = Label.new()
	_codex_hdr_lbl.text = "CONTROLS CODEX"
	_codex_hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_codex_hdr_lbl.add_theme_font_override("font", _disp_font)
	_codex_hdr_lbl.add_theme_font_size_override("font_size", 13)
	_codex_hdr_lbl.add_theme_color_override("font_color", Color(0.44, 0.18, 0.08))
	c_vb.add_child(_codex_hdr_lbl)

	_codex_keys_lbl = Label.new()
	_codex_keys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_keys_lbl.custom_minimum_size = Vector2(400.0, 38.0)
	_codex_keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_codex_keys_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_codex_keys_lbl.add_theme_font_override("font", _quill_font)
	_codex_keys_lbl.add_theme_font_size_override("font_size", 15)
	_codex_keys_lbl.add_theme_color_override("font_color", Color(0.16, 0.10, 0.06))
	c_vb.add_child(_codex_keys_lbl)

	# --- RIGHT PAGE: Audio & Gameplay ---
	var right_page := VBoxContainer.new()
	right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_page.add_theme_constant_override("separation", 8)
	pages_hb.add_child(right_page)

	_right_hdr_lbl = Label.new()
	_right_hdr_lbl.text = "AUDIO & GAMEPLAY"
	_right_hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_hdr_lbl.add_theme_font_override("font", _disp_font)
	_right_hdr_lbl.add_theme_font_size_override("font_size", 19)
	_right_hdr_lbl.add_theme_color_override("font_color", Color(0.24, 0.12, 0.06))
	right_page.add_child(_right_hdr_lbl)

	right_page.add_child(_make_parchment_divider())

	right_page.add_child(_create_book_button_row("difficulty"))
	right_page.add_child(_create_book_button_row("game_pace"))
	right_page.add_child(_create_book_button_row("mute"))
	right_page.add_child(_create_book_slider_row("volume", 0.0, 100.0, 5.0))
	right_page.add_child(_create_book_slider_row("cam_sensitivity", 0.5, 2.0, 0.1))

	# 3. Bottom Action Dock (Replay Tutorial, Return, Save & Resume)
	var bot_bar := PanelContainer.new()
	bot_bar.anchor_left = 0.0
	bot_bar.anchor_top = 1.0
	bot_bar.anchor_right = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.offset_left = 24
	bot_bar.offset_top = -68
	bot_bar.offset_right = -24
	bot_bar.offset_bottom = -12
	bot_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bot_bar.add_theme_stylebox_override("panel", _make_badge_style(Color(0.045, 0.034, 0.028, 0.90), Color(0.76, 0.58, 0.24, 0.86), 3, 10))
	_ui_overlay.add_child(bot_bar)

	var bot_hb := HBoxContainer.new()
	bot_hb.add_theme_constant_override("separation", 14)
	bot_bar.add_child(bot_hb)

	_replay_tut_btn = Button.new()
	_replay_tut_btn.custom_minimum_size = Vector2(220, 38)
	_replay_tut_btn.add_theme_font_override("font", _disp_font)
	_replay_tut_btn.add_theme_font_size_override("font_size", 15)
	_replay_tut_btn.pressed.connect(func():
		emit_signal("sfx_requested", "ui_click")
		emit_signal("replay_tutorial_requested")
	)
	bot_hb.add_child(_replay_tut_btn)

	_return_btn = Button.new()
	_return_btn.custom_minimum_size = Vector2(220, 38)
	_return_btn.visible = false
	_return_btn.add_theme_font_override("font", _disp_font)
	_return_btn.add_theme_font_size_override("font_size", 15)
	_return_btn.pressed.connect(func():
		emit_signal("sfx_requested", "ui_click")
		emit_signal("return_requested")
	)
	bot_hb.add_child(_return_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_hb.add_child(spacer)

	_done_btn = Button.new()
	_done_btn.text = "✓ Save & Resume"
	_done_btn.custom_minimum_size = Vector2(220, 38)
	_done_btn.add_theme_font_override("font", _disp_font)
	_done_btn.add_theme_font_size_override("font_size", 16)
	_done_btn.add_theme_stylebox_override("normal", _make_badge_style(Color(0.28, 0.20, 0.08, 0.98), Color(1.0, 0.84, 0.34, 1.0), 4, 10))
	_done_btn.add_theme_stylebox_override("hover", _make_badge_style(Color(0.38, 0.27, 0.11, 1.0), Color(1.0, 0.92, 0.48, 1.0), 4, 10))
	_done_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	_done_btn.pressed.connect(func():
		emit_signal("sfx_requested", "ui_click")
		emit_signal("close_requested")
	)
	bot_hb.add_child(_done_btn)


func _make_parchment_divider() -> Control:
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(0, 2)
	d.color = Color(0.46, 0.32, 0.18, 0.65)
	return d


func _create_book_button_row(key: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 41)
	row.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.custom_minimum_size = Vector2(182, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", _quill_font)
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", Color(0.16, 0.10, 0.05))
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(236, 36)
	btn.add_theme_font_override("font", _body_font)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.56))
	btn.add_theme_stylebox_override("normal", _make_badge_style(Color(0.20, 0.13, 0.08, 0.96), Color(0.68, 0.50, 0.24, 0.92), 3, 8))
	btn.add_theme_stylebox_override("hover", _make_badge_style(Color(0.30, 0.20, 0.12, 1.0), Color(1.0, 0.84, 0.36, 1.0), 3, 8))
	btn.add_theme_stylebox_override("pressed", _make_badge_style(Color(0.14, 0.09, 0.06, 1.0), Color(0.94, 0.74, 0.28, 1.0), 2, 8))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(func(): _trigger_station(key))
	btn.mouse_entered.connect(func():
		_ui_hovered_station = key
		_set_hovered_station(key)
	)
	btn.mouse_exited.connect(func():
		if _ui_hovered_station == key:
			_ui_hovered_station = ""
	)
	row.add_child(btn)

	_row_widgets[key] = {"row": row, "name_lbl": name_lbl, "btn": btn, "slider": null, "val_lbl": null}
	return row


func _create_book_slider_row(key: String, min_v: float, max_v: float, step_v: float) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 48)
	row.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.custom_minimum_size = Vector2(152, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", _quill_font)
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", Color(0.16, 0.10, 0.05))
	row.add_child(name_lbl)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.custom_minimum_size = Vector2(170, 26)
	var track_bg := StyleBoxFlat.new()
	track_bg.bg_color = Color(0.28, 0.19, 0.11, 0.85)
	track_bg.set_corner_radius_all(4)
	track_bg.content_margin_top = 4
	track_bg.content_margin_bottom = 4
	sl.add_theme_stylebox_override("slider", track_bg)
	var grab_fill := StyleBoxFlat.new()
	grab_fill.bg_color = Color(0.76, 0.56, 0.20, 0.95)
	grab_fill.set_corner_radius_all(4)
	sl.add_theme_stylebox_override("grabber_area", grab_fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", grab_fill)
	sl.mouse_entered.connect(func():
		_ui_hovered_station = key
		_set_hovered_station(key)
	)
	sl.mouse_exited.connect(func():
		if _ui_hovered_station == key:
			_ui_hovered_station = ""
	)
	if key == "volume":
		_vol_slider = sl
		sl.value_changed.connect(func(v: float):
			emit_signal("volume_changed", int(round(v)))
		)
	elif key == "cam_sensitivity":
		_sens_slider = sl
		sl.value_changed.connect(func(v: float):
			emit_signal("option_changed", "cam_sensitivity", v)
		)
	row.add_child(sl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(58, 32)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_override("font", _disp_font)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", Color(0.28, 0.14, 0.06))
	row.add_child(val_lbl)

	_row_widgets[key] = {"row": row, "name_lbl": name_lbl, "btn": null, "slider": sl, "val_lbl": val_lbl}
	return row


func _draw_open_parchment_book(canvas: Control) -> void:
	var sz := canvas.size
	if sz.x < 80.0 or sz.y < 80.0:
		return
	var cx := sz.x * 0.5
	var page_rect := Rect2(10, 8, sz.x - 20, sz.y - 16)
	# Warm illuminated parchment sheet
	canvas.draw_rect(page_rect, Color(0.92, 0.86, 0.72))
	# Page stack deckle edge on outer sides
	canvas.draw_rect(Rect2(6, 12, 5, sz.y - 24), Color(0.76, 0.69, 0.55))
	canvas.draw_rect(Rect2(sz.x - 11, 12, 5, sz.y - 24), Color(0.76, 0.69, 0.55))
	# Center book gutter shadow (12 layered thin translucent vertical strips for curved page depth)
	for gi in range(7):
		var u := float(gi) / 6.0
		var alpha := (1.0 - u) * 0.22
		var gw := 6.0 + u * 26.0
		canvas.draw_rect(Rect2(cx - gw, 8.0, gw * 2.0, sz.y - 16.0), Color(0.22, 0.14, 0.07, alpha))
	canvas.draw_line(Vector2(cx, 8.0), Vector2(cx, sz.y - 8.0), Color(0.26, 0.16, 0.08, 0.65), 2.0)

	# Crimson silk ribbon bookmark peeking below spine
	var rib_pts := PackedVector2Array([
		Vector2(cx - 7.0, sz.y - 14.0),
		Vector2(cx + 7.0, sz.y - 14.0),
		Vector2(cx + 7.0, sz.y + 6.0),
		Vector2(cx, sz.y),
		Vector2(cx - 7.0, sz.y + 6.0),
	])
	canvas.draw_colored_polygon(rib_pts, Color(0.68, 0.14, 0.14, 0.95))

	# Hand-inked double border frames around Left & Right Codex pages
	var l_frame := Rect2(18, 14, cx - 32, sz.y - 28)
	var r_frame := Rect2(cx + 14, 14, cx - 32, sz.y - 28)
	canvas.draw_rect(l_frame, Color(0.32, 0.21, 0.11, 0.75), false, 1.8)
	canvas.draw_rect(l_frame.grow(-4.0), Color(0.42, 0.28, 0.14, 0.42), false, 1.0)
	canvas.draw_rect(r_frame, Color(0.32, 0.21, 0.11, 0.75), false, 1.8)
	canvas.draw_rect(r_frame.grow(-4.0), Color(0.42, 0.28, 0.14, 0.42), false, 1.0)

	# Four forged brass corner brackets on the outer cover
	var brass := Color(0.84, 0.64, 0.24, 0.96)
	var rivet := Color(0.98, 0.86, 0.48, 1.0)
	for corner in [Vector2(0, 0), Vector2(sz.x, 0), Vector2(0, sz.y), Vector2(sz.x, sz.y)]:
		var sx := 1.0 if corner.x < cx else -1.0
		var sy := 1.0 if corner.y < sz.y * 0.5 else -1.0
		var tri := PackedVector2Array([
			corner + Vector2(sx * 4.0, sy * 4.0),
			corner + Vector2(sx * 32.0, sy * 4.0),
			corner + Vector2(sx * 4.0, sy * 32.0),
		])
		canvas.draw_colored_polygon(tri, brass)
		canvas.draw_circle(corner + Vector2(sx * 11.0, sy * 11.0), 2.5, rivet)


# =============================================================================
# INPUT, 3D PICKING, ANIMATIONS & LIVE STATE SYNC
# =============================================================================
func _gui_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		var sz := Vector2(maxf(1.0, size.x), maxf(1.0, size.y))
		_mouse_nx = clampf((m.position.x / sz.x) * 2.0 - 1.0, -1.0, 1.0)
		_mouse_ny = clampf((m.position.y / sz.y) * 2.0 - 1.0, -1.0, 1.0)
		if _ui_hovered_station == "":
			_set_hovered_station(_pick_station_at_screen_pos(m.position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(_book_panel) and _book_panel.get_global_rect().has_point(mb.global_position):
				return
			var hit := _pick_station_at_screen_pos(mb.position)
			if hit != "":
				_trigger_station(hit)
				accept_event()


func _pick_station_at_screen_pos(local_pos: Vector2) -> String:
	if not is_instance_valid(_cam) or not is_instance_valid(_vp) or not is_instance_valid(_vp_container):
		return ""
	var vp_sz := Vector2(maxi(1, _vp.size.x), maxi(1, _vp.size.y))
	var cont_sz := Vector2(maxf(1.0, _vp_container.size.x), maxf(1.0, _vp_container.size.y))
	var vp_pos := local_pos * (vp_sz / cont_sz)
	var ray_orig := _cam.project_ray_origin(vp_pos)
	var ray_dir := _cam.project_ray_normal(vp_pos).normalized()

	var best_key := ""
	var best_t := 9999.0
	for k in _station_order:
		var st: Dictionary = _stations[k]
		var center: Vector3 = st["hit_center"]
		var rad: float = float(st["hit_radius"])
		var oc := ray_orig - center
		var b := oc.dot(ray_dir)
		var c := oc.dot(oc) - rad * rad
		var disc := b * b - c
		if disc >= 0.0:
			var t := -b - sqrt(disc)
			if t > 0.0 and t < best_t:
				best_t = t
				best_key = k
	return best_key


func _set_hovered_station(next_key: String) -> void:
	if next_key == _pending_hover_key and next_key == _hovered_station:
		return
	_pending_hover_key = next_key
	_hover_debounce_t = HOVER_DEBOUNCE_SEC


func _commit_hovered_station(next_key: String) -> void:
	if next_key == _hovered_station:
		return
	_hovered_station = next_key
	if _hovered_station != "":
		var now_ms := Time.get_ticks_msec()
		if now_ms - _last_hover_sfx_ms >= HOVER_SFX_COOLDOWN_MS:
			_last_hover_sfx_ms = now_ms
			emit_signal("sfx_requested", "card_hover")


func _animate_stamp_press(key: String) -> void:
	var handle: Node3D = _stamp_handles.get(key, null)
	if not is_instance_valid(handle):
		return
	var base_y := float(handle.get_meta("base_y", handle.position.y))
	var tw := handle.create_tween()
	tw.tween_property(handle, "position:y", base_y - 0.022, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(handle, "position:y", base_y, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_hourglass_flip() -> void:
	if not is_instance_valid(_hourglass_body):
		return
	_hourglass_flip_deg += 180.0
	var tw := _hourglass_body.create_tween()
	tw.tween_property(_hourglass_body, "rotation_degrees:z", _hourglass_flip_deg, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_bell_pulse() -> void:
	if not is_instance_valid(_bell_horn):
		return
	var tw := _bell_horn.create_tween()
	tw.tween_property(_bell_horn, "scale", Vector3(1.16, 1.16, 1.16), 0.10).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_bell_horn, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _trigger_station(key: String) -> void:
	emit_signal("sfx_requested", "ui_click")
	match key:
		"language":
			_animate_stamp_press(key)
			var next_lang := "cs" if str(_opts.get("language", "en")) == "en" else "en"
			emit_signal("option_changed", "language", next_lang)
		"fullscreen":
			_animate_stamp_press(key)
			var next_fs := not bool(_opts.get("fullscreen", true))
			emit_signal("option_changed", "fullscreen", next_fs)
		"visual_mode":
			var order: Array[int] = [3, 0, 1, 2]
			var cur_i := order.find(int(_opts.get("visual_mode", 3)))
			var next_mode: int = order[(maxi(0, cur_i) + 1) % order.size()]
			emit_signal("option_changed", "visual_mode", next_mode)
		"high_fx":
			var next_fx := not bool(_opts.get("high_fx", true))
			emit_signal("option_changed", "high_fx", next_fx)
		"difficulty":
			_animate_stamp_press(key)
			emit_signal("difficulty_toggled")
		"game_pace":
			_animate_hourglass_flip()
			var pace_order := ["relaxed", "normal", "fast"]
			var cur_p := str(_opts.get("game_pace", "relaxed"))
			var ni := (maxi(0, pace_order.find(cur_p)) + 1) % pace_order.size()
			emit_signal("option_changed", "game_pace", pace_order[ni])
		"turn_timer_sec":
			_animate_hourglass_flip()
			var t_order: Array[int] = [30, 35, 45]
			var cur_t := int(_opts.get("turn_timer_sec", 35))
			var ti := (maxi(0, t_order.find(cur_t)) + 1) % t_order.size()
			emit_signal("option_changed", "turn_timer_sec", t_order[ti])
		"mute":
			_animate_bell_pulse()
			emit_signal("mute_toggled")
		"volume":
			var next_v := 0 if _vol_pct >= 100 else mini(100, _vol_pct + 20)
			emit_signal("volume_changed", next_v)
		"cam_sensitivity":
			var cur_s := float(_opts.get("cam_sensitivity", 1.0))
			var next_s := 0.5 if cur_s >= 1.95 else snappedf(minf(2.0, cur_s + 0.2), 0.1)
			emit_signal("option_changed", "cam_sensitivity", next_s)


func _refresh_all_visuals() -> void:
	var cs := (str(_opts.get("language", "en")) == "cs")
	var vm := int(_opts.get("visual_mode", 3))
	var hfx := bool(_opts.get("high_fx", true))
	var fs := bool(_opts.get("fullscreen", true))
	var is_trav := (str(_profile.get("campaign_difficulty", "traveler")) == "traveler")
	var gp := str(_opts.get("game_pace", "relaxed"))
	var sens := float(_opts.get("cam_sensitivity", 1.0))

	if is_instance_valid(_title_lbl):
		_title_lbl.text = "⚙ LIALO — NASTAVENÍ HRY" if cs else "⚙ LIALO — OPTIONS"
	if is_instance_valid(_close_btn):
		_close_btn.text = "✕ Zavřít [ESC]" if cs else "✕ Close [ESC]"
	if is_instance_valid(_done_btn):
		_done_btn.text = "✓ Uložit a zpět" if cs else "✓ Save & Resume"
	if is_instance_valid(_replay_tut_btn):
		_replay_tut_btn.text = "Zopakovat Tutoriál" if cs else "Replay Tutorial"
	if is_instance_valid(_return_btn):
		_return_btn.visible = (_screen_kind == "MATCH_3D" or _screen_kind == "WORLD_3D")
		if _screen_kind == "MATCH_3D":
			_return_btn.text = "← Zpět na Mapu" if cs else "← Return to Map"
		else:
			_return_btn.text = "← Zpět do Menu" if cs else "← Return to Lobby"

	if is_instance_valid(_left_hdr_lbl):
		_left_hdr_lbl.text = "OBRAZ A ATMOSFÉRA" if cs else "DISPLAY & ATMOSPHERE"
	if is_instance_valid(_right_hdr_lbl):
		_right_hdr_lbl.text = "ZVUK A HRATELNOST" if cs else "AUDIO & GAMEPLAY"

	if is_instance_valid(_codex_hdr_lbl):
		_codex_hdr_lbl.text = "KODEX OVLÁDÁNÍ" if cs else "CONTROLS CODEX"
	if is_instance_valid(_codex_keys_lbl):
		_codex_keys_lbl.text = (
			"[SPACE] Předměty → Karty  •  [W] Zahrát  •  [M] Výměna\n[Myš] Rozhlížení  •  [Pravé tl.] Kombo  •  [1/2/3] Seřadit"
			if cs else
			"[SPACE] Items → Cards  •  [W] Play  •  [M] Redraw\n[Mouse] Free Look  •  [RMB] Stage Combo  •  [1/2/3] Sort"
		)

	var vnames := {
		3: "Filmové 3D PBR" if cs else "Liar's Bar PBR",
		0: "Dřevoryt Inkoust" if cs else "Woodcut Ink",
		1: "Stará Sepie" if cs else "Broadsheet Sepia",
		2: "Čisté 3D" if cs else "Classic 3D",
	}
	var pnames := {
		"relaxed": "Pohodové (1.0×)" if cs else "Relaxed (1.0×)",
		"normal":  "Normální (1.4×)" if cs else "Normal (1.4×)",
		"fast":    "Rychlé (2.0×)" if cs else "Fast (2.0×)",
	}

	var row_labels := {
		"language":        "Jazyk / Language" if cs else "Language",
		"fullscreen":      "Obrazovka" if cs else "Display Mode",
		"visual_mode":     "Vizuální styl" if cs else "Visual Style",
		"high_fx":         "Efekty krčmy" if cs else "Tavern FX",
		"turn_timer_sec":  "Limit tahu" if cs else "Turn Timer",
		"difficulty":      "Obtížnost" if cs else "Difficulty",
		"game_pace":       "Tempo hry" if cs else "Game Pace",
		"mute":            "Zvuk" if cs else "Audio",
		"volume":          "Hlasitost" if cs else "Volume",
		"cam_sensitivity": "Citlivost myši" if cs else "Look Sens",
	}
	var t_sec := clampi(int(_opts.get("turn_timer_sec", 35)), 30, 45)
	var btn_texts := {
		"language":        "Čeština" if cs else "English",
		"fullscreen":      ("Celá obrazovka" if fs else "V okně") if cs else ("Fullscreen" if fs else "Windowed"),
		"visual_mode":     str(vnames.get(vm, vnames[3])),
		"high_fx":         ("Vysoké" if hfx else "Výkon") if cs else ("High" if hfx else "Performance"),
		"turn_timer_sec":  "%d s (Auto-líz)" % t_sec if cs else "%ds (Auto-Draw)" % t_sec,
		"difficulty":      ("Poutník (Lehčí)" if is_trav else "Klasická (Těžší)") if cs else ("Traveler (Easy)" if is_trav else "Classic (Hard)"),
		"game_pace":       str(pnames.get(gp, pnames["relaxed"])),
		"mute":            ("🔇 Ztlumeno" if cs else "🔇 Muted") if (_muted or _vol_pct <= 0) else ("🔊 Zapnuto" if cs else "🔊 Audio ON"),
	}

	for k in _row_widgets.keys():
		var w_map: Dictionary = _row_widgets[k]
		var nl: Label = w_map.get("name_lbl", null) as Label
		if is_instance_valid(nl) and row_labels.has(k):
			nl.text = str(row_labels[k])
		var bt: Button = w_map.get("btn", null) as Button
		if is_instance_valid(bt) and btn_texts.has(k):
			bt.text = str(btn_texts[k])
		var vl: Label = w_map.get("val_lbl", null) as Label
		if is_instance_valid(vl):
			if k == "volume":
				vl.text = "%d%%" % (0 if _muted else _vol_pct)
			elif k == "cam_sensitivity":
				vl.text = "%.1f×" % sens

	if is_instance_valid(_vol_slider):
		_vol_slider.set_value_no_signal(float(_vol_pct))
	if is_instance_valid(_sens_slider):
		_sens_slider.set_value_no_signal(sens)

	# Sync 3D Brass Dial Knobs (-135° to +135° around Y)
	if is_instance_valid(_vol_knob):
		var v_frac := clampf(float(_vol_pct) / 100.0, 0.0, 1.0)
		_vol_knob.rotation_degrees.y = lerpf(135.0, -135.0, v_frac)
	if is_instance_valid(_sens_knob):
		var s_frac := clampf((sens - 0.5) / 1.5, 0.0, 1.0)
		_sens_knob.rotation_degrees.y = lerpf(135.0, -135.0, s_frac)

	# Sync 3D Prism Lantern & Post-Processing Visual Mode Live Preview
	if is_instance_valid(_post_mat):
		_post_mat.set_shader_parameter("print_mode", vm)
	var mode_colors := {
		3: Color(1.0, 0.78, 0.34),
		0: Color(0.94, 0.88, 0.70),
		1: Color(0.92, 0.66, 0.36),
		2: Color(0.46, 0.88, 1.0),
	}
	var m_col: Color = mode_colors.get(vm, Color(1.0, 0.78, 0.34))
	if is_instance_valid(_lantern_core_node):
		_tint_named_mesh(_lantern_core_node, "CrystalCore", m_col, m_col, 2.4)
	if is_instance_valid(_lantern_light):
		_lantern_light.light_color = m_col

	# Sync 3D Wax Stamp colors for Difficulty (Emerald Traveler vs Crimson Classic)
	if _wax_meshes.has("difficulty") and is_instance_valid(_wax_meshes["difficulty"]):
		var d_col := Color(0.14, 0.46, 0.24) if is_trav else Color(0.56, 0.10, 0.14)
		var d_mat := StandardMaterial3D.new()
		d_mat.albedo_color = d_col
		d_mat.roughness = 0.34
		(_wax_meshes["difficulty"] as MeshInstance3D).material_override = d_mat

	# Sync Tavern FX dust motes & ember brazier intensity
	if is_instance_valid(_dust_particles):
		_dust_particles.emitting = hfx
	if is_instance_valid(_fx_flame_node):
		_fx_flame_node.scale = Vector3.ONE if hfx else Vector3(0.55, 0.45, 0.55)
	if is_instance_valid(_fx_light):
		_fx_light.light_energy = 1.65 if hfx else 0.45

	# Sync Gramophone Bell tilt when muted vs active
	if is_instance_valid(_bell_horn):
		_bell_horn.rotation_degrees.x = -22.0 if (_muted or _vol_pct <= 0) else 0.0


func _update_camera_pose(delta: float, snap: bool = false) -> void:
	if not is_instance_valid(_cam):
		return
	# Continuously track local mouse position even while over the foreground Codex book
	# so parallax never freezes & snaps when crossing button/book boundaries.
	var sz := Vector2(maxf(1.0, size.x), maxf(1.0, size.y))
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		var mp := get_local_mouse_position()
		_mouse_nx = clampf((mp.x / sz.x) * 2.0 - 1.0, -1.0, 1.0)
		_mouse_ny = clampf((mp.y / sz.y) * 2.0 - 1.0, -1.0, 1.0)

	var focus_shift := Vector3.ZERO
	if _hovered_station != "" and _stations.has(_hovered_station):
		var hp: Vector3 = _stations[_hovered_station]["base_pos"]
		focus_shift = Vector3(hp.x * 0.065, -0.012, hp.z * 0.045)

	var base_pos := CAM_OPEN_START_POS.lerp(CAM_BASE_POS, _cam_open_blend)
	if snap:
		_smooth_mouse_nx = _mouse_nx
		_smooth_mouse_ny = _mouse_ny
		var parallax_s := Vector3(_smooth_mouse_nx * 0.035, -_smooth_mouse_ny * 0.020, 0.0) * _cam_open_blend
		var desired_pos_s := base_pos + focus_shift + parallax_s
		var desired_target_s := CAM_BASE_TARGET + focus_shift * 0.55
		_cam.position = desired_pos_s
		_cam_cur_target = desired_target_s
		_cam.look_at(_cam_cur_target, Vector3.UP)
	else:
		var dt := minf(delta, 0.05)
		var k_mouse := 1.0 - exp(-8.5 * dt)
		var k_pos := 1.0 - exp(-7.2 * dt)
		var k_tgt := 1.0 - exp(-6.4 * dt)
		_smooth_mouse_nx = lerpf(_smooth_mouse_nx, _mouse_nx, k_mouse)
		_smooth_mouse_ny = lerpf(_smooth_mouse_ny, _mouse_ny, k_mouse)
		var parallax := Vector3(_smooth_mouse_nx * 0.035, -_smooth_mouse_ny * 0.020, 0.0) * _cam_open_blend
		var desired_pos := base_pos + focus_shift + parallax
		var desired_target := CAM_BASE_TARGET + focus_shift * 0.55
		_cam.position = _cam.position.lerp(desired_pos, k_pos)
		_cam_cur_target = _cam_cur_target.lerp(desired_target, k_tgt)
		_cam.look_at(_cam_cur_target, Vector3.UP)


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := minf(delta, 0.05)
	_time_acc += dt
	if _pending_hover_key != _hovered_station:
		_hover_debounce_t -= dt
		if _hover_debounce_t <= 0.0:
			_commit_hovered_station(_pending_hover_key)
	_update_camera_pose(dt, false)

	# Candlelight & FX flame subtle tavern flicker
	if is_instance_valid(_candle_light):
		_candle_light.light_energy = 2.55 + sin(_time_acc * 7.2) * 0.14 + cos(_time_acc * 13.4) * 0.08
	if is_instance_valid(_fx_flame_node):
		var hfx := bool(_opts.get("high_fx", true))
		var base_s := 1.0 if hfx else 0.50
		var flick := 1.0 + sin(_time_acc * 9.8) * (0.12 if hfx else 0.03)
		_fx_flame_node.scale = Vector3(base_s * (1.0 + sin(_time_acc * 6.0) * 0.04), base_s * flick, base_s)

	# Hover levitation & smooth golden spotlight focus on 3D Study props
	var k_prop := 1.0 - exp(-12.0 * dt)
	var k_spot := 1.0 - exp(-9.5 * dt)
	var target_spot_energy := 0.0
	for k in _station_order:
		var st: Dictionary = _stations[k]
		var r: Node3D = st["root"]
		if not is_instance_valid(r):
			continue
		var is_hov := (k == _hovered_station)
		var base_p: Vector3 = st["base_pos"]
		var target_y := base_p.y + (0.024 + sin(_time_acc * 4.2) * 0.004 if is_hov else 0.0)
		r.position.y = lerpf(r.position.y, target_y, k_prop)
		if is_hov and is_instance_valid(_hover_spot):
			_hover_spot.position = _hover_spot.position.lerp(base_p + Vector3(0.0, 0.86, 0.25), k_spot)
			_spot_cur_target = _spot_cur_target.lerp(base_p + Vector3(0.0, 0.08, 0.0), k_spot)
			_hover_spot.look_at(_spot_cur_target, Vector3.UP)
			target_spot_energy = 2.8

	if is_instance_valid(_hover_spot):
		_hover_spot.light_energy = lerpf(_hover_spot.light_energy, target_spot_energy, k_spot)
