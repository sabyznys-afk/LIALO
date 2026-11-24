class_name TavernSceneBuilder
extends RefCounted

## Shared Campaign-Parity 3D Tavern Environment Builder & Animator for Multiplayer.
## Mirrors BattleTable3D's dark Liar's Bar atmosphere, sculpted oak/brass table,
## velvet inlay shader, rotating Suit Astrolabe, gothic storm windows, alpine vistas,
## hearth, bar, chandelier, wall lanterns, and interactive tavern props.

const Toon = preload("res://scripts/toon_style.gd")
const Fx = preload("res://scripts/fx_lib.gd")
const RelicMesh = preload("res://scripts/relic_mesh_factory.gd")
const TABLE_INLAY_SHADER := preload("res://shaders/table_cloth.gdshader")

const SUIT_ASTRO_ANGLES := {"CERVEN": 0.0, "ZALUD": PI * 0.5, "ZELEN": PI, "GULA": PI * 1.5}
const SUIT_COLORS := {
	"CERVEN": Color(0.88, 0.20, 0.24),
	"ZELEN": Color(0.18, 0.65, 0.48),
	"ZALUD": Color(0.84, 0.64, 0.38),
	"GULA": Color(0.95, 0.56, 0.24),
}

var env: Environment
var table_spot_light: SpotLight3D
var player_hand_light: OmniLight3D
var hearth_fire_light: OmniLight3D
var boss_rim_lights: Array[SpotLight3D] = []

var table_felt_mat: ShaderMaterial
var astrolabe_root: Node3D
var astrolabe_ring_outer: Node3D
var astrolabe_ring_inner: Node3D
var astrolabe_glow_mat: StandardMaterial3D
var astrolabe_yaw: float = 0.0
var suit_pulse_age: float = 10.0
var last_suit_id: String = ""

var table_arcane_outer: MeshInstance3D
var table_arcane_inner: MeshInstance3D
var table_arcane_mat: StandardMaterial3D
var table_arcane_spin_boost: float = 0.0

var tavern_chandelier: Node3D
var chandelier_cone_mesh: MeshInstance3D
var chandelier_sway_boost: float = 0.0
var wall_lantern_roots: Array[Node3D] = []
var lantern_lights: Array[OmniLight3D] = []
var dust_motes_root: Node3D

var exterior_vista_root: Node3D
var exterior_vista_theme: String = "full_moon"
var storm_rain_meshes: Array[MeshInstance3D] = []
var storm_window_lights: Array[OmniLight3D] = []
var exterior_twinkle_nodes: Array[MeshInstance3D] = []
var exterior_pine_nodes: Array[Node3D] = []
var exterior_lightning_meshes: Array[MeshInstance3D] = []

var tavern_mug_root: Node3D
var tavern_coins_root: Node3D
var tavern_dice_root: Node3D
var tavern_bell_root: Node3D
var table_pot_chips_root: Node3D


func build(parent: Node3D, vista_era: String = "stredovek", disc_center_xz: Vector2 = Vector2.ZERO) -> void:
	_setup_dark_atmosphere_and_lighting(parent)
	_setup_3d_table_and_props(parent, disc_center_xz)
	_setup_epic_3d_tavern_environment(parent, vista_era)
	_spawn_chandelier_volumetric_cone(parent)


func trigger_suit_pulse(power: float = 1.0) -> void:
	suit_pulse_age = 0.0
	if table_felt_mat:
		table_felt_mat.set_shader_parameter("suit_pulse_power", clampf(power, 0.4, 2.0))


func boost_impact(sway: float = 0.8, spin: float = 1.2) -> void:
	chandelier_sway_boost = minf(2.5, chandelier_sway_boost + sway)
	table_arcane_spin_boost = minf(2.8, table_arcane_spin_boost + spin)


func animate_ambient(delta: float, t: float, active_suit_id: String, is_my_turn: bool, is_top_down: bool) -> void:
	if active_suit_id != last_suit_id:
		last_suit_id = active_suit_id
		trigger_suit_pulse(1.2)
	suit_pulse_age += delta
	chandelier_sway_boost = maxf(0.0, chandelier_sway_boost - delta * 1.4)
	table_arcane_spin_boost = maxf(0.0, table_arcane_spin_boost - delta * 1.9)

	var s_col: Color = SUIT_COLORS.get(active_suit_id, Color(0.88, 0.20, 0.24))
	if table_felt_mat:
		table_felt_mat.set_shader_parameter("suit_col", s_col)
		table_felt_mat.set_shader_parameter("suit_pulse_t", suit_pulse_age)
	if is_instance_valid(astrolabe_ring_outer):
		var target: float = -float(SUIT_ASTRO_ANGLES.get(active_suit_id, 0.0))
		astrolabe_yaw = lerp_angle(astrolabe_yaw, target, clampf(6.0 * delta, 0.0, 1.0))
		astrolabe_ring_outer.rotation.y = astrolabe_yaw
		if is_instance_valid(astrolabe_ring_inner):
			astrolabe_ring_inner.rotation.y = -t * 0.25
		if astrolabe_glow_mat:
			astrolabe_glow_mat.albedo_color = astrolabe_glow_mat.albedo_color.lerp(s_col, 5.0 * delta)
			astrolabe_glow_mat.emission = astrolabe_glow_mat.albedo_color
			astrolabe_glow_mat.emission_energy_multiplier = 1.1 + 0.3 * sin(t * 2.4) + clampf(1.0 - suit_pulse_age, 0.0, 1.0) * 2.0

	if is_instance_valid(table_arcane_outer) and is_instance_valid(table_arcane_inner):
		table_arcane_outer.rotation_degrees.y += (14.0 + table_arcane_spin_boost * 95.0) * delta
		table_arcane_inner.rotation_degrees.y -= (24.0 + table_arcane_spin_boost * 135.0) * delta
		if table_arcane_outer.material_override is ShaderMaterial:
			(table_arcane_outer.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(s_col.r, s_col.g, s_col.b, 0.90))
		if table_arcane_inner.material_override is ShaderMaterial:
			var lc := s_col.lightened(0.25)
			(table_arcane_inner.material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(lc.r, lc.g, lc.b, 0.85))
	if table_arcane_mat:
		var pulse := 0.75 + 0.25 * sin(t * 3.2) + table_arcane_spin_boost * 0.9
		table_arcane_mat.albedo_color = table_arcane_mat.albedo_color.lerp(s_col.lightened(0.15), 5.0 * delta)
		table_arcane_mat.emission = table_arcane_mat.emission.lerp(s_col * pulse, 5.0 * delta)

	if is_instance_valid(player_hand_light):
		var target_hl := 0.52 if is_my_turn else 0.28
		player_hand_light.light_energy = lerpf(player_hand_light.light_energy, target_hl, 7.0 * delta)
	if is_instance_valid(table_spot_light):
		var target_sl := 1.90 if is_top_down else (1.72 if is_my_turn else 1.45)
		table_spot_light.light_energy = lerpf(table_spot_light.light_energy, target_sl, 5.5 * delta)
	if is_instance_valid(hearth_fire_light):
		hearth_fire_light.light_energy = 2.6 + sin(t * 11.0) * 0.35 + cos(t * 17.5) * 0.22
	if is_instance_valid(tavern_chandelier):
		var ch_extra := sin(t * 5.2) * chandelier_sway_boost * 4.5
		tavern_chandelier.rotation_degrees.z = sin(t * 1.1) * 1.8 + ch_extra
		tavern_chandelier.rotation_degrees.x = cos(t * 0.85) * 1.2 + cos(t * 4.4) * chandelier_sway_boost * 2.8
	for li in range(wall_lantern_roots.size()):
		var wl_node := wall_lantern_roots[li]
		if is_instance_valid(wl_node):
			wl_node.rotation_degrees.z = sin(t * 1.6 + float(li) * 1.3) * (1.1 + chandelier_sway_boost * 2.4)
	for i in range(lantern_lights.size()):
		var ll := lantern_lights[i]
		if is_instance_valid(ll):
			ll.light_energy = 1.7 + sin(t * 8.5 + float(i) * 2.1) * 0.22

	var storm_flash := 0.0
	if exterior_vista_theme == "storm_rain":
		storm_flash = pow(maxf(0.0, sin(t * 0.65) * sin(t * 4.3 + 0.7)), 10.0)
	for wl in storm_window_lights:
		if not is_instance_valid(wl):
			continue
		if exterior_vista_theme == "sun_mountains":
			wl.light_energy = 2.6 + sin(t * 0.8) * 0.25
		elif exterior_vista_theme == "full_moon":
			wl.light_energy = 2.1 + sin(t * 1.1) * 0.15
		elif exterior_vista_theme == "starry_night":
			wl.light_energy = 1.25
		else:
			wl.light_energy = 1.55 + storm_flash * 5.0
	for lt in exterior_lightning_meshes:
		if is_instance_valid(lt):
			lt.visible = (storm_flash > 0.18)
	for st_n in exterior_twinkle_nodes:
		if is_instance_valid(st_n):
			var phs := float(st_n.get_meta("phase", 0.0))
			var twk := 0.65 + 0.45 * sin(t * 2.8 + phs)
			st_n.scale = Vector3(twk, twk, 1.0)
	for drp in storm_rain_meshes:
		if not is_instance_valid(drp) or not drp.visible:
			continue
		var dph: float = float(drp.get_meta("phase", 0.0))
		var cycle := fmod(t * 2.4 + dph, 1.0)
		drp.position.y = 0.70 - cycle * 1.40
		drp.position.x = float(drp.get_meta("base_x", 0.0)) - cycle * 0.32
	if is_instance_valid(dust_motes_root):
		for m in dust_motes_root.get_children():
			var bp: Vector3 = m.get_meta("base_pos")
			var ph: float = float(m.get_meta("phase", 0.0))
			var swirl := table_arcane_spin_boost * 0.08
			m.position = bp + Vector3(sin(t * 0.7 + ph) * (0.07 + swirl), cos(t * 0.55 + ph) * 0.06 + swirl * 0.5, sin(t * 0.45 + ph * 1.3) * (0.07 + swirl))
			var m_sc := 0.72 + 0.42 * sin(t * 3.4 + ph * 1.7)
			m.scale = Vector3(m_sc, m_sc, m_sc)
	for i in range(exterior_pine_nodes.size()):
		var pn := exterior_pine_nodes[i]
		if is_instance_valid(pn):
			pn.rotation_degrees.z = sin(t * 1.45 + float(i) * 0.9) * 2.8


