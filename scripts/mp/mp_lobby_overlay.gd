class_name MpLobbyOverlay
extends Control

## Tavern Multiplayer Hall (2-4 Players): Campaign Vault Loadouts, Recent Opponents,
## Instant Rematch, Radmin/Tailscale VPN Share Bar, Animated Embers & Card Backdrop.

const Config = preload("res://scripts/mp/mp_config.gd")
const History = preload("res://scripts/mp/mp_history.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")
const Toon = preload("res://scripts/toon_style.gd")
const FONT_DISPLAY_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoBody.ttf"

signal close_requested
signal play_click_sfx

var mp_net: Node = null
var _font_display: Font = null
var _font_body: Font = null

var _main_panel: PanelContainer
var _bg_fx_canvas: Control
var _fx_t: float = 0.0
var _embers: Array[Dictionary] = []
var _bg_cards: Array[Dictionary] = []

var _conn_dot_lbl: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var host_btn: Button
var join_btn: Button
var spawn_win_btn: Button
var leave_btn: Button

var status_lbl: Label
var share_bar: PanelContainer
var share_vpn_lbl: Label
var share_lan_lbl: Label
var share_pub_lbl: Label
var copy_vpn_btn: Button
var copy_lan_btn: Button
var copy_pub_btn: Button
var _vpn_copy_str: String = ""
var _lan_copy_str: String = ""
var _pub_copy_str: String = ""

var _tab_btns: Array[Button] = []
var _tab_containers: Array[Control] = []
var _active_tab: int = 0
var _recent_tab_btn: Button

var arch_buttons: Dictionary = {}
var char_buttons: Dictionary = {}
var _char_portrait_pivots: Array[Dictionary] = []
var selected_char_id: String = "CHAR_GUILLOTINE"
var selected_arch_id: String = "GUILLOTINE_ACES"
var extra_aces_val: int = 4
var aces_lbl: Label
var _ace_pips_lbl: Label
var deck_desc_lbl: Label

var recent_list_vb: VBoxContainer

var rule_btn: Button
var vista_btn: Button
var _selected_vista_era: String = "stredovek"
var seats_box: VBoxContainer
var _last_seat_count: int = 0

var chat_panel: PanelContainer
var chat_rtl: RichTextLabel
var chat_input: LineEdit
var chat_send_btn: Button
var _chat_lines: Array[String] = []

var add_bot_btn: Button
var ready_btn: Button
var start_btn: Button
var _local_ready: bool = true

var _toast_panel: PanelContainer
var _toast_lbl: Label
var _toast_tween: Tween

var _profile: Dictionary = {}
var _prefs: Dictionary = {}
var _lang: String = "en"
var selected_power_cards: Array[String] = []
var selected_table_relics: Array[String] = []
var selected_passive_relics: Array[String] = []
var equipped_sword_id: String = "SWORD_IRON"
var vault_power_btns: Dictionary = {}
var vault_trel_btns: Dictionary = {}
var vault_prel_btns: Dictionary = {}
var vault_power_hdr: Label
var vault_trel_hdr: Label
var vault_prel_hdr: Label
var vault_sword_lbl: Label
var vault_box: VBoxContainer


func configure(network_node: Node) -> void:
	mp_net = network_node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_fonts()
	_prefs = History.load_data()
	_load_vault_from_profile()
	_init_bg_fx_particles()
	_build_ui()
	_apply_saved_prefs()
	if mp_net != null:
		mp_net.lobby_updated.connect(_on_lobby_updated)
		mp_net.status_changed.connect(_on_status_changed)
		if mp_net.has_signal("host_network_ready"):
			mp_net.host_network_ready.connect(_on_host_network_ready)
		if mp_net.has_signal("lobby_chat_received"):
			mp_net.lobby_chat_received.connect(_on_lobby_chat_received)
		mp_net.session_closed.connect(func(_r: String): _refresh_controls())
		if mp_net.in_session and not mp_net.lobby_seats.is_empty():
			_on_lobby_updated(mp_net.lobby_seats, mp_net.room_settings)
	_refresh_recent_list()
	_refresh_controls()
	_play_entrance_anim()


func _process(delta: float) -> void:
	if not visible or not is_inside_tree():
		return
	_fx_t += delta
	for em in _embers:
		em["y"] = float(em["y"]) - float(em["spd"]) * delta
		if float(em["y"]) < -0.05:
			em["y"] = 1.05
			em["x"] = randf()
	for bc in _bg_cards:
		bc["rot"] = float(bc["rot"]) + float(bc["rspd"]) * delta
		bc["y"] = float(bc["y"]) - float(bc["spd"]) * delta
		if float(bc["y"]) < -0.15:
			bc["y"] = 1.15
	if is_instance_valid(_bg_fx_canvas):
		_bg_fx_canvas.queue_redraw()
	if is_instance_valid(start_btn) and start_btn.visible and not start_btn.disabled:
		var pulse := 1.0 + sin(_fx_t * 3.8) * 0.022
		start_btn.pivot_offset = start_btn.size * 0.5
		start_btn.scale = Vector2(pulse, pulse)
	elif is_instance_valid(start_btn):
		start_btn.scale = Vector2.ONE
	for pv in _char_portrait_pivots:
		var pivot := pv.get("node") as Node3D
		if is_instance_valid(pivot):
			pivot.rotation.y = sin(_fx_t * 1.15 + float(pv.get("phase", 0.0))) * 0.24


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var focused := get_viewport().gui_get_focus_owner() if get_viewport() else null
		if focused is LineEdit:
			if focused == chat_input:
				chat_input.release_focus()
				if get_viewport():
					get_viewport().set_input_as_handled()
			return
		if get_viewport():
			get_viewport().set_input_as_handled()
		_close_lobby()


func _close_lobby() -> void:
	play_click_sfx.emit()
	_persist_ui_prefs()
	if mp_net != null and mp_net.in_session:
		mp_net.leave_room(false)
	close_requested.emit()


func _ensure_fonts() -> void:
	if _font_display == null and ResourceLoader.exists(FONT_DISPLAY_PATH):
		_font_display = ResourceLoader.load(FONT_DISPLAY_PATH) as Font
	if _font_body == null and ResourceLoader.exists(FONT_BODY_PATH):
		_font_body = ResourceLoader.load(FONT_BODY_PATH) as Font


func _apply_font(ctrl: Control, is_display: bool = false) -> void:
	var f := _font_display if is_display else _font_body
	if f != null:
		ctrl.add_theme_font_override("font", f)


func _make_tavern_panel_sb(bg: Color, border: Color, border_w: int = 2, radius: int = 12, pad: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.border_width_bottom = border_w + 2
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(6, pad - 3)
	sb.content_margin_bottom = maxi(6, pad - 3)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _attach_hover_anim(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		if btn.disabled or not is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		if not is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)


func _style_tavern_btn(btn: Button, bg: Color, border: Color, is_display: bool = false, radius: int = 9, with_hover: bool = true) -> void:
	_apply_font(btn, is_display)
	var sb_n := _make_tavern_panel_sb(bg, border, 2, radius, 12)
	sb_n.content_margin_top = 7
	sb_n.content_margin_bottom = 8
	var sb_h := _make_tavern_panel_sb(bg.lightened(0.16), border.lightened(0.24), 2, radius, 12)
	sb_h.content_margin_top = 7
	sb_h.content_margin_bottom = 8
	var sb_p := _make_tavern_panel_sb(bg.darkened(0.18), border, 2, radius, 12)
	sb_p.border_width_top = 1
	sb_p.border_width_bottom = 2
	sb_p.content_margin_top = 9
	sb_p.content_margin_bottom = 6
	var sb_d := _make_tavern_panel_sb(Color(0.08, 0.07, 0.06, 0.72), Color(0.32, 0.26, 0.18, 0.45), 1, radius, 12)
	sb_d.content_margin_top = 7
	sb_d.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("disabled", sb_d)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.56))
	btn.add_theme_color_override("font_disabled_color", Color(0.52, 0.48, 0.42, 0.7))
	if with_hover:
		_attach_hover_anim(btn)


func _style_tavern_input(le: LineEdit) -> void:
	_apply_font(le, false)
	var sb_n := _make_tavern_panel_sb(Color(0.05, 0.04, 0.035, 0.94), Color(0.54, 0.40, 0.22, 0.78), 1, 8, 10)
	sb_n.border_width_bottom = 2
	sb_n.shadow_size = 3
	var sb_f := _make_tavern_panel_sb(Color(0.08, 0.06, 0.045, 0.98), Color(0.96, 0.78, 0.32, 0.98), 2, 8, 10)
	sb_f.shadow_size = 4
	le.add_theme_stylebox_override("normal", sb_n)
	le.add_theme_stylebox_override("focus", sb_f)
	le.add_theme_stylebox_override("read_only", sb_n)
	le.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
	le.add_theme_color_override("caret_color", Color(1.0, 0.84, 0.36))


func _apply_choice_btn_style(btn: Button, is_selected: bool, accent: Color) -> void:
	_apply_font(btn, false)
	if is_selected:
		var glow_border := Color(0.98, 0.80, 0.30, 0.98).lerp(accent, 0.35)
		var sb_sel := _make_tavern_panel_sb(Color(0.24, 0.17, 0.08, 0.96), glow_border, 3, 10, 10)
		sb_sel.border_width_bottom = 3
		sb_sel.shadow_color = Color(glow_border.r, glow_border.g, glow_border.b, 0.45)
		sb_sel.shadow_size = 10
		var sb_sel_h := sb_sel.duplicate() as StyleBoxFlat
		sb_sel_h.bg_color = Color(0.28, 0.20, 0.10, 0.98)
		btn.add_theme_stylebox_override("normal", sb_sel)
		btn.add_theme_stylebox_override("hover", sb_sel_h)
		btn.add_theme_stylebox_override("pressed", sb_sel)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.68))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.56))
	else:
		var sb_unsel := _make_tavern_panel_sb(Color(0.06, 0.05, 0.045, 0.88), Color(0.46, 0.36, 0.24, 0.52), 1, 10, 10)
		sb_unsel.border_width_bottom = 1
		sb_unsel.shadow_size = 4
		var sb_unsel_h := _make_tavern_panel_sb(Color(0.11, 0.085, 0.065, 0.92), Color(0.72, 0.56, 0.32, 0.78), 2, 10, 10)
		sb_unsel_h.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", sb_unsel)
		btn.add_theme_stylebox_override("hover", sb_unsel_h)
		btn.add_theme_stylebox_override("pressed", sb_unsel_h)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
		btn.add_theme_color_override("font_hover_color", Color(0.95, 0.88, 0.72))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.56))


