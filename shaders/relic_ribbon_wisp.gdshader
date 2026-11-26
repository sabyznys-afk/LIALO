shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D atlas_tex : source_color, filter_linear_mipmap;
uniform int cell_idx = 0;
uniform int atlas_cols = 4;
uniform vec4 wisp_color : source_color = vec4(0.46, 0.92, 1.0, 0.85);
uniform vec4 ink_color : source_color = vec4(0.06, 0.04, 0.05, 1.0);
uniform float wave_speed = 2.4;
uniform float wave_amp = 0.004;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float sway = sin(TIME * wave_speed + UV.y * 6.2831) * wave_amp * UV.y;
	VERTEX.x += sway;
	VERTEX.z += cos(TIME * wave_speed * 0.85 + UV.y * 5.0) * wave_amp * 0.7 * UV.y;
}

void fragment() {
	float cols = float(max(1, atlas_cols));
	float cx = float(cell_idx % max(1, atlas_cols));
	float cy = float(cell_idx / max(1, atlas_cols));
	vec2 scrolled = vec2(UV.x, fract(UV.y - TIME * 0.25));
	vec2 cell_uv = (scrolled + vec2(cx, cy)) / cols;
	vec4 tex = texture(atlas_tex, cell_uv);
	float v_taper = sin(UV.y * 3.14159);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(ink_color.rgb, wisp_color.rgb, smoothstep(0.18, 0.55, lum));
	ALBEDO = col;
	EMISSION = wisp_color.rgb * 0.75 * smoothstep(0.4, 1.0, lum);
	ALPHA = tex.a * wisp_color.a * v_taper * fade_alpha;
	if (ALPHA < 0.03) {
		discard;
	}
}
