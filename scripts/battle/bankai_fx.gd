class_name BankaiFx
extends CanvasLayer
## Bleach-style "Bankai" Awakening Cut-In & Persistent Duel Aura for LIALO.
## Shared by both Campaign (BattleTable3D) and Multiplayer (MpBattleTable3D).

const Catalog := preload("res://scripts/lialo_catalog.gd")
const Toon := preload("res://scripts/toon_style.gd")

var _root: Control
var _canvas: Control
var _aura_active: bool = false
var _aura_col: Color = Color(0.32, 0.88, 1.0)
var _cutin_t: float = 0.0
var _cutin_dur: float = 2.25
var _cutin_playing: bool = false
var _title_txt: String = "GRAND SEAL"
var _sub_txt: String = ""
var _caster_txt: String = ""
var _combo_textures: Array[Texture2D] = []
var _sparks: Array[Dictionary] = []
var _time_acc: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sfx_player: AudioStreamPlayer
var _sfx_bankai: AudioStream
var _font_disp: Font
var _font_body: Font


func _ready() -> void:
	layer = 18
	_rng.randomize()
	_font_disp = load("res://assets/fonts/LialoDisplay.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoDisplay.ttf") else ThemeDB.fallback_font
	_font_body = load("res://assets/fonts/LialoUI.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoUI.ttf") else ThemeDB.fallback_font

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_fx)
	_root.add_child(_canvas)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -3.0
	add_child(_sfx_player)
	_sfx_bankai = _load_bankai_stinger()


func _load_bankai_stinger() -> AudioStream:
	# Use rich studio impact SFX instead of simple procedural sine-wave tones
	for p in ["res://assets/audio/sfx_anim_sword_cleave.mp3", "res://assets/audio/sfx_card_ace_strike.mp3"]:
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
		if FileAccess.file_exists(p):
			return AudioStreamMP3.load_from_buffer(FileAccess.get_file_as_bytes(p))
	return null


func trigger_grand_seal(build_id: String, caster_name: String, combo_keys: Array, lang: String = "en", persist_aura: bool = true) -> void:
	trigger_bankai(build_id, caster_name, combo_keys, lang, persist_aura)


