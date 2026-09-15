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
	float n = sky_fbm((q - sky_clouds.xy) * 0.045) * 0.7 + sky_noise((q - sky_clouds.xy * 0.6) * 0.11 + vec2(17.0, 3.0)) * 0.3;
	return step(1.0 - sky_clouds.z * 0.62, n + 0.12);
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
		// Banks that lie in the low ground and drift: denser in hollows and on the
		// water, thinning up the hills, stepped into four values like everything else.
		vec2 p = world_pos.xz - sky_fog.xy;
		float n = sky_fbm(p * 0.07 + vec2(41.0, 7.0));
		float low = 1.0 - smoothstep(0.0, 3.5, world_pos.y);
		float d = clamp((n - 0.28) * 2.2 + low * 0.45, 0.0, 1.0) * sky_fog.z;
		d = floor(d * 4.0 + 0.5) / 4.0;
		vec3 bank = vec3(0.72, 0.75, 0.79) * sky_tint;
		// Some of the bank is a darker body under a lighter top: the drift reads.
		float body = step(0.55, sky_noise(p * 0.19 + vec2(3.0, 11.0)));
		bank *= mix(1.0, 0.9, body);
		c = mix(c, bank, d * 0.55);
	}
	if (sky_fog.w > 0.001) {
		// Heat: thin bright ripples crawling across open ground, a step of warmth.
		float r = sin(world_pos.z * 5.0 + world_pos.x * 1.3 - time * 2.3 + 3.0 * sky_noise(world_pos.xz * 0.35 + vec2(0.0, time * 0.3)));
		c *= 1.0 + step(0.93, r) * 0.07 * sky_fog.w;
	}
	if (sky_sun.w > 0.001) {
		c = mix(c, vec3(0.80, 0.86, 1.0), sky_sun.w * 0.5);
	}
	return c;
}

#endif
