extends RefCounted
class_name LialoCatalog
## LIALO Master Roguelite Deckbuilder Registry & Progression Save Engine
## Obsahuje:
## - 15 originálnych Špeciálnych Power Kariet (automaticky načítava `res://assets/cards/SPEC_<ID>.png`, ak existuje)
## - 5 Edícií kariet (Standard, Foil +50 Chips, Holographic +10 Mult, Polychrome ×1.5 X-Mult, Storm Charged)
## - 23 zberateľských Relikvií (13 pôvodných + 10 nových Scaling/X-Mult/Prší Relikvií)
## - 6 Alchymistických Elixírov na Deck Sculpting (Remove, Duplicate, Suit Transmute, Foil/Holo/Poly Infusion)
## - 5 historických ér × 3 eskalované štádiá (Ascension 1–10 + Endless Mode Epoch 6+)

const PROFILE_PATH := "user://lialo_profile.cfg"
const OPTIONS_PATH := "user://lialo_options.cfg"
const MAX_ASCENSION := 10

const ARCHIVED_CARD_IDS: Array[String] = ["SPEC_PRISM"]
const ARCHIVED_RELIC_IDS: Array[String] = ["REL_PRISM_ORB"]
const TEMPORARILY_HIDDEN_RELICS: Array[String] = ["REL_CHAMOIS", "REL_STORMCAP"]

const DEFAULT_UNLOCKED_CARDS := [
	"CERVEN_7", "CERVEN_8", "CERVEN_9", "CERVEN_10", "CERVEN_D", "CERVEN_E",
	"ZELEN_7", "ZELEN_8", "ZELEN_9", "ZELEN_10", "ZELEN_H",
	"ZALUD_7", "ZALUD_8", "ZALUD_9", "ZALUD_D", "ZALUD_H",
	"GULA_7", "GULA_8", "GULA_9", "GULA_10", "GULA_E",
	"SPEC_VAMPIRE", "SPEC_STORM", "SPEC_PHOENIX", "SPEC_MIDAS"
]

const ERA_BASE_TARGETS := {
	"antika": 60,
	"rim": 75,
	"stredovek": 90,
	"objavy": 110,
	"prohibicia": 130,
}

const CLASSIC_BASE_TARGETS := {
	"antika": 80,
	"rim": 100,
	"stredovek": 120,
	"objavy": 145,
	"prohibicia": 175,
}

const CLASSIC_STAGE_MULTS := {
	"antika": [0.80, 1.00, 1.25],
	"rim": [0.85, 1.05, 1.30],
	"stredovek": [0.85, 1.05, 1.32],
	"objavy": [0.88, 1.08, 1.36],
	"prohibicia": [0.90, 1.12, 1.45],
}

const CARD_CLASSES := {
	"NORMAL": {
		"id": "NORMAL", "name": "Ironborne", "name_cs": "Obyčejná", "short_cls": "Normal", "short_cls_cs": "Klasika", "badge": "", "badge_cs": "", "shader_id": 0,
		"gold_bonus": 2, "max_charge": 0,
		"col": Color(0.76, 0.72, 0.64), "cost": 0,
		"desc": "Classic tavern card. Steady points and +2 Florins.",
		"desc_cs": "Klasická krčmová karta. Dává základní body a +2 Zlaté."
	},
	"MAGE": {
		"id": "MAGE", "name": "Runecaster", "name_cs": "Mág", "short_cls": "Mage", "short_cls_cs": "Mág", "badge": "MAGE", "badge_cs": "MÁG", "shader_id": 1,
		"gold_bonus": 2, "max_charge": 2,
		"col": Color(0.64, 0.44, 1.0), "cost": 26,
		"desc": "Charges in hand (+1/round to 2/2). At 2/2: +20 pts, ×2.0 Mult, -12 Rival & +1 Card! (+5 pts uncharged).",
		"desc_cs": "Nabíjí se v ruce (+1/kolo do 2/2). Plná (2/2): +20 b., ×2.0, -12 soupeři a +1 karta! (+5 b. nenabitá)."
	},
	"KNIGHT": {
		"id": "KNIGHT", "name": "Mistblade", "name_cs": "Rytíř", "short_cls": "Knight", "short_cls_cs": "Rytíř", "badge": "KNIGHT", "badge_cs": "RYTÍŘ", "shader_id": 2,
		"gold_bonus": 4, "max_charge": 0,
		"col": Color(0.60, 0.88, 0.98), "cost": 24,
		"desc": "Fast strike (+10 pts, ×1.5) hidden in Mist! Wrong guess forces Rival +1 Draw.",
		"desc_cs": "Rychlý úder (+10 b., ×1.5) v mlze! Chybný tip donutí soupeře líznout +1 kartu."
	},
	"MERCHANT": {
		"id": "MERCHANT", "name": "Guildsman", "name_cs": "Kupec", "short_cls": "Merchant", "short_cls_cs": "Kupec", "badge": "GUILD", "badge_cs": "KUPEC", "shader_id": 3,
		"gold_bonus": 15, "max_charge": 0,
		"col": Color(1.0, 0.82, 0.24), "cost": 22,
		"desc": "Skips card power, but grants +5 pts & +15 Florins on play! Easy target for Thieves.",
		"desc_cs": "Nemá bojovou schopnost, ale dá +5 b. a +15 Zlatých! Snadný cíl pro Zloděje."
	},
	"THIEF": {
		"id": "THIEF", "name": "Cutpurse", "name_cs": "Zloděj", "short_cls": "Thief", "short_cls_cs": "Zloděj", "badge": "THIEF", "badge_cs": "ZLODĚJ", "shader_id": 4,
		"gold_bonus": 4, "max_charge": 0,
		"col": Color(0.28, 0.90, 0.56), "cost": 28,
		"desc": "Shadow Cut (+10 pts). Guess 2+ matching non-Mages in Rival's hand: steal 1 card & Rival draws +2!",
		"desc_cs": "Stínový řez (+10 b.). Tipni 2+ karty v ruce soupeře: ukradneš 1 kartu a soupeř lízne +2!"
	},
}

const EDITIONS := CARD_CLASSES

