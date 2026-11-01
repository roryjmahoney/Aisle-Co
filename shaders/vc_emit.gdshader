shader_type spatial;
render_mode shadows_disabled;
// Self-lit surfaces: lamp diffusers, fridge light strips, register screens.
#include "res://shaders/common.gdshaderinc"
uniform float energy = 2.2;

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb);
	ALBEDO = c;
	EMISSION = c * energy;
	ROUGHNESS = 0.5;
}
