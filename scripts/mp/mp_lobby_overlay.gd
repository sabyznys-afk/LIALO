class_name MpLobbyOverlay
extends Control

## Modern Animated Multiplayer Hub (2-4 Players, v0.194):
## - Animated MULTIPLAYER header with brass/crimson glow
## - Top Mode Tabs (Public Match, Private Match, Ranked, Unranked)
## - Streamlined PLAY / FIND MATCH & Private Room Code flow + Hidden Dev Settings
## - HD 256x256 MSAA 4X 3D Duelist Portraits + Clean Saved Builds ("Basic Set" + Custom)
## - Global / Local Leaderboard & Rivals powered by MpHistory
## - Zero System/Unicode Emojis (uses LialoIcons everywhere)

const Config = preload("res://scripts/mp/mp_config.gd")
const History = preload("res://scripts/mp/mp_history.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")
const Toon = preload("res://scripts/toon_style.gd")
const Icons = preload("res://scripts/ui/lialo_icons.gd")
const DeckBuilderScript = preload("res://scripts/ui/deck_builder_panel.gd")
const FONT_DISPLAY_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoBody.ttf"
const TESTER_FALLBACK_NAMES := [
	"Tester Arny",
	"Tester Simon",
	"Tester Kuba",
	"Tester Vera",
	"Tester Marek",
	"Tester Lukas",
]

signal close_requested
signal play_click_sfx
signal open_deck_builder_requested
signal open_dev_inspector_requested

var mp_net: Node = null
var _font_display: Font = null
var _font_body: Font = null

var _main_panel: PanelContainer
var _hdr_bar: PanelContainer
var _hdr_title_lbl: Label
var _hdr_sub_lbl: Label
var _bg_fx_canvas: Control
var _fx_t: float = 0.0
var _embers: Array[Dictionary] = []
var _bg_cards: Array[Dictionary] = []
var _smoke_wisps: Array[Dictionary] = []

var _conn_dot_lbl: Label
var _conn_dot_icon: TextureRect
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var room_code_box: HBoxContainer
var room_code_edit: LineEdit
var private_create_btn: Button
var private_join_btn: Button
var play_match_btn: Button
var dev_settings_btn: Button
var _dev_settings_panel: PanelContainer
var dev_inspector_btn: Button
var host_btn: Button
var join_btn: Button
var spawn_win_btn: Button
var leave_btn: Button

var status_lbl: Label
var share_bar: PanelContainer
var share_vpn_lbl: Label
var share_lan_lbl: Label
var share_pub_lbl: Label
var share_code_lbl: Label
var copy_vpn_btn: Button
var copy_lan_btn: Button
var copy_pub_btn: Button
var copy_code_btn: Button
var _vpn_copy_str: String = ""
var _lan_copy_str: String = ""
var _pub_copy_str: String = ""
var _room_code_str: String = ""

var _tab_btns: Array[Button] = []
var _tab_containers: Array[Control] = []
var _active_tab: int = 0
var _leaderboard_tab_btn: Button

var _mode_cards: Dictionary = {}
var _selected_match_mode: String = Config.MODE_UNRANKED
var _in_match_room: bool = false
var _mode_tabs_hb: Control
var _mode_pill_btn: Button
var _mode_drawer_panel: PanelContainer
var _mode_drawer_open: bool = false
var _arena_vpc: SubViewportContainer
var _arena_vp: SubViewport
var _arena_sword_l: Node3D
var _arena_sword_r: Node3D
var _arena_banners: Array[Node3D] = []
var _arena_torches: Array[OmniLight3D] = []
var _arena_clash_pulse: float = 0.0
var _room_banner_pan: PanelContainer
var _room_banner_lbl: Label
var _room_back_btn: Button
var _tab_bar_hb: HBoxContainer
var _left_col_vb: VBoxContainer
var _right_col_vb: VBoxContainer
var _duelist_section_hdr: Control
var _duelist_section_row: Control

var char_buttons: Dictionary = {}
var _char_portrait_pivots: Array[Dictionary] = []
var selected_char_id: String = "CHAR_GUILLOTINE"
var selected_arch_id: String = "GUILLOTINE_ACES"
var _active_saved_deck_id: String = ""

var _saved_decks_flow: HFlowContainer
var _saved_deck_btns: Dictionary = {}
var _build_summary_title: Label
var _build_summary_lbl: Label
var _grand_seal_lbl: Label
var _open_deck_builder_btn: Button

var _leaderboard_vb: VBoxContainer

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

var _deck_builder_modal: PanelContainer = null

var _profile: Dictionary = {}
var _prefs: Dictionary = {}
var _lang: String = "en"
var selected_power_cards: Array[String] = []
var selected_table_relics: Array[String] = []
var selected_passive_relics: Array[String] = []
var equipped_sword_id: String = "SWORD_IRON"


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
	_refresh_leaderboard()
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
	for sm in _smoke_wisps:
		sm["y"] = float(sm["y"]) - float(sm["spd"]) * delta
		if float(sm["y"]) < -0.10:
			sm["y"] = 1.08
			sm["x"] = randf()
	if is_instance_valid(_bg_fx_canvas):
		_bg_fx_canvas.queue_redraw()
	_arena_clash_pulse = maxf(0.0, _arena_clash_pulse - delta * 1.8)
	for ti in range(_arena_torches.size()):
		var tl := _arena_torches[ti]
		if is_instance_valid(tl):
			tl.light_energy = 2.6 + sin(_fx_t * 7.5 + float(ti) * 2.1) * 0.45 + _arena_clash_pulse * 2.5
	for bi in range(_arena_banners.size()):
		var bn := _arena_banners[bi]
		if is_instance_valid(bn):
			bn.rotation_degrees.x = sin(_fx_t * 1.8 + float(bi) * 1.4) * 4.5
			bn.rotation_degrees.z = cos(_fx_t * 1.4 + float(bi) * 1.9) * 2.2
	if is_instance_valid(_hdr_title_lbl):
		var glow_mix := 0.5 + 0.5 * sin(_fx_t * 2.2)
		var brass := Color(1.0, 0.86, 0.44)
		var crimson_gold := Color(1.0, 0.56, 0.34)
		_hdr_title_lbl.add_theme_color_override("font_color", brass.lerp(crimson_gold, glow_mix * 0.32))
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
		if is_instance_valid(_deck_builder_modal) and _deck_builder_modal.visible:
			_close_deck_builder_modal()
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
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


func _attach_hover_anim(btn: Button, hover_scale: float = 1.03) -> void:
	btn.mouse_entered.connect(func():
		if btn.disabled or not is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(hover_scale, hover_scale), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		if not is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
		var glow_border := Color(0.98, 0.80, 0.30, 0.98).lerp(accent, 0.45)
		var sb_sel := _make_tavern_panel_sb(Color(0.22, 0.14, 0.08, 0.96), glow_border, 3, 10, 10)
		sb_sel.border_width_bottom = 3
		sb_sel.shadow_color = Color(glow_border.r, glow_border.g, glow_border.b, 0.45)
		sb_sel.shadow_size = 10
		var sb_sel_h := sb_sel.duplicate() as StyleBoxFlat
		sb_sel_h.bg_color = Color(0.26, 0.17, 0.10, 0.98)
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
		var sb_unsel_h := _make_tavern_panel_sb(Color(0.11, 0.085, 0.065, 0.92), Color(accent.r, accent.g, accent.b, 0.82), 2, 10, 10)
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
	for _i in range(36):
		_embers.append({
			"x": randf(),
			"y": randf(),
			"r": randf_range(1.6, 4.2),
			"spd": randf_range(0.028, 0.085),
			"phase": randf_range(0.0, TAU),
			"alpha": randf_range(0.30, 0.78),
		})
	_smoke_wisps.clear()
	for _s in range(16):
		_smoke_wisps.append({
			"x": randf(),
			"y": randf(),
			"rad": randf_range(28.0, 62.0),
			"spd": randf_range(0.014, 0.032),
			"phase": randf_range(0.0, TAU),
			"alpha": randf_range(0.035, 0.075),
		})
	_bg_cards.clear()
	var card_x := [0.05, 0.95, 0.09, 0.91, 0.03, 0.97, 0.14, 0.86]
	for i in range(card_x.size()):
		_bg_cards.append({
			"x": card_x[i],
			"y": randf(),
			"rot": randf_range(-0.45, 0.45),
			"rspd": randf_range(-0.18, 0.18),
			"spd": randf_range(0.012, 0.028),
			"w": randf_range(34.0, 54.0),
		})


func _draw_bg_fx() -> void:
	# Minimal subtle atmospheric vignette; 3D Arena Stage provides the live gothic backdrop & foreground Oath Blades (v0.197)
	if not is_instance_valid(_bg_fx_canvas):
		return
	var sz := _bg_fx_canvas.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	var glow_p := 0.06 + 0.03 * sin(_fx_t * 1.9) + _arena_clash_pulse * 0.14
	_bg_fx_canvas.draw_circle(Vector2(sz.x * 0.5, sz.y * 0.55), sz.x * 0.24, Color(0.98, 0.58, 0.22, glow_p))


func _build_3d_arena_stage() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_arena_vpc = SubViewportContainer.new()
	_arena_vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena_vpc.stretch = true
	_arena_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arena_vpc)

	_arena_vp = SubViewport.new()
	_arena_vp.size = Vector2i(1280, 720)
	_arena_vp.own_world_3d = true
	_arena_vp.transparent_bg = true
	_arena_vp.msaa_3d = Viewport.MSAA_4X
	_arena_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_arena_vpc.add_child(_arena_vp)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.12, 0.10)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	_arena_vp.add_child(we)

	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.current = true
	cam.look_at_from_position(Vector3(0.0, 1.32, 2.35), Vector3(0.0, 0.78, 0.0), Vector3.UP)
	_arena_vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.64)
	key.light_energy = 1.65
	key.rotation_degrees = Vector3(-34.0, 28.0, 0.0)
	_arena_vp.add_child(key)

	for tx in [-1.45, 1.45]:
		var tl := OmniLight3D.new()
		tl.position = Vector3(tx, 1.55, -0.55)
		tl.light_color = Color(1.0, 0.56, 0.22)
		tl.light_energy = 2.6
		tl.omni_range = 4.5
		_arena_vp.add_child(tl)
		_arena_torches.append(tl)

	# Gothic Arena Oak Table
	var tbl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.55; cyl.bottom_radius = 1.48; cyl.height = 0.12; cyl.radial_segments = 48
	tbl.mesh = cyl
	tbl.position = Vector3(0.0, 0.56, 0.0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.16, 0.10, 0.07)
	if ResourceLoader.exists("res://assets/table/wood.png"):
		tmat.albedo_texture = load("res://assets/table/wood.png") as Texture2D
	tmat.roughness = 0.74
	tbl.material_override = tmat
	_arena_vp.add_child(tbl)

	# Swaying 3D Banners
	_arena_banners.clear()
	for bx in [-1.65, 1.65]:
		var bm := MeshInstance3D.new()
		var bp := PlaneMesh.new()
		bp.size = Vector2(0.42, 1.35)
		bp.orientation = PlaneMesh.FACE_Z
		bm.mesh = bp
		bm.position = Vector3(bx, 1.65, -1.35)
		var bmat := StandardMaterial3D.new()
		bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		bmat.albedo_color = Color(0.48, 0.09, 0.11)
		bmat.roughness = 0.85
		bm.material_override = bmat
		_arena_vp.add_child(bm)
		_arena_banners.append(bm)

	# Ink-textured embers GPUParticles3D
	if ResourceLoader.exists("res://shaders/relic_ink_particle.gdshader") and ResourceLoader.exists("res://assets/vfx/relic_ink_particles_atlas.png"):
		var gp := GPUParticles3D.new()
		gp.amount = 24
		gp.lifetime = 2.8
		gp.position = Vector3(0.0, 0.65, 0.0)
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(1.4, 0.1, 0.8)
		pm.direction = Vector3(0.0, 1.0, 0.0)
		pm.gravity = Vector3(0.0, 0.22, 0.0)
		pm.initial_velocity_min = 0.15
		pm.initial_velocity_max = 0.45
		gp.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.045, 0.045)
		var qmat := ShaderMaterial.new()
		qmat.shader = load("res://shaders/relic_ink_particle.gdshader") as Shader
		qmat.set_shader_parameter("atlas_tex", load("res://assets/vfx/relic_ink_particles_atlas.png") as Texture2D)
		qmat.set_shader_parameter("cell_idx", 7)
		qmat.set_shader_parameter("tint_color", Color(1.0, 0.72, 0.28, 0.85))
		qmat.set_shader_parameter("emission_boost", 1.2)
		qm.material = qmat
		gp.draw_pass_1 = qm
		_arena_vp.add_child(gp)

	# Foreground Crossed 3D Oath Blades on Arena Table
	var sw_path := "res://assets/models/swords/handdrawn_oathblade.glb"
	if ResourceLoader.exists(sw_path):
		var sw_scene := load(sw_path) as PackedScene
		if sw_scene != null:
			_arena_sword_l = sw_scene.instantiate() as Node3D
			_arena_sword_r = sw_scene.instantiate() as Node3D
			if is_instance_valid(_arena_sword_l) and is_instance_valid(_arena_sword_r):
				_arena_sword_l.scale = Vector3.ONE * 1.15
				_arena_sword_r.scale = Vector3.ONE * 1.15
				_arena_sword_l.position = Vector3(-0.34, 0.74, 0.42)
				_arena_sword_r.position = Vector3(0.34, 0.74, 0.42)
				_arena_sword_l.rotation_degrees = Vector3(18.0, 15.0, -44.0)
				_arena_sword_r.rotation_degrees = Vector3(18.0, -15.0, 44.0)
				_arena_vp.add_child(_arena_sword_l)
				_arena_vp.add_child(_arena_sword_r)


