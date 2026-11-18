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
const Config = preload("res://scripts/mp/mp_config.gd")

const CARD_FX_SHADER := preload("res://shaders/card_fx.gdshader")
const TABLE_INLAY_SHADER := preload("res://shaders/table_cloth.gdshader")
const WOODCUT_POST_SHADER := preload("res://shaders/woodcut_post.gdshader")

signal exit_mp_requested
signal play_sfx_requested(sname: String)

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

var public_state: Dictionary = {}
var my_seat: int = 0
var my_hand: Array = []
var my_items: Array = []
var selected_indices: Array[int] = []
var selected_target: int = 1
var chosen_wild_suit: String = "CERVEN"
var local_parry_left: float = 0.0
var rmb_down: bool = false
var look_yaw: float = 0.0
var look_pitch: float = 0.0

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
	_build_3d_tavern()
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
	if is_instance_valid(cam):
		var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * cam_kick_shake * 0.025
		cam.position = Vector3(0.0, 1.78, 1.58) + cam_spring.pos_offset + sh
		cam.rotation_degrees = Vector3(-27.0 + look_pitch + cam_spring.get_pitch_kick(), look_yaw, cam_spring.rot_offset_deg.z)
		cam.fov = 50.0 + cam_spring.get_fov_kick()
		cam_spring.apply_to_camera(cam)

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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			rmb_down = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and is_instance_valid(cam):
			_try_click_3d_seat(mb.position)
	elif event is InputEventMouseMotion and rmb_down:
		var mm := event as InputEventMouseMotion
		look_yaw = clampf(look_yaw - mm.relative.x * 0.16, -34.0, 34.0)
		look_pitch = clampf(look_pitch - mm.relative.y * 0.14, -18.0, 14.0)


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
	e.background_color = Color(0.05, 0.04, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.28, 0.24)
	e.ambient_light_energy = 0.85
	e.glow_enabled = true
	e.glow_intensity = 0.72
	env.environment = e
	add_child(env)

	var key_light := OmniLight3D.new()
	key_light.position = Vector3(0.0, 2.55, 0.15)
	key_light.light_color = Color(1.0, 0.84, 0.62)
	key_light.light_energy = 2.8
	key_light.omni_range = 6.5
	add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(0.0, 1.9, -2.4)
	rim_light.light_color = Color(0.38, 0.54, 0.78)
	rim_light.light_energy = 1.6
	rim_light.omni_range = 6.0
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

	# Tavern Floor + Backdrop
	var floor_m := MeshInstance3D.new()
	var fl_p := PlaneMesh.new(); fl_p.size = Vector2(14.0, 14.0)
	floor_m.mesh = fl_p
	floor_m.material_override = Toon.mat(Color(0.16, 0.14, 0.14), "res://assets/table/stone_floor.png", 0.0, Vector2(5.0, 5.0))
	add_child(floor_m)

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
	cam.fov = 50.0
	cam.position = Vector3(0.0, 1.78, 1.58)
	cam.rotation_degrees = Vector3(-27.0, 0.0, 0.0)
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

		# Personal Draw Deck stack to the right of the player
		var deck_m := MeshInstance3D.new()
		var dbox := BoxMesh.new(); dbox.size = Vector3(0.14, 0.055, 0.20)
		deck_m.mesh = dbox
		deck_m.position = Vector3(0.28, 0.028, 0.06)
		deck_m.material_override = Toon.mat(scol.darkened(0.25), "res://assets/table/card_back.png")
		sroot.add_child(deck_m)

		# Seat's Forged 3D Sword on the left (or tucked neatly on felt to the right for local player!)
		var sword_p := Node3D.new()
		sword_p.position = Vector3(0.46, 0.032, -0.34) if si == my_seat else Vector3(-0.27, 0.035, 0.02)
		var sw_skin := Catalog.get_sword_skin(str(s.get("sword_skin", "SWORD_RUNE")))
		var sw_col: Color = sw_skin.get("col", Color(0.75, 0.82, 0.90))
		var blade_m := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.034, 0.012, 0.44)
		blade_m.mesh = bm; blade_m.position = Vector3(0.0, 0.0, -0.22)
		blade_m.material_override = Toon.mat(sw_col, "", 0.02, Vector2.ONE, sw_skin.get("trail_col", scol) * 0.45)
		sword_p.add_child(blade_m)
		var guard_m := MeshInstance3D.new()
		var gm := BoxMesh.new(); gm.size = Vector3(0.13, 0.016, 0.026)
		guard_m.mesh = gm; guard_m.position = Vector3(0.0, 0.0, -0.02)
		guard_m.material_override = Toon.mat(Color(0.84, 0.64, 0.24))
		sword_p.add_child(guard_m)
		sroot.add_child(sword_p)

		# Opponent Hand + Character Avatar (hidden for local seat 0 so camera never clips)
		var hand_grp := Node3D.new()
		hand_grp.position = Vector3(0.0, 0.20, 0.04)
		sroot.add_child(hand_grp)

		var avatar := Node3D.new()
		avatar.position = Vector3(0.0, 0.04, 0.34)
		avatar.scale = Vector3(0.84, 0.84, 0.84)
		var torso := MeshInstance3D.new()
		var tm := CylinderMesh.new(); tm.top_radius = 0.14; tm.bottom_radius = 0.22; tm.height = 0.38
		torso.mesh = tm; torso.position = Vector3(0.0, 0.16, 0.0)
		torso.material_override = Toon.mat(scol.darkened(0.40))
		avatar.add_child(torso)
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new(); hm.radius = 0.115
		head.mesh = hm; head.position = Vector3(0.0, 0.44, 0.0)
		head.material_override = Toon.mat(Color(0.18, 0.15, 0.16))
		avatar.add_child(head)
		avatar.visible = (si != my_seat)
		sroot.add_child(avatar)

		var lbl := Label3D.new()
		lbl.position = Vector3(0.0, 0.34, -0.04)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 22
		lbl.outline_size = 5
		lbl.pixel_size = 0.0020
		lbl.visible = (si != my_seat)
		sroot.add_child(lbl)

		seat_nodes[si] = {
			"root": sroot,
			"avatar": avatar,
			"hand_grp": hand_grp,
			"deck_mesh": deck_m,
			"sword": sword_p,
			"turn_ring": ring,
			"lbl": lbl,
		}


