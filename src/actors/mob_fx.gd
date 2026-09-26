class_name MobFx
## Hit feel drawn into the notebook (docs/LOOK.md): a short ink burst where a
## blow lands, dust as stipple puffs, a plate's ring as a pen's sound marks and
## two or three bright pixels, a dashed ink ring on the ground, the swing's
## stroke, and a paper-white flash on a struck body. No particles that look like
## a physics engine: every mark is drawn in whole screen pixels by a shader on a
## single quad, and its patterns are pinned to the world through `world_px`.
##
## Ink and dust are tinted by the sky like the page they sit on; sparks and
## glints are light, so they are not. Each mark frees itself.

const _COMMON := """
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled%s;
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform int mode = 0;
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform vec3 col_a = vec3(0.91, 0.86, 0.75);
uniform vec3 col_b = vec3(0.71, 0.86, 0.93);
uniform vec3 ink_col = vec3(0.031, 0.027, 0.059);
uniform vec3 paper_col = vec3(0.91, 0.86, 0.75);
uniform vec2 dir = vec2(1.0, 0.0);
// Pixels of paper laid round a mark's strokes. One is enough on the land; a mark
// that hangs on a machine needs more, because a FOUND body is darker than the
// ground and an ink stroke on it is invisible.
uniform float mark_halo = 1.0;
varying vec3 wp;
"""

const _BILLBOARD := """
void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2] * s.z, MODEL_MATRIX[3]);
	wp = MODEL_MATRIX[3].xyz;
}
"""

const _FLAT := """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
"""

