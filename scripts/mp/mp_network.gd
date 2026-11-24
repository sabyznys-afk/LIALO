class_name MpNetwork
extends Node

## ENet Multiplayer Transport + Lobby/Authority Bridge for Downpour (2-4 Players, Experimental).
## Host runs MpAuthority and keeps hidden hands secret via per-peer rpc_id(peer_id).

const Config = preload("res://scripts/mp/mp_config.gd")
const AuthorityScript = preload("res://scripts/mp/mp_authority.gd")

signal lobby_updated(seats: Array, settings: Dictionary)
signal status_changed(msg: String, is_err: bool)
signal match_started(public_state: Dictionary)
signal public_state_received(state: Dictionary)
signal private_hand_received(my_seat: int, hand: Array, items: Array, meta: Dictionary)
signal vfx_event_received(evt: Dictionary)
signal match_ended(winner_seat: int, summary: Dictionary)
signal session_closed(reason: String)
signal host_network_ready(info: Dictionary)

const CONNECT_TIMEOUT_SEC := 10.0

var is_host: bool = false
var in_session: bool = false
var in_match: bool = false
var my_peer_id: int = 1
var my_seat_idx: int = 0
var local_name: String = "Duelist"
var local_deck_cfg: Dictionary = {"archetype_id": "GUILLOTINE_ACES", "extra_aces": 4}

var lobby_seats: Array = []
var room_settings: Dictionary = {"rule_mode": Config.RULE_CAMPAIGN_VAULT}
var authority: AuthorityScript = null
var _bot_seq: int = 1
var last_public_state: Dictionary = {}
var last_private_packet: Dictionary = {}

var _is_connecting: bool = false
var _connect_elapsed: float = 0.0
var _host_port: int = Config.DEFAULT_PORT
var _upnp_thread: Thread = null
var _upnp_instance: UPNP = null
var _upnp_mapped_port: int = 0
var _upnp_stop_requested: bool = false
var _upnp_ok: bool = false
var _upnp_pending: bool = false
var _upnp_external_ip: String = ""
var _upnp_error: String = ""


func _ready() -> void:
	name = "MpNetwork"


func _exit_tree() -> void:
	_cleanup_upnp()


func _process(delta: float) -> void:
	if is_host and in_match and authority != null:
		authority.tick(delta)
	if _is_connecting and not is_host and in_session:
		_connect_elapsed += delta
		if _connect_elapsed >= CONNECT_TIMEOUT_SEC:
			_is_connecting = false
			_connect_elapsed = 0.0
			status_changed.emit("Connection timed out after 10s — check Host IP, Port, or Firewall/UPnP/Radmin/Tailscale.", true)
			leave_room(true)


func host_room(port: int, player_name: String, deck_cfg: Dictionary) -> Error:
	leave_room(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Config.MAX_PLAYERS)
	if err != OK:
		status_changed.emit("Failed to bind port %d (err %d)" % [port, err], true)
		return err

	multiplayer.multiplayer_peer = peer
	_connect_mp_signals()

	is_host = true
	in_session = true
	in_match = false
	_is_connecting = false
	_connect_elapsed = 0.0
	_host_port = port
	my_peer_id = 1
	local_name = player_name.strip_edges()
	if local_name.is_empty():
		local_name = "Host Knight"
	var rmode := str(room_settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	local_deck_cfg = Config.sanitize_deck_cfg(deck_cfg, rmode)
	_bot_seq = 1

	lobby_seats = [{
		"seat_idx": 0,
		"peer_id": 1,
		"name": local_name,
		"is_bot": false,
		"ready": true,
		"deck_cfg": local_deck_cfg.duplicate(true),
	}]
	_broadcast_lobby()
	status_changed.emit("Hosting Table on port %d — Ready for 2–4 Players!" % port, false)
	_start_upnp_async(port)
	host_network_ready.emit(get_host_network_addresses())
	return OK


func join_room(ip: String, port: int, player_name: String, deck_cfg: Dictionary) -> Error:
	leave_room(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), port)
	if err != OK:
		status_changed.emit("Could not connect to %s:%d (err %d)" % [ip, port, err], true)
		return err

	multiplayer.multiplayer_peer = peer
	_connect_mp_signals()

	is_host = false
	in_session = true
	in_match = false
	_is_connecting = true
	_connect_elapsed = 0.0
	local_name = player_name.strip_edges()
	if local_name.is_empty():
		local_name = "Challenger"
	local_deck_cfg = deck_cfg.duplicate(true)
	status_changed.emit("Connecting to %s:%d..." % [ip, port], false)
	return OK


