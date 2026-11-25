extends RefCounted
class_name ScoringEngine
## Simplified Multiplier Scoring Engine for LIALO
## Formula: Total points = Card value × Number of cards played

const Catalog = preload("res://scripts/lialo_catalog.gd")

const BASE_CARD_CHIPS := {
	"7": 7,
	"8": 8,
	"9": 9,
	"10": 10,
	"D": 12,
	"H": 16,
	"K": 18,
	"E": 20,
}

const COURT_RANKS := ["D", "H", "K", "E"]
const RED_SUITS := ["CERVEN", "GULA"]
const BLACK_GREEN_SUITS := ["ZELEN", "ZALUD"]

# Compatibility constants (simplified multiplier tracks Card Count: 1×, 2×, 3×, 4×)
const SLAM_BASE_CHIPS := {1: 0, 2: 0, 3: 0, 4: 0}
const SLAM_BASE_MULT := {1: 1.0, 2: 2.0, 3: 3.0, 4: 4.0}

const PRSI_7_CHIPS := 0
const PRSI_7_MULT := 0.0
const PRSI_7_COUNTER_CHIPS := 0
const PRSI_7_COUNTER_XMULT := 1.0
const PRSI_7_VOLLEY_MULT := 0.0

const PRSI_ACE_CHIPS := 0
const PRSI_ACE_MULT := 0.0
const PRSI_ACE_COUNTER_XMULT := 1.0

const PRSI_HORNIK_SHIFT_CHIPS := 0
const PRSI_HORNIK_SHIFT_MULT := 0.0

const SHED_PAR_TURNS := 12
const SHED_BASE_CHIPS := 0
const SHED_BASE_XMULT := 1.0
const SHED_EXP_PER_TURN := 1.0

const SEVEN_GRIMOIRE_STEP := 0.0
const MERCHANT_LEDGER_CHIP_STEP := 0

const RANK_ABILITY_INFO := {
	"7": {
		"title": "Seven Barrage", "title_cs": "Sedmový útok",
		"badge": "+2 DRAW", "badge_cs": "+2 LÍZÁNÍ",
		"col": Color(0.95, 0.34, 0.34),
		"desc": "Rival draws +2 unless blocked by another 7! Worth 7 × count pts.",
		"desc_cs": "Soupeř líže +2, pokud nedá další 7! Dává 7 × počet b."
	},
	"8": {
		"title": "Eight Infinity", "title_cs": "Nekonečná Osma",
		"badge": "∞ 8 × COUNT", "badge_cs": "∞ 8 × POČET",
		"col": Color(0.32, 0.88, 1.0),
		"desc": "Stack multiple 8s at once! 1→8, 2→16, 3→24, 4→32 pts.",
		"desc_cs": "Vykládej více Osmiček najednou! 1→8, 2→16, 3→24, 4→32 b."
	},
	"9": {
		"title": "Nine Conduit", "title_cs": "Vysátí Devítky",
		"badge": "✨ +1 REDRAW", "badge_cs": "✨ +1 VÝMĚNA",
		"col": Color(0.92, 0.38, 0.68),
		"desc": "Charges Mage cards (+1) & grants +1 Redraw. Worth 9 × count pts.",
		"desc_cs": "Nabije Mágy (+1) a přidá +1 výměnu. Dává 9 × počet b."
	},
	"10": {
		"title": "Ten Bullion", "title_cs": "Zlatá Desítka",
		"badge": "+10 GOLD", "badge_cs": "+10 ZLATO",
		"col": Color(1.0, 0.82, 0.24),
		"desc": "Mints +10 Florins on play! Worth 10 × count pts.",
		"desc_cs": "Vyrazí +10 Zlatých při zahrání! Dává 10 × počet b."
	},
	"D": {
		"title": "Jack Guard", "title_cs": "Obrana Spodka",
		"badge": "+1 SHIELD", "badge_cs": "+1 ŠTÍT",
		"col": Color(0.46, 0.94, 0.56),
		"desc": "Grants +1 Guard Shield against curses & damage! Worth 12 × count pts.",
		"desc_cs": "Přidá +1 Štít proti kletbám a útokům! Dává 12 × počet b."
	},
	"H": {
		"title": "Queen Wild", "title_cs": "Změna barvy (Svršek)",
		"badge": "WILD SUIT", "badge_cs": "ZMĚNA BARVY",
		"col": Color(0.74, 0.52, 1.0),
		"desc": "Play on any suit and choose the next suit! Worth 16 × count pts.",
		"desc_cs": "Lze zahrát na cokoli a zvolit novou barvu! Dává 16 × počet b."
	},
	"K": {
		"title": "King Challenge", "title_cs": "Královský útok",
		"badge": "1-3 HP DMG", "badge_cs": "1–3 HP ÚTOK",
		"col": Color(1.0, 0.72, 0.28),
		"desc": "Deals 1–3 ♥ HP & Curse unless Rival blocks with a King! Worth 18 × count pts.",
		"desc_cs": "Ubírá 1–3 ♥ HP a kletbu, pokud soupeř nedá Krále! Dává 18 × počet b."
	},
	"E": {
		"title": "Ace Strike", "title_cs": "Stopka Esa",
		"badge": "1/4/6 HP DMG", "badge_cs": "1/4/6 HP ÚTOK",
		"col": Color(0.96, 0.86, 0.32),
		"desc": "Deals 1 / 4 / 6 ♥ HP DMG + Stun! Worth 20 × count pts.",
		"desc_cs": "Bere 1 / 4 / 6 ♥ HP a zastaví soupeře! Dává 20 × počet b."
	},
}

