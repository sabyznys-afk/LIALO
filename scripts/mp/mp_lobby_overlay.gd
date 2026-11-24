class_name MpLobbyOverlay
extends Control

## Experimental Dev-Only 2-4 Player Multiplayer Lobby Overlay.
## Automatically opens only when MpConfig.is_test_mp_available() is true.

const Config = preload("res://scripts/mp/mp_config.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")
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
var share_bar: PanelContainer
var share_addr_lbl: Label
var copy_ip_btn: Button
var _share_copy_target: String = ""
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

var _profile: Dictionary = {}
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
	_load_vault_from_profile()
	_build_ui()
	if mp_net != null:
		mp_net.lobby_updated.connect(_on_lobby_updated)
		mp_net.status_changed.connect(_on_status_changed)
		if mp_net.has_signal("host_network_ready"):
			mp_net.host_network_ready.connect(_on_host_network_ready)
		mp_net.session_closed.connect(func(_r: String): _refresh_controls())
	_refresh_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is LineEdit:
			return
		get_viewport().set_input_as_handled()
		_close_lobby()


func _close_lobby() -> void:
	play_click_sfx.emit()
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
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.025, 0.02, 0.86)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.03; panel.anchor_right = 0.97
	panel.anchor_top = 0.03; panel.anchor_bottom = 0.97
	panel.offset_left = 0; panel.offset_top = 0
	panel.offset_right = 0; panel.offset_bottom = 0
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

	var ver_badge := PanelContainer.new()
	ver_badge.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.14, 0.10, 0.06, 0.95), Color(0.78, 0.62, 0.28, 0.85), 1, 6, 8))
	warn_hb.add_child(ver_badge)
	var ver_lbl := Label.new()
	ver_lbl.text = "v%s" % Config.MP_PROTOCOL_VERSION
	_apply_font(ver_lbl, false)
	ver_lbl.add_theme_font_size_override("font_size", 13)
	ver_lbl.add_theme_color_override("font_color", Color(0.76, 0.92, 1.0))
	ver_badge.add_child(ver_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ Close Lobby"
	_style_tavern_btn(close_btn, Color(0.24, 0.10, 0.09, 0.95), Color(0.78, 0.36, 0.28, 0.85), false, 8)
	close_btn.pressed.connect(_close_lobby)
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

	# Compact Share Address Bar (visible while Hosting)
	share_bar = PanelContainer.new()
	share_bar.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.10, 0.14, 0.11, 0.94), Color(0.46, 0.76, 0.56, 0.85), 1, 8, 8))
	share_bar.visible = false
	root_vb.add_child(share_bar)

	var share_hb := HBoxContainer.new()
	share_hb.add_theme_constant_override("separation", 10)
	share_bar.add_child(share_hb)

	share_addr_lbl = Label.new()
	share_addr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_addr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(share_addr_lbl, false)
	share_addr_lbl.add_theme_font_size_override("font_size", 13)
	share_addr_lbl.add_theme_color_override("font_color", Color(0.82, 0.96, 0.86))
	share_hb.add_child(share_addr_lbl)

	copy_ip_btn = Button.new()
	copy_ip_btn.text = "📋 Copy IP"
	copy_ip_btn.custom_minimum_size = Vector2(120, 32)
	_style_tavern_btn(copy_ip_btn, Color(0.14, 0.24, 0.18, 0.96), Color(0.54, 0.86, 0.64, 0.90), false, 7)
	copy_ip_btn.pressed.connect(func():
		play_click_sfx.emit()
		if not _share_copy_target.is_empty():
			DisplayServer.clipboard_set(_share_copy_target)
			_on_status_changed("Copied %s to clipboard!" % _share_copy_target, false)
	)
	share_hb.add_child(copy_ip_btn)

	# Split Content: Left = Personal Deck Builder, Right = 2-4P Seat Roster & Match Rules
	var body_hb := HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 18)
	root_vb.add_child(body_hb)

	# Left Column: Personal Custom Deck Builder + Campaign Vault Loadout (scrollable)
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_hb.add_child(left_scroll)

	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 10)
	left_scroll.add_child(left_vb)

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

	_build_vault_section(left_vb)

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
	rule_btn.text = "Ruleset: 🏛 Campaign Vault (Your Unlocked Power Cards, Relics & Sword)"
	rule_btn.clip_text = true
	rule_btn.custom_minimum_size = Vector2(0, 38)
	_style_tavern_btn(rule_btn, Color(0.16, 0.12, 0.08, 0.94), Color(0.76, 0.58, 0.26, 0.86), false, 8)
	rule_btn.pressed.connect(func():
		if mp_net == null or not mp_net.is_host:
			return
		play_click_sfx.emit()
		var cur := str(mp_net.room_settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
		var nxt := Config.RULE_BALANCED_ARENA if cur == Config.RULE_CAMPAIGN_VAULT else Config.RULE_CAMPAIGN_VAULT
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


func _build_local_deck_cfg(arch_id: String) -> Dictionary:
	return {
		"archetype_id": arch_id,
		"extra_aces": extra_aces_val,
		"character_id": selected_char_id,
		"power_cards": selected_power_cards.duplicate(),
		"table_relics": selected_table_relics.duplicate(),
		"passive_relics": selected_passive_relics.duplicate(),
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
		"power_cards": selected_power_cards.duplicate(),
		"table_relics": selected_table_relics.duplicate(),
		"passive_relics": selected_passive_relics.duplicate(),
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

	var sw_info := Catalog.get_sword_skin_loc(equipped_sword_id, _lang)
	vault_sword_lbl = Label.new()
	vault_sword_lbl.text = "⚔ Sword: %s" % str(sw_info.get("name", equipped_sword_id))
	_apply_font(vault_sword_lbl, false)
	vault_sword_lbl.add_theme_font_size_override("font_size", 13)
	vault_sword_lbl.add_theme_color_override("font_color", Color(0.76, 0.92, 1.0))
	hdr_hb.add_child(vault_sword_lbl)

	# 1. Power Cards (3 max, max 1 Mythic)
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
		btn.custom_minimum_size = Vector2(0, 32)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		var tag := " ★M" if is_mythic else ""
		if unlocked:
			btn.text = "%s%s" % [str(pc_loc.get("short", pc_loc.get("name", pid))), tag]
			btn.tooltip_text = "%s (%s)\n%s" % [str(pc_loc.get("name", pid)), str(pc_loc.get("rarity", "")), str(pc_loc.get("desc", ""))]
			btn.toggle_mode = true
			btn.set_pressed_no_signal(pid in selected_power_cards)
			btn.pressed.connect(func(): _toggle_vault_power(pid))
			_apply_choice_btn_style(btn, pid in selected_power_cards, pc.get("accent", Color(0.95, 0.78, 0.30)))
		else:
			btn.text = "🔒 %s%s" % [str(pc_loc.get("short", pc_loc.get("name", pid))), tag]
			btn.tooltip_text = "Locked — %s\n%s" % [Catalog.get_unlock_source_label(pid, _lang), str(pc_loc.get("desc", ""))]
			btn.disabled = true
			_style_vault_locked_btn(btn)
		vault_power_btns[pid] = btn
		p_grid.add_child(btn)

	# 2. Tabletop Relics (2 max)
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
		btn.custom_minimum_size = Vector2(0, 32)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		if unlocked:
			btn.text = str(tr_loc.get("name", tid))
			btn.tooltip_text = "%s\n%s" % [str(tr_loc.get("name", tid)), str(tr_loc.get("desc", ""))]
			btn.toggle_mode = true
			btn.set_pressed_no_signal(tid in selected_table_relics)
			btn.pressed.connect(func(): _toggle_vault_table_relic(tid))
			_apply_choice_btn_style(btn, tid in selected_table_relics, tr_item.get("col", Color(0.96, 0.78, 0.34)))
		else:
			btn.text = "🔒 %s" % str(tr_loc.get("name", tid))
			btn.tooltip_text = "Locked — %s\n%s" % [Catalog.get_unlock_source_label(tid, _lang), str(tr_loc.get("desc", ""))]
			btn.disabled = true
			_style_vault_locked_btn(btn)
		vault_trel_btns[tid] = btn
		t_grid.add_child(btn)

	# 3. Passive Relics (2 max)
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
		btn.custom_minimum_size = Vector2(0, 32)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		if unlocked:
			btn.text = str(rel_loc.get("name", rid))
			btn.tooltip_text = "%s\n%s" % [str(rel_loc.get("name", rid)), str(rel_loc.get("desc", ""))]
			btn.toggle_mode = true
			btn.set_pressed_no_signal(rid in selected_passive_relics)
			btn.pressed.connect(func(): _toggle_vault_passive_relic(rid))
			_apply_choice_btn_style(btn, rid in selected_passive_relics, rel.get("col", Color(0.54, 0.86, 0.96)))
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
	var arch_id := "GUILLOTINE_ACES"
	for k in arch_buttons.keys():
		if arch_buttons[k].button_pressed:
			arch_id = str(k)
			break
	if mp_net != null:
		mp_net.local_deck_cfg = _build_local_deck_cfg(arch_id)
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(Config.get_archetype(arch_id))


func _update_deck_summary(_arch: Dictionary) -> void:
	aces_lbl.text = "Extra Aces in Your Deck (3× Aces = Instant Kill on Chosen Target!): +%d (%d Aces Total)" % [extra_aces_val, 4 + extra_aces_val]
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
	deck_desc_lbl.text = "Vault Powers: %s  |  Table Relics: %s  |  Passive Relics: %s\nTip: 3× Aces = Instant Kill on Chosen Target! (unless Mirror/Chronos parried!)." % [pnames, tnames, rnames]


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
	for c in seats_box.get_children():
		c.queue_free()

	var rm := str(settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	for s in seats:
		var si := int(s["seat_idx"])
		var is_rdy := bool(s["ready"])
		var card := PanelContainer.new()
		var border_col := Color(0.78, 0.64, 0.28, 0.85) if is_rdy else Color(0.46, 0.36, 0.24, 0.65)
		card.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.12, 0.09, 0.065, 0.92), border_col, 2, 9, 10))
		var seat_vb := VBoxContainer.new()
		seat_vb.add_theme_constant_override("separation", 4)
		card.add_child(seat_vb)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
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
		lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76) if is_rdy else Color(0.80, 0.74, 0.64))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		if mp_net != null and mp_net.is_host and si > 0:
			var kick := Button.new(); kick.text = "Kick"
			_style_tavern_btn(kick, Color(0.26, 0.11, 0.10, 0.94), Color(0.76, 0.36, 0.28, 0.85), false, 6)
			kick.pressed.connect(func(): mp_net.remove_seat(si))
			row.add_child(kick)

		var loadout_lbl := Label.new()
		loadout_lbl.text = _format_seat_loadout_summary(eff_dcfg)
		loadout_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_font(loadout_lbl, false)
		loadout_lbl.add_theme_font_size_override("font_size", 12)
		loadout_lbl.add_theme_color_override("font_color", Color(0.76, 0.70, 0.58))
		seat_vb.add_child(loadout_lbl)

		seats_box.add_child(card)

	if rm == Config.RULE_BALANCED_ARENA:
		rule_btn.text = "Ruleset: ⚖ Balanced Arena (Preset Archetype Decks + Fair Relics)"
	else:
		rule_btn.text = "Ruleset: 🏛 Campaign Vault (Your Unlocked Power Cards, Relics & Sword)"
	if vault_box != null:
		vault_box.modulate = Color(0.62, 0.60, 0.56, 0.85) if rm == Config.RULE_BALANCED_ARENA else Color(1, 1, 1, 1)
	_refresh_controls()


