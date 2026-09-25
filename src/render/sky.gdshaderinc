// The sky over the world (docs/LOOK.md). Owned by the sky package. Included by
// every lit shader (world, found, water, person) and by the weather marks.
//
// Under LANTERN this file is no longer a TINT. The hour's colour, the weather's
// colour and a landscape's own light are the SUN's colour and the SKY's colour
// now, set on the real lights by SkyLight; what is left here is what the air and
// the weather do to a surface the light has already found:
//
//   sky_apply(albedo, world_pos, TIME)   in fragment(): what has SETTLED on this
//                                        surface (snow, ash, wet), the bank of
//                                        fog or the whiteout it is seen
//                                        through, a cloud's shade over it, the
//                                        glare, and the white of a strike
//   sky_power()                          a multiply for the machines' own light
//                                        (FOUND strips, beacons, stolen neon):
//                                        1 steady, stuttering after lightning
//   sky_gloom()                          how little light there is (0 full day,
//                                        1 dead of night)
//   neon_reflect(world_pos, px)          emission for wet ground: the glint list
//                                        mirrored as broken streaks
//
// Four functions are kept as no-ops on purpose, because half a dozen shaders
// call them and each is converted in its turn: sky_ink (there is no hatch to
// lay), sky_pool (real lights make their own pools now), neon_graded (the grade
// is one knob on the Environment, not a per-fragment multiply) and neon_skyglow
// (the sky's own light is AMBIENT light, not emission added to every surface).
// Each says below what took its job.
//
// Every global is written by SkyLight (src/render/sky_light.gd) and nothing else.
#ifndef SKY_GDSHADERINC
#define SKY_GDSHADERINC

// Time of day x season x region x weather: the colour of the light.
global uniform vec3 sky_tint;
// THE COLOSSI'S SHADOWS (19_colossi writes these, once a frame). xyz: the way
// to the REAL sun (the one the sky draws, not the light, which never sets);
// w: how many capsules are live, 0..8 -- 0 on every frame nothing of theirs
// falls near the player, which is nearly all of them, and then nothing below is
// asked. Each mat4 holds two tapered capsules as columns (a.xyz, radius at a),
// (b.xyz, radius at b).
global uniform vec4 colossus_sun;
global uniform mat4 colossus_legs0;
global uniform mat4 colossus_legs1;
global uniform mat4 colossus_legs2;
global uniform mat4 colossus_legs3;
// THE SHOCK OF A LANDING, for what sways (19_colossi writes it): xy the tread's
// centre in world XZ, z how far out the front has run (metres), w how hard it
// still pushes, 0..1 -- 0 on every frame no foot has just come down, and then
// `sky_shock` returns at once.
global uniform vec4 colossus_shock;
// xy: horizontal offset per unit height toward the light (clouds on walls line
// up with clouds on the ground); z: light level 0..1; w: lightning flash 0..1.
global uniform vec4 sky_sun;
// xy: cloud drift in tiles; z: coverage 0..1; w: shadow strength 0..1 (0 at night).
global uniform vec4 sky_clouds;
// xy: fog drift in tiles; z: fog density 0..1; w: spare.
global uniform vec4 sky_fog;
// x: world units per screen pixel; y: night fall 0..1; z: 1 / world size (for
// sky_ground); w: tiles the afterglow of the last strike has rolled out.
global uniform vec4 sky_view;
// How far the night's own dark has come: 0 in daylight, 1 in the dead of night,
// and up in a sky darker than its hour whatever the clock says. x is the blue
// floor under the washes, y the skyglow, which is held back behind it. Both are
// spent against the light the evening is losing, NOT against how far night has
// fallen: see the header of SkyLight.night_dark for what the eased curve
// sky_view.y walks measured.
global uniform vec2 sky_night;
// The airs over the focus: x rain falling now (rain, drizzle, hail) 0..1,
// y glare 0..1 (hard white light bleaching the washes), z how warm the fog is
// drawn (0 page-pale mist, 1 furnace haze), w whiteout 0..1.
global uniform vec4 sky_air;
// Where the player is looking: xyz the camera's focus in world space, w spare.
// A whiteout closes in from the distance toward it.
global uniform vec4 sky_focus;
// Lightning after a strike: xy the strike's world x/z, z the afterglow rolling
// through the clouds 0..1 (stepped), w the machines' power 0..1 (1 = steady).
global uniform vec4 sky_bolt;
// The glint list: lights mirrored in wet ground, nearest the camera first. One
// per column: xyz world position of the light, w its level 0..1 (0 = unused).
// Colours in glint_rgb*: rgb, w spare. Not lights: nothing is lit by them.
global uniform mat4 sky_glints;
global uniform mat4 sky_glints2;
global uniform mat4 sky_glints3;
global uniform mat4 glint_rgb;
global uniform mat4 glint_rgb2;
global uniform mat4 glint_rgb3;
// What the weather has left lying (Weather.settled): x snow, y ash, z wet; w spare.
global uniform vec4 sky_settle;
// For anything that sways: xy = wind along world x/z times strength; z gust;
// w = phase in radians, advanced by the wind so a sway never jumps.
global uniform vec4 sky_wind;
// Lamp and fire pools near the camera, one per column: xyz = the light's world
// position, w = its range in tiles (0 = unused). The same lights as the
// OmniLight3D pool, so the pool the light paints is the pool the ink leaves.
global uniform mat4 sky_lamps;
global uniform mat4 sky_lamps2;
// rgb: a multiply for faces in shade (cast or turned away) that takes the
// dawn and dusk warmth back out of them, so low sun is warm on what it lights
// and shade stays blue; w: low light 0..1 (0 at midday, 1 from dusk to dawn).
global uniform vec4 sky_shade;
// What the land can hold, by world position (SkyGround): r snow can lie, g ash
// can lie, b wet can show, a the ground's height smoothed over ~8 tiles / 8.
// Sampled at world xz * sky_view.z.
global uniform sampler2D sky_ground;
// What the land DOES to a thing standing on it (SkyWear), by world position:
// r rust, g salt bloom, b soot, a frost. The same sampling as sky_ground.
// Read by matter_worn(); LANTERN law 1.
global uniform sampler2D sky_wear;
// 1 where the renderer wants ALBEDO in LINEAR light and will encode the frame
// to sRGB itself (Forward+), 0 where it hands the value straight to the display
// (Compatibility). Measured, both; matter.gdshaderinc says what it is for.
// Written once at boot by SkyLight from Quality.forward_plus().
global uniform float sky_linear;
// What a surface's own light (EMISSION, through matter_light) is multiplied by:
// 1 on Forward+, and CompatTrim's `emission` on Compatibility, whose pass for a
// casting sun lights a surface's emission a second time (measured: `perf
// sunpath`, src/render/degrade/render_probe.gd). SkyLight writes it every frame.
global uniform float sky_emission;
// How much LID is over this place: 0 under the open sky, 1 with something
// between it and the sun at every hour (`BiomeDef.sky_shut`, blended across an
// ecotone by `SkyLight.sky_shut_at`, written every frame beside the other sky_*
// globals by their only writer). It is 0 in every landscape that has not asked
// for one, so nothing reading it can move another landscape's evening by a
// pixel. It is what lets a shader tell "the SKY is dark" from "the STREET is
// dark", which used to be the same sentence.
global uniform float sky_lid;

