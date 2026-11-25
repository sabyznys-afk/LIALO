class_name PowerCardVfxShowcase
extends Node3D

## Flagship 1st-Person POV Epic Power Card Animation: SPEC_STORM ("Thunder Strike")
## Dual-mode:
##  - setup_fpv_preview(cam, overlay, loop) -> Self-contained 1st-person tavern table + rival + hand + 2D ink/anime impact frame
##  - setup_battle_fx(impact_pos, rival_pos) -> Spawns directly in live BattleTable3D at exact table coordinates
## Headless-safe & strictly typed for Godot 4.7.

signal sfx_triggered(sfx_key: String, vol_db: float, pitch: float)
signal sequence_finished()

const Toon := preload("res://scripts/toon_style.gd")

const DURATION: float = 3.55
const CARD_FRONT_TEX := "res://assets/cards/SPEC_STORM.png"
const CARD_BACK_TEX := "res://assets/table/deck_back_klasic.png"
const WOOD_TEX := "res://assets/table/wood.png"
const OPP_MODEL_PATH := "res://assets/models/opp_stredovek.glb"
const FONT_DISP_PATH := "res://assets/fonts/LialoDisplay.ttf"
const FONT_BODY_PATH := "res://assets/fonts/LialoUI.ttf"

var _mode: String = "fpv_preview"
var _t: float = 0.0
var _playing: bool = true
var _loop: bool = true
var _speed: float = 1.0
var _is_headless: bool = false

var _impact_pos: Vector3 = Vector3(0.0, 0.82, 0.0)
var _rival_pos: Vector3 = Vector3(0.0, 1.12, -1.16)
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

# Preview Stage Nodes (fpv_preview mode)
var _stage_root: Node3D = null
var _warm_light: OmniLight3D = null
var _storm_light: OmniLight3D = null
var _rival_root: Node3D = null
var _rival_base_pos: Vector3 = Vector3(0.0, 0.80, -1.24)
var _rival_eye_mats: Array[StandardMaterial3D] = []
var _hand_fan_root: Node3D = null

# Storm FX Rig Nodes (shared by fpv_preview & battle_fx)
var _fx_root: Node3D = null
var _hero_card: Node3D = null
var _card_orbit_rings: Array[MeshInstance3D] = []
var _vortex_root: Node3D = null
var _vortex_layers: Array[MeshInstance3D] = []
var _rune_seal_root: Node3D = null
var _rune_seal_mat: StandardMaterial3D = null
var _shock_rings: Array[Dictionary] = []
var _pillar_root: Node3D = null
var _pillar_core_mat: StandardMaterial3D = null
var _pillar_sheath_mat: StandardMaterial3D = null
var _pillar_helixes: Array[MeshInstance3D] = []
var _bolts_mesh: ImmediateMesh = null
var _bolts_mesh_inst: MeshInstance3D = null
var _bolts_mat: StandardMaterial3D = null
var _sparks: Array[Dictionary] = []
var _curse_cards: Array[Dictionary] = []


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


func setup_fpv_preview(cam: Camera3D, overlay_ctrl: Control, loop_enabled: bool = true) -> void:
	_mode = "fpv_preview"
	_cam = cam
	_overlay = overlay_ctrl
	_loop = loop_enabled
	_impact_pos = Vector3(0.0, 0.816, 0.0)
	_rival_pos = Vector3(0.0, 1.15, -1.16)
	_hand_pos = Vector3(0.0, 1.05, 0.72)

	if is_instance_valid(_overlay) and not _overlay.draw.is_connected(_draw_overlay):
		_overlay.draw.connect(_draw_overlay)

	_build_fpv_stage()
	_build_storm_fx_rig()
	restart()


