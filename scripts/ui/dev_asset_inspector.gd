class_name DevAssetInspector
extends Control

## LIALO Lobby Dev / QA Asset & Animation Inspector (F9 / DEV button)
## Dark tavern woodcut style, LialoDisplay + LialoBody fonts, LialoIcons, zero Unicode emojis.
## Headless-safe: disables 3D SubViewport updates & audio playback when DisplayServer == "headless".

signal closed()

const Catalog = preload("res://scripts/lialo_catalog.gd")
const Toon = preload("res://scripts/toon_style.gd")
const LialoIcons = preload("res://scripts/ui/lialo_icons.gd")
const FxLib = preload("res://scripts/fx_lib.gd")
const CinematicProfiles = preload("res://scripts/cinematic_profiles.gd")
const BankaiFxScript = preload("res://scripts/battle/bankai_fx.gd")
const SnakeLoadingScript = preload("res://scripts/ui/snake_loading_screen.gd")
const PowerCardShowcaseScript = preload("res://scripts/battle/power_card_vfx_showcase.gd")
const FujiraIntroScript = preload("res://scripts/ui/fujira_studio_intro.gd")
const StoryDataScript = preload("res://scripts/campaign/campaign_story_data.gd")
const ComicPlayerScript = preload("res://scripts/ui/comic_cutscene_player.gd")

const RELIC_MESH_FACTORY_PATH := "res://scripts/relic_mesh_factory.gd"
const BLENDER_VFX_PATHS := [
	"res://assets/models/vfx/scoring_astrolabe_stage.glb",
	"res://assets/models/vfx/scoring_tokens_pack.glb",
	"res://assets/models/vfx/card_anim_seven_barrage.glb",
	"res://assets/models/vfx/card_anim_ace_chronos.glb",
	"res://assets/models/vfx/card_anim_royal_crown.glb",
	"res://assets/models/vfx/card_anim_arcane_conduit.glb",
	"res://assets/models/vfx/hellfire_phial_hero.glb",
	"res://assets/models/vfx/hellfire_explosion_anim.glb",
	"res://assets/models/vfx/hellfire_burn_crown.glb",
	"res://assets/models/vfx/defeat_execution_anim.glb",
]

const SWORD_ANIM_PATH := "res://scripts/sword_card_animator.gd"
const FONT_DISP_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoBody.ttf"

const CAT_ALL := "All"
const CAT_ANIM := "Animations & VFX"
const CAT_3D := "3D Models"
const CAT_2D := "2D & UI"
const CAT_AUDIO := "Audio & BGM"
const CATEGORIES := [CAT_ALL, CAT_ANIM, CAT_3D, CAT_2D, CAT_AUDIO]
const SPEED_PRESETS := [0.25, 0.5, 1.0, 1.5, 2.0]

var _is_headless := false
var _font_disp: Font
var _font_body: Font

var _all_items: Array[Dictionary] = []
var _filtered_items: Array[Dictionary] = []
var _active_cat: String = CAT_ALL
var _search_query: String = ""
var _selected_idx: int = -1

var _cat_btns: Dictionary = {}
var _search_edit: LineEdit
var _list_vb: VBoxContainer
var _item_btns: Array[Button] = []

var _stage_title_lbl: Label
var _stage_status_lbl: Label
var _stage_meta_lbl: Label
var _play_btn: Button
var _replay_btn: Button
var _loop_btn: Button
var _speed_btn: Button
var _next_btn: Button
var _zoom_1_1_btn: Button

var _loop_enabled := true
var _speed_idx := 2 # 1.0x
var _speed_scale := 1.0
var _zoom_1_1 := false
var _is_playing := true

# Preview Stages
var _stage_stack: Control
var _stage_3d_wrap: PanelContainer
var _vp_container: SubViewportContainer
var _vp: SubViewport
var _cam_3d: Camera3D
var _pivot_3d: Node3D
var _fx_root_3d: Node3D
var _dragging_3d := false
var _last_mouse_3d := Vector2.ZERO
var _rot_yaw := 0.45
var _rot_pitch := -0.22
var _zoom_dist := 1.85
var _auto_spin_3d := true

var _stage_2d_wrap: ScrollContainer
var _stage_2d_center: CenterContainer
var _tex_rect_2d: TextureRect
var _fujira_intro_node: Control

var _stage_anim_2d: Control
var _anim_2d_t := 0.0
var _anim_2d_kind := ""
var _anim_2d_mult := 1
var _anim_2d_label := ""
var _anim_2d_col := Color(1.0, 0.84, 0.34)

var _stage_audio_wrap: VBoxContainer
var _audio_info_lbl: Label
var _bgm_intensity_slider: HSlider
var _bgm_intensity_lbl: Label
var _amb_tavern_chk: CheckButton
var _audio_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0
var _bgm_calm_player: AudioStreamPlayer
var _bgm_epic_player: AudioStreamPlayer
var _bgm_climax_player: AudioStreamPlayer
var _bgm_amb_player: AudioStreamPlayer
var _bgm_mix_active := false
var _bgm_intensity := 0.0

var _bankai_fx: BankaiFxScript = null
var _snake_screen: CanvasLayer = null
var _loop_timer := 0.0
var _active_anim_player: AnimationPlayer = null

var _stage_fpv_wrap: PanelContainer
var _fpv_vp_container: SubViewportContainer
var _fpv_vp: SubViewport
var _fpv_cam: Camera3D
var _fpv_overlay: Control
var _fpv_showcase: PowerCardShowcaseScript = null
var _comic_preview_node: ComicPlayerScript = null


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 98

	_font_disp = load(FONT_DISP_PATH) as Font if ResourceLoader.exists(FONT_DISP_PATH) else ThemeDB.fallback_font
	_font_body = load(FONT_BODY_PATH) as Font if ResourceLoader.exists(FONT_BODY_PATH) else ThemeDB.fallback_font

	_build_ui()
	_build_audio_players()
	_catalog_all_items()
	_apply_filter()


func _exit_tree() -> void:
	_stop_all_previews()


func open_inspector() -> void:
	visible = true
	if _all_items.is_empty():
		_catalog_all_items()
		_apply_filter()
	if _selected_idx < 0 and not _filtered_items.is_empty():
		_select_item(0)


func close_inspector() -> void:
	if not visible:
		return
	_stop_all_previews()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_F9:
			close_inspector()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := delta * _speed_scale
	if _stage_3d_wrap.visible and _pivot_3d != null:
		if _auto_spin_3d and not _dragging_3d and _is_playing:
			_rot_yaw += dt * 0.45
		_pivot_3d.rotation = Vector3(_rot_pitch, _rot_yaw, 0.0)
		if _cam_3d != null:
			_cam_3d.position.z = lerpf(_cam_3d.position.z, _zoom_dist, minf(1.0, delta * 12.0))
		if _is_playing and _loop_enabled and _selected_idx >= 0 and _selected_idx < _filtered_items.size():
			var item := _filtered_items[_selected_idx]
			var kind := str(item.get("kind", ""))
			if kind in ["fx_lib", "sword_anim", "cinematic"]:
				_loop_timer += dt
				if _loop_timer >= 2.8:
					_loop_timer = 0.0
					_trigger_selected_preview()

	if _stage_anim_2d.visible and _is_playing:
		_anim_2d_t += dt
		if _loop_enabled and _anim_2d_t >= 2.6:
			_anim_2d_t = 0.0
		_stage_anim_2d.queue_redraw()


