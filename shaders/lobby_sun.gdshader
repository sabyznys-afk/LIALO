shader_type canvas_item;
// Ultra-smooth Volumetric Golden Sun & Crepuscular Rays on Black Lobby Canvas (GL Compatibility)
// Uses continuous exponential falloff & smooth harmonic angular modulation with zero stepped bands.

uniform vec2 sun_center_uv = vec2(0.5, 0.255);
uniform float sun_prog : hint_range(0.0, 1.0) = 1.0;
uniform float aspect_ratio = 1.778;

void fragment() {
	vec2 d = UV - sun_center_uv;
	d.x *= aspect_ratio;
	float r = length(d);
	float ang = atan(d.y, d.x);

	// Smooth continuous multi-scale exponential solar corona (zero concentric polygon steps!)
	float pulse = 1.0 + sin(TIME * 1.35) * 0.032;
	float pr = r / max(0.001, sun_prog * pulse);

	float core_glow = exp(-pr * 11.5);
	float mid_bloom = exp(-pr * 4.4) * 0.58;
	float wide_halo = exp(-pr * 1.85) * 0.24;

	// Silky organic solar beams feathering out smoothly with zero hard edges
	float beam_a = pow(0.5 + 0.5 * sin(ang * 10.0 + TIME * 0.16), 2.4);
	float beam_b = pow(0.5 + 0.5 * sin(ang * 6.0 - TIME * 0.11 + 1.3), 3.0);
	float ray_mask = exp(-pr * 2.75) * (beam_a * 0.16 + beam_b * 0.11) * smoothstep(0.02, 0.10, r);

	// Faint subtle gossamer astrolabe whisper ring fading smoothly both sides
	float ring_r = 0.215 * sun_prog;
	float gossamer = exp(-pow((r - ring_r) * 78.0, 2.0)) * 0.10 * smoothstep(0.25, 0.85, sun_prog);

	float total = (core_glow + mid_bloom + wide_halo + ray_mask + gossamer) * sun_prog;
	// Slight gentle radial edge vignette so wide bloom melts cleanly into deep black
	total *= smoothstep(0.95, 0.18, r);

	vec3 col_core = vec3(1.00, 0.94, 0.72);
	vec3 col_amber = vec3(0.96, 0.66, 0.22);
	vec3 col_deep = vec3(0.58, 0.28, 0.08);
	vec3 grad_col = mix(col_deep, col_amber, clamp(mid_bloom * 1.8 + ray_mask * 2.2, 0.0, 1.0));
	grad_col = mix(grad_col, col_core, clamp(core_glow * 1.15, 0.0, 1.0));

	COLOR = vec4(grad_col * total, clamp(total, 0.0, 1.0));
}
