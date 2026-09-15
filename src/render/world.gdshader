// The one lit material for everything MADE and FOUND: terrain, props, people,
// machines. Albedo is the vertex colour (palette sRGB). Lighting follows the art
// direction: a hard one-step shadow that is a COLOUR (blue-violet), a second
// band on grazing faces, no specular, no smooth falloff. Day, night, weather and
// region are multiplies set on the global `sky_tint` (sky.gdshaderinc).
//
// Vertex channels (TerrainMesher documents them): UV.y is a KIND, UV.x its
// parameter, UV2 the tile-space position. Plain models have UV = 0 and draw
// their vertex colour. Kinds:
//   1 terrain top   the ground, painted from per-tile data textures by world fields
//   2 cliff face    strata by country; COLOR carries (country, country2, blend, lip)
//   3 glow          emissive embers and lamps, UV.x strength
//   4 sway          wind moves it, UV.x weight (0 base .. 1 tip)
//   5 glint         sea glass, frost, wet glass: an occasional sparkle
// Every pattern colour is a palette value or a whole or half ramp step of the
// ground's own colour (STEP), so the frame stays on the palette.
shader_type spatial;
render_mode cull_back, specular_disabled, world_vertex_coords;

#include "res://src/render/sky.gdshaderinc"

// The measured one-step darken of the source game, pushed toward blue-violet.
uniform vec3 shade_tint = vec3(0.64, 0.66, 0.80);
uniform float emission_strength = 0.0;
// Wind 0 calm .. 1 gale, and its bearing in tile space.
uniform float wind = 0.35;
uniform vec2 wind_dir = vec2(0.83, 0.55);
// World units per screen pixel: sway moves in whole pixels, never a smear.
uniform float texel = 0.0417;

// Terrain data, bound only on WorldView's materials.
uniform bool has_terrain = false;
uniform sampler2D tile_tex : filter_nearest;
uniform sampler2D field_tex : filter_nearest;
uniform sampler2D field_lin : filter_linear;
uniform sampler2D palette_tex : filter_nearest;
uniform vec2 world_size = vec2(256.0);
// World xz of tile (0, 0): models find the tile under them from it.
uniform vec2 tile_origin = vec2(0.0);

// Ramp rows of TerrainMesher.palette_image().
const int INK = 0;
const int STONE = 1;
const int BRINE = 2;
const int SLATE = 3;
const int EARTH = 4;
const int RUST = 5;
const int MOSS = 6;
const int SPRUCE = 7;
const int SAND = 8;
const int LINEN = 9;
const int ASH = 12;
const int EMBER = 13;
const int RIME = 14;
const int BLOOM = 15;

// Ground ids (src/core/ground.gd).
const int G_DEEP_WATER = 0;
const int G_WATER = 1;
const int G_SAND = 2;
const int G_GRASS = 3;
const int G_MOSS = 4;
const int G_MUD = 5;
const int G_NEEDLES = 6;
const int G_SNOW = 7;
const int G_BONE = 8;
const int G_ASH = 9;
const int G_ROCK = 10;
const int G_ROAD = 11;
const int G_FLOOR = 12;
const int G_HEATH = 13;
const int G_SHINGLE = 14;
const int G_GRAVEL = 15;
const int G_SCREE = 16;
const int G_LIMESTONE = 17;
const int G_CLINKER = 18;
const int G_ICE = 19;
const int G_BLACKWATER = 20;
const int G_PEAT = 21;
const int G_RIVER = 22;

// Country ids (src/core/country.gd).
const int C_COAST = 1;
const int C_MOSS = 2;
const int C_PINEWOOD = 3;
const int C_SNOWFIELD = 4;
const int C_BONELANDS = 5;
const int C_BURNING = 6;

const vec3 STEP = vec3(0.700, 0.704, 0.749);

varying vec3 world_pos;
varying vec2 tile_pos;
varying flat int kind;
varying float param;

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

// (F1, F2, id of the nearest cell)
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

vec3 dn(vec3 c, float n) {
	return c * pow(STEP, vec3(n));
}