func _make_box(bg: Color, border: Color, bw: int = 2, rad: int = 8, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.set_content_margin_all(pad)
	return sb


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.016, 0.014, 0.90)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.048, 0.04, 0.98), Color(0.76, 0.60, 0.28, 0.92), 2, 12, 16))
	margin.add_child(frame)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	frame.add_child(root_vb)

	# Top Header Bar
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_vb.add_child(hdr)

	var hdr_icon := LialoIcons.make_icon_rect("gear", 22, Color(0.98, 0.82, 0.38))
	hdr.add_child(hdr_icon)

	var hdr_title := Label.new()
	hdr_title.text = "DEV / QA ASSET & ANIMATION INSPECTOR"
	hdr_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_title.add_theme_font_override("font", _font_disp)
	hdr_title.add_theme_font_size_override("font_size", 22)
	hdr_title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.66))
	hdr.add_child(hdr_title)

	var close_btn := Button.new()
	close_btn.text = "Close [F9 / ESC]"
	close_btn.custom_minimum_size = Vector2(150, 34)
	close_btn.add_theme_font_override("font", _font_body)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_stylebox_override("normal", _make_box(Color(0.22, 0.08, 0.08), Color(0.76, 0.34, 0.30), 2, 6, 6))
	LialoIcons.apply_button_icon(close_btn, "cross", 14)
	close_btn.pressed.connect(close_inspector)
	hdr.add_child(close_btn)

	# Main Split: Left Browser + Right Preview Stage
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root_vb.add_child(split)

	# LEFT PANEL
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(390, 0)
	left_panel.add_theme_stylebox_override("panel", _make_box(Color(0.045, 0.036, 0.030, 0.98), Color(0.42, 0.33, 0.18, 0.85), 1, 8, 10))
	split.add_child(left_panel)

	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vb)

	# Category filter tabs
	var cat_flow := HFlowContainer.new()
	cat_flow.add_theme_constant_override("h_separation", 6)
	cat_flow.add_theme_constant_override("v_separation", 6)
	left_vb.add_child(cat_flow)

	for cat_v in CATEGORIES:
		var cat := str(cat_v)
		var cb := Button.new()
		cb.text = cat
		cb.add_theme_font_override("font", _font_body)
		cb.add_theme_font_size_override("font_size", 12)
		var cat_cap: String = cat
		cb.pressed.connect(func():
			_active_cat = cat_cap
			_update_cat_buttons()
			_apply_filter()
		)
		cat_flow.add_child(cb)
		_cat_btns[cat] = cb
	_update_cat_buttons()

	# Search Box
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search assets, animations, relics, audio..."
	_search_edit.clear_button_enabled = true
	_search_edit.add_theme_font_override("font", _font_body)
	_search_edit.add_theme_font_size_override("font_size", 13)
	_search_edit.text_changed.connect(func(txt: String):
		_search_query = txt.strip_edges().to_lower()
		_apply_filter()
	)
	left_vb.add_child(_search_edit)

	# Scrollable Item List
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vb.add_child(list_scroll)

	_list_vb = VBoxContainer.new()
	_list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vb.add_theme_constant_override("separation", 4)
	list_scroll.add_child(_list_vb)

	# RIGHT PANEL
	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 10)
	split.add_child(right_vb)

	# Selected Item Info Header
	var info_bar := HBoxContainer.new()
	info_bar.add_theme_constant_override("separation", 10)
	right_vb.add_child(info_bar)

	_stage_title_lbl = Label.new()
	_stage_title_lbl.text = "Select an asset or animation"
	_stage_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_title_lbl.add_theme_font_override("font", _font_disp)
	_stage_title_lbl.add_theme_font_size_override("font_size", 20)
	_stage_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	info_bar.add_child(_stage_title_lbl)

	_stage_status_lbl = Label.new()
	_stage_status_lbl.text = "READY"
	_stage_status_lbl.add_theme_font_override("font", _font_body)
	_stage_status_lbl.add_theme_font_size_override("font_size", 13)
	info_bar.add_child(_stage_status_lbl)

	# Preview Stage Frame
	var stage_panel := PanelContainer.new()
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_theme_stylebox_override("panel", _make_box(Color(0.032, 0.026, 0.022, 1.0), Color(0.50, 0.40, 0.22, 0.85), 1, 8, 8))
	right_vb.add_child(stage_panel)

	_stage_stack = Control.new()
	_stage_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_panel.add_child(_stage_stack)

	_build_stage_fpv()
	_build_stage_3d()
	_build_stage_2d()
	_build_stage_anim_2d()
	_build_stage_audio()

	# Controls Bar
	var ctrl_bar := HBoxContainer.new()
	ctrl_bar.add_theme_constant_override("separation", 8)
	right_vb.add_child(ctrl_bar)

	_play_btn = _make_ctrl_btn("Play", "sword", func():
		_is_playing = not _is_playing
		_play_btn.text = "Pause" if _is_playing else "Play"
		if _fpv_showcase != null and is_instance_valid(_fpv_showcase):
			_fpv_showcase.set_playing(_is_playing)
		if _active_anim_player != null and is_instance_valid(_active_anim_player):
			if _is_playing:
				_active_anim_player.play()
			else:
				_active_anim_player.pause()
	)
	ctrl_bar.add_child(_play_btn)

	_replay_btn = _make_ctrl_btn("Replay", "dice", func():
		_is_playing = true
		_play_btn.text = "Pause"
		if _fpv_showcase != null and is_instance_valid(_fpv_showcase):
			_fpv_showcase.set_playing(true)
			_fpv_showcase.restart()
		else:
			_trigger_selected_preview()
	)
	ctrl_bar.add_child(_replay_btn)

	_loop_btn = _make_ctrl_btn("Loop: ON", "shield", func():
		_loop_enabled = not _loop_enabled
		_loop_btn.text = "Loop: ON" if _loop_enabled else "Loop: OFF"
		if _fpv_showcase != null and is_instance_valid(_fpv_showcase):
			_fpv_showcase.set_loop(_loop_enabled)
	)
	ctrl_bar.add_child(_loop_btn)

	_speed_btn = _make_ctrl_btn("Speed: 1.0x", "crown", func():
		_speed_idx = (_speed_idx + 1) % SPEED_PRESETS.size()
		_speed_scale = SPEED_PRESETS[_speed_idx]
		_speed_btn.text = "Speed: %.2gx" % _speed_scale
		if _fpv_showcase != null and is_instance_valid(_fpv_showcase):
			_fpv_showcase.set_speed(_speed_scale)
		if _active_anim_player != null and is_instance_valid(_active_anim_player):
			_active_anim_player.speed_scale = _speed_scale
	)
	ctrl_bar.add_child(_speed_btn)

	_zoom_1_1_btn = _make_ctrl_btn("1:1 Zoom: OFF", "eye", func():
		_zoom_1_1 = not _zoom_1_1
		_zoom_1_1_btn.text = "1:1 Zoom: ON" if _zoom_1_1 else "1:1 Zoom: OFF"
		_apply_2d_zoom_mode()
	)
	ctrl_bar.add_child(_zoom_1_1_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_bar.add_child(spacer)

	_next_btn = _make_ctrl_btn("Next", "scroll", func():
		if not _filtered_items.is_empty():
			var nxt := (_selected_idx + 1) % _filtered_items.size()
			_select_item(nxt)
	)
	ctrl_bar.add_child(_next_btn)

	# File path & resolution readout
	_stage_meta_lbl = Label.new()
	_stage_meta_lbl.text = "Path: - | Resolution: -"
	_stage_meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage_meta_lbl.add_theme_font_override("font", _font_body)
	_stage_meta_lbl.add_theme_font_size_override("font_size", 12)
	_stage_meta_lbl.add_theme_color_override("font_color", Color(0.76, 0.72, 0.62))
	right_vb.add_child(_stage_meta_lbl)


func _make_ctrl_btn(txt: String, icon_key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(96, 32)
	b.add_theme_font_override("font", _font_body)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", _make_box(Color(0.14, 0.11, 0.08), Color(0.58, 0.44, 0.22), 1, 6, 6))
	LialoIcons.apply_button_icon(b, icon_key, 14)
	b.pressed.connect(cb)
	return b


func _update_cat_buttons() -> void:
	for cat in _cat_btns.keys():
		var b: Button = _cat_btns[cat]
		var act := (str(cat) == _active_cat)
		b.add_theme_stylebox_override("normal", _make_box(
			Color(0.28, 0.20, 0.08, 0.98) if act else Color(0.10, 0.08, 0.07, 0.94),
			Color(1.0, 0.84, 0.34) if act else Color(0.45, 0.35, 0.20),
			2 if act else 1, 6, 6
		))
		b.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72) if act else Color(0.82, 0.76, 0.66))


