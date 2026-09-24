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

// The sun's disc in the procedural sky (see the fragment).
uniform bool l0_on = false;
uniform vec3 l0_dir = vec3(0.0, 1.0, 0.0);
uniform float l0_size = 0.01;
uniform vec3 l0_color : source_color = vec3(1.0);
uniform float l0_energy = 1.0;

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
// And a floor under it that is not the albedo's: the plate is dark on purpose, and
// times a dark albedo the last sun came out a smear nobody saw (coast, 21:30).
const float EMBER_FLOOR = 0.35;
// How far over a fragment's own horizon (radians) the sun must stand to light it
// fully, and the colour of the last of it, as a share of the glow: the sun
// through the whole low air is red and a fifth as bright.
const float EMBER_RISE = 0.06;
const vec3 EMBER_LOW = vec3(0.55, 0.12, 0.10);

float compress_len(float d) {
	if (d <= comp_d0) {
		return d;
	}
	return min(comp_d0 + comp_l * log(1.0 + (d - comp_d0) / comp_l), comp_max);
}

// A pixel's size in metres at one metre from the eye (2 tan(fov/2) / rows),
// handed over by the view every frame. 0 turns the minimum sizes off.
uniform float px_angle = 0.0;

// THE LEAST A PART MAY BE DRAWN, in pixels of radius. A shin ninety metres
// across is a quarter of a pixel at 150 km, and drawn honestly it is a dashed
// line that crawls as it walks; a spire's needle is worse. So anything thinner
// than `MIN_PX` is drawn that wide and let into the air by the share it was
// widened (`thin`), which keeps it a continuous faint line whose weight is still
// its own. A LAMP is not let off that way: a light is how a thing is seen at
// night, so every lamp is at least `LAMP_PX`, and the lens a little more.
const float MIN_PX = 0.75;
const float LAMP_PX = 1.6;
const float LENS_PX = 2.2;
const float LAMP_BIAS = 0.06;
// A ring's least reach past its leg, and its least depth, in pixels; and the
// share its authored flange stands proud of the plate (colossus_model.gd
// STRIP_PROUD), to find the plate from the ring's own outer radius.
const float RING_PX = 1.4;
const float RING_TALL_PX = 2.6;
const float STRIP_PROUD = 1.24;

// The legs' two bones, for the pulse's run up them: (thigh, shin), metres.
uniform vec2 leg_len = vec2(34000.0, 36000.0);
// How often a pulse leaves each ankle (per second), and how far behind its front
// it still lights, as a share of the whole leg.
const float PULSE_RATE = 0.12;
const float PULSE_TRAIL = 0.22;

varying float thin;
varying float bone_phase;