## 15 ORIGINÁLNYCH POWER KARIET
## Poznámka pre výtvarníka (vlastné assety): stačí uložiť PNG do `res://assets/cards/` s presným názvom
## v poli `art_file` (napr. `SPEC_VAMPIRE.png`, `SPEC_STORM.png`, ...). Hra ho automaticky načíta!
const POWER_CARDS := [
	{
		"id": "SPEC_VAMPIRE", "name": "Vampire Leech", "name_cs": "Upíří pijavice", "short": "LEECH", "short_cs": "UPÍR", "suit": "CERVEN",
		"pts": 22, "cost": 16, "rarity": "Uncommon", "rarity_cs": "Neobvyklá", "wild": false,
		"accent": Color(0.92, 0.16, 0.26), "art_file": "SPEC_VAMPIRE.png",
		"power_line": "Drain 15 pts from Rival", "power_line_cs": "Vysaje 15 b. soupeři",
		"desc": "Steals 15 pts from Rival (×1.5 Mult if Hearts active).",
		"desc_cs": "Sebere soupeři 15 bodů (×1.5 násobitel, pokud jedou Srdce)."
	},
	{
		"id": "SPEC_STORM", "name": "Thunder Strike", "name_cs": "Úder blesku", "short": "STORM", "short_cs": "BOUŘE", "suit": "ZELEN",
		"pts": 25, "cost": 18, "rarity": "Rare", "rarity_cs": "Vzácná", "wild": false,
		"accent": Color(0.32, 0.88, 1.0), "art_file": "SPEC_STORM.png",
		"power_line": "+3 Draw & ×1.5 Surge", "power_line_cs": "+3 lízání a ×1.5 výboj",
		"desc": "Rival draws +3 cards & next Combo gains ×1.5 Surge!",
		"desc_cs": "Soupeř líže +3 karty a příští kombo získá ×1.5 výboj!"
	},
	{
		"id": "SPEC_MIRROR", "name": "Twin Mirror", "name_cs": "Zrcadlo ozvěn", "short": "MIRROR", "short_cs": "ZRCADLO", "suit": "CERVEN",
		"pts": 18, "cost": 19, "rarity": "Rare", "rarity_cs": "Vzácná", "wild": true,
		"accent": Color(0.76, 0.84, 1.0), "art_file": "SPEC_MIRROR.png",
		"power_line": "Echo Last Played Card", "power_line_cs": "Zopakuje minulou kartu",
		"desc": "WILD: Copies the last played card and triggers its power again!",
		"desc_cs": "DIVOKÁ: Zopakuje poslední hranou kartu včetně její síly!"
	},
	{
		"id": "SPEC_ALCHEMIST", "name": "Gold Transmuter", "name_cs": "Alchymista", "short": "ALCH", "short_cs": "ALCHYM.", "suit": "ZALUD",
		"pts": 20, "cost": 17, "rarity": "Uncommon", "rarity_cs": "Neobvyklá", "wild": false,
		"accent": Color(1.0, 0.78, 0.24), "art_file": "SPEC_ALCHEMIST.png",
		"power_line": "Upgrade Hand +1 Phial", "power_line_cs": "Povýší kartu +1 Ohněm",
		"desc": "Turns 1 Normal card in hand into Mage/Knight/Thief & adds +1 Fire Phial!",
		"desc_cs": "Promění 1 obyčejnou kartu v ruce na Mága/Rytíře a přidá +1 Baňku!"
	},
	{
		"id": "SPEC_ORACLE", "name": "Seer's Eye", "name_cs": "Oko věštce", "short": "SEER", "short_cs": "VĚŠTEC", "suit": "ZELEN",
		"pts": 18, "cost": 14, "rarity": "Common", "rarity_cs": "Běžná", "wild": false,
		"accent": Color(0.50, 0.96, 0.82), "art_file": "SPEC_ORACLE.png",
		"power_line": "Reveal Rival +1 Card", "power_line_cs": "Odhalí soupeře +1 karta",
		"desc": "Flips Rival's cards face-up for 2 turns & draws +1 card.",
		"desc_cs": "Na 2 kola odkryje soupeřovy karty a lízne +1 kartu."
	},
	{
		"id": "SPEC_PHOENIX", "name": "Ash Phoenix", "name_cs": "Fénix z popela", "short": "PHOENIX", "short_cs": "FÉNIX", "suit": "CERVEN",
		"pts": 28, "cost": 20, "rarity": "Rare", "rarity_cs": "Vzácná", "wild": false,
		"accent": Color(1.0, 0.48, 0.16), "art_file": "SPEC_PHOENIX.png",
		"power_line": "Clear Curse +30 Burn", "power_line_cs": "Zruší útok +30 b.",
		"desc": "Cancels pending Draw curses, adds +30 pts & returns to Deck!",
		"desc_cs": "Spálí hrozbu lízání (+2), přidá +30 b. a vrátí se do balíčku!"
	},
	{
		"id": "SPEC_MIDAS", "name": "Midas Touch", "name_cs": "Midasův dotek", "short": "MIDAS", "short_cs": "MIDAS", "suit": "GULA",
		"pts": 20, "cost": 18, "rarity": "Uncommon", "rarity_cs": "Neobvyklá", "wild": false,
		"accent": Color(1.0, 0.86, 0.22), "art_file": "SPEC_MIDAS.png",
		"power_line": "+20 pts & +15 Gold", "power_line_cs": "+20 b. & +15 Zlatých",
		"desc": "Grants +20 bonus pts & +15 Florins!",
		"desc_cs": "Přidá +20 bonusových bodů a +15 Zlatých!"
	},
	{
		"id": "SPEC_CHRONOS", "name": "Chronos Glass", "name_cs": "Presýpací hodiny", "short": "TIME", "short_cs": "ČAS", "suit": "GULA",
		"pts": 25, "cost": 24, "rarity": "Mythic", "rarity_cs": "Mýtická", "wild": true,
		"accent": Color(0.96, 0.88, 0.44), "art_file": "SPEC_CHRONOS.png",
		"power_line": "Extra Turn Immediately!", "power_line_cs": "Hraješ ihned znovu!",
		"desc": "WILD: Freezes time — you take another turn immediately!",
		"desc_cs": "DIVOKÁ: Zastaví čas — soupeř nehraje a ty jdeš hned znovu!"
	},
	{
		"id": "SPEC_JESTER", "name": "Tavern Jester", "name_cs": "Krčmový šašek", "short": "JESTER", "short_cs": "ŠAŠEK", "suit": "GULA",
		"pts": 20, "cost": 20, "rarity": "Rare", "rarity_cs": "Vzácná", "wild": true,
		"accent": Color(0.96, 0.34, 0.82), "art_file": "SPEC_JESTER.png",
		"power_line": "Trigger Relics Twice!", "power_line_cs": "Relikvie 2× za tah!",
		"desc": "WILD: Fires all your equipped Relics twice in this Slam!",
		"desc_cs": "DIVOKÁ: Spustí všechny tvé Relikvie v tomto tahu dvakrát!"
	},
	{
		"id": "SPEC_HEX", "name": "Shadow Hex", "name_cs": "Kletba stínu", "short": "HEX", "short_cs": "KLETBA", "suit": "ZALUD",
		"pts": 16, "cost": 14, "rarity": "Common", "rarity_cs": "Běžná", "wild": false,
		"accent": Color(0.66, 0.28, 0.94), "art_file": "SPEC_HEX.png",
		"power_line": "Rival -15 pts / +15 pts", "power_line_cs": "Soupeř -15 b. / +15 b.",
		"desc": "Curses Rival for -15 pts & adds +15 bonus points.",
		"desc_cs": "Prokleje soupeře (-15 b.) a přidá ti +15 bonusových bodů."
	},
	{
		"id": "SPEC_MAGNET", "name": "Rune Magnet", "name_cs": "Runový magnet", "short": "MAGNET", "short_cs": "MAGNET", "suit": "GULA",
		"pts": 18, "cost": 16, "rarity": "Uncommon", "rarity_cs": "Neobvyklá", "wild": false,
		"accent": Color(0.45, 0.78, 1.0), "art_file": "SPEC_MAGNET.png",
		"power_line": "Pull 2 Matching Cards", "power_line_cs": "Přitáhne 2 stejné karty",
		"desc": "Pulls up to 2 matching-rank cards from Deck into your hand!",
		"desc_cs": "Vytáhne z balíčku až 2 stejné hodnoty přímo do tvé ruky!"
	},
	{
		"id": "SPEC_SHIELD", "name": "Iron Bastion", "name_cs": "Železná bašta", "short": "SHIELD", "short_cs": "ŠTÍT", "suit": "ZALUD",
		"pts": 22, "cost": 15, "rarity": "Common", "rarity_cs": "Běžná", "wild": false,
		"accent": Color(0.68, 0.78, 0.88), "art_file": "SPEC_SHIELD.png",
		"power_line": "+2 Reflect Shields", "power_line_cs": "+2 Odrazové štíty",
		"desc": "Grants 2 Shields: blocks & rebounds Rival attacks!",
		"desc_cs": "Přidá 2 Štíty: vykryjí a odrazí příští útoky soupeře!"
	},
	{
		"id": "SPEC_GAMBLER", "name": "Loaded Dice", "name_cs": "Cinknuté kostky", "short": "DICE", "short_cs": "KOSTKY", "suit": "ZALUD",
		"pts": 15, "cost": 17, "rarity": "Uncommon", "rarity_cs": "Neobvyklá", "wild": true,
		"accent": Color(0.98, 0.62, 0.20), "art_file": "SPEC_GAMBLER.png",
		"power_line": "×2.0 Solo / ×3.0 Combo", "power_line_cs": "×2.0 Sólo / ×3.0 Kombo",
		"desc": "WILD: Deterministic ×2.0 Mult solo, or ×3.0 Mult when played in a Combo!",
		"desc_cs": "DIVOKÁ: Dává ×2.0 násobič sólo, nebo ×3.0 násobič v kombu!"
	},
	{
		"id": "SPEC_PLAGUE", "name": "Frost Blight", "name_cs": "Mrazivá zhouba", "short": "FROST", "short_cs": "MRÁZ", "suit": "ZELEN",
		"pts": 24, "cost": 17, "rarity": "Uncommon", "rarity_cs": "Neobvyklá", "wild": false,
		"accent": Color(0.42, 0.92, 0.98), "art_file": "SPEC_PLAGUE.png",
		"power_line": "Stun Rival & -15 pts", "power_line_cs": "Omráčí soupeře a -15 b.",
		"desc": "Chills Rival (-15 pts) & stuns them for 1 turn!",
		"desc_cs": "Zmrazí soupeře (-15 b.) a vynechá mu 1 tah!"
	},
	{
		"id": "SPEC_CROWN", "name": "Royal Decree", "name_cs": "Královský glejt", "short": "CROWN", "short_cs": "KORUNA", "suit": "GULA",
		"pts": 26, "cost": 22, "rarity": "Rare", "rarity_cs": "Vzácná", "wild": false,
		"accent": Color(1.0, 0.86, 0.30), "art_file": "SPEC_CROWN.png",
		"power_line": "+20/Court Card Held", "power_line_cs": "+20 b. za figuru v ruce",
		"desc": "Adds +20 pts for every Court Card (D/H/K/E) in your hand!",
		"desc_cs": "Přidá +20 bodů za každého Spodka, Svrška, Krále či Eso v ruce!"
	},
]