vec3 upc(vec3 c, float n) {
	return min(c * pow(STEP, vec3(-n)), vec3(1.0));
}

vec3 pal(int ramp, int i) {
	return texelFetch(palette_tex, ivec2(i, ramp), 0).rgb;
}

bool is_wet(int g) {
	return g == G_DEEP_WATER || g == G_WATER || g == G_BLACKWATER || g == G_RIVER;
}

// The swash: 0 drawn back .. 1 run up the shore. Shared with water.gdshader.
float lap(vec2 p) {
	return 0.5 + 0.5 * sin(TIME * 1.15 + vnoise(p * 0.35, 7) * 6.2831);
}

float shore_distance(vec2 p) {
	return (texture(field_lin, p / world_size).a * 255.0 - 128.0) / 10.0;
}

vec3 limestone(vec3 c, vec2 p, float spacing) {
	vec2 da = vec2(0.985, 0.17);
	vec2 db = vec2(-0.17, 0.985);
	float sa = 2.1 * spacing;
	float sb = 1.45 * spacing;
	float su = dot(p, da) / sa + (vnoise(p * 0.21, 81) - 0.5) * 0.5;
	float row = floor(su);
	float sv = dot(p, db) / sb + hash(ivec2(int(row), 0), 82) * 3.0 + (vnoise(p * 0.33, 83) - 0.5) * 0.35;
	float fu = fract(su);
	float fv = fract(sv);
	float clint = hash(ivec2(int(row), int(floor(sv))), 84);
	c = clint < 0.3 ? dn(c, 0.22) : (clint > 0.8 ? upc(c, 0.18) : c);
	float to_a = fu * sa;
	float to_b = (1.0 - fu) * sa;
	float to_c = fv * sb;
	float to_d = (1.0 - fv) * sb;
	float gd = min(min(to_a, to_b), min(to_c, to_d));
	if (gd < 0.05) {
		// The grike: a dark slot, some with grass or ferns down in it.
		c = vnoise(p * 0.8, 85) > 0.62 ? pal(MOSS, 2) : pal(SLATE, 1);
	} else if (to_b < 0.1 || to_d < 0.09) {
		c = dn(c, 0.9);
	} else if (to_a < 0.13 || to_c < 0.11) {
		// The rubbed-bright edge on the side toward the light.
		c = upc(c, 0.35);
	}
	// Rows of drill holes along some joints, the machine age in the stone.
	if (hash(ivec2(int(row), 5), 86) > 0.7 && to_a > 0.1 && to_a < 0.2 && fract(dot(p, db) * 3.0) < 0.3) {
		c = dn(c, 1.4);
	}
	return c;
}

