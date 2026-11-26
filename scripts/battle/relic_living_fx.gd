class_name RelicLivingFx
extends Node3D

## Signature Living Hand-Drawn 3D Micro-Animations for the 9 Reworked Tabletop Relics.
## Mounted under SpinPivot alongside each sculpted .glb relic mesh so every artifact breathes
## with inked woodcut motion (falling sand, incense smoke, ember sparks, floating runes,
## swinging toll bell, coin sparkles, wine droplets, flint sparks, phoenix feathers).

const HANDDRAWN_RELIC_SHADER := preload("res://shaders/handdrawn_relic_3d.gdshader")
const HANDDRAWN_OUTLINE_SHADER := preload("res://shaders/handdrawn_outline_3d.gdshader")
const INK_PARTICLE_SHADER := preload("res://shaders/relic_ink_particle.gdshader")
const RIBBON_WISP_SHADER := preload("res://shaders/relic_ribbon_wisp.gdshader")
const INK_ATLAS_PATH := "res://assets/vfx/relic_ink_particles_atlas.png"

var _rel_id: String = ""
var _accent: Color = Color(0.96, 0.78, 0.34)
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()

var _motes: Array[Dictionary] = []
var _node_refs: Dictionary = {}
var _base_pos: Dictionary = {}
var _base_rot: Dictionary = {}
var _base_scale: Dictionary = {}


func setup_for_relic(rel_id: String, glb_root: Node3D, accent_col: Color) -> void:
	_rel_id = rel_id
	_accent = accent_col
	_rng.seed = hash(rel_id) ^ 51827
	_collect_named_parts(glb_root)
	_build_relic_particles()
	_update_frame(0.0)


func _collect_named_parts(root: Node3D) -> void:
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back() as Node
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var nm: String = str(mi.name)
			_node_refs[nm] = mi
			_base_pos[nm] = mi.position
			_base_rot[nm] = mi.rotation
			_base_scale[nm] = mi.scale
		for ch in cur.get_children():
			stack.append(ch)


func _make_ink_fx_mat(albedo: Color, shadow: Color, emit: Color, outline_thick: float = 0.00045) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HANDDRAWN_RELIC_SHADER
	m.set_shader_parameter("use_texture", false)
	m.set_shader_parameter("albedo_tint", albedo)
	m.set_shader_parameter("shadow_tint", shadow)
	m.set_shader_parameter("highlight_tint", Color(1.0, 0.96, 0.88))
	m.set_shader_parameter("hatch_strength", 0.28)
	m.set_shader_parameter("hatch_density", 28.0)
	m.set_shader_parameter("specular_strength", 0.82)
	m.set_shader_parameter("specular_size", 28.0)
	m.set_shader_parameter("rim_strength", 0.65)
	m.set_shader_parameter("ao_ink_strength", 0.0)
	m.set_shader_parameter("emission_color", emit)

	var out := ShaderMaterial.new()
	out.shader = HANDDRAWN_OUTLINE_SHADER
	out.set_shader_parameter("thickness", outline_thick)
	out.set_shader_parameter("dist_scale", outline_thick * 2.0)
	out.set_shader_parameter("outline_color", Color(0.04, 0.025, 0.018, 1.0))
	m.next_pass = out
	return m


func _spawn_mote_pool(
	count: int,
	mesh: Mesh,
	mat: Material,
	spawn_fn: Callable,
	rise_min: float,
	rise_max: float,
	life_min: float,
	life_max: float,
	wob_amp: float,
	scale_mul: float = 1.0
) -> void:
	for i in range(count):
		var mi := MeshInstance3D.new()
		mi.name = "LivingMote_%d" % _motes.size()
		mi.mesh = mesh
		mi.material_override = mat
		add_child(mi)
		var origin: Vector3 = spawn_fn.call(i)
		_motes.append({
			"node": mi,
			"age": float(i) / float(maxi(1, count)),
			"life": _rng.randf_range(life_min, life_max),
			"base": origin,
			"rise": _rng.randf_range(rise_min, rise_max),
			"wob": wob_amp,
			"freq": _rng.randf_range(2.8, 5.6),
			"ph": _rng.randf_range(0.0, TAU),
			"sc": scale_mul * _rng.randf_range(0.75, 1.25),
			"spin": _rng.randf_range(-2.2, 2.2),
		})


