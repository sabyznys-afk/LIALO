extends RefCounted
class_name ScoringEngine
## Three-Tier Exponential Scoring Engine for LIALO (Balatro-inspired Prší deckbuilder)
## Formula: Final Score = round(Total Chips × Flat Mult × Π X-Mults)

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

const SLAM_BASE_CHIPS := {1: 12, 2: 36, 3: 80, 4: 150}
const SLAM_BASE_MULT := {1: 1.0, 2: 1.8, 3: 2.8, 4: 4.5}

const PRSI_7_CHIPS := 7
const PRSI_7_MULT := 0.4
const PRSI_7_COUNTER_CHIPS := 21
const PRSI_7_COUNTER_XMULT := 1.35
const PRSI_7_VOLLEY_MULT := 0.8

const PRSI_ACE_CHIPS := 15
const PRSI_ACE_MULT := 0.4
const PRSI_ACE_COUNTER_XMULT := 1.30

const PRSI_HORNIK_SHIFT_CHIPS := 12
const PRSI_HORNIK_SHIFT_MULT := 0.25

const SHED_PAR_TURNS := 12
const SHED_BASE_CHIPS := 120
const SHED_BASE_XMULT := 2.00
const SHED_EXP_PER_TURN := 1.22

const SEVEN_GRIMOIRE_STEP := 0.15
const MERCHANT_LEDGER_CHIP_STEP := 18

const RANK_ABILITY_INFO := {
	"7": {
		"title": "Seven Barrage", "title_cs": "Sedmový útok",
		"badge": "⚡ +2 DRAW (3×)", "badge_cs": "⚡ +2 LÍZÁNÍ (3×)",
		"col": Color(0.95, 0.34, 0.34),
		"desc": "Rival draws +2 unless blocked by 7! Scores 3× (21 pts) if they draw!",
		"desc_cs": "Soupeř líže +2, pokud nedá další 7! Když líže, získáš 3× (21 b.)!"
	},
	"8": {
		"title": "Eight Infinity", "title_cs": "Nekonečná Osma",
		"badge": "∞ STACK 8s", "badge_cs": "∞ VÍCE KARET",
		"col": Color(0.32, 0.88, 1.0),
		"desc": "ONLY card you can stack multiple copies of at once!",
		"desc_cs": "JEDINÁ karta, které můžeš vyložit více kusů najednou!"
	},
	"9": {
		"title": "Nine Conduit", "title_cs": "Vysátí Devítky",
		"badge": "✨ +1 CHARGE", "badge_cs": "✨ +1 NABITÍ",
		"col": Color(0.92, 0.38, 0.68),
		"desc": "Drains -9 pts, charges Mage cards (+1) & grants +1 Redraw.",
		"desc_cs": "Sebere -9 b. soupeři, nabije Mágy (+1) a přidá +1 výměnu."
	},
	"10": {
		"title": "Ten Bullion", "title_cs": "Zlatá Desítka",
		"badge": "🪙 +10 GOLD", "badge_cs": "🪙 +10 ZLATO",
		"col": Color(1.0, 0.82, 0.24),
		"desc": "Mints +10 Florins & adds +0.5× Mult.",
		"desc_cs": "Vyrazí +10 Zlatých a přidá +0.5× násobitel."
	},
	"D": {
		"title": "Jack Guard", "title_cs": "Obrana Spodka",
		"badge": "🛡 +1 SHIELD", "badge_cs": "🛡 +1 ŠTÍT",
		"col": Color(0.46, 0.94, 0.56),
		"desc": "+1 Guard Shield (blocks curses/HP) & +12 bonus pts.",
		"desc_cs": "+1 Štít proti kletbám a poškození + 12 bodů."
	},
	"H": {
		"title": "Queen Wild", "title_cs": "Změna barvy (Svršek)",
		"badge": "🌈 WILD SUIT", "badge_cs": "🌈 ZMĚNA BARVY",
		"col": Color(0.74, 0.52, 1.0),
		"desc": "Play on any suit and pick the next table suit!",
		"desc_cs": "Lze dát na cokoli a zvolit novou barvu na stole!"
	},
	"K": {
		"title": "King Challenge", "title_cs": "Královský útok",
		"badge": "👑 1-3 HP DMG", "badge_cs": "👑 1–3 HP ÚTOK",
		"col": Color(1.0, 0.72, 0.28),
		"desc": "1–3 ♥ HP Damage & Curse unless Rival blocks with a King!",
		"desc_cs": "Ubírá 1–3 ♥ HP a kletbu, pokud soupeř nemá Krále!"
	},
	"E": {
		"title": "Ace Strike", "title_cs": "Stopka Esa",
		"badge": "⚡ 1/4/6 HP DMG", "badge_cs": "⚡ 1/4/6 HP ÚTOK",
		"col": Color(0.96, 0.86, 0.32),
		"desc": "Stack max 3 Aces: deals 1 / 4 / 6 ♥ HP DMG + Stun!",
		"desc_cs": "Max 3 Esa najednou: bere 1 / 4 / 6 ♥ HP a zastaví soupeře!"
	},
}

static func get_rank_ability_info(rank_id: String, lang: String = "en") -> Dictionary:
	var d: Dictionary = (RANK_ABILITY_INFO.get(rank_id, {}) as Dictionary).duplicate()
	if not d.is_empty() and lang == "cs":
		d["title"] = str(d.get("title_cs", d.get("title", "")))
		d["badge"] = str(d.get("badge_cs", d.get("badge", "")))
		d["desc"] = str(d.get("desc_cs", d.get("desc", "")))
	return d


static func get_base_card_chips(rank_id: String, fallback_pts: int = 10) -> int:
	if BASE_CARD_CHIPS.has(rank_id):
		return int(BASE_CARD_CHIPS[rank_id])
	return fallback_pts


