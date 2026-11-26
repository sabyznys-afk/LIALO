class_name PowerCardVfxShowcase
extends Node3D

## Hand-Drawn Woodcut-Ink 4.2s 1st-Person POV Epic Power Card Animations for LIALO.
## Supports 4 flagship cards:
##  - SPEC_STORM   ("THUNDER STRIKE!" / "+3 RIVAL DRAW • ×1.5 SURGE")
##  - SPEC_VAMPIRE ("VAMPIRE LEECH!" / "DRAIN 15 PTS • CRIMSON SIPHON")
##  - SPEC_PHOENIX ("ASH PHOENIX!" / "CURSE CLEARED • +30 BURN")
##  - SPEC_CHRONOS ("CHRONOS GLASS!" / "TIME FROZEN • EXTRA TURN!")
## Dual-mode:
##  - setup_fpv_preview(cam, overlay, loop, card_id)
##  - setup_battle_fx(impact_pos, rival_pos, card_id)

signal sfx_triggered(sfx_key: String, vol_db: float, pitch: float)
signal sequence_finished()

const Toon := preload("res://scripts/toon_style.gd")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const SHADER_CEL := preload("res://shaders/sword_cel_sprite.gdshader")
const SHADER_BLADE := preload("res://shaders/sword_blade_cutout.gdshader")
const SHADER_LIVING_25D := preload("res://shaders/power_25d_living.gdshader")

const DURATION: float = 4.20
const CARD_BACK_TEX := "res://assets/table/deck_back_klasic.png"
const WOOD_TEX := "res://assets/table/wood.png"
const OPP_MODEL_PATH := "res://assets/models/opp_stredovek.glb"
const FONT_DISP_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoBody.ttf"
const TEX_SLASH_SHEET := "res://assets/vfx/sword_card/slash_cel_sheet.png"
const TEX_MIST_SHEET := "res://assets/vfx/sword_card/mist_veil_sheet.png"
const TEX_IMPACT_SHEET := "res://assets/vfx/sword_card/impact_sigil_sheet.png"
const TEX_INK_SPARKS_SHEET := "res://assets/vfx/sword_card/ink_sparks_sheet.png"
const TEX_PHOENIX_25D := "res://assets/vfx/power_25d/phoenix_hero_2d.png"
const TEX_MIRROR_25D := "res://assets/vfx/power_25d/mirror_gate_2d.png"
const TEX_VAMPIRE_CHALICE_25D := "res://assets/vfx/power_25d/vampire_chalice_clean_2d.png"
const TEX_VAMPIRE_ECLIPSE_RING_25D := "res://assets/vfx/power_25d/vampire_eclipse_ring_2d.png"
const TEX_GOTHIC_BAT_25D := "res://assets/vfx/power_25d/gothic_bat_2d.png"
const TEX_STORM_25D := "res://assets/vfx/power_25d/storm_tempest_2d.png"
const TEX_STORM_SPARK_25D := "res://assets/vfx/power_25d/storm_lightning_spark_2d.png"
const TEX_PHOENIX_FEATHER_25D := "res://assets/vfx/power_25d/phoenix_feather_2d.png"
const TEX_MIRROR_SHARD_25D := "res://assets/vfx/power_25d/mirror_shard_2d.png"
const TEX_MIDAS_25D := "res://assets/vfx/power_25d/midas_gauntlet_2d.png"
const TEX_GOLD_FLORIN_25D := "res://assets/vfx/power_25d/gold_florin_2d.png"
const TEX_CHRONOS_25D := "res://assets/vfx/power_25d/chronos_astrolabe_2d.png"
const TEX_CHRONOS_RING_25D := "res://assets/vfx/power_25d/chronos_gear_ring_2d.png"
const TEX_ORACLE_25D := "res://assets/vfx/power_25d/oracle_eye_2d.png"
const TEX_JESTER_25D := "res://assets/vfx/power_25d/jester_mask_2d.png"
const TEX_JESTER_CARD_25D := "res://assets/vfx/power_25d/jester_card_2d.png"
const TEX_HEX_25D := "res://assets/vfx/power_25d/hex_grimoire_2d.png"
const TEX_HEX_THORN_25D := "res://assets/vfx/power_25d/hex_thorn_2d.png"
const TEX_MAGNET_25D := "res://assets/vfx/power_25d/magnet_sigil_2d.png"
const TEX_SHIELD_25D := "res://assets/vfx/power_25d/bastion_shield_2d.png"
const TEX_GAMBLER_WHEEL_25D := "res://assets/vfx/power_25d/gambler_wheel_2d.png"
const TEX_GAMBLER_DICE_25D := "res://assets/vfx/power_25d/gambler_dice_2d.png"
const TEX_PLAGUE_25D := "res://assets/vfx/power_25d/plague_frost_2d.png"
const TEX_FROST_CRYSTAL_25D := "res://assets/vfx/power_25d/frost_crystal_2d.png"
const TEX_CROWN_25D := "res://assets/vfx/power_25d/sovereign_crown_2d.png"

const CARD_META := {
	"SPEC_STORM": {
		"tex": "res://assets/cards/SPEC_STORM.png",
		"accent": Color(0.32, 0.92, 1.0),
		"title": "THUNDER STRIKE!",
		"sub": "+3 RIVAL DRAW  •  ×1.5 COMBO SURGE",
	},
	"SPEC_VAMPIRE": {
		"tex": "res://assets/cards/SPEC_VAMPIRE.png",
		"accent": Color(0.95, 0.14, 0.24),
		"title": "VAMPIRE LEECH!",
		"sub": "DRAIN 15 PTS  •  CRIMSON SIPHON",
	},
	"SPEC_PHOENIX": {
		"tex": "res://assets/cards/SPEC_PHOENIX.png",
		"accent": Color(1.0, 0.48, 0.14),
		"title": "ASH PHOENIX!",
		"sub": "CURSE CLEARED  •  +30 BURN",
	},
	"SPEC_CHRONOS": {
		"tex": "res://assets/cards/SPEC_CHRONOS.png",
		"accent": Color(0.98, 0.84, 0.34),
		"title": "CHRONOS GLASS!",
		"sub": "TIME FROZEN  •  EXTRA TURN!",
	},
	"SPEC_MIRROR": {
		"tex": "res://assets/cards/SPEC_MIRROR.png",
		"accent": Color(0.56, 0.90, 1.0),
		"title": "MIRROR GATE!",
		"sub": "DUPLICATE & REFLECT CARD",
	},
	"SPEC_ALCHEMIST": {
		"tex": "res://assets/cards/SPEC_ALCHEMIST.png",
		"accent": Color(0.54, 0.96, 0.42),
		"title": "ALCHEMIST'S CRUCIBLE!",
		"sub": "TRANSMUTE  •  +GOLD & ×MULT",
	},
	"SPEC_ORACLE": {
		"tex": "res://assets/cards/SPEC_ORACLE.png",
		"accent": Color(0.76, 0.56, 1.0),
		"title": "ALL-SEEING ORACLE!",
		"sub": "RIVAL HAND REVEALED!",
	},
	"SPEC_MIDAS": {
		"tex": "res://assets/cards/SPEC_MIDAS.png",
		"accent": Color(1.0, 0.84, 0.24),
		"title": "MIDAS TOUCH!",
		"sub": "GOLDEN CASCADE  •  +FLORINS",
	},
	"SPEC_JESTER": {
		"tex": "res://assets/cards/SPEC_JESTER.png",
		"accent": Color(0.96, 0.48, 0.94),
		"title": "FOOL'S GAMBIT!",
		"sub": "CHAOS VORTEX  •  RELIC SURGE",
	},
	"SPEC_HEX": {
		"tex": "res://assets/cards/SPEC_HEX.png",
		"accent": Color(0.64, 0.30, 0.96),
		"title": "SHADOW HEX!",
		"sub": "CURSED CHAINS  •  RIVAL DRAIN",
	},
	"SPEC_MAGNET": {
		"tex": "res://assets/cards/SPEC_MAGNET.png",
		"accent": Color(0.94, 0.34, 0.38),
		"title": "ARCANE MAGNET!",
		"sub": "PULL MATCHING CARDS!",
	},
	"SPEC_SHIELD": {
		"tex": "res://assets/cards/SPEC_SHIELD.png",
		"accent": Color(0.50, 0.90, 1.0),
		"title": "IRON BASTION!",
		"sub": "FORGE AEGIS  •  +2 SHIELDS",
	},
	"SPEC_GAMBLER": {
		"tex": "res://assets/cards/SPEC_GAMBLER.png",
		"accent": Color(1.0, 0.78, 0.28),
		"title": "LOADED FATE!",
		"sub": "GOLDEN DICE  •  ×2 / ×3 MULT",
	},
	"SPEC_PLAGUE": {
		"tex": "res://assets/cards/SPEC_PLAGUE.png",
		"accent": Color(0.42, 0.94, 0.72),
		"title": "FROST PLAGUE!",
		"sub": "BLIZZARD FREEZE  •  STUNNED!",
	},
	"SPEC_CROWN": {
		"tex": "res://assets/cards/SPEC_CROWN.png",
		"accent": Color(1.0, 0.88, 0.36),
		"title": "SOVEREIGN'S DECREE!",
		"sub": "ROYAL HALO  •  COURT SURGE",
	},
}

var _mode: String = "fpv_preview"
var _card_id: String = "SPEC_STORM"
var _accent: Color = Color(0.32, 0.92, 1.0)
var _t: float = 0.0
var _playing: bool = true
var _loop: bool = true
var _speed: float = 1.0
var _is_headless: bool = false

var _impact_pos: Vector3 = Vector3(0.0, 0.82, 0.0)
var _rival_pos: Vector3 = Vector3(0.0, 1.15, -1.16)
var _hand_pos: Vector3 = Vector3(0.0, 1.04, 0.72)

var _cam: Camera3D = null
var _cam_base_pos: Vector3 = Vector3(0.0, 1.56, 1.24)
var _cam_base_look: Vector3 = Vector3(0.0, 0.94, -0.42)
var _cam_base_fov: float = 54.0

var _overlay: Control = null
var _font_disp: Font = null
var _font_body: Font = null
var _rng := RandomNumberGenerator.new()
var _beats_fired: Dictionary = {}
var _bolt_rebuild_acc: float = 0.0
var _finished_emitted: bool = false
var _with_stinger: bool = true

# Preview Stage Nodes
var _stage_root: Node3D = null
var _warm_light: OmniLight3D = null
var _fx_light: OmniLight3D = null
var _rival_root: Node3D = null
var _rival_base_pos: Vector3 = Vector3(0.0, 0.80, -1.24)
var _rival_eye_mats: Array[StandardMaterial3D] = []
var _hand_fan_root: Node3D = null

# Shared Card + Hand-Drawn 2.5D Cel Seals & Hero Cutout Diorama
var _fx_root: Node3D = null
var _hero_card: Node3D = null
var _card_orbit_rings: Array[MeshInstance3D] = []
var _rune_seal_root: Node3D = null
var _rune_seal_mat: StandardMaterial3D = null
var _seal_cel_outer: MeshInstance3D = null
var _seal_cel_outer_mat: ShaderMaterial = null
var _seal_cel_mist: MeshInstance3D = null
var _seal_cel_mist_mat: ShaderMaterial = null
var _hero_25d_root: Node3D = null
var _hero_25d_mat: ShaderMaterial = null
var _hero_25d_shadow_mat: ShaderMaterial = null
var _extra_25d_mats: Array[Dictionary] = []
var _vampire_eclipse_ring: Node3D = null
var _vampire_eclipse_mat: ShaderMaterial = null
var _vampire_eclipse_shadow_mat: ShaderMaterial = null
var _cel_slash_a: MeshInstance3D = null
var _cel_slash_a_mat: ShaderMaterial = null
var _cel_slash_b: MeshInstance3D = null
var _cel_slash_b_mat: ShaderMaterial = null
var _alc_mist_rings: Array[Dictionary] = []
var _shock_rings: Array[Dictionary] = []

# SPEC_STORM Nodes
var _vortex_root: Node3D = null
var _vortex_layers: Array[MeshInstance3D] = []
var _pillar_root: Node3D = null
var _pillar_core_mat: StandardMaterial3D = null
var _pillar_sheath_mat: StandardMaterial3D = null
var _bolts_mesh: ImmediateMesh = null
var _bolts_mesh_inst: MeshInstance3D = null
var _sparks: Array[Dictionary] = []
var _curse_cards: Array[Dictionary] = []

# SPEC_VAMPIRE Nodes
var _blood_moon_mesh: MeshInstance3D = null
var _bats: Array[Dictionary] = []
var _crescent_slash: Node3D = null
var _siphon_orbs: Array[Dictionary] = []
var _siphon_ribbons_mesh: ImmediateMesh = null
var _siphon_ribbons_inst: MeshInstance3D = null

# SPEC_PHOENIX Nodes
var _curse_chains: Array[Dictionary] = []
var _phoenix_bird_root: Node3D = null
var _phoenix_wing_l: Node3D = null
var _phoenix_wing_r: Node3D = null
var _feathers: Array[Dictionary] = []
var _flame_pillar: MeshInstance3D = null
var _flame_pillar_mat: StandardMaterial3D = null

# SPEC_CHRONOS Nodes
var _astrolabe_root: Node3D = null
var _astro_gears: Array[Node3D] = []
var _clock_hand_min: Node3D = null
var _clock_hand_hr: Node3D = null
var _glass_shards: Array[Dictionary] = []

# Shared Hybrid 2.5D Rig Nodes for the 11 Power Cards (Mirror..Crown)
var _hybrid_stage_root: Node3D = null
var _hybrid_spinners: Array[Dictionary] = []
var _hybrid_motes: Array[Dictionary] = []
var _hybrid_pillars: Array[MeshInstance3D] = []


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	_rng.randomize()
	_font_disp = load(FONT_DISP_PATH) as Font if ResourceLoader.exists(FONT_DISP_PATH) else ThemeDB.fallback_font
	_font_body = load(FONT_BODY_PATH) as Font if ResourceLoader.exists(FONT_BODY_PATH) else ThemeDB.fallback_font


func _exit_tree() -> void:
	if is_instance_valid(_overlay):
		if _overlay.draw.is_connected(_draw_overlay):
			_overlay.draw.disconnect(_draw_overlay)
		_overlay.queue_redraw()


func setup_fpv_preview(cam: Camera3D, overlay_ctrl: Control, loop_enabled: bool = true, card_id: String = "SPEC_STORM") -> void:
	_mode = "fpv_preview"
	_with_stinger = true
	_card_id = card_id if CARD_META.has(card_id) else "SPEC_STORM"
	var meta: Dictionary = CARD_META[_card_id]
	_accent = meta["accent"] as Color
	_cam = cam
	_overlay = overlay_ctrl
	_loop = loop_enabled
	_impact_pos = Vector3(0.0, 0.816, 0.0)
	_rival_pos = Vector3(0.0, 1.15, -1.16)
	_hand_pos = Vector3(0.0, 1.05, 0.72)

	if is_instance_valid(_overlay) and not _overlay.draw.is_connected(_draw_overlay):
		_overlay.draw.connect(_draw_overlay)

	_build_fpv_stage()
	_build_fx_rig()
	restart()


func _get_duration() -> float:
	if _card_id in ["SPEC_VAMPIRE", "SPEC_STORM"]:
		return 6.00
	if _card_id in ["SPEC_MIRROR", "SPEC_ALCHEMIST"]:
		return 5.80
	return DURATION


func setup_battle_fx(impact_pos: Vector3, rival_pos: Vector3, card_id: String = "SPEC_STORM", with_stinger: bool = false, cam_override: Camera3D = null, overlay_override: Control = null) -> void:
	_mode = "battle_fx"
	_with_stinger = with_stinger
	_card_id = card_id if CARD_META.has(card_id) else "SPEC_STORM"
	var meta: Dictionary = CARD_META[_card_id]
	_accent = meta["accent"] as Color
	_loop = false
	var vp := get_viewport()
	_cam = cam_override if is_instance_valid(cam_override) else (vp.get_camera_3d() if vp != null else null)
	if is_instance_valid(_cam):
		_cam_base_pos = _cam.global_position
		_cam_base_fov = _cam.fov
	_overlay = overlay_override
	if is_instance_valid(_overlay) and not _overlay.draw.is_connected(_draw_overlay):
		_overlay.draw.connect(_draw_overlay)
	_impact_pos = impact_pos
	_rival_pos = rival_pos
	_hand_pos = impact_pos + Vector3(0.0, 0.24, 0.70)
	_build_fx_rig()
	restart()


func set_playing(p: bool) -> void:
	_playing = p


func set_loop(l: bool) -> void:
	_loop = l


