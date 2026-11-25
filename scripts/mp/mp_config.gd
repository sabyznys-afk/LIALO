class_name MpConfig
extends RefCounted

const Catalog = preload("res://scripts/lialo_catalog.gd")

## EXPERIMENTAL / DEV-ONLY MULTIPLAYER FEATURE GATE
## Flip ENABLE_TEST_MULTIPLAYER = false before shipping any public launch build
## to completely remove the test entry from menus. When REQUIRE_NON_RELEASE_BUILD is true,
## exported Release templates automatically hide it even if ENABLE_TEST_MULTIPLAYER is true.
const ENABLE_TEST_MULTIPLAYER := true
const REQUIRE_NON_RELEASE_BUILD := false
const MP_PROTOCOL_VERSION := "0.9.1-mp2"

const VISTA_ERAS := [
	{"id": "stredovek", "name": "Full Moon Tavern", "name_cs": "Krčma za úplňku", "icon": "tavern"},
	{"id": "antika", "name": "Alpine Sun Vista", "name_cs": "Slunečné Alpy", "icon": "star"},
	{"id": "rim", "name": "Starry Night", "name_cs": "Hvězdná noc", "icon": "dice"},
	{"id": "prohibicia", "name": "Storm & Lightning", "name_cs": "Bouřka a blesky", "icon": "bolt"},
]

const MIN_PLAYERS := 2
const MAX_PLAYERS := 4
const DEFAULT_PORT := 24780

const START_HP := 120
const START_SHIELDS := 15
const START_GOLD := 25
const START_HAND_SIZE := 6
const TURN_TIMEOUT_SEC := 35.0
const TURN_TIMEOUT_MIN := 30.0
const TURN_TIMEOUT_MAX := 45.0
const PARRY_WINDOW_SEC := 2.6

const MP_MAX_POWER_CARDS := 3
const MP_MAX_MYTHIC_POWER_CARDS := 1
const MP_MAX_TABLE_RELICS := 2
const MP_MAX_PASSIVE_RELICS := 2
const MP_PASSIVE_MULT_CAP := 2.5
const RULE_CAMPAIGN_VAULT := "CAMPAIGN_VAULT"
const RULE_BALANCED_ARENA := "BALANCED_ARENA"
const MODE_PUBLIC := "PUBLIC"
const MODE_PRIVATE := "PRIVATE"
const MODE_RANKED := "RANKED"
const MODE_UNRANKED := "UNRANKED"

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

const CHARACTERS := [
	{
		"id": "CHAR_GUILLOTINE",
		"name": "Executioner",
		"name_cs": "Kat",
		"icon": "sword",
		"desc": "Hooded iron duelist with cyan visor & heavy steel pauldrons.",
		"glb": "res://assets/models/mp/mp_char_guillotine.glb",
		"default_arch": "GUILLOTINE_ACES",
		"col": Color(0.32, 0.88, 1.0),
	},
	{
		"id": "CHAR_MONARCH",
		"name": "Parry Monarch",
		"name_cs": "Panovník",
		"icon": "crown",
		"desc": "Crowned gilded noble wearing a Venetian porcelain half-mask.",
		"glb": "res://assets/models/mp/mp_char_monarch.glb",
		"default_arch": "MIRROR_MONARCH",
		"col": Color(1.0, 0.78, 0.28),
	},
	{
		"id": "CHAR_JESTER",
		"name": "Chaos Jester",
		"name_cs": "Šašek chaosu",
		"icon": "cards",
		"desc": "Horned harlequin trickster with brass bells & grinning mask.",
		"glb": "res://assets/models/mp/mp_char_jester.glb",
		"default_arch": "CHAOS_JESTER",
		"col": Color(0.95, 0.42, 0.78),
	},
	{
		"id": "CHAR_MISTBLADE",
		"name": "Mistblade Shadow",
		"name_cs": "Rytíř mlhy",
		"icon": "mist",
		"desc": "High-collared dark shadow-forged war-cloak & cracked silver visor.",
		"glb": "res://assets/models/mp/mp_char_mistblade.glb",
		"default_arch": "MISTBLADE_DUELIST",
		"col": Color(0.45, 0.94, 0.80),
	},
]