# ---------------------------------------------------------------------------
# HUD & Controls (MP Test Strip, Cards, Items, Parry, Ghost, Victory)
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(hud_root)

	# Top Bar: Test Badge + Turn Strip + Leave Button
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.0; top_panel.anchor_right = 1.0
	top_panel.offset_left = 12; top_panel.offset_right = -12; top_panel.offset_top = 10; top_panel.offset_bottom = 66
	hud_root.add_child(top_panel)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_hb)

	var dev_tag := Label.new()
	dev_tag.text = " ⚗ EXPERIMENTAL MP (2–4P) "
	dev_tag.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	dev_tag.add_theme_font_size_override("font_size", 14)
	top_hb.add_child(dev_tag)

	turn_strip_box = HBoxContainer.new()
	turn_strip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_strip_box.add_theme_constant_override("separation", 10)
	top_hb.add_child(turn_strip_box)

	status_info_lbl = Label.new()
	status_info_lbl.text = "Suit: ♥  •  R1"
	status_info_lbl.add_theme_font_size_override("font_size", 15)
	top_hb.add_child(status_info_lbl)

	var exit_btn := Button.new()
	exit_btn.text = "← Leave"
	exit_btn.custom_minimum_size = Vector2(96, 0)
	exit_btn.pressed.connect(func(): exit_mp_requested.emit())
	top_hb.add_child(exit_btn)

	# Center Action Banner
	center_banner_lbl = Label.new()
	center_banner_lbl.anchor_left = 0.15; center_banner_lbl.anchor_right = 0.85
	center_banner_lbl.offset_top = 74; center_banner_lbl.offset_bottom = 110
	center_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_banner_lbl.add_theme_font_size_override("font_size", 19)
	center_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	center_banner_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03, 0.95))
	center_banner_lbl.add_theme_constant_override("outline_size", 5)
	center_banner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(center_banner_lbl)

	# Bottom Tray: Target Selection + Hand Cards + Action & OP Item Bars
	var bot_vb := VBoxContainer.new()
	bot_vb.anchor_left = 0.03; bot_vb.anchor_right = 0.97
	bot_vb.anchor_top = 1.0; bot_vb.anchor_bottom = 1.0
	bot_vb.offset_top = -238; bot_vb.offset_bottom = -10
	bot_vb.add_theme_constant_override("separation", 6)
	hud_root.add_child(bot_vb)

	var meta_hb := HBoxContainer.new()
	meta_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_hb.add_theme_constant_override("separation", 18)
	bot_vb.add_child(meta_hb)

	target_bar = HBoxContainer.new()
	target_bar.add_theme_constant_override("separation", 8)
	meta_hb.add_child(target_bar)

	items_bar = HBoxContainer.new()
	items_bar.add_theme_constant_override("separation", 8)
	meta_hb.add_child(items_bar)

	suit_pick_bar = HBoxContainer.new()
	suit_pick_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	suit_pick_bar.add_theme_constant_override("separation", 10)
	suit_pick_bar.visible = false
	for s in Config.SUITS:
		var sb := Button.new()
		sb.text = "Next Suit: %s %s" % [s["sym"], s["name"]]
		var sid := str(s["id"])
		sb.pressed.connect(func():
			chosen_wild_suit = sid
			_refresh_target_and_actions()
		)
		suit_pick_bar.add_child(sb)
	bot_vb.add_child(suit_pick_bar)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 134)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bot_vb.add_child(hand_scroll)

	hand_bar = HBoxContainer.new()
	hand_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_bar.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_bar)

	action_bar = HBoxContainer.new()
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", 14)
	bot_vb.add_child(action_bar)

	slam_btn = Button.new()
	slam_btn.custom_minimum_size = Vector2(240, 40)
	slam_btn.text = "⚔ SLAM CARDS"
	slam_btn.pressed.connect(_on_slam_pressed)
	action_bar.add_child(slam_btn)

	draw_btn = Button.new()
	draw_btn.custom_minimum_size = Vector2(200, 40)
	draw_btn.text = "🃏 DRAW CARD"
	draw_btn.pressed.connect(func():
		if mp_net:
			mp_net.send_draw_card()
	)
	action_bar.add_child(draw_btn)

	# Parry / Interrupt Modal (Only pops on the victim when Execution lands!)
	parry_panel = PanelContainer.new()
	parry_panel.anchor_left = 0.25; parry_panel.anchor_right = 0.75
	parry_panel.anchor_top = 0.28; parry_panel.anchor_bottom = 0.56
	parry_panel.visible = false
	hud_root.add_child(parry_panel)
	var pvb := VBoxContainer.new()
	pvb.alignment = BoxContainer.ALIGNMENT_CENTER
	pvb.add_theme_constant_override("separation", 12)
	parry_panel.add_child(pvb)
	parry_title_lbl = Label.new()
	parry_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parry_title_lbl.add_theme_font_size_override("font_size", 24)
	parry_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.34, 0.28))
	pvb.add_child(parry_title_lbl)
	parry_timer_lbl = Label.new()
	parry_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parry_timer_lbl.add_theme_font_size_override("font_size", 18)
	pvb.add_child(parry_timer_lbl)
	parry_btns_box = HBoxContainer.new()
	parry_btns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	parry_btns_box.add_theme_constant_override("separation", 14)
	pvb.add_child(parry_btns_box)

	# Ghost Strip (When local player is executed/dead)
	ghost_panel = PanelContainer.new()
	ghost_panel.anchor_left = 0.22; ghost_panel.anchor_right = 0.78
	ghost_panel.anchor_top = 0.84; ghost_panel.anchor_bottom = 0.96
	ghost_panel.visible = false
	hud_root.add_child(ghost_panel)
	var ghb := HBoxContainer.new()
	ghb.alignment = BoxContainer.ALIGNMENT_CENTER
	ghb.add_theme_constant_override("separation", 12)
	ghost_panel.add_child(ghb)
	ghost_cd_lbl = Label.new()
	ghost_cd_lbl.text = "👻 TAVERN GHOST — Ready!"
	ghb.add_child(ghost_cd_lbl)
	for ga in [["GHOST_HEX", "💀 Curse Target (-8 HP)"], ["GHOST_BLESS", "✨ Shield Target (+10)"], ["GHOST_SUIT", "🌬 Shift Suit"]]:
		var gb := Button.new()
		gb.text = ga[1]
		var gid: String = ga[0]
		gb.pressed.connect(func():
			if mp_net:
				mp_net.send_ghost_action(gid, selected_target)
		)
		ghb.add_child(gb)

	# Victory Overlay
	victory_panel = PanelContainer.new()
	victory_panel.anchor_left = 0.28; victory_panel.anchor_right = 0.72
	victory_panel.anchor_top = 0.25; victory_panel.anchor_bottom = 0.65
	victory_panel.visible = false
	hud_root.add_child(victory_panel)
	var vvb := VBoxContainer.new()
	vvb.alignment = BoxContainer.ALIGNMENT_CENTER
	vvb.add_theme_constant_override("separation", 16)
	victory_panel.add_child(vvb)
	victory_lbl = Label.new()
	victory_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_lbl.add_theme_font_size_override("font_size", 24)
	vvb.add_child(victory_lbl)
	var vbtn := Button.new()
	vbtn.text = "Return to MP Lobby"
	vbtn.custom_minimum_size = Vector2(220, 44)
	vbtn.pressed.connect(func(): exit_mp_requested.emit())
	vvb.add_child(vbtn)

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
	if is_instance_valid(status_info_lbl):
		status_info_lbl.text = "Suit: %s %s  •  R%d%s" % [s_obj["sym"], s_obj["name"], int(state.get("round_num", 1)), stack_txt]
	if is_instance_valid(center_banner_lbl) and _toast_timer <= 0.0:
		center_banner_lbl.text = str(state.get("banner", ""))

	# Update top center discard card visual if discard count grew
	var top_c: Dictionary = state.get("top_card", {})
	var dcnt := int(state.get("discard_count", 0))
	if not top_c.is_empty() and dcnt != _discard_visual_count:
		_discard_visual_count = dcnt
		_spawn_center_discard_mesh(top_c)

	# Refresh turn strip + 3D seat visuals
	for c in turn_strip_box.get_children():
		c.queue_free()

	for s in seats_arr:
		var si := int(s["seat_idx"])
		var is_alive := bool(s["alive"])
		var is_turn := (si == t_seat and is_alive)
		var pill := Label.new()
		var mark := "▶ " if is_turn else ("" if is_alive else "👻 ")
		pill.text = "%s%s [%d♥|%d🛡|%dg]" % [mark, str(s["name"]), int(s["hp"]), int(s["shields"]), int(s["gold"])]
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
			sn["deck_mesh"].scale.y = clampf(float(s["deck_count"]) / 32.0, 0.15, 1.35)
			sn["avatar"].visible = (si != my_seat)
			if not is_alive:
				sn["avatar"].scale = Vector3(0.72, 0.72, 0.72)
			_rebuild_seat_hand_3d(si, s)

	# Ensure selected target points to a valid alive opponent
	if not _is_valid_opponent_target(selected_target):
		selected_target = _first_alive_opponent()

	# Check local alive / Ghost mode & Parry panel
	var my_pub := _get_pub_seat(my_seat)
	var i_am_alive := bool(my_pub.get("alive", true))
	action_bar.visible = i_am_alive
	hand_bar.visible = i_am_alive
	ghost_panel.visible = not i_am_alive and not bool(state.get("match_over", false))
	if not i_am_alive and is_instance_valid(ghost_cd_lbl):
		var gcd := float(my_pub.get("ghost_cd", 0.0))
		ghost_cd_lbl.text = "👻 TAVERN GHOST — Ready!" if gcd <= 0.1 else ("👻 Recharging (%.1fs)..." % gcd)

	_update_parry_ui(state.get("pending_parry", {}))
	_refresh_target_and_actions()