func set_speed(s: float) -> void:
	_speed = clampf(s, 0.1, 4.0)


func restart() -> void:
	_t = 0.0
	_bolt_rebuild_acc = 0.0
	_beats_fired.clear()
	_finished_emitted = false
	_apply_animation_state(0.0)
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _apply_ink_outline(node: Node, thickness: float = 0.012, col: Color = Color(0.03, 0.02, 0.02, 1.0)) -> void:
	var out_mat := ShaderMaterial.new()
	out_mat.shader = OUTLINE_SHADER
	out_mat.set_shader_parameter("thickness", thickness)
	out_mat.set_shader_parameter("outline_color", col)
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var mat := mi.material_override as Material
			if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var sm := mi.mesh.surface_get_material(0)
				if sm != null:
					mat = sm.duplicate()
					mi.material_override = mat
			if mat != null:
				mat.next_pass = out_mat
		for ch in cur.get_children():
			stack.append(ch)


func _build_fpv_stage() -> void:
	if is_instance_valid(_stage_root):
		_stage_root.queue_free()
	_stage_root = Node3D.new()
	_stage_root.name = "FpvTavernStage"
	add_child(_stage_root)

	var wood_mat := Toon.pbr(Color(0.32, 0.20, 0.12), WOOD_TEX, 0.65, 0.04, Vector2(2.6, 2.6))
	var tbl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.42
	cyl.bottom_radius = 1.38
	cyl.height = 0.14
	cyl.radial_segments = 48
	tbl.mesh = cyl
	tbl.position = Vector3(0.0, 0.73, 0.0)
	tbl.material_override = wood_mat
	_stage_root.add_child(tbl)

	var brass_mat := Toon.pbr(Color(0.84, 0.64, 0.24), "", 0.28, 0.88)
	var inlay := MeshInstance3D.new()
	var t_inlay := TorusMesh.new()
	t_inlay.inner_radius = 1.24
	t_inlay.outer_radius = 1.27
	t_inlay.rings = 48
	t_inlay.ring_segments = 12
	inlay.mesh = t_inlay
	inlay.position = Vector3(0.0, 0.802, 0.0)
	inlay.material_override = brass_mat
	_stage_root.add_child(inlay)

	var disc_ring := MeshInstance3D.new()
	var t_disc := TorusMesh.new()
	t_disc.inner_radius = 0.34
	t_disc.outer_radius = 0.36
	t_disc.rings = 36
	t_disc.ring_segments = 8
	disc_ring.mesh = t_disc
	disc_ring.position = Vector3(0.0, 0.803, 0.0)
	disc_ring.material_override = brass_mat
	_stage_root.add_child(disc_ring)

	var wall := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(6.4, 3.6, 0.18)
	wall.mesh = w_box
	wall.position = Vector3(0.0, 1.5, -2.55)
	wall.material_override = Toon.pbr(Color(0.10, 0.08, 0.08), "", 0.88, 0.02)
	_stage_root.add_child(wall)

	_warm_light = OmniLight3D.new()
	_warm_light.position = Vector3(-0.95, 1.45, 0.25)
	_warm_light.light_color = Color(1.0, 0.72, 0.36)
	_warm_light.light_energy = 2.4
	_warm_light.omni_range = 5.5
	_stage_root.add_child(_warm_light)

	_fx_light = OmniLight3D.new()
	_fx_light.position = Vector3(0.0, 1.95, -0.10)
	_fx_light.light_color = _accent
	_fx_light.light_energy = 0.0
	_fx_light.omni_range = 6.5
	_stage_root.add_child(_fx_light)

	_rival_root = Node3D.new()
	_rival_root.name = "FpvRival"
	_rival_root.position = _rival_base_pos
	_stage_root.add_child(_rival_root)

	var loaded_opp := false
	_rival_eye_mats.clear()
	if not _is_headless and ResourceLoader.exists(OPP_MODEL_PATH):
		var packed := load(OPP_MODEL_PATH) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			if inst is Node3D:
				var opp_nd := inst as Node3D
				opp_nd.scale = Vector3.ONE * 0.72
				opp_nd.position = Vector3(0.0, -0.04, 0.0)
				_apply_ink_outline(opp_nd, 0.012)
				_rival_root.add_child(opp_nd)
				loaded_opp = true
	if not loaded_opp:
		_build_fallback_rival(_rival_root)

	var opp_fan := Node3D.new()
	opp_fan.position = Vector3(0.0, 0.34, 0.26)
	_rival_root.add_child(opp_fan)
	for oi in range(5):
		var om := _create_card_quad_node(CARD_BACK_TEX, CARD_BACK_TEX, Color(0.75, 0.58, 0.26), Vector2(0.11, 0.16))
		var o_off := float(oi) - 2.0
		om.position = Vector3(o_off * 0.046, -absf(o_off) * 0.006, -float(oi) * 0.002)
		om.rotation_degrees = Vector3(14.0, 0.0, -o_off * 6.0)
		opp_fan.add_child(om)

	_hand_fan_root = Node3D.new()
	_hand_fan_root.name = "PlayerHandFanPreview"
	_hand_fan_root.position = Vector3(0.0, 1.00, 0.78)
	_stage_root.add_child(_hand_fan_root)
	var hand_cards := ["res://assets/cards/CERVEN_7.png", "res://assets/cards/ZELEN_H.png", "res://assets/cards/ZALUD_K.png", "res://assets/cards/GULA_E.png"]
	for hi in range(hand_cards.size()):
		var h_off := float(hi) - 1.5
		var hc := _create_card_quad_node(hand_cards[hi], CARD_BACK_TEX, Color(0.84, 0.68, 0.30), Vector2(0.14, 0.20))
		hc.position = Vector3(h_off * 0.11, -absf(h_off) * 0.012 - 0.04, absf(h_off) * 0.015)
		hc.rotation_degrees = Vector3(-42.0, 0.0, -h_off * 8.0)
		_hand_fan_root.add_child(hc)


func _build_fallback_rival(parent_nd: Node3D) -> void:
	var cloak_mat := Toon.pbr(Color(0.14, 0.12, 0.16), "", 0.78, 0.08)
	var trim_mat := Toon.pbr(Color(0.76, 0.56, 0.20), "", 0.32, 0.85)
	var torso := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.22
	tm.bottom_radius = 0.30
	tm.height = 0.52
	torso.mesh = tm
	torso.position = Vector3(0.0, 0.26, 0.0)
	torso.material_override = cloak_mat
	parent_nd.add_child(torso)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.14
	hm.height = 0.28
	head.mesh = hm
	head.position = Vector3(0.0, 0.62, 0.02)
	head.material_override = cloak_mat
	parent_nd.add_child(head)

	for side in [-1.0, 1.0]:
		var pauldron := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.10
		pm.height = 0.14
		pauldron.mesh = pm
		pauldron.position = Vector3(side * 0.24, 0.44, 0.02)
		pauldron.material_override = trim_mat
		parent_nd.add_child(pauldron)

		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.018
		em.height = 0.032
		eye.mesh = em
		eye.position = Vector3(side * 0.046, 0.62, 0.145)
		var e_mat := StandardMaterial3D.new()
		e_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		e_mat.albedo_color = Color(0.95, 0.72, 0.32)
		eye.material_override = e_mat
		parent_nd.add_child(eye)
		_rival_eye_mats.append(e_mat)
	_apply_ink_outline(parent_nd, 0.014)


func _create_card_quad_node(front_path: String, back_path: String, rim_col: Color, card_sz: Vector2) -> Node3D:
	var card_root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(card_sz.x, card_sz.y, 0.008)
	body.mesh = bm
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = rim_col * 0.35
	rim_mat.emission_enabled = true
	rim_mat.emission = rim_col
	rim_mat.emission_energy_multiplier = 0.9
	body.material_override = rim_mat
	_apply_ink_outline(body, 0.009)
	card_root.add_child(body)

	var front_tex: Texture2D = Toon.tex(front_path)
	var back_tex: Texture2D = Toon.tex(back_path)

	var f_quad := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = card_sz
	f_quad.mesh = fq
	f_quad.position = Vector3(0.0, 0.0, 0.005)
	var f_mat := StandardMaterial3D.new()
	f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if front_tex != null:
		f_mat.albedo_texture = front_tex
	else:
		f_mat.albedo_color = rim_col
	f_quad.material_override = f_mat
	card_root.add_child(f_quad)

	var b_quad := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = card_sz
	b_quad.mesh = bq
	b_quad.position = Vector3(0.0, 0.0, -0.005)
	b_quad.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if back_tex != null:
		b_mat.albedo_texture = back_tex
	else:
		b_mat.albedo_color = Color(0.18, 0.14, 0.10)
	b_quad.material_override = b_mat
	card_root.add_child(b_quad)

	return card_root


func _load_tex_25d(path: String) -> Texture2D:
	var t := Toon.tex(path)
	if t != null:
		return t
	var abs_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_p):
		var img := Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _make_25d_diorama(tex_path: String, w: float, h: float, glow_col: Color, tint_col: Color, out_mats: Dictionary, anim_mode: int = -1) -> Node3D:
	var root := Node3D.new()
	var tex := _load_tex_25d(tex_path)
	if tex != null and tex.get_size().y > 1.0:
		var aspect := tex.get_size().x / tex.get_size().y
		w = h * aspect

	var front_mat := ShaderMaterial.new()
	var shadow_mat := ShaderMaterial.new()
	if anim_mode >= 0:
		front_mat.shader = SHADER_LIVING_25D
		front_mat.set_shader_parameter("albedo_tex", tex)
		front_mat.set_shader_parameter("tint_col", tint_col)
		front_mat.set_shader_parameter("glow_col", glow_col)
		front_mat.set_shader_parameter("anim_mode", anim_mode)
		front_mat.set_shader_parameter("time_sec", 0.0)
		front_mat.set_shader_parameter("rune_glow", 2.0)
		front_mat.set_shader_parameter("sheen_pos", -0.5)
		front_mat.set_shader_parameter("opacity", 1.0)

		shadow_mat.shader = SHADER_LIVING_25D
		shadow_mat.set_shader_parameter("albedo_tex", tex)
		shadow_mat.set_shader_parameter("tint_col", Color(0.05, 0.04, 0.05, 0.88))
		shadow_mat.set_shader_parameter("glow_col", Color(0.03, 0.02, 0.03, 1.0))
		shadow_mat.set_shader_parameter("anim_mode", anim_mode if anim_mode in [2, 4, 8, 9, 10] else 99)
		shadow_mat.set_shader_parameter("time_sec", 0.0)
		shadow_mat.set_shader_parameter("rune_glow", 0.0)
		shadow_mat.set_shader_parameter("sheen_strength", 0.0)
		shadow_mat.set_shader_parameter("opacity", 0.85)
	else:
		front_mat.shader = SHADER_BLADE
		front_mat.set_shader_parameter("blade_tex", tex)
		front_mat.set_shader_parameter("tint_col", tint_col)
		front_mat.set_shader_parameter("glow_col", glow_col)
		front_mat.set_shader_parameter("rune_glow", 2.0)
		front_mat.set_shader_parameter("sheen_pos", -0.5)
		front_mat.set_shader_parameter("opacity", 1.0)

		shadow_mat.shader = SHADER_BLADE
		shadow_mat.set_shader_parameter("blade_tex", tex)
		shadow_mat.set_shader_parameter("tint_col", Color(0.05, 0.04, 0.05, 0.88))
		shadow_mat.set_shader_parameter("glow_col", Color(0.03, 0.02, 0.03, 1.0))
		shadow_mat.set_shader_parameter("rune_glow", 0.0)
		shadow_mat.set_shader_parameter("sheen_strength", 0.0)
		shadow_mat.set_shader_parameter("opacity", 0.85)

	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	if anim_mode in [2, 4, 8, 9, 10]:
		qm.subdivide_width = 14
		qm.subdivide_depth = 8

	var front_mi := MeshInstance3D.new()
	front_mi.mesh = qm
	front_mi.material_override = front_mat
	front_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	front_mi.sorting_offset = 0.14
	root.add_child(front_mi)

	var shadow_mi := MeshInstance3D.new()
	shadow_mi.mesh = qm
	shadow_mi.position = Vector3(0.014, -0.012, -0.026)
	shadow_mi.material_override = shadow_mat
	shadow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow_mi.sorting_offset = 0.08
	root.add_child(shadow_mi)

	out_mats["front"] = front_mat
	out_mats["shadow"] = shadow_mat
	return root


func _make_25d_particle_quad(tex_path: String, sz: Vector2, glow_col: Color, tint_col: Color, anim_mode: int = 99, phase: float = 0.0, sort_idx: int = 4) -> Dictionary:
	var tex := _load_tex_25d(tex_path)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_LIVING_25D
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("tint_col", tint_col)
	mat.set_shader_parameter("glow_col", glow_col)
	mat.set_shader_parameter("anim_mode", anim_mode)
	mat.set_shader_parameter("sheen_pos", phase)
	mat.set_shader_parameter("time_sec", 0.0)
	mat.set_shader_parameter("rune_glow", 1.9)
	mat.set_shader_parameter("opacity", 1.0)

	var qm := QuadMesh.new()
	qm.size = sz
	if anim_mode == 4:
		qm.subdivide_width = 12
		qm.subdivide_depth = 4

	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = float(sort_idx) * 0.04
	return {"node": mi, "mat": mat}


func _make_cel_quad(tex_path: String, grid: Vector2, w: float, h: float, glow_col: Color, tint_col: Color, glow_str: float, boil_seed: float, sort_idx: int) -> Dictionary:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_CEL
	mat.set_shader_parameter("sprite_sheet", _load_tex_25d(tex_path))
	mat.set_shader_parameter("grid_size", grid)
	mat.set_shader_parameter("frame_index", 0.0)
	mat.set_shader_parameter("tint_col", tint_col)
	mat.set_shader_parameter("glow_col", glow_col)
	mat.set_shader_parameter("glow_strength", glow_str)
	mat.set_shader_parameter("royal_shift", 0.0)
	mat.set_shader_parameter("boil_seed", boil_seed)
	mat.set_shader_parameter("opacity", 1.0)

	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = float(sort_idx) * 0.04
	return {"node": mi, "mat": mat}


func _attach_cel_slashes(col_a: Color, tint_a: Color, col_b: Color, tint_b: Color, royal_shift: float = 0.0) -> void:
	var sa := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.30, 1.30, col_a, tint_a, 2.45, 3.1, 4)
	_cel_slash_a = sa["node"] as MeshInstance3D
	_cel_slash_a_mat = sa["mat"] as ShaderMaterial
	_cel_slash_a_mat.set_shader_parameter("royal_shift", royal_shift)
	_cel_slash_a.position = _impact_pos + Vector3(0.0, 0.04, 0.06)
	_cel_slash_a.rotation_degrees = Vector3(-84.0, 30.0, -14.0)
	_cel_slash_a.visible = false
	_fx_root.add_child(_cel_slash_a)

	var sb := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.18, 1.18, col_b, tint_b, 2.25, 6.7, 5)
	_cel_slash_b = sb["node"] as MeshInstance3D
	_cel_slash_b_mat = sb["mat"] as ShaderMaterial
	_cel_slash_b_mat.set_shader_parameter("flip_x", 1.0)
	_cel_slash_b_mat.set_shader_parameter("royal_shift", royal_shift)
	_cel_slash_b.position = _impact_pos + Vector3(0.0, 0.05, 0.08)
	_cel_slash_b.rotation_degrees = Vector3(-82.0, -34.0, 16.0)
	_cel_slash_b.visible = false
	_fx_root.add_child(_cel_slash_b)