func _build_stage_3d() -> void:
	_stage_3d_wrap = PanelContainer.new()
	_stage_3d_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_3d_wrap.visible = false
	_stage_stack.add_child(_stage_3d_wrap)

	_vp_container = SubViewportContainer.new()
	_vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp_container.stretch = true
	_vp_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_vp_container.gui_input.connect(_on_3d_stage_input)
	_stage_3d_wrap.add_child(_vp_container)

	_vp = SubViewport.new()
	_vp.size = Vector2i(760, 480)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if _is_headless else SubViewport.UPDATE_ALWAYS
	_vp_container.add_child(_vp)

	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color(0.48, 0.42, 0.36)
	we.ambient_light_energy = 1.2
	env.environment = we
	_vp.add_child(env)

	var key_l := DirectionalLight3D.new()
	key_l.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	key_l.light_color = Color(1.0, 0.90, 0.74)
	key_l.light_energy = 1.85
	_vp.add_child(key_l)

	var rim_l := OmniLight3D.new()
	rim_l.position = Vector3(-1.6, 1.0, -1.4)
	rim_l.light_color = Color(0.42, 0.78, 1.0)
	rim_l.light_energy = 1.5
	_vp.add_child(rim_l)

	_cam_3d = Camera3D.new()
	_cam_3d.position = Vector3(0.0, 0.20, _zoom_dist)
	_cam_3d.fov = 40.0
	_vp.add_child(_cam_3d)

	_pivot_3d = Node3D.new()
	_vp.add_child(_pivot_3d)

	_fx_root_3d = Node3D.new()
	_vp.add_child(_fx_root_3d)


func _on_3d_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_3d = mb.pressed
			_auto_spin_3d = false
			_last_mouse_3d = mb.position
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_dist = clampf(_zoom_dist - 0.16, 0.65, 5.5)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_dist = clampf(_zoom_dist + 0.16, 0.65, 5.5)
	elif event is InputEventMouseMotion and _dragging_3d:
		var mm := event as InputEventMouseMotion
		var d := mm.position - _last_mouse_3d
		_last_mouse_3d = mm.position
		_rot_yaw += d.x * 0.012
		_rot_pitch = clampf(_rot_pitch + d.y * 0.012, -1.25, 1.25)


func _build_stage_2d() -> void:
	_stage_2d_wrap = ScrollContainer.new()
	_stage_2d_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_2d_wrap.visible = false
	_stage_stack.add_child(_stage_2d_wrap)

	_stage_2d_center = CenterContainer.new()
	_stage_2d_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_2d_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage_2d_wrap.add_child(_stage_2d_center)

	_tex_rect_2d = TextureRect.new()
	_tex_rect_2d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect_2d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect_2d.custom_minimum_size = Vector2(520, 420)
	_stage_2d_center.add_child(_tex_rect_2d)


func _apply_2d_zoom_mode() -> void:
	if _tex_rect_2d == null or _tex_rect_2d.texture == null:
		return
	if _zoom_1_1:
		var tsz := _tex_rect_2d.texture.get_size()
		_tex_rect_2d.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		_tex_rect_2d.stretch_mode = TextureRect.STRETCH_KEEP
		_tex_rect_2d.custom_minimum_size = tsz
	else:
		_tex_rect_2d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tex_rect_2d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tex_rect_2d.custom_minimum_size = Vector2(540, 440)


func _build_stage_fpv() -> void:
	_stage_fpv_wrap = PanelContainer.new()
	_stage_fpv_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_fpv_wrap.visible = false
	_stage_stack.add_child(_stage_fpv_wrap)

	_fpv_vp_container = SubViewportContainer.new()
	_fpv_vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fpv_vp_container.stretch = true
	_fpv_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_fpv_wrap.add_child(_fpv_vp_container)

	_fpv_vp = SubViewport.new()
	_fpv_vp.size = Vector2i(960, 540)
	_fpv_vp.own_world_3d = true
	_fpv_vp.msaa_3d = Viewport.MSAA_4X
	_fpv_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if _is_headless else SubViewport.UPDATE_ALWAYS
	_fpv_vp_container.add_child(_fpv_vp)

	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color(0.025, 0.024, 0.036)
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color(0.24, 0.22, 0.28)
	we.ambient_light_energy = 0.72
	we.glow_enabled = true
	we.glow_intensity = 0.85
	we.glow_bloom = 0.35
	env.environment = we
	_fpv_vp.add_child(env)

	var dir_l := DirectionalLight3D.new()
	dir_l.rotation_degrees = Vector3(-48.0, 26.0, 0.0)
	dir_l.light_color = Color(0.84, 0.86, 1.0)
	dir_l.light_energy = 0.75
	_fpv_vp.add_child(dir_l)

	_fpv_cam = Camera3D.new()
	_fpv_cam.fov = 54.0
	_fpv_cam.current = true
	_fpv_cam.look_at_from_position(Vector3(0.0, 1.56, 1.24), Vector3(0.0, 0.94, -0.42), Vector3.UP)
	_fpv_vp.add_child(_fpv_cam)

	_fpv_overlay = Control.new()
	_fpv_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fpv_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_fpv_wrap.add_child(_fpv_overlay)


