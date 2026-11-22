shader_type canvas_item;

uniform float beat_phase = 0.0;
uniform float beat_amp = 0.045;
uniform float hp_ratio = 1.0;
uniform float crack_energy = 0.16;
uniform float damage_flash = 0.0;
uniform float heal_flash = 0.0;
uniform float is_dead = 0.0;
uniform float time_sec = 0.0;
uniform vec4 accent_col : source_color = vec4(1.0, 0.72, 0.24, 1.0);
uniform sampler2D crack_tex : filter_linear, repeat_disable;

void fragment() {
	// Lub-dub physiological heartbeat radial expansion around (0.5, 0.48)
	float lub = max(0.0, sin(beat_phase));
	float dub = max(0.0, sin(beat_phase * 2.0 - 0.85)) * 0.62;
	float pulse = (lub + dub) * (1.0 - is_dead);

	vec2 center = vec2(0.50, 0.48);
	vec2 rel = UV - center;
	float radial_scale = 1.0 - beat_amp * (pulse * 0.65 + heal_flash * 0.35);
	vec2 p_uv = center + rel * radial_scale;

	vec4 tex = texture(TEXTURE, clamp(p_uv, vec2(0.0), vec2(1.0)));
	// Mask pixels outside clean sprite bounds
	if (p_uv.x < 0.0 || p_uv.x > 1.0 || p_uv.y < 0.0 || p_uv.y > 1.0) {
		tex.a = 0.0;
	}

	vec3 col = tex.rgb;
	float a = tex.a * COLOR.a;

	if (a > 0.01) {
		float hp_clamped = clamp(hp_ratio, 0.0, 1.0);
		float drain = 1.0 - hp_clamped;

		// 1. Progressive red-color drain as health drops (vital crimson bleeds out into pale ash)
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		float red_excess = max(0.0, col.r - max(col.g, col.b));
		float crimson_mask = smoothstep(0.02, 0.22, red_excess);
		vec3 ash_stone = vec3(luma * 1.15, luma * 1.14, luma * 1.22) * mix(1.0, 0.88, drain);
		col = mix(col, ash_stone, clamp(pow(drain, 0.78) * mix(0.42, 0.98, crimson_mask), 0.0, 0.97));
		col.r = mix(col.r, min(col.r, luma * 0.92), clamp(pow(drain, 0.85) * crimson_mask * 0.90, 0.0, 0.92));

		// 2. Subtle arterial lub warmth (fades as HP drops) & candlelight specular sweep
		float sweep_diag = (p_uv.x * 0.75 - p_uv.y * 0.65) + fract(time_sec * 0.16) * 2.4 - 1.2;
		float sweep = exp(-pow(sweep_diag * 4.5, 2.0)) * 0.22 * (1.0 - is_dead);
		float heart_core_dist = length((p_uv - vec2(0.50, 0.50)) * vec2(1.15, 1.25));
		float arterial_glow = exp(-heart_core_dist * 3.4) * (0.14 + 0.26 * lub) * hp_clamped * (1.0 - is_dead);
		col += vec3(1.0, 0.28, 0.16) * arterial_glow;
		col += mix(vec3(1.0, 0.92, 0.74), accent_col.rgb, 0.45) * sweep;

		// 3. Glowing fracture veins as HP drops (amber-gold shifting cooler so drained heart loses red cleanly)
		float crack_val = texture(crack_tex, clamp(p_uv, vec2(0.0), vec2(1.0))).r;
		float core_alpha = smoothstep(0.25, 0.85, tex.a);
		float ember_flicker = 0.84 + 0.16 * sin(time_sec * 11.0 + p_uv.y * 16.0);
		vec3 crack_col = mix(vec3(0.90, 0.56, 0.18), vec3(0.96, 0.86, 0.54), clamp(crack_val + drain * 0.40, 0.0, 1.0));
		float crack_intensity = crack_val * core_alpha * clamp(crack_energy, 0.0, 3.6) * 0.68 * ember_flicker * (1.0 - is_dead);
		col = mix(col, crack_col * 1.35, clamp(crack_intensity * 0.55, 0.0, 0.85));
		col += crack_col * crack_intensity;

		// 4. Visceral Damage Hit / Heal Swell modulation
		col = mix(col, vec3(1.0, 0.24, 0.22) * 1.25, clamp(damage_flash * 0.65, 0.0, 0.72));
		col = mix(col, vec3(1.0, 0.86, 0.44) * 1.18, clamp(heal_flash * 0.55, 0.0, 0.65));

		// 5. Dead Ash / Obsidian Fracture State at 0 HP
		if (is_dead > 0.01) {
			float gray = dot(col, vec3(0.299, 0.587, 0.114));
			vec3 ash = vec3(gray * 0.42, gray * 0.40, gray * 0.42);
			ash = mix(ash, vec3(0.05, 0.04, 0.05), crack_val * 0.75);
			col = mix(col, ash, is_dead);
		}
	}

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.8)) * COLOR.rgb, a);
}
