class_name DeckBuilderPanel
extends Control
## Unified 5-Step Tavern Deck Forge (Campaign + Multiplayer) for LIALO v0.194
## Step 1: Archetype & Physical Base Cards (Click card to cycle Class)
## Step 2: Graphical Power Cards (Max 3, Max 1 Mythic)
## Step 3: 4-Card Grand Seal (4/4) + Graphical Picker + Live FX Preview
## Step 4: 2x 3D Tabletop Relics (with SubViewport & 3D Inspect), Card Back & Sword
## Step 5: Name & Save (Named Decks + Save & Play)

signal deck_changed(profile: Dictionary)
signal sfx_requested(sfx_name: String)
signal explain_card_requested(card_key: String, is_power: bool)

const Catalog := preload("res://scripts/lialo_catalog.gd")
const Toon := preload("res://scripts/toon_style.gd")
const LialoIcons := preload("res://scripts/ui/lialo_icons.gd")
const BankaiFxScript := preload("res://scripts/battle/bankai_fx.gd")
const RELIC_INSPECT_PATH := "res://scripts/ui/relic_inspect_3d.gd"

const SUITS := [
	{"id": "CERVEN", "icon": "heart",  "en": "Hearts", "cs": "Červený", "col": Color(0.92, 0.28, 0.30)},
	{"id": "ZELEN",  "icon": "leaves", "en": "Leaves", "cs": "Zelený",  "col": Color(0.28, 0.80, 0.50)},
	{"id": "ZALUD",  "icon": "acorn",  "en": "Acorns", "cs": "Žaludy",  "col": Color(0.88, 0.66, 0.32)},
	{"id": "GULA",   "icon": "bell",   "en": "Bells",  "cs": "Kule",    "col": Color(0.98, 0.64, 0.24)},
]
const RANKS := ["7", "8", "9", "10", "D", "H", "K", "E"]
const CLASS_CYCLE_RANKS := ["D", "H", "K", "E"]
const CLASS_CYCLE := ["NORMAL", "KNIGHT", "MAGE", "THIEF", "MERCHANT"]

const CARD_BACKS := [
	{"id": "klasic",     "en": "Classic Leather", "cs": "Klasická kůže",     "tex": "res://assets/table/deck_back_klasic.png",     "col": Color(0.85, 0.68, 0.30)},
	{"id": "antika",     "en": "Pharaoh's Vault", "cs": "Faraonův poklad",   "tex": "res://assets/table/deck_back_antika.png",     "col": Color(0.96, 0.74, 0.26)},
	{"id": "rim",        "en": "Legion's Aegis",  "cs": "Štít legie",        "tex": "res://assets/table/deck_back_rim.png",        "col": Color(0.91, 0.44, 0.32)},
	{"id": "stredovek",  "en": "Iron Crown",      "cs": "Železná koruna",    "tex": "res://assets/table/deck_back_stredovek.png",  "col": Color(0.58, 0.83, 0.69)},
	{"id": "objavy",     "en": "Corsair's Grip",  "cs": "Korzárův stisk",    "tex": "res://assets/table/deck_back_objavy.png",     "col": Color(0.30, 0.78, 0.94)},
]

const BUILD_ICONS := {
	"GUILLOTINE_ACES": "dagger",
	"MIRROR_MONARCH": "crown",
	"CHAOS_JESTER": "dice",
	"MISTBLADE_DUELIST": "mist",
}

const COL_WALNUT_BG := Color(0.085, 0.060, 0.044, 0.96)
const COL_WALNUT_CARD := Color(0.125, 0.088, 0.062, 0.95)
const COL_WALNUT_DEEP := Color(0.058, 0.042, 0.032, 0.96)
const COL_GOLD_BORDER := Color(0.84, 0.66, 0.30, 0.90)
const COL_GOLD_TEXT := Color(1.0, 0.88, 0.46)
const COL_PARCHMENT := Color(0.94, 0.89, 0.78)
const COL_PARCHMENT_DIM := Color(0.76, 0.70, 0.58)

var _profile: Dictionary = {}
var _lang: String = "en"
var _font_disp: Font
var _font_body: Font
var _card_cache: Dictionary = {}
var _table_cache: Dictionary = {}

var _current_step: int = 0
var _step_dir: int = 1
var _guide_open: bool = true
var _bg_fx: Control
var _content_vb: VBoxContainer
var _step_body_wrap: Control
var _step_tween: Tween
var _editing_seal_slot: int = -1
var _flash_seal_slot: int = -1
var _bounce_relic_id: String = ""
var _flip_back_id: String = ""
var _pop_card_key: String = ""
var _save_flare_pending: bool = false
var _bankai_fx_preview: BankaiFxScript
var _relic_inspect: Control
var _deck_name_edit: LineEdit
var _status_toast: Label

var _fx_time: float = 0.0
var _fx_col: Color = Color(0.88, 0.68, 0.28)
var _tut_step: int = 0
var _tut_done_flags: Array[bool] = [false, false, false, false, false]
var _spirko_celebrate_t: float = 0.0
var _spirko_avatar: Control
var _fx_target_col: Color = Color(0.88, 0.68, 0.28)
var _motes: Array[Dictionary] = []
var _relic_pivots: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(1160, 780)
	_font_disp = load("res://assets/fonts/LialoDisplay.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoDisplay.ttf") else ThemeDB.fallback_font
	_font_body = load("res://assets/fonts/LialoBody.ttf") as Font if ResourceLoader.exists("res://assets/fonts/LialoBody.ttf") else ThemeDB.fallback_font

	for _i in range(34):
		_motes.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"spd": _rng.randf_range(0.025, 0.075),
			"sz": _rng.randf_range(1.6, 3.8),
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
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	_content_vb = VBoxContainer.new()
	_content_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vb.add_theme_constant_override("separation", 10)
	margin.add_child(_content_vb)


func setup_builder(prof: Dictionary, lang: String = "en", card_face_cache: Dictionary = {}) -> void:
	_profile = prof
	_lang = lang
	_card_cache = card_face_cache
	_editing_seal_slot = -1
	_sanitize_local_loadout()
	var b := Catalog.get_deck_build(str(_profile.get("selected_build_id", "GUILLOTINE_ACES")))
	_fx_target_col = b.get("col", Color(0.88, 0.68, 0.28))
	_rebuild_ui()


func _tr(en: String, cs: String) -> String:
	return cs if _lang == "cs" else en


func _count_tut_done() -> int:
	var c := 0
	for f in _tut_done_flags:
		if f:
			c += 1
	return c


func _mark_tut_action(step_idx: int) -> void:
	if step_idx >= 0 and step_idx < _tut_done_flags.size():
		if not _tut_done_flags[step_idx]:
			_tut_done_flags[step_idx] = true
			_spirko_celebrate_t = 1.2
		_tut_step = clampi(step_idx + 1, 0, 4)


func _get_spirko_dialogue() -> String:
	var done_cnt := _count_tut_done()
	if done_cnt >= 5:
		return _tr("Spirko: Magnificent! All 5 forging rites are complete — your deck is battle-ready!", "Spirko: Skvělé! Všech 5 kroků kovárny je hotovo — balíček je připraven do boje!")
	match _tut_step:
		0:
			return _tr("Spirko: Step 1 — 7–10 stay pure classics. Click any D, H, K or E card above 10 to infuse Mage, Thief or Knight, or tap ? to learn!", "Spirko: Krok 1 — 7–10 jsou čisté základy. Klikni na D, H, K nebo E nad 10 pro výběr třídy, nebo na ? pro vysvětlení!")
		1:
			return _tr("Spirko: Step 2 — Equip up to 3 Power Cards (max 1 Mythic). Tap ? on any card to inspect its Arsenal lore!", "Spirko: Krok 2 — Vybav až 3 Mocné karty (max 1 Mýtickou). Klikni na ? pro detail v Arzenálu!")
		2:
			return _tr("Spirko: Step 3 — Forge your 4-card Grand Seal combination and hit Preview to see the ink finisher!", "Spirko: Krok 3 — Sestav 4 karty Velké Pečeti a vyzkoušej Ukázku animace!")
		3:
			return _tr("Spirko: Step 4 — Equip 2 physical 3D Tabletop Relics, inspect them in 3D, and pick your Card Back & Blade!", "Spirko: Krok 4 — Vybav 2 stolní 3D Relikvie, prohlédni si je ve 3D a vyber rub karet i čepel!")
		_:
			return _tr("Spirko: Final Step — Name your deck and hit Save & Play so Campaign and Multiplayer both use your forge build!", "Spirko: Poslední krok — Pojmenuj balíček a klikni na Uložit a hrát pro Kampaň i Multiplayer!")


func _make_explain_mini_btn(card_key: String, is_power: bool) -> Button:
	var eb := Button.new()
	eb.text = "?"
	eb.custom_minimum_size = Vector2(20, 20)
	eb.tooltip_text = _tr("Explain card in Arsenal", "Vysvětlit kartu v Arzenálu")
	eb.z_index = 2
	eb.add_theme_font_override("font", _font_disp)
	eb.add_theme_font_size_override("font_size", 11)
	eb.add_theme_color_override("font_color", Color(0.08, 0.05, 0.03))
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.94, 0.78, 0.34, 0.94)
	sb_n.border_color = Color(0.14, 0.09, 0.04)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(10)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.42, 0.92, 1.0, 1.0)
	eb.add_theme_stylebox_override("normal", sb_n)
	eb.add_theme_stylebox_override("hover", sb_h)
	eb.pressed.connect(func():
		sfx_requested.emit("ui_click")
		explain_card_requested.emit(card_key, is_power)
	)
	return eb


