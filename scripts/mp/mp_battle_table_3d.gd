class_name MpBattleTable3D
extends Node3D

## Experimental 2-4 Player Round-Table 3D Arena for Downpour / LIALO.
## Reuses authentic woodcut/hand-drawn cards, SwordCardAnimator (multi-angle strikes),
## FxLib, CameraRecoilSpring, and custom personal decks around a circular tavern table.

const Toon = preload("res://scripts/toon_style.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")
const CamSpring = preload("res://scripts/camera_recoil_spring.gd")
const Fx = preload("res://scripts/fx_lib.gd")
const SwordCardAnim = preload("res://scripts/sword_card_animator.gd")
const BlenderVfx = preload("res://scripts/blender_vfx_animator.gd")
const RelicMesh = preload("res://scripts/relic_mesh_factory.gd")
const HeartbeatHpScript = preload("res://scripts/heartbeat_hp_display.gd")
const Config = preload("res://scripts/mp/mp_config.gd")

const CARD_FX_SHADER := preload("res://shaders/card_fx.gdshader")
const TABLE_INLAY_SHADER := preload("res://shaders/table_cloth.gdshader")
const WOODCUT_POST_SHADER := preload("res://shaders/woodcut_post.gdshader")
const FONT_DISPLAY_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoBody.ttf"

const HAND_POS_UP := Vector3(0.0, 1.24, 1.00)
const HAND_ROT_UP := Vector3(-24.0, 0.0, 0.0)
const HAND_POS_TUCKED := Vector3(0.0, 0.72, 1.48)
const HAND_ROT_TUCKED := Vector3(-54.0, 0.0, 0.0)
const MAX_MP_ITEM_USES: int = 3

const MP_ITEM_MESH_MAP := {
	"MYS_IRON_GAUNTLET": "REL_IRON_BOOT",
	"MYS_WITCH_MIRROR": "TRELIC_HOLLOW_MASK",
	"MYS_BELL_TOLL": "TRELIC_SOUL_BELL",
	"MYS_RUNE_WHETSTONE": "REL_FORGEMASTER",
	"MYS_RAVENS_EYE": "TRELIC_STAR_BOW",
	"MYS_ALCHEMIST_PHIAL": "REL_ALEMBIC",
	"MYS_LANTERN_ASH": "TRELIC_CENSER",
	"MYS_CROWBAR_KEY": "TRELIC_IRON_CHAIN",
}

signal exit_mp_requested
signal play_sfx_requested(sname: String)
signal open_options_requested

var mp_net: Node = null
var cam: Camera3D
var cam_spring: CamSpring
var cam_kick_shake: float = 0.0
var battle_audio_muted: bool = false
var battle_audio_pct: int = 85

var woodcut_layer: CanvasLayer
var woodcut_mat: ShaderMaterial
var hud_layer: CanvasLayer
var hud_root: Control

var discard_pile_root: Node3D
var suit_beacon_lbl: Label3D
var center_banner_lbl: Label
var turn_strip_box: HBoxContainer
var status_info_lbl: Label
var target_bar: HBoxContainer
var hand_bar: HBoxContainer
var items_bar: HBoxContainer
var action_bar: HBoxContainer
var suit_pick_bar: HBoxContainer
var slam_btn: Button
var draw_btn: Button
var parry_panel: PanelContainer
var parry_title_lbl: Label
var parry_timer_lbl: Label
var parry_btns_box: HBoxContainer
var ghost_panel: PanelContainer
var ghost_cd_lbl: Label
var victory_panel: PanelContainer
var victory_lbl: Label

# Campaign-parity FPP 3D hand, tabletop OP items & Campaign HUD
var player_hand_anchor: Node3D
var player_card_nodes: Array[Node3D] = []
var player_glove_left_mesh: Node3D
var player_glove_right_mesh: Node3D
var mp_items_rack_root: Node3D
var mp_item_3d_nodes: Dictionary = {}
var mp_item_uses: Dictionary = {}
var _mp_intro_showcase_done: bool = false
var hovered_card_idx: int = -1
var hovered_item_id: String = ""
var hovered_draw_deck: bool = false
var _last_local_hp: int = 120
var _hover_cache_key: String = ""

var player_hp_heart: Control
var turn_banner_grp: Control
var turn_banner_lbl: Label
var bottom_left_status_pill: PanelContainer
var status_cards_coins_lbl: Label
var target_plaques_box: VBoxContainer
var hover_inspect_panel: PanelContainer
var hover_inspect_title: Label
var hover_inspect_sub: Label
var hover_inspect_desc: Label
var suit_pick_modal: PanelContainer
var _pending_wild_play_indices: Array[int] = []
var _last_mp_round_num: int = -1
var round_transition_overlay: Control = null
var round_transition_ribbon: PanelContainer = null
var round_transition_title_lbl: Label = null
var round_transition_sub_lbl: Label = null
var _round_transition_tween: Tween = null

var public_state: Dictionary = {}
var my_seat: int = 0
var my_hand: Array = []
var my_items: Array = []
var selected_indices: Array[int] = []
var selected_target: int = 1
var chosen_wild_suit: String = "CERVEN"
var local_parry_left: float = 0.0
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var _mp_cursor_pos: Vector2 = Vector2(-1.0, -1.0)
var _mp_anim_t: float = 0.0
var _font_display: Font = null
var _font_body: Font = null
var top_down_manual: bool = false
var _top_down_auto_timer: float = 0.0
var _cam_blend: float = 0.0

var seat_nodes: Dictionary = {} # seat_idx -> {root, avatar, hand_grp, deck_mesh, sword, turn_ring, lbl, hit_area}
var _built_seat_count: int = -1
var _discard_visual_count: int = 0
var _toast_msg: String = ""
var _toast_timer: float = 0.0


func configure(network_node: Node, muted: bool = false, vol_pct: int = 85) -> void:
	mp_net = network_node
	battle_audio_muted = muted
	battle_audio_pct = vol_pct


func _ready() -> void:
	cam_spring = CamSpring.new()
	_ensure_fonts()
	_build_3d_tavern()
	_setup_mp_fpp_hand()
	_build_hud()
	if mp_net != null:
		mp_net.public_state_received.connect(_on_public_state)
		mp_net.private_hand_received.connect(_on_private_hand)
		mp_net.vfx_event_received.connect(_on_vfx_event)
		mp_net.match_ended.connect(_on_match_ended)
		if not mp_net.last_public_state.is_empty():
			_on_public_state(mp_net.last_public_state)
		if not mp_net.last_private_packet.is_empty():
			var lp: Dictionary = mp_net.last_private_packet
			_on_private_hand(int(lp["seat"]), lp["hand"], lp["items"], lp["meta"])


func _exit_tree() -> void:
	if is_instance_valid(woodcut_layer):
		woodcut_layer.queue_free()
	if is_instance_valid(hud_layer):
		hud_layer.queue_free()


func _process(delta: float) -> void:
	if not visible:
		return
	if cam_kick_shake > 0.0:
		cam_kick_shake = maxf(0.0, cam_kick_shake - delta * 2.2)
	cam_spring.step(delta)
	_mp_anim_t += delta

	var active_turn_seat := int(public_state.get("turn_seat", 0))
	var seats_arr: Array = public_state.get("seats", [])
	var my_pub := _get_pub_seat(my_seat)
	var i_am_alive := bool(my_pub.get("alive", true))
	var match_over := bool(public_state.get("match_over", false))
	var modal_open := (is_instance_valid(parry_panel) and parry_panel.visible) or (is_instance_valid(victory_panel) and victory_panel.visible) or (is_instance_valid(suit_pick_modal) and suit_pick_modal.visible)

	# Free camera look-around when >2 players & NOT your turn; smoothly return to static view on your turn!
	var allow_free_look := (seats_arr.size() > 2) and (active_turn_seat != my_seat) and not modal_open and not match_over
	var tgt_yaw := 0.0
	var tgt_pitch := 0.0
	if allow_free_look:
		var vp := get_viewport()
		var vp_s := vp.get_visible_rect().size if vp != null else Vector2(1280, 720)
		if vp_s.x > 10.0 and vp_s.y > 10.0 and _mp_cursor_pos.x >= 0.0:
			var nx := clampf((_mp_cursor_pos.x / vp_s.x) * 2.0 - 1.0, -1.0, 1.0)
			var ny := clampf((_mp_cursor_pos.y / vp_s.y) * 2.0 - 1.0, -1.0, 1.0)
			tgt_yaw = -nx * 62.0
			tgt_pitch = clampf(-ny * 24.0, -24.0, 24.0)
	var cam_rot_speed := 8.5 if allow_free_look else 14.0
	look_yaw = lerpf(look_yaw, tgt_yaw, clampf(delta * cam_rot_speed, 0.0, 1.0))
	look_pitch = lerpf(look_pitch, tgt_pitch, clampf(delta * cam_rot_speed, 0.0, 1.0))

	# Subtle idle breathing & turn highlight animation on sculpted MP characters
	for si_k in seat_nodes.keys():
		var sn: Dictionary = seat_nodes[si_k]
		var tp: Node3D = sn.get("torso_pivot")
		var hp: Node3D = sn.get("head_pivot")
		var is_t := (int(si_k) == active_turn_seat)
		var ph := float(int(si_k)) * 1.45
		if is_instance_valid(tp):
			var base_p: Vector3 = sn.get("torso_base_pos", tp.position)
			tp.position.y = base_p.y + sin(_mp_anim_t * (2.4 if is_t else 1.5) + ph) * 0.008
			tp.rotation_degrees.x = lerpf(tp.rotation_degrees.x, 4.5 if is_t else 0.0, clampf(delta * 5.0, 0.0, 1.0))
		if is_instance_valid(hp):
			hp.rotation_degrees.y = sin(_mp_anim_t * 0.85 + ph) * (6.0 if is_t else 3.5)

	if _top_down_auto_timer > 0.0:
		_top_down_auto_timer = maxf(0.0, _top_down_auto_timer - delta)
	var use_top_down := top_down_manual or (_top_down_auto_timer > 0.0)
	_cam_blend = lerpf(_cam_blend, 1.0 if use_top_down else 0.0, clampf(delta * 6.5, 0.0, 1.0))

	if is_instance_valid(cam):
		var base_pos := Vector3(0.0, 1.78, 1.48).lerp(Vector3(0.0, 2.68, 0.48), _cam_blend)
		var base_pitch := lerpf(-31.0, -74.0, _cam_blend)
		var base_fov := lerpf(70.0, 72.0, _cam_blend)
		var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * cam_kick_shake * 0.025
		cam.position = base_pos + cam_spring.pos_offset + sh
		cam.rotation_degrees = Vector3(clampf(base_pitch + look_pitch + cam_spring.get_pitch_kick(), -84.0, -6.0), look_yaw, cam_spring.rot_offset_deg.z)
		cam.fov = base_fov + cam_spring.get_fov_kick()
		cam_spring.apply_to_camera(cam)

	# First-person 3D hand anchor & gloves matched cleanly to Campaign!
	if is_instance_valid(player_hand_anchor):
		var tuck_hand := use_top_down or (not i_am_alive) or match_over
		var tgt_hp := HAND_POS_TUCKED if tuck_hand else HAND_POS_UP
		var tgt_hr := HAND_ROT_TUCKED if tuck_hand else HAND_ROT_UP
		player_hand_anchor.position = player_hand_anchor.position.lerp(tgt_hp, clampf(10.5 * delta, 0.0, 1.0))
		player_hand_anchor.rotation_degrees = player_hand_anchor.rotation_degrees.lerp(tgt_hr, clampf(10.5 * delta, 0.0, 1.0))
		player_hand_anchor.visible = i_am_alive and not match_over
		if is_instance_valid(player_glove_left_mesh) and is_instance_valid(player_glove_right_mesh):
			var p_lx := -0.24
			var p_rx := 0.24
			if not player_card_nodes.is_empty():
				p_lx = clampf((player_card_nodes[0].get_meta("base_pos", Vector3(-0.16, 0.0, 0.0)) as Vector3).x - 0.095, -0.46, -0.18)
				p_rx = clampf((player_card_nodes[player_card_nodes.size() - 1].get_meta("base_pos", Vector3(0.16, 0.0, 0.0)) as Vector3).x + 0.095, 0.18, 0.46)
			var p_gy := -0.114 if not player_card_nodes.is_empty() else -0.24
			player_glove_left_mesh.position = player_glove_left_mesh.position.lerp(Vector3(p_lx, p_gy + sin(_mp_anim_t * 2.1) * 0.005, 0.014), clampf(10.0 * delta, 0.0, 1.0))
			player_glove_right_mesh.position = player_glove_right_mesh.position.lerp(Vector3(p_rx, p_gy + cos(_mp_anim_t * 2.1) * 0.005, 0.018), clampf(10.0 * delta, 0.0, 1.0))
			player_glove_left_mesh.visible = not player_card_nodes.is_empty()
			player_glove_right_mesh.visible = not player_card_nodes.is_empty()

	# Raycast 3D hand cards, 3D OP items & local 3D deck + hover animations
	_update_mp_hover_and_cursor(delta, modal_open or match_over or (not i_am_alive))

	if local_parry_left > 0.0:
		local_parry_left = maxf(0.0, local_parry_left - delta)
		if is_instance_valid(parry_timer_lbl):
			parry_timer_lbl.text = "⏳ %.1fs TO REACT!" % local_parry_left

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and is_instance_valid(center_banner_lbl):
			center_banner_lbl.text = str(public_state.get("banner", ""))

	# Aim local sword visually toward currently chosen target seat!
	if seat_nodes.has(my_seat) and seat_nodes.has(selected_target):
		var sw: Node3D = seat_nodes[my_seat].get("sword")
		var sroot: Node3D = seat_nodes[my_seat].get("root")
		if is_instance_valid(sw) and is_instance_valid(sroot):
			var tgt_pos := _seat_world_pos(selected_target, 1.05)
			var my_pos := sw.global_position
			var aim_vec := Vector3(tgt_pos.x - my_pos.x, 0.0, tgt_pos.z - my_pos.z)
			if aim_vec.length_squared() > 0.01:
				var desired_local_yaw := atan2(-aim_vec.x, -aim_vec.z) - sroot.rotation.y
				sw.rotation.y = lerp_angle(sw.rotation.y, desired_local_yaw, delta * 9.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_mp_cursor_pos = (event as InputEventMouseMotion).position
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_TAB or k.keycode == KEY_SPACE):
			top_down_manual = not top_down_manual
			play_sfx_requested.emit("card_hover")
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			if is_instance_valid(suit_pick_modal) and suit_pick_modal.visible:
				suit_pick_modal.visible = false
				_pending_wild_play_indices.clear()
				var vp_s := get_viewport()
				if vp_s != null:
					vp_s.set_input_as_handled()
				return
			var modal_open := (is_instance_valid(parry_panel) and parry_panel.visible) or (is_instance_valid(victory_panel) and victory_panel.visible)
			if not modal_open:
				play_sfx_requested.emit("ui_click")
				open_options_requested.emit()
				var vp := get_viewport()
				if vp != null:
					vp.set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		var modal_open := (is_instance_valid(parry_panel) and parry_panel.visible) or (is_instance_valid(victory_panel) and victory_panel.visible) or (is_instance_valid(suit_pick_modal) and suit_pick_modal.visible)
		if modal_open:
			return
		var my_turn: bool = (int(public_state.get("turn_seat", -1)) == my_seat) and public_state.get("pending_parry", {}).is_empty() and bool(_get_pub_seat(my_seat).get("alive", true))
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if my_turn and not top_down_manual and hovered_card_idx >= 0 and hovered_card_idx < my_hand.size():
				_toggle_mp_stage_card(hovered_card_idx)
				var vp_r := get_viewport()
				if vp_r != null:
					vp_r.set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(cam):
			_mp_cursor_pos = mb.position
			if hovered_item_id != "":
				if my_turn and mp_net != null:
					play_sfx_requested.emit("prop_coins")
					mp_net.send_use_item(hovered_item_id, selected_target)
				elif not my_turn:
					_toast_msg = "Wait for your turn to activate tabletop items!"
					_toast_timer = 1.6
					if is_instance_valid(center_banner_lbl):
						center_banner_lbl.text = _toast_msg
				return
			if hovered_draw_deck:
				if my_turn and mp_net != null:
					play_sfx_requested.emit("btn_wooden_slam")
					mp_net.send_draw_card()
				return
			if hovered_card_idx >= 0 and hovered_card_idx < my_hand.size() and not top_down_manual:
				if my_turn:
					_handle_mp_card_left_click(hovered_card_idx)
				return
			_try_click_3d_seat(mb.position)