const RELICS := [
	{
		"id": "REL_CHAMOIS", "name": "Chamois Horn", "name_cs": "Kamzičí roh", "icon": "Horn", "cost": 20,
		"category": "Chips", "category_cs": "Body", "col": Color(0.92, 0.72, 0.32),
		"desc": "+10 pts whenever a Clubs (♣) or Power Card scores.",
		"desc_cs": "+10 bodů za každý Žalud (♣) nebo Mocnou kartu."
	},
	{
		"id": "REL_FUJARA", "name": "Copper Fujara", "name_cs": "Měděná fujara", "icon": "Flute", "cost": 22,
		"category": "Flat Mult", "category_cs": "Násobitel", "col": Color(0.95, 0.56, 0.28),
		"desc": "+2.5 Flat Mult on single-card plays.",
		"desc_cs": "+2.5× násobitel při zahrání jediné karty."
	},
	{
		"id": "REL_STORMCAP", "name": "Storm Capacitor", "name_cs": "Bouřková cívka", "icon": "Bolt", "cost": 25,
		"category": "X-Mult", "category_cs": "×Násobič", "col": Color(0.38, 0.90, 1.0),
		"desc": "×1.5 Mult & Lightning on every Combo (2+ cards).",
		"desc_cs": "×1.5 násobitel a blesk při každém kombu (2+ karty)."
	},
	{
		"id": "REL_KNUCKLE", "name": "Loaded Knucklebone", "name_cs": "Kouzelná kůstka", "icon": "Bone", "cost": 32,
		"category": "Chips", "category_cs": "Body", "col": Color(0.96, 0.86, 0.62),
		"desc": "35% chance any play triggers its Chips twice!",
		"desc_cs": "35% šance, že zahraná karta oboduje dvakrát!"
	},
	{
		"id": "REL_PHOENIX_F", "name": "Phoenix Feather", "name_cs": "Péro Fénixe", "icon": "Plume", "cost": 24,
		"category": "X-Mult", "category_cs": "×Násobič", "col": Color(1.0, 0.44, 0.22),
		"desc": "×1.6 X-Mult when finishing with ≤ 2 cards left.",
		"desc_cs": "×1.6 násobitel, pokud ti v ruce zůstanou max. 2 karty."
	},
	{
		"id": "REL_FANG", "name": "Crimson Fang", "name_cs": "Rudý tesák", "icon": "Fang", "cost": 20,
		"category": "Utility", "category_cs": "Útok", "col": Color(0.90, 0.18, 0.30),
		"desc": "Every Hearts (♥) card drains 10 pts from Rival.",
		"desc_cs": "Každé zahrané Srdce (♥) vysaje 10 bodů ze soupeře."
	},
	{
		"id": "REL_GREED", "name": "Merchant Scale", "name_cs": "Kupecké váhy", "icon": "Coin", "cost": 22,
		"category": "Economy", "category_cs": "Zlato", "col": Color(1.0, 0.84, 0.20),
		"desc": "+5 Florins per Bells (●) card & +15g on Victory.",
		"desc_cs": "+5 Zlatých za každou Kouli (●) a +15g za vítězství."
	},
	{
		"id": "REL_ALEMBIC", "name": "Hellfire Still", "name_cs": "Alchymistická baňka", "icon": "Flask", "cost": 24,
		"category": "Alchemy", "category_cs": "Alchymie", "col": Color(0.96, 0.44, 0.18),
		"desc": "+1 Hellfire Phial at match start; burning yields +15g & +40 pts.",
		"desc_cs": "+1 Baňka ohně na startu; zapálení dá +15g a +40 b."
	},
	{
		"id": "REL_ROYAL", "name": "King's Signet", "name_cs": "Královská pečeť", "icon": "Ring", "cost": 26,
		"category": "Chips", "category_cs": "Body", "col": Color(1.0, 0.88, 0.38),
		"desc": "Court Cards (D/H/K/E) score +10 extra pts.",
		"desc_cs": "Všechny figury (Spodek, Svršek, Král, Eso) mají +10 bodů."
	},
	{
		"id": "REL_CHRONO_P", "name": "Chrono Pendulum", "name_cs": "Kyvadlo času", "icon": "Clock", "cost": 25,
		"category": "Utility", "category_cs": "Výhoda", "col": Color(0.56, 0.86, 0.96),
		"desc": "+2 extra Redraws at the start of every match.",
		"desc_cs": "+2 výměny karet navíc na začátku každého zápasu."
	},
	{
		"id": "REL_HEX_DOLL", "name": "Voodoo Effigy", "name_cs": "Prokletá panenka", "icon": "Hex", "cost": 18,
		"category": "Utility", "category_cs": "Útok", "col": Color(0.62, 0.30, 0.86),
		"desc": "+12 pts whenever Rival is forced to draw penalty cards.",
		"desc_cs": "+12 bodů pokaždé, když soupeř musí trestně lízat."
	},
	{
		"id": "REL_IRON_BOOT", "name": "Legion Greaves", "name_cs": "Železné holeně", "icon": "Armor", "cost": 22,
		"category": "Utility", "category_cs": "Obrana", "col": Color(0.70, 0.76, 0.84),
		"desc": "Start every match with +1 Shield and +25 Score.",
		"desc_cs": "Začni každý zápas s +1 Štítem a +25 body náskoku."
	},
	{
		"id": "REL_OVERCHARGE", "name": "Tatra Rod", "name_cs": "Tatranský hromosvod", "icon": "Tower", "cost": 34,
		"category": "Flat Mult", "category_cs": "Násobitel", "col": Color(0.46, 0.96, 1.0),
		"desc": "Multi-card Combos gain +2.0× Flat Mult per extra card!",
		"desc_cs": "Vícekartová komba přidají +2.0× za každou další kartu!"
	},
	{
		"id": "REL_WOODCUTTER", "name": "Forest Cleaver", "name_cs": "Dřevorubcova sekera", "icon": "Axe", "cost": 20,
		"category": "Chips", "category_cs": "Body", "col": Color(0.76, 0.62, 0.30),
		"desc": "+30 Chips for every Clubs (♣) or Seven (7) played.",
		"desc_cs": "+30 bodů za každý Žalud (♣) nebo Sedmu (7) v tahu."
	},
	{
		"id": "REL_FORGEMASTER", "name": "Anvil Tally", "name_cs": "Kovářská kovadlina", "icon": "Anvil", "cost": 22,
		"category": "Chips", "category_cs": "Body", "col": Color(0.95, 0.65, 0.28),
		"desc": "+45 Chips per card on every Combo (2+ cards).",
		"desc_cs": "+45 bodů za každou kartu při jakémkoli kombu (2+)."
	},
	{
		"id": "REL_RED_SEAL", "name": "Waxed Sigil", "name_cs": "Vosková pečeť", "icon": "Seal", "cost": 20,
		"category": "Chips", "category_cs": "Body", "col": Color(0.94, 0.34, 0.30),
		"desc": "+28 Chips for every Red card (♥ Hearts or ● Bells).",
		"desc_cs": "+28 bodů za každou červenou či zlatou kartu (♥ nebo ●)."
	},
	{
		"id": "REL_CRIMSON_CHOIR", "name": "Crimson Choir", "name_cs": "Rudý chór", "icon": "Lyre", "cost": 24,
		"category": "X-Mult", "category_cs": "×Násobič", "col": Color(0.96, 0.28, 0.42),
		"desc": "×1.5 Mult when all played cards are ♥ or ●.",
		"desc_cs": "×1.5 násobitel, pokud jsou všechny zahrané karty ♥ nebo ●."
	},
	{
		"id": "REL_GREEN_CANOPY", "name": "Highland Canopy", "name_cs": "Lesní koruna", "icon": "Leaf", "cost": 25,
		"category": "Flat Mult", "category_cs": "Násobitel", "col": Color(0.26, 0.82, 0.52),
		"desc": "+6.0× Flat Mult if ≥ 2 Leaves/Clubs stay in hand.",
		"desc_cs": "+6.0× násobitel, pokud máš v ruce aspoň 2× Listí nebo Žaludy."
	},
	{
		"id": "REL_PRSI_PURIST", "name": "Tavern Purist", "name_cs": "Korbel štamgasta", "icon": "Mug", "cost": 23,
		"category": "Flat Mult", "category_cs": "Násobitel", "col": Color(0.94, 0.78, 0.36),
		"desc": "+4.5× Flat Mult on solo 7, Queen (H) or Ace (E).",
		"desc_cs": "+4.5× násobitel při samotné Sedmě, Svrškovi nebo Esu."
	},
	{
		"id": "REL_SEVEN_GRIMOIRE", "name": "Ledger of Sevens", "name_cs": "Grimoár sedmiček", "icon": "Grim", "cost": 30,
		"category": "Scaling", "category_cs": "Růst", "col": Color(0.82, 0.46, 1.0),
		"desc": "SCALING: Gains +0.15× permanently every Seven (7) played!",
		"desc_cs": "TRVALÝ RŮST: Přidá +0.15× za každou zahranou Sedmu!"
	},
	{
		"id": "REL_MERCHANT_LEDGER", "name": "Peddler's Ledger", "name_cs": "Kniha kramáře", "icon": "Scroll", "cost": 26,
		"category": "Scaling", "category_cs": "Růst", "col": Color(1.0, 0.84, 0.32),
		"desc": "SCALING: Gains +18 Chips every time you Reroll Shop!",
		"desc_cs": "TRVALÝ RŮST: Přidá +18 bodů za každé obnovení Obchodu!"
	},
	{
		"id": "REL_FINAL_TOLL", "name": "Executioner's Oath", "name_cs": "Katova přísaha", "icon": "Blade", "cost": 32,
		"category": "X-Mult", "category_cs": "×Násobič", "col": Color(1.0, 0.24, 0.28),
		"desc": "×2.5 X-Mult when emptying hand to 0 cards (×1.5 at 1 left)!",
		"desc_cs": "×2.5 násobitel při vyhození poslední karty v ruce (×1.5 s 1 kartou)!"
	},
	{
		"id": "REL_COURT_SOVEREIGN", "name": "Sovereign Treasury", "name_cs": "Královská pokladna", "icon": "Crown", "cost": 34,
		"category": "X-Mult", "category_cs": "×Násobič", "col": Color(1.0, 0.86, 0.28),
		"desc": "×1.4 X-Mult per Court card (D/H/K/E) still held in hand!",
		"desc_cs": "×1.4 násobitel za každou figuru (D/H/K/E) drženou v ruce!"
	},
]

const ALCHEMY_ITEMS := [
	{
		"id": "ALC_REMOVE", "name": "Acid of Oblivion", "name_cs": "Kyselina zapomnění", "action": "remove", "cost": 15,
		"col": Color(0.68, 0.94, 0.38), "sub": "Remove 1 Card", "sub_cs": "Odebrat 1 kartu",
		"desc": "Dissolve 1 chosen card from your deck (min 12 cards).",
		"desc_cs": "Navždy rozpustí 1 vybranou kartu z tvého balíčku (min. 12 karet)."
	},
	{
		"id": "ALC_CLONE", "name": "Doppelganger Phial", "name_cs": "Klonovací lektvar", "action": "clone", "cost": 20,
		"col": Color(0.54, 0.86, 1.0), "sub": "Clone 1 Card (+1)", "sub_cs": "Zdvojit 1 kartu (+1)",
		"desc": "Clone 1 chosen card in your deck (keeps Suit & Class)!",
		"desc_cs": "Navždy zdvojí vybranou kartu v balíčku včetně její třídy!"
	},
	{
		"id": "ALC_CONVERT_SUIT", "name": "Prismatic Suit Ink", "name_cs": "Měnič barvy", "action": "convert_suit", "cost": 14,
		"col": Color(0.96, 0.44, 0.56), "sub": "Change Card Suit", "sub_cs": "Změnit barvu karty",
		"desc": "Convert 1 card's Suit to ♥ Hearts or ♣ Acorns!",
		"desc_cs": "Změní barvu vybrané karty na ♥ Srdce nebo ♣ Žaludy!"
	},
	{
		"id": "ALC_INFUSE_MAGE", "name": "Runecaster Tome", "name_cs": "Kniha Mága", "action": "infuse", "edition": "MAGE", "cost": 16,
		"col": Color(0.64, 0.44, 1.0), "sub": "Class: Mage", "sub_cs": "Třída: Mág",
		"desc": "Make 1 card MAGE: charges in hand (2/2) for +20 pts & ×2.0!",
		"desc_cs": "Udělá z karty Mága: nabíjí se v ruce (2/2) na +20 b. a ×2.0!"
	},
	{
		"id": "ALC_INFUSE_KNIGHT", "name": "Mistblade Banner", "name_cs": "Prapor Rytíře", "action": "infuse", "edition": "KNIGHT", "cost": 18,
		"col": Color(0.60, 0.88, 0.98), "sub": "Class: Knight", "sub_cs": "Třída: Rytíř",
		"desc": "Make 1 card KNIGHT: +10 pts, ×1.5 & Battle Mist trap!",
		"desc_cs": "Udělá z karty Rytíře: +10 b., ×1.5 a mlžná past!"
	},
	{
		"id": "ALC_INFUSE_MERCHANT", "name": "Guildsman Charter", "name_cs": "Listina Kupce", "action": "infuse", "edition": "MERCHANT", "cost": 16,
		"col": Color(1.0, 0.82, 0.24), "sub": "Class: Merchant", "sub_cs": "Třída: Kupec",
		"desc": "Make 1 card MERCHANT: skips ability for +5 pts & +15 Florins on play!",
		"desc_cs": "Udělá z karty Kupce: bez schopnosti, ale dá +5 b. a +15 Zlatých!"
	},
	{
		"id": "ALC_INFUSE_THIEF", "name": "Cutpurse Dagger", "name_cs": "Dýka Zloděje", "action": "infuse", "edition": "THIEF", "cost": 22,
		"col": Color(0.28, 0.90, 0.56), "sub": "Class: Thief", "sub_cs": "Třída: Zloděj",
		"desc": "Make 1 card THIEF: guess Rival pairs to steal cards & +2 Draw!",
		"desc_cs": "Udělá z karty Zloděje: tipni pár soupeře, ukradneš kartu +2 lízání!"
	},
]