static func get_slam_name(cnt: int, played_cards: Array, lang: String = "en") -> String:
	if lang == "cs":
		if cnt <= 1:
			if played_cards.size() == 1 and str(played_cards[0].get("power_id", "")) != "":
				return "Mocná karta"
			return "Tah kartou"
		if cnt == 2:
			return "Dvojkombo"
		if cnt == 3:
			return "Trojkombo"
		if cnt == 4:
			return "Čtyřkombo"
		return "%d× Mega kombo" % cnt
	if cnt <= 1:
		if played_cards.size() == 1 and str(played_cards[0].get("power_id", "")) != "":
			return "Arcane Play"
		return "Single Strike"
	if cnt == 2:
		return "Pair Slam"
	if cnt == 3:
		return "Triple Slam"
	if cnt == 4:
		return "Quad Slam"
	return "%d-Card Over-Slam" % cnt


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
			"formula_summary": "0 Chips × 1.0 Mult = 0",
			"steps": steps,
		}

	var tutorial_mode := bool(context.get("tutorial_mode", false))
	var tutorial_step := int(context.get("tutorial_step", 0))
	var lang := str(context.get("lang", "en"))
	var cs := (lang == "cs")
	var is_preview := bool(context.get("is_preview", false))
	var chosen_suit := str(context.get("chosen_suit", played_cards[cnt - 1].get("suit", "CERVEN")))
	var prev_suit := str(context.get("prev_suit", chosen_suit))
	var pending_draw_before := int(context.get("pending_draw_before", 0))
	var pending_skip_before := bool(context.get("pending_skip_before", false))
	var storm_surge := float(context.get("storm_surge_mult", 0.0))
	var relic_scales: Dictionary = context.get("relic_scales", {})
	var shop_rerolls := int(context.get("shop_rerolls", 0))
	var match_turn_count := maxi(1, int(context.get("match_turn_count", 1)))
	var boss_mod := str(context.get("boss_mod", ""))

	var slam_name := get_slam_name(cnt, played_cards, lang)
	var base_chips := int(SLAM_BASE_CHIPS.get(cnt, 180 + maxi(0, cnt - 4) * 55))
	var flat_mult := float(SLAM_BASE_MULT.get(cnt, 5.0 + float(maxi(0, cnt - 4)) * 1.5))
	var x_mult_product := 1.0

	var chips := base_chips
	var card_chips_sum := 0
	var rival_drain := 0
	var rival_bonus := 0
	var bonus_gold := 0
	var extra_draw := 0
	var extra_skip := false
	var lightning := (cnt >= 2)
	var surge_kept := false
	var new_surge_mult := 0.0

	steps.append(_make_step(
		"slam",
		"%s (%d+%.1f×)" % [slam_name, base_chips, flat_mult],
		"%d card(s)" % cnt,
		base_chips, flat_mult, 1.0,
		chips, flat_mult, x_mult_product,
		Color(0.95, 0.80, 0.36), "", lightning
	))

	if not tutorial_mode and bool(context.get("flow_chain", false)):
		chips += 10
		flat_mult += 0.5
		steps.append(_make_step(
			"prsi",
			"+10 / +0.5× Vzestupný tok!" if cs else "+10 / +0.5× Tavern Flow!",
			"Řetězení barvy či hodnoty" if cs else "Suit or Rank chain rhythm",
			10, 0.5, 1.0,
			chips, flat_mult, x_mult_product,
			Color(0.45, 0.96, 0.72)
		))

	if not tutorial_mode and storm_surge > 0.0:
		flat_mult += storm_surge
		steps.append(_make_step(
			"prsi",
			("+%.1f× Bouřná vlna" if cs else "+%.1f× Storm Surge") % storm_surge,
			"Přenesený náboj bouře" if cs else "Carried thundercharge",
			0, storm_surge, 1.0,
			chips, flat_mult, x_mult_product,
			Color(0.38, 0.90, 1.0), "", true
		))

	# 1. Base Card Chips
	var midas_played := false
	for card in played_cards:
		if str(card.get("power_id", "")) == "SPEC_MIDAS":
			midas_played = true
			break

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
	var jester_triggers := 1
	var knight_mist_triggered := false
	var thief_heist_triggered := false
	var mage_draws := 0

	for card in played_cards:
		var r_id := str(card.get("rank", ""))
		var s_id := str(card.get("suit", ""))
		var p_id := str(card.get("power_id", ""))
		var cls_id := Catalog.normalize_card_class(str(card.get("edition", card.get("card_class", "NORMAL"))))
		var is_merchant_nolock := (cls_id == "MERCHANT" and p_id == "")
		var base_pts := int(card.get("pts", get_base_card_chips(r_id))) if p_id != "" else (get_base_card_chips(r_id, int(card.get("pts", 10))) + int(card.get("bonus_chips", 0)))
		if midas_played and p_id == "" and (s_id == "GULA" or r_id in COURT_RANKS):
			base_pts *= 2
		chips += base_pts
		card_chips_sum += base_pts
		# Merchant Guildsman cards forfeit rank combat abilities in exchange for massive Gold payout!
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
		if not (s_id in RED_SUITS):
			all_red = false

		steps.append(_make_step(
			"card",
			("+%d b." if cs else "+%d Chips") % base_pts,
			("%s [%s]" % [str(card.get("rname", r_id)), ("Kupec" if cs else "Merchant")]) if is_merchant_nolock else ("%s" % str(card.get("rname", r_id))),
			base_pts, 0.0, 1.0,
			chips, flat_mult, x_mult_product,
			Color(1.0, 0.84, 0.30) if is_merchant_nolock else Color(0.62, 0.90, 1.0)
		))

	# 2. Prší Special Play Bonuses (Seven Draw Stacks, Ace Skips, Upper Suit Shifts)
	if sevens_played > 0:
		var c_add := PRSI_7_CHIPS * sevens_played
		var m_add := PRSI_7_MULT * float(sevens_played)
		chips += c_add
		flat_mult += m_add
		steps.append(_make_step(
			"prsi",
			("+%d / +%.1f× Útok Sedmou" if cs else "+%d / +%.1f× Seven Attack") % [c_add, m_add],
			("Lízání +%d" if cs else "Seven Draw +%d") % (sevens_played * 2),
			c_add, m_add, 1.0,
			chips, flat_mult, x_mult_product,
			Color(1.0, 0.56, 0.30), "", sevens_played >= 2
		))
		if sevens_played >= 2:
			flat_mult += PRSI_7_VOLLEY_MULT
			lightning = true
			steps.append(_make_step(
				"prsi",
				("+%.1f× Salva Sedmiček!" if cs else "+%.1f× Seven Volley!") % PRSI_7_VOLLEY_MULT,
				("%d× Sedmy" if cs else "%d× Sevens Stacked") % sevens_played,
				0, PRSI_7_VOLLEY_MULT, 1.0,
				chips, flat_mult, x_mult_product,
				Color(1.0, 0.42, 0.24), "", true
			))
		if pending_draw_before > 0:
			chips += PRSI_7_COUNTER_CHIPS
			x_mult_product *= PRSI_7_COUNTER_XMULT
			lightning = true
			steps.append(_make_step(
				"prsi",
				("×%.2f Přebití Sedmy! (+%d)" if cs else "×%.2f Draw Rebound! (+%d)") % [PRSI_7_COUNTER_XMULT, PRSI_7_COUNTER_CHIPS],
				("Odraženo +%d" if cs else "Reflected +%d Seven curse") % pending_draw_before,
				PRSI_7_COUNTER_CHIPS, 0.0, PRSI_7_COUNTER_XMULT,
				chips, flat_mult, x_mult_product,
				Color(1.0, 0.72, 0.28), "", true
			))

	var ace_hp_damage := 0
	if aces_played > 0:
		ace_hp_damage = 1 if aces_played == 1 else (4 if aces_played == 2 else 6)
		var ac_add := PRSI_ACE_CHIPS * aces_played
		var am_add := PRSI_ACE_MULT * float(aces_played)
		chips += ac_add
		flat_mult += am_add
		steps.append(_make_step(
			"prsi",
			("+%d / +%.1f× Úder Esa (-%d ♥ HP!)" if cs else "+%d / +%.1f× Ace Strike (-%d ♥ HP!)") % [ac_add, am_add, ace_hp_damage],
			("Stopka & -%d HP" if cs else "Turn Lock & -%d Rival HP") % ace_hp_damage,
			ac_add, am_add, 1.0,
			chips, flat_mult, x_mult_product,
			Color(1.0, 0.86, 0.36), "", aces_played >= 2
		))
		if pending_skip_before:
			x_mult_product *= PRSI_ACE_COUNTER_XMULT
			lightning = true
			steps.append(_make_step(
				"prsi",
				("×%.2f Proti-Eso!" if cs else "×%.2f Skip Breaker!") % PRSI_ACE_COUNTER_XMULT,
				"Přebití soupeřova Esa" if cs else "Countered Rival Ace Lock",
				0, 0.0, PRSI_ACE_COUNTER_XMULT,
				chips, flat_mult, x_mult_product,
				Color(1.0, 0.92, 0.44), "", true
			))

	if horniks_played > 0 and chosen_suit != prev_suit:
		chips += PRSI_HORNIK_SHIFT_CHIPS
		flat_mult += PRSI_HORNIK_SHIFT_MULT
		steps.append(_make_step(
			"prsi",
			("+%d / +%.2f× Změna barvy" if cs else "+%d / +%.2f× Suit Decree") % [PRSI_HORNIK_SHIFT_CHIPS, PRSI_HORNIK_SHIFT_MULT],
			("Svršek změnil na %s" if cs else "Upper shifted suit to %s") % chosen_suit,
			PRSI_HORNIK_SHIFT_CHIPS, PRSI_HORNIK_SHIFT_MULT, 1.0,
			chips, flat_mult, x_mult_product,
			Color(0.76, 0.88, 1.0)
		))

	var mage_charge_boost := 0
	var shields_gained := 0
	var redraws_gained := 0

	# 2B. Evolved Rank Abilities (Active in Act II Tutorial step >= 3 and all normal matches)
	var rank_abilities_active := (not tutorial_mode) or (tutorial_step >= 3)
	if rank_abilities_active:
		if eights_played > 0:
			var e_chips := 16 * eights_played
			var e_x := 1.25 if eights_played >= 2 else 1.0
			chips += e_chips
			x_mult_product *= e_x
			if eights_played >= 2:
				lightning = true
			steps.append(_make_step(
				"prsi",
				(("+%d & ×1.25 ∞ Řetěz Osmiček!" if cs else "+%d & ×1.25 ∞ Eight Chain!") % e_chips) if eights_played >= 2 else (("+" + str(e_chips) + (" ∞ Osma" if cs else " ∞ Eight Link"))),
				("%d× Osma" if cs else "%d× Stackable Eight(s)") % eights_played,
				e_chips, 0.0, e_x,
				chips, flat_mult, x_mult_product,
				Color(0.35, 0.90, 1.0), "", eights_played >= 2
			))
		if nines_played > 0:
			var n_chips := 9 * nines_played
			var n_drain := 9 * nines_played
			chips += n_chips
			rival_drain += n_drain
			mage_charge_boost += nines_played
			redraws_gained += nines_played
			steps.append(_make_step(
				"prsi",
				("+%d b. / -%d Soupeř & +1 Mág" if cs else "+%d Chips / -%d Rival & +1 Mage Charge") % [n_chips, n_drain],
				"Vysátí Devítkou" if cs else "Nine Soul Conduit",
				n_chips, 0.0, 1.0,
				chips, flat_mult, x_mult_product,
				Color(0.95, 0.42, 0.72)
			))
		if tens_played > 0:
			var t_chips := 10 * tens_played
			var t_mult := 0.5 * float(tens_played)
			var t_gold := 10 * tens_played
			chips += t_chips
			flat_mult += t_mult
			bonus_gold += t_gold
			steps.append(_make_step(
				"prsi",
				("+%d / +%.1f× & +%dg (Desítka)" if cs else "+%d / +%.1f× & +%dg (Ten Bullion)") % [t_chips, t_mult, t_gold],
				"Cechovní zlato" if cs else "Royal Guild Bullion",
				t_chips, t_mult, 1.0,
				chips, flat_mult, x_mult_product,
				Color(1.0, 0.84, 0.26)
			))
		if lowers_played > 0:
			var d_chips := 12 * lowers_played
			var rival_low_hand := int(context.get("rival_hand_size", 5)) <= 4
			var d_mult := 1.0 * float(lowers_played) if rival_low_hand else 0.4 * float(lowers_played)
			shields_gained += lowers_played
			chips += d_chips
			flat_mult += d_mult
			steps.append(_make_step(
				"prsi",
				("+1 Štít / +%d & +%.1f× (Spodek)" if cs else "+1 Shield / +%d & +%.1f× (Jack)") % [d_chips, d_mult],
				"Strážce (Spodek)" if cs else "Vanguard Guard & Flank",
				d_chips, d_mult, 1.0,
				chips, flat_mult, x_mult_product,
				Color(0.46, 0.94, 0.56)
			))
		if kings_played > 0:
			var suit_names := ({"CERVEN": "♥ Srdcový Král", "GULA": "● Kulový Král", "ZELEN": "♠ Listový Král", "ZALUD": "♣ Žaludový Král"} if cs else {"CERVEN": "♥ Hearts Drain", "GULA": "♦ Bells Tax", "ZELEN": "♠ Leaves Venom", "ZALUD": "♣ Acorns Shatter"})
			var k_chips := 18 * kings_played
			chips += k_chips
			lightning = true
			steps.append(_make_step(
				"prsi",
				"👑 %s (+%d)" % [str(suit_names.get(king_curse_suit, "Kletba Krále" if cs else "Royal Curse")), k_chips],
				"Kletba udeří, pokud soupeř nemá Krále!" if cs else "Curse hits unless Rival plays a King!",
				k_chips, 0.0, 1.0,
				chips, flat_mult, x_mult_product,
				Color(1.0, 0.76, 0.28), "", true
			))

	# 3. Five Fantasy Card Classes (Normal / Mage / Knight / Merchant / Thief) & Power Cards
	var ed_card_count := 0
	if not tutorial_mode:
		for card in played_cards:
			var p_id_chk := str(card.get("power_id", ""))
			var cls_id := Catalog.normalize_card_class(str(card.get("edition", card.get("card_class", "NORMAL"))))
			var cls_info := Catalog.get_card_class(cls_id)
			var g_add := int(cls_info.get("gold_bonus", 2))
			bonus_gold += g_add
			if cls_id != "NORMAL":
				ed_card_count += 1
			match cls_id:
				"NORMAL":
					if p_id_chk == "" and g_add > 0:
						steps.append(_make_step(
							"edition",
							("+%dg Krčmová" if cs else "+%dg Ironborne") % g_add,
							str(card.get("rname", "")),
							0, 0.0, 1.0,
							chips, flat_mult, x_mult_product,
							cls_info.get("col", Color(0.76, 0.72, 0.64))
						))
				"MAGE":
					var m_chg := int(card.get("mage_charge", 0))
					var max_c := int(cls_info.get("max_charge", 2))
					if m_chg >= max_c:
						chips += 65
						x_mult_product *= 2.0
						rival_drain += 15
						mage_draws += 1
						lightning = true
						steps.append(_make_step(
							"edition",
							("🔮 MÁG NABITÝ (%d/%d): +65 & ×2.0!" if cs else "🔮 MAGE OVERLOAD (%d/%d): +65 & ×2.0!") % [m_chg, max_c],
							("%s (-15 Soupeř, +1 Karta)" if cs else "%s (-15 Zap, +1 Draw)") % str(card.get("rname", "")),
							65, 0.0, 2.0,
							chips, flat_mult, x_mult_product,
							cls_info.get("col", Color(0.64, 0.44, 1.0)), "", true
						))
					else:
						chips += 6
						steps.append(_make_step(
							"edition",
							("🔮 Mág (%d/%d): +6 b." if cs else "🔮 Mage Spark (%d/%d): +6 Chips") % [m_chg, max_c],
							("Drž v ruce ještě %d kolo" if cs else "Hold in hand %d more turn(s)") % maxi(1, max_c - m_chg),
							6, 0.0, 1.0,
							chips, flat_mult, x_mult_product,
							Color(0.54, 0.44, 0.78)
						))
				"KNIGHT":
					knight_mist_triggered = true
					chips += 18
					flat_mult += 0.8
					lightning = true
					steps.append(_make_step(
						"edition",
						"⚔ RYTÍŘ V MLZE: +18 & +0.8×" if cs else "⚔ KNIGHT MISTBLADE: +18 & +0.8×",
						"Zmizí v mlze (+1 karta soupeři při chybě!)" if cs else "Vanishes in Battle Fog (+1 Rival Draw if wrong guess!)",
						18, 0.8, 1.0,
						chips, flat_mult, x_mult_product,
						cls_info.get("col", Color(0.60, 0.88, 0.98)), "", true
					))
				"MERCHANT":
					steps.append(_make_step(
						"edition",
						("🪙 KUPEC: +%dg Zlatých!" if cs else "🪙 GUILDSMAN: +%dg Florins!") % g_add,
						("%s (Zlato bez schopnosti)" if cs else "%s (Pure Gold, No Ability)") % str(card.get("rname", "")),
						0, 0.0, 1.0,
						chips, flat_mult, x_mult_product,
						cls_info.get("col", Color(1.0, 0.82, 0.24))
					))
				"THIEF":
					thief_heist_triggered = true
					chips += 10
					steps.append(_make_step(
						"edition",
						("🗡 ZLODĚJ (+%dg)" if cs else "🗡 CUTPURSE HEIST (+%dg)") % g_add,
						"Tipni 2+ karty soupeře: ukradneš kartu +2 lízání!" if cs else "Guess Rival pairs (2+): Steal 1 Card & Rival +2 Draw!",
						10, 0.0, 1.0,
						chips, flat_mult, x_mult_product,
						cls_info.get("col", Color(0.28, 0.90, 0.56))
					))

		for card in played_cards:
			var p_id := str(card.get("power_id", ""))
			if p_id == "":
				continue
			var p_res := _apply_power_scoring(card, true, cnt, chosen_suit, current_hand, context, is_preview)
			chips += int(p_res["chips"])
			flat_mult += float(p_res["flat_mult"])
			x_mult_product *= float(p_res["x_mult"])
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
				steps.append(_make_step(
					"power",
					str(p_res["label"]),
					str(card.get("rname", p_id)),
					int(p_res["chips"]), float(p_res["flat_mult"]), float(p_res["x_mult"]),
					chips, flat_mult, x_mult_product,
					card.get("accent", Color(1.0, 0.85, 0.3)), "", bool(p_res["lightning"])
				))

	# 4. Equipped Relics Cascade (doubled if Prší Jester is active!)
	var seven_grimoire_base := float(relic_scales.get("REL_SEVEN_GRIMOIRE", 0.0))
	var seven_grimoire_cur := seven_grimoire_base
	var seven_grimoire_delta := 0.0
	var knuckle_override = context.get("knuckle_roll", null)

	if not tutorial_mode:
		for trig_i in range(jester_triggers):
			# Flat Chip Relics (Card & Play triggered)
			if "REL_KNUCKLE" in active_relics:
				var k_hit := false
				if knuckle_override != null:
					k_hit = bool(knuckle_override)
				elif not is_preview:
					k_hit = (randf() < 0.35)
				if k_hit:
					var rt_c := get_base_card_chips(str(played_cards[0].get("rank", "")), int(played_cards[0].get("pts", 15)))
					chips += rt_c
					steps.append(_make_step("relic", "+%d Retrigger!" % rt_c, "Loaded Knucklebone", rt_c, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.96, 0.86, 0.62), "REL_KNUCKLE"))

			if "REL_FORGEMASTER" in active_relics and cnt >= 2:
				var f_c := 45 * cnt
				chips += f_c
				steps.append(_make_step("relic", "+%d Chips" % f_c, "Anvil Tally (%d× Slam)" % cnt, f_c, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.95, 0.65, 0.28), "REL_FORGEMASTER"))

			if "REL_MERCHANT_LEDGER" in active_relics:
				var stored_m := int(relic_scales.get("REL_MERCHANT_LEDGER", shop_rerolls * MERCHANT_LEDGER_CHIP_STEP))
				var m_c := maxi(MERCHANT_LEDGER_CHIP_STEP, stored_m + MERCHANT_LEDGER_CHIP_STEP)
				chips += m_c
				steps.append(_make_step("relic", "+%d Chips" % m_c, "Peddler's Ledger", m_c, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(1.0, 0.84, 0.32), "REL_MERCHANT_LEDGER"))

			for card in played_cards:
				var s_id := str(card.get("suit", ""))
				var r_id := str(card.get("rank", ""))
				var has_pwr := str(card.get("power_id", "")) != ""
				if "REL_CHAMOIS" in active_relics and (s_id == "ZALUD" or has_pwr):
					chips += 25
					steps.append(_make_step("relic", "+25 Chips", "Chamois Horn", 25, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.92, 0.72, 0.32), "REL_CHAMOIS"))
				if "REL_ROYAL" in active_relics and (r_id in COURT_RANKS):
					chips += 25
					steps.append(_make_step("relic", "+25 Chips", "King's Signet", 25, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(1.0, 0.88, 0.38), "REL_ROYAL"))
				if "REL_WOODCUTTER" in active_relics and (s_id == "ZALUD" or r_id == "7"):
					chips += 30
					steps.append(_make_step("relic", "+30 Chips", "Forest Cleaver", 30, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.76, 0.62, 0.30), "REL_WOODCUTTER"))
				if "REL_RED_SEAL" in active_relics and (s_id in RED_SUITS):
					chips += 28
					steps.append(_make_step("relic", "+28 Chips", "Waxed Sigil", 28, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.94, 0.34, 0.30), "REL_RED_SEAL"))
				if "REL_FANG" in active_relics and s_id == "CERVEN":
					rival_drain += 10
					steps.append(_make_step("relic", "Drain -10", "Crimson Fang", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.90, 0.18, 0.30), "REL_FANG"))
				if "REL_GREED" in active_relics and s_id == "GULA":
					bonus_gold += 4
					steps.append(_make_step("relic", "+4 Florins", "Merchant Scale", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(1.0, 0.84, 0.20), "REL_GREED"))

			# Flat Mult Relics
			if "REL_FUJARA" in active_relics and cnt == 1:
				flat_mult += 2.5
				steps.append(_make_step("relic", "+2.5× Solo", "Copper Fujara", 0, 2.5, 1.0, chips, flat_mult, x_mult_product, Color(0.95, 0.56, 0.28), "REL_FUJARA"))

			if "REL_STORMCAP" in active_relics and cnt >= 2:
				flat_mult += 3.5
				lightning = true
				steps.append(_make_step("relic", "+3.5× Storm!", "Storm Capacitor", 0, 3.5, 1.0, chips, flat_mult, x_mult_product, Color(0.38, 0.90, 1.0), "REL_STORMCAP", true))

			if "REL_OVERCHARGE" in active_relics and cnt >= 2:
				var o_m := float(cnt - 1) * 2.0
				flat_mult += o_m
				steps.append(_make_step("relic", "+%.1f× Rod" % o_m, "Tatra Rod", 0, o_m, 1.0, chips, flat_mult, x_mult_product, Color(0.46, 0.96, 1.0), "REL_OVERCHARGE"))

			if "REL_CRIMSON_CHOIR" in active_relics and all_red:
				flat_mult += 5.0
				steps.append(_make_step("relic", "+5.0× Choir!", "Crimson Choir", 0, 5.0, 1.0, chips, flat_mult, x_mult_product, Color(0.96, 0.28, 0.42), "REL_CRIMSON_CHOIR"))

			if "REL_GREEN_CANOPY" in active_relics:
				var bg_held := 0
				for hc in current_hand:
					if str(hc.get("suit", "")) in BLACK_GREEN_SUITS:
						bg_held += 1
				if bg_held >= 2:
					flat_mult += 6.0
					steps.append(_make_step("relic", "+6.0× Canopy!", "Highland Canopy (%d held)" % bg_held, 0, 6.0, 1.0, chips, flat_mult, x_mult_product, Color(0.26, 0.82, 0.52), "REL_GREEN_CANOPY"))

			if "REL_PRSI_PURIST" in active_relics and cnt == 1 and str(played_cards[0].get("rank", "")) in ["7", "H", "E"]:
				flat_mult += 4.5
				steps.append(_make_step("relic", "+4.5× Purist!", "Tavern Purist", 0, 4.5, 1.0, chips, flat_mult, x_mult_product, Color(0.94, 0.78, 0.36), "REL_PRSI_PURIST"))

			# Scaling & Explosive X-Mult Relics
			if "REL_SEVEN_GRIMOIRE" in active_relics:
				if sevens_played > 0:
					var d := float(sevens_played) * SEVEN_GRIMOIRE_STEP
					seven_grimoire_cur += d
					seven_grimoire_delta += d
				var s_x := 1.0 + seven_grimoire_cur
				if s_x > 1.0:
					x_mult_product *= s_x
					steps.append(_make_step("relic", "×%.2f Grimoire" % s_x, "Ledger of Sevens (+%.2f/7)" % SEVEN_GRIMOIRE_STEP, 0, 0.0, s_x, chips, flat_mult, x_mult_product, Color(0.82, 0.46, 1.0), "REL_SEVEN_GRIMOIRE", s_x >= 1.6))

			if "REL_PRISM_ORB" in active_relics and ed_card_count > 0:
				var p_x := pow(1.25, float(ed_card_count))
				x_mult_product *= p_x
				steps.append(_make_step("relic", "×%.2f Seal" % p_x, "Guild Astral Seal (%d Cls)" % ed_card_count, 0, 0.0, p_x, chips, flat_mult, x_mult_product, Color(0.95, 0.52, 0.94), "REL_PRISM_ORB", true))

			if "REL_PHOENIX_F" in active_relics and current_hand.size() <= 2:
				x_mult_product *= 1.6
				steps.append(_make_step("relic", "×1.60 Clutch!", "Phoenix Feather", 0, 0.0, 1.6, chips, flat_mult, x_mult_product, Color(1.0, 0.44, 0.22), "REL_PHOENIX_F", true))

			if "REL_FINAL_TOLL" in active_relics:
				if current_hand.is_empty():
					x_mult_product *= 2.5
					lightning = true
					steps.append(_make_step("relic", "×2.50 Executioner!", "Executioner's Oath (0 left)", 0, 0.0, 2.5, chips, flat_mult, x_mult_product, Color(1.0, 0.24, 0.28), "REL_FINAL_TOLL", true))
				elif current_hand.size() == 1:
					x_mult_product *= 1.5
					steps.append(_make_step("relic", "×1.50 Oath", "Executioner's Oath (1 left)", 0, 0.0, 1.5, chips, flat_mult, x_mult_product, Color(1.0, 0.46, 0.34), "REL_FINAL_TOLL"))

			if "REL_COURT_SOVEREIGN" in active_relics:
				var courts_held := 0
				for hc in current_hand:
					if str(hc.get("rank", "")) in COURT_RANKS:
						courts_held += 1
				if courts_held > 0:
					var cs_x := pow(1.4, float(courts_held))
					x_mult_product *= cs_x
					lightning = lightning or (courts_held >= 2)
					steps.append(_make_step("relic", "×%.2f Treasury (%d)" % [cs_x, courts_held], "Sovereign Treasury", 0, 0.0, cs_x, chips, flat_mult, x_mult_product, Color(1.0, 0.86, 0.28), "REL_COURT_SOVEREIGN", courts_held >= 2))

			if trig_i == 0 and jester_triggers > 1:
				steps.append(_make_step("power", "🎭 JESTER: RELICS 2×!", "Retriggering Relics!", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.96, 0.34, 0.82), "", true))

	# 5. Hand-Shedding Finisher Cash-Out (0 Cards Remaining!)
	var did_shed := false
	var shed_rem_turns := 0
	var shed_x_mult := 1.0
	var allow_shed := not (tutorial_mode and tutorial_step < 6)
	if allow_shed and current_hand.is_empty():
		did_shed = true
		shed_rem_turns = maxi(0, SHED_PAR_TURNS - match_turn_count)
		shed_x_mult = round(SHED_BASE_XMULT * pow(SHED_EXP_PER_TURN, float(shed_rem_turns)) * 100.0) / 100.0
		chips += SHED_BASE_CHIPS
		x_mult_product *= shed_x_mult
		lightning = true
		steps.append(_make_step(
			"finisher",
			"★ SHEDDING FINISHER +%d & ×%.2f!" % [SHED_BASE_CHIPS, shed_x_mult],
			"%d turns saved vs Par %d" % [shed_rem_turns, SHED_PAR_TURNS],
			SHED_BASE_CHIPS, 0.0, shed_x_mult,
			chips, flat_mult, x_mult_product,
			Color(0.42, 1.0, 0.64), "", true
		))

	var d_chalice := float(context.get("duel_chalice_mult", 0.0))
	if not tutorial_mode and d_chalice > 0.01:
		flat_mult += d_chalice
		steps.append(_make_step("relic", "+%.1f× Plague Chalice" % d_chalice, "Peddler Curse Upgrade", 0, d_chalice, 1.0, chips, flat_mult, x_mult_product, Color(0.92, 0.26, 0.30)))

	var d_whet := int(context.get("duel_whetstone_stacks", 0))
	if not tutorial_mode and d_whet > 0:
		var has_sharp := false
		for pc in played_cards:
			if str(pc.get("power_id", "")) != "" or str(pc.get("rank", "")) in COURT_RANKS:
				has_sharp = true
				break
		if has_sharp:
			var w_xm := 1.0 + 0.35 * float(d_whet)
			x_mult_product *= w_xm
			steps.append(_make_step("relic", "×%.2f Whetstone" % w_xm, "Gallows-Iron Edge", 0, 0.0, w_xm, chips, flat_mult, x_mult_product, Color(1.0, 0.40, 0.28), "", true))

	var d_next_x := float(context.get("duel_next_xmult", 1.0))
	if not tutorial_mode and d_next_x > 1.01:
		x_mult_product *= d_next_x
		lightning = true
		steps.append(_make_step("power", "×%.2f Witch-Glass!" % d_next_x, "Belladonna Charge", 0, 0.0, d_next_x, chips, flat_mult, x_mult_product, Color(0.94, 0.48, 0.92), "", true))

	var final_score := int(round(float(chips) * flat_mult * x_mult_product))

	# 6. Boss Modifiers (Traveler mode softens penalties & rewards counterplay!)
	var difficulty := str(context.get("campaign_difficulty", "traveler"))
	if not tutorial_mode and boss_mod != "":
		var lead_is_pwr := str(played_cards[0].get("power_id", "")) != ""
		var is_combo := (cnt >= 2)
		var lead_rank := str(played_cards[0].get("rank", ""))
		if difficulty == "classic":
			if boss_mod == "PHARAOH_SEAL" and not is_combo and not lead_is_pwr and final_score < 20:
				final_score = maxi(1, final_score - 5)
				steps.append(_make_step("boss", "-5 Pharaoh Seal", "Solo < 20 pts drained", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(1.0, 0.45, 0.35)))
			elif boss_mod == "IRON_JOUST" and not is_combo and not lead_is_pwr and lead_rank != "7":
				final_score = maxi(1, final_score - 3)
				steps.append(_make_step("boss", "-3 Iron Armor", "Play Combos or Sevens", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.85, 0.45, 0.45)))
			elif boss_mod == "CAESAR_TRIBUTE" and not is_combo:
				rival_bonus += 12
				steps.append(_make_step("boss", "☠ +12 Caesar Tribute", "Solo play feeds Rival", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(1.0, 0.42, 0.36)))
			elif boss_mod == "SYNDICATE_CUT" and not is_combo:
				final_score = maxi(1, int(round(float(final_score) * 0.85)))
				steps.append(_make_step("boss", "-15% Syndicate Tax", "2×+ Combos evade tax", 0, 0.0, 0.85, chips, flat_mult, x_mult_product, Color(0.95, 0.42, 0.48)))
		else:
			if boss_mod == "PHARAOH_SEAL":
				if is_combo or lead_is_pwr:
					final_score += 15
					steps.append(_make_step("boss", "+15 Seal Broken!", "Combo/Power overpowers Pharaoh", 15, 0.0, 1.0, chips + 15, flat_mult, x_mult_product, Color(1.0, 0.86, 0.32)))
				elif final_score < 20:
					final_score = maxi(1, final_score - 2)
					steps.append(_make_step("boss", "-2 Pharaoh Seal", "Mild solo ward", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(1.0, 0.52, 0.40)))
			elif boss_mod == "IRON_JOUST":
				if is_combo or lead_is_pwr or lead_rank == "7":
					final_score += 20
					steps.append(_make_step("boss", "+20 Armor Shatter!", "Strong strike pierces Joust Plate", 20, 0.0, 1.0, chips + 20, flat_mult, x_mult_product, Color(0.55, 0.94, 1.0)))
				else:
					final_score = maxi(1, final_score - 1)
					steps.append(_make_step("boss", "-1 Iron Armor", "Mild plate deflect", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(0.85, 0.52, 0.50)))
			elif boss_mod == "CAESAR_TRIBUTE":
				if is_combo:
					final_score += 25
					steps.append(_make_step("boss", "+25 Counter-Tribute!", "Combo rallies against Caesar", 25, 0.0, 1.0, chips + 25, flat_mult, x_mult_product, Color(1.0, 0.86, 0.32)))
				else:
					rival_bonus += 4
					steps.append(_make_step("boss", "☠ +4 Caesar Tribute", "Mild solo tax", 0, 0.0, 1.0, chips, flat_mult, x_mult_product, Color(1.0, 0.48, 0.40)))
			elif boss_mod == "SYNDICATE_CUT":
				if is_combo:
					final_score += 30
					bonus_gold += 8
					steps.append(_make_step("boss", "+30 & +8g Tax Rebate!", "Combo busts the Syndicate", 30, 0.0, 1.0, chips + 30, flat_mult, x_mult_product, Color(0.46, 0.96, 0.64)))
				else:
					final_score = maxi(1, int(round(float(final_score) * 0.95)))
					steps.append(_make_step("boss", "-5% Syndicate Fee", "2×+ Combos earn rebate", 0, 0.0, 0.95, chips, flat_mult, x_mult_product, Color(0.95, 0.50, 0.52)))

	return {
		"base_chips": base_chips,
		"card_chips": card_chips_sum,
		"total_chips": chips,
		"flat_mult": flat_mult,
		"x_mult_product": x_mult_product,
		"effective_mult": flat_mult * x_mult_product,
		"final_score": final_score,
		"slam_name": slam_name,
		"shed_finisher": did_shed,
		"shed_rem_turns": shed_rem_turns,
		"shed_x_mult": shed_x_mult,
		"rival_drain": rival_drain,
		"rival_bonus": rival_bonus,
		"bonus_gold": bonus_gold,
		"extra_draw": extra_draw,
		"extra_skip": extra_skip,
		"lightning": lightning,
		"surge_kept": surge_kept,
		"new_surge_mult": new_surge_mult,
		"jester_triggers": jester_triggers,
		"seven_grimoire_delta": seven_grimoire_delta,
		"seven_grimoire_new": seven_grimoire_cur,
		"seven_draw_bonus": 14 * sevens_played,
		"ace_stun_bonus": 25 * aces_played,
		"ace_hp_damage": ace_hp_damage,
		"mage_charge_boost": mage_charge_boost,
		"mage_draws": mage_draws,
		"shields_gained": shields_gained,
		"redraws_gained": redraws_gained,
		"knight_mist_triggered": knight_mist_triggered,
		"thief_heist_triggered": thief_heist_triggered,
		"king_curse_suit": king_curse_suit,
		"formula_summary": ("%d b. × %.1f× × %.2f = %d" if cs else "%d Chips × %.1f Mult × %.2f X-Mult = %d") % [chips, flat_mult, x_mult_product, final_score],
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
				res["x_mult"] = 1.4
				res["label"] = "🦇 Upír: +15 a ×1.4!" if cs else "🦇 Vampire: +15 & ×1.4!"
			else:
				res["label"] = "🦇 Upír: -15 Soupeř / +15" if cs else "🦇 Vampire: -15 Rival / +15"
		"SPEC_STORM":
			res["extra_draw"] = 3
			res["lightning"] = true
			res["surge_kept"] = true
			res["new_surge_mult"] = 0.8
			res["label"] = "⚡ Blesk: +3 lízání a +0.8×!" if cs else "⚡ Thunder: +3 Draw & +0.8× Surge!"
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
					res["label"] = ("🪞 Zrcadlo: +%d (%s)" if cs else "🪞 Mirror Echo: +%d (%s)") % [res["chips"], str(dc.get("rname", "Card"))]
				else:
					res["chips"] = 18
					res["label"] = "🪞 Zrcadlo: +18 bodů" if cs else "🪞 Mirror: +18 Chips"
		"SPEC_ALCHEMIST":
			res["lightning"] = true
			res["label"] = "⚗ Alchymista: +1 Baňka!" if cs else "⚗ Alchemist: +1 Phial & Promote!"
		"SPEC_ORACLE":
			res["extra_draw"] = 0
			res["label"] = "👁 Věštec: Odhalení & +1!" if cs else "👁 Seer's Eye: Reveal & +1 Card!"
		"SPEC_PHOENIX":
			res["chips"] = 30
			res["lightning"] = true
			res["label"] = "🔥 Fénix: +30 a Čistka" if cs else "🔥 Ash Phoenix: +30 Burn & Clear"
		"SPEC_MIDAS":
			res["bonus_gold"] = 14
			res["chips"] = 24
			res["label"] = "🪙 Midas: +24 b. & +14g!" if cs else "🪙 Midas Touch: +24 Chips & 2× ♦/Courts"
		"SPEC_CHRONOS":
			res["lightning"] = true
			res["label"] = "⏳ Chronos: Tah navíc!" if cs else "⏳ Chronos Glass: Extra Turn!"
		"SPEC_JESTER":
			res["jester_double"] = true
			res["lightning"] = true
			res["label"] = "🎭 Šašek: Relikvie 2×!" if cs else "🎭 Tavern Jester: Relics 2×!"
		"SPEC_HEX":
			res["rival_drain"] = 18
			res["chips"] = 15
			res["label"] = "☠ Stínový hex: -18 / +15" if cs else "☠ Shadow Hex: -18 Rival / +15"
		"SPEC_MAGNET":
			res["label"] = "🧲 Magnet: Přitáhni pár!" if cs else "🧲 Rune Magnet: Pull Match Duo!"
		"SPEC_SHIELD":
			res["label"] = "🛡 Železná bašta: +2 Štíty!" if cs else "🛡 Iron Bastion: +2 Shields!"
		"SPEC_GAMBLER":
			var d_mult := 2.0
			var roll_override := float(context.get("gambler_roll", 0.0))
			if roll_override > 0.0:
				d_mult = roll_override
			elif not is_preview:
				var rv := randf()
				d_mult = 3.5 if rv < 0.22 else (2.0 if rv < 0.65 else 1.5)
			res["x_mult"] = d_mult
			if d_mult >= 2.0:
				res["lightning"] = true
			res["label"] = ("🎲 Kostky: ×%.1f!" if cs else "🎲 Loaded Dice: ×%.1f!") % d_mult
		"SPEC_PLAGUE":
			res["rival_drain"] = 14
			res["label"] = "❄ Mráz: Omráčení & -14" if cs else "❄ Frost Blight: Stun & -14"
		"SPEC_CROWN":
			var courts := 0
			for hc in current_hand:
				if str(hc.get("rank", "")) in COURT_RANKS:
					courts += 1
			var bonus_c := courts * 20
			res["chips"] = bonus_c
			res["label"] = ("👑 Královský dekret: +%d (%d figur)" if cs else "👑 Royal Decree: +%d (%d Courts)") % [bonus_c, courts]
		"SPEC_PRISM":
			var add_m := 0.6 * float(cnt)
			res["flat_mult"] = add_m
			res["lightning"] = true
			res["label"] = ("💎 Prizma: +%.1f× & +4 b.!" if cs else "💎 Prism Core: +%.1f× & +4 Pts!") % add_m
	return res