func setup_battle_fx(impact_pos: Vector3, rival_pos: Vector3) -> void:
	_mode = "battle_fx"
	_loop = false
	_impact_pos = impact_pos
	_rival_pos = rival_pos
	_hand_pos = impact_pos + Vector3(0.0, 0.24, 0.70)
	_build_storm_fx_rig()
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
	for sp in _sparks:
		var nd: MeshInstance3D = sp.get("node") as MeshInstance3D
		if is_instance_valid(nd):
			nd.visible = false
	for cc in _curse_cards:
		var cn: Node3D = cc.get("node") as Node3D
		if is_instance_valid(cn):
			cn.visible = false
	if is_instance_valid(_hero_card):
		_hero_card.visible = (_mode == "fpv_preview")
	_apply_animation_state(0.0)
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _build_fpv_stage() -> void:
	if is_instance_valid(_stage_root):
		_stage_root.queue_free()
	_stage_root = Node3D.new()
	_stage_root.name = "FpvTavernStage"
	add_child(_stage_root)

	# Carved Oak Round Tavern Table
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

	# Brass Table Inlay Ring
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

	# Center Etched Discard Circle
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

	# Dark Stone Backdrop Wall behind Rival
	var wall := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(6.4, 3.6, 0.18)
	wall.mesh = w_box
	wall.position = Vector3(0.0, 1.5, -2.55)
	wall.material_override = Toon.pbr(Color(0.11, 0.09, 0.08), "", 0.88, 0.02)
	_stage_root.add_child(wall)

	# Warm Tavern Candlelight + Overhead Storm Light
	_warm_light = OmniLight3D.new()
	_warm_light.position = Vector3(-0.95, 1.45, 0.25)
	_warm_light.light_color = Color(1.0, 0.72, 0.36)
	_warm_light.light_energy = 2.4
	_warm_light.omni_range = 5.5
	_stage_root.add_child(_warm_light)

	_storm_light = OmniLight3D.new()
	_storm_light.position = Vector3(0.0, 1.95, -0.10)
	_storm_light.light_color = Color(0.45, 0.90, 1.0)
	_storm_light.light_energy = 0.0
	_storm_light.omni_range = 6.5
	_stage_root.add_child(_storm_light)

	# Rival across the table
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
				var opp_nd: Node3D = inst as Node3D
				opp_nd.scale = Vector3.ONE * 0.72
				opp_nd.position = Vector3(0.0, -0.04, 0.0)
				_rival_root.add_child(opp_nd)
				loaded_opp = true
	if not loaded_opp:
		_build_fallback_rival(_rival_root)

	# Rival held cards silhouette above table
	var opp_fan := Node3D.new()
	opp_fan.position = Vector3(0.0, 0.34, 0.26)
	_rival_root.add_child(opp_fan)
	for oi in range(5):
		var om := _create_card_quad_node(CARD_BACK_TEX, CARD_BACK_TEX, Color(0.75, 0.58, 0.26), Vector2(0.11, 0.16))
		var o_off := float(oi) - 2.0
		om.position = Vector3(o_off * 0.046, -absf(o_off) * 0.006, -float(oi) * 0.002)
		om.rotation_degrees = Vector3(14.0, 0.0, -o_off * 6.0)
		opp_fan.add_child(om)

	# Player foreground resting hand fan at bottom of camera frame
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
		f_mat.albedo_color = Color(0.24, 0.72, 0.96)
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


