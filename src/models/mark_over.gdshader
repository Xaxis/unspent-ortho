// A mark drawn over everything in front of it: the ink burst of a blow and its
// sparks. A blow lands on the near side of a trunk under a crown, or behind a
// shoulder of rock, and the burst must still be seen, the way a pen draws it on
// top. Otherwise the same as mark.gdshader (and drawn after the outline pass).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

#include "res://src/render/sky.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, sky_apply(COLOR.rgb, world_pos, TIME), COLOR.a);
	ALPHA = 1.0;
}