func _on_status_changed(msg: String, is_err: bool) -> void:
	status_lbl.text = msg
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.44, 0.38) if is_err else Color(0.74, 0.96, 0.80))
	_refresh_controls()


func _on_host_network_ready(info: Dictionary) -> void:
	_update_share_bar(info)


func _update_share_bar(info: Dictionary) -> void:
	if share_addr_lbl == null:
		return
	var port := int(info.get("port", Config.DEFAULT_PORT))
	var lan_ip := str(info.get("lan_ip", "127.0.0.1"))
	var pub_ip := str(info.get("public_ip", ""))
	var upnp_ok := bool(info.get("upnp_ok", false))
	var upnp_pending := bool(info.get("upnp_pending", false))
	var lan_str := "%s:%d" % [lan_ip, port]
	if upnp_ok and not pub_ip.is_empty():
		var pub_str := "%s:%d" % [pub_ip, port]
		_share_copy_target = pub_str
		share_addr_lbl.text = "🌐 Share Address:  LAN %s   |   Public (UPnP OK) %s" % [lan_str, pub_str]
		copy_ip_btn.tooltip_text = "Copies %s" % pub_str
	elif upnp_pending:
		_share_copy_target = lan_str
		share_addr_lbl.text = "🌐 Share Address:  LAN %s   |   Public: Checking UPnP..." % lan_str
		copy_ip_btn.tooltip_text = "Copies %s" % lan_str
	else:
		_share_copy_target = lan_str
		share_addr_lbl.text = "🌐 LAN: %s   |   UPnP unavailable — forward UDP %d on router or use Radmin VPN / Tailscale." % [lan_str, port]
		copy_ip_btn.tooltip_text = "Copies %s" % lan_str


func _refresh_controls() -> void:
	var in_s: bool = (mp_net != null and bool(mp_net.get("in_session")))
	var is_h: bool = (mp_net != null and bool(mp_net.get("is_host")))
	host_btn.disabled = in_s
	join_btn.disabled = in_s
	leave_btn.disabled = not in_s
	if share_bar != null:
		share_bar.visible = in_s and is_h
		if share_bar.visible and mp_net != null and mp_net.has_method("get_host_network_addresses"):
			_update_share_bar(mp_net.get_host_network_addresses())
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