func _try_click_3d_seat(screen_pos: Vector2) -> void:
	var seats_arr: Array = public_state.get("seats", [])
	var best_seat := -1
	var best_dist := 95.0
	for s in seats_arr:
		var si := int(s["seat_idx"])
		if si == my_seat or not bool(s["alive"]):
			continue
		var wp := _seat_world_pos(si, 1.28) + Vector3(0.0, 0.35, 0.0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var d := sp.distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best_seat = si
	if best_seat != -1:
		selected_target = best_seat
		play_sfx_requested.emit("card_hover")
		_refresh_target_and_actions()


# ---------------------------------------------------------------------------
# 3D Tavern Construction
# ---------------------------------------------------------------------------

func _build_3d_tavern() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.055, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.33, 0.25)
	e.ambient_light_energy = 0.62
	e.glow_enabled = true
	e.glow_intensity = 0.28
	env.environment = e
	add_child(env)

	var key_light := OmniLight3D.new()
	key_light.position = Vector3(0.0, 2.75, 0.10)
	key_light.light_color = Color(1.0, 0.87, 0.66)
	key_light.light_energy = 1.55
	key_light.omni_range = 8.0
	add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(0.0, 2.2, -3.2)
	rim_light.light_color = Color(0.95, 0.68, 0.38)
	rim_light.light_energy = 1.05
	rim_light.omni_range = 7.5
	add_child(rim_light)

	# Oak Round Tavern Table (wider r = 1.56m for comfortable 2-4 player circle)
	var table_wood := MeshInstance3D.new()
	var t_cyl := CylinderMesh.new()
	t_cyl.top_radius = 1.64; t_cyl.bottom_radius = 1.56; t_cyl.height = 0.10; t_cyl.radial_segments = 48
	table_wood.mesh = t_cyl
	table_wood.position = Vector3(0.0, 0.765, 0.0)
	table_wood.material_override = Toon.mat(Color(0.24, 0.15, 0.09), "res://assets/table/wood.png", 0.0, Vector2(2.0, 2.0))
	add_child(table_wood)

	var felt := MeshInstance3D.new()
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 1.48; f_cyl.bottom_radius = 1.48; f_cyl.height = 0.014; f_cyl.radial_segments = 48
	felt.mesh = f_cyl
	felt.position = Vector3(0.0, 0.812, 0.0)
	var f_mat := ShaderMaterial.new()
	f_mat.shader = TABLE_INLAY_SHADER
	f_mat.set_shader_parameter("base_color", Color(0.09, 0.15, 0.13))
	f_mat.set_shader_parameter("accent_color", Color(0.76, 0.58, 0.24))
	felt.material_override = f_mat
	add_child(felt)

	# Tavern Floor + Warm Stone/Timber Medieval Room Enclosure
	var floor_m := MeshInstance3D.new()
	var fl_p := PlaneMesh.new(); fl_p.size = Vector2(14.0, 14.0)
	floor_m.mesh = fl_p
	floor_m.material_override = Toon.mat(Color(0.18, 0.15, 0.14), "res://assets/table/stone_floor.png", 0.0, Vector2(5.0, 5.0))
	add_child(floor_m)

	var stone_wall_mat := Toon.mat(Color(0.24, 0.21, 0.19), "res://assets/table/stone_floor.png", 0.0, Vector2(3.5, 2.0))
	var beam_mat := Toon.mat(Color(0.22, 0.14, 0.08), "res://assets/table/wood.png", 0.0, Vector2(2.5, 1.5))
	var wainscot_mat := Toon.mat(Color(0.17, 0.10, 0.06), "res://assets/table/wood.png", 0.0, Vector2(3.5, 1.0))

	# 4 enclosing stone walls + oak wainscoting + ceiling
	for wspec in [
		{"pos": Vector3(0.0, 2.5, -5.2), "sz": Vector3(11.0, 5.0, 0.35)},
		{"pos": Vector3(0.0, 2.5, 5.2), "sz": Vector3(11.0, 5.0, 0.35)},
		{"pos": Vector3(-5.2, 2.5, 0.0), "sz": Vector3(0.35, 5.0, 10.6)},
		{"pos": Vector3(5.2, 2.5, 0.0), "sz": Vector3(0.35, 5.0, 10.6)},
	]:
		var wm := MeshInstance3D.new()
		var wb := BoxMesh.new(); wb.size = wspec["sz"]
		wm.mesh = wb; wm.position = wspec["pos"]; wm.material_override = stone_wall_mat
		add_child(wm)

	for wainscoting_spec in [
		{"pos": Vector3(0.0, 0.58, -4.96), "sz": Vector3(10.2, 1.16, 0.12)},
		{"pos": Vector3(-4.96, 0.58, 0.0), "sz": Vector3(0.12, 1.16, 10.0)},
		{"pos": Vector3(4.96, 0.58, 0.0), "sz": Vector3(0.12, 1.16, 10.0)},
	]:
		var wsm := MeshInstance3D.new()
		var wsb := BoxMesh.new(); wsb.size = wainscoting_spec["sz"]
		wsm.mesh = wsb; wsm.position = wainscoting_spec["pos"]; wsm.material_override = wainscot_mat
		add_child(wsm)

	# Timber pillars & overhead ceiling crossbeams
	for px in [-3.8, 3.8]:
		for pz in [-4.8, 0.0, 4.8]:
			var pil := MeshInstance3D.new()
			var pb := BoxMesh.new(); pb.size = Vector3(0.34, 4.8, 0.34)
			pil.mesh = pb; pil.position = Vector3(px, 2.4, pz); pil.material_override = beam_mat
			add_child(pil)

	for bz in [-3.6, -1.2, 1.2, 3.6]:
		var cbeam := MeshInstance3D.new()
		var cb := BoxMesh.new(); cb.size = Vector3(10.6, 0.28, 0.30)
		cbeam.mesh = cb; cbeam.position = Vector3(0.0, 4.45, bz); cbeam.material_override = beam_mat
		add_child(cbeam)

	var ceiling := MeshInstance3D.new()
	var cplane := BoxMesh.new(); cplane.size = Vector3(11.2, 0.2, 11.2)
	ceiling.mesh = cplane; ceiling.position = Vector3(0.0, 4.75, 0.0); ceiling.material_override = beam_mat
	add_child(ceiling)

	# Tavern Banners along the walls behind opponents
	var banner_colors := [Color(0.54, 0.12, 0.14), Color(0.14, 0.30, 0.22), Color(0.46, 0.32, 0.10)]
	var banner_positions := [
		{"pos": Vector3(-2.1, 2.75, -4.92), "rot": 0.0, "col": banner_colors[0]},
		{"pos": Vector3(0.0, 2.85, -4.92), "rot": 0.0, "col": banner_colors[2]},
		{"pos": Vector3(2.1, 2.75, -4.92), "rot": 0.0, "col": banner_colors[1]},
		{"pos": Vector3(-4.92, 2.75, -1.8), "rot": 90.0, "col": banner_colors[0]},
		{"pos": Vector3(4.92, 2.75, -1.8), "rot": -90.0, "col": banner_colors[1]},
	]
	for bspec in banner_positions:
		var ban_root := Node3D.new()
		ban_root.position = bspec["pos"]
		ban_root.rotation_degrees.y = float(bspec["rot"])
		var cloth := MeshInstance3D.new()
		var cm := BoxMesh.new(); cm.size = Vector3(0.76, 1.45, 0.03)
		cloth.mesh = cm
		cloth.material_override = Toon.mat(bspec["col"])
		ban_root.add_child(cloth)
		var rod := MeshInstance3D.new()
		var rm := CylinderMesh.new(); rm.top_radius = 0.03; rm.bottom_radius = 0.03; rm.height = 0.92
		rod.mesh = rm; rod.position = Vector3(0.0, 0.74, 0.02); rod.rotation_degrees.z = 90.0
		rod.material_override = Toon.mat(Color(0.78, 0.58, 0.22))
		ban_root.add_child(rod)
		add_child(ban_root)

	# Warm Tavern Wall Lanterns (glowing sconces + warm OmniLight3D fill behind opponents)
	for lpos in [Vector3(-3.2, 2.25, -4.65), Vector3(3.2, 2.25, -4.65), Vector3(-4.65, 2.25, 0.2), Vector3(4.65, 2.25, 0.2)]:
		var lan_bulb := MeshInstance3D.new()
		var lm := SphereMesh.new(); lm.radius = 0.09
		lan_bulb.mesh = lm; lan_bulb.position = lpos
		lan_bulb.material_override = Toon.mat(Color(1.0, 0.80, 0.42), "", 0.0, Vector2.ONE, Color(1.0, 0.65, 0.22) * 2.2)
		add_child(lan_bulb)
		var l_omni := OmniLight3D.new()
		l_omni.position = lpos
		l_omni.light_color = Color(1.0, 0.72, 0.36)
		l_omni.light_energy = 0.85
		l_omni.omni_range = 6.2
		add_child(l_omni)

	# Center Discard Anchor & Suit Indicator
	discard_pile_root = Node3D.new()
	discard_pile_root.position = Vector3(0.0, 0.822, 0.0)
	add_child(discard_pile_root)

	suit_beacon_lbl = Label3D.new()
	suit_beacon_lbl.position = Vector3(0.0, 0.90, -0.26)
	suit_beacon_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	suit_beacon_lbl.font_size = 54
	suit_beacon_lbl.outline_size = 6
	suit_beacon_lbl.pixel_size = 0.0022
	suit_beacon_lbl.text = "♥"
	add_child(suit_beacon_lbl)

	cam = Camera3D.new()
	cam.fov = 60.0
	cam.position = Vector3(0.0, 2.08, 1.98)
	cam.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	add_child(cam)
	cam.current = true

	# Matching Woodcut / PBR Post Shader Layer
	woodcut_layer = CanvasLayer.new()
	woodcut_layer.layer = 3
	var wc := ColorRect.new()
	wc.set_anchors_preset(Control.PRESET_FULL_RECT)
	wc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	woodcut_mat = ShaderMaterial.new()
	woodcut_mat.shader = WOODCUT_POST_SHADER
	woodcut_mat.set_shader_parameter("print_mode", 3)
	wc.material = woodcut_mat
	woodcut_layer.add_child(wc)
	add_child(woodcut_layer)


func _seat_angle_rad(abs_seat: int) -> float:
	var seats_arr: Array = public_state.get("seats", [])
	var n := maxi(2, seats_arr.size())
	var rel := posmod(abs_seat - my_seat, n)
	if rel == 0:
		return 0.0
	if n == 2:
		return PI
	if n == 3:
		return 2.38 if rel == 1 else -2.38
	# N == 4 (pulled slightly back into far semicircle so side labels never clip viewport edges)
	if rel == 1: return 2.02
	if rel == 2: return PI
	return -2.02