func _build_fx_rig() -> void:
	if is_instance_valid(_fx_root):
		_fx_root.queue_free()
	_fx_root = Node3D.new()
	_fx_root.name = "PowerCardFxRig_" + _card_id
	add_child(_fx_root)
	_hero_25d_root = null
	_hero_25d_mat = null
	_hero_25d_shadow_mat = null
	_extra_25d_mats.clear()
	_vampire_eclipse_ring = null
	_vampire_eclipse_mat = null
	_vampire_eclipse_shadow_mat = null
	_cel_slash_a = null
	_cel_slash_a_mat = null
	_cel_slash_b = null
	_cel_slash_b_mat = null
	_alc_mist_rings.clear()

	var meta: Dictionary = CARD_META[_card_id]
	var tex_path: String = str(meta["tex"])

	# Shared Hero 3D Card + Ink-Outlined Orbit Rings
	_hero_card = _create_card_quad_node(tex_path, CARD_BACK_TEX, _accent, Vector2(0.22, 0.32))
	_hero_card.position = _hand_pos
	_fx_root.add_child(_hero_card)

	_card_orbit_rings.clear()
	for ri in range(2):
		var orb := MeshInstance3D.new()
		var om := TorusMesh.new()
		om.inner_radius = 0.19 + float(ri) * 0.042
		om.outer_radius = 0.208 + float(ri) * 0.042
		om.rings = 32
		om.ring_segments = 8
		orb.mesh = om
		var omat := StandardMaterial3D.new()
		omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		omat.albedo_color = Color(_accent.r, _accent.g, _accent.b, 0.88)
		orb.material_override = omat
		_apply_ink_outline(orb, 0.010)
		orb.rotation_degrees = Vector3(65.0 if ri == 0 else -58.0, float(ri) * 45.0, 22.0)
		_hero_card.add_child(orb)
		_card_orbit_rings.append(orb)

	# Shared Hand-Drawn 2.5D Table Sigil & Swirl Mist Seal (replaces flat vector spokes/torus!)
	_rune_seal_root = Node3D.new()
	_rune_seal_root.position = _impact_pos + Vector3(0.0, 0.014, 0.0)
	_fx_root.add_child(_rune_seal_root)

	_rune_seal_mat = StandardMaterial3D.new()
	_rune_seal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rune_seal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rune_seal_mat.albedo_color = Color(_accent.r, _accent.g, _accent.b, 0.0)

	var sigil_cfg := _make_cel_quad(TEX_IMPACT_SHEET, Vector2(4.0, 4.0), 1.48, 1.48, _accent.lightened(0.15), Color(0.98, 0.99, 1.0, 1.0), 2.15, 2.7, 1)
	_seal_cel_outer = sigil_cfg["node"] as MeshInstance3D
	_seal_cel_outer_mat = sigil_cfg["mat"] as ShaderMaterial
	_seal_cel_outer.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_rune_seal_root.add_child(_seal_cel_outer)

	var mist_cfg := _make_cel_quad(TEX_MIST_SHEET, Vector2(4.0, 4.0), 1.72, 1.72, _accent, Color(_accent.r, _accent.g, _accent.b, 0.72), 0.95, 5.1, 0)
	_seal_cel_mist = mist_cfg["node"] as MeshInstance3D
	_seal_cel_mist_mat = mist_cfg["mat"] as ShaderMaterial
	_seal_cel_mist_mat.set_shader_parameter("loop_sheet", 1.0)
	_seal_cel_mist_mat.set_shader_parameter("blend_next", 0.55)
	_seal_cel_mist.position = Vector3(0.0, 0.005, 0.0)
	_seal_cel_mist.rotation_degrees = Vector3(-90.0, 18.0, 0.0)
	_rune_seal_root.add_child(_seal_cel_mist)

	_shock_rings.clear()
	for si in range(3):
		var sr := MeshInstance3D.new()
		var srm := TorusMesh.new()
		srm.inner_radius = 0.24
		srm.outer_radius = 0.30
		srm.rings = 40
		srm.ring_segments = 8
		sr.mesh = srm
		sr.position = _impact_pos + Vector3(0.0, 0.018 + float(si) * 0.004, 0.0)
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(_accent.r, _accent.g, _accent.b, 0.0)
		sr.material_override = smat
		_apply_ink_outline(sr, 0.010)
		_fx_root.add_child(sr)
		_shock_rings.append({"node": sr, "mat": smat})

	match _card_id:
		"SPEC_STORM":
			_build_storm_specific_rig(tex_path)
		"SPEC_VAMPIRE":
			_build_vampire_specific_rig()
		"SPEC_PHOENIX":
			_build_phoenix_specific_rig()
		"SPEC_CHRONOS":
			_build_chronos_specific_rig()
		_:
			_build_hybrid_power_rig(_card_id, tex_path)


func _build_storm_specific_rig(tex_path: String) -> void:
	_vortex_root = Node3D.new()
	_vortex_root.position = _impact_pos + Vector3(0.0, 1.18, 0.0)
	_fx_root.add_child(_vortex_root)

	# Hand-Drawn Cel Mist & Carved Sigil Storm Vortex Overhead (replaces flat TorusMesh rings)
	_vortex_layers.clear()
	for vi in range(3):
		var use_sig := (vi == 1)
		var v_cfg := _make_cel_quad(
			TEX_IMPACT_SHEET if use_sig else TEX_MIST_SHEET,
			Vector2(4.0, 4.0),
			1.28 - float(vi) * 0.24,
			1.28 - float(vi) * 0.24,
			Color(0.32, 0.94, 1.0, 1.0),
			Color(0.75, 0.96, 1.0, 0.88 if not use_sig else 0.96),
			2.1 if use_sig else 1.15,
			3.3 + float(vi) * 2.1,
			2 + vi
		)
		var vr := v_cfg["node"] as MeshInstance3D
		var vmat := v_cfg["mat"] as ShaderMaterial
		vmat.set_shader_parameter("loop_sheet", 1.0)
		vmat.set_shader_parameter("blend_next", 0.55)
		vr.position = Vector3(0.0, float(vi) * -0.04, 0.0)
		vr.rotation_degrees = Vector3(-90.0, float(vi) * 35.0, 0.0)
		vr.set_meta("cel_mat", vmat)
		_vortex_root.add_child(vr)
		_vortex_layers.append(vr)

	# Hand-Drawn 2.5D Living Celestial Tempest Spear Diorama (anim_mode=1) + Dual Cel Storm-Slash Canopies
	var s_mats := {}
	_hero_25d_root = _make_25d_diorama(TEX_STORM_25D, 0.78, 0.92, Color(0.28, 0.94, 1.0, 1.0), Color(0.96, 0.99, 1.0, 1.0), s_mats, 1)
	_hero_25d_mat = s_mats.get("front", null) as ShaderMaterial
	_hero_25d_shadow_mat = s_mats.get("shadow", null) as ShaderMaterial
	_hero_25d_root.position = _impact_pos + Vector3(0.0, 0.42, -0.06)
	_hero_25d_root.visible = false
	_fx_root.add_child(_hero_25d_root)

	var sa := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.32, 1.32, Color(0.28, 0.94, 1.0, 1.0), Color(0.84, 0.98, 1.0, 1.0), 2.55, 3.3, 4)
	_cel_slash_a = sa["node"] as MeshInstance3D
	_cel_slash_a_mat = sa["mat"] as ShaderMaterial
	_cel_slash_a_mat.set_shader_parameter("royal_shift", 0.0)
	_cel_slash_a.position = _impact_pos + Vector3(0.0, 0.04, 0.06)
	_cel_slash_a.rotation_degrees = Vector3(-84.0, 26.0, -14.0)
	_cel_slash_a.visible = false
	_fx_root.add_child(_cel_slash_a)

	var sb := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.20, 1.20, Color(0.42, 0.96, 1.0, 1.0), Color(0.88, 0.99, 1.0, 1.0), 2.35, 7.9, 5)
	_cel_slash_b = sb["node"] as MeshInstance3D
	_cel_slash_b_mat = sb["mat"] as ShaderMaterial
	_cel_slash_b_mat.set_shader_parameter("flip_x", 1.0)
	_cel_slash_b_mat.set_shader_parameter("royal_shift", 0.0)
	_cel_slash_b.position = _impact_pos + Vector3(0.0, 0.05, 0.08)
	_cel_slash_b.rotation_degrees = Vector3(-82.0, -32.0, 16.0)
	_cel_slash_b.visible = false
	_fx_root.add_child(_cel_slash_b)

	_pillar_root = null
	_pillar_core_mat = null
	_pillar_sheath_mat = null

	_bolts_mesh = ImmediateMesh.new()
	_bolts_mesh_inst = MeshInstance3D.new()
	_bolts_mesh_inst.mesh = _bolts_mesh
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.vertex_color_use_as_albedo = true
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolts_mesh_inst.material_override = bmat
	_fx_root.add_child(_bolts_mesh_inst)

	# 32 Hand-Drawn 2.5D Storm Lightning Shards & Ink Sparks (replaces flat BoxMesh vectors!)
	_sparks.clear()
	for spi in range(32):
		var use_bolt_tex := (spi % 2 == 0)
		var nd: MeshInstance3D
		var spmat: ShaderMaterial
		if use_bolt_tex:
			var sc := _make_25d_particle_quad(TEX_STORM_SPARK_25D, Vector2(0.14, 0.14), Color(0.32, 0.94, 1.0, 1.0), Color(0.95, 0.99, 1.0, 1.0), 1, float(spi) * 0.25, 6)
			nd = sc["node"] as MeshInstance3D
			spmat = sc["mat"] as ShaderMaterial
		else:
			var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(0.32, 0.95, 1.0, 1.0), Color(0.85, 0.98, 1.0, 1.0), 2.35, 1.4 + float(spi) * 0.5, 6)
			nd = ic["node"] as MeshInstance3D
			spmat = ic["mat"] as ShaderMaterial
			spmat.set_shader_parameter("frame_index", float((spi % 6) + 6))
			spmat.set_shader_parameter("loop_sheet", 1.0)
		nd.visible = false
		_fx_root.add_child(nd)
		_sparks.append({
			"node": nd,
			"mat": spmat,
			"is_cel": not use_bolt_tex,
			"angle": float(spi) * (TAU / 32.0) + _rng.randf_range(-0.2, 0.2),
			"rad": _rng.randf_range(0.20, 0.96),
			"spd": _rng.randf_range(0.75, 1.85),
			"phase": _rng.randf(),
		})

	_curse_cards.clear()
	for ci in range(3):
		var cnode := _create_card_quad_node(tex_path, CARD_BACK_TEX, _accent, Vector2(0.14, 0.20))
		cnode.visible = false
		_fx_root.add_child(cnode)
		_curse_cards.append({
			"node": cnode,
			"delay": 2.60 + float(ci) * 0.18,
			"arc_x": (float(ci) - 1.0) * 0.36,
		})


func _build_vampire_specific_rig() -> void:
	# Layer 1: Independent Spinning Hand-Drawn Crimson Blood Eclipse Halo Ring (anim_mode=5) behind Chalice
	var e_mats := {}
	_vampire_eclipse_ring = _make_25d_diorama(TEX_VAMPIRE_ECLIPSE_RING_25D, 1.08, 1.08, Color(0.95, 0.12, 0.20, 1.0), Color(1.0, 0.94, 0.94, 1.0), e_mats, 5)
	_vampire_eclipse_mat = e_mats.get("front", null) as ShaderMaterial
	_vampire_eclipse_shadow_mat = e_mats.get("shadow", null) as ShaderMaterial
	_vampire_eclipse_ring.position = _impact_pos + Vector3(0.0, 0.46, -0.34)
	_vampire_eclipse_ring.visible = false
	_fx_root.add_child(_vampire_eclipse_ring)

	# Layer 2: Clean Living 2.5D Gothic Vampire Blood Chalice (anim_mode=0: flowing liquid blood + pulsing rubies!)
	var v_mats := {}
	_hero_25d_root = _make_25d_diorama(TEX_VAMPIRE_CHALICE_25D, 0.72, 0.78, Color(0.96, 0.14, 0.24, 1.0), Color(1.0, 0.96, 0.94, 1.0), v_mats, 0)
	_hero_25d_mat = v_mats.get("front", null) as ShaderMaterial
	_hero_25d_shadow_mat = v_mats.get("shadow", null) as ShaderMaterial
	_hero_25d_root.position = _impact_pos + Vector3(0.0, 0.38, -0.14)
	_hero_25d_root.visible = false
	_fx_root.add_child(_hero_25d_root)

	# Layer 3: 10 Independent Animated Vertex Wing-Flapping Gothic 2.5D Bats (anim_mode=4!)
	_bats.clear()
	for bi in range(10):
		var ph := float(bi) * 0.37
		var b_cfg := _make_25d_particle_quad(TEX_GOTHIC_BAT_25D, Vector2(0.24, 0.24), Color(0.92, 0.14, 0.24, 1.0), Color(1.0, 0.96, 0.96, 1.0), 4, ph, 7)
		var b_nd := b_cfg["node"] as MeshInstance3D
		b_nd.visible = false
		_fx_root.add_child(b_nd)
		_bats.append({
			"node": b_nd,
			"mat": b_cfg["mat"] as ShaderMaterial,
			"angle": float(bi) * (TAU / 10.0),
			"phase": ph,
			"rad": _rng.randf_range(0.32, 0.78),
		})

	var sa := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.32, 1.32, Color(0.96, 0.10, 0.20, 1.0), Color(1.0, 0.22, 0.30, 1.0), 2.50, 4.1, 4)
	_cel_slash_a = sa["node"] as MeshInstance3D
	_cel_slash_a_mat = sa["mat"] as ShaderMaterial
	_cel_slash_a_mat.set_shader_parameter("royal_shift", 0.0)
	_cel_slash_a.position = _impact_pos + Vector3(0.0, 0.04, 0.06)
	_cel_slash_a.rotation_degrees = Vector3(-84.0, 34.0, -18.0)
	_cel_slash_a.visible = false
	_fx_root.add_child(_cel_slash_a)

	var sb := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.18, 1.18, Color(0.92, 0.12, 0.26, 1.0), Color(1.0, 0.28, 0.38, 1.0), 2.25, 8.7, 5)
	_cel_slash_b = sb["node"] as MeshInstance3D
	_cel_slash_b_mat = sb["mat"] as ShaderMaterial
	_cel_slash_b_mat.set_shader_parameter("flip_x", 1.0)
	_cel_slash_b_mat.set_shader_parameter("royal_shift", 0.0)
	_cel_slash_b.position = _impact_pos + Vector3(0.0, 0.05, 0.08)
	_cel_slash_b.rotation_degrees = Vector3(-82.0, -38.0, 18.0)
	_cel_slash_b.visible = false
	_fx_root.add_child(_cel_slash_b)

	_blood_moon_mesh = null
	_crescent_slash = null

	# 16 Hand-Drawn Crimson Siphon Ink-Sparks (NO SphereMesh balls!) + ImmediateMesh Ribbons
	_siphon_orbs.clear()
	for oi in range(16):
		var oc := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(0.98, 0.12, 0.24, 1.0), Color(1.0, 0.56, 0.60, 1.0), 2.35, float(oi) * 0.7, 6)
		var om := oc["node"] as MeshInstance3D
		var omat := oc["mat"] as ShaderMaterial
		omat.set_shader_parameter("royal_shift", 1.0)
		omat.set_shader_parameter("frame_index", float(oi % 6))
		om.visible = false
		_fx_root.add_child(om)
		_siphon_orbs.append({
			"node": om,
			"mat": omat,
			"delay": 2.35 + float(oi) * 0.065,
			"arc_x": sin(float(oi) * 1.9) * 0.42,
			"arc_y": 0.22 + cos(float(oi) * 1.4) * 0.16,
		})

	_siphon_ribbons_mesh = ImmediateMesh.new()
	_siphon_ribbons_inst = MeshInstance3D.new()
	_siphon_ribbons_inst.mesh = _siphon_ribbons_mesh
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.vertex_color_use_as_albedo = true
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_siphon_ribbons_inst.material_override = rmat
	_fx_root.add_child(_siphon_ribbons_inst)