const ERA_STAGES := {
	"antika": [
		{"stage_idx": 0, "stage_name": "Temple Guard", "stage_name_cs": "Chrámový strážce", "boss_mod": "", "boss_desc": "", "boss_desc_cs": "", "target_mult": 0.75, "gold": 90},
		{"stage_idx": 1, "stage_name": "High Scribe", "stage_name_cs": "Vrchní písař", "boss_mod": "SCROLL_TAX", "boss_desc": "Deck draws cost 2 pts; same suit grants Flow bonus!", "boss_desc_cs": "Lízání z balíčku stojí 2 b.; stejná barva dává bonus!", "target_mult": 0.95, "gold": 125},
		{"stage_idx": 2, "stage_name": "Pharaoh Ramesses (BOSS)", "stage_name_cs": "Faraon Ramesse (BOSS)", "boss_mod": "PHARAOH_SEAL", "boss_desc": "Solo plays <20 pts pay -2 tax; Power Cards & Combos gain +15!", "boss_desc_cs": "Slabé karty (<20 b.) mají daň -2 b.; komba a Mocné karty +15!", "target_mult": 1.15, "gold": 200},
	],
	"rim": [
		{"stage_idx": 0, "stage_name": "Arena Gladiator", "stage_name_cs": "Gladiátor arény", "boss_mod": "", "boss_desc": "", "boss_desc_cs": "", "target_mult": 0.80, "gold": 105},
		{"stage_idx": 1, "stage_name": "Centurion Captain", "stage_name_cs": "Velitel centurie", "boss_mod": "IRON_WALL", "boss_desc": "Rival opens with +15 Score skirmish lead.", "boss_desc_cs": "Soupeř začíná s lehkým náskokem +15 bodů.", "target_mult": 1.00, "gold": 145},
		{"stage_idx": 2, "stage_name": "Julius Caesar (BOSS)", "stage_name_cs": "Julius Caesar (BOSS)", "boss_mod": "CAESAR_TRIBUTE", "boss_desc": "Solo plays grant Rival +4 pts; Combos strike +25!", "boss_desc_cs": "Samostatná karta dá soupeři +4 b.; komba udeří +25 b.!", "target_mult": 1.20, "gold": 230},
	],
	"stredovek": [
		{"stage_idx": 0, "stage_name": "Tavern Squire", "stage_name_cs": "Krčmový zbrojnoš", "boss_mod": "", "boss_desc": "", "boss_desc_cs": "", "target_mult": 0.82, "gold": 120},
		{"stage_idx": 1, "stage_name": "Royal Joust Knight", "stage_name_cs": "Turnajový rytíř", "boss_mod": "IRON_JOUST", "boss_desc": "Sevens, Combos & Power Cards get +20 Bonus (-1 solo).", "boss_desc_cs": "Sedmy, komba a Mocné karty mají +20 b. (ostatní sólo -1 b.).", "target_mult": 1.00, "gold": 165},
		{"stage_idx": 2, "stage_name": "King Charles IV (BOSS)", "stage_name_cs": "Král Karel IV. (BOSS)", "boss_mod": "CROWN_DECREE", "boss_desc": "Rival Court cards gain +4 pts unless blocked by Shields!", "boss_desc_cs": "Soupeřovy figury berou +4 b., pokud nemáš Štít!", "target_mult": 1.22, "gold": 265},
	],
	"objavy": [
		{"stage_idx": 0, "stage_name": "Deck Quartermaster", "stage_name_cs": "Palubní důstojník", "boss_mod": "", "boss_desc": "", "boss_desc_cs": "", "target_mult": 0.85, "gold": 140},
		{"stage_idx": 1, "stage_name": "Sea Navigator", "stage_name_cs": "Mořský navigátor", "boss_mod": "SHIFTING_WINDS", "boss_desc": "Winds rotate the Active Suit every 3 turns!", "boss_desc_cs": "Mořský vítr každé 3 tahy změní barvu na stole!", "target_mult": 1.02, "gold": 190},
		{"stage_idx": 2, "stage_name": "Pirate Queen Anne (BOSS)", "stage_name_cs": "Pirátská královna (BOSS)", "boss_mod": "PLUNDER", "boss_desc": "Rival Aces or 7s raid 4 pts unless blocked by Shields!", "boss_desc_cs": "Soupeřova Esa a 7 berou 4 b., pokud nemáš Štít!", "target_mult": 1.25, "gold": 300},
	],
	"prohibicia": [
		{"stage_idx": 0, "stage_name": "Speakeasy Bouncer", "stage_name_cs": "Vyhazovač z baru", "boss_mod": "", "boss_desc": "", "boss_desc_cs": "", "target_mult": 0.85, "gold": 160},
		{"stage_idx": 1, "stage_name": "Syndicate Accountant", "stage_name_cs": "Účetní syndikátu", "boss_mod": "SYNDICATE_CUT", "boss_desc": "Solo plays pay 5% fee; 2×+ Combos earn +30 bonus!", "boss_desc_cs": "Sólo tah platí 5% výpalné; kombo 2+ získá +30 b.!", "target_mult": 1.05, "gold": 220},
		{"stage_idx": 2, "stage_name": "Al Capone (FINAL BOSS)", "stage_name_cs": "Al Capone (HLAVNÍ BOSS)", "boss_mod": "DON_RACKETEER", "boss_desc": "Starts at +20 pts & +3 Seven Threat!", "boss_desc_cs": "Začíná s +20 body a silným útokem Sedmami!", "target_mult": 1.25, "gold": 350},
	],
}

const SWORD_SKINS := [
	{
		"id": "SWORD_IRON", "name": "Tavern Falchion", "name_cs": "Krčmový tesák", "cost": 0,
		"blade_col": Color(0.68, 0.72, 0.78), "guard_col": Color(0.62, 0.46, 0.18),
		"grip_col": Color(0.32, 0.19, 0.11), "glow_col": Color(0.0, 0.0, 0.0),
		"trail_col": Color(0.85, 0.90, 0.98), "metallic": 0.72,
		"desc": "Starter steel blade resting beside your mat.",
		"desc_cs": "Základní duelantský meč ležící vedle tvých karet."
	},
	{
		"id": "SWORD_GILDED", "name": "Royal Claymore", "name_cs": "Královský meč", "cost": 30,
		"blade_col": Color(0.90, 0.90, 0.96), "guard_col": Color(0.96, 0.78, 0.24),
		"grip_col": Color(0.45, 0.10, 0.12), "glow_col": Color(0.28, 0.20, 0.04),
		"trail_col": Color(1.0, 0.86, 0.34), "metallic": 0.86,
		"desc": "Damascus blade with gilded royal crossguard.",
		"desc_cs": "Damašková čepel se zlacenou královskou záštitou."
	},
	{
		"id": "SWORD_CRIMSON", "name": "Vampire Saber", "name_cs": "Krvavá šavle", "cost": 40,
		"blade_col": Color(0.30, 0.24, 0.26), "guard_col": Color(0.76, 0.52, 0.18),
		"grip_col": Color(0.18, 0.05, 0.06), "glow_col": Color(0.88, 0.10, 0.16),
		"trail_col": Color(1.0, 0.18, 0.24), "metallic": 0.78,
		"desc": "Smoked iron saber glowing with crimson fire.",
		"desc_cs": "Temná šavle žhnoucí rudým upířím ohněm."
	},
	{
		"id": "SWORD_RUNE", "name": "Tempest Runeblade", "name_cs": "Runová čepel bouře", "cost": 48,
		"blade_col": Color(0.56, 0.78, 0.96), "guard_col": Color(0.52, 0.64, 0.78),
		"grip_col": Color(0.12, 0.18, 0.28), "glow_col": Color(0.26, 0.84, 1.0),
		"trail_col": Color(0.36, 0.92, 1.0), "metallic": 0.84,
		"desc": "Sky-forged steel crackling with storm runes.",
		"desc_cs": "Modrá ocel jiskřící prastarými bouřkovými runami."
	},
	{
		"id": "SWORD_DRAGON", "name": "Dragonfire Greatsword", "name_cs": "Meč dračího ohně", "cost": 62,
		"blade_col": Color(0.22, 0.15, 0.13), "guard_col": Color(0.88, 0.62, 0.20),
		"grip_col": Color(0.24, 0.08, 0.05), "glow_col": Color(1.0, 0.42, 0.08),
		"trail_col": Color(1.0, 0.48, 0.12), "metallic": 0.82,
		"desc": "Volcanic black steel burning with ember veins.",
		"desc_cs": "Černá sopečná čepel planoucí žhavými jiskrami."
	},
]

