class_name HandwritingQuill
extends Control

## Medieval Goose-Quill Handwriting Animator for LIALO.
## Draws kerning-faithful settled ink glyphs alongside wet-ink progressive letter
## crystallization, carriage-return nib arcs, drifting ink sparks, punctuation pauses,
## and an animated vector goose-quill feather tracking exact cursor coordinates.

signal quill_stroke_sfx(pitch: float)

var _font: Font
var _font_size: int = 24
var _full_text: String = ""
var _alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
var _ink_color: Color = Color(0.92, 0.99, 1.0, 1.0)
var _wet_ink_color: Color = Color(0.48, 0.96, 1.0, 1.0)
var _shadow_color: Color = Color(0.02, 0.04, 0.08, 0.72)
var _feather_color: Color = Color(0.98, 0.94, 0.82, 1.0)
var _feather_trim: Color = Color(0.45, 0.92, 1.0, 0.85)

var _lines: Array[Dictionary] = []
var _char_map: Array[Dictionary] = []
var _layout_width: float = 540.0
var _line_height: float = 32.0
var _total_height: float = 40.0

var _active: bool = false
var _finishing: bool = false
var _finish_t: float = 0.0
var _chars_f: float = 0.0
var _cur_i: int = 0
var _cps: float = 42.0
var _pace_mult: float = 1.0
var _pause_timer: float = 0.0
var _with_sfx: bool = true
var _sfx_cd: float = 0.0
var _time_acc: float = 0.0

var _nib_pos: Vector2 = Vector2.ZERO
var _last_line_idx: int = -1
var _hop_t: float = 1.0
var _hop_start: Vector2 = Vector2.ZERO
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func():
		if absf(size.x - _layout_width) > 2.0 and size.x > 40.0:
			_layout_width = size.x
			_rebuild_layout()
			queue_redraw()
	)


func setup(
	font_ref: Font,
	font_sz: int = 24,
	ink_col: Color = Color(0.92, 0.99, 1.0, 1.0),
	wet_col: Color = Color(0.48, 0.96, 1.0, 1.0),
	feather_col: Color = Color(0.98, 0.94, 0.82, 1.0),
	feather_accent: Color = Color(0.45, 0.92, 1.0, 0.85)
) -> void:
	_font = font_ref if font_ref != null else ThemeDB.fallback_font
	_font_size = maxi(14, font_sz)
	_ink_color = ink_col
	_wet_ink_color = wet_col
	_feather_color = feather_col
	_feather_trim = feather_accent
	_rebuild_layout()


func set_wrap_width(w: float) -> void:
	_layout_width = maxf(160.0, w)
	_rebuild_layout()


func get_preferred_height(for_width: float = -1.0) -> float:
	if for_width > 40.0 and absf(for_width - _layout_width) > 2.0:
		_layout_width = for_width
		_rebuild_layout()
	return maxf(34.0, _total_height)


func start_text(txt: String, cps: float = 42.0, pace_mode: String = "relaxed", with_sfx: bool = true) -> void:
	_full_text = txt
	_with_sfx = with_sfx
	_pace_mult = 0.78 if pace_mode == "relaxed" else (1.08 if pace_mode == "normal" else 1.72)
	_cps = maxf(18.0, cps * _pace_mult)
	if size.x > 40.0:
		_layout_width = size.x
	_rebuild_layout()

	_sparks.clear()
	_pause_timer = 0.0
	_sfx_cd = 0.0
	_last_line_idx = 0
	_hop_t = 1.0

	if _char_map.is_empty():
		_active = false
		_finishing = false
		_cur_i = 0
		_chars_f = 0.0
		queue_redraw()
		return

	_chars_f = 0.0
	_cur_i = 0
	_active = true
	_finishing = false
	_finish_t = 0.0
	var first_entry: Dictionary = _char_map[0]
	_nib_pos = Vector2(float(first_entry["cx"]), float(first_entry["baseline_y"]))
	_hop_start = _nib_pos
	queue_redraw()


func finish_immediately() -> void:
	_chars_f = float(_char_map.size())
	_cur_i = _char_map.size()
	_active = false
	_finishing = false
	_finish_t = 0.0
	_pause_timer = 0.0
	_sparks.clear()
	queue_redraw()


func is_busy() -> bool:
	return _active


func get_visible_char_count() -> int:
	if _active:
		return clampi(_cur_i, 0, _full_text.length())
	return -1