func _init_bg_fx_particles() -> void:
	_embers.clear()
	for _i in range(28):
		_embers.append({
			"x": randf(),
			"y": randf(),
			"r": randf_range(1.6, 4.2),
			"spd": randf_range(0.025, 0.075),
			"phase": randf_range(0.0, TAU),
			"alpha": randf_range(0.28, 0.72),
		})
	_bg_cards.clear()
	var card_x := [0.06, 0.94, 0.11, 0.89, 0.04, 0.96]
	for i in range(6):
		_bg_cards.append({
			"x": card_x[i],
			"y": randf(),
			"rot": randf_range(-0.4, 0.4),
			"rspd": randf_range(-0.18, 0.18),
			"spd": randf_range(0.012, 0.028),
			"w": randf_range(38.0, 56.0),
		})


func _draw_bg_fx() -> void:
	if not is_instance_valid(_bg_fx_canvas):
		return
	var sz := _bg_fx_canvas.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	var glow_p := 0.10 + 0.04 * sin(_fx_t * 1.9)
	_bg_fx_canvas.draw_circle(Vector2(sz.x * 0.5, sz.y * 0.14), sz.x * 0.34, Color(1.0, 0.64, 0.22, glow_p))
	for bc in _bg_cards:
		var cx := float(bc["x"]) * sz.x
		var cy := float(bc["y"]) * sz.y
		var w := float(bc["w"])
		var h := w * 1.45
		_bg_fx_canvas.draw_set_transform(Vector2(cx, cy), float(bc["rot"]), Vector2.ONE)
		_bg_fx_canvas.draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.85, 0.68, 0.36, 0.055), false, 1.5)
		_bg_fx_canvas.draw_rect(Rect2(-w * 0.5 + 4, -h * 0.5 + 4, w - 8, h - 8), Color(0.18, 0.12, 0.08, 0.10), true)
	_bg_fx_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for em in _embers:
		var ex := float(em["x"]) * sz.x + sin(_fx_t * 2.1 + float(em["phase"])) * 16.0
		var ey := float(em["y"]) * sz.y
		var ea := float(em["alpha"]) * (0.65 + 0.35 * sin(_fx_t * 3.4 + float(em["phase"])))
		_bg_fx_canvas.draw_circle(Vector2(ex, ey), float(em["r"]), Color(1.0, 0.72, 0.28, ea))


