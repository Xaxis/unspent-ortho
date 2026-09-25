// LEAVES: the crown of every plant, as cards (src/models/props/kit.gd `canopy`).
//
// WHY NOT A SOLID. Foliage is many small surfaces at many angles, and under a
// real sun that is the whole read: each leaf turns its own way, so light breaks
// into dapple instead of shading like a dome. The lobed solid this replaces was
// either a cut green gem or a green boulder depending on its crease angle, and
// no angle made it a tree.
//
// WHY NOT TRANSPARENT. A card is OPAQUE and cut with `discard`: it draws in the
// opaque pass, sorts by depth with the land, writes depth for what is behind it
// and has no render_priority to get wrong. Transparent world geometry at the
// default priority silently does not draw at all (CLAUDE.md), and the depth
// package's foreground layer made the same choice for the same reason.
//
// WHY NOT world.gdshader. Three things the terrain's shader cannot be asked to
// do without making every tile pay for them:
//   1. Both sides. A leaf has no back, and `cull_disabled` on the land would
//      double the cost of the whole world.
//   2. The cut. The terrain has no card coordinates to cut a sprig out of; UV
//      there is a landscape's hand.
//   3. Light THROUGH it. The sun behind a canopy's rim is the thing that sells a
//      leaf, and BACKLIGHT on the land's shader would put translucency in the
//      light loop of every fragment of ground in the game.
//
// WHAT RENDERS WHERE, measured rather than assumed (tests/render/test_foliage.gd
// holds the parts a test can hold): BACKLIGHT changes the picture on BOTH
// renderers. Under gl_compatibility a quad lit only from behind came back
// (0.231, 0.451, 0.098) with it and black without; on Forward+ the gallery's
// broadleaf at 18:00 with `through` 0.6 against 0.0 moved 93,860 pixels by ten
// levels. So nothing here is gated on a tier. SSS transmittance is Forward+ only
// and is not used. A back face's NORMAL is turned round by both renderers
// before fragment() runs, which is what `crown` below undoes; shot on both.
//
// Everything else -- colour space, what the air and the weather have done, what
// the land has done to it -- goes through the same three includes the world
// does, so a leaf is lit by exactly the same renderer, in exactly the same
// weather, as the ground under it.
//
// Vertex channels (kit.gd `_card` writes them):
//   COLOR.rgb  the leaf's wash, already darkened by how deep in the crown it sits
//   COLOR.a    one byte, / 255: the low LEAF_SHAPE_BITS say which sprig to cut
//              (LEAF_*), the rest how much snow lies on this card (0..LEAF_SNOW_STEPS)
//   NORMAL     the CROWN's normal, not the card's: see fragment()
//   UV         the card, 0..1: stem at v = 0, tip at v = 1
//   UV2        x wind sway weight, y phase -- which is also the card's seed
//
// SNOW IS A MATERIAL, NOT A LID. A laden pine used to carry a white tier laid
// over its needles and a snowfield bush a white clump on its crown, and under a
// real sun both read as the two things the cards had just removed from every
// other plant: a sliver of paper on the pine, a white dome on the bush. Snow
// lies on the side of a leaf that faces the sky, in lumps, and bridges the gaps
// between needles where it is deep -- so it is laid on HERE, per fragment, by
// how much the leaf faces up and where it stands, and the silhouette and the
// dapple stay the leaves'. It goes through sky_apply() and matter_albedo() with
// the leaf, in the snow ground's own wash, so it is lit as the drift under the
// tree is lit and never matched against it by eye: a white quad on snow was
// tried for footprints, and white shaded one way on white shaded another
// vanished.
shader_type spatial;
render_mode cull_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/render/sight.gdshaderinc"
#include "res://src/render/near_mask.gdshaderinc"
#include "res://src/render/wind.gdshaderinc"

// Where a crown must not hide a fight: world.gdshader's rule, word for word, and
// the same six slots 18_crowns writes into both materials every frame. A leaf is
// the thing that rule was written for.
const int CROWN_CLEAR = 6;
uniform vec4 crown_clear[CROWN_CLEAR];
const float CROWN_LIFT = 0.85;
const float CROWN_SWAY = 0.25;