func _on_private_hand(s_idx: int, hand: Array, items: Array, meta: Dictionary) -> void:
	my_seat = s_idx
	my_hand = hand
	my_items = items
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
			play_sfx_requested.emit("card_slam")
			cam_kick_shake = maxf(cam_kick_shake, 0.35)
			if bool(evt.get("has_sword", false)):
				var cards_arr: Array = evt.get("cards", [])
				var lead_c: Dictionary = cards_arr[0] if not cards_arr.is_empty() else {}
				SwordCardAnim.play_sword_card_mp_strike(
					self,
					lead_c,
					from_p,
					to_p,
					center,
					int(evt.get("dmg", 35)),
					1.6,
					bool(evt.get("is_knight", true))
				)
				cam_spring.trigger_score_recoil(int(evt.get("dmg", 35)) * 3, 2.2, 0.58)
		"PARRY_WINDUP":
			play_sfx_requested.emit("puf")
			cam_kick_shake = 0.55
			Fx.ring(self, center + Vector3(0.0, 0.04, 0.0), Color(1.0, 0.25, 0.22), 1.35, 0.8, 0.08, 2.5, 8.0)
		"PARRY_DEFLECT":
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
			var fs3 := int(evt.get("from_seat", 0))
			var ts3 := int(evt.get("to_seat", 1))
			var vpos := _seat_world_pos(ts3, 1.15)
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
	victory_panel.visible = true
	var wname := str(summary.get("winner_name", "Champion"))
	var you_won := (winner_seat == my_seat)
	victory_lbl.text = "%s\nChampion: %s (%d Turns)" % [
		"👑 VICTORY! LAST DUELIST STANDING!" if you_won else "💀 DEFEATED AT THE TAVERN TABLE",
		wname,
		int(summary.get("rounds", 1)),
	]


