extends CanvasLayer
## LIALO Ouroboros Serpent Loading Screen (v2 — Hand-Drawn Woodcut 2D Edition)
## - Detailed woodcut/ink 2D serpent sprite ribbon (head closed/open, tiled scale body, barbed tail)
## - 4-phase choreography: Slither In -> Tightening Coil -> 2× Tail-Dodge Bite Lunges -> 3rd Clamp Ouroboros Seal
## - Drifting hand-drawn LIALO cards background with parallax & occasional ink/ember burn
## - Plays assets/audio/sfx_loading_snake.mp3 (<= 15 s) + synced procedural hiss/snap SFX
## - Click/key skip after 3.0 s; auto-finishes after choreography; skipped in headless/script runs.

signal finished

const Toon := preload("res://scripts/toon_style.gd")

const AUDIO_PATH := "res://assets/audio/sfx_loading_snake"
const HEAD_CLOSED_PATH := "res://assets/ui/ouroboros_head_closed.png"
const HEAD_OPEN_PATH := "res://assets/ui/ouroboros_head_open.png"
const BODY_STRIP_PATH := "res://assets/ui/ouroboros_body_strip.png"
const TAIL_PATH := "res://assets/ui/ouroboros_tail.png"

const MIN_SKIP_TIME := 3.0
const AUTO_END_TIME := 10.6
const AUDIO_MAX_SEC := 15.0

const SEGMENTS := 56
const SEG_SPACING := 10.5
const START_CIRCLE_R := 192.0
const SEAL_CIRCLE_R := 124.0

var volume_db: float = -4.0
var _t: float = 0.0
var _ending: bool = false
var _root: Control
var _canvas: Control
var _label: Label
var _sub_label: Label
var _player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sfx_hiss: AudioStreamWAV
var _sfx_snap: AudioStreamWAV
var _sfx_seal: AudioStreamWAV

# Textures
var _tex_head_closed: Texture2D
var _tex_head_open: Texture2D
var _tex_body: Texture2D
var _tex_tail: Texture2D
var _card_textures: Array[Texture2D] = []

# Serpent kinematic state
var _trail: PackedVector2Array = PackedVector2Array()
var _head_pos: Vector2 = Vector2.ZERO
var _head_dir: Vector2 = Vector2.RIGHT
var _phase: int = 0 # 0=SLITHER_IN, 1=COIL, 2=BITE_CHASE, 3=OUROBOROS_SEAL
var _phase_t: float = 0.0
var _circle_ang: float = PI * 0.85
var _circle_r: float = START_CIRCLE_R
var _jaw_open: float = 0.0
var _bite_count: int = 0
var _bite_lunge_t: float = 0.0
var _tail_dodge_offset: float = 0.0
var _seal_glow: float = 0.0
var _bite_flash: float = 0.0
var _bite_flash_pos: Vector2 = Vector2.ZERO

# Background drifting cards & ember/ink particles
var _bg_cards: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 90
	_rng.seed = 2026192

	_tex_head_closed = Toon.tex(HEAD_CLOSED_PATH)
	_tex_head_open = Toon.tex(HEAD_OPEN_PATH)
	_tex_body = Toon.tex(BODY_STRIP_PATH)
	_tex_tail = Toon.tex(TAIL_PATH)
	_load_bg_card_textures()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.036, 0.022, 0.022, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	_root.add_child(_canvas)

	_label = Label.new()
	_label.text = "LIALO"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_top = -98
	_label.offset_left = -260
	_label.offset_right = 260
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.48))
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	_label.add_theme_constant_override("outline_size", 5)
	_root.add_child(_label)

	_sub_label = Label.new()
	_sub_label.text = ""
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_label.offset_top = -62
	_sub_label.offset_left = -260
	_sub_label.offset_right = 260
	_sub_label.add_theme_font_size_override("font_size", 14)
	_sub_label.add_theme_color_override("font_color", Color(0.76, 0.62, 0.46, 0.85))
	_root.add_child(_sub_label)

	var vs := _vp_size()
	_head_pos = Vector2(-90.0, vs.y * 0.76)
	_head_dir = Vector2(0.86, -0.5).normalized()
	_trail.clear()
	for i in range(SEGMENTS * 4):
		_trail.append(_head_pos - _head_dir * (float(i) * 3.5))

	_init_bg_cards(vs)
	_build_procedural_sfx()

	_player = AudioStreamPlayer.new()
	_player.volume_db = volume_db
	add_child(_player)
	var st := _load_stream()
	if st:
		_player.stream = st
		_player.play()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = volume_db - 2.0
	add_child(_sfx_player)


