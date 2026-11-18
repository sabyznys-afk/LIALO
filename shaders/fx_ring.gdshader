shader_type spatial;
// Soft additive expanding shockwave ring (flat quad). Animate `progress` 0 -> 1.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 ring_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float thickness = 0.10;
uniform float intensity = 1.6;
uniform float spokes = 0.0; // >0 adds radial sunburst rays (woodcut engraving style)

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float radius = mix(0.08, 0.96, sqrt(progress));
	float w = thickness * (1.0 - progress * 0.55);
	float band = smoothstep(w, 0.0, abs(r - radius));
	float inner_glow = smoothstep(radius, 0.0, r) * 0.18 * (1.0 - progress);
	float rays = 0.0;
	if (spokes > 0.0) {
		rays = smoothstep(0.82, 1.0, abs(sin(ang * spokes))) * smoothstep(radius + 0.05, radius * 0.4, r) * smoothstep(0.0, radius * 0.5, r);
	}
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	float a = (band + inner_glow + rays * 0.7) * fade;
	ALBEDO = ring_color.rgb * intensity * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
