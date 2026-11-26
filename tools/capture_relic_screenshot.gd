extends SceneTree

const RelicFactory = preload("res://scripts/relic_mesh_factory.gd")
const Toon = preload("res://scripts/toon_style.gd")

const OUT_PATH := "C:/Users/arnos/.gemini/antigravity/brain/7f5a7ecb-3428-465f-896a-bb95771f2800/tankard_relic_preview.png"

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
	outer.offset_left = 20
	outer.offset_right = -20
	outer.offset_top = 16
	outer.offset_bottom = -16
	outer.add_theme_constant_override("separation", 12)
	canvas.add_child(outer)

	var hdr := Label.new()
	hdr.text = "TRELIC_WAR_HORN  —  Tavern Ale Tankard (Hand-Drawn 3D Prototype)"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 24)
	hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.46))
	outer.add_child(hdr)

	var grid := HBoxContainer.new()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 14)
	outer.add_child(grid)

	# Left Hero Close-up (front-right 3/4 view showing crest, staves, rivets, foam crown & drips)
	grid.add_child(_make_angle_panel(
		"HERO FRONT 3/4 (Crest, Staves, Rivets & Sculpted Foam)",
		Vector3(0.145, 0.142, 0.215),
		Vector3(0.005, 0.068, 0.0),
		34.0,
		1.45,
		false
	))

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.85
	right_col.add_theme_constant_override("separation", 14)
	grid.add_child(right_col)

	# Top-right: Handle & Back/Side Clasp angle
	right_col.add_child(_make_angle_panel(
		"HANDLE & CLASP ANGLE (Scroll Handle, Thumb-Rest & Riveted Straps)",
		Vector3(0.205, 0.132, -0.142),
		Vector3(0.014, 0.068, 0.0),
		34.0,
		0.95,
		false
	))

	# Bottom-right: Tabletop Duel POV with oak surface
	right_col.add_child(_make_angle_panel(
		"IN-GAME TABLETOP POV (Dark Oak Surface + ReadyHalo)",
		Vector3(-0.095, 0.200, 0.235),
		Vector3(0.0, 0.064, 0.0),
		36.0,
		0.95,
		true
	))

	process_frame.connect(_on_frame)


func _make_angle_panel(title_txt: String, cam_pos: Vector3, look_tgt: Vector3, fov_deg: float, stretch_r: float, show_table: bool) -> PanelContainer:
	var pan := PanelContainer.new()
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pan.size_flags_stretch_ratio = stretch_r
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.055, 1.0)
	sb.border_color = Color(0.76, 0.58, 0.26, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	pan.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pan.add_child(vb)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66))
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
	env.background_color = Color(0.11, 0.085, 0.068, 1.0) if not show_table else Color(0.065, 0.050, 0.038, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.46, 0.36)
	env.ambient_light_energy = 0.65
	we.environment = env
	vp.add_child(we)

	# Warm candle key light + cool teal fill rim light
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.90, 0.72)
	key.light_energy = 1.65
	key.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	vp.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.35, 0.25, -0.30)
	rim.light_color = Color(0.48, 0.78, 0.96)
	rim.light_energy = 1.15
	vp.add_child(rim)

	if show_table:
		var tbl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.8, 0.8)
		tbl.mesh = pm
		tbl.material_override = Toon.pbr(Color(0.24, 0.16, 0.11), "res://assets/table/wood.png", 0.72, 0.04)
		vp.add_child(tbl)

	var relic := RelicFactory.build_relic_3d_mesh("TRELIC_WAR_HORN", Color(0.95, 0.74, 0.28))
	vp.add_child(relic)

	var cam := Camera3D.new()
	cam.fov = fov_deg
	vp.add_child(cam)
	cam.look_at_from_position(cam_pos, look_tgt, Vector3.UP)

	return pan


func _on_frame() -> void:
	_frames += 1
	if _done or _frames < 28:
		return
	_done = true
	var img := get_root().get_texture().get_image()
	if img != null and not img.is_empty():
		var err := img.save_png(OUT_PATH)
		print("CAPTURED RELIC SCREENSHOT: %s (err=%d, size=%dx%d)" % [OUT_PATH, err, img.get_width(), img.get_height()])
	else:
		printerr("FAILED: viewport image is empty")
	quit(0)