func _load_bg_card_textures() -> void:
	var card_paths := [
		"res://assets/cards/CERVEN_E.png",
		"res://assets/cards/ZALUD_K.png",
		"res://assets/cards/ZELEN_H.png",
		"res://assets/cards/GULA_10.png",
		"res://assets/cards/CERVEN_7.png",
		"res://assets/cards/ZELEN_D.png",
		"res://assets/cards/ZALUD_8.png",
		"res://assets/cards/GULA_E.png",
		"res://assets/table/card_back.png",
	]
	for p in card_paths:
		var t := Toon.tex(p)
		if t != null:
			_card_textures.append(t)


func _init_bg_cards(vs: Vector2) -> void:
	_bg_cards.clear()
	if _card_textures.is_empty():
		return
	for i in range(18):
		var depth := _rng.randf_range(0.55, 1.15)
		_bg_cards.append({
			"tex_idx": i % _card_textures.size(),
			"pos": Vector2(_rng.randf_range(40.0, vs.x - 40.0), _rng.randf_range(40.0, vs.y - 40.0)),
			"vel": Vector2(_rng.randf_range(-18.0, 24.0), _rng.randf_range(-24.0, -9.0)) * depth,
			"rot": _rng.randf_range(-0.6, 0.6),
			"rot_spd": _rng.randf_range(-0.22, 0.22),
			"depth": depth,
			"flip_phase": _rng.randf_range(0.0, TAU),
			"burn": 0.0,
			"burn_cd": _rng.randf_range(2.2, 8.5),
		})


func _build_procedural_sfx() -> void:
	var sr := 22050
	# 1. Serpent Hiss (sibilant bandpass-like hiss)
	var n_h := int(sr * 0.42)
	var s_h := PackedFloat32Array()
	s_h.resize(n_h)
	var prev := 0.0
	for i in range(n_h):
		var t := float(i) / float(sr)
		var env := minf(1.0, t / 0.06) * exp(-t * 4.5)
		var wn := _rng.randf_range(-1.0, 1.0)
		var hp := wn - prev * 0.85
		prev = wn
		s_h[i] = hp * env * 0.28
	_sfx_hiss = _pcm16(s_h, sr)

	# 2. Fang Snap (sharp percussive jaw click + low thud)
	var n_s := int(sr * 0.24)
	var s_s := PackedFloat32Array()
	s_s.resize(n_s)
	for i in range(n_s):
		var t := float(i) / float(sr)
		var click := exp(-t * 45.0) * sin(TAU * (820.0 - t * 2400.0) * t)
		var thud := exp(-t * 18.0) * sin(TAU * 135.0 * t)
		var grit := exp(-t * 32.0) * _rng.randf_range(-0.35, 0.35)
		s_s[i] = clampf((click * 0.55 + thud * 0.48 + grit * 0.3), -1.0, 1.0) * 0.72
	_sfx_snap = _pcm16(s_s, sr)

	# 3. Ouroboros Seal Resonance (deep resonant arcane gong)
	var n_g := int(sr * 0.95)
	var s_g := PackedFloat32Array()
	s_g.resize(n_g)
	for i in range(n_g):
		var t := float(i) / float(sr)
		var env := minf(1.0, t / 0.015) * exp(-t * 2.4)
		var sig := sin(TAU * 110.0 * t) * 0.45 + sin(TAU * 164.81 * t) * 0.30 + sin(TAU * 220.0 * t) * 0.22 + sin(TAU * 440.0 * t) * 0.12
		s_g[i] = clampf(sig * env * 0.78, -1.0, 1.0)
	_sfx_seal = _pcm16(s_g, sr)


