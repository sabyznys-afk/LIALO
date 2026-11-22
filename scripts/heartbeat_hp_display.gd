class_name HeartbeatHpDisplay
extends Control

## High-Detail 2D Illuminated Medieval Heartbeat HP HUD Widget for LIALO.
## Renders a 10x more detailed 2D engraved crimson/boss heart emblem animated via
## heart_2d_living.gdshader (lub-dub expansion, sweeping specular glaze, glowing fracture veins),
## delicate floating vitality motes, gilded filigree framing, and crisp HP/Shield plaques.

signal heartbeat_pulsed(bpm: float, hp_ratio: float, is_boss: bool)
signal hp_depleted(is_rival: bool, is_boss: bool)

const HEART_2D_SHADER := preload("res://shaders/heart_2d_living.gdshader")
const PATH_HEART_PLAYER_PNG := "res://assets/ui/heart_2d_player.png"
const PATH_HEART_BOSS_PNG := "res://assets/ui/heart_2d_boss.png"
const PATH_HEART_CRACKS_PNG := "res://assets/ui/heart_2d_cracks.png"
const PATH_PILL_3D_PNG := "res://assets/ui/blender/ui_status_pill_3d.png"

const SIZE_STANDARD := Vector2(148.0, 148.0)
const SIZE_BOSS := Vector2(180.0, 180.0)

var _disp_font: Font
var _is_rival: bool = false
var _is_boss: bool = false
var _boss_accent_col: Color = Color(1.0, 0.72, 0.24)

var _cur_hp: int = 10
var _max_hp: int = 10
var _shields: int = 0
var _status_tag: String = ""
var _has_initialized_hp: bool = false

var _current_bpm: float = 63.0
var _target_speed_scale: float = 1.05
var _crack_emit_energy: float = 0.16

# 2D Illuminated Emblem Hierarchy
var _heart_tex_player: Texture2D
var _heart_tex_boss: Texture2D
var _crack_tex: Texture2D
var _pill_tex_3d: Texture2D
var _heart_rect: TextureRect
var _heart_mat: ShaderMaterial

# 2D Diegetic Overlay (Crown Plaque + Lower Crest HP Readout + Hit Flash)
var _crown_plaque: PanelContainer
var _crown_lbl: Label
var _hp_plaque: PanelContainer
var _hp_lbl: Label
var _flash_overlay: ColorRect

# Runtime animation / pulse / mote particle state
var _time_acc: float = 0.0
var _beat_phase: float = 0.0
var _shake_intensity: float = 0.0
var _damage_flash: float = 0.0
var _heal_swell: float = 0.0
var _motes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _heart_rect == null:
		setup(_disp_font, _is_rival, _is_boss)


func setup(display_font: Font, is_rival: bool = false, is_boss: bool = false) -> void:
	_disp_font = display_font if display_font != null else ThemeDB.fallback_font
	_is_rival = is_rival
	_is_boss = is_boss

	_load_2d_textures()
	if _heart_rect == null:
		_build_2d_heart_visuals()
		_build_2d_overlay()

	_apply_frame_metrics()
	_sync_heart_texture_and_shader()
	_recompute_heartbeat_state()
	_refresh_labels()
	queue_redraw()


func set_boss_mode(is_boss: bool, accent_col: Color = Color(1.0, 0.72, 0.24)) -> void:
	_is_boss = is_boss
	_boss_accent_col = accent_col
	if _heart_rect == null:
		setup(_disp_font, _is_rival, _is_boss)
		return
	_apply_frame_metrics()
	_sync_heart_texture_and_shader()
	_recompute_heartbeat_state()
	_refresh_labels()
	queue_redraw()


