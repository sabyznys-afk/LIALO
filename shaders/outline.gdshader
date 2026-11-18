shader_type spatial;
// Hand-carved woodcut reed-pen ink outline (inverted hull with subtle organic nib variation).
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.045, 0.032, 0.026, 1.0);
uniform float thickness = 0.013;

void vertex() {
	float wobble = 0.85 + 0.30 * sin(VERTEX.x * 29.0 + VERTEX.y * 23.0 + VERTEX.z * 17.0);
	VERTEX += NORMAL * (thickness * wobble);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