func _build_ui() -> void:
	# Textured Tavern Backdrop + Dark Atmospheric Vignette + Animated Embers/Cards
	var bg_tex := Toon.tex("res://assets/ui/lobby_tavern_handdrawn.png")
	if bg_tex == null:
		bg_tex = Toon.tex("res://assets/lobby/menu_bg_stredovek.png")
	if bg_tex != null:
		var bg_rect := TextureRect.new()
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_rect.texture = bg_tex
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_rect.modulate = Color(0.38, 0.31, 0.25, 1.0)
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_rect)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.022, 0.018, 0.76)
	add_child(dim)

	_bg_fx_canvas = Control.new()
	_bg_fx_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_fx_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_fx_canvas.draw.connect(_draw_bg_fx)
	add_child(_bg_fx_canvas)

	_main_panel = PanelContainer.new()
	_main_panel.anchor_left = 0.03; _main_panel.anchor_right = 0.97
	_main_panel.anchor_top = 0.03; _main_panel.anchor_bottom = 0.97
	_main_panel.clip_contents = true
	_main_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.058, 0.042, 0.95), Color(0.84, 0.64, 0.26, 0.94), 3, 14, 16))
	add_child(_main_panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 10)
	_main_panel.add_child(root_vb)

	# 1. Stylized Tavern Hall Header Bar (Clean, zero dev banners!)
	var hdr_bar := PanelContainer.new()
	hdr_bar.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.14, 0.095, 0.06, 0.96), Color(0.88, 0.68, 0.26, 0.92), 2, 10, 10))
	root_vb.add_child(hdr_bar)

	var hdr_hb := HBoxContainer.new()
	hdr_hb.add_theme_constant_override("separation", 12)
	hdr_bar.add_child(hdr_hb)

	var logo_tex := Toon.tex("res://assets/lobby/title_lialo.png")
	if logo_tex != null:
		var logo_img := TextureRect.new()
		logo_img.texture = logo_tex
		logo_img.custom_minimum_size = Vector2(92, 34)
		logo_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr_hb.add_child(logo_img)

	var hall_lbl := Label.new()
	hall_lbl.text = "⚔  KRČMOVÝ MULTIPLAYER (2–4 HRÁČI)" if _lang == "cs" else "⚔  TAVERN MULTIPLAYER HALL (2–4 PLAYERS)"
	hall_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(hall_lbl, true)
	hall_lbl.add_theme_font_size_override("font_size", 18)
	hall_lbl.add_theme_color_override("font_color", Color(1.0, 0.89, 0.52))
	hdr_hb.add_child(hall_lbl)

	_conn_dot_lbl = Label.new()
	_conn_dot_lbl.text = "● Offline"
	_apply_font(_conn_dot_lbl, false)
	_conn_dot_lbl.add_theme_font_size_override("font_size", 13)
	_conn_dot_lbl.add_theme_color_override("font_color", Color(0.74, 0.70, 0.64))
	hdr_hb.add_child(_conn_dot_lbl)

	var ver_badge := PanelContainer.new()
	ver_badge.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.12, 0.09, 0.06, 0.95), Color(0.72, 0.58, 0.28, 0.82), 1, 6, 8))
	hdr_hb.add_child(ver_badge)
	var ver_lbl := Label.new()
	ver_lbl.text = "v%s" % Config.MP_PROTOCOL_VERSION
	_apply_font(ver_lbl, false)
	ver_lbl.add_theme_font_size_override("font_size", 12)
	ver_lbl.add_theme_color_override("font_color", Color(0.76, 0.92, 1.0))
	ver_badge.add_child(ver_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ Zpět" if _lang == "cs" else "✕ Back"
	_style_tavern_btn(close_btn, Color(0.24, 0.10, 0.09, 0.95), Color(0.78, 0.36, 0.28, 0.88), false, 8)
	close_btn.pressed.connect(_close_lobby)
	hdr_hb.add_child(close_btn)

	# 2. Connection & Profile Strip
	var conn_hb := HBoxContainer.new()
	conn_hb.add_theme_constant_override("separation", 8)
	root_vb.add_child(conn_hb)

	var n_lbl := Label.new(); n_lbl.text = "Name:"
	_apply_font(n_lbl, false); n_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	conn_hb.add_child(n_lbl)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(130, 36)
	name_edit.text = "Duelist_%d" % (randi() % 90 + 10)
	name_edit.text_submitted.connect(func(_t): _persist_ui_prefs())
	name_edit.focus_exited.connect(_persist_ui_prefs)
	_style_tavern_input(name_edit)
	conn_hb.add_child(name_edit)

	var ip_lbl := Label.new(); ip_lbl.text = "Host IP:"
	_apply_font(ip_lbl, false); ip_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	conn_hb.add_child(ip_lbl)
	ip_edit = LineEdit.new()
	ip_edit.custom_minimum_size = Vector2(136, 36)
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Radmin / LAN IP"
	_style_tavern_input(ip_edit)
	conn_hb.add_child(ip_edit)

	var p_lbl := Label.new(); p_lbl.text = "Port:"
	_apply_font(p_lbl, false); p_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	conn_hb.add_child(p_lbl)
	port_edit = LineEdit.new()
	port_edit.custom_minimum_size = Vector2(68, 36)
	port_edit.text = str(Config.DEFAULT_PORT)
	_style_tavern_input(port_edit)
	conn_hb.add_child(port_edit)

	host_btn = Button.new()
	host_btn.text = "🔥 HOST TABLE"
	host_btn.custom_minimum_size = Vector2(132, 36)
	_style_tavern_btn(host_btn, Color(0.32, 0.16, 0.08, 0.96), Color(0.94, 0.70, 0.24, 0.94), true, 8)
	host_btn.pressed.connect(_on_host_pressed)
	conn_hb.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "🔗 JOIN TABLE"
	join_btn.custom_minimum_size = Vector2(128, 36)
	_style_tavern_btn(join_btn, Color(0.14, 0.22, 0.18, 0.96), Color(0.56, 0.82, 0.62, 0.90), true, 8)
	join_btn.pressed.connect(_on_join_pressed)
	conn_hb.add_child(join_btn)

	if OS.has_feature("editor") or ("--mp-test" in OS.get_cmdline_args()):
		spawn_win_btn = Button.new()
		spawn_win_btn.text = "🪟 +2nd"
		spawn_win_btn.tooltip_text = "Open a 2nd local client window for instant loopback testing"
		spawn_win_btn.custom_minimum_size = Vector2(82, 36)
		_style_tavern_btn(spawn_win_btn, Color(0.16, 0.13, 0.10, 0.94), Color(0.62, 0.50, 0.30, 0.80), false, 8)
		spawn_win_btn.pressed.connect(func():
			play_click_sfx.emit()
			OS.create_instance(["--mp-test"])
			_on_status_changed("Launched 2nd window — click JOIN TABLE there!", false)
		)
		conn_hb.add_child(spawn_win_btn)

	leave_btn = Button.new()
	leave_btn.text = "Disconnect"
	leave_btn.custom_minimum_size = Vector2(104, 36)
	_style_tavern_btn(leave_btn, Color(0.24, 0.11, 0.10, 0.94), Color(0.74, 0.36, 0.30, 0.85), false, 8)
	leave_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net:
			mp_net.leave_room(true)
	)
	conn_hb.add_child(leave_btn)

	status_lbl = Label.new()
	status_lbl.text = "Prepare your Duelist & Deck below, then Host Table or Join a Friend (Radmin / Tailscale / LAN)."
	_apply_font(status_lbl, false)
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	root_vb.add_child(status_lbl)

	# 3. Smart VPN + LAN + UPnP Share Address Bar (visible when Hosting)
	share_bar = PanelContainer.new()
	share_bar.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.09, 0.14, 0.11, 0.94), Color(0.46, 0.80, 0.58, 0.88), 1, 9, 8))
	share_bar.visible = false
	root_vb.add_child(share_bar)

	var share_hb := HBoxContainer.new()
	share_hb.add_theme_constant_override("separation", 10)
	share_bar.add_child(share_hb)

	share_vpn_lbl = Label.new()
	_apply_font(share_vpn_lbl, false)
	share_vpn_lbl.add_theme_font_size_override("font_size", 13)
	share_vpn_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
	share_hb.add_child(share_vpn_lbl)

	copy_vpn_btn = Button.new()
	copy_vpn_btn.text = "📋 Copy VPN"
	copy_vpn_btn.custom_minimum_size = Vector2(104, 28)
	_style_tavern_btn(copy_vpn_btn, Color(0.14, 0.28, 0.18, 0.96), Color(0.50, 0.92, 0.64, 0.94), false, 7)
	copy_vpn_btn.pressed.connect(func():
		play_click_sfx.emit()
		_copy_and_toast(_vpn_copy_str, "VPN IP")
	)
	share_hb.add_child(copy_vpn_btn)

	share_lan_lbl = Label.new()
	share_lan_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(share_lan_lbl, false)
	share_lan_lbl.add_theme_font_size_override("font_size", 13)
	share_lan_lbl.add_theme_color_override("font_color", Color(0.84, 0.94, 0.86))
	share_hb.add_child(share_lan_lbl)

	copy_lan_btn = Button.new()
	copy_lan_btn.text = "📋 Copy LAN"
	copy_lan_btn.custom_minimum_size = Vector2(104, 28)
	_style_tavern_btn(copy_lan_btn, Color(0.14, 0.22, 0.18, 0.94), Color(0.52, 0.80, 0.64, 0.86), false, 7)
	copy_lan_btn.pressed.connect(func():
		play_click_sfx.emit()
		_copy_and_toast(_lan_copy_str, "LAN IP")
	)
	share_hb.add_child(copy_lan_btn)

	share_pub_lbl = Label.new()
	_apply_font(share_pub_lbl, false)
	share_pub_lbl.add_theme_font_size_override("font_size", 12)
	share_pub_lbl.add_theme_color_override("font_color", Color(0.76, 0.88, 0.96))
	share_hb.add_child(share_pub_lbl)

	copy_pub_btn = Button.new()
	copy_pub_btn.text = "📋 Copy Public"
	copy_pub_btn.custom_minimum_size = Vector2(114, 28)
	_style_tavern_btn(copy_pub_btn, Color(0.14, 0.18, 0.26, 0.94), Color(0.48, 0.74, 0.96, 0.88), false, 7)
	copy_pub_btn.pressed.connect(func():
		play_click_sfx.emit()
		_copy_and_toast(_pub_copy_str, "Public IP")
	)
	share_hb.add_child(copy_pub_btn)

	# 4. Split Content: Left = 3-Tab Loadout / Vault / Recent Opponents, Right = 4-Seat Table & Chat & Start
	var body_hb := HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 16)
	root_vb.add_child(body_hb)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.15
	left_col.add_theme_constant_override("separation", 8)
	body_hb.add_child(left_col)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	left_col.add_child(tab_bar)

	var tab_defs := [
		"⚔ Duelist & Deck",
		"🏛 Campaign Vault",
		"📜 Recent & Rematch",
	]
	_tab_btns.clear()
	_tab_containers.clear()
	for ti in range(tab_defs.size()):
		var tb := Button.new()
		tb.text = tab_defs[ti]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 36)
		tb.toggle_mode = true
		var tab_idx := ti
		tb.pressed.connect(func():
			play_click_sfx.emit()
			_switch_tab(tab_idx)
		)
		_tab_btns.append(tb)
		tab_bar.add_child(tb)
		if ti == 2:
			_recent_tab_btn = tb

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(left_scroll)

	var tabs_host := VBoxContainer.new()
	tabs_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(tabs_host)

	# --- TAB 0: Duelist & Deck ---
	var tab0 := VBoxContainer.new()
	tab0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab0.add_theme_constant_override("separation", 9)
	tabs_host.add_child(tab0)
	_tab_containers.append(tab0)
	_build_duelist_deck_tab(tab0)

	# --- TAB 1: Campaign Vault ---
	var tab1 := VBoxContainer.new()
	tab1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab1.add_theme_constant_override("separation", 8)
	tabs_host.add_child(tab1)
	_tab_containers.append(tab1)
	_build_vault_section(tab1)

	# --- TAB 2: Recent Opponents & Quick Rematch ---
	var tab2 := VBoxContainer.new()
	tab2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab2.add_theme_constant_override("separation", 8)
	tabs_host.add_child(tab2)
	_tab_containers.append(tab2)
	recent_list_vb = VBoxContainer.new()
	recent_list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent_list_vb.add_theme_constant_override("separation", 8)
	tab2.add_child(recent_list_vb)

	# --- RIGHT COLUMN: 4-Seat Table Roster, Rules, Atmosphere, Chat & Launch ---
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.size_flags_stretch_ratio = 0.95
	right_vb.add_theme_constant_override("separation", 8)
	body_hb.add_child(right_vb)

	var settings_hb := HBoxContainer.new()
	settings_hb.add_theme_constant_override("separation", 8)
	right_vb.add_child(settings_hb)

	rule_btn = Button.new()
	rule_btn.text = "Ruleset: 🏛 Campaign Vault"
	rule_btn.clip_text = true
	rule_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_btn.custom_minimum_size = Vector2(0, 36)
	_style_tavern_btn(rule_btn, Color(0.16, 0.12, 0.08, 0.94), Color(0.78, 0.60, 0.26, 0.88), false, 8)
	rule_btn.pressed.connect(func():
		if mp_net == null or not mp_net.is_host:
			return
		play_click_sfx.emit()
		var cur := str(mp_net.room_settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
		var nxt := Config.RULE_BALANCED_ARENA if cur == Config.RULE_CAMPAIGN_VAULT else Config.RULE_CAMPAIGN_VAULT
		mp_net.set_rule_mode(nxt)
	)
	settings_hb.add_child(rule_btn)

	vista_btn = Button.new()
	vista_btn.text = "🌕 Full Moon Tavern"
	vista_btn.clip_text = true
	vista_btn.custom_minimum_size = Vector2(185, 36)
	_style_tavern_btn(vista_btn, Color(0.12, 0.13, 0.18, 0.94), Color(0.56, 0.68, 0.88, 0.86), false, 8)
	vista_btn.pressed.connect(_cycle_vista_era)
	settings_hb.add_child(vista_btn)

	var r_title := Label.new()
	r_title.text = "TAVERN ROUND TABLE (2–4 SEATS)"
	_apply_font(r_title, true)
	r_title.add_theme_font_size_override("font_size", 15)
	r_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	right_vb.add_child(r_title)

	seats_box = VBoxContainer.new()
	seats_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seats_box.add_theme_constant_override("separation", 7)
	right_vb.add_child(seats_box)

	# Quick Lobby Chat / Emotes Strip (visible while in session)
	chat_panel = PanelContainer.new()
	chat_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.06, 0.048, 0.036, 0.92), Color(0.54, 0.42, 0.24, 0.72), 1, 9, 8))
	chat_panel.visible = false
	right_vb.add_child(chat_panel)
	var chat_vb := VBoxContainer.new()
	chat_vb.add_theme_constant_override("separation", 5)
	chat_panel.add_child(chat_vb)
	chat_rtl = RichTextLabel.new()
	chat_rtl.bbcode_enabled = true
	chat_rtl.scroll_following = true
	chat_rtl.custom_minimum_size = Vector2(0, 52)
	chat_rtl.add_theme_font_size_override("normal_font_size", 12)
	chat_rtl.add_theme_color_override("default_color", Color(0.92, 0.86, 0.74))
	chat_vb.add_child(chat_rtl)
	var em_hb := HBoxContainer.new()
	em_hb.add_theme_constant_override("separation", 6)
	chat_vb.add_child(em_hb)
	for em_txt in ["⚔ Ready!", "🔥 Rematch!", "🍻 GL HF!", "⏳ Wait 1m"]:
		var eb := Button.new()
		eb.text = em_txt
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eb.custom_minimum_size = Vector2(0, 26)
		eb.add_theme_font_size_override("font_size", 11)
		_style_tavern_btn(eb, Color(0.14, 0.11, 0.08, 0.92), Color(0.58, 0.46, 0.26, 0.78), false, 6, false)
		var msg_send: String = em_txt
		eb.pressed.connect(func():
			play_click_sfx.emit()
			if mp_net != null and mp_net.has_method("send_lobby_chat"):
				mp_net.send_lobby_chat(msg_send)
		)
		em_hb.add_child(eb)
	var chat_in_hb := HBoxContainer.new()
	chat_in_hb.add_theme_constant_override("separation", 6)
	chat_vb.add_child(chat_in_hb)
	chat_input = LineEdit.new()
	chat_input.max_length = 140
	chat_input.placeholder_text = "Napiš zprávu... [Enter]" if _lang == "cs" else "Type a message... [Enter]"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 30)
	chat_input.add_theme_font_size_override("font_size", 12)
	_style_tavern_input(chat_input)
	chat_input.text_submitted.connect(func(_t: String): _send_chat_message())
	chat_in_hb.add_child(chat_input)
	chat_send_btn = Button.new()
	chat_send_btn.text = "Odeslat" if _lang == "cs" else "Send"
	chat_send_btn.custom_minimum_size = Vector2(74, 30)
	chat_send_btn.add_theme_font_size_override("font_size", 12)
	_style_tavern_btn(chat_send_btn, Color(0.18, 0.14, 0.09, 0.95), Color(0.76, 0.58, 0.28, 0.86), false, 6, false)
	chat_send_btn.pressed.connect(func():
		play_click_sfx.emit()
		_send_chat_message()
	)
	chat_in_hb.add_child(chat_send_btn)

	var bot_hb := HBoxContainer.new()
	bot_hb.add_theme_constant_override("separation", 10)
	right_vb.add_child(bot_hb)

	add_bot_btn = Button.new()
	add_bot_btn.text = "🤖 +Add Bot"
	add_bot_btn.custom_minimum_size = Vector2(138, 44)
	_style_tavern_btn(add_bot_btn, Color(0.16, 0.13, 0.10, 0.96), Color(0.68, 0.54, 0.30, 0.88), false, 9)
	add_bot_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net:
			mp_net.add_test_bot()
	)
	bot_hb.add_child(add_bot_btn)

	ready_btn = Button.new()
	ready_btn.text = "✓ READY"
	ready_btn.custom_minimum_size = Vector2(140, 44)
	_style_tavern_btn(ready_btn, Color(0.14, 0.22, 0.14, 0.96), Color(0.54, 0.82, 0.48, 0.90), true, 9)
	ready_btn.pressed.connect(func():
		play_click_sfx.emit()
		_local_ready = not _local_ready
		if mp_net:
			mp_net.toggle_ready(_local_ready)
	)
	bot_hb.add_child(ready_btn)

	start_btn = Button.new()
	start_btn.text = "⚔ START TAVERN BRAWL!"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.custom_minimum_size = Vector2(200, 44)
	_style_tavern_btn(start_btn, Color(0.34, 0.16, 0.08, 0.98), Color(0.98, 0.76, 0.26, 0.96), true, 9)
	start_btn.pressed.connect(func():
		play_click_sfx.emit()
		_persist_ui_prefs()
		if mp_net:
			mp_net.start_match()
	)
	bot_hb.add_child(start_btn)

	# Floating Toast Overlay
	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5; _toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 1.0; _toast_panel.anchor_bottom = 1.0
	_toast_panel.offset_left = -210; _toast_panel.offset_right = 210
	_toast_panel.offset_top = -62; _toast_panel.offset_bottom = -22
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.10, 0.16, 0.11, 0.96), Color(0.56, 0.92, 0.64, 0.94), 2, 10, 10))
	add_child(_toast_panel)
	_toast_lbl = Label.new()
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_toast_lbl, true)
	_toast_lbl.add_theme_font_size_override("font_size", 14)
	_toast_lbl.add_theme_color_override("font_color", Color(0.92, 1.0, 0.88))
	_toast_panel.add_child(_toast_lbl)

	_switch_tab(0)
	_render_4_seats([], {})


