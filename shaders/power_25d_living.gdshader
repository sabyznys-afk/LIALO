shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Living Animated 2.5D Diorama & Creature Shader
// Drives per-element motion (vertex wing flapping, liquid blood flow, pulsing rubies,
// crackling tempest runes & clouds, phoenix heat-shimmer, mirror water-glass ripples)
// while keeping crisp 15th-century woodcut black ink outlines intact.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_col : source_color = vec4(0.95, 0.25, 0.28, 1.0);

// 0 = Vampire Chalice (liquid blood flow + pulsing rubies)
// 1 = Storm Spear (swirling storm clouds + strobing cyan lightning/runes)
// 2 = Ash Phoenix (vertex wing-flap + flickering molten flame/chest sun rune)
// 3 = Mirror Gate (undulating liquid-mirror glass ripple + shimmering arch runes)
// 4 = Gothic Bat (fast vertex 3D wing-flap)
// 5 = Spinning Eclipse Halo Ring (pulsing scarlet corona flare)
uniform int anim_mode = 0;
uniform float time_sec = 0.0;
uniform float rune_glow : hint_range(0.0, 6.0) = 1.8;
uniform float sheen_pos : hint_range(-1.0, 2.0) = -0.4;
uniform float sheen_strength : hint_range(0.0, 4.0) = 1.4;
uniform float flash_white : hint_range(0.0, 1.0) = 0.0;
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

void vertex() {
	if (anim_mode == 2) {
		// Organic 3D wing-beat along wing span while keeping central crowned head steady
		float wing_dist = max(0.0, abs(UV.x - 0.5) - 0.14) / 0.36;
		float flap = sin(time_sec * 9.5 - wing_dist * 2.4);
		VERTEX.y += flap * wing_dist * 0.085;
		VERTEX.z += flap * wing_dist * 0.115;
	} else if (anim_mode == 4) {
		// Crisp rapid bat wing-flap (use sheen_pos as per-bat phase offset!)
		float wing_dist = abs(UV.x - 0.5) / 0.5;
		float flap = sin(time_sec * 20.0 + sheen_pos * 6.28318 - wing_dist * 1.6);
		VERTEX.y += flap * wing_dist * 0.08;
		VERTEX.z += abs(flap) * wing_dist * 0.06;
	}
}

