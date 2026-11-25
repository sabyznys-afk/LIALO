class_name LialoIcons
extends RefCounted

## Central loader and helpers for hand-drawn woodcut/brass UI icons.
## Replaces all system/Unicode emojis across the UI (v0.193).

const ICON_DIR := "res://assets/ui/icons/"

static var _cache: Dictionary = {}


static func get_icon(icon_name: String) -> Texture2D:
	var key := icon_name.strip_edges().to_lower()
	if key.is_empty():
		return null
	if _cache.has(key):
		return _cache[key] as Texture2D
	var path := ICON_DIR + "icon_" + key + ".png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_cache[key] = tex
		return tex
	return null


static func make_icon_rect(icon_name: String, size_px: int = 18, tint: Color = Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = get_icon(icon_name)
	tr.custom_minimum_size = Vector2(size_px, size_px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func apply_button_icon(btn: Button, icon_name: String, size_px: int = 18) -> void:
	if btn == null:
		return
	var tex := get_icon(icon_name)
	if tex == null:
		return
	btn.icon = tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("icon_max_width", size_px)


static func make_icon_label_row(icon_name: String, text: String, icon_px: int = 18, font_size: int = 14, color: Color = Color(0.95, 0.90, 0.78)) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := make_icon_rect(icon_name, icon_px)
	row.add_child(tr)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return row


static func get_suit_icon_name(suit: int) -> String:
	match suit:
		0: return "heart"
		1: return "leaves"
		2: return "acorn"
		3: return "bell"
	return "diamond"
