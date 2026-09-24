// A COLOSSUS: a machine whose hub stands fifty-five kilometres up, drawn in the
// same pass, the same light and the same air as the land under it.
//
// COMPRESSED SPACE. The camera's far plane is 1400 units (Shoulder.FAR); the
// nearest walker is tens of kilometres off. So every vertex is moved ALONG ITS
// OWN VIEW RAY: nearer than a knee (`comp_d0`, 0.82 of far) nothing moves; past
// it the distance is taken down a logarithm that reaches `comp_max` (inside the
// far plane) at 400 km. A point on its own ray projects to the same pixel, so
// where a thing is on the glass and how big it looks are exact; the log is
// monotone, so what is in front stays in front. Only DEPTH is squashed, and
// nothing here reads depth for anything but ordering. Under an orthographic
// camera the glass does not depend on depth at all, so only the depth along the
// axis is squashed. `ColossusView.compress` is the GDScript mirror of this, and
// tests/render/test_colossus.gd holds the two to one rule.
//
// Because vertices move, the TRUE world position rides in a varying and every
// question the fragment asks -- height, distance, which way it is seen -- is
// asked of that, never of the compressed one.
//
// SITTING IN THE AIR. The land's depth fog closes into the sky's own colour by
// SkyLight.SEE; left on, it would put every colossus behind a solid wall of it.
// So the air is worked out per fragment and written to FOG, which REPLACES the
// engine's fog (and its volumetric fog) for this material and is laid over the
// lit colour exactly as the engine's own is -- after the light, before the
// tonemapper. NOT `fog_disabled`: that render mode compiles FOG out along with
// the engine's fog, and the machine came back as a black silhouette standing on
// the horizon with no air in front of it at all (measured on the first frame).
// Two layers:
//   LOW, the game's own haze, as thin as `h_low` over the ground. Its optical
//   depth along the true ray is turned into the ground distance that would hold
//   the same air, and that distance goes through the LAND'S OWN depth-fog curve
//   (`land_fog`: begin, end, curve, density, as `_look_out` left them). At the
//   ground the two are therefore one formula, so a foot's base closes into the
//   land's haze on no line; a thing high in the sky crosses only the layer's
//   thickness and comes out of it.
//   HIGH, real air, `h_high` thick: what turns a leg blue with distance and
//   leaves the hub and the spire crisp against the zenith.
// The colour both close into is the DOME's own, in the direction the fragment
// is seen (sky_dome.gdshaderinc, the radiance pass without moon or stars),
// which is the colour the land's aerial perspective samples.
//
// Lit by the renderer, like everything else: there is no light() here. The
// shadow map cannot hold a thing this size (and a compressed vertex would read
// it wrongly), so it neither casts nor receives.
shader_type spatial;
render_mode cull_back, skip_vertex_transform, shadows_disabled;

#define SKY_FOUND
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/render/sky_dome.gdshaderinc"

// The rigid frames the mesh is skinned to (colossus_model.gd): three rows per
// bone, each (basis row, origin), so bone b maps a local point p to
// (dot(r0.xyz, p) + r0.w, dot(r1.xyz, p) + r1.w, dot(r2.xyz, p) + r2.w).
uniform vec4 bone_rows[30];
// Compressed space (ColossusView.compress): the knee, the ceiling, and the
// log's scale, solved on the CPU so the curve meets the ceiling at 400 km with
// no bend at the knee.
uniform float comp_d0 = 1148.0;
uniform float comp_max = 1393.0;
uniform float comp_l = 25.0;
uniform bool comp_ortho = false;
// The land's depth fog, as the eye-level camera is drawing it this frame.
uniform vec4 land_fog = vec4(18.0, 900.0, 1.0, 1.0);
// The weather's fog, 0..1: it thickens the low layer as it thickens the land's.
uniform float thick = 0.0;
// The layers. `h_low` is how thick the game's haze is over the ground; `h_high`
// and `beta_high` are the real air (extinction per metre at sea level).
// `h_low` is FORTY METRES and not the design's 250 because the land's air is
// thick: it closes by SkyLight.SEE (900), so a ray crosses its whole visibility
// inside the layer below an elevation of asin(h_low / 900). At 250 that is 16
// degrees -- the whole lower two thirds of every leg vanished and the machines
// floated (measured, seed 7 coast noon). At 40 it is 2.5: the feet stand in the
// haze and the legs come up out of it.
uniform float h_low = 40.0;
uniform float h_high = 8000.0;
uniform float beta_high = 1.1e-5;
// How much of the lens's own light the hour leaves (0 at noon, 1 at night):
// a lamp in daylight shows the colour it is made of, not white.
uniform float lens_glow = 1.0;

varying vec3 true_world;
varying vec3 body_local;

// FOUND's own two constants (found.gdshader): the albedo taken down so the
// body is a dark mass under the real sun, and how metal it reads.
const float FOUND_MASS = 0.55;
const float FOUND_METAL = 0.52;
const float FOUND_ROUGH = 0.64;
// The planet the top of the air is measured on, for the sunlit top only: small,
// so the ember lasts an hour or two of the evening rather than twenty minutes.
const float R_EFF = 4.5e6;
// How bright the last sun is on the top: over its albedo, so it reads as lit
// metal and not as a lamp.
const float EMBER = 5.0;

float compress_len(float d) {
	if (d <= comp_d0) {
		return d;
	}
	return min(comp_d0 + comp_l * log(1.0 + (d - comp_d0) / comp_l), comp_max);
}