// The ground's own pattern. `emit` collects embers.
vec3 paint(int g, vec3 c, vec2 p, inout vec3 emit) {
	if (g == G_GRASS) {
		vec2 q = p * 5.0;
		ivec2 qi = ivec2(floor(q));
		vec2 fq = fract(q) - 0.5 - (vec2(hash(qi, 32), hash(qi, 33)) - 0.5) * 0.4;
		float h = hash(qi, 31);
		float r = length(fq);
		if (h < 0.16 && r < 0.2) {
			c = dn(c, 0.55);
		} else if (h > 0.93 && r < 0.17) {
			c = upc(c, 0.45);
		}
		if (vnoise(p * 0.35, 34) > 0.76) {
			c = mix(c, pal(EARTH, 3), 0.3);
		}
	} else if (g == G_HEATH) {
		vec3 v = voronoi(p * 1.5, 41);
		if (v.z < 0.45) {
			c = dn(c, 0.4);
		} else if (v.z > 0.78) {
			c = mix(c, pal(MOSS, 2), 0.55);
		}
		if (v.y - v.x < 0.07) {
			c = dn(c, 0.7);
		} else if (v.z < 0.45 && v.x < 0.22 && vnoise(p * 0.12, 42) > 0.45) {
			c = v.z < 0.2 ? pal(BLOOM, 2) : pal(BLOOM, 1);
		}
		if (vnoise(p * 0.18, 43) > 0.8) {
			c = mix(c, pal(INK, 2), 0.5);
		}
	} else if (g == G_SAND) {
		float rip = sin((p.x * 0.6 + p.y * 1.1) * 6.0 + vnoise(p * 0.5, 51) * 6.0);
		if (rip > 0.9) {
			c = dn(c, 0.3);
		} else if (rip < -0.94) {
			c = upc(c, 0.3);
		}
		float sh = hash(ivec2(floor(p * 7.0)), 52);
		if (sh > 0.988) {
			c = pal(LINEN, 5);
		} else if (sh < 0.012) {
			c = dn(c, 0.8);
		}
	} else if (g == G_SHINGLE || g == G_GRAVEL) {
		float scale = g == G_SHINGLE ? 3.2 : 5.5;
		vec3 v = voronoi(p * scale, 61);
		float tone = v.z;
		c = tone < 0.25 ? dn(c, 0.6) : (tone < 0.55 ? c : (tone < 0.86 ? upc(c, 0.3) : mix(c, pal(SAND, 3), 0.5)));
		if (v.y - v.x < 0.08) {
			c = dn(c, 1.0);
		} else if (v.x < 0.13 && tone > 0.5) {
			c = upc(c, 0.4);
		}
		if (g == G_SHINGLE && tone > 0.992) {
			c = hash(ivec2(floor(p * scale)), 62) > 0.5 ? pal(SPRUCE, 4) : pal(BRINE, 5);
		}
	} else if (g == G_SCREE) {
		vec3 v = voronoi(p * 2.2, 71);
		c = v.z < 0.3 ? dn(c, 0.45) : (v.z > 0.75 ? upc(c, 0.3) : c);
		if (v.y - v.x < 0.09) {
			c = dn(c, 1.2);
		}
		if (v.z > 0.93) {
			c = mix(c, pal(LINEN, 3), 0.5);
		}
	} else if (g == G_LIMESTONE) {
		c = limestone(c, p, 1.0);
	} else if (g == G_BONE) {
		c = limestone(c, p, 1.6);
	} else if (g == G_SNOW) {
		vec2 wd = vec2(0.89, 0.45);
		float across = dot(p, wd);
		float along = dot(p, vec2(-wd.y, wd.x));
		float ridge = across * 0.42 + vnoise(vec2(along * 0.16, across * 0.05), 91) * 2.6 + vnoise(p * 0.45, 92) * 0.5;
		float fr = fract(ridge);
		if (fr > 0.9) {
			c = upc(c, 0.3);
		} else if (fr < 0.16) {
			c = dn(c, 0.75);
		} else if (fr < 0.34) {
			c = dn(c, 0.35);
		}
		// Soot in the lee of the drifts.
		if (fr < 0.12 && vnoise(p * 1.3, 93) > 0.74) {
			c = mix(c, pal(ASH, 2), 0.5);
		}
		float gh = hash(ivec2(floor(p * 9.0)), 94);
		if (gh > 0.994 && fract(TIME * 0.23 + gh * 97.0) < 0.2) {
			c = vec3(1.0);
		}
	} else if (g == G_ICE) {
		vec3 v = voronoi(p * 0.9, 101);
		if (vnoise(p * 0.3, 102) < 0.4) {
			c = dn(c, 0.5);
		}
		if (v.y - v.x < 0.03) {
			c = pal(RIME, 5);
		} else if (v.y - v.x < 0.065) {
			c = dn(c, 0.6);
		}
		if (hash(ivec2(floor(p * 6.0)), 103) > 0.985) {
			c = upc(c, 0.6);
		}
		if (vnoise(vec2(dot(p, vec2(0.89, 0.45)) * 0.2, dot(p, vec2(-0.45, 0.89)) * 1.6), 104) > 0.72) {
			c = mix(c, pal(RIME, 5), 0.7);
		}
	} else if (g == G_ASH) {
		float drift = sin(dot(p, vec2(0.7, 1.0)) * 2.2 + vnoise(p * 0.4, 111) * 5.0);
		if (drift > 0.8) {
			c = upc(c, 0.3);
		} else if (drift < -0.85) {
			c = dn(c, 0.35);
		}
		vec2 q = p * 6.0;
		float eh = hash(ivec2(floor(q)), 112);
		vec2 ef = fract(q) - 0.5;
		if (eh > 0.986 && length(ef) < 0.3) {
			float fl = step(0.5, fract(TIME * (0.6 + eh * 2.0) + eh * 13.0));
			c = mix(pal(EMBER, 2), pal(EMBER, 4), fl);
			emit += pal(EMBER, 3) * (0.5 + 0.7 * fl);
		} else if (eh < 0.01 && abs(ef.y) < 0.18 && abs(ef.x) < 0.34) {
			// A leaf of burnt ruled paper.
			c = abs(ef.y) < 0.05 ? pal(LINEN, 2) : pal(LINEN, 3);
		} else if (eh > 0.94 && length(ef) < 0.22) {
			c = pal(ASH, 0);
		}
	} else if (g == G_CLINKER) {
		vec3 v = voronoi(p * 1.15, 121);
		if (v.y - v.x < 0.09) {
			c = pal(STONE, 1);
		} else {
			c = mix(pal(INK, 1), pal(SPRUCE, 1), v.z * 0.8);
			if (v.x > 0.22 && v.x < 0.3 && v.z > 0.4) {
				c = pal(SPRUCE, 2);
			}
			if (hash(ivec2(floor(p * 8.0)), 123) > 0.985) {
				c = pal(SPRUCE, 4);
			}
		}
		if (vnoise(p * 0.5, 122) > 0.76) {
			c = mix(c, pal(RUST, 2), 0.45);
		}
	} else if (g == G_NEEDLES) {
		float s = p.x * 0.3 + p.y * 0.18 + vnoise(p * 0.07, 131) * 7.0;
		float st = fract(s * 2.6);
		if (st < 0.1) {
			c = upc(c, 0.4);
		} else if (st > 0.5 && st < 0.58) {
			c = dn(c, 0.55);
		}
		float nh = hash(ivec2(floor(p * 6.0)), 132);
		if (nh > 0.975) {
			c = pal(EARTH, 3);
		} else if (nh < 0.03) {
			c = dn(c, 0.9);
		}
	} else if (g == G_MOSS) {
		vec3 v = voronoi(p * 0.85, 141);
		if (v.x < 0.3) {
			c = mix(upc(c, 0.35), pal(SPRUCE, 3), 0.25);
		} else if (v.x > 0.62) {
			c = dn(c, 0.7);
		}
		if (v.x < 0.25 && v.z > 0.72) {
			c = mix(c, pal(RUST, 2), 0.5);
		}
		if (v.x > 0.76 && v.z < 0.3) {
			c = v.x > 0.8 ? pal(BRINE, 0) : pal(SPRUCE, 2);
		}
		if (hash(ivec2(floor(p * 7.0)), 142) > 0.988) {
			c = pal(LINEN, 4);
		}
	} else if (g == G_PEAT) {
		float cut = fract(p.y * 1.6 + vnoise(p * 0.3, 151) * 0.8);
		if (cut < 0.08) {
			c = dn(c, 0.8);
		} else if (cut < 0.14) {
			c = upc(c, 0.25);
		}
		if (vnoise(p * 0.9, 152) > 0.76) {
			c = mix(c, pal(BRINE, 0), 0.5);
		}
	} else if (g == G_MUD) {
		float pu = vnoise(p * 0.55, 161) + vnoise(p * 1.7, 162) * 0.25;
		if (pu > 0.86) {
			c = pal(BRINE, 2);
		} else if (pu > 0.8) {
			c = dn(c, 0.6);
		}
	} else if (g == G_ROCK) {
		vec3 v = voronoi(p * 1.3, 171);
		c = v.z < 0.3 ? dn(c, 0.3) : (v.z > 0.8 ? upc(c, 0.25) : c);
		if (v.y - v.x < 0.05) {
			c = dn(c, 1.0);
		}
		if (hash(ivec2(floor(p * 6.0)), 172) > 0.975) {
			c = mix(c, v.z > 0.5 ? pal(LINEN, 3) : pal(MOSS, 4), 0.7);
		}
	} else if (g == G_ROAD) {
		float rh = hash(ivec2(floor(p * 5.0)), 181);
		if (rh > 0.9) {
			c = dn(c, 0.5);
		} else if (rh < 0.05) {
			c = upc(c, 0.3);
		}
	} else if (g == G_FLOOR) {
		vec2 q = p * vec2(2.0, 2.5);
		q.x += hash(ivec2(0, int(floor(q.y))), 191);
		vec2 fq = fract(q);
		if (fq.x < 0.08 || fq.y < 0.1) {
			c = dn(c, 0.9);
		} else if (hash(ivec2(floor(q)), 192) < 0.3) {
			c = dn(c, 0.2);
		}
	}
	return c;
}

