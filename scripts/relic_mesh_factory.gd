extends RefCounted
## Factory for sculpted multi-part 3D medieval relics, shop artifacts, and tavern props.
## Every artifact sits cleanly on an octagonal walnut-and-brass coaster with a toggleable
## emissive ReadyHalo ring and an independently animated SpinPivot centerpiece.

const Toon = preload("res://scripts/toon_style.gd")
const BlenderVfx = preload("res://scripts/blender_vfx_animator.gd")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const HANDDRAWN_RELIC_SHADER := preload("res://shaders/handdrawn_relic_3d.gdshader")
const HANDDRAWN_OUTLINE_SHADER := preload("res://shaders/handdrawn_outline_3d.gdshader")
const TankardBubblesFxScript := preload("res://scripts/battle/tankard_bubbles_fx.gd")
const RelicLivingFxScript := preload("res://scripts/battle/relic_living_fx.gd")

const HANDDRAWN_TRELIC_IDS := [
	"TRELIC_HOLLOW_MASK",
	"TRELIC_STAR_BOW",
	"TRELIC_BLOOD_SEAL",
	"TRELIC_IRON_CHAIN",
	"TRELIC_ASH_GLASS",
	"TRELIC_GOLD_SCALES",
	"TRELIC_SOUL_BELL",
	"TRELIC_CENSER",
	"TRELIC_PHOENIX_BOX",
]


static func _apply_woodcut_ink_outline(node: Node, thickness: float = 0.005) -> void:
	var out_mat := ShaderMaterial.new()
	out_mat.shader = OUTLINE_SHADER
	out_mat.set_shader_parameter("thickness", thickness)
	out_mat.set_shader_parameter("outline_color", Color(0.03, 0.02, 0.02, 1.0))
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


static func _make_handdrawn_mat(
	tex_path: String,
	tint: Color,
	shadow_tint: Color,
	hatch_str: float,
	hatch_dens: float,
	spec_str: float,
	spec_sz: float,
	rim_str: float,
	outline_thick: float,
	uv_sc: Vector2 = Vector2.ONE,
	ao_str: float = 0.78,
	emission: Color = Color.BLACK
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDDRAWN_RELIC_SHADER
	mat.set_shader_parameter("albedo_tint", tint)
	mat.set_shader_parameter("shadow_tint", shadow_tint)
	mat.set_shader_parameter("highlight_tint", Color(1.0, 0.94, 0.80, 1.0))
	mat.set_shader_parameter("uv_scale", uv_sc)
	mat.set_shader_parameter("hatch_strength", hatch_str)
	mat.set_shader_parameter("hatch_density", hatch_dens)
	mat.set_shader_parameter("specular_strength", spec_str)
	mat.set_shader_parameter("specular_size", spec_sz)
	mat.set_shader_parameter("rim_strength", rim_str)
	mat.set_shader_parameter("ao_ink_strength", ao_str)
	mat.set_shader_parameter("emission_color", emission)
	var tx := Toon.tex(tex_path) if tex_path != "" else null
	if tx != null:
		mat.set_shader_parameter("albedo_tex", tx)
		mat.set_shader_parameter("use_texture", true)
	else:
		mat.set_shader_parameter("use_texture", false)
	if outline_thick > 0.0:
		var out := ShaderMaterial.new()
		out.shader = HANDDRAWN_OUTLINE_SHADER
		out.set_shader_parameter("thickness", outline_thick)
		out.set_shader_parameter("dist_scale", outline_thick * 1.9)
		out.set_shader_parameter("outline_color", Color(0.035, 0.022, 0.018, 1.0))
		mat.next_pass = out
	return mat


static func _apply_handdrawn_tankard_materials(glb_root: Node3D, accent_col: Color) -> void:
	var oak_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_oak_ink.png",
		Color(1.04, 0.98, 0.92), Color(0.14, 0.08, 0.06),
		0.90, 44.0, 0.14, 20.0, 0.32, 0.0011, Vector2.ONE, 0.82
	)
	var brass_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_brass_ink.png",
		Color(1.06, 0.98, 0.86), Color(0.22, 0.14, 0.08),
		0.68, 52.0, 0.72, 26.0, 0.56, 0.0009, Vector2.ONE, 0.80
	)
	var handle_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_oak_ink.png",
		Color(0.84, 0.74, 0.64), Color(0.12, 0.07, 0.05),
		0.95, 36.0, 0.18, 22.0, 0.36, 0.0011, Vector2(0.5, 1.2), 0.75
	)
	var crest_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_crest_ink.png",
		Color(1.04, 1.0, 0.96), Color(0.18, 0.10, 0.08),
		0.45, 38.0, 0.42, 28.0, 0.42, 0.0009, Vector2.ONE, 0.72
	)
	var foam_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_foam_ink.png",
		Color(1.04, 1.01, 0.96), Color(0.32, 0.24, 0.16),
		0.42, 34.0, 0.28, 16.0, 0.48, 0.0010, Vector2.ONE, 0.65,
		Color(accent_col.r * 0.04, accent_col.g * 0.04, accent_col.b * 0.02)
	)
	var ale_mat := _make_handdrawn_mat(
		"", Color(0.84, 0.44, 0.08), Color(0.24, 0.09, 0.02),
		0.35, 32.0, 0.95, 42.0, 0.50, 0.0005, Vector2.ONE, 0.45,
		Color(0.18, 0.08, 0.01)
	)

	var stack: Array[Node] = [glb_root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back() as Node
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var nm := mi.name
			if "OakStaves" in nm:
				mi.material_override = oak_mat
			elif "BrassHoops" in nm:
				mi.material_override = brass_mat
			elif "ScrollHandle" in nm:
				mi.material_override = handle_mat
			elif "HeraldicCrest" in nm:
				mi.material_override = crest_mat
			elif "AleFoam" in nm:
				mi.material_override = foam_mat
			elif "AleLiquid" in nm or "SpilledAle" in nm:
				mi.material_override = ale_mat
		for ch in cur.get_children():
			stack.append(ch)


static func _apply_handdrawn_coaster(root: Node3D) -> void:
	var oak_base := _make_handdrawn_mat(
		"res://assets/table/wood.png", Color(0.28, 0.18, 0.12), Color(0.06, 0.04, 0.03),
		0.88, 38.0, 0.10, 16.0, 0.20, 0.0009, Vector2(2.0, 2.0), 0.72
	)
	var brass_trim := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_brass_ink.png", Color(0.76, 0.62, 0.42), Color(0.14, 0.09, 0.05),
		0.70, 48.0, 0.48, 22.0, 0.34, 0.0008, Vector2.ONE, 0.62
	)
	var children := root.get_children()
	if children.size() >= 2:
		if children[0] is MeshInstance3D:
			(children[0] as MeshInstance3D).material_override = oak_base
		if children[1] is MeshInstance3D:
			(children[1] as MeshInstance3D).material_override = brass_trim


