class_name MpLobbyOverlay
extends Control

## Experimental Dev-Only 2-4 Player Multiplayer Lobby Overlay.
## Automatically opens only when MpConfig.is_test_mp_available() is true.

const Config = preload("res://scripts/mp/mp_config.gd")
const FONT_DISPLAY_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoBody.ttf"

signal close_requested
signal play_click_sfx

var mp_net: Node = null
var _font_display: Font = null
var _font_body: Font = null

var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var host_btn: Button
var join_btn: Button
var spawn_win_btn: Button
var leave_btn: Button

var status_lbl: Label
var arch_buttons: Dictionary = {}
var char_buttons: Dictionary = {}
var selected_char_id: String = "CHAR_GUILLOTINE"
var extra_aces_val: int = 4
var aces_lbl: Label
var deck_desc_lbl: Label
var rule_btn: Button

var seats_box: VBoxContainer
var add_bot_btn: Button
var ready_btn: Button
var start_btn: Button
var _local_ready: bool = true


func configure(network_node: Node) -> void:
	mp_net = network_node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_fonts()
	_build_ui()
	if mp_net != null:
		mp_net.lobby_updated.connect(_on_lobby_updated)
		mp_net.status_changed.connect(_on_status_changed)
		mp_net.session_closed.connect(func(_r: String): _refresh_controls())
	_refresh_controls()


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
	sb.content_margin_top = pad - 2
	sb.content_margin_bottom = pad - 2
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _style_tavern_btn(btn: Button, bg: Color, border: Color, is_display: bool = false, radius: int = 9) -> void:
	_apply_font(btn, is_display)
	var sb_n := _make_tavern_panel_sb(bg, border, 2, radius, 12)
	sb_n.content_margin_top = 7
	sb_n.content_margin_bottom = 8
	var sb_h := _make_tavern_panel_sb(bg.lightened(0.14), border.lightened(0.22), 2, radius, 12)
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
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.80))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.56))
	btn.add_theme_color_override("font_disabled_color", Color(0.52, 0.48, 0.42, 0.7))


