class_name RelicInspect3D
extends Control

## CS2-style 360-degree rotatable & zoomable 3D Relic Inspection Modal.
## Supports both passive Core Relics (REL_*) and active Tabletop Relics (TRELIC_*),
## plus clean non-overlapping metadata rows and headless-safe rendering.

signal closed()

var _overlay: PanelContainer
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _title_lbl: Label
var _cat_lbl: Label
var _status_lbl: Label
var _source_lbl: Label
var _desc_lbl: Label
var _hint_lbl: Label

var _dragging := false
var _last_mouse := Vector2.ZERO
var _rot_yaw := 0.45
var _rot_pitch := -0.22
var _zoom_dist := 1.45
var _auto_spin := true
var _is_headless := false


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 95

	# Dimmed backdrop
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.025, 0.02, 0.84)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_inspect()
	)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_overlay = PanelContainer.new()
	_overlay.custom_minimum_size = Vector2(780, 480)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.075, 0.060, 0.048, 0.98)
	st.border_color = Color(0.76, 0.60, 0.28, 0.92)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.set_content_margin_all(22)
	_overlay.add_theme_stylebox_override("panel", st)
	center.add_child(_overlay)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	_overlay.add_child(hbox)

	# Left: 3D SubViewport
	var vp_frame := PanelContainer.new()
	vp_frame.custom_minimum_size = Vector2(360, 420)
	var vp_st := StyleBoxFlat.new()
	vp_st.bg_color = Color(0.035, 0.028, 0.024, 1.0)
	vp_st.border_color = Color(0.45, 0.36, 0.20, 0.75)
	vp_st.set_border_width_all(1)
	vp_st.set_corner_radius_all(8)
	vp_frame.add_theme_stylebox_override("panel", vp_st)
	hbox.add_child(vp_frame)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_container.gui_input.connect(_on_viewport_input)
	vp_frame.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(360, 420)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _is_headless else SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)

	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color(0.46, 0.40, 0.34)
	we.ambient_light_energy = 1.15
	env.environment = we
	_viewport.add_child(env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	key_light.light_color = Color(1.0, 0.90, 0.74)
	key_light.light_energy = 1.85
	_viewport.add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-1.4, 0.8, -1.2)
	rim_light.light_color = Color(0.42, 0.78, 1.0)
	rim_light.light_energy = 1.6
	_viewport.add_child(rim_light)

	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, 0.16, _zoom_dist)
	_cam.fov = 38.0
	_viewport.add_child(_cam)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	# Right: Clean Metadata Column (zero overlap!)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)
	hbox.add_child(info)

	var top_bar := HBoxContainer.new()
	info.add_child(top_bar)

	_cat_lbl = Label.new()
	_cat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cat_lbl.add_theme_font_size_override("font_size", 12)
	_cat_lbl.add_theme_color_override("font_color", Color(0.84, 0.70, 0.38))
	top_bar.add_child(_cat_lbl)

	var close_btn := Button.new()
	close_btn.text = "ESC"
	close_btn.custom_minimum_size = Vector2(56, 28)
	LialoIcons.apply_button_icon(close_btn, "cross", 14)
	close_btn.pressed.connect(close_inspect)
	top_bar.add_child(close_btn)

	_title_lbl = Label.new()
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	info.add_child(_title_lbl)

	# Status + Source on separate clean rows so they never collide!
	var meta_box := VBoxContainer.new()
	meta_box.add_theme_constant_override("separation", 6)
	info.add_child(meta_box)

	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.52, 0.92, 0.64))
	meta_box.add_child(_status_lbl)

	_source_lbl = Label.new()
	_source_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_lbl.add_theme_font_size_override("font_size", 12)
	_source_lbl.add_theme_color_override("font_color", Color(0.76, 0.74, 0.68))
	meta_box.add_child(_source_lbl)

	var sep := HSeparator.new()
	info.add_child(sep)

	_desc_lbl = Label.new()
	_desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_font_size_override("font_size", 15)
	_desc_lbl.add_theme_color_override("font_color", Color(0.90, 0.87, 0.80))
	info.add_child(_desc_lbl)

	_hint_lbl = Label.new()
	_hint_lbl.add_theme_font_size_override("font_size", 12)
	_hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.52))
	info.add_child(_hint_lbl)


