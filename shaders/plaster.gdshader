shader_type spatial;
// Interior walls: painted plaster above a green wainscot, split at a fixed
// world height so every wall in the store shares one continuous datum line.
#include "res://shaders/common.gdshaderinc"

uniform vec3 upper : source_color = vec3(0.953, 0.890, 0.620);
uniform vec3 lower : source_color = vec3(0.184, 0.478, 0.341);
uniform vec3 rail : source_color = vec3(0.114, 0.231, 0.2);
uniform float split_height = 0.95;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float y = v_world.y;
	vec3 col = y < split_height ? lower : upper;
	// tongue-and-groove boards on the wainscot
	if (y < split_height) {
		float along = v_world.x + v_world.z;
		float g = abs(fract(along / 0.12) - 0.5);
		col *= 0.9 + 0.1 * smoothstep(0.03, 0.08, g);
	}
	float r = smoothstep(split_height - 0.005, split_height, y) * (1.0 - smoothstep(split_height + 0.05, split_height + 0.055, y));
	col = mix(col, rail, r);
	col *= 0.97 + 0.04 * fbm(v_world.xy * 3.0 + v_world.zy * 2.0);
	ALBEDO = col * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = y < split_height ? 0.45 : 0.85;
	SPECULAR = 0.35;
}