func _load_char_bust_glb(glb_path: String) -> Node3D:
	if glb_path.is_empty():
		return null
	if ResourceLoader.exists(glb_path):
		var ps := ResourceLoader.load(glb_path) as PackedScene
		if ps != null:
			var inst := ps.instantiate()
			if inst is Node3D:
				return inst as Node3D
	var abs_p := ProjectSettings.globalize_path(glb_path)
	if FileAccess.file_exists(abs_p):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(abs_p, state) == OK:
			var gen := doc.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
	return null


func _build_char_bust_portrait(ch: Dictionary, back_tex: Texture2D, idx: int) -> Control:
	var ch_accent: Color = ch.get("col", Color(0.95, 0.78, 0.30))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(88, 88)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_sb := _make_tavern_panel_sb(Color(0.04, 0.032, 0.026, 0.90), Color(ch_accent.r, ch_accent.g, ch_accent.b, 0.55), 1, 8, 2)
	frame.add_theme_stylebox_override("panel", frame_sb)
	cc.add_child(frame)

	if DisplayServer.get_name() != "headless":
		var bust := _load_char_bust_glb(str(ch.get("glb", "")))
		if bust != null:
			var svpc := SubViewportContainer.new()
			svpc.custom_minimum_size = Vector2(84, 84)
			svpc.stretch = true
			svpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(svpc)

			var svp := SubViewport.new()
			svp.size = Vector2i(84, 84)
			svp.own_world_3d = true
			svp.transparent_bg = true
			svp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
			svpc.add_child(svp)

			var env := Environment.new()
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.28, 0.24, 0.20)
			env.ambient_light_energy = 0.65
			var we := WorldEnvironment.new()
			we.environment = env
			svp.add_child(we)

			var key_light := DirectionalLight3D.new()
			key_light.light_color = Color(1.0, 0.84, 0.60)
			key_light.light_energy = 1.65
			key_light.rotation_degrees = Vector3(-28.0, 32.0, 0.0)
			svp.add_child(key_light)

			var rim_light := DirectionalLight3D.new()
			rim_light.light_color = ch_accent
			rim_light.light_energy = 2.1
			rim_light.rotation_degrees = Vector3(18.0, -142.0, 0.0)
			svp.add_child(rim_light)

			var cam := Camera3D.new()
			cam.fov = 30.0
			cam.current = true
			cam.look_at_from_position(Vector3(0.0, 0.45, 0.76), Vector3(0.0, 0.41, 0.0), Vector3.UP)
			svp.add_child(cam)

			var pivot := Node3D.new()
			pivot.add_child(bust)
			svp.add_child(pivot)
			_char_portrait_pivots.append({"node": pivot, "phase": float(idx) * 1.35})
			return cc

	# Crisp styled emblem fallback (headless mode or missing GLB)
	var fb_center := CenterContainer.new()
	fb_center.custom_minimum_size = Vector2(84, 84)
	fb_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(fb_center)
	if back_tex != null:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(68, 68)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = back_tex
		tr.modulate = Color(1.0, 1.0, 1.0, 0.90)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb_center.add_child(tr)
	else:
		var glyph_lbl := Label.new()
		var raw_name := str(ch.get("name", "?"))
		glyph_lbl.text = raw_name.substr(0, 1)
		glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_apply_font(glyph_lbl, true)
		glyph_lbl.add_theme_font_size_override("font_size", 32)
		glyph_lbl.add_theme_color_override("font_color", ch_accent)
		glyph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb_center.add_child(glyph_lbl)
	return cc


func _build_duelist_deck_tab(parent_vb: VBoxContainer) -> void:
	var c_title := Label.new()
	c_title.text = "CHOOSE YOUR 3D CHARACTER & CARD BACK"
	_apply_font(c_title, true)
	c_title.add_theme_font_size_override("font_size", 15)
	c_title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.54))
	parent_vb.add_child(c_title)

	var char_back_map := {
		"CHAR_GUILLOTINE": "res://assets/table/deck_back_obsidian.png",
		"CHAR_MONARCH": "res://assets/table/deck_back_stredovek.png",
		"CHAR_JESTER": "res://assets/table/deck_back_prohibicia.png",
		"CHAR_MISTBLADE": "res://assets/table/deck_back_astral.png",
	}

	var char_hb := HBoxContainer.new()
	char_hb.add_theme_constant_override("separation", 8)
	parent_vb.add_child(char_hb)
	_char_portrait_pivots.clear()
	for ch_idx in range(Config.CHARACTERS.size()):
		var ch: Dictionary = Config.CHARACTERS[ch_idx]
		var cid := str(ch["id"])
		var ch_accent: Color = ch.get("col", Color(0.95, 0.78, 0.30))
		var cb := Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 126)
		cb.text = ""
		cb.tooltip_text = str(ch["desc"])
		cb.toggle_mode = true
		var btex := Toon.tex(str(char_back_map.get(cid, "res://assets/table/card_back.png")))
		var card_vb := VBoxContainer.new()
		card_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_vb.offset_left = 6; card_vb.offset_right = -6
		card_vb.offset_top = 6; card_vb.offset_bottom = -6
		card_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vb.add_theme_constant_override("separation", 4)
		card_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cb.add_child(card_vb)
		var portrait_ctrl := _build_char_bust_portrait(ch, btex, ch_idx)
		card_vb.add_child(portrait_ctrl)
		var cname_lbl := Label.new()
		cname_lbl.text = str(ch.get("name_cs" if _lang == "cs" else "name", ch["name"]))
		cname_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cname_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_apply_font(cname_lbl, true)
		cname_lbl.add_theme_font_size_override("font_size", 12)
		cname_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
		cname_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vb.add_child(cname_lbl)
		cb.pressed.connect(func():
			play_click_sfx.emit()
			_select_character(cid)
		)
		_apply_choice_btn_style(cb, cid == selected_char_id, ch_accent)
		_attach_hover_anim(cb)
		char_buttons[cid] = cb
		char_hb.add_child(cb)

	var d_title := Label.new()
	d_title.text = "YOUR PERSONAL DECK ARCHETYPE"
	_apply_font(d_title, true)
	d_title.add_theme_font_size_override("font_size", 15)
	d_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	parent_vb.add_child(d_title)

	for arch in Config.DECK_ARCHETYPES:
		var aid := str(arch["id"])
		var ab := Button.new()
		ab.custom_minimum_size = Vector2(0, 42)
		ab.text = "%s — %s" % [arch["name"], arch["desc"]]
		ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ab.toggle_mode = true
		ab.pressed.connect(func():
			play_click_sfx.emit()
			_select_archetype(aid)
		)
		_apply_choice_btn_style(ab, aid == selected_arch_id, arch.get("col", Color(0.95, 0.78, 0.30)))
		_attach_hover_anim(ab)
		arch_buttons[aid] = ab
		parent_vb.add_child(ab)

	var aces_hb := HBoxContainer.new()
	aces_hb.add_theme_constant_override("separation", 10)
	parent_vb.add_child(aces_hb)
	aces_lbl = Label.new()
	_apply_font(aces_lbl, false)
	aces_lbl.add_theme_color_override("font_color", Color(0.94, 0.86, 0.68))
	aces_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aces_hb.add_child(aces_lbl)
	_ace_pips_lbl = Label.new()
	_apply_font(_ace_pips_lbl, true)
	_ace_pips_lbl.add_theme_font_size_override("font_size", 16)
	_ace_pips_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	aces_hb.add_child(_ace_pips_lbl)
	var minus_e := Button.new(); minus_e.text = " - "; minus_e.custom_minimum_size = Vector2(40, 34)
	_style_tavern_btn(minus_e, Color(0.18, 0.13, 0.09, 0.94), Color(0.66, 0.52, 0.28, 0.82), true, 8)
	minus_e.pressed.connect(func():
		play_click_sfx.emit()
		extra_aces_val = maxi(0, extra_aces_val - 1)
		_push_deck_update()
	)
	aces_hb.add_child(minus_e)
	var plus_e := Button.new(); plus_e.text = " + "; plus_e.custom_minimum_size = Vector2(40, 34)
	_style_tavern_btn(plus_e, Color(0.18, 0.13, 0.09, 0.94), Color(0.66, 0.52, 0.28, 0.82), true, 8)
	plus_e.pressed.connect(func():
		play_click_sfx.emit()
		extra_aces_val = mini(6, extra_aces_val + 1)
		_push_deck_update()
	)
	aces_hb.add_child(plus_e)

	var sum_pan := PanelContainer.new()
	sum_pan.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.06, 0.05, 0.038, 0.88), Color(0.56, 0.42, 0.20, 0.68), 1, 9, 10))
	parent_vb.add_child(sum_pan)
	deck_desc_lbl = Label.new()
	deck_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(deck_desc_lbl, false)
	deck_desc_lbl.add_theme_font_size_override("font_size", 13)
	deck_desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	sum_pan.add_child(deck_desc_lbl)


