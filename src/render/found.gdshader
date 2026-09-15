// FOUND: the machines and everything taken off them (pylons, plate on roofs,
// salvage kit). Drawn by a ruler: a flat wash, ONE hard shade step, NO hatching,
// no paper grain, no wobble. They should look like they do not belong to the
// drawing, because they do not. Working parts glow (emission_strength > 0).
shader_type spatial;
render_mode cull_back, specular_disabled;

#define SKY_FOUND
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
	// Neon on the FOUND: vertex alpha below 1 is a light built into the machine.
	// 0.5..0.98 a steady strip (brighter lower); below 0.5 a beacon that blinks
	// on a slow machine beat, each beacon at its own phase.
	float glow = 0.0;
	if (COLOR.a < 0.98) {
		if (COLOR.a >= 0.5) {
			glow = (1.0 - COLOR.a) * 5.0;
		} else {
			float beat = fract(TIME * 0.45 + dot(floor(world_pos.xz * 0.5), vec2(0.37, 0.61)));
			glow = step(beat, 0.18) * (1.0 - COLOR.a * 2.0) * 6.0 + 0.15;
		}
	}
	// The machines' own light runs on their power: a lightning strike stutters it.
	EMISSION = (c * emission_strength + c * glow) * sky_power() + neon_skyglow(c);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.05, dot(NORMAL, LIGHT)) * step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_tint * sky_shade.rgb, vec3(1.0), lit) / PI;
	} else {
		// The lamp's pool in the land's own two hard steps and stippled rim.
		float a = sky_pool(clamp(ATTENUATION * step(-0.2, dot(NORMAL, LIGHT)), 0.0, 1.0), world_pos);
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
