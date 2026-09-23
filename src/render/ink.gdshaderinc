// The ink: hatching, stipple and paper, shared by every lit shader.
// See docs/LOOK.md. Patterns are in SCREEN PIXELS of the 640x360 image but
// anchored to the WORLD through `world_px` (set every frame by CameraRig), so a
// hatch line belongs to the ground it is drawn on and never swims.
//
// Hatch styles (stored per vertex in UV.x as style1 + style2 * 16):
//   0 NONE      water, FOUND things, UI
//   1 WIND      coast: long shallow diagonals, like weather across turf
//   2 STIPPLE   moss: dots, denser in deep shade
//   3 UPRIGHT   pinewood: vertical strokes
//   4 SPARSE    snowfield: few long diagonals; the page does the work
//   5 CROSS     bonelands: cross-hatch
//   6 SCRIBBLE  burning: broken, restless diagonals
//   7 HAND      made things: short back-diagonals, a little uneven
//   8 CONTOUR   rock and cliff faces: horizontal strata strokes
//   9 CRACK     salt flats: long dry strokes that run and stop, never a net

global uniform vec2 world_px;

float ink_hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

// px: world-anchored integer pixel. depth: 0 = light shade, 1 = deep shade.
// Returns 1 where ink is laid, 0 where the page shows.
float hatch(int style, vec2 px, float depth) {
	float x = px.x;
	float y = px.y;
	if (style == 1) {
		float a = mod(x + 3.0 * y, 9.0) < 1.0 ? 1.0 : 0.0;
		float b = mod(x - 3.0 * y, 9.0) < 1.0 ? 1.0 : 0.0;
		return max(a, b * step(0.6, depth));
	}
	if (style == 2) {
		float h = ink_hash(floor(px));
		return step(h, 0.10 + 0.22 * depth) * step(0.5, mod(x + y, 2.0));
	}
	if (style == 3) {
		float v = mod(x, 3.0) < 1.0 ? 1.0 : 0.0;
		float broken = step(0.18, ink_hash(vec2(floor(x / 3.0), floor(y / 5.0))));
		return v * broken * step(0.25, depth + 0.3);
	}
	if (style == 4) {
		return mod(x + 2.0 * y, 11.0) < 1.0 ? step(0.35, depth + 0.2) : 0.0;
	}
	if (style == 5) {
		float a = mod(x + y, 4.0) < 1.0 ? 1.0 : 0.0;
		float b = mod(x - y, 4.0) < 1.0 ? 1.0 : 0.0;
		return max(a, b * step(0.5, depth));
	}
	if (style == 6) {
		float seg = step(0.35, ink_hash(vec2(floor((x + y) / 4.0), floor((x - y) / 6.0))));
		float a = mod(x + y + floor(ink_hash(vec2(floor(y / 3.0), 7.0)) * 3.0), 3.0) < 1.0 ? 1.0 : 0.0;
		return a * seg;
	}
	if (style == 7) {
		float a = mod(x - y, 4.0) < 1.0 ? 1.0 : 0.0;
		float gap = step(0.2, ink_hash(vec2(floor((x + y) / 3.0), floor((x - y) / 4.0))));
		return a * gap;
	}
	if (style == 8) {
		float a = mod(y, 3.0) < 1.0 ? 1.0 : 0.0;
		float gap = step(0.3, ink_hash(vec2(floor(x / 5.0), floor(y / 3.0))));
		return a * gap;
	}
	if (style == 9) {
		// A crust splits in long dry runs, not on a pitch: one family of strokes
		// far apart, each broken where the crack healed, and a second bearing
		// that only shows once the shade is deep. A regular net would be the
		// bonelands' hand, and the flat would read as paving.
		float a = mod(x + 4.0 * y, 13.0) < 1.0 ? 1.0 : 0.0;
		float run = step(0.30, ink_hash(vec2(floor((x + 4.0 * y) / 13.0), floor(y / 9.0))));
		float b = mod(x - 5.0 * y, 17.0) < 1.0 ? 1.0 : 0.0;
		float run2 = step(0.45, ink_hash(vec2(floor((x - 5.0 * y) / 17.0), floor(y / 7.0) + 31.0)));
		return max(a * run, b * run2 * step(0.45, depth));
	}
	return 0.0;
}

// Pick between two styles across an ecotone by a stable per-pixel dither.
int ink_style(float packed, float blend, vec2 px) {
	int s1 = int(mod(packed, 16.0) + 0.5);
	int s2 = int(floor(packed / 16.0) + 0.5);
	return ink_hash(px + vec2(17.0, 91.0)) < blend ? s2 : s1;
}

// Smooth value noise for organic patches in world space (not tile-aligned).
float ink_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = ink_hash(i);
	float b = ink_hash(i + vec2(1.0, 0.0));
	float c = ink_hash(i + vec2(0.0, 1.0));
	float d = ink_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// A ragged, stable pixel threshold: w in 0..1 across a boundary becomes a hard
// edge with a dithered fringe about a third of the way wide.
float ink_edge(float w, vec2 px) {
	return step(ink_hash(px + vec2(3.0, 5.0)), smoothstep(0.25, 0.75, w));
}

// The page: a barely-there grain so large washes are paper, not plastic.
float paper(vec2 px) {
	float fibre = step(0.985, ink_hash(floor(px / vec2(3.0, 1.0))));
	return 1.0 + (ink_hash(px) - 0.5) * 0.035 + fibre * 0.03;
}