func _build_phoenix_specific_rig() -> void:
	# Shattering Ink Curse Chains around card slam
	_curse_chains.clear()
	var chain_mat := Toon.pbr(Color(0.16, 0.14, 0.18), "", 0.45, 0.72)
	for ci in range(4):
		var ch := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.55, 0.032, 0.032)
		ch.mesh = cm
		ch.position = _impact_pos + Vector3(0.0, 0.12, 0.0)
		ch.rotation_degrees = Vector3(12.0, float(ci) * 45.0, 18.0)
		ch.material_override = chain_mat
		_apply_ink_outline(ch, 0.012)
		_fx_root.add_child(ch)
		_curse_chains.append({"node": ch, "dir": Vector3(cos(float(ci) * 1.57), 0.7, sin(float(ci) * 1.57))})

	# Towering Living Hand-Drawn 2.5D Woodcut Ash Phoenix Diorama (anim_mode=2: vertex wing-flap + flame flicker)
	var p_mats := {}
	_hero_25d_root = _make_25d_diorama(TEX_PHOENIX_25D, 0.88, 0.88, Color(1.0, 0.58, 0.16, 1.0), Color(1.0, 0.97, 0.92, 1.0), p_mats, 2)
	_hero_25d_mat = p_mats.get("front", null) as ShaderMaterial
	_hero_25d_shadow_mat = p_mats.get("shadow", null) as ShaderMaterial
	_hero_25d_root.position = _impact_pos + Vector3(0.0, 0.40, -0.16)
	_hero_25d_root.visible = false
	_fx_root.add_child(_hero_25d_root)

	var pa := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.32, 1.32, Color(1.0, 0.56, 0.14, 1.0), Color(1.0, 0.78, 0.45, 1.0), 2.55, 3.8, 4)
	_cel_slash_a = pa["node"] as MeshInstance3D
	_cel_slash_a_mat = pa["mat"] as ShaderMaterial
	_cel_slash_a_mat.set_shader_parameter("royal_shift", 1.0)
	_cel_slash_a.position = _impact_pos + Vector3(0.0, 0.04, 0.06)
	_cel_slash_a.rotation_degrees = Vector3(-84.0, 32.0, -14.0)
	_cel_slash_a.visible = false
	_fx_root.add_child(_cel_slash_a)

	var pb := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.18, 1.18, Color(1.0, 0.80, 0.24, 1.0), Color(1.0, 0.78, 0.45, 1.0), 2.35, 7.1, 5)
	_cel_slash_b = pb["node"] as MeshInstance3D
	_cel_slash_b_mat = pb["mat"] as ShaderMaterial
	_cel_slash_b_mat.set_shader_parameter("flip_x", 1.0)
	_cel_slash_b_mat.set_shader_parameter("royal_shift", 1.0)
	_cel_slash_b.position = _impact_pos + Vector3(0.0, 0.05, 0.08)
	_cel_slash_b.rotation_degrees = Vector3(-82.0, -34.0, 16.0)
	_cel_slash_b.visible = false
	_fx_root.add_child(_cel_slash_b)

	_phoenix_bird_root = null
	_flame_pillar = null
	_flame_pillar_mat = null

	# 32 Swirling Hand-Drawn 2.5D Blazing Phoenix Feathers & Ink Sparks (replaces flat BoxMesh rectangles!)
	_feathers.clear()
	for fi in range(32):
		var fc := _make_25d_particle_quad(TEX_PHOENIX_FEATHER_25D, Vector2(0.14, 0.14), Color(1.0, 0.62, 0.18, 1.0), Color(1.0, 0.96, 0.92, 1.0), 2, float(fi) * 0.2, 6)
		var fm := fc["node"] as MeshInstance3D
		fm.visible = false
		_fx_root.add_child(fm)
		_feathers.append({
			"node": fm,
			"mat": fc["mat"] as ShaderMaterial,
			"angle": float(fi) * (TAU / 32.0),
			"rad": _rng.randf_range(0.24, 1.00),
			"spd": _rng.randf_range(0.6, 1.5),
			"phase": _rng.randf(),
		})


func _build_chronos_specific_rig() -> void:
	_astro_gears.clear()
	var ring_mats := {}
	var gear_ring := _make_25d_diorama(TEX_CHRONOS_RING_25D, 1.06, 1.06, Color(0.45, 0.90, 1.0, 1.0), Color(1.0, 0.96, 0.88, 1.0), ring_mats, 7)
	gear_ring.position = _impact_pos + Vector3(0.0, 0.46, -0.32)
	gear_ring.visible = false
	_fx_root.add_child(gear_ring)
	_astro_gears.append(gear_ring)
	_extra_25d_mats.append(ring_mats)

	var c_mats := {}
	_hero_25d_root = _make_25d_diorama(TEX_CHRONOS_25D, 0.82, 0.88, Color(0.98, 0.84, 0.34, 1.0), Color(1.0, 0.98, 0.92, 1.0), c_mats, 7)
	_hero_25d_mat = c_mats.get("front", null) as ShaderMaterial
	_hero_25d_shadow_mat = c_mats.get("shadow", null) as ShaderMaterial
	_hero_25d_root.position = _impact_pos + Vector3(0.0, 0.42, -0.14)
	_hero_25d_root.visible = false
	_fx_root.add_child(_hero_25d_root)

	_attach_cel_slashes(Color(0.98, 0.84, 0.34, 1.0), Color(1.0, 0.92, 0.65, 1.0), Color(0.45, 0.90, 1.0, 1.0), Color(0.84, 0.98, 1.0, 1.0), 0.5)

	_astrolabe_root = null
	_clock_hand_min = null
	_clock_hand_hr = null

	# 24 Suspended Time-Frozen Hand-Drawn 2.5D Crystal Shards (NO PrismMesh vectors!)
	_glass_shards.clear()
	for si in range(24):
		var sc := _make_25d_particle_quad(TEX_MIRROR_SHARD_25D, Vector2(0.14, 0.14), Color(0.48, 0.92, 1.0, 1.0), Color(0.95, 0.98, 1.0, 1.0), 7, float(si) * 0.25, 6)
		var sh := sc["node"] as MeshInstance3D
		sh.visible = false
		_fx_root.add_child(sh)
		_glass_shards.append({
			"node": sh,
			"mat": sc["mat"] as ShaderMaterial,
			"pos": _impact_pos + Vector3(_rng.randf_range(-0.85, 0.85), _rng.randf_range(0.18, 1.15), _rng.randf_range(-0.75, 0.35)),
			"rot": Vector3(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-30.0, 30.0), _rng.randf_range(0.0, 360.0)),
		})


func _process(delta: float) -> void:
	if not visible or not _playing:
		return

	var dt := minf(delta, 0.05) * _speed
	_t += dt
	_bolt_rebuild_acc += dt

	var dur := _get_duration()
	if _t >= dur:
		if _loop:
			restart()
			return
		else:
			_t = dur
			_apply_animation_state(_t)
			if not _finished_emitted:
				_finished_emitted = true
				sequence_finished.emit()
			if _mode == "battle_fx":
				queue_free()
			return

	_apply_animation_state(_t)
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _fire_beat(beat_id: String, at_time: float, sfx_key: String, vol_db: float, pitch: float) -> void:
	if _t >= at_time and not _beats_fired.has(beat_id):
		_beats_fired[beat_id] = true
		sfx_triggered.emit(sfx_key, vol_db, pitch)


func _apply_animation_state(t: float) -> void:
	var use_custom_studio := _with_stinger and (_card_id in ["SPEC_VAMPIRE", "SPEC_STORM"])
	if _with_stinger:
		if _card_id == "SPEC_VAMPIRE":
			_fire_beat("studio_cast", 0.05, "power_vampire_cast", -2.5, 1.0)
		elif _card_id == "SPEC_STORM":
			_fire_beat("studio_cast", 0.05, "power_storm_cast", -2.5, 1.0)

	# Common 5-act beats tuned to 4.20s (fallback when card doesn't use bespoke multi-stem studio cues)
	if not use_custom_studio:
		_fire_beat("rise", 0.05, "card_throw_whoosh", -5.0, 1.04)
		_fire_beat("charge", 0.22, "anim_sword_unsheathe", -6.0, 1.18)
		_fire_beat("slam", 0.85, "card_slam", -3.0, 1.0)
		_fire_beat("conduit", 0.90, "anim_combo_slam", -4.5, 1.10)

	# 1. Hero Card Transform across 4.20s
	if is_instance_valid(_hero_card):
		var show_card := (_mode == "fpv_preview") or (t < 2.65)
		_hero_card.visible = show_card
		if t < 0.85:
			var u := ease(clampf(t / 0.85, 0.0, 1.0), 0.42)
			var hover_pos := _cam_base_pos.lerp(_impact_pos + Vector3(0.0, 0.36, 0.18), 0.58)
			_hero_card.position = _hand_pos.lerp(hover_pos, u) + Vector3(0.0, sin(t * 8.5) * 0.020 * u, 0.0)
			_hero_card.rotation_degrees = Vector3(lerpf(-35.0, -14.0, u), lerpf(0.0, 360.0, u * 0.95), sin(t * 7.5) * 4.5)
			_hero_card.scale = Vector3.ONE * lerpf(0.75, 1.20, u)
		elif t < 1.04:
			var u := ease(clampf((t - 0.85) / 0.19, 0.0, 1.0), 2.2)
			var hover_pos := _cam_base_pos.lerp(_impact_pos + Vector3(0.0, 0.36, 0.18), 0.58)
			_hero_card.position = hover_pos.lerp(_impact_pos + Vector3(0.0, 0.018, 0.0), u)
			_hero_card.rotation_degrees = Vector3(lerpf(-14.0, -90.0, u), 0.0, 0.0)
			_hero_card.scale = Vector3.ONE * lerpf(1.20, 0.96, u)
		else:
			var rise_back := 0.0
			if _card_id == "SPEC_PHOENIX" and t >= 2.85:
				rise_back = ease(clampf((t - 2.85) / 1.10, 0.0, 1.0), 0.5)
			_hero_card.position = _impact_pos + Vector3(0.0, 0.018 + rise_back * 0.72, 0.0)
			_hero_card.rotation_degrees = Vector3(lerpf(-90.0, 0.0, rise_back), rise_back * 360.0, 0.0)
			_hero_card.scale = Vector3.ONE * (0.96 * (1.0 - rise_back * 0.35))

		for ri in range(_card_orbit_rings.size()):
			var orb := _card_orbit_rings[ri]
			if is_instance_valid(orb):
				orb.visible = t >= 0.12 and t < 1.02
				orb.rotation_degrees.y = t * (260.0 if ri == 0 else -320.0)

	# Shared Hand-Drawn 2.5D Table Seal & Cel Animation
	if is_instance_valid(_rune_seal_root):
		var seal_a := 0.0
		if t >= 0.85 and t < 3.60:
			seal_a = 1.0 if t < 2.95 else clampf(1.0 - (t - 2.95) / 0.65, 0.0, 1.0)
		_rune_seal_root.visible = seal_a > 0.01
		_rune_seal_root.rotation_degrees.y = t * 38.0
		if _seal_cel_outer_mat != null:
			_seal_cel_outer_mat.set_shader_parameter("frame_index", clampf((t - 0.85) * 9.5, 0.0, 15.0))
			_seal_cel_outer_mat.set_shader_parameter("opacity", seal_a)
			_seal_cel_outer_mat.set_shader_parameter("dissolve", clampf((t - 2.85) / 0.65, 0.0, 1.0))
		if _seal_cel_mist_mat != null:
			_seal_cel_mist_mat.set_shader_parameter("frame_index", fmod(t * 9.0, 16.0))
			_seal_cel_mist_mat.set_shader_parameter("opacity", seal_a * 0.72)

	if is_instance_valid(_hero_25d_root) and _card_id in ["SPEC_STORM", "SPEC_VAMPIRE", "SPEC_PHOENIX"]:
		var hero_in := clampf((t - 1.28) / 0.34, 0.0, 1.0)
		var hero_out := 1.0 if t < 3.30 else clampf(1.0 - (t - 3.30) / 0.75, 0.0, 1.0)
		var hero_op := hero_in * hero_out
		_hero_25d_root.visible = hero_op > 0.01
		var ease_pop := ease(hero_in, 0.32)
		if _card_id == "SPEC_PHOENIX":
			_hero_25d_root.position = _impact_pos + Vector3(0.0, lerpf(0.18, 0.42, ease_pop) + sin(t * 6.5) * 0.025, -0.18)
			var flap_sx := 1.0 + sin(t * 11.0) * 0.075
			_hero_25d_root.scale = Vector3(flap_sx, 1.0 / sqrt(flap_sx), 1.0) * lerpf(0.55, 0.96, ease_pop)
			_hero_25d_root.rotation_degrees = Vector3(-8.0, sin(t * 2.8) * 9.0, sin(t * 4.2) * 3.5)
		elif _card_id == "SPEC_STORM":
			var plunge := ease(clampf((t - 1.25) / 0.32, 0.0, 1.0), 2.2)
			_hero_25d_root.position = _impact_pos + Vector3(0.0, lerpf(1.15, 0.44, plunge), -0.06)
			_hero_25d_root.scale = Vector3.ONE * lerpf(0.75, 0.96, plunge)
			_hero_25d_root.rotation_degrees = Vector3(-6.0, sin(t * 5.0) * 6.0, 0.0)
		elif _card_id == "SPEC_VAMPIRE":
			_hero_25d_root.position = _impact_pos + Vector3(0.0, lerpf(0.18, 0.42, ease_pop) + sin(t * 3.5) * 0.018, -0.20)
			_hero_25d_root.scale = Vector3.ONE * lerpf(0.52, 0.96, ease_pop)
			_hero_25d_root.rotation_degrees = Vector3(-6.0, sin(t * 2.2) * 6.0, 0.0)
		var sheen_v := fmod(maxf(0.0, t - 1.35) * 0.95, 1.8) - 0.3
		if _hero_25d_mat != null:
			_hero_25d_mat.set_shader_parameter("time_sec", t)
			_hero_25d_mat.set_shader_parameter("opacity", hero_op)
			_hero_25d_mat.set_shader_parameter("sheen_pos", sheen_v)
			_hero_25d_mat.set_shader_parameter("flash_white", maxf(0.0, 0.55 - absf(t - 1.62) * 3.5))
		if _hero_25d_shadow_mat != null:
			_hero_25d_shadow_mat.set_shader_parameter("time_sec", t)
			_hero_25d_shadow_mat.set_shader_parameter("opacity", hero_op * 0.85)
		if is_instance_valid(_vampire_eclipse_ring):
			_vampire_eclipse_ring.visible = hero_op > 0.01
			_vampire_eclipse_ring.position = _impact_pos + Vector3(0.0, lerpf(0.18, 0.46, ease_pop), -0.34)
			_vampire_eclipse_ring.scale = Vector3.ONE * lerpf(0.50, 1.04, ease_pop) * (1.0 + 0.04 * sin(t * 4.5))
			_vampire_eclipse_ring.rotation_degrees = Vector3(-6.0, 0.0, t * 44.0)
			if _vampire_eclipse_mat != null:
				_vampire_eclipse_mat.set_shader_parameter("time_sec", t)
				_vampire_eclipse_mat.set_shader_parameter("opacity", hero_op * 0.96)
			if _vampire_eclipse_shadow_mat != null:
				_vampire_eclipse_shadow_mat.set_shader_parameter("opacity", hero_op * 0.82)

	if is_instance_valid(_cel_slash_a) and is_instance_valid(_cel_slash_b) and _card_id in ["SPEC_STORM", "SPEC_VAMPIRE", "SPEC_PHOENIX"]:
		if t >= 1.44 and t <= 2.95:
			var su := clampf((t - 1.44) / 1.45, 0.0, 1.0)
			var swing_a := 1.0 - pow(1.0 - su, 2.4)
			_cel_slash_a.visible = true
			_cel_slash_a.scale = Vector3.ONE * lerpf(0.75, 1.04, minf(1.0, su * 2.2))
			_cel_slash_a.rotation_degrees = Vector3(-84.0, lerpf(-34.0, 42.0, swing_a), lerpf(-18.0, 14.0, swing_a))
			if _cel_slash_a_mat != null:
				_cel_slash_a_mat.set_shader_parameter("frame_index", pow(su, 0.72) * 23.0)
				_cel_slash_a_mat.set_shader_parameter("dissolve", clampf((su - 0.68) / 0.32, 0.0, 1.0) * 0.80)
			_cel_slash_b.visible = su >= 0.12
			var su2 := clampf((su - 0.12) / 0.88, 0.0, 1.0)
			var swing_b := 1.0 - pow(1.0 - su2, 2.3)
			_cel_slash_b.scale = Vector3.ONE * lerpf(0.72, 1.00, minf(1.0, su2 * 2.2))
			_cel_slash_b.rotation_degrees = Vector3(-82.0, lerpf(38.0, -40.0, swing_b), lerpf(16.0, -14.0, swing_b))
			if _cel_slash_b_mat != null:
				_cel_slash_b_mat.set_shader_parameter("frame_index", pow(su2, 0.78) * 23.0)
				_cel_slash_b_mat.set_shader_parameter("dissolve", clampf((su2 - 0.66) / 0.34, 0.0, 1.0) * 0.80)
		else:
			_cel_slash_a.visible = false
			_cel_slash_b.visible = false

	for si in range(_shock_rings.size()):
		var sd: Dictionary = _shock_rings[si]
		var sr: MeshInstance3D = sd["node"] as MeshInstance3D
		var smat: StandardMaterial3D = sd["mat"] as StandardMaterial3D
		var trig_t := 0.85 if si == 0 else (1.58 + float(si - 1) * 0.14)
		var local_t := t - trig_t
		if local_t >= 0.0 and local_t <= 0.75:
			var u := local_t / 0.75
			sr.visible = true
			sr.scale = Vector3.ONE * lerpf(0.6, 3.7 + float(si) * 0.75, ease(u, 0.45))
			smat.albedo_color = Color(_accent.r, _accent.g, _accent.b, (1.0 - u) * 0.92)
		else:
			sr.visible = false

	# Card-Specific 4.2s Animation
	match _card_id:
		"SPEC_STORM":
			_animate_storm(t)
		"SPEC_VAMPIRE":
			_animate_vampire(t)
		"SPEC_PHOENIX":
			_animate_phoenix(t)
		"SPEC_CHRONOS":
			_animate_chronos(t)
		_:
			_animate_hybrid_power(t)

	# FPV Stage Lighting, Camera Choreography & Rival Reaction
	if _mode == "fpv_preview":
		var climax_hit := (t >= 1.56 and t <= 2.60)
		if is_instance_valid(_warm_light):
			_warm_light.light_energy = lerpf(_warm_light.light_energy, 0.55 if climax_hit else 2.4, 0.22)
		if is_instance_valid(_fx_light):
			if t >= 1.56 and t <= 1.76:
				_fx_light.light_energy = 11.8
			elif climax_hit:
				_fx_light.light_energy = 4.6 + 3.4 * absf(sin(t * 42.0))
			elif t >= 0.85 and t < 1.56:
				_fx_light.light_energy = 2.6
			else:
				_fx_light.light_energy = 0.0

		if is_instance_valid(_rival_root):
			var recoil := 0.0
			if t >= 1.58 and t <= 2.65:
				recoil = sin(minf((t - 1.58) / 1.07, 1.0) * PI)
			elif t >= 2.65 and t <= 3.45:
				recoil = sin(minf((t - 2.65) / 0.80, 1.0) * PI) * 0.42
			_rival_root.position = _rival_base_pos + Vector3(sin(t * 54.0) * 0.03 * recoil, 0.0, -0.22 * recoil)
			_rival_root.rotation_degrees = Vector3(-16.0 * recoil, 0.0, sin(t * 38.0) * 3.5 * recoil)
			for emat in _rival_eye_mats:
				if is_instance_valid(emat):
					emat.albedo_color = _accent if recoil > 0.2 else Color(0.95, 0.72, 0.32)

		if is_instance_valid(_cam):
			var dur_c := _get_duration()
			var target_fov := _cam_base_fov
			var cam_off := Vector3.ZERO
			var look_off := Vector3.ZERO
			var roll_deg := 0.0
			if t < 1.00:
				var u := ease(t / 1.00, 0.5)
				target_fov = lerpf(48.0, 35.0, u)
				cam_off = Vector3(0.0, -0.14 * u, -0.26 * u)
				look_off = Vector3(0.0, -0.04 * u, 0.18 * u)
			elif t < 2.50:
				var u := (t - 1.00) / 1.50
				target_fov = lerpf(38.0, 56.0, sin(u * PI * 0.5))
				cam_off = Vector3(sin(u * PI) * 0.42, 0.28 * u, -0.10)
				look_off = Vector3(0.0, 0.14, -0.30)
				roll_deg = lerpf(-7.5, 5.0, u)
			elif t < 3.80:
				var u := (t - 2.50) / 1.30
				var ang := lerpf(-0.65, 0.65, u)
				target_fov = 46.0
				cam_off = Vector3(sin(ang) * 0.85, 0.16, cos(ang) * 0.35 - 0.35)
				look_off = Vector3(0.0, 0.12, -0.22)
				roll_deg = sin(ang) * -4.0
			elif t < 4.80:
				var quake := 1.0 - clampf((t - 3.80) / 1.00, 0.0, 1.0) * 0.6
				target_fov = 40.0 + (1.0 - quake) * 6.0
				cam_off = Vector3(0.18 + sin(t * 84.0) * 0.032 * quake, -0.06 + cos(t * 72.0) * 0.025 * quake, -0.24)
				look_off = Vector3(0.0, 0.08, -0.45)
				roll_deg = 4.2 * sin(t * 13.0) * quake
			else:
				var u := ease(clampf((t - 4.80) / maxf(0.4, dur_c - 4.80), 0.0, 1.0), 0.45)
				target_fov = lerpf(46.0, _cam_base_fov, u)
				cam_off = Vector3(0.0, 0.0, lerpf(-0.18, 0.0, u))
			_cam.fov = target_fov
			_cam.look_at_from_position(_cam_base_pos + cam_off, _cam_base_look + look_off, Vector3.UP)
			_cam.rotation_degrees.z += roll_deg