func _trigger_arena_sword_clash() -> void:
	_arena_clash_pulse = 1.0
	if not is_inside_tree() or not is_instance_valid(_arena_sword_l) or not is_instance_valid(_arena_sword_r):
		return
	var tw := create_tween().set_parallel(true)
	_arena_sword_l.position = Vector3(-0.62, 0.92, 0.52)
	_arena_sword_r.position = Vector3(0.62, 0.92, 0.52)
	_arena_sword_l.rotation_degrees = Vector3(8.0, 28.0, -72.0)
	_arena_sword_r.rotation_degrees = Vector3(8.0, -28.0, 72.0)
	tw.tween_property(_arena_sword_l, "position", Vector3(-0.34, 0.74, 0.42), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_arena_sword_r, "position", Vector3(0.34, 0.74, 0.42), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_arena_sword_l, "rotation_degrees", Vector3(18.0, 15.0, -44.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_arena_sword_r, "rotation_degrees", Vector3(18.0, -15.0, 44.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_ui() -> void:
	var bg_tex := Toon.tex("res://assets/ui/mp_arena_bg.png")
	if bg_tex == null:
		bg_tex = Toon.tex("res://assets/ui/lobby_tavern_handdrawn.png")
	if bg_tex == null:
		bg_tex = Toon.tex("res://assets/lobby/menu_bg_stredovek.png")
	if bg_tex != null:
		var bg_rect := TextureRect.new()
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_rect.texture = bg_tex
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_rect.modulate = Color(0.56, 0.46, 0.44, 1.0)
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_rect)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.018, 0.024, 0.64)
	add_child(dim)

	_build_3d_arena_stage()

	_bg_fx_canvas = Control.new()
	_bg_fx_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_fx_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_fx_canvas.draw.connect(_draw_bg_fx)
	add_child(_bg_fx_canvas)

	_main_panel = PanelContainer.new()
	_main_panel.anchor_left = 0.025; _main_panel.anchor_right = 0.975
	_main_panel.anchor_top = 0.025; _main_panel.anchor_bottom = 0.975
	_main_panel.clip_contents = false
	_main_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_main_panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 10)
	_main_panel.add_child(root_vb)

	# 1. Modern Animated MULTIPLAYER Header Bar (Brass / Crimson Glow)
	_hdr_bar = PanelContainer.new()
	var hdr_sb := _make_tavern_panel_sb(Color(0.14, 0.082, 0.058, 0.98), Color(0.92, 0.68, 0.28, 0.94), 2, 11, 10)
	hdr_sb.shadow_color = Color(0.76, 0.28, 0.14, 0.36)
	hdr_sb.shadow_size = 14
	_hdr_bar.add_theme_stylebox_override("panel", hdr_sb)
	root_vb.add_child(_hdr_bar)

	var hdr_hb := HBoxContainer.new()
	hdr_hb.add_theme_constant_override("separation", 12)
	_hdr_bar.add_child(hdr_hb)

	var logo_tex := Toon.tex("res://assets/lobby/title_lialo.png")
	if logo_tex != null:
		var logo_img := TextureRect.new()
		logo_img.texture = logo_tex
		logo_img.custom_minimum_size = Vector2(92, 34)
		logo_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr_hb.add_child(logo_img)

	hdr_hb.add_child(Icons.make_icon_rect("sword", 24, Color(1.0, 0.82, 0.36)))

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vb.add_theme_constant_override("separation", 0)
	hdr_hb.add_child(title_vb)

	_hdr_title_lbl = Label.new()
	_hdr_title_lbl.text = "MULTIPLAYER"
	_apply_font(_hdr_title_lbl, true)
	_hdr_title_lbl.add_theme_font_size_override("font_size", 22)
	_hdr_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	title_vb.add_child(_hdr_title_lbl)

	_hdr_sub_lbl = Label.new()
	_hdr_sub_lbl.text = "Krčmová aréna pro 2–4 hráče" if _lang == "cs" else "Tavern Arena Hub • 2–4 Players"
	_apply_font(_hdr_sub_lbl, false)
	_hdr_sub_lbl.add_theme_font_size_override("font_size", 11)
	_hdr_sub_lbl.add_theme_color_override("font_color", Color(0.84, 0.74, 0.58))
	title_vb.add_child(_hdr_sub_lbl)

	var conn_pill := PanelContainer.new()
	conn_pill.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.06, 0.05, 0.90), Color(0.52, 0.42, 0.28, 0.60), 1, 8, 7))
	hdr_hb.add_child(conn_pill)
	var conn_pill_hb := HBoxContainer.new()
	conn_pill_hb.add_theme_constant_override("separation", 6)
	conn_pill.add_child(conn_pill_hb)
	_conn_dot_icon = Icons.make_icon_rect("globe", 15, Color(0.74, 0.70, 0.64))
	conn_pill_hb.add_child(_conn_dot_icon)
	_conn_dot_lbl = Label.new()
	_conn_dot_lbl.text = "Offline"
	_apply_font(_conn_dot_lbl, false)
	_conn_dot_lbl.add_theme_font_size_override("font_size", 13)
	_conn_dot_lbl.add_theme_color_override("font_color", Color(0.74, 0.70, 0.64))
	conn_pill_hb.add_child(_conn_dot_lbl)

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
	close_btn.text = "Zpět" if _lang == "cs" else "Back"
	Icons.apply_button_icon(close_btn, "cross", 15)
	_style_tavern_btn(close_btn, Color(0.26, 0.10, 0.09, 0.95), Color(0.82, 0.36, 0.28, 0.88), false, 8)
	close_btn.pressed.connect(_close_lobby)
	hdr_hb.add_child(close_btn)

	# 2. Top Match Mode Tabs (Public Match | Private Match | Ranked | Unranked)
	var mode_wrap := VBoxContainer.new()
	mode_wrap.add_theme_constant_override("separation", 6)
	root_vb.add_child(mode_wrap)
	_mode_tabs_hb = mode_wrap

	var pill_row := HBoxContainer.new()
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_wrap.add_child(pill_row)

	_mode_pill_btn = Button.new()
	_mode_pill_btn.text = "UNRANKED  [CASUAL]  v"
	_mode_pill_btn.custom_minimum_size = Vector2(280, 38)
	Icons.apply_button_icon(_mode_pill_btn, "sword", 18)
	_style_tavern_btn(_mode_pill_btn, Color(0.14, 0.10, 0.07, 0.94), Color(0.92, 0.72, 0.30, 0.94), true, 12)
	_mode_pill_btn.pressed.connect(func():
		play_click_sfx.emit()
		_mode_drawer_open = not _mode_drawer_open
		if is_instance_valid(_mode_drawer_panel):
			_mode_drawer_panel.visible = _mode_drawer_open
			if _mode_drawer_open:
				_mode_drawer_panel.modulate.a = 0.0
				var mtw := _mode_drawer_panel.create_tween()
				mtw.tween_property(_mode_drawer_panel, "modulate:a", 1.0, 0.16)
	)
	pill_row.add_child(_mode_pill_btn)

	_mode_drawer_panel = PanelContainer.new()
	_mode_drawer_panel.visible = false
	_mode_drawer_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.06, 0.05, 0.94), Color(0.84, 0.64, 0.28, 0.88), 2, 10, 8))
	mode_wrap.add_child(_mode_drawer_panel)

	var mode_tabs_hb := HBoxContainer.new()
	mode_tabs_hb.add_theme_constant_override("separation", 8)
	_mode_drawer_panel.add_child(mode_tabs_hb)

	# Match Room Banner (shown when user enters Private/Public/Ranked/Unranked Match Room)
	_room_banner_pan = PanelContainer.new()
	_room_banner_pan.visible = false
	_room_banner_pan.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.11, 0.08, 0.055, 0.96), Color(0.95, 0.74, 0.28, 0.90), 2, 10, 8))
	root_vb.add_child(_room_banner_pan)
	var rb_hb := HBoxContainer.new()
	rb_hb.add_theme_constant_override("separation", 10)
	_room_banner_pan.add_child(rb_hb)
	rb_hb.add_child(Icons.make_icon_rect("lock", 18, Color(0.98, 0.78, 0.30)))
	_room_banner_lbl = Label.new()
	_room_banner_lbl.text = "MATCH ROOM"
	_room_banner_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(_room_banner_lbl, true)
	_room_banner_lbl.add_theme_font_size_override("font_size", 16)
	_room_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	rb_hb.add_child(_room_banner_lbl)
	_room_back_btn = Button.new()
	_room_back_btn.text = "← Change Mode"
	_room_back_btn.custom_minimum_size = Vector2(142, 30)
	_style_tavern_btn(_room_back_btn, Color(0.18, 0.13, 0.09, 0.94), Color(0.76, 0.60, 0.30, 0.85), false, 7, false)
	_room_back_btn.pressed.connect(func():
		play_click_sfx.emit()
		_in_match_room = false
		if mp_net != null and bool(mp_net.get("in_session")):
			mp_net.leave_room(true)
		_refresh_controls()
	)
	rb_hb.add_child(_room_back_btn)

	var mode_defs := [
		{
			"id": Config.MODE_PUBLIC,
			"title": "Public Match",
			"badge": "OPEN LOBBY",
			"tip": "Quick Match / Public Lobby",
			"icon": "globe",
			"col": Color(0.36, 0.86, 0.98),
		},
		{
			"id": Config.MODE_PRIVATE,
			"title": "Private Match",
			"badge": "ROOM CODE",
			"tip": "Host or Join with a Private Room Code",
			"icon": "lock",
			"col": Color(0.98, 0.76, 0.28),
		},
		{
			"id": Config.MODE_RANKED,
			"title": "Ranked",
			"badge": "ELO • FAIR",
			"tip": "Competitive ELO / Balanced Arena Ruleset",
			"icon": "trophy",
			"col": Color(0.98, 0.38, 0.34),
		},
		{
			"id": Config.MODE_UNRANKED,
			"title": "Unranked",
			"badge": "CASUAL",
			"tip": "Casual Tavern Duel / Campaign Vault Allowed",
			"icon": "sword",
			"col": Color(0.46, 0.92, 0.58),
		},
	]
	_mode_cards.clear()
	for md in mode_defs:
		var mid := str(md["id"])
		var mcol: Color = md["col"]
		var mbtn := Button.new()
		mbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mbtn.custom_minimum_size = Vector2(0, 40)
		mbtn.text = "%s  [%s]" % [str(md["title"]), str(md["badge"])]
		mbtn.tooltip_text = str(md["tip"])
		mbtn.toggle_mode = true
		Icons.apply_button_icon(mbtn, str(md["icon"]), 16)
		mbtn.pressed.connect(func():
			play_click_sfx.emit()
			_select_match_mode(mid)
		)
		_apply_choice_btn_style(mbtn, mid == _selected_match_mode, mcol)
		_attach_mode_card_anim(mbtn, mid, mcol)
		_mode_cards[mid] = mbtn
		mode_tabs_hb.add_child(mbtn)

	# 3. Streamlined Connection & Profile Strip
	var conn_hb := HBoxContainer.new()
	conn_hb.add_theme_constant_override("separation", 8)
	root_vb.add_child(conn_hb)

	var n_lbl := Label.new(); n_lbl.text = "Name:"
	_apply_font(n_lbl, false); n_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	conn_hb.add_child(n_lbl)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(150, 38)
	name_edit.text = _resolve_default_player_name()
	name_edit.text_submitted.connect(func(_t): _persist_ui_prefs(); _refresh_leaderboard())
	name_edit.focus_exited.connect(func(): _persist_ui_prefs(); _refresh_leaderboard())
	_style_tavern_input(name_edit)
	conn_hb.add_child(name_edit)

	play_match_btn = Button.new()
	play_match_btn.text = "PLAY / FIND MATCH"
	Icons.apply_button_icon(play_match_btn, "sword", 17)
	play_match_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_match_btn.custom_minimum_size = Vector2(220, 38)
	_style_tavern_btn(play_match_btn, Color(0.28, 0.16, 0.08, 0.98), Color(0.96, 0.76, 0.26, 0.96), true, 9)
	play_match_btn.pressed.connect(_on_play_match_pressed)
	conn_hb.add_child(play_match_btn)

	room_code_box = HBoxContainer.new()
	room_code_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_code_box.add_theme_constant_override("separation", 8)
	room_code_box.visible = false
	conn_hb.add_child(room_code_box)
	var rc_lbl := Label.new(); rc_lbl.text = "Room Code:"
	_apply_font(rc_lbl, false); rc_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42))
	room_code_box.add_child(rc_lbl)
	room_code_edit = LineEdit.new()
	room_code_edit.custom_minimum_size = Vector2(124, 38)
	room_code_edit.max_length = 8
	room_code_edit.placeholder_text = "ENTER CODE"
	_style_tavern_input(room_code_edit)
	room_code_box.add_child(room_code_edit)

	private_create_btn = Button.new()
	private_create_btn.text = "CREATE ROOM"
	Icons.apply_button_icon(private_create_btn, "fire", 16)
	private_create_btn.custom_minimum_size = Vector2(148, 38)
	_style_tavern_btn(private_create_btn, Color(0.32, 0.16, 0.08, 0.96), Color(0.94, 0.70, 0.24, 0.94), true, 8)
	private_create_btn.pressed.connect(_on_host_pressed)
	room_code_box.add_child(private_create_btn)

	private_join_btn = Button.new()
	private_join_btn.text = "JOIN CODE"
	Icons.apply_button_icon(private_join_btn, "lock", 16)
	private_join_btn.custom_minimum_size = Vector2(136, 38)
	_style_tavern_btn(private_join_btn, Color(0.14, 0.22, 0.18, 0.96), Color(0.56, 0.82, 0.62, 0.90), true, 8)
	private_join_btn.pressed.connect(_on_private_join_pressed)
	room_code_box.add_child(private_join_btn)

	leave_btn = Button.new()
	leave_btn.text = "Disconnect"
	Icons.apply_button_icon(leave_btn, "cross", 14)
	leave_btn.custom_minimum_size = Vector2(118, 38)
	_style_tavern_btn(leave_btn, Color(0.24, 0.11, 0.10, 0.94), Color(0.74, 0.36, 0.30, 0.85), false, 8)
	leave_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net:
			mp_net.leave_room(true)
	)
	conn_hb.add_child(leave_btn)

	dev_settings_btn = Button.new()
	dev_settings_btn.text = ""
	dev_settings_btn.tooltip_text = "Dev Settings (IP / Port / Host / Join / Asset Inspector)"
	Icons.apply_button_icon(dev_settings_btn, "gear", 16)
	dev_settings_btn.custom_minimum_size = Vector2(38, 38)
	dev_settings_btn.toggle_mode = true
	dev_settings_btn.button_pressed = false
	_style_tavern_btn(dev_settings_btn, Color(0.14, 0.11, 0.09, 0.92), Color(0.58, 0.48, 0.32, 0.78), false, 8)
	dev_settings_btn.pressed.connect(func():
		play_click_sfx.emit()
		if is_instance_valid(_dev_settings_panel):
			_dev_settings_panel.visible = dev_settings_btn.button_pressed
	)
	conn_hb.add_child(dev_settings_btn)

	# Collapsible Dev Settings Panel (hidden by default)
	_dev_settings_panel = PanelContainer.new()
	_dev_settings_panel.visible = false
	_dev_settings_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.06, 0.048, 0.038, 0.95), Color(0.56, 0.44, 0.24, 0.76), 1, 9, 8))
	root_vb.add_child(_dev_settings_panel)

	var dev_hb := HBoxContainer.new()
	dev_hb.add_theme_constant_override("separation", 8)
	_dev_settings_panel.add_child(dev_hb)

	var dev_tag := Label.new()
	dev_tag.text = "DEV:"
	_apply_font(dev_tag, true)
	dev_tag.add_theme_font_size_override("font_size", 12)
	dev_tag.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38))
	dev_hb.add_child(dev_tag)

	var ip_lbl := Label.new(); ip_lbl.text = "Host IP:"
	_apply_font(ip_lbl, false); ip_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	dev_hb.add_child(ip_lbl)
	ip_edit = LineEdit.new()
	ip_edit.custom_minimum_size = Vector2(132, 34)
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Radmin / LAN IP"
	_style_tavern_input(ip_edit)
	dev_hb.add_child(ip_edit)

	var p_lbl := Label.new(); p_lbl.text = "Port:"
	_apply_font(p_lbl, false); p_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	dev_hb.add_child(p_lbl)
	port_edit = LineEdit.new()
	port_edit.custom_minimum_size = Vector2(66, 34)
	port_edit.text = str(Config.DEFAULT_PORT)
	_style_tavern_input(port_edit)
	dev_hb.add_child(port_edit)

	host_btn = Button.new()
	host_btn.text = "HOST TABLE"
	Icons.apply_button_icon(host_btn, "fire", 15)
	host_btn.custom_minimum_size = Vector2(128, 34)
	_style_tavern_btn(host_btn, Color(0.32, 0.16, 0.08, 0.96), Color(0.94, 0.70, 0.24, 0.94), true, 8)
	host_btn.pressed.connect(_on_host_pressed)
	dev_hb.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "JOIN TABLE"
	Icons.apply_button_icon(join_btn, "players", 15)
	join_btn.custom_minimum_size = Vector2(124, 34)
	_style_tavern_btn(join_btn, Color(0.14, 0.22, 0.18, 0.96), Color(0.56, 0.82, 0.62, 0.90), true, 8)
	join_btn.pressed.connect(_on_join_pressed)
	dev_hb.add_child(join_btn)

	if OS.has_feature("editor") or ("--mp-test" in OS.get_cmdline_args()):
		spawn_win_btn = Button.new()
		spawn_win_btn.text = "+2nd"
		Icons.apply_button_icon(spawn_win_btn, "dice", 14)
		spawn_win_btn.tooltip_text = "Open a 2nd local client window for instant loopback testing"
		spawn_win_btn.custom_minimum_size = Vector2(78, 34)
		_style_tavern_btn(spawn_win_btn, Color(0.16, 0.13, 0.10, 0.94), Color(0.62, 0.50, 0.30, 0.80), false, 8)
		spawn_win_btn.pressed.connect(func():
			play_click_sfx.emit()
			OS.create_instance(["--mp-test"])
			_on_status_changed("Launched 2nd window — click JOIN TABLE there!", false)
		)
		dev_hb.add_child(spawn_win_btn)

	dev_inspector_btn = Button.new()
	dev_inspector_btn.text = "Asset Inspector [F9]"
	Icons.apply_button_icon(dev_inspector_btn, "relic", 14)
	dev_inspector_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_inspector_btn.custom_minimum_size = Vector2(150, 34)
	_style_tavern_btn(dev_inspector_btn, Color(0.15, 0.13, 0.18, 0.94), Color(0.62, 0.54, 0.82, 0.84), false, 8)
	dev_inspector_btn.pressed.connect(func():
		play_click_sfx.emit()
		open_dev_inspector_requested.emit()
	)
	dev_hb.add_child(dev_inspector_btn)

	status_lbl = Label.new()
	status_lbl.text = "Select a match mode above, customize your Duelist & Build, then press PLAY / FIND MATCH."
	_apply_font(status_lbl, false)
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	root_vb.add_child(status_lbl)

	# 3. Smart VPN + LAN + UPnP + Room Code Share Address Bar (visible when Hosting)
	share_bar = PanelContainer.new()
	share_bar.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.09, 0.14, 0.11, 0.94), Color(0.46, 0.80, 0.58, 0.88), 1, 9, 8))
	share_bar.visible = false
	root_vb.add_child(share_bar)

	var share_hb := HBoxContainer.new()
	share_hb.add_theme_constant_override("separation", 10)
	share_bar.add_child(share_hb)

	share_code_lbl = Label.new()
	_apply_font(share_code_lbl, true)
	share_code_lbl.add_theme_font_size_override("font_size", 13)
	share_code_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	share_code_lbl.visible = false
	share_hb.add_child(share_code_lbl)

	copy_code_btn = Button.new()
	copy_code_btn.text = "Copy Code"
	Icons.apply_button_icon(copy_code_btn, "lock", 14)
	copy_code_btn.custom_minimum_size = Vector2(104, 28)
	_style_tavern_btn(copy_code_btn, Color(0.24, 0.18, 0.08, 0.96), Color(0.94, 0.74, 0.28, 0.92), false, 7)
	copy_code_btn.visible = false
	copy_code_btn.pressed.connect(func():
		play_click_sfx.emit()
		_copy_and_toast(_room_code_str, "Room Code")
	)
	share_hb.add_child(copy_code_btn)

	share_vpn_lbl = Label.new()
	_apply_font(share_vpn_lbl, false)
	share_vpn_lbl.add_theme_font_size_override("font_size", 13)
	share_vpn_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
	share_hb.add_child(share_vpn_lbl)

	copy_vpn_btn = Button.new()
	copy_vpn_btn.text = "Copy VPN"
	Icons.apply_button_icon(copy_vpn_btn, "scroll", 14)
	copy_vpn_btn.custom_minimum_size = Vector2(102, 28)
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
	copy_lan_btn.text = "Copy LAN"
	Icons.apply_button_icon(copy_lan_btn, "tavern", 14)
	copy_lan_btn.custom_minimum_size = Vector2(102, 28)
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
	copy_pub_btn.text = "Copy Public"
	Icons.apply_button_icon(copy_pub_btn, "globe", 14)
	copy_pub_btn.custom_minimum_size = Vector2(114, 28)
	_style_tavern_btn(copy_pub_btn, Color(0.14, 0.18, 0.26, 0.94), Color(0.48, 0.74, 0.96, 0.88), false, 7)
	copy_pub_btn.pressed.connect(func():
		play_click_sfx.emit()
		_copy_and_toast(_pub_copy_str, "Public IP")
	)
	share_hb.add_child(copy_pub_btn)

	# 4. Split Content: Left = 2-Tab Hub (Play & Loadout | Leaderboard & Rivals), Right = 4-Seat Table & Chat & Start
	var body_hb := HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 16)
	root_vb.add_child(body_hb)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.22
	left_col.add_theme_constant_override("separation", 8)
	body_hb.add_child(left_col)
	_left_col_vb = left_col

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	left_col.add_child(tab_bar)
	_tab_bar_hb = tab_bar

	var tab_defs := [
		{"label": "Play & Loadout", "icon": "sword"},
		{"label": "Leaderboard & Rivals", "icon": "trophy"},
	]
	_tab_btns.clear()
	_tab_containers.clear()
	for ti in range(tab_defs.size()):
		var tb := Button.new()
		tb.text = str(tab_defs[ti]["label"])
		Icons.apply_button_icon(tb, str(tab_defs[ti]["icon"]), 16)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 38)
		tb.toggle_mode = true
		var tab_idx := ti
		tb.pressed.connect(func():
			play_click_sfx.emit()
			_switch_tab(tab_idx)
		)
		_tab_btns.append(tb)
		tab_bar.add_child(tb)
		if ti == 1:
			_leaderboard_tab_btn = tb

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(left_scroll)

	var tabs_host := VBoxContainer.new()
	tabs_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(tabs_host)

	# --- TAB 0: Play & Loadout (4 Mode Cards + 3D Character + 1-Click Saved Build Selector) ---
	var tab0 := VBoxContainer.new()
	tab0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab0.add_theme_constant_override("separation", 10)
	tabs_host.add_child(tab0)
	_tab_containers.append(tab0)
	_build_play_loadout_tab(tab0)

	# --- TAB 1: Global / Local Leaderboard & Recent Rivals ---
	var tab1 := VBoxContainer.new()
	tab1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab1.add_theme_constant_override("separation", 8)
	tabs_host.add_child(tab1)
	_tab_containers.append(tab1)
	_leaderboard_vb = VBoxContainer.new()
	_leaderboard_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_vb.add_theme_constant_override("separation", 8)
	tab1.add_child(_leaderboard_vb)

	# --- RIGHT COLUMN: 4-Seat Table Roster, Rules, Atmosphere, Chat & Launch ---
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.size_flags_stretch_ratio = 0.90
	right_vb.add_theme_constant_override("separation", 8)
	body_hb.add_child(right_vb)
	_right_col_vb = right_vb

	var settings_hb := HBoxContainer.new()
	settings_hb.add_theme_constant_override("separation", 8)
	right_vb.add_child(settings_hb)

	rule_btn = Button.new()
	rule_btn.text = "Ruleset: Campaign Vault"
	Icons.apply_button_icon(rule_btn, "shield", 15)
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
	vista_btn.text = "Full Moon Tavern"
	Icons.apply_button_icon(vista_btn, "tavern", 15)
	vista_btn.clip_text = true
	vista_btn.custom_minimum_size = Vector2(185, 36)
	_style_tavern_btn(vista_btn, Color(0.12, 0.13, 0.18, 0.94), Color(0.56, 0.68, 0.88, 0.86), false, 8)
	vista_btn.pressed.connect(_cycle_vista_era)
	settings_hb.add_child(vista_btn)

	var r_title_row := Icons.make_icon_label_row("players", "TAVERN ROUND TABLE (2–4 SEATS)", 18, 15, Color(1.0, 0.86, 0.42))
	for child in r_title_row.get_children():
		if child is Label:
			_apply_font(child, true)
	right_vb.add_child(r_title_row)

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
	var quick_msgs := [
		{"txt": "Ready!", "icon": "check"},
		{"txt": "Rematch!", "icon": "fire"},
		{"txt": "GL HF!", "icon": "tavern"},
		{"txt": "Wait 1m", "icon": "hourglass"},
	]
	for qm in quick_msgs:
		var eb := Button.new()
		eb.text = str(qm["txt"])
		Icons.apply_button_icon(eb, str(qm["icon"]), 13)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eb.custom_minimum_size = Vector2(0, 26)
		eb.add_theme_font_size_override("font_size", 11)
		_style_tavern_btn(eb, Color(0.14, 0.11, 0.08, 0.92), Color(0.58, 0.46, 0.26, 0.78), false, 6, false)
		var msg_send: String = str(qm["txt"])
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
	add_bot_btn.text = "+Add Bot"
	Icons.apply_button_icon(add_bot_btn, "players", 16)
	add_bot_btn.custom_minimum_size = Vector2(132, 44)
	_style_tavern_btn(add_bot_btn, Color(0.16, 0.13, 0.10, 0.96), Color(0.68, 0.54, 0.30, 0.88), false, 9)
	add_bot_btn.pressed.connect(func():
		play_click_sfx.emit()
		if mp_net:
			mp_net.add_test_bot()
	)
	bot_hb.add_child(add_bot_btn)

	ready_btn = Button.new()
	ready_btn.text = "READY"
	Icons.apply_button_icon(ready_btn, "check", 16)
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
	start_btn.text = "START TAVERN BRAWL"
	Icons.apply_button_icon(start_btn, "sword", 18)
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


