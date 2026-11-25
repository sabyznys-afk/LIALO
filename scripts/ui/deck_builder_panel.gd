class_name DeckBuilderPanel
extends Control
## Unified 5-Step Wizard Deck Builder (Campaign + Multiplayer) for LIALO v0.193
## Step 1: Base Cards & Archetype Selection
## Step 2: Power Cards (Max 3, Max 1 Mythic)
## Step 3: 4-Card Grand Seal (4/4) + Live FX Preview
## Step 4: 2x Core Relics, 2x Tabletop Relics (with 3D Inspect), Card Back & Sword
## Step 5: Name & Save (Named Decks + Save & Play)

signal deck_changed(profile: Dictionary)
signal sfx_requested(sfx_name: String)

const Catalog := preload("res://scripts/lialo_catalog.gd")
const Toon := preload("res://scripts/toon_style.gd")
const LialoIcons := preload("res://scripts/ui/lialo_icons.gd")
const BankaiFxScript := preload("res://scripts/battle/bankai_fx.gd")
const RELIC_INSPECT_PATH := "res://scripts/ui/relic_inspect_3d.gd"

const SUITS := [
	{"id": "CERVEN", "icon": "heart",  "en": "Hearts", "cs": "Červený", "col": Color(0.92, 0.24, 0.28)},
	{"id": "ZELEN",  "icon": "leaves", "en": "Leaves", "cs": "Zelený",  "col": Color(0.24, 0.78, 0.52)},
	{"id": "ZALUD",  "icon": "acorn",  "en": "Acorns", "cs": "Žaludy",  "col": Color(0.86, 0.64, 0.34)},
	{"id": "GULA",   "icon": "bell",   "en": "Bells",  "cs": "Kule",    "col": Color(0.98, 0.62, 0.22)},
]
const RANKS := ["7", "8", "9", "10", "D", "H", "K", "E"]
const CLASS_CYCLE := ["NORMAL", "KNIGHT", "MAGE", "THIEF", "MERCHANT"]

const CARD_BACKS := [
	{"id": "klasic",     "en": "Classic Leather", "cs": "Klasická kůže",     "tex": "res://assets/table/deck_back_klasic.png",     "col": Color(0.85, 0.68, 0.30)},
	{"id": "antika",     "en": "Pharaoh's Vault", "cs": "Faraonův poklad",   "tex": "res://assets/table/deck_back_antika.png",     "col": Color(0.96, 0.74, 0.26)},
	{"id": "rim",        "en": "Legion's Aegis",  "cs": "Štít legie",        "tex": "res://assets/table/deck_back_rim.png",        "col": Color(0.91, 0.44, 0.32)},
	{"id": "stredovek",  "en": "Iron Crown",      "cs": "Železná koruna",    "tex": "res://assets/table/deck_back_stredovek.png",  "col": Color(0.58, 0.83, 0.69)},
	{"id": "objavy",     "en": "Corsair's Grip",  "cs": "Korzárův stisk",    "tex": "res://assets/table/deck_back_objavy.png",     "col": Color(0.30, 0.78, 0.94)},
	{"id": "prohibicia", "en": "Syndicate Noir",  "cs": "Syndikát prohibice","tex": "res://assets/table/deck_back_prohibicia.png", "col": Color(0.96, 0.76, 0.26)},
	{"id": "obsidian",   "en": "Obsidian Seal",   "cs": "Obsidiánová pečeť", "tex": "res://assets/table/deck_back_obsidian.png",   "col": Color(0.96, 0.18, 0.26)},
	{"id": "astral",     "en": "Astral Compass",  "cs": "Astrální kompas",   "tex": "res://assets/table/deck_back_astral.png",     "col": Color(0.24, 0.90, 1.0)},
]

const BUILD_ICONS := {
	"GUILLOTINE_ACES": "dagger",
	"PHOENIX_CHAINS": "fire",
	"MIRROR_TRICKS": "mist",
	"CRIMSON_GAMBIT": "blood",
}

var _profile: Dictionary = {}
var _lang: String = "en"
var _font_disp: Font
var _font_body: Font
var _card_cache: Dictionary = {}

var _current_step: int = 0
var _step_dir: int = 1
var _bg_fx: Control
var _content_vb: VBoxContainer
var _step_body_wrap: Control
var _step_tween: Tween
var _editing_seal_slot: int = -1
var _seal_picker_wrap: PanelContainer
var _bankai_fx_preview: BankaiFxScript
var _relic_inspect: Control
var _deck_name_edit: LineEdit
var _status_toast: Label

var _fx_time: float = 0.0
var _fx_col: Color = Color(0.32, 0.88, 1.0)
var _fx_target_col: Color = Color(0.32, 0.88, 1.0)
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(1160, 780)
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
	_content_vb.add_theme_constant_override("separation", 12)
	margin.add_child(_content_vb)


func setup_builder(prof: Dictionary, lang: String = "en", card_face_cache: Dictionary = {}) -> void:
	_profile = prof
	_lang = lang
	_card_cache = card_face_cache
	_editing_seal_slot = -1
	_sanitize_local_loadout()
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
	_bg_fx.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.045, 0.036, 0.042, 0.84))
	var center := Vector2(sz.x * 0.5, 290.0)
	var r := minf(sz.x * 0.34, 240.0)
	_bg_fx.draw_arc(center, r, 0.0, TAU, 80, Color(_fx_col.r, _fx_col.g, _fx_col.b, 0.16), 2.2)
	_bg_fx.draw_arc(center, r * 0.78, 0.0, TAU, 64, Color(_fx_col.r, _fx_col.g, _fx_col.b, 0.10), 1.4)
	for ti in range(16):
		var a := float(ti) * (TAU / 16.0) + _fx_time * 0.22
		var p1 := center + Vector2(cos(a), sin(a)) * (r * 0.94)
		var p2 := center + Vector2(cos(a), sin(a)) * (r * 1.04)
		_bg_fx.draw_line(p1, p2, Color(_fx_col.r, _fx_col.g, _fx_col.b, 0.22), 1.8)
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


