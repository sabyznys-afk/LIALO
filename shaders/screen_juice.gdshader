shader_type canvas_item;
// Full-screen Balatro impact shader: chromatic aberration shockwave rings, god-rays starburst, radiant aura & edge sparks.

uniform float shock_strength = 0.0; // 0.0 .. 1.0 rapid decay on impact
uniform float ring_progress = 0.0;  // 0.0 .. 1.0 expanding wave from impact origin
uniform vec2 shock_center = vec2(0.54, 0.50);
uniform float chroma_shift = 0.016;
uniform float godrays_strength = 0.0; // 0.0 .. 1.0 full-screen radiant beams during score tally
uniform vec4 flash_color : source_color = vec4(0.45, 0.88, 1.0, 1.0);

float edge_noise(vec2 uv, float t) {
	return fract(sin(dot(floor(uv * 32.0), vec2(12.9898, 78.233)) + floor(t * 14.0)) * 43758.5453);
}

float soft_sparkle_grid(vec2 uv, float density, float t, float thresh) {
	vec2 guv = uv * vec2(density * 1.7778, density);
	vec2 id = floor(guv);
	vec2 f = fract(guv) - 0.5;
	float h = fract(sin(dot(id, vec2(127.1, 311.7)) + floor(t * 7.5)) * 43758.5453);
	if (h < thresh) return 0.0;
	vec2 jitter = vec2(fract(h * 19.3) - 0.5, fract(h * 47.7) - 0.5) * 0.42;
	float d = length(f - jitter);
	return smoothstep(0.24, 0.02, d) * (0.65 + 0.35 * sin(t * 12.0 + h * 40.0));
}

void fragment() {
	if (shock_strength <= 0.002 && godrays_strength <= 0.002) {
		COLOR = vec4(0.0);
	} else {
		vec2 centered = UV - shock_center;
		vec2 aspect_c = vec2(centered.x * 1.7778, centered.y);
		float dist = length(aspect_c);
		float ang = atan(aspect_c.y, aspect_c.x);

		// 1. Expanding dual chromatic shockwaves with RGB spectral separation along wave crests
		float radius = ring_progress * 1.48;
		float wave_w = 0.14 + shock_strength * 0.045;
		float offset_uv = chroma_shift * (0.4 + shock_strength * 0.95);
		float band_r = smoothstep(wave_w, 0.0, abs(dist - (radius - offset_uv * 2.4))) * shock_strength;
		float band_g = smoothstep(wave_w, 0.0, abs(dist - radius)) * shock_strength;
		float band_b = smoothstep(wave_w, 0.0, abs(dist - (radius + offset_uv * 2.4))) * shock_strength;
		float echo_radius = max(0.0, ring_progress - 0.18) * 1.25;
		float echo_band = smoothstep(wave_w * 0.72, 0.0, abs(dist - echo_radius)) * shock_strength * 0.65;

		vec3 chroma = (vec3(band_r * 0.98, band_g * 0.78, band_b * 1.08) + vec3(echo_band * 0.85)) * mix(vec3(1.0), flash_color.rgb, 0.54);

		// 2. Full-screen radiant starburst god-rays fanning across the viewport
		float ray_a = pow(max(0.0, sin(ang * 12.0 + TIME * 2.2)), 4.0);
		float ray_b = pow(max(0.0, cos(ang * 7.0 - TIME * 1.45)), 3.0);
		float rays = (ray_a * 0.65 + ray_b * 0.45) * godrays_strength * smoothstep(0.05, 0.65, dist);

		// 3. Full-screen perimeter vignette surge + soft circular starlight sparkles (zero blocky squares)
		float vig = smoothstep(0.38, 1.06, dist) * max(shock_strength, godrays_strength * 0.88);
		float spark_hi = soft_sparkle_grid(UV, 22.0, TIME, 0.88) * vig * 0.85;
		float full_shimmer = soft_sparkle_grid(UV + vec2(TIME * 0.03, -TIME * 0.02), 18.0, TIME * 0.7, 0.93) * godrays_strength * 0.72;

		vec3 ray_col = mix(vec3(1.0, 0.88, 0.36), flash_color.rgb, 0.45);
		vec3 out_col = chroma * 0.56 + ray_col * (rays * 0.48 + vig * 0.32 + spark_hi + full_shimmer);
		float out_a = clamp(max(max(band_r, max(band_b, echo_band)) * 0.36, vig * 0.38 + rays * 0.28 + spark_hi * 0.45 + full_shimmer * 0.48), 0.0, 0.64);
		COLOR = vec4(out_col, out_a);
	}
}
