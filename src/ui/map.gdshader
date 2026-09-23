// The survey: explored land as the slate's scanner draws it, in phosphor on
// the glass (docs/LOOK.md). Every value is computed per MAP pixel from integer
// coordinates, so the survey is crisp at any whole scale and its texture belongs
// to the land, moving with it when the map is panned.
//   sea      the glass itself; depth bands as dotted soundings, two ripple lines
//            hugging the shore, a few wave ticks far out
//   land     a dim fill stepped by the ground's value; each country's own hatch
//            hand laid faintly (heavier where the ground turns from the light);
//            a contour at every level, an index contour at every second, cliffs
//            and the coast in the brightest tone
//   marks    trees, rocks, reeds, houses and stations as tiny symbols; ruins,
//            wrecks, tips and pylons in the machines' violet
//   unseen   THE SHAPE ONLY: the same land fill stepped by the ground's value,
//            dimmed to UNSEEN_LIGHT, with no contour, hatch, road, symbol,
//            sounding or name. Owner's ruling, 2026-09-19: he should be able to
//            zoom out and see the ENTIRE map, because walking does not buy a
//            tile's EXISTENCE, it buys its DETAIL. It was bare glass, which drew
//            a 1300-tile world as an empty field with a smear on it -- after a
//            long walk the survey still reported 0.3% seen. Inland water stays
//            glass so a lake reads as a hole and not as land.
//            The edge of what is KNOWN still breaks up in a scan dither.
// Tones come in as uniforms from UiTheme so the slate's colours live in one place.
shader_type canvas_item;
render_mode unshaded;

#include "res://src/render/ink.gdshaderinc"

uniform sampler2D ground_tex : filter_nearest;
uniform sampler2D level_tex : filter_nearest;
uniform sampler2D coast_tex : filter_nearest;
uniform sampler2D marks_tex : filter_nearest;
uniform sampler2D seen_tex : filter_nearest;
uniform sampler2D palette_tex : filter_nearest;
uniform sampler2D country_tex : filter_nearest;
uniform vec2 rect_size = vec2(580.0, 290.0);
// Map pixel (in tile * scale units) at the rect's top-left pixel.
uniform vec2 origin_px = vec2(0.0);
uniform float scale = 2.0;
uniform float world_size = 256.0;
// World tiles to one texel. The survey's textures are capped at UiMapData.MOST a
// side so their build cost does not follow the world's size, so a WORLD tile and
// a TEXEL stopped being the same thing. Every fetch below that reads the world's
// own textures divides by it; `seen_tex` does NOT, because the explored mask is
// a straight copy of the player's own grid and is cheap at any size.
uniform float tex_step = 1.0;

// How much of the land's lit fill an UNSURVEYED tile keeps. Low enough that the
// eye reads the surveyed country as the subject and the rest as the shape it
// sits in; high enough that five continents read as five continents on the
// first frame the map is ever opened.
const float UNSEEN_LIGHT = 0.42;

ivec2 texel(ivec2 t) {
	return t / int(tex_step);
}

uniform vec3 glass = vec3(0.043, 0.075, 0.082);
uniform vec3 ph0 = vec3(0.09, 0.188, 0.161);
uniform vec3 ph1 = vec3(0.169, 0.361, 0.298);
uniform vec3 ph2 = vec3(0.31, 0.608, 0.506);
uniform vec3 ph3 = vec3(0.529, 0.851, 0.71);
uniform vec3 ph4 = vec3(0.788, 0.984, 0.886);
uniform vec3 violet = vec3(0.486, 0.439, 0.714);

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

ivec2 clamp_tile(ivec2 t) {
	return clamp(t, ivec2(0), ivec2(int(world_size) - 1));
}

bool inside(ivec2 t) {
	return t.x >= 0 && t.y >= 0 && t.x < int(world_size) && t.y < int(world_size);
}

int level_at(ivec2 t) {
	if (!inside(t)) return -3;
	int v = int(texelFetch(level_tex, texel(t), 0).r * 255.0 + 0.5);
	return v > 127 ? v - 256 : v;
}

int ground_at(ivec2 t) {
	return int(texelFetch(ground_tex, texel(clamp_tile(t)), 0).r * 255.0 + 0.5);
}

int mark_at(ivec2 t) {
	if (!inside(t)) return 0;
	return int(texelFetch(marks_tex, texel(t), 0).r * 255.0 + 0.5);
}

float coast_at(ivec2 t) {
	if (!inside(t)) return 16.0;
	return texelFetch(coast_tex, texel(t), 0).r * 255.0 / 16.0;
}