# ---------------------------------------------------------------------------
# UI Builders
# ---------------------------------------------------------------------------

func _rebuild_local_hand_ui() -> void:
	for c in hand_bar.get_children():
		c.queue_free()

	for i in range(my_hand.size()):
		var card: Dictionary = my_hand[i]
		var pid := str(card.get("power_id", ""))
		var s_obj := Config.get_suit(str(card.get("suit", "CERVEN")))
		var ed := Catalog.normalize_card_class(str(card.get("edition", "NORMAL")))
		var ed_info := Catalog.get_card_class(ed)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(92, 126)
		btn.toggle_mode = true
		btn.button_pressed = (i in selected_indices)

		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		var tex_path := "res://assets/cards/%s.png" % pid if pid != "" else "res://assets/cards/%s_%s.png" % [card["suit"], card["rank"]]
		var art_tex := Toon.tex(tex_path)
		if art_tex != null:
			var tr := TextureRect.new()
			tr.texture = art_tex
			tr.custom_minimum_size = Vector2(72, 84)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(tr)

		var lbl := Label.new()
		var badge := ""
		if ed == "KNIGHT": badge = " ⚔"
		elif ed == "MAGE": badge = " 🔮"
		elif ed == "THIEF": badge = " 🗡"
		lbl.text = (str(card["rname"]) if pid != "" else "%s %s%s" % [s_obj["sym"], card["rank"], badge])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", ed_info.get("col", s_obj["col"]) if ed != "NORMAL" else s_obj["col"])
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lbl)

		var c_idx := i
		btn.pressed.connect(func():
			if c_idx in selected_indices:
				selected_indices.erase(c_idx)
			else:
				selected_indices.append(c_idx)
			play_sfx_requested.emit("card_hover")
			_refresh_target_and_actions()
		)
		hand_bar.add_child(btn)