// The sprigs, as kit.gd names them.
const int LEAF_BROAD = 1;
const int LEAF_SMALL = 2;
const int LEAF_NEEDLE = 3;
const int LEAF_SPINE = 4;
// The byte in COLOR.a, as kit.gd packs it: shape low, snow above.
const int LEAF_SHAPE_BITS = 3;
const int LEAF_SNOW_STEPS = 31;
// Lying snow: the snow ground's own wash (GroundColors SNOW, RIME[5]) and the
// step under it that a drift's lee is drawn in (world.gdshader, RIME[4]).
const vec3 SNOW_LIT = vec3(0.8667, 0.9412, 0.9686);
const vec3 SNOW_LEE = vec3(0.5882, 0.7529, 0.8157);
// Snow's surface, as matter_of() gives the snow ground (roughness, specular), so
// a lump on a bough answers the sun as the drift under it does.
const float SNOW_ROUGH = 0.74;
const float SNOW_SPEC = 0.5;
// How big a lump of snow is, in world units: a handful. Pinned to where the card
// RESTS, not where the wind has it, or the snow would crawl over the needles.
const float SNOW_LUMP = 0.14;
// The lump threshold at a trace of snow and at all a leaf can hold.
const float SNOW_BARE = 0.2;
const float SNOW_FULL = 0.56;

// How far a card's own face leads its light over the crown's volume normal.
// 0 is a dome again; 1 is sixty random facets. Found against the canon frames.
const float LEAF_FACE = 0.45;
// How much sun comes through a leaf lit from behind, and in what colour: a leaf
// passes green and yellow and keeps the blue.
uniform float through = 0.6;
const vec3 THROUGH_TINT = vec3(1.0, 1.15, 0.5);
// How much of the land's wear a leaf takes. Low, and below 0.5 on purpose:
// matter_worn grows SEAMS above 0.5, and a bough given 0.85 came back as a
// white crystalline star (fore.gdshader found it first).
const float LEAF_WEAR = 0.2;

// A card's flutter, as a share of what the wind alone gives it: in the lull
// between fronts, added at the height of a full gust (squared, so the front
// has an edge), and added again where a body is pushing through it.
const float LEAF_CALM = 0.3;
const float LEAF_GUST = 2.2;
const float LEAF_RUSTLE = 2.8;
// How much paler a leaf turned over by a full gust reads.
const float LEAF_UNDER = 0.35;

varying vec3 world_pos;
varying vec3 rest_pos;
varying float sway_w;
// How much gust stands on this card now, 0..1 (zero on what does not sway).
varying float gust_v;

