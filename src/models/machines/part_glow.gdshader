// The working part's light as a world object (art-audio-extract §3): a
// camera-facing ring of loose amber pixels round the part. Not a soft veil and
// never bloom (docs/ART.md §6): whole palette pixels, ordered-dithered in rings
// and pinned to the world through world_px so the pattern never swims. Pulled a
// little toward the camera and depth-tested, so when the part is on the far side
// the body hides the ring and only the spill round the silhouette shows ("over
// the shoulder"). Thicker as the sky darkens; the machine's own light is never
// tinted by it. Drawn in the transparent pass (ALPHA is written, always whole)
// with a high render priority, after the ink outline repaints the frame: a
// light has no ink round it.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform vec3 core = vec3(0.9098, 0.7608, 0.2275);
uniform vec3 rim = vec3(0.5608, 0.4157, 0.0706);
// 0 none .. 1 full night density (a flare goes past 1).
uniform float strength = 1.0;
uniform float toward_camera = 0.45;

varying float night;

void vertex() {
	vec4 origin = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 v = origin.xyz + vec3(VERTEX.xy * s, toward_camera);
	POSITION = PROJECTION_MATRIX * vec4(v, 1.0);
	// sky_apply() takes screen derivatives, which a vertex stage cannot; the
	// light's own colour carries time, weather and region.
	vec3 tint = sky_tint;
	// 0 under a full day sky (the sun outshines it), ~1 at night.
	night = clamp((0.92 - dot(tint, vec3(0.3333))) / 0.36, 0.0, 1.0);
}

// An ORDERED 4x4 matrix drew this halo as a chequerboard: a perfect circle with
// a perfect hole over a visible square lattice, which reads as a UI sprite
// dropped into the world (art review, wave A finding 7) and breaks ART §1. A
// hash on the world-anchored pixel is irregular at every density and just as
// stable, because world_px pins it to the ground.
float stipple(vec2 p) {
	return ink_hash(p + vec2(5.0, 23.0));
}

void fragment() {
	vec2 d2 = UV - 0.5;
	float r = length(d2) * 2.0;
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	// Nothing round a machine is turned on a lathe. The ring's own edges wander
	// by a fifth of their radius, on a slow angular noise, so it is a spill of
	// light and not a drawn annulus.
	float a = atan(d2.y, d2.x);
	float wobble = 0.86 + 0.28 * ink_vnoise(vec2(cos(a), sin(a)) * 2.7 + vec2(7.0, 13.0));
	float inner = 0.34 * wobble;
	float mid = 0.60 * wobble;
	float outer = 0.86 * wobble;
	// The core of the ring is left open: the lens itself is the brightest pixel.
	float d = 0.0;
	if (r > inner && r < mid) {
		d = 0.5;
	} else if (r >= mid && r < outer) {
		d = 0.17;
	}
	// The ring runs on machine power: it stutters with FOUND strips after a strike.
	d *= clamp(strength, 0.0, 1.8) * night * sky_power();
	if (stipple(px) >= d) {
		discard;
	}
	ALBEDO = r < mid ? core : rim;
	ALPHA = 1.0;
}