// --- Ink & Neon (docs/LOOK.md, docs/VISION.md section 8) ---------------------
// The grade every lit wash passes through last: x darkness 0..1, y desaturation
// 0..1, z cool shift 0..1, w contrast (crushes the mids). Written by SkyLight
// from the hour and the landscapes in view. Emission never passes through it,
// so neon, embers and working parts stay bright against the dark.
global uniform vec4 neon_grade;
// x: how wet the land lies without rain (a rain-slicked world), y: sheen,
// z: reflection strength, w: spare. Rain adds on top (sky_settle.z).
global uniform vec4 neon_wet;
// The colour of each pool in sky_lamps / sky_lamps2, one per column (rgb, w =
// the light's height above the ground it lights), for coloured pools and for
// the streaks their light leaves on wet ground.
global uniform mat4 neon_lamp_rgb;
global uniform mat4 neon_lamp_rgb2;
const vec3 NEON_COOL = vec3(0.80, 0.90, 1.10);

const vec3 SKY_PAGE = vec3(0.910, 0.863, 0.753);      // LINEN[5]: the page itself
const vec3 SKY_CLOUD_SHADE = vec3(0.88, 0.90, 0.97);
// A leg's shade: the direct sun gone and the sky's blue left. Deep, because
// a leg is solid: at a cloud's half step the band crossing the land reads as
// the light dimming, not as something standing in the sun.
const vec3 COLOSSUS_SHADE = vec3(0.30, 0.33, 0.45);
const vec3 SKY_SNOW = vec3(0.90, 0.93, 0.95);         // lying snow: page, a little cold
const vec3 SKY_ASH = vec3(0.231, 0.251, 0.290);       // ASH[1]: specks of fallen ash
const vec3 SKY_PUDDLE = vec3(0.365, 0.545, 0.627);    // RIME[3]: sky in standing water
const vec3 SKY_HAZE = vec3(0.60, 0.40, 0.28);         // furnace haze: ash lit rust from below
// The page gone cold white: paler than lying snow, or a whiteout on the
// snowfield would be the snowfield (the one land it happens in).
const vec3 SKY_WHITEOUT = vec3(0.96, 0.97, 1.0);
const vec3 SKY_AFTERGLOW = vec3(0.78, 0.87, 1.0);    // lightning's light held in cloud
// A whiteout keeps the land readable this far round the focus (tiles), and has
// taken all of it by SKY_WHITEOUT_FAR.
const float SKY_WHITEOUT_NEAR = 3.5;
const float SKY_WHITEOUT_FAR = 13.0;
const vec3 SKY_NIGHT_INK = vec3(0.16, 0.20, 0.42);    // what ink turns to under the moon
// WAS: SKY_NIGHT_FLOOR and SKY_NIGHT_KNEE, a deep blue floor lifted UNDER every
// wash at night so the renderer's light could not crush it to nothing. That was
// the single biggest reason night was not dark: it put light into a frame no
// light was falling on, and it put it into the albedo, where nothing could take
// it out again. LANTERN law 3 wants a night that is genuinely dark and still
// shaped, and the honest way to get one is AMBIENT light from a real sky
// (SkyLight.NIGHT_SKY) plus moonlight, both of which a lamp can then beat.
// THE CEILING. There used to be a shoulder here (SKY_TOP_KNEE, SKY_TOP): the
// grade was a per-frame GAIN with no ceiling, so a pale landscape seen from a
// dark one was multiplied onto the page and clipped to flat white, which holds
// no wash, no shade band and no ink. Clipping is still a failure; it has simply
// stopped being about paper.
//
// What replaces it is the TONEMAPPER. The frame is rendered in HDR and rolled
// off by Environment.tonemap_mode (SkyLight.TONEMAP), which is the honest place
// for a ceiling: it is one curve for the whole image, it cannot be defeated by
// a second landscape in frame, and it takes a highlight that is four times over
// white and gives back a highlight instead of a hole. A machine's own light is
// meant to burn and is rolled off rather than clipped, which is what makes a
// strip read as bright rather than as a white rectangle.
//
// tests/render/test_page_ceiling.gd pinned the old shoulder's arithmetic;
// tests/render/test_ceiling.gd now measures the frames themselves.
const float SKY_GROUND_HEIGHT = 16.0;                 // SkyGround.HEIGHT_RANGE