## Every width below is in whole pixels of a mark's own PEN (`pw` is one of them
## in quad units, `PEN` pixels of the frame wide), so a mark reads the same at the
## camera players get as in a close shot.
const _MARKS := """

vec4 ink_out() {
	return vec4(sky_apply(ink_col, wp, TIME), 1.0);
}

// The page under a mark: tinted by the sky, but held up a little so a mark still
// reads as drawn on paper where the land has gone dark.
vec4 paper_out() {
	return vec4(mix(sky_apply(paper_col, wp, TIME), paper_col, 0.4), 1.0);
}

// Ink where e < 0 (e: pixels outside the stroke), a paper edge `halo` pixels
// round it, nothing beyond.
vec4 inked(float e, float halo) {
	if (e < 0.0) {
		return ink_out();
	}
	if (e < halo) {
		return paper_out();
	}
	return vec4(0.0);
}

// Pixels outside a round-ended stroke from a to b (pixel space), half width hw.
float stroke(vec2 q, vec2 a, vec2 b, float hw) {
	vec2 ab = b - a;
	float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(q - (a + ab * t)) - hw;
}

// A short ink burst: tapered strokes thrown OUT from the point, and nothing at
// all at its heart. What a burst is for is to prove where the blow landed, so it
// must not be the thing standing in front of it: the amber working part shows
// through the middle of its own hit mark. Hence OPEN — the fraction of the
// radius that never takes ink — and hence no filled star. (docs/LOOK.md: a
// short ink burst, sparks off plate as two or three bright pixels.)
vec4 burst(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw;
	float e = 1e5;
	// AS MANY STROKES AS CLEAR EACH OTHER AT THIS SIZE, and no more. The quad is
	// sized by the body the mark lands on (MobFx.on_body), so it is not one size:
	// seven roots that stand well apart round a harvester touch round a runner,
	// and touching roots are the filled star BURST_OPEN exists to prevent. The pen
	// does not get finer to fit -- a smaller mark is simply drawn with less ink,
	// the way a smaller drawing is. Three is the fewest that still reads as thrown
	// from a point rather than as a stray tick.
	float root = OPEN * BURST_SHORT * (R - 2.0);
	int strokes = clamp(int(floor(TAU * root / (2.0 * (BURST_ROOT + MARK_HALO)))), 3, BURST_STROKES);
	for (int i = 0; i < strokes; i++) {
		float fi = float(i);
		float h = ink_hash(vec2(seed * 13.1 + fi, 3.7));
		float ang = fi / float(strokes) * TAU + seed + (h - 0.5) * 0.7;
		vec2 d = vec2(cos(ang), sin(ang));
		float len = BURST_SHORT + (1.0 - BURST_SHORT) * ink_hash(vec2(fi, seed * 7.3));
		float r0 = mix(OPEN, 0.84, pr) * len * (R - 2.0);
		float r1 = mix(OPEN + 0.34, 1.0, sqrt(pr)) * len * (R - 2.0);
		float along = dot(q, d);
		float k = clamp((along - r0) / max(r1 - r0, 1e-4), 0.0, 1.0);
		// Thin where the stroke leaves the heart, heavy where it lands. Ink thrown
		// out by a blow pools at the far end, so this is the truer pen -- but it is
		// here because it is the only thing that keeps the heart OPEN at a full pen.
		// The radius R is in pen units, so it shrinks as the pen widens while these
		// widths do not: at PEN 3 seven strokes are 3.7 pens apart at OPEN, and a
		// root 1.5 wide with a pen of paper round it is 5.0 -- the halos meet and
		// the mark becomes the filled star BURST_OPEN exists to prevent. (That is
		// how the 640x360 drawing really looked; the 1080 floor hid it by making R
		// three times larger in pen units, and restoring the pen brought it back.)
		float hw = mix(BURST_ROOT, BURST_TIP, k) * (1.0 - pr * 0.3);
		e = min(e, stroke(q, d * r0, d * r1, hw));
	}
	return inked(e, MARK_HALO);
}

// Dust as a drawn puff: a scalloped contour, inked on the side away from the
// light and paper on the lit side, stippled inside; the line breaks up and the
// dots thin as it settles.
vec4 puff(vec2 p, vec2 px, float pw, float pr) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float R = mix(0.55, 0.92, 1.0 - (1.0 - pr) * (1.0 - pr));
	float lobe = abs(sin(a * 2.5 + seed * 3.0));
	float edge = R * (0.78 + 0.22 * sqrt(lobe));
	float shade = dot(p / max(r, 1e-4), vec2(0.7071, 0.7071));
	float fade = 1.0 - pr;
	if (abs(r - edge) < pw * 0.75) {
		// Dashes fall out of the contour as it goes, starting on the lit side.
		float seg = floor((a / TAU + 0.5) * 18.0);
		if (ink_hash(vec2(seg, seed)) < pr * 1.1 - shade * 0.3) {
			return vec4(0.0);
		}
		return vec4(sky_apply(shade > -0.1 ? ink_col : col_a, wp, TIME), 1.0);
	}
	if (r > edge) {
		return vec4(0.0);
	}
	if (mod(px.x + px.y, 2.0) > 0.5) {
		return vec4(0.0);
	}
	float h = ink_hash(px + vec2(seed * 31.0, seed * 17.0));
	if (h > (0.12 + 0.3 * max(shade, 0.0)) * fade) {
		return vec4(0.0);
	}
	return vec4(sky_apply(shade > 0.25 ? col_b : col_a, wp, TIME), 1.0);
}

// A dashed ink ring spreading on the ground, edged with the page so it reads on
// dark ground; the dashes drop out as it goes. Lying flat, its pixel size differs
// across and along, so widths come from the radius' own screen rate.
vec4 ring(vec2 p, float pr) {
	float r = length(p);
	float pw = max(fwidth(r), 1e-4) * PEN;
	float R = mix(0.3, 1.0, 1.0 - (1.0 - pr) * (1.0 - pr)) - pw * 3.0;
	float seg = floor((atan(p.y, p.x) / TAU + 0.5) * 14.0);
	if (mod(seg, 2.0) > 0.5 || ink_hash(vec2(seg, seed)) < pr * 0.95) {
		return vec4(0.0);
	}
	return inked(abs(r - R) / pw - 1.0, MARK_HALO);
}

// A bite coming, on the ground where it lands: a dashed ring held still at the
// size of what it will strike, and a whole ring inside it closing on the middle,
// which reaches it as the bite goes live. The outer ring says WHERE, the closing
// one says WHEN; neither spreads or fades, because a tell that thins as it runs
// is weakest at the moment it matters.
vec4 tell_ring(vec2 p, float pr) {
	float r = length(p);
	float pw = max(fwidth(r), 1e-4) * PEN;
	float R = 1.0 - pw * 3.0;
	float seg = floor((atan(p.y, p.x) / TAU + 0.5) * 20.0);
	float outer = mod(seg, 2.0) > 0.5 ? 1e3 : abs(r - R) / pw - 1.0;
	float inner = abs(r - R * (1.0 - pr)) / pw - 1.0;
	return inked(min(outer, inner), MARK_HALO);
}

// A throw's tell (MobFx.tell_line): the lane it lands along, on a quad
// stretched to the lane, x along it from the thrower (-1) to its far end (1).
// Both long edges dashed and the far end ruled across, and a bar across the lane
// that travels out from the thrower and reaches the far end as the throw goes
// live. Pens are measured per axis, since the quad is far longer than wide.
vec4 tell_line(vec2 p, float pr) {
	vec2 pw = max(fwidth(p), vec2(1e-4)) * PEN;
	vec2 q = p / pw;
	vec2 R = 1.0 / pw - 2.0;
	bool in_len = abs(q.x) <= R.x;
	bool in_wid = abs(q.y) <= R.y;
	float dash = mod(floor((p.x * 0.5 + 0.5) * R.x / 3.0), 2.0);
	float sides = (in_len && dash < 0.5) ? abs(abs(q.y) - R.y) - 1.0 : 1e3;
	float far_end = in_wid ? abs(q.x - R.x) - 1.0 : 1e3;
	float bar = in_wid ? abs(q.x - mix(-R.x, R.x, pr)) - 1.0 : 1e3;
	return inked(min(min(sides, far_end), bar), MARK_HALO);
}

// A drop's tell (MobFx.tell_drop): its shadow on the ground where it will land,
// a stipple of ink that grows from a pip to the whole of the landing as the body
// comes down, inside a dashed ring the size of the landing. A shadow that grows
// is read from above and from over the shoulder alike: it is flat on the ground
// and it is the one mark that means "something is coming down here".
vec4 tell_drop(vec2 p, vec2 px, float pr) {
	float r = length(p);
	float pw = max(fwidth(r), 1e-4) * PEN;
	float R = 1.0 - pw * 3.0;
	float seg = floor((atan(p.y, p.x) / TAU + 0.5) * 24.0);
	float outer = mod(seg, 2.0) > 0.5 ? 1e3 : abs(r - R) / pw - 1.0;
	float grown = R * (0.12 + 0.88 * pr * pr);
	// Three pixels in four: dense enough to read as a shadow on sunlit rock from
	// a low camera, open enough that the ground still shows through it.
	if (r < grown && (mod(px.x, 2.0) < 1.0 || mod(px.y, 2.0) < 1.0)) {
		return ink_out();
	}
	return inked(outer, MARK_HALO);
}

// A shadow thrown from far above (a colossus's pad): a fine dashed ring round
// the ground it will cover, with a light ordered stipple inside thickening to
// one pixel in four. The dark itself is the land's own shade (sky.gdshaderinc
// `colossus_pads`, lit, not drawn); this is only the edge a player reads it by.
vec4 tell_shade(vec2 p, vec2 px, float pr) {
	float r = length(p);
	float pw = max(fwidth(r), 1e-4) * PEN;
	float R = 1.0 - pw * 3.0;
	float seg = floor((atan(p.y, p.x) / TAU + 0.5) * 96.0);
	float outer = mod(seg, 2.0) > 0.5 ? 1e3 : abs(r - R) / pw - 1.0;
	vec2 c = mod(px, 4.0);
	int i = int(c.x) + int(c.y) * 4;
	const float B[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	if (r < R && (B[i] + 0.5) / 16.0 < 0.25 * pr) {
		return ink_out();
	}
	return inked(outer, MARK_HALO);
}

// Plate: the pen's sound marks, (( )), and two or three cold bright pixels. The
// arcs stand OUTSIDE the plate they rang off, and the sparks are pixels, not
// blobs: this mark says "that was armour", it does not hide the armour.
vec4 clang(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw - 2.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float ang = seed * 2.0 + fi * 2.1 + ink_hash(vec2(fi, seed)) * 0.8;
		vec2 at = vec2(cos(ang), sin(ang)) * mix(OPEN, 0.9, sqrt(pr)) * R;
		vec2 d = abs(q - at);
		if (pr < 0.85 && max(d.x, d.y) < (i == 0 ? 1.0 : 0.5)) {
			return vec4(col_b, 1.0);
		}
	}
	float r = length(q);
	float a = atan(q.y, q.x);
	float e = 1e5;
	for (int s = 0; s < 2; s++) {
		float base = s == 0 ? 0.0 : 3.14159;
		float off = abs(mod(a - base + 3.14159, TAU) - 3.14159);
		if (off > 0.62) {
			continue;
		}
		for (int j = 0; j < 2; j++) {
			if (pr > 0.9 - float(j) * 0.2) {
				continue;
			}
			float Rj = (mix(OPEN + 0.06, 0.78, pr) + float(j) * 0.2) * R;
			e = min(e, abs(r - Rj) - 0.7);
		}
	}
	return inked(e, MARK_HALO);
}

// A glint: a small plus of light that shrinks to one pixel.
vec4 glint(vec2 p, float pw, float pr) {
	vec2 d = abs(p) / pw;
	float arm = floor(mix(3.0, 0.0, pr));
	if ((d.x < 0.5 && d.y < arm + 0.5) || (d.y < 0.5 && d.x < arm + 0.5)) {
		return vec4(d.x < 0.5 && d.y < 0.5 ? col_b : col_a, 1.0);
	}
	return vec4(0.0);
}

// A tell: three short strokes flicked along `dir`, the way a pen draws "about
// to": a fan that does not meet at its root (joined, it reads as an arrow). On a
// scrap of page of their own so they read over any ground. They spring out
// quickly and hold, then break away.
//
// `dir` is which way the fan flicks, in quad space (up the screen is -y). It
// exists so the tell can be aimed: over a body it flicks up, and over a
// MACHINE'S WORKING PART it flicks DOWN at it. A windup has to send the eye to
// the side that opens — the side that hurts you and the side you must hit —
// and three ticks floating above the hull sent it to the roof instead.
vec4 tell(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw;
	float grow = clamp(pr / 0.18, 0.0, 1.0);
	vec2 f = normalize(dir);
	vec2 n = vec2(-f.y, f.x);
	// The fan's root is off the quad, behind the flick.
	vec2 root = -f * 1.05 * R;
	float e = 1e5;
	for (int i = 0; i < 3; i++) {
		float ang = (float(i) - 1.0) * 0.72;
		vec2 d = f * cos(ang) + n * sin(ang);
		float r0 = (i == 1 ? 0.95 : 0.85) * R;
		float r1 = r0 + (i == 1 ? 0.8 : 0.6) * R * mix(0.4, 1.0, grow) - 3.0;
		if (pr > 0.8 && ink_hash(vec2(float(i), seed)) < (pr - 0.8) * 5.0) {
			continue;
		}
		// Heavier where the pen came down, lifting off at the far end.
		vec2 a = root + d * r0;
		vec2 b = root + d * r1;
		float t = clamp(dot(q - a, b - a) / max(dot(b - a, b - a), 1e-4), 0.0, 1.0);
		e = min(e, length(q - mix(a, b, t)) - mix(1.7, 0.6, t * t));
	}
	return inked(e, mark_halo);
}

// Speed lines: three ink dashes left behind a body that has just shot away along
// `dir` (screen, UV space), the middle one longest, with CLEAR PAGE between them.
// They slide back and thin.
//
// They came in at 40 px with each stroke 2.6 px wide and a pixel of paper round
// it, laid 5 px apart: the three paper edges met and the mark became one opaque
// cream slab about 40x35 px with some ink in it, over the player and the ground
// both. So: the burst's OPEN heart (nothing is drawn within OPEN of the centre,
// where the body is), strokes half as thick, and the page showing between them.
// A speed line is ink over the world, not ink on a field of paper (ART §7).
vec4 streak(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw - 2.0;
	vec2 d = normalize(dir);
	vec2 n = vec2(-d.y, d.x);
	float e = 1e5;
	float lit = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i) - 1.0;
		float len = (i == 1 ? 1.5 : 1.05) * R * (1.0 - pr * 0.5);
		// Laid out behind the quad's centre along dir and slid further back as they
		// go: the heart stays open, so the body is never inside its own dash.
		float head = R * (1.0 - OPEN) - abs(fi) * R * 0.12 - pr * R * 0.4;
		vec2 a = d * head + n * fi * 7.0;
		vec2 b = d * (head - len) + n * fi * 7.0;
		// Drawn off to a point at BOTH ends: a pen leaves the page, it does not stop.
		vec2 ab = b - a;
		float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
		float taper = min(1.0, t * 9.0);
		float hw = mix(1.1, 0.25, t) * taper * (pr < 0.55 ? 1.0 : 0.6);
		vec2 off = q - (a + ab * t);
		float de = length(off) - hw;
		if (de < e) {
			e = de;
			// Which flank of THIS stroke the pixel is on, in the same light the
			// dust is drawn by: negative toward the light, positive away from it.
			lit = dot(off, vec2(0.7071, 0.7071));
		}
	}
	if (e < 0.0) {
		return ink_out();
	}
	// One pixel of page, on the LIT flank of each stroke and nowhere else. Edged
	// all round the way a tell is, three narrow strokes stop being strokes: each
	// reads as a white lozenge with a slit down it, and the three lozenges
	// together are the brightest thing on screen, over the body that made them.
	// With no edge at all they are three near-black hairlines, which vanish on
	// dark rock and at night — and this is the DODGE's mark as well as the dash
	// (40_fight), so it has to survive a cave. One flank is a pen catching the
	// light: it cannot close into a lozenge, and it cannot meet its neighbour.
	if (e < 1.0 && lit < 0.0) {
		return paper_out();
	}
	return vec4(0.0);
}

// Breath is the one mark that has to be PALER than its page, not darker, and an
// `unshaded` mark never takes the sun the ground takes. Through sky_apply alone
// a near-white core lands eighty levels BELOW lit snow (measured: core 103, snow
// 187), which is the whole of why breath read as soot on a snowfield: the
// wash it was tinted by is the ambient, and the snow beside it also has a sun on
// it. So while the sun is up the mark is given that light back, capped at its
// own paint so it can never burn past the colour it was drawn in — steam is a
// pale swatch, never a source. As night falls the multiply goes back to 1 and
// NOTHING changes: night was already right, because there the ground is dark and
// the sky's own wash is a step above it.
//
// The gate is sky_view.y, the hour's own night fall, and not either of the two
// obvious neighbours: sky_sun.z counts the moon and put a 227-luminance cloud
// over 100-luminance snow at eleven at night (a lamp, and ART §5 says only a
// lamp may be that), while sky_gloom() reads a low winter sun as dark and left
// the core at 143 under snow that renders at 188 — the soot again.
//
// And the lift never goes to nothing, even at midnight. The mark's own paint is
// as pale as snow is, so under one light they render as the same value: at
// eleven at night the core sat at 101 on a snowfield rendering 98 and the whole
// cloud disappeared, leaving its rim behind as three dark specks. A cloud of
// breath is lit from inside by nothing, but it is DRAWN, and a drawn pale thing
// on a pale page is given its step. (wave A2, art finding 9.)
vec3 vapour_lit(vec3 c) {
	float day = 1.0 - clamp(sky_view.y, 0.0, 1.0);
	return min(c, sky_apply(c, wp, TIME) * (1.0 + mix(VAPOUR_DARK, VAPOUR_SUN, day)));
}

// Breath in the cold, steam off hot ground: the one mark that is neither ink nor
// paper. It has to read on snow AND on wet rock, so it is held by its own rim
// the way a person is (docs/LOOK.md): a pale core of loose pixels inside a
// one-pixel contour in the cue's own mid tone. Drawn in ink on the shaded side,
// as dust is, three specks of breath on a white snowfield read as soot.
vec4 vapour(vec2 p, vec2 px, float pw, float pr) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float R = mix(0.55, 0.80, 1.0 - (1.0 - pr) * (1.0 - pr));
	float lobe = abs(sin(a * 2.5 + seed * 3.0));
	float edge = R * (0.74 + 0.26 * sqrt(lobe));
	if (r > edge) {
		return vec4(0.0);
	}
	float fade = 1.0 - pr;
	if (edge - r < pw * 1.3) {
		// The contour breaks into dashes as the breath thins away.
		float seg = floor((a / TAU + 0.5) * 16.0);
		if (ink_hash(vec2(seg, seed)) < pr * 0.85) {
			return vec4(0.0);
		}
		return vec4(vapour_lit(col_b), 1.0);
	}
	if (ink_hash(px + vec2(seed * 31.0, seed * 17.0)) > 0.35 + 0.5 * fade) {
		return vec4(0.0);
	}
	return vec4(vapour_lit(col_a), 1.0);
}

// A reading held on something: four ruled corner ticks framing it, drawn in
// light, no ink and no paper. This is a machine's own mark seen through a stolen
// lens (docs/LOOK.md: FOUND is clean and exact), so nothing here is hatched,
// stippled or crooked. It snaps in at the start, holds its whole life, and the
// corners close the last of the way as the read settles.
vec4 bracket(vec2 p, float pw, float pr) {
	vec2 q = p / pw;
	float R = 1.0 / pw - 2.0;
	float open = clamp(pr / 0.12, 0.0, 1.0);
	float arm = R * 0.44;
	float e = 1e5;
	for (int i = 0; i < 4; i++) {
		vec2 c = vec2(i == 0 || i == 3 ? -1.0 : 1.0, i < 2 ? -1.0 : 1.0) * R * mix(1.35, 1.0, open);
		e = min(e, stroke(q, c, c - vec2(sign(c.x) * arm, 0.0), 0.9));
		e = min(e, stroke(q, c, c - vec2(0.0, sign(c.y) * arm), 0.9));
	}
	if (e < 0.0) {
		return vec4(col_a, 1.0);
	}
	return vec4(0.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	// One pixel of the mark's own pen, in quad units: PEN of the frame's.
	float pw = max(fwidth(p.x), 1e-4) * PEN;
	float pr = clamp(progress, 0.0, 1.0);
	vec4 o = vec4(0.0);
	if (mode == 0) { o = burst(p, pw, pr); }
	else if (mode == 1) { o = puff(p, px, pw, pr); }
	else if (mode == 2) { o = ring(p, pr); }
	else if (mode == 3) { o = clang(p, pw, pr); }
	else if (mode == 4) { o = glint(p, pw, pr); }
	else if (mode == 5) { o = tell(p, pw, pr); }
	else if (mode == 6) { o = streak(p, pw, pr); }
	else if (mode == 7) { o = bracket(p, pw, pr); }
	else if (mode == 8) { o = vapour(p, px, pw, pr); }
	else if (mode == 9) { o = tell_ring(p, pr); }
	else if (mode == 10) { o = tell_line(p, pr); }
	else if (mode == 11) { o = tell_drop(p, px, pr); }
	else if (mode == 12) { o = tell_shade(p, px, pr); }
	if (o.a < 0.5) {
		discard;
	}
	ALBEDO = o.rgb;
	// In the transparent pass, after the ink outline has been laid over the
	// frame, so a mark sits on top of the page and is never drawn over by it.
	ALPHA = 1.0;
}
"""