static func get_rank_ability_info(rank_id: String, lang: String = "en") -> Dictionary:
	var d: Dictionary = (RANK_ABILITY_INFO.get(rank_id, {}) as Dictionary).duplicate()
	if not d.is_empty() and lang == "cs":
		d["title"] = str(d.get("title_cs", d.get("title", "")))
		d["badge"] = str(d.get("badge_cs", d.get("badge", "")))
		d["desc"] = str(d.get("desc_cs", d.get("desc", "")))
	return d


static func _fmt_num(val: float) -> String:
	if absf(val - roundf(val)) < 0.005:
		return "%d" % int(round(val))
	if absf(val * 10.0 - roundf(val * 10.0)) < 0.05:
		return "%.1f" % val
	return "%.2f" % val


static func get_base_card_chips(rank_id: String, fallback_pts: int = 10) -> int:
	if BASE_CARD_CHIPS.has(rank_id):
		return int(BASE_CARD_CHIPS[rank_id])
	return fallback_pts


static func get_slam_name(cnt: int, played_cards: Array, lang: String = "en") -> String:
	if lang == "cs":
		if cnt <= 1:
			if played_cards.size() == 1 and str(played_cards[0].get("power_id", "")) != "":
				return "Mocná karta"
			return "Tah kartou (×1)"
		if cnt == 2:
			return "Dvojkombo (×2)"
		if cnt == 3:
			return "Trojkombo (×3)"
		if cnt == 4:
			return "Čtyřkombo (×4)"
		return "%d× Kombo" % cnt
	if cnt <= 1:
		if played_cards.size() == 1 and str(played_cards[0].get("power_id", "")) != "":
			return "Arcane Play (×1)"
		return "Single Play (×1)"
	if cnt == 2:
		return "Double Combo (×2)"
	if cnt == 3:
		return "Triple Combo (×3)"
	if cnt == 4:
		return "Quad Combo (×4)"
	return "%d-Card Combo (×%d)" % [cnt, cnt]


static func _make_step(
	phase: String,
	label: String,
	detail: String,
	chips_delta: int,
	flat_mult_delta: float,
	x_mult_factor: float,
	chips_after: int,
	flat_mult_after: float,
	x_mult_after: float,
	col: Color,
	relic_id: String = "",
	lightning: bool = false
) -> Dictionary:
	return {
		"phase": phase,
		"label": label,
		"detail": detail,
		"chips_delta": chips_delta,
		"flat_mult_delta": flat_mult_delta,
		"x_mult_factor": x_mult_factor,
		"chips_after": chips_after,
		"flat_mult_after": flat_mult_after,
		"x_mult_after": x_mult_after,
		"color": col,
		"relic_id": relic_id,
		"lightning": lightning,
	}