func _setup_dark_atmosphere_and_lighting(parent: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.020, 0.028, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.085, 0.09, 0.13)
	env.ambient_light_energy = 0.72
	env.fog_enabled = true
	env.fog_light_color = Color(0.025, 0.032, 0.055)
	env.fog_density = 0.024
	env_node.environment = env
	parent.add_child(env_node)

	table_spot_light = SpotLight3D.new()
	table_spot_light.position = Vector3(0.0, 2.80, 0.05)
	table_spot_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	table_spot_light.light_color = Color(1.0, 0.87, 0.70)
	table_spot_light.light_energy = 1.65
	table_spot_light.spot_range = 6.5
	table_spot_light.spot_angle = 49.0
	table_spot_light.spot_angle_attenuation = 1.9
	table_spot_light.shadow_enabled = true
	parent.add_child(table_spot_light)

	player_hand_light = OmniLight3D.new()
	player_hand_light.position = Vector3(0.0, 1.38, 1.22)
	player_hand_light.light_color = Color(0.98, 0.90, 0.78)
	player_hand_light.light_energy = 0.55
	player_hand_light.omni_range = 2.3
	parent.add_child(player_hand_light)

	# Warm rim backlights across the far semicircle so 2-4P opponent avatars read cleanly like Campaign bosses
	for rspec in [
		{"pos": Vector3(0.0, 1.88, -2.36), "rot": Vector3(-28.0, 0.0, 0.0), "e": 3.4},
		{"pos": Vector3(-2.15, 1.85, -1.25), "rot": Vector3(-28.0, -56.0, 0.0), "e": 2.4},
		{"pos": Vector3(2.15, 1.85, -1.25), "rot": Vector3(-28.0, 56.0, 0.0), "e": 2.4},
	]:
		var rim := SpotLight3D.new()
		rim.position = rspec["pos"]
		rim.rotation_degrees = rspec["rot"]
		rim.light_color = Color(1.0, 0.66, 0.24)
		rim.light_energy = float(rspec["e"])
		rim.spot_range = 3.8
		rim.spot_angle = 48.0
		parent.add_child(rim)
		boss_rim_lights.append(rim)


func _load_glb_model(res_path: String, cast_shadows: bool = true) -> Node3D:
	var inst_node: Node3D = null
	if ResourceLoader.exists(res_path):
		var packed := load(res_path) as PackedScene
		if packed:
			var sc := packed.instantiate()
			if sc is Node3D:
				inst_node = sc as Node3D
	if inst_node == null and FileAccess.file_exists(res_path):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(res_path), st) == OK:
			var gen := doc.generate_scene(st)
			if gen is Node3D:
				inst_node = gen as Node3D
	if inst_node:
		_set_shadow_mode_recursive(inst_node, cast_shadows)
	return inst_node


func _set_shadow_mode_recursive(node: Node, cast_shadows: bool) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in node.get_children():
		_set_shadow_mode_recursive(ch, cast_shadows)


func _apply_mat_by_mesh_name(root: Node, mat_map: Dictionary) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var nm := mi.name.to_lower()
		for k in mat_map.keys():
			if str(k).to_lower() in nm:
				mi.material_override = mat_map[k]
				break
	for ch in root.get_children():
		_apply_mat_by_mesh_name(ch, mat_map)


func _make_triplanar_pbr_mat(tex_path: String, tint: Color, world_scale: float, roughness: float = 0.85, metallic: float = 0.04) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = roughness
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3(world_scale, world_scale, world_scale)
	if tex_path != "":
		var t := Toon.tex(tex_path)
		if t:
			m.albedo_texture = t
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.albedo_color = Color(1, 1, 1, 1).lerp(tint, 0.56)
	return m


