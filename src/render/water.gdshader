// The sea sheet. Vertex colour carries depth and foam; the shader adds slow
// swell bands that drift on a period of four, never a shimmer.
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://src/render/sky.gdshaderinc"
uniform vec3 shade_tint = vec3(0.64, 0.66, 0.80);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float swell = sin((world_pos.x + world_pos.z) * 0.9 - TIME * 0.8) * sin(world_pos.x * 0.37 - world_pos.z * 0.23 + TIME * 0.35);
	c *= 1.0 + step(0.72, swell) * 0.18;
	ALBEDO = sky_apply(c, world_pos, TIME);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_tint, vec3(1.0), lit) / PI;
	} else {
		float a = floor(clamp(ATTENUATION, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
