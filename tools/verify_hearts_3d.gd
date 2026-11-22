extends SceneTree

const HeartbeatHpDisplayScript = preload("res://scripts/heartbeat_hp_display.gd")
const SHADER_PATH := "res://shaders/heart_2d_living.gdshader"
const TEX_PATHS := [
	"res://assets/ui/heart_2d_player.png",
	"res://assets/ui/heart_2d_boss.png",
	"res://assets/ui/heart_2d_cracks.png",
]

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _find_class_node(node: Node, cls_name: String) -> Node:
	if node.get_class() == cls_name:
		return node
	for ch in node.get_children():
		var found := _find_class_node(ch, cls_name)
		if found != null:
			return found
	return null


func _load_tex_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var loaded := ResourceLoader.load(res_path) as Texture2D
		if loaded != null:
			return loaded
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var img := Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	print("=== VERIFY 2D ILLUMINATED HEARTS HP SYSTEM START ===")

	# 1. Verify HeartbeatHpDisplay script & 2D living shader load cleanly
	var res := ResourceLoader.load("res://scripts/heartbeat_hp_display.gd")
	if res == null or (res is GDScript and not (res as GDScript).can_instantiate()):
		_fail("Failed to load/compile res://scripts/heartbeat_hp_display.gd")
	else:
		print("OK script: res://scripts/heartbeat_hp_display.gd")

	var sh_res := ResourceLoader.load(SHADER_PATH)
	if not (sh_res is Shader):
		_fail("Missing or invalid 2D heart shader: %s" % SHADER_PATH)
	else:
		var sh_code := (sh_res as Shader).code
		if not (sh_code.contains("crimson_mask") and sh_code.contains("ash_stone") and sh_code.contains("hp_ratio")):
			_fail("2D heart shader missing progressive hp_ratio red-drain logic (crimson_mask / ash_stone)")
		else:
			print("OK shader: %s (progressive red-color drain verified)" % SHADER_PATH)

	# 2. Verify high-detail 2D medieval heart textures & crack mask
	for tp in TEX_PATHS:
		var tex := _load_tex_safe(tp)
		if tex == null:
			_fail("Failed to load 2D heart asset: %s" % tp)
		else:
			var tsz := tex.get_size()
			if tsz.x < 256.0 or tsz.y < 256.0:
				_fail("2D heart asset too small (%s): %s" % [str(tsz), tp])
			else:
				print("OK 2D heart art %s (%dx%d)" % [tp.get_file(), int(tsz.x), int(tsz.y)])

	# 3. Test HeartbeatHpDisplay across Player, Rival, and Boss modes
	var modes := [
		{"name": "Player", "is_rival": false, "is_boss": false, "expected_size": Vector2(148.0, 148.0)},
		{"name": "Rival",  "is_rival": true,  "is_boss": false, "expected_size": Vector2(148.0, 148.0)},
		{"name": "Boss",   "is_rival": true,  "is_boss": true,  "expected_size": Vector2(180.0, 180.0)},
	]

	for m_cfg in modes:
		var m_name: String = m_cfg["name"]
		var widget := HeartbeatHpDisplayScript.new()
		root.add_child(widget)
		widget.setup(ThemeDB.fallback_font, bool(m_cfg["is_rival"]), false)
		if bool(m_cfg["is_boss"]):
			widget.set_boss_mode(true, Color(1.0, 0.72, 0.24))

		# Must be pure 2D TextureRect with ZERO SubViewport
		if _find_class_node(widget, "SubViewport") != null:
			_fail("[%s] Unexpected SubViewport in 2D Heart display" % m_name)
		if widget.get_heart_instance() != null:
			_fail("[%s] Expected get_heart_instance() == null in pure 2D Heart display" % m_name)
		var tr_mat: ShaderMaterial = null
		var sprite_inst: Variant = widget.get_heart_texture_rect()
		if not (sprite_inst is TextureRect):
			_fail("[%s] get_heart_texture_rect() must return TextureRect, got %s" % [m_name, str(sprite_inst)])
		else:
			var tr := sprite_inst as TextureRect
			if tr.texture == null:
				_fail("[%s] HeartSprite2D TextureRect has null texture" % m_name)
			if not (tr.material is ShaderMaterial):
				_fail("[%s] HeartSprite2D missing ShaderMaterial" % m_name)
			else:
				tr_mat = tr.material as ShaderMaterial

		var exp_sz: Vector2 = m_cfg["expected_size"]
		if widget.size != exp_sz:
			_fail("[%s] Expected frame size %s, got %s" % [m_name, str(exp_sz), str(widget.size)])
		if widget.is_boss_mode() != bool(m_cfg["is_boss"]):
			_fail("[%s] is_boss_mode() mismatch" % m_name)

		# 100% HP (10 / 10)
		widget.set_hp(10, 10, false)
		var bpm_100: float = widget.get_current_bpm()
		var crack_100: float = widget.get_crack_emission_energy()
		var ratio_100: float = float(tr_mat.get_shader_parameter("hp_ratio")) if tr_mat else -1.0

		# 50% HP (5 / 10)
		widget.set_hp(5, 10, true)
		var bpm_50: float = widget.get_current_bpm()
		var crack_50: float = widget.get_crack_emission_energy()
		var ratio_50: float = float(tr_mat.get_shader_parameter("hp_ratio")) if tr_mat else -1.0

		# 20% HP (2 / 10)
		widget.set_hp(2, 10, true)
		var bpm_20: float = widget.get_current_bpm()
		var crack_20: float = widget.get_crack_emission_energy()
		var ratio_20: float = float(tr_mat.get_shader_parameter("hp_ratio")) if tr_mat else -1.0

		# 0% HP (0 / 10)
		var depleted_fired := [false]
		widget.hp_depleted.connect(func(_r, _b): depleted_fired[0] = true)
		widget.set_hp(0, 10, true)
		var bpm_0: float = widget.get_current_bpm()
		var crack_0: float = widget.get_crack_emission_energy()
		var ratio_0: float = float(tr_mat.get_shader_parameter("hp_ratio")) if tr_mat else -1.0

		if not (ratio_100 > 0.99 and absf(ratio_50 - 0.5) < 0.02 and absf(ratio_20 - 0.2) < 0.02 and is_zero_approx(ratio_0)):
			_fail("[%s] Shader hp_ratio uniform did not track HP monotonically: %.2f -> %.2f -> %.2f -> %.2f" % [m_name, ratio_100, ratio_50, ratio_20, ratio_0])

		print("  [%s Mode] BPM: 100%%=%.1f -> 50%%=%.1f -> 20%%=%.1f -> 0%%=%.1f | CrackGlow: %.2f -> %.2f -> %.2f -> %.2f" % [
			m_name, bpm_100, bpm_50, bpm_20, bpm_0, crack_100, crack_50, crack_20, crack_0
		])

		if not (bpm_100 > 55.0 and bpm_50 > bpm_100 and bpm_20 > bpm_50 and is_zero_approx(bpm_0)):
			_fail("[%s] BPM progression invalid: 100%%=%.1f, 50%%=%.1f, 20%%=%.1f, 0%%=%.1f" % [m_name, bpm_100, bpm_50, bpm_20, bpm_0])
		if not (crack_100 > 0.05 and crack_50 > crack_100 and crack_20 > crack_50 and is_zero_approx(crack_0)):
			_fail("[%s] CrackVeins emission progression invalid: %.2f -> %.2f -> %.2f -> %.2f" % [m_name, crack_100, crack_50, crack_20, crack_0])
		if not depleted_fired[0]:
			_fail("[%s] hp_depleted signal did not fire when reaching 0 HP" % m_name)

		# Test heal pulse, damage pulse, shield readout, and status tag readout
		widget.set_hp_with_status(8, 10, 2, "🔥1", true)
		widget.trigger_damage_pulse(1)
		widget.trigger_heal_pulse(3)
		widget._process(0.05)
		var hp_txt: String = widget.get_hp_text()
		if not (hp_txt.contains("8 / 10") and hp_txt.contains("🛡2") and hp_txt.contains("🔥1")):
			_fail("[%s] Expected HP text with shield & status, got '%s'" % [m_name, hp_txt])

		widget.queue_free()

	if _failures.is_empty():
		print("=== VERIFY 2D ILLUMINATED HEARTS HP SYSTEM: ALL CHECKS PASSED ===")
		quit(0)
	else:
		printerr("=== VERIFY 2D ILLUMINATED HEARTS HP SYSTEM FAILED (%d errors) ===" % _failures.size())
		quit(1)