func _make_ink_atlas_mat(cell_idx: int, tint: Color, emission_boost: float = 0.7) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = INK_PARTICLE_SHADER
	if ResourceLoader.exists(INK_ATLAS_PATH):
		m.set_shader_parameter("atlas_tex", load(INK_ATLAS_PATH) as Texture2D)
	m.set_shader_parameter("cell_idx", cell_idx)
	m.set_shader_parameter("atlas_cols", 4)
	m.set_shader_parameter("tint_color", tint)
	m.set_shader_parameter("ink_color", Color(0.05, 0.03, 0.02, 1.0))
	m.set_shader_parameter("emission_boost", emission_boost)
	m.set_shader_parameter("fade_alpha", 0.94)
	return m


func _make_ribbon_wisp_mat(cell_idx: int, wisp_col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = RIBBON_WISP_SHADER
	if ResourceLoader.exists(INK_ATLAS_PATH):
		m.set_shader_parameter("atlas_tex", load(INK_ATLAS_PATH) as Texture2D)
	m.set_shader_parameter("cell_idx", cell_idx)
	m.set_shader_parameter("atlas_cols", 4)
	m.set_shader_parameter("wisp_color", wisp_col)
	m.set_shader_parameter("ink_color", Color(0.05, 0.03, 0.03, 1.0))
	m.set_shader_parameter("wave_speed", 2.6)
	m.set_shader_parameter("wave_amp", 0.0045)
	m.set_shader_parameter("fade_alpha", 0.88)
	return m


func _build_relic_particles() -> void:
	# Zero primitive SphereMesh/PrismMesh particles — use hand-inked quad sprites & 3D wisp ribbons (v0.197)
	var quad_sm := QuadMesh.new()
	quad_sm.size = Vector2(0.0085, 0.0085)
	var quad_md := QuadMesh.new()
	quad_md.size = Vector2(0.0125, 0.0125)
	var ribbon_q := QuadMesh.new()
	ribbon_q.size = Vector2(0.010, 0.032)
	ribbon_q.subdivide_depth = 6

	match _rel_id:
		"TRELIC_HOLLOW_MASK":
			var luck_mat := _make_ink_atlas_mat(7, Color(1.0, 0.88, 0.36, 1.0), 0.95)
			_spawn_mote_pool(9, quad_sm, luck_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 9.0)
				return Vector3(cos(a) * 0.022, _rng.randf_range(0.022, 0.062), sin(a) * 0.022)
			, 0.016, 0.028, 1.1, 1.7, 0.0032, 0.9)

		"TRELIC_STAR_BOW":
			var rune_mat := _make_ink_atlas_mat(2, Color(0.46, 0.94, 1.0, 1.0), 1.15)
			var spark_mat := _make_ink_atlas_mat(7, Color(0.72, 0.96, 1.0, 1.0), 1.35)
			_spawn_mote_pool(7, quad_md, rune_mat, func(i: int) -> Vector3:
				var a := float(i) * 2.1
				var rad := _rng.randf_range(0.012, 0.030)
				return Vector3(cos(a) * rad, _rng.randf_range(0.025, 0.070), sin(a) * rad)
			, 0.020, 0.036, 1.3, 2.0, 0.0025, 0.92)
			_spawn_mote_pool(5, quad_sm, spark_mat, func(i: int) -> Vector3:
				var a := float(i) * 1.4
				return Vector3(cos(a) * 0.024, _rng.randf_range(0.032, 0.068), sin(a) * 0.024)
			, 0.014, 0.026, 0.65, 1.1, 0.0045, 0.80)

		"TRELIC_BLOOD_SEAL":
			var bubble_mat := _make_ink_atlas_mat(1, Color(0.95, 0.18, 0.24, 1.0), 0.75)
			var drop_mat := _make_ink_atlas_mat(4, Color(0.88, 0.10, 0.16, 1.0), 0.55)
			var vapor_mat := _make_ribbon_wisp_mat(0, Color(0.86, 0.16, 0.24, 0.78))
			_spawn_mote_pool(6, quad_sm, bubble_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 6.0)
				var rad := _rng.randf_range(0.005, 0.022)
				return Vector3(cos(a) * rad, 0.092, sin(a) * rad)
			, 0.008, 0.016, 1.1, 1.7, 0.0014, 0.85)
			_spawn_mote_pool(3, ribbon_q, vapor_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 3.0)
				return Vector3(cos(a) * 0.012, 0.098, sin(a) * 0.012)
			, 0.018, 0.028, 1.6, 2.3, 0.0022, 0.88)
			_spawn_mote_pool(3, quad_sm, drop_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 3.0) + 0.4
				return Vector3(cos(a) * 0.033, 0.084, sin(a) * 0.033)
			, -0.026, -0.018, 0.9, 1.4, 0.0008, 0.75)

		"TRELIC_IRON_CHAIN":
			var spark_mat := _make_ink_atlas_mat(7, Color(1.0, 0.74, 0.26, 1.0), 1.25)
			_spawn_mote_pool(9, quad_sm, spark_mat, func(_i: int) -> Vector3:
				return Vector3(_rng.randf_range(-0.010, 0.010), _rng.randf_range(0.028, 0.044), _rng.randf_range(-0.006, 0.006))
			, 0.018, 0.038, 0.55, 0.95, 0.0065, 0.85)

		"TRELIC_ASH_GLASS":
			var sand_mat := _make_ink_atlas_mat(5, Color(1.0, 0.86, 0.36, 1.0), 0.75)
			var rune_mat := _make_ink_atlas_mat(2, Color(0.98, 0.80, 0.32, 1.0), 1.05)
			_spawn_mote_pool(8, quad_sm, sand_mat, func(i: int) -> Vector3:
				if i < 5:
					return Vector3(_rng.randf_range(-0.0014, 0.0014), 0.050, _rng.randf_range(-0.0014, 0.0014))
				var a := float(i) * 1.9
				return Vector3(cos(a) * 0.010, 0.014, sin(a) * 0.010)
			, -0.022, -0.018, 0.75, 1.15, 0.0010, 0.72)
			_spawn_mote_pool(2, quad_md, rune_mat, func(i: int) -> Vector3:
				return Vector3(-0.018 if i == 0 else 0.018, 0.049, 0.018)
			, 0.004, 0.008, 1.8, 2.4, 0.0012, 0.70)

		"TRELIC_GOLD_SCALES":
			var glint_mat := _make_ink_atlas_mat(7, Color(1.0, 0.90, 0.36, 1.0), 1.10)
			_spawn_mote_pool(9, quad_sm, glint_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 9.0)
				return Vector3(0.014 + cos(a) * 0.018, _rng.randf_range(0.008, 0.030), sin(a) * 0.018)
			, 0.014, 0.026, 1.0, 1.6, 0.0020, 0.85)

		"TRELIC_SOUL_BELL":
			var wisp_mat := _make_ribbon_wisp_mat(0, Color(0.46, 0.92, 1.0, 0.86))
			var ripple_mat := _make_ink_atlas_mat(6, Color(0.48, 0.92, 1.0, 1.0), 1.05)
			var dust_mat := _make_ink_atlas_mat(5, Color(0.76, 0.92, 0.96, 1.0), 0.65)
			_spawn_mote_pool(4, ribbon_q, wisp_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 4.0)
				return Vector3(0.012 + cos(a) * 0.012, 0.026, sin(a) * 0.012)
			, 0.026, 0.044, 1.5, 2.2, 0.0038, 0.95)
			_spawn_mote_pool(3, quad_md, ripple_mat, func(_i: int) -> Vector3:
				return Vector3(0.012, 0.034, 0.016)
			, 0.012, 0.022, 1.3, 1.9, 0.0020, 1.15)
			_spawn_mote_pool(4, quad_sm, dust_mat, func(i: int) -> Vector3:
				var a := float(i) * 1.6
				return Vector3(0.012 + cos(a) * 0.018, 0.020, sin(a) * 0.018)
			, 0.016, 0.028, 1.4, 2.0, 0.0028, 0.72)

		"TRELIC_CENSER":
			var smoke_mat := _make_ribbon_wisp_mat(0, Color(0.84, 0.80, 0.76, 0.82))
			var coal_mat := _make_ink_atlas_mat(3, Color(1.0, 0.56, 0.16, 1.0), 1.25)
			_spawn_mote_pool(5, ribbon_q, smoke_mat, func(i: int) -> Vector3:
				var a := float(i) * 1.4
				return Vector3(0.014 + cos(a) * 0.008, 0.064, sin(a) * 0.008)
			, 0.026, 0.046, 1.5, 2.2, 0.0040, 1.05)
			_spawn_mote_pool(4, quad_sm, coal_mat, func(i: int) -> Vector3:
				var a := float(i) * 1.7
				return Vector3(0.014 + cos(a) * 0.010, 0.062, sin(a) * 0.010)
			, 0.020, 0.038, 0.9, 1.5, 0.0045, 0.78)

		"TRELIC_PHOENIX_BOX":
			var ember_mat := _make_ink_atlas_mat(3, Color(1.0, 0.54, 0.16, 1.0), 1.25)
			_spawn_mote_pool(10, quad_md, ember_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 10.0)
				return Vector3(cos(a) * 0.016, _rng.randf_range(0.028, 0.056), sin(a) * 0.012)
			, 0.026, 0.050, 1.1, 1.8, 0.0052, 0.95)


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := minf(delta, 0.05)
	_time += dt
	_update_frame(dt)


