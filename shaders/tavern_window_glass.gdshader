shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 glass_tint : source_color = vec4(0.18, 0.32, 0.54, 0.24);
uniform vec4 moon_halo : source_color = vec4(0.62, 0.82, 1.0, 0.42);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	float d = distance(UV, vec2(0.5, 0.35));
	float halo = smoothstep(0.55, 0.05, d);
	// Animated rain streaks sliding down leaded glass
	vec2 cell = floor(vec2(UV.x * 16.0, UV.y * 6.0 - TIME * 1.8));
	vec2 f = fract(vec2(UV.x * 16.0, UV.y * 6.0 - TIME * 1.8));
	float drop = smoothstep(0.18, 0.04, abs(f.x - 0.5)) * smoothstep(0.45, 0.10, abs(f.y - 0.5)) * step(0.55, hash(cell));
	vec3 col = mix(glass_tint.rgb, moon_halo.rgb, halo * 0.72 + drop * 0.55);
	ALBEDO = col;
	EMISSION = col * (0.45 + halo * 0.55);
	ALPHA = clamp(glass_tint.a + halo * 0.22 + drop * 0.32, 0.08, 0.72);
}