func step_anim(delta: float) -> void:
	_time_acc += delta

	# Step ink sparks regardless of completion
	if not _sparks.is_empty():
		var next_sparks: Array[Dictionary] = []
		for sp in _sparks:
			var t_val: float = float(sp["t"]) + delta
			if t_val < float(sp["max_t"]):
				sp["t"] = t_val
				next_sparks.append(sp)
		_sparks = next_sparks

	if _finishing:
		_finish_t += delta
		if _finish_t >= 0.34:
			_finishing = false
		queue_redraw()
		return

	if not _active:
		if not _sparks.is_empty():
			queue_redraw()
		return

	_sfx_cd = maxf(0.0, _sfx_cd - delta)
	if _hop_t < 1.0:
		_hop_t = minf(1.0, _hop_t + delta / 0.14)

	if _pause_timer > 0.0:
		_pause_timer = maxf(0.0, _pause_timer - delta)
		queue_redraw()
		return

	var n_total := _char_map.size()
	if _cur_i >= n_total:
		_active = false
		_finishing = true
		_finish_t = 0.0
		queue_redraw()
		return

	# Modulate writing speed naturally: spaces are light lifts, mid-word is crisp & flowing
	var speed_factor := 1.12
	var cur_ch := str(_char_map[_cur_i]["ch"])
	if cur_ch == " ":
		speed_factor = 0.85

	var prev_i := _cur_i
	_chars_f = minf(float(n_total), _chars_f + delta * _cps * speed_factor)
	_cur_i = clampi(int(floor(_chars_f)), 0, n_total)

	if _cur_i > prev_i:
		for ci in range(prev_i, _cur_i):
			if ci >= n_total:
				break
			var entry: Dictionary = _char_map[ci]
			var ch := str(entry["ch"])
			var l_idx := int(entry["line"])
			if _last_line_idx >= 0 and l_idx != _last_line_idx:
				_hop_start = _nib_pos
				_hop_t = 0.0
			_last_line_idx = l_idx

			var target_pos := Vector2(float(entry["cx"]) + float(entry["w"]) * 0.5, float(entry["baseline_y"]))
			if _hop_t >= 1.0:
				_nib_pos = _nib_pos.lerp(target_pos, 0.72)

			if ch != " ":
				if _with_sfx and _sfx_cd <= 0.0:
					_sfx_cd = clampf(0.088 / maxf(0.75, _pace_mult * 0.75), 0.055, 0.115)
					emit_signal("quill_stroke_sfx", randf_range(0.92, 1.18))
				# Emit subtle ink spark droplet on fresh glyph
				if _sparks.size() < 12 and (ci % 2 == 0):
					_sparks.append({
						"pos": target_pos + Vector2(randf_range(-2.0, 2.0), -6.0),
						"vel": Vector2(randf_range(10.0, 26.0), randf_range(-28.0, -10.0)),
						"t": 0.0,
						"max_t": randf_range(0.22, 0.34),
						"r": randf_range(1.6, 2.8),
					})

			# Natural breathing pauses after punctuation (scaled gently so fast E2E stays brisk)
			if ch in [".", "!", "?"]:
				_pause_timer = 0.14 / maxf(0.8, _pace_mult)
				break
			elif ch in [",", ";", ":", "—"]:
				_pause_timer = 0.08 / maxf(0.8, _pace_mult)
				break

	# Smoothly track active fractional glyph position
	var active_idx := clampi(_cur_i, 0, maxi(0, n_total - 1))
	if n_total > 0:
		var act_e: Dictionary = _char_map[active_idx]
		var frac_in_ch := clampf(_chars_f - float(_cur_i), 0.0, 1.0)
		var g_x := float(act_e["cx"]) + float(act_e["w"]) * frac_in_ch
		var g_y := float(act_e["baseline_y"])
		var target := Vector2(g_x, g_y)
		if _hop_t < 1.0:
			var hopped := _hop_start.lerp(target, ease(_hop_t, 0.5))
			hopped.y -= sin(_hop_t * PI) * 22.0
			_nib_pos = hopped
		else:
			_nib_pos = _nib_pos.lerp(target, clampf(delta * 26.0, 0.25, 1.0))

	if _cur_i >= n_total:
		_active = false
		_finishing = true
		_finish_t = 0.0
	queue_redraw()


