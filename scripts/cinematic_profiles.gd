class_name CinematicProfiles
extends RefCounted

## Expanded Multi-Act Dark-Fantasy Cutscene Profiles for LIALO:
## Covers ALL 15 active Special Cards (5.2s - 6.2s, 5-shot choreography),
## ALL 5 Campaign Era Rivals (4.3s - 4.8s, 4-shot choreography), and
## ALL 5 Era Bosses + Endless Overlord (5.8s - 6.6s, 5-shot grand spectacles).

const PATH_VAMPIRE_CRIMSON := "res://assets/models/vfx/cinematic_vampire_crimson.glb"
const PATH_STORM_TEMPEST := "res://assets/models/vfx/cinematic_storm_tempest.glb"
const PATH_PHOENIX_INFERNO := "res://assets/models/vfx/cinematic_phoenix_inferno.glb"
const PATH_SHADOW_HEX := "res://assets/models/vfx/cinematic_shadow_hex.glb"
const PATH_MIDAS_VAULT := "res://assets/models/vfx/cinematic_midas_vault.glb"
const PATH_RIVAL_SLAM := "res://assets/models/vfx/cinematic_rival_slam.glb"
const PATH_TYBW_GETSUGA := "res://assets/models/vfx/cinematic_tybw_getsuga.glb"
const PATH_TYBW_QUINCY := "res://assets/models/vfx/cinematic_tybw_quincy.glb"

const ALL_VFX_GLB_PATHS := [
	PATH_VAMPIRE_CRIMSON,
	PATH_STORM_TEMPEST,
	PATH_PHOENIX_INFERNO,
	PATH_SHADOW_HEX,
	PATH_MIDAS_VAULT,
	PATH_RIVAL_SLAM,
	PATH_TYBW_GETSUGA,
	PATH_TYBW_QUINCY,
]

const ACTIVE_SPECIAL_CARD_IDS := [
	"SPEC_VAMPIRE",
	"SPEC_STORM",
	"SPEC_MIRROR",
	"SPEC_ALCHEMIST",
	"SPEC_ORACLE",
	"SPEC_PHOENIX",
	"SPEC_MIDAS",
	"SPEC_CHRONOS",
	"SPEC_JESTER",
	"SPEC_HEX",
	"SPEC_MAGNET",
	"SPEC_SHIELD",
	"SPEC_GAMBLER",
	"SPEC_PLAGUE",
	"SPEC_CROWN",
]

const ERA_IDS := [
	"antika",
	"rim",
	"stredovek",
	"objavy",
	"prohibicia",
]

const VALID_POSE_KEYS := [
	"lean_slam",
	"taunt_raise",
	"command_wave",
	"boss_wrath",
	"recoil_stagger",
]


static func _build_5act_special_shots(dur: float, flip_x: float = 1.0) -> Array:
	return [
		# Act I: Low-angle stark aura awakening close-up on the played card
		{"time": 0.00, "pos": Vector3(-0.62 * flip_x, 1.18, 0.72), "look_at": Vector3(0.08, 0.98, -0.04), "fov": 44.0, "trans": "cut", "roll": -3.2 * flip_x},
		# Act II: Dramatic sweeping orbital climb as towering 3D manifestation rises
		{"time": dur * 0.21, "pos": Vector3(0.78 * flip_x, 1.44, 0.36), "look_at": Vector3(0.04, 1.24, -0.26), "fov": 48.0, "trans": "orbit", "roll": 4.2 * flip_x},
		# Act III-A: Razor whip-zoom into climax strike angle right before impact frame
		{"time": dur * 0.48, "pos": Vector3(-0.56 * flip_x, 1.04, 0.42), "look_at": Vector3(0.02, 1.16, -0.68), "fov": 37.0, "trans": "cut", "roll": -5.4 * flip_x},
		# Act III-B: Explosive impact recoil framing Rival getting blown back
		{"time": dur * 0.64, "pos": Vector3(0.46 * flip_x, 1.38, 0.68), "look_at": Vector3(0.00, 1.26, -1.32), "fov": 46.0, "trans": "cut", "roll": 2.4 * flip_x},
		# Act IV: Slow dramatic crane pull-out through drifting spiritual ash
		{"time": dur * 0.80, "pos": Vector3(0.00, 1.62, 1.26), "look_at": Vector3(0.00, 1.10, -0.82), "fov": 56.0, "trans": "cubic", "roll": 0.0},
	]