func _build_stage_anim_2d() -> void:
	_stage_anim_2d = Control.new()
	_stage_anim_2d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_anim_2d.visible = false
	_stage_anim_2d.draw.connect(_draw_anim_2d)
	_stage_stack.add_child(_stage_anim_2d)


func _draw_anim_2d() -> void:
	var vs := _stage_anim_2d.size
	if vs.x < 10.0 or vs.y < 10.0:
		return
	var cx := vs.x * 0.5
	var cy := vs.y * 0.5
	if _anim_2d_kind == "combo_banner":
		var u := clampf(_anim_2d_t / 2.2, 0.0, 1.0)
		var env := sin(u * PI)
		var sc := 0.8 + 0.35 * sin(minf(u * 3.0, 1.0) * PI * 0.5)
		_stage_anim_2d.draw_rect(Rect2(cx - 260 * sc, cy - 68 * sc, 520 * sc, 136 * sc), Color(0.08, 0.05, 0.04, 0.92 * env))
		_stage_anim_2d.draw_rect(Rect2(cx - 260 * sc, cy - 68 * sc, 520 * sc, 136 * sc), Color(_anim_2d_col.r, _anim_2d_col.g, _anim_2d_col.b, env), false, 3.0)
		var title := "%dx COMBO!" % _anim_2d_mult if _anim_2d_mult < 4 else "4x+ GRAND SLAM!"
		_stage_anim_2d.draw_string(_font_disp, Vector2(cx - 220, cy + 12), title, HORIZONTAL_ALIGNMENT_CENTER, 440, int(42 * sc), Color(_anim_2d_col.r, _anim_2d_col.g, _anim_2d_col.b, env))
	elif _anim_2d_kind == "fujira_intro":
		var u := clampf(_anim_2d_t / 2.6, 0.0, 1.0)
		_stage_anim_2d.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.05, 0.09, 1.0))
		var sun_y := lerpf(vs.y * 0.72, vs.y * 0.34, minf(u * 1.4, 1.0))
		_stage_anim_2d.draw_circle(Vector2(cx, sun_y), 54.0, Color(0.98, 0.78, 0.34, 0.88))
		var peak := PackedVector2Array([Vector2(cx - 220, vs.y * 0.82), Vector2(cx - 24, vs.y * 0.28), Vector2(cx + 220, vs.y * 0.82)])
		_stage_anim_2d.draw_colored_polygon(peak, Color(0.14, 0.16, 0.22, 1.0))
		for si in range(28):
			var sx := fmod(float(si) * 97.0 + _anim_2d_t * 32.0, vs.x)
			var sy := fmod(float(si) * 61.0 + _anim_2d_t * 88.0, vs.y)
			_stage_anim_2d.draw_circle(Vector2(sx, sy), 2.5, Color(0.94, 0.96, 1.0, 0.75))
		_stage_anim_2d.draw_string(_font_disp, Vector2(cx - 240, vs.y * 0.88), "FUJIRA STUDIOS", HORIZONTAL_ALIGNMENT_CENTER, 480, 32, Color(0.98, 0.92, 0.76, minf(u * 2.0, 1.0)))


func _build_stage_audio() -> void:
	_stage_audio_wrap = VBoxContainer.new()
	_stage_audio_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_audio_wrap.add_theme_constant_override("separation", 16)
	_stage_audio_wrap.visible = false
	_stage_stack.add_child(_stage_audio_wrap)

	_audio_info_lbl = Label.new()
	_audio_info_lbl.text = "Select an audio track or use the Dynamic BGM Mixer below."
	_audio_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_audio_info_lbl.add_theme_font_override("font", _font_body)
	_audio_info_lbl.add_theme_font_size_override("font_size", 15)
	_audio_info_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	_stage_audio_wrap.add_child(_audio_info_lbl)

	var mix_panel := PanelContainer.new()
	mix_panel.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.065, 0.052, 0.96), Color(0.65, 0.50, 0.24, 0.85), 1, 8, 14))
	_stage_audio_wrap.add_child(mix_panel)

	var mix_vb := VBoxContainer.new()
	mix_vb.add_theme_constant_override("separation", 10)
	mix_panel.add_child(mix_vb)

	var mix_hdr := Label.new()
	mix_hdr.text = "DYNAMIC BATTLE BGM MIXER (CALM -> EPIC -> CLIMAX)"
	mix_hdr.add_theme_font_override("font", _font_disp)
	mix_hdr.add_theme_font_size_override("font_size", 16)
	mix_hdr.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	mix_vb.add_child(mix_hdr)

	var sl_row := HBoxContainer.new()
	sl_row.add_theme_constant_override("separation", 12)
	mix_vb.add_child(sl_row)

	_bgm_intensity_lbl = Label.new()
	_bgm_intensity_lbl.text = "Intensity: 0.00 (CALM)"
	_bgm_intensity_lbl.custom_minimum_size = Vector2(200, 0)
	_bgm_intensity_lbl.add_theme_font_override("font", _font_body)
	_bgm_intensity_lbl.add_theme_font_size_override("font_size", 13)
	sl_row.add_child(_bgm_intensity_lbl)

	_bgm_intensity_slider = HSlider.new()
	_bgm_intensity_slider.min_value = 0.0
	_bgm_intensity_slider.max_value = 1.0
	_bgm_intensity_slider.step = 0.01
	_bgm_intensity_slider.value = 0.0
	_bgm_intensity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bgm_intensity_slider.value_changed.connect(func(v: float):
		_bgm_intensity = v
		_update_bgm_mix_volumes()
	)
	sl_row.add_child(_bgm_intensity_slider)

	_amb_tavern_chk = CheckButton.new()
	_amb_tavern_chk.text = "Include amb_tavern layer"
	_amb_tavern_chk.button_pressed = true
	_amb_tavern_chk.toggled.connect(func(_on: bool):
		_update_bgm_mix_volumes()
	)
	mix_vb.add_child(_amb_tavern_chk)

	var mix_btns := HBoxContainer.new()
	mix_btns.add_theme_constant_override("separation", 10)
	mix_vb.add_child(mix_btns)

	var start_mix_btn := _make_ctrl_btn("Start Dynamic Mix", "horn", func():
		_start_dynamic_bgm_mix()
	)
	start_mix_btn.custom_minimum_size = Vector2(160, 34)
	mix_btns.add_child(start_mix_btn)

	var stop_mix_btn := _make_ctrl_btn("Stop Audio", "cross", func():
		_stop_audio_players()
	)
	stop_mix_btn.custom_minimum_size = Vector2(130, 34)
	mix_btns.add_child(stop_mix_btn)