func _switch_tab(idx: int) -> void:
	_active_tab = idx
	for i in range(_tab_btns.size()):
		var is_sel := (i == idx)
		_tab_btns[i].set_pressed_no_signal(is_sel)
		_apply_choice_btn_style(_tab_btns[i], is_sel, Color(0.98, 0.78, 0.28))
		if i < _tab_containers.size():
			_tab_containers[i].visible = is_sel
			if is_sel and is_inside_tree():
				_tab_containers[i].modulate.a = 0.0
				var tw := _tab_containers[i].create_tween()
				tw.tween_property(_tab_containers[i], "modulate:a", 1.0, 0.18)


func _play_entrance_anim() -> void:
	if not is_inside_tree() or not is_instance_valid(_main_panel):
		return
	_main_panel.modulate.a = 0.0
	_main_panel.position.y += 18.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_main_panel, "modulate:a", 1.0, 0.24).set_ease(Tween.EASE_OUT)
	tw.tween_property(_main_panel, "position:y", _main_panel.position.y - 18.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_toast(msg: String, is_err: bool = false) -> void:
	if not is_instance_valid(_toast_panel) or not is_instance_valid(_toast_lbl):
		return
	_toast_lbl.text = msg
	var bg := Color(0.24, 0.09, 0.08, 0.96) if is_err else Color(0.10, 0.18, 0.12, 0.96)
	var bd := Color(0.95, 0.42, 0.36, 0.94) if is_err else Color(0.54, 0.92, 0.64, 0.94)
	_toast_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(bg, bd, 2, 10, 10))
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	if is_inside_tree():
		if is_instance_valid(_toast_tween) and _toast_tween.is_valid():
			_toast_tween.kill()
		_toast_tween = create_tween()
		_toast_tween.tween_interval(2.0)
		_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
		_toast_tween.tween_callback(func():
			if is_instance_valid(_toast_panel):
				_toast_panel.visible = false
		)


func _copy_and_toast(addr: String, label: String) -> void:
	if addr.is_empty():
		return
	DisplayServer.clipboard_set(addr)
	_show_toast("Copied %s: %s" % [label, addr], false)
	_on_status_changed("Copied %s (%s) to clipboard!" % [label, addr], false)


func _apply_saved_prefs() -> void:
	var saved_name := str(_prefs.get("player_name", "")).strip_edges()
	if not saved_name.is_empty() and is_instance_valid(name_edit):
		name_edit.text = saved_name
	var saved_ip := str(_prefs.get("last_ip", "")).strip_edges()
	if not saved_ip.is_empty() and is_instance_valid(ip_edit):
		ip_edit.text = saved_ip
	var saved_port := int(_prefs.get("last_port", Config.DEFAULT_PORT))
	if saved_port >= 1024 and is_instance_valid(port_edit):
		port_edit.text = str(saved_port)
	var saved_arch := str(_prefs.get("last_archetype_id", "GUILLOTINE_ACES"))
	if not arch_buttons.has(saved_arch):
		saved_arch = "GUILLOTINE_ACES"
	_select_archetype(saved_arch)
	var saved_char := str(_prefs.get("last_character_id", ""))
	if not saved_char.is_empty() and char_buttons.has(saved_char):
		_select_character(saved_char)
	extra_aces_val = clampi(int(_prefs.get("last_extra_aces", extra_aces_val)), 0, 6)
	_selected_vista_era = str(_prefs.get("last_vista_era", "stredovek"))
	_update_vista_btn_label()
	_push_deck_update()


func _persist_ui_prefs() -> void:
	History.save_prefs({
		"player_name": name_edit.text.strip_edges() if is_instance_valid(name_edit) else "",
		"last_ip": ip_edit.text.strip_edges() if is_instance_valid(ip_edit) else "127.0.0.1",
		"last_port": maxi(1024, port_edit.text.to_int()) if is_instance_valid(port_edit) else Config.DEFAULT_PORT,
		"last_character_id": selected_char_id,
		"last_archetype_id": selected_arch_id,
		"last_extra_aces": extra_aces_val,
		"last_vista_era": _selected_vista_era,
	})


func _cycle_vista_era() -> void:
	if mp_net != null and mp_net.in_session and not mp_net.is_host:
		return
	play_click_sfx.emit()
	var idx := 0
	for i in range(Config.VISTA_ERAS.size()):
		if str(Config.VISTA_ERAS[i]["id"]) == _selected_vista_era:
			idx = i
			break
	idx = (idx + 1) % Config.VISTA_ERAS.size()
	_selected_vista_era = str(Config.VISTA_ERAS[idx]["id"])
	_update_vista_btn_label()
	_persist_ui_prefs()
	if mp_net != null and mp_net.in_session and mp_net.is_host:
		mp_net.set_vista_era(_selected_vista_era)


func _update_vista_btn_label() -> void:
	if not is_instance_valid(vista_btn):
		return
	for ve in Config.VISTA_ERAS:
		if str(ve["id"]) == _selected_vista_era:
			vista_btn.text = str(ve.get("name_cs" if _lang == "cs" else "name", _selected_vista_era))
			return


func _refresh_recent_list() -> void:
	if not is_instance_valid(recent_list_vb):
		return
	for c in recent_list_vb.get_children():
		c.queue_free()
	var recents := History.get_recent_players()
	if is_instance_valid(_recent_tab_btn):
		_recent_tab_btn.text = "📜 Recent (%d)" % recents.size() if not recents.is_empty() else "📜 Recent & Rematch"
	if recents.is_empty():
		var emp := PanelContainer.new()
		emp.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.07, 0.055, 0.04, 0.85), Color(0.45, 0.36, 0.22, 0.50), 1, 10, 16))
		recent_list_vb.add_child(emp)
		var elbl := Label.new()
		elbl.text = "No recent matches yet.\nFinish a match against a friend and they'll appear here for 1-click Quick Rematch!"
		elbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_font(elbl, false)
		elbl.add_theme_color_override("font_color", Color(0.76, 0.70, 0.60))
		emp.add_child(elbl)
		return

	for raw_r in recents:
		if not (raw_r is Dictionary):
			continue
		var r := raw_r as Dictionary
		var r_name := str(r.get("name", "Player"))
		var r_ip := str(r.get("ip", "")).strip_edges()
		var r_port := int(r.get("port", Config.DEFAULT_PORT))
		var r_w := int(r.get("wins", 0))
		var r_l := int(r.get("losses", 0))
		var r_date := str(r.get("last_played_str", ""))
		var r_char := str(r.get("last_character", "CHAR_GUILLOTINE"))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.11, 0.08, 0.055, 0.94), Color(0.74, 0.56, 0.24, 0.82), 2, 10, 10))
		recent_list_vb.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info_vb)
		var top_l := Label.new()
		var char_name := str(Config.get_character(r_char).get("name", "Duelist"))
		top_l.text = "%s  •  🏆 %dW – %dL  •  %s" % [r_name, r_w, r_l, char_name]
		_apply_font(top_l, true)
		top_l.add_theme_font_size_override("font_size", 14)
		top_l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
		info_vb.add_child(top_l)

		var sub_l := Label.new()
		var addr_txt := ("%s:%d" % [r_ip, r_port]) if not r_ip.is_empty() else "Joined your table"
		sub_l.text = "%s  •  Last played: %s" % [addr_txt, r_date]
		_apply_font(sub_l, false)
		sub_l.add_theme_font_size_override("font_size", 12)
		sub_l.add_theme_color_override("font_color", Color(0.78, 0.74, 0.64))
		info_vb.add_child(sub_l)

		var rem_btn := Button.new()
		rem_btn.text = "⚔ Quick Rematch" if not r_ip.is_empty() else "🔥 Host Rematch"
		rem_btn.custom_minimum_size = Vector2(142, 34)
		_style_tavern_btn(rem_btn, Color(0.20, 0.28, 0.14, 0.96), Color(0.62, 0.92, 0.46, 0.92), true, 8)
		rem_btn.pressed.connect(func():
			play_click_sfx.emit()
			if not r_ip.is_empty():
				ip_edit.text = r_ip
				port_edit.text = str(r_port)
				_on_join_pressed()
			else:
				_on_host_pressed()
				var copy_ip := _vpn_copy_str if not _vpn_copy_str.is_empty() else _lan_copy_str
				if not copy_ip.is_empty():
					DisplayServer.clipboard_set(copy_ip)
					_show_toast("Table hosted! Share IP copied for rematch with %s!" % r_name, false)
		)
		hb.add_child(rem_btn)

		if not r_ip.is_empty():
			var cbtn := Button.new()
			cbtn.text = "📋"
			cbtn.tooltip_text = "Copy %s:%d" % [r_ip, r_port]
			cbtn.custom_minimum_size = Vector2(36, 34)
			_style_tavern_btn(cbtn, Color(0.14, 0.18, 0.16, 0.94), Color(0.52, 0.76, 0.62, 0.85), false, 8)
			cbtn.pressed.connect(func():
				play_click_sfx.emit()
				_copy_and_toast("%s:%d" % [r_ip, r_port], r_name)
			)
			hb.add_child(cbtn)

		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.tooltip_text = "Remove from recent"
		del_btn.custom_minimum_size = Vector2(34, 34)
		_style_tavern_btn(del_btn, Color(0.22, 0.10, 0.09, 0.92), Color(0.72, 0.34, 0.28, 0.80), false, 8)
		del_btn.pressed.connect(func():
			play_click_sfx.emit()
			History.remove_opponent(r_name, r_ip)
			_refresh_recent_list()
		)
		hb.add_child(del_btn)