// The GRAIN cell a world point falls in. The camera never rotates (yaw 45,
// pitch 57), so projecting on its two axes gives a stable 2D field pinned to the
// world. The divisor used to be the LIVE texel (sky_view.x), which made this a
// screen pixel: every pattern built on it swam when the camera zoomed and got
// three times finer the moment the floor rose from 360 rows to 1080, so none of
// it belonged to the place it was drawn on. It is a constant now -- the world a
// pixel covers at the base's own 1080 rows -- so a speck of grit is the same
// speck of grit at any tier, at any zoom, and on the web.
//
// This is PIGMENT only. A material's own RELIEF, which is the thing the light
// finds, is measured in world units and does not come through here at all
// (matter_height); so the pebbles on a beach are pebble-sized however fine the
// grit on them is drawn.
const float SKY_GRAIN = 15.0 / 1080.0;
vec2 sky_px(vec3 world_pos) {
	return floor(vec2(dot(world_pos, vec3(0.7071, 0.0, -0.7071)), dot(world_pos, vec3(-0.5931, 0.5446, -0.5931))) / SKY_GRAIN);
}

// Hash without sine (Hoskins): stable in highp, no texture needed.
float sky_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// A stable per-pixel threshold 0..1: a soft edge becomes stipple, the way the
// ink's own ragged edges do. (Never an ordered dither: that reads as a screen.)
float sky_dither(vec2 px) {
	return sky_hash(px + vec2(113.0, 57.0));
}

float sky_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = sky_hash(i);
	float b = sky_hash(i + vec2(1.0, 0.0));
	float c = sky_hash(i + vec2(0.0, 1.0));
	float d = sky_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Three octaves, rotated between octaves so no lattice lines show.
float sky_fbm(vec2 p) {
	float v = 0.5 * sky_noise(p);
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
	v += 0.3 * sky_noise(p);
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
	v += 0.2 * sky_noise(p);
	return v;
}

// How far a lamp, a window or a stolen tube is burning, given the mean of the
// light it stands under. It was a function of the sky alone -- a tube lights
// when the light goes -- which is right under an open sky and wrong under a
// lid. Measured in the Slums, whose light_tint is (1.0, 0.88, 0.72): the mean
// at noon is 0.86, so the old expression gave 0.24, and a street made dark at
// noon had every sign in it burning at a QUARTER. That reads as a city whose
// advertising is guttering, which is the exact opposite of the one thing that
// landscape is about -- it functions, and advertising does not sleep. Dead
// would have been a better failure than dying.
//
// The lid is a FLOOR and never a replacement, so a landscape under an open sky
// is untouched to the pixel: sky_lid is 0 for all but one of them.
//
// Not solved by darkening sky_tint, and this is the case that tests the rule:
// sky_tint is hue TIMES level and this gate reads its mean, so dimming it to
// switch the signs on would also swing the sun's hue, the shade's hue and the
// divisor 15_lights.compensate subtracts -- which is the exact chain that gave
// the caves a red lantern. Hue and level stay separate.
//
// `neon_burn` itself lives further down, beside the other neon functions.


float sky_power() {
	return clamp(sky_bolt.w, 0.0, 1.0);
}

// How little light there is, whatever the cause: night, dusk, or a storm's dark
// sky at eight in the morning. 0 in full day, 1 in the dead of night. Everything
// that only belongs to the dark is multiplied by this one term: lamp pools, the
// neon halo, the lights mirrored in wet ground, the skyglow. Nothing artificial
// may show on a landscape the sun is still lighting (docs/LOOK.md section 6).
float sky_gloom() {
	float lum = dot(sky_tint, vec3(0.3, 0.59, 0.11)) * clamp(sky_sun.z, 0.0, 1.0);
	return clamp(max(sky_view.y, max(sky_shade.w, 1.0 - clamp(lum * 1.25, 0.0, 1.0))), 0.0, 1.0);
}

// 0..1 under a cloud: 1 in its shadow, a narrow band at its edge (strength is
// NOT folded in; see sky_clouds.w). Patches are a few tiles across, a handful
// on screen at a time, so light and shade walk over the land together. Two
// layers drift at different rates, so a cloud changes shape as it passes.
// The cloud field's raw value at a place (mean 0.5, spread about 0.11).
float sky_cloud_noise(vec3 world_pos) {
	vec2 q = world_pos.xz + sky_sun.xy * world_pos.y;
	float n = sky_fbm((q - sky_clouds.xy) * 0.12) * 0.7 + sky_noise((q - sky_clouds.xy * 0.8) * 0.33 + vec2(17.0, 3.0)) * 0.3;
	// A fine wobble so the edge is laid by hand, then a band of stipple only a
	// few pixels deep: soft, but still a shape.
	return n + (sky_noise(q * 1.1 + vec2(3.0, 11.0)) - 0.5) * 0.03;
}

float sky_cloud_field(vec3 world_pos) {
	float n = sky_cloud_noise(world_pos);
	// Cover is the share of the land in shade: n's quantiles, fitted (mean 0.5,
	// spread 0.11), with the ends pushed out so 0 is none and 1 is all.
	float c = sky_clouds.z;
	float t = 0.5 - 0.32 * (c - 0.5) - smoothstep(0.85, 1.0, c) * 0.3 + (1.0 - smoothstep(0.0, 0.1, c)) * 0.3;
	return smoothstep(t - 0.008, t + 0.008, n);
}