# ============================================================================
# 10 BUYABLE & ACQUIRABLE 3D ACTIVE TABLETOP RELICS (Usable on Table in Duel!)
# ============================================================================
const TABLE_RELICS := [
	{
		"id": "TRELIC_SOUL_BELL",
		"name": "Soul-Severing Bell",
		"name_cs": "Zvon rozetnutí duše",
		"short": "SHATTER SHIELDS",
		"short_cs": "ROZBIJE ŠTÍTY",
		"cost": 22,
		"charges": 1,
		"col": Color(0.24, 0.90, 1.0),
		"glb": "res://assets/models/relics/TRELIC_SOUL_BELL.glb",
		"desc": "TABLE RELIC (1×/duel): Rings a Reiatsu shockwave that shatters all Rival Shields & drains -18 Rival pts.",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Rozezní rázovou vlnu — zničí všechny soupeřovy štíty a sebere mu -18 bodů."
	},
	{
		"id": "TRELIC_BLOOD_SEAL",
		"name": "Blood-Ink Seal",
		"name_cs": "Krvavá pečeť",
		"short": "NEXT PLAY ×2",
		"short_cs": "PŘÍŠTÍ TAH ×2",
		"cost": 26,
		"charges": 1,
		"col": Color(0.96, 0.14, 0.24),
		"glb": "res://assets/models/relics/TRELIC_BLOOD_SEAL.glb",
		"desc": "TABLE RELIC (1×/duel): Stamps your next play with Crimson Resonance (×2.0 Score) & drains -10 Rival pts!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Tvůj příští tah má ×2.0 body a vysaje -10 bodů ze soupeře!"
	},
	{
		"id": "TRELIC_STAR_BOW",
		"name": "Quincy Astrolabe",
		"name_cs": "Hvězdný astroláb",
		"short": "REVEAL & PIERCE",
		"short_cs": "ODHALENÍ + SALVA",
		"cost": 24,
		"charges": 1,
		"col": Color(0.22, 0.88, 1.0),
		"glb": "res://assets/models/relics/TRELIC_STAR_BOW.glb",
		"desc": "TABLE RELIC (1×/duel): Fires a cyan star volley — reveals Rival's hand for 2 turns & deals 1 ♥ HP damage!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Vypálí salvu hvězdných šípů — odhalí soupeřovy karty na 2 tahy a ubere 1 ♥ HP!"
	},
	{
		"id": "TRELIC_ASH_GLASS",
		"name": "Ashen Hourglass",
		"name_cs": "Popelavé přesýpací hodiny",
		"short": "RECHARGE +2 REDRAW",
		"short_cs": "NABITÍ +2 VÝMĚNY",
		"cost": 24,
		"charges": 1,
		"col": Color(0.74, 0.44, 1.0),
		"glb": "res://assets/models/relics/TRELIC_ASH_GLASS.glb",
		"desc": "TABLE RELIC (1×/duel): Rewinds fate — +2 free Redraws & instantly charges all Mage cards in hand to 2/2!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Vrátí čas — +2 výměny zdarma a okamžitě nabije všechny Mágy v ruce na 2/2!"
	},
	{
		"id": "TRELIC_WAR_HORN",
		"name": "Templar War-Horn",
		"name_cs": "Templářský válečný roh",
		"short": "FORGE KNIGHT +2🛡",
		"short_cs": "UKOVE RYTÍŘE +2🛡",
		"cost": 22,
		"charges": 1,
		"col": Color(0.68, 0.86, 1.0),
		"glb": "res://assets/models/relics/TRELIC_WAR_HORN.glb",
		"desc": "TABLE RELIC (1×/duel): Forges your strongest card into a heavy metallic Knight & grants +2 Iron Shields!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Ukove tvou nejsilnější kartu na těžkého kovového Rytíře a přidá +2 Štíty!"
	},
	{
		"id": "TRELIC_HOLLOW_MASK",
		"name": "Hollow Mask Fragment",
		"name_cs": "Střep prázdné masky",
		"short": "-1♥ → WILD ×2",
		"short_cs": "-1♥ → DIVOKÁ ×2",
		"cost": 30,
		"charges": 1,
		"col": Color(1.0, 0.22, 0.30),
		"glb": "res://assets/models/relics/TRELIC_HOLLOW_MASK.glb",
		"desc": "TABLE RELIC (1×/duel): Pay 1 ♥ HP to unleash Hollow Reiatsu — your next card plays WILD on any suit at ×2.0 Score!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Obětuj 1 ♥ HP — tvoje příští karta je DIVOKÁ na jakoukoli barvu s ×2.0 body!"
	},
	{
		"id": "TRELIC_CENSER",
		"name": "Alchemist's Censer",
		"name_cs": "Alchymistická kadidelnice",
		"short": "MAGE 2/2 + PHIAL",
		"short_cs": "MÁG 2/2 + BAŇKA",
		"cost": 25,
		"charges": 1,
		"col": Color(0.28, 0.96, 0.68),
		"glb": "res://assets/models/relics/TRELIC_CENSER.glb",
		"desc": "TABLE RELIC (1×/duel): Imbues a card in hand into a full-charge Mage (2/2) & refills +1 Hellfire Phial!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Promění kartu v ruce v plně nabitého Mága (2/2) a doplní +1 Ohnivou baňku!"
	},
	{
		"id": "TRELIC_GOLD_SCALES",
		"name": "Gilded Merchant Scales",
		"name_cs": "Zlaté kupecké váhy",
		"short": "+22g & +1 CARD",
		"short_cs": "+22g & +1 KARTA",
		"cost": 20,
		"charges": 1,
		"col": Color(1.0, 0.84, 0.22),
		"glb": "res://assets/models/relics/TRELIC_GOLD_SCALES.glb",
		"desc": "TABLE RELIC (1×/duel): Mints +22 Florins immediately and draws +1 card directly into your hand!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Ihned vyrazí +22 Zlatých a lízne +1 kartu rovnou do ruky!"
	},
	{
		"id": "TRELIC_IRON_CHAIN",
		"name": "Executioner's Chain",
		"name_cs": "Katovský řetěz",
		"short": "STUN RIVAL +14",
		"short_cs": "ZASTAVÍ SOUPEŘE",
		"cost": 28,
		"charges": 1,
		"col": Color(0.46, 0.84, 1.0),
		"glb": "res://assets/models/relics/TRELIC_IRON_CHAIN.glb",
		"desc": "TABLE RELIC (1×/duel): Binds the Rival in iron chains — forces Rival +2 Draw & adds +14 pts immediately!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Spoutá soupeře řetězy — donutí ho líznout +2 karty a ihned přidá +14 bodů!"
	},
	{
		"id": "TRELIC_PHOENIX_BOX",
		"name": "Phoenix Reliquary",
		"name_cs": "Relikviář Fénixe",
		"short": "+2♥ HEAL & PURGE",
		"short_cs": "+2♥ LÉČENÍ + ČISTKA",
		"cost": 28,
		"charges": 1,
		"col": Color(1.0, 0.52, 0.16),
		"glb": "res://assets/models/relics/TRELIC_PHOENIX_BOX.glb",
		"desc": "TABLE RELIC (1×/duel): Opens blazing wings — restores +2 ♥ HP, clears pending Draw/Ace curses & adds +16 pts!",
		"desc_cs": "RELIKVIE NA STŮL (1×/duel): Otevře ohnivý relikviář — vyléčí +2 ♥ HP, zruší kletby a přidá +16 bodů!"
	},
]

static func get_table_relic(tid: String) -> Dictionary:
	for tr in TABLE_RELICS:
		if str(tr.get("id", "")) == tid:
			return tr
	return {}

static func get_table_relic_loc(tid: String, lang: String = "en") -> Dictionary:
	var tr: Dictionary = get_table_relic(tid).duplicate(true)
	if tr.is_empty():
		return tr
	if lang == "cs":
		tr["name"] = str(tr.get("name_cs", tr.get("name", "")))
		tr["short"] = str(tr.get("short_cs", tr.get("short", "")))
		tr["desc"] = str(tr.get("desc_cs", tr.get("desc", "")))
	return tr

static func grant_table_relic(prof: Dictionary, tid: String) -> bool:
	if get_table_relic(tid).is_empty():
		return false
	var owned: Array = prof.get("table_relics", [])
	if not (tid in owned):
		owned.append(tid)
		prof["table_relics"] = owned
		return true
	return false

