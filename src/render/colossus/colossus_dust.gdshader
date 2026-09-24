// DUST AND STEAM off a colossus's foot as it lands (colossus_foot.gd `land`):
// a wall of dust thrown out from each pad along the ground and settling, and
// steam falling out of the vents under the drum and spreading. Air, not a
// surface: no light() and no shadow; it takes the hour's light off the sky
// (sky_apply over its own colour), so a landing at dusk throws up dusk-coloured
// dust and one at night a dark grey wall.
//
// ONE DRAW A CLOUD: a MultiMesh of camera-facing quads, each a billow, whose
// whole flight is worked out here from `age` and the instance's own numbers
// (INSTANCE_CUSTOM: bearing, pace, size, lift, all 0..1), so nothing about a
// landing is animated on the CPU but one uniform. A billow is soft all round
// and torn by noise, never a shape: a solid puff read as a glass jewel.
//
// Transparent, so it carries a render_priority (colossus_foot.gd sets 8: over
// the land and the props it rolls across, under people and hit marks).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix, skip_vertex_transform;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

uniform vec4 dust_col : source_color = vec4(0.6, 0.55, 0.48, 1.0);
// 0 at the landing, 1 when it has settled.
uniform float age = 0.0;
// Steam instead of dust: falling out of a ring of vents and spreading, not
// thrown out along the ground.
uniform bool steam = false;
// Dust: from a pad's edge (`from_r`) out to `reach`, rising to `high`, billows
// `size` across at their fullest. Steam: vents on a ring `from_r` out, falling
// `high`, billows `size` across.
uniform float from_r = 20.0;
uniform float reach = 190.0;
uniform float high = 26.0;
uniform float size = 30.0;

varying vec3 world_pos;
varying float seed;
varying float life;

void vertex() {
	vec4 k = INSTANCE_CUSTOM;
	float a = k.x * TAU;
	vec3 dir = vec3(cos(a), 0.0, sin(a));
	vec3 at;
	float grow;
	if (steam) {
		// Each vent breathes out puffs in turn: a puff's own clock, falling and
		// spreading, fading as it goes.
		float t = fract(age * 3.0 + k.y);
		at = dir * (from_r + t * 30.0 * k.w) + vec3(0.0, -t * high, 0.0);
		grow = mix(0.35, 1.2, t) * (0.6 + 0.6 * k.z);
		life = smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.55, 1.0, t)) * (1.0 - smoothstep(0.7, 1.0, age));
	} else {
		// Out fast and slowing, as a thrown thing does; lifting and thinning.
		float t = 1.0 - pow(1.0 - clamp(age * (0.8 + 0.4 * k.y), 0.0, 1.0), 2.6);
		at = dir * mix(from_r, reach * (0.55 + 0.45 * k.y), t) + vec3(0.0, high * k.w * sqrt(t), 0.0);
		grow = mix(0.25, 1.0, sqrt(t)) * (0.5 + 0.7 * k.z);
		life = smoothstep(0.0, 0.03, age) * (1.0 - smoothstep(0.4, 1.0, age));
	}
	seed = k.x * 91.0 + k.z * 17.0;
	world_pos = (MODEL_MATRIX * vec4(at, 1.0)).xyz;
	vec3 centre = (MODELVIEW_MATRIX * vec4(at, 1.0)).xyz;
	VERTEX = centre + vec3(VERTEX.xy * size * grow, 0.0);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	// A billow: soft all round, torn at its edge by noise that drifts through it.
	float n = ink_vnoise(UV * 3.1 + vec2(seed, seed * 0.7) + vec2(TIME * 0.05, -TIME * 0.07)) * 0.6
		+ ink_vnoise(UV * 7.3 + vec2(seed * 1.3, 3.0) - vec2(TIME * 0.09, 0.0)) * 0.4;
	float body = (1.0 - smoothstep(0.15, 1.0, r + (n - 0.5) * 0.7)) * smoothstep(0.2, 0.55, n + 0.25 * (1.0 - r));
	vec3 c = sky_apply(dust_col.rgb, world_pos, TIME);
	// The side toward the sky catches its light; the underside keeps its shade.
	c *= mix(0.78, 1.08, UV.y < 0.5 ? 1.0 - UV.y * 0.6 : 0.7);
	ALBEDO = matter_albedo(c);
	ALPHA = clamp(body * life * (steam ? 0.5 : 0.7), 0.0, 1.0);
}
