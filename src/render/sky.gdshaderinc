// The sky over the notebook (docs/ART.md section 6). Owned by the sky package.
// Included by every lit shader (world, found, water) and by the weather marks.
// It is the ONLY place lit colour is tinted by time, weather or region:
//
//   sky_apply(albedo, world_pos, TIME)   in fragment(): the wash under this sky
//   sky_ink(world_pos, lit)              in world.gdshader light(): how the sky
//                                        lays or lifts hatching (cloud shadow and
//                                        night lay it; lamplight, fog and a
//                                        lightning flash lift it)
//   sky_pool(attenuation, world_pos)     in light() for lamps and fire: the pool
//                                        in two hard steps with a stippled rim
//   sky_line(ink)                        for outlines: ink turns blue at night
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
// x: world units per screen pixel; y: night fall 0..1; zw: spare.
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

const vec3 SKY_PAGE = vec3(0.910, 0.863, 0.753);      // LINEN[5]: the page itself
const vec3 SKY_CLOUD_SHADE = vec3(0.86, 0.87, 0.95);  // a cloud's shade: a step toward blue-violet
const vec3 SKY_SNOW = vec3(0.90, 0.93, 0.95);         // lying snow: page, a little cold
const vec3 SKY_ASH = vec3(0.231, 0.251, 0.290);       // ASH[1]: specks of fallen ash
const vec3 SKY_PUDDLE = vec3(0.365, 0.545, 0.627);    // RIME[3]: sky in standing water
const vec3 SKY_NIGHT_INK = vec3(0.16, 0.20, 0.42);    // what ink turns to under the moon

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
// NOT folded in; see sky_clouds.w). Two layers drifting at different rates, so
// a cloud changes shape as it passes instead of sliding over the land.
float sky_cloud(vec3 world_pos) {
	if (sky_clouds.w < 0.001) {
		return 0.0;
	}
	vec2 q = world_pos.xz + sky_sun.xy * world_pos.y;
	float n = sky_fbm((q - sky_clouds.xy) * 0.03) * 0.74 + sky_noise((q - sky_clouds.xy * 0.63) * 0.085 + vec2(17.0, 3.0)) * 0.26;
	// n sits near 0.5 with a spread of about 0.12: this maps cover to area.
	float t = mix(0.68, 0.32, sky_clouds.z);
	return smoothstep(t - 0.02, t + 0.02, n);
}