func _build_storm_fx_rig() -> void:
	if is_instance_valid(_fx_root):
		_fx_root.queue_free()
	_fx_root = Node3D.new()
	_fx_root.name = "StormFxRig"
	add_child(_fx_root)

	# 1. Hero 3D SPEC_STORM Card + 2 Orbiting Electric Rings
	_hero_card = _create_card_quad_node(CARD_FRONT_TEX, CARD_BACK_TEX, Color(0.32, 0.90, 1.0), Vector2(0.22, 0.32))
	_hero_card.position = _hand_pos
	_fx_root.add_child(_hero_card)

	_card_orbit_rings.clear()
	for ri in range(2):
		var orb := MeshInstance3D.new()
		var om := TorusMesh.new()
		om.inner_radius = 0.19 + float(ri) * 0.04
		om.outer_radius = 0.205 + float(ri) * 0.04
		om.rings = 32
		om.ring_segments = 8
		orb.mesh = om
		var omat := StandardMaterial3D.new()
		omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		omat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		omat.albedo_color = Color(0.45, 0.94, 1.0, 0.85)
		orb.material_override = omat
		orb.rotation_degrees = Vector3(65.0 if ri == 0 else -58.0, float(ri) * 45.0, 22.0)
		_hero_card.add_child(orb)
		_card_orbit_rings.append(orb)

	# 2. Swirling Overhead Storm Vortex
	_vortex_root = Node3D.new()
	_vortex_root.position = _impact_pos + Vector3(0.0, 1.22, 0.0)
	_fx_root.add_child(_vortex_root)

	_vortex_layers.clear()
	var vortex_radii := [[0.42, 0.56, Color(0.14, 0.24, 0.58, 0.72)], [0.24, 0.38, Color(0.28, 0.74, 1.0, 0.78)], [0.10, 0.22, Color(0.76, 0.96, 1.0, 0.90)]]
	for vi in range(vortex_radii.size()):
		var cfg: Array = vortex_radii[vi]
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
		vmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		vmat.albedo_color = cfg[2] as Color
		vr.material_override = vmat
		_vortex_root.add_child(vr)
		_vortex_layers.append(vr)

	# 3. Etched Table Rune Seal + 3 Shockwave Rings
	_rune_seal_root = Node3D.new()
	_rune_seal_root.position = _impact_pos + Vector3(0.0, 0.014, 0.0)
	_fx_root.add_child(_rune_seal_root)

	_rune_seal_mat = StandardMaterial3D.new()
	_rune_seal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rune_seal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rune_seal_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_rune_seal_mat.albedo_color = Color(0.32, 0.92, 1.0, 0.0)

	var outer_seal := MeshInstance3D.new()
	var osm := TorusMesh.new()
	osm.inner_radius = 0.36
	osm.outer_radius = 0.40
	osm.rings = 48
	osm.ring_segments = 8
	outer_seal.mesh = osm
	outer_seal.material_override = _rune_seal_mat
	_rune_seal_root.add_child(outer_seal)

	for bi in range(8):
		var spoke := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.022, 0.008, 0.74)
		spoke.mesh = sm
		spoke.rotation_degrees.y = float(bi) * 45.0
		spoke.material_override = _rune_seal_mat
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
		smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		smat.albedo_color = Color(0.45, 0.95, 1.0, 0.0)
		sr.material_override = smat
		_fx_root.add_child(sr)
		_shock_rings.append({"node": sr, "mat": smat})

	# 4. Sky-Splitting Helical Thunder Pillar
	_pillar_root = Node3D.new()
	_pillar_root.position = _impact_pos
	_fx_root.add_child(_pillar_root)

	_pillar_core_mat = StandardMaterial3D.new()
	_pillar_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pillar_core_mat.albedo_color = Color(0.92, 0.99, 1.0, 0.0)

	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.075
	cm.bottom_radius = 0.055
	cm.height = 1.45
	core.mesh = cm
	core.position = Vector3(0.0, 0.72, 0.0)
	core.material_override = _pillar_core_mat
	_pillar_root.add_child(core)

	_pillar_sheath_mat = StandardMaterial3D.new()
	_pillar_sheath_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_sheath_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_sheath_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pillar_sheath_mat.albedo_color = Color(0.24, 0.84, 1.0, 0.0)

	var sheath := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 0.22
	shm.bottom_radius = 0.16
	shm.height = 1.45
	sheath.mesh = shm
	sheath.position = Vector3(0.0, 0.72, 0.0)
	sheath.material_override = _pillar_sheath_mat
	_pillar_root.add_child(sheath)

	_pillar_helixes.clear()
	for hi in range(2):
		var hx := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.032, 1.42, 0.032)
		hx.mesh = hm
		hx.position = Vector3(0.0, 0.71, 0.0)
		hx.rotation_degrees = Vector3(0.0, float(hi) * 180.0, 14.0 if hi == 0 else -14.0)
		hx.material_override = _pillar_sheath_mat
		_pillar_root.add_child(hx)
		_pillar_helixes.append(hx)

	# 5. Dynamic Multi-Branching 3D Lightning Bolts (ImmediateMesh)
	_bolts_mesh = ImmediateMesh.new()
	_bolts_mesh_inst = MeshInstance3D.new()
	_bolts_mesh_inst.mesh = _bolts_mesh
	_bolts_mat = StandardMaterial3D.new()
	_bolts_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolts_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolts_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolts_mat.vertex_color_use_as_albedo = true
	_bolts_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolts_mesh_inst.material_override = _bolts_mat
	_fx_root.add_child(_bolts_mesh_inst)

	# 6. 36 Rising Storm Sparks / Plasma Needles
	_sparks.clear()
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.018, 0.14, 0.018)
	for spi in range(36):
		var sp := MeshInstance3D.new()
		sp.mesh = spark_mesh
		var spmat := StandardMaterial3D.new()
		spmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		spmat.albedo_color = Color(0.56, 0.95, 1.0, 0.0)
		sp.material_override = spmat
		sp.visible = false
		_fx_root.add_child(sp)
		_sparks.append({
			"node": sp,
			"mat": spmat,
			"angle": float(spi) * (TAU / 36.0) + _rng.randf_range(-0.2, 0.2),
			"rad": _rng.randf_range(0.18, 0.95),
			"spd": _rng.randf_range(0.9, 2.2),
			"phase": _rng.randf(),
		})

	# 7. 3 Spectral +3 DRAW Curse Cards
	_curse_cards.clear()
	for ci in range(3):
		var cnode := _create_card_quad_node(CARD_FRONT_TEX, CARD_BACK_TEX, Color(0.32, 0.92, 1.0), Vector2(0.14, 0.20))
		cnode.visible = false
		_fx_root.add_child(cnode)
		_curse_cards.append({
			"node": cnode,
			"delay": 2.18 + float(ci) * 0.14,
			"arc_x": (float(ci) - 1.0) * 0.34,
		})