func _draw_spirko_2d(cv: Control) -> void:
	var s := cv.size
	if s.x < 24.0 or s.y < 24.0:
		return
	var cx := s.x * 0.5
	var cy := s.y * 0.56
	var bob := sin(_fx_time * 3.4) * 2.5 - absf(sin(_spirko_celebrate_t * 8.0)) * (6.0 if _spirko_celebrate_t > 0.0 else 0.0)
	# Parchment halo & ink ring
	cv.draw_circle(Vector2(cx, cy - 4.0), 40.0, Color(0.12, 0.10, 0.08, 0.95))
	var ring_c := Color(0.46, 0.98, 0.62, 0.9) if _spirko_celebrate_t > 0.0 else Color(0.34, 0.88, 1.0, 0.78)
	cv.draw_arc(Vector2(cx, cy - 4.0), 40.0, 0.0, TAU, 40, ring_c, 2.4, true)
	# Crosshatched cloak shoulders
	var cloak := PackedVector2Array([
		Vector2(cx - 26, cy + 32), Vector2(cx - 18, cy + 4 + bob), Vector2(cx + 18, cy + 4 + bob), Vector2(cx + 26, cy + 32)
	])
	cv.draw_colored_polygon(cloak, Color(0.18, 0.22, 0.28))
	cv.draw_polyline(PackedVector2Array([cloak[0], cloak[1], cloak[2], cloak[3], cloak[0]]), Color(0.04, 0.03, 0.03), 2.2, true)
	# Quill staff beside Spirko
	var arm_wave := sin(_fx_time * 5.0) * 3.0 + (sin(_spirko_celebrate_t * 14.0) * 6.0 if _spirko_celebrate_t > 0.0 else 0.0)
	cv.draw_line(Vector2(cx + 22, cy + 28), Vector2(cx + 28, cy - 22 + bob + arm_wave), Color(0.84, 0.64, 0.28), 2.5, true)
	cv.draw_circle(Vector2(cx + 28, cy - 24 + bob + arm_wave), 5.0, Color(0.42, 0.94, 1.0, 0.92))
	# Head + tavern wide-brim mage hat + hand-drawn woodcut hatching
	cv.draw_circle(Vector2(cx, cy - 6.0 + bob), 14.0, Color(0.88, 0.76, 0.62))
	cv.draw_arc(Vector2(cx, cy - 6.0 + bob), 14.0, 0.0, TAU, 24, Color(0.06, 0.04, 0.04), 2.2, true)
	# Wide hat brim & pointy crown
	var brim := PackedVector2Array([
		Vector2(cx - 24, cy - 13 + bob), Vector2(cx, cy - 19 + bob), Vector2(cx + 24, cy - 13 + bob), Vector2(cx, cy - 10 + bob)
	])
	cv.draw_colored_polygon(brim, Color(0.10, 0.09, 0.12))
	var crown := PackedVector2Array([
		Vector2(cx - 13, cy - 14 + bob), Vector2(cx - 3, cy - 39 + bob), Vector2(cx + 12, cy - 14 + bob)
	])
	cv.draw_colored_polygon(crown, Color(0.14, 0.12, 0.18))
	cv.draw_line(Vector2(cx - 12, cy - 14 + bob), Vector2(cx + 11, cy - 14 + bob), Color(0.95, 0.76, 0.28), 2.5, true)
	# Glowing spectacles (blinks briefly every ~3s)
	var blink: bool = fmod(_fx_time, 3.2) > 3.06
	var eye_h: float = 0.8 if blink else 3.4
	for ex in [-5.5, 5.5]:
		cv.draw_circle(Vector2(cx + ex, cy - 5.0 + bob), 4.2, Color(0.08, 0.06, 0.04))
		cv.draw_rect(Rect2(cx + ex - 2.4, cy - 5.0 + bob - eye_h * 0.5, 4.8, eye_h), Color(0.45, 0.96, 1.0))


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := minf(delta, 0.05)
	_fx_time += dt
	if _spirko_celebrate_t > 0.0:
		_spirko_celebrate_t = maxf(0.0, _spirko_celebrate_t - dt)
	_fx_col = _fx_col.lerp(_fx_target_col, 1.0 - exp(-5.0 * dt))
	for m in _motes:
		m["y"] = float(m["y"]) - float(m["spd"]) * dt
		if float(m["y"]) < -0.05:
			m["y"] = 1.05
			m["x"] = _rng.randf()
	for piv in _relic_pivots:
		if is_instance_valid(piv):
			piv.rotation.y += dt * 0.75
	if is_instance_valid(_bg_fx):
		_bg_fx.queue_redraw()
	if is_instance_valid(_spirko_avatar):
		_spirko_avatar.queue_redraw()


func _draw_animated_bg() -> void:
	var sz := _bg_fx.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	_bg_fx.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.048, 0.034, 0.025, 0.90))
	var center := Vector2(sz.x * 0.5, 300.0)
	var r := minf(sz.x * 0.34, 240.0)
	var warm_col := _fx_col.lerp(Color(0.92, 0.70, 0.30), 0.35)
	_bg_fx.draw_arc(center, r, 0.0, TAU, 80, Color(warm_col.r, warm_col.g, warm_col.b, 0.14), 2.0)
	_bg_fx.draw_arc(center, r * 0.78, 0.0, TAU, 64, Color(warm_col.r, warm_col.g, warm_col.b, 0.09), 1.4)
	for ti in range(16):
		var a := float(ti) * (TAU / 16.0) + _fx_time * 0.18
		var p1 := center + Vector2(cos(a), sin(a)) * (r * 0.94)
		var p2 := center + Vector2(cos(a), sin(a)) * (r * 1.04)
		_bg_fx.draw_line(p1, p2, Color(warm_col.r, warm_col.g, warm_col.b, 0.18), 1.6)
	for m in _motes:
		var mx := float(m["x"]) * sz.x + sin(_fx_time * 1.6 + float(m["ph"])) * 14.0
		var my := float(m["y"]) * sz.y
		var a := 0.18 + 0.18 * sin(_fx_time * 2.8 + float(m["ph"]))
		_bg_fx.draw_circle(Vector2(mx, my), float(m["sz"]), Color(1.0, 0.76, 0.34, a))


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


func _get_table_tex(path: String) -> Texture2D:
	if _table_cache.has(path) and _table_cache[path] is Texture2D:
		return _table_cache[path] as Texture2D
	var t := Toon.tex(path)
	if t != null:
		_table_cache[path] = t
	return t


func _strip_seal_prefix(raw_name: String) -> String:
	var s := raw_name.strip_edges()
	var prefixes := ["GRAND SEAL:", "VELKÁ PEČEŤ:", "Grand Seal:", "Velká pečeť:", "BANKAI:", "Bankai:"]
	for pref in prefixes:
		if s.begins_with(pref):
			s = s.substr(pref.length()).strip_edges()
	s = s.replace("Bankai", "Grand Seal").replace("BANKAI", "GRAND SEAL")
	return s


func _sanitize_local_loadout() -> void:
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


# ============================================================================
# UI ANIMATION HELPERS (10+ TANGIBLE ANIMATIONS)
# ============================================================================
func _attach_button_hover(btn: Control, hover_scale: float = 1.04) -> void:
	btn.mouse_entered.connect(func():
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(hover_scale, hover_scale), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)


