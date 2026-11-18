class_name MpConfig
extends RefCounted

const Catalog = preload("res://scripts/lialo_catalog.gd")

## EXPERIMENTAL / DEV-ONLY MULTIPLAYER FEATURE GATE
## Flip ENABLE_TEST_MULTIPLAYER = false before shipping any public launch build
## to completely remove the test entry from menus. When REQUIRE_NON_RELEASE_BUILD is true,
## exported Release templates automatically hide it even if ENABLE_TEST_MULTIPLAYER is true.
const ENABLE_TEST_MULTIPLAYER := true
const REQUIRE_NON_RELEASE_BUILD := true

const MIN_PLAYERS := 2
const MAX_PLAYERS := 4
const DEFAULT_PORT := 24780

const START_HP := 120
const START_SHIELDS := 15
const START_GOLD := 25
const START_HAND_SIZE := 6
const TURN_TIMEOUT_SEC := 24.0
const PARRY_WINDOW_SEC := 2.6

const SUITS := [
	{"id": "CERVEN", "name": "Srdce", "sym": "♥", "col": Color(0.90, 0.24, 0.28)},
	{"id": "ZELEN", "name": "Listí", "sym": "♠", "col": Color(0.22, 0.72, 0.52)},
	{"id": "ZALUD", "name": "Žaludy", "sym": "♣", "col": Color(0.86, 0.66, 0.38)},
	{"id": "GULA", "name": "Koule", "sym": "●", "col": Color(0.96, 0.58, 0.24)},
]

const RANKS := [
	{"id": "7", "name": "Sedma", "pts": 7},
	{"id": "8", "name": "Osma", "pts": 8},
	{"id": "9", "name": "Devítka", "pts": 9},
	{"id": "10", "name": "Desítka", "pts": 10},
	{"id": "D", "name": "Dolník", "pts": 12},
	{"id": "H", "name": "Svršek", "pts": 16},
	{"id": "K", "name": "Král", "pts": 18},
	{"id": "E", "name": "Eso", "pts": 20},
]

const DECK_ARCHETYPES := [
	{
		"id": "GUILLOTINE_ACES",
		"name": "⚔ 4-Ace Guillotine",
		"desc": "+4 extra Aces & Mistblade Knights for instant Sword Execution.",
		"extra_aces": 4,
		"knight_slots": 4,
		"mage_slots": 1,
		"thief_slots": 0,
		"powers": ["SPEC_CHRONOS", "SPEC_STORM", "SPEC_MIRROR"],
		"items": ["MYS_RUNE_WHETSTONE", "MYS_IRON_GAUNTLET"],
		"sword_skin": "SWORD_RUNE",
		"col": Color(0.32, 0.88, 1.0),
	},
	{
		"id": "MIRROR_MONARCH",
		"name": "🪞 Parry Monarch",
		"desc": "2× Twin Mirrors, Blood Sevens & Royal Kings to deflect executions.",
		"extra_aces": 2,
		"knight_slots": 2,
		"mage_slots": 2,
		"thief_slots": 0,
		"powers": ["SPEC_MIRROR", "SPEC_MIRROR", "SPEC_VAMPIRE"],
		"items": ["MYS_WITCH_MIRROR", "MYS_ALCHEMIST_PHIAL"],
		"sword_skin": "SWORD_GILDED",
		"col": Color(1.0, 0.78, 0.28),
	},
	{
		"id": "CHAOS_JESTER",
		"name": "🃏 Tavern Chaos",
		"desc": "Card theft, Jester Roulette, Hex Reverse & extra Suit Queens.",
		"extra_aces": 2,
		"knight_slots": 1,
		"mage_slots": 2,
		"thief_slots": 4,
		"powers": ["SPEC_JESTER", "SPEC_HEX", "SPEC_VAMPIRE", "SPEC_MIRROR"],
		"items": ["MYS_CROWBAR_KEY", "MYS_BELL_TOLL"],
		"sword_skin": "SWORD_CRIMSON",
		"col": Color(0.95, 0.42, 0.78),
	},
	{
		"id": "MISTBLADE_DUELIST",
		"name": "🌫 Mistblade Shadow",
		"desc": "6× Mistblade Knights, Raven Glass & lethal Assassin slashes.",
		"extra_aces": 3,
		"knight_slots": 6,
		"mage_slots": 2,
		"thief_slots": 2,
		"powers": ["SPEC_ORACLE", "SPEC_MIRROR", "SPEC_CHRONOS"],
		"items": ["MYS_RAVENS_EYE", "MYS_LANTERN_ASH"],
		"sword_skin": "SWORD_DRAGON",
		"col": Color(0.45, 0.94, 0.80),
	},
]