func _build_play_loadout_tab(parent_vb: VBoxContainer) -> void:
	# 1. 3D Duelist Character Picker (Mode selection lives in the top mode tabs)
	var c_title := Icons.make_icon_label_row("crown", "CHOOSE YOUR 3D DUELIST", 16, 14, Color(0.95, 0.84, 0.54))
	for child in c_title.get_children():
		if child is Label:
			_apply_font(child, true)
	parent_vb.add_child(c_title)
	_duelist_section_hdr = c_title

	var char_back_map := {
		"CHAR_GUILLOTINE": "res://assets/table/deck_back_obsidian.png",
		"CHAR_MONARCH": "res://assets/table/deck_back_stredovek.png",
		"CHAR_JESTER": "res://assets/table/deck_back_prohibicia.png",
		"CHAR_MISTBLADE": "res://assets/table/deck_back_astral.png",
	}

	var char_hb := HBoxContainer.new()
	char_hb.add_theme_constant_override("separation", 8)
	parent_vb.add_child(char_hb)
	_duelist_section_row = char_hb
	_char_portrait_pivots.clear()
	for ch_idx in range(Config.CHARACTERS.size()):
		var ch: Dictionary = Config.CHARACTERS[ch_idx]
		var cid := str(ch["id"])
		var ch_accent: Color = ch.get("col", Color(0.95, 0.78, 0.30))
		var cb := Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 144)
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
		var name_row := HBoxContainer.new()
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.add_theme_constant_override("separation", 4)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(Icons.make_icon_rect(str(ch.get("icon", "sword")), 13, ch_accent))
		var cname_lbl := Label.new()
		cname_lbl.text = str(ch.get("name_cs" if _lang == "cs" else "name", ch["name"]))
		cname_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cname_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_apply_font(cname_lbl, true)
		cname_lbl.add_theme_font_size_override("font_size", 11)
		cname_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
		cname_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(cname_lbl)
		card_vb.add_child(name_row)
		cb.pressed.connect(func():
			play_click_sfx.emit()
			_select_character(cid)
		)
		_apply_choice_btn_style(cb, cid == selected_char_id, ch_accent)
		_attach_hover_anim(cb)
		char_buttons[cid] = cb
		char_hb.add_child(cb)

	# 3. 1-Click Saved Build / Deck Preset Selector + Active Build Summary + Open Deck Builder
	var deck_hdr_hb := HBoxContainer.new()
	deck_hdr_hb.add_theme_constant_override("separation", 8)
	parent_vb.add_child(deck_hdr_hb)

	var d_title := Icons.make_icon_label_row("cards", "SAVED BUILDS & DECK PRESETS", 16, 14, Color(1.0, 0.86, 0.42))
	d_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in d_title.get_children():
		if child is Label:
			_apply_font(child, true)
	deck_hdr_hb.add_child(d_title)

	_open_deck_builder_btn = Button.new()
	_open_deck_builder_btn.text = "Deck Builder"
	Icons.apply_button_icon(_open_deck_builder_btn, "gear", 14)
	_open_deck_builder_btn.custom_minimum_size = Vector2(132, 32)
	_style_tavern_btn(_open_deck_builder_btn, Color(0.20, 0.14, 0.08, 0.96), Color(0.90, 0.70, 0.28, 0.92), true, 8)
	_open_deck_builder_btn.pressed.connect(func():
		play_click_sfx.emit()
		_open_deck_builder_modal()
	)
	deck_hdr_hb.add_child(_open_deck_builder_btn)

	_saved_decks_flow = HFlowContainer.new()
	_saved_decks_flow.add_theme_constant_override("h_separation", 8)
	_saved_decks_flow.add_theme_constant_override("v_separation", 8)
	parent_vb.add_child(_saved_decks_flow)

	var sum_pan := PanelContainer.new()
	sum_pan.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.06, 0.05, 0.038, 0.90), Color(0.60, 0.44, 0.22, 0.72), 1, 10, 12))
	parent_vb.add_child(sum_pan)
	var sum_vb := VBoxContainer.new()
	sum_vb.add_theme_constant_override("separation", 5)
	sum_pan.add_child(sum_vb)

	var sum_top := HBoxContainer.new()
	sum_top.add_theme_constant_override("separation", 8)
	sum_vb.add_child(sum_top)
	sum_top.add_child(Icons.make_icon_rect("seal", 16, Color(0.45, 0.92, 1.0)))
	_build_summary_title = Label.new()
	_build_summary_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(_build_summary_title, true)
	_build_summary_title.add_theme_font_size_override("font_size", 14)
	_build_summary_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	sum_top.add_child(_build_summary_title)

	_grand_seal_lbl = Label.new()
	_apply_font(_grand_seal_lbl, false)
	_grand_seal_lbl.add_theme_font_size_override("font_size", 12)
	_grand_seal_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	sum_vb.add_child(_grand_seal_lbl)

	_build_summary_lbl = Label.new()
	_build_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(_build_summary_lbl, false)
	_build_summary_lbl.add_theme_font_size_override("font_size", 12)
	_build_summary_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	sum_vb.add_child(_build_summary_lbl)

	_rebuild_saved_deck_selector()