func _rebuild_local_items_ui() -> void:
	for c in items_bar.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "OP Items:"
	lbl.add_theme_font_size_override("font_size", 13)
	items_bar.add_child(lbl)
	for raw_it in my_items:
		var it_id := str(raw_it)
		var info: Dictionary = Config.MP_ITEMS.get(it_id, {"name": it_id, "short": "Use", "col": Color.GOLD})
		var ib := Button.new()
		ib.text = "%s (%s)" % [info["name"], info["short"]]
		ib.add_theme_font_size_override("font_size", 12)
		ib.pressed.connect(func():
			if mp_net:
				mp_net.send_use_item(it_id, selected_target)
		)
		items_bar.add_child(ib)


func _refresh_target_and_actions() -> void:
	for c in target_bar.get_children():
		c.queue_free()
	var tlbl := Label.new()
	tlbl.text = "🎯 Target:"
	tlbl.add_theme_font_size_override("font_size", 13)
	target_bar.add_child(tlbl)

	for s in public_state.get("seats", []):
		var si := int(s["seat_idx"])
		if si == my_seat or not bool(s["alive"]):
			continue
		var tb := Button.new()
		var is_sel := (si == selected_target)
		tb.text = "%s%s (%d♥)" % ["► " if is_sel else "", str(s["name"]), int(s["hp"])]
		tb.add_theme_font_size_override("font_size", 12)
		if is_sel:
			tb.modulate = Color(1.0, 0.85, 0.42)
		tb.pressed.connect(func():
			selected_target = si
			play_sfx_requested.emit("card_hover")
			_refresh_target_and_actions()
		)
		target_bar.add_child(tb)

	# Show Suit Picker only when a Queen (H) or Wild Power card is selected!
	var needs_suit := false
	var ace_sel := 0
	for idx in selected_indices:
		if idx >= 0 and idx < my_hand.size():
			var c: Dictionary = my_hand[idx]
			if str(c.get("rank", "")) == "H" or bool(c.get("wild", false)):
				needs_suit = true
			if str(c.get("rank", "")) == "E":
				ace_sel += 1
	suit_pick_bar.visible = needs_suit

	var my_turn: bool = (int(public_state.get("turn_seat", -1)) == my_seat) and public_state.get("pending_parry", {}).is_empty()
	slam_btn.disabled = (not my_turn) or selected_indices.is_empty()
	draw_btn.disabled = not my_turn
	if ace_sel >= 4:
		slam_btn.text = "💀 4× ESO SWORD EXECUTION!"
	elif ace_sel == 3:
		slam_btn.text = "⚔ 3× ESO TRIPLE GUILLOTINE!"
	else:
		slam_btn.text = "⚔ SLAM (%d)" % selected_indices.size() if not selected_indices.is_empty() else "⚔ SLAM CARDS"

	var tax := int(public_state.get("pending_draw_stack", 0))
	draw_btn.text = ("🩸 EAT +%d TAX CARDS" % tax) if tax > 0 else "🃏 DRAW CARD"


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
		mb.pressed.connect(func():
			if mp_net: mp_net.send_parry("MIRROR")
		)
		parry_btns_box.add_child(mb)
	if has_chronos:
		var cb := Button.new()
		cb.text = "⏳ TIME REWIND (CHRONOS +25 HP)"
		cb.custom_minimum_size = Vector2(240, 46)
		cb.pressed.connect(func():
			if mp_net: mp_net.send_parry("CHRONOS")
		)
		parry_btns_box.add_child(cb)

	var brace_btn := Button.new()
	brace_btn.text = "💀 Brace / No Counter"
	brace_btn.custom_minimum_size = Vector2(160, 46)
	brace_btn.pressed.connect(func():
		if mp_net: mp_net.send_parry("BRACE")
	)
	parry_btns_box.add_child(brace_btn)