static func _build_4act_rival_shots(dur: float, flip_x: float = 1.0) -> Array:
	return [
		{"time": 0.00, "pos": Vector3(0.44 * flip_x, 1.24, -0.44), "look_at": Vector3(0.00, 1.38, -1.48), "fov": 39.0, "trans": "cut", "roll": 3.0 * flip_x},
		{"time": dur * 0.28, "pos": Vector3(-0.68 * flip_x, 1.38, 0.16), "look_at": Vector3(0.04, 1.16, -0.74), "fov": 45.0, "trans": "orbit", "roll": -3.6 * flip_x},
		{"time": dur * 0.56, "pos": Vector3(0.56 * flip_x, 1.06, 0.48), "look_at": Vector3(0.08, 0.96, -0.06), "fov": 40.0, "trans": "cut", "roll": 4.2 * flip_x},
		{"time": dur * 0.78, "pos": Vector3(0.00, 1.60, 1.28), "look_at": Vector3(0.00, 1.02, -0.68), "fov": 56.0, "trans": "cubic", "roll": 0.0},
	]


static func _build_5act_boss_shots(dur: float, flip_x: float = 1.0) -> Array:
	return [
		{"time": 0.00, "pos": Vector3(0.38 * flip_x, 1.16, -0.52), "look_at": Vector3(0.00, 1.42, -1.48), "fov": 35.0, "trans": "cut", "roll": 4.0 * flip_x},
		{"time": dur * 0.22, "pos": Vector3(-0.78 * flip_x, 1.48, -0.08), "look_at": Vector3(0.00, 1.30, -1.15), "fov": 46.0, "trans": "orbit", "roll": -4.6 * flip_x},
		{"time": dur * 0.46, "pos": Vector3(0.64 * flip_x, 1.02, 0.36), "look_at": Vector3(0.06, 1.10, -0.18), "fov": 38.0, "trans": "cut", "roll": 5.2 * flip_x},
		{"time": dur * 0.64, "pos": Vector3(-0.52 * flip_x, 1.32, 0.72), "look_at": Vector3(0.04, 1.06, -0.45), "fov": 45.0, "trans": "cut", "roll": -3.2 * flip_x},
		{"time": dur * 0.80, "pos": Vector3(0.00, 1.62, 1.26), "look_at": Vector3(0.00, 1.12, -0.78), "fov": 56.0, "trans": "cubic", "roll": 0.0},
	]