void vertex() {
	sway_w = UV2.x;
	gust_v = 0.0;
	rest_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (sway_w > 0.0) {
		// The crown's sway is world.gdshader's, from the same globals, so a card
		// moves with the trunk it grew on and not to its own beat...
		vec3 push = wind_push(rest_pos, sway_w, UV2.y, 1.0);
		// ...and on top of it the tip of each card flutters on a faster beat of
		// its own, which is the one motion a solid crown could never make. A
		// whole multiple of the sky's phase, 5 to 8 by the card's seed, so it
		// quickens with the wind and never jumps where the phase wraps.
		float f = sky_wind.w * (5.0 + floor(UV2.y * 4.0)) + UV2.y * 40.0;
		// How hard it shivers: a little always, far more as a gust front reaches
		// this card (the same field that lays the grass over, so a front moves
		// the grass, then the bush, then the tree)...
		float g = gust_at(rest_pos.xz) * mix(0.45, 1.0, sky_wind.z);
		float shiver = LEAF_CALM + g * g * LEAF_GUST;
		gust_v = g * min(sway_w * 3.0, 1.0);
		// ...and where a body is pushing through a bush: the trample field under
		// a card low enough to be brushed, above the ground the player stands on.
		vec3 tr = trample_at(rest_pos.xz);
		float low = 1.0 - smoothstep(1.2, 2.2, rest_pos.y - crown_clear[0].y);
		shiver += (length(tr.xy) * 2.0 + tr.z) * low * LEAF_RUSTLE;
		push += vec3(sin(f), cos(f * 1.3) * 0.5, cos(f * 0.9)) * UV.y * sway_w * 0.02 * (0.3 + wind_strength) * shiver;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * (mat3(INV_VIEW_MATRIX) * wind_view(push, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE));
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// world.gdshader's crown_cut, unchanged: only what sways and stands clear of a
// point's own ground can open.
float crown_cut(vec3 wp, float sway) {
	if (sway < CROWN_SWAY) {
		return 0.0;
	}
	float cut = 0.0;
	for (int i = 0; i < CROWN_CLEAR; i++) {
		vec4 p = crown_clear[i];
		if (p.w <= 0.0 || wp.y < p.y + CROWN_LIFT) {
			continue;
		}
		float d = length(wp.xz - p.xz);
		cut = max(cut, 1.0 - smoothstep(p.w * 0.72, p.w, d));
	}
	return cut * clamp((sway - CROWN_SWAY) * 2.5, 0.0, 1.0);
}

// One leaf blade from `base`, pointing `a` radians off the card's +v, `len` long
// and `wid` wide at its widest. Above 0 inside it, 1 on its midrib.
float blade(vec2 p, vec2 base, float a, float len, float wid) {
	vec2 d = p - base;
	float along = d.x * sin(a) + d.y * cos(a);
	if (along <= 0.0 || along >= len) {
		return -1.0;
	}
	float across = d.x * cos(a) - d.y * sin(a);
	// Widest a third of the way out, and pointed at the tip.
	float w = wid * pow(sin(3.14159 * pow(along / len, 0.72)), 0.8);
	return 1.0 - abs(across) / max(w, 1e-4);
}

// A broadleaf sprig: a twig, a leaf at its end and one or two pairs along it.
float sprig_broad(vec2 uv, float seed, out float which) {
	which = 0.0;
	float best = -1.0;
	float lean = (ink_hash(vec2(seed, 1.0)) - 0.5) * 0.5;
	float v = blade(uv, vec2(0.5, 0.34), lean, 0.64, 0.19);
	if (v > best) { best = v; which = 1.0; }
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float y = 0.08 + fk * 0.22;
		float spread = 0.85 + ink_hash(vec2(seed, 2.0 + fk)) * 0.45;
		float len = 0.44 - fk * 0.04;
		// A leaf lost here and there, so no two sprigs are the same outline.
		if (ink_hash(vec2(seed, 5.0 + fk)) > 0.18) {
			v = blade(uv, vec2(0.5, y), spread, len, 0.15);
			if (v > best) { best = v; which = 2.0 + fk; }
		}
		if (ink_hash(vec2(seed, 7.0 + fk)) > 0.18) {
			v = blade(uv, vec2(0.5, y), -spread, len, 0.15);
			if (v > best) { best = v; which = 4.0 + fk; }
		}
	}
	return best;
}

// A cluster of rounded leaves standing out from a short twig: scrub, bramble.
// Five, not seven: a bush is seen smaller than a crown, and seven leaves to a
// card were three pixels each at the play camera -- a speckle, not a shrub.
float sprig_small(vec2 uv, float seed, out float which) {
	which = 0.0;
	float best = -1.0;
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		float h1 = ink_hash(vec2(seed + fk * 3.1, 11.0));
		float h2 = ink_hash(vec2(fk * 5.7, seed + 17.0));
		float ang = fk * 2.39996 + seed * 0.13;
		vec2 at = vec2(0.5, 0.5) + vec2(sin(ang), cos(ang)) * (0.05 + 0.2 * sqrt(h1));
		float a = atan(at.x - 0.5, at.y - 0.5) + (h2 - 0.5) * 0.9;
		float v = blade(uv, at - vec2(sin(a), cos(a)) * 0.1, a, 0.36 + h2 * 0.1, 0.17);
		if (v > best) { best = v; which = fk + 1.0; }
	}
	return best;
}

// A spray of needles off a twig. `stiff` 0 is a soft pine spray, 1 gorse spines:
// fewer, thicker, further off the twig. Gorse is seen small -- a whole bush is
// fifty pixels at the play camera -- and spines drawn at a pine's pitch and width
// were under a pixel wide, so the coast's scrub came back as glitter.
float sprig_needle(vec2 uv, float seed, float stiff, out float which) {
	which = 0.0;
	float bend = (ink_hash(vec2(seed, 5.0)) - 0.5) * 0.35;
	float x = uv.x - 0.5 - bend * uv.y * uv.y;
	float y = uv.y;
	float best = -1.0;
	if (y > 0.0 && y < 0.9 && abs(x) < 0.035) {
		best = 0.4;
	}
	// In the frame (|x|, y) a needle is the line y = y0 + |x| cot(ang): which row
	// a point belongs to is where its line meets the twig.
	float ang = mix(0.6, 1.0, stiff);
	float row = y - abs(x) * cos(ang) / sin(ang);
	float pitch = mix(0.085, 0.17, stiff);
	float k = floor(row / pitch + 0.5);
	float y0 = k * pitch;
	if (y0 < 0.04 || y0 > 0.86) {
		return best;
	}
	float along = abs(x) / sin(ang);
	float len = mix(0.4, 0.34, stiff) * (1.0 - y0 * 0.4) * (0.8 + 0.4 * ink_hash(vec2(seed, k + sign(x) * 0.5)));
	float w = mix(0.05, 0.1, stiff) * (1.0 - 0.6 * along / len);
	float dist = abs(row - y0) * sin(ang);
	if (along < len && dist < w) {
		float v = 1.0 - dist / w;
		if (v > best) { best = v; which = k * 2.0 + step(0.0, x); }
	}
	return best;
}

