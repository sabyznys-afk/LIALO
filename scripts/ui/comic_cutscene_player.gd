class_name ComicCutscenePlayer
extends Control

## Animated Short Woodcut-Ink Motion-Comic Cutscene Player for LIALO.
## Plays 2-4 sequential panels (8-15s total) with 2.5D Ken Burns parallax,
## stylized procedural woodcut-ink fallback artwork (or custom PNG overlays if present),
## comic action stamps, speech bubbles, and 2D atmospheric weather particles.

signal scene_finished(scene_id: String)
signal sfx_requested(sfx_key: String)

const StoryData := preload("res://scripts/campaign/campaign_story_data.gd")
const Toon := preload("res://scripts/toon_style.gd")

const FONT_DISP_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoBody.ttf"

var _font_disp: Font
var _font_body: Font
var _scene_id: String = ""
var _scene: Dictionary = {}
var _lang: String = "en"
var _auto_advance: bool = true
var _embedded: bool = false
var _playing: bool = false
var _panel_idx: int = -1
var _panel_timer: float = 0.0
var _fx_time: float = 0.0
var _is_headless: bool = false

var _bg_rect: ColorRect
var _title_lbl: Label
var _hint_lbl: Label
var _skip_btn: Button
var _panels_hb: HBoxContainer
var _panel_nodes: Array[Dictionary] = []
var _weather_ctrl: Control
var _weather_pts: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_is_headless = (DisplayServer.get_name() == "headless")
	_rng.seed = 90211
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font_disp = load(FONT_DISP_PATH) as Font if ResourceLoader.exists(FONT_DISP_PATH) else ThemeDB.fallback_font
	_font_body = load(FONT_BODY_PATH) as Font if ResourceLoader.exists(FONT_BODY_PATH) else ThemeDB.fallback_font
	_build_shell()


func _build_shell() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0.055, 0.044, 0.036, 0.96)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_rect)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var page_pan := PanelContainer.new()
	var page_sb := StyleBoxFlat.new()
	page_sb.bg_color = Color(0.095, 0.075, 0.056, 0.98)
	page_sb.border_color = Color(0.86, 0.68, 0.28, 0.94)
	page_sb.set_border_width_all(3)
	page_sb.set_corner_radius_all(12)
	page_sb.set_content_margin_all(18)
	page_pan.add_theme_stylebox_override("panel", page_sb)
	margin.add_child(page_pan)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	page_pan.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_override("font", _font_disp)
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	hdr.add_child(_title_lbl)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip [ESC]"
	_skip_btn.custom_minimum_size = Vector2(138, 34)
	_skip_btn.add_theme_font_override("font", _font_disp)
	_skip_btn.add_theme_font_size_override("font_size", 13)
	var sk_sb := StyleBoxFlat.new()
	sk_sb.bg_color = Color(0.20, 0.11, 0.08, 0.95)
	sk_sb.border_color = Color(0.84, 0.64, 0.28, 0.90)
	sk_sb.set_border_width_all(1)
	sk_sb.set_corner_radius_all(8)
	_skip_btn.add_theme_stylebox_override("normal", sk_sb)
	_skip_btn.pressed.connect(stop_scene)
	hdr.add_child(_skip_btn)

	_panels_hb = HBoxContainer.new()
	_panels_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panels_hb.add_theme_constant_override("separation", 14)
	vb.add_child(_panels_hb)

	_hint_lbl = Label.new()
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_override("font", _font_body)
	_hint_lbl.add_theme_font_size_override("font_size", 13)
	_hint_lbl.add_theme_color_override("font_color", Color(0.82, 0.74, 0.58))
	vb.add_child(_hint_lbl)

	_weather_ctrl = Control.new()
	_weather_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weather_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_ctrl.draw.connect(_draw_weather)
	add_child(_weather_ctrl)


func play_scene(scene_id: String, lang: String = "en", auto_advance: bool = true, embedded: bool = false) -> void:
	var data: Dictionary = StoryData.get_comic_scene(scene_id)
	if data.is_empty():
		visible = false
		scene_finished.emit(scene_id)
		return
	_scene_id = scene_id
	_scene = data
	_lang = lang
	_auto_advance = auto_advance
	_embedded = embedded
	_playing = true
	_panel_idx = -1
	_panel_timer = 0.0
	_fx_time = 0.0
	visible = true

	var pal: Dictionary = data.get("palette", {})
	var bg_col: Color = pal.get("bg", Color(0.06, 0.05, 0.05))
	_bg_rect.color = Color(bg_col.r, bg_col.g, bg_col.b, 0.88 if embedded else 0.96)
	_title_lbl.text = str(data.get("title_cs" if lang == "cs" else "title_en", scene_id))
	_skip_btn.text = "Přeskočit [ESC]" if lang == "cs" else "Skip [ESC]"
	_hint_lbl.text = "[KLIK / SPACE] Další panel  •  [ESC] Přeskočit" if lang == "cs" else "[CLICK / SPACE] Next Panel  •  [ESC] Skip"

	_init_weather(str(data.get("weather", "rain")))
	_rebuild_panels()
	_reveal_next_panel()