## The swing's stroke over an arc mesh: u runs along the swing, v across it.
const _SWING := """
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled, blend_add;
// The order found.gdshader uses, and it is load-bearing: matter reaches for
// `ink_hash`, so ink comes before it.
#define SKY_FOUND
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

uniform float head = 1.0;
uniform float tail = 0.7;
// The light a steel edge carries through its sweep: cold and near white, and
// never the amber of a machine's working part, which is the one saturated thing
// a player is aiming AT and must not be competed with (src/render/palette.gd).
uniform vec3 edge_col = vec3(0.86, 0.91, 0.96);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float from = head - tail;
	if (u > head || u < from) {
		discard;
	}
	float k = (u - from) / max(tail, 1e-4);
	// A crescent: full at the head, thinning to a hairline at the tail, from the
	// outer edge in.
	float inner = 1.0 - (0.15 + 0.85 * sqrt(k));
	if (v < inner) {
		discard;
	}
	// In the mark's own pen, as every other width here is (MobFx.PEN).
	float pu = max(fwidth(u), 1e-5) * PEN;
	// THE EDGE IS WHAT CATCHES. A swing is light smeared along the sweep, not a
	// crescent drawn round it: brightest on the outer rim where the blade is and
	// at the leading hand, dying back down the tail. It is ADDITIVE, so it reads
	// on a dark machine and on bright gravel for the same reason a lamp does,
	// and it needs neither the two pixels of ink this had on every edge nor the
	// paper behind them to be seen (docs/LOOK.md: the world is lit, not drawn).
	float across = smoothstep(inner, 1.0, v);
	float along = pow(1.0 - k, 1.6);
	float lead = smoothstep(pu * 5.0, 0.0, head - u);
	float a = clamp(across * along * 0.8 + lead * across * 0.95, 0.0, 1.0);
	if (a < 0.015) {
		discard;
	}
	// Through the one colour door, so the two renderers agree about what this
	// value MEANS and the web gets it through `sky_emission` like every other
	// light in the game (matter.gdshaderinc).
	ALBEDO = matter_light(edge_col) * a;
	ALPHA = a;
}
"""