# ============================================================================
# 10 MYSTERIOUS MEDIEVAL FANTASY CROSSROADS UPGRADES & ITEMS (Every 3 Rounds)
# ============================================================================
const MEDIEVAL_MYSTIC_ITEMS := [
	{
		"id": "MYS_LANTERN_ASH",
		"name": "Cinder of Saint Vitus",
		"name_cs": "Popel svatého Víta",
		"category": "KNIGHT RELIC",
		"emblem": "urn",
		"cost": 10,
		"col": Color(0.95, 0.58, 0.24),
		"desc": "Sits on your table: +1 Redraw right now, and turns your leftmost card into a Mistblade Knight (+0.75× Mult & fog trap).",
		"desc_cs": "Položí se na stůl: Ihned +1 výměna karet a promění tvou první kartu v Rytíře mlhy (+0.75× násobitel)."
	},
	{
		"id": "MYS_BLOOD_CHALICE",
		"name": "Gilded Plague Chalice",
		"name_cs": "Zlacený morový kalich",
		"category": "TABLE ARTIFACT",
		"emblem": "chalice",
		"cost": 12,
		"col": Color(0.92, 0.24, 0.28),
		"desc": "Placed on the table: Permanently adds +0.4× Flat Mult to every hand you play this duel and gives +12 points right away.",
		"desc_cs": "Stojí na stole: Trvale přidává +0.4× násobitel ke každému tahu v tomto duelu a ihned přidá +12 bodů."
	},
	{
		"id": "MYS_IRON_GAUNTLET",
		"name": "Templar Iron Gauntlet",
		"name_cs": "Templářská železná rukavice",
		"category": "ARMOR ARTIFACT",
		"emblem": "gauntlet",
		"cost": 10,
		"col": Color(0.68, 0.78, 0.90),
		"desc": "Heavy steel on the felt: Grants +2 Iron Shields (blocks curses) and smashes -15 points off the Rival's score.",
		"desc_cs": "Těžká ocel na stole: Přidá +2 Železné štíty proti kletbám a okamžitě sebere soupeři 15 bodů."
	},
	{
		"id": "MYS_ALCHEMIST_PHIAL",
		"name": "Quicksilver Fire Flask",
		"name_cs": "Baňka rtuťového ohně",
		"category": "ALCHEMY ITEM",
		"emblem": "phial",
		"cost": 11,
		"col": Color(0.96, 0.46, 0.20),
		"desc": "Refills +2 Hellfire Phials on your table and boosts your next play with +1.2× Storm Surge multiplier.",
		"desc_cs": "Doplní +2 Ohnivé lahvičky na tvůj stůl a nabije příští tah +1.2× bouřkovým násobitelem."
	},
	{
		"id": "MYS_RAVENS_EYE",
		"name": "Seer's Raven Monocle",
		"name_cs": "Havraní monokl věštce",
		"category": "TABLE CURIO",
		"emblem": "eye",
		"cost": 9,
		"col": Color(0.42, 0.88, 0.96),
		"desc": "Watches from the table: Flips all of the Rival's cards face-up for 3 turns and draws +1 card into your hand.",
		"desc_cs": "Sleduje hru ze stolu: Na 3 tahy otočí všechny soupeřovy karty lícem nahoru a lízne ti +1 kartu."
	},
	{
		"id": "MYS_HERMIT_SCROLL",
		"name": "Blind Monk's Scroll",
		"name_cs": "Svitek slepého mnicha",
		"category": "DECK SCROLL",
		"emblem": "scroll",
		"cost": 14,
		"col": Color(0.96, 0.84, 0.40),
		"desc": "Permanent ink blessing: Every 7 and 8 in your hand gains +15 base points, and 1 Mage card charges to full (2/2)!",
		"desc_cs": "Požehnání pergamenu: Každá 7 a 8 v ruce získá +15 bodů a 1 karta Mága se okamžitě plně nabije (2/2)!"
	},
	{
		"id": "MYS_WITCH_MIRROR",
		"name": "Belladonna Witch-Mirror",
		"name_cs": "Čarodějné zrcátko",
		"category": "TABLE MIRROR",
		"emblem": "mirror",
		"cost": 15,
		"col": Color(0.64, 0.44, 1.0),
		"desc": "Rests on the table (click it anytime!): Multiplies your next play by ×1.5 X-Mult and conjures a Wild Mirror Card.",
		"desc_cs": "Leží na stole (můžeš na něj kliknout!): Vynásobí tvůj příští tah ×1.5 a vyčaruje divokou kartu!"
	},
	{
		"id": "MYS_CROWBAR_KEY",
		"name": "Vyšehrad Skeleton Key",
		"name_cs": "Vyšehradský paklíč",
		"category": "TABLE RELIC",
		"emblem": "key",
		"cost": 10,
		"col": Color(0.86, 0.70, 0.36),
		"desc": "Unlocks tight spots: Cancels any active Seven/Ace penalty against you, draws +2 cards, and adds +15 points.",
		"desc_cs": "Odemkne každou past: Zruší proti tobě aktivní Sedmu či Eso, lízne +2 karty a přidá +15 bodů."
	},
	{
		"id": "MYS_RUNE_WHETSTONE",
		"name": "Executioner's Whetstone",
		"name_cs": "Katovský brousek",
		"category": "BLADE ARTIFACT",
		"emblem": "whetstone",
		"cost": 13,
		"col": Color(1.0, 0.38, 0.28),
		"desc": "Sharpens your table sword: Every Court card (J, Q, K, A) gets ×1.35 X-Mult, plus +35g on Sword victory.",
		"desc_cs": "Nabrousí tvůj meč na stole: Každá figurová karta (D, H, K, Eso) získá ×1.35 násobitel a +35g při výhře."
	},
	{
		"id": "MYS_BELL_TOLL",
		"name": "Plague-Bell Clapper",
		"name_cs": "Srdce morového zvonu",
		"category": "DREAD ARTIFACT",
		"emblem": "bell",
		"cost": 16,
		"col": Color(0.98, 0.74, 0.24),
		"desc": "Rings across the tavern: Freezes the Rival for 1 full turn, strikes for +45 points, and adds +1 Fire Flask.",
		"desc_cs": "Rozezní celou krčmu: Zmrazí soupeře na 1 celé kolo, udeří za +45 bodů a přidá +1 Ohnivou lahvičku."
	},
]

static func get_medieval_mystic_item(item_id: String) -> Dictionary:
	for it in MEDIEVAL_MYSTIC_ITEMS:
		if str(it.get("id", "")) == item_id:
			return it
	return {}

static func tr_loc(lang: String, en_text: String, cs_text: String) -> String:
	return cs_text if lang == "cs" else en_text

static func get_shop_item_art(emblem: String) -> String:
	var p := "res://assets/shop/%s.png" % emblem
	return p if ResourceLoader.exists(p) else ""

static func roll_medieval_peddler_offers(count: int = 3, owned_table_relics: Array = []) -> Array[Dictionary]:
	var pool := MEDIEVAL_MYSTIC_ITEMS.duplicate()
	pool.shuffle()
	var res: Array[Dictionary] = []
	for i in range(mini(count, pool.size())):
		# Slot 1: offer an unowned 3D Active Tabletop Relic from the 10 TABLE_RELICS so players can buy & place them mid-duel!
		if i == 1 and count >= 3:
			var tr_pool: Array[Dictionary] = []
			for tr_raw in TABLE_RELICS:
				if not (str(tr_raw["id"]) in owned_table_relics):
					tr_pool.append(tr_raw)
			if not tr_pool.is_empty():
				tr_pool.shuffle()
				var tr_pick: Dictionary = (tr_pool[0] as Dictionary).duplicate()
				res.append({
					"id": str(tr_pick["id"]),
					"name": str(tr_pick["name"]),
					"name_cs": str(tr_pick.get("name_cs", tr_pick["name"])),
					"category": "3D TABLE RELIC",
					"category_cs": "3D RELIKVIE NA STŮL",
					"emblem": str(tr_pick["id"]),
					"cost": int(tr_pick.get("cost", 24)),
					"col": tr_pick.get("col", Color(0.96, 0.24, 0.34)),
					"desc": str(tr_pick.get("desc", "")),
					"desc_cs": str(tr_pick.get("desc_cs", tr_pick.get("desc", ""))),
					"bought": false,
					"is_table_relic": true,
				})
				continue
		var entry: Dictionary = (pool[i] as Dictionary).duplicate()
		entry["bought"] = false
		entry["shop_art"] = get_shop_item_art(str(entry.get("emblem", "urn")))
		# Slot 2 (3rd crossroads offer) is a Free Traveler Blessing so players always gain a medieval gift!
		if i == 2:
			entry["cost"] = 0
			entry["category"] = "FREE BLESSING"
			entry["category_cs"] = "DÁREK ZDARMA"
		else:
			var cat_en := str(entry.get("category", "TABLE ARTIFACT"))
			var cat_cs_map := {
				"KNIGHT RELIC": "RYTÍŘSKÁ RELIKVIE",
				"TABLE ARTIFACT": "ARTEFAKT NA STŮL",
				"ARMOR ARTIFACT": "OBRANA NA STŮL",
				"ALCHEMY ITEM": "ALCHYMIE",
				"TABLE CURIO": "ZÁZRAK NA STŮL",
				"DECK SCROLL": "SVITEK BALÍČKU",
				"TABLE MIRROR": "ZRCADLO NA STŮL",
				"TABLE RELIC": "RELIKVIE NA STŮL",
				"BLADE ARTIFACT": "OSTŘÍ MEČE",
				"DREAD ARTIFACT": "ZVON ZKÁZY",
			}
			entry["category_cs"] = str(cat_cs_map.get(cat_en, "ARTEFAKT"))
		res.append(entry)
	return res

static func get_power_card_loc(card_id: String, lang: String = "en") -> Dictionary:
	var pc := get_power_card(card_id).duplicate()
	if pc.is_empty():
		return pc
	if lang == "cs":
		pc["name"] = str(pc.get("name_cs", pc.get("name", "")))
		pc["short"] = str(pc.get("short_cs", pc.get("short", "")))
		pc["rarity"] = str(pc.get("rarity_cs", pc.get("rarity", "")))
		pc["power_line"] = str(pc.get("power_line_cs", pc.get("power_line", "")))
		pc["desc"] = str(pc.get("desc_cs", pc.get("desc", "")))
	return pc

static func get_relic_loc(rel_id: String, lang: String = "en") -> Dictionary:
	var r := get_relic(rel_id).duplicate()
	if r.is_empty():
		return r
	if lang == "cs":
		r["name"] = str(r.get("name_cs", r.get("name", "")))
		r["category"] = str(r.get("category_cs", r.get("category", "")))
		r["desc"] = str(r.get("desc_cs", r.get("desc", "")))
	return r

static func get_card_class_loc(cls_id: String, lang: String = "en") -> Dictionary:
	var c := get_card_class(cls_id).duplicate()
	if lang == "cs":
		c["name"] = str(c.get("name_cs", c.get("name", "")))
		c["short_cls"] = str(c.get("short_cls_cs", c.get("short_cls", "")))
		c["badge"] = str(c.get("badge_cs", c.get("badge", "")))
		c["desc"] = str(c.get("desc_cs", c.get("desc", "")))
	return c

static func get_sword_skin_loc(skin_id: String, lang: String = "en") -> Dictionary:
	var s := get_sword_skin(skin_id).duplicate()
	if lang == "cs":
		s["name"] = str(s.get("name_cs", s.get("name", "")))
		s["desc"] = str(s.get("desc_cs", s.get("desc", "")))
	return s

static func get_alchemy_item_loc(alc_id: String, lang: String = "en") -> Dictionary:
	var a := get_alchemy_item(alc_id).duplicate()
	if not a.is_empty() and lang == "cs":
		a["name"] = str(a.get("name_cs", a.get("name", "")))
		a["sub"] = str(a.get("sub_cs", a.get("sub", "")))
		a["desc"] = str(a.get("desc_cs", a.get("desc", "")))
	return a

static func get_power_card(card_id: String) -> Dictionary:
	for pc in POWER_CARDS:
		if pc["id"] == card_id:
			return pc
	return {}

static func get_relic_art_path(rel_id: String) -> String:
	return "res://assets/relics/%s.png" % rel_id

static func get_relic(rel_id: String) -> Dictionary:
	for r in RELICS:
		if r["id"] == rel_id:
			return r
	return {}

static func is_relic_hidden(rel_id: String) -> bool:
	return rel_id in TEMPORARILY_HIDDEN_RELICS

static func get_visible_relics() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in RELICS:
		if not is_relic_hidden(str(r.get("id", ""))):
			out.append(r)
	return out