// A shadow far too big for the shadow map, the way a cloud's is: the ray from
// here to the sun, against one leg as a capsule. The penumbra widens with how
// far along the ray the leg is (the sun is a disc, a third of a degree wide
// here as in the sky), so a shin's shadow is sharp at its foot and soft a
// hundred kilometres out. 1 in the umbra.
const float COLOSSUS_PENUMBRA = 0.006;
float colossus_capsule(vec3 p, vec3 l, vec3 a, vec3 b, float ra, float rb) {
	vec3 ab = b - a;
	vec3 ap = p - a;
	float d1 = dot(l, ab);
	float d2 = dot(ab, ab);
	float d3 = dot(l, ap);
	float d4 = dot(ab, ap);
	float den = d2 - d1 * d1;
	// Closest points between the ray p + t l and the segment a + s ab.
	float sp = den > 1e-6 ? clamp((d4 - d1 * d3) / den, 0.0, 1.0) : 0.0;
	vec3 q = a + ab * sp;
	// Tapered: the leg is as thick here as its own profile says.
	float r = mix(ra, rb, sp);
	float t = max(dot(q - p, l), 0.0);
	float dist = length(p + l * t - q);
	float pen = max(t * COLOSSUS_PENUMBRA, 1.0);
	return 1.0 - smoothstep(r - pen, r + pen, dist);
}

float colossus_in(mat4 m, int first, int n, vec3 p, vec3 l) {
	float s = 0.0;
	if (first < n) {
		s = max(s, colossus_capsule(p, l, m[0].xyz, m[1].xyz, m[0].w, m[1].w));
	}
	if (first + 1 < n) {
		s = max(s, colossus_capsule(p, l, m[2].xyz, m[3].xyz, m[2].w, m[3].w));
	}
	return s;
}

// How far, and which way, the shock of a landing pushes something that sways at
// `wp`, in metres at full sway: out from the tread as the front passes, a
// smaller swing back behind it, less the further out it has run.
const float SHOCK_FRONT = 22.0;
const float SHOCK_REACH = 900.0;
// Metres a crown's tip goes over at full sway weight and full shock.
const float SHOCK_BEND = 1.4;
vec3 sky_shock(vec3 wp) {
	if (colossus_shock.w <= 0.0) {
		return vec3(0.0);
	}
	vec2 d = wp.xz - colossus_shock.xy;
	float r = length(d);
	float x = r - colossus_shock.z;
	float band = exp(-x * x / (2.0 * SHOCK_FRONT * SHOCK_FRONT))
		- 0.35 * exp(-(x + 45.0) * (x + 45.0) / (2.0 * 30.0 * 30.0));
	float fall = clamp(1.0 - r / SHOCK_REACH, 0.0, 1.0);
	return vec3(d.x, 0.0, d.y) / max(r, 1.0) * band * fall * colossus_shock.w;
}

// 0..1: how much of the sun a colossus's leg takes off this place.
float sky_colossus(vec3 world_pos) {
	int n = int(colossus_sun.w + 0.5);
	if (n <= 0) {
		return 0.0;
	}
	vec3 l = colossus_sun.xyz;
	float s = colossus_in(colossus_legs0, 0, n, world_pos, l);
	s = max(s, colossus_in(colossus_legs1, 2, n, world_pos, l));
	s = max(s, colossus_in(colossus_legs2, 4, n, world_pos, l));
	s = max(s, colossus_in(colossus_legs3, 6, n, world_pos, l));
	return s;
}

float sky_cloud(vec3 world_pos) {
	if (sky_clouds.w < 0.001) {
		return 0.0;
	}
	return sky_cloud_field(world_pos);
}

// The afterglow of a strike: the clouds it lit, catching and letting go as the
// light rolls out from where it struck. 0/1 per pixel. Drawn as light IN the
// cloud, not a bank on the ground: the lit edges of the cloud's own shapes as
// stippled rims, and only a sparse stipple inside them, so the land always
// shows through.
const float SKY_GLOW_RIM = 0.02;
float sky_afterglow(vec3 world_pos, float d) {
	if (sky_bolt.z < 0.001) {
		return 0.0;
	}
	float reach = sky_view.w;
	float dist = length(world_pos.xz - sky_bolt.xy);
	if (dist > reach + 4.0) {
		return 0.0;
	}
	// The rolling front lights more of the cloud than what it has passed.
	float front = smoothstep(reach - 18.0, reach - 2.0, dist);
	// A brighter flicker lights more of the field.
	float t = mix(0.7, 0.5, clamp(sky_bolt.z, 0.0, 1.0)) - 0.06 * front + 0.08 * smoothstep(reach - 2.0, reach + 4.0, dist);
	float n = sky_cloud_noise(world_pos);
	if (n < t) {
		return 0.0;
	}
	// Only the edges that face the strike catch its light: a step toward the
	// strike leaves the cloud there. The light thins as it goes into the cloud,
	// in stipple, so an edge is a lit fringe and never a ruled ring.
	vec2 toward = normalize(sky_bolt.xy - world_pos.xz + vec2(0.001));
	float facing = step(sky_cloud_noise(world_pos + vec3(toward.x, 0.0, toward.y) * 0.7), t + SKY_GLOW_RIM * 0.5);
	float depth = smoothstep(t, t + SKY_GLOW_RIM * 3.0, n);
	float dots = facing * 0.32 * (1.0 - depth) + 0.022;
	return step(d, dots * clamp(sky_bolt.z * 1.6, 0.0, 1.0));
}

// How much of a place a whiteout has taken, 0..1: nothing round the focus,
// closing in over the distance. Smooth; callers cut it into steps.
float sky_whiteout_at(vec3 world_pos) {
	if (sky_air.w < 0.001) {
		return 0.0;
	}
	float dist = length(world_pos.xz - sky_focus.xz);
	return sky_air.w * smoothstep(SKY_WHITEOUT_NEAR, SKY_WHITEOUT_FAR, dist);
}

