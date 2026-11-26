shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;

uniform sampler2D shroud_tex : source_color, filter_linear_mipmap;
uniform vec4 base_col : source_color = vec4(0.06, 0.14, 0.22, 0.34);
uniform vec4 fold_col : source_color = vec4(0.18, 0.44, 0.62, 0.58);
uniform vec4 rim_col : source_color = vec4(0.56, 0.94, 1.0, 1.0);
varying float v_y;
varying vec3 v_pos;

void vertex() {
	float low_w = pow(clamp(1.0 - VERTEX.y * 1.15, 0.0, 1.0), 1.25);
	VERTEX.x += sin(TIME * 2.2 + VERTEX.y * 5.2 + VERTEX.z * 4.2) * 0.030 * low_w;
	VERTEX.z += cos(TIME * 1.8 + VERTEX.y * 4.6 + VERTEX.x * 4.8) * 0.024 * low_w;
	v_y = UV.y;
	v_pos = VERTEX;
}

void fragment() {
	vec3 tex = texture(shroud_tex, UV * vec2(2.0, 2.0)).rgb;
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 2.4);
	// Chiaroscuro ink hatching in deep folds
	float hatch = smoothstep(0.25, 0.78, sin((v_pos.x + v_pos.y) * 58.0) * 0.5 + 0.5);
	float fold_shade = clamp(ndv * 0.85 + 0.15, 0.0, 1.0);
	vec3 cloth = mix(base_col.rgb * 0.35, fold_col.rgb * tex, fold_shade * (0.72 + 0.28 * hatch));
	ALBEDO = mix(cloth, rim_col.rgb, fres * 0.82);
	EMISSION = rim_col.rgb * (fres * 1.05 + (1.0 - fold_shade) * 0.06);
	ROUGHNESS = 0.76;
	float hem_fade = 1.0 - smoothstep(0.58, 0.98, v_y);
	ALPHA = clamp((mix(base_col.a, fold_col.a, fold_shade) + fres * 0.48) * hem_fade, 0.03, 0.84);
}
