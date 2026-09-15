// Owned by the sky/weather package. Included by world.gdshader and
// water.gdshader (and the weather particle shaders). Everything that tints the
// lit world by time, weather or region goes here, so the geometry shaders never
// change for it. The globals are written only by SkyLight.set_hour().
#ifndef SKY_GDSHADERINC
#define SKY_GDSHADERINC

// Time of day x season x region x weather: the colour of the light.
global uniform vec3 sky_tint;
// xy: horizontal offset per unit height toward the light; z: light level
// (0.58 at night, for unlit things to match); w: lightning flash 0..1.
global uniform vec4 sky_sun;
// xy: cloud drift in tiles; z: coverage 0..1; w: shadow strength 0..1 (0 at night).
global uniform vec4 sky_clouds;
// xy: fog drift in tiles; z: fog density 0..1; w: heat shimmer 0..1.
global uniform vec4 sky_fog;
// x: world units per screen pixel (the camera is snapped to it); yzw spare.
global uniform vec4 sky_view;

// 0/1 checker on whole SCREEN pixels, from a world position. The camera never
// rotates (yaw 45, pitch 57) and is snapped to texels, so this grid never crawls.
float sky_checker(vec3 world_pos) {
	float texel = max(sky_view.x, 0.001);
	float px = floor(dot(world_pos, vec3(0.7071, 0.0, -0.7071)) / texel);
	float py = floor(dot(world_pos, vec3(-0.5931, 0.5446, -0.5931)) / texel);
	return mod(px + py, 2.0);
}

float sky_bayer2(vec2 a) {
	a = floor(a);
	return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

// Ordered 4x4 threshold 0..1 on whole screen pixels: soft things (fog, haze)
// step between a few values in a pixel pattern instead of a smooth gradient.
float sky_bayer(vec3 world_pos) {
	float texel = max(sky_view.x, 0.001);
	vec2 px = vec2(dot(world_pos, vec3(0.7071, 0.0, -0.7071)), dot(world_pos, vec3(-0.5931, 0.5446, -0.5931))) / texel;
	return sky_bayer2(0.5 * px) * 0.25 + sky_bayer2(px);
}

// Hash without sine (Hoskins): stable in highp, no texture needed.
float sky_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

// 1 under a cloud's shadow, 0 in sun. Two layers drifting at different rates
// so the clouds change shape as they pass instead of sliding like a decal.
float sky_cloud_shadow(vec3 world_pos) {
	vec2 q = world_pos.xz + sky_sun.xy * world_pos.y;
	float n = sky_fbm((q - sky_clouds.xy) * 0.034) * 0.72 + sky_noise((q - sky_clouds.xy * 0.6) * 0.09 + vec2(17.0, 3.0)) * 0.28;
	// n sits near 0.5 with a spread of about 0.12: this maps cover to area.
	float t = mix(0.70, 0.30, sky_clouds.z);
	// A dithered rim about one pixel wide, wherever the noise is steep or flat.
	float rim = max(fwidth(n) * 1.2, 0.0005);
	return max(step(t, n), step(t - rim, n) * sky_checker(world_pos));
}

vec3 sky_apply(vec3 albedo, vec3 world_pos, float time) {
	vec3 c = albedo * sky_tint;
	if (sky_clouds.w > 0.001) {
		// A cloud's shade is a colour, like every shadow here: a little of the
		// blue-violet of the cast shadow, never grey.
		float s = sky_cloud_shadow(world_pos);
		c *= mix(vec3(1.0), vec3(0.76, 0.79, 0.93), s * sky_clouds.w);
	}
	if (sky_fog.z > 0.001) {
		// Banks that lie in the low ground and drift, stretched along the wind:
		// thick on the water and in hollows, thinning up the hills, so high
		// ground stands out of it.
		vec2 p = world_pos.xz - sky_fog.xy;
		vec2 s = vec2(p.x + p.y, p.y - p.x) * 0.7071;
		float n = sky_fbm(s * vec2(0.11, 0.04) + vec2(41.0, 7.0));
		float low = 1.0 - smoothstep(0.2, 3.2, world_pos.y);
		float d = smoothstep(0.30, 0.70, n + low * 0.24) * sky_fog.z;
		// Five values, dithered between on screen pixels.
		d = floor(d * 4.0 + sky_bayer(world_pos)) / 4.0;
		// A darker body (ash2) with lighter wisps (ash4) combed along the drift.
		float wisp = sky_noise(s * vec2(0.6, 0.06) + vec2(5.0, time * 0.03));
		vec3 wash = mix(vec3(0.58, 0.61, 0.67), vec3(0.79, 0.82, 0.86), step(0.58, wisp));
		c = mix(c, wash * sky_tint, d * 0.5);
	}
	if (sky_fog.w > 0.001) {
		// Heat shimmer: short bright dashes on whole screen rows that crawl up the
		// screen and break up, the way hot air wobbles a far line.
		float texel = max(sky_view.x, 0.001);
		float row = floor(dot(world_pos, vec3(-0.5931, 0.5446, -0.5931)) / texel);
		float col = dot(world_pos, vec3(0.7071, 0.0, -0.7071));
		float wave = sin(row * 0.9 + time * 5.0) * sin(col * 1.7 + row * 0.13 - time * 1.1);
		float broken = step(0.55, sky_noise(vec2(col * 0.8, row * 0.25 + time * 2.0)));
		c *= 1.0 + step(0.8, wave) * broken * 0.09 * sky_fog.w;
	}
	if (sky_sun.w > 0.001) {
		c = mix(c, vec3(0.80, 0.86, 1.0), sky_sun.w * 0.5);
	}
	return c;
}

#endif