vec4 sky_ground_at(vec3 world_pos) {
	return texture(sky_ground, world_pos.xz * sky_view.z);
}

// Fog at a place, as whole steps: 0 clear, 0.55 a thin bank, 1 a thick one.
// Banks are a few tiles across and drift with the wind. They lie in hollows
// and over water and thin over rises; anything standing (a roof, a crown)
// rises out of them. Their edges tear into long level wisps, the way a dry
// brush drags. Density moves the edges, never the value inside, and even the
// thickest fog leaves ground showing between its banks: never a veil.
float sky_fog_at(vec3 world_pos, vec2 px, float band) {
	if (sky_fog.z < 0.001) {
		return 0.0;
	}
	// Furnace haze lies lower and heavier in the hollows than a pale mist.
	float low = sky_air.z * 0.08;
	vec2 p = world_pos.xz - sky_fog.xy;
	float n = sky_fbm(p * vec2(0.17, 0.13) + vec2(41.0, 7.0)) * 0.8 + sky_noise(p * 0.45 + vec2(9.0, 2.0)) * 0.2;
	float hollow = sky_ground_at(world_pos).a * SKY_GROUND_HEIGHT - world_pos.y;
	n += clamp(hollow, -1.5, 1.0) * (0.14 + low) + (1.0 - step(0.36, world_pos.y)) * 0.06;
	n += (sky_noise(vec2(px.x * 0.025, px.y * 0.22) + p * 0.02) - 0.5) * 0.07;
	float t1 = mix(0.7, 0.585, sky_fog.z);
	float t2 = t1 + 0.1;
	float h = sky_hash(px + vec2(61.0, 17.0));
	return step(h, smoothstep(t1 - band, t1 + band, n)) * 0.55 + step(h, smoothstep(t2 - band, t2 + band, n)) * 0.45;
}

// Distance attenuation of an OmniLight3D with omni_attenuation = 0, as the
// renderer computes it, so the ink agrees with the light about the pool.
float sky_omni(vec3 world_pos, vec4 lamp) {
	if (lamp.w <= 0.0) {
		return 0.0;
	}
	float nd = length(world_pos - lamp.xyz) / lamp.w;
	nd = nd * nd;
	nd = max(1.0 - nd * nd, 0.0);
	return nd * nd;
}

// Lamplight lies on the ground and on walls below the light, never across a
// roof: a pool cut into steps on a slope reads as a ruled arc. up: the face's
// normal y in world space; ly: the world y of the direction toward the light.
float sky_lamp_gate(float up, float ly) {
	if (up >= 0.9) {
		return step(0.06, ly);
	}
	if (abs(up) < 0.3) {
		return step(0.0, ly);
	}
	// A slope takes lamplight only when the light is well above it.
	return step(0.6, ly);
}

float sky_lamp_level(vec3 world_pos, float up) {
	float a = 0.0;
	for (int i = 0; i < 4; i++) {
		a = max(a, sky_omni(world_pos, sky_lamps[i]) * sky_lamp_gate(up, normalize(sky_lamps[i].xyz - world_pos + vec3(0.0, 0.001, 0.0)).y));
		a = max(a, sky_omni(world_pos, sky_lamps2[i]) * sky_lamp_gate(up, normalize(sky_lamps2[i].xyz - world_pos + vec3(0.0, 0.001, 0.0)).y));
	}
	return a;
}

// The colour of the strongest pool at a place (rgb), and that pool's level (a).
vec4 sky_lamp_colour(vec3 world_pos, float up) {
	vec4 best = vec4(SKY_PAGE, 0.0);
	for (int i = 0; i < 4; i++) {
		float a = sky_omni(world_pos, sky_lamps[i]) * sky_lamp_gate(up, normalize(sky_lamps[i].xyz - world_pos + vec3(0.0, 0.001, 0.0)).y);
		if (a > best.a) {
			best = vec4(neon_lamp_rgb[i].rgb, a);
		}
		float b = sky_omni(world_pos, sky_lamps2[i]) * sky_lamp_gate(up, normalize(sky_lamps2[i].xyz - world_pos + vec3(0.0, 0.001, 0.0)).y);
		if (b > best.a) {
			best = vec4(neon_lamp_rgb2[i].rgb, b);
		}
	}
	if (dot(best.rgb, vec3(1.0)) < 0.01) {
		best.rgb = SKY_PAGE;
	}
	return best;
}

// Where the attenuation crosses into the bright core and into the dim ring.
const float SKY_POOL_CORE = 0.66;
const float SKY_POOL_RING = 0.32;
// How far the core of a pool carries the light's own colour into the wash, how
// far that wash is tilted to the light's own hue, and how much brighter the lit
// ground is. Kept low: a pool is a tint and a step, never a disc of paint.
const float SKY_POOL_WASH = 0.3;
const float SKY_POOL_TILT = 0.8;
const float SKY_POOL_LIFT = 1.6;

// WAS: a pool of lamplight cut into two hard steps with a stippled rim, so a
// lamp read as a wash laid by hand. Now the renderer's own attenuation is the
// pool, and it falls off the way light does. Kept as the identity so the
// shaders that still call it keep compiling and keep meaning the same thing.
float sky_pool(float a, vec3 world_pos) {
	return clamp(a, 0.0, 1.0);
}

