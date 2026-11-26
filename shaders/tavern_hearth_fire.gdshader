shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float speed = 2.6;
uniform float intensity = 2.4;
uniform vec4 core_col : source_color = vec4(1.0, 0.94, 0.68, 1.0);
uniform vec4 mid_col : source_color = vec4(1.0, 0.46, 0.08, 1.0);
uniform vec4 tip_col : source_color = vec4(0.78, 0.10, 0.02, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * 6.4 + h * 4.5 + VERTEX.z * 8.0) * 0.045 * h;
	VERTEX.z += cos(TIME * 5.2 + h * 3.8 + VERTEX.x * 7.0) * 0.032 * h;
}

void fragment() {
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	float cx = abs(UV.x - 0.5) * 2.0;
	vec2 uv_n = vec2(UV.x * 3.6, h * 3.2 - TIME * speed * 0.65);
	float n = fbm(uv_n);
	float taper = pow(1.0 - h, 0.65);
	float mask = smoothstep(cx * 0.92 + h * 0.35, 0.05, n * taper + (1.0 - h) * 0.55);
	float shape = (1.0 - smoothstep(0.18, 0.95, cx + h * 0.45)) * smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.75, 1.0, h));
	float alpha = clamp(shape * (0.45 + n * 0.85) * mask, 0.0, 1.0);
	vec3 col = mix(tip_col.rgb, mid_col.rgb, smoothstep(0.2, 0.65, n * (1.0 - h * 0.5)));
	col = mix(col, core_col.rgb, smoothstep(0.55, 0.92, (1.0 - h) * n * 1.4));
	ALBEDO = col * intensity;
	EMISSION = col * intensity;
	ALPHA = alpha;
	if (ALPHA < 0.03) {
		discard;
	}
}
