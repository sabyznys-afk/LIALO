class_name RelicLivingFx
extends Node3D

## Signature Living Hand-Drawn 3D Micro-Animations for the 9 Reworked Tabletop Relics.
## Mounted under SpinPivot alongside each sculpted .glb relic mesh so every artifact breathes
## with inked woodcut motion (falling sand, incense smoke, ember sparks, floating runes,
## swinging toll bell, coin sparkles, wine droplets, flint sparks, phoenix feathers).

const HANDDRAWN_RELIC_SHADER := preload("res://shaders/handdrawn_relic_3d.gdshader")
const HANDDRAWN_OUTLINE_SHADER := preload("res://shaders/handdrawn_outline_3d.gdshader")

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


func _build_relic_particles() -> void:
	var sph := SphereMesh.new()
	sph.radius = 0.0024
	sph.height = 0.0048
	sph.radial_segments = 10
	sph.rings = 6

	var prism := PrismMesh.new()
	prism.size = Vector3(0.0042, 0.0058, 0.0022)

	match _rel_id:
		"TRELIC_HOLLOW_MASK":
			var luck_mat := _make_ink_fx_mat(Color(1.0, 0.88, 0.36), Color(0.45, 0.28, 0.08), Color(0.55, 0.38, 0.08))
			_spawn_mote_pool(9, prism, luck_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 9.0)
				return Vector3(cos(a) * 0.022, _rng.randf_range(0.022, 0.062), sin(a) * 0.022)
			, 0.016, 0.028, 1.1, 1.7, 0.0032, 0.9)

		"TRELIC_STAR_BOW":
			var rune_mat := _make_ink_fx_mat(Color(0.42, 0.92, 1.0), Color(0.10, 0.32, 0.56), Color(0.22, 0.68, 0.96))
			_spawn_mote_pool(10, prism, rune_mat, func(i: int) -> Vector3:
				var a := float(i) * 2.1
				var rad := _rng.randf_range(0.010, 0.028)
				return Vector3(cos(a) * rad, _rng.randf_range(0.025, 0.070), sin(a) * rad)
			, 0.020, 0.036, 1.3, 2.0, 0.0025, 0.85)

		"TRELIC_BLOOD_SEAL":
			var wine_mat := _make_ink_fx_mat(Color(0.88, 0.14, 0.20), Color(0.30, 0.03, 0.05), Color(0.32, 0.04, 0.06))
			_spawn_mote_pool(8, sph, wine_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 8.0)
				var rad := _rng.randf_range(0.005, 0.022)
				return Vector3(cos(a) * rad, 0.091, sin(a) * rad)
			, 0.012, 0.026, 1.2, 1.9, 0.0018, 0.95)

		"TRELIC_IRON_CHAIN":
			var spark_mat := _make_ink_fx_mat(Color(1.0, 0.72, 0.24), Color(0.48, 0.18, 0.04), Color(0.75, 0.34, 0.05))
			_spawn_mote_pool(9, prism, spark_mat, func(_i: int) -> Vector3:
				return Vector3(_rng.randf_range(-0.010, 0.010), _rng.randf_range(0.028, 0.044), _rng.randf_range(-0.006, 0.006))
			, 0.018, 0.038, 0.55, 0.95, 0.0065, 0.75)

		"TRELIC_ASH_GLASS":
			var sand_mat := _make_ink_fx_mat(Color(1.0, 0.84, 0.32), Color(0.46, 0.30, 0.08), Color(0.38, 0.26, 0.06))
			_spawn_mote_pool(10, sph, sand_mat, func(i: int) -> Vector3:
				if i < 6:
					return Vector3(_rng.randf_range(-0.0014, 0.0014), 0.050, _rng.randf_range(-0.0014, 0.0014))
				var a := float(i) * 1.9
				return Vector3(cos(a) * 0.011, 0.014, sin(a) * 0.011)
			, -0.022, -0.018, 0.75, 1.15, 0.0010, 0.58)

		"TRELIC_GOLD_SCALES":
			var glint_mat := _make_ink_fx_mat(Color(1.0, 0.90, 0.34), Color(0.46, 0.30, 0.06), Color(0.56, 0.38, 0.08))
			_spawn_mote_pool(9, prism, glint_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 9.0)
				return Vector3(0.014 + cos(a) * 0.018, _rng.randf_range(0.008, 0.030), sin(a) * 0.018)
			, 0.014, 0.026, 1.0, 1.6, 0.0020, 0.80)

		"TRELIC_SOUL_BELL":
			var wisp_mat := _make_ink_fx_mat(Color(0.44, 0.90, 1.0), Color(0.12, 0.34, 0.44), Color(0.24, 0.62, 0.76))
			_spawn_mote_pool(9, sph, wisp_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 9.0)
				return Vector3(0.012 + cos(a) * 0.018, 0.032, sin(a) * 0.018)
			, 0.022, 0.042, 1.4, 2.2, 0.0042, 0.92)

		"TRELIC_CENSER":
			var smoke_mat := _make_ink_fx_mat(Color(0.84, 0.80, 0.76), Color(0.30, 0.26, 0.24), Color(0.12, 0.10, 0.10))
			var coal_mat := _make_ink_fx_mat(Color(1.0, 0.56, 0.16), Color(0.42, 0.12, 0.04), Color(0.75, 0.26, 0.04))
			for i in range(10):
				var mi := MeshInstance3D.new()
				mi.name = "IncenseMote_%d" % i
				var is_spark := (i % 3 == 0)
				mi.mesh = prism if is_spark else sph
				mi.material_override = coal_mat if is_spark else smoke_mat
				add_child(mi)
				var a := float(i) * 1.7
				_motes.append({
					"node": mi,
					"age": float(i) / 10.0,
					"life": _rng.randf_range(1.3, 2.1),
					"base": Vector3(0.014 + cos(a) * 0.010, 0.064, sin(a) * 0.010),
					"rise": _rng.randf_range(0.026, 0.048),
					"wob": 0.0048,
					"freq": _rng.randf_range(2.6, 4.4),
					"ph": _rng.randf_range(0.0, TAU),
					"sc": 0.72 if is_spark else 1.25,
					"spin": _rng.randf_range(-1.8, 1.8),
				})

		"TRELIC_PHOENIX_BOX":
			var ember_mat := _make_ink_fx_mat(Color(1.0, 0.54, 0.16), Color(0.48, 0.10, 0.04), Color(0.82, 0.28, 0.04))
			_spawn_mote_pool(11, prism, ember_mat, func(i: int) -> Vector3:
				var a := float(i) * (TAU / 11.0)
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
