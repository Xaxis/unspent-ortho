// GRASS: every tuft, reed, flower and frond a chunk's decor lays (Decor, the
// `grass` surface). Its own material so a blade pays for what a blade needs --
// the wind, the trample field, grass light -- and none of the terrain's library
// (ground marks, strata, works, crown and tall cuts: grass stands under
// CROWN_LIFT and under every tall floor).
//
// LIT LIKE GRASS, NOT LIKE A CARD. A blade's own face turns every way, so lit by
// its face half a sward goes black against the sun and reads as paper shards.
// Grass is lit by a normal bent most of the way to the sky, the light a sward
// actually shows: the blades share the light of the turf they stand in, and the
// face adds only a little grain. Both faces draw (cull_disabled), so a blade is
// one-sided geometry; the back face's NORMAL, which the renderer turns round,
// is turned back. The root takes the tuft's own shade, the tip goes pale and
// bleached, and the sun comes through a blade lit from behind (BACKLIGHT, both
// renderers: leaf.gdshader measured it).
//
// Opaque and never discarded, so early-z survives on WebGL. Casts no shadow
// (WorldView). Under the lens a far plant is left out by its seed (GRASS_THIN),
// collapsed to a point so it costs no fill; the orthographic frame is all near.
//
// Vertex channels (MeshKit, Decor):
//   COLOR.rgb  the blade's colour (palette sRGB); COLOR.a its MARK code / 255
//   UV2.x      sway weight: 0 at the root, rising to the tip
//   UV2.y      fraction: the plant's seed 0..1 (Decor writes one per plant);
//              whole part: its weight in the hundreds (Decor.HEAVY_TRIS), then
//              its species' motion (GrassSpecies.motion_code), tens the
//              stiffness in tenths and units the flutter, 0 for no species
//   UV         the plant's root in world xz (Decor), for what is decided per plant
shader_type spatial;
render_mode cull_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/render/wind.gdshaderinc"

// A blade bends further than a crown: 1 is a crown's stiffness.
const float GRASS_STIFF = 0.55;
// Tiles a tip goes over, per unit of sway weight, when a body parts it.
const float PART_LEAN = 0.42;
// And how far it drops when pressed flat.
const float PRESS_DROP = 0.22;
// How far a blade's normal is bent toward the sky: 1 lights it as the turf.
const float GRASS_UP = 0.8;
// The root against the tip: the tuft's own shade on its base. Mild, so by day
// no blade stands as a dark silhouette on the sward.
const float ROOT_SHADE = 0.74;
// How far the tip goes toward its own bleached, paler self.
const float TIP_BLEACH = 0.42;
// How much paler a blade laid over by a gust reads.
const float GUST_PALE = 0.3;
// How matte a blade is at least, and how much of its matter's specular it keeps.
const float GRASS_ROUGH = 0.85;
const float GRASS_SPEC = 0.3;
// Sun through a blade lit from behind: a blade passes green and yellow.
const vec3 GRASS_THROUGH = vec3(0.55, 0.62, 0.22);
// Under the lens: from here the plants thin, by their seed, to GRASS_THIN_KEEP
// of them at WorldView.DECOR_TO (72), where decor stops.
const float GRASS_THIN_FROM = 22.0;
const float GRASS_THIN_TO = 72.0;
const float GRASS_THIN_KEEP = 0.3;
// Per step of a plant's weight (its triangles / Decor.HEAVY_TRIS, 0..9, in the
// hundreds of UV2.y's whole part): how much sooner it starts to thin and how
// many fewer of it are kept at the far edge.
const float GRASS_HEAVY_SOONER = 0.25;
const float GRASS_HEAVY_FEWER = 0.3;

varying vec3 world_pos;
varying float sway_w;
varying float gust_v;
varying float code_v;
// What the weather has left on this plant (sky_settle, masked by what its
// ground can hold, SkyGround): x snow, y ash, z wet.
varying vec3 settle_v;

// THE WEATHER ON THE GRASS. Rain bows the tips (RAIN_DROOP tiles at full
// sway), stills the steady sway by RAIN_STILL, and shivers each blade on the
// fast beat of its hits; wet darkens a blade to WET_DARK and slicks it. Lying
// snow bows it further (SNOW_BOW) and stiffens it (SNOW_STILL), and lies white
// on the upper blade in lumps; ash greys it toward the fall.
const float RAIN_DROOP = 0.10;
const float RAIN_STILL = 0.35;
const float RAIN_HITS = 0.012;
const float WET_DARK = 0.72;
const float SNOW_BOW = 0.16;
const float SNOW_STILL = 0.6;
const float ASH_GREY = 0.65;
const vec3 SNOW_ON = vec3(0.8667, 0.9412, 0.9686);

