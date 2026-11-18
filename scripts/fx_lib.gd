extends RefCounted
class_name FxLib
## Reusable particle / feedback effects for LIALO (GL Compatibility safe: CPUParticles3D + Label3D).
## All functions take a parent Node3D (inside the tree) and GLOBAL positions.

const RING_SHADER := preload("res://shaders/fx_ring.gdshader")
const FONT_PATH := "res://assets/fonts/LialoDisplay.ttf"

static var _soft_tex: Texture2D
static var _spark_tex: Texture2D
static var _font: Font


static func soft_tex() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft_tex = t
	return _soft_tex


static func spark_tex() -> Texture2D:
	# Hard-core star dot (bright centre, quick falloff) for crisp sparks
	if _spark_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.18, Color(1, 1, 1, 0.9))
		g.add_point(0.4, Color(1, 1, 1, 0.15))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_spark_tex = t
	return _spark_tex


static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
		else:
			_font = ThemeDB.fallback_font
	return _font


static func _particle_mat(additive: bool, hard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = spark_tex() if hard else soft_tex()
	m.disable_receive_shadows = true
	m.no_depth_test = false
	return m


static func _auto_free(parent: Node, n: Node, after: float) -> void:
	if parent.is_inside_tree():
		var n_wr: WeakRef = weakref(n)
		parent.get_tree().create_timer(after, true, false, true).timeout.connect(func():
			var inst := n_wr.get_ref() as Node
			if is_instance_valid(inst):
				inst.queue_free()
		)


## Generic one-shot particle burst.
static func burst(parent: Node3D, gpos: Vector3, col: Color, amount: int = 24, speed: float = 1.2,
		life: float = 0.6, size: float = 0.035, gravity: float = 2.0, additive: bool = true,
		spread: float = 180.0, dir: Vector3 = Vector3.UP, hard: bool = true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	p.mesh = q
	p.material_override = _particle_mat(additive, hard)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.damping_min = 1.2
	p.damping_max = 2.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(0.7, 0.75))
	sc.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = sc
	var gr := Gradient.new()
	gr.set_color(0, Color(col.r * 1.0 + 0.35, col.g + 0.35, col.b + 0.35, 1.0))
	gr.set_color(1, Color(col.r, col.g, col.b, 0.0))
	gr.add_point(0.25, Color(col.r, col.g, col.b, 1.0))
	p.color_ramp = gr
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.02
	parent.add_child(p)
	p.global_position = gpos
	p.emitting = true
	_auto_free(parent, p, life + 0.4)
	return p


## Flat expanding soft ring lying on the table (or facing up).
static func ring(parent: Node3D, gpos: Vector3, col: Color, radius: float = 0.5, dur: float = 0.42,
		thickness: float = 0.10, intensity: float = 1.6, spokes: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = RING_SHADER
	sm.set_shader_parameter("ring_color", col)
	sm.set_shader_parameter("thickness", thickness)
	sm.set_shader_parameter("intensity", intensity)
	sm.set_shader_parameter("spokes", spokes)
	sm.set_shader_parameter("progress", 0.0)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = gpos
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): sm.set_shader_parameter("progress", v), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)


## Balatro-style floating score tag (+15 / +4 Mult / x1.5) that pops, rises and fades in 3D.
static func float_number(parent: Node3D, gpos: Vector3, txt: String, col: Color, px: int = 64,
		rise: float = 0.22, dur: float = 0.85, pop: float = 1.65) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font = font()
	l.font_size = px
	l.outline_size = maxi(8, int(px * 0.22))
	l.modulate = Color(col.r, col.g, col.b, 1.0)
	l.outline_modulate = Color(0.06, 0.03, 0.02, 1.0)
	l.pixel_size = 0.0011
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.render_priority = 10
	l.outline_render_priority = 9
	parent.add_child(l)
	l.global_position = gpos
	l.scale = Vector3.ONE * 0.2
	var start := l.position
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * pop, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(l, "position", start + Vector3(0, rise * 0.35, 0), 0.14)
	tw.tween_interval(dur * 0.35)
	tw.tween_property(l, "position", start + Vector3(0, rise, 0), dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 0.0, dur * 0.5)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, dur * 0.5)
	tw.tween_callback(l.queue_free)
	return l