# =============================================================================
# 15 ACTIVE SPECIAL CARD CUTSCENE PROFILES (5.2s - 6.2s, GRAND SCALE)
# =============================================================================
const SPECIAL_CARD_PROFILES := {
	"SPEC_VAMPIRE": {
		"id": "SPEC_VAMPIRE",
		"duration": 5.65,
		"title_en": "VAMPIRE LEECH",
		"title_cs": "UPÍŘÍ PIJAVICE",
		"subtitle_en": "BLOOD SIPHON • CRIMSON BLOOD CRESCENT",
		"subtitle_cs": "KRVAVÝ SRPEK • VYSAJE 15 BODŮ SOUPEŘI",
		"accent_color": Color(0.96, 0.12, 0.22),
		"vfx_glb_path": PATH_TYBW_GETSUGA,
		"tybw_style": "getsuga",
		"vfx_scale": 1.55,
		"light_color": Color(1.0, 0.14, 0.24),
		"light_energy": 8.4,
		"hitstop_at": 3.45,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_STORM": {
		"id": "SPEC_STORM",
		"duration": 5.80,
		"title_en": "THUNDER STRIKE",
		"title_cs": "ÚDER BLESKU",
		"subtitle_en": "ASTRAL VOLLEY • RAIN OF HEAVENLY SPEARS",
		"subtitle_cs": "BOUŘNÁ SALVA • +3 LÍZÁNÍ A +0.8× NÁSOBIČ",
		"accent_color": Color(0.22, 0.90, 1.0),
		"vfx_glb_path": PATH_TYBW_QUINCY,
		"tybw_style": "quincy",
		"vfx_scale": 1.62,
		"light_color": Color(0.32, 0.94, 1.0),
		"light_energy": 8.8,
		"hitstop_at": 3.55,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_MIRROR": {
		"id": "SPEC_MIRROR",
		"duration": 5.35,
		"title_en": "TWIN MIRROR",
		"title_cs": "ZRCADLO OZVĚN",
		"subtitle_en": "KYOKA REFLECTION • SHATTERED ECHO PLAY",
		"subtitle_cs": "ILUZE ZRCADLA • ZOPAKUJE SÍLU MINULÉ KARTY",
		"accent_color": Color(0.76, 0.88, 1.0),
		"vfx_glb_path": PATH_SHADOW_HEX,
		"tybw_style": "quincy",
		"vfx_scale": 1.50,
		"light_color": Color(0.78, 0.90, 1.0),
		"light_energy": 7.6,
		"hitstop_at": 3.25,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_ALCHEMIST": {
		"id": "SPEC_ALCHEMIST",
		"duration": 5.45,
		"title_en": "GOLD TRANSMUTER",
		"title_cs": "ALCHYMISTA",
		"subtitle_en": "IGNIS CRUCIBLE • FORGE HAND & +1 PHIAL",
		"subtitle_cs": "ALCHYMISTICKÝ ŽÁR • POVÝŠÍ KARTU A +1 BAŇKA",
		"accent_color": Color(1.0, 0.76, 0.22),
		"vfx_glb_path": PATH_PHOENIX_INFERNO,
		"tybw_style": "inferno",
		"vfx_scale": 1.52,
		"light_color": Color(1.0, 0.72, 0.24),
		"light_energy": 8.0,
		"hitstop_at": 3.32,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_ORACLE": {
		"id": "SPEC_ORACLE",
		"duration": 5.20,
		"title_en": "SEER'S EYE",
		"title_cs": "OKO VĚŠTCE",
		"subtitle_en": "ALMIGHTY GAZE • UNVEIL EVERY RIVAL CARD",
		"subtitle_cs": "VŠEVIDOUCÍ ZRAK • ODHALÍ VŠECHNY KARTY SOUPEŘE",
		"accent_color": Color(0.38, 0.98, 0.84),
		"vfx_glb_path": PATH_TYBW_QUINCY,
		"tybw_style": "quincy",
		"vfx_scale": 1.48,
		"light_color": Color(0.42, 0.98, 0.84),
		"light_energy": 7.6,
		"hitstop_at": 3.15,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_PHOENIX": {
		"id": "SPEC_PHOENIX",
		"duration": 6.10,
		"title_en": "ASH PHOENIX",
		"title_cs": "FÉNIX Z POPELA",
		"subtitle_en": "ZANKA PYRE • IMMORTAL SUNFIRE PURGE +30",
		"subtitle_cs": "SLUNEČNÍ ŽÁR • SPÁLÍ KLETBU A +30 BODŮ",
		"accent_color": Color(1.0, 0.44, 0.12),
		"vfx_glb_path": PATH_PHOENIX_INFERNO,
		"tybw_style": "inferno",
		"vfx_scale": 1.72,
		"light_color": Color(1.0, 0.50, 0.16),
		"light_energy": 9.2,
		"hitstop_at": 3.72,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_MIDAS": {
		"id": "SPEC_MIDAS",
		"duration": 5.60,
		"title_en": "MIDAS TOUCH",
		"title_cs": "MIDASŮV DOTEK",
		"subtitle_en": "SOVEREIGN VAULT • +14 FLORINS & 2× BELLS",
		"subtitle_cs": "ZLATÝ PALÁC • +14 ZLATÝCH A 2× KOULE",
		"accent_color": Color(1.0, 0.86, 0.20),
		"vfx_glb_path": PATH_MIDAS_VAULT,
		"tybw_style": "sovereign",
		"vfx_scale": 1.56,
		"light_color": Color(1.0, 0.88, 0.28),
		"light_energy": 8.4,
		"hitstop_at": 3.40,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_CHRONOS": {
		"id": "SPEC_CHRONOS",
		"duration": 6.20,
		"title_en": "CHRONOS GLASS",
		"title_cs": "PŘESÝPACÍ HODINY",
		"subtitle_en": "TIME SHATTERED • CLAIM AN IMMEDIATE EXTRA TURN",
		"subtitle_cs": "ZASTAVENÝ ČAS • HRAJEŠ IHNED ZNOVU",
		"accent_color": Color(0.98, 0.88, 0.42),
		"vfx_glb_path": PATH_MIDAS_VAULT,
		"tybw_style": "sovereign",
		"vfx_scale": 1.70,
		"light_color": Color(1.0, 0.92, 0.48),
		"light_energy": 9.0,
		"hitstop_at": 3.78,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_JESTER": {
		"id": "SPEC_JESTER",
		"duration": 5.30,
		"title_en": "TAVERN JESTER",
		"title_cs": "KRČMOVÝ ŠAŠEK",
		"subtitle_en": "SHADOW THEATER • TRIGGER EVERY RELIC TWICE",
		"subtitle_cs": "DIVADLO STÍNŮ • SPUSTÍ VŠECHNY RELIKVIE 2×",
		"accent_color": Color(0.98, 0.28, 0.78),
		"vfx_glb_path": PATH_SHADOW_HEX,
		"tybw_style": "shadow",
		"vfx_scale": 1.52,
		"light_color": Color(1.0, 0.34, 0.84),
		"light_energy": 8.0,
		"hitstop_at": 3.22,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_HEX": {
		"id": "SPEC_HEX",
		"duration": 5.65,
		"title_en": "SHADOW HEX",
		"title_cs": "KLETBA STÍNU",
		"subtitle_en": "KUROHITSUGI SEAL • RIVAL -18 PTS & +15 PTS",
		"subtitle_cs": "ČERNÁ RAKVE KLETBA • SOUPEŘ -18 B. A +15 BODŮ",
		"accent_color": Color(0.68, 0.24, 0.98),
		"vfx_glb_path": PATH_SHADOW_HEX,
		"tybw_style": "shadow",
		"vfx_scale": 1.62,
		"light_color": Color(0.72, 0.28, 1.0),
		"light_energy": 8.4,
		"hitstop_at": 3.46,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_MAGNET": {
		"id": "SPEC_MAGNET",
		"duration": 5.25,
		"title_en": "RUNE MAGNET",
		"title_cs": "RUNOVÝ MAGNET",
		"subtitle_en": "SPIRITUAL PULL • CONJURE 2 MATCHING CARDS",
		"subtitle_cs": "MAGNET RUN • PŘITÁHNE 2 STEJNÉ KARTY",
		"accent_color": Color(0.36, 0.80, 1.0),
		"vfx_glb_path": PATH_STORM_TEMPEST,
		"tybw_style": "quincy",
		"vfx_scale": 1.48,
		"light_color": Color(0.42, 0.84, 1.0),
		"light_energy": 7.8,
		"hitstop_at": 3.18,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_SHIELD": {
		"id": "SPEC_SHIELD",
		"duration": 5.25,
		"title_en": "IRON BASTION",
		"title_cs": "ŽELEZNÁ BAŠTA",
		"subtitle_en": "BLUT VENE AEGIS • +2 REFLECT SHIELDS",
		"subtitle_cs": "OCELOVÁ BAŠTA • +2 ODRAZOVÉ ŠTÍTY",
		"accent_color": Color(0.62, 0.84, 1.0),
		"vfx_glb_path": PATH_TYBW_QUINCY,
		"tybw_style": "quincy",
		"vfx_scale": 1.50,
		"light_color": Color(0.70, 0.88, 1.0),
		"light_energy": 7.8,
		"hitstop_at": 3.20,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_GAMBLER": {
		"id": "SPEC_GAMBLER",
		"duration": 5.45,
		"title_en": "LOADED DICE",
		"title_cs": "CINKNUTÉ KOSTKY",
		"subtitle_en": "FATE'S BALANCE • ×1.5 / ×2.0 / ×3.5 SURGE",
		"subtitle_cs": "VÁHY OSUDU • NÁSOBIČ ×1.5, ×2.0 NEBO ×3.5",
		"accent_color": Color(1.0, 0.62, 0.18),
		"vfx_glb_path": PATH_MIDAS_VAULT,
		"tybw_style": "sovereign",
		"vfx_scale": 1.54,
		"light_color": Color(1.0, 0.68, 0.22),
		"light_energy": 8.2,
		"hitstop_at": 3.34,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_PLAGUE": {
		"id": "SPEC_PLAGUE",
		"duration": 5.65,
		"title_en": "FROST BLIGHT",
		"title_cs": "MRAZIVÁ ZHOUBA",
		"subtitle_en": "ABSOLUTE ZERO • FREEZE RIVAL & -14 PTS",
		"subtitle_cs": "ABSOLUTNÍ NULA • ZMRAZÍ SOUPEŘE A -14 BODŮ",
		"accent_color": Color(0.32, 0.94, 1.0),
		"vfx_glb_path": PATH_STORM_TEMPEST,
		"tybw_style": "quincy",
		"vfx_scale": 1.60,
		"light_color": Color(0.38, 0.96, 1.0),
		"light_energy": 8.5,
		"hitstop_at": 3.45,
		"opponent_pose_key": "recoil_stagger",
	},
	"SPEC_CROWN": {
		"id": "SPEC_CROWN",
		"duration": 5.95,
		"title_en": "ROYAL DECREE",
		"title_cs": "KRÁLOVSKÝ GLEJT",
		"subtitle_en": "SOUL KING EDICT • +20 PTS PER COURT CARD",
		"subtitle_cs": "KRÁLOVSKÁ PEČEŤ • +20 BODŮ ZA KAŽDOU FIGURU",
		"accent_color": Color(1.0, 0.86, 0.26),
		"vfx_glb_path": PATH_TYBW_GETSUGA,
		"tybw_style": "getsuga",
		"vfx_scale": 1.68,
		"light_color": Color(1.0, 0.88, 0.32),
		"light_energy": 8.8,
		"hitstop_at": 3.64,
		"opponent_pose_key": "recoil_stagger",
	},
}