func set_hp(cur_hp: int, max_hp: int, animate_change: bool = true) -> void:
	var clean_max := maxi(1, max_hp)
	var clean_cur := clampi(cur_hp, 0, clean_max)
	var prev_hp := _cur_hp
	var was_init := _has_initialized_hp

	_cur_hp = clean_cur
	_max_hp = clean_max
	_has_initialized_hp = true

	if _heart_rect == null:
		setup(_disp_font, _is_rival, _is_boss)

	_recompute_heartbeat_state()
	_refresh_labels()

	if animate_change and was_init:
		if clean_cur < prev_hp:
			trigger_damage_pulse(prev_hp - clean_cur)
		elif clean_cur > prev_hp:
			trigger_heal_pulse(clean_cur - prev_hp)

	if clean_cur == 0 and prev_hp > 0 and was_init:
		emit_signal("hp_depleted", _is_rival, _is_boss)
	queue_redraw()


func set_shields(shield_count: int) -> void:
	_shields = maxi(0, shield_count)
	_refresh_labels()
	queue_redraw()


func set_status_tag(status_text: String) -> void:
	_status_tag = status_text.strip_edges()
	_refresh_labels()


func set_hp_with_status(cur_hp: int, max_hp: int, shields: int = 0, status_text: String = "", animate_change: bool = true) -> void:
	_shields = maxi(0, shields)
	_status_tag = status_text.strip_edges()
	set_hp(cur_hp, max_hp, animate_change)


func trigger_damage_pulse(dmg: int = 1) -> void:
	if _heart_rect == null:
		setup(_disp_font, _is_rival, _is_boss)
	var strength := clampf(0.65 + float(maxi(1, dmg)) * 0.22, 0.65, 1.55)
	_shake_intensity = maxf(_shake_intensity, 6.5 * strength)
	_damage_flash = maxf(_damage_flash, minf(1.0, 0.85 * strength))
	_spawn_burst_motes(8, Color(1.0, 0.24, 0.18))
	_sync_shader_uniforms()
	queue_redraw()


func trigger_heal_pulse(amt: int = 1) -> void:
	if _heart_rect == null:
		setup(_disp_font, _is_rival, _is_boss)
	var strength := clampf(0.60 + float(maxi(1, amt)) * 0.20, 0.60, 1.45)
	_heal_swell = maxf(_heal_swell, minf(1.0, 0.88 * strength))
	_spawn_burst_motes(8, Color(1.0, 0.84, 0.36))
	_sync_shader_uniforms()
	queue_redraw()


func get_current_bpm() -> float:
	return _current_bpm


func get_speed_scale() -> float:
	return _target_speed_scale


func get_hp_ratio() -> float:
	return clampf(float(_cur_hp) / float(maxi(1, _max_hp)), 0.0, 1.0)


func get_crack_emission_energy() -> float:
	return _crack_emit_energy


func is_boss_mode() -> bool:
	return _is_boss


func get_hp_text() -> String:
	return _hp_lbl.text if is_instance_valid(_hp_lbl) else "%d / %d" % [_cur_hp, _max_hp]


func get_heart_instance() -> Node3D:
	return null


func get_animation_player() -> AnimationPlayer:
	return null


func get_heart_texture_rect() -> TextureRect:
	return _heart_rect


# =============================================================================
# 2D ILLUMINATED SPRITE LOADING & SHADER CONSTRUCTION
# =============================================================================
func _load_png_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res := ResourceLoader.load(res_path)
		if res is Texture2D:
			return res as Texture2D
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var img := Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _load_2d_textures() -> void:
	if _heart_tex_player == null:
		_heart_tex_player = _load_png_tex(PATH_HEART_PLAYER_PNG)
	if _heart_tex_boss == null:
		_heart_tex_boss = _load_png_tex(PATH_HEART_BOSS_PNG)
	if _crack_tex == null:
		_crack_tex = _load_png_tex(PATH_HEART_CRACKS_PNG)
	if _pill_tex_3d == null:
		_pill_tex_3d = _load_png_tex(PATH_PILL_3D_PNG)


func _build_2d_heart_visuals() -> void:
	_heart_mat = ShaderMaterial.new()
	_heart_mat.shader = HEART_2D_SHADER
	if _crack_tex != null:
		_heart_mat.set_shader_parameter("crack_tex", _crack_tex)

	_heart_rect = TextureRect.new()
	_heart_rect.name = "HeartSprite2D"
	_heart_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_heart_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heart_rect.material = _heart_mat
	add_child(_heart_rect)