// Where deep snow can bridge the gaps of a sprig, above 0 inside: the inner part
// of a spray along its twig, and the heart of a cluster -- never out at the
// tips, so a laden bough is still cut to needles at its edge and never becomes
// the solid it replaced.
float snow_bed(int shape, vec2 uv, float seed) {
	if (shape == LEAF_NEEDLE || shape == LEAF_SPINE) {
		float bend = (ink_hash(vec2(seed, 5.0)) - 0.5) * 0.35;
		float x = uv.x - 0.5 - bend * uv.y * uv.y;
		// As wide on a gorse spray as on a pine's: a bed the width of the spines'
		// own reach laid snow along each twig as a white line, a sliver again.
		float reach = 0.24 * (1.0 - uv.y * 0.6);
		return min(1.0 - abs(x) / reach, min(uv.y - 0.04, 0.8 - uv.y) * 8.0);
	} else if (shape == LEAF_SMALL) {
		return 1.0 - length(uv - vec2(0.5)) / 0.2;
	}
	return min(1.0 - abs(uv.x - 0.5) / 0.1, min(uv.y - 0.06, 0.62 - uv.y) * 8.0);
}

float leaf_mask(int shape, vec2 uv, float seed, out float which) {
	if (shape == LEAF_SMALL) {
		return sprig_small(uv, seed, which);
	} else if (shape == LEAF_NEEDLE) {
		return sprig_needle(uv, seed, 0.0, which);
	} else if (shape == LEAF_SPINE) {
		return sprig_needle(uv, seed, 1.0, which);
	}
	return sprig_broad(uv, seed, which);
}