func _animate_storm(t: float) -> void:
	if _with_stinger:
		_fire_beat("storm_shift", 0.85, "power_storm_shift", -2.5, 1.0)
		_fire_beat("storm_impact", 1.56, "power_storm_impact", -1.5, 1.0)
		_fire_beat("storm_tail", 2.60, "power_storm_tail", -3.0, 1.0)
	else:
		_fire_beat("thunder", 1.56, "card_ace_strike", -2.0, 0.88)
		_fire_beat("cleave", 1.58, "anim_sword_cleave", -3.5, 1.15)
		_fire_beat("curse_0", 2.62, "card_deal", -4.5, 1.10)
		_fire_beat("curse_1", 2.80, "card_deal", -4.5, 1.22)
		_fire_beat("curse_2", 2.98, "card_deal", -4.5, 1.35)

	if is_instance_valid(_vortex_root):
		var v_alpha := 0.0
		if t >= 0.22 and t < 1.56:
			v_alpha = clampf((t - 0.22) / 0.72, 0.0, 1.0) * 0.78
		elif t >= 1.56 and t < 2.65:
			v_alpha = 1.0
		elif t >= 2.65:
			v_alpha = clampf(1.0 - (t - 2.65) / 1.10, 0.0, 1.0)
		_vortex_root.visible = v_alpha > 0.01
		_vortex_root.scale = Vector3.ONE * (0.48 + v_alpha * 0.92)
		for vi in range(_vortex_layers.size()):
			var vr := _vortex_layers[vi]
			if is_instance_valid(vr):
				vr.rotation_degrees.y = t * (190.0 + float(vi) * 95.0) * (-1.0 if vi % 2 == 1 else 1.0)
				if vr.has_meta("cel_mat"):
					var cmat := vr.get_meta("cel_mat") as ShaderMaterial
					if cmat != null:
						cmat.set_shader_parameter("frame_index", fmod(t * 10.0 + float(vi) * 3.0, 16.0))
						cmat.set_shader_parameter("opacity", v_alpha * (0.95 if vi == 1 else 0.75))

	if is_instance_valid(_bolts_mesh) and _bolts_mesh_inst != null:
		var bolts_active := (t >= 0.18 and t < 2.65)
		_bolts_mesh_inst.visible = bolts_active
		if bolts_active and (_bolt_rebuild_acc >= 0.038 or t < 0.06):
			_bolt_rebuild_acc = 0.0
			_rebuild_dynamic_bolts(t)

	for sp in _sparks:
		var nd: MeshInstance3D = sp["node"] as MeshInstance3D
		var spmat: ShaderMaterial = sp.get("mat", null) as ShaderMaterial
		if t >= 0.85 and t < 3.25:
			var life := fmod((t - 0.85) * float(sp["spd"]) + float(sp["phase"]), 1.0)
			nd.visible = true
			var a := float(sp["angle"]) + life * 0.55
			var r := float(sp["rad"]) * (0.45 + life * 0.95)
			nd.position = _impact_pos + Vector3(cos(a) * r, life * 1.15, sin(a) * r)
			nd.rotation_degrees = Vector3(0.0, rad_to_deg(-a), 18.0 + life * 90.0)
			if spmat != null:
				spmat.set_shader_parameter("time_sec", t)
				spmat.set_shader_parameter("opacity", sin(life * PI) * 0.95)
				if bool(sp.get("is_cel", false)):
					spmat.set_shader_parameter("frame_index", 6.0 + fmod(life * 8.0, 6.0))
		else:
			nd.visible = false

	for cc in _curse_cards:
		var cnode: Node3D = cc["node"] as Node3D
		var cu := (t - float(cc["delay"])) / 0.52
		if cu >= 0.0 and cu <= 1.0:
			cnode.visible = true
			var eu := ease(cu, 0.55)
			var mid_p := _impact_pos.lerp(_rival_pos, 0.5) + Vector3(float(cc["arc_x"]), 0.44, 0.0)
			var p0 := _impact_pos + Vector3(0.0, 0.12, 0.0)
			cnode.position = p0.lerp(mid_p, eu).lerp(mid_p.lerp(_rival_pos, eu), eu)
			cnode.rotation_degrees = Vector3(lerpf(-60.0, 12.0, eu), eu * 360.0, float(cc["arc_x"]) * 35.0)
			cnode.scale = Vector3.ONE * lerpf(0.85, 1.15, sin(eu * PI))
		else:
			cnode.visible = false


func _animate_vampire(t: float) -> void:
	if _with_stinger:
		_fire_beat("vamp_shift", 0.85, "power_vampire_shift", -2.5, 1.0)
		_fire_beat("vamp_impact", 1.56, "power_vampire_impact", -1.5, 1.0)
		_fire_beat("vamp_tail", 2.35, "power_vampire_tail", -3.0, 1.0)
	else:
		_fire_beat("slash", 1.56, "anim_sword_slash", -2.5, 0.84)
		_fire_beat("siphon", 2.25, "btn_ghost_curse", -4.0, 1.08)

	if is_instance_valid(_blood_moon_mesh):
		var m_u := clampf((t - 0.50) / 0.90, 0.0, 1.0)
		var out_u := 1.0 if t < 3.15 else clampf(1.0 - (t - 3.15) / 0.85, 0.0, 1.0)
		_blood_moon_mesh.visible = m_u > 0.01 and out_u > 0.01
		_blood_moon_mesh.position = _rival_pos + Vector3(0.0, lerpf(-0.15, 0.54, m_u), -0.58)
		var mm := _blood_moon_mesh.material_override as StandardMaterial3D
		if mm != null:
			mm.albedo_color.a = m_u * out_u * 0.90

	for bd in _bats:
		var bn: MeshInstance3D = bd["node"] as MeshInstance3D
		var bmat: ShaderMaterial = bd.get("mat", null) as ShaderMaterial
		if t >= 0.72 and t <= 3.30:
			bn.visible = true
			var u := (t - 0.72) / 2.58
			var a := float(bd["angle"]) + u * 5.2
			var r := float(bd["rad"]) * (0.55 + sin(u * PI) * 0.85)
			bn.position = _impact_pos + Vector3(cos(a) * r, 0.20 + sin(u * PI * 1.4 + float(bd["phase"])) * 0.68, sin(a) * r * 0.65 - 0.14)
			bn.rotation_degrees = Vector3(-8.0, rad_to_deg(cos(a) * 0.35), sin(t * 8.0 + float(bd["phase"])) * 14.0)
			bn.scale = Vector3.ONE * clampf(sin(u * PI) * 2.2, 0.45, 1.15)
			if bmat != null:
				bmat.set_shader_parameter("time_sec", t)
				bmat.set_shader_parameter("opacity", clampf(sin(u * PI) * 2.4, 0.0, 1.0))
		else:
			bn.visible = false

	for od in _siphon_orbs:
		var on: MeshInstance3D = od["node"] as MeshInstance3D
		var omat: ShaderMaterial = od.get("mat", null) as ShaderMaterial
		var ou := (t - float(od["delay"])) / 0.75
		if ou >= 0.0 and ou <= 1.0:
			on.visible = true
			var eu := ease(ou, 0.48)
			var mid := _rival_pos.lerp(_hand_pos, 0.5) + Vector3(float(od["arc_x"]), float(od["arc_y"]), 0.0)
			on.position = _rival_pos.lerp(mid, eu).lerp(mid.lerp(_hand_pos, eu), eu)
			on.scale = Vector3.ONE * sin(eu * PI) * 1.2
			on.rotation_degrees.z = eu * 240.0
			if omat != null:
				omat.set_shader_parameter("opacity", sin(eu * PI))
		else:
			on.visible = false

	if is_instance_valid(_siphon_ribbons_mesh) and _siphon_ribbons_inst != null:
		var rib_on := (t >= 2.10 and t <= 3.65)
		_siphon_ribbons_inst.visible = rib_on
		if rib_on and _bolt_rebuild_acc >= 0.04:
			_bolt_rebuild_acc = 0.0
			_siphon_ribbons_mesh.clear_surfaces()
			_siphon_ribbons_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for ri in range(4):
				_emit_bolt_ribbon(_rival_pos + Vector3(0.0, 0.12, 0.1), _hand_pos, 8, 0.16, 0.024, Color(0.96, 0.14, 0.24, 0.90), _siphon_ribbons_mesh)
			_siphon_ribbons_mesh.surface_end()


func _animate_phoenix(t: float) -> void:
	_fire_beat("burn", 1.56, "card_ace_strike", -2.5, 1.06)
	_fire_beat("soar", 2.10, "anim_sword_cleave", -4.0, 1.28)

	for ci in range(_curse_chains.size()):
		var cd: Dictionary = _curse_chains[ci]
		var ch: MeshInstance3D = cd["node"] as MeshInstance3D
		if t < 0.85:
			ch.visible = true
			ch.position = _impact_pos + Vector3(0.0, 0.12, 0.0)
			ch.scale = Vector3.ONE
		elif t < 1.55:
			var su := (t - 0.85) / 0.70
			ch.visible = true
			ch.position = _impact_pos + Vector3(0.0, 0.12, 0.0) + (cd["dir"] as Vector3) * (su * 0.75)
			ch.scale = Vector3.ONE * (1.0 - su)
		else:
			ch.visible = false

	if is_instance_valid(_flame_pillar) and _flame_pillar_mat != null:
		var fa := 0.0
		if t >= 1.56 and t <= 3.45:
			fa = sin(minf((t - 1.56) / 1.89, 1.0) * PI)
		_flame_pillar.visible = fa > 0.01
		_flame_pillar.rotation_degrees.y = t * 240.0
		_flame_pillar.scale = Vector3(lerpf(0.7, 1.35, fa), 1.0, lerpf(0.7, 1.35, fa))
		_flame_pillar_mat.albedo_color.a = fa * 0.82

	if is_instance_valid(_phoenix_bird_root):
		if t >= 1.45 and t <= 3.75:
			_phoenix_bird_root.visible = true
			var pu := ease(clampf((t - 1.45) / 2.30, 0.0, 1.0), 0.5)
			_phoenix_bird_root.position = _impact_pos + Vector3(0.0, 0.25 + pu * 0.95, -pu * 0.35)
			_phoenix_bird_root.scale = Vector3.ONE * lerpf(0.55, 1.35, sin(pu * PI))
			var flap := sin(t * 13.0) * 26.0
			if is_instance_valid(_phoenix_wing_l):
				_phoenix_wing_l.rotation_degrees.z = flap
			if is_instance_valid(_phoenix_wing_r):
				_phoenix_wing_r.rotation_degrees.z = -flap
		else:
			_phoenix_bird_root.visible = false

	for fd in _feathers:
		var fm: MeshInstance3D = fd["node"] as MeshInstance3D
		var fmat: ShaderMaterial = fd.get("mat", null) as ShaderMaterial
		if t >= 1.28 and t <= 3.85:
			fm.visible = true
			var life := fmod((t - 1.28) * float(fd["spd"]) + float(fd["phase"]), 1.0)
			var a := float(fd["angle"]) + life * 3.8
			var r := float(fd["rad"]) * (0.35 + life * 0.95)
			fm.position = _impact_pos + Vector3(cos(a) * r, 0.12 + life * 1.15, sin(a) * r)
			fm.rotation_degrees = Vector3(-18.0, rad_to_deg(-a), life * 210.0)
			if fmat != null:
				fmat.set_shader_parameter("time_sec", t)
				fmat.set_shader_parameter("opacity", sin(life * PI) * 0.96)
		else:
			fm.visible = false