// 0..1 fog at a place: banks that drift with the wind, lie thick on water and
// in hollows, and thin up the hills so high ground stands out of them.
float sky_fog_at(vec3 world_pos, float time) {
	if (sky_fog.z < 0.001) {
		return 0.0;
	}
	vec2 p = world_pos.xz - sky_fog.xy;
	float n = sky_fbm(p * vec2(0.045, 0.032) + vec2(41.0, 7.0));
	float low = 1.0 - smoothstep(0.1, 3.5, world_pos.y);
	return smoothstep(0.40, 0.60, n + low * 0.2 - (1.0 - sky_fog.z) * 0.3) * sky_fog.z;
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

float sky_lamp_level(vec3 world_pos) {
	float a = 0.0;
	for (int i = 0; i < 4; i++) {
		a = max(a, sky_omni(world_pos, sky_lamps[i]));
		a = max(a, sky_omni(world_pos, sky_lamps2[i]));
	}
	return a;
}

// A pool of lamplight in two hard steps: the full pool, then a thin rim that
// breaks into stipple. Never a smooth falloff, never concentric target rings.
float sky_pool(float a, vec3 world_pos) {
	float h = sky_hash(sky_px(world_pos) + vec2(29.0, 13.0));
	if (a >= 0.5) {
		// The inner edge is ragged: stipple eats a little way into the pool.
		return (a < 0.54 && h > (a - 0.5) / 0.04) ? 0.35 : 1.0;
	}
	if (a >= 0.36) {
		return h < (a - 0.36) / 0.14 * 0.7 ? 0.35 : 0.0;
	}
	return 0.0;
}

// How the sky changes the hatching of a MADE surface, for world.gdshader
// light(). Returns x: 1 where hatching is laid on a sunlit face (a cloud's
// shadow, or night), y: 1 where hatching is lifted (lamplight, fog, a flash),
// z: how much deeper shade reads (night). All 0/1 per pixel, dithered.
vec3 sky_ink(vec3 world_pos, float lit) {
	vec2 px = sky_px(world_pos);
	float d = sky_dither(px);
	float night = sky_view.y;
	// Under a thin cloud the hatch breaks into short lengths; under a thick one
	// it runs whole.
	float shaded = step(d, sky_cloud(world_pos) * 0.999) * step(sky_hash(floor(px / 3.0) + vec2(5.0, 9.0)), sky_clouds.w * 1.2 - 0.1);
	float lay = max(step(d, night * 0.999), shaded);
	float deeper = max(night * 0.3, shaded * 0.2);
	float lift = step(0.99, sky_pool(sky_lamp_level(world_pos), world_pos));
	// Fog thins the hatching a line-length at a time, not pixel by pixel.
	lift = max(lift, step(sky_hash(floor(px / 3.0) + vec2(41.0, 3.0)), sky_fog_at(world_pos, 0.0) * 1.1 - 0.15));
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
// the sea floor sit below 0.36 and are left alone. Nothing lies on a machine's
// found violet: they run warm, and they must always read as machines.
vec3 sky_settled(vec3 c, vec3 albedo, vec3 world_pos, vec2 px) {
	if (sky_settle.x + sky_settle.y + sky_settle.z < 0.002 || world_pos.y < 0.36) {
		return c;
	}
	if (albedo.b - albedo.g > 0.3 && albedo.b > albedo.r) {
		return c;
	}
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
	if (sky_settle.z > 0.001) {
		// Wet ground darkens a step in patches that spread as it rains and
		// shrink as it dries; standing water shows the sky in the flat hollows.
		float wet_lay = sky_fbm(world_pos.xz * 0.3 + vec2(71.0, 5.0));
		float w = sky_settle.z;
		float dark = smoothstep(0.02, 0.06, w + wet_lay * 0.6 - 0.55 + w * 0.5 - 0.5 + 0.5);
		c *= mix(vec3(1.0), vec3(0.80, 0.82, 0.90), step(h, dark));
		float puddle_lay = sky_noise(world_pos.xz * 1.3 + vec2(11.0, 47.0)) * 0.6 + broad * 0.4;
		float pool = smoothstep(0.0, 0.02, puddle_lay - 0.86 + (w - 0.5) * 0.12) * flat_face * step(0.5, w);
		c = mix(c, SKY_PUDDLE * sky_tint, step(h, pool) * 0.45);
	}
	if (sky_settle.y > 0.001) {
		float a = sky_settle.y;
		// Specks, gathering thicker where it drifts, never a flat grey bed.
		float drift = sky_noise(world_pos.xz * 0.6 + vec2(5.0, 23.0));
		c = mix(c, SKY_ASH * sky_tint, step(h, a * (0.06 + 0.1 * drift)));
	}
	if (sky_settle.x > 0.001) {
		float s = sky_settle.x;
		float lie = smoothstep(0.0, 0.05, lay - 1.0 + s * 0.75);
		// Flecks outrun the drift, so snow arrives as paper showing through.
		float fleck = step(h, s * 0.3) * step(0.5, sky_hash(px * 0.5 + vec2(3.0, 1.0)));
		c = mix(c, SKY_SNOW * sky_tint, max(step(h, lie), fleck));
	}
	return c;
}

vec3 sky_apply(vec3 albedo, vec3 world_pos, float time) {
	vec2 px = sky_px(world_pos);
	float d = sky_dither(px);
	vec3 c = sky_settled(albedo * sky_tint, albedo, world_pos, px);
	float cloud = sky_cloud(world_pos);
	if (cloud > 0.0) {
		// A cloud's shade is a colour, like every shade here: one step toward
		// blue-violet (the hatching is laid in light()), with a stippled edge.
		c *= mix(vec3(1.0), SKY_CLOUD_SHADE, step(d, cloud * 0.999) * sky_clouds.w);
	}
	float fog = sky_fog_at(world_pos, time);
	if (fog > 0.0) {
		// The page showing through: washes lighten toward linen in two steps,
		// dithered between. Under the moon the page is blue too.
		float level = (step(d, fog * 1.6 - 0.1) + step(d, fog * 1.6 - 0.7)) * 0.5;
		c = mix(c, SKY_PAGE * sky_tint, level * 0.5);
	}
	if (sky_sun.w > 0.001) {
		// Lightning: for a moment the whole page shows.
		c = mix(c, SKY_PAGE, sky_sun.w * 0.5);
	}
	return c;
}

#endif
