shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sprite_sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 grid_size = vec2(6.0, 4.0);
uniform float frame_index = 0.0;
uniform float blend_next : hint_range(0.0, 1.0) = 0.0;
uniform float loop_sheet = 0.0;
uniform float flip_x = 0.0;
uniform float flip_y = 0.0;

uniform vec4 tint_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_col : source_color = vec4(0.32, 0.90, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 6.0) = 1.6;
uniform float flash_white : hint_range(0.0, 1.0) = 0.0;
uniform float ink_preserve : hint_range(0.0, 1.0) = 0.88;
uniform float royal_shift : hint_range(0.0, 1.0) = 0.0;

uniform float boil_amp : hint_range(0.0, 0.025) = 0.0024;
uniform float boil_fps = 12.0;
uniform float boil_seed = 1.0;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float woodcut_grain : hint_range(0.0, 0.35) = 0.07;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 frame_uv(vec2 local_uv, float idx, vec2 gsize, vec2 tex_sz) {
	float total = max(1.0, gsize.x * gsize.y);
	float safe_idx = clamp(floor(idx + 0.001), 0.0, total - 1.0);
	if (loop_sheet > 0.5) {
		safe_idx = mod(max(0.0, floor(idx + 0.001)), total);
	}
	float col = mod(safe_idx, gsize.x);
	float row = floor(safe_idx / gsize.x);
	vec2 cell_px = max(vec2(1.0), tex_sz / gsize);
	vec2 pad = 1.25 / cell_px;
	vec2 safe_uv = clamp(local_uv, pad, vec2(1.0) - pad);
	return (vec2(col, row) + safe_uv) / gsize;
}

vec4 sample_cel(vec2 local_uv, float idx, float nxt, vec2 gsize, vec2 tex_sz) {
	vec4 c0 = texture(sprite_sheet, frame_uv(local_uv, idx, gsize, tex_sz));
	if (nxt > 0.005) {
		vec4 c1 = texture(sprite_sheet, frame_uv(local_uv, idx + 1.0, gsize, tex_sz));
		return mix(c0, c1, nxt);
	}
	return c0;
}

void fragment() {
	vec2 uv = UV;
	if (flip_x > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	if (flip_y > 0.5) {
		uv.y = 1.0 - uv.y;
	}

	// Subtle quantized hand-drawn line boil (feels inked on 2s at 12 fps)
	float q_time = floor(TIME * max(1.0, boil_fps)) + boil_seed * 13.7;
	vec2 boil_n = vec2(
		value_noise(uv * 11.0 + vec2(q_time * 1.37, q_time * 0.71)) - 0.5,
		value_noise(uv * 11.0 + vec2(q_time * 0.89 + 19.3, q_time * 1.53)) - 0.5
	);
	uv = clamp(uv + boil_n * boil_amp, vec2(0.0), vec2(1.0));

	vec2 tex_sz = vec2(textureSize(sprite_sheet, 0));
	float base_idx = floor(frame_index);
	float auto_nxt = mix(0.0, fract(frame_index), step(0.005, blend_next)) * blend_next;
	vec4 tex = sample_cel(uv, base_idx, auto_nxt, grid_size, tex_sz);

	// Optional cool-mist -> warm-royal gold/crimson palette shift while preserving black ink
	vec3 rgb = tex.rgb;
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	float max_c = max(rgb.r, max(rgb.g, rgb.b));
	float min_c = min(rgb.r, min(rgb.g, rgb.b));
	float sat = (max_c > 0.001) ? (max_c - min_c) / max_c : 0.0;

	if (royal_shift > 0.005) {
		vec3 royal_col = vec3(
			clamp(rgb.b * 1.18 + rgb.g * 0.18 + 0.14, 0.0, 1.0),
			clamp(rgb.g * 0.78 + rgb.b * 0.15, 0.0, 1.0),
			clamp(rgb.r * 0.55, 0.0, 1.0)
		);
		// Shift saturated blade/rune hues more strongly than neutral ink
		rgb = mix(rgb, royal_col, royal_shift * smoothstep(0.08, 0.42, sat + luma * 0.25));
	}

	// Tint midtones/highlights without muddying dip-pen ink outlines
	float ink_mask = 1.0 - smoothstep(0.08, 0.45, luma);
	vec3 tinted = rgb * mix(tint_col.rgb, vec3(1.0), ink_mask * ink_preserve);

	// Tactile paper tooth modulation on watercolor washes
	float tooth = (value_noise(uv * 38.0 + vec2(boil_seed)) - 0.5) * woodcut_grain * (1.0 - ink_mask);
	tinted = clamp(tinted + vec3(tooth), vec3(0.0), vec3(1.0));

	// Energy glow emerges from bright rim highlights & saturated magic pigment
	float glow_mask = smoothstep(0.50, 0.92, luma) * 0.68 + smoothstep(0.18, 0.65, sat) * smoothstep(0.25, 0.85, luma) * 0.72;
	tinted = mix(tinted, vec3(1.0, 0.98, 0.92), flash_white * (1.0 - ink_mask * 0.35));

	// Organic ink-erosion dissolve: paper wash dries out first, ink outlines fragment last
	float alpha = tex.a * tint_col.a * opacity;
	if (dissolve > 0.001) {
		float n_erode = value_noise(uv * 16.0 + vec2(boil_seed * 7.1)) * 0.68
			+ value_noise(uv * 37.0 + vec2(11.3, 4.7)) * 0.32;
		float ink_resilience = mix(0.0, 0.28, ink_mask);
		float edge = dissolve * 1.32 - ink_resilience;
		alpha *= smoothstep(edge - 0.10, edge + 0.08, n_erode);
	}

	ALBEDO = tinted;
	EMISSION = glow_col.rgb * (glow_mask * glow_strength + flash_white * 1.4) * smoothstep(0.05, 0.45, alpha);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