// The neighbouring country creeping in across an ecotone: its weather on this
// ground. t = 0 deep in the country .. 1 on the border.
vec3 dust(vec3 c, int g, int c2, float t, vec2 p) {
	if (t <= 0.01) {
		return c;
	}
	float m = vnoise(p * 0.42, 201) * 0.7 + vnoise(p * 1.9, 202) * 0.3;
	if (c2 == C_SNOWFIELD && g != G_SNOW && g != G_ICE) {
		float k = t * 0.62;
		if (m < k - 0.04) {
			c = pal(RIME, 5);
		} else if (m < k + 0.01) {
			c = pal(RIME, 4);
		}
	} else if (c2 == C_BURNING && g != G_ASH && g != G_CLINKER) {
		if (m < t * 0.5 - 0.02) {
			c = vnoise(p * 3.0, 203) > 0.5 ? pal(ASH, 2) : pal(ASH, 1);
		} else if (hash(ivec2(floor(p * 6.0)), 204) < t * 0.07) {
			c = pal(ASH, 0);
		}
	} else if (c2 == C_MOSS && g != G_MOSS && g != G_PEAT && g != G_MUD) {
		if (m < t * 0.14) {
			c = m < t * 0.1 ? pal(BRINE, 0) : pal(SPRUCE, 2);
		} else if (m < t * 0.45) {
			c = dn(c, 0.55);
		}
	} else if (c2 == C_BONELANDS && g != G_LIMESTONE && g != G_BONE && g != G_SCREE) {
		vec3 v = voronoi(p * 2.2, 205);
		if (v.z < t * 0.4 && v.x < 0.34) {
			c = v.y - v.x < 0.06 ? pal(LINEN, 2) : (v.z > t * 0.2 ? pal(LINEN, 4) : pal(LINEN, 3));
		}
	} else if (c2 == C_PINEWOOD && g != G_NEEDLES) {
		float s = fract((p.x * 0.3 + p.y * 0.18 + vnoise(p * 0.07, 131) * 7.0) * 2.6);
		if (m < t * 0.55 && s > 0.45 && s < 0.7) {
			c = mix(c, pal(EARTH, 1), 0.7);
		}
	} else if (c2 == C_COAST && g != G_GRASS) {
		if (hash(ivec2(floor(p * 5.0)), 206) < t * 0.18) {
			c = pal(MOSS, 3);
		}
	}
	return c;
}