func leave_room(notify: bool = true) -> void:
	_is_connecting = false
	_connect_elapsed = 0.0
	_cleanup_upnp()
	_disconnect_mp_signals()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	authority = null
	is_host = false
	in_session = false
	in_match = false
	lobby_seats.clear()
	my_seat_idx = 0
	last_public_state.clear()
	last_private_packet.clear()
	if notify:
		session_closed.emit("Disconnected from table.")


func get_host_network_addresses() -> Dictionary:
	var lan_ips: Array[String] = []
	for raw_addr in IP.get_local_addresses():
		var addr := str(raw_addr).strip_edges()
		if ":" in addr:
			continue # Skip IPv6
		var parts := addr.split(".")
		if parts.size() != 4:
			continue
		var a := int(parts[0])
		var b := int(parts[1])
		var is_lan := (a == 192 and b == 168) or (a == 10) or (a == 172 and b >= 16 and b <= 31)
		if is_lan and not (addr in lan_ips):
			lan_ips.append(addr)

	var primary_lan := "127.0.0.1"
	for ip_s in lan_ips:
		if ip_s.begins_with("192.168."):
			primary_lan = ip_s
			break
	if primary_lan == "127.0.0.1" and not lan_ips.is_empty():
		primary_lan = lan_ips[0]

	return {
		"port": _host_port,
		"lan_ip": primary_lan,
		"lan_ips": lan_ips,
		"public_ip": _upnp_external_ip,
		"upnp_ok": _upnp_ok,
		"upnp_pending": _upnp_pending,
		"upnp_error": _upnp_error,
	}


func _start_upnp_async(port: int) -> void:
	_cleanup_upnp()
	_upnp_stop_requested = false
	_upnp_pending = true
	_upnp_ok = false
	_upnp_external_ip = ""
	_upnp_error = ""
	_upnp_thread = Thread.new()
	var err := _upnp_thread.start(_upnp_worker.bind(port))
	if err != OK:
		_upnp_pending = false
		_upnp_error = "Could not start UPnP thread"
		_upnp_thread = null


func _upnp_worker(port: int) -> void:
	var upnp := UPNP.new()
	var discover_res := upnp.discover(2500, 2, "InternetGatewayDevice")
	if _upnp_stop_requested:
		return
	if discover_res != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_on_upnp_finished", false, "", "UPnP gateway not found (code %d)" % discover_res, null, port)
		return
	var gw := upnp.get_gateway()
	if gw == null or not gw.is_valid_gateway():
		call_deferred("_on_upnp_finished", false, "", "No valid UPnP gateway", null, port)
		return
	var map_res := upnp.add_port_mapping(port, port, "Lialo Downpour MP", "UDP", 0)
	var ext_ip := upnp.query_external_address()
	if _upnp_stop_requested:
		if map_res == UPNP.UPNP_RESULT_SUCCESS:
			upnp.delete_port_mapping(port, "UDP")
		return
	if map_res == UPNP.UPNP_RESULT_SUCCESS and not ext_ip.is_empty():
		call_deferred("_on_upnp_finished", true, ext_ip, "", upnp, port)
	else:
		var err_str := "UPnP port mapping failed (code %d)" % map_res if map_res != UPNP.UPNP_RESULT_SUCCESS else "Could not query public IP"
		call_deferred("_on_upnp_finished", false, ext_ip, err_str, upnp if map_res == UPNP.UPNP_RESULT_SUCCESS else null, port)


func _on_upnp_finished(ok: bool, ext_ip: String, err_msg: String, upnp_obj: UPNP, port: int) -> void:
	if _upnp_thread != null and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = null
	if not in_session or not is_host or port != _host_port or _upnp_stop_requested:
		if upnp_obj != null:
			upnp_obj.delete_port_mapping(port, "UDP")
		return
	_upnp_pending = false
	_upnp_ok = ok
	_upnp_external_ip = ext_ip
	_upnp_error = err_msg
	_upnp_instance = upnp_obj
	_upnp_mapped_port = port if ok else 0
	host_network_ready.emit(get_host_network_addresses())


func _cleanup_upnp() -> void:
	_upnp_stop_requested = true
	if _upnp_thread != null and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = null
	if _upnp_instance != null and _upnp_mapped_port > 0:
		_upnp_instance.delete_port_mapping(_upnp_mapped_port, "UDP")
	_upnp_instance = null
	_upnp_mapped_port = 0
	_upnp_ok = false
	_upnp_pending = false
	_upnp_external_ip = ""
	_upnp_error = ""


