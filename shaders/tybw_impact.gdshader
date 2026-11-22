shader_type canvas_item;
// Bleach TYBW-Inspired Fullscreen Impact-Frame, Speedlines & Reiatsu Slash Overlay
// 100% GL Compatibility safe (no screen_texture dependency required — blends cleanly as an overlay!)

uniform float impact_amount : hint_range(0.0, 1.0) = 0.0;
uniform float invert_flash : hint_range(0.0, 1.0) = 0.0;
uniform float speedline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float slash_strength : hint_range(0.0, 1.0) = 0.0;
uniform float slash_angle = -0.36; // radians
uniform float slash_progress : hint_range(0.0, 1.0) = 0.5;
uniform float pressure_darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focal_uv = vec2(0.5, 0.46);
uniform vec4 accent_col : source_color = vec4(0.95, 0.14, 0.24, 1.0);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	vec2 uv = UV;
	vec2 d = uv - focal_uv;
	float dist = length(d * vec2(1.77, 1.0));
	float ang = atan(d.y, d.x);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// 1. Stark Reiatsu Shadow Pressure (TYBW stark ink-vignette darkening the room)
	if (pressure_darkness > 0.005) {
		float vig = smoothstep(0.24, 1.05, dist);
		float ink_band = smoothstep(0.58, 0.96, dist);
		vec3 dark_tint = mix(vec3(0.01, 0.008, 0.015), accent_col.rgb * 0.14, ink_band * 0.55);
		col = mix(col, dark_tint, vig);
		alpha = max(alpha, vig * pressure_darkness * 0.84);
	}

	// 2. Radial Anime Speedlines (razor-sharp monochrome + accent streaks)
	if (speedline_strength > 0.005) {
		float sector_count = 110.0;
		float a_idx = floor((ang + 3.14159) / 6.28318 * sector_count + floor(TIME * 22.0) * 1.37);
		float rnd = hash11(a_idx);
		float spoke = step(0.62, rnd);
		float inner_cut = mix(0.28, 0.62, hash11(a_idx + 17.3));
		float radial_mask = smoothstep(inner_cut, inner_cut + 0.24, dist);
		float line_val = spoke * radial_mask * speedline_strength;
		vec3 line_col = (rnd > 0.84) ? mix(vec3(1.0), accent_col.rgb, 0.45) : vec3(0.015, 0.01, 0.02);
		col = mix(col, line_col, clamp(line_val * 0.95, 0.0, 1.0));
		alpha = max(alpha, line_val * 0.78);
	}

	// 3. Razor-Sharp High-Contrast Diagonal TYBW Energy Slash (black ink core + blazing accent rim)
	if (slash_strength > 0.005) {
		float ca = cos(slash_angle);
		float sa = sin(slash_angle);
		vec2 p = uv - vec2(0.5, 0.48);
		float perp = abs(-p.x * sa + p.y * ca);
		float along = (p.x * ca + p.y * sa) + 0.5;
		float head_mask = smoothstep(slash_progress + 0.12, slash_progress - 0.04, along);
		float width_taper = (1.0 - smoothstep(0.0, 0.68, abs(along - 0.5))) * (0.006 + slash_strength * 0.020);
		float core = smoothstep(width_taper * 0.58, width_taper * 0.16, perp) * head_mask;
		float rim = smoothstep(width_taper * 1.85, width_taper * 0.45, perp) * head_mask;
		float white_hot = smoothstep(width_taper * 0.18, 0.0, perp) * head_mask;

		vec3 slash_c = mix(accent_col.rgb * 1.45, vec3(0.012, 0.008, 0.018), core * 0.92);
		slash_c = mix(slash_c, vec3(1.0, 0.98, 0.96), white_hot * 0.98);
		float s_a = clamp(rim * slash_strength, 0.0, 1.0);
		col = mix(col, slash_c, s_a);
		alpha = max(alpha, s_a * 0.94);
	}

	// 4. True Anime Impact Frame Flash (stark B&W / Accent burst at climax hitstop)
	if (impact_amount > 0.005 || invert_flash > 0.005) {
		float burst_ring = smoothstep(0.04, 0.0, abs(dist - mix(0.10, 0.95, 1.0 - impact_amount)));
		float ray_a = floor((ang + 3.14159) / 6.28318 * 48.0);
		float ray_spike = step(0.45, hash11(ray_a + floor(TIME * 30.0))) * smoothstep(0.18, 0.88, dist);
		// Alternating stark white/black/accent ink impact aesthetic
		vec3 flash_c = mix(vec3(0.01, 0.01, 0.015), vec3(0.98, 0.97, 0.95), step(0.42, ray_spike + burst_ring));
		flash_c = mix(flash_c, accent_col.rgb * 1.4, burst_ring * 0.75);
		float imp_a = clamp(max(impact_amount * 0.72, invert_flash * 0.88), 0.0, 0.92);
		col = mix(col, flash_c, imp_a);
		alpha = max(alpha, imp_a);
	}

	COLOR = vec4(col, clamp(alpha, 0.0, 0.96));
}
