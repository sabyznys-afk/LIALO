shader_type spatial;
// LIALO Dark-Fantasy Card Material Shader (gl_compatibility):
// painted textures + 5 Card Classes (Normal, Mage, Knight, Merchant, Thief),
// Knight Mist-Shroud veil, Mage Charge sigil bloom, Boss debuff fracture overlay.

uniform vec4 albedo : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_texture = false;
uniform int edition_id = 0; // 0=Normal, 1=Mage, 2=Knight, 3=Merchant, 4=Thief
uniform float hover_glow = 0.0;
uniform vec2 tilt_vec = vec2(0.0, 0.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.84, 0.32, 1.0);
uniform float is_power_card = 0.0;
uniform float debuffed = 0.0; // 1.0 when Boss Modifier taxes/debuffs this card in hand
uniform float playable = 1.0; // 0.0 = unplayable in hand (subtle desaturation)
uniform float mage_charge = 0.0; // 0.0..1.0 hand charge ratio for Mage cards
uniform float mist_shroud = 0.0; // 1.0 = Knight Battle Mist fog shrouding top discard card

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 tex_c = albedo;
	if (use_texture) {
		tex_c = texture(albedo_tex, UV) * vec4(mix(vec3(1.0), albedo.rgb, 0.14), 1.0);
		tex_c.rgb *= 0.80;
		tex_c.a = 1.0;
	}

	vec3 base = tex_c.rgb;
	vec3 fx_emit = vec3(0.0);

	float edge_x = min(UV.x, 1.0 - UV.x);
	float edge_y = min(UV.y, 1.0 - UV.y);
	float border_dist = min(edge_x, edge_y);
	float rim_mask = smoothstep(0.085, 0.015, border_dist);

	if (is_power_card > 0.5 && !use_texture) {
		float grad = sin(UV.y * 3.14159) * 0.12;
		base = mix(base * 0.88, accent_color.rgb * 0.34 + vec3(0.14, 0.11, 0.09), 0.55 + grad);
		base = mix(base, accent_color.rgb * 0.92, rim_mask * 0.52);
		fx_emit += accent_color.rgb * (0.14 + hover_glow * 0.18) * rim_mask;
	}

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.1);
	float view_dot = dot(VIEW.xy, vec2(0.85, 0.65));
	float tilt_shift = dot(UV - 0.5, tilt_vec * 2.4) + view_dot * 0.65;

	// --- Faux-embossed border relief: light from upper-left, offset by tilt ---
	vec2 light_dir = normalize(vec2(-0.6, -0.8) + tilt_vec * 0.6);
	float bevel_in = smoothstep(0.050, 0.030, border_dist) - smoothstep(0.030, 0.012, border_dist);
	vec2 edge_n = vec2(UV.x < 0.5 ? -1.0 : 1.0, UV.y < 0.5 ? -1.0 : 1.0) * vec2(step(edge_x, edge_y), step(edge_y, edge_x));
	float relief = dot(edge_n, -light_dir) * bevel_in;
	base += vec3(0.10, 0.08, 0.05) * relief;
	// stamped gold-leaf inner hairline
	float hairline = smoothstep(0.0035, 0.0, abs(border_dist - 0.040));
	vec3 gold_leaf = mix(vec3(0.78, 0.58, 0.22), accent_color.rgb, is_power_card * 0.6);

	// --- Gilded parchment specular sheen sweeping with tilt ---
	float sheen_coord = (UV.x * 0.62 - UV.y * 0.78) + tilt_shift * 0.9 + sin(TIME * 0.35) * 0.08;
	float sheen = smoothstep(0.10, 0.0, abs(fract(sheen_coord) - 0.5));
	float paper_grain = vnoise(UV * 120.0) * 0.5 + vnoise(UV * 37.0) * 0.5;
	float gild = sheen * (0.35 + paper_grain * 0.65) * (0.28 + hover_glow * 0.55 + length(tilt_vec) * 0.35);
	fx_emit += vec3(1.0, 0.86, 0.55) * gild * 0.30;
	base = mix(base, gold_leaf, hairline * 0.75);
	fx_emit += gold_leaf * hairline * (0.10 + sheen * 0.6);

	if (edition_id == 1) {
		// 1: MAGE (Runecaster) — pulsing violet-cyan rune sigils intensifying with mage_charge
		float d_c = length(UV - vec2(0.5, 0.5));
		float rune_ring = smoothstep(0.018, 0.0, abs(d_c - 0.33)) + smoothstep(0.012, 0.0, abs(d_c - 0.19));
		float pulse = 0.45 + 0.55 * sin(TIME * (2.6 + mage_charge * 4.5));
		vec3 mage_c = mix(vec3(0.46, 0.28, 0.96), vec3(0.42, 0.94, 1.0), mage_charge);
		float glow_lvl = 0.12 + mage_charge * 0.52;
		base = mix(base, mage_c * 0.35 + base * 0.65, 0.14 + mage_charge * 0.16);
		fx_emit += mage_c * (glow_lvl * (rune_ring * 1.1 + rim_mask * 0.85 + fresnel * 0.4) * (0.7 + pulse * 0.5));
	} else if (edition_id == 2) {
		// 2: KNIGHT (Mistblade) — forged silver-steel rim & subtle mist wisps
		float wisp = vnoise(UV * vec2(4.5, 6.0) + vec2(TIME * 0.35, -TIME * 0.22));
		float sweep = UV.x * 0.78 + UV.y * 0.48 - TIME * 0.16 + tilt_shift * 0.8;
		float band = smoothstep(0.08, 0.0, abs(fract(sweep) - 0.5));
		vec3 steel_c = mix(vec3(0.68, 0.84, 0.96), vec3(0.84, 0.92, 0.98), wisp);
		base = mix(base, steel_c * 0.35 + base * 0.70, 0.16 + wisp * 0.10);
		fx_emit += steel_c * (0.10 + band * 0.40 + rim_mask * 0.28 + fresnel * 0.20);
	} else if (edition_id == 3) {
		// 3: MERCHANT (Guildsman) — burnished liquid-gold leaf & coin glint
		float liquid = vnoise(UV * 5.0 + vec2(TIME * 0.22, -TIME * 0.16) + tilt_vec);
		vec3 gold_c = vec3(1.0, 0.80, 0.24);
		float shimmer = smoothstep(0.55, 0.88, liquid + tilt_shift * 0.25);
		base = mix(base, gold_c * 0.45 + base * 0.60, 0.18 + rim_mask * 0.20);
		fx_emit += gold_c * (0.14 + shimmer * 0.38 + rim_mask * 0.36 + fresnel * 0.20);
	} else if (edition_id == 4) {
		// 4: THIEF (Cutpurse) — dark emerald-obsidian stealth gleam & blade glint
		float slash = smoothstep(0.025, 0.0, abs((UV.x * 0.9 - UV.y * 0.7) - 0.08 + sin(TIME * 1.4) * 0.04));
		vec3 thief_c = mix(vec3(0.18, 0.78, 0.48), vec3(0.92, 0.26, 0.36), rim_mask * 0.5);
		base = mix(base, vec3(0.10, 0.18, 0.15), 0.22);
		fx_emit += thief_c * (0.12 + slash * 0.45 + rim_mask * 0.32 + fresnel * 0.22);
	}

	// Hover + Playable crisp rim-light
	fx_emit += accent_color.rgb * (rim_mask * hover_glow * 0.58 + fresnel * hover_glow * 0.18);
	fx_emit += vec3(1.0, 0.86, 0.48) * smoothstep(0.016, 0.004, border_dist) * playable * 0.10;
	base = clamp(base + hover_glow * 0.05, 0.0, 1.0);

	// Unplayable: subtle desaturation & dim
	if (playable < 0.5) {
		float l = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, vec3(l) * 0.82, 0.38);
		fx_emit *= 0.55;
	}

	// Boss Modifier Debuff Overlay
	if (debuffed > 0.5) {
		float luma = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, vec3(luma * 0.52, luma * 0.44, luma * 0.46), 0.62);
		float crack1 = smoothstep(0.016, 0.0, abs((UV.x - UV.y * 0.72) - 0.14 + sin(UV.y * 22.0) * 0.025));
		float crack2 = smoothstep(0.014, 0.0, abs((UV.x + UV.y * 0.68) - 0.82 + cos(UV.x * 19.0) * 0.022));
		float x_bar1 = smoothstep(0.022, 0.006, abs((UV.x - 0.5) * 1.15 - (UV.y - 0.5))) * step(abs(UV.x - 0.5), 0.34) * step(abs(UV.y - 0.5), 0.34);
		float x_bar2 = smoothstep(0.022, 0.006, abs((UV.x - 0.5) * 1.15 + (UV.y - 0.5))) * step(abs(UV.x - 0.5), 0.34) * step(abs(UV.y - 0.5), 0.34);
		float scar = clamp(crack1 + crack2 + (x_bar1 + x_bar2) * 0.75, 0.0, 1.0);
		base = mix(base, vec3(0.32, 0.06, 0.08), scar * 0.85);
		fx_emit = mix(fx_emit * 0.25, vec3(0.68, 0.12, 0.14), scar * 0.48 + rim_mask * 0.32);
	}

	// Knight Battle Mist Shroud Veil (obscures card in swirling silver-blue fog)
	if (mist_shroud > 0.05) {
		float f1 = vnoise(UV * 4.5 + vec2(TIME * 0.45, -TIME * 0.28));
		float f2 = vnoise(UV * 9.0 + vec2(-TIME * 0.32, TIME * 0.52));
		float swirl = clamp(f1 * 0.6 + f2 * 0.4, 0.0, 1.0);
		vec3 fog_c = mix(vec3(0.24, 0.30, 0.38), vec3(0.68, 0.78, 0.86), swirl);
		base = mix(base, fog_c, clamp(mist_shroud * (0.86 + swirl * 0.14), 0.0, 0.96));
		fx_emit = mix(fx_emit, fog_c * (0.35 + swirl * 0.35), clamp(mist_shroud, 0.0, 1.0));
	}

	ALBEDO = base;
	ROUGHNESS = (edition_id > 0) ? 0.26 : mix(0.85, 0.55, hairline);
	METALLIC = (edition_id == 3) ? 0.52 : (edition_id == 2 ? 0.35 : hairline * 0.4);
	EMISSION = fx_emit;
}
