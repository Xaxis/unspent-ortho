// One puff of a vent's breath or a fire's smoke seen close: a billboard of soft
// vapour, never a disc. Its edge is a radial falloff eaten into by moving noise,
// so neighbouring puffs of one breath overlap and melt into a single column
// instead of reading as a stack of cotton balls. Lit by what reaches it (a
// vent's own light from below, the sky from above), and taking the land's own
// fog colour where the land has one (sky_fog_tint).
//
// Two ways to drive it:
//  - one material per puff, tweened from script (MobFx._air): `tint`, `density`;
//  - POOLED (16_vents): every vent's puffs are the instances of ONE MultiMesh,
//    one draw. A breath writes each puff's whole life into its instance once
//    and the life is run here against `plume_now`, so a breath costs no node,
//    material, tween or draw call. Per instance:
//      transform  origin where it is let out; basis x column its width at birth
//                 (length), y column how far it travels over its life
//      COLOR      rgb its colour, a which puff it is (the erosion's phase)
//      CUSTOM     x when it was let out, y how long it lives (0 idle), z how
//                 many times wider it grows, w how dense it gets
//
// Transparent world geometry: `render_priority` is set by the material's user
// (11, as FireModel's puffs), or it silently does not draw.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

// The vents' clock, in seconds (16_vents), which pooled puffs are timed against.
global uniform float plume_now;

uniform bool pooled = false;
// Tweened mode: the puff's colour (sRGB) and how opaque it is now, 0..1.
uniform vec3 tint : source_color = vec3(0.8, 0.8, 0.8);
uniform float density = 0.0;
// Which puff this is, so no two erode alike.
uniform float seed_phase = 0.0;

varying float v_density;
varying vec3 v_tint;
varying float v_phase;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 at = MODEL_MATRIX[3].xyz;
	v_density = density;
	v_tint = tint;
	v_phase = seed_phase;
	if (pooled) {
		vec4 life = INSTANCE_CUSTOM;
		float t = life.y > 0.0 ? (plume_now - life.x) / life.y : 2.0;
		if (t < 0.0 || t >= 1.0) {
			// Idle: nothing drawn, nothing shaded.
			s = 0.0;
			v_density = 0.0;
		} else {
			float e = 1.0 - (1.0 - t) * (1.0 - t);
			s *= mix(1.0, life.z, e);
			at += MODEL_MATRIX[1].xyz * e;
			v_density = life.w * smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.3, 1.0, t));
			v_tint = COLOR.rgb;
			v_phase = COLOR.a;
		}
	}
	// Billboard at `at`, `s` across.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, vec4(at, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 q = UV - 0.5;
	float r = length(q) * 2.0;
	// The rim eaten by two octaves of noise drifting upward, so the edge is torn
	// vapour and moves as it rises.
	vec2 p = q * 3.2 + vec2(v_phase * 7.3, v_phase * 3.1 - TIME * 0.25);
	float n = ink_vnoise(p) * 0.65 + ink_vnoise(p * 2.3 + 11.0) * 0.35;
	float body = 1.0 - smoothstep(0.15, 1.0, r + (n - 0.5) * 0.7);
	float a = body * body * v_density;
	if (a < 0.004) {
		discard;
	}
	vec3 c = mix(v_tint, sky_fog_tint.rgb, step(0.001, sky_fog_tint.a) * 0.45);
	// A little denser and darker in its core, thinner and lighter at its rim.
	c *= mix(1.08, 0.9, body);
	ALBEDO = matter_albedo(c);
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