func update_local_deck(deck_cfg: Dictionary) -> void:
	local_deck_cfg = deck_cfg.duplicate(true)
	if not in_session:
		return
	if is_host:
		_apply_deck_for_peer(1, local_deck_cfg)
	else:
		_rpc_update_deck.rpc_id(1, local_deck_cfg)


func toggle_ready(want_ready: bool) -> void:
	if not in_session:
		return
	if is_host:
		for s in lobby_seats:
			if int(s["peer_id"]) == 1:
				s["ready"] = want_ready
		_broadcast_lobby()
	else:
		_rpc_set_ready.rpc_id(1, want_ready)


func set_rule_mode(mode_id: String) -> void:
	if not is_host:
		return
	room_settings["rule_mode"] = mode_id
	_broadcast_lobby()


func add_test_bot() -> void:
	if not is_host or lobby_seats.size() >= Config.MAX_PLAYERS:
		return
	var archs := Config.DECK_ARCHETYPES
	var chosen_arch: Dictionary = archs[lobby_seats.size() % archs.size()]
	var chosen_char: Dictionary = Config.CHARACTERS[lobby_seats.size() % Config.CHARACTERS.size()]
	var bot_names := ["Baron Černý", "Sestra Mlh", "Šašek Jáchym", "Rytíř Křiván"]
	var bname := "%s [BOT]" % bot_names[(_bot_seq - 1) % bot_names.size()]
	_bot_seq += 1
	lobby_seats.append({
		"seat_idx": lobby_seats.size(),
		"peer_id": -_bot_seq,
		"name": bname,
		"is_bot": true,
		"ready": true,
		"deck_cfg": {
			"character_id": str(chosen_char["id"]),
			"archetype_id": str(chosen_arch["id"]),
			"extra_aces": int(chosen_arch["extra_aces"]),
		},
	})
	_reindex_lobby()
	_broadcast_lobby()


func remove_seat(seat_idx: int) -> void:
	if not is_host or seat_idx <= 0 or seat_idx >= lobby_seats.size():
		return
	var s: Dictionary = lobby_seats[seat_idx]
	if bool(s["is_bot"]):
		lobby_seats.remove_at(seat_idx)
		_reindex_lobby()
		_broadcast_lobby()
	else:
		var pid := int(s["peer_id"])
		multiplayer.multiplayer_peer.disconnect_peer(pid)


func can_start_match() -> Dictionary:
	if not is_host:
		return {"ok": false, "reason": "Only Host starts match."}
	if lobby_seats.size() < Config.MIN_PLAYERS:
		return {"ok": false, "reason": "Need 2–4 players (or +Add Test Bot)."}
	for s in lobby_seats:
		if not bool(s["ready"]):
			return {"ok": false, "reason": "Waiting for %s to Ready up." % str(s["name"])}
	return {"ok": true, "reason": ""}


func start_match() -> void:
	var chk := can_start_match()
	if not bool(chk["ok"]):
		status_changed.emit(str(chk["reason"]), true)
		return

	authority = AuthorityScript.new()
	authority.broadcast_public_state.connect(func(st: Dictionary):
		_rpc_sync_public_state.rpc(st)
	)
	authority.send_private_hand.connect(func(pid: int, s_idx: int, hand: Array, items: Array, meta: Dictionary):
		_rpc_sync_private_hand.rpc_id(pid, s_idx, hand, items, meta)
	)
	authority.broadcast_vfx_event.connect(func(evt: Dictionary):
		_rpc_play_vfx.rpc(evt)
	)
	authority.match_finished.connect(func(winner_seat: int, summary: Dictionary):
		in_match = false
		_rpc_end_match.rpc(winner_seat, summary)
	)

	var rmode := str(room_settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	for s in lobby_seats:
		s["deck_cfg"] = Config.sanitize_deck_cfg(s.get("deck_cfg", {}), rmode)

	in_match = true
	_rpc_begin_match.rpc()
	authority.setup_match(lobby_seats, room_settings)


# --- Match Actions (Client -> Host) ---

func send_play_cards(card_indices: Array, target_seat: int, chosen_suit: String) -> void:
	if not in_session or not in_match:
		return
	_rpc_client_play_cards.rpc_id(1, my_seat_idx, card_indices, target_seat, chosen_suit)


func send_draw_card() -> void:
	if not in_session or not in_match:
		return
	_rpc_client_draw_card.rpc_id(1, my_seat_idx)


func send_use_item(item_id: String, target_seat: int) -> void:
	if not in_session or not in_match:
		return
	_rpc_client_use_item.rpc_id(1, my_seat_idx, item_id, target_seat)


func send_parry(choice: String) -> void:
	if not in_session or not in_match:
		return
	_rpc_client_parry.rpc_id(1, my_seat_idx, choice)


func send_ghost_action(action_id: String, target_seat: int) -> void:
	if not in_session or not in_match:
		return
	_rpc_client_ghost_action.rpc_id(1, my_seat_idx, action_id, target_seat)


# ---------------------------------------------------------------------------
# ENet Peer Connection Hooks
# ---------------------------------------------------------------------------

func _connect_mp_signals() -> void:
	_disconnect_mp_signals()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _disconnect_mp_signals() -> void:
	if multiplayer == null:
		return
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)


