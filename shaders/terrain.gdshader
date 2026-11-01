shader_type spatial;
// One shader for every outdoor ground surface. `mode` picks the recipe:
// 0 = grass, 1 = concrete paving slabs, 2 = asphalt, 3 = poured concrete.
#include "res://shaders/common.gdshaderinc"

uniform int mode = 0;
uniform vec3 col_a : source_color = vec3(0.49, 0.70, 0.42);
uniform vec3 col_b : source_color = vec3(0.37, 0.58, 0.32);
uniform float slab = 1.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	vec3 col;
	float rough = 0.9;
	if (mode == 0) {
		float n = fbm(p * 0.7) * 0.7 + vnoise(p * 9.0) * 0.3;
		col = mix(col_b, col_a, smoothstep(0.25, 0.75, n));
		col *= 0.95 + 0.08 * vnoise(p * 31.0);
		rough = 0.95;
	} else if (mode == 1) {
		vec2 cell = floor(p / slab);
		float h = hash12(cell + 11.0);
		col = mix(col_a, col_b, h * 0.45 + fbm(p * 1.3) * 0.3);
		float g = grid_groove(p / slab, 0.012 / slab * 2.0);
		col = mix(col, col_b * 0.78, g);
		rough = 0.85;
	} else if (mode == 2) {
		float n = fbm(p * 1.8);
		col = mix(col_a, col_b, n * 0.6);
		col *= 0.93 + 0.12 * vnoise(p * 55.0);
		rough = 0.88;
	} else {
		float n = fbm(p * 0.6);
		col = mix(col_a, col_b, n * 0.5);
		col *= 0.96 + 0.06 * vnoise(p * 30.0);
		rough = 0.8;
	}
	ALBEDO = col * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
