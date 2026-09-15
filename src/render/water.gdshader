// Water sheets. UV.x is the water kind (TerrainMesher.WATER_*), COLOR.rg the
// downstream direction for rivers, UV2 the tile-space position. The waterline
// distance comes from the world's field texture, so the sea deepens in warped
// bands, foam laps the shore in step with the wet strand on the land side
// (world.gdshader shares `lap`), rivers run, blackwater keeps green edges and
// an oily film, and cold water carries floes. Never a shimmer: slow, stepped.
shader_type spatial;
render_mode cull_back, specular_disabled, world_vertex_coords;

#include "res://src/render/sky.gdshaderinc"

uniform vec3 shade_tint = vec3(0.64, 0.66, 0.80);
uniform bool has_terrain = false;
uniform sampler2D field_lin : filter_linear;
uniform sampler2D palette_tex : filter_nearest;
uniform vec2 world_size = vec2(256.0);

const int INK = 0;
const int BRINE = 2;
const int SPRUCE = 7;
const int ASH = 12;
const int RIME = 14;
const int BLOOM = 15;

const int W_SEA = 0;
const int W_RIVER = 1;
const int W_BLACK = 2;
const int W_COLD = 3;
const int W_FALL = 4;
const int W_OPEN = 5;

const vec3 STEP = vec3(0.700, 0.704, 0.749);

varying vec3 world_pos;
varying vec2 tile_pos;
varying flat int wkind;
varying vec2 flow;

uint hu(uint x) {
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}

float hash(ivec2 p, int salt) {
	uint h = hu(uint(p.x) + hu(uint(p.y) + hu(uint(salt))));
	return float(h >> 8u) / 16777216.0;
}

float vnoise(vec2 p, int salt) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	ivec2 ii = ivec2(i);
	float a = hash(ii, salt);
	float b = hash(ii + ivec2(1, 0), salt);
	float c = hash(ii + ivec2(0, 1), salt);
	float d = hash(ii + ivec2(1, 1), salt);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 voronoi(vec2 p, int salt) {
	ivec2 ip = ivec2(floor(p));
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			ivec2 cell = ip + ivec2(x, y);
			vec2 o = vec2(float(x), float(y)) + vec2(hash(cell, salt), hash(cell, salt + 7)) * 0.85 + 0.075;
			float d = length(o - fp);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = hash(cell, salt + 13);
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(f1, f2, id);
}

vec3 pal(int ramp, int i) {
	return texelFetch(palette_tex, ivec2(i, ramp), 0).rgb;
}

vec3 dn(vec3 c, float n) {
	return c * pow(STEP, vec3(n));
}

vec3 upc(vec3 c, float n) {
	return min(c * pow(STEP, vec3(-n)), vec3(1.0));
}

float lap(vec2 p) {
	return 0.5 + 0.5 * sin(TIME * 1.15 + vnoise(p * 0.35, 7) * 6.2831);
}

void vertex() {
	world_pos = VERTEX;
	tile_pos = UV2;
	wkind = int(UV.x + 0.5);
	flow = COLOR.rg * 2.0 - 1.0;
}

// Stepped swell: bands drift on a period of four, never a shimmer.
float swell(vec2 p) {
	float t = floor(TIME * 4.0) / 4.0;
	return sin((p.x + p.y) * 0.9 - t * 0.8) * sin(p.x * 0.37 - p.y * 0.23 + t * 0.35);
}

vec3 sea(vec2 p, float sd, bool cold) {
	float dn_ = sd + (vnoise(p * 0.45, 11) - 0.5) * 1.1;
	vec3 c;
	if (cold) {
		c = dn_ < 1.4 ? pal(RIME, 3) : (dn_ < 4.0 ? pal(RIME, 2) : (dn_ < 9.0 ? mix(pal(RIME, 1), pal(BRINE, 1), 0.5) : pal(BRINE, 1)));
	} else {
		c = dn_ < 1.3 ? pal(BRINE, 3) : (dn_ < 3.5 ? mix(pal(BRINE, 3), pal(BRINE, 2), 0.5) : (dn_ < 8.0 ? pal(BRINE, 2) : pal(BRINE, 1)));
	}
	float sw = swell(p);
	if (sw > 0.74) {
		c = upc(c, 0.4);
	} else if (sw < -0.8 && dn_ > 3.0) {
		c = dn(c, 0.3);
	}
	if (cold) {
		// Floes: plates of ice thickest near the shore, drifting a little.
		vec2 q = p * 0.55 + vec2(TIME * 0.01, 0.0);
		vec3 v = voronoi(q, 21);
		float want = 0.25 + 0.5 * clamp(1.0 - sd / 7.0, 0.0, 1.0);
		if (v.z < want && v.y - v.x > 0.07) {
			c = v.y - v.x < 0.12 ? pal(RIME, 5) : pal(RIME, 4);
		}
	}
	// Foam that laps: a front that runs in and draws back, broken along its length.
	float l = lap(p);
	float front = sd - (0.04 + 0.38 * l);
	float broken = vnoise(p * 2.6 + vec2(0.0, TIME * 0.15), 31);
	if (front < 0.0 && sd < 0.75) {
		c = broken > 0.3 ? pal(RIME, 5) : upc(c, 0.8);
	} else if (front < 0.12) {
		c = broken > 0.55 ? pal(BRINE, 5) : c;
	}
	// A second, fainter line further out, coming in as the first draws back.
	float outer = abs(sd - (0.8 + 0.6 * (1.0 - l)));
	if (outer < 0.05 && broken > 0.45) {
		c = upc(c, 0.55);
	}
	return c;
}