func _attach_mode_card_anim(btn: Button, mode_id: String, accent: Color) -> void:
	btn.mouse_entered.connect(func():
		if btn.disabled or not is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.028, 1.028), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var sb := btn.get_theme_stylebox("hover") as StyleBoxFlat
		if sb != null:
			sb.border_color = accent.lightened(0.22)
	)
	btn.mouse_exited.connect(func():
		if not is_inside_tree():
			return
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if mode_id != _selected_match_mode:
			_apply_choice_btn_style(btn, false, accent)
	)


func _select_match_mode(mode_id: String) -> void:
	_selected_match_mode = mode_id
	_in_match_room = true
	_mode_drawer_open = false
	if is_instance_valid(_mode_drawer_panel):
		_mode_drawer_panel.visible = false
	if is_instance_valid(_mode_pill_btn):
		var p_labels := {
			Config.MODE_PUBLIC: "PUBLIC MATCH  [OPEN]  v",
			Config.MODE_PRIVATE: "PRIVATE MATCH  [CODE]  v",
			Config.MODE_RANKED: "RANKED  [ELO]  v",
			Config.MODE_UNRANKED: "UNRANKED  [CASUAL]  v",
		}
		_mode_pill_btn.text = str(p_labels.get(mode_id, "UNRANKED  v"))
	_trigger_arena_sword_clash()
	if _active_tab != 0:
		_switch_tab(0)
	var mode_colors := {
		Config.MODE_PUBLIC: Color(0.36, 0.86, 0.98),
		Config.MODE_PRIVATE: Color(0.98, 0.76, 0.28),
		Config.MODE_RANKED: Color(0.98, 0.38, 0.34),
		Config.MODE_UNRANKED: Color(0.46, 0.92, 0.58),
	}
	for k in _mode_cards.keys():
		var m_k := str(k)
		var is_sel := (m_k == mode_id)
		var b: Button = _mode_cards[k]
		b.set_pressed_no_signal(is_sel)
		_apply_choice_btn_style(b, is_sel, mode_colors.get(m_k, Color(0.95, 0.78, 0.30)))
	if is_instance_valid(room_code_box):
		room_code_box.visible = (mode_id == Config.MODE_PRIVATE)
	if mp_net != null and mp_net.has_method("set_match_mode"):
		mp_net.set_match_mode(mode_id)
	_persist_ui_prefs()
	_refresh_controls()
	if is_inside_tree() and is_instance_valid(_main_panel):
		_main_panel.modulate.a = 0.82
		var rtw := _main_panel.create_tween()
		rtw.tween_property(_main_panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _rebuild_saved_deck_selector() -> void:
	if not is_instance_valid(_saved_decks_flow):
		return
	for c in _saved_decks_flow.get_children():
		c.queue_free()
	_saved_deck_btns.clear()

	# Always show 1 default "Basic Set" + player's own saved builds from profile["saved_decks"]
	var basic_btn := Button.new()
	basic_btn.text = "Basic Set"
	Icons.apply_button_icon(basic_btn, "cards", 14)
	basic_btn.custom_minimum_size = Vector2(148, 36)
	basic_btn.toggle_mode = true
	var is_basic_sel := _active_saved_deck_id.is_empty()
	basic_btn.set_pressed_no_signal(is_basic_sel)
	basic_btn.pressed.connect(func():
		play_click_sfx.emit()
		_apply_core_build_preset("GUILLOTINE_ACES")
	)
	_apply_choice_btn_style(basic_btn, is_basic_sel, Color(0.95, 0.78, 0.30))
	_attach_hover_anim(basic_btn)
	_saved_deck_btns["__BASIC_SET__"] = basic_btn
	_saved_decks_flow.add_child(basic_btn)

	var saved_decks: Array = _profile.get("saved_decks", [])
	for sd_v in saved_decks:
		if not (sd_v is Dictionary):
			continue
		var sd := sd_v as Dictionary
		var did := str(sd.get("id", ""))
		var dname := str(sd.get("name", "Saved Build"))
		var bid := str(sd.get("build_id", "GUILLOTINE_ACES"))
		var bcol: Color = Catalog.get_deck_build(bid).get("col", Color(0.95, 0.78, 0.30))
		var btn := Button.new()
		btn.text = dname
		Icons.apply_button_icon(btn, "cards", 14)
		btn.custom_minimum_size = Vector2(148, 36)
		btn.toggle_mode = true
		var is_sel := (_active_saved_deck_id == did)
		btn.set_pressed_no_signal(is_sel)
		btn.pressed.connect(func():
			play_click_sfx.emit()
			_apply_saved_deck_preset(did)
		)
		_apply_choice_btn_style(btn, is_sel, bcol)
		_attach_hover_anim(btn)
		_saved_deck_btns[did] = btn
		_saved_decks_flow.add_child(btn)

	_update_deck_summary(Config.get_archetype(selected_arch_id))


func _apply_saved_deck_preset(deck_id: String) -> void:
	if Catalog.apply_saved_deck(_profile, deck_id):
		_active_saved_deck_id = deck_id
		Catalog.save_profile(_profile)
		_load_vault_from_profile()
		selected_arch_id = str(_profile.get("selected_build_id", selected_arch_id))
		var def_char := Config.get_character_for_archetype(selected_arch_id)
		if selected_char_id.is_empty():
			selected_char_id = str(def_char.get("id", "CHAR_GUILLOTINE"))
		_rebuild_saved_deck_selector()
		_push_deck_update()
		_persist_ui_prefs()
		_show_toast("Build preset applied!", false)


func _apply_core_build_preset(build_id: String) -> void:
	_active_saved_deck_id = ""
	selected_arch_id = build_id
	_profile["selected_build_id"] = build_id
	var arch := Config.get_archetype(build_id)
	var def_char := Config.get_character_for_archetype(build_id)
	_select_character(str(def_char.get("id", "CHAR_GUILLOTINE")))
	equipped_sword_id = str(arch.get("sword_skin", equipped_sword_id))
	_save_vault_to_profile()
	_rebuild_saved_deck_selector()
	_push_deck_update()
	_persist_ui_prefs()


func _open_deck_builder_modal() -> void:
	open_deck_builder_requested.emit()
	if is_instance_valid(_deck_builder_modal):
		_deck_builder_modal.queue_free()
		_deck_builder_modal = null

	_deck_builder_modal = PanelContainer.new()
	_deck_builder_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_builder_modal.anchor_left = 0.04; _deck_builder_modal.anchor_right = 0.96
	_deck_builder_modal.anchor_top = 0.04; _deck_builder_modal.anchor_bottom = 0.96
	_deck_builder_modal.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.05, 0.038, 0.028, 0.98), Color(0.92, 0.72, 0.28, 0.96), 3, 14, 14))
	add_child(_deck_builder_modal)

	var modal_vb := VBoxContainer.new()
	modal_vb.add_theme_constant_override("separation", 8)
	_deck_builder_modal.add_child(modal_vb)

	var m_hdr := HBoxContainer.new()
	m_hdr.add_theme_constant_override("separation", 10)
	modal_vb.add_child(m_hdr)
	var m_title := Icons.make_icon_label_row("cards", "DECK BUILDER (CAMPAIGN & MULTIPLAYER)", 18, 16, Color(1.0, 0.88, 0.46))
	m_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in m_title.get_children():
		if child is Label:
			_apply_font(child, true)
	m_hdr.add_child(m_title)

	var done_btn := Button.new()
	done_btn.text = "Save & Close"
	Icons.apply_button_icon(done_btn, "check", 15)
	done_btn.custom_minimum_size = Vector2(138, 34)
	_style_tavern_btn(done_btn, Color(0.16, 0.26, 0.14, 0.96), Color(0.56, 0.90, 0.46, 0.94), true, 8)
	done_btn.pressed.connect(func():
		play_click_sfx.emit()
		_close_deck_builder_modal()
	)
	m_hdr.add_child(done_btn)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_vb.add_child(sc)

	var db_panel := DeckBuilderScript.new()
	db_panel.sfx_requested.connect(func(_sn: String): play_click_sfx.emit())
	db_panel.deck_changed.connect(func(updated_prof: Dictionary):
		_profile = updated_prof
		Catalog.save_profile(_profile)
		_load_vault_from_profile()
		selected_arch_id = str(_profile.get("selected_build_id", selected_arch_id))
		_rebuild_saved_deck_selector()
		_push_deck_update()
	)
	sc.add_child(db_panel)
	db_panel.setup_builder(_profile, _lang)