void fragment() {
	// The card's own face, taken before anything is discarded: derivatives are
	// only defined while the whole pixel quad is still running.
	vec3 face = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	face *= dot(face, VIEW) < 0.0 ? -1.0 : 1.0;
	if (near_cut > 0.5 && near_drawn(world_pos)) {
		discard;
	}
	vec2 px = matter_px(world_pos);
	// A fight is never hidden: stipple, never a fade.
	float cut = crown_cut(world_pos, sway_w);
	// And, for a close eye, every card in the line of sight to a body.
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		vec3 eye = INV_VIEW_MATRIX[3].xyz;
		float close = sight_close(eye, crown_clear[0]);
		if (close > 0.0) {
			for (int i = 0; i < CROWN_CLEAR; i++) {
				cut = max(cut, sight_cone(world_pos, eye, crown_clear[i]) * close);
			}
		}
	}
	if (cut > 0.0 && ink_hash(px + vec2(53.0, 11.0)) < cut) {
		discard;
	}
	int code = int(COLOR.a * 255.0 + 0.5);
	int shape = code & ((1 << LEAF_SHAPE_BITS) - 1);
	float laden = float(code >> LEAF_SHAPE_BITS) / float(LEAF_SNOW_STEPS);
	float seed = UV2.y * 97.0;
	// Godot turns NORMAL round for a back face before this code runs; turning it
	// back recovers the crown normal kit.gd wrote, whichever side of the card is
	// showing. The card's own face (above) is the dapple.
	vec3 crown = FRONT_FACING ? NORMAL : -NORMAL;
	float which = 0.0;
	float inside = leaf_mask(shape, UV, seed, which);

	// SNOW: how much of this pixel of leaf lies under it (see the header).
	float snow = 0.0;
	float deep = 0.0;
	if (laden > 0.0) {
		// Only the side that faces the sky holds any, and more of it on the top of
		// the crown than round its flanks; a drooping tip sheds what lands on it.
		float face_up = (INV_VIEW_MATRIX * vec4(face, 0.0)).y;
		float crown_up = (INV_VIEW_MATRIX * vec4(crown, 0.0)).y;
		float lie = laden * smoothstep(0.05, 0.6, face_up) * smoothstep(-0.45, 0.35, crown_up)
			* (1.0 - 0.6 * smoothstep(0.55, 0.95, UV.y));
		// In lumps: a handful across, pinned to where the leaf rests, with a little
		// of the sprig's own grain so no two lumps have the same edge.
		vec3 lp = rest_pos / SNOW_LUMP;
		float lump = ink_vnoise(lp.xz + lp.y * vec2(0.61, -0.37)) * 0.72
			+ ink_vnoise(UV * 3.3 + vec2(seed * 0.71, seed * 0.29)) * 0.28;
		// `lump` sits about 0.5 with a spread of about 0.12, so the threshold is
		// what share of a leaf is covered: a laden top about two thirds, the thin
		// fall on a snowfield pine's rim barely any, and a leaf turned to the side
		// none at all -- never a white tree with green holes in it.
		float t = mix(SNOW_BARE, SNOW_FULL, lie) * step(0.02, lie);
		snow = 1.0 - smoothstep(t - 0.05, t + 0.03, lump);
		// Where it lies deepest it fills the gaps between the needles, inside the
		// spray's own bed, and nowhere a leaf would not have held it up. The bed's
		// edge is the lump's own, so a lump is never ruled along its twig.
		float bed = step(0.0, snow_bed(shape, UV, seed) + (t - lump) * 1.2);
		if (shape == LEAF_NEEDLE || shape == LEAF_SPINE) {
			// A needle is a pixel wide: snow on one needle and not the gap beside
			// it is a white dot, and a band of them round every lump is glitter. On
			// a conifer the snow is the whole lump, needles and gaps alike, or none.
			deep = (1.0 - smoothstep(t - 0.03, t + 0.01, lump)) * bed;
			snow = deep;
		} else {
			deep = (1.0 - smoothstep(t - 0.07, t - 0.03, lump)) * bed;
			// A leaf inside a lump is under it as deeply as the gap beside it.
			snow = max(snow, deep);
		}
	}
	if (inside <= 0.0 && deep < 0.5) {
		discard;
	}
	vec3 c = COLOR.rgb;
	// Every leaf on a sprig its own value, so one card reads as several leaves,
	// and on a broad leaf a paler midrib, which is where a leaf folds. Only a
	// broad leaf is big enough on screen to carry either at full strength: on a
	// bush's or a needle's a midrib is one pixel and comes back as glitter.
	bool broad = shape == LEAF_BROAD;
	c *= 1.0 + (broad ? 0.24 : 0.1) * (ink_hash(vec2(which * 7.3 + seed, 3.1)) - 0.5);
	if (broad) {
		c *= mix(1.0, 1.1, smoothstep(0.82, 0.96, inside));
	}
	// A lump is lit at its crown and falls into its own lee at the rim, which is
	// the whole of how snow on a bough reads as lying ON it and not painted.
	vec3 snow_col = mix(SNOW_LEE, SNOW_LIT, 0.45 + 0.55 * max(deep, smoothstep(0.0, 0.6, snow)));
	c = mix(c, snow_col, snow);
	// A gust turns leaves over, and a leaf's underside is paler: a front shows
	// crossing a crown as it shows crossing the grass, and a still frame can
	// see where it is. Squared, so only the front and not the air round it.
	c = mix(c, c * (1.0 + LEAF_UNDER) + vec3(0.03, 0.035, 0.02), gust_v * gust_v * (1.0 - snow));
	c = sky_apply(c, world_pos, TIME);

	// THE LIGHT. Snow lies level whatever the leaf under it is doing, so where it
	// lies the normal is the sky's, as the drift's under the tree is.
	vec3 n = normalize(mix(crown, face, LEAF_FACE));
	n = normalize(mix(n, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, snow * 0.75));
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float rough_add = 0.0;
	c = matter_worn(c, matter_wear(world_pos), n_world, world_pos, LEAF_WEAR, rough_add);

	ALBEDO = matter_albedo(c);
	ROUGHNESS = clamp(mix(0.7, SNOW_ROUGH, snow) + rough_add, 0.04, 1.0);
	// A leaf has a waxy face: a little comes back off it at a glancing sun.
	SPECULAR = mix(0.36, SNOW_SPEC, snow);
	METALLIC = 0.0;
	NORMAL = n;
	// No sun comes through a lump of snow.
	BACKLIGHT = THROUGH_TINT * through * (1.0 - snow);
}

// No light(). The renderer lights a leaf against the same sun, sky and lamps as
// the ground, and BACKLIGHT is the renderer's own transmission term.
