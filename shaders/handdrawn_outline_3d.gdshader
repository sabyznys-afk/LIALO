shader_type spatial;
// Distance-compensated hand-inked calligraphic silhouette contour for sculpted 3D relics.
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.035, 0.022, 0.018, 1.0);
uniform float thickness = 0.0016;
uniform float dist_scale = 0.0030;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cam_dist = length(view_pos);
	float scaled_t = clamp(cam_dist * dist_scale, thickness * 0.55, thickness * 2.2);
	float nib_wobble = 0.88 + 0.24 * sin(VERTEX.x * 165.0 + VERTEX.y * 195.0 + VERTEX.z * 140.0);
	VERTEX += NORMAL * (scaled_t * nib_wobble);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
