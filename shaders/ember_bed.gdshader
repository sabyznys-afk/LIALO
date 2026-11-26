shader_type spatial;
render_mode cull_back;

uniform vec4 coal_dark : source_color = vec4(0.05, 0.03, 0.025, 1.0);
uniform vec4 ember_hot : source_color = vec4(1.0, 0.28, 0.03, 1.0);
uniform float pulse_speed = 2.4;

void fragment() {
	float p = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.x * 18.0 + UV.y * 14.0);
	float cracks = smoothstep(0.45, 0.95, sin(UV.x * 34.0) * cos(UV.y * 34.0) * 0.5 + 0.5);
	float glow = cracks * (0.45 + 0.55 * p);
	ALBEDO = mix(coal_dark.rgb, ember_hot.rgb, glow * 0.55);
	EMISSION = ember_hot.rgb * glow * 2.8;
	ROUGHNESS = 0.88;
}