func _build_local_deck_cfg(arch_id: String) -> Dictionary:
	var b_combo: Array = _profile.get("bankai_combo", Catalog.get_deck_build(arch_id).get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]))
	return {
		"archetype_id": arch_id,
		"extra_aces": extra_aces_val,
		"character_id": selected_char_id,
		"power_cards": selected_power_cards.duplicate(),
		"table_relics": selected_table_relics.duplicate(),
		"passive_relics": selected_passive_relics.duplicate(),
		"bankai_combo": b_combo.duplicate(),
		"sword_skin": equipped_sword_id,
	}


func _load_vault_from_profile() -> void:
	_lang = str(Catalog.load_options().get("language", "en"))
	_profile = Catalog.load_profile()
	equipped_sword_id = str(_profile.get("equipped_sword", "SWORD_IRON"))
	var loadout: Dictionary = _profile.get("mp_loadout", {})
	selected_power_cards.clear()
	var mythic_cnt := 0
	for pv in loadout.get("power_cards", []):
		var pid := str(pv)
		if (pid in Catalog.ARCHIVED_CARD_IDS) or not Catalog.is_power_card_unlocked(_profile, pid):
			continue
		var pdata := Catalog.get_power_card(pid)
		if pdata.is_empty():
			continue
		if str(pdata.get("rarity", "")) == "Mythic":
			if mythic_cnt >= Config.MP_MAX_MYTHIC_POWER_CARDS:
				continue
			mythic_cnt += 1
		if not (pid in selected_power_cards):
			selected_power_cards.append(pid)
		if selected_power_cards.size() >= Config.MP_MAX_POWER_CARDS:
			break

	selected_table_relics.clear()
	for tv in loadout.get("table_relics", []):
		var tid := str(tv)
		if not Catalog.is_table_relic_unlocked(_profile, tid):
			continue
		if Catalog.get_table_relic(tid).is_empty():
			continue
		if not (tid in selected_table_relics):
			selected_table_relics.append(tid)
		if selected_table_relics.size() >= Config.MP_MAX_TABLE_RELICS:
			break

	selected_passive_relics.clear()
	for rv in loadout.get("passive_relics", []):
		var rid := str(rv)
		if (rid in Catalog.ARCHIVED_RELIC_IDS) or Catalog.is_relic_hidden(rid) or not Catalog.is_relic_unlocked(_profile, rid):
			continue
		if Catalog.get_relic(rid).is_empty():
			continue
		if not (rid in selected_passive_relics):
			selected_passive_relics.append(rid)
		if selected_passive_relics.size() >= Config.MP_MAX_PASSIVE_RELICS:
			break


func _save_vault_to_profile() -> void:
	_profile["mp_loadout"] = {
		"archetype_id": selected_arch_id,
		"power_cards": selected_power_cards.duplicate(),
		"table_relics": selected_table_relics.duplicate(),
		"passive_relics": selected_passive_relics.duplicate(),
		"bankai_combo": (_profile.get("bankai_combo", Catalog.get_deck_build(selected_arch_id).get("default_bankai", [])) as Array).duplicate(),
		"sword_skin": equipped_sword_id,
	}
	Catalog.save_profile(_profile)


func _style_vault_locked_btn(btn: Button) -> void:
	_apply_font(btn, false)
	var sb_d := _make_tavern_panel_sb(Color(0.06, 0.05, 0.045, 0.55), Color(0.28, 0.24, 0.18, 0.35), 1, 8, 8)
	sb_d.shadow_size = 2
	btn.add_theme_stylebox_override("normal", sb_d)
	btn.add_theme_stylebox_override("hover", sb_d)
	btn.add_theme_stylebox_override("pressed", sb_d)
	btn.add_theme_stylebox_override("disabled", sb_d)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_disabled_color", Color(0.46, 0.42, 0.36, 0.65))


func _build_vault_section(parent_vb: VBoxContainer) -> void:
	var vault_panel := PanelContainer.new()
	vault_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.07, 0.055, 0.04, 0.90), Color(0.62, 0.46, 0.22, 0.72), 2, 10, 12))
	parent_vb.add_child(vault_panel)

	vault_box = VBoxContainer.new()
	vault_box.add_theme_constant_override("separation", 8)
	vault_panel.add_child(vault_box)

	var hdr_hb := HBoxContainer.new()
	vault_box.add_child(hdr_hb)
	var v_title := Label.new()
	v_title.text = "CAMPAIGN VAULT LOADOUT"
	v_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(v_title, true)
	v_title.add_theme_font_size_override("font_size", 15)
	v_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	hdr_hb.add_child(v_title)

	var sw_icon := Toon.tex("res://assets/ui/blender/ui_wager_sword_3d.png")
	if sw_icon != null:
		var sw_tr := TextureRect.new()
		sw_tr.texture = sw_icon
		sw_tr.custom_minimum_size = Vector2(22, 22)
		sw_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr_hb.add_child(sw_tr)

	var sw_info := Catalog.get_sword_skin_loc(equipped_sword_id, _lang)
	vault_sword_lbl = Label.new()
	vault_sword_lbl.text = "Sword: %s" % str(sw_info.get("name", equipped_sword_id))
	_apply_font(vault_sword_lbl, false)
	vault_sword_lbl.add_theme_font_size_override("font_size", 13)
	vault_sword_lbl.add_theme_color_override("font_color", Color(0.76, 0.92, 1.0))
	hdr_hb.add_child(vault_sword_lbl)

	vault_power_hdr = Label.new()
	_apply_font(vault_power_hdr, false)
	vault_power_hdr.add_theme_font_size_override("font_size", 13)
	vault_power_hdr.add_theme_color_override("font_color", Color(0.95, 0.84, 0.56))
	vault_box.add_child(vault_power_hdr)

	var p_grid := GridContainer.new()
	p_grid.columns = 3
	p_grid.add_theme_constant_override("h_separation", 6)
	p_grid.add_theme_constant_override("v_separation", 6)
	vault_box.add_child(p_grid)
	vault_power_btns.clear()
	for pc in Catalog.POWER_CARDS:
		var pid := str(pc.get("id", ""))
		if pid == "" or (pid in Catalog.ARCHIVED_CARD_IDS):
			continue
		var pc_loc := Catalog.get_power_card_loc(pid, _lang)
		var unlocked := Catalog.is_power_card_unlocked(_profile, pid)
		var is_mythic := str(pc.get("rarity", "")) == "Mythic"
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		var ctex := Toon.tex("res://assets/cards/%s.png" % pid)
		if ctex != null:
			btn.icon = ctex
			btn.expand_icon = true
		var tag := " ★M" if is_mythic else ""
		if unlocked:
			btn.text = "%s%s" % [str(pc_loc.get("short", pc_loc.get("name", pid))), tag]
			btn.tooltip_text = "%s (%s)\n%s" % [str(pc_loc.get("name", pid)), str(pc_loc.get("rarity", "")), str(pc_loc.get("desc", ""))]
			btn.toggle_mode = true
			btn.set_pressed_no_signal(pid in selected_power_cards)
			btn.pressed.connect(func(): _toggle_vault_power(pid))
			_apply_choice_btn_style(btn, pid in selected_power_cards, pc.get("accent", Color(0.95, 0.78, 0.30)))
			_attach_hover_anim(btn)
		else:
			btn.text = "🔒 %s%s" % [str(pc_loc.get("short", pc_loc.get("name", pid))), tag]
			btn.tooltip_text = "Locked — %s\n%s" % [Catalog.get_unlock_source_label(pid, _lang), str(pc_loc.get("desc", ""))]
			btn.disabled = true
			_style_vault_locked_btn(btn)
		vault_power_btns[pid] = btn
		p_grid.add_child(btn)

	vault_trel_hdr = Label.new()
	_apply_font(vault_trel_hdr, false)
	vault_trel_hdr.add_theme_font_size_override("font_size", 13)
	vault_trel_hdr.add_theme_color_override("font_color", Color(0.95, 0.84, 0.56))
	vault_box.add_child(vault_trel_hdr)

	var t_grid := GridContainer.new()
	t_grid.columns = 3
	t_grid.add_theme_constant_override("h_separation", 6)
	t_grid.add_theme_constant_override("v_separation", 6)
	vault_box.add_child(t_grid)
	vault_trel_btns.clear()
	for tr_item in Catalog.TABLE_RELICS:
		var tid := str(tr_item.get("id", ""))
		if tid == "":
			continue
		var tr_loc := Catalog.get_table_relic_loc(tid, _lang)
		var unlocked := Catalog.is_table_relic_unlocked(_profile, tid)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		if unlocked:
			btn.text = str(tr_loc.get("name", tid))
			btn.tooltip_text = "%s\n%s" % [str(tr_loc.get("name", tid)), str(tr_loc.get("desc", ""))]
			btn.toggle_mode = true
			btn.set_pressed_no_signal(tid in selected_table_relics)
			btn.pressed.connect(func(): _toggle_vault_table_relic(tid))
			_apply_choice_btn_style(btn, tid in selected_table_relics, tr_item.get("col", Color(0.96, 0.78, 0.34)))
			_attach_hover_anim(btn)
		else:
			btn.text = "🔒 %s" % str(tr_loc.get("name", tid))
			btn.tooltip_text = "Locked — %s\n%s" % [Catalog.get_unlock_source_label(tid, _lang), str(tr_loc.get("desc", ""))]
			btn.disabled = true
			_style_vault_locked_btn(btn)
		vault_trel_btns[tid] = btn
		t_grid.add_child(btn)

	vault_prel_hdr = Label.new()
	_apply_font(vault_prel_hdr, false)
	vault_prel_hdr.add_theme_font_size_override("font_size", 13)
	vault_prel_hdr.add_theme_color_override("font_color", Color(0.95, 0.84, 0.56))
	vault_box.add_child(vault_prel_hdr)

	var r_grid := GridContainer.new()
	r_grid.columns = 3
	r_grid.add_theme_constant_override("h_separation", 6)
	r_grid.add_theme_constant_override("v_separation", 6)
	vault_box.add_child(r_grid)
	vault_prel_btns.clear()
	for rel in Catalog.get_visible_relics():
		var rid := str(rel.get("id", ""))
		if rid == "" or (rid in Catalog.ARCHIVED_RELIC_IDS):
			continue
		var rel_loc := Catalog.get_relic_loc(rid, _lang)
		var unlocked := Catalog.is_relic_unlocked(_profile, rid)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		if unlocked:
			btn.text = str(rel_loc.get("name", rid))
			btn.tooltip_text = "%s\n%s" % [str(rel_loc.get("name", rid)), str(rel_loc.get("desc", ""))]
			btn.toggle_mode = true
			btn.set_pressed_no_signal(rid in selected_passive_relics)
			btn.pressed.connect(func(): _toggle_vault_passive_relic(rid))
			_apply_choice_btn_style(btn, rid in selected_passive_relics, rel.get("col", Color(0.54, 0.86, 0.96)))
			_attach_hover_anim(btn)
		else:
			btn.text = "🔒 %s" % str(rel_loc.get("name", rid))
			btn.tooltip_text = "Locked — %s\n%s" % [Catalog.get_unlock_source_label(rid, _lang), str(rel_loc.get("desc", ""))]
			btn.disabled = true
			_style_vault_locked_btn(btn)
		vault_prel_btns[rid] = btn
		r_grid.add_child(btn)

	_refresh_vault_buttons()