func _sanitize_local_loadout() -> void:
	# Deduplicate and cap power cards to LialoCatalog.MAX_POWER_CARDS (3), max 1 Mythic
	var raw_pc: Array = _profile.get("custom_cards", [])
	if raw_pc.is_empty() and _profile.get("mp_loadout") is Dictionary:
		raw_pc = (_profile["mp_loadout"] as Dictionary).get("power_cards", [])
	var clean_pc: Array = []
	var mythic_cnt := 0
	for pv in raw_pc:
		var pid := str(pv)
		if pid in clean_pc:
			continue
		var pdata := Catalog.get_power_card(pid)
		if pdata.is_empty():
			continue
		if str(pdata.get("rarity", "")) == "Mythic":
			if mythic_cnt >= 1:
				continue
			mythic_cnt += 1
		clean_pc.append(pid)
		if clean_pc.size() >= Catalog.MAX_POWER_CARDS:
			break
	_profile["custom_cards"] = clean_pc

	# Deduplicate and cap Core Relics to LialoCatalog.MAX_ACTIVE_RELICS (2)
	var raw_ar: Array = _profile.get("active_relics", [])
	var clean_ar: Array = []
	for rv in raw_ar:
		var rid := str(rv)
		if rid in clean_ar or Catalog.get_relic(rid).is_empty():
			continue
		clean_ar.append(rid)
		if clean_ar.size() >= Catalog.MAX_ACTIVE_RELICS:
			break
	_profile["active_relics"] = clean_ar

	# Deduplicate and cap Tabletop 3D Relics to 2
	var raw_tr: Array = _profile.get("table_relics", [])
	var clean_tr: Array = []
	for tv in raw_tr:
		var tid := str(tv)
		if tid in clean_tr or Catalog.get_table_relic(tid).is_empty():
			continue
		clean_tr.append(tid)
		if clean_tr.size() >= 2:
			break
	_profile["table_relics"] = clean_tr

	# Ensure 4-card Grand Seal combo
	var cur_b := Catalog.get_deck_build(str(_profile.get("selected_build_id", "GUILLOTINE_ACES")))
	var def_seal: Array = cur_b.get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"])
	var raw_seal: Array = _profile.get("bankai_combo", [])
	var clean_seal: Array = []
	for sv in raw_seal:
		var sk := str(sv)
		if sk != "" and clean_seal.size() < 4:
			clean_seal.append(sk)
	while clean_seal.size() < 4:
		clean_seal.append(str(def_seal[clean_seal.size() % def_seal.size()]))
	_profile["bankai_combo"] = clean_seal


func _sync_and_save() -> void:
	_sanitize_local_loadout()
	var sel_b := str(_profile.get("selected_build_id", "GUILLOTINE_ACES"))
	var b_combo: Array = _profile.get("bankai_combo", []).duplicate()
	var act_rel: Array = _profile.get("active_relics", []).duplicate()
	var tbl_rel: Array = _profile.get("table_relics", []).duplicate()
	var cust_pc: Array = _profile.get("custom_cards", []).duplicate()
	if not _profile.has("mp_loadout") or not (_profile["mp_loadout"] is Dictionary):
		_profile["mp_loadout"] = {}
	var mpl: Dictionary = _profile["mp_loadout"]
	mpl["archetype_id"] = sel_b
	mpl["bankai_combo"] = b_combo
	mpl["passive_relics"] = act_rel.slice(0, Catalog.MAX_ACTIVE_RELICS)
	mpl["table_relics"] = tbl_rel.slice(0, 2)
	mpl["power_cards"] = cust_pc.slice(0, Catalog.MAX_POWER_CARDS)
	mpl["sword_skin"] = str(_profile.get("equipped_sword", "SWORD_IRON"))
	Catalog.save_profile(_profile)
	deck_changed.emit(_profile)


func _animate_btn_pop(ctrl: Control) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale", Vector2(1.06, 1.06), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _go_to_step(step_idx: int) -> void:
	var clamped := clampi(step_idx, 0, 4)
	_step_dir = 1 if clamped >= _current_step else -1
	_current_step = clamped
	_editing_seal_slot = -1
	_rebuild_ui(true)


func _ensure_relic_inspect() -> Control:
	if is_instance_valid(_relic_inspect):
		return _relic_inspect
	var script_res := load(RELIC_INSPECT_PATH) as GDScript
	if script_res == null:
		return null
	_relic_inspect = script_res.new() as Control
	var host: Node = get_tree().root if get_tree() != null else self
	var parent_layer: Node = self
	# Try to attach to nearest CanvasLayer ancestor so modal covers full viewport cleanly
	var p := get_parent()
	while p != null:
		if p is CanvasLayer:
			parent_layer = p
			break
		p = p.get_parent()
	if parent_layer == self and host != self:
		parent_layer = self
	parent_layer.add_child(_relic_inspect)
	return _relic_inspect


func _open_relic_inspect(relic_id: String, is_unlocked: bool, is_equipped: bool, source_text: String = "") -> void:
	sfx_requested.emit("ui_click")
	var modal := _ensure_relic_inspect()
	if modal != null and modal.has_method("inspect_relic"):
		modal.call("inspect_relic", relic_id, _lang, is_unlocked, is_equipped, source_text)


