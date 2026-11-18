shader_type canvas_item;

uniform float heat : hint_range(0.0, 3.0) = 0.25;
uniform float charge_frac : hint_range(0.0, 1.0) = 0.15;
uniform float mult_tier : hint_range(1.0, 64.0) = 1.0;
uniform vec4 flame_core : source_color = vec4(1.0, 0.92, 0.45, 1.0);
uniform vec4 flame_mid : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 flame_outer : source_color = vec4(0.55, 0.06, 0.03, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise2(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * 2.0 - 1.0;
	p.x *= 1.35;

	float tier_norm = clamp(log(max(1.0, mult_tier)) / 3.2, 0.0, 1.0);
	float pulse = 1.0 + sin(TIME * (3.2 + heat * 1.45)) * (0.04 + clamp(heat * 0.035, 0.0, 0.12));
	float t = TIME * (1.2 + heat * 0.95 + tier_norm * 1.1);

	// Spectral palette progression: warm tavern gold -> ruby overdrive -> spectral arcane violet-cyan
	vec3 tier_outer = mix(flame_outer.rgb, vec3(0.24, 0.08, 0.62), tier_norm);
	vec3 tier_mid = mix(flame_mid.rgb, vec3(0.92, 0.24, 0.92), tier_norm * 0.85);
	vec3 tier_core = mix(flame_core.rgb, vec3(0.72, 0.96, 1.0), smoothstep(0.45, 1.0, tier_norm));

	// Swirling organic tongues rising from the brazier seal
	vec2 q = vec2(uv.x * 4.2, uv.y * 3.4 + t * 1.45);
	float n1 = fbm(q);
	float n2 = fbm(q * 1.9 - vec2(t * 0.4, -t * 0.8));
	float turb = (n1 * 0.65 + n2 * 0.35);

	// Distance from center + harmonic pulse & upward flame teardrop shaping
	vec2 fp = p / pulse;
	fp.y -= 0.08 + tier_norm * 0.04;
	fp.y /= mix(0.85, 1.35 + tier_norm * 0.25, clamp(1.0 - uv.y, 0.0, 1.0));
	float dist = length(fp + vec2((turb - 0.5) * (0.28 + heat * 0.16), (turb - 0.5) * 0.22));

	float mask = smoothstep(0.96, 0.16, dist);
	float fire_val = clamp((1.0 - dist * (1.06 - heat * 0.16)) * (1.25 + tier_norm * 0.22) + (turb - 0.42) * 0.85, 0.0, 1.7);

	vec3 col = mix(tier_outer, tier_mid, smoothstep(0.18, 0.62, fire_val));
	col = mix(col, tier_core, smoothstep(0.62, 1.15, fire_val));

	// Arcane charging rune ring around left dial center
	vec2 dial_uv = (uv - vec2(0.24, 0.54)) * vec2(2.35, 2.0);
	float dr = length(dial_uv);
	float ang = atan(dial_uv.y, dial_uv.x);
	float norm_ang = fract((ang + 1.5707963) / 6.2831853);

	float outer_track = smoothstep(0.032, 0.008, abs(dr - 0.72));
	float rune_ticks = smoothstep(0.3, 0.85, sin(ang * 16.0 - t * 1.6)) * smoothstep(0.04, 0.01, abs(dr - 0.82));
	float charged_arc = step(norm_ang, charge_frac + 0.005) * smoothstep(0.055 * pulse, 0.012, abs(dr - 0.72));

	col += vec3(0.45, 0.24, 0.08) * outer_track * (0.35 + heat * 0.25);
	col += mix(tier_mid, tier_core, charge_frac) * charged_arc * (1.2 + heat * 0.55);
	col += tier_core * rune_ticks * (0.25 + heat * 0.45);

	// Rising glowing embers scaling smoothly with heat + mult tier
	vec2 sp_uv = uv * vec2(12.0, 8.0) + vec2(0.0, t * 2.2);
	vec2 cell = floor(sp_uv);
	vec2 loc = fract(sp_uv) - 0.5;
	float rnd = hash21(cell);
	float ember_dist = length(loc - vec2((rnd - 0.5) * 0.4, sin(t * 2.0 + rnd * 6.28) * 0.2));
	float ember = smoothstep(0.18, 0.02, ember_dist) * step(0.76 - clamp(heat * 0.14 + tier_norm * 0.10, 0.0, 0.35), rnd);
	col += tier_core * ember * (0.85 + heat * 0.6);

	float edge_fade = smoothstep(1.08, 0.42, length((uv * 2.0 - 1.0) * vec2(0.95, 1.05)));
	float alpha = clamp((mask * (0.40 + heat * 0.30) + outer_track * 0.35 + charged_arc * 0.85 + ember * 0.85) * edge_fade, 0.0, 0.94);

	COLOR = vec4(col * (0.90 + heat * 0.32), alpha);
}
