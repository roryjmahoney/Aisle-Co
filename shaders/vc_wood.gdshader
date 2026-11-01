shader_type spatial;
// Vertex-coloured wood: grain runs along the object's local X axis so planks
// stay coherent however the fixture is rotated.
#include "res://shaders/common.gdshaderinc"

uniform float grain_scale = 22.0;
uniform float grain_strength = 0.16;

varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	vec2 p = vec2(v_obj.x * 1.6, (v_obj.y + v_obj.z) * grain_scale);
	float warp = fbm(vec2(v_obj.x * 3.0, (v_obj.y + v_obj.z) * 4.0)) * 2.4;
	float rings = sin(p.y + warp * 3.0 + fbm(p * 0.35) * 4.0) * 0.5 + 0.5;
	float fleck = vnoise(vec2(v_obj.x * 90.0, (v_obj.y + v_obj.z) * 9.0));
	float g = mix(rings, fleck, 0.35);
	ALBEDO = srgb_to_linear(COLOR.rgb) * (1.0 - grain_strength + grain_strength * 1.6 * g);
	ROUGHNESS = 0.62 + g * 0.12;
	SPECULAR = 0.35;
}
