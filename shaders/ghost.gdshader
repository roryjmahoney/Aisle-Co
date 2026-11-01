shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;
// Placement preview: a soft body tint plus a brighter fresnel rim, so the
// object's form reads clearly without looking like solid geometry.
uniform vec4 tint : source_color = vec4(0.56, 0.88, 0.72, 1.0);
uniform float body_alpha = 0.22;
uniform float rim_alpha = 0.75;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	// Gentle top-light so horizontal faces read differently from vertical ones.
	float up = clamp(dot((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	ALBEDO = tint.rgb * (0.75 + up * 0.35) + rim * 0.35;
	ALPHA = clamp(body_alpha + up * 0.12 + rim * rim_alpha, 0.0, 0.9);
}