func _on_slam_pressed() -> void:
	if mp_net == null or selected_indices.is_empty():
		return
	var send_arr: Array = []
	for idx in selected_indices:
		send_arr.append(idx)
	mp_net.send_play_cards(send_arr, selected_target, chosen_wild_suit)


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


func _rebuild_seat_hand_3d(si: int, seat_pub: Dictionary) -> void:
	if not seat_nodes.has(si) or si == my_seat:
		return
	var hgrp: Node3D = seat_nodes[si]["hand_grp"]
	for c in hgrp.get_children():
		c.queue_free()
	if not bool(seat_pub["alive"]):
		return

	var revealed: Array = seat_pub.get("revealed_cards", [])
	var count := revealed.size() if not revealed.is_empty() else clampi(int(seat_pub.get("hand_count", 4)), 0, 8)
	if int(seat_pub.get("hand_count", 0)) == -1:
		count = 4
	for i in range(count):
		var croot := MeshInstance3D.new()
		var qm := QuadMesh.new(); qm.size = Vector2(0.13, 0.19)
		croot.mesh = qm
		var fan := (float(i) - float(count - 1) * 0.5)
		croot.position = Vector3(fan * 0.068, absf(fan) * -0.008, 0.0)
		croot.rotation_degrees = Vector3(-12.0, 0.0, -fan * 7.5)
		if not revealed.is_empty() and i < revealed.size():
			var rc: Dictionary = revealed[i]
			var rpath := "res://assets/cards/%s.png" % str(rc.get("power_id", "")) if str(rc.get("power_id", "")) != "" else "res://assets/cards/%s_%s.png" % [rc["suit"], rc["rank"]]
			croot.material_override = Toon.mat(Color.WHITE, rpath)
		else:
			croot.material_override = Toon.mat(Color(0.78, 0.82, 0.92) if not bool(seat_pub["mist_cloaked"]) else Color(0.55, 0.92, 1.0), "res://assets/table/card_back.png", 0.0, Vector2.ONE, Color(0.16, 0.18, 0.24) if not bool(seat_pub["mist_cloaked"]) else Color(0.18, 0.42, 0.52))
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