func _rebuild_ui(animate_step: bool = false) -> void:
	if not is_instance_valid(_content_vb):
		return
	_sanitize_local_loadout()
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
	hdr_hb.add_theme_constant_override("separation", 12)
	hdr_pan.add_child(hdr_hb)

	hdr_hb.add_child(LialoIcons.make_icon_rect("cards", 28, Color(1.0, 0.88, 0.44)))

	var hdr_vb := VBoxContainer.new()
	hdr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hb.add_child(hdr_vb)

	var t_lbl := Label.new()
	t_lbl.text = _tr("DECK FORGE WIZARD — CAMPAIGN & MULTIPLAYER", "TVORBA BALÍČKU — KAMPAŇ & MULTIPLAYER")
	t_lbl.add_theme_font_override("font", _font_disp)
	t_lbl.add_theme_font_size_override("font_size", 21)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	hdr_vb.add_child(t_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = _tr(
		"Step %d of 5 • Build: %s • Synced to Campaign & Online Duels" % [_current_step + 1, str(cur_build["name"])],
		"Krok %d z 5 • Build: %s • Synchronizováno s kampaní i online duely" % [_current_step + 1, str(cur_build["name"])]
	)
	sub_lbl.add_theme_font_override("font", _font_body)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
	hdr_vb.add_child(sub_lbl)

	var sync_row := LialoIcons.make_icon_label_row("check", _tr("CAMPAIGN + MP SYNCED", "KAMPAŇ + MP SYNC"), 16, 13, Color(0.42, 1.0, 0.62))
	hdr_hb.add_child(sync_row)

	# === TOP 5-STEP PROGRESS BAR ===
	var pc_cnt: int = (_profile.get("custom_cards", []) as Array).size()
	var step_defs := [
		{"icon": "cards", "en": "1. Base Cards", "cs": "1. Základní karty"},
		{"icon": "bolt",  "en": "2. Power Cards (%d/%d)" % [pc_cnt, Catalog.MAX_POWER_CARDS], "cs": "2. Mocné karty (%d/%d)" % [pc_cnt, Catalog.MAX_POWER_CARDS]},
		{"icon": "seal",  "en": "3. Grand Seal (4 Cards)", "cs": "3. Velká pečeť (4 karty)"},
		{"icon": "relic", "en": "4. 2x Relics, Back & Sword", "cs": "4. 2x Relikvie, rub a meč"},
		{"icon": "check", "en": "5. Name & Save", "cs": "5. Název a uložení"},
	]
	var prog_hb := HBoxContainer.new()
	prog_hb.add_theme_constant_override("separation", 8)
	_content_vb.add_child(prog_hb)

	for si in range(step_defs.size()):
		var sd: Dictionary = step_defs[si]
		var is_cur := (si == _current_step)
		var is_done := (si < _current_step)
		var sb := Button.new()
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size = Vector2(0, 44)
		sb.text = _tr(str(sd["en"]), str(sd["cs"]))
		LialoIcons.apply_button_icon(sb, str(sd["icon"]), 18)
		sb.add_theme_font_override("font", _font_disp)
		sb.add_theme_font_size_override("font_size", 13)
		sb.add_theme_color_override("font_color", Color.WHITE if is_cur else (Color(0.56, 0.96, 0.66) if is_done else Color(0.78, 0.74, 0.68)))
		sb.add_theme_stylebox_override("normal", _make_box_style(
			Color(_fx_target_col.r * 0.28, _fx_target_col.g * 0.28, _fx_target_col.b * 0.28, 0.98) if is_cur else (Color(0.08, 0.16, 0.10, 0.90) if is_done else Color(0.07, 0.06, 0.06, 0.88)),
			_fx_target_col if is_cur else (Color(0.38, 0.82, 0.48, 0.85) if is_done else Color(0.34, 0.28, 0.22, 0.70)),
			8, 6
		))
		sb.add_theme_stylebox_override("hover", _make_box_style(
			Color(_fx_target_col.r * 0.34, _fx_target_col.g * 0.34, _fx_target_col.b * 0.34, 1.0),
			_fx_target_col.lightened(0.2), 8, 6
		))
		var target_step := si
		sb.pressed.connect(func():
			sfx_requested.emit("ui_click")
			_go_to_step(target_step)
		)
		prog_hb.add_child(sb)

	# === STEP BODY CONTAINER (Animated with Tween) ===
	_step_body_wrap = VBoxContainer.new()
	_step_body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_body_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(_step_body_wrap as VBoxContainer).add_theme_constant_override("separation", 12)
	_content_vb.add_child(_step_body_wrap)

	match _current_step:
		0: _build_step_1_base_cards(_step_body_wrap as VBoxContainer, sel_build_id)
		1: _build_step_2_power_cards(_step_body_wrap as VBoxContainer)
		2: _build_step_3_grand_seal(_step_body_wrap as VBoxContainer, sel_build_id, cur_build)
		3: _build_step_4_relics_cosmetics(_step_body_wrap as VBoxContainer, sel_build_id)
		4: _build_step_5_name_save(_step_body_wrap as VBoxContainer, sel_build_id, cur_build)

	# === BOTTOM WIZARD NAVIGATION BAR ===
	var nav_hb := HBoxContainer.new()
	nav_hb.add_theme_constant_override("separation", 12)
	_content_vb.add_child(nav_hb)

	var prev_btn := Button.new()
	prev_btn.custom_minimum_size = Vector2(180, 44)
	prev_btn.text = _tr("< Previous Step", "< Předchozí krok")
	prev_btn.disabled = (_current_step <= 0)
	prev_btn.add_theme_font_override("font", _font_disp)
	prev_btn.add_theme_font_size_override("font_size", 14)
	prev_btn.add_theme_stylebox_override("normal", _make_box_style(Color(0.09, 0.08, 0.08, 0.94), Color(0.55, 0.45, 0.30), 8, 8))
	prev_btn.pressed.connect(func():
		sfx_requested.emit("ui_click")
		_go_to_step(_current_step - 1)
	)
	nav_hb.add_child(prev_btn)

	_status_toast = Label.new()
	_status_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_toast.add_theme_font_override("font", _font_body)
	_status_toast.add_theme_font_size_override("font_size", 13)
	_status_toast.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	nav_hb.add_child(_status_toast)

	if _current_step < 4:
		var next_btn := Button.new()
		next_btn.custom_minimum_size = Vector2(210, 44)
		next_btn.text = _tr("Next Step >", "Další krok >")
		next_btn.add_theme_font_override("font", _font_disp)
		next_btn.add_theme_font_size_override("font_size", 15)
		next_btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(_fx_target_col.r * 0.26, _fx_target_col.g * 0.26, _fx_target_col.b * 0.26, 0.98),
			_fx_target_col, 8, 8
		))
		next_btn.pressed.connect(func():
			sfx_requested.emit("ui_click")
			_go_to_step(_current_step + 1)
		)
		nav_hb.add_child(next_btn)

	if animate_step and is_instance_valid(_step_body_wrap):
		if is_instance_valid(_step_tween):
			_step_tween.kill()
		_step_body_wrap.modulate.a = 0.0
		_step_body_wrap.position.x = float(_step_dir) * 28.0
		_step_tween = _step_body_wrap.create_tween()
		_step_tween.set_parallel(true)
		_step_tween.tween_property(_step_body_wrap, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_step_tween.tween_property(_step_body_wrap, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================================
# STEP 1: BASE CARDS & ARCHETYPE SELECTION
# ============================================================================
func _build_step_1_base_cards(parent: VBoxContainer, sel_build_id: String) -> void:
	var arch_pan := PanelContainer.new()
	arch_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.055, 0.94), _fx_target_col, 10, 12))
	parent.add_child(arch_pan)

	var arch_vb := VBoxContainer.new()
	arch_vb.add_theme_constant_override("separation", 10)
	arch_pan.add_child(arch_vb)

	arch_vb.add_child(LialoIcons.make_icon_label_row(
		"crown",
		_tr("CHOOSE DECK ARCHETYPE (4 PLAYSTYLES)", "VYBER ARCHETYP BALÍČKU (4 HERNÍ STYLY)"),
		20, 16, Color(1.0, 0.88, 0.44)
	))

	var builds_hb := HBoxContainer.new()
	builds_hb.add_theme_constant_override("separation", 10)
	arch_vb.add_child(builds_hb)

	for b_raw in Catalog.DECK_BUILDS:
		var bid := str(b_raw["id"])
		var b := Catalog.get_deck_build_loc(bid, _lang)
		var b_col: Color = b["col"]
		var is_sel := (bid == sel_build_id)
		var b_btn := Button.new()
		b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_btn.custom_minimum_size = Vector2(0, 78)
		var seal_name := str(b.get("bankai_name", "")).replace("Bankai", "Grand Seal").replace("BANKAI", "GRAND SEAL")
		b_btn.text = "%s\n%s" % [str(b["name"]), _tr("ACTIVE BUILD", "AKTIVNÍ BUILD") if is_sel else seal_name]
		LialoIcons.apply_button_icon(b_btn, "check" if is_sel else str(BUILD_ICONS.get(bid, "cards")), 22)
		b_btn.add_theme_font_override("font", _font_disp)
		b_btn.add_theme_font_size_override("font_size", 14)
		b_btn.add_theme_color_override("font_color", Color.WHITE if is_sel else Color(0.86, 0.82, 0.74))
		b_btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(b_col.r * 0.26, b_col.g * 0.26, b_col.b * 0.26, 0.96) if is_sel else Color(0.08, 0.065, 0.06, 0.90),
			b_col if is_sel else Color(0.42, 0.34, 0.24, 0.75), 10, 8
		))
		b_btn.add_theme_stylebox_override("hover", _make_box_style(
			Color(b_col.r * 0.34, b_col.g * 0.34, b_col.b * 0.34, 1.0), b_col.lightened(0.2), 10, 8
		))
		b_btn.pressed.connect(func():
			sfx_requested.emit("ui_click")
			_profile["selected_build_id"] = bid
			var def_b := Catalog.get_deck_build(bid)
			var auto_rels: Array = []
			for r_id in def_b.get("relics", []):
				if Catalog.is_relic_unlocked(_profile, str(r_id)):
					auto_rels.append(str(r_id))
			if not auto_rels.is_empty():
				_profile["active_relics"] = auto_rels.slice(0, Catalog.MAX_ACTIVE_RELICS)
			_sync_and_save()
			_rebuild_ui()
		)
		builds_hb.add_child(b_btn)

	# Base 32-Card Overview + Suit/Rank Notes
	var base_pan := PanelContainer.new()
	base_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.055, 0.05, 0.06, 0.94), Color(0.55, 0.45, 0.30, 0.80), 10, 12))
	parent.add_child(base_pan)

	var base_vb := VBoxContainer.new()
	base_vb.add_theme_constant_override("separation", 10)
	base_pan.add_child(base_vb)

	base_vb.add_child(LialoIcons.make_icon_label_row(
		"cards",
		_tr("BASE 32-CARD TAVERN DECK (4 SUITS × 8 RANKS: 7, 8, 9, 10, D, H, K, E)", "ZÁKLADNÍ BALÍČEK 32 KARET (4 BARVY × 8 HODNOSTÍ: 7, 8, 9, 10, D, H, K, E)"),
		18, 15, Color(0.95, 0.86, 0.62)
	))

	var suits_hb := HBoxContainer.new()
	suits_hb.add_theme_constant_override("separation", 10)
	base_vb.add_child(suits_hb)

	for s in SUITS:
		var sp := PanelContainer.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc: Color = s["col"]
		sp.add_theme_stylebox_override("panel", _make_box_style(Color(0.08, 0.065, 0.06, 0.92), Color(sc.r, sc.g, sc.b, 0.65), 8, 8))
		var svb := VBoxContainer.new()
		svb.add_theme_constant_override("separation", 4)
		sp.add_child(svb)
		svb.add_child(LialoIcons.make_icon_label_row(str(s["icon"]), _tr(str(s["en"]), str(s["cs"])), 18, 14, sc.lightened(0.2)))
		var r_lbl := Label.new()
		r_lbl.text = "7  8  9  10  D  H  K  E"
		r_lbl.add_theme_font_override("font", _font_body)
		r_lbl.add_theme_font_size_override("font_size", 12)
		r_lbl.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72))
		svb.add_child(r_lbl)
		suits_hb.add_child(sp)

	var note_lbl := Label.new()
	note_lbl.text = _tr(
		"Key Ranks: 7 (+2 Draw) • 8 (Chain Stack) • D (Shield) • H (Suit Shift) • K (Curse) • E (Ace Strike). Click signature cards below to infuse a Class:",
		"Klíčové karty: 7 (+2 lízání) • 8 (Řetězení) • D (Štít) • H (Změna barvy) • K (Kletba) • E (Úder esa). Kliknutím níže změň třídu karty:"
	)
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.add_theme_font_override("font", _font_body)
	note_lbl.add_theme_font_size_override("font_size", 13)
	note_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74))
	base_vb.add_child(note_lbl)

	var cls_grid := GridContainer.new()
	cls_grid.columns = 4
	cls_grid.add_theme_constant_override("h_separation", 8)
	cls_grid.add_theme_constant_override("v_separation", 8)
	base_vb.add_child(cls_grid)

	var ce: Dictionary = _profile.get("card_editions", {})
	var featured_keys := ["CERVEN_E", "ZALUD_E", "CERVEN_K", "GULA_K", "CERVEN_7", "ZELEN_7", "ZELEN_8", "GULA_8"]
	for fk in featured_keys:
		var cur_cls := Catalog.normalize_card_class(str(ce.get(fk, "NORMAL")))
		var cls_d := Catalog.get_card_class_loc(cur_cls, _lang)
		var cb := Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 38)
		cb.text = "%s: %s" % [_pretty_card_key(fk), str(cls_d.get("short_cls", cur_cls))]
		LialoIcons.apply_button_icon(cb, _suit_icon_for_key(fk), 16)
		cb.add_theme_font_override("font", _font_body)
		cb.add_theme_font_size_override("font_size", 13)
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


