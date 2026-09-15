// The notebook map: explored land inked and washed onto the page, in the same
// hands the world is drawn in (docs/ART.md). Every value is computed per MAP
// pixel from integer coordinates, so the map is crisp at any whole scale and
// its hatching belongs to the land, moving with it when the map is panned.
//   sea      a chart: depth bands washed paler to darker, each band edge inked,
//            ripple lines hugging the shore, a few wave ticks far out
//   land     ground wash thinned toward the paper; each country's own hatch hand
//            laid lightly over it and heavily on slopes turned from the light;
//            a contour every second level, heavier at cliffs; coast in ink
//   marks    little drawn trees, rocks, reeds, houses, on a hand-jittered grid
//   unseen   bare paper; the edge of the known is a ragged pencil fade
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

const vec3 PAPER = vec3(0.9098, 0.8627, 0.7529);
const vec3 INK = vec3(0.0706, 0.0667, 0.1137);
const vec3 SEPIA = vec3(0.3098, 0.2118, 0.1529);
const vec3 BRINE = vec3(0.1686, 0.3882, 0.5373);
const vec3 BRINE_PALE = vec3(0.2627, 0.5725, 0.6902);
const vec3 GREEN_INK = vec3(0.1137, 0.2353, 0.2549);
const vec3 HATCH_INK = vec3(0.1843, 0.1725, 0.2706);

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
	int v = int(texelFetch(level_tex, t, 0).r * 255.0 + 0.5);
	return v > 127 ? v - 256 : v;
}

int ground_at(ivec2 t) {
	return int(texelFetch(ground_tex, clamp_tile(t), 0).r * 255.0 + 0.5);
}

int mark_at(ivec2 t) {
	if (!inside(t)) return 0;
	return int(texelFetch(marks_tex, t, 0).r * 255.0 + 0.5);
}

float coast_at(ivec2 t) {
	if (!inside(t)) return 16.0;
	return texelFetch(coast_tex, t, 0).r * 255.0 / 16.0;
}

float seen_raw(ivec2 t) {
	if (!inside(t)) return 0.0;
	return texelFetch(seen_tex, t, 0).r;
}

// Bilinear over tile centres, done by hand so textures stay nearest.
float coast_smooth(vec2 tp) {
	vec2 q = tp - 0.5;
	ivec2 b = ivec2(floor(q));
	vec2 f = q - vec2(b);
	float a = coast_at(b), c = coast_at(b + ivec2(1, 0));
	float d = coast_at(b + ivec2(0, 1)), e = coast_at(b + ivec2(1, 1));
	return mix(mix(a, c, f.x), mix(d, e, f.x), f.y);
}

float seen_smooth(vec2 tp) {
	vec2 q = tp - 0.5;
	ivec2 b = ivec2(floor(q));
	vec2 f = q - vec2(b);
	float a = seen_raw(b), c = seen_raw(b + ivec2(1, 0));
	float d = seen_raw(b + ivec2(0, 1)), e = seen_raw(b + ivec2(1, 1));
	return mix(mix(a, c, f.x), mix(d, e, f.x), f.y);
}

// Distance across the shore, signed: positive on land, negative at sea. Its zero
// crossing, interpolated, is a coast that curves instead of stepping by tiles.
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
// the tile grid on the page. Five bilinear taps a tile apart round every step
// into a curve before a line is drawn along it.
float shore_soft(vec2 tp) {
	return (shore_smooth(tp) * 2.0 + shore_smooth(tp + vec2(0.75, 0.75)) + shore_smooth(tp + vec2(-0.75, 0.75))
		+ shore_smooth(tp + vec2(0.75, -0.75)) + shore_smooth(tp + vec2(-0.75, -0.75))) / 6.0;
}

// The tile whose ground shows at a point: jittered by slow noise so grounds
// meet on ragged, wandering edges rather than along the tile grid.
ivec2 ground_tile(vec2 mp, vec2 tp) {
	vec2 slow = vec2(ink_vnoise(tp * 0.8), ink_vnoise(tp * 0.8 + vec2(19.0, 7.0))) - 0.5;
	vec2 fringe = vec2(hash(mp), hash(mp + vec2(3.3, 8.1))) - 0.5;
	return ivec2(floor(tp + slow * 1.6 + fringe * 0.7));
}

// The land's elevation in levels, the way the terrain mesher builds it: tile
// levels between tile centres, softened, and warped a little where the height
// changes, so the map's contours are the world's terrace edges.
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
	vec4 c = texelFetch(country_tex, clamp_tile(t), 0);
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
	else if (m == 7) bits = 17 | 10 << 5 | 4 << 10 | 10 << 15 | 17 << 20; // ruin, wreck
	return ((bits >> (l.y * 5 + l.x)) & 1) == 1;
}

vec3 mark_colour(int m) {
	if (m == 1 || m == 2 || m == 8) return GREEN_INK;
	if (m == 5 || m == 7) return INK;
	if (m == 6) return vec3(0.6039, 0.3098, 0.1569);
	return SEPIA;
}