func _sync_heart_texture_and_shader() -> void:
	if not is_instance_valid(_heart_rect):
		return
	var target_tex := _heart_tex_boss if (_is_boss and _heart_tex_boss != null) else _heart_tex_player
	_heart_rect.texture = target_tex
	if _heart_mat:
		_heart_mat.set_shader_parameter("accent_col", _boss_accent_col if _is_boss else (Color(0.96, 0.34, 0.28) if _is_rival else Color(1.0, 0.78, 0.30)))
		if _crack_tex != null:
			_heart_mat.set_shader_parameter("crack_tex", _crack_tex)


func _build_2d_overlay() -> void:
	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "PulseFlashOverlay"
	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color(1.0, 0.18, 0.22, 0.0)
	add_child(_flash_overlay)

	_crown_plaque = PanelContainer.new()
	_crown_plaque.name = "BossCrownPlaque"
	_crown_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown_plaque.visible = _is_boss
	add_child(_crown_plaque)

	_crown_lbl = Label.new()
	_crown_lbl.name = "BossCrownLabel"
	_crown_lbl.text = "👑 BOSS"
	_crown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crown_lbl.add_theme_font_override("font", _disp_font)
	_crown_lbl.add_theme_font_size_override("font_size", 11)
	_crown_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	_crown_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.015, 0.02))
	_crown_lbl.add_theme_constant_override("outline_size", 4)
	_crown_plaque.add_child(_crown_lbl)

	_hp_plaque = PanelContainer.new()
	_hp_plaque.name = "HpCrestPlaque"
	_hp_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_plaque)

	_hp_lbl = Label.new()
	_hp_lbl.name = "HpValueLabel"
	_hp_lbl.text = "10 / 10"
	_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_lbl.add_theme_font_override("font", _disp_font)
	_hp_lbl.add_theme_font_size_override("font_size", 14)
	_hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.84))
	_hp_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.02))
	_hp_lbl.add_theme_constant_override("outline_size", 5)
	_hp_plaque.add_child(_hp_lbl)