float seen_raw(ivec2 t) {
	if (!inside(t)) return 0.0;
	return texelFetch(seen_tex, t, 0).r;
}

float seen_smooth(vec2 tp) {
	vec2 q = tp - 0.5;
	ivec2 b = ivec2(floor(q));
	vec2 f = q - vec2(b);
	float a = seen_raw(b), c = seen_raw(b + ivec2(1, 0));
	float d = seen_raw(b + ivec2(0, 1)), e = seen_raw(b + ivec2(1, 1));
	return mix(mix(a, c, f.x), mix(d, e, f.x), f.y);
}

// Distance across the shore, signed: positive on land, negative at sea.
float shore_at(ivec2 t) {
	float d = coast_at(t);
	return level_at(t) > 0 ? d : -d;
}

float shore_smooth(vec2 tp) {
	vec2 q = tp - 0.5;
	ivec2 b = ivec2(floor(q));
	vec2 f = q - vec2(b);
	float a = shore_at(b), c = shore_at(b + ivec2(1, 0));
	float d = shore_at(b + ivec2(0, 1)), e = shore_at(b + ivec2(1, 1));
	return mix(mix(a, c, f.x), mix(d, e, f.x), f.y);
}

float level_smooth(vec2 tp) {
	vec2 q = tp - 0.5;
	ivec2 b = ivec2(floor(q));
	vec2 f = q - vec2(b);
	float a = float(max(level_at(b), 0)), c = float(max(level_at(b + ivec2(1, 0)), 0));
	float d = float(max(level_at(b + ivec2(0, 1)), 0)), e = float(max(level_at(b + ivec2(1, 1)), 0));
	return mix(mix(a, c, f.x), mix(d, e, f.x), f.y);
}

float level_soft(vec2 tp) {
	return (level_smooth(tp) * 2.0 + level_smooth(tp + vec2(0.75, 0.75)) + level_smooth(tp + vec2(-0.75, 0.75))
		+ level_smooth(tp + vec2(0.75, -0.75)) + level_smooth(tp + vec2(-0.75, -0.75))) / 6.0;
}

// Tile fields are integer steps; drawn straight they are a staircase, which is
// the tile grid on the glass. Five bilinear taps round every step into a curve.
float shore_soft(vec2 tp) {
	return (shore_smooth(tp) * 2.0 + shore_smooth(tp + vec2(0.75, 0.75)) + shore_smooth(tp + vec2(-0.75, 0.75))
		+ shore_smooth(tp + vec2(0.75, -0.75)) + shore_smooth(tp + vec2(-0.75, -0.75))) / 6.0;
}

// The tile whose ground shows at a point, jittered so grounds meet on ragged edges.
ivec2 ground_tile(vec2 mp, vec2 tp) {
	vec2 slow = vec2(ink_vnoise(tp * 0.8), ink_vnoise(tp * 0.8 + vec2(19.0, 7.0))) - 0.5;
	vec2 fringe = vec2(hash(mp), hash(mp + vec2(3.3, 8.1))) - 0.5;
	return ivec2(floor(tp + slow * 1.6 + fringe * 0.7));
}

// The land's elevation in levels, the way the terrain mesher builds it.
float land_field(vec2 tp) {
	float v = level_soft(tp);
	vec2 q = tp - 0.5;
	ivec2 b = ivec2(floor(q));
	int lo = min(min(level_at(b), level_at(b + ivec2(1, 0))), min(level_at(b + ivec2(0, 1)), level_at(b + ivec2(1, 1))));
	int hi = max(max(level_at(b), level_at(b + ivec2(1, 0))), max(level_at(b + ivec2(0, 1)), level_at(b + ivec2(1, 1))));
	if (hi != lo) {
		v += (ink_vnoise(tp * 1.15) - 0.5) * 0.64;
	}
	return v;
}

// The country's hatch hand at a tile, dithered across an ecotone as the world does.
int hand_at(ivec2 t, vec2 mp) {
	vec4 c = texelFetch(country_tex, texel(clamp_tile(t)), 0);
	int c1 = int(c.r * 255.0 + 0.5);
	int c2 = int(c.g * 255.0 + 0.5);
	return ink_hash(mp + vec2(17.0, 91.0)) < c.b ? c2 : c1;
}

bool is_inland_water(int g) {
	return g == 1 || g == 20 || g == 22; // WATER, BLACKWATER, RIVER
}