func _seat_world_pos(abs_seat: int, radius: float = 1.05) -> Vector3:
	var ang := _seat_angle_rad(abs_seat)
	return global_position + Vector3(sin(ang) * radius, 0.822, cos(ang) * radius)


func _rebuild_seats_if_needed(seats_arr: Array) -> void:
	if _built_seat_count == seats_arr.size():
		return
	for k in seat_nodes.keys():
		var rn: Node3D = seat_nodes[k].get("root")
		if is_instance_valid(rn):
			rn.queue_free()
	seat_nodes.clear()
	_built_seat_count = seats_arr.size()

	for s in seats_arr:
		var si := int(s["seat_idx"])
		var ang := _seat_angle_rad(si)
		var pos_local := Vector3(sin(ang) * 1.06, 0.822, cos(ang) * 1.06)

		var sroot := Node3D.new()
		sroot.name = "MpSeat_%d" % si
		sroot.position = pos_local
		sroot.rotation.y = ang
		add_child(sroot)

		var scol: Color = s.get("color", Color(0.85, 0.68, 0.30))

		# Turn glow ring on felt
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new(); tor.inner_radius = 0.22; tor.outer_radius = 0.255; tor.rings = 24; tor.ring_segments = 8
		ring.mesh = tor
		ring.position = Vector3(0.0, 0.008, 0.0)
		ring.material_override = Toon.mat(scol, "", 0.0, Vector2.ONE, scol * 1.8)
		ring.visible = false
		sroot.add_child(ring)

		var char_id := str(s.get("character_id", ""))
		if char_id == "":
			char_id = str(Config.CHARACTERS[si % Config.CHARACTERS.size()]["id"])
		var deck_back_map := {
			"CHAR_GUILLOTINE": "res://assets/table/deck_back_obsidian.png",
			"CHAR_MONARCH": "res://assets/table/deck_back_stredovek.png",
			"CHAR_JESTER": "res://assets/table/deck_back_prohibicia.png",
			"CHAR_MISTBLADE": "res://assets/table/deck_back_astral.png",
		}
		var seat_back_p := str(deck_back_map.get(char_id, "res://assets/table/card_back.png"))

		# Personal Draw Deck stack to the right of the player (with character's signature card back!)
		var deck_m := MeshInstance3D.new()
		var dbox := BoxMesh.new(); dbox.size = Vector3(0.14, 0.055, 0.20)
		deck_m.mesh = dbox
		deck_m.position = Vector3(0.28, 0.028, 0.06)
		deck_m.material_override = Toon.mat(Color(0.94, 0.92, 0.88), seat_back_p)
		sroot.add_child(deck_m)

		# Seat's Sculpted Blender PBR 3D Sword on the left (or tucked neatly on felt to the right for local player!)
		var sw_skin_id := str(s.get("sword_skin", "SWORD_RUNE"))
		var sw_skin := Catalog.get_sword_skin(sw_skin_id)
		var sword_p := RelicMesh.build_sword_3d_mesh(sw_skin_id, sw_skin)
		if sword_p == null:
			sword_p = Node3D.new()
			var blade_m := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.034, 0.012, 0.44)
			blade_m.mesh = bm; blade_m.position = Vector3(0.0, 0.0, -0.22)
			blade_m.material_override = Toon.mat(sw_skin.get("col", Color(0.75, 0.82, 0.90)))
			sword_p.add_child(blade_m)
		else:
			sword_p.scale = Vector3(0.64, 0.64, 0.64)
		sword_p.position = Vector3(0.46, 0.022, -0.34) if si == my_seat else Vector3(-0.27, 0.024, 0.02)
		sword_p.rotation_degrees = Vector3(0.0, 18.0 if si == my_seat else -8.0, 0.0)
		sroot.add_child(sword_p)

		# Sculpted Blender 5.3 Multiplayer Character Avatar + Dedicated Card-Hold Grip Anchor
		var avatar := Node3D.new()
		avatar.name = "MpAvatar_%d" % si
		avatar.position = Vector3(0.0, 0.0, 0.34)
		avatar.rotation_degrees = Vector3(0.0, 180.0, 0.0) # Face inward toward center of tavern table (-Z in seat local)
		var char_rig := _load_mp_character_glb(char_id, scol)
		avatar.add_child(char_rig)
		avatar.visible = (si != my_seat)
		sroot.add_child(avatar)

		var torso_piv := avatar.find_child("TorsoPivot", true, false) as Node3D
		var head_piv := avatar.find_child("HeadPivot", true, false) as Node3D
		var arm_l_piv := avatar.find_child("ArmLPivot", true, false) as Node3D
		var arm_r_piv := avatar.find_child("ArmRPivot", true, false) as Node3D
		var hand_l_hold := avatar.find_child("HandLHold", true, false) as Node3D
		var hand_r_hold := avatar.find_child("HandRHold", true, false) as Node3D

		var hand_grp := Node3D.new()
		hand_grp.name = "MpHandGrip_%d" % si
		if is_instance_valid(hand_l_hold) and is_instance_valid(hand_r_hold):
			var mid_local := (avatar.to_local(hand_l_hold.global_position) + avatar.to_local(hand_r_hold.global_position)) * 0.5
			# Convert from avatar local (rotated 180° Y at z=0.34) into sroot local cleanly
			hand_grp.position = Vector3(-mid_local.x, mid_local.y + 0.04, 0.34 - mid_local.z)
		else:
			hand_grp.position = Vector3(0.0, 0.27, 0.08)
		sroot.add_child(hand_grp)

		var lbl := Label3D.new()
		lbl.position = Vector3(0.0, 0.08, 0.38)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 20
		lbl.outline_size = 5
		lbl.pixel_size = 0.0018
		lbl.visible = (si != my_seat)
		sroot.add_child(lbl)

		seat_nodes[si] = {
			"root": sroot,
			"avatar": avatar,
			"char_id": char_id,
			"torso_pivot": torso_piv,
			"torso_base_pos": torso_piv.position if is_instance_valid(torso_piv) else Vector3.ZERO,
			"head_pivot": head_piv,
			"arm_l_pivot": arm_l_piv,
			"arm_r_pivot": arm_r_piv,
			"hand_l_hold": hand_l_hold,
			"hand_r_hold": hand_r_hold,
			"hand_grp": hand_grp,
			"deck_mesh": deck_m,
			"sword": sword_p,
			"turn_ring": ring,
			"lbl": lbl,
		}


# ---------------------------------------------------------------------------
# HUD & Controls (MP Test Strip, Cards, Items, Parry, Ghost, Victory)
# ---------------------------------------------------------------------------

func _ensure_fonts() -> void:
	if _font_display == null and ResourceLoader.exists(FONT_DISPLAY_PATH):
		_font_display = ResourceLoader.load(FONT_DISPLAY_PATH) as Font
	if _font_body == null and ResourceLoader.exists(FONT_BODY_PATH):
		_font_body = ResourceLoader.load(FONT_BODY_PATH) as Font


func _apply_font(ctrl: Control, is_display: bool = false) -> void:
	var f := _font_display if is_display else _font_body
	if f != null:
		ctrl.add_theme_font_override("font", f)


