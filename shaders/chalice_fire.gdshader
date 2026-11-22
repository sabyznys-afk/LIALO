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
	// 0.00 -> Unlit Slate / Cold Ash
	vec3 o0 = vec3(0.24, 0.28, 0.36);
	vec3 m0 = vec3(0.42, 0.48, 0.58);
	vec3 k0 = vec3(0.70, 0.78, 0.88);
	// 0.01..0.25 -> First Smoldering Embers -> Deep Crimson-Orange
	vec3 o1 = vec3(0.56, 0.07, 0.02);
	vec3 m1 = vec3(0.95, 0.32, 0.05);
	vec3 k1 = vec3(1.00, 0.72, 0.26);
	// 0.25..0.55 -> Warm Orange Hearth -> Bright Gold Flame
	vec3 o2 = vec3(0.84, 0.24, 0.02);
	vec3 m2 = vec3(1.00, 0.64, 0.12);
	vec3 k2 = vec3(1.00, 0.94, 0.52);
	// 0.55..0.80 -> Blazing Incandescent Gold-White
	vec3 o3 = vec3(0.98, 0.50, 0.08);
	vec3 m3 = vec3(1.00, 0.88, 0.32);
	vec3 k3 = vec3(1.00, 0.99, 0.86);
	// 0.80..0.98 -> High-Temp Azure-White Heart Flame
	vec3 o4 = vec3(0.10, 0.42, 0.95);
	vec3 m4 = vec3(0.36, 0.88, 1.00);
	vec3 k4 = vec3(0.92, 0.99, 1.00);
	// 0.98..1.35+ -> Overdrive Royal Violet Corona + Solar Gold Core
	vec3 o5 = vec3(0.54, 0.10, 0.88);
	vec3 m5 = vec3(0.88, 0.34, 1.00);
	vec3 k5 = vec3(1.00, 0.96, 0.74);

	if (p < 0.06) {
		float u = smoothstep(0.0, 0.06, p);
		c_outer = mix(o0, o1, u);
		c_mid = mix(m0, m1, u);
		c_core = mix(k0, k1, u);
	} else if (p < 0.28) {
		float u = smoothstep(0.06, 0.28, p);
		c_outer = mix(o1, o2, u);
		c_mid = mix(m1, m2, u);
		c_core = mix(k1, k2, u);
	} else if (p < 0.58) {
		float u = smoothstep(0.28, 0.58, p);
		c_outer = mix(o2, o3, u);
		c_mid = mix(m2, m3, u);
		c_core = mix(k2, k3, u);
	} else if (p < 0.88) {
		float u = smoothstep(0.58, 0.88, p);
		c_outer = mix(o3, o4, u);
		c_mid = mix(m3, m4, u);
		c_core = mix(k3, k4, u);
	} else {
		float u = smoothstep(0.88, 1.08, p);
		c_outer = mix(o4, o5, u);
		c_mid = mix(m4, m5, u);
		c_core = mix(k4, k5, u);
	}
}