int sea_band(float d) {
	return d < 2.6 ? 0 : (d < 7.0 ? 1 : 2);
}

// 5x5 symbols: bit (row * 5 + column), row 0 at the top.
bool glyph(int m, ivec2 l) {
	if (l.x < 0 || l.y < 0 || l.x > 4 || l.y > 4) return false;
	int bits = 0;
	if (m == 1) bits = 4 | 14 << 5 | 31 << 10 | 4 << 15; // conifer
	else if (m == 2) bits = 14 | 31 << 5 | 14 << 10 | 4 << 15; // round tree
	else if (m == 3) bits = 6 << 5 | 15 << 10; // rock
	else if (m == 4) bits = 5 | 21 << 5 | 21 << 10; // reeds
	else if (m == 5) bits = 4 | 14 << 5 | 31 << 10 | 14 << 15 | 14 << 20; // house
	else if (m == 6) bits = 4 | 10 << 5 | 14 << 10; // fire, bench, kiln
	else if (m == 7) bits = 17 | 10 << 5 | 4 << 10 | 10 << 15 | 17 << 20; // ruin, wreck, tip, pylon
	return ((bits >> (l.y * 5 + l.x)) & 1) == 1;
}

vec3 mark_colour(int m) {
	if (m == 7) return violet;
	if (m == 5 || m == 6) return ph4;
	if (m == 3) return ph2;
	return ph2;
}