const DECK_ARCHETYPES := [
	{
		"id": "GUILLOTINE_ACES",
		"name": "4-Ace Guillotine",
		"icon": "sword",
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
		"name": "Parry Monarch",
		"icon": "shield",
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
		"name": "Tavern Chaos",
		"icon": "cards",
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
		"name": "Mistblade Shadow",
		"icon": "mist",
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


static func get_character(char_id: String) -> Dictionary:
	for c in CHARACTERS:
		if str(c.get("id", "")) == char_id:
			return c
	return CHARACTERS[0]


static func get_character_for_archetype(arch_id: String) -> Dictionary:
	for c in CHARACTERS:
		if str(c.get("default_arch", "")) == arch_id:
			return c
	return CHARACTERS[0]


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


static func get_mp_item_info(item_id: String, lang: String = "en") -> Dictionary:
	if MP_ITEMS.has(item_id):
		return MP_ITEMS[item_id]
	var trel: Dictionary = Catalog.get_table_relic_loc(item_id, lang)
	if not trel.is_empty():
		var needs_tgt := item_id in ["TRELIC_SOUL_BELL", "TRELIC_STAR_BOW", "TRELIC_IRON_CHAIN"]
		return {
			"id": item_id,
			"name": str(trel.get("name", item_id)),
			"short": str(trel.get("short", "USE")),
			"desc": str(trel.get("desc", "")),
			"needs_target": needs_tgt,
			"col": trel.get("col", Color(0.96, 0.78, 0.34)),
			"is_table_relic": true,
		}
	return {}


static func make_mp_item_instance(item_id: String, seq: int = 0) -> Dictionary:
	return {
		"uid": "%s#%d" % [item_id, seq],
		"id": item_id,
		"uses": 0,
	}


static func get_item_id(entry: Variant) -> String:
	if entry is Dictionary:
		return str((entry as Dictionary).get("id", ""))
	return str(entry)


static func get_item_uid(entry: Variant, fallback_idx: int = 0) -> String:
	if entry is Dictionary:
		var d := entry as Dictionary
		var u := str(d.get("uid", ""))
		if u != "":
			return u
		return "%s#%d" % [str(d.get("id", "")), fallback_idx]
	return "%s#%d" % [str(entry), fallback_idx]


static func sanitize_deck_cfg(deck_cfg: Dictionary, rule_mode: String = RULE_CAMPAIGN_VAULT) -> Dictionary:
	var arch := get_archetype(str(deck_cfg.get("archetype_id", "GUILLOTINE_ACES")))
	var arch_id := str(arch.get("id", "GUILLOTINE_ACES"))
	var char_id := str(get_character(str(deck_cfg.get("character_id", get_character_for_archetype(arch_id).get("id", "CHAR_GUILLOTINE")))).get("id", "CHAR_GUILLOTINE"))
	var extra_aces := clampi(int(deck_cfg.get("extra_aces", arch.get("extra_aces", 2))), 0, 6)

	if rule_mode == RULE_BALANCED_ARENA:
		var bal_powers: Array = []
		for pid in arch.get("powers", []):
			if bal_powers.size() < MP_MAX_POWER_CARDS:
				bal_powers.append(str(pid))
		var bal_items: Array = []
		for iid in arch.get("items", []):
			if bal_items.size() < MP_MAX_TABLE_RELICS:
				bal_items.append(str(iid))
		var bal_build := Catalog.get_deck_build(arch_id)
		return {
			"archetype_id": arch_id,
			"character_id": char_id,
			"extra_aces": clampi(int(arch.get("extra_aces", 2)), 0, 6),
			"power_cards": bal_powers,
			"table_relics": bal_items,
			"passive_relics": [],
			"bankai_combo": (bal_build.get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]) as Array).duplicate(),
			"sword_skin": str(arch.get("sword_skin", "SWORD_IRON")),
			"rule_mode": RULE_BALANCED_ARENA,
		}

	var clean_powers: Array = []
	var mythic_cnt := 0
	var raw_p = deck_cfg.get("power_cards", [])
	if raw_p is Array:
		for pv in raw_p:
			var pid := str(pv)
			if pid in Catalog.ARCHIVED_CARD_IDS:
				continue
			var pdata := Catalog.get_power_card(pid)
			if pdata.is_empty():
				continue
			if str(pdata.get("rarity", "")) == "Mythic":
				if mythic_cnt >= MP_MAX_MYTHIC_POWER_CARDS:
					continue
				mythic_cnt += 1
			clean_powers.append(pid)
			if clean_powers.size() >= MP_MAX_POWER_CARDS:
				break
	if clean_powers.is_empty() and not deck_cfg.has("power_cards"):
		for pid in arch.get("powers", []):
			if clean_powers.size() < MP_MAX_POWER_CARDS:
				clean_powers.append(str(pid))

	var clean_trels: Array = []
	var raw_t = deck_cfg.get("table_relics", [])
	if raw_t is Array:
		for tv in raw_t:
			var tid := str(tv)
			if tid == "" or get_mp_item_info(tid).is_empty():
				continue
			if not (tid in clean_trels):
				clean_trels.append(tid)
			if clean_trels.size() >= MP_MAX_TABLE_RELICS:
				break
	if clean_trels.is_empty() and not deck_cfg.has("table_relics"):
		for iid in arch.get("items", []):
			if clean_trels.size() < MP_MAX_TABLE_RELICS:
				clean_trels.append(str(iid))

	var clean_prels: Array = []
	var raw_r = deck_cfg.get("passive_relics", [])
	if raw_r is Array:
		for rv in raw_r:
			var rid := Catalog.migrate_relic_id(str(rv))
			if (rid in Catalog.ARCHIVED_RELIC_IDS) or Catalog.is_relic_hidden(rid) or Catalog.get_relic(rid).is_empty():
				continue
			if not (rid in clean_prels):
				clean_prels.append(rid)
			if clean_prels.size() >= MP_MAX_PASSIVE_RELICS:
				break

	var b_def := Catalog.get_deck_build(arch_id)
	var clean_bankai: Array = []
	var raw_b = deck_cfg.get("bankai_combo", b_def.get("default_bankai", []))
	if raw_b is Array:
		for bv in raw_b:
			var bs := str(bv).strip_edges()
			if bs != "" and not (bs in clean_bankai) and clean_bankai.size() < 4:
				clean_bankai.append(bs)
	if clean_bankai.size() < 4:
		for fb in b_def.get("default_bankai", ["CERVEN_E", "ZALUD_E", "ZELEN_E", "GULA_E"]):
			var fbs := str(fb)
			if not (fbs in clean_bankai) and clean_bankai.size() < 4:
				clean_bankai.append(fbs)

	var sw_id := str(deck_cfg.get("sword_skin", arch.get("sword_skin", "SWORD_IRON")))
	if Catalog.get_sword_skin(sw_id).get("id", "") != sw_id:
		sw_id = "SWORD_IRON"

	return {
		"archetype_id": arch_id,
		"character_id": char_id,
		"extra_aces": extra_aces,
		"power_cards": clean_powers,
		"table_relics": clean_trels,
		"passive_relics": clean_prels,
		"bankai_combo": clean_bankai,
		"sword_skin": sw_id,
		"rule_mode": RULE_CAMPAIGN_VAULT,
	}


static func build_custom_deck(deck_cfg: Dictionary) -> Array:
	var clean_cfg := sanitize_deck_cfg(deck_cfg, str(deck_cfg.get("rule_mode", RULE_CAMPAIGN_VAULT)))
	var arch := get_archetype(str(clean_cfg.get("archetype_id", "GUILLOTINE_ACES")))
	var deck: Array = []
	for s in SUITS:
		for r in RANKS:
			deck.append(make_card(str(s["id"]), str(r["id"]), "NORMAL"))

	# Extra Aces requested by deck archetype + player slider override
	var extra_aces := clampi(int(clean_cfg.get("extra_aces", arch.get("extra_aces", 2))), 0, 6)
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

	# Signature OP Power Cards (custom Vault selection or archetype fallback)
	var p_list: Array = clean_cfg.get("power_cards", arch.get("powers", []))
	for pid in p_list:
		deck.append(make_power_card(str(pid)))

	return deck
