class_name TankardBubblesFx
extends Node3D

## Living Hand-Drawn 3D Ale Bubbling & Simmering Foam FX for TRELIC_WAR_HORN.
## Spawns rising/popping ink-outlined spheres above the sculpted ale foam crown
## plus micro simmering foam bubbles along the upper rim, paired with a gentle fizzy pulse.

const HANDDRAWN_RELIC_SHADER := preload("res://shaders/handdrawn_relic_3d.gdshader")
const HANDDRAWN_OUTLINE_SHADER := preload("res://shaders/handdrawn_outline_3d.gdshader")

var _bubbles: Array[Dictionary] = []
var _foam_mesh: MeshInstance3D = null
var _foam_base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 94821
	if _bubbles.is_empty():
		_spawn_bubbles()


func setup_for_tankard(tankard_root: Node3D) -> void:
	if tankard_root != null:
		var found := tankard_root.find_child("*AleFoam*", true, false)
		if found is MeshInstance3D:
			_foam_mesh = found as MeshInstance3D
			_foam_base_scale = _foam_mesh.scale
	if _bubbles.is_empty():
		_spawn_bubbles()


func _make_bubble_mat(is_amber: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HANDDRAWN_RELIC_SHADER
	m.set_shader_parameter("use_texture", false)
	m.set_shader_parameter("albedo_tint", Color(0.98, 0.72, 0.24) if is_amber else Color(1.0, 0.96, 0.84))
	m.set_shader_parameter("shadow_tint", Color(0.42, 0.24, 0.08) if is_amber else Color(0.44, 0.34, 0.22))
	m.set_shader_parameter("highlight_tint", Color(1.0, 0.96, 0.86))
	m.set_shader_parameter("hatch_strength", 0.25)
	m.set_shader_parameter("hatch_density", 28.0)
	m.set_shader_parameter("specular_strength", 0.85)
	m.set_shader_parameter("specular_size", 32.0)
	m.set_shader_parameter("rim_strength", 0.65)
	m.set_shader_parameter("ao_ink_strength", 0.0)
	m.set_shader_parameter("emission_color", Color(0.22, 0.14, 0.04) if is_amber else Color(0.18, 0.15, 0.08))

	var out := ShaderMaterial.new()
	out.shader = HANDDRAWN_OUTLINE_SHADER
	out.set_shader_parameter("thickness", 0.00055)
	out.set_shader_parameter("dist_scale", 0.0012)
	out.set_shader_parameter("outline_color", Color(0.04, 0.025, 0.018, 1.0))
	m.next_pass = out
	return m


func _spawn_bubbles() -> void:
	var cream_mat := _make_bubble_mat(false)
	var amber_mat := _make_bubble_mat(true)

	# Shared low-poly spheres stamped with crisp ink contour
	var mesh_small := SphereMesh.new()
	mesh_small.radius = 0.0024
	mesh_small.height = 0.0048
	mesh_small.radial_segments = 10
	mesh_small.rings = 6

	var mesh_med := SphereMesh.new()
	mesh_med.radius = 0.0036
	mesh_med.height = 0.0072
	mesh_med.radial_segments = 10
	mesh_med.rings = 6

	var mesh_pop := SphereMesh.new()
	mesh_pop.radius = 0.0045
	mesh_pop.height = 0.0090
	mesh_pop.radial_segments = 12
	mesh_pop.rings = 7

	# 11 rising / floating & popping ale crown bubbles
	for i in range(11):
		var mi := MeshInstance3D.new()
		mi.name = "RiseBubble_%d" % i
		mi.mesh = mesh_pop if (i % 4 == 0) else (mesh_med if (i % 2 == 0) else mesh_small)
		mi.material_override = amber_mat if (i % 3 == 0) else cream_mat
		add_child(mi)

		var b: Dictionary = {
			"node": mi,
			"kind": "rise",
			"age": float(i) / 11.0,
			"life": _rng.randf_range(1.15, 1.85),
			"base_pos": _pick_crown_spawn(i),
			"rise_h": _rng.randf_range(0.018, 0.042),
			"wobble_amp": _rng.randf_range(0.0018, 0.0038),
			"wobble_freq": _rng.randf_range(3.6, 6.2),
			"phase": _rng.randf_range(0.0, TAU),
		}
		_bubbles.append(b)

	# 5 surface simmering / micro-pop bubbles along the frothy foam crown
	for j in range(5):
		var smi := MeshInstance3D.new()
		smi.name = "SimmerBubble_%d" % j
		smi.mesh = mesh_pop if (j % 2 == 0) else mesh_med
		smi.material_override = cream_mat if (j != 2) else amber_mat
		add_child(smi)

		var ang := float(j) * (TAU / 5.0) + 0.45
		var rad := _rng.randf_range(0.012, 0.028)
		var b: Dictionary = {
			"node": smi,
			"kind": "simmer",
			"age": float(j) / 5.0,
			"life": _rng.randf_range(0.75, 1.25),
			"base_pos": Vector3(cos(ang) * rad, _rng.randf_range(0.104, 0.116), sin(ang) * rad),
			"rise_h": 0.005,
			"wobble_amp": 0.0008,
			"wobble_freq": 5.0,
			"phase": _rng.randf_range(0.0, TAU),
		}
		_bubbles.append(b)

	_apply_bubble_frame(0.0)


func _pick_crown_spawn(idx: int) -> Vector3:
	var ang := float(idx) * 2.399963 + _rng.randf_range(-0.25, 0.25)
	var rad := _rng.randf_range(0.004, 0.030)
	var dome_y := 0.118 - (rad / 0.034) * 0.012
	return Vector3(cos(ang) * rad, dome_y, sin(ang) * rad)


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := minf(delta, 0.05)
	_time += dt
	_apply_bubble_frame(dt)


func _apply_bubble_frame(dt: float) -> void:
	if is_instance_valid(_foam_mesh):
		var fizz := 1.0 + sin(_time * 4.2) * 0.016
		var squish := 1.0 - sin(_time * 4.2) * 0.008
		_foam_mesh.scale = Vector3(_foam_base_scale.x * squish, _foam_base_scale.y * fizz, _foam_base_scale.z * squish)

	for bi in range(_bubbles.size()):
		var b: Dictionary = _bubbles[bi]
		var mi: MeshInstance3D = b.get("node", null) as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		var life := maxf(0.2, float(b["life"]))
		var age := float(b["age"]) + dt / life
		if age >= 1.0:
			age = fmod(age, 1.0)
			if str(b["kind"]) == "rise":
				b["base_pos"] = _pick_crown_spawn(bi)
		b["age"] = age

		var bp: Vector3 = b["base_pos"]
		var rise_h := float(b["rise_h"])
		var w_amp := float(b["wobble_amp"])
		var w_freq := float(b["wobble_freq"])
		var ph := float(b["phase"])

		var lift := ease(age, 0.72) * rise_h
		var sx := sin(age * w_freq * TAU + ph) * w_amp
		var sz := cos(age * w_freq * TAU * 0.85 + ph) * w_amp
		mi.position = bp + Vector3(sx, lift, sz)

		# Swell in smoothly -> hold -> pop burst in last 10%
		var sc: float
		if age < 0.18:
			sc = lerpf(0.15, 1.0, age / 0.18)
		elif age < 0.90:
			sc = 1.0 + sin(age * 12.0 + ph) * 0.08
		else:
			var p := (age - 0.90) / 0.10
			sc = lerpf(1.36, 0.04, p * p)
		var stretch_y := 1.0 + 0.14 * sin(age * 9.0 + ph)
		mi.scale = Vector3(sc / sqrt(stretch_y), sc * stretch_y, sc / sqrt(stretch_y))