const _FLASH := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
uniform vec3 col = vec3(0.91, 0.86, 0.75);
void fragment() {
	ALBEDO = col;
}
"""

## A ruled line of borrowed light between two points, on a ribbon that faces the
## camera. FOUND, so it is exact (docs/LOOK.md): a one-pixel core of the
## machines' cold with a one-pixel dark edge each side, which is what lets it
## read over pale gravel and over night both. It carries its own two values for
## the same reason a person carries a rim.
const _LINE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
#include "res://src/render/sky.gdshaderinc"

uniform vec3 core = vec3(0.70, 0.77, 0.80);
uniform vec3 edge = vec3(0.17, 0.20, 0.25);
uniform float progress = 0.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The ribbon is exactly LINE_PX wide, so UV.y maps whole screen pixels.
	float v = abs(UV.y - 0.5) * 2.0;
	// A line given a life of its own retracts toward the hand as it goes. A
	// grapple's does not: it is re-pointed every frame and freed when the pull
	// is over, so its progress stays at 0 and the whole line stands.
	if (UV.x > 1.0 - progress) {
		discard;
	}
	ALBEDO = sky_apply(v < 0.34 ? core : edge, wp, TIME);
	ALPHA = 1.0;
}
"""

const BURST := 0
const PUFF := 1
const RING := 2
const CLANG := 3
const GLINT := 4
const TELL := 5
const STREAK := 6
const BRACKET := 7
const VAPOUR := 8
const TELL_RING := 9
const TELL_LINE := 10
const TELL_DROP := 11
const TELL_SHADE := 12

## World units per screen pixel of the BASE (1920x1080; the fight system keeps it
## to the camera's own, `40_fight._keep_texel`). Marks are never smaller on screen
## than their *_PX sizes.
static var texel := 15.0 / 1080.0
## Pixels of the frame to one pixel of a mark's own PEN. Every width inside the
## shaders is in that pen -- a stroke's half width, the paper laid round it, a
## spark, a glint's arm, the comb across the swing's arc -- and none of them moved
## when LANTERN's floor took the base from 640x360 to 1920x1080, so every pen came
## out a third of its weight. The FLOORS beside this are a different number and
## are already in pixels of the frame: a floor decides how big a mark is, this
## decides how heavily it is drawn, and a mark whose quad never fell under its
## floor still lost two thirds of its line. Compiled into the shaders as PEN.
const PEN := 3.0
## Smallest on-screen size of each mark (its quad's full width), IN PIXELS OF THE
## 1080-ROW BASE. They were written as pixels of the old 640x360 image and did not
## move when the floor did, so every floor has been a third of its intended reach
## ever since -- and a floor is all they are: a caller passes a size in WORLD units
## (`burst(..., 0.8)`) and only a size under the floor is raised. Measured against
## 640x360 that cost the plain burst 13% and a tell on the smallest machine 36%,
## while the clang and the lens-hit burst never moved at all, their callers'
## sizes having already cleared the floor. Tripling restores every one exactly.
## A hit mark has to be read at a glance and then be gone; it must never be the
## biggest thing in the frame, and it must never be the thing standing in front
## of what it proves (docs/LOOK.md: a SHORT ink burst, sparks as two or three
## bright pixels). The burst and the plate ring came in at 30 px with a filled
## paper star at the heart, which put an opaque disc over the amber working part
## at the exact moment the player needed to see it.
const BURST_PX := 66.0
const PUFF_PX := 48.0
const RING_PX := 66.0
const CLANG_PX := 60.0
const GLINT_PX := 27.0
## A tell is the one mark that is NOT a record of a blow: it is a warning, and it
## is read at the far edge of vision while the player is deciding to dodge. It
## keeps the full 30 px it has always had — shrunk to 26 it read as one thin bar
## beside the machine instead of a fan pointing anywhere.
const TELL_PX := 90.0
## Speed lines came in at 40 px, which at 640x360 is a mark wider than the body
## that made it; back down beside the burst's 22, where a dash is a flick of the
## pen behind a body that is still plainly a person (wave A2, art finding 3).
const STREAK_PX := 102.0
const BRACKET_PX := 78.0
## Breath and steam: small, because they are a cue and not an event.
const VAPOUR_PX := 54.0
## A magnet line's width in pixels of the frame: one PEN of the machines' cold
## with one of their dark each side, which is the least that reads over pale
## gravel. It is the one floor `look/marks` left at its 640x360 value, so the
## line was drawn with a one-pixel core until this.
const LINE_PX := 9.0
## A burst's stroke, in pens: thin where it leaves the heart, heavy where it lands.
## How many there are, how short the shortest may be, and how much paper is laid
## round one. They are here and not buried in the shader because together with
## `PEN` and `BURST_OPEN` they decide whether the heart stays open at all, and
## tests/models/test_machines_hit_marks.gd does that arithmetic every run.
const BURST_STROKES := 7
const BURST_ROOT := 0.55
const BURST_TIP := 1.5
const BURST_SHORT := 0.78
## Pens of paper laid round an ordinary mark's strokes (a tell asks for more:
## TELL_HALO). It is what makes ink read on dark ground, and it is also half of
## what can close a burst's heart, since it is laid on BOTH flanks of every stroke.
const MARK_HALO := 1.0
## The fraction of a burst's (and a plate ring's) radius that never takes ink, so
## what was struck shows through the middle of its own mark. Compiled into the
## shader as OPEN and measured against the machines' parts in
## tests/models/test_machines_hit_marks.gd.
const BURST_OPEN := 0.48
## How many pixels of paper are laid round a tell's strokes. Every other mark
## sits on the land, which is pale; a tell hangs on a MACHINE, whose body is now
## deliberately darker than the ground it stands on, and ink on ink is nothing.
## Backed by this much page the fan reads over a hull, over turf and over night —
## and no more than this, or the strokes stop being strokes and the tell reads as
## three white lozenges with a slit down each (ART §7: these are pen marks).
const TELL_HALO := 1.7
## How much of the sun a breath is given back. A mark is `unshaded`, so it takes
## the sky's ambient wash and none of the key light the ground beside it takes:
## on a lit snowfield that put a near-white core eighty levels BELOW the snow.
## Big enough that in any real daylight the multiply saturates at the mark's own
## colour, so the core is always the paler thing.
const VAPOUR_SUN := 2.2
## And what is left of that lift once night has fallen. Not nothing: a mark's
## paint is as pale as snow, so under one light they land on the same value and
## the cloud vanishes into the field it is breathed over. Small enough that a
## breath at midnight is a pale cloud and not a lamp (docs/LOOK.md).
const VAPOUR_DARK := 0.6
## Which way a tell's fan flicks, in quad space: up the screen over a body, down
## the screen when it is aimed at a working part below it.
const FLICK_UP := Vector2(0.0, -1.0)
const FLICK_DOWN := Vector2(0.0, 1.0)
const MARK_PRIORITY := 12
## A shot's held moment: marks are advanced a little and then stop where they are.
static var hold := false
## How far into its life a held mark is stopped (0..1).
static var hold_at := 0.3
static var _shaders: Dictionary = {}
static var _flash_mat: ShaderMaterial
static var _quad: QuadMesh


