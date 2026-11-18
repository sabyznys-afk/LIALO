shader_type spatial;
// Eerie Illuminated Chronicle / Antique Grimoire Cartography Shader (GL Compatibility)
// Matches aged tea-stained folio vellum of the book border: dusty bone-taupe trails,
// weathered lichen-ash wilds, deep indigo-ink waterways, and etched brass rhumb geometry.

uniform sampler2D map_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform bool is_outer = false;
uniform float map_half_size = 20.0;
uniform float hatch_strength : hint_range(0.0, 1.5) = 0.42;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.24;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 src = texture(map_tex, uv).rgb;
	float src_luma = dot(src, vec3(0.299, 0.587, 0.114));

	float blotch = vnoise(v_world_pos.xz * 0.16) * 0.62 + vnoise(v_world_pos.xz * 0.48) * 0.38;
	float stain = vnoise(v_world_pos.xz * 0.085 + vec2(4.2, 7.1));
	float tooth = sin(FRAGCOORD.x * 0.15 + FRAGCOORD.y * 0.06) * cos(FRAGCOORD.y * 0.14 - FRAGCOORD.x * 0.05) * 0.014;

	vec3 base_col = vec3(0.50, 0.45, 0.37);
	if (is_outer) {
		// Uncharted smoked taupe margins fading smoothly into obsidian book-table gloom
		vec3 aged_edge = mix(vec3(0.22, 0.195, 0.16), vec3(0.38, 0.34, 0.27), clamp(src_luma * 1.1, 0.0, 1.0));
		aged_edge *= mix(0.84, 1.08, blotch);
		float edge_d = max(abs(v_world_pos.x), abs(v_world_pos.z));
		float abyss = smoothstep(map_half_size + 2.0, map_half_size + 21.0, edge_d);
		base_col = mix(aged_edge, vec3(0.04, 0.032, 0.026), abyss);
	} else {
		float is_water = smoothstep(0.018, 0.072, src.b - max(src.r, src.g) * 0.90);
		float is_path = smoothstep(-0.012, 0.068, src.r - src.g * 0.94) * (1.0 - is_water);
		float ink_stroke = smoothstep(0.38, 0.11, src_luma);

		// Neutral ash-taupe & weathered moss-vellum (woodcut_post warms subtly to match map_frame!)
		vec3 wild_col = mix(vec3(0.35, 0.35, 0.32), vec3(0.46, 0.45, 0.40), blotch);
		// Antique bone-vellum trails & clearings (soft neutral parchment without yellow blowout)
		vec3 path_col = mix(vec3(0.52, 0.51, 0.46), vec3(0.62, 0.60, 0.54), blotch);

		// Deep Stygian slate ink river + delicate engraved silver current hairlines
		float wave_phase = uv.y * 340.0 + sin(uv.x * 110.0 + TIME * 0.85) * 2.6 - TIME * 1.3;
		float river_wave = smoothstep(0.72, 0.96, sin(wave_phase) * 0.5 + 0.5);
		float shore = smoothstep(0.02, 0.10, src.b - max(src.r, src.g) * 0.90);
		vec3 water_col = mix(vec3(0.11, 0.14, 0.155), vec3(0.26, 0.31, 0.31), river_wave * 0.32 * shore);

		vec3 terrain = mix(wild_col, path_col, is_path);
		terrain = mix(terrain, water_col, is_water);

		// Crisp iron-gall ink outlines & cobblestone penwork
		vec3 ink_tint = vec3(0.08, 0.06, 0.045);
		terrain = mix(terrain, ink_tint, ink_stroke * mix(0.84, 0.42, is_water));

		// Subtle sepia age-foxing stains
		float stain_ring = smoothstep(0.58, 0.72, stain) * smoothstep(0.88, 0.74, stain);
		terrain = mix(terrain, terrain * vec3(0.84, 0.77, 0.67), stain_ring * 0.34 * (1.0 - is_water));

		// Engraved Cartographic Coordinate Grid & Compass Rhumb Rays
		float gx = 1.0 - smoothstep(0.0, 0.038, abs(fract(v_world_pos.x * 0.16) - 0.5));
		float gz = 1.0 - smoothstep(0.0, 0.038, abs(fract(v_world_pos.z * 0.16) - 0.5));
		vec2 c_hub1 = v_world_pos.xz - vec2(-5.5, -4.5);
		vec2 c_hub2 = v_world_pos.xz - vec2(6.5, 5.5);
		float a1 = atan(c_hub1.y, c_hub1.x);
		float a2 = atan(c_hub2.y, c_hub2.x);
		float rhumb1 = (1.0 - smoothstep(0.0, 0.040, abs(sin(a1 * 8.0)))) * smoothstep(22.0, 1.5, length(c_hub1));
		float rhumb2 = (1.0 - smoothstep(0.0, 0.040, abs(sin(a2 * 8.0)))) * smoothstep(22.0, 1.5, length(c_hub2));
		float carto_lines = clamp(max(max(gx, gz) * 0.55, max(rhumb1, rhumb2) * 0.80), 0.0, 1.0) * (1.0 - is_water * 0.85);
		terrain = mix(terrain, vec3(0.14, 0.105, 0.078), carto_lines * grid_strength);

		// Gentle dark burnt-vellum perimeter burn near atlas edges
		float bound = max(abs(v_world_pos.x), abs(v_world_pos.z));
		float burn = smoothstep(map_half_size * 0.74, map_half_size, bound);
		terrain = mix(terrain, vec3(0.16, 0.135, 0.105), burn * 0.52);

		base_col = terrain + vec3(tooth);
	}

	ALBEDO = clamp(base_col, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.96;
	SPECULAR = 0.0;
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float lit = ndl * ATTENUATION;

	float wave = sin(FRAGCOORD.y * 0.04 + FRAGCOORD.x * 0.015 + v_world_pos.x * 0.65) * 1.1;
	float h1 = smoothstep(0.16, 0.56, abs(sin((FRAGCOORD.x + FRAGCOORD.y) * 0.42 + wave)));

	float b_hi = smoothstep(0.30, 0.42, lit);
	float b_mid = smoothstep(0.05, 0.16, lit);

	float hatch = mix(mix(0.72, 1.0, h1), mix(0.86, 1.0, h1), b_mid);
	hatch = mix(hatch, 1.0, b_hi);
	hatch = mix(1.0, hatch, clamp(hatch_strength, 0.0, 1.0));

	vec3 shade = mix(vec3(0.52, 0.48, 0.43), vec3(1.0), b_mid * 0.34 + b_hi * 0.66) * hatch;
	DIFFUSE_LIGHT += ALBEDO * shade * LIGHT_COLOR / PI * 1.68;
}
