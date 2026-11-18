shader_type canvas_item;
// Full-Screen Living Woodcut / Etching Print Post-Processing Shader
// Clean directional burin cross-hatching, smooth 3x3 Sobel ink contours, and warm rag broadsheet grading
// with zero pixel-static noise and full highlight protection for readable card art.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform int print_mode = 3; // 0 = Living Woodcut, 1 = Broadsheet Sepia, 2 = Classic Toon, 3 = Liar's Bar Cinematic PBR
uniform float edge_strength : hint_range(0.0, 2.0) = 0.95;
uniform float hatch_strength : hint_range(0.0, 1.5) = 0.82;
uniform float paper_grain : hint_range(0.0, 0.25) = 0.022;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.36;
uniform float boil_fps = 3.5;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 raw = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	if (print_mode == 2) {
		COLOR = vec4(raw, 1.0);
	} else if (print_mode == 3) {
		// Liar's Bar / Buckshot Roulette Cinematic PBR Grade: crisp filmic contrast, warm tungsten highlights, smoky shadow vignette, ZERO hatching!
		vec3 x = max(vec3(0.0), raw * 1.12);
		vec3 aces = clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), vec3(0.0), vec3(1.0));
		float lum_raw = luma(raw);
		// Warm candlelight shadow tint + subtle rim punch
		vec3 warm_grade = mix(aces * vec3(0.95, 0.96, 1.04), aces * vec3(1.06, 1.01, 0.92), smoothstep(0.14, 0.68, lum_raw));
		// Subtle optical bloom halo on hot flames / magic highlights
		vec2 b_px = SCREEN_PIXEL_SIZE * 2.5;
		vec3 blur_hi = (
			texture(SCREEN_TEXTURE, SCREEN_UV + vec2(b_px.x, 0.0)).rgb +
			texture(SCREEN_TEXTURE, SCREEN_UV - vec2(b_px.x, 0.0)).rgb +
			texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, b_px.y)).rgb +
			texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, b_px.y)).rgb
		) * 0.25;
		vec3 bloom = max(vec3(0.0), blur_hi - vec3(0.72)) * 0.42;
		vec2 v_uv = SCREEN_UV - vec2(0.5);
		float vig = smoothstep(0.44, 0.94, length(v_uv * vec2(1.18, 1.0)));
		vec3 final_c = mix(warm_grade + bloom, vec3(0.024, 0.020, 0.018), vig * (vignette_strength * 0.92));
		COLOR = vec4(clamp(final_c, vec3(0.0), vec3(1.0)), 1.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE * 1.15;
		// Ultra-subtle slow boil for living print feel (only 0.22 px max shift)
		float boil_t = floor(TIME * boil_fps) * 0.173;
		vec2 j_uv = SCREEN_UV;

		// 3x3 Sobel luminance gradient -> crisp smooth charcoal ink contours without rim dot aliasing
		float l_tl = luma(texture(SCREEN_TEXTURE, j_uv + vec2(-px.x, -px.y)).rgb);
		float l_tc = luma(texture(SCREEN_TEXTURE, j_uv + vec2(0.0,   -px.y)).rgb);
		float l_tr = luma(texture(SCREEN_TEXTURE, j_uv + vec2(px.x,  -px.y)).rgb);
		float l_ml = luma(texture(SCREEN_TEXTURE, j_uv + vec2(-px.x,  0.0)).rgb);
		vec3  c_c  = texture(SCREEN_TEXTURE, j_uv).rgb;
		float l_mr = luma(texture(SCREEN_TEXTURE, j_uv + vec2(px.x,   0.0)).rgb);
		float l_bl = luma(texture(SCREEN_TEXTURE, j_uv + vec2(-px.x,  px.y)).rgb);
		float l_bc = luma(texture(SCREEN_TEXTURE, j_uv + vec2(0.0,    px.y)).rgb);
		float l_br = luma(texture(SCREEN_TEXTURE, j_uv + vec2(px.x,   px.y)).rgb);

		float gx = (l_tr + 2.0 * l_mr + l_br) - (l_tl + 2.0 * l_ml + l_bl);
		float gy = (l_bl + 2.0 * l_bc + l_br) - (l_tl + 2.0 * l_tc + l_tr);
		float sobel = sqrt(gx * gx + gy * gy);

		float lum = luma(c_c);
		float max_ch = max(c_c.r, max(c_c.g, c_c.b));
		float min_ch = min(c_c.r, min(c_c.g, c_c.b));
		float sat = (max_ch - min_ch) / max(0.001, max_ch);

		// Protect bright card paper & fine text + vivid glowing rim accents from over-inking
		float card_protect = smoothstep(0.86, 0.42, lum);
		float glow_protect = 1.0 - smoothstep(0.45, 0.85, sat) * smoothstep(0.30, 0.65, lum);
		float ink_edge = smoothstep(0.16, 0.46, sobel * edge_strength) * mix(0.32, 1.0, card_protect) * mix(0.45, 1.0, glow_protect);

		// Clean continuous directional burin engraving strokes (zero speckled hash noise!)
		float wave = sin(FRAGCOORD.y * 0.038 + FRAGCOORD.x * 0.014 + boil_t * 0.25) * 1.15;
		float h_45 = smoothstep(0.16, 0.56, abs(sin((FRAGCOORD.x + FRAGCOORD.y) * 0.44 + wave)));
		float h_n45 = smoothstep(0.20, 0.60, abs(sin((FRAGCOORD.x - FRAGCOORD.y) * 0.41 - wave)));

		float mid_band = smoothstep(0.42, 0.16, lum);
		float deep_band = smoothstep(0.18, 0.035, lum);
		float hatch_mask = 1.0;
		hatch_mask = mix(1.0, mix(0.54, 1.0, h_45), mid_band * hatch_strength);
		hatch_mask = mix(hatch_mask, mix(0.30, 1.0, h_45 * h_n45), deep_band * hatch_strength);

		// Gentle broadsheet rag-paper fiber weave (smooth organic tooth, no high-freq sandy grit)
		float fiber = (sin(FRAGCOORD.x * 0.14 + FRAGCOORD.y * 0.05) * cos(FRAGCOORD.y * 0.13 - FRAGCOORD.x * 0.04)) * paper_grain;
		float micro_boil = (hash21(floor(FRAGCOORD.xy * 0.35) + boil_t * 0.02) - 0.5) * (paper_grain * 0.45);

		vec3 graded = c_c;
		if (print_mode == 1) {
			// Broadsheet Sepia mode: stark antique woodcut engraving with vivid crimson/gold/cyan accents popping through!
			float lifted = pow(clamp(lum * 1.18 + 0.025, 0.0, 1.0), 0.88);
			float poster_l = mix(lifted, floor(lifted * 7.0 + 0.4) / 7.0, 0.28);
			vec3 sepia_paper = mix(vec3(0.095, 0.068, 0.054), vec3(0.93, 0.88, 0.77), poster_l);
			float accent_keep = smoothstep(0.30, 0.62, sat);
			graded = mix(sepia_paper, c_c * vec3(1.02, 0.96, 0.86), accent_keep * 0.94);
		} else {
			// Living Woodcut mode: lift dark tavern stone/wood shadows into legible engraved charcoal-umber tones + warm broadsheet highlights
			vec3 shadow_lift = c_c * vec3(1.24, 1.13, 1.00) + vec3(0.058, 0.046, 0.038) * smoothstep(0.26, 0.015, lum);
			vec3 cream_high = c_c * vec3(1.01, 0.98, 0.91);
			graded = mix(shadow_lift, cream_high, smoothstep(0.24, 0.80, lum));
			// Unify desaturated greys slightly toward warm broadsheet parchment while preserving vivid magic/fire/rims
			float avg_l = luma(graded);
			vec3 sepia_pull = vec3(avg_l * 1.03, avg_l * 0.95, avg_l * 0.82);
			graded = mix(graded, sepia_pull, (1.0 - smoothstep(0.18, 0.54, sat)) * 0.22);
		}

		vec3 ink_col = vec3(0.048, 0.034, 0.028);
		vec3 etched = graded * hatch_mask + vec3(fiber + micro_boil) * smoothstep(0.02, 0.35, lum);
		etched = mix(etched, ink_col, ink_edge * 0.82);

		// Soft broadsheet vignette
		vec2 v_uv = SCREEN_UV - vec2(0.5);
		float vig = smoothstep(0.40, 0.88, length(v_uv * vec2(1.20, 1.0)));
		etched = mix(etched, vec3(0.042, 0.030, 0.024), vig * vignette_strength);

		COLOR = vec4(clamp(etched, vec3(0.0), vec3(1.0)), 1.0);
	}
}