void fragment() {
	vec2 pix = floor(UV * rect_size);
	vec2 mp = pix + origin_px; // map pixel
	vec2 tp = (mp + 0.5) / scale; // tile-space point
	vec3 col = glass;
	float alpha = 0.0;

	float seen = seen_smooth(tp);
	float edge_noise = hash(floor(mp / 2.0) * 1.37) * 0.45 + hash(mp) * 0.15;
	float known = step(0.28 + edge_noise, seen);

	if (known > 0.5) {
		alpha = 1.0;
		float shore = shore_soft(tp);
		float lv = land_field(tp);
		bool land = lv >= 0.5;
		if (!land) {
			float d = max(-shore, 0.0);
			int band = sea_band(d);
			col = glass;
			// Each depth band's edge as a line of soundings: dotted.
			float dr = -shore_soft((mp + vec2(1.0, 0.0) + 0.5) / scale);
			float db = -shore_soft((mp + vec2(0.0, 1.0) + 0.5) / scale);
			if (band > 0 && (sea_band(dr) != band || sea_band(db) != band) && mod(mp.x + mp.y, 3.0) < 1.0) {
				col = ph1;
			}
			// Two ripple lines hugging the shore, the outer one broken.
			float px_w = 0.75 / scale;
			for (int k = 0; k < 2; k++) {
				float at = 0.7 + float(k) * 0.9;
				if (abs(d - at) < px_w && hash(floor(mp / (3.0 + float(k) * 2.0))) > 0.12 + float(k) * 0.25) {
					col = k == 0 ? ph2 : ph1;
				}
			}
			// Wave ticks well out: a short dash in some cells of a loose grid.
			if (band == 2) {
				vec2 cell = floor(mp / vec2(11.0, 7.0));
				vec2 o = floor(vec2(hash(cell + 1.3), hash(cell + 5.1)) * vec2(7.0, 5.0));
				vec2 l = mp - cell * vec2(11.0, 7.0) - o;
				if (hash(cell + 9.7) < 0.3 && l.y == 0.0 && l.x >= 0.0 && l.x < 3.0) {
					col = ph0;
				}
			}
		} else {
			ivec2 gt = ground_tile(mp, tp);
			int g = ground_at(gt);
			vec3 wash = texelFetch(palette_tex, ivec2(g, 0), 0).rgb;
			// The ground's value picks how lit the land's fill is, through an ordered dither.
			float value = dot(wash, vec3(0.3, 0.55, 0.15));
			float bayer = mod(mp.x, 2.0) * 0.5 + mod(mp.y, 2.0) * 0.25 + mod(mp.x + mp.y, 2.0) * 0.125;
			col = (value * 1.3 > 0.35 + bayer * 0.5) ? mix(ph0, ph1, 0.35) : ph0;
			float lr = land_field((mp + vec2(1.0, 0.0) + 0.5) / scale);
			float lb = land_field((mp + vec2(0.0, 1.0) + 0.5) / scale);
			float ll = land_field((mp + vec2(-1.0, 0.0) + 0.5) / scale);
			float lt = land_field((mp + vec2(0.0, -1.0) + 0.5) / scale);
			if (is_inland_water(g)) {
				col = glass;
				int gr = ground_at(ground_tile(mp + vec2(1.0, 0.0), (mp + vec2(1.5, 0.5)) / scale));
				int gb = ground_at(ground_tile(mp + vec2(0.0, 1.0), (mp + vec2(0.5, 1.5)) / scale));
				if (!is_inland_water(gr) || !is_inland_water(gb)) {
					col = ph2;
				}
			} else {
				// The country's hand: faint on all its land, heavier where the ground
				// turns away from the light (north-west).
				float slope = level_soft(tp + vec2(-0.8, -0.8)) - level_soft(tp + vec2(0.8, 0.8));
				float depth = clamp(slope * 0.45, 0.0, 1.0);
				float ink = hatch(hand_at(gt, mp), mp, depth);
				if (ink > 0.5 && (depth > 0.2 || hash(mp * 0.71) < 0.5)) {
					col = ph1;
				}
				if (g == 11 && mod(mp.x + mp.y, 4.0) < 2.0) {
					// Roads: a dashed trace.
					col = ph2;
				}
			}
			float steep = (abs(lr - lv) + abs(lb - lv)) * scale;
			float tv = floor(lv + 0.5);
			if (lr < 0.5 || lb < 0.5 || ll < 0.5 || lt < 0.5) {
				col = ph3;
			} else if (steep > 1.4 && (tv != floor(lr + 0.5) || tv != floor(lb + 0.5))) {
				col = ph3;
			} else if (floor((lv + 0.5) / 2.0) != floor((lr + 0.5) / 2.0) || floor((lv + 0.5) / 2.0) != floor((lb + 0.5) / 2.0)) {
				// An index contour every second terrace.
				col = ph2;
			} else if (tv != floor(lr + 0.5) || tv != floor(lb + 0.5)) {
				// A contour at every terrace, dotted so hills read without clutter.
				col = mod(mp.x + mp.y, 2.0) < 1.0 ? ph1 : col;
			}
		}
		// Symbols on a 6 px grid, each nudged a pixel.
		vec2 cell = floor(mp / 6.0);
		vec2 jit = floor(vec2(hash(cell + 3.1), hash(cell + 7.7)) * 2.0);
		ivec2 local = ivec2(mp - cell * 6.0 - jit);
		ivec2 ct = ivec2(floor((cell * 6.0 + 3.0) / scale));
		int m = mark_at(ct);
		if (m == 8) {
			int n = max(max(mark_at(ct + ivec2(1, 0)), mark_at(ct + ivec2(-1, 0))), max(mark_at(ct + ivec2(0, 1)), mark_at(ct + ivec2(0, -1))));
			m = (n == 1 || n == 2) ? n : 0;
		}
		if (m > 0 && land && glyph(m, local)) {
			col = mark_colour(m);
		}
		// Near the edge of what is known, the scan breaks up into the glass.
		float fade = clamp((seen - 0.28 - edge_noise) * 4.0, 0.0, 1.0);
		if (fade < 0.99 && hash(mp * 1.13) > fade + 0.25) {
			col = mix(glass, col, 0.45);
		}
		// The scanner's rows: every other map row a touch dimmer.
		if (mod(pix.y, 2.0) > 0.5) {
			col = mix(col, glass, 0.12);
		}
	} else {
		// UNSEEN: the world's SHAPE, and nothing that walking is supposed to buy.
		// Deliberately the same fill expression as the known branch above, at
		// UNSEEN_LIGHT, so a surveyed country and its unsurveyed continuation are
		// the same land in two states rather than two different drawings meeting
		// at a line.
		float lv = land_field(tp);
		if (lv >= 0.5) {
			ivec2 gt = ground_tile(mp, tp);
			int g = ground_at(gt);
			if (!is_inland_water(g)) {
				alpha = 1.0;
				vec3 wash = texelFetch(palette_tex, ivec2(g, 0), 0).rgb;
				float value = dot(wash, vec3(0.3, 0.55, 0.15));
				float bayer = mod(mp.x, 2.0) * 0.5 + mod(mp.y, 2.0) * 0.25 + mod(mp.x + mp.y, 2.0) * 0.125;
				col = (value * 1.3 > 0.35 + bayer * 0.5) ? mix(ph0, ph1, 0.35) : ph0;
				col = mix(glass, col, UNSEEN_LIGHT);
				if (mod(pix.y, 2.0) > 0.5) {
					col = mix(col, glass, 0.12);
				}
			}
		}
	}
	COLOR = vec4(col, alpha);
}
