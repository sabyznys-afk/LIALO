class_name MpLobbyOverlay
extends Control

## Experimental Dev-Only 2-4 Player Multiplayer Lobby Overlay.
## Automatically opens only when MpConfig.is_test_mp_available() is true.

const Config = preload("res://scripts/mp/mp_config.gd")

signal close_requested
signal play_click_sfx

var mp_net: Node = null

var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var host_btn: Button
var join_btn: Button
var spawn_win_btn: Button
var leave_btn: Button

var status_lbl: Label
var arch_buttons: Dictionary = {}
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
	_build_ui()
	if mp_net != null:
		mp_net.lobby_updated.connect(_on_lobby_updated)
		mp_net.status_changed.connect(_on_status_changed)
		mp_net.session_closed.connect(func(_r: String): _refresh_controls())
	_refresh_controls()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.03, 0.84)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.08; panel.anchor_right = 0.92
	panel.anchor_top = 0.06; panel.anchor_bottom = 0.94
	add_child(panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	panel.add_child(root_vb)

	# Dev-only clear banner
	var warn_bar := PanelContainer.new()
	var warn_sb := StyleBoxFlat.new()
	warn_sb.bg_color = Color(0.38, 0.16, 0.08, 0.95)
	warn_sb.border_color = Color(1.0, 0.70, 0.22)
	warn_sb.set_border_width_all(2)
	warn_bar.add_theme_stylebox_override("panel", warn_sb)
	root_vb.add_child(warn_bar)

	var warn_hb := HBoxContainer.new()
	warn_bar.add_child(warn_hb)
	var warn_lbl := Label.new()
	warn_lbl.text = "  ⚗ EXPERIMENTAL TEST MULTIPLAYER (2–4 PLAYERS) — HIDDEN FROM RELEASE LAUNCH BUILDS  "
	warn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warn_lbl.add_theme_font_size_override("font_size", 15)
	warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	warn_hb.add_child(warn_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ Close Lobby"
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
	conn_hb.add_child(n_lbl)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(140, 36)
	name_edit.text = "Duelist_%d" % (randi() % 90 + 10)
	conn_hb.add_child(name_edit)

	var ip_lbl := Label.new(); ip_lbl.text = "IP:"
	conn_hb.add_child(ip_lbl)
	ip_edit = LineEdit.new()
	ip_edit.custom_minimum_size = Vector2(130, 36)
	ip_edit.text = "127.0.0.1"
	conn_hb.add_child(ip_edit)

	var p_lbl := Label.new(); p_lbl.text = "Port:"
	conn_hb.add_child(p_lbl)
	port_edit = LineEdit.new()
	port_edit.custom_minimum_size = Vector2(76, 36)
	port_edit.text = str(Config.DEFAULT_PORT)
	conn_hb.add_child(port_edit)

	host_btn = Button.new()
	host_btn.text = "🔥 HOST TABLE"
	host_btn.custom_minimum_size = Vector2(135, 36)
	host_btn.pressed.connect(_on_host_pressed)
	conn_hb.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "🔗 JOIN TABLE"
	join_btn.custom_minimum_size = Vector2(130, 36)
	join_btn.pressed.connect(_on_join_pressed)
	conn_hb.add_child(join_btn)

	spawn_win_btn = Button.new()
	spawn_win_btn.text = "🪟 +Spawn 2nd Window"
	spawn_win_btn.tooltip_text = "Launches another local Godot client into MP Test Lobby for quick localhost testing"
	spawn_win_btn.custom_minimum_size = Vector2(170, 36)
	spawn_win_btn.pressed.connect(func():
		play_click_sfx.emit()
		OS.create_instance(["--mp-test"])
		_on_status_changed("Launched 2nd test client window! Click JOIN TABLE there.", false)
	)
	conn_hb.add_child(spawn_win_btn)

	leave_btn = Button.new()
	leave_btn.text = "Disconnect"
	leave_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net: mp_net.leave_room(true)
	)
	conn_hb.add_child(leave_btn)

	status_lbl = Label.new()
	status_lbl.text = "Pick your Personal Deck below, then Host Table (add Test Bots or invite up to 4 friends!)."
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.86))
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

	var d_title := Label.new()
	d_title.text = "YOUR OWN PERSONAL DECK (Every player brings their own!)"
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
		arch_buttons[aid] = ab
		left_vb.add_child(ab)

	var aces_hb := HBoxContainer.new()
	aces_hb.add_theme_constant_override("separation", 10)
	left_vb.add_child(aces_hb)
	aces_lbl = Label.new()
	aces_lbl.text = "Extra Aces in Your Deck (for 3×/4× Eso Executions): +4 (8 Total)"
	aces_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aces_hb.add_child(aces_lbl)
	var minus_e := Button.new(); minus_e.text = " - "; minus_e.custom_minimum_size = Vector2(40, 34)
	minus_e.pressed.connect(func():
		extra_aces_val = maxi(0, extra_aces_val - 1)
		_push_deck_update()
	)
	aces_hb.add_child(minus_e)
	var plus_e := Button.new(); plus_e.text = " + "; plus_e.custom_minimum_size = Vector2(40, 34)
	plus_e.pressed.connect(func():
		extra_aces_val = mini(6, extra_aces_val + 1)
		_push_deck_update()
	)
	aces_hb.add_child(plus_e)

	deck_desc_lbl = Label.new()
	deck_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deck_desc_lbl.add_theme_font_size_override("font_size", 13)
	deck_desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.92))
	left_vb.add_child(deck_desc_lbl)

	# Right Column: 2-4 Player Seat Roster & Launch Controls
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 10)
	body_hb.add_child(right_vb)

	var r_title := Label.new()
	r_title.text = "TABLE SEATS (2–4 PLAYERS ROUND TABLE)"
	r_title.add_theme_font_size_override("font_size", 16)
	r_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	right_vb.add_child(r_title)

	rule_btn = Button.new()
	rule_btn.text = "Ruleset: ⚡ OP CHAOS (3×/4× Ace Sword Kill + Boosted Relics)"
	rule_btn.custom_minimum_size = Vector2(0, 38)
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
	add_bot_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net: mp_net.add_test_bot()
	)
	bot_hb.add_child(add_bot_btn)

	ready_btn = Button.new()
	ready_btn.text = "✓ READY"
	ready_btn.custom_minimum_size = Vector2(140, 44)
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
	start_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net: mp_net.start_match()
	)
	bot_hb.add_child(start_btn)

	_select_archetype("GUILLOTINE_ACES")