void vertex() {
	sway_w = UV2.x;
	settle_v = vec3(0.0);
	float seed = fract(UV2.y);
	float heavy = floor(floor(UV2.y) / 100.0);
	float code = mod(floor(UV2.y), 100.0);
	code_v = code;
	float stiff = code >= 10.0 ? floor(code / 10.0) / 10.0 : GRASS_STIFF;
	float flutter = mod(code, 10.0);
	gust_v = 0.0;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat3 to_model = inverse(mat3(MODEL_MATRIX));
	vec3 up_m = to_model * vec3(0.0, 1.0, 0.0);
	bool left_out = false;
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		float d = distance(vec3(UV.x, wp.y, UV.y), INV_VIEW_MATRIX[3].xyz);
		// A heavy plant (a frond, a head of cotton) thins sooner and further.
		float from = GRASS_THIN_FROM / (1.0 + GRASS_HEAVY_SOONER * heavy);
		float keep = GRASS_THIN_KEEP / (1.0 + GRASS_HEAVY_FEWER * heavy);
		left_out = seed > mix(1.0, keep, smoothstep(from, GRASS_THIN_TO, d));
	}
	NORMAL = normalize(mix(NORMAL, up_m, GRASS_UP));
	if (left_out) {
		// Every corner of the plant to one point: no area, no fill.
		VERTEX = vec3(0.0);
	} else if (sway_w > 0.0) {
		settle_v = sky_settle.xyz * sky_ground_at(wp).rgb;
		float rain = sky_air.x;
		vec3 push = wind_push(wp, sway_w, seed, stiff) * (1.0 - RAIN_STILL * rain) * (1.0 - SNOW_STILL * settle_v.x);
		// The weight of water and snow on the upper blade.
		push.y -= (max(rain, settle_v.z) * RAIN_DROOP + settle_v.x * SNOW_BOW) * sway_w * sway_w;
		// Rain hitting: a fast shiver of its own, each blade on its own beat, a
		// whole multiple of the sky's phase so it never jumps at the wrap.
		float hit = sky_wind.w * 37.0 + seed * 91.0 + wp.x * 13.1 + wp.z * 7.7;
		push.y += sin(hit) * sin(hit * 0.37) * RAIN_HITS * rain * sway_w;
		float g = gust_at(wp.xz);
		gust_v = g * sway_w;
		// A species' own shiver over the sway: a whole multiple of the sky's
		// phase, so it quickens with the wind and never jumps at the wrap.
		if (flutter > 0.0) {
			vec2 dir = wind_dir();
			float f = sky_wind.w * (2.0 + flutter) + seed * 40.0;
			push += vec3(-dir.y, 0.0, dir.x) * sin(f) * sway_w * 0.01 * flutter * (0.3 + wind_strength) * (0.4 + g);
		}
		vec3 tr = trample_at(wp.xz);
		push += vec3(tr.x, 0.0, tr.y) * PART_LEAN * sway_w;
		push.y -= (length(tr.xy) * 0.5 + tr.z) * PRESS_DROP * sway_w;
		// A blade keeps its length: the further its tip goes over, the lower it
		// sits, so a gust lays the grass down instead of stretching it.
		float over = length(push.xz);
		push.y -= min(over * over * 1.6 / max(sway_w, 0.1), over * 0.9);
		VERTEX += to_model * (mat3(INV_VIEW_MATRIX) * wind_view(push, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE));
		NORMAL = wind_tilt(NORMAL, to_model * push, sway_w, up_m);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The renderer turned a back face's normal round; the sky-bent normal is the
	// same on both faces of a blade.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec2 px = matter_px(world_pos);
	int m = int(COLOR.a * 255.0 + 0.5);
	vec3 c = COLOR.rgb;
	float h = smoothstep(0.0, 0.9, sway_w);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 bleached = mix(c, vec3(lum) * vec3(1.32, 1.26, 1.02) + vec3(0.05, 0.045, 0.02), 0.6);
	// A species brings its own tip colour, so it bleaches only a little more.
	float bleach = code_v >= 10.0 ? TIP_BLEACH * 0.3 : TIP_BLEACH;
	c = mix(c * ROOT_SHADE, mix(c, bleached, bleach), smoothstep(0.0, 0.85, h));
	c = mix(c, c * (1.0 + GUST_PALE) + vec3(0.03, 0.03, 0.02), gust_v);
	// Wet: darker, and slick (ROUGHNESS below).
	float wet = max(sky_settle.z > 0.0 ? settle_v.z : 0.0, sky_air.x * 0.8);
	c *= mix(1.0, WET_DARK, wet);
	// Ash: greyed toward what falls, most on the upper blade that catches it.
	c = mix(c, mix(vec3(lum) * 0.8, SKY_ASH, 0.5), settle_v.y * ASH_GREY * (0.4 + 0.6 * h));
	// Snow: lying on the upper blade in lumps, pinned to the world.
	float lump = sky_noise(world_pos.xz * 5.3 + world_pos.y * 3.1);
	float snow_on = settle_v.x * smoothstep(0.25, 0.7, h) * smoothstep(0.35, 0.6, lump + settle_v.x * 0.35);
	c = mix(c, SNOW_ON, snow_on);
	c = sky_apply(c, world_pos, TIME);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 mr = matter_of(m);
	float rough_add = 0.0;
	// A living blade is the land growing, not a thing left standing in it: it
	// takes the land's share of the place's wear (world.gdshader), not a post's.
	c = matter_worn(c, matter_wear(world_pos), n_world, world_pos, 0.14, rough_add);
	ALBEDO = matter_albedo(c);
	// Matte: a blade lit by a sky-bent normal and seen at a grazing angle would
	// otherwise mirror the sky and go silver, which reads as paper, not grass.
	ROUGHNESS = clamp(max(mr.x, GRASS_ROUGH) + rough_add - gust_v * 0.1 - wet * 0.4, 0.04, 1.0);
	SPECULAR = mr.y * GRASS_SPEC;
	METALLIC = mr.w;
	BACKLIGHT = GRASS_THROUGH * (0.35 + 0.65 * h);
	EMISSION = matter_light(neon_reflect(world_pos, px) + neon_skyglow(c));
}