func _style_tavern_input(le: LineEdit) -> void:
	_apply_font(le, false)
	var sb_n := _make_tavern_panel_sb(Color(0.05, 0.04, 0.035, 0.94), Color(0.50, 0.38, 0.22, 0.75), 1, 8, 10)
	sb_n.border_width_bottom = 2
	sb_n.shadow_size = 3
	var sb_f := _make_tavern_panel_sb(Color(0.08, 0.06, 0.045, 0.96), Color(0.95, 0.76, 0.32, 0.95), 2, 8, 10)
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
		var sb_sel := _make_tavern_panel_sb(Color(0.24, 0.17, 0.08, 0.96), glow_border, 3, 10, 12)
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
		var sb_unsel := _make_tavern_panel_sb(Color(0.06, 0.05, 0.045, 0.88), Color(0.46, 0.36, 0.24, 0.52), 1, 10, 12)
		sb_unsel.border_width_bottom = 1
		sb_unsel.shadow_size = 4
		var sb_unsel_h := _make_tavern_panel_sb(Color(0.11, 0.085, 0.065, 0.92), Color(0.72, 0.56, 0.32, 0.78), 2, 10, 12)
		sb_unsel_h.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", sb_unsel)
		btn.add_theme_stylebox_override("hover", sb_unsel_h)
		btn.add_theme_stylebox_override("pressed", sb_unsel_h)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
		btn.add_theme_color_override("font_hover_color", Color(0.95, 0.88, 0.72))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.56))


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.025, 0.02, 0.86)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.05; panel.anchor_right = 0.95
	panel.anchor_top = 0.06; panel.anchor_bottom = 0.94
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.09, 0.065, 0.048, 0.96), Color(0.72, 0.54, 0.24, 0.90), 3, 14, 18))
	add_child(panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	panel.add_child(root_vb)

	# Dev-only clear banner
	var warn_bar := PanelContainer.new()
	warn_bar.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.24, 0.12, 0.06, 0.96), Color(0.92, 0.68, 0.24, 0.92), 2, 10, 10))
	root_vb.add_child(warn_bar)

	var warn_hb := HBoxContainer.new()
	warn_bar.add_child(warn_hb)
	var warn_lbl := Label.new()
	warn_lbl.text = "  ⚗ EXPERIMENTAL TEST MULTIPLAYER (2–4 PLAYERS) — HIDDEN FROM RELEASE LAUNCH BUILDS  "
	warn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(warn_lbl, true)
	warn_lbl.add_theme_font_size_override("font_size", 15)
	warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	warn_hb.add_child(warn_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ Close Lobby"
	_style_tavern_btn(close_btn, Color(0.24, 0.10, 0.09, 0.95), Color(0.78, 0.36, 0.28, 0.85), false, 8)
	close_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net != null and mp_net.in_session:
			mp_net.leave_room(false)
		close_requested.emit()
	)
	warn_hb.add_child(close_btn)

	# Connection Bar
	var conn_hb := HBoxContainer.new()
	conn_hb.add_theme_constant_override("separation", 10)
	root_vb.add_child(conn_hb)

	var n_lbl := Label.new(); n_lbl.text = "Name:"
	_apply_font(n_lbl, false)
	n_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	conn_hb.add_child(n_lbl)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(120, 36)
	name_edit.text = "Duelist_%d" % (randi() % 90 + 10)
	_style_tavern_input(name_edit)
	conn_hb.add_child(name_edit)

	var ip_lbl := Label.new(); ip_lbl.text = "IP:"
	_apply_font(ip_lbl, false)
	ip_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	conn_hb.add_child(ip_lbl)
	ip_edit = LineEdit.new()
	ip_edit.custom_minimum_size = Vector2(110, 36)
	ip_edit.text = "127.0.0.1"
	_style_tavern_input(ip_edit)
	conn_hb.add_child(ip_edit)

	var p_lbl := Label.new(); p_lbl.text = "Port:"
	_apply_font(p_lbl, false)
	p_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	conn_hb.add_child(p_lbl)
	port_edit = LineEdit.new()
	port_edit.custom_minimum_size = Vector2(68, 36)
	port_edit.text = str(Config.DEFAULT_PORT)
	_style_tavern_input(port_edit)
	conn_hb.add_child(port_edit)

	host_btn = Button.new()
	host_btn.text = "🔥 HOST TABLE"
	host_btn.custom_minimum_size = Vector2(120, 36)
	_style_tavern_btn(host_btn, Color(0.30, 0.16, 0.08, 0.96), Color(0.92, 0.68, 0.24, 0.92), true, 8)
	host_btn.pressed.connect(_on_host_pressed)
	conn_hb.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "🔗 JOIN TABLE"
	join_btn.custom_minimum_size = Vector2(115, 36)
	_style_tavern_btn(join_btn, Color(0.14, 0.20, 0.18, 0.96), Color(0.56, 0.78, 0.62, 0.88), true, 8)
	join_btn.pressed.connect(_on_join_pressed)
	conn_hb.add_child(join_btn)

	spawn_win_btn = Button.new()
	spawn_win_btn.text = "🪟 +Spawn 2nd Window"
	spawn_win_btn.tooltip_text = "Launches another local Godot client into MP Test Lobby for quick localhost testing"
	spawn_win_btn.custom_minimum_size = Vector2(150, 36)
	_style_tavern_btn(spawn_win_btn, Color(0.16, 0.13, 0.10, 0.94), Color(0.62, 0.50, 0.30, 0.80), false, 8)
	spawn_win_btn.pressed.connect(func():
		play_click_sfx.emit()
		OS.create_instance(["--mp-test"])
		_on_status_changed("Launched 2nd test client window! Click JOIN TABLE there.", false)
	)
	conn_hb.add_child(spawn_win_btn)

	leave_btn = Button.new()
	leave_btn.text = "Disconnect"
	_style_tavern_btn(leave_btn, Color(0.22, 0.11, 0.10, 0.94), Color(0.74, 0.36, 0.30, 0.85), false, 8)
	leave_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net: mp_net.leave_room(true)
	)
	conn_hb.add_child(leave_btn)

	status_lbl = Label.new()
	status_lbl.text = "Pick your Personal Deck below, then Host Table (add Test Bots or invite up to 4 friends!)."
	_apply_font(status_lbl, false)
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	root_vb.add_child(status_lbl)

	# Split Content: Left = Personal Deck Builder, Right = 2-4P Seat Roster & Match Rules
	var body_hb := HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 18)
	root_vb.add_child(body_hb)

	# Left Column: Personal Custom Deck Builder
	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 10)
	body_hb.add_child(left_vb)

	var c_title := Label.new()
	c_title.text = "CHOOSE YOUR 3D CHARACTER (Visible around the Tavern Table)"
	_apply_font(c_title, true)
	c_title.add_theme_font_size_override("font_size", 15)
	c_title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.54))
	left_vb.add_child(c_title)

	var char_hb := HBoxContainer.new()
	char_hb.add_theme_constant_override("separation", 8)
	left_vb.add_child(char_hb)
	for ch in Config.CHARACTERS:
		var cid := str(ch["id"])
		var cb := Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 40)
		cb.text = str(ch["name"])
		cb.tooltip_text = str(ch["desc"])
		cb.toggle_mode = true
		cb.pressed.connect(func():
			play_click_sfx.emit()
			_select_character(cid)
		)
		_apply_choice_btn_style(cb, cid == "CHAR_GUILLOTINE", ch.get("col", Color(0.95, 0.78, 0.30)))
		char_buttons[cid] = cb
		char_hb.add_child(cb)

	var d_title := Label.new()
	d_title.text = "YOUR OWN PERSONAL DECK (Every player brings their own!)"
	_apply_font(d_title, true)
	d_title.add_theme_font_size_override("font_size", 16)
	d_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	left_vb.add_child(d_title)

	for arch in Config.DECK_ARCHETYPES:
		var aid := str(arch["id"])
		var ab := Button.new()
		ab.custom_minimum_size = Vector2(0, 44)
		ab.text = "%s — %s" % [arch["name"], arch["desc"]]
		ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ab.toggle_mode = true
		ab.pressed.connect(func():
			play_click_sfx.emit()
			_select_archetype(aid)
		)
		_apply_choice_btn_style(ab, aid == "GUILLOTINE_ACES", arch.get("col", Color(0.95, 0.78, 0.30)))
		arch_buttons[aid] = ab
		left_vb.add_child(ab)

	var aces_hb := HBoxContainer.new()
	aces_hb.add_theme_constant_override("separation", 10)
	left_vb.add_child(aces_hb)
	aces_lbl = Label.new()
	aces_lbl.text = "Extra Aces in Your Deck (3× Aces = Instant Kill on Chosen Target!): +4 (8 Total)"
	_apply_font(aces_lbl, false)
	aces_lbl.add_theme_color_override("font_color", Color(0.94, 0.86, 0.68))
	aces_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aces_hb.add_child(aces_lbl)
	var minus_e := Button.new(); minus_e.text = " - "; minus_e.custom_minimum_size = Vector2(40, 34)
	_style_tavern_btn(minus_e, Color(0.18, 0.13, 0.09, 0.94), Color(0.66, 0.52, 0.28, 0.82), true, 8)
	minus_e.pressed.connect(func():
		extra_aces_val = maxi(0, extra_aces_val - 1)
		_push_deck_update()
	)
	aces_hb.add_child(minus_e)
	var plus_e := Button.new(); plus_e.text = " + "; plus_e.custom_minimum_size = Vector2(40, 34)
	_style_tavern_btn(plus_e, Color(0.18, 0.13, 0.09, 0.94), Color(0.66, 0.52, 0.28, 0.82), true, 8)
	plus_e.pressed.connect(func():
		extra_aces_val = mini(6, extra_aces_val + 1)
		_push_deck_update()
	)
	aces_hb.add_child(plus_e)

	deck_desc_lbl = Label.new()
	deck_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(deck_desc_lbl, false)
	deck_desc_lbl.add_theme_font_size_override("font_size", 13)
	deck_desc_lbl.add_theme_color_override("font_color", Color(0.84, 0.78, 0.66))
	left_vb.add_child(deck_desc_lbl)

	# Right Column: 2-4 Player Seat Roster & Launch Controls
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 10)
	body_hb.add_child(right_vb)

	var r_title := Label.new()
	r_title.text = "TABLE SEATS (2–4 PLAYERS ROUND TABLE)"
	_apply_font(r_title, true)
	r_title.add_theme_font_size_override("font_size", 16)
	r_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	right_vb.add_child(r_title)

	rule_btn = Button.new()
	rule_btn.text = "Ruleset: ⚡ OP CHAOS (3× Aces = Instant Kill on Chosen Target! + Relics)"
	rule_btn.clip_text = true
	rule_btn.custom_minimum_size = Vector2(0, 38)
	_style_tavern_btn(rule_btn, Color(0.16, 0.12, 0.08, 0.94), Color(0.76, 0.58, 0.26, 0.86), false, 8)
	rule_btn.pressed.connect(func():
		if mp_net == null or not mp_net.is_host:
			return
		play_click_sfx.emit()
		var nxt := "CLASSIC_BRAWL" if str(mp_net.room_settings.get("rule_mode", "OP_CHAOS")) == "OP_CHAOS" else "OP_CHAOS"
		mp_net.set_rule_mode(nxt)
	)
	right_vb.add_child(rule_btn)

	seats_box = VBoxContainer.new()
	seats_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seats_box.add_theme_constant_override("separation", 8)
	right_vb.add_child(seats_box)

	var bot_hb := HBoxContainer.new()
	bot_hb.add_theme_constant_override("separation", 10)
	right_vb.add_child(bot_hb)

	add_bot_btn = Button.new()
	add_bot_btn.text = "🤖 +Add Test Bot"
	add_bot_btn.custom_minimum_size = Vector2(160, 44)
	_style_tavern_btn(add_bot_btn, Color(0.16, 0.13, 0.10, 0.96), Color(0.68, 0.54, 0.30, 0.88), false, 9)
	add_bot_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net: mp_net.add_test_bot()
	)
	bot_hb.add_child(add_bot_btn)

	ready_btn = Button.new()
	ready_btn.text = "✓ READY"
	ready_btn.custom_minimum_size = Vector2(140, 44)
	_style_tavern_btn(ready_btn, Color(0.14, 0.22, 0.14, 0.96), Color(0.54, 0.82, 0.48, 0.90), true, 9)
	ready_btn.pressed.connect(func():
		play_click_sfx.emit()
		_local_ready = not _local_ready
		if mp_net: mp_net.toggle_ready(_local_ready)
	)
	bot_hb.add_child(ready_btn)

	start_btn = Button.new()
	start_btn.text = "⚔ START 2–4P BRAWL!"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.custom_minimum_size = Vector2(200, 44)
	_style_tavern_btn(start_btn, Color(0.32, 0.15, 0.08, 0.98), Color(0.96, 0.74, 0.24, 0.95), true, 9)
	start_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net: mp_net.start_match()
	)
	bot_hb.add_child(start_btn)

	_select_archetype("GUILLOTINE_ACES")


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
		mp_net.local_deck_cfg = {"archetype_id": arch_id, "extra_aces": extra_aces_val, "character_id": selected_char_id}
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(arch)


