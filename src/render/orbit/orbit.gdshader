// THE RING, lit by its own sun in its own layer (orbit_layer.gd), in KILOMETRES.
//
// Lit by the renderer, like everything else: there is no light() here. The
// layer's one DirectionalLight3D stands where the REAL sun is (SkyLight.sky_sun),
// which sets, so after dusk the land is dark while the ring four hundred
// kilometres up is still in full sun -- gold over a dark land -- until the
// Earth's shadow reaches it.
//
// THE EARTH'S SHADOW IS GEOMETRY, asked per fragment: a point behind the
// planet's terminator plane and inside its cylinder gets no sun (`sunlit`,
// the mirror of OrbitPass.sunlit, with the half-degree sun's penumbra). So the
// shadow is seen creeping round the rim, and the last light is RED: sunlight
// that grazes the limb has come through the whole of the air. Shadow is laid on
// by scaling what the surface reflects (ALBEDO, SPECULAR), since the renderer's
// light cannot know where the planet is.
//
// THE RING'S OWN LIGHTS are EMISSION and ignore the shadow: cold ruled rows on
// the rim with whole runs dead, the hub's slow beacon, the wound's embers
// flickering and its rare arcs, and one warm amber point (ring_model.gd).
//
// Lamps and thin parts keep a least size on the glass (the colossi's rule,
// numbers duplicated from colossus.gdshader, to dedupe into a shared include):
// a tube is never under MIN_PX, a lamp never under LAMP_PX.
shader_type spatial;
render_mode cull_disabled, skip_vertex_transform, shadows_disabled;

#define SKY_FOUND
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

uniform vec4 bones[48];
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 earth = vec3(0.0, -4500.0, 0.0);
uniform float planet_km = 4500.0;
uniform float px_angle = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.30);
// How much sunlit ground lies below, for the light it throws back up.
uniform float planet_day = 1.0;
// 0 by day .. 1 at night: the lamps are as bright as they are, but a lamp
// against a daylit sky shows its colour, not a star.
uniform float night = 1.0;
// HOW MUCH A LAMP SHOWS against the sky it is seen on, 0..1, off the sky's own
// brightness (orbit_layer.gd `lamp_seen`): a lamp the size of a street is a
// point four hundred kilometres up, and a white point in a noon sky is a bug on
// the glass, not a light. Every lamp is multiplied by it.
uniform float lamp_seen = 1.0;

// DUPLICATES of colossus.gdshader's least sizes.
const float MIN_PX = 0.75;
const float LAMP_PX = 1.6;
// OrbitPass.PENUMBRA_KM, RED_LIMB_KM.
const float PENUMBRA_KM = 20.0;
const float RED_LIMB_KM = 90.0;

varying vec3 world_km;
varying float thin;
varying float kind_v;
varying float cls_v;
varying float burn_v;
varying vec2 corner_v;

vec3 bone_apply(int b, vec3 p) {
	vec4 r0 = bones[b];
	vec4 r1 = bones[b + 1];
	vec4 r2 = bones[b + 2];
	return vec3(dot(r0.xyz, p) + r0.w, dot(r1.xyz, p) + r1.w, dot(r2.xyz, p) + r2.w);
}

vec3 bone_dir(int b, vec3 n) {
	return vec3(dot(bones[b].xyz, n), dot(bones[b + 1].xyz, n), dot(bones[b + 2].xyz, n));
}

void vertex() {
	int b = int(CUSTOM0.x + 0.5) * 3;
	int kind = int(CUSTOM0.y + 0.5);
	vec3 centre = CUSTOM1.xyz;
	vec3 local = VERTEX;
	vec3 c_world = (MODEL_MATRIX * vec4(bone_apply(b, centre), 1.0)).xyz;
	vec3 c_view = (VIEW_MATRIX * vec4(c_world, 1.0)).xyz;
	float px = length(c_view) * px_angle;
	thin = 1.0;
	kind_v = float(kind);
	cls_v = CUSTOM1.w;
	burn_v = CUSTOM1.w;
	corner_v = CUSTOM0.zw;
	if (kind == 2) {
		// A lamp: opened on the glass round its point, a hair nearer than the
		// plate it sits on.
		vec3 v = c_view + vec3(CUSTOM0.zw, 0.0) * max(LAMP_PX * 0.5 * px, UV.x);
		v *= 1.0 - 2.0 * px / max(length(v), 1.0);
		world_km = c_world;
		VERTEX = v;
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		if (kind == 1 && px > 0.0) {
			vec3 o = local - centre;
			float l = length(o);
			float want = MIN_PX * px * 0.5;
			if (l > 1e-5 && l < want) {
				local = centre + o * (want / l);
				thin = l / want;
			}
		}
		vec3 w = (MODEL_MATRIX * vec4(bone_apply(b, local), 1.0)).xyz;
		world_km = w;
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
		vec3 n = mat3(MODEL_MATRIX) * bone_dir(b, NORMAL);
		NORMAL = normalize(mat3(VIEW_MATRIX) * n);
	}
}