func _toggle_vault_power(pid: String) -> void:
	play_click_sfx.emit()
	if pid in selected_power_cards:
		selected_power_cards.erase(pid)
	else:
		if selected_power_cards.size() >= Config.MP_MAX_POWER_CARDS:
			_on_status_changed("Max %d Power Cards allowed in Vault Loadout!" % Config.MP_MAX_POWER_CARDS, true)
			_refresh_vault_buttons()
			return
		var pdata := Catalog.get_power_card(pid)
		if str(pdata.get("rarity", "")) == "Mythic":
			var m_cnt := 0
			for sp in selected_power_cards:
				if str(Catalog.get_power_card(sp).get("rarity", "")) == "Mythic":
					m_cnt += 1
			if m_cnt >= Config.MP_MAX_MYTHIC_POWER_CARDS:
				_on_status_changed("Max %d Mythic Power Card allowed in Vault Loadout!" % Config.MP_MAX_MYTHIC_POWER_CARDS, true)
				_refresh_vault_buttons()
				return
		selected_power_cards.append(pid)
	_save_vault_to_profile()
	_refresh_vault_buttons()
	_push_deck_update()


func _toggle_vault_table_relic(tid: String) -> void:
	play_click_sfx.emit()
	if tid in selected_table_relics:
		selected_table_relics.erase(tid)
	else:
		if selected_table_relics.size() >= Config.MP_MAX_TABLE_RELICS:
			_on_status_changed("Max %d Tabletop Relics allowed in Vault Loadout!" % Config.MP_MAX_TABLE_RELICS, true)
			_refresh_vault_buttons()
			return
		selected_table_relics.append(tid)
	_save_vault_to_profile()
	_refresh_vault_buttons()
	_push_deck_update()


func _toggle_vault_passive_relic(rid: String) -> void:
	play_click_sfx.emit()
	if rid in selected_passive_relics:
		selected_passive_relics.erase(rid)
	else:
		if selected_passive_relics.size() >= Config.MP_MAX_PASSIVE_RELICS:
			_on_status_changed("Max %d Passive Relics allowed in Vault Loadout!" % Config.MP_MAX_PASSIVE_RELICS, true)
			_refresh_vault_buttons()
			return
		selected_passive_relics.append(rid)
	_save_vault_to_profile()
	_refresh_vault_buttons()
	_push_deck_update()


func _refresh_vault_buttons() -> void:
	var m_cnt := 0
	for sp in selected_power_cards:
		if str(Catalog.get_power_card(sp).get("rarity", "")) == "Mythic":
			m_cnt += 1
	if vault_power_hdr != null:
		vault_power_hdr.text = "⚡ Power Cards (%d/%d, Mythic %d/%d):" % [selected_power_cards.size(), Config.MP_MAX_POWER_CARDS, m_cnt, Config.MP_MAX_MYTHIC_POWER_CARDS]
	if vault_trel_hdr != null:
		vault_trel_hdr.text = "🏺 Tabletop Relics (%d/%d):" % [selected_table_relics.size(), Config.MP_MAX_TABLE_RELICS]
	if vault_prel_hdr != null:
		vault_prel_hdr.text = "🧿 Passive Relics (%d/%d):" % [selected_passive_relics.size(), Config.MP_MAX_PASSIVE_RELICS]

	for pid in vault_power_btns.keys():
		var btn: Button = vault_power_btns[pid]
		if not btn.disabled:
			var is_sel := str(pid) in selected_power_cards
			btn.set_pressed_no_signal(is_sel)
			_apply_choice_btn_style(btn, is_sel, Catalog.get_power_card(str(pid)).get("accent", Color(0.95, 0.78, 0.30)))

	for tid in vault_trel_btns.keys():
		var btn: Button = vault_trel_btns[tid]
		if not btn.disabled:
			var is_sel := str(tid) in selected_table_relics
			btn.set_pressed_no_signal(is_sel)
			_apply_choice_btn_style(btn, is_sel, Catalog.get_table_relic(str(tid)).get("col", Color(0.96, 0.78, 0.34)))

	for rid in vault_prel_btns.keys():
		var btn: Button = vault_prel_btns[rid]
		if not btn.disabled:
			var is_sel := str(rid) in selected_passive_relics
			btn.set_pressed_no_signal(is_sel)
			_apply_choice_btn_style(btn, is_sel, Catalog.get_relic(str(rid)).get("col", Color(0.54, 0.86, 0.96)))


func _select_character(char_id: String) -> void:
	selected_char_id = char_id
	for k in char_buttons.keys():
		var cid_k := str(k)
		var is_sel := (cid_k == char_id)
		char_buttons[k].set_pressed_no_signal(is_sel)
		var ch_info := Config.get_character(cid_k)
		_apply_choice_btn_style(char_buttons[k], is_sel, ch_info.get("col", Color(0.95, 0.78, 0.30)))
	_push_deck_update()


func _select_archetype(arch_id: String) -> void:
	selected_arch_id = arch_id
	for k in arch_buttons.keys():
		var aid_k := str(k)
		var is_sel := (aid_k == arch_id)
		arch_buttons[k].set_pressed_no_signal(is_sel)
		var a_info := Config.get_archetype(aid_k)
		_apply_choice_btn_style(arch_buttons[k], is_sel, a_info.get("col", Color(0.95, 0.78, 0.30)))
	var arch := Config.get_archetype(arch_id)
	var def_char := Config.get_character_for_archetype(arch_id)
	selected_char_id = str(def_char.get("id", "CHAR_GUILLOTINE"))
	for k in char_buttons.keys():
		var cid_k := str(k)
		var is_csel := (cid_k == selected_char_id)
		char_buttons[k].set_pressed_no_signal(is_csel)
		var ch_info := Config.get_character(cid_k)
		_apply_choice_btn_style(char_buttons[k], is_csel, ch_info.get("col", Color(0.95, 0.78, 0.30)))
	extra_aces_val = int(arch.get("extra_aces", 2))
	if mp_net != null:
		mp_net.local_deck_cfg = _build_local_deck_cfg(arch_id)
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(arch)


func _push_deck_update() -> void:
	if mp_net != null:
		mp_net.local_deck_cfg = _build_local_deck_cfg(selected_arch_id)
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(Config.get_archetype(selected_arch_id))


func _update_deck_summary(_arch: Dictionary) -> void:
	var total_aces := 4 + extra_aces_val
	aces_lbl.text = "Extra Aces (3× Aces = Instant Kill!): +%d (%d Total)" % [extra_aces_val, total_aces]
	if is_instance_valid(_ace_pips_lbl):
		var pips := ["♠", "♥", "♣", "●"]
		var s := ""
		for i in range(total_aces):
			s += pips[i % 4] + " "
		_ace_pips_lbl.text = s.strip_edges()
	var pnames_arr: PackedStringArray = []
	for pid in selected_power_cards:
		pnames_arr.append(str(Catalog.get_power_card_loc(pid, _lang).get("short", pid)))
	var tnames_arr: PackedStringArray = []
	for tid in selected_table_relics:
		tnames_arr.append(str(Catalog.get_table_relic_loc(tid, _lang).get("name", tid)))
	var rnames_arr: PackedStringArray = []
	for rid in selected_passive_relics:
		rnames_arr.append(str(Catalog.get_relic_loc(rid, _lang).get("name", rid)))
	var pnames := ", ".join(pnames_arr) if not pnames_arr.is_empty() else "None"
	var tnames := ", ".join(tnames_arr) if not tnames_arr.is_empty() else "None"
	var rnames := ", ".join(rnames_arr) if not rnames_arr.is_empty() else "None"
	deck_desc_lbl.text = "Powers: %s  |  Table Relics: %s  |  Passives: %s" % [pnames, tnames, rnames]


func _on_host_pressed() -> void:
	play_click_sfx.emit()
	_persist_ui_prefs()
	if mp_net == null:
		return
	var port := maxi(1024, int(port_edit.text.to_int()))
	mp_net.room_settings["vista_era"] = _selected_vista_era
	mp_net.host_room(port, name_edit.text, mp_net.local_deck_cfg)
	_local_ready = true
	_refresh_controls()


func _on_join_pressed() -> void:
	play_click_sfx.emit()
	_persist_ui_prefs()
	if mp_net == null:
		return
	var port := maxi(1024, int(port_edit.text.to_int()))
	mp_net.join_room(ip_edit.text, port, name_edit.text, mp_net.local_deck_cfg)
	_local_ready = false
	_refresh_controls()