static func _apply_handdrawn_relic_materials(rel_id: String, glb_root: Node3D, accent_col: Color) -> void:
	var brass_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_brass_ink.png",
		Color(1.04, 0.96, 0.84), Color(0.22, 0.14, 0.08),
		0.64, 50.0, 0.72, 26.0, 0.56, 0.00085, Vector2.ONE, 0.78
	)
	var ivory_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/dice_ivory_ink.png",
		Color(1.04, 1.00, 0.92), Color(0.32, 0.24, 0.16),
		0.52, 44.0, 0.26, 20.0, 0.44, 0.00095, Vector2.ONE, 0.80
	)
	var leather_dice_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/dice_leather_ink.png",
		Color(0.94, 0.84, 0.76), Color(0.14, 0.08, 0.06),
		0.84, 38.0, 0.14, 18.0, 0.30, 0.00095, Vector2.ONE, 0.82
	)
	var pip_mat := _make_handdrawn_mat(
		"", Color(0.10, 0.07, 0.06), Color(0.03, 0.02, 0.02),
		0.20, 28.0, 0.20, 16.0, 0.25, 0.00045, Vector2.ONE, 0.50,
		Color(accent_col.r * 0.18, accent_col.g * 0.12, accent_col.b * 0.06)
	)
	var slate_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/rune_slate_ink.png",
		Color(0.96, 0.98, 1.04), Color(0.10, 0.11, 0.14),
		0.88, 42.0, 0.20, 18.0, 0.42, 0.00095, Vector2.ONE, 0.84
	)
	var rune_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/rune_glyph_ink.png",
		Color(0.74, 0.96, 1.0), Color(0.14, 0.42, 0.58),
		0.24, 30.0, 0.78, 32.0, 0.75, 0.00055, Vector2.ONE, 0.35,
		Color(0.24, 0.76, 0.98)
	)
	var copper_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_brass_ink.png",
		Color(0.92, 0.56, 0.34), Color(0.24, 0.10, 0.06),
		0.65, 46.0, 0.68, 24.0, 0.52, 0.00080, Vector2.ONE, 0.76
	)
	var silver_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/goblet_silver_ink.png",
		Color(0.88, 0.84, 0.78), Color(0.10, 0.08, 0.09),
		0.76, 54.0, 0.82, 28.0, 0.56, 0.00085, Vector2.ONE, 0.88
	)
	var ruby_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/blood_wine_ink.png",
		Color(1.06, 0.32, 0.36), Color(0.28, 0.04, 0.06),
		0.25, 28.0, 0.95, 36.0, 0.72, 0.00055, Vector2.ONE, 0.45,
		Color(0.55, 0.08, 0.10)
	)
	var wine_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/blood_wine_ink.png",
		Color(0.96, 0.24, 0.26), Color(0.22, 0.03, 0.04),
		0.30, 32.0, 0.92, 34.0, 0.54, 0.00060, Vector2.ONE, 0.52,
		Color(0.28, 0.04, 0.05)
	)
	var cradle_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/tankard_oak_ink.png",
		Color(0.84, 0.72, 0.62), Color(0.12, 0.07, 0.05),
		0.88, 38.0, 0.14, 18.0, 0.30, 0.00095, Vector2(0.8, 0.8), 0.82
	)
	var whet_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/whetstone_granite_ink.png",
		Color(1.00, 0.98, 0.94), Color(0.18, 0.17, 0.16),
		0.86, 46.0, 0.22, 20.0, 0.36, 0.00095, Vector2.ONE, 0.82
	)
	var steel_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/forged_steel_ink.png",
		Color(1.02, 1.04, 1.08), Color(0.22, 0.24, 0.30),
		0.54, 50.0, 0.90, 34.0, 0.62, 0.00075, Vector2.ONE, 0.76
	)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_mat.albedo_color = Color(0.78, 0.92, 0.98, 0.28)
	if ResourceLoader.exists("res://assets/textures/relics/hourglass_glass_ink.png"):
		glass_mat.albedo_texture = load("res://assets/textures/relics/hourglass_glass_ink.png") as Texture2D
	glass_mat.roughness = 0.08
	glass_mat.metallic = 0.16
	glass_mat.rim_enabled = true
	glass_mat.rim = 0.85
	glass_mat.rim_tint = 0.45
	glass_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var sand_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/gold_sand_ink.png",
		Color(1.04, 0.94, 0.68), Color(0.38, 0.24, 0.08),
		0.56, 38.0, 0.46, 22.0, 0.42, 0.00065, Vector2.ONE, 0.72,
		Color(0.24, 0.16, 0.04)
	)
	var purse_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/purse_leather_ink.png",
		Color(1.02, 0.92, 0.84), Color(0.18, 0.09, 0.06),
		0.84, 38.0, 0.18, 18.0, 0.34, 0.00095, Vector2.ONE, 0.84
	)
	var coin_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/florin_gold_ink.png",
		Color(1.06, 0.98, 0.74), Color(0.32, 0.20, 0.06),
		0.50, 48.0, 0.88, 30.0, 0.60, 0.00065, Vector2.ONE, 0.72,
		Color(0.16, 0.11, 0.02)
	)
	var timber_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/gallows_oak_ink.png",
		Color(0.92, 0.86, 0.78), Color(0.10, 0.07, 0.04),
		0.90, 42.0, 0.12, 16.0, 0.28, 0.00095, Vector2.ONE, 0.86
	)
	var iron_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/forged_steel_ink.png",
		Color(0.42, 0.44, 0.48), Color(0.08, 0.08, 0.10),
		0.72, 46.0, 0.56, 24.0, 0.46, 0.00080, Vector2.ONE, 0.82
	)
	var bronze_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/cracked_bronze_ink.png",
		Color(1.02, 0.96, 0.86), Color(0.16, 0.16, 0.14),
		0.72, 46.0, 0.62, 24.0, 0.52, 0.00085, Vector2.ONE, 0.80
	)
	var coal_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/ember_coal_ink.png",
		Color(1.05, 0.88, 0.72), Color(0.22, 0.06, 0.04),
		0.52, 34.0, 0.45, 20.0, 0.50, 0.00060, Vector2.ONE, 0.65,
		Color(0.75, 0.24, 0.04)
	)
	var ebony_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/reliquary_ebony_ink.png",
		Color(0.96, 0.88, 0.84), Color(0.08, 0.06, 0.06),
		0.86, 42.0, 0.24, 20.0, 0.38, 0.00095, Vector2.ONE, 0.84
	)
	var plume_mat := _make_handdrawn_mat(
		"res://assets/textures/relics/ember_plume_ink.png",
		Color(1.08, 0.94, 0.80), Color(0.36, 0.08, 0.04),
		0.40, 34.0, 0.70, 26.0, 0.72, 0.00065, Vector2.ONE, 0.52,
		Color(0.68, 0.22, 0.04)
	)

	var stack: Array[Node] = [glb_root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back() as Node
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var nm: String = str(mi.name)
			if "CupRim" in nm or "LeatherStrop" in nm:
				mi.material_override = leather_dice_mat
			elif "BoneDice" in nm:
				mi.material_override = ivory_mat
			elif "PipBowls" in nm:
				mi.material_override = pip_mat
			elif "Brass" in nm or "DaggerGuard" in nm or "DrawstringCord" in nm:
				mi.material_override = brass_mat
			elif "SlateMonolith" in nm or "RuneShard" in nm:
				mi.material_override = slate_mat
			elif "RuneGlyphs" in nm or "SoulClapper" in nm:
				mi.material_override = rune_mat
			elif "CopperWire" in nm:
				mi.material_override = copper_mat
			elif "GobletBody" in nm:
				mi.material_override = silver_mat
			elif "RubyGems" in nm or "WaxRibbon" in nm:
				mi.material_override = ruby_mat
			elif "WineDome" in nm:
				mi.material_override = wine_mat
			elif "TimberCradle" in nm:
				mi.material_override = cradle_mat
			elif "WhetstoneBlock" in nm:
				mi.material_override = whet_mat
			elif "SharpeningDagger" in nm:
				mi.material_override = steel_mat
			elif "GlassBulbs" in nm:
				mi.material_override = glass_mat
			elif "SandCones" in nm:
				mi.material_override = sand_mat
			elif "LeatherPouch" in nm:
				mi.material_override = purse_mat
			elif "GoldCoins" in nm:
				mi.material_override = coin_mat
			elif "GallowsPost" in nm:
				mi.material_override = timber_mat
			elif "IronBraces" in nm or "IronCrane" in nm or "CenserChains" in nm:
				mi.material_override = iron_mat
			elif "BronzeBell" in nm:
				mi.material_override = bronze_mat
			elif "EmberCoals" in nm:
				mi.material_override = coal_mat
			elif "ChestBody" in nm:
				mi.material_override = ebony_mat
			elif "PhoenixPlume" in nm:
				mi.material_override = plume_mat
			else:
				mi.material_override = brass_mat
		for ch in cur.get_children():
			stack.append(ch)
	if rel_id == "TRELIC_HOLLOW_MASK":
		pass

static func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale_v
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _cyl(top_r: float, bot_r: float, h: float, segs: int = 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = segs
	return m

static func _box(sz: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = sz
	return m

static func _sph(r: float, h: float = -1.0, segs: int = 14) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h if h > 0.0 else r * 2.0
	m.radial_segments = segs
	m.rings = 8
	return m

static func _tor(in_r: float, out_r: float, segs: int = 20) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = in_r
	m.outer_radius = out_r
	m.rings = segs
	m.ring_segments = 10
	return m

static func _prism(sz: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = sz
	return m

static func _mats(accent_col: Color) -> Dictionary:
	return {
		"brass": Toon.pbr(Color(0.86, 0.66, 0.24), "", 0.26, 0.88),
		"copper": Toon.pbr(Color(0.76, 0.41, 0.22), "", 0.30, 0.84),
		"iron": Toon.pbr(Color(0.20, 0.21, 0.24), "", 0.44, 0.76),
		"steel": Toon.pbr(Color(0.74, 0.78, 0.84), "", 0.24, 0.90),
		"wood": Toon.pbr(Color(0.40, 0.26, 0.16), "res://assets/table/wood.png", 0.56, 0.05),
		"walnut": Toon.pbr(Color(0.22, 0.14, 0.09), "res://assets/table/wood.png", 0.58, 0.05),
		"leather": Toon.pbr(Color(0.32, 0.18, 0.11), "res://assets/gloves/glove_leather.png", 0.66, 0.04),
		"ivory": Toon.pbr(Color(0.90, 0.84, 0.70), "", 0.42, 0.05),
		"parchment": Toon.pbr(Color(0.88, 0.82, 0.66), "", 0.72, 0.02),
		"wax": Toon.pbr(Color(0.64, 0.10, 0.12), "", 0.34, 0.08, Vector2.ONE, Color(0.22, 0.02, 0.02), 0.3),
		"cloth_red": Toon.pbr(Color(0.56, 0.14, 0.14), "", 0.74, 0.04),
		"cloth_green": Toon.pbr(Color(0.18, 0.44, 0.22), "", 0.68, 0.04),
		"stone": Toon.pbr(Color(0.34, 0.33, 0.32), "", 0.78, 0.06),
		"glow": Toon.pbr(accent_col.lightened(0.28), "", 0.18, 0.15, Vector2.ONE, accent_col, 1.9),
		"amber_glow": Toon.pbr(Color(1.0, 0.64, 0.18), "", 0.18, 0.10, Vector2.ONE, Color(1.0, 0.48, 0.10), 2.1),
		"azure_glow": Toon.pbr(Color(0.45, 0.86, 1.0), "", 0.16, 0.15, Vector2.ONE, Color(0.28, 0.72, 1.0), 2.2),
		"dark": Toon.pbr(Color(0.08, 0.06, 0.05), "", 0.70, 0.10),
	}


# ==============================================================================
# 1. ALL 24 SCULPTED 3D TABLE RELICS
# ==============================================================================

static func build_relic_3d_mesh(rel_id: String, accent_col: Color) -> Node3D:
	var root := Node3D.new()
	var m := _mats(accent_col)
	var brass: Material = m["brass"]
	var copper: Material = m["copper"]
	var iron: Material = m["iron"]
	var steel: Material = m["steel"]
	var wood: Material = m["wood"]
	var walnut: Material = m["walnut"]
	var leather: Material = m["leather"]
	var ivory: Material = m["ivory"]
	var parchment: Material = m["parchment"]
	var wax: Material = m["wax"]
	var cloth_red: Material = m["cloth_red"]
	var cloth_green: Material = m["cloth_green"]
	var stone: Material = m["stone"]
	var glow: Material = m["glow"]
	var amber_glow: Material = m["amber_glow"]
	var azure_glow: Material = m["azure_glow"]
	var dark: Material = m["dark"]

	# Ornate octagonal walnut & inlaid-brass pedestal base
	_add_part(root, _cyl(0.044, 0.052, 0.016, 8), Vector3(0.0, 0.008, 0.0), Vector3.ZERO, walnut)
	_add_part(root, _cyl(0.046, 0.046, 0.004, 8), Vector3(0.0, 0.018, 0.0), Vector3.ZERO, brass)

	# Glowing emissive ring indicating active tabletop invoke availability
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = accent_col.lightened(0.35)
	halo_mat.emission_enabled = true
	halo_mat.emission = accent_col
	halo_mat.emission_energy_multiplier = 1.45
	halo_mat.roughness = 0.25
	var halo_mi := _add_part(root, _tor(0.042, 0.049, 24), Vector3(0.0, 0.019, 0.0), Vector3.ZERO, halo_mat)
	halo_mi.name = "ReadyHalo"

	var sp := Node3D.new()
	sp.name = "SpinPivot"
	sp.position = Vector3(0.0, 0.020, 0.0)
	root.add_child(sp)

	# First check our Hand-Drawn Sculpted 10 Tabletop Relics (with ink outline + living 3D FX!)
	if rel_id in HANDDRAWN_TRELIC_IDS:
		var hd_glb := _load_glb("res://assets/models/relics/%s.glb" % rel_id)
		if hd_glb != null:
			hd_glb.name = "HandDrawnRelicGLB_%s" % rel_id
			_apply_handdrawn_relic_materials(rel_id, hd_glb, accent_col)
			sp.add_child(hd_glb)
			var lfx := RelicLivingFxScript.new()
			lfx.name = "RelicLivingFx"
			lfx.setup_for_relic(rel_id, hd_glb, accent_col)
			sp.add_child(lfx)
			root.set_meta("handdrawn_3d", true)
			halo_mi.mesh = _tor(0.0435, 0.0462, 32)
			halo_mat.emission_energy_multiplier = 0.52
			_apply_handdrawn_coaster(root)
			return root

	var handled_hand_drawn := true
	match rel_id:
		"TRELIC_WAR_HORN":
			var tankard_glb := _load_glb("res://assets/models/relics/TRELIC_WAR_HORN.glb")
			if tankard_glb != null:
				tankard_glb.name = "HandDrawnTankardGLB"
				_apply_handdrawn_tankard_materials(tankard_glb, accent_col)
				sp.add_child(tankard_glb)
				var bfx := TankardBubblesFxScript.new()
				bfx.name = "TankardBubblesFx"
				bfx.setup_for_tankard(tankard_glb)
				sp.add_child(bfx)
				root.set_meta("handdrawn_3d", true)
				halo_mi.mesh = _tor(0.0435, 0.0462, 32)
				halo_mat.emission_energy_multiplier = 0.52
				_apply_handdrawn_coaster(root)
				return root
			# Fallback oak staves prototype
			_add_part(sp, _cyl(0.026, 0.031, 0.078, 16), Vector3(-0.004, 0.039, 0.0), Vector3.ZERO, wood)
			for hy in [0.016, 0.062]:
				_add_part(sp, _cyl(0.0315, 0.0315, 0.009, 16), Vector3(-0.004, hy, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _tor(0.015, 0.022, 14), Vector3(0.031, 0.040, 0.0), Vector3(0.0, 0.0, 90.0), wood)
			_add_part(sp, _box(Vector3(0.018, 0.024, 0.005)), Vector3(-0.004, 0.040, 0.030), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.024, 0.024, 0.012, 16), Vector3(-0.004, 0.078, 0.0), Vector3.ZERO, ivory)
			for fm in [[0.0, 0.0, 0.017], [-0.012, 0.009, 0.013], [0.012, -0.008, 0.012], [0.005, 0.014, 0.011], [0.020, 0.004, 0.008]]:
				_add_part(sp, _sph(float(fm[2])), Vector3(-0.004 + float(fm[0]), 0.083, float(fm[1])), Vector3.ZERO, ivory)
		"TRELIC_HOLLOW_MASK":
			# Loaded Bone Dice (angled twin ivory dice with carved ink pips + brass corner inlay)
			var bone_mat := Toon.pbr(Color(0.94, 0.88, 0.74), "", 0.40, 0.04)
			for di in range(2):
				var dp := Vector3(-0.014 + float(di) * 0.028, 0.024 + float(di) * 0.026, float(di) * 0.008 - 0.004)
				var dr := Vector3(14.0 * float(di), 22.0 + float(di) * 35.0, -12.0 * float(di))
				var die := _add_part(sp, _box(Vector3(0.032, 0.032, 0.032)), dp, dr, bone_mat)
				for pp in [[-0.008, -0.008], [0.008, 0.008], [0.0, 0.0], [-0.008, 0.008], [0.008, -0.008]]:
					_add_part(die, _cyl(0.0036, 0.0036, 0.002, 8), Vector3(float(pp[0]), 0.0165, float(pp[1])), Vector3.ZERO, glow)
				for fp in [[-0.007, -0.007], [0.007, 0.007]]:
					_add_part(die, _cyl(0.0036, 0.0036, 0.002, 8), Vector3(float(fp[0]), float(fp[1]), 0.0165), Vector3(90.0, 0.0, 0.0), dark)
		"TRELIC_STAR_BOW":
			# Arcane Slate Rune (cracked monolith + engraved glowing rune sigil + 3 floating shard stones)
			_add_part(sp, _box(Vector3(0.046, 0.082, 0.022)), Vector3(0.0, 0.044, 0.0), Vector3(-6.0, 12.0, 4.0), stone)
			_add_part(sp, _prism(Vector3(0.046, 0.028, 0.022)), Vector3(0.0, 0.098, -0.004), Vector3(-6.0, 12.0, 4.0), stone)
			_add_part(sp, _box(Vector3(0.008, 0.056, 0.025)), Vector3(0.0, 0.050, 0.0), Vector3(-6.0, 12.0, 4.0), azure_glow)
			_add_part(sp, _box(Vector3(0.030, 0.008, 0.025)), Vector3(0.0, 0.060, 0.0), Vector3(-6.0, 12.0, 32.0), azure_glow)
			_add_part(sp, _tor(0.034, 0.038, 20), Vector3(0.0, 0.055, 0.0), Vector3(72.0, 0.0, 16.0), azure_glow)
			for si in range(3):
				var sa := float(si) * (TAU / 3.0)
				_add_part(sp, _prism(Vector3(0.014, 0.024, 0.012)), Vector3(cos(sa) * 0.038, 0.058 + float(si) * 0.012, sin(sa) * 0.038), Vector3(12.0, rad_to_deg(sa), 0.0), stone)
		"TRELIC_BLOOD_SEAL":
			# Crimson Blood Goblet (ornate brass chalice + ruby gems + brimming crimson liquid + ink wax seal)
			_add_part(sp, _cyl(0.010, 0.028, 0.014, 14), Vector3(0.0, 0.007, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.007, 0.008, 0.036, 12), Vector3(0.0, 0.030, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.032, 0.014, 0.044, 16), Vector3(0.0, 0.068, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.028, 0.028, 0.006, 16), Vector3(0.0, 0.088, 0.0), Vector3.ZERO, wax)
			for gi in range(4):
				var ga := float(gi) * (PI * 0.5)
				_add_part(sp, _sph(0.006), Vector3(cos(ga) * 0.026, 0.072, sin(ga) * 0.026), Vector3.ZERO, glow)
		"TRELIC_IRON_CHAIN":
			# Executioner's Whetstone (timber cradle + angled bevel whetstone + crossed sharpening dagger + sparks)
			_add_part(sp, _box(Vector3(0.064, 0.014, 0.040)), Vector3(0.0, 0.007, 0.0), Vector3.ZERO, walnut)
			_add_part(sp, _box(Vector3(0.058, 0.020, 0.032)), Vector3(0.0, 0.026, 0.0), Vector3(8.0, 12.0, -14.0), stone)
			_add_part(sp, _box(Vector3(0.010, 0.066, 0.004)), Vector3(-0.008, 0.056, 0.0), Vector3(0.0, 0.0, 34.0), steel)
			_add_part(sp, _box(Vector3(0.026, 0.006, 0.008)), Vector3(-0.024, 0.032, 0.0), Vector3(0.0, 0.0, 34.0), brass)
			_add_part(sp, _sph(0.005), Vector3(0.012, 0.042, 0.008), Vector3.ZERO, amber_glow)
		"TRELIC_ASH_GLASS":
			# Fate Hourglass (brass columns + twin glass bulbs + glowing golden sand cones)
			for py in [0.006, 0.092]:
				_add_part(sp, _cyl(0.032, 0.032, 0.008, 12), Vector3(0.0, py, 0.0), Vector3.ZERO, brass)
			for cx in [-0.022, 0.022]:
				_add_part(sp, _cyl(0.003, 0.003, 0.086, 8), Vector3(cx, 0.049, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.022, 0.004, 0.036, 14), Vector3(0.0, 0.070, 0.0), Vector3.ZERO, azure_glow)
			_add_part(sp, _cyl(0.004, 0.022, 0.036, 14), Vector3(0.0, 0.028, 0.0), Vector3.ZERO, glow)
		"TRELIC_GOLD_SCALES":
			# Guild Coin Purse (bulging stitched leather pouch + brass cord + overflowing stacks of gold coins)
			_add_part(sp, _sph(0.030, 0.044), Vector3(-0.014, 0.024, 0.0), Vector3.ZERO, leather)
			_add_part(sp, _tor(0.012, 0.016, 12), Vector3(-0.014, 0.046, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.018, 0.011, 0.018, 10), Vector3(-0.014, 0.056, 0.0), Vector3.ZERO, leather)
			for ci in range(8):
				_add_part(sp, _cyl(0.010, 0.010, 0.004, 12), Vector3(0.018 + float(ci % 2) * 0.012, 0.006 + float(ci / 2) * 0.0045, -0.006 + float(ci % 3) * 0.006), Vector3(0.0, float(ci) * 24.0, 0.0), brass)
		"TRELIC_SOUL_BELL":
			# Graveyard Toll Bell (oak gallows post + cracked bronze bell + glowing soul clapper)
			_add_part(sp, _box(Vector3(0.010, 0.096, 0.010)), Vector3(-0.024, 0.048, 0.0), Vector3.ZERO, walnut)
			_add_part(sp, _box(Vector3(0.054, 0.010, 0.010)), Vector3(0.0, 0.094, 0.0), Vector3.ZERO, walnut)
			_add_part(sp, _cyl(0.016, 0.028, 0.044, 14), Vector3(0.010, 0.060, 0.0), Vector3.ZERO, copper)
			_add_part(sp, _tor(0.026, 0.030, 14), Vector3(0.010, 0.040, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _sph(0.009), Vector3(0.010, 0.034, 0.0), Vector3.ZERO, azure_glow)
		"TRELIC_CENSER":
			# Alchemist's Ember Censer (brass tripod hook + perforated incense sphere + glowing coals)
			_add_part(sp, _cyl(0.003, 0.004, 0.104, 8), Vector3(-0.022, 0.052, 0.0), Vector3.ZERO, iron)
			_add_part(sp, _box(Vector3(0.044, 0.006, 0.006)), Vector3(-0.004, 0.102, 0.0), Vector3.ZERO, iron)
			_add_part(sp, _cyl(0.002, 0.002, 0.032, 6), Vector3(0.014, 0.086, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _sph(0.024, 0.028), Vector3(0.014, 0.054, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _sph(0.020, 0.020), Vector3(0.014, 0.054, 0.0), Vector3.ZERO, glow)
		"TRELIC_PHOENIX_BOX":
			# Phoenix Ember Reliquary (open brass chest + blazing crimson plume crest)
			_add_part(sp, _box(Vector3(0.058, 0.028, 0.038)), Vector3(0.0, 0.016, 0.0), Vector3.ZERO, walnut)
			_add_part(sp, _box(Vector3(0.060, 0.014, 0.036)), Vector3(0.0, 0.044, -0.018), Vector3(-38.0, 0.0, 0.0), copper)
			_add_part(sp, _sph(0.016, 0.024), Vector3(0.0, 0.034, 0.002), Vector3.ZERO, amber_glow)
			_add_part(sp, _prism(Vector3(0.028, 0.044, 0.012)), Vector3(0.0, 0.060, 0.004), Vector3(0.0, 15.0, 0.0), amber_glow)
		_:
			handled_hand_drawn = false

	if handled_hand_drawn:
		_apply_woodcut_ink_outline(root, 0.0045)
		return root

	var glb_rel := _load_glb("res://assets/models/relics/%s.glb" % rel_id)
	if glb_rel != null:
		sp.add_child(glb_rel)
		_apply_woodcut_ink_outline(root, 0.0045)
		root.set_meta("blender_glb", true)
		return root

	match rel_id:
		"REL_CHAMOIS":
			# Curved 6-segment Alpine Chamois horn with brass ferrules & suspension rings
			var pts: Array[Vector3] = [
				Vector3(-0.026, 0.018, 0.0), Vector3(-0.010, 0.024, 0.0),
				Vector3(0.008, 0.036, 0.0), Vector3(0.020, 0.056, 0.0),
				Vector3(0.022, 0.080, 0.0), Vector3(0.014, 0.102, 0.0),
			]
			var radii: Array[float] = [0.018, 0.016, 0.013, 0.010, 0.007, 0.0045]
			var rots: Array[float] = [-72.0, -56.0, -34.0, -14.0, 8.0, 28.0]
			for i in range(pts.size()):
				var hr: float = radii[i]
				var nr: float = radii[mini(i + 1, radii.size() - 1)] * 0.85
				_add_part(sp, _cyl(nr, hr, 0.028, 12), pts[i], Vector3(0.0, 0.0, rots[i]), leather if i < 4 else ivory)
			_add_part(sp, _tor(0.016, 0.021, 16), Vector3(-0.028, 0.016, 0.0), Vector3(0.0, 0.0, 18.0), brass)
			_add_part(sp, _cyl(0.0145, 0.0145, 0.010, 14), Vector3(0.008, 0.036, 0.0), Vector3(0.0, 0.0, -34.0), brass)
			_add_part(sp, _cyl(0.008, 0.008, 0.009, 12), Vector3(0.022, 0.080, 0.0), Vector3(0.0, 0.0, 8.0), copper)
			_add_part(sp, _tor(0.006, 0.009, 12), Vector3(0.022, 0.058, 0.012), Vector3(90.0, 0.0, 0.0), brass)

		"REL_FUJARA":
			# Carved walnut Carpathian Fujara bass pipe + parallel side blowtube + copper rings
			_add_part(sp, _cyl(0.009, 0.013, 0.140, 12), Vector3(0.006, 0.072, 0.0), Vector3(0.0, 0.0, -18.0), wood)
			_add_part(sp, _cyl(0.005, 0.006, 0.105, 10), Vector3(-0.008, 0.076, 0.0), Vector3(0.0, 0.0, -18.0), wood)
			for t_y in [0.024, 0.062, 0.104, 0.130]:
				_add_part(sp, _cyl(0.0125, 0.0125, 0.007, 12), Vector3(-0.014 + t_y * 0.30, t_y, 0.0), Vector3(0.0, 0.0, -18.0), copper)
			for hi in range(3):
				var hy: float = 0.042 + float(hi) * 0.015
				_add_part(sp, _cyl(0.0028, 0.0028, 0.004, 8), Vector3(-0.004 + hy * 0.30, hy, 0.010), Vector3(90.0, 0.0, 0.0), dark)
			_add_part(sp, _tor(0.009, 0.012, 14), Vector3(0.026, 0.138, 0.0), Vector3(0.0, 0.0, -18.0), brass)

		"REL_STORMCAP":
			# Leyden capacitor jar with copper coil windings, azure plasma glass & brass crown orb
			_add_part(sp, _cyl(0.028, 0.032, 0.014, 14), Vector3(0.0, 0.007, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.024, 0.024, 0.068, 16), Vector3(0.0, 0.048, 0.0), Vector3.ZERO, azure_glow)
			for cy in [0.024, 0.036, 0.048]:
				_add_part(sp, _tor(0.021, 0.027, 18), Vector3(0.0, cy, 0.0), Vector3.ZERO, copper)
			_add_part(sp, _cyl(0.027, 0.027, 0.010, 14), Vector3(0.0, 0.084, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.004, 0.004, 0.032, 10), Vector3(0.0, 0.104, 0.0), Vector3.ZERO, copper)
			_add_part(sp, _sph(0.014), Vector3(0.0, 0.122, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _box(Vector3(0.056, 0.004, 0.004)), Vector3(0.0, 0.114, 0.0), Vector3(0.0, 0.0, 22.0), azure_glow)

		"REL_KNUCKLE":
			# Carved ivory 4-lobe knucklebone astragalus + weighted gilded brass die
			_add_part(sp, _box(Vector3(0.034, 0.050, 0.024)), Vector3(-0.008, 0.036, 0.0), Vector3(12.0, 22.0, -10.0), ivory)
			for dx in [-0.014, 0.014]:
				for dy in [-0.018, 0.018]:
					_add_part(sp, _sph(0.012), Vector3(-0.008 + dx, 0.036 + dy, 0.0), Vector3.ZERO, ivory)
			_add_part(sp, _sph(0.009), Vector3(-0.008, 0.036, 0.012), Vector3.ZERO, brass)
			_add_part(sp, _box(Vector3(0.024, 0.024, 0.024)), Vector3(0.024, 0.072, 0.008), Vector3(26.0, 40.0, 18.0), brass)
			_add_part(sp, _sph(0.0038), Vector3(0.024, 0.072, 0.020), Vector3.ZERO, wax)

		"REL_PHOENIX_F":
			# Iron inkwell holding tall arched crimson & gold layered phoenix plume
			_add_part(sp, _cyl(0.014, 0.022, 0.024, 8), Vector3(-0.012, 0.012, 0.0), Vector3.ZERO, iron)
			_add_part(sp, _cyl(0.003, 0.002, 0.122, 8), Vector3(0.006, 0.068, 0.0), Vector3(0.0, 0.0, -20.0), brass)
			for i in range(5):
				var t: float = float(i) / 4.0
				var vy: float = 0.044 + t * 0.066
				var vx: float = -0.003 + t * 0.024
				var w_v: float = 0.032 - absf(t - 0.5) * 0.016
				_add_part(sp, _box(Vector3(w_v, 0.022, 0.004)), Vector3(vx, vy, 0.0), Vector3(0.0, 8.0, -24.0), cloth_red if i < 3 else amber_glow)
			_add_part(sp, _sph(0.008), Vector3(0.028, 0.126, 0.0), Vector3.ZERO, amber_glow)

		"REL_FANG":
			# Curved beast ivory fang socketed in riveted iron collar + glowing crimson blood drop
			_add_part(sp, _cyl(0.018, 0.020, 0.032, 8), Vector3(-0.014, 0.098, 0.0), Vector3(0.0, 0.0, 26.0), iron)
			_add_part(sp, _cyl(0.019, 0.019, 0.008, 8), Vector3(-0.010, 0.084, 0.0), Vector3(0.0, 0.0, 26.0), brass)
			_add_part(sp, _tor(0.007, 0.010, 12), Vector3(-0.022, 0.120, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.015, 0.011, 0.042, 12), Vector3(-0.002, 0.064, 0.0), Vector3(0.0, 0.0, 22.0), ivory)
			_add_part(sp, _cyl(0.011, 0.006, 0.038, 12), Vector3(0.014, 0.036, 0.0), Vector3(0.0, 0.0, 38.0), ivory)
			_add_part(sp, _cyl(0.006, 0.001, 0.026, 10), Vector3(0.028, 0.016, 0.0), Vector3(0.0, 0.0, 56.0), ivory)
			_add_part(sp, _sph(0.007, 0.020), Vector3(0.034, 0.009, 0.008), Vector3.ZERO, glow)

		"REL_GREED":
			# Brass balance scales with coin-filled pan & ruby counterweight pan
			_add_part(sp, _cyl(0.016, 0.024, 0.012, 12), Vector3(0.0, 0.006, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.004, 0.006, 0.106, 10), Vector3(0.0, 0.058, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _sph(0.007), Vector3(0.0, 0.114, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _box(Vector3(0.088, 0.006, 0.006)), Vector3(0.0, 0.104, 0.0), Vector3(0.0, 0.0, 8.0), brass)
			for side in [-1.0, 1.0]:
				var px: float = side * 0.039
				var py: float = 0.056 + side * 0.006
				_add_part(sp, _cyl(0.0015, 0.0015, 0.044, 6), Vector3(px - 0.010, py + 0.022, 0.0), Vector3(0.0, 0.0, -14.0), iron)
				_add_part(sp, _cyl(0.0015, 0.0015, 0.044, 6), Vector3(px + 0.010, py + 0.022, 0.0), Vector3(0.0, 0.0, 14.0), iron)
				_add_part(sp, _cyl(0.017, 0.011, 0.008, 12), Vector3(px, py, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.008, 0.008, 0.012, 10), Vector3(-0.039, 0.056, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _sph(0.008), Vector3(0.039, 0.068, 0.0), Vector3.ZERO, glow)

		"REL_ALEMBIC":
			# Iron tripod + ember brazier + glowing copper alembic retort + receiver flask
			for ang_y in [0.0, 120.0, 240.0]:
				var r_a: float = deg_to_rad(ang_y)
				_add_part(sp, _cyl(0.003, 0.003, 0.044, 6), Vector3(cos(r_a) * 0.019, 0.020, sin(r_a) * 0.019), Vector3(0.0, ang_y, 20.0), iron)
			_add_part(sp, _sph(0.014, 0.014), Vector3(-0.006, 0.012, 0.0), Vector3.ZERO, amber_glow)
			_add_part(sp, _sph(0.026, 0.046), Vector3(-0.006, 0.054, 0.0), Vector3.ZERO, copper)
			_add_part(sp, _sph(0.017, 0.030), Vector3(-0.006, 0.088, 0.0), Vector3.ZERO, amber_glow)
			_add_part(sp, _cyl(0.020, 0.020, 0.007, 12), Vector3(-0.006, 0.072, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.005, 0.007, 0.048, 10), Vector3(0.016, 0.076, 0.0), Vector3(0.0, 0.0, -56.0), copper)
			_add_part(sp, _sph(0.013), Vector3(0.030, 0.018, 0.0), Vector3.ZERO, amber_glow)

		"REL_ROYAL":
			# Dark crimson cushion tray supporting heavy gold royal signet ring with ruby
			_add_part(sp, _cyl(0.036, 0.040, 0.006, 16), Vector3(0.0, 0.004, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _sph(0.030, 0.024), Vector3(0.0, 0.016, 0.0), Vector3.ZERO, cloth_red)
			_add_part(sp, _tor(0.022, 0.030, 20), Vector3(0.0, 0.054, 0.0), Vector3(72.0, 18.0, 0.0), brass)
			_add_part(sp, _box(Vector3(0.024, 0.026, 0.018)), Vector3(0.0, 0.080, -0.006), Vector3(-18.0, 0.0, 0.0), brass)
			_add_part(sp, _sph(0.011, 0.016), Vector3(0.0, 0.082, 0.004), Vector3.ZERO, glow)

		"REL_CHRONO_P":
			# Twin brass clock pillars, ivory dial ring, cog wheel & swinging bob pendulum
			for sx in [-0.024, 0.024]:
				_add_part(sp, _cyl(0.0045, 0.0055, 0.112, 10), Vector3(sx, 0.056, 0.0), Vector3.ZERO, brass)
				_add_part(sp, _sph(0.007), Vector3(sx, 0.116, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _box(Vector3(0.062, 0.010, 0.020)), Vector3(0.0, 0.108, 0.0), Vector3.ZERO, wood)
			_add_part(sp, _cyl(0.026, 0.026, 0.012, 18), Vector3(0.0, 0.082, 0.0), Vector3(90.0, 0.0, 0.0), brass)
			_add_part(sp, _cyl(0.021, 0.021, 0.014, 18), Vector3(0.0, 0.082, 0.0), Vector3(90.0, 0.0, 0.0), ivory)
			_add_part(sp, _cyl(0.002, 0.002, 0.058, 6), Vector3(0.008, 0.044, 0.004), Vector3(0.0, 0.0, 14.0), brass)
			_add_part(sp, _cyl(0.013, 0.013, 0.007, 14), Vector3(0.014, 0.018, 0.004), Vector3(90.0, 0.0, 14.0), copper)

		"REL_PRISM_ORB":
			# Brass armillary rings orbiting faceted glowing astral octahedron
			_add_part(sp, _cyl(0.005, 0.016, 0.028, 10), Vector3(0.0, 0.014, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _tor(0.034, 0.039, 22), Vector3(0.0, 0.070, 0.0), Vector3(68.0, 0.0, 0.0), brass)
			_add_part(sp, _tor(0.028, 0.032, 20), Vector3(0.0, 0.070, 0.0), Vector3(24.0, 48.0, 56.0), copper)
			_add_part(sp, _tor(0.022, 0.025, 18), Vector3(0.0, 0.070, 0.0), Vector3(-42.0, -32.0, 28.0), brass)
			_add_part(sp, _prism(Vector3(0.030, 0.036, 0.030)), Vector3(0.0, 0.082, 0.0), Vector3.ZERO, glow)
			_add_part(sp, _prism(Vector3(0.030, 0.036, 0.030)), Vector3(0.0, 0.056, 0.0), Vector3(180.0, 0.0, 0.0), glow)

		"REL_HEX_DOLL":
			# Stitched burlap voodoo effigy with cloth heart patch & protruding brass pins
			_add_part(sp, _cyl(0.016, 0.020, 0.048, 10), Vector3(0.0, 0.056, 0.0), Vector3.ZERO, parchment)
			_add_part(sp, _sph(0.021), Vector3(0.0, 0.098, 0.0), Vector3.ZERO, parchment)
			_add_part(sp, _cyl(0.006, 0.007, 0.068, 8), Vector3(0.0, 0.066, 0.0), Vector3(0.0, 0.0, 90.0), parchment)
			for lx in [-0.010, 0.010]:
				_add_part(sp, _cyl(0.007, 0.006, 0.034, 8), Vector3(lx, 0.019, 0.0), Vector3(0.0, 0.0, lx * 320.0), parchment)
			_add_part(sp, _sph(0.009, 0.012), Vector3(0.0, 0.060, 0.014), Vector3.ZERO, wax)
			for pin_d in [[Vector3(0.018, 0.072, 0.014), Vector3(20.0, 0.0, -48.0)], [Vector3(-0.016, 0.104, 0.012), Vector3(14.0, 0.0, 42.0)], [Vector3(0.012, 0.044, 0.018), Vector3(-18.0, 0.0, -34.0)]]:
				var p_pos: Vector3 = pin_d[0]
				var p_rot: Vector3 = pin_d[1]
				_add_part(sp, _cyl(0.0012, 0.0012, 0.036, 6), p_pos, p_rot, steel)
				_add_part(sp, _sph(0.0042), p_pos + Vector3(0.006 * signf(p_pos.x), 0.012, 0.004), Vector3.ZERO, glow)

		"REL_IRON_BOOT":
			# Articulated steel knight sabaton & fluted greave with brass straps
			_add_part(sp, _cyl(0.018, 0.016, 0.072, 12), Vector3(-0.010, 0.056, 0.0), Vector3(0.0, 0.0, 4.0), steel)
			_add_part(sp, _sph(0.022), Vector3(-0.010, 0.098, 0.004), Vector3.ZERO, steel)
			_add_part(sp, _box(Vector3(0.052, 0.026, 0.032)), Vector3(0.008, 0.016, 0.0), Vector3(0.0, 0.0, -4.0), iron)
			_add_part(sp, _sph(0.018, 0.024), Vector3(0.030, 0.016, 0.0), Vector3(0.0, 0.0, 90.0), brass)
			for sy in [0.044, 0.066]:
				_add_part(sp, _cyl(0.0195, 0.0195, 0.008, 12), Vector3(-0.010, sy, 0.0), Vector3.ZERO, leather)
				_add_part(sp, _box(Vector3(0.008, 0.012, 0.006)), Vector3(-0.008, sy, 0.020), Vector3.ZERO, brass)

		"REL_OVERCHARGE":
			# Tatra granite plinth & tapered copper lightning spire with azure arcs
			_add_part(sp, _cyl(0.026, 0.038, 0.024, 8), Vector3(0.0, 0.012, 0.0), Vector3.ZERO, stone)
			_add_part(sp, _cyl(0.006, 0.018, 0.088, 10), Vector3(0.0, 0.066, 0.0), Vector3.ZERO, copper)
			for ring_d in [[0.046, 0.024], [0.068, 0.019], [0.090, 0.015]]:
				var dy: float = ring_d[0]
				var dr: float = ring_d[1]
				_add_part(sp, _cyl(dr, dr, 0.006, 12), Vector3(0.0, dy, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _sph(0.015), Vector3(0.0, 0.118, 0.0), Vector3.ZERO, azure_glow)
			_add_part(sp, _tor(0.020, 0.023, 18), Vector3(0.0, 0.118, 0.0), Vector3(32.0, 22.0, 12.0), azure_glow)

		"REL_WOODCUTTER":
			# Timber chopping block + leaning bearded Carpathian woodcutter axe
			_add_part(sp, _cyl(0.026, 0.028, 0.028, 12), Vector3(-0.008, 0.014, 0.0), Vector3.ZERO, wood)
			_add_part(sp, _cyl(0.0045, 0.005, 0.132, 10), Vector3(0.0, 0.072, 0.0), Vector3(0.0, 0.0, -24.0), walnut)
			_add_part(sp, _box(Vector3(0.038, 0.044, 0.010)), Vector3(0.024, 0.092, 0.0), Vector3(0.0, 0.0, -24.0), iron)
			_add_part(sp, _box(Vector3(0.012, 0.052, 0.011)), Vector3(0.040, 0.088, 0.0), Vector3(0.0, 0.0, -18.0), steel)
			_add_part(sp, _cyl(0.010, 0.010, 0.018, 10), Vector3(0.018, 0.112, 0.0), Vector3(0.0, 0.0, -24.0), brass)

		"REL_FORGEMASTER":
			# Horned blacksmith anvil + glowing tally groove + crossed peen hammer
			_add_part(sp, _box(Vector3(0.068, 0.014, 0.034)), Vector3(0.0, 0.008, 0.0), Vector3.ZERO, iron)
			_add_part(sp, _box(Vector3(0.036, 0.026, 0.024)), Vector3(0.004, 0.026, 0.0), Vector3.ZERO, iron)
			_add_part(sp, _box(Vector3(0.062, 0.018, 0.032)), Vector3(0.006, 0.046, 0.0), Vector3.ZERO, steel)
			_add_part(sp, _cyl(0.002, 0.014, 0.032, 8), Vector3(-0.036, 0.046, 0.0), Vector3(0.0, 0.0, 90.0), iron)
			_add_part(sp, _box(Vector3(0.028, 0.006, 0.026)), Vector3(0.004, 0.028, 0.002), Vector3.ZERO, amber_glow)
			_add_part(sp, _cyl(0.004, 0.004, 0.072, 8), Vector3(0.014, 0.078, 0.0), Vector3(0.0, 0.0, -56.0), walnut)
			_add_part(sp, _box(Vector3(0.020, 0.028, 0.018)), Vector3(-0.004, 0.072, 0.0), Vector3(0.0, 0.0, -56.0), steel)

		"REL_RED_SEAL":
			# Crimson wax seal cake + rolled parchment corner + turned brass lion seal stamp
			_add_part(sp, _box(Vector3(0.056, 0.006, 0.046)), Vector3(0.0, 0.004, 0.0), Vector3(0.0, 12.0, 0.0), parchment)
			_add_part(sp, _cyl(0.030, 0.034, 0.010, 14), Vector3(0.0, 0.012, 0.0), Vector3.ZERO, wax)
			_add_part(sp, _tor(0.018, 0.024, 16), Vector3(0.0, 0.017, 0.0), Vector3.ZERO, wax)
			_add_part(sp, _box(Vector3(0.032, 0.012, 0.028)), Vector3(0.004, 0.032, -0.004), Vector3(-16.0, 15.0, 0.0), brass)
			_add_part(sp, _cyl(0.009, 0.014, 0.038, 10), Vector3(0.004, 0.056, -0.010), Vector3(-16.0, 0.0, 0.0), walnut)
			_add_part(sp, _sph(0.012), Vector3(0.004, 0.080, -0.016), Vector3.ZERO, brass)

		"REL_CRIMSON_CHOIR":
			# Carved medieval lyre with gilded bent arms, crossbar & 4 shimmering strings
			_add_part(sp, _box(Vector3(0.044, 0.022, 0.018)), Vector3(0.0, 0.016, 0.0), Vector3.ZERO, walnut)
			_add_part(sp, _sph(0.022, 0.018), Vector3(0.0, 0.026, 0.0), Vector3.ZERO, cloth_red)
			for sx in [-1.0, 1.0]:
				_add_part(sp, _cyl(0.005, 0.008, 0.078, 8), Vector3(sx * 0.024, 0.064, 0.0), Vector3(0.0, 0.0, -sx * 16.0), brass)
			_add_part(sp, _cyl(0.005, 0.005, 0.068, 10), Vector3(0.0, 0.104, 0.0), Vector3(0.0, 0.0, 90.0), walnut)
			for si in range(4):
				var str_x: float = -0.012 + float(si) * 0.008
				_add_part(sp, _cyl(0.001, 0.001, 0.078, 4), Vector3(str_x, 0.064, 0.0), Vector3.ZERO, glow)

		"REL_GREEN_CANOPY":
			# Braided woodland bough wreath studded with emerald leaves & twin brass acorns
			_add_part(sp, _tor(0.028, 0.036, 20), Vector3(0.0, 0.058, 0.0), Vector3(72.0, 0.0, 0.0), wood)
			for li in range(8):
				var a: float = float(li) * PI * 0.25
				var lx: float = cos(a) * 0.034
				var ly: float = 0.058 + sin(a) * 0.032
				_add_part(sp, _box(Vector3(0.016, 0.028, 0.004)), Vector3(lx, ly, 0.004), Vector3(12.0, 0.0, rad_to_deg(a) - 70.0), cloth_green)
			for ax in [-0.014, 0.014]:
				_add_part(sp, _sph(0.008, 0.016), Vector3(ax, 0.022, 0.012), Vector3.ZERO, copper)
				_add_part(sp, _cyl(0.009, 0.006, 0.006, 10), Vector3(ax, 0.028, 0.012), Vector3.ZERO, walnut)

		"REL_PRSI_PURIST":
			# Staved oak tavern tankard with brass hoops, shield crest & foaming ale crown
			_add_part(sp, _cyl(0.026, 0.030, 0.072, 14), Vector3(-0.004, 0.036, 0.0), Vector3.ZERO, wood)
			for hy in [0.018, 0.056]:
				_add_part(sp, _cyl(0.030, 0.030, 0.008, 14), Vector3(-0.004, hy, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _tor(0.014, 0.020, 14), Vector3(0.030, 0.038, 0.0), Vector3(0.0, 0.0, 90.0), brass)
			_add_part(sp, _box(Vector3(0.016, 0.022, 0.004)), Vector3(-0.004, 0.038, 0.028), Vector3.ZERO, brass)
			for foam_d in [[0.0, 0.0, 0.020], [-0.012, 0.008, 0.014], [0.010, -0.008, 0.013], [0.004, 0.012, 0.012]]:
				_add_part(sp, _sph(foam_d[2]), Vector3(-0.004 + foam_d[0], 0.074, foam_d[1]), Vector3.ZERO, ivory)

		"REL_SEVEN_GRIMOIRE":
			# Lectern stand holding open leather grimoire with gilded brass corners & VII sigil
			_add_part(sp, _cyl(0.018, 0.024, 0.024, 8), Vector3(0.0, 0.012, 0.0), Vector3.ZERO, walnut)
			_add_part(sp, _box(Vector3(0.068, 0.010, 0.054)), Vector3(0.0, 0.044, 0.0), Vector3(34.0, 0.0, 0.0), cloth_red)
			_add_part(sp, _box(Vector3(0.062, 0.012, 0.048)), Vector3(0.0, 0.050, 0.002), Vector3(34.0, 0.0, 0.0), parchment)
			for cx in [-0.030, 0.030]:
				for cz in [-0.020, 0.020]:
					_add_part(sp, _box(Vector3(0.010, 0.014, 0.010)), Vector3(cx, 0.048 + cz * 0.5, cz), Vector3(34.0, 0.0, 0.0), brass)
			_add_part(sp, _box(Vector3(0.018, 0.004, 0.026)), Vector3(0.0, 0.060, 0.005), Vector3(34.0, 0.0, 0.0), glow)

		"REL_MERCHANT_LEDGER":
			# Unrolled parchment ledger scroll between twin mahogany rods + crimson seal & golden quill
			_add_part(sp, _box(Vector3(0.058, 0.008, 0.054)), Vector3(0.0, 0.038, 0.0), Vector3(30.0, 0.0, 0.0), parchment)
			for rod_d in [[-0.024, 0.052], [0.024, 0.024]]:
				var rz: float = rod_d[0]
				var ry: float = rod_d[1]
				_add_part(sp, _cyl(0.008, 0.008, 0.072, 10), Vector3(0.0, ry, rz), Vector3(0.0, 0.0, 90.0), walnut)
				for rx in [-0.038, 0.038]:
					_add_part(sp, _sph(0.009), Vector3(rx, ry, rz), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.011, 0.011, 0.005, 10), Vector3(0.014, 0.036, 0.014), Vector3(30.0, 0.0, 0.0), wax)
			_add_part(sp, _cyl(0.002, 0.001, 0.068, 6), Vector3(0.026, 0.072, 0.0), Vector3(0.0, 0.0, -28.0), brass)

		"REL_FINAL_TOLL":
			# Cracked stone plinth + upright Executioner's Zweihander sword + scarlet oath ribbon
			_add_part(sp, _cyl(0.028, 0.034, 0.020, 7), Vector3(0.0, 0.010, 0.0), Vector3.ZERO, stone)
			_add_part(sp, _box(Vector3(0.014, 0.098, 0.004)), Vector3(0.0, 0.064, 0.0), Vector3.ZERO, steel)
			_add_part(sp, _box(Vector3(0.064, 0.008, 0.010)), Vector3(0.0, 0.112, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _cyl(0.005, 0.006, 0.034, 8), Vector3(0.0, 0.132, 0.0), Vector3.ZERO, leather)
			_add_part(sp, _sph(0.010), Vector3(0.0, 0.152, 0.0), Vector3.ZERO, brass)
			_add_part(sp, _box(Vector3(0.034, 0.012, 0.007)), Vector3(0.006, 0.068, 0.003), Vector3(0.0, 0.0, -22.0), wax)

		"REL_COURT_SOVEREIGN":
			# Iron-banded royal treasure chest open to reveal mounded gold ducats & ruby/sapphire gems
			_add_part(sp, _box(Vector3(0.068, 0.036, 0.044)), Vector3(0.0, 0.018, 0.004), Vector3.ZERO, walnut)
			for bx in [-0.022, 0.022]:
				_add_part(sp, _box(Vector3(0.008, 0.038, 0.048)), Vector3(bx, 0.019, 0.004), Vector3.ZERO, iron)
			_add_part(sp, _box(Vector3(0.068, 0.018, 0.042)), Vector3(0.0, 0.056, -0.022), Vector3(-42.0, 0.0, 0.0), cloth_red)
			_add_part(sp, _box(Vector3(0.014, 0.016, 0.004)), Vector3(0.0, 0.026, 0.027), Vector3.ZERO, brass)
			for coin_d in [[-0.016, 0.038, 0.006], [0.0, 0.044, 0.004], [0.016, 0.038, 0.006], [-0.008, 0.040, -0.004], [0.008, 0.040, -0.004]]:
				var cx_c: float = coin_d[0]
				_add_part(sp, _cyl(0.009, 0.009, 0.006, 10), Vector3(cx_c, coin_d[1], coin_d[2]), Vector3(12.0, 0.0, cx_c * 240.0), brass)
			_add_part(sp, _sph(0.007), Vector3(0.0, 0.050, 0.006), Vector3.ZERO, glow)

		_:
			# Fallback ornate brass astrolabe medallion
			_add_part(sp, _tor(0.030, 0.038, 18), Vector3(0.0, 0.064, 0.0), Vector3(68.0, 0.0, 0.0), brass)
			_add_part(sp, _sph(0.018), Vector3(0.0, 0.064, 0.0), Vector3.ZERO, glow)

	return root


# ==============================================================================
# 2. SCULPTED 3D MEDIEVAL SHOP ARTIFACTS (ALL 10 CROSSROADS ITEMS)
# ==============================================================================

static func build_medieval_shop_item_3d(emblem: String, col: Color) -> Node3D:
	var root := Node3D.new()
	var m := _mats(col)
	var brass: Material = m["brass"]
	var copper: Material = m["copper"]
	var iron: Material = m["iron"]
	var steel: Material = m["steel"]
	var wood: Material = m["wood"]
	var walnut: Material = m["walnut"]
	var leather: Material = m["leather"]
	var ivory: Material = m["ivory"]
	var parchment: Material = m["parchment"]
	var wax: Material = m["wax"]
	var cloth_red: Material = m["cloth_red"]
	var stone: Material = m["stone"]
	var glow: Material = m["glow"]

	match emblem:
		"mirror":
			_add_part(root, _cyl(0.046, 0.056, 0.016, 12), Vector3(0.0, 0.008, 0.0), Vector3.ZERO, walnut)
			_add_part(root, _cyl(0.016, 0.012, 0.088, 12), Vector3(0.0, 0.054, 0.0), Vector3.ZERO, brass)
			_add_part(root, _tor(0.072, 0.094, 22), Vector3(0.0, 0.148, 0.0), Vector3(90.0, 0.0, 0.0), brass)
			_add_part(root, _cyl(0.074, 0.074, 0.012, 20), Vector3(0.0, 0.148, 0.0), Vector3(90.0, 0.0, 0.0), glow)
			_add_part(root, _sph(0.014), Vector3(0.0, 0.244, 0.0), Vector3.ZERO, glow)
			_add_part(root, _sph(0.012), Vector3(-0.084, 0.148, 0.0), Vector3.ZERO, brass)
			_add_part(root, _sph(0.012), Vector3(0.084, 0.148, 0.0), Vector3.ZERO, brass)

		"chalice":
			_add_part(root, _cyl(0.022, 0.068, 0.024, 14), Vector3(0.0, 0.012, 0.0), Vector3.ZERO, brass)
			_add_part(root, _cyl(0.015, 0.018, 0.084, 12), Vector3(0.0, 0.064, 0.0), Vector3.ZERO, brass)
			_add_part(root, _sph(0.024), Vector3(0.0, 0.066, 0.0), Vector3.ZERO, copper)
			_add_part(root, _cyl(0.076, 0.030, 0.105, 16), Vector3(0.0, 0.148, 0.0), Vector3.ZERO, brass)
			_add_part(root, _tor(0.066, 0.078, 18), Vector3(0.0, 0.198, 0.0), Vector3.ZERO, brass)
			_add_part(root, _sph(0.062, 0.030), Vector3(0.0, 0.192, 0.0), Vector3.ZERO, wax)
			for i in range(4):
				var a: float = float(i) * PI * 0.5
				_add_part(root, _sph(0.010), Vector3(cos(a) * 0.058, 0.148, sin(a) * 0.058), Vector3.ZERO, glow)

		"gauntlet":
			_add_part(root, _cyl(0.056, 0.070, 0.095, 12), Vector3(0.0, 0.048, 0.0), Vector3(-6.0, 0.0, 0.0), iron)
			_add_part(root, _cyl(0.062, 0.062, 0.012, 12), Vector3(0.0, 0.088, 0.0), Vector3(-6.0, 0.0, 0.0), brass)
			_add_part(root, _box(Vector3(0.102, 0.092, 0.068)), Vector3(0.0, 0.138, 0.0), Vector3.ZERO, steel)
			_add_part(root, _box(Vector3(0.106, 0.024, 0.072)), Vector3(0.0, 0.168, 0.004), Vector3.ZERO, brass)
			for ki in range(4):
				var kx: float = -0.036 + float(ki) * 0.024
				_add_part(root, _cyl(0.011, 0.011, 0.058, 8), Vector3(kx, 0.196, 0.018), Vector3(32.0, 0.0, 0.0), steel)
			_add_part(root, _cyl(0.013, 0.012, 0.052, 8), Vector3(-0.062, 0.146, 0.024), Vector3(14.0, 0.0, 32.0), brass)

		"phial":
			_add_part(root, _sph(0.078, 0.136), Vector3(0.0, 0.074, 0.0), Vector3.ZERO, glow)
			_add_part(root, _tor(0.074, 0.080, 16), Vector3(0.0, 0.072, 0.0), Vector3.ZERO, iron)
			_add_part(root, _tor(0.072, 0.078, 16), Vector3(0.0, 0.074, 0.0), Vector3(90.0, 0.0, 0.0), iron)
			_add_part(root, _cyl(0.024, 0.032, 0.064, 12), Vector3(0.0, 0.156, 0.0), Vector3.ZERO, copper)
			_add_part(root, _cyl(0.030, 0.030, 0.014, 12), Vector3(0.0, 0.178, 0.0), Vector3.ZERO, brass)
			_add_part(root, _cyl(0.020, 0.017, 0.026, 10), Vector3(0.0, 0.194, 0.0), Vector3.ZERO, wax)

		"eye":
			_add_part(root, _cyl(0.034, 0.044, 0.016, 10), Vector3(0.0, 0.008, 0.0), Vector3.ZERO, walnut)
			_add_part(root, _cyl(0.009, 0.012, 0.052, 10), Vector3(0.0, 0.036, 0.0), Vector3.ZERO, brass)
			_add_part(root, _tor(0.070, 0.092, 22), Vector3(0.0, 0.132, 0.0), Vector3(90.0, 0.0, 0.0), brass)
			_add_part(root, _sph(0.062), Vector3(0.0, 0.132, 0.0), Vector3.ZERO, ivory)
			_add_part(root, _sph(0.034), Vector3(0.0, 0.132, 0.040), Vector3.ZERO, glow)
			_add_part(root, _sph(0.016), Vector3(0.0, 0.132, 0.058), Vector3.ZERO, m["dark"])
			_add_part(root, _cyl(0.005, 0.005, 0.042, 8), Vector3(0.088, 0.100, 0.0), Vector3(0.0, 0.0, 12.0), brass)

		"scroll":
			_add_part(root, _box(Vector3(0.118, 0.012, 0.118)), Vector3(0.0, 0.084, 0.0), Vector3(28.0, 0.0, 0.0), parchment)
			for rod_d in [[-0.054, 0.112], [0.054, 0.056]]:
				var rz: float = rod_d[0]
				var ry: float = rod_d[1]
				_add_part(root, _cyl(0.016, 0.016, 0.148, 12), Vector3(0.0, ry, rz), Vector3(0.0, 0.0, 90.0), walnut)
				for rx in [-0.078, 0.078]:
					_add_part(root, _sph(0.019), Vector3(rx, ry, rz), Vector3.ZERO, brass)
			_add_part(root, _cyl(0.024, 0.024, 0.008, 12), Vector3(0.022, 0.078, 0.028), Vector3(28.0, 0.0, 0.0), wax)
			_add_part(root, _cyl(0.004, 0.002, 0.145, 8), Vector3(0.058, 0.145, 0.0), Vector3(0.0, 0.0, -28.0), brass)

		"key":
			_add_part(root, _cyl(0.038, 0.046, 0.016, 8), Vector3(0.0, 0.008, 0.0), Vector3.ZERO, stone)
			_add_part(root, _tor(0.038, 0.058, 18), Vector3(0.0, 0.184, 0.0), Vector3(90.0, 0.0, 0.0), brass)
			_add_part(root, _tor(0.018, 0.026, 14), Vector3(0.0, 0.184, 0.0), Vector3(90.0, 0.0, 0.0), glow)
			_add_part(root, _cyl(0.013, 0.014, 0.144, 12), Vector3(0.0, 0.088, 0.0), Vector3.ZERO, brass)
			_add_part(root, _box(Vector3(0.044, 0.036, 0.014)), Vector3(0.028, 0.042, 0.0), Vector3.ZERO, steel)
			_add_part(root, _box(Vector3(0.016, 0.022, 0.016)), Vector3(0.044, 0.068, 0.0), Vector3.ZERO, glow)

		"whetstone":
			_add_part(root, _box(Vector3(0.128, 0.022, 0.088)), Vector3(0.0, 0.012, 0.0), Vector3.ZERO, wood)
			_add_part(root, _box(Vector3(0.064, 0.172, 0.034)), Vector3(0.0, 0.098, 0.0), Vector3(0.0, 0.0, -18.0), stone)
			_add_part(root, _box(Vector3(0.022, 0.132, 0.040)), Vector3(0.0, 0.098, 0.0), Vector3(0.0, 0.0, -18.0), glow)
			_add_part(root, _box(Vector3(0.018, 0.122, 0.008)), Vector3(-0.024, 0.118, 0.024), Vector3(0.0, 0.0, 28.0), steel)
			_add_part(root, _box(Vector3(0.042, 0.010, 0.012)), Vector3(-0.048, 0.064, 0.024), Vector3(0.0, 0.0, 28.0), brass)

		"urn":
			_add_part(root, _cyl(0.046, 0.058, 0.018, 12), Vector3(0.0, 0.009, 0.0), Vector3.ZERO, iron)
			_add_part(root, _cyl(0.056, 0.042, 0.118, 14), Vector3(0.0, 0.076, 0.0), Vector3.ZERO, copper)
			_add_part(root, _cyl(0.062, 0.062, 0.014, 14), Vector3(0.0, 0.096, 0.0), Vector3.ZERO, brass)
			_add_part(root, _tor(0.042, 0.054, 16), Vector3(0.0, 0.138, 0.0), Vector3.ZERO, brass)
			_add_part(root, _sph(0.046, 0.074), Vector3(0.0, 0.156, 0.0), Vector3.ZERO, glow)
			for side in [-1.0, 1.0]:
				_add_part(root, _tor(0.014, 0.020, 12), Vector3(side * 0.060, 0.088, 0.0), Vector3(0.0, 90.0, 0.0), brass)

		_:
			# Ornate bronze Plague-Bell
			_add_part(root, _cyl(0.052, 0.064, 0.018, 14), Vector3(0.0, 0.009, 0.0), Vector3.ZERO, walnut)
			_add_part(root, _cyl(0.042, 0.084, 0.118, 18), Vector3(0.0, 0.096, 0.0), Vector3.ZERO, brass)
			_add_part(root, _tor(0.076, 0.086, 18), Vector3(0.0, 0.038, 0.0), Vector3.ZERO, copper)
			_add_part(root, _sph(0.042), Vector3(0.0, 0.156, 0.0), Vector3.ZERO, brass)
			_add_part(root, _tor(0.016, 0.024, 14), Vector3(0.0, 0.204, 0.0), Vector3(90.0, 0.0, 0.0), brass)
			_add_part(root, _sph(0.024), Vector3(0.0, 0.028, 0.0), Vector3.ZERO, glow)

	return root


static func build_sword_3d_mesh(skin_id: String, sk: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	var blade_col: Color = sk.get("blade_col", Color(0.84, 0.88, 0.94))
	var guard_col: Color = sk.get("guard_col", Color(0.92, 0.74, 0.28))
	var grip_col: Color = sk.get("grip_col", Color(0.36, 0.20, 0.14))
	var trail_col: Color = sk.get("trail_col", Color(0.95, 0.28, 0.28))

	var glb_sw := _load_glb("res://assets/models/swords/%s.glb" % skin_id)
	if glb_sw != null:
		glb_sw.name = "HeroSwordGLB"
		root.add_child(glb_sw)
		root.set_meta("blender_glb", true)
		_apply_woodcut_ink_outline(root, 0.005)
		return root

	var hd_sw := _load_glb("res://assets/models/swords/handdrawn_oathblade.glb")
	if hd_sw != null:
		hd_sw.name = "HandDrawnOathBladeGLB"
		var b_mat := _make_handdrawn_mat(
			"res://assets/textures/relics/forged_steel_ink.png",
			blade_col, blade_col.darkened(0.68),
			0.52, 48.0, 0.90, 32.0, 0.64, 0.0008, Vector2.ONE, 0.78
		)
		var g_mat := _make_handdrawn_mat(
			"res://assets/textures/relics/tankard_brass_ink.png",
			guard_col, guard_col.darkened(0.66),
			0.64, 48.0, 0.76, 26.0, 0.56, 0.0008, Vector2.ONE, 0.78
		)
		var gr_mat := _make_handdrawn_mat(
			"res://assets/textures/relics/dice_leather_ink.png",
			grip_col.lightened(0.35), grip_col.darkened(0.65),
			0.82, 36.0, 0.16, 18.0, 0.30, 0.0008, Vector2.ONE, 0.80
		)
		var gem_mat := _make_handdrawn_mat(
			"", trail_col.lightened(0.25), trail_col.darkened(0.55),
			0.25, 28.0, 0.92, 34.0, 0.75, 0.0005, Vector2.ONE, 0.40,
			trail_col * 0.45
		)
		var stack: Array[Node] = [hd_sw]
		while not stack.is_empty():
			var cur: Node = stack.pop_back() as Node
			if cur is MeshInstance3D:
				var mi := cur as MeshInstance3D
				var nm: String = str(mi.name)
				if "BladeSteel" in nm:
					mi.material_override = b_mat
				elif "BrassGuard" in nm:
					mi.material_override = g_mat
				elif "LeatherGrip" in nm:
					mi.material_override = gr_mat
				elif "OathGem" in nm:
					mi.material_override = gem_mat
			for ch in cur.get_children():
				stack.append(ch)
		root.add_child(hd_sw)
		root.set_meta("handdrawn_3d", true)
		return root

	glb_sw = _load_glb("res://assets/models/sword_oath.glb")
	if glb_sw != null:
		glb_sw.name = "HeroSwordGLB"
		root.add_child(glb_sw)
		root.set_meta("blender_glb", true)
		_apply_woodcut_ink_outline(root, 0.006)
		return root

	# Detailed sculpted woodcut Oathblade fallback (NEVER returns an empty node!)
	var blade_mat := Toon.pbr(blade_col, "", 0.24, 0.90)
	var guard_mat := Toon.pbr(guard_col, "", 0.28, 0.88)
	var grip_mat := Toon.pbr(grip_col, "res://assets/gloves/glove_leather.png", 0.68, 0.04)
	var gem_mat2 := Toon.pbr(trail_col, "", 0.14, 0.20, Vector2.ONE, trail_col, 1.6)

	_add_part(root, _box(Vector3(0.046, 0.56, 0.012)), Vector3(0.0, 0.34, 0.0), Vector3.ZERO, blade_mat)
	_add_part(root, _prism(Vector3(0.046, 0.14, 0.012)), Vector3(0.0, 0.69, 0.0), Vector3.ZERO, blade_mat)
	_add_part(root, _box(Vector3(0.24, 0.024, 0.030)), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, guard_mat)
	_add_part(root, _cyl(0.015, 0.018, 0.18, 10), Vector3(0.0, -0.05, 0.0), Vector3.ZERO, grip_mat)
	_add_part(root, _sph(0.026), Vector3(0.0, -0.155, 0.0), Vector3.ZERO, guard_mat)
	_add_part(root, _sph(0.014), Vector3(0.0, 0.05, 0.016), Vector3.ZERO, gem_mat2)
	_apply_woodcut_ink_outline(root, 0.006)
	return root


# ==============================================================================
# 3. PERMANENT TAVERN TABLE PROPS (DETAILED SCULPTED VERSIONS)
# ==============================================================================

static func _load_glb(res_path: String) -> Node3D:
	if ResourceLoader.exists(res_path):
		var packed := load(res_path) as PackedScene
		if packed:
			var inst := packed.instantiate()
			if inst is Node3D:
				return inst as Node3D
	if FileAccess.file_exists(res_path):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		var abs_p := ProjectSettings.globalize_path(res_path)
		if doc.append_from_file(abs_p, st) == OK:
			var gen := doc.generate_scene(st)
			if gen is Node3D:
				return gen as Node3D
	return null


static func build_hellfire_phial_meshes(parent: Node3D) -> void:
	var blender_phial := BlenderVfx.build_hero_hellfire_phial(parent)
	if blender_phial != null:
		parent.set_meta("blender_glb", true)
		return
	var glb := _load_glb("res://assets/models/phial_ignis.glb")
	if glb:
		glb.name = "HeroPhialIgnisGLB"
		var plume := glb.find_child("IgnitedPlume", true, false) as Node3D
		if plume != null:
			plume.visible = false
		parent.add_child(glb)
		parent.set_meta("blender_glb", true)
		return
	var glass_mat := Toon.mat(Color(0.64, 0.18, 0.06), "", 0.007, Vector2.ONE, Color(0.38, 0.10, 0.02))
	var iron_mat := Toon.pbr(Color(0.20, 0.18, 0.18), "", 0.42, 0.78)
	var gold_mat := Toon.pbr(Color(0.86, 0.64, 0.22), "", 0.26, 0.86)
	var cork_mat := Toon.pbr(Color(0.46, 0.30, 0.16), "res://assets/table/wood.png", 0.68, 0.04)
	var wax_mat := Toon.pbr(Color(0.68, 0.12, 0.10), "", 0.34, 0.08)

	# Coaster base + bulbous flask + iron cage strapwork + shoulder brass ring + wax cork + alchemy tag
	_add_part(parent, _cyl(0.064, 0.068, 0.010, 14), Vector3(0.0, 0.005, 0.0), Vector3.ZERO, iron_mat)
	_add_part(parent, _sph(0.062, 0.114), Vector3(0.0, 0.064, 0.0), Vector3.ZERO, glass_mat)
	_add_part(parent, _tor(0.058, 0.064, 16), Vector3(0.0, 0.066, 0.0), Vector3.ZERO, iron_mat)
	_add_part(parent, _tor(0.056, 0.061, 16), Vector3(0.0, 0.066, 0.0), Vector3(90.0, 0.0, 0.0), iron_mat)
	_add_part(parent, _cyl(0.023, 0.032, 0.064, 12), Vector3(0.0, 0.136, 0.0), Vector3.ZERO, glass_mat)
	_add_part(parent, _cyl(0.028, 0.028, 0.014, 14), Vector3(0.0, 0.162, 0.0), Vector3.ZERO, gold_mat)
	_add_part(parent, _cyl(0.020, 0.017, 0.028, 10), Vector3(0.0, 0.180, 0.0), Vector3.ZERO, cork_mat)
	_add_part(parent, _cyl(0.023, 0.020, 0.010, 10), Vector3(0.0, 0.192, 0.0), Vector3.ZERO, wax_mat)


static func build_shop_bell_meshes(parent: Node3D) -> void:
	var glb := _load_glb("res://assets/models/shop_bell.glb")
	if glb:
		parent.add_child(glb)
		return
	var brass_mat := Toon.pbr(Color(0.92, 0.72, 0.26), "", 0.22, 0.88, Vector2.ONE, Color(0.28, 0.18, 0.04), 0.35)
	var copper_mat := Toon.pbr(Color(0.76, 0.44, 0.22), "", 0.28, 0.84)
	var ebony_mat := Toon.pbr(Color(0.14, 0.09, 0.07), "res://assets/table/wood.png", 0.52, 0.05)

	_add_part(parent, _cyl(0.060, 0.070, 0.018, 20), Vector3(0.0, 0.009, 0.0), Vector3.ZERO, ebony_mat)
	_add_part(parent, _tor(0.054, 0.060, 20), Vector3(0.0, 0.018, 0.0), Vector3.ZERO, brass_mat)
	_add_part(parent, _cyl(0.034, 0.052, 0.048, 20), Vector3(0.0, 0.042, 0.0), Vector3.ZERO, brass_mat)
	_add_part(parent, _sph(0.034, 0.044), Vector3(0.0, 0.064, 0.0), Vector3.ZERO, brass_mat)
	_add_part(parent, _tor(0.045, 0.051, 18), Vector3(0.0, 0.036, 0.0), Vector3.ZERO, copper_mat)
	_add_part(parent, _cyl(0.012, 0.008, 0.022, 12), Vector3(0.0, 0.088, 0.0), Vector3.ZERO, brass_mat)
	_add_part(parent, _sph(0.012), Vector3(0.0, 0.100, 0.0), Vector3.ZERO, brass_mat)


static func build_coins_pouch_meshes(parent: Node3D) -> void:
	var glb := _load_glb("res://assets/models/coins_pouch.glb")
	if glb:
		parent.add_child(glb)
		return
	var leather_mat := Toon.pbr(Color(0.32, 0.18, 0.11), "res://assets/gloves/glove_leather.png", 0.68, 0.05)
	var cord_mat := Toon.pbr(Color(0.84, 0.64, 0.24), "", 0.42, 0.45)
	var gold_mat := Toon.pbr(Color(0.95, 0.74, 0.24), "", 0.24, 0.88, Vector2.ONE, Color(0.25, 0.18, 0.04), 0.32)
	var silver_mat := Toon.pbr(Color(0.80, 0.84, 0.90), "", 0.28, 0.84, Vector2.ONE, Color(0.10, 0.12, 0.16), 0.25)

	_add_part(parent, _sph(0.072, 0.105), Vector3(-0.06, 0.032, -0.02), Vector3.ZERO, leather_mat, Vector3(1.1, 0.85, 1.0))
	_add_part(parent, _tor(0.024, 0.030, 14), Vector3(-0.06, 0.072, -0.02), Vector3.ZERO, cord_mat)
	_add_part(parent, _cyl(0.038, 0.024, 0.038, 12), Vector3(-0.06, 0.088, -0.02), Vector3.ZERO, leather_mat)
	for ci in range(11):
		var st: int = ci / 4
		var jx: float = (float(ci % 2) - 0.5) * 0.004
		_add_part(parent, _cyl(0.022, 0.022, 0.0065, 14),
			Vector3(0.038 + float(st) * 0.052 + jx, float(ci % 4) * 0.007, 0.02 + float(st) * 0.022),
			Vector3(0.0, float(ci) * 28.0, 0.0), gold_mat if st != 1 else silver_mat)


static func build_bone_dice_meshes(parent: Node3D) -> void:
	var glb := _load_glb("res://assets/models/bone_dice.glb")
	if glb:
		glb.position = Vector3(0.0, -0.017, 0.0)
		parent.add_child(glb)
		return
	var bone_mat := Toon.pbr(Color(0.92, 0.86, 0.72), "", 0.42, 0.04)
	var pip_mat := Toon.pbr(Color(0.14, 0.10, 0.08), "", 0.75, 0.02)

	for di in range(2):
		var d_pos := Vector3(float(di) * 0.054 - 0.027, 0.0, float(di) * 0.018)
		var d_rot := Vector3(0.0, 18.0 + float(di) * 37.0, 0.0)
		var die := _add_part(parent, _box(Vector3(0.034, 0.034, 0.034)), d_pos, d_rot, bone_mat)
		# Brass edge corners & carved multi-pip patterns on top and front
		var top_pips: Array = [[-0.008, -0.008], [0.008, 0.008], [0.0, 0.0]] if di == 0 else [[-0.008, -0.008], [0.008, -0.008], [-0.008, 0.008], [0.008, 0.008]]
		for tp in top_pips:
			_add_part(die, _cyl(0.0038, 0.0038, 0.002, 8), Vector3(tp[0], 0.0175, tp[1]), Vector3.ZERO, pip_mat)
		for fp in [[-0.007, -0.007], [0.007, 0.007]]:
			_add_part(die, _cyl(0.0038, 0.0038, 0.002, 8), Vector3(fp[0], fp[1], 0.0175), Vector3(90.0, 0.0, 0.0), pip_mat)


static func build_tavern_mug_meshes(parent: Node3D) -> void:
	var glb := _load_glb("res://assets/models/tavern_mug.glb")
	if glb:
		glb.name = "HeroTavernMugGLB"
		parent.add_child(glb)
		parent.set_meta("blender_glb", true)
		return
	var wood_mat := Toon.pbr(Color(0.46, 0.30, 0.17), "res://assets/table/wood.png", 0.56, 0.06)
	var brass_mat := Toon.pbr(Color(0.86, 0.65, 0.24), "", 0.26, 0.86)
	var foam_mat := Toon.mat(Color(0.96, 0.92, 0.80), "", 0.0)

	var mug := _add_part(parent, _cyl(0.054, 0.060, 0.132, 12), Vector3(0.0, 0.066, 0.0), Vector3.ZERO, wood_mat)
	for by in [-0.042, 0.032]:
		_add_part(mug, _cyl(0.061, 0.061, 0.014, 12), Vector3(0.0, by, 0.0), Vector3.ZERO, brass_mat)
	_add_part(mug, _box(Vector3(0.032, 0.036, 0.008)), Vector3(0.0, -0.005, 0.056), Vector3.ZERO, brass_mat)
	_add_part(mug, _tor(0.022, 0.035, 14), Vector3(0.064, 0.0, 0.0), Vector3(90.0, 0.0, 0.0), wood_mat)
	_add_part(mug, _cyl(0.049, 0.049, 0.018, 12), Vector3(0.0, 0.066, 0.0), Vector3.ZERO, foam_mat)
	for fm in [[-0.018, 0.010, 0.018], [0.018, -0.008, 0.016], [0.0, 0.018, 0.015]]:
		_add_part(mug, _sph(fm[2]), Vector3(fm[0], 0.072, fm[1]), Vector3.ZERO, foam_mat)