func _close_deck_builder_modal() -> void:
	if is_instance_valid(_deck_builder_modal):
		_deck_builder_modal.queue_free()
		_deck_builder_modal = null
	_load_vault_from_profile()
	_rebuild_saved_deck_selector()
	_push_deck_update()


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
	frame.custom_minimum_size = Vector2(104, 104)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_sb := _make_tavern_panel_sb(Color(0.04, 0.032, 0.026, 0.90), Color(ch_accent.r, ch_accent.g, ch_accent.b, 0.55), 1, 8, 2)
	frame.add_theme_stylebox_override("panel", frame_sb)
	cc.add_child(frame)

	if DisplayServer.get_name() != "headless":
		var bust := _load_char_bust_glb(str(ch.get("glb", "")))
		if bust != null:
			var svp := SubViewport.new()
			svp.size = Vector2i(256, 256)
			svp.msaa_3d = Viewport.MSAA_4X
			svp.own_world_3d = true
			svp.transparent_bg = true
			svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			frame.add_child(svp)

			var tr := TextureRect.new()
			tr.custom_minimum_size = Vector2(100, 100)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = svp.get_texture()
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(tr)

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
			cam.look_at_from_position(Vector3(0.0, 0.56, 1.50), Vector3(0.0, 0.48, 0.0), Vector3.UP)
			svp.add_child(cam)

			var pivot := Node3D.new()
			pivot.add_child(bust)
			svp.add_child(pivot)
			_char_portrait_pivots.append({"node": pivot, "phase": float(idx) * 1.35})
			return cc

	var fb_center := CenterContainer.new()
	fb_center.custom_minimum_size = Vector2(100, 100)
	fb_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(fb_center)
	if back_tex != null:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(60, 60)
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
		glyph_lbl.add_theme_font_size_override("font_size", 28)
		glyph_lbl.add_theme_color_override("font_color", ch_accent)
		glyph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fb_center.add_child(glyph_lbl)
	return cc