static func _shader(key: StringName) -> Shader:
	if _shaders.has(key):
		return _shaders[key]
	var s := Shader.new()
	# One number for the open heart of a mark, and one for the pen every width in
	# this file is drawn with, in the shaders and in the tests.
	var open := ("#define PEN %0.4f\n#define OPEN %0.4f\n#define VAPOUR_SUN %0.4f\n#define VAPOUR_DARK %0.4f\n"
		+ "#define BURST_STROKES %d\n#define BURST_ROOT %0.4f\n#define BURST_TIP %0.4f\n#define BURST_SHORT %0.4f\n#define MARK_HALO %0.4f\n") % [
		PEN, BURST_OPEN, VAPOUR_SUN, VAPOUR_DARK, BURST_STROKES, BURST_ROOT, BURST_TIP, BURST_SHORT, MARK_HALO]
	match key:
		&"over":
			s.code = "shader_type spatial;\n" + (_COMMON % ", depth_test_disabled") + open + _BILLBOARD + _MARKS
		&"flat":
			s.code = "shader_type spatial;\n" + (_COMMON % ", depth_test_disabled") + open + _FLAT + _MARKS
		&"ground":
			s.code = "shader_type spatial;\n" + (_COMMON % "") + open + _FLAT + _MARKS
		&"among":
			s.code = "shader_type spatial;\n" + (_COMMON % "") + open + _BILLBOARD + _MARKS
		&"swing":
			s.code = "shader_type spatial;\n" + open + _SWING
		&"line":
			s.code = _LINE
		_:
			s.code = _FLASH
	_shaders[key] = s
	return s


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## One mark on a quad. `shader`: over (faces the camera) or flat (lies on the
## ground). From above neither is hidden by what it is drawn on: the land's
## contours stand a little proud of a tile's level, and a depth-tested mark sank
## into them. Under the close eye a flat mark is `ground`, depth-tested: seen from
## behind the head, a ring round the feet drawn over everything lands on the
## head. (`among`: a mark facing the camera that bodies hide, for the few drawn
## by the body at eye level; see `puff`.)
static func _mark(parent: Node, at: Vector3, size: float, mode: int, shader: StringName, seed_value: int, a: Color, b: Color) -> MeshInstance3D:
	if shader == &"flat" and close_eye(parent):
		shader = &"ground"
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = _shader(shader)
	mat.set_shader_parameter(&"mode", mode)
	mat.set_shader_parameter(&"seed", float(posmod(seed_value, 997)) * 0.731)
	mat.set_shader_parameter(&"col_a", _v3(a))
	mat.set_shader_parameter(&"col_b", _v3(b))
	mat.set_shader_parameter(&"ink_col", _v3(Palette.INK[0]))
	mat.set_shader_parameter(&"paper_col", _v3(Palette.LINEN[5]))
	mat.set_shader_parameter(&"progress", 0.0)
	# Marks draw after the land, the bodies and a part's light (priority 10): a
	# burst is the thing to read at the moment of a hit, and a flare swallowed it.
	mat.render_priority = MARK_PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	parent.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * size * 0.5
	if shader == &"flat" or shader == &"ground":
		mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	return mi


