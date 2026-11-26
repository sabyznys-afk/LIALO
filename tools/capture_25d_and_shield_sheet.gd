extends SceneTree

const Toon = preload("res://scripts/toon_style.gd")
const SwordCardAnimatorScript = preload("res://scripts/sword_card_animator.gd")
const PowerVfxScript = preload("res://scripts/battle/power_card_vfx_showcase.gd")
const HeartbeatHpScript = preload("res://scripts/heartbeat_hp_display.gd")

const OUT_VFX_PATH := "C:/Users/arnos/.gemini/antigravity/brain/7f5a7ecb-3428-465f-896a-bb95771f2800/living_power_cards_25d_preview.png"
const OUT_SHIELD_PATH := "C:/Users/arnos/.gemini/antigravity/brain/7f5a7ecb-3428-465f-896a-bb95771f2800/knight_shield_hud_preview.png"

var _frames := 0
var _spawned := false
var _done := false
var _vfx_root: Control
var _grid: GridContainer
var _shield_vp: SubViewport


func _initialize() -> void:
	# Silence audio during GPU screenshot capture
	AudioServer.set_bus_mute(0, true)

	var root := get_root()
	root.size = Vector2i(1920, 1080)

	# -------------------------------------------------------------------------
	# 1. Build Main Root UI: 2x3 Hybrid 2.5D VFX Contact Sheet (1920x1080)
	# -------------------------------------------------------------------------
	_vfx_root = Control.new()
	_vfx_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_vfx_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.040, 0.032, 1.0)
	_vfx_root.add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 18; outer.offset_right = -18
	outer.offset_top = 12; outer.offset_bottom = -12
	outer.add_theme_constant_override("separation", 10)
	_vfx_root.add_child(outer)

	var hdr := Label.new()
	hdr.text = "LIALO — HYBRID 2.5D MERGE SHOWCASE (3D Tavern + Hand-Drawn 2D Cutouts, Shaders & Ink VFX)"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.46))
	outer.add_child(hdr)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	outer.add_child(_grid)

	# -------------------------------------------------------------------------
	# 2. Separate SubViewport for Knight 3-Part Aegis Shield Strip (1280x420)
	# -------------------------------------------------------------------------
	_shield_vp = SubViewport.new()
	_shield_vp.size = Vector2i(1280, 420)
	_shield_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_build_knight_shield_strip(_shield_vp)
	root.add_child(_shield_vp)

	process_frame.connect(_on_frame)


func _spawn_all_vfx_tiles() -> void:
	# Row 1: Knight Mistblade + Vampire Eclipse Chalice/Bats + Storm Tempest Spear
	_make_sword_cell(
		_grid,
		"2.5D WEAPON STRIKE: KNIGHT MISTBLADE (SWING + CEL)",
		{"rank": "E", "suit": "CERVEN", "edition": "KNIGHT"},
		Color(0.32, 0.92, 1.0),
		20
	)
	_make_power_cell(
		_grid,
		"LIVING 2.5D: VAMPIRE LEECH (Spinning Eclipse + Flying Bats + Rubies)",
		"SPEC_VAMPIRE",
		Color(0.95, 0.22, 0.30),
		2.08
	)
	_make_power_cell(
		_grid,
		"LIVING 2.5D: THUNDER STRIKE (Spear + Hand-Drawn Sparks)",
		"SPEC_STORM",
		Color(0.32, 0.92, 1.0),
		2.08
	)

	# Row 2: Ash Phoenix + Mirror Gate + Alchemist Crucible
	_make_power_cell(
		_grid,
		"LIVING 2.5D: ASH PHOENIX (Wing-Flap + 2.5D Feathers)",
		"SPEC_PHOENIX",
		Color(1.0, 0.54, 0.18),
		2.12
	)
	_make_power_cell(
		_grid,
		"LIVING 2.5D: MIRROR GATE (Liquid Glass + 2.5D Shards)",
		"SPEC_MIRROR",
		Color(0.56, 0.90, 1.0),
		2.08
	)
	_make_power_cell(
		_grid,
		"ALCHEMY CRUCIBLE: SPEC_ALCHEMIST (Layered Vapor + Ink Sparks)",
		"SPEC_ALCHEMIST",
		Color(0.54, 0.96, 0.42),
		2.08
	)