// The wash inside a pool: the LIGHT's own colour laid over the ground, warm for
// a lamp or a fire and cold for a machine's strip (docs/LOOK.md section 6).
//
// It is a GAIN and nothing else: `c` is multiplied, never lifted toward a level
// the light chooses. That is the whole rule. Light falling on things multiplies
// them, so every surface in the pool keeps its ratio to its neighbours — a
// charred log stays six times darker than the turf beside it, and the player's
// coat, trousers and boots stay three colours inside their own lantern's light.
// Anything that averages toward a common value flattens the page under the pool
// into one bright disc, which is what a lamp must never be.
//
// `pool` is sky_pool's two flat steps, so the wash has two values and no
// gradient; sky_gloom() takes it to nothing before the sun is up.
vec3 sky_lamp_wash(vec3 c, vec3 lamp_rgb, float pool) {
	if (pool <= 0.0) {
		return c;
	}
	float ll = dot(lamp_rgb, vec3(0.3, 0.59, 0.11));
	if (ll < 0.001) {
		return c;
	}
	// The light's hue at unit brightness, so a dim lamp and a bright one tilt
	// the ground the same way and only the pool's own steps say how far.
	vec3 hue = lamp_rgb / ll;
	vec3 gain = mix(vec3(1.0), hue, SKY_POOL_TILT) * SKY_POOL_LIFT;
	return mix(c, c * gain, pool * SKY_POOL_WASH * sky_gloom());
}

// WAS: where the sky laid hatching on a lit face (cloud shadow, night) and
// where it lifted it (lamplight, fog, a flash). There is no hatching. A cloud's
// shade is a shade now, and night is dark because there is less light in it.
vec3 sky_ink(vec3 world_pos, float up) {
	return vec3(0.0);
}

// Outline ink under this sky: near-black by day, deep blue ink under the moon.
vec3 sky_line(vec3 ink) {
	return mix(ink, SKY_NIGHT_INK * max(sky_tint.b, 0.4), sky_view.y * 0.7);
}

// How wide the edge of a wet patch is drawn, in the lay's own units: wide
// enough that the stipple between wet and dry runs a tile or two, so wet ground
// is drawn into the land and never a mask cut out of it.
const float SKY_WET_FEATHER = 0.13;

// How far the wet has spread at a place, 0..1 (callers cut it into stipple with
// a per-pixel threshold). One LAY of patches for every caller, so the darkening
// and the slick pick out the same hollows; how far each spreads over that lay
// is its own `w`, since rain that has settled and a land that never dries are
// not the same wetness (sky_settled takes the first, the slick takes both).
float sky_wet_cover(vec3 world_pos, float w) {
	if (w <= 0.001) {
		return 0.0;
	}
	float lay = sky_fbm(world_pos.xz * 0.3 + vec2(71.0, 5.0));
	return smoothstep(-SKY_WET_FEATHER, SKY_WET_FEATHER, 1.5 * w + 0.6 * lay - 0.55);
}

// Snow, ash and wet left on the land. Flat faces take it first, and it lies in
// patches that join up as it deepens, with a stippled rim. Faces are found from
// screen derivatives of the world position (every face here is flat). Water and
// the sea floor sit below 0.36 and are left alone. FOUND shaders define
// SKY_FOUND before the include, and nothing lies on them.
vec3 sky_settled(vec3 c, vec3 albedo, vec3 world_pos, vec2 px) {
	if (sky_settle.x + sky_settle.y + sky_settle.z < 0.002 || world_pos.y < 0.36) {
		return c;
	}
	// Each thing lies only on the countries that make it (SkyGround), thinning
	// out across an ecotone.
	vec4 ground = sky_ground_at(world_pos);
	vec3 settle = sky_settle.xyz * ground.rgb;
	vec3 n = normalize(cross(dFdx(world_pos), dFdy(world_pos)));
	float up = abs(n.y);
	if (up < 0.45) {
		return c;
	}
	float h = sky_hash(px + vec2(7.0, 61.0));
	// Flat ground holds broad drifts; a slope (a roof, a pine's tier) holds
	// only a dapple of flecks, so what is under it still shows.
	float flat_face = step(0.93, up);
	float broad = sky_fbm(world_pos.xz * 0.45 + vec2(13.0, 29.0)) * 0.8 + sky_noise(world_pos.xz * 2.1) * 0.2;
	float lay = mix(0.35 + (up - 0.45) * 0.4, broad, flat_face);
	if (settle.z > 0.001) {
		// Wet ground darkens a step in patches that spread as it rains and
		// shrink as it dries; standing water shows the sky in the flat hollows.
		float w = settle.z;
		float dark = sky_wet_cover(world_pos, w);
		c *= mix(vec3(1.0), vec3(0.87, 0.89, 0.94), step(h, dark));
		float puddle_lay = sky_noise(world_pos.xz * 1.3 + vec2(11.0, 47.0)) * 0.6 + broad * 0.4;
		float pool = smoothstep(0.0, 0.02, puddle_lay - 0.86 + (w - 0.5) * 0.12) * flat_face * step(0.5, w);
		c = mix(c, SKY_PUDDLE, step(h, pool) * 0.45);
		if (sky_air.x > 0.02 && pool > 0.5) {
			// Rain on standing water: rings spreading and gone, one to a small
			// cell, each on its own beat, more of them the harder it falls.
			vec2 cell = floor(world_pos.xz / 0.42);
			float ph = sky_hash(cell + vec2(3.0, 91.0));
			float beat = TIME * 1.7 + ph * 9.0;
			float age = fract(beat);
			vec2 centre = (cell + 0.25 + 0.5 * vec2(sky_hash(cell + floor(beat)), sky_hash(cell.yx + floor(beat) + 7.0))) * 0.42;
			vec2 dv = (world_pos.xz - centre) / max(sky_view.x, 0.001);
			float rad = 1.0 + age * 5.0;
			float ring = step(abs(length(vec2(dv.x, dv.y * 1.2)) - rad), 0.55) * step(age, 0.8);
			ring *= step(sky_hash(cell + floor(beat) + vec2(17.0, 5.0)), sky_air.x * 0.8);
			c = mix(c, min(SKY_PUDDLE * 1.35, vec3(1.0)), ring * 0.7);
		}
	}
	if (settle.y > 0.001) {
		float a = settle.y;
		// Specks, gathering thicker where it drifts, never a flat grey bed.
		float drift = sky_noise(world_pos.xz * 0.6 + vec2(5.0, 23.0));
		c = mix(c, SKY_ASH, step(h, a * (0.03 + 0.06 * drift)));
	}
	if (settle.x > 0.001) {
		float s = settle.x;
		float lie = smoothstep(0.0, 0.025, lay - 1.0 + s * 0.75);
		// Flecks outrun the drift, so snow arrives as paper showing through.
		float fleck = step(h, s * 0.12) * step(0.5, sky_hash(px * 0.5 + vec2(3.0, 1.0)));
		c = mix(c, SKY_SNOW, max(step(h, lie), fleck));
	}
	return c;
}