func _apply_frame_metrics() -> void:
	var target_sz := SIZE_BOSS if _is_boss else SIZE_STANDARD
	custom_minimum_size = target_sz
	size = target_sz

	if is_instance_valid(_heart_rect):
		var pad_x := 4.0 if not _is_boss else 2.0
		var pad_top := 14.0 if _is_boss else 0.0
		var sprite_w := target_sz.x - pad_x * 2.0
		var sprite_h := target_sz.y - (28.0 if _is_boss else 20.0)
		_heart_rect.position = Vector2(pad_x, pad_top)
		_heart_rect.size = Vector2(sprite_w, sprite_h)
		_heart_rect.pivot_offset = Vector2(sprite_w * 0.5, sprite_h * 0.48)

	if is_instance_valid(_crown_plaque):
		_crown_plaque.visible = _is_boss
		if _pill_tex_3d != null:
			var cr_tex_sb := StyleBoxTexture.new()
			cr_tex_sb.texture = _pill_tex_3d
			cr_tex_sb.modulate_color = Color(1.12, 0.92, 0.70)
			cr_tex_sb.content_margin_left = 8
			cr_tex_sb.content_margin_right = 8
			cr_tex_sb.content_margin_top = 1
			cr_tex_sb.content_margin_bottom = 1
			_crown_plaque.add_theme_stylebox_override("panel", cr_tex_sb)
		else:
			var cr_sb := StyleBoxFlat.new()
			cr_sb.bg_color = Color(0.11, 0.025, 0.035, 0.94)
			cr_sb.border_color = _boss_accent_col
			cr_sb.set_border_width_all(1)
			cr_sb.set_corner_radius_all(8)
			cr_sb.content_margin_left = 7
			cr_sb.content_margin_right = 7
			cr_sb.content_margin_top = 1
			cr_sb.content_margin_bottom = 1
			_crown_plaque.add_theme_stylebox_override("panel", cr_sb)
		var cr_w := 76.0
		var cr_h := 18.0
		_crown_plaque.position = Vector2((target_sz.x - cr_w) * 0.5, 0.0)
		_crown_plaque.size = Vector2(cr_w, cr_h)
		if is_instance_valid(_crown_lbl):
			_crown_lbl.add_theme_color_override("font_color", _boss_accent_col.lerp(Color(1.0, 0.95, 0.72), 0.35))

	if is_instance_valid(_hp_plaque):
		if _pill_tex_3d != null:
			var hp_tex_sb := StyleBoxTexture.new()
			hp_tex_sb.texture = _pill_tex_3d
			hp_tex_sb.modulate_color = Color(1.08, 0.96, 0.78) if _is_boss else (Color(1.08, 0.80, 0.78) if _is_rival else Color(1.02, 0.98, 0.92))
			hp_tex_sb.content_margin_left = 10
			hp_tex_sb.content_margin_right = 10
			hp_tex_sb.content_margin_top = 2
			hp_tex_sb.content_margin_bottom = 2
			_hp_plaque.add_theme_stylebox_override("panel", hp_tex_sb)
		else:
			var hp_sb := StyleBoxFlat.new()
			hp_sb.bg_color = Color(0.08, 0.022, 0.028, 0.95) if not _is_boss else Color(0.10, 0.018, 0.026, 0.96)
			var border_col := _boss_accent_col if _is_boss else (Color(0.90, 0.62, 0.26, 0.94) if not _is_rival else Color(0.90, 0.38, 0.36, 0.94))
			hp_sb.border_color = border_col
			hp_sb.set_border_width_all(2 if _is_boss else 1)
			hp_sb.set_corner_radius_all(11)
			hp_sb.content_margin_left = 8
			hp_sb.content_margin_right = 8
			hp_sb.content_margin_top = 1
			hp_sb.content_margin_bottom = 1
			_hp_plaque.add_theme_stylebox_override("panel", hp_sb)

		var plaque_w := 118.0 if _is_boss else 96.0
		var plaque_h := 25.0 if _is_boss else 23.0
		_hp_plaque.position = Vector2((target_sz.x - plaque_w) * 0.5, target_sz.y - plaque_h)
		_hp_plaque.size = Vector2(plaque_w, plaque_h)
		if is_instance_valid(_hp_lbl):
			_hp_lbl.add_theme_font_size_override("font_size", 16 if _is_boss else 15)


# =============================================================================
# DYNAMIC HP-DRIVEN BPM, CRACK VEINS GLOW & LIVING 2D SHADER UNIFORMS
# =============================================================================
func _recompute_heartbeat_state() -> void:
	var ratio := get_hp_ratio()
	if _cur_hp <= 0 or ratio <= 0.0:
		_current_bpm = 0.0
		_target_speed_scale = 0.0
		_crack_emit_energy = 0.0
	elif ratio >= 0.75:
		var t := clampf((1.0 - ratio) / 0.25, 0.0, 1.0)
		_current_bpm = lerpf(63.0, 68.0, t)
		_target_speed_scale = _current_bpm / 60.0
		_crack_emit_energy = lerpf(0.18, 0.38, t) * (1.25 if _is_boss else 1.0)
	elif ratio >= 0.40:
		var t := clampf((0.75 - ratio) / 0.35, 0.0, 1.0)
		_current_bpm = lerpf(86.0, 103.0, t)
		_target_speed_scale = _current_bpm / 60.0
		_crack_emit_energy = lerpf(0.82, 1.48, t) * (1.30 if _is_boss else 1.0)
	else:
		var t := clampf((0.40 - ratio) / 0.39, 0.0, 1.0)
		_current_bpm = lerpf(152.0, 175.0, t)
		_target_speed_scale = _current_bpm / 60.0
		_crack_emit_energy = lerpf(2.15, 3.25, t) * (1.35 if _is_boss else 1.0)

	_sync_shader_uniforms()


