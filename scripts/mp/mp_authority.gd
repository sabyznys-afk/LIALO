class_name MpAuthority
extends RefCounted

## Server-authoritative 2-4 Player Match Engine for Downpour Experimental Multiplayer.
## Owns hidden hands, custom personal decks, HP/Shields, Calamity Combos (3x/4x Ace Execution),
## 2.6s Parry Interrupt Windows, OP Tavern Items, and Ghost actions.

const ScoreEng = preload("res://scripts/scoring_engine.gd")
const Catalog = preload("res://scripts/lialo_catalog.gd")
const Config = preload("res://scripts/mp/mp_config.gd")

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
var turn_timer: float = Config.TURN_TIMEOUT_SEC
var extra_turn_seat: int = -1

var pending_parry: Dictionary = {} # Empty when not in parry window
var bot_think_timer: float = 0.0
var bot_parry_timer: float = 0.0
var match_over: bool = false
var banner_text: String = ""
var next_uid: int = 100
var rng := RandomNumberGenerator.new()


func setup_match(lobby_seats: Array, settings: Dictionary) -> void:
	rng.randomize()
	rule_mode = str(settings.get("rule_mode", "OP_CHAOS"))
	seats.clear()
	discard_pile.clear()
	pending_parry.clear()
	pending_draw_stack = 0
	turn_dir = 1
	round_num = 1
	match_over = false
	extra_turn_seat = -1

	for i in range(lobby_seats.size()):
		var ls: Dictionary = lobby_seats[i]
		var dcfg: Dictionary = ls.get("deck_cfg", {})
		var arch := Config.get_archetype(str(dcfg.get("archetype_id", "GUILLOTINE_ACES")))
		var raw_deck := Config.build_custom_deck(dcfg)
		for card in raw_deck:
			next_uid += 1
			card["uid"] = next_uid
		raw_deck.shuffle()

		var item_list: Array = arch.get("items", ["MYS_RUNE_WHETSTONE", "MYS_IRON_GAUNTLET"]).duplicate()
		var char_id := str(dcfg.get("character_id", ""))
		if char_id == "":
			char_id = str(Config.get_character_for_archetype(str(arch.get("id", "GUILLOTINE_ACES"))).get("id", "CHAR_GUILLOTINE"))
		var seat := {
			"seat_idx": i,
			"peer_id": int(ls.get("peer_id", 0)),
			"name": str(ls.get("name", "Player %d" % (i + 1))),
			"is_bot": bool(ls.get("is_bot", false)),
			"deck_cfg": dcfg,
			"character_id": char_id,
			"archetype_name": str(arch.get("name", "Custom")),
			"sword_skin": str(arch.get("sword_skin", "SWORD_RUNE")),
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
			"revealed_turns": 0,
			"ghost_cd": 0.0,
			"draw_pile": raw_deck,
			"spent_pile": [],
			"hand": [],
			"items": item_list,
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
	turn_timer = Config.TURN_TIMEOUT_SEC
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

	# Priority 3: Human Turn Timeout Safeguard
	turn_timer -= delta
	if turn_timer <= 0.0:
		banner_text = "%s ran out of time — forced draw!" % str(cur["name"])
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

	# Compute combo damage via ScoringEngine + MP OP scaling
	var score_res := ScoreEng.calculate_hand_score(played, [], s["hand"], {
		"chosen_suit": active_suit,
		"prev_suit": active_suit,
		"pending_draw_before": pending_draw_stack,
	})
	var raw_pts := int(score_res.get("final_score", 20))
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

	var gold_gain := 8 + cnt * 4 + (8 if knight_cnt > 0 else 0)
	s["gold"] = int(s["gold"]) + gold_gain

	# KNIGHT Mist Veil cloak
	if knight_cnt > 0:
		s["mist_turns"] = maxi(int(s["mist_turns"]), 1 + (1 if knight_cnt >= 2 else 0))

	# THIEF Card Steal from target
	var tgt_s := _get_seat(tgt)
	if thief_cnt > 0 and not tgt_s.is_empty() and not tgt_s["hand"].is_empty():
		var steal_idx: int = rng.randi() % tgt_s["hand"].size()
		var stolen: Dictionary = tgt_s["hand"][steal_idx]
		tgt_s["hand"].remove_at(steal_idx)
		s["hand"].append(stolen)
		banner_text = "🗡 %s stole a card from %s!" % [s["name"], tgt_s["name"]]

	# 7s Hot-Potato Blood Tax
	if seven_cnt > 0:
		pending_draw_stack += 2 * seven_cnt + (2 if rule_mode == "OP_CHAOS" and seven_cnt >= 2 else 0)
		banner_text = "🩸 %s stacked +%d BLOOD DRAW (%d total)!" % [s["name"], 2 * seven_cnt, pending_draw_stack]

	# H (Queens) Chaos Suit Storm — 2+ Queens pass cards clockwise!
	if queen_cnt >= 2:
		_rotate_hands_clockwise(1 if queen_cnt == 2 else 2)
		banner_text = "🌪 SUIT STORM (%d× H)! Everyone passes cards clockwise!" % queen_cnt

	# Power Card Specials
	for pid in power_ids:
		_apply_power_card_effect(s, tgt_s, str(pid))

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
			banner_text = "⚔ %s hits %s for %d DMG & shatters all Shields!" % [kind_lbl, str(tgt_s.get("name", "")), exec_dmg]
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
				banner_text = "⚔ %s strikes %s for %d DMG!" % [s["name"], tgt_s["name"], base_dmg]

	_check_shedding_refill(s)
	if _check_match_winner():
		return

	# Advance turn (Aces skip 1 next player unless extra turn triggered!)
	if extra_turn_seat == turn_seat:
		extra_turn_seat = -1
		turn_timer = Config.TURN_TIMEOUT_SEC
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
		banner_text = "🩸 %s drew %d cards & took %d Blood-Tax DMG!" % [s["name"], n_draw, blood_dmg]
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


func handle_use_item(peer_id: int, seat_idx_hint: int, item_id: String, target_seat: int) -> void:
	if match_over or not pending_parry.is_empty():
		return
	if seat_idx_hint != turn_seat:
		return
	var s := _get_seat(turn_seat)
	if s.is_empty() or not _verify_peer(s, peer_id) or not bool(s["alive"]):
		return
	var idx: int = s["items"].find(item_id)
	if idx == -1:
		return

	var tgt := _resolve_target_seat(turn_seat, target_seat)
	var tgt_s := _get_seat(tgt)
	s["items"].remove_at(idx)

	match item_id:
		"MYS_IRON_GAUNTLET":
			s["shields"] = int(s["shields"]) + 25
			_apply_damage(s, tgt_s, 18)
			banner_text = "🛡 %s used Templar Gauntlet (+25 Shield, -18 HP on %s)!" % [s["name"], str(tgt_s.get("name", ""))]
		"MYS_WITCH_MIRROR":
			s["aegis_reflect"] = true
			banner_text = "🪞 %s raised Witch-Glass Reflect Shield!" % s["name"]
		"MYS_BELL_TOLL":
			for os in seats:
				if int(os["seat_idx"]) != turn_seat and bool(os["alive"]):
					_apply_damage(s, os, 22)
			var next_s := _get_seat(_next_alive_seat(turn_seat, 1))
			if not next_s.is_empty():
				next_s["stunned"] = true
			banner_text = "🔔 PLAGUE BELL! All rivals take 22 DMG!"
		"MYS_RUNE_WHETSTONE":
			s["whetstone_stacks"] = int(s["whetstone_stacks"]) + 1
			banner_text = "⚔ %s sharpened Blade! (+25%% DMG, 2× Ace Guillotine unlocked at 2 stacks!)" % s["name"]
		"MYS_RAVENS_EYE":
			_draw_one_for_seat(s)
			if not tgt_s.is_empty():
				tgt_s["revealed_turns"] = 2
			banner_text = "👁 %s pierced %s's secrets (+1 Card & Revealed)!" % [s["name"], str(tgt_s.get("name", ""))]
		"MYS_ALCHEMIST_PHIAL":
			pending_draw_stack = 0
			_draw_one_for_seat(s)
			_draw_one_for_seat(s)
			s["gold"] = int(s["gold"]) + 20
			banner_text = "⚗ %s downed Quicksilver (+2 Cards, cleared Blood Stack, +20g)!" % s["name"]
		"MYS_LANTERN_ASH":
			s["shields"] = int(s["shields"]) + 18
			if not s["hand"].is_empty():
				s["hand"][0]["edition"] = "KNIGHT"
			banner_text = "🏮 %s infused leftmost card with Mistblade Knight & +18 Shield!" % s["name"]
		"MYS_CROWBAR_KEY":
			if not tgt_s.is_empty():
				if not tgt_s["items"].is_empty():
					var stolen_it: String = str(tgt_s["items"].pop_back())
					s["items"].append(stolen_it)
					banner_text = "🗝 %s unlocked & stole %s's Relic!" % [s["name"], tgt_s["name"]]
				elif not tgt_s["hand"].is_empty():
					var sc: Dictionary = tgt_s["hand"].pop_back()
					s["hand"].append(sc)
					banner_text = "🗝 %s pickpocketed a card from %s!" % [s["name"], tgt_s["name"]]

	broadcast_vfx_event.emit({"type": "ITEM_CAST", "from_seat": turn_seat, "to_seat": tgt, "item_id": item_id})
	if _check_match_winner():
		return
	_sync_all()


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
		elif "MYS_WITCH_MIRROR" in tgt_s["items"]:
			tgt_s["items"].erase("MYS_WITCH_MIRROR")
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
			banner_text = "🪞 PARRY DEFLECT! %s bounced the Execution back at %s!" % [tgt_s["name"], str(att_s.get("name", ""))]
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
				extra_turn_seat = tgt_idx
				banner_text = "⏳ TIME REWIND! %s negated the execution & took the turn!" % tgt_s["name"]
				broadcast_vfx_event.emit({"type": "CHRONOS_SAVE", "seat": tgt_idx})
				turn_seat = tgt_idx
				turn_timer = Config.TURN_TIMEOUT_SEC
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
		_apply_damage(gs, tgt_s, 8)
		banner_text = "👻 %s (Ghost) cursed %s (-8 HP)!" % [gs["name"], tgt_s["name"]]
	elif action_id == "GHOST_BLESS":
		tgt_s["shields"] = int(tgt_s["shields"]) + 10
		banner_text = "👻 %s (Ghost) blessed %s (+10 Shield)!" % [gs["name"], tgt_s["name"]]
	elif action_id == "GHOST_SUIT":
		var suits := ["CERVEN", "ZELEN", "ZALUD", "GULA"]
		active_suit = suits[rng.randi() % 4]
		banner_text = "👻 %s (Ghost) shifted winds to %s!" % [gs["name"], Config.get_suit(active_suit)["sym"]]

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
	banner_text = "⚔ %s! %s has %.1fs to PARRY!" % [kind, str(tgt_s.get("name", "")), Config.PARRY_WINDOW_SEC]
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
		banner_text = "💀 %s EXECUTED %s with %s!" % [str(att_s.get("name", "")), str(tgt_s.get("name", "")), kind]
		broadcast_vfx_event.emit({"type": "EXECUTION_KILL", "from_seat": att_idx, "to_seat": tgt_idx, "kind": kind})
	else:
		banner_text = "⚔ %s landed %s for %d DMG!" % [str(att_s.get("name", "")), kind, dmg]

	if _check_match_winner():
		return
	_advance_turn(1)
	_sync_all()
	_queue_bot_if_needed()


func _apply_damage(att_s: Dictionary, tgt_s: Dictionary, dmg: int, bypass_shields: bool = false) -> void:
	if tgt_s.is_empty() or not bool(tgt_s.get("alive", false)):
		return
	var left := dmg
	if not bypass_shields:
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
	if s.is_empty() or s["items"].size() >= 3:
		return
	var keys := Config.MP_ITEMS.keys()
	var picked := str(keys[rng.randi() % keys.size()])
	s["items"].append(picked)


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
	banner_text = "★ PRŠÍ OVERDRIVE! %s emptied hand (-42 AoE DMG to table & +Item)!" % s["name"]
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
			banner_text = "🃏 JESTER ROULETTE! Everyone rotates 1 card clockwise!"
		"SPEC_HEX":
			turn_dir *= -1
			if not tgt_s.is_empty() and not tgt_s["hand"].is_empty() and not s["hand"].is_empty():
				var c1: Dictionary = s["hand"].pop_back()
				var c2: Dictionary = tgt_s["hand"].pop_back()
				s["hand"].append(c2)
				tgt_s["hand"].append(c1)
		"SPEC_STORM":
			for os in seats:
				if int(os["seat_idx"]) != int(s["seat_idx"]) and bool(os["alive"]):
					_apply_damage(s, os, 25)
		"SPEC_ORACLE":
			if not tgt_s.is_empty():
				tgt_s["revealed_turns"] = 2


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

	# Calamity Ritual override: 3+ matching cards OR Wild / H / Power can slam onto ANY top card!
	if chosen.size() >= 3 or base_rank == "H" or base_rank == "PWR":
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
	if bool(s.get("aegis_reflect", false)) or ("MYS_WITCH_MIRROR" in s["items"]):
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
	turn_timer = Config.TURN_TIMEOUT_SEC
	var cur := _get_seat(turn_seat)
	if not cur.is_empty() and int(cur["mist_turns"]) > 0:
		cur["mist_turns"] = int(cur["mist_turns"]) - 1
	if not cur.is_empty() and int(cur["revealed_turns"]) > 0:
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
	if not s["items"].is_empty() and rng.randf() < 0.45:
		var it := str(s["items"][0])
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
	if bool(tgt_s.get("aegis_reflect", false)) or ("MYS_WITCH_MIRROR" in tgt_s["items"]):
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
	send_private_hand.emit(peer_id, int(s["seat_idx"]), s["hand"].duplicate(), s["items"].duplicate(), meta)