static func calculate_hand_score(
	played_cards: Array,
	active_relics: Array,
	current_hand: Array,
	context: Dictionary = {}
) -> Dictionary:
	var steps: Array[Dictionary] = []
	var cnt := played_cards.size()
	if cnt == 0:
		return {
			"card_value": 0,
			"card_count": 0,
			"base_chips": 0,
			"card_chips": 0,
			"total_chips": 0,
			"flat_mult": 1.0,
			"x_mult_product": 1.0,
			"effective_mult": 1.0,
			"final_score": 0,
			"slam_name": "No Cards",
			"shed_finisher": false,
			"shed_rem_turns": 0,
			"shed_x_mult": 1.0,
			"rival_drain": 0,
			"rival_bonus": 0,
			"bonus_gold": 0,
			"extra_draw": 0,
			"extra_skip": false,
			"lightning": false,
			"surge_kept": false,
			"new_surge_mult": 0.0,
			"jester_triggers": 1,
			"seven_grimoire_delta": 0.0,
			"seven_grimoire_new": 0.0,
			"seven_draw_bonus": 0,
			"ace_stun_bonus": 0,
			"ace_hp_damage": 0,
			"mage_charge_boost": 0,
			"mage_draws": 0,
			"shields_gained": 0,
			"redraws_gained": 0,
			"knight_mist_triggered": false,
			"thief_heist_triggered": false,
			"king_curse_suit": "",
			"formula_summary": "0 × 0 = 0",
			"steps": steps,
		}

	var tutorial_mode := bool(context.get("tutorial_mode", false))
	var tutorial_step := int(context.get("tutorial_step", 0))
	var lang := str(context.get("lang", "en"))
	var cs := (lang == "cs")
	var is_preview := bool(context.get("is_preview", false))
	var chosen_suit := str(context.get("chosen_suit", played_cards[cnt - 1].get("suit", "CERVEN")))
	var slam_name := get_slam_name(cnt, played_cards, lang)

	# Core Simplified Rule: Total points = Card value × Number of cards played
	var card_vals: Array[int] = []
	var sum_val := 0
	var sevens_played := 0
	var eights_played := 0
	var nines_played := 0
	var tens_played := 0
	var lowers_played := 0
	var kings_played := 0
	var king_curse_suit := ""
	var aces_played := 0
	var horniks_played := 0
	var all_red := true
	var bonus_gold := 0
	var extra_draw := 0
	var extra_skip := false
	var rival_drain := 0
	var rival_bonus := 0
	var lightning := (cnt >= 2)
	var surge_kept := false
	var new_surge_mult := 0.0
	var jester_triggers := 1
	var knight_mist_triggered := false
	var thief_heist_triggered := false
	var mage_charge_boost := 0
	var mage_draws := 0
	var shields_gained := 0
	var redraws_gained := 0

	for card in played_cards:
		var r_id := str(card.get("rank", ""))
		var s_id := str(card.get("suit", ""))
		var p_id := str(card.get("power_id", ""))
		var cls_id := Catalog.normalize_card_class(str(card.get("edition", card.get("card_class", "NORMAL"))))
		var is_merchant_nolock := (cls_id == "MERCHANT" and p_id == "")
		var c_val := int(card.get("pts", get_base_card_chips(r_id, 18))) if p_id != "" else get_base_card_chips(r_id, int(card.get("pts", 8)))
		card_vals.append(c_val)
		sum_val += c_val
		if p_id != "":
			lightning = true

		if not (s_id in RED_SUITS):
			all_red = false

		if not is_merchant_nolock:
			if r_id == "7":
				sevens_played += 1
				extra_draw += 2
			elif r_id == "8" and p_id == "":
				eights_played += 1
			elif r_id == "9" and p_id == "":
				nines_played += 1
			elif r_id == "10" and p_id == "":
				tens_played += 1
			elif r_id == "D" and p_id == "":
				lowers_played += 1
			elif r_id == "K" and p_id == "":
				kings_played += 1
				king_curse_suit = s_id
			elif r_id == "E":
				aces_played += 1
				extra_skip = true
			elif r_id == "H":
				horniks_played += 1

	var lead_val: int = card_vals[0]
	var same_value := true
	for cv in card_vals:
		if cv != lead_val:
			same_value = false
			break

	var base_subtotal := (lead_val * cnt) if same_value else sum_val
	var bonus_pts := 0
	var x_mult_product := 1.0
	var display_card_val := lead_val if same_value else int(round(float(sum_val) / float(cnt)))
	var mult_val := float(cnt)
	var breakdown_chips: Array[Dictionary] = []

	var running_pts := 0
	for ci in range(cnt):
		var c_d: Dictionary = played_cards[ci]
		var cv_i: int = card_vals[ci]
		running_pts += cv_i
		steps.append(_make_step(
			"card",
			("%d × %d" % [lead_val, ci + 1]) if same_value else ("+%d" % cv_i),
			"%s (%d pts)" % [str(c_d.get("rname", c_d.get("rank", "Card"))), cv_i],
			cv_i, 0.0, 1.0,
			running_pts, float(ci + 1), 1.0,
			Color(0.62, 0.90, 1.0)
		))
	breakdown_chips.append({
		"tag": ("%d×%d" % [display_card_val, cnt]) if same_value else ("SUM %d" % base_subtotal),
		"val": "+%d" % base_subtotal,
		"col": Color(0.68, 0.92, 1.0),
	})

	var final_score := base_subtotal

	var ace_hp_damage := 0
	if aces_played > 0:
		ace_hp_damage = 1 if aces_played == 1 else (4 if aces_played == 2 else 6)
		steps.append(_make_step(
			"prsi",
			("Úder Esa (-%d ♥ HP)" if cs else "Ace Strike (-%d ♥ HP)") % ace_hp_damage,
			"Stopka" if cs else "Turn Lock",
			0, 0.0, 1.0, final_score, mult_val, 1.0,
			Color(1.0, 0.86, 0.36), "", aces_played >= 2
		))

	if sevens_played > 0:
		steps.append(_make_step(
			"prsi",
			("Sedma: Soupeř +%d" if cs else "Seven: Rival +%d Draw") % (sevens_played * 2),
			"Trestné lízání" if cs else "Draw Barrage",
			0, 0.0, 1.0, final_score, mult_val, 1.0,
			Color(1.0, 0.56, 0.30), "", sevens_played >= 2
		))

	var rank_abilities_active := (not tutorial_mode) or (tutorial_step >= 3)
	if rank_abilities_active:
		if nines_played > 0:
			mage_charge_boost += nines_played
			redraws_gained += nines_played
		if tens_played > 0:
			bonus_gold += 10 * tens_played
		if lowers_played > 0:
			shields_gained += lowers_played

	if not tutorial_mode:
		for card in played_cards:
			var cls_id := Catalog.normalize_card_class(str(card.get("edition", card.get("card_class", "NORMAL"))))
			var cls_info := Catalog.get_card_class(cls_id)
			bonus_gold += int(cls_info.get("gold_bonus", 2))
			match cls_id:
				"MAGE":
					var m_chg := int(card.get("mage_charge", 0))
					var max_c := int(cls_info.get("max_charge", 2))
					if m_chg >= max_c:
						mage_draws += 1
						bonus_pts += 20
						x_mult_product *= 2.0
						rival_drain += 12
						lightning = true
						breakdown_chips.append({"tag": "MAGE 2/2" if not cs else "MÁG 2/2", "val": "+20 ×2", "col": Color(0.54, 0.72, 1.0)})
						steps.append(_make_step("edition", "MAGE BURST (+20 & ×2.0)", str(card.get("rname", "")), 20, 0.0, 2.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.64, 0.44, 1.0), "", true))
					else:
						bonus_pts += 5
						breakdown_chips.append({"tag": "MAGE" if not cs else "MÁG", "val": "+5", "col": Color(0.68, 0.52, 1.0)})
						steps.append(_make_step("edition", "ARCANE AURA (+5)", str(card.get("rname", "")), 5, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.64, 0.44, 1.0)))
				"KNIGHT":
					knight_mist_triggered = true
					bonus_pts += 10
					x_mult_product *= 1.5
					lightning = true
					breakdown_chips.append({"tag": "KNIGHT" if not cs else "RYTÍŘ", "val": "+10 ×1.5", "col": Color(0.66, 0.88, 1.0)})
					steps.append(_make_step("edition", "STEEL IMPACT (+10 & ×1.5)", str(card.get("rname", "")), 10, 0.0, 1.5, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.60, 0.88, 0.98), "", true))
				"MERCHANT":
					bonus_pts += 5
					breakdown_chips.append({"tag": "GUILD" if not cs else "KUPEC", "val": "+5 & +15g", "col": Color(1.0, 0.84, 0.28)})
					steps.append(_make_step("edition", "BULLION (+5 & +15g)", str(card.get("rname", "")), 5, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(1.0, 0.82, 0.24)))
				"THIEF":
					thief_heist_triggered = true
					bonus_pts += 10
					breakdown_chips.append({"tag": "THIEF" if not cs else "ZLODĚJ", "val": "+10", "col": Color(0.28, 0.92, 0.56)})
					steps.append(_make_step("edition", "SHADOW CUT (+10)", str(card.get("rname", "")), 10, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.28, 0.90, 0.56)))

		for card in played_cards:
			var p_id := str(card.get("power_id", ""))
			if p_id == "" or p_id == "SPEC_PRISM":
				continue
			var p_res := _apply_power_scoring(card, true, cnt, chosen_suit, current_hand, context, is_preview)
			var p_chips := int(p_res["chips"])
			var p_xm := float(p_res["x_mult"])
			bonus_pts += p_chips
			x_mult_product *= p_xm
			rival_drain += int(p_res["rival_drain"])
			bonus_gold += int(p_res["bonus_gold"])
			extra_draw += int(p_res["extra_draw"])
			if bool(p_res["extra_skip"]):
				extra_skip = true
			if bool(p_res["lightning"]):
				lightning = true
			if bool(p_res["surge_kept"]):
				surge_kept = true
				new_surge_mult += float(p_res["new_surge_mult"])
			if bool(p_res["jester_double"]):
				jester_triggers = 2
			if str(p_res["label"]) != "":
				var p_val_txt := ""
				if p_chips > 0 and p_xm > 1.01:
					p_val_txt = "+%d ×%.1f" % [p_chips, p_xm]
				elif p_chips > 0:
					p_val_txt = "+%d" % p_chips
				elif p_xm > 1.01:
					p_val_txt = "×%.1f" % p_xm
				else:
					p_val_txt = "FX"
				breakdown_chips.append({"tag": str(card.get("rname", p_id)), "val": p_val_txt, "col": card.get("accent", Color(1.0, 0.85, 0.3))})
				steps.append(_make_step(
					"power",
					str(p_res["label"]),
					str(card.get("rname", p_id)),
					p_chips, 0.0, p_xm,
					base_subtotal + bonus_pts, mult_val, x_mult_product,
					card.get("accent", Color(1.0, 0.85, 0.3)), "", bool(p_res["lightning"])
				))

		# Active 8 Core Build Relics & Bankai Awakening Buffs (v0.192 Overhaul)
		for _rt in range(jester_triggers):
			for card in played_cards:
				var s_id := str(card.get("suit", ""))
				var r_id := str(card.get("rank", ""))
				var has_pwr := str(card.get("power_id", "")) != ""
				var c_cls := Catalog.normalize_card_class(str(card.get("edition", card.get("card_class", "NORMAL"))))
				# Build 1: Guillotine Aces
				if "REL_FORGEMASTER" in active_relics and (r_id == "E" or c_cls == "KNIGHT"):
					bonus_pts += 15
					breakdown_chips.append({"tag": "Anvil", "val": "+15", "col": Color(0.32, 0.88, 1.0)})
					steps.append(_make_step("relic", "Executioner's Anvil (+15)", "Ace / Knight", 15, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.32, 0.88, 1.0), "REL_FORGEMASTER"))
				# Build 2: Mirror Monarch
				if "REL_ROYAL" in active_relics and (r_id in COURT_RANKS):
					bonus_pts += 12
					if r_id == "K":
						shields_gained += 1
					breakdown_chips.append({"tag": "Signet", "val": "+12", "col": Color(1.0, 0.84, 0.34)})
					steps.append(_make_step("relic", "Monarch's Signet (+12)", "Court Card", 12, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(1.0, 0.84, 0.34), "REL_ROYAL"))
				if "REL_IRON_BOOT" in active_relics and (r_id == "H" or r_id == "D"):
					x_mult_product *= 1.25
					breakdown_chips.append({"tag": "Aegis", "val": "×1.25", "col": Color(0.74, 0.82, 0.92)})
					steps.append(_make_step("relic", "Aegis Greaves (×1.25)", "Guard / Wild", 0, 0.0, 1.25, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.74, 0.82, 0.92), "REL_IRON_BOOT"))
				# Build 3: Chaos Jester
				if "REL_GREED" in active_relics:
					if s_id == "GULA" or has_pwr:
						bonus_gold += 8
						steps.append(_make_step("relic", "+8 Florins", "Trickster's Scale", 0, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(1.0, 0.82, 0.24), "REL_GREED"))
					if r_id == "H":
						bonus_pts += 12
						breakdown_chips.append({"tag": "Scale", "val": "+12", "col": Color(1.0, 0.82, 0.24)})
				if "REL_SEVEN_GRIMOIRE" in active_relics and (r_id == "7" or c_cls == "THIEF"):
					bonus_pts += 12
					rival_drain += 10
					breakdown_chips.append({"tag": "Grimoire", "val": "+12/-10", "col": Color(0.94, 0.40, 0.84)})
					steps.append(_make_step("relic", "Grimoire of Sevens (+12 & -10 Rival)", "Seven / Thief", 12, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.94, 0.40, 0.84), "REL_SEVEN_GRIMOIRE"))
				# Build 4: Mistblade Shadow
				if "REL_FANG" in active_relics and (s_id == "CERVEN" or cnt >= 2):
					bonus_pts += 8
					rival_drain += 12
					breakdown_chips.append({"tag": "Fang", "val": "-12 Rival", "col": Color(0.92, 0.20, 0.34)})
					steps.append(_make_step("relic", "Phantom Fang (+8 & -12 Rival)", "Shadow Affinity", 8, 0.0, 1.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.92, 0.20, 0.34), "REL_FANG"))
			if "REL_FORGEMASTER" in active_relics and cnt >= 2:
				bonus_pts += 20
				breakdown_chips.append({"tag": "Anvil Combo", "val": "+20", "col": Color(0.32, 0.88, 1.0)})
			if "REL_FINAL_TOLL" in active_relics and (cnt >= 2 or current_hand.size() <= 1):
				var toll_m := 2.0 if current_hand.size() <= 1 else 1.5
				x_mult_product *= toll_m
				lightning = true
				breakdown_chips.append({"tag": "Oath", "val": "×%.1f" % toll_m, "col": Color(1.0, 0.28, 0.34)})
				steps.append(_make_step("relic", "Executioner's Oath (×%.1f)" % toll_m, "Lethal Finish", 0, 0.0, toll_m, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(1.0, 0.28, 0.34), "REL_FINAL_TOLL", true))
			if "REL_OVERCHARGE" in active_relics and cnt >= 2:
				mage_charge_boost += 1
				var has_mage_or_pwr := false
				for mc in played_cards:
					if str(mc.get("power_id", "")) != "" or Catalog.normalize_card_class(str(mc.get("edition", mc.get("card_class", "NORMAL")))) == "MAGE":
						has_mage_or_pwr = true
						break
				if has_mage_or_pwr:
					x_mult_product *= 1.45
					lightning = true
					breakdown_chips.append({"tag": "Mist Conduit", "val": "×1.45", "col": Color(0.38, 0.96, 0.78)})
					steps.append(_make_step("relic", "Mistborn Conduit (×1.45)", "Mage / Power Surge", 0, 0.0, 1.45, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.38, 0.96, 0.78), "REL_OVERCHARGE", true))

		# Grand Seal Awakening Persistent Build Buff (4-card combo transformation)
		if bool(context.get("bankai_active", false)):
			var b_build := str(context.get("bankai_build_id", "GUILLOTINE_ACES"))
			var seal_tag := "SEAL" if not cs else "PEČEŤ"
			match b_build:
				"GUILLOTINE_ACES":
					x_mult_product *= 1.4
					bonus_pts += 15 * aces_played
					lightning = true
					breakdown_chips.append({"tag": seal_tag, "val": "×1.4", "col": Color(0.32, 0.88, 1.0)})
					steps.append(_make_step("relic", "GRAND SEAL: SEAL OF EXECUTION (×1.4)", "Awakened Execution", 15 * aces_played, 0.0, 1.4, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.32, 0.88, 1.0), "", true))
				"MIRROR_MONARCH":
					var court_cnt := 0
					for cc in played_cards:
						if str(cc.get("rank", "")) in COURT_RANKS:
							court_cnt += 1
					bonus_pts += 18 * maxi(1, court_cnt)
					x_mult_product *= 1.35
					shields_gained += 1
					breakdown_chips.append({"tag": seal_tag, "val": "×1.35 +SHIELD", "col": Color(1.0, 0.78, 0.28)})
					steps.append(_make_step("relic", "GRAND SEAL: SOVEREIGN SEAL (×1.35)", "Awakened Monarch", 18 * maxi(1, court_cnt), 0.0, 1.35, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(1.0, 0.78, 0.28), "", true))
				"CHAOS_JESTER":
					bonus_gold += 20
					rival_drain += 14
					if sevens_played > 0:
						extra_draw += 2 * sevens_played
					x_mult_product *= 1.35
					lightning = true
					breakdown_chips.append({"tag": seal_tag, "val": "×1.35 -14", "col": Color(0.96, 0.36, 0.78)})
					steps.append(_make_step("relic", "GRAND SEAL: JESTER'S PACT (×1.35)", "Awakened Chaos", 0, 0.0, 1.35, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.96, 0.36, 0.78), "", true))
				"MISTBLADE_DUELIST":
					mage_charge_boost += 2
					if cnt >= 2:
						rival_drain += 15
						x_mult_product *= 1.45
					else:
						x_mult_product *= 1.25
					lightning = true
					breakdown_chips.append({"tag": seal_tag, "val": "×1.45 -15", "col": Color(0.38, 0.96, 0.78)})
					steps.append(_make_step("relic", "GRAND SEAL: MISTBOUND RITE (×1.45)", "Awakened Shadow", 0, 0.0, 1.45 if cnt >= 2 else 1.25, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.38, 0.96, 0.78), "", true))

		# Active Tabletop Relic Buffs (Blood-Ink Seal ×2, Phantom Mask ×2, Storm Surge)
		if bool(context.get("blood_seal_active", false)):
			x_mult_product *= 2.0
			rival_drain += 10
			lightning = true
			breakdown_chips.append({"tag": "SEAL" if not cs else "PEČEŤ", "val": "×2", "col": Color(0.96, 0.14, 0.24)})
			steps.append(_make_step("relic", "Blood-Ink Seal (×2.0)", "Crimson Resonance", 0, 0.0, 2.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(0.96, 0.14, 0.24), "TRELIC_BLOOD_SEAL", true))
		if bool(context.get("hollow_mask_active", false)):
			x_mult_product *= 2.0
			lightning = true
			breakdown_chips.append({"tag": "PHANTOM", "val": "×2 WILD", "col": Color(1.0, 0.22, 0.30)})
			steps.append(_make_step("relic", "Phantom Mask (×2.0)", "Phantom Aura", 0, 0.0, 2.0, base_subtotal + bonus_pts, mult_val, x_mult_product, Color(1.0, 0.22, 0.30), "TRELIC_HOLLOW_MASK", true))
		var ctx_surge := float(context.get("surge_mult", 0.0))
		if ctx_surge > 0.01:
			var s_fac := maxf(1.5, roundf((1.0 + ctx_surge * 0.5) * 2.0) * 0.5)
			x_mult_product *= s_fac
			breakdown_chips.append({"tag": "SURGE", "val": "×%s" % _fmt_num(s_fac), "col": Color(0.32, 0.90, 1.0)})

	final_score = int(round(float(base_subtotal + bonus_pts) * x_mult_product))
	var eff_mult := mult_val * x_mult_product

	var did_shed := (not (tutorial_mode and tutorial_step < 6)) and current_hand.is_empty()
	var formula_txt := ""
	if bonus_pts > 0 and x_mult_product > 1.01:
		formula_txt = "(%d + %d) × %s = %d" % [base_subtotal, bonus_pts, _fmt_num(x_mult_product), final_score]
	elif bonus_pts > 0:
		formula_txt = "%d + %d = %d" % [base_subtotal, bonus_pts, final_score]
	elif x_mult_product > 1.01:
		formula_txt = "%d × %s = %d" % [base_subtotal, _fmt_num(x_mult_product), final_score]
	else:
		formula_txt = "%d × %d = %d" % [display_card_val, cnt, final_score]

	return {
		"card_value": display_card_val,
		"card_count": cnt,
		"base_subtotal": base_subtotal,
		"bonus_pts": bonus_pts,
		"base_chips": display_card_val,
		"card_chips": base_subtotal + bonus_pts,
		"total_chips": base_subtotal + bonus_pts,
		"flat_mult": mult_val,
		"x_mult_product": x_mult_product,
		"effective_mult": eff_mult,
		"final_score": final_score,
		"slam_name": slam_name,
		"shed_finisher": did_shed,
		"shed_rem_turns": 0,
		"shed_x_mult": 1.0,
		"rival_drain": rival_drain,
		"rival_bonus": rival_bonus,
		"bonus_gold": bonus_gold,
		"extra_draw": extra_draw,
		"extra_skip": extra_skip,
		"lightning": lightning,
		"surge_kept": surge_kept,
		"new_surge_mult": new_surge_mult,
		"jester_triggers": jester_triggers,
		"seven_grimoire_delta": 0.0,
		"seven_grimoire_new": 0.0,
		"seven_draw_bonus": 0,
		"ace_stun_bonus": 0,
		"ace_hp_damage": ace_hp_damage,
		"mage_charge_boost": mage_charge_boost,
		"mage_draws": mage_draws,
		"shields_gained": shields_gained,
		"redraws_gained": redraws_gained,
		"knight_mist_triggered": knight_mist_triggered,
		"thief_heist_triggered": thief_heist_triggered,
		"king_curse_suit": king_curse_suit,
		"formula_summary": formula_txt,
		"breakdown_chips": breakdown_chips,
		"steps": steps,
	}


