shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D blade_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_col : source_color = vec4(0.30, 0.92, 1.0, 1.0);
uniform float rune_glow : hint_range(0.0, 5.0) = 1.65;
uniform float sheen_pos : hint_range(-0.5, 1.6) = -0.5;
uniform float sheen_width : hint_range(0.03, 0.45) = 0.14;
uniform float sheen_strength : hint_range(0.0, 4.0) = 1.65;
uniform float flash_white : hint_range(0.0, 1.0) = 0.0;
uniform float boil_amp : hint_range(0.0, 0.015) = 0.0015;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	float qt = floor(TIME * 12.0);
	vec2 uv_off = vec2(
		value_noise(UV * 10.0 + vec2(qt, qt * 0.7)) - 0.5,
		value_noise(UV * 10.0 + vec2(qt * 1.2 + 5.0, qt * 0.4)) - 0.5
	) * boil_amp;
	vec2 uv = clamp(UV + uv_off, vec2(0.002), vec2(0.998));

	vec4 tex = texture(blade_tex, uv);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float max_c = max(tex.r, max(tex.g, tex.b));
	float min_c = min(tex.r, min(tex.g, tex.b));
	float sat = (max_c > 0.001) ? (max_c - min_c) / max_c : 0.0;
	float ink_mask = 1.0 - smoothstep(0.08, 0.40, luma);

	// Glowing rune & bevel sheen mask (saturated steel/rune accent or bright blade glint)
	float rune_mask = smoothstep(0.20, 0.62, sat) * smoothstep(0.24, 0.85, luma);
	float along = 1.0 - uv.y; // 0 = pommel, 1 = tip
	float sheen_band = exp(-pow((along - sheen_pos) / max(0.02, sheen_width), 2.0)) * (1.0 - ink_mask * 0.85);

	// Dual-sided view-angle specular bevel kick (looks great from both +Z and -Z)
	float fres = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = smoothstep(0.35, 0.92, fres) * (1.0 - ink_mask) * 0.45;

	vec3 base = tex.rgb * mix(tint_col.rgb, vec3(1.0), ink_mask * 0.90);
	base = mix(base, vec3(1.0, 0.97, 0.90), clamp(flash_white + sheen_band * 0.55, 0.0, 1.0) * (1.0 - ink_mask * 0.65));

	float alpha = tex.a * tint_col.a * opacity;
	if (dissolve > 0.001) {
		float n_mist = value_noise(uv * 14.0 + vec2(0.0, -TIME * 1.4)) * 0.72 + value_noise(uv * 29.0) * 0.28;
		float cut = dissolve * 1.25 - mix(0.0, 0.22, ink_mask);
		alpha *= smoothstep(cut - 0.10, cut + 0.08, n_mist);
	}

	ALBEDO = base;
	EMISSION = glow_col.rgb * (rune_mask * rune_glow + sheen_band * sheen_strength + rim + flash_white * 1.1) * smoothstep(0.1, 0.5, alpha);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