func _attach_card_hover(card_ctrl: Control, tilt_rad: float = 0.032, lift_px: float = 6.0, hover_scale: float = 1.10) -> void:
	var base_z := card_ctrl.z_index
	card_ctrl.mouse_entered.connect(func():
		if not is_instance_valid(card_ctrl):
			return
		card_ctrl.pivot_offset = card_ctrl.size * 0.5
		card_ctrl.z_index = base_z + 12
		var dir := -1.0 if int(card_ctrl.position.x) % 2 == 0 else 1.0
		var tw := card_ctrl.create_tween().set_parallel(true)
		tw.tween_property(card_ctrl, "scale", Vector2(hover_scale, hover_scale), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_ctrl, "rotation", dir * tilt_rad, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_ctrl, "pivot_offset:y", card_ctrl.size.y * 0.5 + lift_px, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card_ctrl.mouse_exited.connect(func():
		if not is_instance_valid(card_ctrl):
			return
		card_ctrl.z_index = base_z
		var tw := card_ctrl.create_tween().set_parallel(true)
		tw.tween_property(card_ctrl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_ctrl, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card_ctrl, "pivot_offset:y", card_ctrl.size.y * 0.5, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)


func _animate_btn_pop(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale", Vector2(1.09, 1.09), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_card_flip(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale:x", 0.08, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ctrl, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_relic_bounce(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2(0.86, 0.86)
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _animate_seal_slot_pulse(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween().set_loops()
	tw.tween_property(ctrl, "scale", Vector2(1.045, 1.045), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_seal_flash(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.92, 0.45, 0.78)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(flash)
	_animate_btn_pop(ctrl)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)


func _animate_save_flare(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	var flare := ColorRect.new()
	flare.set_anchors_preset(Control.PRESET_FULL_RECT)
	flare.color = Color(0.55, 1.0, 0.65, 0.55)
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(flare)
	var tw := flare.create_tween()
	tw.tween_property(flare, "color:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flare.queue_free)


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
	var parent_layer: Node = self
	var p := get_parent()
	while p != null:
		if p is CanvasLayer:
			parent_layer = p
			break
		p = p.get_parent()
	parent_layer.add_child(_relic_inspect)
	return _relic_inspect


func _open_relic_inspect(relic_id: String, is_unlocked: bool, is_equipped: bool, source_text: String = "") -> void:
	sfx_requested.emit("ui_click")
	var modal := _ensure_relic_inspect()
	if modal != null and modal.has_method("inspect_relic"):
		modal.call("inspect_relic", relic_id, _lang, is_unlocked, is_equipped, source_text)


func _rebuild_ui(animate_step: bool = false, animate_guide: bool = false) -> void:
	if not is_instance_valid(_content_vb):
		return
	_relic_pivots.clear()
	_sanitize_local_loadout()
	for ch in _content_vb.get_children():
		ch.queue_free()

	var sel_build_id := str(_profile.get("selected_build_id", "GUILLOTINE_ACES"))
	var cur_build := Catalog.get_deck_build_loc(sel_build_id, _lang)
	_fx_target_col = cur_build.get("col", Color(0.88, 0.68, 0.28))

	# === TAVERN WOODCUT HEADER BAR ===
	var hdr_pan := PanelContainer.new()
	hdr_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, COL_GOLD_BORDER, 12, 10))
	_content_vb.add_child(hdr_pan)

	var hdr_hb := HBoxContainer.new()
	hdr_hb.add_theme_constant_override("separation", 12)
	hdr_pan.add_child(hdr_hb)

	hdr_hb.add_child(LialoIcons.make_icon_rect("cards", 28, COL_GOLD_TEXT))

	var hdr_vb := VBoxContainer.new()
	hdr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hb.add_child(hdr_vb)

	var t_lbl := Label.new()
	t_lbl.text = _tr("TAVERN DECK FORGE", "KRČMOVÁ KOVÁRNA BALÍČKU")
	t_lbl.add_theme_font_override("font", _font_disp)
	t_lbl.add_theme_font_size_override("font_size", 21)
	t_lbl.add_theme_color_override("font_color", COL_GOLD_TEXT)
	hdr_vb.add_child(t_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "%s  •  %d / 5" % [str(cur_build["name"]), _current_step + 1]
	sub_lbl.add_theme_font_override("font", _font_body)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", COL_PARCHMENT_DIM)
	hdr_vb.add_child(sub_lbl)

	var guide_btn := Button.new()
	guide_btn.custom_minimum_size = Vector2(168, 36)
	guide_btn.text = _tr("Spirko Tutor (%d/5)" % _count_tut_done(), "Spirko Průvodce (%d/5)" % _count_tut_done())
	LialoIcons.apply_button_icon(guide_btn, "help", 16)
	guide_btn.add_theme_font_override("font", _font_disp)
	guide_btn.add_theme_font_size_override("font_size", 13)
	guide_btn.add_theme_color_override("font_color", COL_GOLD_TEXT if _guide_open else COL_PARCHMENT)
	guide_btn.add_theme_stylebox_override("normal", _make_box_style(
		Color(0.22, 0.15, 0.08, 0.96) if _guide_open else COL_WALNUT_CARD,
		COL_GOLD_TEXT if _guide_open else COL_GOLD_BORDER, 8, 6
	))
	_attach_button_hover(guide_btn, 1.04)
	guide_btn.pressed.connect(func():
		sfx_requested.emit("ui_click")
		_guide_open = not _guide_open
		_rebuild_ui(false, _guide_open)
	)
	hdr_hb.add_child(guide_btn)

	hdr_hb.add_child(LialoIcons.make_icon_label_row("check", _tr("SYNCED", "SYNC"), 16, 13, Color(0.46, 0.96, 0.62)))

	# === INTERACTIVE HAND-DRAWN 2D SPIRKO TUTOR DOCK ===
	if _guide_open:
		var guide_pan := PanelContainer.new()
		guide_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_DEEP, Color(0.32, 0.86, 0.98, 0.85), 10, 10))
		_content_vb.add_child(guide_pan)

		var g_outer := HBoxContainer.new()
		g_outer.add_theme_constant_override("separation", 12)
		guide_pan.add_child(g_outer)

		_spirko_avatar = Control.new()
		_spirko_avatar.custom_minimum_size = Vector2(92, 92)
		_spirko_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spirko_avatar.draw.connect(_draw_spirko_2d.bind(_spirko_avatar))
		g_outer.add_child(_spirko_avatar)

		var g_right := VBoxContainer.new()
		g_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_right.add_theme_constant_override("separation", 6)
		g_outer.add_child(g_right)

		var sp_speech := Label.new()
		sp_speech.text = _get_spirko_dialogue()
		sp_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sp_speech.add_theme_font_override("font", _font_body)
		sp_speech.add_theme_font_size_override("font_size", 13)
		sp_speech.add_theme_color_override("font_color", Color(0.98, 0.93, 0.78))
		g_right.add_child(sp_speech)

		var g_hb := HBoxContainer.new()
		g_hb.add_theme_constant_override("separation", 6)
		g_right.add_child(g_hb)

		var tips := [
			{"ic": "crown", "en": "1. Infuse D–E Card", "cs": "1. Třída D–E karty"},
			{"ic": "bolt",  "en": "2. Equip Power Card", "cs": "2. Mocná karta"},
			{"ic": "seal",  "en": "3. Customize Seal", "cs": "3. Velká Pečeť"},
			{"ic": "trophy","en": "4. Relic / Card Back", "cs": "4. Relikvie / Rub"},
			{"ic": "scroll","en": "5. Save Deck", "cs": "5. Ulož balíček"},
		]
		for ti in range(tips.size()):
			var tp: Dictionary = tips[ti]
			var is_done: bool = _tut_done_flags[ti]
			var is_cur: bool = (ti == _tut_step) and not is_done
			var tp_btn := Button.new()
			tp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tp_btn.custom_minimum_size = Vector2(0, 32)
			tp_btn.text = _tr(str(tp["en"]), str(tp["cs"]))
			LialoIcons.apply_button_icon(tp_btn, "check" if is_done else str(tp["ic"]), 14)
			tp_btn.add_theme_font_override("font", _font_body)
			tp_btn.add_theme_font_size_override("font_size", 11)
			tp_btn.add_theme_color_override("font_color", Color(0.46, 0.98, 0.62) if is_done else (COL_GOLD_TEXT if is_cur else COL_PARCHMENT_DIM))
			tp_btn.add_theme_stylebox_override("normal", _make_box_style(
				Color(0.10, 0.24, 0.14, 0.94) if is_done else (Color(0.22, 0.16, 0.08, 0.96) if is_cur else COL_WALNUT_CARD),
				Color(0.46, 0.96, 0.58) if is_done else (Color(0.32, 0.88, 1.0) if is_cur else Color(0.45, 0.36, 0.22, 0.55)), 7, 4
			))
			var target_step := ti
			tp_btn.pressed.connect(func():
				sfx_requested.emit("ui_click")
				_step_dir = 1 if target_step >= _current_step else -1
				_current_step = target_step
				_rebuild_ui()
			)
			g_hb.add_child(tp_btn)

		if animate_guide:
			guide_pan.modulate.a = 0.0
			guide_pan.scale = Vector2(0.98, 0.85)
			var g_tw := guide_pan.create_tween().set_parallel(true)
			g_tw.tween_property(guide_pan, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			g_tw.tween_property(guide_pan, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# === TOP 5-STEP PILLS ===
	var pc_cnt: int = (_profile.get("custom_cards", []) as Array).size()
	var tr_cnt: int = (_profile.get("table_relics", []) as Array).size()
	var step_defs := [
		{"icon": "cards",  "en": "1. Base Cards", "cs": "1. Základní karty"},
		{"icon": "bolt",   "en": "2. Power (%d/%d)" % [pc_cnt, Catalog.MAX_POWER_CARDS], "cs": "2. Mocné (%d/%d)" % [pc_cnt, Catalog.MAX_POWER_CARDS]},
		{"icon": "seal",   "en": "3. Grand Seal", "cs": "3. Velká pečeť"},
		{"icon": "trophy", "en": "4. Relics (%d/2)" % tr_cnt, "cs": "4. Relikvie (%d/2)" % tr_cnt},
		{"icon": "check",  "en": "5. Save", "cs": "5. Uložit"},
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
		sb.custom_minimum_size = Vector2(0, 42)
		sb.text = _tr(str(sd["en"]), str(sd["cs"]))
		LialoIcons.apply_button_icon(sb, str(sd["icon"]), 18)
		sb.add_theme_font_override("font", _font_disp)
		sb.add_theme_font_size_override("font_size", 13)
		sb.add_theme_color_override("font_color", COL_GOLD_TEXT if is_cur else (Color(0.58, 0.94, 0.64) if is_done else COL_PARCHMENT_DIM))
		sb.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.20, 0.14, 0.08, 0.98) if is_cur else (Color(0.09, 0.15, 0.09, 0.92) if is_done else COL_WALNUT_DEEP),
			COL_GOLD_TEXT if is_cur else (Color(0.42, 0.78, 0.46, 0.82) if is_done else Color(0.40, 0.30, 0.18, 0.75)),
			8, 6
		))
		sb.add_theme_stylebox_override("hover", _make_box_style(
			Color(0.24, 0.17, 0.10, 1.0), COL_GOLD_TEXT, 8, 6
		))
		_attach_button_hover(sb, 1.03)
		if is_cur and animate_step:
			sb.call_deferred("set_pivot_offset", Vector2(90, 21))
			_animate_btn_pop(sb)
		var target_step := si
		sb.pressed.connect(func():
			sfx_requested.emit("ui_click")
			_go_to_step(target_step)
		)
		prog_hb.add_child(sb)

	# === STEP BODY CONTAINER ===
	_step_body_wrap = VBoxContainer.new()
	_step_body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_body_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(_step_body_wrap as VBoxContainer).add_theme_constant_override("separation", 10)
	_content_vb.add_child(_step_body_wrap)

	match _current_step:
		0: _build_step_1_base_cards(_step_body_wrap as VBoxContainer, sel_build_id)
		1: _build_step_2_power_cards(_step_body_wrap as VBoxContainer)
		2: _build_step_3_grand_seal(_step_body_wrap as VBoxContainer, sel_build_id, cur_build)
		3: _build_step_4_relics_cosmetics(_step_body_wrap as VBoxContainer)
		4: _build_step_5_name_save(_step_body_wrap as VBoxContainer, sel_build_id, cur_build)

	# === BOTTOM WIZARD NAVIGATION BAR ===
	var nav_hb := HBoxContainer.new()
	nav_hb.add_theme_constant_override("separation", 12)
	_content_vb.add_child(nav_hb)

	var prev_btn := Button.new()
	prev_btn.custom_minimum_size = Vector2(170, 42)
	prev_btn.text = _tr("< Back", "< Zpět")
	prev_btn.disabled = (_current_step <= 0)
	prev_btn.add_theme_font_override("font", _font_disp)
	prev_btn.add_theme_font_size_override("font_size", 14)
	prev_btn.add_theme_color_override("font_color", COL_PARCHMENT)
	prev_btn.add_theme_stylebox_override("normal", _make_box_style(COL_WALNUT_CARD, Color(0.56, 0.44, 0.26), 8, 8))
	_attach_button_hover(prev_btn, 1.04)
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
	_status_toast.add_theme_color_override("font_color", COL_GOLD_TEXT)
	nav_hb.add_child(_status_toast)

	if _current_step < 4:
		var next_btn := Button.new()
		next_btn.custom_minimum_size = Vector2(190, 42)
		next_btn.text = _tr("Next >", "Další >")
		next_btn.add_theme_font_override("font", _font_disp)
		next_btn.add_theme_font_size_override("font_size", 15)
		next_btn.add_theme_color_override("font_color", COL_GOLD_TEXT)
		next_btn.add_theme_stylebox_override("normal", _make_box_style(Color(0.22, 0.15, 0.08, 0.98), COL_GOLD_BORDER, 8, 8))
		_attach_button_hover(next_btn, 1.05)
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

	_flash_seal_slot = -1
	_bounce_relic_id = ""
	_flip_back_id = ""
	_pop_card_key = ""


# ============================================================================
# STEP 1: PHYSICAL BASE CARDS (7–10 FIXED BASE, D–H–K–E INDIVIDUAL RARITY + EXPLAIN ?)
# ============================================================================
func _build_step_1_base_cards(parent: VBoxContainer, _sel_build_id: String) -> void:
	# Physical 32-Card Suit-Grouped Grid (Archetype panel removed by design; infusion only above 10)
	var base_pan := PanelContainer.new()
	base_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, Color(0.62, 0.48, 0.26, 0.85), 10, 10))
	parent.add_child(base_pan)

	var base_vb := VBoxContainer.new()
	base_vb.add_theme_constant_override("separation", 8)
	base_pan.add_child(base_vb)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 10)
	base_vb.add_child(hdr_row)
	hdr_row.add_child(LialoIcons.make_icon_label_row(
		"cards",
		_tr("7–10 ARE PURE BASE CARDS  •  INFUSE CLASS ON CARDS ABOVE 10 (D, H, K, E)", "7–10 JSOU ZÁKLAD  •  TŘÍDU VYBÍREJ NA KARTÁCH NAD 10 (D, H, K, E)"),
		18, 14, COL_GOLD_TEXT
	))

	var ce: Dictionary = _profile.get("card_editions", {})
	for s in SUITS:
		var suit_id := str(s["id"])
		var sc: Color = s["col"]
		var suit_row := HBoxContainer.new()
		suit_row.add_theme_constant_override("separation", 8)
		base_vb.add_child(suit_row)

		var s_tag := PanelContainer.new()
		s_tag.custom_minimum_size = Vector2(104, 86)
		s_tag.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_DEEP, Color(sc.r, sc.g, sc.b, 0.70), 8, 6))
		var s_vb := VBoxContainer.new()
		s_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		s_vb.add_theme_constant_override("separation", 4)
		s_tag.add_child(s_vb)
		var ic_r := LialoIcons.make_icon_rect(str(s["icon"]), 22, sc.lightened(0.2))
		ic_r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		s_vb.add_child(ic_r)
		var s_lbl := Label.new()
		s_lbl.text = _tr(str(s["en"]), str(s["cs"]))
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.add_theme_font_override("font", _font_disp)
		s_lbl.add_theme_font_size_override("font_size", 12)
		s_lbl.add_theme_color_override("font_color", COL_PARCHMENT)
		s_vb.add_child(s_lbl)
		suit_row.add_child(s_tag)

		var cards_hb := HBoxContainer.new()
		cards_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_hb.add_theme_constant_override("separation", 8)
		suit_row.add_child(cards_hb)

		for r in RANKS:
			var r_str: String = str(r)
			var fk: String = "%s_%s" % [suit_id, r_str]
			var is_infusable: bool = (r_str in CLASS_CYCLE_RANKS)
			var cur_cls: String = Catalog.normalize_card_class(str(ce.get(fk, "NORMAL"))) if is_infusable else "NORMAL"
			var cls_d: Dictionary = Catalog.get_card_class_loc(cur_cls, _lang)
			var cls_col: Color = cls_d.get("col", COL_GOLD_BORDER)
			var is_mod: bool = is_infusable and (cur_cls != "NORMAL")

			var card_btn := Button.new()
			card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_btn.custom_minimum_size = Vector2(68, 92)
			card_btn.tooltip_text = "%s (%s) — %s" % [
				_pretty_card_key(fk),
				str(cls_d.get("name", cur_cls)),
				_tr("Click to cycle Class (Normal/Mage/Thief/Knight)", "Kliknutím vyber třídu (Klasik/Mág/Zloděj/Rytíř)") if is_infusable else _tr("Pure Base Card • Click or tap ? to Explain", "Základní karta • Kliknutím zobrazíš vysvětlení")
			]
			card_btn.add_theme_stylebox_override("normal", _make_box_style(
				Color(0.18, 0.12, 0.07, 0.96) if is_mod else (Color(0.085, 0.064, 0.044, 0.96) if is_infusable else COL_WALNUT_DEEP),
				cls_col if is_mod else (Color(0.72, 0.56, 0.28, 0.82) if is_infusable else Color(0.36, 0.30, 0.22, 0.56)), 8, 3
			))
			card_btn.add_theme_stylebox_override("hover", _make_box_style(
				Color(0.24, 0.17, 0.10, 1.0), COL_GOLD_TEXT, 8, 3
			))

			var card_vb := VBoxContainer.new()
			card_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
			card_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_vb.alignment = BoxContainer.ALIGNMENT_CENTER
			card_vb.add_theme_constant_override("separation", 2)
			card_btn.add_child(card_vb)

			var tex_r := TextureRect.new()
			tex_r.texture = _get_card_tex(fk)
			tex_r.custom_minimum_size = Vector2(46, 62)
			tex_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_vb.add_child(tex_r)

			var cls_lbl := Label.new()
			cls_lbl.text = (str(cls_d.get("short_cls", cur_cls)) if is_mod else (r_str + " ★" if is_infusable else r_str))
			cls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cls_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cls_lbl.add_theme_font_override("font", _font_disp if is_mod else _font_body)
			cls_lbl.add_theme_font_size_override("font_size", 10)
			cls_lbl.add_theme_color_override("font_color", cls_col if is_mod else (COL_GOLD_TEXT if is_infusable else COL_PARCHMENT_DIM))
			card_vb.add_child(cls_lbl)

			# Explain ? corner button (jumps directly into Arsenal Normal Cards explanation)
			var exp_btn := _make_explain_mini_btn(fk, false)
			exp_btn.anchor_left = 1.0; exp_btn.anchor_right = 1.0
			exp_btn.anchor_top = 0.0; exp_btn.anchor_bottom = 0.0
			exp_btn.offset_left = -22; exp_btn.offset_top = 3
			exp_btn.offset_right = -3; exp_btn.offset_bottom = 22
			card_btn.add_child(exp_btn)

			_attach_card_hover(card_btn, 0.042 if is_infusable else 0.024, 6.0 if is_infusable else 3.0, 1.14 if is_infusable else 1.08)
			if _pop_card_key == fk:
				card_btn.call_deferred("set_pivot_offset", Vector2(34, 46))
				_animate_btn_pop(card_btn)
				_animate_card_flip(card_btn)

			card_btn.pressed.connect(func():
				if not is_infusable:
					sfx_requested.emit("ui_click")
					explain_card_requested.emit(fk, false)
					return
				sfx_requested.emit("card_hover")
				var idx := CLASS_CYCLE.find(cur_cls)
				var next_cls: String = str(CLASS_CYCLE[(idx + 1) % CLASS_CYCLE.size()])
				var ce_map: Dictionary = _profile.get("card_editions", {}).duplicate()
				if next_cls == "NORMAL":
					ce_map.erase(fk)
				else:
					ce_map[fk] = next_cls
				_profile["card_editions"] = ce_map
				_pop_card_key = fk
				_mark_tut_action(0)
				_sync_and_save()
				_rebuild_ui()
			)
			cards_hb.add_child(card_btn)