func _animate_chronos(t: float) -> void:
	_fire_beat("freeze", 1.56, "card_suit_shift", -2.5, 0.78)
	_fire_beat("rewind", 2.30, "anim_parry_clang", -4.0, 1.18)

	var c_in := clampf((t - 0.85) / 0.40, 0.0, 1.0)
	var c_out := 1.0 if t < 3.25 else clampf(1.0 - (t - 3.25) / 0.70, 0.0, 1.0)
	var c_op := c_in * c_out
	var c_pop := ease(c_in, 0.35)
	var sheen_v := fmod(maxf(0.0, t - 1.10) * 0.95, 1.8) - 0.3

	if is_instance_valid(_hero_25d_root):
		_hero_25d_root.visible = c_op > 0.01
		_hero_25d_root.position = _impact_pos + Vector3(0.0, lerpf(0.18, 0.42, c_pop) + sin(t * 2.8) * 0.02, -0.14)
		_hero_25d_root.scale = Vector3.ONE * lerpf(0.55, 0.98, c_pop)
		_hero_25d_root.rotation_degrees = Vector3(-6.0, sin(t * 2.0) * 6.0, 0.0)
		if _hero_25d_mat != null:
			_hero_25d_mat.set_shader_parameter("time_sec", t)
			_hero_25d_mat.set_shader_parameter("opacity", c_op)
			_hero_25d_mat.set_shader_parameter("sheen_pos", sheen_v)
			_hero_25d_mat.set_shader_parameter("flash_white", maxf(0.0, 0.55 - absf(t - 1.62) * 3.5))
		if _hero_25d_shadow_mat != null:
			_hero_25d_shadow_mat.set_shader_parameter("time_sec", t)
			_hero_25d_shadow_mat.set_shader_parameter("opacity", c_op * 0.85)

	if _astro_gears.size() > 0 and is_instance_valid(_astro_gears[0]):
		var ring := _astro_gears[0]
		ring.visible = c_op > 0.01
		ring.position = _impact_pos + Vector3(0.0, lerpf(0.18, 0.46, c_pop), -0.32)
		ring.scale = Vector3.ONE * lerpf(0.50, 1.04, c_pop)
		var ring_rot_z := t * 32.0 if t < 1.56 else (1.56 * 32.0 - (t - 1.56) * 110.0 if t <= 2.95 else (1.56 * 32.0 - 1.39 * 110.0 + (t - 2.95) * 42.0))
		ring.rotation_degrees = Vector3(-6.0, 0.0, ring_rot_z)
	for em in _extra_25d_mats:
		var fmat := em.get("front", null) as ShaderMaterial
		var smat := em.get("shadow", null) as ShaderMaterial
		if fmat != null:
			fmat.set_shader_parameter("time_sec", t)
			fmat.set_shader_parameter("opacity", c_op * 0.96)
			fmat.set_shader_parameter("sheen_pos", sheen_v)
		if smat != null:
			smat.set_shader_parameter("time_sec", t)
			smat.set_shader_parameter("opacity", c_op * 0.80)

	if is_instance_valid(_cel_slash_a) and is_instance_valid(_cel_slash_b):
		if t >= 1.44 and t <= 2.95:
			var su := clampf((t - 1.44) / 1.45, 0.0, 1.0)
			var sw_a := 1.0 - pow(1.0 - su, 2.4)
			_cel_slash_a.visible = true
			_cel_slash_a.scale = Vector3.ONE * lerpf(0.75, 1.02, minf(1.0, su * 2.2))
			_cel_slash_a.rotation_degrees = Vector3(-84.0, lerpf(-30.0, 38.0, sw_a), lerpf(-16.0, 14.0, sw_a))
			if _cel_slash_a_mat != null:
				_cel_slash_a_mat.set_shader_parameter("frame_index", pow(su, 0.72) * 23.0)
				_cel_slash_a_mat.set_shader_parameter("dissolve", clampf((su - 0.68) / 0.32, 0.0, 1.0) * 0.80)
			_cel_slash_b.visible = su >= 0.12
			var su2 := clampf((su - 0.12) / 0.88, 0.0, 1.0)
			var sw_b := 1.0 - pow(1.0 - su2, 2.3)
			_cel_slash_b.scale = Vector3.ONE * lerpf(0.72, 0.98, minf(1.0, su2 * 2.2))
			_cel_slash_b.rotation_degrees = Vector3(-82.0, lerpf(36.0, -38.0, sw_b), lerpf(16.0, -14.0, sw_b))
			if _cel_slash_b_mat != null:
				_cel_slash_b_mat.set_shader_parameter("frame_index", pow(su2, 0.78) * 23.0)
				_cel_slash_b_mat.set_shader_parameter("dissolve", clampf((su2 - 0.66) / 0.34, 0.0, 1.0) * 0.80)
		else:
			_cel_slash_a.visible = false
			_cel_slash_b.visible = false

	for gd in _glass_shards:
		var sh: MeshInstance3D = gd["node"] as MeshInstance3D
		var shmat := gd.get("mat", null) as ShaderMaterial
		if t >= 1.56 and t <= 3.30:
			sh.visible = true
			var frozen := (t >= 1.72 and t <= 2.85)
			var wobble := 0.0 if frozen else sin(t * 9.0) * 0.04
			sh.position = (gd["pos"] as Vector3) + Vector3(0.0, wobble, 0.0)
			sh.rotation_degrees = (gd["rot"] as Vector3) + (Vector3.ZERO if frozen else Vector3(0.0, 0.0, t * 45.0))
			if shmat != null:
				shmat.set_shader_parameter("time_sec", 1.72 if frozen else t)
				shmat.set_shader_parameter("opacity", clampf(sin((t - 1.56) / 1.74 * PI) * 1.4, 0.0, 0.96))
		else:
			sh.visible = false


func _rebuild_dynamic_bolts(t: float) -> void:
	_bolts_mesh.clear_surfaces()
	_bolts_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	if t < 0.85 and is_instance_valid(_hero_card):
		for _i in range(3):
			var p0 := _hero_card.position + Vector3(_rng.randf_range(-0.16, 0.16), _rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.08, 0.08))
			var p1 := _hero_card.position + Vector3(_rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.08, 0.08))
			_emit_bolt_ribbon(p0, p1, 5, 0.045, 0.014, Color(0.55, 0.96, 1.0, 0.94))
	elif t < 1.56:
		var top_c := _impact_pos + Vector3(0.0, 1.20, 0.0)
		for i in range(4):
			var ang := float(i) * (PI * 0.5) + t * 2.4
			var b_pt := _impact_pos + Vector3(cos(ang) * 0.24, 0.02, sin(ang) * 0.24)
			var t_pt := top_c + Vector3(cos(ang + 0.5) * 0.34, 0.0, sin(ang + 0.5) * 0.34)
			_emit_bolt_ribbon(b_pt, t_pt, 7, 0.08, 0.020, Color(0.45, 0.94, 1.0, 0.94))
	else:
		var top_c := _impact_pos + Vector3(0.0, 1.36, 0.0)
		for bi in range(8):
			var a := float(bi) * (TAU / 8.0) + _rng.randf_range(-0.25, 0.25)
			var src := top_c + Vector3(cos(a) * _rng.randf_range(0.08, 0.42), 0.12, sin(a) * _rng.randf_range(0.08, 0.42))
			var dst := _impact_pos + Vector3(_rng.randf_range(-0.22, 0.22), 0.01, _rng.randf_range(-0.22, 0.22))
			# Black ink outer silhouette bolt + bright cyan inner core!
			_emit_bolt_ribbon(src, dst, 9, 0.13, 0.036, Color(0.02, 0.03, 0.05, 0.96))
			var col := Color(0.95, 0.99, 1.0, 1.0) if (bi % 2 == 0) else Color(0.32, 0.92, 1.0, 0.96)
			_emit_bolt_ribbon(src, dst, 9, 0.13, 0.022 if bi < 4 else 0.014, col)
		for _ci in range(3):
			var r_dst := _rival_pos + Vector3(_rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.08, 0.24), _rng.randf_range(-0.10, 0.10))
			_emit_bolt_ribbon(_impact_pos + Vector3(0.0, 0.08, 0.0), r_dst, 8, 0.12, 0.034, Color(0.02, 0.03, 0.05, 0.96))
			_emit_bolt_ribbon(_impact_pos + Vector3(0.0, 0.08, 0.0), r_dst, 8, 0.12, 0.022, Color(0.55, 0.97, 1.0, 0.98))

	_bolts_mesh.surface_end()


func _emit_bolt_ribbon(p_start: Vector3, p_end: Vector3, segs: int, jitter: float, width: float, col: Color, target_mesh: ImmediateMesh = null) -> void:
	var mesh_out := target_mesh if target_mesh != null else _bolts_mesh
	if mesh_out == null:
		return
	var pts: Array[Vector3] = [p_start]
	for si in range(1, segs):
		var frac := float(si) / float(segs)
		var base := p_start.lerp(p_end, frac)
		var env := sin(frac * PI)
		base += Vector3(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter * 0.5, jitter * 0.5), _rng.randf_range(-jitter, jitter)) * env
		pts.append(base)
	pts.append(p_end)

	var cam_pos := _cam.global_position if is_instance_valid(_cam) else (_impact_pos + Vector3(0.0, 1.2, 1.5))
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var dir := (b - a).normalized()
		var to_cam := (cam_pos - a).normalized()
		var side := dir.cross(to_cam).normalized() * width
		if side.length_squared() < 0.00001:
			side = Vector3.RIGHT * width
		mesh_out.surface_set_color(col)
		mesh_out.surface_add_vertex(a - side)
		mesh_out.surface_set_color(col)
		mesh_out.surface_add_vertex(a + side)
		mesh_out.surface_set_color(col)
		mesh_out.surface_add_vertex(b + side)

		mesh_out.surface_set_color(col)
		mesh_out.surface_add_vertex(a - side)
		mesh_out.surface_set_color(col)
		mesh_out.surface_add_vertex(b + side)
		mesh_out.surface_set_color(col)
		mesh_out.surface_add_vertex(b - side)


func _draw_overlay() -> void:
	if not is_instance_valid(_overlay):
		return
	var vs := _overlay.size
	if vs.x < 20.0 or vs.y < 20.0:
		return
	var cx := vs.x * 0.5
	var cy := vs.y * 0.5
	var meta: Dictionary = CARD_META[_card_id]
	var title_txt := str(meta["title"])
	var sub_txt := str(meta["sub"])

	# 140ms Stark Hand-Drawn Ink Impact Frame & Radiating Speed-Lines (1.56s - 1.76s)
	if _t >= 1.56 and _t <= 1.78:
		var iu := (_t - 1.56) / 0.22
		var flash_a := (1.0 - iu) * 0.78
		if _t < 1.63:
			_overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.03, 0.62))
		_overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(_accent.r, _accent.g, _accent.b, flash_a * 0.42))
		for li in range(36):
			var ang := float(li) * (TAU / 36.0) + 0.06 * float(li % 3)
			var r0 := lerpf(55.0, 150.0, float(li % 4) / 3.0)
			var r1 := maxf(vs.x, vs.y) * 0.90
			var p0 := Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r0
			var p1 := Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r1
			_overlay.draw_line(p0, p1, Color(0.02, 0.02, 0.02, flash_a), 4.0 if li % 3 == 0 else 2.0)
			_overlay.draw_line(p0, p1, Color(_accent.r, _accent.g, _accent.b, flash_a), 2.0 if li % 2 == 0 else 1.0)

	# Chronos Desaturated Time-Freeze Wash
	if _card_id == "SPEC_CHRONOS" and _t >= 1.60 and _t <= 2.95:
		var fz_a := sin(clampf((_t - 1.60) / 1.35, 0.0, 1.0) * PI) * 0.26
		_overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.18, 0.34, 0.56, fz_a))

	# Calligraphic Hand-Drawn Banner (1.62s - 3.65s) — placed near upper edge so 2.5D hero art stays unobscured
	if _t >= 1.62 and _t <= 3.65 and _font_disp != null:
		var bu := clampf((_t - 1.62) / 0.22, 0.0, 1.0)
		var out_a := 1.0 if _t < 3.10 else clampf(1.0 - (_t - 3.10) / 0.55, 0.0, 1.0)
		var slam_sc := lerpf(1.36, 1.0, ease(bu, 0.35))
		var banner_y := vs.y * 0.13
		var f_sz := int(round(36.0 * slam_sc))

		var slash_w := vs.x * 0.44 * bu
		var slash_pts := PackedVector2Array([
			Vector2(cx - slash_w, banner_y - 20.0),
			Vector2(cx + slash_w * 0.94, banner_y - 24.0),
			Vector2(cx + slash_w, banner_y + 18.0),
			Vector2(cx - slash_w * 0.92, banner_y + 22.0),
		])
		_overlay.draw_colored_polygon(slash_pts, Color(0.03, 0.03, 0.04, 0.88 * out_a))
		_overlay.draw_polyline(slash_pts, Color(_accent.r, _accent.g, _accent.b, 0.95 * out_a), 2.4, true)

		var text_pos := Vector2(cx - 320.0, banner_y + 10.0)
		_overlay.draw_string(_font_disp, text_pos + Vector2(3.0, 3.0), title_txt, HORIZONTAL_ALIGNMENT_CENTER, 640, f_sz, Color(0.02, 0.02, 0.02, 0.96 * out_a))
		_overlay.draw_string(_font_disp, text_pos, title_txt, HORIZONTAL_ALIGNMENT_CENTER, 640, f_sz, Color(_accent.r, _accent.g, _accent.b, out_a))

		if _font_body != null:
			_overlay.draw_string(_font_body, Vector2(cx - 280.0, banner_y + 38.0), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 560, 15, Color(0.98, 0.88, 0.48, out_a))


func _make_hybrid_mat(col: Color, alpha: float = 0.94) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	return mat