// WAS: the dystopian grade -- darker, cooler, less colour, harder mids, on a
// per-fragment shoulder. Grading a lit world per fragment fights the light: it
// is applied before anything knows how bright the frame turned out, so the same
// multiply crushes a dark interior and does nothing to a noon field. The grade
// is now one knob on the Environment (SkyLight: adjustment brightness, contrast
// and saturation, plus the tonemapper), set once a frame from the hour and the
// landscapes in view -- the same inputs, in the one place that can see the
// whole image. Kept as the identity while the callers are converted.
vec3 neon_graded(vec3 c, float found) {
	return c;
}

// HOW FAR A NEON-CODED FACE IS BURNING, 0..1.
//
// It was `clamp((0.9 - mean(sky_tint)) * 6.0, 0, 1)` written out at each of the
// two call sites in world.gdshader — a stolen tube lights when the light goes.
// That is right under an open sky and wrong under one that is SHUT, because it
// asks whether the SKY is dark when what decides an advertisement is whether the
// STREET is. Measured on the slums at noon, `sky_tint` means 0.86 and the old
// expression answered 0.24: every sign in a street drawn dark at midday burning
// at a quarter, which reads as a city guttering out. That is the exact opposite
// of what that landscape is for — the horror there is that it FUNCTIONS.
//
// The lid is a FLOOR and never a replacement, so no other landscape moves by a
// pixel: `sky_lid` is 0 everywhere that has not asked for one, and the tint term
// still owns every evening in the game.
//
// It is a function rather than a third copy of the expression because the number
// belongs where it is DRAWN and the caller should ask (docs/LOOK.md): the two
// call sites had already drifted into two spellings of one rule.
float neon_burn(float tint_mean) {
	return max(clamp((0.9 - tint_mean) * 6.0, 0.0, 1.0), sky_lid);
}

// How wet the ground lies here, 0..1: the rain-slicked default plus rain, only
// where the land can hold water (sky_ground.b) and never on water itself.
float neon_wetness(vec3 world_pos) {
	if (world_pos.y < 0.36) {
		return 0.0;
	}
	float can = sky_ground_at(world_pos).b;
	return clamp(max(neon_wet.x, sky_settle.z) * can, 0.0, 1.0);
}

// One glint's streak on wet ground. lamp: xyz the light, w its level 0..1.
float neon_streak(vec3 world_pos, vec2 px, vec4 lamp, float up_px) {
	if (lamp.w <= 0.0) {
		return 0.0;
	}
	float reach = 2.5 + 2.5 * lamp.w;
	if (abs(world_pos.x - lamp.x) > reach * 1.7 || abs(world_pos.z - lamp.z) > reach * 1.7) {
		return 0.0;
	}
	// The light, and the point on this ground right under it, in screen pixels:
	// its reflection hangs below that point as far as the light stands above it.
	vec2 lp = sky_px(lamp.xyz);
	vec2 gp = sky_px(vec3(lamp.x, world_pos.y, lamp.z));
	float dy = gp.y - px.y;
	float len = max(lp.y - gp.y, 4.0) * 1.8 + 10.0;
	if (dy < 0.0 || dy > len) {
		return 0.0;
	}
	float dx = abs(px.x - gp.x);
	float width = 1.5 + 3.0 * (1.0 - dy / len);
	if (dx > width) {
		return 0.0;
	}
	// Broken into short dashes that the rain shivers, fading down the streak;
	// on still wet ground the dashes hold.
	float dash = step(sky_hash(vec2(floor(px.y / 2.0), floor(TIME * (0.7 + 7.0 * sky_air.x)) + gp.x)), 0.72);
	float near = 1.0 - clamp(length(world_pos.xz - lamp.xz) / (reach * 1.6), 0.0, 1.0);
	return dash * near * (1.0 - dy / len) * (1.0 - dx / (width + 1.0)) * up_px * lamp.w;
}

// Emission for wet flat ground: the glint list's colours (lamps, fires, machine
// beacons and strips, stolen neon) mirrored as broken vertical streaks. By day
// they are faint; in dusk, storm and night they carry. Call from fragment() and
// ADD to EMISSION.
vec3 neon_reflect(vec3 world_pos, vec2 px) {
	float wet = neon_wetness(world_pos);
	if (wet < 0.05 || neon_wet.z <= 0.0) {
		return vec3(0.0);
	}
	float up = abs(normalize(cross(dFdx(world_pos), dFdy(world_pos))).y);
	if (up < 0.9) {
		return vec3(0.0);
	}
	vec3 e = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		e += glint_rgb[i].rgb * neon_streak(world_pos, px, sky_glints[i], 1.0);
		e += glint_rgb2[i].rgb * neon_streak(world_pos, px, sky_glints2[i], 1.0);
		e += glint_rgb3[i].rgb * neon_streak(world_pos, px, sky_glints3[i], 1.0);
	}
	return e * wet * neon_wet.z * 2.6 * (0.2 + 0.8 * sky_gloom());
}