func _make_arrow_compass_ring_mat(ring_col: Color, arrow_cnt: float = 8.0, spd: float = 1.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 ring_color : source_color = vec4(1.0, 0.82, 0.32, 0.90);
uniform float num_arrows = 8.0;
uniform float anim_spd = 1.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float outer_ring = smoothstep(0.024, 0.004, abs(r - 0.90));
	float mid_ring = smoothstep(0.018, 0.003, abs(r - 0.74));
	float inner_ring = smoothstep(0.020, 0.003, abs(r - 0.54));
	float ticks = smoothstep(0.42, 0.68, cos(ang * 36.0 + TIME * 0.4 * anim_spd)) * smoothstep(0.05, 0.01, abs(r - 0.82));
	float runes = smoothstep(0.12, 0.38, sin(ang * 16.0 - TIME * 0.8 * anim_spd)) * smoothstep(0.028, 0.006, abs(r - 0.64));
	float a_cell = fract((ang / 6.2831853) * num_arrows) * 2.0 - 1.0;
	float pulse_r = 0.78 - 0.055 * sin(TIME * 3.4 * anim_spd);
	float chev_dist = abs(r - (pulse_r - abs(a_cell) * 0.11));
	float chev = smoothstep(0.026, 0.005, chev_dist) * smoothstep(0.66, 0.56, abs(a_cell)) * smoothstep(0.53, 0.59, r) * smoothstep(0.95, 0.89, r);
	float chev2_dist = abs(r - (pulse_r - 0.12 - abs(a_cell) * 0.09));
	float chev2 = smoothstep(0.020, 0.004, chev2_dist) * smoothstep(0.52, 0.42, abs(a_cell)) * smoothstep(0.43, 0.49, r) * smoothstep(0.87, 0.81, r) * 0.75;
	float alpha = clamp(outer_ring * 0.95 + mid_ring * 0.75 + inner_ring * 0.65 + ticks * 0.70 + runes * 0.55 + (chev + chev2) * 1.15, 0.0, 1.0);
	ALBEDO = mix(ring_color.rgb, vec3(1.0, 0.97, 0.84), clamp(chev + chev2, 0.0, 1.0) * 0.55);
	ALPHA = alpha * ring_color.a * smoothstep(1.0, 0.94, r);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.render_priority = 1
	sm.set_shader_parameter("ring_color", ring_col)
	sm.set_shader_parameter("num_arrows", arrow_cnt)
	sm.set_shader_parameter("anim_spd", spd)
	return sm


func _setup_3d_table_and_props(parent: Node3D, disc_center_xz: Vector2) -> void:
	var table_glb := _load_glb_model("res://assets/models/battle_table.glb", true)
	if table_glb:
		table_glb.name = "BattleTableGLB"
		var tbl_wood := _make_triplanar_pbr_mat("res://assets/table/wood.png", Color(0.24, 0.14, 0.09), 0.72, 0.68, 0.04)
		var tbl_leather := _make_triplanar_pbr_mat("res://assets/gloves/glove_leather.png", Color(0.14, 0.08, 0.06), 1.45, 0.72, 0.04)
		var tbl_brass := Toon.pbr(Color(0.76, 0.56, 0.20), "", 0.30, 0.88)
		var tbl_iron := Toon.pbr(Color(0.15, 0.16, 0.19), "", 0.44, 0.84)
		_apply_mat_by_mesh_name(table_glb, {
			"tablefootpad": tbl_iron,
			"rimbracket": tbl_iron,
			"stretcherring": tbl_iron,
			"tablebrass": tbl_brass,
			"rimstud": tbl_brass,
			"aproncorbel": tbl_brass,
			"tablebolsterleather": tbl_leather,
			"tablebodyslab": tbl_wood,
			"tablegothicapron": tbl_wood,
			"tablepedestal": tbl_wood,
			"tablefoot": tbl_wood,
		})
		parent.add_child(table_glb)
	else:
		var table_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new(); cyl.top_radius = 1.85; cyl.bottom_radius = 1.76; cyl.height = 0.12; cyl.radial_segments = 20
		table_mesh.mesh = cyl; table_mesh.material_override = Toon.pbr(Color(0.42, 0.27, 0.16), "res://assets/table/wood.png", 0.62, 0.04, Vector2(2.4, 2.4)); table_mesh.position = Vector3(0.0, 0.74, 0.0)
		parent.add_child(table_mesh)

	var floor_mesh := MeshInstance3D.new()
	var fplane := PlaneMesh.new()
	fplane.size = Vector2(18.0, 18.0)
	floor_mesh.mesh = fplane
	floor_mesh.material_override = _make_triplanar_pbr_mat("res://assets/table/stone_floor.png", Color(0.32, 0.30, 0.30), 0.42, 0.90, 0.02)
	parent.add_child(floor_mesh)

	var rug_mesh := MeshInstance3D.new()
	var rcyl := CylinderMesh.new()
	rcyl.top_radius = 2.65
	rcyl.bottom_radius = 2.65
	rcyl.height = 0.012
	rcyl.radial_segments = 24
	rug_mesh.mesh = rcyl
	rug_mesh.position = Vector3(0.0, 0.008, 0.0)
	rug_mesh.material_override = Toon.pbr(Color(0.40, 0.14, 0.13), "res://assets/table/felt.png", 0.92, 0.0, Vector2(2.6, 2.6))
	parent.add_child(rug_mesh)

	var felt := MeshInstance3D.new()
	var felt_cyl := CylinderMesh.new()
	felt_cyl.top_radius = 1.38
	felt_cyl.bottom_radius = 1.40
	felt_cyl.height = 0.020
	felt_cyl.radial_segments = 48
	felt.mesh = felt_cyl
	table_felt_mat = ShaderMaterial.new()
	table_felt_mat.shader = TABLE_INLAY_SHADER
	table_felt_mat.set_shader_parameter("cloth_tex", Toon.tex("res://assets/table/felt.png"))
	table_felt_mat.set_shader_parameter("mat_radius", 1.38)
	table_felt_mat.set_shader_parameter("disc_center", disc_center_xz)
	felt.material_override = table_felt_mat
	felt.position = Vector3(0.0, 0.805, 0.0)
	parent.add_child(felt)

	_build_suit_astrolabe_and_rim(parent, disc_center_xz)

	table_arcane_mat = StandardMaterial3D.new()
	table_arcane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	table_arcane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	table_arcane_mat.albedo_color = Color(0.95, 0.72, 0.28, 0.52)

	table_arcane_outer = MeshInstance3D.new()
	var a_plane1 := PlaneMesh.new()
	a_plane1.size = Vector2(1.48, 1.48)
	table_arcane_outer.mesh = a_plane1
	table_arcane_outer.position = Vector3(disc_center_xz.x, 0.815, disc_center_xz.y)
	table_arcane_outer.material_override = _make_arrow_compass_ring_mat(Color(0.95, 0.74, 0.28, 0.78), 12.0, 0.65)
	parent.add_child(table_arcane_outer)

	table_arcane_inner = MeshInstance3D.new()
	var a_plane2 := PlaneMesh.new()
	a_plane2.size = Vector2(0.86, 0.86)
	table_arcane_inner.mesh = a_plane2
	table_arcane_inner.position = Vector3(disc_center_xz.x, 0.8165, disc_center_xz.y)
	table_arcane_inner.material_override = _make_arrow_compass_ring_mat(Color(1.0, 0.84, 0.36, 0.92), 8.0, 1.25)
	parent.add_child(table_arcane_inner)
	var chev_brass := Toon.pbr(Color(0.92, 0.72, 0.26), "", 0.26, 0.86, Vector2.ONE, Color(0.28, 0.18, 0.04), 0.35)
	for ai in range(8):
		var aang := float(ai) * TAU / 8.0
		var chev := MeshInstance3D.new()
		var cp := PrismMesh.new(); cp.size = Vector3(0.042, 0.052, 0.008)
		chev.mesh = cp
		chev.position = Vector3(cos(aang) * 0.365, 0.004, sin(aang) * 0.365)
		chev.rotation_degrees = Vector3(-90.0, -rad_to_deg(aang) - 90.0, 0.0)
		chev.material_override = chev_brass
		table_arcane_inner.add_child(chev)

	# Decorative & Clickable Campaign Table Props (offset cleanly from MP seat positions)
	_spawn_candle(parent, Vector3(-0.98, 0.80, -0.54))
	_spawn_mug(parent, Vector3(0.96, 0.80, -0.48))
	_spawn_table_dice_and_coins(parent)
	_spawn_tavern_shop_bell(parent, Vector3(-0.92, 0.806, -0.10))

	table_pot_chips_root = Node3D.new()
	table_pot_chips_root.position = Vector3(0.56, 0.816, -0.06)
	parent.add_child(table_pot_chips_root)
	for st_i in range(3):
		var col_chip := Color(0.96, 0.78, 0.22) if st_i % 2 == 0 else Color(0.84, 0.22, 0.26)
		var cmat := Toon.mat(col_chip, "", 0.004, Vector2.ONE, col_chip * 0.12)
		var sx := -0.06 + float(st_i) * 0.062
		var sz := 0.02 if st_i == 1 else -0.02
		var stack_h := 5 - st_i
		for ch_j in range(stack_h):
			var cm := MeshInstance3D.new()
			var cc := CylinderMesh.new(); cc.top_radius = 0.026; cc.bottom_radius = 0.026; cc.height = 0.009; cc.radial_segments = 14
			cm.mesh = cc; cm.material_override = cmat
			cm.position = Vector3(sx, 0.006 + float(ch_j) * 0.010, sz)
			table_pot_chips_root.add_child(cm)


func _build_suit_astrolabe_and_rim(parent: Node3D, disc_center_xz: Vector2) -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.80, 0.60, 0.24)
	brass.metallic = 0.90
	brass.roughness = 0.30
	var dark_brass := StandardMaterial3D.new()
	dark_brass.albedo_color = Color(0.40, 0.28, 0.12)
	dark_brass.metallic = 0.75
	dark_brass.roughness = 0.45
	astrolabe_glow_mat = StandardMaterial3D.new()
	astrolabe_glow_mat.albedo_color = Color(0.9, 0.2, 0.2)
	astrolabe_glow_mat.emission_enabled = true
	astrolabe_glow_mat.emission = Color(0.9, 0.2, 0.2)
	astrolabe_glow_mat.emission_energy_multiplier = 1.4
	astrolabe_glow_mat.metallic = 0.4
	astrolabe_glow_mat.roughness = 0.3

	astrolabe_root = Node3D.new()
	astrolabe_root.name = "SuitAstrolabe"
	astrolabe_root.position = Vector3(disc_center_xz.x, 0.817, disc_center_xz.y)
	parent.add_child(astrolabe_root)

	var outer_fixed := MeshInstance3D.new()
	var otm := TorusMesh.new(); otm.inner_radius = 0.385; otm.outer_radius = 0.405; otm.rings = 64; otm.ring_segments = 6
	outer_fixed.mesh = otm; outer_fixed.scale = Vector3(1.0, 0.25, 1.0); outer_fixed.material_override = dark_brass
	outer_fixed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	astrolabe_root.add_child(outer_fixed)

	astrolabe_ring_outer = Node3D.new()
	astrolabe_root.add_child(astrolabe_ring_outer)
	var rot_ring := MeshInstance3D.new()
	var rtm := TorusMesh.new(); rtm.inner_radius = 0.352; rtm.outer_radius = 0.368; rtm.rings = 64; rtm.ring_segments = 6
	rot_ring.mesh = rtm; rot_ring.scale = Vector3(1.0, 0.3, 1.0); rot_ring.material_override = brass
	rot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	astrolabe_ring_outer.add_child(rot_ring)

	var suit_ids := ["CERVEN", "ZALUD", "ZELEN", "GULA"]
	for i in range(4):
		var a: float = SUIT_ASTRO_ANGLES[suit_ids[i]]
		var gem := MeshInstance3D.new()
		var gm := SphereMesh.new(); gm.radius = 0.018; gm.height = 0.022; gm.radial_segments = 10; gm.rings = 5
		gem.mesh = gm
		var gmat := StandardMaterial3D.new()
		var sc: Color = SUIT_COLORS.get(suit_ids[i], Color.WHITE)
		gmat.albedo_color = sc
		gmat.emission_enabled = true
		gmat.emission = sc
		gmat.emission_energy_multiplier = 0.9
		gem.material_override = gmat
		gem.position = Vector3(sin(a) * 0.36, 0.006, cos(a) * 0.36)
		astrolabe_ring_outer.add_child(gem)
		for t_i in range(6):
			var tk := MeshInstance3D.new()
			var tb := BoxMesh.new(); tb.size = Vector3(0.004, 0.003, 0.014)
			tk.mesh = tb; tk.material_override = brass
			var ta := a + (float(t_i) - 2.5) * 0.12
			tk.position = Vector3(sin(ta) * 0.376, 0.002, cos(ta) * 0.376)
			tk.rotation.y = ta
			astrolabe_ring_outer.add_child(tk)

	astrolabe_ring_inner = Node3D.new()
	astrolabe_root.add_child(astrolabe_ring_inner)
	var in_ring := MeshInstance3D.new()
	var itm := TorusMesh.new(); itm.inner_radius = 0.322; itm.outer_radius = 0.330; itm.rings = 64; itm.ring_segments = 4
	in_ring.mesh = itm; in_ring.scale = Vector3(1.0, 0.2, 1.0); in_ring.material_override = astrolabe_glow_mat
	in_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	astrolabe_ring_inner.add_child(in_ring)
	for k in range(8):
		var sp := MeshInstance3D.new()
		var sb := BoxMesh.new(); sb.size = Vector3(0.006, 0.002, 0.05)
		sp.mesh = sb; sp.material_override = astrolabe_glow_mat
		var ka := float(k) * TAU / 8.0
		sp.position = Vector3(sin(ka) * 0.30, 0.0, cos(ka) * 0.30)
		sp.rotation.y = ka
		astrolabe_ring_inner.add_child(sp)

	var ptr := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.04, 0.035, 0.008)
	ptr.mesh = pm; ptr.material_override = brass
	ptr.rotation_degrees = Vector3(-90.0, 0.0, 180.0)
	ptr.position = Vector3(0.0, 0.004, 0.425)
	astrolabe_root.add_child(ptr)

	# Carved brass rim studs & corner brackets
	var rim_r := 1.395
	var rim_y := 0.818
	for s_i in range(-9, 10):
		var ang := deg_to_rad(float(s_i) * 6.0)
		var stud := MeshInstance3D.new()
		var stm := SphereMesh.new(); stm.radius = 0.011; stm.height = 0.012; stm.radial_segments = 8; stm.rings = 4
		stud.mesh = stm; stud.material_override = brass
		stud.position = Vector3(sin(ang) * rim_r, rim_y, cos(ang) * rim_r)
		parent.add_child(stud)
	for s_i in range(-8, 9):
		var a0 := deg_to_rad(float(s_i) * 6.0 + 3.0)
		var seg := MeshInstance3D.new()
		var sbm := BoxMesh.new(); sbm.size = Vector3(0.14, 0.003, 0.008)
		seg.mesh = sbm; seg.material_override = brass
		seg.position = Vector3(sin(a0) * 1.36, 0.8165, cos(a0) * 1.36)
		seg.rotation.y = a0 + PI * 0.5
		parent.add_child(seg)
	for side in [-1.0, 1.0]:
		var ba := deg_to_rad(side * 58.0)
		var bracket := Node3D.new()
		bracket.position = Vector3(sin(ba) * 1.38, rim_y, cos(ba) * 1.38)
		bracket.rotation.y = ba
		parent.add_child(bracket)
		var plate := MeshInstance3D.new()
		var plm := BoxMesh.new(); plm.size = Vector3(0.16, 0.012, 0.09)
		plate.mesh = plm; plate.material_override = brass
		bracket.add_child(plate)
		var boss_knob := MeshInstance3D.new()
		var bkm := SphereMesh.new(); bkm.radius = 0.022; bkm.height = 0.02
		boss_knob.mesh = bkm; boss_knob.position = Vector3(0, 0.008, 0); boss_knob.material_override = dark_brass
		bracket.add_child(boss_knob)

	var relic_tray := Node3D.new()
	relic_tray.name = "RelicAltarTray"
	relic_tray.position = Vector3(-0.62, 0.816, -0.10)
	relic_tray.rotation_degrees.y = 14.0
	parent.add_child(relic_tray)
	var tray_wood := Toon.mat(Color(0.22, 0.14, 0.09), "res://assets/table/wood.png", 0.008)
	var tray_base := MeshInstance3D.new()
	var tbm := BoxMesh.new(); tbm.size = Vector3(0.32, 0.014, 0.68)
	tray_base.mesh = tbm; tray_base.material_override = tray_wood
	relic_tray.add_child(tray_base)
	var tray_rim := MeshInstance3D.new()
	var trm := BoxMesh.new(); trm.size = Vector3(0.34, 0.022, 0.70)
	tray_rim.mesh = trm; tray_rim.position.y = -0.002; tray_rim.material_override = dark_brass
	relic_tray.add_child(tray_rim)


