extends RefCounted
class_name CombatLogDrawer

const MAX_LOG_ENTRIES: int = 60

var mini_relic_pill: PanelContainer
var mini_relic_lbl: Label
var log_toggle_btn: Button
var drawer_panel: PanelContainer
var drawer_title_lbl: Label
var log_rtl: RichTextLabel

var _entries: Array[String] = []
var _is_open: bool = false
var _font: Font = null
var _lang: String = "en"


func setup(hud_root: Control, font: Font, lang: String = "en") -> void:
	_font = font
	_lang = lang

	# Compact mini relic-charge indicator pill + [L] Log toggle button (top-right below Rival HUD)
	mini_relic_pill = PanelContainer.new()
	mini_relic_pill.name = "MiniRelicChargePill"
	mini_relic_pill.anchor_left = 1.0
	mini_relic_pill.anchor_top = 0.0
	mini_relic_pill.anchor_right = 1.0
	mini_relic_pill.offset_left = -362
	mini_relic_pill.offset_top = 90
	mini_relic_pill.offset_right = -14
	mini_relic_pill.offset_bottom = 120
	mini_relic_pill.mouse_filter = Control.MOUSE_FILTER_PASS
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.05, 0.04, 0.055, 0.88)
	pill_sb.border_color = Color(0.76, 0.58, 0.26, 0.82)
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(8)
	pill_sb.content_margin_left = 10
	pill_sb.content_margin_right = 6
	pill_sb.content_margin_top = 3
	pill_sb.content_margin_bottom = 3
	mini_relic_pill.add_theme_stylebox_override("panel", pill_sb)
	hud_root.add_child(mini_relic_pill)

	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 8)
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mini_relic_pill.add_child(pill_row)

	mini_relic_lbl = Label.new()
	mini_relic_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mini_relic_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mini_relic_lbl.clip_text = true
	mini_relic_lbl.text = ""
	if _font:
		mini_relic_lbl.add_theme_font_override("font", _font)
	mini_relic_lbl.add_theme_font_size_override("font_size", 11)
	mini_relic_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68))
	mini_relic_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.02))
	mini_relic_lbl.add_theme_constant_override("outline_size", 3)
	pill_row.add_child(mini_relic_lbl)

	log_toggle_btn = Button.new()
	log_toggle_btn.text = _tr("📜 Log [L]", "📜 Záznam [L]")
	log_toggle_btn.custom_minimum_size = Vector2(82, 22)
	log_toggle_btn.focus_mode = Control.FOCUS_NONE
	if _font:
		log_toggle_btn.add_theme_font_override("font", _font)
	log_toggle_btn.add_theme_font_size_override("font_size", 10)
	log_toggle_btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.14, 0.10, 0.07, 0.94)
	btn_sb.border_color = Color(0.86, 0.66, 0.28, 0.90)
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(5)
	log_toggle_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hov := btn_sb.duplicate() as StyleBoxFlat
	btn_hov.bg_color = Color(0.24, 0.17, 0.10, 0.96)
	log_toggle_btn.add_theme_stylebox_override("hover", btn_hov)
	log_toggle_btn.pressed.connect(toggle)
	pill_row.add_child(log_toggle_btn)

	# Toggleable Combat Log Drawer
	drawer_panel = PanelContainer.new()
	drawer_panel.name = "CombatLogDrawerPanel"
	drawer_panel.anchor_left = 1.0
	drawer_panel.anchor_top = 0.0
	drawer_panel.anchor_right = 1.0
	drawer_panel.offset_left = -362
	drawer_panel.offset_top = 126
	drawer_panel.offset_right = -14
	drawer_panel.offset_bottom = 396
	drawer_panel.visible = false
	drawer_panel.z_index = 18
	drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dr_sb := StyleBoxFlat.new()
	dr_sb.bg_color = Color(0.04, 0.03, 0.045, 0.93)
	dr_sb.border_color = Color(0.84, 0.64, 0.28, 0.90)
	dr_sb.set_border_width_all(2)
	dr_sb.set_corner_radius_all(10)
	dr_sb.content_margin_left = 10
	dr_sb.content_margin_right = 10
	dr_sb.content_margin_top = 8
	dr_sb.content_margin_bottom = 8
	drawer_panel.add_theme_stylebox_override("panel", dr_sb)
	hud_root.add_child(drawer_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	drawer_panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	drawer_title_lbl = Label.new()
	drawer_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_title_lbl.text = _tr("📜 COMBAT LOG [L]", "📜 ZÁZNAM BOJE [L]")
	if _font:
		drawer_title_lbl.add_theme_font_override("font", _font)
	drawer_title_lbl.add_theme_font_size_override("font_size", 12)
	drawer_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	hdr.add_child(drawer_title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(24, 20)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func(): set_open(false))
	hdr.add_child(close_btn)

	log_rtl = RichTextLabel.new()
	log_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_rtl.bbcode_enabled = true
	log_rtl.scroll_following = true
	log_rtl.fit_content = false
	if _font:
		log_rtl.add_theme_font_override("normal_font", _font)
	log_rtl.add_theme_font_size_override("normal_font_size", 11)
	log_rtl.add_theme_color_override("default_color", Color(0.92, 0.88, 0.80))
	vbox.add_child(log_rtl)


func set_language(lang: String) -> void:
	_lang = lang
	if is_instance_valid(log_toggle_btn):
		log_toggle_btn.text = _tr("📜 Log [L]", "📜 Záznam [L]")
	if is_instance_valid(drawer_title_lbl):
		drawer_title_lbl.text = _tr("📜 COMBAT LOG [L]", "📜 ZÁZNAM BOJE [L]")


func toggle() -> void:
	set_open(not _is_open)


func set_open(open: bool) -> void:
	_is_open = open
	if is_instance_valid(drawer_panel):
		drawer_panel.visible = _is_open


func is_open() -> bool:
	return _is_open


func clear_log() -> void:
	_entries.clear()
	if is_instance_valid(log_rtl):
		log_rtl.clear()


func add_entry(text: String, col: Color = Color(0.92, 0.88, 0.78)) -> void:
	if text == "":
		return
	var hex := col.to_html(false)
	_entries.append("[color=#%s]%s[/color]" % [hex, text])
	if _entries.size() > MAX_LOG_ENTRIES:
		_entries.pop_front()
	if is_instance_valid(log_rtl):
		log_rtl.text = "\n".join(_entries)


func update_relic_pill(relic_entries: Array) -> void:
	if not is_instance_valid(mini_relic_lbl):
		return
	if relic_entries.is_empty():
		mini_relic_lbl.text = _tr("No Relics", "Bez relikvií")
		return
	var parts: Array[String] = []
	var shown := 0
	for entry in relic_entries:
		if shown >= 5:
			parts.append("+%d" % (relic_entries.size() - shown))
			break
		var d: Dictionary = entry
		var icon_s := str(d.get("icon", "✦"))
		var rem := int(d.get("rem", 0))
		var max_u := int(d.get("max", 3))
		if bool(d.get("broken", false)) or rem <= 0:
			parts.append("%s 0/%d" % [icon_s, max_u])
		else:
			parts.append("%s %d/%d" % [icon_s, rem, max_u])
		shown += 1
	mini_relic_lbl.text = " • ".join(parts)


func sync_visibility(show_in_cards_view: bool, cine_active: bool) -> void:
	if is_instance_valid(mini_relic_pill):
		mini_relic_pill.visible = show_in_cards_view and (not cine_active)
	if is_instance_valid(drawer_panel):
		drawer_panel.visible = _is_open and (not cine_active)


func _tr(en: String, cs: String) -> String:
	return cs if _lang == "cs" else en