vec3 river(vec2 p, float sd, vec2 dir) {
	vec2 d = length(dir) > 0.1 ? normalize(dir) : vec2(1.0, 0.0);
	float along = dot(p, d);
	float across = dot(p, vec2(-d.y, d.x));
	vec3 c = sd < 0.9 ? pal(BRINE, 3) : pal(BRINE, 2);
	if (sd > 2.2) {
		c = mix(pal(BRINE, 2), pal(BRINE, 1), 0.5);
	}
	// Dashes carried downstream in lanes, each lane its own speed.
	float lane = floor(across * 3.0);
	float lh = hash(ivec2(int(lane), 0), 41);
	float run = fract(along * (0.55 + lh * 0.3) - TIME * (0.45 + lh * 0.35) + lh * 7.0);
	if (lh > 0.35 && run < 0.16 && fract(across * 3.0) > 0.3 && fract(across * 3.0) < 0.7) {
		c = upc(c, 0.55);
	}
	// Riffles along the banks.
	if (sd < 0.35 && vnoise(vec2(along * 2.0 - TIME * 1.2, across * 6.0), 42) > 0.55) {
		c = pal(BRINE, 5);
	}
	return c;
}

vec3 blackwater(vec2 p, float sd) {
	vec3 c = pal(BRINE, 0);
	// Green at the edges.
	float edge = sd + (vnoise(p * 1.4, 51) - 0.5) * 0.35;
	if (edge < 0.28) {
		c = pal(SPRUCE, 2);
	} else if (edge < 0.62) {
		c = pal(SPRUCE, 1);
	}
	// An oily film in marbled bands on the still water.
	float m = vnoise(p * 0.5 + vec2(TIME * 0.01, 0.0), 52) * 3.0 + vnoise(p * 1.3, 53);
	float band = fract(m * 1.7);
	if (edge > 0.62 && band < 0.05) {
		c = mix(c, pal(BLOOM, 1), 0.6);
	} else if (edge > 0.62 && band > 0.5 && band < 0.54) {
		c = mix(c, pal(SPRUCE, 3), 0.45);
	}
	// A rare slow ring where something rose.
	vec2 cell = floor(p * 0.25);
	float rh = hash(ivec2(cell), 54);
	vec2 centre = (cell + vec2(hash(ivec2(cell), 55), hash(ivec2(cell), 56))) * 4.0;
	float age = fract(TIME * 0.08 + rh * 13.0);
	if (rh > 0.6 && abs(length(p - centre) - age * 1.4) < 0.05 && age < 0.6) {
		c = upc(c, 1.0);
	}
	return c;
}

vec3 fall(vec2 p, float y) {
	float col = floor((p.x + p.y) * 7.0);
	float h = hash(ivec2(int(col), 0), 61);
	float run = fract(y * 2.2 + TIME * (1.4 + h) + h * 5.0);
	return run < 0.45 ? pal(RIME, 5) : (h > 0.5 ? pal(BRINE, 4) : pal(BRINE, 5));
}

void fragment() {
	vec2 p = tile_pos;
	float sd = 12.0;
	if (has_terrain && wkind != W_OPEN) {
		sd = (texture(field_lin, p / world_size).a * 255.0 - 128.0) / 10.0;
	}
	vec3 c;
	if (wkind == W_RIVER) {
		c = river(p, sd, flow);
	} else if (wkind == W_BLACK) {
		c = blackwater(p, sd);
	} else if (wkind == W_FALL) {
		c = fall(p, world_pos.y);
	} else if (wkind == W_OPEN) {
		c = pal(BRINE, 1);
		if (swell(world_pos.xz) > 0.8) {
			c = upc(c, 0.35);
		}
	} else {
		c = sea(p, sd, wkind == W_COLD);
	}
	ALBEDO = sky_apply(c, world_pos, TIME);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_tint, vec3(1.0), lit) / PI;
	} else {
		float a = floor(clamp(ATTENUATION, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