func _build_hybrid_power_rig(card_id: String, tex_path: String) -> void:
	_hybrid_stage_root = Node3D.new()
	_hybrid_stage_root.position = _impact_pos
	_fx_root.add_child(_hybrid_stage_root)
	_hybrid_spinners.clear()
	_hybrid_motes.clear()
	_hybrid_pillars.clear()

	var main_mat := _make_hybrid_mat(_accent, 0.95)
	var trim_mat := _make_hybrid_mat(Color(1.0, 0.90, 0.48), 0.96)
	var dark_mat := _make_hybrid_mat(Color(0.10, 0.08, 0.12), 0.94)

	match card_id:
		"SPEC_MIRROR":
			# Towering Living 2.5D Gothic Twin Mirror Gate Diorama (anim_mode=3: liquid-mirror ripple + runes) + 2.5D Shards
			var m_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_MIRROR_25D, 0.88, 0.92, Color(0.42, 0.90, 1.0, 1.0), Color(0.96, 0.99, 1.0, 1.0), m_mats, 3)
			_hero_25d_mat = m_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = m_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.42, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 14.0, "bob": 0.04})

			var ma := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.28, 1.28, Color(0.45, 0.92, 1.0, 1.0), Color(0.84, 0.98, 1.0, 1.0), 2.35, 2.9, 4)
			_cel_slash_a = ma["node"] as MeshInstance3D
			_cel_slash_a_mat = ma["mat"] as ShaderMaterial
			_cel_slash_a_mat.set_shader_parameter("royal_shift", 0.0)
			_cel_slash_a.position = _impact_pos + Vector3(0.0, 0.04, 0.06)
			_cel_slash_a.rotation_degrees = Vector3(-84.0, 30.0, -16.0)
			_cel_slash_a.visible = false
			_fx_root.add_child(_cel_slash_a)

			var mb := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.16, 1.16, Color(0.78, 0.96, 1.0, 1.0), Color(0.88, 0.99, 1.0, 1.0), 2.15, 6.4, 5)
			_cel_slash_b = mb["node"] as MeshInstance3D
			_cel_slash_b_mat = mb["mat"] as ShaderMaterial
			_cel_slash_b_mat.set_shader_parameter("flip_x", 1.0)
			_cel_slash_b_mat.set_shader_parameter("royal_shift", 0.0)
			_cel_slash_b.position = _impact_pos + Vector3(0.0, 0.05, 0.08)
			_cel_slash_b.rotation_degrees = Vector3(-82.0, -34.0, 16.0)
			_cel_slash_b.visible = false
			_fx_root.add_child(_cel_slash_b)

			for mi in range(2):
				var mc := _create_card_quad_node(tex_path, CARD_BACK_TEX, _accent, Vector2(0.18, 0.26))
				mc.position = Vector3((-0.44 if mi == 0 else 0.44), 0.36, 0.04)
				_hybrid_stage_root.add_child(mc)
				_hybrid_spinners.append({"node": mc, "spin_y": 140.0 if mi == 0 else -140.0, "bob": 0.08})

			# 24 Hand-Drawn 2.5D Shattered Ornate Mirror Crystal Shards (NO PrismMesh vectors!)
			for si in range(24):
				var sh := _make_25d_particle_quad(TEX_MIRROR_SHARD_25D, Vector2(0.15, 0.15), Color(0.56, 0.94, 1.0, 1.0), Color(0.96, 0.99, 1.0, 1.0), 3, float(si) * 0.2, 6)
				var nd := sh["node"] as MeshInstance3D
				nd.visible = false
				_hybrid_stage_root.add_child(nd)
				_hybrid_motes.append({
					"node": nd,
					"mat": sh["mat"] as ShaderMaterial,
					"pattern": "burst",
					"angle": float(si) * (TAU / 24.0) + _rng.randf_range(-0.2, 0.2),
					"rad": _rng.randf_range(0.28, 0.90),
					"spd": _rng.randf_range(0.7, 1.5),
					"phase": _rng.randf(),
				})

		"SPEC_ALCHEMIST":
			# Counter-rotating Gilded Transmutation Bezels + Glowing Elixir Core + Layered Emerald/Gold Vapor, Runes & Ink Sparks
			for ri in range(2):
				var tr := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.42 + float(ri) * 0.12; tm.outer_radius = 0.445 + float(ri) * 0.12; tm.rings = 36; tm.ring_segments = 8
				tr.mesh = tm
				tr.position = Vector3(0.0, 0.10 + float(ri) * 0.16, 0.0)
				tr.material_override = trim_mat
				_apply_ink_outline(tr, 0.010)
				_hybrid_stage_root.add_child(tr)
				_hybrid_spinners.append({"node": tr, "spin_y": 160.0 if ri == 0 else -190.0, "bob": 0.04})
			var flask := MeshInstance3D.new()
			var sphm := SphereMesh.new()
			sphm.radius = 0.095; sphm.height = 0.19
			flask.mesh = sphm
			flask.position = Vector3(0.0, 0.34, 0.0)
			flask.material_override = _make_hybrid_mat(Color(0.55, 1.0, 0.48), 0.72)
			_apply_ink_outline(flask, 0.011)
			_hybrid_stage_root.add_child(flask)
			_hybrid_pillars.append(flask)

			# Added surrounding alchemy halo vapor, carved rune ring & rising hand-drawn ink sparks
			for ai in range(3):
				var is_rune := (ai == 1)
				var m_cfg := _make_cel_quad(
					TEX_IMPACT_SHEET if is_rune else TEX_MIST_SHEET,
					Vector2(4.0, 4.0),
					1.36 - float(ai) * 0.24,
					1.36 - float(ai) * 0.24,
					Color(0.56, 0.98, 0.44, 1.0) if ai != 2 else Color(1.0, 0.86, 0.34, 1.0),
					Color(0.76, 1.0, 0.68, 0.82),
					2.1 if is_rune else 1.25,
					1.9 + float(ai) * 2.5,
					2 + ai
				)
				var mi := m_cfg["node"] as MeshInstance3D
				var mmat := m_cfg["mat"] as ShaderMaterial
				mmat.set_shader_parameter("loop_sheet", 1.0)
				mmat.set_shader_parameter("blend_next", 0.55)
				mi.position = Vector3(0.0, 0.08 + float(ai) * 0.16, 0.0)
				mi.rotation_degrees = Vector3(-90.0, float(ai) * 40.0, 0.0)
				_hybrid_stage_root.add_child(mi)
				_alc_mist_rings.append({"node": mi, "mat": mmat, "spin": (90.0 if ai % 2 == 0 else -110.0)})

			var alc_slash := _make_cel_quad(TEX_SLASH_SHEET, Vector2(6.0, 4.0), 1.26, 1.26, Color(0.45, 0.96, 0.48, 1.0), Color(0.84, 1.0, 0.72, 1.0), 2.35, 5.4, 4)
			_cel_slash_a = alc_slash["node"] as MeshInstance3D
			_cel_slash_a_mat = alc_slash["mat"] as ShaderMaterial
			_cel_slash_a_mat.set_shader_parameter("royal_shift", 0.0)
			_cel_slash_a.position = _impact_pos + Vector3(0.0, 0.04, 0.06)
			_cel_slash_a.rotation_degrees = Vector3(-84.0, 24.0, -12.0)
			_cel_slash_a.visible = false
			_fx_root.add_child(_cel_slash_a)

			# 28 Hand-Drawn Golden Ink Sparks rising cleanly (NO SphereMesh balls!)
			for si in range(28):
				var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(1.0, 0.88, 0.34, 1.0), Color(1.0, 0.92, 0.55, 1.0), 2.30, float(si) * 0.4, 6)
				var nd := ic["node"] as MeshInstance3D
				var smat := ic["mat"] as ShaderMaterial
				smat.set_shader_parameter("royal_shift", 1.0)
				smat.set_shader_parameter("frame_index", float((si % 8) + 2))
				nd.visible = false
				_hybrid_stage_root.add_child(nd)
				_hybrid_motes.append({
					"node": nd,
					"mat": smat,
					"pattern": "rise",
					"angle": float(si) * (TAU / 28.0) + _rng.randf_range(-0.2, 0.2),
					"rad": _rng.randf_range(0.24, 0.86),
					"spd": _rng.randf_range(0.8, 1.6),
					"phase": _rng.randf(),
				})

		"SPEC_ORACLE":
			# Living 2.5D Illuminated Third Eye (anim_mode=8) + Cel Slashes + 24 Orbiting Tarot Sparks
			var o_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_ORACLE_25D, 0.88, 0.88, Color(0.76, 0.56, 1.0, 1.0), Color(0.98, 0.96, 1.0, 1.0), o_mats, 8)
			_hero_25d_mat = o_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = o_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.44, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 14.0, "bob": 0.05})
			_attach_cel_slashes(Color(0.76, 0.56, 1.0, 1.0), Color(0.92, 0.84, 1.0, 1.0), Color(1.0, 0.84, 0.34, 1.0), Color(1.0, 0.94, 0.72, 1.0), 0.4)
			for si in range(24):
				var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(0.80, 0.58, 1.0, 1.0), Color(1.0, 0.92, 0.65, 1.0), 2.35, float(si) * 0.4, 6)
				var nd := ic["node"] as MeshInstance3D
				var smat := ic["mat"] as ShaderMaterial
				smat.set_shader_parameter("royal_shift", 0.5)
				smat.set_shader_parameter("frame_index", float((si % 8) + 2))
				nd.visible = false
				_hybrid_stage_root.add_child(nd)
				_hybrid_motes.append({"node": nd, "mat": smat, "is_cel": true, "pattern": "orbit", "angle": float(si) * (TAU / 24.0), "rad": _rng.randf_range(0.32, 0.88), "spd": _rng.randf_range(0.8, 1.5), "phase": _rng.randf()})

		"SPEC_MIDAS":
			# Living 2.5D Gilded Gauntlet & Overflowing Molten Gold Chalice (anim_mode=6) + Florins + Ink Sparks
			var m_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_MIDAS_25D, 0.88, 0.92, Color(1.0, 0.84, 0.24, 1.0), Color(1.0, 0.98, 0.92, 1.0), m_mats, 6)
			_hero_25d_mat = m_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = m_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.44, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 14.0, "bob": 0.04})
			_attach_cel_slashes(Color(1.0, 0.84, 0.24, 1.0), Color(1.0, 0.94, 0.68, 1.0), Color(1.0, 0.68, 0.14, 1.0), Color(1.0, 0.88, 0.50, 1.0), 1.0)
			for ci in range(22):
				var fc := _make_25d_particle_quad(TEX_GOLD_FLORIN_25D, Vector2(0.14, 0.14), Color(1.0, 0.84, 0.24, 1.0), Color(1.0, 0.98, 0.92, 1.0), 6, float(ci) * 0.2, 6)
				var fnd := fc["node"] as MeshInstance3D
				fnd.visible = false
				_hybrid_stage_root.add_child(fnd)
				_hybrid_motes.append({"node": fnd, "mat": fc["mat"] as ShaderMaterial, "pattern": "orbit", "angle": float(ci) * (TAU / 22.0), "rad": _rng.randf_range(0.28, 0.92), "spd": _rng.randf_range(0.8, 1.6), "phase": _rng.randf()})
			for si in range(12):
				var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(1.0, 0.88, 0.34, 1.0), Color(1.0, 0.94, 0.65, 1.0), 2.35, float(si) * 0.5, 6)
				var nd := ic["node"] as MeshInstance3D
				var smat := ic["mat"] as ShaderMaterial
				smat.set_shader_parameter("royal_shift", 1.0)
				smat.set_shader_parameter("frame_index", float((si % 8) + 2))
				nd.visible = false
				_hybrid_stage_root.add_child(nd)
				_hybrid_motes.append({"node": nd, "mat": smat, "is_cel": true, "pattern": "rise", "angle": float(si) * (TAU / 12.0), "rad": _rng.randf_range(0.26, 0.86), "spd": _rng.randf_range(0.9, 1.6), "phase": _rng.randf()})

		"SPEC_JESTER":
			# Living 2.5D Sinister Jester Mask (anim_mode=9) + 6 Orbiting 3D Cards + 20 Torn Jester Cards
			var j_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_JESTER_25D, 0.88, 0.88, Color(0.96, 0.42, 0.92, 1.0), Color(1.0, 0.97, 0.94, 1.0), j_mats, 9)
			_hero_25d_mat = j_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = j_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.44, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 18.0, "bob": 0.06})
			_attach_cel_slashes(Color(0.96, 0.42, 0.92, 1.0), Color(1.0, 0.78, 0.96, 1.0), Color(1.0, 0.84, 0.28, 1.0), Color(1.0, 0.94, 0.65, 1.0), 0.5)
			for ci in range(6):
				var a := float(ci) * (TAU / 6.0)
				var jc := _create_card_quad_node(CARD_BACK_TEX, CARD_BACK_TEX, _accent if ci % 2 == 0 else Color(1.0, 0.82, 0.28), Vector2(0.14, 0.20))
				jc.position = Vector3(cos(a) * 0.44, 0.36 + float(ci % 3) * 0.10, sin(a) * 0.44)
				_hybrid_stage_root.add_child(jc)
				_hybrid_spinners.append({"node": jc, "spin_y": 240.0, "bob": 0.12, "phase": a})
			for ti in range(20):
				var tc := _make_25d_particle_quad(TEX_JESTER_CARD_25D, Vector2(0.15, 0.15), Color(0.96, 0.48, 0.94, 1.0), Color(1.0, 0.96, 0.94, 1.0), 9, float(ti) * 0.2, 6)
				var tnd := tc["node"] as MeshInstance3D
				tnd.visible = false
				_hybrid_stage_root.add_child(tnd)
				_hybrid_motes.append({"node": tnd, "mat": tc["mat"] as ShaderMaterial, "pattern": "burst", "angle": float(ti) * (TAU / 20.0), "rad": _rng.randf_range(0.30, 0.92), "spd": _rng.randf_range(0.8, 1.5), "phase": _rng.randf()})

		"SPEC_HEX":
			# Living 2.5D Cursed Grimoire (anim_mode=10) + Swirling Violet Mist + 22 Striking Iron Thorns
			var h_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_HEX_25D, 0.86, 0.90, Color(0.68, 0.28, 1.0, 1.0), Color(0.98, 0.96, 1.0, 1.0), h_mats, 10)
			_hero_25d_mat = h_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = h_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.44, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 14.0, "bob": 0.05})
			_attach_cel_slashes(Color(0.68, 0.28, 1.0, 1.0), Color(0.88, 0.68, 1.0, 1.0), Color(0.45, 0.16, 0.85, 1.0), Color(0.82, 0.56, 1.0, 1.0), 0.0)
			for ai in range(2):
				var is_rune := (ai == 1)
				var m_cfg := _make_cel_quad(TEX_IMPACT_SHEET if is_rune else TEX_MIST_SHEET, Vector2(4.0, 4.0), 1.38 - float(ai) * 0.22, 1.38 - float(ai) * 0.22, Color(0.68, 0.28, 1.0, 1.0), Color(0.84, 0.64, 1.0, 0.82), 2.1 if is_rune else 1.25, 2.3 + float(ai) * 2.1, 2 + ai)
				var mi := m_cfg["node"] as MeshInstance3D
				var mmat := m_cfg["mat"] as ShaderMaterial
				mmat.set_shader_parameter("loop_sheet", 1.0)
				mmat.set_shader_parameter("blend_next", 0.55)
				mi.position = Vector3(0.0, 0.08 + float(ai) * 0.14, 0.0)
				mi.rotation_degrees = Vector3(-90.0, float(ai) * 45.0, 0.0)
				_hybrid_stage_root.add_child(mi)
				_alc_mist_rings.append({"node": mi, "mat": mmat, "spin": (85.0 if ai % 2 == 0 else -110.0)})
			for hi in range(22):
				var hc := _make_25d_particle_quad(TEX_HEX_THORN_25D, Vector2(0.15, 0.15), Color(0.72, 0.30, 1.0, 1.0), Color(0.96, 0.94, 1.0, 1.0), 10, float(hi) * 0.2, 6)
				var hnd := hc["node"] as MeshInstance3D
				hnd.visible = false
				_hybrid_stage_root.add_child(hnd)
				_hybrid_motes.append({"node": hnd, "mat": hc["mat"] as ShaderMaterial, "pattern": "strike", "angle": float(hi) * (TAU / 22.0), "rad": _rng.randf_range(0.28, 0.88), "spd": _rng.randf_range(0.85, 1.55), "phase": _rng.randf()})

		"SPEC_MAGNET":
			# Living 2.5D Runic Horseshoe Magnet (anim_mode=11) + 5 Attracted 3D Cards + 24 Polarity Sparks
			var mg_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_MAGNET_25D, 0.86, 0.86, Color(0.94, 0.34, 0.38, 1.0), Color(1.0, 0.97, 0.96, 1.0), mg_mats, 11)
			_hero_25d_mat = mg_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = mg_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.44, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 14.0, "bob": 0.05})
			_attach_cel_slashes(Color(0.94, 0.34, 0.38, 1.0), Color(1.0, 0.72, 0.75, 1.0), Color(0.32, 0.92, 1.0, 1.0), Color(0.84, 0.98, 1.0, 1.0), 0.0)
			for ai in range(5):
				var ac := _create_card_quad_node(CARD_BACK_TEX, tex_path, _accent, Vector2(0.13, 0.19))
				ac.position = Vector3((float(ai) - 2.0) * 0.26, 0.32, -0.45)
				_hybrid_stage_root.add_child(ac)
				_hybrid_spinners.append({"node": ac, "spin_y": 180.0, "bob": 0.08, "phase": float(ai)})
			for si in range(24):
				var col_sp := Color(0.35, 0.92, 1.0, 1.0) if si % 2 == 0 else Color(1.0, 0.32, 0.38, 1.0)
				var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, col_sp, Color(0.96, 0.96, 1.0, 1.0), 2.35, float(si) * 0.4, 6)
				var nd := ic["node"] as MeshInstance3D
				var smat := ic["mat"] as ShaderMaterial
				smat.set_shader_parameter("frame_index", float((si % 8) + 2))
				nd.visible = false
				_hybrid_stage_root.add_child(nd)
				_hybrid_motes.append({"node": nd, "mat": smat, "is_cel": true, "pattern": "orbit", "angle": float(si) * (TAU / 24.0), "rad": _rng.randf_range(0.28, 0.88), "spd": _rng.randf_range(0.9, 1.7), "phase": _rng.randf()})

		"SPEC_SHIELD":
			# Twin Symmetrical Angled Living 2.5D Bastion Shields (anim_mode=12) + 24 Golden Barrier Sparks
			var sh_mats_l := {}
			_hero_25d_root = _make_25d_diorama(TEX_SHIELD_25D, 0.72, 0.82, Color(0.50, 0.90, 1.0, 1.0), Color(0.96, 0.99, 1.0, 1.0), sh_mats_l, 12)
			_hero_25d_mat = sh_mats_l.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = sh_mats_l.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(-0.32, 0.40, 0.08)
			_hero_25d_root.rotation_degrees = Vector3(-6.0, -18.0, 0.0)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 8.0, "bob": 0.04})

			var sh_mats_r := {}
			var shield_r := _make_25d_diorama(TEX_SHIELD_25D, 0.72, 0.82, Color(1.0, 0.86, 0.36, 1.0), Color(1.0, 0.98, 0.92, 1.0), sh_mats_r, 12)
			shield_r.position = Vector3(0.32, 0.40, 0.08)
			shield_r.rotation_degrees = Vector3(-6.0, 18.0, 0.0)
			_hybrid_stage_root.add_child(shield_r)
			_hybrid_spinners.append({"node": shield_r, "spin_y": -8.0, "bob": 0.04, "phase": 1.2})
			_extra_25d_mats.append(sh_mats_r)

			_attach_cel_slashes(Color(0.50, 0.90, 1.0, 1.0), Color(0.84, 0.98, 1.0, 1.0), Color(1.0, 0.86, 0.36, 1.0), Color(1.0, 0.94, 0.65, 1.0), 0.5)
			for si in range(24):
				var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(1.0, 0.86, 0.36, 1.0), Color(0.92, 0.98, 1.0, 1.0), 2.35, float(si) * 0.4, 6)
				var nd := ic["node"] as MeshInstance3D
				var smat := ic["mat"] as ShaderMaterial
				smat.set_shader_parameter("royal_shift", 0.8)
				smat.set_shader_parameter("frame_index", float((si % 8) + 2))
				nd.visible = false
				_hybrid_stage_root.add_child(nd)
				_hybrid_motes.append({"node": nd, "mat": smat, "is_cel": true, "pattern": "rise", "angle": float(si) * (TAU / 24.0), "rad": _rng.randf_range(0.28, 0.86), "spd": _rng.randf_range(0.8, 1.5), "phase": _rng.randf()})

		"SPEC_GAMBLER":
			# Spinning Living 2.5D Wheel of Fortune + Foreground Tumbling Bone Dice (anim_mode=13) + Florin Burst
			var gw_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_GAMBLER_WHEEL_25D, 0.98, 0.98, Color(1.0, 0.80, 0.28, 1.0), Color(1.0, 0.98, 0.92, 1.0), gw_mats, 13)
			_hero_25d_mat = gw_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = gw_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.46, -0.28)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_z": 115.0, "bob": 0.03})

			var gd_mats := {}
			var dice_fg := _make_25d_diorama(TEX_GAMBLER_DICE_25D, 0.56, 0.56, Color(1.0, 0.82, 0.30, 1.0), Color(1.0, 0.98, 0.94, 1.0), gd_mats, 13)
			dice_fg.position = Vector3(0.0, 0.38, -0.06)
			_hybrid_stage_root.add_child(dice_fg)
			_hybrid_spinners.append({"node": dice_fg, "spin_y": 24.0, "bob": 0.09, "phase": 0.6})
			_extra_25d_mats.append(gd_mats)

			_attach_cel_slashes(Color(1.0, 0.78, 0.28, 1.0), Color(1.0, 0.94, 0.68, 1.0), Color(0.95, 0.34, 0.34, 1.0), Color(1.0, 0.82, 0.72, 1.0), 1.0)
			for ci in range(22):
				var use_florin := (ci % 2 == 0)
				if use_florin:
					var fc := _make_25d_particle_quad(TEX_GOLD_FLORIN_25D, Vector2(0.14, 0.14), Color(1.0, 0.84, 0.24, 1.0), Color(1.0, 0.98, 0.92, 1.0), 13, float(ci) * 0.2, 6)
					var fnd := fc["node"] as MeshInstance3D
					fnd.visible = false
					_hybrid_stage_root.add_child(fnd)
					_hybrid_motes.append({"node": fnd, "mat": fc["mat"] as ShaderMaterial, "pattern": "burst", "angle": float(ci) * (TAU / 22.0), "rad": _rng.randf_range(0.28, 0.92), "spd": _rng.randf_range(0.8, 1.6), "phase": _rng.randf()})
				else:
					var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(1.0, 0.86, 0.32, 1.0), Color(1.0, 0.94, 0.65, 1.0), 2.35, float(ci) * 0.4, 6)
					var nd := ic["node"] as MeshInstance3D
					var smat := ic["mat"] as ShaderMaterial
					smat.set_shader_parameter("royal_shift", 1.0)
					smat.set_shader_parameter("frame_index", float((ci % 8) + 2))
					nd.visible = false
					_hybrid_stage_root.add_child(nd)
					_hybrid_motes.append({"node": nd, "mat": smat, "is_cel": true, "pattern": "burst", "angle": float(ci) * (TAU / 22.0), "rad": _rng.randf_range(0.28, 0.92), "spd": _rng.randf_range(0.8, 1.6), "phase": _rng.randf()})

		"SPEC_PLAGUE":
			# Living 2.5D Frost Plague Skull Mask (anim_mode=14) + Swirling Ice Mist + 26 Frost Crystal Shards
			var pl_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_PLAGUE_25D, 0.86, 0.90, Color(0.42, 0.94, 0.72, 1.0), Color(0.95, 0.99, 0.98, 1.0), pl_mats, 14)
			_hero_25d_mat = pl_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = pl_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.44, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 14.0, "bob": 0.05})
			_attach_cel_slashes(Color(0.42, 0.94, 0.72, 1.0), Color(0.78, 1.0, 0.92, 1.0), Color(0.58, 0.96, 1.0, 1.0), Color(0.86, 1.0, 1.0, 1.0), 0.0)
			for ai in range(2):
				var is_rune := (ai == 1)
				var m_cfg := _make_cel_quad(TEX_IMPACT_SHEET if is_rune else TEX_MIST_SHEET, Vector2(4.0, 4.0), 1.40 - float(ai) * 0.24, 1.40 - float(ai) * 0.24, Color(0.42, 0.94, 0.78, 1.0), Color(0.76, 1.0, 0.94, 0.82), 2.0 if is_rune else 1.25, 3.1 + float(ai) * 2.0, 2 + ai)
				var mi := m_cfg["node"] as MeshInstance3D
				var mmat := m_cfg["mat"] as ShaderMaterial
				mmat.set_shader_parameter("loop_sheet", 1.0)
				mmat.set_shader_parameter("blend_next", 0.55)
				mi.position = Vector3(0.0, 0.08 + float(ai) * 0.14, 0.0)
				mi.rotation_degrees = Vector3(-90.0, float(ai) * 40.0, 0.0)
				_hybrid_stage_root.add_child(mi)
				_alc_mist_rings.append({"node": mi, "mat": mmat, "spin": (85.0 if ai % 2 == 0 else -105.0)})
			for fi in range(26):
				var fc := _make_25d_particle_quad(TEX_FROST_CRYSTAL_25D, Vector2(0.15, 0.15), Color(0.42, 0.94, 0.78, 1.0), Color(0.95, 0.99, 1.0, 1.0), 14, float(fi) * 0.2, 6)
				var fnd := fc["node"] as MeshInstance3D
				fnd.visible = false
				_hybrid_stage_root.add_child(fnd)
				_hybrid_motes.append({"node": fnd, "mat": fc["mat"] as ShaderMaterial, "pattern": "orbit", "angle": float(fi) * (TAU / 26.0), "rad": _rng.randf_range(0.30, 0.92), "spd": _rng.randf_range(0.75, 1.45), "phase": _rng.randf()})

		_:
			# SPEC_CROWN (and clean fallback): Living 2.5D Imperial Sovereign Crown (anim_mode=15) + Royal Gold Florins & Sparks
			var cr_mats := {}
			_hero_25d_root = _make_25d_diorama(TEX_CROWN_25D, 0.88, 0.88, Color(1.0, 0.88, 0.36, 1.0), Color(1.0, 0.98, 0.94, 1.0), cr_mats, 15)
			_hero_25d_mat = cr_mats.get("front", null) as ShaderMaterial
			_hero_25d_shadow_mat = cr_mats.get("shadow", null) as ShaderMaterial
			_hero_25d_root.position = Vector3(0.0, 0.44, -0.18)
			_hybrid_stage_root.add_child(_hero_25d_root)
			_hybrid_spinners.append({"node": _hero_25d_root, "spin_y": 14.0, "bob": 0.05})
			_attach_cel_slashes(Color(1.0, 0.88, 0.36, 1.0), Color(1.0, 0.95, 0.72, 1.0), Color(0.98, 0.24, 0.28, 1.0), Color(1.0, 0.78, 0.74, 1.0), 1.0)
			for si in range(26):
				if si % 2 == 0:
					var fc := _make_25d_particle_quad(TEX_GOLD_FLORIN_25D, Vector2(0.14, 0.14), Color(1.0, 0.88, 0.34, 1.0), Color(1.0, 0.98, 0.92, 1.0), 15, float(si) * 0.2, 6)
					var fnd := fc["node"] as MeshInstance3D
					fnd.visible = false
					_hybrid_stage_root.add_child(fnd)
					_hybrid_motes.append({"node": fnd, "mat": fc["mat"] as ShaderMaterial, "pattern": "rise", "angle": float(si) * (TAU / 26.0), "rad": _rng.randf_range(0.28, 0.90), "spd": _rng.randf_range(0.8, 1.5), "phase": _rng.randf()})
				else:
					var ic := _make_cel_quad(TEX_INK_SPARKS_SHEET, Vector2(4.0, 4.0), 0.16, 0.16, Color(1.0, 0.88, 0.36, 1.0), Color(1.0, 0.94, 0.65, 1.0), 2.35, float(si) * 0.4, 6)
					var nd := ic["node"] as MeshInstance3D
					var smat := ic["mat"] as ShaderMaterial
					smat.set_shader_parameter("royal_shift", 1.0)
					smat.set_shader_parameter("frame_index", float((si % 8) + 2))
					nd.visible = false
					_hybrid_stage_root.add_child(nd)
					_hybrid_motes.append({"node": nd, "mat": smat, "is_cel": true, "pattern": "rise", "angle": float(si) * (TAU / 26.0), "rad": _rng.randf_range(0.28, 0.90), "spd": _rng.randf_range(0.8, 1.5), "phase": _rng.randf()})