# ============================================================================
# STEP 2: POWER CARDS (MAX 3, MAX 1 MYTHIC)
# ============================================================================
func _build_step_2_power_cards(parent: VBoxContainer) -> void:
	var eq_pcs: Array = _profile.get("custom_cards", [])
	var mythic_equipped := 0
	for ep in eq_pcs:
		var pd := Catalog.get_power_card(str(ep))
		if str(pd.get("rarity", "")) == "Mythic":
			mythic_equipped += 1

	var pc_pan := PanelContainer.new()
	pc_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.065, 0.94), Color(0.68, 0.46, 0.96, 0.85), 10, 12))
	parent.add_child(pc_pan)

	var pc_vb := VBoxContainer.new()
	pc_vb.add_theme_constant_override("separation", 10)
	pc_pan.add_child(pc_vb)

	var hdr_hb := HBoxContainer.new()
	hdr_hb.add_theme_constant_override("separation", 10)
	pc_vb.add_child(hdr_hb)
	hdr_hb.add_child(LialoIcons.make_icon_label_row(
		"bolt",
		_tr(
			"POWER CARDS IN DECK (%d / %d)  •  Mythic: %d / 1" % [eq_pcs.size(), Catalog.MAX_POWER_CARDS, mythic_equipped],
			"MOCNÉ KARTY V BALÍČKU (%d / %d)  •  Mýtická: %d / 1" % [eq_pcs.size(), Catalog.MAX_POWER_CARDS, mythic_equipped]
		),
		20, 16, Color(0.84, 0.70, 1.0)
	))

	var pc_grid := GridContainer.new()
	pc_grid.columns = 4
	pc_grid.add_theme_constant_override("h_separation", 8)
	pc_grid.add_theme_constant_override("v_separation", 8)
	pc_vb.add_child(pc_grid)

	for pc_raw in Catalog.POWER_CARDS:
		var pid := str(pc_raw["id"])
		var pcl := Catalog.get_power_card_loc(pid, _lang)
		var is_ul := Catalog.is_power_card_unlocked(_profile, pid) or (pid in eq_pcs)
		var is_eq := pid in eq_pcs
		var is_mythic := str(pc_raw.get("rarity", "")) == "Mythic"
		var pb := Button.new()
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.custom_minimum_size = Vector2(0, 56)
		var rar_tag := _tr(" [MYTHIC]", " [MÝTICKÁ]") if is_mythic else ""
		pb.text = "%s%s\n%s" % [str(pcl["short"]), rar_tag, _tr("EQUIPPED", "VYBAVENO") if is_eq else (_tr("Click to Equip", "Klikni pro výběr") if is_ul else _tr("Locked", "Zamčeno"))]
		LialoIcons.apply_button_icon(pb, "check" if is_eq else ("star" if is_mythic and is_ul else ("bolt" if is_ul else "lock")), 18)
		pb.disabled = not is_ul
		pb.tooltip_text = "%s — %s" % [str(pcl["name"]), str(pcl["desc"])]
		pb.add_theme_font_override("font", _font_body)
		pb.add_theme_font_size_override("font_size", 12)
		pb.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.16, 0.11, 0.28, 0.96) if is_eq else Color(0.08, 0.07, 0.08, 0.88),
			pcl["accent"] if is_eq else (Color(0.95, 0.72, 0.22, 0.75) if is_mythic else Color(0.38, 0.34, 0.42)),
			8, 6
		))
		pb.pressed.connect(func():
			sfx_requested.emit("card_hover")
			var arr: Array = _profile.get("custom_cards", []).duplicate()
			if pid in arr:
				arr.erase(pid)
			else:
				if is_mythic:
					# Enforce max 1 Mythic by replacing any existing Mythic
					var filtered: Array = []
					for existing_id in arr:
						if str(Catalog.get_power_card(str(existing_id)).get("rarity", "")) != "Mythic":
							filtered.append(existing_id)
					arr = filtered
				while arr.size() >= Catalog.MAX_POWER_CARDS:
					arr.pop_front()
				arr.append(pid)
			_profile["custom_cards"] = arr
			_sync_and_save()
			_rebuild_ui()
		)
		pc_grid.add_child(pb)


