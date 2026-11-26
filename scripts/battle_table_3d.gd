extends Node3D
class_name BattleTable3D
## Skutočná 3D hracia plocha v štýle Liar's Bar / Inscryption:
## - Hráč sedí za 3D stolom v temnej miestnosti s bodovým svetlom nad stolom.
## - Oproti v tme vidno iba jemný čierny obrys v hmle a osvetlené 3D rukavice súpera s 3D kartami.
## - Hráč drží vlastné 3D karty v priestore pred sebou (žiadne ploché 2D UI!).
## - Kamera sa jemne natáča podľa polohy myši (pohľad na vlastné 3D karty <-> 3D stôl <-> ruky súpera v tme).
## - Kliknutím na 3D kartu v ruke karta reálne preletí v 3D priestore a dopadne na odhadzovaciu kopu na stole!

signal exit_to_map_requested
signal battle_won(new_points: int)
signal match_won_details(details: Dictionary)
signal match_lost_details(details: Dictionary)
signal play_sfx_requested(sfx_name: String)
signal play_sfx_pitched_requested(sfx_name: String, pitch_val: float)
signal toggle_mute_requested
signal volume_changed_requested(new_pct: int)
signal print_mode_changed(new_mode: int)
signal open_options_requested

const Toon = preload("res://scripts/toon_style.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")
const BankaiFxScript = preload("res://scripts/battle/bankai_fx.gd")
const ScoreEng = preload("res://scripts/scoring_engine.gd")
const CamSpring = preload("res://scripts/camera_recoil_spring.gd")
const Fx = preload("res://scripts/fx_lib.gd")
const SwordCardAnim = preload("res://scripts/sword_card_animator.gd")
const BlenderVfx = preload("res://scripts/blender_vfx_animator.gd")
const RelicMesh = preload("res://scripts/relic_mesh_factory.gd")
const HeartbeatHpScript := preload("res://scripts/heartbeat_hp_display.gd")
const CinematicDirectorScript := preload("res://scripts/cinematic_director.gd")
const HandwritingQuillScript := preload("res://scripts/handwriting_quill.gd")
const TableRelicMgrScript := preload("res://scripts/battle/table_relic_manager.gd")
const CombatLogDrawerScript := preload("res://scripts/battle/combat_log_drawer.gd")
const LialoIcons := preload("res://scripts/ui/lialo_icons.gd")
const RelicInspect3D := preload("res://scripts/ui/relic_inspect_3d.gd")
const PowerCardShowcase := preload("res://scripts/battle/power_card_vfx_showcase.gd")
const StoryData := preload("res://scripts/campaign/campaign_story_data.gd")
const ComicPlayerScript := preload("res://scripts/ui/comic_cutscene_player.gd")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const CARD_FX_SHADER := preload("res://shaders/card_fx.gdshader")
const SCREEN_JUICE_SHADER := preload("res://shaders/screen_juice.gdshader")
const TABLE_INLAY_SHADER := preload("res://shaders/table_cloth.gdshader")
const COMBO_FLAME_SHADER := preload("res://shaders/combo_flame.gdshader")
const BOSS_SILHOUETTE_SHADER := preload("res://shaders/boss_silhouette.gdshader")
const WOODCUT_POST_SHADER := preload("res://shaders/woodcut_post.gdshader")
const CHALICE_FIRE_SHADER := preload("res://shaders/chalice_fire.gdshader")
const CHALICE_VESSEL_SHADER := preload("res://shaders/chalice_vessel.gdshader")
const FONT_DISPLAY_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_UI_PATH := "res://assets/fonts/LialoBody.ttf"
const FONT_QUILL_PATH := "res://assets/fonts/LialoQuill.ttf"
var _cached_quill_font: Font = null

# --- Gameplay graphics overhaul state ---
const SUIT_ASTRO_ANGLES := {"CERVEN": 0.0, "ZALUD": PI * 0.5, "ZELEN": PI, "GULA": PI * 1.5}
var gfx_env: Environment
var gfx_base_ambient_energy: float = 0.72
var gfx_base_spot_energy: float = 1.65
var suit_pulse_age: float = 10.0
var gfx_last_suit_id: String = ""
var astrolabe_root: Node3D
var astrolabe_ring_outer: Node3D
var astrolabe_ring_inner: Node3D
var astrolabe_glow_mat: StandardMaterial3D
var astrolabe_yaw: float = 0.0
var overdrive_light_t: float = 0.0
var overdrive_light_target: float = 0.0
var dramatic_lighting_dim: float = 0.0
var dramatic_lighting_tint: Color = Color(0.85, 0.16, 0.18)
var _active_blender_vfx_nodes: Array[Node3D] = []
var _active_astrolabe_stage: Node3D = null
var cam_roll_kick: float = 0.0
var cam_prev_roll_kick: float = 0.0
var hud_frame_overlays: Array[Control] = []

# --- High-Stakes Wager ("GOLD", "ITEM", "SWORD") & Tutorial Ghost Guide ---
var active_wager_type: String = "GOLD"
var wager_gold_amount: int = 25
var player_available_gold: int = 100
var wager_bar_panel: PanelContainer
var wager_indicator_pill: PanelContainer
var wager_indicator_lbl: Label
var veto_standalone_panel: PanelContainer
var wager_gold_btn: Button
var wager_item_btn: Button
var wager_sword_btn: Button
var wager_veto_hand_btn: Button
var wager_veto_duel_btn: Button
var _ui_blender_tex_cache: Dictionary = {}
var wager_indicator_icon: TextureRect
var carry_out_coin_icon: TextureRect
var status_coin_icon: TextureRect
var status_coins_lbl: Label
var opening_veto_used: bool = false
var wager_3d_ring: MeshInstance3D
var player_hp_heart: Control
var rival_hp_heart: Control
var cinematic_director: Node = null
var _cinematic_seq_token: int = 0
var tutorial_ghost_3d: Node3D
var tutorial_ghost_mat: StandardMaterial3D
var tutorial_ghost_accent: Color = Color(0.42, 0.96, 0.72)
var tutorial_ghost_mouth: MeshInstance3D
var tutorial_ghost_skull_root: Node3D
var tutorial_ghost_jaw_root: Node3D
var tutorial_ghost_eye_left: Node3D
var tutorial_ghost_eye_right: Node3D
var tutorial_ghost_pupil_left: MeshInstance3D
var tutorial_ghost_pupil_right: MeshInstance3D
var tutorial_ghost_arm: Node3D
var tutorial_ghost_arm_left: Node3D
var tutorial_ghost_tendrils: Array[Node3D] = []
var tutorial_ghost_wisps: Array[MeshInstance3D] = []
var tutorial_ghost_light: OmniLight3D
var tutorial_ghost_speech_3d: Label3D
var tutorial_ghost_speech_lbl: Label
var ghost_speech_full: String = ""
var ghost_speech_chars: float = 0.0
var ghost_voice_cd: float = 0.0

const DEFAULT_MAX_HP := 10
var player_hp: int = DEFAULT_MAX_HP
var player_max_hp: int = DEFAULT_MAX_HP
var ai_hp: int = DEFAULT_MAX_HP
var ai_max_hp: int = DEFAULT_MAX_HP
var player_hp_lbl: Label
var ai_hp_lbl: Label
var carry_out_score_lbl: Label

const SUITS = [
	{"id": "CERVEN", "name": "Hearts", "name_cs": "Srdce",  "sym": "♥", "col": Color(0.88, 0.20, 0.24)},
	{"id": "ZELEN",  "name": "Leaves", "name_cs": "Listí",  "sym": "♠", "col": Color(0.18, 0.65, 0.48)},
	{"id": "ZALUD",  "name": "Acorns", "name_cs": "Žaludy", "sym": "♣", "col": Color(0.84, 0.64, 0.38)},
	{"id": "GULA",   "name": "Bells",  "name_cs": "Koule",  "sym": "●", "col": Color(0.95, 0.56, 0.24)}
]

const RANKS = [
	{"id": "7",  "name": "Seven",     "name_cs": "Sedma",    "pts": 7},
	{"id": "8",  "name": "Eight (∞)", "name_cs": "Osma (∞)", "pts": 8},
	{"id": "9",  "name": "Nine",      "name_cs": "Devítka",  "pts": 9},
	{"id": "10", "name": "Ten",       "name_cs": "Desítka",  "pts": 10},
	{"id": "D",  "name": "Jack",      "name_cs": "Spodek",   "pts": 12},
	{"id": "H",  "name": "Queen",     "name_cs": "Svršek",   "pts": 16},
	{"id": "K",  "name": "King",      "name_cs": "Král",     "pts": 18},
	{"id": "E",  "name": "Ace",       "name_cs": "Eso",      "pts": 20}
]

const MAX_MATCH_ROUNDS := 6

enum CameraViewMode { CARDS, TABLE_ITEMS, CINEMATIC, RIVAL_ITEMS }
enum TurnStage { ITEM_REVIEW, CARD_PLAY, RESOLVING }
var cam_view_mode: CameraViewMode = CameraViewMode.CARDS
var turn_stage: TurnStage = TurnStage.ITEM_REVIEW
var _pre_cinematic_view_mode: CameraViewMode = CameraViewMode.CARDS
var view_toggle_btn: Button
var item_review_bar: PanelContainer
var item_review_lbl: Label
var item_review_continue_btn: Button
var item_review_light: OmniLight3D
var draw_deck_beacon: MeshInstance3D
var opp_table_items_root: Node3D
var opp_phial_node: Node3D
var opp_relic_node: Node3D
var opp_item_charges: int = 1
var tutorial_ghost_quill: Control

var cam: Camera3D
var base_cam_rot := Vector3(-25.0, 0.0, 0.0)
var cards_tucked: bool = true
var auto_edge_peek: bool = false
var turn_glance_timer: float = 0.0
var turn_glance_duration: float = 1.45
var opts_language: String = "en"
var opts_high_fx: bool = true
var opts_cam_sens: float = 1.0
var opts_game_pace: String = "relaxed"
var _shop_gate_tween: Tween
var hovered_prop_id: String = ""
var tavern_bell_root: Node3D
var chandelier_cone_mesh: MeshInstance3D
var hud_shop_btn: Button
var prop_hover_pill: PanelContainer
var prop_hover_title: Label
var prop_hover_desc: Label
var tutorial_ghost_center_panel: PanelContainer
var tutorial_ghost_center_lbl: Label
var tutorial_continue_btn: Button
var tutorial_substep: int = 0
var _hw_targets: Dictionary = {}
var tutorial_ghost_ok_flash: float = 0.0
var wheel_canvas: Control
var wheel_lap_lbl: Label
var round_counter_lbl: Label
var round_transition_overlay: Control
var round_transition_ribbon: PanelContainer
var round_transition_sub_lbl: Label
var round_transition_main_lbl: Label
var round_transition_pips_lbl: Label
var round_transition_tween: Tween
var settings_icon_btn: Button
var card_guide_btn: Button
var relic_inspect_modal: RelicInspect3D = null
var card_guide_modal: Control
var card_guide_title_lbl: Label
var card_guide_scroll_vb: VBoxContainer
var shop_gate_overlay: Control
var shop_gate_title: Label
var shop_gate_sub: Label
var shop_gate_yes_btn: Button
var shop_gate_no_btn: Button
var shop_gate_open: bool = false
var current_round_num: int = 1
var bottom_left_status_pill: PanelContainer
var bottom_left_status_lbl: Label
var pending_seven_banner_pill: PanelContainer
var pending_seven_banner_lbl: Label
var victory_summary_overlay: Control
var victory_crown_ctrl: Control
var victory_title_lbl: Label
var victory_stats_lbl: Label
var victory_continue_btn: Button
var defeat_summary_overlay: Control
var defeat_title_lbl: Label
var defeat_stats_lbl: Label
var defeat_continue_btn: Button
var peddler_ghost_ctrl: Control
var peddler_ghost_lbl: Label
var peddler_3d_roots: Array[Node3D] = []
var purchased_table_items_root: Node3D
var purchased_table_item_nodes: Array[Node3D] = []
var checkpoint_state: Dictionary = {}
var match_best_move_desc: String = "Single Play"
var match_optimal_possible_slam: int = 20
var match_optimal_move_desc: String = "Optimal Play"
var score_popup_side_toggle: bool = false
var opp_play_anim_t: float = 0.0
var opp_torso_node: Node3D
var opp_head_node: Node3D
var opp_arm_right_node: Node3D
var opp_arm_left_node: Node3D
var opp_eye_nodes: Array[MeshInstance3D] = []
var opp_blink_timer: float = 2.6
var glove_lunge_boost: float = 0.0
var wager_showcase_boost: float = 0.0
var key_hint_lbl: Label

# Celé 3D karty v ruke jasne čitateľné nad stolom + [SPACE] náhľad (~12% horný okraj dole)
const HAND_POS_UP := Vector3(0.0, 1.24, 1.00)
const HAND_ROT_UP := Vector3(-24.0, 0.0, 0.0)
const HAND_POS_TUCKED := Vector3(0.0, 0.72, 1.48)
const HAND_ROT_TUCKED := Vector3(-54.0, 0.0, 0.0)

var rmb_down: bool = false
var rmb_drag_dist: float = 0.0
var rmb_press_card_idx: int = -1
var freelook_yaw: float = 0.0
var freelook_pitch: float = 0.0
var cam_look_yaw: float = 0.0
var cam_look_pitch: float = 0.0
var _cursor_look_pos := Vector2(-1.0, -1.0)

var intro_animating: bool = false
var intro_seq_tween: Tween
var cam_kick_shake: float = 0.0
var cam_impact_active: bool = false
var cam_spring := CamSpring.new()
var cam_prev_pitch_kick: float = 0.0
var cam_prev_fov_kick: float = 0.0
var prev_hovered_idx: int = -1
var exterior_vista_root: Node3D
var exterior_vista_theme: String = "full_moon"
var exterior_twinkle_nodes: Array[MeshInstance3D] = []
var exterior_pine_nodes: Array[Node3D] = []
var exterior_lightning_meshes: Array[MeshInstance3D] = []

var tavern_chandelier: Node3D
var hearth_fire_light: OmniLight3D
var storm_rain_meshes: Array[MeshInstance3D] = []
var storm_window_lights: Array[Light3D] = []
var lantern_lights: Array[OmniLight3D] = []
var dust_motes_root: Node3D
var table_spot_light: SpotLight3D
var player_hand_light: OmniLight3D
var boss_rim_light: SpotLight3D
var opp_silhouette_root: Node3D
var opp_ambient_fx_root: Node3D
var dark_silhouette_mat: ShaderMaterial
var table_felt_mat: ShaderMaterial
var table_pulse_strength: float = 0.0
var table_peek_ring: MeshInstance3D
var table_peek_mat: StandardMaterial3D
var turn_banner_grp: Control
var turn_ornament_ctrl: Control
var turn_banner_lbl: Label
var turn_banner_sub_lbl: Label
var turn_timer_pill: PanelContainer
var turn_timer_lbl: Label
var turn_timer_bar: ColorRect
var bankai_fx: BankaiFxScript
var bankai_seal_pill: PanelContainer
var bankai_seal_lbl: Label
var bankai_build_id: String = "GUILLOTINE_ACES"
var bankai_combo: Array = ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]
var bankai_charged: Array = []
var bankai_active: bool = false
var opts_turn_timer_sec: float = 35.0
var player_turn_timer: float = 35.0
var _turn_timer_was_active: bool = false
var _turn_timer_last_tick_sec: int = -1
var turn_banner_accent := Color(0.45, 0.94, 0.62)
var turn_toast_tween: Tween
var _last_turn_toast_key: String = ""
var hint_lbl: Label
var peek_hud_bar: PanelContainer
var peek_hud_lbl: Label
var stagger_callout_pill: PanelContainer
var stagger_callout_lbl: Label
var stagger_callout_tween: Tween
var stagger_callout_ttl: float = 0.0
var stagger_eq_row: HBoxContainer
var stagger_eq_chips_lbl: Label
var stagger_eq_mult_lbl: Label
var stagger_eq_xmult_lbl: Label
var stagger_eq_total_lbl: Label
var stagger_step_progress_lbl: Label
var _stagger_seq_token: int = 0
var _ai_turn_seq: int = 0
var _battle_session_token: int = 0
var _active_popup_lbl: Control = null
var _last_peek_state: bool = false

var player_deck_data: Dictionary = {}
var tutorial_mode: bool = false
var tutorial_step: int = 0
var tutorial_turns_left: int = 3
var tutorial_step_badge_pill: PanelContainer
var tutorial_step_badge_lbl: Label
var tutorial_task_pill: PanelContainer
var tutorial_task_lbl: Label
var tutorial_arrow_overlay: Control
var unlock_tip_panel: PanelContainer
var unlock_tip_title_lbl: Label
var unlock_tip_body_lbl: Label
var unlock_tip_btn: Button
var _active_unlock_tip_id: String = ""
var _unlock_tip_queue: Array[Dictionary] = []
var active_run_profile: Dictionary = {}
var cards_points_revealed: bool = true
var abilities_revealed: bool = true
var hud_score_revealed: bool = true
var hud_combo_revealed: bool = true
var puf_revealed: bool = true

var opp_shake_time: float = 0.0
var player_glove_action_offset := Vector3.ZERO

# Frameless Calligraphic HUD + Liquid Arcane Meters + Mystical Tutorial Overlay
var player_hud_grp: Control
var player_liquid_bar: Control
var player_score_lbl: Label
var player_puf_lbl: Label
var charge_tier_textures: Array[Texture2D] = []
var score_chalice_art: TextureRect
var score_chalice_next: TextureRect
var chalice_back_fire_rect: ColorRect
var chalice_front_fire_rect: ColorRect
var chalice_back_fire_mat: ShaderMaterial
var chalice_front_fire_mat: ShaderMaterial
var chalice_vessel_mat: ShaderMaterial
var chalice_flame_progress: float = 0.0
var chalice_flame_surge: float = 0.0
var score_chalice_tier_lbl: Label
var score_chalice_pct_lbl: Label
var score_goal_bar_ctrl: Control
var score_ledger_panel: PanelContainer
var score_ledger_state_lbl: Label
var score_ledger_eq_lbl: Label
var score_fx_overlay: Control
var score_resolve_light: OmniLight3D

var pending_player_exchange_pts: int = 0
var pending_player_exchange_notes: Array[String] = []
var pending_player_exchange_col: Color = Color(1.0, 0.88, 0.34)
var pending_player_best_slam: int = 0
var pending_player_best_desc: String = ""
var pending_ai_exchange_pts: int = 0
var pending_ai_exchange_notes: Array[String] = []
var _score_resolve_token: int = 0
var score_resolving_active: bool = false
var last_charge_tier_idx: int = 0
var last_settled_eq_str: String = ""
var score_sheen_phase: float = -1.0
var score_ledger_glow: float = 0.0
var _score_fx_orbs: Array[Dictionary] = []
var _score_fx_bolts: Array[Dictionary] = []
var _score_fx_embers: Array[Dictionary] = []
var _score_fx_rings: Array[Dictionary] = []
var _score_fx_beams_alpha: float = 0.0
var _score_fx_active_time: float = 0.0

var rival_hud_grp: Control
var ai_liquid_bar: Control
var ai_score_lbl: Label
var ai_cards_lbl: Label
var ai_pending_lbl: Label
var battle_audio_drawer_open: bool = false
var battle_audio_muted: bool = false
var battle_audio_pct: int = 85
var battle_audio_toggle_btn: Button
var battle_audio_drawer: Control
var battle_mute_btn: Button
var battle_vol_slider: HSlider
var battle_vol_pct_lbl: Label
var intro_title_grp: Control
var intro_title_lbl: Label

var combo_hud_grp: Control
var combo_glow_active: bool = false
var combo_title_lbl: Label
var chips_lbl: Label
var mult_lbl: Label
var flat_mult_lbl: Label
var xmult_lbl: Label
var total_calc_lbl: Label
var stack_action_bar: HBoxContainer
var stack_action_btn: Button
var stack_clear_btn: Button

var tutorial_callout_grp: Control
var tutorial_chapter_lbl: Label
var tutorial_title_lbl: Label
var tutorial_body_lbl: Label
var tutorial_skip_btn: Button
var hud_fx_layer: Control
var tutorial_beacon_mesh: MeshInstance3D

# Balatro Roguelite Deckbuilder State & Redesigned Visual FX Nodes
var run_custom_cards: Array = []
var run_active_relics: Array = []
var run_card_editions: Dictionary = {}
var run_removed_cards: Array = []
var run_added_cards: Array = []
var run_suit_overrides: Dictionary = {}
var run_relic_scales: Dictionary = {}
var match_relic_scales: Dictionary = {}
var run_shop_rerolls: int = 0
var active_endless_ante: int = 0
var active_stage_data: Dictionary = {}
var active_boss_mod: String = ""
var active_boss_desc: String = ""
var redraws_left: int = 2
var player_shields: int = 0
var player_knight_shield_charge: int = 0
var ai_shields: int = 0
var boss_phase: int = 1
var sealed_suit_id: String = ""
var sealed_suit_turns: int = 0
var shifting_winds_active: bool = false
var stamped_card_key: String = ""
var _mid_comic_layer: CanvasLayer = null
var rival_cards_revealed_turns: int = 0
var aces_played: int = 0
var extra_player_turn: bool = false
var deferred_ai_draw: int = 0
var deferred_ai_skip: bool = false
var storm_surge_mult: float = 0.0
var match_bonus_gold: int = 0
var match_best_slam: int = 0
var match_turn_count: int = 0
var duel_chalice_mult: float = 0.0
var duel_whetstone_stacks: int = 0
var duel_next_xmult: float = 1.0
var duel_sword_bonus_gold: int = 0
var duel_gold_delta: int = 0
var active_campaign_difficulty: String = "traveler"
var active_retry_blessing: int = 0
var last_player_play_suit: String = ""
var last_player_play_rank: String = ""
var dock_backdrop_panel: PanelContainer
var quick_action_bar: HBoxContainer
var quick_play_btn: Button
var quick_peek_btn: Button
var peddler_offers: Array[Dictionary] = []
var peddler_open: bool = false
var peddler_modal: PanelContainer
var peddler_title_lbl: Label
var peddler_sub_lbl: Label
var peddler_gold_lbl: Label
var peddler_cards_hbox: HBoxContainer
var peddler_reroll_btn: Button
var pending_seven_trap_bonus: int = 0
var pending_ai_seven_trap_bonus: int = 0
var pending_ace_stun_bonus: int = 0
var pending_skip_turns: int = 0
var pending_king_challenge: Dictionary = {}
var rival_burn_turns: int = 0
var rival_poison_turns: int = 0
var rival_tax_debuff: bool = false
var rival_shatter_debuff: bool = false
var player_poison_turns: int = 0
var player_tax_debuff: bool = false
var player_shatter_debuff: bool = false
var knight_mist_active: bool = false
var knight_mist_hidden_card: Dictionary = {}
var knight_mist_from_ai: bool = false
var mist_guess_modal: PanelContainer
var mist_guess_title_lbl: Label
var mist_guess_sub_lbl: Label
var mist_guess_options_box: HBoxContainer
var mist_guess_options: Array[Dictionary] = []
var mist_guess_open: bool = false
var thief_heist_modal: PanelContainer
var thief_heist_title_lbl: Label
var thief_heist_cls_lbl: Label
var thief_heist_rank_lbl: Label
var thief_heist_skip_btn: Button
var thief_heist_class_btns: Array[Dictionary] = []
var thief_heist_rank_btns: Array[Dictionary] = []
var thief_heist_class_box: HBoxContainer
var thief_heist_rank_box: GridContainer
var thief_heist_hint_lbl: Label
var thief_heist_open: bool = false
var peddler_close_btn: Button
var sort_hand_btns: Array[Dictionary] = []
var player_hp_pill: PanelContainer
var carry_out_pill: PanelContainer
var opening_turn_committed: bool = false
var suit_modal_title_lbl: Label
var suit_modal_btn_lbls: Dictionary = {}
var opp_fire_fx_root: Node3D
var opp_fire_light: OmniLight3D
var discard_mist_fx_root: Node3D
var _scored_display_nodes: Array[Node3D] = []
var popup_lane_idx: int = 0
var popup_last_msec: int = 0

var table_arcane_outer: MeshInstance3D
var table_arcane_inner: MeshInstance3D
var table_arcane_mat: StandardMaterial3D
var table_arcane_spin_boost: float = 0.0
var table_relic_rack_root: Node3D
var relic_3d_nodes: Dictionary = {}
var invoked_table_relics: Dictionary = {}
const MAX_TABLE_ITEM_USES: int = TableRelicMgrScript.MAX_TABLE_ITEM_USES
var relic_mgr: TableRelicMgrScript = TableRelicMgrScript.new()
var combat_log_drawer: CombatLogDrawerScript = null
var active_player_count: int = 2
var run_table_relics: Array = []
var table_relic_blood_seal_active: bool = false
var table_relic_hollow_mask_active: bool = false
var turn_score_history: Array[int] = []
var score_breakdown_row: HBoxContainer
var score_delta_lbl: Label
var score_history_lbl: Label
var last_breakdown_chips: Array = []
var table_pot_chips_root: Node3D

var screen_juice_rect: ColorRect
var screen_juice_mat: ShaderMaterial
var screen_juice_tween: Tween
var woodcut_layer: CanvasLayer
var woodcut_post_rect: ColorRect
var woodcut_post_mat: ShaderMaterial
var woodcut_print_mode: int = 3 # 0 = Living Woodcut, 1 = Broadsheet Sepia, 2 = Classic Toon, 3 = Liar's Bar PBR
var boss_rule_lbl: Label
var relic_bar_hbox: HBoxContainer
var relic_badge_nodes: Dictionary = {}
var hover_inspect_panel: PanelContainer
var hover_inspect_title: Label
var hover_inspect_sub: Label
var hover_inspect_desc: Label
var redraw_action_btn: Button

var display_player_score: float = 0.0
var display_ai_score: float = 0.0
var score_tick_cd: float = 0.0
var staged_card_indices: Array[int] = []
var pending_play_indices: Array[int] = []

# 3D Uzly na stole a v rukách + hráčove telo + duelistické meče
var player_hand_anchor: Node3D
var player_body_root: Node3D
var player_arm_left: Node3D
var player_arm_right: Node3D
var opp_hands_anchor: Node3D
var opp_glove_left_mesh: Node3D
var opp_glove_right_mesh: Node3D
var _has_sculpted_opp_glb: bool = false
var player_glove_left_mesh: Node3D
var player_glove_right_mesh: Node3D
var player_sword_root: Node3D
var opp_sword_root: Node3D
var active_sword_skin_id: String = "SWORD_IRON"
var finisher_anim_active: bool = false
var _finisher_sword_tween: Tween
var _opp_finisher_tween: Tween

# Fiery Combo Dial shader & HUD vars
var combo_flame_rect: ColorRect
var combo_flame_mat: ShaderMaterial
var combo_dial_ctrl: Control
var combo_heat: float = 0.25
var combo_target_heat: float = 0.25
var combo_charge_frac: float = 0.12
var combo_target_charge: float = 0.12
var combo_dial_rot: float = 0.0
var combo_raw_val: int = 0
var combo_mult_val: float = 1.0
var combo_tot_val: int = 0
var combo_embers: Array[Dictionary] = []

var draw_deck_root: Node3D
var discard_pile_root: Node3D
var table_suit_label3d: Label3D
var table_status_label3d: Label3D
var magic_puf_bottle: Node3D

# Kartová logika a stav
var active_era: Dictionary = {}
var deck: Array = []
var discard_pile: Array = []
var player_hand: Array = []
var ai_hand: Array = []

var player_card_nodes: Array[Node3D] = []
var opp_card_nodes: Array[Node3D] = []
var hovered_card_idx: int = -1
var hovered_draw_deck: bool = false
var hovered_puf_bottle: bool = false
var reorder_src_idx: int = -1

# Reactive Boss States, Stone Plaque, Clickable Tavern Props & Spring-Drag State
var opp_recoil_time: float = 0.0
var boss_flare_time: float = 0.0
var boss_eye_left: MeshInstance3D
var boss_eye_right: MeshInstance3D
var boss_sigil_halo: MeshInstance3D
var boss_eye_mat: StandardMaterial3D
var boss_plaque_root: Node3D
var boss_plaque_title_3d: Label3D
var boss_plaque_desc_3d: Label3D
var boss_plaque_rune_3d: Label3D
var hovered_boss_plaque: bool = false
var tavern_mug_root: Node3D
var tavern_coins_root: Node3D
var tavern_dice_root: Node3D
var hovered_tavern_prop: String = ""
var chandelier_sway_boost: float = 0.0
var wall_lantern_roots: Array[Node3D] = []
var sort_hand_bar: Container
var bottom_right_drawer: PanelContainer = null
var bottom_right_drawer_open: bool = false
var bottom_right_drawer_tween: Tween = null
var drawer_guide_btn: Button = null
var drawer_mute_btn: Button = null
var lmb_down: bool = false
var drag_card_idx: int = -1
var drag_active: bool = false
var drag_start_mouse := Vector2.ZERO
var drag_vel_smooth := Vector2.ZERO
var last_mouse_pos := Vector2.ZERO
var preview_hud_active: bool = false
var overdrive_hum_cd: float = 0.0

var active_suit_id: String = "CERVEN"
var pending_draw: int = 0
var pending_skip: bool = false
var is_player_turn: bool = true
var busy_animating: bool = false

var player_score: int = 0
var ai_score: int = 0
var target_score: int = 90
var ai_stun_turns: int = 0
var puf_charges: int = 2

# Minimalistický diegetický HUD (iba hore v rohu tlačidlo späť, skóre a výber farby pri Horníkovi)
var hud_layer: CanvasLayer
var hud_root: Control
var suit_modal: PanelContainer
var _suit_crest_cache: Dictionary = {}
var pending_hornik_idx: int = -1

func _ready() -> void:
	_setup_dark_atmosphere_and_lighting()
	_setup_3d_table_and_props()
	_setup_opponent_shadow_and_hands()
	_setup_player_camera_and_3d_hands()
	_setup_tutorial_beacon_3d()
	_setup_minimal_overlay_hud()
	_setup_cinematic_director()
	bankai_fx = BankaiFxScript.new()
	add_child(bankai_fx)

func _setup_cinematic_director() -> void:
	if is_instance_valid(cinematic_director):
		return
	cinematic_director = CinematicDirectorScript.new()
	cinematic_director.name = "CinematicDirector"
	add_child(cinematic_director)
	if cinematic_director.has_signal("sfx_requested"):
		cinematic_director.connect("sfx_requested", func(sk: String, _v: float, p: float):
			emit_signal("play_sfx_pitched_requested", sk, p)
		)
	cinematic_director.call("setup", self, cam, hud_root, _get_font(true))
	if is_instance_valid(opp_silhouette_root):
		cinematic_director.call("set_opponent_rig", opp_silhouette_root)

func _is_cinematic_playing() -> bool:
	return is_instance_valid(cinematic_director) and bool(cinematic_director.call("is_playing"))

func _can_change_opening_wager() -> bool:
	if tutorial_mode:
		return tutorial_step == 1 and tutorial_substep >= 1 and (not busy_animating) and (not intro_animating)
	return (not opening_turn_committed) and current_round_num == 1 and (not busy_animating) and (not intro_animating) and (not peddler_open) and (not shop_gate_open) and (not _is_cinematic_playing())

func _cycle_opening_wager() -> void:
	if not _can_change_opening_wager():
		return
	var next_w := "ITEM"
	if active_wager_type == "GOLD":
		next_w = "ITEM"
	elif active_wager_type == "ITEM":
		next_w = "SWORD"
	else:
		next_w = "GOLD" if player_available_gold >= wager_gold_amount else "ITEM"
	if next_w == "GOLD":
		emit_signal("play_sfx_requested", "prop_coins")
	elif next_w == "SWORD":
		emit_signal("play_sfx_requested", "card_slam")
	else:
		emit_signal("play_sfx_requested", "ui_click")
	set_duel_wager(next_w)
	if is_instance_valid(wager_indicator_icon):
		wager_indicator_icon.pivot_offset = wager_indicator_icon.size * 0.5
		wager_indicator_icon.scale = Vector2(1.24, 1.24)
		var itw := wager_indicator_icon.create_tween()
		itw.tween_property(wager_indicator_icon, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animate_wager_showcase_3d(true)

func _refresh_wager_indicator_ui() -> void:
	if wager_indicator_pill == null or wager_indicator_lbl == null:
		return
	var is_mp_mode: bool = (get("is_mp_mode") == true)
	if not is_mp_mode:
		wager_indicator_pill.visible = false
		return
	var show_ind := (not tutorial_mode) and (not intro_animating) and (not _is_cinematic_playing()) and (not (victory_summary_overlay and victory_summary_overlay.visible)) and (not (defeat_summary_overlay and defeat_summary_overlay.visible))
	wager_indicator_pill.visible = show_ind
	if not show_ind:
		return
	var short_bet := _get_active_bet_summary()
	var can_edit := _can_change_opening_wager()
	wager_indicator_lbl.text = short_bet
	var accent_c := Color(1.0, 0.42, 0.34) if active_wager_type == "SWORD" else (Color(0.86, 0.56, 1.0) if active_wager_type == "ITEM" else Color(1.0, 0.84, 0.32))
	wager_indicator_lbl.add_theme_color_override("font_color", accent_c.lightened(0.18))
	if is_instance_valid(wager_indicator_icon):
		var icon_name := "ui_wager_sword_3d.png" if active_wager_type == "SWORD" else ("ui_wager_phial_3d.png" if active_wager_type == "ITEM" else "ui_wager_gold_3d.png")
		wager_indicator_icon.texture = _load_blender_ui_tex(icon_name)
	var pill_sb := wager_indicator_pill.get_theme_stylebox("panel")
	if pill_sb is StyleBoxTexture:
		(pill_sb as StyleBoxTexture).modulate_color = Color(1.14, 0.86, 0.86) if active_wager_type == "SWORD" else (Color(0.98, 0.88, 1.14) if active_wager_type == "ITEM" else Color(1.04, 1.01, 0.96))
	if not can_edit:
		wager_indicator_pill.modulate = Color.WHITE
	wager_indicator_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_edit else Control.CURSOR_ARROW
	wager_indicator_pill.tooltip_text = _tr(
		"Active Wager: %s\nBefore Turn 1: click Coins (Gold), Hellfire Phial (Item), Sword (Blood Oath) on the table — or click here to cycle." % short_bet,
		"Aktivní sázka: %s\nPřed 1. tahem: klikni na Mince (Zlato), Baňku (Item), Meč (Krvavá přísaha) na stole — nebo klikni sem pro přepnutí." % short_bet
	)

func _sync_heartbeat_hp_displays(animate_change: bool = true) -> void:
	var show_player_hp := ((not tutorial_mode) or tutorial_step >= 5) and (not _is_cinematic_playing())
	if is_instance_valid(player_hp_heart):
		player_hp_heart.visible = show_player_hp
		player_hp_heart.call("set_hp_with_status", player_hp, player_max_hp, player_shields, "", animate_change, player_knight_shield_charge)
	var show_rival_hp := ((not tutorial_mode) or tutorial_step >= 5) and (not _is_cinematic_playing())
	if is_instance_valid(rival_hp_heart):
		rival_hp_heart.visible = show_rival_hp
		var r_tag := ("%d" % rival_burn_turns) if rival_burn_turns > 0 else (("%d" % rival_poison_turns) if rival_poison_turns > 0 else "")
		rival_hp_heart.call("set_hp_with_status", ai_hp, ai_max_hp, ai_shields, r_tag, animate_change)

func _position_rival_hp_heart(is_boss: bool) -> void:
	if not is_instance_valid(rival_hp_heart):
		return
	var sz := 118.0 if is_boss else 96.0
	rival_hp_heart.anchor_left = 1.0
	rival_hp_heart.anchor_top = 0.0
	rival_hp_heart.anchor_right = 1.0
	rival_hp_heart.anchor_bottom = 0.0
	rival_hp_heart.offset_left = -18.0 - sz
	rival_hp_heart.offset_right = -18.0
	rival_hp_heart.offset_top = 92.0
	rival_hp_heart.offset_bottom = 92.0 + sz
	if is_instance_valid(rival_hud_grp):
		rival_hud_grp.offset_right = -14.0
		rival_hud_grp.offset_left = -362.0
		rival_hud_grp.offset_top = 10.0
		rival_hud_grp.offset_bottom = 84.0

func set_camera_view_mode(mode: CameraViewMode, play_fx: bool = false) -> void:
	cam_view_mode = mode
	cards_tucked = (mode != CameraViewMode.CARDS)
	auto_edge_peek = false
	if mode == CameraViewMode.CARDS and turn_stage == TurnStage.ITEM_REVIEW:
		turn_stage = TurnStage.CARD_PLAY
	if is_instance_valid(view_toggle_btn):
		if cam_view_mode == CameraViewMode.TABLE_ITEMS:
			view_toggle_btn.text = _tr("Cards [TAB]", "Karty [TAB]")
			LialoIcons.apply_button_icon(view_toggle_btn, "cards", 16)
			_style_action_button(view_toggle_btn, Color(0.24, 0.16, 0.08, 0.95), Color(1.0, 0.84, 0.34), 14)
		else:
			view_toggle_btn.text = _tr("Items [TAB]", "Itemy [TAB]")
			LialoIcons.apply_button_icon(view_toggle_btn, "sword", 16)
			_style_action_button(view_toggle_btn, Color(0.11, 0.09, 0.08, 0.94), Color(0.84, 0.64, 0.30), 14)
	if play_fx and cam_view_mode != CameraViewMode.CINEMATIC:
		emit_signal("play_sfx_pitched_requested", "card_hover", 0.82 if cards_tucked else 1.18)
		if cam_view_mode == CameraViewMode.TABLE_ITEMS:
			_animate_wager_showcase_3d(true)
		elif cam_view_mode == CameraViewMode.CARDS:
			_animate_hand_return_wave()
	_sync_peek_ui_visibility()

func toggle_camera_view_mode(play_fx: bool = true) -> void:
	if cam_view_mode == CameraViewMode.CINEMATIC or _is_cinematic_playing():
		return
	if intro_animating or peddler_open or shop_gate_open or mist_guess_open or thief_heist_open or (suit_modal and suit_modal.visible):
		return
	if tutorial_mode and tutorial_step == 0:
		return
	if is_player_turn and turn_stage == TurnStage.ITEM_REVIEW and not tutorial_mode:
		_confirm_item_review_to_cards(play_fx)
		return
	turn_glance_timer = 0.0
	var next_mode := CameraViewMode.CARDS if cam_view_mode == CameraViewMode.TABLE_ITEMS else CameraViewMode.TABLE_ITEMS
	set_camera_view_mode(next_mode, play_fx)
	if tutorial_mode and tutorial_step == 1:
		if tutorial_substep == 1 and next_mode == CameraViewMode.TABLE_ITEMS:
			_update_tutorial_callout_ui(1, false)
		elif tutorial_substep == 2 and next_mode == CameraViewMode.CARDS:
			_trigger_ghost_ok_flash()
			_advance_tutorial_to(2)

func _player_has_any_playable_card() -> bool:
	for c in player_hand:
		if _can_play(c):
			return true
	return false

func _begin_player_item_review_stage(play_fx: bool = true) -> void:
	if intro_seq_tween and intro_seq_tween.is_valid():
		intro_seq_tween.kill()
	intro_animating = false
	turn_glance_timer = 0.0
	staged_card_indices.clear()
	is_player_turn = true
	busy_animating = false
	relic_mgr.reset_turn()
	if tutorial_mode and tutorial_step < 7:
		turn_stage = TurnStage.CARD_PLAY
		set_camera_view_mode(CameraViewMode.CARDS, false)
		return
	turn_stage = TurnStage.ITEM_REVIEW
	set_camera_view_mode(CameraViewMode.TABLE_ITEMS, false)
	if play_fx:
		_animate_wager_showcase_3d(true)
		emit_signal("play_sfx_pitched_requested", "card_hover", 0.86)
	else:
		wager_showcase_boost = 0.75
	_refresh_table_labels()

func _play_table_items_intro_showcase() -> void:
	if tutorial_mode:
		return
	var showcase_nodes: Array[Node3D] = []
	for rn in relic_3d_nodes.values():
		if rn is Node3D and is_instance_valid(rn) and (rn as Node3D).visible:
			showcase_nodes.append(rn as Node3D)
	for ptn in purchased_table_item_nodes:
		if ptn is Node3D and is_instance_valid(ptn) and (ptn as Node3D).visible:
			showcase_nodes.append(ptn as Node3D)
	if is_instance_valid(magic_puf_bottle) and magic_puf_bottle.visible:
		showcase_nodes.append(magic_puf_bottle)
	if is_instance_valid(tavern_bell_root) and tavern_bell_root.visible:
		showcase_nodes.append(tavern_bell_root)
	if is_instance_valid(player_sword_root) and player_sword_root.visible:
		showcase_nodes.append(player_sword_root)

	for si in range(showcase_nodes.size()):
		var sn: Node3D = showcase_nodes[si]
		var pid_s := str(sn.get_meta("prop_id", sn.get_meta("relic_id", "item")))
		var id_u := pid_s.to_upper()
		var item_col := Color(0.96, 0.80, 0.36)
		if pid_s.begins_with("trelic:"):
			item_col = Catalog.get_table_relic_loc(pid_s.substr(7), opts_language).get("col", item_col)
		elif pid_s.begins_with("relic:"):
			item_col = Catalog.get_relic_loc(pid_s.substr(6), opts_language).get("col", item_col)
		elif sn.has_meta("item_col"):
			item_col = sn.get_meta("item_col")
		elif "SWORD" in id_u:
			item_col = Color(0.95, 0.32, 0.26)
		elif "PHIAL" in id_u or sn == magic_puf_bottle:
			item_col = Color(1.0, 0.48, 0.16)
		var bp: Vector3 = sn.get_meta("base_pos", sn.position)
		var bs: Vector3 = sn.get_meta("base_scale", sn.scale)
		var br: Vector3 = sn.get_meta("base_rot", sn.rotation_degrees)
		sn.set_meta("base_pos", bp)
		sn.set_meta("base_scale", bs)
		sn.set_meta("base_rot", br)
		var delay := 0.08 * float(si)
		var tw := sn.create_tween()
		if delay > 0.001:
			tw.tween_interval(delay)
		tw.tween_callback(func():
			if is_instance_valid(self) and is_instance_valid(sn):
				var gp := sn.global_position + Vector3(0.0, 0.06, 0.0)
				Fx.ring(self, gp, item_col, 0.24, 0.36, 0.04, 1.9, 6.0)
				Fx.burst(self, gp, item_col.lightened(0.25), 10, 0.75, 0.38, 0.020, 1.6, true, 120.0, Vector3.UP, true)
				emit_signal("play_sfx_pitched_requested", "card_hover", 0.92 + float(si % 5) * 0.08)
		)
		tw.tween_property(sn, "position:y", bp.y + 0.18, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sn, "scale", bs * 1.26, 0.16)
		tw.parallel().tween_property(sn, "rotation_degrees:y", br.y + 360.0, 0.36).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(sn, "position:y", bp.y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sn, "scale", bs, 0.18)

func _can_use_table_item(item_id: String) -> bool:
	return relic_mgr.can_use(item_id)

func _refresh_combat_log_relic_pill() -> void:
	if combat_log_drawer == null:
		return
	var entries: Array = []
	for tid in run_table_relics:
		var t_s := str(tid)
		var t_inf := Catalog.get_table_relic_loc(t_s, opts_language)
		var ic_s := str(t_inf.get("icon", ""))
		entries.append({
			"icon": ic_s,
			"rem": relic_mgr.get_remaining(t_s),
			"max": TableRelicMgrScript.MAX_TABLE_ITEM_USES,
			"broken": relic_mgr.is_broken(t_s),
		})
	for rid in run_active_relics:
		var r_s := str(rid)
		var r_inf := Catalog.get_relic_loc(r_s, opts_language)
		var ic_r := str(r_inf.get("icon", "✦"))
		entries.append({
			"icon": ic_r,
			"rem": relic_mgr.get_remaining(r_s),
			"max": TableRelicMgrScript.MAX_TABLE_ITEM_USES,
			"broken": relic_mgr.is_broken(r_s),
		})
	combat_log_drawer.update_relic_pill(entries)

func _record_table_item_activation(item_id: String, item_node: Variant, target_override: Vector3 = Vector3.ZERO, anim_key: String = "") -> int:
	var n_node: Node3D = item_node as Node3D if item_node is Node3D else null
	var origin := n_node.global_position if is_instance_valid(n_node) else (discard_pile_root.global_position if is_instance_valid(discard_pile_root) else Vector3(0.0, 0.85, 0.0))
	var target := target_override
	if target == Vector3.ZERO:
		target = opp_silhouette_root.global_position + Vector3(0.0, 0.65, 0.18) if is_instance_valid(opp_silhouette_root) else Vector3(0.0, 1.25, -1.35)
	var col := Color(0.96, 0.78, 0.34)
	var item_name := item_id
	var t_info := Catalog.get_table_relic_loc(item_id, opts_language)
	if not t_info.is_empty():
		col = t_info.get("col", col)
		item_name = str(t_info.get("name", item_id))
	else:
		var r_info := Catalog.get_relic_loc(item_id, opts_language)
		if not r_info.is_empty():
			col = r_info.get("col", col)
			item_name = str(r_info.get("name", item_id))
		elif is_instance_valid(n_node) and n_node.has_meta("item_col"):
			col = n_node.get_meta("item_col")
			item_name = str(n_node.get_meta("hover_title", item_id))

	Fx.play_complex_table_item_anim(self, n_node, origin, target, anim_key if anim_key != "" else item_id, col)

	var use_res := relic_mgr.record_use(item_id)
	var rem := int(use_res.get("rem", 0))
	var shattered := bool(use_res.get("shattered", false))
	var overcharged := bool(use_res.get("overcharged", false))

	if is_instance_valid(n_node):
		var rtag := n_node.get_node_or_null("RelicHoverTag") as Label3D
		if rtag:
			if rem <= 0:
				rtag.text = _tr("%s [SHATTERED]", "%s [ROZBITO]") % item_name
			else:
				var short_tag := str(t_info.get("short", "")) if not t_info.is_empty() else ""
				if short_tag != "":
					rtag.text = "%s [%d/%d]\n[%s]" % [item_name, rem, MAX_TABLE_ITEM_USES, short_tag]
				else:
					rtag.text = "%s [%d/%d]" % [item_name, rem, MAX_TABLE_ITEM_USES]

	if overcharged:
		_show_stagger_callout(_tr("OVERCHARGE (-2 dur): %s" % item_name, "PŘETÍŽENÍ (-2 výdrž): %s" % item_name), Color(1.0, 0.62, 0.18), 1.35)
		if not shattered:
			Fx.float_number(self, origin + Vector3(0.0, 0.36, 0.0), _tr("OVERCHARGE (-2 dur)", "PŘETÍŽENÍ (-2 výdrž)"), Color(1.0, 0.66, 0.18), 46, 0.18, 0.80, 1.35)

	if shattered:
		invoked_table_relics[item_id] = true
		Fx.float_number(self, origin + Vector3(0.0, 0.26, 0.0), _tr("SHATTERED! (0/3)", "ROZBITO! (0/3)"), Color(1.0, 0.36, 0.24), 52, 0.20, 0.90, 1.45)
		get_tree().create_timer(0.50).timeout.connect(func():
			if is_instance_valid(self):
				Fx.shatter_table_item(self, n_node, origin, col)
				emit_signal("play_sfx_pitched_requested", "card_slam", 0.72)
		)
	else:
		invoked_table_relics.erase(item_id)
		Fx.float_number(self, origin + Vector3(0.0, 0.26, 0.0), "%d/%d" % [rem, MAX_TABLE_ITEM_USES], col.lightened(0.32), 46, 0.16, 0.65, 1.25)

	if combat_log_drawer != null:
		var ov_tag := "OVERCHARGE (-2 dur)" if overcharged else ""
		var sh_tag := "SHATTERED!" if shattered else (" (%d/%d)" % [rem, MAX_TABLE_ITEM_USES])
		combat_log_drawer.add_entry("✦ %s%s%s" % [item_name, ov_tag, sh_tag], Color(1.0, 0.50, 0.34) if shattered else (Color(1.0, 0.72, 0.28) if overcharged else col.lightened(0.25)))
	_refresh_combat_log_relic_pill()
	return rem

func _confirm_item_review_to_cards(play_fx: bool = true) -> void:
	if turn_stage != TurnStage.ITEM_REVIEW and cam_view_mode == CameraViewMode.CARDS:
		return
	if intro_seq_tween and intro_seq_tween.is_valid():
		intro_seq_tween.kill()
	intro_animating = false
	turn_stage = TurnStage.CARD_PLAY
	turn_glance_timer = 0.0
	set_camera_view_mode(CameraViewMode.CARDS, play_fx)
	if not tutorial_mode and is_player_turn and not _player_has_any_playable_card() and table_status_label3d:
		table_status_label3d.text = _tr("No playable cards — Draw from Deck! [Click Deck / W]", "Nemáš hratelnou kartu — Lízni z balíčku! [Klikni / W]")
	_refresh_table_labels()

func _enter_cinematic_camera_lock() -> void:
	if cam_view_mode != CameraViewMode.CINEMATIC:
		_pre_cinematic_view_mode = cam_view_mode
	cam_view_mode = CameraViewMode.CINEMATIC
	cards_tucked = true
	cam_impact_active = true
	rmb_down = false
	lmb_down = false
	drag_card_idx = -1
	drag_active = false
	hovered_card_idx = -1
	hovered_prop_id = ""
	if prop_hover_pill:
		prop_hover_pill.visible = false
	if hover_inspect_panel:
		hover_inspect_panel.visible = false
	if stack_action_bar:
		stack_action_bar.visible = false
	if quick_action_bar:
		quick_action_bar.visible = false
	if veto_standalone_panel:
		veto_standalone_panel.visible = false
	if wager_indicator_pill:
		wager_indicator_pill.visible = false
	if view_toggle_btn:
		view_toggle_btn.visible = false
	if is_instance_valid(player_hp_heart):
		player_hp_heart.visible = false
	if is_instance_valid(rival_hp_heart):
		rival_hp_heart.visible = false

func _exit_cinematic_camera_lock(restore_mode: CameraViewMode = CameraViewMode.CARDS) -> void:
	cam_impact_active = false
	cam_spring.reset()
	cam_prev_pitch_kick = 0.0
	cam_prev_fov_kick = 0.0
	set_camera_view_mode(restore_mode, false)
	_sync_heartbeat_hp_displays(false)

func _cancel_active_cinematic() -> void:
	_cinematic_seq_token += 1
	if _is_cinematic_playing():
		cinematic_director.call("skip_current")
	cam_impact_active = false
	if cam_view_mode == CameraViewMode.CINEMATIC:
		set_camera_view_mode(CameraViewMode.CARDS, false)

func _setup_tutorial_beacon_3d() -> void:
	tutorial_beacon_mesh = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.145
	ring.outer_radius = 0.175
	ring.rings = 28
	ring.ring_segments = 12
	tutorial_beacon_mesh.mesh = ring
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.86, 0.28, 0.88)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.render_priority = 1
	tutorial_beacon_mesh.material_override = bmat
	tutorial_beacon_mesh.visible = false
	add_child(tutorial_beacon_mesh)

	# 3D Full Human-Scale Animated Ghost Companion ("Spirko — Duch Krčmára") seated physically next to the player
	tutorial_ghost_3d = Node3D.new()
	tutorial_ghost_3d.name = "TutorialGhost3D"
	tutorial_ghost_3d.position = Vector3(-0.92, 0.80, 0.14)
	tutorial_ghost_3d.rotation_degrees = Vector3(0.0, 52.0, 0.0)
	tutorial_ghost_3d.visible = false
	add_child(tutorial_ghost_3d)

	tutorial_ghost_mat = StandardMaterial3D.new()
	tutorial_ghost_mat.albedo_color = Color(0.46, 0.98, 0.80, 0.80)
	tutorial_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tutorial_ghost_mat.emission_enabled = true
	tutorial_ghost_mat.emission = Color(0.32, 0.94, 0.76)
	tutorial_ghost_mat.emission_energy_multiplier = 1.35

	# Tattered ghostly robe skirt
	var g_skirt := MeshInstance3D.new()
	var g_skm := CylinderMesh.new(); g_skm.top_radius = 0.21; g_skm.bottom_radius = 0.34; g_skm.height = 0.42
	g_skirt.mesh = g_skm; g_skirt.position = Vector3(0.0, -0.02, 0.0); g_skirt.material_override = tutorial_ghost_mat
	tutorial_ghost_3d.add_child(g_skirt)

	# Human-scale spectral torso & wide cloak mantle
	var g_body := MeshInstance3D.new()
	var g_cap := CapsuleMesh.new(); g_cap.radius = 0.22; g_cap.height = 0.56
	g_body.mesh = g_cap; g_body.position = Vector3(0.0, 0.26, 0.0); g_body.material_override = tutorial_ghost_mat
	tutorial_ghost_3d.add_child(g_body)

	var g_mantle := MeshInstance3D.new()
	var g_mm := CylinderMesh.new(); g_mm.top_radius = 0.22; g_mm.bottom_radius = 0.31; g_mm.height = 0.15
	g_mantle.mesh = g_mm; g_mantle.position = Vector3(0.0, 0.44, 0.0); g_mantle.material_override = tutorial_ghost_mat
	tutorial_ghost_3d.add_child(g_mantle)

	# Full human-sized spectral head
	var g_head := MeshInstance3D.new()
	var g_hm := SphereMesh.new(); g_hm.radius = 0.145; g_hm.height = 0.27
	g_head.mesh = g_hm; g_head.position = Vector3(0.0, 0.66, 0.02); g_head.material_override = tutorial_ghost_mat
	tutorial_ghost_3d.add_child(g_head)

	# Wizard / tavern ghost hat brim + crooked tall cone
	var hat_mat := Toon.mat(Color(0.22, 0.14, 0.36), "", 0.008, Vector2.ONE, Color(0.20, 0.12, 0.34))
	var g_brim := MeshInstance3D.new()
	var g_bm := CylinderMesh.new(); g_bm.top_radius = 0.22; g_bm.bottom_radius = 0.24; g_bm.height = 0.028
	g_brim.mesh = g_bm; g_brim.position = Vector3(0.0, 0.78, 0.02); g_brim.rotation_degrees = Vector3(-6.0, 0.0, 7.0); g_brim.material_override = hat_mat
	tutorial_ghost_3d.add_child(g_brim)

	var g_hat := MeshInstance3D.new()
	var g_cone := CylinderMesh.new(); g_cone.top_radius = 0.012; g_cone.bottom_radius = 0.14; g_cone.height = 0.24
	g_hat.mesh = g_cone; g_hat.position = Vector3(-0.02, 0.90, 0.02); g_hat.rotation_degrees = Vector3(-6.0, 0.0, 12.0); g_hat.material_override = hat_mat
	tutorial_ghost_3d.add_child(g_hat)

	# Bright expressive eyes + animated talking mouth
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.96, 0.56)
	for ex in [-0.048, 0.048]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new(); es.radius = 0.020; es.height = 0.036
		eye.mesh = es; eye.position = Vector3(ex, 0.68, 0.145); eye.material_override = eye_mat
		tutorial_ghost_3d.add_child(eye)

	tutorial_ghost_mouth = MeshInstance3D.new()
	var gm := SphereMesh.new(); gm.radius = 0.028; gm.height = 0.032
	tutorial_ghost_mouth.mesh = gm
	tutorial_ghost_mouth.position = Vector3(0.0, 0.59, 0.145)
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mouth_mat.albedo_color = Color(0.08, 0.05, 0.12)
	tutorial_ghost_mouth.material_override = mouth_mat
	tutorial_ghost_3d.add_child(tutorial_ghost_mouth)

	# Gesturing right arm + glowing amber ghost lantern pointing at what he teaches
	tutorial_ghost_arm = Node3D.new()
	tutorial_ghost_arm.position = Vector3(0.24, 0.38, 0.08)
	tutorial_ghost_3d.add_child(tutorial_ghost_arm)

	var g_forearm := MeshInstance3D.new()
	var g_fm := CapsuleMesh.new(); g_fm.radius = 0.045; g_fm.height = 0.28
	g_forearm.mesh = g_fm; g_forearm.position = Vector3(0.06, -0.02, 0.14); g_forearm.rotation_degrees = Vector3(72.0, 14.0, 0.0)
	g_forearm.material_override = tutorial_ghost_mat
	tutorial_ghost_arm.add_child(g_forearm)

	var g_lantern := MeshInstance3D.new()
	var g_lm := SphereMesh.new(); g_lm.radius = 0.038; g_lm.height = 0.055
	g_lantern.mesh = g_lm; g_lantern.position = Vector3(0.11, -0.03, 0.30)
	var lan_mat := StandardMaterial3D.new()
	lan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lan_mat.albedo_color = Color(1.0, 0.88, 0.38)
	g_lantern.material_override = lan_mat
	tutorial_ghost_arm.add_child(g_lantern)

	tutorial_ghost_light = OmniLight3D.new()
	tutorial_ghost_light.position = Vector3(0.16, 0.58, 0.36)
	tutorial_ghost_light.light_color = Color(0.56, 0.80, 0.96)
	tutorial_ghost_light.light_energy = 1.45
	tutorial_ghost_light.omni_range = 1.95
	tutorial_ghost_3d.add_child(tutorial_ghost_light)

	# Diegetic 3D Floating Spoken Text beside Spirko's head (NO rectangular pop-up window!)
	tutorial_ghost_speech_3d = Label3D.new()
	tutorial_ghost_speech_3d.font = _get_font(true)
	tutorial_ghost_speech_3d.font_size = 24
	tutorial_ghost_speech_3d.outline_size = 3
	tutorial_ghost_speech_3d.modulate = Color(0.96, 1.0, 0.90)
	tutorial_ghost_speech_3d.outline_modulate = Color(0.03, 0.04, 0.06)
	tutorial_ghost_speech_3d.pixel_size = 0.00145
	tutorial_ghost_speech_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tutorial_ghost_speech_3d.no_depth_test = true
	tutorial_ghost_speech_3d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_ghost_speech_3d.width = 430.0
	tutorial_ghost_speech_3d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tutorial_ghost_speech_3d.position = Vector3(0.42, 0.95, 0.14)
	tutorial_ghost_speech_3d.text = ""
	tutorial_ghost_speech_3d.visible = false
	tutorial_ghost_3d.add_child(tutorial_ghost_speech_3d)

	# 3D Ornate Arrowed Wager Target Ring under staked Sword / Gold
	wager_3d_ring = MeshInstance3D.new()
	var w_plane := PlaneMesh.new(); w_plane.size = Vector2(0.46, 0.46)
	wager_3d_ring.mesh = w_plane
	wager_3d_ring.material_override = _make_arrow_compass_ring_mat(Color(1.0, 0.82, 0.28, 0.92), 8.0, 1.35)
	wager_3d_ring.position = Vector3(-0.56, 0.822, 0.44)
	wager_3d_ring.visible = false
	add_child(wager_3d_ring)

func _register_blender_vfx(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var pruned: Array[Node3D] = []
	for n in _active_blender_vfx_nodes:
		if is_instance_valid(n):
			pruned.append(n)
	pruned.append(node)
	_active_blender_vfx_nodes = pruned

func _clear_blender_vfx() -> void:
	for n in _active_blender_vfx_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_active_blender_vfx_nodes.clear()
	if is_instance_valid(_active_astrolabe_stage):
		_active_astrolabe_stage.queue_free()
	_active_astrolabe_stage = null

func set_active(active: bool) -> void:
	visible = active
	if not active:
		_cancel_active_cinematic()
		rmb_down = false
		intro_animating = false
		busy_animating = false
		finisher_anim_active = false
		dramatic_lighting_dim = 0.0
		_stagger_seq_token += 1
		_clear_blender_vfx()
		for dn in _scored_display_nodes:
			if is_instance_valid(dn):
				dn.queue_free()
		_scored_display_nodes.clear()
		cam_impact_active = false
		cam_kick_shake = 0.0
		cam_spring.reset()
		cam_prev_pitch_kick = 0.0
		cam_prev_fov_kick = 0.0
		freelook_yaw = 0.0
		freelook_pitch = 0.0
		cam_look_yaw = 0.0
		cam_look_pitch = 0.0
		_cursor_look_pos = Vector2(-1.0, -1.0)
		if cam:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			cam.rotation_degrees.z = 0.0
		if stagger_callout_pill:
			stagger_callout_pill.visible = false
		if defeat_summary_overlay:
			defeat_summary_overlay.visible = false
		if victory_summary_overlay:
			victory_summary_overlay.visible = false
		if peek_hud_bar:
			peek_hud_bar.visible = false
		if intro_title_grp:
			intro_title_grp.visible = false
		if tutorial_beacon_mesh:
			tutorial_beacon_mesh.visible = false
	if cam:
		cam.current = active
	if woodcut_layer:
		woodcut_layer.visible = active
	if hud_root:
		hud_root.visible = active
	set_process(active)
	set_process_unhandled_input(active)

func _get_font(display: bool = true) -> Font:
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

# ============================================================================
# 1. TEMNÁ MIESTNOSŤ, HMLA A BODOVÉ SVETLO NAD STOLOM (LIAR'S BAR VIBE)
# ============================================================================
func _setup_dark_atmosphere_and_lighting() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.020, 0.028, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.085, 0.09, 0.13)
	env.fog_enabled = true
	env.fog_light_color = Color(0.025, 0.032, 0.055)
	env.fog_density = 0.024
	env_node.environment = env
	add_child(env_node)
	gfx_env = env
	gfx_base_ambient_energy = env.ambient_light_energy

	# Hlavná teplá lampa visiaca priamo nad stredom stola (osvetľuje stôl a ruky, postava vzadu ostáva v tme!)
	table_spot_light = SpotLight3D.new()
	table_spot_light.position = Vector3(0.0, 2.80, 0.05)
	table_spot_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	table_spot_light.light_color = Color(1.0, 0.87, 0.70)
	table_spot_light.light_energy = 1.65
	table_spot_light.spot_range = 6.5
	table_spot_light.spot_angle = 49.0
	table_spot_light.spot_angle_attenuation = 1.9
	table_spot_light.shadow_enabled = true
	add_child(table_spot_light)

	# Podsvietenie rúk hráča — jemné teplé osvetlenie bez prepálenia kariet
	player_hand_light = OmniLight3D.new()
	player_hand_light.position = Vector3(0.0, 1.38, 1.22)
	player_hand_light.light_color = Color(0.98, 0.90, 0.78)
	player_hand_light.light_energy = 0.55
	player_hand_light.omni_range = 2.3
	add_child(player_hand_light)

	# Dedicated rim backlight behind the Boss Silhouette — tinted per historical epoch
	boss_rim_light = SpotLight3D.new()
	boss_rim_light.position = Vector3(0.0, 1.88, -2.36)
	boss_rim_light.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
	boss_rim_light.light_color = Color(1.0, 0.66, 0.24)
	boss_rim_light.light_energy = 4.5
	boss_rim_light.spot_range = 3.6
	boss_rim_light.spot_angle = 44.0
	add_child(boss_rim_light)

	# Dedicated atmospheric Buckshot item-review spotlight over active player's tabletop props
	item_review_light = OmniLight3D.new()
	item_review_light.name = "ItemReviewOmniLight"
	item_review_light.position = Vector3(0.0, 1.48, 0.42)
	item_review_light.light_color = Color(1.0, 0.86, 0.56)
	item_review_light.light_energy = 0.0
	item_review_light.omni_range = 2.8
	item_review_light.omni_attenuation = 1.25
	add_child(item_review_light)

# ============================================================================
# 2. 3D STÔL, 3D ŤAHACÍ BALÍČEK, ODHADZOVACIA KOPA A FĽAŠTIČKA MAGICKÉHO PUFU
# ============================================================================
func _load_glb_model(res_path: String, cast_shadows: bool = true) -> Node3D:
	var inst_node: Node3D = null
	if ResourceLoader.exists(res_path):
		var packed := load(res_path) as PackedScene
		if packed:
			var sc := packed.instantiate()
			if sc is Node3D:
				inst_node = sc as Node3D
	if inst_node == null and FileAccess.file_exists(res_path):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(res_path), st) == OK:
			var gen := doc.generate_scene(st)
			if gen is Node3D:
				inst_node = gen as Node3D
	if inst_node:
		_set_shadow_mode_recursive(inst_node, cast_shadows)
	return inst_node

func _set_shadow_mode_recursive(node: Node, cast_shadows: bool) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in node.get_children():
		_set_shadow_mode_recursive(ch, cast_shadows)

func _apply_mat_by_mesh_name(root: Node, mat_map: Dictionary) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var nm := mi.name.to_lower()
		for k in mat_map.keys():
			if str(k).to_lower() in nm:
				mi.material_override = mat_map[k]
				break
	for ch in root.get_children():
		_apply_mat_by_mesh_name(ch, mat_map)

func _make_triplanar_pbr_mat(tex_path: String, tint: Color, world_scale: float, roughness: float = 0.85, metallic: float = 0.04, normal_path: String = "", ao_path: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = roughness
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3(world_scale, world_scale, world_scale)
	if tex_path != "":
		var t := Toon.tex(tex_path)
		if t:
			m.albedo_texture = t
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.albedo_color = Color(1, 1, 1, 1).lerp(tint, 0.56)
	if normal_path != "":
		var nt := Toon.tex(normal_path)
		if nt:
			m.normal_enabled = true
			m.normal_texture = nt
			m.normal_scale = 0.85
	if ao_path != "":
		var at := Toon.tex(ao_path)
		if at:
			m.ao_enabled = true
			m.ao_texture = at
			m.ao_light_affect = 0.65
	return m

func _setup_3d_table_and_props() -> void:
	# Blender-sculpted Heavy Carved Oak & Brass Duel Table (flat play bed y=0.798 out to r=1.44, bolstered armrest rim)
	var table_glb := _load_glb_model("res://assets/models/battle_table.glb", true)
	if table_glb:
		table_glb.name = "BattleTableGLB"
		var tbl_wood := _make_triplanar_pbr_mat("res://assets/table/wood.png", Color(0.24, 0.14, 0.09), 0.72, 0.68, 0.04)
		var tbl_leather := _make_triplanar_pbr_mat("res://assets/gloves/glove_leather.png", Color(0.14, 0.08, 0.06), 1.45, 0.72, 0.04)
		var tbl_brass := Toon.pbr(Color(0.76, 0.56, 0.20), "", 0.30, 0.88)
		var tbl_iron := Toon.pbr(Color(0.15, 0.16, 0.19), "", 0.44, 0.84)
		_apply_mat_by_mesh_name(table_glb, {
			"tablefootpad": tbl_iron,
			"rimbracket": tbl_iron,
			"stretcherring": tbl_iron,
			"tablebrass": tbl_brass,
			"rimstud": tbl_brass,
			"aproncorbel": tbl_brass,
			"tablebolsterleather": tbl_leather,
			"tablebodyslab": tbl_wood,
			"tablegothicapron": tbl_wood,
			"tablepedestal": tbl_wood,
			"tablefoot": tbl_wood,
		})
		add_child(table_glb)
	else:
		var table_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new(); cyl.top_radius = 1.85; cyl.bottom_radius = 1.76; cyl.height = 0.12; cyl.radial_segments = 20
		table_mesh.mesh = cyl; table_mesh.material_override = Toon.pbr(Color(0.42, 0.27, 0.16), "res://assets/table/wood.png", 0.62, 0.04, Vector2(2.4, 2.4)); table_mesh.position = Vector3(0.0, 0.74, 0.0)
		add_child(table_mesh)

	# Kamenná podlaha krčmy s World-Space Triplanar UV (bez natiahnutej textúry!) + koberec pod stolom
	var floor_mesh := MeshInstance3D.new()
	var fplane := PlaneMesh.new()
	fplane.size = Vector2(18.0, 18.0)
	floor_mesh.mesh = fplane
	floor_mesh.material_override = _make_triplanar_pbr_mat("res://assets/table/stone_floor.png", Color(0.32, 0.30, 0.30), 0.42, 0.90, 0.02)
	add_child(floor_mesh)

	var rug_mesh := MeshInstance3D.new()
	var rcyl := CylinderMesh.new()
	rcyl.top_radius = 2.65
	rcyl.bottom_radius = 2.65
	rcyl.height = 0.012
	rcyl.radial_segments = 24
	rug_mesh.mesh = rcyl
	rug_mesh.position = Vector3(0.0, 0.008, 0.0)
	rug_mesh.material_override = Toon.pbr(Color(0.40, 0.14, 0.13), "res://assets/table/felt.png", 0.92, 0.0, Vector2(2.6, 2.6))
	add_child(rug_mesh)

	_setup_epic_3d_tavern_environment()
	_spawn_chandelier_volumetric_cone()

	# Rekvizity na stole: zlatý svietnik, mešec florinov s mincami, zvonček kupca a dva duelistické meče!
	_spawn_candle(Vector3(-1.02, 0.80, -0.52))
	_spawn_mug(Vector3(0.96, 0.80, -0.46))
	_spawn_table_dice_and_coins()
	_spawn_tavern_shop_bell(Vector3(-0.92, 0.806, -0.14))

	# Zdobená tmavá vkladaná hracia plocha (shader inlay: karmínovo-indigo súkno, mosadzné kruhy, bez nudnej zelenej!)
	var felt := MeshInstance3D.new()
	var felt_cyl := CylinderMesh.new()
	felt_cyl.top_radius = 1.38
	felt_cyl.bottom_radius = 1.40
	felt_cyl.height = 0.020
	felt_cyl.radial_segments = 48
	felt.mesh = felt_cyl
	table_felt_mat = ShaderMaterial.new()
	table_felt_mat.shader = TABLE_INLAY_SHADER
	table_felt_mat.set_shader_parameter("cloth_tex", Toon.tex("res://assets/table/felt.png"))
	table_felt_mat.set_shader_parameter("mat_radius", 1.38)
	felt.material_override = table_felt_mat
	felt.position = Vector3(0.0, 0.805, 0.0)
	add_child(felt)
	_build_suit_astrolabe_and_rim()

	# 3D Odpočívajúce duelové meče po bokoch stola (hráčov meč vpravo so skinom + súperov vľavo!)
	player_sword_root = _build_3d_sword_mesh(active_sword_skin_id)
	player_sword_root.position = Vector3(1.02, 0.822, 0.22)
	player_sword_root.rotation_degrees = Vector3(0.0, 16.0, 0.0)
	player_sword_root.set_meta("base_pos", player_sword_root.position)
	player_sword_root.set_meta("base_scale", Vector3.ONE)
	player_sword_root.set_meta("prop_id", "sword")
	_attach_sword_hover_area(player_sword_root)
	add_child(player_sword_root)

	opp_sword_root = _build_3d_sword_mesh("SWORD_CRIMSON")
	opp_sword_root.position = Vector3(-0.38, 0.822, -0.74)
	opp_sword_root.rotation_degrees = Vector3(0.0, 96.0, 0.0)
	add_child(opp_sword_root)

	# Jemný zlatý okruh na stole pre Peek (SPACE) okolo odhodenej kopy
	table_peek_mat = StandardMaterial3D.new()
	table_peek_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	table_peek_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	table_peek_mat.albedo_color = Color(1.0, 0.82, 0.30, 0.0)
	table_peek_ring = MeshInstance3D.new()
	var pt := TorusMesh.new(); pt.inner_radius = 0.34; pt.outer_radius = 0.365; pt.rings = 40; pt.ring_segments = 8
	table_peek_ring.mesh = pt
	table_peek_ring.position = Vector3(0.14, 0.822, 0.02)
	table_peek_ring.scale = Vector3(1.0, 0.22, 1.0)
	table_peek_ring.material_override = table_peek_mat
	add_child(table_peek_ring)

	table_arcane_mat = StandardMaterial3D.new()
	table_arcane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	table_arcane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	table_arcane_mat.albedo_color = Color(0.95, 0.72, 0.28, 0.52)

	table_arcane_outer = MeshInstance3D.new()
	var a_plane1 := PlaneMesh.new()
	a_plane1.size = Vector2(1.48, 1.48)
	table_arcane_outer.mesh = a_plane1
	table_arcane_outer.position = Vector3(0.0, 0.815, 0.02)
	table_arcane_outer.material_override = _make_arrow_compass_ring_mat(Color(0.95, 0.74, 0.28, 0.78), 12.0, 0.65)
	add_child(table_arcane_outer)

	table_arcane_inner = MeshInstance3D.new()
	var a_plane2 := PlaneMesh.new()
	a_plane2.size = Vector2(0.86, 0.86)
	table_arcane_inner.mesh = a_plane2
	table_arcane_inner.position = Vector3(0.14, 0.8165, 0.02)
	table_arcane_inner.material_override = _make_arrow_compass_ring_mat(Color(1.0, 0.84, 0.36, 0.92), 8.0, 1.25)
	add_child(table_arcane_inner)
	var chev_brass := Toon.pbr(Color(0.92, 0.72, 0.26), "", 0.26, 0.86, Vector2.ONE, Color(0.28, 0.18, 0.04), 0.35)
	for ai in range(8):
		var aang := float(ai) * TAU / 8.0
		var chev := MeshInstance3D.new()
		var cp := PrismMesh.new(); cp.size = Vector3(0.042, 0.052, 0.008)
		chev.mesh = cp
		chev.position = Vector3(cos(aang) * 0.365, 0.004, sin(aang) * 0.365)
		chev.rotation_degrees = Vector3(-90.0, -rad_to_deg(aang) - 90.0, 0.0)
		chev.material_override = chev_brass
		table_arcane_inner.add_child(chev)

	# 3D Stojan pre aktívne Relikvie po ľavom okraji stola + Kúpené 3D predmety z obchodu vpravo
	table_relic_rack_root = Node3D.new()
	table_relic_rack_root.position = Vector3(0.0, 0.816, 0.0)
	add_child(table_relic_rack_root)

	purchased_table_items_root = Node3D.new()
	purchased_table_items_root.position = Vector3.ZERO
	add_child(purchased_table_items_root)

	# 3D Komíniky zlatých a rubínových žetónov pri banku
	table_pot_chips_root = Node3D.new()
	table_pot_chips_root.position = Vector3(0.56, 0.816, -0.06)
	add_child(table_pot_chips_root)
	for st_i in range(3):
		var col_chip := Color(0.96, 0.78, 0.22) if st_i % 2 == 0 else Color(0.84, 0.22, 0.26)
		var cmat := Toon.mat(col_chip, "", 0.004, Vector2.ONE, col_chip * 0.12)
		var sx := -0.06 + float(st_i) * 0.062
		var sz := 0.02 if st_i == 1 else -0.02
		var stack_h := 5 - st_i
		for ch_j in range(stack_h):
			var cm := MeshInstance3D.new()
			var cc := CylinderMesh.new(); cc.top_radius = 0.026; cc.bottom_radius = 0.026; cc.height = 0.009; cc.radial_segments = 14
			cm.mesh = cc; cm.material_override = cmat
			cm.position = Vector3(sx, 0.006 + float(ch_j) * 0.010, sz)
			table_pot_chips_root.add_child(cm)

	# 3D Ťahací balíček (vľavo na stole) s Blender kartovým stojanom a Area3D kolíziou pre kliknutie myšou
	draw_deck_root = Node3D.new()
	draw_deck_root.position = Vector3(-0.46, 0.815, 0.04)
	draw_deck_root.set_meta("base_pos", draw_deck_root.position)
	draw_deck_root.set_meta("base_scale", Vector3.ONE)
	draw_deck_root.set_meta("prop_id", "deck")
	add_child(draw_deck_root)

	var deck_glb := _load_glb_model("res://assets/models/deck_shoe.glb", true)
	if deck_glb:
		deck_glb.name = "DeckShoeGLB"
		var card_top_mat := Toon.pbr(Color.WHITE, "res://assets/table/card_back.png", 0.56, 0.04)
		card_top_mat.albedo_color = Color.WHITE
		_apply_mat_by_mesh_name(deck_glb, {"decktopcard": card_top_mat})
		draw_deck_root.add_child(deck_glb)
	else:
		var stack_mesh := MeshInstance3D.new()
		stack_mesh.name = "DeckStackMesh"
		var stack_box := BoxMesh.new()
		stack_box.size = Vector3(0.20, 0.068, 0.285)
		stack_mesh.mesh = stack_box
		stack_mesh.material_override = Toon.mat(Color(0.96, 0.94, 0.90), "res://assets/table/card_back.png", 0.004)
		stack_mesh.position = Vector3(0, 0.034, 0)
		draw_deck_root.add_child(stack_mesh)

	var deck_trim := Node3D.new()
	deck_trim.name = "DeckThemeTrim"
	draw_deck_root.add_child(deck_trim)

	var deck_lbl := Label3D.new()
	deck_lbl.name = "DeckCountLabel"
	deck_lbl.text = "DECK"
	deck_lbl.font = _get_font(true)
	deck_lbl.font_size = 20
	deck_lbl.outline_size = 5
	deck_lbl.pixel_size = 0.0018
	deck_lbl.rotation_degrees = Vector3(-90, 0, 0)
	deck_lbl.position = Vector3(0, 0.072, 0)
	draw_deck_root.add_child(deck_lbl)

	var deck_area := Area3D.new()
	deck_area.name = "DrawDeckArea"
	var deck_col := CollisionShape3D.new()
	var d_shape := BoxShape3D.new()
	d_shape.size = Vector3(0.25, 0.12, 0.34)
	deck_col.shape = d_shape
	deck_area.add_child(deck_col)
	draw_deck_root.add_child(deck_area)

	draw_deck_beacon = MeshInstance3D.new()
	draw_deck_beacon.name = "DrawDeckBeaconRing"
	var d_tor := TorusMesh.new()
	d_tor.inner_radius = 0.165
	d_tor.outer_radius = 0.195
	d_tor.rings = 32
	d_tor.ring_segments = 10
	draw_deck_beacon.mesh = d_tor
	draw_deck_beacon.position = Vector3(0.0, 0.015, 0.0)
	draw_deck_beacon.scale = Vector3(1.0, 0.35, 1.22)
	var db_mat := StandardMaterial3D.new()
	db_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	db_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	db_mat.albedo_color = Color(0.45, 0.94, 1.0, 0.85)
	draw_deck_beacon.material_override = db_mat
	draw_deck_beacon.visible = false
	draw_deck_root.add_child(draw_deck_beacon)

	# Opponent Tabletop Items (symmetrical Buckshot item display on far side of table)
	opp_table_items_root = Node3D.new()
	opp_table_items_root.name = "OppTableItemsRoot"
	opp_table_items_root.position = Vector3(0.0, 0.816, 0.0)
	add_child(opp_table_items_root)

	opp_phial_node = Node3D.new()
	opp_phial_node.name = "OppEmberPhial"
	opp_phial_node.position = Vector3(-0.62, 0.0, -0.68)
	opp_phial_node.scale = Vector3(0.92, 0.92, 0.92)
	opp_phial_node.set_meta("base_pos", opp_phial_node.position)
	opp_phial_node.set_meta("base_scale", opp_phial_node.scale)
	opp_phial_node.set_meta("prop_id", "opp_phial")
	RelicMesh.build_hellfire_phial_meshes(opp_phial_node)
	var op_area := Area3D.new()
	op_area.name = "OppPhialArea"
	op_area.set_meta("prop_id", "opp_phial")
	var op_col := CollisionShape3D.new()
	var op_box := BoxShape3D.new()
	op_box.size = Vector3(0.16, 0.22, 0.16)
	op_col.shape = op_box
	op_col.position = Vector3(0.0, 0.09, 0.0)
	op_area.add_child(op_col)
	opp_phial_node.add_child(op_area)
	var op_lbl := Label3D.new()
	op_lbl.name = "OppPhialTag"
	op_lbl.text = "EMBER VIAL"
	op_lbl.font = _get_font(true)
	op_lbl.font_size = 14
	op_lbl.outline_size = 4
	op_lbl.pixel_size = 0.0014
	op_lbl.modulate = Color(1.0, 0.62, 0.44)
	op_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	op_lbl.position = Vector3(0.0, 0.21, 0.0)
	opp_phial_node.add_child(op_lbl)
	opp_table_items_root.add_child(opp_phial_node)

	opp_relic_node = Node3D.new()
	opp_relic_node.name = "OppRelicTotem"
	opp_relic_node.position = Vector3(0.56, 0.0, -0.66)
	opp_relic_node.scale = Vector3(1.12, 1.12, 1.12)
	opp_relic_node.set_meta("base_pos", opp_relic_node.position)
	opp_relic_node.set_meta("base_scale", opp_relic_node.scale)
	opp_relic_node.set_meta("prop_id", "opp_relic")
	var or_mesh := RelicMesh.build_relic_3d_mesh("REL_ROYAL", Color(0.95, 0.34, 0.30))
	opp_relic_node.add_child(or_mesh)
	var or_area := Area3D.new()
	or_area.name = "OppRelicArea"
	or_area.set_meta("prop_id", "opp_relic")
	var or_col := CollisionShape3D.new()
	var or_box := BoxShape3D.new()
	or_box.size = Vector3(0.18, 0.22, 0.18)
	or_col.shape = or_box
	or_col.position = Vector3(0.0, 0.09, 0.0)
	or_area.add_child(or_col)
	opp_relic_node.add_child(or_area)
	var or_lbl := Label3D.new()
	or_lbl.name = "OppRelicTag"
	or_lbl.text = "RIVAL SIGIL"
	or_lbl.font = _get_font(true)
	or_lbl.font_size = 14
	or_lbl.outline_size = 4
	or_lbl.pixel_size = 0.0014
	or_lbl.modulate = Color(1.0, 0.78, 0.42)
	or_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	or_lbl.position = Vector3(0.0, 0.21, 0.0)
	opp_relic_node.add_child(or_lbl)
	opp_table_items_root.add_child(opp_relic_node)

	# 3D Odhadzovací balíček (zväčšený uprostred stola, kam lietajú zahrané 3D karty)
	discard_pile_root = Node3D.new()
	discard_pile_root.position = Vector3(0.14, 0.816, -0.02)
	discard_pile_root.scale = Vector3(1.38, 1.38, 1.38)
	discard_pile_root.set_meta("base_pos", discard_pile_root.position)
	discard_pile_root.set_meta("base_scale", discard_pile_root.scale)
	discard_pile_root.set_meta("prop_id", "discard")
	add_child(discard_pile_root)

	var disc_area := Area3D.new()
	disc_area.name = "DiscardPileArea"
	var d_col := CollisionShape3D.new()
	var d_box := BoxShape3D.new()
	d_box.size = Vector3(0.32, 0.12, 0.44)
	d_col.shape = d_box
	d_col.position = Vector3(0.0, 0.05, 0.0)
	disc_area.add_child(d_col)
	discard_pile_root.add_child(disc_area)

	discard_mist_fx_root = Node3D.new()
	discard_mist_fx_root.position = Vector3(0.14, 0.90, 0.02)
	discard_mist_fx_root.visible = false
	add_child(discard_mist_fx_root)
	var mp := CPUParticles3D.new()
	mp.amount = 28
	mp.lifetime = 1.05
	mp.local_coords = true
	var mq := QuadMesh.new(); mq.size = Vector2(0.11, 0.11)
	mp.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.albedo_texture = Fx.soft_tex()
	mm.vertex_color_use_as_albedo = true
	mp.material_override = mm
	var mgr := Gradient.new()
	mgr.set_color(0, Color(0.68, 0.80, 0.92, 0.0))
	mgr.add_point(0.30, Color(0.68, 0.80, 0.92, 0.72))
	mgr.set_color(1, Color(0.45, 0.56, 0.68, 0.0))
	mp.color_ramp = mgr
	mp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mp.emission_box_extents = Vector3(0.12, 0.04, 0.16)
	mp.direction = Vector3(0.0, 1.0, 0.0)
	mp.spread = 35.0
	mp.gravity = Vector3.ZERO
	mp.initial_velocity_min = 0.06
	mp.initial_velocity_max = 0.16
	discard_mist_fx_root.add_child(mp)

	# 3D Nápis platnej farby položene priamo na doske nad kôpkou (žiadne kolízie s pop-upmi!)
	table_suit_label3d = Label3D.new()
	table_suit_label3d.font = _get_font(true)
	table_suit_label3d.font_size = 24
	table_suit_label3d.outline_size = 6
	table_suit_label3d.pixel_size = 0.0020
	table_suit_label3d.rotation_degrees = Vector3(-78, 0, 0)
	table_suit_label3d.position = Vector3(0.14, 0.84, -0.44)
	add_child(table_suit_label3d)

	table_status_label3d = Label3D.new()
	table_status_label3d.font = _get_font(true)
	table_status_label3d.font_size = 18
	table_status_label3d.outline_size = 5
	table_status_label3d.pixel_size = 0.0018
	table_status_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	table_status_label3d.position = Vector3(0.0, 0.96, -0.62)
	add_child(table_status_label3d)

	# 3D Alchymistická banka na stole pre "Magický Puf"
	magic_puf_bottle = Node3D.new()
	magic_puf_bottle.position = Vector3(0.76, 0.815, 0.34)
	magic_puf_bottle.set_meta("base_pos", magic_puf_bottle.position)
	magic_puf_bottle.set_meta("base_scale", Vector3.ONE)
	magic_puf_bottle.set_meta("prop_id", "phial")
	add_child(magic_puf_bottle)

	RelicMesh.build_hellfire_phial_meshes(magic_puf_bottle)

	var puf_lbl := Label3D.new()
	puf_lbl.name = "PufLabel"
	puf_lbl.text = "IGNIS (20)"
	puf_lbl.font = _get_font(true)
	puf_lbl.font_size = 17
	puf_lbl.outline_size = 4
	puf_lbl.pixel_size = 0.0016
	puf_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	puf_lbl.position = Vector3(0, 0.205, 0)
	magic_puf_bottle.add_child(puf_lbl)

	var puf_area := Area3D.new()
	puf_area.name = "MagicPufArea"
	var puf_col := CollisionShape3D.new()
	var p_shape := BoxShape3D.new()
	p_shape.size = Vector3(0.18, 0.24, 0.18)
	puf_col.shape = p_shape
	puf_area.add_child(puf_col)
	magic_puf_bottle.add_child(puf_area)

# ============================================================================
# 3. OPROTI V TME: NEJASNNÝ ČIERNY OBRYS + OSVETLENÉ 3D RUKAVICE S KARTAMI
# ============================================================================
func _setup_opponent_shadow_and_hands() -> void:
	# Seated Boss Silhouette framed cleanly above cards + backlit by epoch rim light (zero rigging budget!)
	opp_silhouette_root = Node3D.new()
	opp_silhouette_root.position = Vector3(0.0, 0.86, -1.50)
	add_child(opp_silhouette_root)

	opp_ambient_fx_root = Node3D.new()
	opp_ambient_fx_root.position = Vector3(0.0, 0.82, -1.56)
	add_child(opp_ambient_fx_root)

	# 3D Hellfire Burning Aura around Rival Silhouette + Swirling Battle Mist on Discard Pile
	opp_fire_fx_root = Node3D.new()
	opp_fire_fx_root.position = Vector3(0.0, 0.92, -1.52)
	opp_fire_fx_root.visible = false
	add_child(opp_fire_fx_root)
	var fp := CPUParticles3D.new()
	fp.name = "FireParticles"
	fp.amount = 20
	fp.lifetime = 0.72
	fp.local_coords = true
	var fq := QuadMesh.new()
	fq.size = Vector2(0.045, 0.06)
	fp.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_texture = Fx.soft_tex()
	fm.vertex_color_use_as_albedo = true
	fp.material_override = fm
	var f_grad := Gradient.new()
	f_grad.set_color(0, Color(1.0, 0.88, 0.30, 0.92))
	f_grad.add_point(0.45, Color(1.0, 0.40, 0.08, 0.85))
	f_grad.set_color(1, Color(0.55, 0.08, 0.02, 0.0))
	fp.color_ramp = f_grad
	fp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fp.emission_box_extents = Vector3(0.18, 0.12, 0.10)
	fp.direction = Vector3.UP
	fp.spread = 24.0
	fp.gravity = Vector3(0.0, -0.6, 0.0)
	fp.initial_velocity_min = 0.55
	fp.initial_velocity_max = 1.25
	opp_fire_fx_root.add_child(fp)
	opp_fire_light = OmniLight3D.new()
	opp_fire_light.light_color = Color(1.0, 0.42, 0.10)
	opp_fire_light.light_energy = 0.0
	opp_fire_light.omni_range = 2.6
	opp_fire_fx_root.add_child(opp_fire_light)
	BlenderVfx.build_burn_crown_aura(opp_fire_fx_root)

	dark_silhouette_mat = ShaderMaterial.new()
	dark_silhouette_mat.shader = BOSS_SILHOUETTE_SHADER
	dark_silhouette_mat.set_shader_parameter("core_color", Color(0.015, 0.014, 0.022, 1.0))
	dark_silhouette_mat.set_shader_parameter("rim_color", Color(1.0, 0.66, 0.24, 1.0))
	dark_silhouette_mat.set_shader_parameter("rim_power", 2.5)
	dark_silhouette_mat.set_shader_parameter("rim_strength", 1.45)
	_build_opponent_silhouette_for_era("stredovek")

	# 3D Ruky súpera vystupujúce z tmy dopredu nad okraj stola pod svetlo lampy!
	opp_hands_anchor = Node3D.new()
	opp_hands_anchor.position = Vector3(0.0, 1.10, -0.90)
	add_child(opp_hands_anchor)

	opp_glove_left_mesh = _create_3d_glove_mesh(true)
	opp_glove_left_mesh.position = Vector3(-0.27, -0.04, -0.02)
	opp_glove_left_mesh.rotation_degrees = Vector3(18.0, 162.0, -14.0)
	opp_hands_anchor.add_child(opp_glove_left_mesh)

	opp_glove_right_mesh = _create_3d_glove_mesh(false)
	opp_glove_right_mesh.position = Vector3(0.27, -0.04, -0.02)
	opp_glove_right_mesh.rotation_degrees = Vector3(18.0, -162.0, 14.0)
	opp_hands_anchor.add_child(opp_glove_right_mesh)

func _add_dark_part(parent: Node3D, m: Mesh, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = m
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.material_override = dark_silhouette_mat
	parent.add_child(inst)
	return inst

func _spawn_boss_epoch_particles(era_id: String, accent_col: Color) -> void:
	if not is_instance_valid(opp_ambient_fx_root):
		return
	for ch in opp_ambient_fx_root.get_children():
		ch.queue_free()

	var count := 16
	var style_kind := "dust"
	if era_id == "prohibicia":
		style_kind = "smoke"
		count = 14
	elif era_id == "rim":
		style_kind = "ember"
		count = 16
	elif era_id == "stredovek":
		style_kind = "candle"
		count = 15
	elif era_id == "objavy":
		style_kind = "mist"
		count = 16

	for i in range(count):
		var pm := MeshInstance3D.new()
		var p_mat := StandardMaterial3D.new()
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var m_mesh := SphereMesh.new()
		if style_kind == "smoke":
			m_mesh.radius = randf_range(0.032, 0.068)
			m_mesh.height = m_mesh.radius * 1.8
			p_mat.albedo_color = Color(0.76, 0.72, 0.88, randf_range(0.16, 0.30))
			pm.position = Vector3(randf_range(-0.42, 0.42), randf_range(0.22, 0.96), randf_range(-0.14, 0.20))
		else:
			m_mesh.radius = randf_range(0.008, 0.017)
			m_mesh.height = m_mesh.radius * 2.0
			var c_mix := accent_col.lightened(0.25)
			p_mat.albedo_color = Color(c_mix.r, c_mix.g, c_mix.b, randf_range(0.42, 0.82))
			p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			pm.position = Vector3(randf_range(-0.76, 0.76), randf_range(0.08, 1.05), randf_range(-0.22, 0.24))
		pm.mesh = m_mesh
		pm.material_override = p_mat
		pm.set_meta("base_pos", pm.position)
		pm.set_meta("phase", randf_range(0.0, TAU))
		pm.set_meta("fx_kind", style_kind)
		pm.set_meta("rise_spd", randf_range(0.14, 0.34))
		opp_ambient_fx_root.add_child(pm)

func _get_opponent_visual_tier() -> int:
	if tutorial_mode:
		return 0
	var s_idx := int(active_stage_data.get("stage_idx", 0))
	var s_name := str(active_stage_data.get("stage_name", "")).to_upper()
	if s_idx >= 2 or active_endless_ante > 0 or "(BOSS)" in s_name or "FINAL BOSS" in s_name:
		return 2
	if s_idx == 1 or active_boss_mod != "":
		return 1
	return 0

func _build_sculpted_torso_mesh(w_chest: float, w_waist: float, w_hip: float, d_chest: float, d_waist: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 28
	var rings := 14
	var grid: Array = []
	for ri in range(rings + 1):
		var v := float(ri) / float(rings) # 0.0 bottom hem -> 1.0 shoulder top
		var y := v * height
		var rx: float
		var rz: float
		if v < 0.35:
			var u := smoothstep(0.0, 0.35, v)
			rx = lerpf(w_hip, w_waist, u)
			rz = lerpf(d_waist * 1.12, d_waist, u)
		elif v < 0.86:
			var u := smoothstep(0.35, 0.86, v)
			rx = lerpf(w_waist, w_chest, u)
			rz = lerpf(d_waist, d_chest, u)
		else:
			var u := smoothstep(0.86, 1.0, v)
			rx = lerpf(w_chest, w_chest * 0.44, u * u)
			rz = lerpf(d_chest, d_chest * 0.54, u * u)
		var row: Array = []
		for si in range(segs + 1):
			var u_ang := float(si) / float(segs)
			var ang := u_ang * TAU
			var front := maxf(0.0, sin(ang))
			var pec := front * sin(smoothstep(0.45, 0.85, v) * PI) * 0.018
			var fold := sin(ang * 6.0) * 0.005 * (1.0 - v * 0.6)
			var px := cos(ang) * (rx + fold)
			var pz := sin(ang) * (rz + pec)
			row.append({"pos": Vector3(px, y, pz), "uv": Vector2(u_ang, 1.0 - v)})
		grid.append(row)
	for ri in range(rings):
		var r0: Array = grid[ri]
		var r1: Array = grid[ri + 1]
		for si in range(segs):
			var a: Dictionary = r0[si]
			var b: Dictionary = r0[si + 1]
			var c: Dictionary = r1[si]
			var d: Dictionary = r1[si + 1]
			for tri in [[a, b, c], [b, d, c]]:
				for vert in tri:
					st.set_uv(vert["uv"])
					st.add_vertex(vert["pos"])
	st.index()
	st.generate_normals()
	return st.commit()

func _build_opponent_silhouette_for_era(era_id: String) -> void:
	if not opp_silhouette_root:
		return
	_has_sculpted_opp_glb = false
	for ch in opp_silhouette_root.get_children():
		ch.queue_free()

	# Configure Epoch Rim Color & Backlight SpotLight (intensified for Campaign Bosses!)
	var rim_col := Color(1.0, 0.66, 0.22)
	match era_id:
		"antika":
			rim_col = Color(1.0, 0.80, 0.24)
		"rim":
			rim_col = Color(0.98, 0.32, 0.22)
		"stredovek":
			rim_col = Color(1.0, 0.62, 0.20)
		"objavy":
			rim_col = Color(0.26, 0.88, 0.98)
		"prohibicia":
			rim_col = Color(0.76, 0.42, 1.0)
	var v_tier := _get_opponent_visual_tier()
	if is_instance_valid(boss_rim_light):
		boss_rim_light.light_color = rim_col
		boss_rim_light.light_energy = 6.2 if v_tier >= 2 else (4.6 if v_tier == 1 else 3.4)
	_build_detailed_opponent_character(era_id, rim_col)
	_spawn_boss_epoch_particles(era_id, rim_col)
	_ensure_boss_stone_plaque_3d()

func _ensure_boss_stone_plaque_3d() -> void:
	if is_instance_valid(boss_plaque_root):
		_refresh_boss_stone_plaque_3d()
		return
	boss_plaque_root = Node3D.new()
	boss_plaque_root.position = Vector3(0.62, 0.825, -0.58)
	boss_plaque_root.rotation_degrees = Vector3(-28.0, -24.0, 0.0)
	add_child(boss_plaque_root)

	var slab_mat := Toon.mat(Color(0.14, 0.12, 0.15), "res://assets/table/stone_floor.png", 0.006, Vector2(1.5, 1.5), Color(0.06, 0.02, 0.04))
	var brass_mat := Toon.mat(Color(0.84, 0.64, 0.24), "", 0.004, Vector2.ONE, Color(0.22, 0.14, 0.04))

	var slab := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(0.42, 0.22, 0.028)
	slab.mesh = sbox
	slab.position = Vector3(0.0, 0.10, 0.0)
	slab.material_override = slab_mat
	boss_plaque_root.add_child(slab)

	var bevel := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(0.44, 0.24, 0.018)
	bevel.mesh = bbox
	bevel.position = Vector3(0.0, 0.10, -0.006)
	bevel.material_override = brass_mat
	boss_plaque_root.add_child(bevel)

	for sx in [-0.19, 0.19]:
		for sy in [0.01, 0.19]:
			var stud := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.012
			sp.height = 0.020
			stud.mesh = sp
			stud.position = Vector3(sx, sy, 0.015)
			stud.material_override = brass_mat
			boss_plaque_root.add_child(stud)

	boss_plaque_rune_3d = Label3D.new()
	boss_plaque_rune_3d.text = ""
	boss_plaque_rune_3d.font = _get_font(true)
	boss_plaque_rune_3d.font_size = 26
	boss_plaque_rune_3d.outline_size = 6
	boss_plaque_rune_3d.pixel_size = 0.0014
	boss_plaque_rune_3d.modulate = Color(1.0, 0.42, 0.36)
	boss_plaque_rune_3d.position = Vector3(-0.155, 0.162, 0.018)
	boss_plaque_root.add_child(boss_plaque_rune_3d)

	boss_plaque_title_3d = Label3D.new()
	boss_plaque_title_3d.text = "BOSS EDICT"
	boss_plaque_title_3d.font = _get_font(true)
	boss_plaque_title_3d.font_size = 18
	boss_plaque_title_3d.outline_size = 6
	boss_plaque_title_3d.pixel_size = 0.00125
	boss_plaque_title_3d.modulate = Color(1.0, 0.86, 0.42)
	boss_plaque_title_3d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	boss_plaque_title_3d.position = Vector3(-0.120, 0.162, 0.018)
	boss_plaque_root.add_child(boss_plaque_title_3d)

	boss_plaque_desc_3d = Label3D.new()
	boss_plaque_desc_3d.text = ""
	boss_plaque_desc_3d.font = _get_font(false)
	boss_plaque_desc_3d.font_size = 14
	boss_plaque_desc_3d.outline_size = 5
	boss_plaque_desc_3d.pixel_size = 0.00105
	boss_plaque_desc_3d.modulate = Color(0.95, 0.88, 0.78)
	boss_plaque_desc_3d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_plaque_desc_3d.width = 340.0
	boss_plaque_desc_3d.position = Vector3(0.0, 0.082, 0.018)
	boss_plaque_root.add_child(boss_plaque_desc_3d)

	var p_area := Area3D.new()
	p_area.name = "BossPlaqueArea"
	var p_col := CollisionShape3D.new()
	var p_shape := BoxShape3D.new()
	p_shape.size = Vector3(0.46, 0.26, 0.08)
	p_col.shape = p_shape
	p_col.position = Vector3(0.0, 0.10, 0.0)
	p_area.add_child(p_col)
	boss_plaque_root.add_child(p_area)
	_refresh_boss_stone_plaque_3d()

func _refresh_boss_stone_plaque_3d() -> void:
	if not is_instance_valid(boss_plaque_root):
		return
	var has_mod := (not tutorial_mode) and active_boss_mod != ""
	boss_plaque_root.visible = has_mod
	if is_instance_valid(boss_sigil_halo):
		boss_sigil_halo.visible = has_mod or (_get_opponent_visual_tier() >= 1)
	if has_mod:
		if boss_plaque_title_3d:
			boss_plaque_title_3d.text = active_boss_mod.replace("_", " ")
		if boss_plaque_desc_3d:
			boss_plaque_desc_3d.text = _get_boss_desc_loc()

func _trigger_boss_recoil_stagger(intense: bool = false) -> void:
	opp_recoil_time = maxf(opp_recoil_time, 0.82 if intense else 0.48)
	opp_shake_time = maxf(opp_shake_time, 0.65 if intense else 0.42)
	chandelier_sway_boost = minf(2.5, chandelier_sway_boost + (1.4 if intense else 0.75))
	if is_instance_valid(opp_silhouette_root):
		var plume_pos := opp_silhouette_root.global_position + Vector3(0.0, 0.56, 0.18)
		Fx.ink_splat(self, plume_pos, 24 if intense else 14, 1.35 if intense else 0.95)
		Fx.burst(self, plume_pos, Color(0.18, 0.12, 0.22), 22 if intense else 12, 1.15, 0.68, 0.065, -0.6, false, 150.0, Vector3.UP, false)
		if intense:
			Fx.embers(self, plume_pos, 26, 1.15)

func _trigger_boss_modifier_flare(reason_txt: String = "") -> void:
	boss_flare_time = 0.95
	emit_signal("play_sfx_pitched_requested", "boss_omen", 1.0)
	if is_instance_valid(opp_silhouette_root):
		var flare_pos := opp_silhouette_root.global_position + Vector3(0.0, 0.68, 0.14)
		Fx.ring(self, flare_pos, Color(1.0, 0.28, 0.24), 0.52, 0.40, 0.11, 1.85, 8.0)
		Fx.burst(self, flare_pos, Color(1.0, 0.34, 0.24), 18, 1.25, 0.50, 0.032, 1.2, true, 160.0, Vector3.UP, true)
	if is_instance_valid(boss_plaque_root) and boss_plaque_root.visible:
		var ptw := boss_plaque_root.create_tween()
		ptw.tween_property(boss_plaque_root, "scale", Vector3(1.18, 1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptw.tween_property(boss_plaque_root, "scale", Vector3.ONE, 0.22)
	if reason_txt != "":
		_show_stagger_callout("" + reason_txt, Color(1.0, 0.42, 0.36), 1.24)

func _create_3d_glove_mesh(is_right: bool = false) -> Node3D:
	# Detailne prepracovaná anatomická 3D rukavica s kĺbovou artikuláciou (zápästie, 3-článkový palec, 4× 3-článkové prsty,
	# svalové vankúšiky dlane thenar/hypothenar, chrbtové šľachy, vrstvená manžeta s remienkami, prackami a mosadznými nitmi)
	var root := Node3D.new()
	var side := 1.0 if is_right else -1.0
	var g_mat := Toon.mat(Color(0.46, 0.30, 0.18), "res://assets/gloves/glove_leather.png", 0.0022)
	var strap_mat := Toon.mat(Color(0.27, 0.17, 0.11), "res://assets/gloves/glove_leather.png", 0.0018)
	var sleeve_mat := Toon.mat(Color(0.16, 0.13, 0.15), "res://assets/table/felt.png", 0.003)
	var brass_mat := Toon.mat(Color(0.84, 0.64, 0.24), "", 0.0016)

	# 1. Prešívaný podkladový rukáv predlaktia
	var sleeve := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.034
	scyl.bottom_radius = 0.049
	scyl.height = 0.21
	scyl.radial_segments = 18
	sleeve.mesh = scyl
	sleeve.position = Vector3(side * 0.017, -0.030, 0.158)
	sleeve.rotation_degrees = Vector3(77.0, -side * 7.5, 0.0)
	sleeve.material_override = sleeve_mat
	sleeve.set_meta("part_role", "sleeve")
	root.add_child(sleeve)

	# 2. Vrstvená zvonová kožená manžeta rukavice s lemom, chrbtovým chráničom, remienkami a prackami
	var cuff_bell := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.039
	cmesh.bottom_radius = 0.052
	cmesh.height = 0.088
	cmesh.radial_segments = 18
	cuff_bell.mesh = cmesh
	cuff_bell.position = Vector3(side * 0.008, -0.014, 0.084)
	cuff_bell.rotation_degrees = Vector3(78.0, -side * 5.0, 0.0)
	cuff_bell.material_override = g_mat
	cuff_bell.set_meta("part_role", "glove")
	root.add_child(cuff_bell)

	var cuff_rim := MeshInstance3D.new()
	var rtor := TorusMesh.new()
	rtor.inner_radius = 0.044
	rtor.outer_radius = 0.055
	rtor.rings = 18
	rtor.ring_segments = 10
	cuff_rim.mesh = rtor
	cuff_rim.position = Vector3(side * 0.011, -0.023, 0.125)
	cuff_rim.rotation_degrees = Vector3(78.0, -side * 5.0, 0.0)
	cuff_rim.material_override = strap_mat
	cuff_rim.set_meta("part_role", "strap")
	root.add_child(cuff_rim)

	var cuff_plate := MeshInstance3D.new()
	var cp_cap := CapsuleMesh.new()
	cp_cap.radius = 0.024
	cp_cap.height = 0.082
	cuff_plate.mesh = cp_cap
	cuff_plate.position = Vector3(side * 0.010, -0.025, 0.082)
	cuff_plate.rotation_degrees = Vector3(78.0, -side * 5.0, 0.0)
	cuff_plate.scale = Vector3(1.15, 0.42, 1.0)
	cuff_plate.material_override = g_mat
	cuff_plate.set_meta("part_role", "glove")
	root.add_child(cuff_plate)

	for s_i in range(2):
		var z_off := 0.049 + float(s_i) * 0.036
		var y_off := -0.007 - float(s_i) * 0.008
		var r_base := 0.040 + float(s_i) * 0.006
		var strap := MeshInstance3D.new()
		var stor := TorusMesh.new()
		stor.inner_radius = r_base - 0.004
		stor.outer_radius = r_base + 0.005
		stor.rings = 16
		stor.ring_segments = 8
		strap.mesh = stor
		strap.position = Vector3(side * (0.005 + float(s_i) * 0.003), y_off, z_off)
		strap.rotation_degrees = Vector3(78.0, -side * 5.0, 0.0)
		strap.material_override = strap_mat
		strap.set_meta("part_role", "strap")
		root.add_child(strap)

		var buckle := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(0.007, 0.014, 0.016)
		buckle.mesh = b_box
		buckle.position = Vector3(side * (r_base + 0.004), y_off + 0.002, z_off)
		buckle.rotation_degrees = Vector3(12.0, 0.0, -side * 15.0)
		buckle.material_override = brass_mat
		buckle.set_meta("part_role", "metal")
		root.add_child(buckle)

		var clasp := MeshInstance3D.new()
		var csph := SphereMesh.new()
		csph.radius = 0.0065
		csph.height = 0.011
		clasp.mesh = csph
		clasp.position = Vector3(-side * (r_base - 0.002), y_off + 0.006, z_off)
		clasp.material_override = brass_mat
		clasp.set_meta("part_role", "metal")
		root.add_child(clasp)

	# 3. Artikulovaný kĺb zápästia (wrist_pivot) nesúci celú dlaň, palec a prsty
	var wrist_pivot := Node3D.new()
	wrist_pivot.position = Vector3(0.0, -0.004, 0.036)
	root.add_child(wrist_pivot)

	var wrist_carpal := MeshInstance3D.new()
	var w_sph := SphereMesh.new()
	w_sph.radius = 0.031
	w_sph.height = 0.058
	wrist_carpal.mesh = w_sph
	wrist_carpal.scale = Vector3(1.14, 0.66, 0.92)
	wrist_carpal.material_override = strap_mat
	wrist_carpal.set_meta("part_role", "strap")
	wrist_pivot.add_child(wrist_carpal)

	# 4. Anatomicky tvarovaná dlaň (Metacarpal core + Thenar sval palca + Hypothenar vonkajší oblúk + kožená výstuha)
	var palm_core := MeshInstance3D.new()
	var pcap := CapsuleMesh.new()
	pcap.radius = 0.031
	pcap.height = 0.086
	palm_core.mesh = pcap
	palm_core.position = Vector3(0.0, -0.003, -0.035)
	palm_core.rotation_degrees = Vector3(85.0, 0.0, 90.0)
	palm_core.scale = Vector3(1.04, 0.56, 1.08)
	palm_core.material_override = g_mat
	palm_core.set_meta("part_role", "glove")
	wrist_pivot.add_child(palm_core)

	var hypothenar := MeshInstance3D.new()
	var h_cap := CapsuleMesh.new()
	h_cap.radius = 0.018
	h_cap.height = 0.068
	hypothenar.mesh = h_cap
	hypothenar.position = Vector3(side * 0.024, -0.001, -0.036)
	hypothenar.rotation_degrees = Vector3(84.0, -side * 10.0, side * 8.0)
	hypothenar.scale = Vector3(0.95, 0.68, 1.0)
	hypothenar.material_override = g_mat
	hypothenar.set_meta("part_role", "glove")
	wrist_pivot.add_child(hypothenar)

	var thenar_mound := MeshInstance3D.new()
	var tm_cap := CapsuleMesh.new()
	tm_cap.radius = 0.019
	tm_cap.height = 0.056
	thenar_mound.mesh = tm_cap
	thenar_mound.position = Vector3(-side * 0.023, 0.008, -0.026)
	thenar_mound.rotation_degrees = Vector3(72.0, side * 26.0, side * 16.0)
	thenar_mound.scale = Vector3(1.0, 0.76, 1.0)
	thenar_mound.material_override = g_mat
	thenar_mound.set_meta("part_role", "glove")
	wrist_pivot.add_child(thenar_mound)

	var palm_grip_pad := MeshInstance3D.new()
	var pg_cap := CapsuleMesh.new()
	pg_cap.radius = 0.021
	pg_cap.height = 0.056
	palm_grip_pad.mesh = pg_cap
	palm_grip_pad.position = Vector3(-side * 0.003, 0.012, -0.037)
	palm_grip_pad.rotation_degrees = Vector3(86.0, 0.0, 90.0)
	palm_grip_pad.scale = Vector3(0.96, 0.30, 0.94)
	palm_grip_pad.material_override = strap_mat
	palm_grip_pad.set_meta("part_role", "strap")
	wrist_pivot.add_child(palm_grip_pad)

	# Chrbtový pancier/kožený plát ruky + 4 šľachové rebrá a mosadzné nity
	var dorsal_plate := MeshInstance3D.new()
	var dp_cap := CapsuleMesh.new()
	dp_cap.radius = 0.026
	dp_cap.height = 0.072
	dorsal_plate.mesh = dp_cap
	dorsal_plate.position = Vector3(0.0, -0.016, -0.034)
	dorsal_plate.rotation_degrees = Vector3(85.0, 0.0, 90.0)
	dorsal_plate.scale = Vector3(1.0, 0.34, 0.96)
	dorsal_plate.material_override = strap_mat
	dorsal_plate.set_meta("part_role", "strap")
	wrist_pivot.add_child(dorsal_plate)

	var finger_xs := [-0.027, -0.009, 0.009, 0.026]
	for t_i in range(4):
		var tendon := MeshInstance3D.new()
		var td_cap := CapsuleMesh.new()
		td_cap.radius = 0.0030
		td_cap.height = 0.044
		tendon.mesh = td_cap
		tendon.position = Vector3(finger_xs[t_i] * side * 0.88, -0.020, -0.038)
		tendon.rotation_degrees = Vector3(87.0, side * (-2.0 + float(t_i) * 1.5), 0.0)
		tendon.material_override = g_mat
		tendon.set_meta("part_role", "glove")
		wrist_pivot.add_child(tendon)

	for r_i in range(3):
		var d_rivet := MeshInstance3D.new()
		var dr_sph := SphereMesh.new()
		dr_sph.radius = 0.0042
		dr_sph.height = 0.007
		d_rivet.mesh = dr_sph
		d_rivet.position = Vector3((float(r_i) - 1.0) * 0.017 * side, -0.021, -0.018)
		d_rivet.material_override = brass_mat
		d_rivet.set_meta("part_role", "metal")
		wrist_pivot.add_child(d_rivet)

	# 5. Trojčlánkový artikulovaný palec (CMC základňa -> MCP článok -> IP špička s nechtovým sedlom)
	var thumb_pivot := Node3D.new()
	var th_base_rot := Vector3(-10.0, side * 30.0, side * 12.0)
	thumb_pivot.position = Vector3(-side * 0.033, 0.011, -0.030)
	thumb_pivot.rotation_degrees = th_base_rot
	thumb_pivot.set_meta("base_rot", th_base_rot)
	wrist_pivot.add_child(thumb_pivot)

	var th_cmc := MeshInstance3D.new()
	var cmc_sph := SphereMesh.new()
	cmc_sph.radius = 0.0135
	cmc_sph.height = 0.025
	th_cmc.mesh = cmc_sph
	th_cmc.material_override = g_mat
	th_cmc.set_meta("part_role", "glove")
	thumb_pivot.add_child(th_cmc)

	var th1 := MeshInstance3D.new()
	var tc1 := CapsuleMesh.new()
	tc1.radius = 0.0122
	tc1.height = 0.036
	th1.mesh = tc1
	th1.rotation_degrees.x = 90.0
	th1.position = Vector3(0.0, 0.0, -0.014)
	th1.material_override = g_mat
	th1.set_meta("part_role", "glove")
	thumb_pivot.add_child(th1)

	var th_mcp_pivot := Node3D.new()
	var th_mcp_rot := Vector3(14.0, -side * 12.0, 0.0)
	th_mcp_pivot.position = Vector3(0.0, 0.001, -0.027)
	th_mcp_pivot.rotation_degrees = th_mcp_rot
	th_mcp_pivot.set_meta("base_rot", th_mcp_rot)
	thumb_pivot.add_child(th_mcp_pivot)

	var th_kn1 := MeshInstance3D.new()
	var tks1 := SphereMesh.new()
	tks1.radius = 0.0115
	tks1.height = 0.021
	th_kn1.mesh = tks1
	th_kn1.material_override = strap_mat
	th_kn1.set_meta("part_role", "strap")
	th_mcp_pivot.add_child(th_kn1)

	var th2 := MeshInstance3D.new()
	var tc2 := CapsuleMesh.new()
	tc2.radius = 0.0108
	tc2.height = 0.030
	th2.mesh = tc2
	th2.rotation_degrees.x = 90.0
	th2.position = Vector3(0.0, 0.0, -0.012)
	th2.material_override = g_mat
	th2.set_meta("part_role", "glove")
	th_mcp_pivot.add_child(th2)

	var th_ip_pivot := Node3D.new()
	var th_ip_rot := Vector3(18.0, -side * 8.0, 0.0)
	th_ip_pivot.position = Vector3(0.0, 0.001, -0.022)
	th_ip_pivot.rotation_degrees = th_ip_rot
	th_ip_pivot.set_meta("base_rot", th_ip_rot)
	th_mcp_pivot.add_child(th_ip_pivot)

	var th3 := MeshInstance3D.new()
	var tc3 := CapsuleMesh.new()
	tc3.radius = 0.0094
	tc3.height = 0.024
	th3.mesh = tc3
	th3.rotation_degrees.x = 90.0
	th3.position = Vector3(0.0, 0.0, -0.009)
	th3.material_override = g_mat
	th3.set_meta("part_role", "glove")
	th_ip_pivot.add_child(th3)

	var th_tip := MeshInstance3D.new()
	var t_nail := BoxMesh.new()
	t_nail.size = Vector3(0.011, 0.004, 0.011)
	th_tip.mesh = t_nail
	th_tip.position = Vector3(0.0, -0.006, -0.012)
	th_tip.rotation_degrees.x = -8.0
	th_tip.material_override = strap_mat
	th_tip.set_meta("part_role", "strap")
	th_ip_pivot.add_child(th_tip)

	# 6. Štyri 3-článkové prsty (Index, Middle, Ring, Pinky) s kĺbmi MCP, PIP, DIP a chráničmi hánok
	var finger_zs := [-0.071, -0.075, -0.072, -0.065]
	var finger_ys := [-0.008, -0.010, -0.009, -0.005]
	var finger_lens := [0.056, 0.063, 0.058, 0.047]
	var finger_radii := [0.0098, 0.0104, 0.0096, 0.0084]
	var mcp_pivots: Array[Node3D] = []
	var pip_pivots: Array[Node3D] = []
	var dip_pivots: Array[Node3D] = []

	for fi in range(4):
		var r0: float = finger_radii[fi]
		var flen: float = finger_lens[fi]
		var l1 := flen * 0.45
		var l2 := flen * 0.32
		var l3 := flen * 0.24

		var kn_boss := MeshInstance3D.new()
		var kb_sph := SphereMesh.new()
		kb_sph.radius = r0 * 1.18
		kb_sph.height = r0 * 2.2
		kn_boss.mesh = kb_sph
		kn_boss.position = Vector3(finger_xs[fi] * side, finger_ys[fi], finger_zs[fi])
		kn_boss.material_override = g_mat
		kn_boss.set_meta("part_role", "glove")
		wrist_pivot.add_child(kn_boss)

		var kn_stud := MeshInstance3D.new()
		var ks_sph := SphereMesh.new()
		ks_sph.radius = r0 * 0.62
		ks_sph.height = r0 * 1.0
		kn_stud.mesh = ks_sph
		kn_stud.position = Vector3(finger_xs[fi] * side, finger_ys[fi] - r0 * 0.85, finger_zs[fi] + 0.002)
		kn_stud.material_override = brass_mat
		kn_stud.set_meta("part_role", "metal")
		wrist_pivot.add_child(kn_stud)

		var mcp := Node3D.new()
		var mcp_rot := Vector3(15.0 + float(fi) * 2.4, side * (-4.5 + float(fi) * 3.6), 0.0)
		mcp.position = Vector3(finger_xs[fi] * side, finger_ys[fi], finger_zs[fi])
		mcp.rotation_degrees = mcp_rot
		mcp.set_meta("base_rot", mcp_rot)
		wrist_pivot.add_child(mcp)
		mcp_pivots.append(mcp)

		var seg1 := MeshInstance3D.new()
		var sc1 := CapsuleMesh.new()
		sc1.radius = r0
		sc1.height = l1 + r0 * 1.4
		seg1.mesh = sc1
		seg1.rotation_degrees.x = 90.0
		seg1.position = Vector3(0.0, 0.0, -l1 * 0.5)
		seg1.material_override = g_mat
		seg1.set_meta("part_role", "glove")
		mcp.add_child(seg1)

		var pip := Node3D.new()
		var pip_rot := Vector3(24.0 + float(fi) * 1.8, 0.0, 0.0)
		pip.position = Vector3(0.0, 0.0, -l1)
		pip.rotation_degrees = pip_rot
		pip.set_meta("base_rot", pip_rot)
		mcp.add_child(pip)
		pip_pivots.append(pip)

		var pip_joint := MeshInstance3D.new()
		var pj_sph := SphereMesh.new()
		pj_sph.radius = r0 * 0.94
		pj_sph.height = r0 * 1.75
		pip_joint.mesh = pj_sph
		pip_joint.material_override = strap_mat
		pip_joint.set_meta("part_role", "strap")
		pip.add_child(pip_joint)

		var seg2 := MeshInstance3D.new()
		var sc2 := CapsuleMesh.new()
		sc2.radius = r0 * 0.88
		sc2.height = l2 + r0 * 1.2
		seg2.mesh = sc2
		seg2.rotation_degrees.x = 90.0
		seg2.position = Vector3(0.0, 0.0, -l2 * 0.5)
		seg2.material_override = g_mat
		seg2.set_meta("part_role", "glove")
		pip.add_child(seg2)

		var dip := Node3D.new()
		var dip_rot := Vector3(18.0 + float(fi) * 1.2, 0.0, 0.0)
		dip.position = Vector3(0.0, 0.0, -l2)
		dip.rotation_degrees = dip_rot
		dip.set_meta("base_rot", dip_rot)
		pip.add_child(dip)
		dip_pivots.append(dip)

		var dip_joint := MeshInstance3D.new()
		var dj_sph := SphereMesh.new()
		dj_sph.radius = r0 * 0.80
		dj_sph.height = r0 * 1.5
		dip_joint.mesh = dj_sph
		dip_joint.material_override = strap_mat
		dip_joint.set_meta("part_role", "strap")
		dip.add_child(dip_joint)

		var seg3 := MeshInstance3D.new()
		var sc3 := CapsuleMesh.new()
		sc3.radius = r0 * 0.76
		sc3.height = l3 + r0 * 1.0
		seg3.mesh = sc3
		seg3.rotation_degrees.x = 90.0
		seg3.position = Vector3(0.0, 0.0, -l3 * 0.5)
		seg3.material_override = g_mat
		seg3.set_meta("part_role", "glove")
		dip.add_child(seg3)

		var nail_cap := MeshInstance3D.new()
		var nc_box := BoxMesh.new()
		nc_box.size = Vector3(r0 * 1.05, r0 * 0.34, l3 * 0.58)
		nail_cap.mesh = nc_box
		nail_cap.position = Vector3(0.0, -r0 * 0.52, -l3 * 0.62)
		nail_cap.rotation_degrees.x = -6.0
		nail_cap.material_override = strap_mat
		nail_cap.set_meta("part_role", "strap")
		dip.add_child(nail_cap)

	root.set_meta("is_right", is_right)
	root.set_meta("wrist_pivot", wrist_pivot)
	root.set_meta("thumb_pivot", thumb_pivot)
	root.set_meta("thumb_mcp", th_mcp_pivot)
	root.set_meta("thumb_ip", th_ip_pivot)
	root.set_meta("mcp_pivots", mcp_pivots)
	root.set_meta("pip_pivots", pip_pivots)
	root.set_meta("dip_pivots", dip_pivots)
	return root

func _animate_3d_hand_rig(hand_root: Node3D, t: float, grip_curl: float, flick_open: float, pinch_amt: float, drum_speed: float, delta: float) -> void:
	if not is_instance_valid(hand_root) or not hand_root.has_meta("wrist_pivot"):
		return
	var is_right := bool(hand_root.get_meta("is_right", false))
	var side := 1.0 if is_right else -1.0
	var rate := clampf(11.0 * delta, 0.0, 1.0)

	var wrist_pivot := hand_root.get_meta("wrist_pivot") as Node3D
	if is_instance_valid(wrist_pivot):
		var w_pitch := sin(t * 2.1 + side * 0.6) * 2.6 + grip_curl * 8.0 - flick_open * 22.0 + pinch_amt * 5.0
		var w_yaw := cos(t * 1.7 + side) * 2.0 * side + pinch_amt * (-7.0 * side)
		var w_roll := sin(t * 1.9) * 2.4 * side - flick_open * 10.0 * side
		wrist_pivot.rotation_degrees = wrist_pivot.rotation_degrees.lerp(Vector3(w_pitch, w_yaw, w_roll), rate)

	var thumb_pivot := hand_root.get_meta("thumb_pivot") as Node3D
	var thumb_mcp := hand_root.get_meta("thumb_mcp") as Node3D
	var thumb_ip := hand_root.get_meta("thumb_ip") as Node3D
	if is_instance_valid(thumb_pivot):
		var tb: Vector3 = thumb_pivot.get_meta("base_rot", Vector3.ZERO)
		var th_target := tb + Vector3(
			sin(t * 2.3 + side) * 2.2 + pinch_amt * 10.0 + grip_curl * 6.0 - flick_open * 16.0,
			side * (pinch_amt * 9.0 - flick_open * 14.0),
			side * (pinch_amt * 6.0)
		)
		thumb_pivot.rotation_degrees = thumb_pivot.rotation_degrees.lerp(th_target, rate)
	if is_instance_valid(thumb_mcp):
		var tmb: Vector3 = thumb_mcp.get_meta("base_rot", Vector3.ZERO)
		thumb_mcp.rotation_degrees = thumb_mcp.rotation_degrees.lerp(
			tmb + Vector3(pinch_amt * 14.0 + grip_curl * 8.0 - flick_open * 18.0, 0.0, 0.0), rate)
	if is_instance_valid(thumb_ip):
		var tib: Vector3 = thumb_ip.get_meta("base_rot", Vector3.ZERO)
		thumb_ip.rotation_degrees = thumb_ip.rotation_degrees.lerp(
			tib + Vector3(pinch_amt * 16.0 + grip_curl * 10.0 - flick_open * 16.0, 0.0, 0.0), rate)

	var mcp_pivots: Array = hand_root.get_meta("mcp_pivots", [])
	var pip_pivots: Array = hand_root.get_meta("pip_pivots", [])
	var dip_pivots: Array = hand_root.get_meta("dip_pivots", [])
	for fi in range(mcp_pivots.size()):
		var drum_wave := sin(t * drum_speed + float(fi) * 1.15 + side * 0.8) * (4.2 if drum_speed > 3.2 else 2.6)
		var index_pinch := pinch_amt * (14.0 if fi == 0 else (8.0 if fi == 1 else 2.0))
		var curl_add := drum_wave + grip_curl * (14.0 + float(fi) * 2.0) + index_pinch - flick_open * (28.0 - float(fi) * 2.5)
		var spread_add := side * (float(fi) - 1.5) * (flick_open * 7.5 - grip_curl * 2.0)

		var mcp := mcp_pivots[fi] as Node3D
		if is_instance_valid(mcp):
			var mb: Vector3 = mcp.get_meta("base_rot", Vector3.ZERO)
			mcp.rotation_degrees = mcp.rotation_degrees.lerp(mb + Vector3(curl_add * 0.65, spread_add, 0.0), rate)
		if fi < pip_pivots.size():
			var pip := pip_pivots[fi] as Node3D
			if is_instance_valid(pip):
				var pb: Vector3 = pip.get_meta("base_rot", Vector3.ZERO)
				pip.rotation_degrees = pip.rotation_degrees.lerp(pb + Vector3(curl_add * 0.85, 0.0, 0.0), rate)
		if fi < dip_pivots.size():
			var dip := dip_pivots[fi] as Node3D
			if is_instance_valid(dip):
				var db: Vector3 = dip.get_meta("base_rot", Vector3.ZERO)
				dip.rotation_degrees = dip.rotation_degrees.lerp(db + Vector3(curl_add * 0.55, 0.0, 0.0), rate)

func _apply_hand_materials(hand_root: Node3D, glove_mat: Material, sleeve_mat: Material, metal_mat: Material, strap_mat: Material = null) -> void:
	if not hand_root:
		return
	var eff_strap := strap_mat
	if eff_strap == null:
		if glove_mat is ShaderMaterial:
			var sm := (glove_mat as ShaderMaterial).duplicate() as ShaderMaterial
			var base_alb: Variant = sm.get_shader_parameter("albedo")
			if base_alb is Color:
				sm.set_shader_parameter("albedo", (base_alb as Color).darkened(0.36))
			eff_strap = sm
		else:
			eff_strap = sleeve_mat
	for ch in hand_root.get_children():
		if ch is MeshInstance3D:
			var role := str(ch.get_meta("part_role", "glove"))
			if role == "sleeve":
				ch.material_override = sleeve_mat
			elif role == "metal":
				ch.material_override = metal_mat
			elif role == "strap":
				ch.material_override = eff_strap
			else:
				ch.material_override = glove_mat
		elif ch is Node3D:
			_apply_hand_materials(ch, glove_mat, sleeve_mat, metal_mat, eff_strap)

func _build_3d_sword_mesh(skin_id: String) -> Node3D:
	var sk := Catalog.get_sword_skin(skin_id)
	var glb_root := RelicMesh.build_sword_3d_mesh(skin_id, sk)
	if glb_root.get_meta("blender_glb", false):
		return glb_root
	var root := Node3D.new()
	var glow: Color = sk.get("glow_col", Color.BLACK)
	var blade_col: Color = sk.get("blade_col", Color(0.7, 0.72, 0.78))
	var guard_col: Color = sk.get("guard_col", Color(0.66, 0.50, 0.20))
	var grip_col: Color = sk.get("grip_col", Color(0.32, 0.19, 0.11))

	var blade_mat := Toon.pbr(blade_col, "", 0.22, 0.88, Vector2.ONE, glow * 0.35, 1.0)
	var edge_mat := Toon.pbr(blade_col.lightened(0.22), "", 0.16, 0.78, Vector2.ONE, glow * 0.90, 1.4)
	var guard_mat := Toon.pbr(guard_col, "", 0.28, 0.86, Vector2.ONE, guard_col * 0.16, 1.0)
	var grip_mat := Toon.pbr(grip_col, "res://assets/gloves/glove_leather.png", 0.74, 0.06)
	var gem_mat := Toon.pbr(sk.get("trail_col", Color.GOLD), "", 0.10, 0.20, Vector2.ONE, glow * 1.4, 1.8)

	var sword_glb := _load_glb_model("res://assets/models/sword_oath.glb", true)
	if sword_glb:
		sword_glb.name = "SwordOathGLB"
		_apply_mat_by_mesh_name(sword_glb, {
			"blade": blade_mat,
			"fuller": edge_mat,
			"guard": guard_mat,
			"grip": grip_mat,
			"pommel": guard_mat,
			"gem": gem_mat,
		})
		root.add_child(sword_glb)
		return root

	# Fallback primitive sword
	var blade := MeshInstance3D.new()
	var bmesh := BoxMesh.new(); bmesh.size = Vector3(0.044, 0.010, 0.56)
	blade.mesh = bmesh; blade.position = Vector3(0.0, 0.012, -0.30)
	blade.material_override = blade_mat
	root.add_child(blade)
	return root

func _refresh_player_sword_visual(skin_id: String) -> void:
	active_sword_skin_id = skin_id
	if not is_instance_valid(player_sword_root):
		return
	var pos := player_sword_root.position
	var rot := player_sword_root.rotation_degrees
	player_sword_root.queue_free()
	player_sword_root = _build_3d_sword_mesh(skin_id)
	player_sword_root.position = pos
	player_sword_root.rotation_degrees = rot
	player_sword_root.set_meta("base_pos", pos)
	player_sword_root.set_meta("base_scale", Vector3.ONE)
	player_sword_root.set_meta("prop_id", "sword")
	_attach_sword_hover_area(player_sword_root)
	add_child(player_sword_root)

# ============================================================================
# GAMEPLAY GRAPHICS OVERHAUL: Suit Astrolabe, Brass Rim, Bespoke VFX, HUD Frames
# ============================================================================
func _build_suit_astrolabe_and_rim() -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.80, 0.60, 0.24)
	brass.metallic = 0.90
	brass.roughness = 0.30
	var dark_brass := StandardMaterial3D.new()
	dark_brass.albedo_color = Color(0.40, 0.28, 0.12)
	dark_brass.metallic = 0.75
	dark_brass.roughness = 0.45
	astrolabe_glow_mat = StandardMaterial3D.new()
	astrolabe_glow_mat.albedo_color = Color(0.9, 0.2, 0.2)
	astrolabe_glow_mat.emission_enabled = true
	astrolabe_glow_mat.emission = Color(0.9, 0.2, 0.2)
	astrolabe_glow_mat.emission_energy_multiplier = 1.4
	astrolabe_glow_mat.metallic = 0.4
	astrolabe_glow_mat.roughness = 0.3

	astrolabe_root = Node3D.new()
	astrolabe_root.name = "SuitAstrolabe"
	astrolabe_root.position = Vector3(0.14, 0.817, 0.02)
	add_child(astrolabe_root)

	# Outer fixed brass ring + engraved tick studs
	var outer_fixed := MeshInstance3D.new()
	var otm := TorusMesh.new(); otm.inner_radius = 0.385; otm.outer_radius = 0.405; otm.rings = 64; otm.ring_segments = 6
	outer_fixed.mesh = otm; outer_fixed.scale = Vector3(1.0, 0.25, 1.0); outer_fixed.material_override = dark_brass
	outer_fixed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	astrolabe_root.add_child(outer_fixed)

	# Rotating outer ring carries 4 suit gems; the active suit gem rotates to face the player
	astrolabe_ring_outer = Node3D.new()
	astrolabe_root.add_child(astrolabe_ring_outer)
	var rot_ring := MeshInstance3D.new()
	var rtm := TorusMesh.new(); rtm.inner_radius = 0.352; rtm.outer_radius = 0.368; rtm.rings = 64; rtm.ring_segments = 6
	rot_ring.mesh = rtm; rot_ring.scale = Vector3(1.0, 0.3, 1.0); rot_ring.material_override = brass
	rot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	astrolabe_ring_outer.add_child(rot_ring)
	var suit_ids := ["CERVEN", "ZALUD", "ZELEN", "GULA"]
	for i in range(4):
		var s_obj := _get_suit_obj(suit_ids[i])
		var a: float = SUIT_ASTRO_ANGLES[suit_ids[i]]
		var gem := MeshInstance3D.new()
		var gm := SphereMesh.new(); gm.radius = 0.018; gm.height = 0.022; gm.radial_segments = 10; gm.rings = 5
		gem.mesh = gm
		var gmat := StandardMaterial3D.new()
		var sc: Color = s_obj.get("col", Color.WHITE)
		gmat.albedo_color = sc
		gmat.emission_enabled = true
		gmat.emission = sc
		gmat.emission_energy_multiplier = 0.9
		gem.material_override = gmat
		gem.position = Vector3(sin(a) * 0.36, 0.006, cos(a) * 0.36)
		astrolabe_ring_outer.add_child(gem)
		for t_i in range(6):
			var tk := MeshInstance3D.new()
			var tb := BoxMesh.new(); tb.size = Vector3(0.004, 0.003, 0.014)
			tk.mesh = tb; tk.material_override = brass
			var ta := a + (float(t_i) - 2.5) * 0.12
			tk.position = Vector3(sin(ta) * 0.376, 0.002, cos(ta) * 0.376)
			tk.rotation.y = ta
			astrolabe_ring_outer.add_child(tk)

	# Inner glowing suit ring counter-rotates slowly
	astrolabe_ring_inner = Node3D.new()
	astrolabe_root.add_child(astrolabe_ring_inner)
	var in_ring := MeshInstance3D.new()
	var itm := TorusMesh.new(); itm.inner_radius = 0.322; itm.outer_radius = 0.330; itm.rings = 64; itm.ring_segments = 4
	in_ring.mesh = itm; in_ring.scale = Vector3(1.0, 0.2, 1.0); in_ring.material_override = astrolabe_glow_mat
	in_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	astrolabe_ring_inner.add_child(in_ring)
	for k in range(8):
		var sp := MeshInstance3D.new()
		var sb := BoxMesh.new(); sb.size = Vector3(0.006, 0.002, 0.05)
		sp.mesh = sb; sp.material_override = astrolabe_glow_mat
		var ka := float(k) * TAU / 8.0
		sp.position = Vector3(sin(ka) * 0.30, 0.0, cos(ka) * 0.30)
		sp.rotation.y = ka
		astrolabe_ring_inner.add_child(sp)

	# Pointer arrow on fixed ring facing the player (+Z)
	var ptr := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.04, 0.035, 0.008)
	ptr.mesh = pm; ptr.material_override = brass
	ptr.rotation_degrees = Vector3(-90.0, 0.0, 180.0)
	ptr.position = Vector3(0.0, 0.004, 0.425)
	astrolabe_root.add_child(ptr)

	# --- Carved brass rim on the player-side edge: corner brackets, nail studs, inlay arc ---
	var rim_r := 1.395
	var rim_y := 0.818
	for s_i in range(-9, 10):
		var ang := deg_to_rad(float(s_i) * 6.0)
		var stud := MeshInstance3D.new()
		var stm := SphereMesh.new(); stm.radius = 0.011; stm.height = 0.012; stm.radial_segments = 8; stm.rings = 4
		stud.mesh = stm; stud.material_override = brass
		stud.position = Vector3(sin(ang) * rim_r, rim_y, cos(ang) * rim_r)
		add_child(stud)
	for s_i in range(-8, 9):
		var a0 := deg_to_rad(float(s_i) * 6.0 + 3.0)
		var seg := MeshInstance3D.new()
		var sbm := BoxMesh.new(); sbm.size = Vector3(0.14, 0.003, 0.008)
		seg.mesh = sbm; seg.material_override = brass
		seg.position = Vector3(sin(a0) * 1.36, 0.8165, cos(a0) * 1.36)
		seg.rotation.y = a0 + PI * 0.5
		add_child(seg)
	for side in [-1.0, 1.0]:
		var ba := deg_to_rad(side * 58.0)
		var bracket := Node3D.new()
		bracket.position = Vector3(sin(ba) * 1.38, rim_y, cos(ba) * 1.38)
		bracket.rotation.y = ba
		add_child(bracket)
		var plate := MeshInstance3D.new()
		var plm := BoxMesh.new(); plm.size = Vector3(0.16, 0.012, 0.09)
		plate.mesh = plm; plate.material_override = brass
		bracket.add_child(plate)
		var boss_knob := MeshInstance3D.new()
		var bkm := SphereMesh.new(); bkm.radius = 0.022; bkm.height = 0.02
		boss_knob.mesh = bkm; boss_knob.position = Vector3(0, 0.008, 0); boss_knob.material_override = dark_brass
		bracket.add_child(boss_knob)
		for corner in [Vector3(-0.065, 0.008, -0.035), Vector3(0.065, 0.008, -0.035), Vector3(-0.065, 0.008, 0.035), Vector3(0.065, 0.008, 0.035)]:
			var nail := MeshInstance3D.new()
			var nm := SphereMesh.new(); nm.radius = 0.007; nm.height = 0.008
			nail.mesh = nm; nail.position = corner; nail.material_override = dark_brass
			bracket.add_child(nail)

	# --- Carved Oak & Brass Relic Altar Tray on the Table Left ---
	var relic_tray := Node3D.new()
	relic_tray.name = "RelicAltarTray"
	relic_tray.position = Vector3(-0.62, 0.816, -0.10)
	relic_tray.rotation_degrees.y = 14.0
	add_child(relic_tray)
	var tray_wood := Toon.mat(Color(0.22, 0.14, 0.09), "res://assets/table/wood.png", 0.008)
	var tray_base := MeshInstance3D.new()
	var tbm := BoxMesh.new(); tbm.size = Vector3(0.32, 0.014, 0.68)
	tray_base.mesh = tbm; tray_base.material_override = tray_wood
	relic_tray.add_child(tray_base)
	var tray_rim := MeshInstance3D.new()
	var trm := BoxMesh.new(); trm.size = Vector3(0.34, 0.022, 0.70)
	tray_rim.mesh = trm; tray_rim.position.y = -0.002; tray_rim.material_override = dark_brass
	relic_tray.add_child(tray_rim)
	for cz in [-0.32, 0.32]:
		for cx_t in [-0.14, 0.14]:
			var r_stud := MeshInstance3D.new()
			var rsm := SphereMesh.new(); rsm.radius = 0.012; rsm.height = 0.014
			r_stud.mesh = rsm; r_stud.position = Vector3(cx_t, 0.012, cz); r_stud.material_override = brass
			relic_tray.add_child(r_stud)

func _trigger_suit_pulse(power: float = 1.0) -> void:
	suit_pulse_age = 0.0
	if table_felt_mat:
		table_felt_mat.set_shader_parameter("suit_pulse_power", clampf(power, 0.4, 2.0))

func _update_gameplay_gfx(delta: float, t: float) -> void:
	# Suit change detection -> ripple + astrolabe realign
	if active_suit_id != gfx_last_suit_id:
		gfx_last_suit_id = active_suit_id
		_trigger_suit_pulse(1.2)
	suit_pulse_age += delta
	var s_col: Color = _get_suit_obj(active_suit_id).get("col", Color(0.9, 0.2, 0.2))
	if table_felt_mat:
		table_felt_mat.set_shader_parameter("suit_col", s_col)
		table_felt_mat.set_shader_parameter("suit_pulse_t", suit_pulse_age)
		table_felt_mat.set_shader_parameter("overdrive", overdrive_light_t)
	if is_instance_valid(astrolabe_ring_outer):
		var target: float = -float(SUIT_ASTRO_ANGLES.get(active_suit_id, 0.0))
		astrolabe_yaw = lerp_angle(astrolabe_yaw, target, clampf(6.0 * delta, 0.0, 1.0))
		astrolabe_ring_outer.rotation.y = astrolabe_yaw
		astrolabe_ring_inner.rotation.y = -t * 0.25
		if astrolabe_glow_mat:
			astrolabe_glow_mat.albedo_color = astrolabe_glow_mat.albedo_color.lerp(s_col, 5.0 * delta)
			astrolabe_glow_mat.emission = astrolabe_glow_mat.albedo_color
			astrolabe_glow_mat.emission_energy_multiplier = 1.1 + 0.3 * sin(t * 2.4) + clampf(1.0 - suit_pulse_age, 0.0, 1.0) * 2.0 + overdrive_light_t * 1.2

	# INFERNO & DRAMATIC EXECUTION LIGHTING: dim room, tint & intensify table spot cleanly
	overdrive_light_target = maxf(0.0, overdrive_light_target - delta * 0.35)
	overdrive_light_t = lerpf(overdrive_light_t, clampf(overdrive_light_target, 0.0, 1.0), 3.0 * delta)
	var dim_amt := clampf(dramatic_lighting_dim, 0.0, 1.0)
	if gfx_env:
		var base_amb := gfx_base_ambient_energy * lerpf(1.0, 0.45, overdrive_light_t)
		gfx_env.ambient_light_energy = lerpf(base_amb, gfx_base_ambient_energy * 0.18, dim_amt)
	if is_instance_valid(table_spot_light):
		var flick := 1.0 + overdrive_light_t * (0.08 * sin(t * 23.0) + 0.05 * sin(t * 37.0))
		var base_e := lerpf(gfx_base_spot_energy, gfx_base_spot_energy * 1.28, overdrive_light_t) * flick
		table_spot_light.light_energy = minf(2.4, lerpf(base_e, gfx_base_spot_energy * 0.28, dim_amt))
		var base_col := Color(1.0, 0.84, 0.62).lerp(Color(1.0, 0.66, 0.36), overdrive_light_t)
		table_spot_light.light_color = base_col.lerp(dramatic_lighting_tint, dim_amt * 0.72)
	if is_instance_valid(opp_fire_fx_root) and opp_fire_fx_root.visible:
		var bc := opp_fire_fx_root.get_node_or_null("BlenderBurnCrown") as Node3D
		if is_instance_valid(bc):
			bc.rotation.y += delta * 1.35

	# Lazy engraved HUD frame overlays (only Rival & Combo plaques — Wheel is round, Turn banner is frameless calligraphy)
	if hud_frame_overlays.is_empty():
		for g in [rival_hud_grp]:
			if is_instance_valid(g):
				_attach_hud_frame(g, false)
	else:
		for ov in hud_frame_overlays:
			if is_instance_valid(ov) and ov.is_visible_in_tree():
				ov.queue_redraw()
	if tutorial_callout_grp and tutorial_callout_grp.visible:
		tutorial_callout_grp.queue_redraw()
	if is_instance_valid(tutorial_ghost_3d) and tutorial_ghost_3d.visible:
		tutorial_ghost_3d.position.y = 0.80 + sin(t * 2.6) * 0.032
		tutorial_ghost_3d.rotation_degrees.y = 52.0 + sin(t * 1.4) * 6.0
		if is_instance_valid(tutorial_ghost_arm):
			var arm_target := Vector3(-6.0 + sin(t * 3.8) * 5.0, 22.0 if tutorial_step == 1 else (36.0 if tutorial_step == 5 else 8.0), 0.0)
			tutorial_ghost_arm.rotation_degrees = tutorial_ghost_arm.rotation_degrees.lerp(arm_target, 6.0 * delta)
		if is_instance_valid(tutorial_ghost_arm_left):
			var l_arm_target := Vector3(12.0 + cos(t * 2.9) * 7.0, -14.0 + sin(t * 2.1) * 5.0, -12.0 + sin(t * 2.4) * 4.0)
			tutorial_ghost_arm_left.rotation_degrees = tutorial_ghost_arm_left.rotation_degrees.lerp(l_arm_target, 6.0 * delta)
		for ti in range(tutorial_ghost_tendrils.size()):
			var td := tutorial_ghost_tendrils[ti]
			if is_instance_valid(td):
				var base_yaw: float = float(td.get_meta("base_yaw", 0.0))
				var ph_t: float = float(td.get_meta("phase", 0.0))
				td.rotation_degrees = Vector3(
					10.0 + sin(t * 2.8 + ph_t) * 14.0,
					base_yaw + cos(t * 1.7 + ph_t) * 9.0,
					sin(t * 2.2 + ph_t * 1.3) * 10.0
				)
		for wi in range(tutorial_ghost_wisps.size()):
			var wp := tutorial_ghost_wisps[wi]
			if is_instance_valid(wp):
				var rad_w: float = float(wp.get_meta("rad", 0.24))
				var ph_w: float = float(wp.get_meta("phase", 0.0))
				var spd_w: float = float(wp.get_meta("spd", 0.9))
				var cyc := fmod(t * 0.28 * spd_w + ph_w / TAU, 1.0)
				var ang_w := t * spd_w + ph_w
				wp.position = Vector3(cos(ang_w) * (rad_w * (1.0 - cyc * 0.35)), lerpf(-0.08, 0.92, cyc), sin(ang_w) * (rad_w * 0.85))
				var sc_w := sin(cyc * PI) * float(wp.get_meta("base_sc", 1.0))
				wp.scale = Vector3(sc_w, sc_w, sc_w)
		if is_instance_valid(tutorial_ghost_skull_root):
			tutorial_ghost_skull_root.rotation_degrees = Vector3(
				sin(t * 2.1) * 3.5,
				cos(t * 1.6) * 6.5,
				sin(t * 1.9) * 2.5
			)
		# Animated 3D skull eyes: periodic blinking, darting gaze saccades, and pulsing soul-fire pupils
		var blink_cycle: float = fmod(t, 3.4)
		var is_blink := (blink_cycle > 3.22) or (fmod(t, 9.5) > 9.10 and fmod(t, 9.5) < 9.22)
		var eye_open_y: float = 0.10 if is_blink else (0.94 + 0.10 * sin(t * 5.2))
		var gaze_yaw: float = sin(t * 1.8) * 14.0 + roundf(sin(t * 0.85)) * 10.0
		var gaze_pitch: float = cos(t * 2.3) * 8.0
		var pupil_pulse := 0.86 + 0.28 * sin(t * 7.8)
		for e_node in [tutorial_ghost_eye_left, tutorial_ghost_eye_right]:
			if is_instance_valid(e_node):
				e_node.scale.y = lerpf(e_node.scale.y, eye_open_y, 24.0 * delta)
				e_node.rotation_degrees = e_node.rotation_degrees.lerp(Vector3(gaze_pitch, gaze_yaw, 0.0), 14.0 * delta)
		for p_node in [tutorial_ghost_pupil_left, tutorial_ghost_pupil_right]:
			if is_instance_valid(p_node):
				p_node.scale = Vector3(pupil_pulse, pupil_pulse, 1.0)
		var is_speaking := (ghost_speech_full != "" and ghost_speech_chars < float(ghost_speech_full.length()))
		if is_speaking:
			ghost_speech_chars = minf(float(ghost_speech_full.length()), ghost_speech_chars + delta * 42.0)
			var vis_speech := ghost_speech_full.substr(0, int(ghost_speech_chars))
			if is_instance_valid(tutorial_ghost_speech_3d):
				tutorial_ghost_speech_3d.text = vis_speech
			if is_instance_valid(tutorial_ghost_speech_lbl):
				tutorial_ghost_speech_lbl.text = vis_speech
			ghost_voice_cd -= delta
			if ghost_voice_cd <= 0.0:
				ghost_voice_cd = 0.115
				emit_signal("play_sfx_pitched_requested", "ghost_speak", randf_range(0.90, 1.22))
			if is_instance_valid(tutorial_ghost_jaw_root):
				tutorial_ghost_jaw_root.rotation_degrees.x = 5.0 + absf(sin(t * 26.0)) * 21.0
			elif is_instance_valid(tutorial_ghost_mouth):
				tutorial_ghost_mouth.scale = Vector3(1.1, 0.4 + absf(sin(t * 24.0)) * 1.5, 1.0)
		else:
			if is_instance_valid(tutorial_ghost_jaw_root):
				var idle_chatter := 3.5 + maxf(0.0, sin(t * 4.2) - 0.65) * 14.0
				tutorial_ghost_jaw_root.rotation_degrees.x = lerpf(tutorial_ghost_jaw_root.rotation_degrees.x, idle_chatter, 12.0 * delta)
			elif is_instance_valid(tutorial_ghost_mouth):
				tutorial_ghost_mouth.scale = tutorial_ghost_mouth.scale.lerp(Vector3(1.0, 0.22, 1.0), 10.0 * delta)
		if is_instance_valid(tutorial_ghost_speech_lbl) and tutorial_ghost_speech_lbl.visible and cam:
			var sp_world := tutorial_ghost_3d.global_position + Vector3(0.20, 0.72, 0.02)
			var sp_2d := cam.unproject_position(sp_world)
			tutorial_ghost_speech_lbl.position = Vector2(clampf(sp_2d.x, 236.0, 258.0), clampf(sp_2d.y, 92.0, 146.0))
	if is_instance_valid(tutorial_ghost_center_panel) and tutorial_ghost_center_panel.visible:
		tutorial_ghost_center_panel.queue_redraw()

func _attach_hud_frame(grp: Control, is_combo: bool) -> void:
	var ov := Control.new()
	ov.name = "WoodcutFrame"
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.set_meta("is_combo", is_combo)
	ov.draw.connect(func(): _draw_hud_frame(ov))
	grp.add_child(ov)
	hud_frame_overlays.append(ov)

func _draw_hud_frame(ov: Control) -> void:
	var p := ov.get_parent() as Control
	if p == null:
		return
	var sz := p.size
	if sz.x < 8.0 or sz.y < 8.0:
		return
	var t := Time.get_ticks_msec() * 0.001
	var ink := Color(0.06, 0.04, 0.03, 0.90)
	var brass := Color(0.84, 0.64, 0.28, 0.88)
	var r := Rect2(Vector2.ZERO, sz)
	# Double-ruled engraved dark oak & antique brass border
	ov.draw_rect(r.grow(-0.5), ink, false, 2.2)
	ov.draw_rect(r.grow(-3.0), brass, false, 1.3)
	ov.draw_rect(r.grow(-5.5), Color(0.45, 0.32, 0.16, 0.45), false, 1.0)
	# Subtle top candlelit sheen bevel
	ov.draw_line(Vector2(6.0, 2.5), Vector2(sz.x - 6.0, 2.5), Color(1.0, 0.90, 0.62, 0.24), 1.0)
	# Four corner brass rivets
	for c in [Vector2(5.5, 5.5), Vector2(sz.x - 5.5, 5.5), Vector2(5.5, sz.y - 5.5), Vector2(sz.x - 5.5, sz.y - 5.5)]:
		ov.draw_circle(c, 3.2, brass)
		ov.draw_circle(c, 1.4, ink)
	var tick_n := int(sz.x / 26.0)
	for i in range(1, tick_n):
		var x := float(i) * sz.x / float(tick_n)
		ov.draw_line(Vector2(x, 1.5), Vector2(x, 3.5), Color(0.86, 0.66, 0.28, 0.38), 1.0)
		ov.draw_line(Vector2(x, sz.y - 1.5), Vector2(x, sz.y - 3.5), Color(0.86, 0.66, 0.28, 0.38), 1.0)
	# Flame / ember aura around the Chips × Mult pill when hot
	if bool(ov.get_meta("is_combo", false)) and float(combo_mult_val) >= 3.0:
		var heat := clampf((float(combo_mult_val) - 3.0) / 4.0, 0.15, 1.0)
		for k in range(12):
			var u := fmod(float(k) * 0.137 + t * (0.35 + float(k % 3) * 0.12), 1.0)
			var ex := fmod(float(k) * 37.0, sz.x)
			var ey := sz.y - u * (sz.y + 14.0)
			ov.draw_circle(Vector2(ex, ey), 2.0 * (1.0 - u) + 0.5, Color(1.0, 0.55 + 0.3 * (1.0 - u), 0.15, (1.0 - u) * 0.72 * heat))
		ov.draw_rect(r.grow(-1.0), Color(1.0, 0.5, 0.15, (0.35 + 0.25 * sin(t * 9.0)) * heat), false, 2.2)

func _is_fancy_play_card(card: Dictionary, cnt: int = 1) -> bool:
	var c_cls := Catalog.normalize_card_class(str(card.get("edition", "NORMAL")))
	var pid := str(card.get("power_id", ""))
	if c_cls in ["KNIGHT", "MAGE"] or pid.begins_with("SPEC_") or pid != "":
		return true
	if aces_played >= 3 or (cnt >= 3 and str(card.get("rank", "")) == "E"):
		return true
	return false

func _should_play_weapon_card_anim(card_data: Dictionary, combo_count: int = 1, is_shield_block: bool = false) -> bool:
	if is_shield_block:
		return true
	if combo_count >= 2:
		return true
	var cls := Catalog.normalize_card_class(str(card_data.get("edition", card_data.get("card_class", "NORMAL"))))
	if cls != "NORMAL":
		return true
	var pid := str(card_data.get("power_id", ""))
	if pid != "":
		return true
	var rank := str(card_data.get("rank", ""))
	return rank in ["7", "D", "K", "E"]

func _spawn_signature_play_vfx(chosen_cards: Array[Dictionary], impact_pos: Vector3, cnt: int, skip_power_showcase: bool = false) -> Node3D:
	if chosen_cards.is_empty():
		return null
	var lead: Dictionary = chosen_cards[0]
	var rank := str(lead.get("rank", ""))
	var pid := str(lead.get("power_id", ""))
	var s_col: Color = _get_suit_obj(str(lead.get("suit", active_suit_id))).get("col", Color(1, 0.8, 0.3))
	var rival_pos := to_global(Vector3(0.0, 0.95, -1.05))
	var player_pos := to_global(Vector3(0.0, 0.95, 0.85))
	_trigger_suit_pulse(1.0 + 0.25 * float(cnt))
	var has_fancy := false
	for c_f in chosen_cards:
		if _is_fancy_play_card(c_f, cnt):
			has_fancy = true
			break
	var b_card_fx: Node3D = null
	if _should_play_weapon_card_anim(lead, cnt) or has_fancy:
		b_card_fx = SwordCardAnim.play_ancient_circle_sigil(self, lead, impact_pos)
		_register_blender_vfx(b_card_fx)

	# Camera micro-choreography: FOV punch + Dutch roll on multi-card slams
	if cam_spring:
		cam_spring.fov_vel -= 9.0 + 3.0 * float(cnt)
		if cnt >= 2:
			var dir := -1.0 if (cnt % 2 == 0) else 1.0
			cam_spring.rot_vel_deg.z += dir * (14.0 + 6.0 * float(mini(cnt, 4)))

	if PowerCardShowcase.CARD_META.has(pid) and not skip_power_showcase:
		var meta_p: Dictionary = PowerCardShowcase.CARD_META[pid]
		var accent_c: Color = meta_p.get("accent", lead.get("accent", Color(1.0, 0.84, 0.32)))
		Fx.shard_burst(self, impact_pos, accent_c, 12, 0.52)
		if pid == "SPEC_PHOENIX":
			overdrive_light_target = maxf(overdrive_light_target, 0.6)
		elif pid == "SPEC_PLAGUE":
			Fx.ink_splat(self, impact_pos, 26, 1.2)
		elif pid == "SPEC_CROWN":
			Fx.light_pillar(self, impact_pos, accent_c, 1.6, 0.8)
		emit_signal("play_sfx_pitched_requested", "card_ace_strike", 1.12 if pid == "SPEC_STORM" else 1.02)
		var card_vfx := PowerCardShowcase.new()
		add_child(card_vfx)
		card_vfx.sfx_triggered.connect(func(sfx_key: String, _vol: float, pitch_val: float):
			emit_signal("play_sfx_pitched_requested", sfx_key, pitch_val)
		)
		card_vfx.setup_battle_fx(impact_pos, rival_pos, pid, false)
	elif pid != "":
		Fx.shard_burst(self, impact_pos, lead.get("accent", Color(1.0, 0.84, 0.32)), 8, 0.42)

	if pid == "":
		if rank == "7":
			Fx.dagger_slash(self, impact_pos, rival_pos, 1.0 + 0.2 * float(cnt - 1))
			emit_signal("play_sfx_pitched_requested", "card_seven_curse", clampf(0.96 + float(cnt - 1) * 0.08, 0.96, 1.24))
		elif rank == "E":
			Fx.sigil_clock(self, impact_pos, rival_pos, 1.0)
			emit_signal("play_sfx_pitched_requested", "card_ace_strike", clampf(0.96 + float(cnt - 1) * 0.08, 0.96, 1.24))
		elif rank == "H":
			Fx.compass_spin(self, impact_pos, _get_suit_obj(active_suit_id).get("col", s_col))
			emit_signal("play_sfx_requested", "card_suit_shift")
		elif rank == "D":
			emit_signal("play_sfx_requested", "card_shield_guard")
	if cnt >= 2:
		Fx.ring(self, impact_pos + Vector3(0, 0.012, 0), s_col, 0.45 + 0.15 * float(cnt), 0.5, 0.08, 2.0, float(cnt * 4))
		emit_signal("play_sfx_pitched_requested", "anim_combo_slam", clampf(0.95 + float(cnt - 2) * 0.08, 0.95, 1.20))
	return b_card_fx

func _setup_epic_3d_tavern_environment() -> void:
	# World-Space Triplanar UV PBR materials: NO stretched wall/beam/ceiling/floor textures anywhere!
	var beam_mat := _make_triplanar_pbr_mat("res://assets/table/wood.png", Color(0.24, 0.16, 0.10), 0.52, 0.72, 0.04, "res://assets/textures/tavern/tavern_wood_normal.png")
	var wainscot_mat := _make_triplanar_pbr_mat("res://assets/table/wood.png", Color(0.18, 0.11, 0.07), 0.65, 0.66, 0.05, "res://assets/textures/tavern/tavern_wood_normal.png")
	var iron_mat := Toon.pbr(Color(0.18, 0.20, 0.24), "", 0.42, 0.84)
	var stone_wall_mat := _make_triplanar_pbr_mat("res://assets/table/stone_floor.png", Color(0.24, 0.23, 0.25), 0.44, 0.90, 0.02, "res://assets/textures/tavern/tavern_stone_normal.png", "res://assets/textures/tavern/tavern_stone_ao.png")

	# 1. Krčmové stoličky okolo stola (vzadu vysoká za súperom + bočné)
	_spawn_tavern_chair(Vector3(0.0, 0.0, -2.02), 0.0, beam_mat, 1.15)
	_spawn_tavern_chair(Vector3(-2.05, 0.0, -0.35), 78.0, beam_mat, 0.95)
	_spawn_tavern_chair(Vector3(2.05, 0.0, -0.35), -78.0, beam_mat, 0.95)

	# 2. Kamenné múry s reálnymi gotickými okennými otvormi + dubové obloženie (wainscoting)
	_add_wall_block(Vector3(0.0, 0.80, -5.2), Vector3(13.0, 1.60, 0.4), stone_wall_mat)
	_add_wall_block(Vector3(0.0, 4.25, -5.2), Vector3(13.0, 1.90, 0.4), stone_wall_mat)
	_add_wall_block(Vector3(0.0, 2.45, -5.2), Vector3(2.86, 1.70, 0.4), stone_wall_mat)
	_add_wall_block(Vector3(-4.60, 2.45, -5.2), Vector3(3.84, 1.70, 0.4), stone_wall_mat)
	_add_wall_block(Vector3(4.60, 2.45, -5.2), Vector3(3.84, 1.70, 0.4), stone_wall_mat)

	# Spodné dubové táflovanie + rímsa pozdĺž zadnej a bočných stien (žiadne holé natiahnuté plochy)
	_add_wall_block(Vector3(0.0, 0.56, -4.96), Vector3(11.4, 1.12, 0.12), wainscot_mat)
	_add_wall_block(Vector3(0.0, 1.16, -4.92), Vector3(11.5, 0.10, 0.18), beam_mat)
	for px_w in range(-5, 6):
		_add_wall_block(Vector3(float(px_w) * 1.05, 0.56, -4.89), Vector3(0.14, 1.06, 0.06), beam_mat)

	for side_x in [-5.6, 5.6]:
		_add_wall_block(Vector3(side_x, 2.6, -0.2), Vector3(0.4, 5.2, 11.5), stone_wall_mat)
		_add_wall_block(Vector3(side_x - signf(side_x) * 0.22, 0.56, -0.2), Vector3(0.12, 1.12, 11.2), wainscot_mat)
		_add_wall_block(Vector3(side_x - signf(side_x) * 0.25, 1.16, -0.2), Vector3(0.18, 0.10, 11.2), beam_mat)

	for px in [-3.4, 3.4, -5.1, 5.1]:
		var pz := -4.8 if absf(px) < 4.0 else -1.6
		var pillar := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.38, 4.8, 0.38)
		pillar.mesh = pb; pillar.position = Vector3(px, 2.4, pz); pillar.material_override = beam_mat
		add_child(pillar)

	for bz in [-4.5, -2.2, 0.0, 2.2]:
		var cbeam := MeshInstance3D.new()
		var cb := BoxMesh.new(); cb.size = Vector3(11.6, 0.32, 0.34)
		cbeam.mesh = cb; cbeam.position = Vector3(0.0, 4.3, bz); cbeam.material_override = beam_mat
		add_child(cbeam)

	# Drevený strop a pozdĺžne krokvy (s World-Space Triplanar drevenou textúrou)
	var ceiling := MeshInstance3D.new()
	var cplane := BoxMesh.new(); cplane.size = Vector3(13.0, 0.2, 12.5)
	ceiling.mesh = cplane; ceiling.position = Vector3(0.0, 4.65, -0.2); ceiling.material_override = beam_mat
	add_child(ceiling)

	for lx in [-3.4, 0.0, 3.4]:
		var rbeam := MeshInstance3D.new()
		var rb := BoxMesh.new(); rb.size = Vector3(0.28, 0.28, 11.5)
		rbeam.mesh = rb; rbeam.position = Vector3(lx, 4.42, -0.2); rbeam.material_override = beam_mat
		add_child(rbeam)

	# 3. Gotické okná s výhľadom na malebný nočný svet vonku + dážď za sklom!
	for wx in [-2.05, 2.05]:
		_spawn_storm_window(Vector3(wx, 2.45, -5.08), beam_mat, iron_mat)
	_spawn_exterior_vista()

	# 4. Kamenný kozub s ohňom na ľavej stene + drevo
	_spawn_tavern_hearth(Vector3(-5.05, 0.0, -0.35), stone_wall_mat, beam_mat)

	# 5. Sudy, debny, heroldické štíty
	_spawn_tavern_barrel(Vector3(-3.35, 0.0, -3.55), 0.95, beam_mat, iron_mat)
	_spawn_tavern_barrel(Vector3(-4.15, 0.0, -2.85), 0.85, beam_mat, iron_mat)
	_spawn_tavern_barrel(Vector3(-3.65, 0.98, -3.35), 0.72, beam_mat, iron_mat, 90.0)
	_spawn_tavern_barrel(Vector3(3.65, 0.0, -3.55), 0.95, beam_mat, iron_mat)
	_spawn_crate(Vector3(-4.35, 0.0, -4.05), 0.75, beam_mat)
	_spawn_crate(Vector3(4.35, 0.0, -0.20), 0.68, beam_mat)
	_spawn_crate(Vector3(4.45, 0.68, -0.25), 0.50, beam_mat)
	_spawn_wall_trophy(Vector3(-3.16, 2.55, -4.75), iron_mat, beam_mat)
	_spawn_wall_trophy(Vector3(3.16, 2.55, -4.75), iron_mat, beam_mat)

	# 6. Krčmový barový pult z Blenderu (tavern_bar.glb) + nástenná polica + zdobené zástavy (tavern_banner.glb)
	var bar_glb := _load_glb_model("res://assets/models/tavern_bar.glb", true)
	if bar_glb:
		bar_glb.position = Vector3(4.2, 0.0, -2.2)
		var bar_brass := Toon.pbr(Color(0.78, 0.58, 0.22), "", 0.28, 0.88)
		_apply_mat_by_mesh_name(bar_glb, {
			"barfootrail": bar_brass,
			"footbracket": bar_brass,
			"barbody": beam_mat,
			"barplinth": beam_mat,
			"barcountertop": beam_mat,
			"barpanel": beam_mat,
			"barpilaster": beam_mat,
		})
		add_child(bar_glb)
	else:
		var bar_counter := MeshInstance3D.new()
		var bcm := BoxMesh.new(); bcm.size = Vector3(1.1, 1.1, 2.8)
		bar_counter.mesh = bcm; bar_counter.position = Vector3(4.2, 0.55, -2.2); bar_counter.material_override = beam_mat
		add_child(bar_counter)

	var shelf := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.45, 0.08, 2.4)
	shelf.mesh = sm; shelf.position = Vector3(5.2, 2.15, -2.2); shelf.material_override = beam_mat
	add_child(shelf)
	var bottle_colors := [Color(0.15, 0.26, 0.17), Color(0.30, 0.12, 0.10), Color(0.24, 0.18, 0.11), Color(0.16, 0.18, 0.26)]
	for si in range(6):
		var sc: Color = bottle_colors[(si + 1) % bottle_colors.size()]
		var smat := Toon.pbr(sc, "", 0.18, 0.05)
		var sz := -3.15 + float(si) * 0.36
		var sb := MeshInstance3D.new()
		var sbc := CylinderMesh.new(); sbc.top_radius = 0.036; sbc.bottom_radius = 0.048; sbc.height = 0.15
		sb.mesh = sbc; sb.material_override = smat; sb.position = Vector3(5.16, 2.26, sz)
		add_child(sb)
		var sneck := MeshInstance3D.new()
		var snc := CylinderMesh.new(); snc.top_radius = 0.016; snc.bottom_radius = 0.022; snc.height = 0.07
		sneck.mesh = snc; sneck.material_override = smat; sneck.position = Vector3(5.16, 2.36, sz)
		add_child(sneck)

	# Heraldické vlajúce zástavy na stenách (top-rod kotvenie, žiadne natiahnuté pláty!)
	_spawn_wall_banner(Vector3(-3.82, 3.72, -4.90), Color(0.56, 0.12, 0.14), Color(0.90, 0.70, 0.24))
	_spawn_wall_banner(Vector3(3.82, 3.72, -4.90), Color(0.14, 0.32, 0.48), Color(0.90, 0.70, 0.24))
	_spawn_wall_banner(Vector3(0.0, 4.02, -4.94), Color(0.16, 0.34, 0.22), Color(0.94, 0.74, 0.28))

	# 6B. Gotické kamenné okenné klenby, parapety a originálny LIALO Erb (bez dvojkríža!)
	_spawn_gothic_room_architecture(beam_mat, stone_wall_mat, iron_mat)

	# 7. Kované nástenné lucerny s teplým mihotavým svetlom
	_spawn_wall_lantern(Vector3(-3.12, 2.25, -4.85), iron_mat)
	_spawn_wall_lantern(Vector3(3.12, 2.25, -4.85), iron_mat)
	_spawn_wall_lantern(Vector3(-1.12, 2.38, -4.86), iron_mat)
	_spawn_wall_lantern(Vector3(1.12, 2.38, -4.86), iron_mat)
	_spawn_wall_lantern(Vector3(5.32, 2.35, -1.6), iron_mat, -90.0)

	# 8. Visiaci kovaný kolesový luster z Blenderu s kovaným stropným hákom, reťazou a shaderovými plameňmi (jemne sa hojdá!)
	tavern_chandelier = Node3D.new()
	tavern_chandelier.position = Vector3(0.0, 4.2, 0.05)
	add_child(tavern_chandelier)

	var hook_ring := MeshInstance3D.new()
	var hrt := TorusMesh.new(); hrt.inner_radius = 0.04; hrt.outer_radius = 0.085
	hook_ring.mesh = hrt; hook_ring.position = Vector3(0, 0.28, 0); hook_ring.rotation_degrees.x = 90.0
	hook_ring.material_override = iron_mat
	tavern_chandelier.add_child(hook_ring)
	for li_c in range(5):
		var link := MeshInstance3D.new()
		var lt := TorusMesh.new(); lt.inner_radius = 0.020; lt.outer_radius = 0.044
		link.mesh = lt; link.position = Vector3(0, 0.16 - float(li_c) * 0.11, 0)
		link.rotation_degrees = Vector3(90.0, 90.0 if (li_c % 2 == 1) else 0.0, 0.0)
		link.material_override = iron_mat
		tavern_chandelier.add_child(link)

	var chand_glb := _load_glb_model("res://assets/models/tavern_chandelier.glb", true)
	if chand_glb:
		chand_glb.name = "TavernChandelierGLB"
		tavern_chandelier.add_child(chand_glb)
	else:
		var chain := MeshInstance3D.new()
		var chc := CylinderMesh.new(); chc.top_radius = 0.025; chc.bottom_radius = 0.025; chc.height = 1.4
		chain.mesh = chc; chain.position = Vector3(0, -0.7, 0); chain.material_override = iron_mat
		tavern_chandelier.add_child(chain)

	var chand_flame_mat := ShaderMaterial.new()
	chand_flame_mat.shader = load("res://shaders/tavern_hearth_fire.gdshader")
	chand_flame_mat.set_shader_parameter("speed", 3.1)
	chand_flame_mat.set_shader_parameter("intensity", 2.7)
	for ci_f in range(6):
		var c_ang := float(ci_f) * (TAU / 6.0)
		var c_pos := Vector3(cos(c_ang) * 0.56, -1.24, sin(c_ang) * 0.56)
		for cross_y in [0.0, 90.0]:
			var cf := MeshInstance3D.new()
			var cqm := QuadMesh.new(); cqm.size = Vector2(0.045, 0.085); cqm.subdivide_depth = 4
			cf.mesh = cqm; cf.position = c_pos; cf.rotation_degrees.y = cross_y
			cf.material_override = chand_flame_mat
			cf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tavern_chandelier.add_child(cf)

	# 9. Podsvietené billboard GPUParticles3D prachové častice v kuželi okien a lustru
	dust_motes_root = Node3D.new()
	add_child(dust_motes_root)
	var dust_gp := GPUParticles3D.new()
	dust_gp.name = "TavernDustParticles"
	dust_gp.amount = 72
	dust_gp.lifetime = 6.5
	dust_gp.preprocess = 3.0
	dust_gp.position = Vector3(0.0, 1.75, -0.15)
	var dust_proc := ParticleProcessMaterial.new()
	dust_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_proc.emission_box_extents = Vector3(1.8, 0.9, 1.5)
	dust_proc.direction = Vector3(0.15, 1.0, 0.05)
	dust_proc.spread = 38.0
	dust_proc.gravity = Vector3(0.0, 0.015, 0.0)
	dust_proc.initial_velocity_min = 0.02
	dust_proc.initial_velocity_max = 0.07
	dust_proc.scale_min = 0.6
	dust_proc.scale_max = 1.35
	dust_gp.process_material = dust_proc
	var dust_qm := QuadMesh.new()
	dust_qm.size = Vector2(0.026, 0.026)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	dust_mat.albedo_texture = Fx.soft_tex()
	dust_mat.albedo_color = Color(1.0, 0.88, 0.60, 0.45)
	dust_qm.material = dust_mat
	dust_gp.draw_pass_1 = dust_qm
	dust_motes_root.add_child(dust_gp)

func _spawn_gothic_room_architecture(beam_mat: Material, stone_mat: Material, iron_mat: Material) -> void:
	var brass_mat := Toon.pbr(Color(0.88, 0.68, 0.24), "", 0.26, 0.88)

	# 1. Gotické lomené oblúky a kamenné parapety okolo oboch búrkových okien
	for wx in [-2.05, 2.05]:
		var sill := MeshInstance3D.new()
		var sb := BoxMesh.new(); sb.size = Vector3(1.52, 0.14, 0.36)
		sill.mesh = sb; sill.position = Vector3(wx, 1.56, -4.96); sill.material_override = stone_mat
		add_child(sill)

		for side in [-1.0, 1.0]:
			var arch_arm := MeshInstance3D.new()
			var aab := BoxMesh.new(); aab.size = Vector3(0.86, 0.18, 0.34)
			arch_arm.mesh = aab
			arch_arm.position = Vector3(wx + side * 0.34, 3.36, -4.96)
			arch_arm.rotation_degrees.z = -side * 26.0
			arch_arm.material_override = stone_mat
			add_child(arch_arm)

		var keystone := MeshInstance3D.new()
		var ksb := BoxMesh.new(); ksb.size = Vector3(0.24, 0.30, 0.38)
		keystone.mesh = ksb; keystone.position = Vector3(wx, 3.52, -4.94); keystone.material_override = brass_mat
		add_child(keystone)

	# 2. Drevené gotické klenbové vzpery pod stropom
	for bz in [-4.45, -2.20, 0.0]:
		for side in [-1.0, 1.0]:
			var strut := MeshInstance3D.new()
			var stb := BoxMesh.new(); stb.size = Vector3(1.65, 0.22, 0.26)
			strut.mesh = stb; strut.position = Vector3(side * 2.68, 3.68, bz); strut.rotation_degrees.z = -side * 34.0; strut.material_override = beam_mat
			add_child(strut)
		var boss_key := MeshInstance3D.new()
		var bkb := CylinderMesh.new(); bkb.top_radius = 0.18; bkb.bottom_radius = 0.18; bkb.height = 0.12
		boss_key.mesh = bkb; boss_key.position = Vector3(0.0, 4.18, bz); boss_key.rotation_degrees.x = 90.0; boss_key.material_override = brass_mat
		add_child(boss_key)

	# 3. Originálny LIALO Erb Krčmy (Blender skulptovaný štít s Korunovaným Kalichom, Krídlami, Astrolábom a Halapartňami — bez slovenského dvojkríža!)
	var crest_root := Node3D.new()
	crest_root.name = "WallCrestShieldRoot"
	crest_root.position = Vector3(0.0, 2.55, -4.82)
	add_child(crest_root)
	var crest_glb := _load_glb_model("res://assets/models/wall_crest_shield.glb", true)
	if crest_glb:
		crest_glb.name = "WallCrestShieldGLB"
		crest_root.add_child(crest_glb)

	# 4. Alchymistická polica s grimoármi a elixírmi na zadnej stene vpravo
	var alc_shelf := MeshInstance3D.new()
	var asm := BoxMesh.new(); asm.size = Vector3(1.15, 0.08, 0.36)
	alc_shelf.mesh = asm; alc_shelf.position = Vector3(3.25, 1.72, -4.82); alc_shelf.material_override = beam_mat
	add_child(alc_shelf)
	var potion_cols := [Color(0.20, 0.88, 0.48), Color(0.92, 0.22, 0.36), Color(0.32, 0.66, 1.0), Color(0.96, 0.76, 0.22)]
	for p_i in range(4):
		var pot := MeshInstance3D.new()
		var pm := SphereMesh.new(); pm.radius = 0.065; pm.height = 0.13
		pot.mesh = pm; pot.position = Vector3(2.86 + float(p_i) * 0.25, 1.83, -4.80)
		var pc: Color = potion_cols[p_i]
		pot.material_override = Toon.pbr(pc, "", 0.18, 0.08, Vector2.ONE, pc * 0.55, 1.4)
		add_child(pot)

func _spawn_tavern_chair(pos: Vector3, rot_y: float, wood_mat: Material, tall_scale: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	root.scale = Vector3(1.0, tall_scale, 1.0)
	add_child(root)
	var chair_glb := _load_glb_model("res://assets/models/tavern_chair.glb", true)
	if chair_glb:
		var ch_brass := Toon.pbr(Color(0.78, 0.58, 0.22), "", 0.30, 0.88)
		var ch_leather := _make_triplanar_pbr_mat("res://assets/gloves/glove_leather.png", Color(0.24, 0.09, 0.08), 1.4, 0.72, 0.04)
		_apply_mat_by_mesh_name(chair_glb, {
			"chairfinial": ch_brass,
			"chairmedallion": ch_brass,
			"chaircushion": ch_leather,
			"chair": wood_mat,
		})
		root.add_child(chair_glb)
		return
	var seat := MeshInstance3D.new()
	var sb := BoxMesh.new(); sb.size = Vector3(0.54, 0.06, 0.50)
	seat.mesh = sb; seat.position = Vector3(0, 0.50, 0); seat.material_override = wood_mat
	root.add_child(seat)

func _spawn_tavern_barrel(pos: Vector3, s: float, wood_mat: Material, iron_mat: Material, tilt_z: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * s
	root.rotation_degrees.z = tilt_z
	add_child(root)
	var barrel_glb := _load_glb_model("res://assets/models/tavern_barrel.glb", true)
	if barrel_glb:
		_apply_mat_by_mesh_name(barrel_glb, {
			"barrelhoop": iron_mat,
			"hooprivet": iron_mat,
			"barrelstave": wood_mat,
			"barrellid": wood_mat,
		})
		root.add_child(barrel_glb)
		return
	var body := MeshInstance3D.new()
	var bc := CylinderMesh.new(); bc.top_radius = 0.34; bc.bottom_radius = 0.34; bc.height = 0.92; bc.radial_segments = 12
	body.mesh = bc; body.position = Vector3(0, 0.46, 0); body.material_override = wood_mat
	root.add_child(body)
	var hoop := MeshInstance3D.new()
	var hc := CylinderMesh.new(); hc.top_radius = 0.36; hc.bottom_radius = 0.36; hc.height = 0.06; hc.radial_segments = 12
	hoop.mesh = hc; hoop.position = Vector3(0, 0.5, 0); hoop.material_override = iron_mat
	root.add_child(hoop)

func _add_wall_block(pos: Vector3, sz: Vector3, mat: Material) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	b.mesh = bm
	b.position = pos
	b.material_override = mat
	add_child(b)

func _spawn_storm_window(pos: Vector3, wood_mat: Material, iron_mat: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	# Shaderové okenné sklo so stékajúcim dažďom a halom mesačného svitu
	var glass := MeshInstance3D.new()
	var gp := BoxMesh.new()
	gp.size = Vector3(1.18, 1.62, 0.03)
	glass.mesh = gp
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/tavern_window_glass.gdshader")
	gmat.set_shader_parameter("glass_tint", Color(0.18, 0.32, 0.54, 0.24))
	gmat.set_shader_parameter("moon_halo", Color(0.62, 0.82, 1.0, 0.42))
	glass.material_override = gmat
	root.add_child(glass)

	for bar_x in [-0.60, 0.0, 0.60]:
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.08, 1.72, 0.14)
		bar.mesh = bb
		bar.position = Vector3(bar_x, 0, 0.02)
		bar.material_override = iron_mat if bar_x == 0.0 else wood_mat
		root.add_child(bar)
	for bar_y in [-0.82, 0.0, 0.82]:
		var hbar := MeshInstance3D.new()
		var hbb := BoxMesh.new()
		hbb.size = Vector3(1.28, 0.08, 0.14)
		hbar.mesh = hbb
		hbar.position = Vector3(0, bar_y, 0.02)
		hbar.material_override = iron_mat if bar_y == 0.0 else wood_mat
		root.add_child(hbar)
	# Fine gothic leaded glass cross-mullions inside window panes for dramatic woodcut silhouette contrast
	for lx in [-0.30, 0.30]:
		for ly in [-0.41, 0.41]:
			for ang in [42.0, -42.0]:
				var lead := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(0.022, 0.96, 0.04)
				lead.mesh = lm
				lead.position = Vector3(lx, ly, 0.005)
				lead.rotation_degrees.z = ang
				lead.material_override = iron_mat
				root.add_child(lead)

	# Dažďové kvapky šikmo za sklom okna
	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.disable_fog = true
	drop_mat.albedo_color = Color(0.75, 0.90, 1.0, 0.85)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for ri in range(10):
		var drop := MeshInstance3D.new()
		var dm := BoxMesh.new(); dm.size = Vector3(0.015, 0.24, 0.01)
		drop.mesh = dm
		drop.material_override = drop_mat
		var bx := -0.48 + float(ri) * 0.105
		var by := -0.4 + fmod(float(ri) * 0.37, 0.9)
		drop.position = Vector3(bx, by, -0.06)
		drop.rotation_degrees.z = -16.0
		drop.set_meta("base_x", bx)
		drop.set_meta("phase", float(ri) * 0.6)
		root.add_child(drop)
		storm_rain_meshes.append(drop)

	var moon_light := SpotLight3D.new()
	moon_light.position = Vector3(0.0, 0.25, -0.35)
	moon_light.rotation_degrees = Vector3(-28.0, 180.0, 0.0)
	moon_light.spot_range = 7.5
	moon_light.spot_angle = 44.0
	moon_light.light_color = Color(0.46, 0.72, 1.0)
	moon_light.light_energy = 2.4
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.04
	root.add_child(moon_light)
	storm_window_lights.append(moon_light)

	# Objemové svetelné paprsky (god-rays) prenikajúce skrz gotické okná na podlahu a stôl
	var ray_mat := ShaderMaterial.new()
	ray_mat.shader = load("res://shaders/window_godray.gdshader")
	ray_mat.set_shader_parameter("ray_color", Color(0.46, 0.70, 0.98, 0.14))
	for ray_i in range(2):
		var shaft := MeshInstance3D.new()
		var smesh := QuadMesh.new()
		smesh.size = Vector2(1.22, 3.2)
		shaft.mesh = smesh
		shaft.position = Vector3(0.0, -0.68, 1.25 + float(ray_i) * 0.10)
		shaft.rotation_degrees = Vector3(52.0, -14.0 if ray_i == 0 else 14.0, 0.0)
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.material_override = ray_mat
		root.add_child(shaft)

func _spawn_exterior_vista() -> void:
	exterior_vista_root = Node3D.new()
	add_child(exterior_vista_root)
	apply_exterior_vista_for_era("stredovek")

func apply_exterior_vista_for_era(era_id: String) -> void:
	if not is_instance_valid(exterior_vista_root):
		return
	for ch in exterior_vista_root.get_children():
		ch.queue_free()
	exterior_pine_nodes.clear()
	exterior_twinkle_nodes.clear()
	exterior_lightning_meshes.clear()

	# 4 grafické výhľady z okien podľa éry: Hory & Slnko, Hviezdna noc, Veľký Mesiac, Búrka s bleskami
	if era_id == "antika":
		exterior_vista_theme = "sun_mountains"
	elif era_id == "rim":
		exterior_vista_theme = "starry_night"
	elif era_id == "stredovek":
		exterior_vista_theme = "full_moon"
	else:
		exterior_vista_theme = "storm_rain"

	var ext := exterior_vista_root
	var sky_col := Color(0.05, 0.09, 0.20)
	var hor_col := Color(0.14, 0.24, 0.42)
	var far_base := Color(0.08, 0.14, 0.26)
	var far_snow := Color(0.64, 0.78, 0.96)
	var mid_base := Color(0.05, 0.10, 0.19)
	var mid_snow := Color(0.46, 0.62, 0.82)
	var win_col := Color(0.42, 0.68, 1.0)
	var rain_vis := (exterior_vista_theme == "storm_rain")

	if exterior_vista_theme == "sun_mountains":
		sky_col = Color(0.24, 0.54, 0.86)
		hor_col = Color(0.96, 0.72, 0.36)
		far_base = Color(0.24, 0.34, 0.48)
		far_snow = Color(1.0, 0.96, 0.88)
		mid_base = Color(0.16, 0.32, 0.24)
		mid_snow = Color(0.92, 0.86, 0.74)
		win_col = Color(1.0, 0.82, 0.46)
	elif exterior_vista_theme == "starry_night":
		sky_col = Color(0.02, 0.04, 0.14)
		hor_col = Color(0.09, 0.14, 0.32)
		far_base = Color(0.04, 0.07, 0.18)
		far_snow = Color(0.42, 0.56, 0.86)
		mid_base = Color(0.03, 0.05, 0.12)
		mid_snow = Color(0.32, 0.44, 0.72)
		win_col = Color(0.38, 0.58, 1.0)
	elif exterior_vista_theme == "full_moon":
		sky_col = Color(0.04, 0.07, 0.16)
		hor_col = Color(0.18, 0.25, 0.44)
		far_base = Color(0.07, 0.11, 0.22)
		far_snow = Color(0.76, 0.86, 0.98)
		mid_base = Color(0.05, 0.08, 0.16)
		mid_snow = Color(0.56, 0.70, 0.88)
		win_col = Color(0.72, 0.84, 1.0)
	else:
		sky_col = Color(0.04, 0.05, 0.10)
		hor_col = Color(0.14, 0.16, 0.26)
		far_base = Color(0.05, 0.07, 0.13)
		far_snow = Color(0.48, 0.58, 0.76)
		mid_base = Color(0.04, 0.05, 0.10)
		mid_snow = Color(0.34, 0.42, 0.58)
		win_col = Color(0.46, 0.70, 1.0)

	for drp in storm_rain_meshes:
		if is_instance_valid(drp):
			drp.visible = rain_vis
	for wl in storm_window_lights:
		if is_instance_valid(wl):
			wl.light_color = win_col

	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.disable_fog = true
	sky_mat.albedo_color = sky_col
	var sky := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(38.0, 18.0, 0.2)
	sky.mesh = sm; sky.position = Vector3(0.0, 4.5, -19.5); sky.material_override = sky_mat
	ext.add_child(sky)

	var hor_mat := StandardMaterial3D.new()
	hor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hor_mat.disable_fog = true
	hor_mat.albedo_color = hor_col
	var hor := MeshInstance3D.new()
	var hm := BoxMesh.new(); hm.size = Vector3(36.0, 4.0, 0.2)
	hor.mesh = hm; hor.position = Vector3(0.0, 1.8, -18.8); hor.material_override = hor_mat
	ext.add_child(hor)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7711

	# Nebeské telesá & atmosférické prvky presne v osi pohľadu oboch gotických okien nad hrebeňmi hôr!
	if exterior_vista_theme == "sun_mountains":
		for halo_idx in range(3):
			var h_rad := 1.15 + float(halo_idx) * 0.72
			var h_al := 0.56 if halo_idx == 0 else (0.28 if halo_idx == 1 else 0.14)
			var h_mat := StandardMaterial3D.new()
			h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			h_mat.disable_fog = true
			h_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			h_mat.albedo_color = Color(1.0, 0.88 - float(halo_idx) * 0.10, 0.42, h_al)
			var sun_orb := MeshInstance3D.new()
			var spm := SphereMesh.new(); spm.radius = h_rad; spm.height = h_rad * 2.0
			sun_orb.mesh = spm; sun_orb.position = Vector3(5.35, 3.65, -17.2); sun_orb.material_override = h_mat
			ext.add_child(sun_orb)
		var core_mat := StandardMaterial3D.new()
		core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core_mat.disable_fog = true
		core_mat.albedo_color = Color(1.0, 0.96, 0.78)
		var core := MeshInstance3D.new()
		var cm := SphereMesh.new(); cm.radius = 0.85; cm.height = 1.70
		core.mesh = cm; core.position = Vector3(5.35, 3.65, -16.9); core.material_override = core_mat
		ext.add_child(core)
		# Biele denné obláčiky v pohľadovej výške ľavého aj pravého okna
		var wcloud_mat := StandardMaterial3D.new()
		wcloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wcloud_mat.disable_fog = true
		wcloud_mat.albedo_color = Color(0.98, 0.96, 0.94)
		for cp in [Vector3(-5.8, 3.55, -16.8), Vector3(-4.9, 3.68, -16.8), Vector3(-3.4, 3.25, -16.6), Vector3(2.8, 3.85, -16.9)]:
			var cm2 := MeshInstance3D.new()
			var spc := SphereMesh.new(); spc.radius = 0.62; spc.height = 0.82
			cm2.mesh = spc; cm2.position = cp; cm2.material_override = wcloud_mat
			ext.add_child(cm2)

	elif exterior_vista_theme == "starry_night":
		var star_mat := StandardMaterial3D.new()
		star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star_mat.disable_fog = true
		star_mat.albedo_color = Color(0.95, 0.97, 1.0)
		for si in range(62):
			var st := MeshInstance3D.new()
			var sz := rng.randf_range(0.06, 0.14)
			var sbm := BoxMesh.new(); sbm.size = Vector3(sz, sz, 0.02)
			st.mesh = sbm; st.material_override = star_mat
			st.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(2.6, 4.9), -16.8)
			st.set_meta("phase", float(si) * 0.7)
			ext.add_child(st)
			exterior_twinkle_nodes.append(st)
		# Jemný polmesiac vľavo priamo v ráme ľavého okna
		var moon_mat := StandardMaterial3D.new()
		moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_mat.disable_fog = true
		moon_mat.albedo_color = Color(0.96, 0.94, 0.78)
		var cres := MeshInstance3D.new()
		var crm := SphereMesh.new(); crm.radius = 0.68; crm.height = 1.36
		cres.mesh = crm; cres.position = Vector3(-5.35, 3.65, -16.8); cres.material_override = moon_mat
		ext.add_child(cres)

	elif exterior_vista_theme == "full_moon":
		# Žiariaci spln priamo v zábere pravého okna + mesačné hviezdy nad štítmi hôr!
		var halo_mat := StandardMaterial3D.new()
		halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_mat.disable_fog = true
		halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_mat.albedo_color = Color(0.76, 0.88, 1.0, 0.28)
		var m_halo := MeshInstance3D.new()
		var mhm := SphereMesh.new(); mhm.radius = 1.75; mhm.height = 3.50
		m_halo.mesh = mhm; m_halo.position = Vector3(5.35, 3.65, -17.2); m_halo.material_override = halo_mat
		ext.add_child(m_halo)

		var full_mat := StandardMaterial3D.new()
		full_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		full_mat.disable_fog = true
		full_mat.albedo_color = Color(1.0, 0.97, 0.88)
		var full_m := MeshInstance3D.new()
		var fmm := SphereMesh.new(); fmm.radius = 1.12; fmm.height = 2.24
		full_m.mesh = fmm; full_m.position = Vector3(5.35, 3.65, -16.9); full_m.material_override = full_mat
		ext.add_child(full_m)

		var star_mat2 := StandardMaterial3D.new()
		star_mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star_mat2.disable_fog = true
		star_mat2.albedo_color = Color(0.92, 0.95, 1.0)
		for si in range(36):
			var st := MeshInstance3D.new()
			var sbm := BoxMesh.new(); var sz := rng.randf_range(0.06, 0.12); sbm.size = Vector3(sz, sz, 0.02)
			st.mesh = sbm; st.material_override = star_mat2
			st.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(2.6, 4.9), -16.8)
			st.set_meta("phase", float(si) * 0.9)
			ext.add_child(st)
			exterior_twinkle_nodes.append(st)

	else:
		# Búrka & blesky + ťažké mračná v hornej línii oboch okien
		var scloud_mat := StandardMaterial3D.new()
		scloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		scloud_mat.disable_fog = true
		scloud_mat.albedo_color = Color(0.11, 0.13, 0.22)
		for cx_o in [-6.8, -5.2, -3.5, 3.5, 5.2, 6.8]:
			var sc := MeshInstance3D.new()
			var scm := SphereMesh.new(); scm.radius = 1.10; scm.height = 1.20
			sc.mesh = scm; sc.position = Vector3(cx_o, 4.10, -16.2); sc.material_override = scloud_mat
			ext.add_child(sc)
		# Blesky viditeľné priamo cez okná pred vrcholkami hôr
		var bolt_mat := StandardMaterial3D.new()
		bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bolt_mat.disable_fog = true
		bolt_mat.albedo_color = Color(0.75, 0.92, 1.0)
		for bx in [-5.35, 5.35]:
			var segs := [
				[Vector3(bx, 4.25, -15.6), Vector3(bx + 0.28, 3.45, -15.6)],
				[Vector3(bx + 0.28, 3.45, -15.6), Vector3(bx - 0.22, 2.75, -15.6)],
				[Vector3(bx - 0.22, 2.75, -15.6), Vector3(bx + 0.16, 2.00, -15.6)],
			]
			for s in segs:
				var seg_m := _spawn_bolt_segment_mesh(s[0], s[1], 0.09, bolt_mat)
				ext.add_child(seg_m)
				exterior_lightning_meshes.append(seg_m)

	# Multi-layered Carpathian alpine peaks & jagged snow ridges in both window sightlines
	var mtn_mat := StandardMaterial3D.new()
	mtn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mtn_mat.disable_fog = true
	mtn_mat.vertex_color_use_as_albedo = true
	mtn_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var far_peaks := [
		{"pos": Vector3(-7.8, 0.7, -19.0), "r": 4.4, "h": 5.2, "snow": 0.45, "seed": 1101},
		{"pos": Vector3(-3.8, 0.7, -18.5), "r": 4.2, "h": 5.6, "snow": 0.42, "seed": 1102},
		{"pos": Vector3(0.0,  0.7, -19.2), "r": 4.8, "h": 6.0, "snow": 0.40, "seed": 1103},
		{"pos": Vector3(3.6,  0.7, -18.4), "r": 4.2, "h": 5.4, "snow": 0.44, "seed": 1104},
		{"pos": Vector3(7.6,  0.7, -18.8), "r": 4.4, "h": 5.0, "snow": 0.46, "seed": 1105}
	]
	for fp in far_peaks:
		var m_mesh := MeshInstance3D.new()
		m_mesh.mesh = _build_exterior_mountain_mesh(float(fp["r"]), float(fp["h"]), float(fp["snow"]), int(fp["seed"]), far_base, far_snow)
		m_mesh.position = fp["pos"]
		m_mesh.material_override = mtn_mat
		ext.add_child(m_mesh)

	var mid_peaks := [
		{"pos": Vector3(-7.0, 0.7, -14.2), "r": 3.0, "h": 2.65, "snow": 0.56, "seed": 2201},
		{"pos": Vector3(-3.2, 0.7, -14.6), "r": 3.2, "h": 2.95, "snow": 0.54, "seed": 2202},
		{"pos": Vector3(0.6,  0.7, -14.2), "r": 3.3, "h": 3.05, "snow": 0.58, "seed": 2203},
		{"pos": Vector3(3.4,  0.7, -14.6), "r": 3.0, "h": 2.75, "snow": 0.54, "seed": 2204},
		{"pos": Vector3(7.2,  0.7, -14.2), "r": 3.0, "h": 2.60, "snow": 0.60, "seed": 2205}
	]
	for mp2 in mid_peaks:
		var mid_mtn := MeshInstance3D.new()
		mid_mtn.mesh = _build_exterior_mountain_mesh(float(mp2["r"]), float(mp2["h"]), float(mp2["snow"]), int(mp2["seed"]), mid_base, mid_snow)
		mid_mtn.position = mp2["pos"]
		mid_mtn.material_override = mtn_mat
		ext.add_child(mid_mtn)

	# Útulná dedinka s teplými okienkami v údolí
	var house_mat := StandardMaterial3D.new()
	house_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	house_mat.disable_fog = true
	house_mat.albedo_color = Color(0.28, 0.22, 0.18) if exterior_vista_theme == "sun_mountains" else Color(0.11, 0.14, 0.20)
	var win_glow_mat := StandardMaterial3D.new()
	win_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_glow_mat.disable_fog = true
	win_glow_mat.albedo_color = Color(0.82, 0.92, 1.0) if exterior_vista_theme == "sun_mountains" else Color(1.0, 0.74, 0.28)
	for hp in [Vector3(-3.8, 1.25, -10.8), Vector3(-1.95, 1.35, -11.4), Vector3(1.9, 1.30, -11.2), Vector3(3.6, 1.25, -10.6)]:
		var hbox := MeshInstance3D.new()
		var hbm := BoxMesh.new(); hbm.size = Vector3(1.15, 0.95, 0.95)
		hbox.mesh = hbm; hbox.position = hp; hbox.material_override = house_mat
		ext.add_child(hbox)
		var roof := MeshInstance3D.new()
		var rc := CylinderMesh.new(); rc.top_radius = 0.04; rc.bottom_radius = 0.85; rc.height = 0.68; rc.radial_segments = 4
		roof.mesh = rc; roof.rotation_degrees.y = 45.0; roof.position = hp + Vector3(0, 0.80, 0); roof.material_override = house_mat
		ext.add_child(roof)
		for wx_o in [-0.24, 0.24]:
			var hw := MeshInstance3D.new()
			var hwm := BoxMesh.new(); hwm.size = Vector3(0.18, 0.24, 0.04)
			hw.mesh = hwm; hw.position = hp + Vector3(wx_o, 0.06, 0.49); hw.material_override = win_glow_mat
			ext.add_child(hw)

	var pine_mat := StandardMaterial3D.new()
	pine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pine_mat.disable_fog = true
	pine_mat.albedo_color = Color(0.10, 0.26, 0.14) if exterior_vista_theme == "sun_mountains" else Color(0.06, 0.16, 0.14)
	for pi in range(14):
		var pine := Node3D.new()
		var px := -7.2 + float(pi) * 1.12
		var pz := rng.randf_range(-12.6, -8.5)
		pine.position = Vector3(px, 0.85, pz)
		pine.set_meta("phase", rng.randf_range(0.0, TAU))
		var cone := MeshInstance3D.new()
		var cc := CylinderMesh.new(); cc.top_radius = 0.04; cc.bottom_radius = 0.55; cc.height = rng.randf_range(1.6, 2.5); cc.radial_segments = 7
		cone.mesh = cc; cone.position.y = 1.0; cone.material_override = pine_mat
		pine.add_child(cone)
		ext.add_child(pine)
		exterior_pine_nodes.append(pine)

func _spawn_bolt_segment_mesh(a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var seg := MeshInstance3D.new()
	var diff := b - a
	var diff_len := diff.length()
	var length := maxf(0.04, diff_len)
	var bm := BoxMesh.new()
	bm.size = Vector3(thickness, length, thickness)
	seg.mesh = bm
	seg.material_override = mat
	seg.position = (a + b) * 0.5
	if diff_len < 0.0005:
		seg.rotation = Vector3.ZERO
		return seg
	var dir := diff / diff_len
	if absf(dir.dot(Vector3.UP)) > 0.985:
		seg.rotation = Vector3.ZERO
	else:
		var up_vec := Vector3.FORWARD if absf(dir.dot(Vector3.RIGHT)) > 0.96 else Vector3.RIGHT
		seg.look_at_from_position((a + b) * 0.5, (a + b) * 0.5 + dir, up_vec)
		seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	return seg

func _build_exterior_mountain_mesh(radius: float, height: float, snow_line: float, seed_val: int, base_col: Color, snow_col: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var rings := 5
	var grid: Array = []
	for r_i in range(rings + 1):
		var t_h := float(r_i) / float(rings)
		var ring_pts: Array = []
		for s_i in range(segs):
			var ang := (float(s_i) / float(segs)) * TAU
			var ridge := 1.0 + 0.24 * sin(ang * 3.0 + float(seed_val)) + 0.14 * cos(ang * 5.0 - float(seed_val) * 0.5)
			var cur_r := lerpf(radius, 0.08, pow(t_h, 0.85)) * ridge
			var jitter_y := rng.randf_range(-0.18, 0.18) if (r_i > 0 and r_i < rings) else 0.0
			var skew_x := t_h * rng.randf_range(-0.35, 0.35) if r_i == rings else 0.0
			var vx := cos(ang) * cur_r + skew_x
			var vz := sin(ang) * cur_r * 0.72
			var vy := t_h * height + jitter_y
			ring_pts.append({"pos": Vector3(vx, vy, vz), "th": t_h, "ang": ang})
		grid.append(ring_pts)

	for r_i in range(rings):
		var row0: Array = grid[r_i]
		var row1: Array = grid[r_i + 1]
		for s_i in range(segs):
			var sn := (s_i + 1) % segs
			var a: Dictionary = row0[s_i]
			var b: Dictionary = row0[sn]
			var c: Dictionary = row1[s_i]
			var d: Dictionary = row1[sn]
			for tri in [[a, b, c], [b, d, c]]:
				for v in tri:
					var vt := float(v["th"])
					var moon_shade := 0.5 + 0.5 * cos(float(v["ang"]) - 0.8)
					var snow_t := clampf((vt - snow_line) / maxf(0.12, 1.0 - snow_line), 0.0, 1.0)
					var rock := base_col.lerp(base_col.lightened(0.28), vt * 0.55 + moon_shade * 0.25)
					var col := rock.lerp(snow_col.lerp(Color.WHITE, moon_shade * 0.30), smoothstep(0.0, 1.0, snow_t))
					st.set_color(col)
					st.add_vertex(v["pos"])
	st.generate_normals()
	return st.commit()

func _spawn_wall_trophy(pos: Vector3, iron_mat: Material, wood_mat: Material) -> void:
	var t_root := Node3D.new()
	t_root.position = pos
	add_child(t_root)
	var trophy_glb := _load_glb_model("res://assets/models/wall_trophy.glb", true)
	if trophy_glb:
		t_root.add_child(trophy_glb)
		return
	var shield := MeshInstance3D.new()
	var sc := CylinderMesh.new(); sc.top_radius = 0.34; sc.bottom_radius = 0.34; sc.height = 0.05; sc.radial_segments = 8
	shield.mesh = sc; shield.rotation_degrees.x = 90.0; shield.material_override = wood_mat
	t_root.add_child(shield)
	var boss := MeshInstance3D.new()
	var bm := SphereMesh.new(); bm.radius = 0.11; bm.height = 0.10
	boss.mesh = bm; boss.position = Vector3(0, 0, 0.03); boss.material_override = iron_mat
	t_root.add_child(boss)

func _spawn_tavern_hearth(pos: Vector3, stone_mat: Material, wood_mat: Material) -> void:
	var hearth := Node3D.new()
	hearth.position = pos
	add_child(hearth)

	var h_iron := Toon.pbr(Color(0.14, 0.14, 0.16), "", 0.46, 0.84)
	var hearth_glb := _load_glb_model("res://assets/models/tavern_hearth.glb", true)
	if hearth_glb:
		var h_ember := ShaderMaterial.new()
		h_ember.shader = load("res://shaders/ember_bed.gdshader")
		var h_soot := Toon.pbr(Color(0.05, 0.045, 0.05), "", 0.96, 0.0)
		_apply_mat_by_mesh_name(hearth_glb, {
			"hearthembercore": h_ember,
			"hearthback": h_soot,
			"andiron": h_iron,
			"hearthmantel": wood_mat,
			"firelog": wood_mat,
			"hearthslab": stone_mat,
			"hearthjamb": stone_mat,
			"hearthcorbel": stone_mat,
			"hearthhood": stone_mat,
			"archstone": stone_mat,
		})
		hearth.add_child(hearth_glb)
	else:
		var back_stone := MeshInstance3D.new()
		var bsm := BoxMesh.new(); bsm.size = Vector3(0.55, 3.6, 1.95)
		back_stone.mesh = bsm; back_stone.position = Vector3(-0.2, 1.8, 0); back_stone.material_override = stone_mat
		hearth.add_child(back_stone)
		var mantle := MeshInstance3D.new()
		var mm := BoxMesh.new(); mm.size = Vector3(0.75, 0.16, 2.15)
		mantle.mesh = mm; mantle.position = Vector3(0.05, 1.48, 0); mantle.material_override = wood_mat
		hearth.add_child(mantle)

	# 6 křížících se vrstvených plamenných pásů v krbu (tavern_hearth_fire.gdshader)
	var hearth_flame_mat := ShaderMaterial.new()
	hearth_flame_mat.shader = load("res://shaders/tavern_hearth_fire.gdshader")
	hearth_flame_mat.set_shader_parameter("speed", 2.6)
	hearth_flame_mat.set_shader_parameter("intensity", 2.5)
	for fi in range(6):
		var f_ang := float(fi) * 30.0
		var flame_strip := MeshInstance3D.new()
		var fqm := QuadMesh.new()
		fqm.size = Vector2(0.32 + float(fi % 3) * 0.07, 0.44 + float(fi % 2) * 0.22)
		fqm.subdivide_width = 4
		fqm.subdivide_depth = 8
		flame_strip.mesh = fqm
		flame_strip.position = Vector3(0.32 + sin(deg_to_rad(f_ang)) * 0.05, 0.44, cos(deg_to_rad(f_ang)) * 0.12)
		flame_strip.rotation_degrees = Vector3(0.0, f_ang, (float(fi % 3) - 1.0) * 6.0)
		flame_strip.material_override = hearth_flame_mat
		flame_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hearth.add_child(flame_strip)

	# Stoupající jiskry a žhavé uhlíky do komína (GPUParticles3D)
	var spark_gp := GPUParticles3D.new()
	spark_gp.name = "HearthSparks"
	spark_gp.amount = 36
	spark_gp.lifetime = 2.2
	spark_gp.position = Vector3(0.32, 0.36, 0.0)
	var spark_proc := ParticleProcessMaterial.new()
	spark_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spark_proc.emission_box_extents = Vector3(0.16, 0.08, 0.28)
	spark_proc.direction = Vector3(0.08, 1.0, 0.0)
	spark_proc.spread = 22.0
	spark_proc.gravity = Vector3(0.0, 0.18, 0.0)
	spark_proc.initial_velocity_min = 0.45
	spark_proc.initial_velocity_max = 0.95
	spark_proc.scale_min = 0.5
	spark_proc.scale_max = 1.2
	spark_gp.process_material = spark_proc
	var spark_qm := QuadMesh.new()
	spark_qm.size = Vector2(0.032, 0.032)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	spark_mat.albedo_texture = Fx.soft_tex()
	spark_mat.albedo_color = Color(1.0, 0.58, 0.18, 0.92)
	spark_qm.material = spark_mat
	spark_gp.draw_pass_1 = spark_qm
	hearth.add_child(spark_gp)

	# Kovaný pohrabáč a stojan na polena vedle krbu
	var poker := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.011; pm.bottom_radius = 0.014; pm.height = 0.88
	poker.mesh = pm; poker.position = Vector3(0.56, 0.44, 0.96); poker.rotation_degrees.x = -10.0
	poker.material_override = h_iron
	hearth.add_child(poker)
	for li_log in range(3):
		var log_m := MeshInstance3D.new()
		var lm := CylinderMesh.new(); lm.top_radius = 0.075; lm.bottom_radius = 0.082; lm.height = 0.48
		log_m.mesh = lm
		var row_y := 0.14 if li_log < 2 else 0.26
		var row_z := -1.04 + float(li_log % 2) * 0.15 if li_log < 2 else -0.965
		log_m.position = Vector3(0.44, row_y, row_z)
		log_m.rotation_degrees.z = 90.0
		log_m.material_override = wood_mat
		hearth.add_child(log_m)

	hearth_fire_light = OmniLight3D.new()
	hearth_fire_light.position = Vector3(0.65, 0.55, 0.0)
	hearth_fire_light.light_color = Color(1.0, 0.56, 0.18)
	hearth_fire_light.light_energy = 2.8
	hearth_fire_light.omni_range = 6.2
	hearth_fire_light.shadow_enabled = true
	hearth_fire_light.shadow_bias = 0.05
	hearth.add_child(hearth_fire_light)

func _spawn_crate(pos: Vector3, s: float, wood_mat: Material) -> void:
	var c := MeshInstance3D.new()
	var cb := BoxMesh.new(); cb.size = Vector3(s, s, s)
	c.mesh = cb; c.position = pos + Vector3(0, s * 0.5, 0); c.rotation_degrees.y = randf() * 35.0
	c.material_override = wood_mat
	add_child(c)

func _spawn_wall_banner(pos: Vector3, fabric_col: Color, trim_col: Color) -> void:
	var root := Node3D.new()
	root.name = "WallBannerRoot"
	root.position = pos
	add_child(root)
	var banner_glb := _load_glb_model("res://assets/models/tavern_banner.glb", true)
	if banner_glb:
		banner_glb.name = "TavernBannerGLB"
		var cloth_mat := Toon.pbr(fabric_col, "", 0.84, 0.04, Vector2.ONE, fabric_col * 0.06)
		cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var trim_mat := Toon.pbr(trim_col, "", 0.28, 0.84, Vector2.ONE, trim_col * 0.12)
		_apply_mat_by_mesh_name(banner_glb, {
			"bannercloth": cloth_mat,
			"bannertrim": trim_mat,
		})
		root.add_child(banner_glb)
		return
	var rod := MeshInstance3D.new()
	var rc := CylinderMesh.new(); rc.top_radius = 0.025; rc.bottom_radius = 0.025; rc.height = 0.92
	rod.mesh = rc; rod.rotation_degrees.z = 90.0; rod.position = Vector3(0, 0.72, 0)
	rod.material_override = Toon.mat(trim_col, "", 0.008)
	root.add_child(rod)

func _spawn_chandelier_volumetric_cone() -> void:
	if is_instance_valid(chandelier_cone_mesh):
		return
	chandelier_cone_mesh = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.14
	cone.bottom_radius = 1.62
	cone.height = 2.10
	cone.radial_segments = 32
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	chandelier_cone_mesh.mesh = cone
	chandelier_cone_mesh.position = Vector3(0.0, 1.72, 0.02)
	chandelier_cone_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cone_shader := Shader.new()
	cone_shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
varying float v_y;
void vertex() {
	v_y = clamp((VERTEX.y + 1.05) / 2.10, 0.0, 1.0);
}
void fragment() {
	float fres = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.35);
	float vert_fade = smoothstep(0.0, 0.28, v_y) * smoothstep(1.0, 0.55, v_y);
	float dust_wave = 0.85 + 0.15 * sin(TIME * 1.4 + v_y * 9.0);
	ALBEDO = vec3(1.0, 0.76, 0.36);
	ALPHA = fres * vert_fade * 0.085 * dust_wave;
}
"""
	var smat := ShaderMaterial.new()
	smat.shader = cone_shader
	chandelier_cone_mesh.material_override = smat
	add_child(chandelier_cone_mesh)

func _spawn_tavern_shop_bell(pos: Vector3) -> void:
	tavern_bell_root = Node3D.new()
	tavern_bell_root.position = pos
	tavern_bell_root.set_meta("base_pos", pos)
	tavern_bell_root.set_meta("base_scale", Vector3.ONE)
	tavern_bell_root.set_meta("prop_id", "bell")
	add_child(tavern_bell_root)

	RelicMesh.build_shop_bell_meshes(tavern_bell_root)

	var b_area := Area3D.new()
	b_area.name = "TavernBellArea"
	var b_col := CollisionShape3D.new()
	var b_box := BoxShape3D.new()
	b_box.size = Vector3(0.16, 0.14, 0.16)
	b_col.shape = b_box; b_col.position = Vector3(0, 0.05, 0)
	b_area.add_child(b_col)
	tavern_bell_root.add_child(b_area)

func _spawn_table_dice_and_coins() -> void:
	# Kožený mešec florinov, komíniky razených mincí & klikateľné kostené kocky (interaktívne krčmové rekvizity!)
	tavern_coins_root = Node3D.new()
	tavern_coins_root.position = Vector3(-0.72, 0.816, -0.32)
	tavern_coins_root.set_meta("base_pos", tavern_coins_root.position)
	tavern_coins_root.set_meta("base_scale", Vector3.ONE)
	tavern_coins_root.set_meta("prop_id", "coins")
	add_child(tavern_coins_root)

	RelicMesh.build_coins_pouch_meshes(tavern_coins_root)

	var c_area := Area3D.new()
	c_area.name = "TavernCoinsArea"
	var c_col := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(0.28, 0.16, 0.20)
	c_col.shape = c_box
	c_col.position = Vector3(0.02, 0.05, 0.0)
	c_area.add_child(c_col)
	tavern_coins_root.add_child(c_area)

	# Dve vyrezávané kostené kocky vedľa mešca (klikateľné pre hod kockami!)
	tavern_dice_root = Node3D.new()
	tavern_dice_root.position = Vector3(-0.52, 0.832, -0.26)
	tavern_dice_root.set_meta("base_pos", tavern_dice_root.position)
	tavern_dice_root.set_meta("base_scale", Vector3.ONE)
	tavern_dice_root.set_meta("prop_id", "dice")
	add_child(tavern_dice_root)
	RelicMesh.build_bone_dice_meshes(tavern_dice_root)

	var d_area := Area3D.new()
	d_area.name = "TavernDiceArea"
	var d_col := CollisionShape3D.new()
	var d_box := BoxShape3D.new()
	d_box.size = Vector3(0.14, 0.10, 0.12)
	d_col.shape = d_box
	d_area.add_child(d_col)
	tavern_dice_root.add_child(d_area)

func _spawn_wall_lantern(pos: Vector3, iron_mat: Material, rot_y: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	wall_lantern_roots.append(root)

	var lan_glb := _load_glb_model("res://assets/models/tavern_lantern.glb", true)
	if lan_glb:
		root.add_child(lan_glb)
	else:
		var body := MeshInstance3D.new()
		var bb := BoxMesh.new(); bb.size = Vector3(0.14, 0.24, 0.14)
		body.mesh = bb; body.material_override = Toon.mat(Color(1.0, 0.72, 0.30), "", 0.01, Vector2.ONE, Color(0.95, 0.55, 0.18))
		root.add_child(body)
		var cap := MeshInstance3D.new()
		var cc := CylinderMesh.new(); cc.top_radius = 0.02; cc.bottom_radius = 0.14; cc.height = 0.12
		cap.mesh = cc; cap.position = Vector3(0, 0.17, 0); cap.material_override = iron_mat
		root.add_child(cap)

	var lan_flame_mat := ShaderMaterial.new()
	lan_flame_mat.shader = load("res://shaders/tavern_hearth_fire.gdshader")
	lan_flame_mat.set_shader_parameter("speed", 3.2)
	lan_flame_mat.set_shader_parameter("intensity", 2.8)
	for cross_y in [0.0, 90.0]:
		var l_flame := MeshInstance3D.new()
		var lqm := QuadMesh.new(); lqm.size = Vector2(0.045, 0.075); lqm.subdivide_depth = 4
		l_flame.mesh = lqm; l_flame.position = Vector3(0, -0.01, 0.16); l_flame.rotation_degrees.y = cross_y
		l_flame.material_override = lan_flame_mat
		l_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(l_flame)

	var l_light := OmniLight3D.new()
	l_light.position = Vector3(0, 0, 0.28)
	l_light.light_color = Color(1.0, 0.68, 0.30)
	l_light.light_energy = 1.8
	l_light.omni_range = 3.6
	root.add_child(l_light)
	lantern_lights.append(l_light)

	var l_halo := Sprite3D.new()
	l_halo.texture = Fx.soft_tex()
	l_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l_halo.position = Vector3(0, -0.02, 0.24)
	l_halo.modulate = Color(1.0, 0.68, 0.24, 0.34)
	l_halo.pixel_size = 0.0095
	l_halo.no_depth_test = false
	var lh_mat := StandardMaterial3D.new()
	lh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	lh_mat.albedo_texture = Fx.soft_tex()
	lh_mat.albedo_color = Color(1.0, 0.68, 0.24, 0.32)
	l_halo.material_override = lh_mat
	root.add_child(l_halo)

func _spawn_candle(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var cand_glb := _load_glb_model("res://assets/models/candelabra.glb", true)
	if cand_glb:
		cand_glb.name = "CandelabraGLB"
		root.add_child(cand_glb)
	else:
		var brass := Toon.mat(Color(0.76, 0.56, 0.22), "", 0.005)
		var base := MeshInstance3D.new()
		var bc := CylinderMesh.new(); bc.top_radius = 0.032; bc.bottom_radius = 0.078; bc.height = 0.035; bc.radial_segments = 14
		base.mesh = bc; base.position.y = 0.018; base.material_override = brass
		root.add_child(base)

	var candle_flame_mat := ShaderMaterial.new()
	candle_flame_mat.shader = load("res://shaders/tavern_hearth_fire.gdshader")
	candle_flame_mat.set_shader_parameter("speed", 3.2)
	candle_flame_mat.set_shader_parameter("intensity", 2.8)
	for ci in range(2):
		var cx := -0.074 if ci == 0 else 0.074
		var top_y := 0.238 if ci == 0 else 0.250
		for cross_y in [0.0, 90.0]:
			var flame := MeshInstance3D.new()
			var fqm := QuadMesh.new(); fqm.size = Vector2(0.028, 0.052); fqm.subdivide_depth = 4
			flame.mesh = fqm; flame.position = Vector3(cx, top_y + 0.016, 0.0); flame.rotation_degrees.y = cross_y
			flame.material_override = candle_flame_mat
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(flame)
		var f_halo := Sprite3D.new()
		f_halo.texture = Fx.soft_tex()
		f_halo.position = Vector3(cx, top_y + 0.008, 0.0)
		f_halo.pixel_size = 0.0042
		var fh_mat := StandardMaterial3D.new()
		fh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fh_mat.albedo_texture = Fx.soft_tex()
		fh_mat.albedo_color = Color(1.0, 0.72, 0.24, 0.44)
		f_halo.material_override = fh_mat
		root.add_child(f_halo)
	var glow := OmniLight3D.new()
	glow.position.y = 0.27
	glow.light_color = Color(1.0, 0.68, 0.34)
	glow.light_energy = 1.15
	glow.omni_range = 1.4
	root.add_child(glow)

func _spawn_mug(pos: Vector3) -> void:
	# Striebro-zlatý krčah a pohár duelanta (klikateľný pre prípitok!)
	tavern_mug_root = Node3D.new()
	tavern_mug_root.position = pos
	tavern_mug_root.set_meta("base_pos", pos)
	tavern_mug_root.set_meta("base_scale", Vector3.ONE)
	tavern_mug_root.set_meta("prop_id", "mug")
	add_child(tavern_mug_root)

	RelicMesh.build_tavern_mug_meshes(tavern_mug_root)

	var m_area := Area3D.new()
	m_area.name = "TavernMugArea"
	var m_col := CollisionShape3D.new()
	var m_box := BoxShape3D.new()
	m_box.size = Vector3(0.18, 0.18, 0.18)
	m_col.shape = m_box
	m_col.position = Vector3(0.0, 0.07, 0.0)
	m_area.add_child(m_col)
	tavern_mug_root.add_child(m_area)

# ============================================================================
# 4. HRÁČOVA 3D KAMERA, TELO DUELANTA, ARTIKULOVANÉ RUKY & VEJÁR KARIET
# ============================================================================
func _setup_player_camera_and_3d_hands() -> void:
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 1.66, 1.52)
	cam.rotation_degrees = base_cam_rot
	cam.fov = 72.0
	add_child(cam)

	# Viditeľné 3D Telo sediaceho hráča (umiestnené priamo POD kamerou: pri normálnom pohľade nevidno, viditeľné až pri sklopení pohľadu nadol!)
	player_body_root = Node3D.new()
	player_body_root.position = Vector3(0.0, 0.64, 1.56)
	player_body_root.rotation_degrees = Vector3(6.0, 0.0, 0.0)
	add_child(player_body_root)

	var tunic_mat := Toon.mat(Color(0.28, 0.12, 0.14), "", 0.008)
	var shirt_mat := Toon.mat(Color(0.84, 0.78, 0.68), "", 0.005)
	var strap_mat := Toon.mat(Color(0.28, 0.16, 0.09), "res://assets/gloves/glove_leather.png", 0.006)
	var buckle_mat := Toon.mat(Color(0.88, 0.68, 0.24), "", 0.004)
	var trouser_mat := Toon.mat(Color(0.12, 0.10, 0.12), "", 0.008)

	var torso := MeshInstance3D.new()
	var tcyl := CylinderMesh.new(); tcyl.top_radius = 0.24; tcyl.bottom_radius = 0.20; tcyl.height = 0.46; tcyl.radial_segments = 16
	torso.mesh = tcyl; torso.position = Vector3(0.0, 0.14, 0.0); torso.scale = Vector3(1.16, 1.0, 0.56)
	torso.material_override = tunic_mat; torso.set_meta("part_role", "tunic")
	player_body_root.add_child(torso)

	var collar := MeshInstance3D.new()
	var cbox := CylinderMesh.new(); cbox.top_radius = 0.10; cbox.bottom_radius = 0.12; cbox.height = 0.06; cbox.radial_segments = 12
	collar.mesh = cbox; collar.position = Vector3(0.0, 0.34, 0.01); collar.scale = Vector3(1.1, 1.0, 0.72)
	collar.material_override = shirt_mat; collar.set_meta("part_role", "shirt")
	player_body_root.add_child(collar)

	var belt := MeshInstance3D.new()
	var bmesh := CylinderMesh.new(); bmesh.top_radius = 0.21; bmesh.bottom_radius = 0.21; bmesh.height = 0.075; bmesh.radial_segments = 16
	belt.mesh = bmesh; belt.position = Vector3(0.0, -0.02, 0.0); belt.scale = Vector3(1.18, 1.0, 0.58)
	belt.material_override = strap_mat; belt.set_meta("part_role", "strap")
	player_body_root.add_child(belt)

	var belt_buckle := MeshInstance3D.new()
	var bb := BoxMesh.new(); bb.size = Vector3(0.085, 0.088, 0.028)
	belt_buckle.mesh = bb; belt_buckle.position = Vector3(0.0, -0.02, -0.122)
	belt_buckle.material_override = buckle_mat; belt_buckle.set_meta("part_role", "metal")
	player_body_root.add_child(belt_buckle)

	var baldric := MeshInstance3D.new()
	var bld := BoxMesh.new(); bld.size = Vector3(0.068, 0.50, 0.22)
	baldric.mesh = bld; baldric.position = Vector3(0.0, 0.16, -0.004); baldric.rotation_degrees.z = -34.0
	baldric.material_override = strap_mat; baldric.set_meta("part_role", "strap")
	player_body_root.add_child(baldric)

	for sx in [-0.30, 0.30]:
		var thigh := MeshInstance3D.new()
		var th_c := CylinderMesh.new(); th_c.top_radius = 0.088; th_c.bottom_radius = 0.074; th_c.height = 0.36; th_c.radial_segments = 12
		thigh.mesh = th_c; thigh.position = Vector3(signf(sx) * 0.13, -0.15, -0.17); thigh.rotation_degrees = Vector3(84.0, 0.0, -signf(sx) * 6.0)
		thigh.material_override = trouser_mat; thigh.set_meta("part_role", "tunic")
		player_body_root.add_child(thigh)

		var pauldron := MeshInstance3D.new()
		var pm := SphereMesh.new(); pm.radius = 0.098; pm.height = 0.16
		pauldron.mesh = pm; pauldron.position = Vector3(sx, 0.30, -0.01)
		pauldron.material_override = tunic_mat; pauldron.set_meta("part_role", "tunic")
		player_body_root.add_child(pauldron)

		var upper_arm := Node3D.new()
		upper_arm.position = Vector3(sx, 0.25, -0.02)
		var u_cyl := MeshInstance3D.new()
		var uc := CylinderMesh.new(); uc.top_radius = 0.064; uc.bottom_radius = 0.054; uc.height = 0.30; uc.radial_segments = 12
		u_cyl.mesh = uc; u_cyl.position = Vector3(signf(sx) * 0.035, -0.11, -0.09); u_cyl.rotation_degrees = Vector3(54.0, 0.0, -signf(sx) * 12.0)
		u_cyl.material_override = tunic_mat; u_cyl.set_meta("part_role", "tunic")
		upper_arm.add_child(u_cyl)
		var fore_cyl := MeshInstance3D.new()
		var fc := CylinderMesh.new(); fc.top_radius = 0.052; fc.bottom_radius = 0.044; fc.height = 0.24; fc.radial_segments = 12
		fore_cyl.mesh = fc; fore_cyl.position = Vector3(signf(sx) * 0.065, -0.18, -0.22); fore_cyl.rotation_degrees = Vector3(76.0, 0.0, -signf(sx) * 8.0)
		fore_cyl.material_override = strap_mat; fore_cyl.set_meta("part_role", "strap")
		upper_arm.add_child(fore_cyl)
		player_body_root.add_child(upper_arm)
		if sx < 0.0:
			player_arm_left = upper_arm
		else:
			player_arm_right = upper_arm

	# Hráčove artikulované 3D ruky a 3D karty priamo v 3D priestore pred ním
	player_hand_anchor = Node3D.new()
	player_hand_anchor.position = HAND_POS_TUCKED
	player_hand_anchor.rotation_degrees = HAND_ROT_TUCKED
	add_child(player_hand_anchor)

	player_glove_left_mesh = _create_3d_glove_mesh(false)
	player_glove_left_mesh.position = Vector3(-0.34, -0.04, 0.05)
	player_glove_left_mesh.rotation_degrees = Vector3(26, -24, 18)
	player_hand_anchor.add_child(player_glove_left_mesh)

	player_glove_right_mesh = _create_3d_glove_mesh(true)
	player_glove_right_mesh.position = Vector3(0.34, -0.04, 0.05)
	player_glove_right_mesh.rotation_degrees = Vector3(26, 24, -18)
	player_hand_anchor.add_child(player_glove_right_mesh)

func _get_deck_back_tex_path(deck_id: String = "") -> String:
	var did: String = deck_id if deck_id != "" else str(player_deck_data.get("id", ""))
	match did:
		"klasic", "antika", "rim", "stredovek", "objavy":
			var p: String = "res://assets/table/deck_back_%s.png" % did
			if ResourceLoader.exists(p):
				return p
	var explicit_p: String = str(player_deck_data.get("back_tex", ""))
	if explicit_p != "" and ResourceLoader.exists(explicit_p):
		return explicit_p
	return "res://assets/table/card_back.png"

func _refresh_draw_deck_theme(chosen_deck: Dictionary) -> void:
	if not is_instance_valid(draw_deck_root):
		return
	var b_path := _get_deck_back_tex_path(str(chosen_deck.get("id", "klasic")))
	var deck_glb := draw_deck_root.get_node_or_null("DeckShoeGLB") as Node3D
	var btex := Toon.tex(b_path)
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.96, 0.94, 0.90)
	top_mat.roughness = 0.58
	top_mat.metallic = 0.04
	if btex:
		top_mat.albedo_texture = btex
		top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if deck_glb:
		_apply_mat_by_mesh_name(deck_glb, {"decktopcard": top_mat})
		var top_quad := draw_deck_root.get_node_or_null("DeckTopCardBackQuad") as MeshInstance3D
		if top_quad == null:
			top_quad = MeshInstance3D.new()
			top_quad.name = "DeckTopCardBackQuad"
			var qm := QuadMesh.new()
			qm.size = Vector2(0.188, 0.276)
			top_quad.mesh = qm
			top_quad.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			top_quad.position = Vector3(0.0, 0.0695, 0.0)
			top_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			draw_deck_root.add_child(top_quad)
		top_quad.material_override = top_mat
	var stack_mesh := draw_deck_root.get_node_or_null("DeckStackMesh") as MeshInstance3D
	if stack_mesh:
		stack_mesh.material_override = Toon.mat(Color(0.96, 0.94, 0.90), b_path, 0.004)
	var trim_root := draw_deck_root.get_node_or_null("DeckThemeTrim") as Node3D
	if not trim_root:
		return
	for ch in trim_root.get_children():
		ch.queue_free()

	var style_id: String = str(chosen_deck.get("box_style", chosen_deck.get("id", "klasic")))
	var acc_col: Color = chosen_deck.get("border_col", Color(0.86, 0.66, 0.24))
	var trim_mat: Material = Toon.pbr(acc_col, "", 0.30, 0.80)
	var dark_mat: Material = Toon.pbr(Color(0.18, 0.14, 0.12), "", 0.56, 0.35)
	if style_id == "antika":
		# Stepped gilded sandstone pedestal + solar scarab clasp front
		var plinth := MeshInstance3D.new()
		var pbox := BoxMesh.new(); pbox.size = Vector3(0.228, 0.014, 0.312)
		plinth.mesh = pbox; plinth.position = Vector3(0.0, 0.007, 0.0); plinth.material_override = trim_mat
		trim_root.add_child(plinth)
		var clasp := MeshInstance3D.new()
		var csph := SphereMesh.new(); csph.radius = 0.018; csph.height = 0.014
		clasp.mesh = csph; clasp.position = Vector3(0.0, 0.036, 0.146); clasp.material_override = Toon.pbr(Color(0.16, 0.42, 0.72), "", 0.28, 0.35)
		trim_root.add_child(clasp)
	elif style_id == "rim":
		# Imperial riveted bronze side bars & legion boss studs
		for sx in [-0.106, 0.106]:
			var bar := MeshInstance3D.new()
			var bbox := BoxMesh.new(); bbox.size = Vector3(0.014, 0.056, 0.290)
			bar.mesh = bbox; bar.position = Vector3(sx, 0.028, 0.0); bar.material_override = trim_mat
			trim_root.add_child(bar)
	elif style_id == "stredovek":
		# Forged wrought-iron Gothic corner angle brackets + dome rivets
		var iron_m := Toon.pbr(Color(0.22, 0.24, 0.28), "", 0.40, 0.84)
		for cx in [-0.098, 0.098]:
			for cz in [-0.140, 0.140]:
				var post := MeshInstance3D.new()
				var pbox := BoxMesh.new(); pbox.size = Vector3(0.022, 0.068, 0.022)
				post.mesh = pbox; post.position = Vector3(cx, 0.034, cz); post.material_override = iron_m
				trim_root.add_child(post)
				var stud := MeshInstance3D.new()
				var ssph := SphereMesh.new(); ssph.radius = 0.008; ssph.height = 0.014
				stud.mesh = ssph; stud.position = Vector3(cx, 0.070, cz); stud.material_override = trim_mat
				trim_root.add_child(stud)
	elif style_id == "objavy":
		# Coiled hemp-rope straps & nautical brass sea-chest clasps
		var rope_m := Toon.pbr(Color(0.68, 0.54, 0.32), "", 0.82, 0.04)
		for sz in [-0.08, 0.08]:
			var band := MeshInstance3D.new()
			var rbox := BoxMesh.new(); rbox.size = Vector3(0.214, 0.062, 0.014)
			band.mesh = rbox; band.position = Vector3(0.0, 0.031, sz); band.material_override = rope_m
			trim_root.add_child(band)
	elif style_id == "prohibicia":
		# Art-Deco brushed brass corner chevrons + dark lacquered mahogany bands
		var deco_gold := Toon.pbr(Color(0.92, 0.74, 0.28), "", 0.22, 0.88)
		for sx in [-0.105, 0.105]:
			var rail := MeshInstance3D.new()
			var rbx := BoxMesh.new(); rbx.size = Vector3(0.012, 0.064, 0.286)
			rail.mesh = rbx; rail.position = Vector3(sx, 0.032, 0.0); rail.material_override = deco_gold
			trim_root.add_child(rail)
		var front_plaque := MeshInstance3D.new()
		var fbx := BoxMesh.new(); fbx.size = Vector3(0.11, 0.024, 0.014)
		front_plaque.mesh = fbx; front_plaque.position = Vector3(0.0, 0.034, 0.144); front_plaque.material_override = deco_gold
		trim_root.add_child(front_plaque)
	elif style_id == "obsidian" or style_id == "reaper":
		# Pitch-black forged obsidian iron box + crimson hilt-wrap bands + glowing crimson seal
		var obsi_m := Toon.pbr(Color(0.06, 0.06, 0.08), "", 0.34, 0.86)
		var crim_m := Toon.pbr(Color(0.88, 0.10, 0.18), "", 0.36, 0.20, Vector2.ONE, Color(1.0, 0.14, 0.22), 0.72)
		for sz in [-0.072, 0.072]:
			var cord := MeshInstance3D.new()
			var cbx := BoxMesh.new(); cbx.size = Vector3(0.218, 0.058, 0.016)
			cord.mesh = cbx; cord.position = Vector3(0.0, 0.029, sz); cord.material_override = crim_m
			trim_root.add_child(cord)
		for cx in [-0.100, 0.100]:
			for cz in [-0.142, 0.142]:
				var cap := MeshInstance3D.new()
				var cpb := BoxMesh.new(); cpb.size = Vector3(0.020, 0.068, 0.020)
				cap.mesh = cpb; cap.position = Vector3(cx, 0.034, cz); cap.material_override = obsi_m
				trim_root.add_child(cap)
	elif style_id == "astral" or style_id == "quincy":
		# Pure ivory-silver astral frame + glowing electric-cyan compass emblem
		var silver_m := Toon.pbr(Color(0.88, 0.93, 0.98), "", 0.18, 0.92)
		var cyan_m := Toon.pbr(Color(0.22, 0.90, 1.0), "", 0.14, 0.35, Vector2.ONE, Color(0.24, 0.94, 1.0), 1.45)
		for sx in [-0.105, 0.105]:
			var bar_q := MeshInstance3D.new()
			var bqx := BoxMesh.new(); bqx.size = Vector3(0.014, 0.064, 0.292)
			bar_q.mesh = bqx; bar_q.position = Vector3(sx, 0.032, 0.0); bar_q.material_override = silver_m
			trim_root.add_child(bar_q)
		var q_cross_v := MeshInstance3D.new()
		var qbv := BoxMesh.new(); qbv.size = Vector3(0.012, 0.044, 0.012)
		q_cross_v.mesh = qbv; q_cross_v.position = Vector3(0.0, 0.036, 0.145); q_cross_v.material_override = cyan_m
		trim_root.add_child(q_cross_v)
		var q_cross_h := MeshInstance3D.new()
		var qbh := BoxMesh.new(); qbh.size = Vector3(0.042, 0.012, 0.012)
		q_cross_h.mesh = qbh; q_cross_h.position = Vector3(0.0, 0.040, 0.145); q_cross_h.material_override = cyan_m
		trim_root.add_child(q_cross_h)
	else:
		# Classic saddle-leather cross straps with brass corner rivets
		for sz in [-0.075, 0.075]:
			var strap := MeshInstance3D.new()
			var sbox := BoxMesh.new(); sbox.size = Vector3(0.214, 0.052, 0.016)
			strap.mesh = sbox; strap.position = Vector3(0.0, 0.026, sz); strap.material_override = dark_mat
			trim_root.add_child(strap)
		for cx in [-0.094, 0.094]:
			var rivet := MeshInstance3D.new()
			var rsph := SphereMesh.new(); rsph.radius = 0.007; rsph.height = 0.012
			rivet.mesh = rsph; rivet.position = Vector3(cx, 0.070, 0.132); rivet.material_override = trim_mat
			trim_root.add_child(rivet)

# Vytvorenie skutočnej 3D karty v priestore (podporuje custom Power karty, Edície & vlastné PNG assety)
func _build_3d_card_node(card_data: Dictionary, face_up: bool, back_border_col: Color, back_tex_override: String = "") -> Node3D:
	var card_root := Node3D.new()
	var df := _get_font(true)
	var p_id: String = str(card_data.get("power_id", ""))
	var is_power := p_id != ""
	var ed_id: String = Catalog.normalize_card_class(str(card_data.get("edition", "NORMAL")))
	var ed_info: Dictionary = Catalog.get_card_class(ed_id)
	var shader_ed_id: int = int(ed_info.get("shader_id", 0))
	var is_mist_hidden := bool(card_data.get("_mist_hidden", false))
	var m_chg := int(card_data.get("mage_charge", 0))
	var m_max := maxi(1, int(ed_info.get("max_charge", 2)))
	var acc_col: Color = card_data.get("accent", ed_info.get("col", Color(1.0, 0.84, 0.32)))

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "CardFaceMesh"
	var qquad := QuadMesh.new()
	qquad.size = Vector2(0.185, 0.275)
	mesh_inst.mesh = qquad
	mesh_inst.position = Vector3(0.0, 0.0, 0.0026)

	var mat: Material
	var has_custom_tex := false
	if face_up:
		# Vlastná grafika: Power karty hľadajú `res://assets/cards/SPEC_<ID>.png`, klasické `<SUIT>_<RANK>.png`
		var tex_path: String = "res://assets/cards/%s.png" % p_id if is_power else "res://assets/cards/%s_%s.png" % [card_data["suit"], card_data["rank"]]
		has_custom_tex = ResourceLoader.exists(tex_path)
		var smat := ShaderMaterial.new()
		smat.shader = CARD_FX_SHADER
		smat.set_shader_parameter("use_texture", has_custom_tex)
		if has_custom_tex:
			smat.set_shader_parameter("albedo_tex", load(tex_path))
		smat.set_shader_parameter("albedo", Color(0.95, 0.92, 0.85) if has_custom_tex else (Color(0.24, 0.18, 0.30) if is_power else Color(0.95, 0.92, 0.85)))
		smat.set_shader_parameter("edition_id", shader_ed_id)
		smat.set_shader_parameter("is_power_card", 1.0 if is_power else 0.0)
		smat.set_shader_parameter("is_back", 0.0)
		smat.set_shader_parameter("accent_color", acc_col)
		smat.set_shader_parameter("hover_glow", 0.0)
		smat.set_shader_parameter("tilt_vec", Vector2.ZERO)
		smat.set_shader_parameter("debuffed", 0.0)
		smat.set_shader_parameter("mage_charge", clampf(float(m_chg) / float(m_max), 0.0, 1.0) if ed_id == "MAGE" else 0.0)
		smat.set_shader_parameter("mist_shroud", 1.0 if is_mist_hidden else 0.0)
		mat = smat
	else:
		var back_p := back_tex_override if back_tex_override != "" else _get_deck_back_tex_path()
		var back_tex := Toon.tex(back_p)
		var bmat := ShaderMaterial.new()
		bmat.shader = CARD_FX_SHADER
		bmat.set_shader_parameter("use_texture", back_tex != null)
		if back_tex != null:
			bmat.set_shader_parameter("albedo_tex", back_tex)
		bmat.set_shader_parameter("albedo", Color(0.96, 0.94, 0.90))
		bmat.set_shader_parameter("is_back", 1.0)
		bmat.set_shader_parameter("edition_id", 0)
		bmat.set_shader_parameter("accent_color", back_border_col)
		mat = bmat
	mesh_inst.material_override = mat
	card_root.add_child(mesh_inst)
	card_root.set_meta("card_class_id", ed_id)
	card_root.set_meta("is_power_card", is_power)

	# Rámik a telo karty (Knight = hrubší kovový plát, Mage = arkánový lem)
	var rim := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	var is_knight_plate := (face_up and ed_id == "KNIGHT")
	var is_mage_aura := (face_up and ed_id == "MAGE")
	rbox.size = Vector3(0.200 if is_knight_plate else (0.202 if is_mage_aura else 0.194), 0.290 if is_knight_plate else (0.292 if is_mage_aura else 0.284), 0.0072 if is_knight_plate else (0.0055 if is_mage_aura else 0.004))
	rim.mesh = rbox
	rim.position = Vector3(0.0, 0.0, -0.0020 if is_knight_plate else (-0.0022 if is_mage_aura else 0.0))
	var rim_col := Color(0.68, 0.78, 0.88) if is_knight_plate else (Color(0.32, 0.72, 1.0) if is_mage_aura else (acc_col if (face_up and (is_power or shader_ed_id > 0)) else back_border_col))
	var rim_emit := acc_col * (1.15 if is_mage_aura else 0.45) if (face_up and (is_power or shader_ed_id > 0)) else Color.BLACK
	if is_knight_plate:
		rim.material_override = Toon.pbr(rim_col, "", 0.20, 0.92, Vector2.ONE, Color(0.45, 0.78, 1.0), 0.35)
	else:
		rim.material_override = Toon.mat(rim_col, "", 0.0, Vector2.ONE, rim_emit)
	card_root.add_child(rim)

	if is_mage_aura and not is_mist_hidden:
		var mage_halo := MeshInstance3D.new()
		mage_halo.name = "MageArcaneRimHalo"
		var hbox := BoxMesh.new()
		hbox.size = Vector3(0.214, 0.306, 0.0025)
		mage_halo.mesh = hbox
		mage_halo.position = Vector3(0.0, 0.0, -0.0046)
		var hmat := StandardMaterial3D.new()
		hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hmat.albedo_color = Color(0.28, 0.68, 1.0, 0.42)
		hmat.emission_enabled = true
		hmat.emission = acc_col.lerp(Color(0.32, 0.74, 1.0), 0.5)
		hmat.emission_energy_multiplier = 1.45
		mage_halo.material_override = hmat
		card_root.add_child(mage_halo)

	if face_up and shader_ed_id > 0 and not is_mist_hidden:
		Fx.attach_card_class_aura(card_root, shader_ed_id, acc_col)

	# Jemný kontaktný tieň pod kartou (dynamicky sa zväčšuje a zjemňuje pri nadvihnutí)
	var c_shadow := MeshInstance3D.new()
	c_shadow.name = "ContactShadow"
	var sh_quad := QuadMesh.new()
	sh_quad.size = Vector2(0.205, 0.295)
	c_shadow.mesh = sh_quad
	c_shadow.position = Vector3(0.010, -0.012, -0.004)
	var sh_mat := StandardMaterial3D.new()
	sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	sh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	c_shadow.material_override = sh_mat
	c_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card_root.add_child(c_shadow)

	if face_up:
		var s_obj := _get_suit_obj(card_data["suit"])
		var r_key: String = str(card_data["rank"])
		var full_custom_art := has_custom_tex and not is_power
		var corner_r_disp := r_key if opts_language == "cs" else str({"D": "J", "H": "Q", "K": "K", "E": "A"}.get(r_key, r_key))
		var corner_lbl := Label3D.new()
		corner_lbl.text = (s_obj["sym"] + ("★" if card_data.get("wild", false) else "")) if is_power else (s_obj["sym"] + corner_r_disp)
		corner_lbl.font = df
		corner_lbl.modulate = acc_col if is_power else s_obj["col"]
		corner_lbl.outline_size = 6 if is_power else 2
		corner_lbl.font_size = 24 if is_power else 28
		corner_lbl.pixel_size = 0.00145
		corner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		corner_lbl.position = Vector3(-0.076, 0.106, 0.004)
		corner_lbl.visible = (not full_custom_art) and (not is_mist_hidden)
		card_root.add_child(corner_lbl)

		if is_mist_hidden:
			var mist_q := Label3D.new()
			mist_q.text = _tr("? MIST ?", "? MLHA ?")
			mist_q.font = df
			mist_q.modulate = Color(0.84, 0.94, 1.0)
			mist_q.outline_size = 6
			mist_q.font_size = 24
			mist_q.pixel_size = 0.0015
			mist_q.position = Vector3(0.0, 0.015, 0.005)
			card_root.add_child(mist_q)
		elif shader_ed_id > 0:
			var ed_loc := Catalog.get_card_class_loc(ed_id, opts_language)
			var ed_lbl := Label3D.new()
			if ed_id == "MAGE":
				ed_lbl.text = _tr("MAGEREADY!", "MÁGPŘIPRAVEN!") if m_chg >= m_max else _tr("MAGE %d/%d" % [m_chg, m_max], "MÁG %d/%d" % [m_chg, m_max])
			elif ed_id == "MERCHANT":
				ed_lbl.text = _tr("GUILD +16g", "KUPEC +16g")
			else:
				ed_lbl.text = str(ed_loc.get("badge", ed_info.get("badge", "")))
			ed_lbl.font = df
			ed_lbl.modulate = Color(0.45, 0.96, 1.0) if (ed_id == "MAGE" and m_chg >= m_max) else ed_info.get("col", Color.CYAN)
			ed_lbl.font_size = 13
			ed_lbl.outline_size = 6
			ed_lbl.pixel_size = 0.00105
			ed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ed_lbl.position = Vector3(0.076, 0.106, 0.004)
			card_root.add_child(ed_lbl)
		elif is_power:
			var pw_tag := Label3D.new()
			pw_tag.text = _tr("WILD", "DIVOKÁ") if card_data.get("wild", false) else _tr("POWER", "MOCNÁ")
			pw_tag.font = df
			pw_tag.modulate = Color(1.0, 0.90, 0.42)
			pw_tag.font_size = 13
			pw_tag.outline_size = 5
			pw_tag.pixel_size = 0.00105
			pw_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pw_tag.position = Vector3(0.076, 0.106, 0.004)
			card_root.add_child(pw_tag)

		var center_lbl := Label3D.new()
		if is_power:
			center_lbl.text = ("★\n" if card_data.get("wild", false) else "✦\n") + str(card_data.get("short", "POWER"))
			center_lbl.modulate = Color(1.0, 0.96, 0.88)
			center_lbl.outline_size = 7
			center_lbl.font_size = 21
			center_lbl.pixel_size = 0.00125
			center_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			center_lbl.width = 130.0
			center_lbl.position = Vector3(0.0, 0.024, 0.004)
		else:
			center_lbl.text = s_obj["sym"] + " " + corner_r_disp + "\n" + _get_rank_name(r_key)
			center_lbl.modulate = s_obj["col"]
			center_lbl.font_size = 22
			center_lbl.pixel_size = 0.00145
			center_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			center_lbl.width = 120.0
			center_lbl.position = Vector3(0.0, 0.016, 0.004)
		center_lbl.font = df
		center_lbl.visible = (not has_custom_tex) and (not is_mist_hidden)
		card_root.add_child(center_lbl)

		var r_id: String = str(card_data["rank"])
		# Keep cards clean and readable: show ONLY Card Type/Class + Points (no "+10 gold" / "+2 draw" clutter on card art!)
		if is_power:
			var p_sub := Label3D.new()
			p_sub.name = "AbilityLabel"
			var pc_loc := Catalog.get_power_card_loc(str(card_data.get("power_id", "")), opts_language)
			p_sub.text = str(pc_loc.get("name", card_data.get("rname", card_data.get("name", _tr("POWER", "MOCNÁ")))))
			p_sub.font = df
			p_sub.modulate = Color(1.0, 0.90, 0.44)
			p_sub.outline_modulate = Color(0.04, 0.02, 0.02)
			p_sub.font_size = 13
			p_sub.outline_size = 4
			p_sub.pixel_size = 0.00105
			p_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p_sub.width = 142.0
			p_sub.position = Vector3(0.0, -0.072, 0.0042)
			p_sub.visible = not is_mist_hidden
			card_root.add_child(p_sub)

		var pts_lbl := Label3D.new()
		pts_lbl.name = "PtsLabel"
		pts_lbl.text = "+" + str(card_data["pts"]) + _tr(" pts", " b.")
		pts_lbl.font = df
		pts_lbl.modulate = Color(1.0, 0.92, 0.56)
		pts_lbl.outline_modulate = Color(0.05, 0.03, 0.02)
		pts_lbl.outline_size = 3
		pts_lbl.font_size = 16 if (full_custom_art or (is_power and has_custom_tex)) else 19
		pts_lbl.pixel_size = 0.00120 if (full_custom_art or (is_power and has_custom_tex)) else 0.00130
		pts_lbl.position = Vector3(0.0, -0.114 if full_custom_art else (-0.106 if is_power and has_custom_tex else -0.110), 0.0042)
		pts_lbl.visible = cards_points_revealed and (not is_mist_hidden)
		card_root.add_child(pts_lbl)

	return card_root

# ============================================================================
# 5. MINIMALISTICKÝ HUD & ŠTART ZÁPASU
# ============================================================================
func _make_plaque_style(bg_col: Color, border_col: Color, radius: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	return sb

func _make_bevel_btn_style(bg_col: Color, border_col: Color, is_pressed: bool = false, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col.darkened(0.24) if is_pressed else bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.border_width_top = 1 if is_pressed else 2
	sb.border_width_bottom = 2 if is_pressed else 4
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9 if is_pressed else 7
	sb.content_margin_bottom = 6 if is_pressed else 9
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 4 if is_pressed else 8
	sb.shadow_offset = Vector2(0, 1 if is_pressed else 3)
	return sb

func _style_action_button(btn: Button, bg_col: Color, border_col: Color, radius: int = 10) -> void:
	if not btn:
		return
	btn.add_theme_stylebox_override("normal", _make_bevel_btn_style(bg_col, border_col, false, radius))
	btn.add_theme_stylebox_override("hover", _make_bevel_btn_style(bg_col.lightened(0.18), border_col.lightened(0.25), false, radius))
	btn.add_theme_stylebox_override("pressed", _make_bevel_btn_style(bg_col, border_col, true, radius))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _load_blender_ui_tex(tex_name: String) -> Texture2D:
	if _ui_blender_tex_cache.has(tex_name):
		return _ui_blender_tex_cache[tex_name] as Texture2D
	var res_path := "res://assets/ui/blender/" + tex_name
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		var loaded := ResourceLoader.load(res_path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var abs_p := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_p):
			var img := Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_ui_blender_tex_cache[tex_name] = tex
	return tex

func _make_tex_panel_style(tex_name: String, hmargin: int = 0, vmargin: int = 0, mod_col: Color = Color.WHITE) -> StyleBox:
	var tex := _load_blender_ui_tex(tex_name)
	if tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.modulate_color = mod_col
		sb.content_margin_left = hmargin
		sb.content_margin_right = hmargin
		sb.content_margin_top = vmargin
		sb.content_margin_bottom = vmargin
		return sb
	return _make_plaque_style(Color(0.06, 0.045, 0.038, 0.94), Color(0.86, 0.66, 0.28, 0.90), 14)

func _style_blender_button(btn: Button, tex_name: String, normal: Color = Color.WHITE, hover: Color = Color(1.18, 1.13, 1.05), pressed: Color = Color(0.82, 0.78, 0.74), disabled: Color = Color(0.55, 0.55, 0.58, 0.76), hmargin: int = 10, vmargin: int = 4) -> void:
	if not btn:
		return
	var tex := _load_blender_ui_tex(tex_name)
	if tex != null:
		for st_pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled]]:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			sb.modulate_color = st_pair[1]
			sb.content_margin_left = hmargin
			sb.content_margin_right = hmargin
			sb.content_margin_top = vmargin
			sb.content_margin_bottom = vmargin
			btn.add_theme_stylebox_override(st_pair[0], sb)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	else:
		_style_action_button(btn, Color(0.14, 0.09, 0.09, 0.94), Color(0.86, 0.58, 0.30), 14)

func _make_ink_btn_style(glow_col: Color, is_hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(glow_col.r, glow_col.g, glow_col.b, 0.14 if is_hover else 0.0)
	sb.border_color = Color(glow_col.r, glow_col.g, glow_col.b, 0.85 if is_hover else 0.0)
	sb.set_border_width_all(0)
	if is_hover:
		sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _draw_feathered_oval(ctrl: Control, center: Vector2, radii: Vector2, base_col: Color) -> void:
	var steps := 5
	for i in range(steps):
		var frac := 1.0 - (float(i) / float(steps)) * 0.62
		var rx := maxf(2.0, radii.x * frac)
		var ry := maxf(2.0, radii.y * frac)
		var layer_a := base_col.a * (0.14 + float(i) * 0.18) / float(steps)
		ctrl.draw_set_transform(center, 0.0, Vector2(rx, ry))
		ctrl.draw_circle(Vector2.ZERO, 1.0, Color(base_col.r, base_col.g, base_col.b, layer_a))
	ctrl.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ornamental_divider(ctrl: Control, y: float, x0: float, x1: float, col: Color, with_diamond: bool = true) -> void:
	var cx := (x0 + x1) * 0.5
	ctrl.draw_line(Vector2(x0, y), Vector2(x1, y), Color(col.r, col.g, col.b, col.a * 0.25), 4.0, true)
	ctrl.draw_line(Vector2(x0 + 8.0, y), Vector2(x1 - 8.0, y), Color(col.r, col.g, col.b, col.a * 0.85), 1.5, true)
	if with_diamond:
		var r := 4.5
		var pts := PackedVector2Array([
			Vector2(cx, y - r),
			Vector2(cx + r, y),
			Vector2(cx, y + r),
			Vector2(cx - r, y)
		])
		ctrl.draw_colored_polygon(pts, Color(col.r, col.g, col.b, minf(1.0, col.a * 1.15)))

func _draw_liquid_bar(ctrl: Control, rect: Rect2, pct: float, fill_col: Color, tip_col: Color) -> void:
	var p := clampf(pct, 0.0, 1.0)
	var mid_y := rect.position.y + rect.size.y * 0.5
	# Subtle recessed ink track (no boxy outline!)
	ctrl.draw_line(Vector2(rect.position.x, mid_y), Vector2(rect.position.x + rect.size.x, mid_y), Color(0.06, 0.04, 0.05, 0.72), rect.size.y, true)
	ctrl.draw_line(Vector2(rect.position.x, mid_y - 1.0), Vector2(rect.position.x + rect.size.x, mid_y - 1.0), Color(0.55, 0.44, 0.24, 0.28), 1.0, true)
	if p > 0.005:
		var fx1 := rect.position.x + rect.size.x * p
		ctrl.draw_line(Vector2(rect.position.x, mid_y), Vector2(fx1, mid_y), Color(fill_col.r, fill_col.g, fill_col.b, 0.35), rect.size.y + 4.0, true)
		ctrl.draw_line(Vector2(rect.position.x, mid_y), Vector2(fx1, mid_y), fill_col, rect.size.y * 0.72, true)
		ctrl.draw_line(Vector2(rect.position.x, mid_y - 1.2), Vector2(fx1, mid_y - 1.2), tip_col, 1.8, true)
		# Diamond rune finial at tip
		var dpts := PackedVector2Array([
			Vector2(fx1, mid_y - 5.5),
			Vector2(fx1 + 5.5, mid_y),
			Vector2(fx1, mid_y + 5.5),
			Vector2(fx1 - 4.0, mid_y)
		])
		ctrl.draw_colored_polygon(dpts, tip_col)
	# Fine notched runes at 1/3 & 2/3
	for k: float in [0.333, 0.666]:
		var nx: float = rect.position.x + rect.size.x * k
		ctrl.draw_line(Vector2(nx, mid_y - 4.0), Vector2(nx, mid_y + 4.0), Color(0.95, 0.85, 0.55, 0.36), 1.2)

func _spawn_hud_sparkles(screen_pos: Vector2, col: Color, count: int = 16) -> void:
	if not hud_fx_layer:
		return
	for i in range(count):
		var sp := Control.new()
		var sz := randf_range(6.0, 12.0)
		sp.custom_minimum_size = Vector2(sz, sz)
		sp.size = Vector2(sz, sz)
		sp.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		sp.position = screen_pos - Vector2(sz * 0.5, sz * 0.5)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var draw_col := col.lightened(randf_range(0.0, 0.4))
		sp.draw.connect(func():
			var c := Vector2(sz * 0.5, sz * 0.5)
			var r := sz * 0.5
			var poly := PackedVector2Array([
				Vector2(c.x, c.y - r),
				Vector2(c.x + r * 0.35, c.y - r * 0.35),
				Vector2(c.x + r, c.y),
				Vector2(c.x + r * 0.35, c.y + r * 0.35),
				Vector2(c.x, c.y + r),
				Vector2(c.x - r * 0.35, c.y + r * 0.35),
				Vector2(c.x - r, c.y),
				Vector2(c.x - r * 0.35, c.y - r * 0.35)
			])
			sp.draw_colored_polygon(poly, draw_col)
		)
		hud_fx_layer.add_child(sp)
		var ang := randf_range(0.0, TAU)
		var dist := randf_range(28.0, 96.0)
		var dest := sp.position + Vector2(cos(ang) * dist, sin(ang) * dist * 0.72)
		sp.scale = Vector2(0.2, 0.2)
		var dur := randf_range(0.45, 0.85)
		var tw := sp.create_tween().set_parallel(true)
		tw.tween_property(sp, "position", dest, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector2(1.35, 1.35), dur * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "rotation_degrees", randf_range(-180.0, 180.0), dur)
		tw.tween_property(sp, "modulate:a", 0.0, dur * 0.55).set_delay(dur * 0.45)
		tw.chain().tween_callback(sp.queue_free)

func set_mute_label(muted: bool) -> void:
	battle_audio_muted = muted
	_refresh_battle_audio_toggle_text()

func set_audio_hud(muted: bool, vol_pct: int) -> void:
	battle_audio_muted = muted
	battle_audio_pct = vol_pct
	_refresh_battle_audio_toggle_text()
	if battle_mute_btn:
		battle_mute_btn.text = _tr("Muted", "Ztlumeno") if (muted or vol_pct <= 0) else _tr("Mute", "Ztlumit")
		LialoIcons.apply_button_icon(battle_mute_btn, "sound_off" if (muted or vol_pct <= 0) else "sound_on", 14)
	if is_instance_valid(drawer_mute_btn):
		drawer_mute_btn.text = _tr("Audio: Muted", "Zvuk: Ztlumeno") if (muted or vol_pct <= 0) else _tr("Audio: On", "Zvuk: Zapnuto")
		LialoIcons.apply_button_icon(drawer_mute_btn, "sound_off" if (muted or vol_pct <= 0) else "sound_on", 16)
	if battle_vol_slider:
		battle_vol_slider.set_value_no_signal(float(vol_pct))
	if battle_vol_pct_lbl:
		battle_vol_pct_lbl.text = "%d%%" % (0 if muted else vol_pct)

func _refresh_battle_audio_toggle_text() -> void:
	var is_off := (battle_audio_muted or battle_audio_pct <= 0)
	var arr := "▴" if battle_audio_drawer_open else "▾"
	if battle_audio_toggle_btn:
		battle_audio_toggle_btn.text = ("OFF %s" % arr) if is_off else ("%d%% %s" % [battle_audio_pct, arr])
		LialoIcons.apply_button_icon(battle_audio_toggle_btn, "sound_off" if is_off else "sound_on", 14)
	if battle_audio_drawer:
		battle_audio_drawer.visible = battle_audio_drawer_open

func _get_combo_mult(cnt: int) -> float:
	var base := float(ScoreEng.SLAM_BASE_MULT.get(cnt, 4.5 + float(maxi(0, cnt - 4)) * 1.5))
	if not tutorial_mode and cnt <= 1 and "REL_FUJARA" in run_active_relics:
		base += 2.5
	if not tutorial_mode and cnt >= 2 and "REL_OVERCHARGE" in run_active_relics:
		base += float(cnt - 1) * 2.0
	if not tutorial_mode and storm_surge_mult > 0.0:
		base += storm_surge_mult
	return base

func _get_ai_score_mult() -> float:
	if tutorial_mode:
		return 1.0
	if active_boss_mod == "ENDLESS_TITAN" or active_campaign_difficulty == "classic":
		var boss_boost := 0.58 if active_boss_mod == "ENDLESS_TITAN" else 0.42
		return maxf(1.0, (float(target_score) / 260.0) * boss_boost)
	return clampf((float(target_score) / 520.0) * 0.25, 0.55, 1.35)

func _get_last_echo_card() -> Dictionary:
	for idx in range(discard_pile.size() - 1, -1, -1):
		var dc: Dictionary = discard_pile[idx]
		if str(dc.get("power_id", "")) != "SPEC_MIRROR":
			return dc
	return {}

func _format_pts_ui(val: int) -> String:
	var av := absi(val)
	if av >= 1000000:
		return "%.2fM" % (float(val) / 1000000.0)
	if av >= 100000:
		return "%.1fk" % (float(val) / 1000.0)
	return str(val)

func _rebuild_relic_visuals() -> void:
	for k in relic_3d_nodes.keys():
		if is_instance_valid(relic_3d_nodes[k]):
			relic_3d_nodes[k].queue_free()
	relic_3d_nodes.clear()
	relic_badge_nodes.clear()
	if relic_bar_hbox:
		for c in relic_bar_hbox.get_children():
			c.queue_free()
		relic_bar_hbox.visible = false

	if tutorial_mode:
		return

	# Spawn Owned Active Tabletop Relics (10 Buyable/Usable TRELIC_* 3D Models on Front-Right Table Arc!)
	var df_tr := _get_font(true)
	var trelic_arc_slots: Array[Vector3] = [
		Vector3(0.28, 0.0, 0.56),
		Vector3(0.47, 0.0, 0.48),
		Vector3(0.66, 0.0, 0.38),
		Vector3(0.84, 0.0, 0.26),
		Vector3(0.36, 0.0, 0.72),
		Vector3(0.56, 0.0, 0.66),
		Vector3(0.76, 0.0, 0.54),
		Vector3(0.94, 0.0, 0.40),
		Vector3(0.14, 0.0, 0.64),
		Vector3(-0.14, 0.0, 0.64),
	]
	for ti in range(mini(run_table_relics.size(), Catalog.MAX_ACTIVE_RELICS)):
		var tid: String = str(run_table_relics[ti])
		if relic_mgr.is_broken(tid):
			continue
		var t_info: Dictionary = Catalog.get_table_relic_loc(tid, opts_language)
		if t_info.is_empty() or not table_relic_rack_root:
			continue
		var tcol: Color = t_info.get("col", Color(0.96, 0.24, 0.34))
		var t_rem := relic_mgr.get_remaining(tid)
		var tped := Node3D.new()
		tped.name = "TableRelic_" + tid
		tped.position = trelic_arc_slots[ti % trelic_arc_slots.size()]
		var t_model := RelicMesh.build_relic_3d_mesh(tid, tcol)
		t_model.name = "RelicModel3D"
		t_model.scale = Vector3(1.26, 1.26, 1.26)
		var t_halo := t_model.get_node_or_null("ReadyHalo") as Node3D
		if t_halo:
			t_halo.visible = (t_rem > 0)
		tped.add_child(t_model)

		var t_lbl := Label3D.new()
		t_lbl.name = "RelicHoverTag"
		t_lbl.text = "%s [%d/%d]\n[%s]" % [str(t_info.get("name", tid)), t_rem, MAX_TABLE_ITEM_USES, str(t_info.get("short", "USE"))]
		t_lbl.font = df_tr
		t_lbl.modulate = tcol.lightened(0.45)
		t_lbl.font_size = 11
		t_lbl.outline_size = 5
		t_lbl.pixel_size = 0.0012
		t_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		t_lbl.position = Vector3(0.0, 0.22, 0.0)
		t_lbl.visible = false
		tped.add_child(t_lbl)

		var t_pid := "trelic:" + tid
		tped.set_meta("prop_id", t_pid)
		tped.set_meta("base_pos", tped.position)
		tped.set_meta("base_scale", Vector3.ONE)
		tped.set_meta("relic_id", tid)

		var t_area := Area3D.new()
		t_area.name = "TableRelicArea_" + tid
		t_area.set_meta("prop_id", t_pid)
		var t_cs := CollisionShape3D.new()
		var t_box := BoxShape3D.new()
		t_box.size = Vector3(0.18, 0.24, 0.18)
		t_cs.shape = t_box
		t_cs.position = Vector3(0.0, 0.10, 0.0)
		t_area.add_child(t_cs)
		tped.add_child(t_area)

		table_relic_rack_root.add_child(tped)
		relic_3d_nodes[tid] = tped

	var df := _get_font(true)
	for i in range(mini(run_active_relics.size(), Catalog.MAX_ACTIVE_RELICS)):
		var rel_id: String = str(run_active_relics[i])
		if relic_mgr.is_broken(rel_id):
			continue
		var r_info: Dictionary = Catalog.get_relic_loc(rel_id, opts_language)
		if r_info.is_empty():
			continue
		var rcol: Color = r_info.get("col", Color(1.0, 0.84, 0.32))
		var r_rem := relic_mgr.get_remaining(rel_id)
		var r_art_p := Catalog.get_relic_art_path(rel_id)
		var r_tex: Texture2D = Toon.tex(r_art_p) if ResourceLoader.exists(r_art_p) else null

		# Sculpted 3D Medieval Relic Artifact along the visible left table rim (clickable & hover-liftable!)
		if table_relic_rack_root:
			var ped := Node3D.new()
			var relic_arc_slots: Array[Vector3] = [
				Vector3(-0.34, 0.0, 0.56),
				Vector3(-0.50, 0.0, 0.44),
				Vector3(-0.73, 0.0, 0.42),
				Vector3(-0.87, 0.0, 0.27),
				Vector3(-0.96, 0.0, 0.09),
				Vector3(-0.46, 0.0, 0.72),
				Vector3(-0.67, 0.0, 0.67),
				Vector3(-0.91, 0.0, 0.50),
			]
			var slot_base: Vector3 = relic_arc_slots[i % relic_arc_slots.size()]
			var row_idx: int = int(i / relic_arc_slots.size())
			ped.position = slot_base + Vector3(-0.14 * float(row_idx), 0.0, 0.14 * float(row_idx))

			var rel_model := RelicMesh.build_relic_3d_mesh(rel_id, rcol)
			rel_model.name = "RelicModel3D"
			rel_model.scale = Vector3(1.18, 1.18, 1.18)
			var halo_n := rel_model.get_node_or_null("ReadyHalo") as Node3D
			if halo_n:
				halo_n.visible = (r_rem > 0)
			ped.add_child(rel_model)

			var r_lbl3d := Label3D.new()
			r_lbl3d.name = "RelicHoverTag"
			r_lbl3d.text = "%s [%d/%d]" % [str(r_info.get("name", r_info.get("icon", "R"))), r_rem, MAX_TABLE_ITEM_USES]
			r_lbl3d.font = df
			r_lbl3d.modulate = Color(1.0, 0.96, 0.86)
			r_lbl3d.font_size = 11
			r_lbl3d.outline_size = 5
			r_lbl3d.pixel_size = 0.0012
			r_lbl3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			r_lbl3d.position = Vector3(0.0, 0.20, 0.0)
			r_lbl3d.visible = false
			ped.add_child(r_lbl3d)

			var rel_pid := "relic:" + rel_id
			ped.set_meta("prop_id", rel_pid)
			ped.set_meta("base_pos", ped.position)
			ped.set_meta("base_scale", Vector3.ONE)
			ped.set_meta("relic_id", rel_id)

			var r_area := Area3D.new()
			r_area.name = "RelicArea_" + rel_id
			r_area.set_meta("prop_id", rel_pid)
			var r_cs := CollisionShape3D.new()
			var r_box := BoxShape3D.new()
			r_box.size = Vector3(0.16, 0.22, 0.16)
			r_cs.shape = r_box
			r_cs.position = Vector3(0.0, 0.09, 0.0)
			r_area.add_child(r_cs)
			ped.add_child(r_area)

			table_relic_rack_root.add_child(ped)
			relic_3d_nodes[rel_id] = ped

		# 2D Interactive Relic Badge Pill below Combo HUD with detailed artwork thumbnail
		if relic_bar_hbox:
			var badge := PanelContainer.new()
			var bsb := _make_plaque_style(Color(0.10, 0.08, 0.14, 0.90), rcol, 10)
			bsb.content_margin_left = 7
			bsb.content_margin_right = 8
			bsb.content_margin_top = 3
			bsb.content_margin_bottom = 3
			badge.add_theme_stylebox_override("panel", bsb)
			badge.mouse_filter = Control.MOUSE_FILTER_PASS
			var bhb := HBoxContainer.new()
			bhb.add_theme_constant_override("separation", 5)
			badge.add_child(bhb)
			if r_tex:
				var ico_bg := PanelContainer.new()
				ico_bg.custom_minimum_size = Vector2(24, 24)
				ico_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var ibs := StyleBoxFlat.new()
				ibs.bg_color = Color(0.92, 0.86, 0.74, 0.24)
				ibs.set_corner_radius_all(6)
				ibs.content_margin_left = 1; ibs.content_margin_right = 1
				ibs.content_margin_top = 1; ibs.content_margin_bottom = 1
				ico_bg.add_theme_stylebox_override("panel", ibs)
				var icon_tr := TextureRect.new()
				icon_tr.name = "RelicIcon"
				icon_tr.texture = r_tex
				icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_tr.custom_minimum_size = Vector2(22, 22)
				icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ico_bg.add_child(icon_tr)
				bhb.add_child(ico_bg)
			var bl := Label.new()
			bl.text = str(r_info.get("name", r_info.get("icon", "Relic"))) if r_tex else ("✦ " + str(r_info.get("icon", "Relic")))
			if str(bl.text).length() > 14:
				bl.text = str(r_info.get("icon", bl.text.substr(0, 12)))
			bl.add_theme_font_override("font", df)
			bl.add_theme_font_size_override("font_size", 12)
			bl.add_theme_color_override("font_color", rcol.lightened(0.28))
			bhb.add_child(bl)
			var r_id_cap := rel_id
			badge.mouse_entered.connect(func():
				if hover_inspect_panel and hover_inspect_title:
					var rl := Catalog.get_relic_loc(r_id_cap, opts_language)
					hover_inspect_title.text = _tr("✦ RELIC: ", "✦ RELIKVIE: ") + str(rl.get("name", ""))
					var cat_s := str(rl.get("category", _tr("Passive", "Pasivní")))
					var sub_txt := _tr("%s Artifact (Active)" % cat_s, "%s • Aktivní relikvie" % cat_s)
					if r_id_cap == "REL_SEVEN_GRIMOIRE":
						var sc7 := 1.0 + float(match_relic_scales.get("REL_SEVEN_GRIMOIRE", 0.0))
						sub_txt = _tr("Scaling Artifact — Current: ×%.2f X-Mult" % sc7, "Rostoucí relikvie — Aktuálně: ×%.2f násobič" % sc7)
					elif r_id_cap == "REL_MERCHANT_LEDGER":
						var scm := maxi(ScoreEng.MERCHANT_LEDGER_CHIP_STEP, int(match_relic_scales.get("REL_MERCHANT_LEDGER", run_shop_rerolls * ScoreEng.MERCHANT_LEDGER_CHIP_STEP)) + ScoreEng.MERCHANT_LEDGER_CHIP_STEP)
						sub_txt = _tr("Scaling Artifact — Current: +%d Chips (%d rerolls)" % [scm, run_shop_rerolls], "Rostoucí relikvie — Aktuálně: +%d bodů (%d obnovení)" % [scm, run_shop_rerolls])
					hover_inspect_sub.text = sub_txt
					hover_inspect_desc.text = str(rl.get("desc", ""))
					hover_inspect_panel.visible = true
			)
			badge.mouse_exited.connect(func():
				if hover_inspect_panel and hovered_card_idx < 0:
					hover_inspect_panel.visible = false
			)
			relic_bar_hbox.add_child(badge)
			relic_badge_nodes[rel_id] = badge

func _pulse_relic_trigger(rel_id: String, bonus_txt: String, show_center_popup: bool = true) -> void:
	var r_info: Dictionary = Catalog.get_relic_loc(rel_id, opts_language)
	var col: Color = r_info.get("col", Color(1.0, 0.84, 0.30))
	var my_sess := _battle_session_token
	if relic_3d_nodes.has(rel_id) and is_instance_valid(relic_3d_nodes[rel_id]):
		var n3: Node3D = relic_3d_nodes[rel_id]
		var bp_y: float = (n3.get_meta("base_pos", n3.position) as Vector3).y
		var tw := n3.create_tween()
		tw.tween_property(n3, "position:y", bp_y + 0.14, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(n3, "scale", Vector3(1.42, 1.42, 1.42), 0.12)
		var spin_p := n3.get_node_or_null("RelicModel3D/SpinPivot") as Node3D
		if spin_p:
			tw.parallel().tween_property(spin_p, "rotation_degrees:y", spin_p.rotation_degrees.y + 360.0, 0.34)
		tw.tween_property(n3, "position:y", bp_y, 0.22).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(n3, "scale", Vector3.ONE, 0.22)
		var gped := n3.global_position + Vector3(0.0, 0.09, 0.0)
		Fx.burst(self, gped, col.lightened(0.25), 18, 0.95, 0.55, 0.028, 1.6, true, 120.0, Vector3.UP, true)
		Fx.ring(self, n3.global_position + Vector3(0.0, 0.01, 0.0), Color(1.0, 0.84, 0.36), 0.16, 0.35, 0.12, 2.2, 8.0)
		var beam_dst := (discard_pile_root.global_position + Vector3(0.0, 0.05, 0.0)) if is_instance_valid(discard_pile_root) else to_global(Vector3(0.14, 0.86, 0.02))
		Fx.beam(self, gped, beam_dst, col.lightened(0.35), 0.34)
		BlenderVfx.spawn_scoring_token_arc(self, "Token_RelicBeamOrb", gped, beam_dst, col.lightened(0.25), _pace(0.45), 0.24, 2)
		if is_instance_valid(_active_astrolabe_stage):
			BlenderVfx.pulse_astrolabe(_active_astrolabe_stage, col, 1.15)
		if bonus_txt != "":
			Fx.float_number(self, gped + Vector3(0.0, 0.11, 0.0), bonus_txt, col.lightened(0.30), 58, 0.24, 1.05, 1.68)
	if relic_badge_nodes.has(rel_id) and is_instance_valid(relic_badge_nodes[rel_id]):
		var nb: PanelContainer = relic_badge_nodes[rel_id] as PanelContainer
		if nb:
			nb.pivot_offset = nb.size * 0.5
			var btw := nb.create_tween()
			btw.tween_property(nb, "scale", Vector2(1.34, 1.34), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			btw.tween_property(nb, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_QUAD)
			var hl_sb := _make_plaque_style(col.darkened(0.55), Color(1.0, 0.94, 0.48), 10)
			hl_sb.content_margin_left = 7; hl_sb.content_margin_right = 8
			hl_sb.content_margin_top = 3; hl_sb.content_margin_bottom = 3
			var orig_sb := _make_plaque_style(Color(0.10, 0.08, 0.14, 0.90), col, 10)
			orig_sb.content_margin_left = 7; orig_sb.content_margin_right = 8
			orig_sb.content_margin_top = 3; orig_sb.content_margin_bottom = 3
			nb.add_theme_stylebox_override("panel", hl_sb)
			_spawn_hud_sparkles(nb.global_position + nb.size * 0.5, col.lightened(0.3), 7)
			var nb_wr: WeakRef = weakref(nb)
			get_tree().create_timer(_pace(0.32)).timeout.connect(func():
				if my_sess != _battle_session_token:
					return
				var nb_inst := nb_wr.get_ref() as PanelContainer
				if is_instance_valid(nb_inst):
					nb_inst.add_theme_stylebox_override("panel", orig_sb)
			)
	var step_line := "✦ %s: %s" % [str(r_info.get("name", "Relic")), bonus_txt]
	if show_center_popup:
		_spawn_score_popup(step_line, col.lightened(0.25), true)
	else:
		_show_stagger_callout(step_line, col.lightened(0.25))

func _show_stagger_callout(txt: String, col: Color, punch_scale: float = 1.14) -> void:
	if not stagger_callout_pill or not stagger_callout_lbl:
		return
	if txt == "":
		stagger_callout_pill.visible = false
		stagger_callout_ttl = 0.0
		return
	if stagger_callout_tween and stagger_callout_tween.is_valid():
		stagger_callout_tween.kill()
	stagger_callout_ttl = 1.8
	var sb := _make_plaque_style(Color(0.055, 0.042, 0.036, 0.95), col, 18)
	sb.set_border_width_all(2)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	stagger_callout_pill.add_theme_stylebox_override("panel", sb)
	stagger_callout_lbl.text = txt
	stagger_callout_lbl.add_theme_color_override("font_color", col.lightened(0.28))
	var pill_w := maxf(304.0, stagger_callout_pill.size.x)
	stagger_callout_pill.position = Vector2(162.0, 166.0)
	stagger_callout_pill.custom_minimum_size = Vector2(304, 58)
	stagger_callout_pill.visible = true
	stagger_callout_pill.modulate.a = 1.0
	stagger_callout_pill.pivot_offset = stagger_callout_pill.size * 0.5
	stagger_callout_pill.scale = Vector2(punch_scale, punch_scale)
	stagger_callout_tween = create_tween()
	stagger_callout_tween.tween_property(stagger_callout_pill, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_stagger_equation_theatre(cur_chips: int, cur_flat: float, _cur_x: float, sub_tot: int, step_idx: int, total_steps: int, punch_what: String = "") -> void:
	if stagger_step_progress_lbl:
		if step_idx > 0 and total_steps > 0:
			stagger_step_progress_lbl.visible = true
			stagger_step_progress_lbl.text = "%d / %d" % [mini(step_idx, total_steps), total_steps]
		else:
			stagger_step_progress_lbl.visible = false
	if not stagger_eq_row:
		return
	var show_eq := cards_points_revealed or hud_combo_revealed
	stagger_eq_row.visible = show_eq
	if not show_eq:
		return
	if stagger_eq_chips_lbl:
		stagger_eq_chips_lbl.text = "%s" % _format_pts_ui(cur_chips)
		if punch_what == "chips":
			_punch_hud_label(stagger_eq_chips_lbl.get_parent() as Control if stagger_eq_chips_lbl.get_parent() is PanelContainer else stagger_eq_chips_lbl, 1.24)
	if stagger_eq_mult_lbl:
		var mult_is_int := absf(cur_flat - roundf(cur_flat)) < 0.01
		stagger_eq_mult_lbl.text = ("%d" % maxi(1, int(round(cur_flat)))) if mult_is_int else ("%.1f" % cur_flat)
		if punch_what == "mult":
			_punch_hud_label(stagger_eq_mult_lbl.get_parent() as Control if stagger_eq_mult_lbl.get_parent() is PanelContainer else stagger_eq_mult_lbl, 1.26)
	if stagger_eq_xmult_lbl:
		var xm_cap := stagger_eq_xmult_lbl.get_parent() as Control if stagger_eq_xmult_lbl.get_parent() is PanelContainer else stagger_eq_xmult_lbl
		if _cur_x > 1.005:
			stagger_eq_xmult_lbl.text = "×%s" % ScoreEng._fmt_num(_cur_x)
			stagger_eq_xmult_lbl.visible = true
			if xm_cap != stagger_eq_xmult_lbl:
				xm_cap.visible = true
			if punch_what == "xmult":
				_punch_hud_label(xm_cap, 1.28)
		else:
			stagger_eq_xmult_lbl.visible = false
			if xm_cap != stagger_eq_xmult_lbl:
				xm_cap.visible = false
	if stagger_eq_total_lbl:
		stagger_eq_total_lbl.text = "+%s" % _format_pts_ui(sub_tot)
		var tot_cap := stagger_eq_total_lbl.get_parent() as Control if stagger_eq_total_lbl.get_parent() is PanelContainer else stagger_eq_total_lbl
		_punch_hud_label(tot_cap, 1.28 if punch_what == "total" else 1.16)

func _punch_hud_label(lbl: Control, peak: float = 1.30) -> void:
	if not lbl or not lbl.visible:
		return
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2(peak, peak)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _wrap_eq_capsule(lbl: Label, _bg_col: Color, _border_col: Color, pad_x: int = 4, pad_y: int = 2, _radius: int = 0) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	cap.add_theme_stylebox_override("panel", sb)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(lbl)
	return cap

func _spawn_edition_burst_3d(world_pos: Vector3, col: Color) -> void:
	Fx.ring(self, world_pos + Vector3(0.0, 0.03, 0.0), col.lightened(0.2), 0.34, 0.34, 0.11, 1.7, 8.0)
	Fx.burst(self, world_pos + Vector3(0.0, 0.05, 0.0), col.lightened(0.3), 24, 1.35, 0.52, 0.030, 1.8, true, 140.0, Vector3.UP, true)

func _update_combo_hud(title_txt: String, chips_val: int, flat_mult_val: float, total_pts: int, is_active: bool, x_mult_val: float = 1.0) -> void:
	if not combo_hud_grp:
		return
	var prev_chips := combo_raw_val
	var prev_mult := combo_mult_val
	var prev_tot := combo_tot_val
	var card_cnt_mult := maxf(1.0, flat_mult_val)
	combo_glow_active = is_active
	combo_raw_val = chips_val
	combo_mult_val = card_cnt_mult
	combo_tot_val = total_pts
	var stack_cnt := staged_card_indices.size()
	var charge_denom := maxf(40.0, float(target_score) * 0.45)
	if is_active:
		combo_target_heat = clampf(0.72 + card_cnt_mult * 0.35, 0.85, 2.2)
		combo_heat = maxf(combo_heat, combo_target_heat)
		combo_target_charge = clampf(float(total_pts) / charge_denom, 0.25, 1.0)
		table_pulse_strength = maxf(table_pulse_strength, clampf(0.55 + card_cnt_mult * 0.25, 0.55, 1.6))
	elif stack_cnt >= 1:
		combo_target_heat = clampf(0.42 + float(stack_cnt) * 0.22, 0.48, 1.55)
		combo_target_charge = clampf(float(total_pts) / charge_denom + float(stack_cnt) * 0.12, 0.18, 0.96)
	else:
		combo_target_heat = 0.22
		combo_target_charge = 0.12

	if combo_title_lbl:
		combo_title_lbl.text = title_txt
		combo_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.44) if is_active else Color(0.92, 0.80, 0.58))
	if combo_flame_mat:
		combo_flame_mat.set_shader_parameter("mult_tier", clampf(card_cnt_mult, 1.0, 12.0))
	if chips_lbl:
		chips_lbl.text = _format_pts_ui(chips_val)
		if chips_val != prev_chips and chips_val > 0:
			_punch_hud_label(chips_lbl, 1.38 if is_active else 1.24)
	if flat_mult_lbl:
		flat_mult_lbl.text = "%d" % maxi(1, int(round(card_cnt_mult)))
		if absf(card_cnt_mult - prev_mult) > 0.05 or is_active:
			_punch_hud_label(flat_mult_lbl, 1.44 if card_cnt_mult >= 2.0 else 1.25)
	if xmult_lbl:
		var xm_show := x_mult_val > 1.01
		xmult_lbl.visible = xm_show
		if xmult_lbl.get_parent() is PanelContainer:
			xmult_lbl.get_parent().visible = xm_show
		if xm_show:
			xmult_lbl.text = "×%s" % ScoreEng._fmt_num(x_mult_val)
			_punch_hud_label(xmult_lbl, 1.48)
	if mult_lbl:
		var disp_eff := card_cnt_mult * maxf(1.0, x_mult_val)
		mult_lbl.text = ("×%s" % ScoreEng._fmt_num(disp_eff)) if x_mult_val > 1.01 else ("×%d" % maxi(1, int(round(card_cnt_mult))))
	if total_calc_lbl:
		total_calc_lbl.text = "+" + _format_pts_ui(total_pts)
		if total_pts != prev_tot and total_pts > 0:
			_punch_hud_label(total_calc_lbl, 1.52 if is_active else 1.30)
	combo_hud_grp.queue_redraw()
	if combo_dial_ctrl:
		combo_dial_ctrl.queue_redraw()

	if (is_active or (total_pts > prev_tot and total_pts > 0)) and combo_hud_grp.visible:
		score_sheen_phase = 0.0
		score_ledger_glow = maxf(score_ledger_glow, 1.0 if is_active else 0.65)
		combo_hud_grp.pivot_offset = combo_hud_grp.size * 0.5
		combo_hud_grp.scale = Vector2(1.10, 1.10) if is_active else Vector2(1.05, 1.05)
		var tw := create_tween()
		tw.tween_property(combo_hud_grp, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if total_calc_lbl and is_active:
			var tpos := total_calc_lbl.global_position + total_calc_lbl.size * 0.5
			_score_fx_rings.append({"pos": tpos, "r": 6.0, "max_r": 76.0, "life": 0.34, "max_life": 0.34, "col": Color(1.0, 0.86, 0.28), "w": 3.0})
			if card_cnt_mult >= 2.0:
				_score_fx_bolts.append({"from": combo_hud_grp.global_position + Vector2(36, 48), "to": tpos, "life": 0.24, "max_life": 0.24, "col": Color(1.0, 0.72, 0.24), "w": 2.4})
		if combo_embers.size() < 40:
			for _ei in range(14 if is_active else 6):
				combo_embers.append({
					"pos": Vector2(randf_range(24.0, 270.0), randf_range(22.0, 68.0)),
					"vel": Vector2(randf_range(-28.0, 40.0), randf_range(-95.0, -35.0)),
					"life": randf_range(0.45, 0.95),
					"max_life": 0.95,
					"col": Color(1.0, randf_range(0.42, 0.92), randf_range(0.14, 0.45)),
					"sz": randf_range(2.0, 3.8),
				})
	_refresh_score_ledger_ui()

func _get_chalice_fire_tint(prog: float) -> Color:
	var p := clampf(prog, 0.0, 1.45)
	if p < 0.06:
		return Color(0.48, 0.55, 0.64).lerp(Color(0.95, 0.34, 0.08), smoothstep(0.0, 0.06, p))
	elif p < 0.28:
		return Color(0.95, 0.34, 0.08).lerp(Color(1.0, 0.66, 0.14), smoothstep(0.06, 0.28, p))
	elif p < 0.58:
		return Color(1.0, 0.66, 0.14).lerp(Color(1.0, 0.90, 0.34), smoothstep(0.28, 0.58, p))
	elif p < 0.88:
		return Color(1.0, 0.90, 0.34).lerp(Color(0.32, 0.86, 1.0), smoothstep(0.58, 0.88, p))
	return Color(0.32, 0.86, 1.0).lerp(Color(0.88, 0.38, 1.0), smoothstep(0.88, 1.08, p))

func _get_charge_tier_index(sc: int, tgt: int) -> int:
	var pct := clampf(float(sc) / float(maxi(1, tgt)), 0.0, 2.0)
	if pct >= 1.0:
		return 4
	elif pct >= 0.70:
		return 3
	elif pct >= 0.45:
		return 2
	elif pct >= 0.20:
		return 1
	return 0

func _sync_charge_chalice_art(force_snap: bool = false) -> void:
	var shown_sc := int(round(display_player_score)) if hud_score_revealed else 0
	var tier := _get_charge_tier_index(shown_sc, target_score)
	var pct_int := clampi(int(round((float(shown_sc) / float(maxi(1, target_score))) * 100.0)), 0, 999)
	var roman_tiers := ["STAGE I", "STAGE II", "STAGE III", "STAGE IV", "OVERDRIVE"]
	var raw_p := clampf(float(shown_sc) / float(maxi(1, target_score)), 0.0, 1.45) if hud_score_revealed else 0.0
	var ui_col := _get_chalice_fire_tint(chalice_flame_progress if not force_snap else raw_p).lightened(0.18)
	if score_chalice_tier_lbl:
		score_chalice_tier_lbl.text = roman_tiers[tier] if not _tr("EN", "CS") == "CS" else ["FÁZE I", "FÁZE II", "FÁZE III", "FÁZE IV", "NADBITÍ"][tier]
		score_chalice_tier_lbl.add_theme_color_override("font_color", ui_col)
	if score_chalice_pct_lbl:
		var pend_str := (" (+%s)" % _format_pts_ui(pending_player_exchange_pts)) if (pending_player_exchange_pts > 0 and hud_score_revealed) else ""
		score_chalice_pct_lbl.text = "%d%%%s" % [pct_int, pend_str]
		score_chalice_pct_lbl.add_theme_color_override("font_color", Color(0.45, 0.94, 1.0) if pending_player_exchange_pts > 0 else ui_col)

	if not is_instance_valid(score_chalice_art):
		return
	# Keep ONE single unchanged chalice vessel; ONLY fire & surrounding aura evolve gradually!
	var base_chalice_tex: Texture2D = _load_blender_ui_tex("chalice_3d.png")
	if base_chalice_tex == null and not charge_tier_textures.is_empty():
		base_chalice_tex = charge_tier_textures[0]
	if base_chalice_tex == null:
		return
	score_chalice_art.texture = base_chalice_tex
	if is_instance_valid(score_chalice_next):
		score_chalice_next.visible = false

	if force_snap:
		last_charge_tier_idx = tier
		score_chalice_art.scale = Vector2.ONE
		score_chalice_art.modulate = Color.WHITE
		chalice_flame_progress = raw_p
		var snap_tint := _get_chalice_fire_tint(chalice_flame_progress)
		if chalice_back_fire_mat:
			chalice_back_fire_mat.set_shader_parameter("progress", chalice_flame_progress)
		if chalice_front_fire_mat:
			chalice_front_fire_mat.set_shader_parameter("progress", chalice_flame_progress)
		if chalice_vessel_mat:
			chalice_vessel_mat.set_shader_parameter("progress", chalice_flame_progress)
			chalice_vessel_mat.set_shader_parameter("fire_tint", snap_tint)
		return

	if tier != last_charge_tier_idx:
		var evolved_up := tier > last_charge_tier_idx
		last_charge_tier_idx = tier
		score_chalice_art.pivot_offset = score_chalice_art.size * 0.5
		score_chalice_art.scale = Vector2(1.09, 1.09) if evolved_up else Vector2(0.95, 0.95)
		var atw := score_chalice_art.create_tween()
		atw.tween_property(score_chalice_art, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if evolved_up:
			var ch_center := score_chalice_art.global_position + score_chalice_art.size * 0.5
			var burst_col := _get_chalice_fire_tint(raw_p)
			_score_fx_rings.append({"pos": ch_center, "r": 18.0, "max_r": 150.0, "life": 0.65, "max_life": 0.65, "col": burst_col, "w": 4.0})
			_spawn_hud_sparkles(ch_center, burst_col, 20)
			emit_signal("play_sfx_pitched_requested", "overdrive_hum", 1.04 + float(tier) * 0.10)

func _set_score_breakdown_chips(chips: Array) -> void:
	last_breakdown_chips = chips.duplicate()
	if not is_instance_valid(score_breakdown_row):
		return
	for ch in score_breakdown_row.get_children():
		ch.queue_free()
	score_breakdown_row.visible = false

func _refresh_score_ledger_ui() -> void:
	if not score_ledger_eq_lbl or not score_ledger_state_lbl:
		return
	if is_instance_valid(score_delta_lbl):
		if hud_score_revealed:
			var diff := player_score - ai_score
			if diff > 0:
				score_delta_lbl.text = _tr("+%d LEAD" % diff, "+%d NÁSKOK" % diff)
				score_delta_lbl.add_theme_color_override("font_color", Color(0.46, 0.96, 0.62))
			elif diff < 0:
				score_delta_lbl.text = _tr("%d TRAIL" % diff, "%d ZTRÁTA" % diff)
				score_delta_lbl.add_theme_color_override("font_color", Color(1.0, 0.44, 0.40))
			else:
				score_delta_lbl.text = _tr("EVEN", "VYROVNÁNO")
				score_delta_lbl.add_theme_color_override("font_color", Color(0.92, 0.84, 0.56))
			score_delta_lbl.visible = true
		else:
			score_delta_lbl.visible = false
	if is_instance_valid(score_history_lbl):
		if hud_score_revealed and not turn_score_history.is_empty():
			var start_hi := maxi(0, turn_score_history.size() - 5)
			var h_parts: Array[String] = []
			for hi in range(start_hi, turn_score_history.size()):
				h_parts.append("+%d" % int(turn_score_history[hi]))
			score_history_lbl.text = _tr("Turns: ", "Tahy: ") + " • ".join(h_parts)
			score_history_lbl.visible = true
		else:
			score_history_lbl.visible = false
	if not hud_score_revealed:
		score_ledger_state_lbl.text = _tr("✦ SCORE LEDGER (HIDDEN)", "✦ ZÁPIS BODŮ (SKRYTO)")
		score_ledger_eq_lbl.text = "---"
		return
	var st_cnt := staged_card_indices.size()
	if st_cnt >= 1 and is_player_turn and not busy_animating and combo_tot_val > 0:
		score_ledger_state_lbl.text = _tr("PREVIEW", "NÁHLED")
		score_ledger_state_lbl.add_theme_color_override("font_color", Color(0.56, 0.94, 1.0))
	elif last_settled_eq_str != "":
		score_ledger_state_lbl.text = _tr("LAST PLAY", "POSLEDNÍ TAH")
		score_ledger_state_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	else:
		score_ledger_state_lbl.text = _tr("CARD × COUNT", "KARTA × POČET")
		score_ledger_state_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.56))

func _award_player_score_immediately(pts: int, note: String, col: Color, best_slam_pts: int = 0, best_move_txt: String = "", card_val: int = 0, card_cnt: int = 1) -> void:
	if pts > 0:
		var prev_p := player_score
		player_score += pts
		turn_score_history.append(pts)
		if turn_score_history.size() > 8:
			turn_score_history.pop_front()
		if best_slam_pts >= match_best_slam and best_slam_pts > 0:
			match_best_slam = best_slam_pts
			if best_move_txt != "":
				match_best_move_desc = best_move_txt
		if card_val > 0 and card_cnt >= 1:
			last_settled_eq_str = "%d × %d = +%d  (%s)" % [card_val, card_cnt, pts, _format_pts_ui(player_score)]
		else:
			last_settled_eq_str = "%s + %s = %s PTS" % [_format_pts_ui(prev_p), _format_pts_ui(pts), _format_pts_ui(player_score)]
		score_ledger_glow = 1.0
		score_sheen_phase = 0.0
	pending_player_exchange_pts = 0
	pending_player_exchange_notes.clear()
	pending_player_best_slam = 0
	pending_player_best_desc = ""
	if player_score_lbl and hud_score_revealed:
		player_score_lbl.text = _tr("SCORE: %s / %s", "BODY: %s / %s") % [_format_pts_ui(player_score), _format_pts_ui(target_score)]
		_punch_hud_label(player_score_lbl, 1.24)
	_refresh_score_ledger_ui()
	_sync_charge_chalice_art(false)
	_check_boss_phase_awakening()
	if is_instance_valid(score_chalice_art) and pts > 0:
		var vp_rect := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1366, 768)
		var origin_p := vp_rect * Vector2(0.50, 0.50)
		var ch_p := score_chalice_art.global_position + score_chalice_art.size * 0.5
		for _oi in range(14):
			var ang := randf_range(0.0, TAU)
			_score_fx_orbs.append({
				"start": origin_p + Vector2(cos(ang), sin(ang)) * randf_range(10.0, 65.0),
				"pos": origin_p,
				"prev_pos": origin_p,
				"ctrl": origin_p.lerp(ch_p, 0.45) + Vector2(randf_range(-100.0, 100.0), randf_range(-80.0, 110.0)),
				"target": ch_p + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)),
				"t": -float(_oi) * 0.020,
				"dur": randf_range(0.36, 0.54),
				"sz": randf_range(3.5, 6.2),
				"col": Color(1.0, 0.88, 0.36).lerp(col, 0.45),
			})
		score_chalice_art.pivot_offset = score_chalice_art.size * 0.5
		score_chalice_art.scale = Vector2(1.16, 1.16)
		var btw := score_chalice_art.create_tween()
		btw.tween_property(score_chalice_art, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
		if score_fx_overlay:
			score_fx_overlay.queue_redraw()
		if player_liquid_bar:
			player_liquid_bar.queue_redraw()
		if score_goal_bar_ctrl:
			score_goal_bar_ctrl.queue_redraw()

func _award_ai_score_immediately(pts: int, note: String = "", col: Color = Color(1.0, 0.44, 0.38)) -> void:
	pending_ai_exchange_pts = 0
	pending_ai_exchange_notes.clear()
	if pts > 0:
		ai_score += pts
		display_ai_score = float(ai_score)
	if ai_score_lbl and hud_score_revealed:
		ai_score_lbl.text = _tr("RIVAL: %s / %s", "SOUPEŘ: %s / %s") % [_format_pts_ui(ai_score), _format_pts_ui(target_score)]
		if pts > 0:
			_punch_hud_label(ai_score_lbl, 1.28)
	_refresh_score_ledger_ui()
	if pts > 0:
		_check_boss_phase_awakening()
	if pts > 0 and hud_score_revealed:
		var pop_txt := note if note != "" else _tr("+%d RIVAL" % pts, "+%d SOUPEŘ" % pts)
		_spawn_score_popup(pop_txt, col, false)
		if is_instance_valid(opp_hands_anchor):
			Fx.float_number(self, opp_hands_anchor.global_position + Vector3(0.0, 0.24, 0.0), "+%d" % pts, col.lightened(0.18), 64, 0.22, 0.78, 1.55)

func _bank_player_turn_score(pts: int, note: String, col: Color, best_slam_pts: int = 0, best_move_txt: String = "") -> void:
	_award_player_score_immediately(pts, note, col, best_slam_pts, best_move_txt)

func _flush_pending_exchange_scores_immediately() -> void:
	if pending_player_exchange_pts > 0:
		var prev_p := player_score
		var g_p := pending_player_exchange_pts
		player_score += g_p
		last_settled_eq_str = "%s + %s = %s PTS" % [_format_pts_ui(prev_p), _format_pts_ui(g_p), _format_pts_ui(player_score)]
		pending_player_exchange_pts = 0
		pending_player_exchange_notes.clear()
		if pending_player_best_slam >= match_best_slam and pending_player_best_slam > 0:
			match_best_slam = pending_player_best_slam
			if pending_player_best_desc != "":
				match_best_move_desc = pending_player_best_desc
		pending_player_best_slam = 0
		pending_player_best_desc = ""
	if pending_ai_exchange_pts > 0:
		ai_score += pending_ai_exchange_pts
		pending_ai_exchange_pts = 0
		pending_ai_exchange_notes.clear()
	display_player_score = float(player_score)
	display_ai_score = float(ai_score)
	_sync_charge_chalice_art(true)
	_refresh_score_ledger_ui()

func _spawn_score_fx_bolts_burst(from_pos: Vector2, to_pos: Vector2, col: Color, count: int = 5) -> void:
	for bi in range(count):
		var pts := PackedVector2Array()
		var segs := 9
		for s in range(segs + 1):
			var u := float(s) / float(segs)
			var p := from_pos.lerp(to_pos, u)
			if s > 0 and s < segs:
				var perp := (to_pos - from_pos).normalized()
				perp = Vector2(-perp.y, perp.x)
				p += perp * randf_range(-52.0, 52.0) * sin(u * PI) + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
			pts.append(p)
		_score_fx_bolts.append({"pts": pts, "life": 0.42 + float(bi) * 0.05, "max_life": 0.48, "col": col, "w": 3.4 - float(bi) * 0.35})

func _draw_score_fx_overlay() -> void:
	if not score_fx_overlay:
		return
	var ch_center := Vector2(92.0, 92.0)
	if is_instance_valid(score_chalice_art):
		ch_center = score_chalice_art.global_position + score_chalice_art.size * 0.5
	# Effect: Rotating Golden Starburst God-Rays anchored at the Charge Vessel & extending full-viewport
	if _score_fx_beams_alpha > 0.01:
		var beam_n := 14
		var t_rot := float(Time.get_ticks_msec()) * 0.0008
		for bi in range(beam_n):
			var a0 := t_rot + float(bi) * (TAU / float(beam_n))
			var spread := 0.065
			var reach := 1650.0
			var bcol := Color(1.0, 0.88, 0.36, 0.14 * _score_fx_beams_alpha) if bi % 2 == 0 else Color(0.45, 0.92, 1.0, 0.10 * _score_fx_beams_alpha)
			var poly := PackedVector2Array([
				ch_center,
				ch_center + Vector2(cos(a0 - spread), sin(a0 - spread)) * reach,
				ch_center + Vector2(cos(a0 + spread), sin(a0 + spread)) * reach,
			])
			score_fx_overlay.draw_colored_polygon(poly, bcol)
	# Effect: Concentric Expanding Halo Shock Rings
	for rg in _score_fx_rings:
		var lf := clampf(float(rg["life"]) / maxf(0.01, float(rg["max_life"])), 0.0, 1.0)
		var rc: Color = rg["col"]
		score_fx_overlay.draw_arc(rg["pos"], float(rg["r"]), 0.0, TAU, 56, Color(rc.r, rc.g, rc.b, lf * 0.88), float(rg["w"]) * (0.4 + 0.6 * lf), true)
	# Effect: Electric Arc Lightning Bolts bridging cards/table directly into Score Board & Chalice
	for bt in _score_fx_bolts:
		var lf := clampf(float(bt["life"]) / maxf(0.01, float(bt["max_life"])), 0.0, 1.0)
		var bc: Color = bt["col"]
		var pts: PackedVector2Array = bt["pts"]
		if pts.size() >= 2:
			score_fx_overlay.draw_polyline(pts, Color(bc.r, bc.g, bc.b, lf * 0.55), float(bt["w"]) * 2.6, true)
			score_fx_overlay.draw_polyline(pts, Color(1.0, 0.98, 0.90, lf * 0.95), maxf(1.2, float(bt["w"]) * 0.85), true)
	# Effect: Homing Mana & Gold Energy Orbs with Glowing Ribbon Trails flying into Chalice
	for ob in _score_fx_orbs:
		if float(ob["t"]) < 0.0 or float(ob["t"]) > 1.0:
			continue
		var oc: Color = ob["col"]
		var p: Vector2 = ob["pos"]
		var pp: Vector2 = ob["prev_pos"]
		var sz: float = float(ob["sz"])
		score_fx_overlay.draw_line(pp, p, Color(oc.r, oc.g, oc.b, 0.55), sz * 0.85, true)
		score_fx_overlay.draw_circle(p, sz * 1.6, Color(oc.r, oc.g, oc.b, 0.36))
		score_fx_overlay.draw_circle(p, sz, Color(1.0, 0.97, 0.86, 0.96))
	# Effect: Viewport-Wide Golden & Arcane Ember/Confetti Shower across the full 1366x768 screen
	for em in _score_fx_embers:
		var lf := clampf(float(em["life"]) / maxf(0.01, float(em["max_life"])), 0.0, 1.0)
		var ec: Color = em["col"]
		var ep: Vector2 = em["pos"]
		var esz: float = float(em["sz"])
		var ang: float = float(em["rot"])
		var d1 := Vector2(cos(ang), sin(ang)) * esz
		var d2 := Vector2(-d1.y, d1.x) * 0.65
		var diamond := PackedVector2Array([ep + d1, ep + d2, ep - d1, ep - d2])
		score_fx_overlay.draw_colored_polygon(diamond, Color(ec.r, ec.g, ec.b, lf * 0.90))

func _resolve_turn_pair_scoring_fx(_token: int) -> void:
	_flush_pending_exchange_scores_immediately()
	score_resolving_active = false

func _spawn_score_popup(txt: String, col: Color, is_player: bool) -> void:
	if not hud_root:
		return
	if is_player and is_instance_valid(_active_popup_lbl):
		_active_popup_lbl.queue_free()
		_active_popup_lbl = null

	var upper_t := txt.to_upper()
	var tier := 1
	if "GRAND SEAL" in upper_t or "VELKÁ PEČEŤ" in upper_t or "BANKAI" in upper_t or "×4" in upper_t or "4×" in upper_t or "×5" in upper_t or "×6" in upper_t:
		tier = 4
	elif "×3" in upper_t or "3×" in upper_t or "TRIPLE" in upper_t or "TROJ" in upper_t:
		tier = 3
	elif "×2" in upper_t or "2×" in upper_t or "COMBO" in upper_t or "KOMBO" in upper_t or "SLAM" in upper_t or "CHAIN" in upper_t or (is_player and combo_mult_val >= 2.0):
		tier = 2

	var tier_col := col
	if tier == 4:
		tier_col = Color(0.54, 0.94, 1.0)
	elif tier == 3:
		tier_col = Color(1.0, 0.72, 0.24)
	elif tier == 2:
		tier_col = Color(1.0, 0.88, 0.38)

	var vp_w: float = get_viewport().get_visible_rect().size.x
	var banner := Control.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bw := 380.0 if is_player else 440.0
	var bh := 64.0
	banner.size = Vector2(bw, bh)
	banner.pivot_offset = Vector2(bw * 0.5, bh * 0.5)
	if is_player:
		banner.position = Vector2(154.0, 174.0)
		_active_popup_lbl = banner
	else:
		banner.position = Vector2(maxf(480.0, vp_w - 496.0), 156.0)

	# Open, layered calligraphic ink brush & gold flourish (no static black StyleBoxFlat!)
	var flourish := Control.new()
	flourish.set_anchors_preset(Control.PRESET_FULL_RECT)
	flourish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flourish.draw.connect(func():
		var w := flourish.size.x
		var h := flourish.size.y
		var cy := h * 0.52
		# Soft tapered ink brush wash behind text (open edges, zero rectangular box)
		var wash_pts := PackedVector2Array([
			Vector2(18.0, cy),
			Vector2(w * 0.22, cy - 16.0),
			Vector2(w * 0.78, cy - 16.0),
			Vector2(w - 18.0, cy),
			Vector2(w * 0.78, cy + 18.0),
			Vector2(w * 0.22, cy + 18.0),
		])
		flourish.draw_colored_polygon(wash_pts, Color(0.03, 0.02, 0.02, 0.52))
		# Primary calligraphic underline stroke
		flourish.draw_line(Vector2(26.0, h - 10.0), Vector2(w - 26.0, h - 10.0), Color(tier_col.r, tier_col.g, tier_col.b, 0.88), 2.4 if tier >= 2 else 1.6, true)
		if tier >= 2:
			# Secondary layered gold/tier flourish & diamond crest
			flourish.draw_line(Vector2(54.0, h - 5.0), Vector2(w - 54.0, h - 5.0), Color(1.0, 0.92, 0.56, 0.58), 1.3, true)
			var mx := w * 0.5
			var my := h - 10.0
			var d_sz := 4.5 + float(tier) * 0.8
			flourish.draw_colored_polygon(PackedVector2Array([
				Vector2(mx, my - d_sz), Vector2(mx + d_sz, my),
				Vector2(mx, my + d_sz), Vector2(mx - d_sz, my)
			]), tier_col.lightened(0.25))
		if tier >= 3:
			# Upper calligraphic arch stroke for 3x & 4x/Grand Seal
			flourish.draw_line(Vector2(64.0, 8.0), Vector2(w - 64.0, 8.0), Color(tier_col.r, tier_col.g, tier_col.b, 0.65), 1.5, true)
	)
	banner.add_child(flourish)

	var lbl := Label.new()
	lbl.text = txt
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_override("font", _get_font(true))
	lbl.add_theme_font_size_override("font_size", (24 + tier * 2) if is_player else 24)
	lbl.add_theme_color_override("font_color", tier_col.lightened(0.16))
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.01, 0.98))
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_child(lbl)

	hud_root.add_child(banner)
	var hold_sec := 3.2 if tier >= 2 else 2.0
	banner.scale = Vector2(0.62, 0.62)
	banner.modulate.a = 0.0
	var tw := banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, _pace(0.18))
	tw.tween_property(banner, "scale", Vector2(1.12 if tier >= 2 else 1.04, 1.12 if tier >= 2 else 1.04), _pace(0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "position:y", banner.position.y - 30.0, _pace(hold_sec + 0.55)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 0.0, _pace(0.55)).set_delay(_pace(hold_sec))
	var banner_wr: WeakRef = weakref(banner)
	tw.chain().tween_callback(func():
		var b_inst := banner_wr.get_ref() as Control
		if b_inst != null and _active_popup_lbl == b_inst:
			_active_popup_lbl = null
		if is_instance_valid(b_inst):
			b_inst.queue_free()
	)

func set_print_mode(mode_idx: int) -> void:
	var norm := posmod(mode_idx, 4)
	if norm == 1:
		norm = 2
	woodcut_print_mode = norm
	if woodcut_post_mat:
		woodcut_post_mat.set_shader_parameter("print_mode", woodcut_print_mode)

func _tr(en_txt: String, cs_txt: String) -> String:
	return Catalog.tr_loc(opts_language, en_txt, cs_txt)

func _get_stage_name_loc() -> String:
	return _tr(
		str(active_stage_data.get("stage_name", active_era.get("boss", "Rival"))),
		str(active_stage_data.get("stage_name_cs", active_era.get("boss_cs", active_stage_data.get("stage_name", "Soupeř"))))
	)

func _get_boss_desc_loc() -> String:
	return _tr(
		str(active_stage_data.get("boss_desc", "")),
		str(active_stage_data.get("boss_desc_cs", active_stage_data.get("boss_desc", "")))
	)

func _start_handwriting_anim(lbl: Label, full_txt: String, cps: float = 42.0, with_sfx: bool = true) -> void:
	if is_instance_valid(lbl):
		lbl.text = full_txt
	if lbl == tutorial_ghost_center_lbl and is_instance_valid(tutorial_ghost_quill):
		if is_instance_valid(lbl):
			lbl.visible = false
		tutorial_ghost_quill.visible = not full_txt.is_empty()
		tutorial_ghost_quill.call("start_text", full_txt, cps, opts_game_pace, with_sfx)
		_hw_targets.erase(lbl.get_instance_id())
		return
	if not is_instance_valid(lbl):
		return
	var key := lbl.get_instance_id()
	if full_txt.is_empty():
		lbl.visible_characters = -1
		_hw_targets.erase(key)
		return
	lbl.visible = true
	lbl.visible_characters = 0
	var pace_cps_mult := 0.76 if opts_game_pace == "relaxed" else (1.0 if opts_game_pace == "normal" else 1.55)
	_hw_targets[key] = {
		"lbl": lbl,
		"full_len": full_txt.length(),
		"chars_f": 0.0,
		"cps": maxf(16.0, cps * pace_cps_mult),
		"last_i": 0,
		"pop_t": 0.0,
		"with_sfx": with_sfx,
		"pen_sfx_cd": 0.0,
	}

func _finish_handwriting_anim(lbl: Label) -> void:
	if lbl == tutorial_ghost_center_lbl and is_instance_valid(tutorial_ghost_quill):
		tutorial_ghost_quill.call("finish_immediately")
		return
	if not is_instance_valid(lbl):
		return
	var key := lbl.get_instance_id()
	if _hw_targets.has(key):
		_hw_targets.erase(key)
	lbl.visible_characters = -1

func _is_handwriting_busy(lbl: Label) -> bool:
	if lbl == tutorial_ghost_center_lbl and is_instance_valid(tutorial_ghost_quill):
		return bool(tutorial_ghost_quill.call("is_busy"))
	if not is_instance_valid(lbl):
		return false
	return _hw_targets.has(lbl.get_instance_id())

func _get_handwriting_progress(lbl: Label) -> Dictionary:
	if lbl == tutorial_ghost_center_lbl and is_instance_valid(tutorial_ghost_quill):
		return {"active": bool(tutorial_ghost_quill.call("is_busy")), "frac": 1.0, "pop": 0.0}
	if not is_instance_valid(lbl):
		return {"active": false, "frac": 1.0, "pop": 0.0}
	var key := lbl.get_instance_id()
	if not _hw_targets.has(key):
		return {"active": false, "frac": 1.0, "pop": 0.0}
	var e: Dictionary = _hw_targets[key]
	var flen := maxi(1, int(e.get("full_len", 1)))
	return {
		"active": true,
		"frac": clampf(float(e.get("chars_f", 0.0)) / float(flen), 0.0, 1.0),
		"pop": float(e.get("pop_t", 0.0)),
	}

func _step_handwriting_anims(delta: float) -> void:
	if is_instance_valid(tutorial_ghost_quill) and tutorial_ghost_quill.visible:
		tutorial_ghost_quill.call("step_anim", delta)
	if _hw_targets.is_empty():
		return
	var done_keys: Array = []
	for key in _hw_targets.keys():
		var e: Dictionary = _hw_targets[key]
		var lbl: Label = e.get("lbl")
		if not is_instance_valid(lbl):
			done_keys.append(key)
			continue
		var full_len := int(e.get("full_len", 0))
		var cf := float(e.get("chars_f", 0.0)) + delta * float(e.get("cps", 42.0))
		var cur_i := mini(full_len, int(cf))
		var prev_i := int(e.get("last_i", 0))
		e["chars_f"] = cf
		e["pop_t"] = maxf(0.0, float(e.get("pop_t", 0.0)) - delta * 6.5)
		e["pen_sfx_cd"] = maxf(0.0, float(e.get("pen_sfx_cd", 0.0)) - delta)
		if cur_i > prev_i:
			e["last_i"] = cur_i
			lbl.visible_characters = cur_i
			e["pop_t"] = 1.0
			if bool(e.get("with_sfx", true)) and float(e.get("pen_sfx_cd", 0.0)) <= 0.0:
				e["pen_sfx_cd"] = 0.095
				emit_signal("play_sfx_pitched_requested", "quill_scratch", randf_range(0.92, 1.18))
		if cur_i >= full_len:
			lbl.visible_characters = -1
			done_keys.append(key)
	for dk in done_keys:
		_hw_targets.erase(dk)

func _is_hand_tucked() -> bool:
	return cards_tucked

func _get_rank_name(r_id: String) -> String:
	for r in RANKS:
		if r["id"] == r_id:
			return _tr(str(r["name"]), str(r.get("name_cs", r["name"])))
	return r_id

func _refresh_hud_language_labels() -> void:
	if tutorial_skip_btn:
		tutorial_skip_btn.text = _tr("Skip ›", "Přeskočit ›")
	if quick_play_btn:
		quick_play_btn.text = _tr("PLAY CARD [W]", "HRÁT KARTU [W]")
	if quick_peek_btn:
		quick_peek_btn.text = _tr("VIEW TABLE [SPACE]", "POHLED STŮL [SPACE]")
	if is_instance_valid(view_toggle_btn):
		view_toggle_btn.text = _tr("Cards [TAB]", "Karty [TAB]") if cam_view_mode == CameraViewMode.TABLE_ITEMS else _tr("Items [TAB]", "Itemy [TAB]")
		LialoIcons.apply_button_icon(view_toggle_btn, "cards" if cam_view_mode == CameraViewMode.TABLE_ITEMS else "sword", 16)
		view_toggle_btn.tooltip_text = _tr("Toggle Camera View: Hand Cards <-> 3D Table Items [TAB / SPACE]", "Přepnout pohled kamery: Karty v ruce <-> 3D Itemy na stole [TAB / SPACE]")
	_refresh_wager_indicator_ui()
	if settings_icon_btn:
		settings_icon_btn.tooltip_text = _tr("Options", "Nastavení")
	if card_guide_btn:
		card_guide_btn.tooltip_text = _tr("Actions & Help Drawer ([F1] Guide)", "Akce a Nápověda ([F1] Průvodce)")
	if is_instance_valid(drawer_guide_btn):
		drawer_guide_btn.text = _tr("Card Guide [F1]", "Průvodce [F1]")
	for sb_entry in sort_hand_btns:
		var b: Button = sb_entry.get("btn")
		if is_instance_valid(b):
			b.text = _tr(str(sb_entry.get("en", "")), str(sb_entry.get("cs", "")))
	if peddler_title_lbl and not peddler_open:
		peddler_title_lbl.text = _tr("☾ CROSSROADS SHOP — 3D ARTIFACTS ☽", "☾ KUPECKÝ OBCHOD — 3D ARTEFAKTY ☽")
	if peddler_reroll_btn:
		peddler_reroll_btn.text = _tr("New Wares (10g)", "Nové zboží (10g)")
	if peddler_close_btn:
		peddler_close_btn.text = _tr("Return to Duel ›", "Zpět do duelu ›")
	if mist_guess_title_lbl:
		mist_guess_title_lbl.text = _tr("BATTLE MIST — GUESS THE KNIGHT!", "BOJOVÁ MLHA — UHÁDNI RYTÍŘE!")
	if mist_guess_sub_lbl:
		mist_guess_sub_lbl.text = _tr("Right guess = +10 pts! Wrong = Draw +1 card!", "Správně = +10 b.! Špatně = Lízáš +1 kartu!")
	if thief_heist_title_lbl:
		thief_heist_title_lbl.text = _tr("CUTPURSE HEIST — GUESS 2+ CARDS", "ZLODĚJ — UHÁDNI 2+ STEJNÉ KARTY")
	if thief_heist_cls_lbl:
		thief_heist_cls_lbl.text = _tr("Pick Class (Merchants = 2×! Mages immune!):", "Vyber třídu (Kupci = 2×! Mágové imunní!):")
	if thief_heist_rank_lbl:
		thief_heist_rank_lbl.text = _tr("Or guess 2+ of a Rank:", "Nebo uhádni 2+ stejné hodnoty:")
	if thief_heist_skip_btn:
		thief_heist_skip_btn.text = _tr("Skip Heist", "Přeskočit")
	for ce in thief_heist_class_btns:
		var cb: Button = ce.get("btn")
		if is_instance_valid(cb):
			cb.text = _tr(str(ce.get("en", "")), str(ce.get("cs", "")))
	for re in thief_heist_rank_btns:
		var rb: Button = re.get("btn")
		if is_instance_valid(rb):
			rb.text = "2+ %s" % _get_rank_name(str(re.get("id", "")))
	if boss_rule_lbl:
		if not tutorial_mode and active_boss_mod != "":
			var b_desc := _get_boss_desc_loc()
			if b_desc != "":
				boss_rule_lbl.text = "%s: %s" % [_get_stage_name_loc(), b_desc]
				boss_rule_lbl.tooltip_text = "%s\n%s" % [b_desc, _get_boss_counterplay_tip()]
	if shop_gate_overlay and shop_gate_overlay.visible:
		if shop_gate_title:
			shop_gate_title.text = _tr("ENTER THE CROSSROADS SHOP?", "OTEVŘÍT KUPECKÝ OBCHOD?")
		if shop_gate_yes_btn:
			shop_gate_yes_btn.text = _tr("YES — ENTER SHOP", "ANO — VSTOUPIT")
		if shop_gate_no_btn:
			shop_gate_no_btn.text = _tr("NO — CONTINUE", "NE — POKRAČOVAT")
	if peddler_open:
		if peddler_title_lbl:
			peddler_title_lbl.text = _tr("☾ ROUND %d CROSSROADS SHOP ☽" % current_round_num, "☾ OBCHOD PO %d. KOLE ☽" % current_round_num)
		_rebuild_peddler_ui()

func _pace(base_sec: float) -> float:
	var mult := 1.0 if opts_game_pace == "relaxed" else (0.82 if opts_game_pace == "normal" else 0.50)
	return maxf(0.03, base_sec * mult)

func apply_options(opts: Dictionary) -> void:
	opts_language = str(opts.get("language", "en"))
	opts_high_fx = bool(opts.get("high_fx", true))
	opts_cam_sens = clampf(float(opts.get("cam_sensitivity", opts.get("cam_sens", 1.0))), 0.4, 2.2)
	var gp := str(opts.get("game_pace", "relaxed"))
	opts_game_pace = gp if (gp in ["relaxed", "normal", "fast"]) else "relaxed"
	opts_turn_timer_sec = clampf(float(opts.get("turn_timer_sec", 35)), 30.0, 45.0)
	player_turn_timer = minf(player_turn_timer, opts_turn_timer_sec)
	turn_glance_duration = _pace(1.45)
	set_print_mode(int(opts.get("visual_mode", 3)))
	if is_instance_valid(dust_motes_root):
		dust_motes_root.visible = opts_high_fx
	if is_instance_valid(chandelier_cone_mesh):
		chandelier_cone_mesh.visible = opts_high_fx
	if hud_shop_btn:
		hud_shop_btn.text = _tr("✦ SHOP", "✦ OBCHOD")
	_sync_contextual_cancel_btn()
	if tutorial_continue_btn and tutorial_step == 0:
		tutorial_continue_btn.text = _tr("Continue [SPACE] ▸", "Pokračovat [SPACE] ▸")
	_refresh_suit_modal_labels()
	_refresh_hud_language_labels()
	_refresh_boss_stone_plaque_3d()
	set_duel_wager(active_wager_type, true)
	if tutorial_mode:
		_update_tutorial_callout_ui(tutorial_step, false)
	if is_inside_tree() and player_hand.size() > 0:
		_rebuild_all_3d_hands()
	if not discard_pile.is_empty():
		_refresh_discard_top_mesh()
	_refresh_table_labels()

func _attach_sword_hover_area(sw: Node3D) -> void:
	if not is_instance_valid(sw) or sw.get_node_or_null("SwordArea") != null:
		return
	var s_area := Area3D.new()
	s_area.name = "SwordArea"
	var s_col := CollisionShape3D.new()
	var s_box := BoxShape3D.new()
	s_box.size = Vector3(0.13, 0.08, 0.50)
	s_col.shape = s_box
	s_col.position = Vector3(0.0, 0.03, 0.0)
	s_area.add_child(s_col)
	sw.add_child(s_area)

func _make_arrow_compass_ring_mat(ring_col: Color, arrow_cnt: float = 8.0, spd: float = 1.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 ring_color : source_color = vec4(1.0, 0.82, 0.32, 0.90);
uniform float num_arrows = 8.0;
uniform float anim_spd = 1.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float outer_ring = smoothstep(0.024, 0.004, abs(r - 0.90));
	float mid_ring = smoothstep(0.018, 0.003, abs(r - 0.74));
	float inner_ring = smoothstep(0.020, 0.003, abs(r - 0.54));
	float ticks = smoothstep(0.42, 0.68, cos(ang * 36.0 + TIME * 0.4 * anim_spd)) * smoothstep(0.05, 0.01, abs(r - 0.82));
	float runes = smoothstep(0.12, 0.38, sin(ang * 16.0 - TIME * 0.8 * anim_spd)) * smoothstep(0.028, 0.006, abs(r - 0.64));
	// Animated inward-pointing chevron arrows around the circle!
	float a_cell = fract((ang / 6.2831853) * num_arrows) * 2.0 - 1.0;
	float pulse_r = 0.78 - 0.055 * sin(TIME * 3.4 * anim_spd);
	float chev_dist = abs(r - (pulse_r - abs(a_cell) * 0.11));
	float chev = smoothstep(0.026, 0.005, chev_dist) * smoothstep(0.66, 0.56, abs(a_cell)) * smoothstep(0.53, 0.59, r) * smoothstep(0.95, 0.89, r);
	float chev2_dist = abs(r - (pulse_r - 0.12 - abs(a_cell) * 0.09));
	float chev2 = smoothstep(0.020, 0.004, chev2_dist) * smoothstep(0.52, 0.42, abs(a_cell)) * smoothstep(0.43, 0.49, r) * smoothstep(0.87, 0.81, r) * 0.75;
	float alpha = clamp(outer_ring * 0.95 + mid_ring * 0.75 + inner_ring * 0.65 + ticks * 0.70 + runes * 0.55 + (chev + chev2) * 1.15, 0.0, 1.0);
	ALBEDO = mix(ring_color.rgb, vec3(1.0, 0.97, 0.84), clamp(chev + chev2, 0.0, 1.0) * 0.55);
	ALPHA = alpha * ring_color.a * smoothstep(1.0, 0.94, r);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.render_priority = 1
	sm.set_shader_parameter("ring_color", ring_col)
	sm.set_shader_parameter("num_arrows", arrow_cnt)
	sm.set_shader_parameter("anim_spd", spd)
	return sm

func _build_seamless_ghost_shroud_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	var rings := 36
	var grid: Array = []
	for ri in range(rings + 1):
		var v := float(ri) / float(rings) # 0.0 = wispy tattered bottom tail, 1.0 = pointed gothic cowl apex
		var y := lerpf(-0.08, 0.88, v)
		var row: Array = []
		for si in range(segs + 1):
			var u := float(si) / float(segs)
			var ang := u * TAU # ang = PI*0.5 is front (+Z)
			var front_w := maxf(0.0, sin(ang))
			var base_r := 0.16
			if v < 0.34:
				# Tapering ethereal lower tail
				base_r = lerpf(0.095, 0.185, smoothstep(0.0, 0.34, v))
			elif v < 0.56:
				# Slender waist flaring softly into draped phantom shoulders
				var shoulder_w := sin(smoothstep(0.36, 0.56, v) * PI * 0.5)
				base_r = lerpf(0.170, 0.220, shoulder_w)
			elif v < 0.67:
				# Smooth neck / collar pinch right below the skull jaw
				base_r = lerpf(0.220, 0.132, smoothstep(0.56, 0.67, v))
			elif v < 0.89:
				# Smooth continuous gothic cowl arching neatly over skull without side balloons
				var cowl_arch := sin(smoothstep(0.67, 0.89, v) * PI)
				base_r = lerpf(0.132, 0.088, smoothstep(0.67, 0.89, v)) + cowl_arch * 0.044
			else:
				# Pointed gothic hood tip
				base_r = lerpf(0.088, 0.008, smoothstep(0.89, 1.0, v))

			var pleat_env := smoothstep(0.64, 0.25, v)
			var pleat := (0.015 * sin(ang * 8.0 + v * 3.8) + 0.007 * cos(ang * 13.0 - v * 2.5)) * pleat_env
			var tail_mask := pow(clampf(1.0 - v * 2.75, 0.0, 1.0), 1.35)
			var hem_tatter := (0.062 * sin(ang * 7.0) + 0.036 * cos(ang * 11.0 + 0.6) + 0.020 * sin(ang * 15.0)) * tail_mask
			var tail_curl := sin(v * 7.5 + ang * 2.0) * 0.025 * tail_mask
			var r := maxf(0.008, base_r + pleat)
			var px := cos(ang) * r
			var hood_sweep := pow(maxf(0.0, (v - 0.66) / 0.34), 1.45) * 0.145
			var pz := sin(ang) * r * 0.86 + tail_curl - hood_sweep
			var py := y + hem_tatter
			# Smooth front gothic hood aperture framing the 3D skull cleanly
			if v > 0.66 and v < 0.90 and front_w > 0.30:
				var hood_arch := sin(clampf((v - 0.66) / 0.24, 0.0, 1.0) * PI)
				var face_depth := smoothstep(0.30, 0.86, front_w) * hood_arch
				pz -= face_depth * 0.115
				px *= (1.0 + 0.08 * hood_arch * (1.0 - face_depth))
			row.append({"pos": Vector3(px, py, pz), "uv": Vector2(u, 1.0 - v)})
		grid.append(row)
	for ri in range(rings):
		var r0: Array = grid[ri]
		var r1: Array = grid[ri + 1]
		for si in range(segs):
			var a: Dictionary = r0[si]
			var b: Dictionary = r0[si + 1]
			var c: Dictionary = r1[si]
			var d: Dictionary = r1[si + 1]
			for tri in [[a, b, c], [b, d, c]]:
				for vert in tri:
					st.set_uv(vert["uv"])
					st.add_vertex(vert["pos"])
	st.index()
	st.generate_normals()
	return st.commit()

func _build_ghost_tendril_mesh(width_top: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 10
	var cols := 3
	var pts: Array = []
	for ri in range(rows + 1):
		var t := float(ri) / float(rows)
		var y := -t * length
		var w := width_top * (1.0 - pow(t, 0.82)) * 0.5
		var z_curve := sin(t * PI * 1.4) * 0.035 + t * 0.02
		var row: Array = []
		for ci in range(cols + 1):
			var u := float(ci) / float(cols)
			var x := (u - 0.5) * 2.0 * w
			row.append({"pos": Vector3(x, y, z_curve), "uv": Vector2(u, t)})
		pts.append(row)
	for ri in range(rows):
		var r0: Array = pts[ri]
		var r1: Array = pts[ri + 1]
		for ci in range(cols):
			var a: Dictionary = r0[ci]
			var b: Dictionary = r0[ci + 1]
			var c: Dictionary = r1[ci]
			var d: Dictionary = r1[ci + 1]
			for tri in [[a, c, b], [b, c, d]]:
				for vert in tri:
					st.set_uv(vert["uv"])
					st.add_vertex(vert["pos"])
	st.index()
	st.generate_normals()
	return st.commit()

func _build_detailed_tutorial_ghost() -> void:
	if not is_instance_valid(tutorial_ghost_3d):
		return
	tutorial_ghost_tendrils.clear()
	tutorial_ghost_wisps.clear()
	tutorial_ghost_arm_left = null
	tutorial_ghost_mouth = null
	for ch in tutorial_ghost_3d.get_children():
		if ch != tutorial_ghost_light and ch != tutorial_ghost_speech_3d:
			ch.queue_free()

	# Truly Ethereal Semi-Transparent Spectral Wraith Shader (GL Compatibility safe)
	var phantom_shader := Shader.new()
	phantom_shader.code = """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;
uniform vec4 base_col : source_color = vec4(0.10, 0.28, 0.44, 0.18);
uniform vec4 fold_col : source_color = vec4(0.24, 0.64, 0.88, 0.40);
uniform vec4 rim_col : source_color = vec4(0.62, 0.96, 1.00, 1.0);
varying float v_y;
varying vec3 v_pos;
void vertex() {
	float low_w = pow(clamp(1.0 - VERTEX.y * 1.15, 0.0, 1.0), 1.25);
	VERTEX.x += sin(TIME * 2.3 + VERTEX.y * 5.5 + VERTEX.z * 4.5) * 0.032 * low_w;
	VERTEX.z += cos(TIME * 1.9 + VERTEX.y * 4.8 + VERTEX.x * 5.0) * 0.026 * low_w;
	v_y = UV.y;
	v_pos = VERTEX;
}
void fragment() {
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.25);
	float mist_a = 0.5 + 0.5 * sin(v_pos.y * 18.0 - TIME * 2.6 + sin(v_pos.x * 22.0 + TIME * 1.4));
	float mist_b = 0.5 + 0.5 * cos(v_pos.x * 30.0 - TIME * 1.9 + v_pos.y * 11.0);
	float mist = mist_a * 0.65 + mist_b * 0.35;
	vec3 cloth = mix(base_col.rgb, fold_col.rgb, clamp(mist * 0.48 + fres * 0.52, 0.0, 1.0));
	ALBEDO = mix(cloth, rim_col.rgb, fres * 0.86);
	EMISSION = rim_col.rgb * (fres * 1.18 + mist * 0.22);
	ROUGHNESS = 0.32;
	float hem_fade = 1.0 - smoothstep(0.56, 0.98, v_y + (mist - 0.5) * 0.24);
	float hood_focus = smoothstep(0.45, 0.12, v_y) * 0.16;
	float a_core = mix(base_col.a, fold_col.a, mist * 0.55) + fres * 0.54 + hood_focus;
	ALPHA = clamp(a_core * hem_fade, 0.02, 0.78);
}
"""
	var shroud_mat := ShaderMaterial.new()
	shroud_mat.shader = load("res://shaders/spirit_chiaroscuro.gdshader")
	var shroud_weave_tex := Toon.tex("res://assets/textures/tavern/ghost_shroud_weave_ink.png")
	if shroud_weave_tex:
		shroud_mat.set_shader_parameter("shroud_tex", shroud_weave_tex)
	var clasp_mat := Toon.pbr(Color(0.76, 0.94, 1.0), "", 0.20, 0.90, Vector2.ONE, Color(0.32, 0.86, 1.0), 1.35)

	var tendril_shader := Shader.new()
	tendril_shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec4 rim_col : source_color = vec4(0.56, 0.95, 1.0, 1.0);
varying float v_t;
void vertex() {
	v_t = UV.y;
	VERTEX.x += sin(TIME * 3.4 + v_t * 5.0) * 0.018 * v_t;
	VERTEX.z += cos(TIME * 2.8 + v_t * 4.5) * 0.016 * v_t;
}
void fragment() {
	float fade = (1.0 - smoothstep(0.35, 1.0, v_t)) * (0.55 + 0.45 * sin(TIME * 4.0 - v_t * 8.0));
	ALBEDO = rim_col.rgb;
	EMISSION = rim_col.rgb * 1.15;
	ALPHA = clamp(fade * 0.44, 0.0, 0.58);
}
"""
	var tendril_mat := ShaderMaterial.new()
	tendril_mat.shader = tendril_shader

	# Blender-sculpted Hooded Wraith Shroud (ghost_shroud.glb) wrapped in translucent Fresnel phantom shader
	var shroud_glb := _load_glb_model("res://assets/models/ghost_shroud.glb", false)
	if shroud_glb:
		shroud_glb.name = "GhostShroudGLB"
		_apply_mat_by_mesh_name(shroud_glb, {
			"shroudclasp": clasp_mat,
			"shroudouter": shroud_mat,
			"shroudinner": shroud_mat,
		})
		tutorial_ghost_3d.add_child(shroud_glb)
	else:
		var shroud_mi := MeshInstance3D.new()
		shroud_mi.mesh = _build_seamless_ghost_shroud_mesh()
		shroud_mi.material_override = shroud_mat
		tutorial_ghost_3d.add_child(shroud_mi)

	# Glowing translucent ectoplasm soul-core visible INSIDE the transparent chest!
	var soul_core_mat := StandardMaterial3D.new()
	soul_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soul_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soul_core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	soul_core_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	soul_core_mat.albedo_color = Color(0.42, 0.92, 1.0, 0.28)
	var soul_core := MeshInstance3D.new()
	var sc_s := SphereMesh.new(); sc_s.radius = 0.088; sc_s.height = 0.34
	soul_core.mesh = sc_s
	soul_core.position = Vector3(0.0, 0.44, 0.0)
	soul_core.scale = Vector3(0.95, 1.0, 0.72)
	soul_core.material_override = soul_core_mat
	tutorial_ghost_3d.add_child(soul_core)

	# 6 Floating Wispy Spectral Tendrils billowing off the cloak tail
	for ti in range(6):
		var tang := float(ti) * (TAU / 6.0) + 0.3
		var td_root := Node3D.new()
		td_root.position = Vector3(cos(tang) * 0.16, 0.14, sin(tang) * 0.13)
		td_root.set_meta("base_yaw", rad_to_deg(tang))
		td_root.set_meta("phase", float(ti) * 1.05)
		var td_mesh := MeshInstance3D.new()
		td_mesh.mesh = _build_ghost_tendril_mesh(0.085, 0.34)
		td_mesh.material_override = tendril_mat
		td_root.add_child(td_mesh)
		tutorial_ghost_3d.add_child(td_root)
		tutorial_ghost_tendrils.append(td_root)

	# Soft dark mist/shadow pool beneath the floating phantom
	var mist_pool := MeshInstance3D.new()
	var mpq := QuadMesh.new(); mpq.size = Vector2(0.65, 0.65)
	mist_pool.mesh = mpq
	mist_pool.position = Vector3(0.0, 0.015, 0.0)
	mist_pool.rotation_degrees.x = -90.0
	var mp_mat := StandardMaterial3D.new()
	mp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mp_mat.albedo_texture = Fx.soft_tex()
	mp_mat.albedo_color = Color(0.02, 0.05, 0.08, 0.52)
	mist_pool.material_override = mp_mat
	mist_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tutorial_ghost_3d.add_child(mist_pool)

	# 12 Orbiting Textured Soul-Mist Ribbon Wisps spiraling softly up around the phantom
	var wisp_mat := ShaderMaterial.new()
	wisp_mat.shader = load("res://shaders/relic_ribbon_wisp.gdshader")
	var wisp_atlas := Toon.tex("res://assets/vfx/relic_ink_particles_atlas.png")
	if wisp_atlas:
		wisp_mat.set_shader_parameter("atlas_tex", wisp_atlas)
	wisp_mat.set_shader_parameter("wisp_color", Color(0.56, 0.96, 1.0, 0.72))
	for wi in range(12):
		var wm := MeshInstance3D.new()
		var wqm := QuadMesh.new(); wqm.size = Vector2(0.026, 0.11); wqm.subdivide_depth = 4
		wm.mesh = wqm; wm.material_override = wisp_mat
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wm.set_meta("rad", randf_range(0.20, 0.34))
		wm.set_meta("phase", float(wi) * (TAU / 12.0))
		wm.set_meta("spd", randf_range(0.65, 1.30))
		wm.set_meta("base_sc", randf_range(0.85, 1.35))
		tutorial_ghost_3d.add_child(wm)
		tutorial_ghost_wisps.append(wm)

	var eye_mat := Toon.pbr(Color(0.54, 0.96, 1.0), "", 0.08, 0.0, Vector2.ONE, Color(0.42, 0.92, 1.0), 4.8)
	var pupil_mat := Toon.pbr(Color(1.0, 0.96, 0.58), "", 0.04, 0.0, Vector2.ONE, Color(1.0, 0.88, 0.34), 6.2)
	var bone_mat := Toon.pbr(Color(0.84, 0.78, 0.66), "res://assets/textures/tavern/ghost_skull_ivory_ink.png", 0.58, 0.03, Vector2.ONE, Color(0.06, 0.14, 0.18), 0.16)
	var tooth_mat := Toon.pbr(Color(0.94, 0.90, 0.80), "", 0.30, 0.04, Vector2.ONE, Color(0.05, 0.10, 0.14), 0.10)
	var socket_dark_mat := Toon.pbr(Color(0.015, 0.02, 0.038), "", 0.94, 0.0)
	var lantern_ember_mat := Toon.pbr(Color(0.58, 0.96, 1.0), "", 0.08, 0.0, Vector2.ONE, Color(1.0, 0.84, 0.38), 5.2)

	# 3D Blender-Sculpted Anatomical Human Skull inside the ghostly hood
	tutorial_ghost_skull_root = Node3D.new()
	tutorial_ghost_skull_root.position = Vector3(0.0, 0.675, 0.048)
	tutorial_ghost_3d.add_child(tutorial_ghost_skull_root)

	var skull_glb := _load_glb_model("res://assets/models/ghost_skull.glb", false)
	if skull_glb:
		skull_glb.name = "GhostSkullGLB"
		_apply_mat_by_mesh_name(skull_glb, {
			"shadow": socket_dark_mat,
			"tooth": tooth_mat,
			"cranium": bone_mat,
			"zygomatic": bone_mat,
			"nasal": bone_mat,
		})
		tutorial_ghost_skull_root.add_child(skull_glb)

	# Animated Eye Rigs nestled cleanly inside the sculpted anatomical eye sockets
	for sx in [-1.0, 1.0]:
		var eye_rig := Node3D.new()
		eye_rig.position = Vector3(sx * 0.0245, 0.008, 0.051)
		tutorial_ghost_skull_root.add_child(eye_rig)

		var eye_glow := MeshInstance3D.new()
		var pm := SphereMesh.new(); pm.radius = 0.0105; pm.height = 0.018
		eye_glow.mesh = pm
		eye_glow.scale = Vector3(1.08, 0.90, 0.72)
		eye_glow.material_override = eye_mat
		eye_rig.add_child(eye_glow)

		var pupil_core := MeshInstance3D.new()
		var pcm := SphereMesh.new(); pcm.radius = 0.0052; pcm.height = 0.010
		pupil_core.mesh = pcm
		pupil_core.position = Vector3(0.0, 0.0, 0.0068)
		pupil_core.material_override = pupil_mat
		eye_rig.add_child(pupil_core)

		if sx < 0.0:
			tutorial_ghost_eye_left = eye_rig
			tutorial_ghost_pupil_left = pupil_core
		else:
			tutorial_ghost_eye_right = eye_rig
			tutorial_ghost_pupil_right = pupil_core

	# Sculpted Articulated Lower Jaw / Mandible with Individual Lower Teeth (chatters when speaking!)
	tutorial_ghost_jaw_root = Node3D.new()
	tutorial_ghost_jaw_root.position = Vector3(0.0, -0.034, 0.014)
	tutorial_ghost_jaw_root.rotation_degrees.x = 5.0
	tutorial_ghost_skull_root.add_child(tutorial_ghost_jaw_root)

	var jaw_glb := _load_glb_model("res://assets/models/ghost_jaw.glb", false)
	if jaw_glb:
		jaw_glb.name = "GhostJawGLB"
		_apply_mat_by_mesh_name(jaw_glb, {
			"tooth": tooth_mat,
			"mandible": bone_mat,
			"chin": bone_mat,
		})
		tutorial_ghost_jaw_root.add_child(jaw_glb)

	# Translucent spectral hand material for delicate skeletal hands on both arms
	var spec_hand_mat := StandardMaterial3D.new()
	spec_hand_mat.albedo_color = Color(0.76, 0.96, 1.0, 0.68)
	spec_hand_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spec_hand_mat.emission_enabled = true
	spec_hand_mat.emission = Color(0.45, 0.90, 1.0)
	spec_hand_mat.emission_energy_multiplier = 0.90

	# Right draped sleeve, skeletal hand & Blender wrought-iron spirit lantern
	tutorial_ghost_arm = Node3D.new()
	tutorial_ghost_arm.position = Vector3(0.15, 0.48, 0.06)
	tutorial_ghost_3d.add_child(tutorial_ghost_arm)

	var r_hand_glb := _load_glb_model("res://assets/models/ghost_hand_r.glb", false)
	if r_hand_glb:
		r_hand_glb.name = "GhostHandRGLB"
		_apply_mat_by_mesh_name(r_hand_glb, {
			"ghostsleeve": shroud_mat,
			"spectral": spec_hand_mat,
			"finger": spec_hand_mat,
			"thumb": spec_hand_mat,
		})
		tutorial_ghost_arm.add_child(r_hand_glb)

	var lantern_grp := Node3D.new()
	lantern_grp.position = Vector3(0.038, -0.178, 0.215)
	tutorial_ghost_arm.add_child(lantern_grp)

	var lan_glb := _load_glb_model("res://assets/models/ghost_lantern.glb", false)
	if lan_glb:
		lan_glb.name = "GhostLanternGLB"
		_apply_mat_by_mesh_name(lan_glb, {
			"lanterncore": lantern_ember_mat,
		})
		lantern_grp.add_child(lan_glb)

	var l_halo := MeshInstance3D.new()
	var lhs := SphereMesh.new(); lhs.radius = 0.052; lhs.height = 0.085
	l_halo.mesh = lhs; l_halo.material_override = soul_core_mat
	lantern_grp.add_child(l_halo)

	# Left draped spectral arm + beckoning ghostly fingers
	tutorial_ghost_arm_left = Node3D.new()
	tutorial_ghost_arm_left.position = Vector3(-0.15, 0.48, 0.05)
	tutorial_ghost_3d.add_child(tutorial_ghost_arm_left)

	var l_hand_glb := _load_glb_model("res://assets/models/ghost_hand_l.glb", false)
	if l_hand_glb:
		l_hand_glb.name = "GhostHandLGLB"
		_apply_mat_by_mesh_name(l_hand_glb, {
			"ghostsleeve": shroud_mat,
			"spectral": spec_hand_mat,
			"finger": spec_hand_mat,
			"thumb": spec_hand_mat,
		})
		tutorial_ghost_arm_left.add_child(l_hand_glb)

func _add_opp_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_opponent_sculpted_head(head_root: Node3D, skin_mat: Material, socket_mat: Material, iris_mat: Material, brow_mat: Material, is_boss: bool, era: String) -> void:
	var head_glb := _load_glb_model("res://assets/models/opp_head.glb", true)
	if head_glb:
		head_glb.name = "OppHeadGLB"
		_apply_mat_by_mesh_name(head_glb, {
			"brows": brow_mat,
			"skin": skin_mat,
		})
		head_root.add_child(head_glb)
	else:
		var cran_m := SphereMesh.new(); cran_m.radius = 0.110; cran_m.height = 0.228; cran_m.radial_segments = 22; cran_m.rings = 12
		_add_opp_mesh(head_root, cran_m, Vector3(0.0, 0.095, -0.004), skin_mat, Vector3.ZERO, Vector3(0.90, 1.04, 0.98))

	# Expressive Recessed Eye Sockets & Luminous Blinking Eyes (keep animated!)
	var sclera_mat := Toon.pbr(Color(0.88, 0.85, 0.78), "", 0.38, 0.0)
	var eye_y := 0.106
	for side_x in [-1.0, 1.0]:
		var sx := float(side_x)
		var skip_eye: bool = (era == "objavy" and is_boss and sx < 0.0)

		var sk := SphereMesh.new(); sk.radius = 0.017; sk.height = 0.022; sk.radial_segments = 12
		_add_opp_mesh(head_root, sk, Vector3(sx * 0.038, eye_y, 0.092), socket_mat, Vector3.ZERO, Vector3(1.18, 0.72, 0.45))

		if not skip_eye:
			var sc := SphereMesh.new(); sc.radius = 0.0102; sc.height = 0.013; sc.radial_segments = 12
			var eye_white := _add_opp_mesh(head_root, sc, Vector3(sx * 0.038, eye_y, 0.098), sclera_mat, Vector3.ZERO, Vector3(1.12, 0.72, 0.65))
			opp_eye_nodes.append(eye_white)

			var ir := SphereMesh.new(); ir.radius = 0.0064; ir.height = 0.010; ir.radial_segments = 10
			var iris := _add_opp_mesh(head_root, ir, Vector3(sx * 0.038, eye_y, 0.104), iris_mat, Vector3.ZERO, Vector3(1.0, 0.92, 0.65))
			opp_eye_nodes.append(iris)
			if is_boss:
				if sx < 0.0:
					boss_eye_left = iris
				else:
					boss_eye_right = iris

func _apply_subtle_outline_next_pass(root: Node, thickness: float = 0.0040, outline_col: Color = Color(0.045, 0.032, 0.026, 1.0)) -> void:
	if not is_instance_valid(root):
		return
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OUTLINE_SHADER
	outline_mat.set_shader_parameter("outline_color", outline_col)
	outline_mat.set_shader_parameter("thickness", thickness)
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var nm := mi.name.to_lower()
			var skip_outline := ("eye" in nm) or ("socket" in nm) or ("ember" in nm) or ("pupil" in nm) or ("iris" in nm) or ("glow" in nm)
			if not skip_outline and mi.mesh != null:
				for si in range(mi.mesh.get_surface_count()):
					var base_mat := mi.get_surface_override_material(si)
					if base_mat == null:
						base_mat = mi.mesh.surface_get_material(si)
					if base_mat is BaseMaterial3D:
						var dup := base_mat.duplicate() as BaseMaterial3D
						dup.next_pass = outline_mat
						mi.set_surface_override_material(si, dup)
		for ch in cur.get_children():
			stack.append(ch)

func _hide_non_boss_headgear_meshes(head_piv: Node3D) -> void:
	if not is_instance_valid(head_piv):
		return
	for ch in head_piv.get_children():
		if not (ch is Node3D):
			continue
		var nm := ch.name.to_lower()
		var keep_face := (
			nm.begins_with("sculpted")
			or nm.begins_with("nose")
			or nm.begins_with("eye")
			or nm.begins_with("kohl")
			or ("cheekscar" in nm)
			or ("hoopearring" in nm)
			or ("piratebeard" in nm)
			or ("beard" in nm)
		)
		if not keep_face:
			(ch as Node3D).visible = false

func _build_detailed_opponent_character(era_id: String, rim_col: Color = Color(1.0, 0.66, 0.22)) -> void:
	if not is_instance_valid(opp_silhouette_root):
		return
	for ch in opp_silhouette_root.get_children():
		ch.queue_free()
	opp_eye_nodes.clear()
	opp_torso_node = null
	opp_head_node = null
	opp_arm_left_node = null
	opp_arm_right_node = null
	boss_eye_left = null
	boss_eye_right = null

	var e := era_id.to_lower()
	var tier := _get_opponent_visual_tier()
	var is_boss := (tier >= 2)
	var is_elite := (tier == 1)

	# Dedicated warm front key fill light so opponent & Campaign Boss facial features, crowns & garments read clearly
	var opp_key_light := OmniLight3D.new()
	opp_key_light.position = Vector3(0.0, 0.95, 0.78)
	opp_key_light.light_color = Color(1.0, 0.93, 0.84)
	opp_key_light.light_energy = 1.30 if is_boss else (1.05 if is_elite else 0.92)
	opp_key_light.omni_range = 2.8
	opp_silhouette_root.add_child(opp_key_light)

	boss_eye_mat = StandardMaterial3D.new()
	boss_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boss_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	boss_eye_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	boss_eye_mat.albedo_color = Color(rim_col.r, rim_col.g, rim_col.b, 0.60 if is_boss else 0.38)

	# 1. Load Sculpted Blender 5.3 Era Opponent GLB (Task #3 verified pivot contract: TorsoPivot, HeadPivot, ArmLPivot, ArmRPivot, EyeL, EyeR)
	var era_opp_map := {
		"antika": "res://assets/models/opponents/opp_antika.glb",
		"rim": "res://assets/models/opponents/opp_rim.glb",
		"stredovek": "res://assets/models/opponents/opp_stredovek.glb",
		"objavy": "res://assets/models/opponents/opp_objavy.glb",
		"prohibicia": "res://assets/models/opponents/opp_prohibicia.glb",
	}
	var resolved_era := e if era_opp_map.has(e) else "stredovek"
	var era_opp_glb := _load_glb_model(str(era_opp_map[resolved_era]), true)
	if era_opp_glb != null:
		_has_sculpted_opp_glb = true
		if is_instance_valid(opp_glove_left_mesh):
			opp_glove_left_mesh.visible = not opp_card_nodes.is_empty()
		if is_instance_valid(opp_glove_right_mesh):
			opp_glove_right_mesh.visible = not opp_card_nodes.is_empty()
		era_opp_glb.name = "EraOpponentGLB_" + resolved_era
		opp_silhouette_root.add_child(era_opp_glb)
		_apply_subtle_outline_next_pass(era_opp_glb, 0.0040)

		opp_torso_node = era_opp_glb.find_child("TorsoPivot", true, false) as Node3D
		opp_head_node = era_opp_glb.find_child("HeadPivot", true, false) as Node3D
		opp_arm_left_node = era_opp_glb.find_child("ArmLPivot", true, false) as Node3D
		opp_arm_right_node = era_opp_glb.find_child("ArmRPivot", true, false) as Node3D
		var eye_l := era_opp_glb.find_child("EyeL", true, false) as Node3D
		var eye_r := era_opp_glb.find_child("EyeR", true, false) as Node3D
		if is_instance_valid(eye_l):
			opp_eye_nodes.append(eye_l)
			boss_eye_left = eye_l
		if is_instance_valid(eye_r):
			opp_eye_nodes.append(eye_r)
			boss_eye_right = eye_r

		# Campaign Boss Regalia on HeadPivot (hide non-boss headgear first so there is zero clipping/z-fighting)
		if is_boss and is_instance_valid(opp_head_node):
			var head_reg_map := {
				"stredovek": "res://assets/models/boss_charles_iv.glb",
				"antika": "res://assets/models/boss_ramesses.glb",
				"rim": "res://assets/models/boss_caesar.glb",
				"objavy": "res://assets/models/boss_pirate_anne.glb",
				"prohibicia": "res://assets/models/boss_al_capone.glb",
			}
			if head_reg_map.has(resolved_era):
				var bh_glb := _load_glb_model(str(head_reg_map[resolved_era]), true)
				if bh_glb:
					_hide_non_boss_headgear_meshes(opp_head_node)
					bh_glb.name = "BossHeadRegaliaGLB"
					_apply_subtle_outline_next_pass(bh_glb, 0.0040)
					opp_head_node.add_child(bh_glb)
	else:
		# Graceful fallback if an era GLB is unavailable
		var fallback_mat := Toon.pbr(Color(0.22, 0.14, 0.14), "", 0.72, 0.08)
		opp_torso_node = Node3D.new()
		opp_torso_node.name = "TorsoPivot"
		opp_silhouette_root.add_child(opp_torso_node)
		_add_opp_mesh(opp_torso_node, _build_sculpted_torso_mesh(0.26, 0.195, 0.23, 0.155, 0.128, 0.56), Vector3.ZERO, fallback_mat)
		opp_head_node = Node3D.new()
		opp_head_node.name = "HeadPivot"
		opp_head_node.position = Vector3(0.0, 0.562, 0.01)
		opp_torso_node.add_child(opp_head_node)
		var skin_fb := Toon.pbr(Color(0.72, 0.54, 0.42), "", 0.56, 0.02)
		var sock_fb := Toon.pbr(Color(0.05, 0.04, 0.05), "", 0.90, 0.0)
		var eye_fb := Toon.pbr(rim_col, "", 0.10, 0.0, Vector2.ONE, rim_col, 2.4)
		var hair_fb := Toon.pbr(Color(0.14, 0.10, 0.08), "", 0.76, 0.04)
		_build_opponent_sculpted_head(opp_head_node, skin_fb, sock_fb, eye_fb, hair_fb, is_boss, e)
		opp_arm_left_node = Node3D.new()
		opp_arm_left_node.name = "ArmLPivot"
		opp_arm_left_node.position = Vector3(-0.26, 0.44, 0.02)
		opp_torso_node.add_child(opp_arm_left_node)
		opp_arm_right_node = Node3D.new()
		opp_arm_right_node.name = "ArmRPivot"
		opp_arm_right_node.position = Vector3(0.26, 0.44, 0.02)
		opp_torso_node.add_child(opp_arm_right_node)

	# 2. Spinning Boss Sigil Halo (radiates behind Elites & Campaign Bosses)
	boss_sigil_halo = MeshInstance3D.new()
	var s_tor := TorusMesh.new()
	s_tor.inner_radius = 0.32 if is_boss else 0.26
	s_tor.outer_radius = 0.348 if is_boss else 0.282
	s_tor.rings = 28
	s_tor.ring_segments = 8
	boss_sigil_halo.mesh = s_tor
	boss_sigil_halo.position = Vector3(0.0, 0.72, -0.22)
	boss_sigil_halo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	boss_sigil_halo.material_override = boss_eye_mat
	boss_sigil_halo.visible = (active_boss_mod != "" or tier >= 1)
	opp_silhouette_root.add_child(boss_sigil_halo)

	if is_instance_valid(cinematic_director):
		cinematic_director.call("set_opponent_rig", opp_silhouette_root)

func _get_prop_hover_info(prop_id: String) -> Array[String]:
	match prop_id:
		"discard":
			var top_c: Dictionary = discard_pile.back() if not discard_pile.is_empty() else {"suit": active_suit_id, "rank": "?"}
			var r_str := str(top_c.get("rank", "?"))
			var s_id := str(top_c.get("suit", active_suit_id))
			var s_obj: Dictionary = _get_suit_obj(s_id)
			var cls := str(top_c.get("card_class", "NORMAL"))
			return [
				_tr("Discard Pile • ", "Odkládací hromádka • ") + str(s_obj["sym"]) + " " + r_str + " (" + cls + ")",
				_tr("Match active Suit (%s) or Rank (%s). Hover cards [SPACE] to play.", "Dej kartu stejné barvy (%s) nebo hodnoty (%s). Karty zvedneš [SPACE].") % [str(s_obj["name"]), r_str]
			]
		"deck":
			if pending_skip:
				return [
					_tr("SKIP TURN (Frozen by Ace)", "PŘESKOČIT TAH (Zmrazen Esem)"),
					_tr("Click to pass your frozen turn.", "Klikni pro přeskočení zmrazeného tahu.")
				]
			return [
				_tr("Draw Deck (%d cards)", "Tahací balíček (%d karet)") % deck.size(),
				_tr("Click to draw 1 card (+draw stack if hit by a 7) and pass turn.", "Klikni pro líznutí 1 karty (nebo +2 za 7) a ukončení kola.")
			]
		"phial":
			var phial_desc := _tr("Click on your turn to douse the rival in fire: steals/burns points & boosts attack!", "Klikni ve svém tahu a polij soupeře ohněm: spaluje body a posílí útok!")
			if _can_change_opening_wager():
				phial_desc = _tr("CLICK BEFORE TURN 1: Stake Hellfire Phial Wager (+45g)! ", "KLIKNI PŘED 1. TAHEM: Vsadit baňku IGNIS (+45g)! ") + phial_desc
			return [
				_tr("Hellfire Phial IGNIS (%d charges)", "Baňka ohně IGNIS (%d nabití)") % puf_charges,
				phial_desc
			]
		"sword":
			var sw_info: Dictionary = Catalog.get_sword_skin(active_sword_skin_id) if Catalog else {}
			var sw_desc := str(sw_info.get("passive_desc", _tr("Strikes rival decisively at duel's end or shed finish.", "Rozetne soupeře při vítězství nebo shození poslední karty.")))
			if _can_change_opening_wager():
				sw_desc = _tr("CLICK BEFORE TURN 1: Stake Blood Oath Sword Wager (+100g)! ", "KLIKNI PŘED 1. TAHEM: Krvavá přísaha — vsadit meč (+100g)! ") + sw_desc
			return [
				_tr("Oath Blade: %s", "Čepel přísahy: %s") % str(sw_info.get("name", "Iron Oath")),
				sw_desc
			]
		"bell":
			var r_mod := current_round_num % 3
			var is_ready := (r_mod == 0)
			var rem := 0 if is_ready else (3 - r_mod)
			var next_shop_r := ((current_round_num - 1) / 3 + 1) * 3
			if is_ready:
				return [
					_tr("Peddler's Brass Bell — Shop after R%d!" % current_round_num, "Kupcův zvonec — Obchod po %d. kole!" % current_round_num),
					_tr("Finish Round %d to summon the Cloaked Peddler and buy items & upgrades!" % current_round_num, "Dohraj %d. kolo pro otevření Obchodu se zbožím a vylepšeními!" % current_round_num)
				]
			return [
				_tr("Peddler's Brass Bell (%d rounds to Shop)" % rem, "Kupcův zvonec (obchod po %d. kole)" % next_shop_r),
				_tr("Rings open the illustrated Crossroads Shop at the end of Round 3 & Round 6.", "Otevírá ilustrovaný Obchod na konci 3. a 6. kola.")
			]
		"coins":
			var coins_desc := _tr("Spent in the Crossroads Shop. Merchant cards forge bonus Florins on play.", "Platidlo do Obchodu. Kupecké karty při zahrání přidají bonusové zlato.")
			if _can_change_opening_wager():
				coins_desc = _tr("CLICK BEFORE TURN 1: Stake %dg Gold Wager! " % wager_gold_amount, "KLIKNI PŘED 1. TAHEM: Vsadit %dg zlata! " % wager_gold_amount) + coins_desc
			return [
				_tr("Florin Purse: %d Gold", "Měšec florinů: %d zlata") % player_available_gold,
				coins_desc
			]
		"dice":
			return [
				_tr("Bone Fortune Dice", "Kostené kostky štěstěny"),
				_tr("Click to roll the bone dice across the felt for luck & atmosphere!", "Klikni pro hození kostek po plátně pro štěstí!")
			]
		"mug":
			return [
				_tr("Spiced Mead Tankard", "Korbel kořeněné medoviny"),
				_tr("Click to clink tankards and steady your nerve before a Knight bluff.", "Klikni pro cinknutí korbelem před dalším tahem.")
			]
		"plaque":
			return [
				_tr("Rival Crest & Oath Rule", "Erb soupeře a pravidlo"),
				_tr("Shows enemy era, active boss plague modifier & special vulnerability.", "Ukazuje epochu nepřítele a aktivní speciální pravidlo.")
			]
		"opp_phial":
			return [
				_tr("Rival Ember Vial", "Soupeřova baňka žáru"),
				_tr("The rival's volatile ember phial on the far side of the table.", "Soupeřova nestabilní baňka žáru na opačné straně stolu.")
			]
		"opp_relic":
			return [
				_tr("Rival Table Sigil", "Soupeřova pečeť na stole"),
				_tr("The rival's royal sigil totem. Right-click to inspect in 3D.", "Soupeřův královský totem. Pravým tlačítkem prohlédneš ve 3D.")
			]
	if prop_id.begins_with("trelic:"):
		var tid := prop_id.substr(7)
		var tr_l := Catalog.get_table_relic_loc(tid, opts_language)
		var t_title := _tr("TABLE RELIC: ", "RELIKVIE NA STŮL: ") + str(tr_l.get("name", tid))
		var t_body := str(tr_l.get("desc", ""))
		var t_rem := relic_mgr.get_remaining(tid)
		if relic_mgr.is_broken(tid) or t_rem <= 0:
			t_body += _tr("  [Shattered (0/3) — passive disabled until Shop repair]", "  [Rozbito (0/3) — pasivní efekt vypnut do opravy v Obchodě]")
		else:
			t_body += _tr("  [Click on Table: %d/%d uses]" % [t_rem, MAX_TABLE_ITEM_USES], "  [Klikni na stole: %d/%d použití]" % [t_rem, MAX_TABLE_ITEM_USES])
			if relic_mgr.is_overcharge(tid):
				t_body += _tr("  [Next use this turn: OVERCHARGE (-2 dur)]", "  [Další použití v tahu: PŘETÍŽENÍ (-2 výdrž)]")
		return [t_title, t_body]
	if prop_id.begins_with("relic:"):
		var rel_id := prop_id.substr(6)
		var rl := Catalog.get_relic_loc(rel_id, opts_language)
		var title_s := _tr("✦ RELIC: ", "✦ RELIKVIE: ") + str(rl.get("name", rel_id))
		var body_s := str(rl.get("desc", ""))
		if rel_id == "REL_SEVEN_GRIMOIRE":
			var sc7 := 1.0 + float(match_relic_scales.get("REL_SEVEN_GRIMOIRE", 0.0))
			body_s += _tr(" (Current: ×%.2f)" % sc7, " (Aktuálně: ×%.2f)" % sc7)
		elif rel_id == "REL_MERCHANT_LEDGER":
			var scm := maxi(ScoreEng.MERCHANT_LEDGER_CHIP_STEP, int(match_relic_scales.get("REL_MERCHANT_LEDGER", run_shop_rerolls * ScoreEng.MERCHANT_LEDGER_CHIP_STEP)) + ScoreEng.MERCHANT_LEDGER_CHIP_STEP)
			body_s += _tr(" (Current: +%d)" % scm, " (Aktuálně: +%d)" % scm)
		var r_rem := relic_mgr.get_remaining(rel_id)
		if relic_mgr.is_broken(rel_id) or r_rem <= 0:
			body_s += _tr("  [Shattered (0/3) — passive disabled until Shop repair]", "  [Rozbito (0/3) — pasivní efekt vypnut do opravy v Obchodě]")
		else:
			body_s += _tr("  [Click on Table: %d/%d uses]" % [r_rem, MAX_TABLE_ITEM_USES], "  [Klikni na stole: %d/%d použití]" % [r_rem, MAX_TABLE_ITEM_USES])
			if relic_mgr.is_overcharge(rel_id):
				body_s += _tr("  [Next use this turn: OVERCHARGE (-2 dur)]", "  [Další použití v tahu: PŘETÍŽENÍ (-2 výdrž)]")
		return [title_s, body_s]
	for p_item_n in purchased_table_item_nodes:
		var pn_node := p_item_n as Node3D
		if is_instance_valid(pn_node) and str(pn_node.get_meta("prop_id", "")) == prop_id:
			var item_desc := str(pn_node.get_meta("hover_desc", ""))
			var p_rem := relic_mgr.get_remaining(prop_id)
			if relic_mgr.is_broken(prop_id) or p_rem <= 0:
				item_desc += _tr("  [Shattered (0/3) — passive disabled until Shop repair]", "  [Rozbito (0/3) — pasivní efekt vypnut do opravy v Obchodě]")
			else:
				item_desc += _tr("  [Click on Table: %d/%d uses]" % [p_rem, MAX_TABLE_ITEM_USES], "  [Klikni na stole: %d/%d použití]" % [p_rem, MAX_TABLE_ITEM_USES])
				if relic_mgr.is_overcharge(prop_id):
					item_desc += _tr("  [Next use this turn: OVERCHARGE (-2 dur)]", "  [Další použití v tahu: PŘETÍŽENÍ (-2 výdrž)]")
			return [
				str(pn_node.get_meta("hover_title", "Table Artifact")),
				item_desc
			]
	return ["", ""]

func _get_hand_card_area_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for cn in player_card_nodes:
		if not is_instance_valid(cn):
			continue
		for ch in cn.get_children():
			if ch is Area3D:
				rids.append((ch as Area3D).get_rid())
	return rids

func _update_prop_hover_and_edge_peek(delta: float, mouse_pos: Vector2, _vp_size: Vector2) -> void:
	# 1. Cards NEVER peek or disappear on mouse hover — only [TAB]/[SPACE] toggles CameraViewMode!
	auto_edge_peek = false

	# 2. Additional raycast check for ALL 3D Table Props (including Discard, Sword, Bell, and Purchased Shop Items)
	var next_prop := ""
	if not _is_cinematic_playing() and cam_view_mode != CameraViewMode.CINEMATIC and not peddler_open and not shop_gate_open and is_instance_valid(cam) and (hovered_card_idx < 0 or _is_hand_tucked()):
		var from := cam.project_ray_origin(mouse_pos)
		var dir := cam.project_ray_normal(mouse_pos)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 12.0)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		if _is_hand_tucked():
			q.exclude = _get_hand_card_area_rids()
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var col_obj: Object = hit.get("collider")
			if col_obj:
				if col_obj.has_meta("prop_id"):
					next_prop = str(col_obj.get_meta("prop_id"))
				else:
					match str(col_obj.name):
						"DiscardPileArea": next_prop = "discard"
						"DrawDeckArea": next_prop = "deck"
						"MagicPufArea": next_prop = "phial"
						"SwordArea": next_prop = "sword"
						"TavernBellArea": next_prop = "bell"
						"TavernCoinsArea": next_prop = "coins"
						"TavernDiceArea": next_prop = "dice"
						"TavernMugArea": next_prop = "mug"
						"BossPlaqueArea": next_prop = "plaque"
	if hovered_draw_deck and next_prop == "sword":
		next_prop = "deck"
	hovered_prop_id = next_prop

	# 3. Physically lift hovered 3D table prop (+0.075m) & highlight scale
	var prop_nodes: Array = [draw_deck_root, discard_pile_root, magic_puf_bottle, player_sword_root, tavern_bell_root, tavern_coins_root, tavern_dice_root, tavern_mug_root, opp_phial_node, opp_relic_node]
	for r_extra in relic_3d_nodes.values():
		if is_instance_valid(r_extra):
			prop_nodes.append(r_extra)
	for p_extra in purchased_table_item_nodes:
		if is_instance_valid(p_extra):
			prop_nodes.append(p_extra)
	for p_item in prop_nodes:
		var pn: Node3D = p_item as Node3D
		if not is_instance_valid(pn) or not pn.visible or not pn.has_meta("base_pos"):
			continue
		var bp: Vector3 = pn.get_meta("base_pos")
		var bs: Vector3 = pn.get_meta("base_scale", Vector3.ONE)
		var pid: String = str(pn.get_meta("prop_id", ""))
		var is_hov: bool = (pid != "" and pid == hovered_prop_id)
		var is_relic_prop := pid.begins_with("relic:") or pid.begins_with("trelic:")
		var target_y := bp.y + ((0.088 if is_relic_prop else 0.075) if is_hov else 0.0)
		var target_sc := bs * ((1.18 if is_relic_prop else 1.14) if is_hov else 1.0)
		pn.position.y = lerpf(pn.position.y, target_y, 12.0 * delta)
		pn.scale = pn.scale.lerp(target_sc, 12.0 * delta)
		var rtag := pn.get_node_or_null("RelicHoverTag") as Label3D
		if rtag:
			rtag.visible = is_hov
		if is_relic_prop:
			var r_halo := pn.get_node_or_null("RelicModel3D/ReadyHalo") as MeshInstance3D
			if r_halo and r_halo.material_override is StandardMaterial3D:
				var hm := r_halo.material_override as StandardMaterial3D
				hm.emission_energy_multiplier = 2.6 if is_hov else 1.15

	# 4. Update Floating Prop Hover Pill
	if prop_hover_pill and prop_hover_title and prop_hover_desc:
		var tut_vis := tutorial_ghost_center_panel and tutorial_ghost_center_panel.visible
		if hovered_prop_id != "" and not peddler_open and hovered_card_idx < 0 and not tut_vis and (not tutorial_mode or tutorial_step >= 1):
			var info: Array[String] = _get_prop_hover_info(hovered_prop_id)
			if info[0] != "":
				prop_hover_title.text = info[0]
				prop_hover_desc.text = info[1]
				var top_y := 396 if (unlock_tip_panel and unlock_tip_panel.visible) else 252
				prop_hover_pill.offset_top = top_y
				prop_hover_pill.offset_bottom = top_y + 76
				prop_hover_pill.visible = true
			else:
				prop_hover_pill.visible = false
		else:
			prop_hover_pill.visible = false

	# 5. Live Articulated Opponent Animation (breathing, blinks, arm slam) — paused while CinematicDirector owns the rig!
	if not _is_cinematic_playing():
		if opp_play_anim_t > 0.0:
			opp_play_anim_t = maxf(0.0, opp_play_anim_t - delta * 2.2)
		var t_sec := float(Time.get_ticks_msec()) * 0.001
		opp_blink_timer -= delta
		var blink_scale := 1.0
		if opp_blink_timer <= 0.0:
			if opp_blink_timer < -0.14:
				opp_blink_timer = randf_range(2.2, 4.6)
			else:
				blink_scale = 0.14
		for eo in opp_eye_nodes:
			if is_instance_valid(eo):
				eo.scale.y = lerpf(eo.scale.y, blink_scale, 24.0 * delta)
		if is_instance_valid(opp_torso_node):
			opp_torso_node.position.y = sin(t_sec * 1.9) * 0.014
			opp_torso_node.rotation_degrees.x = opp_play_anim_t * 14.0 + sin(t_sec * 1.1) * 1.8
		if is_instance_valid(opp_head_node):
			opp_head_node.rotation_degrees.y = sin(t_sec * 0.85) * 6.5
			opp_head_node.rotation_degrees.x = 4.0 + opp_play_anim_t * 12.0 + sin(t_sec * 1.9) * 2.0
		if is_instance_valid(opp_arm_left_node):
			opp_arm_left_node.rotation_degrees.x = -46.0 + sin(t_sec * 1.9) * 2.0
			opp_arm_left_node.rotation_degrees.y = 34.0
			opp_arm_left_node.rotation_degrees.z = 26.0
		if is_instance_valid(opp_arm_right_node):
			opp_arm_right_node.position.z = 0.02 + opp_play_anim_t * 0.22
			opp_arm_right_node.rotation_degrees.x = -46.0 + opp_play_anim_t * 32.0
			opp_arm_right_node.rotation_degrees.y = -34.0
			opp_arm_right_node.rotation_degrees.z = -26.0

func _trigger_ghost_ok_flash() -> void:
	tutorial_ghost_ok_flash = 1.0
	emit_signal("play_sfx_pitched_requested", "turn_player", 1.32)
	if is_instance_valid(tutorial_ghost_3d):
		Fx.burst(self, tutorial_ghost_3d.global_position + Vector3(0.0, 0.56, 0.14), Color(0.36, 1.0, 0.62), 20, 0.95, 0.55, 0.032, 0.4, true, 160.0)
		Fx.float_number(self, tutorial_ghost_3d.global_position + Vector3(0.0, 0.78, 0.12), "OK!", Color(0.42, 1.0, 0.66), 72, 0.24, 0.85, 1.55)

func _get_tutorial_ghost_copy(step: int, sub: int = 0) -> Dictionary:
	match step:
		0:
			return {
				"en": "Hey! Welcome to LIALO — high-stakes tavern card duels of wit and blade. I'm Spirko, the tavern ghost, and I'll teach you every trick!",
				"cs": "Čau! Vítej v LIALU — krčmových karetních soubojích na život a na smrt. Jsem Spirko, duch této krčmy, a naučím tě všechny triky!",
				"task_en": "", "task_cs": "",
				"btn_en": "Start Learning [SPACE] ▸", "btn_cs": "Jdeme na to [SPACE] ▸",
				"show_btn": true,
			}
		1:
			if sub == 0:
				return {
					"en": "Before Turn 1, you can Veto a bad opening hand once or decline the duel.",
					"cs": "Před 1. tahem můžeš 1× vyměnit špatnou ruku (Veto) nebo duel odmítnout.",
					"task_en": "TASK: Press [V] (or click Veto Hand) to deal 5 fresh cards!",
					"task_cs": "ÚKOL: Stiskni [V] (nebo klikni na Vetovat karty) pro novou ruku!",
					"btn_en": "Next", "btn_cs": "Dál",
					"show_btn": false,
				}
			elif sub == 1:
				return {
					"en": "OK! Press [TAB] or [SPACE] anytime to switch between Cards and 3D Table Items.",
					"cs": "OK! Klávesou [TAB] nebo [SPACE] kdykoliv přepneš mezi Kartami a 3D Stolem.",
					"task_en": "TASK: Toggle to 3D Table [TAB] and click your 3D SWORD to stake it!",
					"task_cs": "ÚKOL: Přepni na 3D Stůl [TAB] a klikni na svůj 3D MEČ pro sázku!",
					"btn_en": "Next", "btn_cs": "Dál",
					"show_btn": false,
				}
			else:
				return {
					"en": "OK! Blood Oath Sword staked (+100g on victory)!",
					"cs": "OK! Krvavá přísaha meče je vsazena (+100g při výhře)!",
					"task_en": "TASK: Press [TAB] or [SPACE] again to return to your 3D cards!",
					"task_cs": "ÚKOL: Stiskni znovu [TAB] nebo [SPACE] a vrať se ke svým kartám!",
					"btn_en": "Next", "btn_cs": "Dál",
					"show_btn": false,
				}
		2:
			return {
				"en": "Match the active Suit (♥/●/♠/♣) or Rank. Turn points settle together into the Chalice.",
				"cs": "Základ Prší: hoď stejnou Barvu (♥/●/♠/♣) nebo Hodnotu. Body tahu se slijí do Kalicha.",
				"task_en": "TASK: Play your glowing ♥ Ten from hand (click or press [W])!",
				"task_cs": "ÚKOL: Zahraj svítící ♥ Desítku z ruky (klikem nebo klávesou [W])!",
				"btn_en": "Next", "btn_cs": "Dál",
				"show_btn": false,
			}
		3:
			return {
				"en": "OK! Seven (7) forces +2 draw & 3× POINTS (21 pts)! Queen (H) shifts Suit.",
				"cs": "OK! Sedmička (7) dává +2 karty a 3× BODY (21 b.)! Svršek (H) mění Barvu.",
				"task_en": "TASK: Play your glowing ♥ Seven (7) now!",
				"task_cs": "ÚKOL: Zahraj teď svou svítící ♥ Sedmičku (7)!",
				"btn_en": "Next", "btn_cs": "Dál",
				"show_btn": false,
			}
		4:
			return {
				"en": "OK! Only Eights (8 ∞) or up to 3 Aces can be chained into a Combo!",
				"cs": "OK! Řetězit do komba lze jen Osmičky (8 ∞) nebo max. 3 Esa najednou!",
				"task_en": "TASK: Right-click [RMB] both Eights (8) and slam a 2× Combo [W]!",
				"task_cs": "ÚKOL: Označ pravým klikem [RMB] obě Osmičky (8) a odpal 2× Kombo [W]!",
				"btn_en": "Next", "btn_cs": "Dál",
				"show_btn": false,
			}
		5:
			return {
				"en": "OK! 3D Hearts (10 ♥ HP): King hits 1–3 HP; 1/2 Aces deal 1/4 HP + Stun; 3× Aces = INSTANT KILL (chosen target in MP)!",
				"cs": "OK! 3D Srdce (10 ♥ HP): Král bere 1–3 HP; 1/2 Esa berou 1/4 HP + Stopku; 3× Eso = OKAMŽITÁ SMRT (v MP zvolený cíl)!",
				"task_en": "TASK: Stack both Aces (E) into a combo to strike Rival's heart for -4 ♥ HP!",
				"task_cs": "ÚKOL: Spoj obě Esa (E) do komba — zasáhneš soupeřovo srdce za -4 ♥ HP!",
				"btn_en": "Next", "btn_cs": "Dál",
				"show_btn": false,
			}
		6:
			if sub == 0:
				return {
					"en": "OK! Rival's heart is racing! Unleash a Special Card cutscene.",
					"cs": "OK! Soupeřovo srdce zběsile buší! Povolej Mocnou kartu s cutscénou.",
					"task_en": "TASK: Play your special card Vampire Leech (SPEC_VAMPIRE)!",
					"task_cs": "ÚKOL: Zahraj speciální kartu Upíří pijavice (SPEC_VAMPIRE)!",
					"btn_en": "Next", "btn_cs": "Dál",
					"show_btn": false,
				}
			else:
				return {
					"en": "OK! Your 3D Hellfire Phial IGNIS glows on the right (costs 20 pts).",
					"cs": "OK! Na stole vpravo plane 3D Baňka pekelného ohně IGNIS (stojí 20 b.).",
					"task_en": "TASK: Click the 3D Hellfire Phial IGNIS (or via [TAB]) to burn Rival!",
					"task_cs": "ÚKOL: Klikni na 3D Ohnivou baňku IGNIS (nebo přes [TAB]) a zapal soupeře!",
					"btn_en": "Next", "btn_cs": "Dál",
					"show_btn": false,
				}
		7:
			return {
				"en": "OK! 3 ways to win: 0 ♥ HP, Chalice Score Goal (e.g. 520), or 3× Aces = Instant Kill! New round starts whenever ANY player reaches 0 cards. Shop opens every 3rd round.",
				"cs": "OK! 3 cesty k výhře: 0 ♥ HP, Cíl Kalicha (např. 520) nebo 3× Eso = Okamžitá smrt! Nové kolo začíná, jakmile komukoli dojdou karty! Obchod je každé 3. kolo.",
				"task_en": "FINAL TASK: Play your last card (0 in hand = Round Won! +bonus & next round)!",
				"task_cs": "POSLEDNÍ ÚKOL: Vyhoď poslední kartu (0 karet = Kolo vyhráno! +bonus a nové kolo)!",
				"btn_en": "Finish", "btn_cs": "Dokončit",
				"show_btn": false,
			}
		_:
			return {
				"en": "OK! 0 cards — Round Won! (+bonus & next round) — you master all of LIALO! (Replay anytime from Options.)",
				"cs": "OK! 0 karet — Kolo vyhráno! (+bonus a nové kolo) — ovládáš celé LIALO! (Tutoriál můžeš kdykoliv zopakovat v Nastavení.)",
				"task_en": "", "task_cs": "",
				"btn_en": "Play Now! ▸", "btn_cs": "Hrát naplno! ▸",
				"show_btn": true,
			}

func _advance_tutorial_substep() -> void:
	if not tutorial_mode:
		return
	if tutorial_step == 0:
		tutorial_substep = 0
		_advance_tutorial_to(1)
	elif tutorial_step >= 8:
		_skip_tutorial_immediately()

func _layout_tutorial_ghost_center_panel(float_y: float = 0.0) -> void:
	if not is_instance_valid(tutorial_ghost_center_panel) or not tutorial_ghost_center_panel.visible:
		return
	var is_centered_card := (tutorial_step == 0 or tutorial_step >= 8)
	var vp_w: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1366.0
	var left_edge := (player_hud_grp.global_position.x + player_hud_grp.size.x) if (player_hud_grp and player_hud_grp.visible and player_hud_grp.size.x > 0.0) else 492.0
	var right_edge := rival_hud_grp.global_position.x if (rival_hud_grp and rival_hud_grp.visible and rival_hud_grp.global_position.x > left_edge + 120.0) else (vp_w - 368.0)
	var gap := right_edge - left_edge
	var min_gw := 410.0 if gap >= 434.0 else maxf(280.0, gap - 20.0)
	var gw := 620.0 if is_centered_card else clampf(gap - 24.0, min_gw, 540.0)
	tutorial_ghost_center_panel.custom_minimum_size = Vector2(gw, 0)
	if tutorial_ghost_center_lbl:
		tutorial_ghost_center_lbl.custom_minimum_size = Vector2(gw - 56.0, 0)
	if tutorial_task_lbl:
		tutorial_task_lbl.custom_minimum_size = Vector2(gw - 88.0, 0)
	if is_instance_valid(tutorial_ghost_quill) and tutorial_ghost_quill.has_method("set_wrap_width"):
		tutorial_ghost_quill.call("set_wrap_width", gw - 56.0)
	if is_instance_valid(tutorial_ghost_quill) and tutorial_ghost_quill.has_method("get_preferred_height"):
		var qh := float(tutorial_ghost_quill.call("get_preferred_height", gw - 56.0))
		tutorial_ghost_quill.custom_minimum_size = Vector2(gw - 56.0, maxf(32.0, qh))
	if is_centered_card:
		tutorial_ghost_center_panel.anchor_left = 0.5
		tutorial_ghost_center_panel.anchor_right = 0.5
		tutorial_ghost_center_panel.anchor_top = 1.0
		tutorial_ghost_center_panel.anchor_bottom = 1.0
		tutorial_ghost_center_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		tutorial_ghost_center_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		tutorial_ghost_center_panel.offset_left = -310.0
		tutorial_ghost_center_panel.offset_right = 310.0
	else:
		var mid_x := (left_edge + right_edge) * 0.5
		tutorial_ghost_center_panel.anchor_left = 0.0
		tutorial_ghost_center_panel.anchor_right = 0.0
		tutorial_ghost_center_panel.anchor_top = 0.0
		tutorial_ghost_center_panel.anchor_bottom = 0.0
		tutorial_ghost_center_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		tutorial_ghost_center_panel.grow_vertical = Control.GROW_DIRECTION_END
		tutorial_ghost_center_panel.offset_left = mid_x - gw * 0.5
		tutorial_ghost_center_panel.offset_right = mid_x + gw * 0.5
	tutorial_ghost_center_panel.size = Vector2(gw, 0)
	tutorial_ghost_center_panel.reset_size()
	var gh := maxf(68.0, tutorial_ghost_center_panel.get_combined_minimum_size().y)
	if is_centered_card:
		tutorial_ghost_center_panel.offset_bottom = -36.0 + float_y
		tutorial_ghost_center_panel.offset_top = -36.0 - gh + float_y
	else:
		var mid_x2 := (left_edge + right_edge) * 0.5
		tutorial_ghost_center_panel.offset_left = mid_x2 - gw * 0.5
		tutorial_ghost_center_panel.offset_right = mid_x2 + gw * 0.5
		tutorial_ghost_center_panel.offset_top = 14.0 + float_y
		tutorial_ghost_center_panel.offset_bottom = 14.0 + gh + float_y

func _apply_staged_tutorial_state(step: int, animate_magic: bool = true) -> void:
	if hud_shop_btn:
		hud_shop_btn.visible = false
	if dock_backdrop_panel:
		dock_backdrop_panel.visible = false
	if wager_bar_panel:
		wager_bar_panel.visible = false
	if veto_standalone_panel:
		var show_veto_real := (not tutorial_mode) and (not opening_turn_committed) and current_round_num == 1 and (not intro_animating) and (not peddler_open) and (not shop_gate_open) and (not _is_cinematic_playing())
		var show_veto_tut := tutorial_mode and (step == 1 and tutorial_substep == 0) and (not intro_animating)
		veto_standalone_panel.visible = show_veto_real or show_veto_tut
		if show_veto_tut:
			if wager_veto_hand_btn:
				wager_veto_hand_btn.disabled = false
				wager_veto_hand_btn.text = _tr("Veto Hand [V]", "Vetovat karty [V]")
			if wager_veto_duel_btn:
				wager_veto_duel_btn.disabled = false
				wager_veto_duel_btn.text = _tr("Veto Game", "Vetovat hru")
	_refresh_wager_indicator_ui()
	if player_puf_lbl:
		player_puf_lbl.visible = false
	if not tutorial_mode and step >= 8:
		if is_instance_valid(player_hand_anchor): player_hand_anchor.visible = true
		if is_instance_valid(player_body_root): player_body_root.visible = true
		if is_instance_valid(opp_silhouette_root): opp_silhouette_root.visible = true
		if is_instance_valid(opp_hands_anchor): opp_hands_anchor.visible = true
		if is_instance_valid(draw_deck_root): draw_deck_root.visible = true
		if is_instance_valid(discard_pile_root): discard_pile_root.visible = true
		if is_instance_valid(tavern_bell_root): tavern_bell_root.visible = true
		if is_instance_valid(magic_puf_bottle): magic_puf_bottle.visible = true
		if player_hud_grp: player_hud_grp.visible = true
		if player_hp_pill: player_hp_pill.visible = false
		if is_instance_valid(player_hp_heart): player_hp_heart.visible = not _is_cinematic_playing()
		if carry_out_pill: carry_out_pill.visible = false
		if combo_hud_grp: combo_hud_grp.visible = true
		if rival_hud_grp: rival_hud_grp.visible = true
		if is_instance_valid(rival_hp_heart): rival_hp_heart.visible = not _is_cinematic_playing()
		if round_counter_lbl: round_counter_lbl.visible = true
		if settings_icon_btn: settings_icon_btn.visible = true
		if card_guide_btn: card_guide_btn.visible = true
		if is_instance_valid(view_toggle_btn): view_toggle_btn.visible = true
		if bottom_left_status_pill: bottom_left_status_pill.visible = true
		_sync_contextual_cancel_btn()
		if tutorial_ghost_center_panel: tutorial_ghost_center_panel.visible = false
		if tutorial_arrow_overlay: tutorial_arrow_overlay.visible = false
		return

	# Progressive visibility aligned with 8-Step Tutorial (0..7, 8=Complete)
	var show_table := (step >= 1)
	var show_hand := (step >= 1)
	var show_scores := (step >= 2)
	var show_combo := (step >= 4)
	var show_hearts := (step >= 5)
	var show_phial := (step >= 6)
	var show_bell := (step >= 7)

	if is_instance_valid(draw_deck_root): draw_deck_root.visible = show_table
	if is_instance_valid(discard_pile_root): discard_pile_root.visible = show_table
	if is_instance_valid(player_hand_anchor): player_hand_anchor.visible = show_hand
	if is_instance_valid(player_body_root): player_body_root.visible = show_hand
	if is_instance_valid(opp_silhouette_root): opp_silhouette_root.visible = show_table
	if is_instance_valid(opp_hands_anchor): opp_hands_anchor.visible = show_table
	if is_instance_valid(boss_plaque_root): boss_plaque_root.visible = show_phial
	if is_instance_valid(magic_puf_bottle): magic_puf_bottle.visible = show_phial
	if is_instance_valid(tavern_bell_root): tavern_bell_root.visible = show_bell

	if player_hud_grp: player_hud_grp.visible = show_scores
	if player_hp_pill: player_hp_pill.visible = false
	if is_instance_valid(player_hp_heart): player_hp_heart.visible = show_hearts and (not _is_cinematic_playing())
	if carry_out_pill: carry_out_pill.visible = false
	if combo_hud_grp: combo_hud_grp.visible = show_combo
	if rival_hud_grp: rival_hud_grp.visible = show_scores
	if is_instance_valid(rival_hp_heart): rival_hp_heart.visible = show_hearts and (not _is_cinematic_playing())
	if settings_icon_btn: settings_icon_btn.visible = show_hand
	if card_guide_btn: card_guide_btn.visible = show_hand
	if is_instance_valid(view_toggle_btn): view_toggle_btn.visible = show_hand and (not _is_cinematic_playing())
	if bottom_left_status_pill: bottom_left_status_pill.visible = show_hand
	_sync_contextual_cancel_btn()
	if tutorial_arrow_overlay:
		tutorial_arrow_overlay.visible = tutorial_mode and (step >= 1 and step <= 7)

	if tutorial_callout_grp:
		tutorial_callout_grp.visible = false
	if turn_banner_grp and step < 1:
		turn_banner_grp.visible = false
		_last_turn_toast_key = ""
	if tutorial_ghost_center_panel and tutorial_ghost_center_lbl:
		var cp := _get_tutorial_ghost_copy(step, tutorial_substep)
		var full_txt := _tr(str(cp["en"]), str(cp["cs"]))
		var task_txt := _tr(str(cp.get("task_en", "")), str(cp.get("task_cs", "")))
		tutorial_ghost_center_panel.visible = true
		tutorial_ghost_center_panel.pivot_offset = tutorial_ghost_center_panel.size * 0.5
		tutorial_ghost_center_panel.scale = Vector2.ONE
		var is_centered_card := (step == 0 or step >= 8)
		var vp_w: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1366.0
		var gw := 620.0 if is_centered_card else clampf((vp_w - 368.0 - 492.0) - 24.0, 410.0, 540.0)
		tutorial_ghost_center_panel.custom_minimum_size = Vector2(gw, 0)
		tutorial_ghost_center_lbl.custom_minimum_size = Vector2(gw - 48.0, 0)
		if tutorial_step_badge_lbl:
			if step == 0:
				tutorial_step_badge_lbl.text = _tr("✦ INTRO", "✦ ÚVOD")
			elif step >= 8:
				tutorial_step_badge_lbl.text = _tr("★ COMPLETE", "★ DOKONČENO")
			else:
				tutorial_step_badge_lbl.text = _tr("✦ STEP %d / 7" % step, "✦ KROK %d / 7" % step)
		if tutorial_task_pill and tutorial_task_lbl:
			tutorial_task_pill.visible = (task_txt != "")
			tutorial_task_lbl.text = task_txt
			tutorial_task_lbl.custom_minimum_size = Vector2(gw - 72.0, 0)
		if is_instance_valid(tutorial_ghost_quill) and tutorial_ghost_quill.has_method("set_wrap_width"):
			tutorial_ghost_quill.call("set_wrap_width", gw - 48.0)
		if animate_magic or tutorial_ghost_center_lbl.text != full_txt:
			_start_handwriting_anim(tutorial_ghost_center_lbl, full_txt, 46.0, animate_magic)
		if tutorial_continue_btn:
			tutorial_continue_btn.visible = bool(cp.get("show_btn", false))
			tutorial_continue_btn.text = _tr(str(cp["btn_en"]), str(cp["btn_cs"]))
		_layout_tutorial_ghost_center_panel(0.0)

	if animate_magic:
		if step == 1 and is_instance_valid(discard_pile_root):
			discard_pile_root.scale = Vector3(0.12, 0.12, 0.12)
			Fx.ring(self, discard_pile_root.global_position + Vector3(0.0, 0.04, 0.0), Color(0.95, 0.78, 0.36), 0.45, 0.45, 0.06, 1.8, 6.0)
		elif step == 2 and player_hud_grp:
			player_hud_grp.pivot_offset = player_hud_grp.size * 0.5
			player_hud_grp.scale = Vector2(0.18, 0.18)
			var wtw := player_hud_grp.create_tween()
			wtw.tween_property(player_hud_grp, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif step == 4 and combo_hud_grp:
			combo_hud_grp.pivot_offset = combo_hud_grp.size * 0.5
			combo_hud_grp.scale = Vector2(0.18, 0.18)
			var ctw := combo_hud_grp.create_tween()
			ctw.tween_property(combo_hud_grp, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif step == 7 and is_instance_valid(tavern_bell_root):
			Fx.ring(self, tavern_bell_root.position + Vector3(0.0, 0.05, 0.0), Color(1.0, 0.84, 0.32), 0.32, 0.45, 0.05, 1.8, 4.0)

func _setup_minimal_overlay_hud() -> void:
	# Layer 3: Full-Screen Living Woodcut / Etching Print Shader (strictly above 3D world, strictly below HUD layer 5!)
	woodcut_layer = CanvasLayer.new()
	woodcut_layer.layer = 3
	woodcut_layer.visible = false
	add_child(woodcut_layer)

	woodcut_post_rect = ColorRect.new()
	woodcut_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	woodcut_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	woodcut_post_rect.color = Color(1, 1, 1, 1)
	woodcut_post_mat = ShaderMaterial.new()
	woodcut_post_mat.shader = WOODCUT_POST_SHADER
	woodcut_post_mat.set_shader_parameter("print_mode", woodcut_print_mode)
	woodcut_post_rect.material = woodcut_post_mat
	woodcut_layer.add_child(woodcut_post_rect)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_root.visible = false
	hud_layer.add_child(hud_root)

	screen_juice_rect = ColorRect.new()
	screen_juice_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_juice_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_juice_rect.color = Color(1, 1, 1, 1)
	screen_juice_mat = ShaderMaterial.new()
	screen_juice_mat.shader = SCREEN_JUICE_SHADER
	screen_juice_mat.set_shader_parameter("shock_strength", 0.0)
	screen_juice_mat.set_shader_parameter("ring_progress", 0.0)
	screen_juice_mat.set_shader_parameter("godrays_strength", 0.0)
	screen_juice_mat.set_shader_parameter("flash_color", Color(0.45, 0.88, 1.0, 1.0))
	screen_juice_rect.material = screen_juice_mat
	hud_root.add_child(screen_juice_rect)

	# Preload 5-stage evolving Charge Chalice artwork (Stage I Empty -> Stage V Overcharged Solar Gold)
	charge_tier_textures.clear()
	for ti in range(5):
		var ctp := "res://assets/ui/charge_tier_%d.png" % ti
		charge_tier_textures.append(Toon.tex(ctp))

	# ZONE 1 LEFT TOP: Permanent Score Board + Evolving Charge Vessel + Fixed Turn-Pair Equation Ledger (x: 14..488, y: 10..178)
	player_hud_grp = Control.new()
	player_hud_grp.position = Vector2(14, 10)
	player_hud_grp.size = Vector2(474, 168)
	player_hud_grp.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_root.add_child(player_hud_grp)

	var sb_bg_3d := TextureRect.new()
	sb_bg_3d.name = "ScoreBoardBg3D"
	sb_bg_3d.set_anchors_preset(Control.PRESET_FULL_RECT)
	sb_bg_3d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sb_bg_3d.stretch_mode = TextureRect.STRETCH_SCALE
	sb_bg_3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb_bg_3d.texture = _load_blender_ui_tex("ui_score_board_3d.png")
	player_hud_grp.add_child(sb_bg_3d)

	player_liquid_bar = Control.new()
	player_liquid_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	player_liquid_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_liquid_bar.draw.connect(func():
		var t_ms := float(Time.get_ticks_msec()) * 0.001
		var sc_val := maxf(0.0, display_player_score) if hud_score_revealed else 0.0
		var pend_val := float(pending_player_exchange_pts) if hud_score_revealed else 0.0
		var denom := float(maxi(1, target_score))
		var goal_pct := clampf(sc_val / denom, 0.0, 1.0)
		var pend_pct := clampf((sc_val + pend_val) / denom, 0.0, 1.0)
		var cur_c := _get_chalice_fire_tint(chalice_flame_progress)
		var glow_strength := clampf(chalice_flame_progress, 0.0, 1.25)

		# Left Chalice Sanctuary Medallion fire aura + Dual Progress Halo on top of sculpted 3D plate
		var c := Vector2(80.0, 84.0)
		var pulse_aura := (0.04 + glow_strength * 0.24) + (0.03 + glow_strength * 0.05) * sin(t_ms * 3.2) + score_ledger_glow * 0.20
		player_liquid_bar.draw_circle(c, 50.0, Color(cur_c.r, cur_c.g, cur_c.b, clampf(pulse_aura, 0.03, 0.44)))
		player_liquid_bar.draw_arc(c, 54.5, 0.0, TAU, 56, Color(0.08, 0.05, 0.06, 0.72), 5.4, true)

		# Rotating rune sparkles aligned with sculpted bezel
		for gi in range(12):
			var ga := combo_dial_rot * 0.28 + float(gi) * (TAU / 12.0)
			player_liquid_bar.draw_circle(c + Vector2(cos(ga), sin(ga)) * 54.5, 1.8, Color(cur_c.r, cur_c.g, cur_c.b, 0.42 + glow_strength * 0.42))

		# Pending / Banked preview arc (pulsing cyan-amber ghost arc showing next charge level!)
		if pend_pct > goal_pct + 0.004:
			var p_ang0 := -PI * 0.5 + TAU * goal_pct
			var p_ang1 := -PI * 0.5 + TAU * pend_pct
			var p_alpha := 0.52 + 0.34 * sin(t_ms * 6.4)
			player_liquid_bar.draw_arc(c, 54.5, p_ang0, p_ang1, 48, Color(0.36, 0.94, 1.0, p_alpha), 5.0, true)

		# Confirmed charge arc
		if goal_pct > 0.004:
			var ang_end := -PI * 0.5 + TAU * goal_pct
			player_liquid_bar.draw_arc(c, 54.5, -PI * 0.5, ang_end, 56, cur_c, 5.4, true)
			player_liquid_bar.draw_arc(c, 54.5, -PI * 0.5, ang_end, 56, cur_c.lightened(0.42), 1.8, true)
			var tip_p := c + Vector2(cos(ang_end), sin(ang_end)) * 54.5
			player_liquid_bar.draw_circle(tip_p, 4.0 + sin(t_ms * 5.8) * 0.8, cur_c.lightened(0.45))

		# Floating embers rising inside the Chalice Sanctuary when heated / charging
		for em in combo_embers:
			var lf: float = clampf(float(em["life"]) / maxf(0.01, float(em["max_life"])), 0.0, 1.0)
			var ec: Color = em["col"]
			var ep: Vector2 = em["pos"] + Vector2(48.0, 52.0)
			player_liquid_bar.draw_circle(ep, float(em["sz"]) * lf, Color(ec.r, ec.g, ec.b, lf * 0.85))
	)
	wheel_canvas = player_liquid_bar
	player_hud_grp.add_child(player_liquid_bar)

	# Constant Charge Vessel + Gradual Multi-Pass Living Fire Shader
	chalice_back_fire_rect = ColorRect.new()
	chalice_back_fire_rect.position = Vector2(20, 22)
	chalice_back_fire_rect.size = Vector2(120, 120)
	chalice_back_fire_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalice_back_fire_mat = ShaderMaterial.new()
	chalice_back_fire_mat.shader = CHALICE_FIRE_SHADER
	chalice_back_fire_mat.set_shader_parameter("progress", 0.0)
	chalice_back_fire_mat.set_shader_parameter("heat_surge", 0.0)
	chalice_back_fire_mat.set_shader_parameter("front_pass", 0.0)
	chalice_back_fire_rect.material = chalice_back_fire_mat
	player_hud_grp.add_child(chalice_back_fire_rect)

	score_chalice_art = TextureRect.new()
	score_chalice_art.position = Vector2(26, 30)
	score_chalice_art.size = Vector2(108, 108)
	score_chalice_art.pivot_offset = Vector2(54, 54)
	score_chalice_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	score_chalice_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	score_chalice_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalice_vessel_mat = ShaderMaterial.new()
	chalice_vessel_mat.shader = CHALICE_VESSEL_SHADER
	chalice_vessel_mat.set_shader_parameter("progress", 0.0)
	chalice_vessel_mat.set_shader_parameter("heat_surge", 0.0)
	chalice_vessel_mat.set_shader_parameter("fire_tint", Color(0.48, 0.55, 0.64, 1.0))
	score_chalice_art.material = chalice_vessel_mat
	var ch_3d := _load_blender_ui_tex("chalice_3d.png")
	if ch_3d != null:
		score_chalice_art.texture = ch_3d
	elif not charge_tier_textures.is_empty():
		score_chalice_art.texture = charge_tier_textures[0]
	player_hud_grp.add_child(score_chalice_art)

	score_chalice_next = TextureRect.new()
	score_chalice_next.position = Vector2(26, 30)
	score_chalice_next.size = Vector2(108, 108)
	score_chalice_next.pivot_offset = Vector2(54, 54)
	score_chalice_next.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	score_chalice_next.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	score_chalice_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_chalice_next.material = chalice_vessel_mat
	score_chalice_next.visible = false
	score_chalice_next.modulate.a = 0.0
	player_hud_grp.add_child(score_chalice_next)

	chalice_front_fire_rect = ColorRect.new()
	chalice_front_fire_rect.position = Vector2(20, 22)
	chalice_front_fire_rect.size = Vector2(120, 120)
	chalice_front_fire_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalice_front_fire_mat = ShaderMaterial.new()
	chalice_front_fire_mat.shader = CHALICE_FIRE_SHADER
	chalice_front_fire_mat.set_shader_parameter("progress", 0.0)
	chalice_front_fire_mat.set_shader_parameter("heat_surge", 0.0)
	chalice_front_fire_mat.set_shader_parameter("front_pass", 1.0)
	chalice_front_fire_rect.material = chalice_front_fire_mat
	player_hud_grp.add_child(chalice_front_fire_rect)

	score_chalice_tier_lbl = Label.new()
	score_chalice_tier_lbl.text = "STAGE I"
	score_chalice_tier_lbl.position = Vector2(10, 4)
	score_chalice_tier_lbl.size = Vector2(140, 16)
	score_chalice_tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_chalice_tier_lbl.add_theme_font_override("font", _get_font(true))
	score_chalice_tier_lbl.add_theme_font_size_override("font_size", 11)
	score_chalice_tier_lbl.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96))
	score_chalice_tier_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.02))
	score_chalice_tier_lbl.add_theme_constant_override("outline_size", 4)
	player_hud_grp.add_child(score_chalice_tier_lbl)

	score_chalice_pct_lbl = Label.new()
	score_chalice_pct_lbl.text = "0%"
	score_chalice_pct_lbl.position = Vector2(10, 146)
	score_chalice_pct_lbl.size = Vector2(140, 18)
	score_chalice_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_chalice_pct_lbl.add_theme_font_override("font", _get_font(true))
	score_chalice_pct_lbl.add_theme_font_size_override("font_size", 12)
	score_chalice_pct_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	score_chalice_pct_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	score_chalice_pct_lbl.add_theme_constant_override("outline_size", 5)
	player_hud_grp.add_child(score_chalice_pct_lbl)

	player_score_lbl = Label.new()
	player_score_lbl.text = "SCORE: 0 / 90"
	player_score_lbl.position = Vector2(164, 6)
	player_score_lbl.size = Vector2(198, 28)
	player_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	player_score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_score_lbl.add_theme_font_override("font", _get_font(true))
	player_score_lbl.add_theme_font_size_override("font_size", 18)
	player_score_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.44))
	player_score_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	player_score_lbl.add_theme_constant_override("outline_size", 6)
	player_hud_grp.add_child(player_score_lbl)

	wheel_lap_lbl = Label.new()
	wheel_lap_lbl.text = ""
	wheel_lap_lbl.visible = false
	player_hud_grp.add_child(wheel_lap_lbl)

	mult_lbl = Label.new()
	mult_lbl.text = "×1.0"
	mult_lbl.position = Vector2(418, 6)
	mult_lbl.size = Vector2(46, 24)
	mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mult_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mult_lbl.add_theme_font_override("font", _get_font(true))
	mult_lbl.add_theme_font_size_override("font_size", 14)
	mult_lbl.add_theme_color_override("font_color", Color(1.0, 0.56, 0.42))
	mult_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.02, 0.02))
	mult_lbl.add_theme_constant_override("outline_size", 5)
	player_hud_grp.add_child(mult_lbl)

	score_goal_bar_ctrl = Control.new()
	score_goal_bar_ctrl.position = Vector2(164, 34)
	score_goal_bar_ctrl.size = Vector2(298, 12)
	score_goal_bar_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_goal_bar_ctrl.draw.connect(func():
		var w := score_goal_bar_ctrl.size.x
		var h := score_goal_bar_ctrl.size.y
		var denom := float(maxi(1, target_score))
		var sc_now := maxf(0.0, display_player_score) if hud_score_revealed else 0.0
		var pct_now := clampf(sc_now / denom, 0.0, 1.0)
		var pct_pend := clampf((sc_now + float(pending_player_exchange_pts)) / denom, 0.0, 1.0)
		if pct_pend > pct_now + 0.002:
			var pw := maxf(2.0, (w - 4.0) * pct_pend)
			var pa := 0.50 + 0.35 * sin(float(Time.get_ticks_msec()) * 0.0065)
			score_goal_bar_ctrl.draw_rect(Rect2(2.0, 2.0, pw, h - 4.0), Color(0.32, 0.92, 1.0, pa))
		_draw_liquid_bar(score_goal_bar_ctrl, Rect2(2.0, 2.0, w - 4.0, h - 4.0), pct_now, Color(0.94, 0.68, 0.18), Color(1.0, 0.95, 0.62))
	)
	player_hud_grp.add_child(score_goal_bar_ctrl)

	# ZONE 1 TOP-LEFT UNDER CHALICE: Bare Larger Ringless 2D Heartbeat HP Emblem directly beneath Score Chalice!
	player_hp_pill = null
	player_hp_lbl = null
	player_hp_heart = HeartbeatHpScript.new()
	player_hp_heart.name = "PlayerHeartbeatHp"
	player_hp_heart.anchor_left = 0.0
	player_hp_heart.anchor_top = 0.0
	player_hp_heart.anchor_right = 0.0
	player_hp_heart.anchor_bottom = 0.0
	player_hp_heart.offset_left = 18
	player_hp_heart.offset_top = 182
	player_hp_heart.offset_right = 166
	player_hp_heart.offset_bottom = 278
	hud_root.add_child(player_hp_heart)
	player_hp_heart.call("setup", _get_font(true), false, false)
	player_hp_heart.call("set_hp_with_status", player_hp, player_max_hp, player_shields, "", false, player_knight_shield_charge)

	# Disjoint Row beside Player Heart & beneath Score Ledger (x: 166..660, y: 182..218): Cards/Coins + Carry-Out + Cancel
	bottom_left_status_pill = PanelContainer.new()
	bottom_left_status_pill.anchor_left = 0.0
	bottom_left_status_pill.anchor_top = 1.0
	bottom_left_status_pill.anchor_right = 0.0
	bottom_left_status_pill.anchor_bottom = 1.0
	bottom_left_status_pill.offset_left = 18
	bottom_left_status_pill.offset_top = -90
	bottom_left_status_pill.offset_right = 224
	bottom_left_status_pill.offset_bottom = -54
	bottom_left_status_pill.custom_minimum_size = Vector2(206, 36)
	bottom_left_status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_left_status_pill.add_theme_stylebox_override("panel", _make_tex_panel_style("ui_status_pill_3d.png", 12, 4))
	var bl_hb := HBoxContainer.new()
	bl_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bl_hb.add_theme_constant_override("separation", 6)
	bl_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_left_status_pill.add_child(bl_hb)
	bottom_left_status_lbl = Label.new()
	bottom_left_status_lbl.text = _tr("Cards: 5", "Karty: 5")
	bottom_left_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_left_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_left_status_lbl.add_theme_font_override("font", _get_font(true))
	bottom_left_status_lbl.add_theme_font_size_override("font_size", 12)
	bottom_left_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	bottom_left_status_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	bottom_left_status_lbl.add_theme_constant_override("outline_size", 4)
	bl_hb.add_child(bottom_left_status_lbl)
	var bl_sep := Label.new()
	bl_sep.text = "•"
	bl_sep.add_theme_font_override("font", _get_font(true))
	bl_sep.add_theme_font_size_override("font_size", 12)
	bl_sep.add_theme_color_override("font_color", Color(0.86, 0.68, 0.34))
	bl_hb.add_child(bl_sep)
	status_coin_icon = TextureRect.new()
	status_coin_icon.custom_minimum_size = Vector2(18, 18)
	status_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_coin_icon.texture = _load_blender_ui_tex("ui_coin_3d.png")
	bl_hb.add_child(status_coin_icon)
	status_coins_lbl = Label.new()
	status_coins_lbl.text = "100"
	status_coins_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_coins_lbl.add_theme_font_override("font", _get_font(true))
	status_coins_lbl.add_theme_font_size_override("font_size", 12)
	status_coins_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	status_coins_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	status_coins_lbl.add_theme_constant_override("outline_size", 4)
	bl_hb.add_child(status_coins_lbl)
	hud_root.add_child(bottom_left_status_pill)

	carry_out_pill = PanelContainer.new()
	carry_out_pill.anchor_left = 0.0
	carry_out_pill.anchor_top = 1.0
	carry_out_pill.anchor_right = 0.0
	carry_out_pill.anchor_bottom = 1.0
	carry_out_pill.offset_left = 232
	carry_out_pill.offset_top = -90
	carry_out_pill.offset_right = 424
	carry_out_pill.offset_bottom = -54
	carry_out_pill.custom_minimum_size = Vector2(192, 36)
	carry_out_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carry_out_pill.add_theme_stylebox_override("panel", _make_tex_panel_style("ui_carry_plaque_3d.png", 0, 0))
	var carry_ctrl := Control.new()
	carry_ctrl.name = "CarryContent"
	carry_ctrl.custom_minimum_size = Vector2(184, 36)
	carry_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carry_out_pill.add_child(carry_ctrl)
	carry_out_coin_icon = TextureRect.new()
	carry_out_coin_icon.position = Vector2(11, 6)
	carry_out_coin_icon.size = Vector2(24, 24)
	carry_out_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carry_out_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	carry_out_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carry_out_coin_icon.texture = _load_blender_ui_tex("ui_coin_3d.png")
	carry_ctrl.add_child(carry_out_coin_icon)
	carry_out_score_lbl = Label.new()
	carry_out_score_lbl.text = _tr("Carry: 0 • +25g", "Odnášíš: 0 • +25g")
	carry_out_score_lbl.position = Vector2(44, 2)
	carry_out_score_lbl.size = Vector2(132, 32)
	carry_out_score_lbl.clip_text = true
	carry_out_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carry_out_score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carry_out_score_lbl.add_theme_font_override("font", _get_font(true))
	carry_out_score_lbl.add_theme_font_size_override("font_size", 11)
	carry_out_score_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.54))
	carry_out_score_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01))
	carry_out_score_lbl.add_theme_constant_override("outline_size", 4)
	carry_ctrl.add_child(carry_out_score_lbl)
	carry_out_pill.visible = false
	hud_root.add_child(carry_out_pill)

	var btn_map := Button.new()
	btn_map.name = "MapExitBtn"
	btn_map.text = _tr("Cancel", "Zrušit")
	LialoIcons.apply_button_icon(btn_map, "cross", 14)
	btn_map.tooltip_text = _tr("Cancel current card/action selection", "Zrušit aktuální výběr karty nebo akce")
	btn_map.visible = false
	btn_map.anchor_left = 0.0
	btn_map.anchor_top = 1.0
	btn_map.anchor_right = 0.0
	btn_map.anchor_bottom = 1.0
	btn_map.offset_left = 232
	btn_map.offset_top = -90
	btn_map.offset_right = 330
	btn_map.offset_bottom = -54
	btn_map.custom_minimum_size = Vector2(98, 36)
	btn_map.add_theme_font_override("font", _get_font(true))
	btn_map.add_theme_font_size_override("font_size", 12)
	btn_map.add_theme_color_override("font_color", Color(0.98, 0.88, 0.74))
	btn_map.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.58))
	btn_map.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	btn_map.add_theme_constant_override("outline_size", 5)
	_style_blender_button(btn_map, "ui_btn_cancel_3d.png", Color.WHITE, Color(1.22, 1.14, 1.06), Color(0.82, 0.76, 0.72), Color(0.55, 0.55, 0.58, 0.76), 8, 4)
	btn_map.pressed.connect(func():
		emit_signal("play_sfx_requested", "ui_click")
		if is_instance_valid(suit_modal) and suit_modal.visible:
			_cancel_suit_modal()
		elif not staged_card_indices.is_empty():
			staged_card_indices.clear()
			_recompute_hand_fan_bases()
			_refresh_table_labels()
		_sync_contextual_cancel_btn()
	)
	hud_root.add_child(btn_map)

	player_puf_lbl = Label.new()
	player_puf_lbl.visible = false
	hud_root.add_child(player_puf_lbl)

	# ZONE 2 INSIDE SCORE BOARD: Fixed Permanent Score Ledger & Equation Display (x: 162..464, y: 54..158)
	combo_hud_grp = Control.new()
	combo_hud_grp.position = Vector2(162, 54)
	combo_hud_grp.size = Vector2(302, 104)
	combo_hud_grp.pivot_offset = Vector2(151, 52)
	combo_hud_grp.clip_contents = true
	combo_hud_grp.mouse_filter = Control.MOUSE_FILTER_PASS
	combo_hud_grp.mouse_entered.connect(func():
		if hover_inspect_panel and hover_inspect_title and hovered_card_idx < 0:
			hover_inspect_title.text = _tr("✦ SCORE LEDGER", "✦ ZÁPIS BODŮ")
			hover_inspect_sub.text = _tr("Card Value × Count = Points", "Hodnota karty × Počet = Body")
			if tutorial_mode:
				hover_inspect_desc.text = _tr("Play cards to queue points and charge the Chalice.\nHover or stage cards to preview your combo equation.", "Zahráním karet nabiješ Kalich k cíli.\nNajeď na kartu nebo ji vyber pro náhled rovnice.")
			else:
				hover_inspect_desc.text = _tr("Play cards to charge the Chalice.\nHover cards to preview exact combo points.", "Zahraj karty pro nabití Kalicha.\nNajeď na kartu pro náhled bodů.")
			hover_inspect_panel.visible = true
	)
	combo_hud_grp.mouse_exited.connect(func():
		if hover_inspect_panel and hovered_card_idx < 0 and not hovered_boss_plaque:
			hover_inspect_panel.visible = false
	)
	player_hud_grp.add_child(combo_hud_grp)

	score_ledger_panel = PanelContainer.new()
	score_ledger_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_ledger_panel.offset_left = 4
	score_ledger_panel.offset_top = 4
	score_ledger_panel.offset_right = -4
	score_ledger_panel.offset_bottom = -4
	score_ledger_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_ledger_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	combo_hud_grp.add_child(score_ledger_panel)

	combo_flame_rect = ColorRect.new()
	combo_flame_rect.position = Vector2(5, 5)
	combo_flame_rect.size = Vector2(292, 94)
	combo_flame_rect.visible = false
	combo_flame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_flame_mat = null
	combo_hud_grp.add_child(combo_flame_rect)

	combo_dial_ctrl = Control.new()
	combo_dial_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	combo_dial_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_dial_ctrl.draw.connect(func():
		var sz := combo_dial_ctrl.size
		var t_now := float(Time.get_ticks_msec()) * 0.001
		var frame_r := Rect2(Vector2(2.0, 2.0), sz - Vector2(4.0, 4.0))
		var pulse_c := Color(0.96, 0.78, 0.34).lerp(Color(0.45, 0.94, 1.0), clampf((combo_heat - 0.5) * 0.5, 0.0, 1.0))

		# Crisp woodcut rune border ticks along top & bottom rails
		var tick_col := Color(0.86, 0.66, 0.28, 0.42 + score_ledger_glow * 0.48)
		var tick_count := 16
		for ti in range(tick_count + 1):
			var tx := lerpf(10.0, sz.x - 10.0, float(ti) / float(tick_count))
			var tlen := 5.5 if (ti % 4 == 0) else 3.0
			combo_dial_ctrl.draw_line(Vector2(tx, 2.0), Vector2(tx, 2.0 + tlen), tick_col, 1.4 if (ti % 4 == 0) else 1.0, true)
			combo_dial_ctrl.draw_line(Vector2(tx, sz.y - 2.0), Vector2(tx, sz.y - 2.0 - tlen), tick_col, 1.4 if (ti % 4 == 0) else 1.0, true)

		# Crisp woodcut corner brackets
		var brk_col := Color(0.98, 0.84, 0.42, 0.72 + score_ledger_glow * 0.28)
		for corner in [Vector2(2.0, 2.0), Vector2(sz.x - 2.0, 2.0), Vector2(2.0, sz.y - 2.0), Vector2(sz.x - 2.0, sz.y - 2.0)]:
			var sx := 1.0 if corner.x < sz.x * 0.5 else -1.0
			var sy := 1.0 if corner.y < sz.y * 0.5 else -1.0
			combo_dial_ctrl.draw_line(corner, corner + Vector2(sx * 10.0, 0.0), brk_col, 2.0, true)
			combo_dial_ctrl.draw_line(corner, corner + Vector2(0.0, sy * 10.0), brk_col, 2.0, true)

		# Sharp energetic score-gain pulse border + crisp diamond sparks
		if score_ledger_glow > 0.01:
			var g_alpha := clampf(score_ledger_glow, 0.0, 1.0)
			combo_dial_ctrl.draw_rect(frame_r, Color(1.0, 0.88, 0.34, g_alpha * 0.92), false, 2.2)
			combo_dial_ctrl.draw_rect(frame_r.grow(-3.0), Color(0.42, 0.94, 1.0, g_alpha * 0.48), false, 1.2)
			for si in range(6):
				var sa := t_now * 5.2 + float(si) * (TAU / 6.0)
				var sp_x := lerpf(16.0, sz.x - 16.0, 0.5 + 0.46 * cos(sa))
				var sp_y := 6.0 if (si % 2 == 0) else (sz.y - 6.0)
				var sp_r := (3.2 + 2.0 * sin(t_now * 14.0 + float(si))) * g_alpha
				var sp_c := Color(1.0, 0.95, 0.55, g_alpha)
				combo_dial_ctrl.draw_line(Vector2(sp_x - sp_r, sp_y), Vector2(sp_x + sp_r, sp_y), sp_c, 1.5, true)
				combo_dial_ctrl.draw_line(Vector2(sp_x, sp_y - sp_r), Vector2(sp_x, sp_y + sp_r), sp_c, 1.5, true)
		elif combo_heat > 0.42:
			var h_alpha := clampf((combo_heat - 0.42) * 0.55, 0.0, 0.55)
			combo_dial_ctrl.draw_rect(frame_r, Color(pulse_c.r, pulse_c.g, pulse_c.b, h_alpha), false, 1.5)

		if score_sheen_phase >= 0.0 and score_sheen_phase <= 1.25:
			var sx_pos := lerpf(-60.0, sz.x + 60.0, score_sheen_phase)
			var sheen_poly := PackedVector2Array([
				Vector2(sx_pos - 22.0, 0.0), Vector2(sx_pos + 16.0, 0.0),
				Vector2(sx_pos - 10.0, sz.y), Vector2(sx_pos - 48.0, sz.y)
			])
			combo_dial_ctrl.draw_colored_polygon(sheen_poly, Color(1.0, 0.95, 0.68, 0.30))
		_draw_ornamental_divider(combo_dial_ctrl, sz.y - 3.0, 12.0, sz.x - 12.0, Color(0.84, 0.64, 0.26, 0.58), false)
	)
	combo_hud_grp.add_child(combo_dial_ctrl)

	combo_title_lbl = Label.new()
	combo_title_lbl.text = _tr("CARD × COUNT", "KARTA × POČET")
	combo_title_lbl.position = Vector2(10, 4)
	combo_title_lbl.size = Vector2(184, 18)
	combo_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	combo_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_title_lbl.clip_text = true
	combo_title_lbl.add_theme_font_override("font", _get_font(true))
	combo_title_lbl.add_theme_font_size_override("font_size", 11)
	combo_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.54))
	combo_title_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.01))
	combo_title_lbl.add_theme_constant_override("outline_size", 4)
	combo_hud_grp.add_child(combo_title_lbl)
	score_ledger_state_lbl = combo_title_lbl

	score_delta_lbl = Label.new()
	score_delta_lbl.text = "EVEN"
	score_delta_lbl.position = Vector2(196, 4)
	score_delta_lbl.size = Vector2(96, 18)
	score_delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_delta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_delta_lbl.clip_text = true
	score_delta_lbl.add_theme_font_override("font", _get_font(true))
	score_delta_lbl.add_theme_font_size_override("font_size", 10)
	score_delta_lbl.add_theme_color_override("font_color", Color(0.92, 0.84, 0.56))
	score_delta_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.01))
	score_delta_lbl.add_theme_constant_override("outline_size", 4)
	combo_hud_grp.add_child(score_delta_lbl)

	score_ledger_eq_lbl = Label.new()
	score_ledger_eq_lbl.text = ""
	score_ledger_eq_lbl.visible = false
	combo_hud_grp.add_child(score_ledger_eq_lbl)

	var cf_row := HBoxContainer.new()
	cf_row.position = Vector2(8, 25)
	cf_row.size = Vector2(286, 42)
	cf_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cf_row.add_theme_constant_override("separation", 5)
	cf_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_hud_grp.add_child(cf_row)

	# Breakdown pills hidden cleanly so Score Ledger stays uncluttered
	score_breakdown_row = HBoxContainer.new()
	score_breakdown_row.position = Vector2(8, 70)
	score_breakdown_row.size = Vector2(286, 0)
	score_breakdown_row.visible = false
	score_breakdown_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_hud_grp.add_child(score_breakdown_row)

	score_history_lbl = Label.new()
	score_history_lbl.text = ""
	score_history_lbl.position = Vector2(8, 74)
	score_history_lbl.size = Vector2(286, 18)
	score_history_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_history_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_history_lbl.clip_text = true
	score_history_lbl.add_theme_font_override("font", _get_font(true))
	score_history_lbl.add_theme_font_size_override("font_size", 10)
	score_history_lbl.add_theme_color_override("font_color", Color(0.84, 0.92, 0.72))
	score_history_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.02))
	score_history_lbl.add_theme_constant_override("outline_size", 3)
	score_history_lbl.visible = false
	combo_hud_grp.add_child(score_history_lbl)

	chips_lbl = Label.new()
	chips_lbl.text = "0"
	chips_lbl.add_theme_font_override("font", _get_font(true))
	chips_lbl.add_theme_font_size_override("font_size", 26)
	chips_lbl.add_theme_color_override("font_color", Color(0.62, 0.96, 1.0))
	chips_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.10))
	chips_lbl.add_theme_constant_override("outline_size", 7)
	cf_row.add_child(_wrap_eq_capsule(chips_lbl, Color(0.04, 0.09, 0.16, 0.96), Color(0.32, 0.90, 1.0, 0.96), 12, 4, 10))

	var mul_sep := Label.new()
	mul_sep.text = "×"
	mul_sep.add_theme_font_override("font", _get_font(true))
	mul_sep.add_theme_font_size_override("font_size", 22)
	mul_sep.add_theme_color_override("font_color", Color(0.98, 0.84, 0.50))
	mul_sep.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.01))
	mul_sep.add_theme_constant_override("outline_size", 5)
	cf_row.add_child(mul_sep)

	flat_mult_lbl = Label.new()
	flat_mult_lbl.text = "1"
	flat_mult_lbl.add_theme_font_override("font", _get_font(true))
	flat_mult_lbl.add_theme_font_size_override("font_size", 26)
	flat_mult_lbl.add_theme_color_override("font_color", Color(1.0, 0.52, 0.34))
	flat_mult_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.02, 0.02))
	flat_mult_lbl.add_theme_constant_override("outline_size", 7)
	cf_row.add_child(_wrap_eq_capsule(flat_mult_lbl, Color(0.16, 0.04, 0.05, 0.96), Color(1.0, 0.44, 0.30, 0.96), 12, 4, 10))

	xmult_lbl = Label.new()
	xmult_lbl.text = "×1"
	xmult_lbl.visible = false
	xmult_lbl.add_theme_font_override("font", _get_font(true))
	xmult_lbl.add_theme_font_size_override("font_size", 22)
	xmult_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42))
	xmult_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.06, 0.01))
	xmult_lbl.add_theme_constant_override("outline_size", 6)
	var xmult_cap := _wrap_eq_capsule(xmult_lbl, Color(0.16, 0.10, 0.02, 0.96), Color(1.0, 0.84, 0.28, 0.98), 10, 4, 10)
	xmult_cap.visible = false
	cf_row.add_child(xmult_cap)

	var arr_lbl := Label.new()
	arr_lbl.text = "="
	arr_lbl.add_theme_font_override("font", _get_font(true))
	arr_lbl.add_theme_font_size_override("font_size", 24)
	arr_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
	arr_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.01))
	arr_lbl.add_theme_constant_override("outline_size", 5)
	cf_row.add_child(arr_lbl)

	total_calc_lbl = Label.new()
	total_calc_lbl.text = "+0"
	total_calc_lbl.add_theme_font_override("font", _get_font(true))
	total_calc_lbl.add_theme_font_size_override("font_size", 30)
	total_calc_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.46))
	total_calc_lbl.add_theme_color_override("font_outline_color", Color(0.16, 0.04, 0.01))
	total_calc_lbl.add_theme_constant_override("outline_size", 8)
	cf_row.add_child(_wrap_eq_capsule(total_calc_lbl, Color(0.14, 0.10, 0.02, 0.98), Color(1.0, 0.88, 0.34, 1.0), 14, 5, 11))

	# ZONE 1 RIGHT WING: Round 1 / 6 + Rival Score & 10 HP Crest (x: 994..1350, y: 10..84)
	rival_hud_grp = Control.new()
	rival_hud_grp.anchor_left = 1.0
	rival_hud_grp.anchor_top = 0.0
	rival_hud_grp.anchor_right = 1.0
	rival_hud_grp.offset_left = -362
	rival_hud_grp.offset_top = 10
	rival_hud_grp.offset_right = -14
	rival_hud_grp.offset_bottom = 84
	rival_hud_grp.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_root.add_child(rival_hud_grp)

	var rh_bg_3d := TextureRect.new()
	rh_bg_3d.name = "RivalHudBg3D"
	rh_bg_3d.set_anchors_preset(Control.PRESET_FULL_RECT)
	rh_bg_3d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rh_bg_3d.stretch_mode = TextureRect.STRETCH_SCALE
	rh_bg_3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rh_bg_3d.texture = _load_blender_ui_tex("ui_rival_hud_3d.png")
	rival_hud_grp.add_child(rh_bg_3d)

	ai_liquid_bar = Control.new()
	ai_liquid_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	ai_liquid_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ai_liquid_bar.draw.connect(func():
		var bar_r := Rect2(18.0, 43.0, 194.0, 12.0)
		var pct := (display_ai_score / float(maxi(1, target_score))) if hud_score_revealed else 0.0
		_draw_liquid_bar(ai_liquid_bar, bar_r, pct, Color(0.84, 0.18, 0.28), Color(1.0, 0.68, 0.52))
	)
	rival_hud_grp.add_child(ai_liquid_bar)

	# 3D Animated Rival / Boss Heartbeat HP Widget cleanly positioned beside Rival Score Plaque
	rival_hp_heart = HeartbeatHpScript.new()
	rival_hp_heart.name = "RivalHeartbeatHp"
	hud_root.add_child(rival_hp_heart)
	rival_hp_heart.call("setup", _get_font(true), true, false)
	rival_hp_heart.call("set_hp_with_status", ai_hp, ai_max_hp, 0, "", false)
	_position_rival_hp_heart(false)

	combat_log_drawer = CombatLogDrawerScript.new()
	combat_log_drawer.setup(hud_root, _get_font(true), opts_language)

	ai_score_lbl = Label.new()
	ai_score_lbl.text = "RIVAL: 0 / 120"
	ai_score_lbl.position = Vector2(18, 6)
	ai_score_lbl.size = Vector2(186, 24)
	ai_score_lbl.add_theme_font_override("font", _get_font(true))
	ai_score_lbl.add_theme_font_size_override("font_size", 17)
	ai_score_lbl.add_theme_color_override("font_color", Color(1.0, 0.56, 0.50))
	ai_score_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.01, 0.02))
	ai_score_lbl.add_theme_constant_override("outline_size", 6)
	rival_hud_grp.add_child(ai_score_lbl)

	round_counter_lbl = Label.new()
	round_counter_lbl.text = "ROUND 1 / 6"
	round_counter_lbl.position = Vector2(208, 6)
	round_counter_lbl.size = Vector2(134, 24)
	round_counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_counter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_counter_lbl.add_theme_font_override("font", _get_font(true))
	round_counter_lbl.add_theme_font_size_override("font_size", 16)
	round_counter_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42))
	round_counter_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.02))
	round_counter_lbl.add_theme_constant_override("outline_size", 6)
	rival_hud_grp.add_child(round_counter_lbl)

	battle_audio_toggle_btn = Button.new()
	battle_audio_toggle_btn.visible = false
	battle_audio_toggle_btn.size = Vector2.ZERO
	rival_hud_grp.add_child(battle_audio_toggle_btn)

	battle_audio_drawer = PanelContainer.new()
	battle_audio_drawer.visible = false
	rival_hud_grp.add_child(battle_audio_drawer)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	battle_audio_drawer.add_child(vol_row)

	battle_mute_btn = Button.new()
	battle_mute_btn.text = "Mute"
	battle_mute_btn.custom_minimum_size = Vector2(76, 26)
	battle_mute_btn.add_theme_font_override("font", _get_font(false))
	battle_mute_btn.add_theme_font_size_override("font_size", 13)
	battle_mute_btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74))
	battle_mute_btn.add_theme_stylebox_override("normal", _make_ink_btn_style(Color(0.92, 0.72, 0.34), false))
	battle_mute_btn.add_theme_stylebox_override("hover", _make_ink_btn_style(Color(0.92, 0.72, 0.34), true))
	battle_mute_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	battle_mute_btn.pressed.connect(func(): emit_signal("toggle_mute_requested"))
	vol_row.add_child(battle_mute_btn)

	battle_vol_slider = HSlider.new()
	battle_vol_slider.min_value = 0.0
	battle_vol_slider.max_value = 100.0
	battle_vol_slider.step = 5.0
	battle_vol_slider.value = 85.0
	battle_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sl_bg := StyleBoxFlat.new()
	sl_bg.bg_color = Color(0.18, 0.13, 0.10, 0.85)
	sl_bg.set_corner_radius_all(3)
	sl_bg.content_margin_top = 4
	sl_bg.content_margin_bottom = 4
	var sl_fill := StyleBoxFlat.new()
	sl_fill.bg_color = Color(0.92, 0.72, 0.28, 0.94)
	sl_fill.set_corner_radius_all(3)
	battle_vol_slider.add_theme_stylebox_override("slider", sl_bg)
	battle_vol_slider.add_theme_stylebox_override("grabber_area", sl_fill)
	battle_vol_slider.add_theme_stylebox_override("grabber_area_highlight", sl_fill)
	battle_vol_slider.value_changed.connect(func(val: float):
		emit_signal("volume_changed_requested", int(round(val)))
	)
	vol_row.add_child(battle_vol_slider)

	battle_vol_pct_lbl = Label.new()
	battle_vol_pct_lbl.text = "85%"
	battle_vol_pct_lbl.custom_minimum_size = Vector2(38, 0)
	battle_vol_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_vol_pct_lbl.add_theme_font_override("font", _get_font(false))
	battle_vol_pct_lbl.add_theme_font_size_override("font_size", 14)
	battle_vol_pct_lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.56))
	vol_row.add_child(battle_vol_pct_lbl)

	ai_cards_lbl = Label.new()
	ai_cards_lbl.text = "Cards: 5"
	ai_cards_lbl.position = Vector2(226, 39)
	ai_cards_lbl.size = Vector2(116, 22)
	ai_cards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ai_cards_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ai_cards_lbl.clip_text = false
	ai_cards_lbl.add_theme_font_override("font", _get_font(false))
	ai_cards_lbl.add_theme_font_size_override("font_size", 13)
	ai_cards_lbl.add_theme_color_override("font_color", Color(0.92, 0.84, 0.86))
	ai_cards_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.02))
	ai_cards_lbl.add_theme_constant_override("outline_size", 4)
	rival_hud_grp.add_child(ai_cards_lbl)

	ai_hp_lbl = null

	# ZONE 1 BOTTOM-LEFT BELOW HEART: Prominent Calligraphic Turn Headline ("YOUR TURN" directly under 2D Heart!)
	turn_banner_grp = Control.new()
	turn_banner_grp.anchor_left = 0.0
	turn_banner_grp.anchor_top = 1.0
	turn_banner_grp.anchor_right = 0.0
	turn_banner_grp.anchor_bottom = 1.0
	turn_banner_grp.offset_left = 18
	turn_banner_grp.offset_top = -152
	turn_banner_grp.offset_right = 388
	turn_banner_grp.offset_bottom = -96
	turn_banner_grp.pivot_offset = Vector2(100, 28)
	turn_banner_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_banner_grp.visible = false
	turn_banner_grp.modulate.a = 0.0
	hud_root.add_child(turn_banner_grp)

	turn_ornament_ctrl = Control.new()
	turn_ornament_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	turn_ornament_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_ornament_ctrl.draw.connect(func():
		var t_ms := float(Time.get_ticks_msec()) * 0.001
		var w_line := 260.0
		var pulse_a := 0.55 + 0.25 * sin(t_ms * 3.4)
		var col := turn_banner_accent.lightened(0.28)
		turn_ornament_ctrl.draw_line(Vector2(2.0, 48.0), Vector2(w_line, 48.0), Color(col.r, col.g, col.b, pulse_a * 0.72), 2.2, true)
		turn_ornament_ctrl.draw_circle(Vector2(6.0, 48.0), 3.2, Color(col.r, col.g, col.b, pulse_a))
	)
	turn_banner_grp.add_child(turn_ornament_ctrl)

	turn_banner_lbl = Label.new()
	turn_banner_lbl.position = Vector2(0, 0)
	turn_banner_lbl.size = Vector2(370, 52)
	turn_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_banner_lbl.clip_text = false
	turn_banner_lbl.add_theme_font_override("font", _get_font(true))
	turn_banner_lbl.add_theme_font_size_override("font_size", 44)
	turn_banner_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02, 0.98))
	turn_banner_lbl.add_theme_constant_override("outline_size", 11)
	turn_banner_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	turn_banner_lbl.add_theme_constant_override("shadow_offset_x", 3)
	turn_banner_lbl.add_theme_constant_override("shadow_offset_y", 5)
	turn_banner_grp.add_child(turn_banner_lbl)

	turn_banner_sub_lbl = Label.new()
	turn_banner_sub_lbl.visible = false
	turn_banner_grp.add_child(turn_banner_sub_lbl)

	# Diegetic Turn Timer Pill (30-45s countdown with auto-draw on expiry)
	turn_timer_pill = PanelContainer.new()
	turn_timer_pill.anchor_left = 0.0; turn_timer_pill.anchor_top = 1.0
	turn_timer_pill.anchor_right = 0.0; turn_timer_pill.anchor_bottom = 1.0
	turn_timer_pill.offset_left = 18; turn_timer_pill.offset_top = -194
	turn_timer_pill.offset_right = 250; turn_timer_pill.offset_bottom = -156
	turn_timer_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_timer_pill.visible = false
	var tt_sb := StyleBoxFlat.new()
	tt_sb.bg_color = Color(0.08, 0.06, 0.045, 0.90)
	tt_sb.border_color = Color(0.92, 0.74, 0.28, 0.86)
	tt_sb.set_border_width_all(2)
	tt_sb.set_corner_radius_all(8)
	tt_sb.set_content_margin_all(5)
	turn_timer_pill.add_theme_stylebox_override("panel", tt_sb)
	hud_root.add_child(turn_timer_pill)

	var tt_vb := VBoxContainer.new()
	tt_vb.add_theme_constant_override("separation", 3)
	turn_timer_pill.add_child(tt_vb)

	var tt_hb := HBoxContainer.new()
	tt_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	tt_hb.add_theme_constant_override("separation", 6)
	tt_vb.add_child(tt_hb)
	tt_hb.add_child(LialoIcons.make_icon_rect("hourglass", 16, Color(1.0, 0.90, 0.48)))

	turn_timer_lbl = Label.new()
	turn_timer_lbl.text = _tr("TURN: 35s", "TAH: 35 s")
	turn_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_timer_lbl.add_theme_font_override("font", _get_font(true))
	turn_timer_lbl.add_theme_font_size_override("font_size", 14)
	turn_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48))
	tt_hb.add_child(turn_timer_lbl)

	var tt_bg := ColorRect.new()
	tt_bg.custom_minimum_size = Vector2(204, 6)
	tt_bg.color = Color(0.16, 0.12, 0.09, 0.92)
	tt_vb.add_child(tt_bg)

	turn_timer_bar = ColorRect.new()
	turn_timer_bar.anchor_left = 0.0; turn_timer_bar.anchor_top = 0.0
	turn_timer_bar.anchor_right = 1.0; turn_timer_bar.anchor_bottom = 1.0
	turn_timer_bar.color = Color(0.96, 0.78, 0.26, 0.96)
	tt_bg.add_child(turn_timer_bar)

	# 4-Card Bankai Awakening Seal HUD Indicator (directly above Turn Timer)
	bankai_seal_pill = PanelContainer.new()
	bankai_seal_pill.anchor_left = 0.0; bankai_seal_pill.anchor_top = 1.0
	bankai_seal_pill.anchor_right = 0.0; bankai_seal_pill.anchor_bottom = 1.0
	bankai_seal_pill.offset_left = 18; bankai_seal_pill.offset_top = -232
	bankai_seal_pill.offset_right = 250; bankai_seal_pill.offset_bottom = -198
	bankai_seal_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bankai_seal_pill.visible = false
	var bk_sb := StyleBoxFlat.new()
	bk_sb.bg_color = Color(0.06, 0.05, 0.08, 0.90)
	bk_sb.border_color = Color(0.32, 0.88, 1.0, 0.85)
	bk_sb.set_border_width_all(2)
	bk_sb.set_corner_radius_all(8)
	bk_sb.set_content_margin_all(4)
	bankai_seal_pill.add_theme_stylebox_override("panel", bk_sb)
	hud_root.add_child(bankai_seal_pill)

	bankai_seal_lbl = Label.new()
	bankai_seal_lbl.text = _tr("GRAND SEAL: 0 / 4", "VELKÁ PEČEŤ: 0 / 4")
	bankai_seal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bankai_seal_lbl.add_theme_font_override("font", _get_font(true))
	bankai_seal_lbl.add_theme_font_size_override("font_size", 13)
	bankai_seal_lbl.add_theme_color_override("font_color", Color(0.55, 0.94, 1.0))
	bankai_seal_pill.add_child(bankai_seal_lbl)

	hint_lbl = null

	# 3A. Farebný animovaný Tutoriál PRŠÍ s Duchom Krčmára ("Spirko") vľavo hore
	tutorial_callout_grp = Control.new()
	tutorial_callout_grp.anchor_left = 0.0
	tutorial_callout_grp.anchor_top = 0.0
	tutorial_callout_grp.anchor_right = 0.0
	tutorial_callout_grp.offset_left = 18
	tutorial_callout_grp.offset_top = 100
	tutorial_callout_grp.offset_right = 568
	tutorial_callout_grp.offset_bottom = 268
	tutorial_callout_grp.pivot_offset = Vector2(275, 84)
	tutorial_callout_grp.mouse_filter = Control.MOUSE_FILTER_PASS
	tutorial_callout_grp.visible = false
	tutorial_callout_grp.queue_redraw()
	hud_root.add_child(tutorial_callout_grp)

	tutorial_chapter_lbl = Label.new()
	tutorial_chapter_lbl.visible = false
	tutorial_callout_grp.add_child(tutorial_chapter_lbl)

	tutorial_title_lbl = Label.new()
	tutorial_title_lbl.visible = false
	tutorial_callout_grp.add_child(tutorial_title_lbl)

	tutorial_body_lbl = Label.new()
	tutorial_body_lbl.visible = false
	tutorial_callout_grp.add_child(tutorial_body_lbl)

	tutorial_skip_btn = Button.new()
	tutorial_skip_btn.text = _tr("Skip ›", "Přeskočit ›")
	tutorial_skip_btn.anchor_left = 1.0
	tutorial_skip_btn.anchor_top = 1.0
	tutorial_skip_btn.anchor_right = 1.0
	tutorial_skip_btn.anchor_bottom = 1.0
	tutorial_skip_btn.offset_left = -254
	tutorial_skip_btn.offset_top = -54
	tutorial_skip_btn.offset_right = -116
	tutorial_skip_btn.offset_bottom = -14
	tutorial_skip_btn.visible = false
	tutorial_skip_btn.add_theme_font_override("font", _get_font(false))
	tutorial_skip_btn.add_theme_font_size_override("font_size", 15)
	tutorial_skip_btn.add_theme_color_override("font_color", Color(0.94, 0.86, 0.64, 0.94))
	tutorial_skip_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.45))
	tutorial_skip_btn.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	tutorial_skip_btn.add_theme_constant_override("outline_size", 4)
	tutorial_skip_btn.add_theme_stylebox_override("normal", _make_plaque_style(Color(0.10, 0.08, 0.06, 0.88), Color(0.76, 0.58, 0.24), 8))
	tutorial_skip_btn.add_theme_stylebox_override("hover", _make_plaque_style(Color(0.20, 0.15, 0.10, 0.96), Color(1.0, 0.84, 0.34), 8))
	tutorial_skip_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tutorial_skip_btn.pressed.connect(func():
		emit_signal("play_sfx_requested", "ui_click")
		_skip_tutorial_immediately()
	)
	hud_root.add_child(tutorial_skip_btn)

	# Frameless floating dialogue anchored beside the 3D Ghost (no pop-up box, above woodcut Sobel pass!)
	tutorial_ghost_speech_lbl = Label.new()
	tutorial_ghost_speech_lbl.position = Vector2(240, 108)
	tutorial_ghost_speech_lbl.size = Vector2(220, 148)
	tutorial_ghost_speech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_ghost_speech_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_ghost_speech_lbl.visible = false
	tutorial_ghost_speech_lbl.add_theme_font_override("font", _get_font(true))
	tutorial_ghost_speech_lbl.add_theme_font_size_override("font_size", 18)
	tutorial_ghost_speech_lbl.add_theme_color_override("font_color", Color(0.96, 1.0, 0.92))
	tutorial_ghost_speech_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.98))
	tutorial_ghost_speech_lbl.add_theme_constant_override("outline_size", 7)
	tutorial_ghost_speech_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	tutorial_ghost_speech_lbl.add_theme_constant_override("shadow_offset_x", 2)
	tutorial_ghost_speech_lbl.add_theme_constant_override("shadow_offset_y", 3)
	hud_root.add_child(tutorial_ghost_speech_lbl)

	# ZONE 2 OPENING PACT (Task #7): Old 5-button wager_bar_panel removed!
	# Replaced by (a) Compact Wager Indicator Pill (click to cycle before Turn 1, or click 3D table props)
	# and (b) Standalone Compact Veto Pill shown ONLY before Turn 1.
	wager_bar_panel = null
	wager_gold_btn = null
	wager_item_btn = null
	wager_sword_btn = null

	wager_indicator_pill = PanelContainer.new()
	wager_indicator_pill.name = "WagerIndicatorPill"
	wager_indicator_pill.visible = false
	wager_indicator_pill.anchor_left = 0.0
	wager_indicator_pill.anchor_top = 1.0
	wager_indicator_pill.anchor_right = 0.0
	wager_indicator_pill.anchor_bottom = 1.0
	wager_indicator_pill.offset_left = 18
	wager_indicator_pill.offset_top = -48
	wager_indicator_pill.offset_right = 212
	wager_indicator_pill.offset_bottom = -12
	wager_indicator_pill.custom_minimum_size = Vector2(194, 36)
	wager_indicator_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	wager_indicator_pill.add_theme_stylebox_override("panel", _make_tex_panel_style("ui_wager_pill_3d.png", 0, 0))
	wager_indicator_pill.mouse_entered.connect(func():
		if _can_change_opening_wager():
			wager_indicator_pill.modulate = Color(1.12, 1.08, 1.04)
	)
	wager_indicator_pill.mouse_exited.connect(func():
		wager_indicator_pill.modulate = Color.WHITE
	)
	wager_indicator_pill.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _can_change_opening_wager():
				_cycle_opening_wager()
				get_viewport().set_input_as_handled()
	)
	hud_root.add_child(wager_indicator_pill)

	var wp_ctrl := Control.new()
	wp_ctrl.name = "WagerPillContent"
	wp_ctrl.custom_minimum_size = Vector2(194, 36)
	wp_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wager_indicator_pill.add_child(wp_ctrl)

	wager_indicator_icon = TextureRect.new()
	wager_indicator_icon.name = "WagerIndicatorIcon"
	wager_indicator_icon.position = Vector2(6, 4)
	wager_indicator_icon.size = Vector2(28, 28)
	wager_indicator_icon.pivot_offset = Vector2(14, 14)
	wager_indicator_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wager_indicator_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wager_indicator_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wager_indicator_icon.texture = _load_blender_ui_tex("ui_wager_gold_3d.png")
	wp_ctrl.add_child(wager_indicator_icon)

	wager_indicator_lbl = Label.new()
	wager_indicator_lbl.name = "WagerIndicatorLabel"
	wager_indicator_lbl.text = "25g STAKE"
	wager_indicator_lbl.position = Vector2(42, 2)
	wager_indicator_lbl.size = Vector2(144, 32)
	wager_indicator_lbl.clip_text = true
	wager_indicator_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wager_indicator_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wager_indicator_lbl.add_theme_font_override("font", _get_font(true))
	wager_indicator_lbl.add_theme_font_size_override("font_size", 11)
	wager_indicator_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	wager_indicator_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01))
	wager_indicator_lbl.add_theme_constant_override("outline_size", 4)
	wp_ctrl.add_child(wager_indicator_lbl)

	veto_standalone_panel = PanelContainer.new()
	veto_standalone_panel.name = "VetoStandalonePanel"
	veto_standalone_panel.visible = false
	veto_standalone_panel.position = Vector2(366, 223)
	veto_standalone_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hud_root.add_child(veto_standalone_panel)

	var vs_hb := HBoxContainer.new()
	vs_hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vs_hb.add_theme_constant_override("separation", 6)
	veto_standalone_panel.add_child(vs_hb)

	wager_veto_hand_btn = Button.new()
	wager_veto_hand_btn.name = "VetoHandBtn"
	wager_veto_hand_btn.focus_mode = Control.FOCUS_NONE
	wager_veto_hand_btn.custom_minimum_size = Vector2(124, 34)
	wager_veto_hand_btn.text = _tr("Veto Hand [V]", "Vetovat karty [V]")
	wager_veto_hand_btn.tooltip_text = _tr("Veto opening hand once: redraw 5 fresh cards + top table card before Turn 1", "Vetovat úvodní karty (1×): vymění úvodních 5 karet i kartu na stole před 1. tahem")
	wager_veto_hand_btn.add_theme_font_override("font", _get_font(true))
	wager_veto_hand_btn.add_theme_font_size_override("font_size", 11)
	wager_veto_hand_btn.add_theme_color_override("font_color", Color(0.58, 0.94, 1.0))
	_style_blender_button(wager_veto_hand_btn, "ui_wager_veto_btn_3d.png", Color(0.80, 0.98, 1.10), Color(0.98, 1.18, 1.30), Color(0.64, 0.80, 0.90), Color(0.50, 0.52, 0.56, 0.65), 10, 4)
	wager_veto_hand_btn.pressed.connect(_perform_opening_veto_hand)
	vs_hb.add_child(wager_veto_hand_btn)

	wager_veto_duel_btn = Button.new()
	wager_veto_duel_btn.name = "VetoGameBtn"
	wager_veto_duel_btn.focus_mode = Control.FOCUS_NONE
	wager_veto_duel_btn.custom_minimum_size = Vector2(108, 34)
	wager_veto_duel_btn.text = _tr("Veto Game", "Vetovat hru")
	wager_veto_duel_btn.tooltip_text = _tr("Veto / decline this duel before making your opening move (returns safely to map)", "Vetovat / odmítnout duel na začátku hry před 1. tahem (návrat na mapu bez trestu)")
	wager_veto_duel_btn.add_theme_font_override("font", _get_font(true))
	wager_veto_duel_btn.add_theme_font_size_override("font_size", 11)
	wager_veto_duel_btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.68))
	_style_blender_button(wager_veto_duel_btn, "ui_wager_veto_btn_3d.png", Color(1.14, 0.78, 0.78), Color(1.32, 0.94, 0.92), Color(0.86, 0.60, 0.60), Color(0.50, 0.52, 0.56, 0.65), 10, 4)
	wager_veto_duel_btn.pressed.connect(_perform_opening_veto_duel)
	vs_hb.add_child(wager_veto_duel_btn)

	# ZONE 1 RIGHT GUTTER SEAL: Wrapped Boss Rule Ribbon cleanly below Rival HUD (x: 994..1350, y: 90..132)
	boss_rule_lbl = Label.new()
	boss_rule_lbl.anchor_left = 1.0
	boss_rule_lbl.anchor_top = 0.0
	boss_rule_lbl.anchor_right = 1.0
	boss_rule_lbl.offset_left = -372
	boss_rule_lbl.offset_top = 90
	boss_rule_lbl.offset_right = -16
	boss_rule_lbl.offset_bottom = 132
	boss_rule_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_rule_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_rule_lbl.clip_text = false
	boss_rule_lbl.add_theme_font_override("font", _get_font(false))
	boss_rule_lbl.add_theme_font_size_override("font_size", 12)
	boss_rule_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.44))
	boss_rule_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02))
	boss_rule_lbl.add_theme_constant_override("outline_size", 4)
	var br_sb := _make_plaque_style(Color(0.11, 0.04, 0.05, 0.92), Color(0.86, 0.36, 0.32), 8)
	br_sb.content_margin_left = 10; br_sb.content_margin_right = 10
	br_sb.content_margin_top = 4; br_sb.content_margin_bottom = 4
	boss_rule_lbl.add_theme_stylebox_override("normal", br_sb)
	boss_rule_lbl.visible = false

	# hud_shop_btn hidden permanently (Shop appears cleanly via full-screen YES/NO Gate every 3rd round!)
	hud_shop_btn = Button.new()
	hud_shop_btn.visible = false
	hud_root.add_child(hud_shop_btn)

	# PROP HOVER PILL (Top-Down Table View: floating description when hovering 3D items, anchored cleanly on right below Rival Heart)
	prop_hover_pill = PanelContainer.new()
	prop_hover_pill.anchor_left = 1.0
	prop_hover_pill.anchor_top = 0.0
	prop_hover_pill.anchor_right = 1.0
	prop_hover_pill.anchor_bottom = 0.0
	prop_hover_pill.grow_vertical = Control.GROW_DIRECTION_END
	prop_hover_pill.offset_left = -384
	prop_hover_pill.offset_top = 252
	prop_hover_pill.offset_right = -16
	prop_hover_pill.offset_bottom = 328
	prop_hover_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph_sb := StyleBoxFlat.new()
	ph_sb.bg_color = Color(0.08, 0.055, 0.045, 0.94)
	ph_sb.border_color = Color(0.92, 0.72, 0.32, 0.90)
	ph_sb.set_border_width_all(2)
	ph_sb.set_corner_radius_all(8)
	ph_sb.content_margin_left = 14
	ph_sb.content_margin_right = 14
	ph_sb.content_margin_top = 8
	ph_sb.content_margin_bottom = 8
	prop_hover_pill.add_theme_stylebox_override("panel", ph_sb)
	var ph_vb := VBoxContainer.new()
	ph_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph_vb.add_theme_constant_override("separation", 2)
	prop_hover_pill.add_child(ph_vb)
	prop_hover_title = Label.new()
	prop_hover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prop_hover_title.add_theme_font_override("font", _get_font(true))
	prop_hover_title.add_theme_font_size_override("font_size", 15)
	prop_hover_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	ph_vb.add_child(prop_hover_title)
	prop_hover_desc = Label.new()
	prop_hover_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prop_hover_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prop_hover_desc.add_theme_font_override("font", _get_font(false))
	prop_hover_desc.add_theme_font_size_override("font_size", 12)
	prop_hover_desc.add_theme_color_override("font_color", Color(0.88, 0.84, 0.76))
	ph_vb.add_child(prop_hover_desc)
	prop_hover_pill.visible = false
	hud_root.add_child(prop_hover_pill)

	# GHOST CLOSE-UP CENTERED DIALOGUE PANEL (Rich Parchment & Tavern-Brass Frame + Step Badge + Task Pill)
	tutorial_ghost_center_panel = PanelContainer.new()
	tutorial_ghost_center_panel.custom_minimum_size = Vector2(620, 0)
	tutorial_ghost_center_panel.anchor_left = 0.5
	tutorial_ghost_center_panel.anchor_top = 1.0
	tutorial_ghost_center_panel.anchor_right = 0.5
	tutorial_ghost_center_panel.anchor_bottom = 1.0
	tutorial_ghost_center_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tutorial_ghost_center_panel.offset_left = -310
	tutorial_ghost_center_panel.offset_top = -36
	tutorial_ghost_center_panel.offset_right = 310
	tutorial_ghost_center_panel.offset_bottom = -36
	tutorial_ghost_center_panel.pivot_offset = Vector2(310, 56)
	var gc_sb := StyleBoxFlat.new()
	gc_sb.bg_color = Color(0.065, 0.052, 0.044, 0.96)
	gc_sb.border_color = Color(0.86, 0.70, 0.34, 0.94)
	gc_sb.set_border_width_all(2)
	gc_sb.set_corner_radius_all(16)
	gc_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	gc_sb.shadow_size = 12
	gc_sb.set_content_margin_all(0)
	tutorial_ghost_center_panel.add_theme_stylebox_override("panel", gc_sb)
	var ghost_wave := Control.new()
	ghost_wave.name = "GhostWaveBorder"
	ghost_wave.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghost_wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_wave.draw.connect(func():
		var sz := ghost_wave.size
		if sz.x < 24.0 or sz.y < 24.0:
			return
		var gt := float(Time.get_ticks_msec()) * 0.001
		var ok_col := Color(0.36, 1.0, 0.62)
		var ring_col := tutorial_ghost_accent.lerp(ok_col, clampf(tutorial_ghost_ok_flash, 0.0, 1.0))
		var inner_sb := StyleBoxFlat.new()
		inner_sb.draw_center = false
		inner_sb.border_color = Color(ring_col.r, ring_col.g, ring_col.b, 0.44 + 0.16 * sin(gt * 3.2))
		inner_sb.set_border_width_all(1)
		inner_sb.set_corner_radius_all(13)
		ghost_wave.draw_style_box(inner_sb, Rect2(Vector2(5.0, 5.0), sz - Vector2(10.0, 10.0)))
		var hw := _get_handwriting_progress(tutorial_ghost_center_lbl)
		if bool(hw.get("active", false)):
			var frac := float(hw.get("frac", 0.0))
			var qx := lerpf(38.0, sz.x - 38.0, frac)
			var qy := (sz.y * 0.42 if tutorial_continue_btn and tutorial_continue_btn.visible else sz.y * 0.50) + sin(gt * 28.0) * 2.5
			ghost_wave.draw_circle(Vector2(qx, qy), 8.5, Color(0.42, 0.96, 1.0, 0.34))
			ghost_wave.draw_circle(Vector2(qx, qy), 3.0, Color(1.0, 0.96, 0.72, 0.96))
	)
	tutorial_ghost_center_panel.add_child(ghost_wave)
	var gc_pad := MarginContainer.new()
	gc_pad.add_theme_constant_override("margin_left", 20)
	gc_pad.add_theme_constant_override("margin_right", 20)
	gc_pad.add_theme_constant_override("margin_top", 10)
	gc_pad.add_theme_constant_override("margin_bottom", 12)
	tutorial_ghost_center_panel.add_child(gc_pad)
	var gc_vb := VBoxContainer.new()
	gc_vb.add_theme_constant_override("separation", 7)
	gc_pad.add_child(gc_vb)

	var gc_hdr := HBoxContainer.new()
	gc_hdr.add_theme_constant_override("separation", 8)
	gc_vb.add_child(gc_hdr)

	tutorial_step_badge_pill = PanelContainer.new()
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.18, 0.13, 0.06, 0.96)
	badge_sb.border_color = Color(0.92, 0.76, 0.36, 0.92)
	badge_sb.set_border_width_all(1)
	badge_sb.set_corner_radius_all(9)
	badge_sb.content_margin_left = 10
	badge_sb.content_margin_right = 10
	badge_sb.content_margin_top = 2
	badge_sb.content_margin_bottom = 2
	tutorial_step_badge_pill.add_theme_stylebox_override("panel", badge_sb)
	tutorial_step_badge_lbl = Label.new()
	tutorial_step_badge_lbl.text = _tr("✦ INTRO", "✦ ÚVOD")
	tutorial_step_badge_lbl.add_theme_font_override("font", _get_font(true))
	tutorial_step_badge_lbl.add_theme_font_size_override("font_size", 13)
	tutorial_step_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	tutorial_step_badge_pill.add_child(tutorial_step_badge_lbl)
	gc_hdr.add_child(tutorial_step_badge_pill)

	var gc_spacer := Control.new()
	gc_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gc_hdr.add_child(gc_spacer)

	var spirko_tag := Label.new()
	spirko_tag.text = "SPIRKO"
	spirko_tag.add_theme_font_override("font", _get_font(true))
	spirko_tag.add_theme_font_size_override("font_size", 12)
	spirko_tag.add_theme_color_override("font_color", Color(0.62, 0.88, 0.96, 0.86))
	gc_hdr.add_child(spirko_tag)

	tutorial_ghost_center_lbl = Label.new()
	tutorial_ghost_center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_ghost_center_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_ghost_center_lbl.add_theme_font_override("font", _get_quill_font())
	tutorial_ghost_center_lbl.add_theme_font_size_override("font_size", 20)
	tutorial_ghost_center_lbl.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	gc_vb.add_child(tutorial_ghost_center_lbl)

	tutorial_ghost_quill = HandwritingQuillScript.new()
	tutorial_ghost_quill.name = "TutorialGhostQuill"
	tutorial_ghost_quill.visible = false
	tutorial_ghost_quill.call("setup", _get_quill_font(), 21, Color(0.97, 0.94, 0.86), Color(0.45, 0.94, 1.0), Color(0.98, 0.94, 0.82), Color(0.45, 0.92, 1.0, 0.85))
	tutorial_ghost_quill.quill_stroke_sfx.connect(func(pitch_val: float):
		emit_signal("play_sfx_pitched_requested", "quill_scratch", pitch_val)
	)
	gc_vb.add_child(tutorial_ghost_quill)

	tutorial_task_pill = PanelContainer.new()
	tutorial_task_pill.visible = false
	var task_sb := StyleBoxFlat.new()
	task_sb.bg_color = Color(0.08, 0.19, 0.13, 0.96)
	task_sb.border_color = Color(0.38, 0.96, 0.64, 0.92)
	task_sb.set_border_width_all(1)
	task_sb.set_corner_radius_all(10)
	task_sb.content_margin_left = 12
	task_sb.content_margin_right = 12
	task_sb.content_margin_top = 5
	task_sb.content_margin_bottom = 5
	tutorial_task_pill.add_theme_stylebox_override("panel", task_sb)
	tutorial_task_lbl = Label.new()
	tutorial_task_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_task_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_task_lbl.add_theme_font_override("font", _get_font(true))
	tutorial_task_lbl.add_theme_font_size_override("font_size", 15)
	tutorial_task_lbl.add_theme_color_override("font_color", Color(0.56, 1.0, 0.74))
	tutorial_task_pill.add_child(tutorial_task_lbl)
	gc_vb.add_child(tutorial_task_pill)

	var gc_btn_row := HBoxContainer.new()
	gc_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gc_vb.add_child(gc_btn_row)
	tutorial_continue_btn = Button.new()
	tutorial_continue_btn.text = _tr("Start Learning [SPACE] ▸", "Jdeme na to [SPACE] ▸")
	tutorial_continue_btn.custom_minimum_size = Vector2(236, 38)
	tutorial_continue_btn.add_theme_font_override("font", _get_font(true))
	tutorial_continue_btn.add_theme_font_size_override("font_size", 17)
	_style_action_button(tutorial_continue_btn, Color(0.08, 0.24, 0.34, 0.94), Color(0.45, 0.92, 1.0), 18)
	tutorial_continue_btn.pressed.connect(func():
		_finish_handwriting_anim(tutorial_ghost_center_lbl)
		_advance_tutorial_substep()
	)
	gc_btn_row.add_child(tutorial_continue_btn)
	tutorial_ghost_center_panel.visible = false
	hud_root.add_child(tutorial_ghost_center_panel)
	hud_root.add_child(boss_rule_lbl)

	# Full-screen Tutorial Arrow Overlay (projects 3D card/prop positions + 2D HUD rects into animated golden-ink arrows)
	tutorial_arrow_overlay = Control.new()
	tutorial_arrow_overlay.name = "TutorialArrowOverlay"
	tutorial_arrow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_arrow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_arrow_overlay.z_index = 25
	tutorial_arrow_overlay.visible = false
	tutorial_arrow_overlay.draw.connect(_draw_tutorial_arrow_overlay)
	hud_root.add_child(tutorial_arrow_overlay)

	_setup_unlock_tip_banner()

	# ZONE 2 RELIC SEAL RAIL: Directly beneath Wager / Veto row to the right of Player Heart (x: 166..640, y: 264..296)
	relic_bar_hbox = HBoxContainer.new()
	relic_bar_hbox.position = Vector2(128, 224)
	relic_bar_hbox.size = Vector2(474, 32)
	relic_bar_hbox.add_theme_constant_override("separation", 5)
	relic_bar_hbox.visible = false
	relic_bar_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(relic_bar_hbox)

	# LEFT-FLANK PULSING SEVEN TRAP BANNER (beside Player Heart)
	pending_seven_banner_pill = PanelContainer.new()
	pending_seven_banner_pill.position = Vector2(166, 302)
	pending_seven_banner_pill.custom_minimum_size = Vector2(310, 44)
	pending_seven_banner_pill.pivot_offset = Vector2(155, 22)
	pending_seven_banner_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pending_seven_banner_pill.visible = false
	var psb := _make_plaque_style(Color(0.18, 0.08, 0.04, 0.95), Color(1.0, 0.78, 0.24), 22)
	psb.content_margin_left = 18; psb.content_margin_right = 18
	psb.content_margin_top = 8; psb.content_margin_bottom = 8
	pending_seven_banner_pill.add_theme_stylebox_override("panel", psb)
	pending_seven_banner_lbl = Label.new()
	pending_seven_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pending_seven_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pending_seven_banner_lbl.add_theme_font_override("font", _get_font(true))
	pending_seven_banner_lbl.add_theme_font_size_override("font_size", 17)
	pending_seven_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38))
	pending_seven_banner_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01))
	pending_seven_banner_lbl.add_theme_constant_override("outline_size", 6)
	pending_seven_banner_pill.add_child(pending_seven_banner_lbl)
	hud_root.add_child(pending_seven_banner_pill)

	# EARNED-POINTS THEATRE UNDER TOP-LEFT BODY SCORE BLOCK
	stagger_callout_pill = PanelContainer.new()
	stagger_callout_pill.position = Vector2(162, 166)
	stagger_callout_pill.custom_minimum_size = Vector2(304, 58)
	stagger_callout_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stagger_callout_pill.visible = false
	var sc_sb := _make_plaque_style(Color(0.055, 0.042, 0.036, 0.95), Color(1.0, 0.84, 0.34), 18)
	sc_sb.set_border_width_all(2)
	sc_sb.content_margin_left = 18
	sc_sb.content_margin_right = 18
	sc_sb.content_margin_top = 8
	sc_sb.content_margin_bottom = 8
	stagger_callout_pill.add_theme_stylebox_override("panel", sc_sb)
	var sc_vb := VBoxContainer.new()
	sc_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	sc_vb.add_theme_constant_override("separation", 4)
	sc_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stagger_callout_pill.add_child(sc_vb)

	var sc_top_row := HBoxContainer.new()
	sc_top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sc_top_row.add_theme_constant_override("separation", 12)
	sc_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc_vb.add_child(sc_top_row)

	stagger_callout_lbl = Label.new()
	stagger_callout_lbl.add_theme_font_override("font", _get_font(true))
	stagger_callout_lbl.add_theme_font_size_override("font_size", 18)
	stagger_callout_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	stagger_callout_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	stagger_callout_lbl.add_theme_constant_override("outline_size", 6)
	sc_top_row.add_child(stagger_callout_lbl)

	stagger_step_progress_lbl = Label.new()
	stagger_step_progress_lbl.add_theme_font_override("font", _get_font(true))
	stagger_step_progress_lbl.add_theme_font_size_override("font_size", 13)
	stagger_step_progress_lbl.add_theme_color_override("font_color", Color(0.76, 0.70, 0.56))
	stagger_step_progress_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.02))
	stagger_step_progress_lbl.add_theme_constant_override("outline_size", 4)
	sc_top_row.add_child(stagger_step_progress_lbl)

	stagger_eq_row = HBoxContainer.new()
	stagger_eq_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stagger_eq_row.add_theme_constant_override("separation", 10)
	stagger_eq_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc_vb.add_child(stagger_eq_row)

	stagger_eq_chips_lbl = Label.new()
	stagger_eq_chips_lbl.text = "0"
	stagger_eq_chips_lbl.add_theme_font_override("font", _get_font(true))
	stagger_eq_chips_lbl.add_theme_font_size_override("font_size", 22)
	stagger_eq_chips_lbl.add_theme_color_override("font_color", Color(0.48, 0.92, 1.0))
	stagger_eq_chips_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08))
	stagger_eq_chips_lbl.add_theme_constant_override("outline_size", 6)
	stagger_eq_row.add_child(_wrap_eq_capsule(stagger_eq_chips_lbl, Color(0.04, 0.08, 0.14, 0.94), Color(0.32, 0.88, 1.0, 0.92), 14, 5, 10))

	var eq_mul_sep := Label.new()
	eq_mul_sep.text = "×"
	eq_mul_sep.add_theme_font_override("font", _get_font(true))
	eq_mul_sep.add_theme_font_size_override("font_size", 18)
	eq_mul_sep.add_theme_color_override("font_color", Color(0.92, 0.80, 0.56))
	eq_mul_sep.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	eq_mul_sep.add_theme_constant_override("outline_size", 4)
	stagger_eq_row.add_child(eq_mul_sep)

	stagger_eq_mult_lbl = Label.new()
	stagger_eq_mult_lbl.text = "1"
	stagger_eq_mult_lbl.add_theme_font_override("font", _get_font(true))
	stagger_eq_mult_lbl.add_theme_font_size_override("font_size", 22)
	stagger_eq_mult_lbl.add_theme_color_override("font_color", Color(1.0, 0.54, 0.36))
	stagger_eq_mult_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02))
	stagger_eq_mult_lbl.add_theme_constant_override("outline_size", 6)
	stagger_eq_row.add_child(_wrap_eq_capsule(stagger_eq_mult_lbl, Color(0.14, 0.04, 0.05, 0.94), Color(1.0, 0.46, 0.34, 0.92), 14, 5, 10))

	stagger_eq_xmult_lbl = Label.new()
	stagger_eq_xmult_lbl.text = "×1"
	stagger_eq_xmult_lbl.visible = false
	stagger_eq_xmult_lbl.add_theme_font_override("font", _get_font(true))
	stagger_eq_xmult_lbl.add_theme_font_size_override("font_size", 22)
	stagger_eq_xmult_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.44))
	stagger_eq_xmult_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.06, 0.01))
	stagger_eq_xmult_lbl.add_theme_constant_override("outline_size", 6)
	var stag_xm_cap := _wrap_eq_capsule(stagger_eq_xmult_lbl, Color(0.14, 0.09, 0.02, 0.95), Color(1.0, 0.82, 0.28, 0.96), 12, 5, 10)
	stag_xm_cap.visible = false
	stagger_eq_row.add_child(stag_xm_cap)

	var eq_eq_sep := Label.new()
	eq_eq_sep.text = "="
	eq_eq_sep.add_theme_font_override("font", _get_font(true))
	eq_eq_sep.add_theme_font_size_override("font_size", 20)
	eq_eq_sep.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	eq_eq_sep.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.01))
	eq_eq_sep.add_theme_constant_override("outline_size", 5)
	stagger_eq_row.add_child(eq_eq_sep)

	stagger_eq_total_lbl = Label.new()
	stagger_eq_total_lbl.text = "+0"
	stagger_eq_total_lbl.add_theme_font_override("font", _get_font(true))
	stagger_eq_total_lbl.add_theme_font_size_override("font_size", 24)
	stagger_eq_total_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.44))
	stagger_eq_total_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.04, 0.01))
	stagger_eq_total_lbl.add_theme_constant_override("outline_size", 7)
	stagger_eq_row.add_child(_wrap_eq_capsule(stagger_eq_total_lbl, Color(0.12, 0.09, 0.02, 0.96), Color(1.0, 0.86, 0.32, 0.98), 16, 5, 10))

	hud_root.add_child(stagger_callout_pill)

	# Old bottom dock backdrop & peek_hud_bar hidden permanently per user request
	dock_backdrop_panel = PanelContainer.new()
	dock_backdrop_panel.visible = false
	hud_root.add_child(dock_backdrop_panel)

	peek_hud_bar = PanelContainer.new()
	peek_hud_bar.visible = false
	peek_hud_lbl = Label.new()
	peek_hud_bar.add_child(peek_hud_lbl)
	hud_root.add_child(peek_hud_bar)

	key_hint_lbl = null

	hover_inspect_panel = PanelContainer.new()
	hover_inspect_panel.anchor_left = 1.0
	hover_inspect_panel.anchor_top = 0.0
	hover_inspect_panel.anchor_right = 1.0
	hover_inspect_panel.offset_left = -410
	hover_inspect_panel.offset_top = 204
	hover_inspect_panel.offset_right = -16
	hover_inspect_panel.offset_bottom = 342
	hover_inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_inspect_panel.visible = false
	var hip_sb := StyleBoxFlat.new()
	hip_sb.bg_color = Color(0.075, 0.055, 0.045, 0.94)
	hip_sb.border_color = Color(0.88, 0.70, 0.28, 0.90)
	hip_sb.set_border_width_all(2)
	hip_sb.set_corner_radius_all(18)
	hip_sb.content_margin_left = 14
	hip_sb.content_margin_right = 14
	hip_sb.content_margin_top = 8
	hip_sb.content_margin_bottom = 8
	hover_inspect_panel.add_theme_stylebox_override("panel", hip_sb)
	var hip_vb := VBoxContainer.new()
	hip_vb.add_theme_constant_override("separation", 3)
	hover_inspect_panel.add_child(hip_vb)
	hover_inspect_title = Label.new()
	hover_inspect_title.add_theme_font_override("font", _get_font(true))
	hover_inspect_title.add_theme_font_size_override("font_size", 18)
	hover_inspect_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.44))
	hip_vb.add_child(hover_inspect_title)
	hover_inspect_sub = Label.new()
	hover_inspect_sub.add_theme_font_override("font", _get_font(false))
	hover_inspect_sub.add_theme_font_size_override("font_size", 14)
	hover_inspect_sub.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	hip_vb.add_child(hover_inspect_sub)
	hover_inspect_desc = Label.new()
	hover_inspect_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_inspect_desc.add_theme_font_override("font", _get_font(false))
	hover_inspect_desc.add_theme_font_size_override("font_size", 14)
	hover_inspect_desc.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82))
	hip_vb.add_child(hover_inspect_desc)
	hud_root.add_child(hover_inspect_panel)
	_build_shop_gate_overlay()
	_build_peddler_modal()
	_build_victory_summary_overlay()
	_build_defeat_summary_overlay()
	_build_mist_guess_modal()
	_build_thief_heist_modal()

	# BOTTOM-RIGHT: Compact Gear Icon Button + Help/Actions Drawer Toggle (?)
	settings_icon_btn = Button.new()
	settings_icon_btn.text = ""
	settings_icon_btn.tooltip_text = _tr("Options", "Nastavení")
	LialoIcons.apply_button_icon(settings_icon_btn, "gear", 36)
	settings_icon_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_icon_btn.anchor_left = 1.0
	settings_icon_btn.anchor_top = 1.0
	settings_icon_btn.anchor_right = 1.0
	settings_icon_btn.anchor_bottom = 1.0
	settings_icon_btn.offset_left = -58
	settings_icon_btn.offset_top = -56
	settings_icon_btn.offset_right = -14
	settings_icon_btn.offset_bottom = -12
	_style_action_button(settings_icon_btn, Color(0.11, 0.085, 0.068, 0.96), Color(0.88, 0.68, 0.28), 22)
	for st_name in ["normal", "hover", "pressed", "focus"]:
		var st_sb := settings_icon_btn.get_theme_stylebox(st_name)
		if st_sb is StyleBoxFlat:
			var sb_copy := (st_sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb_copy.content_margin_left = 2
			sb_copy.content_margin_right = 2
			sb_copy.content_margin_top = 2
			sb_copy.content_margin_bottom = 2
			settings_icon_btn.add_theme_stylebox_override(st_name, sb_copy)
	settings_icon_btn.pressed.connect(func():
		emit_signal("play_sfx_requested", "ui_click")
		emit_signal("open_options_requested")
	)
	hud_root.add_child(settings_icon_btn)

	card_guide_btn = Button.new()
	card_guide_btn.name = "CardGuideBtn"
	card_guide_btn.text = ""
	card_guide_btn.tooltip_text = _tr("Actions & Help Drawer ([F1] Guide)", "Akce a Nápověda ([F1] Průvodce)")
	LialoIcons.apply_button_icon(card_guide_btn, "help", 36)
	card_guide_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_guide_btn.anchor_left = 1.0
	card_guide_btn.anchor_top = 1.0
	card_guide_btn.anchor_right = 1.0
	card_guide_btn.anchor_bottom = 1.0
	card_guide_btn.offset_left = -108
	card_guide_btn.offset_top = -56
	card_guide_btn.offset_right = -64
	card_guide_btn.offset_bottom = -12
	_style_action_button(card_guide_btn, Color(0.11, 0.085, 0.068, 0.96), Color(0.88, 0.68, 0.28), 22)
	for st_name in ["normal", "hover", "pressed", "focus"]:
		var st_sb := card_guide_btn.get_theme_stylebox(st_name)
		if st_sb is StyleBoxFlat:
			var sb_copy := (st_sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb_copy.content_margin_left = 2
			sb_copy.content_margin_right = 2
			sb_copy.content_margin_top = 2
			sb_copy.content_margin_bottom = 2
			card_guide_btn.add_theme_stylebox_override(st_name, sb_copy)
	card_guide_btn.pressed.connect(func():
		emit_signal("play_sfx_requested", "ui_click")
		_toggle_bottom_right_drawer()
	)
	hud_root.add_child(card_guide_btn)

	bottom_right_drawer = PanelContainer.new()
	bottom_right_drawer.name = "BottomRightActionsDrawer"
	bottom_right_drawer.anchor_left = 1.0
	bottom_right_drawer.anchor_top = 1.0
	bottom_right_drawer.anchor_right = 1.0
	bottom_right_drawer.anchor_bottom = 1.0
	bottom_right_drawer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_right_drawer.offset_left = -232
	bottom_right_drawer.offset_top = -384
	bottom_right_drawer.offset_right = -14
	bottom_right_drawer.offset_bottom = -64
	bottom_right_drawer.visible = false
	bottom_right_drawer.modulate.a = 0.0
	var brd_sb := StyleBoxFlat.new()
	brd_sb.bg_color = Color(0.91, 0.84, 0.67, 0.98)
	brd_sb.border_color = Color(0.38, 0.24, 0.12, 0.96)
	brd_sb.border_width_left = 3
	brd_sb.border_width_right = 3
	brd_sb.border_width_top = 2
	brd_sb.border_width_bottom = 2
	brd_sb.set_corner_radius_all(6)
	brd_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	brd_sb.shadow_size = 8
	brd_sb.shadow_offset = Vector2(0, 4)
	brd_sb.content_margin_left = 10
	brd_sb.content_margin_right = 10
	brd_sb.content_margin_top = 8
	brd_sb.content_margin_bottom = 8
	bottom_right_drawer.add_theme_stylebox_override("panel", brd_sb)
	hud_root.add_child(bottom_right_drawer)

	var brd_vb := VBoxContainer.new()
	brd_vb.add_theme_constant_override("separation", 6)
	bottom_right_drawer.add_child(brd_vb)

	# Dark wood top scroll roller + prominent × close button
	var top_roller_row := HBoxContainer.new()
	top_roller_row.custom_minimum_size = Vector2(194, 26)
	top_roller_row.add_theme_constant_override("separation", 6)
	brd_vb.add_child(top_roller_row)

	var top_roller_art := Control.new()
	top_roller_art.name = "ScrollRollerTop"
	top_roller_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_roller_art.custom_minimum_size = Vector2(140, 24)
	top_roller_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_roller_art.draw.connect(func():
		var rsz := top_roller_art.size
		var cy := rsz.y * 0.5
		top_roller_art.draw_rect(Rect2(6.0, cy - 6.0, rsz.x - 12.0, 12.0), Color(0.24, 0.14, 0.08, 1.0))
		top_roller_art.draw_rect(Rect2(6.0, cy - 4.0, rsz.x - 12.0, 4.0), Color(0.46, 0.29, 0.16, 0.92))
		top_roller_art.draw_rect(Rect2(6.0, cy - 6.0, rsz.x - 12.0, 12.0), Color(0.14, 0.08, 0.04, 0.95), false, 1.5)
		top_roller_art.draw_circle(Vector2(6.0, cy), 7.5, Color(0.68, 0.50, 0.20, 1.0))
		top_roller_art.draw_circle(Vector2(rsz.x - 6.0, cy), 7.5, Color(0.68, 0.50, 0.20, 1.0))
	)
	top_roller_row.add_child(top_roller_art)

	var brd_close_btn := Button.new()
	brd_close_btn.name = "ScrollCloseBtn"
	brd_close_btn.text = ""
	brd_close_btn.tooltip_text = _tr("Close Scroll", "Zavřít svitek")
	LialoIcons.apply_button_icon(brd_close_btn, "cross", 18)
	brd_close_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brd_close_btn.custom_minimum_size = Vector2(28, 26)
	_style_action_button(brd_close_btn, Color(0.24, 0.12, 0.08, 0.96), Color(0.76, 0.52, 0.22), 8)
	for st_name in ["normal", "hover", "pressed", "focus"]:
		var st_sb := brd_close_btn.get_theme_stylebox(st_name)
		if st_sb is StyleBoxFlat:
			var sb_copy := (st_sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb_copy.content_margin_left = 2
			sb_copy.content_margin_right = 2
			sb_copy.content_margin_top = 2
			sb_copy.content_margin_bottom = 2
			brd_close_btn.add_theme_stylebox_override(st_name, sb_copy)
	brd_close_btn.pressed.connect(func():
		emit_signal("play_sfx_requested", "ui_click")
		_toggle_bottom_right_drawer(false)
	)
	top_roller_row.add_child(brd_close_btn)

	# Task #8: Camera View Mode Toggle Button inside drawer (CARDS <-> TABLE_ITEMS)
	view_toggle_btn = Button.new()
	view_toggle_btn.name = "ViewToggleBtn"
	view_toggle_btn.focus_mode = Control.FOCUS_NONE
	view_toggle_btn.text = _tr("Items [TAB]", "Itemy [TAB]")
	LialoIcons.apply_button_icon(view_toggle_btn, "sword", 16)
	view_toggle_btn.tooltip_text = _tr("Toggle Camera View: Hand Cards <-> 3D Table Items [TAB / SPACE]", "Přepnout pohled kamery: Karty v ruce <-> 3D Itemy na stole [TAB / SPACE]")
	view_toggle_btn.custom_minimum_size = Vector2(188, 34)
	view_toggle_btn.add_theme_font_override("font", _get_font(true))
	view_toggle_btn.add_theme_font_size_override("font_size", 13)
	view_toggle_btn.add_theme_color_override("font_color", Color(0.98, 0.90, 0.66))
	view_toggle_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.78))
	view_toggle_btn.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01))
	view_toggle_btn.add_theme_constant_override("outline_size", 4)
	_style_action_button(view_toggle_btn, Color(0.11, 0.09, 0.08, 0.94), Color(0.84, 0.64, 0.30), 14)
	view_toggle_btn.pressed.connect(func():
		toggle_camera_view_mode(true)
	)
	brd_vb.add_child(view_toggle_btn)

	sort_hand_bar = VBoxContainer.new()
	sort_hand_bar.add_theme_constant_override("separation", 5)
	brd_vb.add_child(sort_hand_bar)

	sort_hand_btns.clear()
	for s_cfg in [
		{"id": "rank",  "en": "Rank [1]",  "cs": "Hodnota [1]", "col": Color(0.92, 0.78, 0.36)},
		{"id": "suit",  "en": "Suit [2]",  "cs": "Barva [2]",   "col": Color(0.45, 0.88, 0.96)},
		{"id": "power", "en": "Power [3]", "cs": "Síla [3]",    "col": Color(0.92, 0.56, 1.0)}
	]:
		var sb_btn := Button.new()
		sb_btn.text = _tr(str(s_cfg["en"]), str(s_cfg["cs"]))
		LialoIcons.apply_button_icon(sb_btn, "sort", 14)
		sb_btn.custom_minimum_size = Vector2(188, 32)
		sb_btn.add_theme_font_override("font", _get_font(true))
		sb_btn.add_theme_font_size_override("font_size", 13)
		var b_c: Color = s_cfg["col"]
		sb_btn.add_theme_color_override("font_color", b_c.lightened(0.38))
		sb_btn.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.04))
		sb_btn.add_theme_constant_override("outline_size", 4)
		_style_action_button(sb_btn, Color(0.11, 0.085, 0.072, 0.94), b_c.darkened(0.10), 12)
		var mode_str := str(s_cfg["id"])
		sb_btn.pressed.connect(func(): _sort_player_hand(mode_str))
		sort_hand_bar.add_child(sb_btn)
		sort_hand_btns.append({"btn": sb_btn, "en": str(s_cfg["en"]), "cs": str(s_cfg["cs"])})

	redraw_action_btn = Button.new()
	redraw_action_btn.text = _tr("REDRAW (3) [M]", "VÝMĚNA (3) [M]")
	LialoIcons.apply_button_icon(redraw_action_btn, "redraw", 16)
	redraw_action_btn.custom_minimum_size = Vector2(188, 34)
	redraw_action_btn.add_theme_font_override("font", _get_font(true))
	redraw_action_btn.add_theme_font_size_override("font_size", 13)
	redraw_action_btn.add_theme_color_override("font_color", Color(0.86, 0.98, 1.0))
	redraw_action_btn.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.14))
	redraw_action_btn.add_theme_constant_override("outline_size", 4)
	_style_action_button(redraw_action_btn, Color(0.09, 0.22, 0.30, 0.96), Color(0.42, 0.88, 1.0), 14)
	redraw_action_btn.pressed.connect(_redraw_staged_cards)
	brd_vb.add_child(redraw_action_btn)

	drawer_guide_btn = Button.new()
	drawer_guide_btn.text = _tr("Card Guide [F1]", "Průvodce [F1]")
	LialoIcons.apply_button_icon(drawer_guide_btn, "scroll", 16)
	drawer_guide_btn.custom_minimum_size = Vector2(188, 32)
	drawer_guide_btn.add_theme_font_override("font", _get_font(true))
	drawer_guide_btn.add_theme_font_size_override("font_size", 13)
	drawer_guide_btn.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68))
	_style_action_button(drawer_guide_btn, Color(0.11, 0.085, 0.072, 0.94), Color(0.84, 0.64, 0.30), 12)
	drawer_guide_btn.pressed.connect(func():
		_toggle_bottom_right_drawer(false)
		_toggle_card_guide_modal()
	)
	brd_vb.add_child(drawer_guide_btn)

	drawer_mute_btn = Button.new()
	drawer_mute_btn.text = _tr("Audio: On", "Zvuk: Zapnuto")
	LialoIcons.apply_button_icon(drawer_mute_btn, "sound_on", 16)
	drawer_mute_btn.custom_minimum_size = Vector2(188, 32)
	drawer_mute_btn.add_theme_font_override("font", _get_font(true))
	drawer_mute_btn.add_theme_font_size_override("font_size", 13)
	drawer_mute_btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74))
	_style_action_button(drawer_mute_btn, Color(0.11, 0.085, 0.072, 0.94), Color(0.84, 0.64, 0.30), 12)
	drawer_mute_btn.pressed.connect(func():
		emit_signal("toggle_mute_requested")
	)
	brd_vb.add_child(drawer_mute_btn)

	# Dark wood bottom scroll roller
	var bot_roller_art := Control.new()
	bot_roller_art.name = "ScrollRollerBot"
	bot_roller_art.custom_minimum_size = Vector2(194, 18)
	bot_roller_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_roller_art.draw.connect(func():
		var rsz := bot_roller_art.size
		var cy := rsz.y * 0.5
		bot_roller_art.draw_rect(Rect2(6.0, cy - 5.0, rsz.x - 12.0, 10.0), Color(0.24, 0.14, 0.08, 1.0))
		bot_roller_art.draw_rect(Rect2(6.0, cy - 3.0, rsz.x - 12.0, 3.5), Color(0.46, 0.29, 0.16, 0.92))
		bot_roller_art.draw_rect(Rect2(6.0, cy - 5.0, rsz.x - 12.0, 10.0), Color(0.14, 0.08, 0.04, 0.95), false, 1.5)
		bot_roller_art.draw_circle(Vector2(6.0, cy), 6.5, Color(0.68, 0.50, 0.20, 1.0))
		bot_roller_art.draw_circle(Vector2(rsz.x - 6.0, cy), 6.5, Color(0.68, 0.50, 0.20, 1.0))
	)
	brd_vb.add_child(bot_roller_art)

	_setup_card_guide_modal()
	relic_inspect_modal = RelicInspect3D.new()
	relic_inspect_modal.name = "RelicInspect3DModal"
	hud_root.add_child(relic_inspect_modal)
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_battle_viewport_resized):
		get_viewport().size_changed.connect(_on_battle_viewport_resized)

	# BUCKSHOT TURN-START ITEM REVIEW BAR (Bottom-Center, clear of bottom-left Heart & YOUR TURN!)
	item_review_bar = PanelContainer.new()
	item_review_bar.name = "ItemReviewPromptBar"
	item_review_bar.anchor_left = 0.5
	item_review_bar.anchor_top = 1.0
	item_review_bar.anchor_right = 0.5
	item_review_bar.anchor_bottom = 1.0
	item_review_bar.offset_left = -280
	item_review_bar.offset_top = -66
	item_review_bar.offset_right = 280
	item_review_bar.offset_bottom = -14
	item_review_bar.visible = false
	var ir_sb := _make_plaque_style(Color(0.06, 0.045, 0.036, 0.95), Color(0.96, 0.78, 0.30, 0.92), 24)
	ir_sb.set_border_width_all(2)
	ir_sb.content_margin_left = 18; ir_sb.content_margin_right = 14
	ir_sb.content_margin_top = 6; ir_sb.content_margin_bottom = 6
	item_review_bar.add_theme_stylebox_override("panel", ir_sb)
	var ir_hb := HBoxContainer.new()
	ir_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	ir_hb.add_theme_constant_override("separation", 14)
	item_review_bar.add_child(ir_hb)
	item_review_lbl = Label.new()
	item_review_lbl.text = _tr("✦ REVIEW TABLE ITEMS — CLICK TO USE OR", "✦ PROHLÉDNI ITEMY NA STOLE — KLIKNI NEBO")
	item_review_lbl.add_theme_font_override("font", _get_font(true))
	item_review_lbl.add_theme_font_size_override("font_size", 14)
	item_review_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	item_review_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01))
	item_review_lbl.add_theme_constant_override("outline_size", 4)
	ir_hb.add_child(item_review_lbl)
	item_review_continue_btn = Button.new()
	item_review_continue_btn.name = "ItemReviewContinueBtn"
	item_review_continue_btn.focus_mode = Control.FOCUS_NONE
	item_review_continue_btn.text = _tr("CARDS [SPACE] ▸", "KE KARTÁM [SPACE] ▸")
	item_review_continue_btn.custom_minimum_size = Vector2(186, 36)
	item_review_continue_btn.add_theme_font_override("font", _get_font(true))
	item_review_continue_btn.add_theme_font_size_override("font_size", 15)
	item_review_continue_btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	_style_action_button(item_review_continue_btn, Color(0.28, 0.16, 0.07, 0.96), Color(1.0, 0.84, 0.34), 18)
	item_review_continue_btn.pressed.connect(func():
		emit_signal("play_sfx_requested", "ui_click")
		_confirm_item_review_to_cards(true)
	)
	ir_hb.add_child(item_review_continue_btn)
	hud_root.add_child(item_review_bar)

	# (Sort hand bar & ViewToggleBtn are now housed inside bottom_right_drawer)

	# CENTER DOCK DEFAULT OVAL PILLS: [W] Quick Play + [R] Look Table
	quick_action_bar = HBoxContainer.new()
	quick_action_bar.anchor_left = 0.5
	quick_action_bar.anchor_top = 1.0
	quick_action_bar.anchor_right = 0.5
	quick_action_bar.anchor_bottom = 1.0
	quick_action_bar.offset_left = -215
	quick_action_bar.offset_top = -55
	quick_action_bar.offset_right = 215
	quick_action_bar.offset_bottom = -16
	quick_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	quick_action_bar.add_theme_constant_override("separation", 10)
	hud_root.add_child(quick_action_bar)

	quick_play_btn = Button.new()
	quick_play_btn.text = _tr("PLAY CARD [W]", "HRÁT KARTU [W]")
	quick_play_btn.custom_minimum_size = Vector2(184, 38)
	quick_play_btn.add_theme_font_override("font", _get_font(true))
	quick_play_btn.add_theme_font_size_override("font_size", 15)
	quick_play_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	_style_action_button(quick_play_btn, Color(0.28, 0.18, 0.08, 0.96), Color(0.96, 0.76, 0.30), 19)
	quick_play_btn.pressed.connect(func():
		emit_signal("play_sfx_requested", "btn_wooden_slam")
		var ev := InputEventKey.new()
		ev.keycode = KEY_W
		ev.pressed = true
		_unhandled_input(ev)
	)
	quick_action_bar.add_child(quick_play_btn)

	quick_peek_btn = Button.new()
	quick_peek_btn.text = _tr("VIEW TABLE [SPACE]", "POHLED STŮL [SPACE]")
	quick_peek_btn.custom_minimum_size = Vector2(204, 38)
	quick_peek_btn.add_theme_font_override("font", _get_font(true))
	quick_peek_btn.add_theme_font_size_override("font_size", 14)
	quick_peek_btn.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_style_action_button(quick_peek_btn, Color(0.12, 0.10, 0.09, 0.94), Color(0.74, 0.60, 0.34), 19)
	quick_peek_btn.pressed.connect(func():
		toggle_camera_view_mode(true)
	)
	quick_action_bar.add_child(quick_peek_btn)

	# (ViewToggleBtn is housed inside bottom_right_drawer)

	stack_action_bar = HBoxContainer.new()
	stack_action_bar.anchor_left = 0.5
	stack_action_bar.anchor_top = 1.0
	stack_action_bar.anchor_right = 0.5
	stack_action_bar.anchor_bottom = 1.0
	stack_action_bar.offset_left = -225
	stack_action_bar.offset_top = -56
	stack_action_bar.offset_right = 225
	stack_action_bar.offset_bottom = -16
	stack_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	stack_action_bar.add_theme_constant_override("separation", 8)
	stack_action_bar.visible = false
	hud_root.add_child(stack_action_bar)

	stack_action_btn = Button.new()
	stack_action_btn.text = "SLAM COMBO [W]"
	stack_action_btn.custom_minimum_size = Vector2(345, 38)
	stack_action_btn.add_theme_font_override("font", _get_font(true))
	stack_action_btn.add_theme_font_size_override("font_size", 16)
	stack_action_btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	stack_action_btn.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.02))
	stack_action_btn.add_theme_constant_override("outline_size", 5)
	_style_action_button(stack_action_btn, Color(0.50, 0.12, 0.16, 0.96), Color(1.0, 0.82, 0.28), 19)
	stack_action_bar.add_child(stack_action_btn)

	stack_clear_btn = Button.new()
	stack_clear_btn.text = ""
	stack_clear_btn.custom_minimum_size = Vector2(42, 38)
	stack_clear_btn.add_theme_font_override("font", _get_font(true))
	stack_clear_btn.add_theme_font_size_override("font_size", 15)
	stack_clear_btn.add_theme_color_override("font_color", Color(0.95, 0.84, 0.74))
	stack_clear_btn.add_theme_stylebox_override("normal", _make_plaque_style(Color(0.18, 0.12, 0.12, 0.90), Color(0.65, 0.42, 0.30), 19))
	stack_clear_btn.add_theme_stylebox_override("hover", _make_plaque_style(Color(0.32, 0.16, 0.16, 0.96), Color(0.95, 0.56, 0.40), 19))
	stack_clear_btn.pressed.connect(func():
		emit_signal("play_sfx_requested", "ui_click")
		staged_card_indices.clear()
		_rebuild_all_3d_hands()
		_refresh_table_labels()
	)
	stack_action_bar.add_child(stack_clear_btn)

	# 4. Dramatic Frameless Entrance Script
	intro_title_grp = Control.new()
	intro_title_grp.anchor_left = 0.5
	intro_title_grp.anchor_top = 0.5
	intro_title_grp.anchor_right = 0.5
	intro_title_grp.anchor_bottom = 0.5
	intro_title_grp.offset_left = -350
	intro_title_grp.offset_top = -95
	intro_title_grp.offset_right = 350
	intro_title_grp.offset_bottom = 35
	intro_title_grp.visible = false
	intro_title_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_title_grp.draw.connect(func():
		var sz := intro_title_grp.size
		_draw_feathered_oval(intro_title_grp, sz * 0.5, Vector2(sz.x * 0.56, sz.y * 0.65), Color(0.02, 0.01, 0.03, 0.88))
		_draw_ornamental_divider(intro_title_grp, 12.0, 90.0, sz.x - 90.0, Color(0.96, 0.78, 0.32, 0.92), true)
		_draw_ornamental_divider(intro_title_grp, sz.y - 12.0, 90.0, sz.x - 90.0, Color(0.96, 0.78, 0.32, 0.92), true)
	)
	hud_root.add_child(intro_title_grp)

	intro_title_lbl = Label.new()
	intro_title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_title_lbl.add_theme_font_override("font", _get_font(true))
	intro_title_lbl.add_theme_font_size_override("font_size", 30)
	intro_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	intro_title_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	intro_title_lbl.add_theme_constant_override("outline_size", 8)
	intro_title_grp.add_child(intro_title_lbl)

	# 5. Queen Suit Picker Modal with Custom Painted Suit Emblems (Localized EN / CS)
	suit_modal = PanelContainer.new()
	suit_modal.anchor_left = 0.5
	suit_modal.anchor_top = 0.5
	suit_modal.anchor_right = 0.5
	suit_modal.anchor_bottom = 0.5
	suit_modal.offset_left = -275
	suit_modal.offset_top = -188
	suit_modal.offset_right = 275
	suit_modal.offset_bottom = 188
	suit_modal.z_index = 45
	suit_modal.visible = false
	var sm_sb := _make_plaque_style(Color(0.065, 0.045, 0.042, 0.97), Color(0.95, 0.78, 0.32), 26)
	sm_sb.set_border_width_all(3)
	sm_sb.content_margin_left = 24; sm_sb.content_margin_right = 24
	sm_sb.content_margin_top = 18; sm_sb.content_margin_bottom = 18
	suit_modal.add_theme_stylebox_override("panel", sm_sb)
	hud_root.add_child(suit_modal)

	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 14)
	suit_modal.add_child(sv)

	suit_modal_title_lbl = Label.new()
	suit_modal_title_lbl.text = _tr("✦ QUEEN — CHOOSE SUIT ✦", "✦ SVRŠEK — ZVOL BARVU ✦")
	suit_modal_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suit_modal_title_lbl.add_theme_font_override("font", _get_font(true))
	suit_modal_title_lbl.add_theme_font_size_override("font_size", 22)
	suit_modal_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	suit_modal_title_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02))
	suit_modal_title_lbl.add_theme_constant_override("outline_size", 6)
	sv.add_child(suit_modal_title_lbl)

	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 14)
	sg.add_theme_constant_override("v_separation", 12)
	sv.add_child(sg)
	suit_modal_btn_lbls.clear()
	for s in SUITS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 96)
		b.text = ""
		var scol: Color = s["col"]
		var sid_str := str(s["id"])
		b.add_theme_stylebox_override("normal", _make_plaque_style(scol.darkened(0.76), scol, 22))
		b.add_theme_stylebox_override("hover", _make_plaque_style(scol.darkened(0.52), scol.lightened(0.35), 22))
		b.add_theme_stylebox_override("pressed", _make_plaque_style(scol.darkened(0.84), scol, 22))

		var b_hb := HBoxContainer.new()
		b_hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		b_hb.offset_left = 14; b_hb.offset_right = -12
		b_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		b_hb.add_theme_constant_override("separation", 12)
		b_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(b_hb)

		var emb_ctrl := Control.new()
		emb_ctrl.custom_minimum_size = Vector2(68, 68)
		emb_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emb_ctrl.draw.connect(func(): _draw_czech_suit_emblem(emb_ctrl, sid_str))
		b_hb.add_child(emb_ctrl)

		var b_lbl := Label.new()
		b_lbl.text = "%s %s" % [_tr(str(s["name"]), str(s.get("name_cs", s["name"]))), str(s["sym"])]
		b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b_lbl.add_theme_font_override("font", _get_font(true))
		b_lbl.add_theme_font_size_override("font_size", 18)
		b_lbl.add_theme_color_override("font_color", scol.lightened(0.45))
		b_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.02))
		b_lbl.add_theme_constant_override("outline_size", 5)
		b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_hb.add_child(b_lbl)
		suit_modal_btn_lbls[sid_str] = b_lbl

		b.pressed.connect(func():
			emit_signal("play_sfx_requested", "btn_card_tick")
			suit_modal.visible = false
			if not pending_play_indices.is_empty():
				var play_idxs := pending_play_indices.duplicate()
				pending_play_indices.clear()
				_play_player_cards_3d(play_idxs, sid_str)
			elif pending_hornik_idx >= 0:
				var idx := pending_hornik_idx
				pending_hornik_idx = -1
				_play_player_cards_3d([idx], sid_str)
		)
		sg.add_child(b)

	var cancel_btn := Button.new()
	cancel_btn.name = "SuitModalCancelBtn"
	cancel_btn.text = _tr("Cancel [ESC]", "Zrušit [ESC]")
	cancel_btn.custom_minimum_size = Vector2(180, 36)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.add_theme_font_override("font", _get_font(true))
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.add_theme_color_override("font_color", Color(0.98, 0.86, 0.72))
	_style_action_button(cancel_btn, Color(0.16, 0.08, 0.08, 0.95), Color(0.86, 0.44, 0.38), 14)
	cancel_btn.pressed.connect(_cancel_suit_modal)
	sv.add_child(cancel_btn)

	# 6. Top-most 2D Mystical Particle Effects Canvas
	hud_fx_layer = Control.new()
	hud_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hud_fx_layer)

	# Fullscreen Multi-Effect Score Resolution Canvas (Lightning, Homing Mana Orbs, Viewport Ember Rain, Starburst Beams, Halo Rings)
	score_fx_overlay = Control.new()
	score_fx_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_fx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_fx_overlay.z_index = 24
	score_fx_overlay.draw.connect(_draw_score_fx_overlay)
	hud_root.add_child(score_fx_overlay)

	if not is_instance_valid(score_resolve_light):
		score_resolve_light = OmniLight3D.new()
		score_resolve_light.position = Vector3(0.0, 1.55, 0.15)
		score_resolve_light.light_color = Color(1.0, 0.86, 0.36)
		score_resolve_light.light_energy = 0.0
		score_resolve_light.omni_range = 6.5
		add_child(score_resolve_light)

func _draw_czech_suit_emblem(ctrl: Control, suit_id: String) -> void:
	var c := ctrl.size * 0.5
	var r := minf(ctrl.size.x, ctrl.size.y) * 0.46
	var sid := suit_id.to_upper()
	var rim_col := Color(0.88, 0.66, 0.28, 0.88)
	match sid:
		"CERVEN":
			rim_col = Color(0.95, 0.28, 0.32, 0.88)
		"GULA":
			rim_col = Color(0.96, 0.78, 0.22, 0.90)
		"ZELEN":
			rim_col = Color(0.32, 0.86, 0.46, 0.88)
	ctrl.draw_circle(c, r + 2.5, Color(0.04, 0.03, 0.03, 0.86))
	ctrl.draw_arc(c, r + 1.0, 0.0, TAU, 36, rim_col, 2.0, true)
	if not _suit_crest_cache.has(sid):
		var tex_path := "res://assets/ui/suits/suit_%s.png" % sid.to_lower()
		_suit_crest_cache[sid] = Toon.tex(tex_path)
	var crest_tex: Texture2D = _suit_crest_cache.get(sid, null)
	if crest_tex != null:
		var side := minf(ctrl.size.x, ctrl.size.y) * 0.92
		var rect := Rect2(c - Vector2(side * 0.5, side * 0.5), Vector2(side, side))
		ctrl.draw_texture_rect(crest_tex, rect, false)
		return
	ctrl.draw_circle(c, r * 0.62, rim_col)

func _save_shop_checkpoint() -> void:
	checkpoint_state = {
		"player_score": player_score,
		"ai_score": ai_score,
		"current_round_num": current_round_num,
		"match_turn_count": match_turn_count,
		"player_available_gold": player_available_gold,
		"puf_charges": puf_charges,
		"player_shields": player_shields,
		"redraws_left": redraws_left,
		"player_hand": player_hand.duplicate(true),
		"ai_hand": ai_hand.duplicate(true),
		"deck": deck.duplicate(true),
		"discard_pile": discard_pile.duplicate(true),
		"active_suit_id": active_suit_id,
	}
	_sync_contextual_cancel_btn()

func _restore_or_exit_checkpoint() -> void:
	_cancel_active_cinematic()
	if not checkpoint_state.is_empty() and not tutorial_mode:
		player_score = int(checkpoint_state.get("player_score", player_score))
		ai_score = int(checkpoint_state.get("ai_score", ai_score))
		display_player_score = float(player_score)
		display_ai_score = float(ai_score)
		current_round_num = int(checkpoint_state.get("current_round_num", current_round_num))
		match_turn_count = int(checkpoint_state.get("match_turn_count", match_turn_count))
		player_available_gold = int(checkpoint_state.get("player_available_gold", player_available_gold))
		puf_charges = int(checkpoint_state.get("puf_charges", puf_charges))
		player_shields = int(checkpoint_state.get("player_shields", player_shields))
		redraws_left = int(checkpoint_state.get("redraws_left", redraws_left))
		player_hand = (checkpoint_state.get("player_hand", []) as Array).duplicate(true)
		ai_hand = (checkpoint_state.get("ai_hand", []) as Array).duplicate(true)
		deck = (checkpoint_state.get("deck", []) as Array).duplicate(true)
		discard_pile = (checkpoint_state.get("discard_pile", []) as Array).duplicate(true)
		active_suit_id = str(checkpoint_state.get("active_suit_id", active_suit_id))
		pending_draw = 0
		pending_skip = false
		pending_seven_trap_bonus = 0
		pending_player_exchange_pts = 0
		pending_player_exchange_notes.clear()
		pending_player_best_slam = 0
		pending_player_best_desc = ""
		pending_ai_exchange_pts = 0
		pending_ai_exchange_notes.clear()
		_score_resolve_token += 1
		score_resolving_active = false
		last_settled_eq_str = ""
		if pending_seven_banner_pill:
			pending_seven_banner_pill.visible = false
		busy_animating = false
		is_player_turn = true
		_sync_charge_chalice_art(true)
		_refresh_score_ledger_ui()
		_rebuild_all_3d_hands()
		_refresh_discard_top_mesh()
		_refresh_table_labels()
		_spawn_score_popup(_tr("↺ RESTORED SHOP CHECKPOINT!", "↺ VRÁCENO NA CHECKPOINT PO OBCHODĚ!"), Color(0.45, 0.94, 1.0), true)
		return
	emit_signal("exit_to_map_requested")

func start_3d_battle(era: Dictionary, chosen_deck: Dictionary = {}, is_tutorial: bool = false, run_loadout: Dictionary = {}) -> void:
	set_active(true)
	_cursor_look_pos = Vector2(-1.0, -1.0)
	_cancel_active_cinematic()
	_battle_session_token += 1
	_ai_turn_seq += 1
	_stagger_seq_token += 1
	_score_resolve_token += 1
	active_era = era
	player_deck_data = chosen_deck
	_refresh_draw_deck_theme(chosen_deck)
	tutorial_mode = is_tutorial
	tutorial_step = 0
	tutorial_substep = 0
	_tutorial_action_done = ""
	_active_unlock_tip_id = ""
	_unlock_tip_queue.clear()
	if unlock_tip_panel:
		unlock_tip_panel.visible = false
	if is_tutorial:
		active_run_profile = {}
	else:
		var prof_in = run_loadout.get("profile", null)
		active_run_profile = prof_in if (prof_in is Dictionary and not prof_in.is_empty()) else Catalog.load_profile()
	if is_tutorial:
		run_custom_cards = []
		run_active_relics = []
		run_table_relics = []
		run_card_editions = {}
		run_removed_cards = []
		run_added_cards = []
		run_suit_overrides = {}
		run_relic_scales = {}
		match_relic_scales = {}
		run_shop_rerolls = 0
		active_endless_ante = 0
		active_stage_data = {}
		active_boss_mod = ""
		active_boss_desc = ""
		redraws_left = 0
		player_shields = 0
		player_knight_shield_charge = 0
		ai_shields = 0
		boss_phase = 1
		sealed_suit_id = ""
		sealed_suit_turns = 0
		shifting_winds_active = (active_boss_mod == "SHIFTING_WINDS")
		stamped_card_key = ""
		cards_points_revealed = false
		abilities_revealed = false
		hud_score_revealed = false
		hud_combo_revealed = false
		puf_revealed = false
	else:
		run_custom_cards = run_loadout.get("custom_cards", []).duplicate()
		run_active_relics = run_loadout.get("active_relics", []).duplicate()
		if run_active_relics.size() > Catalog.MAX_ACTIVE_RELICS:
			run_active_relics.resize(Catalog.MAX_ACTIVE_RELICS)
		run_table_relics = run_loadout.get("table_relics", ["TRELIC_BLOOD_SEAL", "TRELIC_STAR_BOW"]).duplicate()
		if run_table_relics.size() > Catalog.MAX_ACTIVE_RELICS:
			run_table_relics.resize(Catalog.MAX_ACTIVE_RELICS)
		run_card_editions = run_loadout.get("card_editions", {}).duplicate()
		run_removed_cards = run_loadout.get("removed_cards", []).duplicate()
		run_added_cards = run_loadout.get("added_cards", []).duplicate()
		run_suit_overrides = run_loadout.get("suit_overrides", {}).duplicate()
		run_relic_scales = run_loadout.get("relic_scales", {}).duplicate()
		match_relic_scales = run_relic_scales.duplicate()
		run_shop_rerolls = int(run_loadout.get("shop_rerolls", 0))
		active_endless_ante = int(run_loadout.get("endless_ante", 0))
		active_stage_data = run_loadout.get("stage_data", {}).duplicate()
		active_boss_mod = str(active_stage_data.get("boss_mod", ""))
		active_boss_desc = str(active_stage_data.get("boss_desc", ""))
		active_campaign_difficulty = str(run_loadout.get("campaign_difficulty", "traveler"))
		active_retry_blessing = clampi(int(run_loadout.get("retry_blessing", 0)), 0, 3)
		var base_redraw := 3 if active_campaign_difficulty == "traveler" else 2
		redraws_left = base_redraw + (2 if "REL_CHRONO_P" in run_active_relics else 0)
		player_shields = (1 if active_campaign_difficulty == "traveler" else 0) + (1 if "REL_IRON_BOOT" in run_active_relics else 0) + (1 if active_retry_blessing > 0 else 0)
		player_knight_shield_charge = 0
		ai_shields = 0
		boss_phase = 1
		sealed_suit_id = ""
		sealed_suit_turns = 0
		shifting_winds_active = (active_boss_mod == "SHIFTING_WINDS")
		stamped_card_key = ""
		bankai_build_id = str(active_run_profile.get("selected_build_id", "GUILLOTINE_ACES"))
		var b_def := Catalog.get_deck_build(bankai_build_id)
		bankai_combo = (active_run_profile.get("bankai_combo", b_def.get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"])) as Array).duplicate()
		bankai_charged.clear()
		bankai_active = false
		if is_instance_valid(bankai_fx):
			bankai_fx.clear_aura()
		_refresh_bankai_seal_hud()
		cards_points_revealed = true
		abilities_revealed = true
		hud_score_revealed = true
		hud_combo_revealed = true
		puf_revealed = true
	var rivals_arr = run_loadout.get("rivals", [])
	var r_cnt: int = (rivals_arr as Array).size() if rivals_arr is Array else 0
	active_player_count = 2 if is_tutorial else maxi(2, maxi(int(run_loadout.get("player_count", 2)), 1 + r_cnt))

	last_player_play_suit = ""
	last_player_play_rank = ""
	rival_cards_revealed_turns = 0
	extra_player_turn = false
	deferred_ai_draw = 0
	deferred_ai_skip = false
	pending_seven_trap_bonus = 0
	pending_ai_seven_trap_bonus = 0
	pending_ace_stun_bonus = 0
	pending_skip_turns = 0
	pending_king_challenge.clear()
	rival_burn_turns = 0
	rival_poison_turns = 0
	rival_tax_debuff = false
	rival_shatter_debuff = false
	player_poison_turns = 0
	player_tax_debuff = false
	player_shatter_debuff = false
	knight_mist_active = false
	knight_mist_hidden_card.clear()
	knight_mist_from_ai = false
	mist_guess_open = false
	if mist_guess_modal:
		mist_guess_modal.visible = false
	thief_heist_open = false
	if thief_heist_modal:
		thief_heist_modal.visible = false
	if is_instance_valid(opp_fire_fx_root):
		opp_fire_fx_root.visible = false
	if is_instance_valid(opp_fire_light):
		opp_fire_light.light_energy = 0.0
	if is_instance_valid(discard_mist_fx_root):
		discard_mist_fx_root.visible = false
	for dn in _scored_display_nodes:
		if is_instance_valid(dn):
			dn.queue_free()
	_scored_display_nodes.clear()
	for ptn in purchased_table_item_nodes:
		if is_instance_valid(ptn):
			ptn.queue_free()
	purchased_table_item_nodes.clear()
	checkpoint_state.clear()
	_sync_contextual_cancel_btn()
	if victory_summary_overlay:
		victory_summary_overlay.visible = false
	if defeat_summary_overlay:
		defeat_summary_overlay.visible = false
	dramatic_lighting_dim = 0.0
	finisher_anim_active = false
	_clear_blender_vfx()
	if pending_seven_banner_pill:
		pending_seven_banner_pill.visible = false
	storm_surge_mult = 0.0
	match_bonus_gold = 0
	match_best_slam = 0
	match_best_move_desc = ""
	match_optimal_possible_slam = 0
	match_optimal_move_desc = ""
	match_turn_count = 0
	aces_played = 0
	current_round_num = 1
	player_max_hp = DEFAULT_MAX_HP
	ai_max_hp = DEFAULT_MAX_HP
	player_hp = player_max_hp
	ai_hp = ai_max_hp
	opening_turn_committed = false
	opening_veto_used = false
	invoked_table_relics.clear()
	relic_mgr.reset_all()
	relic_mgr.load_broken_list(run_loadout.get("broken_relics", []))
	if combat_log_drawer != null:
		combat_log_drawer.set_language(opts_language)
		combat_log_drawer.clear_log()
		combat_log_drawer.set_open(false)
		_refresh_combat_log_relic_pill()
	table_relic_blood_seal_active = false
	table_relic_hollow_mask_active = false
	turn_score_history.clear()
	_set_score_breakdown_chips([])
	_refresh_suit_modal_labels()

	target_score = int(run_loadout.get("target_score", era.get("target", 90)))
	var sb_raw := int(chosen_deck.get("start_bonus_pts", 0))
	player_score = 0 if is_tutorial else mini(10, int(sb_raw / 3) + (5 if "REL_IRON_BOOT" in run_active_relics else 0) + (active_retry_blessing * 5))
	var ai_headstart := 8 if (not is_tutorial and active_boss_mod in ["IRON_WALL", "DON_RACKETEER", "ENDLESS_TITAN"]) else 0
	ai_score = ai_headstart
	display_player_score = float(player_score)
	display_ai_score = float(ai_score)
	pending_player_exchange_pts = 0
	pending_player_exchange_notes.clear()
	pending_player_best_slam = 0
	pending_player_best_desc = ""
	pending_ai_exchange_pts = 0
	pending_ai_exchange_notes.clear()
	_score_resolve_token += 1
	score_resolving_active = false
	last_settled_eq_str = ""
	score_sheen_phase = -1.0
	score_ledger_glow = 0.0
	_score_fx_orbs.clear()
	_score_fx_bolts.clear()
	_score_fx_embers.clear()
	_score_fx_rings.clear()
	_score_fx_beams_alpha = 0.0
	_score_fx_active_time = 0.0
	last_charge_tier_idx = _get_charge_tier_index(player_score, target_score)
	_sync_charge_chalice_art(true)
	ai_stun_turns = 0
	puf_charges = 2 + int(chosen_deck.get("bonus_puf", 0)) + (1 if (not is_tutorial and "REL_ALEMBIC" in run_active_relics) else 0)
	pending_draw = 0
	pending_skip = false
	is_player_turn = true
	busy_animating = false
	cam_impact_active = false
	_stagger_seq_token += 1
	cam_spring.reset()
	cam_prev_pitch_kick = 0.0
	cam_prev_fov_kick = 0.0
	if stagger_callout_pill:
		stagger_callout_pill.visible = false
	if peek_hud_bar:
		peek_hud_bar.visible = false
	reorder_src_idx = -1
	lmb_down = false
	drag_card_idx = -1
	drag_active = false
	preview_hud_active = false
	opp_recoil_time = 0.0
	boss_flare_time = 0.0
	chandelier_sway_boost = 0.0
	staged_card_indices.clear()
	pending_play_indices.clear()
	pending_hornik_idx = -1
	turn_stage = TurnStage.CARD_PLAY if is_tutorial else TurnStage.ITEM_REVIEW
	cam_view_mode = CameraViewMode.TABLE_ITEMS
	cards_tucked = true
	auto_edge_peek = false
	turn_glance_timer = 0.0
	cam_look_yaw = 0.0
	cam_look_pitch = 0.0
	opp_item_charges = 2 if (_get_opponent_visual_tier() >= 2) else 1
	if is_instance_valid(opp_table_items_root):
		opp_table_items_root.visible = not is_tutorial
	if is_instance_valid(opp_phial_node):
		var op_tag := opp_phial_node.get_node_or_null("OppPhialTag") as Label3D
		if op_tag:
			op_tag.text = "IGNIS (%d×)" % opp_item_charges
	duel_chalice_mult = 0.0
	duel_whetstone_stacks = 0
	duel_next_xmult = 1.0
	duel_sword_bonus_gold = 0
	duel_gold_delta = 0
	peddler_open = false
	shop_gate_open = false
	tutorial_substep = 0
	if shop_gate_overlay:
		shop_gate_overlay.visible = false
	peddler_offers.clear()
	if peddler_modal:
		peddler_modal.visible = false
	glove_lunge_boost = 0.0
	wager_showcase_boost = 0.0
	rmb_down = false
	freelook_yaw = 0.0
	freelook_pitch = 0.0
	tutorial_turns_left = 3
	player_hand_anchor.position = HAND_POS_TUCKED
	player_hand_anchor.rotation_degrees = HAND_ROT_TUCKED
	_rebuild_relic_visuals()
	_refresh_boss_stone_plaque_3d()
	if sort_hand_bar:
		sort_hand_bar.visible = not is_tutorial
	if boss_rule_lbl:
		var loc_boss_desc := _get_boss_desc_loc()
		if not is_tutorial and loc_boss_desc != "":
			boss_rule_lbl.text = "%s: %s" % [_get_stage_name_loc(), loc_boss_desc]
			boss_rule_lbl.tooltip_text = "%s\n%s" % [loc_boss_desc, _get_boss_counterplay_tip()]
			boss_rule_lbl.visible = true
		else:
			boss_rule_lbl.visible = false
	if redraw_action_btn:
		redraw_action_btn.visible = not is_tutorial
	if hover_inspect_panel:
		hover_inspect_panel.visible = false
	if magic_puf_bottle:
		magic_puf_bottle.visible = puf_revealed
		magic_puf_bottle.position = Vector3(0.56, 0.815, 0.14)
		magic_puf_bottle.rotation_degrees = Vector3.ZERO
		magic_puf_bottle.scale = Vector3.ONE
	if player_score_lbl:
		player_score_lbl.visible = hud_score_revealed
		player_score_lbl.scale = Vector2.ONE
		player_score_lbl.modulate.a = 1.0
	if ai_score_lbl:
		ai_score_lbl.visible = hud_score_revealed
		ai_score_lbl.scale = Vector2.ONE
		ai_score_lbl.modulate.a = 1.0
	if combo_hud_grp:
		combo_hud_grp.visible = hud_combo_revealed
		combo_hud_grp.position = Vector2(162, 68)
		combo_hud_grp.scale = Vector2.ONE
		combo_hud_grp.modulate.a = 1.0
	if tutorial_callout_grp:
		tutorial_callout_grp.visible = false
	if turn_banner_grp and is_tutorial:
		turn_banner_grp.visible = false
		_last_turn_toast_key = ""
	if tutorial_skip_btn:
		tutorial_skip_btn.visible = is_tutorial
	if tutorial_beacon_mesh:
		tutorial_beacon_mesh.visible = false
	if tutorial_ghost_3d:
		if is_tutorial:
			_build_detailed_tutorial_ghost()
		tutorial_ghost_3d.visible = is_tutorial
	if tutorial_ghost_speech_3d:
		tutorial_ghost_speech_3d.visible = false
	if tutorial_ghost_speech_lbl:
		tutorial_ghost_speech_lbl.visible = is_tutorial
	_last_turn_toast_key = ""
	finisher_anim_active = false
	opp_recoil_time = 0.0
	opp_shake_time = 0.0
	boss_flare_time = 0.0
	if _finisher_sword_tween and _finisher_sword_tween.is_valid():
		_finisher_sword_tween.kill()
	if _opp_finisher_tween and _opp_finisher_tween.is_valid():
		_opp_finisher_tween.kill()

	# 1. Rival silhouette, exterior window vista, resting swords & 3D gauntlets matching era
	var era_id: String = era.get("id", "stredovek")
	apply_exterior_vista_for_era(era_id)
	_build_opponent_silhouette_for_era(era_id)
	opp_silhouette_root.position = Vector3(0.0, 0.86, -1.50)
	opp_silhouette_root.rotation_degrees = Vector3.ZERO
	var boss_tier_val := _get_opponent_visual_tier()
	var is_boss_battle := (boss_tier_val >= 2)
	var boss_sc := 1.07 if is_boss_battle else (1.03 if boss_tier_val == 1 else 1.0)
	opp_silhouette_root.scale = Vector3(boss_sc, boss_sc, boss_sc)
	var era_heart_accent: Color = era.get("border_col", era.get("accent", Color(1.0, 0.72, 0.24)))
	if is_instance_valid(rival_hp_heart):
		rival_hp_heart.call("set_boss_mode", is_boss_battle, era_heart_accent)
		_position_rival_hp_heart(is_boss_battle)
	_sync_heartbeat_hp_displays(false)
	active_sword_skin_id = str(run_loadout.get("equipped_sword", "SWORD_IRON"))
	_refresh_player_sword_visual(active_sword_skin_id)
	if is_instance_valid(player_sword_root):
		player_sword_root.position = Vector3(1.02, 0.822, 0.22)
		player_sword_root.rotation_degrees = Vector3(0.0, 16.0, 0.0)
	if is_instance_valid(opp_sword_root):
		opp_sword_root.position = Vector3(-0.38, 0.822, -0.74)
		opp_sword_root.rotation_degrees = Vector3(0.0, 96.0, 0.0)

	player_available_gold = int(run_loadout.get("player_gold", 100))
	var init_wager := str(run_loadout.get("wager_type", "SWORD" if (not is_tutorial and player_available_gold < 25) else "GOLD"))
	set_duel_wager(init_wager, true)
	if wager_bar_panel:
		wager_bar_panel.visible = false

	var glove_tex := "res://assets/gloves/glove_iron.png" if era_id == "stredovek" or era_id == "rim" else "res://assets/gloves/glove_leather.png"
	var g_mat := Toon.mat(era.get("glove_col", Color(0.35, 0.20, 0.15)), glove_tex, 0.0022, Vector2.ONE, era.get("border_col", Color(0.8, 0.6, 0.2)) * 0.12)
	var o_slv := Toon.mat(era.get("glove_col", Color(0.20, 0.14, 0.14)).darkened(0.45), "res://assets/table/felt.png", 0.003)
	var o_met := Toon.mat(Color(0.82, 0.64, 0.24), "", 0.0016)
	_apply_hand_materials(opp_glove_left_mesh, g_mat, o_slv, o_met)
	_apply_hand_materials(opp_glove_right_mesh, g_mat, o_slv, o_met)

	# 2. Player's own 3D gauntlets & sleeves/body matching selected deck
	var p_use_iron: bool = bool(chosen_deck.get("use_iron", false))
	var p_tex := "res://assets/gloves/glove_iron.png" if p_use_iron else "res://assets/gloves/glove_leather.png"
	var p_col: Color = chosen_deck.get("glove_col", Color(0.48, 0.32, 0.19))
	var p_mat := Toon.mat(p_col, p_tex, 0.0022, Vector2.ONE, chosen_deck.get("border_col", Color(0.4, 0.3, 0.2)) * 0.08)
	var p_slv := Toon.mat(p_col.darkened(0.42), "res://assets/table/felt.png", 0.003)
	var p_met := Toon.mat(chosen_deck.get("border_col", Color(0.88, 0.68, 0.26)), "", 0.0016)
	_apply_hand_materials(player_glove_left_mesh, p_mat, p_slv, p_met)
	_apply_hand_materials(player_glove_right_mesh, p_mat, p_slv, p_met)

	var deck_lbl: String = _tr(str(chosen_deck.get("name", "Traveler's Tavern Deck")), str(chosen_deck.get("name_cs", chosen_deck.get("name", "Poutníkův balíček"))))
	if tutorial_mode:
		_deal_tutorial_round()
		_update_tutorial_callout_ui(0, true)
		table_status_label3d.text = ""
	else:
		_deal_new_3d_round()
		table_status_label3d.text = _get_stage_name_loc()
	_update_combo_hud(_tr("SCORE = CARD × COUNT", "SKÓRE = KARTA × POČET"), 0, 1.0, 0, false)

	# Apply tutorial vs real duel node/HUD visibility right away so ghost/panels never leak into a fresh battle
	intro_animating = true
	busy_animating = true
	_apply_staged_tutorial_state(tutorial_step if tutorial_mode else 8, false)

	# Cinematic entrance: player steps into the storm-lit tavern & sits at the table
	prev_hovered_idx = -1
	cam_kick_shake = 0.0
	cam.fov = 72.0
	cam.position = Vector3(-0.82, 2.38, 3.05)
	cam.rotation_degrees = Vector3(-16.0, 22.0, 0.0)
	player_hand_anchor.position = HAND_POS_TUCKED + Vector3(0.0, -0.32, 0.16)
	emit_signal("play_sfx_requested", "card_shuffle")

	if intro_title_grp and intro_title_lbl:
		intro_title_lbl.text = _tr("LIALO — LEARN TO PLAY", "LIALO — ZÁKLADY HRY") if tutorial_mode else _tr("%s\nDeck: %s  •  Goal: %d pts | 10 ♥ HP", "%s\nBalíček: %s  •  Cíl: %d b | 10 ♥ HP") % [str(era.get("boss", "Tavern Duel")), deck_lbl, target_score]
		intro_title_grp.visible = true
		intro_title_grp.modulate.a = 0.0
		var b_tw := create_tween()
		b_tw.tween_property(intro_title_grp, "modulate:a", 1.0, 0.22)
		b_tw.tween_interval(0.62)
		b_tw.tween_property(intro_title_grp, "modulate:a", 0.0, 0.24)
		b_tw.tween_callback(func():
			if intro_title_grp:
				intro_title_grp.visible = false
		)

	if intro_seq_tween and intro_seq_tween.is_valid():
		intro_seq_tween.kill()
	intro_seq_tween = create_tween()
	var intro_tw := intro_seq_tween
	intro_tw.set_parallel(true)
	table_status_label3d.visible = false
	var target_intro_cam := Vector3(-0.32, 1.50, 0.76) if tutorial_mode else Vector3(0.0, 1.72, 1.48)
	var target_intro_rot := Vector3(1.0, 44.0, 0.0) if tutorial_mode else Vector3(base_cam_rot.x - 2.0, 0.0, 0.0)
	intro_tw.tween_property(cam, "position", target_intro_cam, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(cam, "rotation_degrees", target_intro_rot, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var end_hand_pos := HAND_POS_TUCKED if (cards_tucked or tutorial_mode) else HAND_POS_UP
	intro_tw.tween_property(player_hand_anchor, "position", end_hand_pos, 0.95).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_tw.chain().tween_callback(func():
		var was_natural_intro := intro_animating
		intro_animating = false
		busy_animating = false
		table_status_label3d.visible = not tutorial_mode
		if is_instance_valid(magic_puf_bottle):
			magic_puf_bottle.set_meta("base_pos", magic_puf_bottle.position)
		if is_instance_valid(player_sword_root):
			player_sword_root.set_meta("base_pos", player_sword_root.position)
		_apply_staged_tutorial_state(tutorial_step if tutorial_mode else 8, false)
		_rebuild_all_3d_hands()
		_refresh_table_labels()
		emit_signal("play_sfx_requested", "turn_player")
		if was_natural_intro and not tutorial_mode:
			_begin_player_item_review_stage(true)
			_play_table_items_intro_showcase()
			_check_battle_unlock_tips()
			_check_campaign_micro_tutorial()
	)

func _check_campaign_micro_tutorial() -> void:
	if tutorial_mode or active_run_profile.is_empty():
		return
	var stage_i := int(active_stage_data.get("stage_idx", 0))
	if stage_i > 1:
		return
	var e_id := str(active_era.get("id", ""))
	if e_id == "" or Catalog.has_completed_micro_tutorial(active_run_profile, e_id):
		return
	var tip: Dictionary = StoryData.get_era_micro_tutorial(e_id)
	if tip.is_empty():
		return
	Catalog.mark_micro_tutorial_completed(active_run_profile, e_id)
	Catalog.save_profile(active_run_profile)
	var title_t := str(tip.get("title_cs" if opts_language == "cs" else "title_en", "SPIRKO TIP"))
	var body_t := str(tip.get("body_cs" if opts_language == "cs" else "body_en", ""))
	_flash_turn_toast(title_t, body_t, Color(0.45, 0.94, 1.0), 4.6, true)
	if combat_log_drawer != null:
		combat_log_drawer.add_entry("%s — %s" % [title_t, body_t], Color(0.45, 0.94, 1.0))

func _check_boss_phase_awakening() -> void:
	if tutorial_mode or not is_inside_tree():
		return
	var stage_i := int(active_stage_data.get("stage_idx", 0))
	if stage_i < 2:
		return
	var e_id := str(active_era.get("id", ""))
	var bp_info: Dictionary = StoryData.get_boss_phase_info(e_id)
	if bp_info.is_empty():
		return
	var hp_ratio := float(ai_hp) / float(maxi(1, ai_max_hp))
	var sc_ratio := float(ai_score) / float(maxi(1, target_score))
	if boss_phase == 1 and (hp_ratio <= float(bp_info.get("phase2_hp_ratio", 0.50)) or sc_ratio >= float(bp_info.get("phase2_score_ratio", 0.60))):
		boss_phase = 2
		var p2_title := str(bp_info.get("phase2_title_cs" if opts_language == "cs" else "phase2_title_en", "BOSS PHASE 2!"))
		var p2_desc := str(bp_info.get("phase2_desc_cs" if opts_language == "cs" else "phase2_desc_en", ""))
		_flash_turn_toast(p2_title, p2_desc, Color(1.0, 0.42, 0.24), 3.4, true)
		_trigger_boss_modifier_flare(p2_title)
		cam_kick_shake = maxf(cam_kick_shake, 0.65)
		if combat_log_drawer != null:
			combat_log_drawer.add_entry("%s — %s" % [p2_title, p2_desc], Color(1.0, 0.48, 0.28))
		match e_id:
			"antika":
				var candidates: Array[String] = []
				for su in SUITS:
					var sid := str(su["id"])
					if sid != active_suit_id:
						candidates.append(sid)
				if not candidates.is_empty():
					sealed_suit_id = candidates[randi() % candidates.size()]
					sealed_suit_turns = 1
			"rim":
				ai_shields += 2
				_sync_heartbeat_hp_displays(true)
			"stredovek":
				ai_shields += 2
				var best_k := ""
				var best_pts := -1
				for hc in player_hand:
					if int(hc.get("pts", 0)) > best_pts:
						best_pts = int(hc.get("pts", 0))
						best_k = "%s_%s" % [str(hc.get("suit", "")), str(hc.get("rank", ""))]
				stamped_card_key = best_k
				_sync_heartbeat_hp_displays(true)
			"objavy":
				shifting_winds_active = true
			"prohibicia":
				ai_score += 15
				display_ai_score = float(ai_score)
				var is_hl := (DisplayServer.get_name() == "headless") or ("--script" in OS.get_cmdline_args())
				if not is_hl:
					if _mid_comic_layer == null:
						_mid_comic_layer = CanvasLayer.new()
						_mid_comic_layer.layer = 27
						add_child(_mid_comic_layer)
					var flash_cp := ComicPlayerScript.new()
					_mid_comic_layer.add_child(flash_cp)
					flash_cp.scene_finished.connect(func(_sid: String):
						if is_instance_valid(flash_cp):
							flash_cp.queue_free()
					)
					flash_cp.play_scene("COMIC_CAPONE_PHASE2", opts_language, true, true)
	elif e_id == "prohibicia" and boss_phase == 2 and (ai_hp <= 2 or sc_ratio >= 0.85):
		boss_phase = 3
		overdrive_light_target = maxf(overdrive_light_target, 1.55)
		var p3_title := str(bp_info.get("phase3_title_cs" if opts_language == "cs" else "phase3_title_en", "FINAL CLIMAX!"))
		var p3_desc := str(bp_info.get("phase3_desc_cs" if opts_language == "cs" else "phase3_desc_en", ""))
		_flash_turn_toast(p3_title, p3_desc, Color(1.0, 0.88, 0.34), 3.6, true)
		cam_kick_shake = maxf(cam_kick_shake, 0.80)
		if bankai_charged.size() < bankai_combo.size():
			for bk in bankai_combo:
				if not (bk in bankai_charged):
					bankai_charged.append(bk)
					break
			_refresh_bankai_seal_hud()
		if combat_log_drawer != null:
			combat_log_drawer.add_entry("%s — %s" % [p3_title, p3_desc], Color(1.0, 0.88, 0.34))

var _tutorial_action_done: String = ""

func _refresh_suit_modal_labels() -> void:
	if suit_modal_title_lbl:
		suit_modal_title_lbl.text = _tr("✦ QUEEN — CHOOSE SUIT ✦", "✦ SVRŠEK — ZVOL BARVU ✦")
	if is_instance_valid(suit_modal):
		var cbtn := suit_modal.find_child("SuitModalCancelBtn", true, false) as Button
		if cbtn:
			cbtn.text = _tr("Cancel [ESC]", "Zrušit [ESC]")
	for s in SUITS:
		var sid := str(s["id"])
		if suit_modal_btn_lbls.has(sid):
			var blbl := suit_modal_btn_lbls[sid] as Label
			if is_instance_valid(blbl):
				blbl.text = "%s %s" % [_tr(str(s["name"]), str(s.get("name_cs", s["name"]))), str(s["sym"])]

func _perform_opening_veto_hand() -> void:
	var allow_in_tut := (tutorial_mode and tutorial_step == 1 and tutorial_substep == 0)
	if (tutorial_mode and not allow_in_tut) or busy_animating or not is_player_turn or opening_turn_committed or opening_veto_used:
		return
	opening_veto_used = true
	staged_card_indices.clear()
	if allow_in_tut:
		_deal_tutorial_scripted_hand_after_veto()
		tutorial_substep = 1
		emit_signal("play_sfx_requested", "card_shuffle")
		_spawn_score_popup(_tr("VETO! NEW OPENING DEAL!", "VETO! NOVÉ ÚVODNÍ KARTY!"), Color(0.54, 0.94, 1.0), true)
		_trigger_ghost_ok_flash()
		_update_tutorial_callout_ui(1, true)
		_refresh_table_labels()
		return
	for hc in player_hand:
		deck.push_front(hc)
	player_hand.clear()
	var old_top: Variant = discard_pile.pop_back() if not discard_pile.is_empty() else null
	if old_top is Dictionary:
		deck.push_front(old_top)
	for c in discard_pile_root.get_children():
		if not (c is Area3D):
			c.queue_free()
	deck.shuffle()
	var deal_cnt := 5 + int(player_deck_data.get("extra_draw", 0))
	for _i in range(deal_cnt):
		if not deck.is_empty():
			player_hand.append(_draw_from_deck())
	var first := _draw_from_deck()
	first["_mist_hidden"] = false
	discard_pile.append(first)
	active_suit_id = str(first.get("suit", "CERVEN"))
	_add_card_mesh_to_discard_pile(first)
	emit_signal("play_sfx_requested", "card_shuffle")
	_spawn_score_popup(_tr("VETO! NEW OPENING DEAL!", "VETO! NOVÉ ÚVODNÍ KARTY!"), Color(0.54, 0.94, 1.0), true)
	table_status_label3d.text = _tr("Opening hand vetoed — fresh 5 cards dealt!", "Úvodní ruka vetována — rozdáno 5 nových karet!")
	_rebuild_all_3d_hands()
	_animate_deal_pop_in()
	_refresh_table_labels()
	if not tutorial_mode:
		_check_battle_unlock_tips()

func _perform_opening_veto_duel() -> void:
	if tutorial_mode:
		_whisper_tutorial_nudge(_tr("Veto Game safely returns you to the map in campaign. For now, click Veto Hand [V]!", "Vetovat hru tě v kampani bezpečně vrátí na mapu. Teď klikni na Vetovat karty [V]!"))
		return
	if busy_animating or opening_turn_committed:
		return
	_cancel_active_cinematic()
	emit_signal("play_sfx_requested", "ui_click")
	_spawn_score_popup(_tr("DUEL VETOED!", "HRA VETOVÁNA!"), Color(1.0, 0.72, 0.42), true)
	emit_signal("exit_to_map_requested")

func _make_card_dict(s_id: String, r_id: String) -> Dictionary:
	for r in RANKS:
		if r["id"] == r_id:
			return {"suit": s_id, "rank": r_id, "pts": r["pts"], "rname": _get_rank_name(r_id)}
	return {"suit": s_id, "rank": "8", "pts": 8, "rname": _get_rank_name("8")}

func _deal_tutorial_pre_veto_hand() -> void:
	player_hand = [
		_make_card_dict("ZELEN", "9"),
		_make_card_dict("ZALUD", "D"),
		_make_card_dict("GULA", "9"),
		_make_card_dict("ZELEN", "10"),
		_make_card_dict("ZALUD", "10"),
	]

func _deal_tutorial_scripted_hand_after_veto() -> void:
	player_hand = [
		_make_card_dict("CERVEN", "10"),
		_make_card_dict("CERVEN", "H"),
		_make_card_dict("CERVEN", "7"),
		_make_card_dict("CERVEN", "8"),
		_make_card_dict("ZELEN", "8"),
	]
	_rebuild_all_3d_hands()
	_animate_deal_pop_in()

func _deal_tutorial_round() -> void:
	deck.clear()
	discard_pile.clear()
	player_hand.clear()
	ai_hand.clear()
	staged_card_indices.clear()
	for c in discard_pile_root.get_children():
		if not (c is Area3D):
			c.queue_free()

	# Pre-veto starter hand for Step 1a; Veto [V] deals the scripted combo hand
	_deal_tutorial_pre_veto_hand()
	ai_hand = [
		_make_card_dict("ZALUD", "8"),
		_make_card_dict("GULA", "9"),
		_make_card_dict("ZELEN", "10"),
		_make_card_dict("ZALUD", "K"),
		_make_card_dict("GULA", "K")
	]
	var first := _make_card_dict("CERVEN", "9")
	discard_pile.append(first)
	active_suit_id = "CERVEN"
	_add_card_mesh_to_discard_pile(first)

	var reserved := ["CERVEN_8", "CERVEN_10", "ZELEN_8", "CERVEN_7", "CERVEN_H",
		"ZALUD_8", "GULA_9", "ZELEN_10", "ZALUD_K", "GULA_K", "CERVEN_9", "ZELEN_7", "GULA_8"]
	for s in SUITS:
		for r in RANKS:
			var k: String = "%s_%s" % [s["id"], r["id"]]
			if not (k in reserved):
				deck.append({"suit": s["id"], "rank": r["id"], "pts": r["pts"], "rname": r["name"]})
	deck.shuffle()
	# Place ♥10 & ♦8 on top of draw deck so Step 1 draw creates instant 10-pair option too
	deck.append(_make_card_dict("GULA", "8"))
	deck.append(_make_card_dict("CERVEN", "10"))

	_rebuild_all_3d_hands()
	_animate_deal_pop_in()
	_refresh_table_labels()
	if not tutorial_mode:
		_check_battle_unlock_tips()

func set_duel_wager(w_type: String, silent: bool = false) -> void:
	if w_type == "GOLD" and player_available_gold < wager_gold_amount and not tutorial_mode:
		w_type = "SWORD"
		if not silent:
			table_status_label3d.text = _tr("No Florins left — Blood Oath: Your Sword is on the line!", "Dochází zlato — Krvavá přísaha: Sázíš svůj meč!")
	active_wager_type = w_type
	if wager_gold_btn:
		var can_gold := (player_available_gold >= wager_gold_amount) or tutorial_mode
		wager_gold_btn.text = _tr("Bet %dg", "Sázka %dg") % wager_gold_amount if can_gold else "0g"
		var g_sel := (active_wager_type == "GOLD")
		wager_gold_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.48) if g_sel else (Color(0.84, 0.76, 0.60) if can_gold else Color(0.45, 0.40, 0.38)))
		_style_action_button(wager_gold_btn, Color(0.28, 0.19, 0.07, 0.96) if g_sel else Color(0.08, 0.06, 0.05, 0.88), Color(1.0, 0.84, 0.30) if g_sel else Color(0.52, 0.40, 0.22), 14)
	if wager_item_btn:
		var i_sel := (active_wager_type == "ITEM")
		wager_item_btn.text = _tr("Bet Phial", "Sázka Baňka")
		wager_item_btn.add_theme_color_override("font_color", Color(0.90, 0.72, 1.0) if i_sel else Color(0.78, 0.74, 0.82))
		_style_action_button(wager_item_btn, Color(0.22, 0.10, 0.32, 0.96) if i_sel else Color(0.08, 0.06, 0.08, 0.88), Color(0.84, 0.52, 1.0) if i_sel else Color(0.46, 0.32, 0.56), 14)
	if wager_sword_btn:
		var s_sel := (active_wager_type == "SWORD")
		wager_sword_btn.text = _tr("Bet Sword", "Sázka Meč")
		wager_sword_btn.add_theme_color_override("font_color", Color(1.0, 0.48, 0.42) if s_sel else Color(0.90, 0.70, 0.62))
		_style_action_button(wager_sword_btn, Color(0.32, 0.08, 0.08, 0.96) if s_sel else Color(0.08, 0.05, 0.05, 0.88), Color(1.0, 0.32, 0.26) if s_sel else Color(0.56, 0.26, 0.24), 14)
	if wager_veto_hand_btn:
		wager_veto_hand_btn.text = _tr("Veto Hand [V]", "Vetovat karty [V]") if not opening_veto_used else _tr("Vetoed", "Vetováno")
		wager_veto_hand_btn.disabled = opening_veto_used or opening_turn_committed
	if wager_veto_duel_btn:
		wager_veto_duel_btn.text = _tr("Veto Game", "Vetovat hru")
		wager_veto_duel_btn.disabled = opening_turn_committed

	if is_instance_valid(player_sword_root):
		if active_wager_type == "SWORD":
			player_sword_root.position = Vector3(-0.56, 0.824, 0.44)
			player_sword_root.rotation_degrees = Vector3(0.0, 82.0, 0.0)
			player_sword_root.set_meta("base_pos", player_sword_root.position)
			if is_instance_valid(wager_3d_ring):
				wager_3d_ring.visible = true
				wager_3d_ring.position = Vector3(-0.56, 0.822, 0.44)
				if wager_3d_ring.material_override is ShaderMaterial:
					(wager_3d_ring.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(1.0, 0.24, 0.20, 0.86))
				elif wager_3d_ring.material_override is StandardMaterial3D:
					(wager_3d_ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.24, 0.20, 0.82)
			if not silent:
				Fx.ring(self, to_global(Vector3(-0.56, 0.822, 0.44)), Color(1.0, 0.24, 0.18), 0.38, 0.45, 0.09, 2.2, 8.0)
				table_status_label3d.text = _tr("BLOOD OATH: Sword staked!", "KRVAVÁ PŘÍSAHA: Vsazen meč!")
		else:
			player_sword_root.position = Vector3(1.02, 0.822, 0.22)
			player_sword_root.rotation_degrees = Vector3(0.0, 16.0, 0.0)
			player_sword_root.set_meta("base_pos", player_sword_root.position)
			if is_instance_valid(wager_3d_ring):
				wager_3d_ring.visible = (active_wager_type == "GOLD")
				wager_3d_ring.position = Vector3(-0.24, 0.822, -0.34)
				if wager_3d_ring.material_override is ShaderMaterial:
					(wager_3d_ring.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(1.0, 0.84, 0.24, 0.72))
				elif wager_3d_ring.material_override is StandardMaterial3D:
					(wager_3d_ring.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.84, 0.24, 0.65)
			if not silent:
				table_status_label3d.text = _tr("Coin Wager (%dg) staked!" % wager_gold_amount, "Sázka mincí (%dg)!") if active_wager_type == "GOLD" else _tr("Phial Wager staked!", "Vsazena baňka IGNIS!")
	_refresh_wager_indicator_ui()
	if not silent:
		_refresh_table_labels()

func _draw_tutorial_ghost_callout(ctrl: Control) -> void:
	var sz := ctrl.size
	var t := Time.get_ticks_msec() * 0.001
	var acc := tutorial_ghost_accent

	# 1. Farebný ručne kreslený pergamenovo-atramentový podklad (Colorful Hand-Inked Storybook Panel)
	var r := Rect2(Vector2.ZERO, sz)
	ctrl.draw_rect(r, Color(0.06, 0.07, 0.12, 0.92))
	ctrl.draw_rect(Rect2(4, 4, 104, sz.y - 8), Color(acc.r * 0.22, acc.g * 0.24, acc.b * 0.28, 0.65))
	ctrl.draw_rect(r.grow(-2.0), Color(acc.r, acc.g, acc.b, 0.88), false, 2.8)
	ctrl.draw_rect(r.grow(-6.0), Color(1.0, 0.92, 0.64, 0.42), false, 1.4)
	ctrl.draw_line(Vector2(108, 10), Vector2(108, sz.y - 10), Color(acc.r, acc.g, acc.b, 0.55), 2.0)

	# 2. Animovaný Duch Krčmára ("Spirko") v ľavom portrétovom okne!
	var bob_y := sin(t * 3.4) * 6.5
	var sway_x := cos(t * 2.2) * 3.0
	var gc := Vector2(56.0 + sway_x, 86.0 + bob_y)

	# Svetelná ektoplazmová aura za duchom
	ctrl.draw_circle(gc + Vector2(0, -6), 42.0 + sin(t * 4.0) * 3.0, Color(acc.r, acc.g, acc.b, 0.18))
	ctrl.draw_circle(gc + Vector2(0, -6), 30.0, Color(acc.r, acc.g, acc.b, 0.28))

	# Vlajúci plášť ducha so zvlneným spodným lemom
	var ghost_poly := PackedVector2Array([
		gc + Vector2(-24, -14),
		gc + Vector2(-18, -32),
		gc + Vector2(0, -38),
		gc + Vector2(18, -32),
		gc + Vector2(24, -14),
		gc + Vector2(26, 22 + sin(t * 5.5) * 4.0),
		gc + Vector2(13, 15 + cos(t * 5.5 + 1.0) * 4.0),
		gc + Vector2(0, 25 + sin(t * 5.5 + 2.0) * 4.5),
		gc + Vector2(-13, 15 + cos(t * 5.5 + 3.0) * 4.0),
		gc + Vector2(-26, 22 + sin(t * 5.5 + 4.0) * 4.0),
	])
	var ghost_fill := Color(0.84, 0.98, 1.0, 0.92).lerp(Color(acc.r, acc.g, acc.b, 0.94), 0.28)
	ctrl.draw_colored_polygon(ghost_poly, ghost_fill)
	ctrl.draw_polyline(ghost_poly + PackedVector2Array([ghost_poly[0]]), Color(0.10, 0.14, 0.22, 0.95), 2.4)

	# Klobúčik krčmára / mága na hlave ducha
	var hat_poly := PackedVector2Array([
		gc + Vector2(-26, -28),
		gc + Vector2(0, -56 + sin(t * 4.2) * 2.5),
		gc + Vector2(26, -28),
	])
	ctrl.draw_colored_polygon(hat_poly, Color(0.24, 0.16, 0.42, 0.95))
	ctrl.draw_polyline(hat_poly + PackedVector2Array([hat_poly[0]]), Color(0.96, 0.80, 0.32, 0.92), 2.0)

	# Žiariace žmurkajúce oči a veselý úsmev
	var blink := 0.15 if fmod(t, 3.4) > 3.22 else 1.0
	for ex in [-9.0, 9.0]:
		ctrl.draw_circle(gc + Vector2(ex, -16.0), 4.6 * blink, Color(0.08, 0.10, 0.16, 0.95))
		if blink > 0.5:
			ctrl.draw_circle(gc + Vector2(ex - 1.2, -17.5), 1.8, Color(1.0, 0.98, 0.72, 0.98))
	ctrl.draw_arc(gc + Vector2(0, -8.0), 7.5, 0.15 * PI, 0.85 * PI, 12, Color(0.10, 0.14, 0.22, 0.92), 2.2)

	# Mávajúca rúčka s malým zlatým lampášikom
	var lantern_p := gc + Vector2(30.0, -4.0 + sin(t * 6.0) * 4.0)
	ctrl.draw_line(gc + Vector2(20.0, -8.0), lantern_p, Color(0.12, 0.14, 0.20, 0.90), 2.2)
	ctrl.draw_circle(lantern_p + Vector2(0, 7.0), 11.0, Color(1.0, 0.82, 0.28, 0.35))
	ctrl.draw_circle(lantern_p + Vector2(0, 7.0), 5.0, Color(1.0, 0.94, 0.58, 0.96))

	# Vznášajúce sa farebné iskričky okolo ducha
	for mi in range(6):
		var mx := 16.0 + fmod(float(mi) * 19.0 + sin(t * 2.4 + float(mi)) * 8.0, 84.0)
		var my := 18.0 + fmod(float(mi) * 23.0 - t * 22.0, sz.y - 32.0)
		if my < 14.0:
			my += sz.y - 32.0
		ctrl.draw_circle(Vector2(mx, my), 2.2, Color(acc.r, acc.g, acc.b, 0.78))

func _update_tutorial_callout_ui(step: int, animate_magic: bool = true) -> void:
	_apply_staged_tutorial_state(step, animate_magic)
	# NO pop-up window! Our full-sized 3D Ghost Companion speaks diegetically right next to the player!
	if tutorial_callout_grp:
		tutorial_callout_grp.visible = false
	if turn_banner_grp and step < 2:
		turn_banner_grp.visible = false
		_last_turn_toast_key = ""
	if tutorial_skip_btn:
		tutorial_skip_btn.visible = tutorial_mode
	var accent := Color(0.42, 0.96, 0.72)
	var spoken_line := ""
	match step:
		0:
			spoken_line = _tr(
				"\"Psst, friend! Pull up a chair — I'll show you how to win gold and keep your head!\"",
				"\"Psst, příteli! Sedni ke stolu — ukážu ti, jak v téhle krčmě vyhrát zlato i život!\""
			)
			accent = Color(0.56, 0.80, 0.96)
		1:
			spoken_line = _tr(
				"\"Bad opening deal? Veto it [V]! Press [TAB] to inspect 3D table items and stake your Sword!\"",
				"\"Špatné karty na startu? Vetuj je [V]! Klávesou [TAB] koukni na 3D předměty a vsaď Meč!\""
			)
			accent = Color(1.0, 0.84, 0.34)
		2:
			spoken_line = _tr(
				"\"Suit on Suit, Rank on Rank! Both turns settle together into your Charge Chalice!\"",
				"\"Barva na barvu, hodnota na hodnotu! Body obou tahů se slijí do Kalicha!\""
			)
			accent = Color(0.42, 0.96, 0.72)
		3:
			spoken_line = _tr(
				"\"Seven deals +2 cards (and 3× pts if they draw)! Queen shifts Suit and Jack grants a Shield!\"",
				"\"Sedma dává +2 karty (a 3× body, když soupeř líže)! Svršek mění barvu a Spodek dává Štít!\""
			)
			accent = Color(0.36, 0.92, 1.0)
		4:
			spoken_line = _tr(
				"\"Chain Law: Stack Eights (∞) or up to 3 Aces! Right-click [RMB] matching cards for a Combo!\"",
				"\"Zákon řetězení: Skládej Osmičky (∞) nebo až 3 Esa! Pravým klikem [RMB] postavíš kombo!\""
			)
			accent = Color(0.98, 0.52, 0.92)
		5:
			spoken_line = _tr(
				"\"Watch the 3D Hearts! As HP drops, heartbeat races & cracks glow. Beware giant Boss Hearts!\"",
				"\"Sleduj 3D Srdce! Když HP klesá, tep zrychluje a praskliny žhnou. Pozor na Boss Srdce!\""
			)
			accent = Color(1.0, 0.34, 0.38)
		6:
			spoken_line = _tr(
				"\"Special Cards trigger dramatic cutscenes, and the IGNIS Phial burns rivals for 3 rounds!\"",
				"\"Mocné karty spouští filmové cutscény a baňka IGNIS pálí soupeře na 3 kola!\""
			)
			accent = Color(1.0, 0.54, 0.22)
		_:
			spoken_line = _tr(
				"\"Empty your hand for a Finisher bonus! Duels last 6 rounds with the Shop every 3rd round!\"",
				"\"Vyhoď poslední kartu pro Finisher bonus! Zápas má 6 kol, Obchod cinkne každé 3. kolo!\""
			)
			accent = Color(1.0, 0.90, 0.42)

	tutorial_ghost_accent = accent
	if tutorial_ghost_mat:
		tutorial_ghost_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.80)
		tutorial_ghost_mat.emission = accent
	if is_instance_valid(tutorial_ghost_light):
		tutorial_ghost_light.light_color = accent
	if is_instance_valid(tutorial_ghost_3d):
		tutorial_ghost_3d.visible = true
		if animate_magic:
			Fx.burst(self, tutorial_ghost_3d.global_position + Vector3(0.0, 0.52, 0.15), accent, 18, 0.85, 0.55, 0.03, 0.4, true, 140.0)
	if is_instance_valid(tutorial_ghost_speech_3d):
		tutorial_ghost_speech_3d.visible = false
	if is_instance_valid(tutorial_ghost_speech_lbl):
		tutorial_ghost_speech_lbl.visible = false
	ghost_speech_full = spoken_line
	if animate_magic:
		ghost_speech_chars = 0.0
		if is_instance_valid(tutorial_ghost_speech_3d):
			tutorial_ghost_speech_3d.text = ""
		if is_instance_valid(tutorial_ghost_speech_lbl):
			tutorial_ghost_speech_lbl.text = ""
		emit_signal("play_sfx_pitched_requested", "ghost_speak", 1.05)
	else:
		ghost_speech_chars = float(spoken_line.length())
		if is_instance_valid(tutorial_ghost_speech_3d):
			tutorial_ghost_speech_3d.text = spoken_line
		if is_instance_valid(tutorial_ghost_speech_lbl):
			tutorial_ghost_speech_lbl.text = spoken_line

func _whisper_tutorial_nudge(msg: String) -> void:
	table_status_label3d.text = msg
	emit_signal("play_sfx_requested", "error")
	if tutorial_mode and tutorial_ghost_center_lbl:
		_start_handwriting_anim(tutorial_ghost_center_lbl, msg, 54.0, true)

func _ensure_tutorial_seven_setup() -> void:
	# Strip any 7 from AI hand during Step 2 so AI genuinely fails to block & draws +2!
	for ai_i in range(ai_hand.size()):
		if str(ai_hand[ai_i].get("rank", "")) == "7":
			var safe_s := str(ai_hand[ai_i].get("suit", "GULA"))
			ai_hand[ai_i] = _make_card_dict(safe_s, "9")
	if ai_hand.is_empty():
		ai_hand.append(_make_card_dict("GULA", "9"))
	for c in player_hand:
		if str(c.get("rank", "")) == "7" and _can_play(c):
			return
	var top_r := str(discard_pile.back().get("rank", "9")) if not discard_pile.is_empty() else "9"
	var use_s := active_suit_id if top_r != "7" else "CERVEN"
	player_hand.append(_make_card_dict(use_s, "7"))

func _setup_tutorial_final_round() -> void:
	# Clean 3-card solvable hand so player can win 1 full Prší Round by reaching 0 cards!
	pending_draw = 0
	pending_skip = false
	pending_skip_turns = 0
	pending_king_challenge.clear()
	staged_card_indices.clear()
	player_hand.clear()
	var s_now := active_suit_id if active_suit_id != "" else "CERVEN"
	var alt_s := "ZELEN" if s_now != "ZELEN" else "GULA"
	player_hand.append(_make_card_dict(s_now, "10"))
	player_hand.append(_make_card_dict(s_now, "E"))
	player_hand.append(_make_card_dict(alt_s, "E"))
	# Gentle AI hand so final tutorial round stays fair & quick
	ai_hand = [
		_make_card_dict("ZALUD", "9"),
		_make_card_dict("GULA", "D"),
		_make_card_dict("ZELEN", "10"),
		_make_card_dict("ZALUD", "K"),
	]

func _reveal_points_and_score_magic() -> void:
	cards_points_revealed = true
	hud_score_revealed = true
	emit_signal("play_sfx_pitched_requested", "turn_player", 1.25)

	if player_score_lbl:
		player_score_lbl.visible = true
		player_score_lbl.scale = Vector2(0.4, 0.4)
		player_score_lbl.pivot_offset = player_score_lbl.size * 0.5
		var ptw := create_tween()
		ptw.tween_property(player_score_lbl, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_spawn_hud_sparkles(player_score_lbl.global_position + player_score_lbl.size * 0.5, Color(1.0, 0.88, 0.34), 20)
	if ai_score_lbl:
		ai_score_lbl.visible = true
		ai_score_lbl.scale = Vector2(0.4, 0.4)
		ai_score_lbl.pivot_offset = ai_score_lbl.size * 0.5
		var atw := create_tween()
		atw.tween_property(ai_score_lbl, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_spawn_hud_sparkles(ai_score_lbl.global_position + ai_score_lbl.size * 0.5, Color(1.0, 0.45, 0.48), 16)
	if player_liquid_bar:
		player_liquid_bar.queue_redraw()
	if ai_liquid_bar:
		ai_liquid_bar.queue_redraw()

	# Magically materialize +XX pts on every 3D card with ascending pitched chimes
	for i in range(player_card_nodes.size()):
		var c_node := player_card_nodes[i]
		if not is_instance_valid(c_node):
			continue
		var pl := c_node.get_node_or_null("PtsLabel") as Label3D
		if pl:
			pl.visible = true
			pl.scale = Vector3(0.05, 0.05, 0.05)
			var tw := pl.create_tween()
			tw.tween_interval(0.07 * float(i))
			tw.tween_callback(func():
				if is_instance_valid(c_node) and cam:
					var sp := cam.unproject_position(c_node.global_position)
					_spawn_hud_sparkles(sp, Color(1.0, 0.86, 0.32), 10)
					emit_signal("play_sfx_pitched_requested", "card_hover", 1.05 + float(i) * 0.12)
			)
			tw.tween_property(pl, "scale", Vector3(1.55, 1.55, 1.55), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(pl, "scale", Vector3.ONE, 0.16)

	for dc in discard_pile_root.get_children():
		var dpl := dc.get_node_or_null("PtsLabel") as Label3D
		if dpl:
			dpl.visible = true
			dpl.scale = Vector3(0.1, 0.1, 0.1)
			var dtw := dpl.create_tween()
			dtw.tween_property(dpl, "scale", Vector3.ONE, 0.30).set_trans(Tween.TRANS_BACK)

func _ensure_tutorial_special_card() -> void:
	_ensure_tutorial_seven_setup()

func _reveal_abilities_magic() -> void:
	abilities_revealed = true
	_ensure_tutorial_special_card()
	_rebuild_all_3d_hands()
	emit_signal("play_sfx_pitched_requested", "turn_player", 1.38)
	for i in range(player_card_nodes.size()):
		var c_node := player_card_nodes[i]
		if not is_instance_valid(c_node):
			continue
		var pm := c_node.get_node_or_null("AbilityPillMesh") as MeshInstance3D
		if pm:
			pm.visible = true
		var ab := c_node.get_node_or_null("AbilityLabel") as Label3D
		if ab:
			ab.visible = true
			ab.scale = Vector3(0.08, 0.08, 0.08)
			var tw := ab.create_tween()
			tw.tween_interval(0.06 * float(i))
			tw.tween_callback(func():
				if is_instance_valid(c_node) and cam:
					_spawn_hud_sparkles(cam.unproject_position(c_node.global_position), Color(0.36, 0.94, 1.0), 12)
			)
			tw.tween_property(ab, "scale", Vector3(1.5, 1.5, 1.5), 0.18).set_trans(Tween.TRANS_BACK)
			tw.tween_property(ab, "scale", Vector3.ONE, 0.16)

func _ensure_tutorial_combo_pair() -> void:
	# ONLY 8s can be stacked! Guarantee at least 2 Eights ("8") in hand with one matching active_suit_id
	var eight_cnt := 0
	var eight_playable := false
	for c in player_hand:
		if str(c["rank"]) == "8":
			eight_cnt += 1
			if _can_play(c):
				eight_playable = true
	if eight_cnt >= 2 and eight_playable:
		return
	var other_suit := "ZELEN" if active_suit_id != "ZELEN" else "CERVEN"
	player_hand.append(_make_card_dict(active_suit_id, "8"))
	if eight_cnt == 0:
		player_hand.append(_make_card_dict(other_suit, "8"))

func _reveal_combo_hud_magic() -> void:
	hud_combo_revealed = true
	_ensure_tutorial_combo_pair()
	_rebuild_all_3d_hands()
	if combo_hud_grp:
		combo_hud_grp.visible = true
		combo_hud_grp.pivot_offset = combo_hud_grp.size * 0.5
		combo_hud_grp.scale = Vector2(0.35, 0.35)
		combo_hud_grp.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(combo_hud_grp, "scale", Vector2.ONE, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(combo_hud_grp, "modulate:a", 1.0, 0.28)
		_spawn_hud_sparkles(combo_hud_grp.global_position + combo_hud_grp.size * 0.5, Color(1.0, 0.72, 0.24), 24)
	emit_signal("play_sfx_pitched_requested", "turn_player", 1.48)

func _reveal_puf_bottle_magic() -> void:
	puf_revealed = true
	if wager_bar_panel:
		wager_bar_panel.visible = false
	player_score = maxi(player_score, 25)
	puf_charges = maxi(puf_charges, 1)
	if magic_puf_bottle:
		var coaster_pos := Vector3(0.76, 0.815, 0.34)
		magic_puf_bottle.position = coaster_pos
		magic_puf_bottle.rotation_degrees = Vector3(0, -180, 0)
		magic_puf_bottle.scale = Vector3(0.05, 0.05, 0.05)
		magic_puf_bottle.visible = true
		var tw := create_tween().set_parallel(true)
		tw.tween_property(magic_puf_bottle, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(magic_puf_bottle, "rotation_degrees:y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_spawn_impact_shockwave(magic_puf_bottle.global_position, Color(0.76, 0.40, 1.0), 2.8)
		if cam:
			_spawn_hud_sparkles(cam.unproject_position(magic_puf_bottle.global_position), Color(0.78, 0.42, 1.0), 22)
	emit_signal("play_sfx_pitched_requested", "puf", 1.28)

func _setup_tutorial_hearts_and_aces_step() -> void:
	pending_draw = 0
	pending_skip = false
	pending_skip_turns = 0
	pending_king_challenge.clear()
	staged_card_indices.clear()
	var s_now := active_suit_id if active_suit_id != "" else "CERVEN"
	var alt_s := "ZELEN" if s_now != "ZELEN" else "GULA"
	player_hand = [
		_make_card_dict(s_now, "E"),
		_make_card_dict(alt_s, "E"),
		_make_card_dict("CERVEN", "10"),
	]
	ai_hand = [
		_make_card_dict("ZALUD", "9"),
		_make_card_dict("GULA", "D"),
		_make_card_dict("ZELEN", "10"),
	]
	# Show Rival King strike (-2 HP to player) & short Boss Heart preview
	player_hp = 8
	ai_hp = 10
	if is_instance_valid(player_hp_heart):
		player_hp_heart.call("set_hp", player_hp, player_max_hp, true)
		player_hp_heart.call("trigger_damage_pulse", 2)
	if is_instance_valid(rival_hp_heart):
		rival_hp_heart.call("set_hp", ai_hp, ai_max_hp, false)
	_preview_tutorial_boss_heart()

func _preview_tutorial_boss_heart() -> void:
	if not is_instance_valid(rival_hp_heart):
		return
	rival_hp_heart.call("set_boss_mode", true, Color(1.0, 0.72, 0.24))
	var my_sess := _battle_session_token
	get_tree().create_timer(_pace(2.2)).timeout.connect(func():
		if my_sess == _battle_session_token and is_instance_valid(rival_hp_heart) and tutorial_mode:
			rival_hp_heart.call("set_boss_mode", false)
	)

func _setup_tutorial_special_and_phial_step() -> void:
	pending_draw = 0
	pending_skip = false
	pending_skip_turns = 0
	pending_king_challenge.clear()
	staged_card_indices.clear()
	var p_data := Catalog.get_power_card_loc("SPEC_VAMPIRE", opts_language)
	var use_suit := active_suit_id if active_suit_id != "" else "CERVEN"
	var spec_card := {
		"suit": use_suit,
		"rank": "PWR",
		"pts": int(p_data.get("pts", 22)),
		"rname": str(p_data.get("name", "Vampire Leech")),
		"short": str(p_data.get("short", "LEECH")),
		"power_id": "SPEC_VAMPIRE",
		"wild": true,
		"accent": p_data.get("accent", Color(0.92, 0.16, 0.26)),
		"power_line": str(p_data.get("power_line", "Drain 15 pts from Rival")),
		"desc": str(p_data.get("desc", "Steals 15 pts from Rival.")),
		"edition": "NORMAL",
		"mage_charge": 0,
	}
	player_hand = [
		spec_card,
		_make_card_dict(use_suit, "10"),
	]

func _setup_tutorial_final_shed_card() -> void:
	pending_draw = 0
	pending_skip = false
	pending_skip_turns = 0
	pending_king_challenge.clear()
	staged_card_indices.clear()
	var s_now := active_suit_id if active_suit_id != "" else "CERVEN"
	player_hand = [
		_make_card_dict(s_now, "10"),
	]

func _advance_tutorial_to(next_step: int) -> void:
	if stagger_callout_pill:
		stagger_callout_pill.visible = false
	tutorial_step = next_step
	tutorial_substep = 0
	_tutorial_action_done = ""
	staged_card_indices.clear()
	if next_step == 1:
		set_camera_view_mode(CameraViewMode.CARDS, false)
		_deal_tutorial_pre_veto_hand()
		_rebuild_all_3d_hands()
		_animate_hand_return_wave()
	elif next_step == 2:
		set_camera_view_mode(CameraViewMode.CARDS, false)
		cards_points_revealed = true
		hud_score_revealed = true
		_reveal_points_and_score_magic()
		_rebuild_all_3d_hands()
	elif next_step == 3:
		set_camera_view_mode(CameraViewMode.CARDS, false)
		cards_points_revealed = true
		abilities_revealed = true
		hud_score_revealed = true
		_ensure_tutorial_seven_setup()
		_reveal_points_and_score_magic()
		_reveal_abilities_magic()
	elif next_step == 4:
		set_camera_view_mode(CameraViewMode.CARDS, false)
		cards_points_revealed = true
		abilities_revealed = true
		hud_score_revealed = true
		hud_combo_revealed = true
		if combo_hud_grp:
			combo_hud_grp.position = Vector2(162, 68)
		_ensure_tutorial_combo_pair()
		_reveal_combo_hud_magic()
	elif next_step == 5:
		set_camera_view_mode(CameraViewMode.CARDS, false)
		cards_points_revealed = true
		abilities_revealed = true
		hud_score_revealed = true
		hud_combo_revealed = true
		_setup_tutorial_hearts_and_aces_step()
		_rebuild_all_3d_hands()
		_animate_deal_pop_in()
	elif next_step == 6:
		set_camera_view_mode(CameraViewMode.CARDS, false)
		puf_revealed = true
		_setup_tutorial_special_and_phial_step()
		_reveal_puf_bottle_magic()
		_rebuild_all_3d_hands()
		_animate_deal_pop_in()
	elif next_step == 7:
		set_camera_view_mode(CameraViewMode.CARDS, false)
		_setup_tutorial_final_shed_card()
		_rebuild_all_3d_hands()
		_animate_deal_pop_in()
	elif next_step >= 8:
		_trigger_ghost_ok_flash()
		emit_signal("play_sfx_requested", "win")
		_update_tutorial_callout_ui(8, true)
		_refresh_table_labels()
		return
	_update_tutorial_callout_ui(next_step, true)
	_refresh_table_labels()

func _skip_tutorial_immediately() -> void:
	_battle_session_token += 1
	_ai_turn_seq += 1
	_stagger_seq_token += 1
	_score_resolve_token += 1
	_cancel_active_cinematic()
	tutorial_mode = false
	tutorial_step = 8
	tutorial_substep = 0
	set_camera_view_mode(CameraViewMode.TABLE_ITEMS, false)
	_apply_staged_tutorial_state(8, false)
	cards_points_revealed = true
	abilities_revealed = true
	hud_score_revealed = true
	hud_combo_revealed = true
	puf_revealed = true
	if player_hand.is_empty() or ai_hand.is_empty():
		_deal_new_3d_round()
	if player_score_lbl:
		player_score_lbl.visible = true
	if ai_score_lbl:
		ai_score_lbl.visible = true
	if combo_hud_grp:
		combo_hud_grp.visible = true
		combo_hud_grp.position = Vector2(162, 68)
	if magic_puf_bottle:
		magic_puf_bottle.visible = true
		magic_puf_bottle.scale = Vector3.ONE
	if tutorial_ghost_center_panel:
		tutorial_ghost_center_panel.visible = false
	if tutorial_callout_grp:
		tutorial_callout_grp.visible = false
	if turn_banner_grp:
		_last_turn_toast_key = ""
	if tutorial_skip_btn:
		tutorial_skip_btn.visible = false
	if tutorial_ghost_3d:
		tutorial_ghost_3d.visible = false
	if tutorial_ghost_speech_3d:
		tutorial_ghost_speech_3d.visible = false
	if tutorial_ghost_speech_lbl:
		tutorial_ghost_speech_lbl.visible = false
	if tutorial_beacon_mesh:
		tutorial_beacon_mesh.visible = false
	_rebuild_all_3d_hands()
	_refresh_table_labels()

func _deal_new_3d_round() -> void:
	_ai_turn_seq += 1
	deck.clear()
	discard_pile.clear()
	player_hand.clear()
	ai_hand.clear()
	staged_card_indices.clear()

	for c in discard_pile_root.get_children():
		if not (c is Area3D):
			c.queue_free()

	for s in SUITS:
		for r in RANKS:
			var key: String = "%s_%s" % [s["id"], r["id"]]
			if key in run_removed_cards:
				continue
			var actual_suit: String = str(run_suit_overrides.get(key, s["id"]))
			var ed_id: String = Catalog.normalize_card_class(str(run_card_editions.get(key, "NORMAL")))
			deck.append({
				"deck_key": key,
				"suit": actual_suit, "rank": r["id"], "pts": int(r["pts"]),
				"rname": _get_rank_name(r["id"]), "edition": ed_id, "mage_charge": 0
			})

	# Inject Alchemy Cloned / Duplicated cards from Deck Sculpting
	for ac in run_added_cards:
		if not (ac is Dictionary):
			continue
		var arank := str(ac.get("rank", "E"))
		var asuit := str(ac.get("suit", "CERVEN"))
		var aed := Catalog.normalize_card_class(str(ac.get("edition", "NORMAL")))
		var apts := ScoreEng.get_base_card_chips(arank, 15)
		var rname := _get_rank_name(arank)
		deck.append({
			"deck_key": str(ac.get("source_key", "%s_%s" % [asuit, arank])),
			"suit": asuit, "rank": arank, "pts": apts,
			"rname": rname, "edition": aed, "mage_charge": 0
		})

	# Inject unlocked Custom Power Cards into the shared/player draw pool!
	var injected_powers: Array[Dictionary] = []
	for pc_id in run_custom_cards:
		var pc: Dictionary = Catalog.get_power_card_loc(str(pc_id), opts_language)
		if pc.is_empty():
			continue
		var p_pts := int(pc["pts"])
		var p_card := {
			"suit": pc["suit"],
			"rank": "PWR",
			"pts": p_pts,
			"rname": pc["name"],
			"short": pc["short"],
			"power_id": pc["id"],
			"wild": bool(pc.get("wild", false)),
			"accent": pc["accent"],
			"power_line": pc["power_line"],
			"desc": pc["desc"],
			"edition": Catalog.normalize_card_class(str(run_card_editions.get(pc["id"], "NORMAL"))),
			"mage_charge": 0,
		}
		injected_powers.append(p_card)

	deck.shuffle()

	# Deal AI cards with balanced tactical classes (Knight Mist challenges, Merchant loot, Mage, Thief!)
	var deal_cnt := 5 + int(player_deck_data.get("extra_draw", 0))
	for i in range(deal_cnt):
		var ac: Dictionary = deck.pop_back()
		if not tutorial_mode and Catalog.normalize_card_class(str(ac.get("edition", "NORMAL"))) == "NORMAL":
			if i == 0:
				ac["edition"] = "MERCHANT"
			elif i == 1:
				ac["edition"] = "KNIGHT"
			elif i == 2 and deck.size() % 2 == 0:
				ac["edition"] = "THIEF"
			elif i == 3 and randf() < 0.5:
				ac["edition"] = "MAGE"
				ac["mage_charge"] = 0
		ai_hand.append(ac)

	# Seed 1-2 injected Power Cards into player's opening draw & shuffle rest into deck
	if not injected_powers.is_empty():
		injected_powers.shuffle()
		player_hand.append(injected_powers.pop_back())
	for pc_rem in injected_powers:
		deck.append(pc_rem)
	deck.shuffle()

	while player_hand.size() < deal_cnt and not deck.is_empty():
		player_hand.append(deck.pop_back())

	# Guarantee opening discarded card is readable (prefer classic card on top)
	var first: Dictionary = deck.pop_back()
	if str(first.get("power_id", "")) != "" and not deck.is_empty():
		deck.push_front(first)
		first = deck.pop_back()
	first["_mist_hidden"] = false
	discard_pile.append(first)
	active_suit_id = first["suit"]
	_add_card_mesh_to_discard_pile(first)

	_rebuild_all_3d_hands()
	_animate_deal_pop_in()
	_refresh_table_labels()
	if not tutorial_mode:
		_check_battle_unlock_tips()

func _animate_deal_pop_in() -> void:
	for i in range(player_card_nodes.size()):
		var c_node := player_card_nodes[i]
		if not is_instance_valid(c_node):
			continue
		var target_pos: Vector3 = c_node.get_meta("base_pos")
		c_node.position = target_pos + Vector3(0.0, 0.24, -0.52)
		c_node.scale = Vector3(0.32, 0.32, 0.32)
		var delay_s := 0.22 + 0.08 * float(i)
		var tw := c_node.create_tween().set_parallel(true)
		tw.tween_property(c_node, "position", target_pos, 0.36).set_delay(delay_s).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c_node, "scale", Vector3.ONE, 0.32).set_delay(delay_s).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func(): emit_signal("play_sfx_requested", "card_deal"))

func _add_card_mesh_to_discard_pile(card_data: Dictionary) -> Node3D:
	var c_node := _build_3d_card_node(card_data, true, Color(0.85, 0.68, 0.28))
	for ch in c_node.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).material_override is StandardMaterial3D:
			var sm := (ch as MeshInstance3D).material_override as StandardMaterial3D
			if sm.emission_enabled:
				sm.emission_energy_multiplier = minf(sm.emission_energy_multiplier, 0.35)
	var stack_h := float(mini(discard_pile.size(), 8)) * 0.0045
	c_node.position = Vector3(randf_range(-0.012, 0.012), stack_h, randf_range(-0.012, 0.012))
	c_node.rotation_degrees = Vector3(-90.0, randf_range(-12.0, 12.0), 0.0)
	discard_pile_root.add_child(c_node)
	return c_node

func _rebuild_all_3d_hands() -> void:
	# 1. Player's 3D fanned cards in hand
	for n in player_card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	player_card_nodes.clear()

	# Remove out-of-bounds staged indices defensively
	var clean_staged: Array[int] = []
	for si in staged_card_indices:
		if si >= 0 and si < player_hand.size() and not (si in clean_staged):
			clean_staged.append(si)
	staged_card_indices = clean_staged

	var rank_counts := {}
	var rank_has_playable := {}
	if tutorial_mode and tutorial_step == 3:
		for c_item in player_hand:
			var r_key: String = str(c_item["rank"])
			rank_counts[r_key] = int(rank_counts.get(r_key, 0)) + 1
			if _can_play(c_item):
				rank_has_playable[r_key] = true

	var p_cnt := player_hand.size()
	var p_mid := (p_cnt - 1) * 0.5
	for i in range(p_cnt):
		var c_data: Dictionary = player_hand[i]
		var is_power := str(c_data.get("power_id", "")) != ""
		var playable := is_player_turn and not busy_animating and _can_play(c_data)
		var is_staged := i in staged_card_indices
		var can_chain := false
		if not is_staged and not staged_card_indices.is_empty():
			var base_r := _get_staged_base_rank()
			var staged_ace_cnt := 0
			for si_a in staged_card_indices:
				if si_a >= 0 and si_a < player_hand.size() and str(player_hand[si_a].get("rank", "")) == "E":
					staged_ace_cnt += 1
			if bool(c_data.get("wild", false)):
				can_chain = true
			elif base_r == "" and (str(c_data["rank"]) == "8" or str(c_data["rank"]) == "E" or is_power):
				can_chain = true
			elif base_r == "8" and str(c_data["rank"]) == "8":
				can_chain = true
			elif base_r == "E" and str(c_data["rank"]) == "E" and staged_ace_cnt < 3:
				can_chain = true
			elif base_r == "PWR" and is_power:
				can_chain = true

		var border := Color(0.24, 0.86, 0.52) if playable else Color(0.35, 0.38, 0.44)
		if is_power and playable:
			border = c_data.get("accent", Color(1.0, 0.84, 0.28))
		if tutorial_mode and is_player_turn and not busy_animating:
			var cr: String = str(c_data["rank"])
			var cpid: String = str(c_data.get("power_id", ""))
			if tutorial_step == 2 and playable and cr == "10":
				border = Color(0.32, 0.96, 0.62)
			elif tutorial_step == 3 and playable and cr == "7":
				border = Color(0.28, 0.92, 1.0)
			elif tutorial_step == 4 and staged_card_indices.is_empty():
				if cr == "8" and int(rank_counts.get("8", 0)) >= 2 and bool(rank_has_playable.get("8", false)):
					border = Color(0.32, 0.92, 1.0)
			elif tutorial_step == 5 and staged_card_indices.is_empty():
				if cr == "E":
					border = Color(1.0, 0.36, 0.42)
			elif tutorial_step == 6 and tutorial_substep == 0 and cpid == "SPEC_VAMPIRE":
				border = Color(1.0, 0.30, 0.48)
			elif tutorial_step == 7 and playable:
				border = Color(0.98, 0.78, 0.28)
		if can_chain:
			border = Color(1.0, 0.64, 0.18)
		if is_staged or reorder_src_idx == i:
			border = Color(1.0, 0.88, 0.24)

		var c_node := _build_3d_card_node(c_data, true, border)
		var step_w := clampf(0.154 - float(maxi(0, p_cnt - 5)) * 0.007, 0.118, 0.154)
		var norm := (float(i) - p_mid) / maxf(1.0, p_mid)
		var spread_x := (float(i) - p_mid) * step_w
		var arc_y := -pow(absf(float(i) - p_mid), 1.42) * 0.013 + 0.014
		var depth_z := float(i) * 0.0075 + (1.0 - absf(norm)) * 0.010
		var tilt_z := -(float(i) - p_mid) * clampf(5.0 - float(maxi(0, p_cnt - 6)) * 0.30, 3.2, 5.0)
		var tilt_y := -(float(i) - p_mid) * 1.5

		var in_combo := (is_staged and staged_card_indices.size() >= 2) or (can_chain and not staged_card_indices.is_empty())
		var is_debuffed := _is_card_debuffed_by_boss(c_data, in_combo)

		c_node.position = Vector3(spread_x, arc_y, depth_z)
		c_node.rotation_degrees = Vector3(0.0, tilt_y, tilt_z)
		c_node.set_meta("base_pos", c_node.position)
		c_node.set_meta("base_rot", c_node.rotation_degrees)
		c_node.set_meta("is_playable", playable or can_chain)
		c_node.set_meta("is_debuffed", is_debuffed)

		var fm_init := c_node.get_node_or_null("CardFaceMesh") as MeshInstance3D
		if fm_init and fm_init.material_override is ShaderMaterial:
			(fm_init.material_override as ShaderMaterial).set_shader_parameter("debuffed", 1.0 if is_debuffed else 0.0)

		if is_staged:
			var badge_lbl := Label3D.new()
			badge_lbl.text = ""
			badge_lbl.font = _get_font(true)
			badge_lbl.modulate = Color(1.0, 0.90, 0.22)
			badge_lbl.font_size = 34
			badge_lbl.pixel_size = 0.0018
			badge_lbl.position = Vector3(0.058, 0.106, 0.005)
			c_node.add_child(badge_lbl)
		elif is_debuffed:
			var deb_lbl := Label3D.new()
			deb_lbl.name = "DebuffBadge"
			deb_lbl.text = "TAX"
			deb_lbl.font = _get_font(true)
			deb_lbl.modulate = Color(1.0, 0.34, 0.32)
			deb_lbl.outline_size = 6
			deb_lbl.font_size = 15
			deb_lbl.pixel_size = 0.0011
			deb_lbl.position = Vector3(0.0, 0.068, 0.005)
			c_node.add_child(deb_lbl)

		var area := Area3D.new()
		area.set_meta("card_index", i)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.18, 0.27, 0.025)
		col.shape = box
		area.add_child(col)
		c_node.add_child(area)

		player_hand_anchor.add_child(c_node)
		player_card_nodes.append(c_node)

	# 2. Rival's 3D cards held in shadows (or revealed face-up by Seer's Eye!)
	for n in opp_card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	opp_card_nodes.clear()

	var o_cnt := ai_hand.size()
	var o_mid := (o_cnt - 1) * 0.5
	var opp_border: Color = active_era.get("border_col", Color(0.8, 0.6, 0.2))
	var opp_back_p := _get_deck_back_tex_path(str(active_era.get("id", "")))
	var show_rival := rival_cards_revealed_turns > 0
	for i in range(o_cnt):
		var c_ai: Dictionary = ai_hand[i] if show_rival else {"suit": "CERVEN", "rank": "7", "pts": 0, "rname": ""}
		var back_node := _build_3d_card_node(c_ai, show_rival, Color(0.45, 0.96, 0.85) if show_rival else opp_border, "" if show_rival else opp_back_p)
		back_node.position = Vector3((i - o_mid) * (0.095 if show_rival else 0.066), -absf(i - o_mid) * 0.008, -i * 0.002 + 0.04)
		back_node.rotation_degrees = Vector3(16.0 if show_rival else 14.0, 0.0, -(i - o_mid) * 5.0)
		opp_hands_anchor.add_child(back_node)
		opp_card_nodes.append(back_node)

	# Position first-person gauntlets cleanly at the lower-outer edges of the card fan (zero art clipping!)
	var left_edge_x := -0.24
	var right_edge_x := 0.24
	if not player_card_nodes.is_empty():
		left_edge_x = (player_card_nodes[0].get_meta("base_pos", Vector3(-0.16, 0.0, 0.0)) as Vector3).x - 0.095
		right_edge_x = (player_card_nodes[player_card_nodes.size() - 1].get_meta("base_pos", Vector3(0.16, 0.0, 0.0)) as Vector3).x + 0.095
	left_edge_x = clampf(left_edge_x, -0.46, -0.18)
	right_edge_x = clampf(right_edge_x, 0.18, 0.46)
	player_glove_left_mesh.position = Vector3(left_edge_x, -0.114, 0.014)
	player_glove_left_mesh.rotation_degrees = Vector3(32.0, -26.0, 20.0)
	player_glove_right_mesh.position = Vector3(right_edge_x, -0.114, 0.018)
	player_glove_right_mesh.rotation_degrees = Vector3(32.0, 26.0, -20.0)
	player_glove_left_mesh.visible = not player_card_nodes.is_empty()
	player_glove_right_mesh.visible = not player_card_nodes.is_empty()

func _is_card_debuffed_by_boss(card: Dictionary, in_combo: bool = false) -> bool:
	if tutorial_mode or active_boss_mod == "":
		return false
	var is_pwr := str(card.get("power_id", "")) != ""
	var rk := str(card.get("rank", ""))
	var pts := int(card.get("pts", 10))
	match active_boss_mod:
		"PHARAOH_SEAL":
			return (not in_combo) and (not is_pwr) and pts < 15
		"IRON_JOUST":
			return (not in_combo) and (not is_pwr) and rk != "7"
		"CAESAR_TRIBUTE":
			return not in_combo
		"SYNDICATE_CUT":
			return not in_combo
		_:
			return false

func _get_boss_counterplay_tip() -> String:
	match active_boss_mod:
		"SCROLL_TAX":
			return _tr("Counter: Play cards instead of raw Deck draws.", "Rada: Hraj karty místo lízání z balíčku.")
		"PHARAOH_SEAL":
			return _tr("Counter: Play 2×+ Combos or cards ≥15 pts.", "Rada: Hraj komba 2×+ nebo karty za ≥15 b.")
		"IRON_WALL":
			return _tr("Counter: Build early Combos to overtake Rival.", "Rada: Rychle nasázej komba a dožeň náskok.")
		"CAESAR_TRIBUTE":
			return _tr("Counter: Play 2×+ Combos so solo plays don't feed Caesar.", "Rada: Hraj 2×+ komba, jinak Caesar dostává body.")
		"IRON_JOUST":
			return _tr("Counter: Break armor with Sevens (7), Power Cards, or Combos.", "Rada: Proraz zbroj Sedmami (7), Mocnými kartami či kombem.")
		"CROWN_DECREE":
			return _tr("Counter: Keep Shields active to block Court bonuses.", "Rada: Drž si Štít proti figurám soupeře.")
		"SHIFTING_WINDS":
			return _tr("Counter: Keep Queen (H) or Wild ready when winds shift.", "Rada: Drž si Svrška nebo Divokou kartu na změnu barvy.")
		"PLUNDER":
			return _tr("Counter: Counter Rival 7s/Aces or keep Shields up.", "Rada: Přebíjej 7/Esa nebo drž Štít proti krádeži.")
		"SYNDICATE_CUT":
			return _tr("Counter: Play 2×+ Combos to evade Syndicate tax!", "Rada: Komba 2×+ neplatí syndikátní daň!")
		"DON_RACKETEER":
			return _tr("Counter: Counter 7s with your own 7 or Ash Phoenix.", "Rada: Přebíjej Sedmy vlastní Sedmou nebo Fénixem.")
		_:
			return _tr("Counter: Right-click matching cards for Combos!", "Rada: Pravým klikem spojuj stejné karty do komba!")

func _sort_player_hand(mode: String) -> void:
	if busy_animating or player_hand.size() <= 1:
		return
	var staged_refs: Array = []
	for si in staged_card_indices:
		if si >= 0 and si < player_hand.size():
			staged_refs.append(player_hand[si])

	var rank_order := {"7": 0, "8": 1, "9": 2, "10": 3, "D": 4, "H": 5, "K": 6, "E": 7, "PWR": 8}
	var suit_order := {"CERVEN": 0, "ZELEN": 1, "ZALUD": 2, "GULA": 3}
	var rank_has_playable: Dictionary = {}
	for c_chk in player_hand:
		if _can_play(c_chk):
			rank_has_playable[str(c_chk.get("rank", "8"))] = true

	player_hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := int(rank_order.get(str(a.get("rank", "8")), 9))
		var rb := int(rank_order.get(str(b.get("rank", "8")), 9))
		var sa := -1 if str(a.get("suit", "")) == active_suit_id else int(suit_order.get(str(a.get("suit", "")), 5))
		var sb := -1 if str(b.get("suit", "")) == active_suit_id else int(suit_order.get(str(b.get("suit", "")), 5))
		var play_a := _can_play(a)
		var play_b := _can_play(b)
		var ed_a := Catalog.normalize_card_class(str(a.get("edition", "NORMAL")))
		var ed_b := Catalog.normalize_card_class(str(b.get("edition", "NORMAL")))
		var pa := (1000 if play_a else 0) + (300 if str(a.get("power_id", "")) != "" else 0) + (120 if ed_a != "NORMAL" else 0) + (40 if str(a.get("rank", "")) in ["7", "E", "H"] else 0) + int(a.get("pts", 0))
		var pb := (1000 if play_b else 0) + (300 if str(b.get("power_id", "")) != "" else 0) + (120 if ed_b != "NORMAL" else 0) + (40 if str(b.get("rank", "")) in ["7", "E", "H"] else 0) + int(b.get("pts", 0))
		if mode == "suit":
			if sa != sb:
				return sa < sb
			return ra < rb
		elif mode == "power":
			if pa != pb:
				return pa > pb
			return ra < rb
		else:
			var rpa := bool(rank_has_playable.get(str(a.get("rank", "8")), false))
			var rpb := bool(rank_has_playable.get(str(b.get("rank", "8")), false))
			if rpa != rpb:
				return rpa
			if ra != rb:
				return ra < rb
			if play_a != play_b:
				return play_a
			return sa < sb
	)

	staged_card_indices.clear()
	for sr in staged_refs:
		for hi in range(player_hand.size()):
			if player_hand[hi] == sr and not (hi in staged_card_indices):
				staged_card_indices.append(hi)
				break

	emit_signal("play_sfx_pitched_requested", "card_shuffle", 1.12)
	_rebuild_all_3d_hands()
	_refresh_table_labels()
	for i in range(player_card_nodes.size()):
		var cn := player_card_nodes[i]
		if is_instance_valid(cn):
			cn.scale = Vector3(0.84, 0.84, 0.84)
			var tw := cn.create_tween()
			tw.tween_interval(float(i) * 0.025)
			tw.tween_property(cn, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _can_play(card: Dictionary) -> bool:
	if sealed_suit_turns > 0 and sealed_suit_id != "" and str(card.get("suit", "")) == sealed_suit_id and str(card.get("rank", "")) != "H" and not bool(card.get("wild", false)):
		return false
	var top: Dictionary = discard_pile.back()
	var p_id: String = str(card.get("power_id", ""))
	if pending_draw > 0:
		return card["rank"] == "7" or p_id == "SPEC_PHOENIX"
	if pending_skip:
		return card["rank"] == "E" or p_id == "SPEC_CHRONOS"
	if table_relic_hollow_mask_active:
		return true
	if card["rank"] == "H" or bool(card.get("wild", false)):
		return true
	if p_id != "" and top.get("power_id", "") != "":
		return true
	return card["suit"] == active_suit_id or card["rank"] == top["rank"]

func _get_suit_obj(s_id: String) -> Dictionary:
	for s in SUITS:
		if s["id"] == s_id:
			var d: Dictionary = s.duplicate()
			d["name"] = _tr(str(s["name"]), str(s.get("name_cs", s["name"])))
			return d
	var fallback: Dictionary = SUITS[0].duplicate()
	fallback["name"] = _tr(str(SUITS[0]["name"]), str(SUITS[0].get("name_cs", SUITS[0]["name"])))
	return fallback

func _apply_hp_damage(to_player: bool, dmg: int, reason: String = "", pierce_shield: bool = false) -> int:
	if dmg <= 0:
		return 0
	if to_player:
		if not tutorial_mode and not pierce_shield and player_shields > 0:
			var blocked := mini(player_shields, dmg)
			player_shields -= blocked
			dmg -= blocked
			if is_instance_valid(player_hp_heart):
				player_hp_heart.call("set_shields", player_shields)
			_spawn_score_popup(_tr("SHIELD BLOCKED -%d ♥ HP!" % blocked, "ŠTÍT VYKRYL -%d ♥ HP!" % blocked), Color(0.45, 0.94, 1.0), true)
			SwordCardAnim.play_sword_card_score_anim(self, {"suit": "CERVEN", "rank": "D", "edition": "KNIGHT", "shield_block": true}, null, true, player_hand_anchor.global_position + Vector3(0.0, 0.14, -0.18), blocked, 1.2, false)
			_refresh_table_labels()
			if dmg <= 0:
				return 0
		var min_hp := 1 if (tutorial_mode and tutorial_step < 8) else 0
		player_hp = maxi(min_hp, player_hp - dmg)
		_trigger_screen_juice(Color(0.96, 0.16, 0.20), 0.72, 0.44)
		cam_kick_shake = maxf(cam_kick_shake, 0.75)
		if is_instance_valid(player_hp_heart):
			player_hp_heart.call("set_hp_with_status", player_hp, player_max_hp, player_shields, "", false, player_knight_shield_charge)
			player_hp_heart.call("trigger_damage_pulse", dmg)
		if player_hp_lbl:
			_punch_hud_label(player_hp_lbl, 1.38)
		var msg := (("%s " % _tr("CRITICAL • SHIELD PIERCE!", "KRITICKÝ PRŮRAZ ŠTÍTEM!")) if pierce_shield else "") + ("-%d ♥ HP! %s" % [dmg, reason]).strip_edges()
		_spawn_score_popup(msg, Color(1.0, 0.82, 0.28) if pierce_shield else Color(1.0, 0.30, 0.34), true)
		Fx.float_number(self, player_hand_anchor.global_position + Vector3(0.0, 0.22, -0.10), "-%d ♥ HP!" % dmg, Color(1.0, 0.26, 0.30), 74, 0.26, 1.0, 1.8)
	else:
		if not tutorial_mode and not pierce_shield and ai_shields > 0:
			var r_blocked := mini(ai_shields, dmg)
			ai_shields -= r_blocked
			dmg -= r_blocked
			if is_instance_valid(rival_hp_heart):
				rival_hp_heart.call("set_shields", ai_shields)
			_spawn_score_popup(_tr("RIVAL SHIELD BLOCKED -%d!" % r_blocked, "SOUPEŘŮV ŠTÍT VYKRYL -%d!" % r_blocked), Color(0.56, 0.88, 1.0), false)
			if dmg <= 0:
				return 0
		elif pierce_shield and ai_shields > 0:
			_spawn_score_popup(_tr("CRITICAL • SHIELD PIERCE!", "KRITICKÝ PRŮRAZ ŠTÍTEM!"), Color(1.0, 0.86, 0.24), true)
		var min_hp := 1 if (tutorial_mode and tutorial_step < 8) else 0
		ai_hp = maxi(min_hp, ai_hp - dmg)
		_trigger_boss_recoil_stagger(dmg >= 4 or pierce_shield)
		cam_kick_shake = maxf(cam_kick_shake, 0.82 if pierce_shield else (0.65 if dmg >= 4 else 0.42))
		if is_instance_valid(rival_hp_heart):
			rival_hp_heart.call("set_hp_with_status", ai_hp, ai_max_hp, ai_shields, "", false)
			rival_hp_heart.call("trigger_damage_pulse", dmg)
		if ai_hp_lbl:
			_punch_hud_label(ai_hp_lbl, 1.38)
		var r_pos := opp_hands_anchor.global_position + Vector3(0.0, 0.24, 0.05) if is_instance_valid(opp_hands_anchor) else Vector3(0.0, 1.25, -1.0)
		Fx.burst(self, r_pos, Color(1.0, 0.82, 0.24) if pierce_shield else Color(1.0, 0.24, 0.28), 24 if (dmg >= 4 or pierce_shield) else 12, 1.35, 0.52, 0.036, 1.4, true, 150.0, Vector3.UP, true)
		var amsg := (("CRITICAL • SHIELD PIERCE! " if pierce_shield else "") + "-%d ♥ HP! %s" % [dmg, reason]).strip_edges()
		_spawn_score_popup(amsg, Color(1.0, 0.86, 0.24) if pierce_shield else Color(1.0, 0.42, 0.26), false)
		Fx.float_number(self, r_pos, ("CRIT PIERCE -%d ♥!" % dmg) if pierce_shield else ("-%d ♥ HP!" % dmg), Color(1.0, 0.86, 0.26) if pierce_shield else Color(1.0, 0.32, 0.24), 78 if (dmg >= 4 or pierce_shield) else 64, 0.26, 1.0, 1.85)
	_refresh_table_labels()
	if not to_player:
		_check_boss_phase_awakening()
	return dmg

func _draw_from_deck() -> Dictionary:
	if deck.is_empty():
		if discard_pile.size() <= 1:
			return {"suit": "CERVEN", "rank": "8", "pts": 8, "rname": _get_rank_name("8")}
		var top: Dictionary = discard_pile.pop_back()
		deck = discard_pile.duplicate()
		deck.shuffle()
		discard_pile = [top]
	var drawn = deck.pop_back()
	if not (drawn is Dictionary) or drawn.is_empty():
		return {"suit": "CERVEN", "rank": "8", "pts": 8, "rname": _get_rank_name("8")}
	return drawn

# ============================================================================
# 6. 3D RAYCAST INTERAKCIA, VOĽNÝ POHĽAD PRAVÝM KLIKOM A LET KARIET
# ============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_look_pos = event.position

func _process(delta: float) -> void:
	if not visible or cam == null:
		return

	var vp_size := get_viewport().get_visible_rect().size
	var m_pos := _cursor_look_pos if _cursor_look_pos.x >= 0.0 else (get_viewport().get_mouse_position() if DisplayServer.window_is_focused() else vp_size * 0.5)
	var nx := clampf((m_pos.x / maxf(1.0, vp_size.x)) - 0.5, -0.5, 0.5)
	var ny := clampf((m_pos.y / maxf(1.0, vp_size.y)) - 0.5, -0.5, 0.5)
	var t := Time.get_ticks_msec() * 0.001

	_step_handwriting_anims(delta)
	_step_player_turn_timer(delta, t)
	tutorial_ghost_ok_flash = maxf(0.0, tutorial_ghost_ok_flash - delta * 1.4)

	if _is_hand_tucked() != _last_peek_state:
		_sync_peek_ui_visibility()

	glove_lunge_boost = maxf(0.0, glove_lunge_boost - delta * 4.2)
	wager_showcase_boost = maxf(0.0, wager_showcase_boost - delta * 1.35)
	if turn_glance_timer > 0.0:
		turn_glance_timer = maxf(0.0, turn_glance_timer - delta)
	if stagger_callout_ttl > 0.0:
		stagger_callout_ttl -= delta
		if stagger_callout_ttl <= 0.0 and is_instance_valid(stagger_callout_pill) and stagger_callout_pill.visible:
			stagger_callout_ttl = 0.0
			if stagger_callout_tween and stagger_callout_tween.is_valid():
				stagger_callout_tween.kill()
			stagger_callout_tween = create_tween()
			stagger_callout_tween.tween_property(stagger_callout_pill, "modulate:a", 0.0, 0.25)
			stagger_callout_tween.tween_callback(func():
				if is_instance_valid(stagger_callout_pill):
					stagger_callout_pill.visible = false
			)

	_update_gameplay_gfx(delta, t)

	# Step CameraRecoilSpring cleanly without fighting natural cursor look or scripted cutscenes
	var cine_owns_cam := (cam_view_mode == CameraViewMode.CINEMATIC) or _is_cinematic_playing()
	if not cine_owns_cam:
		var base_pitch := cam.rotation_degrees.x - cam_prev_pitch_kick
		var base_fov := cam.fov - cam_prev_fov_kick
		if cam_kick_shake > 0.001:
			cam_spring.pos_vel += Vector3(sin(t * 42.0), cos(t * 37.0), 0.0) * (cam_kick_shake * 0.35)
			cam_kick_shake = maxf(0.0, cam_kick_shake - delta * 8.0)
		cam_spring.step(delta)
		cam_spring.apply_to_camera(cam)
		var next_pitch_kick := cam_spring.get_pitch_kick()
		var next_fov_kick := cam_spring.get_fov_kick()

		if not intro_animating and not cam_impact_active:
			cam_prev_pitch_kick = next_pitch_kick
			cam_prev_fov_kick = next_fov_kick
			var is_player_items_view := (cam_view_mode == CameraViewMode.TABLE_ITEMS) and not (tutorial_mode and tutorial_step == 0)
			var is_rival_items_view := (cam_view_mode == CameraViewMode.RIVAL_ITEMS) and not (tutorial_mode and tutorial_step == 0)
			var is_items_view := is_player_items_view or is_rival_items_view or (cards_tucked and not (tutorial_mode and tutorial_step == 0))
			var is_ghost_closeup := tutorial_mode and tutorial_step == 0
			var is_top_down_view := (is_player_items_view or (turn_glance_timer > 0.0 and not is_rival_items_view)) and not is_ghost_closeup

			# Static camera (no cursor-driven camera sway so HUD/Settings clicks stay rock-steady)
			cam_look_yaw = 0.0
			cam_look_pitch = 0.0
			freelook_yaw = 0.0
			freelook_pitch = 0.0

			var target_pitch := 1.0 if is_ghost_closeup else (-22.0 if is_rival_items_view else (-74.0 if is_top_down_view else -31.0))
			var target_yaw := 44.0 if is_ghost_closeup else 0.0
			if active_player_count > 2 and not is_player_turn and not is_ghost_closeup and not intro_animating and not tutorial_mode:
				var vp_fl := get_viewport().get_visible_rect().size
				var mp_fl := get_viewport().get_mouse_position()
				if vp_fl.x > 10.0 and vp_fl.y > 10.0:
					var nx_fl := clampf((mp_fl.x / vp_fl.x) * 2.0 - 1.0, -1.0, 1.0)
					var ny_fl := clampf((mp_fl.y / vp_fl.y) * 2.0 - 1.0, -1.0, 1.0)
					freelook_yaw = -nx_fl * 60.0
					freelook_pitch = clampf(-ny_fl * 22.0, -24.0, 24.0)
					target_yaw += freelook_yaw
					target_pitch = clampf(target_pitch + freelook_pitch, -82.0, -8.0)
			var target_cam_pos := Vector3(-0.32, 1.50, 0.76) if is_ghost_closeup else (Vector3(0.0, 1.54, 1.04) if is_rival_items_view else (Vector3(0.0, 2.68, 0.48) if is_top_down_view else Vector3(0.0, 1.78, 1.48)))
			var target_fov := 62.0 if is_ghost_closeup else (64.0 if is_rival_items_view else 72.0)
			cam.position = cam.position.lerp(target_cam_pos, 9.0 * delta)
			cam.fov = lerpf(base_fov, target_fov, 8.5 * delta) + next_fov_kick
			cam.rotation_degrees.x = lerpf(base_pitch, target_pitch, 10.0 * delta) + next_pitch_kick
			cam.rotation_degrees.y = lerpf(cam.rotation_degrees.y, target_yaw, 10.0 * delta)
		else:
			cam_prev_pitch_kick = 0.0
			cam_prev_fov_kick = 0.0
	else:
		cam_prev_pitch_kick = 0.0
		cam_prev_fov_kick = 0.0

	if not intro_animating:
		var use_tucked_hand := cine_owns_cam or (cam_view_mode == CameraViewMode.TABLE_ITEMS) or (cam_view_mode == CameraViewMode.RIVAL_ITEMS) or cards_tucked or (tutorial_mode and tutorial_step == 0)
		var tucked_pos := HAND_POS_TUCKED + Vector3(0.0, -0.26, 0.14) if (cam_view_mode == CameraViewMode.TABLE_ITEMS or cam_view_mode == CameraViewMode.RIVAL_ITEMS or cine_owns_cam) else HAND_POS_TUCKED
		var target_hand_pos := tucked_pos if use_tucked_hand else (HAND_POS_UP + Vector3(0.0, 0.02 * glove_lunge_boost, -0.06 * glove_lunge_boost))
		var target_hand_rot := HAND_ROT_TUCKED if use_tucked_hand else HAND_ROT_UP
		player_hand_anchor.position = player_hand_anchor.position.lerp(target_hand_pos, 10.5 * delta)
		player_hand_anchor.rotation_degrees = player_hand_anchor.rotation_degrees.lerp(target_hand_rot, 10.5 * delta)
	_update_prop_hover_and_edge_peek(delta, m_pos, vp_size)

	# Rolling Score Odometer + Live Multi-Lap 100-Pt Wheel
	score_tick_cd = maxf(0.0, score_tick_cd - delta)
	if not hud_score_revealed:
		display_player_score = float(player_score)
		display_ai_score = float(ai_score)
	elif absf(display_player_score - float(player_score)) > 0.25:
		var was_lower := display_player_score < float(player_score)
		var diff_sc := absf(float(player_score) - display_player_score)
		var spd := maxf(88.0, diff_sc * 22.0)
		display_player_score = move_toward(display_player_score, float(player_score), spd * delta)
		if was_lower and score_tick_cd <= 0.0:
			score_tick_cd = 0.060
			if player_score_lbl:
				player_score_lbl.pivot_offset = player_score_lbl.size * 0.5
				var roll_sc := clampf(1.04 + minf(diff_sc, 60.0) * 0.0025, 1.04, 1.18)
				player_score_lbl.scale = Vector2(roll_sc, roll_sc)
			emit_signal("play_sfx_pitched_requested", "card_hover", clampf(0.98 + (display_player_score / maxf(1.0, float(target_score))) * 0.48, 0.98, 1.55))
	elif player_score_lbl and player_score_lbl.scale.distance_to(Vector2.ONE) > 0.005:
		player_score_lbl.scale = player_score_lbl.scale.lerp(Vector2.ONE, clampf(delta * 14.0, 0.0, 1.0))
	var shown_sc := int(round(display_player_score)) if absf(display_player_score - float(player_score)) > 0.25 else player_score
	if player_score_lbl:
		player_score_lbl.text = _tr("SCORE: %s / %s", "BODY: %s / %s") % [_format_pts_ui(shown_sc), _format_pts_ui(target_score)]
	if wheel_lap_lbl:
		var lap_num := int(floor(display_player_score / 100.0)) + 1
		var lap_cols_ui: Array[Color] = [Color(0.98, 0.78, 0.30), Color(0.32, 0.92, 1.0), Color(0.88, 0.48, 1.0), Color(1.0, 0.36, 0.32), Color(0.34, 0.98, 0.56), Color(1.0, 0.95, 0.74)]
		wheel_lap_lbl.text = _tr("100 PT ×%d", "100 B ×%d") % lap_num
		wheel_lap_lbl.add_theme_color_override("font_color", lap_cols_ui[(lap_num - 1) % lap_cols_ui.size()])
	_sync_charge_chalice_art(false)
	var raw_prog := clampf(display_player_score / float(maxi(1, target_score)), 0.0, 1.45) if hud_score_revealed else 0.0
	var pend_preview_prog := clampf((display_player_score + float(pending_player_exchange_pts)) / float(maxi(1, target_score)), 0.0, 1.45) if hud_score_revealed else 0.0
	var target_prog := maxf(raw_prog, lerpf(raw_prog, pend_preview_prog, 0.25))
	chalice_flame_progress = lerpf(chalice_flame_progress, target_prog, clampf(delta * 2.2, 0.0, 1.0))
	var is_rolling := absf(float(player_score) - display_player_score) > 0.5
	var target_surge := (0.55 if is_rolling else 0.0) + clampf(score_ledger_glow, 0.0, 1.0) * 0.55 + (0.24 if (combo_tot_val > 0 and not staged_card_indices.is_empty()) else 0.0)
	chalice_flame_surge = lerpf(chalice_flame_surge, target_surge, clampf(delta * 4.2, 0.0, 1.0))
	var ch_tint := _get_chalice_fire_tint(chalice_flame_progress)
	if chalice_back_fire_mat:
		chalice_back_fire_mat.set_shader_parameter("progress", chalice_flame_progress)
		chalice_back_fire_mat.set_shader_parameter("heat_surge", chalice_flame_surge)
	if chalice_front_fire_mat:
		chalice_front_fire_mat.set_shader_parameter("progress", chalice_flame_progress)
		chalice_front_fire_mat.set_shader_parameter("heat_surge", chalice_flame_surge)
	if chalice_vessel_mat:
		chalice_vessel_mat.set_shader_parameter("progress", chalice_flame_progress)
		chalice_vessel_mat.set_shader_parameter("heat_surge", chalice_flame_surge)
		chalice_vessel_mat.set_shader_parameter("fire_tint", ch_tint)
	if is_instance_valid(score_chalice_art):
		score_chalice_art.position.y = 30.0 + sin(t * (2.4 + chalice_flame_progress * 1.4)) * (0.5 + minf(1.2, chalice_flame_progress * 0.9))
		if is_instance_valid(score_chalice_next) and score_chalice_next.visible:
			score_chalice_next.position.y = score_chalice_art.position.y
	if wheel_canvas and player_hud_grp and player_hud_grp.visible:
		wheel_canvas.queue_redraw()
	if score_goal_bar_ctrl:
		score_goal_bar_ctrl.queue_redraw()

	if absf(display_ai_score - float(ai_score)) > 0.25:
		var ai_spd := maxf(90.0, absf(float(ai_score) - display_ai_score) * 20.0)
		display_ai_score = move_toward(display_ai_score, float(ai_score), ai_spd * delta)
		if ai_score_lbl:
			ai_score_lbl.text = _tr("RIVAL: %s / %s", "SOUPEŘ: %s / %s") % [_format_pts_ui(int(round(display_ai_score))), _format_pts_ui(target_score)]
		if ai_liquid_bar:
			ai_liquid_bar.queue_redraw()
	elif ai_score_lbl:
		ai_score_lbl.text = _tr("RIVAL: %s / %s", "SOUPEŘ: %s / %s") % [_format_pts_ui(ai_score), _format_pts_ui(target_score)]

	# 3D Raycast from mouse into table scene
	_update_3d_hover(m_pos, delta)

	if tutorial_callout_grp and tutorial_callout_grp.visible:
		tutorial_callout_grp.queue_redraw()
	if turn_banner_grp and turn_banner_grp.visible and turn_ornament_ctrl:
		turn_ornament_ctrl.queue_redraw()

	# Žiariaca horiaca kombo aura + iskry + rotujúce runy
	combo_heat = lerpf(combo_heat, combo_target_heat, 4.2 * delta)
	combo_charge_frac = lerpf(combo_charge_frac, combo_target_charge, 6.5 * delta)
	combo_dial_rot += delta * (0.9 + combo_heat * 3.8)
	if combo_flame_mat:
		combo_flame_mat.set_shader_parameter("heat", combo_heat)
		combo_flame_mat.set_shader_parameter("charge_frac", combo_charge_frac)
	var ember_rate := (0.0 if chalice_flame_progress < 0.02 else (1.5 + chalice_flame_progress * 14.0)) + combo_heat * 6.5 + chalice_flame_surge * 7.0
	if combo_embers.size() < 28 and randf() < delta * ember_rate:
		var ember_tint := _get_chalice_fire_tint(chalice_flame_progress)
		var spark_col := ember_tint.lerp(Color(1.0, 0.96, 0.72), randf_range(0.05, 0.42))
		combo_embers.append({
			"pos": Vector2(32.0 + randf_range(-16.0, 16.0), 34.0 + randf_range(-10.0, 6.0)),
			"vel": Vector2(randf_range(-14.0, 16.0), randf_range(-56.0 - chalice_flame_progress * 26.0, -26.0)),
			"life": randf_range(0.42, 0.88),
			"max_life": 0.88,
			"col": spark_col,
			"sz": randf_range(1.4, 2.9 + chalice_flame_progress * 1.0),
		})
	for ei in range(combo_embers.size() - 1, -1, -1):
		var em: Dictionary = combo_embers[ei]
		em["life"] = float(em["life"]) - delta
		if float(em["life"]) <= 0.0:
			combo_embers.remove_at(ei)
		else:
			em["pos"] = em["pos"] + em["vel"] * delta
	if combo_dial_ctrl and combo_hud_grp and combo_hud_grp.visible:
		combo_dial_ctrl.queue_redraw()

	# Animate Fullscreen Score Resolution Multi-FX (Orbs, Lightning Bolts, Viewport Ember Rain, Rings, Starburst & Ledger Glow)
	var fx_dirty := false
	if score_ledger_glow > 0.0:
		score_ledger_glow = move_toward(score_ledger_glow, 0.0, delta * 0.28)
		fx_dirty = true
	if score_sheen_phase >= 0.0:
		score_sheen_phase += delta * 1.45
		if score_sheen_phase > 1.35:
			score_sheen_phase = -1.0
		fx_dirty = true
	if _score_fx_beams_alpha > 0.0:
		_score_fx_beams_alpha = move_toward(_score_fx_beams_alpha, 0.0, delta * 0.42)
		fx_dirty = true
	for oi in range(_score_fx_orbs.size() - 1, -1, -1):
		var ob: Dictionary = _score_fx_orbs[oi]
		var dur_o: float = maxf(0.15, float(ob["dur"]))
		ob["t"] = float(ob["t"]) + delta / dur_o
		var ot: float = float(ob["t"])
		if ot >= 1.0:
			var tpos: Vector2 = ob["target"]
			var ocol: Color = ob["col"]
			_score_fx_rings.append({"pos": tpos, "r": 4.0, "max_r": 48.0, "life": 0.24, "max_life": 0.24, "col": ocol, "w": 2.2})
			_score_fx_orbs.remove_at(oi)
			fx_dirty = true
		elif ot >= 0.0:
			ob["prev_pos"] = ob["pos"]
			var u := 1.0 - pow(1.0 - ot, 2.0)
			var p0: Vector2 = ob["start"]
			var p1: Vector2 = ob["ctrl"]
			var p2: Vector2 = ob["target"]
			ob["pos"] = p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
			fx_dirty = true
	for bi in range(_score_fx_bolts.size() - 1, -1, -1):
		var bt: Dictionary = _score_fx_bolts[bi]
		bt["life"] = float(bt["life"]) - delta
		if float(bt["life"]) <= 0.0:
			_score_fx_bolts.remove_at(bi)
		fx_dirty = true
	for emi in range(_score_fx_embers.size() - 1, -1, -1):
		var em2: Dictionary = _score_fx_embers[emi]
		em2["life"] = float(em2["life"]) - delta
		if float(em2["life"]) <= 0.0:
			_score_fx_embers.remove_at(emi)
		else:
			em2["pos"] = em2["pos"] + (em2["vel"] as Vector2) * delta
			em2["rot"] = float(em2["rot"]) + delta * 3.2
		fx_dirty = true
	for ri in range(_score_fx_rings.size() - 1, -1, -1):
		var rg: Dictionary = _score_fx_rings[ri]
		rg["life"] = float(rg["life"]) - delta
		if float(rg["life"]) <= 0.0:
			_score_fx_rings.remove_at(ri)
		else:
			var prog := 1.0 - (float(rg["life"]) / maxf(0.01, float(rg["max_life"])))
			rg["r"] = lerpf(12.0, float(rg["max_r"]), 1.0 - pow(1.0 - prog, 2.2))
		fx_dirty = true
	if fx_dirty and is_instance_valid(score_fx_overlay):
		score_fx_overlay.queue_redraw()

	# Minimal Circular Discard Spread when [SPACE] Peek is active (top 5 cards in clean rosette arc)
	table_pulse_strength = maxf(0.0, table_pulse_strength - delta * 2.1)
	if table_felt_mat:
		table_felt_mat.set_shader_parameter("pulse_strength", table_pulse_strength)
	if table_peek_mat:
		var target_pk_alpha := (0.46 + sin(t * 4.6) * 0.12) if cards_tucked else 0.0
		table_peek_mat.albedo_color.a = lerpf(table_peek_mat.albedo_color.a, target_pk_alpha, 10.0 * delta)
	var cam_tilt_vec := Vector2(
		clampf(cam.rotation_degrees.y * 0.032 - nx * 0.55, -0.75, 0.75),
		clampf((cam.rotation_degrees.x - base_cam_rot.x) * 0.032 + ny * 0.55, -0.75, 0.75)
	)
	if discard_pile_root:
		var d_cards: Array[Node3D] = []
		for di in range(discard_pile_root.get_child_count()):
			var dc := discard_pile_root.get_child(di)
			if dc is Node3D and not (dc is Area3D) and not dc.is_queued_for_deletion():
				d_cards.append(dc)
		var d_cnt := d_cards.size()
		for di in range(d_cnt):
			var dc := d_cards[di]
			if not dc.has_meta("pile_base_pos"):
				dc.set_meta("pile_base_pos", dc.position)
				dc.set_meta("pile_base_rot", dc.rotation_degrees)
			var from_top := d_cnt - 1 - di
			if from_top == 0:
				# Flat on the table during top-down view (when not playing a card); tilted toward camera otherwise
				var is_td_flat := (not busy_animating) and (cam_view_mode == CameraViewMode.TABLE_ITEMS or turn_glance_timer > 0.0)
				var top_tilt_x := -90.0 if is_td_flat else (-52.0 if cards_tucked else -64.0)
				var top_target_p := Vector3(0.0, 0.028, 0.0) if is_td_flat else Vector3(0.0, 0.112 + sin(t * 2.6) * 0.004, 0.044)
				var top_target_r := Vector3(-90.0, 0.0, 0.0) if is_td_flat else Vector3(top_tilt_x, sin(t * 2.1) * 2.2, 0.0)
				dc.position = dc.position.lerp(top_target_p, 11.0 * delta)
				dc.rotation_degrees = dc.rotation_degrees.lerp(top_target_r, 11.0 * delta)
				dc.scale = dc.scale.lerp(Vector3(1.06, 1.06, 1.06), 11.0 * delta)
				dc.visible = true
			elif from_top <= 4:
				# Older buried cards stack flat and neat underneath (never fan sideways to compete with top card!)
				var stack_y := float(4 - from_top) * 0.0028
				var stack_p := Vector3(-0.004 * float(from_top), stack_y, -0.004 * float(from_top))
				var stack_r := Vector3(-90.0, float(from_top) * 5.0, 0.0)
				dc.position = dc.position.lerp(stack_p, 11.0 * delta)
				dc.rotation_degrees = dc.rotation_degrees.lerp(stack_r, 11.0 * delta)
				dc.scale = dc.scale.lerp(Vector3(0.94, 0.94, 0.94), 11.0 * delta)
				dc.visible = true
			else:
				dc.visible = false
			if from_top < 5:
				var dfm := dc.get_node_or_null("CardFaceMesh") as MeshInstance3D
				if dfm and dfm.material_override is ShaderMaterial:
					(dfm.material_override as ShaderMaterial).set_shader_parameter("tilt_vec", cam_tilt_vec)

	# Epoch Boss Silhouette Reactive States:
	# 1) Nervous lean-in when player > 50% of target_score
	# 2) Recoil stagger + ink-smoke plume when hit by Overdrive / Slams
	# 3) Menacing Eye & Sigil Halo flare when Boss Modifier triggers
	opp_recoil_time = maxf(0.0, opp_recoil_time - delta)
	boss_flare_time = maxf(0.0, boss_flare_time - delta)
	chandelier_sway_boost = maxf(0.0, chandelier_sway_boost - delta * 1.4)
	overdrive_hum_cd = maxf(0.0, overdrive_hum_cd - delta)
	if combo_heat >= 0.78 and overdrive_hum_cd <= 0.0 and visible and not audio_muted_flag():
		overdrive_hum_cd = 1.05
		emit_signal("play_sfx_pitched_requested", "overdrive_hum", clampf(0.95 + (combo_heat - 0.75) * 0.6, 0.95, 1.35))

	var player_threat := float(player_score) / maxf(1.0, float(target_score))
	var is_nervous := player_threat >= 0.50
	if dark_silhouette_mat:
		var pulse_spd := 2.8 if is_nervous else 1.4
		dark_silhouette_mat.set_shader_parameter("breathe_pulse", 0.5 + 0.5 * sin(t * pulse_spd))
		var base_rim_str := 1.65 + (0.45 if is_nervous else 0.0) + (boss_flare_time * 1.35)
		dark_silhouette_mat.set_shader_parameter("rim_strength", base_rim_str)
	if is_instance_valid(opp_silhouette_root) and not finisher_anim_active:
		var lean_z := -1.36 if is_nervous else -1.52
		var lean_y := 0.85 if is_nervous else 0.86
		var lean_pitch := 11.5 if is_nervous else 0.0
		if opp_recoil_time > 0.0:
			var rec_u := opp_recoil_time / 0.82
			lean_z -= 0.19 * rec_u
			lean_pitch = -18.0 * rec_u
		opp_silhouette_root.position = opp_silhouette_root.position.lerp(Vector3(0.0, lean_y, lean_z), 7.5 * delta)
		opp_silhouette_root.rotation_degrees.x = lerpf(opp_silhouette_root.rotation_degrees.x, lean_pitch, 8.5 * delta)
		var sway_amp := 1.9 if is_nervous else 1.1
		var sway_freq := 2.5 if is_nervous else 1.1
		opp_silhouette_root.rotation_degrees.z = sin(t * sway_freq) * sway_amp + (sin(t * 36.0) * 5.0 * opp_recoil_time)
	if boss_eye_mat:
		var eye_a := 0.48 + (0.28 if is_nervous else 0.0) + clampf(boss_flare_time * 0.65, 0.0, 0.52)
		var base_ec: Color = active_era.get("border_col", Color(1.0, 0.55, 0.22))
		if boss_flare_time > 0.01:
			base_ec = Color(1.0, 0.24, 0.20)
		boss_eye_mat.albedo_color = Color(base_ec.r, base_ec.g, base_ec.b, clampf(eye_a, 0.2, 1.0))
	if is_instance_valid(boss_sigil_halo) and boss_sigil_halo.visible:
		boss_sigil_halo.rotation_degrees.z += delta * (38.0 + boss_flare_time * 180.0 + (28.0 if is_nervous else 0.0))
		var h_sc := 1.0 + sin(t * 3.2) * 0.06 + boss_flare_time * 0.28
		boss_sigil_halo.scale = Vector3(h_sc, h_sc, h_sc)
	if is_instance_valid(opp_ambient_fx_root):
		for pm in opp_ambient_fx_root.get_children():
			if not (pm is Node3D) or not pm.has_meta("base_pos"):
				continue
			var bp: Vector3 = pm.get_meta("base_pos")
			var ph: float = float(pm.get_meta("phase", 0.0))
			var fk: String = str(pm.get_meta("fx_kind", "dust"))
			var rspd: float = float(pm.get_meta("rise_spd", 0.22)) * (1.45 if is_nervous else 1.0)
			if fk == "smoke":
				var cycle := fmod(t * rspd + ph, 1.0)
				pm.position = Vector3(bp.x + sin(t * 1.4 + ph) * 0.07 + cycle * 0.12, bp.y + cycle * 0.42, bp.z + cos(t * 1.1 + ph) * 0.04)
				var s_sc := 0.7 + cycle * 0.95
				pm.scale = Vector3(s_sc, s_sc, s_sc)
			else:
				pm.position = bp + Vector3(sin(t * 0.85 + ph) * 0.08, sin(t * 1.1 + ph * 1.3) * 0.06, cos(t * 0.7 + ph) * 0.05)

	# Jemné dýchanie a pohyb hráčovho tela priamo pod kamerou + rúk v 1. osobe
	if is_instance_valid(player_body_root):
		player_body_root.position.y = 0.64 + sin(t * 1.8) * 0.006
		player_body_root.position.z = lerpf(player_body_root.position.z, 1.56 + (0.02 if cards_tucked else (-0.025 * glove_lunge_boost)), 12.0 * delta)
		player_body_root.rotation_degrees.x = 6.0 + (-2.0 if cards_tucked else (4.0 * glove_lunge_boost))
	if is_instance_valid(player_arm_left) and is_instance_valid(player_arm_right):
		var lunge_x := 16.0 * glove_lunge_boost
		player_arm_left.rotation_degrees.x = (-8.0 if cards_tucked else lunge_x) + sin(t * 2.1) * 1.5
		player_arm_right.rotation_degrees.x = (-8.0 if cards_tucked else lunge_x) + cos(t * 2.1) * 1.5
	if is_instance_valid(wager_3d_ring) and wager_3d_ring.visible:
		wager_3d_ring.rotation_degrees.y += delta * (75.0 + wager_showcase_boost * 240.0)
		var wr_sc := 1.0 + sin(t * 4.2) * 0.06 + wager_showcase_boost * 0.16
		wager_3d_ring.scale = Vector3(wr_sc, 1.0, wr_sc)
	if tutorial_beacon_mesh:
		if tutorial_mode and is_player_turn and not busy_animating and tutorial_step == 1 and tutorial_substep == 1 and cam_view_mode == CameraViewMode.TABLE_ITEMS and is_instance_valid(player_sword_root):
			tutorial_beacon_mesh.visible = true
			tutorial_beacon_mesh.global_position = player_sword_root.global_position + Vector3(0.0, 0.14 + sin(t * 5.0) * 0.025, 0.0)
			tutorial_beacon_mesh.rotation_degrees = Vector3(0.0, t * 110.0, 0.0)
			if tutorial_beacon_mesh.material_override is ShaderMaterial:
				(tutorial_beacon_mesh.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(1.0, 0.84, 0.28, 0.94))
			elif tutorial_beacon_mesh.material_override is StandardMaterial3D:
				(tutorial_beacon_mesh.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.84, 0.28, 0.92)
		elif tutorial_mode and is_player_turn and not busy_animating and tutorial_step == 6 and tutorial_substep == 1 and magic_puf_bottle and magic_puf_bottle.visible:
			tutorial_beacon_mesh.visible = true
			tutorial_beacon_mesh.global_position = magic_puf_bottle.global_position + Vector3(0.0, 0.16 + sin(t * 5.0) * 0.025, 0.0)
			tutorial_beacon_mesh.rotation_degrees = Vector3(0.0, t * 110.0, 0.0)
			if tutorial_beacon_mesh.material_override is ShaderMaterial:
				(tutorial_beacon_mesh.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(0.76, 0.42, 1.0, 0.94))
			elif tutorial_beacon_mesh.material_override is StandardMaterial3D:
				(tutorial_beacon_mesh.material_override as StandardMaterial3D).albedo_color = Color(0.76, 0.42, 1.0, 0.92)
		else:
			tutorial_beacon_mesh.visible = false
	if tutorial_arrow_overlay and tutorial_arrow_overlay.visible:
		tutorial_arrow_overlay.queue_redraw()
	if tutorial_ghost_center_panel and tutorial_ghost_center_panel.visible:
		var float_y := roundf(sin(t * 2.6) * 3.5)
		_layout_tutorial_ghost_center_panel(float_y)
		var hw_inf := _get_handwriting_progress(tutorial_ghost_center_lbl)
		var pop_sc := 1.0 + float(hw_inf.get("pop", 0.0)) * 0.015 + tutorial_ghost_ok_flash * 0.03
		tutorial_ghost_center_panel.pivot_offset = tutorial_ghost_center_panel.size * 0.5
		tutorial_ghost_center_panel.scale = Vector2(pop_sc, pop_sc)
		tutorial_ghost_center_panel.rotation = 0.0
		var gw_node := tutorial_ghost_center_panel.get_node_or_null("GhostWaveBorder") as Control
		if gw_node:
			gw_node.queue_redraw()
	if pending_seven_banner_pill and pending_seven_banner_pill.visible:
		var p_sc := 1.0 + sin(t * 6.5) * 0.045
		pending_seven_banner_pill.scale = Vector2(p_sc, p_sc)
	if peddler_ghost_ctrl and peddler_open:
		peddler_ghost_ctrl.queue_redraw()
	if victory_crown_ctrl and victory_summary_overlay and victory_summary_overlay.visible:
		victory_crown_ctrl.queue_redraw()
	# Handled smoothly via CameraRecoilSpring above; zero jitter override needed.

	var shake_x := 0.0
	if opp_shake_time > 0.0:
		opp_shake_time = maxf(0.0, opp_shake_time - delta)
		shake_x = sin(t * 48.0) * 0.06 * (opp_shake_time / 0.5)
	opp_hands_anchor.position.x = shake_x
	opp_hands_anchor.position.y = 1.10 + sin(t * (3.2 if is_nervous else 2.2)) * 0.014
	opp_hands_anchor.position.z = lerpf(opp_hands_anchor.position.z, -0.86 if is_nervous else -0.90, 6.0 * delta)

	player_glove_action_offset = player_glove_action_offset.lerp(Vector3.ZERO, 8.0 * delta)
	opp_play_anim_t = maxf(0.0, opp_play_anim_t - delta * 2.2)
	var p_left_x := -0.24
	var p_right_x := 0.24
	if not player_card_nodes.is_empty():
		p_left_x = clampf((player_card_nodes[0].get_meta("base_pos", Vector3(-0.16, 0.0, 0.0)) as Vector3).x - 0.095, -0.46, -0.18)
		p_right_x = clampf((player_card_nodes[player_card_nodes.size() - 1].get_meta("base_pos", Vector3(0.16, 0.0, 0.0)) as Vector3).x + 0.095, 0.18, 0.46)
	var p_grip_y := -0.114 if not player_card_nodes.is_empty() else -0.24
	player_glove_left_mesh.position = player_glove_left_mesh.position.lerp(
		Vector3(p_left_x, p_grip_y + sin(t * 2.1) * 0.005, 0.014) + player_glove_action_offset, 10.0 * delta)
	player_glove_right_mesh.position = player_glove_right_mesh.position.lerp(
		Vector3(p_right_x, p_grip_y + cos(t * 2.1) * 0.005, 0.018) + player_glove_action_offset, 10.0 * delta)
	player_glove_left_mesh.rotation_degrees = player_glove_left_mesh.rotation_degrees.lerp(Vector3(32.0, -26.0, 20.0), 10.0 * delta)
	player_glove_right_mesh.rotation_degrees = player_glove_right_mesh.rotation_degrees.lerp(Vector3(32.0, 26.0, -20.0), 10.0 * delta)

	var p_flick := clampf(player_glove_action_offset.length() * 4.5 + glove_lunge_boost * 0.85, 0.0, 1.25)
	var p_grip := (0.65 if cards_tucked else 0.28) + (0.28 if not staged_card_indices.is_empty() else 0.0)
	var p_mid := (float(player_hand.size()) - 1.0) * 0.5
	var p_pinch_l := 0.75 if (hovered_card_idx >= 0 and float(hovered_card_idx) <= p_mid) else (0.35 if not staged_card_indices.is_empty() else 0.0)
	var p_pinch_r := 0.75 if (hovered_card_idx >= 0 and float(hovered_card_idx) >= p_mid) else (0.35 if not staged_card_indices.is_empty() else 0.0)
	_animate_3d_hand_rig(player_glove_left_mesh, t, p_grip, p_flick, p_pinch_l, 2.4, delta)
	_animate_3d_hand_rig(player_glove_right_mesh, t, p_grip, p_flick, p_pinch_r, 2.4, delta)

	# Opponent hands snugly grip the lower-outer edges of opp_card_nodes in front of chest above the table
	if is_instance_valid(opp_hands_anchor) and _has_sculpted_opp_glb and is_instance_valid(opp_arm_left_node) and is_instance_valid(opp_arm_right_node):
		var arm_mid := (opp_arm_left_node.global_position + opp_arm_right_node.global_position) * 0.5
		var target_opp_hand_pos := Vector3(arm_mid.x, clampf(arm_mid.y - 0.12, 1.06, 1.16), clampf(arm_mid.z + 0.48, -0.94, -0.82))
		opp_hands_anchor.global_position = opp_hands_anchor.global_position.lerp(target_opp_hand_pos, 10.0 * delta)
	var o_left_x := -0.18
	var o_right_x := 0.18
	if not opp_card_nodes.is_empty():
		o_left_x = clampf(opp_card_nodes[0].position.x - 0.072, -0.32, -0.11)
		o_right_x = clampf(opp_card_nodes[opp_card_nodes.size() - 1].position.x + 0.072, 0.11, 0.32)
	if is_instance_valid(opp_glove_left_mesh) and is_instance_valid(opp_glove_right_mesh):
		var o_has_cards := not opp_card_nodes.is_empty()
		opp_glove_left_mesh.visible = o_has_cards
		opp_glove_right_mesh.visible = o_has_cards
		var o_lunge_z := sin(opp_play_anim_t * PI) * 0.11
		var o_lunge_y := sin(opp_play_anim_t * PI) * 0.04
		opp_glove_left_mesh.position = opp_glove_left_mesh.position.lerp(
			Vector3(o_left_x, -0.056 + sin(t * 2.5) * 0.004 + o_lunge_y, 0.014 + o_lunge_z), 10.0 * delta)
		opp_glove_right_mesh.position = opp_glove_right_mesh.position.lerp(
			Vector3(o_right_x, -0.056 + cos(t * 2.5) * 0.004 + o_lunge_y, 0.014 + o_lunge_z * 0.6), 10.0 * delta)
		opp_glove_left_mesh.rotation_degrees = opp_glove_left_mesh.rotation_degrees.lerp(Vector3(22.0, 152.0, -16.0), 10.0 * delta)
		opp_glove_right_mesh.rotation_degrees = opp_glove_right_mesh.rotation_degrees.lerp(Vector3(22.0, -152.0, 16.0), 10.0 * delta)
		var o_flick := sin(opp_play_anim_t * PI) * 1.15
		var o_grip := 0.48 if is_nervous else 0.28
		var o_pinch := 0.55 if (opp_shake_time > 0.0 or is_nervous) else 0.18
		var o_drum := 5.2 if is_nervous else 2.2
		_animate_3d_hand_rig(opp_glove_left_mesh, t + 1.3, o_grip, o_flick, o_pinch, o_drum, delta)
		_animate_3d_hand_rig(opp_glove_right_mesh, t + 2.1, o_grip, o_flick * 0.5, o_pinch, o_drum, delta)

	if player_hand_light:
		var target_hl := 0.52 if (is_player_turn and not busy_animating) else 0.26
		player_hand_light.light_energy = lerpf(player_hand_light.light_energy, target_hl, 7.0 * delta)
	if table_spot_light:
		var target_sl := 1.90 if (cards_tucked or wager_showcase_boost > 0.1) else (1.72 if (is_player_turn and not busy_animating) else 1.35)
		table_spot_light.light_energy = lerpf(table_spot_light.light_energy, target_sl, 5.5 * delta)
	if hearth_fire_light:
		hearth_fire_light.light_energy = 2.6 + sin(t * 11.0) * 0.35 + cos(t * 17.5) * 0.22
	if tavern_chandelier:
		var ch_extra := sin(t * 5.2) * chandelier_sway_boost * 4.5
		tavern_chandelier.rotation_degrees.z = sin(t * 1.1) * 1.8 + ch_extra
		tavern_chandelier.rotation_degrees.x = cos(t * 0.85) * 1.2 + cos(t * 4.4) * chandelier_sway_boost * 2.8
	for li in range(wall_lantern_roots.size()):
		var wl_node := wall_lantern_roots[li]
		if is_instance_valid(wl_node):
			wl_node.rotation_degrees.z = sin(t * 1.6 + float(li) * 1.3) * (1.1 + chandelier_sway_boost * 2.4)
	var storm_flash := 0.0
	if exterior_vista_theme == "storm_rain":
		storm_flash = pow(maxf(0.0, sin(t * 0.65) * sin(t * 4.3 + 0.7)), 10.0)
	for wl in storm_window_lights:
		if exterior_vista_theme == "sun_mountains":
			wl.light_energy = 2.6 + sin(t * 0.8) * 0.25
		elif exterior_vista_theme == "full_moon":
			wl.light_energy = 2.1 + sin(t * 1.1) * 0.15
		elif exterior_vista_theme == "starry_night":
			wl.light_energy = 1.25
		else:
			wl.light_energy = 1.55 + storm_flash * 5.0
	for lt in exterior_lightning_meshes:
		if is_instance_valid(lt):
			lt.visible = (storm_flash > 0.18)
	for st_n in exterior_twinkle_nodes:
		if is_instance_valid(st_n):
			var phs := float(st_n.get_meta("phase", 0.0))
			var twk := 0.65 + 0.45 * sin(t * 2.8 + phs)
			st_n.scale = Vector3(twk, twk, 1.0)
	for drp in storm_rain_meshes:
		if not drp.visible:
			continue
		var dph: float = drp.get_meta("phase", 0.0)
		var cycle := fmod(t * 2.4 + dph, 1.0)
		drp.position.y = 0.70 - cycle * 1.40
		drp.position.x = float(drp.get_meta("base_x", 0.0)) - cycle * 0.32
	for i in range(lantern_lights.size()):
		lantern_lights[i].light_energy = 1.7 + sin(t * 8.5 + float(i) * 2.1) * 0.22
	if dust_motes_root:
		for m in dust_motes_root.get_children():
			if not m.has_meta("base_pos"):
				continue
			var bp: Vector3 = m.get_meta("base_pos")
			var ph: float = m.get_meta("phase")
			var swirl := table_arcane_spin_boost * 0.08
			m.position = bp + Vector3(sin(t * 0.7 + ph) * (0.07 + swirl), cos(t * 0.55 + ph) * 0.06 + swirl * 0.5, sin(t * 0.45 + ph * 1.3) * (0.07 + swirl))
			var m_sc := 0.72 + 0.42 * sin(t * 3.4 + ph * 1.7)
			m.scale = Vector3(m_sc, m_sc, m_sc)

	for i in range(exterior_pine_nodes.size()):
		var pn := exterior_pine_nodes[i]
		if is_instance_valid(pn):
			pn.rotation_degrees.z = sin(t * 1.45 + float(i) * 0.9) * 2.8

	# Rotating arcane felt rings reacting to Active Suit & Slam Energy
	table_arcane_spin_boost = maxf(0.0, table_arcane_spin_boost - delta * 1.9)
	if table_arcane_outer and table_arcane_inner:
		table_arcane_outer.rotation_degrees.y += (14.0 + table_arcane_spin_boost * 95.0) * delta
		table_arcane_inner.rotation_degrees.y -= (24.0 + table_arcane_spin_boost * 135.0) * delta
		var s_col: Color = _get_suit_obj(active_suit_id).get("col", Color(0.92, 0.72, 0.28))
		if table_arcane_outer.material_override is ShaderMaterial:
			(table_arcane_outer.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(s_col.r, s_col.g, s_col.b, 0.90))
		if table_arcane_inner.material_override is ShaderMaterial:
			(table_arcane_inner.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(s_col.lightened(0.25).r, s_col.lightened(0.25).g, s_col.lightened(0.25).b, 0.85))
	if table_arcane_mat:
		var s_col: Color = _get_suit_obj(active_suit_id).get("col", Color(0.92, 0.72, 0.28))
		var pulse := 0.75 + 0.25 * sin(t * 3.2) + table_arcane_spin_boost * 0.9
		table_arcane_mat.albedo_color = table_arcane_mat.albedo_color.lerp(s_col.lightened(0.15), 5.0 * delta)
		table_arcane_mat.emission = table_arcane_mat.emission.lerp(s_col * pulse, 5.0 * delta)
	var ri := 0
	for k in relic_3d_nodes.keys():
		var rn: Node3D = relic_3d_nodes[k]
		if is_instance_valid(rn):
			var sp := rn.get_node_or_null("RelicModel3D/SpinPivot") as Node3D
			if sp:
				if str(k) in ["REL_CHRONO_P", "REL_STORMCAP"]:
					sp.rotation_degrees.y = t * 28.0 + float(ri) * 55.0
				else:
					sp.rotation_degrees.y = sin(t * 1.1 + float(ri) * 1.3) * 14.0
			var halo_m := rn.get_node_or_null("RelicModel3D/ReadyHalo") as MeshInstance3D
			if halo_m and halo_m.visible and halo_m.material_override is StandardMaterial3D:
				(halo_m.material_override as StandardMaterial3D).emission_energy_multiplier = 1.15 + 0.55 * sin(t * 3.4 + float(ri))
			ri += 1

	if is_instance_valid(draw_deck_beacon):
		var need_draw_beacon := is_player_turn and not busy_animating and (turn_stage == TurnStage.CARD_PLAY or cards_points_revealed) and not _is_hand_tucked() and not _player_has_any_playable_card() and (not tutorial_mode or tutorial_step == 4)
		draw_deck_beacon.visible = need_draw_beacon
		if need_draw_beacon:
			draw_deck_beacon.rotation_degrees.y = fmod(t * 96.0, 360.0)
			var db_sc := 1.0 + sin(t * 5.2) * 0.08
			draw_deck_beacon.scale = Vector3(db_sc, 1.0, db_sc)
	if is_instance_valid(item_review_light):
		var target_irl_energy := 0.65 if cam_view_mode == CameraViewMode.RIVAL_ITEMS else (0.50 if (cam_view_mode == CameraViewMode.TABLE_ITEMS or turn_stage == TurnStage.ITEM_REVIEW) else 0.0)
		var target_irl_pos := Vector3(0.30, 1.38, -0.44) if cam_view_mode == CameraViewMode.RIVAL_ITEMS else Vector3(0.16, 1.38, 0.30)
		item_review_light.light_energy = lerpf(item_review_light.light_energy, target_irl_energy, 7.5 * delta)
		item_review_light.position = item_review_light.position.lerp(target_irl_pos, 8.0 * delta)
	if is_instance_valid(opp_relic_node):
		var osp := opp_relic_node.get_node_or_null("RelicModel3D/SpinPivot") as Node3D
		if osp:
			osp.rotation_degrees.y = t * 22.0

func audio_muted_flag() -> bool:
	return battle_audio_muted or battle_audio_pct <= 0

func _recompute_hand_fan_bases() -> void:
	var p_cnt := player_card_nodes.size()
	var p_mid := (p_cnt - 1) * 0.5
	for i in range(p_cnt):
		var cn := player_card_nodes[i]
		if not is_instance_valid(cn):
			continue
		var spread_x := (i - p_mid) * 0.142
		var arc_y := -absf(i - p_mid) * 0.016
		var depth_z := i * 0.006
		var tilt_z := -(i - p_mid) * 4.6
		cn.set_meta("base_pos", Vector3(spread_x, arc_y, depth_z))
		cn.set_meta("base_rot", Vector3(0.0, 0.0, tilt_z))
		for ch in cn.get_children():
			if ch is Area3D and ch.has_meta("card_index"):
				ch.set_meta("card_index", i)

func _update_3d_hover(mouse_pos: Vector2, delta: float) -> void:
	hovered_card_idx = -1
	hovered_draw_deck = false
	hovered_puf_bottle = false
	hovered_boss_plaque = false
	hovered_tavern_prop = ""

	var raw_vel := (mouse_pos - last_mouse_pos) / maxf(0.001, delta)
	drag_vel_smooth = drag_vel_smooth.lerp(raw_vel, minf(1.0, 14.0 * delta))
	last_mouse_pos = mouse_pos

	if not cam_impact_active and not _is_cinematic_playing() and cam_view_mode != CameraViewMode.CINEMATIC:
		var from := cam.project_ray_origin(mouse_pos)
		var to := from + cam.project_ray_normal(mouse_pos) * 5.0
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		if _is_hand_tucked():
			query.exclude = _get_hand_card_area_rids()
		var hit := space.intersect_ray(query)

		if not hit.is_empty() and hit.has("collider"):
			var col_obj: Object = hit["collider"]
			if col_obj is Area3D:
				if col_obj.has_meta("card_index") and not _is_hand_tucked():
					hovered_card_idx = int(col_obj.get_meta("card_index"))
				elif col_obj.name == "DrawDeckArea":
					hovered_draw_deck = true
				elif col_obj.name == "MagicPufArea" and puf_revealed and magic_puf_bottle and magic_puf_bottle.visible:
					hovered_puf_bottle = true
				elif col_obj.name == "BossPlaqueArea" and is_instance_valid(boss_plaque_root) and boss_plaque_root.visible:
					hovered_boss_plaque = true
				elif col_obj.name == "TavernMugArea":
					hovered_tavern_prop = "mug"
				elif col_obj.name == "TavernCoinsArea":
					hovered_tavern_prop = "coins"
				elif col_obj.name == "TavernDiceArea":
					hovered_tavern_prop = "dice"

	var vp_s := get_viewport().get_visible_rect().size
	var m_norm := Vector2((mouse_pos.x / maxf(1.0, vp_s.x)) - 0.5, (mouse_pos.y / maxf(1.0, vp_s.y)) - 0.5)

	# Handle live Drag-to-Reorder & Magnetic Spring-Physics Card Dragging
	if lmb_down and drag_card_idx >= 0 and drag_card_idx < player_hand.size() and not busy_animating and not _is_hand_tucked():
		hovered_card_idx = drag_card_idx
		if drag_active and mouse_pos.y > vp_s.y * 0.56 and player_hand.size() > 1:
			var p_mid := float(player_hand.size() - 1) * 0.5
			var target_slot := clampi(int(round(m_norm.x * 6.8 + p_mid)), 0, player_hand.size() - 1)
			if target_slot != drag_card_idx:
				var tmp_c: Dictionary = player_hand[drag_card_idx]
				player_hand[drag_card_idx] = player_hand[target_slot]
				player_hand[target_slot] = tmp_c
				var tmp_n: Node3D = player_card_nodes[drag_card_idx]
				player_card_nodes[drag_card_idx] = player_card_nodes[target_slot]
				player_card_nodes[target_slot] = tmp_n
				for si_k in range(staged_card_indices.size()):
					if staged_card_indices[si_k] == drag_card_idx:
						staged_card_indices[si_k] = target_slot
					elif staged_card_indices[si_k] == target_slot:
						staged_card_indices[si_k] = drag_card_idx
				_recompute_hand_fan_bases()
				drag_card_idx = target_slot
				hovered_card_idx = target_slot
				prev_hovered_idx = target_slot
				emit_signal("play_sfx_pitched_requested", "card_hover", 1.05 + float(target_slot) * 0.05)

	if not busy_animating:
		if is_instance_valid(boss_plaque_root):
			boss_plaque_root.scale = boss_plaque_root.scale.lerp(Vector3(1.08, 1.08, 1.08) if hovered_boss_plaque else Vector3.ONE, 12.0 * delta)

	if hovered_card_idx != prev_hovered_idx:
		if hovered_card_idx >= 0 and not busy_animating:
			emit_signal("play_sfx_requested", "card_hover")
		prev_hovered_idx = hovered_card_idx

	# Update Live Card Inspector Tooltip + Real-Time Hover Score Preview!
	if hover_inspect_panel and not _is_hand_tucked() and not peddler_open and hovered_card_idx >= 0 and hovered_card_idx < player_hand.size():
		if not tutorial_mode or cards_points_revealed:
			var hc: Dictionary = player_hand[hovered_card_idx]
			var hs: Dictionary = _get_suit_obj(hc["suit"])
			var hp_id: String = str(hc.get("power_id", ""))
			var hcls_id := Catalog.normalize_card_class(str(hc.get("edition", "NORMAL")))
			var hed: Dictionary = Catalog.get_card_class_loc(hcls_id, opts_language)
			var ed_tag: String = (" [%s]" % hed["name"]) if hcls_id != "NORMAL" else ""
			var is_deb := _is_card_debuffed_by_boss(hc, staged_card_indices.size() >= 1)
			var hp_loc := Catalog.get_power_card_loc(hp_id, opts_language) if hp_id != "" else {}
			var disp_rname := str(hp_loc.get("name", hc["rname"])) if hp_id != "" else _get_rank_name(str(hc["rank"]))
			hover_inspect_title.text = "%s %s%s%s" % [hs["sym"], disp_rname, ed_tag, _tr(" [TAX]", " [DAŇ]") if is_deb else ""]

			# Calculate real-time projected score before committing a slam!
			var rem_hand: Array = []
			for hi in range(player_hand.size()):
				if hi != hovered_card_idx:
					rem_hand.append(player_hand[hi])
			var lead_suit := str(hc.get("suit", active_suit_id))
			var p_flow := (last_player_play_suit != "" and (lead_suit == last_player_play_suit or str(hc.get("rank", "")) == last_player_play_rank))
			var p_ctx := {
				"tutorial_mode": tutorial_mode,
				"tutorial_step": tutorial_step,
				"chosen_suit": lead_suit,
				"prev_suit": active_suit_id,
				"pending_draw_before": pending_draw,
				"pending_skip_before": pending_skip,
				"storm_surge_mult": storm_surge_mult,
				"echo_card": _get_last_echo_card(),
				"relic_scales": match_relic_scales,
				"shop_rerolls": run_shop_rerolls,
				"match_turn_count": match_turn_count + 1,
				"rival_hand_size": ai_hand.size(),
				"boss_mod": active_boss_mod,
				"campaign_difficulty": active_campaign_difficulty,
				"flow_chain": p_flow,
				"target_score": target_score,
				"duel_chalice_mult": duel_chalice_mult,
				"duel_whetstone_stacks": duel_whetstone_stacks,
				"duel_next_xmult": duel_next_xmult,
				"blood_seal_active": table_relic_blood_seal_active,
				"hollow_mask_active": table_relic_hollow_mask_active,
				"surge_mult": storm_surge_mult,
				"is_preview": true,
				"lang": opts_language,
			}
			var prev_res := ScoreEng.calculate_hand_score([hc], relic_mgr.get_effective_passive_relics(run_active_relics), rem_hand, p_ctx)
			var p_chips := int(prev_res["total_chips"])
			var p_flat := float(prev_res["flat_mult"])
			var p_xm := float(prev_res["x_mult_product"])
			var p_eff := float(prev_res["effective_mult"])
			var p_tot := int(prev_res["final_score"])
			hover_inspect_sub.text = "%s" % str(prev_res.get("formula_summary", "+%s pts" % _format_pts_ui(p_tot)))
			if staged_card_indices.is_empty() and hud_combo_revealed and is_player_turn and not busy_animating:
				if _can_play(hc):
					_update_combo_hud(_tr("PREVIEW: %s", "NÁHLED: %s") % disp_rname.to_upper(), p_chips, p_flat, p_tot, false, p_xm)
					_set_score_breakdown_chips(prev_res.get("breakdown_chips", []))
					preview_hud_active = true
				elif preview_hud_active:
					preview_hud_active = false
					_update_combo_hud(_tr("CARD × COUNT", "KARTA × POČET"), 0, 1.0, 0, false, 1.0)
					_set_score_breakdown_chips([])

			var is_plain_normal := (not tutorial_mode) and (hp_id == "") and (hcls_id == "NORMAL") and (not is_deb)
			if is_plain_normal:
				hover_inspect_panel.visible = false
			else:
				var desc_parts: Array[String] = []
				if hp_id != "":
					desc_parts.append(str(hp_loc.get("desc", hc.get("desc", ""))))
				elif hcls_id == "MERCHANT":
					desc_parts.append(_tr("Merchant — +5 pts & +15g Florins.", "Kupec — +5 b. a +15g při zahrání."))
				elif tutorial_mode:
					var r_ab := ScoreEng.get_rank_ability_info(str(hc["rank"]), opts_language)
					if not r_ab.is_empty():
						desc_parts.append("%s — %s" % [str(r_ab.get("badge", "")), str(r_ab.get("desc", ""))])
				if hcls_id == "MAGE":
					var mc := int(hc.get("mage_charge", 0))
					var mmax := int(hed.get("max_charge", 2))
					desc_parts.append(_tr("Mage %d/%d — %s" % [mc, mmax, "READY (+20 & ×2)!" if mc >= mmax else "Charges in hand (+5 now)."], "Mág %d/%d — %s" % [mc, mmax, "PŘIPRAVEN (+20 a ×2)!" if mc >= mmax else "Nabíjí se (+5 b.)."]))
				elif hcls_id != "NORMAL" and hcls_id != "MERCHANT":
					desc_parts.append("✦ %s: %s" % [hed["name"], hed["desc"]])
				if is_deb:
					desc_parts.append("%s: %s" % [active_boss_mod.replace("_", " "), _get_boss_counterplay_tip()])
				elif tutorial_mode and desc_parts.is_empty():
					desc_parts.append(_tr("Stack 8s (∞) or up to 3 Aces! Right-click for Combo.", "Skákej Osmičky (∞) nebo až 3 Esa! Pravým klikem tvoř kombo."))
				hover_inspect_desc.text = "\n".join(desc_parts)
				hover_inspect_panel.visible = true
	elif hover_inspect_panel and not _is_hand_tucked() and hovered_boss_plaque and active_boss_mod != "":
		hover_inspect_title.text = _tr("BOSS EDICT: %s", "PRAVIDLO BOSSE: %s") % active_boss_mod.replace("_", " ")
		hover_inspect_sub.text = _get_stage_name_loc()
		hover_inspect_desc.text = "%s\n%s" % [_get_boss_desc_loc(), _get_boss_counterplay_tip()]
		hover_inspect_panel.visible = true
	elif hover_inspect_panel and (_is_hand_tucked() or peddler_open or (hovered_card_idx < 0 and not hovered_boss_plaque)):
		hover_inspect_panel.visible = false
		if staged_card_indices.is_empty() and preview_hud_active and not busy_animating:
			preview_hud_active = false
			_update_combo_hud(_tr("SCORE = CARD × COUNT", "SKÓRE = KARTA × POČET"), 0, 1.0, 0, false, 1.0)

	for i in range(player_card_nodes.size()):
		var c_node := player_card_nodes[i]
		if not is_instance_valid(c_node):
			continue
		var b_pos: Vector3 = c_node.get_meta("base_pos")
		var b_rot: Vector3 = c_node.get_meta("base_rot")
		var is_staged := i in staged_card_indices
		var is_playable := bool(c_node.get_meta("is_playable", false))
		# Magnetic Balatro fan spacing: neighbor cards nudge smoothly aside on hover
		var push_x := 0.0
		if hovered_card_idx >= 0 and i != hovered_card_idx:
			var dist_i := absf(float(i - hovered_card_idx))
			if dist_i <= 2.5:
				push_x = signf(float(i - hovered_card_idx)) * (0.042 / dist_i)

		var c_cls := str(c_node.get_meta("card_class_id", "NORMAL"))
		var is_knight_heavy := (c_cls == "KNIGHT")
		var is_mage_float := (c_cls == "MAGE")
		var float_bob := Vector3(0.0, sin(float(Time.get_ticks_msec()) * 0.0038 + float(i) * 1.1) * 0.011, 0.0) if is_mage_float else Vector3.ZERO
		var hov_spd := (7.6 if is_knight_heavy else 16.5) * delta
		var rest_spd := (7.2 if is_knight_heavy else 13.0) * delta

		if lmb_down and drag_active and i == drag_card_idx:
			var in_arena_drop := mouse_pos.y <= vp_s.y * 0.56
			if in_arena_drop:
				table_arcane_spin_boost = maxf(table_arcane_spin_boost, 0.85)
			var drag_local := Vector3(
				clampf(m_norm.x * 0.96, -0.56, 0.56),
				clampf(-m_norm.y * 0.48 + 0.06, -0.04, 0.36),
				0.13 if in_arena_drop else 0.095
			)
			c_node.position = c_node.position.lerp(drag_local, (12.0 if is_knight_heavy else 22.0) * delta)
			var bank_rot := Vector3(
				-6.0 - clampf(drag_vel_smooth.y * 0.015, -18.0, 18.0),
				clampf(drag_vel_smooth.x * 0.018, -22.0, 22.0),
				-clampf(drag_vel_smooth.x * 0.022, -24.0, 24.0)
			)
			c_node.rotation_degrees = c_node.rotation_degrees.lerp(bank_rot, (11.0 if is_knight_heavy else 18.0) * delta)
			var d_scale := Vector3(1.28, 1.28, 1.28) if in_arena_drop else Vector3(1.24, 1.24, 1.24)
			c_node.scale = c_node.scale.lerp(d_scale, 18.0 * delta)
		elif i == hovered_card_idx:
			var lift_y := (0.064 if is_knight_heavy else (0.104 if is_mage_float else (0.092 if is_staged else 0.080)))
			var lift_pos := b_pos + Vector3(0.0, lift_y, 0.078) + float_bob
			c_node.position = c_node.position.lerp(lift_pos, hov_spd)
			var tilt_scale := 0.65 if is_knight_heavy else 1.0
			var tilt_rot := Vector3(-3.0 - m_norm.y * 8.0 * tilt_scale, m_norm.x * 11.0 * tilt_scale, 0.0)
			c_node.rotation_degrees = c_node.rotation_degrees.lerp(tilt_rot, hov_spd)
			c_node.scale = c_node.scale.lerp(Vector3(1.24, 1.24, 1.24) if is_knight_heavy else Vector3(1.22, 1.22, 1.22), hov_spd)
		elif is_staged:
			c_node.position = c_node.position.lerp(b_pos + Vector3(push_x * 0.5, 0.052, 0.036) + float_bob, rest_spd)
			c_node.rotation_degrees = c_node.rotation_degrees.lerp(b_rot * 0.45, rest_spd)
			c_node.scale = c_node.scale.lerp(Vector3(1.10, 1.10, 1.10), rest_spd)
		else:
			c_node.position = c_node.position.lerp(b_pos + Vector3(push_x, 0.0, 0.0) + float_bob, rest_spd)
			c_node.rotation_degrees = c_node.rotation_degrees.lerp(b_rot, rest_spd)
			c_node.scale = c_node.scale.lerp(Vector3.ONE, rest_spd)

		var face_mesh := c_node.get_node_or_null("CardFaceMesh") as MeshInstance3D
		if face_mesh and face_mesh.material_override is ShaderMaterial:
			var sm: ShaderMaterial = face_mesh.material_override
			var target_glow := 1.0 if i == hovered_card_idx else (0.72 if is_staged else (0.20 if is_playable else 0.0))
			var base_cam_tilt := Vector2(
				clampf(-cam.rotation_degrees.y * 0.018, -0.45, 0.45),
				clampf((cam.rotation_degrees.x - base_cam_rot.x) * 0.018, -0.45, 0.45)
			)
			var card_tilt := (Vector2(m_norm.x, m_norm.y) * 1.15) if i == hovered_card_idx else (Vector2(b_rot.z * 0.014, 0.08) if is_staged else Vector2(b_rot.z * 0.008, 0.0))
			sm.set_shader_parameter("hover_glow", target_glow)
			sm.set_shader_parameter("tilt_vec", base_cam_tilt + card_tilt)
			sm.set_shader_parameter("playable", 1.0 if (is_playable or is_staged or i == hovered_card_idx) else 0.0)
		var c_shadow := c_node.get_node_or_null("ContactShadow") as MeshInstance3D
		if c_shadow:
			var lift := clampf((c_node.scale.x - 1.0) / 0.24, 0.0, 1.0)
			c_shadow.position = Vector3(0.010 + lift * 0.018, -0.012 - lift * 0.022, -0.004 - lift * 0.02)
			c_shadow.scale = Vector3.ONE * (1.0 + lift * 0.18)
			var shm := c_shadow.material_override as StandardMaterial3D
			if shm:
				shm.albedo_color.a = lerpf(0.42, 0.20, lift)

func _get_staged_base_rank() -> String:
	for si in staged_card_indices:
		if si >= 0 and si < player_hand.size():
			var sc: Dictionary = player_hand[si]
			if not bool(sc.get("wild", false)):
				return str(sc["rank"])
	return ""

func _is_staged_slam_valid() -> bool:
	if staged_card_indices.is_empty():
		return false
	var any_playable := false
	var base_rank := ""
	var aces_count := 0
	for idx in staged_card_indices:
		if idx < 0 or idx >= player_hand.size():
			return false
		var c: Dictionary = player_hand[idx]
		if _can_play(c):
			any_playable = true
		var is_wild := bool(c.get("wild", false))
		var r: String = str(c["rank"])
		if r == "E":
			aces_count += 1
		if not is_wild:
			if base_rank == "":
				base_rank = r
			elif r != base_rank and not (base_rank == "PWR" and r == "PWR"):
				return false
	if aces_count > 3:
		return false
	if staged_card_indices.size() >= 2:
		# Rank 8 (Chain Linker) or up to 3 Aces ("E") among standard cards can be stacked into a multi-card Slam!
		if base_rank != "" and base_rank != "8" and base_rank != "E" and base_rank != "PWR":
			return false
	return any_playable

func _toggle_stage_card(idx: int) -> void:
	if not is_player_turn or busy_animating or _is_hand_tucked():
		return
	if idx < 0 or idx >= player_hand.size():
		return
	if idx in staged_card_indices:
		staged_card_indices.erase(idx)
		emit_signal("play_sfx_requested", "card_hover")
		_rebuild_all_3d_hands()
		_refresh_table_labels()
		return

	var card: Dictionary = player_hand[idx]
	if str(card["rank"]) == "E":
		var ace_cnt := 0
		for si in staged_card_indices:
			if si >= 0 and si < player_hand.size() and str(player_hand[si].get("rank", "")) == "E":
				ace_cnt += 1
		if ace_cnt >= 3:
			emit_signal("play_sfx_requested", "error")
			table_status_label3d.text = _tr("Max 3 Aces allowed at once (4 Aces is too OP)!", "Max 3 Esa najednou (4 Esa jsou moc OP)!")
			_spawn_score_popup(_tr("MAX 3 ACES!", "MAX 3 ESA!"), Color(1.0, 0.36, 0.32), true)
			return
	if tutorial_mode:
		if staged_card_indices.is_empty():
			if str(card["rank"]) != "8" and str(card["rank"]) != "E" and not bool(card.get("wild", false)):
				emit_signal("play_sfx_requested", "error")
				table_status_label3d.text = _tr("Only 8s or up to 3 Aces can be stacked together!", "Řetězit lze jen Osmičky nebo max 3 Esa!")
				return
			if not _can_play(card):
				emit_signal("play_sfx_requested", "error")
				table_status_label3d.text = _tr("Cannot start combo: card must match active suit or rank!", "Nelze začít kombo: karta musí pasovat na barvu nebo hodnotu!")
				return
		else:
			if str(card["rank"]) != "8" and str(card["rank"]) != "E" and not bool(card.get("wild", false)):
				emit_signal("play_sfx_requested", "error")
				table_status_label3d.text = _tr("Only 8s or up to 3 Aces can be stacked together!", "Řetězit lze jen Osmičky nebo max 3 Esa!")
				return
	else:
		# Outside tutorial: allow staging playable 8-Chains, up to 3 Aces (including Wilds) OR staging up to 4 cards for Redraw!
		if staged_card_indices.size() >= 4:
			emit_signal("play_sfx_requested", "error")
			table_status_label3d.text = _tr("Maximum 4 cards can be staged at once.", "Najednou lze označit maximálně 4 karty.")
			return

	staged_card_indices.append(idx)
	emit_signal("play_sfx_pitched_requested", "card_deal", 1.0 + float(staged_card_indices.size() - 1) * 0.16)
	_rebuild_all_3d_hands()
	_refresh_table_labels()

func _launch_staged_stack() -> void:
	if not is_player_turn or busy_animating or staged_card_indices.is_empty():
		return
	if tutorial_mode and tutorial_step == 4 and staged_card_indices.size() < 2:
		_whisper_tutorial_nudge(_tr("Stage both EIGHTS (8) before playing the Combo!", "Označ obě OSMIČKY (8) před zahráním komba!"))
		return
	if tutorial_mode and tutorial_step == 5 and staged_card_indices.size() < 2:
		_whisper_tutorial_nudge(_tr("Stage both ACES (E) to deal -4 ♥ HP!", "Označ obě ESA (E) pro úder -4 ♥ HP!"))
		return
	if tutorial_mode and tutorial_step == 0:
		_whisper_tutorial_nudge(_tr("Press [SPACE] to begin!", "Stiskni [SPACE] pro začátek!"))
		return
	if not _is_staged_slam_valid():
		emit_signal("play_sfx_requested", "error")
		var staged_aces := 0
		for si in staged_card_indices:
			if si >= 0 and si < player_hand.size() and str(player_hand[si].get("rank", "")) == "E":
				staged_aces += 1
		if staged_aces >= 4:
			table_status_label3d.text = _tr("Cannot play 4 Aces at once (Max 3 Aces = 6 ♥ HP DMG)!", "Nelze zahrát 4 Esa najednou (Max 3 Esa = 6 ♥ HP)!")
		else:
			table_status_label3d.text = _tr("Stack 8s or up to 3 Aces for a Combo — or click REDRAW.", "Skákej Osmičky nebo max 3 Esa — nebo klikni REDRAW.")
		return
	var idxs := staged_card_indices.duplicate()
	idxs.sort()
	var needs_suit_pick := false
	var echo_c := _get_last_echo_card()
	for si in idxs:
		var lc: Dictionary = player_hand[si]
		var lpid := str(lc.get("power_id", ""))
		if str(lc["rank"]) == "H" or lpid == "SPEC_ORACLE" or (lpid == "SPEC_MIRROR" and (str(echo_c.get("rank", "")) == "H" or str(echo_c.get("power_id", "")) == "SPEC_ORACLE")):
			needs_suit_pick = true
			break
	if needs_suit_pick:
		emit_signal("play_sfx_requested", "ui_click")
		pending_play_indices = idxs
		suit_modal.visible = true
		return
	var last_card: Dictionary = player_hand[idxs[idxs.size() - 1]]
	_play_player_cards_3d(idxs, str(last_card["suit"]))

func _redraw_staged_cards() -> void:
	if tutorial_mode or not is_player_turn or busy_animating or redraws_left <= 0 or player_hand.is_empty():
		if redraws_left <= 0 and not tutorial_mode:
			emit_signal("play_sfx_requested", "error")
			table_status_label3d.text = _tr("No Redraws remaining this duel!", "V tomto souboji už nemáš další výměnu!")
		return
	var idxs: Array[int] = staged_card_indices.duplicate()
	if idxs.is_empty():
		# Smart auto-pick up to 3 unplayable normal cards first (keeping Power Cards & Editions safe!)
		for i in range(player_hand.size()):
			var hc: Dictionary = player_hand[i]
			if not _can_play(hc) and str(hc.get("power_id", "")) == "" and Catalog.normalize_card_class(str(hc.get("edition", "NORMAL"))) == "NORMAL":
				idxs.append(i)
				if idxs.size() >= 3:
					break
		if idxs.is_empty():
			for i in range(player_hand.size()):
				if not _can_play(player_hand[i]):
					idxs.append(i)
					if idxs.size() >= 3:
						break
		if idxs.is_empty():
			idxs.append(0)
	idxs.sort()
	staged_card_indices.clear()
	redraws_left -= 1
	for k in range(idxs.size() - 1, -1, -1):
		var rem_i := idxs[k]
		if rem_i >= 0 and rem_i < player_hand.size():
			var old_c: Dictionary = player_hand[rem_i]
			player_hand.remove_at(rem_i)
			deck.push_front(old_c)
	deck.shuffle()
	var repl_cnt := idxs.size()
	for _r in range(repl_cnt):
		player_hand.append(_draw_from_deck())
	emit_signal("play_sfx_requested", "card_shuffle")
	_spawn_score_popup(_tr("REDREW %d CARDS!" % repl_cnt, "VYMĚNĚNO %d KARET!" % repl_cnt), Color(0.45, 0.96, 1.0), true)
	table_status_label3d.text = _tr("Mulligan! Swapped %d card(s) — %d Redraw(s) left.", "Výměna! Vyměněno %d karet — zbývá %d×.") % [repl_cnt, redraws_left]
	_rebuild_all_3d_hands()
	_animate_deal_pop_in()
	_refresh_table_labels()
	if not tutorial_mode:
		_check_battle_unlock_tips()

func _get_active_bet_summary() -> String:
	if active_wager_type == "SWORD":
		return _tr("SWORD +100g", "MEČ +100g")
	elif active_wager_type == "ITEM":
		return _tr("PHIAL +45g", "BAŇKA +45g")
	return _tr("%dg STAKE", "SÁZKA %dg") % wager_gold_amount

func _refresh_peek_hud_text() -> void:
	if not peek_hud_lbl:
		return
	var s_obj := _get_suit_obj(active_suit_id)
	var top_txt := "Empty"
	if not discard_pile.is_empty():
		var tc: Dictionary = discard_pile.back()
		if bool(tc.get("_mist_hidden", false)):
			top_txt = "? IN BATTLE MIST ?"
		else:
			var ts := _get_suit_obj(str(tc.get("suit", active_suit_id)))
			var ed_id := Catalog.normalize_card_class(str(tc.get("edition", "NORMAL")))
			var ed_suf := (" [%s]" % ed_id) if ed_id != "NORMAL" else ""
			top_txt = "%s %s%s" % [ts["sym"], str(tc.get("rname", tc.get("rank", "?"))), ed_suf]
	var mode_tag := _tr("RIVAL ITEMS", "SOUPEŘOVY PŘEDMĚTY") if cam_view_mode == CameraViewMode.RIVAL_ITEMS else (_tr("ITEMS • CONTINUE [SPACE]", "PŘEDMĚTY • POKRAČOVAT [SPACE]") if turn_stage == TurnStage.ITEM_REVIEW else _tr("ITEMS [SPACE] • PLAY [W]", "PŘEDMĚTY [SPACE] • HRÁT [W]"))
	peek_hud_lbl.text = "%s  •  Top: %s  •  Suit: %s %s  •  Bet: %s  •  Pile: %d" % [mode_tag, top_txt, s_obj["sym"], s_obj["name"], _get_active_bet_summary(), discard_pile.size()]

func _animate_wager_showcase_3d(emit_fx: bool = true) -> void:
	wager_showcase_boost = 1.0
	suit_pulse_age = 0.0
	table_arcane_spin_boost = maxf(table_arcane_spin_boost, 1.15)
	chandelier_sway_boost = maxf(chandelier_sway_boost, 0.72)
	if active_wager_type == "SWORD" and is_instance_valid(player_sword_root):
		var sw_bp := Vector3(-0.56, 0.824, 0.44)
		var sw_tw := player_sword_root.create_tween()
		sw_tw.tween_property(player_sword_root, "position", sw_bp + Vector3(0.0, 0.11, 0.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		sw_tw.parallel().tween_property(player_sword_root, "rotation_degrees:z", 12.0, 0.18)
		sw_tw.tween_property(player_sword_root, "position", sw_bp, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		sw_tw.parallel().tween_property(player_sword_root, "rotation_degrees:z", 0.0, 0.34)
		if emit_fx:
			Fx.burst(self, sw_bp + Vector3(0.0, 0.06, 0.0), Color(1.0, 0.28, 0.22), 14, 0.55, 0.42, 0.02, 0.3, true, 120.0)
	elif active_wager_type == "ITEM" and is_instance_valid(magic_puf_bottle):
		var pb := Vector3(0.76, 0.815, 0.34)
		var ptw := magic_puf_bottle.create_tween()
		ptw.tween_property(magic_puf_bottle, "position", pb + Vector3(0.0, 0.09, 0.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(magic_puf_bottle, "rotation_degrees:y", 180.0, 0.26)
		ptw.tween_property(magic_puf_bottle, "position", pb, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		ptw.parallel().tween_property(magic_puf_bottle, "rotation_degrees:y", 360.0, 0.26)
		ptw.tween_callback(func():
			if is_instance_valid(magic_puf_bottle):
				magic_puf_bottle.rotation_degrees.y = 0.0
		)
		if emit_fx:
			Fx.burst(self, pb + Vector3(0.0, 0.10, 0.0), Color(0.76, 0.44, 1.0), 14, 0.55, 0.42, 0.02, 0.3, true, 120.0)
	elif is_instance_valid(tavern_coins_root):
		var ctw := tavern_coins_root.create_tween()
		ctw.tween_property(tavern_coins_root, "position:y", 0.885, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ctw.parallel().tween_property(tavern_coins_root, "rotation_degrees:y", tavern_coins_root.rotation_degrees.y + 180.0, 0.44)
		ctw.tween_property(tavern_coins_root, "position:y", 0.816, 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if emit_fx:
			emit_signal("play_sfx_pitched_requested", "prop_coins", randf_range(0.96, 1.08))
			Fx.gold_flakes(self, tavern_coins_root.global_position + Vector3(0.0, 0.06, 0.0), 12, 0.48)

func _trigger_glove_play_lunge() -> void:
	glove_lunge_boost = 1.0

func _animate_hand_return_wave() -> void:
	for i in range(player_card_nodes.size()):
		var c_node := player_card_nodes[i]
		if not is_instance_valid(c_node):
			continue
		c_node.scale = Vector3(0.84, 0.84, 0.84)
		var dly := float(i) * 0.032
		var tw := c_node.create_tween()
		tw.tween_interval(dly)
		tw.tween_property(c_node, "scale", Vector3(1.06, 1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c_node, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _trigger_turn_table_bet_glance(quiet_sfx: bool = false) -> void:
	_begin_player_item_review_stage(not quiet_sfx)

func _find_best_playable_idx_for_w() -> int:
	if tutorial_mode and tutorial_step == 2:
		for i in range(player_hand.size()):
			if str(player_hand[i].get("rank", "")) == "10" and _can_play(player_hand[i]):
				return i
	if tutorial_mode and tutorial_step == 3:
		for i in range(player_hand.size()):
			if str(player_hand[i].get("rank", "")) == "7" and _can_play(player_hand[i]):
				return i
		return -1
	if tutorial_mode and tutorial_step == 4:
		for i in range(player_hand.size()):
			if str(player_hand[i].get("rank", "")) == "8" and not (i in staged_card_indices):
				return i
		return -1
	if tutorial_mode and tutorial_step == 5:
		for i in range(player_hand.size()):
			if str(player_hand[i].get("rank", "")) == "E" and not (i in staged_card_indices):
				return i
		return -1
	if tutorial_mode and tutorial_step == 6:
		for i in range(player_hand.size()):
			if str(player_hand[i].get("power_id", "")) == "SPEC_VAMPIRE":
				return i
		return -1
	for i in range(player_hand.size()):
		if _can_play(player_hand[i]):
			return i
	return -1

func _cancel_suit_modal() -> void:
	if suit_modal:
		suit_modal.visible = false
	pending_play_indices.clear()
	pending_hornik_idx = -1
	busy_animating = false
	emit_signal("play_sfx_requested", "ui_click")
	_rebuild_all_3d_hands()

func _unhandled_input(event: InputEvent) -> void:
	if victory_summary_overlay and victory_summary_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_battle_session_token += 1
			victory_summary_overlay.visible = false
			emit_signal("exit_to_map_requested")
			get_viewport().set_input_as_handled()
		return
	if card_guide_modal and card_guide_modal.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_F1]:
			_toggle_card_guide_modal(false)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		if visible and not _is_cinematic_playing():
			_toggle_card_guide_modal(true)
			get_viewport().set_input_as_handled()
		return
	if visible and suit_modal and suit_modal.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_suit_modal()
			get_viewport().set_input_as_handled()
		return
	if not visible or mist_guess_open or thief_heist_open:
		return
	if _is_cinematic_playing():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			cinematic_director.call("skip_current")
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cinematic_director.call("skip_current")
			get_viewport().set_input_as_handled()
			return
		return
	if peddler_open or shop_gate_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if shop_gate_open:
				_close_shop_gate_prompt(false)
			else:
				_close_peddler_shop()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if suit_modal and suit_modal.visible:
				pass
			else:
				emit_signal("play_sfx_requested", "ui_click")
				emit_signal("open_options_requested")
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB:
			toggle_camera_view_mode(true)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_L:
			if combat_log_drawer != null:
				combat_log_drawer.toggle()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SPACE:
			if unlock_tip_panel and unlock_tip_panel.visible:
				_dismiss_unlock_tip()
				get_viewport().set_input_as_handled()
				return
			if tutorial_mode and (tutorial_step == 0 or tutorial_step >= 8):
				var hw := _get_handwriting_progress(tutorial_ghost_center_lbl)
				if bool(hw.get("active", false)):
					_finish_handwriting_anim(tutorial_ghost_center_lbl)
				else:
					_advance_tutorial_substep()
				get_viewport().set_input_as_handled()
				return
			if is_player_turn and not busy_animating and turn_stage == TurnStage.ITEM_REVIEW and not tutorial_mode:
				_confirm_item_review_to_cards(true)
				get_viewport().set_input_as_handled()
				return
			toggle_camera_view_mode(true)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_W:
			if not is_player_turn or busy_animating:
				get_viewport().set_input_as_handled()
				return
			if turn_stage == TurnStage.ITEM_REVIEW and not tutorial_mode:
				_show_stagger_callout(_tr("Inspect items or press [SPACE] to switch to cards!", "Prohlédni předměty nebo stiskni [SPACE] pro karty!"), Color(0.98, 0.84, 0.42), 1.05)
				emit_signal("play_sfx_requested", "ui_click")
				get_viewport().set_input_as_handled()
				return
			if cards_tucked:
				get_viewport().set_input_as_handled()
				return
			if tutorial_mode and tutorial_step == 0:
				_advance_tutorial_substep()
				get_viewport().set_input_as_handled()
				return
			if tutorial_mode and tutorial_step == 1:
				if tutorial_substep == 0:
					_whisper_tutorial_nudge(_tr("Try vetoing your opening hand first: press [V] or click Veto Hand!", "Nejdřív si vyzkoušej výměnu úvodní ruky: stiskni [V] nebo klikni na Vetovat karty!"))
				elif tutorial_substep == 1:
					_whisper_tutorial_nudge(_tr("Press [TAB] or [SPACE] to switch to 3D Table Items and click your Sword!", "Stiskni [TAB] nebo [SPACE] pro přepnutí na 3D Stůl a klikni na Meč!"))
				else:
					_whisper_tutorial_nudge(_tr("Wager staked! Press [TAB] or [SPACE] to return to your cards.", "Sázka je uzavřena! Stiskni [TAB] nebo [SPACE] pro návrat ke kartám."))
				get_viewport().set_input_as_handled()
				return
			if tutorial_mode and tutorial_step == 4:
				for i8 in range(player_hand.size()):
					if str(player_hand[i8].get("rank", "")) == "8" and not (i8 in staged_card_indices):
						staged_card_indices.append(i8)
				if staged_card_indices.size() >= 2 and _is_staged_slam_valid():
					_trigger_glove_play_lunge()
					_launch_staged_stack()
				else:
					_whisper_tutorial_nudge(_tr("Stage both Eights (8) for this combo!", "Označ obě Osmičky (8) pro toto kombo!"))
				get_viewport().set_input_as_handled()
				return
			if tutorial_mode and tutorial_step == 5:
				for ie in range(player_hand.size()):
					if str(player_hand[ie].get("rank", "")) == "E" and not (ie in staged_card_indices):
						staged_card_indices.append(ie)
				if staged_card_indices.size() >= 2 and _is_staged_slam_valid():
					_trigger_glove_play_lunge()
					_launch_staged_stack()
				else:
					_whisper_tutorial_nudge(_tr("Stage both Aces (E) to strike for -4 ♥ HP!", "Označ obě Esa (E) pro úder za -4 ♥ HP!"))
				get_viewport().set_input_as_handled()
				return
			if tutorial_mode and tutorial_step == 6 and tutorial_substep == 1:
				_whisper_tutorial_nudge(_tr("First toss the 3D Hellfire Phial IGNIS on the right side of the table!", "Nejdřív vyzkoušej 3D Baňku pekelného ohně IGNIS vpravo na stole!"))
				get_viewport().set_input_as_handled()
				return
			if not staged_card_indices.is_empty():
				_trigger_glove_play_lunge()
				_launch_staged_stack()
				get_viewport().set_input_as_handled()
				return
			var play_idx := hovered_card_idx if (hovered_card_idx >= 0 and hovered_card_idx < player_hand.size() and _can_play(player_hand[hovered_card_idx])) else _find_best_playable_idx_for_w()
			if play_idx >= 0:
				_trigger_glove_play_lunge()
				_handle_card_click_or_drop(play_idx, true)
			elif not tutorial_mode:
				_player_draw_from_3d_deck()
				_trigger_glove_play_lunge()
			else:
				_whisper_tutorial_nudge(_tr("Follow the task above first!", "Splň nejdřív úkol nahoře!"))
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_M and not tutorial_mode:
			_redraw_staged_cards()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_V and not opening_turn_committed and not opening_veto_used and ((not tutorial_mode) or (tutorial_step == 1 and tutorial_substep == 0)):
			_perform_opening_veto_hand()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_1 and not tutorial_mode:
			_sort_player_hand("rank")
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_2 and not tutorial_mode:
			_sort_player_hand("suit")
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_3 and not tutorial_mode:
			_sort_player_hand("power")
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_F8:
			var cycle_modes := [0, 2, 3]
			var cur_pos := cycle_modes.find(woodcut_print_mode)
			var next_mode: int = cycle_modes[(cur_pos + 1) % cycle_modes.size()] if cur_pos >= 0 else 3
			set_print_mode(next_mode)
			emit_signal("print_mode_changed", woodcut_print_mode)
			emit_signal("play_sfx_requested", "ui_click")
			var mode_names := ["WOODCUT INK", "3D", "3D", "ULTRA DETAILED"]
			_show_stagger_callout("STYLE: " + mode_names[woodcut_print_mode] + " [F8]", Color(0.96, 0.84, 0.46), 1.18)
			if stagger_callout_tween and stagger_callout_tween.is_valid():
				stagger_callout_tween.tween_interval(1.3)
				stagger_callout_tween.tween_property(stagger_callout_pill, "modulate:a", 0.0, 0.35)
				stagger_callout_tween.tween_callback(func():
					if stagger_callout_pill:
						stagger_callout_pill.visible = false
				)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# Right-click toggles card in/out of Combo Stack ONLY when hovering a hand card
			if not busy_animating and is_player_turn and not _is_hand_tucked() and hovered_card_idx >= 0:
				_toggle_stage_card(hovered_card_idx)
				rmb_down = false
				return
		else:
			rmb_down = false
			return

	if event is InputEventMouseMotion and lmb_down and drag_card_idx >= 0 and not busy_animating and not _is_hand_tucked():
		if (event.position - drag_start_mouse).length() > 9.0:
			drag_active = true
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if lmb_down:
			var c_idx := drag_card_idx
			var was_drag := drag_active
			lmb_down = false
			drag_card_idx = -1
			drag_active = false
			if not busy_animating and is_player_turn and not _is_hand_tucked() and c_idx >= 0 and c_idx < player_hand.size():
				var vp_h := get_viewport().get_visible_rect().size.y
				if was_drag:
					if event.position.y <= vp_h * 0.56:
						# Magnetic Arena Drop: play card or launch staged stack!
						_handle_card_click_or_drop(c_idx, true)
					else:
						# Finished drag-to-reorder in hand
						_rebuild_all_3d_hands()
						_refresh_table_labels()
				else:
					_handle_card_click_or_drop(c_idx, false)
		return

	if busy_animating:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var r_prop := hovered_prop_id if hovered_prop_id != "" else hovered_tavern_prop
		if r_prop != "" and _inspect_table_prop_3d(r_prop):
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var is_top_down := (cam_view_mode == CameraViewMode.TABLE_ITEMS)
		if hovered_tavern_prop != "":
			if is_top_down and not is_player_turn:
				if _inspect_table_prop_3d(hovered_tavern_prop):
					return
			_trigger_tavern_prop_click(hovered_tavern_prop)
			return
		if not (hovered_draw_deck and hovered_prop_id == "sword") and (hovered_prop_id in ["bell", "discard", "sword", "coins", "phial", "mug", "dice", "opp_phial", "opp_relic"] or hovered_prop_id.begins_with("shop_item_") or hovered_prop_id.begins_with("relic:") or hovered_prop_id.begins_with("trelic:")):
			if hovered_prop_id in ["opp_phial", "opp_relic"]:
				if _inspect_table_prop_3d(hovered_prop_id):
					return
			if hovered_prop_id.begins_with("relic:") or hovered_prop_id.begins_with("trelic:"):
				var r_id := hovered_prop_id.substr(7) if hovered_prop_id.begins_with("trelic:") else hovered_prop_id.substr(6)
				if (not is_player_turn) or tutorial_mode or (not _can_use_table_item(r_id)):
					if _inspect_table_prop_3d(hovered_prop_id):
						return
			if hovered_prop_id == "phial" and not _can_change_opening_wager():
				if is_player_turn and puf_revealed and puf_charges > 0:
					staged_card_indices.clear()
					_activate_magic_puf_3d()
					return
				elif is_top_down:
					if _inspect_table_prop_3d("phial"):
						return
				return
			if is_top_down and hovered_prop_id in ["sword", "coins", "bell", "discard"] and (not is_player_turn or not _can_change_opening_wager()):
				if _inspect_table_prop_3d(hovered_prop_id):
					return
			_trigger_tavern_prop_click(hovered_prop_id)
			return
		if hovered_boss_plaque and active_boss_mod != "":
			_trigger_boss_modifier_flare("%s — %s" % [active_boss_mod.replace("_", " "), _get_boss_counterplay_tip()])
			return
		if not is_player_turn:
			return
		if tutorial_mode:
			if tutorial_step == 0:
				return
			if tutorial_step >= 1 and tutorial_step <= 6 and hovered_draw_deck:
				_whisper_tutorial_nudge(_tr("No need to draw — follow the highlighted task above!", "Teď nelízej — splň zvýrazněný úkol nahoře!"))
				return

		if not _is_hand_tucked() and hovered_card_idx >= 0:
			if event.shift_pressed:
				_toggle_stage_card(hovered_card_idx)
				return
			lmb_down = true
			drag_card_idx = hovered_card_idx
			drag_start_mouse = event.position
			drag_active = false
			return
		elif hovered_draw_deck:
			if turn_stage == TurnStage.ITEM_REVIEW and not tutorial_mode:
				_show_stagger_callout(_tr("Press [SPACE] to leave Items and inspect your hand first!", "Stiskni [SPACE] pro přechod z předmětů ke kartám!"), Color(0.98, 0.84, 0.42), 1.05)
				emit_signal("play_sfx_requested", "ui_click")
				return
			if tutorial_mode and tutorial_step >= 1 and tutorial_step <= 6:
				_whisper_tutorial_nudge(_tr("No need to draw — follow the highlighted task above!", "Teď nelízej — splň zvýrazněný úkol nahoře!"))
				return
			staged_card_indices.clear()
			_player_draw_from_3d_deck()
		elif hovered_puf_bottle and puf_revealed:
			if _can_change_opening_wager() and not (tutorial_mode and tutorial_step == 6):
				_trigger_tavern_prop_click("phial")
				return
			staged_card_indices.clear()
			_activate_magic_puf_3d()

func _handle_card_click_or_drop(c_idx: int, from_arena_drop: bool = false) -> void:
	if c_idx < 0 or c_idx >= player_hand.size() or busy_animating or not is_player_turn:
		return
	if tutorial_mode and tutorial_step == 1:
		if tutorial_substep == 0:
			_whisper_tutorial_nudge(_tr("Try vetoing your opening hand first: press [V] or click Veto Hand!", "Nejdřív si vyzkoušej výměnu úvodní ruky: stiskni [V] nebo klikni na Vetovat karty!"))
		elif tutorial_substep == 1:
			_whisper_tutorial_nudge(_tr("Press [TAB] or [SPACE] to switch to 3D Table Items and click your Sword!", "Stiskni [TAB] nebo [SPACE] pro přepnutí na 3D Stůl a klikni na Meč!"))
		else:
			_whisper_tutorial_nudge(_tr("Wager staked! Press [TAB] or [SPACE] to return to your cards.", "Sázka je uzavřena! Stiskni [TAB] nebo [SPACE] pro návrat ke kartám."))
		return
	if tutorial_mode and tutorial_step == 2:
		var scard2: Dictionary = player_hand[c_idx]
		if not _can_play(scard2) or str(scard2["rank"]) != "10":
			_whisper_tutorial_nudge(_tr("That card isn't the task! Play your glowing ♥ Ten from hand.", "Zahraj svítící ♥ Desítku ze své ruky!"))
			return
	if tutorial_mode and tutorial_step == 3:
		var scard: Dictionary = player_hand[c_idx]
		if str(scard["rank"]) != "7":
			_whisper_tutorial_nudge(_tr("Task: Play your glowing Seven (7)!", "Úkol: Zahraj svou svítící Sedmičku (7)!"))
			return
	if tutorial_mode and tutorial_step == 4:
		if c_idx in staged_card_indices:
			if staged_card_indices.size() >= 2:
				_launch_staged_stack()
			else:
				_whisper_tutorial_nudge(_tr("First 8 staged! Now click the OTHER Eight (8)!", "První Osma označena! Teď klikni na DRUHOU Osmičku (8)!"))
			return
		if str(player_hand[c_idx]["rank"]) == "8":
			_toggle_stage_card(c_idx)
			return
		_whisper_tutorial_nudge(_tr("Task: Stack both Eights (8) together!", "Úkol: Spoj obě Osmičky (8) do komba!"))
		return
	if tutorial_mode and tutorial_step == 5:
		if c_idx in staged_card_indices:
			if staged_card_indices.size() >= 2:
				_launch_staged_stack()
			else:
				_whisper_tutorial_nudge(_tr("First Ace staged! Now click the OTHER Ace (E)!", "První Eso označeno! Teď klikni na DRUHÉ Eso (E)!"))
			return
		if str(player_hand[c_idx]["rank"]) == "E":
			_toggle_stage_card(c_idx)
			return
		_whisper_tutorial_nudge(_tr("Task: Stack both Aces (E) to deal -4 ♥ HP!", "Úkol: Spoj obě Esa (E) do komba pro -4 ♥ HP!"))
		return
	if tutorial_mode and tutorial_step == 6:
		if tutorial_substep == 0:
			if str(player_hand[c_idx].get("power_id", "")) != "SPEC_VAMPIRE":
				_whisper_tutorial_nudge(_tr("Task: Play your special card Vampire Leech (SPEC_VAMPIRE)!", "Úkol: Zahraj speciální kartu Upíří pijavice (SPEC_VAMPIRE)!"))
				return
		else:
			_whisper_tutorial_nudge(_tr("First toss the 3D Hellfire Phial IGNIS on the right side of the table!", "Nejdřív vyzkoušej 3D Baňku pekelného ohně IGNIS vpravo na stole!"))
			return

	if not staged_card_indices.is_empty():
		if c_idx in staged_card_indices:
			_launch_staged_stack()
			return
		if not from_arena_drop:
			var base_r := _get_staged_base_rank()
			var clk_c: Dictionary = player_hand[c_idx]
			var clk_rank: String = str(clk_c["rank"])
			var chainable := bool(clk_c.get("wild", false)) or (base_r == "8" and clk_rank == "8") or (base_r == "E" and clk_rank == "E") or (base_r == "PWR" and str(clk_c.get("power_id", "")) != "")
			if chainable:
				_toggle_stage_card(c_idx)
				return
		staged_card_indices.clear()

	var card: Dictionary = player_hand[c_idx]
	if not _can_play(card):
		emit_signal("play_sfx_requested", "error")
		table_status_label3d.text = _tr("Card does not match suit or rank!", "Karta nepasuje na barvu ani hodnotu!")
		_rebuild_all_3d_hands()
		return
	var solo_pid := str(card.get("power_id", ""))
	var echo_solo := _get_last_echo_card() if solo_pid == "SPEC_MIRROR" else {}
	if card["rank"] == "H" or solo_pid == "SPEC_ORACLE" or (solo_pid == "SPEC_MIRROR" and (str(echo_solo.get("rank", "")) == "H" or str(echo_solo.get("power_id", "")) == "SPEC_ORACLE")):
		emit_signal("play_sfx_requested", "ui_click")
		pending_play_indices = [c_idx]
		pending_hornik_idx = c_idx
		suit_modal.visible = true
		return
	_play_player_cards_3d([c_idx], card["suit"])

func _inspect_table_prop_3d(prop_id: String) -> bool:
	if not is_instance_valid(relic_inspect_modal) or prop_id == "":
		return false
	if prop_id.begins_with("relic:") or prop_id.begins_with("trelic:"):
		var rid := prop_id.substr(7) if prop_id.begins_with("trelic:") else prop_id.substr(6)
		emit_signal("play_sfx_requested", "ui_click")
		relic_inspect_modal.inspect_relic(rid, opts_language, true, true)
		return true
	if prop_id == "opp_relic":
		emit_signal("play_sfx_requested", "ui_click")
		relic_inspect_modal.inspect_relic("REL_ROYAL", opts_language, true, false, _tr("Rival's Table Sigil", "Soupeřova pečeť na stole"))
		return true
	var info: Array[String] = _get_prop_hover_info(prop_id)
	var p_title := info[0] if info.size() > 0 and info[0] != "" else prop_id.capitalize()
	var p_desc := info[1] if info.size() > 1 else ""
	var custom_n: Node3D = null
	var glb_p := ""
	var accent := Color(0.92, 0.74, 0.34)
	var cat := _tr("TABLE ITEM", "PŘEDMĚT NA STOLE")
	match prop_id:
		"mug":
			custom_n = Node3D.new()
			RelicMesh.build_tavern_mug_meshes(custom_n)
			accent = Color(0.94, 0.78, 0.36)
		"coins":
			custom_n = Node3D.new()
			RelicMesh.build_coins_pouch_meshes(custom_n)
			accent = Color(1.0, 0.84, 0.28)
		"dice":
			custom_n = Node3D.new()
			RelicMesh.build_bone_dice_meshes(custom_n)
			accent = Color(0.92, 0.86, 0.70)
		"bell":
			custom_n = Node3D.new()
			RelicMesh.build_shop_bell_meshes(custom_n)
			accent = Color(0.96, 0.80, 0.32)
		"phial", "opp_phial":
			custom_n = Node3D.new()
			RelicMesh.build_hellfire_phial_meshes(custom_n)
			accent = Color(0.96, 0.44, 0.24) if prop_id == "opp_phial" else Color(0.84, 0.42, 1.0)
			if prop_id == "opp_phial":
				cat = _tr("RIVAL ARTIFACT", "ARTEFAKT SOUPEŘE")
		"sword":
			var sw_info: Dictionary = Catalog.get_sword_skin(active_sword_skin_id) if Catalog else {}
			custom_n = RelicMesh.build_sword_3d_mesh(active_sword_skin_id, sw_info)
			glb_p = ""
			accent = Color(0.86, 0.92, 1.0)
			cat = _tr("OATH BLADE", "ČEPEL PŘÍSAHY")
		"discard":
			accent = Color(0.98, 0.84, 0.42)
		_:
			if not prop_id.begins_with("shop_item_"):
				return false
	emit_signal("play_sfx_requested", "ui_click")
	relic_inspect_modal.inspect_prop(prop_id, p_title, cat, p_desc, glb_p, accent, opts_language, custom_n)
	return true

func _trigger_tavern_prop_click(prop_id: String) -> void:
	if prop_id == "mug" and is_instance_valid(tavern_mug_root):
		emit_signal("play_sfx_pitched_requested", "prop_tankard", randf_range(0.95, 1.08))
		var base_y := 0.80
		var tw := tavern_mug_root.create_tween()
		tw.tween_property(tavern_mug_root, "position:y", base_y + 0.08, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tavern_mug_root, "rotation_degrees:z", -14.0, 0.09)
		tw.tween_property(tavern_mug_root, "position:y", base_y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tavern_mug_root, "rotation_degrees:z", 0.0, 0.14)
		Fx.burst(self, tavern_mug_root.global_position + Vector3(0.0, 0.14, 0.0), Color(0.98, 0.94, 0.78), 16, 0.95, 0.45, 0.024, 1.8, true, 130.0, Vector3.UP, false)
		Fx.float_number(self, tavern_mug_root.global_position + Vector3(0.0, 0.20, 0.0), _tr("CHEERS!", "NA ZDRAVÍ!"), Color(1.0, 0.88, 0.42), 42, 0.16, 0.65, 1.35)
	elif prop_id == "coins" and is_instance_valid(tavern_coins_root):
		emit_signal("play_sfx_pitched_requested", "prop_coins", randf_range(0.96, 1.12))
		var base_y := 0.816
		var tw := tavern_coins_root.create_tween()
		tw.tween_property(tavern_coins_root, "position:y", base_y + 0.06, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tavern_coins_root, "position:y", base_y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Fx.gold_flakes(self, tavern_coins_root.global_position + Vector3(0.0, 0.10, 0.0), 18, 0.95)
		if _can_change_opening_wager():
			set_duel_wager("GOLD")
			Fx.float_number(self, tavern_coins_root.global_position + Vector3(0.0, 0.20, 0.0), _tr("GOLD WAGER!", "SÁZKA ZLATA!"), Color(1.0, 0.88, 0.30), 46, 0.18, 0.72, 1.42)
		else:
			Fx.float_number(self, tavern_coins_root.global_position + Vector3(0.0, 0.18, 0.0), _tr("FLORINS!", "ZLAŤÁKY!"), Color(1.0, 0.86, 0.28), 42, 0.16, 0.65, 1.35)
	elif prop_id == "phial" and is_instance_valid(magic_puf_bottle):
		if _can_change_opening_wager():
			emit_signal("play_sfx_requested", "ui_click")
			set_duel_wager("ITEM")
			_animate_wager_showcase_3d(true)
			Fx.float_number(self, magic_puf_bottle.global_position + Vector3(0.0, 0.20, 0.0), _tr("ITEM WAGER!", "SÁZKA BAŇKY!"), Color(0.86, 0.56, 1.0), 46, 0.18, 0.72, 1.42)
	elif prop_id == "dice" and is_instance_valid(tavern_dice_root):
		emit_signal("play_sfx_pitched_requested", "prop_dice", randf_range(0.94, 1.10))
		var d1 := randi() % 6 + 1
		var d2 := randi() % 6 + 1
		var base_y := 0.832
		var tw := tavern_dice_root.create_tween()
		tw.tween_property(tavern_dice_root, "position:y", base_y + 0.11, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tavern_dice_root, "rotation_degrees:y", tavern_dice_root.rotation_degrees.y + 360.0, 0.24)
		tw.tween_property(tavern_dice_root, "position:y", base_y, 0.13).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Fx.burst(self, tavern_dice_root.global_position + Vector3(0.0, 0.06, 0.0), Color(0.96, 0.88, 0.62), 14, 1.0, 0.42, 0.022, 2.0, true, 140.0, Vector3.UP, true)
		var omen := _tr("LUCKY 7!", "ŠŤASTNÁ 7!") if (d1 + d2 == 7) else (_tr("DOUBLE SIX!", "DVĚ ŠESTKY!") if (d1 == 6 and d2 == 6) else (_tr("SNAKE EYES!", "DVĚ JEDNIČKY!") if (d1 == 1 and d2 == 1) else ("%d & %d" % [d1, d2])))
		Fx.float_number(self, tavern_dice_root.global_position + Vector3(0.0, 0.18, 0.0), "" + omen, Color(1.0, 0.90, 0.46), 44, 0.18, 0.72, 1.42)
	elif prop_id == "bell" and is_instance_valid(tavern_bell_root):
		emit_signal("play_sfx_pitched_requested", "prop_coins", 1.24)
		var base_y := 0.806
		var btw := tavern_bell_root.create_tween()
		btw.tween_property(tavern_bell_root, "position:y", base_y + 0.06, 0.07)
		btw.tween_property(tavern_bell_root, "position:y", base_y, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Fx.ring(self, tavern_bell_root.global_position + Vector3(0.0, 0.06, 0.0), Color(1.0, 0.86, 0.34), 0.34, 0.40, 0.05, 1.6, 4.0)
		var next_shop_r := ((current_round_num - 1) / 3 + 1) * 3
		Fx.float_number(self, tavern_bell_root.global_position + Vector3(0.0, 0.18, 0.0), _tr("SHOP AT END OF R%d" % next_shop_r, "OBCHOD PO %d. KOLE" % next_shop_r), Color(1.0, 0.88, 0.42), 36, 0.16, 0.72, 1.25)
	elif prop_id == "discard" and is_instance_valid(discard_pile_root):
		emit_signal("play_sfx_requested", "card_hover")
		var dtw := discard_pile_root.create_tween()
		dtw.tween_property(discard_pile_root, "scale", Vector3(1.52, 1.52, 1.52), 0.09)
		dtw.tween_property(discard_pile_root, "scale", Vector3(1.38, 1.38, 1.38), 0.14)
		var info_d: Array[String] = _get_prop_hover_info("discard")
		_show_stagger_callout(info_d[0], Color(0.98, 0.86, 0.46), 1.15)
	elif prop_id == "sword" and is_instance_valid(player_sword_root):
		emit_signal("play_sfx_pitched_requested", "sword_draw", 1.1)
		if _can_change_opening_wager():
			set_duel_wager("SWORD")
			_animate_wager_showcase_3d(true)
			Fx.float_number(self, player_sword_root.global_position + Vector3(0.0, 0.22, 0.0), _tr("SWORD OATH!", "KRVAVÁ PŘÍSAHA!"), Color(1.0, 0.36, 0.28), 48, 0.18, 0.75, 1.45)
			if tutorial_mode and tutorial_step == 1 and tutorial_substep == 1:
				tutorial_substep = 2
				_tutorial_action_done = "wager_staked"
				_trigger_ghost_ok_flash()
				_update_tutorial_callout_ui(1, true)
				return
		else:
			var stw := player_sword_root.create_tween()
			stw.tween_property(player_sword_root, "position:y", 0.90, 0.08)
			stw.tween_property(player_sword_root, "position:y", 0.822, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			var info_s: Array[String] = _get_prop_hover_info("sword")
			_show_stagger_callout(info_s[0], Color(0.86, 0.92, 1.0), 1.15)
	elif prop_id.begins_with("trelic:"):
		var tid := prop_id.substr(7)
		var trn := relic_3d_nodes.get(tid) as Node3D
		var t_info: Dictionary = Catalog.get_table_relic_loc(tid, opts_language)
		var tcol: Color = t_info.get("col", Color(0.96, 0.24, 0.34))
		if is_instance_valid(trn):
			var bp_y: float = (trn.get_meta("base_pos", trn.position) as Vector3).y
			var trtw := trn.create_tween()
			trtw.tween_property(trn, "position:y", bp_y + 0.16, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var sp_t := trn.get_node_or_null("RelicModel3D/SpinPivot") as Node3D
			if sp_t:
				trtw.parallel().tween_property(sp_t, "rotation_degrees:y", sp_t.rotation_degrees.y + 540.0, 0.38)
			trtw.tween_property(trn, "position:y", bp_y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		if is_player_turn and not busy_animating and not tutorial_mode and _can_use_table_item(tid):
			var t_rem := _record_table_item_activation(tid, relic_3d_nodes.get(tid))
			var t_origin := trn.global_position + Vector3(0.0, 0.10, 0.0) if is_instance_valid(trn) else Vector3(0.35, 0.90, 0.45)
			var t_target := opp_hands_anchor.global_position + Vector3(0.0, 0.08, 0.0) if is_instance_valid(opp_hands_anchor) else Vector3(0.0, 1.05, -1.0)
			if is_instance_valid(trn):
				var t_halo := trn.get_node_or_null("RelicModel3D/ReadyHalo") as Node3D
				if t_halo:
					t_halo.visible = (t_rem > 0)
			Fx.relic_tybw_ritual(self, t_origin, t_target, tid, tcol)
			emit_signal("play_sfx_pitched_requested", "chord_lute", 1.24)
			var tr_msg := ""
			match tid:
				"TRELIC_SOUL_BELL":
					ai_score = maxi(0, ai_score - 18)
					display_ai_score = float(ai_score)
					if ai_score_lbl and hud_score_revealed:
						ai_score_lbl.text = _tr("RIVAL: %s / %s", "SOUPEŘ: %s / %s") % [_format_pts_ui(ai_score), _format_pts_ui(target_score)]
					_trigger_boss_recoil_stagger(true)
					tr_msg = _tr("SOUL SEVER: RIVAL -18 PTS!", "ROZETNUTÍ: SOUPEŘ -18 B.!")
				"TRELIC_BLOOD_SEAL":
					table_relic_blood_seal_active = true
					tr_msg = _tr("NEXT PLAY ×2.0 & -10 RIVAL!", "PŘÍŠTÍ TAH ×2.0 & -10 SOUPEŘ!")
				"TRELIC_STAR_BOW":
					rival_cards_revealed_turns = maxi(rival_cards_revealed_turns, 2)
					_apply_hp_damage(false, 1, _tr("★ ASTRAL VOLLEY: -1 ♥ HP!", "★ HVĚZDNÁ SALVA: -1 ♥ HP!"))
					tr_msg = _tr("★ REVEAL 2T & -1 ♥ RIVAL!", "★ ODHALENÍ 2T & -1 ♥ SOUPEŘ!")
				"TRELIC_ASH_GLASS":
					redraws_left += 2
					_advance_mage_charges(2, true)
					tr_msg = _tr("+2 REDRAWS & MAGES 2/2!", "+2 VÝMĚNY & MÁGOVÉ 2/2!")
				"TRELIC_WAR_HORN":
					player_shields += 2
					if is_instance_valid(player_hp_heart):
						player_hp_heart.call("set_shields", player_shields)
					var best_horn_idx := -1
					var best_horn_pts := -1
					for hi in range(player_hand.size()):
						var hc_w: Dictionary = player_hand[hi]
						if Catalog.normalize_card_class(str(hc_w.get("edition", "NORMAL"))) != "KNIGHT":
							var h_pts := int(hc_w.get("pts", 0))
							if h_pts > best_horn_pts:
								best_horn_pts = h_pts
								best_horn_idx = hi
					if best_horn_idx >= 0:
						player_hand[best_horn_idx]["edition"] = "KNIGHT"
					tr_msg = _tr("FORGED KNIGHT & +2!", "UKOVÁN RYTÍŘ & +2!")
				"TRELIC_HOLLOW_MASK":
					player_hp = maxi(1, player_hp - 1)
					if is_instance_valid(player_hp_heart):
						player_hp_heart.call("set_hp", player_hp, player_max_hp, true)
					table_relic_hollow_mask_active = true
					tr_msg = _tr("PHANTOM MASK: NEXT WILD ×2!", "MASKA PŘÍZRAKU: PŘÍŠTÍ DIVOKÁ ×2!")
				"TRELIC_CENSER":
					puf_charges += 1
					for hc_c in player_hand:
						if Catalog.normalize_card_class(str(hc_c.get("edition", "NORMAL"))) != "MAGE":
							hc_c["edition"] = "MAGE"
							hc_c["mage_charge"] = 2
							break
					tr_msg = _tr("MAGE 2/2 & +1 PHIAL!", "MÁG 2/2 & +1 BAŇKA!")
				"TRELIC_GOLD_SCALES":
					player_available_gold += 22
					match_bonus_gold += 22
					if player_hand.size() < 9:
						player_hand.append(_draw_from_deck())
					tr_msg = _tr("+22g FLORINS & +1 CARD!", "+22g ZLATÝCH & +1 KARTA!")
				"TRELIC_IRON_CHAIN":
					for _ic in range(2):
						ai_hand.append(_draw_from_deck())
					_award_player_score_immediately(14, _tr("Chain (+14)", "Řetěz (+14)"), tcol)
					_trigger_boss_recoil_stagger(false)
					tr_msg = _tr("RIVAL +2 DRAW & +14 PTS!", "SOUPEŘ +2 KARTY & +14 B.!")
				"TRELIC_PHOENIX_BOX":
					player_hp = mini(player_max_hp, player_hp + 2)
					if is_instance_valid(player_hp_heart):
						player_hp_heart.call("set_hp", player_hp, player_max_hp, true)
					pending_draw = 0
					pending_skip = false
					_award_player_score_immediately(16, _tr("Phoenix (+16)", "Fénix (+16)"), tcol)
					tr_msg = _tr("+2 ♥ HEAL, PURGE & +16 PTS!", "+2 ♥ LÉČENÍ, ČISTKA & +16 B.!")
			Fx.float_number(self, t_origin + Vector3(0.0, 0.16, 0.0), tr_msg, tcol.lightened(0.30), 48, 0.22, 0.95, 1.50)
			_show_stagger_callout("✦ %s — %s" % [str(t_info.get("name", tid)), tr_msg], tcol.lightened(0.25), 1.32)
			_refresh_score_ledger_ui()
			_refresh_table_labels()
			_rebuild_all_3d_hands()
		else:
			emit_signal("play_sfx_pitched_requested", "chord_lute", 1.04)
			_show_stagger_callout("✦ %s" % str(t_info.get("name", tid)), tcol.lightened(0.20), 1.15)
	elif prop_id.begins_with("relic:"):
		var rel_id := prop_id.substr(6)
		var rn := relic_3d_nodes.get(rel_id) as Node3D
		var r_info: Dictionary = Catalog.get_relic_loc(rel_id, opts_language)
		var col: Color = r_info.get("col", Color(1.0, 0.84, 0.34))
		if is_instance_valid(rn):
			var bp_y: float = (rn.get_meta("base_pos", rn.position) as Vector3).y
			var rtw := rn.create_tween()
			rtw.tween_property(rn, "position:y", bp_y + 0.13, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var spin_p := rn.get_node_or_null("RelicModel3D/SpinPivot") as Node3D
			if spin_p:
				rtw.parallel().tween_property(spin_p, "rotation_degrees:y", spin_p.rotation_degrees.y + 360.0, 0.32)
			rtw.tween_property(rn, "position:y", bp_y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			Fx.burst(self, rn.global_position + Vector3(0.0, 0.09, 0.0), col.lightened(0.25), 18, 0.95, 0.48, 0.025, 1.8, true, 140.0, Vector3.UP, true)

		if is_player_turn and not busy_animating and not tutorial_mode and _can_use_table_item(rel_id):
			var r_rem := _record_table_item_activation(rel_id, relic_3d_nodes.get(rel_id))
			if is_instance_valid(rn):
				var halo_n := rn.get_node_or_null("RelicModel3D/ReadyHalo") as Node3D
				if halo_n:
					halo_n.visible = (r_rem > 0)
				var r_target := discard_pile_root.global_position + Vector3(0.0, 0.05, 0.0) if is_instance_valid(discard_pile_root) else rn.global_position + Vector3(0.0, 0.25, -0.35)
				Fx.item_ritual_activation(self, rn.global_position + Vector3(0.0, 0.08, 0.0), r_target, col.lightened(0.35))
			emit_signal("play_sfx_pitched_requested", "prop_coins" if rel_id in ["REL_GREED", "REL_MERCHANT_LEDGER", "REL_COURT_SOVEREIGN", "REL_RED_SEAL"] else "chord_lute", 1.18)
			var chan_msg := ""
			if rel_id in ["REL_GREED", "REL_MERCHANT_LEDGER", "REL_COURT_SOVEREIGN", "REL_RED_SEAL"]:
				player_available_gold += 8
				match_bonus_gold += 8
				chan_msg = _tr("+8 CHANNELED!", "+8 AKTIVOVÁNO!")
			elif rel_id in ["REL_STORMCAP", "REL_OVERCHARGE", "REL_PHOENIX_F", "REL_ALEMBIC", "REL_FANG", "REL_FINAL_TOLL", "REL_WOODCUTTER"]:
				redraws_left += 1
				chan_msg = _tr("+1 REDRAW!", "+1 VÝMĚNA!")
			elif rel_id in ["REL_IRON_BOOT", "REL_ROYAL", "REL_HEX_DOLL", "REL_FORGEMASTER"]:
				player_shields += 1
				chan_msg = _tr("+1 SHIELD!", "+1 ŠTÍT!")
			else:
				_advance_mage_charges(1, true)
				_award_player_score_immediately(8, _tr("✦ Relic Focus (+8)", "✦ Soustředění relikvie (+8)"), col)
				chan_msg = _tr("+8 FOCUS!", "+8 SOUSTŘEDĚNÍ!")
			if is_instance_valid(rn):
				Fx.float_number(self, rn.global_position + Vector3(0.0, 0.22, 0.0), chan_msg, col.lightened(0.35), 48, 0.18, 0.80, 1.45)
			_show_stagger_callout("✦ %s — %s" % [str(r_info.get("name", rel_id)), chan_msg], col.lightened(0.25), 1.24)
			_refresh_table_labels()
			_rebuild_all_3d_hands()
		else:
			emit_signal("play_sfx_pitched_requested", "chord_lute", 1.08)
			_show_stagger_callout("✦ %s" % str(r_info.get("name", rel_id)), col.lightened(0.20), 1.15)
	elif prop_id.begins_with("shop_item_"):
		for p_node in purchased_table_item_nodes:
			var pn := p_node as Node3D
			if is_instance_valid(pn) and str(pn.get_meta("prop_id", "")) == prop_id:
				if not _can_use_table_item(prop_id):
					_show_stagger_callout(_tr("Item Shattered!", "Předmět se rozbil!"), Color(0.75, 0.34, 0.28), 1.0)
					break
				emit_signal("play_sfx_pitched_requested", "prop_coins", 1.16)
				var ic: Color = pn.get_meta("item_col", Color(1.0, 0.86, 0.34))
				var em_s := str(pn.get_meta("emblem", "bell"))
				var s_target := discard_pile_root.global_position + Vector3(0.0, 0.05, 0.0) if is_instance_valid(discard_pile_root) else pn.global_position + Vector3(0.0, 0.25, -0.35)
				if is_player_turn and not busy_animating:
					var rem_s := _record_table_item_activation(prop_id, pn, s_target, em_s)
					var res_msg := ""
					if em_s == "mirror":
						redraws_left += 1
						_award_player_score_immediately(8, _tr("✦ Mirror (+8)", "✦ Zrcadlo (+8)"), ic)
						res_msg = _tr("+8 PTS & +1!", "+8 B. & +1!")
					elif em_s == "gauntlet":
						player_shields += 1
						res_msg = _tr("+1 SHIELD!", "+1 ŠTÍT!")
					elif em_s == "phial":
						puf_charges += 1
						res_msg = _tr("+1 PHIAL!", "+1 BAŇKA!")
					elif em_s in ["scroll", "eye", "key"]:
						_advance_mage_charges(1, true)
						_award_player_score_immediately(8, _tr("✦ Arcane (+8)", "✦ Arkána (+8)"), ic)
						res_msg = _tr("+8 &CHARGE!", "+8 &NABITÍ!")
					else:
						_award_player_score_immediately(10, _tr("✦ Relic (+10)", "✦ Relikvie (+10)"), ic)
						res_msg = _tr("+10 PTS!", "+10 BODŮ!")
					_show_stagger_callout("✦ %s (%d/3) — %s" % [str(pn.get_meta("hover_title", "Artifact")), rem_s, res_msg], ic, 1.25)
					_refresh_table_labels()
					_rebuild_all_3d_hands()
				else:
					Fx.play_complex_table_item_anim(self, pn, pn.global_position, s_target, em_s, ic)
					_show_stagger_callout(str(pn.get_meta("hover_title", "Artifact")), ic, 1.25)
				break

func _spawn_card_impact_dust(impact_global_pos: Vector3) -> void:
	Fx.ink_splat(self, impact_global_pos, 18, 1.0)
	Fx.burst(self, impact_global_pos + Vector3(0.0, 0.02, 0.0), Color(0.96, 0.84, 0.52), 14, 0.95, 0.42, 0.026, 2.2, true, 120.0, Vector3.UP, true)

func _spawn_suit_discard_rune_ring_3d(impact_global_pos: Vector3, suit_id: String) -> void:
	if not is_inside_tree():
		return
	var s_obj := _get_suit_obj(suit_id)
	var scol: Color = s_obj.get("col", Color(0.94, 0.74, 0.28))
	var ring_root := Node3D.new()
	add_child(ring_root)
	ring_root.global_position = impact_global_pos + Vector3(0.0, 0.018, 0.0)

	# Outer ink-rimmed woodcut ring
	var outer_mi := MeshInstance3D.new()
	var outer_t := TorusMesh.new()
	outer_t.inner_radius = 0.19
	outer_t.outer_radius = 0.23
	outer_t.rings = 24
	outer_t.ring_segments = 6
	outer_mi.mesh = outer_t
	var outer_mat := StandardMaterial3D.new()
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.albedo_color = Color(0.06, 0.04, 0.03, 0.92)
	outer_mat.emission_enabled = true
	outer_mat.emission = scol
	outer_mat.emission_energy_multiplier = 1.35
	outer_mi.material_override = outer_mat
	ring_root.add_child(outer_mi)

	# Inner suit-reactive rune ring
	var inner_mi := MeshInstance3D.new()
	var inner_t := TorusMesh.new()
	inner_t.inner_radius = 0.11
	inner_t.outer_radius = 0.135
	inner_t.rings = 16
	inner_t.ring_segments = 6
	inner_mi.mesh = inner_t
	var inner_mat := StandardMaterial3D.new()
	inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_mat.albedo_color = Color(scol.r, scol.g, scol.b, 0.92)
	inner_mat.emission_enabled = true
	inner_mat.emission = scol.lightened(0.25)
	inner_mat.emission_energy_multiplier = 2.2
	inner_mi.material_override = inner_mat
	ring_root.add_child(inner_mi)

	Fx.ring(self, impact_global_pos + Vector3(0.0, 0.02, 0.0), scol.lightened(0.2), 0.36, 0.34, 0.09, 1.5, 9.0)
	Fx.burst(self, impact_global_pos + Vector3(0.0, 0.03, 0.0), scol.lightened(0.28), 16, 1.05, 0.44, 0.024, 1.9, true, 130.0, Vector3.UP, true)

	var tw := ring_root.create_tween().set_parallel(true)
	tw.tween_property(outer_mi, "scale", Vector3(2.15, 1.0, 2.15), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(outer_mi, "rotation_degrees:y", 75.0, 0.58)
	tw.tween_property(inner_mi, "scale", Vector3(1.85, 1.0, 1.85), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(inner_mi, "rotation_degrees:y", -110.0, 0.58)
	tw.tween_property(outer_mat, "albedo_color:a", 0.0, 0.35).set_delay(0.23)
	tw.tween_property(inner_mat, "albedo_color:a", 0.0, 0.35).set_delay(0.23)
	tw.chain().tween_callback(ring_root.queue_free)

func _spawn_impact_shockwave(center_global: Vector3, col: Color, max_scale: float = 2.6) -> void:
	var rad := clampf(max_scale * 0.26, 0.42, 1.15)
	Fx.ring(self, center_global + Vector3(0.0, 0.015, 0.0), col.lightened(0.15), rad, 0.42, 0.11, 1.75, 10.0)

func _trigger_screen_juice(col: Color, strength: float = 0.72, dur: float = 0.42, godrays: float = 0.0, center: Vector2 = Vector2(0.54, 0.50)) -> void:
	if not screen_juice_mat:
		return
	if screen_juice_tween and screen_juice_tween.is_valid():
		screen_juice_tween.kill()
	screen_juice_mat.set_shader_parameter("shock_center", center)
	screen_juice_mat.set_shader_parameter("flash_color", Color(col.r, col.g, col.b, 1.0))
	screen_juice_mat.set_shader_parameter("shock_strength", strength)
	screen_juice_mat.set_shader_parameter("ring_progress", 0.04)
	screen_juice_mat.set_shader_parameter("godrays_strength", godrays)
	screen_juice_tween = create_tween().set_parallel(true)
	screen_juice_tween.tween_method(func(v: float):
		if screen_juice_mat:
			screen_juice_mat.set_shader_parameter("ring_progress", v)
	, 0.04, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	screen_juice_tween.tween_method(func(v: float):
		if screen_juice_mat:
			screen_juice_mat.set_shader_parameter("shock_strength", v)
	, strength, 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if godrays > 0.005:
		screen_juice_tween.tween_method(func(v: float):
			if screen_juice_mat:
				screen_juice_mat.set_shader_parameter("godrays_strength", v)
		, godrays, 0.0, maxf(dur, 1.45)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _spawn_lightning_bolt_3d(impact_global: Vector3, accent_col: Color) -> void:
	var local_imp := to_local(impact_global)
	table_arcane_spin_boost = minf(2.4, table_arcane_spin_boost + 1.2)
	_trigger_screen_juice(Color(0.45, 0.92, 1.0).lerp(accent_col, 0.35), 0.56, 0.36)

	var flash := OmniLight3D.new()
	flash.position = local_imp + Vector3(0.0, 0.72, 0.0)
	flash.light_color = Color(0.55, 0.92, 1.0).lerp(accent_col.lightened(0.45), 0.35)
	flash.light_energy = 6.4
	flash.omni_range = 5.2
	add_child(flash)
	var ftw := create_tween()
	ftw.tween_property(flash, "light_energy", 0.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ftw.chain().tween_callback(flash.queue_free)

	# Crisp plasma bolt + translucent electric outer aura (never blows out card faces!)
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color = Color(0.95, 0.99, 1.0, 0.92)

	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var a_col := Color(0.28, 0.86, 1.0).lerp(accent_col.lightened(0.3), 0.40)
	aura_mat.albedo_color = Color(a_col.r, a_col.g, a_col.b, 0.46)

	var bolt_root := Node3D.new()
	add_child(bolt_root)
	for fork in range(4):
		var spread_top := 0.24 if fork == 0 else 0.70
		var cur := local_imp + Vector3(randf_range(-spread_top, spread_top), 2.55, randf_range(-0.42, 0.42))
		var steps := 8 if fork == 0 else 6
		var end_off := Vector3.ZERO if fork <= 1 else Vector3(randf_range(-0.32, 0.32), 0.02, randf_range(-0.26, 0.26))
		for s in range(1, steps + 1):
			var u := float(s) / float(steps)
			var nxt := cur.lerp(local_imp + end_off, u)
			if s < steps:
				var jag := 0.24 if fork == 0 else 0.18
				nxt += Vector3(randf_range(-jag, jag), randf_range(-0.05, 0.05), randf_range(-jag, jag))
			else:
				nxt = local_imp + end_off + Vector3(0.0, 0.02, 0.0)
			if fork == 0:
				bolt_root.add_child(_spawn_bolt_segment_mesh(cur, nxt, 0.019, core_mat))
				bolt_root.add_child(_spawn_bolt_segment_mesh(cur, nxt, 0.042, aura_mat))
			else:
				var th := 0.012 if fork == 1 else 0.008
				bolt_root.add_child(_spawn_bolt_segment_mesh(cur, nxt, th, aura_mat))
			cur = nxt

	# Soft electric sunburst ring + crisp spark fountain via FxLib
	Fx.ring(self, impact_global + Vector3(0.0, 0.02, 0.0), a_col.lightened(0.25), 0.72, 0.36, 0.12, 1.9, 12.0)
	Fx.burst(self, impact_global + Vector3(0.0, 0.04, 0.0), a_col.lightened(0.3), 26, 1.55, 0.48, 0.032, 1.8, true, 160.0, Vector3.UP, true)

	var btw := create_tween()
	btw.tween_interval(0.15)
	btw.tween_property(core_mat, "albedo_color:a", 0.0, 0.22)
	btw.parallel().tween_property(aura_mat, "albedo_color:a", 0.0, 0.28)
	btw.chain().tween_callback(bolt_root.queue_free)

func _sync_peek_ui_visibility() -> void:
	var tucked_now := _is_hand_tucked()
	_last_peek_state = tucked_now
	var cine_active := _is_cinematic_playing() or cam_view_mode == CameraViewMode.CINEMATIC
	if wager_bar_panel:
		wager_bar_panel.visible = false
	var show_opening_pact := ((not tutorial_mode and not opening_turn_committed and current_round_num == 1) or (tutorial_mode and tutorial_step == 1 and tutorial_substep == 0)) and (not intro_animating) and (not peddler_open) and (not shop_gate_open) and (not cine_active) and (not (victory_summary_overlay and victory_summary_overlay.visible))
	if veto_standalone_panel:
		veto_standalone_panel.visible = show_opening_pact
		if show_opening_pact:
			if wager_veto_hand_btn:
				wager_veto_hand_btn.disabled = opening_veto_used
				wager_veto_hand_btn.text = _tr("Veto Hand [V]", "Vetovat karty [V]") if not opening_veto_used else _tr("Vetoed", "Vetováno")
			if wager_veto_duel_btn:
				wager_veto_duel_btn.disabled = false
				wager_veto_duel_btn.text = _tr("Veto Game", "Vetovat hru")
	_refresh_wager_indicator_ui()
	if is_instance_valid(view_toggle_btn):
		view_toggle_btn.visible = (not cine_active) and (not intro_animating) and (not peddler_open) and (not shop_gate_open) and (not (tutorial_mode and tutorial_step == 0)) and (not (victory_summary_overlay and victory_summary_overlay.visible)) and (not (defeat_summary_overlay and defeat_summary_overlay.visible))
		view_toggle_btn.text = _tr("Cards [TAB]", "Karty [TAB]") if cam_view_mode == CameraViewMode.TABLE_ITEMS else _tr("Items [TAB]", "Itemy [TAB]")
		LialoIcons.apply_button_icon(view_toggle_btn, "cards" if cam_view_mode == CameraViewMode.TABLE_ITEMS else "sword", 16)
	if peek_hud_bar:
		peek_hud_bar.visible = false
	if dock_backdrop_panel:
		dock_backdrop_panel.visible = false
	if key_hint_lbl:
		key_hint_lbl.visible = false
	if combat_log_drawer != null:
		var show_log_pill := (cam_view_mode == CameraViewMode.CARDS) and (not intro_animating) and (not peddler_open) and (not shop_gate_open) and (not tutorial_mode) and (not (victory_summary_overlay and victory_summary_overlay.visible)) and (not (defeat_summary_overlay and defeat_summary_overlay.visible))
		combat_log_drawer.sync_visibility(show_log_pill, cine_active)
		if show_log_pill:
			_refresh_combat_log_relic_pill()
	if is_instance_valid(item_review_bar):
		var show_ir := (not cine_active) and (not intro_animating) and (not peddler_open) and (not shop_gate_open) and (not tutorial_mode) and is_player_turn and (not busy_animating) and (turn_stage == TurnStage.ITEM_REVIEW) and not (is_instance_valid(view_toggle_btn) and view_toggle_btn.visible)
		item_review_bar.visible = show_ir
		if item_review_lbl:
			item_review_lbl.text = _tr("✦ REVIEW TABLE ITEMS — CLICK TO USE OR", "✦ PROHLÉDNI ITEMY NA STOLE — KLIKNI NEBO")
		if item_review_continue_btn:
			item_review_continue_btn.text = _tr("CARDS [SPACE] ▸", "KE KARTÁM [SPACE] ▸")
	if is_instance_valid(draw_deck_beacon):
		draw_deck_beacon.visible = (not cine_active) and (not intro_animating) and is_player_turn and (not busy_animating) and (turn_stage == TurnStage.CARD_PLAY) and (not tutorial_mode) and (not _player_has_any_playable_card())
	if table_status_label3d:
		table_status_label3d.visible = (not cards_tucked) and (not tutorial_mode) and (not busy_animating) and (not cine_active)
	var p_lbl := magic_puf_bottle.get_node_or_null("PufLabel") as Label3D if magic_puf_bottle else null
	if p_lbl:
		p_lbl.visible = puf_revealed and (cam_view_mode != CameraViewMode.RIVAL_ITEMS) and (not cine_active)
	var d_lbl := draw_deck_root.get_node_or_null("DeckCountLabel") as Label3D if draw_deck_root else null
	if d_lbl:
		d_lbl.text = _tr("DECK (%d)", "BALÍČEK (%d)") % deck.size()
	if cards_tucked or cine_active or (turn_stage == TurnStage.ITEM_REVIEW and not tutorial_mode):
		if stack_action_bar:
			stack_action_bar.visible = false
		if quick_action_bar:
			quick_action_bar.visible = false
		if redraw_action_btn:
			redraw_action_btn.visible = false
		if sort_hand_bar:
			sort_hand_bar.visible = false
		if hover_inspect_panel:
			hover_inspect_panel.visible = false
	else:
		if redraw_action_btn:
			redraw_action_btn.visible = not tutorial_mode and is_player_turn and not busy_animating
		if sort_hand_bar:
			sort_hand_bar.visible = not tutorial_mode and is_player_turn and not busy_animating
		if stack_action_bar:
			stack_action_bar.visible = (not staged_card_indices.is_empty()) and is_player_turn and not busy_animating
		if quick_action_bar:
			quick_action_bar.visible = staged_card_indices.is_empty() and is_player_turn and not busy_animating

func _execute_power_card_side_effects(card: Dictionary, echo_card: Dictionary = {}, allow_echo: bool = true, quiet_popup: bool = false) -> void:
	var p_id: String = str(card.get("power_id", ""))
	if p_id == "":
		return
	var acc: Color = card.get("accent", Color(1.0, 0.85, 0.30))
	match p_id:
		"SPEC_MIRROR":
			if allow_echo and not echo_card.is_empty():
				_execute_power_card_side_effects(echo_card, {}, false, quiet_popup)
		"SPEC_ALCHEMIST":
			puf_charges += 1
			var upgraded := false
			for hc in player_hand:
				if Catalog.normalize_card_class(str(hc.get("edition", "NORMAL"))) == "NORMAL":
					var roll_eds := ["MAGE", "KNIGHT", "MERCHANT", "THIEF"]
					var roll_ed: String = roll_eds[randi() % roll_eds.size()]
					hc["edition"] = roll_ed
					if roll_ed == "MAGE":
						hc["mage_charge"] = 1
					upgraded = true
					break
			if not quiet_popup:
				_spawn_score_popup(_tr("ALCHEMIST: +1 IGNIS" + (" & Class!" if upgraded else "!"), "ALCHYMISTA: +1 Baňka" + (" a Třída!" if upgraded else "!")), acc, true)
		"SPEC_ORACLE":
			rival_cards_revealed_turns = 2
			player_hand.append(_draw_from_deck())
			if not quiet_popup:
				_spawn_score_popup(_tr("SEER: Rival Revealed & +1!", "VĚŠTEC: Odhalení & +1 karta!"), acc, true)
		"SPEC_PHOENIX":
			pending_draw = 0
			deck.push_front(card.duplicate())
			deck.shuffle()
		"SPEC_CHRONOS":
			extra_player_turn = true
		"SPEC_MAGNET":
			var pulled := 0
			var best_r := ""
			var best_cnt := 0
			for hc in player_hand:
				var hr := str(hc.get("rank", ""))
				if hr == "" or hr == "PWR":
					continue
				var d_cnt := 0
				for dc in deck:
					if str(dc.get("rank", "")) == hr:
						d_cnt += 1
				if d_cnt > best_cnt:
					best_cnt = d_cnt
					best_r = hr
			if best_r == "":
				for hc in player_hand:
					var hr := str(hc.get("rank", ""))
					if hr != "" and hr != "PWR":
						best_r = hr
						break
			for di in range(deck.size() - 1, -1, -1):
				if best_r != "" and str(deck[di].get("rank", "")) == best_r:
					player_hand.append(deck[di])
					deck.remove_at(di)
					pulled += 1
					if pulled >= 2:
						break
			if pulled == 0 and not deck.is_empty():
				player_hand.append(_draw_from_deck())
				pulled = 1
			if not quiet_popup:
				_spawn_score_popup(_tr("MAGNET: Pulled %d Combo!", "MAGNET: Přitaženo %d!") % pulled, acc, true)
		"SPEC_SHIELD":
			player_shields += 2
			if not quiet_popup:
				_spawn_score_popup(_tr("BASTION: +2 Shields!", "BAŠTA: +2 Štíty!"), acc, true)
		"SPEC_PLAGUE":
			ai_stun_turns = maxi(ai_stun_turns, 1)

func _play_player_cards_3d(play_indices: Array, chosen_suit: String) -> void:
	if play_indices.is_empty():
		return
	turn_stage = TurnStage.RESOLVING
	opening_turn_committed = true
	if wager_bar_panel:
		wager_bar_panel.visible = false
	turn_glance_timer = 0.0
	cards_tucked = true
	auto_edge_peek = false
	_trigger_glove_play_lunge()
	busy_animating = true
	_stagger_seq_token += 1
	var my_token := _stagger_seq_token
	reorder_src_idx = -1
	staged_card_indices.clear()
	pending_play_indices.clear()
	pending_hornik_idx = -1
	tutorial_turns_left = maxi(0, tutorial_turns_left - 1)
	if stack_action_bar:
		stack_action_bar.visible = false
	if quick_action_bar:
		quick_action_bar.visible = false
	if table_status_label3d:
		table_status_label3d.visible = false
	if stagger_callout_pill:
		stagger_callout_pill.visible = false
	player_glove_action_offset = Vector3(0.0, 0.06, -0.14)

	var prev_suit := active_suit_id
	var pending_draw_before := pending_draw
	var pending_skip_before := pending_skip
	var echo_card := _get_last_echo_card()

	# Evaluate best possible move in hand BEFORE removing played cards (for Victory Best Move % efficiency breakdown!)
	var eights_in_hand: Array[Dictionary] = []
	for hi_eval in range(player_hand.size()):
		var hc_ev: Dictionary = player_hand[hi_eval]
		if _can_play(hc_ev):
			var rem_ev: Array = []
			for hj_eval in range(player_hand.size()):
				if hj_eval != hi_eval:
					rem_ev.append(player_hand[hj_eval])
			var ev_ctx := {
				"tutorial_mode": tutorial_mode, "tutorial_step": tutorial_step,
				"chosen_suit": str(hc_ev.get("suit", active_suit_id)), "prev_suit": prev_suit,
				"pending_draw_before": pending_draw_before, "pending_skip_before": pending_skip_before,
				"storm_surge_mult": storm_surge_mult, "echo_card": echo_card,
				"relic_scales": match_relic_scales, "shop_rerolls": run_shop_rerolls,
				"match_turn_count": match_turn_count + 1, "rival_hand_size": ai_hand.size(),
				"boss_mod": active_boss_mod, "campaign_difficulty": active_campaign_difficulty,
				"flow_chain": false, "target_score": target_score,
				"duel_chalice_mult": duel_chalice_mult, "duel_whetstone_stacks": duel_whetstone_stacks,
				"duel_next_xmult": duel_next_xmult, "is_preview": true, "lang": opts_language,
			}
			var ev_res := ScoreEng.calculate_hand_score([hc_ev], relic_mgr.get_effective_passive_relics(run_active_relics), rem_ev, ev_ctx)
			var ev_pts := int(ev_res.get("final_score", 0))
			if ev_pts > match_optimal_possible_slam:
				match_optimal_possible_slam = ev_pts
				var s_ev := _get_suit_obj(str(hc_ev.get("suit", "CERVEN")))
				match_optimal_move_desc = "%s %s (+%d %s)" % [s_ev["sym"], str(hc_ev.get("rname", "Card")), ev_pts, _tr("pts", "b.")]
		if str(hc_ev.get("rank", "")) == "8":
			eights_in_hand.append(hc_ev)
	if eights_in_hand.size() >= 2:
		var any_8_ok := false
		for e8 in eights_in_hand:
			if _can_play(e8):
				any_8_ok = true
				break
		if any_8_ok:
			var e8_ctx := {
				"tutorial_mode": tutorial_mode, "tutorial_step": tutorial_step,
				"chosen_suit": str(eights_in_hand.back().get("suit", active_suit_id)), "prev_suit": prev_suit,
				"pending_draw_before": pending_draw_before, "pending_skip_before": pending_skip_before,
				"storm_surge_mult": storm_surge_mult, "echo_card": echo_card,
				"relic_scales": match_relic_scales, "shop_rerolls": run_shop_rerolls,
				"match_turn_count": match_turn_count + 1, "rival_hand_size": ai_hand.size(),
				"boss_mod": active_boss_mod, "campaign_difficulty": active_campaign_difficulty,
				"flow_chain": false, "target_score": target_score,
				"duel_chalice_mult": duel_chalice_mult, "duel_whetstone_stacks": duel_whetstone_stacks,
				"duel_next_xmult": duel_next_xmult, "is_preview": true, "lang": opts_language,
			}
			var e8_res := ScoreEng.calculate_hand_score(eights_in_hand, relic_mgr.get_effective_passive_relics(run_active_relics), [], e8_ctx)
			var e8_pts := int(e8_res.get("final_score", 0))
			if e8_pts > match_optimal_possible_slam:
				match_optimal_possible_slam = e8_pts
				match_optimal_move_desc = _tr("∞ %d× Eight Chain (+%d pts)" % [eights_in_hand.size(), e8_pts], "∞ %d× Osmičky (+%d b.)" % [eights_in_hand.size(), e8_pts])

	var sorted_asc := play_indices.duplicate()
	sorted_asc.sort()
	var cnt := sorted_asc.size()
	var is_combo_slam := (cnt >= 2)
	var chosen_cards: Array[Dictionary] = []
	var flying_nodes: Array[Node3D] = []
	for idx in sorted_asc:
		var card: Dictionary = player_hand[idx]
		var fnode := player_card_nodes[idx]
		var s_global := fnode.global_transform
		player_hand_anchor.remove_child(fnode)
		add_child(fnode)
		fnode.global_transform = s_global
		chosen_cards.append(card)
		flying_nodes.append(fnode)

	for k in range(cnt - 1, -1, -1):
		var rem_idx: int = sorted_asc[k]
		player_hand.remove_at(rem_idx)
		player_card_nodes.remove_at(rem_idx)

	var phoenix_cleared := false
	for card in chosen_cards:
		if str(card.get("power_id", "")) == "SPEC_PHOENIX":
			phoenix_cleared = true
		else:
			discard_pile.append(card)
	active_suit_id = chosen_suit

	var flow_chain := (not tutorial_mode) and last_player_play_suit != "" and (chosen_suit == last_player_play_suit or (not chosen_cards.is_empty() and str(chosen_cards[0].get("rank", "")) == last_player_play_rank))
	var ctx := {
		"tutorial_mode": tutorial_mode,
		"tutorial_step": tutorial_step,
		"chosen_suit": chosen_suit,
		"prev_suit": prev_suit,
		"pending_draw_before": pending_draw_before,
		"pending_skip_before": pending_skip_before,
		"storm_surge_mult": storm_surge_mult,
		"echo_card": echo_card,
		"relic_scales": match_relic_scales,
		"shop_rerolls": run_shop_rerolls,
		"match_turn_count": match_turn_count + 1,
		"rival_hand_size": ai_hand.size(),
		"boss_mod": active_boss_mod,
		"campaign_difficulty": active_campaign_difficulty,
		"flow_chain": flow_chain,
		"target_score": target_score,
		"duel_chalice_mult": duel_chalice_mult,
		"duel_whetstone_stacks": duel_whetstone_stacks,
		"duel_next_xmult": duel_next_xmult,
		"blood_seal_active": table_relic_blood_seal_active,
		"hollow_mask_active": table_relic_hollow_mask_active,
		"surge_mult": storm_surge_mult,
		"bankai_active": bankai_active,
		"bankai_build_id": bankai_build_id,
		"is_preview": false,
		"lang": opts_language,
	}
	if not tutorial_mode:
		_check_and_trigger_bankai(chosen_cards)
		ctx["bankai_active"] = bankai_active
		ctx["bankai_build_id"] = bankai_build_id
	var had_blood_seal := table_relic_blood_seal_active
	var score_res := ScoreEng.calculate_hand_score(chosen_cards, relic_mgr.get_effective_passive_relics(run_active_relics), player_hand, ctx)
	table_relic_blood_seal_active = false
	table_relic_hollow_mask_active = false
	if had_blood_seal and not tutorial_mode:
		ai_score = maxi(0, ai_score - 10)
		display_ai_score = float(ai_score)
		if ai_score_lbl and hud_score_revealed:
			ai_score_lbl.text = _tr("RIVAL: %s / %s", "SOUPEŘ: %s / %s") % [_format_pts_ui(ai_score), _format_pts_ui(target_score)]
		Fx.float_number(self, opp_hands_anchor.global_position + Vector3(0.0, 0.24, 0.08), "-10", Color(1.0, 0.18, 0.28), 60, 0.22, 0.9, 1.35)
		_trigger_boss_recoil_stagger(false)
	_set_score_breakdown_chips(score_res.get("breakdown_chips", []))
	if not tutorial_mode:
		if player_shatter_debuff:
			player_shatter_debuff = false
			score_res["final_score"] = maxi(1, int(ceil(float(score_res["final_score"]) * 0.5)))
		if player_tax_debuff:
			player_tax_debuff = false
			score_res["final_score"] = maxi(1, int(round(float(score_res["final_score"]) * 0.7)))
	if not chosen_cards.is_empty():
		last_player_play_suit = chosen_suit
		last_player_play_rank = str(chosen_cards[0].get("rank", ""))
	if not tutorial_mode and duel_next_xmult > 1.01:
		duel_next_xmult = 1.0
	var eff_mult := float(score_res["effective_mult"])
	var total_pts := int(score_res["final_score"])
	if combat_log_drawer != null and not chosen_cards.is_empty():
		var p_slam := str(score_res.get("slam_name", chosen_cards[0].get("rname", "Card")))
		var p_fsum := str(score_res.get("formula_summary", "+%d" % total_pts))
		combat_log_drawer.add_entry(_tr("▶ YOU: %s (%s)" % [p_slam, p_fsum], "▶ TY: %s (%s)" % [p_slam, p_fsum]), Color(0.56, 0.94, 1.0))
	var force_lightning := bool(score_res["lightning"]) or is_combo_slam

	if not phoenix_cleared:
		pending_draw += int(score_res["extra_draw"])
		pending_seven_trap_bonus += int(score_res.get("seven_draw_bonus", 0))
	else:
		pending_draw = 0
		pending_seven_trap_bonus = 0
	if bool(score_res["extra_skip"]):
		pending_skip = true
		pending_skip_turns = mini(2, pending_skip_turns + 1)
		pending_ace_stun_bonus += int(score_res.get("ace_stun_bonus", 0))

	if not tutorial_mode or tutorial_step >= 7:
		var ace_cnt_in_play := 0
		for c_ace in chosen_cards:
			if str(c_ace.get("rank", "")) == "E":
				ace_cnt_in_play += 1
		if ace_cnt_in_play > 0:
			aces_played += ace_cnt_in_play
			if aces_played >= 3 and not tutorial_mode:
				ai_hp = 0
				_sync_heartbeat_hp_displays(true)
				_spawn_score_popup(_tr("3× ACE EXECUTION!", "POPRAVA 3× ESEM!"), Color(1.0, 0.28, 0.24), true)

	if not tutorial_mode or tutorial_step >= 3:
		if bool(score_res["surge_kept"]):
			storm_surge_mult += float(score_res["new_surge_mult"])
		else:
			storm_surge_mult = 0.0
		if int(score_res["rival_drain"]) > 0:
			ai_score = maxi(0, ai_score - int(score_res["rival_drain"]))
		if int(score_res["rival_bonus"]) > 0:
			ai_score += int(score_res["rival_bonus"])
		if int(score_res["bonus_gold"]) > 0:
			match_bonus_gold += int(score_res["bonus_gold"])
			duel_gold_delta += int(score_res["bonus_gold"])
		# NORMAL class economy buff: +6 Florins per pure base card played
		var normal_gold_cnt := 0
		var knight_charge_cnt := 0
		for cc_cls in chosen_cards:
			var n_cls := Catalog.normalize_card_class(str(cc_cls.get("edition", cc_cls.get("card_class", "NORMAL"))))
			if n_cls == "NORMAL" and str(cc_cls.get("power_id", "")) == "":
				normal_gold_cnt += 1
			elif n_cls == "KNIGHT":
				knight_charge_cnt += 1
		if normal_gold_cnt > 0:
			var n_gold_bonus := normal_gold_cnt * int(Catalog.CARD_CLASSES.get("NORMAL", {}).get("gold_bonus", 6))
			match_bonus_gold += n_gold_bonus
			duel_gold_delta += n_gold_bonus
			Fx.float_number(self, discard_pile_root.global_position + Vector3(0.0, 0.24, 0.0), "+%dg NORMAL" % n_gold_bonus, Color(1.0, 0.86, 0.28), 52, 0.24, 0.9, 1.35)
		if knight_charge_cnt > 0:
			for _ki in range(knight_charge_cnt):
				player_knight_shield_charge += 1
				if player_knight_shield_charge >= 3:
					player_knight_shield_charge -= 3
					player_shields += 1
					if is_instance_valid(player_hp_heart):
						player_hp_heart.call("trigger_shield_charge_pulse", player_knight_shield_charge, true)
						player_hp_heart.call("set_shields", player_shields)
					play_sfx_requested.emit("card_shield_guard")
					_spawn_score_popup(_tr("AEGIS FORGED! +1 FULL SHIELD (3/3)", "ŠTÍT UKOVÁN! +1 CELÝ ŠTÍT (3/3)"), Color(1.0, 0.88, 0.34), true)
				else:
					if is_instance_valid(player_hp_heart):
						player_hp_heart.call("trigger_shield_charge_pulse", player_knight_shield_charge, false)
					play_sfx_requested.emit("anim_parry_clang")
					_spawn_score_popup(_tr("KNIGHT SHIELD: %d/3" % player_knight_shield_charge, "RYTÍŘSKÝ ŠTÍT: %d/3" % player_knight_shield_charge), Color(0.45, 0.94, 1.0), true)
		if float(score_res["seven_grimoire_delta"]) > 0.0:
			match_relic_scales["REL_SEVEN_GRIMOIRE"] = float(score_res["seven_grimoire_new"])
		if int(score_res.get("shields_gained", 0)) > 0:
			player_shields += int(score_res["shields_gained"])
		if int(score_res.get("redraws_gained", 0)) > 0:
			redraws_left += int(score_res["redraws_gained"])
		if int(score_res.get("mage_charge_boost", 0)) > 0:
			_advance_mage_charges(int(score_res["mage_charge_boost"]), true)
		for _md in range(int(score_res.get("mage_draws", 0))):
			player_hand.append(_draw_from_deck())

		var k_suit := str(score_res.get("king_curse_suit", ""))
		if not pending_king_challenge.is_empty() and bool(pending_king_challenge.get("from_ai", false)):
			if k_suit != "":
				_spawn_score_popup(_tr("KING COUNTERED!", "KRÁL ODRAŽEN!"), Color(1.0, 0.86, 0.30), true)
				pending_king_challenge = {"suit": k_suit, "from_ai": false}
			else:
				_apply_king_curse_to_player(str(pending_king_challenge.get("suit", "CERVEN")))
				pending_king_challenge.clear()
		elif k_suit != "":
			pending_king_challenge = {"suit": k_suit, "from_ai": false}

	var run_special_cine := false
	var special_cine_id := ""
	if is_instance_valid(cinematic_director) and (not tutorial_mode or (tutorial_step == 6 and tutorial_substep == 0)):
		for c_chk in chosen_cards:
			var chk_pid := str(c_chk.get("power_id", ""))
			if chk_pid != "":
				run_special_cine = true
				special_cine_id = chk_pid
				break

	if (not tutorial_mode or tutorial_step >= 3) and (not run_special_cine):
		for card in chosen_cards:
			if str(card.get("power_id", "")) != "":
				_execute_power_card_side_effects(card, echo_card, true, true)

	if cnt >= 2:
		_tutorial_action_done = "slammed_combo"
	elif chosen_cards[0]["rank"] == "7":
		_tutorial_action_done = "played_seven"
	elif chosen_cards[0]["rank"] in ["E", "H"] or str(chosen_cards[0].get("power_id", "")) != "":
		_tutorial_action_done = "played_special"
	else:
		_tutorial_action_done = "played_card"

	var base_inspect := cam.global_position - cam.global_transform.basis.z * 0.50 + cam.global_transform.basis.y * 0.06
	var inspect_rot := cam.global_rotation + Vector3(0.04, 0.0, -0.04)
	var target_pos := discard_pile_root.global_position + Vector3(0, float(mini(discard_pile.size(), 8)) * 0.0045, 0)
	var s_obj := _get_suit_obj(chosen_suit)

	# Step 1: Unzoomed Top-Down Table View — keep camera wide and open over the table so scoring is 100% readable!
	emit_signal("play_sfx_requested", "card_draw")
	cam_impact_active = false
	turn_glance_timer = 1.15
	set_camera_view_mode(CameraViewMode.TABLE_ITEMS, false)
	if pending_seven_trap_bonus > 0 and pending_seven_banner_pill and pending_seven_banner_lbl:
		pending_seven_banner_lbl.text = _tr("SEVEN ON TABLE: +7 PTS (Waiting for Rival...)", "SEDMA NA STOLE: +7 BODŮ (Čeká na soupeře...)")
		pending_seven_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38))
		pending_seven_banner_pill.visible = true

	# TASK #9: Full Dramatic 2.5-3.8s Special Card Cutscene via CinematicDirector!
	if run_special_cine:
		for dn in _scored_display_nodes:
			if is_instance_valid(dn):
				dn.queue_free()
		_scored_display_nodes.clear()
		for k in range(cnt):
			var fn := flying_nodes[k]
			_scored_display_nodes.append(fn)
			var off_k := (float(k) - float(cnt - 1) * 0.5) * 0.21
			fn.global_position = target_pos + Vector3(off_k + 0.02, 0.11 + float(k) * 0.008, 0.13 + absf(off_k) * 0.10)
			fn.rotation_degrees = Vector3(-42.0, -off_k * 18.0, -off_k * 12.0)
			fn.scale = Vector3(1.12, 1.12, 1.12)
		_cinematic_seq_token += 1
		var my_cine_tok := _cinematic_seq_token
		_enter_cinematic_camera_lock()
		var card_world := target_pos + Vector3(0.0, 0.12, 0.12)
		var rival_world := opp_silhouette_root.global_position + Vector3(0.0, 0.42, 0.0) if is_instance_valid(opp_silhouette_root) else to_global(Vector3(0.0, 1.28, -1.50))
		var accent_c: Color = chosen_cards[0].get("accent", s_obj["col"])
		var impact_done := false
		var on_special_impact := func():
			if impact_done or my_cine_tok != _cinematic_seq_token or my_token != _stagger_seq_token or not is_inside_tree() or not visible:
				return
			impact_done = true
			if not tutorial_mode or tutorial_step >= 3:
				for card in chosen_cards:
					if str(card.get("power_id", "")) != "":
						_execute_power_card_side_effects(card, echo_card, true, true)
			_sync_heartbeat_hp_displays(true)
			var slam_pitch := clampf(1.02 + eff_mult * 0.025, 0.96, 1.38)
			emit_signal("play_sfx_pitched_requested", "card_slam", slam_pitch)
			emit_signal("play_sfx_pitched_requested", "puf", 0.68)
			_spawn_card_impact_dust(target_pos)
			_spawn_suit_discard_rune_ring_3d(target_pos, chosen_suit)
			_spawn_lightning_bolt_3d(target_pos, accent_c)
			_spawn_impact_shockwave(target_pos, accent_c, 3.1)
		var on_special_finished := func():
			if my_cine_tok != _cinematic_seq_token or my_token != _stagger_seq_token or not is_inside_tree() or not visible:
				return
			_exit_cinematic_camera_lock(CameraViewMode.TABLE_ITEMS)
			_execute_balatro_stagger_timeline(my_token, score_res, chosen_cards, _scored_display_nodes, s_obj, target_pos, true, true)
		cinematic_director.call(
			"play_special_card_cinematic",
			special_cine_id,
			card_world,
			rival_world,
			opts_language == "cs",
			on_special_impact,
			on_special_finished
		)
		return

	var inspect_dur := _pace(0.50 if force_lightning else 0.42)
	var inspect_tw := create_tween().set_parallel(true)
	for k in range(cnt):
		var fn := flying_nodes[k]
		var offset_x := (float(k) - (cnt - 1) * 0.5) * (0.18 if is_combo_slam else 0.14)
		var i_pos := base_inspect + cam.global_transform.basis.x * offset_x
		var i_rot := inspect_rot + Vector3(0.0, 0.0, -(float(k) - (cnt - 1) * 0.5) * 0.11)
		inspect_tw.tween_property(fn, "global_position", i_pos, inspect_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		inspect_tw.tween_property(fn, "global_rotation", i_rot, inspect_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		inspect_tw.tween_property(fn, "scale", Vector3(1.22, 1.22, 1.22) if force_lightning else Vector3(1.16, 1.16, 1.16), inspect_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	inspect_tw.chain().tween_interval(_pace(0.36 if force_lightning else 0.30))
	inspect_tw.chain().tween_callback(func():
		if my_token != _stagger_seq_token or not is_inside_tree() or not visible:
			return
		player_glove_action_offset = Vector3(0.0, 0.10, -0.24)
		emit_signal("play_sfx_requested", "card_throw_whoosh")
		# Stay in Top-Down Table View (do NOT zoom in close!)

		for dn in _scored_display_nodes:
			if is_instance_valid(dn):
				dn.queue_free()
		_scored_display_nodes.clear()
		for k in range(cnt):
			var fn := flying_nodes[k]
			_scored_display_nodes.append(fn)
			var c_data: Dictionary = chosen_cards[k]
			var delay_k := float(k) * _pace(0.24 if force_lightning else 0.18)
			var fly_dur := _pace(0.44 if force_lightning else 0.38)
			var arc_h := 0.28 if force_lightning else 0.16
			var start_p := fn.global_position
			var start_r_deg := fn.rotation_degrees
			# Fan scored cards face-up right in center arena clear of left HUD and right PUF flask
			var off_k := (float(k) - float(cnt - 1) * 0.5) * 0.21
			var showcase_pos := target_pos + Vector3(off_k + 0.02, 0.11 + float(k) * 0.008, 0.13 + absf(off_k) * 0.10)
			var showcase_rot := Vector3(-42.0, -off_k * 18.0, -off_k * 12.0)
			var c_tw := create_tween()
			if delay_k > 0.0:
				c_tw.tween_interval(delay_k)
			var fn_wr: WeakRef = weakref(fn)
			c_tw.tween_method(func(u: float):
				var fn_inst := fn_wr.get_ref() as Node3D
				if not is_instance_valid(fn_inst):
					return
				fn_inst.global_position = start_p.lerp(showcase_pos, u) + Vector3(0.0, sin(u * PI) * arc_h, 0.0)
				fn_inst.scale = (Vector3(1.24, 1.24, 1.24) if force_lightning else Vector3(1.16, 1.16, 1.16)).lerp(Vector3(1.06, 1.06, 1.06), u)
				fn_inst.rotation_degrees = start_r_deg.lerp(showcase_rot, u)
			, 0.0, 1.0, fly_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			c_tw.chain().tween_callback(func():
				var fn_inst := fn_wr.get_ref() as Node3D
				if my_token != _stagger_seq_token or not is_inside_tree() or not visible:
					if is_instance_valid(fn_inst):
						fn_inst.queue_free()
					return
				var slam_pitch := 0.96 + float(k) * 0.12 + clampf(eff_mult * 0.025, 0.0, 0.25)
				emit_signal("play_sfx_pitched_requested", "card_slam", slam_pitch)
				cam_spring.trigger_slam_tap(k)
				_spawn_card_impact_dust(target_pos)
				if k == cnt - 1:
					_spawn_suit_discard_rune_ring_3d(target_pos, chosen_suit)
				if force_lightning and k == cnt - 1:
					emit_signal("play_sfx_pitched_requested", "puf", 0.62)
					_spawn_lightning_bolt_3d(target_pos, c_data.get("accent", s_obj["col"]))
					_spawn_impact_shockwave(target_pos, Color(0.55, 0.88, 1.0), 3.1)
				else:
					_spawn_impact_shockwave(target_pos, s_obj["col"], 2.1 + float(k) * 0.35)

				if k == cnt - 1:
					_execute_balatro_stagger_timeline(my_token, score_res, chosen_cards, _scored_display_nodes, s_obj, target_pos, force_lightning)
			)
	)

func _hop_scored_card(card_node: Node3D, wiggle_sign: float = 1.0, big: bool = false) -> void:
	if not is_instance_valid(card_node):
		return
	var orig_y := card_node.position.y
	var orig_rz := card_node.rotation_degrees.z
	var peak_s := Vector3(1.26, 1.26, 1.26) if big else Vector3(1.18, 1.18, 1.18)
	var tw := card_node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card_node, "position:y", orig_y + (0.095 if big else 0.055), 0.075).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_node, "scale", peak_s, 0.075).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_node, "rotation_degrees:z", orig_rz + wiggle_sign * (11.0 if big else 7.0), 0.075)
	tw.chain().set_parallel(true)
	tw.tween_property(card_node, "position:y", orig_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card_node, "scale", Vector3(1.06, 1.06, 1.06), 0.14)
	tw.tween_property(card_node, "rotation_degrees:z", orig_rz, 0.14)

func _execute_balatro_stagger_timeline(
	token: int,
	score_res: Dictionary,
	chosen_cards: Array[Dictionary],
	scored_nodes: Array[Node3D],
	s_obj: Dictionary,
	impact_pos: Vector3,
	force_lightning: bool,
	skip_power_showcase: bool = false
) -> void:
	if token != _stagger_seq_token or not is_inside_tree() or not visible:
		return

	var cnt := chosen_cards.size()
	var sig_sword_fx := _spawn_signature_play_vfx(chosen_cards, impact_pos, cnt, skip_power_showcase)

	var slam_name := str(score_res.get("slam_name", "Hand"))
	var slam_title := ("%s (%d×)" % [slam_name.to_upper(), cnt]) if cnt > 1 else ("%s" % slam_name.to_upper() if force_lightning else slam_name.to_upper())
	var card_val := int(score_res.get("card_value", score_res.get("base_chips", 0)))
	var total_pts := int(score_res.get("final_score", card_val * cnt))
	var musical_step := 0

	var steps: Array = score_res.get("steps", [])
	var chip_steps: Array[Dictionary] = []
	var edition_power_steps: Array[Dictionary] = []
	var relic_steps_raw: Array[Dictionary] = []
	var post_steps: Array[Dictionary] = []

	for st in steps:
		var ph := str(st.get("phase", ""))
		if ph == "slam":
			continue
		elif ph == "card":
			chip_steps.append(st)
		elif ph == "prsi":
			edition_power_steps.append(st)
		elif ph == "edition" or ph == "power":
			edition_power_steps.append(st)
		elif ph == "relic":
			relic_steps_raw.append(st)
		elif ph == "shed" or ph == "boss" or ph == "finisher":
			post_steps.append(st)

	var relic_pass1: Array[Dictionary] = []
	var relic_pass2: Array[Dictionary] = []
	var seen_in_pass1 := {}
	for rs in relic_steps_raw:
		var rid := str(rs.get("relic_id", ""))
		if rid != "" and seen_in_pass1.has(rid):
			relic_pass2.append(rs)
		else:
			if rid != "":
				seen_in_pass1[rid] = true
			relic_pass1.append(rs)
	var sort_hud_order := func(a: Dictionary, b: Dictionary) -> bool:
		var ia := run_active_relics.find(str(a.get("relic_id", "")))
		var ib := run_active_relics.find(str(b.get("relic_id", "")))
		if ia == -1: ia = 999
		if ib == -1: ib = 999
		return ia < ib
	relic_pass1.sort_custom(sort_hud_order)
	relic_pass2.sort_custom(sort_hud_order)
	var relic_ordered: Array[Dictionary] = []
	relic_ordered.append_array(relic_pass1)
	relic_ordered.append_array(relic_pass2)

	var total_steps_count := chip_steps.size() + edition_power_steps.size() + relic_ordered.size() + post_steps.size()
	var step_cursor := 0
	var astrolabe_dur := maxf(
		_pace(1.35),
		_pace(0.14) * float(chip_steps.size()) + _pace(0.20) * float(edition_power_steps.size() + relic_ordered.size() + post_steps.size()) + _pace(0.65)
	)
	if is_instance_valid(_active_astrolabe_stage):
		_active_astrolabe_stage.queue_free()
	_active_astrolabe_stage = BlenderVfx.spawn_scoring_astrolabe(self, impact_pos, s_obj["col"], astrolabe_dur)
	_register_blender_vfx(_active_astrolabe_stage)

	if hud_combo_revealed:
		_update_combo_hud(slam_title, card_val, 1.0, card_val, false, 1.0)
	if cards_points_revealed or hud_combo_revealed:
		_show_stagger_callout(slam_title, s_obj["col"], 1.18)
		_update_stagger_equation_theatre(card_val, 1.0, 1.0, card_val, 0, total_steps_count, "chips")

	var sword_fired_idxs := {}
	if is_instance_valid(sig_sword_fx):
		sword_fired_idxs[0] = true

	# Per-card crisp kinetic hop (Card Value × Running Count)
	for ci in range(chip_steps.size()):
		await get_tree().create_timer(_pace(0.14)).timeout
		if token != _stagger_seq_token or not is_inside_tree() or not visible:
			return
		step_cursor += 1
		var st: Dictionary = chip_steps[ci]
		var running_cnt := ci + 1
		var running_tot := int(st.get("chips_after", card_val * running_cnt))
		if hud_combo_revealed:
			_update_combo_hud(slam_title, card_val, float(running_cnt), running_tot, false, 1.0)
			_punch_hud_label(chips_lbl, 1.24)
			if running_cnt > 1:
				_punch_hud_label(flat_mult_lbl, 1.28)
		var cnode: Node3D = scored_nodes[mini(ci, maxi(0, scored_nodes.size() - 1))] if not scored_nodes.is_empty() else null
		var pop_pos := ((cnode.global_position + Vector3(0.0, 0.085, 0.0)) if is_instance_valid(cnode) else (impact_pos + Vector3(0.0, 0.12, 0.0)))
		if is_instance_valid(cnode):
			_hop_scored_card(cnode, -1.0 if (ci % 2 == 0) else 1.0, false)
		var ccol: Color = st.get("color", Color(0.56, 0.92, 1.0))
		Fx.burst(self, pop_pos - Vector3(0.0, 0.04, 0.0), ccol, 12, 0.92, 0.42, 0.024, 1.6, true, 130.0, Vector3.UP, true)
		BlenderVfx.spawn_scoring_token_arc(self, "Token_ChipCoin", pop_pos, impact_pos + Vector3(0.0, 0.12, 0.0), ccol, _pace(0.28), 0.18, 2)
		if is_instance_valid(_active_astrolabe_stage):
			BlenderVfx.pulse_astrolabe(_active_astrolabe_stage, ccol, 1.05)
		if cards_points_revealed:
			Fx.float_number(self, pop_pos, str(st.get("label", "+%d" % card_val)), ccol.lightened(0.18), 54, 0.20, 0.85, 1.35)
			_update_stagger_equation_theatre(card_val, float(running_cnt), 1.0, running_tot, step_cursor, total_steps_count, "chips")
		var semi_pitch := clampf(pow(2.0, float(musical_step) / 12.0), 0.95, 2.05)
		musical_step += 1
		emit_signal("play_sfx_pitched_requested", "card_hover", semi_pitch)
		emit_signal("play_sfx_pitched_requested", "chord_lute", semi_pitch * 0.88)
		if ci < chosen_cards.size() and not sword_fired_idxs.has(ci) and _should_play_weapon_card_anim(chosen_cards[ci], cnt):
			var sc_card: Dictionary = chosen_cards[ci]
			var sc_cls := Catalog.normalize_card_class(str(sc_card.get("edition", "NORMAL")))
			sword_fired_idxs[ci] = true
			var sword_pos := (cnode.global_position if is_instance_valid(cnode) else impact_pos)
			var sc_fx := SwordCardAnim.play_sword_card_score_anim(self, sc_card, cnode, true, sword_pos, running_tot, float(running_cnt), sc_cls == "KNIGHT")
			_register_blender_vfx(sc_fx)
			await get_tree().create_timer(_pace(0.55)).timeout
			if token != _stagger_seq_token or not is_inside_tree() or not visible:
				return
		elif ci == 0 and cnt == 1:
			await get_tree().create_timer(_pace(0.18)).timeout
			if token != _stagger_seq_token or not is_inside_tree() or not visible:
				return

	# Tactical Editions & Power Card Triggers (simplified score preserved!)
	for ei in range(edition_power_steps.size()):
		await get_tree().create_timer(_pace(0.20)).timeout
		if token != _stagger_seq_token or not is_inside_tree() or not visible:
			return
		step_cursor += 1
		var st: Dictionary = edition_power_steps[ei]
		var ecol: Color = st.get("color", Color(0.95, 0.72, 1.0))
		var sc_cnt := maxi(1, scored_nodes.size())
		var cidx := ei % sc_cnt
		var cnode: Node3D = scored_nodes[cidx] if not scored_nodes.is_empty() else null
		var pop_pos := ((cnode.global_position + Vector3(0.0, 0.20, 0.0)) if is_instance_valid(cnode) else (impact_pos + Vector3(0.0, 0.22, 0.0)))
		if is_instance_valid(cnode):
			_hop_scored_card(cnode, 1.0 if (ei % 2 == 0) else -1.0, true)
		_spawn_edition_burst_3d(pop_pos - Vector3(0.0, 0.08, 0.0), ecol)
		if is_instance_valid(_active_astrolabe_stage):
			BlenderVfx.pulse_astrolabe(_active_astrolabe_stage, ecol, 1.20)
		var lbl_s := str(st.get("label", ""))
		var sword_triggered_step3 := false
		if "KNIGHT MISTBLADE" in lbl_s or "KNIGHT MIST" in lbl_s or "RYTÍŘSKÁ MLHA" in lbl_s or "RYTÍŘ V MLZE" in lbl_s:
			var k_idx := -1
			for ki in range(chosen_cards.size()):
				if Catalog.normalize_card_class(str(chosen_cards[ki].get("edition", "NORMAL"))) == "KNIGHT" and not sword_fired_idxs.has(ki):
					k_idx = ki
					break
			if k_idx != -1:
				sword_fired_idxs[k_idx] = true
				var k_card: Dictionary = chosen_cards[k_idx] if not chosen_cards.is_empty() else {}
				var k_node: Node3D = scored_nodes[k_idx] if k_idx < scored_nodes.size() else cnode
				var k_pos := (k_node.global_position if is_instance_valid(k_node) else impact_pos)
				var k_fx := SwordCardAnim.play_sword_card_score_anim(self, k_card, k_node, true, k_pos, total_pts, float(cnt), true)
				_register_blender_vfx(k_fx)
				sword_triggered_step3 = true
		Fx.float_number(self, pop_pos, lbl_s, ecol.lightened(0.22), 52, 0.22, 0.90, 1.35)
		_show_stagger_callout(lbl_s, ecol, 1.18)
		_update_stagger_equation_theatre(card_val, float(cnt), 1.0, total_pts, step_cursor, total_steps_count, "chips")
		if "Vampire" in lbl_s or "Upír" in lbl_s or "Shadow Hex" in lbl_s or "Stínový" in lbl_s or "Frost" in lbl_s or "Mráz" in lbl_s:
			_trigger_boss_recoil_stagger(false)
			Fx.burst(self, opp_hands_anchor.global_position + Vector3(0, 0.14, 0.05), ecol, 18, 1.2, 0.50, 0.032, 1.3, true, 145.0, Vector3.UP, true)
		elif "Loaded Dice" in lbl_s or "Kostky" in lbl_s or "Midas" in lbl_s or "Royal Decree" in lbl_s or "Královský" in lbl_s:
			Fx.gold_flakes(self, pop_pos, 20, 0.95)
		elif "Phoenix" in lbl_s or "Fénix" in lbl_s or "Alchemist" in lbl_s or "Alchymist" in lbl_s:
			Fx.embers(self, pop_pos - Vector3(0, 0.06, 0), 22, 0.95)
		var semi_pitch := clampf(pow(2.0, float(musical_step) / 12.0), 1.05, 2.25)
		musical_step += 1
		emit_signal("play_sfx_pitched_requested", "card_deal", semi_pitch)
		emit_signal("play_sfx_pitched_requested", "chord_lute", semi_pitch)
		if sword_triggered_step3:
			await get_tree().create_timer(_pace(0.32)).timeout
			if token != _stagger_seq_token or not is_inside_tree() or not visible:
				return

	# Relic Pedestal Pulse Feedback
	for ri in range(relic_ordered.size()):
		await get_tree().create_timer(_pace(0.18)).timeout
		if token != _stagger_seq_token or not is_inside_tree() or not visible:
			return
		step_cursor += 1
		var st: Dictionary = relic_ordered[ri]
		var rid := str(st.get("relic_id", ""))
		if rid != "":
			_pulse_relic_trigger(rid, str(st.get("label", "")), false)
		else:
			_show_stagger_callout(str(st.get("label", "")), st.get("color", Color(1.0, 0.85, 0.35)), 1.15)
		_update_stagger_equation_theatre(card_val, float(cnt), 1.0, total_pts, step_cursor, total_steps_count, "chips")
		var r_pitch := clampf(pow(2.0, float(musical_step) / 12.0), 1.08, 2.35)
		musical_step += 1
		emit_signal("play_sfx_pitched_requested", "ui_click", r_pitch)

	for pi in range(post_steps.size()):
		await get_tree().create_timer(_pace(0.18)).timeout
		if token != _stagger_seq_token or not is_inside_tree() or not visible:
			return
		step_cursor += 1
		var st: Dictionary = post_steps[pi]
		var pcol: Color = st.get("color", Color(1.0, 0.86, 0.30))
		_spawn_edition_burst_3d(impact_pos, pcol)
		Fx.float_number(self, impact_pos + Vector3(0.0, 0.24, 0.0), str(st.get("label", "")), pcol.lightened(0.2), 70, 0.24, 0.95, 1.65)
		_show_stagger_callout(str(st.get("label", "")), pcol, 1.20)
		_update_stagger_equation_theatre(card_val, float(cnt), 1.0, total_pts, step_cursor, total_steps_count, "total")
		if str(st.get("phase", "")) == "boss":
			_trigger_boss_modifier_flare(str(st.get("label", "")))
		else:
			emit_signal("play_sfx_pitched_requested", "card_deal", 1.55)

	# Climax: Flagship Slam Shockwave + Immediate Score Credit
	var eff_mult := float(score_res.get("effective_mult", float(cnt)))
	var is_shed := bool(score_res.get("shed_finisher", false))
	var is_big_boom := (total_pts >= 24 or cnt >= 2 or is_shed)
	var is_on_fire := (total_pts >= 30 or cnt >= 3 or is_shed)
	if cnt >= 3 or is_shed:
		overdrive_light_target = 1.4
	elif is_on_fire:
		overdrive_light_target = maxf(overdrive_light_target, 0.75)

	await get_tree().create_timer(_pace(0.18)).timeout
	if token != _stagger_seq_token or not is_inside_tree() or not visible:
		return

	var queued_desc := _tr("∞ %d× Eight Chain (+%d pts)" % [cnt, total_pts], "∞ %d× Osmičky (+%d b.)" % [cnt, total_pts]) if (cnt >= 2 and str(chosen_cards[0].get("rank", "")) == "8") else ("%s %s (+%d %s)" % [s_obj["sym"], _get_rank_name(str(chosen_cards[0].get("rank", "8"))) if str(chosen_cards[0].get("power_id", "")) == "" else str(Catalog.get_power_card_loc(str(chosen_cards[0].get("power_id", "")), opts_language).get("name", chosen_cards[0].get("rname", "Card"))), total_pts, _tr("pts", "b.")] if not chosen_cards.is_empty() else ("+%d %s" % [total_pts, _tr("pts", "b.")]))

	var ace_dmg := int(score_res.get("ace_hp_damage", 0))
	if ace_dmg > 0 and (not tutorial_mode or tutorial_step >= 5):
		var ace_cnt := 0
		for cc_a in chosen_cards:
			if str(cc_a.get("rank", "")) == "E" and Catalog.normalize_card_class(str(cc_a.get("edition", "NORMAL"))) != "MERCHANT":
				ace_cnt += 1
		_apply_hp_damage(false, ace_dmg, _tr("%d× ACE STRIKE!" % maxi(1, ace_cnt), "ÚDER %d× ESA!" % maxi(1, ace_cnt)), bankai_active)

	var climax_col: Color = Color(1.0, 0.86, 0.28) if (is_shed or cnt >= 2 or force_lightning or is_on_fire) else s_obj["col"].lightened(0.30)
	var played_has_knight := false
	var played_has_mage := false
	var played_mage_charged := false
	var played_has_thief := false
	var played_has_merchant := false
	for cc_fx in chosen_cards:
		var cls_fx := Catalog.normalize_card_class(str(cc_fx.get("edition", "NORMAL")))
		if cls_fx == "KNIGHT":
			played_has_knight = true
		elif cls_fx == "MAGE":
			played_has_mage = true
			if int(cc_fx.get("mage_charge", 0)) >= 2:
				played_mage_charged = true
		elif cls_fx == "THIEF":
			played_has_thief = true
		elif cls_fx == "MERCHANT":
			played_has_merchant = true

	var rival_fx_pos := opp_hands_anchor.global_position + Vector3(0.0, 0.14, 0.0) if is_instance_valid(opp_hands_anchor) else Vector3(0.0, 1.05, -1.05)
	if played_has_knight:
		Fx.knight_heavy_steel_slam(self, impact_pos, climax_col, 1.40 if cnt >= 2 else 1.20)
	else:
		Fx.card_slam_master(self, impact_pos, climax_col, 1.25 if cnt >= 2 else 1.0)
	if played_has_mage:
		Fx.mage_arcane_cast(self, impact_pos, rival_fx_pos, Color(0.50, 0.36, 1.0), played_mage_charged)
	if played_has_thief:
		Fx.thief_shunpo_strike(self, impact_pos, rival_fx_pos, Color(0.18, 0.92, 0.56))
	if played_has_merchant:
		Fx.merchant_gold_vault(self, impact_pos)
	if cnt >= 2 or total_pts >= 28 or is_shed:
		Fx.tybw_slash_arc(self, impact_pos + Vector3(0.0, 0.22, 0.0), rival_fx_pos, climax_col, true, 1.20 if cnt >= 2 else 1.05, -24.0)

	_award_player_score_immediately(total_pts, queued_desc, climax_col, total_pts, queued_desc, card_val, cnt)

	if hud_combo_revealed:
		var xm_res := float(score_res.get("x_mult_product", 1.0))
		var final_title := "✦ " + str(score_res.get("formula_summary", "+%s!" % _format_pts_ui(total_pts)))
		_update_combo_hud(final_title, int(score_res.get("total_chips", card_val)), float(cnt), total_pts, true, xm_res)
		_set_score_breakdown_chips(score_res.get("breakdown_chips", []))
		_punch_hud_label(total_calc_lbl, 1.44 if is_on_fire else 1.32)
	if cards_points_revealed:
		var is_eight_chain := (cnt >= 2 and str(chosen_cards[0].get("rank", "")) == "8")
		var mult_tag := ""
		if eff_mult >= 4.0:
			mult_tag = _tr("%d× CATACLYSM! " % int(round(eff_mult)), "%d× KATAKLYZMA! " % int(round(eff_mult)))
		elif eff_mult >= 3.0:
			mult_tag = _tr("3× FURY! ", "3× ZUŘIVOST! ")
		elif eff_mult >= 2.0:
			mult_tag = _tr("2× SLAM! ", "2× ÚDER! ")
		var final_txt := ("★ %d × %d = +%s!" % [card_val, cnt, _format_pts_ui(total_pts)]) if is_eight_chain else (_tr("★ %s+%s PTS!" % [mult_tag, _format_pts_ui(total_pts)], "★ %s+%s BODŮ!" % [mult_tag, _format_pts_ui(total_pts)]))
		_show_stagger_callout(final_txt, climax_col, clampf(1.28 + eff_mult * 0.08, 1.28, 1.65))
		_update_stagger_equation_theatre(card_val, float(cnt), 1.0, total_pts, total_steps_count, total_steps_count, "total")
		var float_sz := 98 if eff_mult >= 4.0 else (88 if eff_mult >= 3.0 else (80 if eff_mult >= 2.0 else 72))
		var float_sc := clampf(1.55 + eff_mult * 0.14, 1.55, 2.25)
		Fx.float_number(self, impact_pos + Vector3(-0.06, 0.30, 0.06), "+%s" % _format_pts_ui(total_pts), climax_col, float_sz, 0.36, 1.20, float_sc)
		if eff_mult >= 2.0:
			Fx.float_number(self, impact_pos + Vector3(0.14, 0.44, -0.04), "%d×!" % int(round(eff_mult)), Color(1.0, 0.92, 0.36), float_sz + 10, 0.30, 1.05, float_sc * 1.1)

	# Fiery & lightning streak particles flying from 3D card impact toward the Score HUD
	if is_instance_valid(cam) and is_instance_valid(score_chalice_art):
		var imp_2d := cam.unproject_position(impact_pos + Vector3(0.0, 0.16, 0.0))
		var hud_tgt := score_chalice_art.global_position + score_chalice_art.size * 0.5
		var streak_cnt := clampi(8 + int(round(eff_mult)) * 5, 10, 28)
		for si in range(streak_cnt):
			var s_col := Color(0.42, 0.94, 1.0) if (si % 3 == 0 and eff_mult >= 2.0) else Color(1.0, randf_range(0.48, 0.90), 0.16)
			_score_fx_orbs.append({
				"start": imp_2d + Vector2(randf_range(-24.0, 24.0), randf_range(-18.0, 18.0)),
				"pos": imp_2d,
				"prev_pos": imp_2d,
				"ctrl": imp_2d.lerp(hud_tgt, 0.42) + Vector2(randf_range(-130.0, 130.0), randf_range(-110.0, 80.0)),
				"target": hud_tgt + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)),
				"t": -float(si) * 0.015,
				"dur": randf_range(0.28, 0.46),
				"sz": randf_range(4.0, 7.2),
				"col": s_col,
			})
		if score_fx_overlay:
			score_fx_overlay.queue_redraw()
		if eff_mult >= 2.0:
			Fx.beam(self, impact_pos + Vector3(0.0, 0.14, 0.0), rival_fx_pos, Color(0.48, 0.92, 1.0) if eff_mult >= 3.0 else climax_col, 0.28)

	if is_instance_valid(_active_astrolabe_stage):
		BlenderVfx.pulse_astrolabe(_active_astrolabe_stage, climax_col, 1.65)
	if cnt >= 2 or is_shed:
		BlenderVfx.spawn_scoring_token_arc(self, "Token_ScoreCrown", impact_pos + Vector3(0.0, 0.55, 0.0), impact_pos + Vector3(0.0, 0.14, 0.0), climax_col, _pace(0.36), 0.10, 1)

	if is_on_fire:
		_trigger_boss_recoil_stagger(true)
		emit_signal("play_sfx_pitched_requested", "chord_lute", 1.40)
	elif is_big_boom:
		_trigger_boss_recoil_stagger(false)

	var juice_str := clampf(0.22 + log(maxf(8.0, float(total_pts))) * 0.06 + (eff_mult - 1.0) * 0.05, 0.22, 0.62)
	_trigger_screen_juice(climax_col, juice_str, 0.42)
	cam_spring.trigger_score_recoil(total_pts, eff_mult * (1.35 if eff_mult >= 3.0 else 1.12), clampf(0.85 + eff_mult * 0.22, 0.85, 1.95))
	emit_signal("play_sfx_pitched_requested", "card_slam", clampf(0.95 + float(cnt) * 0.08, 0.95, 1.42))

	# Brief micro hit-stop on 2×+ combos or big slams
	if eff_mult >= 2.0 or is_shed or total_pts >= 30:
		Engine.time_scale = 0.25
		await get_tree().create_timer(0.045, true, false, true).timeout
		Engine.time_scale = 1.0
		if token != _stagger_seq_token or not is_inside_tree() or not visible:
			return

	_rebuild_all_3d_hands()
	_refresh_table_labels()

	await get_tree().create_timer(_pace(0.45)).timeout
	if token != _stagger_seq_token or not is_inside_tree() or not visible:
		return

	var k_mist_now := bool(score_res.get("knight_mist_triggered", false)) and not tutorial_mode
	for k in range(scored_nodes.size()):
		var sn: Node3D = scored_nodes[k]
		if is_instance_valid(sn):
			sn.queue_free()
		if k < chosen_cards.size():
			var cd: Dictionary = chosen_cards[k]
			if str(cd.get("power_id", "")) == "SPEC_PHOENIX":
				Fx.embers(self, draw_deck_root.global_position + Vector3(0, 0.08, 0), 18, 0.85)
			else:
				if k_mist_now and k == chosen_cards.size() - 1:
					cd["_mist_hidden"] = true
					knight_mist_active = true
					knight_mist_from_ai = false
					knight_mist_hidden_card = cd.duplicate()
					if is_instance_valid(discard_mist_fx_root):
						discard_mist_fx_root.visible = true
				_add_card_mesh_to_discard_pile(cd)
	_scored_display_nodes.clear()

	cam_impact_active = false
	if stagger_callout_pill:
		stagger_callout_pill.visible = false
	if table_status_label3d:
		table_status_label3d.visible = (not tutorial_mode) and (not cards_tucked)
	if _check_win_or_redeal():
		return
	if extra_player_turn:
		extra_player_turn = false
		if pending_draw > 0:
			deferred_ai_draw += pending_draw
			pending_draw = 0
		if pending_skip:
			deferred_ai_skip = true
			pending_skip = false
		emit_signal("play_sfx_requested", "turn_player")
		_spawn_score_popup(_tr("CHRONOS TURN AGAIN!", "CHRONOS: TAH NAVÍC!"), Color(1.0, 0.88, 0.36), true)
		_rebuild_all_3d_hands()
		_refresh_table_labels()
		busy_animating = false
		is_player_turn = true
		relic_mgr.reset_turn()
		turn_stage = TurnStage.CARD_PLAY
		set_camera_view_mode(CameraViewMode.CARDS, true)
	elif bool(score_res.get("thief_heist_triggered", false)) and not tutorial_mode and not ai_hand.is_empty():
		_open_thief_heist_modal()
	else:
		_start_ai_3d_turn()

func _animate_magical_card_draw_3d(drawn_cards: Array, to_player: bool, on_finished: Callable) -> void:
	if drawn_cards.is_empty() or not is_instance_valid(draw_deck_root):
		if on_finished.is_valid():
			on_finished.call()
		return
	var my_sess := _battle_session_token
	var deck_origin := draw_deck_root.global_position + Vector3(0.0, 0.08, 0.0)
	var lead_suit := str(drawn_cards[0].get("suit", active_suit_id))
	var s_obj := _get_suit_obj(lead_suit)
	var draw_col: Color = Color(0.96, 0.42, 0.34) if not to_player else (s_obj.get("col", Color(0.95, 0.78, 0.32)) as Color).lightened(0.22)
	Fx.magical_draw_launch(self, deck_origin, draw_col)
	emit_signal("play_sfx_requested", "card_draw")

	var anim_cnt := mini(drawn_cards.size(), 4)
	var remaining := [anim_cnt]
	var base_dest := (player_hand_anchor.global_position + Vector3(0.04, 0.04, -0.02)) if to_player else (opp_hands_anchor.global_position + Vector3(0.0, 0.05, 0.08))

	for i in range(anim_cnt):
		var c_dict: Dictionary = drawn_cards[i]
		var fly_card := _build_3d_card_node(c_dict, to_player, draw_col)
		add_child(fly_card)
		var start_rot := Vector3(90.0, 0.0, 0.0) if to_player else Vector3(-90.0, 0.0, 0.0)
		var end_rot := Vector3(-14.0, 0.0, 6.0 + float(i) * 3.0) if to_player else Vector3(16.0, 180.0, float(i - 1) * 4.0)
		var fan_x := (float(i) - float(anim_cnt - 1) * 0.5) * 0.11
		var card_dest := base_dest + Vector3(fan_x, float(i) * 0.015, 0.0)
		fly_card.global_position = deck_origin
		fly_card.rotation_degrees = start_rot
		fly_card.scale = Vector3(0.76, 0.76, 0.76)

		var trail := Fx.attach_magical_card_trail(fly_card, draw_col)
		var ctrl_pt := deck_origin.lerp(card_dest, 0.48) + Vector3(fan_x * 0.6 + randf_range(-0.10, 0.10), 0.34 + float(i) * 0.03, 0.04 if to_player else -0.04)

		var fly_wr: WeakRef = weakref(fly_card)
		var tw := create_tween()
		if i > 0:
			tw.tween_interval(_pace(0.09) * float(i))
		tw.tween_method(func(u: float):
			var fn := fly_wr.get_ref() as Node3D
			if not is_instance_valid(fn) or my_sess != _battle_session_token or not is_inside_tree():
				return
			var eu := 1.0 - pow(1.0 - u, 2.2)
			var p0 := deck_origin.lerp(ctrl_pt, eu)
			var p1 := ctrl_pt.lerp(card_dest, eu)
			fn.global_position = p0.lerp(p1, eu)
			fn.rotation_degrees = start_rot.lerp(end_rot, eu)
			var sc := lerpf(0.76, 0.98, eu) + sin(eu * PI) * 0.18
			fn.scale = Vector3(sc, sc, sc)
		, 0.0, 1.0, _pace(0.42))
		tw.tween_callback(func():
			var fn := fly_wr.get_ref() as Node3D
			if is_instance_valid(fn):
				Fx.burst(self, card_dest, draw_col.lightened(0.25), 10, 0.75, 0.38, 0.022, 1.4, true, 120.0, Vector3.UP, true)
				emit_signal("play_sfx_pitched_requested", "card_deal", 0.96 + float(i) * 0.08)
				for ch in fn.get_children():
					if ch is MeshInstance3D or ch is Label3D:
						(ch as Node3D).visible = false
				var sp_p := trail.get("sparks") as CPUParticles3D
				if is_instance_valid(sp_p):
					sp_p.emitting = false
				var ms_p := trail.get("mist") as CPUParticles3D
				if is_instance_valid(ms_p):
					ms_p.emitting = false
				var lg := trail.get("light") as OmniLight3D
				if is_instance_valid(lg):
					var ltw := lg.create_tween()
					ltw.tween_property(lg, "light_energy", 0.0, 0.18)
				get_tree().create_timer(0.28).timeout.connect(func():
					if is_instance_valid(fn):
						fn.queue_free()
				)
			if my_sess != _battle_session_token or not is_inside_tree() or not visible:
				return
			remaining[0] -= 1
			if remaining[0] == 0 and on_finished.is_valid():
				on_finished.call()
		)

func _sync_contextual_cancel_btn() -> void:
	if not hud_root:
		return
	var mb := hud_root.get_node_or_null("MapExitBtn") as Button
	if not is_instance_valid(mb):
		return
	var has_selection := (not staged_card_indices.is_empty()) or (is_instance_valid(suit_modal) and suit_modal.visible)
	mb.visible = (not tutorial_mode) and is_player_turn and (not busy_animating) and has_selection
	mb.text = _tr("Cancel", "Zrušit")

func _refresh_bankai_seal_hud() -> void:
	if not is_instance_valid(bankai_seal_pill) or not is_instance_valid(bankai_seal_lbl):
		return
	if tutorial_mode or bankai_combo.is_empty() or (not bankai_active and bankai_charged.is_empty()):
		bankai_seal_pill.visible = false
		return
	bankai_seal_pill.visible = true
	var b := Catalog.get_deck_build_loc(bankai_build_id, opts_language)
	var b_col: Color = b.get("col", Color(0.32, 0.88, 1.0))
	if bankai_active:
		bankai_seal_lbl.text = "%s" % str(b.get("bankai_name", _tr("GRAND SEAL ACTIVE", "VELKÁ PEČEŤ AKTIVNÍ")))
		bankai_seal_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.56))
	else:
		bankai_seal_lbl.text = _tr("GRAND SEAL: %d / 4" % bankai_charged.size(), "VELKÁ PEČEŤ: %d / 4" % bankai_charged.size())
		bankai_seal_lbl.add_theme_color_override("font_color", b_col.lightened(0.22))


func _check_and_trigger_bankai(chosen_cards: Array) -> void:
	if bankai_active or bankai_combo.size() < 4:
		return
	var gained_any := false
	for card in chosen_cards:
		var ck := "%s_%s" % [str(card.get("suit", "")), str(card.get("rank", ""))]
		if (ck in bankai_combo) and not (ck in bankai_charged):
			bankai_charged.append(ck)
			gained_any = true
	# Also support instant 4-card Bankai when playing any 4-card slam matching rank/combo
	if chosen_cards.size() >= 4 and bankai_charged.size() < 4:
		var all_in_seal := true
		for card in chosen_cards:
			var ck2 := "%s_%s" % [str(card.get("suit", "")), str(card.get("rank", ""))]
			if not (ck2 in bankai_combo):
				all_in_seal = false
				break
		if all_in_seal:
			bankai_charged = bankai_combo.duplicate()
			gained_any = true
	if gained_any:
		_refresh_bankai_seal_hud()
	if bankai_charged.size() >= 4 and not bankai_active:
		bankai_active = true
		_refresh_bankai_seal_hud()
		cam_kick_shake = maxf(cam_kick_shake, 0.55)
		if is_instance_valid(bankai_fx):
			bankai_fx.trigger_bankai(bankai_build_id, _tr("YOU", "TY"), bankai_combo, opts_language, true)
		match bankai_build_id:
			"MIRROR_MONARCH":
				player_shields += 2
			"MISTBLADE_DUELIST":
				for hc in player_hand:
					if Catalog.normalize_card_class(str(hc.get("edition", hc.get("card_class", "NORMAL")))) == "MAGE":
						hc["mage_charge"] = 2
			"CHAOS_JESTER":
				ai_score = maxi(0, ai_score - 14)
				display_ai_score = float(ai_score)
		if not tutorial_mode:
			_apply_hp_damage(false, 2, _tr("GRAND SEAL FINISHER!", "ÚDER VELKÉ PEČETĚ!"), true)
		if combat_log_drawer != null:
			var b_loc := Catalog.get_deck_build_loc(bankai_build_id, opts_language)
			combat_log_drawer.add_entry("%s — %s" % [str(b_loc["bankai_name"]), str(b_loc["bankai_desc"])], b_loc["col"])


func _step_player_turn_timer(delta: float, t_sec: float) -> void:
	if not is_instance_valid(turn_timer_pill):
		return
	var modal_blocking := (is_instance_valid(suit_modal) and suit_modal.visible) or peddler_open or shop_gate_open
	var can_tick := is_player_turn and (not busy_animating) and (not intro_animating) and (not tutorial_mode) and (not modal_blocking) and (not _is_cinematic_playing()) and (not player_hand.is_empty())
	if not is_player_turn or tutorial_mode or player_hand.is_empty():
		_turn_timer_was_active = false
		_turn_timer_last_tick_sec = -1
		turn_timer_pill.visible = false
		return
	if not _turn_timer_was_active:
		_turn_timer_was_active = true
		player_turn_timer = clampf(opts_turn_timer_sec, 30.0, 45.0)
		_turn_timer_last_tick_sec = -1
	turn_timer_pill.visible = true
	if can_tick:
		player_turn_timer = maxf(0.0, player_turn_timer - delta)
	var max_t := clampf(opts_turn_timer_sec, 30.0, 45.0)
	var frac := clampf(player_turn_timer / max_t, 0.0, 1.0)
	var sec_ceil := int(ceil(player_turn_timer))
	var bar_col := Color(0.96, 0.78, 0.26, 0.96)
	if player_turn_timer <= 10.0:
		var p := 0.55 + 0.45 * absf(sin(t_sec * 7.5))
		bar_col = Color(1.0, 0.22 * p, 0.20, 0.98)
		if can_tick and sec_ceil > 0 and sec_ceil <= 5 and sec_ceil != _turn_timer_last_tick_sec:
			_turn_timer_last_tick_sec = sec_ceil
			emit_signal("play_sfx_requested", "btn_card_tick")
	elif player_turn_timer <= 15.0:
		bar_col = Color(1.0, 0.56, 0.18, 0.96)
	if is_instance_valid(turn_timer_lbl):
		turn_timer_lbl.text = _tr("TURN: %ds" % sec_ceil, "TAH: %d s" % sec_ceil)
		turn_timer_lbl.add_theme_color_override("font_color", bar_col.lightened(0.22))
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.anchor_right = frac
		turn_timer_bar.color = bar_col
	if can_tick and player_turn_timer <= 0.0:
		_turn_timer_was_active = false
		_show_stagger_callout(_tr("TIME'S UP — AUTO-DRAW!", "ČAS VYPRŠEL — AUTOMATICKÉ LÍZNUTÍ!"), Color(1.0, 0.44, 0.24), 1.6)
		_player_draw_from_3d_deck()


func _player_draw_from_3d_deck() -> void:
	turn_stage = TurnStage.RESOLVING
	opening_turn_committed = true
	if wager_bar_panel:
		wager_bar_panel.visible = false
	busy_animating = true
	staged_card_indices.clear()
	tutorial_turns_left = maxi(0, tutorial_turns_left - 1)
	_tutorial_action_done = "drew_card"
	player_glove_action_offset = Vector3(-0.08, 0.04, -0.18)

	if pending_skip:
		pending_skip_turns = maxi(0, pending_skip_turns - 1)
		pending_skip = (pending_skip_turns > 0)
		emit_signal("play_sfx_requested", "error")
		_show_stagger_callout(_tr("FROZEN BY ACE — TURN SKIPPED!", "ZMRAZEN ESEM — TAH PŘESKOČEN!"), Color(0.45, 0.90, 1.0), 1.4)
		_spawn_score_popup(_tr("FROZEN BY ACE!", "ZMRAZEN ESEM!"), Color(0.45, 0.90, 1.0), true)
		table_status_label3d.text = _tr("Frozen by Rival's Ace! (%d turn(s) lock)" % (pending_skip_turns + 1), "Zmrazen soupeřovým Esem! (%d tah(y) stop)" % (pending_skip_turns + 1))
		_rebuild_all_3d_hands()
		_refresh_table_labels()
		if not tutorial_mode:
			_check_battle_unlock_tips()
		_start_ai_3d_turn()
		return

	if not pending_king_challenge.is_empty() and bool(pending_king_challenge.get("from_ai", false)):
		_apply_king_curse_to_player(str(pending_king_challenge.get("suit", "CERVEN")))
		pending_king_challenge.clear()
		if _check_win_or_redeal():
			return

	var cnt := pending_draw if pending_draw > 0 else 1
	var was_penalty := pending_draw > 0
	pending_draw = 0
	if was_penalty and pending_ai_seven_trap_bonus > 0:
		_award_ai_score_immediately(pending_ai_seven_trap_bonus, _tr("7 TRAP! +%d Rival" % pending_ai_seven_trap_bonus, "PAST 7! +%d Soupeř" % pending_ai_seven_trap_bonus), Color(1.0, 0.40, 0.34))
		pending_ai_seven_trap_bonus = 0

	if not tutorial_mode and not was_penalty and active_boss_mod == "SCROLL_TAX":
		player_score = maxi(0, player_score - 4)
		_trigger_boss_modifier_flare(_tr("Scroll Tax: -4 pts!", "Daň svitků: -4 b.!"))
		_spawn_score_popup(_tr("-4 SCROLL TAX!", "-4 DAŇ SVITKŮ!"), Color(0.95, 0.45, 0.35), true)

	emit_signal("play_sfx_requested", "card_draw")
	var drawn_cards: Array = []
	for i in range(cnt):
		var c := _draw_from_deck()
		player_hand.append(c)
		drawn_cards.append(c)
	_rebuild_all_3d_hands()
	_refresh_table_labels()

	var my_sess := _battle_session_token
	_animate_magical_card_draw_3d(drawn_cards, true, func():
		if my_sess != _battle_session_token or not is_inside_tree() or not visible:
			return
		table_status_label3d.text = _tr("Drew +%d penalty cards." % cnt, "Lízl jsi +%d trestných karet." % cnt) if was_penalty else _tr("Drew a card from deck.", "Lízl jsi kartu z balíčku.")
		_rebuild_all_3d_hands()
		_refresh_table_labels()
		if not tutorial_mode:
			_check_battle_unlock_tips()
		_start_ai_3d_turn()
	)

func _activate_magic_puf_3d() -> void:
	if puf_charges <= 0:
		emit_signal("play_sfx_requested", "error")
		table_status_label3d.text = _tr("No IGNIS Phial charges left!", "Baňka IGNIS už nemá žádné nabití!")
		return
	opening_turn_committed = true
	if wager_bar_panel:
		wager_bar_panel.visible = false
	busy_animating = true
	cam_impact_active = true
	puf_charges -= 1
	rival_burn_turns = 3
	if not tutorial_mode and "REL_ALEMBIC" in run_active_relics:
		_award_player_score_immediately(15, _tr("Alchemy Alembic (+15)", "Alchymická baňka (+15)"), Color(0.95, 0.72, 0.28))
		match_bonus_gold += 15
		_pulse_relic_trigger("REL_ALEMBIC", "+15 & +15!", false)
	player_glove_action_offset = Vector3(0.14, 0.10, -0.24)
	_refresh_table_labels()

	var coaster_pos: Vector3 = magic_puf_bottle.get_meta("base_pos", magic_puf_bottle.position)
	var coaster_global := to_global(coaster_pos)
	var target_global := opp_hands_anchor.global_position + Vector3(0.0, 0.06, 0.14)
	Fx.item_ritual_activation(self, coaster_global + Vector3(0.0, 0.06, 0.0), target_global, Color(1.0, 0.44, 0.12))
	emit_signal("play_sfx_requested", "card_throw_whoosh")
	emit_signal("play_sfx_pitched_requested", "anim_sword_unsheathe", 0.85)

	var was_status_vis := table_status_label3d.visible
	table_status_label3d.visible = false
	var puf_lbl_node := magic_puf_bottle.get_node_or_null("PufLabel") as Label3D
	if puf_lbl_node:
		puf_lbl_node.visible = false
	var my_sess := _battle_session_token
	magic_puf_bottle.visible = false

	var pm := _pace(1.0)
	# Smooth 3-phase heroic camera choreography matching 4.1s Blender throw + shatter detonation
	var cam_tw := create_tween()
	cam_tw.set_parallel(true)
	cam_tw.tween_property(cam, "position", Vector3(1.18, 1.24, 0.86), 0.95 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam_tw.tween_property(cam, "rotation_degrees:x", -19.0, 0.95 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam_tw.tween_property(cam, "rotation_degrees:y", 37.5, 0.95 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam_tw.tween_property(cam, "fov", 50.0, 0.95 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam_tw.chain().set_parallel(true)
	cam_tw.tween_property(cam, "position", Vector3(0.74, 1.46, 0.62), 1.10 * pm).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(cam, "rotation_degrees:x", -9.0, 1.10 * pm).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(cam, "rotation_degrees:y", 26.5, 1.10 * pm).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(cam, "fov", 52.0, 1.10 * pm).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var on_phial_impact := func() -> void:
		if my_sess != _battle_session_token or not is_inside_tree() or not visible:
			return
		dramatic_lighting_tint = Color(1.0, 0.40, 0.12)
		dramatic_lighting_dim = 0.48
		opp_shake_time = 2.10
		cam_kick_shake = 1.15
		cam_spring.trigger_score_recoil(380, 4.5, 1.25)
		if is_instance_valid(opp_fire_fx_root):
			opp_fire_fx_root.visible = true
		if is_instance_valid(opp_fire_light):
			opp_fire_light.light_energy = 1.1
		emit_signal("play_sfx_pitched_requested", "puf", 0.96)
		emit_signal("play_sfx_pitched_requested", "card_slam", 0.85)
		_trigger_screen_juice(Color(1.0, 0.44, 0.12), 0.85, 0.65, 0.45)
		_spawn_magic_puf_explosion_3d(target_global)
		_spawn_score_popup(_tr("HELLFIRE PHIAL! RIVAL BURNING (3t)!", "BAŇKA PEKELNÉHO OHNĚ! SOUPEŘ HOŘÍ (3 kola)!"), Color(1.0, 0.50, 0.14), true)
		table_status_label3d.text = _tr("RIVAL IS ON FIRE! (-14 pts/turn & -25%% power for 3 rounds!)", "SOUPEŘ HOŘÍ! (-14 b./tah a -25%% síly na 3 kola!)")
		_refresh_table_labels()
		var react_tw := create_tween()
		react_tw.tween_property(cam, "fov", 43.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		react_tw.tween_property(cam, "fov", 49.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	var on_phial_finish := func() -> void:
		if my_sess != _battle_session_token or not is_inside_tree() or not visible:
			return
		var dim_tw := create_tween()
		dim_tw.tween_property(self, "dramatic_lighting_dim", 0.0, 0.55 * pm)
		var ret_items := (turn_stage == TurnStage.ITEM_REVIEW)
		var ret_pos := Vector3(0.04, 1.44, 1.12) if ret_items else Vector3(0.0, 1.64, 1.48)
		var ret_pitch := base_cam_rot.x - 11.0 if ret_items else base_cam_rot.x + 0.5
		var ret_fov := 54.0 if ret_items else 59.0
		var back_tw := create_tween().set_parallel(true)
		back_tw.tween_property(cam, "position", ret_pos, 0.65 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		back_tw.tween_property(cam, "rotation_degrees:x", ret_pitch, 0.65 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		back_tw.tween_property(cam, "rotation_degrees:y", base_cam_rot.y, 0.65 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		back_tw.tween_property(cam, "fov", ret_fov, 0.65 * pm).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

		magic_puf_bottle.position = coaster_pos
		magic_puf_bottle.rotation_degrees = Vector3.ZERO
		magic_puf_bottle.scale = Vector3(0.05, 0.05, 0.05)
		magic_puf_bottle.visible = true
		var pop_tw := create_tween()
		pop_tw.tween_property(magic_puf_bottle, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		back_tw.chain().tween_callback(func():
			if my_sess != _battle_session_token or not is_inside_tree() or not visible:
				return
			table_status_label3d.visible = was_status_vis and not tutorial_mode
			if is_instance_valid(puf_lbl_node):
				puf_lbl_node.visible = true
			cam_impact_active = false
			busy_animating = false
			if tutorial_mode and tutorial_step == 6 and tutorial_substep == 1:
				_trigger_ghost_ok_flash()
				_advance_tutorial_to(7)
			else:
				_refresh_table_labels()
		)

	var throw_rig := SwordCardAnim.play_ignis_2d_anim(self, coaster_global, target_global, pm, on_phial_impact, on_phial_finish)
	_register_blender_vfx(throw_rig)
	if throw_rig == null:
		magic_puf_bottle.visible = true
		cam_impact_active = false
		busy_animating = false

func _spawn_magic_puf_explosion_3d(impact_global: Vector3) -> void:
	Fx.ring(self, impact_global + Vector3(0, -0.04, 0), Color(1.0, 0.44, 0.12), 1.15, 0.55, 0.14, 2.0, 12.0)
	Fx.ring(self, impact_global + Vector3(0, 0.06, 0), Color(1.0, 0.78, 0.24), 0.85, 0.46, 0.11, 1.8, 0.0)
	Fx.embers(self, impact_global, 48, 1.45)
	Fx.burst(self, impact_global, Color(1.0, 0.34, 0.08), 32, 1.6, 0.68, 0.065, 0.4, true, 160.0, Vector3.UP, true)
	Fx.float_number(self, opp_hands_anchor.global_position + Vector3(0, 0.30, 0), _tr("ON FIRE!", "V PLAMENECH!"), Color(1.0, 0.54, 0.14), 76, 0.24, 0.95, 1.85)

func _advance_mage_charges(amount: int = 1, player_only: bool = false) -> void:
	if amount <= 0:
		return
	var any_charged := false
	for hc in player_hand:
		if Catalog.normalize_card_class(str(hc.get("edition", "NORMAL"))) == "MAGE":
			var old_c := int(hc.get("mage_charge", 0))
			var new_c := mini(2, old_c + amount)
			hc["mage_charge"] = new_c
			if old_c < 2 and new_c >= 2:
				any_charged = true
	if any_charged:
		_spawn_score_popup(_tr("MAGE FULLY CHARGED (2/2)!", "MÁG PLNĚ NABIT (2/2)!"), Color(0.55, 0.92, 1.0), true)
	if not player_only:
		for ac in ai_hand:
			if Catalog.normalize_card_class(str(ac.get("edition", "NORMAL"))) == "MAGE":
				ac["mage_charge"] = mini(2, int(ac.get("mage_charge", 0)) + amount)

func _apply_king_curse_to_ai(k_suit: String) -> void:
	var k_hp_dmg := randi_range(1, 3)
	_apply_hp_damage(false, k_hp_dmg, _tr("KING CURSE", "KRÁLOVSKÁ KLETBA"))
	match k_suit:
		"CERVEN":
			ai_score = maxi(0, ai_score - 18)
			_spawn_score_popup(_tr("♥ KING DRAIN: Rival -18!", "♥ KRÁL: Soupeř -18 b.!"), Color(0.95, 0.28, 0.34), true)
		"GULA":
			ai_score = maxi(0, ai_score - 10)
			match_bonus_gold += 8
			rival_tax_debuff = true
			_spawn_score_popup(_tr("● KING TOLL: +8g & Taxed!", "● KRÁL: +8g & Daň!"), Color(1.0, 0.80, 0.24), true)
		"ZELEN":
			rival_poison_turns = maxi(rival_poison_turns, 2)
			_spawn_score_popup(_tr("♠ KING VENOM: 2t Poison!", "♠ KRÁL: Jed na 2 kola!"), Color(0.32, 0.88, 0.56), true)
		"ZALUD":
			rival_shatter_debuff = true
			_spawn_score_popup(_tr("♣ KING SHATTER: Next ×0.5!", "♣ KRÁL: Tříštění ×0.5!"), Color(0.84, 0.68, 0.40), true)

func _apply_king_curse_to_player(k_suit: String) -> void:
	if player_shields > 0:
		player_shields -= 1
		_spawn_score_popup(_tr("GUARD BLOCKED KING CURSE!", "ŠTÍT VYKRYL KRÁLE!"), Color(0.45, 0.94, 1.0), true)
		_refresh_table_labels()
		return
	var k_hp_dmg := randi_range(1, 3)
	_apply_hp_damage(true, k_hp_dmg, _tr("RIVAL KING", "SOUPEŘŮV KRÁL"))
	match k_suit:
		"CERVEN":
			player_score = maxi(0, player_score - 14)
			_spawn_score_popup(_tr("♥ RIVAL KING DRAIN: -14!", "♥ SOUPEŘŮV KRÁL: -14 b.!"), Color(1.0, 0.36, 0.36), false)
		"GULA":
			player_score = maxi(0, player_score - 8)
			player_tax_debuff = true
			_spawn_score_popup(_tr("● RIVAL KING TAX: -30% Next!", "● SOUPEŘŮV KRÁL: -30% tah!"), Color(1.0, 0.64, 0.24), false)
		"ZELEN":
			player_poison_turns = maxi(player_poison_turns, 2)
			_spawn_score_popup(_tr("♠ RIVAL VENOM: 2t Poison!", "♠ SOUPEŘŮV JED: 2 kola!"), Color(0.48, 0.88, 0.42), false)
		"ZALUD":
			player_shatter_debuff = true
			_spawn_score_popup(_tr("♣ RIVAL SHATTER: Next ×0.5!", "♣ TŘÍŠTĚNÍ: Příště ×0.5!"), Color(0.88, 0.62, 0.36), false)

func _refresh_discard_top_mesh() -> void:
	if not is_instance_valid(discard_pile_root) or discard_pile.is_empty():
		return
	var ch_cnt := discard_pile_root.get_child_count()
	for idx in range(ch_cnt - 1, -1, -1):
		var ch := discard_pile_root.get_child(idx)
		if is_instance_valid(ch) and not (ch is Area3D):
			ch.queue_free()
			break
	_add_card_mesh_to_discard_pile(discard_pile.back())

func _start_ai_3d_turn() -> void:
	_ai_turn_seq += 1
	var my_ai_seq := _ai_turn_seq
	turn_stage = TurnStage.RESOLVING
	opp_play_anim_t = 1.0
	if deferred_ai_draw > 0:
		pending_draw += deferred_ai_draw
		deferred_ai_draw = 0
	if deferred_ai_skip:
		pending_skip = true
		pending_skip_turns = maxi(1, pending_skip_turns)
		deferred_ai_skip = false
	is_player_turn = false
	_refresh_table_labels()

	if not tutorial_mode:
		_run_ai_item_review_stage(my_ai_seq)
		return
	get_tree().create_timer(_pace(0.55)).timeout.connect(func():
		_execute_ai_turn_body(my_ai_seq)
	)

func _run_ai_item_review_stage(my_ai_seq: int) -> void:
	if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
		return
	set_camera_view_mode(CameraViewMode.RIVAL_ITEMS, false)
	wager_showcase_boost = 0.75
	await get_tree().create_timer(_pace(0.45)).timeout
	if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
		return

	var want_item := opp_item_charges > 0 and (ai_hp <= 5 or (match_turn_count % 3 == 1 and ai_score < target_score))
	if want_item and is_instance_valid(opp_phial_node):
		opp_item_charges -= 1
		var op_tag := opp_phial_node.get_node_or_null("OppPhialTag") as Label3D
		if op_tag:
			op_tag.text = "IGNIS (%d×)" % opp_item_charges
		var op_bp := opp_phial_node.position.y
		var op_tw := opp_phial_node.create_tween()
		op_tw.tween_property(opp_phial_node, "position:y", op_bp + 0.12, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		op_tw.tween_property(opp_phial_node, "position:y", op_bp, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		var r_target := player_hand_anchor.global_position + Vector3(0.0, 0.12, 0.0) if is_instance_valid(player_hand_anchor) else Vector3(0.0, 1.0, 0.9)
		Fx.item_ritual_activation(self, opp_phial_node.global_position + Vector3(0.0, 0.08, 0.0), r_target, Color(1.0, 0.42, 0.16))
		emit_signal("play_sfx_pitched_requested", "puf", 1.12)
		if ai_hp < ai_max_hp:
			ai_hp = mini(ai_max_hp, ai_hp + 1)
			if is_instance_valid(rival_hp_heart):
				rival_hp_heart.call("set_hp", ai_hp, ai_max_hp, false)
				rival_hp_heart.call("trigger_heal_pulse", 1)
			Fx.float_number(self, opp_phial_node.global_position + Vector3(0.0, 0.24, 0.0), "+1 ♥ HP!", Color(0.42, 1.0, 0.56), 56, 0.20, 0.80, 1.45)
			_refresh_table_labels()
		else:
			_award_ai_score_immediately(6, _tr("EMBER VIAL (+6)", "PEKELNÁ BAŇKA (+6)"), Color(1.0, 0.46, 0.22))
		await get_tree().create_timer(_pace(0.42)).timeout
		if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
			return
	_execute_ai_turn_body(my_ai_seq)

func _execute_ai_turn_body(my_ai_seq: int) -> void:
	if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
		return
	# 1. Tick Hellfire Burn & Briar Poison on Rival!
	if rival_burn_turns > 0:
		rival_burn_turns -= 1
		var b_dmg := 10 if active_campaign_difficulty != "classic" else 8
		ai_score = maxi(0, ai_score - b_dmg)
		display_ai_score = float(ai_score)
		Fx.embers(self, opp_hands_anchor.global_position, 22, 1.1)
		Fx.float_number(self, opp_hands_anchor.global_position + Vector3(0, 0.28, 0), _tr("-%d BURN!" % b_dmg, "-%d POPÁLENÍ!" % b_dmg), Color(1.0, 0.46, 0.14), 60, 0.20, 0.80, 1.5)
		if rival_burn_turns <= 0:
			if is_instance_valid(opp_fire_fx_root):
				opp_fire_fx_root.visible = false
			if is_instance_valid(opp_fire_light):
				opp_fire_light.light_energy = 0.0
	if rival_poison_turns > 0:
		rival_poison_turns -= 1
		ai_score = maxi(0, ai_score - 8)
		display_ai_score = float(ai_score)
		Fx.float_number(self, opp_hands_anchor.global_position + Vector3(0, 0.18, 0), _tr("-8 VENOM!", "-8 JED!"), Color(0.42, 0.90, 0.45), 54, 0.18, 0.72, 1.4)

	# 2. Resolve Player's Knight Battle Mist Challenge against AI!
	if knight_mist_active and not knight_mist_from_ai:
		knight_mist_active = false
		if is_instance_valid(discard_mist_fx_root):
			discard_mist_fx_root.visible = false
		if not discard_pile.is_empty():
			discard_pile.back()["_mist_hidden"] = false
			_refresh_discard_top_mesh()
		var ai_guess_right := randf() < (0.35 if active_campaign_difficulty == "classic" else 0.25)
		if ai_guess_right:
			_spawn_score_popup(_tr("Rival pierced Knight Mist!", "Soupeř prohlédl Rytířskou mlhu!"), Color(0.75, 0.86, 0.96), false)
		else:
			ai_hand.append(_draw_from_deck())
			_award_player_score_immediately(12, _tr("Mist Ambush (+12)", "Přepad z mlhy (+12)"), Color(0.55, 0.92, 1.0))
			_spawn_score_popup(_tr("MIST AMBUSH! +12 & Rival +1!", "PŘEPAD Z MLHY! +12 a Soupeř +1!"), Color(0.55, 0.92, 1.0), false)

	if ai_stun_turns > 0:
		ai_stun_turns -= 1
		var cnt := pending_draw if pending_draw > 0 else 1
		pending_draw = 0
		pending_seven_trap_bonus = 0
		pending_skip = false
		pending_skip_turns = 0
		pending_ace_stun_bonus = 0
		var stun_drawn: Array = []
		for i in range(cnt):
			var dc := _draw_from_deck()
			ai_hand.append(dc)
			stun_drawn.append(dc)
		table_status_label3d.text = _tr("Stunned hands fumble and draw %d card(s)!" % cnt, "Omráčený soupeř líže %d karet!" % cnt)
		_animate_magical_card_draw_3d(stun_drawn, false, func():
			if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
				return
			_rebuild_all_3d_hands()
			_refresh_table_labels()
			_finish_ai_3d_turn()
		)
		return

	var play_idx := _choose_ai_play_idx()
	if play_idx != -1:
		var peek_c: Dictionary = ai_hand[play_idx]
		var peek_cls := Catalog.normalize_card_class(str(peek_c.get("edition", "NORMAL")))
		var is_cinematic_play := is_instance_valid(cinematic_director) and (str(peek_c.get("power_id", "")) != "")
		if is_cinematic_play:
			_run_rival_turn_with_cinematic(my_ai_seq)
			return
		var c: Dictionary = ai_hand[play_idx]
		var c_cls := peek_cls
		var ai_pts := _apply_ai_card_play_state(play_idx)
		var s_obj := _get_suit_obj(c["suit"])
		var s_col: Color = s_obj["col"]
		var thrown := _build_3d_card_node(c, true, Color(0.9, 0.7, 0.25))
		add_child(thrown)
		var opp_start := opp_hands_anchor.global_position
		thrown.global_position = opp_start
		var target_pos := discard_pile_root.global_position + Vector3(0, discard_pile.size() * 0.0055, 0)
		var ai_start_rot := Vector3(12.0, 180.0, 0.0)
		var ai_end_rot := Vector3(-90.0, randf_range(-16.0, 16.0), 0.0)
		var trail := Fx.attach_magical_card_trail(thrown, s_col)
		emit_signal("play_sfx_requested", "card_throw_whoosh")
		var tw := create_tween()
		var thrown_wr: WeakRef = weakref(thrown)
		tw.tween_method(func(u: float):
			var t_inst := thrown_wr.get_ref() as Node3D
			if not is_instance_valid(t_inst):
				return
			t_inst.global_position = opp_start.lerp(target_pos, u) + Vector3(0.0, sin(u * PI) * 0.22, 0.0)
			t_inst.rotation_degrees = ai_start_rot.lerp(ai_end_rot, u)
		, 0.0, 1.0, _pace(0.46)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			var t_inst := thrown_wr.get_ref() as Node3D
			var sp_p := trail.get("sparks") as CPUParticles3D
			if is_instance_valid(sp_p): sp_p.emitting = false
			var ms_p := trail.get("mist") as CPUParticles3D
			if is_instance_valid(ms_p): ms_p.emitting = false
			if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
				if is_instance_valid(t_inst):
					t_inst.queue_free()
				return
			emit_signal("play_sfx_requested", "card_slam")
			cam_kick_shake = 0.45
			Fx.card_slam_master(self, target_pos, s_col, 1.05)
			if is_instance_valid(t_inst):
				t_inst.queue_free()
			_add_card_mesh_to_discard_pile(c)
			turn_glance_timer = 1.15
			var is_rival_knight := (c_cls == "KNIGHT")
			if _should_play_weapon_card_anim(c, 1):
				var r_sword_fx := SwordCardAnim.play_sword_card_score_anim(self, c, null, false, target_pos, ai_pts, 1.0, is_rival_knight)
				_register_blender_vfx(r_sword_fx)
			if is_rival_knight and not tutorial_mode and not _check_win_or_redeal():
				table_status_label3d.text = _tr("RIVAL KNIGHT! Memorize: %s %s before MIST rolls in!", "RYTÍŘ SOUPEŘE! Zapamatuj si: %s %s před MLHOU!") % [s_obj["sym"], _get_rank_name(str(c.get("rank", "")))]
				_rebuild_all_3d_hands()
				get_tree().create_timer(_pace(1.45)).timeout.connect(func():
					if my_ai_seq == _ai_turn_seq and is_inside_tree() and visible and not tutorial_mode:
						_open_mist_guess_modal(c)
				)
				return
			_rebuild_all_3d_hands()
			get_tree().create_timer(_pace(1.35)).timeout.connect(func():
				if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
					return
				var r_disp := _get_rank_name(str(c.get("rank", "")))
				if cards_points_revealed:
					table_status_label3d.text = _tr("Rival played: %s %s (+%s pts)", "Soupeř zahrál: %s %s (+%s b.)") % [s_obj["sym"], r_disp, _format_pts_ui(ai_pts)]
				else:
					table_status_label3d.text = _tr("Rival played: %s %s", "Soupeř zahrál: %s %s") % [s_obj["sym"], r_disp]
				_finish_ai_3d_turn()
			)
			return
			var r_disp2 := _get_rank_name(str(c.get("rank", "")))
			if cards_points_revealed:
				table_status_label3d.text = _tr("Rival played: %s %s (+%s pts)", "Soupeř zahrál: %s %s (+%s b.)") % [s_obj["sym"], r_disp2, _format_pts_ui(ai_pts)]
			else:
				table_status_label3d.text = _tr("Rival played: %s %s", "Soupeř zahrál: %s %s") % [s_obj["sym"], r_disp2]
			_rebuild_all_3d_hands()
			_refresh_table_labels()
			get_tree().create_timer(_pace(0.32)).timeout.connect(func():
				if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
					return
				_finish_ai_3d_turn()
			)
		)
	else:
		var ai_drawn := _apply_ai_draw_or_skip_state()
		if ai_drawn.is_empty():
			_rebuild_all_3d_hands()
			_refresh_table_labels()
			_finish_ai_3d_turn()
		else:
			_animate_magical_card_draw_3d(ai_drawn, false, func():
				if my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
					return
				_rebuild_all_3d_hands()
				_refresh_table_labels()
				_finish_ai_3d_turn()
			)

func _choose_ai_play_idx() -> int:
	var play_idx := -1
	if not pending_king_challenge.is_empty() and not bool(pending_king_challenge.get("from_ai", false)) and pending_draw == 0 and not pending_skip:
		var king_idx := -1
		for i in range(ai_hand.size()):
			var ac: Dictionary = ai_hand[i]
			if str(ac.get("rank", "")) == "K" and Catalog.normalize_card_class(str(ac.get("edition", "NORMAL"))) != "MERCHANT" and _can_play(ac):
				king_idx = i
				break
		if king_idx != -1:
			play_idx = king_idx
		else:
			_apply_king_curse_to_ai(str(pending_king_challenge.get("suit", "CERVEN")))
			pending_king_challenge.clear()

	if play_idx == -1:
		if tutorial_mode and tutorial_step == 3:
			play_idx = -1
		elif tutorial_mode and tutorial_step <= 6:
			for i in range(ai_hand.size()):
				var ac: Dictionary = ai_hand[i]
				var ar: String = str(ac["rank"])
				if _can_play(ac) and ar != "7" and ar != "E" and ar != "H":
					play_idx = i
					break
		else:
			var mercy := (active_campaign_difficulty != "classic") and (float(ai_score) >= float(target_score) * 0.72) and (float(player_score) < float(target_score) * 0.45)
			if mercy:
				var best_mild := -1
				for i in range(ai_hand.size()):
					var ac: Dictionary = ai_hand[i]
					if _can_play(ac) and not (str(ac.get("rank", "")) in ["7", "E"]):
						best_mild = i
						break
				play_idx = best_mild
			if play_idx == -1:
				for i in range(ai_hand.size()):
					if _can_play(ai_hand[i]):
						play_idx = i
						break
	return play_idx

func _apply_ai_card_play_state(play_idx: int) -> int:
	var c: Dictionary = ai_hand[play_idx]
	var c_cls := Catalog.normalize_card_class(str(c.get("edition", "NORMAL")))
	var is_merch := (c_cls == "MERCHANT")
	ai_hand.remove_at(play_idx)
	discard_pile.append(c)
	active_suit_id = c["suit"] if (c["rank"] != "H" or is_merch or ai_hand.is_empty()) else ai_hand[0]["suit"]
	var ai_ctx := {
		"tutorial_mode": tutorial_mode,
		"tutorial_step": tutorial_step,
		"chosen_suit": active_suit_id,
		"prev_suit": active_suit_id,
		"is_preview": false,
		"lang": opts_language,
	}
	var ai_res := ScoreEng.calculate_hand_score([c], [], ai_hand, ai_ctx)
	var ai_pts := int(ai_res.get("final_score", int(c.get("pts", 8))))
	if rival_burn_turns > 0:
		ai_pts = maxi(1, int(round(float(ai_pts) * 0.75)))
	if rival_shatter_debuff:
		rival_shatter_debuff = false
		ai_pts = maxi(1, int(ceil(float(ai_pts) * 0.5)))
	if rival_tax_debuff:
		rival_tax_debuff = false
		ai_pts = maxi(1, int(round(float(ai_pts) * 0.7)))
	if not tutorial_mode or cards_points_revealed:
		if not tutorial_mode and active_boss_mod == "CROWN_DECREE" and player_shields <= 0 and str(c["rank"]) in ["D", "H", "K", "E"]:
			var crown_add := 6 if active_campaign_difficulty == "classic" else 4
			ai_pts += crown_add
			_trigger_boss_modifier_flare(_tr("Crown Decree: +%d Rival pts!" % crown_add, "Královský dekret: +%d b. soupeři!" % crown_add))
		_award_ai_score_immediately(ai_pts, "+%d %s" % [ai_pts, _tr("RIVAL", "SOUPEŘ")], Color(1.0, 0.44, 0.38))
		if combat_log_drawer != null:
			combat_log_drawer.add_entry(_tr("◀ RIVAL: %s (+%d pts)", "◀ SOUPEŘ: %s (+%d b.)") % [str(c.get("rname", "Card")), ai_pts], Color(1.0, 0.54, 0.46))
	var shielded_hit := false
	if not tutorial_mode and player_shields > 0 and (c["rank"] in ["7", "E"] or ai_pts >= 15):
		player_shields -= 1
		shielded_hit = true
		var reflect_dmg := maxi(4, int(round(float(ai_pts) * 0.5)))
		ai_score = maxi(0, ai_score - reflect_dmg)
		display_ai_score = float(ai_score)
		_spawn_score_popup(_tr("SHIELD REFLECTED -%d!" % reflect_dmg, "ŠTÍT ODRAZIL -%d!" % reflect_dmg), Color(0.45, 0.94, 1.0), true)
		_refresh_table_labels()
	if not shielded_hit and not is_merch:
		if c["rank"] == "7":
			pending_seven_trap_bonus = 0
			if pending_seven_banner_pill:
				pending_seven_banner_pill.visible = false
			var don_pen := 4 if active_campaign_difficulty == "classic" else 3
			pending_draw += (don_pen if (not tutorial_mode and active_boss_mod == "DON_RACKETEER") else 2)
			pending_ai_seven_trap_bonus += 10
			if not tutorial_mode and active_boss_mod == "DON_RACKETEER":
				_trigger_boss_modifier_flare(_tr("Don Racketeer: +%d Draw Penalty!" % don_pen, "Vyděrač: +%d karet navíc!" % don_pen))
		elif c["rank"] == "E":
			pending_skip = true
			pending_skip_turns = mini(2, pending_skip_turns + 1)
			if not tutorial_mode or tutorial_step >= 3:
				_apply_hp_damage(true, 1, _tr("Rival Ace Strike!", "Soupeřovo Eso!"))
		elif c["rank"] == "K":
			if not pending_king_challenge.is_empty() and not bool(pending_king_challenge.get("from_ai", false)):
				_spawn_score_popup(_tr("RIVAL COUNTERED KING!", "SOUPEŘ ODRAZIL KRÁLE!"), Color(1.0, 0.58, 0.32), false)
			pending_king_challenge = {"suit": str(c.get("suit", "CERVEN")), "from_ai": true}
		if not tutorial_mode and active_boss_mod == "PLUNDER" and (c["rank"] == "7" or c["rank"] == "E"):
			var p_amt := 8 if active_campaign_difficulty == "classic" else 4
			player_score = maxi(0, player_score - p_amt)
			_award_ai_score_immediately(p_amt, _tr("PLUNDERED +%d" % p_amt, "ULOUPEŽENO +%d" % p_amt), Color(1.0, 0.35, 0.35))
			_trigger_boss_modifier_flare(_tr("Plunder: -%d pts stolen!" % p_amt, "Loupež: -%d b. ukradeno!" % p_amt))
			_spawn_score_popup(_tr("PLUNDERED -%d!" % p_amt, "ULOUPEŽENO -%d!" % p_amt), Color(1.0, 0.35, 0.35), false)
		if not tutorial_mode and c_cls == "THIEF" and player_hand.size() >= 2:
			var stealables: Array[int] = []
			for pi in range(player_hand.size()):
				var pcls := Catalog.normalize_card_class(str(player_hand[pi].get("edition", "NORMAL")))
				if pcls != "MAGE":
					if pcls == "MERCHANT" or randf() < 0.35:
						stealables.append(pi)
			if stealables.size() >= 1 and randf() < (0.55 if active_campaign_difficulty == "classic" else 0.30):
				var s_idx := stealables[randi() % stealables.size()]
				var stolen_c: Dictionary = player_hand[s_idx]
				player_hand.remove_at(s_idx)
				ai_hand.append(stolen_c)
				player_hand.append(_draw_from_deck())
				_spawn_score_popup(_tr("RIVAL THIEF STOLE A CARD! (+1 Draw)", "SOUPEŘŮV ZLODĚJ UKRADL KARTU! (+1 Líz.)"), Color(1.0, 0.42, 0.36), false)
	return ai_pts

func _apply_ai_draw_or_skip_state() -> Array:
	var drawn: Array = []
	if pending_skip:
		emit_signal("play_sfx_requested", "card_draw")
		pending_skip_turns = maxi(0, pending_skip_turns - 1)
		pending_skip = (pending_skip_turns > 0)
		if pending_ace_stun_bonus > 0:
			_award_player_score_immediately(pending_ace_stun_bonus, _tr("Ace Lockdown (+%d)" % pending_ace_stun_bonus, "Omráčení Esem (+%d)" % pending_ace_stun_bonus), Color(0.42, 0.94, 1.0))
			pending_ace_stun_bonus = 0
		table_status_label3d.text = _tr("Rival frozen by your Ace!", "Soupeř zmražen tvým Esem!")
	elif pending_draw > 0:
		var cnt := pending_draw
		pending_draw = 0
		for i in range(cnt):
			var dc := _draw_from_deck()
			ai_hand.append(dc)
			drawn.append(dc)
		if pending_seven_trap_bonus > 0:
			var bonus_7 := pending_seven_trap_bonus
			pending_seven_trap_bonus = 0
			_award_player_score_immediately(bonus_7, _tr("Seven Trap (+%d)" % bonus_7, "Past Sedma (+%d)" % bonus_7), Color(1.0, 0.86, 0.24), 7 + bonus_7, _tr("7 Seven Trap (+%d pts)" % (7 + bonus_7), "7 Past Sedma (+%d b.)" % (7 + bonus_7)))
			if pending_seven_banner_pill and pending_seven_banner_lbl:
				pending_seven_banner_lbl.text = _tr("7 TRAP BONUS: +%d PTS! (Rival Drew +%d!)" % [bonus_7, cnt], "PAST SEDMA: +%d BODŮ! (Soupeř lízal +%d!)" % [bonus_7, cnt])
				pending_seven_banner_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.62))
				pending_seven_banner_pill.visible = true
				var p7_tw := pending_seven_banner_pill.create_tween()
				p7_tw.tween_interval(1.45)
				p7_tw.tween_callback(func():
					if pending_seven_banner_pill and pending_seven_trap_bonus <= 0:
						pending_seven_banner_pill.visible = false
				)
		if not tutorial_mode and "REL_HEX_DOLL" in run_active_relics:
			var hex_pts := 6 * cnt
			_award_player_score_immediately(hex_pts, _tr("Hex Doll (+%d)" % hex_pts, "Prokletá panenka (+%d)" % hex_pts), Color(0.86, 0.44, 1.0))
			_pulse_relic_trigger("REL_HEX_DOLL", "+%d!" % hex_pts, false)
		table_status_label3d.text = _tr("Rival forced to draw +%d cards!" % cnt, "Soupeř musel lízat +%d karty!" % cnt)
	else:
		var dc_one := _draw_from_deck()
		ai_hand.append(dc_one)
		drawn.append(dc_one)
		table_status_label3d.text = _tr("Rival drew a card from deck.", "Soupeř si lízl kartu z balíčku.")
	return drawn

func _run_rival_turn_with_cinematic(my_ai_seq: int) -> void:
	var action_kind := "draw"
	var play_idx := -1
	var play_label := ""
	if ai_stun_turns > 0:
		action_kind = "stun"
		var stun_cnt := pending_draw if pending_draw > 0 else 1
		play_label = _tr("STUNNED • DRAWS +%d" % stun_cnt, "OMRÁČEN • LÍŽE +%d" % stun_cnt)
	else:
		play_idx = _choose_ai_play_idx()
		if play_idx != -1 and play_idx < ai_hand.size():
			action_kind = "play"
			var peek_c: Dictionary = ai_hand[play_idx]
			var ps_obj := _get_suit_obj(str(peek_c.get("suit", "CERVEN")))
			play_label = "%s %s" % [ps_obj["sym"], _get_rank_name(str(peek_c.get("rank", "")))]
		elif pending_skip:
			play_label = _tr("FROZEN BY ACE", "ZMRAZEN ESEM")
		elif pending_draw > 0:
			play_label = _tr("FORCED DRAW +%d" % pending_draw, "TRESTNÉ LÍZÁNÍ +%d" % pending_draw)
		else:
			play_label = _tr("DRAWS FROM DECK", "LÍŽE Z BALÍČKU")

	_cinematic_seq_token += 1
	var my_cine_tok := _cinematic_seq_token
	_enter_cinematic_camera_lock()
	var era_id := str(active_era.get("id", "stredovek"))
	var is_boss := (_get_opponent_visual_tier() >= 2)
	var card_world := discard_pile_root.global_position + Vector3(0.0, float(mini(discard_pile.size() + 1, 12)) * 0.0055, 0.0)
	var rival_world := opp_silhouette_root.global_position + Vector3(0.0, 0.42, 0.0) if is_instance_valid(opp_silhouette_root) else to_global(Vector3(0.0, 1.28, -1.50))
	var impact_done := false
	var rival_knight_card: Dictionary = {}

	var on_rival_impact := func():
		if impact_done or my_cine_tok != _cinematic_seq_token or my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
			return
		impact_done = true
		if action_kind == "stun":
			ai_stun_turns = maxi(0, ai_stun_turns - 1)
			var cnt := pending_draw if pending_draw > 0 else 1
			pending_draw = 0
			pending_seven_trap_bonus = 0
			pending_skip = false
			pending_skip_turns = 0
			pending_ace_stun_bonus = 0
			for i in range(cnt):
				ai_hand.append(_draw_from_deck())
			emit_signal("play_sfx_requested", "card_deal")
			table_status_label3d.text = _tr("Stunned hands fumble and draw %d card(s)!" % cnt, "Omráčený soupeř líže %d karet!" % cnt)
		elif action_kind == "play" and play_idx >= 0 and play_idx < ai_hand.size():
			var c: Dictionary = ai_hand[play_idx]
			var c_cls := Catalog.normalize_card_class(str(c.get("edition", "NORMAL")))
			var ai_pts := _apply_ai_card_play_state(play_idx)
			emit_signal("play_sfx_requested", "card_slam")
			_spawn_card_impact_dust(card_world)
			_spawn_suit_discard_rune_ring_3d(card_world, str(c.get("suit", "CERVEN")))
			_add_card_mesh_to_discard_pile(c)
			var s_obj := _get_suit_obj(c["suit"])
			_spawn_impact_shockwave(card_world, s_obj["col"], 2.3)
			var is_rival_knight := (c_cls == "KNIGHT")
			if _should_play_weapon_card_anim(c, 1):
				var r_sword_fx := SwordCardAnim.play_sword_card_score_anim(self, c, null, false, card_world, ai_pts, 1.0, is_rival_knight)
				_register_blender_vfx(r_sword_fx)
			var r_disp := _get_rank_name(str(c.get("rank", "")))
			if is_rival_knight:
				rival_knight_card = c
				table_status_label3d.text = _tr("RIVAL KNIGHT! Memorize: %s %s before MIST rolls in!", "RYTÍŘ SOUPEŘE! Zapamatuj si: %s %s před MLHOU!") % [s_obj["sym"], r_disp]
			elif cards_points_revealed:
				table_status_label3d.text = _tr("Rival played: %s %s (+%s pts)", "Soupeř zahrál: %s %s (+%s b.)") % [s_obj["sym"], r_disp, _format_pts_ui(ai_pts)]
			else:
				table_status_label3d.text = _tr("Rival played: %s %s", "Soupeř zahrál: %s %s") % [s_obj["sym"], r_disp]
		else:
			var _drawn_c := _apply_ai_draw_or_skip_state()
			if not _drawn_c.is_empty() and is_instance_valid(draw_deck_root):
				Fx.magical_draw_launch(self, draw_deck_root.global_position + Vector3(0.0, 0.08, 0.0), Color(0.96, 0.42, 0.34))
		_rebuild_all_3d_hands()
		_refresh_table_labels()

	var on_rival_finished := func():
		if my_cine_tok != _cinematic_seq_token or my_ai_seq != _ai_turn_seq or not is_inside_tree() or not visible:
			return
		_exit_cinematic_camera_lock(CameraViewMode.CARDS)
		if action_kind == "play":
			turn_glance_timer = 1.15
		if not rival_knight_card.is_empty():
			if not _check_win_or_redeal():
				_open_mist_guess_modal(rival_knight_card)
			return
		_finish_ai_3d_turn()

	cinematic_director.call(
		"play_rival_turn_cinematic",
		era_id,
		is_boss,
		play_label,
		card_world,
		rival_world,
		opts_language == "cs",
		on_rival_impact,
		on_rival_finished
	)

func _finish_ai_3d_turn() -> void:
	_score_resolve_token += 1
	var my_resolve_tok := _score_resolve_token
	if not tutorial_mode:
		rival_cards_revealed_turns = maxi(0, rival_cards_revealed_turns - 1)
		match_turn_count += 1
		_advance_mage_charges(1, false)
		if player_poison_turns > 0:
			player_poison_turns -= 1
			if player_shields > 0:
				player_shields -= 1
				_spawn_score_popup(_tr("SHIELD BLOCKED VENOM!", "ŠTÍT ZABLOKOVAL JED!"), Color(0.45, 0.94, 1.0), true)
			else:
				player_score = maxi(0, player_score - 8)
				_spawn_score_popup(_tr("-8 VENOM TICK", "-8 JED"), Color(0.55, 0.90, 0.45), true)
		if (active_boss_mod == "SHIFTING_WINDS" and match_turn_count % 3 == 0) or (shifting_winds_active and boss_phase >= 2 and match_turn_count % 2 == 0):
			active_suit_id = str(SUITS[randi() % SUITS.size()]["id"])
			_trigger_boss_modifier_flare(_tr("Shifting Winds!", "Proměnlivé větry!"))
			_spawn_score_popup(_tr("WINDS SHIFT SUIT!", "VÍTR MĚNÍ BARVU!"), Color(0.45, 0.88, 1.0), true)
		if sealed_suit_turns > 0:
			sealed_suit_turns -= 1
			if sealed_suit_turns <= 0:
				sealed_suit_id = ""
	_flush_pending_exchange_scores_immediately()
	_rebuild_all_3d_hands()
	_refresh_table_labels()
	await get_tree().create_timer(_pace(0.18)).timeout
	if my_resolve_tok != _score_resolve_token or not is_inside_tree() or not visible:
		return
	if _check_win_or_redeal():
		return
	busy_animating = false
	is_player_turn = true
	relic_mgr.reset_turn()
	if tutorial_mode:
		if tutorial_step <= 6:
			pending_draw = 0
			pending_skip = false
			pending_skip_turns = 0
		if tutorial_step == 2 and (_tutorial_action_done == "played_card" or _tutorial_action_done == "played_seven" or _tutorial_action_done == "played_special" or _tutorial_action_done == "slammed_combo"):
			_trigger_ghost_ok_flash()
			_advance_tutorial_to(3)
			return
		elif tutorial_step == 3 and _tutorial_action_done == "played_seven":
			_trigger_ghost_ok_flash()
			_advance_tutorial_to(4)
			return
		elif tutorial_step == 4 and _tutorial_action_done == "slammed_combo":
			_trigger_ghost_ok_flash()
			_advance_tutorial_to(5)
			return
		elif tutorial_step == 5 and _tutorial_action_done == "slammed_combo":
			_trigger_ghost_ok_flash()
			_advance_tutorial_to(6)
			return
		elif tutorial_step == 6 and tutorial_substep == 0 and _tutorial_action_done == "played_special":
			tutorial_substep = 1
			_tutorial_action_done = ""
			_trigger_ghost_ok_flash()
			_update_tutorial_callout_ui(6, true)
			emit_signal("play_sfx_requested", "turn_player")
			_rebuild_all_3d_hands()
			_refresh_table_labels()
			return
	emit_signal("play_sfx_requested", "turn_player")
	_rebuild_all_3d_hands()
	_refresh_table_labels()
	turn_stage = TurnStage.CARD_PLAY
	set_camera_view_mode(CameraViewMode.CARDS, true)

func _build_shop_gate_overlay() -> void:
	shop_gate_overlay = Control.new()
	shop_gate_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_gate_overlay.visible = false
	shop_gate_overlay.z_index = 40
	shop_gate_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(shop_gate_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.025, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_gate_overlay.add_child(bg)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -340
	box.offset_top = -150
	box.offset_right = 340
	box.offset_bottom = 150
	var b_sb := _make_plaque_style(Color(0.06, 0.045, 0.04, 0.96), Color(0.92, 0.72, 0.28), 28)
	b_sb.set_border_width_all(3)
	b_sb.content_margin_left = 28; b_sb.content_margin_right = 28
	b_sb.content_margin_top = 24; b_sb.content_margin_bottom = 24
	box.add_theme_stylebox_override("panel", b_sb)
	shop_gate_overlay.add_child(box)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	box.add_child(vb)

	var art_tr := TextureRect.new()
	var bell_p := "res://assets/shop/bell.png"
	if ResourceLoader.exists(bell_p):
		art_tr.texture = load(bell_p)
	art_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_tr.custom_minimum_size = Vector2(92, 92)
	art_tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(art_tr)

	shop_gate_title = Label.new()
	shop_gate_title.text = "ENTER THE CROSSROADS SHOP?"
	shop_gate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_gate_title.add_theme_font_override("font", _get_font(true))
	shop_gate_title.add_theme_font_size_override("font_size", 26)
	shop_gate_title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.38))
	vb.add_child(shop_gate_title)

	# Subtitle hidden permanently per user request (clean YES / NO gate!)
	shop_gate_sub = Label.new()
	shop_gate_sub.visible = false
	vb.add_child(shop_gate_sub)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vb.add_child(btn_row)

	shop_gate_yes_btn = Button.new()
	shop_gate_yes_btn.text = "YES — ENTER SHOP"
	shop_gate_yes_btn.custom_minimum_size = Vector2(240, 52)
	shop_gate_yes_btn.add_theme_font_override("font", _get_font(true))
	shop_gate_yes_btn.add_theme_font_size_override("font_size", 17)
	shop_gate_yes_btn.add_theme_color_override("font_color", Color(0.92, 1.0, 0.90))
	_style_action_button(shop_gate_yes_btn, Color(0.12, 0.28, 0.16, 0.96), Color(0.42, 0.92, 0.56), 22)
	shop_gate_yes_btn.pressed.connect(func(): _close_shop_gate_prompt(true))
	btn_row.add_child(shop_gate_yes_btn)

	shop_gate_no_btn = Button.new()
	shop_gate_no_btn.text = "NO — CONTINUE"
	shop_gate_no_btn.custom_minimum_size = Vector2(220, 52)
	shop_gate_no_btn.add_theme_font_override("font", _get_font(true))
	shop_gate_no_btn.add_theme_font_size_override("font_size", 17)
	shop_gate_no_btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.82))
	_style_action_button(shop_gate_no_btn, Color(0.28, 0.10, 0.10, 0.96), Color(0.88, 0.42, 0.36), 22)
	shop_gate_no_btn.pressed.connect(func(): _close_shop_gate_prompt(false))
	btn_row.add_child(shop_gate_no_btn)

func _open_shop_gate_prompt() -> void:
	if not shop_gate_overlay:
		_open_peddler_modal()
		return
	shop_gate_open = true
	auto_edge_peek = false
	if shop_gate_title:
		shop_gate_title.text = _tr("ENTER THE CROSSROADS SHOP?", "OTEVŘÍT KUPECKÝ OBCHOD?")
	if shop_gate_sub:
		shop_gate_sub.visible = false
	if shop_gate_yes_btn:
		shop_gate_yes_btn.text = _tr("YES — ENTER SHOP", "ANO — VSTOUPIT")
	if shop_gate_no_btn:
		shop_gate_no_btn.text = _tr("NO — CONTINUE", "NE — POKRAČOVAT")
	shop_gate_overlay.visible = true
	shop_gate_overlay.modulate.a = 0.0
	if is_instance_valid(_shop_gate_tween):
		_shop_gate_tween.kill()
	_shop_gate_tween = shop_gate_overlay.create_tween()
	_shop_gate_tween.tween_property(shop_gate_overlay, "modulate:a", 1.0, 0.22)
	emit_signal("play_sfx_requested", "prop_coins")

func _close_shop_gate_prompt(enter_shop: bool) -> void:
	shop_gate_open = false
	if is_instance_valid(_shop_gate_tween):
		_shop_gate_tween.kill()
		_shop_gate_tween = null
	if shop_gate_overlay:
		shop_gate_overlay.modulate.a = 1.0
		shop_gate_overlay.visible = false
	if enter_shop:
		_open_peddler_modal()
	else:
		_save_shop_checkpoint()
		_trigger_turn_table_bet_glance(false)

func _build_3d_medieval_item_mesh(emblem: String, col: Color) -> Node3D:
	return RelicMesh.build_medieval_shop_item_3d(emblem, col)

func _build_3d_shop_item_viewport(emblem: String, col: Color) -> SubViewportContainer:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(142, 142)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_PASS

	var svp := SubViewport.new()
	svp.size = Vector2i(142, 142)
	svp.transparent_bg = true
	svp.own_world_3d = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(svp)

	var w_root := Node3D.new()
	svp.add_child(w_root)

	var v_cam := Camera3D.new()
	v_cam.position = Vector3(0.0, 0.16, 0.38)
	v_cam.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	v_cam.fov = 45.0
	w_root.add_child(v_cam)

	var d_light := DirectionalLight3D.new()
	d_light.rotation_degrees = Vector3(-38.0, 32.0, 0.0)
	d_light.light_energy = 2.2
	d_light.light_color = Color(1.0, 0.94, 0.80)
	w_root.add_child(d_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-0.22, 0.26, -0.18)
	rim_light.light_energy = 1.8
	rim_light.light_color = col.lightened(0.3)
	w_root.add_child(rim_light)

	var item_3d: Node3D
	if emblem.begins_with("TRELIC_"):
		item_3d = RelicMesh.build_relic_3d_mesh(emblem, col)
		item_3d.scale = Vector3(1.55, 1.55, 1.55)
		item_3d.position = Vector3(0.0, 0.03, 0.0)
	else:
		item_3d = _build_3d_medieval_item_mesh(emblem, col)
	item_3d.rotation_degrees = Vector3(8.0, 24.0, 0.0)
	w_root.add_child(item_3d)
	peddler_3d_roots.append(item_3d)

	svc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion and is_instance_valid(item_3d):
			item_3d.rotation_degrees.y += ev.relative.x * 1.45
			item_3d.rotation_degrees.x = clampf(item_3d.rotation_degrees.x + ev.relative.y * 0.65, -28.0, 34.0)
	)
	return svc

func _spawn_purchased_table_item_3d(offer: Dictionary) -> void:
	if not is_instance_valid(purchased_table_items_root):
		return
	var em_id := str(offer.get("emblem", "bell"))
	var col: Color = offer.get("col", Color(0.95, 0.82, 0.34))
	var idx_slot := purchased_table_item_nodes.size()
	var slots: Array[Vector3] = [
		Vector3(0.36, 0.816, 0.54),
		Vector3(0.56, 0.816, 0.47),
		Vector3(0.75, 0.816, 0.35),
		Vector3(0.78, 0.816, -0.14),
		Vector3(0.18, 0.816, 0.62),
		Vector3(0.78, 0.816, -0.34),
	]
	var pos_3d: Vector3 = slots[idx_slot % slots.size()]
	var item_node := _build_3d_medieval_item_mesh(em_id, col)
	item_node.position = pos_3d
	item_node.scale = Vector3(0.05, 0.05, 0.05)
	var pid := "shop_item_%d" % idx_slot
	item_node.set_meta("prop_id", pid)
	item_node.set_meta("base_pos", pos_3d)
	item_node.set_meta("base_scale", Vector3(0.82, 0.82, 0.82))
	item_node.set_meta("item_col", col)
	item_node.set_meta("emblem", em_id)
	item_node.set_meta("active_charges", 1)
	item_node.set_meta("hover_title", _tr(str(offer.get("name", "Artifact")), str(offer.get("name_cs", offer.get("name", "Artefakt")))))
	item_node.set_meta("hover_desc", _tr(str(offer.get("desc", "")), str(offer.get("desc_cs", offer.get("desc", "")))))

	var area := Area3D.new()
	area.name = "PurchasedShopItemArea_%d" % idx_slot
	area.set_meta("prop_id", pid)
	var cshape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.24, 0.28, 0.24)
	cshape.shape = box
	cshape.position = Vector3(0.0, 0.12, 0.0)
	area.add_child(cshape)
	item_node.add_child(area)

	purchased_table_items_root.add_child(item_node)
	purchased_table_item_nodes.append(item_node)
	var tw := item_node.create_tween()
	tw.tween_property(item_node, "scale", Vector3(0.82, 0.82, 0.82), 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_peddler_modal() -> void:
	peddler_modal = PanelContainer.new()
	peddler_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	peddler_modal.offset_left = 0
	peddler_modal.offset_top = 0
	peddler_modal.offset_right = 0
	peddler_modal.offset_bottom = 0
	peddler_modal.z_index = 40
	peddler_modal.visible = false
	var pm_sb := StyleBoxFlat.new()
	pm_sb.bg_color = Color(0.032, 0.025, 0.022, 0.98)
	pm_sb.border_color = Color(0.84, 0.64, 0.24, 0.96)
	pm_sb.set_border_width_all(3)
	pm_sb.content_margin_left = 44
	pm_sb.content_margin_right = 44
	pm_sb.content_margin_top = 24
	pm_sb.content_margin_bottom = 24
	peddler_modal.add_theme_stylebox_override("panel", pm_sb)
	hud_root.add_child(peddler_modal)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	peddler_modal.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 14)
	vb.add_child(hdr)

	peddler_title_lbl = Label.new()
	peddler_title_lbl.text = _tr("☾ CROSSROADS SHOP — 3D ARTIFACTS ☽", "☾ KUPECKÝ OBCHOD — 3D ARTEFAKTY ☽")
	peddler_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	peddler_title_lbl.add_theme_font_override("font", _get_font(true))
	peddler_title_lbl.add_theme_font_size_override("font_size", 26)
	peddler_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.40))
	hdr.add_child(peddler_title_lbl)

	peddler_gold_lbl = Label.new()
	peddler_gold_lbl.text = "100"
	peddler_gold_lbl.add_theme_font_override("font", _get_font(true))
	peddler_gold_lbl.add_theme_font_size_override("font_size", 24)
	peddler_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
	hdr.add_child(peddler_gold_lbl)

	# 2D Animated Ghost Shopkeeper Banner explaining each 3D item!
	var ghost_bar := PanelContainer.new()
	var gb_sb := _make_plaque_style(Color(0.05, 0.07, 0.11, 0.94), Color(0.45, 0.88, 0.96, 0.88), 22)
	gb_sb.content_margin_left = 16; gb_sb.content_margin_right = 18
	gb_sb.content_margin_top = 8; gb_sb.content_margin_bottom = 8
	ghost_bar.add_theme_stylebox_override("panel", gb_sb)
	vb.add_child(ghost_bar)

	var gh_hb := HBoxContainer.new()
	gh_hb.add_theme_constant_override("separation", 14)
	ghost_bar.add_child(gh_hb)

	peddler_ghost_ctrl = Control.new()
	peddler_ghost_ctrl.custom_minimum_size = Vector2(64, 64)
	peddler_ghost_ctrl.draw.connect(func():
		var gc := peddler_ghost_ctrl.size * 0.5
		var gt := float(Time.get_ticks_msec()) * 0.001
		var bob := sin(gt * 3.6) * 3.5
		peddler_ghost_ctrl.draw_circle(gc + Vector2(0, bob), 28.0, Color(0.32, 0.86, 0.98, 0.22))
		var g_poly := PackedVector2Array([
			gc + Vector2(-18, -6 + bob),
			gc + Vector2(-13, -22 + bob),
			gc + Vector2(0, -27 + bob),
			gc + Vector2(13, -22 + bob),
			gc + Vector2(18, -6 + bob),
			gc + Vector2(20, 18 + bob + sin(gt * 5.0) * 3.0),
			gc + Vector2(8, 12 + bob),
			gc + Vector2(0, 21 + bob + cos(gt * 5.0) * 3.0),
			gc + Vector2(-8, 12 + bob),
			gc + Vector2(-20, 18 + bob - sin(gt * 5.0) * 3.0),
		])
		peddler_ghost_ctrl.draw_colored_polygon(g_poly, Color(0.76, 0.96, 1.0, 0.94))
		peddler_ghost_ctrl.draw_circle(gc + Vector2(-6, -8 + bob), 3.4, Color(0.05, 0.08, 0.14))
		peddler_ghost_ctrl.draw_circle(gc + Vector2(6, -8 + bob), 3.4, Color(0.05, 0.08, 0.14))
		peddler_ghost_ctrl.draw_circle(gc + Vector2(-6, -8 + bob), 1.6, Color(1.0, 0.92, 0.42))
		peddler_ghost_ctrl.draw_circle(gc + Vector2(6, -8 + bob), 1.6, Color(1.0, 0.92, 0.42))
	)
	gh_hb.add_child(peddler_ghost_ctrl)

	peddler_ghost_lbl = Label.new()
	peddler_ghost_lbl.text = _tr("Spirko: \"Checkpoint saved! Hover 3D items to inspect them.\"", "Spirko: \"Checkpoint uložen! Najeď na předmět pro detail.\"")
	peddler_ghost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	peddler_ghost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	peddler_ghost_lbl.add_theme_font_override("font", _get_font(false))
	peddler_ghost_lbl.add_theme_font_size_override("font_size", 18)
	peddler_ghost_lbl.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	gh_hb.add_child(peddler_ghost_lbl)

	peddler_sub_lbl = Label.new()
	peddler_sub_lbl.visible = false
	vb.add_child(peddler_sub_lbl)

	peddler_cards_hbox = HBoxContainer.new()
	peddler_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	peddler_cards_hbox.add_theme_constant_override("separation", 22)
	vb.add_child(peddler_cards_hbox)

	var ftr := HBoxContainer.new()
	ftr.alignment = BoxContainer.ALIGNMENT_END
	ftr.add_theme_constant_override("separation", 16)
	vb.add_child(ftr)

	peddler_reroll_btn = Button.new()
	peddler_reroll_btn.text = _tr("New Wares (10g)", "Nové zboží (10g)")
	peddler_reroll_btn.custom_minimum_size = Vector2(235, 48)
	peddler_reroll_btn.add_theme_font_override("font", _get_font(true))
	peddler_reroll_btn.add_theme_font_size_override("font_size", 17)
	peddler_reroll_btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	_style_action_button(peddler_reroll_btn, Color(0.14, 0.11, 0.08, 0.95), Color(0.76, 0.58, 0.26), 20)
	peddler_reroll_btn.pressed.connect(_reroll_peddler_offers)
	ftr.add_child(peddler_reroll_btn)

	var close_btn := Button.new()
	close_btn.text = _tr("Return to Duel ›", "Zpět do duelu ›")
	close_btn.custom_minimum_size = Vector2(220, 48)
	close_btn.add_theme_font_override("font", _get_font(true))
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.74))
	_style_action_button(close_btn, Color(0.28, 0.19, 0.07, 0.98), Color(1.0, 0.82, 0.30), 20)
	close_btn.pressed.connect(_close_peddler_shop)
	ftr.add_child(close_btn)
	peddler_close_btn = close_btn

func _draw_medieval_item_emblem(ctrl: Control, emblem: String, col: Color) -> void:
	var c := ctrl.size * 0.5
	var r := minf(ctrl.size.x, ctrl.size.y) * 0.42
	ctrl.draw_circle(c, r + 3.0, Color(0.06, 0.04, 0.03, 0.90))
	ctrl.draw_arc(c, r, 0.0, TAU, 32, col * 0.85, 2.2)

func _open_peddler_modal() -> void:
	if not peddler_modal:
		return
	peddler_open = true
	player_available_gold += 15
	duel_gold_delta += 15
	_save_shop_checkpoint()
	peddler_offers = Catalog.roll_medieval_peddler_offers(3, run_table_relics)
	if peddler_title_lbl:
		peddler_title_lbl.text = _tr("☾ ROUND %d CROSSROADS SHOP ☽" % current_round_num, "☾ OBCHOD PO %d. KOLE ☽" % current_round_num)
	if peddler_ghost_lbl:
		_start_handwriting_anim(peddler_ghost_lbl, _tr("Spirko: \"Checkpoint saved (+15g)! Hover items to inspect & buy.\"", "Spirko: \"Checkpoint uložen (+15g)! Najeď na předmět a vyber si.\""), 46.0, false)
	_rebuild_peddler_ui()
	peddler_modal.visible = true
	peddler_modal.scale = Vector2.ONE
	peddler_modal.modulate.a = 0.0
	var tw := peddler_modal.create_tween()
	tw.tween_property(peddler_modal, "modulate:a", 1.0, 0.20)
	emit_signal("play_sfx_requested", "prop_coins")

func _rebuild_peddler_ui() -> void:
	if peddler_gold_lbl:
		peddler_gold_lbl.text = _tr("%d Florins", "%d Zlaťáků") % player_available_gold
	if peddler_reroll_btn:
		peddler_reroll_btn.disabled = (player_available_gold < 10)
		peddler_reroll_btn.text = _tr("New Wares (10g)", "Nové zboží (10g)")
	if peddler_close_btn:
		peddler_close_btn.text = _tr("Return to Duel ›", "Zpět do duelu ›")
	if not peddler_cards_hbox:
		return
	peddler_3d_roots.clear()
	for ch in peddler_cards_hbox.get_children():
		ch.queue_free()

	for i in range(peddler_offers.size()):
		var offer: Dictionary = peddler_offers[i]
		var col: Color = offer.get("col", Color(0.92, 0.76, 0.34))
		var bought := bool(offer.get("bought", false))
		var cost := int(offer.get("cost", 20))
		var loc_name := _tr(str(offer.get("name", "Mystery Curio")), str(offer.get("name_cs", offer.get("name", "Artefakt"))))
		var loc_desc := _tr(str(offer.get("desc", "")), str(offer.get("desc_cs", offer.get("desc", ""))))

		var card_pc := PanelContainer.new()
		card_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var csb := _make_plaque_style(Color(0.08, 0.06, 0.05, 0.94), col if not bought else Color(0.32, 0.34, 0.32), 22)
		csb.content_margin_left = 14; csb.content_margin_right = 14
		csb.content_margin_top = 12; csb.content_margin_bottom = 12
		card_pc.add_theme_stylebox_override("panel", csb)
		card_pc.mouse_entered.connect(func():
			if peddler_ghost_lbl:
				_start_handwriting_anim(peddler_ghost_lbl, "Spirko — %s: \"%s\"" % [loc_name, loc_desc], 52.0, false)
		)
		peddler_cards_hbox.add_child(card_pc)

		var cvb := VBoxContainer.new()
		cvb.add_theme_constant_override("separation", 6)
		card_pc.add_child(cvb)

		var cat_lbl := Label.new()
		cat_lbl.text = _tr(str(offer.get("category", "CURIO")), str(offer.get("category_cs", offer.get("category", "ARTEFAKT"))))
		cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cat_lbl.add_theme_font_override("font", _get_font(false))
		cat_lbl.add_theme_font_size_override("font_size", 13)
		cat_lbl.add_theme_color_override("font_color", col.lightened(0.25))
		cvb.add_child(cat_lbl)

		var frame_pc := PanelContainer.new()
		frame_pc.custom_minimum_size = Vector2(154, 154)
		frame_pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var f_sb := _make_plaque_style(Color(0.04, 0.03, 0.035, 0.96), col.darkened(0.15), 22)
		f_sb.content_margin_left = 6; f_sb.content_margin_right = 6
		f_sb.content_margin_top = 6; f_sb.content_margin_bottom = 6
		frame_pc.add_theme_stylebox_override("panel", f_sb)
		cvb.add_child(frame_pc)

		var em_id := str(offer.get("emblem", "urn"))
		var vp_3d := _build_3d_shop_item_viewport(em_id, col)
		frame_pc.add_child(vp_3d)

		var name_lbl := Label.new()
		name_lbl.text = loc_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_override("font", _get_font(true))
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
		cvb.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = loc_desc
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_override("font", _get_font(false))
		desc_lbl.add_theme_font_size_override("font_size", 15)
		desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74))
		cvb.add_child(desc_lbl)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(0, 46)
		buy_btn.add_theme_font_override("font", _get_font(true))
		buy_btn.add_theme_font_size_override("font_size", 17)
		if bought:
			buy_btn.text = _tr("ON TABLE", "NA STOLE")
			buy_btn.disabled = true
			_style_action_button(buy_btn, Color(0.12, 0.22, 0.14, 0.72), Color(0.36, 0.62, 0.40), 18)
		else:
			buy_btn.text = _tr("FREE GIFT (0g)", "DÁREK ZDARMA (0g)") if cost <= 0 else (_tr("BUY (%dg)" % cost, "KOUPIT (%dg)" % cost))
			buy_btn.disabled = (player_available_gold < cost)
			_style_action_button(buy_btn, col.darkened(0.65), col, 18)
			var cap_i := i
			buy_btn.pressed.connect(func(): _buy_peddler_offer(cap_i))
		cvb.add_child(buy_btn)

func _buy_peddler_offer(idx: int) -> void:
	if idx < 0 or idx >= peddler_offers.size():
		return
	var offer := peddler_offers[idx]
	var cost := int(offer.get("cost", 20))
	if bool(offer.get("bought", false)) or player_available_gold < cost:
		emit_signal("play_sfx_requested", "error")
		return
	player_available_gold -= cost
	duel_gold_delta -= cost
	offer["bought"] = true
	var item_id := str(offer.get("id", ""))
	var col: Color = offer.get("col", Color(0.95, 0.82, 0.34))

	if item_id.begins_with("TRELIC_"):
		if not (item_id in run_table_relics):
			while run_table_relics.size() >= Catalog.MAX_ACTIVE_RELICS:
				run_table_relics.pop_front()
			run_table_relics.append(item_id)
		_rebuild_relic_visuals()
		var t_origin := to_global(Vector3(0.32, 0.90, 0.48))
		Fx.relic_tybw_ritual(self, t_origin, opp_hands_anchor.global_position if is_instance_valid(opp_hands_anchor) else Vector3(0.0, 1.0, -1.0), item_id, col)
	else:
		match item_id:
			"MYS_LANTERN_ASH":
				redraws_left += 1
				if not player_hand.is_empty():
					player_hand[0]["edition"] = "KNIGHT"
			"MYS_BLOOD_CHALICE":
				duel_chalice_mult += 0.4
				player_score += 12
			"MYS_IRON_GAUNTLET":
				player_shields += 2
				ai_score = maxi(0, ai_score - 15)
			"MYS_ALCHEMIST_PHIAL":
				puf_charges += 2
				storm_surge_mult += 1.2
			"MYS_RAVENS_EYE":
				rival_cards_revealed_turns += 3
				player_hand.append(_draw_from_deck())
			"MYS_HERMIT_SCROLL":
				var maged := false
				for hc in player_hand:
					if str(hc.get("rank", "")) in ["7", "8"]:
						hc["pts"] = int(hc["pts"]) + 15
						hc["bonus_chips"] = int(hc.get("bonus_chips", 0)) + 15
					if not maged and Catalog.normalize_card_class(str(hc.get("edition", "NORMAL"))) == "NORMAL":
						hc["edition"] = "MAGE"
						hc["mage_charge"] = 2
						maged = true
			"MYS_WITCH_MIRROR":
				duel_next_xmult *= 1.5
				var pc := Catalog.get_power_card("SPEC_MIRROR")
				if not pc.is_empty():
					player_hand.append({"suit": pc["suit"], "rank": "PWR", "pts": pc["pts"], "rname": pc["name"], "short": pc["short"], "power_id": pc["id"], "wild": true, "accent": pc["accent"], "power_line": pc["power_line"], "desc": pc["desc"], "edition": "MAGE", "mage_charge": 2})
			"MYS_CROWBAR_KEY":
				player_hand.append(_draw_from_deck())
				player_hand.append(_draw_from_deck())
				pending_draw = 0
				pending_skip = false
				player_score += 15
			"MYS_RUNE_WHETSTONE":
				duel_whetstone_stacks += 1
				duel_sword_bonus_gold += 35
			"MYS_BELL_TOLL":
				ai_stun_turns += 1
				player_score += 45
				puf_charges += 1
		_spawn_purchased_table_item_3d(offer)
	_save_shop_checkpoint()
	emit_signal("play_sfx_requested", "prop_coins")
	Fx.burst(self, to_global(Vector3(0.0, 0.96, 0.0)), col, 22, 0.85, 0.55, 0.025, 0.35, true, 140.0)
	_spawn_score_popup("✦ %s!" % _tr(str(offer.get("name", "Upgrade")), str(offer.get("name_cs", offer.get("name", "Artefakt")))), col, true)
	table_status_label3d.text = _tr("Peddler Upgrade: %s!", "Získáno: %s!") % _tr(str(offer.get("name", "")), str(offer.get("name_cs", offer.get("name", ""))))
	set_duel_wager(active_wager_type, true)
	_rebuild_all_3d_hands()
	_refresh_table_labels()
	_rebuild_peddler_ui()

func _reroll_peddler_offers() -> void:
	if player_available_gold < 10:
		emit_signal("play_sfx_requested", "error")
		return
	player_available_gold -= 10
	duel_gold_delta -= 10
	peddler_offers = Catalog.roll_medieval_peddler_offers(3, run_table_relics)
	emit_signal("play_sfx_requested", "card_shuffle")
	_rebuild_peddler_ui()

func _close_peddler_shop() -> void:
	if not peddler_open:
		return
	peddler_open = false
	if peddler_modal:
		peddler_modal.visible = false
	emit_signal("play_sfx_requested", "ui_click")
	_rebuild_all_3d_hands()
	_refresh_table_labels()
	_trigger_turn_table_bet_glance(false)

func _build_mist_guess_modal() -> void:
	mist_guess_modal = PanelContainer.new()
	mist_guess_modal.anchor_left = 0.5
	mist_guess_modal.anchor_top = 0.5
	mist_guess_modal.anchor_right = 0.5
	mist_guess_modal.anchor_bottom = 0.5
	mist_guess_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mist_guess_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	mist_guess_modal.custom_minimum_size = Vector2(700, 0)
	mist_guess_modal.offset_left = -350
	mist_guess_modal.offset_top = -100
	mist_guess_modal.offset_right = 350
	mist_guess_modal.offset_bottom = 100
	mist_guess_modal.z_index = 46
	mist_guess_modal.visible = false
	var msb := _make_plaque_style(Color(0.06, 0.08, 0.12, 0.97), Color(0.60, 0.88, 0.98), 14)
	msb.set_border_width_all(3)
	msb.content_margin_left = 20; msb.content_margin_right = 20
	msb.content_margin_top = 14; msb.content_margin_bottom = 14
	mist_guess_modal.add_theme_stylebox_override("panel", msb)
	hud_root.add_child(mist_guess_modal)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	mist_guess_modal.add_child(vb)

	var ttl := Label.new()
	ttl.text = _tr("BATTLE MIST — GUESS THE KNIGHT!", "BOJOVÁ MLHA — UHÁDNI RYTÍŘE!")
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_override("font", _get_font(true))
	ttl.add_theme_font_size_override("font_size", 20)
	ttl.add_theme_color_override("font_color", Color(0.74, 0.94, 1.0))
	vb.add_child(ttl)
	mist_guess_title_lbl = ttl

	var sub := Label.new()
	sub.text = _tr("Rival hid a Knight card in Battle Mist — guess which card they played! Correct = +10 pts | Wrong = draw +1 & Rival +15 pts.", "Soupeř zahrál skrytého Rytíře v mlze — tipni, jakou kartu položil! Správně = +10 b. | Špatně = +1 karta & soupeř +15 b.")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", _get_font(false))
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
	vb.add_child(sub)
	mist_guess_sub_lbl = sub

	mist_guess_options_box = HBoxContainer.new()
	mist_guess_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mist_guess_options_box.add_theme_constant_override("separation", 10)
	vb.add_child(mist_guess_options_box)

func _open_mist_guess_modal(true_card: Dictionary) -> void:
	knight_mist_active = true
	knight_mist_from_ai = true
	knight_mist_hidden_card = true_card.duplicate()
	if not discard_pile.is_empty():
		discard_pile.back()["_mist_hidden"] = true
		_refresh_discard_top_mesh()
	if is_instance_valid(discard_mist_fx_root):
		discard_mist_fx_root.visible = true

	mist_guess_options.clear()
	var ts := str(true_card.get("suit", "CERVEN"))
	var tr := str(true_card.get("rank", "8"))
	mist_guess_options.append({"suit": ts, "rank": tr, "rname": _get_rank_name(tr), "correct": true})
	var guard := 0
	while mist_guess_options.size() < 4 and guard < 40:
		guard += 1
		var rs: Dictionary = SUITS[randi() % SUITS.size()]
		var rr: Dictionary = RANKS[randi() % RANKS.size()]
		var dup := false
		for ex in mist_guess_options:
			if str(ex["suit"]) == str(rs["id"]) and str(ex["rank"]) == str(rr["id"]):
				dup = true
				break
		if not dup:
			var r_id := str(rr["id"])
			mist_guess_options.append({"suit": str(rs["id"]), "rank": r_id, "rname": _get_rank_name(r_id), "correct": false})
	mist_guess_options.shuffle()

	for ch in mist_guess_options_box.get_children():
		ch.queue_free()
	if mist_guess_title_lbl:
		mist_guess_title_lbl.text = _tr("BATTLE MIST — GUESS THE KNIGHT!", "BOJOVÁ MLHA — UHÁDNI RYTÍŘE!")
	if mist_guess_sub_lbl:
		mist_guess_sub_lbl.text = _tr("Rival hid a Knight card in Battle Mist — guess which card they played! Correct = +10 pts | Wrong = draw +1 & Rival +15 pts.", "Soupeř zahrál skrytého Rytíře v mlze — tipni, jakou kartu položil! Správně = +10 b. | Špatně = +1 karta & soupeř +15 b.")
	for i in range(mist_guess_options.size()):
		var opt: Dictionary = mist_guess_options[i]
		var sobj := _get_suit_obj(str(opt["suit"]))
		var btn := Button.new()
		btn.text = "%s %s\n(%s)" % [sobj["sym"], str(opt["rname"]), sobj["name"]]
		btn.custom_minimum_size = Vector2(150, 58)
		btn.add_theme_font_override("font", _get_font(true))
		btn.add_theme_font_size_override("font_size", 14)
		var bcol: Color = sobj["col"]
		btn.add_theme_color_override("font_color", bcol.lightened(0.45))
		var btn_norm := StyleBoxFlat.new()
		btn_norm.bg_color = Color(0.11, 0.085, 0.07, 0.96)
		btn_norm.border_color = bcol
		btn_norm.set_border_width_all(2)
		btn_norm.set_corner_radius_all(10)
		btn_norm.content_margin_left = 10; btn_norm.content_margin_right = 10
		btn_norm.content_margin_top = 6; btn_norm.content_margin_bottom = 6
		var btn_hov := btn_norm.duplicate() as StyleBoxFlat
		btn_hov.bg_color = Color(0.19, 0.145, 0.11, 0.98)
		btn_hov.border_color = bcol.lightened(0.35)
		btn.add_theme_stylebox_override("normal", btn_norm)
		btn.add_theme_stylebox_override("hover", btn_hov)
		btn.add_theme_stylebox_override("pressed", btn_norm)
		var ci := i
		btn.pressed.connect(func(): submit_mist_guess(ci))
		mist_guess_options_box.add_child(btn)

	mist_guess_open = true
	if mist_guess_modal:
		mist_guess_modal.visible = true
	emit_signal("play_sfx_requested", "ui_hover")

func submit_mist_guess(idx: int) -> void:
	if not mist_guess_open or idx < 0 or idx >= mist_guess_options.size():
		return
	var picked: Dictionary = mist_guess_options[idx]
	mist_guess_open = false
	if mist_guess_modal:
		mist_guess_modal.visible = false
	knight_mist_active = false
	if is_instance_valid(discard_mist_fx_root):
		discard_mist_fx_root.visible = false
	if not discard_pile.is_empty():
		discard_pile.back()["_mist_hidden"] = false
		_refresh_discard_top_mesh()
	if bool(picked.get("correct", false)):
		_bank_player_turn_score(10, _tr("Mist Pierced (+10)", "Mlha odhalena (+10)"), Color(0.55, 0.94, 1.0))
		emit_signal("play_sfx_requested", "ui_click")
		table_status_label3d.text = _tr("Sharp eye! Named the Knight!", "Bystré oko! Uhádl jsi Rytíře v mlze!")
	else:
		player_hand.append(_draw_from_deck())
		_award_ai_score_immediately(15, _tr("WRONG! +15 RIVAL", "ŠPATNĚ! +15 SOUPEŘ"), Color(1.0, 0.42, 0.36))
		emit_signal("play_sfx_requested", "error")
		_spawn_score_popup(_tr("WRONG! +1 CARD & +15 RIVAL", "ŠPATNĚ! +1 KARTA a +15 SOUPEŘ"), Color(1.0, 0.42, 0.36), false)
		table_status_label3d.text = _tr("Fooled by Mist! Drew +1 card.", "Zmátla tě mlha! Lížeš +1 kartu.")
	_finish_ai_3d_turn()

func _build_thief_heist_modal() -> void:
	thief_heist_modal = PanelContainer.new()
	thief_heist_modal.anchor_left = 0.5
	thief_heist_modal.anchor_top = 0.5
	thief_heist_modal.anchor_right = 0.5
	thief_heist_modal.anchor_bottom = 0.5
	thief_heist_modal.offset_left = -410
	thief_heist_modal.offset_top = -185
	thief_heist_modal.offset_right = 410
	thief_heist_modal.offset_bottom = 165
	thief_heist_modal.visible = false
	var tsb := _make_plaque_style(Color(0.05, 0.08, 0.06, 0.96), Color(0.28, 0.90, 0.56), 14)
	tsb.set_border_width_all(3)
	tsb.content_margin_left = 20; tsb.content_margin_right = 20
	tsb.content_margin_top = 14; tsb.content_margin_bottom = 14
	thief_heist_modal.add_theme_stylebox_override("panel", tsb)
	hud_root.add_child(thief_heist_modal)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	thief_heist_modal.add_child(vb)

	var hdr := Label.new()
	hdr.text = _tr("CUTPURSE HEIST — GUESS 2+ CARDS", "ZLODĚJ — UHÁDNI 2+ STEJNÉ KARTY")
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_override("font", _get_font(true))
	hdr.add_theme_font_size_override("font_size", 21)
	hdr.add_theme_color_override("font_color", Color(0.42, 0.96, 0.68))
	vb.add_child(hdr)
	thief_heist_title_lbl = hdr

	thief_heist_hint_lbl = Label.new()
	thief_heist_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thief_heist_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thief_heist_hint_lbl.add_theme_font_override("font", _get_font(false))
	thief_heist_hint_lbl.add_theme_font_size_override("font_size", 15)
	thief_heist_hint_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.86))
	vb.add_child(thief_heist_hint_lbl)

	var cls_lbl := Label.new()
	cls_lbl.text = _tr("Pick Class (Merchants = 2×! Mages immune!):", "Vyber třídu (Kupci = 2×! Mágové imunní!):")
	cls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cls_lbl.add_theme_font_override("font", _get_font(false))
	cls_lbl.add_theme_font_size_override("font_size", 14)
	cls_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	vb.add_child(cls_lbl)
	thief_heist_cls_lbl = cls_lbl

	thief_heist_class_box = HBoxContainer.new()
	thief_heist_class_box.alignment = BoxContainer.ALIGNMENT_CENTER
	thief_heist_class_box.add_theme_constant_override("separation", 10)
	vb.add_child(thief_heist_class_box)
	thief_heist_class_btns.clear()
	for cl in [
		{"id": "MERCHANT", "en": "2+ Merchants (+20g)", "cs": "2+ Kupci (+20g)", "col": Color(1.0, 0.82, 0.24)},
		{"id": "NORMAL",   "en": "2+ Normals",          "cs": "2+ Základní",     "col": Color(0.76, 0.72, 0.64)},
		{"id": "KNIGHT",   "en": "2+ Knights",          "cs": "2+ Rytíři",       "col": Color(0.60, 0.88, 0.98)},
	]:
		var cb := Button.new()
		cb.text = _tr(str(cl["en"]), str(cl["cs"]))
		cb.custom_minimum_size = Vector2(220, 44)
		cb.add_theme_font_override("font", _get_font(true))
		cb.add_theme_font_size_override("font_size", 15)
		var cc: Color = cl["col"]
		cb.add_theme_color_override("font_color", cc.lightened(0.3))
		cb.add_theme_stylebox_override("normal", _make_ink_btn_style(cc, false))
		cb.add_theme_stylebox_override("hover", _make_ink_btn_style(cc, true))
		var cid := str(cl["id"])
		cb.pressed.connect(func(): resolve_thief_heist("class", cid))
		thief_heist_class_box.add_child(cb)
		thief_heist_class_btns.append({"btn": cb, "en": str(cl["en"]), "cs": str(cl["cs"])})

	var r_lbl := Label.new()
	r_lbl.text = _tr("Or guess 2+ of a Rank:", "Nebo uhádni 2+ stejné hodnoty:")
	r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_lbl.add_theme_font_override("font", _get_font(false))
	r_lbl.add_theme_font_size_override("font_size", 14)
	r_lbl.add_theme_color_override("font_color", Color(0.76, 0.86, 0.80))
	vb.add_child(r_lbl)
	thief_heist_rank_lbl = r_lbl

	thief_heist_rank_box = GridContainer.new()
	thief_heist_rank_box.columns = 4
	thief_heist_rank_box.add_theme_constant_override("h_separation", 8)
	thief_heist_rank_box.add_theme_constant_override("v_separation", 8)
	vb.add_child(thief_heist_rank_box)
	thief_heist_rank_btns.clear()
	for r_item in RANKS:
		var rb := Button.new()
		var rid := str(r_item["id"])
		rb.text = "2+ %s" % _get_rank_name(rid)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.custom_minimum_size = Vector2(140, 38)
		rb.add_theme_font_override("font", _get_font(true))
		rb.add_theme_font_size_override("font_size", 15)
		rb.add_theme_stylebox_override("normal", _make_ink_btn_style(Color(0.34, 0.88, 0.56), false))
		rb.add_theme_stylebox_override("hover", _make_ink_btn_style(Color(0.45, 0.96, 0.68), true))
		rb.pressed.connect(func(): resolve_thief_heist("rank", rid))
		thief_heist_rank_box.add_child(rb)
		thief_heist_rank_btns.append({"btn": rb, "id": rid})

	var sk := Button.new()
	sk.text = _tr("Skip Heist", "Přeskočit")
	sk.custom_minimum_size = Vector2(220, 36)
	sk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sk.add_theme_font_size_override("font_size", 14)
	sk.pressed.connect(func(): resolve_thief_heist("skip", ""))
	vb.add_child(sk)
	thief_heist_skip_btn = sk

func _open_thief_heist_modal() -> void:
	thief_heist_open = true
	if thief_heist_hint_lbl:
		thief_heist_hint_lbl.text = _tr("Rival holds %d card(s). Guess 2+ matching non-Mage cards to STEAL 1!", "Soupeř má %d karet. Uhádni 2+ stejné karty (ne Mága) a UKRADNI 1!" % ai_hand.size())
	if thief_heist_modal:
		thief_heist_modal.visible = true
	emit_signal("play_sfx_requested", "ui_hover")

func resolve_thief_heist(guess_kind: String, guess_val: String) -> void:
	if not thief_heist_open:
		return
	thief_heist_open = false
	if thief_heist_modal:
		thief_heist_modal.visible = false
	if guess_kind != "skip":
		var stealable_idxs: Array[int] = []
		var weight := 0
		for i in range(ai_hand.size()):
			var c: Dictionary = ai_hand[i]
			var cls := Catalog.normalize_card_class(str(c.get("edition", "NORMAL")))
			# Thief NEVER steals charging Mage cards!
			if cls == "MAGE":
				continue
			var matched := (cls == guess_val) if guess_kind == "class" else (str(c.get("rank", "")) == guess_val)
			if matched:
				stealable_idxs.append(i)
				# Guildsman Merchants are double vulnerable to Cutpurse Thievery!
				weight += (2 if cls == "MERCHANT" else 1)
		if weight >= 2 and not stealable_idxs.is_empty():
			var pick_pos := stealable_idxs[randi() % stealable_idxs.size()]
			var stolen: Dictionary = ai_hand[pick_pos]
			ai_hand.remove_at(pick_pos)
			player_hand.append(stolen)
			for _d in range(2):
				ai_hand.append(_draw_from_deck())
			var loot_bonus := 20 if Catalog.normalize_card_class(str(stolen.get("edition", "NORMAL"))) == "MERCHANT" else 0
			match_bonus_gold += loot_bonus
			var sobj := _get_suit_obj(str(stolen.get("suit", "CERVEN")))
			emit_signal("play_sfx_requested", "prop_coins")
			_spawn_score_popup(_tr("HEIST! Stole %s %s%s!" % [sobj["sym"], _get_rank_name(str(stolen.get("rank", ""))), (" (+20g)" if loot_bonus > 0 else "")], "LOUPEŽ! Ukradeno %s %s%s!" % [sobj["sym"], _get_rank_name(str(stolen.get("rank", ""))), (" (+20g)" if loot_bonus > 0 else "")]), Color(0.32, 0.94, 0.62), true)
			table_status_label3d.text = _tr("CUTPURSE HIT! Stole %s %s & Rival +2!" % [sobj["sym"], _get_rank_name(str(stolen.get("rank", "")))], "ÚSPĚCH! Ukradena karta %s %s a Soupeř +2!" % [sobj["sym"], _get_rank_name(str(stolen.get("rank", "")))])
		else:
			emit_signal("play_sfx_requested", "error")
			_spawn_score_popup(_tr("HEIST WHIFFED!", "LOUPEŽ SELHALA!"), Color(0.76, 0.78, 0.80), true)
			table_status_label3d.text = _tr("Cutpurse missed — no 2+ matches held!", "Zloděj minul — soupeř nemá 2+ takové karty!")
		_rebuild_all_3d_hands()
		_refresh_table_labels()
	_start_ai_3d_turn()

func _flash_turn_toast(title_txt: String, sub_txt: String, accent: Color, hold_sec: float = 0.85, stay_visible: bool = false) -> void:
	if not turn_banner_grp or not turn_banner_lbl:
		return
	if tutorial_mode and tutorial_step < 1 and not stay_visible:
		turn_banner_grp.visible = false
		return
	if turn_toast_tween and turn_toast_tween.is_valid():
		turn_toast_tween.kill()
	turn_banner_accent = accent
	turn_banner_lbl.add_theme_font_override("font", _get_font(true))
	turn_banner_lbl.text = title_txt
	turn_banner_lbl.add_theme_color_override("font_color", accent.lightened(0.45))
	if turn_banner_sub_lbl:
		turn_banner_sub_lbl.text = sub_txt

	if stay_visible:
		# Victory / Defeat Finale Banner scales cleanly into upper-center stage!
		if turn_ornament_ctrl: turn_ornament_ctrl.visible = false
		if turn_banner_sub_lbl: turn_banner_sub_lbl.visible = true
		turn_banner_grp.anchor_left = 0.5
		turn_banner_grp.anchor_right = 0.5
		turn_banner_grp.anchor_top = 0.25
		turn_banner_grp.anchor_bottom = 0.25
		turn_banner_grp.offset_left = -320
		turn_banner_grp.offset_top = -42
		turn_banner_grp.offset_right = 320
		turn_banner_grp.offset_bottom = 42
		turn_banner_grp.pivot_offset = Vector2(320, 42)
		turn_banner_lbl.position = Vector2(12, 8)
		turn_banner_lbl.size = Vector2(616, 40)
		turn_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turn_banner_lbl.add_theme_font_size_override("font_size", 28)
		if turn_banner_sub_lbl:
			turn_banner_sub_lbl.position = Vector2(12, 50)
			turn_banner_sub_lbl.size = Vector2(616, 24)
			turn_banner_sub_lbl.add_theme_font_size_override("font_size", 14)
	else:
		# Normal Play: Prominent Bottom-Left Calligraphy Directly Underneath the 2D Heart Indicator!
		if turn_ornament_ctrl: turn_ornament_ctrl.visible = true
		if turn_banner_sub_lbl: turn_banner_sub_lbl.visible = false
		turn_banner_grp.anchor_left = 0.0
		turn_banner_grp.anchor_top = 1.0
		turn_banner_grp.anchor_right = 0.0
		turn_banner_grp.anchor_bottom = 1.0
		turn_banner_grp.offset_left = 18
		turn_banner_grp.offset_top = -152
		turn_banner_grp.offset_right = 388
		turn_banner_grp.offset_bottom = -96
		turn_banner_grp.pivot_offset = Vector2(100, 28)
		turn_banner_lbl.position = Vector2(0, 0)
		turn_banner_lbl.size = Vector2(370, 52)
		turn_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		turn_banner_lbl.add_theme_font_size_override("font_size", 44 if is_player_turn else 36)

	if turn_ornament_ctrl:
		turn_ornament_ctrl.queue_redraw()
	turn_banner_grp.visible = true
	turn_banner_grp.scale = Vector2(0.88, 0.88) if not stay_visible else Vector2(0.76, 0.76)
	turn_banner_grp.modulate.a = 0.25 if not stay_visible else 0.0
	turn_toast_tween = create_tween()
	turn_toast_tween.set_parallel(true)
	turn_toast_tween.tween_property(turn_banner_grp, "modulate:a", 1.0, 0.16)
	turn_toast_tween.tween_property(turn_banner_grp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_victory_summary_overlay() -> void:
	victory_summary_overlay = Control.new()
	victory_summary_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	victory_summary_overlay.z_index = 48
	victory_summary_overlay.visible = false
	victory_summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(victory_summary_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.02, 0.74)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_summary_overlay.add_child(bg)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -330
	box.offset_top = -195
	box.offset_right = 330
	box.offset_bottom = 195
	box.pivot_offset = Vector2(330, 195)
	var b_sb := _make_plaque_style(Color(0.06, 0.045, 0.038, 0.96), Color(1.0, 0.84, 0.28), 28)
	b_sb.set_border_width_all(3)
	b_sb.content_margin_left = 28; b_sb.content_margin_right = 28
	b_sb.content_margin_top = 22; b_sb.content_margin_bottom = 22
	box.add_theme_stylebox_override("panel", b_sb)
	victory_summary_overlay.add_child(box)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)

	# Animated Golden Crown (Korunka) with Royal Jewels & Sunburst Rays!
	victory_crown_ctrl = Control.new()
	victory_crown_ctrl.custom_minimum_size = Vector2(140, 96)
	victory_crown_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	victory_crown_ctrl.draw.connect(func():
		var cc := victory_crown_ctrl.size * 0.5 + Vector2(0, 8)
		var ct := float(Time.get_ticks_msec()) * 0.001
		var bob := sin(ct * 3.4) * 3.5
		# Sunburst rays behind crown
		for ri in range(12):
			var ra := ct * 0.7 + float(ri) * (TAU / 12.0)
			var r0 := cc + Vector2(cos(ra), sin(ra)) * 22.0
			var r1 := cc + Vector2(cos(ra), sin(ra)) * (44.0 + sin(ct * 4.0 + float(ri)) * 4.0)
			victory_crown_ctrl.draw_line(r0, r1, Color(1.0, 0.86, 0.30, 0.36), 3.0, true)
		var c_poly := PackedVector2Array([
			cc + Vector2(-42, 22 + bob),
			cc + Vector2(-48, -14 + bob),
			cc + Vector2(-24, 4 + bob),
			cc + Vector2(0, -28 + bob),
			cc + Vector2(24, 4 + bob),
			cc + Vector2(48, -14 + bob),
			cc + Vector2(42, 22 + bob),
		])
		victory_crown_ctrl.draw_colored_polygon(c_poly, Color(1.0, 0.82, 0.22))
		victory_crown_ctrl.draw_polyline(c_poly + PackedVector2Array([c_poly[0]]), Color(0.18, 0.10, 0.04), 2.6, true)
		victory_crown_ctrl.draw_rect(Rect2(cc.x - 42, cc.y + 14 + bob, 84, 10), Color(0.78, 0.16, 0.20))
		# Crown jewels
		victory_crown_ctrl.draw_circle(cc + Vector2(0, -28 + bob), 5.5, Color(0.35, 0.94, 1.0))
		victory_crown_ctrl.draw_circle(cc + Vector2(-48, -14 + bob), 4.5, Color(1.0, 0.32, 0.36))
		victory_crown_ctrl.draw_circle(cc + Vector2(48, -14 + bob), 4.5, Color(1.0, 0.32, 0.36))
		victory_crown_ctrl.draw_circle(cc + Vector2(0, 6 + bob), 5.0, Color(0.95, 0.22, 0.28))
	)
	vb.add_child(victory_crown_ctrl)

	victory_title_lbl = Label.new()
	victory_title_lbl.text = "YOU WON!"
	victory_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_title_lbl.add_theme_font_override("font", _get_font(true))
	victory_title_lbl.add_theme_font_size_override("font_size", 32)
	victory_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.36))
	victory_title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01))
	victory_title_lbl.add_theme_constant_override("outline_size", 8)
	vb.add_child(victory_title_lbl)

	victory_stats_lbl = Label.new()
	victory_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	victory_stats_lbl.add_theme_font_override("font", _get_font(false))
	victory_stats_lbl.add_theme_font_size_override("font_size", 17)
	victory_stats_lbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	vb.add_child(victory_stats_lbl)

	victory_continue_btn = Button.new()
	victory_continue_btn.text = "CLAIM SPOILS & CONTINUE ›"
	victory_continue_btn.custom_minimum_size = Vector2(280, 48)
	victory_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	victory_continue_btn.add_theme_font_override("font", _get_font(true))
	victory_continue_btn.add_theme_font_size_override("font_size", 16)
	victory_continue_btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.80))
	_style_action_button(victory_continue_btn, Color(0.28, 0.18, 0.06, 0.98), Color(1.0, 0.84, 0.30), 22)
	victory_continue_btn.pressed.connect(func():
		_battle_session_token += 1
		if victory_summary_overlay:
			victory_summary_overlay.visible = false
		if visible:
			emit_signal("exit_to_map_requested")
	)
	vb.add_child(victory_continue_btn)

func _show_victory_summary_overlay(wager_payout: int, win_gold: int) -> void:
	if not victory_summary_overlay:
		return
	var best_played := maxi(10, match_best_slam)
	var your_desc := match_best_move_desc if match_best_move_desc != "" else ("+%d pts Slam" % best_played)
	if victory_title_lbl:
		victory_title_lbl.text = _tr("YOU WON!", "VÍTĚZSTVÍ!")
	if victory_stats_lbl:
		victory_stats_lbl.text = _tr(
			"Carry-Out Score: %d / %d pts   •   ♥ Survived: %d/%d HP   •   Spoils: +%d (+%dg Wager)\n★ Your Best Move: %s",
			"Odnášené skóre: %d / %d b   •   ♥ Přežil s: %d/%d HP   •   Kořist: +%d (+%dg Sázka)\n★ Tvůj nejlepší tah: %s"
		) % [player_score, target_score, player_hp, player_max_hp, win_gold, wager_payout, your_desc]
	if victory_continue_btn:
		victory_continue_btn.text = _tr("CLAIM SPOILS & CONTINUE ›", "SEBRAT KOŘIST A POKRAČOVAT ›")
	victory_summary_overlay.visible = false
	victory_summary_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_summary_overlay.modulate.a = 0.0
	var tw := victory_summary_overlay.create_tween()
	tw.tween_interval(3.65)
	tw.tween_callback(func():
		if is_instance_valid(victory_summary_overlay):
			victory_summary_overlay.visible = true
			victory_summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	)
	tw.tween_property(victory_summary_overlay, "modulate:a", 1.0, 0.42)

func _build_defeat_summary_overlay() -> void:
	defeat_summary_overlay = Control.new()
	defeat_summary_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	defeat_summary_overlay.z_index = 48
	defeat_summary_overlay.visible = false
	defeat_summary_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(defeat_summary_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.01, 0.015, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_summary_overlay.add_child(bg)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -330
	box.offset_top = -185
	box.offset_right = 330
	box.offset_bottom = 185
	box.pivot_offset = Vector2(330, 185)
	var b_sb := _make_plaque_style(Color(0.07, 0.028, 0.032, 0.96), Color(0.95, 0.24, 0.28), 28)
	b_sb.set_border_width_all(3)
	b_sb.content_margin_left = 28; b_sb.content_margin_right = 28
	b_sb.content_margin_top = 24; b_sb.content_margin_bottom = 24
	box.add_theme_stylebox_override("panel", b_sb)
	defeat_summary_overlay.add_child(box)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	box.add_child(vb)

	var skull_lbl := Label.new()
	skull_lbl.text = "   "
	skull_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skull_lbl.add_theme_font_override("font", _get_font(true))
	skull_lbl.add_theme_font_size_override("font_size", 36)
	skull_lbl.add_theme_color_override("font_color", Color(0.98, 0.28, 0.30))
	skull_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.01))
	skull_lbl.add_theme_constant_override("outline_size", 8)
	vb.add_child(skull_lbl)

	defeat_title_lbl = Label.new()
	defeat_title_lbl.text = "DEFEATED"
	defeat_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_title_lbl.add_theme_font_override("font", _get_font(true))
	defeat_title_lbl.add_theme_font_size_override("font_size", 32)
	defeat_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	defeat_title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.01))
	defeat_title_lbl.add_theme_constant_override("outline_size", 8)
	vb.add_child(defeat_title_lbl)

	defeat_stats_lbl = Label.new()
	defeat_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	defeat_stats_lbl.add_theme_font_override("font", _get_font(false))
	defeat_stats_lbl.add_theme_font_size_override("font_size", 17)
	defeat_stats_lbl.add_theme_color_override("font_color", Color(0.94, 0.86, 0.82))
	vb.add_child(defeat_stats_lbl)

	defeat_continue_btn = Button.new()
	defeat_continue_btn.text = "RISE AGAIN & CLAIM SPOILS ›"
	defeat_continue_btn.custom_minimum_size = Vector2(300, 48)
	defeat_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	defeat_continue_btn.add_theme_font_override("font", _get_font(true))
	defeat_continue_btn.add_theme_font_size_override("font_size", 16)
	defeat_continue_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.84))
	_style_action_button(defeat_continue_btn, Color(0.28, 0.08, 0.10, 0.98), Color(0.96, 0.30, 0.32), 22)
	defeat_continue_btn.pressed.connect(func():
		_battle_session_token += 1
		dramatic_lighting_dim = 0.0
		if defeat_summary_overlay:
			defeat_summary_overlay.visible = false
		if visible:
			emit_signal("exit_to_map_requested")
	)
	vb.add_child(defeat_continue_btn)

func _show_defeat_summary_overlay(ko_loss: bool, stage_gold: int) -> void:
	if not defeat_summary_overlay:
		return
	var cons_g := maxi(35, int(round(float(maxi(50, stage_gold)) * 0.60)))
	if defeat_title_lbl:
		defeat_title_lbl.text = _tr("SLAIN IN BATTLE", "PADL JSI V BOJI") if ko_loss else _tr("DEFEATED AT THE TABLE", "PORÁŽKA U STOLU")
	if defeat_stats_lbl:
		defeat_stats_lbl.text = _tr(
			"Your Crown Shattered! Carry-Out Score: %d / %d pts\n✦ Consolation Spoils: +%d Florins (+60%%)\n✦ Fail-Forward Blessing: +1 Free Card Class Forge & Tavern Retry Boost!",
			"Tvá koruna se roztříštila! Odnášené skóre: %d / %d b\n✦ Útěšná kořist: +%d Florinů (+60%%)\n✦ Požehnání dalšího pokusu: +1 Kovářská třída zdarma a bonus na start!"
		) % [player_score, target_score, cons_g]
	if defeat_continue_btn:
		defeat_continue_btn.text = _tr("RETURN & FORGE STRONGER ›", "NÁVRAT A POSÍLIT BALÍČEK ›")
	defeat_summary_overlay.visible = false
	defeat_summary_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_summary_overlay.modulate.a = 0.0
	var tw := defeat_summary_overlay.create_tween()
	tw.tween_interval(3.95)
	tw.tween_callback(func():
		if is_instance_valid(defeat_summary_overlay):
			defeat_summary_overlay.visible = true
			defeat_summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	)
	tw.tween_property(defeat_summary_overlay, "modulate:a", 1.0, 0.48)

func _play_sword_execution_finisher(player_won: bool) -> void:
	finisher_anim_active = true
	cam_impact_active = true
	cards_tucked = true
	if stagger_callout_pill:
		stagger_callout_pill.visible = false
	if table_status_label3d:
		table_status_label3d.visible = false
	if quick_action_bar:
		quick_action_bar.visible = false
	if stack_action_bar:
		stack_action_bar.visible = false

	var sw_skin := Catalog.get_sword_skin(active_sword_skin_id if player_won else "SWORD_CRIMSON")
	var trail_col: Color = sw_skin.get("trail_col", Color(1.0, 0.82, 0.28)) if player_won else Color(0.95, 0.16, 0.20)
	var sword := player_sword_root if player_won else opp_sword_root
	var my_sess := _battle_session_token

	dramatic_lighting_tint = Color(0.95, 0.14, 0.16) if not player_won else Color(1.0, 0.72, 0.22)
	var dim_tw := create_tween()
	dim_tw.tween_property(self, "dramatic_lighting_dim", 0.82, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	emit_signal("play_sfx_requested", "boss_omen")
	emit_signal("play_sfx_pitched_requested", "anim_sword_unsheathe", 0.78 if not player_won else 1.02)

	# Smooth 4.3s dramatic camera sweep
	var cam_tw := create_tween()
	if not player_won:
		# Player loses: camera tilts up toward darkness, pulls back to frame full execution & shattering crown
		cam_tw.set_parallel(true)
		cam_tw.tween_property(cam, "position", Vector3(0.0, 1.58, 1.68), 1.90).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(cam, "rotation_degrees:x", -8.0, 1.90).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(cam, "rotation_degrees:y", 0.0, 1.90).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(cam, "fov", 62.0, 1.90)
		cam_tw.chain().tween_interval(0.38)
		cam_tw.chain().set_parallel(true)
		cam_tw.tween_property(cam, "position", Vector3(0.0, 1.68, 1.76), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cam_tw.tween_property(cam, "rotation_degrees:x", -23.0, 0.34)
		cam_tw.tween_property(cam, "fov", 65.0, 0.34)
		cam_tw.chain().set_parallel(true)
		cam_tw.tween_property(cam, "rotation_degrees:x", -21.0, 1.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		cam_tw.tween_property(cam, "fov", 60.0, 1.50)
	else:
		# Rival loses: camera glides victoriously over the table toward Rival
		cam_tw.set_parallel(true)
		cam_tw.tween_property(cam, "position", Vector3(0.0, 1.58, 1.12), 2.00).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(cam, "rotation_degrees:x", -10.0, 2.00).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(cam, "rotation_degrees:y", 0.0, 2.00).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(cam, "fov", 58.0, 2.00)
		cam_tw.chain().tween_interval(0.30)
		cam_tw.chain().set_parallel(true)
		cam_tw.tween_property(cam, "position", Vector3(0.0, 1.66, 1.40), 1.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tw.tween_property(cam, "rotation_degrees:x", -18.0, 1.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam_tw.tween_property(cam, "fov", 58.0, 1.40)

	var exec_center_g := to_global(Vector3(0.0, 0.82, -0.10))
	var exec_loser_g := to_global(Vector3(0.0, 1.05, 0.95) if not player_won else Vector3(0.0, 1.15, -1.52))
	var on_exec_impact := func() -> void:
		if my_sess != _battle_session_token or not is_inside_tree() or not visible:
			return
		emit_signal("play_sfx_pitched_requested", "anim_sword_cleave", 0.82 if not player_won else 1.05)
		emit_signal("play_sfx_requested", "card_slam")
		cam_kick_shake = 1.65 if not player_won else 1.35
		cam_spring.trigger_score_recoil(maxi(600, target_score), 9.0, 1.55 if not player_won else 1.35)
		table_pulse_strength = 1.90
		var imp := to_global(Vector3(0.0, 1.12, 0.35) if not player_won else Vector3(0.0, 1.24, -1.48))
		_spawn_impact_shockwave(imp, Color(0.98, 0.14, 0.18) if not player_won else trail_col, 4.2)
		_spawn_card_impact_dust(imp)
		_trigger_screen_juice(Color(0.98, 0.14, 0.18) if not player_won else trail_col, 1.0, 1.05, 0.65)
		Fx.ink_splat(self, imp, 42, 1.8)
		if not player_won:
			cam_spring.rot_vel_deg.z -= 28.0
			Fx.embers(self, imp, 44, 1.5)
			Fx.float_number(self, to_global(Vector3(0.0, 1.36, 0.40)), _tr("CROWN SHATTERED!", "KORUNA ROZTŘÍŠTĚNA!"), Color(1.0, 0.26, 0.28), 80, 0.30, 1.55, 1.95)
			for hc_n in player_card_nodes:
				if is_instance_valid(hc_n):
					var ctw := hc_n.create_tween().set_parallel(true)
					ctw.tween_property(hc_n, "position:y", hc_n.position.y - 0.38, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					ctw.tween_property(hc_n, "rotation_degrees:z", randf_range(-42.0, 42.0), 0.45)
		else:
			_spawn_lightning_bolt_3d(to_global(Vector3(0.0, 1.30, -1.62)), trail_col)
			Fx.gold_flakes(self, to_global(Vector3(0.0, 1.32, -1.58)), 52, 1.7)
			if active_wager_type == "SWORD":
				Fx.dagger_slash(self, to_global(Vector3(0.0, 1.28, -1.52)), to_global(Vector3(0.0, 1.18, -1.78)), 1.8)
				Fx.light_pillar(self, to_global(Vector3(0.0, 0.82, -1.60)), Color(1.0, 0.22, 0.18), 2.1, 1.1)
				Fx.float_number(self, to_global(Vector3(0.0, 1.56, -1.48)), _tr("RIVAL EXECUTED! +100g", "SOUPEŘ POPRAVEN! +100g"), Color(1.0, 0.28, 0.22), 74, 0.30, 1.35, 1.85)
			if is_instance_valid(opp_silhouette_root):
				var otw := opp_silhouette_root.create_tween().set_parallel(true)
				_opp_finisher_tween = otw
				if active_wager_type == "SWORD":
					otw.tween_property(opp_silhouette_root, "position", Vector3(0.18, -0.25, -2.55), 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
					otw.tween_property(opp_silhouette_root, "rotation_degrees", Vector3(-78.0, 34.0, -52.0), 0.55)
					otw.tween_property(opp_silhouette_root, "scale", Vector3(0.25, 0.25, 0.25), 0.55)
				else:
					otw.tween_property(opp_silhouette_root, "position", Vector3(0.0, 0.34, -2.35), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					otw.tween_property(opp_silhouette_root, "rotation_degrees", Vector3(-42.0, 18.0, -24.0), 0.65)
					otw.tween_property(opp_silhouette_root, "scale", Vector3(0.65, 0.65, 0.65), 0.65)
		if hud_root:
			_spawn_hud_sparkles(hud_root.size * 0.5, trail_col, 44)

	var exec_rig := BlenderVfx.play_defeat_execution_anim(
		self,
		not player_won,
		exec_center_g,
		exec_loser_g,
		on_exec_impact
	)
	_register_blender_vfx(exec_rig)

	if not is_instance_valid(sword):
		return
	var fin_light := OmniLight3D.new()
	fin_light.light_color = trail_col
	fin_light.light_energy = 5.0
	fin_light.omni_range = 3.2
	fin_light.position = Vector3(0.0, 0.25, -0.35)
	sword.add_child(fin_light)

	if _finisher_sword_tween and _finisher_sword_tween.is_valid():
		_finisher_sword_tween.kill()
	if _opp_finisher_tween and _opp_finisher_tween.is_valid():
		_opp_finisher_tween.kill()
	var base_sw_pos := sword.position
	var base_sw_rot := sword.rotation_degrees
	var tw := sword.create_tween()
	_finisher_sword_tween = tw
	# Keep table flank sword resting/trembling in place with glowing fin_light so center Blender Greatsword owns the stage
	tw.set_parallel(true)
	tw.tween_property(sword, "position", base_sw_pos + Vector3(0.0, 0.18, 0.0), 1.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sword, "rotation_degrees", base_sw_rot + Vector3(6.0, 0.0, -8.0 if player_won else 8.0), 1.40)
	tw.chain().tween_interval(0.85)
	tw.chain().set_parallel(true)
	tw.tween_property(sword, "position", base_sw_pos, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(sword, "rotation_degrees", base_sw_rot, 0.25)

func _check_win_or_redeal() -> bool:
	if (not tutorial_mode) and ((ai_hp <= 0) or (player_hp <= 0) or player_hand.is_empty() or ai_hand.is_empty()):
		_flush_pending_exchange_scores_immediately()
	var round_cycled := false
	if player_hand.is_empty():
		if tutorial_mode and tutorial_step == 7:
			_spawn_score_popup(_tr("★ 0 CARDS — ROUND WON! (+120 & ×2.44)", "★ 0 KARET — KOLO VYHRÁNO! (+120 & ×2.44)"), Color(1.0, 0.88, 0.34), true)
			_advance_tutorial_to(8)
			_refresh_table_labels()
			return false
		elif tutorial_mode and tutorial_step < 7:
			for _i in range(3):
				player_hand.append(_draw_from_deck())
		elif tutorial_mode:
			for _i in range(3):
				player_hand.append(_draw_from_deck())
		else:
			round_cycled = true
			if active_campaign_difficulty != "classic":
				var shed_ko := 16
				_award_player_score_immediately(shed_ko, _tr("Round %d Clear" % current_round_num, "Výhra %d. kola" % current_round_num), Color(0.45, 1.0, 0.68), shed_ko, _tr("Round %d Clear (+%d pts)" % [current_round_num, shed_ko], "Výhra %d. kola (+%d b.)" % [current_round_num, shed_ko]))
				match_bonus_gold += 35
				_spawn_score_popup(_tr("★ 0 CARDS — ROUND %d WON! (+%s & +35g, next round)" % [current_round_num, _format_pts_ui(shed_ko)], "★ 0 KARET — %d. KOLO VYHRÁNO! (+%s a +35g, nové kolo)" % [current_round_num, _format_pts_ui(shed_ko)]), Color(0.45, 1.0, 0.68), true)
			table_status_label3d.text = _tr("0 cards — Round %d Won! (+bonus & next round)" % current_round_num, "0 karet — %d. kolo vyhráno! (+bonus a nové kolo)" % current_round_num)
	elif ai_hand.is_empty():
		if tutorial_mode and tutorial_step < 8:
			for _i in range(3):
				ai_hand.append(_make_card_dict("ZALUD", "9") if _i == 0 else _make_card_dict("GULA", "D"))
		else:
			round_cycled = true
			var ai_empty_b := 12
			_award_ai_score_immediately(ai_empty_b, "+%s BONUS" % _format_pts_ui(ai_empty_b), Color(1.0, 0.40, 0.40))
			table_status_label3d.text = _tr("Rival emptied their hand (+%s pts)!" % _format_pts_ui(ai_empty_b), "Soupeř dohrál ruku (+%s b.)!" % _format_pts_ui(ai_empty_b))

	if tutorial_mode and tutorial_step < 7:
		player_score = mini(player_score, target_score - 10)
		ai_score = mini(ai_score, target_score - 20)

	_refresh_table_labels()

	var rounds_done := round_cycled and (current_round_num >= MAX_MATCH_ROUNDS)
	var ko_win := (not tutorial_mode) and (ai_hp <= 0)
	var ko_loss := (not tutorial_mode) and (player_hp <= 0)
	var time_up_win := (not tutorial_mode) and rounds_done and (player_score >= ai_score)
	var time_up_loss := (not tutorial_mode) and rounds_done and (ai_score > player_score)

	if ko_win or player_score >= target_score or time_up_win:
		busy_animating = true
		emit_signal("play_sfx_requested", "win")
		_play_sword_execution_finisher(true)
		table_status_label3d.text = ""
		var wager_payout := (100 + duel_sword_bonus_gold) if active_wager_type == "SWORD" else (wager_gold_amount if active_wager_type == "GOLD" else 45)
		match_bonus_gold += wager_payout
		var win_banner_title := _tr("KNOCKOUT! RIVAL SLAIN (0 ♥ HP)", "K.O.! SOUPEŘ PADL (0 ♥ HP)") if ko_win else (_tr("RIVAL EXECUTED BY SWORD OATH!", "SOUPEŘ POPRAVEN PŘÍSAHOU MEČE!") if active_wager_type == "SWORD" else _tr("VICTORY BY THE BLADE", "VÍTĚZSTVÍ ČEPELÍ"))
		var win_banner_sub := _tr("Sword Bet Won! Rival executed (+%dg)!" % wager_payout, "Sázka na Meč vyhrána! (+%dg)" % wager_payout) if active_wager_type == "SWORD" else _tr("Wager Won (+%dg) — Score: %d | %d/%d HP" % [wager_payout, player_score, player_hp, player_max_hp], "Sázka vyhrána (+%dg) — Skóre: %d | %d/%d HP" % [wager_payout, player_score, player_hp, player_max_hp])
		_flash_turn_toast(win_banner_title, win_banner_sub, Color(1.0, 0.34, 0.26) if (active_wager_type == "SWORD" or ko_win) else Color(1.0, 0.84, 0.28), 2.4, true)
		var win_gold := int(active_stage_data.get("gold", 90)) + match_bonus_gold + (15 if (not tutorial_mode and "REL_GREED" in run_active_relics) else 0)
		_show_victory_summary_overlay(wager_payout, win_gold)
		emit_signal("match_won_details", {
			"score": player_score,
			"carry_out_score": player_score,
			"player_hp": player_hp,
			"target_score": target_score,
			"gold_earned": win_gold,
			"duel_gold_delta": duel_gold_delta,
			"best_slam": match_best_slam,
			"stage_idx": int(active_stage_data.get("stage_idx", 0)),
			"era_id": str(active_era.get("id", "stredovek")),
			"endless_ante": active_endless_ante,
			"relic_scales": match_relic_scales.duplicate(),
			"table_relics": run_table_relics.duplicate(),
			"broken_relics": relic_mgr.export_broken_list(),
		})
		emit_signal("battle_won", player_score)
		return true
	if ko_loss or ai_score >= target_score or time_up_loss:
		busy_animating = true
		emit_signal("play_sfx_requested", "lose")
		_play_sword_execution_finisher(false)
		table_status_label3d.text = ""
		var st_g := int(active_stage_data.get("gold", 90))
		_show_defeat_summary_overlay(ko_loss, st_g)
		emit_signal("match_lost_details", {
			"score": player_score,
			"carry_out_score": player_score,
			"player_hp": player_hp,
			"target_score": target_score,
			"stage_gold": st_g,
			"era_id": str(active_era.get("id", "stredovek")),
			"stage_idx": int(active_stage_data.get("stage_idx", 0)),
			"table_relics": run_table_relics.duplicate(),
			"broken_relics": relic_mgr.export_broken_list(),
		})
		var loss_title := _tr("SLAIN IN BATTLE (0 ♥ HP)", "ZABIT V BOJI (0 ♥ HP)") if ko_loss else _tr("DEFEATED — SPOILS GRANTED", "PORÁŽKA — ÚTĚŠNÁ KOŘIST")
		_flash_turn_toast(loss_title, _tr("Carry-Out: %d pts — Witness the Final Blow!" % player_score, "Odnášíš: %d b — Sleduj závěrečný úder!" % player_score), Color(0.95, 0.38, 0.38), 3.6, true)
		return true

	if player_hand.is_empty() or ai_hand.is_empty():
		var finished_r := current_round_num
		var p_won_r := player_hand.is_empty()
		current_round_num = mini(MAX_MATCH_ROUNDS, current_round_num + 1)
		emit_signal("play_sfx_requested", "card_shuffle")
		_deal_new_3d_round()
		busy_animating = false
		is_player_turn = true
		_rebuild_all_3d_hands()
		_refresh_table_labels()
		_play_round_transition_anim(finished_r, current_round_num, p_won_r)
		if not tutorial_mode and finished_r % 3 == 0:
			_open_shop_gate_prompt()
		elif not tutorial_mode:
			turn_stage = TurnStage.CARD_PLAY
			set_camera_view_mode(CameraViewMode.CARDS, true)
	return false

func _play_round_transition_anim(finished_r: int, next_r: int, player_won_round: bool) -> void:
	if is_instance_valid(round_counter_lbl):
		round_counter_lbl.pivot_offset = round_counter_lbl.size * 0.5
		var rtw := round_counter_lbl.create_tween()
		rtw.tween_property(round_counter_lbl, "scale", Vector2(1.55, 1.55), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rtw.tween_property(round_counter_lbl, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var center_gp := discard_pile_root.global_position if is_instance_valid(discard_pile_root) else to_global(Vector3(0.0, 0.85, 0.0))
	var acol := Color(1.0, 0.86, 0.34) if player_won_round else Color(0.96, 0.42, 0.32)
	Fx.ring(self, center_gp + Vector3(0, 0.03, 0), acol, 1.25, 0.65, 0.12, 2.4, 10.0)
	Fx.gold_flakes(self, center_gp + Vector3(0, 0.12, 0), 34, 1.25)
	_trigger_screen_juice(acol, 0.55, 0.52, 0.32)
	if not is_instance_valid(round_transition_overlay) or not is_instance_valid(round_transition_ribbon):
		return
	var pips := ""
	for pi in range(1, MAX_MATCH_ROUNDS + 1):
		pips += ("● " if pi <= next_r else "○ ")
	round_transition_sub_lbl.text = _tr("✦ ROUND %d COMPLETE (0 cards!) — New round starts! ✦" % finished_r, "✦ %d. KOLO DOKONČENO (0 karet!) — Nové kolo začíná! ✦" % finished_r)
	round_transition_sub_lbl.add_theme_color_override("font_color", Color(0.48, 0.96, 0.66) if player_won_round else Color(1.0, 0.58, 0.44))
	round_transition_main_lbl.text = _tr("ROUND %d / %d" % [next_r, MAX_MATCH_ROUNDS], "%d. / %d KOLO" % [next_r, MAX_MATCH_ROUNDS])
	round_transition_pips_lbl.text = pips.strip_edges()
	round_transition_overlay.visible = true
	round_transition_overlay.modulate.a = 0.0
	round_transition_ribbon.pivot_offset = round_transition_ribbon.size * 0.5
	round_transition_ribbon.scale = Vector2(0.08, 0.72)
	if round_transition_tween and round_transition_tween.is_valid():
		round_transition_tween.kill()
	round_transition_tween = create_tween()
	round_transition_tween.set_parallel(true)
	round_transition_tween.tween_property(round_transition_overlay, "modulate:a", 1.0, 0.20)
	round_transition_tween.tween_property(round_transition_ribbon, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	round_transition_tween.chain().tween_interval(1.25)
	round_transition_tween.chain().tween_property(round_transition_overlay, "modulate:a", 0.0, 0.38)
	round_transition_tween.chain().tween_callback(func():
		if is_instance_valid(round_transition_overlay):
			round_transition_overlay.visible = false
	)

func _refresh_table_labels() -> void:
	var s_obj := _get_suit_obj(active_suit_id)
	var extra := ""
	if pending_draw > 0:
		extra = _tr("  |  SEVEN +", "  |  SEDMA +") + str(pending_draw)
	elif pending_skip:
		extra = _tr("  |  ACE (SKIP)", "  |  ESO (STOP)")
	if table_suit_label3d:
		table_suit_label3d.text = s_obj["sym"] + " " + s_obj["name"] + extra
		table_suit_label3d.modulate = s_obj["col"]

	var d_lbl := draw_deck_root.get_node_or_null("DeckCountLabel") as Label3D if draw_deck_root else null
	if d_lbl:
		d_lbl.text = _tr("DECK (%d)", "BALÍČEK (%d)") % deck.size()

	var p_lbl := magic_puf_bottle.get_node_or_null("PufLabel") as Label3D if magic_puf_bottle else null
	if p_lbl:
		p_lbl.visible = puf_revealed and (not _is_hand_tucked())
		p_lbl.text = "IGNIS (%d×)" % puf_charges
	_sync_peek_ui_visibility()

	if player_liquid_bar:
		player_liquid_bar.queue_redraw()
	if player_hp_pill:
		player_hp_pill.visible = false
	_sync_heartbeat_hp_displays(true)
	if carry_out_pill:
		carry_out_pill.visible = false
	_sync_contextual_cancel_btn()
	_refresh_score_ledger_ui()
	_sync_charge_chalice_art(false)
	_check_boss_phase_awakening()
	if score_goal_bar_ctrl:
		score_goal_bar_ctrl.queue_redraw()
	if player_puf_lbl:
		player_puf_lbl.visible = false
	if round_counter_lbl:
		round_counter_lbl.text = _tr("ROUND %d / 6", "%d. / 6 KOLO") % clampi(current_round_num, 1, MAX_MATCH_ROUNDS)
	if bottom_left_status_lbl:
		bottom_left_status_lbl.text = _tr("Cards: %d", "Karty: %d") % player_hand.size()
	if status_coins_lbl:
		status_coins_lbl.text = str(player_available_gold + match_bonus_gold)
	if redraw_action_btn:
		redraw_action_btn.visible = not tutorial_mode
		redraw_action_btn.text = _tr("REDRAW (%d) [M]", "VÝMĚNA (%d) [M]") % redraws_left
		redraw_action_btn.disabled = redraws_left <= 0 or not is_player_turn or busy_animating
		redraw_action_btn.modulate = Color.WHITE if (not redraw_action_btn.disabled) else Color(0.55, 0.55, 0.60, 0.65)
	if sort_hand_bar:
		sort_hand_bar.visible = not tutorial_mode
	if ai_liquid_bar:
		ai_liquid_bar.queue_redraw()
	if ai_cards_lbl:
		var fire_tag := (_tr(" | BURN %d", " | HOŘÍ %d") % rival_burn_turns) if rival_burn_turns > 0 else ""
		ai_cards_lbl.text = _tr("Cards: %d%s", "Karty: %d%s") % [ai_hand.size(), fire_tag]
	if ai_hp_lbl:
		ai_hp_lbl.text = "♥ HP: %d / %d" % [ai_hp, ai_max_hp]
	if hud_shop_btn:
		hud_shop_btn.visible = false

	# Update Staged Combo bar + live Three-Tier Formula Calculator preview
	if stack_action_bar and stack_action_btn:
		var st_cnt := staged_card_indices.size()
		if st_cnt >= 1 and is_player_turn and not busy_animating and not _is_hand_tucked():
			var st_cards: Array = []
			var rem_hand: Array = []
			var raw := 0
			for hi in range(player_hand.size()):
				var hc: Dictionary = player_hand[hi]
				if hi in staged_card_indices:
					st_cards.append(hc)
					raw += int(hc["pts"])
				else:
					rem_hand.append(hc)
			var slam_valid := _is_staged_slam_valid()
			var echo_c := _get_last_echo_card()
			var lead_suit := str(st_cards[st_cards.size() - 1].get("suit", active_suit_id)) if not st_cards.is_empty() else active_suit_id
			var st_flow := (not tutorial_mode) and last_player_play_suit != "" and (lead_suit == last_player_play_suit or (not st_cards.is_empty() and str(st_cards[0].get("rank", "")) == last_player_play_rank))
			var p_ctx := {
				"tutorial_mode": tutorial_mode,
				"tutorial_step": tutorial_step,
				"chosen_suit": lead_suit,
				"prev_suit": active_suit_id,
				"pending_draw_before": pending_draw,
				"pending_skip_before": pending_skip,
				"storm_surge_mult": storm_surge_mult,
				"echo_card": echo_c,
				"relic_scales": match_relic_scales,
				"shop_rerolls": run_shop_rerolls,
				"match_turn_count": match_turn_count + 1,
				"rival_hand_size": ai_hand.size(),
				"boss_mod": active_boss_mod,
				"campaign_difficulty": active_campaign_difficulty,
				"flow_chain": st_flow,
				"target_score": target_score,
				"duel_chalice_mult": duel_chalice_mult,
				"duel_whetstone_stacks": duel_whetstone_stacks,
				"duel_next_xmult": duel_next_xmult,
				"is_preview": true,
				"lang": opts_language,
			}
			var prev_res := ScoreEng.calculate_hand_score(st_cards, relic_mgr.get_effective_passive_relics(run_active_relics), rem_hand, p_ctx)
			var p_chips := int(prev_res["total_chips"])
			var p_flat := float(prev_res["flat_mult"])
			var p_xm := float(prev_res["x_mult_product"])
			var p_eff := float(prev_res["effective_mult"])
			var tot := int(prev_res["final_score"])
			stack_action_bar.visible = true
			if quick_action_bar:
				quick_action_bar.visible = false
			stack_action_btn.disabled = not slam_valid
			if slam_valid:
				var ace_hp_dmg := int(prev_res.get("ace_hp_damage", 0))
				var ace_hp_str := (" | -%d ♥HP" % ace_hp_dmg) if ace_hp_dmg > 0 else ""
				var c_val_disp := int(prev_res.get("card_value", p_chips))
				stack_action_btn.text = "%d × %d = +%s%s [W]" % [c_val_disp, st_cnt, _format_pts_ui(tot), ace_hp_str]
				if hud_combo_revealed:
					_update_combo_hud(_tr("STAGED: %s", "KOMBO: %s") % str(prev_res["slam_name"]).to_upper(), c_val_disp, float(st_cnt), tot, false, 1.0)
			else:
				stack_action_btn.text = _tr("MULLIGAN (%d) — Click REDRAW", "VÝMĚNA (%d) — Klikni VÝMĚNA") % st_cnt
				if hud_combo_revealed:
					_update_combo_hud(_tr("MULLIGAN (%d Cards)", "VÝMĚNA (%d karet)") % st_cnt, raw, 1.0, raw, false, 1.0)
		else:
			stack_action_bar.visible = false
			if quick_action_bar:
				quick_action_bar.visible = is_player_turn and not busy_animating and not _is_hand_tucked()

	# Pop-In Top-Center Crown Callout: shows active Turn & Wager Stake concisely without overlapping!
	if not (busy_animating and (player_score >= target_score or ai_score >= target_score)):
		var next_key := ""
		var t_title := ""
		var t_sub := ""
		var t_col := Color(0.45, 0.94, 0.62)
		var stake_tag := "SWORD" if active_wager_type == "SWORD" else ("IGNIS" if active_wager_type == "ITEM" else ("%dg" % wager_gold_amount))
		var k_sub := _tr(" • COUNTER KING!", " • PŘEBIJ KRÁLEM!") if (not pending_king_challenge.is_empty() and bool(pending_king_challenge.get("from_ai", false))) else ""
		if not is_player_turn:
			next_key = "AI_%s_%d" % [active_wager_type, rival_burn_turns]
			t_title = _tr("RIVAL'S TURN", "TAH SOUPEŘE")
			t_sub = ""
			t_col = Color(1.0, 0.44, 0.16) if rival_burn_turns > 0 else Color(0.92, 0.46, 0.52)
		elif pending_draw > 0:
			next_key = "P_DRAW_%d_%s" % [pending_draw, active_wager_type]
			t_title = _tr("YOUR TURN", "TVŮJ TAH")
			t_sub = ""
			t_col = Color(1.0, 0.54, 0.36)
		elif pending_skip:
			next_key = "P_SKIP_%s" % active_wager_type
			t_title = _tr("YOUR TURN", "TVŮJ TAH")
			t_sub = ""
			t_col = Color(1.0, 0.82, 0.34)
		else:
			next_key = "P_GO_%s_%d_%s" % [active_suit_id, match_turn_count, active_wager_type]
			t_title = _tr("YOUR TURN", "TVŮJ TAH")
			t_sub = ""
			t_col = Color(0.98, 0.90, 0.64)
		if next_key != _last_turn_toast_key:
			_last_turn_toast_key = next_key
			_flash_turn_toast(t_title, t_sub, t_col, 0.85, false)

func _project_world_to_hud(world_pos: Vector3) -> Variant:
	if not is_instance_valid(cam) or not cam.is_inside_tree():
		return null
	if cam.is_position_behind(world_pos):
		return null
	return cam.unproject_position(world_pos)

func _draw_tutorial_callout_arrow(ctrl: Control, target_pt: Vector2, tail_offset: Vector2, label_txt: String, accent: Color) -> void:
	var t := float(Time.get_ticks_msec()) * 0.001
	var bob := sin(t * 4.2) * 5.0
	var dir_v := (target_pt - (target_pt + tail_offset)).normalized()
	var tip := target_pt - dir_v * (6.0 + bob)
	var tail := target_pt + tail_offset - dir_v * bob

	# Outer dark ink shadow + golden-ink shaft
	ctrl.draw_line(tail, tip, Color(0.05, 0.04, 0.03, 0.88), 6.0, true)
	ctrl.draw_line(tail, tip, accent, 3.0, true)

	# Arrowhead
	var perp := Vector2(-dir_v.y, dir_v.x)
	var h1 := tip - dir_v * 14.0 + perp * 7.5
	var h2 := tip - dir_v * 14.0 - perp * 7.5
	var head_poly := PackedVector2Array([tip, h1, h2])
	ctrl.draw_colored_polygon(head_poly, accent)
	ctrl.draw_polyline(PackedVector2Array([tip, h1, h2, tip]), Color(0.08, 0.05, 0.03, 0.92), 1.8, true)

	# Compact micro-callout pill at tail
	if label_txt != "":
		var fnt := _get_font(true)
		var fsize := 13
		var txt_sz := fnt.get_string_size(label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var pad := Vector2(10.0, 5.0)
		var box_sz := txt_sz + pad * 2.0
		var box_pos := tail - Vector2(box_sz.x * 0.5, box_sz.y * 0.5)
		var vp_sz := ctrl.size
		box_pos.x = clampf(box_pos.x, 8.0, maxf(8.0, vp_sz.x - box_sz.x - 8.0))
		box_pos.y = clampf(box_pos.y, 8.0, maxf(8.0, vp_sz.y - box_sz.y - 8.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.05, 0.04, 0.94)
		sb.border_color = accent
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		ctrl.draw_style_box(sb, Rect2(box_pos, box_sz))
		ctrl.draw_string(fnt, box_pos + Vector2(pad.x, pad.y + txt_sz.y * 0.78), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1.0, 0.96, 0.84))

func _draw_tutorial_arrow_overlay() -> void:
	if not tutorial_mode or not is_instance_valid(tutorial_arrow_overlay) or not tutorial_arrow_overlay.visible:
		return
	if intro_animating or busy_animating or _is_cinematic_playing():
		return
	var gold := Color(1.0, 0.84, 0.34, 0.96)
	var cyan := Color(0.36, 0.92, 1.0, 0.96)
	var emerald := Color(0.40, 0.96, 0.66, 0.96)
	var crimson := Color(1.0, 0.42, 0.42, 0.96)

	match tutorial_step:
		1:
			if tutorial_substep == 0 and veto_standalone_panel and veto_standalone_panel.visible:
				var vr := veto_standalone_panel.get_global_rect()
				_draw_tutorial_callout_arrow(tutorial_arrow_overlay, Vector2(vr.position.x + vr.size.x * 0.35, vr.end.y + 4.0), Vector2(36.0, 58.0), _tr("Veto Hand [V]", "Vetovat karty [V]"), cyan)
			elif tutorial_substep == 1:
				if cam_view_mode != CameraViewMode.TABLE_ITEMS and is_instance_valid(view_toggle_btn) and view_toggle_btn.visible:
					var br := view_toggle_btn.get_global_rect()
					_draw_tutorial_callout_arrow(tutorial_arrow_overlay, Vector2(br.position.x + br.size.x * 0.5, br.position.y - 4.0), Vector2(0.0, -56.0), _tr("3D Table [TAB]", "3D Stůl [TAB]"), gold)
				elif cam_view_mode == CameraViewMode.TABLE_ITEMS and is_instance_valid(player_sword_root):
					var sp = _project_world_to_hud(player_sword_root.global_position + Vector3(0.0, 0.08, 0.0))
					if sp is Vector2:
						var vp_w := tutorial_arrow_overlay.size.x
						var vp_h := tutorial_arrow_overlay.size.y
						var clamped_sp := Vector2(clampf(sp.x, 120.0, vp_w - 130.0), clampf(sp.y, 90.0, vp_h - 80.0))
						_draw_tutorial_callout_arrow(tutorial_arrow_overlay, clamped_sp, Vector2(-84.0, -68.0), _tr("Click 3D Sword", "Klikni na 3D Meč"), gold)
			elif tutorial_substep == 2 and is_instance_valid(view_toggle_btn) and view_toggle_btn.visible:
				var br2 := view_toggle_btn.get_global_rect()
				_draw_tutorial_callout_arrow(tutorial_arrow_overlay, Vector2(br2.position.x + br2.size.x * 0.5, br2.position.y - 4.0), Vector2(0.0, -56.0), _tr("Back to Cards [TAB]", "Zpět ke kartám [TAB]"), emerald)
		2:
			for i in range(mini(player_hand.size(), player_card_nodes.size())):
				if str(player_hand[i].get("rank", "")) == "10" and is_instance_valid(player_card_nodes[i]):
					var p_pts = _project_world_to_hud(player_card_nodes[i].global_position + Vector3(0.0, 0.075, 0.0))
					if p_pts is Vector2:
						_draw_tutorial_callout_arrow(tutorial_arrow_overlay, p_pts, Vector2(-24.0, -72.0), _tr("Suit & Value", "Hodnota karty"), emerald)
					break
			if player_hud_grp and player_hud_grp.visible:
				var chalice_center := player_hud_grp.global_position + Vector2(80.0, 84.0)
				_draw_tutorial_callout_arrow(tutorial_arrow_overlay, chalice_center + Vector2(0.0, 44.0), Vector2(18.0, 52.0), _tr("Chalice Score", "Body do Kalicha"), gold)
		3:
			for i in range(mini(player_hand.size(), player_card_nodes.size())):
				if str(player_hand[i].get("rank", "")) == "7" and is_instance_valid(player_card_nodes[i]):
					var p7 = _project_world_to_hud(player_card_nodes[i].global_position + Vector3(0.0, 0.075, 0.0))
					if p7 is Vector2:
						_draw_tutorial_callout_arrow(tutorial_arrow_overlay, p7, Vector2(0.0, -76.0), _tr("7 = +2 & 3× pts", "7 = +2 & 3× body"), cyan)
					break
		4:
			var e_idx := 0
			for i in range(mini(player_hand.size(), player_card_nodes.size())):
				if str(player_hand[i].get("rank", "")) == "8" and is_instance_valid(player_card_nodes[i]):
					var p8 = _project_world_to_hud(player_card_nodes[i].global_position + Vector3(0.0, 0.075, 0.0))
					if p8 is Vector2:
						var off_x := -38.0 if e_idx == 0 else 38.0
						_draw_tutorial_callout_arrow(tutorial_arrow_overlay, p8, Vector2(off_x, -74.0), _tr("RMB Stage 8", "Pravý klik [RMB]"), gold)
					e_idx += 1
			if combo_hud_grp and combo_hud_grp.visible:
				var cr := combo_hud_grp.get_global_rect()
				_draw_tutorial_callout_arrow(tutorial_arrow_overlay, Vector2(cr.position.x + cr.size.x * 0.5, cr.end.y + 4.0), Vector2(0.0, 54.0), _tr("Combo Formula", "Vzorec komba"), gold)
		5:
			var a_idx := 0
			for i in range(mini(player_hand.size(), player_card_nodes.size())):
				if str(player_hand[i].get("rank", "")) == "E" and is_instance_valid(player_card_nodes[i]):
					var pe = _project_world_to_hud(player_card_nodes[i].global_position + Vector3(0.0, 0.075, 0.0))
					if pe is Vector2:
						var off_x := -38.0 if a_idx == 0 else 38.0
						_draw_tutorial_callout_arrow(tutorial_arrow_overlay, pe, Vector2(off_x, -74.0), _tr("2× Ace = -4 HP", "2× Eso = -4 HP"), crimson)
					a_idx += 1
			if is_instance_valid(player_hp_heart) and player_hp_heart.visible:
				var hr := player_hp_heart.get_global_rect()
				_draw_tutorial_callout_arrow(tutorial_arrow_overlay, Vector2(hr.end.x + 4.0, hr.position.y + hr.size.y * 0.5), Vector2(76.0, 0.0), _tr("Your Heart (♥ HP)", "Tvoje srdce (♥ HP)"), crimson)
			if is_instance_valid(rival_hp_heart) and rival_hp_heart.visible:
				var rhr := rival_hp_heart.get_global_rect()
				_draw_tutorial_callout_arrow(tutorial_arrow_overlay, Vector2(rhr.position.x + rhr.size.x * 0.5, rhr.end.y + 4.0), Vector2(-24.0, 56.0), _tr("Rival Heart (♥ HP)", "Soupeřovo srdce (♥ HP)"), crimson)
		6:
			if tutorial_substep == 0:
				for i in range(mini(player_hand.size(), player_card_nodes.size())):
					if str(player_hand[i].get("power_id", "")) == "SPEC_VAMPIRE" and is_instance_valid(player_card_nodes[i]):
						var pv = _project_world_to_hud(player_card_nodes[i].global_position + Vector3(0.0, 0.075, 0.0))
						if pv is Vector2:
							_draw_tutorial_callout_arrow(tutorial_arrow_overlay, pv, Vector2(0.0, -78.0), _tr("Special Card", "Speciální karta"), crimson)
						break
			elif tutorial_substep == 1 and is_instance_valid(magic_puf_bottle) and magic_puf_bottle.visible:
				var pf = _project_world_to_hud(magic_puf_bottle.global_position + Vector3(0.0, 0.14, 0.0))
				if pf is Vector2:
					_draw_tutorial_callout_arrow(tutorial_arrow_overlay, pf, Vector2(-72.0, -64.0), _tr("Click IGNIS Phial", "Klikni na Baňku"), gold)
		7:
			if not player_card_nodes.is_empty() and is_instance_valid(player_card_nodes[0]):
				var pl = _project_world_to_hud(player_card_nodes[0].global_position + Vector3(0.0, 0.075, 0.0))
				if pl is Vector2:
					_draw_tutorial_callout_arrow(tutorial_arrow_overlay, pl, Vector2(0.0, -76.0), _tr("Last Card!", "Poslední karta!"), emerald)
			if is_instance_valid(tavern_bell_root) and tavern_bell_root.visible:
				var pb = _project_world_to_hud(tavern_bell_root.global_position + Vector3(0.0, 0.12, 0.0))
				if pb is Vector2:
					_draw_tutorial_callout_arrow(tutorial_arrow_overlay, pb, Vector2(-64.0, -58.0), _tr("Shop every 3rd R", "Obchod každé 3. kolo"), gold)

func _setup_unlock_tip_banner() -> void:
	unlock_tip_panel = PanelContainer.new()
	unlock_tip_panel.name = "UnlockTipBanner"
	unlock_tip_panel.anchor_left = 1.0
	unlock_tip_panel.anchor_top = 0.0
	unlock_tip_panel.anchor_right = 1.0
	unlock_tip_panel.anchor_bottom = 0.0
	unlock_tip_panel.offset_left = -384
	unlock_tip_panel.offset_top = 252
	unlock_tip_panel.offset_right = -16
	unlock_tip_panel.offset_bottom = 384
	unlock_tip_panel.z_index = 28
	unlock_tip_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.05, 0.96)
	sb.border_color = Color(0.94, 0.78, 0.34, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	unlock_tip_panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	unlock_tip_panel.add_child(vb)

	unlock_tip_title_lbl = Label.new()
	unlock_tip_title_lbl.add_theme_font_override("font", _get_font(true))
	unlock_tip_title_lbl.add_theme_font_size_override("font_size", 15)
	unlock_tip_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	vb.add_child(unlock_tip_title_lbl)

	unlock_tip_body_lbl = Label.new()
	unlock_tip_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_tip_body_lbl.custom_minimum_size = Vector2(336, 0)
	unlock_tip_body_lbl.add_theme_font_override("font", _get_font(false))
	unlock_tip_body_lbl.add_theme_font_size_override("font_size", 13)
	unlock_tip_body_lbl.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	vb.add_child(unlock_tip_body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	vb.add_child(btn_row)
	var skip_all_btn := Button.new()
	skip_all_btn.name = "UnlockTipSkipAllBtn"
	skip_all_btn.text = _tr("Skip All", "Přeskočit vše")
	skip_all_btn.custom_minimum_size = Vector2(118, 30)
	skip_all_btn.add_theme_font_override("font", _get_font(true))
	skip_all_btn.add_theme_font_size_override("font_size", 12)
	_style_action_button(skip_all_btn, Color(0.20, 0.12, 0.10, 0.94), Color(0.84, 0.56, 0.34), 10)
	skip_all_btn.pressed.connect(func():
		for q_it in _unlock_tip_queue:
			var qid := str(q_it.get("id", ""))
			if qid != "":
				Catalog.mark_unlock_tip_seen(active_run_profile, qid)
		_unlock_tip_queue.clear()
		_dismiss_unlock_tip()
	)
	btn_row.add_child(skip_all_btn)
	unlock_tip_btn = Button.new()
	unlock_tip_btn.text = _tr("Got it [SPACE]", "Rozumím [SPACE]")
	unlock_tip_btn.custom_minimum_size = Vector2(148, 30)
	unlock_tip_btn.add_theme_font_override("font", _get_font(true))
	unlock_tip_btn.add_theme_font_size_override("font_size", 13)
	_style_action_button(unlock_tip_btn, Color(0.16, 0.24, 0.14, 0.96), Color(0.46, 0.94, 0.62), 10)
	unlock_tip_btn.pressed.connect(_dismiss_unlock_tip)
	btn_row.add_child(unlock_tip_btn)
	hud_root.add_child(unlock_tip_panel)

func _try_show_unlock_tip(tip_id: String, title_en: String, title_cs: String, body_en: String, body_cs: String, accent_col: Color = Color(0.96, 0.80, 0.36)) -> void:
	if tutorial_mode or tip_id == "":
		return
	if active_run_profile.is_empty():
		active_run_profile = Catalog.load_profile()
	if Catalog.has_seen_unlock_tip(active_run_profile, tip_id):
		return
	if _active_unlock_tip_id == tip_id:
		return
	for q_item in _unlock_tip_queue:
		if str(q_item.get("id", "")) == tip_id:
			return
	var tip_data := {
		"id": tip_id,
		"title_en": title_en, "title_cs": title_cs,
		"body_en": body_en, "body_cs": body_cs,
		"col": accent_col,
	}
	if unlock_tip_panel and unlock_tip_panel.visible:
		_unlock_tip_queue.append(tip_data)
		return
	_present_unlock_tip(tip_data)

func _present_unlock_tip(tip_data: Dictionary) -> void:
	if not is_instance_valid(unlock_tip_panel):
		return
	_active_unlock_tip_id = str(tip_data.get("id", ""))
	var acol: Color = tip_data.get("col", Color(0.96, 0.80, 0.36))
	var sb := unlock_tip_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = acol
	unlock_tip_title_lbl.text = _tr(str(tip_data["title_en"]), str(tip_data["title_cs"])) + ((" (%d left)" % _unlock_tip_queue.size()) if (opts_language != "cs" and not _unlock_tip_queue.is_empty()) else ((" (%d další)" % _unlock_tip_queue.size()) if not _unlock_tip_queue.is_empty() else ""))
	unlock_tip_title_lbl.add_theme_color_override("font_color", acol)
	unlock_tip_body_lbl.text = _tr(str(tip_data["body_en"]), str(tip_data["body_cs"]))
	unlock_tip_btn.text = _tr("Got it [SPACE]", "Rozumím [SPACE]")
	unlock_tip_panel.visible = true
	unlock_tip_panel.modulate.a = 0.0
	var tw := unlock_tip_panel.create_tween()
	tw.tween_property(unlock_tip_panel, "modulate:a", 1.0, 0.22)

func _dismiss_unlock_tip() -> void:
	if _active_unlock_tip_id != "":
		Catalog.mark_unlock_tip_seen(active_run_profile, _active_unlock_tip_id)
		_active_unlock_tip_id = ""
	if is_instance_valid(unlock_tip_panel):
		unlock_tip_panel.visible = false
	emit_signal("play_sfx_requested", "ui_click")
	if not _unlock_tip_queue.is_empty():
		var next_tip: Dictionary = _unlock_tip_queue.pop_front()
		_present_unlock_tip(next_tip)

func _check_battle_unlock_tips() -> void:
	if tutorial_mode:
		return
	if active_boss_mod != "":
		_try_show_unlock_tip(
			"unlock_boss_stage",
			"✦ BOSS ENCOUNTER", "✦ SOUBOJ S BOSSEM",
			"Bosses have special rules & an armored Boss Heart! Hover the Boss Plaque on the table for counterplay tips.",
			"Bossové mají speciální pravidla a obrněné Boss Srdce! Najeď myší na plaketu Bosse na stole pro radu.",
			Color(1.0, 0.56, 0.26)
		)
	if not run_table_relics.is_empty():
		_try_show_unlock_tip(
			"unlock_table_relic",
			"✦ TABLETOP RELICS", "✦ STOLNÍ RELIKVIE",
			"3D Relics sit on the table! Press [TAB] to inspect them or click active ones for bonuses (max 3 uses!).",
			"3D Relikvie leží na stole! Klávesou [TAB] si je prohlédni a aktivuj bonusy (max 3 použití!).",
			Color(0.46, 0.88, 1.0)
		)
	for hc in player_hand:
		var pid := str(hc.get("power_id", ""))
		if pid != "":
			var pc_en := Catalog.get_power_card_loc(pid, "en")
			var pc_cs := Catalog.get_power_card_loc(pid, "cs")
			var nm_en := str(pc_en.get("name", pid))
			var nm_cs := str(pc_cs.get("name", pid))
			var d_en := str(pc_en.get("desc", pc_en.get("power_line", "Special Power Card!")))
			var d_cs := str(pc_cs.get("desc", pc_cs.get("power_line", "Speciální Mocná karta!")))
			var pcol: Color = hc.get("accent", pc_en.get("accent", Color(1.0, 0.38, 0.52)))
			_try_show_unlock_tip(
				"unlock_spec_" + pid,
				"✦ " + nm_en.to_upper(), "✦ " + nm_cs.to_upper(),
				d_en,
				d_cs,
				pcol
			)
		var ed := Catalog.normalize_card_class(str(hc.get("edition", "NORMAL")))
		match ed:
			"MAGE":
				_try_show_unlock_tip("unlock_edition_mage", "✦ MAGE EDITION CARD", "✦ EDICE MÁG", "Mage cards charge up while held in your hand — hold them to amplify their power!", "Karty Mága se nabíjí, dokud je držíš v ruce — podrž je pro silnější efekt!", Color(0.42, 0.84, 1.0))
			"KNIGHT":
				_try_show_unlock_tip("unlock_edition_knight", "✦ KNIGHT EDITION CARD", "✦ EDICE RYTÍŘ", "Knight cards grant protective Shields and armored synergy against Rival attacks!", "Karty Rytíře dávají ochranné Štíty a brání tě proti útokům soupeře!", Color(0.74, 0.86, 1.0))
			"MERCHANT":
				_try_show_unlock_tip("unlock_edition_merchant", "✦ MERCHANT EDITION CARD", "✦ EDICE KUPEC", "Merchant cards mine bonus Florins (Gold) when played so you can afford Forge upgrades!", "Karty Kupce těží bonusové Zlaťáky při zahrání pro nákupy v Kovárně!", Color(1.0, 0.84, 0.30))
			"THIEF":
				_try_show_unlock_tip("unlock_edition_thief", "✦ THIEF EDITION CARD", "✦ EDICE ZLODĚJ", "Thief cards siphon points or steal tempo directly from your Rival!", "Karty Zloděje kradou body nebo tempo přímo od soupeře!", Color(0.86, 0.48, 1.0))
		var r := str(hc.get("rank", ""))
		match r:
			"7":
				_try_show_unlock_tip("unlock_rank_7", "✦ SEVEN (7) — BLOOD TAX +2", "✦ SEDMA (7) — KRVAVÁ DAŇ +2", "Forces the Rival to draw +2 cards (stacks +2/+4/+6 if countered with another 7)!", "Přinutí soupeře líznout +2 karty (řetězí se +2/+4/+6, pokud ji přebije další 7)!", Color(1.0, 0.34, 0.28))
			"8":
				_try_show_unlock_tip("unlock_rank_8", "✦ EIGHT (8) — COMBO CHAIN", "✦ OSMA (8) — ŘETĚZOVÉ KOMBO", "Right-click multiple 8s in your hand to stage & slam a massive multi-card combo!", "Pravým tlačítkem naklikni více Osmiček v ruce a zahraj drtivé kombo!", Color(0.36, 0.88, 1.0))
			"9":
				_try_show_unlock_tip("unlock_rank_9", "✦ NINE (9) — ARCANE CHARGE", "✦ DEVÍTKA (9) — MAGICKÉ NABITÍ", "Playing a 9 charges all Mage cards in your hand and grants +1 Redraw!", "Zahrání Devítky (9) nabije všechny karty Mága v ruce a přidá +1 Výměnu (Redraw)!", Color(0.44, 0.86, 1.0))
			"10":
				_try_show_unlock_tip("unlock_rank_10", "✦ TEN (10) — FLORIN MINT", "✦ DESÍTKA (10) — ZLAŤÁKOVÁ RAŽBA", "Playing a 10 mints +10 Gold (Florins) into your pouch for the Shop!", "Zahrání Desítky (10) ti přidá +10 Zlaťáků do měšce na nákupy v Obchodě!", Color(1.0, 0.84, 0.30))
			"D":
				_try_show_unlock_tip("unlock_rank_D", "✦ JACK (D) — GUARD SHIELD", "✦ SPODEK (D) — OCHRANNÝ ŠTÍT", "Playing a Jack (D) grants +1 Guard Shield that blocks incoming ♥ HP damage!", "Zahrání Spodka (D) přidá +1 Ochranný štít, který vykryje příchozí zranění ♥ HP!", Color(0.72, 0.88, 1.0))
			"H":
				_try_show_unlock_tip("unlock_rank_H", "✦ QUEEN (H) — WILD SUIT", "✦ SVRŠEK (H) — ZMĚNA BARVY", "Queen (H) is Wild! Play it on any card (except an unblocked 7) to choose the new active Suit.", "Svršek (H) je žolík! Zahraj ho na cokoliv (mimo neblokované 7) a zvol novou barvu.", Color(0.96, 0.56, 0.92))
			"K":
				_try_show_unlock_tip("unlock_rank_K", "✦ KING (K) — KING CHALLENGE", "✦ KRÁL (K) — KRÁLOVSKÁ VÝZVA", "Playing a King (K) launches a King Challenge dealing 1–3 ♥ HP damage to your Rival!", "Zahrání Krále (K) spustí Královskou výzvu za 1–3 ♥ HP poškození soupeři!", Color(1.0, 0.44, 0.36))
			"E":
				_try_show_unlock_tip("unlock_rank_E_triple", "✦ TRIPLE ACE — INSTANT KILL!", "✦ 3× ESO — OKAMŽITÁ SMRT!", "Stack 3 Aces (E) in one combo for an Instant Kill! In Multiplayer, it kills your chosen target!", "Spoj 3 Esa (E) do jednoho komba pro Okamžitou smrt! V Multiplayeru zabije zvoleného soupeře!", Color(1.0, 0.32, 0.36))

func _on_battle_viewport_resized() -> void:
	_layout_tutorial_ghost_center_panel(0.0)
	if is_instance_valid(card_guide_modal) and card_guide_modal.visible:
		_layout_card_guide_panel()

func _layout_card_guide_panel() -> void:
	if not is_instance_valid(card_guide_modal):
		return
	var panel := card_guide_modal.get_node_or_null("CardGuidePanel") as PanelContainer
	if not panel:
		return
	var vp_sz := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1366, 768)
	var pw := clampf(vp_sz.x - 80.0, 520.0, 780.0)
	var ph := clampf(vp_sz.y - 72.0, 420.0, 620.0)
	panel.offset_left = -pw * 0.5
	panel.offset_right = pw * 0.5
	panel.offset_top = -ph * 0.5
	panel.offset_bottom = ph * 0.5

func _setup_card_guide_modal() -> void:
	card_guide_modal = Control.new()
	card_guide_modal.name = "CardGuideModal"
	card_guide_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_guide_modal.z_index = 45
	card_guide_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	card_guide_modal.visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.015, 0.012, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_toggle_card_guide_modal(false)
			get_viewport().set_input_as_handled()
	)
	card_guide_modal.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "CardGuidePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.058, 0.046, 0.98)
	sb.border_color = Color(0.88, 0.70, 0.32, 0.96)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	sb.shadow_size = 18
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	card_guide_modal.add_child(panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	panel.add_child(root_vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	root_vb.add_child(hdr)

	card_guide_title_lbl = Label.new()
	card_guide_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_guide_title_lbl.add_theme_font_override("font", _get_font(true))
	card_guide_title_lbl.add_theme_font_size_override("font_size", 20)
	card_guide_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	hdr.add_child(card_guide_title_lbl)

	var close_btn := Button.new()
	close_btn.text = ""
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.add_theme_font_override("font", _get_font(true))
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(0.98, 0.86, 0.50))
	_style_action_button(close_btn, Color(0.14, 0.09, 0.07, 0.96), Color(0.88, 0.68, 0.28), 10)
	close_btn.pressed.connect(func():
		_toggle_card_guide_modal(false)
	)
	hdr.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vb.add_child(scroll)

	card_guide_scroll_vb = VBoxContainer.new()
	card_guide_scroll_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_guide_scroll_vb.add_theme_constant_override("separation", 14)
	scroll.add_child(card_guide_scroll_vb)

	hud_root.add_child(card_guide_modal)
	_setup_round_transition_overlay()

func _setup_round_transition_overlay() -> void:
	round_transition_overlay = Control.new()
	round_transition_overlay.name = "RoundTransitionOverlay"
	round_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	round_transition_overlay.z_index = 36
	round_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_transition_overlay.visible = false

	round_transition_ribbon = PanelContainer.new()
	round_transition_ribbon.anchor_left = 0.5
	round_transition_ribbon.anchor_top = 0.5
	round_transition_ribbon.anchor_right = 0.5
	round_transition_ribbon.anchor_bottom = 0.5
	round_transition_ribbon.offset_left = -270
	round_transition_ribbon.offset_top = -68
	round_transition_ribbon.offset_right = 270
	round_transition_ribbon.offset_bottom = 68
	round_transition_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _make_plaque_style(Color(0.06, 0.042, 0.032, 0.96), Color(0.96, 0.78, 0.32, 0.96), 16)
	sb.set_border_width_all(3)
	sb.content_margin_left = 26; sb.content_margin_right = 26
	sb.content_margin_top = 14; sb.content_margin_bottom = 14
	round_transition_ribbon.add_theme_stylebox_override("panel", sb)
	round_transition_overlay.add_child(round_transition_ribbon)

	var rvb := VBoxContainer.new()
	rvb.alignment = BoxContainer.ALIGNMENT_CENTER
	rvb.add_theme_constant_override("separation", 4)
	rvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_transition_ribbon.add_child(rvb)

	round_transition_sub_lbl = Label.new()
	round_transition_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_transition_sub_lbl.add_theme_font_override("font", _get_font(true))
	round_transition_sub_lbl.add_theme_font_size_override("font_size", 15)
	round_transition_sub_lbl.add_theme_color_override("font_color", Color(0.54, 0.96, 0.68))
	round_transition_sub_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01))
	round_transition_sub_lbl.add_theme_constant_override("outline_size", 5)
	rvb.add_child(round_transition_sub_lbl)

	round_transition_main_lbl = Label.new()
	round_transition_main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_transition_main_lbl.add_theme_font_override("font", _get_font(true))
	round_transition_main_lbl.add_theme_font_size_override("font_size", 32)
	round_transition_main_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.44))
	round_transition_main_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01))
	round_transition_main_lbl.add_theme_constant_override("outline_size", 8)
	rvb.add_child(round_transition_main_lbl)

	round_transition_pips_lbl = Label.new()
	round_transition_pips_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_transition_pips_lbl.add_theme_font_override("font", _get_font(true))
	round_transition_pips_lbl.add_theme_font_size_override("font_size", 14)
	round_transition_pips_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.36))
	rvb.add_child(round_transition_pips_lbl)

	hud_root.add_child(round_transition_overlay)

func _add_guide_section_header(parent_vb: VBoxContainer, title_txt: String, accent: Color) -> void:
	var lbl := Label.new()
	lbl.text = title_txt
	lbl.add_theme_font_override("font", _get_font(true))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", accent)
	parent_vb.add_child(lbl)

func _add_guide_row(parent_vb: VBoxContainer, badge_txt: String, desc_txt: String, badge_col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent_vb.add_child(row)

	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(128, 0)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(badge_col.r * 0.22, badge_col.g * 0.22, badge_col.b * 0.22, 0.92)
	psb.border_color = Color(badge_col.r, badge_col.g, badge_col.b, 0.72)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(6)
	psb.content_margin_left = 8; psb.content_margin_right = 8
	psb.content_margin_top = 4; psb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", psb)
	row.add_child(pill)

	var blbl := Label.new()
	blbl.text = badge_txt
	blbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blbl.add_theme_font_override("font", _get_font(true))
	blbl.add_theme_font_size_override("font_size", 13)
	blbl.add_theme_color_override("font_color", badge_col)
	pill.add_child(blbl)

	var dlbl := Label.new()
	dlbl.text = desc_txt
	dlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlbl.add_theme_font_override("font", _get_font(false))
	dlbl.add_theme_font_size_override("font_size", 13)
	dlbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	row.add_child(dlbl)

func _populate_card_guide_modal() -> void:
	if not is_instance_valid(card_guide_scroll_vb):
		return
	for ch in card_guide_scroll_vb.get_children():
		ch.queue_free()
	if card_guide_title_lbl:
		card_guide_title_lbl.text = _tr("✦ CARD & RULES GUIDE  [F1 / ESC]", "✦ PRŮVODCE KARTAMI A PRAVIDLY  [F1 / ESC]")

	# 1. WIN CONDITIONS
	_add_guide_section_header(card_guide_scroll_vb, _tr("1. WIN CONDITIONS (3 WAYS TO WIN)", "1. PODMÍNKY VÝHRY (3 CESTY K VÍTĚZSTVÍ)"), Color(1.0, 0.84, 0.34))
	_add_guide_row(card_guide_scroll_vb, _tr("0 ♥ HP", "0 ♥ HP"), _tr("Drain Rival's 3D Heart to 0 HP using Kings (1–3 HP), Aces (1/4 HP), or Special Power Cards.", "Sraz soupeřovo 3D Srdce na 0 HP pomocí Králů (1–3 HP), Es (1/4 HP) nebo Mocných karet."), Color(1.0, 0.42, 0.44))
	_add_guide_row(card_guide_scroll_vb, _tr("Chalice Goal", "Cíl Kalicha"), _tr("Reach the target Chalice Score (currently %d pts) by chaining combos & settling turn points." % target_score, "Dosáhni bodového Cíle Kalicha (aktuálně %d b.) řetězením komb a sčítáním bodů." % target_score), Color(0.42, 0.96, 0.72))
	_add_guide_row(card_guide_scroll_vb, _tr("3× Aces KILL", "3× Eso SMRT"), _tr("Play 3 Aces (E) in one combo for an INSTANT KILL! In Multiplayer, kills your chosen target.", "Zahraj 3 Esa (E) v jednom kombu pro OKAMŽITOU SMRT! V Multiplayeru zabije zvolený cíl."), Color(1.0, 0.32, 0.36))
	_add_guide_row(card_guide_scroll_vb, _tr("New Round", "Nové kolo"), _tr("A new round starts whenever ANY player (you or Rival) runs out of cards (0 cards in hand)!", "Nové kolo začíná, jakmile komukoli (tobě nebo soupeři) dojdou karty (0 karet v ruce)!"), Color(0.96, 0.84, 0.44))

	# 2. ALL 8 RANKS & 4 CLASSES
	_add_guide_section_header(card_guide_scroll_vb, _tr("2. ALL 8 RANKS & 4 CARD CLASSES", "2. VŠECH 8 HODNOT A 4 TŘÍDY KARET"), Color(0.42, 0.90, 1.0))
	var rank_rows := [
		["7", _tr("Forces Rival to draw +2 cards & awards 3× points if unblocked.", "Soupeř líže +2 karty a získáš 3× body, pokud ji neblokuje."), Color(0.36, 0.92, 1.0)],
		["8", _tr("Infinite Chain (∞): stack any number of 8s together in one Combo.", "Nekonečné řetězení (∞): spoj libovolný počet Osmiček do komba."), Color(0.98, 0.56, 0.92)],
		["9", _tr("Charges all Mage cards in your hand & grants +1 Redraw.", "Nabije všechny karty Mága v ruce a přidá +1 Výměnu (Redraw)."), Color(0.44, 0.86, 1.0)],
		["10", _tr("Mints +10 Gold (Florins) into your pouch for the Peddler's Shop.", "Přidá +10 Zlaťáků do měšce na nákupy v Kupeckém obchodě."), Color(1.0, 0.84, 0.30)],
		["D (Jack)", _tr("Grants +1 Guard Shield that blocks incoming ♥ HP damage.", "Přidá +1 Ochranný štít, který vykryje příchozí zranění ♥ HP."), Color(0.74, 0.88, 1.0)],
		["H (Queen)", _tr("Wild Suit: play on anything (except unblocked 7) to pick a new Suit.", "Změna barvy: lze hrát na cokoliv (mimo neblokované 7) a zvolit barvu."), Color(0.96, 0.56, 0.92)],
		["K (King)", _tr("Triggers a King Challenge dealing 1–3 ♥ HP damage to Rival.", "Spustí Královskou výzvu za 1–3 ♥ HP poškození soupeři."), Color(1.0, 0.44, 0.36)],
		["E (Ace)", _tr("Stack up to 3 Aces: 1× = 1 HP + Stun, 2× = 4 HP + Stun, 3× = Instant Kill!", "Až 3 Esa v kombu: 1× = 1 HP + Stopka, 2× = 4 HP + Stopka, 3× = Okamžitá smrt!"), Color(1.0, 0.34, 0.38)],
	]
	for rr in rank_rows:
		_add_guide_row(card_guide_scroll_vb, str(rr[0]), str(rr[1]), rr[2])

	var class_rows := [
		[_tr("Mage", "Mág"), _tr("Charges up while held in hand to amplify points & effects.", "Nabíjí se držením v ruce pro silnější body a efekty."), Color(0.42, 0.84, 1.0)],
		[_tr("Knight", "Rytíř"), _tr("Grants protective Shields and armored defense.", "Poskytuje ochranné Štíty a obrněnou obranu."), Color(0.74, 0.86, 1.0)],
		[_tr("Merchant", "Kupec"), _tr("Mines bonus Gold (Florins) for Shop & Forge upgrades.", "Těží bonusové Zlaťáky pro nákupy v Obchodě a Kovárně."), Color(1.0, 0.84, 0.30)],
		[_tr("Thief", "Zloděj"), _tr("Siphons points or steals tempo directly from your Rival.", "Krade body nebo tempo přímo od soupeře."), Color(0.86, 0.48, 1.0)],
	]
	for cr in class_rows:
		_add_guide_row(card_guide_scroll_vb, str(cr[0]), str(cr[1]), cr[2])

	# 3. YOUR CURRENT SPECIAL POWER CARDS & ACTIVE RELICS
	_add_guide_section_header(card_guide_scroll_vb, _tr("3. YOUR SPECIAL POWER CARDS & ACTIVE RELICS", "3. TVOJE MOCNÉ KARTY A AKTIVNÍ RELIKVIE"), Color(0.98, 0.62, 0.38))
	var seen_powers: Dictionary = {}
	var power_ids: Array = []
	for src_arr in [player_hand, deck, discard_pile, run_custom_cards]:
		if src_arr is Array:
			for item in src_arr:
				var pid := str(item.get("power_id", "")) if item is Dictionary else str(item)
				if pid != "" and not seen_powers.has(pid):
					seen_powers[pid] = true
					power_ids.append(pid)
	for pid in power_ids:
		var pc := Catalog.get_power_card_loc(str(pid), opts_language)
		if not pc.is_empty():
			var p_desc := str(pc.get("desc", pc.get("power_line", "")))
			_add_guide_row(card_guide_scroll_vb, str(pc.get("name", pid)), p_desc, Color(1.0, 0.48, 0.60))

	for rid in run_active_relics:
		var r_info := Catalog.get_relic_loc(str(rid), opts_language)
		if not r_info.is_empty():
			_add_guide_row(card_guide_scroll_vb, str(r_info.get("name", rid)), str(r_info.get("desc", "")), Color(0.96, 0.82, 0.38))

	for tid in run_table_relics:
		var t_info := Catalog.get_table_relic_loc(str(tid), opts_language)
		if not t_info.is_empty():
			_add_guide_row(card_guide_scroll_vb, str(t_info.get("name", tid)), str(t_info.get("desc", "")), Color(0.46, 0.88, 1.0))

	if power_ids.is_empty() and run_active_relics.is_empty() and run_table_relics.is_empty():
		_add_guide_row(card_guide_scroll_vb, _tr("None yet", "Zatím žádné"), _tr("Visit the Peddler's Shop (every 3rd round) to buy Special Cards & Relics!", "Navštiv Kupecký obchod (každé 3. kolo) pro nákup Mocných karet a Relikvií!"), Color(0.68, 0.64, 0.58))

func _toggle_bottom_right_drawer(force_state: Variant = null) -> void:
	if not is_instance_valid(bottom_right_drawer):
		return
	var next_open: bool = (not bottom_right_drawer_open) if force_state == null else bool(force_state)
	bottom_right_drawer_open = next_open
	if bottom_right_drawer_tween and bottom_right_drawer_tween.is_valid():
		bottom_right_drawer_tween.kill()
	bottom_right_drawer.pivot_offset = Vector2(bottom_right_drawer.size.x * 0.5, bottom_right_drawer.size.y)
	bottom_right_drawer_tween = create_tween().set_parallel(true)
	if next_open:
		bottom_right_drawer.visible = true
		bottom_right_drawer.scale = Vector2(1.0, 0.10)
		bottom_right_drawer_tween.tween_property(bottom_right_drawer, "modulate:a", 1.0, 0.16)
		bottom_right_drawer_tween.tween_property(bottom_right_drawer, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		bottom_right_drawer_tween.tween_property(bottom_right_drawer, "modulate:a", 0.0, 0.14)
		bottom_right_drawer_tween.tween_property(bottom_right_drawer, "scale", Vector2(1.0, 0.10), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		bottom_right_drawer_tween.chain().tween_callback(func():
			if is_instance_valid(bottom_right_drawer) and not bottom_right_drawer_open:
				bottom_right_drawer.visible = false
				bottom_right_drawer.scale = Vector2.ONE
		)

func _toggle_card_guide_modal(force_state: Variant = null) -> void:
	if not is_instance_valid(card_guide_modal):
		return
	var next_vis: bool = (not card_guide_modal.visible) if force_state == null else bool(force_state)
	if next_vis:
		_populate_card_guide_modal()
		_layout_card_guide_panel()
	card_guide_modal.visible = next_vis
	emit_signal("play_sfx_requested", "ui_click")
