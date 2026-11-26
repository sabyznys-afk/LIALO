shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D atlas_tex : source_color, filter_linear_mipmap;
uniform int cell_idx = 0;
uniform int atlas_cols = 4;
uniform vec4 tint_color : source_color = vec4(1.0, 0.92, 0.78, 1.0);
uniform vec4 ink_color : source_color = vec4(0.05, 0.03, 0.02, 1.0);
uniform float emission_boost : hint_range(0.0, 4.0) = 0.65;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Y-axis spherical-ish billboard aligned cleanly to camera
	mat4 mv = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	float cols = float(max(1, atlas_cols));
	float cx = float(cell_idx % max(1, atlas_cols));
	float cy = float(cell_idx / max(1, atlas_cols));
	vec2 cell_uv = (UV + vec2(cx, cy)) / cols;
	vec4 tex = texture(atlas_tex, cell_uv);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(ink_color.rgb, tint_color.rgb * tex.rgb, smoothstep(0.14, 0.42, lum));
	ALBEDO = col;
	EMISSION = col * emission_boost * smoothstep(0.35, 0.95, lum);
	ALPHA = tex.a * tint_color.a * fade_alpha;
	if (ALPHA < 0.04) {
		discard;
	}
}