# ============================================================================
# STEP 3: 4-CARD GRAND SEAL (NO "Bankai" TEXT IN UI)
# ============================================================================
func _build_step_3_grand_seal(parent: VBoxContainer, sel_build_id: String, cur_build: Dictionary) -> void:
	var seal_pan := PanelContainer.new()
	seal_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.065, 0.048, 0.065, 0.95), _fx_target_col, 12, 12))
	parent.add_child(seal_pan)

	var bk_vb := VBoxContainer.new()
	bk_vb.add_theme_constant_override("separation", 10)
	seal_pan.add_child(bk_vb)

	var bk_hdr := HBoxContainer.new()
	bk_hdr.add_theme_constant_override("separation", 12)
	bk_vb.add_child(bk_hdr)

	var bk_info := VBoxContainer.new()
	bk_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bk_hdr.add_child(bk_info)

	var raw_seal_title := str(cur_build.get("bankai_name", "Grand Seal")).replace("Bankai", "Grand Seal").replace("BANKAI", "GRAND SEAL")
	bk_info.add_child(LialoIcons.make_icon_label_row(
		"seal",
		_tr("GRAND SEAL: %s (4 / 4 CARDS)" % raw_seal_title, "VELKÁ PEČEŤ: %s (4 / 4 KARTY)" % raw_seal_title),
		22, 18, _fx_target_col.lightened(0.25)
	))

	var bk_desc := Label.new()
	var clean_desc := str(cur_build.get("bankai_desc", "")).replace("Bankai", "Grand Seal").replace("BANKAI", "GRAND SEAL")
	bk_desc.text = "%s\n%s" % [
		clean_desc,
		_tr("Play all 4 Seal cards (in 1 slam or across the duel 0/4 -> 4/4) to unleash your Grand Seal!", "Zahraj všechny 4 karty Pečeti (najednou nebo během duelu 0/4 -> 4/4) pro spuštění Velké Pečeti!")
	]
	bk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bk_desc.add_theme_font_override("font", _font_body)
	bk_desc.add_theme_font_size_override("font_size", 14)
	bk_desc.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	bk_info.add_child(bk_desc)

	var preset_btn := Button.new()
	preset_btn.text = _tr("Build Preset", "Výchozí pečeť")
	preset_btn.custom_minimum_size = Vector2(150, 40)
	LialoIcons.apply_button_icon(preset_btn, "redraw", 16)
	preset_btn.add_theme_font_override("font", _font_disp)
	preset_btn.add_theme_font_size_override("font_size", 13)
	preset_btn.pressed.connect(func():
		sfx_requested.emit("card_shuffle")
		_profile["bankai_combo"] = (cur_build.get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]) as Array).duplicate()
		_editing_seal_slot = -1
		_sync_and_save()
		_rebuild_ui()
	)
	bk_hdr.add_child(preset_btn)

	var preview_btn := Button.new()
	preview_btn.text = _tr("Preview Grand Seal FX", "Ukázka Velké Pečeti")
	preview_btn.custom_minimum_size = Vector2(198, 40)
	LialoIcons.apply_button_icon(preview_btn, "bolt", 16)
	preview_btn.add_theme_font_override("font", _font_disp)
	preview_btn.add_theme_font_size_override("font_size", 13)
	preview_btn.add_theme_stylebox_override("normal", _make_box_style(Color(_fx_target_col.r * 0.25, _fx_target_col.g * 0.25, _fx_target_col.b * 0.25, 0.96), _fx_target_col, 8, 6))
	preview_btn.pressed.connect(func():
		sfx_requested.emit("card_ace_strike")
		_play_grand_seal_preview(sel_build_id)
	)
	bk_hdr.add_child(preview_btn)

	# 4 Glowing Grand Seal Slots
	var slots_hb := HBoxContainer.new()
	slots_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hb.add_theme_constant_override("separation", 18)
	bk_vb.add_child(slots_hb)

	var combo_arr: Array = _profile.get("bankai_combo", cur_build.get("default_bankai", []))
	for si in range(4):
		var ck := str(combo_arr[si]) if si < combo_arr.size() else "CERVEN_E"
		var is_ed := (si == _editing_seal_slot)
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
		cap.text = "%s %d • %s" % [_tr("SEAL", "PEČEŤ"), si + 1, _pretty_card_key(ck)]
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
			_editing_seal_slot = -1 if _editing_seal_slot == slot_idx_cap else slot_idx_cap
			_rebuild_ui()
		)
		slots_hb.add_child(slot_btn)

	if _editing_seal_slot >= 0 and _editing_seal_slot < 4:
		_seal_picker_wrap = PanelContainer.new()
		_seal_picker_wrap.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.04, 0.055, 0.98), Color(1.0, 0.84, 0.34), 10, 10))
		bk_vb.add_child(_seal_picker_wrap)

		var pk_vb := VBoxContainer.new()
		pk_vb.add_theme_constant_override("separation", 8)
		_seal_picker_wrap.add_child(pk_vb)

		var pk_lbl := Label.new()
		pk_lbl.text = _tr("Pick a card for Grand Seal Slot #%d:" % (_editing_seal_slot + 1), "Vyber kartu pro Velkou Pečeť #%d:" % (_editing_seal_slot + 1))
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
				pb.custom_minimum_size = Vector2(118, 34)
				pb.text = r
				LialoIcons.apply_button_icon(pb, str(s["icon"]), 16)
				pb.add_theme_font_override("font", _font_disp)
				pb.add_theme_font_size_override("font_size", 13)
				pb.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62) if already_in else (s["col"] as Color).lightened(0.25))
				pb.pressed.connect(func():
					sfx_requested.emit("ui_click")
					var next_c: Array = _profile.get("bankai_combo", []).duplicate()
					while next_c.size() < 4:
						next_c.append("CERVEN_E")
					next_c[_editing_seal_slot] = key
					_profile["bankai_combo"] = next_c
					_editing_seal_slot = -1
					_sync_and_save()
					_rebuild_ui()
				)
				pk_grid.add_child(pb)


