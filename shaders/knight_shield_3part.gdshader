shader_type canvas_item;

// Illuminated Medieval Golden 3-Part Knight Aegis Shield Shader
// Maps UV coordinates cleanly across 3 shield compartments:
//  - Seg 0 (1/3): Upper-left wing
//  - Seg 1 (2/3): Upper-right wing
//  - Seg 2 (3/3): Lower bastion tip
// Uncharged compartments show weathered dark bronze-iron; charged ones blaze in forged antique gold.

uniform float charge_level : hint_range(0.0, 3.0) = 0.0;
uniform float pulse_energy : hint_range(0.0, 1.5) = 0.0;
uniform float time_sec : hint_range(0.0, 10000.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float ink_mask = 1.0 - smoothstep(0.08, 0.34, luma);

	// Outer decorative frame vs interior 3 compartments
	float in_y = smoothstep(0.14, 0.18, UV.y);
	float in_x = smoothstep(0.16, 0.21, UV.x) * (1.0 - smoothstep(0.79, 0.84, UV.x));
	float interior = in_y * in_x;

	float seg_idx = 2.0;
	if (UV.y < 0.525) {
		seg_idx = (UV.x < 0.50) ? 0.0 : 1.0;
	}

	// Compare segment against charge_level (3.0 = fully forged radiant gold)
	float lit_seg = step(seg_idx + 0.5, charge_level);
	float is_full = smoothstep(2.6, 3.0, charge_level);

	// Unlit compartments become weathered dark bronze-iron while preserving cross-hatch ink detail
	vec3 dark_bronze = vec3(dot(tex.rgb, vec3(0.36, 0.34, 0.28))) * vec3(0.42, 0.40, 0.44);
	// Lit compartments keep rich metallic gold + subtle warm forge bloom
	vec3 forged_gold = mix(tex.rgb, tex.rgb * vec3(1.22, 1.08, 0.72) + vec3(0.10, 0.06, 0.0), 0.75 + is_full * 0.25);

	// Diagonal metallic sheen sweep across forged/lit gold plates
	float sweep_pos = mod(time_sec * 0.55, 2.2) - 0.5;
	float diag = (UV.x + UV.y) * 0.5;
	float glint = exp(-pow((diag - sweep_pos) / 0.09, 2.0)) * (0.24 + is_full * 0.24) * lit_seg * (1.0 - ink_mask);

	vec3 rim_gold = tex.rgb * mix(vec3(0.78, 0.72, 0.64), vec3(1.16, 1.04, 0.78), clamp(charge_level / 3.0, 0.25, 1.0));
	vec3 interior_col = mix(dark_bronze, forged_gold, lit_seg);
	vec3 final_rgb = mix(rim_gold, interior_col, interior);

	// Keep engraved black nib ink crisp at all times
	final_rgb = mix(final_rgb, tex.rgb, ink_mask * 0.92);
	final_rgb += vec3(1.0, 0.90, 0.55) * (glint + pulse_energy * 0.26 * lit_seg) * (1.0 - ink_mask * 0.75);

	COLOR = vec4(clamp(final_rgb, 0.0, 1.4), tex.a);
}
