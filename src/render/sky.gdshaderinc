// The sky over the notebook (docs/ART.md section 6). Owned by the sky package.
// Included by every lit shader (world, found, water) and by the weather marks.
// It is the ONLY place lit colour is tinted by time, weather or region:
//
//   sky_apply(albedo, world_pos, TIME)   in fragment(): the wash under this sky
//   sky_ink(world_pos, up)               in world.gdshader light(): how the sky
//                                        lays or lifts hatching (cloud shadow and
//                                        night lay it; lamplight, fog and a
//                                        lightning flash lift it)
//   sky_pool(attenuation, world_pos)     in light() for lamps and fire: the pool
//                                        in two hard steps with a stippled rim
//   sky_line(ink)                        for outlines: ink turns blue at night
//   sky_shade.rgb                        in light(): multiply the shade colour by it
//   sky_power()                          a multiply for the machines' own light
//                                        (FOUND strips, beacons, stolen neon): 1
//                                        steady, stuttering for a beat after lightning
//   sky_gloom()                          how little light there is (0 full day, 1
//                                        dead of night): the multiply for everything
//                                        that only belongs to the dark
//   neon_reflect(world_pos, px)          emission for wet ground: the glint list
//                                        (lamps, fires, beacons, neon) mirrored
//
// Every global is written by SkyLight (src/render/sky_light.gd) and nothing else.
// Patterns here are in screen pixels pinned to the world, like the ink: nothing
// is a gradient, nothing swims.
#ifndef SKY_GDSHADERINC
#define SKY_GDSHADERINC

// Time of day x season x region x weather: the colour of the light.
global uniform vec3 sky_tint;
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

// --- Ink & Neon (docs/ART.md, docs/VISION.md section 8) ---------------------
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
const vec3 SKY_CLOUD_SHADE = vec3(0.88, 0.90, 0.97);  // a cloud's shade: half a step toward blue-violet
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
const vec3 SKY_NIGHT_FLOOR = vec3(0.08, 0.10, 0.21);  // the darkest a wash goes at night
const float SKY_NIGHT_KNEE = 0.32;
const float SKY_GROUND_HEIGHT = 8.0;                  // SkyGround.HEIGHT_RANGE