# ============================================================================
# STEP 4: 2x CORE RELICS, 2x TABLETOP 3D RELICS, CARD BACK & SWORD SKIN
# ============================================================================
func _build_step_4_relics_cosmetics(parent: VBoxContainer, sel_build_id: String) -> void:
	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 12)
	parent.add_child(top_hb)

	# Left: 2x Passive Core Relics
	var act_rels: Array = _profile.get("active_relics", [])
	var rel_pan := PanelContainer.new()
	rel_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rel_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.048, 0.94), Color(0.84, 0.66, 0.28, 0.85), 10, 10))
	top_hb.add_child(rel_pan)

	var rel_vb := VBoxContainer.new()
	rel_vb.add_theme_constant_override("separation", 6)
	rel_pan.add_child(rel_vb)

	rel_vb.add_child(LialoIcons.make_icon_label_row(
		"relic",
		_tr("CORE PASSIVE RELICS (%d / %d)" % [act_rels.size(), Catalog.MAX_ACTIVE_RELICS], "PASIVNÍ RELIKVIE (%d / %d)" % [act_rels.size(), Catalog.MAX_ACTIVE_RELICS]),
		18, 15, Color(1.0, 0.86, 0.42)
	))

	for r_raw in Catalog.RELICS:
		var rid := str(r_raw["id"])
		if Catalog.is_relic_hidden(rid):
			continue
		var rloc := Catalog.get_relic_loc(rid, _lang)
		var is_ul := Catalog.is_relic_unlocked(_profile, rid) or (rid in act_rels)
		var is_eq := rid in act_rels
		var is_sig := (str(r_raw.get("build_id", "")) == sel_build_id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		rel_vb.add_child(row)

		var rb := Button.new()
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.custom_minimum_size = Vector2(0, 38)
		var tag := _tr("EQUIPPED", "VYBAVENO") if is_eq else (_tr("Equip", "Vybrat") if is_ul else _tr("Locked", "Zamčeno"))
		rb.text = "%s [%s]" % [str(rloc["name"]), tag]
		LialoIcons.apply_button_icon(rb, "check" if is_eq else ("star" if is_sig and is_ul else ("relic" if is_ul else "lock")), 16)
		rb.disabled = not is_ul
		rb.tooltip_text = str(rloc["desc"])
		rb.add_theme_font_override("font", _font_body)
		rb.add_theme_font_size_override("font_size", 12)
		rb.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.10, 0.24, 0.14, 0.96) if is_eq else Color(0.10, 0.085, 0.075, 0.90),
			Color(0.42, 1.0, 0.58) if is_eq else (rloc["col"] if is_sig else Color(0.42, 0.36, 0.28)), 6, 4
		))
		rb.pressed.connect(func():
			sfx_requested.emit("ui_click")
			var arr: Array = _profile.get("active_relics", []).duplicate()
			if rid in arr:
				arr.erase(rid)
			else:
				while arr.size() >= Catalog.MAX_ACTIVE_RELICS:
					arr.pop_front()
				arr.append(rid)
			_profile["active_relics"] = arr
			_sync_and_save()
			_rebuild_ui()
		)
		row.add_child(rb)

		var insp := Button.new()
		insp.custom_minimum_size = Vector2(76, 38)
		insp.text = "3D"
		LialoIcons.apply_button_icon(insp, "help", 14)
		insp.tooltip_text = _tr("Inspect 3D Relic", "Prohlédnout 3D relikvii")
		insp.pressed.connect(func():
			_open_relic_inspect(rid, is_ul, is_eq, Catalog.get_unlock_source_label(rid, _lang))
		)
		row.add_child(insp)

	# Right: 2x Active Tabletop 3D Relics
	var tbl_rels: Array = _profile.get("table_relics", [])
	var tr_pan := PanelContainer.new()
	tr_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.065, 0.94), Color(0.46, 0.78, 0.96, 0.85), 10, 10))
	top_hb.add_child(tr_pan)

	var tr_vb := VBoxContainer.new()
	tr_vb.add_theme_constant_override("separation", 6)
	tr_pan.add_child(tr_vb)

	tr_vb.add_child(LialoIcons.make_icon_label_row(
		"trophy",
		_tr("TABLETOP 3D RELICS (%d / 2)" % tbl_rels.size(), "STOLNÍ 3D RELIKVIE (%d / 2)" % tbl_rels.size()),
		18, 15, Color(0.58, 0.88, 1.0)
	))

	for t_raw in Catalog.TABLE_RELICS:
		var tid := str(t_raw["id"])
		var tloc := Catalog.get_table_relic_loc(tid, _lang)
		var is_ul := Catalog.is_table_relic_unlocked(_profile, tid) or (tid in tbl_rels)
		var is_eq := tid in tbl_rels

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		tr_vb.add_child(row)

		var tb := Button.new()
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 34)
		var tag := _tr("ON TABLE", "NA STOLE") if is_eq else (_tr("Equip", "Vybrat") if is_ul else _tr("Locked", "Zamčeno"))
		tb.text = "%s [%s]" % [str(tloc["name"]), tag]
		LialoIcons.apply_button_icon(tb, "check" if is_eq else ("trophy" if is_ul else "lock"), 15)
		tb.disabled = not is_ul
		tb.tooltip_text = str(tloc["desc"])
		tb.add_theme_font_override("font", _font_body)
		tb.add_theme_font_size_override("font_size", 12)
		tb.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.10, 0.22, 0.28, 0.96) if is_eq else Color(0.08, 0.08, 0.10, 0.88),
			Color(0.42, 0.92, 1.0) if is_eq else Color(0.36, 0.40, 0.48), 6, 4
		))
		tb.pressed.connect(func():
			sfx_requested.emit("ui_click")
			var arr: Array = _profile.get("table_relics", []).duplicate()
			if tid in arr:
				arr.erase(tid)
			else:
				while arr.size() >= 2:
					arr.pop_front()
				arr.append(tid)
			_profile["table_relics"] = arr
			_sync_and_save()
			_rebuild_ui()
		)
		row.add_child(tb)

		var insp := Button.new()
		insp.custom_minimum_size = Vector2(76, 34)
		insp.text = "3D"
		LialoIcons.apply_button_icon(insp, "help", 14)
		insp.tooltip_text = _tr("Inspect 3D Relic", "Prohlédnout 3D relikvii")
		insp.pressed.connect(func():
			_open_relic_inspect(tid, is_ul, is_eq, str(tloc.get("unlock_hint", "")))
		)
		row.add_child(insp)

	# Bottom Row: Card Back & Sword Skin
	var cos_hb := HBoxContainer.new()
	cos_hb.add_theme_constant_override("separation", 12)
	parent.add_child(cos_hb)

	# Card Back
	var cb_pan := PanelContainer.new()
	cb_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.05, 0.94), Color(0.75, 0.60, 0.32, 0.80), 10, 10))
	cos_hb.add_child(cb_pan)

	var cb_vb := VBoxContainer.new()
	cb_vb.add_theme_constant_override("separation", 6)
	cb_pan.add_child(cb_vb)
	cb_vb.add_child(LialoIcons.make_icon_label_row("cards", _tr("CARD BACK", "RUB KARET"), 18, 15, Color(1.0, 0.88, 0.44)))

	var cb_grid := GridContainer.new()
	cb_grid.columns = 4
	cb_grid.add_theme_constant_override("h_separation", 6)
	cb_grid.add_theme_constant_override("v_separation", 6)
	cb_vb.add_child(cb_grid)

	var sel_deck := str(_profile.get("selected_deck", "klasic"))
	for d in CARD_BACKS:
		var did := str(d["id"])
		var is_sel := (did == sel_deck)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.text = _tr(str(d["en"]), str(d["cs"]))
		LialoIcons.apply_button_icon(btn, "check" if is_sel else "cards", 14)
		btn.add_theme_font_override("font", _font_body)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.14, 0.22, 0.14, 0.96) if is_sel else Color(0.08, 0.07, 0.07, 0.88),
			d["col"] if is_sel else Color(0.38, 0.34, 0.28), 6, 4
		))
		btn.pressed.connect(func():
			sfx_requested.emit("card_hover")
			_profile["selected_deck"] = did
			_sync_and_save()
			_rebuild_ui()
		)
		cb_grid.add_child(btn)

	# Sword Skin
	var sw_pan := PanelContainer.new()
	sw_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.05, 0.94), Color(0.75, 0.48, 0.32, 0.80), 10, 10))
	cos_hb.add_child(sw_pan)

	var sw_vb := VBoxContainer.new()
	sw_vb.add_theme_constant_override("separation", 6)
	sw_pan.add_child(sw_vb)
	sw_vb.add_child(LialoIcons.make_icon_label_row("sword", _tr("SWORD SKIN", "VZHLED MEČE"), 18, 15, Color(1.0, 0.80, 0.56)))

	var sw_grid := GridContainer.new()
	sw_grid.columns = 3
	sw_grid.add_theme_constant_override("h_separation", 6)
	sw_grid.add_theme_constant_override("v_separation", 6)
	sw_vb.add_child(sw_grid)

	var owned_sw: Array = _profile.get("unlocked_swords", ["SWORD_IRON"])
	var eq_sw := str(_profile.get("equipped_sword", "SWORD_IRON"))
	for sw_raw in Catalog.SWORD_SKINS:
		var sid := str(sw_raw["id"])
		var swl := Catalog.get_sword_skin_loc(sid, _lang)
		var is_ul := (sid in owned_sw) or (sid == "SWORD_IRON")
		var is_eq := (sid == eq_sw)
		var sbtn := Button.new()
		sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbtn.custom_minimum_size = Vector2(0, 36)
		sbtn.text = str(swl["name"])
		LialoIcons.apply_button_icon(sbtn, "check" if is_eq else ("sword" if is_ul else "lock"), 14)
		sbtn.disabled = not is_ul
		sbtn.tooltip_text = str(swl["desc"])
		sbtn.add_theme_font_override("font", _font_body)
		sbtn.add_theme_font_size_override("font_size", 12)
		sbtn.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.22, 0.14, 0.10, 0.96) if is_eq else Color(0.08, 0.07, 0.07, 0.88),
			swl["trail_col"] if is_eq else Color(0.38, 0.34, 0.28), 6, 4
		))
		sbtn.pressed.connect(func():
			sfx_requested.emit("ui_click")
			_profile["equipped_sword"] = sid
			_sync_and_save()
			_rebuild_ui()
		)
		sw_grid.add_child(sbtn)


