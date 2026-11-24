extends CanvasLayer
## Loading screen: a detailed red snake creeps to the middle of the screen and
## then starts circling. Plays the intro sting (max 15 s). Click / key skips.

signal finished

const AUDIO_PATH := "res://assets/audio/sfx_loading_snake"
const MIN_TIME := 3.0
const AUTO_END := 9.0
const AUDIO_MAX := 15.0
const SEGMENTS := 46
const SEG_SPACING := 9.0
const CIRCLE_R := 130.0

var volume_db: float = -4.0
var _t: float = 0.0
var _ending: bool = false
var _root: Control
var _canvas: Control
var _label: Label
var _player: AudioStreamPlayer
var _trail: PackedVector2Array = PackedVector2Array()
var _head: Vector2
var _phase_circle: bool = false
var _circle_ang: float = PI
var _circle_t0: float = 0.0


func _ready() -> void:
	layer = 90
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.03, 0.028, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	_root.add_child(_canvas)
	_label = Label.new()
	_label.text = "LOADING..."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_top = -90
	_label.offset_left = -200
	_label.offset_right = 200
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.5))
	_root.add_child(_label)

	var vs := _vp_size()
	_head = Vector2(-60.0, vs.y * 0.5 + 40.0)
	for i in range(SEGMENTS * 3):
		_trail.append(_head - Vector2(i * 3.0, 0))

	_player = AudioStreamPlayer.new()
	_player.volume_db = volume_db
	add_child(_player)
	var st := _load_stream()
	if st:
		_player.stream = st
		_player.play()


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
		get_viewport().set_input_as_handled()
		if _t >= MIN_TIME:
			_finish()


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_player) and _player.playing and _player.get_playback_position() >= AUDIO_MAX:
		_player.stop()
	var vs := _vp_size()
	var center := vs * 0.5
	if not _phase_circle:
		# Creep towards the centre with a serpentine wiggle
		var dir := (center + Vector2(-CIRCLE_R, 0) - _head)
		var dist := dir.length()
		var speed := 230.0
		if dist < speed * delta + 2.0:
			_phase_circle = true
			_circle_t0 = _t
			_circle_ang = PI
		else:
			var d := dir / dist
			var perp := Vector2(-d.y, d.x)
			_head += d * speed * delta + perp * sin(_t * 7.0) * 3.2
	if _phase_circle:
		var w := minf(2.4, 0.9 + (_t - _circle_t0) * 0.6)
		_circle_ang += w * delta
		_head = center + Vector2(cos(_circle_ang), sin(_circle_ang)) * CIRCLE_R
	_trail.insert(0, _head)
	var max_len := SEGMENTS * 12
	if _trail.size() > max_len:
		_trail.resize(max_len)
	var dots := int(_t * 2.0) % 4
	_label.text = "LOADING" + ".".repeat(dots) + ("   (click to continue)" if _t >= MIN_TIME else "")
	_canvas.queue_redraw()
	if not _ending and _t >= AUTO_END:
		_finish()


func _segment_points() -> PackedVector2Array:
	# Resample trail so segments are evenly spaced
	var pts := PackedVector2Array()
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
	return pts


func _draw_scene() -> void:
	var vs := _vp_size()
	var center := vs * 0.5
	# Ritual ring on the floor
	_canvas.draw_arc(center, CIRCLE_R + 34.0, 0, TAU, 96, Color(0.5, 0.18, 0.12, 0.35), 2.0)
	_canvas.draw_arc(center, CIRCLE_R - 34.0, 0, TAU, 96, Color(0.5, 0.18, 0.12, 0.25), 1.5)
	var pts := _segment_points()
	var n := pts.size()
	if n < 2:
		return
	# Shadow
	for i in range(n - 1, -1, -1):
		var r := _radius(i, n)
		_canvas.draw_circle(pts[i] + Vector2(5, 7), r, Color(0, 0, 0, 0.35))
	# Body: dark outline, red base, darker dorsal band, highlight, scale pattern
	for i in range(n - 1, -1, -1):
		var p := pts[i]
		var r := _radius(i, n)
		var fwd := (pts[maxi(i - 1, 0)] - pts[mini(i + 1, n - 1)]).normalized()
		if fwd == Vector2.ZERO:
			fwd = Vector2.RIGHT
		var side := Vector2(-fwd.y, fwd.x)
		_canvas.draw_circle(p, r + 2.0, Color(0.12, 0.02, 0.02))
		_canvas.draw_circle(p, r, Color(0.72, 0.08, 0.07))
		_canvas.draw_circle(p - side * r * 0.18, r * 0.72, Color(0.55, 0.04, 0.05))
		# diamond scale
		var dc := Color(0.32, 0.02, 0.03) if i % 2 == 0 else Color(0.88, 0.22, 0.12)
		var dr := r * 0.42
		_canvas.draw_colored_polygon(PackedVector2Array([
			p + fwd * dr, p + side * dr * 0.7, p - fwd * dr, p - side * dr * 0.7]), dc)
		_canvas.draw_circle(p + side * r * 0.45 + fwd * r * 0.1, r * 0.22, Color(1.0, 0.55, 0.45, 0.45))
		# belly edge
		_canvas.draw_arc(p, r * 0.92, side.angle() - 0.6, side.angle() + 0.6, 6, Color(0.95, 0.68, 0.38, 0.55), 1.6)
	_draw_head(pts[0], (pts[0] - pts[1]).normalized())


