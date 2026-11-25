class_name MpAuthority
extends RefCounted

## Server-authoritative 2-4 Player Match Engine for Downpour Experimental Multiplayer.
## Owns hidden hands, custom personal decks, HP/Shields, Calamity Combos (3x/4x Ace Execution),
## 2.6s Parry Interrupt Windows, OP Tavern Items, and Ghost actions.

const ScoreEng = preload("res://scripts/scoring_engine.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")
const Config = preload("res://scripts/mp/mp_config.gd")
const MAX_MP_ITEM_USES: int = 3

signal broadcast_public_state(state: Dictionary)
signal send_private_hand(peer_id: int, seat_idx: int, hand: Array, items: Array, meta: Dictionary)
signal broadcast_vfx_event(evt: Dictionary)
signal match_finished(winner_seat: int, summary: Dictionary)

var seats: Array = []
var rule_mode: String = "OP_CHAOS"
var discard_pile: Array = []
var active_suit: String = "CERVEN"
var turn_seat: int = 0
var turn_dir: int = 1
var round_num: int = 1
var pending_draw_stack: int = 0
var turn_timeout_sec: float = Config.TURN_TIMEOUT_SEC
var turn_timer: float = Config.TURN_TIMEOUT_SEC
var cinematic_pause_timer: float = 0.0
var extra_turn_seat: int = -1

var pending_parry: Dictionary = {} # Empty when not in parry window
var bot_think_timer: float = 0.0
var bot_parry_timer: float = 0.0
var match_over: bool = false
var banner_text: String = ""
var next_uid: int = 100
var last_played_power_id: String = ""
var rng := RandomNumberGenerator.new()


