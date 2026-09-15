// FOUND: the machines and everything taken off them (pylons, plate on roofs,
// salvage kit). Drawn by a ruler: a flat wash, ONE hard shade step, NO hatching,
// no paper grain, no wobble. They should look like they do not belong to the
// drawing, because they do not. Working parts glow (emission_strength > 0).
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://src/render/sky.gdshaderinc"

uniform vec3 shade_tint = vec3(0.58, 0.56, 0.74);
uniform float emission_strength = 0.0;
// Machines keep their light at night: their wash is dimmed less than the land.
uniform float night_keep = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 tinted = sky_apply(c, world_pos, TIME);
	ALBEDO = mix(tinted, c, night_keep * (1.0 - clamp(dot(tinted, vec3(0.333)) / max(dot(c, vec3(0.333)), 1e-3), 0.0, 1.0)));
	EMISSION = c * emission_strength;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.05, dot(NORMAL, LIGHT)) * step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_tint, vec3(1.0), lit) / PI;
	} else {
		float a = floor(clamp(ATTENUATION, 0.0, 1.0) * 2.0 + 0.5) / 2.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