vec3 terrain_top(vec2 p, inout vec3 emit) {
	ivec2 hi = ivec2(world_size) - 1;
	ivec2 ti = clamp(ivec2(floor(p)), ivec2(0), hi);
	vec2 wv = vec2(vnoise(p * 1.9, 3), vnoise(p * 1.9 + vec2(17.3, 5.1), 4)) - 0.5;
	ivec2 tw = clamp(ivec2(floor(p + wv * 0.75)), ivec2(0), hi);
	vec4 f0 = texelFetch(field_tex, ti, 0);
	vec4 fld = texelFetch(field_tex, tw, 0);
	vec4 tile = texelFetch(tile_tex, tw, 0);
	int g = int(tile.a * 255.0 + 0.5);
	// Organic edges between grounds, but never borrowed across a step or from water.
	if (abs(fld.r - f0.r) > 0.001 || is_wet(g)) {
		fld = f0;
		tile = texelFetch(tile_tex, ti, 0);
		g = int(tile.a * 255.0 + 0.5);
	}
	vec3 c = tile.rgb;
	// Large grades from world-position fields: masses stay nearly flat.
	float gr = vnoise(p / 23.0, 21) * 0.65 + vnoise(p / 9.0, 22) * 0.35;
	if (gr < 0.36) {
		c = dn(c, 0.3);
	} else if (gr > 0.66) {
		c = upc(c, 0.22);
	}
	c = paint(g, c, p, emit);
	int cc = int(fld.g * 255.0 + 0.5);
	float t = fld.b;
	c = dust(c, g, cc / 16, t, p);
	// The strand darkens where the swash reaches.
	float sd = shore_distance(p);
	if (sd > -1.2 && sd < 0.2 && !is_wet(g)) {
		if (sd > -0.16 - 0.26 * lap(p)) {
			c = dn(c, 0.55);
		}
	}
	return c;
}