func _push_deck_update() -> void:
	var arch_id := "GUILLOTINE_ACES"
	for k in arch_buttons.keys():
		if arch_buttons[k].button_pressed:
			arch_id = str(k)
			break
	if mp_net != null:
		mp_net.local_deck_cfg = {"archetype_id": arch_id, "extra_aces": extra_aces_val, "character_id": selected_char_id}
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(Config.get_archetype(arch_id))


func _update_deck_summary(arch: Dictionary) -> void:
	aces_lbl.text = "Extra Aces in Your Deck (3× Aces = Instant Kill on Chosen Target!): +%d (%d Aces Total)" % [extra_aces_val, 4 + extra_aces_val]
	var pnames := ", ".join(PackedStringArray(arch.get("powers", [])))
	var inames := ", ".join(PackedStringArray(arch.get("items", [])))
	deck_desc_lbl.text = "Included Powers: %s\nStarting OP Items: %s\nTip: 3× Aces = Instant Kill on Chosen Target! (unless Mirror/Chronos parried!)." % [pnames, inames]


func _on_host_pressed() -> void:
	play_click_sfx.emit()
	if mp_net == null: return
	var port := maxi(1024, int(port_edit.text.to_int()))
	mp_net.host_room(port, name_edit.text, mp_net.local_deck_cfg)
	_local_ready = true
	_refresh_controls()


