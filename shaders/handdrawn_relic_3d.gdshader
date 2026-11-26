shader_type spatial;
// Hand-Drawn 3D Relic Surface Shader (Godot 4.7 GL Compatibility)
// Combines hand-inked texture art, crevice vertex AO, UV-locked engraved crosshatching,
// stepped gouache highlights, and dual calligraphic Fresnel contours.

uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = true;
uniform vec2 uv_scale = vec2(1.0, 1.0);

uniform vec4 shadow_tint : source_color = vec4(0.14, 0.09, 0.08, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.94, 0.80, 1.0);

uniform float hatch_strength : hint_range(0.0, 1.5) = 0.92;
uniform float hatch_density : hint_range(8.0, 140.0) = 42.0;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.25;
uniform float specular_size : hint_range(4.0, 96.0) = 24.0;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.35;
uniform float ao_ink_strength : hint_range(0.0, 1.0) = 0.72;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec2 v_uv;
varying float v_crevice_ao;

void vertex() {
	v_uv = UV * uv_scale;
	v_crevice_ao = clamp(COLOR.r, 0.22, 1.0);
}

void fragment() {
	vec4 tex_c = use_texture ? texture(albedo_tex, v_uv) : vec4(1.0);
	vec3 base = tex_c.rgb * albedo_tint.rgb;

	// Deepen sculpted grooves/joints with warm sepia-ink vertex AO
	float ao_mul = mix(1.0, v_crevice_ao, ao_ink_strength);
	base *= mix(shadow_tint.rgb * 1.45 + vec3(0.05), vec3(1.0), ao_mul);

	// Subtle rag-paper tooth variation so flat regions feel painted rather than digital
	float paper = sin(v_uv.x * 88.0 + sin(v_uv.y * 37.0) * 1.8) * cos(v_uv.y * 92.0 - v_uv.x * 21.0) * 0.016;
	ALBEDO = clamp(base + paper, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.92;
	SPECULAR = 0.0;
	EMISSION = emission_color.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;

	// 3-band painterly cel ramp
	float b_mid = smoothstep(-0.08, 0.06, lit);
	float b_hi = smoothstep(0.32, 0.48, lit);

	// UV-locked dual-angle hand-engraved nib strokes (never swim when inspecting 360°)
	float wobble = sin(v_uv.y * 19.0 + v_uv.x * 11.0) * 0.55;
	float diag_a = (v_uv.x + v_uv.y) * hatch_density + wobble;
	float diag_b = (v_uv.x - v_uv.y) * (hatch_density * 0.92) - wobble * 0.75;

	float stroke_a = smoothstep(0.18, 0.62, abs(sin(diag_a)));
	float stroke_b = smoothstep(0.24, 0.66, abs(sin(diag_b)));

	float shadow_mask = clamp(1.0 - b_mid, 0.0, 1.0);
	float mid_mask = clamp(b_mid * (1.0 - b_hi), 0.0, 1.0);

	float h_mid = mix(1.0 - 0.34 * hatch_strength, 1.0, stroke_a);
	float h_deep = mix(1.0 - 0.68 * hatch_strength, 1.0, stroke_a * stroke_b);
	float hatch_mul = mix(1.0, h_mid, mid_mask);
	hatch_mul = mix(hatch_mul, h_deep, shadow_mask);

	// Warm highlights & cool-sepia shadows
	vec3 ramp = mix(shadow_tint.rgb, vec3(0.92, 0.88, 0.84), b_mid);
	ramp = mix(ramp, highlight_tint.rgb, b_hi);

	// Crevice AO softly reinforces dark ink shadows
	float crease = mix(0.65, 1.0, mix(1.0, v_crevice_ao, ao_ink_strength * 0.7));
	vec3 diffuse = ALBEDO * ramp * hatch_mul * crease;
	DIFFUSE_LIGHT += diffuse * LIGHT_COLOR / PI * 1.95;

	// Stepped painterly gouache specular highlight (for hammered brass & wet foam)
	if (specular_strength > 0.001) {
		vec3 H = normalize(LIGHT + VIEW);
		float ndh = max(dot(NORMAL, H), 0.0);
		float spec_raw = pow(ndh, specular_size);
		float spec_dab = smoothstep(0.22, 0.30, spec_raw) * specular_strength;
		DIFFUSE_LIGHT += highlight_tint.rgb * LIGHT_COLOR * spec_dab * ATTENUATION * 0.55;
	}

	// Dual silhouette rim: dark ink edge in shadows + golden candlelight catch on lit edges
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.4);
	float lit_edge = smoothstep(0.05, 0.55, lit + 0.15);
	DIFFUSE_LIGHT += highlight_tint.rgb * LIGHT_COLOR * fresnel * rim_strength * lit_edge * ATTENUATION * 0.42;
	DIFFUSE_LIGHT -= shadow_tint.rgb * fresnel * 0.12 * (1.0 - lit_edge);
}
