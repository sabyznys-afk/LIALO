class_name RelicInspect3D
extends Control

## Transparent In-Game 360-degree Rotatable & Zoomable 3D Relic / Prop Inspection Overlay.
## Renders directly over the live duel table & rival (no opaque black box!)
## Uses sculpted hand-drawn RelicMeshFactory meshes for all 10 TRELIC_*, swords, and table props
## so inspected items NEVER fall back to a gray cube.

signal closed()

const RelicFactory = preload("res://scripts/relic_mesh_factory.gd")
const LialoIcons = preload("res://scripts/ui/lialo_icons.gd")

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

	# Subtle translucent bokeh dim — Rival & 3D Tavern Table remain clearly visible behind!
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.012, 0.28)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_inspect()
	)
	add_child(bg)

	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 48
	layout.offset_right = -48
	layout.offset_top = 48
	layout.offset_bottom = -48
	layout.add_theme_constant_override("separation", 24)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)

	# Left/Center (62%): Completely Borderless Transparent 3D SubViewport directly over the game!
	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_stretch_ratio = 1.65
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_container.gui_input.connect(_on_viewport_input)
	layout.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(680, 560)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _is_headless else SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)

	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color(0.56, 0.48, 0.40)
	we.ambient_light_energy = 1.25
	env.environment = we
	_viewport.add_child(env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	key_light.light_color = Color(1.0, 0.90, 0.74)
	key_light.light_energy = 1.95
	_viewport.add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-1.4, 0.8, -1.2)
	rim_light.light_color = Color(0.42, 0.78, 1.0)
	rim_light.light_energy = 1.6
	_viewport.add_child(rim_light)

	_cam = Camera3D.new()
	_cam.position = Vector3(0.0, 0.12, _zoom_dist)
	_cam.fov = 38.0
	_viewport.add_child(_cam)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	# Right (32%): Compact Translucent Woodcut Parchment/Oak Card (not blocking rival!)
	var right_wrap := CenterContainer.new()
	right_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrap.size_flags_stretch_ratio = 0.85
	right_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(right_wrap)

	_overlay = PanelContainer.new()
	_overlay.custom_minimum_size = Vector2(360, 340)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.075, 0.058, 0.044, 0.84)
	st.border_color = Color(0.84, 0.66, 0.28, 0.94)
	st.set_border_width_all(2)
	st.border_width_bottom = 4
	st.set_corner_radius_all(12)
	st.set_content_margin_all(18)
	_overlay.add_theme_stylebox_override("panel", st)
	right_wrap.add_child(_overlay)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	_overlay.add_child(info)

	var top_bar := HBoxContainer.new()
	info.add_child(top_bar)

	_cat_lbl = Label.new()
	_cat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cat_lbl.add_theme_font_size_override("font_size", 12)
	_cat_lbl.add_theme_color_override("font_color", Color(0.88, 0.72, 0.38))
	top_bar.add_child(_cat_lbl)

	var close_btn := Button.new()
	close_btn.text = "ESC"
	close_btn.custom_minimum_size = Vector2(64, 30)
	LialoIcons.apply_button_icon(close_btn, "cross", 14)
	close_btn.pressed.connect(close_inspect)
	top_bar.add_child(close_btn)

	_title_lbl = Label.new()
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ResourceLoader.exists("res://assets/fonts/LialoDisplay.ttf"):
		_title_lbl.add_theme_font_override("font", load("res://assets/fonts/LialoDisplay.ttf") as Font)
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	info.add_child(_title_lbl)

	var body_font: Font = load("res://assets/fonts/LialoBody.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoBody.ttf") else null
	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font != null:
		_status_lbl.add_theme_font_override("font", body_font)
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.52, 0.92, 0.64))
	info.add_child(_status_lbl)

	_source_lbl = Label.new()
	_source_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font != null:
		_source_lbl.add_theme_font_override("font", body_font)
	_source_lbl.add_theme_font_size_override("font_size", 12)
	_source_lbl.add_theme_color_override("font_color", Color(0.76, 0.74, 0.68))
	info.add_child(_source_lbl)

	info.add_child(HSeparator.new())

	_desc_lbl = Label.new()
	_desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body_font != null:
		_desc_lbl.add_theme_font_override("font", body_font)
	_desc_lbl.add_theme_font_size_override("font_size", 15)
	_desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	info.add_child(_desc_lbl)

	_hint_lbl = Label.new()
	if body_font != null:
		_hint_lbl.add_theme_font_override("font", body_font)
	_hint_lbl.add_theme_font_size_override("font_size", 12)
	_hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.66, 0.56))
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
	if visible and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
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
			_zoom_dist = clampf(_zoom_dist - 0.14, 0.72, 2.8)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_dist = clampf(_zoom_dist + 0.14, 0.72, 2.8)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var d := mm.position - _last_mouse
		_last_mouse = mm.position
		_rot_yaw += d.x * 0.012
		_rot_pitch = clampf(_rot_pitch + d.y * 0.012, -1.15, 1.15)