static func _run(mi: MeshInstance3D, seconds: float, travel: Vector3 = Vector3.ZERO) -> void:
	var mat := mi.material_override as ShaderMaterial
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"progress", t), 0.0, 1.0, seconds)
	if travel != Vector3.ZERO:
		tw.tween_property(mi, "global_position", mi.global_position + travel, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(mi.queue_free)
	if hold:
		tw.custom_step(seconds * hold_at)
		tw.pause()


static func _ok(parent: Node) -> bool:
	return parent != null and parent.is_inside_tree()


## How wide a mark drawn ON a body may be, as a share of that body's own width.
##
## MEASURED, through the real CameraRig at all eight bearings, in pixels of the
## 1080-row frame: lineman 32.7 edge-on to harvester 354.2. The roster runs
## ELEVEN TO ONE, and that is why no single absolute number ever worked here. A
## floor is a legibility minimum ("too small to notice is no record at all") and
## a cap is a proportion rule ("never the thing standing in front of what it
## proves"); across that range the two pull opposite ways, and every attempt to
## serve both with one constant has failed in one direction or the other. The
## floors tripled for the 1080 frame came out 66 px against a runner 51.5 wide.
##
## So a mark that lands on a body is held into a BAND set by that body, and the
## width it is measured against is `2 x` the roster's own `radius` -- the same
## number the fight already places and reaches with, so the mark and the fight
## cannot disagree about how big the thing is. It reads under the drawn
## silhouette for every machine in the roster, which
## tests/models/test_machines_hit_marks.gd measures rather than asserts.
const BODY_SHARE := 0.8
## And under the band, the size below which there is no point drawing at all. It
## wins when a body is so small that a legible mark cannot also be a modest one:
## better a mark wider than a gull than no record that the blow landed.
const LEAST_PX := 24.0


## `size` world units, held into the band a mark may take on a body `across` wide
## (world units). Used by the marks that are drawn OVER the thing they prove --
## the burst and the plate ring. A mark that lands beside a body instead (dust at
## the feet, a ring on the ground, a tell hanging clear above) keeps the plain
## floor below, because none of them stands in front of anything.
static func on_body(size: float, across: float) -> float:
	return maxf(px(LEAST_PX), minf(size, across * BODY_SHARE))


## `size` world units, or `min_px` pixels of the FRAME if that is larger (a
## floor, in the floors' own unit -- not the pen's).
static func at_least(size: float, min_px: float) -> float:
	return maxf(size, min_px * texel)


## World units covered by `n` pixels of the frame. What the floors are in.
static func px(n: float) -> float:
	return n * texel


## World units covered by `n` pixels of a mark's own pen. What a clearance, a
## flash or a lift written beside the shader's own widths is in, so the two
## cannot drift apart.
static func pen_px(n: float) -> float:
	return n * PEN * texel


## How much of a struck body goes to paper, as a share of its height. Enough to
## read as "here", never enough to be the body: at a quarter of the height the
## machine keeps its violet, its wear and its amber part while the blow lands.
const FLASH_SHARE := 0.24


## The flash sphere for a body `height` world units tall, never smaller than a few
## pixels of the pen's grid (a low body would otherwise flash nothing at all).
## Written as pixels of the 640x360 image, like the shader's widths and unlike the
## floors, which is why it is restored here and not with them.
## AND NEVER MORE THAN A SHARE OF THE BODY, WHICH THE FLOOR ALONE DID NOT
## PROMISE. The floor is four pen-pixels so a low body flashes something at all;
## with nothing above it, that floor could exceed the body it was marking. At the
## SHIPPED window (`project.godot` overrides 1080 to 720) a 0.8-unit body came out
## flashing 62.5% of itself, which `tests/render/test_marks.gd` calls out by name:
## the mark is a part of a body and not the body. It passed in isolation only
## because nothing had started a game yet and `texel` still held its 15/1080
## default, so the test read as order-dependent and was neither -- it was a true
## report about the window a player actually gets.
##
## So the floor is a legibility minimum and this is the honest maximum, and the
## maximum wins. 0.30 sits under the two-thirds the test bars at whatever the
## window is, so the pair can no longer disagree on a machine nobody tried.
const FLASH_MOST := 0.30


static func flash_radius(height: float) -> float:
	return minf(maxf(height * FLASH_SHARE, pen_px(4.0)), height * FLASH_MOST)


## Screen pixels at the heart of a burst that never take ink, at the moment of
## the blow. What was struck has to show through: the burst proves the hit, the
## part proves where to hit.
static func burst_clear_px(size: float = 0.9) -> float:
	return at_least(size, BURST_PX) / maxf(texel, 1e-5) * 0.5 * BURST_OPEN


## Where a blow landed: a burst of ink strokes over whatever was struck. An
## `accent` other than transparent adds two or three pixels of that light.
## `across` is how wide the struck body is, in world units; 0 means the mark is
## not landing on a body and takes the plain floor.
static func burst(parent: Node, at: Vector3, size: float = 0.9, seed_value: int = 0, accent: Color = Color(0, 0, 0, 0), across: float = 0.0) -> void:
	if not _ok(parent):
		return
	var wide := on_body(size, across) if across > 0.0 else at_least(size, BURST_PX)
	_run(_mark(parent, at, wide, BURST, &"over", seed_value, Palette.LINEN[5], Palette.LINEN[5]), 0.16)
	if accent.a > 0.0:
		glint(parent, at + Vector3(0, 0.05, 0), accent, seed_value + 5, 0.4)


## Dust thrown up at the feet and drifting along `dir` (tile space). Under the
## close eye it is `among` the bodies, depth-tested: a puff at the feet or the
## mouth drawn over everything is a cloud on the back of the head.
static func puff(parent: Node, at: Vector3, dir: Vector2, dust: Color, size: float = 0.6, seed_value: int = 0) -> void:
	if not _ok(parent):
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	size = at_least(size, PUFF_PX)
	var lift := Vector3(0, size * 0.35, 0)
	var mi := _mark(parent, at + lift, size, PUFF, &"among" if close_eye(parent) else &"over", seed_value, dust, dust.darkened(0.35))
	var t := 0.34 + Rng.hash01(seed_value, 1, 2) * 0.12
	_run(mi, t, Vector3(d.x, 0.0, d.y) * size * 0.9 + Vector3(0, size * 0.3, 0))


## A slow breath of pale steam and ash off a vent, or off a body in the cold: a
## puff that rises and thins over `seconds`, drifting with the wind.
##
## FROM ABOVE it is a MARK drawn in TWO values of `col`'s own hue and in no ink
## at all: a pale core held by a rim in the cue's own mid tone (docs/LOOK.md).
## Breath drawn the way dust is -- an ink contour on the shaded side -- is three
## near-black specks, and on a snowfield near-black is soot, not breath (wave A2,
## art finding 9). The rim is lifted off the cue's own step too: left at the raw
## colour it is a near-black ring round a pale heart, and on snow half the mark's
## pixels are that ring, the soot again with a hole in it. A step up puts the
## contour BETWEEN the core and the snow, so the cloud has an edge without a
## shadow.
##
## UNDER THE CLOSE EYE it is AIR (`_air`): a mark there is a flat cartoon cloud
## held to a floor in frame pixels, drawn over everything, a metre from the lens
## -- a white speckled cloud the size of a door hanging by the player's head.
static func breath(parent: Node, at: Vector3, col: Color, size: float, seconds: float, drift: Vector2, seed_value: int) -> void:
	if not _ok(parent):
		return
	if close_eye(parent):
		_air(parent, at, col, size, seconds, drift, seed_value)
		return
	size = at_least(size, VAPOUR_PX)
	var mi := _mark(parent, at, size, VAPOUR, &"over", seed_value, col.lightened(0.86), col.lightened(0.34))
	_run(mi, seconds, Vector3(drift.x, size * 0.6, drift.y))


## Whether the eye `parent` is seen through is close: the perspective lens (the
## view over the shoulder). A mark's floor in frame pixels is a legibility
## minimum for the camera looking down; under the close eye it is a cloud the
## size of a door a metre from the lens.
static func close_eye(parent: Node) -> bool:
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	return cam != null and cam.projection == Camera3D.PROJECTION_PERSPECTIVE


## Breath as the fire's own soft puff (FireModel.smoke_material): lit by what
## reaches it, depth-tested so a head in front of it hides it, in world units,
## swelling and thinning as it rises.
static func _air(parent: Node, at: Vector3, col: Color, size: float, seconds: float, drift: Vector2, seed_value: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = FireModel.smoke_mesh()
	var mat := FireModel.smoke_material().duplicate() as StandardMaterial3D
	var c := col.lightened(0.72)
	mat.albedo_color = Color(c.r, c.g, c.b, 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	var turn := Rng.hash01(seed_value, 3) * 0.3
	mi.scale = Vector3.ONE * size * (0.55 + turn)
	var dense := 0.5
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		mat.albedo_color.a = dense * smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.3, 1.0, t)), 0.0, 1.0, seconds)
	tw.tween_property(mi, "scale", Vector3.ONE * size * (1.4 + turn), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mi, "global_position", at + Vector3(drift.x, size * 0.6, drift.y), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(mi.queue_free)
	if hold:
		tw.custom_step(seconds * hold_at)
		tw.pause()


## Several puffs about a point, for a body landing or a charge setting off.
static func puffs(parent: Node, at: Vector3, dir: Vector2, dust: Color, count: int, size: float, seed_value: int) -> void:
	for i in count:
		var a := Rng.hash01(seed_value, i, 9) * TAU
		var r := size * (0.25 + Rng.hash01(seed_value, i, 10) * 0.45)
		var off := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var spread := dir + Vector2(off.x, off.z) * 0.8
		puff(parent, at + off, spread, dust, size * (0.7 + Rng.hash01(seed_value, i, 11) * 0.5), seed_value * 7 + i)


## A dashed ink ring spreading on the ground.
static func ring(parent: Node, at: Vector3, col: Color, radius: float = 0.8, seconds: float = 0.3) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at + Vector3(0, 0.04, 0), at_least(radius * 2.0, RING_PX), RING, &"flat", int(at.x * 13.0 + at.z * 7.0), col, col), seconds)


## A bite's tell on the ground (FightRules.tell_ring): a dashed ring of the size
## of what it will strike, held for `seconds` (its windup), with a ring inside it
## closing on the middle that arrives as the bite goes live.
static func tell_ring(parent: Node, at: Vector3, col: Color, radius: float, seconds: float) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at + Vector3(0, 0.04, 0), at_least(radius * 2.0, RING_PX), TELL_RING, &"flat", int(at.x * 13.0 + at.z * 7.0), col, col), seconds)