# ============================================================================
# STEP 2: GRAPHICAL POWER CARDS (MAX 3, MAX 1 MYTHIC)
# ============================================================================
func _build_step_2_power_cards(parent: VBoxContainer) -> void:
	var eq_pcs: Array = _profile.get("custom_cards", [])
	var mythic_equipped := 0
	for ep in eq_pcs:
		var pd := Catalog.get_power_card(str(ep))
		if str(pd.get("rarity", "")) == "Mythic":
			mythic_equipped += 1

	var pc_pan := PanelContainer.new()
	pc_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, COL_GOLD_BORDER, 10, 12))
	parent.add_child(pc_pan)

	var pc_vb := VBoxContainer.new()
	pc_vb.add_theme_constant_override("separation", 10)
	pc_pan.add_child(pc_vb)

	var hdr_hb := HBoxContainer.new()
	hdr_hb.add_theme_constant_override("separation", 12)
	pc_vb.add_child(hdr_hb)

	hdr_hb.add_child(LialoIcons.make_icon_label_row(
		"bolt",
		_tr("POWER CARDS", "MOCNÉ KARTY"),
		20, 16, COL_GOLD_TEXT
	))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_hb.add_child(spacer)

	# Crisp visual X / 3 badge + Mythic 0/1 badge
	var badge_pan := PanelContainer.new()
	badge_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_DEEP, COL_GOLD_TEXT, 8, 6))
	var badge_hb := HBoxContainer.new()
	badge_hb.add_theme_constant_override("separation", 8)
	badge_pan.add_child(badge_hb)

	for slot_i in range(Catalog.MAX_POWER_CARDS):
		var filled := slot_i < eq_pcs.size()
		badge_hb.add_child(LialoIcons.make_icon_rect("bolt" if filled else "cards", 16, COL_GOLD_TEXT if filled else Color(0.42, 0.36, 0.28)))

	var cnt_lbl := Label.new()
	cnt_lbl.text = "%d / %d  •  %s: %d/1" % [eq_pcs.size(), Catalog.MAX_POWER_CARDS, _tr("Mythic", "Mýtická"), mythic_equipped]
	cnt_lbl.add_theme_font_override("font", _font_disp)
	cnt_lbl.add_theme_font_size_override("font_size", 13)
	cnt_lbl.add_theme_color_override("font_color", COL_GOLD_TEXT)
	badge_hb.add_child(cnt_lbl)
	hdr_hb.add_child(badge_pan)

	var pc_grid := GridContainer.new()
	pc_grid.columns = 8
	pc_grid.add_theme_constant_override("h_separation", 8)
	pc_grid.add_theme_constant_override("v_separation", 8)
	pc_vb.add_child(pc_grid)

	for pc_raw in Catalog.POWER_CARDS:
		var pid := str(pc_raw["id"])
		var pcl := Catalog.get_power_card_loc(pid, _lang)
		var is_ul := Catalog.is_power_card_unlocked(_profile, pid) or (pid in eq_pcs)
		var is_eq := pid in eq_pcs
		var is_mythic := str(pc_raw.get("rarity", "")) == "Mythic"
		var accent: Color = pcl["accent"]

		var pb := Button.new()
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.custom_minimum_size = Vector2(118, 168)
		pb.disabled = not is_ul
		pb.tooltip_text = "%s — %s" % [str(pcl["name"]), str(pcl["desc"])]
		pb.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.22, 0.16, 0.08, 0.98) if is_eq else COL_WALNUT_DEEP,
			COL_GOLD_TEXT if is_eq else (Color(0.96, 0.72, 0.24, 0.85) if is_mythic else Color(0.46, 0.36, 0.24, 0.78)),
			8, 4
		))
		pb.add_theme_stylebox_override("hover", _make_box_style(
			Color(0.26, 0.19, 0.10, 1.0), accent.lightened(0.25), 8, 4
		))

		var card_vb := VBoxContainer.new()
		card_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vb.add_theme_constant_override("separation", 3)
		pb.add_child(card_vb)

		var tex_wrap := Control.new()
		tex_wrap.custom_minimum_size = Vector2(88, 114)
		tex_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vb.add_child(tex_wrap)

		var tex_r := TextureRect.new()
		tex_r.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_r.texture = _get_card_tex(pid)
		tex_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_r.modulate = Color.WHITE if is_ul else Color(0.36, 0.32, 0.30, 0.75)
		tex_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_wrap.add_child(tex_r)

		if is_eq or not is_ul or is_mythic:
			var badge_ic := LialoIcons.make_icon_rect(
				"check" if is_eq else ("lock" if not is_ul else "star"),
				18,
				Color(0.46, 1.0, 0.62) if is_eq else (COL_PARCHMENT_DIM if not is_ul else COL_GOLD_TEXT)
			)
			badge_ic.position = Vector2(4, 4)
			tex_wrap.add_child(badge_ic)

		# Explain ? corner button (jumps directly into Arsenal Power Cards explanation)
		var p_exp_btn := _make_explain_mini_btn(pid, true)
		p_exp_btn.anchor_left = 1.0; p_exp_btn.anchor_right = 1.0
		p_exp_btn.anchor_top = 0.0; p_exp_btn.anchor_bottom = 0.0
		p_exp_btn.offset_left = -24; p_exp_btn.offset_top = 4
		p_exp_btn.offset_right = -4; p_exp_btn.offset_bottom = 24
		pb.add_child(p_exp_btn)

		var name_lbl := Label.new()
		name_lbl.text = str(pcl["short"])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_override("font", _font_disp)
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", COL_GOLD_TEXT if is_eq else COL_PARCHMENT)
		card_vb.add_child(name_lbl)

		var pwr_lbl := Label.new()
		pwr_lbl.text = str(pcl.get("power_line", ""))
		pwr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pwr_lbl.clip_text = true
		pwr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pwr_lbl.add_theme_font_override("font", _font_body)
		pwr_lbl.add_theme_font_size_override("font_size", 10)
		pwr_lbl.add_theme_color_override("font_color", COL_PARCHMENT_DIM)
		card_vb.add_child(pwr_lbl)

		if is_ul:
			_attach_card_hover(pb, 0.030, 6.0, 1.08)

		pb.pressed.connect(func():
			sfx_requested.emit("card_hover")
			var arr: Array = _profile.get("custom_cards", []).duplicate()
			if pid in arr:
				arr.erase(pid)
			else:
				if is_mythic:
					var filtered: Array = []
					for existing_id in arr:
						if str(Catalog.get_power_card(str(existing_id)).get("rarity", "")) != "Mythic":
							filtered.append(existing_id)
					arr = filtered
				while arr.size() >= Catalog.MAX_POWER_CARDS:
					arr.pop_front()
				arr.append(pid)
			_profile["custom_cards"] = arr
			_mark_tut_action(1)
			_sync_and_save()
			_rebuild_ui()
		)
		pc_grid.add_child(pb)