func _switch_tab(idx: int) -> void:
	_active_tab = idx
	if idx == 1:
		_refresh_leaderboard()
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
	if is_instance_valid(_hdr_bar):
		_hdr_bar.modulate.a = 0.0
		tw.tween_property(_hdr_bar, "modulate:a", 1.0, 0.34).set_delay(0.06)


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


func _resolve_default_player_name() -> String:
	if Engine.has_singleton("Steam"):
		var steam_obj: Object = Engine.get_singleton("Steam")
		if steam_obj != null and steam_obj.has_method("getPersonaName"):
			var persona := str(steam_obj.getPersonaName()).strip_edges()
			if not persona.is_empty():
				return persona
	return TESTER_FALLBACK_NAMES[randi() % TESTER_FALLBACK_NAMES.size()]


func _apply_saved_prefs() -> void:
	var saved_name := str(_prefs.get("player_name", "")).strip_edges()
	if is_instance_valid(name_edit):
		if saved_name.is_empty() or saved_name.begins_with("Duelist_"):
			name_edit.text = _resolve_default_player_name()
		else:
			name_edit.text = saved_name
	var saved_ip := str(_prefs.get("last_ip", "")).strip_edges()
	if not saved_ip.is_empty() and is_instance_valid(ip_edit):
		ip_edit.text = saved_ip
	var saved_port := int(_prefs.get("last_port", Config.DEFAULT_PORT))
	if saved_port >= 1024 and is_instance_valid(port_edit):
		port_edit.text = str(saved_port)
	var saved_mode := str(_prefs.get("last_mode", Config.MODE_UNRANKED))
	if not _mode_cards.has(saved_mode):
		saved_mode = Config.MODE_UNRANKED
	_select_match_mode(saved_mode)
	_active_saved_deck_id = str(_prefs.get("last_saved_deck_id", ""))
	var saved_arch := str(_prefs.get("last_archetype_id", str(_profile.get("selected_build_id", "GUILLOTINE_ACES"))))
	selected_arch_id = saved_arch
	var saved_char := str(_prefs.get("last_character_id", ""))
	if not saved_char.is_empty() and char_buttons.has(saved_char):
		_select_character(saved_char)
	_selected_vista_era = str(_prefs.get("last_vista_era", "stredovek"))
	_update_vista_btn_label()
	_rebuild_saved_deck_selector()
	_push_deck_update()


