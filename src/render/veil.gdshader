// THE VEIL (AbilityVeil, FightSim.veils): the drip let fall as a curtain of
// water across the way ahead. One upright quad, UV x across it, y from the top
// (0) to the floor (1).
//
// It must read as WATER FALLING, not as bars of light: many thin threads of
// uneven weight, each running down at its own speed, beaded where the drops
// bunch, thickening into a pale sheet in the middle and fraying at both ends,
// with a band of broken white where it lands. Seen through, never solid: what
// stands behind it is still there to the player; it is the machines' eyes the
// water breaks (docs/DESIGN.md), not the player's.
//
// Unshaded and drawn with alpha, writing no depth, so it never hides a body and
// never casts. Near the eye it fades out, as shaft_column.gdshader does, so
// over the shoulder it is never a white sheet across the lens.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

// The water's colour and its lit threads', palette colours (54_gear: RIME, BRINE).
uniform vec3 water_tint = vec3(0.62, 0.74, 0.80);
uniform vec3 thread_tint = vec3(0.90, 0.96, 1.0);
// 0..1 over its life: in as it starts to fall, out as it stops (54_gear).
uniform float strength = 1.0;
// Threads across the whole width.
uniform float threads = 46.0;
// The strip it lands in, lying on the ground along its foot: all churn and wet,
// no threads. From above the sheet is seen edge on, and this is its line.
uniform bool pool = false;

const float EYE_CLEAR = 1.2;
const float EYE_FULL = 4.0;

void fragment() {
	float x = UV.x * threads;
	float col = floor(x);
	float h = ink_hash(vec2(col, 17.0));
	float h2 = ink_hash(vec2(col, 53.0));
	// A thread's weight and where in its cell it runs, so the spacing is uneven.
	float centre = 0.25 + 0.5 * h2;
	float width = 0.10 + 0.22 * h;
	float thread = 1.0 - smoothstep(width * 0.5, width, abs(fract(x) - centre));
	// Running down: bunched drops that slide at each thread's own speed.
	float speed = 1.6 + 1.4 * h;
	float run = fract(UV.y * (3.0 + 4.0 * h2) - TIME * speed + h * 7.0);
	float beads = 0.45 + 0.55 * smoothstep(0.55, 0.95, run);
	// Some threads break for a moment, so it is falling and not ruled.
	float gap = step(0.18, fract(UV.y * 1.3 - TIME * speed * 0.45 + h2 * 5.0));
	float lit = pool ? 0.0 : thread * beads * gap;
	// The sheet between the threads: thickest in the middle of the width, frayed
	// to nothing at both sides and at the lip it falls from.
	float sides = smoothstep(0.0, 0.14, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x));
	float lip = pool ? 1.0 - smoothstep(0.25, 0.5, abs(UV.y - 0.5)) : smoothstep(0.0, 0.18, UV.y);
	float sheet = 0.10 + 0.08 * ink_hash(vec2(col, floor(UV.y * 9.0 - TIME * 2.0)));
	// Where it lands: broken white churn in the bottom band.
	float land = pool ? 1.0 : smoothstep(0.86, 0.99, UV.y);
	// In the pool, rows of churn sliding outward at their own rates.
	float slide = TIME * 3.0 * (ink_hash(vec2(floor(UV.y * 12.0), 3.0)) - 0.5);
	vec2 cell = pool ? floor(vec2(UV.x * 60.0 + slide, UV.y * 12.0))
		: floor(vec2(UV.x * 60.0, UV.y * 30.0 - TIME * 8.0));
	float churn = land * step(pool ? 0.6 : 0.45, ink_hash(cell + floor(TIME * 6.0) * (pool ? 0.37 : 0.0)));
	float eye = smoothstep(EYE_CLEAR, EYE_FULL, length(VERTEX));
	float a = (sheet + 0.62 * lit + 0.55 * churn) * sides * lip * strength * eye;
	if (a < 0.004) {
		discard;
	}
	vec3 c = mix(water_tint, thread_tint, clamp(lit + churn, 0.0, 1.0));
	ALBEDO = matter_light(c);
	ALPHA = clamp(a, 0.0, 0.9);
}