func stop_scene() -> void:
	if not _playing and not visible:
		return
	_playing = false
	visible = false
	var finished_id := _scene_id
	_clear_panels()
	scene_finished.emit(finished_id)


func advance_or_finish() -> void:
	if not _playing:
		return
	var panels: Array = _scene.get("panels", [])
	if _panel_idx + 1 < panels.size():
		_reveal_next_panel()
	else:
		stop_scene()


func _clear_panels() -> void:
	_panel_nodes.clear()
	if is_instance_valid(_panels_hb):
		for ch in _panels_hb.get_children():
			ch.queue_free()


func _rebuild_panels() -> void:
	_clear_panels()
	var panels: Array = _scene.get("panels", [])
	var pal: Dictionary = _scene.get("palette", {})
	var accent: Color = pal.get("accent", Color(1.0, 0.82, 0.34))

	for pi in range(panels.size()):
		var p: Dictionary = panels[pi]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.modulate.a = 0.0
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.075, 0.062, 0.050, 1.0)
		csb.border_color = Color(0.04, 0.03, 0.025, 1.0)
		csb.set_border_width_all(4)
		csb.set_corner_radius_all(6)
		csb.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", csb)
		_panels_hb.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)

		# Artwork stage with Ken Burns + procedural woodcut vector illustration or PNG
		var art_clip := Control.new()
		art_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art_clip.clip_contents = true
		vb.add_child(art_clip)

		var png_path := "res://assets/story/comics/%s_p%d.png" % [_scene_id, pi + 1]
		var art_tex: Texture2D = Toon.tex(png_path) if ResourceLoader.exists(png_path) else null
		var art_node: Control
		if art_tex != null:
			var tr := TextureRect.new()
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.texture = art_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art_node = tr
		else:
			var cv := Control.new()
			cv.set_anchors_preset(Control.PRESET_FULL_RECT)
			var motif_cap: String = str(p.get("motif", "spirko_lantern"))
			var idx_cap: int = pi
			cv.draw.connect(func(): _draw_comic_motif(cv, motif_cap, accent, idx_cap))
			art_node = cv
		art_clip.add_child(art_node)

		# Comic Action Stamp Overlay (upper-right)
		var stamp_txt := str(p.get("stamp", ""))
		var stamp_lbl: Label = null
		if stamp_txt != "":
			stamp_lbl = Label.new()
			stamp_lbl.text = stamp_txt
			stamp_lbl.anchor_left = 1.0; stamp_lbl.anchor_right = 1.0
			stamp_lbl.anchor_top = 0.0; stamp_lbl.anchor_bottom = 0.0
			stamp_lbl.offset_left = -126; stamp_lbl.offset_right = -10
			stamp_lbl.offset_top = 12; stamp_lbl.offset_bottom = 48
			stamp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stamp_lbl.rotation_degrees = -9.0
			stamp_lbl.scale = Vector2(0.2, 0.2)
			stamp_lbl.add_theme_font_override("font", _font_disp)
			stamp_lbl.add_theme_font_size_override("font_size", 24)
			stamp_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
			stamp_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.01, 0.02))
			stamp_lbl.add_theme_constant_override("outline_size", 7)
			art_clip.add_child(stamp_lbl)

		# Speech Bubble (if speaker present)
		var spk := str(p.get("speaker", ""))
		var b_txt := str(p.get("bubble_cs" if _lang == "cs" else "bubble_en", ""))
		if b_txt != "":
			var bpan := PanelContainer.new()
			bpan.anchor_left = 0.05; bpan.anchor_right = 0.95
			bpan.anchor_top = 1.0; bpan.anchor_bottom = 1.0
			bpan.offset_top = -78; bpan.offset_bottom = -8
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color(0.95, 0.90, 0.78, 0.96)
			bsb.border_color = Color(0.06, 0.04, 0.03, 1.0)
			bsb.set_border_width_all(2)
			bsb.set_corner_radius_all(10)
			bsb.set_content_margin_all(7)
			bpan.add_theme_stylebox_override("panel", bsb)
			var blbl := Label.new()
			blbl.text = ("%s: \"%s\"" % [spk, b_txt]) if spk != "" else b_txt
			blbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			blbl.add_theme_font_override("font", _font_body)
			blbl.add_theme_font_size_override("font_size", 12)
			blbl.add_theme_color_override("font_color", Color(0.09, 0.06, 0.04))
			bpan.add_child(blbl)
			art_clip.add_child(bpan)

		# Narrator Caption Strip
		var cap_pan := PanelContainer.new()
		var cap_sb := StyleBoxFlat.new()
		cap_sb.bg_color = Color(0.14, 0.10, 0.06, 0.96)
		cap_sb.border_color = Color(accent.r, accent.g, accent.b, 0.75)
		cap_sb.set_border_width_all(1)
		cap_sb.set_corner_radius_all(4)
		cap_sb.set_content_margin_all(8)
		cap_pan.add_theme_stylebox_override("panel", cap_sb)
		vb.add_child(cap_pan)

		var cap_lbl := Label.new()
		cap_lbl.text = str(p.get("caption_cs" if _lang == "cs" else "caption_en", ""))
		cap_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap_lbl.custom_minimum_size = Vector2(0, 44)
		cap_lbl.add_theme_font_override("font", _font_body)
		cap_lbl.add_theme_font_size_override("font_size", 13)
		cap_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		cap_pan.add_child(cap_lbl)

		_panel_nodes.append({"card": card, "art": art_node, "stamp": stamp_lbl, "data": p})