# ============================================================================
# STEP 5: NAME & SAVE (NAMED DECKS + SAVE & PLAY)
# ============================================================================
func _build_step_5_name_save(parent: VBoxContainer, _sel_build_id: String, cur_build: Dictionary) -> void:
	var save_pan := PanelContainer.new()
	save_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.05, 0.055, 0.95), _fx_target_col, 12, 14))
	parent.add_child(save_pan)

	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 12)
	save_pan.add_child(svb)

	svb.add_child(LialoIcons.make_icon_label_row(
		"scroll",
		_tr("NAME & SAVE YOUR DECK", "POJMENUJ A ULOŽ SVŮJ BALÍČEK"),
		20, 17, Color(1.0, 0.88, 0.44)
	))

	var pc_arr: Array = _profile.get("custom_cards", [])
	var ar_arr: Array = _profile.get("active_relics", [])
	var tr_arr: Array = _profile.get("table_relics", [])
	var seal_arr: Array = _profile.get("bankai_combo", [])
	var sw_loc := Catalog.get_sword_skin_loc(str(_profile.get("equipped_sword", "SWORD_IRON")), _lang)
	var sum_lbl := Label.new()
	sum_lbl.text = _tr(
		"Build: %s  |  Power Cards: %d / %d  |  Grand Seal: %d / 4  |  Core Relics: %d / %d  |  Table Relics: %d / 2  |  Sword: %s" % [
			str(cur_build["name"]), pc_arr.size(), Catalog.MAX_POWER_CARDS, seal_arr.size(), ar_arr.size(), Catalog.MAX_ACTIVE_RELICS, tr_arr.size(), str(sw_loc["name"])
		],
		"Build: %s  |  Mocné karty: %d / %d  |  Velká pečeť: %d / 4  |  Relikvie: %d / %d  |  Stolní: %d / 2  |  Meč: %s" % [
			str(cur_build["name"]), pc_arr.size(), Catalog.MAX_POWER_CARDS, seal_arr.size(), ar_arr.size(), Catalog.MAX_ACTIVE_RELICS, tr_arr.size(), str(sw_loc["name"])
		]
	)
	sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sum_lbl.add_theme_font_override("font", _font_body)
	sum_lbl.add_theme_font_size_override("font_size", 13)
	sum_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
	svb.add_child(sum_lbl)

	var name_hb := HBoxContainer.new()
	name_hb.add_theme_constant_override("separation", 10)
	svb.add_child(name_hb)

	_deck_name_edit = LineEdit.new()
	_deck_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_name_edit.custom_minimum_size = Vector2(0, 44)
	_deck_name_edit.max_length = 28
	_deck_name_edit.placeholder_text = _tr("Enter deck name (e.g. Crimson Guillotine)...", "Zadej název balíčku (např. Rudá gilotina)...")
	_deck_name_edit.add_theme_font_override("font", _font_body)
	_deck_name_edit.add_theme_font_size_override("font_size", 14)
	name_hb.add_child(_deck_name_edit)

	var save_btn := Button.new()
	save_btn.custom_minimum_size = Vector2(170, 44)
	save_btn.text = _tr("Save Deck", "Uložit balíček")
	LialoIcons.apply_button_icon(save_btn, "scroll", 18)
	save_btn.add_theme_font_override("font", _font_disp)
	save_btn.add_theme_font_size_override("font_size", 14)
	save_btn.pressed.connect(func():
		sfx_requested.emit("ui_click")
		var dname := _deck_name_edit.text.strip_edges() if is_instance_valid(_deck_name_edit) else ""
		if dname.is_empty():
			dname = str(cur_build["name"])
		Catalog.save_named_deck(_profile, dname)
		_sync_and_save()
		_rebuild_ui()
		if is_instance_valid(_status_toast):
			_status_toast.text = _tr("Saved deck: %s" % dname, "Balíček uložen: %s" % dname)
	)
	name_hb.add_child(save_btn)

	var play_btn := Button.new()
	play_btn.custom_minimum_size = Vector2(210, 44)
	play_btn.text = _tr("SAVE & PLAY", "ULOŽIT A HRÁT")
	LialoIcons.apply_button_icon(play_btn, "check", 18)
	play_btn.add_theme_font_override("font", _font_disp)
	play_btn.add_theme_font_size_override("font_size", 15)
	play_btn.add_theme_stylebox_override("normal", _make_box_style(Color(0.14, 0.34, 0.18, 0.98), Color(0.45, 0.96, 0.56), 10, 8))
	play_btn.pressed.connect(func():
		sfx_requested.emit("ui_click")
		var dname := _deck_name_edit.text.strip_edges() if is_instance_valid(_deck_name_edit) else ""
		if not dname.is_empty():
			Catalog.save_named_deck(_profile, dname)
		_sync_and_save()
		if is_instance_valid(_status_toast):
			_status_toast.text = _tr("Loadout saved & ready for battle!", "Balíček uložen a připraven do boje!")
	)
	name_hb.add_child(play_btn)

	# Saved Decks List
	var list_pan := PanelContainer.new()
	list_pan.add_theme_stylebox_override("panel", _make_box_style(Color(0.055, 0.048, 0.055, 0.92), Color(0.48, 0.40, 0.28, 0.78), 10, 12))
	parent.add_child(list_pan)

	var lvb := VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 8)
	list_pan.add_child(lvb)

	var saved_decks: Array = _profile.get("saved_decks", [])
	lvb.add_child(LialoIcons.make_icon_label_row(
		"cards",
		_tr("SAVED DECK PRESETS (%d / 8)" % saved_decks.size(), "ULOŽENÉ BALÍČKY (%d / 8)" % saved_decks.size()),
		18, 15, Color(0.95, 0.85, 0.58)
	))

	if saved_decks.is_empty():
		var emp := Label.new()
		emp.text = _tr("No saved decks yet. Enter a name above and click Save Deck.", "Zatím nemáš uložený žádný balíček. Zadej název výše a klikni na Uložit.")
		emp.add_theme_font_override("font", _font_body)
		emp.add_theme_font_size_override("font_size", 13)
		emp.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
		lvb.add_child(emp)
	else:
		for d_v in saved_decks:
			if not (d_v is Dictionary):
				continue
			var d := d_v as Dictionary
			var did := str(d.get("id", ""))
			var dname := str(d.get("name", "Deck"))
			var db := Catalog.get_deck_build_loc(str(d.get("build_id", "GUILLOTINE_ACES")), _lang)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			lvb.add_child(row)

			var info := Label.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.text = "%s  •  %s  (%d Power, %d Relics)" % [
				dname, str(db["name"]),
				(d.get("power_cards", []) as Array).size(),
				(d.get("active_relics", []) as Array).size()
			]
			info.add_theme_font_override("font", _font_body)
			info.add_theme_font_size_override("font_size", 13)
			info.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
			row.add_child(info)

			var load_b := Button.new()
			load_b.custom_minimum_size = Vector2(110, 34)
			load_b.text = _tr("Load", "Načíst")
			LialoIcons.apply_button_icon(load_b, "check", 14)
			load_b.pressed.connect(func():
				sfx_requested.emit("card_shuffle")
				if Catalog.apply_saved_deck(_profile, did):
					_sync_and_save()
					_rebuild_ui()
			)
			row.add_child(load_b)

			var del_b := Button.new()
			del_b.custom_minimum_size = Vector2(110, 34)
			del_b.text = _tr("Delete", "Smazat")
			LialoIcons.apply_button_icon(del_b, "cross", 14)
			del_b.pressed.connect(func():
				sfx_requested.emit("ui_click")
				Catalog.delete_saved_deck(_profile, did)
				_sync_and_save()
				_rebuild_ui()
			)
			row.add_child(del_b)


func _suit_icon_for_key(ck: String) -> String:
	if ck.begins_with("CERVEN_"):
		return "heart"
	if ck.begins_with("ZELEN_"):
		return "leaves"
	if ck.begins_with("ZALUD_"):
		return "acorn"
	if ck.begins_with("GULA_"):
		return "bell"
	return "cards"


func _pretty_card_key(ck: String) -> String:
	return ck.replace("CERVEN_", "H-").replace("ZELEN_", "L-").replace("ZALUD_", "A-").replace("GULA_", "B-")


func _play_grand_seal_preview(build_id: String) -> void:
	if not is_instance_valid(_bankai_fx_preview):
		_bankai_fx_preview = BankaiFxScript.new()
		_bankai_fx_preview.layer = 98
		add_child(_bankai_fx_preview)
	var combo_arr: Array = _profile.get("bankai_combo", [])
	_bankai_fx_preview.trigger_bankai(build_id, _tr("GRAND SEAL PREVIEW", "UKÁZKA VELKÉ PEČETI"), combo_arr, _lang, false)