func _sync_shader_uniforms() -> void:
	if _heart_mat == null:
		return
	var ratio := get_hp_ratio()
	var is_dead_f := 1.0 if (_cur_hp <= 0 or ratio <= 0.0) else 0.0
	_heart_mat.set_shader_parameter("beat_phase", _beat_phase)
	_heart_mat.set_shader_parameter("beat_amp", (0.055 if _is_boss else 0.042) * (1.0 + (1.0 - ratio) * 0.45))
	_heart_mat.set_shader_parameter("hp_ratio", ratio)
	_heart_mat.set_shader_parameter("crack_energy", _crack_emit_energy)
	_heart_mat.set_shader_parameter("damage_flash", _damage_flash)
	_heart_mat.set_shader_parameter("heal_flash", _heal_swell)
	_heart_mat.set_shader_parameter("is_dead", is_dead_f)
	_heart_mat.set_shader_parameter("time_sec", _time_acc)


func _spawn_burst_motes(count: int, col: Color) -> void:
	var sz := size if size.x > 4.0 else (SIZE_BOSS if _is_boss else SIZE_STANDARD)
	var center := Vector2(sz.x * 0.5, sz.y * 0.46)
	for _i in range(count):
		var a := randf_range(0.0, TAU)
		_motes.append({
			"pos": center + Vector2(cos(a), sin(a)) * randf_range(8.0, 22.0),
			"vel": Vector2(cos(a) * randf_range(16.0, 38.0), sin(a) * randf_range(12.0, 30.0) - 18.0),
			"t": 0.0,
			"max_t": randf_range(0.35, 0.65),
			"r": randf_range(1.6, 3.2),
			"col": col,
		})


func _refresh_labels() -> void:
	if not is_instance_valid(_hp_lbl):
		return
	var txt := "%d / %d" % [_cur_hp, _max_hp]
	if _shields > 0:
		txt += " 🛡%d" % _shields
	if not _status_tag.is_empty():
		txt += " " + _status_tag
	_hp_lbl.text = txt

	var ratio := get_hp_ratio()
	var col := Color(1.0, 0.94, 0.84)
	if _cur_hp <= 0:
		col = Color(0.56, 0.52, 0.52)
	elif ratio < 0.40:
		col = Color(1.0, 0.44, 0.42)
	elif ratio < 0.75:
		col = Color(1.0, 0.78, 0.46)
	elif _is_boss:
		col = Color(1.0, 0.90, 0.58)
	_hp_lbl.add_theme_color_override("font_color", col)