void fragment() {
	vec2 uv = UV;
	float cp = clamp(progress, 0.0, 1.45);
	float surge = clamp(heat_surge, 0.0, 1.5);
	float ignite = smoothstep(0.008, 0.14, cp + surge * 0.08);
	float growth = pow(clamp(cp * 0.92 + surge * 0.18, 0.0, 1.35), 0.85);

	vec3 c_outer;
	vec3 c_mid;
	vec3 c_core;
	get_fire_palette(cp, c_outer, c_mid, c_core);

	float t = TIME * (1.45 + growth * 1.65 + surge * 0.95);
	vec2 med = (uv - vec2(0.5, 0.50)) * 2.0;
	float med_r = length(med);
	float circle_clip = smoothstep(0.98, 0.72, med_r);

	if (ignite < 0.005) {
		COLOR = vec4(0.0);
	} else if (front_pass < 0.5) {
		// BACK LAYER: Very gradual brazier halo + flames rising slowly out of goblet cup as score climbs
		float h_reach = mix(0.11, 0.56, clamp(growth, 0.0, 1.0));
		vec2 q = vec2(uv.x * 5.2 + sin(uv.y * 5.0 - t) * 0.22, uv.y * 4.0 + t * 1.50);
		float n1 = fbm(q);
		float n2 = fbm(q * 1.85 - vec2(t * 0.45, -t * 1.15));
		float turb = n1 * 0.62 + n2 * 0.38;

		// Cup center anchor at y = 0.46; grows slowly from rim upward
		float dy_up = clamp((0.48 - uv.y) / max(0.08, h_reach), 0.0, 1.5);
		float plume_w = mix(0.24, 0.07, smoothstep(0.0, 1.0, dy_up)) * mix(0.45, 1.15, clamp(growth, 0.0, 1.0));
		float sway = sin(uv.y * 9.0 - t * 2.2) * 0.042 * dy_up;
		float dx = abs(uv.x - 0.5 + sway + (turb - 0.5) * 0.15) / max(0.04, plume_w);
		float cup_base = smoothstep(0.68, 0.44, uv.y);
		float top_env = 1.0 - smoothstep(0.55, 1.15, dy_up + (turb - 0.5) * 0.28);
		float flame = clamp((1.0 - dx * 0.90) * cup_base * top_env * (0.72 + turb * 0.92) * (0.35 + growth * 0.85), 0.0, 1.65) * ignite;

		// Surrounding chalice aura expanding smoothly from tight cup glow -> full medallion halo
		float halo_tightness = mix(5.2, 1.65, clamp(growth, 0.0, 1.0));
		float aura = exp(-med_r * med_r * halo_tightness) * mix(0.10, 0.72, clamp(growth, 0.0, 1.0)) * ignite;

		// Rising sparks behind chalice (few at low %, abundant inferno sparks near 100%)
		vec2 sp = uv * vec2(15.0, 11.0) + vec2(sin(uv.y * 4.0 + t) * 0.45, t * 2.8);
		vec2 cell = floor(sp);
		vec2 loc = fract(sp) - 0.5;
		float rnd = hash21(cell);
		float spark_thresh = mix(0.96, 0.58, clamp(growth, 0.0, 1.0));
		float spark = smoothstep(0.22, 0.02, length(loc)) * step(spark_thresh, rnd) * smoothstep(0.75, 0.12, uv.y) * ignite;

		vec3 col = mix(c_outer, c_mid, smoothstep(0.12, 0.52, flame + aura * 0.65));
		col = mix(col, c_core, smoothstep(0.52, 1.02, flame));
		col += c_mid * aura * 0.65;
		col += c_core * spark * 1.40;

		float alpha = clamp((flame * 0.78 + aura * 0.72 + spark * 0.90) * circle_clip, 0.0, 0.96);
		COLOR = vec4(col, alpha);
	} else {
		// FRONT LAYER: Delicate rim embers at low score growing gradually into tall licking goblet flames
		float rim_y = 0.43;
		float flame_h = mix(0.08, 0.42, clamp(growth, 0.0, 1.0));
		float y_rel = (rim_y - uv.y) / max(0.06, flame_h);
		float in_rim_y = smoothstep(-0.12, 0.10, y_rel) * (1.0 - smoothstep(0.62, 1.15, y_rel));

		vec2 qf = vec2(uv.x * 8.2, uv.y * 6.0 + t * 2.2);
		float n_a = fbm(qf);
		float n_b = fbm(qf * 2.1 + vec2(t * 0.65, t * 1.45));
		float turb_f = n_a * 0.6 + n_b * 0.4;

		float tongue_w = mix(0.21, 0.045, clamp(y_rel, 0.0, 1.0)) * mix(0.55, 1.22, clamp(growth, 0.0, 1.0));
		float flicker_x = (turb_f - 0.5) * (0.14 + y_rel * 0.12) + sin(uv.y * 16.0 - t * 3.2) * 0.025;
		float x_dist = abs(uv.x - 0.5 + flicker_x) / max(0.028, tongue_w);
		float tongue = clamp((1.0 - x_dist * 0.92) * in_rim_y * (0.72 + turb_f * 1.15) * (0.36 + growth * 0.95), 0.0, 1.65) * ignite;

		// Soft glowing coals resting inside the goblet mouth
		float rim_line = exp(-pow((uv.y - 0.40) * 14.0, 2.0)) * smoothstep(0.26, 0.05, abs(uv.x - 0.5)) * (0.28 + growth * 0.80) * ignite;

		// Foreground embers rising strictly from goblet rim
		vec2 sp2 = uv * vec2(18.0, 14.0) + vec2(sin(t * 1.8 + uv.y * 6.0) * 0.35, t * 3.2);
		vec2 cell2 = floor(sp2);
		vec2 loc2 = fract(sp2) - 0.5;
		float rnd2 = hash21(cell2 + vec2(7.1, 3.3));
		float ember_thresh = mix(0.96, 0.58, clamp(growth, 0.0, 1.0));
		float ember2 = smoothstep(0.18, 0.01, length(loc2)) * step(ember_thresh, rnd2) * smoothstep(0.46, 0.06, uv.y) * smoothstep(0.30, 0.06, abs(uv.x - 0.5)) * ignite;

		vec3 fcol = mix(c_outer, c_mid, smoothstep(0.12, 0.44, tongue + rim_line * 0.6));
		fcol = mix(fcol, c_core, smoothstep(0.42, 0.92, tongue));
		fcol += c_core * ember2 * 1.45;
		fcol += c_mid * rim_line * 0.78;

		float falpha = clamp((tongue * 0.78 + rim_line * 0.52 + ember2 * 0.90) * circle_clip, 0.0, 0.92);
		COLOR = vec4(fcol, falpha);
	}
}