func _format_seat_loadout_summary(dcfg: Dictionary) -> String:
	var p_arr: PackedStringArray = []
	for pv in dcfg.get("power_cards", []):
		var pid := str(pv)
		p_arr.append(str(Catalog.get_power_card_loc(pid, _lang).get("short", pid)))
	var t_arr: PackedStringArray = []
	for tv in dcfg.get("table_relics", []):
		var tid := str(tv)
		var info := Config.get_mp_item_info(tid, _lang)
		t_arr.append(str(info.get("name", tid)) if not info.is_empty() else tid)
	var r_arr: PackedStringArray = []
	for rv in dcfg.get("passive_relics", []):
		var rid := str(rv)
		r_arr.append(str(Catalog.get_relic_loc(rid, _lang).get("name", rid)))
	var sw_id := str(dcfg.get("sword_skin", "SWORD_IRON"))
	var sw_name := str(Catalog.get_sword_skin_loc(sw_id, _lang).get("name", sw_id))
	var p_str := ", ".join(p_arr) if not p_arr.is_empty() else "None"
	var t_str := ", ".join(t_arr) if not t_arr.is_empty() else "None"
	var r_str := ", ".join(r_arr) if not r_arr.is_empty() else "None"
	return "⚔ %s  |  ⚡ %s  |  🏺 %s  |  🧿 %s" % [sw_name, p_str, t_str, r_str]


func _on_lobby_updated(seats: Array, settings: Dictionary) -> void:
	_render_4_seats(seats, settings)
	if settings.has("vista_era"):
		_selected_vista_era = str(settings["vista_era"])
		_update_vista_btn_label()
	var rm := str(settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	if rm == Config.RULE_BALANCED_ARENA:
		rule_btn.text = "Ruleset: ⚖ Balanced Arena (Fair Preset)"
	else:
		rule_btn.text = "Ruleset: 🏛 Campaign Vault (Unlocked)"
	if vault_box != null:
		vault_box.modulate = Color(0.62, 0.60, 0.56, 0.85) if rm == Config.RULE_BALANCED_ARENA else Color(1, 1, 1, 1)
	_refresh_controls()


func _render_4_seats(seats: Array, settings: Dictionary) -> void:
	if not is_instance_valid(seats_box):
		return
	for c in seats_box.get_children():
		c.queue_free()
	var rm := str(settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	var prev_cnt := _last_seat_count
	_last_seat_count = seats.size()

	for slot_i in range(Config.MAX_PLAYERS):
		if slot_i < seats.size():
			var s: Dictionary = seats[slot_i]
			var si := int(s["seat_idx"])
			var is_rdy := bool(s["ready"])
			var card := PanelContainer.new()
			var border_col := Color(0.46, 0.92, 0.54, 0.90) if is_rdy else Color(0.56, 0.42, 0.24, 0.72)
			card.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.12, 0.09, 0.065, 0.94), border_col, 2, 9, 9))
			var seat_vb := VBoxContainer.new()
			seat_vb.add_theme_constant_override("separation", 3)
			card.add_child(seat_vb)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			seat_vb.add_child(row)
			var raw_dcfg: Dictionary = s.get("deck_cfg", {})
			var eff_dcfg := Config.sanitize_deck_cfg(raw_dcfg, rm)
			var arch := Config.get_archetype(str(eff_dcfg.get("archetype_id", "GUILLOTINE_ACES")))
			var aces := 4 + int(eff_dcfg.get("extra_aces", 0))
			var lbl := Label.new()
			var kind := "HOST" if si == 0 else ("BOT" if bool(s["is_bot"]) else "PLAYER")
			var rdy := "✅ READY" if is_rdy else "⏳ WAIT"
			lbl.text = "Seat %d [%s]: %s  •  %s (%d Aces)  •  %s" % [si + 1, kind, str(s["name"]), str(arch["name"]), aces, rdy]
			_apply_font(lbl, false)
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.76) if is_rdy else Color(0.80, 0.74, 0.64))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)

			if mp_net != null and mp_net.is_host and si > 0:
				var kick := Button.new(); kick.text = "Kick"
				_style_tavern_btn(kick, Color(0.26, 0.11, 0.10, 0.94), Color(0.76, 0.36, 0.28, 0.85), false, 6, false)
				kick.pressed.connect(func(): mp_net.remove_seat(si))
				row.add_child(kick)

			var loadout_lbl := Label.new()
			loadout_lbl.text = _format_seat_loadout_summary(eff_dcfg)
			loadout_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_apply_font(loadout_lbl, false)
			loadout_lbl.add_theme_font_size_override("font_size", 11)
			loadout_lbl.add_theme_color_override("font_color", Color(0.76, 0.70, 0.58))
			seat_vb.add_child(loadout_lbl)
			seats_box.add_child(card)
			if slot_i >= prev_cnt and is_inside_tree():
				card.modulate.a = 0.0
				var tw := card.create_tween()
				tw.tween_property(card, "modulate:a", 1.0, 0.22)
		else:
			var empty_slot := PanelContainer.new()
			empty_slot.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.06, 0.048, 0.036, 0.58), Color(0.38, 0.30, 0.20, 0.38), 1, 9, 8))
			var el := Label.new()
			el.text = "Seat %d — 🪑 Empty Chair (Invite a friend or +Add Bot)" % (slot_i + 1)
			_apply_font(el, false)
			el.add_theme_font_size_override("font_size", 12)
			el.add_theme_color_override("font_color", Color(0.56, 0.52, 0.44, 0.78))
			empty_slot.add_child(el)
			seats_box.add_child(empty_slot)


func _send_chat_message() -> void:
	if not is_instance_valid(chat_input):
		return
	var txt := chat_input.text.strip_edges()
	if txt.is_empty():
		return
	if mp_net != null and bool(mp_net.get("in_session")) and mp_net.has_method("send_lobby_chat"):
		mp_net.send_lobby_chat(txt)
		chat_input.clear()


func _on_lobby_chat_received(sender_name: String, text: String) -> void:
	var safe_sender := sender_name.replace("[", "[lb]")
	var safe_text := text.replace("[", "[lb]")
	_chat_lines.append("[color=#ffd966]%s:[/color] %s" % [safe_sender, safe_text])
	if _chat_lines.size() > 30:
		_chat_lines.pop_front()
	if is_instance_valid(chat_rtl):
		chat_rtl.text = "\n".join(_chat_lines)


func _on_status_changed(msg: String, is_err: bool) -> void:
	status_lbl.text = msg
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.44, 0.38) if is_err else Color(0.74, 0.96, 0.80))
	if is_err:
		_show_toast(msg, true)
	_refresh_controls()


func _on_host_network_ready(info: Dictionary) -> void:
	_update_share_bar(info)


func _update_share_bar(info: Dictionary) -> void:
	if not is_instance_valid(share_lan_lbl):
		return
	var port := int(info.get("port", Config.DEFAULT_PORT))
	var vpn_ip := str(info.get("vpn_ip", ""))
	var lan_ip := str(info.get("lan_ip", "127.0.0.1"))
	var pub_ip := str(info.get("public_ip", ""))
	var upnp_ok := bool(info.get("upnp_ok", false))
	var upnp_pending := bool(info.get("upnp_pending", false))

	if not vpn_ip.is_empty():
		_vpn_copy_str = "%s:%d" % [vpn_ip, port]
		share_vpn_lbl.text = "🟢 VPN: %s" % _vpn_copy_str
		share_vpn_lbl.visible = true
		copy_vpn_btn.visible = true
	else:
		_vpn_copy_str = ""
		share_vpn_lbl.visible = false
		copy_vpn_btn.visible = false

	_lan_copy_str = "%s:%d" % [lan_ip, port]
	share_lan_lbl.text = "🏠 LAN: %s" % _lan_copy_str

	if upnp_ok and not pub_ip.is_empty():
		_pub_copy_str = "%s:%d" % [pub_ip, port]
		share_pub_lbl.text = "🌐 Public: %s" % _pub_copy_str
		copy_pub_btn.visible = true
	elif upnp_pending:
		_pub_copy_str = ""
		share_pub_lbl.text = "🌐 UPnP: Checking..."
		copy_pub_btn.visible = false
	else:
		_pub_copy_str = ""
		share_pub_lbl.text = "🌐 UPnP off (Use Radmin/Tailscale)" if not vpn_ip.is_empty() else ("🌐 No UPnP (Forward UDP %d or Radmin/Tailscale)" % port)
		copy_pub_btn.visible = false


func _refresh_controls() -> void:
	var in_s: bool = (mp_net != null and bool(mp_net.get("in_session")))
	var is_h: bool = (mp_net != null and bool(mp_net.get("is_host")))
	if is_instance_valid(_conn_dot_lbl):
		if not in_s:
			_conn_dot_lbl.text = "● Offline"
			_conn_dot_lbl.add_theme_color_override("font_color", Color(0.74, 0.70, 0.64))
		elif is_h:
			_conn_dot_lbl.text = "● Hosting Table"
			_conn_dot_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.62))
		else:
			_conn_dot_lbl.text = "● Connected"
			_conn_dot_lbl.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))

	host_btn.disabled = in_s
	join_btn.disabled = in_s
	leave_btn.visible = in_s
	leave_btn.disabled = not in_s
	if is_instance_valid(chat_panel):
		chat_panel.visible = in_s
	if share_bar != null:
		share_bar.visible = in_s and is_h
		if share_bar.visible and mp_net != null and mp_net.has_method("get_host_network_addresses"):
			_update_share_bar(mp_net.get_host_network_addresses())
	rule_btn.disabled = not (in_s and is_h)
	vista_btn.disabled = in_s and not is_h
	add_bot_btn.visible = in_s and is_h
	add_bot_btn.disabled = (mp_net.lobby_seats.size() >= Config.MAX_PLAYERS) if in_s else true
	ready_btn.visible = in_s and not is_h
	ready_btn.text = "Cancel Ready" if _local_ready else "✓ READY UP"
	start_btn.visible = in_s and is_h
	if in_s and is_h:
		var chk: Dictionary = mp_net.can_start_match()
		start_btn.disabled = not bool(chk["ok"])
		start_btn.tooltip_text = str(chk["reason"])
