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


# ============================================================================
# FLAGSHIP HIGH-CRAFT VFX SUITES (Quality Over Quantity)
# ============================================================================

## Deck-top rune launch effect when drawing a card.
static func magical_draw_launch(parent: Node3D, deck_top: Vector3, col: Color) -> void:
	if not is_instance_valid(parent):
		return
	ring(parent, deck_top + Vector3(0.0, 0.01, 0.0), col.lightened(0.25), 0.32, 0.38, 0.09, 2.2, 8.0)
	ring(parent, deck_top + Vector3(0.0, 0.018, 0.0), Color(0.98, 0.90, 0.54), 0.22, 0.32, 0.06, 1.7, 0.0)
	var p := burst(parent, deck_top + Vector3(0.0, 0.02, 0.0), col.lightened(0.32), 20, 0.85, 0.52, 0.024, -0.55, true, 52.0, Vector3.UP, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.075
	p.emission_ring_inner_radius = 0.045
	p.emission_ring_height = 0.01
	var flash := OmniLight3D.new()
	flash.light_color = col.lightened(0.28)
	flash.light_energy = 2.6
	flash.omni_range = 1.9
	flash.omni_attenuation = 1.4
	parent.add_child(flash)
	flash.global_position = deck_top + Vector3(0.0, 0.14, 0.0)
	var ftw := flash.create_tween()
	ftw.tween_property(flash, "light_energy", 0.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ftw.tween_callback(flash.queue_free)


## Attaches layered glowing spark + mist ribbon trail + traveling OmniLight3D onto a flying card.
static func attach_magical_card_trail(card_node: Node3D, col: Color) -> Dictionary:
	var handles := {"sparks": null, "mist": null, "light": null}
	if not is_instance_valid(card_node):
		return handles

	var sparks := CPUParticles3D.new()
	sparks.name = "MagicalCardSparks"
	sparks.amount = 34
	sparks.lifetime = 0.48
	sparks.local_coords = false
	sparks.emitting = true
	var sq := QuadMesh.new()
	sq.size = Vector2(0.024, 0.024)
	sparks.mesh = sq
	sparks.material_override = _particle_mat(true, true)
	sparks.direction = Vector3(0.0, 1.0, 0.0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 0.08
	sparks.initial_velocity_max = 0.34
	sparks.gravity = Vector3(0.0, 0.14, 0.0)
	sparks.damping_min = 1.4
	sparks.damping_max = 2.6
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.055, 0.01, 0.075)
	var sc_curve := Curve.new()
	sc_curve.add_point(Vector2(0.0, 1.0))
	sc_curve.add_point(Vector2(0.55, 0.72))
	sc_curve.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = sc_curve
	var sp_grad := Gradient.new()
	sp_grad.set_color(0, Color(1.0, 0.96, 0.80, 1.0))
	sp_grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	sp_grad.add_point(0.28, Color(col.r, col.g, col.b, 0.96))
	sparks.color_ramp = sp_grad
	card_node.add_child(sparks)
	handles["sparks"] = sparks

	var mist := CPUParticles3D.new()
	mist.name = "MagicalCardMistTrail"
	mist.amount = 22
	mist.lifetime = 0.42
	mist.local_coords = false
	mist.emitting = true
	var mq := QuadMesh.new()
	mq.size = Vector2(0.068, 0.068)
	mist.mesh = mq
	mist.material_override = _particle_mat(true, false)
	mist.direction = Vector3(0.0, 0.3, 0.0)
	mist.spread = 45.0
	mist.initial_velocity_min = 0.02
	mist.initial_velocity_max = 0.12
	mist.gravity = Vector3(0.0, 0.05, 0.0)
	var m_curve := Curve.new()
	m_curve.add_point(Vector2(0.0, 0.65))
	m_curve.add_point(Vector2(0.35, 1.0))
	m_curve.add_point(Vector2(1.0, 0.0))
	mist.scale_amount_curve = m_curve
	var m_grad := Gradient.new()
	m_grad.set_color(0, Color(col.r, col.g, col.b, 0.44))
	m_grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	mist.color_ramp = m_grad
	card_node.add_child(mist)
	handles["mist"] = mist

	var glow_light := OmniLight3D.new()
	glow_light.name = "MagicalCardLight"
	glow_light.light_color = col.lightened(0.25)
	glow_light.light_energy = 1.85
	glow_light.omni_range = 1.65
	glow_light.omni_attenuation = 1.35
	glow_light.position = Vector3(0.0, 0.08, 0.0)
	card_node.add_child(glow_light)
	handles["light"] = glow_light

	return handles


## Unified high-craft card-play impact shockwave + woodcut ink + ember burst + warm table flash.
static func card_slam_master(parent: Node3D, impact_pos: Vector3, col: Color, intensity: float = 1.0) -> void:
	if not is_instance_valid(parent):
		return
	var pwr := clampf(intensity, 0.6, 2.0)
	ink_splat(parent, impact_pos, int(round(14.0 * pwr)), pwr)
	burst(parent, impact_pos + Vector3(0.0, 0.025, 0.0), col.lightened(0.22), int(round(20.0 * pwr)), 1.35 * pwr, 0.52, 0.028, 2.0, true, 125.0, Vector3.UP, true)
	ring(parent, impact_pos + Vector3(0.0, 0.014, 0.0), col.lightened(0.20), 0.58 * pwr, 0.42, 0.11, 2.1, 10.0)
	ring(parent, impact_pos + Vector3(0.0, 0.018, 0.0), Color(1.0, 0.90, 0.52), 0.36 * pwr, 0.32, 0.07, 1.7, 0.0)
	var imp_light := OmniLight3D.new()
	imp_light.light_color = col.lightened(0.30)
	imp_light.light_energy = 3.6 * pwr
	imp_light.omni_range = 2.8
	imp_light.omni_attenuation = 1.3
	parent.add_child(imp_light)
	imp_light.global_position = impact_pos + Vector3(0.0, 0.28, 0.0)
	var ltw := imp_light.create_tween()
	ltw.tween_property(imp_light, "light_energy", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ltw.tween_callback(imp_light.queue_free)


## Focused Buckshot item-ritual activation sigil, swirling sparks, energy arc, and light pulse.
static func item_ritual_activation(parent: Node3D, item_pos: Vector3, target_pos: Vector3, col: Color) -> void:
	if not is_instance_valid(parent):
		return
	ring(parent, item_pos + Vector3(0.0, 0.012, 0.0), col.lightened(0.28), 0.28, 0.44, 0.11, 2.2, 12.0)
	var helix := burst(parent, item_pos + Vector3(0.0, 0.03, 0.0), col.lightened(0.32), 24, 1.05, 0.58, 0.026, -0.75, true, 38.0, Vector3.UP, true)
	helix.orbit_velocity_min = 0.75
	helix.orbit_velocity_max = 1.45
	beam(parent, item_pos + Vector3(0.0, 0.08, 0.0), target_pos, col.lightened(0.35), 0.38)
	var item_light := OmniLight3D.new()
	item_light.light_color = col.lightened(0.32)
	item_light.light_energy = 3.1
	item_light.omni_range = 2.2
	parent.add_child(item_light)
	item_light.global_position = item_pos + Vector3(0.0, 0.22, 0.0)
	var tw := item_light.create_tween()
	tw.tween_property(item_light, "light_energy", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(item_light.queue_free)


# ============================================================================
# BLEACH TYBW-INSPIRED EFFECTS & ARCHETYPE CARD PLAY VFX
# ============================================================================

## Getsuga-style razor-sharp crescent energy slash (pitch-black ink core + blazing reiatsu edge).
static func tybw_slash_arc(parent: Node3D, origin: Vector3, target: Vector3, accent_col: Color,
		dark_core: bool = true, scale_mult: float = 1.0, tilt_deg: float = -24.0) -> void:
	if not is_instance_valid(parent):
		return
	var root := Node3D.new()
	root.name = "TybwSlashArc"
	parent.add_child(root)
	root.global_position = origin
	var dir_v := (target - origin)
	if dir_v.length_squared() > 0.0001:
		var flat_yaw := atan2(dir_v.x, dir_v.z)
		root.rotation = Vector3(0.0, flat_yaw, deg_to_rad(tilt_deg))

	# Outer blazing reiatsu crescent
	var outer := MeshInstance3D.new()
	var ot := TorusMesh.new()
	ot.inner_radius = 0.24 * scale_mult
	ot.outer_radius = 0.34 * scale_mult
	ot.rings = 28
	ot.ring_segments = 8
	outer.mesh = ot
	outer.scale = Vector3(1.45, 0.22, 0.72)
	outer.material_override = _unlit_mat(Color(accent_col.r, accent_col.g, accent_col.b, 0.96), true)
	root.add_child(outer)

	# Stark ink-black inner core (signature TYBW Getsuga contrast)
	if dark_core:
		var inner := MeshInstance3D.new()
		var it := TorusMesh.new()
		it.inner_radius = 0.255 * scale_mult
		it.outer_radius = 0.315 * scale_mult
		it.rings = 24
		it.ring_segments = 6
		inner.mesh = it
		inner.scale = Vector3(1.38, 0.28, 0.66)
		inner.position = Vector3(0.0, 0.0, 0.015)
		inner.material_override = _unlit_mat(Color(0.015, 0.01, 0.02, 0.95), false)
		root.add_child(inner)

	# Trailing spiritual embers + ink sparks
	var trail := CPUParticles3D.new()
	trail.amount = 32
	trail.lifetime = 0.38
	trail.local_coords = false
	trail.emitting = true
	var tq := QuadMesh.new()
	tq.size = Vector2(0.036 * scale_mult, 0.036 * scale_mult)
	trail.mesh = tq
	trail.material_override = _particle_mat(true, true)
	trail.direction = Vector3(0.0, 0.2, -1.0)
	trail.spread = 45.0
	trail.initial_velocity_min = 0.35
	trail.initial_velocity_max = 1.15
	trail.gravity = Vector3.ZERO
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.98, 0.94, 1.0))
	gr.add_point(0.28, Color(accent_col.r, accent_col.g, accent_col.b, 0.95))
	gr.set_color(1, Color(0.05, 0.02, 0.05, 0.0))
	trail.color_ramp = gr
	root.add_child(trail)

	var slash_light := OmniLight3D.new()
	slash_light.light_color = accent_col.lightened(0.2)
	slash_light.light_energy = 4.2 * scale_mult
	slash_light.omni_range = 3.2
	root.add_child(slash_light)

	root.scale = Vector3(0.35, 0.35, 0.35)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.18, 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "global_position", target, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(parent):
			ring(parent, target + Vector3(0.0, 0.04, 0.0), accent_col, 0.72 * scale_mult, 0.42, 0.10, 2.5, 14.0)
			burst(parent, target, accent_col, int(24 * scale_mult), 1.9 * scale_mult, 0.55, 0.034, 1.2, true, 140.0, Vector3.UP, true)
			ink_splat(parent, target, int(14 * scale_mult), scale_mult)
	)
	tw.tween_property(root, "scale", Vector3(2.2, 0.05, 1.8), 0.16).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(slash_light, "light_energy", 0.0, 0.16)
	tw.tween_callback(root.queue_free)


## Quincy Heilig Pfeil / Licht Regen: electric-cyan sacred sigil firing staggered spirit arrows.
static func tybw_quincy_volley(parent: Node3D, origin: Vector3, target: Vector3,
		arrow_count: int = 7, col: Color = Color(0.22, 0.88, 1.0)) -> void:
	if not is_instance_valid(parent):
		return
	var sigil_pos := origin + Vector3(0.0, 0.52, 0.0)
	ring(parent, sigil_pos, col, 0.48, 0.82, 0.08, 2.6, 5.0)
	ring(parent, sigil_pos + Vector3(0.0, 0.02, 0.0), Color(0.88, 0.98, 1.0), 0.30, 0.75, 0.05, 2.2, 10.0)

	var n := clampi(arrow_count, 3, 14)
	for i in range(n):
		var ang := float(i) * (TAU / float(n))
		var spawn_p := sigil_pos + Vector3(cos(ang) * 0.32, sin(ang) * 0.18 + 0.08, sin(ang) * 0.16)
		var lance := Node3D.new()
		lance.name = "QuincyArrow_%d" % i
		parent.add_child(lance)
		lance.global_position = spawn_p

		var shaft := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.004
		cyl.bottom_radius = 0.016
		cyl.height = 0.44
		shaft.mesh = cyl
		shaft.rotation_degrees.x = 90.0
		shaft.material_override = _unlit_mat(Color(0.88, 0.98, 1.0, 0.98), true)
		lance.add_child(shaft)

		var aura := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = 0.008
		ac.bottom_radius = 0.032
		ac.height = 0.50
		aura.mesh = ac
		aura.rotation_degrees.x = 90.0
		aura.material_override = _unlit_mat(Color(col.r, col.g, col.b, 0.65), true)
		lance.add_child(aura)

		var hit_p := target + Vector3(randf_range(-0.18, 0.18), randf_range(0.02, 0.14), randf_range(-0.14, 0.14))
		if (hit_p - spawn_p).length_squared() > 0.001:
			lance.look_at_from_position(spawn_p, hit_p, Vector3.UP)

		lance.scale = Vector3(0.1, 0.1, 0.1)
		var delay := float(i) * 0.042
		var tw := lance.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(lance, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lance, "global_position", hit_p, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if is_instance_valid(parent):
				ring(parent, hit_p + Vector3(0.0, 0.015, 0.0), col, 0.24, 0.28, 0.09, 2.4, 4.0)
				burst(parent, hit_p, col, 10, 1.35, 0.35, 0.022, 0.4, true, 120.0, Vector3.UP, true)
		)
		tw.tween_callback(lance.queue_free)


## Towering Bleach TYBW vertical Reiatsu pressure pillar (dark inner ink core + glowing outer shell).
static func tybw_reiatsu_pillar(parent: Node3D, gpos: Vector3, col: Color,
		height: float = 2.4, radius: float = 0.34, dur: float = 0.95) -> void:
	if not is_instance_valid(parent):
		return
	var root := Node3D.new()
	root.name = "TybwReiatsuPillar"
	parent.add_child(root)
	root.global_position = gpos

	var outer := MeshInstance3D.new()
	var om := CylinderMesh.new()
	om.top_radius = radius * 1.18
	om.bottom_radius = radius * 0.86
	om.height = height
	om.radial_segments = 24
	outer.mesh = om
	outer.position = Vector3(0.0, height * 0.5, 0.0)
	outer.material_override = _unlit_mat(Color(col.r, col.g, col.b, 0.74), true)
	root.add_child(outer)

	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.52
	cm.bottom_radius = radius * 0.40
	cm.height = height * 1.02
	cm.radial_segments = 16
	core.mesh = cm
	core.position = Vector3(0.0, height * 0.5, 0.0)
	core.material_override = _unlit_mat(Color(0.015, 0.01, 0.02, 0.88), false)
	root.add_child(core)

	var p_light := OmniLight3D.new()
	p_light.light_color = col.lightened(0.22)
	p_light.light_energy = 5.5
	p_light.omni_range = 4.2
	p_light.position = Vector3(0.0, 0.55, 0.0)
	root.add_child(p_light)

	ring(parent, gpos + Vector3(0.0, 0.016, 0.0), col, radius * 2.6, dur * 0.72, 0.11, 2.8, 16.0)
	ring(parent, gpos + Vector3(0.0, 0.022, 0.0), Color(1.0, 0.96, 0.88), radius * 1.7, dur * 0.50, 0.07, 2.2, 8.0)
	burst(parent, gpos + Vector3(0.0, 0.18, 0.0), col, 34, 2.1, 0.82, 0.036, -1.6, true, 32.0, Vector3.UP, true)

	root.scale = Vector3(0.15, 0.05, 0.15)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.15, 1.0, 1.15), 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3(1.0, 1.08, 1.0), dur * 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(root, "scale", Vector3(0.02, 1.35, 0.02), dur * 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(p_light, "light_energy", 0.0, dur * 0.40)
	tw.tween_callback(root.queue_free)


## Heavy Metallic KNIGHT Card Slam: weighted steel anvil impact, sparks, dark crater ring & cold blade cross.
static func knight_heavy_steel_slam(parent: Node3D, impact_pos: Vector3,
		accent_col: Color = Color(0.66, 0.88, 1.0), intensity: float = 1.2) -> void:
	if not is_instance_valid(parent):
		return
	var pwr := clampf(intensity, 0.8, 2.0)
	# Heavy dark shockwave + cold steel ring
	ink_splat(parent, impact_pos, int(22.0 * pwr), 1.35 * pwr)
	ring(parent, impact_pos + Vector3(0.0, 0.015, 0.0), Color(0.76, 0.88, 1.0), 0.74 * pwr, 0.48, 0.14, 2.6, 12.0)
	ring(parent, impact_pos + Vector3(0.0, 0.020, 0.0), Color(1.0, 0.72, 0.30), 0.48 * pwr, 0.34, 0.08, 2.2, 0.0)
	# Radial molten steel anvil sparks with heavy gravity
	burst(parent, impact_pos + Vector3(0.0, 0.03, 0.0), Color(1.0, 0.82, 0.38), int(34.0 * pwr), 2.1 * pwr, 0.62, 0.024, 5.8, true, 115.0, Vector3.UP, true)
	burst(parent, impact_pos + Vector3(0.0, 0.04, 0.0), accent_col, int(18.0 * pwr), 1.5 * pwr, 0.45, 0.030, 3.2, true, 150.0, Vector3.UP, true)
	# Steel blade cross-flash above the slammed card
	for ang_z in [-38.0, 38.0]:
		var slash := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.54 * pwr, 0.018 * pwr, 0.012)
		slash.mesh = bm
		slash.material_override = _unlit_mat(Color(0.92, 0.97, 1.0, 0.96), true)
		parent.add_child(slash)
		slash.global_position = impact_pos + Vector3(0.0, 0.16, 0.0)
		slash.rotation_degrees = Vector3(0.0, 0.0, ang_z)
		slash.scale = Vector3(0.05, 1.6, 1.0)
		var stw := slash.create_tween()
		stw.tween_property(slash, "scale", Vector3(1.25, 0.45, 1.0), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		stw.tween_property(slash, "scale", Vector3(1.6, 0.0, 1.0), 0.18)
		stw.tween_callback(slash.queue_free)

	var fl := OmniLight3D.new()
	fl.light_color = Color(0.84, 0.92, 1.0)
	fl.light_energy = 5.2 * pwr
	fl.omni_range = 3.4
	parent.add_child(fl)
	fl.global_position = impact_pos + Vector3(0.0, 0.32, 0.0)
	var ltw := fl.create_tween()
	ltw.tween_property(fl, "light_energy", 0.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ltw.tween_callback(fl.queue_free)


## Magical MAGE Card Cast: layered rotating Kidō spell-circles, spiraling spiritual lance & arcane burst.
static func mage_arcane_cast(parent: Node3D, origin: Vector3, target: Vector3,
		col: Color = Color(0.56, 0.38, 1.0), charged: bool = false) -> void:
	if not is_instance_valid(parent):
		return
	var r_col := Color(0.32, 0.92, 1.0) if charged else col
	ring(parent, origin + Vector3(0.0, 0.025, 0.0), r_col, 0.56 if charged else 0.40, 0.65, 0.09, 2.5, 12.0)
	ring(parent, origin + Vector3(0.0, 0.055, 0.0), Color(0.92, 0.78, 1.0), 0.36 if charged else 0.25, 0.52, 0.06, 2.0, 6.0)
	var spiral := burst(parent, origin + Vector3(0.0, 0.05, 0.0), r_col, 34 if charged else 22, 1.35, 0.72, 0.030, -0.9, true, 42.0, Vector3.UP, true)
	spiral.orbit_velocity_min = 1.2
	spiral.orbit_velocity_max = 2.4
	beam(parent, origin + Vector3(0.0, 0.14, 0.0), target + Vector3(0.0, 0.18, 0.0), r_col.lightened(0.25), 0.44)
	if charged:
		tybw_reiatsu_pillar(parent, target, r_col, 1.85, 0.26, 0.78)
	else:
		ring(parent, target + Vector3(0.0, 0.02, 0.0), r_col, 0.42, 0.42, 0.10, 2.2, 8.0)


## THIEF Shunpo Shadow-Step Strike: twin dark-emerald/crimson razor diagonal slashes + ink wisps.
static func thief_shunpo_strike(parent: Node3D, origin: Vector3, target: Vector3,
		col: Color = Color(0.18, 0.92, 0.56)) -> void:
	if not is_instance_valid(parent):
		return
	tybw_slash_arc(parent, origin + Vector3(-0.14, 0.16, 0.0), target + Vector3(0.06, 0.18, 0.0), col, true, 0.82, -36.0)
	tybw_slash_arc(parent, origin + Vector3(0.14, 0.20, 0.0), target + Vector3(-0.06, 0.14, 0.0), Color(0.96, 0.22, 0.34), true, 0.76, 36.0)


## MERCHANT Gold Vault Strike: embossed golden shockwave + tumbling bullion flakes.
static func merchant_gold_vault(parent: Node3D, impact_pos: Vector3) -> void:
	if not is_instance_valid(parent):
		return
	ring(parent, impact_pos + Vector3(0.0, 0.016, 0.0), Color(1.0, 0.84, 0.24), 0.62, 0.48, 0.11, 2.4, 8.0)
	gold_flakes(parent, impact_pos + Vector3(0.0, 0.06, 0.0), 42, 1.35)


## Custom TYBW-flavored ritual burst for each of the 10 new Active Tabletop Relics.
static func relic_tybw_ritual(parent: Node3D, item_pos: Vector3, target_pos: Vector3,
		relic_id: String, col: Color) -> void:
	if not is_instance_valid(parent):
		return
	item_ritual_activation(parent, item_pos, target_pos, col)
	match relic_id:
		"TRELIC_SOUL_BELL":
			tybw_reiatsu_pillar(parent, target_pos, Color(0.26, 0.90, 1.0), 2.1, 0.32, 0.85)
		"TRELIC_BLOOD_SEAL":
			tybw_slash_arc(parent, item_pos + Vector3(0.0, 0.22, 0.0), target_pos + Vector3(0.0, 0.22, 0.0), Color(0.96, 0.12, 0.22), true, 1.05, -18.0)
		"TRELIC_STAR_BOW":
			tybw_quincy_volley(parent, item_pos, target_pos, 7, Color(0.24, 0.90, 1.0))
		"TRELIC_ASH_GLASS":
			mage_arcane_cast(parent, item_pos, item_pos + Vector3(0.0, 0.55, 0.25), Color(0.76, 0.46, 1.0), true)
		"TRELIC_WAR_HORN":
			knight_heavy_steel_slam(parent, item_pos + Vector3(0.0, 0.02, 0.15), Color(0.74, 0.90, 1.0), 1.25)
		"TRELIC_HOLLOW_MASK":
			tybw_reiatsu_pillar(parent, item_pos, Color(0.98, 0.16, 0.24), 2.2, 0.30, 0.92)
			tybw_slash_arc(parent, item_pos + Vector3(0.0, 0.25, 0.0), target_pos + Vector3(0.0, 0.25, 0.0), Color(1.0, 0.86, 0.28), true, 1.15, 22.0)
		"TRELIC_CENSER":
			mage_arcane_cast(parent, item_pos, target_pos, Color(0.26, 0.96, 0.68), true)
		"TRELIC_GOLD_SCALES":
			merchant_gold_vault(parent, item_pos)
		"TRELIC_IRON_CHAIN":
			knight_heavy_steel_slam(parent, target_pos, Color(0.45, 0.86, 1.0), 1.35)
		"TRELIC_PHOENIX_BOX":
			tybw_reiatsu_pillar(parent, item_pos, Color(1.0, 0.52, 0.16), 2.1, 0.34, 0.90)
			embers(parent, item_pos + Vector3(0.0, 0.12, 0.0), 48, 1.35)


## Attaches subtle live ambient 3D class particles onto cards held in hand (Mage runes, Knight steel glints, etc.).
static func attach_card_class_aura(card_node: Node3D, edition_id: int, col: Color) -> void:
	if not is_instance_valid(card_node) or edition_id <= 0:
		return
	var existing := card_node.get_node_or_null("CardClassAuraFX")
	if existing:
		existing.queue_free()
	var p := CPUParticles3D.new()
	p.name = "CardClassAuraFX"
	p.local_coords = true
	p.emitting = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.072, 0.105, 0.008)
	var q := QuadMesh.new()
	if edition_id == 1: # MAGE: swirling arcane runes & rising cyan/violet motes
		p.amount = 14
		p.lifetime = 0.95
		q.size = Vector2(0.016, 0.016)
		p.direction = Vector3(0.0, 1.0, 0.0)
		p.spread = 35.0
		p.initial_velocity_min = 0.04
		p.initial_velocity_max = 0.12
		p.orbit_velocity_min = 0.45
		p.orbit_velocity_max = 0.95
		p.gravity = Vector3(0.0, 0.06, 0.0)
		p.material_override = _particle_mat(true, true)
	elif edition_id == 2: # KNIGHT: sparse cold steel forge glints
		p.amount = 7
		p.lifetime = 0.72
		q.size = Vector2(0.014, 0.014)
		p.direction = Vector3(0.0, -0.3, 0.2)
		p.spread = 60.0
		p.initial_velocity_min = 0.02
		p.initial_velocity_max = 0.07
		p.gravity = Vector3(0.0, -0.18, 0.0)
		p.material_override = _particle_mat(true, true)
	elif edition_id == 3: # MERCHANT: tiny gilded coin sparkles
		p.amount = 8
		p.lifetime = 0.85
		q.size = Vector2(0.013, 0.013)
		p.direction = Vector3(0.0, 1.0, 0.0)
		p.spread = 45.0
		p.initial_velocity_min = 0.03
		p.initial_velocity_max = 0.08
		p.gravity = Vector3.ZERO
		p.material_override = _particle_mat(true, true)
	else: # THIEF: creeping dark shadow-emerald wisps
		p.amount = 10
		p.lifetime = 0.75
		q.size = Vector2(0.022, 0.022)
		p.direction = Vector3(0.0, 0.8, -0.2)
		p.spread = 40.0
		p.initial_velocity_min = 0.03
		p.initial_velocity_max = 0.10
		p.gravity = Vector3(0.0, 0.04, 0.0)
		p.material_override = _particle_mat(true, false)
	p.mesh = q
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.98, 0.94, 0.0))
	gr.add_point(0.25, Color(col.r, col.g, col.b, 0.90))
	gr.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = gr
	card_node.add_child(p)