func _make_tavern_panel_sb(bg: Color, border: Color, border_w: int = 2, radius: int = 12, pad: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.border_width_bottom = border_w + 2
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(6, pad - 4)
	sb.content_margin_bottom = maxi(6, pad - 4)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _style_tavern_btn(btn: Button, bg: Color, border: Color, is_display: bool = false, radius: int = 9) -> void:
	_apply_font(btn, is_display)
	var sb_n := _make_tavern_panel_sb(bg, border, 2, radius, 12)
	sb_n.content_margin_top = 6
	sb_n.content_margin_bottom = 7
	var sb_h := _make_tavern_panel_sb(bg.lightened(0.16), border.lightened(0.24), 2, radius, 12)
	sb_h.content_margin_top = 6
	sb_h.content_margin_bottom = 7
	var sb_p := _make_tavern_panel_sb(bg.darkened(0.20), border, 2, radius, 12)
	sb_p.border_width_top = 1
	sb_p.border_width_bottom = 2
	sb_p.content_margin_top = 8
	sb_p.content_margin_bottom = 5
	var sb_d := _make_tavern_panel_sb(Color(0.08, 0.07, 0.06, 0.72), Color(0.32, 0.26, 0.18, 0.45), 1, radius, 12)
	sb_d.content_margin_top = 6
	sb_d.content_margin_bottom = 7
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("disabled", sb_d)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.80))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.56))
	btn.add_theme_color_override("font_disabled_color", Color(0.52, 0.48, 0.42, 0.7))


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# Hidden container keeping legacy compatibility nodes alive without cluttering the Campaign HUD
	var legacy_hidden := Control.new()
	legacy_hidden.visible = false
	legacy_hidden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(legacy_hidden)
	target_bar = HBoxContainer.new()
	items_bar = HBoxContainer.new()
	suit_pick_bar = HBoxContainer.new()
	hand_bar = HBoxContainer.new()
	action_bar = HBoxContainer.new()
	for lc in [target_bar, items_bar, suit_pick_bar, hand_bar, action_bar]:
		legacy_hidden.add_child(lc)

	# Top-Left: Campaign Heartbeat HP Plaque
	player_hp_heart = HeartbeatHpScript.new()
	player_hp_heart.position = Vector2(18, 16)
	player_hp_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(player_hp_heart)
	player_hp_heart.call("setup", _font_display, false, false)

	# Top-Center Compact Status Strip + Banner (Matches Campaign top strip cleanly)
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.5; top_panel.anchor_right = 0.5
	top_panel.offset_left = -250; top_panel.offset_right = 250; top_panel.offset_top = 12; top_panel.offset_bottom = 54
	top_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.06, 0.045, 0.90), Color(0.72, 0.54, 0.24, 0.82), 2, 10, 8))
	hud_root.add_child(top_panel)

	var top_hb := HBoxContainer.new()
	top_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hb.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_hb)

	status_info_lbl = Label.new()
	status_info_lbl.text = "♥ Srdce  •  R1"
	_apply_font(status_info_lbl, true)
	status_info_lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.68))
	status_info_lbl.add_theme_font_size_override("font_size", 15)
	top_hb.add_child(status_info_lbl)

	turn_strip_box = HBoxContainer.new()
	turn_strip_box.add_theme_constant_override("separation", 8)
	top_hb.add_child(turn_strip_box)

	# Center Action Banner directly under compact status pill
	center_banner_lbl = Label.new()
	center_banner_lbl.anchor_left = 0.20; center_banner_lbl.anchor_right = 0.80
	center_banner_lbl.offset_top = 60; center_banner_lbl.offset_bottom = 94
	center_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(center_banner_lbl, true)
	center_banner_lbl.add_theme_font_size_override("font_size", 16)
	center_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.64))
	center_banner_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03, 0.95))
	center_banner_lbl.add_theme_constant_override("outline_size", 5)
	center_banner_lbl.add_theme_stylebox_override("normal", _make_tavern_panel_sb(Color(0.07, 0.05, 0.04, 0.72), Color(0.66, 0.50, 0.24, 0.45), 1, 9, 8))
	center_banner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(center_banner_lbl)

	# Top-Right: Clickable Rival Duelist Plaques (Pick target cleanly!)
	target_plaques_box = VBoxContainer.new()
	target_plaques_box.anchor_left = 1.0; target_plaques_box.anchor_right = 1.0
	target_plaques_box.offset_left = -318; target_plaques_box.offset_right = -16
	target_plaques_box.offset_top = 14; target_plaques_box.offset_bottom = 260
	target_plaques_box.add_theme_constant_override("separation", 6)
	hud_root.add_child(target_plaques_box)

	# Bottom-Left: Exact Campaign Stack (Turn Banner -> Cards · Gold -> Leave & Draw)
	turn_banner_grp = PanelContainer.new()
	turn_banner_grp.anchor_left = 0.0; turn_banner_grp.anchor_top = 1.0
	turn_banner_grp.anchor_right = 0.0; turn_banner_grp.anchor_bottom = 1.0
	turn_banner_grp.offset_left = 18; turn_banner_grp.offset_top = -152
	turn_banner_grp.offset_right = 388; turn_banner_grp.offset_bottom = -96
	(turn_banner_grp as PanelContainer).add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.10, 0.07, 0.05, 0.94), Color(0.92, 0.72, 0.28, 0.92), 2, 10, 8))
	turn_banner_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(turn_banner_grp)

	turn_banner_lbl = Label.new()
	turn_banner_lbl.text = "⚔ YOUR TURN"
	turn_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(turn_banner_lbl, true)
	turn_banner_lbl.add_theme_font_size_override("font_size", 18)
	turn_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
	turn_banner_grp.add_child(turn_banner_lbl)

	bottom_left_status_pill = PanelContainer.new()
	bottom_left_status_pill.anchor_left = 0.0; bottom_left_status_pill.anchor_top = 1.0
	bottom_left_status_pill.anchor_right = 0.0; bottom_left_status_pill.anchor_bottom = 1.0
	bottom_left_status_pill.offset_left = 18; bottom_left_status_pill.offset_top = -90
	bottom_left_status_pill.offset_right = 248; bottom_left_status_pill.offset_bottom = -54
	bottom_left_status_pill.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.06, 0.045, 0.92), Color(0.68, 0.52, 0.24, 0.84), 2, 8, 6))
	bottom_left_status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_left_status_pill)

	status_cards_coins_lbl = Label.new()
	status_cards_coins_lbl.text = "Cards: 0  ·  💰 25g"
	status_cards_coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_cards_coins_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_font(status_cards_coins_lbl, true)
	status_cards_coins_lbl.add_theme_font_size_override("font_size", 14)
	status_cards_coins_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68))
	bottom_left_status_pill.add_child(status_cards_coins_lbl)

	var exit_btn := Button.new()
	exit_btn.name = "MpLeaveBtn"
	exit_btn.text = "← Leave"
	exit_btn.anchor_left = 0.0; exit_btn.anchor_top = 1.0
	exit_btn.anchor_right = 0.0; exit_btn.anchor_bottom = 1.0
	exit_btn.offset_left = 18; exit_btn.offset_top = -48
	exit_btn.offset_right = 118; exit_btn.offset_bottom = -12
	_style_tavern_btn(exit_btn, Color(0.24, 0.11, 0.09, 0.95), Color(0.78, 0.40, 0.26, 0.88), true, 8)
	exit_btn.pressed.connect(func(): exit_mp_requested.emit())
	hud_root.add_child(exit_btn)

	draw_btn = Button.new()
	draw_btn.name = "MpDrawBtn"
	draw_btn.text = "🃏 DRAW"
	draw_btn.anchor_left = 0.0; draw_btn.anchor_top = 1.0
	draw_btn.anchor_right = 0.0; draw_btn.anchor_bottom = 1.0
	draw_btn.offset_left = 126; draw_btn.offset_top = -48
	draw_btn.offset_right = 290; draw_btn.offset_bottom = -12
	draw_btn.add_theme_font_size_override("font_size", 14)
	_style_tavern_btn(draw_btn, Color(0.15, 0.13, 0.10, 0.95), Color(0.68, 0.54, 0.28, 0.88), true, 8)
	draw_btn.pressed.connect(func():
		play_sfx_requested.emit("btn_wooden_slam")
		if mp_net:
			mp_net.send_draw_card()
	)
	hud_root.add_child(draw_btn)

	# Bottom-Center Compact Staged Combo SLAM Pill (only shown when cards are right-click staged!)
	slam_btn = Button.new()
	slam_btn.anchor_left = 0.5; slam_btn.anchor_right = 0.5
	slam_btn.anchor_top = 1.0; slam_btn.anchor_bottom = 1.0
	slam_btn.offset_left = -125; slam_btn.offset_right = 125
	slam_btn.offset_top = -56; slam_btn.offset_bottom = -14
	slam_btn.text = "⚔ SLAM (0)"
	slam_btn.visible = false
	slam_btn.add_theme_font_size_override("font_size", 15)
	_style_tavern_btn(slam_btn, Color(0.32, 0.14, 0.08, 0.96), Color(0.94, 0.72, 0.24, 0.94), true, 10)
	slam_btn.pressed.connect(_on_slam_pressed)
	hud_root.add_child(slam_btn)

	# Bottom-Right Hover Inspect Panel (Campaign parity!)
	hover_inspect_panel = PanelContainer.new()
	hover_inspect_panel.anchor_left = 1.0; hover_inspect_panel.anchor_top = 1.0
	hover_inspect_panel.anchor_right = 1.0; hover_inspect_panel.anchor_bottom = 1.0
	hover_inspect_panel.offset_left = -336; hover_inspect_panel.offset_top = -156
	hover_inspect_panel.offset_right = -16; hover_inspect_panel.offset_bottom = -16
	hover_inspect_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.06, 0.045, 0.94), Color(0.76, 0.58, 0.26, 0.88), 2, 10, 10))
	hover_inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_inspect_panel.visible = false
	hud_root.add_child(hover_inspect_panel)
	var hvb := VBoxContainer.new()
	hvb.add_theme_constant_override("separation", 4)
	hvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_inspect_panel.add_child(hvb)
	hover_inspect_title = Label.new()
	_apply_font(hover_inspect_title, true)
	hover_inspect_title.add_theme_font_size_override("font_size", 16)
	hover_inspect_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.54))
	hvb.add_child(hover_inspect_title)
	hover_inspect_sub = Label.new()
	_apply_font(hover_inspect_sub, false)
	hover_inspect_sub.add_theme_font_size_override("font_size", 13)
	hover_inspect_sub.add_theme_color_override("font_color", Color(0.76, 0.88, 0.96))
	hvb.add_child(hover_inspect_sub)
	hover_inspect_desc = Label.new()
	_apply_font(hover_inspect_desc, false)
	hover_inspect_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_inspect_desc.add_theme_font_size_override("font_size", 13)
	hover_inspect_desc.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	hvb.add_child(hover_inspect_desc)

	# Centered Campaign-Style Wild / Queen Suit Picker Modal
	suit_pick_modal = PanelContainer.new()
	suit_pick_modal.anchor_left = 0.5; suit_pick_modal.anchor_right = 0.5
	suit_pick_modal.anchor_top = 0.5; suit_pick_modal.anchor_bottom = 0.5
	suit_pick_modal.offset_left = -220; suit_pick_modal.offset_right = 220
	suit_pick_modal.offset_top = -100; suit_pick_modal.offset_bottom = 100
	suit_pick_modal.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.09, 0.065, 0.045, 0.97), Color(0.92, 0.72, 0.26, 0.96), 3, 14, 14))
	suit_pick_modal.visible = false
	hud_root.add_child(suit_pick_modal)
	var sp_vb := VBoxContainer.new()
	sp_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	sp_vb.add_theme_constant_override("separation", 10)
	suit_pick_modal.add_child(sp_vb)
	var sp_lbl := Label.new()
	sp_lbl.text = "✦ CHOOSE ACTIVE SUIT ✦"
	sp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(sp_lbl, true)
	sp_lbl.add_theme_font_size_override("font_size", 18)
	sp_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
	sp_vb.add_child(sp_lbl)
	var sp_grid := GridContainer.new()
	sp_grid.columns = 2
	sp_grid.add_theme_constant_override("h_separation", 10)
	sp_grid.add_theme_constant_override("v_separation", 10)
	sp_vb.add_child(sp_grid)
	for s in Config.SUITS:
		var sid := str(s["id"])
		var sb := Button.new()
		sb.text = "%s %s" % [s["sym"], s["name"]]
		sb.icon = Toon.tex("res://assets/ui/suits/suit_%s.png" % sid.to_lower())
		sb.expand_icon = true
		sb.custom_minimum_size = Vector2(186, 48)
		_style_tavern_btn(sb, Color(0.14, 0.11, 0.08, 0.96), s.get("col", Color(0.76, 0.58, 0.24)), true, 9)
		sb.pressed.connect(func():
			play_sfx_requested.emit("card_suit_shift")
			chosen_wild_suit = sid
			suit_pick_modal.visible = false
			var to_play := _pending_wild_play_indices.duplicate()
			_pending_wild_play_indices.clear()
			if not to_play.is_empty() and mp_net != null:
				mp_net.send_play_cards(to_play, selected_target, chosen_wild_suit)
		)
		sp_grid.add_child(sb)

	# Parry / Interrupt Modal (Only pops on the victim when Execution lands!)
	parry_panel = PanelContainer.new()
	parry_panel.anchor_left = 0.25; parry_panel.anchor_right = 0.75
	parry_panel.anchor_top = 0.28; parry_panel.anchor_bottom = 0.56
	parry_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.14, 0.06, 0.06, 0.96), Color(0.95, 0.36, 0.24, 0.95), 3, 14, 18))
	parry_panel.visible = false
	hud_root.add_child(parry_panel)
	var pvb := VBoxContainer.new()
	pvb.alignment = BoxContainer.ALIGNMENT_CENTER
	pvb.add_theme_constant_override("separation", 12)
	parry_panel.add_child(pvb)
	parry_title_lbl = Label.new()
	parry_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(parry_title_lbl, true)
	parry_title_lbl.add_theme_font_size_override("font_size", 24)
	parry_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.34, 0.28))
	pvb.add_child(parry_title_lbl)
	parry_timer_lbl = Label.new()
	parry_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(parry_timer_lbl, false)
	parry_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	parry_timer_lbl.add_theme_font_size_override("font_size", 18)
	pvb.add_child(parry_timer_lbl)
	parry_btns_box = HBoxContainer.new()
	parry_btns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	parry_btns_box.add_theme_constant_override("separation", 14)
	pvb.add_child(parry_btns_box)

	# Ghost Strip (When local player is executed/dead)
	ghost_panel = PanelContainer.new()
	ghost_panel.anchor_left = 0.24; ghost_panel.anchor_right = 0.76
	ghost_panel.anchor_top = 0.78; ghost_panel.anchor_bottom = 0.90
	ghost_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.06, 0.08, 0.10, 0.94), Color(0.45, 0.82, 0.88, 0.82), 2, 12, 12))
	ghost_panel.visible = false
	hud_root.add_child(ghost_panel)
	var ghb := HBoxContainer.new()
	ghb.alignment = BoxContainer.ALIGNMENT_CENTER
	ghb.add_theme_constant_override("separation", 12)
	ghost_panel.add_child(ghb)
	ghost_cd_lbl = Label.new()
	ghost_cd_lbl.text = "👻 TAVERN GHOST — Ready!"
	_apply_font(ghost_cd_lbl, true)
	ghost_cd_lbl.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0))
	ghb.add_child(ghost_cd_lbl)
	for ga in [["GHOST_HEX", "💀 Curse Target (-8 HP)"], ["GHOST_BLESS", "✨ Shield Target (+10)"], ["GHOST_SUIT", "🌬 Shift Suit"]]:
		var gb := Button.new()
		gb.text = ga[1]
		_style_tavern_btn(gb, Color(0.10, 0.14, 0.18, 0.95), Color(0.46, 0.78, 0.88, 0.85), false, 8)
		var gid: String = ga[0]
		gb.pressed.connect(func():
			play_sfx_requested.emit("btn_ghost_curse")
			if mp_net:
				mp_net.send_ghost_action(gid, selected_target)
		)
		ghb.add_child(gb)

	# Victory Overlay
	victory_panel = PanelContainer.new()
	victory_panel.anchor_left = 0.28; victory_panel.anchor_right = 0.72
	victory_panel.anchor_top = 0.25; victory_panel.anchor_bottom = 0.65
	victory_panel.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.09, 0.065, 0.045, 0.96), Color(0.92, 0.72, 0.26, 0.95), 3, 14, 20))
	victory_panel.visible = false
	hud_root.add_child(victory_panel)
	var vvb := VBoxContainer.new()
	vvb.alignment = BoxContainer.ALIGNMENT_CENTER
	vvb.add_theme_constant_override("separation", 16)
	victory_panel.add_child(vvb)
	victory_lbl = Label.new()
	victory_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(victory_lbl, true)
	victory_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	victory_lbl.add_theme_font_size_override("font_size", 24)
	vvb.add_child(victory_lbl)
	var vbtn := Button.new()
	vbtn.text = "Return to MP Lobby"
	vbtn.custom_minimum_size = Vector2(220, 44)
	_style_tavern_btn(vbtn, Color(0.28, 0.15, 0.08, 0.96), Color(0.92, 0.72, 0.26, 0.92), true, 10)
	vbtn.pressed.connect(func(): exit_mp_requested.emit())
	vvb.add_child(vbtn)

	# End-of-Round / Next-Round Cinematic Ribbon Overlay
	round_transition_overlay = Control.new()
	round_transition_overlay.name = "MpRoundTransitionOverlay"
	round_transition_overlay.anchor_left = 0.0
	round_transition_overlay.anchor_top = 0.0
	round_transition_overlay.anchor_right = 1.0
	round_transition_overlay.anchor_bottom = 1.0
	round_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_transition_overlay.visible = false
	round_transition_overlay.z_index = 40
	hud_root.add_child(round_transition_overlay)

	round_transition_ribbon = PanelContainer.new()
	round_transition_ribbon.anchor_left = 0.5
	round_transition_ribbon.anchor_right = 0.5
	round_transition_ribbon.anchor_top = 0.34
	round_transition_ribbon.anchor_bottom = 0.34
	round_transition_ribbon.offset_left = -310.0
	round_transition_ribbon.offset_right = 310.0
	round_transition_ribbon.offset_top = -62.0
	round_transition_ribbon.offset_bottom = 62.0
	round_transition_ribbon.pivot_offset = Vector2(310.0, 62.0)
	round_transition_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_transition_ribbon.add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.055, 0.035, 0.94), Color(0.95, 0.76, 0.30, 0.96), 3, 14, 18))
	round_transition_overlay.add_child(round_transition_ribbon)

	var rtvb := VBoxContainer.new()
	rtvb.alignment = BoxContainer.ALIGNMENT_CENTER
	rtvb.add_theme_constant_override("separation", 4)
	rtvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_transition_ribbon.add_child(rtvb)

	round_transition_title_lbl = Label.new()
	round_transition_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(round_transition_title_lbl, true)
	round_transition_title_lbl.add_theme_font_size_override("font_size", 30)
	round_transition_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.89, 0.48))
	round_transition_title_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.04, 0.02, 1.0))
	round_transition_title_lbl.add_theme_constant_override("outline_size", 6)
	round_transition_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtvb.add_child(round_transition_title_lbl)

	round_transition_sub_lbl = Label.new()
	round_transition_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(round_transition_sub_lbl, false)
	round_transition_sub_lbl.add_theme_font_size_override("font_size", 16)
	round_transition_sub_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	round_transition_sub_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 1.0))
	round_transition_sub_lbl.add_theme_constant_override("outline_size", 3)
	round_transition_sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtvb.add_child(round_transition_sub_lbl)

	add_child(hud_layer)


# ---------------------------------------------------------------------------
# State Updates & Sync Reactions
# ---------------------------------------------------------------------------