vec3 cliff(vec2 p, float y, int g, vec4 data, inout vec3 emit) {
	int c = int(data.r * 8.0 + 0.5);
	int c2 = int(data.g * 8.0 + 0.5);
	float blend = data.b * 0.5;
	float top = data.a * 8.0;
	float s = p.x + p.y;
	float depth = top - y;
	int cc = hash(ivec2(int(floor(s * 1.5)), int(floor(y * 3.0))), 301) < blend ? c2 : c;
	if (g == G_SAND || g == G_SHINGLE || g == G_GRAVEL || g == G_ASH) {
		float b = floor((y + (vnoise(vec2(s * 0.8, y * 2.0), 311) - 0.5) * 0.08) / 0.09);
		vec3 base = g == G_SAND ? pal(SAND, 3) : (g == G_ASH ? pal(ASH, 1) : pal(STONE, 2));
		return mod(b, 3.0) < 1.0 ? dn(base, 0.45) : base;
	}
	if (g == G_ICE) {
		float b = fract((y + vnoise(vec2(s * 2.0, y), 312) * 0.2) / 0.2);
		return b < 0.3 ? pal(RIME, 3) : pal(RIME, 4);
	}
	if (cc == C_BONELANDS) {
		float warp = (vnoise(vec2(s * 0.35, y), 321) - 0.5) * 0.12;
		float bed = (y + warp) / 0.3;
		float bi = floor(bed);
		float bf = fract(bed);
		vec3 col = hash(ivec2(int(bi), 1), 322) < 0.5 ? pal(LINEN, 3) : pal(LINEN, 4);
		if (bf < 0.1) {
			col = pal(LINEN, 1);
		} else if (bf > 0.86) {
			col = upc(col, 0.3);
		}
		if (fract(s * 0.8 + hash(ivec2(int(bi), 2), 323) * 5.0) < 0.05) {
			col = pal(LINEN, 2);
		}
		return col;
	}
	if (cc == C_BURNING) {
		float colx = s * 3.1 + (vnoise(vec2(s * 0.5, y * 0.6), 331) - 0.5) * 0.4;
		float ci = floor(colx);
		float cf = fract(colx);
		float lift = hash(ivec2(int(ci), 0), 332) * 0.6;
		float tier = floor((y + lift) / 1.3);
		float h = hash(ivec2(int(ci), int(tier)), 333);
		vec3 col = h < 0.33 ? pal(INK, 2) : (h < 0.7 ? pal(STONE, 0) : pal(INK, 3));
		if (cf < 0.12) {
			col = upc(col, 0.55);
		} else if (cf > 0.9) {
			col = dn(col, 0.8);
			if (hash(ivec2(int(ci), int(floor(y * 5.0))), 334) > 0.9) {
				float fl = step(0.4, fract(TIME * 0.7 + h * 11.0));
				col = pal(EMBER, 3);
				emit += pal(EMBER, 3) * (0.4 + 0.6 * fl);
			}
		}
		if (fract((y + lift) / 1.3) < 0.04) {
			col = pal(INK, 1);
		}
		return col;
	}
	if (g == G_SNOW || cc == C_SNOWFIELD) {
		if (depth < 0.09 + vnoise(vec2(s * 3.0, 0.5), 341) * 0.1) {
			return pal(RIME, 5);
		}
		float bed = (y + (vnoise(vec2(s * 0.6, y), 342) - 0.5) * 0.1) / 0.2;
		vec3 col = hash(ivec2(int(floor(bed)), 4), 343) < 0.5 ? pal(SLATE, 2) : pal(RIME, 2);
		if (hash(ivec2(int(floor(s * 6.0)), 1), 344) > 0.8 && depth < 0.3 + fract(s * 13.0) * 0.6) {
			col = pal(RIME, 3);
		}
		return col;
	}
	if (cc == C_MOSS) {
		float peat = 0.32 + (vnoise(vec2(s * 1.5, 1.0), 351) - 0.5) * 0.12;
		if (depth < peat) {
			vec3 col = fract(y * 9.0 + vnoise(vec2(s * 2.0, y), 352)) < 0.35 ? pal(EARTH, 0) : pal(EARTH, 1);
			if (fract(s * 5.0 + vnoise(vec2(s, y * 3.0), 353)) < 0.06) {
				col = pal(EARTH, 2);
			}
			return col;
		}
		vec3 col = pal(SLATE, 1);
		if (hash(ivec2(int(floor(s * 5.0)), 2), 354) > 0.7 && fract(s * 5.0) < 0.35) {
			col = pal(SPRUCE, 2);
		}
		return col;
	}
	if (cc == C_PINEWOOD) {
		if (depth < 0.22 + (vnoise(vec2(s * 1.2, 2.0), 361) - 0.5) * 0.1) {
			vec3 col = pal(EARTH, 1);
			if (fract(s * 4.0 + vnoise(vec2(s * 0.5, y * 4.0), 362) * 0.8) < 0.07) {
				col = pal(EARTH, 3);
			}
			return col;
		}
		float bed = (y + (vnoise(vec2(s * 0.6, y), 363) - 0.5) * 0.1) / 0.18;
		float h = hash(ivec2(int(floor(bed)), 5), 364);
		vec3 col = h < 0.4 ? pal(SLATE, 1) : (h < 0.8 ? mix(pal(SLATE, 2), pal(SPRUCE, 1), 0.5) : pal(SLATE, 2));
		if (fract(bed) < 0.1) {
			col = dn(col, 0.6);
		}
		return col;
	}
	// The coast: thin slate beds, a soil line, and white streaks where birds sit.
	float bed = (y + (vnoise(vec2(s * 0.7, y * 1.5), 371) - 0.5) * 0.1) / 0.16;
	float h = hash(ivec2(int(floor(bed)), 3), 372);
	vec3 col = h < 0.35 ? pal(SLATE, 1) : (h < 0.75 ? pal(SLATE, 2) : mix(pal(SLATE, 2), pal(STONE, 2), 0.5));
	if (fract(bed) < 0.12) {
		col = dn(col, 0.6);
	}
	if (depth < 0.1) {
		col = pal(EARTH, 1);
	}
	float streak = hash(ivec2(int(floor(s * 7.0)), 9), 373);
	if (streak > 0.93 && depth < 0.25 + fract(streak * 31.0) * 0.8) {
		col = mix(col, pal(LINEN, 4), 0.6);
	}
	return col;
}

