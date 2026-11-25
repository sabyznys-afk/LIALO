class_name DeckBuilderPanel
extends Control
## Unified Visual Deck Builder Subcategory (Campaign + Multiplayer) for LIALO v0.192
## - Pick 1 of 4 Deck Builds with animated build-themed aura canvas & particles
## - Equip up to 2 of the 8 Core Relics (4 Builds × 2 Signature Relics)
## - Configure your 4-Card "BANKAI" Awakening Combo Seal + live Preview Button!
## - Customize Power Cards (up to 3, max 1 Mythic) & Card Classes synced to Campaign + MP

signal deck_changed(profile: Dictionary)
signal sfx_requested(sfx_name: String)

const Catalog := preload("res://scripts/lialo_catalog.gd")
const Toon := preload("res://scripts/toon_style.gd")
const BankaiFxScript := preload("res://scripts/battle/bankai_fx.gd")

const SUITS := [
	{"id": "CERVEN", "sym": "♥", "col": Color(0.92, 0.24, 0.28)},
	{"id": "ZELEN",  "sym": "♠", "col": Color(0.24, 0.78, 0.52)},
	{"id": "ZALUD",  "sym": "♣", "col": Color(0.86, 0.64, 0.34)},
	{"id": "GULA",   "sym": "●", "col": Color(0.98, 0.62, 0.22)},
]
const RANKS := ["7", "8", "9", "10", "D", "H", "K", "E"]
const CLASS_CYCLE := ["NORMAL", "KNIGHT", "MAGE", "THIEF", "MERCHANT"]

var _profile: Dictionary = {}
var _lang: String = "en"
var _font_disp: Font
var _font_body: Font
var _card_cache: Dictionary = {}

var _bg_fx: Control
var _content_vb: VBoxContainer
var _editing_bankai_slot: int = -1
var _bankai_picker_wrap: PanelContainer
var _bankai_fx_preview: BankaiFxScript
var _fx_time: float = 0.0
var _fx_col: Color = Color(0.32, 0.88, 1.0)
var _fx_target_col: Color = Color(0.32, 0.88, 1.0)
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(1160, 820)
	_font_disp = load("res://assets/fonts/LialoDisplay.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoDisplay.ttf") else ThemeDB.fallback_font
	_font_body = load("res://assets/fonts/LialoUI.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoUI.ttf") else ThemeDB.fallback_font

	for _i in range(36):
		_motes.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"spd": _rng.randf_range(0.03, 0.09),
			"sz": _rng.randf_range(1.6, 4.2),
			"ph": _rng.randf_range(0.0, TAU),
		})

	_bg_fx = Control.new()
	_bg_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_fx.draw.connect(_draw_animated_bg)
	add_child(_bg_fx)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	_content_vb = VBoxContainer.new()
	_content_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vb.add_theme_constant_override("separation", 14)
	margin.add_child(_content_vb)


func setup_builder(prof: Dictionary, lang: String = "en", card_face_cache: Dictionary = {}) -> void:
	_profile = prof
	_lang = lang
	_card_cache = card_face_cache
	_editing_bankai_slot = -1
	var b := Catalog.get_deck_build(str(_profile.get("selected_build_id", "GUILLOTINE_ACES")))
	_fx_target_col = b.get("col", Color(0.32, 0.88, 1.0))
	_rebuild_ui()


func _tr(en: String, cs: String) -> String:
	return cs if _lang == "cs" else en


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := minf(delta, 0.05)
	_fx_time += dt
	_fx_col = _fx_col.lerp(_fx_target_col, 1.0 - exp(-5.0 * dt))
	for m in _motes:
		m["y"] = float(m["y"]) - float(m["spd"]) * dt
		if float(m["y"]) < -0.05:
			m["y"] = 1.05
			m["x"] = _rng.randf()
	if is_instance_valid(_bg_fx):
		_bg_fx.queue_redraw()


