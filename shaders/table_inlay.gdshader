shader_type spatial;
render_mode cull_back;
// Living Woodcut Duelist Table Inlay: carved compass rosette, inked woodblock grain & glowing runic pulse.

uniform sampler2D cloth_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float mat_radius = 1.36;
uniform vec4 base_cloth_col : source_color = vec4(0.15, 0.065, 0.075, 1.0);
uniform vec4 inlay_gold_col : source_color = vec4(0.84, 0.65, 0.28, 1.0);
uniform vec4 trim_border_col : source_color = vec4(0.055, 0.038, 0.032, 1.0);
uniform float pulse_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec4 pulse_col : source_color = vec4(1.0, 0.72, 0.24, 1.0);

varying vec2 local_p;

void vertex() {
	local_p = VERTEX.xz / max(0.01, mat_radius);
}

void fragment() {
	vec2 p = local_p;
	float r = length(p);
	float ang = atan(p.y, p.x);

	vec3 tex_sample = texture(cloth_tex, (p * 0.5 + 0.5) * 3.6).rgb;
	float weave = (tex_sample.r * 0.45 + tex_sample.g * 0.35 + tex_sample.b * 0.20);

	// Hand-carved woodblock ink rings and radial woodcut burin shading across the felt mat
	float radial_etch = smoothstep(0.18, 0.55, abs(sin(r * 68.0 + sin(ang * 12.0) * 0.8)));
	float spoke_etch = smoothstep(0.24, 0.62, abs(sin(ang * 24.0 + r * 8.0)));
	float woodcut_tex = mix(0.84, 1.0, radial_etch * mix(0.86, 1.0, spoke_etch));

	// Rich crimson-mahogany & midnight-indigo duelist mat shaded with woodcut grain
	vec3 col = mix(base_cloth_col.rgb * (0.78 + weave * 0.50), vec3(0.07, 0.06, 0.11) * (0.74 + weave * 0.46), smoothstep(0.28, 0.84, r));
	col *= woodcut_tex;

	// Darkened walnut-leather outer border with carved hatching ticks
	float leather_band = smoothstep(0.84, 0.90, r);
	col = mix(col, trim_border_col.rgb * (0.85 + weave * 0.32), leather_band);

	// Carved gold/brass concentric rings + 16-ray medieval compass rosette + recessed card slot glow
	float ring_outer = smoothstep(0.013, 0.002, abs(r - 0.835));
	float ring_inner = smoothstep(0.008, 0.001, abs(r - 0.790));
	float ring_center = smoothstep(0.008, 0.001, abs(r - 0.31));
	float ticks = step(0.86, cos(ang * 16.0)) * smoothstep(0.025, 0.002, abs(r - 0.812));
	float sub_ticks = step(0.92, cos(ang * 48.0)) * smoothstep(0.014, 0.002, abs(r - 0.770));
	float rosette = smoothstep(0.015, 0.002, abs(r - (0.20 + 0.038 * cos(ang * 8.0))));
	float cross_lines = smoothstep(0.008, 0.001, abs(p.x)) * step(abs(p.y), 0.78) * step(0.32, r);
	float cross_lines_y = smoothstep(0.008, 0.001, abs(p.y)) * step(abs(p.x), 0.78) * step(0.32, r);

	float gold_mask = clamp(ring_outer + ring_inner * 0.75 + ring_center * 0.80 + ticks * 0.70 + sub_ticks * 0.45 + rosette * 0.65 + (cross_lines + cross_lines_y) * 0.40, 0.0, 1.0);
	float foil_shimmer = 0.84 + 0.20 * sin(ang * 3.0 + TIME * 0.9);
	col = mix(col, inlay_gold_col.rgb * foil_shimmer, gold_mask * 0.88);

	// Subtle recessed deck / discard zone dark bevels
	vec2 deck_d = abs(VERTEX.xz - vec2(-0.46, 0.04));
	float deck_box = smoothstep(0.02, 0.0, max(deck_d.x - 0.12, deck_d.y - 0.165)) - smoothstep(0.02, 0.0, max(deck_d.x - 0.105, deck_d.y - 0.15));
	vec2 disc_d = abs(VERTEX.xz - vec2(0.18, 0.02));
	float disc_box = smoothstep(0.02, 0.0, max(disc_d.x - 0.13, disc_d.y - 0.175)) - smoothstep(0.02, 0.0, max(disc_d.x - 0.115, disc_d.y - 0.16));
	col = mix(col, inlay_gold_col.rgb * 0.95, clamp(deck_box + disc_box, 0.0, 1.0) * 0.68);

	col *= mix(1.16, 0.76, smoothstep(0.18, 0.96, r));
	float pulse_ring = smoothstep(0.055, 0.005, abs(r - (0.22 + fract(TIME * 0.45) * 0.55))) * pulse_strength;
	float spec_burn = smoothstep(0.58, 0.0, r) * pulse_strength * 0.30;

	ALBEDO = col;
	ROUGHNESS = mix(0.86, 0.38, gold_mask);
	METALLIC = mix(0.05, 0.66, gold_mask);
	EMISSION = inlay_gold_col.rgb * gold_mask * 0.11 + pulse_col.rgb * (pulse_ring * 0.45 + spec_burn);
}