func _setup_epic_3d_tavern_environment(parent: Node3D, vista_era: String) -> void:
	var beam_mat := _make_triplanar_pbr_mat("res://assets/table/wood.png", Color(0.24, 0.16, 0.10), 0.52, 0.72, 0.04)
	var wainscot_mat := _make_triplanar_pbr_mat("res://assets/table/wood.png", Color(0.18, 0.11, 0.07), 0.65, 0.66, 0.05)
	var iron_mat := Toon.pbr(Color(0.18, 0.20, 0.24), "", 0.42, 0.84)
	var stone_wall_mat := _make_triplanar_pbr_mat("res://assets/table/stone_floor.png", Color(0.24, 0.23, 0.25), 0.44, 0.90, 0.02)

	# Tavern chairs around far & side arcs
	_spawn_tavern_chair(parent, Vector3(0.0, 0.0, -2.02), 0.0, beam_mat, 1.15)
	_spawn_tavern_chair(parent, Vector3(-2.05, 0.0, -0.35), 78.0, beam_mat, 0.95)
	_spawn_tavern_chair(parent, Vector3(2.05, 0.0, -0.35), -78.0, beam_mat, 0.95)

	# Front wall with gothic storm window openings
	_add_wall_block(parent, Vector3(0.0, 0.80, -5.2), Vector3(13.0, 1.60, 0.4), stone_wall_mat)
	_add_wall_block(parent, Vector3(0.0, 4.25, -5.2), Vector3(13.0, 1.90, 0.4), stone_wall_mat)
	_add_wall_block(parent, Vector3(0.0, 2.45, -5.2), Vector3(2.86, 1.70, 0.4), stone_wall_mat)
	_add_wall_block(parent, Vector3(-4.60, 2.45, -5.2), Vector3(3.84, 1.70, 0.4), stone_wall_mat)
	_add_wall_block(parent, Vector3(4.60, 2.45, -5.2), Vector3(3.84, 1.70, 0.4), stone_wall_mat)

	# Rear stone wall + wainscoting (so 3-4P free look behind never reveals void!)
	_add_wall_block(parent, Vector3(0.0, 2.6, 5.4), Vector3(13.0, 5.2, 0.4), stone_wall_mat)
	_add_wall_block(parent, Vector3(0.0, 0.56, 5.16), Vector3(11.4, 1.12, 0.12), wainscot_mat)

	_add_wall_block(parent, Vector3(0.0, 0.56, -4.96), Vector3(11.4, 1.12, 0.12), wainscot_mat)
	_add_wall_block(parent, Vector3(0.0, 1.16, -4.92), Vector3(11.5, 0.10, 0.18), beam_mat)
	for px_w in range(-5, 6):
		_add_wall_block(parent, Vector3(float(px_w) * 1.05, 0.56, -4.89), Vector3(0.14, 1.06, 0.06), beam_mat)

	for side_x in [-5.6, 5.6]:
		_add_wall_block(parent, Vector3(side_x, 2.6, -0.2), Vector3(0.4, 5.2, 11.5), stone_wall_mat)
		_add_wall_block(parent, Vector3(side_x - signf(side_x) * 0.22, 0.56, -0.2), Vector3(0.12, 1.12, 11.2), wainscot_mat)
		_add_wall_block(parent, Vector3(side_x - signf(side_x) * 0.25, 1.16, -0.2), Vector3(0.18, 0.10, 11.2), beam_mat)

	for px in [-3.4, 3.4, -5.1, 5.1]:
		var pz := -4.8 if absf(px) < 4.0 else -1.6
		var pillar := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.38, 4.8, 0.38)
		pillar.mesh = pb; pillar.position = Vector3(px, 2.4, pz); pillar.material_override = beam_mat
		parent.add_child(pillar)

	for bz in [-4.5, -2.2, 0.0, 2.2]:
		var cbeam := MeshInstance3D.new()
		var cb := BoxMesh.new(); cb.size = Vector3(11.6, 0.32, 0.34)
		cbeam.mesh = cb; cbeam.position = Vector3(0.0, 4.3, bz); cbeam.material_override = beam_mat
		parent.add_child(cbeam)

	var ceiling := MeshInstance3D.new()
	var cplane := BoxMesh.new(); cplane.size = Vector3(13.0, 0.2, 12.5)
	ceiling.mesh = cplane; ceiling.position = Vector3(0.0, 4.65, -0.2); ceiling.material_override = beam_mat
	parent.add_child(ceiling)

	for lx in [-3.4, 0.0, 3.4]:
		var rbeam := MeshInstance3D.new()
		var rb := BoxMesh.new(); rb.size = Vector3(0.28, 0.28, 11.5)
		rbeam.mesh = rb; rbeam.position = Vector3(lx, 4.42, -0.2); rbeam.material_override = beam_mat
		parent.add_child(rbeam)

	for wx in [-2.05, 2.05]:
		_spawn_storm_window(parent, Vector3(wx, 2.45, -5.08), beam_mat, iron_mat)
	exterior_vista_root = Node3D.new()
	parent.add_child(exterior_vista_root)
	apply_vista_era(vista_era)

	_spawn_tavern_hearth(parent, Vector3(-5.05, 0.0, -0.35), stone_wall_mat, beam_mat)

	_spawn_tavern_barrel(parent, Vector3(-3.35, 0.0, -3.55), 0.95, beam_mat, iron_mat)
	_spawn_tavern_barrel(parent, Vector3(-4.15, 0.0, -2.85), 0.85, beam_mat, iron_mat)
	_spawn_tavern_barrel(parent, Vector3(-3.65, 0.98, -3.35), 0.72, beam_mat, iron_mat, 90.0)
	_spawn_tavern_barrel(parent, Vector3(3.65, 0.0, -3.55), 0.95, beam_mat, iron_mat)
	_spawn_crate(parent, Vector3(-4.35, 0.0, -4.05), 0.75, beam_mat)
	_spawn_crate(parent, Vector3(4.35, 0.0, -0.20), 0.68, beam_mat)
	_spawn_crate(parent, Vector3(4.45, 0.68, -0.25), 0.50, beam_mat)
	_spawn_wall_trophy(parent, Vector3(-3.16, 2.55, -4.75), iron_mat, beam_mat)
	_spawn_wall_trophy(parent, Vector3(3.16, 2.55, -4.75), iron_mat, beam_mat)

	var bar_glb := _load_glb_model("res://assets/models/tavern_bar.glb", true)
	if bar_glb:
		bar_glb.position = Vector3(4.2, 0.0, -2.2)
		var bar_brass := Toon.pbr(Color(0.78, 0.58, 0.22), "", 0.28, 0.88)
		_apply_mat_by_mesh_name(bar_glb, {
			"barfootrail": bar_brass,
			"footbracket": bar_brass,
			"barbody": beam_mat,
			"barplinth": beam_mat,
			"barcountertop": beam_mat,
			"barpanel": beam_mat,
			"barpilaster": beam_mat,
		})
		parent.add_child(bar_glb)

	var shelf := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.45, 0.08, 2.4)
	shelf.mesh = sm; shelf.position = Vector3(5.2, 2.15, -2.2); shelf.material_override = beam_mat
	parent.add_child(shelf)
	var bottle_colors := [Color(0.15, 0.26, 0.17), Color(0.30, 0.12, 0.10), Color(0.24, 0.18, 0.11), Color(0.16, 0.18, 0.26)]
	for si in range(6):
		var sc: Color = bottle_colors[(si + 1) % bottle_colors.size()]
		var smat := Toon.pbr(sc, "", 0.18, 0.05)
		var sz := -3.15 + float(si) * 0.36
		var sb := MeshInstance3D.new()
		var sbc := CylinderMesh.new(); sbc.top_radius = 0.036; sbc.bottom_radius = 0.048; sbc.height = 0.15
		sb.mesh = sbc; sb.material_override = smat; sb.position = Vector3(5.16, 2.26, sz)
		parent.add_child(sb)
		var sneck := MeshInstance3D.new()
		var snc := CylinderMesh.new(); snc.top_radius = 0.016; snc.bottom_radius = 0.022; snc.height = 0.07
		sneck.mesh = snc; sneck.material_override = smat; sneck.position = Vector3(5.16, 2.36, sz)
		parent.add_child(sneck)

	_spawn_wall_banner(parent, Vector3(-3.82, 3.72, -4.90), Color(0.56, 0.12, 0.14), Color(0.90, 0.70, 0.24))
	_spawn_wall_banner(parent, Vector3(3.82, 3.72, -4.90), Color(0.14, 0.32, 0.48), Color(0.90, 0.70, 0.24))
	_spawn_wall_banner(parent, Vector3(0.0, 4.02, -4.94), Color(0.16, 0.34, 0.22), Color(0.94, 0.74, 0.28))

	_spawn_gothic_room_architecture(parent, beam_mat, stone_wall_mat)

	_spawn_wall_lantern(parent, Vector3(-3.12, 2.25, -4.85), iron_mat)
	_spawn_wall_lantern(parent, Vector3(3.12, 2.25, -4.85), iron_mat)
	_spawn_wall_lantern(parent, Vector3(-1.12, 2.38, -4.86), iron_mat)
	_spawn_wall_lantern(parent, Vector3(1.12, 2.38, -4.86), iron_mat)
	_spawn_wall_lantern(parent, Vector3(5.32, 2.35, -1.6), iron_mat, -90.0)

	tavern_chandelier = Node3D.new()
	tavern_chandelier.position = Vector3(0.0, 4.2, 0.05)
	parent.add_child(tavern_chandelier)
	var chand_glb := _load_glb_model("res://assets/models/tavern_chandelier.glb", true)
	if chand_glb:
		chand_glb.name = "TavernChandelierGLB"
		tavern_chandelier.add_child(chand_glb)

	dust_motes_root = Node3D.new()
	parent.add_child(dust_motes_root)
	var mote_mat := Toon.mat(Color(1.0, 0.88, 0.62), "", 0.0, Vector2.ONE, Color(0.95, 0.75, 0.38))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	for _i in range(30):
		var mote := MeshInstance3D.new()
		var ms := SphereMesh.new(); ms.radius = rng.randf_range(0.008, 0.017); ms.height = ms.radius * 2.0
		mote.mesh = ms; mote.material_override = mote_mat
		var base_p := Vector3(rng.randf_range(-1.55, 1.55), rng.randf_range(1.02, 2.45), rng.randf_range(-1.35, 1.05))
		mote.position = base_p
		mote.set_meta("base_pos", base_p)
		mote.set_meta("phase", rng.randf_range(0.0, TAU))
		dust_motes_root.add_child(mote)


