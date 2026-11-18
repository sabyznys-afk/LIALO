class_name MpDevEntry
extends Node

## Experimental Dev-Only Coordinator for 2-4P Multiplayer Test Mode.
## Isolated completely from singleplayer Campaign / Skirmish / BattleTable3D.

const Config = preload("res://scripts/mp/mp_config.gd")
const NetScript = preload("res://scripts/mp/mp_network.gd")
const LobbyScript = preload("res://scripts/mp/mp_lobby_overlay.gd")
const ArenaScript = preload("res://scripts/mp/mp_battle_table_3d.gd")

var _root: Node = null
var _menu_ctrl: Control = null
var _mp_net: Node = null
var _lobby: Control = null
var _arena: Node3D = null
var _dev_btn: Button = null


func attach(downpour_root: Node, menu_control: Control) -> void:
	if not Config.is_test_mp_available():
		return
	_root = downpour_root
	_menu_ctrl = menu_control

	_mp_net = NetScript.new()
	_mp_net.name = "MpNetwork"
	_root.add_child(_mp_net)
	_mp_net.match_started.connect(_on_match_started)
	_mp_net.session_closed.connect(func(_reason: String):
		if is_instance_valid(_arena):
			_exit_arena_to_lobby()
	)

	_build_dev_menu_button()
	if "--mp-test" in OS.get_cmdline_args():
		call_deferred("_auto_open_mp_test")


func _build_dev_menu_button() -> void:
	if not is_instance_valid(_menu_ctrl):
		return
	_dev_btn = Button.new()
	_dev_btn.name = "MpDevTestBtn"
	_dev_btn.text = "⚗ MP TEST (2–4P) [DEV]"
	_dev_btn.tooltip_text = "Experimental 2-4 Player Tavern Brawl test mode (hidden in release builds)"
	_dev_btn.anchor_left = 0.0
	_dev_btn.anchor_top = 0.0
	_dev_btn.offset_left = 216
	_dev_btn.offset_top = 14
	_dev_btn.offset_right = 432
	_dev_btn.offset_bottom = 54
	_dev_btn.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.28, 0.14, 0.08, 0.92)
	sb.border_color = Color(0.98, 0.72, 0.24, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	_dev_btn.add_theme_stylebox_override("normal", sb)
	_dev_btn.pressed.connect(open_lobby)
	_menu_ctrl.add_child(_dev_btn)


func _auto_open_mp_test() -> void:
	if is_instance_valid(_root) and _root.has_method("_switch_to"):
		_root.call("_switch_to", 1) # ScreenState.MAIN_MENU
	open_lobby()


func open_lobby() -> void:
	_play_click()
	if is_instance_valid(_lobby):
		_lobby.visible = true
		return
	_lobby = LobbyScript.new()
	_lobby.configure(_mp_net)
	_lobby.close_requested.connect(func():
		if is_instance_valid(_lobby):
			_lobby.queue_free()
			_lobby = null
	)
	_lobby.play_click_sfx.connect(_play_click)
	if is_instance_valid(_menu_ctrl):
		_menu_ctrl.add_child(_lobby)
	else:
		_root.add_child(_lobby)


func _on_match_started(_init: Dictionary) -> void:
	if is_instance_valid(_lobby):
		_lobby.visible = false
	if is_instance_valid(_menu_ctrl):
		_menu_ctrl.visible = false

	if is_instance_valid(_arena):
		_arena.queue_free()
	_arena = ArenaScript.new()
	_arena.position = Vector3(-500.0, 0.0, -500.0)
	var muted := bool(_root.get("audio_muted")) if _root else false
	var vpct := int(_root.get("audio_volume_pct")) if _root else 85
	_arena.configure(_mp_net, muted, vpct)
	if _arena.woodcut_mat and _root and _root.get("woodcut_mode") != null:
		_arena.woodcut_mat.set_shader_parameter("print_mode", int(_root.get("woodcut_mode")))
	_arena.play_sfx_requested.connect(func(sn: String):
		if is_instance_valid(_root) and _root.has_method("_play_sfx"):
			_root.call("_play_sfx", sn, -5.0, randf_range(0.96, 1.04))
	)
	_arena.exit_mp_requested.connect(func():
		if _mp_net and _mp_net.in_session:
			_mp_net.leave_room(false)
		_exit_arena_to_lobby()
	)
	_root.add_child(_arena)
	if is_instance_valid(_arena.woodcut_mat) and _root:
		_arena.woodcut_mat.set_shader_parameter("print_mode", int(_root.get("woodcut_mode")))


func _exit_arena_to_lobby() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
		_arena = null
	if is_instance_valid(_menu_ctrl):
		_menu_ctrl.visible = true
	open_lobby()


func _play_click() -> void:
	if is_instance_valid(_root) and _root.has_method("_play_sfx"):
		_root.call("_play_sfx", "ui_click")