func _on_public_state(state: Dictionary) -> void:
	public_state = state
	var seats_arr: Array = state.get("seats", [])
	_rebuild_seats_if_needed(seats_arr)

	var t_seat := int(state.get("turn_seat", 0))
	var s_obj := Config.get_suit(str(state.get("active_suit", "CERVEN")))
	if is_instance_valid(suit_beacon_lbl):
		suit_beacon_lbl.text = str(s_obj["sym"])
		suit_beacon_lbl.modulate = s_obj["col"]

	var stack_txt := ("  •  🩸 TAX +%d" % int(state.get("pending_draw_stack", 0))) if int(state.get("pending_draw_stack", 0)) > 0 else ""
	var r_now := int(state.get("round_num", 1))
	if is_instance_valid(status_info_lbl):
		status_info_lbl.text = "%s %s  •  Round %d%s" % [s_obj["sym"], s_obj["name"], r_now, stack_txt]
	if _last_mp_round_num < 0:
		_last_mp_round_num = r_now
	elif r_now > _last_mp_round_num:
		var prev_r := _last_mp_round_num
		_last_mp_round_num = r_now
		_play_mp_round_transition_anim(prev_r, r_now)
	if is_instance_valid(center_banner_lbl) and _toast_timer <= 0.0:
		center_banner_lbl.text = str(state.get("banner", ""))

	# Update top center discard card visual if discard count grew
	var top_c: Dictionary = state.get("top_card", {})
	var dcnt := int(state.get("discard_count", 0))
	if not top_c.is_empty() and dcnt != _discard_visual_count:
		_discard_visual_count = dcnt
		_spawn_center_discard_mesh(top_c)

	# Refresh turn strip + 3D seat visuals
	if is_instance_valid(turn_strip_box):
		for c in turn_strip_box.get_children():
			c.queue_free()

	for s in seats_arr:
		var si := int(s["seat_idx"])
		var is_alive := bool(s["alive"])
		var is_turn := (si == t_seat and is_alive)
		if is_instance_valid(turn_strip_box):
			var pill := Label.new()
			var mark := "▶ " if is_turn else ("" if is_alive else "👻 ")
			pill.text = "%s%s" % [mark, str(s["name"])]
			_apply_font(pill, false)
			pill.add_theme_font_size_override("font_size", 12)
			pill.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30) if is_turn else (Color(0.86, 0.90, 0.88) if is_alive else Color(0.55, 0.58, 0.62)))
			turn_strip_box.add_child(pill)

		if seat_nodes.has(si):
			var sn: Dictionary = seat_nodes[si]
			sn["turn_ring"].visible = is_turn and (si != my_seat)
			sn["lbl"].text = "%s\n♥ %d   🛡 %d   🃏 %s" % [
				str(s["name"]),
				int(s["hp"]),
				int(s["shields"]),
				"MIST?" if bool(s["mist_cloaked"]) else str(s["hand_count"]),
			]
			sn["lbl"].modulate = Color(1.0, 0.90, 0.40) if is_turn else (Color.WHITE if is_alive else Color(0.55, 0.65, 0.72))
			var dm: MeshInstance3D = sn["deck_mesh"]
			dm.scale.y = clampf(float(s["deck_count"]) / 32.0, 0.15, 1.35)
			if si == my_seat and dm.get_node_or_null("MpDrawDeckArea") == null:
				var da := Area3D.new()
				da.name = "MpDrawDeckArea"
				da.set_meta("mp_draw_deck", true)
				var dcs := CollisionShape3D.new()
				var dbox := BoxShape3D.new()
				dbox.size = Vector3(0.18, 0.14, 0.24)
				dcs.shape = dbox
				da.add_child(dcs)
				dm.add_child(da)
			sn["avatar"].visible = (si != my_seat)
			if not is_alive:
				sn["avatar"].scale = Vector3(0.72, 0.72, 0.72)
			_rebuild_seat_hand_3d(si, s)

	# Ensure selected target points to a valid alive opponent
	if not _is_valid_opponent_target(selected_target):
		selected_target = _first_alive_opponent()

	# Sync Campaign Heartbeat HP Display + bottom-left Cards · Gold pill
	var my_pub := _get_pub_seat(my_seat)
	var i_am_alive := bool(my_pub.get("alive", true))
	var my_hp := int(my_pub.get("hp", Config.START_HP))
	var my_max_hp := int(my_pub.get("max_hp", Config.START_HP))
	var my_sh := int(my_pub.get("shields", 0))
	if is_instance_valid(player_hp_heart):
		player_hp_heart.call("set_hp_with_status", my_hp, my_max_hp, my_sh, "", true)
		if my_hp < _last_local_hp:
			player_hp_heart.call("trigger_damage_pulse", _last_local_hp - my_hp)
	_last_local_hp = my_hp
	if is_instance_valid(status_cards_coins_lbl):
		status_cards_coins_lbl.text = "Cards: %d  ·  💰 %dg" % [my_hand.size(), int(my_pub.get("gold", 25))]

	ghost_panel.visible = not i_am_alive and not bool(state.get("match_over", false))
	if not i_am_alive and is_instance_valid(ghost_cd_lbl):
		var gcd := float(my_pub.get("ghost_cd", 0.0))
		ghost_cd_lbl.text = "👻 TAVERN GHOST — Ready!" if gcd <= 0.1 else ("👻 Recharging (%.1fs)..." % gcd)

	_update_parry_ui(state.get("pending_parry", {}))
	_rebuild_local_hand_ui()
	_refresh_target_and_actions()
	if not _mp_intro_showcase_done and not seats_arr.is_empty():
		_mp_intro_showcase_done = true
		_play_mp_table_items_intro_showcase()


