// THE RING, AS THE SKY SEES IT: the one sample the seen dome takes of the orbit
// layer (src/render/orbit/orbit_layer.gd), and what the air between here and
// four hundred kilometres up does to it.
//
// Included ONLY by sky_dome.gdshaderinc, and only under `DOME_ORBIT`, which only
// sky_eye.gdshader defines: the colossi include the dome too and must not grow a
// sampler they never read.
//
// THE LAYER IS A SECOND CAMERA AIMED AT THE RING, standing at the centre of a
// world measured in kilometres, with a square lens just wide enough for the
// wheel. The sky finds a direction `d` on it by that camera's basis and lens
// (`orbit_view`, `orbit_tan`), so what it holds does not depend on where the eye
// is looking and it need not be redrawn every frame (orbit_layer.gd `uv_of` is
// this function's mirror, and tests/render/test_orbit.gd holds it to the
// engine's own camera).
//
// What comes back is (radiance already through the air, coverage). The dome adds
// the radiance where it stands -- before the clouds, which pass IN FRONT of it --
// and lets the coverage take the sun's disc, the moon and the stars away behind
// the hull. By day the unlit hull adds nothing, so it is the sky's own colour:
// the daytime moon, a ghost of a wheel. At night it is a hole in the stars.
#ifndef ORBIT_SKY_GDSHADERINC
#define ORBIT_SKY_GDSHADERINC
#include "res://src/render/far.gdshaderinc"

uniform sampler2D orbit_layer : filter_linear, repeat_disable, hint_default_transparent;
// 0 while the layer is not being rendered: its texture then holds a stale frame.
uniform float orbit_on = 0.0;
// World direction -> the layer camera's view space (its basis, transposed).
uniform mat3 orbit_view = mat3(1.0);
// tan of half the lens across (x) and up (y), so view space -> NDC.
uniform vec2 orbit_tan = vec2(0.577, 0.577);
// The part of the layer's own lens it covers, in NDC (x0, y0 bottom, x1, y1
// top): the whole of it, since the lens is aimed at the ring.
uniform vec4 orbit_rect = vec4(-1.0, -1.0, 1.0, 1.0);
// What the texture holds is radiance / gain (8 on the RGBA8 fallback, 1 on HDR).
uniform float orbit_gain = 1.0;
// HOW MUCH OF THE SKY'S OWN GLOW THE HULL STANDS IN FRONT OF, 0..1. The air
// between here and the ring glows the same with it or without it, so by day
// this is 0 and the unlit hull is exactly the sky's colour (the ghost). At night
// part of what glows is the sky BEYOND it -- the zodiacal light, the airglow
// above four hundred kilometres, the scattered city of stars -- and the hull
// hides that, so an eclipsed wheel is a darker ring against the night rather
// than only a gap in the stars (19_orbit sets it from the night).
uniform float orbit_mass = 0.0;
// The weather's fog, 0..1: thickens the low haze the ring is seen through.
uniform float orbit_thick = 0.0;

// The layer's pixel for direction `d`, or (-1, -1) off its glass.
vec2 orbit_uv(vec3 d) {
	vec3 v = orbit_view * d;
	if (v.z > -1e-4) {
		return vec2(-1.0);
	}
	vec2 ndc = v.xy / (-v.z) / orbit_tan;
	if (ndc.x < orbit_rect.x || ndc.x > orbit_rect.z || ndc.y < orbit_rect.y || ndc.y > orbit_rect.w) {
		return vec2(-1.0);
	}
	return vec2((ndc.x - orbit_rect.x) / (orbit_rect.z - orbit_rect.x), (orbit_rect.w - ndc.y) / (orbit_rect.w - orbit_rect.y));
}

// THE WAKE: the shards the wound has shed, strung along the ring's own orbit
// (19_orbit hands over that pass's arc across this sky as WAKE_POINTS
// directions, each with how sunlit the orbit is there in w). No layer: a shard
// is a point, so it is asked here, per pixel, analytically -- the arc is found,
// the shards along it are dealt by hash, and a pixel within one pixel of a shard
// lights. Up most nights between passes; only the sunlit stretches show, and
// every shard tumbles, so now and then one flares.
#define WAKE_POINTS 17
uniform vec4 orbit_wake[WAKE_POINTS];
uniform float orbit_wake_on = 0.0;
// The arc's own plane, and how far off it any of the arc strays (a cheap test
// that lets nearly every pixel of the sky skip the rest).
uniform vec4 orbit_wake_plane = vec4(0.0, 1.0, 0.0, 0.0);
// The arc's plane's own axes (e1 along its first point), and the angles its
// first and last points stand at round them.
uniform vec3 orbit_wake_e1 = vec3(1.0, 0.0, 0.0);
uniform vec3 orbit_wake_e2 = vec3(0.0, 0.0, 1.0);
uniform vec2 orbit_wake_span = vec2(0.0, 3.0);
// The whole visible arc's length, radians.
uniform float orbit_wake_arc = 3.0;
// One pixel, in radians, at the middle of the frame.
uniform float orbit_px = 0.001;
// Shards on the whole visible arc, and how wide their spread is across it.
const float WAKE_CELLS = 1500.0;
const float WAKE_BAND = 0.030;

