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

// The hole at the middle: the lens itself is the brightest pixel and the light
// must never stand in front of it. How far the halo reaches, as a share of the
// quad's half size, and how dense it is where it starts.
const float OPEN = 0.20;
const float REACH = 0.58;
const float CORE = 0.62;

void fragment() {
	vec2 d2 = UV - 0.5;
	float r = length(d2) * 2.0;
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	// A HALO round the working part, not a disc over it. It came in as a filled
	// donut of saturated LENS as wide as the whole machine, ordered-dithered, so
	// its edge was a visible square lattice: a UI sprite dropped into the world,
	// and the brightest thing in the frame, which docs/ART.md §5 keeps for fire
	// and lamps. §1 forbids the lattice and §6 asks for exactly this -- a
	// stippled halo, thinning outward, never a smooth bloom. Hashed on the
	// world's own pixel grid (world_px), so nothing swims and nothing repeats.
	//
	// And nothing round a machine is turned on a lathe: both edges wander by a
	// fifth of their radius on a slow angular noise, so what is left after the
	// halo was cut back to well inside its quad is a spill of light rather than
	// a drawn annulus. The two fixes for this finding were built in parallel —
	// the size is what the measurement asked for, the wander is what keeps it
	// from reading as geometry.
	float a = atan(d2.y, d2.x);
	float wobble = 0.86 + 0.28 * ink_vnoise(vec2(cos(a), sin(a)) * 2.7 + vec2(7.0, 13.0));
	float open = OPEN * wobble;
	float reach = REACH * wobble;
	if (r < open || r > reach) {
		discard;
	}
	float t = (r - open) / (reach - open);
	float d = CORE * (1.0 - t) * (1.0 - t);
	// The halo runs on machine power: it stutters with FOUND strips after a strike.
	d *= clamp(strength, 0.0, 1.8) * night * sky_power();
	if (ink_hash(px) >= d) {
		discard;
	}
	ALBEDO = t < 0.34 ? core : rim;
	ALPHA = 1.0;
}