void vertex() {
	int b = int(CUSTOM0.x + 0.5) * 3;
	vec4 r0 = bone_rows[b];
	vec4 r1 = bone_rows[b + 1];
	vec4 r2 = bone_rows[b + 2];
	vec3 wp = vec3(dot(r0.xyz, VERTEX) + r0.w, dot(r1.xyz, VERTEX) + r1.w, dot(r2.xyz, VERTEX) + r2.w);
	vec3 wn = vec3(dot(r0.xyz, NORMAL), dot(r1.xyz, NORMAL), dot(r2.xyz, NORMAL));
	true_world = wp;
	body_local = VERTEX;
	vec3 v = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	if (comp_ortho) {
		float depth = -v.z;
		v.z = -compress_len(depth);
	} else {
		float d = length(v);
		if (d > comp_d0) {
			v *= compress_len(d) / d;
		}
	}
	VERTEX = v;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}

// The air a ray from the eye to `p` crosses in a layer that thins as
// exp(-height / scale), as the length of GROUND-level air that holds as much.
float layer_len(vec3 eye, vec3 p, float scale) {
	float d = distance(eye, p);
	float dh = p.y - eye.y;
	float e0 = exp(-max(eye.y, 0.0) / scale);
	if (abs(dh) < 1.0) {
		return d * e0;
	}
	return d * scale * (e0 - exp(-max(p.y, 0.0) / scale)) / dh;
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 dir = normalize(true_world - eye);
	float thicken = 1.0 + thick * 2.0;
	float low_len = layer_len(eye, true_world, h_low * thicken);
	float low = clamp(pow(smoothstep(land_fog.x, land_fog.y, low_len), land_fog.z) * land_fog.w, 0.0, 1.0);
	float high = beta_high * thicken * layer_len(eye, true_world, h_high);
	float air = 1.0 - (1.0 - low) * exp(-high);
	vec3 sky = dome_color(dome_procedural_join(dir, dome_procedural_sky(dir)), dome_seen_col(dir, true));
	// On Compatibility FOG is taken as linear light and encoded, while the sky it
	// has to match is written as it comes: measured on the web proxy, the legs'
	// bases came out 24 luma OVER the sky at noon and burned like searchlights at
	// night. So there the dome is decoded first (`sky_linear` is 1 on Forward+,
	// where the two already agree).
	FOG = vec4(mix(matter_linear(sky), sky, sky_linear), air);

	vec3 c = COLOR.rgb;
	// Light is marked in vertex alpha (colossus_model.gd): the lens 0.80, a cold
	// strip 0.70, a beacon 0.36.
	float mark = COLOR.a;
	bool lamp = mark < 0.98;
	bool lens = mark > 0.75 && mark < 0.85;
	bool strip = mark > 0.6 && mark <= 0.75;
	// Panels on the BODY's own frame, so they ride with it and do not swim: a
	// course of plate every 600 m up, ruled across by seams on the facets. At
	// this distance a seam is a pixel or less, so it fades by its own footprint
	// rather than shimmering.
	vec3 g = body_local / vec3(900.0, 600.0, 900.0);
	vec3 f = abs(fract(g) - 0.5);
	vec3 w = fwidth(g);
	float seam_y = 1.0 - smoothstep(0.0, max(0.06, w.y * 1.5), f.y);
	seam_y *= 1.0 - smoothstep(0.25, 0.5, w.y);
	float panel = ink_hash(floor(g.xz) + floor(g.y) * 7.0);
	if (!lamp) {
		c *= 1.0 - panel * 0.10 - seam_y * 0.28;
	}
	ALBEDO = matter_albedo(lamp ? c * 0.3 : c * FOUND_MASS);
	METALLIC = lamp ? 0.0 : FOUND_METAL;
	ROUGHNESS = lamp ? 0.3 : FOUND_ROUGH + seam_y * 0.3;
	SPECULAR = 0.48;
	// The machine's own light, on the machines' own power: the lens always (a
	// lamp in daylight shows its colour, not white), the cold strips and the
	// beacons only as the light goes, the beacons on a slow beat.
	float glow = 0.0;
	if (lens) {
		glow = mix(0.6, 3.0, lens_glow);
	} else if (strip) {
		glow = 2.4 * lens_glow;
	} else if (lamp) {
		float beat = fract(TIME * 0.45 + dot(floor(body_local.xz * 0.001), vec2(0.37, 0.61)));
		glow = (step(beat, 0.18) * 5.0 + 0.2) * lens_glow;
	}
	EMISSION = lamp ? matter_light(c * glow * sky_power()) : vec3(0.0);
	// THE TOP KEEPS THE SUN AFTER THE LAND HAS LOST IT. From `h` metres up the sun
	// is still over the horizon until it is sqrt(2h / R) below the ground's, and
	// on a planet of R_EFF that keeps the spire lit an hour and more after dusk:
	// an ember standing in a dark sky. The glow colour is the sky's own low sun
	// (`dome_glow_color`, a `source_color` uniform, so already in the renderer's
	// space and not put through matter_light a second time). The sun is the REAL
	// one the sky draws (`dome_sun_dir`), not the light's, which never sets.
	if (!lamp) {
		vec3 sun = normalize(dome_sun_dir);
		float sun_el = asin(clamp(sun.y, -1.0, 1.0));
		float dip = sqrt(2.0 * max(true_world.y, 0.0) / R_EFF);
		float sees_sun = smoothstep(-dip - 0.012, -dip + 0.012, sun_el);
		float land_lost = 1.0 - smoothstep(-0.02, 0.03, sun_el);
		vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float face = max(dot(n_world, sun), 0.0) * 0.8 + 0.2;
		EMISSION += matter_albedo(c) * dome_glow_color * (EMBER * face * sees_sun * land_lost);
	}
}