func _make_sword_cell(parent_grid: GridContainer, title_txt: String, card_data: Dictionary, border_col: Color, step_count: int) -> PanelContainer:
	var pan := _make_cell_frame(title_txt, border_col)
	parent_grid.add_child(pan)
	var vb: VBoxContainer = pan.get_child(0) as VBoxContainer

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

	var world := Node3D.new()
	vp.add_child(world)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.045, 0.038, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.44, 0.34)
	env.ambient_light_energy = 0.72
	we.environment = env
	world.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.88, 0.70)
	key.light_energy = 1.65
	key.rotation_degrees = Vector3(-44.0, 32.0, 0.0)
	world.add_child(key)

	var candle := OmniLight3D.new()
	candle.position = Vector3(-0.62, 1.24, 0.30)
	candle.light_color = Color(1.0, 0.68, 0.32)
	candle.light_energy = 2.0
	candle.omni_range = 3.2
	world.add_child(candle)

	# 3D Tavern Wood Table + Card on table so 2.5D weapon strike sits in real 3D diorama
	var wood_mat := Toon.pbr(Color(0.32, 0.20, 0.12), "res://assets/table/wood.png", 0.65, 0.05, Vector2(2.4, 2.4))
	var tbl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.35
	cyl.bottom_radius = 1.30
	cyl.height = 0.08
	cyl.radial_segments = 48
	tbl.mesh = cyl
	tbl.position = Vector3(0.0, 0.78, 0.0)
	tbl.material_override = wood_mat
	world.add_child(tbl)

	var felt := MeshInstance3D.new()
	var fcyl := CylinderMesh.new()
	fcyl.top_radius = 0.88
	fcyl.bottom_radius = 0.88
	fcyl.height = 0.014
	fcyl.radial_segments = 40
	felt.mesh = fcyl
	felt.position = Vector3(0.0, 0.822, 0.0)
	var felt_mat := Toon.pbr(Color(0.10, 0.24, 0.15), "", 0.88, 0.02)
	felt.material_override = felt_mat
	world.add_child(felt)

	var cam := Camera3D.new()
	cam.fov = 44.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.38, 0.96), Vector3(0.0, 1.06, -0.04), Vector3.UP)

	var rig := SwordCardAnimatorScript.play_sword_card_score_anim(
		world,
		card_data,
		null,
		true,
		Vector3(0.0, 0.83, -0.05),
		45,
		1.5,
		str(card_data.get("edition", "")) == "KNIGHT"
	)
	if is_instance_valid(rig):
		for _i in range(step_count):
			rig._process(0.03)
		rig.set_process(false)

	return pan


func _make_power_cell(parent_grid: GridContainer, title_txt: String, card_id: String, border_col: Color, target_t: float) -> void:
	var pan := _make_cell_frame(title_txt, border_col)
	parent_grid.add_child(pan)
	var vb: VBoxContainer = pan.get_child(0) as VBoxContainer

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

	var cam := Camera3D.new()
	cam.fov = 54.0
	vp.add_child(cam)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(overlay)

	var vfx := PowerVfxScript.new()
	vp.add_child(vfx)
	vfx.setup_fpv_preview(cam, overlay, false, card_id)
	vfx.set("_with_stinger", false)
	var steps := int(round(target_t / 0.04))
	for _i in range(steps):
		vfx._process(0.04)
	vfx.set_playing(false)
	overlay.queue_redraw()


