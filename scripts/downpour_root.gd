extends Node
## LIALO — Fujira Studios (Godot 4.x Engine)
## 1) Animované intro "FUJIRA STUDIOS" (Vystúpi hora -> Plynulo zasneží -> Kamzíky + znelka)
## 2) Hlavné menu "LIALO" (5 epických kartových animácií + znelka + hero KAMPAŇ + čisté tabule)
## 3) 3D Mapa Kampane (Tmavozelený okraj + 3D oblaky po okrajoch, upscalovaná textúra, návod)
## 4) Skutočný 3D Stôl (BattleTable3D) v živej krčme s výhľadom z okien & close-up hodom kariet

const Catalog := preload("res://scripts/lialo_catalog.gd")
const WOODCUT_POST_SHADER := preload("res://shaders/woodcut_post.gdshader")
const MpConfig := preload("res://scripts/mp/mp_config.gd")
const MpDevEntry := preload("res://scripts/mp/mp_dev_entry.gd")
const LobbyOptions3DScript := preload("res://scripts/lobby_options_3d.gd")
const SnakeLoadingScreenScript := preload("res://scripts/ui/snake_loading_screen.gd")
const DeckBuilderPanelScript := preload("res://scripts/ui/deck_builder_panel.gd")

enum ScreenState { SPLASH, MAIN_MENU, WORLD_3D, MATCH_3D }

var current_screen: ScreenState = ScreenState.SPLASH
var player_level: int = 1
var builder_unlock_level: int = 10
var run_profile: Dictionary = {}
var pending_post_match_shop: bool = false
var last_victory_info: Dictionary = {}
var shop_offers: Array[Dictionary] = []
var shop_modal: PanelContainer
var shop_title_lbl: Label
var shop_gold_lbl: Label
var shop_items_box: VBoxContainer
var almanac_modal: PanelContainer
var almanac_tab_idx: int = 0
var almanac_list_box: VBoxContainer
var map_gold_lbl: Label
var map_relics_row: HBoxContainer
var sculpt_modal: PanelContainer
var sculpt_title_lbl: Label
var sculpt_desc_lbl: Label
var sculpt_suit_bar: HBoxContainer
var sculpt_grid: GridContainer
var sculpt_selected_suit: String = "CERVEN"
var sculpt_pending_offer_idx: int = -1
var endless_mode_selected: bool = false
var campaign_tier_row: HBoxContainer
var asc_val_lbl: Label
var endless_toggle_btn: Button
var campaign_diff_btn: Button
var pending_post_loss_spoils: Dictionary = {}

var ui_layer: CanvasLayer
var map_woodcut_layer: CanvasLayer
var map_woodcut_mat: ShaderMaterial
var map_print_btn: Button
var woodcut_mode: int = 3 # 3 = Liar's Bar PBR, 0 = Living Woodcut, 1 = Broadsheet Sepia, 2 = Classic Toon
var game_options: Dictionary = {}
var options_layer: CanvasLayer
var options_3d: LobbyOptions3DScript
var lobby_options_btn: Button
var collection_close_btn: Button
var collection_det_close_btn: Button
var map_btn_back: Button
var map_btn_guide: Button
var map_btn_nav: Button
var map_btn_shop: Button
var map_guide_title: Label
var map_guide_body: Label
var map_guide_next_btn: Button
var map_guide_ok_btn: Button
var map_nav_title: Label
var map_nav_close_btn: Button
var map_nav_row_widgets: Array[Dictionary] = []
var shop_reroll_btn: Button
var shop_close_btn: Button
var sculpt_cancel_btn: Button
var almanac_title_lbl: Label
var almanac_tab_btns: Array[Button] = []
var almanac_close_btn: Button
var era_label3d_nodes: Array[Dictionary] = []
var game_theme: Theme
var splash_control: Control
var menu_control: Control
var hud_3d_control: Control
var signs_box: VBoxContainer

# Splash animácia 3D hory (Kriváň z Blenderu + sunrise + 3D sneženie + 3D animované kamzíky)
var splash_sky_canvas: Control
var splash_3d_container: SubViewportContainer
var splash_3d_vp: SubViewport
var splash_3d_cam: Camera3D
var splash_3d_sun: DirectionalLight3D
var splash_3d_rim_light: DirectionalLight3D
var splash_mtn_root: Node3D
var splash_mtn_mat: ShaderMaterial
var splash_3d_snow_particles: GPUParticles3D
var splash_chamois_nodes: Array[Node3D] = []
var splash_chamois_anims: Array[AnimationPlayer] = []
var splash_chamois_trails: Array[Dictionary] = []
var splash_canvas: Control
var splash_time: float = 0.0
var splash_skipped: bool = false

# Audio & Music System (Theme, Map, Tavern + Ambient + SFX — Focus Gated!)
var bgm_player: AudioStreamPlayer
var amb_player: AudioStreamPlayer
var splash_sfx_player: AudioStreamPlayer
var battle_bgm_players: Dictionary = {}
var battle_music_intensity: float = 0.0
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_idx: int = 0
var sfx_cache: Dictionary = {}
var bgm_cache: Dictionary = {}
var audio_muted: bool = false
var audio_volume_pct: int = 85
var audio_drawer_open: bool = false
var mute_buttons: Array[Button] = []
var audio_toggle_btns: Array[Button] = []
var audio_drawers: Array[Control] = []
var audio_sliders: Array[HSlider] = []
var audio_pct_labels: Array[Label] = []
var active_bgm_key: String = ""
var music_enabled: bool = true # Active across Lialo Lobby, Map & In-Game Battle (paused automatically when unfocused).
var window_focused: bool = true
var _splash_audio_pending: bool = false
var mp_entry: Node = null
var intro_handdrawn_tex: Texture2D
var lobby_handdrawn_tex: Texture2D
var lobby_king_sheet_tex: Texture2D
var lobby_halberdier_sheet_tex: Texture2D
var lobby_jester_sheet_tex: Texture2D
var lobby_phoenix_sheet_tex: Texture2D
var lobby_empty_cards: Dictionary = {}
var suit_crest_cache: Dictionary = {}
var lobby_slash_fx_tex: Texture2D
var lobby_sparks_fx_tex: Texture2D

# Main Menu & 5 alternating card animations + Epické otváracie intro
var menu_sign_visuals: Array[Control] = []
var title_logo_node: Control
var title_tagline_node: Label
var logo_aura_canvas: Control
var lobby_sun_rect: ColorRect
var lobby_sun_mat: ShaderMaterial
var lobby_sun_canvas: Control
var lobby_dark_veil: ColorRect
var transition_curtain: ColorRect
var lobby_fx_canvas: Control
var arsenal_layer: CanvasLayer
var deck_modal: PanelContainer
var selected_deck_idx: int = 0
var collection_tab_idx: int = 0
var collection_flip_all: bool = false
var collection_grid: GridContainer
var collection_decks_box: VBoxContainer
var collection_blades_box: VBoxContainer
var collection_deck_builder: DeckBuilderPanelScript
var collection_tab_btns: Array[Button] = []
var collection_scroll: ScrollContainer
var collection_stats_lbl: Label
var collection_title_lbl: Label
var collection_flip_btn: Button
var collection_detail_modal: PanelContainer
var _active_collection_hover_slot: Control = null
var _active_collection_hover_reset: Callable = Callable()
var col_det_title: Label
var col_det_sub: Label
var col_det_art: TextureRect
var col_det_desc: Label
var col_det_badge: Label
var lobby_anim_time: float = 0.0
var lobby_intro_time: float = 0.0
var lobby_intro_active: bool = false
var lobby_intro_cards: Array[Dictionary] = []
var lobby_prev_phase: int = -1
var showcase_cards: Array[Dictionary] = []
var showcase_spawn_accum: float = 0.0
var shuffle_cards: Array[Dictionary] = []
var shuffle_spawn_accum: float = 0.0
var card_face_cache: Dictionary = {}
var card_back_tex: Texture2D
var menu_icons_tex: Texture2D

# 3D Top-Down Mapa Kampane
var world_3d_root: Node3D
var world_env_node: WorldEnvironment
var cam_pivot: Node3D
var cam_3d: Camera3D
var is_dragging_cam: bool = false
var cam_zoom: float = 1.0
var cam_target_pos := Vector3(0.0, 0.0, 3.0)
var compass_needle_ctrl: Control
var era_medallions: Array[Node3D] = []
var era_ring_meshes: Array[MeshInstance3D] = []
var map_tree_nodes: Array[Node3D] = []
var map_cloud_nodes: Array[Node3D] = []
var map_river_ripples: Array[Dictionary] = []
var map_sheep_actors: Array[Dictionary] = []
var map_mist_sheets: Array[Dictionary] = []
var era_beacon_lights: Array[OmniLight3D] = []
var map_trail_beads: Array[Node3D] = []
var map_frame_rect: TextureRect
var map_top_panel: PanelContainer
var book_folio_fx: Control
var map_open_active: bool = false
var map_open_time: float = 10.0
var map_cloud_bubbles: Array[Dictionary] = []
var hovered_era_idx: int = -1
var selected_era_idx: int = 0
var campaign_card_panel: PanelContainer
var campaign_title_lbl: Label
var campaign_desc_lbl: Label
var campaign_play_btn: Button
var era_towers: Array[Node3D] = []
var map_guide_modal: PanelContainer
var map_nav_modal: PanelContainer
var first_map_guide_shown: bool = false
var first_battle_tutorial_done: bool = false

var battle_3d: Node3D

const BattleTable3DScript = preload("res://scripts/battle_table_3d.gd")
const Toon = preload("res://scripts/toon_style.gd")
const MOUNTAIN_SHADER := preload("res://shaders/mountain_toon.gdshader")
const MAP_PARCHMENT_SHADER := preload("res://shaders/map_parchment.gdshader")
const LOBBY_SUN_SHADER := preload("res://shaders/lobby_sun.gdshader")
const FONT_DISPLAY_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_UI_PATH := "res://assets/fonts/LialoBody.ttf"
const FONT_QUILL_PATH := "res://assets/fonts/LialoQuill.ttf"
var _cached_quill_font: Font = null

const LOBBY_SUITS = [
	{"id": "CERVEN", "sym": "♥", "col": Color(0.86, 0.20, 0.24)},
	{"id": "ZELEN",  "sym": "♠", "col": Color(0.16, 0.56, 0.38)},
	{"id": "ZALUD",  "sym": "♣", "col": Color(0.56, 0.40, 0.18)},
	{"id": "GULA",   "sym": "♦", "col": Color(0.90, 0.50, 0.18)}
]
const LOBBY_RANKS = ["7", "8", "9", "10", "D", "H", "K", "E"]

const PLAYER_DECKS = [
	{
		"id": "klasic",
		"era_id": "stredovek",
		"name": "Classic Leather",
		"name_cs": "Klasická kůže",
		"desc": "Saddle-stitched tavern leather & oak crests. Balanced deck & gauntlets.",
		"desc_cs": "Šitá krčmová kůže a dubové erby. Vyvážený balíček a rukavice.",
		"back_tex": "res://assets/table/deck_back_klasic.png",
		"box_style": "klasic",
		"glove_col": Color(0.45, 0.30, 0.18),
		"border_col": Color(0.85, 0.68, 0.30),
		"use_iron": false,
		"start_bonus_pts": 0,
		"bonus_puf": 0,
		"extra_draw": 0,
	},
	{
		"id": "antika",
		"era_id": "antika",
		"name": "Pharaoh's Vault",
		"name_cs": "Faraonův poklad",
		"desc": "Winged scarab papyrus codex, golden bracers & +15 start points.",
		"desc_cs": "Papyrus se skarabem a okem Hora, zlaté nátepníky a +15 b. do startu.",
		"back_tex": "res://assets/table/deck_back_antika.png",
		"box_style": "antika",
		"glove_col": Color(0.62, 0.45, 0.14),
		"border_col": Color(0.96, 0.74, 0.26),
		"use_iron": false,
		"start_bonus_pts": 15,
		"bonus_puf": 0,
		"extra_draw": 0,
	},
	{
		"id": "rim",
		"era_id": "rim",
		"name": "Legion's Aegis",
		"name_cs": "Štít legie",
		"desc": "Imperial vermilion scutum & Aquila bronze. Roman steel & +10 start pts.",
		"desc_cs": "Purpurový štít s orlem a blesky, římská ocel a +10 bodů do startu.",
		"back_tex": "res://assets/table/deck_back_rim.png",
		"box_style": "rim",
		"glove_col": Color(0.42, 0.18, 0.16),
		"border_col": Color(0.91, 0.44, 0.32),
		"use_iron": true,
		"start_bonus_pts": 10,
		"bonus_puf": 0,
		"extra_draw": 0,
	},
	{
		"id": "stredovek",
		"era_id": "stredovek",
		"name": "Iron Crown",
		"name_cs": "Železná koruna",
		"desc": "Cathedral iron & Wenceslas crown plate, knightly gloves & +1 Fire Phial.",
		"desc_cs": "Katedrální železo se Svatováclavskou korunou, pláty a +1 Baňka ohně.",
		"back_tex": "res://assets/table/deck_back_stredovek.png",
		"box_style": "stredovek",
		"glove_col": Color(0.28, 0.33, 0.40),
		"border_col": Color(0.58, 0.83, 0.69),
		"use_iron": true,
		"start_bonus_pts": 0,
		"bonus_puf": 1,
		"extra_draw": 0,
	},
	{
		"id": "objavy",
		"era_id": "objavy",
		"name": "Corsair's Grip",
		"name_cs": "Korzárův stisk",
		"desc": "Portolan sea chart & caravel seal, seafarer gloves & +1 extra card.",
		"desc_cs": "Námořní portolánová mapa s karavelou, rukavice a +1 karta navíc.",
		"back_tex": "res://assets/table/deck_back_objavy.png",
		"box_style": "objavy",
		"glove_col": Color(0.14, 0.25, 0.36),
		"border_col": Color(0.30, 0.78, 0.94),
		"use_iron": false,
		"start_bonus_pts": 0,
		"bonus_puf": 0,
		"extra_draw": 1,
	},
	{
		"id": "prohibicia",
		"era_id": "prohibicia",
		"name": "Syndicate Noir",
		"name_cs": "Syndikát prohibice",
		"desc": "1920s Art Deco gold & black velvet speakeasy deck. +12 start pts & sleek dark gloves.",
		"desc_cs": "Art Deco zlato a černý samet tajného baru. +12 bodů do startu a tmavé rukavice.",
		"back_tex": "res://assets/table/deck_back_prohibicia.png",
		"box_style": "prohibicia",
		"glove_col": Color(0.14, 0.12, 0.16),
		"border_col": Color(0.96, 0.76, 0.26),
		"use_iron": false,
		"start_bonus_pts": 12,
		"bonus_puf": 0,
		"extra_draw": 0,
	},
	{
		"id": "obsidian",
		"era_id": "stredovek",
		"name": "Obsidian Seal",
		"name_cs": "Obsidiánová pečeť",
		"desc": "Forged obsidian-iron & crimson ritual seal. +1 Hellfire Phial & obsidian-steel gauntlets.",
		"desc_cs": "Kovaná obsidiánová pečeť a rudý rituální znak. +1 Baňka ohně a obsidiánové rukavice.",
		"back_tex": "res://assets/table/deck_back_obsidian.png",
		"box_style": "obsidian",
		"glove_col": Color(0.12, 0.08, 0.10),
		"border_col": Color(0.96, 0.18, 0.26),
		"use_iron": true,
		"start_bonus_pts": 10,
		"bonus_puf": 1,
		"extra_draw": 0,
	},
	{
		"id": "astral",
		"era_id": "objavy",
		"name": "Astral Compass",
		"name_cs": "Astrální kompas",
		"desc": "Midnight indigo & blazing cyan star-chart crest. +1 extra draw & silver celestial bracers.",
		"desc_cs": "Půlnoční modř a zářící azurová hvězdná mapa. +1 karta navíc a stříbrné nátepníky.",
		"back_tex": "res://assets/table/deck_back_astral.png",
		"box_style": "astral",
		"glove_col": Color(0.16, 0.24, 0.42),
		"border_col": Color(0.24, 0.90, 1.0),
		"use_iron": true,
		"start_bonus_pts": 8,
		"bonus_puf": 0,
		"extra_draw": 1,
	}
]

const ERAS_DATA = [
	{
		"id": "antika",
		"name": "Ancient Egypt & Greece",
		"name_cs": "Starověký Egypt a Řecko",
		"boss": "Pharaoh Ramesses",
		"boss_cs": "Faraon Ramesse",
		"skin_name": "Golden Pharaoh Bracers",
		"skin_name_cs": "Zlaté faraonovy nátepníky",
		"glove_col": Color(0.55, 0.40, 0.12),
		"border_col": Color(0.96, 0.74, 0.26),
		"target": 520,
		"pos": Vector3(0.4, 0, 14.0),
		"color": Color(0.91, 0.76, 0.41)
	},
	{
		"id": "rim",
		"name": "Roman Empire",
		"name_cs": "Římská říše",
		"boss": "Julius Caesar",
		"boss_cs": "Julius Caesar",
		"skin_name": "Roman Legion Vambraces",
		"skin_name_cs": "Chrániče římské legie",
		"glove_col": Color(0.45, 0.14, 0.14),
		"border_col": Color(0.91, 0.44, 0.32),
		"target": 920,
		"pos": Vector3(-14.4, 0, 6.8),
		"color": Color(0.90, 0.43, 0.31)
	},
	{
		"id": "stredovek",
		"name": "Medieval Realm",
		"name_cs": "Středověké království",
		"boss": "King Charles IV",
		"boss_cs": "Král Karel IV.",
		"skin_name": "Knightly Iron Gauntlets",
		"skin_name_cs": "Rytířské železné rukavice",
		"glove_col": Color(0.24, 0.29, 0.35),
		"border_col": Color(0.58, 0.83, 0.69),
		"target": 1500,
		"pos": Vector3(-14.4, 0, -7.6),
		"color": Color(0.58, 0.83, 0.69)
	},
	{
		"id": "objavy",
		"name": "Age of Sail (Corsairs)",
		"name_cs": "Éra objevů a korzárů",
		"boss": "Pirate Queen Anne",
		"boss_cs": "Pirátská královna Anna",
		"skin_name": "Corsair Hook & Cuff",
		"skin_name_cs": "Korzárská manžeta",
		"glove_col": Color(0.10, 0.22, 0.33),
		"border_col": Color(0.30, 0.78, 0.94),
		"target": 2400,
		"pos": Vector3(8.4, 0, -11.6),
		"color": Color(0.30, 0.78, 0.94)
	},
	{
		"id": "prohibicia",
		"name": "1930s Prohibition",
		"name_cs": "Prohibice 30. let",
		"boss": "Al Capone",
		"boss_cs": "Al Capone",
		"skin_name": "Cosa Nostra Black Gloves",
		"skin_name_cs": "Černé mafiánské rukavice",
		"glove_col": Color(0.12, 0.12, 0.15),
		"border_col": Color(0.78, 0.49, 1.0),
		"target": 3800,
		"pos": Vector3(17.2, 0, 0.4),
		"color": Color(0.78, 0.49, 1.0)
	}
]

func _get_font(display: bool = false) -> Font:
	var p := FONT_DISPLAY_PATH if display else FONT_UI_PATH
	if ResourceLoader.exists(p):
		var f := load(p) as Font
		if f:
			return f
	return ThemeDB.fallback_font

func _get_quill_font() -> Font:
	if _cached_quill_font != null:
		return _cached_quill_font
	if ResourceLoader.exists(FONT_QUILL_PATH):
		var fq := load(FONT_QUILL_PATH) as Font
		if fq:
			_cached_quill_font = fq
			return fq
	if FileAccess.file_exists(FONT_QUILL_PATH):
		var raw_bytes := FileAccess.get_file_as_bytes(FONT_QUILL_PATH)
		if raw_bytes.size() > 0:
			var ff := FontFile.new()
			ff.data = raw_bytes
			_cached_quill_font = ff
			return ff
	return _get_font(false)

func _build_global_theme() -> Theme:
	var th := Theme.new()
	var ui_font := _get_font(false)
	var disp_font := _get_font(true)
	th.default_font = ui_font
	th.default_font_size = 18
	th.set_font("font", "Label", ui_font)
	th.set_font("font", "Button", disp_font)
	th.set_font_size("font_size", "Label", 18)
	th.set_font_size("font_size", "Button", 17)
	th.set_color("font_color", "Label", Color(0.95, 0.91, 0.82))
	th.set_color("font_color", "Button", Color(0.98, 0.92, 0.78))
	th.set_color("font_hover_color", "Button", Color(1.0, 0.88, 0.46))

	var b_norm := StyleBoxFlat.new()
	b_norm.bg_color = Color(0.14, 0.105, 0.085, 0.96)
	b_norm.border_color = Color(0.76, 0.58, 0.28, 0.94)
	b_norm.set_border_width_all(2)
	b_norm.border_width_bottom = 4
	b_norm.set_corner_radius_all(10)
	b_norm.content_margin_left = 16
	b_norm.content_margin_right = 16
	b_norm.content_margin_top = 9
	b_norm.content_margin_bottom = 10
	b_norm.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	b_norm.shadow_size = 6
	b_norm.shadow_offset = Vector2(0, 3)
	th.set_stylebox("normal", "Button", b_norm)

	var b_hov := b_norm.duplicate() as StyleBoxFlat
	b_hov.bg_color = Color(0.24, 0.175, 0.125, 0.98)
	b_hov.border_color = Color(1.0, 0.84, 0.38, 1.0)
	th.set_stylebox("hover", "Button", b_hov)

	var b_press := b_norm.duplicate() as StyleBoxFlat
	b_press.bg_color = Color(0.10, 0.075, 0.060, 1.0)
	b_press.border_width_bottom = 2
	b_press.content_margin_top = 11
	b_press.content_margin_bottom = 8
	th.set_stylebox("pressed", "Button", b_press)

	var b_dis := b_norm.duplicate() as StyleBoxFlat
	b_dis.bg_color = Color(0.09, 0.08, 0.075, 0.72)
	b_dis.border_color = Color(0.38, 0.32, 0.24, 0.55)
	th.set_stylebox("disabled", "Button", b_dis)
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.50, 0.44, 0.75))

	var pan := StyleBoxFlat.new()
	pan.bg_color = Color(0.08, 0.065, 0.055, 0.95)
	pan.border_color = Color(0.80, 0.62, 0.30, 0.95)
	pan.set_border_width_all(2)
	pan.set_corner_radius_all(12)
	pan.content_margin_left = 16
	pan.content_margin_right = 16
	pan.content_margin_top = 12
	pan.content_margin_bottom = 12
	th.set_stylebox("panel", "PanelContainer", pan)
	return th

func _setup_audio_engine() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = -6.0
	add_child(bgm_player)

	amb_player = AudioStreamPlayer.new()
	amb_player.volume_db = -13.0
	add_child(amb_player)

	splash_sfx_player = AudioStreamPlayer.new()
	splash_sfx_player.volume_db = -4.5
	add_child(splash_sfx_player)

	for b_layer in ["calm", "epic", "climax"]:
		var bp := AudioStreamPlayer.new()
		bp.volume_db = -80.0
		add_child(bp)
		battle_bgm_players[b_layer] = bp

	for _i in range(12):
		var sp := AudioStreamPlayer.new()
		sp.volume_db = -6.0
		add_child(sp)
		sfx_pool.append(sp)

	bgm_cache["lobby"] = _load_audio("res://assets/audio/bgm_lobby_znelka", true)
	bgm_cache["map"] = _load_audio("res://assets/audio/bgm_campaign_map", true)
	bgm_cache["battle"] = _load_audio("res://assets/audio/bgm_battle_tavern", true)
	bgm_cache["battle_calm"] = _load_audio("res://assets/audio/bgm_battle_calm", true)
	bgm_cache["battle_epic"] = _load_audio("res://assets/audio/bgm_battle_epic", true)
	# Intense-battle theme (snake theme) drives the climax layer; boss fights use it too.
	bgm_cache["battle_climax"] = _load_audio("res://assets/audio/bgm_battle_intense", true)
	if bgm_cache["battle_climax"] == null:
		bgm_cache["battle_climax"] = _load_audio("res://assets/audio/bgm_battle_climax", true)
	bgm_cache["battle_boss"] = _load_audio("res://assets/audio/bgm_battle_boss", true)
	if bgm_cache["battle_boss"] == null:
		bgm_cache["battle_boss"] = bgm_cache["battle_climax"]
	bgm_cache["amb_tavern"] = _load_audio("res://assets/audio/amb_tavern", true)

	for sfx_key in [
		"splash_fujara", "ui_hover", "ui_click", "card_hover",
		"card_shuffle", "card_deal", "card_throw_whoosh", "card_slam",
		"card_draw", "puf", "turn_player", "win", "lose", "error",
		"card_ace_strike", "card_seven_curse", "card_suit_shift", "card_shield_guard",
		"anim_sword_unsheathe", "anim_sword_slash", "anim_sword_cleave",
		"anim_parry_clang", "anim_combo_slam",
		"btn_wooden_slam", "btn_card_tick", "btn_ghost_curse"
	]:
		var st := _load_audio("res://assets/audio/sfx_%s" % sfx_key, false)
		if st:
			sfx_cache[sfx_key] = st

	_generate_procedural_sfx_wavs()

func _make_pcm16_wav(samples: PackedFloat32Array, mix_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	wav.data = bytes
	return wav

func _generate_procedural_sfx_wavs() -> void:
	var sr := 22050
	# 1. Polyphonic Tavern Lute + Harpsichord Stinger (dyad/triad with plucked overtone decay)
	var n_lute := int(sr * 0.34)
	var s_lute := PackedFloat32Array()
	s_lute.resize(n_lute)
	var freqs_lute := [220.0, 329.63, 440.0, 554.37, 659.25]
	var amps_lute := [0.34, 0.28, 0.24, 0.16, 0.12]
	for i in range(n_lute):
		var t := float(i) / float(sr)
		var env := minf(1.0, t / 0.004) * exp(-t * 10.5)
		var h_env := minf(1.0, t / 0.002) * exp(-t * 22.0)
		var sig := 0.0
		for k in range(freqs_lute.size()):
			var f: float = freqs_lute[k]
			var a: float = amps_lute[k]
			var delay_t := maxf(0.0, t - float(k) * 0.006)
			if delay_t > 0.0:
				var e_k := exp(-delay_t * (9.5 + float(k) * 2.2))
				sig += a * e_k * (sin(TAU * f * delay_t) + 0.35 * sin(TAU * f * 2.0 * delay_t) + 0.15 * sin(TAU * f * 3.0 * delay_t))
		# Crisp harpsichord quill pluck transient
		sig += h_env * 0.18 * sin(TAU * 1760.0 * t)
		s_lute[i] = sig * env * 0.85
	sfx_cache["chord_lute"] = _make_pcm16_wav(s_lute, sr)

	# 2. ON FIRE Overdrive Heartbeat + Crackling Tavern Flame Resonance
	var n_ov := int(sr * 0.52)
	var s_ov := PackedFloat32Array()
	s_ov.resize(n_ov)
	for i in range(n_ov):
		var t := float(i) / float(sr)
		# Lub-dub dual heartbeat thump + warm 5th flame drone
		var b1 := exp(-pow((t - 0.05) / 0.042, 2.0)) * sin(TAU * 58.0 * t)
		var b2 := 0.82 * exp(-pow((t - 0.19) / 0.048, 2.0)) * sin(TAU * 49.0 * t)
		var flame_drone := exp(-t * 3.8) * (0.28 * sin(TAU * 110.0 * t) + 0.22 * sin(TAU * 165.0 * t) + 0.14 * sin(TAU * 220.0 * t))
		var crackle := (sin(t * 4312.0) * cos(t * 7819.0)) * 0.08 * exp(-t * 5.0)
		s_ov[i] = (b1 * 0.55 + b2 * 0.50 + flame_drone + crackle) * 0.90
	sfx_cache["overdrive_hum"] = _make_pcm16_wav(s_ov, sr)

	# 3. Clickable Tavern Tankard Clink + Oak Thud
	var n_mug := int(sr * 0.28)
	var s_mug := PackedFloat32Array()
	s_mug.resize(n_mug)
	for i in range(n_mug):
		var t := float(i) / float(sr)
		var wood_thud := exp(-t * 28.0) * sin(TAU * 135.0 * t) * 0.55
		var pewter_ring := exp(-t * 14.0) * (0.35 * sin(TAU * 587.3 * t) + 0.25 * sin(TAU * 1174.6 * t) + 0.15 * sin(TAU * 1760.0 * t))
		s_mug[i] = (wood_thud + pewter_ring) * 0.85
	sfx_cache["prop_tankard"] = _make_pcm16_wav(s_mug, sr)

	# 4. Clickable Coin Stack Jingle (4 cascading silver/gold florin strikes)
	var n_coin := int(sr * 0.36)
	var s_coin := PackedFloat32Array()
	s_coin.resize(n_coin)
	var c_times := [0.0, 0.055, 0.115, 0.175]
	var c_freqs := [2349.3, 2793.8, 3136.0, 3951.1]
	for i in range(n_coin):
		var t := float(i) / float(sr)
		var sig := 0.0
		for k in range(4):
			var dt: float = t - c_times[k]
			if dt >= 0.0:
				var f: float = c_freqs[k]
				sig += exp(-dt * 24.0) * (0.32 * sin(TAU * f * dt) + 0.18 * sin(TAU * (f * 1.414) * dt))
		s_coin[i] = sig * 0.85
	sfx_cache["prop_coins"] = _make_pcm16_wav(s_coin, sr)

	# 5. Clickable Bone Dice Clatter (5 crisp wooden/bone bounces)
	var n_dice := int(sr * 0.32)
	var s_dice := PackedFloat32Array()
	s_dice.resize(n_dice)
	var d_hits := [0.0, 0.05, 0.105, 0.165, 0.23]
	for i in range(n_dice):
		var t := float(i) / float(sr)
		var sig := 0.0
		for k in range(d_hits.size()):
			var dt: float = t - d_hits[k]
			if dt >= 0.0 and dt < 0.045:
				var f := 620.0 + float(k) * 115.0
				sig += exp(-dt * 65.0) * (sin(TAU * f * dt) + 0.5 * sin(TAU * (f * 2.3) * dt)) * (1.0 - float(k) * 0.12)
		s_dice[i] = sig * 0.78
	sfx_cache["prop_dice"] = _make_pcm16_wav(s_dice, sr)

	# 6. Boss Modifier Omen Flare (Dark Gothic Low Brass Fifth)
	var n_boss := int(sr * 0.44)
	var s_boss := PackedFloat32Array()
	s_boss.resize(n_boss)
	for i in range(n_boss):
		var t := float(i) / float(sr)
		var env := minf(1.0, t / 0.025) * exp(-t * 5.2)
		var sig := 0.42 * sin(TAU * 73.42 * t) + 0.34 * sin(TAU * 110.0 * t) + 0.24 * sin(TAU * 146.83 * t) + 0.15 * sin(TAU * 220.0 * t)
		s_boss[i] = sig * env * 0.85
	sfx_cache["boss_omen"] = _make_pcm16_wav(s_boss, sr)

	# 7. Ghost Companion Speech Syllable (Warm Spectral Formant Blip)
	var n_ghost := int(sr * 0.085)
	var s_ghost := PackedFloat32Array()
	s_ghost.resize(n_ghost)
	for i in range(n_ghost):
		var t := float(i) / float(sr)
		var env := sin(PI * clampf(t / 0.085, 0.0, 1.0))
		var freq := 245.0 + sin(t * 48.0) * 38.0
		var sig := 0.55 * sin(TAU * freq * t) + 0.25 * sin(TAU * (freq * 2.0) * t) + 0.12 * sin(TAU * (freq * 3.0) * t)
		s_ghost[i] = sig * env * 0.42
	sfx_cache["ghost_speak"] = _make_pcm16_wav(s_ghost, sr)

	# 8. Goose-Quill Ink Scratch on Parchment (3 organic dry-nib whisper variations)
	for q_i in range(3):
		var q_dur := 0.052 + float(q_i) * 0.008
		var n_q := int(sr * q_dur)
		var s_q := PackedFloat32Array()
		s_q.resize(n_q)
		var seed_v := 713 + q_i * 977
		var prev_lp := 0.0
		var prev_bp := 0.0
		for i in range(n_q):
			var t := float(i) / float(sr)
			var u := clampf(t / q_dur, 0.0, 1.0)
			var env := sin(PI * pow(u, 0.65)) * exp(-u * 1.45)
			seed_v = int((seed_v * 1103515245 + 12345) & 0x7fffffff)
			var white := (float(seed_v % 20001) / 10000.0) - 1.0
			# Dual-band paper grain resonance (soft fiber rustle + subtle nib edge chirp)
			prev_lp = lerpf(prev_lp, white, 0.32)
			var hp := white - prev_lp
			prev_bp = lerpf(prev_bp, hp, 0.48)
			var grain := 0.42 * hp + 0.28 * prev_bp + 0.18 * sin(TAU * (1580.0 + float(q_i) * 210.0 + sin(u * PI * 3.0) * 320.0) * t)
			s_q[i] = clampf(grain * env * 0.56, -0.95, 0.95)
		var q_wav := _make_pcm16_wav(s_q, sr)
		sfx_cache["quill_scratch_%d" % q_i] = q_wav
		if q_i == 0:
			sfx_cache["quill_scratch"] = q_wav

func _load_audio(stem_or_path: String, loop: bool) -> AudioStream:
	var stem := stem_or_path.get_basename() if (stem_or_path.ends_with(".mp3") or stem_or_path.ends_with(".wav")) else stem_or_path
	var mp3_path := stem + ".mp3"
	if ResourceLoader.exists(mp3_path):
		var st_mp3 := load(mp3_path)
		if st_mp3 is AudioStreamMP3:
			(st_mp3 as AudioStreamMP3).loop = loop
			return st_mp3
	if FileAccess.file_exists(mp3_path):
		var raw := FileAccess.get_file_as_bytes(mp3_path)
		if not raw.is_empty():
			var mp3 := AudioStreamMP3.load_from_buffer(raw)
			if mp3:
				mp3.loop = loop
				return mp3
	return _load_wav(stem + ".wav", loop)

func _load_wav(path: String, loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st := load(path)
	if st is AudioStreamWAV:
		var wav := st as AudioStreamWAV
		if loop:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			var bytes_per_sample := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var chans := 2 if wav.stereo else 1
			if bytes_per_sample > 0 and chans > 0:
				wav.loop_end = int(wav.data.size() / (bytes_per_sample * chans))
		else:
			wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return st

func _calc_vol_db(base_db: float) -> float:
	if audio_muted or audio_volume_pct <= 0:
		return -80.0
	var lin := clampf(float(audio_volume_pct) / 100.0, 0.001, 1.0)
	return base_db + linear_to_db(lin)

func _notification(what: int) -> void:
	if "--script" in OS.get_cmdline_args():
		return
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT or what == Window.NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_on_window_focus_changed(false)
	elif what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN or what == Window.NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_window_focus_changed(true)

func _on_window_focus_changed(focused: bool) -> void:
	window_focused = focused
	var paused := not focused
	if is_instance_valid(bgm_player):
		bgm_player.stream_paused = paused
	if is_instance_valid(amb_player):
		amb_player.stream_paused = paused
	if is_instance_valid(splash_sfx_player):
		if focused and current_screen == ScreenState.SPLASH and (_splash_audio_pending or not splash_sfx_player.playing) and splash_time < 4.5 and sfx_cache.has("splash_fujara") and not audio_muted and audio_volume_pct > 0:
			splash_sfx_player.stream = sfx_cache["splash_fujara"]
			splash_sfx_player.volume_db = _calc_vol_db(-3.5)
			splash_sfx_player.stream_paused = false
			splash_sfx_player.play()
			_splash_audio_pending = false
		else:
			splash_sfx_player.stream_paused = paused
	for k in battle_bgm_players.keys():
		var bp: AudioStreamPlayer = battle_bgm_players[k]
		if is_instance_valid(bp):
			bp.stream_paused = paused
	for sp in sfx_pool:
		if is_instance_valid(sp):
			sp.stream_paused = paused
	_apply_audio_state()

func _apply_audio_state() -> void:
	var mute_bus := (not window_focused) or audio_muted or audio_volume_pct <= 0
	AudioServer.set_bus_mute(0, mute_bus)
	bgm_player.volume_db = _calc_vol_db(-5.5 if active_bgm_key == "lobby" else -6.5)
	amb_player.volume_db = _calc_vol_db(-12.5)
	if is_instance_valid(splash_sfx_player):
		splash_sfx_player.volume_db = _calc_vol_db(-4.5)
	if active_bgm_key == "battle":
		_apply_battle_layer_volumes()
	var is_off := (audio_muted or audio_volume_pct <= 0)
	var arrow_sym := "▴" if audio_drawer_open else "▾"
	for tb in audio_toggle_btns:
		if is_instance_valid(tb):
			tb.text = ("🔇 OFF %s" % arrow_sym) if is_off else ("🔊 %d%% %s" % [audio_volume_pct, arrow_sym])
	for mb in mute_buttons:
		if is_instance_valid(mb):
			mb.text = "🔇 Muted" if is_off else "🔊 Mute"
	for sl in audio_sliders:
		if is_instance_valid(sl) and int(round(sl.value)) != audio_volume_pct:
			sl.set_value_no_signal(float(audio_volume_pct))
	for lbl in audio_pct_labels:
		if is_instance_valid(lbl):
			lbl.text = "%d%%" % (0 if audio_muted else audio_volume_pct)
	for dr in audio_drawers:
		if is_instance_valid(dr):
			dr.visible = audio_drawer_open
	if battle_3d and battle_3d.has_method("set_audio_hud"):
		battle_3d.set_audio_hud(audio_muted, audio_volume_pct)

func _toggle_audio_drawer() -> void:
	audio_drawer_open = not audio_drawer_open
	_play_sfx("ui_hover", -8.0, 1.1)
	_apply_audio_state()

func _stop_battle_bgm_layers() -> void:
	for k in battle_bgm_players.keys():
		var bp: AudioStreamPlayer = battle_bgm_players[k]
		if is_instance_valid(bp):
			bp.stop()

func _has_layered_battle_bgm() -> bool:
	return (bgm_cache.get("battle_calm", null) != null) or (bgm_cache.get("battle_epic", null) != null)

func _apply_battle_layer_volumes() -> void:
	var has_calm: bool = bgm_cache.get("battle_calm", null) != null
	var has_epic: bool = bgm_cache.get("battle_epic", null) != null
	var has_climax: bool = bgm_cache.get("battle_climax", null) != null or bgm_cache.get("battle_boss", null) != null
	var x := clampf(battle_music_intensity, 0.0, 1.0)

	var w_calm := 0.0
	var w_epic := 0.0
	var w_climax := 0.0

	if has_calm and has_epic:
		if x < 0.48:
			var u := clampf(x / 0.48, 0.0, 1.0)
			w_calm = lerpf(1.0, 0.25, u)
			w_epic = lerpf(0.0, 0.85, u)
		elif x < 0.80 or not has_climax:
			var u := clampf((x - 0.48) / 0.32, 0.0, 1.0)
			w_calm = lerpf(0.25, 0.0, u)
			w_epic = lerpf(0.85, 1.0, u)
		else:
			var u := clampf((x - 0.80) / 0.20, 0.0, 1.0)
			w_epic = lerpf(1.0, 0.32, u)
			w_climax = lerpf(0.0, 1.0, u)
	elif has_epic:
		w_epic = 1.0
	elif has_calm:
		w_calm = 1.0

	var weights := {"calm": w_calm, "epic": w_epic, "climax": w_climax}
	for k in battle_bgm_players.keys():
		var bp: AudioStreamPlayer = battle_bgm_players[k]
		if not is_instance_valid(bp):
			continue
		var w := float(weights.get(k, 0.0))
		bp.volume_db = _calc_vol_db(-6.5 + linear_to_db(w)) if w > 0.015 else -80.0

func _update_battle_music_mix(delta: float) -> void:
	if active_bgm_key != "battle" or not _has_layered_battle_bgm():
		return
	var target_int := 0.0
	if battle_3d and is_instance_valid(battle_3d):
		var t_sc := maxf(1.0, float(battle_3d.target_score))
		var p_sc := float(battle_3d.player_score)
		var a_sc := float(battle_3d.ai_score)
		var progress := maxf(p_sc, a_sc) / t_sc
		var deficit_pressure := clampf((a_sc - p_sc) / (t_sc * 0.45), 0.0, 0.22)
		target_int = clampf(progress + deficit_pressure, 0.0, 1.0)
	battle_music_intensity = lerpf(battle_music_intensity, target_int, clampf(delta * 1.4, 0.0, 1.0))
	_apply_battle_layer_volumes()

func _play_bgm(key: String, with_tavern_amb: bool = false) -> void:
	active_bgm_key = key
	if not music_enabled:
		if bgm_player:
			bgm_player.stop()
		if amb_player:
			amb_player.stop()
		_stop_battle_bgm_layers()
		return
	if key == "":
		bgm_player.stop()
		_stop_battle_bgm_layers()
	elif key == "battle" and _has_layered_battle_bgm():
		bgm_player.stop()
		_stop_battle_bgm_layers()
		battle_music_intensity = 0.0
		var is_boss_stage := false
		if battle_3d and is_instance_valid(battle_3d):
			is_boss_stage = str(battle_3d.active_boss_mod) != "" or int(battle_3d.active_endless_ante) > 0
		var climax_stream: AudioStream = bgm_cache.get("battle_boss" if (is_boss_stage and bgm_cache.get("battle_boss", null) != null) else "battle_climax", null)
		if climax_stream == null:
			climax_stream = bgm_cache.get("battle_climax", null)
		var streams := {
			"calm": bgm_cache.get("battle_calm", null),
			"epic": bgm_cache.get("battle_epic", null),
			"climax": climax_stream,
		}
		for k in battle_bgm_players.keys():
			var bp: AudioStreamPlayer = battle_bgm_players[k]
			var st: AudioStream = streams.get(k, null)
			if is_instance_valid(bp) and st != null:
				bp.stream = st
				bp.stream_paused = not window_focused
				bp.play(0.0)
		_apply_battle_layer_volumes()
	elif bgm_cache.has(key) and bgm_cache[key]:
		_stop_battle_bgm_layers()
		bgm_player.stream = bgm_cache[key]
		bgm_player.volume_db = _calc_vol_db(-5.5 if key == "lobby" else -6.5)
		bgm_player.stream_paused = not window_focused
		bgm_player.play()
	if with_tavern_amb and bgm_cache.has("amb_tavern") and bgm_cache["amb_tavern"]:
		if not amb_player.playing or amb_player.stream != bgm_cache["amb_tavern"]:
			amb_player.stream = bgm_cache["amb_tavern"]
			amb_player.volume_db = _calc_vol_db(-12.5)
			amb_player.stream_paused = not window_focused
			amb_player.play()
	elif not with_tavern_amb:
		amb_player.stop()

func _play_sfx(key: String, vol_db: float = -5.5, pitch: float = 1.0) -> void:
	if key == "overdrive_hum" and not music_enabled:
		return
	var resolved_key := key
	if key == "quill_scratch":
		var q_cand := "quill_scratch_%d" % (randi() % 3)
		if sfx_cache.has(q_cand):
			resolved_key = q_cand
	if not window_focused or audio_muted or audio_volume_pct <= 0 or not sfx_cache.has(resolved_key) or sfx_pool.is_empty():
		return
	var p: AudioStreamPlayer = sfx_pool[sfx_pool_idx]
	sfx_pool_idx = (sfx_pool_idx + 1) % sfx_pool.size()
	p.stream = sfx_cache[resolved_key]
	p.volume_db = _calc_vol_db(vol_db)
	p.pitch_scale = pitch
	p.stream_paused = false
	p.play()

func _toggle_audio_mute() -> void:
	audio_muted = not audio_muted
	if not audio_muted and audio_volume_pct <= 0:
		audio_volume_pct = 50
	_apply_audio_state()
	if not audio_muted:
		_play_sfx("ui_click", -6.0)

func _set_audio_volume(pct: int) -> void:
	audio_volume_pct = clampi(pct, 0, 100)
	if audio_volume_pct > 0 and audio_muted:
		audio_muted = false
	_apply_audio_state()

func _create_audio_control_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.90)
	sb.border_color = Color(0.76, 0.58, 0.26, 0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pill.add_child(h)

	var drawer := HBoxContainer.new()
	drawer.add_theme_constant_override("separation", 8)
	drawer.visible = audio_drawer_open
	audio_drawers.append(drawer)
	h.add_child(drawer)

	var mute_b := Button.new()
	mute_b.text = "🔇 Muted" if (audio_muted or audio_volume_pct <= 0) else "🔊 Mute"
	mute_b.custom_minimum_size = Vector2(82, 30)
	mute_b.add_theme_font_size_override("font_size", 14)
	mute_b.pressed.connect(_toggle_audio_mute)
	mute_buttons.append(mute_b)
	drawer.add_child(mute_b)

	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 100.0
	sl.step = 5.0
	sl.value = float(audio_volume_pct)
	sl.custom_minimum_size = Vector2(104, 24)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grab_sb := StyleBoxFlat.new()
	grab_sb.bg_color = Color(0.24, 0.19, 0.14)
	grab_sb.border_color = Color(0.86, 0.68, 0.28)
	grab_sb.set_border_width_all(1)
	grab_sb.set_corner_radius_all(4)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.88, 0.68, 0.24)
	fill_sb.set_corner_radius_all(4)
	sl.add_theme_stylebox_override("slider", grab_sb)
	sl.add_theme_stylebox_override("grabber_area", fill_sb)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill_sb)
	sl.value_changed.connect(func(val: float): _set_audio_volume(int(round(val))))
	audio_sliders.append(sl)
	drawer.add_child(sl)

	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % (0 if audio_muted else audio_volume_pct)
	pct_lbl.custom_minimum_size = Vector2(44, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct_lbl.add_theme_font_size_override("font_size", 15)
	pct_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.56))
	audio_pct_labels.append(pct_lbl)
	drawer.add_child(pct_lbl)

	var toggle_btn := Button.new()
	var is_off := (audio_muted or audio_volume_pct <= 0)
	var arr := "▴" if audio_drawer_open else "▾"
	toggle_btn.text = ("🔇 OFF %s" % arr) if is_off else ("🔊 %d%% %s" % [audio_volume_pct, arr])
	toggle_btn.custom_minimum_size = Vector2(102, 30)
	toggle_btn.add_theme_font_size_override("font_size", 14)
	toggle_btn.pressed.connect(_toggle_audio_drawer)
	audio_toggle_btns.append(toggle_btn)
	h.add_child(toggle_btn)
	return pill

func _create_mute_button() -> PanelContainer:
	return _create_audio_control_pill()

func _ready() -> void:
	if get_viewport():
		get_viewport().msaa_3d = Viewport.MSAA_4X
	game_theme = _build_global_theme()
	map_woodcut_layer = CanvasLayer.new()
	map_woodcut_layer.layer = 0
	map_woodcut_layer.visible = false
	add_child(map_woodcut_layer)
	var map_wc_rect := ColorRect.new()
	map_wc_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_wc_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_wc_rect.color = Color(1, 1, 1, 1)
	map_woodcut_mat = ShaderMaterial.new()
	map_woodcut_mat.shader = WOODCUT_POST_SHADER
	map_woodcut_mat.set_shader_parameter("print_mode", woodcut_mode)
	map_woodcut_mat.set_shader_parameter("edge_strength", 0.62)
	map_woodcut_mat.set_shader_parameter("hatch_strength", 0.38)
	map_woodcut_mat.set_shader_parameter("vignette_strength", 0.48)
	map_wc_rect.material = map_woodcut_mat
	map_woodcut_layer.add_child(map_wc_rect)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	_setup_audio_engine()
	game_options = Catalog.load_options()
	woodcut_mode = int(game_options.get("visual_mode", 3))
	audio_volume_pct = int(game_options.get("sfx_volume", 85))
	audio_muted = bool(game_options.get("muted", false))
	if map_woodcut_mat:
		map_woodcut_mat.set_shader_parameter("print_mode", woodcut_mode)
	if bool(game_options.get("fullscreen", true)) and DisplayServer.get_name() != "headless" and not ("--script" in OS.get_cmdline_args()):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if DisplayServer.get_name() != "headless" and not ("--script" in OS.get_cmdline_args()):
		var win := get_window()
		if win:
			win.focus_entered.connect(func(): _on_window_focus_changed(true))
			win.focus_exited.connect(func(): _on_window_focus_changed(false))
			window_focused = win.has_focus()
	run_profile = Catalog.load_profile()
	shop_offers = Catalog.generate_shop_offers(run_profile, str(game_options.get("language", "en")))
	card_back_tex = Toon.tex(str(PLAYER_DECKS[selected_deck_idx].get("back_tex", "res://assets/table/card_back.png")))
	menu_icons_tex = Toon.tex("res://assets/lobby/menu_icons.png")
	_preload_custom_card_faces()

	_build_splash_screen()
	_build_main_menu()
	_build_3d_world()
	_build_3d_hud()

	battle_3d = BattleTable3DScript.new()
	battle_3d.position = Vector3(500.0, 0.0, 500.0)
	battle_3d.exit_to_map_requested.connect(func():
		_play_sfx("ui_click")
		_switch_to(ScreenState.WORLD_3D)
	)
	battle_3d.battle_won.connect(func(_pts: int):
		player_level += 1
		_populate_menu_signs()
	)
	battle_3d.match_won_details.connect(_on_match_won_details)
	if battle_3d.has_signal("match_lost_details"):
		battle_3d.match_lost_details.connect(_on_match_lost_details)
	if battle_3d.has_signal("play_sfx_requested"):
		battle_3d.play_sfx_requested.connect(func(sname: String):
			var v := -5.0
			match sname:
				"card_hover":
					v = -11.5
				"btn_card_tick":
					v = -8.0
				"btn_wooden_slam":
					v = -5.5
				"card_ace_strike", "anim_parry_clang":
					v = -3.5
			_play_sfx(sname, v, randf_range(0.96, 1.04))
		)
	if battle_3d.has_signal("play_sfx_pitched_requested"):
		battle_3d.play_sfx_pitched_requested.connect(func(sname: String, pitch_val: float):
			_play_sfx(sname, -4.5, pitch_val)
		)
	if battle_3d.has_signal("toggle_mute_requested"):
		battle_3d.toggle_mute_requested.connect(_toggle_audio_mute)
	if battle_3d.has_signal("volume_changed_requested"):
		battle_3d.volume_changed_requested.connect(_set_audio_volume)
	if battle_3d.has_signal("print_mode_changed"):
		battle_3d.print_mode_changed.connect(func(nm: int): _apply_woodcut_mode(nm, false))
	if battle_3d.has_signal("open_options_requested"):
		battle_3d.open_options_requested.connect(func():
			_play_sfx("ui_click")
			_open_options_modal()
		)
	battle_3d.set_print_mode(woodcut_mode)
	if battle_3d.has_method("apply_options"):
		battle_3d.apply_options(game_options)
	add_child(battle_3d)
	if battle_3d.hud_root:
		battle_3d.hud_root.theme = game_theme

	# Plynulý prechodový závoj medzi obrazovkami (pri prekliknutí tlačidla šípkou)
	transition_curtain = ColorRect.new()
	transition_curtain.color = Color(0.03, 0.05, 0.04, 0.0)
	transition_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_curtain.visible = false
	ui_layer.add_child(transition_curtain)

	_apply_audio_state()
	var is_headless_run := (DisplayServer.get_name() == "headless") or ("--script" in OS.get_cmdline_args())
	if is_headless_run:
		_switch_to(ScreenState.SPLASH)
	else:
		# Launch Ouroboros 2D woodcut loading screen before Fujira splash
		var loader := SnakeLoadingScreenScript.new()
		loader.volume_db = -80.0 if (audio_muted or audio_volume_pct <= 0) else (-4.0 + linear_to_db(clampf(float(audio_volume_pct) / 100.0, 0.05, 1.0)))
		add_child(loader)
		loader.finished.connect(func():
			_switch_to(ScreenState.SPLASH)
		)

func _preload_custom_card_faces() -> void:
	for s in LOBBY_SUITS:
		for r in LOBBY_RANKS:
			var key := "%s_%s" % [s["id"], r]
			var tex := Toon.tex("res://assets/cards/%s.png" % key)
			if tex:
				card_face_cache[key] = tex
	for pc in Catalog.POWER_CARDS:
		var pc_id := str(pc.get("id", ""))
		if pc_id != "":
			var ptex := Toon.tex("res://assets/cards/%s.png" % pc_id)
			if ptex:
				card_face_cache[pc_id] = ptex
	for d_raw in PLAYER_DECKS:
		var did := str(d_raw.get("id", ""))
		var bp := str(d_raw.get("back_tex", ""))
		if did != "" and bp != "":
			var dtex := Toon.tex(bp)
			if dtex:
				card_face_cache["DECK_" + did] = dtex
	intro_handdrawn_tex = Toon.tex("res://assets/ui/intro_krivan_handdrawn.png")
	lobby_handdrawn_tex = Toon.tex("res://assets/ui/lobby_tavern_handdrawn.png")
	lobby_king_sheet_tex = Toon.tex("res://assets/lobby/duel_sprites/lobby_king_sheet.png")
	lobby_halberdier_sheet_tex = Toon.tex("res://assets/lobby/duel_sprites/lobby_halberdier_sheet.png")
	lobby_jester_sheet_tex = Toon.tex("res://assets/lobby/duel_sprites/lobby_jester_sheet.png")
	lobby_phoenix_sheet_tex = Toon.tex("res://assets/lobby/duel_sprites/lobby_phoenix_sheet.png")
	lobby_slash_fx_tex = Toon.tex("res://assets/vfx/sword_card/slash_cel_sheet.png")
	lobby_sparks_fx_tex = Toon.tex("res://assets/vfx/sword_card/ink_sparks_sheet.png")
	for ek in ["CERVEN_K", "ZALUD_H", "SPEC_JESTER", "SPEC_PHOENIX"]:
		var etex := Toon.tex("res://assets/lobby/duel_sprites/empty_%s.png" % ek)
		if etex:
			lobby_empty_cards[ek] = etex
	for sk in ["CERVEN", "ZALUD", "GULA", "ZELEN"]:
		var stex := Toon.tex("res://assets/ui/suits/suit_%s.png" % sk.to_lower())
		if stex:
			suit_crest_cache[sk] = stex

func _switch_to(next_state: ScreenState) -> void:
	var prev_state := current_screen
	current_screen = next_state
	splash_control.visible = (next_state == ScreenState.SPLASH)
	if is_instance_valid(splash_3d_vp):
		splash_3d_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if (next_state == ScreenState.SPLASH) else SubViewport.UPDATE_DISABLED
	menu_control.visible = (next_state == ScreenState.MAIN_MENU)
	if next_state != ScreenState.SPLASH and is_instance_valid(splash_sfx_player):
		splash_sfx_player.stop()
	if next_state == ScreenState.SPLASH:
		_play_bgm("", false)
		_splash_audio_pending = false
		if is_instance_valid(splash_sfx_player) and sfx_cache.has("splash_fujara") and not audio_muted and audio_volume_pct > 0:
			splash_sfx_player.stream = sfx_cache["splash_fujara"]
			splash_sfx_player.volume_db = _calc_vol_db(-3.5)
			splash_sfx_player.stream_paused = not window_focused
			splash_sfx_player.play()
			if not window_focused:
				_splash_audio_pending = true
	elif next_state == ScreenState.MAIN_MENU:
		_play_bgm("lobby", false)
		if prev_state != ScreenState.MAIN_MENU:
			_play_menu_entrance(prev_state == ScreenState.SPLASH)

	var in_map := (next_state == ScreenState.WORLD_3D)
	world_3d_root.visible = in_map
	if map_woodcut_layer:
		map_woodcut_layer.visible = in_map
	hud_3d_control.visible = in_map
	cam_3d.current = in_map
	if world_env_node:
		world_env_node.environment.fog_enabled = false
	if in_map:
		_play_bgm("map", false)
		_refresh_map_roguelite_hud()
		_update_campaign_card(selected_era_idx)
		_play_map_opening_animations()
		if pending_post_match_shop:
			pending_post_match_shop = false
			_open_shop_modal(true)

	var in_match := (next_state == ScreenState.MATCH_3D)
	battle_3d.set_active(in_match)
	if in_match:
		_play_bgm("battle", true)

func _build_roguelite_loadout_for_era(era: Dictionary, is_quick_showcase: bool = false) -> Dictionary:
	var e_id: String = str(era.get("id", "stredovek"))
	var stages: Array = Catalog.ERA_STAGES.get(e_id, [])
	var st_map: Dictionary = run_profile.get("era_stage", {})
	var st_idx := clampi(int(st_map.get(e_id, 0)), 0, maxi(0, stages.size() - 1))
	var st_data: Dictionary = stages[st_idx] if not stages.is_empty() else {"stage_idx": 0, "stage_name": era.get("boss", "Rival"), "boss_mod": "", "boss_desc": "", "target_mult": 1.0, "gold": 45}
	var asc := clampi(int(run_profile.get("ascension", 1)), 1, Catalog.MAX_ASCENSION)

	if is_quick_showcase:
		# Loaded Quick Table showcase so player immediately experiences Power Cards, Relics & Three-Tier Scoring!
		var q_cards: Array = []
		for cc_raw in run_profile.get("custom_cards", []):
			var cid := str(cc_raw)
			if not (cid in Catalog.ARCHIVED_CARD_IDS) and not Catalog.get_power_card(cid).is_empty():
				q_cards.append(cid)
		for sc in ["SPEC_VAMPIRE", "SPEC_STORM", "SPEC_MIRROR", "SPEC_CHRONOS", "SPEC_JESTER"]:
			if not (sc in q_cards):
				q_cards.append(sc)
		var q_rel: Array = []
		for ar_raw in run_profile.get("active_relics", []):
			var rid := str(ar_raw)
			if not (rid in Catalog.ARCHIVED_RELIC_IDS) and not Catalog.is_relic_hidden(rid) and not Catalog.get_relic(rid).is_empty():
				if not (rid in q_rel):
					q_rel.append(rid)
		for sr in ["REL_GREED", "REL_FANG", "REL_FUJARA"]:
			if not (sr in q_rel) and not Catalog.is_relic_hidden(sr):
				q_rel.append(sr)
		var q_ed: Dictionary = run_profile.get("card_editions", {}).duplicate()
		q_ed["CERVEN_E"] = "MAGE"
		q_ed["ZELEN_7"] = "THIEF"
		q_ed["GULA_K"] = "KNIGHT"
		q_ed["ZALUD_K"] = "MERCHANT"
		return {
			"custom_cards": q_cards,
			"active_relics": q_rel,
			"broken_relics": run_profile.get("broken_relics", []).duplicate(),
			"table_relics": run_profile.get("table_relics", ["TRELIC_BLOOD_SEAL", "TRELIC_STAR_BOW"]).duplicate(),
			"card_editions": q_ed,
			"removed_cards": run_profile.get("removed_cards", []).duplicate(),
			"added_cards": run_profile.get("added_cards", []).duplicate(),
			"suit_overrides": run_profile.get("suit_overrides", {}).duplicate(),
			"relic_scales": run_profile.get("relic_scales", {}).duplicate(),
			"shop_rerolls": int(run_profile.get("shop_rerolls", 0)),
			"endless_ante": 0,
			"stage_data": {"stage_idx": 1, "stage_name": _tr("Quick Duel Showcase", "Rychlý duel"), "stage_name_cs": "Rychlý duel", "boss_mod": "", "boss_desc": "", "boss_desc_cs": "", "gold": 55},
			"target_score": int(era.get("target", 1800)),
			"equipped_sword": str(run_profile.get("equipped_sword", "SWORD_IRON")),
			"player_gold": int(run_profile.get("gold", 0)),
			"language": str(game_options.get("language", "en")),
		}

	var e_ante := 0
	var scaled_goal := 0
	var diff_mode := str(run_profile.get("campaign_difficulty", "traveler"))
	var bless_cnt := clampi(int(run_profile.get("retry_blessing", 0)), 0, 3)
	var lang_code := str(game_options.get("language", "en"))
	if endless_mode_selected and bool(run_profile.get("endless_unlocked", false)):
		e_ante = maxi(1, int(run_profile.get("endless_ante", 1)))
		st_data = Catalog.get_endless_stage_data(e_ante, asc, lang_code)
		scaled_goal = int(st_data["target_score"])
	else:
		st_data = st_data.duplicate()
		scaled_goal = Catalog.compute_target_score(e_id, st_idx, asc, 0, diff_mode)

	var active_rel_clean: Array = []
	for ar_raw in run_profile.get("active_relics", []):
		var rid := str(ar_raw)
		if not (rid in Catalog.ARCHIVED_RELIC_IDS) and not Catalog.is_relic_hidden(rid) and not Catalog.get_relic(rid).is_empty():
			active_rel_clean.append(rid)

	return {
		"custom_cards": run_profile.get("custom_cards", []).duplicate(),
		"active_relics": active_rel_clean,
		"broken_relics": run_profile.get("broken_relics", []).duplicate(),
		"table_relics": run_profile.get("table_relics", ["TRELIC_BLOOD_SEAL", "TRELIC_STAR_BOW"]).duplicate(),
		"card_editions": run_profile.get("card_editions", {}).duplicate(),
		"removed_cards": run_profile.get("removed_cards", []).duplicate(),
		"added_cards": run_profile.get("added_cards", []).duplicate(),
		"suit_overrides": run_profile.get("suit_overrides", {}).duplicate(),
		"relic_scales": run_profile.get("relic_scales", {}).duplicate(),
		"shop_rerolls": int(run_profile.get("shop_rerolls", 0)),
		"endless_ante": e_ante,
		"stage_data": st_data,
		"target_score": scaled_goal,
		"equipped_sword": str(run_profile.get("equipped_sword", "SWORD_IRON")),
		"player_gold": int(run_profile.get("gold", 0)),
		"campaign_difficulty": diff_mode,
		"retry_blessing": bless_cnt,
		"language": str(game_options.get("language", "en")),
	}

func _sync_broken_relics_from_details(details: Dictionary) -> void:
	if details.has("broken_relics") and details["broken_relics"] is Array:
		var br_clean: Array = []
		for br_v in details["broken_relics"]:
			var br_s := str(br_v)
			if br_s != "" and not (br_s in br_clean):
				br_clean.append(br_s)
		run_profile["broken_relics"] = br_clean

func _on_match_won_details(details: Dictionary) -> void:
	var earned := int(details.get("gold_earned", 40)) + int(details.get("duel_gold_delta", 0))
	var e_id: String = str(details.get("era_id", "stredovek"))
	run_profile["gold"] = maxi(0, int(run_profile.get("gold", 0)) + earned)
	for tid_v in details.get("table_relics", []):
		Catalog.grant_table_relic(run_profile, str(tid_v))
	_sync_broken_relics_from_details(details)
	run_profile["retry_blessing"] = 0
	pending_post_loss_spoils.clear()
	run_profile["total_wins"] = int(run_profile.get("total_wins", 0)) + 1
	run_profile["best_slam"] = maxi(int(run_profile.get("best_slam", 0)), int(details.get("best_slam", 0)))

	# Persist permanent scaling Relic growth across runs
	var d_scales: Variant = details.get("relic_scales", {})
	if d_scales is Dictionary and not d_scales.is_empty():
		var cur_scales: Dictionary = run_profile.get("relic_scales", {})
		for sk in d_scales.keys():
			cur_scales[sk] = d_scales[sk]
		run_profile["relic_scales"] = cur_scales

	var st_map_pre: Dictionary = run_profile.get("era_stage", {})
	var won_stage_idx := int(details.get("stage_idx", int(st_map_pre.get(e_id, 0))))
	var is_tut_match := bool(details.get("is_tutorial", false)) or e_id == "tutorial"

	var won_ante := int(details.get("endless_ante", 0))
	if won_ante >= 1:
		run_profile["endless_ante"] = maxi(1, won_ante) + 1
	else:
		var st_map: Dictionary = run_profile.get("era_stage", {})
		var cur_st := int(st_map.get(e_id, 0))
		if cur_st >= 2:
			var clr: Dictionary = run_profile.get("era_cleared", {})
			clr[e_id] = true
			run_profile["era_cleared"] = clr
			st_map[e_id] = 0
			# Check if all 5 Eras cleared -> Unlock Endless Mode Epoch 6+ & Ascension Tier Up (1..10)!
			var all_cleared := true
			for er in ERAS_DATA:
				if not bool(clr.get(er["id"], false)):
					all_cleared = false
					break
			if all_cleared:
				run_profile["endless_unlocked"] = true
				run_profile["endless_ante"] = maxi(1, int(run_profile.get("endless_ante", 0)))
				var next_asc := mini(Catalog.MAX_ASCENSION, int(run_profile.get("ascension", 1)) + 1)
				run_profile["ascension"] = next_asc
				run_profile["highest_ascension"] = mini(Catalog.MAX_ASCENSION, maxi(int(run_profile.get("highest_ascension", 1)), next_asc))
				for er in ERAS_DATA:
					clr[er["id"]] = false
				run_profile["era_cleared"] = clr
		else:
			st_map[e_id] = cur_st + 1
		run_profile["era_stage"] = st_map

	last_victory_info = details.duplicate()
	var new_unlocks: Array[Dictionary] = []
	if not is_tut_match:
		new_unlocks = Catalog.claim_stage_unlocks(run_profile, e_id, won_stage_idx, true)
	last_victory_info["new_unlocks"] = new_unlocks
	# Unlock up to 2 still-locked cards into player's Card Collection after each victory!
	var lock_pool: Array[String] = []
	var ul_now: Array = run_profile.get("unlocked_cards", Catalog.DEFAULT_UNLOCKED_CARDS)
	for ls in LOBBY_SUITS:
		for lr in LOBBY_RANKS:
			var ck := "%s_%s" % [ls["id"], lr]
			if not (ck in ul_now):
				lock_pool.append(ck)
	for pc in Catalog.POWER_CARDS:
		var pk := str(pc["id"])
		if not (pk in ul_now):
			lock_pool.append(pk)
	lock_pool.shuffle()
	for ui in range(mini(2, lock_pool.size())):
		Catalog.unlock_card(run_profile, lock_pool[ui])

	shop_offers = Catalog.generate_shop_offers(run_profile, str(game_options.get("language", "en")))
	pending_post_match_shop = true
	Catalog.save_profile(run_profile)

func _on_match_lost_details(details: Dictionary) -> void:
	var st_gold := maxi(50, int(details.get("stage_gold", 90)))
	var consolation_gold := maxi(35, int(round(float(st_gold) * 0.60)))
	run_profile["gold"] = maxi(0, int(run_profile.get("gold", 0)) + consolation_gold)
	for tid_v in details.get("table_relics", []):
		Catalog.grant_table_relic(run_profile, str(tid_v))
	_sync_broken_relics_from_details(details)
	var next_bless := clampi(int(run_profile.get("retry_blessing", 0)) + 1, 1, 3)
	run_profile["retry_blessing"] = next_bless

	# Fail-Forward Free Card Class Forge!
	var ce: Dictionary = run_profile.get("card_editions", {})
	var cands := ["CERVEN_K", "GULA_E", "ZALUD_E", "ZELEN_E", "GULA_K", "ZALUD_K", "CERVEN_H", "ZELEN_8", "CERVEN_8"]
	var forged_k := ""
	for ck in cands:
		if not ce.has(ck):
			ce[ck] = "KNIGHT"
			forged_k = ck
			break
	if forged_k == "":
		forged_k = cands[randi() % cands.size()]
		ce[forged_k] = "MAGE"
	run_profile["card_editions"] = ce

	pending_post_loss_spoils = {
		"gold": consolation_gold,
		"upgraded_card": "%s (%s)" % [forged_k, str(ce[forged_k])],
		"blessing": next_bless,
	}
	last_victory_info.clear()
	shop_offers = Catalog.generate_shop_offers(run_profile, str(game_options.get("language", "en")))
	pending_post_match_shop = true
	Catalog.save_profile(run_profile)

func _launch_era_battle(era_idx: int, force_tutorial: bool = false) -> void:
	var idx := clampi(era_idx, 0, ERAS_DATA.size() - 1)
	var era: Dictionary = ERAS_DATA[idx]
	var run_tut := force_tutorial or not first_battle_tutorial_done
	first_battle_tutorial_done = true
	var loadout := {} if run_tut else _build_roguelite_loadout_for_era(era, false)
	if not run_tut:
		loadout["profile"] = run_profile
	battle_3d.start_3d_battle(era, PLAYER_DECKS[selected_deck_idx], run_tut, loadout)
	_switch_to(ScreenState.MATCH_3D)

# ============================================================================
# 1. EPICKÉ INTRO: FUJIRA STUDIOS (Vystúpi hora -> Zasneží -> Kamzíky & iskry)
# ============================================================================
func _load_glb_scene(res_path: String) -> Node3D:
	if ResourceLoader.exists(res_path):
		var packed := load(res_path) as PackedScene
		if packed:
			var inst := packed.instantiate()
			if inst is Node3D:
				return inst as Node3D
	if FileAccess.file_exists(res_path):
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		var abs_path := ProjectSettings.globalize_path(res_path)
		if gltf.append_from_file(abs_path, state) == OK:
			var gen := gltf.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
	return null


func _apply_mat_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for ch in node.get_children():
		_apply_mat_recursive(ch, mat)


func _attach_outline_to_surfaces(node: Node, outline_mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for si in range(mi.mesh.get_surface_count()):
				var base_mat := mi.get_active_material(si)
				if base_mat != null:
					var m_copy := base_mat.duplicate() as Material
					m_copy.next_pass = outline_mat
					mi.set_surface_override_material(si, m_copy)
	for ch in node.get_children():
		_attach_outline_to_surfaces(ch, outline_mat)


func _find_anim_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for ch in node.get_children():
		var found := _find_anim_player_recursive(ch)
		if found != null:
			return found
	return null


func _build_splash_screen() -> void:
	splash_control = Control.new()
	splash_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_control.theme = game_theme
	ui_layer.add_child(splash_control)

	# 1. Back layer: sunrise parchment sky + rising sun behind the 3D mountain
	splash_sky_canvas = Control.new()
	splash_sky_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_sky_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_sky_canvas.draw.connect(_draw_splash_sky)
	splash_control.add_child(splash_sky_canvas)

	# 2. Middle layer: isolated 3D SubViewport clipped cleanly along the 0.62 horizon line!
	splash_3d_container = SubViewportContainer.new()
	splash_3d_container.anchor_left = 0.0
	splash_3d_container.anchor_top = 0.0
	splash_3d_container.anchor_right = 1.0
	splash_3d_container.anchor_bottom = 0.62
	splash_3d_container.stretch = true
	splash_3d_container.clip_contents = true
	splash_3d_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_control.add_child(splash_3d_container)

	splash_3d_vp = SubViewport.new()
	splash_3d_vp.transparent_bg = true
	splash_3d_vp.own_world_3d = true
	splash_3d_vp.msaa_3d = Viewport.MSAA_4X
	splash_3d_vp.size = Vector2i(1280, 446)
	splash_3d_container.add_child(splash_3d_vp)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.62, 0.52)
	env.ambient_light_energy = 0.54
	we.environment = env
	splash_3d_vp.add_child(we)

	splash_3d_sun = DirectionalLight3D.new()
	splash_3d_sun.light_color = Color(1.0, 0.86, 0.62)
	splash_3d_sun.light_energy = 1.12
	splash_3d_sun.rotation_degrees = Vector3(-28.0, 52.0, 0.0)
	splash_3d_sun.shadow_enabled = true
	splash_3d_vp.add_child(splash_3d_sun)

	var fill_sun := DirectionalLight3D.new()
	fill_sun.light_color = Color(0.54, 0.68, 0.92)
	fill_sun.light_energy = 0.28
	fill_sun.rotation_degrees = Vector3(-42.0, -125.0, 0.0)
	fill_sun.shadow_enabled = false
	splash_3d_vp.add_child(fill_sun)

	# Golden sunrise rim backlight catching snow crests and leaping 3D chamois silhouettes
	splash_3d_rim_light = DirectionalLight3D.new()
	splash_3d_rim_light.light_color = Color(1.0, 0.78, 0.40)
	splash_3d_rim_light.light_energy = 0.85
	splash_3d_rim_light.rotation_degrees = Vector3(14.0, 162.0, 0.0)
	splash_3d_rim_light.shadow_enabled = false
	splash_3d_vp.add_child(splash_3d_rim_light)

	splash_3d_cam = Camera3D.new()
	splash_3d_cam.fov = 26.5
	splash_3d_cam.position = Vector3(0.0, 0.72, 8.35)
	splash_3d_vp.add_child(splash_3d_cam)
	splash_3d_cam.look_at(Vector3(0.0, 1.36, 0.0), Vector3.UP)

	splash_mtn_mat = ShaderMaterial.new()
	splash_mtn_mat.shader = MOUNTAIN_SHADER
	splash_mtn_mat.set_shader_parameter("rock_tint", Color(0.86, 0.44, 0.20))
	var rock_tex := Toon.tex("res://assets/map/mountain_rock.png")
	if rock_tex:
		splash_mtn_mat.set_shader_parameter("rock_tex", rock_tex)
	splash_mtn_mat.set_shader_parameter("uv_scale", Vector2(2.6, 2.6))
	splash_mtn_mat.set_shader_parameter("peak_height", 3.06)
	splash_mtn_mat.set_shader_parameter("snow_line_ratio", 1.28)
	splash_mtn_mat.set_shader_parameter("snow_col", Color(0.96, 0.94, 0.90))
	splash_mtn_mat.set_shader_parameter("snow_shadow_col", Color(0.50, 0.62, 0.80))
	splash_mtn_mat.set_shader_parameter("snow_sun_tint", Color(1.0, 0.95, 0.84))
	splash_mtn_mat.set_shader_parameter("wind_drift_strength", 0.62)
	splash_mtn_mat.set_shader_parameter("sparkle_strength", 0.60)
	splash_mtn_mat.set_shader_parameter("snow_time", 0.0)
	splash_mtn_mat.set_shader_parameter("shadow_tint", Color(0.42, 0.24, 0.20))
	splash_mtn_mat.set_shader_parameter("band_soft", 0.055)
	var m_outline := ShaderMaterial.new()
	m_outline.shader = preload("res://shaders/outline.gdshader")
	m_outline.set_shader_parameter("thickness", 0.022)
	splash_mtn_mat.next_pass = m_outline

	var loaded_mtn := _load_glb_scene("res://assets/models/krivan_intro_massif.glb")
	if loaded_mtn != null:
		splash_mtn_root = loaded_mtn
		_apply_mat_recursive(splash_mtn_root, splash_mtn_mat)
	else:
		splash_mtn_root = Node3D.new()
		var fb := MeshInstance3D.new()
		fb.mesh = _build_jagged_peak_mesh(0.28, 2.2, 2.65, 16, 42)
		fb.material_override = splash_mtn_mat
		splash_mtn_root.add_child(fb)
	splash_mtn_root.position = Vector3(0.0, -3.0, 0.0)
	splash_3d_vp.add_child(splash_mtn_root)

	# 3D fine summit micro-snow & drifting mist particles
	splash_3d_snow_particles = GPUParticles3D.new()
	splash_3d_snow_particles.amount = 110
	splash_3d_snow_particles.lifetime = 3.2
	splash_3d_snow_particles.emitting = false
	splash_3d_snow_particles.position = Vector3(-0.2, 2.55, 0.55)
	var snow_pm := ParticleProcessMaterial.new()
	snow_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	snow_pm.emission_box_extents = Vector3(3.8, 0.90, 1.4)
	snow_pm.direction = Vector3(0.38, -0.75, 0.08)
	snow_pm.spread = 28.0
	snow_pm.initial_velocity_min = 0.28
	snow_pm.initial_velocity_max = 0.65
	snow_pm.gravity = Vector3(0.14, -0.34, 0.02)
	snow_pm.turbulence_enabled = true
	snow_pm.turbulence_noise_strength = 0.85
	snow_pm.turbulence_noise_scale = 2.6
	snow_pm.scale_min = 0.45
	snow_pm.scale_max = 1.05
	splash_3d_snow_particles.process_material = snow_pm
	var snow_qm := QuadMesh.new()
	snow_qm.size = Vector2(0.012, 0.012)
	var soft_grad := Gradient.new()
	soft_grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	soft_grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	soft_grad.add_point(0.4, Color(1.0, 1.0, 1.0, 0.45))
	var soft_tex := GradientTexture2D.new()
	soft_tex.gradient = soft_grad
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(1.0, 0.5)
	soft_tex.width = 32
	soft_tex.height = 32
	var snow_qmat := StandardMaterial3D.new()
	snow_qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow_qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow_qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	snow_qmat.albedo_texture = soft_tex
	snow_qmat.albedo_color = Color(0.96, 0.98, 1.0, 0.42)
	snow_qm.material = snow_qmat
	splash_3d_snow_particles.draw_pass_1 = snow_qm
	splash_3d_vp.add_child(splash_3d_snow_particles)

	# 3 Animated Blender 3D Tatra Chamois leaping across Krivan's snow-draped front ridge
	splash_chamois_nodes.clear()
	splash_chamois_anims.clear()
	splash_chamois_trails.clear()
	var chamois_outline := ShaderMaterial.new()
	chamois_outline.shader = preload("res://shaders/outline.gdshader")
	chamois_outline.set_shader_parameter("thickness", 0.005)
	chamois_outline.set_shader_parameter("outline_color", Color(0.08, 0.05, 0.03, 1.0))
	var chamois_scales := [0.56, 0.50, 0.46]
	for c_idx in range(3):
		var c_inst := _load_glb_scene("res://assets/models/intro_chamois.glb")
		if c_inst == null:
			continue
		c_inst.visible = false
		c_inst.scale = Vector3.ONE * float(chamois_scales[c_idx])
		_attach_outline_to_surfaces(c_inst, chamois_outline)
		splash_3d_vp.add_child(c_inst)
		splash_chamois_nodes.append(c_inst)
		var ap := _find_anim_player_recursive(c_inst)
		if ap != null:
			if ap.has_animation("LeapCycle"):
				var anim_l := ap.get_animation("LeapCycle")
				if anim_l != null:
					anim_l.loop_mode = Animation.LOOP_LINEAR
			ap.speed_scale = 1.30
		splash_chamois_anims.append(ap)

	# 3. Front layer: foreground snow flakes, golden hoof spindrift, studio title & dark curtain
	splash_canvas = Control.new()
	splash_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_canvas.draw.connect(_draw_splash_animation)
	splash_control.add_child(splash_canvas)

func _draw_snowflake_star(canvas: Control, c: Vector2, r: float, ang: float, col: Color) -> void:
	for k in range(3):
		var a := ang + float(k) * (PI / 3.0)
		var d := Vector2(cos(a), sin(a)) * r
		canvas.draw_line(c - d, c + d, col, 1.35)
	canvas.draw_circle(c, r * 0.28, col)

func _draw_splash_sky() -> void:
	if not is_instance_valid(splash_sky_canvas):
		return
	var rect := splash_sky_canvas.get_viewport_rect()
	var cx := rect.size.x * 0.5
	var horizon_y := rect.size.y * 0.62
	var t := splash_time * 0.88

	var sun_rise := clampf((t - 0.05) / 0.85, 0.0, 1.0)
	var bg_col := Color(0.11, 0.10, 0.12).lerp(Color(0.95, 0.92, 0.87), ease(sun_rise, 0.45))
	splash_sky_canvas.draw_rect(rect, bg_col)

	var sun_y := lerpf(horizon_y + 50.0, horizon_y - 225.0, ease(clampf(t / 1.15, 0.0, 1.0), 0.4))
	var sun_pos := Vector2(cx + 68.0, sun_y)
	splash_sky_canvas.draw_circle(sun_pos, 148.0 * sun_rise, Color(1.0, 0.78, 0.36, 0.36 * sun_rise))
	splash_sky_canvas.draw_circle(sun_pos, 82.0 * sun_rise, Color(1.0, 0.88, 0.54, 0.82 * sun_rise))


func _krivan_chamois_arc_pos(gp: float, c_idx: int) -> Vector3:
	var x := lerpf(-2.45, 2.58, gp)
	var shoulder_y := 1.44 + (1.0 - pow(clampf(absf(x) / 2.6, 0.0, 1.0), 1.45)) * 0.74
	var y := shoulder_y + sin(gp * PI) * 0.62 + float(c_idx % 2) * 0.14
	var z := 0.94 + float(c_idx) * 0.14 - sin(gp * PI) * 0.08
	return Vector3(x, y, z)


func _update_splash_3d() -> void:
	var t := splash_time * 0.88
	var rise_p := clampf((t - 0.38) / 0.92, 0.0, 1.0)
	var rise_ease := clampf(ease(rise_p, 0.32), 0.0, 1.05)
	if rise_p > 0.75:
		var settle := (rise_p - 0.75) / 0.25
		rise_ease = 1.0 + sin(settle * PI) * 0.035

	if is_instance_valid(splash_mtn_root):
		splash_mtn_root.position.y = lerpf(-2.95, -0.22, rise_ease)
		splash_mtn_root.rotation_degrees.y = sin(t * 0.42) * 3.5

	if is_instance_valid(splash_3d_cam):
		var cam_dolly := clampf(t / 4.2, 0.0, 1.0)
		splash_3d_cam.position = Vector3(sin(t * 0.35) * 0.18, lerpf(0.72, 0.82, cam_dolly), lerpf(8.35, 7.75, cam_dolly))
		splash_3d_cam.look_at(Vector3(0.0, lerpf(1.36, 1.30, cam_dolly), 0.0), Vector3.UP)

	if is_instance_valid(splash_3d_sun):
		var sun_sweep := clampf((t - 0.2) / 3.2, 0.0, 1.0)
		splash_3d_sun.rotation_degrees = Vector3(lerpf(-18.0, -34.0, sun_sweep), lerpf(62.0, 40.0, sun_sweep), 0.0)

	if splash_mtn_mat:
		var snow_cov := clampf((t - 1.05) / 1.30, 0.0, 1.0)
		var snow_line := lerpf(1.28, 0.36, ease(snow_cov, 0.54))
		splash_mtn_mat.set_shader_parameter("snow_line_ratio", snow_line)
		splash_mtn_mat.set_shader_parameter("snow_time", t)

	if is_instance_valid(splash_3d_snow_particles):
		splash_3d_snow_particles.emitting = (t >= 0.90 and t <= 4.10)

	# Animate 3 Blender 3D Tatra Chamois leaping gracefully across Krivan's snow-draped ridge
	splash_chamois_trails.clear()
	var can_unproject := (
		is_instance_valid(splash_3d_cam)
		and is_instance_valid(splash_3d_vp)
		and is_instance_valid(splash_3d_container)
		and splash_3d_vp.size.x > 0
		and splash_3d_vp.size.y > 0
	)
	var vp_to_canvas := Vector2.ONE
	if can_unproject:
		vp_to_canvas = splash_3d_container.size / Vector2(splash_3d_vp.size)

	for c_idx in range(splash_chamois_nodes.size()):
		var ch := splash_chamois_nodes[c_idx]
		if not is_instance_valid(ch):
			continue
		var ap: AnimationPlayer = splash_chamois_anims[c_idx] if c_idx < splash_chamois_anims.size() else null
		var g_start := 2.02 + float(c_idx) * 0.34
		var gp := (t - g_start) / 1.18
		if gp > 0.005 and gp < 0.995:
			if not ch.visible:
				ch.visible = true
				if is_instance_valid(ap) and ap.has_animation("LeapCycle"):
					ap.play("LeapCycle")
					ap.seek(fmod(float(c_idx) * 0.22, 1.1), true)
			var pos_now := _krivan_chamois_arc_pos(gp, c_idx)
			var pos_next := _krivan_chamois_arc_pos(minf(gp + 0.025, 1.0), c_idx)
			var vel := pos_next - pos_now
			ch.position = pos_now
			var pitch_deg := rad_to_deg(atan2(vel.y, maxf(0.001, vel.x)))
			ch.rotation_degrees = Vector3(sin(gp * PI * 2.0) * 4.5, -12.0 + float(c_idx) * 3.0, clampf(pitch_deg, -34.0, 34.0))

			if can_unproject:
				var edge_fade := clampf(sin(gp * PI) * 2.6, 0.0, 1.0)
				for tr_i in range(1, 7):
					var tp := clampf(gp - float(tr_i) * 0.024, 0.0, 1.0)
					var w_tr := _krivan_chamois_arc_pos(tp, c_idx) + Vector3(-0.14, 0.04, 0.0)
					if not splash_3d_cam.is_position_behind(w_tr):
						var s_pt := splash_3d_cam.unproject_position(w_tr) * vp_to_canvas
						splash_chamois_trails.append({
							"pos": s_pt,
							"step": tr_i,
							"alpha": edge_fade,
						})
		else:
			if ch.visible:
				ch.visible = false
				if is_instance_valid(ap):
					ap.stop()

	if is_instance_valid(splash_sky_canvas):
		splash_sky_canvas.queue_redraw()
	if is_instance_valid(splash_canvas):
		splash_canvas.queue_redraw()


func _draw_splash_animation() -> void:
	var rect := splash_canvas.get_viewport_rect()
	var w := rect.size.x
	var h := rect.size.y
	var cx := w * 0.5
	var horizon_y := h * 0.62
	# Brisk majestic pacing (~5.3s total) with Blender 3D Krivan peak underneath
	var t := splash_time * 0.88

	var rise_p := clampf((t - 0.38) / 0.92, 0.0, 1.0)
	var rise_ease := clampf(ease(rise_p, 0.32), 0.0, 1.05)
	if rise_p > 0.75:
		var settle := (rise_p - 0.75) / 0.25
		rise_ease = 1.0 + sin(settle * PI) * 0.035

	if rise_ease > 0.05 and t >= 1.12 and t <= 1.85:
		var dp := (t - 1.12) / 0.73
		for i in range(6):
			var side := -1.0 if i < 3 else 1.0
			var k := float(i % 3)
			var px := cx + side * (75.0 + k * 55.0 + dp * 42.0)
			var py := horizon_y - 8.0 - sin(dp * PI) * 18.0
			splash_canvas.draw_circle(Vector2(px, py), (18.0 - k * 3.0) * (1.0 - dp * 0.5), Color(0.86, 0.80, 0.72, (1.0 - dp) * 0.55))

	# Falling alpine mist wisps drifting slowly down Krivan + tiny sub-pixel micro-snow motes (t = 0.95 .. 4.10)
	if t >= 0.95 and t <= 4.10:
		var mist_alpha := clampf((t - 0.95) / 0.45, 0.0, 1.0) * clampf((4.10 - t) / 0.70, 0.0, 1.0)
		# Layered translucent falling mountain mist/fog sheets
		for w_i in range(28):
			var cyc := fmod((t - 0.95) * (0.14 + fmod(float(w_i) * 0.037, 0.10)) + float(w_i) * 0.17, 1.0)
			var mx := cx + (fmod(float(w_i) * 97.3, 620.0) - 310.0) + sin(t * 0.85 + float(w_i) * 0.9) * 26.0 + cyc * 18.0
			var my := (horizon_y - 290.0) + ease(cyc, 0.85) * 305.0
			var rx := 38.0 + fmod(float(w_i) * 19.0, 44.0)
			var edge_f := sin(cyc * PI)
			var m_col := Color(0.92, 0.95, 0.99, (0.048 + fmod(float(w_i), 3.0) * 0.016) * mist_alpha * edge_f)
			splash_canvas.draw_set_transform(Vector2(mx, my), 0.06 * sin(t + float(w_i)), Vector2(1.9, 0.42))
			splash_canvas.draw_circle(Vector2.ZERO, rx, m_col)
			splash_canvas.draw_circle(Vector2(14.0, -5.0), rx * 0.68, Color(0.96, 0.97, 1.0, m_col.a * 0.75))
		splash_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Tiny delicate micro-snow specks
		for f_i in range(44):
			var seed_x := fmod(float(f_i) * 73.1, 560.0) - 280.0
			var spd := 0.24 + fmod(float(f_i) * 0.13, 0.22)
			var fy_cyc := fmod((t - 0.95) * spd + float(f_i) * 0.13, 1.0)
			var drift := sin(t * 1.6 + float(f_i) * 0.7) * 9.0 + fy_cyc * 16.0
			var fx := cx + seed_x + drift
			var fy := (horizon_y - 310.0) + fy_cyc * 310.0
			var rad := 0.9 + fmod(float(f_i) * 0.31, 0.75)
			splash_canvas.draw_circle(Vector2(fx, fy), rad, Color(0.96, 0.98, 1.0, 0.46 * mist_alpha * sin(fy_cyc * PI)))

	# Zlatisté obláčiky snežného prašanu za kopytami 3D kamzíkov
	for tr in splash_chamois_trails:
		var tr_i: int = int(tr["step"])
		var edge_fade: float = float(tr["alpha"])
		var s_pos: Vector2 = tr["pos"]
		var p_col := Color(1.0, 0.98, 0.92, (0.50 - float(tr_i) * 0.07) * edge_fade) if (tr_i % 2 == 0) else Color(0.98, 0.80, 0.34, (0.54 - float(tr_i) * 0.08) * edge_fade)
		splash_canvas.draw_circle(s_pos, maxf(1.2, 6.2 - float(tr_i) * 0.7), p_col)

	# Podkladová linka horizontu
	splash_canvas.draw_line(Vector2(cx - 460.0 * rise_ease, horizon_y), Vector2(cx + 460.0 * rise_ease, horizon_y), Color(0.24, 0.18, 0.13, 0.88), 3.2)

	# Názov FUJIRA STUDIOS pod horou
	var title_a := clampf((t - 2.0) / 0.65, 0.0, 1.0)
	if title_a > 0.01:
		var df := _get_font(true)
		var uf := _get_font(false)
		var slide_y := (1.0 - ease(title_a, 0.3)) * 24.0
		var title_col := Color(0.15, 0.12, 0.10, title_a)
		splash_canvas.draw_string(df, Vector2(0, horizon_y + 62.0 + slide_y), "FUJIRA STUDIOS", HORIZONTAL_ALIGNMENT_CENTER, w, 46, title_col)
		var sub_a := clampf((t - 2.55) / 0.5, 0.0, 1.0)
		if sub_a > 0.01:
			splash_canvas.draw_string(uf, Vector2(0, horizon_y + 96.0), "PRESENTS", HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0.55, 0.38, 0.22, sub_a))
		if t > 2.85:
			splash_canvas.draw_string(uf, Vector2(0, h - 38.0), "Click or press any key to continue", HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0.45, 0.40, 0.35, 0.75))

	# Plynulý prechod do tmy v závere intra pred vstupom do Lobby (t = 4.30 .. 4.76)
	var fade_to_dark := clampf((t - 4.30) / 0.44, 0.0, 1.0)
	if fade_to_dark > 0.005:
		splash_canvas.draw_rect(rect, Color(0.02, 0.03, 0.03, fade_to_dark))

# ============================================================================
# 2. HLAVNÉ MENU "LIALO" (Čierne pozadie + Vylepšená Solitaire Kartová Animácia)
# ============================================================================
func _build_main_menu() -> void:
	menu_control = Control.new()
	menu_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_control.theme = game_theme
	ui_layer.add_child(menu_control)

	# Čisté hlboké čierne pozadie ("Black Screen") s jemným zlatým rámom pre maximálny kontrast kariet
	var bg_canvas := Control.new()
	bg_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_canvas.draw.connect(func():
		var rect := bg_canvas.get_viewport_rect()
		bg_canvas.draw_rect(rect, Color(0.012, 0.012, 0.015))
		var cen := rect.size * 0.5
		bg_canvas.draw_circle(cen, rect.size.x * 0.42, Color(0.04, 0.04, 0.05, 0.45))
		bg_canvas.draw_rect(Rect2(14, 14, rect.size.x - 28, rect.size.y - 28), Color(0.52, 0.40, 0.22, 0.24), false, 2.0)
	)
	menu_control.add_child(bg_canvas)

	lobby_sun_rect = ColorRect.new()
	lobby_sun_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_sun_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_sun_mat = ShaderMaterial.new()
	lobby_sun_mat.shader = LOBBY_SUN_SHADER
	lobby_sun_mat.set_shader_parameter("sun_center_uv", Vector2(0.5, 0.255))
	lobby_sun_mat.set_shader_parameter("sun_prog", 1.0)
	lobby_sun_mat.set_shader_parameter("aspect_ratio", 1.778)
	lobby_sun_rect.material = lobby_sun_mat
	menu_control.add_child(lobby_sun_rect)

	lobby_sun_canvas = Control.new()
	lobby_sun_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_sun_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_sun_canvas.draw.connect(_draw_lobby_sun_backdrop)
	menu_control.add_child(lobby_sun_canvas)

	# Striedajúce sa epické kartové animácie (vrátane úvodného prsknutia a poskočenia kariet!)
	lobby_fx_canvas = Control.new()
	lobby_fx_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_fx_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_fx_canvas.draw.connect(_draw_lobby_card_showcase)
	menu_control.add_child(lobby_fx_canvas)

	lobby_dark_veil = ColorRect.new()
	lobby_dark_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_dark_veil.color = Color(0.015, 0.02, 0.02, 0.0)
	lobby_dark_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_control.add_child(lobby_dark_veil)

	# Jemný tmavý stredový závoj za titulkom a tlačidlami pre maximálnu čitateľnosť
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_control.add_child(center)

	var main_vbox := VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 22)
	center.add_child(main_vbox)

	# Väčší ručne kreslený nápis LIALO oddelený od kariet vrstvenou žiarou a animáciou
	var logo_box := VBoxContainer.new()
	logo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_box.add_theme_constant_override("separation", 4)
	main_vbox.add_child(logo_box)

	var title_tex := Toon.tex("res://assets/lobby/title_lialo.png")
	if title_tex:
		var logo_holder := Control.new()
		logo_holder.custom_minimum_size = Vector2(810, 204)
		logo_holder.pivot_offset = Vector2(405, 102)

		logo_aura_canvas = Control.new()
		logo_aura_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		logo_aura_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_aura_canvas.draw.connect(func():
			if not is_instance_valid(logo_aura_canvas):
				return
			var sz := logo_aura_canvas.size
			var c := sz * 0.5
			var lt := Time.get_ticks_msec() * 0.001
			# Tmavá zamatová clona + zlatistá aureola na výrazné oddelenie nápisu od kariet
			logo_aura_canvas.draw_circle(c, 225.0, Color(0.02, 0.04, 0.04, 0.56))
			logo_aura_canvas.draw_circle(c, 160.0 + sin(lt * 1.8) * 10.0, Color(0.95, 0.72, 0.24, 0.09 + sin(lt * 2.2) * 0.03))
			logo_aura_canvas.draw_arc(c, 198.0, lt * 0.35, lt * 0.35 + PI * 0.65, 28, Color(0.96, 0.80, 0.36, 0.24), 2.0)
			logo_aura_canvas.draw_arc(c, 198.0, lt * 0.35 + PI, lt * 0.35 + PI * 1.65, 28, Color(0.28, 0.84, 0.72, 0.22), 2.0)
			for i in range(14):
				var ph := float(i) * 0.91
				var ang := lt * (0.28 + float(i % 3) * 0.08) + ph
				var rx := 315.0 + sin(lt * 1.3 + ph) * 32.0
				var ry := 76.0 + cos(lt * 1.7 + ph) * 14.0
				var sp := c + Vector2(cos(ang) * rx, sin(ang) * ry)
				var al := 0.25 + 0.45 * absf(sin(lt * 2.6 + ph))
				var col := Color(1.0, 0.86, 0.42, al) if i % 2 == 0 else Color(0.42, 0.92, 0.80, al)
				logo_aura_canvas.draw_circle(sp, 2.4 + sin(lt * 3.0 + ph) * 1.0, col)
		)
		logo_holder.add_child(logo_aura_canvas)

		var shadow_img := TextureRect.new()
		shadow_img.name = "LogoShadow"
		shadow_img.texture = title_tex
		shadow_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		shadow_img.offset_left = 5
		shadow_img.offset_top = 10
		shadow_img.offset_right = 5
		shadow_img.offset_bottom = 10
		shadow_img.modulate = Color(0.01, 0.02, 0.02, 0.86)
		shadow_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_holder.add_child(shadow_img)

		var title_img := TextureRect.new()
		title_img.name = "LogoTitle"
		title_img.texture = title_tex
		title_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		title_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_holder.add_child(title_img)

		logo_box.add_child(logo_holder)
		title_logo_node = logo_holder
	else:
		var main_title := Label.new()
		main_title.text = "L I A L O"
		main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_title.add_theme_font_override("font", _get_font(true))
		main_title.add_theme_font_size_override("font_size", 88)
		main_title.add_theme_color_override("font_color", Color(0.96, 0.74, 0.26))
		logo_box.add_child(main_title)
		title_logo_node = main_title

	var tagline := Label.new()
	tagline.text = "FUJIRA STUDIOS"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_override("font", _get_font(true))
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.add_theme_color_override("font_color", Color(0.94, 0.82, 0.52, 0.96))
	tagline.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.96))
	tagline.add_theme_constant_override("outline_size", 5)
	logo_box.add_child(tagline)
	title_tagline_node = tagline

	# Pyramída drevených tlačidiel bez podtitulov: veľká CAMPAIGN hore + 3 menšie pod ňou
	signs_box = VBoxContainer.new()
	signs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	signs_box.add_theme_constant_override("separation", 18)
	main_vbox.add_child(signs_box)

	# Skryté zosúvateľné ovládanie zvuku v pravom hornom rohu lobby (rozbalí sa po kliknutí)
	var audio_pill := _create_audio_control_pill()
	audio_pill.anchor_left = 1.0
	audio_pill.anchor_right = 1.0
	audio_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	audio_pill.offset_left = -126
	audio_pill.offset_top = 14
	audio_pill.offset_right = -18
	audio_pill.offset_bottom = 56
	menu_control.add_child(audio_pill)

	lobby_options_btn = Button.new()
	lobby_options_btn.text = "⚙ OPTIONS" if str(game_options.get("language", "en")) != "cs" else "⚙ NASTAVENÍ"
	lobby_options_btn.anchor_left = 0.0
	lobby_options_btn.anchor_top = 0.0
	lobby_options_btn.offset_left = 18
	lobby_options_btn.offset_top = 14
	lobby_options_btn.offset_right = 204
	lobby_options_btn.offset_bottom = 54
	lobby_options_btn.add_theme_font_size_override("font_size", 15)
	lobby_options_btn.pressed.connect(func():
		_play_sfx("ui_click")
		_open_options_modal()
	)
	menu_control.add_child(lobby_options_btn)

	if MpConfig.is_test_mp_available():
		var mp_dev := MpDevEntry.new()
		mp_dev.name = "MpDevEntry"
		mp_entry = mp_dev
		add_child(mp_dev)
		mp_dev.attach(self, menu_control)

	var legal_footer := Label.new()
	legal_footer.text = "© 2026 Fujira Studios. Všechna práva vyhrazena. • LIALO" if _is_cs() else "© 2026 Fujira Studios. All Rights Reserved.  •  LIALO"
	legal_footer.anchor_left = 0.0
	legal_footer.anchor_top = 1.0
	legal_footer.anchor_bottom = 1.0
	legal_footer.offset_left = 18
	legal_footer.offset_top = -34
	legal_footer.offset_right = 520
	legal_footer.offset_bottom = -10
	legal_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legal_footer.add_theme_font_override("font", _get_font(false))
	legal_footer.add_theme_font_size_override("font_size", 13)
	legal_footer.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62, 0.78))
	legal_footer.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.90))
	legal_footer.add_theme_constant_override("outline_size", 4)
	menu_control.add_child(legal_footer)

	_build_deck_selector_modal()
	_build_options_modal()
	_populate_menu_signs()

func _tr_ui(en_txt: String, cs_txt: String) -> String:
	return Catalog.tr_loc(str(game_options.get("language", "en")), en_txt, cs_txt)

func _tr(en_txt: String, cs_txt: String) -> String:
	return _tr_ui(en_txt, cs_txt)

func _build_deck_selector_modal() -> void:
	arsenal_layer = CanvasLayer.new()
	arsenal_layer.layer = 11
	add_child(arsenal_layer)

	deck_modal = PanelContainer.new()
	deck_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_modal.offset_left = 0
	deck_modal.offset_top = 0
	deck_modal.offset_right = 0
	deck_modal.offset_bottom = 0
	deck_modal.visible = false
	var ars_sb := StyleBoxFlat.new()
	ars_sb.bg_color = Color(0.032, 0.025, 0.022, 1.0)
	ars_sb.border_color = Color(0.84, 0.64, 0.24, 0.96)
	ars_sb.set_border_width_all(3)
	ars_sb.content_margin_left = 40
	ars_sb.content_margin_right = 40
	ars_sb.content_margin_top = 26
	ars_sb.content_margin_bottom = 26
	deck_modal.add_theme_stylebox_override("panel", ars_sb)
	arsenal_layer.add_child(deck_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	deck_modal.add_child(vbox)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 14)
	vbox.add_child(top_hb)

	collection_title_lbl = Label.new()
	collection_title_lbl.text = "ARSENAL & CARD COLLECTION"
	collection_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_title_lbl.add_theme_font_override("font", _get_font(true))
	collection_title_lbl.add_theme_font_size_override("font_size", 28)
	collection_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.38))
	top_hb.add_child(collection_title_lbl)

	collection_stats_lbl = Label.new()
	collection_stats_lbl.text = "25 / 48 Unlocked"
	collection_stats_lbl.add_theme_font_override("font", _get_font(true))
	collection_stats_lbl.add_theme_font_size_override("font_size", 16)
	collection_stats_lbl.add_theme_color_override("font_color", Color(0.56, 0.92, 0.72))
	top_hb.add_child(collection_stats_lbl)

	collection_flip_btn = Button.new()
	collection_flip_btn.text = _tr("Flip All", "Otočit vše")
	collection_flip_btn.custom_minimum_size = Vector2(146, 40)
	collection_flip_btn.pressed.connect(func():
		_play_sfx("card_shuffle")
		collection_flip_all = not collection_flip_all
		collection_flip_btn.text = _tr("Turn Back", "Otočit zpět") if collection_flip_all else _tr("Flip All", "Otočit vše")
		_rebuild_collection_view()
	)
	top_hb.add_child(collection_flip_btn)

	collection_close_btn = Button.new()
	collection_close_btn.text = _tr("✕ Close [ESC]", "✕ Zavřít [ESC]")
	collection_close_btn.custom_minimum_size = Vector2(144, 40)
	collection_close_btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.70))
	collection_close_btn.pressed.connect(func():
		_play_sfx("ui_click")
		_close_animated_modal(deck_modal)
	)
	top_hb.add_child(collection_close_btn)

	var tab_hb := HBoxContainer.new()
	tab_hb.add_theme_constant_override("separation", 12)
	vbox.add_child(tab_hb)
	collection_tab_btns.clear()
	var t_arr: Array[String] = [
		"Classic Cards (32)",
		"Power Cards (%d)" % Catalog.POWER_CARDS.size(),
		"Choose Deck (5)",
		"Relics (8) & Blades",
		"🛠 Deck Builder & Bankai",
	]
	for ti in range(t_arr.size()):
		var t_txt: String = t_arr[ti]
		var tb := Button.new()
		tb.text = t_txt
		tb.custom_minimum_size = Vector2(182, 42)
		tb.pressed.connect(func():
			_play_sfx("ui_click")
			collection_tab_idx = ti
			_rebuild_collection_view()
		)
		tab_hb.add_child(tb)
		collection_tab_btns.append(tb)

	collection_scroll = ScrollContainer.new()
	collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(collection_scroll)

	var scroll_inner := VBoxContainer.new()
	scroll_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_theme_constant_override("separation", 18)
	collection_scroll.add_child(scroll_inner)

	var deck_center := CenterContainer.new()
	deck_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_child(deck_center)

	collection_decks_box = VBoxContainer.new()
	collection_decks_box.custom_minimum_size = Vector2(1180, 0)
	collection_decks_box.add_theme_constant_override("separation", 10)
	collection_decks_box.visible = true
	deck_center.add_child(collection_decks_box)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_child(grid_center)

	collection_grid = GridContainer.new()
	collection_grid.columns = 4
	collection_grid.add_theme_constant_override("h_separation", 22)
	collection_grid.add_theme_constant_override("v_separation", 22)
	grid_center.add_child(collection_grid)

	var blade_center := CenterContainer.new()
	blade_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_child(blade_center)

	collection_blades_box = VBoxContainer.new()
	collection_blades_box.custom_minimum_size = Vector2(1160, 0)
	collection_blades_box.add_theme_constant_override("separation", 14)
	collection_blades_box.visible = false
	blade_center.add_child(collection_blades_box)

	collection_deck_builder = DeckBuilderPanelScript.new()
	collection_deck_builder.visible = false
	collection_deck_builder.sfx_requested.connect(func(sn: String): _play_sfx(sn))
	collection_deck_builder.deck_changed.connect(func(_p: Dictionary):
		_refresh_map_roguelite_hud()
		_populate_menu_signs()
	)
	scroll_inner.add_child(collection_deck_builder)

	# Dedicated Card Inspection Detail Modal (opens over full-screen Arsenal)
	collection_detail_modal = PanelContainer.new()
	collection_detail_modal.set_anchors_preset(Control.PRESET_CENTER)
	collection_detail_modal.offset_left = -360
	collection_detail_modal.offset_top = -235
	collection_detail_modal.offset_right = 360
	collection_detail_modal.offset_bottom = 235
	collection_detail_modal.z_index = 90
	collection_detail_modal.visible = false
	collection_detail_modal.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.05, 0.04, 0.055, 0.99), Color(0.98, 0.80, 0.36)))
	arsenal_layer.add_child(collection_detail_modal)

	var d_hb := HBoxContainer.new()
	d_hb.add_theme_constant_override("separation", 20)
	collection_detail_modal.add_child(d_hb)

	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(218, 326)
	art_frame.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.08, 0.06, 0.05), Color(0.84, 0.64, 0.28)))
	d_hb.add_child(art_frame)

	col_det_art = TextureRect.new()
	col_det_art.custom_minimum_size = Vector2(204, 310)
	col_det_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	col_det_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_frame.add_child(col_det_art)

	var det_custom_art := Control.new()
	det_custom_art.name = "DetailCustomArt"
	det_custom_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	det_custom_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	det_custom_art.visible = false
	det_custom_art.draw.connect(func():
		var e_meta: Variant = det_custom_art.get_meta("entry", {})
		if e_meta is Dictionary and not (e_meta as Dictionary).is_empty():
			_draw_custom_arsenal_illustration(det_custom_art, e_meta as Dictionary, true)
	)
	art_frame.add_child(det_custom_art)

	var d_info := VBoxContainer.new()
	d_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_info.add_theme_constant_override("separation", 10)
	d_hb.add_child(d_info)

	col_det_title = Label.new()
	col_det_title.add_theme_font_override("font", _get_font(true))
	col_det_title.add_theme_font_size_override("font_size", 24)
	col_det_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	d_info.add_child(col_det_title)

	col_det_sub = Label.new()
	col_det_sub.add_theme_font_size_override("font_size", 17)
	col_det_sub.add_theme_color_override("font_color", Color(0.60, 0.90, 0.98))
	d_info.add_child(col_det_sub)

	col_det_badge = Label.new()
	col_det_badge.add_theme_font_size_override("font_size", 16)
	d_info.add_child(col_det_badge)

	col_det_desc = Label.new()
	col_det_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col_det_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_det_desc.add_theme_font_size_override("font_size", 18)
	col_det_desc.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	d_info.add_child(col_det_desc)

	collection_det_close_btn = Button.new()
	collection_det_close_btn.text = _tr("Close Card", "Zavřít kartu")
	collection_det_close_btn.custom_minimum_size = Vector2(150, 42)
	collection_det_close_btn.add_theme_font_size_override("font_size", 16)
	collection_det_close_btn.pressed.connect(func():
		_play_sfx("ui_click")
		_close_animated_modal(collection_detail_modal)
	)
	d_info.add_child(collection_det_close_btn)

func _is_cs() -> bool:
	return str(game_options.get("language", "en")) == "cs"

func _clear_active_collection_hover() -> void:
	if _active_collection_hover_reset.is_valid():
		_active_collection_hover_reset.call()
	_active_collection_hover_slot = null
	_active_collection_hover_reset = Callable()

func _open_collection_modal(tab: int = 0) -> void:
	_clear_active_collection_hover()
	collection_tab_idx = tab
	_rebuild_collection_view()
	_open_animated_modal(deck_modal)

func _draw_locked_chains_overlay(ctrl: Control, caption: String) -> void:
	var sz := ctrl.size
	if sz.x < 16.0 or sz.y < 16.0:
		return
	# Dark veil over locked card
	ctrl.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.03, 0.04, 0.56))
	var iron_dark := Color(0.14, 0.15, 0.18, 0.98)
	var iron_mid := Color(0.42, 0.45, 0.52, 0.98)
	var iron_hi := Color(0.76, 0.80, 0.88, 0.95)
	var rust := Color(0.38, 0.24, 0.16, 0.85)

	# Two heavy diagonal iron chains crossing in an X across the locked card
	var diag_pairs := [
		[Vector2(8, 12), Vector2(sz.x - 8, sz.y - 12)],
		[Vector2(sz.x - 8, 12), Vector2(8, sz.y - 12)],
	]
	for pair in diag_pairs:
		var p0: Vector2 = pair[0]
		var p1: Vector2 = pair[1]
		var dir := (p1 - p0).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var dist := p0.distance_to(p1)
		var links := int(dist / 17.0)
		for li in range(links + 1):
			var u := float(li) / float(maxi(1, links))
			var lp := p0.lerp(p1, u)
			var is_even := (li % 2 == 0)
			var l_len := 10.5
			var l_wid := 5.5 if is_even else 3.2
			var a := lp - dir * l_len * 0.5
			var b := lp + dir * l_len * 0.5
			ctrl.draw_line(a + Vector2(2, 3), b + Vector2(2, 3), Color(0, 0, 0, 0.55), l_wid * 2.1)
			ctrl.draw_line(a, b, iron_dark, l_wid * 2.0)
			ctrl.draw_line(a, b, iron_mid, l_wid * 1.35)
			if is_even:
				ctrl.draw_line(a + perp * 1.5, b + perp * 1.5, iron_hi, 1.8)
				ctrl.draw_circle(lp, 2.2, iron_dark)

	# Heavy medieval iron padlock in center
	var c := sz * 0.5
	# Shackle loop
	ctrl.draw_arc(c + Vector2(0, -14), 13.0, PI, TAU, 18, iron_dark, 8.0)
	ctrl.draw_arc(c + Vector2(0, -14), 13.0, PI, TAU, 18, iron_mid, 5.0)
	ctrl.draw_arc(c + Vector2(0, -14), 13.0, PI + 0.3, TAU - 0.3, 14, iron_hi, 2.0)
	# Padlock body
	var lock_r := Rect2(c.x - 20, c.y - 12, 40, 34)
	ctrl.draw_rect(Rect2(lock_r.position + Vector2(3, 4), lock_r.size), Color(0, 0, 0, 0.6))
	ctrl.draw_rect(lock_r, iron_dark)
	ctrl.draw_rect(lock_r.grow(-2.5), iron_mid)
	ctrl.draw_rect(Rect2(lock_r.position.x + 3, lock_r.position.y + 3, lock_r.size.x - 6, 5), rust)
	ctrl.draw_rect(lock_r, iron_hi, false, 2.0)
	# 4 corner rivets on padlock
	for rx in [-14.0, 14.0]:
		for ry in [-6.0, 16.0]:
			ctrl.draw_circle(c + Vector2(rx, ry), 2.4, iron_hi)
	# Keyhole
	ctrl.draw_circle(c + Vector2(0, 2), 4.2, iron_dark)
	ctrl.draw_line(c + Vector2(0, 2), c + Vector2(0, 13), iron_dark, 3.6)

	if caption != "":
		var df := _get_font(true)
		var pill_r := Rect2(10, sz.y - 36, sz.x - 20, 24)
		ctrl.draw_rect(pill_r, Color(0.05, 0.04, 0.05, 0.92))
		ctrl.draw_rect(pill_r, iron_mid, false, 1.5)
		ctrl.draw_string(df, Vector2(12, sz.y - 19), caption, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 24, 12, Color(0.88, 0.86, 0.82))

func _draw_custom_arsenal_illustration(ctrl: Control, entry: Dictionary, show_front: bool) -> void:
	var sz := ctrl.size
	if sz.x < 16.0 or sz.y < 16.0:
		return
	var kind := str(entry.get("custom_kind", ""))
	if not show_front:
		if card_back_tex:
			ctrl.draw_texture_rect(card_back_tex, Rect2(Vector2.ZERO, sz), false)
		return
	var accent: Color = entry.get("col", Color(0.92, 0.74, 0.28))
	var df := _get_font(true)
	var ink := Color(0.08, 0.05, 0.03, 0.96)
	# Aged woodcut parchment card base
	var r := Rect2(Vector2.ZERO, sz)
	ctrl.draw_rect(r, Color(0.93, 0.88, 0.77))
	ctrl.draw_rect(r.grow(-5.0), Color(0.88, 0.81, 0.68))
	ctrl.draw_rect(r.grow(-6.0), ink, false, 2.4)
	ctrl.draw_rect(r.grow(-11.0), Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.88), false, 1.8)
	var c := sz * 0.5 + Vector2(0, -6)

	if kind in ["blade", "relic", "table_relic"]:
		# Ornate medieval tarot-style corner ornaments
		var frame_col := Color(accent.r * 0.72, accent.g * 0.72, accent.b * 0.72, 0.90)
		for cx_s in [14.0, sz.x - 14.0]:
			for cy_s in [14.0, sz.y - 14.0]:
				ctrl.draw_circle(Vector2(cx_s, cy_s), 4.2, ink)
				ctrl.draw_circle(Vector2(cx_s, cy_s), 2.4, frame_col)
		# Emblem halo medallion
		var halo_r := minf(sz.x * 0.35, sz.y * 0.28)
		ctrl.draw_circle(c, halo_r, Color(accent.r, accent.g, accent.b, 0.20))
		ctrl.draw_arc(c, halo_r, 0.0, TAU, 40, ink, 2.4)
		ctrl.draw_arc(c, halo_r - 4.0, 0.0, TAU, 36, frame_col, 1.8)

		var art_p := ""
		var cat_lbl := ""
		var title_lbl := ""
		if kind == "blade":
			var sw: Dictionary = entry.get("raw_data", {})
			var sid := str(sw.get("id", entry.get("key", "")))
			art_p = Catalog.get_sword_art_path(sid)
			cat_lbl = _tr("⚔ BLADE", "⚔ ČEPEL")
			title_lbl = _tr(str(sw.get("name", "Blade")), str(sw.get("name_cs", sw.get("name", "Čepel"))))
		elif kind == "table_relic":
			var tr_d: Dictionary = entry.get("raw_data", {})
			var tid := str(tr_d.get("id", entry.get("key", "")))
			art_p = Catalog.get_table_relic_art_path(tid)
			cat_lbl = _tr("✦ 3D TABLE RELIC", "✦ 3D RELIKVIE NA STŮL")
			title_lbl = _tr(str(tr_d.get("name", "Table Relic")), str(tr_d.get("name_cs", tr_d.get("name", "Relikvie"))))
		else:
			var rel: Dictionary = entry.get("raw_data", {})
			var rel_id := str(rel.get("id", entry.get("key", "")))
			art_p = Catalog.get_relic_art_path(rel_id)
			cat_lbl = "✦ " + _tr(str(rel.get("category", "RELIC")), str(rel.get("category_cs", rel.get("category", "RELIKVIE")))).to_upper()
			title_lbl = _tr(str(rel.get("name", "Relic")), str(rel.get("name_cs", rel.get("name", "Relikvie"))))

		if art_p != "":
			var ck := "ARSENAL_" + art_p
			var art_tex: Texture2D = card_face_cache.get(ck, null) as Texture2D
			if art_tex == null and ResourceLoader.exists(art_p):
				art_tex = Toon.tex(art_p)
				if art_tex:
					card_face_cache[ck] = art_tex
			if art_tex:
				var art_sz := minf(sz.x * 0.74, sz.y * 0.56)
				ctrl.draw_texture_rect(art_tex, Rect2(c - Vector2(art_sz * 0.5, art_sz * 0.5), Vector2(art_sz, art_sz)), false)

		# Category header
		ctrl.draw_string(df, Vector2(18, 38), cat_lbl, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 36, 11, ink)
		# Engraved title banner at bottom
		var ban_r := Rect2(14.0, sz.y - 36.0, sz.x - 28.0, 24.0)
		ctrl.draw_rect(ban_r, Color(0.82, 0.74, 0.58, 0.94))
		ctrl.draw_rect(ban_r, ink, false, 1.8)
		ctrl.draw_rect(ban_r.grow(-2.0), frame_col, false, 1.0)
		ctrl.draw_string(df, Vector2(16, sz.y - 19), title_lbl, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 32, 13, ink)

	elif kind == "deck":
		var d: Dictionary = entry.get("raw_data", {})
		var b_col: Color = d.get("border_col", accent)
		var did := str(d.get("id", ""))
		var back_p := str(d.get("back_tex", "res://assets/table/card_back.png"))
		var deck_tex: Texture2D = card_face_cache.get("DECK_" + did, null) as Texture2D
		if deck_tex == null and ResourceLoader.exists(back_p):
			deck_tex = Toon.tex(back_p)
			if deck_tex:
				card_face_cache["DECK_" + did] = deck_tex
		if deck_tex == null:
			deck_tex = card_back_tex
		# Fanned spread of this deck's bespoke woodcut back artwork (zero flat color blocks!)
		for fi in range(5):
			var off_x := (float(fi) - 2.0) * 16.0
			var off_y := absf(float(fi) - 2.0) * 5.0 - 4.0
			var w_c := 74.0 if fi == 2 else 60.0
			var h_c := 110.0 if fi == 2 else 88.0
			var mini_r := Rect2(c.x - w_c * 0.5 + off_x, c.y - h_c * 0.5 + off_y, w_c, h_c)
			if deck_tex:
				ctrl.draw_texture_rect(deck_tex, mini_r, false)
			else:
				ctrl.draw_rect(mini_r, b_col.darkened(0.4))
			ctrl.draw_rect(mini_r, b_col if fi == 2 else ink, false, 2.4 if fi == 2 else 1.6)
		ctrl.draw_string(df, Vector2(10, 26), _tr("🂠 BESPOKE SET", "🂠 UNIKÁTNÍ SADA"), HORIZONTAL_ALIGNMENT_CENTER, sz.x - 20, 12, ink)
		ctrl.draw_string(df, Vector2(10, sz.y - 18), _tr(str(d.get("name", "Deck")), str(d.get("name_cs", d.get("name", "Balíček")))), HORIZONTAL_ALIGNMENT_CENTER, sz.x - 20, 14, ink)

func _build_collection_card_slot(entry: Dictionary) -> Control:
	var unlocked := bool(entry["unlocked"])
	var face_tex: Texture2D = entry.get("tex", null)
	var accent: Color = entry["col"]
	var custom_kind := str(entry.get("custom_kind", ""))
	var is_equipped := bool(entry.get("equipped", false))

	var slot := Control.new()
	slot.custom_minimum_size = Vector2(204, 294)

	var card_panel := PanelContainer.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.pivot_offset = Vector2(102, 147)
	var border_c := Color(0.35, 0.98, 0.56) if is_equipped else (accent if unlocked else Color(0.36, 0.36, 0.40))
	card_panel.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.08, 0.07, 0.075, 0.98), border_c))
	slot.add_child(card_panel)

	var tex_r := TextureRect.new()
	tex_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_r.visible = (custom_kind == "")
	card_panel.add_child(tex_r)

	var custom_canvas := Control.new()
	custom_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_canvas.visible = (custom_kind != "")
	custom_canvas.set_meta("show_front", true)
	custom_canvas.draw.connect(func():
		_draw_custom_arsenal_illustration(custom_canvas, entry, bool(custom_canvas.get_meta("show_front", true)))
	)
	card_panel.add_child(custom_canvas)

	if is_equipped:
		var eq_badge := Label.new()
		eq_badge.text = "✓ EQUIPPED" if not _is_cs() else "✓ VYBAVENO"
		eq_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eq_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		eq_badge.custom_minimum_size = Vector2(0, 26)
		eq_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eq_badge.add_theme_font_override("font", _get_font(true))
		eq_badge.add_theme_font_size_override("font_size", 13)
		eq_badge.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62))
		eq_badge.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.02))
		eq_badge.add_theme_constant_override("outline_size", 5)
		card_panel.add_child(eq_badge)

	# Heavy Iron Chains & Riveted Padlock overlay on any locked card / relic / blade!
	if not unlocked:
		var chain_ctrl := Control.new()
		chain_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
		chain_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap_txt := str(entry.get("cap", "LOCKED"))
		chain_ctrl.draw.connect(func():
			_draw_locked_chains_overlay(chain_ctrl, cap_txt)
		)
		card_panel.add_child(chain_ctrl)

	if bool(entry.get("mp_badge", false)):
		var mp_vb := VBoxContainer.new()
		mp_vb.size_flags_vertical = Control.SIZE_SHRINK_END
		mp_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp_vb.add_theme_constant_override("separation", 1)
		var mp_lbl := Label.new()
		mp_lbl.text = _tr("Unlocked (MP Ready)" if unlocked else "Locked", "Odemčeno (MP)" if unlocked else "Zamčeno")
		mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp_lbl.add_theme_font_override("font", _get_font(true))
		mp_lbl.add_theme_font_size_override("font_size", 11)
		mp_lbl.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62) if unlocked else Color(0.98, 0.56, 0.36))
		mp_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
		mp_lbl.add_theme_constant_override("outline_size", 5)
		mp_vb.add_child(mp_lbl)
		var src_txt := str(entry.get("unlock_source", ""))
		if src_txt != "":
			var src_lbl := Label.new()
			src_lbl.text = src_txt
			src_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			src_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			src_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			src_lbl.add_theme_font_size_override("font_size", 10)
			src_lbl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.70))
			src_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
			src_lbl.add_theme_constant_override("outline_size", 4)
			mp_vb.add_child(src_lbl)
		card_panel.add_child(mp_vb)

	var kill_hover_tw := func():
		if card_panel.has_meta("hover_tw"):
			var old_tw: Variant = card_panel.get_meta("hover_tw")
			if old_tw is Tween and (old_tw as Tween).is_valid():
				(old_tw as Tween).kill()
			card_panel.remove_meta("hover_tw")

	var apply_face_state := func(show_front: bool, is_hovered: bool):
		if custom_kind != "":
			custom_canvas.set_meta("show_front", show_front)
			custom_canvas.modulate = Color.WHITE if unlocked else (Color(0.48, 0.48, 0.52, 0.95) if is_hovered else Color(0.45, 0.45, 0.50, 0.94))
			custom_canvas.queue_redraw()
		else:
			tex_r.texture = face_tex if (show_front and face_tex != null) else (card_back_tex if card_back_tex else face_tex)
			if not unlocked:
				tex_r.modulate = Color(0.42, 0.42, 0.46, 0.95) if is_hovered else Color(0.38, 0.38, 0.42, 0.92)
			elif show_front:
				tex_r.modulate = Color.WHITE
			else:
				tex_r.modulate = Color(0.86, 0.82, 0.74, 0.95)

	var apply_resting := func():
		var show_front := collection_flip_all or (custom_kind != "" and unlocked)
		apply_face_state.call(show_front, false)
		card_panel.scale = Vector2.ONE if show_front else Vector2(0.88, 0.94)
		card_panel.rotation_degrees = 0.0 if show_front else -2.8
		slot.z_index = 0
	apply_resting.call()

	var reset_immediate := func():
		if not is_instance_valid(card_panel) or not is_instance_valid(slot):
			return
		kill_hover_tw.call()
		apply_resting.call()

	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	var esb := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", esb)
	hit.add_theme_stylebox_override("hover", esb)
	hit.add_theme_stylebox_override("pressed", esb)
	hit.add_theme_stylebox_override("focus", esb)
	slot.add_child(hit)

	hit.mouse_entered.connect(func():
		if _active_collection_hover_slot != slot:
			_clear_active_collection_hover()
		_active_collection_hover_slot = slot
		_active_collection_hover_reset = reset_immediate
		kill_hover_tw.call()
		_play_sfx("card_hover", -10.5, randf_range(0.96, 1.08))
		slot.z_index = 40
		var tw := card_panel.create_tween()
		card_panel.set_meta("hover_tw", tw)
		var already_front := collection_flip_all or (custom_kind != "" and unlocked)
		if not already_front:
			tw.tween_property(card_panel, "scale:x", 0.08, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				if is_instance_valid(card_panel):
					apply_face_state.call(true, true)
			)
		else:
			apply_face_state.call(true, true)
		tw.tween_property(card_panel, "scale", Vector2(1.12, 1.12), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card_panel, "rotation_degrees", 0.0, 0.13)
	)
	hit.mouse_exited.connect(func():
		if _active_collection_hover_slot == slot:
			_active_collection_hover_slot = null
			_active_collection_hover_reset = Callable()
		kill_hover_tw.call()
		var tw := card_panel.create_tween()
		card_panel.set_meta("hover_tw", tw)
		var keep_front := collection_flip_all or (custom_kind != "" and unlocked)
		if not keep_front:
			tw.tween_property(card_panel, "scale:x", 0.08, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				if is_instance_valid(card_panel):
					apply_face_state.call(false, false)
					card_panel.scale = Vector2(0.08, 0.94)
			)
			tw.tween_property(card_panel, "scale", Vector2(0.88, 0.94), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card_panel, "rotation_degrees", -2.8, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func():
				if is_instance_valid(slot):
					slot.z_index = 0
			)
		else:
			tw.set_parallel(true)
			tw.tween_property(card_panel, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_panel, "rotation_degrees", 0.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.chain().tween_callback(func():
				if is_instance_valid(slot):
					slot.z_index = 0
			)
	)
	hit.pressed.connect(func():
		_play_sfx("ui_click")
		if entry.has("on_select") and entry["on_select"] is Callable:
			(entry["on_select"] as Callable).call()
		_open_card_collection_detail(entry)
	)
	return slot

func _build_48_card_fanned_ribbon(all_entries: Array[Dictionary]) -> Control:
	# Interactive 48-Card Fanned Deck Set ("40+ karet za sebou — když na ně najedu, tak se mi ukážou!")
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(1180, 226)
	holder.add_theme_stylebox_override("panel", _make_pill_style(Color(0.055, 0.045, 0.040, 0.96), Color(0.86, 0.68, 0.28, 0.88), 4))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	holder.add_child(vb)

	var info_lbl := Label.new()
	var cs := _is_cs()
	info_lbl.text = "🂠 CELÁ SADA KARET (48 KARET V ŘADĚ) — Najeď myší na libovolnou kartu v balíčku pro vytažení a otočení!" if cs else "🂠 FULL 48-CARD FANNED SET — Glide your mouse across the deck to pull out & reveal any card!"
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_font_override("font", _get_font(true))
	info_lbl.add_theme_font_size_override("font_size", 15)
	info_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	vb.add_child(info_lbl)

	var fan_canvas := Control.new()
	fan_canvas.custom_minimum_size = Vector2(1140, 174)
	fan_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	fan_canvas.set_meta("hov_idx", -1)
	vb.add_child(fan_canvas)

	fan_canvas.gui_input.connect(func(ev: InputEvent):
		var cnt := all_entries.size()
		if cnt == 0:
			return
		if ev is InputEventMouseMotion:
			var mx: float = (ev as InputEventMouseMotion).position.x
			var step_x := (fan_canvas.size.x - 110.0) / float(maxi(1, cnt - 1))
			var idx := clampi(int(round((mx - 55.0) / maxf(1.0, step_x))), 0, cnt - 1)
			if idx != int(fan_canvas.get_meta("hov_idx", -1)):
				fan_canvas.set_meta("hov_idx", idx)
				_play_sfx("card_hover", -13.0, 0.92 + float(idx) * 0.008)
				var he: Dictionary = all_entries[idx]
				var st_tag := (" [UNLOCKED]" if not cs else " [ODEMČENO]") if bool(he["unlocked"]) else (" [⛓ CHAINED]" if not cs else " [⛓ V ŘETĚZECH]")
				info_lbl.text = "✦ %s  •  %s%s" % [str(he["title"]), str(he["sub"]), st_tag]
				fan_canvas.queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var hi := int(fan_canvas.get_meta("hov_idx", -1))
			if hi >= 0 and hi < cnt:
				_play_sfx("ui_click")
				_open_card_collection_detail(all_entries[hi])
	)
	fan_canvas.mouse_exited.connect(func():
		fan_canvas.set_meta("hov_idx", -1)
		info_lbl.text = "🂠 CELÁ SADA KARET (48 KARET V ŘADĚ) — Najeď myší na libovolnou kartu v balíčku pro vytažení a otočení!" if cs else "🂠 FULL 48-CARD FANNED SET — Glide your mouse across the deck to pull out & reveal any card!"
		fan_canvas.queue_redraw()
	)
	fan_canvas.draw.connect(func():
		var cnt := all_entries.size()
		if cnt == 0:
			return
		var w := fan_canvas.size.x
		var step_x := (w - 110.0) / float(maxi(1, cnt - 1))
		var hov_i := int(fan_canvas.get_meta("hov_idx", -1))
		var base_sz := Vector2(82, 118)
		for pass_i in range(2):
			for i in range(cnt):
				var is_hov := (i == hov_i)
				if (pass_i == 0 and is_hov) or (pass_i == 1 and not is_hov):
					continue
				var e: Dictionary = all_entries[i]
				var ul := bool(e["unlocked"])
				var dist_h := absf(float(i - hov_i)) if hov_i >= 0 else 99.0
				var spread := 0.0
				if hov_i >= 0 and not is_hov and dist_h <= 4.0:
					spread = signf(float(i - hov_i)) * (26.0 / maxf(1.0, dist_h))
				var cx := 55.0 + float(i) * step_x + spread
				var cy := 98.0 + sin((float(i) / float(maxi(1, cnt - 1))) * PI) * (-12.0)
				if is_hov:
					cy = 74.0
				var sc := 1.36 if is_hov else (1.08 if dist_h == 1.0 else 1.0)
				var csz := base_sz * sc
				var r := Rect2(cx - csz.x * 0.5, cy - csz.y * 0.5, csz.x, csz.y)
				fan_canvas.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.48))
				var show_face := is_hov or collection_flip_all
				var ftex: Texture2D = e.get("tex", null)
				if show_face and ftex != null:
					fan_canvas.draw_texture_rect(ftex, r, false, Color.WHITE if ul else Color(0.42, 0.42, 0.46, 0.96))
				elif card_back_tex:
					fan_canvas.draw_texture_rect(card_back_tex, r, false, Color(0.92, 0.88, 0.80) if ul else Color(0.36, 0.36, 0.40))
				else:
					fan_canvas.draw_rect(r, Color(0.16, 0.14, 0.18))
				var rim_c: Color = e.get("col", Color(0.9, 0.7, 0.25)) if (is_hov or ul) else Color(0.35, 0.36, 0.40)
				fan_canvas.draw_rect(r, rim_c, false, 2.6 if is_hov else 1.5)
				if not ul:
					# Draw crossed iron chains on locked cards in the fan too!
					fan_canvas.draw_line(r.position + Vector2(4, 6), r.position + r.size - Vector2(4, 6), Color(0.56, 0.60, 0.68, 0.92), 2.6)
					fan_canvas.draw_line(Vector2(r.position.x + r.size.x - 4, r.position.y + 6), Vector2(r.position.x + 4, r.position.y + r.size.y - 6), Color(0.56, 0.60, 0.68, 0.92), 2.6)
					fan_canvas.draw_circle(r.position + r.size * 0.5, 5.5, Color(0.22, 0.24, 0.28, 0.98))
	)
	return holder

func _open_card_collection_detail(entry: Dictionary) -> void:
	_clear_active_collection_hover()
	if collection_detail_modal and arsenal_layer:
		collection_detail_modal.mouse_filter = Control.MOUSE_FILTER_STOP
		var backdrop := arsenal_layer.get_node_or_null("CollectionDetailBackdrop") as ColorRect
		if backdrop == null:
			backdrop = ColorRect.new()
			backdrop.name = "CollectionDetailBackdrop"
			backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
			backdrop.offset_left = 0
			backdrop.offset_top = 0
			backdrop.offset_right = 0
			backdrop.offset_bottom = 0
			backdrop.z_index = 89
			backdrop.color = Color(0.015, 0.012, 0.02, 0.72)
			backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
			backdrop.visible = false
			backdrop.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_play_sfx("ui_click")
					_close_animated_modal(collection_detail_modal)
			)
			arsenal_layer.add_child(backdrop)
			collection_detail_modal.visibility_changed.connect(func():
				if is_instance_valid(backdrop) and not collection_detail_modal.visible:
					backdrop.visible = false
			)
		backdrop.visible = true
		backdrop.modulate.a = 0.0
		var btw := backdrop.create_tween()
		btw.tween_property(backdrop, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var unlocked := bool(entry["unlocked"])
	var face_tex: Texture2D = entry.get("tex", null)
	var custom_kind := str(entry.get("custom_kind", ""))
	var det_custom := col_det_art.get_parent().get_node_or_null("DetailCustomArt") as Control if col_det_art and col_det_art.get_parent() else null
	if custom_kind != "" and det_custom:
		col_det_art.visible = false
		det_custom.visible = true
		det_custom.set_meta("entry", entry)
		det_custom.modulate = Color.WHITE if unlocked else Color(0.48, 0.48, 0.52, 0.95)
		det_custom.queue_redraw()
	else:
		if det_custom:
			det_custom.visible = false
		col_det_art.visible = true
		col_det_art.texture = face_tex if face_tex else card_back_tex
		col_det_art.modulate = Color.WHITE if unlocked else Color(0.42, 0.42, 0.46, 0.95)
	col_det_title.text = str(entry["title"])
	col_det_sub.text = str(entry["sub"])
	if bool(entry.get("mp_badge", false)):
		var src_info := str(entry.get("unlock_source", ""))
		var src_suffix := (" • " + src_info) if src_info != "" else ""
		col_det_badge.text = (_tr("✓ Unlocked (MP Ready)", "✓ Odemčeno (MP)") if unlocked else _tr("⛓ Locked", "⛓ Zamčeno")) + src_suffix
	else:
		col_det_badge.text = ("✓ UNLOCKED IN COLLECTION" if not _is_cs() else "✓ ODEMČENO VE SBÍRCE") if unlocked else ("⛓ CHAINED (LOCKED) — Win campaign matches or visit Bazaar to unlock!" if not _is_cs() else "⛓ ZAMČENO V ŘETĚZECH — Vyhraj zápasy v kampani nebo navštiv Obchod!")
	col_det_badge.add_theme_color_override("font_color", Color(0.46, 0.96, 0.62) if unlocked else Color(0.86, 0.62, 0.36))
	col_det_desc.text = str(entry["desc"])
	_open_animated_modal(collection_detail_modal)

func _make_pill_style(bg_col: Color, border_col: Color, bottom_lip: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.border_width_bottom = bottom_lip
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _rebuild_collection_view() -> void:
	if not collection_grid or not collection_decks_box:
		return
	_clear_active_collection_hover()
	if not collection_grid.has_meta("_hover_clear_bound"):
		collection_grid.set_meta("_hover_clear_bound", true)
		collection_grid.mouse_exited.connect(func():
			_clear_active_collection_hover()
		)
	if deck_modal and not deck_modal.has_meta("_hover_clear_bound"):
		deck_modal.set_meta("_hover_clear_bound", true)
		deck_modal.visibility_changed.connect(func():
			if not deck_modal.visible:
				_clear_active_collection_hover()
		)
	var cs := _is_cs()
	var lang := "cs" if cs else "en"
	if collection_title_lbl:
		collection_title_lbl.text = "SBÍRKA KARET & ARZENÁL" if cs else "ARSENAL & CARD COLLECTION"
	if collection_flip_btn:
		collection_flip_btn.text = _tr("Turn Back", "Otočit zpět") if collection_flip_all else _tr("Flip All", "Otočit vše")
	if collection_close_btn:
		collection_close_btn.text = _tr("✕ Close [ESC]", "✕ Zavřít [ESC]")
	if collection_det_close_btn:
		collection_det_close_btn.text = _tr("Close Card", "Zavřít kartu")
	var ul_arr: Array = run_profile.get("unlocked_cards", Catalog.DEFAULT_UNLOCKED_CARDS)
	var total_cards := 32 + Catalog.POWER_CARDS.size()
	var unlocked_cnt := 0
	for k in ul_arr:
		unlocked_cnt += 1
	if collection_stats_lbl:
		collection_stats_lbl.text = "%d / %d %s" % [mini(unlocked_cnt, total_cards), total_cards, "Odemčeno" if cs else "Unlocked"]

	var vis_rel_cnt := Catalog.get_visible_relics().size()
	var pwr_cnt := Catalog.POWER_CARDS.size()
	var tab_labels := ["Klasické karty (32)", "Mocné karty (%d)" % pwr_cnt, "Sady balíčků (5)", "Relikvie (%d) & Meče" % vis_rel_cnt, "🛠 Deck Builder & Bankai"] if cs else ["Classic Cards (32)", "Power Cards (%d)" % pwr_cnt, "Choose Deck (5)", "Relics (%d) & Blades" % vis_rel_cnt, "🛠 Deck Builder & Bankai"]
	for ti in range(collection_tab_btns.size()):
		var tb: Button = collection_tab_btns[ti]
		if is_instance_valid(tb):
			if ti < tab_labels.size():
				tb.text = tab_labels[ti]
			var act := (ti == collection_tab_idx)
			tb.add_theme_stylebox_override("normal", _make_pill_style(Color(0.28, 0.20, 0.08, 0.98) if act else Color(0.11, 0.09, 0.08, 0.94), Color(1.0, 0.84, 0.34) if act else Color(0.56, 0.42, 0.22), 4 if act else 3))
			tb.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72) if act else Color(0.84, 0.78, 0.66))

	for c in collection_grid.get_children():
		c.queue_free()
	for c in collection_decks_box.get_children():
		c.queue_free()
	if collection_blades_box:
		for c in collection_blades_box.get_children():
			c.queue_free()
		collection_blades_box.visible = false

	collection_grid.visible = (collection_tab_idx != 4)
	collection_decks_box.visible = (collection_tab_idx == 0 or collection_tab_idx == 1)
	if is_instance_valid(collection_deck_builder):
		collection_deck_builder.visible = (collection_tab_idx == 4)
	if collection_flip_btn:
		collection_flip_btn.visible = (collection_tab_idx != 4)

	var suit_map := ({"CERVEN": "Srdce ♥", "ZELEN": "Listí ♠", "ZALUD": "Žaludy ♣", "GULA": "Koule ●"} if cs else {"CERVEN": "Hearts ♥", "ZELEN": "Leaves ♠", "ZALUD": "Acorns ♣", "GULA": "Bells ●"})
	var rank_names := ({"7": "Sedma (7)", "8": "Osma (8 ∞)", "9": "Devítka (9)", "10": "Desítka (10)", "D": "Spodek (D)", "H": "Svršek (H)", "K": "Král (K)", "E": "Eso (E)"} if cs else {"7": "Seven (7)", "8": "Eight (8 ∞)", "9": "Nine (9)", "10": "Ten (10)", "D": "Jack (D)", "H": "Queen (H)", "K": "King (K)", "E": "Ace (E)"})
	var pts_map := {"7": 7, "8": 8, "9": 9, "10": 10, "D": 12, "H": 16, "K": 18, "E": 20}
	var rank_rules_en := {
		"7": "Seven Attack: Rival draws +2 cards (stackable). If Rival fails to block with a 7 and draws, you score 3× Points (21 pts total per 7)!",
		"8": "Infinity Chain (∞): Chain Linker that can stack any number of copies in one hand! Every 8 adds its points and combo Mult.",
		"9": "Soul Conduit: Drains Rival score (-9+), adds +1 Mage Charge to Mage cards in hand, and grants +1 Redraw.",
		"10": "Guild Bullion: Mints +10g Florins and grants +0.5× Flat Mult.",
		"D": "Jack Guard: Grants +1 Iron Shield (blocks HP damage & curses) and armor-pierce bonus Chips.",
		"H": "Wild Queen: Playable on any card to change the active table Suit (Hearts, Bells, Leaves, Acorns).",
		"K": "Royal Challenge: Inflicts 1–3 ♥ HP Damage & Suit Curse on Rival unless countered by a King!",
		"E": "Ace Strike: Stack up to 3 Aces (max 3!): 1 Ace = 1 ♥ HP DMG, 2 Aces = 4 ♥ HP DMG, 3 Aces = 6 ♥ HP DMG + Stuns Rival!",
	}
	var rank_rules_cs := {
		"7": "Sedmový útok: Soupeř bere +2 karty (lze přebít další 7). Pokud soupeř musí lízat, získáš 3× bodů (21 b. za sedmu)!",
		"8": "Nekonečný řetěz (∞): Karta, kterou můžeš vyložit v libovolném počtu najednou! Každá přičte body i kombo násobitel.",
		"9": "Vodič duše: Vysaje soupeře (-9+), nabije +1 Mage Charge kartám v ruce a přidá +1 výměnu karet.",
		"10": "Cechovní zlato: Vyrazí +10g Zlatých a přidá +0.5× násobitel.",
		"D": "Strážce (Spodek): Přidá +1 Železný štít (kryje HP poškození i kletby) a průrazné body.",
		"H": "Změna barvy (Svršek): Lze zahrát na cokoli a přepnout aktivní barvu stolu.",
		"K": "Královský útok: Způsobí 1–3 ♥ HP poškození a kletbu podle barvy, pokud soupeř neodpoví Králem!",
		"E": "Úder Esa: Zahrát lze 1 až 3 Esa (max 3!): 1 Eso = 1 ♥ HP DMG, 2 Esa = 4 ♥ HP DMG, 3 Esa = 6 ♥ HP DMG + Stopka!",
	}
	var ce: Dictionary = run_profile.get("card_editions", {})

	# Build unified 48-card entry list for the interactive 48-card Fanned Ribbon at top!
	var classic_entries: Array[Dictionary] = []
	var power_entries: Array[Dictionary] = []
	for s in LOBBY_SUITS:
		var s_id := str(s["id"])
		for r_id in LOBBY_RANKS:
			var ck := "%s_%s" % [s_id, r_id]
			var cls_id := Catalog.normalize_card_class(str(ce.get(ck, "NORMAL")))
			var cls_d := Catalog.get_card_class_loc(cls_id, lang)
			var is_ul := ck in ul_arr
			var ab_desc := str((rank_rules_cs if cs else rank_rules_en).get(r_id, ""))
			if cls_id == "MERCHANT":
				ab_desc = ("Kupec: NEMÁ bojovou schopnost, ale vyrazí +16g!") if cs else ("Guildsman Merchant: Skips ability — mints +16g Florins!")
			var full_desc := "%s\n\n%s: %s\n%s" % [
				ab_desc,
				"Třída" if cs else "Class",
				str(cls_d["name"]),
				str(cls_d["desc"]),
			]
			classic_entries.append({
				"key": ck,
				"unlocked": is_ul,
				"tex": card_face_cache.get(ck, null),
				"col": cls_d["col"] if cls_id != "NORMAL" else s["col"],
				"cap": "%s [%d]" % [ck.replace("CERVEN_", "♥").replace("ZELEN_", "♠").replace("ZALUD_", "♣").replace("GULA_", "●"), int(pts_map.get(r_id, 8))],
				"title": "%s — %s" % [str(suit_map.get(s_id, s_id)), str(rank_names.get(r_id, r_id))],
				"sub": _tr("%d Base Pts • %s" % [int(pts_map.get(r_id, 8)), str(cls_d["name"])], "%d Základ bodů • %s" % [int(pts_map.get(r_id, 8)), str(cls_d["name"])]),
				"desc": full_desc,
			})
	for pc_raw in Catalog.POWER_CARDS:
		var pid := str(pc_raw["id"])
		var pc := Catalog.get_power_card_loc(pid, lang)
		var cls_id := Catalog.normalize_card_class(str(ce.get(pid, "NORMAL")))
		var cls_d := Catalog.get_card_class_loc(cls_id, lang)
		var is_ul := Catalog.is_power_card_unlocked(run_profile, pid) or (pid in ul_arr)
		var src_lbl := Catalog.get_unlock_source_label(pid, lang)
		power_entries.append({
			"key": pid,
			"unlocked": is_ul,
			"mp_badge": true,
			"unlock_source": src_lbl,
			"tex": card_face_cache.get(pid, null),
			"col": pc["accent"],
			"cap": "%s (+%d)" % [str(pc["short"]), int(pc["pts"])],
			"title": str(pc["name"]),
			"sub": _tr("%s • +%d Pts • %s", "%s • +%d b. • %s") % [str(suit_map.get(str(pc["suit"]), "")), int(pc["pts"]), str(pc["rarity"])],
			"desc": "%s\n\n%s\n%s: %s" % [str(pc["power_line"]), str(pc["desc"]), ("Třída" if cs else "Class"), str(cls_d["name"])],
		})

	if collection_tab_idx == 0 or collection_tab_idx == 1:
		var all_48: Array[Dictionary] = []
		all_48.append_array(classic_entries)
		all_48.append_array(power_entries)
		collection_decks_box.add_child(_build_48_card_fanned_ribbon(all_48))
		var target_list := classic_entries if collection_tab_idx == 0 else power_entries
		for e_card in target_list:
			collection_grid.add_child(_build_collection_card_slot(e_card))
	elif collection_tab_idx == 2:
		# Visual Fanned Card-Set Tiles for each of the 5 Decks (zero text bullet lists!)
		for i in range(PLAYER_DECKS.size()):
			var d: Dictionary = PLAYER_DECKS[i]
			var is_sel := (i == selected_deck_idx)
			var deck_idx_cap := i
			var d_name := _tr(str(d["name"]), str(d.get("name_cs", d["name"])))
			var d_desc := _tr(str(d["desc"]), str(d.get("desc_cs", d["desc"])))
			collection_grid.add_child(_build_collection_card_slot({
				"key": "DECK_" + str(d["id"]),
				"custom_kind": "deck",
				"raw_data": d,
				"unlocked": true,
				"equipped": is_sel,
				"tex": null,
				"col": d["border_col"],
				"cap": d_name,
				"title": d_name,
				"sub": _tr("✓ ACTIVE DECK" if is_sel else "CLICK TO EQUIP DECK", "✓ AKTIVNÍ BALÍČEK" if is_sel else "KLIKNUTÍM VYBER BALÍČEK"),
				"desc": d_desc,
				"on_select": func():
					selected_deck_idx = deck_idx_cap
					card_back_tex = Toon.tex(str(PLAYER_DECKS[selected_deck_idx].get("back_tex", "res://assets/table/card_back.png")))
					_rebuild_collection_view()
					_populate_menu_signs()
			}))
	elif collection_tab_idx == 4:
		if is_instance_valid(collection_deck_builder):
			collection_deck_builder.setup_builder(run_profile, lang, card_face_cache)
	else:
		# 8 Core Build Relics (4 Deck Builds × 2 Signature Relics) — click unlocked relics to toggle equip (max 2)!
		var owned_rel: Array = run_profile.get("active_relics", [])
		for r_raw in Catalog.RELICS:
			var rid := str(r_raw["id"])
			if Catalog.is_relic_hidden(rid):
				continue
			var r_art := Catalog.get_relic_art_path(rid)
			if not card_face_cache.has("ARSENAL_" + r_art) and ResourceLoader.exists(r_art):
				card_face_cache["ARSENAL_" + r_art] = Toon.tex(r_art)
			var r := Catalog.get_relic_loc(rid, lang)
			var is_own := Catalog.is_relic_unlocked(run_profile, rid) or (rid in owned_rel)
			var is_eq_r := rid in owned_rel
			var src_r := Catalog.get_unlock_source_label(rid, lang)
			var rid_cap := rid
			collection_grid.add_child(_build_collection_card_slot({
				"key": rid,
				"custom_kind": "relic",
				"raw_data": r,
				"unlocked": is_own,
				"equipped": is_eq_r,
				"mp_badge": true,
				"unlock_source": src_r,
				"tex": null,
				"col": r["col"],
				"cap": "⛓ %dg" % int(r["cost"]),
				"title": "✦ " + str(r["name"]),
				"sub": _tr("%s • %s", "%s • %s") % [str(r.get("category", "Build Relic")), _tr("✓ EQUIPPED (Click to Unequip)" if is_eq_r else ("UNLOCKED — Click to Equip (Max 2)" if is_own else ("Locked • Bazaar: %d 🪙" % int(r["cost"]))), "✓ VYBAVENO (Klikni pro odebrání)" if is_eq_r else ("ODEMČENO — Klikni pro výběr (Max 2)" if is_own else ("Zamčeno • Obchod: %d 🪙" % int(r["cost"]))))],
				"desc": str(r["desc"]),
				"on_select": func():
					if is_own:
						var arr: Array = run_profile.get("active_relics", []).duplicate()
						if rid_cap in arr:
							arr.erase(rid_cap)
						else:
							if arr.size() >= 2:
								arr.pop_front()
							arr.append(rid_cap)
						run_profile["active_relics"] = arr
						if run_profile.has("mp_loadout") and run_profile["mp_loadout"] is Dictionary:
							run_profile["mp_loadout"]["passive_relics"] = arr.slice(0, 2)
						Catalog.save_profile(run_profile)
						_rebuild_collection_view()
			}))
		# Visual Illustrated Cards for all 5 Blades
		var owned_sw: Array = run_profile.get("unlocked_swords", ["SWORD_IRON"])
		var eq_sw: String = str(run_profile.get("equipped_sword", "SWORD_IRON"))
		for sw_raw in Catalog.SWORD_SKINS:
			var sid := str(sw_raw["id"])
			var sw_art := Catalog.get_sword_art_path(sid)
			if not card_face_cache.has("ARSENAL_" + sw_art) and ResourceLoader.exists(sw_art):
				card_face_cache["ARSENAL_" + sw_art] = Toon.tex(sw_art)
			var sw := Catalog.get_sword_skin_loc(sid, lang)
			var is_own := sid in owned_sw
			var is_eq := (sid == eq_sw)
			collection_grid.add_child(_build_collection_card_slot({
				"key": sid,
				"custom_kind": "blade",
				"raw_data": sw,
				"unlocked": is_own,
				"equipped": is_eq,
				"tex": null,
				"col": sw["trail_col"],
				"cap": "⛓ %dg" % int(sw["cost"]),
				"title": "⚔ " + str(sw["name"]),
				"sub": _tr("✓ EQUIPPED BLADE" if is_eq else ("UNLOCKED — Click to Equip" if is_own else ("Locked Blade • Bazaar: %d 🪙" % int(sw["cost"]))), "✓ VYBAVENÁ ČEPEL" if is_eq else ("ODEMČENO — Klikni pro výběr" if is_own else ("Zamčeno • Obchod: %d 🪙" % int(sw["cost"])))),
				"desc": str(sw["desc"]),
				"on_select": func():
					if is_own:
						run_profile["equipped_sword"] = sid
						Catalog.save_profile(run_profile)
						_rebuild_collection_view()
			}))

func _build_options_modal() -> void:
	options_layer = CanvasLayer.new()
	options_layer.layer = 12
	add_child(options_layer)

	options_3d = LobbyOptions3DScript.new()
	options_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_3d.setup(_get_font(true), _get_font(false), _get_quill_font())
	options_layer.add_child(options_3d)
	options_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	options_3d.option_changed.connect(func(key: String, value: Variant):
		match key:
			"language":
				game_options["language"] = str(value)
				Catalog.save_options(game_options)
				_refresh_options_ui(true)
			"fullscreen":
				var fs := bool(value)
				game_options["fullscreen"] = fs
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
				if not fs:
					DisplayServer.window_set_size(Vector2i(1366, 768))
				Catalog.save_options(game_options)
				_refresh_options_ui(false)
			"visual_mode":
				var next_mode := int(value)
				game_options["visual_mode"] = next_mode
				Catalog.save_options(game_options)
				_apply_woodcut_mode(next_mode, true)
				_refresh_options_ui(false)
			"high_fx":
				game_options["high_fx"] = bool(value)
				Catalog.save_options(game_options)
				_refresh_options_ui(false)
			"game_pace":
				game_options["game_pace"] = str(value)
				Catalog.save_options(game_options)
				_refresh_options_ui(false)
			"turn_timer_sec":
				game_options["turn_timer_sec"] = clampi(int(value), 30, 45)
				Catalog.save_options(game_options)
				_refresh_options_ui(false)
			"cam_sensitivity":
				game_options["cam_sensitivity"] = float(value)
				Catalog.save_options(game_options)
				_refresh_options_ui(false)
	)
	options_3d.difficulty_toggled.connect(func():
		var cur_d := str(run_profile.get("campaign_difficulty", "traveler"))
		run_profile["campaign_difficulty"] = "classic" if cur_d == "traveler" else "traveler"
		Catalog.save_profile(run_profile)
		_update_campaign_card(selected_era_idx)
		_refresh_options_ui(false)
	)
	options_3d.mute_toggled.connect(func():
		_toggle_audio_mute()
		game_options["muted"] = audio_muted
		Catalog.save_options(game_options)
		_refresh_options_ui(false)
	)
	options_3d.volume_changed.connect(func(vol_pct: int):
		_set_audio_volume(vol_pct)
		game_options["sfx_volume"] = vol_pct
		Catalog.save_options(game_options)
		_refresh_options_ui(false)
	)
	options_3d.replay_tutorial_requested.connect(func():
		game_options["tutorial_done"] = false
		Catalog.save_options(game_options)
		options_3d.close_3d()
		_play_transition_to(func(): _launch_era_battle(0, true))
	)
	options_3d.return_requested.connect(func():
		options_3d.close_3d()
		if current_screen == ScreenState.MATCH_3D:
			_switch_to(ScreenState.WORLD_3D)
		elif current_screen == ScreenState.WORLD_3D:
			_switch_to(ScreenState.MAIN_MENU)
	)
	options_3d.close_requested.connect(func():
		if is_instance_valid(options_3d):
			options_3d.close_3d()
	)
	options_3d.sfx_requested.connect(func(sname: String):
		_play_sfx(sname)
	)
	_refresh_options_ui()

func _open_options_modal() -> void:
	_refresh_options_ui(false)
	if is_instance_valid(options_3d):
		options_3d.open_3d()

func _refresh_options_ui(full_rebuild: bool = true) -> void:
	var cs := _is_cs()
	if lobby_options_btn:
		lobby_options_btn.text = "⚙ NASTAVENÍ" if cs else "⚙ OPTIONS"
	if is_instance_valid(options_3d):
		var sk := "MAIN_MENU"
		if current_screen == ScreenState.MATCH_3D:
			sk = "MATCH_3D"
		elif current_screen == ScreenState.WORLD_3D:
			sk = "WORLD_3D"
		options_3d.sync_state(game_options, run_profile, audio_muted, audio_volume_pct, sk)
	if battle_3d and battle_3d.has_method("apply_options"):
		battle_3d.apply_options(game_options)
	if full_rebuild:
		_populate_menu_signs()
		_rebuild_collection_view()
		_refresh_map_ui_texts()
		_update_campaign_card(selected_era_idx)
		_refresh_map_roguelite_hud()

func _play_transition_to(on_mid: Callable) -> void:
	if not is_instance_valid(transition_curtain):
		on_mid.call()
		return
	transition_curtain.visible = true
	transition_curtain.color = Color(0.03, 0.05, 0.04, 0.0)
	var tw := transition_curtain.create_tween()
	tw.tween_property(transition_curtain, "color:a", 0.94, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(on_mid)
	tw.tween_property(transition_curtain, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(transition_curtain):
			transition_curtain.visible = false
	)

func _populate_menu_signs() -> void:
	if not is_instance_valid(signs_box):
		return
	for c in signs_box.get_children():
		c.queue_free()
	menu_sign_visuals.clear()
	var cs := _is_cs()

	# Hero row: CAMPAIGN + TUTORIAL side by side on top (no subtitle clutter!)
	var hero_row := HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 18)
	signs_box.add_child(hero_row)

	hero_row.add_child(_create_wooden_sign(
		"KAMPAŇ" if cs else "CAMPAIGN",
		0,
		false,
		Vector2(452, 108),
		44.0,
		38,
		true,
		func(): _switch_to(ScreenState.WORLD_3D),
		true
	))

	var tut_sign := _create_wooden_sign(
		"TUTORIÁL" if cs else "TUTORIAL",
		3,
		false,
		Vector2(252, 94),
		34.0,
		25,
		true,
		func():
			_play_transition_to(func(): _launch_era_battle(0, true))
	)
	tut_sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_row.add_child(tut_sign)

	# Three crisp sub-planks underneath
	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 18)
	signs_box.add_child(sub_row)

	sub_row.add_child(_create_wooden_sign(
		"SBÍRKA KARET" if cs else "ARSENAL",
		1,
		false,
		Vector2(268, 82),
		34.0,
		22,
		false,
		func():
			_play_sfx("ui_click")
			_open_collection_modal(0)
	))
	var mp_unlocked := MpConfig.is_test_mp_available()
	sub_row.add_child(_create_wooden_sign(
		"VÍCE HRÁČŮ" if cs else "MULTIPLAYER",
		2,
		not mp_unlocked,
		Vector2(268, 82),
		32.0,
		20,
		mp_unlocked,
		func():
			var entry: Node = mp_entry if is_instance_valid(mp_entry) else get_node_or_null("MpDevEntry")
			if is_instance_valid(entry) and entry.has_method("open_lobby"):
				entry.call("open_lobby")
	))
	sub_row.add_child(_create_wooden_sign(
		"RYCHLÁ HRA" if cs else "SKIRMISH",
		3,
		false,
		Vector2(268, 82),
		34.0,
		22,
		true,
		func():
			_play_transition_to(func():
				var test_era: Dictionary = ERAS_DATA[2]
				var q_loadout := _build_roguelite_loadout_for_era(test_era, true)
				battle_3d.start_3d_battle(test_era, PLAYER_DECKS[selected_deck_idx], false, q_loadout)
				_switch_to(ScreenState.MATCH_3D)
			)
	))

func _create_wooden_sign(label_text: String, icon_idx: int, is_locked: bool, sign_size: Vector2, icon_px: float, title_font_px: int, show_arrow: bool, on_click: Callable, skip_click_anim: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = sign_size

	var visual := Control.new()
	visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	visual.pivot_offset = sign_size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.set_meta("phase", float(menu_sign_visuals.size()) * 1.45)
	visual.set_meta("hovered", false)
	holder.add_child(visual)
	menu_sign_visuals.append(visual)

	var sign_tex := Toon.tex("res://assets/lobby/sign_wood_locked.png" if is_locked else "res://assets/lobby/sign_wood.png")
	if sign_tex:
		var img := TextureRect.new()
		img.texture = sign_tex
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(img)
	else:
		visual.draw.connect(func():
			var wood_col := Color(0.28, 0.18, 0.10) if not is_locked else Color(0.18, 0.15, 0.13)
			var border_col := Color(0.62, 0.42, 0.22) if not is_locked else Color(0.35, 0.32, 0.30)
			visual.draw_rect(Rect2(4, 4, sign_size.x - 8, sign_size.y - 8), wood_col, true)
			visual.draw_rect(Rect2(4, 4, sign_size.x - 8, sign_size.y - 8), border_col, false, 3.0)
		)

	# Vycentrovaný obsah [ikona] + NÁZOV + [šípka →] bez nalepenia na okraj
	var content_row := HBoxContainer.new()
	content_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_row.add_theme_constant_override("separation", 14 if sign_size.y > 95.0 else 10)
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(content_row)

	if menu_icons_tex and icon_idx >= 0 and icon_idx < 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = menu_icons_tex
		var iw := menu_icons_tex.get_width() / 4.0
		atlas.region = Rect2(iw * float(icon_idx), 0, iw, menu_icons_tex.get_height())
		var icon_rect := TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = atlas
		icon_rect.custom_minimum_size = Vector2(icon_px, icon_px)
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.modulate = Color(0.65, 0.62, 0.58) if is_locked else Color.WHITE
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_row.add_child(icon_rect)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", _get_font(true))
	lbl.add_theme_font_size_override("font_size", title_font_px)
	lbl.add_theme_color_override("font_color", Color(0.64, 0.60, 0.54) if is_locked else Color(0.98, 0.90, 0.72))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	lbl.add_theme_constant_override("outline_size", 6)
	content_row.add_child(lbl)

	var arrow_holder := Control.new()
	arrow_holder.custom_minimum_size = Vector2(32 if show_arrow else 0, sign_size.y)
	arrow_holder.size_flags_vertical = Control.SIZE_FILL
	arrow_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arrow_bevel: Label = null
	var arrow_lbl: Label = null
	if show_arrow and not is_locked:
		# Lowered, wood-carved chisel groove arrow aligned with the LialoDisplay baseline
		arrow_bevel = Label.new()
		arrow_bevel.text = "➜"
		arrow_bevel.set_anchors_preset(Control.PRESET_FULL_RECT)
		arrow_bevel.offset_left = 3.0
		arrow_bevel.offset_top = 7.0
		arrow_bevel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow_bevel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_bevel.add_theme_font_size_override("font_size", int(float(title_font_px) * 0.78))
		arrow_bevel.add_theme_color_override("font_color", Color(0.72, 0.54, 0.28, 0.72))
		arrow_holder.add_child(arrow_bevel)

		arrow_lbl = Label.new()
		arrow_lbl.text = "➜"
		arrow_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		arrow_lbl.offset_left = 2.0
		arrow_lbl.offset_top = 5.0
		arrow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_lbl.add_theme_font_size_override("font_size", int(float(title_font_px) * 0.78))
		arrow_lbl.add_theme_color_override("font_color", Color(0.13, 0.07, 0.02, 0.94))
		arrow_lbl.add_theme_color_override("font_outline_color", Color(0.58, 0.40, 0.18, 0.65))
		arrow_lbl.add_theme_constant_override("outline_size", 2)
		arrow_holder.add_child(arrow_lbl)
		content_row.add_child(arrow_holder)

	var btn := Button.new()
	btn.flat = true
	btn.disabled = is_locked
	btn.text = ""
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("disabled", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)

	btn.mouse_entered.connect(func():
		visual.set_meta("hovered", true)
		_play_sfx("ui_hover", -10.0)
		var tw := visual.create_tween().set_parallel(true)
		if is_locked:
			tw.tween_property(visual, "rotation_degrees", 1.8, 0.06)
			tw.chain().tween_property(visual, "rotation_degrees", -1.8, 0.07)
			tw.chain().tween_property(visual, "rotation_degrees", 0.0, 0.08)
		else:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
			tw.tween_property(visual, "scale", Vector2(1.05, 1.05), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(visual, "modulate", Color(1.12, 1.08, 1.02, 1.0), 0.16)
			tw.tween_property(visual, "rotation_degrees", -1.1, 0.12)
			if arrow_lbl:
				arrow_lbl.add_theme_color_override("font_color", Color(0.24, 0.13, 0.03, 0.96))
				arrow_lbl.add_theme_color_override("font_outline_color", Color(0.98, 0.78, 0.36, 0.85))
				tw.tween_property(arrow_lbl, "offset_left", 7.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if arrow_bevel:
					tw.tween_property(arrow_bevel, "offset_left", 8.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		visual.set_meta("hovered", false)
		if not is_locked:
			lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.72))
		var tw := visual.create_tween().set_parallel(true)
		tw.tween_property(visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(visual, "modulate", Color.WHITE, 0.18)
		if arrow_lbl:
			arrow_lbl.add_theme_color_override("font_color", Color(0.13, 0.07, 0.02, 0.94))
			arrow_lbl.add_theme_color_override("font_outline_color", Color(0.58, 0.40, 0.18, 0.65))
			tw.tween_property(arrow_lbl, "offset_left", 2.0, 0.16).set_trans(Tween.TRANS_QUAD)
			if arrow_bevel:
				tw.tween_property(arrow_bevel, "offset_left", 3.0, 0.16).set_trans(Tween.TRANS_QUAD)
	)
	btn.pressed.connect(func():
		_play_sfx("ui_click", -5.5)
		if skip_click_anim:
			visual.scale = Vector2.ONE
			visual.rotation_degrees = 0.0
			on_click.call()
			return
		var tw := visual.create_tween().set_parallel(true)
		tw.tween_property(visual, "scale", Vector2(1.09, 1.09) if show_arrow else Vector2(0.97, 0.97), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if arrow_lbl:
			tw.tween_property(arrow_lbl, "offset_left", 26.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_property(arrow_lbl, "modulate:a", 0.0, 0.14)
		tw.chain().tween_callback(func():
			if is_instance_valid(visual):
				visual.scale = Vector2.ONE
			if is_instance_valid(arrow_lbl):
				arrow_lbl.offset_left = 2.0
				arrow_lbl.modulate.a = 1.0
		)
		on_click.call()
	)
	holder.add_child(btn)
	return holder

# ----------------------------------------------------------------------------
# LOBBY KARTOVÉ ANIMÁCIE (7 striedajúcich sa epických 2D animácií s väčšími kartami!)
# 0: Solitaire kaskáda so stopou            1: Anatomické rukavice miešajú karty
# 2: Levitujúci dvojitý astroláb            3: Krupiérske rozdávanie
# 4: Kartový víchor cez stôl                5: 2D Rytíř přeskočí z karty do druhé a bojuje!
# 6: 2D Alchymistický souboj Draka a Mága mezi kartami!
# ----------------------------------------------------------------------------
const LOBBY_PHASE_DUR := 7.0
const LOBBY_PHASE_CNT := 7

func _spawn_lobby_intro_cards(vp: Vector2) -> void:
	lobby_intro_cards.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 202611
	var cen := Vector2(vp.x * 0.5, vp.y * 0.56)
	for i in range(28):
		var side := -1.0 if (i % 2 == 0) else 1.0
		var tier := float(i % 7) / 6.0
		var target_x := cen.x + side * lerpf(135.0, vp.x * 0.45, tier) + rng.randf_range(-28.0, 28.0)
		var ground_y := lerpf(vp.y * 0.62, vp.y * 0.88, rng.randf_range(0.0, 1.0))
		lobby_intro_cards.append({
			"origin": cen + Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-16.0, 16.0)),
			"target_x": target_x,
			"ground_y": ground_y,
			"peak_y": rng.randf_range(vp.y * 0.14, vp.y * 0.42),
			"delay": float(i) * 0.022,
			"dur": rng.randf_range(0.68, 0.94),
			"hop_amp": rng.randf_range(44.0, 88.0),
			"rot_start": rng.randf_range(-1.8, 1.8),
			"rot_end": side * rng.randf_range(0.10, 0.55),
			"flip_spd": rng.randf_range(4.5, 8.5),
			"suit": LOBBY_SUITS[i % LOBBY_SUITS.size()],
			"rank": _pick_lobby_card_rank(i),
		})

func _draw_lobby_sun_backdrop() -> void:
	if not is_instance_valid(lobby_sun_canvas):
		return
	var rect := lobby_sun_canvas.get_viewport_rect()
	var w := maxf(1.0, rect.size.x)
	var h := maxf(1.0, rect.size.y)
	var t := Time.get_ticks_msec() * 0.001

	var sun_prog := 1.0
	if lobby_intro_active:
		sun_prog = ease(clampf((lobby_intro_time - 0.55) / 0.95, 0.0, 1.0), 0.36)

	var sun_y_uv := lerpf(0.52, 0.255, sun_prog)
	if is_instance_valid(lobby_sun_rect) and lobby_sun_mat:
		lobby_sun_rect.visible = sun_prog > 0.01
		lobby_sun_mat.set_shader_parameter("sun_prog", sun_prog)
		lobby_sun_mat.set_shader_parameter("sun_center_uv", Vector2(0.5, sun_y_uv))
		lobby_sun_mat.set_shader_parameter("aspect_ratio", w / h)

	if sun_prog <= 0.01:
		return

	# Gentle rising golden ember dust motes floating over the smooth GPU sun bloom
	for m_i in range(28):
		var mx := fmod(float(m_i) * 97.3 + sin(t * 0.7 + float(m_i)) * 28.0, w)
		var my_u := 1.0 - fmod(t * (0.04 + fmod(float(m_i) * 0.013, 0.04)) + float(m_i) * 0.11, 1.0)
		var my := my_u * h
		var ma := sin(my_u * PI) * 0.44 * sun_prog
		var mr := 1.3 + fmod(float(m_i) * 0.55, 1.8)
		lobby_sun_canvas.draw_circle(Vector2(mx, my), mr * 1.9, Color(1.0, 0.80, 0.34, ma * 0.25))
		lobby_sun_canvas.draw_circle(Vector2(mx, my), mr, Color(1.0, 0.88, 0.48, ma))

func _pick_lobby_card_rank(seed_idx: int = -1) -> String:
	var pc_list: Array = Catalog.POWER_CARDS
	if seed_idx >= 0:
		if (seed_idx % 5 == 0) and not pc_list.is_empty():
			var item: Dictionary = pc_list[int(seed_idx / 5) % pc_list.size()]
			return str(item.get("id", "7"))
		return str(LOBBY_RANKS[(seed_idx * 3) % LOBBY_RANKS.size()])
	if (randi() % 5 == 0) and not pc_list.is_empty():
		var r_item: Dictionary = pc_list[randi() % pc_list.size()]
		return str(r_item.get("id", "7"))
	return str(LOBBY_RANKS[randi() % LOBBY_RANKS.size()])

func _update_lobby_card_animations(delta: float) -> void:
	if lobby_intro_active:
		lobby_intro_time += delta
		if lobby_intro_cards.is_empty() and lobby_fx_canvas:
			_spawn_lobby_intro_cards(lobby_fx_canvas.get_viewport_rect().size)
		if is_instance_valid(lobby_dark_veil):
			var veil_a := clampf(1.0 - (lobby_intro_time - 0.04) / 0.55, 0.0, 0.96)
			lobby_dark_veil.color.a = veil_a
			lobby_dark_veil.visible = (veil_a > 0.01)
		if lobby_intro_time >= 3.45:
			lobby_intro_active = false
			if is_instance_valid(lobby_dark_veil):
				lobby_dark_veil.visible = false

	if is_instance_valid(lobby_sun_canvas):
		lobby_sun_canvas.queue_redraw()

	# Kontinuálna kartová slučka začne hladko nadväzovať na otváracie prsknutie
	if not lobby_intro_active or lobby_intro_time >= 1.90:
		lobby_anim_time += delta
	var cycle := LOBBY_PHASE_DUR * float(LOBBY_PHASE_CNT)
	var ct := fmod(lobby_anim_time, cycle)
	var phase := int(ct / LOBBY_PHASE_DUR) % LOBBY_PHASE_CNT
	var phase_t := fmod(ct, LOBBY_PHASE_DUR)
	var vp := lobby_fx_canvas.get_viewport_rect().size if lobby_fx_canvas else Vector2(1280, 720)

	if phase != lobby_prev_phase:
		lobby_prev_phase = phase
		showcase_cards.clear()
		showcase_spawn_accum = 0.25
		shuffle_cards.clear()
		shuffle_spawn_accum = 0.18
		if phase == 1:
			_play_sfx("card_shuffle", -11.0, 0.98)

	if phase == 0:
		# 0: Vylepšená Solitaire Kaskáda Kariet — odrážajúce sa karty s plynulou hodvábnou stopou po dopade na stôl!
		showcase_spawn_accum += delta
		if showcase_spawn_accum >= 0.22 and phase_t < 6.0:
			showcase_spawn_accum = 0.0
			var side := -1.0 if (randi() % 2 == 0) else 1.0
			var origin := Vector2(vp.x * (0.13 if side < 0 else 0.87), vp.y * randf_range(0.18, 0.34))
			var vx := side * -randf_range(190.0, 340.0)
			var vy := randf_range(-240.0, -70.0)
			showcase_cards.append({
				"pos": origin,
				"vel": Vector2(vx, vy),
				"rot": randf_range(-0.35, 0.35),
				"vrot": randf_range(-2.1, 2.1),
				"flip": randf_range(0.0, TAU),
				"suit": LOBBY_SUITS[randi() % LOBBY_SUITS.size()],
				"rank": _pick_lobby_card_rank(),
				"age": 0.0,
				"trail": [],
				"bounces": 0,
			})
		var floor_y := vp.y * 0.89
		for c in showcase_cards:
			c["age"] = float(c["age"]) + delta
			var tr: Array = c["trail"]
			tr.append({
				"pos": c["pos"],
				"rot": float(c["rot"]),
				"flip_cos": cos(float(c["flip"])),
			})
			if tr.size() > 11:
				tr.pop_front()
			var v: Vector2 = c["vel"]
			v.y += 690.0 * delta
			var next_pos: Vector2 = c["pos"] + v * delta
			if next_pos.y >= floor_y and v.y > 0.0 and int(c["bounces"]) < 4:
				next_pos.y = floor_y
				v.y = -absf(v.y) * 0.78
				v.x *= 0.96
				c["bounces"] = int(c["bounces"]) + 1
			c["vel"] = v
			c["pos"] = next_pos
			c["rot"] = float(c["rot"]) + float(c["vrot"]) * delta
			c["flip"] = float(c["flip"]) + delta * 3.4
		for i in range(showcase_cards.size() - 1, -1, -1):
			var p: Vector2 = showcase_cards[i]["pos"]
			if p.y > vp.y + 180.0 or p.x < -190.0 or p.x > vp.x + 190.0:
				showcase_cards.remove_at(i)

	elif phase == 1:
		# 1: Detailné rukavice miešajú hustejší prúd veľkých kariet mostíkovým oblúkom
		shuffle_spawn_accum += delta
		if shuffle_spawn_accum >= 0.062 and phase_t > 0.35 and phase_t < 6.2:
			shuffle_spawn_accum = 0.0
			var dir := 1.0 if (randi() % 2 == 0) else -1.0
			shuffle_cards.append({
				"p": 0.0,
				"dir": dir,
				"speed": randf_range(1.08, 1.42),
				"arc": randf_range(165.0, 265.0),
				"suit": LOBBY_SUITS[randi() % LOBBY_SUITS.size()],
				"rank": _pick_lobby_card_rank(),
			})
		for i in range(shuffle_cards.size() - 1, -1, -1):
			shuffle_cards[i]["p"] = float(shuffle_cards[i]["p"]) + float(shuffle_cards[i]["speed"]) * delta
			if float(shuffle_cards[i]["p"]) >= 1.05:
				shuffle_cards.remove_at(i)

	if lobby_fx_canvas:
		lobby_fx_canvas.queue_redraw()

func _draw_lobby_card_showcase() -> void:
	if not lobby_fx_canvas:
		return
	var rect := lobby_fx_canvas.get_viewport_rect()
	var w := rect.size.x
	var h := rect.size.y
	var cycle := LOBBY_PHASE_DUR * float(LOBBY_PHASE_CNT)
	var ct := fmod(lobby_anim_time, cycle)
	var phase := int(ct / LOBBY_PHASE_DUR) % LOBBY_PHASE_CNT
	var phase_t := fmod(ct, LOBBY_PHASE_DUR)
	var fade := clampf(phase_t / 0.50, 0.0, 1.0) * clampf((LOBBY_PHASE_DUR - phase_t) / 0.65, 0.0, 1.0)
	if lobby_intro_active:
		fade *= clampf((lobby_intro_time - 1.90) / 0.85, 0.0, 1.0)
	var card_sz := Vector2(124.0, 178.0)

	# Úvodné prsknutie a poskočenie kariet z tmy (v prvých ~2.8s lobby intra!)
	if lobby_intro_active and lobby_intro_time < 3.05:
		var burst_fade := clampf((3.05 - lobby_intro_time) / 0.75, 0.0, 1.0)
		for ic in lobby_intro_cards:
			var t_c := lobby_intro_time - float(ic["delay"])
			if t_c <= 0.0:
				continue
			var dur := float(ic["dur"])
			var u := clampf(t_c / dur, 0.0, 1.0)
			var eu := ease(u, 0.42)
			var px := lerpf(ic["origin"].x, float(ic["target_x"]), eu)
			var py := 0.0
			if u < 0.72:
				var arc_u := u / 0.72
				py = lerpf(ic["origin"].y, float(ic["ground_y"]), arc_u) - sin(arc_u * PI) * (float(ic["ground_y"]) - float(ic["peak_y"]))
			else:
				# Dvojité elastické poskočenie pri dopade na plst stola!
				var bu := (u - 0.72) / 0.28
				var hop := absf(sin(bu * PI * 2.0)) * (1.0 - bu * 0.55) * float(ic["hop_amp"])
				py = float(ic["ground_y"]) - hop
			# Jemné dobežné poskočenie po dopade
			if t_c > dur and t_c < dur + 0.55:
				var after := (t_c - dur) / 0.55
				py -= absf(sin(after * PI * 1.5)) * (1.0 - after) * (float(ic["hop_amp"]) * 0.34)
			var rot_c := lerpf(float(ic["rot_start"]), float(ic["rot_end"]), eu)
			var flip_c := cos(t_c * float(ic["flip_spd"]))
			var sc_c := lerpf(0.32, 1.08, ease(clampf(u * 1.4, 0.0, 1.0), 0.35))
			_draw_lobby_card(Vector2(px, py), card_sz * sc_c, rot_c, flip_c, ic["suit"], str(ic["rank"]), 0.96 * burst_fade)

	if phase == 0:
		for c in showcase_cards:
			var sc := lerpf(0.86, 1.12, clampf(float(c["age"]) / 0.65, 0.0, 1.0))
			var tr: Array = c.get("trail", [])
			var tr_len := tr.size()
			for ti in range(tr_len):
				var snap: Dictionary = tr[ti]
				var u := float(ti + 1) / float(maxi(1, tr_len + 1))
				_draw_lobby_card(snap["pos"], card_sz * (sc * lerpf(0.90, 0.99, u)), float(snap["rot"]), float(snap["flip_cos"]), c["suit"], str(c["rank"]), 0.24 * u * fade)
			_draw_lobby_card(c["pos"], card_sz * sc, float(c["rot"]), cos(float(c["flip"])), c["suit"], str(c["rank"]), 0.96 * fade)

	elif phase == 1:
		var enter := ease(clampf(phase_t / 0.55, 0.0, 1.0), 0.4) * ease(clampf((LOBBY_PHASE_DUR - phase_t) / 0.55, 0.0, 1.0), 0.4)
		var ly := h * 0.76 + sin(phase_t * 14.0) * 6.5
		var ry := h * 0.76 + cos(phase_t * 14.0) * 6.5
		var lx := lerpf(-170.0, w * 0.135, enter)
		var rx := lerpf(w + 170.0, w * 0.865, enter)

		# Vrstvené balíčky kariet zovreté v rukách s pružným ohybom pri riffle-miešaní
		for st_k in range(4):
			var off := float(st_k) * 3.5
			var bend_l := sin(phase_t * 15.0 + float(st_k) * 0.4) * 0.04
			var bend_r := cos(phase_t * 15.0 + float(st_k) * 0.4) * 0.04
			_draw_lobby_card(Vector2(lx + 24.0 + off, ly - 24.0 - off * 0.6), card_sz, -0.22 + bend_l, -1.0, LOBBY_SUITS[st_k % 4], "7", 0.96 * fade)
			_draw_lobby_card(Vector2(rx - 24.0 - off, ry - 24.0 - off * 0.6), card_sz, 0.22 - bend_r, -1.0, LOBBY_SUITS[(st_k + 1) % 4], "E", 0.96 * fade)

		for sc in shuffle_cards:
			var p := clampf(float(sc["p"]), 0.0, 1.0)
			var dir := float(sc["dir"])
			var sx := lx + 42.0 if dir > 0.0 else rx - 42.0
			var ex := rx - 42.0 if dir > 0.0 else lx + 42.0
			var px := lerpf(sx, ex, p)
			var py := lerpf(ly - 28.0, ry - 28.0, p) - sin(p * PI) * float(sc["arc"])
			var flip_c := cos(p * PI * 3.0)
			var r_ang := sin(p * PI * 2.0) * 0.38 * dir
			lobby_fx_canvas.draw_circle(Vector2(px - dir * 18.0, py + 6.0), 3.4, Color(1.0, 0.84, 0.38, 0.38 * fade))
			_draw_lobby_card(Vector2(px, py), card_sz * 0.96, r_ang, flip_c, sc["suit"], str(sc["rank"]), fade)

		_draw_stylized_gloved_hand(Vector2(lx, ly), 1.0, fade, phase_t)
		_draw_stylized_gloved_hand(Vector2(rx, ry), -1.0, fade, phase_t + 1.1)

	elif phase == 2:
		# 2: Levitujúce veľké karty v dvoch naklonených astrolábových prstencoch okolo celej scény
		var total_cards := 24
		var cen := Vector2(w * 0.5, h * 0.50)
		lobby_fx_canvas.draw_arc(cen, w * 0.42, 0.0, TAU, 64, Color(0.92, 0.72, 0.28, 0.18 * fade), 2.0)
		var items := []
		for i in range(total_cards):
			var ang := phase_t * 0.55 + float(i) * (TAU / float(total_cards))
			var ring := (i % 2)
			var rx := w * (0.44 if ring == 0 else 0.35)
			var ry := h * (0.40 if ring == 0 else 0.26)
			var px := cen.x + cos(ang) * rx
			var py := cen.y + sin(ang) * ry + sin(phase_t * 2.2 + float(i)) * 14.0
			var depth := sin(ang)
			var scale_c := lerpf(0.76, 1.14, (depth + 1.0) * 0.5)
			var flip_c := sin(phase_t * 1.6 + float(i) * 0.85)
			items.append({
				"depth": depth,
				"pos": Vector2(px, py),
				"scale": scale_c,
				"flip": flip_c,
				"rot": cos(ang) * 0.28,
				"suit": LOBBY_SUITS[i % LOBBY_SUITS.size()],
				"rank": _pick_lobby_card_rank(i),
			})
		items.sort_custom(func(a, b): return float(a["depth"]) < float(b["depth"]))
		for it in items:
			var s: float = float(it["scale"])
			var alp := lerpf(0.58, 0.98, (float(it["depth"]) + 1.0) * 0.5) * fade
			_draw_lobby_card(it["pos"], card_sz * s, float(it["rot"]), float(it["flip"]), it["suit"], str(it["rank"]), alp)

	elif phase == 3:
		# 3: Krupiérske rozdávanie vejárom na 4 rohy stola & synchrónne otáčanie!
		var cen := Vector2(w * 0.5, h * 0.44)
		var corners := [
			Vector2(w * 0.14, h * 0.22),
			Vector2(w * 0.86, h * 0.22),
			Vector2(w * 0.15, h * 0.80),
			Vector2(w * 0.85, h * 0.80),
		]
		for k in range(24):
			var local_t := clampf((phase_t - float(k) * 0.11) / 0.85, 0.0, 1.0)
			if local_t <= 0.01:
				continue
			var seat: Vector2 = corners[k % 4]
			var idx_in_seat := int(k / 4)
			var dest := seat + Vector2((float(idx_in_seat) - 2.5) * 42.0, sin(float(idx_in_seat) * 0.6) * 14.0)
			var e := ease(local_t, 0.35)
			var pos := cen.lerp(dest, e) + Vector2(0.0, -sin(e * PI) * 55.0)
			var flip_c := cos((1.0 - e) * PI * 1.5)
			var rot_c := (float(idx_in_seat) - 2.5) * 0.13 * e
			_draw_lobby_card(pos, card_sz * lerpf(0.75, 1.02, e), rot_c, flip_c, LOBBY_SUITS[k % 4], _pick_lobby_card_rank(k + 3), 0.95 * fade)

	elif phase == 4:
		# 4: Veľký kartový víchor naprieč stolom v sínusových vlnách
		var count := 28
		for i in range(count):
			var spd := 0.22 + fmod(float(i) * 0.073, 0.18)
			var u := fmod(phase_t * spd + float(i) * 0.14, 1.18) - 0.09
			var px := lerpf(-140.0, w + 140.0, u)
			var lane_y := lerpf(h * 0.12, h * 0.90, fmod(float(i) * 0.29, 1.0))
			var py := lane_y + sin(u * TAU * 1.4 + float(i)) * 46.0
			var flip_c := cos(phase_t * 2.4 + float(i) * 0.9)
			var scale_c := 0.82 + 0.35 * sin(u * PI)
			_draw_lobby_card(Vector2(px, py), card_sz * scale_c, cos(u * PI) * 0.35, flip_c, LOBBY_SUITS[(i + 2) % 4], _pick_lobby_card_rank(i + 7), 0.92 * fade)

	elif phase == 5:
		# 5: 2D RYTÍŘSKÝ SOUBOJ MEZI KARTAMI — rytíř vyskočí z levé karty obloukem do pravé karty a šermuje s obráncem!
		_draw_lobby_phase_knight_card_duel(w, h, phase_t, fade, card_sz)

	else:
		# 6: 2D ALCHYMISTICKÝ SOUBOJ DRAKA A MÁGA MEZI KARTAMI — křížová palba plamenů, blesků a runových pečetí!
		_draw_lobby_phase_arcane_card_clash(w, h, phase_t, fade, card_sz)

func _draw_lobby_card(pos: Vector2, size: Vector2, rot: float, flip_cos: float, suit: Dictionary, rank: String, alpha: float, override_tex: Texture2D = null) -> void:
	if alpha <= 0.02:
		return
	var sx := maxf(0.06, absf(flip_cos))
	lobby_fx_canvas.draw_set_transform(pos, rot, Vector2(sx, 1.0))

	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var rect := Rect2(-hw, -hh, size.x, size.y)
	var is_power := rank.begins_with("SPEC_")

	# Hlboký chiaroscuro tieň pod kartou (+ arkánová žiara pre Power Cards)
	lobby_fx_canvas.draw_rect(Rect2(-hw + 7.0, -hh + 9.0, size.x, size.y), Color(0.0, 0.0, 0.0, 0.42 * alpha))
	if is_power and flip_cos >= 0.0:
		lobby_fx_canvas.draw_rect(rect.grow(3.5), Color(0.95, 0.72, 0.22, 0.38 * alpha), false, 3.0)

	var key := rank if is_power else ("%s_%s" % [suit["id"], rank])
	var face_tex: Texture2D = override_tex if override_tex != null else (card_face_cache.get(key, null) as Texture2D)
	if flip_cos >= 0.0:
		if face_tex != null:
			lobby_fx_canvas.draw_texture_rect(face_tex, rect, false, Color(1, 1, 1, alpha))
			var rim_col := Color(0.96, 0.78, 0.28, 0.88 * alpha) if is_power else Color(0.22, 0.15, 0.09, 0.92 * alpha)
			lobby_fx_canvas.draw_rect(rect, rim_col, false, 2.4 if is_power else 2.0)
		else:
			# Rovnaký dizajn karty ako v hre (bez generovania nových kariet)
			lobby_fx_canvas.draw_rect(rect, Color(0.95, 0.92, 0.85, alpha))
			lobby_fx_canvas.draw_rect(rect, Color(0.14, 0.11, 0.08, alpha), false, 2.6)
			lobby_fx_canvas.draw_rect(Rect2(-hw + 6, -hh + 6, size.x - 12, size.y - 12), Color(suit["col"].r, suit["col"].g, suit["col"].b, 0.75 * alpha), false, 2.0)
			if sx > 0.25:
				var df := _get_font(true)
				var c_col := Color(suit["col"].r, suit["col"].g, suit["col"].b, alpha)
				var crest_t := suit_crest_cache.get(str(suit["id"]), null) as Texture2D
				if crest_t != null:
					var top_c_sz := Vector2(size.x * 0.24, size.x * 0.24)
					lobby_fx_canvas.draw_texture_rect(crest_t, Rect2(Vector2(-hw + 8, -hh + 8), top_c_sz), false, Color(1, 1, 1, alpha))
					lobby_fx_canvas.draw_string(df, Vector2(-hw + 12 + top_c_sz.x, -hh + 28), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.x * 0.21), c_col)
					var mid_c_sz := Vector2(size.x * 0.52, size.x * 0.52)
					lobby_fx_canvas.draw_texture_rect(crest_t, Rect2(-mid_c_sz * 0.5 + Vector2(0, 6), mid_c_sz), false, Color(1, 1, 1, alpha))
				else:
					lobby_fx_canvas.draw_string(df, Vector2(-hw + 10, -hh + 28), str(suit["sym"]) + rank, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.x * 0.21), c_col)
					lobby_fx_canvas.draw_string(df, Vector2(-hw, 14), str(suit["sym"]), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size.x * 0.38), c_col)
	else:
		if card_back_tex:
			lobby_fx_canvas.draw_texture_rect(card_back_tex, rect, false, Color(1, 1, 1, alpha))
			lobby_fx_canvas.draw_rect(rect, Color(0.10, 0.08, 0.06, alpha), false, 2.6)
		else:
			lobby_fx_canvas.draw_rect(rect, Color(0.18, 0.22, 0.34, alpha))
			lobby_fx_canvas.draw_rect(rect, Color(0.85, 0.68, 0.30, alpha), false, 2.6)

	lobby_fx_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_stylized_gloved_hand(pos: Vector2, side_dir: float, alpha: float, anim_t: float = 0.0) -> void:
	if alpha <= 0.02:
		return
	var wrist_flex := sin(anim_t * 14.0) * 0.055
	lobby_fx_canvas.draw_set_transform(pos, side_dir * (-0.14 + wrist_flex), Vector2(side_dir * 1.24, 1.24))

	var leather := Color(0.50, 0.33, 0.19, alpha)
	var leather_hi := Color(0.67, 0.47, 0.29, alpha)
	var leather_sh := Color(0.31, 0.19, 0.11, alpha)
	var leather_deep := Color(0.21, 0.13, 0.08, alpha)
	var cuff_col := Color(0.25, 0.16, 0.11, alpha)
	var cuff_hi := Color(0.38, 0.25, 0.16, alpha)
	var sleeve_col := Color(0.14, 0.17, 0.22, alpha)
	var sleeve_sh := Color(0.08, 0.10, 0.14, alpha)
	var brass := Color(0.92, 0.74, 0.30, alpha)
	var brass_hi := Color(1.0, 0.90, 0.56, alpha)
	var ink := Color(0.06, 0.04, 0.03, alpha)
	var shadow := Color(0.0, 0.0, 0.0, 0.36 * alpha)

	# 0. Hlboký vrhnutý chiaroscuro tieň pod celou rukavicou a prstami
	var drop_shadow := PackedVector2Array([
		Vector2(-168, -14), Vector2(-42, -28), Vector2(36, -24),
		Vector2(76, -8), Vector2(72, 42), Vector2(18, 52), Vector2(-164, 38)
	])
	lobby_fx_canvas.draw_colored_polygon(drop_shadow, shadow)

	# 1. Prešívaný rukáv kabátca so záhybmi látky a drevorezovým šrafovaním
	var sleeve := PackedVector2Array([
		Vector2(-175, -25), Vector2(-135, -29), Vector2(-96, -31),
		Vector2(-94, 31), Vector2(-135, 29), Vector2(-175, 26)
	])
	lobby_fx_canvas.draw_colored_polygon(sleeve, sleeve_col)
	var sleeve_fold := PackedVector2Array([
		Vector2(-175, 6), Vector2(-95, 10), Vector2(-94, 31), Vector2(-175, 26)
	])
	lobby_fx_canvas.draw_colored_polygon(sleeve_fold, sleeve_sh)
	for h_i in range(6):
		var hx := -166.0 + float(h_i) * 12.0
		lobby_fx_canvas.draw_line(Vector2(hx, -24), Vector2(hx + 8.0, 24), Color(0.22, 0.26, 0.33, 0.45 * alpha), 1.6)
		lobby_fx_canvas.draw_line(Vector2(hx + 4.0, 8), Vector2(hx - 4.0, 26), ink, 1.4)
	lobby_fx_canvas.draw_polyline(sleeve + PackedVector2Array([sleeve[0]]), ink, 2.8)

	# 2. Dvojvrstvová zvonová kožená manžeta (gauntlet cuff) s remienkami, prackami a mosadznými nitmi
	var cuff_poly := PackedVector2Array([
		Vector2(-116, -36), Vector2(-78, -41), Vector2(-38, -38),
		Vector2(-32, 0), Vector2(-37, 38), Vector2(-78, 39), Vector2(-114, 33)
	])
	lobby_fx_canvas.draw_colored_polygon(cuff_poly, cuff_col)
	var cuff_top_hi := PackedVector2Array([
		Vector2(-112, -33), Vector2(-78, -38), Vector2(-40, -35),
		Vector2(-40, -12), Vector2(-110, -10)
	])
	lobby_fx_canvas.draw_colored_polygon(cuff_top_hi, cuff_hi)
	var cuff_bot_sh := PackedVector2Array([
		Vector2(-112, 10), Vector2(-38, 12), Vector2(-37, 37), Vector2(-114, 33)
	])
	lobby_fx_canvas.draw_colored_polygon(cuff_bot_sh, leather_deep)

	# Zdobené mosadzné lemovanie manžety + dvojica kožených sťahovacích remienkov s prackami
	lobby_fx_canvas.draw_polyline(PackedVector2Array([Vector2(-108, -30), Vector2(-78, -34), Vector2(-43, -32)]), brass, 2.4)
	lobby_fx_canvas.draw_polyline(PackedVector2Array([Vector2(-108, 27), Vector2(-78, 32), Vector2(-42, 31)]), brass, 2.2)
	for st_i in range(2):
		var sx := -92.0 + float(st_i) * 34.0
		var strap_r := Rect2(sx - 5.0, -37.0, 10.0, 74.0)
		lobby_fx_canvas.draw_rect(strap_r, leather_deep)
		lobby_fx_canvas.draw_rect(strap_r, ink, false, 1.8)
		# Mosadzná pracka s jazýčkom
		var b_rect := Rect2(sx - 7.0, 6.0, 14.0, 16.0)
		lobby_fx_canvas.draw_rect(b_rect, brass, false, 2.4)
		lobby_fx_canvas.draw_line(Vector2(sx - 6.0, 14.0), Vector2(sx + 5.0, 14.0), brass_hi, 2.0)
		# Mosadzný nit hore
		lobby_fx_canvas.draw_circle(Vector2(sx, -20.0), 4.2, ink)
		lobby_fx_canvas.draw_circle(Vector2(sx, -20.0), 3.0, brass)
		lobby_fx_canvas.draw_circle(Vector2(sx - 0.8, -20.8), 1.2, brass_hi)
	lobby_fx_canvas.draw_polyline(cuff_poly + PackedVector2Array([cuff_poly[0]]), ink, 3.0)

	# 3. Anatomicky tvarovaná dlaň & chrbát ruky (metacarpus, hypothenar oblúk, chrbtový chránič a šľachy)
	var palm := PackedVector2Array([
		Vector2(-40, -34), Vector2(-8, -38), Vector2(24, -35), Vector2(36, -24),
		Vector2(39, 4), Vector2(34, 28), Vector2(16, 40), Vector2(-18, 39), Vector2(-39, 32)
	])
	lobby_fx_canvas.draw_colored_polygon(palm, leather)
	var palm_hi := PackedVector2Array([
		Vector2(-35, -29), Vector2(-6, -34), Vector2(22, -31),
		Vector2(30, -16), Vector2(12, -4), Vector2(-32, -6)
	])
	lobby_fx_canvas.draw_colored_polygon(palm_hi, leather_hi)
	var palm_sh := PackedVector2Array([
		Vector2(-36, 14), Vector2(35, 10), Vector2(33, 28),
		Vector2(16, 40), Vector2(-18, 39), Vector2(-39, 32)
	])
	lobby_fx_canvas.draw_colored_polygon(palm_sh, leather_sh)

	# Všitý chrbtový kožený štítok s prešívaním a 3 anatomickými šľachovými líniami
	var dorsal_patch := PackedVector2Array([
		Vector2(-28, -22), Vector2(14, -23), Vector2(22, 0), Vector2(12, 22), Vector2(-28, 20)
	])
	lobby_fx_canvas.draw_colored_polygon(dorsal_patch, leather_sh)
	lobby_fx_canvas.draw_polyline(dorsal_patch + PackedVector2Array([dorsal_patch[0]]), ink, 1.8)
	for td_i in range(3):
		var ty := -12.0 + float(td_i) * 12.0
		lobby_fx_canvas.draw_line(Vector2(-20, ty), Vector2(18, ty - 1.5), leather_deep, 2.4)
		lobby_fx_canvas.draw_line(Vector2(-20, ty - 1.5), Vector2(16, ty - 3.0), leather_hi, 1.3)
	# Drevorezové tieňovacie vrásky na zápästí
	for wr_i in range(4):
		var wx := -36.0 + float(wr_i) * 3.5
		lobby_fx_canvas.draw_arc(Vector2(wx, 0.0), 26.0, -0.85, 0.85, 10, ink, 1.4)
	lobby_fx_canvas.draw_polyline(palm + PackedVector2Array([palm[0]]), ink, 3.0)

	# 4. Štyri 3-článkové artikulované prsty (Index, Middle, Ring, Pinky) s hánkami MCP, PIP, DIP a nechtovými špičkami
	var finger_ys := [-25.0, -9.5, 6.5, 22.0]
	var finger_lens := [44.0, 50.0, 46.0, 36.0]
	var finger_thicks := [11.2, 11.8, 11.0, 9.4]
	for f_i in range(4):
		var wave := sin(anim_t * 15.0 + float(f_i) * 1.05)
		var fy := float(finger_ys[f_i])
		var flen := float(finger_lens[f_i])
		var thick := float(finger_thicks[f_i])
		var base_x := 30.0 - absf(float(f_i) - 1.2) * 2.5

		var p0 := Vector2(base_x, fy)
		var a1 := -0.10 + float(f_i) * 0.055 + wave * 0.11
		var a2 := a1 + 0.16 + wave * 0.14
		var a3 := a2 + 0.18 + wave * 0.10
		var l1 := flen * 0.44
		var l2 := flen * 0.33
		var l3 := flen * 0.25
		var p1 := p0 + Vector2(cos(a1), sin(a1)) * l1
		var p2 := p1 + Vector2(cos(a2), sin(a2)) * l2
		var p3 := p2 + Vector2(cos(a3), sin(a3)) * l3

		var seg_col := leather if f_i < 2 else leather_sh
		var seg_hi := leather_hi if f_i < 2 else leather

		# Hánka MCP s mosadzným nitom
		lobby_fx_canvas.draw_circle(p0, thick * 0.58, ink)
		lobby_fx_canvas.draw_circle(p0, thick * 0.46, seg_hi)
		lobby_fx_canvas.draw_circle(p0 + Vector2(-2.0, -1.0), 2.4, brass)

		# 1. článok (Proximálna falanga)
		lobby_fx_canvas.draw_line(p0, p1, ink, thick + 3.4)
		lobby_fx_canvas.draw_line(p0, p1, seg_col, thick)
		lobby_fx_canvas.draw_line(p0 + Vector2(0, -thick * 0.24), p1 + Vector2(0, -thick * 0.22), seg_hi, thick * 0.35)

		# Kĺb PIP s koženými záhybmi
		lobby_fx_canvas.draw_circle(p1, thick * 0.48, ink)
		lobby_fx_canvas.draw_circle(p1, thick * 0.38, leather_deep)

		# 2. článok (Stredná falanga)
		var t2 := thick * 0.88
		lobby_fx_canvas.draw_line(p1, p2, ink, t2 + 3.2)
		lobby_fx_canvas.draw_line(p1, p2, seg_col, t2)
		lobby_fx_canvas.draw_line(p1 + Vector2(0, -t2 * 0.24), p2 + Vector2(0, -t2 * 0.22), seg_hi, t2 * 0.34)

		# Kĺb DIP
		lobby_fx_canvas.draw_circle(p2, t2 * 0.44, ink)
		lobby_fx_canvas.draw_circle(p2, t2 * 0.34, leather_deep)

		# 3. článok (Distálna falanga + zaoblená špička prsta a nechtové lôžko)
		var t3 := thick * 0.76
		lobby_fx_canvas.draw_line(p2, p3, ink, t3 + 3.0)
		lobby_fx_canvas.draw_line(p2, p3, seg_col, t3)
		lobby_fx_canvas.draw_circle(p3, t3 * 0.56, ink)
		lobby_fx_canvas.draw_circle(p3, t3 * 0.42, seg_hi)
		# Nechtový / švový detail na špičke
		var dir3 := (p3 - p2).normalized()
		var n_pos := p3 - dir3 * 2.0
		lobby_fx_canvas.draw_circle(n_pos, t3 * 0.26, leather_deep)

	# 5. Svalnatý vankúšik palca (Thenar eminence) + 3-článkový palec ohýbajúci vrchnú hranu kariet pri miešaní!
	var thenar_poly := PackedVector2Array([
		Vector2(-28, -18), Vector2(-18, -36), Vector2(6, -38),
		Vector2(12, -20), Vector2(-6, -8)
	])
	lobby_fx_canvas.draw_colored_polygon(thenar_poly, leather_hi)
	lobby_fx_canvas.draw_polyline(thenar_poly + PackedVector2Array([thenar_poly[0]]), ink, 2.2)

	var riffle_flick := sin(anim_t * 15.0) * 5.5
	var th0 := Vector2(-10.0, -28.0)
	var th1 := Vector2(10.0, -45.0 + riffle_flick * 0.35)
	var th2 := Vector2(31.0, -53.0 + riffle_flick * 0.85)
	var th3 := Vector2(46.0, -51.0 + riffle_flick * 1.15)

	# Metakarpálny a proximálny článok palca
	lobby_fx_canvas.draw_line(th0, th1, ink, 17.5)
	lobby_fx_canvas.draw_line(th0, th1, leather_hi, 13.5)
	lobby_fx_canvas.draw_circle(th1, 7.6, ink)
	lobby_fx_canvas.draw_circle(th1, 5.8, leather_deep)

	lobby_fx_canvas.draw_line(th1, th2, ink, 15.2)
	lobby_fx_canvas.draw_line(th1, th2, leather, 11.4)
	lobby_fx_canvas.draw_line(th1 + Vector2(0, -3), th2 + Vector2(0, -3), leather_hi, 4.0)
	lobby_fx_canvas.draw_circle(th2, 6.8, ink)
	lobby_fx_canvas.draw_circle(th2, 5.0, leather_deep)

	# Distálna špička palca s nechtom
	lobby_fx_canvas.draw_line(th2, th3, ink, 13.4)
	lobby_fx_canvas.draw_line(th2, th3, leather, 9.8)
	lobby_fx_canvas.draw_circle(th3, 6.2, ink)
	lobby_fx_canvas.draw_circle(th3, 4.6, leather_hi)
	lobby_fx_canvas.draw_circle(th3 + Vector2(-1.5, -1.2), 2.4, cuff_hi)

	lobby_fx_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_lobby_sheet_frame(
	tex: Texture2D,
	frame_idx: int,
	cols: int,
	rows: int,
	pos: Vector2,
	draw_size: Vector2,
	rot: float,
	flip_x: bool,
	modulate: Color
) -> void:
	if tex == null or modulate.a <= 0.02:
		return
	var total := maxi(1, cols * rows)
	var safe_idx := posmod(frame_idx, total)
	var col := safe_idx % cols
	var row := int(safe_idx / cols)
	var tw := tex.get_width()
	var th := tex.get_height()
	if tw <= 0 or th <= 0:
		return
	var cell_w := float(tw) / float(cols)
	var cell_h := float(th) / float(rows)
	var src := Rect2(float(col) * cell_w + 1.5, float(row) * cell_h + 1.5, cell_w - 3.0, cell_h - 3.0)
	lobby_fx_canvas.draw_set_transform(pos, rot, Vector2(-1.0 if flip_x else 1.0, 1.0))
	lobby_fx_canvas.draw_texture_rect_region(tex, Rect2(-draw_size * 0.5, draw_size), src, modulate)
	lobby_fx_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_lobby_card_jump_duel(
	w: float,
	h: float,
	phase_t: float,
	fade: float,
	card_sz: Vector2,
	left_suit: Dictionary,
	left_rank: String,
	left_key: String,
	right_suit: Dictionary,
	right_rank: String,
	right_key: String,
	atk_sheet: Texture2D,
	def_sheet: Texture2D,
	left_aura: Color,
	right_aura: Color,
	slash_tint: Color
) -> void:
	## Draws authentic 2D woodcut cutout fighters leaping out of left_key card into right_key card at ~4.8 stepped FPS.
	const STEP_FPS := 4.8
	var step_t := floorf(phase_t * STEP_FPS) / STEP_FPS
	var enter := ease(clampf(phase_t / 0.55, 0.0, 1.0), 0.38)
	var hero_sz := card_sz * 1.46
	var sprite_sz := Vector2(hero_sz.x * 0.80, hero_sz.x * 0.80)

	# Semicircle of spectator tavern cards (fade smoothly when edge-on so no thin vertical slivers appear)
	for bg_i in range(10):
		var u_bg := float(bg_i) / 9.0
		var ang_bg := lerpf(-2.45, -0.69, u_bg)
		var bg_pos := Vector2(w * 0.5 + cos(ang_bg) * w * 0.43, h * 0.48 + sin(ang_bg) * h * 0.28 + sin(phase_t * 2.2 + float(bg_i)) * 7.0)
		var bg_rot := (u_bg - 0.5) * 0.55
		var bg_fc := cos(phase_t * 1.4 + float(bg_i))
		var bg_edge_fade := clampf((absf(bg_fc) - 0.16) / 0.30, 0.0, 1.0)
		_draw_lobby_card(bg_pos, card_sz * 0.78, bg_rot, bg_fc, LOBBY_SUITS[bg_i % 4], _pick_lobby_card_rank(bg_i + 2), 0.32 * fade * bg_edge_fade)

	var left_base := Vector2(lerpf(-180.0, w * 0.25, enter), h * 0.56 + sin(phase_t * 2.8) * 4.0)
	var right_base := Vector2(lerpf(w + 180.0, w * 0.75, enter), h * 0.56 + cos(phase_t * 2.8) * 4.0)

	var left_recoil := Vector2.ZERO
	var right_recoil := Vector2.ZERO
	var left_rot := -0.08
	var right_rot := 0.08
	var clash_active := false
	var duel_step := 0
	var clash_intensity := 0.0
	var strike_phase := 0.0

	if phase_t >= 0.68 and phase_t < 1.05:
		var push := sin(((phase_t - 0.68) / 0.37) * PI)
		left_recoil = Vector2(-12.0 * push, 14.0 * push)
		left_rot -= 0.11 * push
	elif phase_t >= 1.55 and phase_t < 5.65:
		clash_active = true
		var duel_t := phase_t - 1.55
		duel_step = int(floorf((step_t - 1.55) * 2.4))
		strike_phase = fmod(maxf(0.0, step_t - 1.55) * 2.4, 1.0)
		clash_intensity = pow(maxf(0.0, sin(strike_phase * PI)), 2.2)
		var hit_dir := 1.0 if (duel_step % 2 == 0) else -1.0
		right_recoil = Vector2(clash_intensity * 16.0 * hit_dir, clash_intensity * 9.0)
		right_rot += clash_intensity * 0.12 * hit_dir

	var l_pos := left_base + left_recoil
	var r_pos := right_base + right_recoil

	# Subtle heraldic / arcane card glows behind both cards
	lobby_fx_canvas.draw_circle(l_pos, hero_sz.x * 0.72, Color(left_aura.r, left_aura.g, left_aura.b, 0.16 * fade))
	lobby_fx_canvas.draw_arc(l_pos, hero_sz.x * 0.68, 0.0, TAU, 48, Color(1.0, 0.80, 0.32, 0.44 * fade), 2.4)
	lobby_fx_canvas.draw_circle(r_pos, hero_sz.x * 0.74, Color(right_aura.r, right_aura.g, right_aura.b, (0.16 + clash_intensity * 0.22) * fade))
	lobby_fx_canvas.draw_arc(r_pos, hero_sz.x * 0.70, 0.0, TAU, 48, Color(1.0, 0.86, 0.36, (0.46 + clash_intensity * 0.42) * fade), 2.8)

	# Empty-center cards once characters step out to jump/duel, returning cleanly at end!
	var left_vacated := (phase_t >= 0.72 and phase_t < 6.55)
	var right_vacated := (phase_t >= 1.48 and phase_t < 6.05)
	var l_override: Texture2D = (lobby_empty_cards.get(left_key, null) as Texture2D) if left_vacated else null
	var r_override: Texture2D = (lobby_empty_cards.get(right_key, null) as Texture2D) if right_vacated else null

	_draw_lobby_card(l_pos, hero_sz, left_rot, 1.0, left_suit, left_rank, 0.98 * fade, l_override)
	_draw_lobby_card(r_pos, hero_sz, right_rot, 1.0, right_suit, right_rank, 0.98 * fade, r_override)

	# Portal outline glint on left card just before jump
	if phase_t >= 0.45 and phase_t < 1.25:
		var portal_a := sin(clampf((phase_t - 0.45) / 0.80, 0.0, 1.0) * PI) * 0.72 * fade
		lobby_fx_canvas.draw_set_transform(l_pos, left_rot, Vector2.ONE)
		lobby_fx_canvas.draw_rect(Rect2(-hero_sz.x * 0.40, -hero_sz.y * 0.34, hero_sz.x * 0.80, hero_sz.y * 0.64), Color(1.0, 0.86, 0.36, portal_a), false, 3.0)
		lobby_fx_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Defender cutout steps onto right side of right_key card while dueling
	if right_vacated:
		var def_frame := 0
		var def_pos := r_pos + Vector2(hero_sz.x * 0.24, -4.0)
		var def_rot := 0.0
		if phase_t < 1.55:
			def_frame = 0
		elif phase_t < 5.65:
			var sub := duel_step % 4
			if sub == 0:
				def_frame = 1 # high block
				def_pos.x += clash_intensity * 8.0
			elif sub == 1:
				def_frame = 3 # recoil
				def_pos.x += clash_intensity * 14.0
				def_rot = 0.08 * clash_intensity
			elif sub == 2:
				def_frame = 2 # counter-strike!
				def_pos.x -= clash_intensity * 14.0
			else:
				def_frame = 0
		else:
			def_frame = 0
			def_pos = def_pos.lerp(r_pos + Vector2(0.0, -6.0), clampf((phase_t - 5.65) / 0.40, 0.0, 1.0))
		_draw_lobby_sheet_frame(def_sheet, def_frame, 2, 2, def_pos, sprite_sz, def_rot, false, Color(1, 1, 1, 0.98 * fade))

	# Attacker cutout jumps from left card into right card, fights, then hops back cleanly
	if left_vacated:
		var atk_pos := l_pos + Vector2(0.0, -6.0)
		var atk_frame := 0
		var atk_rot := 0.0
		var atk_flip := false

		if phase_t < 0.85:
			atk_frame = 0
			atk_pos = l_pos + Vector2(4.0, 4.0)
		elif phase_t < 1.55:
			var ju := clampf((step_t - 0.85) / 0.70, 0.0, 1.0)
			var start_p := l_pos + Vector2(8.0, -4.0)
			var end_p := r_pos + Vector2(-hero_sz.x * 0.25, -4.0)
			for tr_i in range(2, 0, -1):
				var tu := clampf(ju - float(tr_i) * 0.14, 0.0, 1.0)
				var tp := start_p.lerp(end_p, tu) + Vector2(0.0, -sin(tu * PI) * 195.0)
				_draw_lobby_sheet_frame(atk_sheet, 1, 2, 2, tp, sprite_sz * 0.94, sin(tu * PI) * 0.12, false, Color(0.95, 0.84, 0.62, (0.28 - float(tr_i) * 0.09) * fade))
			atk_pos = start_p.lerp(end_p, ju) + Vector2(0.0, -sin(ju * PI) * 195.0)
			atk_frame = 1 if ju < 0.88 else 2
			atk_rot = -0.10 + sin(ju * PI) * 0.18
		elif phase_t < 5.65:
			var sub := duel_step % 4
			var base_atk := r_pos + Vector2(-hero_sz.x * 0.24, -4.0)
			if sub == 0:
				atk_frame = 2 # cleave/strike!
				atk_pos = base_atk + Vector2(clash_intensity * 16.0, -clash_intensity * 8.0)
				atk_rot = 0.07 * clash_intensity
			elif sub == 1:
				atk_frame = 1 # soaring pressure strike
				atk_pos = base_atk + Vector2(10.0, -12.0)
			elif sub == 2:
				atk_frame = 3 # parry / guard against counter!
				atk_pos = base_atk + Vector2(-clash_intensity * 10.0, 2.0)
				atk_rot = -0.08 * clash_intensity
			else:
				atk_frame = 0
				atk_pos = base_atk
		else:
			var bu := clampf((step_t - 5.65) / 0.90, 0.0, 1.0)
			var start_b := r_pos + Vector2(-hero_sz.x * 0.24, -4.0)
			var end_b := l_pos + Vector2(0.0, -6.0)
			atk_pos = start_b.lerp(end_b, bu) + Vector2(0.0, -sin(bu * PI) * 185.0)
			atk_flip = (bu < 0.82)
			atk_frame = 1 if bu < 0.84 else 0
			atk_rot = -sin(bu * PI) * 0.16

		_draw_lobby_sheet_frame(atk_sheet, atk_frame, 2, 2, atk_pos, sprite_sz, atk_rot, atk_flip, Color(1, 1, 1, 0.99 * fade))

	# Hand-drawn cel sword slash arcs & woodcut spark starbursts on fight impact beats!
	if clash_active and clash_intensity > 0.18:
		var clash_pt := r_pos + Vector2(0.0, -16.0)
		var c_a := clash_intensity * fade
		var slash_frame := 2 + ((int(floorf(step_t * 14.0))) % 11)
		_draw_lobby_sheet_frame(
			lobby_slash_fx_tex,
			slash_frame,
			6,
			4,
			clash_pt,
			Vector2(178.0, 178.0),
			float(duel_step) * 1.15,
			(duel_step % 2 == 1),
			Color(slash_tint.r, slash_tint.g, slash_tint.b, c_a * 0.95)
		)
		_draw_lobby_sheet_frame(
			lobby_sparks_fx_tex,
			14,
			4,
			4,
			clash_pt + Vector2(0.0, -4.0),
			Vector2(74.0 + clash_intensity * 26.0, 74.0 + clash_intensity * 26.0),
			float(duel_step) * 0.7,
			false,
			Color(1.0, 0.94, 0.72, c_a)
		)
		lobby_fx_canvas.draw_arc(clash_pt, 16.0 + (1.0 - clash_intensity) * 42.0, 0.0, TAU, 28, Color(slash_tint.r, slash_tint.g, slash_tint.b, c_a * 0.75), 2.8)


func _draw_lobby_phase_knight_card_duel(w: float, h: float, phase_t: float, fade: float, card_sz: Vector2) -> void:
	_draw_lobby_card_jump_duel(
		w, h, phase_t, fade, card_sz,
		LOBBY_SUITS[0], "K", "CERVEN_K",
		LOBBY_SUITS[2], "H", "ZALUD_H",
		lobby_king_sheet_tex,
		lobby_halberdier_sheet_tex,
		Color(0.95, 0.24, 0.22),
		Color(0.92, 0.68, 0.22),
		Color(1.0, 0.88, 0.42)
	)


func _draw_lobby_phase_arcane_card_clash(w: float, h: float, phase_t: float, fade: float, card_sz: Vector2) -> void:
	_draw_lobby_card_jump_duel(
		w, h, phase_t, fade, card_sz,
		LOBBY_SUITS[3], "SPEC_JESTER", "SPEC_JESTER",
		LOBBY_SUITS[0], "SPEC_PHOENIX", "SPEC_PHOENIX",
		lobby_jester_sheet_tex,
		lobby_phoenix_sheet_tex,
		Color(0.32, 0.88, 1.0),
		Color(1.0, 0.45, 0.14),
		Color(1.0, 0.62, 0.26)
	)

# ============================================================================
# 3. 3D MAPA KAMPANE (Hory s prírodným snehom, hladké stromy, érové stavby)
# ============================================================================
func _build_3d_world() -> void:
	world_3d_root = Node3D.new()
	add_child(world_3d_root)
	era_beacon_lights.clear()
	map_mist_sheets.clear()

	# Eerie twilight candlelight / cold moonlight rig for mysterious grimoire atlas
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.88, 0.85, 0.78)
	sun.light_energy = 0.86
	sun.rotation_degrees = Vector3(-52, 30, 0)
	sun.shadow_enabled = true
	world_3d_root.add_child(sun)

	var moon_rim := DirectionalLight3D.new()
	moon_rim.light_color = Color(0.60, 0.65, 0.74)
	moon_rim.light_energy = 0.44
	moon_rim.rotation_degrees = Vector3(-36, -135, 0)
	moon_rim.shadow_enabled = false
	world_3d_root.add_child(moon_rim)

	world_env_node = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.038, 0.030, 0.024)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.30, 0.25)
	env.ambient_light_energy = 0.90
	world_env_node.environment = env
	world_3d_root.add_child(world_env_node)

	cam_pivot = Node3D.new()
	cam_pivot.position = cam_target_pos
	world_3d_root.add_child(cam_pivot)

	cam_3d = Camera3D.new()
	cam_3d.position = Vector3(0, 21.0, 12.5)
	cam_3d.rotation_degrees = Vector3(-59.0, 0.0, 0.0)
	cam_3d.fov = 44.0
	cam_pivot.add_child(cam_3d)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_SIZE, MAP_SIZE)
	ground.mesh = plane
	var g_mat := ShaderMaterial.new()
	g_mat.shader = MAP_PARCHMENT_SHADER
	var g_tex := Toon.tex("res://assets/map/map_ground.png")
	if g_tex:
		g_mat.set_shader_parameter("map_tex", g_tex)
	g_mat.set_shader_parameter("uv_scale", Vector2.ONE)
	g_mat.set_shader_parameter("is_outer", false)
	g_mat.set_shader_parameter("map_half_size", MAP_SIZE * 0.5)
	g_mat.set_shader_parameter("hatch_strength", 0.46)
	g_mat.set_shader_parameter("grid_strength", 0.26)
	ground.material_override = g_mat
	world_3d_root.add_child(ground)

	var outer := MeshInstance3D.new()
	var oplane := PlaneMesh.new()
	oplane.size = Vector2(260, 260)
	outer.mesh = oplane
	outer.position.y = -0.05
	var o_mat := ShaderMaterial.new()
	o_mat.shader = MAP_PARCHMENT_SHADER
	var o_tex := Toon.tex("res://assets/map/outer_grass.png")
	if o_tex:
		o_mat.set_shader_parameter("map_tex", o_tex)
	o_mat.set_shader_parameter("uv_scale", Vector2(28.0, 28.0))
	o_mat.set_shader_parameter("is_outer", true)
	o_mat.set_shader_parameter("map_half_size", MAP_SIZE * 0.5)
	o_mat.set_shader_parameter("hatch_strength", 0.54)
	o_mat.set_shader_parameter("grid_strength", 0.0)
	outer.material_override = o_mat
	world_3d_root.add_child(outer)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var half := MAP_SIZE * 0.5
	# Husto zoskupené vonkajšie štíty & hustý les na okrajoch (nikde žiadne prázdne miesto!)
	for i in range(68):
		var side_m := i % 4
		var mx := 0.0
		var mz := 0.0
		var span_m := half + 14.0
		if side_m == 0:
			mx = rng.randf_range(-span_m, span_m); mz = -half - rng.randf_range(0.5, 13.5)
		elif side_m == 1:
			mx = rng.randf_range(-span_m, span_m); mz = half + rng.randf_range(0.5, 13.5)
		elif side_m == 2:
			mx = -half - rng.randf_range(0.5, 13.5); mz = rng.randf_range(-span_m, span_m)
		else:
			mx = half + rng.randf_range(0.5, 13.5); mz = rng.randf_range(-span_m, span_m)
		_spawn_3d_mountain(Vector3(mx, 0, mz), rng.randf_range(3.6, 7.6), i)
	# Hranicný tmavozelený les mimo hracej plochy
	for i in range(150):
		var side_pick := i % 4
		var bx := 0.0
		var bz := 0.0
		if side_pick == 0:
			bx = rng.randf_range(-half - 14, half + 14); bz = rng.randf_range(-half - 14, -half - 0.5)
		elif side_pick == 1:
			bx = rng.randf_range(-half - 14, half + 14); bz = rng.randf_range(half + 0.5, half + 14)
		elif side_pick == 2:
			bx = rng.randf_range(-half - 14, -half - 0.5); bz = rng.randf_range(-half, half)
		else:
			bx = rng.randf_range(half + 0.5, half + 14); bz = rng.randf_range(-half, half)
		_spawn_3d_tree(Vector3(bx, 0, bz), rng.randf_range(1.1, 1.95))

	for i in range(180):
		var t_pos := Vector3(rng.randf_range(-half, half), 0, rng.randf_range(-half, half))
		if _dist_to_any_era(t_pos) < 4.3 or _on_path_or_river(t_pos) or _near_sheep_pasture(t_pos, 2.8):
			continue
		_spawn_3d_tree(t_pos, rng.randf_range(0.85, 1.45))
	for i in range(45):
		var r_pos := Vector3(rng.randf_range(-half, half), 0, rng.randf_range(-half, half))
		if _dist_to_any_era(r_pos) < 3.6 or _on_path_or_river(r_pos) or _near_sheep_pasture(r_pos, 2.2):
			continue
		_spawn_3d_rock(r_pos, rng.randf_range(0.35, 0.75))
	_spawn_border_clouds(rng, half)
	_spawn_map_mist(rng, half)
	_spawn_river_flow()
	_spawn_era_trail_markers()
	_spawn_map_wildlife()
	for era in ERAS_DATA:
		_spawn_era_monument(era)

func _river_point(v: float) -> Vector3:
	# Presná trajektória rieky cez map_ground.png (od ľavého horného rohu popod 2 kamenné mosty dole doprava)
	var pts := [
		Vector2(0.16, 0.00),
		Vector2(0.365, 0.26),
		Vector2(0.515, 0.50),
		Vector2(0.735, 0.69),
		Vector2(0.94, 1.00),
	]
	var vc := clampf(v, 0.0, 1.0)
	var u := 0.5
	for idx in range(pts.size() - 1):
		var a: Vector2 = pts[idx]
		var b: Vector2 = pts[idx + 1]
		if vc <= b.y or idx == pts.size() - 2:
			var t := clampf((vc - a.y) / maxf(0.001, b.y - a.y), 0.0, 1.0)
			u = lerpf(a.x, b.x, t)
			break
	return Vector3((u - 0.5) * MAP_SIZE, 0.022, (vc - 0.5) * MAP_SIZE)

const SHEEP_PASTURES: Array[Vector3] = [
	Vector3(-5.2, 0.0, -13.6), Vector3(-3.6, 0.0, -12.8), Vector3(-6.4, 0.0, -12.4),
	Vector3(-6.8, 0.0, -1.4),  Vector3(-5.8, 0.0, -0.3),
	Vector3(4.8, 0.0, -3.9),   Vector3(5.9, 0.0, -2.7),
	Vector3(-7.2, 0.0, 11.8),  Vector3(-5.8, 0.0, 12.8),
]

func _near_sheep_pasture(p: Vector3, min_dist: float = 2.6) -> bool:
	for sp in SHEEP_PASTURES:
		if p.distance_to(sp) < min_dist:
			return true
	return false

func _spawn_river_flow() -> void:
	map_river_ripples.clear()
	var aqua_mat := StandardMaterial3D.new()
	aqua_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aqua_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aqua_mat.albedo_color = Color(0.28, 0.40, 0.40, 0.34)

	var glint_mat := StandardMaterial3D.new()
	glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glint_mat.albedo_color = Color(0.68, 0.74, 0.64, 0.44)

	# Organické hladké elipsovité prúžky vody a trblietavé kvapky (bez ostrých hranatých čiar)
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.09
	drop_mesh.height = 0.18
	drop_mesh.radial_segments = 8
	drop_mesh.rings = 4

	for i in range(44):
		var rip := MeshInstance3D.new()
		var is_glint := (i % 3 == 0)
		rip.mesh = drop_mesh
		rip.material_override = glint_mat if is_glint else aqua_mat
		var base_scale := Vector3(0.48, 0.10, 2.2) if is_glint else Vector3(0.75, 0.10, 3.1)
		rip.scale = base_scale
		world_3d_root.add_child(rip)
		map_river_ripples.append({
			"node": rip,
			"base_scale": base_scale,
			"v": fmod(float(i) / 44.0 + fmod(float(i) * 0.11, 0.04), 1.0),
			"lane": lerpf(-0.92, 0.92, fmod(float(i) * 0.41, 1.0)),
			"spd": lerpf(0.032, 0.052, fmod(float(i) * 0.23, 1.0)),
			"phase": float(i) * 0.9,
		})

func _spawn_map_wildlife() -> void:
	map_sheep_actors.clear()
	var wool_mat := Toon.mat(Color(0.56, 0.50, 0.42), "", 0.025, Vector2.ONE, Color(0.10, 0.08, 0.07))
	var face_mat := Toon.mat(Color(0.11, 0.09, 0.08), "", 0.020)
	for idx in range(SHEEP_PASTURES.size()):
		var home: Vector3 = SHEEP_PASTURES[idx]
		if _dist_to_any_era(home) < 4.5 or _on_path_or_river(home):
			continue
		var sheep := Node3D.new()
		sheep.position = home
		world_3d_root.add_child(sheep)

		# Nadýchané telo zo 3 vlnených gúľ
		for boff in [Vector3(0.0, 0.34, 0.0), Vector3(-0.12, 0.32, 0.08), Vector3(0.11, 0.33, -0.07)]:
			var w := MeshInstance3D.new()
			var ws := SphereMesh.new(); ws.radius = 0.28; ws.height = 0.48
			w.mesh = ws; w.position = boff; w.material_override = wool_mat
			sheep.add_child(w)

		var head_piv := Node3D.new()
		head_piv.position = Vector3(0.0, 0.38, 0.28)
		sheep.add_child(head_piv)

		var hd := MeshInstance3D.new()
		var hs := SphereMesh.new(); hs.radius = 0.14; hs.height = 0.28
		hd.mesh = hs; hd.position = Vector3(0.0, 0.02, 0.08); hd.material_override = face_mat
		head_piv.add_child(hd)

		for e_s in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			var eb := BoxMesh.new(); eb.size = Vector3(0.12, 0.05, 0.06)
			ear.mesh = eb; ear.position = Vector3(e_s * 0.14, 0.05, 0.04); ear.rotation_degrees.z = -e_s * 22.0; ear.material_override = face_mat
			head_piv.add_child(ear)

		var legs: Array[MeshInstance3D] = []
		for lx in [-0.12, 0.12]:
			for lz in [-0.14, 0.14]:
				var leg := MeshInstance3D.new()
				var lc := CylinderMesh.new(); lc.top_radius = 0.04; lc.bottom_radius = 0.035; lc.height = 0.26
				leg.mesh = lc; leg.position = Vector3(lx, 0.13, lz); leg.material_override = face_mat
				sheep.add_child(leg)
				legs.append(leg)

		map_sheep_actors.append({
			"node": sheep,
			"head": head_piv,
			"legs": legs,
			"home": home,
			"radius": 0.42 + fmod(float(idx) * 0.13, 0.22),
			"phase": float(idx) * 1.35,
			"spd": 0.32 + fmod(float(idx) * 0.09, 0.16),
		})

func _spawn_border_clouds(rng: RandomNumberGenerator, half: float) -> void:
	map_cloud_nodes.clear()
	var cloud_top_mat := Toon.mat(Color(0.26, 0.23, 0.20), "", 0.012, Vector2.ONE, Color(0.06, 0.05, 0.05))
	var cloud_under_mat := Toon.mat(Color(0.13, 0.11, 0.11), "", 0.012, Vector2.ONE, Color(0.03, 0.025, 0.03))
	# Toned-down perimeter clouds pushed strictly outside the map border so the map is 100% clear!
	for i in range(36):
		var side := i % 4
		var tier := i % 2
		var depth_min := 5.2 if tier == 0 else 8.8
		var depth_max := 8.5 if tier == 0 else 14.2
		var d_off := rng.randf_range(depth_min, depth_max)
		var span := half + d_off + 2.5
		var px := 0.0
		var pz := 0.0
		if side == 0:
			px = rng.randf_range(-span, span); pz = -half - d_off
		elif side == 1:
			px = rng.randf_range(-span, span); pz = half + d_off
		elif side == 2:
			px = -half - d_off; pz = rng.randf_range(-span, span)
		else:
			px = half + d_off; pz = rng.randf_range(-span, span)

		var c_root := Node3D.new()
		var py := rng.randf_range(2.2, 4.2) + float(tier) * 0.45
		c_root.position = Vector3(px, py, pz)
		c_root.scale = Vector3.ONE * (0.65 + float(tier) * 0.25)
		c_root.set_meta("base_pos", Vector3(px, py, pz))
		c_root.set_meta("phase", rng.randf_range(0.0, TAU))
		c_root.set_meta("drift_spd", rng.randf_range(0.22, 0.48))
		world_3d_root.add_child(c_root)

		var puffs := rng.randi_range(3, 5)
		for k in range(puffs):
			var puff := MeshInstance3D.new()
			var sp := SphereMesh.new()
			var r := rng.randf_range(1.0, 1.8) if k < 2 else rng.randf_range(0.75, 1.25)
			sp.radius = r
			sp.height = r * 1.15
			sp.radial_segments = 10
			sp.rings = 6
			puff.mesh = sp
			puff.material_override = cloud_top_mat if k < 2 else cloud_under_mat
			var off_x := (float(k) - float(puffs - 1) * 0.5) * 1.05 + rng.randf_range(-0.25, 0.25)
			var off_y := (0.35 if k < 2 else rng.randf_range(-0.12, 0.22))
			var off_z := rng.randf_range(-0.55, 0.55)
			puff.position = Vector3(off_x, off_y, off_z)
			c_root.add_child(puff)
		map_cloud_nodes.append(c_root)

func _spawn_map_mist(rng: RandomNumberGenerator, half: float) -> void:
	map_mist_sheets.clear()
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for py in range(64):
		for px in range(64):
			var dx := (float(px) + 0.5) / 32.0 - 1.0
			var dy := (float(py) + 0.5) / 32.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var w := pow(maxf(0.0, 1.0 - r), 2.1)
			img.set_pixel(px, py, Color(0.62, 0.57, 0.48, w * 0.22))
	var mist_tex := ImageTexture.create_from_image(img)
	var mist_mat := StandardMaterial3D.new()
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.albedo_texture = mist_tex
	mist_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in range(18):
		var sheet := MeshInstance3D.new()
		var qm := PlaneMesh.new()
		var w_sz := rng.randf_range(5.2, 10.5)
		qm.size = Vector2(w_sz, w_sz * rng.randf_range(0.65, 1.15))
		sheet.mesh = qm
		sheet.material_override = mist_mat
		var bx := rng.randf_range(-half * 0.88, half * 0.88)
		var bz := rng.randf_range(-half * 0.88, half * 0.88)
		var by := rng.randf_range(0.32, 0.92)
		sheet.position = Vector3(bx, by, bz)
		sheet.rotation.y = rng.randf_range(0.0, TAU)
		world_3d_root.add_child(sheet)
		map_mist_sheets.append({
			"node": sheet,
			"base": Vector3(bx, by, bz),
			"phase": rng.randf_range(0.0, TAU),
			"spd": rng.randf_range(0.14, 0.30),
		})

func _spawn_era_trail_markers() -> void:
	map_trail_beads.clear()
	# Dashed crimson iron-gall & antique brass cartographer expedition routes along map_ground roads
	var segments := [
		{"a": Vector3(0.4, 0.0, 14.0),   "ctrl": Vector3(-7.4, 0.0, 11.4),  "b": Vector3(-14.4, 0.0, 6.8)},
		{"a": Vector3(-14.4, 0.0, 6.8),  "ctrl": Vector3(-11.0, 0.0, -0.2), "b": Vector3(-14.4, 0.0, -7.6)},
		{"a": Vector3(-14.4, 0.0, -7.6), "ctrl": Vector3(-4.2, 0.0, -9.6),  "b": Vector3(8.4, 0.0, -11.6)},
		{"a": Vector3(8.4, 0.0, -11.6),  "ctrl": Vector3(8.2, 0.0, -3.2),   "b": Vector3(17.2, 0.0, 0.4)},
	]
	var wax_mat := StandardMaterial3D.new()
	wax_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wax_mat.albedo_color = Color(0.58, 0.13, 0.11)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.albedo_color = Color(0.14, 0.07, 0.05)

	var dot_m := CylinderMesh.new()
	dot_m.top_radius = 0.22; dot_m.bottom_radius = 0.25; dot_m.height = 0.036; dot_m.radial_segments = 10
	var ring_m := CylinderMesh.new()
	ring_m.top_radius = 0.28; ring_m.bottom_radius = 0.30; ring_m.height = 0.020; ring_m.radial_segments = 10

	for seg in segments:
		var p0: Vector3 = seg["a"]
		var p1: Vector3 = seg["ctrl"]
		var p2: Vector3 = seg["b"]
		var steps := 11
		for k in range(2, steps - 1):
			var t := float(k) / float(steps - 1)
			var omt := 1.0 - t
			var pt := p0 * (omt * omt) + p1 * (2.0 * omt * t) + p2 * (t * t)
			var base_ring := MeshInstance3D.new()
			base_ring.mesh = ring_m; base_ring.material_override = rim_mat
			base_ring.position = Vector3(pt.x, 0.022, pt.z)
			world_3d_root.add_child(base_ring)
			var wax := MeshInstance3D.new()
			wax.mesh = dot_m; wax.material_override = wax_mat
			wax.position = Vector3(pt.x, 0.032, pt.z)
			world_3d_root.add_child(wax)
			map_trail_beads.append(base_ring)
			map_trail_beads.append(wax)

const MAP_SIZE := 40.0

func _on_path_or_river(p: Vector3) -> bool:
	var u := p.x / MAP_SIZE + 0.5
	var v := p.z / MAP_SIZE + 0.5
	var ru := lerpf(0.16, 0.94, clampf(v, 0.0, 1.0))
	return absf(u - ru) < 0.095

func _spawn_3d_rock(pos: Vector3, scale_f: float) -> void:
	var rock := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.65 * scale_f
	sph.height = 0.72 * scale_f
	sph.radial_segments = 6
	sph.rings = 3
	rock.mesh = sph
	rock.position = pos + Vector3(0, 0.16 * scale_f, 0)
	rock.rotation_degrees.y = randf() * 360.0
	rock.material_override = Toon.mat(Color(0.30, 0.26, 0.22), "res://assets/map/mountain_rock.png", 0.03, Vector2(1.2, 1.2))
	world_3d_root.add_child(rock)

func _dist_to_any_era(p: Vector3) -> float:
	var best := 999.0
	for era in ERAS_DATA:
		var d: float = p.distance_to(era["pos"])
		if d < best:
			best = d
	return best

func _build_jagged_peak_mesh(top_r: float, bot_r: float, h: float, segs: int, seed_val: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 5
	var grid: Array = []
	for r_i in range(rings + 1):
		var t := float(r_i) / float(rings)
		var ring_pts: Array = []
		var base_r := lerpf(bot_r, top_r, t)
		for s_i in range(segs):
			var ang := (float(s_i) / float(segs)) * TAU
			var ridge_jag := 1.0 + sin(ang * 3.0 + float(seed_val) * 1.7 + t * 2.1) * (0.18 * (1.0 - t * 0.4))
			var rad := base_r * ridge_jag
			var py := h * t + sin(ang * 4.0 + float(seed_val)) * (0.06 * h * sin(t * PI))
			ring_pts.append(Vector3(cos(ang) * rad, py, sin(ang) * rad))
		grid.append(ring_pts)

	for r_i in range(rings):
		var row0: Array = grid[r_i]
		var row1: Array = grid[r_i + 1]
		var v0 := float(r_i) / float(rings)
		var v1 := float(r_i + 1) / float(rings)
		for s_i in range(segs):
			var sn := (s_i + 1) % segs
			var u0 := float(s_i) / float(segs)
			var u1 := float(s_i + 1) / float(segs)
			var p00: Vector3 = row0[s_i]
			var p10: Vector3 = row0[sn]
			var p01: Vector3 = row1[s_i]
			var p11: Vector3 = row1[sn]

			st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)

			st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)

	# Uzavretie vrcholu štítu
	var top_ring: Array = grid[rings]
	var summit := Vector3(0.0, h * 1.04, 0.0)
	for s_i in range(segs):
		var sn := (s_i + 1) % segs
		st.set_uv(Vector2(float(s_i) / float(segs), 1.0)); st.add_vertex(top_ring[s_i])
		st.set_uv(Vector2(float(s_i + 1) / float(segs), 1.0)); st.add_vertex(top_ring[sn])
		st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(summit)

	st.generate_normals()
	return st.commit()

func _spawn_3d_mountain(pos: Vector3, h: float, seed_id: int) -> void:
	var m_root := Node3D.new()
	m_root.position = pos
	m_root.rotation_degrees.y = randf() * 360.0
	world_3d_root.add_child(m_root)

	var rock_tex := Toon.tex("res://assets/map/mountain_rock.png")
	var rock_col := Color(0.26, 0.22, 0.19).lerp(Color(0.36, 0.30, 0.25), randf())

	# Štyri organické skalné štíty s prirodzenou snehovou čiarou cez mountain_toon.gdshader (žiadne umelé biele kužele!)
	var peaks := [
		{"off": Vector3(0, 0, 0), "h": h, "r": h * 0.65, "snow": 0.60},
		{"off": Vector3(h * 0.36, 0, h * 0.14), "h": h * 0.72, "r": h * 0.48, "snow": 0.68},
		{"off": Vector3(-h * 0.30, 0, -h * 0.22), "h": h * 0.58, "r": h * 0.44, "snow": 0.78},
	]
	for k in range(peaks.size()):
		var p: Dictionary = peaks[k]
		var ph: float = p["h"]
		var pr: float = p["r"]

		var m_mat := ShaderMaterial.new()
		m_mat.shader = MOUNTAIN_SHADER
		m_mat.set_shader_parameter("rock_tint", rock_col)
		if rock_tex:
			m_mat.set_shader_parameter("rock_tex", rock_tex)
		m_mat.set_shader_parameter("peak_height", ph)
		m_mat.set_shader_parameter("snow_line_ratio", float(p["snow"]))
		m_mat.set_shader_parameter("snow_col", Color(0.76, 0.70, 0.58))
		m_mat.set_shader_parameter("shadow_tint", Color(0.08, 0.06, 0.07))

		var outline := ShaderMaterial.new()
		outline.shader = preload("res://shaders/outline.gdshader")
		outline.set_shader_parameter("thickness", 0.04)
		m_mat.next_pass = outline

		var mtn := MeshInstance3D.new()
		mtn.mesh = _build_jagged_peak_mesh(pr * 0.12, pr, ph, 11, seed_id * 7 + k)
		mtn.material_override = m_mat
		mtn.position = p["off"]
		m_root.add_child(mtn)

func _spawn_3d_tree(pos: Vector3, scale_f: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_f
	world_3d_root.add_child(root)

	var trunk := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.075
	tc.bottom_radius = 0.12
	tc.height = 0.58
	tc.radial_segments = 6
	trunk.mesh = tc
	trunk.position.y = 0.29
	trunk.material_override = Toon.mat(Color(0.18, 0.12, 0.08), "", 0.025)
	root.add_child(trunk)

	# Brooding smoky charcoal-moss woodcut evergreens matching antique engraved parchment
	var green := Color(0.17, 0.19, 0.16).lerp(Color(0.24, 0.25, 0.21), randf())
	var leaf_mat := Toon.mat(green, "", 0.032)
	for k in range(3):
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.72 - float(k) * 0.16
		cm.height = 0.92 - float(k) * 0.12
		cm.radial_segments = 9
		cone.mesh = cm
		cone.position.y = 0.85 + float(k) * 0.44
		cone.rotation_degrees.y = float(k) * 24.0
		cone.material_override = leaf_mat
		root.add_child(cone)
	root.set_meta("sway_phase", randf() * TAU)
	map_tree_nodes.append(root)

func _spawn_era_monument(era: Dictionary) -> void:
	var pos: Vector3 = era["pos"]
	var m_root := Node3D.new()
	m_root.position = pos
	world_3d_root.add_child(m_root)
	era_towers.append(m_root)

	# Klikateľný pulzujúci magický kruh (predvolene rozsvietený na vybranej ére)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.08
	torus.outer_radius = 2.22
	ring.mesh = torus
	ring.position = Vector3(0, 0.06, 0)
	ring.material_override = Toon.mat(era["border_col"], "", 0.0, Vector2.ONE, era["border_col"] * 0.28)
	ring.visible = (ERAS_DATA.find(era) == selected_era_idx)
	m_root.add_child(ring)
	era_ring_meshes.append(ring)

	# Okultné blikotavé svetlo sviece / majáka nad každou pevnosťou
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0.0, 2.45, 0.25)
	beacon.light_color = Color(0.92, 0.78, 0.56).lerp(era["border_col"], 0.25)
	beacon.light_energy = 1.35 if (ERAS_DATA.find(era) == selected_era_idx) else 0.65
	beacon.omni_range = 7.2
	beacon.omni_attenuation = 1.45
	m_root.add_child(beacon)
	era_beacon_lights.append(beacon)

	# Spoločný tmavý kamenný podstavec zapustený do zeme
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 1.65
	bc.bottom_radius = 1.85
	bc.height = 0.28
	bc.radial_segments = 8
	base.mesh = bc
	base.material_override = Toon.mat(Color(0.46, 0.41, 0.34), "res://assets/table/stone_floor.png", 0.035, Vector2(2.0, 2.0))
	base.position = Vector3(0, 0.14, 0)
	m_root.add_child(base)

	var era_id: String = str(era["id"])
	match era_id:
		"antika":
			# Stupňovitá zlatistá pyramída + obelisky
			for step in range(3):
				var b := MeshInstance3D.new()
				var bm := BoxMesh.new()
				var w := 2.0 - float(step) * 0.52
				bm.size = Vector3(w, 0.42, w)
				b.mesh = bm
				b.position = Vector3(0, 0.48 + float(step) * 0.40, 0)
				b.material_override = Toon.mat(Color(0.84, 0.70, 0.42), "", 0.035)
				m_root.add_child(b)
			var cap := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.01; cc.bottom_radius = 0.42; cc.height = 0.55; cc.radial_segments = 4
			cap.mesh = cc; cap.rotation_degrees.y = 45.0; cap.position = Vector3(0, 1.78, 0)
			cap.material_override = Toon.mat(Color(0.95, 0.76, 0.28), "", 0.03)
			m_root.add_child(cap)
			for ox in [-1.05, 1.05]:
				var ob := MeshInstance3D.new()
				var oc := CylinderMesh.new()
				oc.top_radius = 0.08; oc.bottom_radius = 0.16; oc.height = 1.25; oc.radial_segments = 4
				ob.mesh = oc; ob.position = Vector3(ox, 0.90, 0.85)
				ob.material_override = Toon.mat(Color(0.88, 0.76, 0.52), "", 0.03)
				m_root.add_child(ob)
		"rim":
			# Rímska arkáda / kolonáda zo stĺpov s architrávom
			var col_mat := Toon.mat(Color(0.88, 0.84, 0.76), "", 0.03)
			for ci in range(6):
				var ang := float(ci) * (TAU / 6.0)
				var col_m := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.14; cm.bottom_radius = 0.16; cm.height = 1.35; cm.radial_segments = 8
				col_m.mesh = cm
				col_m.position = Vector3(cos(ang) * 1.02, 0.95, sin(ang) * 1.02)
				col_m.material_override = col_mat
				m_root.add_child(col_m)
			var arch := MeshInstance3D.new()
			var am := TorusMesh.new()
			am.inner_radius = 0.82; am.outer_radius = 1.22
			arch.mesh = am; arch.position = Vector3(0, 1.66, 0); arch.scale.y = 0.65
			arch.material_override = col_mat
			m_root.add_child(arch)
			var banner := MeshInstance3D.new()
			var bbm := BoxMesh.new(); bbm.size = Vector3(0.45, 0.9, 0.15)
			banner.mesh = bbm; banner.position = Vector3(0, 0.92, 0)
			banner.material_override = Toon.mat(Color(0.76, 0.22, 0.18), "", 0.025)
			m_root.add_child(banner)
		"stredovek":
			# Kamenná hradná pevnosť s cimburím a praporom
			var stone_m := Toon.mat(Color(0.62, 0.58, 0.50), "", 0.035)
			var keep := MeshInstance3D.new()
			var km := BoxMesh.new(); km.size = Vector3(1.45, 1.4, 1.25)
			keep.mesh = km; keep.position = Vector3(0, 0.98, 0); keep.material_override = stone_m
			m_root.add_child(keep)
			for cx in [-0.72, 0.72]:
				for cz in [-0.62, 0.62]:
					var tur := MeshInstance3D.new()
					var tm := CylinderMesh.new()
					tm.top_radius = 0.24; tm.bottom_radius = 0.26; tm.height = 1.75; tm.radial_segments = 8
					tur.mesh = tm; tur.position = Vector3(cx, 1.15, cz); tur.material_override = stone_m
					m_root.add_child(tur)
			var door := MeshInstance3D.new()
			var dm := BoxMesh.new(); dm.size = Vector3(0.42, 0.62, 0.12)
			door.mesh = dm; door.position = Vector3(0, 0.58, 0.64)
			door.material_override = Toon.mat(Color(0.36, 0.22, 0.12), "res://assets/table/wood.png", 0.02)
			m_root.add_child(door)
			var roof_k := MeshInstance3D.new()
			var rkc := CylinderMesh.new(); rkc.top_radius = 0.02; rkc.bottom_radius = 0.72; rkc.height = 0.75; rkc.radial_segments = 4
			roof_k.mesh = rkc; roof_k.rotation_degrees.y = 45.0; roof_k.position = Vector3(0, 2.02, 0)
			roof_k.material_override = Toon.mat(Color(0.28, 0.34, 0.31), "", 0.03)
			m_root.add_child(roof_k)
		"objavy":
			# Korzárske mólo a lodný trup so sťažňom & plachtou
			var wood_m := Toon.mat(Color(0.42, 0.27, 0.15), "res://assets/table/wood.png", 0.03)
			var hull := MeshInstance3D.new()
			var hm := BoxMesh.new(); hm.size = Vector3(0.95, 0.55, 2.1)
			hull.mesh = hm; hull.position = Vector3(0, 0.55, 0); hull.material_override = wood_m
			m_root.add_child(hull)
			var mast := MeshInstance3D.new()
			var mm := CylinderMesh.new(); mm.top_radius = 0.06; mm.bottom_radius = 0.08; mm.height = 1.95
			mast.mesh = mm; mast.position = Vector3(0, 1.55, 0); mast.material_override = wood_m
			m_root.add_child(mast)
			var sail := MeshInstance3D.new()
			var sm := BoxMesh.new(); sm.size = Vector3(1.15, 0.95, 0.06)
			sail.mesh = sm; sail.position = Vector3(0, 1.58, 0.12)
			sail.material_override = Toon.mat(Color(0.76, 0.69, 0.55), "", 0.025)
			m_root.add_child(sail)
		_:
			# 1930s Art-Deco tehlový klub + teplý neónový vchod
			var brick := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1.55, 1.45, 1.35)
			brick.mesh = bm; brick.position = Vector3(0, 1.0, 0)
			brick.material_override = Toon.mat(Color(0.28, 0.22, 0.26), "", 0.035)
			m_root.add_child(brick)
			var marq := MeshInstance3D.new()
			var mm := BoxMesh.new(); mm.size = Vector3(1.15, 0.34, 0.35)
			marq.mesh = mm; marq.position = Vector3(0, 1.25, 0.72)
			marq.material_override = Toon.mat(Color(0.88, 0.62, 0.24), "", 0.025, Vector2.ONE, Color(0.55, 0.35, 0.10))
			m_root.add_child(marq)

	# Ikona éry vznášajúca sa nad monumentom
	var icons_tex := Toon.tex("res://assets/map/era_icons.png")
	var idx := ERAS_DATA.find(era)
	if icons_tex and idx >= 0:
		var spr := Sprite3D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = icons_tex
		var w := icons_tex.get_width() / 5.0
		atlas.region = Rect2(w * idx, 0, w, icons_tex.get_height())
		spr.texture = atlas
		spr.pixel_size = 0.0085
		spr.modulate = Color(0.92, 0.85, 0.72)
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.position = Vector3(0, 4.05, 0)
		spr.set_meta("base_y", 4.05)
		m_root.add_child(spr)
		era_medallions.append(spr)

	# Čistý popisok podstavca vpredu dole (neprekrýva stavbu ani znak)
	var label3d := Label3D.new()
	label3d.text = _tr(str(era["name"]), str(era.get("name_cs", era["name"])))
	label3d.font = _get_font(true)
	label3d.font_size = 44
	label3d.outline_size = 5
	label3d.outline_modulate = Color(0.88, 0.84, 0.74)
	label3d.modulate = Color(0.14, 0.10, 0.07)
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.position = Vector3(0, 0.68, 2.58)
	m_root.add_child(label3d)
	era_label3d_nodes.append({"lbl": label3d, "en": str(era["name"]), "cs": str(era.get("name_cs", era["name"]))})

func _make_book_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.042, 0.034, 0.92)
	sb.border_color = Color(0.70, 0.54, 0.24, 0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	return sb

func _build_3d_hud() -> void:
	hud_3d_control = Control.new()
	hud_3d_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_3d_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_3d_control.theme = game_theme
	ui_layer.add_child(hud_3d_control)

	var frame_tex := Toon.tex("res://assets/map/map_frame.png")
	if frame_tex:
		var frame := TextureRect.new()
		frame.texture = frame_tex
		frame.modulate = Color(0.84, 0.77, 0.66, 1.0)
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_3d_control.add_child(frame)
		map_frame_rect = frame

	# Populate floating styled Cloud Lore Text Bubbles drifting around the Chronicle Atlas
	map_cloud_bubbles = [
		{"text": _tr("✦ Sand & Riddles", "✦ Písek a hádanky"),  "era_idx": 0, "uv": Vector2(0.54, 0.72), "drift": Vector2(18.0, 9.0),  "spd": 0.65, "phase": 0.4},
		{"text": _tr("✦ Eagle's Oath", "✦ Přísaha orla"),    "era_idx": 1, "uv": Vector2(0.24, 0.56), "drift": Vector2(14.0, 11.0), "spd": 0.55, "phase": 1.6},
		{"text": _tr("✦ Crown of Iron", "✦ Železná koruna"),   "era_idx": 2, "uv": Vector2(0.26, 0.25), "drift": Vector2(16.0, 8.0),  "spd": 0.72, "phase": 2.9},
		{"text": _tr("✦ Black Sails", "✦ Černé plachty"),     "era_idx": 3, "uv": Vector2(0.70, 0.24), "drift": Vector2(15.0, 10.0), "spd": 0.60, "phase": 4.1},
		{"text": _tr("✦ Smoke & Gin", "✦ Kouř a gin"),     "era_idx": 4, "uv": Vector2(0.76, 0.48), "drift": Vector2(14.0, 9.0),  "spd": 0.58, "phase": 5.3},
		{"text": _tr("Ink & Fate Drift…", "Inkoust a osud…"), "era_idx": -1, "uv": Vector2(0.45, 0.23), "drift": Vector2(26.0, 10.0), "spd": 0.48, "phase": 0.9},
		{"text": _tr("Turn the Page…", "Otoč list…"),    "era_idx": -1, "uv": Vector2(0.58, 0.62), "drift": Vector2(24.0, 12.0), "spd": 0.44, "phase": 3.4},
		{"text": "Hic Svnt Dracones", "era_idx": -1, "uv": Vector2(0.10, 0.44), "drift": Vector2(8.0, 16.0),  "spd": 0.52, "phase": 2.1},
	]

	# Illuminated Grimoire / Open Book Chrome: calfskin leather cover, deckle page leaves,
	# recessed aperture shadow, open-book spine gutter fold, crimson silk bookmark & floating cloud bubbles!
	book_folio_fx = Control.new()
	book_folio_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	book_folio_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_folio_fx.draw.connect(func():
		var vp := book_folio_fx.size
		if vp.x < 64.0 or vp.y < 64.0:
			return
		var t := Time.get_ticks_msec() * 0.001
		var open_u := ease(clampf(map_open_time / 0.85, 0.0, 1.0), 0.35) if map_open_active else 1.0
		var win_r := Rect2(vp.x * 0.172, vp.y * 0.145, vp.x * 0.652, vp.y * 0.713)

		# 1. Outer leather book cover framing & stacked deckle paper page edges on left/right
		var leather_col := Color(0.055, 0.035, 0.026, 0.94)
		var b_thick := 12.0
		book_folio_fx.draw_rect(Rect2(0, 0, vp.x, b_thick), leather_col)
		book_folio_fx.draw_rect(Rect2(0, vp.y - b_thick, vp.x, b_thick), leather_col)
		book_folio_fx.draw_rect(Rect2(0, 0, b_thick + 6.0, vp.y), leather_col)
		book_folio_fx.draw_rect(Rect2(vp.x - b_thick - 6.0, 0, b_thick + 6.0, vp.y), leather_col)

		# Stacked parchment leaves peeking along left & right edges of open tome
		for p_i in range(3):
			var px_off := float(p_i) * 3.5 + 18.0
			var leaf_c := Color(0.48 - float(p_i) * 0.08, 0.40 - float(p_i) * 0.07, 0.30 - float(p_i) * 0.05, 0.75 * open_u)
			book_folio_fx.draw_line(Vector2(px_off, 14.0), Vector2(px_off, vp.y - 14.0), leaf_c, 1.5)
			book_folio_fx.draw_line(Vector2(vp.x - px_off, 14.0), Vector2(vp.x - px_off, vp.y - 14.0), leaf_c, 1.5)

		# Gold bookbinding border trim & brass corner clasps
		var trim_col := Color(0.68, 0.52, 0.24, 0.68 * open_u)
		book_folio_fx.draw_rect(Rect2(14.0, 10.0, vp.x - 28.0, vp.y - 20.0), trim_col, false, 1.6)
		var clasp_pts := [Vector2(16.0, 12.0), Vector2(vp.x - 16.0, 12.0), Vector2(16.0, vp.y - 12.0), Vector2(vp.x - 16.0, vp.y - 12.0)]
		for c_pt in clasp_pts:
			book_folio_fx.draw_circle(c_pt, 6.0, Color(0.56, 0.42, 0.18, 0.85 * open_u))
			book_folio_fx.draw_circle(c_pt, 3.0, Color(0.84, 0.68, 0.32, 0.90 * open_u))

		# 2. Inner recessed page drop-shadow inside map window (creates deep book-page well)
		for s_i in range(6):
			var inset := float(s_i) * 6.0
			var alpha := (1.0 - float(s_i) / 6.0) * 0.24
			var r_in := Rect2(win_r.position + Vector2(inset, inset), win_r.size - Vector2(inset * 2.0, inset * 2.0))
			book_folio_fx.draw_rect(r_in, Color(0.03, 0.02, 0.015, alpha), false, 7.0)

		# Candlelight reveal veil gently lifting as folio opens
		if open_u < 0.99:
			book_folio_fx.draw_rect(win_r, Color(0.025, 0.018, 0.014, (1.0 - open_u) * 0.88))

		# 3. Open-Book Spine Gutter Shadow & Binding Thread Stitches down the center!
		var spine_x := vp.x * 0.50
		var y_top := win_r.position.y + 4.0
		var y_bot := win_r.position.y + win_r.size.y - 4.0
		for g_i in range(11):
			var d_frac := (float(g_i) - 5.0) / 5.0
			var gx := spine_x + d_frac * 24.0
			var ga := (1.0 - absf(d_frac)) * 0.20 * open_u
			book_folio_fx.draw_line(Vector2(gx, y_top), Vector2(gx, y_bot), Color(0.03, 0.02, 0.015, ga), 5.2)
		book_folio_fx.draw_line(Vector2(spine_x, y_top), Vector2(spine_x, y_bot), Color(0.08, 0.05, 0.03, 0.34 * open_u), 1.4)
		for st_y in [y_top + 18.0, y_top + 36.0, y_bot - 36.0, y_bot - 18.0]:
			book_folio_fx.draw_line(Vector2(spine_x - 8.0, st_y), Vector2(spine_x + 8.0, st_y), Color(0.32, 0.24, 0.15, 0.45 * open_u), 1.8)

		# 4. Crimson Silk Bookmark Ribbon dropping smoothly along top-right page margin
		var rib_drop := ease(clampf((map_open_time - 0.12) / 0.55, 0.0, 1.0), 0.32) if map_open_active else 1.0
		var rx := vp.x * 0.885
		var ry0 := 10.0
		var ry1 := lerpf(16.0, vp.y * 0.145 + 18.0, rib_drop)
		var sway := sin(t * 1.4) * 2.5
		var rib_poly := PackedVector2Array([
			Vector2(rx - 13.0, ry0),
			Vector2(rx + 13.0, ry0),
			Vector2(rx + 13.0 + sway, ry1 + 14.0),
			Vector2(rx + sway, ry1),
			Vector2(rx - 13.0 + sway, ry1 + 14.0),
		])
		book_folio_fx.draw_colored_polygon(rib_poly, Color(0.46, 0.08, 0.08, 0.94 * clampf(rib_drop * 1.4, 0.0, 1.0)))
		book_folio_fx.draw_polyline(rib_poly, Color(0.76, 0.56, 0.22, 0.80 * clampf(rib_drop * 1.4, 0.0, 1.0)), 1.4)

		# 5. Step-by-Step Guiding Arrows (šipky) along the Campaign Trail + Pulsing Target Arrow over the Active Monument!
		var c_pulse := 0.07 + sin(t * 5.2) * 0.015 + cos(t * 8.4) * 0.008
		book_folio_fx.draw_circle(Vector2(win_r.position.x + 28.0, win_r.position.y + win_r.size.y - 32.0), 190.0, Color(1.0, 0.66, 0.26, c_pulse * open_u))
		var df := _get_font(true)
		book_folio_fx.draw_string(df, Vector2(vp.x * 0.50 - 140.0, vp.y * 0.134), _tr("☾  CHRONICLE ATLAS  •  FOL. IV  ☽", "☾  KRONIKA SVĚTA  •  FOL. IV  ☽"), HORIZONTAL_ALIGNMENT_CENTER, 280.0, 13, Color(0.18, 0.12, 0.08, 0.78 * open_u))

		if is_instance_valid(cam_3d):
			# Draw animated directional arrows (šipky) connecting the Campaign Eras in sequence!
			for ei in range(ERAS_DATA.size() - 1):
				var p0_w: Vector3 = ERAS_DATA[ei]["pos"] + Vector3(0.0, 0.8, 0.0)
				var p1_w: Vector3 = ERAS_DATA[ei + 1]["pos"] + Vector3(0.0, 0.8, 0.0)
				if cam_3d.is_position_behind(p0_w) or cam_3d.is_position_behind(p1_w):
					continue
				var s0 := cam_3d.unproject_position(p0_w)
				var s1 := cam_3d.unproject_position(p1_w)
				var seg_v := s1 - s0
				var seg_len := seg_v.length()
				if seg_len < 36.0:
					continue
				var dir_2d := seg_v / seg_len
				var perp_2d := Vector2(-dir_2d.y, dir_2d.x)
				var is_active_leg := (ei == selected_era_idx)
				for ai in range(1, 4):
					var u_arr := fmod((float(ai) / 4.0) + t * 0.35, 1.0)
					var apt := s0.lerp(s1, clampf(u_arr, 0.18, 0.82))
					if not win_r.grow(-24.0).has_point(apt):
						continue
					var a_col := Color(1.0, 0.88, 0.32, 0.92 * open_u) if is_active_leg else Color(0.84, 0.68, 0.36, 0.52 * open_u)
					var arr_poly := PackedVector2Array([
						apt + dir_2d * 9.0,
						apt - dir_2d * 6.0 + perp_2d * 7.0,
						apt - dir_2d * 3.0,
						apt - dir_2d * 6.0 - perp_2d * 7.0,
					])
					book_folio_fx.draw_colored_polygon(arr_poly, a_col)
					book_folio_fx.draw_polyline(arr_poly + PackedVector2Array([arr_poly[0]]), Color(0.08, 0.04, 0.02, a_col.a), 1.6)

			# Draw prominent bouncing Target Arrow + Step-by-Step Banner directly above the selected Era monument!
			var target_idx := clampi(selected_era_idx, 0, ERAS_DATA.size() - 1)
			var mon_w: Vector3 = ERAS_DATA[target_idx]["pos"] + Vector3(0.0, 3.4, 0.0)
			if not cam_3d.is_position_behind(mon_w):
				var mon_2d := cam_3d.unproject_position(mon_w)
				mon_2d.x = clampf(mon_2d.x, 150.0, vp.x - 150.0)
				mon_2d.y = clampf(mon_2d.y, 145.0, vp.y - 140.0)
				var bob_y := sin(t * 4.8) * 7.0
				var tip := mon_2d + Vector2(0.0, bob_y)
				# Big golden downward-pointing arrow (šipka)
				var big_arr := PackedVector2Array([
					tip,
					tip + Vector2(-18.0, -24.0),
					tip + Vector2(-7.0, -24.0),
					tip + Vector2(-7.0, -44.0),
					tip + Vector2(7.0, -44.0),
					tip + Vector2(7.0, -24.0),
					tip + Vector2(18.0, -24.0),
				])
				book_folio_fx.draw_colored_polygon(big_arr, Color(1.0, 0.86, 0.24, 0.98 * open_u))
				book_folio_fx.draw_polyline(big_arr + PackedVector2Array([big_arr[0]]), Color(0.08, 0.03, 0.02, 0.96 * open_u), 2.4)
				var era_title := _tr(str(ERAS_DATA[target_idx].get("name", "Era")), str(ERAS_DATA[target_idx].get("name_cs", "Epocha")))
				var guide_txt := _tr("STEP %d: %s — CLICK!" % [target_idx + 1, era_title], "KROK %d: %s — KLIKNI!" % [target_idx + 1, era_title])
				_draw_cloud_bubble(book_folio_fx, tip + Vector2(0.0, -64.0), guide_txt, df, 0.98 * open_u, 1.04 * open_u, true)
	)
	hud_3d_control.add_child(book_folio_fx)

	var needle_tex := Toon.tex("res://assets/map/compass_needle.png")
	if needle_tex:
		var n_rect := TextureRect.new()
		n_rect.texture = needle_tex
		n_rect.anchor_left = 0.847
		n_rect.anchor_top = 0.745
		n_rect.anchor_right = 0.847
		n_rect.anchor_bottom = 0.745
		n_rect.offset_left = -64
		n_rect.offset_top = -64
		n_rect.offset_right = 64
		n_rect.offset_bottom = 64
		n_rect.pivot_offset = Vector2(64, 64)
		n_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		n_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		n_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_3d_control.add_child(n_rect)
		compass_needle_ctrl = n_rect

	var edge_dust := CPUParticles2D.new()
	edge_dust.position = Vector2(640, 360)
	edge_dust.amount = 36
	edge_dust.lifetime = 4.2
	edge_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	edge_dust.emission_rect_extents = Vector2(620, 340)
	edge_dust.direction = Vector2(0.8, -0.35)
	edge_dust.spread = 35.0
	edge_dust.gravity = Vector2.ZERO
	edge_dust.initial_velocity_min = 12.0
	edge_dust.initial_velocity_max = 28.0
	edge_dust.scale_amount_min = 2.0
	edge_dust.scale_amount_max = 4.2
	edge_dust.color = Color(0.86, 0.74, 0.46, 0.30)
	hud_3d_control.add_child(edge_dust)

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(40, 28)
	top_panel.add_theme_stylebox_override("panel", _make_book_panel_style())
	hud_3d_control.add_child(top_panel)
	map_top_panel = top_panel

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	top_panel.add_child(hbox)

	var btn_back := Button.new()
	btn_back.text = _tr("← Main Menu", "← Hlavní menu")
	btn_back.add_theme_font_size_override("font_size", 17)
	btn_back.pressed.connect(func():
		_play_sfx("ui_click")
		_play_transition_to(func(): _switch_to(ScreenState.MAIN_MENU))
	)
	hbox.add_child(btn_back)
	map_btn_back = btn_back

	var btn_guide := Button.new()
	btn_guide.text = _tr("📜 Duel Laws", "📜 Pravidla")
	btn_guide.add_theme_font_size_override("font_size", 17)
	btn_guide.pressed.connect(func():
		_play_sfx("ui_click")
		if map_nav_modal:
			map_nav_modal.visible = false
		_open_animated_modal(map_guide_modal)
		_animate_label_handwriting(map_guide_body, 110.0)
	)
	hbox.add_child(btn_guide)
	map_btn_guide = btn_guide

	var btn_nav := Button.new()
	btn_nav.text = _tr("🧭 Wayfinder", "🧭 Ovládání")
	btn_nav.add_theme_font_size_override("font_size", 17)
	btn_nav.pressed.connect(func():
		_play_sfx("ui_click")
		if map_guide_modal:
			map_guide_modal.visible = false
		_open_animated_modal(map_nav_modal)
	)
	hbox.add_child(btn_nav)
	map_btn_nav = btn_nav

	var btn_shop := Button.new()
	btn_shop.text = _tr("✦ Bazaar", "✦ Obchod")
	btn_shop.add_theme_font_size_override("font_size", 17)
	btn_shop.pressed.connect(func():
		_play_sfx("ui_click")
		_open_shop_modal(false)
	)
	hbox.add_child(btn_shop)
	map_btn_shop = btn_shop

	map_gold_lbl = Label.new()
	map_gold_lbl.text = "🪙 65"
	map_gold_lbl.add_theme_font_override("font", _get_font(true))
	map_gold_lbl.add_theme_font_size_override("font_size", 18)
	map_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	hbox.add_child(map_gold_lbl)

	map_relics_row = HBoxContainer.new()
	map_relics_row.add_theme_constant_override("separation", 5)
	hbox.add_child(map_relics_row)

	map_print_btn = Button.new()
	map_print_btn.text = _tr("🎨 Woodcut", "🎨 Dřevoryt")
	map_print_btn.tooltip_text = _tr("Cycle Visual Mode [F8]", "Přepnout vzhled [F8]")
	map_print_btn.add_theme_font_size_override("font_size", 16)
	map_print_btn.pressed.connect(func():
		_play_sfx("ui_click")
		_apply_woodcut_mode(woodcut_mode + 1, true)
	)
	hbox.add_child(map_print_btn)

	var map_audio := _create_audio_control_pill()
	hbox.add_child(map_audio)

	# Bottom panel of selected campaign + Difficulty Toggle + Ascension 1-10 & Endless Mode Epoch 6+ selector
	campaign_card_panel = PanelContainer.new()
	campaign_card_panel.anchor_left = 0.0
	campaign_card_panel.anchor_top = 1.0
	campaign_card_panel.anchor_right = 0.0
	campaign_card_panel.anchor_bottom = 1.0
	campaign_card_panel.offset_left = 42
	campaign_card_panel.offset_top = -316
	campaign_card_panel.offset_right = 576
	campaign_card_panel.offset_bottom = -32
	campaign_card_panel.add_theme_stylebox_override("panel", _make_book_panel_style())
	hud_3d_control.add_child(campaign_card_panel)

	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 8)
	campaign_card_panel.add_child(cvbox)

	campaign_title_lbl = Label.new()
	campaign_title_lbl.add_theme_font_override("font", _get_font(true))
	campaign_title_lbl.add_theme_font_size_override("font_size", 24)
	campaign_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	cvbox.add_child(campaign_title_lbl)

	campaign_desc_lbl = Label.new()
	campaign_desc_lbl.add_theme_font_size_override("font_size", 16)
	campaign_desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	campaign_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cvbox.add_child(campaign_desc_lbl)

	campaign_tier_row = HBoxContainer.new()
	campaign_tier_row.add_theme_constant_override("separation", 8)
	cvbox.add_child(campaign_tier_row)

	var asc_minus := Button.new()
	asc_minus.text = "◀"
	asc_minus.custom_minimum_size = Vector2(34, 30)
	asc_minus.pressed.connect(func():
		_play_sfx("ui_click")
		var a := clampi(int(run_profile.get("ascension", 1)) - 1, 1, Catalog.MAX_ASCENSION)
		run_profile["ascension"] = a
		Catalog.save_profile(run_profile)
		_refresh_map_roguelite_hud()
		_update_campaign_card(selected_era_idx)
	)
	campaign_tier_row.add_child(asc_minus)

	asc_val_lbl = Label.new()
	asc_val_lbl.text = "Ascension 1/10"
	asc_val_lbl.add_theme_font_override("font", _get_font(true))
	asc_val_lbl.add_theme_font_size_override("font_size", 14)
	asc_val_lbl.add_theme_color_override("font_color", Color(0.74, 0.90, 1.0))
	campaign_tier_row.add_child(asc_val_lbl)

	var asc_plus := Button.new()
	asc_plus.text = "▶"
	asc_plus.custom_minimum_size = Vector2(34, 30)
	asc_plus.pressed.connect(func():
		_play_sfx("ui_click")
		var max_a := clampi(int(run_profile.get("highest_ascension", 1)), 1, Catalog.MAX_ASCENSION)
		var cur_a := int(run_profile.get("ascension", 1))
		if cur_a < max_a:
			run_profile["ascension"] = cur_a + 1
			Catalog.save_profile(run_profile)
			_refresh_map_roguelite_hud()
			_update_campaign_card(selected_era_idx)
		else:
			_play_sfx("error")
	)
	campaign_tier_row.add_child(asc_plus)

	endless_toggle_btn = Button.new()
	endless_toggle_btn.text = "∞ Epoch 6 Endless"
	endless_toggle_btn.custom_minimum_size = Vector2(180, 30)
	endless_toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	endless_toggle_btn.pressed.connect(func():
		if not bool(run_profile.get("endless_unlocked", false)):
			_play_sfx("error")
			return
		_play_sfx("ui_click")
		endless_mode_selected = not endless_mode_selected
		_update_campaign_card(selected_era_idx)
	)
	campaign_tier_row.add_child(endless_toggle_btn)

	campaign_diff_btn = Button.new()
	campaign_diff_btn.text = _tr("🌿 Mode: Traveler  [Switch]", "🌿 Režim: Poutník  [Přepnout]")
	campaign_diff_btn.custom_minimum_size = Vector2(0, 32)
	campaign_diff_btn.add_theme_font_override("font", _get_font(true))
	campaign_diff_btn.add_theme_font_size_override("font_size", 15)
	campaign_diff_btn.pressed.connect(func():
		_play_sfx("ui_click")
		var cur_d := str(run_profile.get("campaign_difficulty", "traveler"))
		run_profile["campaign_difficulty"] = "classic" if cur_d == "traveler" else "traveler"
		Catalog.save_profile(run_profile)
		_refresh_map_roguelite_hud()
		_update_campaign_card(selected_era_idx)
	)
	cvbox.add_child(campaign_diff_btn)

	campaign_play_btn = Button.new()
	campaign_play_btn.custom_minimum_size = Vector2(0, 44)
	campaign_play_btn.add_theme_font_size_override("font_size", 19)
	campaign_play_btn.pressed.connect(func():
		_play_sfx("ui_click")
		_play_transition_to(func():
			_launch_era_battle(clampi(selected_era_idx, 0, ERAS_DATA.size() - 1))
		)
	)
	cvbox.add_child(campaign_play_btn)
	_build_roguelite_modals()
	_refresh_map_roguelite_hud()
	_update_campaign_card(0)

	# Centered animated modals: Rules + Second cozy Navigation popup
	_build_map_guide_modal()

func _draw_cloud_bubble(ctrl: Control, cen: Vector2, txt: String, font: Font, alpha: float, sc: float, highlight: bool) -> void:
	var txt_w := clampf(float(txt.length()) * 7.8 + 30.0, 98.0, 310.0) * sc
	var puffs := [
		{"off": Vector2(-txt_w * 0.34, 2.0) * sc,  "r": 14.5 * sc},
		{"off": Vector2(txt_w * 0.34, 2.0) * sc,   "r": 14.5 * sc},
		{"off": Vector2(-txt_w * 0.16, -8.5) * sc, "r": 16.5 * sc},
		{"off": Vector2(txt_w * 0.16, -7.5) * sc,  "r": 15.5 * sc},
		{"off": Vector2(0.0, 4.5) * sc,            "r": 16.0 * sc},
	]
	var sh_col := Color(0.04, 0.025, 0.02, 0.34 * alpha)
	for pf in puffs:
		ctrl.draw_circle(cen + (pf["off"] as Vector2) + Vector2(2.0, 4.0), float(pf["r"]) + 2.0, sh_col)
	var ink_c := Color(0.55, 0.34, 0.10, 0.92 * alpha) if highlight else Color(0.16, 0.11, 0.08, 0.85 * alpha)
	for pf in puffs:
		ctrl.draw_circle(cen + (pf["off"] as Vector2), float(pf["r"]) + 2.0, ink_c)
	var fill_c := Color(0.95, 0.90, 0.76, 0.90 * alpha) if highlight else Color(0.86, 0.81, 0.70, 0.82 * alpha)
	ctrl.draw_rect(Rect2(cen - Vector2(txt_w * 0.34, 10.5 * sc), Vector2(txt_w * 0.68, 21.0 * sc)), fill_c)
	for pf in puffs:
		ctrl.draw_circle(cen + (pf["off"] as Vector2), float(pf["r"]), fill_c)
	# Small drifting cloud-whisper tail beads
	ctrl.draw_circle(cen + Vector2(-txt_w * 0.14, 19.0 * sc), 4.2 * sc, ink_c)
	ctrl.draw_circle(cen + Vector2(-txt_w * 0.14, 19.0 * sc), 2.8 * sc, fill_c)
	ctrl.draw_circle(cen + Vector2(-txt_w * 0.21, 25.0 * sc), 2.5 * sc, ink_c)
	var txt_col := Color(0.14, 0.08, 0.05, 0.95 * alpha)
	ctrl.draw_string(font, cen + Vector2(-txt_w * 0.5, 4.5 * sc), txt, HORIZONTAL_ALIGNMENT_CENTER, txt_w, maxi(10, int(round(12.0 * sc))), txt_col)

func _play_map_opening_animations() -> void:
	# 10 Choreographed Map Opening Animations when opening the Chronicle Atlas!
	map_open_active = true
	map_open_time = 0.0

	# 1) Camera Aerial Swoop & Zoom Settle
	if is_instance_valid(cam_3d):
		cam_zoom = 1.28
		cam_3d.position = Vector3(0.0, 27.5, 16.5)

	# 2) Folio Border Scale & Fade-In
	if is_instance_valid(map_frame_rect):
		map_frame_rect.pivot_offset = map_frame_rect.size * 0.5
		map_frame_rect.scale = Vector2(1.045, 1.045)
		map_frame_rect.modulate.a = 0.2
		var ftw := map_frame_rect.create_tween().set_parallel(true)
		ftw.tween_property(map_frame_rect, "scale", Vector2.ONE, 0.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ftw.tween_property(map_frame_rect, "modulate:a", 1.0, 0.42)

	# 3) Top Parchment Toolbar Slide-Down
	if is_instance_valid(map_top_panel):
		map_top_panel.position = Vector2(40, -52)
		map_top_panel.modulate.a = 0.0
		var ttw := map_top_panel.create_tween().set_parallel(true)
		ttw.tween_property(map_top_panel, "position:y", 28.0, 0.46).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ttw.tween_property(map_top_panel, "modulate:a", 1.0, 0.34).set_delay(0.08)

	# 4) Bottom Era Chronicle Plaque Rise
	if is_instance_valid(campaign_card_panel):
		campaign_card_panel.offset_top = -196
		campaign_card_panel.offset_bottom = 50
		campaign_card_panel.modulate.a = 0.0
		var ctw := campaign_card_panel.create_tween().set_parallel(true)
		ctw.tween_property(campaign_card_panel, "offset_top", -316.0, 0.50).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ctw.tween_property(campaign_card_panel, "offset_bottom", -32.0, 0.50).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ctw.tween_property(campaign_card_panel, "modulate:a", 1.0, 0.36).set_delay(0.14)

	# 5) 5 Era Monuments Staggered Pop-Up
	for i in range(era_towers.size()):
		var tw_n := era_towers[i]
		if is_instance_valid(tw_n):
			tw_n.scale = Vector3(0.06, 0.06, 0.06)
			var mtw := tw_n.create_tween()
			mtw.tween_interval(0.10 + float(i) * 0.075)
			mtw.tween_property(tw_n, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 6) 5 Floating Era Medallions Swoop-In (swoop curve smoothly blended in _process via map_open_time)
	# 7) Crimson Expedition Wax Beads Sequential Path Ripple
	for bi in range(map_trail_beads.size()):
		var bd := map_trail_beads[bi]
		if is_instance_valid(bd):
			bd.scale = Vector3(0.01, 0.01, 0.01)
			var btw := bd.create_tween()
			btw.tween_interval(0.16 + float(bi) * 0.012)
			btw.tween_property(bd, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 8) Compass Rose Calibration Spin (blended cleanly in _process via map_open_time)
	# 9) Occult Candle Beacons Flare Ignition
	for i in range(era_beacon_lights.size()):
		var bl := era_beacon_lights[i]
		if is_instance_valid(bl):
			var tgt_e := 1.35 if (i == selected_era_idx) else 0.65
			bl.light_energy = 0.0
			var ltw := bl.create_tween()
			ltw.tween_property(bl, "light_energy", tgt_e, 0.52).set_delay(0.18 + float(i) * 0.07)

	# 10) Book Folio Spine / Bookmark Ribbon / Cloud Whisper Blossom (driven in book_folio_fx via map_open_time)
	var zoom_tw := create_tween()
	zoom_tw.tween_property(self, "cam_zoom", 1.0, 0.76).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _make_modal_card_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	return sb

func _build_roguelite_modals() -> void:
	# 1. TRAVELING ALCHEMIST & MERCHANT SHOP MODAL
	shop_modal = PanelContainer.new()
	shop_modal.anchor_left = 0.5
	shop_modal.anchor_top = 0.5
	shop_modal.anchor_right = 0.5
	shop_modal.anchor_bottom = 0.5
	shop_modal.offset_left = -430
	shop_modal.offset_top = -295
	shop_modal.offset_right = 430
	shop_modal.offset_bottom = 295
	shop_modal.visible = false
	shop_modal.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.08, 0.06, 0.05, 0.96), Color(0.95, 0.78, 0.30)))
	ui_layer.add_child(shop_modal)

	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 10)
	shop_modal.add_child(svb)

	var shdr := HBoxContainer.new()
	shdr.add_theme_constant_override("separation", 12)
	svb.add_child(shdr)

	shop_title_lbl = Label.new()
	shop_title_lbl.text = _tr("✦ RUNECASTER'S BAZAAR ✦", "✦ RUNOVÝ OBCHOD ✦")
	shop_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_title_lbl.add_theme_font_override("font", _get_font(true))
	shop_title_lbl.add_theme_font_size_override("font_size", 25)
	shop_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34))
	shdr.add_child(shop_title_lbl)

	shop_gold_lbl = Label.new()
	shop_gold_lbl.text = "🪙 65"
	shop_gold_lbl.add_theme_font_override("font", _get_font(true))
	shop_gold_lbl.add_theme_font_size_override("font_size", 22)
	shop_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.44))
	shdr.add_child(shop_gold_lbl)

	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svb.add_child(shop_scroll)

	shop_items_box = VBoxContainer.new()
	shop_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_items_box.add_theme_constant_override("separation", 10)
	shop_scroll.add_child(shop_items_box)

	var s_ftr := HBoxContainer.new()
	s_ftr.alignment = BoxContainer.ALIGNMENT_END
	s_ftr.add_theme_constant_override("separation", 12)
	svb.add_child(s_ftr)

	var reroll_btn := Button.new()
	reroll_btn.text = _tr("🎲 Reroll (15 🪙)", "🎲 Nová nabídka (15 🪙)")
	reroll_btn.add_theme_font_size_override("font_size", 16)
	reroll_btn.custom_minimum_size = Vector2(215, 42)
	reroll_btn.pressed.connect(func():
		var g := int(run_profile.get("gold", 0))
		if g < 15:
			_play_sfx("error")
			return
		run_profile["gold"] = g - 15
		var rr := int(run_profile.get("shop_rerolls", 0)) + 1
		run_profile["shop_rerolls"] = rr
		var rs: Dictionary = run_profile.get("relic_scales", {})
		rs["REL_MERCHANT_LEDGER"] = rr * 18
		run_profile["relic_scales"] = rs
		shop_offers = Catalog.generate_shop_offers(run_profile, str(game_options.get("language", "en")))
		Catalog.save_profile(run_profile)
		_play_sfx("card_shuffle")
		_rebuild_shop_ui(false)
		_refresh_map_roguelite_hud()
	)
	s_ftr.add_child(reroll_btn)
	shop_reroll_btn = reroll_btn

	var shop_close := Button.new()
	shop_close.text = _tr("✓ Return to Map", "✓ Zpět na mapu")
	shop_close.add_theme_font_size_override("font_size", 16)
	shop_close.custom_minimum_size = Vector2(180, 42)
	shop_close.pressed.connect(func():
		_play_sfx("ui_click")
		_close_animated_modal(shop_modal)
		_refresh_map_roguelite_hud()
		_update_campaign_card(selected_era_idx)
	)
	s_ftr.add_child(shop_close)
	shop_close_btn = shop_close

	# 1B. DECK SCULPTING & ALCHEMY TARGET PICKER MODAL
	sculpt_modal = PanelContainer.new()
	sculpt_modal.anchor_left = 0.5
	sculpt_modal.anchor_top = 0.5
	sculpt_modal.anchor_right = 0.5
	sculpt_modal.anchor_bottom = 0.5
	sculpt_modal.offset_left = -465
	sculpt_modal.offset_top = -310
	sculpt_modal.offset_right = 465
	sculpt_modal.offset_bottom = 310
	sculpt_modal.visible = false
	sculpt_modal.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.08, 0.06, 0.10, 0.98), Color(0.68, 0.92, 0.48)))
	ui_layer.add_child(sculpt_modal)

	var sc_vb := VBoxContainer.new()
	sc_vb.add_theme_constant_override("separation", 10)
	sculpt_modal.add_child(sc_vb)

	sculpt_title_lbl = Label.new()
	sculpt_title_lbl.text = _tr("⚒ RUNEFORGE — CARD TRANSMUTATION", "⚒ RUNOVÁ KOVÁRNA — ÚPRAVA KARET")
	sculpt_title_lbl.add_theme_font_override("font", _get_font(true))
	sculpt_title_lbl.add_theme_font_size_override("font_size", 24)
	sculpt_title_lbl.add_theme_color_override("font_color", Color(0.86, 0.96, 0.54))
	sc_vb.add_child(sculpt_title_lbl)

	sculpt_desc_lbl = Label.new()
	sculpt_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sculpt_desc_lbl.add_theme_font_size_override("font_size", 16)
	sculpt_desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85))
	sc_vb.add_child(sculpt_desc_lbl)

	sculpt_suit_bar = HBoxContainer.new()
	sculpt_suit_bar.add_theme_constant_override("separation", 10)
	sculpt_suit_bar.visible = false
	sc_vb.add_child(sculpt_suit_bar)

	var suit_opts := [
		{"id": "CERVEN", "en": "Hearts", "cs": "Srdce",  "col": Color(0.96, 0.34, 0.38)},
		{"id": "ZALUD",  "en": "Acorns", "cs": "Žaludy", "col": Color(0.90, 0.72, 0.38)},
		{"id": "ZELEN",  "en": "Leaves", "cs": "Listy",  "col": Color(0.32, 0.84, 0.62)},
		{"id": "GULA",   "en": "Bells",  "cs": "Kule",   "col": Color(1.0, 0.66, 0.28)},
	]
	for so in suit_opts:
		var sbtn := Button.new()
		sbtn.text = _tr(str(so["en"]), str(so["cs"]))
		sbtn.set_meta("en_label", str(so["en"]))
		sbtn.set_meta("cs_label", str(so["cs"]))
		var crest_ic := suit_crest_cache.get(str(so["id"]), null) as Texture2D
		if crest_ic != null:
			sbtn.icon = crest_ic
			sbtn.expand_icon = true
		sbtn.custom_minimum_size = Vector2(180, 38)
		sbtn.add_theme_font_size_override("font_size", 16)
		sbtn.add_theme_color_override("font_color", so["col"])
		var target_sid: String = str(so["id"])
		sbtn.pressed.connect(func():
			_play_sfx("ui_click")
			sculpt_selected_suit = target_sid
			_rebuild_sculpt_grid()
		)
		sculpt_suit_bar.add_child(sbtn)

	var sc_scroll := ScrollContainer.new()
	sc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc_vb.add_child(sc_scroll)

	sculpt_grid = GridContainer.new()
	sculpt_grid.columns = 8
	sculpt_grid.add_theme_constant_override("h_separation", 6)
	sculpt_grid.add_theme_constant_override("v_separation", 6)
	sculpt_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_scroll.add_child(sculpt_grid)

	var sc_cancel := Button.new()
	sc_cancel.text = _tr("← Back to Shop", "← Zpět do obchodu")
	sc_cancel.add_theme_font_size_override("font_size", 16)
	sc_cancel.custom_minimum_size = Vector2(220, 40)
	sc_cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	sc_cancel.pressed.connect(func():
		_play_sfx("ui_click")
		sculpt_pending_offer_idx = -1
		_close_animated_modal(sculpt_modal)
		_open_animated_modal(shop_modal)
	)
	sc_vb.add_child(sc_cancel)
	sculpt_cancel_btn = sc_cancel

	# 2. LIALO ALMANAC & CUSTOM ART CODEX MODAL
	almanac_modal = PanelContainer.new()
	almanac_modal.anchor_left = 0.5
	almanac_modal.anchor_top = 0.5
	almanac_modal.anchor_right = 0.5
	almanac_modal.anchor_bottom = 0.5
	almanac_modal.offset_left = -450
	almanac_modal.offset_top = -305
	almanac_modal.offset_right = 450
	almanac_modal.offset_bottom = 305
	almanac_modal.visible = false
	almanac_modal.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.06, 0.06, 0.10, 0.96), Color(0.55, 0.86, 1.0)))
	ui_layer.add_child(almanac_modal)

	var avb := VBoxContainer.new()
	avb.add_theme_constant_override("separation", 10)
	almanac_modal.add_child(avb)

	var ahdr := HBoxContainer.new()
	ahdr.add_theme_constant_override("separation", 8)
	avb.add_child(ahdr)

	var a_title := Label.new()
	a_title.text = _tr("📖 LIALO GRIMOIRE", "📖 GRIMOÁR LIALO")
	a_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_title.add_theme_font_override("font", _get_font(true))
	a_title.add_theme_font_size_override("font_size", 22)
	a_title.add_theme_color_override("font_color", Color(0.65, 0.92, 1.0))
	ahdr.add_child(a_title)
	almanac_title_lbl = a_title

	var vis_rel_cnt := Catalog.get_visible_relics().size()
	var pwr_cnt := Catalog.POWER_CARDS.size()
	var t_names_en := ["%d Power Cards" % pwr_cnt, "%d Relics" % vis_rel_cnt, "5 Classes", "⚒ 6 Runeforge", "⚔ 5 Swords"]
	var t_names_cs := ["%d Mocných" % pwr_cnt, "%d Relikvií" % vis_rel_cnt, "5 Tříd", "⚒ 6 Kovárna", "⚔ 5 Čepelí"]
	almanac_tab_btns.clear()
	for ti in range(t_names_en.size()):
		var tbtn := Button.new()
		tbtn.text = _tr(t_names_en[ti], t_names_cs[ti])
		tbtn.set_meta("en_label", t_names_en[ti])
		tbtn.set_meta("cs_label", t_names_cs[ti])
		tbtn.add_theme_font_size_override("font_size", 15)
		tbtn.custom_minimum_size = Vector2(124, 36)
		tbtn.pressed.connect(func():
			_play_sfx("ui_click")
			almanac_tab_idx = ti
			_rebuild_almanac_ui()
		)
		ahdr.add_child(tbtn)
		almanac_tab_btns.append(tbtn)

	var a_scroll := ScrollContainer.new()
	a_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avb.add_child(a_scroll)

	almanac_list_box = VBoxContainer.new()
	almanac_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	almanac_list_box.add_theme_constant_override("separation", 8)
	a_scroll.add_child(almanac_list_box)

	var a_close := Button.new()
	a_close.text = _tr("Close Codex", "Zavřít grimoár")
	a_close.add_theme_font_size_override("font_size", 16)
	a_close.custom_minimum_size = Vector2(160, 40)
	a_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	a_close.pressed.connect(func():
		_play_sfx("ui_click")
		_close_animated_modal(almanac_modal)
	)
	avb.add_child(a_close)
	almanac_close_btn = a_close

func _open_shop_modal(after_win: bool = false) -> void:
	shop_offers = Catalog.generate_shop_offers(run_profile, str(game_options.get("language", "en"))) if shop_offers.is_empty() else shop_offers
	if almanac_modal:
		almanac_modal.visible = false
	if sculpt_modal:
		sculpt_modal.visible = false
	_rebuild_shop_ui(after_win)
	_open_animated_modal(shop_modal)

func _rebuild_shop_ui(after_win: bool = false) -> void:
	if not shop_items_box or not shop_gold_lbl:
		return
	var g := int(run_profile.get("gold", 0))
	shop_gold_lbl.text = _tr("🪙 %d Florins" % g, "🪙 %d Zlaťáků" % g)
	if after_win and not pending_post_loss_spoils.is_empty():
		shop_title_lbl.text = _tr("🛡 CONSOLATION (+%dg • %s Crafted • Blessing ×%d)" % [
			int(pending_post_loss_spoils.get("gold", 35)),
			str(pending_post_loss_spoils.get("upgraded_card", "Card")),
			int(pending_post_loss_spoils.get("blessing", 1)),
		], "🛡 ÚTĚCHA (+%d🪙 • %s ukována • Požehnání ×%d)" % [
			int(pending_post_loss_spoils.get("gold", 35)),
			str(pending_post_loss_spoils.get("upgraded_card", "Karta")),
			int(pending_post_loss_spoils.get("blessing", 1)),
		])
		pending_post_loss_spoils.clear()
	elif after_win and not last_victory_info.is_empty():
		shop_title_lbl.text = _tr("★ VICTORY (+%d 🪙)  •  CHOOSE CARD UPGRADES ★" % int(last_victory_info.get("gold_earned", 40)), "★ VÍTĚZSTVÍ (+%d 🪙)  •  VYBER VYLEPŠENÍ KARET ★" % int(last_victory_info.get("gold_earned", 40)))
	else:
		shop_title_lbl.text = _tr("✦ CARD UPGRADE FORGE (%d OFFERS) ✦" % shop_offers.size(), "✦ KOVÁRNA VYLEPŠENÍ KARET (%d NABÍDEK) ✦" % shop_offers.size())

	for c in shop_items_box.get_children():
		c.queue_free()

	if after_win and not last_victory_info.is_empty():
		var new_ul_raw: Variant = last_victory_info.get("new_unlocks", [])
		if new_ul_raw is Array and not (new_ul_raw as Array).is_empty():
			var ul_banner := PanelContainer.new()
			var ul_sb := _make_modal_card_style(Color(0.08, 0.12, 0.16, 0.98), Color(0.36, 0.92, 0.68))
			ul_sb.set_corner_radius_all(18)
			ul_sb.content_margin_left = 18; ul_sb.content_margin_right = 18
			ul_sb.content_margin_top = 12; ul_sb.content_margin_bottom = 12
			ul_banner.add_theme_stylebox_override("panel", ul_sb)
			var ul_vb := VBoxContainer.new()
			ul_vb.add_theme_constant_override("separation", 6)
			ul_banner.add_child(ul_vb)
			var ul_hdr := Label.new()
			ul_hdr.text = _tr("✦ NEW UNLOCK — USABLE IN CAMPAIGN & MULTIPLAYER", "✦ NOVÉ ODEMČENÍ — KAMPAŇ I MULTIPLAYER")
			ul_hdr.add_theme_font_override("font", _get_font(true))
			ul_hdr.add_theme_font_size_override("font_size", 17)
			ul_hdr.add_theme_color_override("font_color", Color(0.46, 1.0, 0.72))
			ul_vb.add_child(ul_hdr)
			var ul_items_hb := HFlowContainer.new()
			ul_items_hb.add_theme_constant_override("h_separation", 10)
			ul_items_hb.add_theme_constant_override("v_separation", 6)
			ul_vb.add_child(ul_items_hb)
			for ul_entry_v in (new_ul_raw as Array):
				if not (ul_entry_v is Dictionary):
					continue
				var ul_e: Dictionary = ul_entry_v
				var uk := str(ul_e.get("kind", ""))
				var u_name := str(ul_e.get("name_cs" if _is_cs() else "name", ul_e.get("id", "")))
				var u_col: Color = ul_e.get("col", Color(1.0, 0.86, 0.34))
				var kind_tag := ""
				if uk == "power_card":
					kind_tag = _tr("Power Card", "Mocná karta")
				elif uk == "relic":
					kind_tag = _tr("Relic", "Relikvie")
				elif uk == "table_relic":
					kind_tag = _tr("3D Table Relic", "3D Relikvie")
				var pill := PanelContainer.new()
				pill.add_theme_stylebox_override("panel", _make_pill_style(Color(0.06, 0.08, 0.11, 0.96), u_col, 3))
				var plbl := Label.new()
				plbl.text = "✦ %s (%s)" % [u_name, kind_tag]
				plbl.add_theme_font_override("font", _get_font(true))
				plbl.add_theme_font_size_override("font_size", 14)
				plbl.add_theme_color_override("font_color", u_col.lightened(0.24))
				pill.add_child(plbl)
				ul_items_hb.add_child(pill)
			shop_items_box.add_child(ul_banner)

	if not Catalog.has_seen_unlock_tip(run_profile, "unlock_shop"):
		var tip_card := PanelContainer.new()
		var t_sb := _make_modal_card_style(Color(0.08, 0.14, 0.10, 0.96), Color(0.42, 0.94, 0.62))
		t_sb.set_corner_radius_all(16)
		t_sb.content_margin_left = 16; t_sb.content_margin_right = 16
		t_sb.content_margin_top = 10; t_sb.content_margin_bottom = 10
		tip_card.add_theme_stylebox_override("panel", t_sb)
		var thb := HBoxContainer.new()
		thb.add_theme_constant_override("separation", 12)
		tip_card.add_child(thb)
		var tlbl := Label.new()
		tlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tlbl.text = _tr(
			"✦ FIRST TIME IN THE FORGE: Spend Florins on Power Cards & Card Class Upgrades (Mage/Knight/Merchant/Thief) to power up your deck!",
			"✦ POPRVÉ V KOVÁRNĚ: Utrať Zlaťáky za Mocné karty a Edice karet (Mág/Rytíř/Kupec/Zloděj) pro posílení balíčku!"
		)
		tlbl.add_theme_font_override("font", _get_font(true))
		tlbl.add_theme_font_size_override("font_size", 14)
		tlbl.add_theme_color_override("font_color", Color(0.76, 1.0, 0.84))
		thb.add_child(tlbl)
		var tbtn := Button.new()
		tbtn.text = _tr("Got it", "Rozumím")
		tbtn.custom_minimum_size = Vector2(108, 32)
		tbtn.add_theme_font_override("font", _get_font(true))
		tbtn.add_theme_font_size_override("font_size", 13)
		var tb_sb := _make_modal_card_style(Color(0.14, 0.28, 0.18, 0.98), Color(0.46, 0.96, 0.64))
		tb_sb.set_corner_radius_all(10)
		tbtn.add_theme_stylebox_override("normal", tb_sb)
		tbtn.add_theme_stylebox_override("hover", tb_sb)
		tbtn.pressed.connect(func():
			Catalog.mark_unlock_tip_seen(run_profile, "unlock_shop")
			tip_card.queue_free()
		)
		thb.add_child(tbtn)
		shop_items_box.add_child(tip_card)

	for i in range(shop_offers.size()):
		var off: Dictionary = shop_offers[i]
		var card_row := PanelContainer.new()
		var ocol: Color = off.get("col", Color(1.0, 0.84, 0.30))
		var row_sb := _make_modal_card_style(Color(0.11, 0.08, 0.10, 0.96), ocol)
		row_sb.set_corner_radius_all(22)
		row_sb.content_margin_left = 18; row_sb.content_margin_right = 18
		row_sb.content_margin_top = 14; row_sb.content_margin_bottom = 14
		card_row.add_theme_stylebox_override("panel", row_sb)
		shop_items_box.add_child(card_row)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		card_row.add_child(hb)

		var off_kind := str(off.get("kind", ""))
		if off_kind == "power_card" or off_kind == "relic":
			var art_p := ""
			if off_kind == "power_card":
				var pc_info := Catalog.get_power_card(str(off.get("id", "")))
				art_p = "res://assets/cards/" + str(pc_info.get("art_file", ""))
			else:
				art_p = Catalog.get_relic_art_path(str(off.get("id", "")))
			if art_p != "" and ResourceLoader.exists(art_p):
				var thumb_frame := PanelContainer.new()
				thumb_frame.custom_minimum_size = Vector2(72, 92) if off_kind == "power_card" else Vector2(76, 76)
				thumb_frame.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.08, 0.06, 0.05), ocol))
				var tex_r := TextureRect.new()
				tex_r.texture = Toon.tex(art_p) if off_kind == "relic" else load(art_p)
				tex_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_r.custom_minimum_size = Vector2(58, 84) if off_kind == "power_card" else Vector2(64, 64)
				thumb_frame.add_child(tex_r)
				hb.add_child(thumb_frame)
		elif off_kind == "table_relic":
			var tr_thumb := PanelContainer.new()
			tr_thumb.custom_minimum_size = Vector2(76, 76)
			tr_thumb.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.06, 0.05, 0.08), ocol))
			var tr_badge := Label.new()
			tr_badge.text = "✦\n3D"
			tr_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tr_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tr_badge.add_theme_font_override("font", _get_font(true))
			tr_badge.add_theme_font_size_override("font_size", 20)
			tr_badge.add_theme_color_override("font_color", ocol.lightened(0.32))
			tr_thumb.add_child(tr_badge)
			hb.add_child(tr_thumb)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info_vb)

		var t_lbl := Label.new()
		t_lbl.text = "%s   (%s)" % [str(off["title"]), str(off["sub"])]
		t_lbl.add_theme_font_override("font", _get_font(true))
		t_lbl.add_theme_font_size_override("font_size", 19)
		t_lbl.add_theme_color_override("font_color", ocol.lightened(0.28))
		info_vb.add_child(t_lbl)

		var d_lbl := Label.new()
		d_lbl.text = str(off["desc"])
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 14)
		d_lbl.add_theme_color_override("font_color", Color(0.92, 0.89, 0.84))
		info_vb.add_child(d_lbl)

		var cost := int(off["cost"])
		var bought := bool(off.get("bought", false))
		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(160, 46)
		if bought:
			buy_btn.text = _tr("✓ UPGRADED", "✓ VYLEPŠENO")
			buy_btn.disabled = true
		else:
			buy_btn.text = _tr("Upgrade (%d 🪙)" % cost, "Vylepšit (%d 🪙)" % cost)
			buy_btn.disabled = (g < cost)
			buy_btn.pressed.connect(func():
				_buy_shop_offer(i)
			)
		hb.add_child(buy_btn)

func _get_current_sculptable_cards(include_powers: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var suits := ["CERVEN", "ZELEN", "ZALUD", "GULA"]
	var ranks := ["7", "8", "9", "10", "D", "H", "K", "E"]
	var rnames := ({"7": "Sedma", "8": "Osma (∞)", "9": "Devítka", "10": "Desítka", "D": "Spodek", "H": "Svršek", "K": "Král", "E": "Eso"} if _is_cs() else {"7": "Seven", "8": "Eight (∞)", "9": "Nine", "10": "Ten", "D": "Jack", "H": "Queen", "K": "King", "E": "Ace"})
	var removed: Array = run_profile.get("removed_cards", [])
	var overrides: Dictionary = run_profile.get("suit_overrides", {})
	var editions: Dictionary = run_profile.get("card_editions", {})
	for s_id in suits:
		for r_id in ranks:
			var ok := "%s_%s" % [s_id, r_id]
			if ok in removed:
				continue
			out.append({
				"is_clone": false,
				"is_power": false,
				"orig_key": ok,
				"suit": str(overrides.get(ok, s_id)),
				"rank": r_id,
				"rname": str(rnames[r_id]),
				"edition": Catalog.normalize_card_class(str(editions.get(ok, "NORMAL"))),
			})
	var added: Array = run_profile.get("added_cards", [])
	for ci in range(added.size()):
		var ac = added[ci]
		if not (ac is Dictionary):
			continue
		var rr := str(ac.get("rank", "E"))
		out.append({
			"is_clone": true,
			"is_power": false,
			"clone_idx": ci,
			"orig_key": str(ac.get("source_key", "CLONE_%d" % ci)),
			"suit": str(ac.get("suit", "CERVEN")),
			"rank": rr,
			"rname": str(rnames.get(rr, rr)),
			"edition": Catalog.normalize_card_class(str(ac.get("edition", "NORMAL"))),
		})
	if include_powers:
		var seen_pwr := {}
		for pc_id in run_profile.get("custom_cards", []):
			var pid := str(pc_id)
			if seen_pwr.has(pid):
				continue
			seen_pwr[pid] = true
			var pc := Catalog.get_power_card(pid)
			if pc.is_empty():
				continue
			out.append({
				"is_clone": false,
				"is_power": true,
				"orig_key": pid,
				"suit": str(pc["suit"]),
				"rank": "PWR",
				"rname": str(pc["name"]),
				"edition": Catalog.normalize_card_class(str(editions.get(pid, "NORMAL"))),
			})
	return out

func _open_sculpt_picker(offer_idx: int) -> void:
	sculpt_pending_offer_idx = offer_idx
	var off: Dictionary = shop_offers[offer_idx]
	var act := str(off.get("action", "remove"))
	if act == "convert_suit":
		sculpt_selected_suit = "CERVEN"
	if sculpt_title_lbl:
		sculpt_title_lbl.text = _tr("⚗ %s — Select Target Card" % str(off["title"]).to_upper(), "⚗ %s — Vyber kartu" % str(off["title"]).to_upper())
	if shop_modal:
		shop_modal.visible = false
	_rebuild_sculpt_grid()
	_open_animated_modal(sculpt_modal)

func _rebuild_sculpt_grid() -> void:
	if not sculpt_grid or sculpt_pending_offer_idx < 0 or sculpt_pending_offer_idx >= shop_offers.size():
		return
	for c in sculpt_grid.get_children():
		c.queue_free()
	var off: Dictionary = shop_offers[sculpt_pending_offer_idx]
	var act := str(off.get("action", "remove"))
	var cards := _get_current_sculptable_cards(act == "infuse")
	var classic_cnt := 0
	for ce in cards:
		if not bool(ce["is_power"]):
			classic_cnt += 1

	if sculpt_suit_bar:
		sculpt_suit_bar.visible = (act == "convert_suit")
	if sculpt_desc_lbl:
		var suit_sym := (
			{"CERVEN": "♥ Srdce", "ZELEN": "♠ Listy", "ZALUD": "♣ Žaludy", "GULA": "♦ Kule"}
			if _is_cs() else
			{"CERVEN": "♥ Hearts", "ZELEN": "♠ Leaves", "ZALUD": "♣ Acorns", "GULA": "♦ Bells"}
		)
		var extra := (_tr(" → Target: %s", " → Nová barva: %s") % str(suit_sym.get(sculpt_selected_suit, ""))) if act == "convert_suit" else ""
		sculpt_desc_lbl.text = _tr("%s\nClassic Pool: %d cards%s", "%s\nKlasický balíček: %d karet%s") % [str(off["desc"]), classic_cnt, extra]

	var syms := {"CERVEN": "♥", "ZELEN": "♠", "ZALUD": "♣", "GULA": "♦"}
	var cols := {
		"CERVEN": Color(0.96, 0.34, 0.38),
		"ZELEN": Color(0.28, 0.82, 0.58),
		"ZALUD": Color(0.90, 0.70, 0.36),
		"GULA": Color(1.0, 0.64, 0.24),
	}
	var lang_code := str(game_options.get("language", "en"))
	var cannot_remove := (act == "remove" and classic_cnt <= 12)
	for entry in cards:
		var btn := Button.new()
		var s_id := str(entry["suit"])
		var r_id := str(entry["rank"])
		var ed_id := Catalog.normalize_card_class(str(entry["edition"]))
		var tag := "*" if bool(entry["is_clone"]) else ("✦" if bool(entry["is_power"]) else "")
		var ed_loc := Catalog.get_card_class_loc(ed_id, lang_code)
		var ed_txt := ("\n[%s]" % str(ed_loc.get("name", ed_id))) if ed_id != "NORMAL" else _tr("\n[%dc]" % (22 if bool(entry["is_power"]) else int({"7":7,"8":8,"9":9,"10":10,"D":12,"H":16,"K":18,"E":20}.get(r_id, 10))), "\n[%d b.]" % (22 if bool(entry["is_power"]) else int({"7":7,"8":8,"9":9,"10":10,"D":12,"H":16,"K":18,"E":20}.get(r_id, 10))))
		var title_s := str(entry["rname"]).substr(0, 7) if bool(entry["is_power"]) else r_id
		btn.text = "%s %s%s%s" % [str(syms.get(s_id, "?")), title_s, tag, ed_txt]
		btn.custom_minimum_size = Vector2(96, 56)
		btn.disabled = cannot_remove and not bool(entry["is_power"])
		var bcol: Color = cols.get(s_id, Color.WHITE)
		if ed_id != "NORMAL":
			bcol = ed_loc.get("col", bcol)
		btn.add_theme_color_override("font_color", bcol.lightened(0.25))
		var e_copy: Dictionary = entry.duplicate()
		btn.pressed.connect(func():
			_confirm_sculpt_offer(sculpt_pending_offer_idx, e_copy)
		)
		sculpt_grid.add_child(btn)

func apply_alchemy_action(off: Dictionary, entry: Dictionary, target_suit: String = "CERVEN") -> String:
	var act := str(off.get("action", "remove"))
	var result_txt := _tr("Sculpted Deck", "Upraveno")
	var syms := {"CERVEN": "♥", "ZELEN": "♠", "ZALUD": "♣", "GULA": "♦"}
	if act == "remove":
		if bool(entry["is_clone"]):
			var added: Array = run_profile.get("added_cards", [])
			var cidx := int(entry["clone_idx"])
			if cidx >= 0 and cidx < added.size():
				added.remove_at(cidx)
			run_profile["added_cards"] = added
		else:
			var rem: Array = run_profile.get("removed_cards", [])
			var ok := str(entry["orig_key"])
			if not (ok in rem):
				rem.append(ok)
			run_profile["removed_cards"] = rem
		result_txt = _tr("Removed %s %s", "Odebráno: %s %s") % [str(syms.get(entry["suit"], "")), str(entry["rank"])]
	elif act == "clone":
		var added: Array = run_profile.get("added_cards", [])
		added.append({
			"suit": str(entry["suit"]),
			"rank": str(entry["rank"]),
			"edition": str(entry["edition"]),
			"source_key": str(entry["orig_key"]),
		})
		run_profile["added_cards"] = added
		result_txt = _tr("Cloned %s %s", "Klonováno: %s %s") % [str(syms.get(entry["suit"], "")), str(entry["rank"])]
	elif act == "convert_suit":
		if bool(entry["is_clone"]):
			var added: Array = run_profile.get("added_cards", [])
			var cidx := int(entry["clone_idx"])
			if cidx >= 0 and cidx < added.size() and added[cidx] is Dictionary:
				added[cidx]["suit"] = target_suit
			run_profile["added_cards"] = added
		else:
			var ov: Dictionary = run_profile.get("suit_overrides", {})
			ov[str(entry["orig_key"])] = target_suit
			run_profile["suit_overrides"] = ov
		result_txt = _tr("Converted to %s %s", "Změněno na %s %s") % [str(syms.get(target_suit, "")), str(entry["rank"])]
	elif act == "infuse":
		var ed_id := Catalog.normalize_card_class(str(off.get("edition", "MAGE")))
		if bool(entry["is_clone"]):
			var added: Array = run_profile.get("added_cards", [])
			var cidx := int(entry["clone_idx"])
			if cidx >= 0 and cidx < added.size() and added[cidx] is Dictionary:
				added[cidx]["edition"] = ed_id
			run_profile["added_cards"] = added
		else:
			var ce: Dictionary = run_profile.get("card_editions", {})
			ce[str(entry["orig_key"])] = ed_id
			run_profile["card_editions"] = ce
		var ed_loc := Catalog.get_card_class_loc(ed_id, str(game_options.get("language", "en")))
		result_txt = _tr("Infused %s on %s %s", "Třída %s → %s %s") % [str(ed_loc.get("name", ed_id)), str(syms.get(entry["suit"], "")), str(entry["rank"])]
	return result_txt

func _confirm_sculpt_offer(offer_idx: int, entry: Dictionary) -> void:
	if offer_idx < 0 or offer_idx >= shop_offers.size():
		return
	var off: Dictionary = shop_offers[offer_idx]
	if bool(off.get("bought", false)):
		return
	var cost := int(off["cost"])
	var g := int(run_profile.get("gold", 0))
	if g < cost:
		_play_sfx("error")
		return
	run_profile["gold"] = g - cost
	off["bought"] = true
	off["sub"] = apply_alchemy_action(off, entry, sculpt_selected_suit)
	Catalog.save_profile(run_profile)
	_play_sfx("win")
	sculpt_pending_offer_idx = -1
	if sculpt_modal:
		sculpt_modal.visible = false
	_rebuild_shop_ui(false)
	_open_animated_modal(shop_modal)
	_refresh_map_roguelite_hud()
	_update_campaign_card(selected_era_idx)

func _show_shop_toast(msg: String, col: Color = Color(0.46, 0.96, 0.62)) -> void:
	if not shop_modal:
		return
	var old_t := shop_modal.get_node_or_null("ShopToastPill")
	if old_t:
		old_t.queue_free()
	var toast := PanelContainer.new()
	toast.name = "ShopToastPill"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 95
	toast.add_theme_stylebox_override("panel", _make_pill_style(Color(0.06, 0.10, 0.08, 0.96), col, 4))
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.offset_top = 18
	toast.offset_left = -220
	toast.offset_right = 220
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _get_font(true))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", col.lightened(0.25))
	toast.add_child(lbl)
	shop_modal.add_child(toast)
	var tw := toast.create_tween()
	tw.tween_interval(1.9)
	tw.tween_property(toast, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if is_instance_valid(toast):
			toast.queue_free()
	)

func _buy_shop_offer(idx: int) -> void:
	if idx < 0 or idx >= shop_offers.size():
		return
	var off: Dictionary = shop_offers[idx]
	if bool(off.get("bought", false)):
		return
	var cost := int(off["cost"])
	var g := int(run_profile.get("gold", 0))
	if g < cost:
		_play_sfx("error")
		return

	var kind: String = str(off["kind"])
	if kind == "alchemy":
		_play_sfx("ui_click")
		_open_sculpt_picker(idx)
		return

	run_profile["gold"] = g - cost
	off["bought"] = true

	var oid := str(off.get("id", ""))
	if kind == "power_card":
		var cc: Array = run_profile.get("custom_cards", [])
		cc.append(oid)
		run_profile["custom_cards"] = cc
		Catalog.unlock_card(run_profile, oid)
		Catalog.unlock_power_card(run_profile, oid)
	elif kind == "table_relic":
		Catalog.grant_table_relic(run_profile, oid)
		Catalog.unlock_table_relic(run_profile, oid)
	elif kind == "relic":
		var ar: Array = run_profile.get("active_relics", [])
		if not (oid in ar):
			ar.append(oid)
		run_profile["active_relics"] = ar
		Catalog.unlock_relic(run_profile, oid)
		if oid == "REL_MERCHANT_LEDGER":
			var rs: Dictionary = run_profile.get("relic_scales", {})
			rs["REL_MERCHANT_LEDGER"] = maxi(int(rs.get("REL_MERCHANT_LEDGER", 0)), int(run_profile.get("shop_rerolls", 0)) * 18)
			run_profile["relic_scales"] = rs
	elif kind == "repair_relic":
		run_profile["broken_relics"] = []
		_show_shop_toast(_tr("⚒ Relics Repaired & Restored!", "⚒ Relikvie opraveny a obnoveny!"), Color(0.98, 0.78, 0.34))
	elif kind == "edition" or kind == "card_class":
		var ce: Dictionary = run_profile.get("card_editions", {})
		var cands := ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E", "CERVEN_K", "ZELEN_K", "GULA_K", "ZALUD_K", "CERVEN_7", "ZELEN_7", "GULA_7", "ZALUD_7"]
		var chosen_k := ""
		for ck in cands:
			if not ce.has(ck):
				chosen_k = ck
				break
		if chosen_k == "":
			chosen_k = cands[randi() % cands.size()]
		ce[chosen_k] = Catalog.normalize_card_class(str(off["id"]))
		run_profile["card_editions"] = ce
		off["sub"] = _tr("Applied to " + chosen_k, "Aplikováno na " + chosen_k)
	elif kind == "sword_skin":
		var us: Array = run_profile.get("unlocked_swords", ["SWORD_IRON"])
		var sid: String = str(off["id"])
		if not (sid in us):
			us.append(sid)
		run_profile["unlocked_swords"] = us
		run_profile["equipped_sword"] = sid
	elif kind == "pack_random":
		var cc: Array = run_profile.get("custom_cards", [])
		var pool := Catalog.POWER_CARDS.duplicate()
		pool.shuffle()
		for pi in range(mini(2, pool.size())):
			cc.append(str(pool[pi]["id"]))
		run_profile["custom_cards"] = cc

	Catalog.save_profile(run_profile)
	_play_sfx("win")
	_rebuild_shop_ui(false)
	_refresh_map_roguelite_hud()
	_update_campaign_card(selected_era_idx)

func _open_almanac_modal(tab: int = 0) -> void:
	almanac_tab_idx = tab
	if shop_modal:
		shop_modal.visible = false
	_rebuild_almanac_ui()
	_open_animated_modal(almanac_modal)

func _rebuild_almanac_ui() -> void:
	if not almanac_list_box:
		return
	for c in almanac_list_box.get_children():
		c.queue_free()

	var lang_code := str(game_options.get("language", "en"))
	var owned_cards: Array = run_profile.get("custom_cards", [])
	var owned_rel: Array = run_profile.get("active_relics", [])
	if almanac_tab_idx == 0:
		for pc_raw in Catalog.POWER_CARDS:
			var pc := Catalog.get_power_card_loc(str(pc_raw["id"]), lang_code)
			var cnt := 0
			for oc in owned_cards:
				if str(oc) == str(pc["id"]):
					cnt += 1
			var art_path := "res://assets/cards/" + str(pc["art_file"])
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.11, 0.10, 0.16, 0.92), pc["accent"]))
			var row_hb := HBoxContainer.new()
			row_hb.add_theme_constant_override("separation", 12)
			row.add_child(row_hb)
			if ResourceLoader.exists(art_path):
				var tr := TextureRect.new()
				tr.texture = load(art_path)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.custom_minimum_size = Vector2(46, 69)
				row_hb.add_child(tr)
			var lbl := Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var w_tag := _tr(" [WILD]", " [DIVOKÁ]") if bool(pc.get("wild", false)) else ""
			var o_tag := _tr(" • %d× IN DECK" % cnt, " • %d× V BALÍČKU" % cnt) if cnt > 0 else _tr(" • Shop", " • Obchod")
			lbl.text = "✦ %s (%s%s, +%d %s) — %s%s\n%s" % [
				str(pc["name"]), str(pc["rarity"]), w_tag, int(pc["pts"]), _tr("pts", "b."),
				str(pc["power_line"]), o_tag, str(pc["desc"])
			]
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
			row_hb.add_child(lbl)
			almanac_list_box.add_child(row)
	elif almanac_tab_idx == 1:
		var owned_tr_alm: Array = run_profile.get("table_relics", [])
		var tr_hdr := Label.new()
		tr_hdr.text = _tr("✦ ACTIVE 3D TABLETOP RELICS (Click on Table in Duel — 10 Total)", "✦ AKTIVNÍ 3D RELIKVIE NA STŮL (Klikni na stole v duelu — 10 celkem)")
		tr_hdr.add_theme_font_override("font", _get_font(true))
		tr_hdr.add_theme_font_size_override("font_size", 16)
		tr_hdr.add_theme_color_override("font_color", Color(0.54, 0.92, 1.0))
		almanac_list_box.add_child(tr_hdr)
		for tr_raw in Catalog.TABLE_RELICS:
			var tid := str(tr_raw["id"])
			var tr_l := Catalog.get_table_relic_loc(tid, lang_code)
			var eq_tr := tid in owned_tr_alm
			var trow := PanelContainer.new()
			trow.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.10, 0.09, 0.14, 0.94), tr_l["col"]))
			var tlbl := Label.new()
			tlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tlbl.text = "✦ %s [3D TABLE • %s] — %d 🪙 %s\n%s" % [
				str(tr_l["name"]), str(tr_l.get("short", "USE")), int(tr_l["cost"]),
				(_tr("(ON TABLE!)", "(NA STOLE!)") if eq_tr else _tr("(Shop / Peddler)", "(Obchod / Kramář)")),
				str(tr_l["desc"])
			]
			tlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tlbl.add_theme_font_size_override("font_size", 15)
			tlbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
			trow.add_child(tlbl)
			almanac_list_box.add_child(trow)
		var pr_hdr := Label.new()
		pr_hdr.text = _tr("✦ PASSIVE RELICS (Automatic Scoring & Economy)", "✦ PASIVNÍ RELIKVIE (Automatické skórování a ekonomika)")
		pr_hdr.add_theme_font_override("font", _get_font(true))
		pr_hdr.add_theme_font_size_override("font_size", 16)
		pr_hdr.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
		almanac_list_box.add_child(pr_hdr)
		var r_scales: Dictionary = run_profile.get("relic_scales", {})
		for r_raw in Catalog.RELICS:
			var rid := str(r_raw["id"])
			if Catalog.is_relic_hidden(rid):
				continue
			var r := Catalog.get_relic_loc(rid, lang_code)
			var eq := rid in owned_rel
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.11, 0.10, 0.15, 0.92), r["col"]))
			var row_hb := HBoxContainer.new()
			row_hb.add_theme_constant_override("separation", 12)
			row.add_child(row_hb)
			var r_art_p := Catalog.get_relic_art_path(rid)
			if ResourceLoader.exists(r_art_p):
				var r_tr := TextureRect.new()
				r_tr.texture = Toon.tex(r_art_p)
				r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				r_tr.custom_minimum_size = Vector2(54, 54)
				row_hb.add_child(r_tr)
			var lbl := Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var scale_note := ""
			if rid == "REL_SEVEN_GRIMOIRE":
				scale_note = "  [%s: ×%.2f]" % [_tr("Now", "Teď"), 1.0 + float(r_scales.get("REL_SEVEN_GRIMOIRE", 0.0))]
			elif rid == "REL_MERCHANT_LEDGER":
				scale_note = "  [%s: +%d %s]" % [_tr("Now", "Teď"), maxi(18, int(r_scales.get("REL_MERCHANT_LEDGER", 0)) + 18), _tr("pts", "b.")]
			lbl.text = "✦ %s [%s • %s] — %d 🪙 %s%s\n%s" % [
				str(r["name"]), str(r.get("category", "")), str(r["icon"]), int(r["cost"]),
				(_tr("(EQUIPPED!)", "(VYBAVENO!)") if eq else ""), scale_note, str(r["desc"])
			]
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
			row_hb.add_child(lbl)
			almanac_list_box.add_child(row)
	elif almanac_tab_idx == 2:
		for ck in ["NORMAL", "MAGE", "KNIGHT", "MERCHANT", "THIEF"]:
			var ed: Dictionary = Catalog.get_card_class_loc(ck, lang_code)
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.10, 0.10, 0.16, 0.92), ed["col"]))
			var lbl := Label.new()
			lbl.text = "★ %s — %s" % [str(ed["name"]), str(ed["desc"])]
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", ed["col"].lightened(0.25))
			row.add_child(lbl)
			almanac_list_box.add_child(row)
	elif almanac_tab_idx == 3:
		var rem_c: int = run_profile.get("removed_cards", []).size()
		var add_c: int = run_profile.get("added_cards", []).size()
		var ov_c: int = run_profile.get("suit_overrides", {}).size()
		var sum_row := PanelContainer.new()
		sum_row.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.12, 0.14, 0.12, 0.94), Color(0.68, 0.94, 0.38)))
		var sum_lbl := Label.new()
		sum_lbl.text = _tr(
			"⚒ RUNEFORGE  •  Pool: %d cards  (Removed: %d | Cloned: %d | Inked: %d)",
			"⚒ RUNOVÁ KOVÁRNA  •  Balíček: %d karet  (Odebráno: %d | Klonů: %d | Přebarveno: %d)"
		) % [32 - rem_c + add_c, rem_c, add_c, ov_c]
		sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sum_lbl.add_theme_font_size_override("font_size", 15)
		sum_lbl.add_theme_color_override("font_color", Color(0.86, 0.96, 0.56))
		sum_row.add_child(sum_lbl)
		almanac_list_box.add_child(sum_row)
		for alc_raw in Catalog.ALCHEMY_ITEMS:
			var alc := Catalog.get_alchemy_item_loc(str(alc_raw["id"]), lang_code)
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.10, 0.10, 0.14, 0.92), alc["col"]))
			var lbl := Label.new()
			lbl.text = "⚒ %s (%s) — %d 🪙\n%s" % [str(alc["name"]), str(alc["sub"]), int(alc["cost"]), str(alc["desc"])]
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", alc["col"].lightened(0.20))
			row.add_child(lbl)
			almanac_list_box.add_child(row)
	else:
		var owned_sw: Array = run_profile.get("unlocked_swords", ["SWORD_IRON"])
		var eq_sw: String = str(run_profile.get("equipped_sword", "SWORD_IRON"))
		for sw_raw in Catalog.SWORD_SKINS:
			var sw := Catalog.get_sword_skin_loc(str(sw_raw["id"]), lang_code)
			var is_own := str(sw["id"]) in owned_sw
			var is_eq := str(sw["id"]) == eq_sw
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", _make_modal_card_style(Color(0.15, 0.11, 0.09, 0.94) if is_eq else Color(0.10, 0.10, 0.14, 0.92), sw["trail_col"] if is_own else Color(0.35, 0.36, 0.42)))
			var hb := HBoxContainer.new()
			row.add_child(hb)
			var lbl := Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var st_txt := _tr("⚔ EQUIPPED", "⚔ VYBAVENO") if is_eq else (_tr("✓ UNLOCKED", "✓ ODEMČENO") if is_own else ("🔒 " + str(sw["cost"]) + " 🪙"))
			lbl.text = "⚔ %s   [%s]\n%s" % [str(sw["name"]).to_upper(), st_txt, str(sw["desc"])]
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", sw["trail_col"].lightened(0.15) if is_own else Color(0.72, 0.72, 0.78))
			hb.add_child(lbl)
			if is_own and not is_eq:
				var eq_btn := Button.new()
				eq_btn.text = _tr("EQUIP BLADE", "VYBAVIT ČEPEL")
				eq_btn.custom_minimum_size = Vector2(145, 38)
				var sid: String = str(sw["id"])
				eq_btn.pressed.connect(func():
					_play_sfx("ui_click")
					run_profile["equipped_sword"] = sid
					Catalog.save_profile(run_profile)
					_rebuild_almanac_ui()
				)
				hb.add_child(eq_btn)
			almanac_list_box.add_child(row)

func _refresh_map_roguelite_hud() -> void:
	if map_gold_lbl:
		map_gold_lbl.text = "🪙 %d  |  %s %d" % [int(run_profile.get("gold", 0)), _tr("Asc.", "Vzestup"), int(run_profile.get("ascension", 1))]
	if map_relics_row:
		for c in map_relics_row.get_children():
			c.queue_free()
		for rel_id in run_profile.get("active_relics", []):
			if Catalog.is_relic_hidden(str(rel_id)):
				continue
			var r_info := Catalog.get_relic(str(rel_id))
			if r_info.is_empty():
				continue
			var l := Label.new()
			l.text = "[%s]" % str(r_info.get("icon", "R"))
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", r_info["col"].lightened(0.25))
			map_relics_row.add_child(l)

func _open_animated_modal(m: Control) -> void:
	if not is_instance_valid(m):
		return
	if m.has_meta("_modal_tw"):
		var old_tw = m.get_meta("_modal_tw")
		if old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
	var is_fullrect := (m.anchor_left == 0.0 and m.anchor_right == 1.0 and m.anchor_top == 0.0 and m.anchor_bottom == 1.0)
	m.pivot_offset = m.size * 0.5
	m.visible = true
	m.scale = Vector2.ONE if is_fullrect else Vector2(0.84, 0.84)
	if is_fullrect:
		# Keep full-rect modal backdrop strictly opaque so lobby/HUD layers never bleed through during fade-in.
		m.modulate.a = 1.0
		if m.get_child_count() > 0 and m.get_child(0) is Control:
			var inner := m.get_child(0) as Control
			inner.modulate.a = 0.0
			var tw_in := m.create_tween()
			tw_in.tween_property(inner, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			m.set_meta("_modal_tw", tw_in)
		return
	m.modulate.a = 0.0
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	m.set_meta("_modal_tw", tw)

func _close_animated_modal(m: Control) -> void:
	if not is_instance_valid(m) or not m.visible:
		return
	if m.has_meta("_modal_tw"):
		var old_tw = m.get_meta("_modal_tw")
		if old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
	var is_fullrect := (m.anchor_left == 0.0 and m.anchor_right == 1.0 and m.anchor_top == 0.0 and m.anchor_bottom == 1.0)
	m.pivot_offset = m.size * 0.5
	if is_fullrect:
		if m.get_child_count() > 0 and m.get_child(0) is Control:
			var inner := m.get_child(0) as Control
			var tw_out := m.create_tween()
			tw_out.tween_property(inner, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_QUAD)
			tw_out.chain().tween_callback(func():
				if is_instance_valid(m):
					m.visible = false
					m.scale = Vector2.ONE
					m.modulate.a = 1.0
				if is_instance_valid(inner):
					inner.modulate.a = 1.0
			)
			m.set_meta("_modal_tw", tw_out)
		else:
			m.visible = false
		return
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "scale", Vector2(0.88, 0.88), 0.16)
	tw.chain().tween_callback(func():
		if is_instance_valid(m):
			m.visible = false
			m.scale = Vector2.ONE
			m.modulate.a = 1.0
	)
	m.set_meta("_modal_tw", tw)

func _get_map_guide_body_text() -> String:
	return _tr(
		"1. PRŠÍ & GOAL (6 ROUNDS • 10 ♥ HP)\n   Match Suit or Rank. First to 0 cards wins the round!\n   Crossroads Shop opens after Round 3 & Round 6.\n\n" +
		"2. ABILITIES\n   • 7 (+2 Draw): If Rival has no 7, you score 3× (21 pts)!\n   • 8 (∞ Chain): Stack multiple 8s in one turn (Right-Click)!\n   • Jack: Shield  • Queen: Change Suit  • Ace: 1–3× DMG + Stun  • King: Curse\n\n" +
		"3. CARD CLASSES & VIEW\n   Mage (charges 0/2→2/2) • Knight (Mist) • Merchant (+16g) • Thief (Steal)\n   SPACE / Bottom edge raises cards. Hover props to inspect.",
		"1. PRŠÍ A CÍL (6 KOL • 10 ♥ HP)\n   Hoď stejnou barvu nebo hodnotu. Kdo vyprázdní ruku, vyhraje kolo!\n   Po 3. a 6. kole se otevře Křižovatka (Obchod).\n\n" +
		"2. SCHOPNOSTI KARET\n   • 7 (+2 lízání): Když soupeř nemá 7, získáš trojnásobek (21 b.)!\n   • 8 (∞ Řetěz): Můžeš dát více osmiček najednou (pravým tlačítkem)!\n   • Spodek: Štít  • Svršek: Změní barvu  • Eso: Omráčení + DMG  • Král: Kletba\n\n" +
		"3. TŘÍDY KARET A POHLED\n   Mág (nabíjí 0/2→2/2) • Rytíř (Mlha) • Kupec (+16g) • Zloděj (Krade)\n   MEZERNÍK zvedne karty. Najetím myši prohlédneš předměty na stole."
	)

func _animate_label_handwriting(lbl: Label, cps: float = 95.0) -> void:
	if not is_instance_valid(lbl):
		return
	var full_len := lbl.text.length()
	if full_len <= 0:
		lbl.visible_characters = -1
		return
	if lbl.has_meta("_hw_tw"):
		var old_tw = lbl.get_meta("_hw_tw")
		if old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
	lbl.visible_characters = 0
	var dur := clampf(float(full_len) / maxf(25.0, cps), 0.35, 3.2)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "visible_characters", full_len, dur).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.visible_characters = -1
	)
	lbl.set_meta("_hw_tw", tw)

func _build_map_guide_modal() -> void:
	# Popup 1: Rules & Overview
	map_guide_modal = PanelContainer.new()
	map_guide_modal.set_anchors_preset(Control.PRESET_CENTER)
	map_guide_modal.offset_left = -380
	map_guide_modal.offset_top = -235
	map_guide_modal.offset_right = 380
	map_guide_modal.offset_bottom = 235
	map_guide_modal.visible = false
	hud_3d_control.add_child(map_guide_modal)

	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 14)
	map_guide_modal.add_child(gv)

	var g_title := Label.new()
	g_title.text = _tr("DUEL LAWS — PRŠÍ & COMBAT", "PRAVIDLA DUELU — PRŠÍ A SOUBOJ")
	g_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g_title.add_theme_font_override("font", _get_font(true))
	g_title.add_theme_font_size_override("font_size", 28)
	g_title.add_theme_color_override("font_color", Color(0.98, 0.80, 0.36))
	gv.add_child(g_title)
	map_guide_title = g_title

	var g_body := Label.new()
	g_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g_body.add_theme_font_size_override("font_size", 17)
	g_body.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	g_body.text = _get_map_guide_body_text()
	gv.add_child(g_body)
	map_guide_body = g_body

	var g_btn_row := HBoxContainer.new()
	g_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	g_btn_row.add_theme_constant_override("separation", 16)
	gv.add_child(g_btn_row)

	var next_btn := Button.new()
	next_btn.custom_minimum_size = Vector2(225, 44)
	next_btn.add_theme_font_size_override("font_size", 17)
	next_btn.text = _tr("Controls & Nav →", "Ovládání →")
	next_btn.pressed.connect(func():
		_play_sfx("ui_click")
		_close_animated_modal(map_guide_modal)
		_open_animated_modal(map_nav_modal)
	)
	g_btn_row.add_child(next_btn)
	map_guide_next_btn = next_btn

	var ok_btn := Button.new()
	ok_btn.custom_minimum_size = Vector2(175, 44)
	ok_btn.add_theme_font_size_override("font_size", 17)
	ok_btn.text = _tr("Let's Play!", "Hrajeme!")
	ok_btn.pressed.connect(func():
		_play_sfx("ui_click")
		_close_animated_modal(map_guide_modal)
	)
	g_btn_row.add_child(ok_btn)
	map_guide_ok_btn = ok_btn

	# Popup 2: Cozy Centered Animated Map & Table Navigation Popup
	map_nav_modal = PanelContainer.new()
	map_nav_modal.set_anchors_preset(Control.PRESET_CENTER)
	map_nav_modal.offset_left = -350
	map_nav_modal.offset_top = -205
	map_nav_modal.offset_right = 350
	map_nav_modal.offset_bottom = 205
	map_nav_modal.visible = false
	hud_3d_control.add_child(map_nav_modal)

	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 12)
	map_nav_modal.add_child(nv)

	var n_title := Label.new()
	n_title.text = _tr("WORLD & TAVERN NAVIGATION", "OVLÁDÁNÍ MAPY A STOLU")
	n_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_title.add_theme_font_override("font", _get_font(true))
	n_title.add_theme_font_size_override("font_size", 28)
	n_title.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	nv.add_child(n_title)
	map_nav_title = n_title

	map_nav_row_widgets.clear()
	var nav_rows := [
		{"k_en": "WASD / Right Drag", "k_cs": "WASD / Pravé tlačítko", "d_en": "Pan across the 3D World Map", "d_cs": "Posun po 3D mapě světa"},
		{"k_en": "Mouse Wheel",       "k_cs": "Kolečko myši",          "d_en": "Zoom camera in or out", "d_cs": "Přiblížení / oddálení kamery"},
		{"k_en": "Click Monument",    "k_cs": "Klik na pevnost",       "d_en": "1× Select • 2× Enter Battle", "d_cs": "1× Vybrat • 2× Vstoupit do boje"},
		{"k_en": "SPACE / Bottom",    "k_cs": "MEZERNÍK / Dolní okraj","d_en": "Raise cards vs Top-Down table", "d_cs": "Zvednout karty / pohled shora"},
		{"k_en": "Hover Table Props", "k_cs": "Najetí na předmět",     "d_en": "Lifts prop & shows info", "d_cs": "Zvedne předmět a ukáže popis"},
		{"k_en": "W / R / Right-Click","k_cs": "W / R / Pravý klik",   "d_en": "[W] Play • [R] Peek • RMB 8× Combo", "d_cs": "[W] Hrát • [R] Náhled • RMB 8× řetěz"},
	]
	for pair in nav_rows:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		nv.add_child(r)
		var badge := Button.new()
		badge.disabled = true
		badge.custom_minimum_size = Vector2(250, 36)
		badge.text = _tr(str(pair["k_en"]), str(pair["k_cs"]))
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_disabled_color", Color(0.98, 0.85, 0.44))
		r.add_child(badge)
		var desc := Label.new()
		desc.text = _tr(str(pair["d_en"]), str(pair["d_cs"]))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.add_theme_font_size_override("font_size", 17)
		desc.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
		r.add_child(desc)
		map_nav_row_widgets.append({"badge": badge, "desc": desc, "data": pair})

	var nav_close := Button.new()
	nav_close.custom_minimum_size = Vector2(215, 44)
	nav_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nav_close.add_theme_font_size_override("font_size", 17)
	nav_close.text = _tr("Explore Map!", "Zpět na mapu!")
	nav_close.pressed.connect(func():
		_play_sfx("ui_click")
		_close_animated_modal(map_nav_modal)
	)
	nv.add_child(nav_close)
	map_nav_close_btn = nav_close

func _trigger_era_click_anim(idx: int) -> void:
	_play_sfx("ui_click", -7.0, 1.08)
	if idx >= 0 and idx < era_towers.size():
		var tw_root := era_towers[idx]
		var tw := tw_root.create_tween()
		tw.tween_property(tw_root, "scale", Vector3(1.12, 1.24, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tw_root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(era_ring_meshes.size()):
		var ring := era_ring_meshes[i]
		if not is_instance_valid(ring):
			continue
		if i == idx:
			ring.visible = true
			ring.scale = Vector3(0.65, 1.0, 0.65)
			var rtw := ring.create_tween()
			rtw.tween_property(ring, "scale", Vector3(1.45, 1.0, 1.45), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rtw.tween_callback(func(): ring.visible = false)
		else:
			ring.visible = false

func _update_campaign_card(idx: int) -> void:
	if idx < 0 or idx >= ERAS_DATA.size() or campaign_title_lbl == null:
		return
	var era: Dictionary = ERAS_DATA[idx]
	var e_id: String = str(era["id"])
	var stages: Array = Catalog.ERA_STAGES.get(e_id, [])
	var st_idx := clampi(int(run_profile.get("era_stage", {}).get(e_id, 0)), 0, maxi(0, stages.size() - 1))
	var st_data: Dictionary = stages[st_idx] if not stages.is_empty() else {"stage_name": era["boss"], "stage_name_cs": era.get("boss_cs", era["boss"]), "boss_desc": "", "boss_desc_cs": "", "target_mult": 1.0, "gold": 45}
	var asc := clampi(int(run_profile.get("ascension", 1)), 1, Catalog.MAX_ASCENSION)
	var max_asc := clampi(int(run_profile.get("highest_ascension", asc)), 1, Catalog.MAX_ASCENSION)
	var end_unlk := bool(run_profile.get("endless_unlocked", false))
	var lang_code := str(game_options.get("language", "en"))
	if not end_unlk:
		endless_mode_selected = false

	if asc_val_lbl:
		asc_val_lbl.text = "%s %d/%d (%.1f×)" % [_tr("Asc.", "Vzest."), asc, Catalog.MAX_ASCENSION, Catalog.get_ascension_mult(asc)]
		asc_val_lbl.tooltip_text = _tr("Unlocked up to Ascension %d", "Odemčeno do Vzestupu %d") % max_asc
	if endless_toggle_btn:
		if end_unlk:
			var ante := maxi(1, int(run_profile.get("endless_ante", 1)))
			endless_toggle_btn.disabled = false
			endless_toggle_btn.text = _tr("✓ ∞ ENDLESS ANTE %d" % ante, "✓ ∞ NEKONEČNÉ KOLO %d" % ante) if endless_mode_selected else _tr("∞ Epoch 6 (Ante %d)" % ante, "∞ Epocha 6 (Kolo %d)" % ante)
		else:
			endless_toggle_btn.disabled = true
			endless_toggle_btn.text = _tr("🔒 Epoch 6 Endless", "🔒 Epocha 6 Nekonečná")

	if campaign_diff_btn:
		var cur_diff := str(run_profile.get("campaign_difficulty", "traveler"))
		if cur_diff == "classic":
			campaign_diff_btn.text = _tr("⚔ Mode: Classic (Hardcore)  [Switch → Traveler]", "⚔ Režim: Klasický (Těžký)  [Přepnout]")
			campaign_diff_btn.add_theme_color_override("font_color", Color(1.0, 0.62, 0.52))
		else:
			campaign_diff_btn.text = _tr("🌿 Mode: Traveler (Easy)  [Switch → Classic]", "🌿 Režim: Poutník (Lehký)  [Přepnout]")
			campaign_diff_btn.add_theme_color_override("font_color", Color(0.58, 0.96, 0.72))

	var deck_cnt: int = 32 - int(run_profile.get("removed_cards", []).size()) + int(run_profile.get("added_cards", []).size()) + int(run_profile.get("custom_cards", []).size())
	var cur_d := str(run_profile.get("campaign_difficulty", "traveler"))
	var bless_c := int(run_profile.get("retry_blessing", 0))
	var bless_note := _tr("  •  🛡 Blessing ×%d (+%d)" % [bless_c, bless_c * 25], "  •  🛡 Požehnání ×%d (+%d)" % [bless_c, bless_c * 25]) if bless_c > 0 else ""
	var deck_name := _tr(str(PLAYER_DECKS[selected_deck_idx]["name"]), str(PLAYER_DECKS[selected_deck_idx].get("name_cs", PLAYER_DECKS[selected_deck_idx]["name"])))
	var era_name := _tr(str(era["name"]), str(era.get("name_cs", era["name"])))
	if endless_mode_selected and end_unlk:
		var ante := maxi(1, int(run_profile.get("endless_ante", 1)))
		var es := Catalog.get_endless_stage_data(ante, asc, lang_code)
		campaign_title_lbl.text = _tr("∞ EPOCH 6: ANTE %d (%s)" % [ante, era_name], "∞ EPOCHA 6: KOLO %d (%s)" % [ante, era_name])
		campaign_desc_lbl.text = _tr("Rival: %s   |   Goal: %d pts   |   +%dg\n✦ %s\nDeck: %s (%d • Asc. %d)", "Soupeř: %s   |   Cíl: %d b.   |   +%dg\n✦ %s\nBalíček: %s (%d • Vzest. %d)") % [
			str(es["stage_name"]),
			int(es["target_score"]),
			int(es["gold"]),
			str(es["boss_desc"]),
			deck_name,
			deck_cnt,
			asc,
		]
		campaign_play_btn.text = _tr("PLAY ∞ ANTE %d (%d pts)" % [ante, int(es["target_score"])], "HRÁT ∞ KOLO %d (%d b.)" % [ante, int(es["target_score"])])
	else:
		var goal_pts := Catalog.compute_target_score(e_id, st_idx, asc, 0, cur_d)
		var clr_star := " ★" if bool(run_profile.get("era_cleared", {}).get(e_id, false)) else ""
		var rival_name := _tr(str(st_data.get("stage_name", era["boss"])), str(st_data.get("stage_name_cs", era.get("boss_cs", era["boss"]))))
		var twist := _tr(str(st_data.get("boss_desc", "")), str(st_data.get("boss_desc_cs", st_data.get("boss_desc", ""))))
		var twist_line := ("✦ %s\n" % twist) if twist != "" else ""

		campaign_title_lbl.text = _tr("%s  —  Stage %d/3%s" % [era_name, st_idx + 1, clr_star], "%s  —  Zápas %d/3%s" % [era_name, st_idx + 1, clr_star])
		campaign_desc_lbl.text = _tr("Rival: %s   |   Goal: %d pts   |   +%dg\n%sDeck: %s (%d • Asc. %d)%s", "Soupeř: %s   |   Cíl: %d b.   |   +%dg\n%sBalíček: %s (%d • Vzest. %d)%s") % [
			rival_name,
			goal_pts,
			int(st_data.get("gold", 90)),
			twist_line,
			deck_name,
			deck_cnt,
			asc,
			bless_note,
		]
		campaign_play_btn.text = _tr("PLAY %d/3: %s" % [st_idx + 1, rival_name], "HRÁT %d/3: %s" % [st_idx + 1, rival_name])

func _find_era_at_screen_pos(mouse_pos: Vector2) -> int:
	var best_idx := -1
	var best_dist := 86.0
	for i in range(ERAS_DATA.size()):
		var base_pos: Vector3 = ERAS_DATA[i]["pos"]
		for h_off in [0.4, 2.0, 4.0]:
			var world_pt := base_pos + Vector3(0.0, h_off, 0.0)
			if cam_3d.is_position_behind(world_pt):
				continue
			var d := cam_3d.unproject_position(world_pt).distance_to(mouse_pos)
			if d < best_dist:
				best_dist = d
				best_idx = i
	return best_idx

func _apply_woodcut_mode(mode_idx: int, sync_battle: bool = true) -> void:
	woodcut_mode = posmod(mode_idx, 4)
	if map_woodcut_mat:
		map_woodcut_mat.set_shader_parameter("print_mode", woodcut_mode)
	if map_print_btn:
		var labels := (
			{0: "🎨 Dřevoryt", 1: "🎨 Sepie", 2: "🎨 Klasika", 3: "⚔ Liar's Bar"}
			if _is_cs() else
			{0: "🎨 Woodcut", 1: "🎨 Sepia Print", 2: "🎨 Classic", 3: "⚔ Liar's Bar"}
		)
		map_print_btn.text = str(labels.get(woodcut_mode, "⚔ Liar's Bar"))
	if sync_battle and battle_3d and battle_3d.has_method("set_print_mode"):
		battle_3d.set_print_mode(woodcut_mode)

func _refresh_map_ui_texts() -> void:
	if map_btn_back:
		map_btn_back.text = _tr("← Main Menu", "← Hlavní menu")
	if map_btn_guide:
		map_btn_guide.text = _tr("📜 Duel Laws", "📜 Pravidla")
	if map_btn_nav:
		map_btn_nav.text = _tr("🧭 Wayfinder", "🧭 Ovládání")
	if map_btn_shop:
		map_btn_shop.text = _tr("✦ Bazaar", "✦ Obchod")
	if map_print_btn:
		map_print_btn.tooltip_text = _tr("Cycle Visual Mode [F8]", "Přepnout vzhled [F8]")
		_apply_woodcut_mode(woodcut_mode, false)
	for el in era_label3d_nodes:
		var lbl3: Label3D = el.get("lbl")
		if is_instance_valid(lbl3):
			lbl3.text = _tr(str(el.get("en", "")), str(el.get("cs", "")))
	if map_guide_title:
		map_guide_title.text = _tr("DUEL LAWS — CARDS & COMBAT", "PRAVIDLA DUELU — PRŠÍ A SOUBOJ")
	if map_guide_body:
		map_guide_body.text = _get_map_guide_body_text()
		map_guide_body.visible_characters = -1
	if map_guide_next_btn:
		map_guide_next_btn.text = _tr("Controls & Nav →", "Ovládání →")
	if map_guide_ok_btn:
		map_guide_ok_btn.text = _tr("Let's Play!", "Hrajeme!")
	if map_nav_title:
		map_nav_title.text = _tr("WORLD & TAVERN NAVIGATION", "OVLÁDÁNÍ MAPY A STOLU")
	if map_nav_close_btn:
		map_nav_close_btn.text = _tr("Explore Map!", "Zpět na mapu!")
	for rw in map_nav_row_widgets:
		var d: Dictionary = rw.get("data", {})
		var b: Button = rw.get("badge")
		var lb: Label = rw.get("desc")
		if is_instance_valid(b):
			b.text = _tr(str(d.get("k_en", "")), str(d.get("k_cs", "")))
		if is_instance_valid(lb):
			lb.text = _tr(str(d.get("d_en", "")), str(d.get("d_cs", "")))
	if shop_reroll_btn:
		shop_reroll_btn.text = _tr("🎲 Reroll (15 🪙)", "🎲 Nová nabídka (15 🪙)")
	if shop_close_btn:
		shop_close_btn.text = _tr("✓ Return to Map", "✓ Zpět na mapu")
	if sculpt_cancel_btn:
		sculpt_cancel_btn.text = _tr("← Back to Shop", "← Zpět do obchodu")
	if sculpt_suit_bar:
		for ch in sculpt_suit_bar.get_children():
			if ch is Button and ch.has_meta("en_label"):
				ch.text = _tr(str(ch.get_meta("en_label")), str(ch.get_meta("cs_label")))
	if almanac_title_lbl:
		almanac_title_lbl.text = _tr("📖 LIALO GRIMOIRE", "📖 GRIMOÁR LIALO")
	for tb in almanac_tab_btns:
		if is_instance_valid(tb) and tb.has_meta("en_label"):
			tb.text = _tr(str(tb.get_meta("en_label")), str(tb.get_meta("cs_label")))
	if almanac_close_btn:
		almanac_close_btn.text = _tr("Close Codex", "Zavřít grimoár")
	if not shop_offers.is_empty():
		var any_bought := false
		for so in shop_offers:
			if bool(so.get("bought", false)):
				any_bought = true
				break
		if not any_bought:
			shop_offers = Catalog.generate_shop_offers(run_profile, str(game_options.get("language", "en")))
	_rebuild_shop_ui(false)
	_rebuild_almanac_ui()
	_refresh_map_roguelite_hud()
	_update_campaign_card(selected_era_idx)

func _unhandled_input(event: InputEvent) -> void:
	if current_screen == ScreenState.SPLASH:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			if not splash_skipped:
				splash_skipped = true
				get_viewport().set_input_as_handled()
				_switch_to(ScreenState.MAIN_MENU)
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and current_screen == ScreenState.WORLD_3D:
		_play_sfx("ui_click")
		_apply_woodcut_mode(woodcut_mode + 1, true)
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if collection_detail_modal and collection_detail_modal.visible:
			_close_animated_modal(collection_detail_modal)
			get_viewport().set_input_as_handled()
			return
		if options_3d and options_3d.is_open():
			options_3d.close_3d()
			get_viewport().set_input_as_handled()
			return
		if deck_modal and deck_modal.visible:
			_close_animated_modal(deck_modal)
			get_viewport().set_input_as_handled()
			return
		if almanac_modal and almanac_modal.visible:
			_close_animated_modal(almanac_modal)
			get_viewport().set_input_as_handled()
			return

	if current_screen == ScreenState.WORLD_3D:
		if (map_guide_modal and map_guide_modal.visible) or (map_nav_modal and map_nav_modal.visible) or (shop_modal and shop_modal.visible) or (almanac_modal and almanac_modal.visible):
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				_close_animated_modal(map_guide_modal)
				_close_animated_modal(map_nav_modal)
				_close_animated_modal(shop_modal)
				_close_animated_modal(almanac_modal)
			return
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				is_dragging_cam = event.pressed
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				cam_zoom = clampf(cam_zoom - 0.08, 0.65, 1.45)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				cam_zoom = clampf(cam_zoom + 0.08, 0.65, 1.45)
			elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				var hit_idx := _find_era_at_screen_pos(event.position)
				if hit_idx >= 0:
					_trigger_era_click_anim(hit_idx)
					if selected_era_idx == hit_idx:
						_launch_era_battle(hit_idx)
					else:
						selected_era_idx = hit_idx
						_update_campaign_card(hit_idx)
						var epos: Vector3 = ERAS_DATA[hit_idx]["pos"]
						cam_target_pos = Vector3(clampf(epos.x, -14.0, 14.0), 0.0, clampf(epos.z + 2.0, -12.0, 14.0))
		elif event is InputEventMouseMotion:
			if is_dragging_cam:
				cam_target_pos.x = clampf(cam_target_pos.x - event.relative.x * 0.045, -16.0, 16.0)
				cam_target_pos.z = clampf(cam_target_pos.z - event.relative.y * 0.045, -14.0, 16.0)
			else:
				hovered_era_idx = _find_era_at_screen_pos(event.position)
				if hovered_era_idx >= 0:
					_update_campaign_card(hovered_era_idx)
				else:
					_update_campaign_card(selected_era_idx)

func _play_menu_entrance(full_epic: bool = true) -> void:
	if full_epic:
		# Epické otvorenie Lobby z tmy: Prsknú & poskočia karty -> Vyjde Zlaté Slnko -> LIALO -> Priletia drevené tabule
		lobby_intro_active = true
		lobby_intro_time = 0.0
		lobby_intro_cards.clear()
		if lobby_fx_canvas:
			_spawn_lobby_intro_cards(lobby_fx_canvas.get_viewport_rect().size)
		if is_instance_valid(lobby_dark_veil):
			lobby_dark_veil.visible = true
			lobby_dark_veil.color.a = 0.96
		_play_sfx("card_deal", -6.5, 1.05)

		if is_instance_valid(title_logo_node):
			title_logo_node.modulate = Color(1.9, 1.75, 1.2, 0.0)
			title_logo_node.scale = Vector2(0.18, 0.18)
			var ltw := title_logo_node.create_tween().set_parallel(true)
			ltw.tween_property(title_logo_node, "modulate", Color.WHITE, 0.65).set_delay(1.32).set_trans(Tween.TRANS_CUBIC)
			ltw.tween_property(title_logo_node, "scale", Vector2(1.06, 1.06), 0.56).set_delay(1.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ltw.chain().tween_property(title_logo_node, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD)
		if is_instance_valid(title_tagline_node):
			title_tagline_node.modulate.a = 0.0
			var ttw := title_tagline_node.create_tween()
			ttw.tween_property(title_tagline_node, "modulate:a", 1.0, 0.48).set_delay(1.75).set_trans(Tween.TRANS_QUAD)

		var fly_dirs := [
			Vector2(-440.0, 60.0), Vector2(440.0, 60.0),
			Vector2(-380.0, 220.0), Vector2(0.0, 260.0), Vector2(380.0, 220.0),
		]
		for i in range(menu_sign_visuals.size()):
			var visual := menu_sign_visuals[i]
			if not is_instance_valid(visual):
				continue
			var off_start: Vector2 = fly_dirs[i % fly_dirs.size()]
			var dly := 2.02 + 0.11 * float(i)
			visual.modulate.a = 0.0
			visual.position = off_start
			visual.scale = Vector2(0.72, 0.72)
			visual.rotation_degrees = -12.0 if (off_start.x < 0.0) else (12.0 if off_start.x > 0.0 else 0.0)
			var tw := visual.create_tween().set_parallel(true)
			tw.tween_property(visual, "modulate:a", 1.0, 0.34).set_delay(dly)
			tw.tween_property(visual, "position", Vector2.ZERO, 0.54).set_delay(dly).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(visual, "scale", Vector2.ONE, 0.50).set_delay(dly).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(visual, "rotation_degrees", 0.0, 0.46).set_delay(dly).set_trans(Tween.TRANS_QUAD)
		return

	# Rýchly plynulý návrat z mapy / duelu
	lobby_intro_active = false
	if is_instance_valid(lobby_dark_veil):
		lobby_dark_veil.visible = false
	if is_instance_valid(lobby_sun_canvas):
		lobby_sun_canvas.queue_redraw()
	if title_logo_node:
		title_logo_node.modulate = Color(1, 1, 1, 0)
		var tw := title_logo_node.create_tween()
		tw.tween_property(title_logo_node, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_CUBIC)
	if is_instance_valid(title_tagline_node):
		title_tagline_node.modulate.a = 1.0
	for i in range(menu_sign_visuals.size()):
		var visual := menu_sign_visuals[i]
		if not is_instance_valid(visual):
			continue
		visual.modulate.a = 0.0
		visual.position = Vector2.ZERO
		visual.scale = Vector2(0.84, 0.84)
		var tw := visual.create_tween().set_parallel(true)
		tw.tween_property(visual, "modulate:a", 1.0, 0.34).set_delay(0.06 * float(i))
		tw.tween_property(visual, "scale", Vector2.ONE, 0.38).set_delay(0.06 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if DisplayServer.get_name() != "headless" and not ("--script" in OS.get_cmdline_args()):
		var win := get_window()
		if win and win.has_focus() != window_focused:
			_on_window_focus_changed(win.has_focus())
	var t := Time.get_ticks_msec() * 0.001

	if current_screen == ScreenState.SPLASH:
		splash_time += delta
		_update_splash_3d()
		if splash_time >= 5.3 and not splash_skipped:
			splash_skipped = true
			_switch_to(ScreenState.MAIN_MENU)

	elif current_screen == ScreenState.MAIN_MENU:
		_update_lobby_card_animations(delta)
		if is_instance_valid(lobby_sun_canvas):
			lobby_sun_canvas.queue_redraw()
		if is_instance_valid(logo_aura_canvas):
			logo_aura_canvas.queue_redraw()
		if is_instance_valid(title_logo_node) and (not lobby_intro_active or lobby_intro_time >= 2.25):
			var bob := sin(t * 1.55) * 6.0
			title_logo_node.rotation_degrees = sin(t * 0.85) * 1.35
			var sc := 1.0 + sin(t * 1.9) * 0.025
			title_logo_node.scale = Vector2(sc, sc)
			var lt := title_logo_node.get_node_or_null("LogoTitle") as Control
			var ls := title_logo_node.get_node_or_null("LogoShadow") as Control
			if lt:
				lt.position = Vector2(0.0, bob)
				lt.self_modulate = Color(1.0 + sin(t * 2.2) * 0.05, 1.0 + sin(t * 2.2) * 0.04, 1.0)
			if ls:
				ls.position = Vector2(5.0, 10.0 + bob * 0.4)
		if not lobby_intro_active or lobby_intro_time >= 3.05:
			for visual in menu_sign_visuals:
				if not is_instance_valid(visual) or visual.get_meta("hovered", false):
					continue
				var phase: float = visual.get_meta("phase", 0.0)
				var target_rot := sin(t * 1.35 + phase) * 1.1 + cos(t * 0.70 + phase) * 0.35
				visual.rotation_degrees = lerpf(visual.rotation_degrees, target_rot, 5.0 * delta)

	elif current_screen == ScreenState.MATCH_3D:
		if music_enabled:
			_update_battle_music_mix(delta)
	elif current_screen == ScreenState.WORLD_3D:
		if map_open_active:
			map_open_time += delta
			if map_open_time >= 1.65:
				map_open_active = false
		var dir := Vector3.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.z -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.z += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1.0
		if dir != Vector3.ZERO:
			cam_target_pos += dir.normalized() * 16.0 * delta
			cam_target_pos.x = clampf(cam_target_pos.x, -16.0, 16.0)
			cam_target_pos.z = clampf(cam_target_pos.z, -14.0, 16.0)

		cam_pivot.position = cam_pivot.position.lerp(cam_target_pos, 9.0 * delta)
		cam_3d.position = cam_3d.position.lerp(Vector3(0.0, 21.0 * cam_zoom, 12.5 * cam_zoom), 8.0 * delta)

		if compass_needle_ctrl:
			var pan_bias := cam_pivot.position.x * 1.8 - cam_pivot.position.z * 1.2
			var spin_left := (1.0 - ease(clampf((map_open_time - 0.12) / 0.72, 0.0, 1.0), 0.35)) if map_open_active else 0.0
			compass_needle_ctrl.rotation_degrees = pan_bias + sin(t * 0.9) * 28.0 + sin(t * 2.4) * 6.0 - spin_left * 340.0
		for i in range(era_medallions.size()):
			var med := era_medallions[i]
			if is_instance_valid(med):
				var by: float = med.get_meta("base_y", 4.05)
				var boost := 0.50 if (i == hovered_era_idx or i == selected_era_idx) else 0.0
				var med_swoop := (1.0 - ease(clampf((map_open_time - (0.14 + float(i) * 0.075)) / 0.45, 0.0, 1.0), 0.35)) if map_open_active else 0.0
				med.position.y = by + boost + med_swoop * 3.4 + sin(t * 2.1 + float(i) * 1.1) * 0.22
		for i in range(era_beacon_lights.size()):
			var bl := era_beacon_lights[i]
			if is_instance_valid(bl):
				if not map_open_active or map_open_time >= 0.75:
					var active_hi := (i == hovered_era_idx or i == selected_era_idx)
					var base_e := 1.35 if active_hi else 0.65
					bl.light_energy = base_e + sin(t * 4.4 + float(i) * 1.9) * 0.16 + cos(t * 7.8 + float(i)) * 0.08
		for ms in map_mist_sheets:
			var sn: MeshInstance3D = ms.get("node")
			if is_instance_valid(sn):
				var mbp: Vector3 = ms.get("base", Vector3.ZERO)
				var mph: float = float(ms.get("phase", 0.0))
				var mspd: float = float(ms.get("spd", 0.2))
				sn.position = mbp + Vector3(sin(t * mspd + mph) * 1.35, sin(t * 0.6 + mph) * 0.08, cos(t * mspd * 0.8 + mph) * 0.95)
		if is_instance_valid(book_folio_fx):
			book_folio_fx.queue_redraw()
		for tree in map_tree_nodes:
			if is_instance_valid(tree):
				var tp: float = tree.get_meta("sway_phase", 0.0)
				tree.rotation_degrees.z = sin(t * 1.7 + tp) * 2.2
		for cld in map_cloud_nodes:
			if is_instance_valid(cld):
				var bp: Vector3 = cld.get_meta("base_pos", Vector3.ZERO)
				var cph: float = cld.get_meta("phase", 0.0)
				var cspd: float = cld.get_meta("drift_spd", 0.4)
				cld.position = bp + Vector3(sin(t * 0.22 * cspd + cph) * 1.6, cos(t * 0.45 + cph) * 0.22, sin(t * 0.18 + cph) * 1.1)

		# Animácia prúdiacej vody v rieke (pod mostami mizne, v prúde sa trbliece!)
		for rp in map_river_ripples:
			var r_node: MeshInstance3D = rp.get("node")
			if not is_instance_valid(r_node):
				continue
			var v := fmod(float(rp["v"]) + float(rp["spd"]) * delta, 0.98)
			if v < 0.02:
				v = 0.02
			rp["v"] = v
			var under_bridge := (v > 0.23 and v < 0.305) or (v > 0.65 and v < 0.725)
			r_node.visible = not under_bridge
			if under_bridge:
				continue
			var p0 := _river_point(v)
			var p1 := _river_point(minf(0.99, v + 0.02))
			var tangent := (p1 - p0).normalized()
			var normal := Vector3(-tangent.z, 0.0, tangent.x)
			var sway := sin(t * 2.2 + float(rp["phase"])) * 0.12
			r_node.position = p0 + normal * (float(rp["lane"]) * 0.44 + sway)
			r_node.rotation.y = atan2(tangent.x, tangent.z)
			var bs: Vector3 = rp.get("base_scale", Vector3.ONE)
			var pulse := 0.82 + 0.26 * sin(t * 3.4 + float(rp["phase"]))
			r_node.scale = Vector3(bs.x * pulse, bs.y, bs.z * (0.9 + 0.2 * pulse))

		# Pasúce a pobehujúce ovečky na lúkach mapy
		for sh in map_sheep_actors:
			var sn: Node3D = sh.get("node")
			var hd: Node3D = sh.get("head")
			var lgs: Array = sh.get("legs", [])
			if not is_instance_valid(sn):
				continue
			var sph := t * float(sh["spd"]) + float(sh["phase"])
			var graze_cyc := sin(sph * 0.45)
			var move_t := sph if graze_cyc > -0.25 else (sph - 0.1)
			var rad: float = float(sh["radius"])
			var home: Vector3 = sh["home"]
			var nx := home.x + cos(sph) * rad
			var nz := home.z + sin(sph * 0.85) * rad * 0.75
			var dx := -sin(sph) * rad
			var dz := cos(sph * 0.85) * rad * 0.75 * 0.85
			var trotting := graze_cyc > -0.15
			sn.position = Vector3(nx, absf(sin(t * 7.5 + float(sh["phase"]))) * (0.045 if trotting else 0.0), nz)
			if Vector2(dx, dz).length() > 0.01:
				sn.rotation.y = atan2(dx, dz)
			if is_instance_valid(hd):
				hd.rotation_degrees.x = 34.0 if not trotting else sin(t * 4.0) * 5.0
			for li in range(lgs.size()):
				var lg: MeshInstance3D = lgs[li]
				if is_instance_valid(lg):
					var sgn := 1.0 if (li % 2 == 0) else -1.0
					lg.rotation_degrees.x = sin(t * 9.0 + float(sh["phase"])) * 24.0 * sgn if trotting else 0.0