# =============================================================================
# 5 CAMPAIGN ERA RIVAL CUTSCENE PROFILES (4.3s - 4.7s) + GENERIC/ENDLESS
# =============================================================================
const RIVAL_ERA_PROFILES := {
	"antika": {
		"id": "rival_antika",
		"era_id": "antika",
		"is_boss": false,
		"duration": 4.40,
		"title_en": "ANCIENT KEEPER'S EDICT",
		"title_cs": "TAH STRÁŽCE ANTIKY",
		"subtitle_en": "SACRED TEMPLE STRIKE",
		"subtitle_cs": "ÚDER CHRÁMOVÉHO PÍSAŘE",
		"accent_color": Color(1.0, 0.78, 0.24),
		"vfx_glb_path": PATH_RIVAL_SLAM,
		"tybw_style": "sovereign",
		"vfx_scale": 1.42,
		"light_color": Color(1.0, 0.80, 0.28),
		"light_energy": 7.2,
		"hitstop_at": 2.62,
		"opponent_pose_key": "command_wave",
	},
	"rim": {
		"id": "rival_rim",
		"era_id": "rim",
		"is_boss": false,
		"duration": 4.50,
		"title_en": "LEGIONARY ASSAULT",
		"title_cs": "ÚTOK ŘÍMSKÉ LEGIE",
		"subtitle_en": "IRON GLADIUS CLEAVE",
		"subtitle_cs": "ÚDER ARÉNOVÉHO CENTURIONA",
		"accent_color": Color(0.98, 0.26, 0.20),
		"vfx_glb_path": PATH_TYBW_GETSUGA,
		"tybw_style": "getsuga",
		"vfx_scale": 1.45,
		"light_color": Color(1.0, 0.30, 0.22),
		"light_energy": 7.5,
		"hitstop_at": 2.68,
		"opponent_pose_key": "lean_slam",
	},
	"stredovek": {
		"id": "rival_stredovek",
		"era_id": "stredovek",
		"is_boss": false,
		"duration": 4.50,
		"title_en": "CHIVALRIC GAUNTLET",
		"title_cs": "RYTÍŘSKÁ VÝZVA",
		"subtitle_en": "FORGED STEEL JOUST SLAM",
		"subtitle_cs": "ÚDER ŽELEZNÉ RUKAVICE",
		"accent_color": Color(1.0, 0.64, 0.20),
		"vfx_glb_path": PATH_RIVAL_SLAM,
		"tybw_style": "getsuga",
		"vfx_scale": 1.45,
		"light_color": Color(1.0, 0.68, 0.24),
		"light_energy": 7.4,
		"hitstop_at": 2.68,
		"opponent_pose_key": "lean_slam",
	},
	"objavy": {
		"id": "rival_objavy",
		"era_id": "objavy",
		"is_boss": false,
		"duration": 4.60,
		"title_en": "CORSAIR BROADSIDE",
		"title_cs": "KORZÁRSKÁ SALVA",
		"subtitle_en": "HIGH-SEAS TEMPEST BARRAGE",
		"subtitle_cs": "ÚDER MOŘSKÉHO NAVIGÁTORA",
		"accent_color": Color(0.24, 0.90, 1.0),
		"vfx_glb_path": PATH_STORM_TEMPEST,
		"tybw_style": "quincy",
		"vfx_scale": 1.48,
		"light_color": Color(0.32, 0.92, 1.0),
		"light_energy": 7.6,
		"hitstop_at": 2.74,
		"opponent_pose_key": "taunt_raise",
	},
	"prohibicia": {
		"id": "rival_prohibicia",
		"era_id": "prohibicia",
		"is_boss": false,
		"duration": 4.65,
		"title_en": "SYNDICATE SHAKEDOWN",
		"title_cs": "ZÁTAH SYNDIKÁTU",
		"subtitle_en": "SPEAKEASY ENFORCER STRIKE",
		"subtitle_cs": "VÝPALNÉ ČERNÉHO BARU",
		"accent_color": Color(0.86, 0.30, 1.0),
		"vfx_glb_path": PATH_SHADOW_HEX,
		"tybw_style": "shadow",
		"vfx_scale": 1.50,
		"light_color": Color(0.88, 0.38, 1.0),
		"light_energy": 7.8,
		"hitstop_at": 2.78,
		"opponent_pose_key": "taunt_raise",
	},
	"generic": {
		"id": "rival_generic",
		"era_id": "generic",
		"is_boss": false,
		"duration": 4.35,
		"title_en": "RIVAL'S GAMBIT",
		"title_cs": "TAH SOUPEŘE",
		"subtitle_en": "TAVERN DUEL STRIKE",
		"subtitle_cs": "ÚDER NA HRACÍ STŮL",
		"accent_color": Color(1.0, 0.66, 0.22),
		"vfx_glb_path": PATH_RIVAL_SLAM,
		"tybw_style": "getsuga",
		"vfx_scale": 1.42,
		"light_color": Color(1.0, 0.68, 0.24),
		"light_energy": 7.2,
		"hitstop_at": 2.58,
		"opponent_pose_key": "lean_slam",
	},
}