func _persist_ui_prefs() -> void:
	History.save_prefs({
		"player_name": name_edit.text.strip_edges() if is_instance_valid(name_edit) else "",
		"last_ip": ip_edit.text.strip_edges() if is_instance_valid(ip_edit) else "127.0.0.1",
		"last_port": maxi(1024, port_edit.text.to_int()) if is_instance_valid(port_edit) else Config.DEFAULT_PORT,
		"last_character_id": selected_char_id,
		"last_archetype_id": selected_arch_id,
		"last_vista_era": _selected_vista_era,
		"last_mode": _selected_match_mode,
		"last_saved_deck_id": _active_saved_deck_id,
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
			Icons.apply_button_icon(vista_btn, str(ve.get("icon", "tavern")), 15)
			return


func _refresh_leaderboard() -> void:
	if not is_instance_valid(_leaderboard_vb):
		return
	for c in _leaderboard_vb.get_children():
		c.queue_free()

	var stats := History.get_player_stats()
	var elo := int(stats.get("elo", 1000))
	var tier := History.get_rank_tier(elo)
	var tier_col: Color = tier.get("col", Color(0.95, 0.78, 0.30))
	var entries := History.get_leaderboard_entries()

	if is_instance_valid(_leaderboard_tab_btn):
		var rival_cnt := maxi(0, entries.size() - 1)
		_leaderboard_tab_btn.text = ("Leaderboard (%d)" % rival_cnt) if rival_cnt > 0 else "Leaderboard & Rivals"

	# 1. Local Player Summary Card
	var hero_pan := PanelContainer.new()
	hero_pan.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.12, 0.085, 0.055, 0.96), Color(tier_col.r, tier_col.g, tier_col.b, 0.90), 2, 11, 12))
	_leaderboard_vb.add_child(hero_pan)

	var hero_hb := HBoxContainer.new()
	hero_hb.add_theme_constant_override("separation", 12)
	hero_pan.add_child(hero_hb)
	hero_hb.add_child(Icons.make_icon_rect(str(tier.get("icon", "trophy")), 32, tier_col))

	var hero_txt := VBoxContainer.new()
	hero_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_txt.add_theme_constant_override("separation", 2)
	hero_hb.add_child(hero_txt)

	var p_name := name_edit.text.strip_edges() if is_instance_valid(name_edit) and not name_edit.text.strip_edges().is_empty() else str(stats.get("player_name", "Duelist"))
	if p_name.is_empty():
		p_name = "Duelist"
	var h_title := Label.new()
	h_title.text = "%s  •  %s (%d ELO)" % [p_name, str(tier.get("name", "Silver")), elo]
	_apply_font(h_title, true)
	h_title.add_theme_font_size_override("font_size", 15)
	h_title.add_theme_color_override("font_color", tier_col)
	hero_txt.add_child(h_title)

	var h_sub := Label.new()
	h_sub.text = "Record: %dW - %dL (%d%% WR)  •  Best Slam: %d  •  Streak: %d" % [
		int(stats.get("wins", 0)),
		int(stats.get("losses", 0)),
		int(stats.get("winrate", 0)),
		int(stats.get("best_slam", 0)),
		int(stats.get("streak", 0)),
	]
	_apply_font(h_sub, false)
	h_sub.add_theme_font_size_override("font_size", 12)
	h_sub.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	hero_txt.add_child(h_sub)

	# 2. Leaderboard Table Header
	var tbl_hdr := HBoxContainer.new()
	tbl_hdr.add_theme_constant_override("separation", 8)
	_leaderboard_vb.add_child(tbl_hdr)
	var lb_lbl := Icons.make_icon_label_row("trophy", "LOCAL & RIVAL STANDINGS", 15, 13, Color(1.0, 0.86, 0.44))
	lb_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in lb_lbl.get_children():
		if child is Label:
			_apply_font(child, true)
	tbl_hdr.add_child(lb_lbl)

	# 3. Leaderboard Rows
	var rank_idx := 0
	for raw_e in entries:
		if not (raw_e is Dictionary):
			continue
		rank_idx += 1
		var e := raw_e as Dictionary
		var is_local := bool(e.get("is_local", false))
		var e_elo := int(e.get("elo", 1000))
		var e_tier := History.get_rank_tier(e_elo)
		var e_col: Color = e_tier.get("col", Color(0.90, 0.82, 0.68))
		var e_name := p_name if is_local else str(e.get("name", "Rival"))

		var row_pan := PanelContainer.new()
		var bg := Color(0.14, 0.11, 0.065, 0.96) if is_local else Color(0.09, 0.07, 0.05, 0.92)
		var bd := Color(0.98, 0.80, 0.30, 0.92) if is_local else Color(0.56, 0.42, 0.24, 0.68)
		row_pan.add_theme_stylebox_override("panel", _make_tavern_panel_sb(bg, bd, 2 if is_local else 1, 9, 9))
		_leaderboard_vb.add_child(row_pan)

		var row_hb := HBoxContainer.new()
		row_hb.add_theme_constant_override("separation", 10)
		row_pan.add_child(row_hb)

		var r_num := Label.new()
		r_num.text = "#%d" % rank_idx
		r_num.custom_minimum_size = Vector2(28, 0)
		_apply_font(r_num, true)
		r_num.add_theme_font_size_override("font_size", 14)
		r_num.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44) if rank_idx == 1 else Color(0.76, 0.70, 0.60))
		row_hb.add_child(r_num)

		row_hb.add_child(Icons.make_icon_rect(str(e_tier.get("icon", "shield")), 18, e_col))

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.add_theme_constant_override("separation", 2)
		row_hb.add_child(info_vb)

		var top_l := Label.new()
		var tag := " (YOU)" if is_local else ""
		top_l.text = "%s%s  •  %d ELO  •  %dW-%dL (%d%%)" % [
			e_name,
			tag,
			e_elo,
			int(e.get("wins", 0)),
			int(e.get("losses", 0)),
			int(e.get("winrate", 0)),
		]
		_apply_font(top_l, true)
		top_l.add_theme_font_size_override("font_size", 13)
		top_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62) if is_local else Color(0.95, 0.88, 0.74))
		info_vb.add_child(top_l)

		var sub_l := Label.new()
		var char_name := str(Config.get_character(str(e.get("character_id", "CHAR_GUILLOTINE"))).get("name", "Duelist"))
		var slam_v := int(e.get("best_slam", 0))
		if is_local:
			sub_l.text = "Best Slam: %d  •  Duelist: %s" % [slam_v, char_name]
		else:
			var r_ip := str(e.get("ip", "")).strip_edges()
			var r_port := int(e.get("port", Config.DEFAULT_PORT))
			var addr_txt := ("%s:%d" % [r_ip, r_port]) if not r_ip.is_empty() else "Joined your table"
			sub_l.text = "Best Slam: %d  •  %s  •  %s" % [slam_v, char_name, addr_txt]
		_apply_font(sub_l, false)
		sub_l.add_theme_font_size_override("font_size", 11)
		sub_l.add_theme_color_override("font_color", Color(0.74, 0.70, 0.62))
		info_vb.add_child(sub_l)

		if not is_local:
			var r_ip := str(e.get("ip", "")).strip_edges()
			var r_port := int(e.get("port", Config.DEFAULT_PORT))
			var rem_btn := Button.new()
			rem_btn.text = "Rematch" if not r_ip.is_empty() else "Host"
			Icons.apply_button_icon(rem_btn, "sword" if not r_ip.is_empty() else "fire", 13)
			rem_btn.custom_minimum_size = Vector2(104, 30)
			_style_tavern_btn(rem_btn, Color(0.20, 0.28, 0.14, 0.96), Color(0.62, 0.92, 0.46, 0.92), true, 7)
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
						_show_toast("Table hosted! Share IP copied for rematch with %s!" % e_name, false)
			)
			row_hb.add_child(rem_btn)

			if not r_ip.is_empty():
				var cbtn := Button.new()
				cbtn.text = ""
				Icons.apply_button_icon(cbtn, "scroll", 13)
				cbtn.tooltip_text = "Copy %s:%d" % [r_ip, r_port]
				cbtn.custom_minimum_size = Vector2(32, 30)
				_style_tavern_btn(cbtn, Color(0.14, 0.18, 0.16, 0.94), Color(0.52, 0.76, 0.62, 0.85), false, 7)
				cbtn.pressed.connect(func():
					play_click_sfx.emit()
					_copy_and_toast("%s:%d" % [r_ip, r_port], e_name)
				)
				row_hb.add_child(cbtn)

			var del_btn := Button.new()
			del_btn.text = ""
			Icons.apply_button_icon(del_btn, "cross", 12)
			del_btn.tooltip_text = "Remove from rivals"
			del_btn.custom_minimum_size = Vector2(30, 30)
			_style_tavern_btn(del_btn, Color(0.22, 0.10, 0.09, 0.92), Color(0.72, 0.34, 0.28, 0.80), false, 7)
			del_btn.pressed.connect(func():
				play_click_sfx.emit()
				History.remove_opponent(e_name, r_ip)
				_refresh_leaderboard()
			)
			row_hb.add_child(del_btn)

	if entries.size() <= 1:
		var emp := PanelContainer.new()
		emp.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.07, 0.055, 0.04, 0.85), Color(0.45, 0.36, 0.22, 0.50), 1, 10, 14))
		_leaderboard_vb.add_child(emp)
		var elbl := Label.new()
		elbl.text = "No rivals recorded yet.\nFinish a multiplayer match to climb the ELO rankings and log rivals for 1-click Quick Rematch."
		elbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_font(elbl, false)
		elbl.add_theme_font_size_override("font_size", 12)
		elbl.add_theme_color_override("font_color", Color(0.76, 0.70, 0.60))
		emp.add_child(elbl)


func _build_local_deck_cfg(arch_id: String) -> Dictionary:
	var b_combo: Array = _profile.get("bankai_combo", Catalog.get_deck_build(arch_id).get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]))
	var arch := Config.get_archetype(arch_id)
	return {
		"archetype_id": arch_id,
		"extra_aces": int(arch.get("extra_aces", 2)),
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
	selected_arch_id = str(_profile.get("selected_build_id", selected_arch_id))
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


func _select_character(char_id: String) -> void:
	selected_char_id = char_id
	for k in char_buttons.keys():
		var cid_k := str(k)
		var is_sel := (cid_k == char_id)
		char_buttons[k].set_pressed_no_signal(is_sel)
		var ch_info := Config.get_character(cid_k)
		_apply_choice_btn_style(char_buttons[k], is_sel, ch_info.get("col", Color(0.95, 0.78, 0.30)))
	_push_deck_update()


func _push_deck_update() -> void:
	if mp_net != null:
		mp_net.local_deck_cfg = _build_local_deck_cfg(selected_arch_id)
		mp_net.update_local_deck(mp_net.local_deck_cfg)
	_update_deck_summary(Config.get_archetype(selected_arch_id))


func _update_deck_summary(arch: Dictionary) -> void:
	if not is_instance_valid(_build_summary_title):
		return
	var b_loc := Catalog.get_deck_build_loc(selected_arch_id, _lang)
	var b_name := str(b_loc.get("name", arch.get("name", selected_arch_id)))
	var sw_name := str(Catalog.get_sword_skin_loc(equipped_sword_id, _lang).get("name", equipped_sword_id))
	_build_summary_title.text = "Active Build: %s  •  Sword: %s" % [b_name, sw_name]

	var seal_title := "Velká Pečeť" if _lang == "cs" else "Grand Seal"
	var combo_arr: Array = _profile.get("bankai_combo", Catalog.get_deck_build(selected_arch_id).get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]))
	var combo_str := ", ".join(combo_arr) if not combo_arr.is_empty() else "Default"
	if is_instance_valid(_grand_seal_lbl):
		_grand_seal_lbl.text = "%s: %s" % [seal_title, combo_str]

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
	if is_instance_valid(_build_summary_lbl):
		_build_summary_lbl.text = "Powers: %s  |  Table Relics: %s  |  Passives: %s" % [pnames, tnames, rnames]