## Woodcut-themed ink splatter (dark droplets, normal blend) for card slams.
static func ink_splat(parent: Node3D, gpos: Vector3, amount: int = 18, power: float = 1.0) -> void:
	burst(parent, gpos + Vector3(0, 0.02, 0), Color(0.07, 0.045, 0.035), amount, 0.9 * power, 0.45, 0.030, 5.5, false, 70.0, Vector3.UP, false)


## Gold leaf flakes that tumble down (X-Mult / big wins).
static func gold_flakes(parent: Node3D, gpos: Vector3, amount: int = 30, power: float = 1.0) -> void:
	burst(parent, gpos, Color(1.0, 0.78, 0.28), amount, 1.6 * power, 1.1, 0.028, 1.4, true, 75.0, Vector3.UP, true)


## Rising ember fountain (fire / ON FIRE state).
static func embers(parent: Node3D, gpos: Vector3, amount: int = 40, power: float = 1.0) -> void:
	var p := burst(parent, gpos, Color(1.0, 0.45, 0.12), amount, 1.1 * power, 1.3, 0.03, -0.8, true, 28.0, Vector3.UP, true)
	p.explosiveness = 0.55


# ============================================================================
# BESPOKE PLAY VFX (7-Attack, Ace Freeze, Horník Shift, SPEC_* signatures)
# ============================================================================