func trigger_bankai(build_id: String, caster_name: String, combo_keys: Array, lang: String = "en", persist_aura: bool = true) -> void:
	var b := Catalog.get_deck_build_loc(build_id, lang)
	_aura_col = b.get("col", Color(0.32, 0.88, 1.0))
	_title_txt = str(b.get("bankai_name", "GRAND SEAL AWAKENING"))
	_sub_txt = str(b.get("bankai_desc", ""))
	_caster_txt = caster_name
	_aura_active = persist_aura
	_cutin_t = 0.0
	_cutin_playing = true

	_combo_textures.clear()
	for ck in combo_keys:
		var path := "res://assets/cards/%s.png" % str(ck)
		var t := Toon.tex(path)
		if t != null:
			_combo_textures.append(t)

	_sparks.clear()
	var vs := _canvas.get_viewport_rect().size if is_instance_valid(_canvas) else Vector2(1366, 768)
	for _i in range(72):
		var ang := _rng.randf_range(0.0, TAU)
		var spd := _rng.randf_range(160.0, 740.0)
		_sparks.append({
			"pos": vs * 0.5 + Vector2(_rng.randf_range(-120.0, 120.0), _rng.randf_range(-40.0, 40.0)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": _rng.randf_range(0.55, 1.8),
			"max_life": 1.8,
			"sz": _rng.randf_range(2.5, 7.5),
		})

	if is_instance_valid(_sfx_player) and _sfx_bankai != null and DisplayServer.get_name() != "headless":
		_sfx_player.stream = _sfx_bankai
		_sfx_player.play()
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func clear_aura() -> void:
	_aura_active = false
	_cutin_playing = false
	_sparks.clear()
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func is_cutin_playing() -> bool:
	return _cutin_playing


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time_acc += dt
	if not _cutin_playing and not _aura_active and _sparks.is_empty():
		return
	if _cutin_playing:
		_cutin_t += dt
		if _cutin_t >= _cutin_dur:
			_cutin_playing = false
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[i]
		sp["life"] = float(sp["life"]) - dt
		if float(sp["life"]) <= 0.0:
			_sparks.remove_at(i)
			continue
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * dt
		sp["vel"] = (sp["vel"] as Vector2) * (1.0 - minf(0.95, dt * 1.9)) + Vector2(0.0, -70.0 * dt)
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _draw_fx() -> void:
	var vs := _canvas.get_viewport_rect().size
	if vs.x < 10.0 or vs.y < 10.0:
		return
	var cx := vs.x * 0.5
	var cy := vs.y * 0.5

	# 1. Persistent Awakened Spiritual-Pressure Border Aura (while Bankai is active)
	if _aura_active:
		var pulse := 0.35 + 0.25 * sin(_time_acc * 4.5)
		var edge_c := Color(_aura_col.r, _aura_col.g, _aura_col.b, pulse * 0.45)
		for gi in range(4):
			var w := 6.0 + float(gi) * 6.0
			var a := edge_c.a * (1.0 - float(gi) * 0.22)
			_canvas.draw_rect(Rect2(w * 0.5, w * 0.5, vs.x - w, vs.y - w), Color(_aura_col.r, _aura_col.g, _aura_col.b, a), false, 3.0)

	# 2. Full-Screen Bleach Bankai Cut-In Animation
	if _cutin_playing:
		var u := clampf(_cutin_t / _cutin_dur, 0.0, 1.0)
		var env := 1.0
		if u < 0.12:
			env = u / 0.12
		elif u > 0.78:
			env = 1.0 - (u - 0.78) / 0.22
		env = clampf(env, 0.0, 1.0)

		# Dramatic ink shroud darkening screen
		_canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.015, 0.025, 0.74 * env))

		# Expanding spiritual pressure shockwaves from center
		var r1 := 60.0 + u * vs.x * 0.68
		var r2 := 20.0 + maxf(0.0, u - 0.12) * vs.x * 0.55
		_canvas.draw_arc(Vector2(cx, cy), r1, 0.0, TAU, 96, Color(_aura_col.r, _aura_col.g, _aura_col.b, (1.0 - u) * 0.85), 5.0)
		_canvas.draw_arc(Vector2(cx, cy), r2, 0.0, TAU, 96, Color(1.0, 0.94, 0.72, (1.0 - u) * 0.65), 3.0)

		# Diagonal anime cut-in slash band across center
		var band_h := 178.0 * env
		var skew := 54.0
		var band_pts := PackedVector2Array([
			Vector2(-40.0, cy - band_h * 0.5 + skew),
			Vector2(vs.x + 40.0, cy - band_h * 0.5 - skew),
			Vector2(vs.x + 40.0, cy + band_h * 0.5 - skew),
			Vector2(-40.0, cy + band_h * 0.5 + skew),
		])
		_canvas.draw_colored_polygon(band_pts, Color(0.05, 0.035, 0.045, 0.96 * env))
		# Radiant energy speed-lines inside the slash band
		for li in range(14):
			var ly := cy - band_h * 0.44 + float(li) * (band_h * 0.88 / 13.0)
			var offset_x := fmod(_time_acc * 920.0 + float(li) * 173.0, vs.x + 400.0) - 200.0
			_canvas.draw_line(
				Vector2(offset_x - 160.0, ly + 12.0),
				Vector2(offset_x + 220.0, ly - 12.0),
				Color(_aura_col.r, _aura_col.g, _aura_col.b, 0.28 * env), 2.5
			)
		# Crisp luminous top & bottom katana edges
		_canvas.draw_line(band_pts[0], band_pts[1], Color(_aura_col.r, _aura_col.g, _aura_col.b, 0.96 * env), 4.5)
		_canvas.draw_line(band_pts[3], band_pts[2], Color(1.0, 0.90, 0.48, 0.92 * env), 4.0)

		# 4-Card Combo Seal Fan behind text
		var nc := _combo_textures.size()
		for ci in range(nc):
			var frac := (float(ci) - float(nc - 1) * 0.5)
			var c_pos := Vector2(cx + frac * 78.0, cy - 118.0 + absf(frac) * 10.0)
			var tex := _combo_textures[ci]
			var tsz := tex.get_size()
			var sc := 0.20 * env
			_canvas.draw_set_transform(c_pos, frac * 0.14, Vector2(sc, sc))
			_canvas.draw_texture(tex, -tsz * 0.5, Color(1.0, 1.0, 1.0, 0.92 * env))
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Calligraphic Caster Tag + GRAND SEAL Headline + Buff Subtitle
		var slide_x := (1.0 - minf(1.0, u / 0.18)) * 90.0
		var header_txt := ("%s — 4-CARD GRAND SEAL" % _caster_txt.to_upper()) if _caster_txt != "" else "4-CARD GRAND SEAL"
		_canvas.draw_string(_font_disp, Vector2(40.0 + slide_x, cy - 42.0), header_txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x - 80.0, 18, Color(1.0, 0.92, 0.58, env))
		_canvas.draw_string_outline(_font_disp, Vector2(40.0 - slide_x, cy + 16.0), _title_txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x - 80.0, 48, 12, Color(0.02, 0.01, 0.02, env))
		_canvas.draw_string(_font_disp, Vector2(40.0 - slide_x, cy + 16.0), _title_txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x - 80.0, 48, _aura_col.lightened(0.32) * Color(1, 1, 1, env))
		if _sub_txt != "":
			_canvas.draw_string(_font_body, Vector2(80.0, cy + 56.0), _sub_txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x - 160.0, 19, Color(0.96, 0.92, 0.84, env))

	# 3. Bursting Reiatsu Sparks
	for sp in _sparks:
		var a := clampf(float(sp["life"]) / maxf(0.01, float(sp["max_life"])), 0.0, 1.0)
		var p: Vector2 = sp["pos"]
		var v: Vector2 = sp["vel"]
		var dir := v.normalized() if v.length_squared() > 1.0 else Vector2.UP
		_canvas.draw_line(p, p - dir * (float(sp["sz"]) * 3.2), Color(_aura_col.r, _aura_col.g, _aura_col.b, a * 0.92), float(sp["sz"]) * 0.65)
		_canvas.draw_circle(p, float(sp["sz"]) * 0.55 * a, Color(1.0, 0.96, 0.82, a))