// WAS: skyglow, emitted onto every surface so a wash in the dark still read as
// a shape. Emission on everything is the definition of a flat picture -- it is
// light that comes from nowhere, casts nothing and can be hidden by nothing.
// The low cloud over a ruin that keeps its lights on is now what it always was:
// the colour and level of the AMBIENT light (SkyLight.NIGHT_SKY, and the
// Environment's own sky), which a roof can block and a lamp can beat.
vec3 neon_skyglow(vec3 graded) {
	return vec3(0.0);
}

vec3 sky_apply(vec3 albedo, vec3 world_pos, float time) {
	vec2 px = sky_px(world_pos);
	float d = sky_dither(px);
#ifdef SKY_FOUND
	// Nothing lies on the FOUND: it is powered, warm and kept, and must always
	// read as a machine.
	vec3 c = albedo;
#else
	vec3 c = sky_settled(albedo, albedo, world_pos, px);
#endif
	// The hour's own colour is NOT applied here any more. It is the colour of
	// the sun and of the sky (SkyLight), so a face turned away from the light
	// takes the sky's blue and a face turned to it takes the evening's warmth,
	// which one multiply over the whole surface could never do. This function
	// now only says what the AIR and the WEATHER have done.
	float face_up = abs(normalize(cross(dFdx(world_pos), dFdy(world_pos))).y);
#ifndef SKY_FOUND
	// Rain-slicked: wet ground goes a step DARKER, which is what wet ground
	// really does. It used to be given a pale sheen as well, to stand in for a
	// reflection nothing was computing; the reflection is real now (ROUGHNESS
	// falls where it is wet, and the sky and the lamps are in it), so the sheen
	// is gone and only the darkening is left.
	// How much it darkens depends on how much light there is to be absorbed.
	// Wet ground looks dark by DAY because it swallows the light falling on it;
	// at night there is nothing to swallow and what you see in it is reflected,
	// so a full daylight darkening laid on a wet bog at midnight took the moss
	// frames to 86% of the picture under luma 24, which is a black screen with
	// a green dot in it -- the exact thing LOOK.md law 3 is guarding against.
	float wet = neon_wetness(world_pos) * step(0.9, face_up);
	vec3 soak = mix(vec3(0.78, 0.81, 0.87), vec3(0.66, 0.70, 0.78), 1.0 - sky_gloom());
	c = mix(c, c * soak, step(sky_hash(px + vec2(7.0, 61.0)), sky_wet_cover(world_pos, wet)));
#endif
	float cloud = sky_cloud(world_pos);
	if (cloud > 0.0) {
		// A cloud over the sun. Nothing in the engine casts these, so it is a
		// shade on the surface: soft-edged now rather than stippled, because
		// under a real sun a hard-edged cloud shadow reads as paint.
		c *= mix(vec3(1.0), SKY_CLOUD_SHADE, clamp(cloud, 0.0, 1.0) * sky_clouds.w * 0.75);
	}
	// A colossus's leg between this place and the sun: a band of real shade,
	// deeper than a cloud's, because a leg is solid, and only as deep as the
	// sun is strong (nothing to take at night).
	float legs = sky_colossus(world_pos);
	if (legs > 0.0) {
		c *= mix(vec3(1.0), COLOSSUS_SHADE, legs * clamp(sky_sun.z, 0.0, 1.0));
	}
	// Banks of fog and haze lying ON the land, which the Environment's own
	// depth fog cannot do: they sit in the hollows, drift on the wind and leave
	// ground showing between them.
	float fog = sky_fog_at(world_pos, px, max(fwidth(world_pos.x) + fwidth(world_pos.z), 0.01) * 0.12);
	vec3 fog_col = mix(SKY_PAGE, SKY_HAZE * vec3(1.0, 0.7, 0.45), sky_air.z);
	vec3 white = SKY_WHITEOUT;
	fog_col = mix(fog_col, white, sky_air.w);
	if (fog > 0.0) {
		c = mix(c, fog_col, fog * (0.34 + 0.12 * sky_air.z));
	}
	if (sky_air.w > 0.001) {
		// A whiteout: the land round the player still reads and the distance
		// goes, in gusts that blow past on the wind, so its edge wanders over
		// the land like weather and never sits as a ring round the player.
		float gust = sky_noise((world_pos.xz - sky_wind.xy * time * 1.6) * 0.16 + vec2(5.0, 17.0));
		float veil = clamp(sky_whiteout_at(world_pos) + (gust - 0.35) * 0.45 * sky_air.w, 0.0, 1.0);
		c = mix(c, white, max(veil, 0.12 * sky_air.w));
	}
	if (sky_air.y > 0.001) {
		// Glare: hard white light bleaches a surface toward a lifted grey.
		float gl = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(gl) * vec3(1.04, 1.03, 0.99) + (1.0 - vec3(gl)) * 0.17, sky_air.y * 0.5);
	}
	if (sky_bolt.z > 0.001) {
		// The strike's afterglow rolling through the cloud, and the land under
		// it lifting while the light lasts.
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, SKY_AFTERGLOW, sky_afterglow(world_pos, d) * (0.38 - 0.2 * lum));
		float away = length(world_pos.xz - sky_bolt.xy);
		float lifted = clamp(sky_bolt.z, 0.0, 1.0) * (1.0 - smoothstep(sky_view.w * 0.2, sky_view.w + 4.0, away));
		c = mix(c, min(c * vec3(1.10, 1.14, 1.22), vec3(1.0)), lifted * 0.7);
	}
	return c;
}

#endif
