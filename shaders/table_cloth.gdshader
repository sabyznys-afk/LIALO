shader_type spatial;
render_mode cull_back;
// LIALO Duel Baize: woven velvet micro-texture, warm candle falloff, animated golden astrolabe
// rings around the discard pile and a reactive Suit Color Pulse ripple (gl_compatibility safe).

uniform sampler2D cloth_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float mat_radius = 1.38;
uniform vec4 base_cloth_col : source_color = vec4(0.15, 0.065, 0.075, 1.0);
uniform vec4 inlay_gold_col : source_color = vec4(0.84, 0.65, 0.28, 1.0);
uniform vec4 trim_border_col : source_color = vec4(0.055, 0.038, 0.032, 1.0);
uniform float pulse_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec4 pulse_col : source_color = vec4(1.0, 0.72, 0.24, 1.0);
// Suit reactivity
uniform vec4 suit_col : source_color = vec4(0.86, 0.18, 0.20, 1.0);
uniform float suit_pulse_t = 10.0;   // seconds since last suit change / slam (ripple age)
uniform float suit_pulse_power = 1.0;
uniform vec2 disc_center = vec2(0.14, 0.02); // local XZ of discard pile (metres)
uniform float overdrive = 0.0;       // 0..1 INFERNO stage glow

varying vec2 local_xz;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	vec2 p = local_xz / max(0.01, mat_radius);
	float r = length(p);
	float ang = atan(p.y, p.x);

	// --- Woven velvet / baize micro-texture ---
	vec2 wuv = local_xz * 42.0;
	float warp = 0.5 + 0.5 * sin(wuv.x * 6.2831) * sin(wuv.y * 3.1415 + floor(wuv.x) * 1.57);
	float weft = 0.5 + 0.5 * sin(wuv.y * 6.2831) * sin(wuv.x * 3.1415 + floor(wuv.y) * 1.57);
	float weave_pat = mix(warp, weft, step(0.5, fract((floor(wuv.x) + floor(wuv.y)) * 0.5)));
	vec3 tex_sample = texture(cloth_tex, local_xz * 1.3).rgb;
	float fibre = (hash(floor(local_xz * 900.0)) - 0.5) * 0.06;
	float weave = (tex_sample.r * 0.45 + tex_sample.g * 0.35 + tex_sample.b * 0.20);
	// velvet sheen: brighter at grazing view angles
	float nv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float velvet = pow(1.0 - nv, 3.0) * 0.55;

	vec3 col = mix(base_cloth_col.rgb * (0.78 + weave * 0.50), vec3(0.07, 0.06, 0.11) * (0.74 + weave * 0.46), smoothstep(0.28, 0.84, r));
	col *= 0.90 + weave_pat * 0.16 + fibre;
	col += base_cloth_col.rgb * velvet;

	// Leather border
	float leather_band = smoothstep(0.84, 0.90, r);
	col = mix(col, trim_border_col.rgb * (0.85 + weave * 0.32), leather_band);

	// --- Fixed carved gold inlay ---
	float ring_outer = smoothstep(0.013, 0.002, abs(r - 0.835));
	float ring_inner = smoothstep(0.008, 0.001, abs(r - 0.790));
	float ticks = step(0.86, cos(ang * 16.0)) * smoothstep(0.025, 0.002, abs(r - 0.812));
	float sub_ticks = step(0.92, cos(ang * 48.0)) * smoothstep(0.014, 0.002, abs(r - 0.770));
	float gold_mask = clamp(ring_outer + ring_inner * 0.75 + ticks * 0.70 + sub_ticks * 0.45, 0.0, 1.0);

	// --- Animated astrolabe rings around discard pile ---
	vec2 dp = local_xz - disc_center;
	float dr = length(dp);
	float da = atan(dp.y, dp.x);
	float a_ring1 = smoothstep(0.0045, 0.0008, abs(dr - 0.30));
	float a_ring2 = smoothstep(0.0035, 0.0006, abs(dr - 0.345));
	float a_ticks = step(0.80, cos(da * 24.0 + TIME * 0.35)) * smoothstep(0.016, 0.002, abs(dr - 0.322));
	float a_runes = step(0.93, cos(da * 8.0 - TIME * 0.22)) * smoothstep(0.012, 0.002, abs(dr - 0.372));
	float a_dash = step(0.0, sin(da * 36.0 - TIME * 0.6)) * smoothstep(0.003, 0.0005, abs(dr - 0.40));
	float astro = clamp(a_ring1 + a_ring2 * 0.8 + a_ticks * 0.8 + a_runes + a_dash * 0.6, 0.0, 1.0);
	gold_mask = max(gold_mask, astro * 0.9);

	float foil_shimmer = 0.84 + 0.20 * sin(ang * 3.0 + TIME * 0.9);
	col = mix(col, inlay_gold_col.rgb * foil_shimmer, gold_mask * 0.88);

	// --- Warm radial candle falloff (pool of light around center) ---
	float candle = 1.18 - smoothstep(0.10, 0.98, r) * 0.46;
	candle *= 0.97 + 0.03 * sin(TIME * 7.3) * sin(TIME * 3.1);
	col *= candle;
	col *= mix(1.0, 0.70, overdrive * smoothstep(0.35, 0.95, r)); // stage vignette on overdrive

	// --- Suit Color Pulse ripple (expands from discard pile) ---
	float rip_rad = suit_pulse_t * 1.25;
	float rip_fade = clamp(1.0 - suit_pulse_t / 1.4, 0.0, 1.0);
	float ripple = smoothstep(0.07, 0.0, abs(dr - rip_rad)) * rip_fade * suit_pulse_power;
	float ripple2 = smoothstep(0.04, 0.0, abs(dr - rip_rad * 0.62)) * rip_fade * 0.6 * suit_pulse_power;
	float suit_halo = smoothstep(0.42, 0.18, dr) * 0.10;

	float pulse_ring = smoothstep(0.055, 0.005, abs(r - (0.22 + fract(TIME * 0.45) * 0.55))) * pulse_strength;
	float spec_burn = smoothstep(0.58, 0.0, r) * pulse_strength * 0.30;

	ALBEDO = col;
	ROUGHNESS = mix(0.88, 0.36, gold_mask);
	METALLIC = mix(0.04, 0.68, gold_mask);
	EMISSION = inlay_gold_col.rgb * gold_mask * (0.10 + astro * 0.10)
		+ suit_col.rgb * (ripple + ripple2 + suit_halo + astro * 0.12)
		+ pulse_col.rgb * (pulse_ring * 0.45 + spec_burn)
		+ vec3(1.0, 0.55, 0.18) * overdrive * smoothstep(0.5, 0.0, dr) * 0.18;
}