// The screen pixel a world point falls on. The camera never rotates (yaw 45,
// pitch 57) and is snapped to whole texels, so this is pinned to the world.
vec2 sky_px(vec3 world_pos) {
	float texel = max(sky_view.x, 0.001);
	return floor(vec2(dot(world_pos, vec3(0.7071, 0.0, -0.7071)), dot(world_pos, vec3(-0.5931, 0.5446, -0.5931))) / texel);
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

float sky_power() {
	return clamp(sky_bolt.w, 0.0, 1.0);
}

// How little light there is, whatever the cause: night, dusk, or a storm's dark
// sky at eight in the morning. 0 in full day, 1 in the dead of night. Everything
// that only belongs to the dark is multiplied by this one term: lamp pools, the
// neon halo, the lights mirrored in wet ground, the skyglow. Nothing artificial
// may show on a landscape the sun is still lighting (docs/ART.md section 6).
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

// A pool of lamplight in two steps: a bright core (1.0) where the page shows,
// then a dimmer ring (0.5), each edge broken into a few pixels of stipple and
// wandering with the ground, the way a wash of light is laid by hand. Never a
// smooth falloff, never a ruled circle.
float sky_pool(float a, vec3 world_pos) {
	if (a <= 0.0) {
		return 0.0;
	}
	float h = sky_hash(sky_px(world_pos) + vec2(29.0, 13.0));
	a += (sky_noise(world_pos.xz * 0.8 + vec2(3.0, 71.0)) - 0.5) * 0.2 + (sky_noise(world_pos.xz * 2.6) - 0.5) * 0.08;
	if (a >= SKY_POOL_CORE + 0.05) {
		return 1.0;
	}
	if (a >= SKY_POOL_CORE) {
		return h < (a - SKY_POOL_CORE) / 0.05 ? 1.0 : 0.5;
	}
	if (a >= SKY_POOL_RING + 0.05) {
		return 0.5;
	}
	if (a >= SKY_POOL_RING) {
		return h < (a - SKY_POOL_RING) / 0.05 * 0.8 ? 0.5 : 0.0;
	}
	return 0.0;
}

// The wash inside a pool: the LIGHT's own colour laid over the ground, warm for
// a lamp or a fire and cold for a machine's strip (docs/ART.md section 6).
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

// How the sky changes the hatching of a MADE surface, for world.gdshader
// light(). Returns x: 1 where hatching is laid on a sunlit face (a cloud's
// shadow, or night), y: 1 where hatching is lifted (lamplight, fog, a flash),
// z: how much deeper shade reads (night). All 0/1 per pixel, dithered.
// up: the surface normal's world y. Night hatches the ground, roofs and crowns;
// walls, people and faces keep their moonlit wash, so shapes read in the dark
// and hatching never crosses a face.
vec3 sky_ink(vec3 world_pos, float up) {
	vec2 px = sky_px(world_pos);
	float d = sky_dither(px);
	float night = sky_view.y;
	// A cloud's shade is lighter than cast or deep shade: its hatch is laid in
	// broken lengths, about half of them, fewer under a thin cloud. Like night,
	// it is laid only on what faces the sky, never across a wall or a face.
	float shaded = step(d, sky_cloud(world_pos) * 0.999) * step(sky_hash(floor(px / vec2(4.0, 3.0)) + vec2(5.0, 9.0)), sky_clouds.w * 0.55) * step(0.55, up);
	// Night comes on a line-length at a time, so dusk never reads as grain.
	float lay = max(step(sky_hash(floor(px / 3.0) + vec2(17.0, 2.0)), night * 0.999) * step(0.55, up), shaded);
	float deeper = night * 0.3;
	// Lamplight only erases hatching once the dark has come: by day a lit lamp
	// is a flame, and leaves no mark on the page at all.
	float pool = sky_pool(sky_lamp_level(world_pos, up), world_pos) * step(0.12, sky_gloom());
	// The core of a pool is clean page; its ring keeps half its hatching.
	float lift = max(step(0.99, pool), step(0.49, pool) * step(sky_hash(floor(px / 3.0) + vec2(23.0, 7.0)), 0.5));
	// Fog thins the hatching a line-length at a time, not pixel by pixel.
	lift = max(lift, step(sky_hash(floor(px / 3.0) + vec2(41.0, 3.0)), max(sky_fog_at(world_pos, px, 0.01) * 0.9, sky_whiteout_at(world_pos) * 1.2)));
	lift = max(lift, step(0.3, sky_sun.w));
	return vec3(lay, lift, deeper);
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
		c = mix(c, SKY_PUDDLE * sky_tint, step(h, pool) * 0.45);
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
			c = mix(c, min(SKY_PUDDLE * 1.35, vec3(1.0)) * sky_tint, ring * 0.7);
		}
	}
	if (settle.y > 0.001) {
		float a = settle.y;
		// Specks, gathering thicker where it drifts, never a flat grey bed.
		float drift = sky_noise(world_pos.xz * 0.6 + vec2(5.0, 23.0));
		c = mix(c, SKY_ASH * sky_tint, step(h, a * (0.03 + 0.06 * drift)));
	}
	if (settle.x > 0.001) {
		float s = settle.x;
		float lie = smoothstep(0.0, 0.025, lay - 1.0 + s * 0.75);
		// Flecks outrun the drift, so snow arrives as paper showing through.
		float fleck = step(h, s * 0.12) * step(0.5, sky_hash(px * 0.5 + vec2(3.0, 1.0)));
		c = mix(c, SKY_SNOW * sky_tint, max(step(h, lie), fleck));
	}
	return c;
}

// The dystopian grade: darker, cooler, less colour, harder mids. FOUND keeps a
// little more of its colour: the machines' order is the lit thing in the ruin.
vec3 neon_graded(vec3 c, float found) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c, vec3(l), neon_grade.y * (1.0 - 0.5 * found));
	g = mix(g, g * NEON_COOL, neon_grade.z);
	// Contrast as an S around the mids: lights lift a little, mids deepen, and
	// the darks are left where they are, so a dark wash never crushes to black.
	vec3 sc = clamp(g, 0.0, 1.0);
	vec3 s_curve = sc * sc * (3.0 - 2.0 * sc);
	g = mix(g, max(s_curve, sc * 0.8), neon_grade.w);
	return g * (1.0 - neon_grade.x);
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