static func _unlit_mat(col: Color, additive: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


## Two crossing forged-iron daggers + crimson slash arcs (7 draw attack).
static func dagger_slash(parent: Node3D, gpos: Vector3, toward: Vector3, power: float = 1.0) -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.30, 0.32, 0.36)
	iron.metallic = 0.85
	iron.roughness = 0.32
	iron.emission_enabled = true
	iron.emission = Color(0.55, 0.08, 0.06)
	iron.emission_energy_multiplier = 0.8
	for side in [-1.0, 1.0]:
		var root := Node3D.new()
		parent.add_child(root)
		root.global_position = gpos + Vector3(side * 0.22, 0.30, 0.0)
		var blade := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.05, 0.26, 0.012)
		blade.mesh = pm
		blade.material_override = iron
		root.add_child(blade)
		var hilt := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.10, 0.018, 0.02)
		hilt.mesh = hb
		hilt.position = Vector3(0, -0.13, 0)
		hilt.material_override = iron
		root.add_child(hilt)
		root.rotation_degrees = Vector3(0, 0, side * 40.0)
		root.scale = Vector3.ONE * 0.2
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector3.ONE * (1.0 + 0.2 * power), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(root, "rotation_degrees:z", -side * 40.0, 0.20).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(root, "global_position", gpos + Vector3(-side * 0.05, 0.22, 0.0), 0.20)
		tw.tween_interval(0.12)
		tw.tween_property(root, "global_position", toward + Vector3(0, 0.25, 0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(root, "scale", Vector3.ONE * 0.05, 0.24)
		tw.tween_callback(root.queue_free)
	# crimson slash arcs (thin flat torus-like rings tilted vertically)
	for k in range(2):
		var arc := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.26
		tm.outer_radius = 0.275
		tm.rings = 24
		tm.ring_segments = 6
		arc.mesh = tm
		var am := _unlit_mat(Color(1.0, 0.18, 0.12, 0.9))
		arc.material_override = am
		parent.add_child(arc)
		arc.global_position = gpos + Vector3(0, 0.24, 0)
		arc.rotation_degrees = Vector3(90.0, 0.0, 45.0 if k == 0 else -45.0)
		arc.scale = Vector3(0.3, 0.3, 0.3)
		var atw := arc.create_tween()
		atw.tween_interval(0.05 * k)
		atw.tween_property(arc, "scale", Vector3(1.25, 1.25, 1.25), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		atw.parallel().tween_property(am, "albedo_color:a", 0.0, 0.30)
		atw.tween_callback(arc.queue_free)
	ring(parent, gpos + Vector3(0, 0.012, 0), Color(1.0, 0.12, 0.08), 0.75 * power, 0.50, 0.10, 2.2, 12.0)
	burst(parent, gpos + Vector3(0, 0.2, 0), Color(1.0, 0.18, 0.10), 26, 1.6, 0.5, 0.03, 2.5, true, 160.0)


## Ace freeze: expanding frost/amber clock-face sigil + golden chain shatter over a side.
static func sigil_clock(parent: Node3D, gpos: Vector3, side_pos: Vector3, power: float = 1.0) -> void:
	ring(parent, gpos + Vector3(0, 0.014, 0), Color(0.55, 0.85, 1.0), 0.55, 0.55, 0.06, 2.0, 12.0)
	ring(parent, gpos + Vector3(0, 0.016, 0), Color(1.0, 0.72, 0.26), 0.38, 0.65, 0.05, 1.8, 24.0)
	# clock hands
	var hand_root := Node3D.new()
	parent.add_child(hand_root)
	hand_root.global_position = side_pos + Vector3(0, 0.35, 0)
	var hm := _unlit_mat(Color(0.75, 0.92, 1.0, 0.95))
	for L in [0.20, 0.13]:
		var h := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.012, L, 0.006)
		h.mesh = b
		h.position = Vector3(0, L * 0.5, 0)
		h.material_override = hm
		var piv := Node3D.new()
		piv.add_child(h)
		hand_root.add_child(piv)
		var tw := piv.create_tween()
		tw.tween_property(piv, "rotation:z", -TAU * (1.0 if L > 0.15 else 0.25), 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var face := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.20
	tm.outer_radius = 0.215
	face.mesh = tm
	face.rotation_degrees.x = 90.0
	face.material_override = _unlit_mat(Color(1.0, 0.78, 0.30, 0.9))
	hand_root.add_child(face)
	hand_root.scale = Vector3.ONE * 0.2
	var rtw := hand_root.create_tween()
	rtw.tween_property(hand_root, "scale", Vector3.ONE * power, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rtw.tween_interval(0.45)
	rtw.tween_callback(func():
		if is_instance_valid(parent):
			burst(parent, side_pos + Vector3(0, 0.35, 0), Color(1.0, 0.80, 0.30), 34, 1.8, 0.6, 0.03, 3.0, true, 180.0)
			burst(parent, side_pos + Vector3(0, 0.35, 0), Color(0.6, 0.9, 1.0), 20, 1.2, 0.7, 0.025, 1.0, true, 180.0)
	)
	rtw.tween_property(hand_root, "scale", Vector3.ONE * 1.6, 0.10)
	rtw.tween_callback(hand_root.queue_free)


## Vertical pillar of light (Horník suit lock, Crown, etc.).
static func light_pillar(parent: Node3D, gpos: Vector3, col: Color, height: float = 1.6, dur: float = 0.8) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.10
	cm.bottom_radius = 0.16
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := _unlit_mat(Color(col.r, col.g, col.b, 0.55))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = gpos + Vector3(0, height * 0.5, 0)
	mi.scale = Vector3(0.1, 1.0, 0.1)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur * 0.4)
	tw.tween_property(mi, "scale", Vector3(0.05, 1.2, 0.05), dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur * 0.5)
	tw.tween_callback(mi.queue_free)


## 4-colour prismatic compass spin that locks onto the chosen suit colour.
static func compass_spin(parent: Node3D, gpos: Vector3, lock_col: Color) -> void:
	var cols := [Color(0.92, 0.18, 0.20), Color(0.95, 0.70, 0.22), Color(0.22, 0.78, 0.36), Color(1.0, 0.50, 0.12)]
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = gpos + Vector3(0, 0.03, 0)
	for i in range(4):
		var petal := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.10, 0.30, 0.01)
		petal.mesh = pm
		petal.material_override = _unlit_mat(Color(cols[i].r, cols[i].g, cols[i].b, 0.85))
		petal.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		var piv := Node3D.new()
		piv.rotation.y = float(i) * PI * 0.5
		petal.position = Vector3(0, 0, -0.17)
		piv.add_child(petal)
		root.add_child(piv)
	var tw := root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * 3.0, 0.65).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(parent):
			light_pillar(parent, gpos, lock_col, 1.8, 0.9)
			ring(parent, gpos + Vector3(0, 0.015, 0), lock_col, 0.7, 0.5, 0.08, 2.2, 4.0)
	)
	tw.tween_property(root, "scale", Vector3(1.6, 1.6, 1.6), 0.25)
	tw.tween_callback(root.queue_free)