func _spawn_gothic_room_architecture(parent: Node3D, beam_mat: Material, stone_mat: Material) -> void:
	var brass_mat := Toon.pbr(Color(0.88, 0.68, 0.24), "", 0.26, 0.88)
	for wx in [-2.05, 2.05]:
		var sill := MeshInstance3D.new()
		var sb := BoxMesh.new(); sb.size = Vector3(1.52, 0.14, 0.36)
		sill.mesh = sb; sill.position = Vector3(wx, 1.56, -4.96); sill.material_override = stone_mat
		parent.add_child(sill)
		for side in [-1.0, 1.0]:
			var arch_arm := MeshInstance3D.new()
			var aab := BoxMesh.new(); aab.size = Vector3(0.86, 0.18, 0.34)
			arch_arm.mesh = aab
			arch_arm.position = Vector3(wx + side * 0.34, 3.36, -4.96)
			arch_arm.rotation_degrees.z = -side * 26.0
			arch_arm.material_override = stone_mat
			parent.add_child(arch_arm)
		var keystone := MeshInstance3D.new()
		var ksb := BoxMesh.new(); ksb.size = Vector3(0.24, 0.30, 0.38)
		keystone.mesh = ksb; keystone.position = Vector3(wx, 3.52, -4.94); keystone.material_override = brass_mat
		parent.add_child(keystone)

	for bz in [-4.45, -2.20, 0.0]:
		for side in [-1.0, 1.0]:
			var strut := MeshInstance3D.new()
			var stb := BoxMesh.new(); stb.size = Vector3(1.65, 0.22, 0.26)
			strut.mesh = stb; strut.position = Vector3(side * 2.68, 3.68, bz); strut.rotation_degrees.z = -side * 34.0; strut.material_override = beam_mat
			parent.add_child(strut)
		var boss_key := MeshInstance3D.new()
		var bkb := CylinderMesh.new(); bkb.top_radius = 0.18; bkb.bottom_radius = 0.18; bkb.height = 0.12
		boss_key.mesh = bkb; boss_key.position = Vector3(0.0, 4.18, bz); boss_key.rotation_degrees.x = 90.0; boss_key.material_override = brass_mat
		parent.add_child(boss_key)

	var crest_root := Node3D.new()
	crest_root.name = "WallCrestShieldRoot"
	crest_root.position = Vector3(0.0, 2.55, -4.82)
	parent.add_child(crest_root)
	var crest_glb := _load_glb_model("res://assets/models/wall_crest_shield.glb", true)
	if crest_glb:
		crest_glb.name = "WallCrestShieldGLB"
		crest_root.add_child(crest_glb)

	var alc_shelf := MeshInstance3D.new()
	var asm := BoxMesh.new(); asm.size = Vector3(1.15, 0.08, 0.36)
	alc_shelf.mesh = asm; alc_shelf.position = Vector3(3.25, 1.72, -4.82); alc_shelf.material_override = beam_mat
	parent.add_child(alc_shelf)
	var potion_cols := [Color(0.20, 0.88, 0.48), Color(0.92, 0.22, 0.36), Color(0.32, 0.66, 1.0), Color(0.96, 0.76, 0.22)]
	for p_i in range(4):
		var pot := MeshInstance3D.new()
		var pm := SphereMesh.new(); pm.radius = 0.065; pm.height = 0.13
		pot.mesh = pm; pot.position = Vector3(2.86 + float(p_i) * 0.25, 1.83, -4.80)
		var pc: Color = potion_cols[p_i]
		pot.material_override = Toon.pbr(pc, "", 0.18, 0.08, Vector2.ONE, pc * 0.55, 1.4)
		parent.add_child(pot)