# ============================================================================
# STEP 3: 4-CARD GRAND SEAL (GRAPHICAL PICKER & HOVER ANIMATIONS)
# ============================================================================
func _build_step_3_grand_seal(parent: VBoxContainer, sel_build_id: String, cur_build: Dictionary) -> void:
	var seal_pan := PanelContainer.new()
	seal_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, COL_GOLD_BORDER, 12, 12))
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

	var raw_seal_title := _strip_seal_prefix(str(cur_build.get("bankai_name", "Grand Seal")))
	bk_info.add_child(LialoIcons.make_icon_label_row(
		"seal",
		_tr("GRAND SEAL: %s (4 / 4)" % raw_seal_title, "VELKÁ PEČEŤ: %s (4 / 4)" % raw_seal_title),
		22, 17, COL_GOLD_TEXT
	))

	var bk_desc := Label.new()
	bk_desc.text = str(cur_build.get("bankai_desc", "")).replace("Bankai", "Grand Seal").replace("BANKAI", "GRAND SEAL")
	bk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bk_desc.add_theme_font_override("font", _font_body)
	bk_desc.add_theme_font_size_override("font_size", 13)
	bk_desc.add_theme_color_override("font_color", COL_PARCHMENT)
	bk_info.add_child(bk_desc)

	var preset_btn := Button.new()
	preset_btn.text = _tr("Preset", "Výchozí")
	preset_btn.custom_minimum_size = Vector2(126, 38)
	LialoIcons.apply_button_icon(preset_btn, "redraw", 16)
	preset_btn.add_theme_font_override("font", _font_disp)
	preset_btn.add_theme_font_size_override("font_size", 13)
	preset_btn.add_theme_stylebox_override("normal", _make_box_style(COL_WALNUT_CARD, COL_GOLD_BORDER, 8, 6))
	_attach_button_hover(preset_btn, 1.04)
	preset_btn.pressed.connect(func():
		sfx_requested.emit("card_shuffle")
		_profile["bankai_combo"] = (cur_build.get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]) as Array).duplicate()
		_editing_seal_slot = -1
		_sync_and_save()
		_rebuild_ui()
	)
	bk_hdr.add_child(preset_btn)

	var preview_btn := Button.new()
	preview_btn.text = _tr("Preview FX", "Ukázka FX")
	preview_btn.custom_minimum_size = Vector2(148, 38)
	LialoIcons.apply_button_icon(preview_btn, "bolt", 16)
	preview_btn.add_theme_font_override("font", _font_disp)
	preview_btn.add_theme_font_size_override("font_size", 13)
	preview_btn.add_theme_color_override("font_color", COL_GOLD_TEXT)
	preview_btn.add_theme_stylebox_override("normal", _make_box_style(Color(0.22, 0.15, 0.08, 0.96), COL_GOLD_TEXT, 8, 6))
	_attach_button_hover(preview_btn, 1.05)
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
		slot_btn.custom_minimum_size = Vector2(142, 168)
		slot_btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.22, 0.15, 0.08, 0.98) if is_ed else COL_WALNUT_DEEP,
			COL_GOLD_TEXT if is_ed else _fx_target_col, 10, 6
		))
		slot_btn.add_theme_stylebox_override("hover", _make_box_style(Color(0.26, 0.18, 0.10, 1.0), COL_GOLD_TEXT, 10, 6))

		var svb := VBoxContainer.new()
		svb.set_anchors_preset(Control.PRESET_FULL_RECT)
		svb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_btn.add_child(svb)

		var tex_r := TextureRect.new()
		tex_r.texture = _get_card_tex(ck)
		tex_r.custom_minimum_size = Vector2(92, 122)
		tex_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.add_child(tex_r)

		var cap := Label.new()
		cap.text = "#%d • %s" % [si + 1, _pretty_card_key(ck)]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_theme_font_override("font", _font_disp)
		cap.add_theme_font_size_override("font_size", 12)
		cap.add_theme_color_override("font_color", COL_GOLD_TEXT if is_ed else COL_PARCHMENT)
		svb.add_child(cap)

		if is_ed:
			slot_btn.call_deferred("set_pivot_offset", Vector2(71, 84))
			_animate_seal_slot_pulse(slot_btn)
		else:
			_attach_card_hover(slot_btn, 0.024, 4.0, 1.06)

		if _flash_seal_slot == si:
			slot_btn.call_deferred("set_pivot_offset", Vector2(71, 84))
			_animate_seal_flash(slot_btn)

		var slot_idx_cap := si
		slot_btn.pressed.connect(func():
			sfx_requested.emit("card_hover")
			_editing_seal_slot = -1 if _editing_seal_slot == slot_idx_cap else slot_idx_cap
			_rebuild_ui()
		)
		slots_hb.add_child(slot_btn)

	# Graphical Card Picker for Active Seal Slot
	if _editing_seal_slot >= 0 and _editing_seal_slot < 4:
		var picker_wrap := PanelContainer.new()
		picker_wrap.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_DEEP, COL_GOLD_TEXT, 10, 10))
		bk_vb.add_child(picker_wrap)

		var pk_vb := VBoxContainer.new()
		pk_vb.add_theme_constant_override("separation", 6)
		picker_wrap.add_child(pk_vb)

		pk_vb.add_child(LialoIcons.make_icon_label_row(
			"cards",
			_tr("SLOT #%d — PICK CARD" % (_editing_seal_slot + 1), "SLOT #%d — VYBER KARTU" % (_editing_seal_slot + 1)),
			18, 14, COL_GOLD_TEXT
		))

		var pk_grid := GridContainer.new()
		pk_grid.columns = 8
		pk_grid.add_theme_constant_override("h_separation", 8)
		pk_grid.add_theme_constant_override("v_separation", 8)
		pk_vb.add_child(pk_grid)

		for s in SUITS:
			for r in RANKS:
				var key := "%s_%s" % [str(s["id"]), r]
				var already_in := key in combo_arr
				var pb := Button.new()
				pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pb.custom_minimum_size = Vector2(68, 86)
				pb.tooltip_text = _pretty_card_key(key)
				pb.add_theme_stylebox_override("normal", _make_box_style(
					Color(0.14, 0.24, 0.14, 0.96) if already_in else COL_WALNUT_CARD,
					Color(0.46, 0.96, 0.62) if already_in else Color(0.50, 0.38, 0.22, 0.80), 8, 3
				))
				pb.add_theme_stylebox_override("hover", _make_box_style(
					Color(0.24, 0.18, 0.10, 1.0), COL_GOLD_TEXT, 8, 3
				))

				var p_vb := VBoxContainer.new()
				p_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
				p_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				p_vb.alignment = BoxContainer.ALIGNMENT_CENTER
				p_vb.add_theme_constant_override("separation", 1)
				pb.add_child(p_vb)

				var ctex := TextureRect.new()
				ctex.texture = _get_card_tex(key)
				ctex.custom_minimum_size = Vector2(46, 64)
				ctex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ctex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ctex.mouse_filter = Control.MOUSE_FILTER_IGNORE
				p_vb.add_child(ctex)

				var r_lbl := Label.new()
				r_lbl.text = r
				r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				r_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r_lbl.add_theme_font_override("font", _font_disp)
				r_lbl.add_theme_font_size_override("font_size", 10)
				r_lbl.add_theme_color_override("font_color", Color(0.46, 1.0, 0.62) if already_in else COL_PARCHMENT_DIM)
				p_vb.add_child(r_lbl)

				_attach_card_hover(pb, 0.036, 6.0, 1.12)
				var target_slot := _editing_seal_slot
				pb.pressed.connect(func():
					sfx_requested.emit("ui_click")
					var next_c: Array = _profile.get("bankai_combo", []).duplicate()
					while next_c.size() < 4:
						next_c.append("CERVEN_E")
					next_c[target_slot] = key
					_profile["bankai_combo"] = next_c
					_flash_seal_slot = target_slot
					_editing_seal_slot = -1
					_mark_tut_action(2)
					_sync_and_save()
					_rebuild_ui()
				)
				pk_grid.add_child(pb)