func _on_connected_to_server() -> void:
	_is_connecting = false
	_connect_elapsed = 0.0
	my_peer_id = multiplayer.get_unique_id()
	status_changed.emit("Connected! Joining Tavern Table...", false)
	_rpc_register_player.rpc_id(1, local_name, local_deck_cfg, Config.MP_PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	_is_connecting = false
	_connect_elapsed = 0.0
	status_changed.emit("Connection failed (check Host IP/Port).", true)
	leave_room(true)


func _on_server_disconnected() -> void:
	status_changed.emit("Host closed the tavern table.", true)
	leave_room(true)


func _on_peer_connected(id: int) -> void:
	if is_host:
		status_changed.emit("Peer #%d connected..." % id, false)


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	if in_match and authority != null:
		for s in authority.seats:
			if int(s.get("peer_id", 0)) == id and not bool(s.get("is_bot", false)):
				var orig_name := str(s.get("orig_name", ""))
				if orig_name == "":
					orig_name = str(s.get("name", "Player"))
					s["orig_name"] = orig_name
				s["disconnected_human"] = true
				s["is_bot"] = true
				s["name"] = "%s [BOT]" % orig_name
				authority.banner_text = "%s disconnected — Bot took over!" % orig_name
				authority._sync_all()
				authority._queue_bot_if_needed()
				break
		return
	for i in range(lobby_seats.size() - 1, -1, -1):
		if int(lobby_seats[i]["peer_id"]) == id:
			lobby_seats.remove_at(i)
	_reindex_lobby()
	_broadcast_lobby()


func _sender_peer() -> int:
	var pid := multiplayer.get_remote_sender_id()
	return 1 if pid == 0 else pid


func _reindex_lobby() -> void:
	for i in range(lobby_seats.size()):
		lobby_seats[i]["seat_idx"] = i


func _apply_deck_for_peer(pid: int, dcfg: Dictionary) -> void:
	var rmode := str(room_settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	var clean_dcfg := Config.sanitize_deck_cfg(dcfg, rmode)
	for s in lobby_seats:
		if int(s["peer_id"]) == pid:
			s["deck_cfg"] = clean_dcfg
			break
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	if is_host:
		_rpc_sync_lobby.rpc(lobby_seats, room_settings)


# ---------------------------------------------------------------------------
# RPC Definitions
# ---------------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _rpc_register_player(p_name: String, dcfg: Dictionary, client_version: String = "") -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender_peer()
	if client_version != Config.MP_PROTOCOL_VERSION:
		var shown_cver := client_version if not client_version.is_empty() else "legacy"
		_rpc_version_mismatch.rpc_id(sender, Config.MP_PROTOCOL_VERSION, shown_cver)
		status_changed.emit("Peer #%d rejected — version mismatch (Host: v%s, Client: v%s)" % [sender, Config.MP_PROTOCOL_VERSION, shown_cver], true)
		get_tree().create_timer(0.2).timeout.connect(func():
			if multiplayer != null and multiplayer.multiplayer_peer != null and is_host:
				if sender in multiplayer.get_peers():
					multiplayer.multiplayer_peer.disconnect_peer(sender)
		)
		return
	var clean_name := p_name.strip_edges().substr(0, 18)
	if in_match and authority != null:
		for s in authority.seats:
			if bool(s.get("disconnected_human", false)) and (str(s.get("orig_name", "")) == clean_name or str(s.get("orig_name", "")) == p_name):
				var reclaimed_name := clean_name if not clean_name.is_empty() else str(s.get("orig_name", "Player"))
				s["peer_id"] = sender
				s["is_bot"] = false
				s["disconnected_human"] = false
				s["name"] = reclaimed_name
				var s_idx := int(s.get("seat_idx", 0))
				if s_idx >= 0 and s_idx < lobby_seats.size():
					lobby_seats[s_idx]["peer_id"] = sender
					lobby_seats[s_idx]["is_bot"] = false
					lobby_seats[s_idx]["name"] = reclaimed_name
				_rpc_begin_match.rpc_id(sender)
				if authority.has_method("reclaim_seat"):
					authority.reclaim_seat(s_idx, sender)
				authority.banner_text = "%s reconnected and reclaimed their seat!" % reclaimed_name
				authority._sync_all()
				_broadcast_lobby()
				return
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	if in_match or lobby_seats.size() >= Config.MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	for s in lobby_seats:
		if int(s["peer_id"]) == sender:
			return
	if clean_name.is_empty():
		clean_name = "Player %d" % (lobby_seats.size() + 1)
	var rmode := str(room_settings.get("rule_mode", Config.RULE_CAMPAIGN_VAULT))
	var clean_dcfg := Config.sanitize_deck_cfg(dcfg, rmode)
	lobby_seats.append({
		"seat_idx": lobby_seats.size(),
		"peer_id": sender,
		"name": clean_name,
		"is_bot": false,
		"ready": false,
		"deck_cfg": clean_dcfg,
	})
	_reindex_lobby()
	_broadcast_lobby()


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(want_ready: bool) -> void:
	if not multiplayer.is_server() or in_match:
		return
	var pid := _sender_peer()
	for s in lobby_seats:
		if int(s["peer_id"]) == pid:
			s["ready"] = want_ready
	_broadcast_lobby()


@rpc("any_peer", "call_local", "reliable")
func _rpc_update_deck(dcfg: Dictionary) -> void:
	if not multiplayer.is_server() or in_match:
		return
	_apply_deck_for_peer(_sender_peer(), dcfg)


@rpc("any_peer", "call_local", "reliable")
func _rpc_client_play_cards(seat_hint: int, card_indices: Array, target_seat: int, chosen_suit: String) -> void:
	if multiplayer.is_server() and authority != null:
		authority.handle_play_cards(_sender_peer(), seat_hint, card_indices, target_seat, chosen_suit)


@rpc("any_peer", "call_local", "reliable")
func _rpc_client_draw_card(seat_hint: int) -> void:
	if multiplayer.is_server() and authority != null:
		authority.handle_draw_card(_sender_peer(), seat_hint)


@rpc("any_peer", "call_local", "reliable")
func _rpc_client_use_item(seat_hint: int, item_id: String, target_seat: int) -> void:
	if multiplayer.is_server() and authority != null:
		authority.handle_use_item(_sender_peer(), seat_hint, item_id, target_seat)


@rpc("any_peer", "call_local", "reliable")
func _rpc_client_parry(seat_hint: int, choice: String) -> void:
	if multiplayer.is_server() and authority != null:
		authority.handle_parry_response(_sender_peer(), seat_hint, choice)


@rpc("any_peer", "call_local", "reliable")
func _rpc_client_ghost_action(seat_hint: int, action_id: String, target_seat: int) -> void:
	if multiplayer.is_server() and authority != null:
		authority.handle_ghost_action(_sender_peer(), seat_hint, action_id, target_seat)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_lobby(seats_data: Array, settings_data: Dictionary) -> void:
	lobby_seats = seats_data.duplicate(true)
	room_settings = settings_data.duplicate(true)
	var mine := multiplayer.get_unique_id()
	for s in lobby_seats:
		if int(s["peer_id"]) == mine:
			my_seat_idx = int(s["seat_idx"])
			break
	lobby_updated.emit(lobby_seats, room_settings)


@rpc("authority", "call_local", "reliable")
func _rpc_begin_match() -> void:
	in_match = true
	last_public_state.clear()
	last_private_packet.clear()
	match_started.emit({})


@rpc("authority", "call_local", "reliable")
func _rpc_sync_public_state(state: Dictionary) -> void:
	last_public_state = state
	public_state_received.emit(state)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_private_hand(s_idx: int, hand: Array, items: Array, meta: Dictionary) -> void:
	my_seat_idx = s_idx
	last_private_packet = {"seat": s_idx, "hand": hand, "items": items, "meta": meta}
	private_hand_received.emit(s_idx, hand, items, meta)


@rpc("authority", "call_local", "reliable")
func _rpc_play_vfx(evt: Dictionary) -> void:
	vfx_event_received.emit(evt)


@rpc("authority", "reliable")
func _rpc_version_mismatch(host_ver: String, client_ver: String) -> void:
	var msg := "Neshodná verze hry! Host: v%s, Ty: v%s — stáhněte oba nejnovější verzi z Gitu. (Version mismatch!)" % [host_ver, client_ver]
	status_changed.emit(msg, true)
	leave_room(true)


@rpc("authority", "call_local", "reliable")
func _rpc_end_match(winner_seat: int, summary: Dictionary) -> void:
	in_match = false
	match_ended.emit(winner_seat, summary)