func _pcm16(samples: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	wav.data = bytes
	return wav


func _play_fx(st: AudioStreamWAV, pitch: float = 1.0) -> void:
	if is_instance_valid(_sfx_player) and st != null:
		_sfx_player.stream = st
		_sfx_player.pitch_scale = pitch
		_sfx_player.play()


func _load_stream() -> AudioStream:
	for ext in [".mp3", ".wav"]:
		var p: String = AUDIO_PATH + ext
		if ResourceLoader.exists(p):
			var s = load(p)
			if s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = false
			return s
		if ext == ".mp3" and FileAccess.file_exists(p):
			var mp3 := AudioStreamMP3.load_from_buffer(FileAccess.get_file_as_bytes(p))
			if mp3:
				mp3.loop = false
				return mp3
	return null


func _vp_size() -> Vector2:
	return _root.get_viewport_rect().size if _root else Vector2(1366, 768)


func _input(event: InputEvent) -> void:
	if _ending:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		if _t >= MIN_SKIP_TIME:
			_finish()


func _spawn_ember_burst(pos: Vector2, count: int, col: Color) -> void:
	for _i in range(count):
		var ang := _rng.randf_range(0.0, TAU)
		var spd := _rng.randf_range(35.0, 165.0)
		_sparks.append({
			"pos": pos + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": _rng.randf_range(0.35, 0.95),
			"max_life": 0.95,
			"sz": _rng.randf_range(2.0, 5.5),
			"col": col,
		})


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_t += dt
	_phase_t += dt
	_bite_flash = maxf(0.0, _bite_flash - dt * 2.6)
	_tail_dodge_offset = lerpf(_tail_dodge_offset, 0.0, 1.0 - exp(-5.0 * dt))

	if is_instance_valid(_player) and _player.playing and _player.get_playback_position() >= AUDIO_MAX_SEC:
		_player.stop()

	var vs := _vp_size()
	var center := vs * 0.5
	_step_bg_cards(dt, vs)
	_step_sparks(dt)
	_step_serpent(dt, center)

	var dots := int(_t * 2.2) % 4
	_label.text = "LIALO — OUROBOROS" if _phase == 3 else ("LOADING" + ".".repeat(dots))
	if _t >= MIN_SKIP_TIME:
		_sub_label.text = "Click or press any key to continue"
	else:
		_sub_label.text = ""

	_canvas.queue_redraw()
	if not _ending and _t >= AUTO_END_TIME:
		_finish()


func _step_bg_cards(dt: float, vs: Vector2) -> void:
	for c in _bg_cards:
		c["pos"] = (c["pos"] as Vector2) + (c["vel"] as Vector2) * dt
		c["rot"] = float(c["rot"]) + float(c["rot_spd"]) * dt
		c["flip_phase"] = float(c["flip_phase"]) + dt * 0.65
		var p: Vector2 = c["pos"]
		if p.y < -120.0:
			p.y = vs.y + 110.0
			p.x = _rng.randf_range(60.0, vs.x - 60.0)
			c["burn"] = 0.0
		if p.x < -120.0:
			p.x = vs.x + 110.0
		elif p.x > vs.x + 120.0:
			p.x = -110.0
		c["pos"] = p
		c["burn_cd"] = float(c["burn_cd"]) - dt
		if float(c["burn_cd"]) <= 0.0 and float(c["burn"]) <= 0.0:
			c["burn"] = 0.01
			_spawn_ember_burst(p, 8, Color(0.98, 0.36, 0.16, 0.9))
		if float(c["burn"]) > 0.0:
			c["burn"] = float(c["burn"]) + dt * 0.9
			if float(c["burn"]) >= 1.0:
				c["burn"] = 0.0
				c["burn_cd"] = _rng.randf_range(4.0, 10.0)
				c["pos"] = Vector2(_rng.randf_range(60.0, vs.x - 60.0), vs.y + 110.0)


func _step_sparks(dt: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[i]
		sp["life"] = float(sp["life"]) - dt
		if float(sp["life"]) <= 0.0:
			_sparks.remove_at(i)
			continue
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * dt
		sp["vel"] = (sp["vel"] as Vector2) * (1.0 - minf(0.95, dt * 2.5)) + Vector2(0.0, -18.0 * dt)


func _step_serpent(dt: float, center: Vector2) -> void:
	var prev_head := _head_pos
	match _phase:
		0: # SLITHER_IN from bottom-left to entry point of circle
			var entry := center + Vector2(cos(PI * 0.85), sin(PI * 0.85)) * START_CIRCLE_R
			var to_entry := entry - _head_pos
			var dist := to_entry.length()
			var spd := 315.0
			if dist < 24.0 or _phase_t >= 2.4:
				_phase = 1
				_phase_t = 0.0
				_circle_ang = atan2(_head_pos.y - center.y, _head_pos.x - center.x)
				_circle_r = _head_pos.distance_to(center)
				_play_fx(_sfx_hiss, 0.95)
			else:
				var d := to_entry / maxf(1.0, dist)
				var perp := Vector2(-d.y, d.x)
				_head_pos += d * spd * dt + perp * sin(_t * 8.5) * 145.0 * dt
			_jaw_open = 0.0

		1: # COIL: tighten orbit smoothly around center
			var target_r := lerpf(START_CIRCLE_R, SEAL_CIRCLE_R + 28.0, clampf(_phase_t / 2.6, 0.0, 1.0))
			_circle_r = lerpf(_circle_r, target_r, 1.0 - exp(-3.5 * dt))
			var ang_spd := lerpf(1.65, 2.55, clampf(_phase_t / 2.6, 0.0, 1.0))
			_circle_ang += ang_spd * dt
			var undul := sin(_t * 9.0) * 6.5
			_head_pos = center + Vector2(cos(_circle_ang), sin(_circle_ang)) * (_circle_r + undul)
			_jaw_open = 0.0
			if _phase_t >= 2.6:
				_phase = 2
				_phase_t = 0.0
				_bite_count = 0
				_bite_lunge_t = 0.0

		2: # BITE_CHASE: 2 lunges where tail dodges, 3rd clamps tail!
			_bite_lunge_t += dt
			var lunge_period := 1.02
			var local_u := fmod(_bite_lunge_t, lunge_period) / lunge_period
			var lunge_boost := 0.0
			if local_u > 0.58 and local_u < 0.88:
				_jaw_open = 1.0
				lunge_boost = 1.55
			else:
				_jaw_open = lerpf(_jaw_open, 0.0, 1.0 - exp(-12.0 * dt))

			var target_r := lerpf(SEAL_CIRCLE_R + 28.0, SEAL_CIRCLE_R, clampf(float(_bite_count) / 2.5, 0.0, 1.0))
			_circle_r = lerpf(_circle_r, target_r, 1.0 - exp(-4.5 * dt))
			_circle_ang += (2.55 + lunge_boost) * dt
			_head_pos = center + Vector2(cos(_circle_ang), sin(_circle_ang)) * _circle_r

			# Trigger snap event at peak of each lunge cycle
			var expected_bites := int(floor((_bite_lunge_t + 0.18) / lunge_period))
			if expected_bites > _bite_count:
				_bite_count = expected_bites
				_bite_flash = 1.0
				_bite_flash_pos = _head_pos
				if _bite_count < 3:
					_tail_dodge_offset = 24.0
					_play_fx(_sfx_snap, 1.05 + float(_bite_count) * 0.08)
					_spawn_ember_burst(_head_pos, 14, Color(1.0, 0.34, 0.18))
				else:
					# 3rd bite clamps the tail -> OUROBOROS SEAL!
					_phase = 3
					_phase_t = 0.0
					_jaw_open = 1.0
					_play_fx(_sfx_seal, 1.0)
					_spawn_ember_burst(_head_pos, 32, Color(1.0, 0.82, 0.34))

		3: # OUROBOROS_SEAL: Perfect closed glowing ring rotating majestically
			_circle_r = lerpf(_circle_r, SEAL_CIRCLE_R, 1.0 - exp(-6.0 * dt))
			_circle_ang += 0.95 * dt
			_head_pos = center + Vector2(cos(_circle_ang), sin(_circle_ang)) * _circle_r
			_jaw_open = 1.0
			_seal_glow = minf(1.0, _seal_glow + dt * 1.4)
			if _rng.randf() < 0.35:
				var ra := _rng.randf_range(0.0, TAU)
				_spawn_ember_burst(center + Vector2(cos(ra), sin(ra)) * _circle_r, 1, Color(1.0, 0.72, 0.24))

	var move_v := _head_pos - prev_head
	if move_v.length_squared() > 0.01:
		_head_dir = _head_dir.lerp(move_v.normalized(), 1.0 - exp(-18.0 * dt)).normalized()

	_trail.insert(0, _head_pos)
	var max_trail := SEGMENTS * 14
	if _trail.size() > max_trail:
		_trail.resize(max_trail)


func _sample_spine(center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if _phase == 3:
		# Smoothly blend spine onto exact closed Ouroboros circle so jaws grip the tail!
		var ring_len := TAU * _circle_r * 0.96
		for i in range(SEGMENTS):
			var u := float(i) / float(SEGMENTS - 1)
			var ang := _circle_ang - u * (ring_len / maxf(1.0, _circle_r))
			pts.append(center + Vector2(cos(ang), sin(ang)) * _circle_r)
		return pts

	pts.append(_trail[0])
	var acc := 0.0
	for i in range(1, _trail.size()):
		var a := _trail[i - 1]
		var b := _trail[i]
		var l := a.distance_to(b)
		acc += l
		while acc >= SEG_SPACING and pts.size() < SEGMENTS:
			acc -= SEG_SPACING
			var f := 1.0 - acc / maxf(l, 0.001)
			pts.append(a.lerp(b, clampf(f, 0.0, 1.0)))
		if pts.size() >= SEGMENTS:
			break

	# Apply whip-dodge deflection to the tail end when dodging the jaws
	if _tail_dodge_offset > 0.5 and pts.size() > 8:
		var n := pts.size()
		for i in range(n - 10, n):
			var w := float(i - (n - 10)) / 9.0
			var out_dir := (pts[i] - center).normalized()
			pts[i] += out_dir * (_tail_dodge_offset * w * w)
	return pts


func _seg_half_width(u: float) -> float:
	if u < 0.08:
		return lerpf(18.0, 21.0, u / 0.08)
	return lerpf(21.0, 4.5, pow((u - 0.08) / 0.92, 1.35))


func _draw_scene() -> void:
	var vs := _vp_size()
	var center := vs * 0.5

	# 1. Background vignette + drifting hand-drawn LIALO cards
	_draw_bg_cards()

	# 2. Ancient woodcut ritual rings behind serpent
	var ring_a := 0.22 + _seal_glow * 0.65
	var ring_col := Color(0.68, 0.20, 0.14, ring_a).lerp(Color(1.0, 0.78, 0.32, ring_a), _seal_glow)
	_canvas.draw_arc(center, _circle_r + 42.0, 0.0, TAU, 96, ring_col, 2.2)
	_canvas.draw_arc(center, _circle_r - 36.0, 0.0, TAU, 96, Color(ring_col.r, ring_col.g, ring_col.b, ring_a * 0.65), 1.5)
	# Rotating arcane tick notches on outer ring
	for ti in range(24):
		var a := float(ti) * (TAU / 24.0) + _t * (0.28 + _seal_glow * 0.6)
		var p1 := center + Vector2(cos(a), sin(a)) * (_circle_r + 36.0)
		var p2 := center + Vector2(cos(a), sin(a)) * (_circle_r + 48.0)
		_canvas.draw_line(p1, p2, ring_col, 1.8)

	if _seal_glow > 0.01:
		var shock_r := SEAL_CIRCLE_R + _seal_glow * 135.0
		_canvas.draw_arc(center, shock_r, 0.0, TAU, 96, Color(1.0, 0.76, 0.28, (1.0 - _seal_glow) * 0.85), 4.0)

	# 3. Articulated woodcut Ouroboros serpent body ribbon
	var pts := _sample_spine(center)
	var n := pts.size()
	if n < 3:
		return

	# Soft drop shadow underneath
	for i in range(n - 1):
		var u := float(i) / float(n - 1)
		var hw := _seg_half_width(u)
		_canvas.draw_line(pts[i] + Vector2(6, 9), pts[i + 1] + Vector2(6, 9), Color(0.0, 0.0, 0.0, 0.42), hw * 1.85)

	# Textured scaled body quads along spine (tail -> neck so front segments layer cleanly)
	var tangents: Array[Vector2] = []
	for i in range(n):
		var fwd := (pts[maxi(i - 1, 0)] - pts[mini(i + 1, n - 1)])
		tangents.append(fwd.normalized() if fwd.length_squared() > 0.0001 else Vector2.RIGHT)

	var left_pts := PackedVector2Array()
	var right_pts := PackedVector2Array()
	for i in range(n):
		var u := float(i) / float(n - 1)
		var hw := _seg_half_width(u)
		var side := Vector2(-tangents[i].y, tangents[i].x)
		left_pts.append(pts[i] - side * hw)
		right_pts.append(pts[i] + side * hw)

	if _tex_body != null:
		for i in range(n - 2, -1, -1):
			var u0 := fmod(float(i) * 0.16, 1.0)
			var u1 := u0 + 0.16
			if u1 > 1.0:
				u0 = 0.0
				u1 = 0.16
			var quad := PackedVector2Array([left_pts[i], right_pts[i], right_pts[i + 1], left_pts[i + 1]])
			var uvs := PackedVector2Array([Vector2(u0, 0.0), Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, 0.0)])
			var tint := Color.WHITE.lerp(Color(1.0, 0.90, 0.65), _seal_glow * 0.35)
			_canvas.draw_polygon(quad, PackedColorArray([tint, tint, tint, tint]), uvs, _tex_body)
	else:
		for i in range(n - 2, -1, -1):
			var u := float(i) / float(n - 1)
			_canvas.draw_line(pts[i], pts[i + 1], Color(0.68, 0.09, 0.09), _seg_half_width(u) * 1.9)

	# Barbed tail sprite attached to last segment
	if _tex_tail != null:
		var tail_pos := pts[n - 1]
		var tail_ang := tangents[n - 1].angle()
		_canvas.draw_set_transform(tail_pos, tail_ang, Vector2(0.42, 0.42))
		_canvas.draw_texture(_tex_tail, Vector2(-190.0, -64.0), Color.WHITE)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Woodcut Serpent Head (open fanged jaws during lunges & Ouroboros clamp!)
	var head_tex := _tex_head_open if (_jaw_open > 0.45 and _tex_head_open != null) else _tex_head_closed
	if head_tex != null:
		var head_ang := tangents[0].angle()
		var h_sc := 0.44 + _jaw_open * 0.05 + _seal_glow * 0.04
		var h_tint := Color.WHITE.lerp(Color(1.0, 0.88, 0.62), _seal_glow * 0.45)
		_canvas.draw_set_transform(pts[0], head_ang, Vector2(h_sc, h_sc))
		_canvas.draw_texture(head_tex, Vector2(-125.0, -120.0), h_tint)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Fang-snap crimson/gold flash burst
	if _bite_flash > 0.01:
		var r_fl := 24.0 + (1.0 - _bite_flash) * 56.0
		_canvas.draw_circle(_bite_flash_pos, r_fl * 0.55, Color(1.0, 0.82, 0.35, _bite_flash * 0.45))
		_canvas.draw_arc(_bite_flash_pos, r_fl, 0.0, TAU, 36, Color(1.0, 0.32, 0.16, _bite_flash * 0.85), 3.0)

	# 4. Ember / ink spark particles
	for sp in _sparks:
		var a := clampf(float(sp["life"]) / maxf(0.01, float(sp["max_life"])), 0.0, 1.0)
		var col: Color = sp["col"]
		_canvas.draw_circle(sp["pos"], float(sp["sz"]) * a, Color(col.r, col.g, col.b, a * 0.9))


func _draw_bg_cards() -> void:
	if _card_textures.is_empty():
		return
	for c in _bg_cards:
		var tex: Texture2D = _card_textures[int(c["tex_idx"]) % _card_textures.size()]
		var d: float = float(c["depth"])
		var burn: float = float(c["burn"])
		var sx := maxf(0.18, absf(cos(float(c["flip_phase"])))) * 0.24 * d
		var sy := 0.24 * d
		var alpha := (0.14 + 0.14 * d) * (1.0 - burn)
		var tint := Color(0.76, 0.64, 0.56, alpha)
		if burn > 0.0:
			tint = tint.lerp(Color(1.0, 0.34, 0.12, alpha), minf(1.0, burn * 1.8))
		var tsz := tex.get_size()
		_canvas.draw_set_transform(c["pos"], float(c["rot"]), Vector2(sx, sy))
		_canvas.draw_texture(tex, -tsz * 0.5, tint)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _finish() -> void:
	if _ending:
		return
	_ending = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 0.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(_player) and _player.playing:
		tw.tween_property(_player, "volume_db", -60.0, 0.72)
	tw.chain().tween_callback(func():
		finished.emit()
		queue_free()
	)