func apply_vista_era(era_id: String) -> void:
	if not is_instance_valid(exterior_vista_root):
		return
	for ch in exterior_vista_root.get_children():
		ch.queue_free()
	exterior_pine_nodes.clear()
	exterior_twinkle_nodes.clear()
	exterior_lightning_meshes.clear()

	if era_id == "antika":
		exterior_vista_theme = "sun_mountains"
	elif era_id == "rim":
		exterior_vista_theme = "starry_night"
	elif era_id == "stredovek":
		exterior_vista_theme = "full_moon"
	else:
		exterior_vista_theme = "storm_rain"

	var ext := exterior_vista_root
	var sky_col := Color(0.04, 0.07, 0.16)
	var hor_col := Color(0.18, 0.25, 0.44)
	var far_base := Color(0.07, 0.11, 0.22)
	var far_snow := Color(0.76, 0.86, 0.98)
	var mid_base := Color(0.05, 0.08, 0.16)
	var mid_snow := Color(0.56, 0.70, 0.88)
	var win_col := Color(0.72, 0.84, 1.0)
	var rain_vis := (exterior_vista_theme == "storm_rain")

	if exterior_vista_theme == "sun_mountains":
		sky_col = Color(0.24, 0.54, 0.86); hor_col = Color(0.96, 0.72, 0.36)
		far_base = Color(0.24, 0.34, 0.48); far_snow = Color(1.0, 0.96, 0.88)
		mid_base = Color(0.16, 0.32, 0.24); mid_snow = Color(0.92, 0.86, 0.74)
		win_col = Color(1.0, 0.82, 0.46)
	elif exterior_vista_theme == "starry_night":
		sky_col = Color(0.02, 0.04, 0.14); hor_col = Color(0.09, 0.14, 0.32)
		far_base = Color(0.04, 0.07, 0.18); far_snow = Color(0.42, 0.56, 0.86)
		mid_base = Color(0.03, 0.05, 0.12); mid_snow = Color(0.32, 0.44, 0.72)
		win_col = Color(0.38, 0.58, 1.0)
	elif exterior_vista_theme == "storm_rain":
		sky_col = Color(0.04, 0.05, 0.10); hor_col = Color(0.14, 0.16, 0.26)
		far_base = Color(0.05, 0.07, 0.13); far_snow = Color(0.48, 0.58, 0.76)
		mid_base = Color(0.04, 0.05, 0.10); mid_snow = Color(0.34, 0.42, 0.58)
		win_col = Color(0.46, 0.70, 1.0)

	for drp in storm_rain_meshes:
		if is_instance_valid(drp):
			drp.visible = rain_vis
	for wl in storm_window_lights:
		if is_instance_valid(wl):
			wl.light_color = win_col

	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sky_mat.disable_fog = true; sky_mat.albedo_color = sky_col
	var sky := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(38.0, 18.0, 0.2)
	sky.mesh = sm; sky.position = Vector3(0.0, 4.5, -19.5); sky.material_override = sky_mat
	ext.add_child(sky)

	var hor_mat := StandardMaterial3D.new()
	hor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; hor_mat.disable_fog = true; hor_mat.albedo_color = hor_col
	var hor := MeshInstance3D.new(); var hm := BoxMesh.new(); hm.size = Vector3(36.0, 4.0, 0.2)
	hor.mesh = hm; hor.position = Vector3(0.0, 1.8, -18.8); hor.material_override = hor_mat
	ext.add_child(hor)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7711

	if exterior_vista_theme == "sun_mountains":
		var core_mat := StandardMaterial3D.new(); core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; core_mat.disable_fog = true; core_mat.albedo_color = Color(1.0, 0.96, 0.78)
		var core := MeshInstance3D.new(); var cm := SphereMesh.new(); cm.radius = 0.85; cm.height = 1.70
		core.mesh = cm; core.position = Vector3(5.35, 3.65, -16.9); core.material_override = core_mat; ext.add_child(core)
	elif exterior_vista_theme == "full_moon" or exterior_vista_theme == "starry_night":
		var full_mat := StandardMaterial3D.new(); full_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; full_mat.disable_fog = true; full_mat.albedo_color = Color(1.0, 0.97, 0.88)
		var full_m := MeshInstance3D.new(); var fmm := SphereMesh.new(); fmm.radius = 1.05 if exterior_vista_theme == "full_moon" else 0.68; fmm.height = fmm.radius * 2.0
		full_m.mesh = fmm; full_m.position = Vector3(5.35 if exterior_vista_theme == "full_moon" else -5.35, 3.65, -16.9); full_m.material_override = full_mat; ext.add_child(full_m)
		var star_mat := StandardMaterial3D.new(); star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; star_mat.disable_fog = true; star_mat.albedo_color = Color(0.95, 0.97, 1.0)
		for si in range(44):
			var st := MeshInstance3D.new(); var sbm := BoxMesh.new(); var sz := rng.randf_range(0.06, 0.13); sbm.size = Vector3(sz, sz, 0.02)
			st.mesh = sbm; st.material_override = star_mat; st.position = Vector3(rng.randf_range(-9.5, 9.5), rng.randf_range(2.6, 4.9), -16.8)
			st.set_meta("phase", float(si) * 0.8); ext.add_child(st); exterior_twinkle_nodes.append(st)
	else:
		var bolt_mat := StandardMaterial3D.new(); bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bolt_mat.disable_fog = true; bolt_mat.albedo_color = Color(0.75, 0.92, 1.0)
		for bx in [-5.35, 5.35]:
			var segs := [[Vector3(bx, 4.25, -15.6), Vector3(bx + 0.28, 3.45, -15.6)], [Vector3(bx + 0.28, 3.45, -15.6), Vector3(bx - 0.22, 2.75, -15.6)]]
			for s in segs:
				var seg_m := _spawn_bolt_segment_mesh(s[0], s[1], 0.09, bolt_mat)
				ext.add_child(seg_m); exterior_lightning_meshes.append(seg_m)

	var mtn_mat := StandardMaterial3D.new()
	mtn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mtn_mat.disable_fog = true; mtn_mat.vertex_color_use_as_albedo = true; mtn_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for fp in [
		{"pos": Vector3(-7.8, 0.7, -19.0), "r": 4.4, "h": 5.2, "snow": 0.45, "seed": 1101},
		{"pos": Vector3(-3.8, 0.7, -18.5), "r": 4.2, "h": 5.6, "snow": 0.42, "seed": 1102},
		{"pos": Vector3(0.0, 0.7, -19.2), "r": 4.8, "h": 6.0, "snow": 0.40, "seed": 1103},
		{"pos": Vector3(3.6, 0.7, -18.4), "r": 4.2, "h": 5.4, "snow": 0.44, "seed": 1104},
		{"pos": Vector3(7.6, 0.7, -18.8), "r": 4.4, "h": 5.0, "snow": 0.46, "seed": 1105},
	]:
		var m_mesh := MeshInstance3D.new()
		m_mesh.mesh = _build_exterior_mountain_mesh(float(fp["r"]), float(fp["h"]), float(fp["snow"]), int(fp["seed"]), far_base, far_snow)
		m_mesh.position = fp["pos"]; m_mesh.material_override = mtn_mat; ext.add_child(m_mesh)

	for mp2 in [
		{"pos": Vector3(-7.0, 0.7, -14.2), "r": 3.0, "h": 2.65, "snow": 0.56, "seed": 2201},
		{"pos": Vector3(-3.2, 0.7, -14.6), "r": 3.2, "h": 2.95, "snow": 0.54, "seed": 2202},
		{"pos": Vector3(0.6, 0.7, -14.2), "r": 3.3, "h": 3.05, "snow": 0.58, "seed": 2203},
		{"pos": Vector3(3.4, 0.7, -14.6), "r": 3.0, "h": 2.75, "snow": 0.54, "seed": 2204},
		{"pos": Vector3(7.2, 0.7, -14.2), "r": 3.0, "h": 2.60, "snow": 0.60, "seed": 2205},
	]:
		var mid_mtn := MeshInstance3D.new()
		mid_mtn.mesh = _build_exterior_mountain_mesh(float(mp2["r"]), float(mp2["h"]), float(mp2["snow"]), int(mp2["seed"]), mid_base, mid_snow)
		mid_mtn.position = mp2["pos"]; mid_mtn.material_override = mtn_mat; ext.add_child(mid_mtn)

	var pine_mat := StandardMaterial3D.new()
	pine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pine_mat.disable_fog = true
	pine_mat.albedo_color = Color(0.10, 0.26, 0.14) if exterior_vista_theme == "sun_mountains" else Color(0.06, 0.16, 0.14)
	for pi in range(14):
		var pine := Node3D.new()
		pine.position = Vector3(-7.2 + float(pi) * 1.12, 0.85, rng.randf_range(-12.6, -8.5))
		var cone := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = 0.04; cc.bottom_radius = 0.55; cc.height = rng.randf_range(1.6, 2.5); cc.radial_segments = 7
		cone.mesh = cc; cone.position.y = 1.0; cone.material_override = pine_mat; pine.add_child(cone)
		ext.add_child(pine); exterior_pine_nodes.append(pine)


