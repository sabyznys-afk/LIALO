shader_type canvas_item;

uniform float progress : hint_range(0.0, 3.0) = 0.0;
uniform float heat_surge : hint_range(0.0, 2.0) = 0.0;
uniform float front_pass : hint_range(0.0, 1.0) = 0.0;

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
		p = p * 2.04 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void get_fire_palette(float p, out vec3 c_outer, out vec3 c_mid, out vec3 c_core) {
	// Stage 0 (< 20%): Cold Slate Hearth -> Kindling Blue-Amber
	vec3 o0 = vec3(0.10, 0.24, 0.44);
	vec3 m0 = vec3(0.40, 0.66, 0.92);
	vec3 k0 = vec3(0.84, 0.94, 1.00);
	// Stage 1 (20..44%): Warm Amber Hearth Fire
	vec3 o1 = vec3(0.62, 0.08, 0.02);
	vec3 m1 = vec3(1.00, 0.44, 0.08);
	vec3 k1 = vec3(1.00, 0.92, 0.46);
	// Stage 2 (45..69%): Arcane Surge Cyan Flame
	vec3 o2 = vec3(0.04, 0.22, 0.62);
	vec3 m2 = vec3(0.14, 0.78, 1.00);
	vec3 k2 = vec3(0.78, 0.98, 1.00);
	// Stage 3 (70..99%): Blazing Amethyst Inferno
	vec3 o3 = vec3(0.36, 0.04, 0.48);
	vec3 m3 = vec3(0.90, 0.24, 0.94);
	vec3 k3 = vec3(1.00, 0.80, 0.98);
	// Stage 4 (100%+): Solar Overdrive Gold-White
	vec3 o4 = vec3(0.86, 0.34, 0.04);
	vec3 m4 = vec3(1.00, 0.82, 0.20);
	vec3 k4 = vec3(1.00, 0.99, 0.86);

	if (p < 0.20) {
		float u = smoothstep(0.03, 0.20, p);
		c_outer = mix(o0, o1, u);
		c_mid = mix(m0, m1, u);
		c_core = mix(k0, k1, u);
	} else if (p < 0.45) {
		float u = smoothstep(0.20, 0.45, p);
		c_outer = mix(o1, o2, u);
		c_mid = mix(m1, m2, u);
		c_core = mix(k1, k2, u);
	} else if (p < 0.70) {
		float u = smoothstep(0.45, 0.70, p);
		c_outer = mix(o2, o3, u);
		c_mid = mix(m2, m3, u);
		c_core = mix(k2, k3, u);
	} else {
		float u = smoothstep(0.70, 1.00, p);
		c_outer = mix(o3, o4, u);
		c_mid = mix(m3, m4, u);
		c_core = mix(k3, k4, u);
	}
}