func _spawn_hybrid_motes(count: int, mesh: Mesh, mesh_scale: Vector3, mat: Material, pattern: String) -> void:
	for i in range(count):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = mesh_scale
		mi.material_override = mat
		_apply_ink_outline(mi, 0.008)
		mi.visible = false
		_hybrid_stage_root.add_child(mi)
		_hybrid_motes.append({
			"node": mi,
			"pattern": pattern,
			"angle": float(i) * (TAU / float(maxi(1, count))) + _rng.randf_range(-0.2, 0.2),
			"rad": _rng.randf_range(0.24, 0.88),
			"spd": _rng.randf_range(0.8, 1.8),
			"phase": _rng.randf(),
		})


func _animate_hybrid_power(t: float) -> void:
	_fire_beat("impact_main", 1.56, "card_ace_strike", -2.5, 1.05)
	_fire_beat("echo_climax", 2.24, "anim_sword_cleave", -4.0, 1.15)
	if not is_instance_valid(_hybrid_stage_root):
		return

	var vis_u := clampf((t - 0.55) / 0.50, 0.0, 1.0)
	var out_u := 1.0 if t < 3.25 else clampf(1.0 - (t - 3.25) / 0.85, 0.0, 1.0)
	var env := vis_u * out_u
	_hybrid_stage_root.visible = env > 0.01

	var sheen_v := fmod(maxf(0.0, t - 1.25) * 0.95, 1.8) - 0.3
	if _hero_25d_mat != null:
		_hero_25d_mat.set_shader_parameter("time_sec", t)
		_hero_25d_mat.set_shader_parameter("opacity", env)
		_hero_25d_mat.set_shader_parameter("sheen_pos", sheen_v)
		_hero_25d_mat.set_shader_parameter("flash_white", maxf(0.0, 0.55 - absf(t - 1.62) * 3.5))
	if _hero_25d_shadow_mat != null:
		_hero_25d_shadow_mat.set_shader_parameter("time_sec", t)
		_hero_25d_shadow_mat.set_shader_parameter("opacity", env * 0.85)
	for em in _extra_25d_mats:
		var fmat := em.get("front", null) as ShaderMaterial
		var smat := em.get("shadow", null) as ShaderMaterial
		if fmat != null:
			fmat.set_shader_parameter("time_sec", t)
			fmat.set_shader_parameter("opacity", env)
			fmat.set_shader_parameter("sheen_pos", sheen_v)
			fmat.set_shader_parameter("flash_white", maxf(0.0, 0.55 - absf(t - 1.62) * 3.5))
		if smat != null:
			smat.set_shader_parameter("time_sec", t)
			smat.set_shader_parameter("opacity", env * 0.85)

	if is_instance_valid(_cel_slash_a):
		if t >= 1.44 and t <= 2.95:
			var su := clampf((t - 1.44) / 1.45, 0.0, 1.0)
			var sw_a := 1.0 - pow(1.0 - su, 2.4)
			_cel_slash_a.visible = true
			_cel_slash_a.scale = Vector3.ONE * lerpf(0.75, 1.02, minf(1.0, su * 2.2))
			_cel_slash_a.rotation_degrees = Vector3(-84.0, lerpf(-32.0, 40.0, sw_a), lerpf(-16.0, 14.0, sw_a))
			if _cel_slash_a_mat != null:
				_cel_slash_a_mat.set_shader_parameter("frame_index", pow(su, 0.72) * 23.0)
				_cel_slash_a_mat.set_shader_parameter("dissolve", clampf((su - 0.68) / 0.32, 0.0, 1.0) * 0.80)
			if is_instance_valid(_cel_slash_b):
				_cel_slash_b.visible = su >= 0.12
				var su2 := clampf((su - 0.12) / 0.88, 0.0, 1.0)
				var sw_b := 1.0 - pow(1.0 - su2, 2.3)
				_cel_slash_b.scale = Vector3.ONE * lerpf(0.72, 0.98, minf(1.0, su2 * 2.2))
				_cel_slash_b.rotation_degrees = Vector3(-82.0, lerpf(36.0, -38.0, sw_b), lerpf(16.0, -14.0, sw_b))
				if _cel_slash_b_mat != null:
					_cel_slash_b_mat.set_shader_parameter("frame_index", pow(su2, 0.78) * 23.0)
					_cel_slash_b_mat.set_shader_parameter("dissolve", clampf((su2 - 0.66) / 0.34, 0.0, 1.0) * 0.80)
		else:
			_cel_slash_a.visible = false
			if is_instance_valid(_cel_slash_b):
				_cel_slash_b.visible = false

	for ar in _alc_mist_rings:
		var m_nd := ar["node"] as MeshInstance3D
		var m_mat := ar["mat"] as ShaderMaterial
		if is_instance_valid(m_nd):
			m_nd.visible = env > 0.01
			m_nd.rotation_degrees.y = t * float(ar.get("spin", 90.0))
			m_nd.scale = Vector3.ONE * lerpf(0.65, 1.25, env)
			if m_mat != null:
				m_mat.set_shader_parameter("frame_index", fmod(t * 10.0, 16.0))
				m_mat.set_shader_parameter("opacity", env * 0.86)

	for sp in _hybrid_spinners:
		var nd: Node3D = sp.get("node", null) as Node3D
		if not is_instance_valid(nd):
			continue
		if not sp.has("base_pos"):
			sp["base_pos"] = nd.position
		if not sp.has("base_rot"):
			sp["base_rot"] = nd.rotation_degrees
		var b_pos: Vector3 = sp["base_pos"]
		var b_rot: Vector3 = sp["base_rot"]
		var s_sc := maxf(0.05, env * (1.18 if (t >= 3.80 and t <= 4.80) else 1.0))
		nd.scale = Vector3.ONE * s_sc
		nd.rotation_degrees = b_rot + Vector3(float(sp.get("spin_x", 0.0)), float(sp.get("spin_y", 0.0)), float(sp.get("spin_z", 0.0))) * t
		nd.position = b_pos + Vector3(0.0, sin(t * 4.5 + float(sp.get("phase", 0.0))) * float(sp.get("bob", 0.04)), 0.0)

	for pi in range(_hybrid_pillars.size()):
		var p_nd: MeshInstance3D = _hybrid_pillars[pi]
		if is_instance_valid(p_nd):
			var p_env := clampf((t - 1.35) / 0.35, 0.0, 1.0) * out_u
			p_nd.visible = p_env > 0.01
			p_nd.scale = Vector3(0.6 + p_env * 0.6, p_env * 1.15, 0.6 + p_env * 0.6)

	for m in _hybrid_motes:
		var mn: MeshInstance3D = m["node"] as MeshInstance3D
		var m_mat: ShaderMaterial = m.get("mat", null) as ShaderMaterial
		if not is_instance_valid(mn):
			continue
		if t >= 0.75 and t < 3.55:
			mn.visible = true
			var life := fmod((t - 0.75) * float(m["spd"]) + float(m["phase"]), 1.0)
			var a := float(m["angle"]) + life * 3.4
			var r := float(m["rad"]) * (0.45 + life * 0.85)
			var pat := str(m["pattern"])
			if pat == "strike":
				var sr := (_rival_pos - _impact_pos)
				mn.position = Vector3(0.0, 0.25, 0.0).lerp(sr + Vector3(cos(a) * 0.25, 0.3, sin(a) * 0.25), ease(life, 0.45))
			elif pat == "burst":
				mn.position = Vector3(cos(a) * r * 1.2, 0.25 + sin(life * PI) * 0.85, sin(a) * r * 1.2)
			elif pat == "orbit":
				mn.position = Vector3(cos(a + t * 2.5) * r, 0.28 + sin(t * 4.0 + a) * 0.24, sin(a + t * 2.5) * r)
			else:
				mn.position = Vector3(cos(a) * r * 0.75, 0.12 + life * 1.15, sin(a) * r * 0.75)
			mn.rotation_degrees = Vector3(life * 180.0, rad_to_deg(-a), life * 120.0)
			if m_mat != null:
				m_mat.set_shader_parameter("time_sec", t)
				m_mat.set_shader_parameter("opacity", sin(life * PI) * 0.96)
				if bool(m.get("is_cel", false)):
					m_mat.set_shader_parameter("frame_index", 2.0 + fmod(life * 8.0, 8.0))
		else:
			mn.visible = false
