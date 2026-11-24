class_name MpHistory
extends RefCounted

## Persistent Multiplayer Preferences, Recent Opponents, W-L Records, and Quick Rematch History.

const HISTORY_PATH := "user://lialo_mp_history.json"
const MAX_RECENT_PLAYERS := 12


static func _resolve_path(path_override: String = "") -> String:
	return path_override if path_override != "" else HISTORY_PATH


static func get_default_data() -> Dictionary:
	return {
		"player_name": "",
		"last_ip": "127.0.0.1",
		"last_port": 24780,
		"last_character_id": "CHAR_GUILLOTINE",
		"last_archetype_id": "GUILLOTINE_ACES",
		"last_extra_aces": 4,
		"last_vista_era": "stredovek",
		"recent_players": [],
	}


static func load_data(path_override: String = "") -> Dictionary:
	var p := _resolve_path(path_override)
	var out := get_default_data()
	if not FileAccess.file_exists(p):
		return out
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return out
	var txt := f.get_as_text()
	f.close()
	if txt.strip_edges().is_empty():
		return out
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var d := parsed as Dictionary
	for k in out.keys():
		if d.has(k):
			if k == "recent_players":
				var arr: Array = []
				var raw_rp: Variant = d.get("recent_players", [])
				if raw_rp is Array:
					for item in raw_rp:
						if item is Dictionary:
							arr.append((item as Dictionary).duplicate(true))
				out["recent_players"] = arr
			else:
				out[k] = d[k]
	return out


static func save_data(data: Dictionary, path_override: String = "") -> void:
	var p := _resolve_path(path_override)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


static func save_prefs(prefs: Dictionary, path_override: String = "") -> void:
	var data := load_data(path_override)
	var allowed_keys := [
		"player_name",
		"last_ip",
		"last_port",
		"last_character_id",
		"last_archetype_id",
		"last_extra_aces",
		"last_vista_era",
	]
	for k in allowed_keys:
		if prefs.has(k):
			data[k] = prefs[k]
	save_data(data, path_override)


static func record_opponent(
	opp_name: String,
	ip: String,
	port: int,
	they_hosted: bool,
	character_id: String,
	local_won: int,
	path_override: String = ""
) -> void:
	var clean_name := opp_name.strip_edges()
	if clean_name.is_empty():
		return
	var clean_ip := ip.strip_edges()
	var clean_port := clampi(port, 1024, 65535)
	var data := load_data(path_override)
	var rp: Array = data.get("recent_players", [])
	var lower_name := clean_name.to_lower()
	var existing_idx := -1
	for i in range(rp.size()):
		var entry: Dictionary = rp[i]
		var en_name := str(entry.get("name", "")).strip_edges().to_lower()
		var en_ip := str(entry.get("ip", "")).strip_edges()
		if en_name == lower_name and (clean_ip.is_empty() or en_ip.is_empty() or en_ip == clean_ip):
			existing_idx = i
			break
		if en_name == lower_name:
			existing_idx = i
			break

	var now_unix := int(Time.get_unix_time_from_system())
	var now_str := str(Time.get_datetime_string_from_system(false, true))
	var rec: Dictionary = {}
	if existing_idx != -1:
		rec = (rp[existing_idx] as Dictionary).duplicate(true)
		rp.remove_at(existing_idx)
	else:
		rec = {
			"name": clean_name,
			"ip": clean_ip,
			"port": clean_port,
			"was_host": they_hosted,
			"wins": 0,
			"losses": 0,
			"last_character": character_id,
			"last_played_unix": now_unix,
			"last_played_str": now_str,
		}

	rec["name"] = clean_name
	if not clean_ip.is_empty():
		rec["ip"] = clean_ip
	rec["port"] = clean_port
	if they_hosted:
		rec["was_host"] = true
	elif not rec.has("was_host"):
		rec["was_host"] = false
	if not character_id.is_empty():
		rec["last_character"] = character_id
	if local_won > 0:
		rec["wins"] = int(rec.get("wins", 0)) + 1
	elif local_won < 0:
		rec["losses"] = int(rec.get("losses", 0)) + 1
	rec["last_played_unix"] = now_unix
	rec["last_played_str"] = now_str

	rp.insert(0, rec)
	rp.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last_played_unix", 0)) > int(b.get("last_played_unix", 0))
	)
	if rp.size() > MAX_RECENT_PLAYERS:
		rp.resize(MAX_RECENT_PLAYERS)
	data["recent_players"] = rp
	save_data(data, path_override)


static func remove_opponent(opp_name: String, ip: String, path_override: String = "") -> void:
	var data := load_data(path_override)
	var rp: Array = data.get("recent_players", [])
	var lower_name := opp_name.strip_edges().to_lower()
	var clean_ip := ip.strip_edges()
	var kept: Array = []
	for entry in rp:
		if not (entry is Dictionary):
			continue
		var d := entry as Dictionary
		var en_name := str(d.get("name", "")).strip_edges().to_lower()
		var en_ip := str(d.get("ip", "")).strip_edges()
		var matches_name := (en_name == lower_name)
		var matches_ip := clean_ip.is_empty() or (en_ip == clean_ip)
		if matches_name and matches_ip:
			continue
		kept.append(d)
	data["recent_players"] = kept
	save_data(data, path_override)


static func get_recent_players(path_override: String = "") -> Array:
	var data := load_data(path_override)
	return data.get("recent_players", [])