const MP_ITEMS := {
	"MYS_IRON_GAUNTLET": {"id": "MYS_IRON_GAUNTLET", "name": "Templar Gauntlet", "short": "+25 Shd / -18 HP", "needs_target": true, "col": Color(0.68, 0.80, 0.95)},
	"MYS_WITCH_MIRROR": {"id": "MYS_WITCH_MIRROR", "name": "Witch-Glass", "short": "Auto-Reflect Exec", "needs_target": false, "col": Color(0.72, 0.48, 1.0)},
	"MYS_BELL_TOLL": {"id": "MYS_BELL_TOLL", "name": "Plague Bell", "short": "-22 AoE & Skip", "needs_target": false, "col": Color(0.98, 0.76, 0.26)},
	"MYS_RUNE_WHETSTONE": {"id": "MYS_RUNE_WHETSTONE", "name": "Gallows Whetstone", "short": "+Sword Sharp / 2E!", "needs_target": false, "col": Color(1.0, 0.40, 0.28)},
	"MYS_RAVENS_EYE": {"id": "MYS_RAVENS_EYE", "name": "Raven's Eye", "short": "Reveal Hand +1 Card", "needs_target": true, "col": Color(0.42, 0.90, 1.0)},
	"MYS_ALCHEMIST_PHIAL": {"id": "MYS_ALCHEMIST_PHIAL", "name": "Quicksilver Phial", "short": "Clear 7s & +2 Draw", "needs_target": false, "col": Color(0.98, 0.52, 0.22)},
	"MYS_LANTERN_ASH": {"id": "MYS_LANTERN_ASH", "name": "Vitus Lantern", "short": "Knight +18 Shield", "needs_target": false, "col": Color(0.96, 0.62, 0.28)},
	"MYS_CROWBAR_KEY": {"id": "MYS_CROWBAR_KEY", "name": "Skeleton Key", "short": "Steal Card / Item", "needs_target": true, "col": Color(0.88, 0.72, 0.36)},
}


static func is_test_mp_available() -> bool:
	if not ENABLE_TEST_MULTIPLAYER:
		return false
	if not REQUIRE_NON_RELEASE_BUILD:
		return true
	return OS.is_debug_build() or OS.has_feature("editor") or ("--mp-test" in OS.get_cmdline_args())


static func get_archetype(arch_id: String) -> Dictionary:
	for a in DECK_ARCHETYPES:
		if str(a.get("id", "")) == arch_id:
			return a
	return DECK_ARCHETYPES[0]


static func get_suit(s_id: String) -> Dictionary:
	for s in SUITS:
		if str(s["id"]) == s_id:
			return s
	return SUITS[0]


static func get_rank(r_id: String) -> Dictionary:
	for r in RANKS:
		if str(r["id"]) == r_id:
			return r
	return RANKS[1]


static func make_card(s_id: String, r_id: String, edition: String = "NORMAL") -> Dictionary:
	var r := get_rank(r_id)
	return {
		"id": "%s_%s" % [s_id, r_id],
		"suit": s_id,
		"rank": r_id,
		"pts": int(r["pts"]),
		"rname": str(r["name"]),
		"edition": edition,
		"power_id": "",
		"wild": false,
		"mage_charge": 1 if edition == "MAGE" else 0,
	}


static func make_power_card(power_id: String) -> Dictionary:
	var p: Dictionary = Catalog.get_power_card(power_id)
	if p.is_empty():
		return make_card("CERVEN", "E", "KNIGHT")
	return {
		"id": power_id,
		"suit": str(p.get("suit", "CERVEN")),
		"rank": "PWR",
		"pts": int(p.get("pts", 18)),
		"rname": str(p.get("short", p.get("name", "POWER"))),
		"edition": "NORMAL",
		"power_id": power_id,
		"wild": bool(p.get("wild", true)),
		"accent": p.get("accent", Color(1.0, 0.84, 0.32)),
		"mage_charge": 0,
	}


static func build_custom_deck(deck_cfg: Dictionary) -> Array:
	var arch := get_archetype(str(deck_cfg.get("archetype_id", "GUILLOTINE_ACES")))
	var deck: Array = []
	for s in SUITS:
		for r in RANKS:
			deck.append(make_card(str(s["id"]), str(r["id"]), "NORMAL"))

	# Extra Aces requested by deck archetype + player slider override
	var extra_aces := clampi(int(deck_cfg.get("extra_aces", arch.get("extra_aces", 2))), 0, 6)
	for i in range(extra_aces):
		var s_id := str(SUITS[i % 4]["id"])
		deck.append(make_card(s_id, "E", "KNIGHT" if i % 2 == 0 else "NORMAL"))

	# Bonus Queens for chaos deck
	if str(arch["id"]) == "CHAOS_JESTER":
		deck.append(make_card("CERVEN", "H", "NORMAL"))
		deck.append(make_card("ZELEN", "H", "NORMAL"))
		deck.append(make_card("ZALUD", "7", "THIEF"))
		deck.append(make_card("GULA", "7", "THIEF"))
	elif str(arch["id"]) == "MIRROR_MONARCH":
		deck.append(make_card("CERVEN", "7", "NORMAL"))
		deck.append(make_card("ZALUD", "7", "NORMAL"))
		deck.append(make_card("CERVEN", "K", "KNIGHT"))

	# Assign Class infusions (KNIGHT, MAGE, THIEF, MERCHANT) across deck cards deterministically
	var knight_n := int(arch.get("knight_slots", 2))
	var mage_n := int(arch.get("mage_slots", 1))
	var thief_n := int(arch.get("thief_slots", 1))
	var candidates: Array = []
	for idx in range(deck.size()):
		if str(deck[idx].get("edition", "NORMAL")) == "NORMAL":
			candidates.append(idx)
	candidates.shuffle()

	for c_i in candidates:
		if knight_n > 0:
			deck[c_i]["edition"] = "KNIGHT"
			knight_n -= 1
		elif mage_n > 0:
			deck[c_i]["edition"] = "MAGE"
			deck[c_i]["mage_charge"] = 2
			mage_n -= 1
		elif thief_n > 0:
			deck[c_i]["edition"] = "THIEF"
			thief_n -= 1
		else:
			break

	# Signature OP Power Cards
	var p_list: Array = arch.get("powers", [])
	for pid in p_list:
		deck.append(make_power_card(str(pid)))

	return deck