func _make_cell_frame(title_txt: String, border_col: Color) -> PanelContainer:
	var pan := PanelContainer.new()
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.065, 0.052, 1.0)
	sb.border_color = Color(border_col.r, border_col.g, border_col.b, 0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	pan.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pan.add_child(vb)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.72))
	vb.add_child(lbl)
	return pan


func _build_knight_shield_strip(vp: SubViewport) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.065, 0.048, 0.038, 1.0)
	vp.add_child(bg)

	var margin := VBoxContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 20; margin.offset_right = -20
	margin.offset_top = 14; margin.offset_bottom = -14
	margin.add_theme_constant_override("separation", 12)
	vp.add_child(margin)

	var hdr := Label.new()
	hdr.text = "LIALO — KRESLENÉ SRDCE A ZLATÝ 3-DÍLNÝ RYTÍŘSKÝ ŠTÍT (0/3 -> 1/3 -> 2/3 -> 3/3 = +1 CELÝ ŠTÍT)"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	margin.add_child(hdr)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var disp_font := load("res://assets/fonts/LialoDisplay.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoDisplay.ttf") else ThemeDB.fallback_font
	var states := [
		{"title": "STAV 0/3 (Základní štít)", "hp": 10, "max": 10, "sh": 0, "chg": 0, "pulse": false, "col": Color(0.72, 0.64, 0.48)},
		{"title": "1× KNIGHT KARTA (1/3)", "hp": 10, "max": 10, "sh": 0, "chg": 1, "pulse": true, "col": Color(0.95, 0.78, 0.34)},
		{"title": "2× KNIGHT KARTA (2/3)", "hp": 9, "max": 10, "sh": 0, "chg": 2, "pulse": true, "col": Color(1.0, 0.84, 0.36)},
		{"title": "3× KNIGHT -> +1 CELÝ ŠTÍT!", "hp": 9, "max": 10, "sh": 1, "chg": 0, "pulse": true, "col": Color(1.0, 0.92, 0.52)},
	]

	for st in states:
		var pan := PanelContainer.new()
		pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pan.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.075, 0.06, 1.0)
		sb.border_color = st["col"]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(10)
		pan.add_theme_stylebox_override("panel", sb)
		row.add_child(pan)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		pan.add_child(vb)

		var lbl := Label.new()
		lbl.text = str(st["title"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", st["col"])
		vb.add_child(lbl)

		var holder := Control.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(holder)

		var hw := HeartbeatHpScript.new()
		hw.position = Vector2(18, 22)
		hw.scale = Vector2(1.75, 1.75)
		holder.add_child(hw)
		hw.setup(disp_font, false, false)
		hw.set_hp_with_status(int(st["hp"]), int(st["max"]), int(st["sh"]), "", false, int(st["chg"]))
		if bool(st["pulse"]):
			hw.trigger_shield_charge_pulse(int(st["chg"]), int(st["sh"]) > 0)


func _on_frame() -> void:
	_frames += 1
	if not _spawned and _frames >= 2:
		_spawned = true
		_spawn_all_vfx_tiles()
		return
	if _done or _frames < 30:
		return
	_done = true
	var vfx_img := get_root().get_texture().get_image()
	if vfx_img != null and not vfx_img.is_empty():
		var err1 := vfx_img.save_png(OUT_VFX_PATH)
		print("CAPTURED 2.5D VFX SHEET: %s (err=%d, %dx%d)" % [OUT_VFX_PATH, err1, vfx_img.get_width(), vfx_img.get_height()])
	else:
		printerr("FAILED: VFX viewport image empty")

	var sh_img := _shield_vp.get_texture().get_image()
	if sh_img != null and not sh_img.is_empty():
		var err2 := sh_img.save_png(OUT_SHIELD_PATH)
		print("CAPTURED KNIGHT SHIELD STRIP: %s (err=%d, %dx%d)" % [OUT_SHIELD_PATH, err2, sh_img.get_width(), sh_img.get_height()])
	else:
		printerr("FAILED: Shield viewport image empty")
	quit(0)