func _radius(i: int, n: int) -> float:
	var u := float(i) / float(n - 1)
	if u < 0.08:
		return lerpf(15.0, 17.0, u / 0.08)
	return lerpf(17.0, 3.0, pow((u - 0.08) / 0.92, 1.4))


func _draw_head(p: Vector2, fwd: Vector2) -> void:
	if fwd == Vector2.ZERO:
		fwd = Vector2.RIGHT
	var side := Vector2(-fwd.y, fwd.x)
	# tongue flick
	if fmod(_t, 1.1) < 0.35:
		var tb := p + fwd * 24.0
		var tm := tb + fwd * 14.0
		_canvas.draw_line(tb, tm, Color(0.95, 0.1, 0.25), 2.5)
		_canvas.draw_line(tm, tm + fwd * 7.0 + side * 5.0, Color(0.95, 0.1, 0.25), 2.0)
		_canvas.draw_line(tm, tm + fwd * 7.0 - side * 5.0, Color(0.95, 0.1, 0.25), 2.0)
	var poly := PackedVector2Array([
		p + fwd * 27.0,
		p + fwd * 18.0 + side * 13.0,
		p + side * 18.0,
		p - fwd * 12.0 + side * 13.0,
		p - fwd * 14.0,
		p - fwd * 12.0 - side * 13.0,
		p - side * 18.0,
		p + fwd * 18.0 - side * 13.0,
	])
	var outline := PackedVector2Array()
	for q in poly:
		outline.append(p + (q - p) * 1.12)
	_canvas.draw_colored_polygon(outline, Color(0.12, 0.02, 0.02))
	_canvas.draw_colored_polygon(poly, Color(0.75, 0.09, 0.07))
	# head plates
	_canvas.draw_colored_polygon(PackedVector2Array([
		p + fwd * 16.0, p + side * 7.0, p - fwd * 9.0, p - side * 7.0]), Color(0.5, 0.03, 0.04))
	# eyes (gold, slit pupil)
	for s in [-1.0, 1.0]:
		var e: Vector2 = p + fwd * 9.0 + side * 10.0 * s
		_canvas.draw_circle(e, 5.0, Color(0.1, 0.0, 0.0))
		_canvas.draw_circle(e, 4.0, Color(1.0, 0.78, 0.15))
		_canvas.draw_line(e - fwd * 3.2, e + fwd * 3.2, Color(0.05, 0.0, 0.0), 1.6)
		_canvas.draw_circle(e + side * 1.2 * s + fwd * 1.2, 1.0, Color(1, 1, 1, 0.9))
	# nostrils
	_canvas.draw_circle(p + fwd * 22.0 + side * 3.5, 1.3, Color(0.1, 0.0, 0.0))
	_canvas.draw_circle(p + fwd * 22.0 - side * 3.5, 1.3, Color(0.1, 0.0, 0.0))


func _finish() -> void:
	if _ending:
		return
	_ending = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 0.0, 0.8)
	if is_instance_valid(_player) and _player.playing:
		tw.tween_property(_player, "volume_db", -60.0, 0.8)
	tw.chain().tween_callback(func():
		finished.emit()
		queue_free()
	)
