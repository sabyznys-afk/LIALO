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

const DURATION: float = 4.20
const CARD_BACK_TEX := "res://assets/table/deck_back_klasic.png"
const WOOD_TEX := "res://assets/table/wood.png"
const OPP_MODEL_PATH := "res://assets/models/opp_stredovek.glb"
const FONT_DISP_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoUI.ttf"

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

# Shared Card + Table Seal
var _fx_root: Node3D = null
var _hero_card: Node3D = null
var _card_orbit_rings: Array[MeshInstance3D] = []
var _rune_seal_root: Node3D = null
var _rune_seal_mat: StandardMaterial3D = null
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


func setup_battle_fx(impact_pos: Vector3, rival_pos: Vector3, card_id: String = "SPEC_STORM", with_stinger: bool = false) -> void:
	_mode = "battle_fx"
	_with_stinger = with_stinger
	_card_id = card_id if CARD_META.has(card_id) else "SPEC_STORM"
	var meta: Dictionary = CARD_META[_card_id]
	_accent = meta["accent"] as Color
	_loop = false
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


func _build_fx_rig() -> void:
	if is_instance_valid(_fx_root):
		_fx_root.queue_free()
	_fx_root = Node3D.new()
	_fx_root.name = "PowerCardFxRig_" + _card_id
	add_child(_fx_root)

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

	# Shared Etched Woodcut Table Rune Seal + 3 Shockwave Rings
	_rune_seal_root = Node3D.new()
	_rune_seal_root.position = _impact_pos + Vector3(0.0, 0.014, 0.0)
	_fx_root.add_child(_rune_seal_root)

	_rune_seal_mat = StandardMaterial3D.new()
	_rune_seal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rune_seal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rune_seal_mat.albedo_color = Color(_accent.r, _accent.g, _accent.b, 0.0)

	var outer_seal := MeshInstance3D.new()
	var osm := TorusMesh.new()
	osm.inner_radius = 0.36
	osm.outer_radius = 0.405
	osm.rings = 48
	osm.ring_segments = 8
	outer_seal.mesh = osm
	outer_seal.material_override = _rune_seal_mat
	_apply_ink_outline(outer_seal, 0.011)
	_rune_seal_root.add_child(outer_seal)

	for bi in range(8):
		var spoke := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.024, 0.009, 0.74)
		spoke.mesh = sm
		spoke.rotation_degrees.y = float(bi) * 45.0
		spoke.material_override = _rune_seal_mat
		_apply_ink_outline(spoke, 0.013)
		_rune_seal_root.add_child(spoke)

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
	_vortex_root.position = _impact_pos + Vector3(0.0, 1.24, 0.0)
	_fx_root.add_child(_vortex_root)

	_vortex_layers.clear()
	var vortex_cfgs: Array = [
		[0.44, 0.58, Color(0.12, 0.22, 0.52, 0.86)],
		[0.25, 0.39, Color(0.28, 0.78, 1.0, 0.88)],
		[0.10, 0.22, Color(0.84, 0.98, 1.0, 0.95)],
	]
	for vi in range(vortex_cfgs.size()):
		var cfg: Array = vortex_cfgs[vi]
		var vr := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = float(cfg[0])
		tm.outer_radius = float(cfg[1])
		tm.rings = 40
		tm.ring_segments = 10
		vr.mesh = tm
		vr.position = Vector3(0.0, float(vi) * -0.04, 0.0)
		var vmat := StandardMaterial3D.new()
		vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vmat.albedo_color = cfg[2] as Color
		vr.material_override = vmat
		_apply_ink_outline(vr, 0.014)
		_vortex_root.add_child(vr)
		_vortex_layers.append(vr)

	_pillar_root = Node3D.new()
	_pillar_root.position = _impact_pos
	_fx_root.add_child(_pillar_root)

	_pillar_core_mat = StandardMaterial3D.new()
	_pillar_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_core_mat.albedo_color = Color(0.95, 1.0, 1.0, 0.0)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.06
	cm.height = 1.48
	core.mesh = cm
	core.position = Vector3(0.0, 0.74, 0.0)
	core.material_override = _pillar_core_mat
	_apply_ink_outline(core, 0.015)
	_pillar_root.add_child(core)

	_pillar_sheath_mat = StandardMaterial3D.new()
	_pillar_sheath_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_sheath_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_sheath_mat.albedo_color = Color(0.24, 0.86, 1.0, 0.0)
	var sheath := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 0.22
	shm.bottom_radius = 0.16
	shm.height = 1.48
	sheath.mesh = shm
	sheath.position = Vector3(0.0, 0.74, 0.0)
	sheath.material_override = _pillar_sheath_mat
	_pillar_root.add_child(sheath)

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

	_sparks.clear()
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.020, 0.14, 0.020)
	for spi in range(36):
		var sp := MeshInstance3D.new()
		sp.mesh = spark_mesh
		var spmat := StandardMaterial3D.new()
		spmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spmat.albedo_color = Color(0.56, 0.95, 1.0, 0.0)
		sp.material_override = spmat
		_apply_ink_outline(sp, 0.008)
		sp.visible = false
		_fx_root.add_child(sp)
		_sparks.append({
			"node": sp,
			"mat": spmat,
			"angle": float(spi) * (TAU / 36.0) + _rng.randf_range(-0.2, 0.2),
			"rad": _rng.randf_range(0.18, 0.95),
			"spd": _rng.randf_range(0.8, 2.0),
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
	# Ink-rimmed Rising Crimson Blood Moon Disc behind Rival
	_blood_moon_mesh = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.56
	bm.bottom_radius = 0.56
	bm.height = 0.02
	bm.radial_segments = 40
	_blood_moon_mesh.mesh = bm
	_blood_moon_mesh.position = _rival_pos + Vector3(0.0, 0.52, -0.58)
	_blood_moon_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.albedo_color = Color(0.86, 0.08, 0.16, 0.0)
	_blood_moon_mesh.material_override = mmat
	_apply_ink_outline(_blood_moon_mesh, 0.018)
	_blood_moon_mesh.visible = false
	_fx_root.add_child(_blood_moon_mesh)

	# 12 Articulated All-Black Woodcut Bat Silhouettes
	_bats.clear()
	var bat_mat := StandardMaterial3D.new()
	bat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bat_mat.albedo_color = Color(0.03, 0.02, 0.03, 1.0)
	for bi in range(12):
		var broot := Node3D.new()
		broot.visible = false
		var body := MeshInstance3D.new()
		var b_s := SphereMesh.new()
		b_s.radius = 0.026
		b_s.height = 0.065
		body.mesh = b_s
		body.material_override = bat_mat
		broot.add_child(body)
		var wings: Array[MeshInstance3D] = []
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.095, 0.006, 0.045)
			w.mesh = wm
			w.position = Vector3(side * 0.052, 0.0, 0.0)
			w.rotation_degrees = Vector3(0.0, side * -18.0, 0.0)
			w.material_override = bat_mat
			_apply_ink_outline(w, 0.008, Color(0.85, 0.12, 0.22, 1.0))
			broot.add_child(w)
			wings.append(w)
		_fx_root.add_child(broot)
		_bats.append({
			"node": broot,
			"wings": wings,
			"angle": float(bi) * (TAU / 12.0),
			"phase": _rng.randf_range(0.0, TAU),
			"rad": _rng.randf_range(0.28, 0.85),
		})

	# Crimson Crescent Ink Slash Arc
	_crescent_slash = Node3D.new()
	_crescent_slash.position = _impact_pos + Vector3(0.0, 0.22, -0.35)
	_crescent_slash.visible = false
	var c_mi := MeshInstance3D.new()
	var c_tor := TorusMesh.new()
	c_tor.inner_radius = 0.58
	c_tor.outer_radius = 0.76
	c_tor.rings = 32
	c_tor.ring_segments = 8
	c_mi.mesh = c_tor
	c_mi.scale = Vector3(1.25, 0.22, 1.0)
	var c_mat := StandardMaterial3D.new()
	c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	c_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c_mat.albedo_color = Color(0.98, 0.10, 0.20, 0.95)
	c_mi.material_override = c_mat
	_apply_ink_outline(c_mi, 0.018)
	_crescent_slash.add_child(c_mi)
	_fx_root.add_child(_crescent_slash)

	# 16 Crimson Siphon Soul-Orbs + ImmediateMesh Ribbons
	_siphon_orbs.clear()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.036
	orb_mesh.height = 0.072
	for oi in range(16):
		var om := MeshInstance3D.new()
		om.mesh = orb_mesh
		var omat := StandardMaterial3D.new()
		omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		omat.albedo_color = Color(1.0, 0.18, 0.28, 0.95)
		om.material_override = omat
		_apply_ink_outline(om, 0.010)
		om.visible = false
		_fx_root.add_child(om)
		_siphon_orbs.append({
			"node": om,
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

	# Sculpted Ink-Outlined 3D Phoenix Crest & Unfurling Wings
	_phoenix_bird_root = Node3D.new()
	_phoenix_bird_root.position = _impact_pos + Vector3(0.0, 0.35, 0.0)
	_phoenix_bird_root.visible = false
	_fx_root.add_child(_phoenix_bird_root)

	var gold_flame := StandardMaterial3D.new()
	gold_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold_flame.albedo_color = Color(1.0, 0.52, 0.12)
	var sun_crest := StandardMaterial3D.new()
	sun_crest.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_crest.albedo_color = Color(1.0, 0.88, 0.32)

	var pbody := MeshInstance3D.new()
	var pbm := SphereMesh.new()
	pbm.radius = 0.12
	pbm.height = 0.42
	pbody.mesh = pbm
	pbody.material_override = gold_flame
	_phoenix_bird_root.add_child(pbody)

	var crest := MeshInstance3D.new()
	var crm := PrismMesh.new()
	crm.size = Vector3(0.14, 0.28, 0.08)
	crest.mesh = crm
	crest.position = Vector3(0.0, 0.28, 0.02)
	crest.material_override = sun_crest
	_phoenix_bird_root.add_child(crest)

	for side in [-1.0, 1.0]:
		var wpiv := Node3D.new()
		wpiv.position = Vector3(side * 0.09, 0.06, 0.0)
		_phoenix_bird_root.add_child(wpiv)
		if side < 0.0:
			_phoenix_wing_l = wpiv
		else:
			_phoenix_wing_r = wpiv
		for fi in range(5):
			var f := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.32 + float(fi) * 0.06, 0.02, 0.10)
			f.mesh = fm
			f.position = Vector3(side * (0.18 + float(fi) * 0.07), float(fi) * 0.04, -float(fi) * 0.03)
			f.rotation_degrees = Vector3(12.0, side * -15.0, side * (14.0 + float(fi) * 5.0))
			f.material_override = sun_crest if fi >= 3 else gold_flame
			wpiv.add_child(f)
	_apply_ink_outline(_phoenix_bird_root, 0.015)

	# Golden Flame Pillar
	_flame_pillar = MeshInstance3D.new()
	var fpm := CylinderMesh.new()
	fpm.top_radius = 0.28
	fpm.bottom_radius = 0.14
	fpm.height = 1.60
	_flame_pillar.mesh = fpm
	_flame_pillar.position = _impact_pos + Vector3(0.0, 0.80, 0.0)
	_flame_pillar_mat = StandardMaterial3D.new()
	_flame_pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_pillar_mat.albedo_color = Color(1.0, 0.56, 0.14, 0.0)
	_flame_pillar.material_override = _flame_pillar_mat
	_apply_ink_outline(_flame_pillar, 0.014)
	_flame_pillar.visible = false
	_fx_root.add_child(_flame_pillar)

	# 40 Swirling Inked Fire Feathers
	_feathers.clear()
	var f_mesh := BoxMesh.new()
	f_mesh.size = Vector3(0.038, 0.008, 0.11)
	for fi in range(40):
		var fm := MeshInstance3D.new()
		fm.mesh = f_mesh
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.albedo_color = Color(1.0, 0.62 if fi % 2 == 0 else 0.84, 0.18, 0.92)
		fm.material_override = fmat
		_apply_ink_outline(fm, 0.009)
		fm.visible = false
		_fx_root.add_child(fm)
		_feathers.append({
			"node": fm,
			"angle": float(fi) * (TAU / 40.0),
			"rad": _rng.randf_range(0.22, 1.05),
			"spd": _rng.randf_range(0.6, 1.6),
			"phase": _rng.randf(),
		})


func _build_chronos_specific_rig() -> void:
	_astrolabe_root = Node3D.new()
	_astrolabe_root.position = _impact_pos + Vector3(0.0, 0.65, -0.10)
	_astrolabe_root.visible = false
	_fx_root.add_child(_astrolabe_root)

	var brass_mat := Toon.pbr(Color(0.95, 0.76, 0.28), "", 0.25, 0.88)
	var azure_mat := StandardMaterial3D.new()
	azure_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	azure_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	azure_mat.albedo_color = Color(0.45, 0.90, 1.0, 0.86)

	_astro_gears.clear()
	var g_radii := [[0.42, 0.48], [0.28, 0.33], [0.15, 0.19]]
	for gi in range(g_radii.size()):
		var g_piv := Node3D.new()
		var cfg: Array = g_radii[gi]
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = float(cfg[0])
		tm.outer_radius = float(cfg[1])
		tm.rings = 36
		tm.ring_segments = 8
		ring.mesh = tm
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring.material_override = brass_mat if gi != 1 else azure_mat
		g_piv.add_child(ring)
		for ti in range(12):
			var tooth := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.030, 0.060, 0.024)
			tooth.mesh = bm
			var a := float(ti) * (TAU / 12.0)
			tooth.position = Vector3(cos(a) * float(cfg[1]), sin(a) * float(cfg[1]), 0.0)
			tooth.rotation_degrees.z = rad_to_deg(a) - 90.0
			tooth.material_override = brass_mat
			g_piv.add_child(tooth)
		_astrolabe_root.add_child(g_piv)
		_astro_gears.append(g_piv)

	# Clock Hands (Minute + Hour snapping backward!)
	_clock_hand_min = Node3D.new()
	var hm1 := MeshInstance3D.new()
	var b1 := BoxMesh.new()
	b1.size = Vector3(0.022, 0.38, 0.018)
	hm1.mesh = b1
	hm1.position = Vector3(0.0, 0.17, 0.03)
	hm1.material_override = azure_mat
	_clock_hand_min.add_child(hm1)
	_astrolabe_root.add_child(_clock_hand_min)

	_clock_hand_hr = Node3D.new()
	var hm2 := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(0.030, 0.24, 0.018)
	hm2.mesh = b2
	hm2.position = Vector3(0.0, 0.10, 0.04)
	hm2.material_override = brass_mat
	_clock_hand_hr.add_child(hm2)
	_astrolabe_root.add_child(_clock_hand_hr)

	_apply_ink_outline(_astrolabe_root, 0.014)

	# 24 Suspended Time-Frozen Inked Glass Shards
	_glass_shards.clear()
	var shard_m := PrismMesh.new()
	shard_m.size = Vector3(0.06, 0.14, 0.03)
	for si in range(24):
		var sh := MeshInstance3D.new()
		sh.mesh = shard_m
		sh.material_override = azure_mat
		_apply_ink_outline(sh, 0.010)
		sh.visible = false
		_fx_root.add_child(sh)
		_glass_shards.append({
			"node": sh,
			"pos": _impact_pos + Vector3(_rng.randf_range(-0.85, 0.85), _rng.randf_range(0.18, 1.15), _rng.randf_range(-0.75, 0.35)),
			"rot": Vector3(_rng.randf_range(0.0, 360.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(0.0, 360.0)),
		})


func _process(delta: float) -> void:
	if not visible or not _playing:
		return

	var dt := minf(delta, 0.05) * _speed
	_t += dt
	_bolt_rebuild_acc += dt

	if _t >= DURATION:
		if _loop:
			restart()
			return
		else:
			_t = DURATION
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
			_fire_beat("stinger", 0.02, "music_power_vampire", -2.0, 1.0)
			_fire_beat("studio_cast", 0.05, "power_vampire_cast", -2.5, 1.0)
		elif _card_id == "SPEC_STORM":
			_fire_beat("stinger", 0.02, "music_power_storm", -2.0, 1.0)
			_fire_beat("studio_cast", 0.05, "power_storm_cast", -2.5, 1.0)
		elif _card_id == "SPEC_MIRROR":
			_fire_beat("stinger", 0.02, "music_power_mirror", -2.0, 1.0)
		elif _card_id == "SPEC_ALCHEMIST":
			_fire_beat("stinger", 0.02, "music_power_alchemist", -2.0, 1.0)

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
				orb.rotation_degrees.y += 4.5 if ri == 0 else -5.5

	# Shared Table Seal & Shockwaves
	if is_instance_valid(_rune_seal_root) and _rune_seal_mat != null:
		var seal_a := 0.0
		if t >= 0.85 and t < 3.50:
			seal_a = 1.0 if t < 2.85 else clampf(1.0 - (t - 2.85) / 0.65, 0.0, 1.0)
		_rune_seal_root.visible = seal_a > 0.01
		_rune_seal_root.rotation_degrees.y = t * 44.0
		_rune_seal_mat.albedo_color = Color(_accent.r, _accent.g, _accent.b, seal_a * (0.80 + 0.20 * sin(t * 22.0)))

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
			var target_fov := _cam_base_fov
			var cam_off := Vector3.ZERO
			var look_off := Vector3.ZERO
			var roll_deg := 0.0
			if t < 0.85:
				var u := ease(t / 0.85, 0.5)
				target_fov = lerpf(54.0, 46.0, u)
				cam_off = Vector3(0.0, -0.05 * u, -0.10 * u)
			elif t < 1.56:
				var punch := maxf(0.0, 1.0 - (t - 0.85) / 0.28)
				target_fov = 48.0 - punch * 3.5
				cam_off = Vector3(sin(t * 70.0) * 0.015 * punch, -0.04 * punch, -0.08)
				roll_deg = sin(t * 58.0) * 1.4 * punch
			elif t < 2.62:
				var quake := 1.0 - clampf((t - 1.56) / 1.06, 0.0, 1.0) * 0.65
				target_fov = 43.0 + (1.0 - quake) * 7.0
				cam_off = Vector3(sin(t * 84.0) * 0.036 * quake, cos(t * 72.0) * 0.030 * quake, -0.14)
				look_off = Vector3(0.0, 0.04, -0.16)
				roll_deg = 4.6 * sin(t * 13.0) * quake
			else:
				var u := ease(clampf((t - 2.62) / 1.40, 0.0, 1.0), 0.45)
				target_fov = lerpf(50.0, _cam_base_fov, u)
				cam_off = Vector3(0.0, 0.0, lerpf(-0.12, 0.0, u))
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
			v_alpha = clampf((t - 0.22) / 0.72, 0.0, 1.0) * 0.72
		elif t >= 1.56 and t < 2.65:
			v_alpha = 1.0
		elif t >= 2.65:
			v_alpha = clampf(1.0 - (t - 2.65) / 1.10, 0.0, 1.0)
		_vortex_root.visible = v_alpha > 0.01
		_vortex_root.scale = Vector3.ONE * (0.45 + v_alpha * 0.90)
		for vi in range(_vortex_layers.size()):
			var vr := _vortex_layers[vi]
			if is_instance_valid(vr):
				vr.rotation_degrees.y = t * (190.0 + float(vi) * 95.0) * (-1.0 if vi % 2 == 1 else 1.0)

	if is_instance_valid(_pillar_root):
		var pil_a := 0.0
		if t >= 1.56 and t <= 2.60:
			var p_u := (t - 1.56) / 1.04
			pil_a = sin(minf(p_u * 4.5, 1.0) * PI * 0.5) * (1.0 - maxf(0.0, (p_u - 0.55) / 0.45))
			pil_a *= 0.80 + 0.20 * sin(t * 50.0)
		_pillar_root.visible = pil_a > 0.01
		var p_w := lerpf(0.6, 1.35, pil_a)
		_pillar_root.scale = Vector3(p_w, 1.0, p_w)
		_pillar_root.rotation_degrees.y = t * 420.0
		if _pillar_core_mat != null:
			_pillar_core_mat.albedo_color.a = clampf(pil_a, 0.0, 1.0)
		if _pillar_sheath_mat != null:
			_pillar_sheath_mat.albedo_color.a = clampf(pil_a * 0.75, 0.0, 1.0)

	if is_instance_valid(_bolts_mesh) and _bolts_mesh_inst != null:
		var bolts_active := (t >= 0.18 and t < 2.65)
		_bolts_mesh_inst.visible = bolts_active
		if bolts_active and (_bolt_rebuild_acc >= 0.038 or t < 0.06):
			_bolt_rebuild_acc = 0.0
			_rebuild_dynamic_bolts(t)

	for sp in _sparks:
		var nd: MeshInstance3D = sp["node"] as MeshInstance3D
		var spmat: StandardMaterial3D = sp["mat"] as StandardMaterial3D
		if t >= 0.85 and t < 3.25:
			var life := fmod((t - 0.85) * float(sp["spd"]) + float(sp["phase"]), 1.0)
			nd.visible = true
			var a := float(sp["angle"]) + life * 0.45
			var r := float(sp["rad"]) * (0.45 + life * 0.95)
			nd.position = _impact_pos + Vector3(cos(a) * r, life * 1.15, sin(a) * r)
			nd.rotation_degrees = Vector3(0.0, rad_to_deg(-a), 18.0)
			spmat.albedo_color = Color(0.65, 0.97, 1.0, sin(life * PI) * 0.92)
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
		var bn: Node3D = bd["node"] as Node3D
		if t >= 0.72 and t <= 3.10:
			bn.visible = true
			var u := (t - 0.72) / 2.38
			var a := float(bd["angle"]) + u * 5.2
			var r := float(bd["rad"]) * (0.4 + sin(u * PI) * 1.1)
			bn.position = _impact_pos + Vector3(cos(a) * r, 0.15 + sin(u * PI) * 0.92, sin(a) * r - u * 0.65)
			bn.rotation_degrees = Vector3(12.0, rad_to_deg(-a) + 90.0, 0.0)
			var w_arr: Array = bd["wings"]
			var flap := sin(t * 24.0 + float(bd["phase"])) * 38.0
			if w_arr.size() >= 2:
				(w_arr[0] as MeshInstance3D).rotation_degrees.z = flap
				(w_arr[1] as MeshInstance3D).rotation_degrees.z = -flap
		else:
			bn.visible = false

	if is_instance_valid(_crescent_slash):
		if t >= 1.56 and t <= 2.35:
			_crescent_slash.visible = true
			var su := ease((t - 1.56) / 0.79, 0.35)
			_crescent_slash.position = _rival_pos.lerp(_impact_pos, 1.0 - su) + Vector3(0.0, 0.25, 0.0)
			_crescent_slash.rotation_degrees = Vector3(-18.0, lerpf(-55.0, 65.0, su), -22.0)
			_crescent_slash.scale = Vector3.ONE * lerpf(0.65, 1.45, sin(su * PI))
		else:
			_crescent_slash.visible = false

	for od in _siphon_orbs:
		var on: MeshInstance3D = od["node"] as MeshInstance3D
		var ou := (t - float(od["delay"])) / 0.75
		if ou >= 0.0 and ou <= 1.0:
			on.visible = true
			var eu := ease(ou, 0.48)
			var mid := _rival_pos.lerp(_hand_pos, 0.5) + Vector3(float(od["arc_x"]), float(od["arc_y"]), 0.0)
			on.position = _rival_pos.lerp(mid, eu).lerp(mid.lerp(_hand_pos, eu), eu)
			on.scale = Vector3.ONE * sin(eu * PI) * 1.2
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
				_emit_bolt_ribbon(_rival_pos + Vector3(0.0, 0.12, 0.1), _hand_pos, 8, 0.16, 0.024, Color(0.96, 0.14, 0.24, 0.90))
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
		if t >= 1.40 and t <= 3.85:
			fm.visible = true
			var life := fmod((t - 1.40) * float(fd["spd"]) + float(fd["phase"]), 1.0)
			var a := float(fd["angle"]) + life * 3.8
			var r := float(fd["rad"]) * (0.35 + life * 0.95)
			fm.position = _impact_pos + Vector3(cos(a) * r, life * 1.35, sin(a) * r)
			fm.rotation_degrees = Vector3(life * 220.0, rad_to_deg(-a), life * 140.0)
		else:
			fm.visible = false


func _animate_chronos(t: float) -> void:
	_fire_beat("freeze", 1.56, "card_suit_shift", -2.5, 0.78)
	_fire_beat("rewind", 2.30, "anim_parry_clang", -4.0, 1.18)

	if is_instance_valid(_astrolabe_root):
		if t >= 0.85 and t <= 3.75:
			_astrolabe_root.visible = true
			var au := ease(clampf((t - 0.85) / 0.65, 0.0, 1.0), 0.4)
			var out_u := 1.0 if t < 3.15 else clampf(1.0 - (t - 3.15) / 0.60, 0.0, 1.0)
			_astrolabe_root.position = _impact_pos + Vector3(0.0, lerpf(0.15, 0.72, au), -0.10)
			_astrolabe_root.scale = Vector3.ONE * au * out_u
			for gi in range(_astro_gears.size()):
				var g := _astro_gears[gi]
				var dir := -1.0 if (t >= 1.56 and t <= 2.95) else 1.0
				g.rotation_degrees.z += dir * (1.8 + float(gi) * 1.4)
			if is_instance_valid(_clock_hand_min):
				_clock_hand_min.rotation_degrees.z = t * 180.0 if t < 1.56 else (t * 180.0 - (t - 1.56) * 540.0)
			if is_instance_valid(_clock_hand_hr):
				_clock_hand_hr.rotation_degrees.z = t * 45.0 if t < 1.56 else (t * 45.0 - (t - 1.56) * 210.0)
		else:
			_astrolabe_root.visible = false

	for gd in _glass_shards:
		var sh: MeshInstance3D = gd["node"] as MeshInstance3D
		if t >= 1.56 and t <= 3.30:
			sh.visible = true
			var frozen := (t >= 1.72 and t <= 2.85)
			var wobble := 0.0 if frozen else sin(t * 9.0) * 0.04
			sh.position = (gd["pos"] as Vector3) + Vector3(0.0, wobble, 0.0)
			sh.rotation_degrees = (gd["rot"] as Vector3) + (Vector3.ZERO if frozen else Vector3(t * 45.0, t * 30.0, 0.0))
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


func _emit_bolt_ribbon(p_start: Vector3, p_end: Vector3, segs: int, jitter: float, width: float, col: Color) -> void:
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
		_bolts_mesh.surface_set_color(col)
		_bolts_mesh.surface_add_vertex(a - side)
		_bolts_mesh.surface_set_color(col)
		_bolts_mesh.surface_add_vertex(a + side)
		_bolts_mesh.surface_set_color(col)
		_bolts_mesh.surface_add_vertex(b + side)

		_bolts_mesh.surface_set_color(col)
		_bolts_mesh.surface_add_vertex(a - side)
		_bolts_mesh.surface_set_color(col)
		_bolts_mesh.surface_add_vertex(b + side)
		_bolts_mesh.surface_set_color(col)
		_bolts_mesh.surface_add_vertex(b - side)


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

	# Hand-Drawn Woodcut Ink Crosshatch Corner Vignette during spell climax
	if _t >= 0.85 and _t <= 3.60:
		var ink_a := 0.55 * sin(clampf((_t - 0.85) / 2.75, 0.0, 1.0) * PI)
		var ink_c := Color(0.03, 0.02, 0.02, ink_a)
		for hi in range(14):
			var off := float(hi) * 16.0
			_overlay.draw_line(Vector2(0.0, off), Vector2(off, 0.0), ink_c, 1.8)
			_overlay.draw_line(Vector2(vs.x - off, 0.0), Vector2(vs.x, off), ink_c, 1.8)
			_overlay.draw_line(Vector2(0.0, vs.y - off), Vector2(off, vs.y), ink_c, 1.8)
			_overlay.draw_line(Vector2(vs.x - off, vs.y), Vector2(vs.x, vs.y - off), ink_c, 1.8)

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

	# Calligraphic Hand-Drawn Banner (1.62s - 3.65s)
	if _t >= 1.62 and _t <= 3.65 and _font_disp != null:
		var bu := clampf((_t - 1.62) / 0.22, 0.0, 1.0)
		var out_a := 1.0 if _t < 3.10 else clampf(1.0 - (_t - 3.10) / 0.55, 0.0, 1.0)
		var slam_sc := lerpf(1.42, 1.0, ease(bu, 0.35))
		var banner_y := vs.y * 0.19
		var f_sz := int(round(44.0 * slam_sc))

		var slash_w := vs.x * 0.44 * bu
		var slash_pts := PackedVector2Array([
			Vector2(cx - slash_w, banner_y - 22.0),
			Vector2(cx + slash_w * 0.94, banner_y - 28.0),
			Vector2(cx + slash_w, banner_y + 20.0),
			Vector2(cx - slash_w * 0.92, banner_y + 26.0),
		])
		_overlay.draw_colored_polygon(slash_pts, Color(0.03, 0.03, 0.04, 0.88 * out_a))
		_overlay.draw_polyline(slash_pts, Color(_accent.r, _accent.g, _accent.b, 0.95 * out_a), 2.6, true)

		var text_pos := Vector2(cx - 320.0, banner_y + 12.0)
		_overlay.draw_string(_font_disp, text_pos + Vector2(3.0, 3.0), title_txt, HORIZONTAL_ALIGNMENT_CENTER, 640, f_sz, Color(0.02, 0.02, 0.02, 0.96 * out_a))
		_overlay.draw_string(_font_disp, text_pos, title_txt, HORIZONTAL_ALIGNMENT_CENTER, 640, f_sz, Color(_accent.r, _accent.g, _accent.b, out_a))

		if _font_body != null:
			_overlay.draw_string(_font_body, Vector2(cx - 280.0, banner_y + 44.0), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, 560, 16, Color(0.98, 0.88, 0.48, out_a))


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
			# Octagonal Cracking Mirror Gate + Echo Card Clones
			var frame := MeshInstance3D.new()
			var fm := TorusMesh.new()
			fm.inner_radius = 0.34; fm.outer_radius = 0.40; fm.rings = 8; fm.ring_segments = 8
			frame.mesh = fm
			frame.position = Vector3(0.0, 0.44, -0.18)
			frame.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			frame.material_override = trim_mat
			_apply_ink_outline(frame, 0.015)
			_hybrid_stage_root.add_child(frame)
			_hybrid_spinners.append({"node": frame, "spin_z": 42.0, "bob": 0.05})
			for mi in range(2):
				var mc := _create_card_quad_node(tex_path, CARD_BACK_TEX, _accent, Vector2(0.18, 0.26))
				mc.position = Vector3((-0.34 if mi == 0 else 0.34), 0.38, -0.05)
				_hybrid_stage_root.add_child(mc)
				_hybrid_spinners.append({"node": mc, "spin_y": 140.0 if mi == 0 else -140.0, "bob": 0.08})
			_spawn_hybrid_motes(24, PrismMesh.new(), Vector3(0.08, 0.14, 0.02), main_mat, "burst")

		"SPEC_ALCHEMIST":
			# Counter-rotating Golden Transmutation Rings + Central Crucible Orb + Elixir Sparks
			for ri in range(2):
				var tr := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.32 + float(ri) * 0.12; tm.outer_radius = 0.36 + float(ri) * 0.12; tm.rings = 32; tm.ring_segments = 8
				tr.mesh = tm
				tr.position = Vector3(0.0, 0.12 + float(ri) * 0.18, 0.0)
				tr.material_override = trim_mat if ri == 0 else main_mat
				_apply_ink_outline(tr, 0.013)
				_hybrid_stage_root.add_child(tr)
				_hybrid_spinners.append({"node": tr, "spin_y": 160.0 if ri == 0 else -190.0, "bob": 0.04})
			var flask := MeshInstance3D.new()
			var sphm := SphereMesh.new()
			sphm.radius = 0.14; sphm.height = 0.28
			flask.mesh = sphm
			flask.position = Vector3(0.0, 0.38, 0.0)
			flask.material_override = main_mat
			_apply_ink_outline(flask, 0.015)
			_hybrid_stage_root.add_child(flask)
			_hybrid_pillars.append(flask)
			_spawn_hybrid_motes(26, SphereMesh.new(), Vector3(0.045, 0.045, 0.045), trim_mat, "rise")

		"SPEC_ORACLE":
			# All-Seeing Third Eye Iris + Sweeping Divination Beams over Rival
			var outer_eye := MeshInstance3D.new()
			var oem := TorusMesh.new()
			oem.inner_radius = 0.28; oem.outer_radius = 0.34; oem.rings = 32; oem.ring_segments = 8
			outer_eye.mesh = oem
			outer_eye.position = Vector3(0.0, 0.56, -0.15)
			outer_eye.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			outer_eye.material_override = trim_mat
			_apply_ink_outline(outer_eye, 0.015)
			_hybrid_stage_root.add_child(outer_eye)
			_hybrid_spinners.append({"node": outer_eye, "spin_z": 95.0, "bob": 0.06})
			var iris := MeshInstance3D.new()
			var im := SphereMesh.new()
			im.radius = 0.15; im.height = 0.30
			iris.mesh = im
			iris.position = Vector3(0.0, 0.56, -0.15)
			iris.material_override = main_mat
			_apply_ink_outline(iris, 0.014)
			_hybrid_stage_root.add_child(iris)
			_hybrid_pillars.append(iris)
			for bi in range(4):
				var ray := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.035, 0.035, 1.35)
				ray.mesh = rm
				ray.position = Vector3((float(bi) - 1.5) * 0.18, 0.38, -0.55)
				ray.rotation_degrees = Vector3(-18.0, (float(bi) - 1.5) * 10.0, 0.0)
				ray.material_override = trim_mat if bi % 2 == 0 else main_mat
				_apply_ink_outline(ray, 0.010)
				_hybrid_stage_root.add_child(ray)
				_hybrid_pillars.append(ray)
			_spawn_hybrid_motes(18, PrismMesh.new(), Vector3(0.05, 0.12, 0.03), trim_mat, "orbit")

		"SPEC_MIDAS":
			# Stamped Gold Coin Cyclone + Golden Light Pillar
			var col_pil := MeshInstance3D.new()
			var cpm := CylinderMesh.new()
			cpm.top_radius = 0.22; cpm.bottom_radius = 0.12; cpm.height = 1.25
			col_pil.mesh = cpm
			col_pil.position = Vector3(0.0, 0.62, 0.0)
			col_pil.material_override = _make_hybrid_mat(Color(1.0, 0.86, 0.26), 0.72)
			_apply_ink_outline(col_pil, 0.014)
			_hybrid_stage_root.add_child(col_pil)
			_hybrid_pillars.append(col_pil)
			var coin_m := CylinderMesh.new()
			coin_m.top_radius = 0.5; coin_m.bottom_radius = 0.5; coin_m.height = 0.14; coin_m.radial_segments = 16
			_spawn_hybrid_motes(28, coin_m, Vector3(0.09, 0.09, 0.09), trim_mat, "orbit")

		"SPEC_JESTER":
			# Chaotic Card & Diamond Shards Orbiting Vortex
			for ci in range(6):
				var a := float(ci) * (TAU / 6.0)
				var jc := _create_card_quad_node(CARD_BACK_TEX, CARD_BACK_TEX, _accent if ci % 2 == 0 else Color(1.0, 0.82, 0.28), Vector2(0.14, 0.20))
				jc.position = Vector3(cos(a) * 0.42, 0.36 + float(ci % 3) * 0.10, sin(a) * 0.42)
				_hybrid_stage_root.add_child(jc)
				_hybrid_spinners.append({"node": jc, "spin_y": 240.0, "bob": 0.12, "phase": a})
			_spawn_hybrid_motes(24, PrismMesh.new(), Vector3(0.07, 0.10, 0.04), main_mat, "burst")

		"SPEC_HEX":
			# Cursed Violet Rings + Piercing Ink Needles around Rival
			for hi in range(3):
				var ch := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.28 + float(hi) * 0.05; tm.outer_radius = 0.33 + float(hi) * 0.05; tm.rings = 24; tm.ring_segments = 8
				ch.mesh = tm
				ch.position = _rival_pos - _impact_pos + Vector3(0.0, 0.22 + float(hi) * 0.16, 0.0)
				ch.rotation_degrees = Vector3(24.0 * float(hi - 1), float(hi) * 35.0, 0.0)
				ch.material_override = dark_mat if hi == 1 else main_mat
				_apply_ink_outline(ch, 0.015)
				_hybrid_stage_root.add_child(ch)
				_hybrid_spinners.append({"node": ch, "spin_y": 150.0 if hi % 2 == 0 else -150.0, "bob": 0.04})
			_spawn_hybrid_motes(20, PrismMesh.new(), Vector3(0.04, 0.18, 0.04), main_mat, "strike")

		"SPEC_MAGNET":
			# Dual Polarity Torus Arcs + Attracted Cards Spiraling Inward
			var arch := MeshInstance3D.new()
			var am := TorusMesh.new()
			am.inner_radius = 0.26; am.outer_radius = 0.34; am.rings = 28; am.ring_segments = 8
			arch.mesh = am
			arch.position = Vector3(0.0, 0.42, 0.10)
			arch.rotation_degrees = Vector3(72.0, 0.0, 0.0)
			arch.material_override = main_mat
			_apply_ink_outline(arch, 0.015)
			_hybrid_stage_root.add_child(arch)
			_hybrid_spinners.append({"node": arch, "spin_z": 120.0, "bob": 0.06})
			for ai in range(5):
				var ac := _create_card_quad_node(CARD_BACK_TEX, tex_path, _accent, Vector2(0.13, 0.19))
				ac.position = Vector3((float(ai) - 2.0) * 0.26, 0.32, -0.45)
				_hybrid_stage_root.add_child(ac)
				_hybrid_spinners.append({"node": ac, "spin_y": 180.0, "bob": 0.08, "phase": float(ai)})
			_spawn_hybrid_motes(22, SphereMesh.new(), Vector3(0.045, 0.045, 0.045), _make_hybrid_mat(Color(0.45, 0.90, 1.0), 0.95), "orbit")

		"SPEC_SHIELD":
			# Twin Octagonal Steel & Gold Aegis Bastion Shields Protecting Player
			for si in range(2):
				var sh := MeshInstance3D.new()
				var shm := CylinderMesh.new()
				shm.top_radius = 0.34; shm.bottom_radius = 0.30; shm.height = 0.05; shm.radial_segments = 8
				sh.mesh = shm
				sh.position = Vector3((-0.38 if si == 0 else 0.38), 0.38, 0.26)
				sh.rotation_degrees = Vector3(76.0, -24.0 if si == 0 else 24.0, 0.0)
				sh.material_override = main_mat if si == 0 else trim_mat
				_apply_ink_outline(sh, 0.016)
				_hybrid_stage_root.add_child(sh)
				_hybrid_spinners.append({"node": sh, "spin_y": 40.0 if si == 0 else -40.0, "bob": 0.06})
			_spawn_hybrid_motes(22, PrismMesh.new(), Vector3(0.05, 0.08, 0.03), trim_mat, "rise")

		"SPEC_GAMBLER":
			# Twin Oversized Tumbling Golden Inked Dice
			for di in range(2):
				var die := MeshInstance3D.new()
				var dm := BoxMesh.new()
				dm.size = Vector3(0.22, 0.22, 0.22)
				die.mesh = dm
				die.position = Vector3((-0.22 if di == 0 else 0.22), 0.38, -0.04 if di == 0 else 0.08)
				die.material_override = trim_mat if di == 0 else _make_hybrid_mat(Color(0.96, 0.90, 0.72), 0.98)
				_apply_ink_outline(die, 0.016)
				_hybrid_stage_root.add_child(die)
				_hybrid_spinners.append({"node": die, "spin_y": 320.0, "spin_x": 210.0, "bob": 0.14, "phase": float(di) * 1.5})
			_spawn_hybrid_motes(24, PrismMesh.new(), Vector3(0.06, 0.10, 0.04), trim_mat, "burst")

		"SPEC_PLAGUE":
			# Howling Blizzard Cone + 10 Jagged Emerald-Ice Spires Erupting around Rival
			for ii in range(10):
				var a := float(ii) * (TAU / 10.0)
				var sp := MeshInstance3D.new()
				var sm := PrismMesh.new()
				sm.size = Vector3(0.11, 0.42 + float(ii % 3) * 0.14, 0.11)
				sp.mesh = sm
				sp.position = _rival_pos - _impact_pos + Vector3(cos(a) * 0.42, 0.04, sin(a) * 0.34)
				sp.rotation_degrees = Vector3(sin(a) * 18.0, rad_to_deg(-a), cos(a) * 18.0)
				sp.material_override = main_mat if ii % 2 == 0 else _make_hybrid_mat(Color(0.72, 0.98, 1.0), 0.92)
				_apply_ink_outline(sp, 0.014)
				_hybrid_stage_root.add_child(sp)
				_hybrid_pillars.append(sp)
			_spawn_hybrid_motes(28, PrismMesh.new(), Vector3(0.05, 0.11, 0.04), _make_hybrid_mat(Color(0.76, 0.98, 1.0), 0.92), "orbit")

		_:
			# SPEC_CROWN (and clean fallback): Levitating Sovereign Crown with 8 Spires & Royal Rays
			var cr_root := Node3D.new()
			cr_root.position = Vector3(0.0, 0.48, 0.0)
			_hybrid_stage_root.add_child(cr_root)
			var band := MeshInstance3D.new()
			var bm := TorusMesh.new()
			bm.inner_radius = 0.24; bm.outer_radius = 0.30; bm.rings = 28; bm.ring_segments = 8
			band.mesh = bm
			band.material_override = trim_mat
			_apply_ink_outline(band, 0.015)
			cr_root.add_child(band)
			for si in range(8):
				var a := float(si) * (TAU / 8.0)
				var sp := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(0.08, 0.18, 0.08)
				sp.mesh = pm
				sp.position = Vector3(cos(a) * 0.26, 0.12, sin(a) * 0.26)
				sp.material_override = trim_mat if si % 2 == 0 else _make_hybrid_mat(Color(0.96, 0.24, 0.28), 0.95)
				_apply_ink_outline(sp, 0.013)
				cr_root.add_child(sp)
			_hybrid_spinners.append({"node": cr_root, "spin_y": 115.0, "bob": 0.10})
			_spawn_hybrid_motes(24, PrismMesh.new(), Vector3(0.05, 0.12, 0.03), trim_mat, "rise")


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

	for sp in _hybrid_spinners:
		var nd: Node3D = sp.get("node", null) as Node3D
		if not is_instance_valid(nd):
			continue
		var s_sc := maxf(0.05, env * (1.18 if (t >= 1.56 and t <= 2.55) else 1.0))
		nd.scale = Vector3.ONE * s_sc
		nd.rotation_degrees.y += float(sp.get("spin_y", 0.0)) * 0.016
		nd.rotation_degrees.x += float(sp.get("spin_x", 0.0)) * 0.016
		nd.rotation_degrees.z += float(sp.get("spin_z", 0.0)) * 0.016
		nd.position.y += sin(t * 4.5 + float(sp.get("phase", 0.0))) * float(sp.get("bob", 0.04)) * 0.03

	for pi in range(_hybrid_pillars.size()):
		var p_nd: MeshInstance3D = _hybrid_pillars[pi]
		if is_instance_valid(p_nd):
			var p_env := clampf((t - 1.35) / 0.35, 0.0, 1.0) * out_u
			p_nd.visible = p_env > 0.01
			p_nd.scale = Vector3(0.6 + p_env * 0.6, p_env * 1.15, 0.6 + p_env * 0.6)

	for m in _hybrid_motes:
		var mn: MeshInstance3D = m["node"] as MeshInstance3D
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
		else:
			mn.visible = false