func _spawn_bolt_segment_mesh(a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var seg := MeshInstance3D.new()
	var diff := b - a
	var diff_len := diff.length()
	var length := maxf(0.04, diff_len)
	var bm := BoxMesh.new(); bm.size = Vector3(thickness, length, thickness)
	seg.mesh = bm; seg.material_override = mat; seg.position = (a + b) * 0.5
	if diff_len >= 0.0005:
		var dir := diff / diff_len
		if absf(dir.dot(Vector3.UP)) <= 0.985:
			var up_vec := Vector3.FORWARD if absf(dir.dot(Vector3.RIGHT)) > 0.96 else Vector3.RIGHT
			seg.look_at_from_position((a + b) * 0.5, (a + b) * 0.5 + dir, up_vec)
			seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	return seg


func _build_exterior_mountain_mesh(radius: float, height: float, snow_line: float, seed_val: int, base_col: Color, snow_col: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_val
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14; var rings := 5; var grid: Array = []
	for r_i in range(rings + 1):
		var t_h := float(r_i) / float(rings)
		var ring_pts: Array = []
		for s_i in range(segs):
			var ang := (float(s_i) / float(segs)) * TAU
			var ridge := 1.0 + 0.24 * sin(ang * 3.0 + float(seed_val)) + 0.14 * cos(ang * 5.0 - float(seed_val) * 0.5)
			var cur_r := lerpf(radius, 0.08, pow(t_h, 0.85)) * ridge
			var jitter_y := rng.randf_range(-0.18, 0.18) if (r_i > 0 and r_i < rings) else 0.0
			var skew_x := t_h * rng.randf_range(-0.35, 0.35) if r_i == rings else 0.0
			ring_pts.append({"pos": Vector3(cos(ang) * cur_r + skew_x, t_h * height + jitter_y, sin(ang) * cur_r * 0.72), "th": t_h, "ang": ang})
		grid.append(ring_pts)
	for r_i in range(rings):
		var row0: Array = grid[r_i]; var row1: Array = grid[r_i + 1]
		for s_i in range(segs):
			var sn := (s_i + 1) % segs
			for tri in [[row0[s_i], row0[sn], row1[s_i]], [row0[sn], row1[sn], row1[s_i]]]:
				for v in tri:
					var vt := float(v["th"])
					var moon_shade := 0.5 + 0.5 * cos(float(v["ang"]) - 0.8)
					var snow_t := clampf((vt - snow_line) / maxf(0.12, 1.0 - snow_line), 0.0, 1.0)
					var rock := base_col.lerp(base_col.lightened(0.28), vt * 0.55 + moon_shade * 0.25)
					st.set_color(rock.lerp(snow_col.lerp(Color.WHITE, moon_shade * 0.30), smoothstep(0.0, 1.0, snow_t)))
					st.add_vertex(v["pos"])
	st.generate_normals()
	return st.commit()


func _add_wall_block(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material) -> void:
	var b := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz
	b.mesh = bm; b.position = pos; b.material_override = mat; parent.add_child(b)


func _spawn_tavern_chair(parent: Node3D, pos: Vector3, rot_y: float, wood_mat: Material, tall_scale: float) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation_degrees.y = rot_y; root.scale = Vector3(1.0, tall_scale, 1.0); parent.add_child(root)
	var chair_glb := _load_glb_model("res://assets/models/tavern_chair.glb", true)
	if chair_glb:
		var ch_brass := Toon.pbr(Color(0.78, 0.58, 0.22), "", 0.30, 0.88)
		var ch_leather := _make_triplanar_pbr_mat("res://assets/gloves/glove_leather.png", Color(0.24, 0.09, 0.08), 1.4, 0.72, 0.04)
		_apply_mat_by_mesh_name(chair_glb, {"chairfinial": ch_brass, "chairmedallion": ch_brass, "chaircushion": ch_leather, "chair": wood_mat})
		root.add_child(chair_glb)


func _spawn_tavern_barrel(parent: Node3D, pos: Vector3, s: float, wood_mat: Material, iron_mat: Material, tilt_z: float = 0.0) -> void:
	var root := Node3D.new(); root.position = pos; root.scale = Vector3.ONE * s; root.rotation_degrees.z = tilt_z; parent.add_child(root)
	var barrel_glb := _load_glb_model("res://assets/models/tavern_barrel.glb", true)
	if barrel_glb:
		_apply_mat_by_mesh_name(barrel_glb, {"barrelhoop": iron_mat, "hooprivet": iron_mat, "barrelstave": wood_mat, "barrellid": wood_mat})
		root.add_child(barrel_glb)


func _spawn_crate(parent: Node3D, pos: Vector3, s: float, wood_mat: Material) -> void:
	var c := MeshInstance3D.new(); var cb := BoxMesh.new(); cb.size = Vector3(s, s, s)
	c.mesh = cb; c.position = pos + Vector3(0, s * 0.5, 0); c.rotation_degrees.y = randf() * 35.0; c.material_override = wood_mat; parent.add_child(c)


func _spawn_wall_trophy(parent: Node3D, pos: Vector3, iron_mat: Material, wood_mat: Material) -> void:
	var t_root := Node3D.new(); t_root.position = pos; parent.add_child(t_root)
	var trophy_glb := _load_glb_model("res://assets/models/wall_trophy.glb", true)
	if trophy_glb:
		t_root.add_child(trophy_glb)
		return
	var shield := MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.34; sc.bottom_radius = 0.34; sc.height = 0.05; sc.radial_segments = 8
	shield.mesh = sc; shield.rotation_degrees.x = 90.0; shield.material_override = wood_mat; t_root.add_child(shield)
	var boss := MeshInstance3D.new(); var bm := SphereMesh.new(); bm.radius = 0.11; bm.height = 0.10
	boss.mesh = bm; boss.position = Vector3(0, 0, 0.03); boss.material_override = iron_mat; t_root.add_child(boss)


func _spawn_wall_banner(parent: Node3D, pos: Vector3, fabric_col: Color, trim_col: Color) -> void:
	var root := Node3D.new(); root.position = pos; parent.add_child(root)
	var banner_glb := _load_glb_model("res://assets/models/tavern_banner.glb", true)
	if banner_glb:
		var cloth_mat := Toon.pbr(fabric_col, "", 0.84, 0.04, Vector2.ONE, fabric_col * 0.06)
		cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var trim_mat := Toon.pbr(trim_col, "", 0.28, 0.84, Vector2.ONE, trim_col * 0.12)
		_apply_mat_by_mesh_name(banner_glb, {"bannercloth": cloth_mat, "bannertrim": trim_mat})
		root.add_child(banner_glb)


func _spawn_tavern_hearth(parent: Node3D, pos: Vector3, stone_mat: Material, wood_mat: Material) -> void:
	var hearth := Node3D.new(); hearth.position = pos; parent.add_child(hearth)
	var hearth_glb := _load_glb_model("res://assets/models/tavern_hearth.glb", true)
	if hearth_glb:
		var h_iron := Toon.pbr(Color(0.14, 0.14, 0.16), "", 0.46, 0.84)
		var h_ember := Toon.pbr(Color(1.0, 0.34, 0.05), "", 0.25, 0.0, Vector2.ONE, Color(1.0, 0.26, 0.02), 2.4)
		var h_soot := Toon.pbr(Color(0.05, 0.045, 0.05), "", 0.96, 0.0)
		_apply_mat_by_mesh_name(hearth_glb, {
			"hearthembercore": h_ember, "hearthback": h_soot, "andiron": h_iron,
			"hearthmantel": wood_mat, "firelog": wood_mat, "hearthslab": stone_mat,
			"hearthjamb": stone_mat, "hearthcorbel": stone_mat, "hearthhood": stone_mat, "archstone": stone_mat,
		})
		hearth.add_child(hearth_glb)
	hearth_fire_light = OmniLight3D.new()
	hearth_fire_light.position = Vector3(0.65, 0.55, 0.0); hearth_fire_light.light_color = Color(1.0, 0.56, 0.18)
	hearth_fire_light.light_energy = 2.8; hearth_fire_light.omni_range = 6.2; hearth.add_child(hearth_fire_light)


func _spawn_storm_window(parent: Node3D, pos: Vector3, wood_mat: Material, iron_mat: Material) -> void:
	var root := Node3D.new(); root.position = pos; parent.add_child(root)
	var glass := MeshInstance3D.new(); var gp := BoxMesh.new(); gp.size = Vector3(1.18, 1.62, 0.03)
	glass.mesh = gp
	var gmat := StandardMaterial3D.new(); gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gmat.albedo_color = Color(0.32, 0.56, 0.85, 0.14); gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = gmat; root.add_child(glass)
	for bar_x in [-0.60, 0.0, 0.60]:
		var bar := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.08, 1.72, 0.14)
		bar.mesh = bb; bar.position = Vector3(bar_x, 0, 0.02); bar.material_override = iron_mat if bar_x == 0.0 else wood_mat; root.add_child(bar)
	for bar_y in [-0.82, 0.0, 0.82]:
		var hbar := MeshInstance3D.new(); var hbb := BoxMesh.new(); hbb.size = Vector3(1.28, 0.08, 0.14)
		hbar.mesh = hbb; hbar.position = Vector3(0, bar_y, 0.02); hbar.material_override = iron_mat if bar_y == 0.0 else wood_mat; root.add_child(hbar)
	var drop_mat := StandardMaterial3D.new(); drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; drop_mat.disable_fog = true; drop_mat.albedo_color = Color(0.75, 0.90, 1.0, 0.85); drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for ri in range(10):
		var drop := MeshInstance3D.new(); var dm := BoxMesh.new(); dm.size = Vector3(0.015, 0.24, 0.01)
		drop.mesh = dm; drop.material_override = drop_mat
		var bx := -0.48 + float(ri) * 0.105
		drop.position = Vector3(bx, -0.4 + fmod(float(ri) * 0.37, 0.9), -0.06); drop.rotation_degrees.z = -16.0
		drop.set_meta("base_x", bx); drop.set_meta("phase", float(ri) * 0.6)
		root.add_child(drop); storm_rain_meshes.append(drop)
	var moon_light := OmniLight3D.new(); moon_light.position = Vector3(0, 0, 0.55); moon_light.light_color = Color(0.42, 0.68, 1.0); moon_light.light_energy = 1.35; moon_light.omni_range = 3.8
	root.add_child(moon_light); storm_window_lights.append(moon_light)


func _spawn_wall_lantern(parent: Node3D, pos: Vector3, iron_mat: Material, rot_y: float = 0.0) -> void:
	var root := Node3D.new(); root.position = pos; root.rotation_degrees.y = rot_y; parent.add_child(root); wall_lantern_roots.append(root)
	var lan_glb := _load_glb_model("res://assets/models/tavern_lantern.glb", true)
	if lan_glb:
		root.add_child(lan_glb)
	else:
		var body := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(0.14, 0.24, 0.14)
		body.mesh = bb; body.material_override = Toon.mat(Color(1.0, 0.72, 0.30), "", 0.01, Vector2.ONE, Color(0.95, 0.55, 0.18)); root.add_child(body)
		var cap := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = 0.02; cc.bottom_radius = 0.14; cc.height = 0.12
		cap.mesh = cc; cap.position = Vector3(0, 0.17, 0); cap.material_override = iron_mat; root.add_child(cap)
	var l_light := OmniLight3D.new(); l_light.position = Vector3(0, 0, 0.28); l_light.light_color = Color(1.0, 0.68, 0.30); l_light.light_energy = 1.8; l_light.omni_range = 3.6
	root.add_child(l_light); lantern_lights.append(l_light)


func _spawn_candle(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new(); root.position = pos; parent.add_child(root)
	var cand_glb := _load_glb_model("res://assets/models/candelabra.glb", true)
	if cand_glb:
		cand_glb.name = "CandelabraGLB"; root.add_child(cand_glb)
	for ci in range(2):
		var cx := -0.074 if ci == 0 else 0.074
		var top_y := 0.238 if ci == 0 else 0.250
		var flame := MeshInstance3D.new(); var fs := SphereMesh.new(); fs.radius = 0.012; fs.height = 0.036
		flame.mesh = fs; flame.position = Vector3(cx, top_y, 0.0); flame.material_override = Toon.mat(Color(1.0, 0.78, 0.30), "", 0.0, Vector2.ONE, Color(1.0, 0.62, 0.18)); root.add_child(flame)
	var glow := OmniLight3D.new(); glow.position.y = 0.27; glow.light_color = Color(1.0, 0.68, 0.34); glow.light_energy = 1.15; glow.omni_range = 1.4; root.add_child(glow)


func _spawn_mug(parent: Node3D, pos: Vector3) -> void:
	tavern_mug_root = Node3D.new(); tavern_mug_root.position = pos
	tavern_mug_root.set_meta("base_pos", pos); tavern_mug_root.set_meta("base_scale", Vector3.ONE)
	parent.add_child(tavern_mug_root)
	RelicMesh.build_tavern_mug_meshes(tavern_mug_root)
	var a := Area3D.new(); a.set_meta("mp_tavern_prop", "mug")
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(0.18, 0.18, 0.18); cs.shape = bx; cs.position = Vector3(0.0, 0.07, 0.0)
	a.add_child(cs); tavern_mug_root.add_child(a)


func _spawn_table_dice_and_coins(parent: Node3D) -> void:
	tavern_coins_root = Node3D.new(); tavern_coins_root.position = Vector3(-0.74, 0.816, -0.28)
	tavern_coins_root.set_meta("base_pos", tavern_coins_root.position); tavern_coins_root.set_meta("base_scale", Vector3.ONE)
	parent.add_child(tavern_coins_root)
	RelicMesh.build_coins_pouch_meshes(tavern_coins_root)
	var ca := Area3D.new(); ca.set_meta("mp_tavern_prop", "coins")
	var cc := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(0.28, 0.16, 0.20); cc.shape = cb; cc.position = Vector3(0.02, 0.05, 0.0)
	ca.add_child(cc); tavern_coins_root.add_child(ca)

	tavern_dice_root = Node3D.new(); tavern_dice_root.position = Vector3(-0.54, 0.832, -0.24)
	tavern_dice_root.set_meta("base_pos", tavern_dice_root.position); tavern_dice_root.set_meta("base_scale", Vector3.ONE)
	parent.add_child(tavern_dice_root)
	RelicMesh.build_bone_dice_meshes(tavern_dice_root)
	var da := Area3D.new(); da.set_meta("mp_tavern_prop", "dice")
	var dc := CollisionShape3D.new(); var db := BoxShape3D.new(); db.size = Vector3(0.14, 0.10, 0.12); dc.shape = db
	da.add_child(dc); tavern_dice_root.add_child(da)


func _spawn_tavern_shop_bell(parent: Node3D, pos: Vector3) -> void:
	tavern_bell_root = Node3D.new(); tavern_bell_root.position = pos
	tavern_bell_root.set_meta("base_pos", pos); tavern_bell_root.set_meta("base_scale", Vector3.ONE)
	parent.add_child(tavern_bell_root)
	RelicMesh.build_shop_bell_meshes(tavern_bell_root)
	var ba := Area3D.new(); ba.set_meta("mp_tavern_prop", "bell")
	var bc := CollisionShape3D.new(); var bb := BoxShape3D.new(); bb.size = Vector3(0.16, 0.14, 0.16); bc.shape = bb; bc.position = Vector3(0.0, 0.05, 0.0)
	ba.add_child(bc); tavern_bell_root.add_child(ba)


func _spawn_chandelier_volumetric_cone(parent: Node3D) -> void:
	chandelier_cone_mesh = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.14; cone.bottom_radius = 1.62; cone.height = 2.10; cone.radial_segments = 32; cone.rings = 1; cone.cap_top = false; cone.cap_bottom = false
	chandelier_cone_mesh.mesh = cone
	chandelier_cone_mesh.position = Vector3(0.0, 1.72, 0.02)
	chandelier_cone_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cone_shader := Shader.new()
	cone_shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
varying float v_y;
void vertex() {
	v_y = clamp((VERTEX.y + 1.05) / 2.10, 0.0, 1.0);
}
void fragment() {
	float fres = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.35);
	float vert_fade = smoothstep(0.0, 0.28, v_y) * smoothstep(1.0, 0.55, v_y);
	float dust_wave = 0.85 + 0.15 * sin(TIME * 1.4 + v_y * 9.0);
	ALBEDO = vec3(1.0, 0.76, 0.36);
	ALPHA = fres * vert_fade * 0.085 * dust_wave;
}
"""
	var smat := ShaderMaterial.new(); smat.shader = cone_shader
	chandelier_cone_mesh.material_override = smat
	parent.add_child(chandelier_cone_mesh)
