// The one lit material for everything MADE and FOUND: terrain, props, people,
// machines. Albedo is the vertex colour (palette sRGB). Lighting follows the art
// direction: a hard one-step shadow that is a COLOUR (blue-violet), a second
// band on grazing faces, no specular, no smooth falloff. Day, night, weather and
// region are multiplies set on the global `sky_tint`.
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://src/render/sky.gdshaderinc"
// The measured one-step darken of the source game, pushed toward blue-violet.
uniform vec3 shade_tint = vec3(0.64, 0.66, 0.80);
uniform float emission_strength = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = sky_apply(COLOR.rgb, world_pos, TIME);
	EMISSION = COLOR.rgb * emission_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.0, ndl) * step(0.5, ATTENUATION);
		float band = ndl > 0.4 ? 1.0 : 0.88;
		vec3 k = mix(shade_tint, vec3(band), lit);
		DIFFUSE_LIGHT += LIGHT_COLOR * k / PI;
	} else {
		// Lamps and fire: quantised to three steps so pools of light have edges.
		float a = clamp(ATTENUATION * step(-0.2, ndl), 0.0, 1.0);
		a = floor(a * 3.0 + 0.5) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
