extends SceneTree

const Toon = preload("res://scripts/toon_style.gd")
const PowerVfxScript = preload("res://scripts/battle/power_card_vfx_showcase.gd")

const OUT_SHEET := "C:/Users/lostv/.gemini/antigravity/brain/bbdbfa05-ae04-40d3-887b-1696a0626a58/power_25d_p2b_contact_sheet.png"

const P2B_CARDS := [
	"SPEC_MIDAS",
	"SPEC_CHRONOS",
	"SPEC_ORACLE",
	"SPEC_JESTER",
	"SPEC_HEX",
	"SPEC_MAGNET",
	"SPEC_SHIELD",
	"SPEC_GAMBLER",
	"SPEC_PLAGUE",
	"SPEC_CROWN",
]

var _frames := 0
var _done := false


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	create_timer(60.0).timeout.connect(func():
		printerr("TIMEOUT in verify_power_25d_p2b.gd")
		quit(124)
	)
	if DisplayServer.get_name() == "headless":
		process_frame.connect(_on_headless_frame, CONNECT_ONE_SHOT)
		return
	_build_gpu_contact_sheet()
	process_frame.connect(_on_gpu_frame)


func _on_headless_frame() -> void:
	_run_headless_checks()


func _run_headless_checks() -> void:
	print("=== VERIFY POWER 2.5D P2B (ALL 15 CARDS) ===")
	var root := get_root()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.56, 1.24), Vector3(0.0, 1.06, -0.25), Vector3.UP)
	for cid in PowerVfxScript.CARD_META.keys():
		var fx: Node3D = PowerVfxScript.new()
		root.add_child(fx)
		fx.setup_battle_fx(Vector3(0.0, 0.82, 0.0), Vector3(0.0, 1.15, -1.16), cid, false, cam)
		for t_step in [0.0, 0.85, 1.56, 2.08, 2.95, 3.60, 4.20]:
			fx.set("_t", t_step)
			fx.call("_apply_animation_state", t_step)

		if cid in P2B_CARDS:
			var hero_mat = fx.get("_hero_25d_mat")
			if not (hero_mat is ShaderMaterial):
				printerr("FAIL: Missing _hero_25d_mat for ", cid)
				quit(1)
				return
			if hero_mat.get_shader_parameter("albedo_tex") == null:
				printerr("FAIL: Null albedo_tex on hero for ", cid)
				quit(1)
				return
			for em in fx.get("_extra_25d_mats"):
				var fmat = em.get("front", null)
				if not (fmat is ShaderMaterial) or fmat.get_shader_parameter("albedo_tex") == null:
					printerr("FAIL: Null extra 25D texture for ", cid)
					quit(1)
					return
			var rig_root: Node3D = fx.get("_hybrid_stage_root") if cid != "SPEC_CHRONOS" else fx.get("_fx_root")
			if not is_instance_valid(rig_root):
				printerr("FAIL: Missing rig root for ", cid)
				quit(1)
				return
			if not _assert_no_primitive_heroes(rig_root, fx, cid):
				quit(1)
				return
		print("  OK: ", cid)
		root.remove_child(fx)
		fx.free()
	print("ALL 15 POWER CARDS VERIFIED (ZERO PRIMITIVE HEROES, ZERO NULL TEXTURES)")
	quit(0)


func _assert_no_primitive_heroes(node: Node, fx: Node, cid: String) -> bool:
	if node == fx.get("_hero_card") or node == fx.get("_rune_seal_root"):
		return true
	if node is MeshInstance3D:
		var m = (node as MeshInstance3D).mesh
		if m is SphereMesh or m is PrismMesh or m is CylinderMesh:
			printerr("FAIL: Primitive mesh found in P2B rig for ", cid, ": ", m.get_class())
			return false
		if m is BoxMesh and (m as BoxMesh).size.z >= 0.01:
			printerr("FAIL: Primitive BoxMesh found in P2B rig for ", cid)
			return false
	for ch in node.get_children():
		if not _assert_no_primitive_heroes(ch, fx, cid):
			return false
	return true


func _build_gpu_contact_sheet() -> void:
	var root := get_root()
	root.size = Vector2i(1920, 900)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.040, 0.032, 1.0)
	root.add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 14; outer.offset_right = -14
	outer.offset_top = 10; outer.offset_bottom = -10
	outer.add_theme_constant_override("separation", 8)
	root.add_child(outer)

	var hdr := Label.new()
	hdr.text = "LIALO v0.197c — PRIORITA #2B: LIVING 2.5D WOODCUT POWER CARDS (ALL 10 UPGRADED)"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.46))
	outer.add_child(hdr)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	outer.add_child(grid)

	for cid in P2B_CARDS:
		var meta: Dictionary = PowerVfxScript.CARD_META[cid]
		var col: Color = meta["accent"]
		var pan := PanelContainer.new()
		pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pan.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.06, 0.05, 1.0)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		pan.add_theme_stylebox_override("panel", sb)
		grid.add_child(pan)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		pan.add_child(vb)

		var lbl := Label.new()
		lbl.text = "%s — %s" % [cid, str(meta["title"])]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", col)
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

		var world := Node3D.new()
		vp.add_child(world)

		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.06, 0.045, 0.038, 1.0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.65, 0.54, 0.44)
		env.ambient_light_energy = 0.80
		we.environment = env
		world.add_child(we)

		var key := DirectionalLight3D.new()
		key.light_color = Color(1.0, 0.90, 0.74)
		key.light_energy = 1.65
		key.rotation_degrees = Vector3(-44.0, 32.0, 0.0)
		world.add_child(key)

		var wood_mat := Toon.pbr(Color(0.32, 0.20, 0.12), "res://assets/table/wood.png", 0.65, 0.05, Vector2(2.4, 2.4))
		var tbl := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.35; cyl.bottom_radius = 1.30; cyl.height = 0.08; cyl.radial_segments = 40
		tbl.mesh = cyl; tbl.position = Vector3(0.0, 0.78, 0.0); tbl.material_override = wood_mat
		world.add_child(tbl)

		var cam := Camera3D.new()
		cam.fov = 48.0
		world.add_child(cam)
		cam.look_at_from_position(Vector3(0.0, 1.56, 1.24), Vector3(0.0, 1.06, -0.25), Vector3.UP)

		var fx: Node3D = PowerVfxScript.new()
		world.add_child(fx)
		fx.setup_battle_fx(Vector3(0.0, 0.82, 0.0), Vector3(0.0, 1.15, -1.16), cid, false, cam)
		fx.set("_playing", false)
		fx.set("_t", 2.08)
		fx.call("_apply_animation_state", 2.08)


func _on_gpu_frame() -> void:
	_frames += 1
	if _done or _frames < 8:
		return
	_done = true
	var img := get_root().get_texture().get_image()
	img.save_png(OUT_SHEET)
	print("Saved GPU contact sheet -> ", OUT_SHEET)
	quit(0)