func _reveal_next_panel() -> void:
	_panel_idx += 1
	var panels: Array = _scene.get("panels", [])
	if _panel_idx >= _panel_nodes.size() or _panel_idx >= panels.size():
		stop_scene()
		return
	var entry: Dictionary = _panel_nodes[_panel_idx]
	var card: PanelContainer = entry["card"] as PanelContainer
	var art: Control = entry["art"] as Control
	var stamp: Label = entry.get("stamp", null) as Label
	var pdata: Dictionary = entry["data"]
	_panel_timer = float(pdata.get("dur", 3.0))

	var sfx_k := str(pdata.get("sfx", ""))
	if sfx_k != "" and not _is_headless:
		sfx_requested.emit(sfx_k)

	card.pivot_offset = card.size * 0.5
	var tilt := -1.2 if (_panel_idx % 2 == 0) else 1.2
	card.rotation_degrees = tilt * 2.5
	card.scale = Vector2(0.92, 0.92)
	var tw := card.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.28)
	tw.tween_property(card, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation_degrees", tilt, 0.36)

	if is_instance_valid(art):
		art.pivot_offset = art.size * 0.5
		var kb := art.create_tween()
		kb.tween_property(art, "scale", Vector2(1.07, 1.07), _panel_timer + 0.5).set_trans(Tween.TRANS_SINE)

	if is_instance_valid(stamp):
		stamp.pivot_offset = stamp.size * 0.5
		var stw := stamp.create_tween()
		stw.tween_interval(0.18)
		stw.tween_property(stamp, "scale", Vector2(1.05, 1.05), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_or_finish()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _playing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_ESCAPE:
			stop_scene()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
			advance_or_finish()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or not _playing:
		return
	var dt := minf(delta, 0.05)
	_fx_time += dt
	for p in _weather_pts:
		p["x"] = fmod(float(p["x"]) + float(p["vx"]) * dt + 1.0, 1.0)
		p["y"] = fmod(float(p["y"]) + float(p["vy"]) * dt + 1.0, 1.0)
	if is_instance_valid(_weather_ctrl):
		_weather_ctrl.queue_redraw()
	for pn in _panel_nodes:
		var a := pn.get("art", null) as Control
		if is_instance_valid(a):
			a.queue_redraw()
	if _auto_advance:
		_panel_timer -= dt
		if _panel_timer <= 0.0:
			advance_or_finish()


func _init_weather(kind: String) -> void:
	_weather_pts.clear()
	var count := 42 if kind in ["rain", "sand", "embers"] else 24
	for _i in range(count):
		var vx := -0.08 if kind == "rain" else (0.18 if kind == "sand" else _rng.randf_range(-0.04, 0.04))
		var vy := 0.55 if kind == "rain" else (-0.09 if kind in ["embers", "smoke"] else _rng.randf_range(-0.03, 0.05))
		_weather_pts.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"vx": vx,
			"vy": vy,
			"sz": _rng.randf_range(2.0, 6.0),
			"kind": kind,
		})


func _draw_weather() -> void:
	var sz := size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	for p in _weather_pts:
		var pos := Vector2(float(p["x"]) * sz.x, float(p["y"]) * sz.y)
		var kind := str(p["kind"])
		var s := float(p["sz"])
		if kind == "rain":
			_weather_ctrl.draw_line(pos, pos + Vector2(-4.0, 16.0), Color(0.68, 0.86, 1.0, 0.28), 1.3)
		elif kind == "sand":
			_weather_ctrl.draw_circle(pos, s * 0.65, Color(0.96, 0.78, 0.36, 0.28))
		elif kind == "embers":
			_weather_ctrl.draw_circle(pos, s * 0.7, Color(1.0, 0.54, 0.16, 0.45))
		elif kind == "smoke":
			_weather_ctrl.draw_circle(pos, s * 3.0, Color(0.72, 0.70, 0.76, 0.08))
		elif kind == "sun":
			_weather_ctrl.draw_circle(pos, s * 0.85, Color(1.0, 0.92, 0.48, 0.38))