// OrbitPass.sunlit: 1 in the sun, 0 in the Earth's shadow; and how red the
// light that still reaches it is (1 = the limb's last light).
vec2 sunlit(vec3 p_world) {
	vec3 at = p_world - earth;
	vec3 s = normalize(sun_dir);
	float along = dot(at, s);
	if (along >= 0.0) {
		return vec2(1.0, 0.0);
	}
	float perp = length(at - s * along);
	float lit = smoothstep(planet_km - PENUMBRA_KM, planet_km + PENUMBRA_KM, perp);
	float red = 1.0 - smoothstep(planet_km, planet_km + RED_LIMB_KM, perp);
	return vec2(lit, red);
}

float hash1(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	vec2 sl = sunlit(world_km);
	bool return_plume = false;
	if (kind_v > 1.5) {
		// A lamp: a soft square, brightest at its point.
		float r = length(corner_v);
		float shape = 1.0 - smoothstep(0.35, 1.0, r);
		float cls = cls_v;
		vec3 c = COLOR.rgb;
		float glow = 0.0;
		float seed = dot(floor(world_km * 3.0), vec3(0.37, 0.61, 0.83));
		if (cls < 0.5) {
			// The rim's rows: steady, the machines' ruled light.
			glow = 2.4 * mix(0.12, 1.0, night);
		} else if (cls < 1.5) {
			// The hub's beacon: a slow cold beat.
			float beat = fract(TIME * 0.21 + hash1(seed) * 0.1);
			glow = (step(beat, 0.12) * 9.0 + 0.3);
		} else if (cls < 2.5) {
			// The wound's embers: never still, never out.
			float f = 0.55 + 0.45 * sin(TIME * (3.0 + hash1(seed) * 5.0) + seed * 7.0) * sin(TIME * 1.3 + seed);
			glow = 3.2 * f;
		} else if (cls < 3.5) {
			// An arc: dark almost always, a flash a few times a minute.
			float t = TIME * 0.8 + hash1(seed) * 40.0;
			float slot = floor(t);
			float on = step(0.93, hash1(slot + seed)) * step(fract(t), 0.12);
			glow = 16.0 * on;
		} else if (cls < 4.5) {
			// The one warm light: three short, a long dark.
			float t = fract(TIME / 6.0) * 6.0;
			float on = step(t, 0.3) + step(0.6, t) * step(t, 0.9) + step(1.2, t) * step(t, 1.5);
			glow = 0.4 + 3.2 * on;
		} else if (cls < 5.5) {
			// The habitat's last lamps, dim.
			glow = 1.1 * mix(0.3, 1.0, night);
		} else {
			// A vent plume: crystal in sunlight, nothing in the shadow. Thin by
			// STIPPLE (the layer is supersampled, so four samples a pixel average
			// it into a veil), thinner toward its edge and its far end.
			float veil = shape * 0.55;
			if (sl.x < 0.02 || hash1(dot(floor(FRAGCOORD.xy), vec2(0.713, 1.37))) > veil) {
				discard;
			}
			// Ice scatters forward: brightest looking toward the sun through it.
			float fwd = pow(max(dot(normalize(world_km), normalize(sun_dir)), 0.0), 4.0);
			ALBEDO = vec3(0.0);
			ROUGHNESS = 1.0;
			SPECULAR = 0.0;
			EMISSION = matter_light(c) * sl.x * (0.45 + 2.5 * fwd) * mix(vec3(1.0), glow_color * 1.6, sl.y);
			return_plume = true;
		}
		glow *= lamp_seen;
		if (!return_plume) {
		if (shape * glow <= 0.001) {
			discard;
		}
		ALBEDO = vec3(0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		EMISSION = matter_light(c) * glow * shape * (cls < 1.5 ? sky_power() : 1.0);
		}
	} else {
		vec3 c = COLOR.rgb;
		float cls = COLOR.a;
		bool sail = cls > 0.75 && cls < 0.85;
		bool torn = cls > 0.55 && cls < 0.65;
		bool cable = cls < 0.45;
		// Panels: courses and plates on the part's own coordinates, each let in by
		// its own footprint on the glass so none shimmers.
		vec2 g = UV / vec2(1.6, 0.8);
		vec2 f = abs(fract(g) - 0.5);
		vec2 w = fwidth(g);
		float seen = 1.0 - smoothstep(0.2, 0.45, max(w.x, w.y));
		float seam = (1.0 - smoothstep(0.0, max(0.06, w.x * 1.5), f.x)) * seen;
		seam = max(seam, (1.0 - smoothstep(0.0, max(0.06, w.y * 1.5), f.y)) * seen);
		// Plates vary ALONG the part only (a run of plate, then the next), never in
		// a grid: a hash on both axes at a few pixels a cell is a mosaic.
		float plate = ink_hash(vec2(floor(g.x), 3.0)) * seen;
		vec2 g2 = UV / vec2(8.0, 3.2);
		// A course is let in by its own footprint too: at four pixels a course a
		// hash apart is a checkerboard, which is the one thing this may never be.
		float course = ink_hash(vec2(floor(g2.x), 7.0)) * (1.0 - smoothstep(0.06, 0.16, max(fwidth(g2).x, fwidth(g2).y)));
		c *= 1.0 - plate * 0.08 - seam * 0.22 - course * 0.08;
		// Scorch toward the torn ends.
		float burn = torn ? max(burn_v, 0.4) : burn_v * 0.8;
		if (!cable) {
			c = mix(c, c * vec3(0.35, 0.30, 0.30), clamp(burn, 0.0, 1.0));
		}
		// The shadow of the Earth, and the red of the last light through the limb.
		vec3 tint = mix(vec3(1.0), glow_color * vec3(1.25, 0.95, 0.75), sl.y);
		ALBEDO = matter_albedo(c) * tint * sl.x;
		METALLIC = sail ? 0.8 : 0.3;
		ROUGHNESS = sail ? 0.18 : clamp(0.62 + seam * 0.25 - plate * 0.1, 0.05, 1.0);
		SPECULAR = 0.5 * sl.x;
		// The planet under it throws its own light back up on the hull (by day
		// the hull's underside is the sky's colour, plus this).
		vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 down = normalize(earth - world_km);
		float faces = clamp(dot(n_w, down) * 0.5 + 0.5, 0.0, 1.0);
		EMISSION = matter_albedo(c) * vec3(0.30, 0.34, 0.42) * 0.08 * planet_day * faces;
		// Embers where the rim was torn, deep in the plate.
		if (burn > 0.6 && !cable) {
			float flick = 0.6 + 0.4 * sin(TIME * 2.3 + dot(world_km, vec3(3.1, 1.7, 2.3)));
			EMISSION += matter_light(vec3(1.0, 0.35, 0.08)) * (burn - 0.6) * 1.8 * flick;
		}
		// THE HABITAT'S WINDOWS on the side walls: three decks of them, a cold one
		// lit here and there by whatever still runs, most dark. Seen whole where a
		// window is a pixel or more; further off each deck is its average, a faint
		// ruled line of light along the wheel, never a crawl of single pixels.
		if (cls > 0.93 && cls < 0.97) {
			float wall_v = UV.y;
			vec2 wg = vec2(UV.x / 0.45, wall_v / 0.55);
			float deck_row = floor(wg.y);
			float in_row = smoothstep(0.25, 0.4, fract(wg.y)) * (1.0 - smoothstep(0.6, 0.75, fract(wg.y)));
			float cell = floor(wg.x);
			float run_lit = step(0.55, ink_hash(vec2(floor(cell / 23.0), deck_row + 41.0)));
			float lit = step(0.86, ink_hash(vec2(cell, deck_row + 17.0))) * run_lit;
			float fine = 1.0 - smoothstep(0.35, 0.8, max(fwidth(wg).x, fwidth(wg).y));
			float average = 0.14 * 0.45 * 0.35;
			float light = mix(average, lit * in_row, fine);
			ALBEDO *= 1.0 - in_row * fine * 0.35;
			EMISSION += matter_light(vec3(0.62, 0.78, 1.0)) * light * 3.0 * lamp_seen;
		}
		// A part drawn wider than it is gives the rest back to the sky.
		EMISSION *= thin;
		ALBEDO *= thin;
		SPECULAR *= thin;
	}
}
