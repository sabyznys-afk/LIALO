shader_type spatial;
// LIALO Overhauled Dark-Fantasy Card Material Shader (gl_compatibility):
// - Distinct archetype identities:
//     0 = NORMAL (illuminated aged medieval parchment & gold-leaf hairline)
//     1 = MAGE (Runecaster: animated dual counter-rotating arcane circles, floating arcane glyphs, luminous aura rim)
//     2 = KNIGHT (Mistblade: full-surface forged Damascus steel armor plate, corner iron rivets, anisotropic metallic sheen)
//     3 = MERCHANT (Guildsman: embossed burnished 24k gold-leaf bullion filigree & coin glints)
//     4 = THIEF (Cutpurse: dark smoked obsidian shadow-cloak & phantom twin razor glints)
// - Power Cards: stark ink-contrast frame + flaring arcane pressure rim
// - Card Backs (`is_back > 0.5`): embossed metallic foil + velvet/leather sheen tailored per deck set!

uniform vec4 albedo : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_texture = false;
uniform int edition_id = 0; // 0=Normal, 1=Mage, 2=Knight, 3=Merchant, 4=Thief
uniform float hover_glow = 0.0;
uniform vec2 tilt_vec = vec2(0.0, 0.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.84, 0.32, 1.0);
uniform float is_power_card = 0.0;
uniform float is_back = 0.0;
uniform float debuffed = 0.0;
uniform float playable = 1.0;
uniform float mage_charge = 0.0;
uniform float mist_shroud = 0.0;

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
	vec2 uv = UV;
	// Subtle live magical UV ripple along outer edges of Mage cards
	if (edition_id == 1 && is_back < 0.5) {
		float edge_w = smoothstep(0.28, 0.48, length(uv - vec2(0.5)));
		float mag_wave = sin(uv.y * 24.0 - TIME * 4.2 + uv.x * 10.0) * 0.0028 * (0.4 + mage_charge * 0.8) * edge_w;
		uv = clamp(uv + vec2(mag_wave, mag_wave * 0.6), vec2(0.002), vec2(0.998));
	}

	vec4 tex_c = albedo;
	if (use_texture) {
		float tint_mix = (is_back > 0.5) ? 0.04 : 0.14;
		tex_c = texture(albedo_tex, uv) * vec4(mix(vec3(1.0), albedo.rgb, tint_mix), 1.0);
		tex_c.rgb *= (is_back > 0.5) ? 0.90 : 0.82;
		tex_c.a = 1.0;
	}

	vec3 base = tex_c.rgb;
	vec3 fx_emit = vec3(0.0);
	float out_metallic = 0.08;
	float out_roughness = 0.68;

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float border_dist = min(edge_x, edge_y);
	float rim_mask = smoothstep(0.095, 0.012, border_dist);

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float view_dot = dot(VIEW.xy, vec2(0.85, 0.65));
	float tilt_shift = dot(uv - 0.5, tilt_vec * 2.5) + view_dot * 0.68;

	// Embossed border relief
	vec2 light_dir = normalize(vec2(-0.6, -0.8) + tilt_vec * 0.65);
	float bevel_in = smoothstep(0.056, 0.032, border_dist) - smoothstep(0.032, 0.012, border_dist);
	vec2 edge_n = vec2(uv.x < 0.5 ? -1.0 : 1.0, uv.y < 0.5 ? -1.0 : 1.0) * vec2(step(edge_x, edge_y), step(edge_y, edge_x));
	float relief = dot(edge_n, -light_dir) * bevel_in;
	base += vec3(0.11, 0.09, 0.06) * relief;

	float hairline = smoothstep(0.0040, 0.0, abs(border_dist - 0.042));
	vec3 gold_leaf = mix(vec3(0.82, 0.62, 0.24), accent_color.rgb, is_power_card * 0.65);

	// Sweeping parchment / foil specular sheen
	float sheen_coord = (uv.x * 0.62 - uv.y * 0.78) + tilt_shift * 0.92 + sin(TIME * 0.42) * 0.08;
	float sheen = smoothstep(0.11, 0.0, abs(fract(sheen_coord) - 0.5));
	float paper_grain = vnoise(uv * 115.0) * 0.55 + vnoise(uv * 34.0) * 0.45;
	float gild = sheen * (0.35 + paper_grain * 0.65) * (0.28 + hover_glow * 0.58 + length(tilt_vec) * 0.40);

	if (is_back > 0.5) {
		// CARD BACK MODE: Rich embossed metallic foil lines + velvety tactile depth
		float luma_b = dot(base, vec3(0.299, 0.587, 0.114));
		float foil_mask = smoothstep(0.46, 0.74, luma_b);
		out_metallic = mix(0.14, 0.78, foil_mask);
		out_roughness = mix(0.74, 0.24, foil_mask);
		fx_emit += base * foil_mask * (0.12 + sheen * 0.62 + fresnel * 0.25);
		fx_emit += gold_leaf * hairline * (0.18 + sheen * 0.45);
	} else {
		// CARD FRONT MODE
		fx_emit += vec3(1.0, 0.86, 0.55) * gild * 0.26;
		base = mix(base, gold_leaf, hairline * 0.75);
		fx_emit += gold_leaf * hairline * (0.10 + sheen * 0.55);
		out_roughness = mix(0.82, 0.48, hairline);
		out_metallic = hairline * 0.42;

		// POWER CARDS: Stark high-contrast obsidian inner frame + flaring arcane pressure aura
		if (is_power_card > 0.5) {
			float ink_frame = smoothstep(0.052, 0.036, border_dist) * (1.0 - smoothstep(0.022, 0.010, border_dist));
			float aura_n = vnoise(vec2(uv.x * 9.0, uv.y * 14.0 - TIME * 2.2));
			float aura_n2 = vnoise(vec2(uv.x * 16.0 + TIME * 1.1, uv.y * 22.0 - TIME * 3.4));
			float aura_flare = smoothstep(0.32, 0.82, aura_n * 0.6 + aura_n2 * 0.4);
			if (!use_texture) {
				base = mix(base * 0.78, accent_color.rgb * 0.30 + vec3(0.05, 0.04, 0.06), 0.58);
			}
			base = mix(base, vec3(0.02, 0.015, 0.025), ink_frame * 0.82);
			fx_emit += accent_color.rgb * (rim_mask * (0.38 + aura_flare * 0.72 + hover_glow * 0.45) + fresnel * 0.35);
			out_metallic = max(out_metallic, 0.32 + ink_frame * 0.45);
			out_roughness = min(out_roughness, 0.32);
		}

		// ARCHETYPE 1: MAGE (Runecaster) — Luminous Magical Aura Border, Drifting Flame Wisps & Arcane Circles
		if (edition_id == 1) {
			vec2 p = (uv - vec2(0.5, 0.48)) * vec2(1.0, 1.45);
			float r = length(p);
			float a = atan(p.y, p.x);
			float spin1 = a + TIME * (1.1 + mage_charge * 1.6);
			float spin2 = a - TIME * (0.85 + mage_charge * 1.2);
			float outer_ring = smoothstep(0.014, 0.002, abs(r - 0.39));
			float inner_ring = smoothstep(0.011, 0.002, abs(r - 0.27));
			float glyphs = smoothstep(0.45, 0.82, sin(spin1 * 12.0) * sin(r * 42.0)) * smoothstep(0.055, 0.0, abs(r - 0.33));
			// Sacred hexagram arcane geometric star spokes
			float star = smoothstep(0.015, 0.002, abs(r - (0.24 + 0.07 * cos(spin2 * 6.0))));
			float wisp1 = vnoise(vec2(uv.x * 7.5 + sin(TIME * 0.9), uv.y * 12.0 - TIME * 2.6));
			float wisp2 = vnoise(vec2(uv.x * 13.0 - TIME * 0.7, uv.y * 18.0 - TIME * 3.8));
			float flame_wisps = smoothstep(0.32, 0.86, wisp1 * 0.58 + wisp2 * 0.42);
			float pulse = 0.62 + 0.38 * sin(TIME * (3.2 + mage_charge * 4.5));
			float aura_band = smoothstep(0.145, 0.012, border_dist);
			float outer_halo = smoothstep(0.045, 0.003, border_dist);
			vec3 violet_aura = vec3(0.56, 0.22, 1.0);
			vec3 cyan_aura = vec3(0.20, 0.94, 1.0);
			vec3 mage_c = mix(violet_aura, cyan_aura, clamp(mage_charge * 0.55 + flame_wisps * 0.60 + 0.18 * sin(TIME * 2.1 + uv.y * 6.0), 0.0, 1.0));
			float magic_mask = clamp(outer_ring + inner_ring * 0.85 + glyphs * 1.10 + star * 0.70, 0.0, 1.35);
			// Subtle arcane tint in center so card art stays crisp & legible, strong luminous aura on border
			base = mix(base, mage_c * 0.28 + base * 0.80, 0.14 + aura_band * 0.24 + mage_charge * 0.10);
			vec3 border_glow = mage_c * (rim_mask * (1.05 + flame_wisps * 0.95) + outer_halo * (0.85 + pulse * 0.55) + aura_band * flame_wisps * 0.52);
			vec3 circle_glow = mage_c * (magic_mask * (0.34 + mage_charge * 0.58));
			fx_emit += (border_glow + circle_glow + mage_c * fresnel * 0.65) * (0.78 + pulse * 0.36 + mage_charge * 0.45);
			out_metallic = 0.22;
			out_roughness = 0.26;
		}
		// ARCHETYPE 2: KNIGHT (Mistblade) — Full-Surface Forged Damascus Steel Armor Plate & Corner Rivets
		else if (edition_id == 2) {
			// Damascus steel swirling forged grain + cold brushed anisotropic sheen across the entire card
			float damascus_w = sin(uv.x * 38.0 + vnoise(uv * 11.0) * 7.5) * 0.5 + 0.5;
			float brushed = vnoise(vec2(uv.x * 165.0, uv.y * 14.0));
			float plate_frame = smoothstep(0.095, 0.052, border_dist);
			float inner_groove = smoothstep(0.008, 0.001, abs(border_dist - 0.078));
			// 4 hammered iron corner rivets
			vec2 corner_uv = abs(uv - vec2(0.5)) - vec2(0.415, 0.442);
			float rivet = smoothstep(0.022, 0.011, length(corner_uv * vec2(1.0, 1.45)));
			float rivet_hi = smoothstep(0.014, 0.004, length((corner_uv + vec2(0.004, 0.004)) * vec2(1.0, 1.45)));
			// Bold diagonal polished-metal specular sweeps with tilt
			float steel_sweep = (uv.x * 0.85 + uv.y * 0.48) - TIME * 0.24 + tilt_shift * 1.25;
			float razor_band = smoothstep(0.085, 0.0, abs(fract(steel_sweep) - 0.5));
			float second_sweep = smoothstep(0.045, 0.0, abs(fract(steel_sweep + 0.33) - 0.5)) * 0.55;
			float spec_sweep = clamp(razor_band + second_sweep, 0.0, 1.0);
			vec3 steel_plate = mix(vec3(0.46, 0.52, 0.60), vec3(0.82, 0.88, 0.96), damascus_w * 0.50 + brushed * 0.50);
			// Forged brushed steel armor metal tint across entire card while keeping rank/suit crisp
			base = mix(base * vec3(0.84, 0.90, 0.98), steel_plate, clamp(plate_frame * 0.86 + 0.22, 0.0, 0.94));
			base = mix(base, vec3(0.08, 0.11, 0.16), inner_groove * 0.92);
			base = mix(base, vec3(0.78, 0.84, 0.92), rivet * 0.94);
			base += vec3(0.34, 0.40, 0.48) * rivet_hi;
			fx_emit += mix(vec3(0.62, 0.84, 1.0), vec3(0.96, 0.99, 1.0), spec_sweep) * (spec_sweep * 0.62 + plate_frame * 0.16 + rim_mask * 0.22 + fresnel * 0.38 + rivet_hi * 0.28);
			out_metallic = mix(0.82, 0.96, clamp(plate_frame + rivet + spec_sweep * 0.45, 0.0, 1.0));
			out_roughness = mix(0.24, 0.14, clamp(spec_sweep + plate_frame * 0.65, 0.0, 1.0));
		}
		// ARCHETYPE 3: MERCHANT (Guildsman) — Burnished 24k Embossed Gold Bullion & Coin Medallions
		else if (edition_id == 3) {
			float liquid = vnoise(uv * 6.5 + vec2(TIME * 0.26, -TIME * 0.18) + tilt_vec);
			vec3 gold_c = vec3(1.0, 0.82, 0.24);
			float shimmer = smoothstep(0.50, 0.86, liquid + tilt_shift * 0.32);
			float coin_trim = smoothstep(0.007, 0.001, abs(border_dist - 0.068));
			base = mix(base, gold_c * 0.50 + base * 0.55, 0.22 + rim_mask * 0.38);
			fx_emit += gold_c * (0.16 + shimmer * 0.48 + rim_mask * 0.40 + coin_trim * 0.45 + fresnel * 0.26);
			out_metallic = 0.84;
			out_roughness = 0.20;
		}
		// ARCHETYPE 4: THIEF (Cutpurse) — Obsidian Shadow-Cloak & Phantom Twin Razor Glints
		else if (edition_id == 4) {
			float slash1 = smoothstep(0.020, 0.0, abs((uv.x * 0.92 - uv.y * 0.72) - 0.06 + sin(TIME * 2.1) * 0.06));
			float slash2 = smoothstep(0.014, 0.0, abs((uv.x * 0.88 - uv.y * 0.76) + 0.12 - cos(TIME * 1.8) * 0.05));
			vec3 thief_c = mix(vec3(0.14, 0.92, 0.56), vec3(0.96, 0.18, 0.32), clamp(rim_mask * 0.65 + slash2, 0.0, 1.0));
			base = mix(base, vec3(0.05, 0.08, 0.09), 0.32 + rim_mask * 0.32);
			fx_emit += thief_c * (0.14 + slash1 * 0.65 + slash2 * 0.52 + rim_mask * 0.42 + fresnel * 0.30);
			out_metallic = 0.46;
			out_roughness = 0.24;
		}

		// Hover + Playable crisp rim-light
		fx_emit += accent_color.rgb * (rim_mask * hover_glow * 0.68 + fresnel * hover_glow * 0.25);
		fx_emit += vec3(1.0, 0.88, 0.50) * smoothstep(0.018, 0.004, border_dist) * playable * 0.12;
		base = clamp(base + hover_glow * 0.05, 0.0, 1.0);

		// Unplayable: subtle desaturation & dim
		if (playable < 0.5) {
			float l = dot(base, vec3(0.299, 0.587, 0.114));
			base = mix(base, vec3(l) * 0.80, 0.42);
			fx_emit *= 0.50;
		}

		// Boss Modifier Debuff Overlay
		if (debuffed > 0.5) {
			float luma = dot(base, vec3(0.299, 0.587, 0.114));
			base = mix(base, vec3(luma * 0.52, luma * 0.44, luma * 0.46), 0.62);
			float crack1 = smoothstep(0.016, 0.0, abs((uv.x - uv.y * 0.72) - 0.14 + sin(uv.y * 22.0) * 0.025));
			float crack2 = smoothstep(0.014, 0.0, abs((uv.x + uv.y * 0.68) - 0.82 + cos(uv.x * 19.0) * 0.022));
			float x_bar1 = smoothstep(0.022, 0.006, abs((uv.x - 0.5) * 1.15 - (uv.y - 0.5))) * step(abs(uv.x - 0.5), 0.34) * step(abs(uv.y - 0.5), 0.34);
			float x_bar2 = smoothstep(0.022, 0.006, abs((uv.x - 0.5) * 1.15 + (uv.y - 0.5))) * step(abs(uv.x - 0.5), 0.34) * step(abs(uv.y - 0.5), 0.34);
			float scar = clamp(crack1 + crack2 + (x_bar1 + x_bar2) * 0.75, 0.0, 1.0);
			base = mix(base, vec3(0.32, 0.06, 0.08), scar * 0.85);
			fx_emit = mix(fx_emit * 0.25, vec3(0.68, 0.12, 0.14), scar * 0.48 + rim_mask * 0.32);
		}

		// Knight Battle Mist Shroud Veil
		if (mist_shroud > 0.05) {
			float f1 = vnoise(uv * 4.5 + vec2(TIME * 0.45, -TIME * 0.28));
			float f2 = vnoise(uv * 9.0 + vec2(-TIME * 0.32, TIME * 0.52));
			float swirl = clamp(f1 * 0.6 + f2 * 0.4, 0.0, 1.0);
			vec3 fog_c = mix(vec3(0.24, 0.30, 0.38), vec3(0.68, 0.78, 0.86), swirl);
			base = mix(base, fog_c, clamp(mist_shroud * (0.86 + swirl * 0.14), 0.0, 0.96));
			fx_emit = mix(fx_emit, fog_c * (0.35 + swirl * 0.35), clamp(mist_shroud, 0.0, 1.0));
		}
	}

	ALBEDO = base;
	ROUGHNESS = out_roughness;
	METALLIC = out_metallic;
	EMISSION = fx_emit;
}