func _rebuild_layout() -> void:
	_lines.clear()
	_char_map.clear()
	if _font == null:
		_font = ThemeDB.fallback_font
	var w := maxf(160.0, _layout_width)
	var ascent := _font.get_ascent(_font_size)
	var descent := _font.get_descent(_font_size)
	_line_height = ceilf((ascent + descent) * 1.18)

	var wrapped_strs: Array[String] = []
	for para in _full_text.split("\n", true):
		if para == "":
			wrapped_strs.append("")
			continue
		var words := para.split(" ", false)
		var cur_line := ""
		for wd in words:
			var cand := wd if cur_line == "" else (cur_line + " " + wd)
			var cw := _font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
			if cur_line != "" and cw > w - 12.0:
				wrapped_strs.append(cur_line)
				cur_line = wd
			else:
				cur_line = cand
		if cur_line != "":
			wrapped_strs.append(cur_line)

	if wrapped_strs.is_empty():
		wrapped_strs.append("")

	var top_pad := 4.0
	var y_base := top_pad + ascent
	var g_idx := 0
	for li in range(wrapped_strs.size()):
		var ltxt: String = wrapped_strs[li]
		var lw := _font.get_string_size(ltxt, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var x0 := 4.0
		if _alignment == HORIZONTAL_ALIGNMENT_CENTER:
			x0 = maxf(4.0, (w - lw) * 0.5)
		elif _alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			x0 = maxf(4.0, w - lw - 4.0)

		var start_char_i := g_idx
		var prev_x := x0
		for ci in range(ltxt.length()):
			var prefix := ltxt.substr(0, ci + 1)
			var next_x := x0 + _font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
			var ch := ltxt.substr(ci, 1)
			_char_map.append({
				"ch": ch,
				"line": li,
				"col": ci,
				"cx": prev_x,
				"w": maxf(4.0, next_x - prev_x),
				"baseline_y": y_base,
			})
			prev_x = next_x
			g_idx += 1

		_lines.append({
			"text": ltxt,
			"x": x0,
			"baseline_y": y_base,
			"char_start": start_char_i,
			"char_end": g_idx,
		})
		y_base += _line_height

	_total_height = top_pad + float(wrapped_strs.size()) * _line_height + 4.0
	custom_minimum_size = Vector2(0.0, _total_height)


func _draw() -> void:
	if _font == null or _lines.is_empty():
		return

	var revealed := _char_map.size() if not _active else clampi(_cur_i, 0, _char_map.size())
	var trail_n := 4
	var settled_limit := _char_map.size() if not _active else maxi(0, revealed - trail_n)

	# 1. Render settled characters per line using native kerning
	for line in _lines:
		var c0 := int(line["char_start"])
		var c1 := int(line["char_end"])
		if settled_limit <= c0:
			continue
		var line_settled := mini(c1, settled_limit) - c0
		if line_settled <= 0:
			continue
		var sub_str := str(line["text"]).substr(0, line_settled)
		var lpos := Vector2(float(line["x"]), float(line["baseline_y"]))
		draw_string(_font, lpos + Vector2(1.5, 2.0), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _shadow_color)
		draw_string(_font, lpos, sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _ink_color)

	# 2. Render last ~4 freshly written characters with wet-ink highlight & gentle downstroke settle
	if _active and revealed > 0:
		var tail_start := settled_limit
		var tail_end := mini(_char_map.size(), revealed + 1)
		for ci in range(tail_start, tail_end):
			var ce: Dictionary = _char_map[ci]
			var ch := str(ce["ch"])
			if ch == " ":
				continue
			var age := clampf(_chars_f - float(ci), 0.0, float(trail_n))
			var norm := clampf(age / float(trail_n), 0.0, 1.0)
			var alpha_f := clampf(ease(minf(1.0, age * 1.45), 0.45), 0.0, 1.0)
			if alpha_f <= 0.02:
				continue
			var drop_y := (1.0 - minf(1.0, age * 1.8)) * -3.5
			var pos := Vector2(float(ce["cx"]), float(ce["baseline_y"]) + drop_y)
			var col := _wet_ink_color.lerp(_ink_color, norm)
			col.a *= alpha_f
			var sh_col := _shadow_color
			sh_col.a *= alpha_f
			draw_string(_font, pos + Vector2(1.5, 2.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, sh_col)
			draw_string(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, col)
			if age < 1.2:
				draw_circle(pos + Vector2(float(ce["w"]) * 0.45, -7.0), 7.5 * (1.2 - age), Color(_wet_ink_color.r, _wet_ink_color.g, _wet_ink_color.b, 0.24 * (1.2 - age)))

	# 3. Drifting ink sparks
	for sp in _sparks:
		var st_frac := clampf(float(sp["t"]) / maxf(0.01, float(sp["max_t"])), 0.0, 1.0)
		var p: Vector2 = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * float(sp["t"])
		var a := (1.0 - st_frac) * 0.85
		draw_circle(p, float(sp["r"]) * (1.0 - st_frac * 0.5), Color(_wet_ink_color.r, _wet_ink_color.g, _wet_ink_color.b, a))

	# 4. Illustrated Medieval Goose-Quill Pen tracking active cursor
	if _active or _finishing:
		var lift := Vector2.ZERO
		var q_alpha := 1.0
		var rot_extra := 0.0
		if _finishing:
			var fp := clampf(_finish_t / 0.34, 0.0, 1.0)
			var ef := ease(fp, 0.45)
			lift = Vector2(ef * 18.0, -ef * 24.0)
			rot_extra = -ef * 0.22
			q_alpha = 1.0 - ef
		elif _pause_timer > 0.0:
			lift = Vector2(2.0, -5.0)
		elif _hop_t >= 1.0:
			# Rapid subtle cursive stroke tremor while scratching ink onto page
			lift = Vector2(sin(_time_acc * 36.0) * 2.2, cos(_time_acc * 52.0) * 3.0)
			rot_extra = sin(_time_acc * 28.0) * 0.055

		if q_alpha > 0.02:
			_draw_goose_quill(_nib_pos + lift + Vector2(0.0, -2.0), rot_extra, q_alpha)


func _draw_goose_quill(nib: Vector2, tilt_rad: float, alpha: float) -> void:
	# Shaft vector rising up-right from nib (~-54 deg)
	var base_ang := -0.94 + tilt_rad
	var dir := Vector2(cos(base_ang), sin(base_ang))
	var perp := Vector2(-dir.y, dir.x)

	# Subtle warm drop shadow beneath quill nib
	draw_circle(nib + Vector2(3.0, 4.0), 4.5, Color(0.0, 0.0, 0.0, 0.32 * alpha))

	# Outer plume vane polygon (ivory/cream goose feather with upper notch cutouts)
	var p_tip := nib
	var p_collar := nib + dir * 13.0
	var p_mid1 := nib + dir * 27.0
	var p_notch_out := nib + dir * 32.0 + perp * 11.5
	var p_notch_in := nib + dir * 34.0 + perp * 4.5
	var p_top := nib + dir * 56.0 + perp * 1.5
	var vane_pts := PackedVector2Array([
		p_collar + perp * 2.2,
		p_mid1 + perp * 10.5,
		p_notch_out,
		p_notch_in,
		nib + dir * 38.0 + perp * 11.0,
		nib + dir * 49.0 + perp * 7.8,
		p_top,
		nib + dir * 46.0 - perp * 5.4,
		nib + dir * 28.0 - perp * 6.8,
		p_collar - perp * 2.0,
	])
	var fill_c := Color(_feather_color.r, _feather_color.g, _feather_color.b, alpha * 0.96)
	var trim_c := Color(_feather_trim.r, _feather_trim.g, _feather_trim.b, alpha * 0.88)
	draw_colored_polygon(vane_pts, fill_c)
	draw_polyline(vane_pts + PackedVector2Array([vane_pts[0]]), Color(0.14, 0.10, 0.06, 0.85 * alpha), 1.6)

	# Delicate inner feather barbs along upper vane
	for bi in range(1, 5):
		var u := 0.28 + float(bi) * 0.14
		var s0 := nib + dir * (56.0 * u)
		var s1 := s0 + dir * 5.0 + perp * (6.5 + float(bi % 2) * 2.5)
		draw_line(s0, s1, trim_c, 1.2)

	# Central rachis shaft & sharpened dark ink nib
	var shaft_top := nib + dir * 55.0
	draw_line(p_collar, shaft_top, Color(0.95, 0.88, 0.68, alpha), 2.3)
	var nib_poly := PackedVector2Array([
		p_tip,
		p_collar + perp * 3.0,
		p_collar - perp * 2.6,
	])
	draw_colored_polygon(nib_poly, Color(0.16, 0.14, 0.18, alpha))
	draw_line(p_tip, p_collar, Color(_wet_ink_color.r, _wet_ink_color.g, _wet_ink_color.b, 0.9 * alpha), 1.3)
	draw_circle(p_tip, 2.2, Color(_wet_ink_color.r, _wet_ink_color.g, _wet_ink_color.b, alpha))