func _process(delta: float) -> void:
	_time_acc += delta
	var prev_phase := _beat_phase
	if _current_bpm > 0.0:
		_beat_phase += delta * (_current_bpm / 60.0) * TAU
		if floori(_beat_phase / TAU) > floori(prev_phase / TAU):
			emit_signal("heartbeat_pulsed", _current_bpm, get_hp_ratio(), _is_boss)

	if _damage_flash > 0.001:
		_damage_flash = maxf(0.0, _damage_flash - delta * 2.8)
	if _heal_swell > 0.001:
		_heal_swell = maxf(0.0, _heal_swell - delta * 2.1)
	if _shake_intensity > 0.01:
		_shake_intensity = maxf(0.0, _shake_intensity - delta * 22.0)

	# Ambient rising crimson/gold vitality motes
	var ratio := get_hp_ratio()
	if _cur_hp > 0 and _motes.size() < 7 and randf() < delta * (3.2 + (1.0 - ratio) * 4.5):
		var sz := size if size.x > 4.0 else (SIZE_BOSS if _is_boss else SIZE_STANDARD)
		var healthy_m := Color(1.0, 0.80, 0.34) if _is_boss else Color(0.98, 0.28, 0.24)
		var m_col := Color(0.56, 0.54, 0.58).lerp(healthy_m, clampf(ratio, 0.08, 1.0))
		_motes.append({
			"pos": Vector2(sz.x * 0.5 + randf_range(-20.0, 20.0), sz.y * 0.56 + randf_range(-6.0, 8.0)),
			"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-26.0, -14.0)),
			"t": 0.0,
			"max_t": randf_range(0.65, 1.15),
			"r": randf_range(1.2, 2.2),
			"col": m_col,
		})
	if not _motes.is_empty():
		var alive_m: Array[Dictionary] = []
		for m in _motes:
			var nt := float(m["t"]) + delta
			if nt < float(m["max_t"]):
				m["t"] = nt
				m["pos"] = (m["pos"] as Vector2) + (m["vel"] as Vector2) * delta
				alive_m.append(m)
		_motes = alive_m

	# Subtle 2D heartbeat tremor + scale thump on sprite
	var danger_tremor := lerpf(0.8, 2.4, (0.40 - ratio) / 0.40) if (_cur_hp > 0 and ratio < 0.40) else 0.0
	var total_shake := _shake_intensity + danger_tremor
	if is_instance_valid(_heart_rect):
		var lub := maxf(0.0, sin(_beat_phase))
		var dub := maxf(0.0, sin(_beat_phase * 2.0 - 0.85)) * 0.62
		var sc_pulse := 1.0 + (lub + dub) * (0.045 if _is_boss else 0.036) + _heal_swell * 0.08 - _damage_flash * 0.05 if _cur_hp > 0 else 0.94
		_heart_rect.scale = Vector2(sc_pulse, sc_pulse)
		var base_x := 2.0 if _is_boss else 4.0
		var base_y := 14.0 if _is_boss else 0.0
		if total_shake > 0.02:
			_heart_rect.position = Vector2(base_x + sin(_time_acc * 51.0) * total_shake * 0.65, base_y + cos(_time_acc * 63.0) * total_shake * 0.65)
		else:
			_heart_rect.position = Vector2(base_x, base_y)

	if is_instance_valid(_flash_overlay):
		if _damage_flash > 0.01:
			_flash_overlay.color = Color(1.0, 0.14, 0.18, _damage_flash * 0.18)
		elif _heal_swell > 0.01:
			_flash_overlay.color = Color(1.0, 0.82, 0.34, _heal_swell * 0.14)
		else:
			_flash_overlay.color = Color(0.0, 0.0, 0.0, 0.0)

	_sync_shader_uniforms()
	if _current_bpm > 0.0 or not _motes.is_empty() or _damage_flash > 0.0 or _heal_swell > 0.0:
		queue_redraw()


func _draw() -> void:
	# Bare, standalone 2D Illuminated Heart (NO circular medallion or outer rings around it!).
	var sz := size if size.x > 4.0 else (SIZE_BOSS if _is_boss else SIZE_STANDARD)
	var center := Vector2(sz.x * 0.5, sz.y * 0.45)
	var base_rad := minf(sz.x, sz.y) * (0.44 if _is_boss else 0.42)
	var ratio := get_hp_ratio()

	# Crisp 2D Vector Fallback Heart if PNG not imported yet
	if _heart_rect == null or _heart_rect.texture == null:
		var hs := base_rad * 0.72
		var poly := PackedVector2Array([
			center + Vector2(0.0, hs * 0.88),
			center + Vector2(-hs * 0.94, hs * 0.05),
			center + Vector2(-hs * 0.64, -hs * 0.66),
			center + Vector2(0.0, -hs * 0.22),
			center + Vector2(hs * 0.64, -hs * 0.66),
			center + Vector2(hs * 0.94, hs * 0.05),
		])
		draw_colored_polygon(poly, Color(0.28, 0.26, 0.28).lerp(Color(0.75, 0.08, 0.14), ratio) if _cur_hp > 0 else Color(0.24, 0.22, 0.22))

	# Delicate rising vitality / ember motes (draining crimson -> ash as HP drops)
	for m in _motes:
		var lf := 1.0 - clampf(float(m["t"]) / maxf(0.01, float(m["max_t"])), 0.0, 1.0)
		var mc: Color = m["col"]
		var mp: Vector2 = m["pos"]
		var mr: float = float(m["r"])
		draw_circle(mp, mr * 1.6, Color(mc.r, mc.g, mc.b, lf * 0.24))
		draw_circle(mp, mr, Color(1.0, 0.96, 0.82, lf * 0.86))