func setup_match(lobby_seats: Array, settings: Dictionary) -> void:
	rng.randomize()
	rule_mode = str(settings.get("rule_mode", "OP_CHAOS"))
	turn_timeout_sec = clampf(float(settings.get("turn_timer_sec", Config.TURN_TIMEOUT_SEC)), Config.TURN_TIMEOUT_MIN, Config.TURN_TIMEOUT_MAX)
	cinematic_pause_timer = 0.0
	seats.clear()
	discard_pile.clear()
	pending_parry.clear()
	pending_draw_stack = 0
	turn_dir = 1
	round_num = 1
	match_over = false
	extra_turn_seat = -1
	last_played_power_id = ""

	for i in range(lobby_seats.size()):
		var ls: Dictionary = lobby_seats[i]
		var raw_dcfg: Dictionary = ls.get("deck_cfg", {})
		var clean_cfg: Dictionary = Config.sanitize_deck_cfg(raw_dcfg, rule_mode)
		var arch := Config.get_archetype(str(clean_cfg.get("archetype_id", "GUILLOTINE_ACES")))
		var raw_deck := Config.build_custom_deck(clean_cfg)
		for card in raw_deck:
			next_uid += 1
			card["uid"] = next_uid
		raw_deck.shuffle()

		var item_list: Array = []
		var raw_trels: Array = clean_cfg.get("table_relics", arch.get("items", ["MYS_RUNE_WHETSTONE", "MYS_IRON_GAUNTLET"]))
		for tid in raw_trels:
			if item_list.size() >= Catalog.MAX_ACTIVE_RELICS:
				break
			next_uid += 1
			item_list.append(Config.make_mp_item_instance(str(tid), next_uid))
		var passive_list: Array = clean_cfg.get("passive_relics", []).duplicate()
		var char_id := str(clean_cfg.get("character_id", ""))
		if char_id == "":
			char_id = str(Config.get_character_for_archetype(str(arch.get("id", "GUILLOTINE_ACES"))).get("id", "CHAR_GUILLOTINE"))
		var seat := {
			"seat_idx": i,
			"peer_id": int(ls.get("peer_id", 0)),
			"name": str(ls.get("name", "Player %d" % (i + 1))),
			"is_bot": bool(ls.get("is_bot", false)),
			"deck_cfg": clean_cfg,
			"character_id": char_id,
			"archetype_name": str(arch.get("name", "Custom")),
			"sword_skin": str(clean_cfg.get("sword_skin", arch.get("sword_skin", "SWORD_RUNE"))),
			"color": arch.get("col", Color(0.85, 0.72, 0.36)),
			"hp": Config.START_HP,
			"max_hp": Config.START_HP,
			"shields": Config.START_SHIELDS,
			"gold": Config.START_GOLD,
			"kills": 0,
			"total_dmg": 0,
			"alive": true,
			"stunned": false,
			"mist_turns": 0,
			"whetstone_stacks": 0,
			"aegis_reflect": false,
			"blood_seal_active": false,
			"hollow_mask_active": false,
			"surge_mult": 0.0,
			"shield_reflect_charges": 0,
			"item_used_this_turn": false,
			"revealed_turns": 0,
			"ghost_cd": 0.0,
			"draw_pile": raw_deck,
			"spent_pile": [],
			"hand": [],
			"items": item_list,
			"passive_relics": passive_list,
			"bankai_build_id": str(clean_cfg.get("archetype_id", "GUILLOTINE_ACES")),
			"bankai_combo": (clean_cfg.get("bankai_combo", Catalog.get_deck_build(str(clean_cfg.get("archetype_id", "GUILLOTINE_ACES"))).get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"])) as Array).duplicate(),
			"bankai_charged": [],
			"bankai_active": false,
			"item_uses": {},
		}
		seats.append(seat)

	# Deal personal starting hands cleanly
	for s in seats:
		for _d in range(Config.START_HAND_SIZE):
			_draw_one_for_seat(s)

	# Neutral center starter card (avoid instant 7 trap on turn 0)
	var starter_suits := ["CERVEN", "ZELEN", "ZALUD", "GULA"]
	var starter_ranks := ["8", "9", "10", "D"]
	var top := Config.make_card(starter_suits[rng.randi() % 4], starter_ranks[rng.randi() % 4], "NORMAL")
	discard_pile.append(top)
	active_suit = str(top["suit"])
	turn_seat = 0
	turn_timer = turn_timeout_sec
	banner_text = "Tavern Brawl Begun! 3× Aces = Instant Kill on Chosen Target!"

	_sync_all()
	_queue_bot_if_needed()


func tick(delta: float) -> void:
	if match_over:
		return

	# Tick Ghost cooldowns cleanly
	for s in seats:
		if not bool(s["alive"]) and float(s["ghost_cd"]) > 0.0:
			s["ghost_cd"] = maxf(0.0, float(s["ghost_cd"]) - delta)
			if bool(s["is_bot"]) and float(s["ghost_cd"]) <= 0.01:
				_bot_ghost_act(int(s["seat_idx"]))

	# Priority 0: Cinematic Pause (e.g. Bankai Awakening cut-in)
	if cinematic_pause_timer > 0.0:
		cinematic_pause_timer = maxf(0.0, cinematic_pause_timer - delta)
		return

	# Priority 1: Active Parry / Interrupt Window before Sword Execution lands!
	if not pending_parry.is_empty():
		pending_parry["timer"] = maxf(0.0, float(pending_parry["timer"]) - delta)
		if float(pending_parry.get("bot_react_at", -1.0)) > 0.0:
			bot_parry_timer -= delta
			if bot_parry_timer <= 0.0:
				pending_parry["bot_react_at"] = -1.0
				_bot_resolve_parry()
				return
		if float(pending_parry["timer"]) <= 0.0:
			_finalize_pending_parry_execution()
		return

	# Priority 2: Bot Turn Thinking
	var cur := _get_seat(turn_seat)
	if cur.is_empty() or not bool(cur["alive"]):
		_advance_turn()
		return

	if bool(cur["is_bot"]):
		bot_think_timer -= delta
		if bot_think_timer <= 0.0:
			_perform_bot_turn(cur)
		return

	# Priority 3: Human Turn Timeout Safeguard (30-45s -> auto-draw card)
	turn_timer -= delta
	if turn_timer <= 0.0:
		banner_text = "%s ran out of time — auto-drew a card!" % str(cur["name"])
		handle_draw_card(int(cur["peer_id"]), turn_seat)


func handle_play_cards(peer_id: int, seat_idx_hint: int, card_indices: Array, target_seat: int, chosen_suit: String) -> void:
	if match_over or not pending_parry.is_empty():
		return
	if seat_idx_hint != turn_seat:
		return
	var s := _get_seat(turn_seat)
	if s.is_empty() or not _verify_peer(s, peer_id) or not bool(s["alive"]):
		return

	var check := _validate_play(s, card_indices)
	if not bool(check["ok"]):
		_send_private_only(s, {"toast_err": str(check["err"])})
		return

	var tgt := _resolve_target_seat(turn_seat, target_seat)
	var played: Array = []
	var sorted_idxs := card_indices.duplicate()
	sorted_idxs.sort()
	for i in range(sorted_idxs.size() - 1, -1, -1):
		var cidx := int(sorted_idxs[i])
		var c: Dictionary = s["hand"][cidx]
		played.insert(0, c)
		s["hand"].remove_at(cidx)
		s["spent_pile"].append(c)
		discard_pile.append(c)

	var lead: Dictionary = played[0]
	var last_c: Dictionary = played[played.size() - 1]
	if chosen_suit != "" and chosen_suit in ["CERVEN", "ZELEN", "ZALUD", "GULA"]:
		active_suit = chosen_suit
	elif str(last_c.get("rank", "")) != "H" and not bool(last_c.get("wild", false)):
		active_suit = str(last_c.get("suit", active_suit))

	# Count ranks & special traits
	var cnt := played.size()
	var ace_cnt := 0
	var seven_cnt := 0
	var king_cnt := 0
	var queen_cnt := 0
	var knight_cnt := 0
	var thief_cnt := 0
	var power_ids: Array = []
	for c in played:
		var r := str(c.get("rank", ""))
		var cls := Catalog.normalize_card_class(str(c.get("edition", "NORMAL")))
		var pid := str(c.get("power_id", ""))
		if r == "E": ace_cnt += 1
		elif r == "7": seven_cnt += 1
		elif r == "K": king_cnt += 1
		elif r == "H": queen_cnt += 1
		if cls == "KNIGHT": knight_cnt += 1
		elif cls == "THIEF": thief_cnt += 1
		if pid != "": power_ids.append(pid)

	# Check 4-Card Bankai Awakening Seal (instant 4-card play OR cumulative 4/4 in duel)
	var b_combo: Array = s.get("bankai_combo", [])
	var b_charged: Array = s.get("bankai_charged", [])
	var bankai_just_triggered := false
	if not bool(s.get("bankai_active", false)) and b_combo.size() >= 4:
		for pc_b in played:
			var ck_b := "%s_%s" % [str(pc_b.get("suit", "")), str(pc_b.get("rank", ""))]
			if (ck_b in b_combo) and not (ck_b in b_charged):
				b_charged.append(ck_b)
		s["bankai_charged"] = b_charged
		if b_charged.size() >= 4:
			s["bankai_active"] = true
			bankai_just_triggered = true
			cinematic_pause_timer = 2.1
			var b_id := str(s.get("bankai_build_id", "GUILLOTINE_ACES"))
			var b_loc := Catalog.get_deck_build(b_id)
			banner_text = "%s UNLEASHED %s!" % [str(s["name"]), str(b_loc.get("bankai_name", "GRAND SEAL"))]
			broadcast_vfx_event.emit({
				"type": "BANKAI_AWAKENING",
				"seat": turn_seat,
				"build_id": b_id,
				"caster": str(s["name"]),
				"combo": b_combo.duplicate(),
			})

	# Compute combo damage via ScoringEngine + MP OP scaling + Passive Relics + Bankai Buff
	var passive_rels: Array = s.get("passive_relics", [])
	var used_blood_seal := bool(s.get("blood_seal_active", false))
	var used_hollow_mask := bool(s.get("hollow_mask_active", false))
	var used_surge := float(s.get("surge_mult", 0.0))
	var score_res := ScoreEng.calculate_hand_score(played, passive_rels, s["hand"], {
		"chosen_suit": active_suit,
		"prev_suit": active_suit,
		"pending_draw_before": pending_draw_stack,
		"blood_seal_active": used_blood_seal,
		"hollow_mask_active": used_hollow_mask,
		"surge_mult": used_surge,
		"bankai_active": bool(s.get("bankai_active", false)),
		"bankai_build_id": str(s.get("bankai_build_id", "GUILLOTINE_ACES")),
	})
	if bankai_just_triggered:
		match str(s.get("bankai_build_id", "GUILLOTINE_ACES")):
			"GUILLOTINE_ACES":
				s["whetstone_stacks"] = int(s.get("whetstone_stacks", 0)) + 1
			"MIRROR_MONARCH":
				s["shields"] = int(s["shields"]) + 25
				s["aegis_reflect"] = true
			"CHAOS_JESTER":
				s["gold"] = int(s["gold"]) + 25
				_draw_one_for_seat(s)
			"MISTBLADE_DUELIST":
				s["hp"] = mini(int(s["max_hp"]), int(s["hp"]) + 18)
				s["mist_turns"] = maxi(int(s["mist_turns"]), 2)
	s["blood_seal_active"] = false
	s["hollow_mask_active"] = false
	s["surge_mult"] = 0.0

	var raw_pts := int(score_res.get("final_score", 20))
	var x_prod := float(score_res.get("x_mult_product", 1.0))
	if not used_blood_seal and not used_hollow_mask and not ("SPEC_GAMBLER" in power_ids) and x_prod > Config.MP_PASSIVE_MULT_CAP:
		raw_pts = int(round(float(raw_pts) * (Config.MP_PASSIVE_MULT_CAP / x_prod)))
	var op_mult := (1.45 if rule_mode == "OP_CHAOS" else 1.15) * (1.0 + float(s["whetstone_stacks"]) * 0.25)
	if "SPEC_MIRROR" in power_ids:
		op_mult *= 1.85
	var base_dmg := maxi(10, int(round(float(raw_pts) * 0.42 * op_mult)))

	# Emit hand-drawn card slam + King-style 2D sword score anim event for all played cards!
	var has_sword := true
	var is_knight_vfx := (knight_cnt > 0)
	broadcast_vfx_event.emit({
		"type": "CARD_PLAY",
		"from_seat": turn_seat,
		"to_seat": tgt,
		"cards": played,
		"dmg": base_dmg,
		"has_sword": has_sword,
		"is_knight": is_knight_vfx,
		"combo_label": str(score_res.get("slam_name", "Slam")),
	})

	var gold_gain := 8 + cnt * 4 + (8 if knight_cnt > 0 else 0) + int(score_res.get("bonus_gold", 0))
	if "REL_GREED" in passive_rels:
		gold_gain += 4
	s["gold"] = int(s["gold"]) + gold_gain

	# REL_FANG: Hearts Drain passive
	var tgt_s := _get_seat(tgt)
	if "REL_FANG" in passive_rels and not tgt_s.is_empty():
		var drain_amt := int(score_res.get("rival_drain", 0))
		if drain_amt > 0:
			var fang_heal := mini(12, maxi(4, int(round(float(drain_amt) * 0.5))))
			s["hp"] = mini(int(s["max_hp"]), int(s["hp"]) + fang_heal)
			base_dmg += mini(14, drain_amt)

	# KNIGHT Mist Veil cloak
	if knight_cnt > 0:
		s["mist_turns"] = maxi(int(s["mist_turns"]), 1 + (1 if knight_cnt >= 2 else 0))

	# THIEF Card Steal from target
	if thief_cnt > 0 and not tgt_s.is_empty() and not tgt_s["hand"].is_empty():
		var steal_idx: int = rng.randi() % tgt_s["hand"].size()
		var stolen: Dictionary = tgt_s["hand"][steal_idx]
		tgt_s["hand"].remove_at(steal_idx)
		s["hand"].append(stolen)
		banner_text = "%s stole a card from %s!" % [s["name"], tgt_s["name"]]

	# 7s Hot-Potato Blood Tax
	if seven_cnt > 0:
		pending_draw_stack += 2 * seven_cnt + (2 if rule_mode == "OP_CHAOS" and seven_cnt >= 2 else 0)
		banner_text = "%s stacked +%d BLOOD DRAW (%d total)!" % [s["name"], 2 * seven_cnt, pending_draw_stack]

	# H (Queens) Chaos Suit Storm — 2+ Queens pass cards clockwise!
	if queen_cnt >= 2:
		_rotate_hands_clockwise(1 if queen_cnt == 2 else 2)
		banner_text = "SUIT STORM (%d× H)! Everyone passes cards clockwise!" % queen_cnt

	# Power Card Specials
	for pid in power_ids:
		_apply_power_card_effect(s, tgt_s, str(pid))
	for pid in power_ids:
		var spid := str(pid)
		if spid != "" and spid != "SPEC_MIRROR":
			last_played_power_id = spid

	# CALAMITY SWORD EXECUTIONS: 3x / 4x Aces = Instant Kill on Chosen Target (or 2x Aces with Whetstone >= 2)!
	var whet_req := 2 if int(s["whetstone_stacks"]) >= 2 else 3
	var trigger_four_ace_kill := (ace_cnt >= 4)
	var trigger_triple_ace := (ace_cnt >= whet_req) and not trigger_four_ace_kill

	if trigger_four_ace_kill or trigger_triple_ace:
		var is_ace_instant_kill := (ace_cnt >= 3)
		var exec_dmg := 999 if is_ace_instant_kill else (75 if rule_mode == "OP_CHAOS" else 55)
		var auto_execute_if_unparried := is_ace_instant_kill or (not tgt_s.is_empty() and float(tgt_s["hp"]) <= float(tgt_s["max_hp"]) * 0.55)
		if trigger_triple_ace and not tgt_s.is_empty():
			tgt_s["shields"] = 0
			tgt_s["stunned"] = true
		var kind_lbl := "4× ESO ROYAL GUILLOTINE" if trigger_four_ace_kill else ("3× ESO INSTANT KILL" if ace_cnt >= 3 else "%d× ESO EXECUTION STRIKE" % ace_cnt)

		# Check if victim enters 2.6s PARRY INTERRUPT WINDOW (instant kill on ONLY the chosen target seat)!
		if auto_execute_if_unparried and not tgt_s.is_empty():
			_open_parry_window(turn_seat, tgt, kind_lbl, exec_dmg, played, true)
			_check_shedding_refill(s)
			if _check_match_winner():
				return
			_sync_all()
			return
		else:
			_apply_damage(s, tgt_s, exec_dmg)
			banner_text = "%s hits %s for %d DMG & shatters all Shields!" % [kind_lbl, str(tgt_s.get("name", "")), exec_dmg]
	else:
		# Normal HP / Shield damage check — lethal hits also give Parry window if victim holds Mirror/Chronos!
		if not tgt_s.is_empty():
			var eff_hp := int(tgt_s["hp"]) + int(tgt_s["shields"])
			if base_dmg >= eff_hp and _seat_has_any_parry(tgt_s):
				_open_parry_window(turn_seat, tgt, "LETHAL %s" % str(score_res.get("slam_name", "STRIKE")), base_dmg, played, true)
				_check_shedding_refill(s)
				_sync_all()
				return
			_apply_damage(s, tgt_s, base_dmg)
			if seven_cnt == 0 and queen_cnt < 2 and power_ids.is_empty() and thief_cnt == 0:
				banner_text = "%s strikes %s for %d DMG!" % [s["name"], tgt_s["name"], base_dmg]

	_check_shedding_refill(s)
	if _check_match_winner():
		return

	# Advance turn (Aces skip 1 next player unless extra turn triggered!)
	if extra_turn_seat == turn_seat:
		extra_turn_seat = -1
		s["item_used_this_turn"] = false
		turn_timer = turn_timeout_sec
	else:
		var skip_n := 1 if (ace_cnt > 0 and pending_draw_stack == 0) else 0
		_advance_turn(skip_n)

	_sync_all()
	_queue_bot_if_needed()


func handle_draw_card(peer_id: int, seat_idx_hint: int) -> void:
	if match_over or not pending_parry.is_empty():
		return
	if seat_idx_hint != turn_seat:
		return
	var s := _get_seat(turn_seat)
	if s.is_empty() or not _verify_peer(s, peer_id) or not bool(s["alive"]):
		return

	if pending_draw_stack > 0:
		var n_draw := mini(10, pending_draw_stack)
		var blood_dmg := n_draw * 5
		pending_draw_stack = 0
		for _i in range(n_draw):
			_draw_one_for_seat(s)
		_apply_damage({}, s, blood_dmg)
		banner_text = "%s drew %d cards & took %d Blood-Tax DMG!" % [s["name"], n_draw, blood_dmg]
		broadcast_vfx_event.emit({"type": "BLOOD_DRAW", "seat": turn_seat, "count": n_draw, "dmg": blood_dmg})
	else:
		_draw_one_for_seat(s)
		banner_text = "%s drew from their personal deck." % s["name"]
		broadcast_vfx_event.emit({"type": "CARD_DRAW", "seat": turn_seat})

	if _check_match_winner():
		return
	_advance_turn()
	_sync_all()
	_queue_bot_if_needed()


func handle_use_item(peer_id: int, seat_idx_hint: int, item_key: String, target_seat: int) -> void:
	if match_over or not pending_parry.is_empty():
		return
	if seat_idx_hint != turn_seat:
		return
	var s := _get_seat(turn_seat)
	if s.is_empty() or not _verify_peer(s, peer_id) or not bool(s["alive"]):
		return
	if bool(s.get("item_used_this_turn", false)):
		_send_private_only(s, {"toast_err": "Only 1 Relic / Item per turn!"})
		return
	var idx: int = _find_seat_item_index(s, item_key)
	if idx == -1:
		return

	var item_entry = s["items"][idx]
	var item_id := Config.get_item_id(item_entry)
	var item_uid := Config.get_item_uid(item_entry, idx)

	var tgt := _resolve_target_seat(turn_seat, target_seat)
	var tgt_s := _get_seat(tgt)
	var item_uses: Dictionary = s.get("item_uses", {})
	var new_uses := int(item_uses.get(item_uid, 0)) + 1
	item_uses[item_uid] = new_uses
	if item_entry is Dictionary:
		(item_entry as Dictionary)["uses"] = new_uses
	s["item_uses"] = item_uses
	s["item_used_this_turn"] = true
	var shattered := (new_uses >= MAX_MP_ITEM_USES)
	var uses_left := maxi(0, MAX_MP_ITEM_USES - new_uses)
	if shattered:
		s["items"].remove_at(idx)
		item_uses.erase(item_uid)

	match item_id:
		"MYS_IRON_GAUNTLET":
			s["shields"] = int(s["shields"]) + 25
			_apply_damage(s, tgt_s, 18)
			banner_text = "%s used Templar Gauntlet (+25 Shield, -18 HP on %s)!" % [s["name"], str(tgt_s.get("name", ""))]
		"MYS_WITCH_MIRROR":
			s["aegis_reflect"] = true
			banner_text = "%s raised Witch-Glass Reflect Shield!" % s["name"]
		"MYS_BELL_TOLL":
			for os in seats:
				if int(os["seat_idx"]) != turn_seat and bool(os["alive"]):
					_apply_damage(s, os, 22)
			var next_s := _get_seat(_next_alive_seat(turn_seat, 1))
			if not next_s.is_empty() and not ("REL_HEX_DOLL" in next_s.get("passive_relics", [])):
				next_s["stunned"] = true
			banner_text = "PLAGUE BELL! All rivals take 22 DMG!"
		"MYS_RUNE_WHETSTONE":
			s["whetstone_stacks"] = int(s["whetstone_stacks"]) + 1
			banner_text = "%s sharpened Blade! (+25%% DMG, 2× Ace Guillotine unlocked at 2 stacks!)" % s["name"]
		"MYS_RAVENS_EYE":
			_draw_one_for_seat(s)
			if not tgt_s.is_empty():
				tgt_s["revealed_turns"] = 2
			banner_text = "%s pierced %s's secrets (+1 Card & Revealed)!" % [s["name"], str(tgt_s.get("name", ""))]
		"MYS_ALCHEMIST_PHIAL":
			pending_draw_stack = 0
			_draw_one_for_seat(s)
			_draw_one_for_seat(s)
			s["gold"] = int(s["gold"]) + 20
			banner_text = "%s downed Quicksilver (+2 Cards, cleared Blood Stack, +20g)!" % s["name"]
		"MYS_LANTERN_ASH":
			s["shields"] = int(s["shields"]) + 18
			if not s["hand"].is_empty():
				s["hand"][0]["edition"] = "KNIGHT"
			banner_text = "%s infused leftmost card with Mistblade Knight & +18 Shield!" % s["name"]
		"MYS_CROWBAR_KEY":
			if not tgt_s.is_empty():
				if not tgt_s["items"].is_empty():
					var stolen_entry = tgt_s["items"].pop_back()
					var stolen_uid := Config.get_item_uid(stolen_entry, tgt_s["items"].size())
					var stolen_uses := int(tgt_s.get("item_uses", {}).get(stolen_uid, 0))
					tgt_s.get("item_uses", {}).erase(stolen_uid)
					while s["items"].size() >= Catalog.MAX_ACTIVE_RELICS:
						s["items"].pop_front()
					if stolen_entry is Dictionary:
						s["items"].append(stolen_entry)
						s["item_uses"][stolen_uid] = stolen_uses
					else:
						next_uid += 1
						var inst := Config.make_mp_item_instance(str(stolen_entry), next_uid)
						inst["uses"] = stolen_uses
						s["items"].append(inst)
						s["item_uses"][str(inst["uid"])] = stolen_uses
					banner_text = "%s unlocked & stole %s's Relic!" % [s["name"], tgt_s["name"]]
				elif not tgt_s["hand"].is_empty():
					var sc: Dictionary = tgt_s["hand"].pop_back()
					s["hand"].append(sc)
					banner_text = "%s pickpocketed a card from %s!" % [s["name"], tgt_s["name"]]
		"TRELIC_SOUL_BELL":
			if not tgt_s.is_empty():
				tgt_s["shields"] = 0
				_apply_damage(s, tgt_s, 20)
				banner_text = "%s rang Soul-Severing Bell! Shattered %s's shields (-20 HP)!" % [s["name"], tgt_s["name"]]
		"TRELIC_BLOOD_SEAL":
			s["blood_seal_active"] = true
			if not tgt_s.is_empty():
				_apply_damage(s, tgt_s, 12)
			banner_text = "%s stamped Blood-Ink Seal! Next play ×2.0 & -12 HP!" % s["name"]
		"TRELIC_STAR_BOW":
			if not tgt_s.is_empty():
				tgt_s["revealed_turns"] = 2
				_apply_damage(s, tgt_s, 18, true)
				banner_text = "%s fired Astral Astrolabe! Revealed %s & pierced 18 DMG!" % [s["name"], tgt_s["name"]]
		"TRELIC_ASH_GLASS":
			_draw_one_for_seat(s)
			_draw_one_for_seat(s)
			for c in s["hand"]:
				if Catalog.normalize_card_class(str(c.get("edition", "NORMAL"))) == "MAGE":
					c["mage_charge"] = 2
			banner_text = "%s flipped Ashen Hourglass! (+2 Cards & Mage 2/2 charged!)" % s["name"]
		"TRELIC_WAR_HORN":
			s["shields"] = int(s["shields"]) + 22
			var best_ci := -1
			var best_pts := -1
			for ci in range(s["hand"].size()):
				if Catalog.normalize_card_class(str(s["hand"][ci].get("edition", "NORMAL"))) != "KNIGHT":
					var cp := int(s["hand"][ci].get("pts", 0))
					if cp > best_pts:
						best_pts = cp
						best_ci = ci
			if best_ci != -1:
				s["hand"][best_ci]["edition"] = "KNIGHT"
			banner_text = "%s blew Templar War-Horn! (+22 Shield & Knight forged!)" % s["name"]
		"TRELIC_HOLLOW_MASK":
			s["hp"] = maxi(1, int(s["hp"]) - 12)
			s["hollow_mask_active"] = true
			banner_text = "%s donned Phantom Mask! (-12 HP → Next play ×2.0 Wild!)" % s["name"]
		"TRELIC_CENSER":
			for c in s["hand"]:
				if Catalog.normalize_card_class(str(c.get("edition", "NORMAL"))) != "MAGE":
					c["edition"] = "MAGE"
					c["mage_charge"] = 2
					break
			s["surge_mult"] = float(s.get("surge_mult", 0.0)) + 1.0
			banner_text = "%s swung Alchemist's Censer! (Mage 2/2 & +Surge!)" % s["name"]
		"TRELIC_GOLD_SCALES":
			s["gold"] = int(s["gold"]) + 22
			_draw_one_for_seat(s)
			banner_text = "%s weighed Gilded Scales! (+22g & +1 Card!)" % s["name"]
		"TRELIC_IRON_CHAIN":
			if not tgt_s.is_empty():
				if not ("REL_HEX_DOLL" in tgt_s.get("passive_relics", [])):
					tgt_s["stunned"] = true
				_apply_damage(s, tgt_s, 16)
				banner_text = "%s bound %s in Executioner's Chain! (Stun & -16 DMG)" % [s["name"], tgt_s["name"]]
		"TRELIC_PHOENIX_BOX":
			s["hp"] = mini(int(s["max_hp"]), int(s["hp"]) + 24)
			s["shields"] = int(s["shields"]) + 10
			s["stunned"] = false
			pending_draw_stack = 0
			banner_text = "%s opened Phoenix Reliquary! (+24 HP, +10 Shield & Purged!)" % s["name"]

	broadcast_vfx_event.emit({
		"type": "ITEM_CAST",
		"from_seat": turn_seat,
		"to_seat": tgt,
		"item_id": item_id,
		"item_uid": item_uid,
		"uses_left": uses_left,
		"shattered": shattered,
	})
	if _check_match_winner():
		return
	_sync_all()


func reclaim_seat(seat_idx: int, new_peer_id: int) -> void:
	var s := _get_seat(seat_idx)
	if s.is_empty():
		return
	s["peer_id"] = new_peer_id
	s["is_bot"] = false
	banner_text = "%s reconnected to the table!" % str(s.get("name", "Player"))
	_sync_all()
	_send_private_only(s, {"reconnected": true})


func handle_parry_response(peer_id: int, seat_idx_hint: int, choice: String) -> void:
	if match_over or pending_parry.is_empty():
		return
	var tgt_idx := int(pending_parry.get("target", -1))
	if seat_idx_hint != tgt_idx:
		return
	var tgt_s := _get_seat(tgt_idx)
	if tgt_s.is_empty() or not _verify_peer(tgt_s, peer_id):
		return

	if choice == "BRACE":
		_finalize_pending_parry_execution()
		return

	var att_idx := int(pending_parry.get("attacker", -1))
	var att_s := _get_seat(att_idx)

	# 1) Reflect with SPEC_MIRROR in hand OR MYS_WITCH_MIRROR item / aegis_reflect!
	if choice == "MIRROR":
		var used := false
		if bool(tgt_s.get("aegis_reflect", false)):
			tgt_s["aegis_reflect"] = false
			used = true
		else:
			var wm_idx := _find_seat_item_index(tgt_s, "MYS_WITCH_MIRROR")
			if wm_idx != -1:
				var wm_uid := Config.get_item_uid(tgt_s["items"][wm_idx], wm_idx)
				tgt_s["items"].remove_at(wm_idx)
				tgt_s.get("item_uses", {}).erase(wm_uid)
				used = true
			else:
				for hi in range(tgt_s["hand"].size()):
					if str(tgt_s["hand"][hi].get("power_id", "")) == "SPEC_MIRROR":
						tgt_s["spent_pile"].append(tgt_s["hand"][hi])
						tgt_s["hand"].remove_at(hi)
						used = true
						break
		if used:
			var dmg := int(pending_parry.get("dmg", 999))
			pending_parry.clear()
			banner_text = "PARRY DEFLECT! %s bounced the Execution back at %s!" % [tgt_s["name"], str(att_s.get("name", ""))]
			broadcast_vfx_event.emit({
				"type": "PARRY_DEFLECT",
				"from_seat": tgt_idx,
				"to_seat": att_idx,
				"dmg": dmg,
			})
			_apply_damage(tgt_s, att_s, dmg, true)
			if _check_match_winner():
				return
			_advance_turn()
			_sync_all()
			_queue_bot_if_needed()
			return

	# 2) Dodge & Rewind with SPEC_CHRONOS!
	if choice == "CHRONOS":
		for hi in range(tgt_s["hand"].size()):
			if str(tgt_s["hand"][hi].get("power_id", "")) == "SPEC_CHRONOS":
				tgt_s["spent_pile"].append(tgt_s["hand"][hi])
				tgt_s["hand"].remove_at(hi)
				pending_parry.clear()
				tgt_s["hp"] = mini(int(tgt_s["max_hp"]), int(tgt_s["hp"]) + 25)
				tgt_s["shields"] = int(tgt_s["shields"]) + 15
				tgt_s["item_used_this_turn"] = false
				extra_turn_seat = tgt_idx
				banner_text = "TIME REWIND! %s negated the execution & took the turn!" % tgt_s["name"]
				broadcast_vfx_event.emit({"type": "CHRONOS_SAVE", "seat": tgt_idx})
				turn_seat = tgt_idx
				turn_timer = turn_timeout_sec
				_sync_all()
				_queue_bot_if_needed()
				return


func handle_ghost_action(peer_id: int, seat_idx_hint: int, action_id: String, target_seat: int) -> void:
	if match_over or not pending_parry.is_empty():
		return
	var gs := _get_seat(seat_idx_hint)
	if gs.is_empty() or not _verify_peer(gs, peer_id) or bool(gs["alive"]):
		return
	if float(gs["ghost_cd"]) > 0.0:
		return

	var tgt := _resolve_target_seat(seat_idx_hint, target_seat)
	var tgt_s := _get_seat(tgt)
	if tgt_s.is_empty():
		return

	gs["ghost_cd"] = 7.5
	if action_id == "GHOST_HEX":
		var hex_dmg := 4 if ("REL_HEX_DOLL" in tgt_s.get("passive_relics", [])) else 8
		_apply_damage(gs, tgt_s, hex_dmg)
		banner_text = "%s (Ghost) cursed %s (-%d HP)!" % [gs["name"], tgt_s["name"], hex_dmg]
	elif action_id == "GHOST_BLESS":
		tgt_s["shields"] = int(tgt_s["shields"]) + 10
		banner_text = "%s (Ghost) blessed %s (+10 Shield)!" % [gs["name"], tgt_s["name"]]
	elif action_id == "GHOST_SUIT":
		var suits := ["CERVEN", "ZELEN", "ZALUD", "GULA"]
		active_suit = suits[rng.randi() % 4]
		banner_text = "%s (Ghost) shifted winds to %s!" % [gs["name"], Config.get_suit(active_suit)["name"]]

	broadcast_vfx_event.emit({"type": "GHOST_ACT", "from_seat": seat_idx_hint, "to_seat": tgt, "action": action_id})
	_check_match_winner()
	_sync_all()


# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

func _open_parry_window(att_idx: int, tgt_idx: int, kind: String, dmg: int, cards: Array, lethal: bool) -> void:
	var tgt_s := _get_seat(tgt_idx)
	pending_parry = {
		"attacker": att_idx,
		"target": tgt_idx,
		"kind": kind,
		"dmg": dmg,
		"timer": Config.PARRY_WINDOW_SEC,
		"lethal": lethal,
		"cards": cards,
		"bot_react_at": 0.9 if bool(tgt_s.get("is_bot", false)) else -1.0,
	}
	if bool(tgt_s.get("is_bot", false)):
		bot_parry_timer = 0.85
	banner_text = "%s! %s has %.1fs to PARRY!" % [kind, str(tgt_s.get("name", "")), Config.PARRY_WINDOW_SEC]
	broadcast_vfx_event.emit({
		"type": "PARRY_WINDUP",
		"from_seat": att_idx,
		"to_seat": tgt_idx,
		"kind": kind,
	})


func _finalize_pending_parry_execution() -> void:
	if pending_parry.is_empty():
		return
	var att_idx := int(pending_parry["attacker"])
	var tgt_idx := int(pending_parry["target"])
	var dmg := int(pending_parry["dmg"])
	var kind := str(pending_parry["kind"])
	pending_parry.clear()

	var att_s := _get_seat(att_idx)
	var tgt_s := _get_seat(tgt_idx)
	_apply_damage(att_s, tgt_s, dmg, true)
	if not bool(tgt_s.get("alive", true)):
		banner_text = "%s EXECUTED %s with %s!" % [str(att_s.get("name", "")), str(tgt_s.get("name", "")), kind]
		broadcast_vfx_event.emit({"type": "EXECUTION_KILL", "from_seat": att_idx, "to_seat": tgt_idx, "kind": kind})
	else:
		banner_text = "%s landed %s for %d DMG!" % [str(att_s.get("name", "")), kind, dmg]

	if _check_match_winner():
		return
	_advance_turn(1)
	_sync_all()
	_queue_bot_if_needed()


func _apply_damage(att_s: Dictionary, tgt_s: Dictionary, dmg: int, bypass_shields: bool = false, allow_rebound: bool = true) -> void:
	if tgt_s.is_empty() or not bool(tgt_s.get("alive", false)):
		return
	var left := dmg
	if not bypass_shields:
		if "REL_IRON_BOOT" in tgt_s.get("passive_relics", []) and left > 4:
			left = maxi(1, int(round(float(left) * 0.75)))
		if allow_rebound and int(tgt_s.get("shield_reflect_charges", 0)) > 0:
			tgt_s["shield_reflect_charges"] = int(tgt_s["shield_reflect_charges"]) - 1
			left = maxi(0, int(round(float(left) * 0.5)))
			if not att_s.is_empty() and int(att_s.get("seat_idx", -1)) != int(tgt_s["seat_idx"]):
				_apply_damage(tgt_s, att_s, 12, false, false)
		var sh := int(tgt_s["shields"])
		var absorbed := mini(sh, left)
		tgt_s["shields"] = sh - absorbed
		left -= absorbed
	if left > 0:
		tgt_s["hp"] = maxi(0, int(tgt_s["hp"]) - left)
	if not att_s.is_empty():
		att_s["total_dmg"] = int(att_s.get("total_dmg", 0)) + dmg
	if int(tgt_s["hp"]) <= 0:
		tgt_s["alive"] = false
		tgt_s["hp"] = 0
		tgt_s["ghost_cd"] = 4.0
		var loot := int(tgt_s["gold"])
		tgt_s["gold"] = 0
		if not att_s.is_empty() and int(att_s.get("seat_idx", -1)) != int(tgt_s["seat_idx"]):
			att_s["kills"] = int(att_s.get("kills", 0)) + 1
			att_s["gold"] = int(att_s.get("gold", 0)) + loot + 30
			_grant_bonus_item(att_s)
		if pending_draw_stack > 0:
			pending_draw_stack = 0


func _grant_bonus_item(s: Dictionary) -> void:
	if s.is_empty() or s["items"].size() >= Catalog.MAX_ACTIVE_RELICS:
		return
	var keys := Config.MP_ITEMS.keys()
	var picked := str(keys[rng.randi() % keys.size()])
	next_uid += 1
	s["items"].append(Config.make_mp_item_instance(picked, next_uid))


func _find_seat_item_index(s: Dictionary, item_key: String) -> int:
	var items_arr: Array = s.get("items", [])
	for i in range(items_arr.size()):
		if Config.get_item_uid(items_arr[i], i) == item_key:
			return i
	for i in range(items_arr.size()):
		if Config.get_item_id(items_arr[i]) == item_key:
			return i
	return -1


func _check_shedding_refill(s: Dictionary) -> void:
	if not s["hand"].is_empty() or not bool(s["alive"]):
		return
	# Prsi Shedding Overdrive: AoE blast + fresh 5-card hand + bonus OP item!
	for os in seats:
		if int(os["seat_idx"]) != int(s["seat_idx"]) and bool(os["alive"]):
			_apply_damage(s, os, 42)
	s["gold"] = int(s["gold"]) + 30
	_grant_bonus_item(s)
	for _i in range(5):
		_draw_one_for_seat(s)
	banner_text = "PRŠÍ OVERDRIVE! %s emptied hand (-42 AoE DMG to table & +Item)!" % s["name"]
	broadcast_vfx_event.emit({"type": "SHED_OVERDRIVE", "seat": int(s["seat_idx"])})


func _apply_power_card_effect(s: Dictionary, tgt_s: Dictionary, pid: String) -> void:
	match pid:
		"SPEC_VAMPIRE":
			_apply_damage(s, tgt_s, 28)
			s["hp"] = mini(int(s["max_hp"]), int(s["hp"]) + 28)
			if not tgt_s.is_empty():
				var st := mini(18, int(tgt_s["gold"]))
				tgt_s["gold"] = int(tgt_s["gold"]) - st
				s["gold"] = int(s["gold"]) + st
		"SPEC_CHRONOS":
			extra_turn_seat = int(s["seat_idx"])
		"SPEC_JESTER":
			_rotate_hands_clockwise(1)
			banner_text = "JESTER ROULETTE! Everyone rotates 1 card clockwise!"
		"SPEC_HEX":
			turn_dir *= -1
			if not tgt_s.is_empty() and not ("REL_HEX_DOLL" in tgt_s.get("passive_relics", [])) and not tgt_s["hand"].is_empty() and not s["hand"].is_empty():
				var c1: Dictionary = s["hand"].pop_back()
				var c2: Dictionary = tgt_s["hand"].pop_back()
				s["hand"].append(c2)
				tgt_s["hand"].append(c1)
		"SPEC_STORM":
			for os in seats:
				if int(os["seat_idx"]) != int(s["seat_idx"]) and bool(os["alive"]):
					_apply_damage(s, os, 25)
			s["surge_mult"] = float(s.get("surge_mult", 0.0)) + 1.0
		"SPEC_ORACLE":
			_draw_one_for_seat(s)
			if not tgt_s.is_empty():
				tgt_s["revealed_turns"] = 2
		"SPEC_MIRROR":
			if last_played_power_id != "" and last_played_power_id != "SPEC_MIRROR":
				_apply_power_card_effect(s, tgt_s, last_played_power_id)
				banner_text = "TWIN MIRROR echoed %s!" % last_played_power_id
			else:
				s["shields"] = int(s["shields"]) + 15
		"SPEC_ALCHEMIST":
			var upgraded := false
			for hc in s["hand"]:
				if Catalog.normalize_card_class(str(hc.get("edition", "NORMAL"))) == "NORMAL":
					var classes := ["MAGE", "KNIGHT", "THIEF"]
					var new_cls: String = classes[rng.randi() % classes.size()]
					hc["edition"] = new_cls
					if new_cls == "MAGE":
						hc["mage_charge"] = 2
					upgraded = true
					break
			s["gold"] = int(s["gold"]) + 15
			s["surge_mult"] = float(s.get("surge_mult", 0.0)) + 0.5
			if upgraded:
				banner_text = "GOLD TRANSMUTER upgraded a card in %s's hand (+15g)!" % s["name"]
		"SPEC_PHOENIX":
			pending_draw_stack = 0
			s["hp"] = mini(int(s["max_hp"]), int(s["hp"]) + 15)
			if not tgt_s.is_empty():
				_apply_damage(s, tgt_s, 18)
			var phx := Config.make_power_card("SPEC_PHOENIX")
			next_uid += 1
			phx["uid"] = next_uid
			s["draw_pile"].append(phx)
			s["draw_pile"].shuffle()
			banner_text = "ASH PHOENIX purged Blood Tax, healed +15 HP & returned to deck!"
		"SPEC_MIDAS":
			s["gold"] = int(s["gold"]) + 20
			s["shields"] = int(s["shields"]) + 10
			banner_text = "MIDAS TOUCH! %s minted +20g & +10 Shield!" % s["name"]
		"SPEC_MAGNET":
			var want_ranks := {}
			for hc in s["hand"]:
				var hr := str(hc.get("rank", ""))
				if hr != "" and hr != "PWR":
					want_ranks[hr] = true
			var pulled := 0
			var dp: Array = s["draw_pile"]
			for di in range(dp.size() - 1, -1, -1):
				if pulled >= 2 or s["hand"].size() >= 12:
					break
				var dr := str(dp[di].get("rank", ""))
				if want_ranks.has(dr) or (want_ranks.is_empty() and dr in ["E", "K"]):
					s["hand"].append(dp[di])
					dp.remove_at(di)
					pulled += 1
			dp.shuffle()
			banner_text = "RUNE MAGNET pulled %d matching card(s)!" % pulled
		"SPEC_SHIELD":
			s["shields"] = int(s["shields"]) + 25
			s["shield_reflect_charges"] = int(s.get("shield_reflect_charges", 0)) + 2
			banner_text = "IRON BASTION! %s gained +25 Shield & 2 Reflect Charges!" % s["name"]
		"SPEC_GAMBLER":
			s["gold"] = int(s["gold"]) + 10
			banner_text = "LOADED DICE! %s rolled high-stakes multiplier!" % s["name"]
		"SPEC_PLAGUE":
			if not tgt_s.is_empty():
				_apply_damage(s, tgt_s, 15)
				if not ("REL_HEX_DOLL" in tgt_s.get("passive_relics", [])):
					tgt_s["stunned"] = true
					banner_text = "FROST BLIGHT! %s chilled & stunned %s!" % [s["name"], tgt_s["name"]]
				else:
					banner_text = "FROST BLIGHT hit %s (Voodoo Effigy resisted stun)!" % tgt_s["name"]
		"SPEC_CROWN":
			s["shields"] = int(s["shields"]) + 12
			s["gold"] = int(s["gold"]) + 12
			banner_text = "ROYAL DECREE! %s rallied court (+12 Shield & +12g)!" % s["name"]


func _rotate_hands_clockwise(card_count: int) -> void:
	var alive_list: Array = []
	for s in seats:
		if bool(s["alive"]):
			alive_list.append(s)
	if alive_list.size() < 2:
		return
	var packets: Array = []
	for s in alive_list:
		var pack: Array = []
		for _i in range(card_count):
			if s["hand"].size() > 1:
				var idx: int = rng.randi() % s["hand"].size()
				pack.append(s["hand"][idx])
				s["hand"].remove_at(idx)
		packets.append(pack)
	for i in range(alive_list.size()):
		var receiver: Dictionary = alive_list[(i + 1) % alive_list.size()]
		for c in packets[i]:
			receiver["hand"].append(c)


func _validate_play(s: Dictionary, card_indices: Array) -> Dictionary:
	if card_indices.is_empty():
		return {"ok": false, "err": "Select at least 1 card!"}
	var hand: Array = s["hand"]
	var seen := {}
	var chosen: Array = []
	for raw_i in card_indices:
		var idx := int(raw_i)
		if idx < 0 or idx >= hand.size() or seen.has(idx):
			return {"ok": false, "err": "Invalid card selection."}
		seen[idx] = true
		chosen.append(hand[idx])

	var base_rank := str(chosen[0].get("rank", ""))
	var all_same_rank := true
	var any_seven := false
	for c in chosen:
		var r := str(c.get("rank", ""))
		if r == "7": any_seven = true
		if r != base_rank and base_rank != "PWR" and r != "PWR":
			all_same_rank = false
	if not all_same_rank:
		return {"ok": false, "err": "Multi-card slams must share the same Rank (or Power card)!"}

	if pending_draw_stack > 0:
		if any_seven:
			return {"ok": true}
		return {"ok": false, "err": "Blood Tax (+%d) active! Play a 7 to pass it, or Draw!" % pending_draw_stack}

	# Calamity Ritual override: 3+ matching cards OR Wild / H / Power / Hollow Mask can slam onto ANY top card!
	if chosen.size() >= 3 or base_rank == "H" or base_rank == "PWR" or bool(s.get("hollow_mask_active", false)):
		return {"ok": true}

	var top: Dictionary = discard_pile.back() if not discard_pile.is_empty() else {}
	var top_rank := str(top.get("rank", ""))
	for c in chosen:
		if str(c.get("suit", "")) == active_suit or str(c.get("rank", "")) == top_rank or bool(c.get("wild", false)):
			return {"ok": true}
	return {"ok": false, "err": "Card must match active suit or top rank (%s) — or Slam 3+ matching!" % top_rank}


func _draw_one_for_seat(s: Dictionary) -> void:
	var dp: Array = s["draw_pile"]
	if dp.is_empty():
		var sp: Array = s["spent_pile"]
		if not sp.is_empty():
			dp.append_array(sp)
			sp.clear()
			dp.shuffle()
		else:
			var fresh := Config.build_custom_deck(s.get("deck_cfg", {}))
			for card in fresh:
				next_uid += 1
				card["uid"] = next_uid
			fresh.shuffle()
			dp.append_array(fresh)
	if not dp.is_empty() and s["hand"].size() < 12:
		s["hand"].append(dp.pop_back())


func _seat_has_any_parry(s: Dictionary) -> bool:
	if bool(s.get("aegis_reflect", false)) or (_find_seat_item_index(s, "MYS_WITCH_MIRROR") != -1):
		return true
	for c in s["hand"]:
		var pid := str(c.get("power_id", ""))
		if pid == "SPEC_MIRROR" or pid == "SPEC_CHRONOS":
			return true
	return false


func _advance_turn(extra_skips: int = 0) -> void:
	round_num += 1
	var steps := 1 + extra_skips
	var safety := 0
	var next := turn_seat
	while steps > 0 and safety < 16:
		safety += 1
		next = posmod(next + turn_dir, seats.size())
		if bool(seats[next]["alive"]):
			if bool(seats[next]["stunned"]):
				seats[next]["stunned"] = false
				continue
			steps -= 1
	turn_seat = next
	turn_timer = turn_timeout_sec
	var cur := _get_seat(turn_seat)
	if not cur.is_empty():
		cur["item_used_this_turn"] = false
		if int(cur["mist_turns"]) > 0:
			cur["mist_turns"] = int(cur["mist_turns"]) - 1
		if int(cur["revealed_turns"]) > 0:
			cur["revealed_turns"] = int(cur["revealed_turns"]) - 1


func _next_alive_seat(from_idx: int, offset: int) -> int:
	var n := seats.size()
	var idx := from_idx
	var found := 0
	for _i in range(n * 2):
		idx = posmod(idx + turn_dir, n)
		if bool(seats[idx]["alive"]):
			found += 1
			if found >= offset:
				return idx
	return from_idx


func _resolve_target_seat(from_idx: int, desired: int) -> int:
	if desired >= 0 and desired < seats.size() and desired != from_idx and bool(seats[desired]["alive"]):
		return desired
	return _next_alive_seat(from_idx, 1)


func _check_match_winner() -> bool:
	var alive_seats: Array = []
	for s in seats:
		if bool(s["alive"]):
			alive_seats.append(s)
	if alive_seats.size() <= 1:
		match_over = true
		var w_idx := int(alive_seats[0]["seat_idx"]) if not alive_seats.is_empty() else 0
		var summary := {
			"winner_seat": w_idx,
			"winner_name": str(alive_seats[0]["name"]) if not alive_seats.is_empty() else "Nobody",
			"rounds": round_num,
			"seats": _build_public_seats(),
		}
		_sync_all()
		match_finished.emit(w_idx, summary)
		return true
	return false


func _queue_bot_if_needed() -> void:
	var cur := _get_seat(turn_seat)
	if not cur.is_empty() and bool(cur["is_bot"]) and bool(cur["alive"]):
		bot_think_timer = 1.15


func _perform_bot_turn(s: Dictionary) -> void:
	var my_idx := int(s["seat_idx"])
	var tgt := _pick_bot_target(my_idx)
	# Occasionally fire an OP item first
	if not s["items"].is_empty() and not bool(s.get("item_used_this_turn", false)) and rng.randf() < 0.45:
		var it := Config.get_item_uid(s["items"][0], 0)
		handle_use_item(int(s["peer_id"]), my_idx, it, tgt)
		if match_over or not pending_parry.is_empty():
			return

	# Group cards by rank to spot 3x/4x Calamity Slams!
	var by_rank := {}
	for i in range(s["hand"].size()):
		var r := str(s["hand"][i].get("rank", ""))
		if not by_rank.has(r):
			by_rank[r] = []
		by_rank[r].append(i)

	if pending_draw_stack > 0:
		if by_rank.has("7"):
			handle_play_cards(int(s["peer_id"]), my_idx, by_rank["7"], tgt, "")
			return
		handle_draw_card(int(s["peer_id"]), my_idx)
		return

	# Priority 1: Play 3x/4x Ace Guillotine!
	if by_rank.has("E") and by_rank["E"].size() >= 3:
		handle_play_cards(int(s["peer_id"]), my_idx, by_rank["E"], tgt, "")
		return

	# Priority 2: Any 3+ Calamity combo
	for r_key in by_rank.keys():
		if r_key != "PWR" and by_rank[r_key].size() >= 3:
			handle_play_cards(int(s["peer_id"]), my_idx, by_rank[r_key], tgt, _pick_bot_suit(s))
			return

	# Priority 3: Legal multi-pair or single card (preferring Knights/Powers)
	var best_play: Array = []
	for r_key in by_rank.keys():
		var group: Array = by_rank[r_key]
		if _validate_play(s, group)["ok"]:
			if group.size() > best_play.size():
				best_play = group
	if not best_play.is_empty():
		handle_play_cards(int(s["peer_id"]), my_idx, best_play, tgt, _pick_bot_suit(s))
		return

	for i in range(s["hand"].size()):
		if _validate_play(s, [i])["ok"]:
			handle_play_cards(int(s["peer_id"]), my_idx, [i], tgt, _pick_bot_suit(s))
			return

	handle_draw_card(int(s["peer_id"]), my_idx)


func _bot_resolve_parry() -> void:
	if pending_parry.is_empty():
		return
	var tgt_s := _get_seat(int(pending_parry["target"]))
	if tgt_s.is_empty():
		_finalize_pending_parry_execution()
		return
	if bool(tgt_s.get("aegis_reflect", false)) or (_find_seat_item_index(tgt_s, "MYS_WITCH_MIRROR") != -1):
		handle_parry_response(int(tgt_s["peer_id"]), int(tgt_s["seat_idx"]), "MIRROR")
		return
	for c in tgt_s["hand"]:
		var pid := str(c.get("power_id", ""))
		if pid == "SPEC_MIRROR":
			handle_parry_response(int(tgt_s["peer_id"]), int(tgt_s["seat_idx"]), "MIRROR")
			return
		elif pid == "SPEC_CHRONOS":
			handle_parry_response(int(tgt_s["peer_id"]), int(tgt_s["seat_idx"]), "CHRONOS")
			return
	_finalize_pending_parry_execution()


func _bot_ghost_act(ghost_seat: int) -> void:
	var gs := _get_seat(ghost_seat)
	if gs.is_empty():
		return
	var tgt := _pick_bot_target(ghost_seat)
	handle_ghost_action(int(gs["peer_id"]), ghost_seat, "GHOST_HEX" if rng.randf() < 0.7 else "GHOST_SUIT", tgt)


func _pick_bot_target(my_idx: int) -> int:
	var best_idx: int = _next_alive_seat(my_idx, 1)
	var best_hp := -1
	for s in seats:
		if int(s["seat_idx"]) != my_idx and bool(s["alive"]) and int(s["hp"]) > best_hp:
			best_hp = int(s["hp"])
			best_idx = int(s["seat_idx"])
	return best_idx


func _pick_bot_suit(s: Dictionary) -> String:
	for c in s["hand"]:
		if str(c.get("suit", "")) != "":
			return str(c["suit"])
	return "CERVEN"


func _verify_peer(s: Dictionary, peer_id: int) -> bool:
	if bool(s.get("is_bot", false)):
		return peer_id == 1 or peer_id == 0
	return int(s.get("peer_id", -1)) == peer_id


func _get_seat(idx: int) -> Dictionary:
	if idx < 0 or idx >= seats.size():
		return {}
	return seats[idx]


func _build_public_seats() -> Array:
	var out: Array = []
	for s in seats:
		var mist := int(s["mist_turns"]) > 0
		out.append({
			"seat_idx": int(s["seat_idx"]),
			"peer_id": int(s["peer_id"]),
			"name": str(s["name"]),
			"is_bot": bool(s["is_bot"]),
			"archetype_name": str(s["archetype_name"]),
			"character_id": str(s.get("character_id", "CHAR_GUILLOTINE")),
			"sword_skin": str(s["sword_skin"]),
			"color": s["color"],
			"hp": int(s["hp"]),
			"max_hp": int(s["max_hp"]),
			"shields": int(s["shields"]),
			"gold": int(s["gold"]),
			"kills": int(s["kills"]),
			"alive": bool(s["alive"]),
			"stunned": bool(s["stunned"]),
			"mist_cloaked": mist,
			"whetstone_stacks": int(s["whetstone_stacks"]),
			"aegis_reflect": bool(s["aegis_reflect"]),
			"hollow_mask_active": bool(s.get("hollow_mask_active", false)),
			"item_used_this_turn": bool(s.get("item_used_this_turn", false)),
			"bankai_active": bool(s.get("bankai_active", false)),
			"bankai_progress": (s.get("bankai_charged", []) as Array).size(),
			"bankai_build_id": str(s.get("bankai_build_id", "GUILLOTINE_ACES")),
			"hand_count": -1 if mist else s["hand"].size(),
			"deck_count": s["draw_pile"].size(),
			"items_count": s["items"].size(),
			"revealed_cards": s["hand"].duplicate() if int(s["revealed_turns"]) > 0 else [],
			"ghost_cd": float(s["ghost_cd"]),
		})
	return out


func _sync_all() -> void:
	var top_card: Dictionary = discard_pile.back() if not discard_pile.is_empty() else {}
	var parry_pub := {}
	if not pending_parry.is_empty():
		parry_pub = {
			"attacker": int(pending_parry["attacker"]),
			"target": int(pending_parry["target"]),
			"kind": str(pending_parry["kind"]),
			"dmg": int(pending_parry["dmg"]),
			"timer": float(pending_parry["timer"]),
		}
	broadcast_public_state.emit({
		"seats": _build_public_seats(),
		"top_card": top_card,
		"discard_count": discard_pile.size(),
		"active_suit": active_suit,
		"turn_seat": turn_seat,
		"turn_dir": turn_dir,
		"round_num": round_num,
		"pending_draw_stack": pending_draw_stack,
		"turn_timer": turn_timer,
		"turn_timeout_sec": turn_timeout_sec,
		"rule_mode": rule_mode,
		"pending_parry": parry_pub,
		"banner": banner_text,
		"match_over": match_over,
	})
	for s in seats:
		if not bool(s["is_bot"]):
			_send_private_only(s, {})


func _send_private_only(s: Dictionary, meta: Dictionary) -> void:
	if bool(s.get("is_bot", false)):
		return
	var peer_id := int(s.get("peer_id", 1))
	var out_meta := meta.duplicate(true)
	out_meta["item_uses"] = s.get("item_uses", {}).duplicate()
	send_private_hand.emit(peer_id, int(s["seat_idx"]), s["hand"].duplicate(), s["items"].duplicate(), out_meta)
