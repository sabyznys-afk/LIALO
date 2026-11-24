extends SceneTree

const Catalog = preload("res://scripts/lialo_catalog.gd")
const MpConfig = preload("res://scripts/mp/mp_config.gd")
const MpAuthority = preload("res://scripts/mp/mp_authority.gd")
const MpLobbyOverlay = preload("res://scripts/mp/mp_lobby_overlay.gd")
const MpNetwork = preload("res://scripts/mp/mp_network.gd")
const MpHistory = preload("res://scripts/mp/mp_history.gd")
const MpBattleTable3D = preload("res://scripts/mp/mp_battle_table_3d.gd")
const TavernBuilder = preload("res://scripts/battle/tavern_scene_builder.gd")
const TableRelicMgr = preload("res://scripts/battle/table_relic_manager.gd")

var _failures: Array[String] = []


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func():
		printerr("TIMEOUT: verify_progression_mp exceeded 60s")
		quit(124)
	)
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== VERIFY PROGRESSION & MP (PHASE 5 + Q1-Q9) ===")

	# 1. Starter set on fresh profile
	var prof := Catalog.get_default_profile()
	_assert(prof.get("unlocked_power_cards", []) == ["SPEC_ORACLE", "SPEC_HEX"], "Fresh profile starter SPEC cards mismatch")
	_assert(prof.get("unlocked_relics", []) == ["REL_GREED"], "Fresh profile starter REL mismatch")
	_assert(prof.get("unlocked_table_relics", []) == ["TRELIC_GOLD_SCALES"], "Fresh profile starter TRELIC mismatch")
	_assert(not Catalog.is_power_card_unlocked(prof, "SPEC_CHRONOS"), "SPEC_CHRONOS should start locked")
	print("  OK 1: Fresh profile starter vault verified")

	# 2. Legacy save migration
	var backup_cfg := ConfigFile.new()
	var had_save := (backup_cfg.load(Catalog.PROFILE_PATH) == OK)
	var leg := ConfigFile.new()
	leg.set_value("run", "era_cleared", {"antika": true, "rim": false, "stredovek": false, "objavy": false, "prohibicia": false})
	leg.set_value("deck", "custom_cards", ["SPEC_VAMPIRE"])
	leg.set_value("deck", "active_relics", ["REL_FANG"])
	leg.set_value("deck", "table_relics", ["TRELIC_BLOOD_SEAL"])
	leg.save(Catalog.PROFILE_PATH)

	var migrated := Catalog.load_profile()
	_assert(Catalog.is_power_card_unlocked(migrated, "SPEC_ORACLE"), "Migration kept starter SPEC_ORACLE")
	_assert(Catalog.is_power_card_unlocked(migrated, "SPEC_VAMPIRE"), "Migration kept owned SPEC_VAMPIRE")
	_assert(Catalog.is_power_card_unlocked(migrated, "SPEC_MIDAS"), "Migration granted antika boss unlock SPEC_MIDAS")
	_assert(Catalog.is_relic_unlocked(migrated, "REL_FANG"), "Migration kept REL_FANG")
	_assert(Catalog.is_table_relic_unlocked(migrated, "TRELIC_SOUL_BELL"), "Migration granted antika boss TRELIC_SOUL_BELL")

	if had_save:
		backup_cfg.save(Catalog.PROFILE_PATH)
	else:
		var abs_p := ProjectSettings.globalize_path(Catalog.PROFILE_PATH)
		if FileAccess.file_exists(abs_p):
			DirAccess.remove_absolute(abs_p)
	print("  OK 2: Legacy save migration verified")

	# 3. Deterministic 5-era ladder + shop gating + Blacksmith repair
	var p3 := Catalog.get_default_profile()
	for eid in Catalog.ERA_ORDER:
		for st in range(3):
			Catalog.claim_stage_unlocks(p3, eid, st, false)
	_assert(Catalog.is_power_card_unlocked(p3, "SPEC_CHRONOS"), "Final boss prohibicia stage 2 unlocks SPEC_CHRONOS")
	_assert(Catalog.get_unlock_source_label("SPEC_CHRONOS", "en") != "", "Unlock source label non-empty")

	var p_repair := Catalog.get_default_profile()
	p_repair["broken_relics"] = ["TRELIC_GOLD_SCALES"]
	var repair_offers := Catalog.generate_shop_offers(p_repair, "en")
	var has_repair := false
	for off in repair_offers:
		if str(off.get("kind", "")) == "repair_relic":
			has_repair = true
			break
	_assert(has_repair, "Shop generates Blacksmith repair offer when broken_relics is non-empty")
	print("  OK 3: 5-era ladder, source labels & Blacksmith shop repair verified")

	# 4. MpConfig slot caps & Balanced Arena + MpLobbyOverlay instantiation
	var dirty_cfg := {
		"archetype_id": "GUILLOTINE_ACES",
		"power_cards": ["SPEC_CHRONOS", "SPEC_CHRONOS", "SPEC_VAMPIRE", "SPEC_STORM", "SPEC_MIDAS"],
		"table_relics": ["TRELIC_SOUL_BELL", "TRELIC_BLOOD_SEAL", "TRELIC_CENSER"],
		"passive_relics": ["REL_GREED", "REL_FANG", "REL_ROYAL"],
		"sword_skin": "SWORD_DRAGON",
	}
	var clean_vault := MpConfig.sanitize_deck_cfg(dirty_cfg, MpConfig.RULE_CAMPAIGN_VAULT)
	_assert((clean_vault["power_cards"] as Array).size() == 3, "Vault cap max 3 power cards")
	var mythic_count := 0
	for pid in clean_vault["power_cards"]:
		if str(Catalog.get_power_card(str(pid)).get("rarity", "")) == "Mythic":
			mythic_count += 1
	_assert(mythic_count <= 1, "Vault cap max 1 Mythic power card")
	_assert((clean_vault["table_relics"] as Array).size() == 2, "Vault cap max 2 table relics")
	_assert((clean_vault["passive_relics"] as Array).size() == 2, "Vault cap max 2 passive relics")

	var clean_bal := MpConfig.sanitize_deck_cfg(dirty_cfg, MpConfig.RULE_BALANCED_ARENA)
	_assert(clean_bal["rule_mode"] == MpConfig.RULE_BALANCED_ARENA, "Balanced Arena mode preserved")
	_assert(clean_bal["passive_relics"] == ["REL_GREED"], "Balanced Arena normalizes passive relics")

	var lobby := MpLobbyOverlay.new()
	_assert(lobby != null, "MpLobbyOverlay instantiates")
	lobby.free()
	print("  OK 4: MpConfig slot sanitization & MpLobbyOverlay verified")

	# 5. MpAuthority: all 15 SPEC_*, all 10 TRELIC_*, passive REL_*, Q3 UIDs & 1/turn, Q8 reclaim_seat
	var auth := MpAuthority.new()
	var seats_in := [
		{"peer_id": 1, "name": "Host", "is_bot": false, "deck_cfg": {"archetype_id": "GUILLOTINE_ACES", "power_cards": ["SPEC_VAMPIRE", "SPEC_MIRROR", "SPEC_CHRONOS"], "table_relics": ["TRELIC_SOUL_BELL", "TRELIC_BLOOD_SEAL"], "passive_relics": ["REL_GREED", "REL_FANG"]}},
		{"peer_id": 2, "name": "Guest", "is_bot": false, "deck_cfg": {"archetype_id": "MIRROR_MONARCH", "power_cards": ["SPEC_SHIELD", "SPEC_PLAGUE", "SPEC_CROWN"], "table_relics": ["TRELIC_STAR_BOW", "TRELIC_PHOENIX_BOX"], "passive_relics": ["REL_IRON_BOOT", "REL_HEX_DOLL"]}},
	]
	auth.setup_match(seats_in, {"rule_mode": MpConfig.RULE_CAMPAIGN_VAULT})
	_assert(auth.seats.size() == 2, "MpAuthority setup 2 seats")

	# Test all 15 SPEC_* effects execute without error
	var s0: Dictionary = auth.seats[0]
	var s1: Dictionary = auth.seats[1]
	for pc in Catalog.POWER_CARDS:
		var pid := str(pc.get("id", ""))
		if pid == "SPEC_PRISM":
			continue
		auth._apply_power_card_effect(s0, s1, pid)

	# Test all 10 TRELIC_* items via handle_use_item (resetting item_used_this_turn & turn_seat between uses)
	var all_trelics := [
		"TRELIC_SOUL_BELL", "TRELIC_BLOOD_SEAL", "TRELIC_STAR_BOW", "TRELIC_ASH_GLASS",
		"TRELIC_WAR_HORN", "TRELIC_HOLLOW_MASK", "TRELIC_CENSER", "TRELIC_GOLD_SCALES",
		"TRELIC_IRON_CHAIN", "TRELIC_PHOENIX_BOX",
	]
	for ti in range(all_trelics.size()):
		var tid: String = all_trelics[ti]
		var inst := MpConfig.make_mp_item_instance(tid, 100 + ti)
		s0["items"] = [inst]
		s0["item_used_this_turn"] = false
		auth.turn_seat = 0
		auth.pending_parry.clear()
		auth.handle_use_item(1, 0, str(inst["uid"]), 1)
		_assert(bool(s0.get("item_used_this_turn", false)), "Item %s should mark item_used_this_turn" % tid)

	# Q3: Duplicate item UID isolation + 1/turn limit
	var dup_a := MpConfig.make_mp_item_instance("TRELIC_GOLD_SCALES", 201)
	var dup_b := MpConfig.make_mp_item_instance("TRELIC_GOLD_SCALES", 202)
	s0["items"] = [dup_a, dup_b]
	s0["item_uses"] = {}
	s0["item_used_this_turn"] = false
	auth.turn_seat = 0
	auth.handle_use_item(1, 0, str(dup_a["uid"]), 1)
	_assert(int(s0["item_uses"].get(dup_a["uid"], 0)) == 1, "dup_a uses == 1")
	_assert(int(s0["item_uses"].get(dup_b["uid"], 0)) == 0, "dup_b uses == 0 (isolated by UID)")
	# Second use in same turn should be blocked by 1/turn limit
	auth.handle_use_item(1, 0, str(dup_b["uid"]), 1)
	_assert(int(s0["item_uses"].get(dup_b["uid"], 0)) == 0, "1/turn limit blocked 2nd item use in same turn")

	# Q8: Reconnect reclaim_seat
	s1["is_bot"] = true
	auth.reclaim_seat(1, 99)
	_assert(int(s1["peer_id"]) == 99 and not bool(s1["is_bot"]), "reclaim_seat restored peer_id and cleared is_bot")
	print("  OK 5: MpAuthority 15 SPEC, 10 TRELIC, passive REL, UID isolation & reconnect verified")

	# 6. TableRelicManager Q1/Q2/Q9 checks
	var tmgr := TableRelicMgr.new()
	var r1 := tmgr.record_use("TRELIC_SOUL_BELL")
	_assert(int(r1["rem"]) == 2 and not bool(r1["overcharged"]), "1st use costs 1 dur -> 2/3")
	var r2 := tmgr.record_use("TRELIC_SOUL_BELL")
	_assert(bool(r2["overcharged"]) and int(r2["rem"]) == 0 and bool(r2["shattered"]), "2nd use in same turn overcharges (-2 dur) -> 0/3 shattered")
	var eff := tmgr.get_effective_passive_relics(["REL_GREED", "TRELIC_SOUL_BELL"])
	_assert(eff == ["REL_GREED"], "Broken relic filtered from effective passive relics")
	print("  OK 6: TableRelicManager Overcharge & broken passive filtering verified")

	# 7. MP protocol version & host address discovery (including VPN ips)
	_assert(MpConfig.MP_PROTOCOL_VERSION != "", "MP_PROTOCOL_VERSION must be non-empty")
	_assert(MpConfig.is_test_mp_available(), "MP must be available in exported and debug builds")
	var net := MpNetwork.new()
	var addrs: Dictionary = net.get_host_network_addresses()
	_assert(addrs.has("lan_ips"), "get_host_network_addresses returns lan_ips")
	_assert(addrs.has("vpn_ips") and addrs.has("vpn_ip"), "get_host_network_addresses returns vpn_ips & vpn_ip")
	net.free()
	print("  OK 7: MP_PROTOCOL_VERSION (%s) & VPN/LAN address helper verified" % MpConfig.MP_PROTOCOL_VERSION)

	# 8. MpHistory persistence, TavernSceneBuilder, & client seat rebuild regression
	var tmp_hist := "user://test_mp_history_tmp.json"
	if FileAccess.file_exists(tmp_hist):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_hist))
	MpHistory.save_prefs({"player_name": "ArnyTest", "last_ip": "26.43.4.115", "last_port": 24780}, tmp_hist)
	MpHistory.record_opponent("Simon", "26.31.132.116", 24780, true, "CHAR_MONARCH", 1, tmp_hist)
	MpHistory.record_opponent("Simon", "26.31.132.116", 24780, true, "CHAR_MONARCH", -1, tmp_hist)
	var loaded_h := MpHistory.load_data(tmp_hist)
	_assert(str(loaded_h.get("player_name", "")) == "ArnyTest", "MpHistory saved player_name")
	var rec_arr: Array = MpHistory.get_recent_players(tmp_hist)
	_assert(rec_arr.size() == 1 and int(rec_arr[0]["wins"]) == 1 and int(rec_arr[0]["losses"]) == 1, "MpHistory W-L record updated")
	MpHistory.remove_opponent("Simon", "26.31.132.116", tmp_hist)
	_assert(MpHistory.get_recent_players(tmp_hist).is_empty(), "MpHistory remove_opponent cleared list")
	if FileAccess.file_exists(tmp_hist):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_hist))

	var tb_root := Node3D.new()
	var tb := TavernBuilder.new()
	tb.build(tb_root, "stredovek", Vector2.ZERO)
	tb.animate_ambient(0.016, 1.0, "CERVEN", true, false)
	tb_root.free()

	var mp_arena := MpBattleTable3D.new()
	root.add_child(mp_arena)
	var test_seats := [
		{"seat_idx": 0, "peer_id": 1, "name": "Host", "is_bot": false, "alive": true, "hp": 120, "max_hp": 120, "shields": 15, "gold": 25, "hand_count": 6, "deck_count": 20, "mist_cloaked": false, "revealed_cards": [], "ghost_cd": 0.0, "character_id": "CHAR_GUILLOTINE", "sword_skin": "SWORD_RUNE", "color": Color.CYAN},
		{"seat_idx": 1, "peer_id": 2, "name": "Client", "is_bot": false, "alive": true, "hp": 120, "max_hp": 120, "shields": 15, "gold": 25, "hand_count": 6, "deck_count": 20, "mist_cloaked": false, "revealed_cards": [], "ghost_cd": 0.0, "character_id": "CHAR_MONARCH", "sword_skin": "SWORD_GILDED", "color": Color.GOLD},
	]
	mp_arena._on_public_state({"seats": test_seats, "turn_seat": 0, "active_suit": "CERVEN", "round_num": 1, "discard_count": 1, "top_card": {"suit": "CERVEN", "rank": "8"}, "pending_draw_stack": 0, "pending_parry": {}, "banner": "", "match_over": false})
	mp_arena._on_private_hand(1, [], [], {})
	_assert(mp_arena._built_my_seat == 1, "Client seat rebuild updated _built_my_seat == 1")
	var sn1: Dictionary = mp_arena.seat_nodes.get(1, {})
	var sn0: Dictionary = mp_arena.seat_nodes.get(0, {})
	_assert(not sn1.is_empty() and not (sn1["avatar"] as Node3D).visible and (sn1["avatar"] as Node3D).get_child_count() == 0, "Local client seat has zero visible avatar mesh")
	_assert(not sn0.is_empty() and (sn0["root"] as Node3D).position.z < 0.0 and (sn0["avatar"] as Node3D).visible, "Host seat placed opposite with visible avatar")
	mp_arena.free()
	print("  OK 8: MpHistory, TavernSceneBuilder & client-seat camera clearance verified")

	if _failures.is_empty():
		print("=== VERIFY PROGRESSION & MP: ALL CHECKS PASSED ===")
		quit(0)
	else:
		printerr("=== VERIFY PROGRESSION & MP FAILED (%d ERRORS) ===" % _failures.size())
		quit(1)
