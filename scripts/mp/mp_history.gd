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
		"last_mode": "UNRANKED",
		"last_saved_deck_id": "",
		"stats": {
			"wins": 0,
			"losses": 0,
			"elo": 1000,
			"best_slam": 0,
			"streak": 0,
			"best_streak": 0,
			"ranked_wins": 0,
			"ranked_losses": 0,
		},
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
			elif k == "stats":
				var st_out: Dictionary = (out["stats"] as Dictionary).duplicate(true)
				var raw_st: Variant = d.get("stats", {})
				if raw_st is Dictionary:
					for sk in st_out.keys():
						if (raw_st as Dictionary).has(sk):
							st_out[sk] = int((raw_st as Dictionary)[sk])
				out["stats"] = st_out
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
		"last_mode",
		"last_saved_deck_id",
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


static func record_match_result(
	local_won: int,
	best_slam: int = 0,
	is_ranked: bool = false,
	opp_elo: int = 1000,
	path_override: String = ""
) -> Dictionary:
	var data := load_data(path_override)
	var st: Dictionary = data.get("stats", get_default_data()["stats"]).duplicate(true)
	var cur_elo := int(st.get("elo", 1000))
	if best_slam > int(st.get("best_slam", 0)):
		st["best_slam"] = best_slam
	if local_won > 0:
		st["wins"] = int(st.get("wins", 0)) + 1
		if is_ranked:
			st["ranked_wins"] = int(st.get("ranked_wins", 0)) + 1
		var streak := maxi(1, int(st.get("streak", 0)) + 1)
		st["streak"] = streak
		st["best_streak"] = maxi(int(st.get("best_streak", 0)), streak)
		var expected := 1.0 / (1.0 + pow(10.0, float(opp_elo - cur_elo) / 400.0))
		var k_val := 28.0 if is_ranked else 16.0
		st["elo"] = maxi(100, cur_elo + int(round(k_val * (1.0 - expected))))
	elif local_won < 0:
		st["losses"] = int(st.get("losses", 0)) + 1
		if is_ranked:
			st["ranked_losses"] = int(st.get("ranked_losses", 0)) + 1
		st["streak"] = 0
		var expected_l := 1.0 / (1.0 + pow(10.0, float(opp_elo - cur_elo) / 400.0))
		var k_val_l := 24.0 if is_ranked else 12.0
		st["elo"] = maxi(100, cur_elo + int(round(k_val_l * (0.0 - expected_l))))
	data["stats"] = st
	save_data(data, path_override)
	return st


static func get_player_stats(path_override: String = "") -> Dictionary:
	var data := load_data(path_override)
	var st: Dictionary = data.get("stats", get_default_data()["stats"]).duplicate(true)
	var w := int(st.get("wins", 0))
	var l := int(st.get("losses", 0))
	var total := w + l
	st["winrate"] = int(round(float(w) * 100.0 / float(total))) if total > 0 else 0
	st["player_name"] = str(data.get("player_name", "")).strip_edges()
	return st


static func get_rank_tier(elo: int) -> Dictionary:
	if elo >= 1600:
		return {"name": "Grandmaster", "icon": "crown", "col": Color(1.0, 0.82, 0.28)}
	if elo >= 1350:
		return {"name": "Obsidian", "icon": "sword", "col": Color(0.55, 0.90, 1.0)}
	if elo >= 1150:
		return {"name": "Gold", "icon": "trophy", "col": Color(0.96, 0.78, 0.32)}
	if elo >= 1000:
		return {"name": "Silver", "icon": "shield", "col": Color(0.80, 0.86, 0.94)}
	return {"name": "Bronze", "icon": "tavern", "col": Color(0.82, 0.56, 0.36)}


static func get_leaderboard_entries(path_override: String = "") -> Array:
	var data := load_data(path_override)
	var st := get_player_stats(path_override)
	var local_name := str(data.get("player_name", "")).strip_edges()
	if local_name.is_empty():
		local_name = "You (Duelist)"
	var entries: Array = []
	entries.append({
		"name": local_name,
		"is_local": true,
		"wins": int(st.get("wins", 0)),
		"losses": int(st.get("losses", 0)),
		"winrate": int(st.get("winrate", 0)),
		"elo": int(st.get("elo", 1000)),
		"best_slam": int(st.get("best_slam", 0)),
		"character_id": str(data.get("last_character_id", "CHAR_GUILLOTINE")),
		"ip": "",
		"port": 24780,
		"last_played_str": "Active",
	})
	var rp: Array = data.get("recent_players", [])
	for raw_r in rp:
		if not (raw_r is Dictionary):
			continue
		var r := raw_r as Dictionary
		# From rival's perspective: our losses are their wins, our wins are their losses
		var opp_w := int(r.get("losses", 0))
		var opp_l := int(r.get("wins", 0))
		var tot := opp_w + opp_l
		var wr := int(round(float(opp_w) * 100.0 / float(tot))) if tot > 0 else 0
		var opp_elo := maxi(100, int(r.get("elo", 1000 + (opp_w - opp_l) * 18)))
		entries.append({
			"name": str(r.get("name", "Rival")),
			"is_local": false,
			"wins": opp_w,
			"losses": opp_l,
			"my_wins": opp_l,
			"my_losses": opp_w,
			"winrate": wr,
			"elo": opp_elo,
			"best_slam": int(r.get("best_slam", 0)),
			"character_id": str(r.get("last_character", "CHAR_GUILLOTINE")),
			"ip": str(r.get("ip", "")).strip_edges(),
			"port": int(r.get("port", 24780)),
			"last_played_str": str(r.get("last_played_str", "")),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("elo", 1000)) != int(b.get("elo", 1000)):
			return int(a.get("elo", 1000)) > int(b.get("elo", 1000))
		return int(a.get("wins", 0)) > int(b.get("wins", 0))
	)
	return entries
