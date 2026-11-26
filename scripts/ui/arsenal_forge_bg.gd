class_name ArsenalForgeBg
extends Control

## Live Animated Forge Fire & Arcane Magic Background for LIALO Arsenal & Deck Builder.
## Features warm flickering forge flames along bottom edge & lower corners, rising sparks
## and smoke wisps, paired with slow counter-rotating arcane rune circles and spell motes.

var _time: float = 0.0
var _pulse: float = 0.0
var _pulse_col: Color = Color(0.42, 0.92, 1.0)
var _sparks: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 44091
	_init_particles()


func _init_particles() -> void:
	_sparks.clear()
	for i in range(36):
		_sparks.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"spd": _rng.randf_range(0.06, 0.16),
			"sz": _rng.randf_range(1.5, 3.8),
			"ph": _rng.randf_range(0.0, TAU),
			"hot": (i % 3 == 0),
		})
	_motes.clear()
	for j in range(28):
		_motes.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"spd": _rng.randf_range(0.025, 0.065),
			"sz": _rng.randf_range(1.8, 4.2),
			"ph": _rng.randf_range(0.0, TAU),
			"cyan": (j % 2 == 0),
		})


func trigger_magic_pulse(col: Color = Color(0.42, 0.92, 1.0)) -> void:
	_pulse = 1.0
	_pulse_col = col


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := minf(delta, 0.05)
	_time += dt
	if _pulse > 0.001:
		_pulse = maxf(0.0, _pulse - dt * 1.8)
	for sp in _sparks:
		var ny := float(sp["y"]) - float(sp["spd"]) * dt
		if ny < -0.05:
			ny = 1.04
			sp["x"] = _rng.randf()
		sp["y"] = ny
	for mt in _motes:
		var ny2 := float(mt["y"]) - float(mt["spd"]) * dt
		if ny2 < -0.04:
			ny2 = 1.04
			mt["x"] = _rng.randf()
		mt["y"] = ny2
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 16.0 or sz.y < 16.0:
		return

	# Deep dark-walnut forge base
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.028, 0.020, 0.017, 1.0))

	# Warm forge firelight glow rising from bottom furnace edge + corners
	var breath := 0.85 + 0.15 * sin(_time * 2.9)
	for gx_f in [0.16, 0.50, 0.84]:
		draw_circle(Vector2(sz.x * gx_f, sz.y * 1.04), sz.x * 0.34, Color(0.82, 0.24, 0.06, 0.12 * breath))
		draw_circle(Vector2(sz.x * gx_f, sz.y * 1.02), sz.x * 0.20, Color(1.0, 0.48, 0.12, 0.10 * breath))

	# Animated Arcane Runic Circles centered behind the forge panes
	var center := Vector2(sz.x * 0.5, sz.y * 0.46)
	var rad_outer := minf(sz.x, sz.y) * 0.38
	var rad_inner := rad_outer * 0.72
	var rune_alpha := 0.14 + _pulse * 0.22
	var rune_col := Color(0.34, 0.86, 1.0, rune_alpha).lerp(Color(_pulse_col.r, _pulse_col.g, _pulse_col.b, rune_alpha), _pulse)
	var gold_col := Color(0.96, 0.72, 0.26, 0.13 + _pulse * 0.16)

	draw_arc(center, rad_outer, 0.0, TAU, 72, gold_col, 2.0, true)
	draw_arc(center, rad_outer * 0.90, 0.0, TAU, 72, rune_col, 1.6, true)
	draw_arc(center, rad_inner, 0.0, TAU, 56, gold_col, 1.5, true)

	# Outer rotating spoke runes (+rotation) & inner rotating triangle glyphs (-rotation)
	for ti in range(18):
		var a := float(ti) * (TAU / 18.0) + _time * 0.14
		var p1 := center + Vector2(cos(a), sin(a)) * (rad_outer * 0.88)
		var p2 := center + Vector2(cos(a), sin(a)) * (rad_outer * 1.04)
		draw_line(p1, p2, rune_col if (ti % 2 == 0) else gold_col, 1.8, true)

	for tri in range(2):
		var base_a := _time * (-0.22 if tri == 0 else 0.19) + float(tri) * PI * 0.33
		var pts := PackedVector2Array()
		for vi in range(4):
			var va := base_a + float(vi % 3) * (TAU / 3.0)
			pts.append(center + Vector2(cos(va), sin(va)) * rad_inner)
		draw_polyline(pts, rune_col if tri == 0 else gold_col, 1.4, true)

	# Stylized Woodcut Forge Flames licking along the bottom edge & lower corners
	var flame_steps := 26
	for fi in range(flame_steps):
		var fx := (float(fi) + 0.5) / float(flame_steps) * sz.x
		var corner_boost := 1.0 + 0.65 * pow(absf((float(fi) / float(flame_steps - 1)) * 2.0 - 1.0), 2.0)
		var fh := (24.0 + 26.0 * absf(sin(_time * 4.2 + float(fi) * 1.37))) * corner_boost
		var sway := sin(_time * 5.8 + float(fi) * 1.1) * 10.0
		var fw := sz.x / float(flame_steps) * 0.72
		var poly_out := PackedVector2Array([
			Vector2(fx - fw, sz.y + 4.0),
			Vector2(fx + sway, sz.y - fh),
			Vector2(fx + fw, sz.y + 4.0),
		])
		draw_colored_polygon(poly_out, Color(0.88, 0.28, 0.06, 0.24))
		var poly_in := PackedVector2Array([
			Vector2(fx - fw * 0.52, sz.y + 4.0),
			Vector2(fx + sway * 0.6, sz.y - fh * 0.62),
			Vector2(fx + fw * 0.52, sz.y + 4.0),
		])
		draw_colored_polygon(poly_in, Color(1.0, 0.70, 0.18, 0.22))

	# Rising Forge Sparks
	for sp in _sparks:
		var sx := float(sp["x"]) * sz.x + sin(_time * 2.5 + float(sp["ph"])) * 20.0
		var sy := float(sp["y"]) * sz.y
		var sa := clampf(1.0 - (1.0 - float(sp["y"])) * 0.55, 0.15, 0.75) * (0.65 + 0.35 * sin(_time * 4.5 + float(sp["ph"])))
		var scol := Color(1.0, 0.80, 0.32, sa) if bool(sp["hot"]) else Color(0.98, 0.42, 0.14, sa)
		draw_circle(Vector2(sx, sy), float(sp["sz"]), scol)

	# Floating Azure & Gold Arcane Spell Motes
	for mt in _motes:
		var mx := float(mt["x"]) * sz.x + cos(_time * 1.6 + float(mt["ph"])) * 16.0
		var my := float(mt["y"]) * sz.y
		var ma := 0.22 + 0.18 * sin(_time * 3.1 + float(mt["ph"])) + _pulse * 0.15
		var mcol := Color(0.38, 0.90, 1.0, ma) if bool(mt["cyan"]) else Color(1.0, 0.84, 0.36, ma)
		draw_circle(Vector2(mx, my), float(mt["sz"]) * 1.6, Color(mcol.r, mcol.g, mcol.b, ma * 0.28))
		draw_circle(Vector2(mx, my), float(mt["sz"]) * 0.75, mcol)