func _build_audio_players() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	for _si in range(6):
		var sp := AudioStreamPlayer.new()
		add_child(sp)
		_sfx_pool.append(sp)
	_bgm_calm_player = AudioStreamPlayer.new()
	add_child(_bgm_calm_player)
	_bgm_epic_player = AudioStreamPlayer.new()
	add_child(_bgm_epic_player)
	_bgm_climax_player = AudioStreamPlayer.new()
	add_child(_bgm_climax_player)
	_bgm_amb_player = AudioStreamPlayer.new()
	add_child(_bgm_amb_player)


func _stop_audio_players() -> void:
	_bgm_mix_active = false
	for p in [_audio_player, _bgm_calm_player, _bgm_epic_player, _bgm_climax_player, _bgm_amb_player]:
		if is_instance_valid(p):
			p.stop()
	for sp in _sfx_pool:
		if is_instance_valid(sp):
			sp.stop()


func _load_audio_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if path.ends_with(".mp3") and FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			return AudioStreamMP3.load_from_buffer(bytes)
	return null


func _start_dynamic_bgm_mix() -> void:
	_stop_audio_players()
	if _is_headless:
		return
	_bgm_mix_active = true
	var calm := _load_audio_stream("res://assets/audio/bgm_battle_calm.mp3")
	var epic := _load_audio_stream("res://assets/audio/bgm_battle_epic.mp3")
	var climax := _load_audio_stream("res://assets/audio/bgm_battle_intense.mp3")
	var amb := _load_audio_stream("res://assets/audio/amb_tavern.wav")
	if calm:
		_bgm_calm_player.stream = calm
		_bgm_calm_player.play(0.0)
	if epic:
		_bgm_epic_player.stream = epic
		_bgm_epic_player.play(0.0)
	if climax:
		_bgm_climax_player.stream = climax
		_bgm_climax_player.play(0.0)
	if amb:
		_bgm_amb_player.stream = amb
		_bgm_amb_player.play(0.0)
	_update_bgm_mix_volumes()


func _update_bgm_mix_volumes() -> void:
	var x := clampf(_bgm_intensity, 0.0, 1.0)
	var phase := "CALM" if x < 0.48 else ("EPIC" if x < 0.80 else "CLIMAX")
	if is_instance_valid(_bgm_intensity_lbl):
		_bgm_intensity_lbl.text = "Intensity: %.2f (%s)" % [x, phase]
	var w_calm := 0.0
	var w_epic := 0.0
	var w_climax := 0.0
	if x < 0.48:
		var u := clampf(x / 0.48, 0.0, 1.0)
		w_calm = lerpf(1.0, 0.25, u)
		w_epic = lerpf(0.0, 0.85, u)
	elif x < 0.80:
		var u := clampf((x - 0.48) / 0.32, 0.0, 1.0)
		w_calm = lerpf(0.25, 0.0, u)
		w_epic = lerpf(0.85, 1.0, u)
	else:
		var u := clampf((x - 0.80) / 0.20, 0.0, 1.0)
		w_epic = lerpf(1.0, 0.32, u)
		w_climax = lerpf(0.0, 1.0, u)
	if is_instance_valid(_bgm_calm_player):
		_bgm_calm_player.volume_db = (-6.5 + linear_to_db(w_calm)) if w_calm > 0.015 else -80.0
	if is_instance_valid(_bgm_epic_player):
		_bgm_epic_player.volume_db = (-6.5 + linear_to_db(w_epic)) if w_epic > 0.015 else -80.0
	if is_instance_valid(_bgm_climax_player):
		_bgm_climax_player.volume_db = (-6.5 + linear_to_db(w_climax)) if w_climax > 0.015 else -80.0
	if is_instance_valid(_bgm_amb_player):
		_bgm_amb_player.volume_db = -12.5 if (_amb_tavern_chk != null and _amb_tavern_chk.button_pressed) else -80.0


func _add_item(cat: String, title: String, kind: String, path: String = "", extra: Dictionary = {}) -> void:
	var exists := true
	if path != "":
		exists = ResourceLoader.exists(path) or FileAccess.file_exists(path)
	var d := {"cat": cat, "title": title, "kind": kind, "path": path, "exists": exists}
	for k in extra.keys():
		d[k] = extra[k]
	_all_items.append(d)


func _scan_dir_items(cat: String, dir_path: String, exts: PackedStringArray, kind: String, prefix: String = "") -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var fn := da.get_next()
	var files: Array[String] = []
	while fn != "":
		if not da.current_is_dir() and not fn.ends_with(".import") and not fn.ends_with(".uid"):
			for ex in exts:
				if fn.to_lower().ends_with(ex):
					files.append(fn)
					break
		fn = da.get_next()
	da.list_dir_end()
	files.sort()
	for f in files:
		var full := dir_path.path_join(f)
		_add_item(cat, prefix + f.get_basename(), kind, full)