func _select_archetype(arch_id: String) -> void:
	for k in arch_buttons.keys():
		arch_buttons[k].set_pressed_no_signal(k == arch_id)
	var arch := Config.get_archetype(arch_id)
	extra_aces_val = int(arch.get("extra_aces", 2))
	if mp_net != null:
		mp_net.local_deck_cfg = {"archetype_id": arch_id, "extra_aces": extra_aces_val}
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(arch)


func _push_deck_update() -> void:
	var arch_id := "GUILLOTINE_ACES"
	for k in arch_buttons.keys():
		if arch_buttons[k].button_pressed:
			arch_id = str(k)
			break
	if mp_net != null:
		mp_net.local_deck_cfg = {"archetype_id": arch_id, "extra_aces": extra_aces_val}
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(Config.get_archetype(arch_id))


func _update_deck_summary(arch: Dictionary) -> void:
	aces_lbl.text = "Extra Aces in Your Deck (3×/4× Eso Execute): +%d (%d Aces Total)" % [extra_aces_val, 4 + extra_aces_val]
	var pnames := ", ".join(PackedStringArray(arch.get("powers", [])))
	var inames := ", ".join(PackedStringArray(arch.get("items", [])))
	deck_desc_lbl.text = "Included Powers: %s\nStarting OP Items: %s\nTip: Slamming 3× Eso breaks shields & executes below 55%% HP; 4× Eso executes instantly (unless Mirror/Chronos parried!)." % [pnames, inames]


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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var arch := Config.get_archetype(str(s.get("deck_cfg", {}).get("archetype_id", "GUILLOTINE_ACES")))
		var aces := 4 + int(s.get("deck_cfg", {}).get("extra_aces", 0))
		var lbl := Label.new()
		var kind := "HOST" if si == 0 else ("BOT" if bool(s["is_bot"]) else "PLAYER")
		var rdy := "✅ READY" if bool(s["ready"]) else "⏳ WAIT"
		lbl.text = "Seat %d [%s]: %s  •  %s (%d Aces)  •  %s" % [si + 1, kind, str(s["name"]), str(arch["name"]), aces, rdy]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		if mp_net != null and mp_net.is_host and si > 0:
			var kick := Button.new(); kick.text = "Kick"
			kick.pressed.connect(func(): mp_net.remove_seat(si))
			row.add_child(kick)
		seats_box.add_child(row)

	var rm := str(settings.get("rule_mode", "OP_CHAOS"))
	rule_btn.text = "Ruleset: ⚡ OP CHAOS (3×/4× Ace Sword Kill + OP Relics)" if rm == "OP_CHAOS" else "Ruleset: ⚖ Classic Brawl"
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
