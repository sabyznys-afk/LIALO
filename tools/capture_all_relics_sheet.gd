extends SceneTree

const RelicFactory = preload("res://scripts/relic_mesh_factory.gd")
const Toon = preload("res://scripts/toon_style.gd")

const OUT_PATH := "C:/Users/arnos/.gemini/antigravity/brain/7f5a7ecb-3428-465f-896a-bb95771f2800/all_9_relics_preview.png"

const RELICS := [
	{"id": "TRELIC_HOLLOW_MASK", "name": "Loaded Bone Dice", "col": Color(0.94, 0.84, 0.48)},
	{"id": "TRELIC_STAR_BOW", "name": "Arcane Slate Rune", "col": Color(0.36, 0.88, 1.0)},
	{"id": "TRELIC_BLOOD_SEAL", "name": "Crimson Blood Goblet", "col": Color(0.96, 0.22, 0.28)},
	{"id": "TRELIC_IRON_CHAIN", "name": "Executioner's Whetstone", "col": Color(0.84, 0.88, 0.96)},
	{"id": "TRELIC_ASH_GLASS", "name": "Fate Hourglass", "col": Color(0.98, 0.82, 0.34)},
	{"id": "TRELIC_GOLD_SCALES", "name": "Guild Coin Purse", "col": Color(1.0, 0.84, 0.26)},
	{"id": "TRELIC_SOUL_BELL", "name": "Graveyard Toll Bell", "col": Color(0.42, 0.90, 0.86)},
	{"id": "TRELIC_CENSER", "name": "Alchemist's Ember Censer", "col": Color(1.0, 0.56, 0.20)},
	{"id": "TRELIC_PHOENIX_BOX", "name": "Phoenix Ember Reliquary", "col": Color(1.0, 0.44, 0.18)},
]

var _frames := 0
var _done := false


func _initialize() -> void:
	var root := get_root()
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.042, 0.032, 1.0)
	canvas.add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 18; outer.offset_right = -18
	outer.offset_top = 12; outer.offset_bottom = -12
	outer.add_theme_constant_override("separation", 10)
	canvas.add_child(outer)

	var hdr := Label.new()
	hdr.text = "LIALO — ALL 9 REWORKED HAND-DRAWN 3D TABLETOP RELICS (Tankard Norm)"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.46))
	outer.add_child(hdr)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	outer.add_child(grid)

	for r in RELICS:
		grid.add_child(_make_relic_cell(str(r["id"]), str(r["name"]), r["col"]))

	process_frame.connect(_on_frame)


func _make_relic_cell(rel_id: String, rel_name: String, col: Color) -> PanelContainer:
	var pan := PanelContainer.new()
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.055, 1.0)
	sb.border_color = Color(col.r, col.g, col.b, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	pan.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pan.add_child(vb)

	var lbl := Label.new()
	lbl.text = "%s  (%s)" % [rel_name, rel_id]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.72))
	vb.add_child(lbl)

	var svc := SubViewportContainer.new()
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	vb.add_child(svc)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.105, 0.082, 0.065, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.48, 0.38)
	env.ambient_light_energy = 0.70
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.90, 0.72)
	key.light_energy = 1.65
	key.rotation_degrees = Vector3(-40.0, 38.0, 0.0)
	vp.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.32, 0.24, -0.28)
	rim.light_color = Color(0.48, 0.78, 0.96)
	rim.light_energy = 1.15
	vp.add_child(rim)

	var relic := RelicFactory.build_relic_3d_mesh(rel_id, col)
	vp.add_child(relic)

	var cam := Camera3D.new()
	cam.fov = 34.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.135, 0.138, 0.195), Vector3(0.0, 0.056, 0.0), Vector3.UP)

	return pan


func _on_frame() -> void:
	_frames += 1
	if _done or _frames < 26:
		return
	_done = true
	var img := get_root().get_texture().get_image()
	if img != null and not img.is_empty():
		var err := img.save_png(OUT_PATH)
		print("CAPTURED ALL 9 RELICS SHEET: %s (err=%d, size=%dx%d)" % [OUT_PATH, err, img.get_width(), img.get_height()])
	else:
		printerr("FAILED: viewport image empty")
	quit(0)