func _catalog_all_items() -> void:
	_all_items.clear()

	# 1. Animations & VFX (Pinned 1st-Person Hand-Drawn 4.2s Power Card Showcases #0..#14)
	for p_card in Catalog.POWER_CARDS:
		var p_id := str(p_card.get("id", ""))
		if PowerCardShowcaseScript.CARD_META.has(p_id):
			var p_meta: Dictionary = PowerCardShowcaseScript.CARD_META[p_id]
			_add_item(CAT_ANIM, "PINNED [1ST-PERSON] Power Card: %s (%s • 4.2s)" % [p_id, str(p_meta.get("title", p_id))], "power_card_fpv", "res://scripts/battle/power_card_vfx_showcase.gd", {"card_id": p_id, "pinned": true})
	for bid in ["GUILLOTINE_ACES", "MIRROR_MONARCH", "CHAOS_JESTER", "MISTBLADE_DUELIST"]:
		_add_item(CAT_ANIM, "Grand Seal: " + bid, "bankai", "res://scripts/battle/bankai_fx.gd", {"build_id": bid})
	_add_item(CAT_ANIM, "SwordCardAnimator (3D Slash & Blade)", "sword_anim", SWORD_ANIM_PATH)
	for vfx_p in BLENDER_VFX_PATHS:
		_add_item(CAT_ANIM, "BlenderVfx: " + vfx_p.get_file().get_basename(), "glb", vfx_p)
	for fx_k in ["Fire (Embers)", "Poison Burst", "Rune Ring & Sigil", "Sparks & Shards", "Blood Splat"]:
		_add_item(CAT_ANIM, "FxLib: " + fx_k, "fx_lib", "res://scripts/fx_lib.gd", {"fx_key": fx_k})
	for cp in ["SPEC_VAMPIRE", "SPEC_STORM", "SPEC_PHOENIX", "RIVAL", "BOSS"]:
		_add_item(CAT_ANIM, "Cinematic Profile: " + cp, "cinematic", "res://scripts/cinematic_profiles.gd", {"profile_id": cp})
	_add_item(CAT_ANIM, "Fujira Studios Intro", "fujira_intro", "res://scripts/downpour_root.gd")
	_add_item(CAT_ANIM, "SnakeLoadingScreen (Ouroboros)", "snake_loading", "res://scripts/ui/snake_loading_screen.gd")
	for sc_id_v in StoryDataScript.COMIC_ORDER:
		var sc_id: String = str(sc_id_v)
		var sc_d: Dictionary = StoryDataScript.get_comic_scene(sc_id)
		_add_item(CAT_ANIM, "Story Comic: %s (%s)" % [str(sc_d.get("title_en", sc_id)), sc_id], "comic_scene", "res://scripts/ui/comic_cutscene_player.gd", {"scene_id": sc_id})
	for mult in [1, 2, 3, 4]:
		_add_item(CAT_ANIM, "Combo Banner: %dx%s" % [mult, "+" if mult >= 4 else ""], "combo_banner", "", {"mult": mult})

	# 2. 3D Models & Relics
	for tr in Catalog.TABLE_RELICS:
		var tid := str(tr["id"])
		_add_item(CAT_3D, "Relic: " + str(tr["name"]), "table_relic", str(tr.get("glb", "")), {"relic_id": tid, "col": tr.get("col", Color.GOLD)})
	_scan_dir_items(CAT_3D, "res://assets/models", PackedStringArray([".glb"]), "glb", "Model: ")
	for sw in Catalog.SWORD_SKINS:
		_add_item(CAT_3D, "Sword Skin: " + str(sw["name"]), "sword_3d", "res://scripts/relic_mesh_factory.gd", {"sword_id": str(sw["id"]), "sword_data": sw})
	_scan_dir_items(CAT_3D, "res://assets/gloves", PackedStringArray([".glb", ".png"]), "glove_or_prop", "Glove: ")
	_scan_dir_items(CAT_3D, "res://assets/table", PackedStringArray([".glb"]), "glb", "Table Prop: ")

	# 3. 2D Cards, Backs, Icons & UI Assets
	for s in ["CERVEN", "ZELEN", "ZALUD", "GULA"]:
		for r in ["7", "8", "9", "10", "D", "H", "K", "E"]:
			var ck := "%s_%s" % [s, r]
			_add_item(CAT_2D, "Card: " + ck, "tex_2d", "res://assets/cards/%s.png" % ck)
	for pc in Catalog.POWER_CARDS:
		var pid := str(pc["id"])
		_add_item(CAT_2D, "Power Card: " + str(pc["name"]), "tex_2d", "res://assets/cards/%s.png" % pid)
	_scan_dir_items(CAT_2D, "res://assets/table", PackedStringArray([".png"]), "tex_2d", "Table/Back: ")
	_scan_dir_items(CAT_2D, "res://assets/ui/icons", PackedStringArray([".png"]), "tex_2d", "Icon: ")
	_scan_dir_items(CAT_2D, "res://assets/vfx", PackedStringArray([".png"]), "tex_2d", "VFX: ")
	_scan_dir_items(CAT_2D, "res://assets/vfx/sword_card", PackedStringArray([".png"]), "tex_2d", "SwordVFX: ")
	_scan_dir_items(CAT_2D, "res://assets/shop", PackedStringArray([".png"]), "tex_2d", "Shop: ")
	_scan_dir_items(CAT_2D, "res://assets/map", PackedStringArray([".png"]), "tex_2d", "Map: ")
	_scan_dir_items(CAT_2D, "res://assets/lobby", PackedStringArray([".png"]), "tex_2d", "Lobby: ")

	# 4. Audio & Dynamic BGM
	_add_item(CAT_AUDIO, "Dynamic Battle BGM Mixer (Calm/Epic/Climax)", "bgm_mixer", "res://assets/audio/bgm_battle_calm.mp3")
	_scan_dir_items(CAT_AUDIO, "res://assets/audio", PackedStringArray([".mp3", ".wav"]), "audio", "Audio: ")


func _apply_filter() -> void:
	_filtered_items.clear()
	for it in _all_items:
		if _active_cat != CAT_ALL and str(it["cat"]) != _active_cat:
			continue
		if _search_query != "" and not str(it["title"]).to_lower().contains(_search_query) and not str(it["path"]).to_lower().contains(_search_query):
			continue
		_filtered_items.append(it)

	for c in _list_vb.get_children():
		c.queue_free()
	_item_btns.clear()
	_selected_idx = -1

	for i in range(_filtered_items.size()):
		var it := _filtered_items[i]
		var ok := bool(it["exists"])
		var is_pinned := bool(it.get("pinned", false))
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = ("[PINNED] %s" % str(it["title"])) if is_pinned else ("[%s] %s" % ["OK" if ok else "MISSING", str(it["title"])])
		btn.add_theme_font_override("font", _font_body)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.55, 0.96, 1.0) if is_pinned else (Color(0.74, 0.94, 0.72) if ok else Color(0.98, 0.42, 0.38)))
		var idx_cap := i
		btn.pressed.connect(func(): _select_item(idx_cap))
		_list_vb.add_child(btn)
		_item_btns.append(btn)

	if not _filtered_items.is_empty():
		_select_item(0)


func _select_item(idx: int) -> void:
	if idx < 0 or idx >= _filtered_items.size():
		return
	_selected_idx = idx
	for i in range(_item_btns.size()):
		if is_instance_valid(_item_btns[i]):
			var sel := (i == idx)
			var is_pin := bool(_filtered_items[i].get("pinned", false)) if i < _filtered_items.size() else false
			_item_btns[i].add_theme_stylebox_override("normal", _make_box(
				Color(0.10, 0.24, 0.30) if (sel and is_pin) else (Color(0.24, 0.18, 0.08) if sel else (Color(0.07, 0.14, 0.18) if is_pin else Color(0.08, 0.065, 0.055))),
				Color(0.45, 0.94, 1.0) if (sel and is_pin) else (Color(0.96, 0.78, 0.32) if sel else (Color(0.32, 0.74, 0.88) if is_pin else Color(0.26, 0.21, 0.16))), 2 if is_pin else 1, 5, 6
			))
	_trigger_selected_preview()