func _play_mp_round_transition_anim(finished_r: int, next_r: int) -> void:
	if not is_instance_valid(round_transition_overlay) or not is_instance_valid(round_transition_ribbon):
		return
	if is_instance_valid(_round_transition_tween) and _round_transition_tween.is_valid():
		_round_transition_tween.kill()
	round_transition_title_lbl.text = "ROUND %d COMPLETE  ->  ROUND %d" % [finished_r, next_r]
	round_transition_sub_lbl.text = "New Hand  •  Tavern Arena Resets"
	round_transition_overlay.visible = true
	round_transition_overlay.modulate = Color(1, 1, 1, 0)
	round_transition_ribbon.scale = Vector2(0.84, 0.84)
	if is_inside_tree():
		var center := global_position + Vector3(0.0, 0.90, 0.0)
		Fx.ring(self, center, Color(0.98, 0.78, 0.28), 0.72, 0.65, 0.08, 2.8, 8.0)
		Fx.gold_flakes(self, center + Vector3(0.0, 0.14, 0.0), 34, 1.3)
		play_sfx_requested.emit("anim_combo_slam")
		cam_kick_shake = maxf(cam_kick_shake, 0.35)
		_round_transition_tween = create_tween()
		_round_transition_tween.tween_property(round_transition_overlay, "modulate:a", 1.0, 0.24).set_ease(Tween.EASE_OUT)
		_round_transition_tween.parallel().tween_property(round_transition_ribbon, "scale", Vector2(1.03, 1.03), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_round_transition_tween.tween_property(round_transition_ribbon, "scale", Vector2(1.0, 1.0), 0.16)
		_round_transition_tween.tween_interval(1.25)
		_round_transition_tween.tween_property(round_transition_overlay, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
		_round_transition_tween.parallel().tween_property(round_transition_ribbon, "scale", Vector2(0.95, 0.95), 0.42)
		_round_transition_tween.tween_callback(func():
			if is_instance_valid(round_transition_overlay):
				round_transition_overlay.visible = false
		)


func _on_private_hand(s_idx: int, hand: Array, items: Array, meta: Dictionary) -> void:
	my_seat = s_idx
	my_hand = hand
	my_items = items
	if meta.has("item_uses") and typeof(meta["item_uses"]) == TYPE_DICTIONARY:
		mp_item_uses = (meta["item_uses"] as Dictionary).duplicate()
	selected_indices.clear()
	if meta.has("toast_err"):
		_toast_msg = str(meta["toast_err"])
		_toast_timer = 2.2
		if is_instance_valid(center_banner_lbl):
			center_banner_lbl.text = "⚠ " + _toast_msg
	_rebuild_local_hand_ui()
	_rebuild_local_items_ui()
	_refresh_target_and_actions()


func _on_vfx_event(evt: Dictionary) -> void:
	var etype := str(evt.get("type", ""))
	var center := global_position + Vector3(0.0, 0.85, 0.0)
	match etype:
		"CARD_PLAY":
			var fs := int(evt.get("from_seat", 0))
			var ts := int(evt.get("to_seat", 1))
			var from_p := _seat_world_pos(fs, 1.02)
			var to_p := _seat_world_pos(ts, 1.02)
			var cards_arr: Array = evt.get("cards", [])
			play_sfx_requested.emit("card_slam")
			if cards_arr.size() >= 2:
				play_sfx_requested.emit("anim_combo_slam")
			if not cards_arr.is_empty():
				var lead_card: Dictionary = cards_arr[0]
				var lr := str(lead_card.get("rank", ""))
				var lpid := str(lead_card.get("power_id", ""))
				if lpid == "SPEC_SHIELD" or (lpid == "" and lr == "D"):
					play_sfx_requested.emit("card_shield_guard")
				elif lpid == "" and lr == "E":
					play_sfx_requested.emit("card_ace_strike")
				elif lpid == "" and lr == "7":
					play_sfx_requested.emit("card_seven_curse")
				elif lpid == "" and lr == "H":
					play_sfx_requested.emit("card_suit_shift")
			_top_down_auto_timer = maxf(_top_down_auto_timer, 1.35)
			cam_kick_shake = maxf(cam_kick_shake, 0.32)
			var lead_c: Dictionary = cards_arr[0] if not cards_arr.is_empty() and typeof(cards_arr[0]) == TYPE_DICTIONARY else {}
			SwordCardAnim.play_sword_card_mp_strike(
				self,
				lead_c,
				from_p,
				to_p,
				center,
				maxi(20, int(evt.get("dmg", 32))),
				clampf(1.0 + float(maxi(0, cards_arr.size() - 1)) * 0.4, 1.0, 2.5),
				bool(evt.get("is_knight", false))
			)
			cam_spring.trigger_score_recoil(int(evt.get("dmg", 32)) * 3, 2.2, 0.58)
		"ITEM_CAST":
			var fs_i := int(evt.get("from_seat", 0))
			var ts_i := int(evt.get("to_seat", 1))
			var it_id := str(evt.get("item_id", ""))
			var item_info: Dictionary = Config.MP_ITEMS.get(it_id, {"name": it_id, "col": Color.GOLD})
			var icol: Color = item_info.get("col", Color(0.96, 0.78, 0.34))
			var item_n: Node3D = mp_item_3d_nodes.get(it_id) as Node3D if (fs_i == my_seat and mp_item_3d_nodes.has(it_id)) else null
			var origin_i := item_n.global_position if is_instance_valid(item_n) else _seat_world_pos(fs_i, 0.82)
			var target_i := _seat_world_pos(ts_i, 1.02) + Vector3(0.0, 0.32, 0.0)
			play_sfx_requested.emit("prop_coins")
			Fx.play_complex_table_item_anim(self, item_n, origin_i, target_i, it_id, icol)
			if bool(evt.get("shattered", false)):
				Fx.float_number(self, origin_i + Vector3(0.0, 0.24, 0.0), "💥 SHATTERED! (0/3)", Color(1.0, 0.36, 0.24), 48, 0.20, 0.85, 1.40)
				get_tree().create_timer(0.48).timeout.connect(func():
					if is_instance_valid(self):
						Fx.shatter_table_item(self, item_n, origin_i, icol)
						play_sfx_requested.emit("card_slam")
				)
			elif is_instance_valid(item_n):
				var u_left := int(evt.get("uses_left", 2))
				Fx.float_number(self, origin_i + Vector3(0.0, 0.22, 0.0), "%d/%d" % [u_left, MAX_MP_ITEM_USES], icol.lightened(0.3), 44, 0.16, 0.65, 1.25)
				var rtag := item_n.get_node_or_null("RelicHoverTag") as Label3D
				if rtag:
					rtag.text = "%s [%d/%d]\n(%s)" % [str(item_info.get("name", it_id)), u_left, MAX_MP_ITEM_USES, str(item_info.get("short", "Use"))]
		"PARRY_WINDUP":
			play_sfx_requested.emit("anim_sword_unsheathe")
			cam_kick_shake = 0.55
			Fx.ring(self, center + Vector3(0.0, 0.04, 0.0), Color(1.0, 0.25, 0.22), 1.35, 0.8, 0.08, 2.5, 8.0)
		"PARRY_DEFLECT":
			play_sfx_requested.emit("anim_parry_clang")
			var fs2 := int(evt.get("from_seat", 0))
			var ts2 := int(evt.get("to_seat", 1))
			SwordCardAnim.play_sword_card_mp_strike(
				self,
				{"suit": "CERVEN", "rank": "K", "edition": "KNIGHT"},
				_seat_world_pos(fs2, 1.04),
				_seat_world_pos(ts2, 1.04),
				center,
				120,
				3.0,
				false
			)
			cam_kick_shake = 0.95
			Fx.float_number(self, center + Vector3(0.0, 0.38, 0.0), "🪞 MIRROR PARRY!", Color(1.0, 0.84, 0.28), 64, 0.26, 1.1, 1.7)
		"EXECUTION_KILL":
			play_sfx_requested.emit("card_ace_strike")
			var fs3 := int(evt.get("from_seat", 0))
			var ts3 := int(evt.get("to_seat", 1))
			var vpos := _seat_world_pos(ts3, 1.15)
			BlenderVfx.play_defeat_execution_anim(self, ts3 == my_seat, center, vpos)
			SwordCardAnim.play_sword_card_mp_strike(
				self,
				{"suit": "CERVEN", "rank": "E", "edition": "KNIGHT"},
				_seat_world_pos(fs3, 1.05),
				vpos,
				center.lerp(vpos, 0.5),
				150,
				3.5,
				true
			)
			Fx.ink_splat(self, vpos + Vector3(0.0, 0.25, 0.0), 42, 1.8)
			Fx.gold_flakes(self, vpos + Vector3(0.0, 0.28, 0.0), 38, 1.5)
			cam_kick_shake = 1.15
			cam_spring.trigger_score_recoil(300, 4.0, 1.1)
		"SHED_OVERDRIVE":
			Fx.ring(self, center + Vector3(0.0, 0.03, 0.0), Color(0.45, 1.0, 0.65), 1.5, 0.7, 0.10, 2.2, 14.0)


func _on_match_ended(winner_seat: int, summary: Dictionary) -> void:
	parry_panel.visible = false
	ghost_panel.visible = false
	var wname := str(summary.get("winner_name", "Champion"))
	var you_won := (winner_seat == my_seat)
	victory_lbl.text = "%s\nChampion: %s (%d Turns)" % [
		"👑 VICTORY! LAST DUELIST STANDING!" if you_won else "💀 DEFEATED AT THE TAVERN TABLE",
		wname,
		int(summary.get("rounds", 1)),
	]
	var focus_seat := my_seat
	if you_won:
		focus_seat = (my_seat + 1) % 2
		for s in seat_nodes.keys():
			if int(s) != my_seat:
				focus_seat = int(s)
				break
	BlenderVfx.play_defeat_execution_anim(
		self,
		not you_won,
		global_position + Vector3(0.0, 0.85, 0.0),
		_seat_world_pos(focus_seat, 1.0)
	)
	if is_instance_valid(victory_panel):
		victory_panel.visible = false
		victory_panel.modulate.a = 0.0
		var tw := victory_panel.create_tween()
		tw.tween_interval(3.60)
		tw.tween_callback(func():
			if is_instance_valid(victory_panel):
				victory_panel.visible = true
		)
		tw.tween_property(victory_panel, "modulate:a", 1.0, 0.40)


# ---------------------------------------------------------------------------
# UI Builders
# ---------------------------------------------------------------------------

func _setup_mp_fpp_hand() -> void:
	player_hand_anchor = Node3D.new()
	player_hand_anchor.name = "MpPlayerHandAnchor"
	player_hand_anchor.position = HAND_POS_UP
	player_hand_anchor.rotation_degrees = HAND_ROT_UP
	add_child(player_hand_anchor)

	player_glove_left_mesh = _create_mp_glove_mesh(false)
	player_glove_left_mesh.position = Vector3(-0.34, -0.04, 0.05)
	player_glove_left_mesh.rotation_degrees = Vector3(32.0, -26.0, 20.0)
	player_hand_anchor.add_child(player_glove_left_mesh)

	player_glove_right_mesh = _create_mp_glove_mesh(true)
	player_glove_right_mesh.position = Vector3(0.34, -0.04, 0.05)
	player_glove_right_mesh.rotation_degrees = Vector3(32.0, 26.0, -20.0)
	player_hand_anchor.add_child(player_glove_right_mesh)

	mp_items_rack_root = Node3D.new()
	mp_items_rack_root.name = "MpTableItemsRack"
	mp_items_rack_root.position = Vector3(0.0, 0.816, 0.0)
	add_child(mp_items_rack_root)


func _create_mp_glove_mesh(is_right: bool) -> Node3D:
	var root := Node3D.new()
	var side := 1.0 if is_right else -1.0
	var g_mat := Toon.mat(Color(0.44, 0.28, 0.17), "res://assets/gloves/glove_leather.png", 0.0022)
	var strap_mat := Toon.mat(Color(0.25, 0.16, 0.10), "res://assets/gloves/glove_leather.png", 0.0018)
	var brass_mat := Toon.mat(Color(0.84, 0.64, 0.24), "", 0.0016)

	var cuff := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.039; cmesh.bottom_radius = 0.052; cmesh.height = 0.11; cmesh.radial_segments = 16
	cuff.mesh = cmesh
	cuff.position = Vector3(side * 0.010, -0.018, 0.088)
	cuff.rotation_degrees = Vector3(78.0, -side * 5.0, 0.0)
	cuff.material_override = g_mat
	root.add_child(cuff)

	var palm := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(0.072, 0.026, 0.078)
	palm.mesh = pbox
	palm.material_override = g_mat
	root.add_child(palm)

	var strap := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(0.080, 0.028, 0.018)
	strap.mesh = sbox
	strap.position = Vector3(0.0, 0.004, 0.052)
	strap.material_override = strap_mat
	root.add_child(strap)

	var buckle := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(0.014, 0.014, 0.016)
	buckle.mesh = bbox
	buckle.position = Vector3(side * 0.040, 0.006, 0.052)
	buckle.material_override = brass_mat
	root.add_child(buckle)

	for fi in range(4):
		var fm := MeshInstance3D.new()
		var fcap := CapsuleMesh.new()
		fcap.radius = 0.008; fcap.height = 0.052
		fm.mesh = fcap
		fm.position = Vector3((-0.024 + float(fi) * 0.016), -0.004, -0.048)
		fm.rotation_degrees = Vector3(84.0, 0.0, 0.0)
		fm.material_override = g_mat
		root.add_child(fm)
	return root


func _is_mp_card_playable(c_data: Dictionary) -> bool:
	var my_turn: bool = (int(public_state.get("turn_seat", -1)) == my_seat) and public_state.get("pending_parry", {}).is_empty() and bool(_get_pub_seat(my_seat).get("alive", true))
	if not my_turn:
		return false
	var r := str(c_data.get("rank", ""))
	if int(public_state.get("pending_draw_stack", 0)) > 0:
		return r == "7"
	if r in ["H", "PWR"] or bool(c_data.get("wild", false)):
		return true
	var top_c: Dictionary = public_state.get("top_card", {})
	var top_r := str(top_c.get("rank", ""))
	var act_s := str(public_state.get("active_suit", "CERVEN"))
	return str(c_data.get("suit", "")) == act_s or r == top_r


func _can_stage_with_selection(c_data: Dictionary) -> bool:
	if selected_indices.is_empty():
		return true
	var first_c: Dictionary = my_hand[selected_indices[0]] if selected_indices[0] >= 0 and selected_indices[0] < my_hand.size() else {}
	var base_r := str(first_c.get("rank", ""))
	var r := str(c_data.get("rank", ""))
	return r == base_r or base_r == "PWR" or r == "PWR" or bool(c_data.get("wild", false))


func _build_mp_3d_card_node(card_data: Dictionary, border_col: Color) -> Node3D:
	var card_root := Node3D.new()
	var p_id := str(card_data.get("power_id", ""))
	var is_power := (p_id != "")
	var ed_id := Catalog.normalize_card_class(str(card_data.get("edition", "NORMAL")))
	var ed_info := Catalog.get_card_class(ed_id)
	var shader_ed_id := int(ed_info.get("shader_id", 0))
	var acc_col: Color = card_data.get("accent", ed_info.get("col", Color(1.0, 0.84, 0.32)))

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "CardFaceMesh"
	var qquad := QuadMesh.new()
	qquad.size = Vector2(0.185, 0.275)
	mesh_inst.mesh = qquad
	mesh_inst.position = Vector3(0.0, 0.0, 0.0026)

	var tex_path := "res://assets/cards/%s.png" % p_id if is_power else "res://assets/cards/%s_%s.png" % [str(card_data.get("suit", "CERVEN")), str(card_data.get("rank", "8"))]
	var has_tex := ResourceLoader.exists(tex_path)
	var smat := ShaderMaterial.new()
	smat.shader = CARD_FX_SHADER
	smat.set_shader_parameter("use_texture", has_tex)
	if has_tex:
		smat.set_shader_parameter("albedo_tex", load(tex_path))
	smat.set_shader_parameter("albedo", Color(0.95, 0.92, 0.85) if has_tex else Color(0.24, 0.18, 0.30))
	smat.set_shader_parameter("edition_id", shader_ed_id)
	smat.set_shader_parameter("is_power_card", 1.0 if is_power else 0.0)
	smat.set_shader_parameter("is_back", 0.0)
	smat.set_shader_parameter("accent_color", acc_col)
	smat.set_shader_parameter("hover_glow", 0.0)
	smat.set_shader_parameter("playable", 1.0)
	smat.set_shader_parameter("mage_charge", 0.5 if ed_id == "MAGE" else 0.0)
	mesh_inst.material_override = smat
	card_root.add_child(mesh_inst)

	var is_knight := (ed_id == "KNIGHT")
	var is_mage := (ed_id == "MAGE")
	var rim := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(0.200 if is_knight else (0.202 if is_mage else 0.194), 0.290 if is_knight else (0.292 if is_mage else 0.284), 0.0072 if is_knight else (0.0055 if is_mage else 0.004))
	rim.mesh = rbox
	rim.position = Vector3(0.0, 0.0, -0.0020 if is_knight else (-0.0022 if is_mage else 0.0))
	var rim_emit := border_col * 0.55 if (is_power or shader_ed_id > 0) else Color.BLACK
	rim.material_override = Toon.mat(border_col, "", 0.0, Vector2.ONE, rim_emit)
	card_root.add_child(rim)

	if is_mage:
		var halo := MeshInstance3D.new()
		halo.name = "MageArcaneRimHalo"
		var hbox := BoxMesh.new(); hbox.size = Vector3(0.214, 0.306, 0.0025)
		halo.mesh = hbox; halo.position = Vector3(0.0, 0.0, -0.0046)
		var hmat := StandardMaterial3D.new()
		hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hmat.albedo_color = Color(0.28, 0.68, 1.0, 0.42)
		hmat.emission_enabled = true
		hmat.emission = acc_col.lerp(Color(0.32, 0.74, 1.0), 0.5)
		hmat.emission_energy_multiplier = 1.4
		halo.material_override = hmat
		card_root.add_child(halo)

	if shader_ed_id > 0:
		Fx.attach_card_class_aura(card_root, shader_ed_id, acc_col)

	if is_power:
		var c_lbl := Label3D.new()
		c_lbl.text = str(card_data.get("short", card_data.get("rname", "PWR")))
		c_lbl.font = _font_display
		c_lbl.modulate = Color(1.0, 0.96, 0.88)
		c_lbl.outline_size = 6
		c_lbl.font_size = 20
		c_lbl.pixel_size = 0.0012
		c_lbl.position = Vector3(0.0, 0.020, 0.0045)
		card_root.add_child(c_lbl)

	return card_root


func _rebuild_local_hand_ui() -> void:
	if is_instance_valid(hand_bar):
		for c in hand_bar.get_children():
			c.queue_free()
	for n in player_card_nodes:
		if is_instance_valid(n):
			n.queue_free()
	player_card_nodes.clear()
	if not is_instance_valid(player_hand_anchor):
		return

	var p_cnt := my_hand.size()
	var p_mid := (p_cnt - 1) * 0.5
	for i in range(p_cnt):
		var c_data: Dictionary = my_hand[i]
		var playable := _is_mp_card_playable(c_data)
		var is_staged := i in selected_indices
		var can_chain := (not is_staged) and (not selected_indices.is_empty()) and _can_stage_with_selection(c_data)
		var border := Color(0.24, 0.86, 0.52) if playable else Color(0.35, 0.38, 0.44)
		if is_staged:
			border = Color(1.0, 0.88, 0.24)
		elif can_chain:
			border = Color(1.0, 0.64, 0.18)

		var c_node := _build_mp_3d_card_node(c_data, border)
		var step_w := clampf(0.154 - float(maxi(0, p_cnt - 5)) * 0.007, 0.118, 0.154)
		var norm := (float(i) - p_mid) / maxf(1.0, p_mid)
		var spread_x := (float(i) - p_mid) * step_w
		var arc_y := -pow(absf(float(i) - p_mid), 1.42) * 0.013 + 0.014
		var depth_z := float(i) * 0.0075 + (1.0 - absf(norm)) * 0.010
		var tilt_z := -(float(i) - p_mid) * clampf(5.0 - float(maxi(0, p_cnt - 6)) * 0.30, 3.2, 5.0)
		var tilt_y := -(float(i) - p_mid) * 1.5

		c_node.position = Vector3(spread_x, arc_y, depth_z)
		c_node.rotation_degrees = Vector3(0.0, tilt_y, tilt_z)
		c_node.set_meta("base_pos", c_node.position)
		c_node.set_meta("base_rot", c_node.rotation_degrees)
		c_node.set_meta("is_playable", playable or can_chain)

		if is_staged:
			var badge_lbl := Label3D.new()
			badge_lbl.text = "⚡"
			badge_lbl.font = _font_display
			badge_lbl.modulate = Color(1.0, 0.90, 0.22)
			badge_lbl.font_size = 34
			badge_lbl.pixel_size = 0.0018
			badge_lbl.position = Vector3(0.058, 0.106, 0.005)
			c_node.add_child(badge_lbl)

		var area := Area3D.new()
		area.set_meta("mp_card_index", i)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.18, 0.27, 0.025)
		col.shape = box
		area.add_child(col)
		c_node.add_child(area)

		player_hand_anchor.add_child(c_node)
		player_card_nodes.append(c_node)


func _rebuild_local_items_ui() -> void:
	if is_instance_valid(items_bar):
		for c in items_bar.get_children():
			c.queue_free()
	for rn in mp_item_3d_nodes.values():
		if is_instance_valid(rn):
			(rn as Node3D).queue_free()
	mp_item_3d_nodes.clear()
	if not is_instance_valid(mp_items_rack_root):
		return

	var item_slots: Array[Vector3] = [
		Vector3(0.28, 0.0, 0.54),
		Vector3(0.47, 0.0, 0.44),
		Vector3(0.65, 0.0, 0.34),
		Vector3(0.38, 0.0, 0.68),
		Vector3(0.58, 0.0, 0.60),
	]
	for idx_i in range(my_items.size()):
		var it_id := str(my_items[idx_i])
		var info: Dictionary = Config.MP_ITEMS.get(it_id, {"name": it_id, "short": "Use", "col": Color.GOLD})
		var icol: Color = info.get("col", Color(0.95, 0.80, 0.32))
		var rem_uses := maxi(0, MAX_MP_ITEM_USES - int(mp_item_uses.get(it_id, 0)))
		if rem_uses <= 0:
			continue
		var ped := Node3D.new()
		ped.name = "MpItem_" + it_id
		ped.position = item_slots[idx_i % item_slots.size()]

		var mesh_key := str(MP_ITEM_MESH_MAP.get(it_id, "TRELIC_BLOOD_SEAL"))
		var imodel := RelicMesh.build_relic_3d_mesh(mesh_key, icol)
		imodel.scale = Vector3(1.24, 1.24, 1.24)
		ped.add_child(imodel)

		var lbl3d := Label3D.new()
		lbl3d.name = "RelicHoverTag"
		lbl3d.text = "%s [%d/%d]\n(%s)" % [str(info.get("name", it_id)), rem_uses, MAX_MP_ITEM_USES, str(info.get("short", "Use"))]
		lbl3d.font = _font_display
		lbl3d.modulate = icol.lightened(0.42)
		lbl3d.font_size = 11
		lbl3d.outline_size = 5
		lbl3d.pixel_size = 0.0012
		lbl3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl3d.position = Vector3(0.0, 0.22, 0.0)
		lbl3d.visible = false
		ped.add_child(lbl3d)

		var area := Area3D.new()
		area.set_meta("mp_item_id", it_id)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new(); box.size = Vector3(0.18, 0.24, 0.18)
		cs.shape = box; cs.position = Vector3(0.0, 0.10, 0.0)
		area.add_child(cs)
		ped.add_child(area)

		ped.set_meta("base_pos", ped.position)
		ped.set_meta("base_scale", Vector3.ONE)
		ped.set_meta("base_rot", ped.rotation_degrees)
		mp_items_rack_root.add_child(ped)
		mp_item_3d_nodes[it_id] = ped


func _play_mp_table_items_intro_showcase() -> void:
	var list_n: Array[Node3D] = []
	for rn in mp_item_3d_nodes.values():
		if is_instance_valid(rn):
			list_n.append(rn as Node3D)
	if seat_nodes.has(my_seat):
		var sw := seat_nodes[my_seat].get("sword") as Node3D
		if is_instance_valid(sw):
			list_n.append(sw)
	for si in range(list_n.size()):
		var sn: Node3D = list_n[si]
		var bp: Vector3 = sn.get_meta("base_pos", sn.position)
		var bs: Vector3 = sn.get_meta("base_scale", sn.scale)
		var br: Vector3 = sn.get_meta("base_rot", sn.rotation_degrees)
		sn.set_meta("base_pos", bp); sn.set_meta("base_scale", bs); sn.set_meta("base_rot", br)
		var tw := sn.create_tween()
		if si > 0:
			tw.tween_interval(0.09 * float(si))
		tw.tween_callback(func():
			if is_instance_valid(self) and is_instance_valid(sn):
				Fx.ring(self, sn.global_position + Vector3(0, 0.05, 0), Color(1.0, 0.82, 0.36), 0.24, 0.35, 0.04, 1.8, 6.0)
				play_sfx_requested.emit("card_hover")
		)
		tw.tween_property(sn, "position:y", bp.y + 0.18, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sn, "scale", bs * 1.24, 0.15)
		tw.parallel().tween_property(sn, "rotation_degrees:y", br.y + 360.0, 0.34).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(sn, "position:y", bp.y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sn, "scale", bs, 0.16)


func _update_mp_hover_and_cursor(delta: float, blocked: bool) -> void:
	hovered_card_idx = -1
	hovered_item_id = ""
	hovered_draw_deck = false

	if not blocked and is_instance_valid(cam):
		var vp := get_viewport()
		var vp_r := vp.get_visible_rect() if vp != null else Rect2(0, 0, 1280, 720)
		var mpos := _mp_cursor_pos
		if mpos.x >= 0.0 and mpos.y >= 0.0 and vp_r.size.x > 4.0 and vp_r.size.y > 4.0:
			var w3d := get_world_3d()
			if w3d != null and w3d.direct_space_state != null:
				var r_orig := cam.project_ray_origin(mpos)
				var r_dir := cam.project_ray_normal(mpos)
				var q := PhysicsRayQueryParameters3D.create(r_orig, r_orig + r_dir * 8.0)
				q.collide_with_areas = true
				q.collide_with_bodies = false
				var hit := w3d.direct_space_state.intersect_ray(q)
				if not hit.is_empty():
					var coll = hit.get("collider")
					if coll is Area3D:
						var ca := coll as Area3D
						if ca.has_meta("mp_card_index") and not top_down_manual:
							hovered_card_idx = int(ca.get_meta("mp_card_index", -1))
						elif ca.has_meta("mp_item_id"):
							hovered_item_id = str(ca.get_meta("mp_item_id", ""))
						elif ca.has_meta("mp_draw_deck"):
							hovered_draw_deck = true

	# Animate 3D hand card hover lift + shader glow
	for i in range(player_card_nodes.size()):
		var cn := player_card_nodes[i]
		if not is_instance_valid(cn):
			continue
		var bp: Vector3 = cn.get_meta("base_pos", cn.position)
		var is_hov := (i == hovered_card_idx)
		var is_stg := (i in selected_indices)
		var tgt_p := bp + (Vector3(0.0, 0.085, 0.045) if is_hov else (Vector3(0.0, 0.035, 0.015) if is_stg else Vector3.ZERO))
		var tgt_s := Vector3(1.14, 1.14, 1.14) if is_hov else (Vector3(1.06, 1.06, 1.06) if is_stg else Vector3.ONE)
		cn.position = cn.position.lerp(tgt_p, clampf(delta * 14.0, 0.0, 1.0))
		cn.scale = cn.scale.lerp(tgt_s, clampf(delta * 14.0, 0.0, 1.0))
		var fm := cn.get_node_or_null("CardFaceMesh") as MeshInstance3D
		if fm and fm.material_override is ShaderMaterial:
			(fm.material_override as ShaderMaterial).set_shader_parameter("hover_glow", 1.0 if is_hov else (0.55 if is_stg else 0.0))

	# Animate 3D tabletop OP item hover lift + hover tag
	for k_it in mp_item_3d_nodes.keys():
		var in_node := mp_item_3d_nodes[k_it] as Node3D
		if not is_instance_valid(in_node) or not in_node.visible:
			continue
		var bp_i: Vector3 = in_node.get_meta("base_pos", in_node.position)
		var is_ih := (str(k_it) == hovered_item_id)
		in_node.position = in_node.position.lerp(bp_i + (Vector3(0.0, 0.06, 0.0) if is_ih else Vector3.ZERO), clampf(delta * 12.0, 0.0, 1.0))
		in_node.scale = in_node.scale.lerp(Vector3(1.24, 1.24, 1.24) if is_ih else Vector3.ONE, clampf(delta * 12.0, 0.0, 1.0))
		var tag := in_node.get_node_or_null("RelicHoverTag") as Label3D
		if tag:
			tag.visible = is_ih

	# Update bottom-right hover inspect card/item tooltip
	var nkey := "%d|%s|%s" % [hovered_card_idx, hovered_item_id, str(hovered_draw_deck)]
	if nkey != _hover_cache_key and is_instance_valid(hover_inspect_panel):
		_hover_cache_key = nkey
		if hovered_card_idx >= 0 and hovered_card_idx < my_hand.size():
			var hc: Dictionary = my_hand[hovered_card_idx]
			var s_o := Config.get_suit(str(hc.get("suit", "CERVEN")))
			var pid_h := str(hc.get("power_id", ""))
			hover_inspect_title.text = str(hc.get("rname", "Card")) if pid_h != "" else "%s %s" % [s_o["sym"], str(hc.get("rank", "?"))]
			hover_inspect_sub.text = "%s · +%d pts" % [Catalog.normalize_card_class(str(hc.get("edition", "NORMAL"))), int(hc.get("pts", 10))]
			hover_inspect_desc.text = str(hc.get("desc", "Left-click: Play now  |  Right-click: Stage for Combo!"))
			hover_inspect_panel.visible = true
		elif hovered_item_id != "":
			var ii: Dictionary = Config.MP_ITEMS.get(hovered_item_id, {})
			var rem_i := maxi(0, MAX_MP_ITEM_USES - int(mp_item_uses.get(hovered_item_id, 0)))
			hover_inspect_title.text = "✦ %s [%d/%d]" % [str(ii.get("name", hovered_item_id)), rem_i, MAX_MP_ITEM_USES]
			hover_inspect_sub.text = str(ii.get("short", "Table Artifact"))
			hover_inspect_desc.text = "Click to activate on table (breaks after 3 uses!)."
			hover_inspect_panel.visible = true
		elif hovered_draw_deck:
			var tx := int(public_state.get("pending_draw_stack", 0))
			hover_inspect_title.text = "🃏 Draw Deck"
			hover_inspect_sub.text = ("Blood Tax +%d cards" % tx) if tx > 0 else "Draw 1 card & end turn"
			hover_inspect_desc.text = "Click 3D deck on the table to draw."
			hover_inspect_panel.visible = true
		else:
			hover_inspect_panel.visible = false


func _toggle_mp_stage_card(idx: int) -> void:
	if idx < 0 or idx >= my_hand.size():
		return
	if idx in selected_indices:
		selected_indices.erase(idx)
	elif _can_stage_with_selection(my_hand[idx]):
		selected_indices.append(idx)
	else:
		selected_indices = [idx]
	play_sfx_requested.emit("btn_card_tick")
	_rebuild_local_hand_ui()
	_refresh_target_and_actions()


func _handle_mp_card_left_click(idx: int) -> void:
	if idx < 0 or idx >= my_hand.size():
		return
	if selected_indices.is_empty():
		var c: Dictionary = my_hand[idx]
		var needs_suit := (str(c.get("rank", "")) == "H") or bool(c.get("wild", false))
		if needs_suit:
			_pending_wild_play_indices = [idx]
			suit_pick_modal.visible = true
			play_sfx_requested.emit("card_hover")
		elif mp_net != null:
			play_sfx_requested.emit("btn_wooden_slam")
			mp_net.send_play_cards([idx], selected_target, chosen_wild_suit)
	elif idx in selected_indices:
		_on_slam_pressed()
	else:
		_toggle_mp_stage_card(idx)


func _refresh_target_and_actions() -> void:
	if is_instance_valid(target_bar):
		for c in target_bar.get_children():
			c.queue_free()
	if is_instance_valid(target_plaques_box):
		for c in target_plaques_box.get_children():
			c.queue_free()
		var active_ts := int(public_state.get("turn_seat", 0))
		for s in public_state.get("seats", []):
			var si := int(s["seat_idx"])
			if si == my_seat:
				continue
			var is_alive := bool(s["alive"])
			var is_sel := (si == selected_target)
			var is_t := (si == active_ts and is_alive)
			var tb := Button.new()
			var mark := "🎯 " if is_sel else ("▶ " if is_t else ("" if is_alive else "👻 "))
			tb.text = "%s%s  ♥%d  🛡%d  🃏%d" % [mark, str(s["name"]), int(s["hp"]), int(s["shields"]), int(s["hand_count"])]
			tb.disabled = not is_alive
			tb.custom_minimum_size = Vector2(296, 38)
			_style_tavern_btn(
				tb,
				Color(0.24, 0.15, 0.08, 0.96) if is_sel else Color(0.09, 0.07, 0.055, 0.92),
				Color(0.98, 0.80, 0.28, 0.98) if is_sel else (Color(0.56, 0.44, 0.26, 0.82) if is_alive else Color(0.32, 0.34, 0.38, 0.6)),
				false, 8
			)
			tb.pressed.connect(func():
				selected_target = si
				play_sfx_requested.emit("card_hover")
				_refresh_target_and_actions()
			)
			target_plaques_box.add_child(tb)

	var ace_sel := 0
	for idx in selected_indices:
		if idx >= 0 and idx < my_hand.size() and str(my_hand[idx].get("rank", "")) == "E":
			ace_sel += 1

	var my_pub := _get_pub_seat(my_seat)
	var i_am_alive := bool(my_pub.get("alive", true))
	var active_turn_s := int(public_state.get("turn_seat", 0))
	var seats_cnt := (public_state.get("seats", []) as Array).size()
	var my_turn: bool = (active_turn_s == my_seat) and public_state.get("pending_parry", {}).is_empty() and i_am_alive

	if is_instance_valid(turn_banner_lbl) and is_instance_valid(turn_banner_grp):
		if my_turn:
			turn_banner_lbl.text = "⚔ YOUR TURN"
			turn_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.44))
			(turn_banner_grp as PanelContainer).add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.10, 0.08, 0.04, 0.95), Color(0.95, 0.78, 0.28, 0.96), 2, 10, 8))
		else:
			var t_s := _get_pub_seat(active_turn_s)
			var t_name := str(t_s.get("name", "Rival"))
			turn_banner_lbl.text = ("⏳ %s's Turn (Free Look)" % t_name) if seats_cnt > 2 else ("⏳ %s's Turn" % t_name)
			turn_banner_lbl.add_theme_color_override("font_color", Color(0.80, 0.84, 0.90))
			(turn_banner_grp as PanelContainer).add_theme_stylebox_override("panel", _make_tavern_panel_sb(Color(0.08, 0.07, 0.08, 0.90), Color(0.50, 0.44, 0.36, 0.76), 2, 10, 8))

	if is_instance_valid(status_cards_coins_lbl):
		status_cards_coins_lbl.text = "Cards: %d  ·  💰 %dg" % [my_hand.size(), int(my_pub.get("gold", 25))]

	if is_instance_valid(slam_btn):
		slam_btn.visible = my_turn and (not selected_indices.is_empty())
		slam_btn.disabled = (not my_turn) or selected_indices.is_empty()
		if ace_sel >= 4:
			slam_btn.text = "💀 4× ESO INSTANT KILL!"
		elif ace_sel == 3:
			slam_btn.text = "💀 3× ESO INSTANT KILL!"
		else:
			slam_btn.text = "⚔ SLAM (%d)" % selected_indices.size() if not selected_indices.is_empty() else "⚔ SLAM CARDS"

	if is_instance_valid(draw_btn):
		draw_btn.visible = i_am_alive
		draw_btn.disabled = not my_turn
		var tax := int(public_state.get("pending_draw_stack", 0))
		draw_btn.text = ("🩸 TAX +%d" % tax) if tax > 0 else "🃏 DRAW"