# =============================================================================
# 5 CAMPAIGN ERA BOSS CUTSCENE PROFILES (5.9s - 6.6s) + GENERIC/ENDLESS BOSS
# =============================================================================
const BOSS_ERA_PROFILES := {
	"antika": {
		"id": "boss_antika",
		"era_id": "antika",
		"is_boss": true,
		"duration": 6.00,
		"title_en": "PHARAOH RAMESSES • SOLAR WRATH",
		"title_cs": "FARAON RAMESSE • SLUNEČNÍ HNĚV",
		"subtitle_en": "PHARAOH'S SEAL • BOW BEFORE THE DYNASTY",
		"subtitle_cs": "FARAONOVA PEČEŤ • POKLEKNI PŘED DYNASTIÍ",
		"accent_color": Color(1.0, 0.84, 0.20),
		"vfx_glb_path": PATH_MIDAS_VAULT,
		"tybw_style": "sovereign",
		"vfx_scale": 1.75,
		"light_color": Color(1.0, 0.84, 0.26),
		"light_energy": 9.2,
		"hitstop_at": 3.68,
		"opponent_pose_key": "boss_wrath",
	},
	"rim": {
		"id": "boss_rim",
		"era_id": "rim",
		"is_boss": true,
		"duration": 6.15,
		"title_en": "JULIUS CAESAR • IMPERIAL DECREE",
		"title_cs": "JULIUS CAESAR • CÍSAŘSKÝ ROZKAZ",
		"subtitle_en": "CAESAR'S TRIBUTE • THE DIE IS CAST",
		"subtitle_cs": "CAESAROVA DAŇ • KOSTKY JSOU VRŽENY",
		"accent_color": Color(1.0, 0.18, 0.18),
		"vfx_glb_path": PATH_TYBW_GETSUGA,
		"tybw_style": "getsuga",
		"vfx_scale": 1.80,
		"light_color": Color(1.0, 0.22, 0.20),
		"light_energy": 9.4,
		"hitstop_at": 3.76,
		"opponent_pose_key": "boss_wrath",
	},
	"stredovek": {
		"id": "boss_stredovek",
		"era_id": "stredovek",
		"is_boss": true,
		"duration": 6.25,
		"title_en": "KING CHARLES IV • CROWN EDICT",
		"title_cs": "KRÁL KAREL IV. • KORUNNÍ VÝNOS",
		"subtitle_en": "SOVEREIGN JUDGMENT • BY ROYAL CHARTER",
		"subtitle_cs": "ZLATÁ BULA • JMÉNEM KORUNY ČESKÉ",
		"accent_color": Color(1.0, 0.82, 0.22),
		"vfx_glb_path": PATH_MIDAS_VAULT,
		"tybw_style": "sovereign",
		"vfx_scale": 1.80,
		"light_color": Color(1.0, 0.84, 0.28),
		"light_energy": 9.6,
		"hitstop_at": 3.82,
		"opponent_pose_key": "boss_wrath",
	},
	"objavy": {
		"id": "boss_objavy",
		"era_id": "objavy",
		"is_boss": true,
		"duration": 6.20,
		"title_en": "PIRATE QUEEN ANNE • BLACK SPOT",
		"title_cs": "PIRÁTSKÁ KRÁLOVNA • ČERNÁ ZNÁMKA",
		"subtitle_en": "HIGH-SEAS VOLLEY • NO QUARTER GIVEN",
		"subtitle_cs": "KRVAVÁ KOŘIST • ŽÁDNÉ SLITOVÁNÍ",
		"accent_color": Color(0.20, 0.94, 0.92),
		"vfx_glb_path": PATH_TYBW_QUINCY,
		"tybw_style": "quincy",
		"vfx_scale": 1.80,
		"light_color": Color(0.24, 0.96, 0.94),
		"light_energy": 9.5,
		"hitstop_at": 3.80,
		"opponent_pose_key": "boss_wrath",
	},
	"prohibicia": {
		"id": "boss_prohibicia",
		"era_id": "prohibicia",
		"is_boss": true,
		"duration": 6.55,
		"title_en": "AL CAPONE • DON'S VENDETTA",
		"title_cs": "AL CAPONE • VENDETA SYNDIKÁTU",
		"subtitle_en": "FINAL BOSS WRATH • THE HOUSE ALWAYS COLLECTS",
		"subtitle_cs": "HLAVNÍ BOSS • SYNDIKÁT SI BERE VŠE",
		"accent_color": Color(0.98, 0.16, 0.30),
		"vfx_glb_path": PATH_TYBW_GETSUGA,
		"tybw_style": "getsuga",
		"vfx_scale": 1.88,
		"light_color": Color(1.0, 0.22, 0.34),
		"light_energy": 10.0,
		"hitstop_at": 4.02,
		"opponent_pose_key": "boss_wrath",
	},
	"generic": {
		"id": "boss_generic",
		"era_id": "generic",
		"is_boss": true,
		"duration": 6.10,
		"title_en": "ARCH-SOVEREIGN • ABYSSAL DECREE",
		"title_cs": "VLÁDCE PROPASTI • TEMNÝ VÝNOS",
		"subtitle_en": "ENDLESS EPOCH OVERLORD",
		"subtitle_cs": "NEKONEČNÁ EPOCHA • DRTIVÝ ÚDER",
		"accent_color": Color(1.0, 0.42, 0.18),
		"vfx_glb_path": PATH_TYBW_GETSUGA,
		"tybw_style": "getsuga",
		"vfx_scale": 1.78,
		"light_color": Color(1.0, 0.46, 0.22),
		"light_energy": 9.2,
		"hitstop_at": 3.74,
		"opponent_pose_key": "boss_wrath",
	},
}