void vertex() {
	int b = int(CUSTOM0.x + 0.5) * 3;
	int kind = int(CUSTOM0.y + 0.5);
	vec3 lamp_c = vec3(CUSTOM0.w, CUSTOM0.z, 0.0);
	vec4 r0 = bone_rows[b];
	vec4 r1 = bone_rows[b + 1];
	vec4 r2 = bone_rows[b + 2];
	vec3 local = VERTEX;
	vec3 eye_w = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 at = vec3(dot(r0.xyz, local) + r0.w, dot(r1.xyz, local) + r1.w, dot(r2.xyz, local) + r2.w);
	float px = distance(at, eye_w) * px_angle;
	thin = 1.0;
	if (px > 0.0) {
		float r = length(local.xz);
		if (kind == 0) {
			// Round the part's own axis: every leg, the spire.
			float want = MIN_PX * px;
			if (r > 1e-3 && r < want) {
				local.xz *= want / r;
				thin = r / want;
			}
		} else if (kind == 1) {
			// A RING (colossus_model.gd `_strip`): its inner edge follows the
			// plate as the plate is widened, and its outer edge stands at least
			// RING_PX past it on every side, so the ring reads as a ring round a
			// leg however far off the leg is -- a bold line of light and never a
			// crawl of dashes. `lamp_c.x` is the ring's own outer radius.
			float outer = lamp_c.x;
			bool rim = outer > 0.0 && r > outer * 0.995;
			float plate_want = MIN_PX * px;
			float want = rim ? max(plate_want, outer / STRIP_PROUD) + RING_PX * px : plate_want;
			if (r > 1e-3 && r < want) {
				local.xz *= want / r;
			}
			float dy = local.y - lamp_c.y;
			float half_px = RING_TALL_PX * px * 0.5;
			if (abs(dy) > 1e-3 && abs(dy) < half_px) {
				local.y = lamp_c.y + sign(dy) * half_px;
			}
		} else {
			vec3 o = local - lamp_c;
			float want = (kind == 3 ? LENS_PX : LAMP_PX) * px;
			float l = length(o);
			if (l > 1e-3 && l < want) {
				local = lamp_c + o * (want / l);
			}
		}
	}
	vec3 wp = vec3(dot(r0.xyz, local) + r0.w, dot(r1.xyz, local) + r1.w, dot(r2.xyz, local) + r2.w);
	vec3 wn = vec3(dot(r0.xyz, NORMAL), dot(r1.xyz, NORMAL), dot(r2.xyz, NORMAL));
	true_world = wp;
	body_local = VERTEX;
	bone_phase = CUSTOM0.x;
	// HULL-DOWN: on the colossi's own small planet (R_EFF) the ground falls away
	// by the square of the distance over twice the radius below the eye's
	// horizon, so a walker on the skyline stands with its feet below the curve of
	// the world, the way a ship's hull goes first. Only WHERE it is drawn drops;
	// the air is still asked of its true height.
	float flat_d = length(wp.xz - eye_w.xz);
	vec3 drawn = wp - vec3(0.0, flat_d * flat_d / (2.0 * R_EFF), 0.0);
	vec3 v = (VIEW_MATRIX * vec4(drawn, 1.0)).xyz;
	if (comp_ortho) {
		float depth = -v.z;
		v.z = -compress_len(depth);
	} else {
		float d = length(v);
		if (d > comp_d0) {
			v *= compress_len(d) / d;
		}
	}
	// A LAMP IS PROUD OF ITS PLATE BY TENS OF METRES, and fifty kilometres out
	// the log leaves that a fiftieth of a unit of depth: every strip lost the
	// depth test to the leg it rings and only its edges were drawn (measured,
	// coast 22:00). So a lamp is drawn `LAMP_BIAS` nearer along its own ray --
	// enough to win against the plate it sits on, far less than the quarter unit
	// a leg is thick there, so the half of a ring behind the leg stays hidden.
	if (kind != 0) {
		v *= 1.0 - LAMP_BIAS / max(length(v), 1.0);
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
	// A part drawn wider than it is gives the rest back to the air.
	air = 1.0 - (1.0 - air) * clamp(thin, 0.0, 1.0);
	// The procedural sky with the sun's disc on it, as the sky shader lays it
	// (LIGHT0, handed over by SkyLight.seen_air), so across the band where the
	// seen sky comes in the air near the sun is the sky's own there too.
	vec3 proc = dome_procedural_sky(dir);
	proc = dome_sun_in(proc, dir, l0_on, l0_dir, l0_size, l0_color, l0_energy);
	vec3 sky = dome_color(dome_procedural_join(dir, proc), dome_seen_col(dir, true));
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
	// Panels on the BODY's own frame, so they ride with it and do not swim, at
	// TWO scales: courses of plate every 600 m up with seams on the facets, and
	// inside each course the plates it is laid in, a quarter that size. Each
	// scale is let in by its own footprint on the glass (`fwidth`): a seam
	// thinner than a pixel is faded rather than drawn, so the walker on the
	// skyline shows its courses and the one looming shows its plates too, and
	// neither shimmers as it walks.
	vec3 g = body_local / vec3(900.0, 600.0, 900.0);
	vec3 f = abs(fract(g) - 0.5);
	vec3 w = fwidth(g);
	float seam_y = 1.0 - smoothstep(0.0, max(0.06, w.y * 1.5), f.y);
	seam_y *= 1.0 - smoothstep(0.25, 0.5, w.y);
	vec3 g2 = body_local / vec3(230.0, 150.0, 230.0);
	vec3 f2 = abs(fract(g2) - 0.5);
	vec3 w2 = fwidth(g2);
	float fine_seen = 1.0 - smoothstep(0.2, 0.45, max(w2.x, max(w2.y, w2.z)));
	float seam2 = (1.0 - smoothstep(0.0, max(0.05, w2.y * 1.5), f2.y)) * fine_seen;
	float panel = ink_hash(floor(g.xz) + floor(g.y) * 7.0);
	float plate = ink_hash(floor(g2.xz) * 1.7 + floor(g2.y) * 3.1 + vec2(11.0, 5.0)) * fine_seen;
	if (!lamp) {
		c *= 1.0 - panel * 0.10 - seam_y * 0.28 - plate * 0.07 - seam2 * 0.16;
	}
	ALBEDO = matter_albedo(lamp ? c * 0.3 : c * FOUND_MASS);
	METALLIC = lamp ? 0.0 : FOUND_METAL;
	ROUGHNESS = lamp ? 0.3 : clamp(FOUND_ROUGH + seam_y * 0.3 + seam2 * 0.15 - plate * 0.12, 0.05, 1.0);
	SPECULAR = 0.48;
	// The machine's own light, on the machines' own power: the lens always (a
	// lamp in daylight shows its colour, not white), the cold strips and the
	// beacons only as the light goes, the beacons on a slow beat.
	float glow = 0.0;
	if (lens) {
		glow = mix(0.6, 3.0, lens_glow);
	} else if (strip) {
		// A PULSE CLIMBS EVERY LEG on the machines' beat: a front of light runs
		// from the ankle, ring by ring, up the shin and on up the thigh to the
		// hip, a leg at a time, and trails off behind itself. Measured as the
		// distance UP THE LEG from the ankle (`leg_len`: thigh, shin), which a
		// bone's own y does not give -- the shin's runs down from the knee and
		// the thigh's from the hip -- so the front is one line up the whole leg.
		int part = int(bone_phase + 0.5);
		float up = -1.0;
		if (part > 0) {
			int seg = (part - 1) % 3;
			if (seg == 1) {
				up = leg_len.y - body_local.y;
			} else if (seg == 0) {
				up = leg_len.y + leg_len.x - body_local.y;
			}
		}
		float pulse = 0.0;
		if (up >= 0.0) {
			float leg_at = float((part - 1) / 3);
			float front = fract(TIME * PULSE_RATE + leg_at / 3.0) * 1.35 - 0.15;
			float behind = front - up / (leg_len.x + leg_len.y);
			pulse = smoothstep(-0.015, 0.0, behind) * (1.0 - smoothstep(0.0, PULSE_TRAIL, behind));
		}
		glow = (2.4 + 9.0 * pulse) * lens_glow;
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
		// GRADED BY HEIGHT, not a body lit at once: `over` is how high the sun
		// stands above this fragment's own horizon. Just over it the light has
		// crossed the whole low air and is a dim deep red; a few degrees over,
		// it is the sky's gold at full strength. So the terminator climbs the
		// legs as a gradient -- dark feet, red knees, a gold hub, the spire the
		// last thing lit -- and the lit part is never one flat colour.
		float over = sun_el + dip;
		float sees_sun = smoothstep(-0.004, EMBER_RISE, over);
		float land_lost = 1.0 - smoothstep(-0.02, 0.03, sun_el);
		vec3 last_sun = mix(EMBER_LOW * dome_glow_color, dome_glow_color, smoothstep(0.0, EMBER_RISE * 1.6, over));
		vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float face = max(dot(n_world, sun), 0.0) * 0.8 + 0.2;
		EMISSION += (matter_albedo(c) * EMBER + EMBER_FLOOR) * last_sun * (face * sees_sun * land_lost);
	}
}
