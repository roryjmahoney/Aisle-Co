shader_type spatial;
// Shop floor: 50 cm checkerboard tiles that line up exactly with the build
// grid, so the floor itself quietly teaches the player where things snap.
#include "res://shaders/common.gdshaderinc"

uniform vec3 tile_a : source_color = vec3(0.957, 0.969, 0.949);
uniform vec3 tile_b : source_color = vec3(0.560, 0.800, 0.690);
uniform vec3 grout : source_color = vec3(0.62, 0.67, 0.64);
uniform float tile_size = 0.5;
uniform float checker = 1.0;
uniform float wear = 0.5;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world.xz / tile_size;
	vec2 cell = floor(uv);
	float parity = mod(cell.x + cell.y, 2.0) * checker;
	vec3 base = mix(tile_a, tile_b, parity);
	float var_t = hash12(cell * 1.37 + 4.1);
	base *= 0.965 + var_t * 0.05;
	// broad, low-frequency scuffing so a big floor isn't perfectly uniform
	float scuff = fbm(v_world.xz * 0.9);
	base *= 1.0 - wear * 0.06 * smoothstep(0.45, 0.85, scuff);
	float groove = grid_groove(uv, 0.035);
	ALBEDO = mix(base, grout, groove * 0.85);
	ROUGHNESS = mix(0.28 + var_t * 0.1 + scuff * 0.1, 0.9, groove);
	SPECULAR = 0.5;
}