## A throw's tell on the ground (FightRules.tell_lane): the lane it lands along,
## from `from` out along `angle` (the sim's, radians in the ground plane) for
## `length` tiles and `width` across, held for `seconds` (its windup), with a bar
## travelling out along it that reaches the far end as the throw goes live.
static func tell_line(parent: Node, from: Vector3, angle: float, length: float, width: float, col: Color, seconds: float) -> void:
	if not _ok(parent):
		return
	var along := Vector3(cos(angle), 0.0, sin(angle))
	var mi := _mark(parent, from + along * length * 0.5 + Vector3(0, 0.04, 0), 2.0, TELL_LINE, &"flat", int(from.x * 13.0 + from.z * 7.0), col, col)
	# Laid flat (as every ground mark is), then turned so its x runs down the lane.
	mi.rotation = Vector3(-PI * 0.5, -angle, 0.0)
	mi.scale = Vector3(length * 0.5, at_least(width, RING_PX * 0.25) * 0.5, 1.0)
	_run(mi, seconds)


## A drop's tell on the ground (FightRules.tell_drop): a dashed ring the size of
## the landing, with its shadow growing inside it to fill it as the body comes
## down, over `seconds` (its windup).
static func tell_drop(parent: Node, at: Vector3, col: Color, radius: float, seconds: float) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at + Vector3(0, 0.04, 0), at_least(radius * 2.0, RING_PX), TELL_DROP, &"flat", int(at.x * 13.0 + at.z * 7.0), col, col), seconds)


## A shadow from far above on the ground (a colossus's pad, 19_colossi): a
## dashed ring the size of what is coming, the whole ground inside it dimming
## over `seconds` as it comes down. Seen from the shoulder it lies on the land it
## covers, as every flat mark does there (`_mark`).
static func tell_shade(parent: Node, at: Vector3, col: Color, radius: float, seconds: float) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at + Vector3(0, 0.04, 0), at_least(radius * 2.0, RING_PX), TELL_SHADE, &"flat", int(at.x * 13.0 + at.z * 7.0), col, col), seconds)


## A blow that rang off plate: sound marks and a few cold bright pixels.
static func clang(parent: Node, at: Vector3, seed_value: int = 0, across: float = 0.0) -> void:
	if not _ok(parent):
		return
	var wide := on_body(1.0, across) if across > 0.0 else at_least(1.0, CLANG_PX)
	_run(_mark(parent, at, wide, CLANG, &"over", seed_value, Palette.COLD[3], Palette.COLD[3]), 0.2)


## A small plus of light shrinking to a pixel: a lens catching the light, a part flaring.
static func glint(parent: Node, at: Vector3, col: Color, seed_value: int = 0, size: float = 0.5) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, at_least(size, GLINT_PX), GLINT, &"over", seed_value, col, col.lightened(0.5)), 0.16)


## A reading held on something for `seconds`: four ruled corner ticks in `col`,
## clean light with no ink and no stipple. What a stolen lens puts on a machine.
static func bracket(parent: Node, at: Vector3, col: Color, size: float = 1.2, seconds: float = 0.5, seed_value: int = 0) -> void:
	if not _ok(parent):
		return
	_run(_mark(parent, at, at_least(size, BRACKET_PX), BRACKET, &"over", seed_value, col, col), seconds)


## Flicked strokes for a blow that is coming: held for `seconds` (its windup).
## `anchor` is the thing being marked, in the world; the fan stands clear of it
## on screen (`up`: the camera's up vector) so it is never lost in a silhouette.
##
## `flick` says which way the strokes are thrown. FLICK_UP puts the fan above a
## body and throws it up and away — "about to". FLICK_DOWN puts the fan above the
## thing and throws it DOWN at it — "here, this one" — which is what a machine's
## windup wants: the player must look at the side that opens, not at the roof.
static func tell(parent: Node, anchor: Vector3, up: Vector3, seconds: float, seed_value: int = 0, size: float = 0.9, flick: Vector2 = FLICK_UP) -> void:
	if not _ok(parent):
		return
	size = at_least(size, TELL_PX)
	# Aimed down, the whole quad stands above the thing it points at; aimed up,
	# the fan's near ends are 0.45 of the half size below the quad's centre.
	# The fan's furthest tips are 0.4 of the half size from the quad's centre, so
	# aimed down it hangs a clear three pixels above the thing it points at: a
	# tell must send the eye to the part, never stand in front of it.
	var clear := (0.72 if flick == FLICK_DOWN else 0.45) * size * 0.5 + pen_px(3.0)
	var mi := _mark(parent, anchor + up.normalized() * clear, size, TELL, &"over", seed_value, Palette.INK[0], Palette.INK[0])
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter(&"dir", flick)
	# A tell hangs on the machine it warns about, and a machine is the darkest
	# thing in a daylight frame: the strokes are backed by page so they read on it.
	mat.set_shader_parameter(&"mark_halo", TELL_HALO)
	_run(mi, maxf(0.12, seconds))


## Speed lines left behind a body that shot off along `dir` (tile space) as a
## camera at `yaw_deg`/`pitch_deg` sees it. `at` is where the lines' heads
## are: they trail back from it, away from `dir`.
static func streak(parent: Node, at: Vector3, dir: Vector2, yaw_deg: float, pitch_deg: float, seed_value: int = 0, size: float = 1.1) -> void:
	if not _ok(parent) or dir.length() < 0.01:
		return
	size = at_least(size, STREAK_PX)
	var yaw := deg_to_rad(yaw_deg)
	var right := Vector2(cos(yaw), -sin(yaw))
	var up := Vector2(-sin(yaw), -cos(yaw))
	var d := dir.normalized()
	# UV y runs down the screen; the ground's up is foreshortened by the pitch.
	var screen := Vector2(d.dot(right), -d.dot(up) * sin(deg_to_rad(pitch_deg)))
	# The quad sits back along dir so the heads -- drawn (1 - OPEN) of the way
	# ahead in it, clear of the open heart -- land on `at`.
	var back := (1.0 - BURST_OPEN) * 0.5 * size / maxf(0.2, screen.length())
	var mi := _mark(parent, at - Vector3(d.x, 0.0, d.y) * back, size, STREAK, &"over", seed_value, Palette.INK[0], Palette.INK[0])
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter(&"dir", screen.normalized())
	# A step down the page's own ramp. Every other mark is edged in the full linen,
	# which the midday sky grades all the way to 255 -- pure white, and docs/LOOK.md
	# §5 keeps the brightest thing in a frame for fire and lamps. A speed line's
	# edge is only there to keep three hairlines readable on dark rock, and one
	# step down does that at 236 (measured on the coast at eleven).
	mat.set_shader_parameter(&"paper_col", _v3(Palette.LINEN[4]))
	_run(mi, 0.2)


## A line of borrowed light from `from` to `to`: a magnet line off the boots, a
## tether, anything the machines' own hardware puts between two points. It is a
## LINE, drawn its whole length, not a few marks of light spaced along one --
## spaced marks at a real distance are two sparkles and a player who is moved
## without being shown why (wave A2, art finding 4).
##
## Returns the node so whoever drew it can re-point it with `aim_line` as it
## shortens, and free it when the pull is over. `seconds` > 0 frees it itself.
static func line(parent: Node, from: Vector3, to: Vector3, col: Color, seconds: float = 0.0) -> MeshInstance3D:
	if not _ok(parent):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = _shader(&"line")
	mat.set_shader_parameter(&"core", _v3(col))
	mat.set_shader_parameter(&"edge", _v3(Palette.PLATE[1]))
	mat.set_shader_parameter(&"progress", 0.0)
	mat.render_priority = MARK_PRIORITY
	var mi := MeshInstance3D.new()
	mi.mesh = ArrayMesh.new()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	aim_line(mi, from, to)
	if seconds > 0.0:
		_run(mi, seconds)
	return mi