void fragment() {
	vec2 uv = UV;
	float cp = clamp(progress, 0.0, 1.4);
	float surge = clamp(heat_surge, 0.0, 1.5);
	float energy = clamp(0.16 + cp * 0.95 + surge * 0.35, 0.14, 1.45);

	vec3 c_outer;
	vec3 c_mid;
	vec3 c_core;
	get_fire_palette(cp, c_outer, c_mid, c_core);

	float t = TIME * (1.75 + cp * 1.65 + surge * 1.1);
	// Circular Sanctuary Medallion clip mask so fire stays cleanly inside the frame
	vec2 med = (uv - vec2(0.5, 0.51)) * 2.0;
	float med_r = length(med);
	float circle_clip = smoothstep(0.98, 0.72, med_r);

	if (front_pass < 0.5) {
		// BACK LAYER: Swirling brazier halo + rising flames framing the chalice
		float h_reach = mix(0.22, 0.62, clamp(cp * 0.9 + surge * 0.28, 0.0, 1.0));
		vec2 q = vec2(uv.x * 4.8 + sin(uv.y * 5.0 - t) * 0.24, uv.y * 3.8 + t * 1.55);
		float n1 = fbm(q);
		float n2 = fbm(q * 1.85 - vec2(t * 0.45, -t * 1.15));
		float turb = n1 * 0.62 + n2 * 0.38;

		// Flame teardrop anchored at chalice bowl center (0.5, 0.46) rising upward
		float dy_up = clamp((0.64 - uv.y) / max(0.20, h_reach), 0.0, 1.6);
		float plume_w = mix(0.32, 0.11, smoothstep(0.0, 1.0, dy_up)) + energy * 0.08;
		float sway = sin(uv.y * 9.0 - t * 2.2) * 0.045 * dy_up;
		float dx = abs(uv.x - 0.5 + sway + (turb - 0.5) * 0.18) / max(0.05, plume_w);
		float v_fade = smoothstep(0.84, 0.46, uv.y) * smoothstep(0.02, 0.24 + h_reach * 0.3, uv.y + (turb - 0.4) * 0.16);
		float flame = clamp((1.0 - dx * 0.88) * v_fade * (0.75 + turb * 0.95) * (0.65 + energy * 0.75), 0.0, 1.8);

		// Warm brazier aura pulsing behind the vessel
		float aura = exp(-med_r * med_r * mix(3.8, 1.75, clamp(energy * 0.75, 0.0, 1.0))) * (0.35 + energy * 0.50);

		// Rising sparks behind vessel
		vec2 sp = uv * vec2(15.0, 11.0) + vec2(sin(uv.y * 4.0 + t) * 0.5, t * 2.9);
		vec2 cell = floor(sp);
		vec2 loc = fract(sp) - 0.5;
		float rnd = hash21(cell);
		float spark = smoothstep(0.22, 0.02, length(loc)) * step(0.84 - clamp(energy * 0.16, 0.0, 0.34), rnd) * smoothstep(0.85, 0.20, uv.y);

		vec3 col = mix(c_outer, c_mid, smoothstep(0.12, 0.52, flame + aura * 0.65));
		col = mix(col, c_core, smoothstep(0.55, 1.05, flame));
		col += c_mid * aura * 0.55;
		col += c_core * spark * 1.35;

		float alpha = clamp((flame * 0.72 + aura * 0.68 + spark * 0.90) * circle_clip, 0.0, 0.96);
		COLOR = vec4(col, alpha);
	} else {
		// FRONT LAYER: Licking flames emerging right out of the goblet rim (y ~ 0.08..0.46) + front rim sparks
		float rim_y = 0.42;
		float flame_h = mix(0.14, 0.38, clamp(cp * 0.92 + surge * 0.30, 0.0, 1.0));
		float y_rel = (rim_y - uv.y) / max(0.08, flame_h);
		float in_rim_y = smoothstep(-0.18, 0.12, y_rel) * (1.0 - smoothstep(0.62, 1.18, y_rel));

		vec2 qf = vec2(uv.x * 6.5, uv.y * 5.2 + t * 2.1);
		float n_a = fbm(qf);
		float n_b = fbm(qf * 2.1 + vec2(t * 0.6, t * 1.4));
		float turb_f = n_a * 0.6 + n_b * 0.4;

		float tongue_w = mix(0.21, 0.05, clamp(y_rel, 0.0, 1.0)) + energy * 0.035;
		float flicker_x = (turb_f - 0.5) * (0.14 + y_rel * 0.12) + sin(uv.y * 14.0 - t * 3.1) * 0.025;
		float x_dist = abs(uv.x - 0.5 + flicker_x) / max(0.03, tongue_w);
		float tongue = clamp((1.0 - x_dist) * in_rim_y * (0.65 + turb_f * 1.05) * (0.45 + energy * 0.80), 0.0, 1.6);

		// Tiny glowing coals shimmer at goblet bowl top
		float rim_line = exp(-pow((uv.y - 0.36) * 14.0, 2.0)) * smoothstep(0.28, 0.06, abs(uv.x - 0.5)) * (0.28 + cp * 0.65 + surge * 0.35);

		// Rising foreground embers from goblet rim
		vec2 sp2 = uv * vec2(18.0, 14.0) + vec2(sin(t * 1.8 + uv.y * 6.0) * 0.4, t * 3.4);
		vec2 cell2 = floor(sp2);
		vec2 loc2 = fract(sp2) - 0.5;
		float rnd2 = hash21(cell2 + vec2(7.1, 3.3));
		float ember2 = smoothstep(0.18, 0.01, length(loc2)) * step(0.86 - clamp(energy * 0.15, 0.0, 0.32), rnd2) * smoothstep(0.50, 0.08, uv.y) * smoothstep(0.32, 0.08, abs(uv.x - 0.5));

		vec3 fcol = mix(c_outer, c_mid, smoothstep(0.14, 0.48, tongue + rim_line * 0.6));
		fcol = mix(fcol, c_core, smoothstep(0.50, 0.98, tongue));
		fcol += c_core * ember2 * 1.45;
		fcol += c_mid * rim_line * 0.70;

		float falpha = clamp((tongue * 0.62 + rim_line * 0.42 + ember2 * 0.88) * circle_clip, 0.0, 0.88);
		COLOR = vec4(fcol, falpha);
	}
}
