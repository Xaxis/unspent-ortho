// THE RING, AS THE SKY SEES IT: the one sample the seen dome takes of the orbit
// layer (src/render/orbit/orbit_layer.gd), and what the air between here and
// four hundred kilometres up does to it.
//
// Included ONLY by sky_dome.gdshaderinc, and only under `DOME_ORBIT`, which only
// sky_eye.gdshader defines: the colossi include the dome too and must not grow a
// sampler they never read.
//
// THE LAYER IS A SECOND CAMERA WITH THE EYE'S OWN BASIS AND LENS, standing at
// the centre of a world measured in kilometres, rendered into a texture the size
// of the 3D frame. A direction `d` out of the eye lands on the SAME pixel of the
// layer as of the screen, so the sample is the ring as the renderer lit it, on
// the pixel it belongs to (orbit_layer.gd `uv_of` is this function's mirror, and
// tests/render/test_orbit.gd holds the two to one rule).
//
// What comes back is (radiance already through the air, coverage). The dome adds
// the radiance where it stands -- before the clouds, which pass IN FRONT of it --
// and lets the coverage take the sun's disc, the moon and the stars away behind
// the hull. By day the unlit hull adds nothing, so it is the sky's own colour:
// the daytime moon, a ghost of a wheel. At night it is a hole in the stars.
#ifndef ORBIT_SKY_GDSHADERINC
#define ORBIT_SKY_GDSHADERINC

uniform sampler2D orbit_layer : filter_linear, repeat_disable, hint_default_transparent;
// 0 while the layer is not being rendered: its texture then holds a stale frame.
uniform float orbit_on = 0.0;
// World direction -> the layer camera's view space (its basis, transposed).
uniform mat3 orbit_view = mat3(1.0);
// tan of half the lens across (x) and up (y), so view space -> NDC.
uniform vec2 orbit_tan = vec2(0.577, 0.577);
// The rectangle of the frame the layer covers, in NDC (x0, y0 bottom, x1, y1
// top): the layer is cut down to the ring's own box on the glass.
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

// DUPLICATE of the cloud amount in sky_dome.gdshaderinc `dome_seen_col` (the same
// three lines, number for number). The dome lays its clouds before any hook can
// see where they are, so the ring asks again rather than edit that block while
// the colossi builder owns it. To dedupe into a shared `dome_cloud_amount(d)`.
float orbit_cloud_amount(vec3 d) {
	float h = d.y;
	if (h <= 0.0) {
		return 0.0;
	}
	vec2 p = d.xz / (h + 0.08) * 1.6 + dome_drift * 0.004;
	float n = dome_fbm(p);
	float amount = smoothstep(1.0 - (0.18 + dome_cover * 0.72), 1.02 - dome_cover * 0.35, n);
	return amount * smoothstep(0.0, 0.18, h);
}

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

// How much of the ring's light gets through the air to the eye, per channel:
// the high air (thin, a few percent at the zenith) and the low haze, both along
// the slant (1/sin elevation, kept finite at the horizon), blue lost first so a
// low ring reddens the way a low moon does.
vec3 orbit_through(vec3 d) {
	float s = max(d.y, 0.0) + 0.035;
	float tau = (0.045 + 0.10 * (1.0 + orbit_thick * 3.0)) / s;
	return exp(-tau * vec3(0.55, 0.85, 1.35)) * smoothstep(-0.01, 0.015, d.y);
}

// (radiance to ADD, coverage) for direction `d`.
vec4 orbit_at(vec3 d) {
	if (orbit_on <= 0.0) {
		return vec4(0.0);
	}
	vec2 uv = orbit_uv(d);
	if (uv.x < 0.0) {
		return vec4(0.0);
	}
	vec4 s = textureLod(orbit_layer, uv, 0.0);
	if (s.a <= 0.0 && dot(s.rgb, vec3(1.0)) <= 0.0) {
		return vec4(0.0);
	}
	float open = 1.0 - orbit_cloud_amount(d);
	return vec4(s.rgb * orbit_gain * orbit_through(d) * open * orbit_on, s.a * open * orbit_on * smoothstep(-0.01, 0.015, d.y));
}

#endif