func _update_parry_ui(parry_pub: Dictionary) -> void:
	if parry_pub.is_empty():
		parry_panel.visible = false
		local_parry_left = 0.0
		return
	var tgt := int(parry_pub.get("target", -1))
	if tgt != my_seat:
		parry_panel.visible = false
		return

	parry_panel.visible = true
	local_parry_left = float(parry_pub.get("timer", Config.PARRY_WINDOW_SEC))
	var att_s := _get_pub_seat(int(parry_pub.get("attacker", 0)))
	parry_title_lbl.text = "⚔ INCOMING %s FROM %s!" % [str(parry_pub.get("kind", "EXECUTION")), str(att_s.get("name", "RIVAL"))]

	for c in parry_btns_box.get_children():
		c.queue_free()

	var my_pub := _get_pub_seat(my_seat)
	var has_mirror := bool(my_pub.get("aegis_reflect", false)) or ("MYS_WITCH_MIRROR" in my_items)
	var has_chronos := false
	for card in my_hand:
		if str(card.get("power_id", "")) == "SPEC_MIRROR": has_mirror = true
		if str(card.get("power_id", "")) == "SPEC_CHRONOS": has_chronos = true

	if has_mirror:
		var mb := Button.new()
		mb.text = "🪞 DEFLECT WITH MIRROR! (KILL ATTACKER)"
		mb.custom_minimum_size = Vector2(260, 46)
		_style_tavern_btn(mb, Color(0.24, 0.14, 0.34, 0.96), Color(0.86, 0.62, 1.0, 0.95), true, 10)
		mb.pressed.connect(func():
			if mp_net: mp_net.send_parry("MIRROR")
		)
		parry_btns_box.add_child(mb)
	if has_chronos:
		var cb := Button.new()
		cb.text = "⏳ TIME REWIND (CHRONOS +25 HP)"
		cb.custom_minimum_size = Vector2(240, 46)
		_style_tavern_btn(cb, Color(0.12, 0.22, 0.30, 0.96), Color(0.45, 0.88, 1.0, 0.95), true, 10)
		cb.pressed.connect(func():
			if mp_net: mp_net.send_parry("CHRONOS")
		)
		parry_btns_box.add_child(cb)

	var brace_btn := Button.new()
	brace_btn.text = "💀 Brace / No Counter"
	brace_btn.custom_minimum_size = Vector2(160, 46)
	_style_tavern_btn(brace_btn, Color(0.24, 0.10, 0.09, 0.95), Color(0.72, 0.34, 0.28, 0.88), false, 10)
	brace_btn.pressed.connect(func():
		if mp_net: mp_net.send_parry("BRACE")
	)
	parry_btns_box.add_child(brace_btn)


