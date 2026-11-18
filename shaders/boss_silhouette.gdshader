shader_type spatial;
// Enigmatic shadowed Boss silhouette with Fresnel-driven epoch rim glow.
// Keeps the torso/head deep in shadow while etching an unmistakable outline on zero rigging budget.

render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 core_color : source_color = vec4(0.014, 0.013, 0.020, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.68, 0.24, 1.0);
uniform float rim_power : hint_range(1.0, 6.0) = 2.05;
uniform float rim_strength : hint_range(0.0, 3.0) = 2.35;
uniform float breathe_pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, rim_power);
	float pulse = 0.88 + 0.12 * sin(TIME * 2.1 + breathe_pulse * 6.283);

	ALBEDO = core_color.rgb;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	EMISSION = rim_color.rgb * (fresnel * rim_strength * pulse);
}