void vertex() {
	kind = int(UV.y + 0.5);
	param = UV.x;
	if (kind == 4 && UV.x > 0.0) {
		float ph = dot(VERTEX.xz, vec2(0.37, 0.23));
		float gust = 0.55 + 0.45 * sin(TIME * 0.5 + VERTEX.x * 0.045 - VERTEX.z * 0.03);
		float osc = sin(TIME * (1.7 + wind * 1.3) + ph * 2.0) * 0.65 + sin(TIME * 2.9 + ph * 3.1) * 0.35;
		float amp = (0.02 + 0.13 * wind) * gust;
		vec2 d = wind_dir * amp * (0.45 + 0.55 * osc) * UV.x;
		vec3 dv = (VIEW_MATRIX * vec4(d.x, 0.0, d.y, 0.0)).xyz;
		dv.xy = round(dv.xy / texel) * texel;
		VERTEX += (INV_VIEW_MATRIX * vec4(dv, 0.0)).xyz;
	}
	if (kind == 3 && UV.x >= 5.0 && UV.x < 10.0) {
		// Flames lick: a stepped sideways and upward jitter, eight times a second.
		float t = floor(TIME * 8.0);
		float h = fract(sin(dot(VERTEX.xz, vec2(12.9898, 78.233)) + t * 0.731) * 43758.5453);
		vec3 dv = (VIEW_MATRIX * vec4((h - 0.5) * 0.06, h * 0.05, 0.0, 0.0)).xyz;
		dv.xy = round(dv.xy / texel) * texel;
		VERTEX += (INV_VIEW_MATRIX * vec4(dv, 0.0)).xyz;
	}
	world_pos = VERTEX;
	tile_pos = UV2;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 emit = vec3(0.0);
	if (kind == 1 && has_terrain) {
		c = terrain_top(tile_pos, emit);
	} else if (kind == 2 && has_terrain) {
		c = cliff(tile_pos, world_pos.y, int(param + 0.5), COLOR, emit);
	} else {
		if (has_terrain) {
			// Wading: whatever stands on a wet tile is hidden below its wade line.
			vec2 tp = world_pos.xz - tile_origin;
			ivec2 ti = clamp(ivec2(floor(tp)), ivec2(0), ivec2(world_size) - 1);
			int g = int(texelFetch(tile_tex, ti, 0).a * 255.0 + 0.5);
			if (is_wet(g) && all(greaterThanEqual(tp, vec2(0.0))) && all(lessThan(tp, world_size))) {
				float l = texelFetch(field_tex, ti, 0).r * 255.0 - 64.0;
				float wade = l <= 0.0 ? 0.3 : l * 0.5 + 0.22;
				if (world_pos.y < wade) {
					discard;
				}
			}
		}
		if (kind == 3) {
			float fl = 0.8 + 0.2 * step(0.5, fract(TIME * 1.7 + dot(world_pos.xz, vec2(3.1, 1.7))));
			float strength = param;
			if (param >= 10.0) {
				// Lamps: lit only when the sky has gone dim.
				float dim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
				strength = (param - 10.0) * clamp((0.9 - dim) * 5.0, 0.0, 1.0);
			} else if (param >= 5.0) {
				strength = param - 5.0;
			}
			emit = COLOR.rgb * strength * fl;
		} else if (kind == 5) {
			float gh = fract(dot(floor(world_pos.xz * 8.0), vec2(0.1031, 0.1373)) * 43.7);
			if (fract(TIME * 0.31 + gh * 17.0) < 0.07) {
				c = upc(c, 1.5);
			}
		}
	}
	ALBEDO = sky_apply(c, world_pos, TIME);
	EMISSION = COLOR.rgb * emission_strength + emit;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.0, ndl) * step(0.5, ATTENUATION);
		float band = ndl > 0.4 ? 1.0 : 0.88;
		vec3 k = mix(shade_tint, vec3(band), lit);
		if (kind == 1) {
			// Hillside relief: undulating ground turns a half step toward or away from the sun.
			vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
			float rel = ndl - dot(up_v, LIGHT);
			if (rel > 0.05) {
				k *= 1.07;
			} else if (rel < -0.05) {
				k *= mix(vec3(1.0), shade_tint, 0.45);
			}
		}
		DIFFUSE_LIGHT += LIGHT_COLOR * k / PI;
	} else {
		// Lamps and fire: quantised to three steps so pools of light have edges.
		float a = clamp(ATTENUATION * step(-0.2, ndl), 0.0, 1.0);
		a = floor(a * 3.0 + 0.5) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