func _on_slam_pressed() -> void:
	if selected_indices.is_empty():
		return
	var needs_suit := false
	for idx in selected_indices:
		if idx >= 0 and idx < my_hand.size():
			var c: Dictionary = my_hand[idx]
			if str(c.get("rank", "")) == "H" or bool(c.get("wild", false)):
				needs_suit = true
	if needs_suit and is_instance_valid(suit_pick_modal):
		_pending_wild_play_indices = selected_indices.duplicate()
		suit_pick_modal.visible = true
		play_sfx_requested.emit("card_hover")
		return
	if mp_net == null:
		return
	play_sfx_requested.emit("btn_wooden_slam")
	var send_arr: Array = []
	for idx in selected_indices:
		send_arr.append(idx)
	mp_net.send_play_cards(send_arr, selected_target, chosen_wild_suit)


func _play_lightweight_card_slam(cards_arr: Array, from_p: Vector3, to_p: Vector3, center: Vector3, dmg: int) -> void:
	var n_vis := mini(4, maxi(1, cards_arr.size()))
	var suit_col := Color(0.92, 0.74, 0.34)
	if not cards_arr.is_empty() and typeof(cards_arr[0]) == TYPE_DICTIONARY:
		var s_obj := Config.get_suit(str(cards_arr[0].get("suit", "CERVEN")))
		suit_col = s_obj.get("col", suit_col)

	for i in range(n_vis):
		var c_dict: Dictionary = cards_arr[i] if i < cards_arr.size() and typeof(cards_arr[i]) == TYPE_DICTIONARY else {}
		var cm := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.18, 0.26)
		cm.mesh = qm
		var tpath := "res://assets/cards/%s_%s.png" % [str(c_dict.get("suit", "CERVEN")), str(c_dict.get("rank", "8"))]
		var tex := Toon.tex(tpath)
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.55
		if tex != null:
			mat.albedo_texture = tex
		else:
			mat.albedo_color = Color(0.92, 0.88, 0.78)
		cm.material_override = mat
		add_child(cm)

		var start_p := to_local(from_p) + Vector3(0.0, 0.08 + float(i) * 0.012, 0.0)
		var end_p := to_local(center) + Vector3(randf_range(-0.04, 0.04), 0.016 + float(i) * 0.004, randf_range(-0.04, 0.04))
		var mid_p := start_p.lerp(end_p, 0.5) + Vector3(0.0, 0.24, 0.0)
		cm.position = start_p
		cm.rotation_degrees = Vector3(-90.0, randf_range(-20.0, 20.0), 0.0)

		var tw := cm.create_tween()
		tw.tween_interval(float(i) * 0.04)
		tw.tween_property(cm, "position", mid_p, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cm, "position", end_p, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if is_instance_valid(cm):
				cm.queue_free()
		)

	Fx.ring(self, center + Vector3(0.0, 0.025, 0.0), suit_col, 0.55, 0.38, 0.04, 1.4, 3.5)
	if dmg > 0:
		Fx.float_number(self, to_p + Vector3(0.0, 0.26, 0.0), "-%d" % dmg, suit_col.lightened(0.2), 38, 0.18, 0.75, 1.1)


# ---------------------------------------------------------------------------
# 3D Card Visual Helpers
# ---------------------------------------------------------------------------

func _spawn_center_discard_mesh(card: Dictionary) -> void:
	for c in discard_pile_root.get_children():
		c.queue_free()
	var card_m := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(0.22, 0.32)
	card_m.mesh = qm
	card_m.rotation_degrees = Vector3(-90.0, randf_range(-14.0, 14.0), 0.0)
	card_m.position = Vector3(0.0, 0.008, 0.0)
	var pid := str(card.get("power_id", ""))
	var tpath := "res://assets/cards/%s.png" % pid if pid != "" else "res://assets/cards/%s_%s.png" % [card["suit"], card["rank"]]
	var tex := Toon.tex(tpath)
	var mat := ShaderMaterial.new()
	mat.shader = CARD_FX_SHADER
	mat.set_shader_parameter("use_texture", tex != null)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
	var ed := Catalog.normalize_card_class(str(card.get("edition", "NORMAL")))
	var ed_info := Catalog.get_card_class(ed)
	mat.set_shader_parameter("albedo", Color(0.95, 0.92, 0.85))
	mat.set_shader_parameter("edition_id", int(ed_info.get("shader_id", 0)))
	mat.set_shader_parameter("is_power_card", 1.0 if pid != "" else 0.0)
	mat.set_shader_parameter("accent_color", card.get("accent", ed_info.get("col", Color(1.0, 0.84, 0.32))))
	card_m.material_override = mat
	discard_pile_root.add_child(card_m)


func _load_mp_character_glb(char_id: String, fallback_col: Color) -> Node3D:
	var c_info := Config.get_character(char_id)
	var path := str(c_info.get("glb", "res://assets/models/mp/mp_char_guillotine.glb"))
	if ResourceLoader.exists(path):
		var ps := ResourceLoader.load(path) as PackedScene
		if ps != null:
			var inst := ps.instantiate()
			if inst is Node3D:
				return inst as Node3D
	var abs_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_p):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(abs_p, state) == OK:
			var gen := doc.generate_scene(state)
			if gen is Node3D:
				return gen as Node3D
	# Fallback procedural bust if Blender GLB not yet imported
	var fb := Node3D.new()
	var torso := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 0.15; tm.bottom_radius = 0.22; tm.height = 0.42
	torso.mesh = tm; torso.position = Vector3(0.0, 0.21, 0.0)
	torso.material_override = Toon.mat(fallback_col.darkened(0.35))
	fb.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.115
	head.mesh = hm; head.position = Vector3(0.0, 0.50, 0.0)
	head.material_override = Toon.mat(Color(0.20, 0.16, 0.17))
	fb.add_child(head)
	return fb


func _rebuild_seat_hand_3d(si: int, seat_pub: Dictionary) -> void:
	if not seat_nodes.has(si) or si == my_seat:
		return
	var sn: Dictionary = seat_nodes[si]
	var hgrp: Node3D = sn["hand_grp"]
	for c in hgrp.get_children():
		c.queue_free()
	if not bool(seat_pub["alive"]):
		return

	# Sync card-grip anchor cleanly to the sculpted character's left/right palms so cards sit visibly IN their hands!
	var hl: Node3D = sn.get("hand_l_hold")
	var hr: Node3D = sn.get("hand_r_hold")
	var sroot: Node3D = sn.get("root")
	var grip_span := 0.22
	if is_instance_valid(hl) and is_instance_valid(hr) and is_instance_valid(sroot):
		var lp := sroot.to_local(hl.global_position)
		var rp := sroot.to_local(hr.global_position)
		hgrp.position = (lp + rp) * 0.5 + Vector3(0.0, 0.065, -0.020)
		grip_span = clampf(lp.distance_to(rp), 0.16, 0.34)
	# Orient card backs outward toward the center of the table (-Z in seat local) so every opponent's cards are 100% visible!
	hgrp.rotation_degrees = Vector3(0.0, 180.0, 0.0)

	var revealed: Array = seat_pub.get("revealed_cards", [])
	var count := revealed.size() if not revealed.is_empty() else clampi(int(seat_pub.get("hand_count", 4)), 0, 8)
	if int(seat_pub.get("hand_count", 0)) == -1:
		count = 4
	if count <= 0:
		return
	var step_x := clampf(grip_span / float(maxi(2, count)), 0.038, 0.066)
	var back_map := {
		"CHAR_GUILLOTINE": "res://assets/table/deck_back_obsidian.png",
		"CHAR_MONARCH": "res://assets/table/deck_back_stredovek.png",
		"CHAR_JESTER": "res://assets/table/deck_back_prohibicia.png",
		"CHAR_MISTBLADE": "res://assets/table/deck_back_astral.png",
	}
	var cid := str(sn.get("char_id", "CHAR_GUILLOTINE"))
	var back_tex_p := str(back_map.get(cid, "res://assets/table/card_back.png"))
	for i in range(count):
		var croot := MeshInstance3D.new()
		var cbox := BoxMesh.new(); cbox.size = Vector3(0.128, 0.190, 0.004)
		croot.mesh = cbox
		var fan := (float(i) - float(count - 1) * 0.5)
		croot.position = Vector3(fan * step_x, -absf(fan) * 0.008, float(i) * 0.004 - absf(fan) * 0.004)
		croot.rotation_degrees = Vector3(14.0, -fan * 5.0, -fan * 6.5)
		var cmat := StandardMaterial3D.new()
		cmat.roughness = 0.52
		cmat.metallic = 0.14
		cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if not revealed.is_empty() and i < revealed.size():
			var rc: Dictionary = revealed[i]
			var rpath := "res://assets/cards/%s.png" % str(rc.get("power_id", "")) if str(rc.get("power_id", "")) != "" else "res://assets/cards/%s_%s.png" % [rc["suit"], rc["rank"]]
			cmat.albedo_color = Color.WHITE
			var rtex := Toon.tex(rpath)
			if rtex != null:
				cmat.albedo_texture = rtex
		else:
			var cloaked := bool(seat_pub["mist_cloaked"])
			cmat.albedo_color = Color(0.96, 0.94, 0.90) if not cloaked else Color(0.55, 0.92, 1.0)
			var btex := Toon.tex(back_tex_p)
			if btex != null:
				cmat.albedo_texture = btex
			if cloaked:
				cmat.emission_enabled = true
				cmat.emission = Color(0.18, 0.48, 0.62)
				cmat.emission_energy_multiplier = 0.65
		croot.material_override = cmat
		hgrp.add_child(croot)


func _get_pub_seat(si: int) -> Dictionary:
	for s in public_state.get("seats", []):
		if int(s["seat_idx"]) == si:
			return s
	return {}


func _is_valid_opponent_target(si: int) -> bool:
	if si == my_seat or si < 0:
		return false
	var s := _get_pub_seat(si)
	return not s.is_empty() and bool(s.get("alive", false))


func _first_alive_opponent() -> int:
	for s in public_state.get("seats", []):
		var si := int(s["seat_idx"])
		if si != my_seat and bool(s["alive"]):
			return si
	return 0