func _draw_animated_bg() -> void:
	var sz := _bg_fx.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	_bg_fx.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.045, 0.036, 0.042, 0.82))
	# Rotating arcane woodcut ritual ring pulsing in build's color
	var center := Vector2(sz.x * 0.5, 290.0)
	var r := minf(sz.x * 0.34, 240.0)
	_bg_fx.draw_arc(center, r, 0.0, TAU, 80, Color(_fx_col.r, _fx_col.g, _fx_col.b, 0.16), 2.2)
	_bg_fx.draw_arc(center, r * 0.78, 0.0, TAU, 64, Color(_fx_col.r, _fx_col.g, _fx_col.b, 0.10), 1.4)
	for ti in range(16):
		var a := float(ti) * (TAU / 16.0) + _fx_time * 0.22
		var p1 := center + Vector2(cos(a), sin(a)) * (r * 0.94)
		var p2 := center + Vector2(cos(a), sin(a)) * (r * 1.04)
		_bg_fx.draw_line(p1, p2, Color(_fx_col.r, _fx_col.g, _fx_col.b, 0.22), 1.8)
	# Floating spiritual energy embers
	for m in _motes:
		var mx := float(m["x"]) * sz.x + sin(_fx_time * 1.8 + float(m["ph"])) * 16.0
		var my := float(m["y"]) * sz.y
		var a := 0.22 + 0.20 * sin(_fx_time * 3.2 + float(m["ph"]))
		_bg_fx.draw_circle(Vector2(mx, my), float(m["sz"]), Color(_fx_col.r, _fx_col.g, _fx_col.b, a))


