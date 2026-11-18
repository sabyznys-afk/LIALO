shader_type spatial;
// Engraved Alpine Mountain Woodcut Shader: organic snow ridge line + burin slope cross-hatching.

uniform vec4 rock_tint : source_color = vec4(0.58, 0.54, 0.49, 1.0);
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(2.2, 2.2);
uniform vec4 snow_col : source_color = vec4(0.94, 0.91, 0.84, 1.0);
uniform float peak_height = 4.0;
uniform float snow_line_ratio = 0.62;
uniform vec4 shadow_tint : source_color = vec4(0.20, 0.16, 0.18, 1.0);
uniform float band_soft = 0.05;

varying vec3 v_local_pos;
varying vec3 v_local_nrm;

void vertex() {
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;
}

void fragment() {
	vec3 rock = texture(rock_tex, UV * uv_scale).rgb * mix(vec3(1.0), rock_tint.rgb, 0.35);

	float h_norm = clamp(v_local_pos.y / max(0.2, peak_height), 0.0, 1.0);
	float angle = atan(v_local_pos.z, v_local_pos.x);
	float ridge_noise = sin(angle * 3.0 + v_local_pos.x * 1.4) * 0.085
					  + cos(angle * 5.0 - v_local_pos.z * 1.8) * 0.055;
	float slope_bonus = clamp(v_local_nrm.y, 0.0, 1.0) * 0.14;
	float snow_score = h_norm + ridge_noise + slope_bonus;

	float snow_mask = smoothstep(snow_line_ratio, snow_line_ratio + 0.11, snow_score);
	float frost_edge = smoothstep(snow_line_ratio - 0.06, snow_line_ratio + 0.02, snow_score) * (1.0 - snow_mask);
	vec3 ground_c = mix(rock, rock * 0.78 + vec3(0.14, 0.17, 0.22), frost_edge * 0.55);

	// Contour ridge ink rings on exposed mountain rock
	float contour = smoothstep(0.18, 0.55, abs(sin(v_local_pos.y * 9.5 + ridge_noise * 12.0)));
	ground_c *= mix(0.82, 1.0, contour);

	ALBEDO = mix(ground_c, snow_col.rgb, snow_mask);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;

	float wave = sin(FRAGCOORD.y * 0.04 + v_local_pos.x * 2.5) * 1.2;
	float h1 = smoothstep(0.18, 0.54, abs(sin((FRAGCOORD.x + FRAGCOORD.y) * 0.44 + wave)));
	float h2 = smoothstep(0.22, 0.58, abs(sin((FRAGCOORD.x - FRAGCOORD.y) * 0.41 - wave)));

	float b_hi = smoothstep(0.32, 0.32 + band_soft, lit);
	float b_mid = smoothstep(0.06, 0.06 + band_soft, lit);

	float hatch = mix(mix(0.28, 1.0, h1 * h2), mix(0.46, 1.0, h1), b_mid);
	hatch = mix(hatch, 1.0, b_hi);

	vec3 shade = mix(shadow_tint.rgb * 0.28, vec3(1.0), b_mid * 0.48 + b_hi * 0.52) * hatch;
	DIFFUSE_LIGHT += ALBEDO * shade * LIGHT_COLOR / PI * 1.62;
}