func _on_join_pressed() -> void:
	play_click_sfx.emit()
	if mp_net == null: return
	var port := maxi(1024, int(port_edit.text.to_int()))
	mp_net.join_room(ip_edit.text, port, name_edit.text, mp_net.local_deck_cfg)
	_local_ready = false
	_refresh_controls()


func _on_lobby_updated(seats: Array, settings: Dictionary) -> void:
	for c in seats_box.get_children():
		c.queue_free()

	for s in seats:
		var si := int(s["seat_idx"])
		var is_rdy := bool(s["ready"])
		var card := PanelContainer.new()
		var border_col := Color(0.78, 0.64, 0.28, 0.85) if is_rdy else Color(0.46, 0.36, 0.24, 0.65)
		card.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.12, 0.09, 0.065, 0.92), border_col, 2, 9, 10))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var arch := Config.get_archetype(str(s.get("deck_cfg", {}).get("archetype_id", "GUILLOTINE_ACES")))
		var aces := 4 + int(s.get("deck_cfg", {}).get("extra_aces", 0))
		var lbl := Label.new()
		var kind := "HOST" if si == 0 else ("BOT" if bool(s["is_bot"]) else "PLAYER")
		var rdy := "✅ READY" if is_rdy else "⏳ WAIT"
		lbl.text = "Seat %d [%s]: %s  •  %s (%d Aces)  •  %s" % [si + 1, kind, str(s["name"]), str(arch["name"]), aces, rdy]
		_apply_font(lbl, false)
		lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76) if is_rdy else Color(0.80, 0.74, 0.64))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		if mp_net != null and mp_net.is_host and si > 0:
			var kick := Button.new(); kick.text = "Kick"
			_style_tavern_btn(kick, Color(0.26, 0.11, 0.10, 0.94), Color(0.76, 0.36, 0.28, 0.85), false, 6)
			kick.pressed.connect(func(): mp_net.remove_seat(si))
			row.add_child(kick)
		seats_box.add_child(card)

	var rm := str(settings.get("rule_mode", "OP_CHAOS"))
	rule_btn.text = "Ruleset: ⚡ OP CHAOS (3× Aces = Instant Kill on Chosen Target! + OP Relics)" if rm == "OP_CHAOS" else "Ruleset: ⚖ Classic Brawl"
	_refresh_controls()


func _on_status_changed(msg: String, is_err: bool) -> void:
	status_lbl.text = msg
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.44, 0.38) if is_err else Color(0.74, 0.96, 0.80))
	_refresh_controls()


func _refresh_controls() -> void:
	var in_s: bool = (mp_net != null and bool(mp_net.get("in_session")))
	var is_h: bool = (mp_net != null and bool(mp_net.get("is_host")))
	host_btn.disabled = in_s
	join_btn.disabled = in_s
	leave_btn.disabled = not in_s
	rule_btn.disabled = not (in_s and is_h)
	add_bot_btn.visible = in_s and is_h
	add_bot_btn.disabled = (mp_net.lobby_seats.size() >= Config.MAX_PLAYERS) if in_s else true
	ready_btn.visible = in_s and not is_h
	ready_btn.text = "Cancel Ready" if _local_ready else "✓ READY UP"
	start_btn.visible = in_s and is_h
	if in_s and is_h:
		var chk: Dictionary = mp_net.can_start_match()
		start_btn.disabled = not bool(chk["ok"])
		start_btn.tooltip_text = str(chk["reason"])