# ============================================================================
# STEP 4: 3D TABLETOP RELICS ONLY + VISUAL CARD BACKS & SWORD SKINS
# ============================================================================
func _build_step_4_relics_cosmetics(parent: VBoxContainer) -> void:
	var is_headless := DisplayServer.get_name() == "headless"
	var tbl_rels: Array = _profile.get("table_relics", [])

	# Top: 2x 3D Tabletop Relics ONLY (with live SubViewport preview + 3D Inspect)
	var tr_pan := PanelContainer.new()
	tr_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, COL_GOLD_BORDER, 10, 10))
	parent.add_child(tr_pan)

	var tr_vb := VBoxContainer.new()
	tr_vb.add_theme_constant_override("separation", 8)
	tr_pan.add_child(tr_vb)

	tr_vb.add_child(LialoIcons.make_icon_label_row(
		"trophy",
		_tr("3D TABLETOP RELICS (%d / 2)" % tbl_rels.size(), "3D STOLNÍ RELIKVIE (%d / 2)" % tbl_rels.size()),
		18, 15, COL_GOLD_TEXT
	))

	var tr_grid := GridContainer.new()
	tr_grid.columns = 5
	tr_grid.add_theme_constant_override("h_separation", 8)
	tr_grid.add_theme_constant_override("v_separation", 8)
	tr_vb.add_child(tr_grid)

	for t_raw in Catalog.TABLE_RELICS:
		var tid := str(t_raw["id"])
		var tloc := Catalog.get_table_relic_loc(tid, _lang)
		var is_ul := Catalog.is_table_relic_unlocked(_profile, tid) or (tid in tbl_rels)
		var is_eq := tid in tbl_rels
		var rcol: Color = tloc.get("col", COL_GOLD_TEXT)

		var card_pan := PanelContainer.new()
		card_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_pan.custom_minimum_size = Vector2(180, 146)
		card_pan.tooltip_text = str(tloc["desc"])
		card_pan.add_theme_stylebox_override("panel", _make_box_style(
			Color(0.20, 0.15, 0.08, 0.98) if is_eq else COL_WALNUT_DEEP,
			COL_GOLD_TEXT if is_eq else (Color(0.55, 0.42, 0.24, 0.80) if is_ul else Color(0.32, 0.26, 0.20, 0.65)),
			8, 6
		))

		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 4)
		card_pan.add_child(cvb)

		# Live 3D SubViewport preview (headless-safe)
		var vp_wrap := PanelContainer.new()
		vp_wrap.custom_minimum_size = Vector2(0, 66)
		vp_wrap.add_theme_stylebox_override("panel", _make_box_style(Color(0.04, 0.03, 0.025, 0.95), Color(0.38, 0.30, 0.18, 0.65), 6, 2))
		cvb.add_child(vp_wrap)

		if not is_headless:
			var svc := SubViewportContainer.new()
			svc.set_anchors_preset(Control.PRESET_FULL_RECT)
			svc.stretch = true
			svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vp_wrap.add_child(svc)

			var svp := SubViewport.new()
			svp.size = Vector2i(140, 66)
			svp.own_world_3d = true
			svp.transparent_bg = true
			svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			svc.add_child(svp)

			var env := WorldEnvironment.new()
			var we := Environment.new()
			we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			we.ambient_light_color = Color(0.55, 0.48, 0.40)
			we.ambient_light_energy = 1.25
			env.environment = we
			svp.add_child(env)

			var dl := DirectionalLight3D.new()
			dl.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
			dl.light_energy = 1.6
			svp.add_child(dl)

			var cam := Camera3D.new()
			cam.position = Vector3(0.0, 0.15, 1.35)
			cam.fov = 36.0
			svp.add_child(cam)

			var piv := Node3D.new()
			svp.add_child(piv)
			_relic_pivots.append(piv)
			_populate_mini_relic_3d(piv, tid, rcol)
		else:
			var hl_row := CenterContainer.new()
			hl_row.add_child(LialoIcons.make_icon_rect("trophy" if is_ul else "lock", 26, rcol if is_ul else COL_PARCHMENT_DIM))
			vp_wrap.add_child(hl_row)

		var n_lbl := Label.new()
		n_lbl.text = str(tloc["name"])
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n_lbl.clip_text = true
		n_lbl.add_theme_font_override("font", _font_disp)
		n_lbl.add_theme_font_size_override("font_size", 11)
		n_lbl.add_theme_color_override("font_color", COL_GOLD_TEXT if is_eq else (COL_PARCHMENT if is_ul else COL_PARCHMENT_DIM))
		cvb.add_child(n_lbl)

		var act_hb := HBoxContainer.new()
		act_hb.add_theme_constant_override("separation", 4)
		cvb.add_child(act_hb)

		var eq_btn := Button.new()
		eq_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_btn.custom_minimum_size = Vector2(0, 28)
		eq_btn.text = _tr("EQUIPPED", "NA STOLE") if is_eq else (_tr("Equip", "Vybrat") if is_ul else _tr("Locked", "Zamčeno"))
		LialoIcons.apply_button_icon(eq_btn, "check" if is_eq else ("trophy" if is_ul else "lock"), 13)
		eq_btn.disabled = not is_ul
		eq_btn.add_theme_font_override("font", _font_body)
		eq_btn.add_theme_font_size_override("font_size", 11)
		eq_btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.14, 0.28, 0.14, 0.96) if is_eq else COL_WALNUT_CARD,
			Color(0.46, 0.96, 0.58) if is_eq else Color(0.45, 0.36, 0.24), 6, 3
		))
		eq_btn.pressed.connect(func():
			sfx_requested.emit("ui_click")
			var arr: Array = _profile.get("table_relics", []).duplicate()
			if tid in arr:
				arr.erase(tid)
			else:
				while arr.size() >= 2:
					arr.pop_front()
				arr.append(tid)
				_bounce_relic_id = tid
			_profile["table_relics"] = arr
			_mark_tut_action(3)
			_sync_and_save()
			_rebuild_ui()
		)
		act_hb.add_child(eq_btn)

		var insp_btn := Button.new()
		insp_btn.custom_minimum_size = Vector2(46, 28)
		insp_btn.text = "3D"
		insp_btn.tooltip_text = _tr("Inspect 3D Relic", "Prohlédnout 3D relikvii")
		insp_btn.add_theme_font_override("font", _font_disp)
		insp_btn.add_theme_font_size_override("font_size", 11)
		insp_btn.add_theme_stylebox_override("normal", _make_box_style(COL_WALNUT_CARD, COL_GOLD_BORDER, 6, 3))
		insp_btn.pressed.connect(func():
			_open_relic_inspect(tid, is_ul, is_eq, str(tloc.get("unlock_hint", "")))
		)
		act_hb.add_child(insp_btn)

		if _bounce_relic_id == tid:
			card_pan.call_deferred("set_pivot_offset", Vector2(90, 73))
			_animate_relic_bounce(card_pan)

		tr_grid.add_child(card_pan)

	# Bottom Row: Visual Card Backs & Visual Sword Skins
	var cos_hb := HBoxContainer.new()
	cos_hb.add_theme_constant_override("separation", 12)
	parent.add_child(cos_hb)

	# Card Backs (Graphical Previews + Flip Tween)
	var cb_pan := PanelContainer.new()
	cb_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, COL_GOLD_BORDER, 10, 10))
	cos_hb.add_child(cb_pan)

	var cb_vb := VBoxContainer.new()
	cb_vb.add_theme_constant_override("separation", 8)
	cb_pan.add_child(cb_vb)
	cb_vb.add_child(LialoIcons.make_icon_label_row("cards", _tr("CARD BACK", "RUB KARET"), 18, 15, COL_GOLD_TEXT))

	var cb_grid := GridContainer.new()
	cb_grid.columns = 4
	cb_grid.add_theme_constant_override("h_separation", 8)
	cb_grid.add_theme_constant_override("v_separation", 8)
	cb_vb.add_child(cb_grid)

	var sel_deck := str(_profile.get("selected_deck", "klasic"))
	for d in CARD_BACKS:
		var did := str(d["id"])
		var is_sel := (did == sel_deck)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(96, 98)
		btn.tooltip_text = _tr(str(d["en"]), str(d["cs"]))
		btn.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.22, 0.16, 0.08, 0.98) if is_sel else COL_WALNUT_DEEP,
			COL_GOLD_TEXT if is_sel else Color(0.45, 0.35, 0.22, 0.78), 8, 4
		))
		btn.add_theme_stylebox_override("hover", _make_box_style(Color(0.26, 0.19, 0.10, 1.0), COL_GOLD_TEXT, 8, 4))

		var b_vb := VBoxContainer.new()
		b_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		b_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		b_vb.add_theme_constant_override("separation", 3)
		btn.add_child(b_vb)

		var b_tex := TextureRect.new()
		b_tex.texture = _get_table_tex(str(d["tex"]))
		b_tex.custom_minimum_size = Vector2(52, 68)
		b_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_vb.add_child(b_tex)

		var b_lbl := Label.new()
		b_lbl.text = _tr(str(d["en"]), str(d["cs"]))
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.clip_text = true
		b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_lbl.add_theme_font_override("font", _font_body)
		b_lbl.add_theme_font_size_override("font_size", 10)
		b_lbl.add_theme_color_override("font_color", COL_GOLD_TEXT if is_sel else COL_PARCHMENT_DIM)
		b_vb.add_child(b_lbl)

		btn.mouse_entered.connect(func():
			if is_instance_valid(btn):
				_animate_card_flip(btn)
		)
		if _flip_back_id == did:
			btn.call_deferred("set_pivot_offset", Vector2(48, 49))
			_animate_card_flip(btn)

		btn.pressed.connect(func():
			sfx_requested.emit("card_hover")
			_profile["selected_deck"] = did
			_flip_back_id = did
			_mark_tut_action(3)
			_sync_and_save()
			_rebuild_ui()
		)
		cb_grid.add_child(btn)

	# Sword Skins (Visual Blade Previews)
	var sw_pan := PanelContainer.new()
	sw_pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, COL_GOLD_BORDER, 10, 10))
	cos_hb.add_child(sw_pan)

	var sw_vb := VBoxContainer.new()
	sw_vb.add_theme_constant_override("separation", 8)
	sw_pan.add_child(sw_vb)
	sw_vb.add_child(LialoIcons.make_icon_label_row("sword", _tr("SWORD SKIN", "VZHLED MEČE"), 18, 15, COL_GOLD_TEXT))

	var sw_grid := GridContainer.new()
	sw_grid.columns = 3
	sw_grid.add_theme_constant_override("h_separation", 8)
	sw_grid.add_theme_constant_override("v_separation", 8)
	sw_vb.add_child(sw_grid)

	var owned_sw: Array = _profile.get("unlocked_swords", ["SWORD_IRON"])
	var eq_sw := str(_profile.get("equipped_sword", "SWORD_IRON"))
	for sw_raw in Catalog.SWORD_SKINS:
		var sid := str(sw_raw["id"])
		var swl := Catalog.get_sword_skin_loc(sid, _lang)
		var is_ul := (sid in owned_sw) or (sid == "SWORD_IRON")
		var is_eq := (sid == eq_sw)
		var blade_c: Color = swl.get("blade_col", Color.SILVER)
		var guard_c: Color = swl.get("guard_col", COL_GOLD_TEXT)
		var trail_c: Color = swl.get("trail_col", COL_GOLD_TEXT)

		var sbtn := Button.new()
		sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbtn.custom_minimum_size = Vector2(110, 98)
		sbtn.disabled = not is_ul
		sbtn.tooltip_text = str(swl["desc"])
		sbtn.add_theme_stylebox_override("normal", _make_box_style(
			Color(0.22, 0.15, 0.08, 0.98) if is_eq else COL_WALNUT_DEEP,
			trail_c if is_eq else Color(0.45, 0.35, 0.22, 0.78), 8, 5
		))
		sbtn.add_theme_stylebox_override("hover", _make_box_style(Color(0.26, 0.19, 0.10, 1.0), trail_c, 8, 5))

		var svb := VBoxContainer.new()
		svb.set_anchors_preset(Control.PRESET_FULL_RECT)
		svb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.alignment = BoxContainer.ALIGNMENT_CENTER
		svb.add_theme_constant_override("separation", 5)
		sbtn.add_child(svb)

		var sw_ic := LialoIcons.make_icon_rect("sword" if is_ul else "lock", 30, trail_c if is_ul else COL_PARCHMENT_DIM)
		sw_ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		svb.add_child(sw_ic)

		# Visual blade + guard + trail color bar
		var swatch_hb := HBoxContainer.new()
		swatch_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		swatch_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch_hb.add_theme_constant_override("separation", 2)
		svb.add_child(swatch_hb)
		for sc_item in [{"w": 24, "c": blade_c}, {"w": 10, "c": guard_c}, {"w": 18, "c": trail_c}]:
			var cr := ColorRect.new()
			cr.custom_minimum_size = Vector2(int(sc_item["w"]), 6)
			cr.color = sc_item["c"]
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_hb.add_child(cr)

		var sw_lbl := Label.new()
		sw_lbl.text = str(swl["name"])
		sw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sw_lbl.clip_text = true
		sw_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw_lbl.add_theme_font_override("font", _font_body)
		sw_lbl.add_theme_font_size_override("font_size", 11)
		sw_lbl.add_theme_color_override("font_color", COL_GOLD_TEXT if is_eq else COL_PARCHMENT)
		svb.add_child(sw_lbl)

		if is_ul:
			_attach_button_hover(sbtn, 1.04)

		sbtn.pressed.connect(func():
			sfx_requested.emit("ui_click")
			_profile["equipped_sword"] = sid
			_sync_and_save()
			_rebuild_ui()
		)
		sw_grid.add_child(sbtn)