func _update_frame(dt: float) -> void:
	# Relic-specific structural animations (swaying bell, orbiting rune shards, wine/plume pulse)
	match _rel_id:
		"TRELIC_STAR_BOW":
			for si in range(3):
				var nm := "RuneShard_%d" % si
				var sh: Node3D = _node_refs.get(nm, null) as Node3D
				if is_instance_valid(sh):
					var bp: Vector3 = _base_pos.get(nm, Vector3.ZERO)
					sh.position = bp + Vector3(0.0, sin(_time * 2.8 + float(si) * 2.1) * 0.0045, 0.0)
					sh.rotation.y = (_base_rot.get(nm, Vector3.ZERO) as Vector3).y + _time * 0.9 * (1.0 if si % 2 == 0 else -1.0)
		"TRELIC_BLOOD_SEAL":
			var wine: Node3D = _node_refs.get("WineDome", null) as Node3D
			if is_instance_valid(wine):
				var bs: Vector3 = _base_scale.get("WineDome", Vector3.ONE)
				var s_w := 1.0 + sin(_time * 3.1) * 0.022
				wine.scale = Vector3(bs.x * s_w, bs.y * (1.0 - sin(_time * 3.1) * 0.04), bs.z * s_w)
		"TRELIC_SOUL_BELL":
			var sway := sin(_time * 2.1) * 0.065
			var bell: Node3D = _node_refs.get("BronzeBell", null) as Node3D
			var clap: Node3D = _node_refs.get("SoulClapper", null) as Node3D
			if is_instance_valid(bell):
				bell.rotation.z = sway
			if is_instance_valid(clap):
				clap.rotation.z = sway * 1.45
		"TRELIC_CENSER":
			var c_sway := sin(_time * 1.8) * 0.055
			for p_nm in ["BrassCenser", "EmberCoals", "CenserChains"]:
				var nd: Node3D = _node_refs.get(p_nm, null) as Node3D
				if is_instance_valid(nd):
					nd.rotation.z = c_sway
		"TRELIC_PHOENIX_BOX":
			var plume: Node3D = _node_refs.get("PhoenixPlume", null) as Node3D
			if is_instance_valid(plume):
				var bsp: Vector3 = _base_scale.get("PhoenixPlume", Vector3.ONE)
				var pulse := 1.0 + sin(_time * 4.4) * 0.04
				plume.scale = Vector3(bsp.x, bsp.y * pulse, bsp.z)

	for bi in range(_motes.size()):
		var b: Dictionary = _motes[bi]
		var mi: MeshInstance3D = b.get("node", null) as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		var life := maxf(0.2, float(b["life"]))
		var age := fmod(float(b["age"]) + dt / life, 1.0)
		b["age"] = age

		var bp: Vector3 = b["base"]
		var rise := float(b["rise"])
		var wob := float(b["wob"])
		var freq := float(b["freq"])
		var ph := float(b["ph"])
		var sx := sin(age * freq * TAU + ph) * wob
		var sz := cos(age * freq * TAU * 0.8 + ph) * wob
		var lift := age * rise
		mi.position = bp + Vector3(sx, lift, sz)
		mi.rotation.y += dt * float(b["spin"])

		var fade := 1.0
		if age < 0.18:
			fade = age / 0.18
		elif age > 0.78:
			fade = (1.0 - age) / 0.22
		var sc_f := clampf(fade, 0.04, 1.0) * float(b["sc"])
		mi.scale = Vector3(sc_f, sc_f, sc_f)