static func normalize_card_class(cls_id: String) -> String:
	match cls_id:
		"NORMAL", "STD", "":
			return "NORMAL"
		"MAGE", "FOIL":
			return "MAGE"
		"KNIGHT", "HOLO":
			return "KNIGHT"
		"MERCHANT", "POLY":
			return "MERCHANT"
		"THIEF", "STORM":
			return "THIEF"
		_:
			return cls_id if CARD_CLASSES.has(cls_id) else "NORMAL"

static func get_card_class(cls_id: String) -> Dictionary:
	var n_id := normalize_card_class(cls_id)
	return CARD_CLASSES.get(n_id, CARD_CLASSES["NORMAL"])

static func get_edition(ed_id: String) -> Dictionary:
	return get_card_class(ed_id)

static func get_sword_skin(skin_id: String) -> Dictionary:
	for s in SWORD_SKINS:
		if s["id"] == skin_id:
			return s
	return SWORD_SKINS[0]

static func get_alchemy_item(alc_id: String) -> Dictionary:
	for a in ALCHEMY_ITEMS:
		if a["id"] == alc_id:
			return a
	return {}

static func get_ascension_mult(ascension: int) -> float:
	var a := clampi(ascension, 1, MAX_ASCENSION)
	return pow(1.38, float(a - 1))

static func compute_target_score(era_id: String, stage_idx: int, ascension: int, endless_ante: int = 0, difficulty: String = "traveler") -> int:
	var asc_mult := get_ascension_mult(ascension)
	if endless_ante >= 1 or era_id == "endless":
		var ante := maxi(1, endless_ante)
		return int(round(145.0 * pow(1.42, float(ante - 1)) * asc_mult))
	if difficulty == "classic":
		var c_base := float(CLASSIC_BASE_TARGETS.get(era_id, 300))
		var c_mults: Array = CLASSIC_STAGE_MULTS.get(era_id, [])
		var c_st := float(c_mults[stage_idx]) if (stage_idx >= 0 and stage_idx < c_mults.size()) else 1.0
		return int(round(c_base * c_st * asc_mult))
	var base_target := float(ERA_BASE_TARGETS.get(era_id, 120))
	var stages: Array = ERA_STAGES.get(era_id, [])
	var st_mult := 1.0
	if stage_idx >= 0 and stage_idx < stages.size():
		st_mult = float(stages[stage_idx].get("target_mult", 1.0))
	return int(round(base_target * st_mult * asc_mult))

static func get_endless_stage_data(endless_ante: int, ascension: int = 1, lang: String = "en") -> Dictionary:
	var ante := maxi(1, endless_ante)
	var bosses := [
		{"name": "Temporal Archon", "name_cs": "Archont času", "mod": "ENDLESS_TITAN", "desc": "Rival accelerates (+40% score) & demands big Combos!", "desc_cs": "Soupeř zrychluje (+40% bodů) — použij velká komba!"},
		{"name": "Syndicate Phantasm", "name_cs": "Přízrak syndikátu", "mod": "DON_RACKETEER", "desc": "Starts ahead & deals double penalty on Sevens!", "desc_cs": "Začíná s náskokem a dává dvojitý trest za Sedmy!"},
		{"name": "Corsair Spectralis", "name_cs": "Přízrak korzárů", "mod": "PLUNDER", "desc": "Rival Aces/7s steal 12 pts unless blocked by Shields!", "desc_cs": "Soupeřovo Eso či 7 ukradne 12 b., pokud nemáš Štít!"},
		{"name": "Highland Sovereign", "name_cs": "Vládce hor", "mod": "SYNDICATE_CUT", "desc": "Solo plays pay 15% tax; Combos evade all taxes!", "desc_cs": "Sólo tah platí 15% daň; komba jsou bez daně!"},
	]
	var b: Dictionary = bosses[(ante - 1) % bosses.size()]
	var goal := compute_target_score("endless", 0, ascension, ante)
	var b_name := str(b["name_cs"]) if lang == "cs" else str(b["name"])
	var b_desc := str(b["desc_cs"]) if lang == "cs" else str(b["desc"])
	return {
		"stage_idx": ante - 1,
		"endless_ante": ante,
		"stage_name": ("Epocha 6 • Ante %d: %s" if lang == "cs" else "Epoch 6 • Ante %d: %s") % [ante, b_name],
		"boss_mod": str(b["mod"]),
		"boss_desc": b_desc,
		"target_score": goal,
		"gold": 140 + ante * 35,
	}

static func get_default_profile() -> Dictionary:
	return {
		"gold": 200,
		"campaign_difficulty": "traveler",
		"retry_blessing": 0,
		"ascension": 1,
		"highest_ascension": 1,
		"total_wins": 0,
		"best_slam": 0,
		"shop_rerolls": 0,
		"endless_unlocked": false,
		"endless_ante": 0,
		"era_stage": {"antika": 0, "rim": 0, "stredovek": 0, "objavy": 0, "prohibicia": 0},
		"era_cleared": {"antika": false, "rim": false, "stredovek": false, "objavy": false, "prohibicia": false},
		"custom_cards": ["SPEC_VAMPIRE", "SPEC_STORM", "SPEC_PHOENIX", "SPEC_MIDAS"],
		"active_relics": ["REL_GREED", "REL_FANG"],
		"table_relics": ["TRELIC_BLOOD_SEAL", "TRELIC_STAR_BOW"],
		"card_editions": {
			"CERVEN_E": "MAGE",
			"ZELEN_7": "MAGE",
			"ZELEN_8": "KNIGHT",
			"GULA_8": "MERCHANT",
			"CERVEN_7": "THIEF",
		},
		"removed_cards": [],
		"added_cards": [],
		"suit_overrides": {},
		"relic_scales": {"REL_SEVEN_GRIMOIRE": 0.0, "REL_MERCHANT_LEDGER": 0},
		"unlocked_swords": ["SWORD_IRON"],
		"equipped_sword": "SWORD_IRON",
		"unlocked_cards": DEFAULT_UNLOCKED_CARDS.duplicate(),
	}

static func unlock_card(prof: Dictionary, card_key: String) -> bool:
	var ul: Array = prof.get("unlocked_cards", DEFAULT_UNLOCKED_CARDS.duplicate())
	if card_key != "" and not (card_key in ul):
		ul.append(card_key)
		prof["unlocked_cards"] = ul
		return true
	return false

static func get_default_options() -> Dictionary:
	return {
		"language": "en",
		"sfx_volume": 85,
		"muted": false,
		"visual_mode": 3, # 3=Liar's Bar Cinematic PBR, 0=Woodcut, 1=Sepia, 2=Clean
		"high_fx": true,
		"cam_sensitivity": 1.0,
		"game_pace": "relaxed", # "relaxed" (default), "normal", "fast"
		"fullscreen": true,
		"tutorial_done": false,
	}

static func load_options() -> Dictionary:
	var opts := get_default_options()
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS_PATH) != OK:
		return opts
	var l := str(cfg.get_value("general", "language", "en"))
	opts["language"] = l if (l == "en" or l == "cs") else "en"
	opts["sfx_volume"] = clampi(int(cfg.get_value("audio", "sfx_volume", 85)), 0, 100)
	opts["muted"] = bool(cfg.get_value("audio", "muted", false))
	opts["visual_mode"] = clampi(int(cfg.get_value("video", "visual_mode", 3)), 0, 3)
	opts["high_fx"] = bool(cfg.get_value("video", "high_fx", true))
	opts["cam_sensitivity"] = clampf(float(cfg.get_value("controls", "cam_sensitivity", 1.0)), 0.4, 2.2)
	var gp := str(cfg.get_value("general", "game_pace", "relaxed"))
	opts["game_pace"] = gp if (gp in ["relaxed", "normal", "fast"]) else "relaxed"
	opts["fullscreen"] = bool(cfg.get_value("video", "fullscreen", true))
	opts["tutorial_done"] = bool(cfg.get_value("general", "tutorial_done", false))
	return opts