func _process(delta: float) -> void:
	if not visible:
		return
	if not _playing:
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
	# SFX Choreography Beats
	_fire_beat("rise", 0.04, "card_throw_whoosh", -5.0, 1.08)
	_fire_beat("charge", 0.18, "anim_sword_unsheathe", -6.5, 1.24)
	_fire_beat("slam", 0.72, "card_slam", -3.0, 1.02)
	_fire_beat("conduit", 0.76, "anim_combo_slam", -4.5, 1.12)
	_fire_beat("thunder", 1.38, "card_ace_strike", -2.0, 0.88)
	_fire_beat("cleave", 1.40, "anim_sword_cleave", -3.5, 1.15)
	_fire_beat("curse_0", 2.20, "card_deal", -4.5, 1.10)
	_fire_beat("curse_1", 2.34, "card_deal", -4.5, 1.22)
	_fire_beat("curse_2", 2.48, "card_deal", -4.5, 1.35)

	# 1. Hero Card Transform across 5 Phases
	if is_instance_valid(_hero_card):
		var show_card := (_mode == "fpv_preview") or (t < 2.20)
		_hero_card.visible = show_card
		if t < 0.72:
			var u := ease(clampf(t / 0.72, 0.0, 1.0), 0.42)
			var hover_pos := _cam_base_pos.lerp(_impact_pos + Vector3(0.0, 0.34, 0.18), 0.58)
			_hero_card.position = _hand_pos.lerp(hover_pos, u) + Vector3(0.0, sin(t * 9.0) * 0.018 * u, 0.0)
			_hero_card.rotation_degrees = Vector3(lerpf(-35.0, -14.0, u), lerpf(0.0, 360.0, u * 0.95), sin(t * 8.0) * 4.0)
			_hero_card.scale = Vector3.ONE * lerpf(0.75, 1.18, u)
		elif t < 0.90:
			var u := ease(clampf((t - 0.72) / 0.18, 0.0, 1.0), 2.2)
			var hover_pos := _cam_base_pos.lerp(_impact_pos + Vector3(0.0, 0.34, 0.18), 0.58)
			_hero_card.position = hover_pos.lerp(_impact_pos + Vector3(0.0, 0.018, 0.0), u)
			_hero_card.rotation_degrees = Vector3(lerpf(-14.0, -90.0, u), 0.0, 0.0)
			_hero_card.scale = Vector3.ONE * lerpf(1.18, 0.95, u)
		else:
			_hero_card.position = _impact_pos + Vector3(0.0, 0.018, 0.0)
			_hero_card.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			_hero_card.scale = Vector3.ONE * 0.95

		for ri in range(_card_orbit_rings.size()):
			var orb := _card_orbit_rings[ri]
			if is_instance_valid(orb):
				orb.visible = t >= 0.12 and t < 0.88
				orb.rotation_degrees.y += 4.5 if ri == 0 else -5.5

	# 2. Overhead Storm Vortex
	if is_instance_valid(_vortex_root):
		var v_alpha := 0.0
		if t >= 0.18 and t < 1.38:
			v_alpha = clampf((t - 0.18) / 0.65, 0.0, 1.0) * 0.68
		elif t >= 1.38 and t < 2.25:
			v_alpha = 1.0
		elif t >= 2.25:
			v_alpha = clampf(1.0 - (t - 2.25) / 0.95, 0.0, 1.0)
		_vortex_root.visible = v_alpha > 0.01
		_vortex_root.scale = Vector3.ONE * (0.45 + v_alpha * 0.85)
		for vi in range(_vortex_layers.size()):
			var vr := _vortex_layers[vi]
			if is_instance_valid(vr):
				vr.rotation_degrees.y = t * (190.0 + float(vi) * 95.0) * (-1.0 if vi % 2 == 1 else 1.0)
				var vmat := vr.material_override as StandardMaterial3D
				if vmat != null:
					vmat.albedo_color.a = v_alpha * (0.85 - float(vi) * 0.12)

	# 3. Table Rune Seal & Shockwave Rings
	if is_instance_valid(_rune_seal_root) and _rune_seal_mat != null:
		var seal_a := 0.0
		if t >= 0.72 and t < 2.75:
			seal_a = 1.0 if t < 2.25 else clampf(1.0 - (t - 2.25) / 0.50, 0.0, 1.0)
		_rune_seal_root.visible = seal_a > 0.01
		_rune_seal_root.rotation_degrees.y = t * 48.0
		var pulse := 0.78 + 0.22 * sin(t * 24.0)
		_rune_seal_mat.albedo_color = Color(0.32, 0.94, 1.0, seal_a * pulse * 0.92)

	for si in range(_shock_rings.size()):
		var sd: Dictionary = _shock_rings[si]
		var sr: MeshInstance3D = sd["node"] as MeshInstance3D
		var smat: StandardMaterial3D = sd["mat"] as StandardMaterial3D
		var trig_t := 0.72 if si == 0 else (1.38 + float(si - 1) * 0.12)
		var local_t := t - trig_t
		if local_t >= 0.0 and local_t <= 0.65:
			var u := local_t / 0.65
			sr.visible = true
			sr.scale = Vector3.ONE * lerpf(0.6, 3.6 + float(si) * 0.7, ease(u, 0.45))
			smat.albedo_color = Color(0.55, 0.96, 1.0, (1.0 - u) * 0.90)
		else:
			sr.visible = false

	# 4. Sky-Splitting Thunder Pillar
	if is_instance_valid(_pillar_root):
		var pil_a := 0.0
		if t >= 1.38 and t <= 2.18:
			var p_u := (t - 1.38) / 0.80
			pil_a = sin(minf(p_u * 4.5, 1.0) * PI * 0.5) * (1.0 - maxf(0.0, (p_u - 0.55) / 0.45))
			pil_a *= 0.78 + 0.22 * sin(t * 55.0)
		_pillar_root.visible = pil_a > 0.01
		var p_w := lerpf(0.6, 1.35, pil_a)
		_pillar_root.scale = Vector3(p_w, 1.0, p_w)
		_pillar_root.rotation_degrees.y = t * 420.0
		if _pillar_core_mat != null:
			_pillar_core_mat.albedo_color.a = clampf(pil_a * 1.15, 0.0, 1.0)
		if _pillar_sheath_mat != null:
			_pillar_sheath_mat.albedo_color.a = clampf(pil_a * 0.72, 0.0, 1.0)

	# 5. Dynamic 3D Lightning Bolts (rebuilt every 0.036s during active phases)
	if is_instance_valid(_bolts_mesh) and _bolts_mesh_inst != null:
		var bolts_active := (t >= 0.16 and t < 2.25)
		_bolts_mesh_inst.visible = bolts_active
		if bolts_active and (_bolt_rebuild_acc >= 0.036 or t < 0.06):
			_bolt_rebuild_acc = 0.0
			_rebuild_dynamic_bolts(t)

	# 6. Storm Sparks
	for sp in _sparks:
		var nd: MeshInstance3D = sp["node"] as MeshInstance3D
		var spmat: StandardMaterial3D = sp["mat"] as StandardMaterial3D
		if t >= 0.72 and t < 2.65:
			var life := fmod((t - 0.72) * float(sp["spd"]) + float(sp["phase"]), 1.0)
			nd.visible = true
			var a := float(sp["angle"]) + life * 0.45
			var r := float(sp["rad"]) * (0.45 + life * 0.95)
			nd.position = _impact_pos + Vector3(cos(a) * r, life * 1.15, sin(a) * r)
			nd.rotation_degrees = Vector3(0.0, rad_to_deg(-a), 18.0)
			spmat.albedo_color = Color(0.65, 0.97, 1.0, sin(life * PI) * 0.90)
		else:
			nd.visible = false

	# 7. Spectral +3 DRAW Curse Cards flying into Rival
	for cc in _curse_cards:
		var cnode: Node3D = cc["node"] as Node3D
		var c_start := float(cc["delay"])
		var c_dur := 0.46
		var cu := (t - c_start) / c_dur
		if cu >= 0.0 and cu <= 1.0:
			cnode.visible = true
			var eu := ease(cu, 0.55)
			var mid_p := _impact_pos.lerp(_rival_pos, 0.5) + Vector3(float(cc["arc_x"]), 0.42, 0.0)
			var p0 := _impact_pos + Vector3(0.0, 0.12, 0.0)
			var pos := p0.lerp(mid_p, eu).lerp(mid_p.lerp(_rival_pos, eu), eu)
			cnode.position = pos
			cnode.rotation_degrees = Vector3(lerpf(-60.0, 12.0, eu), eu * 360.0, float(cc["arc_x"]) * 35.0)
			cnode.scale = Vector3.ONE * lerpf(0.85, 1.15, sin(eu * PI))
		else:
			cnode.visible = false

	# 8. FPV Stage Lighting, Camera Choreography & Rival Recoil
	if _mode == "fpv_preview":
		if is_instance_valid(_warm_light):
			var storm_dim := 0.25 if (t >= 1.35 and t <= 2.25) else 1.0
			_warm_light.light_energy = lerpf(_warm_light.light_energy, 2.4 * storm_dim, 0.25)
		if is_instance_valid(_storm_light):
			if t >= 1.38 and t <= 1.54:
				_storm_light.light_energy = 11.5
			elif t > 1.54 and t <= 2.20:
				_storm_light.light_energy = 4.2 + 3.5 * absf(sin(t * 48.0))
			elif t >= 0.72 and t < 1.38:
				_storm_light.light_energy = 2.4
			else:
				_storm_light.light_energy = 0.0

		if is_instance_valid(_rival_root):
			var recoil := 0.0
			if t >= 1.40 and t <= 2.25:
				recoil = sin(minf((t - 1.40) / 0.85, 1.0) * PI)
			elif t >= 2.25 and t <= 2.95:
				recoil = sin(minf((t - 2.25) / 0.70, 1.0) * PI) * 0.45
			_rival_root.position = _rival_base_pos + Vector3(sin(t * 58.0) * 0.03 * recoil, 0.0, -0.22 * recoil)
			_rival_root.rotation_degrees = Vector3(-16.0 * recoil, 0.0, sin(t * 42.0) * 3.5 * recoil)
			for emat in _rival_eye_mats:
				if is_instance_valid(emat):
					emat.albedo_color = Color(0.55, 0.96, 1.0) if recoil > 0.2 else Color(0.95, 0.72, 0.32)

		if is_instance_valid(_cam):
			var target_fov := _cam_base_fov
			var cam_off := Vector3.ZERO
			var look_off := Vector3.ZERO
			var roll_deg := 0.0
			if t < 0.72:
				var u := ease(t / 0.72, 0.5)
				target_fov = lerpf(54.0, 46.0, u)
				cam_off = Vector3(0.0, -0.05 * u, -0.10 * u)
			elif t < 1.38:
				var punch := maxf(0.0, 1.0 - (t - 0.72) / 0.25)
				target_fov = 48.0 - punch * 3.5
				cam_off = Vector3(sin(t * 72.0) * 0.015 * punch, -0.04 * punch, -0.08)
				roll_deg = sin(t * 60.0) * 1.4 * punch
			elif t < 2.20:
				var quake := 1.0 - clampf((t - 1.38) / 0.82, 0.0, 1.0) * 0.65
				target_fov = 44.0 + (1.0 - quake) * 6.0
				cam_off = Vector3(sin(t * 88.0) * 0.038 * quake, cos(t * 76.0) * 0.032 * quake, -0.14)
				look_off = Vector3(0.0, 0.04, -0.15)
				roll_deg = 4.6 * sin(t * 14.0) * quake
			else:
				var u := ease(clampf((t - 2.20) / 1.15, 0.0, 1.0), 0.45)
				target_fov = lerpf(50.0, _cam_base_fov, u)
				cam_off = Vector3(0.0, 0.0, lerpf(-0.12, 0.0, u))
			_cam.fov = target_fov
			_cam.look_at_from_position(_cam_base_pos + cam_off, _cam_base_look + look_off, Vector3.UP)
			_cam.rotation_degrees.z += roll_deg


