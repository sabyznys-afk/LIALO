shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 ray_color : source_color = vec4(0.42, 0.66, 0.95, 0.11);

void fragment() {
	float edge = sin(UV.x * 3.14159);
	float v_fade = pow(1.0 - UV.y, 1.45) * smoothstep(0.0, 0.18, UV.y);
	float shimmer = 0.84 + 0.16 * sin(TIME * 1.3 + UV.x * 10.0);
	vec3 col = ray_color.rgb * shimmer;
	ALBEDO = col;
	EMISSION = col;
	ALPHA = ray_color.a * edge * v_fade;
}