// Skyglow: low cloud holds the light of everything the machines keep running,
// so in gloom, dusk and night a wash still reads as a shape and never goes to
// black. Emitted, because a wash multiplied by no light is black.
//
// It is the SKY'S OWN COLOUR, not one colour for every dark hour: teal-indigo
// once the night is all that lights the cloud, and the hour's own light while
// there is any sun left in it. A fixed cold glow laid a blue wash over every
// surface exactly as the sun went warm, which made the evening measure bluer the
// dimmer it got. Call from fragment() with the graded albedo and ADD to EMISSION.
const vec3 SKY_GLOW_NIGHT = vec3(0.2, 0.24, 0.3);
const vec3 SKY_GLOW_NIGHT_FLOOR = vec3(0.02, 0.034, 0.055);

// How much of the skyglow is up. It is NOT sky_gloom(): the glow adds about a
// tenth of full scale to every wash, and the light only falls by about a quarter
// across the whole evening, so a glow that came up with the dusk on a straight
// line made the frame BRIGHTER as it got darker. The night's own share is
// back-loaded (cubed) so it arrives behind the light it replaces, and a sky too
// dark for its hour — a storm at ten in the morning — keeps its lift in full,
// because that darkness is not the night coming.
float sky_glow_share() {
	float lum = dot(sky_tint, vec3(0.3, 0.59, 0.11)) * clamp(sky_sun.z, 0.0, 1.0);
	float dark_sky = clamp(1.0 - clamp(lum * 1.25, 0.0, 1.0), 0.0, 1.0);
	float night = clamp(sky_view.y, 0.0, 1.0);
	return clamp(max(dark_sky, night * night * night), 0.0, 1.0);
}

vec3 neon_skyglow(vec3 graded) {
	float tl = max(dot(sky_tint, vec3(0.3, 0.59, 0.11)), 0.001);
	vec3 hue = sky_tint / tl;
	float night = clamp(sky_view.y, 0.0, 1.0);
	vec3 lift = mix(hue * 0.245, SKY_GLOW_NIGHT, night);
	vec3 base = mix(hue * 0.036, SKY_GLOW_NIGHT_FLOOR, night);
	return (graded * lift + base) * sky_glow_share();
}