func _make_box_style(bg: Color, border: Color, rad: int = 10, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(rad)
	sb.set_content_margin_all(pad)
	return sb


func _get_card_tex(ck: String) -> Texture2D:
	if _card_cache.has(ck) and _card_cache[ck] is Texture2D:
		return _card_cache[ck] as Texture2D
	var p := "res://assets/cards/%s.png" % ck
	var t := Toon.tex(p)
	if t != null:
		_card_cache[ck] = t
	return t


func _sync_and_save() -> void:
	# Mirror Campaign custom deck choices directly into mp_loadout so both modes stay 100% synced!
	var sel_b := str(_profile.get("selected_build_id", "GUILLOTINE_ACES"))
	var b_combo: Array = _profile.get("bankai_combo", []).duplicate()
	var act_rel: Array = _profile.get("active_relics", []).duplicate()
	var cust_pc: Array = _profile.get("custom_cards", []).duplicate()
	if not _profile.has("mp_loadout") or not (_profile["mp_loadout"] is Dictionary):
		_profile["mp_loadout"] = {}
	var mpl: Dictionary = _profile["mp_loadout"]
	mpl["archetype_id"] = sel_b
	mpl["bankai_combo"] = b_combo
	mpl["passive_relics"] = act_rel.slice(0, 2)
	mpl["power_cards"] = cust_pc.slice(0, 3)
	mpl["sword_skin"] = str(_profile.get("equipped_sword", "SWORD_IRON"))
	Catalog.save_profile(_profile)
	deck_changed.emit(_profile)


func _animate_btn_pop(ctrl: Control) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale", Vector2(1.06, 1.06), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _rebuild_ui() -> void:
	if not is_instance_valid(_content_vb):
		return
	for ch in _content_vb.get_children():
		ch.queue_free()

	var sel_build_id := str(_profile.get("selected_build_id", "GUILLOTINE_ACES"))
	var cur_build := Catalog.get_deck_build_loc(sel_build_id, _lang)
	_fx_target_col = cur_build.get("col", Color(0.32, 0.88, 1.0))

	# === HEADER BAR ===
	var hdr_pan := PanelContainer.new()
	hdr_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.08, 0.06, 0.055, 0.94), _fx_target_col, 12, 12))
	_content_vb.add_child(hdr_pan)

	var hdr_hb := HBoxContainer.new()
	hdr_hb.add_theme_constant_override("separation", 14)
	hdr_pan.add_child(hdr_hb)

	var hdr_vb := VBoxContainer.new()
	hdr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hb.add_child(hdr_vb)

	var t_lbl := Label.new()
	t_lbl.text = _tr("🛠 UNIFIED DECK BUILDER — CAMPAIGN & MULTIPLAYER", "🛠 DECK BUILDER — KAMPAŇ & MULTIPLAYER")
	t_lbl.add_theme_font_override("font", _font_disp)
	t_lbl.add_theme_font_size_override("font_size", 22)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	hdr_vb.add_child(t_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = _tr(
		"Craft your Build, equip 2 of the 8 Core Relics, customize Card Classes & forge your 4-Card BANKAI Awakening Seal!",
		"Sestav si vlastní Build, vyber 2 z 8 hlavních relikvií, uprav třídy karet a ukuj své 4-kartové BANKAI kombo!"
	)
	sub_lbl.add_theme_font_override("font", _font_body)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
	hdr_vb.add_child(sub_lbl)

	var sync_badge := Label.new()
	sync_badge.text = _tr("✓ CAMPAIGN + MP SYNCED", "✓ KAMPAŇ + MP SYNC")
	sync_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sync_badge.add_theme_font_override("font", _font_disp)
	sync_badge.add_theme_font_size_override("font_size", 14)
	sync_badge.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62))
	hdr_hb.add_child(sync_badge)

	# === SECTION 1: 4 DECK BUILDS ===
	var builds_hb := HBoxContainer.new()
	builds_hb.add_theme_constant_override("separation", 12)
	_content_vb.add_child(builds_hb)

	for b_raw in Catalog.DECK_BUILDS:
		var bid := str(b_raw["id"])
		var b := Catalog.get_deck_build_loc(bid, _lang)
		var b_col: Color = b["col"]
		var is_sel := (bid == sel_build_id)
		var b_btn := Button.new()
		b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_btn.custom_minimum_size = Vector2(0, 74)
		b_btn.text = "%s\n%s" % [str(b["name"]), _tr("✓ ACTIVE BUILD", "✓ AKTIVNÍ BUILD") if is_sel else str(b["bankai_name"])]
		b_btn.add_theme_font_override("font", _font_disp)
		b_btn.add_theme_font_size_override("font_size", 14)
		b_btn.add_theme_color_override("font_color", Color.WHITE if is_sel else Color(0.86, 0.82, 0.74))
		b_btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(b_col.r * 0.24, b_col.g * 0.24, b_col.b * 0.24, 0.96) if is_sel else Color(0.08, 0.065, 0.06, 0.90),
			b_col if is_sel else Color(0.42, 0.34, 0.24, 0.75), 10, 8
		))
		b_btn.add_theme_stylebox_override("hover", _make_box_style(
			Color(b_col.r * 0.32, b_col.g * 0.32, b_col.b * 0.32, 1.0), b_col.lightened(0.2), 10, 8
		))
		b_btn.pressed.connect(func():
			sfx_requested.emit("ui_click")
			_profile["selected_build_id"] = bid
			# Auto-equip this build's signature relics (any unlocked ones) & default Bankai if user wants preset
			var def_b := Catalog.get_deck_build(bid)
			var auto_rels: Array = []
			for r_id in def_b.get("relics", []):
				if Catalog.is_relic_unlocked(_profile, str(r_id)):
					auto_rels.append(str(r_id))
			if not auto_rels.is_empty():
				_profile["active_relics"] = auto_rels
			_sync_and_save()
			_rebuild_ui()
		)
		builds_hb.add_child(b_btn)

	# === SECTION 2: 4-CARD BANKAI AWAKENING SEAL ===
	var bankai_pan := PanelContainer.new()
	bankai_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.065, 0.048, 0.065, 0.95), _fx_target_col, 12, 12))
	_content_vb.add_child(bankai_pan)

	var bk_vb := VBoxContainer.new()
	bk_vb.add_theme_constant_override("separation", 10)
	bankai_pan.add_child(bk_vb)

	var bk_hdr := HBoxContainer.new()
	bk_hdr.add_theme_constant_override("separation", 12)
	bk_vb.add_child(bk_hdr)

	var bk_info := VBoxContainer.new()
	bk_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bk_hdr.add_child(bk_info)

	var bk_title := Label.new()
	bk_title.text = "⚡ %s" % str(cur_build["bankai_name"])
	bk_title.add_theme_font_override("font", _font_disp)
	bk_title.add_theme_font_size_override("font_size", 20)
	bk_title.add_theme_color_override("font_color", _fx_target_col.lightened(0.25))
	bk_info.add_child(bk_title)

	var bk_desc := Label.new()
	bk_desc.text = "%s\n%s" % [
		str(cur_build["bankai_desc"]),
		_tr("Play all 4 Seal cards (in 1 slam or across the duel 0/4→4/4) to trigger BANKAI Awakening!", "Zahraj všechny 4 karty pečeti (najednou nebo během duelu 0/4→4/4) pro spuštění BANKAI!")
	]
	bk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bk_desc.add_theme_font_override("font", _font_body)
	bk_desc.add_theme_font_size_override("font_size", 14)
	bk_desc.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	bk_info.add_child(bk_desc)

	var preset_btn := Button.new()
	preset_btn.text = _tr("↺ Build Preset", "↺ Výchozí kombo")
	preset_btn.custom_minimum_size = Vector2(150, 38)
	preset_btn.add_theme_font_override("font", _font_disp)
	preset_btn.add_theme_font_size_override("font_size", 13)
	preset_btn.pressed.connect(func():
		sfx_requested.emit("card_shuffle")
		_profile["bankai_combo"] = (cur_build.get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]) as Array).duplicate()
		_editing_bankai_slot = -1
		_sync_and_save()
		_rebuild_ui()
	)
	bk_hdr.add_child(preset_btn)

	var preview_btn := Button.new()
	preview_btn.text = _tr("⚡ Preview Bankai FX", "⚡ Ukázka Bankai FX")
	preview_btn.custom_minimum_size = Vector2(178, 38)
	preview_btn.add_theme_font_override("font", _font_disp)
	preview_btn.add_theme_font_size_override("font_size", 14)
	preview_btn.add_theme_stylebox_override("normal", _make_box_style(Color(_fx_target_col.r * 0.25, _fx_target_col.g * 0.25, _fx_target_col.b * 0.25, 0.96), _fx_target_col, 8, 6))
	preview_btn.pressed.connect(func():
		sfx_requested.emit("card_ace_strike")
		_play_bankai_preview(sel_build_id)
	)
	bk_hdr.add_child(preview_btn)

	# 4 Glowing Bankai Rune Slots
	var slots_hb := HBoxContainer.new()
	slots_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hb.add_theme_constant_override("separation", 18)
	bk_vb.add_child(slots_hb)

	var combo_arr: Array = _profile.get("bankai_combo", cur_build.get("default_bankai", []))
	for si in range(4):
		var ck := str(combo_arr[si]) if si < combo_arr.size() else "CERVEN_E"
		var is_ed := (si == _editing_bankai_slot)
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(148, 174)
		slot_btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.14, 0.10, 0.12, 0.98) if is_ed else Color(0.08, 0.06, 0.07, 0.95),
			Color(1.0, 0.90, 0.38) if is_ed else _fx_target_col, 10, 6
		))
		slot_btn.add_theme_stylebox_override("hover", _make_box_style(Color(0.18, 0.13, 0.15, 1.0), Color(1.0, 0.92, 0.46), 10, 6))

		var svb := VBoxContainer.new()
		svb.set_anchors_preset(Control.PRESET_FULL_RECT)
		svb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_btn.add_child(svb)

		var tex_r := TextureRect.new()
		tex_r.texture = _get_card_tex(ck)
		tex_r.custom_minimum_size = Vector2(96, 128)
		tex_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.add_child(tex_r)

		var cap := Label.new()
		cap.text = "SEAL %d • %s" % [si + 1, _pretty_card_key(ck)]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_theme_font_override("font", _font_disp)
		cap.add_theme_font_size_override("font_size", 12)
		cap.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52) if is_ed else Color(0.92, 0.88, 0.80))
		svb.add_child(cap)

		var slot_idx_cap := si
		slot_btn.pressed.connect(func():
			sfx_requested.emit("card_hover")
			_animate_btn_pop(slot_btn)
			_editing_bankai_slot = -1 if _editing_bankai_slot == slot_idx_cap else slot_idx_cap
			_rebuild_ui()
		)
		slots_hb.add_child(slot_btn)

	# Inline 32-card Picker whenever a Bankai Seal slot is selected!
	if _editing_bankai_slot >= 0 and _editing_bankai_slot < 4:
		_bankai_picker_wrap = PanelContainer.new()
		_bankai_picker_wrap.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.04, 0.055, 0.98), Color(1.0, 0.84, 0.34), 10, 10))
		bk_vb.add_child(_bankai_picker_wrap)

		var pk_vb := VBoxContainer.new()
		pk_vb.add_theme_constant_override("separation", 8)
		_bankai_picker_wrap.add_child(pk_vb)

		var pk_lbl := Label.new()
		pk_lbl.text = _tr("Pick a card for Bankai Seal Slot #%d:" % (_editing_bankai_slot + 1), "Vyber kartu pro Bankai Pečeť #%d:" % (_editing_bankai_slot + 1))
		pk_lbl.add_theme_font_override("font", _font_disp)
		pk_lbl.add_theme_font_size_override("font_size", 15)
		pk_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		pk_vb.add_child(pk_lbl)

		var pk_grid := GridContainer.new()
		pk_grid.columns = 8
		pk_grid.add_theme_constant_override("h_separation", 6)
		pk_grid.add_theme_constant_override("v_separation", 6)
		pk_vb.add_child(pk_grid)

		for s in SUITS:
			for r in RANKS:
				var key := "%s_%s" % [str(s["id"]), r]
				var already_in := key in combo_arr
				var pb := Button.new()
				pb.custom_minimum_size = Vector2(120, 34)
				pb.text = "%s %s" % [str(s["sym"]), r]
				pb.add_theme_font_override("font", _font_disp)
				pb.add_theme_font_size_override("font_size", 13)
				pb.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62) if already_in else (s["col"] as Color).lightened(0.25))
				pb.pressed.connect(func():
					sfx_requested.emit("ui_click")
					var next_c: Array = _profile.get("bankai_combo", []).duplicate()
					while next_c.size() < 4:
						next_c.append("CERVEN_E")
					next_c[_editing_bankai_slot] = key
					_profile["bankai_combo"] = next_c
					_editing_bankai_slot = -1
					_sync_and_save()
					_rebuild_ui()
				)
				pk_grid.add_child(pb)

	# === SECTION 3: 8 CORE RELICS (2 EQUIPPED) & POWER CARDS (3 EQUIPPED) ===
	var lower_hb := HBoxContainer.new()
	lower_hb.add_theme_constant_override("separation", 14)
	_content_vb.add_child(lower_hb)

	# Left Column: 8 Core Relics (4 Builds × 2)
	var rel_pan := PanelContainer.new()
	rel_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rel_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.048, 0.94), Color(0.84, 0.66, 0.28, 0.85), 10, 10))
	lower_hb.add_child(rel_pan)

	var rel_vb := VBoxContainer.new()
	rel_vb.add_theme_constant_override("separation", 8)
	rel_pan.add_child(rel_vb)

	var act_rels: Array = _profile.get("active_relics", [])
	var r_hdr := Label.new()
	r_hdr.text = _tr("✦ 8 CORE BUILD RELICS (Equipped: %d / 2)" % act_rels.size(), "✦ 8 HLAVNÍCH RELIKVIÍ (Vybaveno: %d / 2)" % act_rels.size())
	r_hdr.add_theme_font_override("font", _font_disp)
	r_hdr.add_theme_font_size_override("font_size", 16)
	r_hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	rel_vb.add_child(r_hdr)

	var rel_grid := GridContainer.new()
	rel_grid.columns = 2
	rel_grid.add_theme_constant_override("h_separation", 8)
	rel_grid.add_theme_constant_override("v_separation", 8)
	rel_vb.add_child(rel_grid)

	for r_raw in Catalog.RELICS:
		var rid := str(r_raw["id"])
		var rloc := Catalog.get_relic_loc(rid, _lang)
		var is_ul := Catalog.is_relic_unlocked(_profile, rid) or (rid in act_rels)
		var is_eq := rid in act_rels
		var is_sig := (str(r_raw.get("build_id", "")) == sel_build_id)
		var rb := Button.new()
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.custom_minimum_size = Vector2(0, 62)
		var star := "★ " if is_sig else ""
		var tag := _tr("✓ ON", "✓ AKT.") if is_eq else (_tr("Equip", "Vybrat") if is_ul else "⛓")
		rb.text = "%s%s [%s]\n%s" % [star, str(rloc["name"]), tag, str(rloc["category"])]
		rb.disabled = not is_ul
		rb.tooltip_text = str(rloc["desc"])
		rb.add_theme_font_override("font", _font_body)
		rb.add_theme_font_size_override("font_size", 13)
		rb.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.10, 0.24, 0.14, 0.96) if is_eq else (Color(0.11, 0.09, 0.075, 0.92) if is_ul else Color(0.06, 0.055, 0.06, 0.65)),
			Color(0.42, 1.0, 0.58) if is_eq else (rloc["col"] if is_sig else Color(0.42, 0.36, 0.28)), 8, 6
		))
		rb.pressed.connect(func():
			sfx_requested.emit("ui_click")
			var arr: Array = _profile.get("active_relics", []).duplicate()
			if rid in arr:
				arr.erase(rid)
			else:
				if arr.size() >= 2:
					arr.pop_front()
				arr.append(rid)
			_profile["active_relics"] = arr
			_sync_and_save()
			_rebuild_ui()
		)
		rel_grid.add_child(rb)

	# Right Column: Power Cards (Max 3) + Card Class Sculptor
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 10)
	lower_hb.add_child(right_vb)

	var pc_pan := PanelContainer.new()
	pc_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.065, 0.94), Color(0.68, 0.46, 0.96, 0.85), 10, 10))
	right_vb.add_child(pc_pan)

	var pc_vb := VBoxContainer.new()
	pc_vb.add_theme_constant_override("separation", 8)
	pc_pan.add_child(pc_vb)

	var eq_pcs: Array = _profile.get("custom_cards", [])
	var pc_hdr := Label.new()
	pc_hdr.text = _tr("✦ POWER CARDS IN DECK (%d / 3)" % eq_pcs.size(), "✦ MOCNÉ KARTY V BALÍČKU (%d / 3)" % eq_pcs.size())
	pc_hdr.add_theme_font_override("font", _font_disp)
	pc_hdr.add_theme_font_size_override("font_size", 16)
	pc_hdr.add_theme_color_override("font_color", Color(0.84, 0.70, 1.0))
	pc_vb.add_child(pc_hdr)

	var pc_grid := GridContainer.new()
	pc_grid.columns = 3
	pc_grid.add_theme_constant_override("h_separation", 6)
	pc_grid.add_theme_constant_override("v_separation", 6)
	pc_vb.add_child(pc_grid)

	for pc_raw in Catalog.POWER_CARDS:
		var pid := str(pc_raw["id"])
		var pcl := Catalog.get_power_card_loc(pid, _lang)
		var is_ul := Catalog.is_power_card_unlocked(_profile, pid) or (pid in eq_pcs)
		var is_eq := pid in eq_pcs
		var pb := Button.new()
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.custom_minimum_size = Vector2(0, 38)
		pb.text = ("%s%s" % ["✓ " if is_eq else ("" if is_ul else "⛓ "), str(pcl["short"])])
		pb.disabled = not is_ul
		pb.tooltip_text = "%s — %s" % [str(pcl["name"]), str(pcl["desc"])]
		pb.add_theme_font_override("font", _font_body)
		pb.add_theme_font_size_override("font_size", 12)
		pb.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.16, 0.11, 0.28, 0.96) if is_eq else Color(0.08, 0.07, 0.08, 0.85),
			pcl["accent"] if is_eq else Color(0.38, 0.34, 0.42), 6, 4
		))
		pb.pressed.connect(func():
			sfx_requested.emit("card_hover")
			var arr: Array = _profile.get("custom_cards", []).duplicate()
			if pid in arr:
				arr.erase(pid)
			else:
				if arr.size() >= 3:
					arr.pop_front()
				arr.append(pid)
			_profile["custom_cards"] = arr
			_sync_and_save()
			_rebuild_ui()
		)
		pc_grid.add_child(pb)

	# Card Class Customizer (quick-cycle Knight / Mage / Thief / Merchant on signature cards)
	var cls_pan := PanelContainer.new()
	cls_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.055, 0.06, 0.07, 0.94), Color(0.40, 0.82, 0.94, 0.80), 10, 10))
	right_vb.add_child(cls_pan)

	var cls_vb := VBoxContainer.new()
	cls_vb.add_theme_constant_override("separation", 6)
	cls_pan.add_child(cls_vb)

	var cls_hdr := Label.new()
	cls_hdr.text = _tr("⚔ CARD CLASS INFUSIONS (Click card to cycle Class)", "⚔ TŘÍDY KARET (Kliknutím změň třídu karty)")
	cls_hdr.add_theme_font_override("font", _font_disp)
	cls_hdr.add_theme_font_size_override("font_size", 15)
	cls_hdr.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0))
	cls_vb.add_child(cls_hdr)

	var cls_grid := GridContainer.new()
	cls_grid.columns = 4
	cls_grid.add_theme_constant_override("h_separation", 6)
	cls_grid.add_theme_constant_override("v_separation", 6)
	cls_vb.add_child(cls_grid)

	var ce: Dictionary = _profile.get("card_editions", {})
	var featured_keys := ["CERVEN_E", "ZALUD_E", "CERVEN_K", "GULA_K", "CERVEN_7", "ZELEN_7", "ZELEN_8", "GULA_8"]
	for fk in featured_keys:
		var cur_cls := Catalog.normalize_card_class(str(ce.get(fk, "NORMAL")))
		var cls_d := Catalog.get_card_class_loc(cur_cls, _lang)
		var cb := Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 34)
		cb.text = "%s: %s" % [_pretty_card_key(fk), str(cls_d.get("short_cls", cur_cls))]
		cb.add_theme_font_override("font", _font_body)
		cb.add_theme_font_size_override("font_size", 12)
		cb.add_theme_color_override("font_color", cls_d["col"])
		cb.pressed.connect(func():
			sfx_requested.emit("card_hover")
			var idx := CLASS_CYCLE.find(cur_cls)
			var next_cls: String = str(CLASS_CYCLE[(idx + 1) % CLASS_CYCLE.size()])
			var ce_map: Dictionary = _profile.get("card_editions", {}).duplicate()
			if next_cls == "NORMAL":
				ce_map.erase(fk)
			else:
				ce_map[fk] = next_cls
			_profile["card_editions"] = ce_map
			_sync_and_save()
			_rebuild_ui()
		)
		cls_grid.add_child(cb)


func _pretty_card_key(ck: String) -> String:
	return ck.replace("CERVEN_", "♥").replace("ZELEN_", "♠").replace("ZALUD_", "♣").replace("GULA_", "●")


func _play_bankai_preview(build_id: String) -> void:
	if not is_instance_valid(_bankai_fx_preview):
		_bankai_fx_preview = BankaiFxScript.new()
		_bankai_fx_preview.layer = 98
		add_child(_bankai_fx_preview)
	var combo_arr: Array = _profile.get("bankai_combo", [])
	_bankai_fx_preview.trigger_bankai(build_id, _tr("DECK PREVIEW", "UKÁZKA BALÍČKU"), combo_arr, _lang, false)