float orbit_hash(float x) {
	return fract(sin(x * 91.3458 + 17.123) * 47453.5453);
}

vec3 orbit_wake_at(vec3 d) {
	if (orbit_wake_on <= 0.0 || abs(dot(d, orbit_wake_plane.xyz)) > orbit_wake_plane.w) {
		return vec3(0.0);
	}
	// The nearest segment of the arc: where along the whole arc (s, 0..1) and how
	// far off it (x, radians, signed).
	float best = 1e9;
	float s = -1.0;
	float x = 0.0;
	float lit = 0.0;
	// Which segment, roughly, from the direction's angle round the arc's own
	// plane: the arc's points go round it in order, so only the segment there
	// and two either side need asking, not all sixteen (the points are even in
// angle round the planet, not round this axis, so the guess can be one out).
	float phi = atan(dot(d, orbit_wake_e2), dot(d, orbit_wake_e1));
	int near_i = int(clamp(floor((phi - orbit_wake_span.x) / (orbit_wake_span.y - orbit_wake_span.x) * float(WAKE_POINTS - 1)), 0.0, float(WAKE_POINTS - 2)));
	for (int j = -2; j <= 2; j++) {
		int i = near_i + j;
		if (i < 0 || i > WAKE_POINTS - 2) {
			continue;
		}
		vec3 p0 = orbit_wake[i].xyz;
		vec3 p1 = orbit_wake[i + 1].xyz;
		vec3 n = normalize(cross(p0, p1));
		float off = asin(clamp(dot(d, n), -1.0, 1.0));
		vec3 onp = normalize(d - n * dot(d, n));
		float seg = acos(clamp(dot(p0, p1), -1.0, 1.0));
		float t = acos(clamp(dot(p0, onp), -1.0, 1.0)) / max(seg, 1e-6);
		if (dot(cross(p0, onp), n) < 0.0) {
			t = -t;
		}
		if (t >= 0.0 && t <= 1.0 && abs(off) < abs(best)) {
			best = off;
			s = (float(i) + t) / float(WAKE_POINTS - 1);
			x = off;
			lit = mix(orbit_wake[i].w, orbit_wake[i + 1].w, t);
		}
	}
	if (s < 0.0 || abs(x) > WAKE_BAND * 2.0 || lit <= 0.01) {
		return vec3(0.0);
	}
	float along = s;
	float cell = floor(along * WAKE_CELLS);
	vec3 col = vec3(0.0);
	for (int k = -1; k <= 1; k++) {
		float c = cell + float(k);
		float h = orbit_hash(c);
		if (h < 0.62) {
			continue;
		}
		float sc = (c + orbit_hash(c + 3.1)) / WAKE_CELLS;
		// Spread across the arc, thickest along it.
		float xc = (orbit_hash(c + 7.7) - 0.5) * (orbit_hash(c + 9.2) - 0.5) * 4.0 * WAKE_BAND;
		float da = (along - sc) * orbit_wake_arc;
		float dx = x - xc;
		float r = length(vec2(da, dx)) / orbit_px;
		if (r > 1.2) {
			continue;
		}
		float spot = 1.0 - smoothstep(0.3, 1.2, r);
		float spin = 0.4 + h * 3.0;
		float flare = pow(max(sin(TIME * spin + h * 61.0), 0.0), 40.0);
		float faint = orbit_hash(c + 1.3);
		col += vec3(1.0, 0.93, 0.80) * spot * (0.04 + 0.45 * faint * faint * faint + 3.5 * flare * step(0.8, orbit_hash(c + 2.9)));
	}
	return col * lit * orbit_wake_on;
}
// (radiance to ADD, coverage) for direction `d`: the ring's layer and the wake.
vec4 orbit_at(vec3 d) {
	vec3 wake = orbit_wake_at(d);
	vec4 ring = vec4(0.0);
	if (orbit_on > 0.0) {
		vec2 uv = orbit_uv(d);
		if (uv.x >= 0.0) {
			vec4 s = textureLod(orbit_layer, uv, 0.0);
			ring = vec4(s.rgb * orbit_gain, s.a * smoothstep(-0.01, 0.015, d.y)) * orbit_on;
		}
	}
	if (ring.a <= 0.0 && dot(ring.rgb + wake, vec3(1.0)) <= 0.0) {
		return vec4(0.0);
	}
	// The clouds are asked only here, where there is a ring or a shard to lay
	// them over: asked first, five octaves of noise ran on every pixel of sky.
	float open = 1.0 - dome_cloud_amount(d);
	// A shard behind the hull is behind the hull.
	wake *= 1.0 - ring.a;
	return vec4((ring.rgb + wake) * far_through(d, orbit_thick) * open, ring.a * open);
}

#endif