func inspect_relic(relic_id: String, lang: String = "en", is_unlocked: bool = true, is_equipped: bool = false, source_text: String = "") -> void:
	var cs := lang == "cs"
	var data := LialoCatalog.get_table_relic(relic_id)
	var is_table := not data.is_empty()
	if data.is_empty():
		data = LialoCatalog.get_relic(relic_id)
	if data.is_empty():
		return

	_title_lbl.text = str(data.get("name_cs" if cs else "name", data.get("name", relic_id)))
	_cat_lbl.text = str(data.get("category_cs" if cs else "category", data.get("category", "Tabletop Relic" if is_table else "Relic"))).to_upper()
	_desc_lbl.text = str(data.get("desc_cs" if cs else "desc", data.get("desc", "")))
	if is_equipped:
		_status_lbl.text = "EQUIPPED (ACTIVE)" if not cs else "NASAZENO (AKTIVNÍ)"
		_status_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.34))
	elif is_unlocked:
		_status_lbl.text = "UNLOCKED (MP & DECK READY)" if not cs else "ODEMČENO (PŘIPRAVENO)"
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
	_zoom_dist = 1.38
	_auto_spin = true
	_load_relic_mesh(relic_id, data.get("col", Color(0.85, 0.68, 0.32)) as Color)
	visible = true


func inspect_prop(prop_id: String, title: String, category: String, desc: String, glb_path: String = "", accent: Color = Color(0.85, 0.68, 0.32), lang: String = "en", custom_node: Node3D = null) -> void:
	var cs := lang == "cs"
	_title_lbl.text = title if title != "" else prop_id
	_cat_lbl.text = (category if category != "" else ("TAVERN PROP" if not cs else "STOLNÍ PŘEDMĚT")).to_upper()
	_desc_lbl.text = desc
	_status_lbl.text = "3D TABLETOP INSPECT" if not cs else "3D PROHLÍDKA PŘEDMĚTU"
	_status_lbl.add_theme_color_override("font_color", Color(0.96, 0.82, 0.38))
	_source_lbl.text = ("Table Item: " if not cs else "Předmět na stole: ") + prop_id
	_hint_lbl.text = "Drag to rotate 360° • Scroll to zoom • ESC to close" if not cs else "Táhni myší pro 360° rotaci • Kolečko: zoom • ESC: zavřít"
	_rot_yaw = 0.45
	_rot_pitch = -0.22
	_zoom_dist = 1.42
	_auto_spin = true
	for c in _pivot.get_children():
		c.queue_free()
	if is_instance_valid(custom_node):
		_normalize_and_add(custom_node)
	elif glb_path != "" and ResourceLoader.exists(glb_path):
		var packed := load(glb_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			if inst is Node3D:
				_normalize_and_add(inst as Node3D)
				visible = true
				return
	else:
		_load_prop_mesh_or_relic(prop_id, accent)
	visible = true


func close_inspect() -> void:
	if not visible:
		return
	visible = false
	_dragging = false
	closed.emit()


func _load_prop_mesh_or_relic(prop_id: String, accent: Color) -> void:
	if prop_id == "sword" or prop_id.begins_with("SWORD_"):
		var sw := RelicFactory.build_sword_3d_mesh(prop_id if prop_id.begins_with("SWORD_") else "SWORD_IRON")
		if sw != null:
			_normalize_and_add(sw)
			return
	elif prop_id == "phial":
		var nd := Node3D.new()
		RelicFactory.build_hellfire_phial_meshes(nd)
		_normalize_and_add(nd)
		return
	elif prop_id == "bell":
		var nd := Node3D.new()
		RelicFactory.build_shop_bell_meshes(nd)
		_normalize_and_add(nd)
		return
	elif prop_id == "coins":
		var nd := Node3D.new()
		RelicFactory.build_coins_pouch_meshes(nd)
		_normalize_and_add(nd)
		return
	elif prop_id == "dice":
		var nd := Node3D.new()
		RelicFactory.build_bone_dice_meshes(nd)
		_normalize_and_add(nd)
		return
	elif prop_id == "mug":
		var nd := Node3D.new()
		RelicFactory.build_tavern_mug_meshes(nd)
		_normalize_and_add(nd)
		return
	_load_relic_mesh(prop_id, accent)


func _load_relic_mesh(relic_id: String, accent: Color) -> void:
	for c in _pivot.get_children():
		c.queue_free()
	var built := RelicFactory.build_relic_3d_mesh(relic_id, accent)
	if built != null:
		_normalize_and_add(built)
		return
	var glb_path := LialoCatalog.get_relic_glb_path(relic_id)
	if glb_path != "" and ResourceLoader.exists(glb_path):
		var packed := load(glb_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			if inst is Node3D:
				_normalize_and_add(inst as Node3D)
				return


func _normalize_and_add(node: Node3D) -> void:
	_pivot.add_child(node)
	var aabb := _compute_aabb(node)
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if max_dim > 0.001:
		var scale_f := 0.85 / max_dim
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