static func get_special_card_profile(card_id: String) -> Dictionary:
	var key := card_id.strip_edges().to_upper()
	var base: Dictionary = SPECIAL_CARD_PROFILES[key] if SPECIAL_CARD_PROFILES.has(key) else SPECIAL_CARD_PROFILES["SPEC_CROWN"]
	var prof := base.duplicate(true)
	if not SPECIAL_CARD_PROFILES.has(key) and key != "":
		prof["id"] = key
	if not prof.has("camera_shots"):
		var flip := -1.0 if (key.hash() % 2 == 0) else 1.0
		prof["camera_shots"] = _build_5act_special_shots(float(prof.get("duration", 5.6)), flip)
	return prof


static func get_rival_turn_profile(era_id: String, is_boss: bool = false) -> Dictionary:
	var e := era_id.strip_edges().to_lower()
	if e == "endless" or e == "":
		e = "generic"
	var table: Dictionary = BOSS_ERA_PROFILES if is_boss else RIVAL_ERA_PROFILES
	var base: Dictionary = table[e] if table.has(e) else table["generic"]
	var prof := base.duplicate(true)
	if not prof.has("camera_shots"):
		var flip := -1.0 if (e == "rim" or e == "objavy") else 1.0
		var dur := float(prof.get("duration", 6.0 if is_boss else 4.5))
		prof["camera_shots"] = _build_5act_boss_shots(dur, flip) if is_boss else _build_4act_rival_shots(dur, flip)
	return prof


static func has_special_card_profile(card_id: String) -> bool:
	return SPECIAL_CARD_PROFILES.has(card_id.strip_edges().to_upper())


static func get_all_active_special_card_ids() -> PackedStringArray:
	return PackedStringArray(ACTIVE_SPECIAL_CARD_IDS)


static func get_all_era_ids() -> PackedStringArray:
	return PackedStringArray(ERA_IDS)