static func _apply_power_scoring(
	card: Dictionary,
	allow_echo: bool,
	cnt: int,
	chosen_suit: String,
	current_hand: Array,
	context: Dictionary,
	is_preview: bool
) -> Dictionary:
	var p_id := str(card.get("power_id", ""))
	var res := {
		"chips": 0, "flat_mult": 0.0, "x_mult": 1.0,
		"rival_drain": 0, "bonus_gold": 0, "extra_draw": 0, "extra_skip": false,
		"lightning": false, "surge_kept": false, "new_surge_mult": 0.0, "jester_double": false,
		"label": "",
	}
	var cs := str(context.get("lang", "en")) == "cs"
	match p_id:
		"SPEC_VAMPIRE":
			res["rival_drain"] = 15
			res["chips"] = 15
			if chosen_suit == "CERVEN":
				res["x_mult"] = 1.5
				res["label"] = "Upír: +15 a ×1.5!" if cs else "Vampire: +15 & ×1.5!"
			else:
				res["label"] = "Upír: -15 Soupeř / +15" if cs else "Vampire: -15 Rival / +15"
		"SPEC_STORM":
			res["extra_draw"] = 3
			res["lightning"] = true
			res["surge_kept"] = true
			res["new_surge_mult"] = 1.0
			res["label"] = "Blesk: +3 lízání a ×1.5 výboj!" if cs else "Thunder: +3 Draw & ×1.5 Surge!"
		"SPEC_MIRROR":
			if allow_echo:
				var echo_card: Variant = context.get("echo_card", null)
				if echo_card is Dictionary and not echo_card.is_empty():
					var dc: Dictionary = echo_card
					var d_pts := get_base_card_chips(str(dc.get("rank", "")), int(dc.get("pts", 10))) if str(dc.get("power_id", "")) == "" else int(dc.get("pts", 18))
					res["chips"] = d_pts
					if str(dc.get("rank", "")) == "7":
						res["extra_draw"] = 2
					elif str(dc.get("rank", "")) == "E":
						res["extra_skip"] = true
					if str(dc.get("power_id", "")) != "":
						var sub := _apply_power_scoring(dc, false, cnt, chosen_suit, current_hand, context, is_preview)
						res["chips"] += int(sub["chips"])
						res["flat_mult"] += float(sub["flat_mult"])
						res["x_mult"] *= float(sub["x_mult"])
						res["rival_drain"] += int(sub["rival_drain"])
						res["bonus_gold"] += int(sub["bonus_gold"])
						res["extra_draw"] += int(sub["extra_draw"])
						res["extra_skip"] = bool(res["extra_skip"]) or bool(sub["extra_skip"])
						res["surge_kept"] = bool(res["surge_kept"]) or bool(sub["surge_kept"])
						res["new_surge_mult"] += float(sub["new_surge_mult"])
						res["jester_double"] = bool(res["jester_double"]) or bool(sub["jester_double"])
						res["lightning"] = res["lightning"] or bool(sub["lightning"])
					res["label"] = ("Zrcadlo: +%d (%s)" if cs else "Mirror Echo: +%d (%s)") % [res["chips"], str(dc.get("rname", "Card"))]
				else:
					res["chips"] = 18
					res["label"] = "Zrcadlo: +18 bodů" if cs else "Mirror: +18 Chips"
		"SPEC_ALCHEMIST":
			res["lightning"] = true
			res["label"] = "⚗ Alchymista: +1 Baňka!" if cs else "⚗ Alchemist: +1 Phial & Promote!"
		"SPEC_ORACLE":
			res["extra_draw"] = 0
			res["label"] = "Věštec: Odhalení & +1!" if cs else "Seer's Eye: Reveal & +1 Card!"
		"SPEC_PHOENIX":
			res["chips"] = 30
			res["lightning"] = true
			res["label"] = "Fénix: +30 a Čistka" if cs else "Ash Phoenix: +30 Burn & Clear"
		"SPEC_MIDAS":
			res["bonus_gold"] = 15
			res["chips"] = 20
			res["label"] = "Midas: +20 b. & +15g!" if cs else "Midas Touch: +20 & +15g!"
		"SPEC_CHRONOS":
			res["lightning"] = true
			res["label"] = "Chronos: Tah navíc!" if cs else "Chronos Glass: Extra Turn!"
		"SPEC_JESTER":
			res["jester_double"] = true
			res["lightning"] = true
			res["label"] = "Šašek: Relikvie 2×!" if cs else "Tavern Jester: Relics 2×!"
		"SPEC_HEX":
			res["rival_drain"] = 15
			res["chips"] = 15
			res["label"] = "Stínový hex: -15 / +15" if cs else "Shadow Hex: -15 Rival / +15"
		"SPEC_MAGNET":
			res["label"] = "Magnet: Přitáhni pár!" if cs else "Rune Magnet: Pull Match Duo!"
		"SPEC_SHIELD":
			res["label"] = "Železná bašta: +2 Štíty!" if cs else "Iron Bastion: +2 Shields!"
		"SPEC_GAMBLER":
			var d_mult := 3.0 if cnt >= 2 else 2.0
			var roll_override := float(context.get("gambler_roll", 0.0))
			if roll_override > 0.0:
				d_mult = roll_override
			res["x_mult"] = d_mult
			res["lightning"] = true
			res["label"] = ("Kostky: ×%s!" if cs else "Loaded Dice: ×%s!") % _fmt_num(d_mult)
		"SPEC_PLAGUE":
			res["rival_drain"] = 15
			res["label"] = "❄ Mráz: Omráčení & -15" if cs else "❄ Frost Blight: Stun & -15"
		"SPEC_CROWN":
			var courts := 0
			for hc in current_hand:
				if str(hc.get("rank", "")) in COURT_RANKS:
					courts += 1
			var bonus_c := courts * 20
			res["chips"] = bonus_c
			res["label"] = ("Královský dekret: +%d (%d figur)" if cs else "Royal Decree: +%d (%d Courts)") % [bonus_c, courts]
	return res