## Re-point a line drawn by `line`. The ribbon is rebuilt across the camera, so
## it keeps its exact width in screen pixels from any angle and at any distance.
static func aim_line(mi: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	if mi == null or not mi.is_inside_tree():
		return
	var span := to - from
	if span.length() < 0.01:
		mi.visible = false
		return
	mi.visible = true
	var fwd := Vector3.FORWARD
	var cam := mi.get_viewport().get_camera_3d()
	if cam != null:
		fwd = cam.global_transform.basis.z
	var n := span.cross(fwd)
	if n.length() < 1e-3:
		n = span.cross(Vector3.UP)
	n = n.normalized() * px(LINE_PX) * 0.5
	# Drawn in world space about the line's own midpoint, so the node itself never
	# has to be turned: a line redrawn every frame must cost nothing but a mesh.
	var mid := (from + to) * 0.5
	mi.global_position = mid
	mi.global_transform.basis = Basis.IDENTITY
	var a := from - mid
	var b := to - mid
	var verts := PackedVector3Array([a - n, a + n, b + n, a - n, b + n, b - n])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := mi.mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.extra_cull_margin = span.length()


## Compile every mark's shader before the first blow needs it, so the first hit
## of a game is not also its first hitch. Each draws nothing and frees itself.
static func warm(parent: Node, at: Vector3) -> void:
	if not _ok(parent):
		return
	for key: StringName in [&"over", &"flat"]:
		var mi := _mark(parent, at, 0.5, BURST, key, 0, Palette.INK[0], Palette.INK[0])
		(mi.material_override as ShaderMaterial).set_shader_parameter(&"progress", 1.0)
		_free_after(mi, 0.25)
	var arc := MeshInstance3D.new()
	arc.mesh = swing_mesh(1.0, 1.0)
	var sm := swing_material()
	sm.set_shader_parameter(&"head", 0.0)
	sm.set_shader_parameter(&"tail", 0.0)
	arc.material_override = sm
	parent.add_child(arc)
	arc.global_position = at
	_free_after(arc, 0.25)
	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.01, 0.01)
	card.mesh = q
	card.material_override = _flash_material()
	parent.add_child(card)
	card.global_position = at - Vector3(0, 0.5, 0)
	_free_after(card, 0.25)


static func _free_after(n: Node, seconds: float) -> void:
	var tw := n.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(n.queue_free)


## The swing's arc: `reach` out from the body's centre, spread to cover `width`
## across. u runs from where the swing starts to where it ends; v from the
## inside of the stroke to its outer edge.
static func swing_mesh(reach: float, width: float) -> ArrayMesh:
	# Never a narrow flag: even a fist's sweep is drawn as a crescent a body wide.
	var spread := clampf(atan2(width * 0.5, maxf(0.3, reach)) * 1.5, 0.95, 1.5)
	reach = maxf(reach, 0.9)
	var inner := reach * 0.45
	var steps := 14
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in steps:
		var u0 := float(i) / steps
		var u1 := float(i + 1) / steps
		# From the right hand across to the left.
		var a0 := lerpf(spread, -spread, u0)
		var a1 := lerpf(spread, -spread, u1)
		var o0 := Vector3(cos(a0), 0.0, sin(a0))
		var o1 := Vector3(cos(a1), 0.0, sin(a1))
		verts.append_array([o0 * inner, o0 * reach, o1 * reach, o0 * inner, o1 * reach, o1 * inner])
		uvs.append_array([Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u0, 0), Vector2(u1, 1), Vector2(u1, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func swing_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(&"swing")
	mat.set_shader_parameter(&"paper_col", _v3(Palette.LINEN[5]))
	mat.set_shader_parameter(&"ink_col", _v3(Palette.INK[0]))
	mat.render_priority = MARK_PRIORITY
	return mat


## Paper-white on a struck body while `on` (skips glow cards, which are not
## ArrayMeshes, so a halo never flashes as a square, and shadow-only twins).
## MultiMesh parts (a flock's shards) flash too.
##
## `radius` > 0 flashes ONLY a sphere of that size in world units about `at`:
## the part that was struck goes to paper and the rest of the body keeps its own
## colour. A machine is the one body big enough for this to matter, and it
## matters a lot — flashed whole it is a bone-white silhouette that says nothing
## about where the blow landed, hides the amber working part the player is
## aiming at, and is the biggest thing in the frame (wave A2, playtest finding
## 4). With radius 0 the whole body flashes, which is right for a dog or a
## person: a few pixels across, they have no parts to tell apart.
##
## The sphere is `flash_at`/`flash_r` in found.gdshader and world.gdshader,
## written into a COPY of each drawn part's material. Never into the material
## itself: people share one, and animals draw on the world's, so writing there
## would flash the village or the ground.
##
## A figure that can flash itself (`set_flash(on, at, radius)`, a uniform in its
## own shader) is asked to. Otherwise each material_override is set aside and put
## back after; a figure that assigned its own material in between keeps it.
static func set_flash(root: Node, on: bool, at: Vector3 = Vector3.ZERO, radius: float = 0.0) -> void:
	if root == null:
		return
	# A player may ask for no flashes at all (PlayerSettings): what is struck still
	# shows it in the mark, the sound and the pose, so nothing is lost but the glare.
	if on and not bool(PlayerSettings.value(&"picture.flashes")):
		return
	if root.has_method(&"set_flash"):
		root.call(&"set_flash", on, at, radius)
		return
	_flash_material()
	_flash_under(root, on, at, radius)


static func _flash_material() -> ShaderMaterial:
	if _flash_mat == null:
		_flash_mat = ShaderMaterial.new()
		_flash_mat.shader = _shader(&"flash")
		_flash_mat.set_shader_parameter(&"col", _v3(Palette.LINEN[5]))
	return _flash_mat


static func _flash_under(n: Node, on: bool, at: Vector3, radius: float) -> void:
	var gi := n as GeometryInstance3D
	if gi != null:
		var mi := n as MeshInstance3D
		var drawn := (mi == null or mi.mesh is ArrayMesh) and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if drawn:
			# (An overlay pass would be kinder, but the Compatibility renderer draws none.)
			if on and not gi.has_meta(&"unflashed"):
				gi.set_meta(&"unflashed", gi.material_override)
				gi.material_override = _part_flash(gi, at, radius) if radius > 0.0 else _flash_mat
			elif not on and gi.has_meta(&"unflashed"):
				# Put back only over our own flash: a material the figure chose since is its own.
				var ours: Material = gi.get_meta(&"flash_copy") as Material if gi.has_meta(&"flash_copy") else null
				if gi.material_override == _flash_mat or (ours != null and gi.material_override == ours):
					gi.material_override = gi.get_meta(&"unflashed") as Material
				gi.remove_meta(&"unflashed")
	for c in n.get_children():
		_flash_under(c, on, at, radius)


## This part's own material with the flash sphere written into it. Kept on the
## node and remade only when the part swapped material underneath us (a working
## part does, when its light goes out), so a fight costs no allocation per blow.
static func _part_flash(gi: GeometryInstance3D, at: Vector3, radius: float) -> Material:
	var src := _drawn_material(gi) as ShaderMaterial
	if src == null:
		return _flash_mat
	var copy: ShaderMaterial = gi.get_meta(&"flash_copy") as ShaderMaterial if gi.has_meta(&"flash_copy") else null
	var was: ShaderMaterial = gi.get_meta(&"flash_src") as ShaderMaterial if gi.has_meta(&"flash_src") else null
	if copy == null or was != src:
		copy = src.duplicate() as ShaderMaterial
		gi.set_meta(&"flash_copy", copy)
		gi.set_meta(&"flash_src", src)
	copy.set_shader_parameter(&"flash_at", at)
	copy.set_shader_parameter(&"flash_r", radius)
	return copy


## What this part actually draws with. A mesh whose surfaces carry their own
## materials cannot be copied part-wise through material_override, so it takes
## the whole-body flash rather than the wrong colours.
static func _drawn_material(gi: GeometryInstance3D) -> Material:
	if gi.material_override != null:
		return gi.material_override
	var mi := gi as MeshInstance3D
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() != 1:
		return null
	var m := mi.get_surface_override_material(0)
	return m if m != null else mi.mesh.surface_get_material(0)