## Particles streaming from one point to another (blood siphon etc.).
static func siphon(parent: Node3D, from_pos: Vector3, to_pos: Vector3, col: Color, count: int = 18, dur: float = 0.7) -> void:
	var tex_q := QuadMesh.new()
	tex_q.size = Vector2(0.04, 0.04)
	var pm := _unlit_mat(Color(col.r, col.g, col.b, 0.9))
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.albedo_texture = soft_tex()
	for i in range(count):
		var mi := MeshInstance3D.new()
		mi.mesh = tex_q
		mi.material_override = pm
		parent.add_child(mi)
		var off := Vector3(randf_range(-0.12, 0.12), randf_range(-0.05, 0.12), randf_range(-0.12, 0.12))
		mi.global_position = from_pos + off
		var mid := from_pos.lerp(to_pos, 0.5) + Vector3(randf_range(-0.2, 0.2), 0.35, randf_range(-0.1, 0.1))
		var tw := mi.create_tween()
		tw.tween_interval(float(i) * dur * 0.03)
		tw.tween_method(func(u: float):
			if is_instance_valid(mi):
				var a := (from_pos + off).lerp(mid, u)
				var b := mid.lerp(to_pos, u)
				mi.global_position = a.lerp(b, u)
		, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	burst(parent, to_pos, col, 22, 0.9, 0.5, 0.03, 1.0, true, 180.0)


## Rising fire-feather vortex (Phoenix).
static func feather_vortex(parent: Node3D, gpos: Vector3, power: float = 1.0) -> void:
	for k in range(3):
		var p := burst(parent, gpos + Vector3(0, 0.05 * k, 0), [Color(1.0, 0.45, 0.10), Color(1.0, 0.78, 0.25), Color(1.0, 0.25, 0.08)][k], 36, 1.6 * power, 1.2, 0.05, -1.4, true, 25.0, Vector3.UP, false)
		p.orbit_velocity_min = 0.6
		p.orbit_velocity_max = 1.2
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 0.22 + 0.06 * k
		p.emission_ring_inner_radius = 0.18
		p.emission_ring_height = 0.01
		p.explosiveness = 0.3
	light_pillar(parent, gpos, Color(1.0, 0.55, 0.15), 1.4, 0.9)


## Generic themed geometric burst: octahedra-ish shards flying outward.
static func shard_burst(parent: Node3D, gpos: Vector3, col: Color, count: int = 10, radius: float = 0.45) -> void:
	var m := _unlit_mat(Color(col.r, col.g, col.b, 0.95))
	for i in range(count):
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.045, 0.09, 0.045)
		mi.mesh = pm
		mi.material_override = m
		parent.add_child(mi)
		mi.global_position = gpos + Vector3(0, 0.12, 0)
		var a := float(i) / float(count) * TAU
		var dest := gpos + Vector3(cos(a) * radius, 0.25 + randf() * 0.2, sin(a) * radius)
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", dest, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mi, "rotation", Vector3(randf() * 6.0, randf() * 6.0, randf() * 6.0), 0.45)
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.1, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	ring(parent, gpos + Vector3(0, 0.013, 0), col, radius * 1.4, 0.45, 0.08, 2.0, 8.0)


## Straight light beam between two points (relic → score pile).
static func beam(parent: Node3D, from_pos: Vector3, to_pos: Vector3, col: Color, dur: float = 0.32) -> void:
	var len := from_pos.distance_to(to_pos)
	if len < 0.01:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = len
	mi.mesh = cm
	var m := _unlit_mat(Color(col.r, col.g, col.b, 0.85))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var mid := (from_pos + to_pos) * 0.5
	mi.global_position = mid
	var dir := (to_pos - from_pos).normalized()
	var up := Vector3.UP
	var axis := up.cross(dir)
	if axis.length() > 0.0001:
		mi.global_basis = Basis(axis.normalized(), up.angle_to(dir))
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mi, "scale", Vector3(2.5, 1.0, 2.5), dur)
	tw.tween_callback(mi.queue_free)
	burst(parent, to_pos, col, 10, 0.6, 0.35, 0.025, 0.5, true, 180.0)
