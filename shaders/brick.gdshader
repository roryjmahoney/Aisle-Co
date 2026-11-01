shader_type spatial;
// Storybook brick: slightly oversized courses so the pattern stays readable
// at management-camera distances instead of turning into moiré.
#include "res://shaders/common.gdshaderinc"

uniform vec3 brick_col : source_color = vec3(0.72, 0.36, 0.25);
uniform vec3 brick_dark : source_color = vec3(0.6, 0.28, 0.18);
uniform vec3 mortar_col : source_color = vec3(0.85, 0.84, 0.81);
uniform vec2 brick_size = vec2(0.36, 0.12);

varying vec3 v_world;
varying vec3 v_wnormal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(v_wnormal);
	vec2 p = n.x > n.z ? v_world.zy : v_world.xy;
	if (n.y > 0.7) { p = v_world.xz; }
	vec2 uv = p / brick_size;
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float h = hash12(cell + vec2(row * 7.0, 3.0));
	vec3 col = mix(brick_col, brick_dark, h * 0.75);
	col *= 0.94 + 0.1 * vnoise(p * 40.0);
	vec2 edge = min(f, 1.0 - f) * brick_size;
	float m = 1.0 - smoothstep(0.006, 0.013, min(edge.x, edge.y));
	ALBEDO = mix(col, mortar_col, m) * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = mix(0.82, 0.95, m);
	SPECULAR = 0.25;
}
