shader_type spatial;
// Living Woodcut / Etching 3D Surface Shader (Godot 4.7 GL Compatibility)
// Hand-engraved 45° / -45° burin cross-hatching driven by light luminance + organic paper tooth.

uniform vec4 albedo : source_color = vec4(0.6, 0.45, 0.3, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.14, 0.16, 1.0);
uniform float band_soft = 0.05;
uniform float rim_strength = 0.32;
uniform float grain_strength = 0.0;
uniform float hatch_strength : hint_range(0.0, 1.5) = 1.0;
uniform float hatch_density : hint_range(0.2, 1.5) = 0.46;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 v_world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = albedo;
	if (use_texture) {
		c *= texture(albedo_tex, UV * uv_scale);
	}
	// Smooth organic rag-paper wave tooth without digital static dots
	float strength = grain_strength > 0.0 ? grain_strength : 0.018;
	float paper = sin(FRAGCOORD.x * 0.16 + FRAGCOORD.y * 0.07) * cos(FRAGCOORD.y * 0.15 - FRAGCOORD.x * 0.05) * strength;
	vec3 warm_c = c.rgb * vec3(1.02, 0.99, 0.94) + paper;
	ALBEDO = clamp(warm_c, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.96;
	SPECULAR = 0.0;
	EMISSION = emission_color.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;

	// Screen-aligned clean burin engraving lines (zero harsh pixel stipple)
	float wave = sin(FRAGCOORD.y * 0.042 + FRAGCOORD.x * 0.016 + v_world_pos.x * 2.8) * 1.25;
	float p1 = (FRAGCOORD.x + FRAGCOORD.y) * hatch_density + wave;
	float p2 = (FRAGCOORD.x - FRAGCOORD.y) * (hatch_density * 0.94) - wave * 0.80;

	float stroke1 = smoothstep(0.18, 0.54, abs(sin(p1)));
	float stroke2 = smoothstep(0.22, 0.58, abs(sin(p2)));

	float b_hi = smoothstep(0.30, 0.30 + band_soft, lit);
	float b_mid = smoothstep(0.06, 0.06 + band_soft, lit);

	float hatch_mid = mix(1.0 - 0.50 * hatch_strength, 1.0, stroke1);
	float hatch_deep = mix(1.0 - 0.72 * hatch_strength, 1.0, stroke1 * stroke2);

	float tone_mul = mix(hatch_deep, hatch_mid, b_mid);
	tone_mul = mix(tone_mul, 1.0, b_hi);

	vec3 ink_col = shadow_tint.rgb * 0.24;
	vec3 base_shade = mix(ink_col, vec3(1.0), b_mid * 0.48 + b_hi * 0.52);
	vec3 final_shade = base_shade * mix(vec3(1.0), vec3(tone_mul), clamp(hatch_strength, 0.0, 1.0));

	DIFFUSE_LIGHT += ALBEDO * final_shade * LIGHT_COLOR / PI * 1.65;

	// Etched highlight rim for dramatic silhouette readability in candlelight
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.8);
	float rim_hatch = mix(0.75, 1.0, stroke1);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * rim_strength * rim_hatch * ATTENUATION * 0.13;
}