func _process(delta: float) -> void:
	if not visible or _pivot == null:
		return
	if _auto_spin and not _dragging:
		_rot_yaw += delta * 0.45
	_pivot.rotation = Vector3(_rot_pitch, _rot_yaw, 0.0)
	if _cam != null:
		_cam.position.z = lerpf(_cam.position.z, _zoom_dist, minf(1.0, delta * 12.0))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_inspect()
		get_viewport().set_input_as_handled()


func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_auto_spin = false
			_last_mouse = mb.position
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_dist = clampf(_zoom_dist - 0.14, 0.75, 2.6)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_dist = clampf(_zoom_dist + 0.14, 0.75, 2.6)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var d := mm.position - _last_mouse
		_last_mouse = mm.position
		_rot_yaw += d.x * 0.012
		_rot_pitch = clampf(_rot_pitch + d.y * 0.012, -1.15, 1.15)


func inspect_relic(relic_id: String, lang: String = "en", is_unlocked: bool = true, is_equipped: bool = false, source_text: String = "") -> void:
	var cs := lang == "cs"
	var data := LialoCatalog.get_relic(relic_id)
	var is_table := false
	if data.is_empty():
		data = LialoCatalog.get_table_relic(relic_id)
		is_table = not data.is_empty()
	if data.is_empty():
		return

	_title_lbl.text = str(data.get("name_cs" if cs else "name", data.get("name", relic_id)))
	_cat_lbl.text = str(data.get("category_cs" if cs else "category", data.get("category", "Tabletop Relic" if is_table else "Core Relic"))).to_upper()
	_desc_lbl.text = str(data.get("desc_cs" if cs else "desc", data.get("desc", "")))
	if is_equipped:
		_status_lbl.text = "EQUIPPED (ACTIVE)" if not cs else "NASAZENO (AKTIVNÍ)"
		_status_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.34))
	elif is_unlocked:
		_status_lbl.text = "UNLOCKED (MP & DECK READY)" if not cs else "ODEMČENO (PŘIPRAVENO PRO MP I BALÍČEK)"
		_status_lbl.add_theme_color_override("font_color", Color(0.52, 0.92, 0.64))
	else:
		_status_lbl.text = "LOCKED" if not cs else "ZAMČENO"
		_status_lbl.add_theme_color_override("font_color", Color(0.88, 0.42, 0.38))

	var src := source_text.strip_edges()
	if src.is_empty():
		src = str(data.get("unlock_hint", "Campaign & Tavern Arsenal" if not cs else "Kampaň a Tavernowý arzenál"))
	_source_lbl.text = ("Source: " if not cs else "Zdroj: ") + src
	_hint_lbl.text = "Drag to rotate 360° • Scroll to zoom • ESC to close" if not cs else "Táhni myší pro 360° rotaci • Kolečko: zoom • ESC: zavřít"

	_rot_yaw = 0.45
	_rot_pitch = -0.22
	_zoom_dist = 1.45
	_auto_spin = true
	_load_relic_mesh(relic_id, data.get("col", Color(0.85, 0.68, 0.32)) as Color)
	visible = true


func close_inspect() -> void:
	if not visible:
		return
	visible = false
	_dragging = false
	closed.emit()


func _load_relic_mesh(relic_id: String, accent: Color) -> void:
	for c in _pivot.get_children():
		c.queue_free()
	var glb_path := LialoCatalog.get_relic_glb_path(relic_id)
	if glb_path != "" and ResourceLoader.exists(glb_path):
		var packed := load(glb_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			if inst is Node3D:
				_normalize_and_add(inst as Node3D)
				return
	# Fallback sculpted brass pedestal if GLB unavailable
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.45, 0.45)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent
	mat.metallic = 0.72
	mat.roughness = 0.28
	mi.material_override = mat
	_pivot.add_child(mi)


func _normalize_and_add(node: Node3D) -> void:
	_pivot.add_child(node)
	var aabb := _compute_aabb(node)
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if max_dim > 0.001:
		var scale_f := 0.72 / max_dim
		node.scale = Vector3.ONE * scale_f
		var center := aabb.get_center() * scale_f
		node.position = -center


func _compute_aabb(node: Node3D) -> AABB:
	var has_box := false
	var total := AABB()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var b := mi.get_aabb()
			if not has_box:
				total = b
				has_box = true
			else:
				total = total.merge(b)
		for ch in cur.get_children():
			stack.append(ch)
	return total if has_box else AABB(Vector3(-0.25, -0.25, -0.25), Vector3(0.5, 0.5, 0.5))