void fragment() {
	vec2 pix = floor(UV * rect_size);
	vec2 mp = pix + origin_px; // map pixel
	vec2 tp = (mp + 0.5) / scale; // tile-space point
	ivec2 t = ivec2(floor(tp));
	vec3 col = PAPER;
	float alpha = 0.0;

	float seen = seen_smooth(tp);
	float edge_noise = hash(floor(mp / 2.0) * 1.37) * 0.45 + hash(mp) * 0.15;
	float known = step(0.28 + edge_noise, seen);

	if (known > 0.5) {
		alpha = 1.0;
		float shore = shore_soft(tp);
		float lv = land_field(tp);
		// Terrace 1 and up is land, as in the world.
		bool land = lv >= 0.5;
		if (!land) {
			float d = max(-shore, 0.0);
			int band = sea_band(d);
			col = mix(PAPER, BRINE_PALE, 0.13 + 0.09 * float(band));
			// Each depth band's edge inked, the way a chart draws soundings.
			float dr = -shore_soft((mp + vec2(1.0, 0.0) + 0.5) / scale);
			float db = -shore_soft((mp + vec2(0.0, 1.0) + 0.5) / scale);
			if (band > 0 && (sea_band(dr) != band || sea_band(db) != band)) {
				col = mix(col, BRINE, 0.42);
			}
			// Two ripple lines hugging the shore, the outer one broken.
			float px_w = 0.75 / scale;
			for (int k = 0; k < 2; k++) {
				float at = 0.7 + float(k) * 0.9;
				if (abs(d - at) < px_w && hash(floor(mp / (3.0 + float(k) * 2.0))) > 0.12 + float(k) * 0.25) {
					col = mix(col, BRINE, 0.6 - float(k) * 0.2);
				}
			}
			// Wave ticks well out: a short dash in some cells of a loose grid.
			if (band == 2) {
				vec2 cell = floor(mp / vec2(11.0, 7.0));
				vec2 o = floor(vec2(hash(cell + 1.3), hash(cell + 5.1)) * vec2(7.0, 5.0));
				vec2 l = mp - cell * vec2(11.0, 7.0) - o;
				if (hash(cell + 9.7) < 0.3 && l.y == 0.0 && l.x >= 0.0 && l.x < 3.0) {
					col = mix(col, BRINE, 0.5);
				}
			}
		} else {
			ivec2 gt = ground_tile(mp, tp);
			int g = ground_at(gt);
			vec3 wash = texelFetch(palette_tex, ivec2(g, 0), 0).rgb;
			col = mix(PAPER, wash, 0.5);
			float lr = land_field((mp + vec2(1.0, 0.0) + 0.5) / scale);
			float lb = land_field((mp + vec2(0.0, 1.0) + 0.5) / scale);
			float ll = land_field((mp + vec2(-1.0, 0.0) + 0.5) / scale);
			float lt = land_field((mp + vec2(0.0, -1.0) + 0.5) / scale);
			if (is_inland_water(g)) {
				col = mix(PAPER, BRINE_PALE, 0.42);
				int gr = ground_at(ground_tile(mp + vec2(1.0, 0.0), (mp + vec2(1.5, 0.5)) / scale));
				int gb = ground_at(ground_tile(mp + vec2(0.0, 1.0), (mp + vec2(0.5, 1.5)) / scale));
				if (!is_inland_water(gr) || !is_inland_water(gb)) {
					col = mix(col, BRINE, 0.75);
				}
			} else {
				// The country's hand: laid faintly on all its land, and heavily where
				// the ground turns away from the light (north-west).
				float slope = level_soft(tp + vec2(-0.8, -0.8)) - level_soft(tp + vec2(0.8, 0.8));
				float depth = clamp(slope * 0.45, 0.0, 1.0);
				float ink = hatch(hand_at(gt, mp), mp, depth);
				if (ink > 0.5) {
					col = mix(col, HATCH_INK, depth > 0.2 ? 0.28 + 0.3 * depth : 0.1);
				}
				if (g == 11 && mod(mp.x + mp.y, 4.0) < 2.0) {
					// Roads: a dashed pen line.
					col = mix(col, SEPIA, 0.55);
				}
			}
			float steep = (abs(lr - lv) + abs(lb - lv)) * scale;
			float tv = floor(lv + 0.5);
			if (lr < 0.5 || lb < 0.5 || ll < 0.5 || lt < 0.5) {
				col = INK;
			} else if (steep > 1.4 && (tv != floor(lr + 0.5) || tv != floor(lb + 0.5))) {
				// A cliff: a hard ink line.
				col = mix(col, INK, 0.78);
			} else if (floor((lv + 0.5) / 2.0) != floor((lr + 0.5) / 2.0) || floor((lv + 0.5) / 2.0) != floor((lb + 0.5) / 2.0)) {
				// A contour every second terrace, in brown ink, so hills read without clutter.
				col = mix(col, SEPIA, 0.38);
			}
		}
		// Symbols on a 6 px grid, each nudged by hand.
		vec2 cell = floor(mp / 6.0);
		vec2 jit = floor(vec2(hash(cell + 3.1), hash(cell + 7.7)) * 2.0);
		ivec2 local = ivec2(mp - cell * 6.0 - jit);
		ivec2 ct = ivec2(floor((cell * 6.0 + 3.0) / scale));
		int m = mark_at(ct);
		if (m == 8) {
			// Beside a tree: draw the kind of tree that is there.
			int n = max(max(mark_at(ct + ivec2(1, 0)), mark_at(ct + ivec2(-1, 0))), max(mark_at(ct + ivec2(0, 1)), mark_at(ct + ivec2(0, -1))));
			m = (n == 1 || n == 2) ? n : 0;
		}
		if (m > 0 && land && glyph(m, local)) {
			col = mix(col, mark_colour(m), m == 5 ? 0.95 : 0.75);
		}
		// Near the edge of what is known, the wash thins into the page.
		alpha = clamp((seen - 0.28 - edge_noise) * 4.0, 0.4, 1.0);
		// Paper grain through the wash, locked to the page, not the map.
		col *= 0.985 + 0.02 * hash(floor(FRAGCOORD.xy));
	}
	COLOR = vec4(col, alpha);
}
