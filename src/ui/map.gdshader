// The notebook map: explored land painted in ink and wash on the page.
// Every value is computed per SCREEN pixel from integer coordinates, so the map
// is crisp at any whole-number scale and pans a pixel at a time.
//   sea      pale brine wash; ripple lines that follow the shore outward
//   land     ground colour thinned toward the paper; contour at every level
//            change, heavier at cliffs; coast line in ink
//   marks    little drawn trees, rocks, reeds, houses, on a hand-jittered grid
//   unseen   bare paper; the edge of the known is a ragged pencil fade
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ground_tex : filter_nearest;
uniform sampler2D level_tex : filter_nearest;
uniform sampler2D coast_tex : filter_nearest;
uniform sampler2D marks_tex : filter_nearest;
uniform sampler2D seen_tex : filter_nearest;
uniform sampler2D palette_tex : filter_nearest;
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

bool is_inland_water(int g) {
	return g == 1 || g == 20 || g == 22; // WATER, BLACKWATER, RIVER
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

	float seen = seen_smooth(tp);
	float edge_noise = hash(floor(mp / 2.0) * 1.37) * 0.45 + hash(mp) * 0.15;
	float known = step(0.28 + edge_noise, seen);

	if (known > 0.5) {
		int lv = level_at(t);
		int g = ground_at(t);
		ivec2 tr = ivec2(floor((mp + vec2(1.0, 0.0) + 0.5) / scale));
		ivec2 tb = ivec2(floor((mp + vec2(0.0, 1.0) + 0.5) / scale));
		ivec2 tl = ivec2(floor((mp + vec2(-1.0, 0.0) + 0.5) / scale));
		ivec2 tt = ivec2(floor((mp + vec2(0.0, -1.0) + 0.5) / scale));
		if (lv <= 0) {
			float d = coast_smooth(tp);
			col = mix(PAPER, BRINE_PALE, 0.16 + 0.14 * clamp(d / 12.0, 0.0, 1.0));
			// Ripple lines hugging the shore, thinning and fading outward.
			float px_w = 0.75 / scale;
			for (int k = 0; k < 4; k++) {
				float at = 1.1 + float(k) * (1.4 + float(k) * 0.55);
				if (abs(d - at) < px_w) {
					float a = 0.55 - float(k) * 0.12;
					// Broken strokes, the way a pen skips.
					if (hash(floor(mp / (4.0 + float(k)))) > 0.18 + float(k) * 0.1) {
						col = mix(col, BRINE, a);
					}
				}
			}
		} else {
			vec3 wash = texelFetch(palette_tex, ivec2(g, 0), 0).rgb;
			col = mix(PAPER, wash, 0.52);
			// Height as a soft darkening, so hills read before the contours do.
			col *= 1.0 - float(clamp(lv - 1, 0, 12)) * 0.012;
			if (is_inland_water(g)) {
				col = mix(PAPER, BRINE_PALE, 0.42);
			}
			int lr = level_at(tr);
			int lb = level_at(tb);
			int step_r = lv - lr;
			int step_b = lv - lb;
			bool sea_next = lr <= 0 || lb <= 0 || level_at(tl) <= 0 || level_at(tt) <= 0;
			if (sea_next) {
				col = INK;
			} else if (step_r != 0 || step_b != 0) {
				int big = max(abs(step_r), abs(step_b));
				col = mix(col, big >= 2 ? INK : SEPIA, big >= 2 ? 0.8 : 0.42);
			} else if (is_inland_water(g) && (!is_inland_water(ground_at(tr)) || !is_inland_water(ground_at(tb)) || !is_inland_water(ground_at(tl)) || !is_inland_water(ground_at(tt)))) {
				col = mix(col, BRINE, 0.75);
			} else if (g == 11) {
				// Roads: a dashed pen line.
				if (mod(mp.x + mp.y, 4.0) < 2.0) col = mix(col, SEPIA, 0.55);
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
		if (m > 0 && level_at(ct) > 0 && glyph(m, local)) {
			col = mix(col, mark_colour(m), m == 5 ? 0.95 : 0.75);
		}
		// Near the edge of what is known, the wash thins toward the paper.
		col = mix(PAPER, col, clamp((seen - 0.28 - edge_noise) * 4.0, 0.35, 1.0));
	}
	// Paper grain over everything, locked to the page, not the map.
	float grain = hash(floor(FRAGCOORD.xy));
	col *= 0.985 + 0.02 * grain;
	COLOR = vec4(col, 1.0);
}
