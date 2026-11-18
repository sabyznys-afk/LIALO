extends RefCounted
## Pomocník na vytváranie kreslených (cel-shaded) materiálov s atramentovým obrysom.
## Použitie:  const Toon = preload("res://scripts/toon_style.gd")
##            mesh.material_override = Toon.mat(Color(...), "res://assets/table/wood.png", 0.01)

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

static func mat(color: Color, tex_path: String = "", outline: float = 0.01, uv_scale: Vector2 = Vector2.ONE, emission: Color = Color.BLACK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("emission_color", emission)
	if tex_path != "" and ResourceLoader.exists(tex_path):
		m.set_shader_parameter("albedo_tex", load(tex_path))
		m.set_shader_parameter("use_texture", true)
		m.set_shader_parameter("albedo", Color(1, 1, 1, 1).lerp(color, 0.25))
	if outline > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("thickness", outline)
		m.next_pass = o
	return m

static func pbr(color: Color, tex_path: String = "", roughness: float = 0.52, metallic: float = 0.0, uv_scale: Vector2 = Vector2.ONE, emission: Color = Color.BLACK, em_energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = clampf(roughness, 0.04, 1.0)
	m.metallic = clampf(metallic, 0.0, 1.0)
	m.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	if tex_path != "":
		var t := tex(tex_path)
		if t:
			m.albedo_texture = t
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.albedo_color = Color(1, 1, 1, 1).lerp(color, 0.42)
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = em_energy
	return m

static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null
