// One puff of a vent's breath or a fire's smoke seen close (MobFx._air): a
// billboard of soft vapour, never a disc. Its edge is a radial falloff eaten
// into by moving noise, so neighbouring puffs of one breath overlap and melt
// into a single column instead of reading as a stack of cotton balls. Lit by
// what reaches it (a vent's own light from below, the sky from above), and
// taking the land's own fog colour where the land has one (sky_fog_tint), so
// steam in the sulphur jungle is its acid yellow and the Burning's ash its soot.
//
// Transparent world geometry: `render_priority` is set by the material's user
// (FireModel's puffs are 11), or it silently does not draw.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

// The puff's own colour (sRGB) and how opaque it is now, 0..1 (the user tweens it).
uniform vec3 tint : source_color = vec3(0.8, 0.8, 0.8);
uniform float density = 0.0;
// Which puff this is, so no two erode alike.
uniform float seed_phase = 0.0;

void vertex() {
	// Billboard, keeping the instance's scale.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q) * 2.0;
	// The rim eaten by two octaves of noise drifting upward, so the edge is torn
	// vapour and moves as it rises.
	vec2 p = q * 3.2 + vec2(seed_phase * 7.3, seed_phase * 3.1 - TIME * 0.25);
	float n = ink_vnoise(p) * 0.65 + ink_vnoise(p * 2.3 + 11.0) * 0.35;
	float body = 1.0 - smoothstep(0.15, 1.0, r + (n - 0.5) * 0.7);
	float a = body * body * density;
	if (a < 0.004) {
		discard;
	}
	vec3 c = mix(tint, sky_fog_tint.rgb, step(0.001, sky_fog_tint.a) * 0.45);
	// A little denser and darker in its core, thinner and lighter at its rim.
	c *= mix(1.08, 0.9, body);
	ALBEDO = matter_albedo(c);
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
