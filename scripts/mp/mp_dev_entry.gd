class_name MpDevEntry
extends Node

## Multiplayer Tavern Coordinator (2-4P).
## Manages MpNetwork, MpLobbyOverlay, and MpBattleTable3D cleanly while keeping
## singleplayer Campaign / BattleTable3D isolated.

const Config = preload("res://scripts/mp/mp_config.gd")
const NetScript = preload("res://scripts/mp/mp_network.gd")
const LobbyScript = preload("res://scripts/mp/mp_lobby_overlay.gd")
const ArenaScript = preload("res://scripts/mp/mp_battle_table_3d.gd")

var _root: Node = null
var _menu_ctrl: Control = null
var _mp_net: Node = null
var _lobby_layer: CanvasLayer = null
var _lobby: Control = null
var _arena: Node3D = null


func attach(downpour_root: Node, menu_control: Control) -> void:
	if not Config.is_test_mp_available():
		return
	_root = downpour_root
	_menu_ctrl = menu_control

	_mp_net = NetScript.new()
	_mp_net.name = "MpNetwork"
	_root.add_child(_mp_net)
	_mp_net.match_started.connect(_on_match_started)
	if _mp_net.has_signal("returned_to_lobby"):
		_mp_net.returned_to_lobby.connect(_return_arena_to_lobby_keep_session)
	_mp_net.session_closed.connect(func(_reason: String):
		if is_instance_valid(_arena):
			_exit_arena_to_lobby()
	)

	if "--mp-test" in OS.get_cmdline_args():
		call_deferred("_auto_open_mp_test")


func _auto_open_mp_test() -> void:
	if is_instance_valid(_root) and _root.has_method("_switch_to"):
		_root.call("_switch_to", 1) # ScreenState.MAIN_MENU
	open_lobby()


func open_lobby() -> void:
	_play_click()
	if is_instance_valid(_lobby) and is_instance_valid(_lobby_layer):
		_lobby_layer.visible = true
		_lobby.visible = true
		return
	_free_lobby()
	_lobby_layer = CanvasLayer.new()
	_lobby_layer.name = "MpLobbyCanvasLayer"
	_lobby_layer.layer = 35
	if is_instance_valid(_root):
		_root.add_child(_lobby_layer)
	else:
		add_child(_lobby_layer)

	_lobby = LobbyScript.new()
	_lobby.configure(_mp_net)
	_lobby.close_requested.connect(func():
		_free_lobby()
	)
	_lobby.play_click_sfx.connect(_play_click)
	_lobby_layer.add_child(_lobby)


func _free_lobby() -> void:
	if is_instance_valid(_lobby):
		_lobby.queue_free()
		_lobby = null
	if is_instance_valid(_lobby_layer):
		_lobby_layer.queue_free()
		_lobby_layer = null


func _on_match_started(_init: Dictionary) -> void:
	_free_lobby()
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
	if _arena.has_signal("return_to_lobby_requested"):
		_arena.return_to_lobby_requested.connect(_return_arena_to_lobby_keep_session)
	_arena.exit_mp_requested.connect(func():
		if _mp_net and _mp_net.in_session:
			_mp_net.leave_room(false)
		_exit_arena_to_lobby()
	)
	if _arena.has_signal("open_options_requested"):
		_arena.open_options_requested.connect(func():
			if is_instance_valid(_root) and _root.has_method("_open_options_modal"):
				_root.call("_open_options_modal")
		)
	_root.add_child(_arena)
	if is_instance_valid(_arena.woodcut_mat) and _root:
		_arena.woodcut_mat.set_shader_parameter("print_mode", int(_root.get("woodcut_mode")))
	if is_instance_valid(_root) and _root.has_method("_play_bgm"):
		_root.call("_play_bgm", "battle", true)


func _return_arena_to_lobby_keep_session() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
		_arena = null
	if is_instance_valid(_menu_ctrl):
		_menu_ctrl.visible = true
	if is_instance_valid(_root) and _root.has_method("_play_bgm"):
		_root.call("_play_bgm", "lobby", false)
	open_lobby()


func _exit_arena_to_lobby() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
		_arena = null
	if is_instance_valid(_menu_ctrl):
		_menu_ctrl.visible = true
	if is_instance_valid(_root) and _root.has_method("_play_bgm"):
		_root.call("_play_bgm", "lobby", false)
	open_lobby()


func _play_click() -> void:
	if is_instance_valid(_root) and _root.has_method("_play_sfx"):
		_root.call("_play_sfx", "ui_click")