void fragment() {
	vec2 uv = UV;

	if (anim_mode == 0) {
		// Swirling crimson blood liquid rising from chalice top (UV.y < 0.46)
		if (uv.y < 0.46) {
			float falloff = smoothstep(0.46, 0.12, uv.y);
			float wave_x = sin(uv.y * 22.0 - time_sec * 7.5 + uv.x * 6.0) * 0.011 * falloff;
			float wave_y = cos(uv.x * 16.0 - time_sec * 5.2) * 0.006 * falloff;
			uv += vec2(wave_x, wave_y);
		}
	} else if (anim_mode == 1) {
		// Swirling storm clouds enveloping spear sides
		float cloud_mask = smoothstep(0.10, 0.26, abs(uv.x - 0.5)) * smoothstep(0.18, 0.32, uv.y) * (1.0 - smoothstep(0.62, 0.78, uv.y));
		uv.x += sin(uv.y * 16.0 - time_sec * 6.5) * 0.008 * cloud_mask;
		uv.y += cos(uv.x * 14.0 + time_sec * 5.0) * 0.005 * cloud_mask;
	} else if (anim_mode == 2) {
		// Rising molten heat-shimmer near flames/edges
		float outer = smoothstep(0.20, 0.48, length(uv - vec2(0.5, 0.44)));
		uv.x += sin(uv.y * 26.0 - time_sec * 9.0) * 0.005 * outer;
	} else if (anim_mode == 3) {
		// Liquid dimensional ripple inside Mirror Gate glass pane
		float in_glass = smoothstep(0.24, 0.30, uv.x) * (1.0 - smoothstep(0.70, 0.76, uv.x)) * smoothstep(0.28, 0.36, uv.y) * (1.0 - smoothstep(0.76, 0.84, uv.y));
		uv.x += sin(uv.y * 24.0 - time_sec * 5.5) * 0.0065 * in_glass;
		uv.y += cos(uv.x * 22.0 + time_sec * 4.4) * 0.0045 * in_glass;
	}

	uv = clamp(uv, vec2(0.002), vec2(0.998));
	vec4 tex = texture(albedo_tex, uv);

	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float max_c = max(tex.r, max(tex.g, tex.b));
	float min_c = min(tex.r, min(tex.g, tex.b));
	float sat = (max_c > 0.001) ? (max_c - min_c) / max_c : 0.0;
	float ink_mask = 1.0 - smoothstep(0.08, 0.36, luma);

	vec3 base = tex.rgb * mix(tint_col.rgb, vec3(1.0), ink_mask * 0.90);
	vec3 emit_add = vec3(0.0);

	if (anim_mode == 0) {
		// Vampire Chalice: flowing crimson blood liquid + pulsing glowing rubies
		float is_red = smoothstep(1.20, 1.65, tex.r / max(0.05, max(tex.g, tex.b))) * smoothstep(0.18, 0.48, tex.r);
		float blood_flow_mask = is_red * smoothstep(0.47, 0.34, UV.y);
		float flow_band = 0.5 + 0.5 * sin(UV.y * 24.0 - time_sec * 8.5 + UV.x * 10.0);
		float ruby_mask = is_red * smoothstep(0.42, 0.50, UV.y);
		float ruby_beat = pow(0.5 + 0.5 * sin(time_sec * 5.4), 2.0);
		base += vec3(0.30, 0.02, 0.06) * (blood_flow_mask * flow_band * 0.65 + ruby_mask * ruby_beat * 0.85);
		emit_add += vec3(1.0, 0.14, 0.24) * (blood_flow_mask * (0.55 + 0.85 * flow_band) + ruby_mask * (1.2 + 1.8 * ruby_beat));
	} else if (anim_mode == 1) {
		// Storm Spear: crackling electric-cyan plasma & glowing runes
		float is_cyan = smoothstep(1.12, 1.55, tex.b / max(0.05, tex.r)) * smoothstep(0.25, 0.60, tex.g);
		float crackle = 0.55 + 0.45 * abs(sin(time_sec * 18.0 + UV.y * 14.0));
		emit_add += vec3(0.32, 0.92, 1.0) * is_cyan * (1.1 + 1.6 * crackle);
	} else if (anim_mode == 2) {
		// Ash Phoenix: flickering molten fire ribbons & glowing chest sun-rune
		float is_flame = smoothstep(1.30, 2.0, tex.r / max(0.05, tex.b)) * smoothstep(0.42, 0.85, tex.r);
		float flicker = 0.65 + 0.35 * sin(time_sec * 12.0 - UV.y * 12.0 + UV.x * 8.0);
		emit_add += vec3(1.0, 0.58, 0.14) * is_flame * flicker * 1.15;
	} else if (anim_mode == 3) {
		// Mirror Gate: luminous icy-blue mirror shimmer + golden rune bevel pulse
		float is_ice = smoothstep(0.95, 1.25, tex.b / max(0.05, tex.r)) * smoothstep(0.42, 0.82, luma);
		float ripple_glint = pow(0.5 + 0.5 * sin(UV.y * 22.0 - time_sec * 6.0 + UV.x * 8.0), 3.0);
		emit_add += vec3(0.48, 0.90, 1.0) * is_ice * (0.55 + 0.95 * ripple_glint);
	} else if (anim_mode == 5) {
		// Spinning Crimson Eclipse Ring corona flare
		float flare = 0.65 + 0.35 * sin(time_sec * 4.8 + atan(UV.y - 0.5, UV.x - 0.5) * 6.0);
		float is_red = smoothstep(1.18, 1.60, tex.r / max(0.05, tex.b));
		emit_add += vec3(0.95, 0.14, 0.22) * is_red * (0.65 + 0.75 * flare);
	}

	// Shared sweeping sheen & subtle fresnel rim
	float along = 1.0 - uv.y;
	float sheen_band = exp(-pow((along - sheen_pos) / 0.14, 2.0)) * (1.0 - ink_mask * 0.85);
	float fres = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = smoothstep(0.35, 0.92, fres) * (1.0 - ink_mask) * 0.35;
	base = mix(base, vec3(1.0, 0.97, 0.92), clamp(flash_white + sheen_band * 0.45, 0.0, 1.0) * (1.0 - ink_mask * 0.7));

	float alpha = tex.a * tint_col.a * opacity;
	if (dissolve > 0.001) {
		float n_mist = value_noise(uv * 14.0 + vec2(0.0, -TIME * 1.4)) * 0.72 + value_noise(uv * 29.0) * 0.28;
		float cut = dissolve * 1.25 - mix(0.0, 0.22, ink_mask);
		alpha *= smoothstep(cut - 0.10, cut + 0.08, n_mist);
	}

	float vis_mask = smoothstep(0.1, 0.5, alpha);
	float rune_mask = smoothstep(0.22, 0.62, sat) * smoothstep(0.24, 0.85, luma);
	ALBEDO = base;
	EMISSION = (emit_add + glow_col.rgb * (rune_mask * rune_glow * 0.45 + sheen_band * sheen_strength * 0.7 + rim + flash_white * 1.1)) * vis_mask;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