static func save_options(opts: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", str(opts.get("language", "en")))
	cfg.set_value("general", "game_pace", str(opts.get("game_pace", "relaxed")))
	cfg.set_value("general", "tutorial_done", bool(opts.get("tutorial_done", false)))
	cfg.set_value("audio", "sfx_volume", clampi(int(opts.get("sfx_volume", 85)), 0, 100))
	cfg.set_value("audio", "muted", bool(opts.get("muted", false)))
	cfg.set_value("video", "visual_mode", clampi(int(opts.get("visual_mode", 3)), 0, 3))
	cfg.set_value("video", "high_fx", bool(opts.get("high_fx", true)))
	cfg.set_value("video", "fullscreen", bool(opts.get("fullscreen", true)))
	cfg.set_value("controls", "cam_sensitivity", clampf(float(opts.get("cam_sensitivity", 1.0)), 0.4, 2.2))
	cfg.save(OPTIONS_PATH)

static func sanitize_profile(prof: Dictionary) -> Dictionary:
	# Strip archived Power Cards (e.g. SPEC_PRISM) and unknown power card IDs from custom_cards & unlocked_cards
	var raw_cc = prof.get("custom_cards", [])
	var clean_cc: Array = []
	if raw_cc is Array:
		for cid_v in raw_cc:
			var cid := str(cid_v)
			if not (cid in ARCHIVED_CARD_IDS) and not get_power_card(cid).is_empty():
				clean_cc.append(cid)
	prof["custom_cards"] = clean_cc

	var raw_uc = prof.get("unlocked_cards", DEFAULT_UNLOCKED_CARDS.duplicate())
	var clean_uc: Array = []
	if raw_uc is Array:
		for ucid_v in raw_uc:
			var ucid := str(ucid_v)
			if ucid in ARCHIVED_CARD_IDS:
				continue
			if ucid.begins_with("SPEC_") and get_power_card(ucid).is_empty():
				continue
			clean_uc.append(ucid)
	if clean_uc.is_empty():
		clean_uc = DEFAULT_UNLOCKED_CARDS.duplicate()
	prof["unlocked_cards"] = clean_uc

	# Strip archived or temporarily hidden Relics (REL_PRISM_ORB, REL_CHAMOIS, REL_STORMCAP) from active_relics
	var raw_ar = prof.get("active_relics", [])
	var clean_ar: Array = []
	if raw_ar is Array:
		for rid_v in raw_ar:
			var rid := str(rid_v)
			if (rid in ARCHIVED_RELIC_IDS) or is_relic_hidden(rid) or get_relic(rid).is_empty():
				continue
			if not (rid in clean_ar):
				clean_ar.append(rid)
	prof["active_relics"] = clean_ar

	# Sanitize owned active Tabletop Relics (TRELIC_*)
	var raw_tr = prof.get("table_relics", ["TRELIC_BLOOD_SEAL", "TRELIC_STAR_BOW"])
	var clean_tr: Array = []
	if raw_tr is Array:
		for tid_v in raw_tr:
			var tid := str(tid_v)
			if not get_table_relic(tid).is_empty() and not (tid in clean_tr):
				clean_tr.append(tid)
	prof["table_relics"] = clean_tr

	# Strip archived card keys from card_editions
	var raw_ce = prof.get("card_editions", {})
	if raw_ce is Dictionary:
		var clean_ce: Dictionary = {}
		for ck_v in raw_ce.keys():
			var ck := str(ck_v)
			if ck in ARCHIVED_CARD_IDS:
				continue
			clean_ce[ck] = normalize_card_class(str(raw_ce[ck_v]))
		prof["card_editions"] = clean_ce

	prof.erase("prism_pts_bonus")
	return prof

static func load_profile() -> Dictionary:
	var prof := get_default_profile()
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return sanitize_profile(prof)
	prof["gold"] = int(cfg.get_value("run", "gold", prof["gold"]))
	var diff_v := str(cfg.get_value("run", "campaign_difficulty", prof["campaign_difficulty"]))
	prof["campaign_difficulty"] = diff_v if (diff_v == "traveler" or diff_v == "classic") else "traveler"
	prof["retry_blessing"] = clampi(int(cfg.get_value("run", "retry_blessing", 0)), 0, 3)
	prof["ascension"] = clampi(int(cfg.get_value("run", "ascension", 1)), 1, MAX_ASCENSION)
	prof["highest_ascension"] = clampi(int(cfg.get_value("run", "highest_ascension", prof["ascension"])), 1, MAX_ASCENSION)
	prof["total_wins"] = int(cfg.get_value("run", "total_wins", 0))
	prof["best_slam"] = int(cfg.get_value("run", "best_slam", 0))
	prof["shop_rerolls"] = int(cfg.get_value("run", "shop_rerolls", 0))
	prof["endless_unlocked"] = bool(cfg.get_value("run", "endless_unlocked", false))
	prof["endless_ante"] = maxi(0, int(cfg.get_value("run", "endless_ante", 0)))
	var es = cfg.get_value("run", "era_stage", prof["era_stage"])
	if es is Dictionary:
		prof["era_stage"] = es
	var ec = cfg.get_value("run", "era_cleared", prof["era_cleared"])
	if ec is Dictionary:
		prof["era_cleared"] = ec
	var cc = cfg.get_value("deck", "custom_cards", prof["custom_cards"])
	if cc is Array:
		prof["custom_cards"] = cc
	var ar = cfg.get_value("deck", "active_relics", prof["active_relics"])
	if ar is Array:
		prof["active_relics"] = ar
	var tr_saved = cfg.get_value("deck", "table_relics", prof["table_relics"])
	if tr_saved is Array:
		prof["table_relics"] = tr_saved
	var ce = cfg.get_value("deck", "card_editions", prof["card_editions"])
	if ce is Dictionary:
		var norm_ce: Dictionary = {}
		for ck in ce.keys():
			norm_ce[ck] = normalize_card_class(str(ce[ck]))
		prof["card_editions"] = norm_ce
	var rc = cfg.get_value("sculpt", "removed_cards", prof["removed_cards"])
	if rc is Array:
		prof["removed_cards"] = rc
	var ac = cfg.get_value("sculpt", "added_cards", prof["added_cards"])
	if ac is Array:
		prof["added_cards"] = ac
	var so = cfg.get_value("sculpt", "suit_overrides", prof["suit_overrides"])
	if so is Dictionary:
		prof["suit_overrides"] = so
	var rs = cfg.get_value("sculpt", "relic_scales", prof["relic_scales"])
	if rs is Dictionary:
		var merged_rs: Dictionary = prof["relic_scales"].duplicate()
		for k in rs.keys():
			merged_rs[k] = rs[k]
		prof["relic_scales"] = merged_rs
	var us = cfg.get_value("gear", "unlocked_swords", prof["unlocked_swords"])
	if us is Array and not us.is_empty():
		prof["unlocked_swords"] = us
	var eqs = cfg.get_value("gear", "equipped_sword", prof["equipped_sword"])
	if eqs is String and str(eqs) != "":
		prof["equipped_sword"] = eqs
	var uc = cfg.get_value("collection", "unlocked_cards", prof["unlocked_cards"])
	if uc is Array and not uc.is_empty():
		prof["unlocked_cards"] = uc
	return sanitize_profile(prof)

static func save_profile(prof: Dictionary) -> void:
	sanitize_profile(prof)
	var cfg := ConfigFile.new()
	cfg.set_value("run", "gold", int(prof.get("gold", 200)))
	cfg.set_value("run", "campaign_difficulty", str(prof.get("campaign_difficulty", "traveler")))
	cfg.set_value("run", "retry_blessing", clampi(int(prof.get("retry_blessing", 0)), 0, 3))
	cfg.set_value("run", "ascension", clampi(int(prof.get("ascension", 1)), 1, MAX_ASCENSION))
	cfg.set_value("run", "highest_ascension", clampi(int(prof.get("highest_ascension", prof.get("ascension", 1))), 1, MAX_ASCENSION))
	cfg.set_value("run", "total_wins", int(prof.get("total_wins", 0)))
	cfg.set_value("run", "best_slam", int(prof.get("best_slam", 0)))
	cfg.set_value("run", "shop_rerolls", int(prof.get("shop_rerolls", 0)))
	cfg.set_value("run", "endless_unlocked", bool(prof.get("endless_unlocked", false)))
	cfg.set_value("run", "endless_ante", maxi(0, int(prof.get("endless_ante", 0))))
	cfg.set_value("run", "era_stage", prof.get("era_stage", {}))
	cfg.set_value("run", "era_cleared", prof.get("era_cleared", {}))
	cfg.set_value("deck", "custom_cards", prof.get("custom_cards", []))
	cfg.set_value("deck", "active_relics", prof.get("active_relics", []))
	cfg.set_value("deck", "table_relics", prof.get("table_relics", []))
	cfg.set_value("deck", "card_editions", prof.get("card_editions", {}))
	cfg.set_value("sculpt", "removed_cards", prof.get("removed_cards", []))
	cfg.set_value("sculpt", "added_cards", prof.get("added_cards", []))
	cfg.set_value("sculpt", "suit_overrides", prof.get("suit_overrides", {}))
	cfg.set_value("sculpt", "relic_scales", prof.get("relic_scales", {}))
	cfg.set_value("gear", "unlocked_swords", prof.get("unlocked_swords", ["SWORD_IRON"]))
	cfg.set_value("gear", "equipped_sword", str(prof.get("equipped_sword", "SWORD_IRON")))
	cfg.set_value("collection", "unlocked_cards", prof.get("unlocked_cards", DEFAULT_UNLOCKED_CARDS))
	cfg.save(PROFILE_PATH)

static func generate_shop_offers(_prof: Dictionary, lang: String = "en") -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	# Focused 3-Card Campaign Upgrade Selection (1 Power Card + 2 Card Class/Deck Upgrades)
	var pool_pc: Array[Dictionary] = []
	for pc_raw in POWER_CARDS:
		var pid := str(pc_raw.get("id", ""))
		if not (pid in ARCHIVED_CARD_IDS):
			pool_pc.append(pc_raw)
	pool_pc.shuffle()
	var pc0 := get_power_card_loc(str(pool_pc[0]["id"]), lang)
	offers.append({
		"kind": "power_card",
		"id": pc0["id"],
		"title": pc0["name"],
		"sub": pc0["power_line"],
		"desc": pc0["desc"],
		"cost": int(pc0["cost"]),
		"col": pc0["accent"],
		"bought": false,
	})

	# 1 Buyable Active Tabletop Relic (prioritize unowned relics from the 10 TABLE_RELICS!)
	var owned_tr: Array = _prof.get("table_relics", [])
	var pool_tr: Array[Dictionary] = []
	for tr_raw in TABLE_RELICS:
		if not (str(tr_raw["id"]) in owned_tr):
			pool_tr.append(tr_raw)
	if pool_tr.is_empty():
		for tr_raw in TABLE_RELICS:
			pool_tr.append(tr_raw)
	pool_tr.shuffle()
	var tr0 := get_table_relic_loc(str(pool_tr[0]["id"]), lang)
	offers.append({
		"kind": "table_relic",
		"id": tr0["id"],
		"title": ("Relikvie na stůl: " if lang == "cs" else "Tabletop Relic: ") + str(tr0["name"]),
		"sub": tr0["short"],
		"desc": tr0["desc"],
		"cost": int(tr0["cost"]),
		"col": tr0["col"],
		"bought": false,
	})

	var sculpt_infusions: Array[Dictionary] = []
	var sculpt_utils: Array[Dictionary] = []
	for alc in ALCHEMY_ITEMS:
		if str(alc["action"]) == "infuse":
			sculpt_infusions.append(alc)
		else:
			sculpt_utils.append(alc)
	sculpt_infusions.shuffle()
	sculpt_utils.shuffle()
	for alc_raw in [sculpt_infusions[0], sculpt_utils[0]]:
		var alc := get_alchemy_item_loc(str(alc_raw["id"]), lang)
		offers.append({
			"kind": "alchemy",
			"id": alc["id"],
			"action": alc["action"],
			"edition": str(alc.get("edition", "")),
			"title": ("Vylepšení: " if lang == "cs" else "Card Upgrade: ") + str(alc["name"]),
			"sub": alc["sub"],
			"desc": alc["desc"],
			"cost": int(alc["cost"]),
			"col": alc["col"],
			"bought": false,
		})
	var visible_offers: Array[Dictionary] = []
	for off in offers:
		var oid := str(off.get("id", ""))
		if (oid in ARCHIVED_CARD_IDS) or (oid in ARCHIVED_RELIC_IDS) or is_relic_hidden(oid):
			continue
		visible_offers.append(off)
	return visible_offers