vec3 sky_apply(vec3 albedo, vec3 world_pos, float time) {
	vec2 px = sky_px(world_pos);
	float d = sky_dither(px);
#ifdef SKY_FOUND
	// Nothing lies on the FOUND: it runs warm, and must always read as a machine.
	vec3 c = albedo * sky_tint;
#else
	vec3 c = sky_settled(albedo * sky_tint, albedo, world_pos, px);
#endif
	// Night is blue ink on dim washes, never black. The renderer's linear light
	// crushes dark washes to nothing under the moon, so the darks are lifted
	// onto a deep blue floor (a soft knee: light washes are left alone).
	// The lift comes on through low light, not only once night has fallen, so a
	// dusk is blue in its darks instead of brown.
	vec3 floor_ink = SKY_NIGHT_FLOOR * max(sky_view.y, sky_shade.w * 0.7);
	c = mix(mix(floor_ink, vec3(SKY_NIGHT_KNEE), c / SKY_NIGHT_KNEE), c, step(vec3(SKY_NIGHT_KNEE), c));
	// Where lamplight falls the page shows through the dark a little: the light
	// is a lifted wash, not only a warmer one. Faces are found from screen
	// derivatives (every face here is flat), so roofs are left out as in light().
	float face_up = abs(normalize(cross(dFdx(world_pos), dFdy(world_pos))).y);
	vec4 lamp = sky_lamp_colour(world_pos, face_up);
	// Water (below 0.36) takes no lamplight at all: no glow disc on the sea.
	// The pool is the light's own colour: sodium, stolen neon, a fire.
	float pool = sky_pool(lamp.a, world_pos) * step(0.36, world_pos.y);
	c = sky_lamp_wash(c, lamp.rgb, pool);
#ifndef SKY_FOUND
	// Rain-slicked: wet ground is a step darker and holds the sky in a sheen. By
	// day the sheen is the pale sky, so a wet afternoon is bleak, not night; in
	// low light the step goes deep and the lights' streaks carry. The slick picks
	// out the same lay of hollows the wet wash darkens, stippled at their edges,
	// and spreads over as much of it as this ground is wet — rain that has
	// settled, or a land like the moss that never dries.
	float wet = neon_wetness(world_pos) * step(0.9, face_up);
	float day_sheen = 1.0 - clamp(max(sky_view.y, sky_shade.w), 0.0, 1.0);
	vec3 slick = mix(c * vec3(0.72, 0.76, 0.83), c * vec3(0.84, 0.87, 0.92) + SKY_PUDDLE * sky_tint * 0.04, day_sheen);
	c = mix(c, slick + vec3(0.02, 0.025, 0.035) * neon_wet.y, step(sky_hash(px + vec2(7.0, 61.0)), sky_wet_cover(world_pos, wet)));
#endif
	float cloud = sky_cloud(world_pos);
	if (cloud > 0.0) {
		// A cloud's shade is a colour, like every shade here: one step toward
		// blue-violet (the hatching is laid in light()), with a stippled edge.
		c *= mix(vec3(1.0), SKY_CLOUD_SHADE, step(d, cloud * 0.999) * sky_clouds.w);
	}
	// Each bank's edge is a band of stipple a few pixels wide wherever it lies.
	float fog = sky_fog_at(world_pos, px, max(fwidth(world_pos.x) + fwidth(world_pos.z), 0.01) * 0.035);
	// Furnace haze is drawn in ash lit rust from below, keeping some of the
	// furnace's warmth at dusk; a whiteout is the page gone cold white.
	vec3 fog_col = mix(SKY_PAGE * sky_tint, SKY_HAZE * mix(sky_tint, vec3(1.0, 0.7, 0.45), 0.55), sky_air.z);
	vec3 white = SKY_WHITEOUT * max(sky_tint, vec3(0.55));
	fog_col = mix(fog_col, white, sky_air.w);
	if (fog > 0.0) {
		// The page showing through: washes lighten toward linen in two steps.
		// Under the moon the page is blue too.
		c = mix(c, fog_col, fog * (0.42 + 0.12 * sky_air.z));
	}
	if (sky_air.w > 0.001) {
		// A whiteout: the land round the player still reads, and the page takes
		// the rest in whole steps with a stippled edge between them, until at
		// the edge of the screen there is only blowing white. The white comes
		// in gusts that blow past on the wind, so its edge wanders over the
		// land like weather and never sits as a ruled ring round the player.
		float gust = sky_noise((world_pos.xz - sky_wind.xy * time * 1.6) * 0.16 + vec2(5.0, 17.0));
		float veil = clamp(sky_whiteout_at(world_pos) + (gust - 0.35) * 0.45 * sky_air.w, 0.0, 1.0);
		veil = max(veil, 0.12 * sky_air.w);
		c = mix(c, white, floor(veil * 4.0 + sky_dither(px + vec2(37.0, 5.0))) / 4.0);
	}
	if (sky_air.y > 0.001) {
		// Glare: hard white light bleaches the washes toward a lifted grey and
		// pales the mids; shade and ink keep their places, so it is harsh, not soft.
		float gl = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(gl) * vec3(1.04, 1.03, 0.99) + (1.0 - vec3(gl)) * 0.17, sky_air.y * 0.5);
	}
	if (sky_bolt.z > 0.001) {
		// The strike's afterglow rolling through the clouds: a cold blue-white,
		// laid thinner over bright ground so it never reads as a bank of snow.
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		// The land the light has reached lifts with it, a stipple at a time and
		// thickest behind the rolling front, so a strike is felt on the ground
		// and not only in the cloud. Its far edge is the front itself, dithered.
		c = mix(c, SKY_AFTERGLOW, sky_afterglow(world_pos, d) * (0.38 - 0.2 * lum));
		// And the land under it lifts a step while the light lasts, cold and
		// dithered at its edge, so a strike is felt on the ground as well as in
		// the cloud. A step, never a wash: the shade and the ink keep their places.
		float away = length(world_pos.xz - sky_bolt.xy);
		float lifted = clamp(sky_bolt.z, 0.0, 1.0) * (1.0 - smoothstep(sky_view.w * 0.2, sky_view.w + 4.0, away));
		c = mix(c, min(c * vec3(1.10, 1.14, 1.22), vec3(1.0)), step(sky_dither(px + vec2(19.0, 53.0)), lifted * 0.9));
	}
	if (sky_sun.w > 0.001) {
		// Lightning: for a moment the whole page shows.
		c = mix(c, SKY_PAGE, sky_sun.w * 0.5);
	}
#ifdef SKY_FOUND
	return neon_graded(c, 1.0);
#else
	return neon_graded(c, 0.0);
#endif
}

#endif
