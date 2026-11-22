shader_type spatial;
// Engraved Alpine Mountain Woodcut Shader: layered wind-drifted snowpack, cliff shedding, hoarfrost crevices,
// alpine sky shadows, sunrise snow glints & burin slope cross-hatching.

uniform vec4 rock_tint : source_color = vec4(0.58, 0.54, 0.49, 1.0);
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(2.2, 2.2);
uniform vec4 snow_col : source_color = vec4(0.94, 0.91, 0.84, 1.0);
uniform float peak_height = 4.0;
uniform float snow_line_ratio = 0.62;
uniform vec4 shadow_tint : source_color = vec4(0.20, 0.16, 0.18, 1.0);
uniform float band_soft = 0.05;

uniform vec4 snow_shadow_col : source_color = vec4(0.55, 0.65, 0.82, 1.0);
uniform vec4 snow_sun_tint : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float wind_drift_strength : hint_range(0.0, 1.0) = 0.58;
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.55;
uniform float snow_time = 0.0;

varying vec3 v_local_pos;
varying vec3 v_local_nrm;
varying vec3 v_world_pos;
varying float v_snow_mask;
varying float v_frost_mask;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);

	float nxy0 = mix(nx00, nx10, u.y);
	float nxy1 = mix(nx01, nx11, u.y);
	return mix(nxy0, nxy1, u.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise3(p);
		p = p * 2.07 + vec3(13.1, 7.7, 5.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 rock = texture(rock_tex, UV * uv_scale).rgb * mix(vec3(1.0), rock_tint.rgb, 0.35);

	float h_norm = clamp(v_local_pos.y / max(0.2, peak_height), 0.0, 1.0);
	float upness = clamp(v_local_nrm.y, 0.0, 1.0);
	float cliff_shed = smoothstep(0.22, 0.72, upness);

	// Multi-octave couloir / gully fingers & crag variation
	float gully_n = fbm3(v_local_pos * vec3(1.85, 0.95, 1.85) + vec3(1.7, 0.0, 3.1)) - 0.5;
	float crag_n = fbm3(v_local_pos * vec3(4.6, 3.4, 4.6) + vec3(7.3, 2.4, 1.9)) - 0.5;

	// Directional wind drift along the ridge (prevailing west-northwest alpine wind + leeward accumulation)
	vec2 wind_dir = normalize(vec2(0.84, 0.54));
	vec2 nrm_xz = v_local_nrm.xz;
	float nrm_xz_len = length(nrm_xz);
	vec2 safe_xz = nrm_xz_len > 0.001 ? (nrm_xz / nrm_xz_len) : vec2(1.0, 0.0);
	float slope_wind = dot(safe_xz, wind_dir);
	float drift_wave = sin(v_local_pos.x * 2.8 + v_local_pos.z * 1.9 + gully_n * 3.8) * 0.5;
	float wind_bias = (slope_wind * 0.55 + drift_wave * 0.45) * wind_drift_strength;

	float slope_hold = mix(-0.18, 0.10, cliff_shed);
	float snow_score = h_norm * 0.92 + slope_hold + gully_n * 0.13 + crag_n * 0.06 + wind_bias * 0.07;

	float snow_mask = smoothstep(snow_line_ratio, snow_line_ratio + 0.085, snow_score);
	float frost_mask = smoothstep(snow_line_ratio - 0.13, snow_line_ratio + 0.02, snow_score)
					 * (1.0 - snow_mask)
					 * (0.45 + 0.55 * pow(upness, 1.3));

	v_snow_mask = snow_mask;
	v_frost_mask = frost_mask;

	// Exposed alpine granite with engraved topographic contour rings & frosted crevices
	float contour = smoothstep(0.18, 0.55, abs(sin(v_local_pos.y * 9.5 + (gully_n + crag_n) * 10.0)));
	vec3 ground_c = rock * mix(0.82, 1.0, contour);
	vec3 frost_col = mix(rock * 0.80, snow_col.rgb * vec3(0.90, 0.94, 1.0), 0.72);
	ground_c = mix(ground_c, frost_col, frost_mask * (0.62 + 0.38 * clamp(crag_n + 0.5, 0.0, 1.0)));

	// Wind-carved sastrugi micro-relief & soft cool/warm modulation inside deep snowpack
	float sastrugi = fbm3(v_local_pos * vec3(5.8, 2.2, 8.4) + vec3(snow_time * 0.015, 0.0, 0.0));
	float sastrugi_band = smoothstep(0.32, 0.72, sastrugi);
	vec3 snow_base = mix(snow_col.rgb * mix(snow_shadow_col.rgb, vec3(1.0), 0.78), snow_col.rgb * snow_sun_tint.rgb, sastrugi_band);
	snow_base = mix(snow_base, snow_col.rgb, 0.35);

	ALBEDO = mix(ground_c, snow_base, snow_mask);
	ROUGHNESS = mix(0.96, 0.76, snow_mask);
	SPECULAR = mix(0.0, 0.18, snow_mask);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;

	float wave = sin(FRAGCOORD.y * 0.04 + v_local_pos.x * 2.5) * 1.2;
	float h1 = smoothstep(0.18, 0.54, abs(sin((FRAGCOORD.x + FRAGCOORD.y) * 0.44 + wave)));
	float h2 = smoothstep(0.22, 0.58, abs(sin((FRAGCOORD.x - FRAGCOORD.y) * 0.41 - wave)));

	float b_hi = smoothstep(0.32, 0.32 + band_soft, lit);
	float b_mid = smoothstep(0.06, 0.06 + band_soft, lit);

	// Rock uses bold burin cross-hatching; snow shifts to lighter, airier alpine woodcut hatching
	float hatch_rock = mix(mix(0.28, 1.0, h1 * h2), mix(0.46, 1.0, h1), b_mid);
	hatch_rock = mix(hatch_rock, 1.0, b_hi);

	float hatch_snow = mix(mix(0.68, 1.0, h1 * 0.8 + 0.2), mix(0.84, 1.0, h1), b_mid);
	hatch_snow = mix(hatch_snow, 1.0, b_hi);

	vec3 rock_shade = mix(shadow_tint.rgb * 0.28, vec3(1.0), b_mid * 0.48 + b_hi * 0.52) * hatch_rock;
	vec3 snow_shade = mix(snow_shadow_col.rgb * 0.72, snow_sun_tint.rgb * 1.04, b_mid * 0.46 + b_hi * 0.54) * hatch_snow;

	float snow_blend = clamp(v_snow_mask + v_frost_mask * 0.45, 0.0, 1.0);
	vec3 shade = mix(rock_shade, snow_shade, snow_blend);

	// Alpenglow Fresnel rim on snowy ridges
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.4);
	vec3 alpenglow = snow_sun_tint.rgb * LIGHT_COLOR * fres * snow_blend * 0.34 * ATTENUATION;

	// Subtle sunlit crystalline snow glints driven by half-vector & spatial micro-facets
	vec3 half_v = normalize(LIGHT + VIEW);
	float spec_align = pow(max(dot(NORMAL, half_v), 0.0), 18.0);
	float glint_cell = hash31(floor(v_local_pos * 26.0));
	float glint_twinkle = 0.55 + 0.45 * sin(snow_time * 3.8 + glint_cell * 41.0);
	float glint = smoothstep(0.90, 0.985, glint_cell) * spec_align * glint_twinkle * v_snow_mask * sparkle_strength * ATTENUATION;

	DIFFUSE_LIGHT += ALBEDO * shade * LIGHT_COLOR / PI * 1.62 + alpenglow;
	SPECULAR_LIGHT += LIGHT_COLOR * snow_sun_tint.rgb * glint * 0.72;
}