func _populate_mini_relic_3d(pivot: Node3D, relic_id: String, accent: Color) -> void:
	var glb_path := Catalog.get_relic_glb_path(relic_id)
	if glb_path != "" and ResourceLoader.exists(glb_path):
		var packed := load(glb_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			if inst is Node3D:
				var n3 := inst as Node3D
				pivot.add_child(n3)
				var aabb := _compute_aabb(n3)
				var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
				if max_dim > 0.001:
					var sf := 0.65 / max_dim
					n3.scale = Vector3.ONE * sf
					n3.position = -aabb.get_center() * sf
				return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.42, 0.42, 0.42)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent
	mat.metallic = 0.75
	mat.roughness = 0.25
	mi.material_override = mat
	pivot.add_child(mi)


func _compute_aabb(node: Node3D) -> AABB:
	var has_box := false
	var total := AABB()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var b := (cur as MeshInstance3D).get_aabb()
			if not has_box:
				total = b
				has_box = true
			else:
				total = total.merge(b)
		for ch in cur.get_children():
			stack.append(ch)
	return total if has_box else AABB(Vector3(-0.25, -0.25, -0.25), Vector3(0.5, 0.5, 0.5))


# ============================================================================
# STEP 5: NAME & SAVE (NAMED DECKS + SAVE & PLAY)
# ============================================================================
func _build_step_5_name_save(parent: VBoxContainer, _sel_build_id: String, cur_build: Dictionary) -> void:
	var save_pan := PanelContainer.new()
	save_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, COL_GOLD_BORDER, 12, 14))
	parent.add_child(save_pan)

	if _save_flare_pending:
		_save_flare_pending = false
		save_pan.call_deferred("set_pivot_offset", Vector2(560, 80))
		_animate_save_flare(save_pan)

	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 10)
	save_pan.add_child(svb)

	svb.add_child(LialoIcons.make_icon_label_row(
		"scroll",
		_tr("NAME & SAVE", "POJMENOVAT A ULOŽIT"),
		20, 17, COL_GOLD_TEXT
	))

	var pc_arr: Array = _profile.get("custom_cards", [])
	var tr_arr: Array = _profile.get("table_relics", [])
	var seal_arr: Array = _profile.get("bankai_combo", [])
	var sw_loc := Catalog.get_sword_skin_loc(str(_profile.get("equipped_sword", "SWORD_IRON")), _lang)

	var sum_lbl := Label.new()
	sum_lbl.text = "%s  •  %s: %d/%d  •  %s: %d/4  •  %s: %d/2  •  %s" % [
		str(cur_build["name"]),
		_tr("Power", "Mocné"), pc_arr.size(), Catalog.MAX_POWER_CARDS,
		_tr("Seal", "Pečeť"), seal_arr.size(),
		_tr("Relics", "Relikvie"), tr_arr.size(),
		str(sw_loc["name"])
	]
	sum_lbl.add_theme_font_override("font", _font_body)
	sum_lbl.add_theme_font_size_override("font_size", 13)
	sum_lbl.add_theme_color_override("font_color", COL_PARCHMENT)
	svb.add_child(sum_lbl)

	var name_hb := HBoxContainer.new()
	name_hb.add_theme_constant_override("separation", 10)
	svb.add_child(name_hb)

	_deck_name_edit = LineEdit.new()
	_deck_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_name_edit.custom_minimum_size = Vector2(0, 44)
	_deck_name_edit.max_length = 28
	_deck_name_edit.placeholder_text = _tr("Deck name...", "Název balíčku...")
	_deck_name_edit.add_theme_font_override("font", _font_body)
	_deck_name_edit.add_theme_font_size_override("font_size", 14)
	_deck_name_edit.add_theme_stylebox_override("normal", _make_box_style(COL_WALNUT_DEEP, COL_GOLD_BORDER, 8, 8))
	name_hb.add_child(_deck_name_edit)

	var save_btn := Button.new()
	save_btn.custom_minimum_size = Vector2(160, 44)
	save_btn.text = _tr("Save Deck", "Uložit")
	LialoIcons.apply_button_icon(save_btn, "scroll", 18)
	save_btn.add_theme_font_override("font", _font_disp)
	save_btn.add_theme_font_size_override("font_size", 14)
	save_btn.add_theme_stylebox_override("normal", _make_box_style(COL_WALNUT_CARD, COL_GOLD_BORDER, 8, 8))
	_attach_button_hover(save_btn, 1.04)
	save_btn.pressed.connect(func():
		sfx_requested.emit("ui_click")
		var dname := _deck_name_edit.text.strip_edges() if is_instance_valid(_deck_name_edit) else ""
		if dname.is_empty():
			dname = str(cur_build["name"])
		Catalog.save_named_deck(_profile, dname)
		_save_flare_pending = true
		_mark_tut_action(4)
		_sync_and_save()
		_rebuild_ui()
		if is_instance_valid(_status_toast):
			_status_toast.text = _tr("Saved: %s" % dname, "Uloženo: %s" % dname)
	)
	name_hb.add_child(save_btn)

	var play_btn := Button.new()
	play_btn.custom_minimum_size = Vector2(190, 44)
	play_btn.text = _tr("SAVE & PLAY", "ULOŽIT A HRÁT")
	LialoIcons.apply_button_icon(play_btn, "check", 18)
	play_btn.add_theme_font_override("font", _font_disp)
	play_btn.add_theme_font_size_override("font_size", 15)
	play_btn.add_theme_stylebox_override("normal", _make_box_style(Color(0.14, 0.32, 0.16, 0.98), Color(0.46, 0.96, 0.56), 10, 8))
	_attach_button_hover(play_btn, 1.05)
	play_btn.pressed.connect(func():
		sfx_requested.emit("ui_click")
		var dname := _deck_name_edit.text.strip_edges() if is_instance_valid(_deck_name_edit) else ""
		if not dname.is_empty():
			Catalog.save_named_deck(_profile, dname)
		_animate_save_flare(save_pan)
		_mark_tut_action(4)
		_sync_and_save()
		if is_instance_valid(_status_toast):
			_status_toast.text = _tr("Ready for battle!", "Připraveno do boje!")
	)
	name_hb.add_child(play_btn)

	var list_pan := PanelContainer.new()
	list_pan.add_theme_stylebox_override("panel", _make_box_style(COL_WALNUT_BG, Color(0.55, 0.42, 0.24, 0.80), 10, 12))
	parent.add_child(list_pan)

	var lvb := VBoxContainer.new()
	lvb.add_theme_constant_override("separation", 8)
	list_pan.add_child(lvb)

	var saved_decks: Array = _profile.get("saved_decks", [])
	lvb.add_child(LialoIcons.make_icon_label_row(
		"cards",
		_tr("SAVED DECKS (%d / 8)" % saved_decks.size(), "ULOŽENÉ BALÍČKY (%d / 8)" % saved_decks.size()),
		18, 15, COL_GOLD_TEXT
	))

	if saved_decks.is_empty():
		var emp := Label.new()
		emp.text = _tr("No saved decks yet.", "Zatím žádný uložený balíček.")
		emp.add_theme_font_override("font", _font_body)
		emp.add_theme_font_size_override("font_size", 13)
		emp.add_theme_color_override("font_color", COL_PARCHMENT_DIM)
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
			info.text = "%s  •  %s" % [dname, str(db["name"])]
			info.add_theme_font_override("font", _font_body)
			info.add_theme_font_size_override("font_size", 13)
			info.add_theme_color_override("font_color", COL_PARCHMENT)
			row.add_child(info)

			var load_b := Button.new()
			load_b.custom_minimum_size = Vector2(104, 34)
			load_b.text = _tr("Load", "Načíst")
			LialoIcons.apply_button_icon(load_b, "check", 14)
			load_b.add_theme_font_override("font", _font_disp)
			load_b.add_theme_font_size_override("font_size", 12)
			load_b.add_theme_stylebox_override("normal", _make_box_style(COL_WALNUT_CARD, COL_GOLD_BORDER, 6, 4))
			load_b.pressed.connect(func():
				sfx_requested.emit("card_shuffle")
				if Catalog.apply_saved_deck(_profile, did):
					_sync_and_save()
					_rebuild_ui()
			)
			row.add_child(load_b)

			var del_b := Button.new()
			del_b.custom_minimum_size = Vector2(104, 34)
			del_b.text = _tr("Delete", "Smazat")
			LialoIcons.apply_button_icon(del_b, "cross", 14)
			del_b.add_theme_font_override("font", _font_disp)
			del_b.add_theme_font_size_override("font_size", 12)
			del_b.add_theme_stylebox_override("normal", _make_box_style(Color(0.22, 0.08, 0.08, 0.94), Color(0.82, 0.34, 0.30), 6, 4))
			del_b.pressed.connect(func():
				sfx_requested.emit("ui_click")
				Catalog.delete_saved_deck(_profile, did)
				_sync_and_save()
				_rebuild_ui()
			)
			row.add_child(del_b)


func _pretty_card_key(ck: String) -> String:
	return ck.replace("CERVEN_", "H-").replace("ZELEN_", "L-").replace("ZALUD_", "A-").replace("GULA_", "B-")


func _play_grand_seal_preview(build_id: String) -> void:
	if not is_instance_valid(_bankai_fx_preview):
		_bankai_fx_preview = BankaiFxScript.new()
		_bankai_fx_preview.layer = 98
		add_child(_bankai_fx_preview)
	var combo_arr: Array = _profile.get("bankai_combo", [])
	_bankai_fx_preview.trigger_bankai(build_id, _tr("GRAND SEAL PREVIEW", "UKÁZKA VELKÉ PEČETI"), combo_arr, _lang, false)