func _rebuild_dynamic_bolts(t: float) -> void:
	_bolts_mesh.clear_surfaces()
	_bolts_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	if t < 0.72 and is_instance_valid(_hero_card):
		# Mini arcs crackling around hovering card
		for _i in range(3):
			var p0 := _hero_card.position + Vector3(_rng.randf_range(-0.16, 0.16), _rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.08, 0.08))
			var p1 := _hero_card.position + Vector3(_rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.08, 0.08))
			_emit_bolt_ribbon(p0, p1, 5, 0.045, 0.012, Color(0.55, 0.96, 1.0, 0.92))
	elif t < 1.38:
		# 4 vertical tether conduits from slammed card up to overhead storm vortex
		var top_c := _impact_pos + Vector3(0.0, 1.18, 0.0)
		for i in range(4):
			var ang := float(i) * (PI * 0.5) + t * 2.4
			var b_pt := _impact_pos + Vector3(cos(ang) * 0.24, 0.02, sin(ang) * 0.24)
			var t_pt := top_c + Vector3(cos(ang + 0.5) * 0.34, 0.0, sin(ang + 0.5) * 0.34)
			_emit_bolt_ribbon(b_pt, t_pt, 7, 0.08, 0.018, Color(0.45, 0.94, 1.0, 0.92))
	else:
		# 8 massive jagged sky-splitting bolts into table center + 3 violent chain bolts into Rival!
		var top_c := _impact_pos + Vector3(0.0, 1.32, 0.0)
		for bi in range(8):
			var a := float(bi) * (TAU / 8.0) + _rng.randf_range(-0.25, 0.25)
			var src := top_c + Vector3(cos(a) * _rng.randf_range(0.08, 0.42), 0.12, sin(a) * _rng.randf_range(0.08, 0.42))
			var dst := _impact_pos + Vector3(_rng.randf_range(-0.22, 0.22), 0.01, _rng.randf_range(-0.22, 0.22))
			var col := Color(0.95, 0.99, 1.0, 1.0) if (bi % 2 == 0) else Color(0.32, 0.90, 1.0, 0.95)
			_emit_bolt_ribbon(src, dst, 9, 0.13, 0.026 if bi < 4 else 0.016, col)
		for ci in range(3):
			var r_dst := _rival_pos + Vector3(_rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.08, 0.24), _rng.randf_range(-0.10, 0.10))
			_emit_bolt_ribbon(_impact_pos + Vector3(0.0, 0.08, 0.0), r_dst, 8, 0.12, 0.024, Color(0.55, 0.97, 1.0, 0.98))

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

	# Impact Flash + Radiating Ink Speed-Lines (1.38s - 1.56s)
	if _t >= 1.38 and _t <= 1.58:
		var iu := (_t - 1.38) / 0.20
		var flash_a := (1.0 - iu) * 0.72
		if _t < 1.44:
			_overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.06, 0.14, 0.55))
		_overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.45, 0.94, 1.0, flash_a * 0.48))
		for li in range(28):
			var ang := float(li) * (TAU / 28.0) + 0.08 * float(li % 3)
			var r0 := lerpf(60.0, 140.0, float(li % 4) / 3.0)
			var r1 := maxf(vs.x, vs.y) * 0.85
			var p0 := Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r0
			var p1 := Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r1
			_overlay.draw_line(p0, p1, Color(0.85, 0.98, 1.0, flash_a), 2.5 if li % 2 == 0 else 1.2)

	# Calligraphic Banner: THUNDER STRIKE! (1.44s - 2.90s)
	if _t >= 1.44 and _t <= 2.90 and _font_disp != null:
		var bu := clampf((_t - 1.44) / 0.20, 0.0, 1.0)
		var out_a := 1.0 if _t < 2.45 else clampf(1.0 - (_t - 2.45) / 0.45, 0.0, 1.0)
		var slam_sc := lerpf(1.45, 1.0, ease(bu, 0.35))
		var banner_y := vs.y * 0.19
		var title := "THUNDER STRIKE!"
		var f_sz := int(round(44.0 * slam_sc))

		# Jagged lightning brush slash behind title
		var slash_w := vs.x * 0.44 * bu
		var slash_pts := PackedVector2Array([
			Vector2(cx - slash_w, banner_y - 18.0),
			Vector2(cx + slash_w * 0.92, banner_y - 26.0),
			Vector2(cx + slash_w, banner_y + 18.0),
			Vector2(cx - slash_w * 0.92, banner_y + 24.0),
		])
		_overlay.draw_colored_polygon(slash_pts, Color(0.03, 0.07, 0.15, 0.82 * out_a))
		_overlay.draw_line(Vector2(cx - slash_w, banner_y + 22.0), Vector2(cx + slash_w, banner_y + 22.0), Color(0.35, 0.92, 1.0, 0.95 * out_a), 3.0)

		var text_pos := Vector2(cx - 320.0, banner_y + 12.0)
		_overlay.draw_string(_font_disp, text_pos + Vector2(3.0, 3.0), title, HORIZONTAL_ALIGNMENT_CENTER, 640, f_sz, Color(0.02, 0.04, 0.08, 0.95 * out_a))
		_overlay.draw_string(_font_disp, text_pos, title, HORIZONTAL_ALIGNMENT_CENTER, 640, f_sz, Color(0.65, 0.96, 1.0, out_a))

		if _font_body != null:
			var sub := "+3 RIVAL DRAW  •  ×1.5 COMBO SURGE"
			_overlay.draw_string(_font_body, Vector2(cx - 280.0, banner_y + 42.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 560, 16, Color(0.98, 0.86, 0.42, out_a))