func _on_play_match_pressed() -> void:
	play_click_sfx.emit()
	_persist_ui_prefs()
	if mp_net == null or bool(mp_net.get("in_session")):
		return
	var port := maxi(1024, int(port_edit.text.to_int())) if is_instance_valid(port_edit) else Config.DEFAULT_PORT
	var target_ip := ip_edit.text.strip_edges() if is_instance_valid(ip_edit) else "127.0.0.1"
	mp_net.room_settings["vista_era"] = _selected_vista_era
	mp_net.room_settings["match_mode"] = _selected_match_mode
	if _selected_match_mode == Config.MODE_RANKED:
		mp_net.room_settings["rule_mode"] = Config.RULE_BALANCED_ARENA
	if not target_ip.is_empty() and target_ip != "127.0.0.1" and target_ip != "localhost":
		mp_net.join_room(target_ip, port, name_edit.text, mp_net.local_deck_cfg)
		_local_ready = false
		_on_status_changed("Searching & joining %s:%d..." % [target_ip, port], false)
	else:
		var err: int = int(mp_net.host_room(port, name_edit.text, mp_net.local_deck_cfg))
		if err == OK:
			_local_ready = true
		else:
			mp_net.join_room("127.0.0.1", port, name_edit.text, mp_net.local_deck_cfg)
			_local_ready = false
			_on_status_changed("Found active local table — joining...", false)
	_refresh_controls()


func _on_private_join_pressed() -> void:
	play_click_sfx.emit()
	_persist_ui_prefs()
	if mp_net == null:
		return
	var rc := room_code_edit.text.strip_edges().to_upper() if is_instance_valid(room_code_edit) else ""
	if rc.is_empty():
		_on_status_changed("Enter a Room Code to join a Private Match, or click CREATE ROOM.", true)
		return
	mp_net.room_settings["room_code"] = rc
	var port := maxi(1024, int(port_edit.text.to_int())) if is_instance_valid(port_edit) else Config.DEFAULT_PORT
	var target_ip := ip_edit.text.strip_edges() if is_instance_valid(ip_edit) else "127.0.0.1"
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
	mp_net.join_room(target_ip, port, name_edit.text, mp_net.local_deck_cfg)
	_local_ready = false
	_on_status_changed("Joining Private Room [%s]..." % rc, false)
	_refresh_controls()


func _on_host_pressed() -> void:
	play_click_sfx.emit()
	_persist_ui_prefs()
	if mp_net == null:
		return
	var port := maxi(1024, int(port_edit.text.to_int()))
	mp_net.room_settings["vista_era"] = _selected_vista_era
	mp_net.room_settings["match_mode"] = _selected_match_mode
	if _selected_match_mode == Config.MODE_RANKED:
		mp_net.room_settings["rule_mode"] = Config.RULE_BALANCED_ARENA
	elif _selected_match_mode == Config.MODE_PRIVATE:
		var rc := room_code_edit.text.strip_edges().to_upper() if is_instance_valid(room_code_edit) else ""
		if rc.is_empty():
			rc = mp_net.generate_room_code() if mp_net.has_method("generate_room_code") else "TAVERN"
			if is_instance_valid(room_code_edit):
				room_code_edit.text = rc
		mp_net.room_settings["room_code"] = rc
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
	return "Sword: %s  |  Powers: %s  |  Table: %s  |  Passives: %s" % [sw_name, p_str, t_str, r_str]


func _on_lobby_updated(seats: Array, settings: Dictionary) -> void:
	_render_4_seats(seats, settings)
	if settings.has("vista_era"):
		_selected_vista_era = str(settings["vista_era"])
		_update_vista_btn_label()
	if settings.has("match_mode"):
		var mm := str(settings["match_mode"])
		if mm != _selected_match_mode and _mode_cards.has(mm):
			_selected_match_mode = mm
			for k in _mode_cards.keys():
				_mode_cards[k].set_pressed_no_signal(str(k) == mm)
	var rm := str(settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	if rm == Config.RULE_BALANCED_ARENA:
		rule_btn.text = "Ruleset: Balanced Arena (Fair Preset)"
		Icons.apply_button_icon(rule_btn, "trophy", 15)
	else:
		rule_btn.text = "Ruleset: Campaign Vault (Unlocked)"
		Icons.apply_button_icon(rule_btn, "shield", 15)
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
			row.add_child(Icons.make_icon_rect("check" if is_rdy else "hourglass", 16, Color(0.46, 0.94, 0.56) if is_rdy else Color(0.95, 0.78, 0.34)))
			var lbl := Label.new()
			var kind := "HOST" if si == 0 else ("BOT" if bool(s["is_bot"]) else "PLAYER")
			var rdy := "READY" if is_rdy else "WAIT"
			lbl.text = "Seat %d [%s]: %s  •  %s (%d Aces)  •  %s" % [si + 1, kind, str(s["name"]), str(arch["name"]), aces, rdy]
			_apply_font(lbl, false)
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.76) if is_rdy else Color(0.80, 0.74, 0.64))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)

			if mp_net != null and mp_net.is_host and si > 0:
				var kick := Button.new(); kick.text = "Kick"
				Icons.apply_button_icon(kick, "cross", 12)
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
			var emp_row := Icons.make_icon_label_row("tavern", "Seat %d — Empty Chair (Invite a friend or +Add Bot)" % (slot_i + 1), 15, 12, Color(0.56, 0.52, 0.44, 0.78))
			for child in emp_row.get_children():
				if child is Label:
					_apply_font(child, false)
			empty_slot.add_child(emp_row)
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

	var rc := str(mp_net.room_settings.get("room_code", "")) if mp_net != null else ""
	if not rc.is_empty():
		_room_code_str = rc
		share_code_lbl.text = "Code: %s" % rc
		share_code_lbl.visible = true
		copy_code_btn.visible = true
	else:
		_room_code_str = ""
		share_code_lbl.visible = false
		copy_code_btn.visible = false

	if not vpn_ip.is_empty():
		_vpn_copy_str = "%s:%d" % [vpn_ip, port]
		share_vpn_lbl.text = "VPN: %s" % _vpn_copy_str
		share_vpn_lbl.visible = true
		copy_vpn_btn.visible = true
	else:
		_vpn_copy_str = ""
		share_vpn_lbl.visible = false
		copy_vpn_btn.visible = false

	_lan_copy_str = "%s:%d" % [lan_ip, port]
	share_lan_lbl.text = "LAN: %s" % _lan_copy_str

	if upnp_ok and not pub_ip.is_empty():
		_pub_copy_str = "%s:%d" % [pub_ip, port]
		share_pub_lbl.text = "Public: %s" % _pub_copy_str
		copy_pub_btn.visible = true
	elif upnp_pending:
		_pub_copy_str = ""
		share_pub_lbl.text = "UPnP: Checking..."
		copy_pub_btn.visible = false
	else:
		_pub_copy_str = ""
		share_pub_lbl.text = "UPnP off (Use Radmin/Tailscale)" if not vpn_ip.is_empty() else ("No UPnP (Forward UDP %d or Radmin/Tailscale)" % port)
		copy_pub_btn.visible = false


func _refresh_controls() -> void:
	var in_s: bool = (mp_net != null and bool(mp_net.get("in_session")))
	var is_h: bool = (mp_net != null and bool(mp_net.get("is_host")))
	var show_room: bool = _in_match_room or in_s
	if is_instance_valid(_mode_tabs_hb):
		_mode_tabs_hb.visible = not show_room
	if is_instance_valid(_room_banner_pan):
		_room_banner_pan.visible = show_room
		if show_room and is_instance_valid(_room_banner_lbl):
			var mode_titles := {
				Config.MODE_PUBLIC: "PUBLIC MATCH ROOM  •  Your Deck & Live Table",
				Config.MODE_PRIVATE: "PRIVATE MATCH ROOM  •  Invite Friends via Room Code",
				Config.MODE_RANKED: "RANKED ARENA ROOM  •  ELO Balanced Matchmaking",
				Config.MODE_UNRANKED: "UNRANKED MATCH ROOM  •  Casual Tavern Table",
			}
			_room_banner_lbl.text = str(mode_titles.get(_selected_match_mode, "MATCH ROOM"))
	if is_instance_valid(_tab_bar_hb):
		_tab_bar_hb.visible = not show_room
	if show_room and _active_tab != 0:
		_switch_tab(0)
	if is_instance_valid(_duelist_section_hdr):
		_duelist_section_hdr.visible = not show_room
	if is_instance_valid(_duelist_section_row):
		_duelist_section_row.visible = not show_room
	if is_instance_valid(_left_col_vb) and is_instance_valid(_right_col_vb):
		_left_col_vb.size_flags_stretch_ratio = 0.72 if show_room else 1.22
		_right_col_vb.size_flags_stretch_ratio = 1.28 if show_room else 0.90
	if is_instance_valid(_conn_dot_lbl):
		if not in_s:
			_conn_dot_lbl.text = "Offline"
			_conn_dot_lbl.add_theme_color_override("font_color", Color(0.74, 0.70, 0.64))
			if is_instance_valid(_conn_dot_icon):
				_conn_dot_icon.modulate = Color(0.74, 0.70, 0.64)
		elif is_h:
			_conn_dot_lbl.text = "Hosting Table"
			_conn_dot_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.62))
			if is_instance_valid(_conn_dot_icon):
				_conn_dot_icon.modulate = Color(0.45, 0.96, 0.62)
		else:
			_conn_dot_lbl.text = "Connected"
			_conn_dot_lbl.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
			if is_instance_valid(_conn_dot_icon):
				_conn_dot_icon.modulate = Color(0.48, 0.88, 1.0)

	host_btn.disabled = in_s
	join_btn.disabled = in_s
	if is_instance_valid(play_match_btn):
		play_match_btn.visible = (_selected_match_mode != Config.MODE_PRIVATE)
		play_match_btn.disabled = in_s
	if is_instance_valid(room_code_box):
		room_code_box.visible = (_selected_match_mode == Config.MODE_PRIVATE)
	if is_instance_valid(private_create_btn):
		private_create_btn.disabled = in_s
	if is_instance_valid(private_join_btn):
		private_join_btn.disabled = in_s
	for k in _mode_cards.keys():
		var mbtn: Button = _mode_cards[k]
		if is_instance_valid(mbtn):
			mbtn.disabled = in_s and not is_h
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
	ready_btn.text = "Cancel Ready" if _local_ready else "READY UP"
	Icons.apply_button_icon(ready_btn, "cross" if _local_ready else "check", 16)
	start_btn.visible = in_s and is_h
	if in_s and is_h:
		var chk: Dictionary = mp_net.can_start_match()
		start_btn.disabled = not bool(chk["ok"])
		start_btn.tooltip_text = str(chk["reason"])