func _draw_comic_motif(cv: Control, motif: String, accent: Color, _idx: int) -> void:
	var s := cv.size
	if s.x < 20.0 or s.y < 20.0:
		return
	var bg_c := Color(0.11, 0.085, 0.068)
	if motif == "sepia_flashback":
		bg_c = Color(0.22, 0.17, 0.11)
	elif motif == "sunrise_tavern":
		bg_c = Color(0.26, 0.18, 0.09)
	cv.draw_rect(Rect2(Vector2.ZERO, s), bg_c)
	# Subtle woodcut crosshatch horizon bands
	for hy in range(8, int(s.y), 14):
		cv.draw_line(Vector2(0, float(hy)), Vector2(s.x, float(hy)), Color(0.04, 0.03, 0.025, 0.30), 1.0)

	var c := Vector2(s.x * 0.5, s.y * 0.44)
	var ink := Color(0.04, 0.03, 0.025)
	var pulse := 0.88 + 0.12 * sin(_fx_time * 3.4)

	match motif:
		"rain_tavern", "sunrise_tavern":
			var glow_col := Color(1.0, 0.86, 0.42, 0.55) if motif == "sunrise_tavern" else Color(0.45, 0.72, 0.95, 0.25)
			cv.draw_rect(Rect2(c.x - 54, c.y - 68, 108, 128), glow_col)
			cv.draw_rect(Rect2(c.x - 54, c.y - 68, 108, 128), ink, false, 4.0)
			cv.draw_line(Vector2(c.x, c.y - 68), Vector2(c.x, c.y + 60), ink, 3.0)
			cv.draw_line(Vector2(c.x - 54, c.y - 4), Vector2(c.x + 54, c.y - 4), ink, 3.0)
		"spirko_lantern", "sepia_flashback":
			cv.draw_circle(c + Vector2(36, -10), 42.0 * pulse, Color(accent.r, accent.g, accent.b, 0.28))
			cv.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-46, 76), c + Vector2(-32, -8), c + Vector2(32, -8), c + Vector2(46, 76)
			]), Color(0.14, 0.13, 0.16))
			cv.draw_circle(c + Vector2(0, -26), 22.0, Color(0.84, 0.74, 0.58))
			cv.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-36, -34), c + Vector2(0, -78), c + Vector2(36, -34)
			]), ink)
			cv.draw_rect(Rect2(c.x + 28, c.y - 16, 18, 28), Color(accent.r, accent.g, accent.b, 0.90))
		"five_seals", "seal_crack":
			for si in range(5):
				var ang := float(si) * (TAU / 5.0) - PI * 0.5
				var p := c + Vector2(cos(ang), sin(ang)) * 52.0
				cv.draw_circle(p, 18.0, Color(accent.r, accent.g, accent.b, 0.72))
				cv.draw_arc(p, 18.0, 0.0, TAU, 24, ink, 2.5)
			if motif == "seal_crack":
				cv.draw_line(c + Vector2(-55, -60), c + Vector2(55, 60), Color(1.0, 0.94, 0.58), 4.0)
		"deal_cards":
			for ci in range(4):
				var off := (float(ci) - 1.5) * 28.0
				cv.draw_set_transform(c + Vector2(off, absf(off) * 0.2), (float(ci) - 1.5) * 0.16, Vector2.ONE)
				cv.draw_rect(Rect2(-24, -36, 48, 72), Color(0.90, 0.84, 0.70))
				cv.draw_rect(Rect2(-24, -36, 48, 72), ink, false, 3.0)
				cv.draw_rect(Rect2(-18, -30, 36, 60), accent, false, 2.0)
			cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			# Dramatic sovereign emblem (crown/scarab/eagle/compass/ledger) framed by ink rays
			for ri in range(12):
				var ra := float(ri) * (TAU / 12.0) + _fx_time * 0.12
				cv.draw_line(c, c + Vector2(cos(ra), sin(ra)) * 120.0, Color(accent.r, accent.g, accent.b, 0.18), 2.0)
			cv.draw_circle(c, 48.0, Color(accent.r, accent.g, accent.b, 0.82))
			cv.draw_arc(c, 48.0, 0.0, TAU, 36, ink, 4.0)
			cv.draw_arc(c, 36.0, 0.0, TAU, 28, Color(0.98, 0.92, 0.72), 2.5)