func _stop_all_previews() -> void:
	_stop_audio_players()
	_active_anim_player = null
	if is_instance_valid(_fpv_showcase):
		_fpv_showcase.queue_free()
		_fpv_showcase = null
	if is_instance_valid(_bankai_fx):
		_bankai_fx.clear_aura()
		_bankai_fx.queue_free()
		_bankai_fx = null
	if is_instance_valid(_snake_screen):
		_snake_screen.queue_free()
		_snake_screen = null
	if is_instance_valid(_fujira_intro_node):
		_fujira_intro_node.queue_free()
		_fujira_intro_node = null
	if is_instance_valid(_comic_preview_node):
		_comic_preview_node.queue_free()
		_comic_preview_node = null
	if is_instance_valid(_pivot_3d):
		for c in _pivot_3d.get_children():
			c.queue_free()
	if is_instance_valid(_fx_root_3d):
		for c in _fx_root_3d.get_children():
			c.queue_free()
	if is_instance_valid(_stage_fpv_wrap):
		_stage_fpv_wrap.visible = false
	_stage_3d_wrap.visible = false
	_stage_2d_wrap.visible = false
	_stage_anim_2d.visible = false
	_stage_audio_wrap.visible = false


func _trigger_selected_preview() -> void:
	if _selected_idx < 0 or _selected_idx >= _filtered_items.size():
		return
	_stop_all_previews()
	_loop_timer = 0.0
	var it := _filtered_items[_selected_idx]
	var kind := str(it["kind"])
	# First-person tabletop POV default for animations & VFX; turntable spin only for static props
	if kind in ["table_relic", "sword_3d"]:
		_rot_yaw = 0.45
		_rot_pitch = -0.24
		_zoom_dist = 1.75
		_auto_spin_3d = true
	else:
		_rot_yaw = 0.06
		_rot_pitch = -0.30
		_zoom_dist = 1.62
		_auto_spin_3d = false
	var path := str(it.get("path", ""))
	var ok := bool(it["exists"])

	_stage_title_lbl.text = str(it["title"])
	_stage_status_lbl.text = "OK" if ok else "MISSING"
	_stage_status_lbl.add_theme_color_override("font_color", Color(0.46, 0.96, 0.60) if ok else Color(0.98, 0.38, 0.36))
	_stage_meta_lbl.text = "Category: %s | Path: %s" % [str(it["cat"]), path if path != "" else "(Procedural / Built-in)"]

	match kind:
		"power_card_fpv":
			_stage_fpv_wrap.visible = true
			_fpv_showcase = PowerCardShowcaseScript.new()
			_fpv_vp.add_child(_fpv_showcase)
			_fpv_showcase.sfx_triggered.connect(func(sfx_key: String, vol_db: float, pitch_val: float):
				if _is_headless or _sfx_pool.is_empty():
					return
				var st := _load_audio_stream("res://assets/audio/sfx_%s.mp3" % sfx_key)
				if st == null:
					st = _load_audio_stream("res://assets/audio/sfx_%s.wav" % sfx_key)
				if st != null:
					var sp: AudioStreamPlayer = _sfx_pool[_sfx_pool_idx]
					_sfx_pool_idx = (_sfx_pool_idx + 1) % _sfx_pool.size()
					if is_instance_valid(sp):
						sp.stream = st
						sp.volume_db = vol_db
						sp.pitch_scale = pitch_val
						sp.play()
			)
			_fpv_showcase.setup_fpv_preview(_fpv_cam, _fpv_overlay, _loop_enabled, str(it.get("card_id", "SPEC_STORM")))
			_fpv_showcase.set_speed(_speed_scale)
			_fpv_showcase.set_playing(_is_playing)
		"bankai":
			_stage_anim_2d.visible = true
			if not _is_headless:
				_bankai_fx = BankaiFxScript.new()
				_bankai_fx.layer = 99
				add_child(_bankai_fx)
				_bankai_fx.trigger_grand_seal(str(it.get("build_id", "GUILLOTINE_ACES")), "DEV INSPECTOR", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"], "en", _loop_enabled)
		"snake_loading":
			_stage_anim_2d.visible = true
			if not _is_headless:
				_snake_screen = SnakeLoadingScript.new()
				_snake_screen.layer = 99
				_snake_screen.configure_transition("DEV PREVIEW: OUROBOROS", Callable(), 4.5, -14.0)
				add_child(_snake_screen)
		"fujira_intro":
			if not _is_headless:
				_fujira_intro_node = FujiraIntroScript.new()
				_fujira_intro_node.set("skippable", false)
				_fujira_intro_node.set("play_internal_audio", false)
				_stage_stack.add_child(_fujira_intro_node)
				_fujira_intro_node.call("start_intro", false, _loop_enabled)
			else:
				_stage_anim_2d.visible = true
				_anim_2d_kind = "fujira_intro"
				_anim_2d_t = 0.0
		"comic_scene":
			_comic_preview_node = ComicPlayerScript.new()
			_stage_stack.add_child(_comic_preview_node)
			var sc_cap: String = str(it.get("scene_id", "COMIC_PROLOGUE_INTRO"))
			_comic_preview_node.play_scene(sc_cap, "en", true, true)
			_comic_preview_node.scene_finished.connect(func(_sid: String):
				if _loop_enabled and is_instance_valid(_comic_preview_node) and visible:
					_comic_preview_node.play_scene(sc_cap, "en", true, true)
			)
		"combo_banner":
			_stage_anim_2d.visible = true
			_anim_2d_kind = "combo_banner"
			_anim_2d_mult = int(it.get("mult", 1))
			_anim_2d_col = [Color(0.85, 0.85, 0.90), Color(0.38, 0.88, 1.0), Color(1.0, 0.76, 0.24), Color(1.0, 0.28, 0.34)][clampi(_anim_2d_mult - 1, 0, 3)]
			_anim_2d_t = 0.0
		"sword_anim":
			_stage_3d_wrap.visible = true
			if not _is_headless:
				# Mount 1st-person tabletop coaster & sculpted Oath Blade so the slash has full 3D context
				var coaster := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.55; cm.bottom_radius = 0.58; cm.height = 0.04; cm.radial_segments = 18
				coaster.mesh = cm
				coaster.position = Vector3(0.0, -0.32, 0.0)
				var cmat := StandardMaterial3D.new()
				cmat.albedo_color = Color(0.14, 0.10, 0.07)
				cmat.roughness = 0.85
				coaster.material_override = cmat
				_pivot_3d.add_child(coaster)
				if ResourceLoader.exists(RELIC_MESH_FACTORY_PATH):
					var rmf_s := load(RELIC_MESH_FACTORY_PATH) as GDScript
					if rmf_s != null and rmf_s.has_method("build_sword_3d_mesh"):
						var sw_n := rmf_s.call("build_sword_3d_mesh", "SWORD_IRON", {}) as Node3D
						if sw_n != null:
							sw_n.position = Vector3(0.0, 0.05, 0.0)
							sw_n.rotation_degrees = Vector3(12.0, 28.0, -24.0)
							_pivot_3d.add_child(sw_n)
							var sw_tw := sw_n.create_tween().set_loops()
							sw_tw.tween_property(sw_n, "rotation_degrees:z", 34.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
							sw_tw.tween_property(sw_n, "rotation_degrees:z", -24.0, 0.65).set_trans(Tween.TRANS_SINE)
				FxLib.tybw_slash_arc(_fx_root_3d, Vector3(-0.65, -0.05, 0.35), Vector3(0.65, 0.25, -0.35), Color(0.32, 0.88, 1.0), 1.3)
				FxLib.ring(_fx_root_3d, Vector3(0.0, -0.25, 0.0), Color(0.32, 0.88, 1.0), 0.75, 1.0)
		"fx_lib":
			_stage_3d_wrap.visible = true
			if not _is_headless:
				_spawn_fx_lib_demo(str(it.get("fx_key", "")))
		"cinematic":
			_stage_3d_wrap.visible = true
			if not _is_headless:
				var glb := "res://assets/models/vfx/card_anim_ace_chronos.glb"
				var prof_id := str(it.get("profile_id", ""))
				if prof_id == "SPEC_VAMPIRE":
					glb = CinematicProfiles.PATH_VAMPIRE_CRIMSON
				elif prof_id == "SPEC_STORM":
					glb = CinematicProfiles.PATH_STORM_TEMPEST
				elif prof_id == "SPEC_PHOENIX":
					glb = CinematicProfiles.PATH_PHOENIX_INFERNO
				_load_glb_into_pivot(glb)
		"table_relic":
			_stage_3d_wrap.visible = true
			if not _is_headless and ResourceLoader.exists(RELIC_MESH_FACTORY_PATH):
				var rmf := load(RELIC_MESH_FACTORY_PATH) as GDScript
				if rmf != null and rmf.has_method("build_relic_3d_mesh"):
					var m := rmf.call("build_relic_3d_mesh", str(it.get("relic_id", "")), it.get("col", Color.GOLD) as Color) as Node3D
					if m != null:
						_normalize_3d_node(m)
		"sword_3d":
			_stage_3d_wrap.visible = true
			if not _is_headless and ResourceLoader.exists(RELIC_MESH_FACTORY_PATH):
				var rmf := load(RELIC_MESH_FACTORY_PATH) as GDScript
				if rmf != null and rmf.has_method("build_sword_3d_mesh"):
					var sw := rmf.call("build_sword_3d_mesh", str(it.get("sword_id", "SWORD_IRON")), it.get("sword_data", {}) as Dictionary) as Node3D
					if sw != null:
						_normalize_3d_node(sw)
		"glb":
			_stage_3d_wrap.visible = true
			if not _is_headless and path != "":
				_load_glb_into_pivot(path)
		"glove_or_prop":
			if path.ends_with(".glb"):
				_stage_3d_wrap.visible = true
				if not _is_headless:
					_load_glb_into_pivot(path)
			else:
				_show_2d_texture(path)
		"tex_2d":
			_show_2d_texture(path)
		"bgm_mixer":
			_stage_audio_wrap.visible = true
			_audio_info_lbl.text = "Use the Dynamic Battle BGM Mixer below to audition Calm -> Epic -> Climax."
		"audio":
			_stage_audio_wrap.visible = true
			_audio_info_lbl.text = "Playing: " + path
			if not _is_headless:
				var st := _load_audio_stream(path)
				if st != null:
					_audio_player.stream = st
					_audio_player.play()
				else:
					_stage_status_lbl.text = "LOAD FAILED"


func _show_2d_texture(path: String) -> void:
	_stage_2d_wrap.visible = true
	var tex: Texture2D = Toon.tex(path) if path != "" else null
	_tex_rect_2d.texture = tex
	_apply_2d_zoom_mode()
	if tex != null:
		var sz := tex.get_size()
		_stage_meta_lbl.text = "Path: %s | Resolution: %dx%d px" % [path, int(sz.x), int(sz.y)]
	else:
		_stage_status_lbl.text = "MISSING"
		_stage_status_lbl.add_theme_color_override("font_color", Color(0.98, 0.38, 0.36))


func _spawn_fx_lib_demo(fx_key: String) -> void:
	if _fx_root_3d == null:
		return
	match fx_key:
		"Fire (Embers)":
			FxLib.embers(_fx_root_3d, Vector3.ZERO, 45, 1.3)
		"Poison Burst":
			FxLib.burst(_fx_root_3d, Vector3.ZERO, Color(0.28, 0.94, 0.32), 32, 1.4)
		"Rune Ring & Sigil":
			FxLib.ring(_fx_root_3d, Vector3.ZERO, Color(0.32, 0.88, 1.0), 0.72, 1.2)
			FxLib.sigil_clock(_fx_root_3d, Vector3.ZERO, Vector3(0.4, 0.0, 0.0), 1.2)
		"Sparks & Shards":
			FxLib.shard_burst(_fx_root_3d, Vector3.ZERO, Color(1.0, 0.82, 0.28), 16, 0.65)
			FxLib.gold_flakes(_fx_root_3d, Vector3.ZERO, 30, 1.2)
		_:
			FxLib.ink_splat(_fx_root_3d, Vector3.ZERO, 24, 1.3)
			FxLib.burst(_fx_root_3d, Vector3.ZERO, Color(0.88, 0.12, 0.16), 30, 1.4)


func _load_glb_into_pivot(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var ps := load(path) as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate()
	if inst is Node3D:
		var n3d := inst as Node3D
		_normalize_3d_node(n3d)
		# First-person tabletop tilt so player sees front face & silhouette cleanly
		n3d.rotation_degrees.x = -10.0
		var ap := _find_anim_player(n3d)
		if ap != null:
			_active_anim_player = ap
			ap.speed_scale = _speed_scale
			var anims := ap.get_animation_list()
			var played := false
			for an in anims:
				if String(an) != "RESET":
					ap.play(an)
					played = true
					break
			if not played and anims.size() > 0:
				ap.play(anims[0])
		else:
			# Fallback procedural motion for static GLBs so nothing looks frozen
			var glb_tw := n3d.create_tween().set_loops()
			glb_tw.tween_property(n3d, "position:y", n3d.position.y + 0.08, 0.9).set_trans(Tween.TRANS_SINE)
			glb_tw.tween_property(n3d, "position:y", n3d.position.y - 0.03, 0.9).set_trans(Tween.TRANS_SINE)
	elif inst != null:
		inst.queue_free()


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var f := _find_anim_player(c)
		if f != null:
			return f
	return null


func _normalize_3d_node(node: Node3D) -> void:
	_pivot_3d.add_child(node)
	var has_box := false
	var total := AABB()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var b := (cur as MeshInstance3D).get_aabb()
			total = b if not has_box else total.merge(b)
			has_box = true
		for ch in cur.get_children():
			stack.append(ch)
	if has_box:
		var max_d := maxf(total.size.x, maxf(total.size.y, total.size.z))
		if max_d > 0.001:
			var sc := 0.95 / max_d
			node.scale = Vector3.ONE * sc
			node.position = -total.get_center() * sc
