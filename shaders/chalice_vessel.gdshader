shader_type canvas_item;

uniform float progress : hint_range(0.0, 3.0) = 0.0;
uniform float heat_surge : hint_range(0.0, 2.0) = 0.0;
uniform vec4 fire_tint = vec4(0.56, 0.72, 0.92, 1.0);

void fragment() {
	float cp = clamp(progress, 0.0, 1.4);
	float surge = clamp(heat_surge, 0.0, 1.5);
	float energy = clamp(cp + surge * 0.45, 0.0, 1.5);

	// Subtle rising heat shimmer near upper rim & flames (stronger with higher points)
	float rim_mask = smoothstep(0.62, 0.10, UV.y);
	float shimmer = sin(UV.y * 36.0 - TIME * (6.0 + cp * 4.5)) * (0.0014 + energy * 0.0034) * rim_mask;
	vec2 duv = clamp(UV + vec2(shimmer, 0.0), vec2(0.001), vec2(0.999));

	vec4 tex = texture(TEXTURE, duv);
	float alpha = tex.a * COLOR.a;

	// Dynamic flickering firelight illuminating bowl & rim highlights
	float flicker = 0.78 + 0.22 * sin(TIME * 7.4 + UV.y * 9.0) * cos(TIME * 11.3 - UV.x * 8.0);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float bowl_focus = smoothstep(0.85, 0.25, length((UV - vec2(0.5, 0.36)) * vec2(1.4, 1.7)));

	vec3 lit = tex.rgb * COLOR.rgb;
	lit += fire_tint.rgb * bowl_focus * (0.08 + energy * 0.26) * flicker * (0.45 + lum * 0.75);
	// Hot golden/arcane rim gleam pulsing across vessel metal
	float sweep = exp(-pow((UV.y - fract(TIME * (0.35 + cp * 0.25))) * 8.0, 2.0)) * energy * 0.18;
	lit += fire_tint.rgb * sweep * lum;

	COLOR = vec4(lit, alpha);
}
