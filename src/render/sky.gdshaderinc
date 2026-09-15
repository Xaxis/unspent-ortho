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
// sky_ground); w: spare.
global uniform vec4 sky_view;
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

const vec3 SKY_PAGE = vec3(0.910, 0.863, 0.753);      // LINEN[5]: the page itself
const vec3 SKY_CLOUD_SHADE = vec3(0.88, 0.90, 0.97);  // a cloud's shade: half a step toward blue-violet
const vec3 SKY_SNOW = vec3(0.90, 0.93, 0.95);         // lying snow: page, a little cold
const vec3 SKY_ASH = vec3(0.231, 0.251, 0.290);       // ASH[1]: specks of fallen ash
const vec3 SKY_PUDDLE = vec3(0.365, 0.545, 0.627);    // RIME[3]: sky in standing water
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

// 0..1 under a cloud: 1 in its shadow, a narrow band at its edge (strength is
// NOT folded in; see sky_clouds.w). Patches are a few tiles across, a handful
// on screen at a time, so light and shade walk over the land together. Two
// layers drift at different rates, so a cloud changes shape as it passes.
float sky_cloud(vec3 world_pos) {
	if (sky_clouds.w < 0.001) {
		return 0.0;
	}
	vec2 q = world_pos.xz + sky_sun.xy * world_pos.y;
	float n = sky_fbm((q - sky_clouds.xy) * 0.12) * 0.7 + sky_noise((q - sky_clouds.xy * 0.8) * 0.33 + vec2(17.0, 3.0)) * 0.3;
	// A fine wobble so the edge is laid by hand, then a band of stipple only a
	// few pixels deep: soft, but still a shape.
	n += (sky_noise(q * 1.1 + vec2(3.0, 11.0)) - 0.5) * 0.03;
	// Cover is the share of the land in shade: n's quantiles, fitted (mean 0.5,
	// spread 0.11), with the ends pushed out so 0 is none and 1 is all.
	float c = sky_clouds.z;
	float t = 0.5 - 0.32 * (c - 0.5) - smoothstep(0.85, 1.0, c) * 0.3 + (1.0 - smoothstep(0.0, 0.1, c)) * 0.3;
	return smoothstep(t - 0.008, t + 0.008, n);
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
	vec2 p = world_pos.xz - sky_fog.xy;
	float n = sky_fbm(p * vec2(0.17, 0.13) + vec2(41.0, 7.0)) * 0.8 + sky_noise(p * 0.45 + vec2(9.0, 2.0)) * 0.2;
	float hollow = sky_ground_at(world_pos).a * SKY_GROUND_HEIGHT - world_pos.y;
	n += clamp(hollow, -1.5, 1.0) * 0.14 + (1.0 - step(0.36, world_pos.y)) * 0.06;
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

// Where the attenuation crosses into the bright core and into the dim ring.
const float SKY_POOL_CORE = 0.66;
const float SKY_POOL_RING = 0.32;

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
	float pool = sky_pool(sky_lamp_level(world_pos, up), world_pos);
	// The core of a pool is clean page; its ring keeps half its hatching.
	float lift = max(step(0.99, pool), step(0.49, pool) * step(sky_hash(floor(px / 3.0) + vec2(23.0, 7.0)), 0.5));
	// Fog thins the hatching a line-length at a time, not pixel by pixel.
	lift = max(lift, step(sky_hash(floor(px / 3.0) + vec2(41.0, 3.0)), sky_fog_at(world_pos, px, 0.01) * 0.9));
	lift = max(lift, step(0.3, sky_sun.w));
	return vec3(lay, lift, deeper);
}

// Outline ink under this sky: near-black by day, deep blue ink under the moon.
vec3 sky_line(vec3 ink) {
	return mix(ink, SKY_NIGHT_INK * max(sky_tint.b, 0.4), sky_view.y * 0.7);
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
		float wet_lay = sky_fbm(world_pos.xz * 0.3 + vec2(71.0, 5.0));
		float w = settle.z;
		float dark = smoothstep(0.02, 0.06, w + wet_lay * 0.6 - 0.55 + w * 0.5 - 0.5 + 0.5);
		c *= mix(vec3(1.0), vec3(0.80, 0.82, 0.90), step(h, dark));
		float puddle_lay = sky_noise(world_pos.xz * 1.3 + vec2(11.0, 47.0)) * 0.6 + broad * 0.4;
		float pool = smoothstep(0.0, 0.02, puddle_lay - 0.86 + (w - 0.5) * 0.12) * flat_face * step(0.5, w);
		c = mix(c, SKY_PUDDLE * sky_tint, step(h, pool) * 0.45);
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
	float pool = sky_pool(sky_lamp_level(world_pos, face_up), world_pos);
	// Water (below 0.36) takes no lamplight at all: no glow disc on the sea.
	c = mix(c, SKY_PAGE * sky_tint, (step(0.99, pool) * 0.22 + step(0.49, pool) * 0.06) * step(0.36, world_pos.y));
	float cloud = sky_cloud(world_pos);
	if (cloud > 0.0) {
		// A cloud's shade is a colour, like every shade here: one step toward
		// blue-violet (the hatching is laid in light()), with a stippled edge.
		c *= mix(vec3(1.0), SKY_CLOUD_SHADE, step(d, cloud * 0.999) * sky_clouds.w);
	}
	// Each bank's edge is a band of stipple a few pixels wide wherever it lies.
	float fog = sky_fog_at(world_pos, px, max(fwidth(world_pos.x) + fwidth(world_pos.z), 0.01) * 0.035);
	if (fog > 0.0) {
		// The page showing through: washes lighten toward linen in two steps.
		// Under the moon the page is blue too.
		c = mix(c, SKY_PAGE * sky_tint, fog * 0.42);
	}
	if (sky_sun.w > 0.001) {
		// Lightning: for a moment the whole page shows.
		c = mix(c, SKY_PAGE, sky_sun.w * 0.5);
	}
	return c;
}

#endif
