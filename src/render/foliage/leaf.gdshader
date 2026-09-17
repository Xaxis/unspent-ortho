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
//   COLOR.a    which sprig to cut, LEAF_* / 255
//   NORMAL     the CROWN's normal, not the card's: see fragment()
//   UV         the card, 0..1: stem at v = 0, tip at v = 1
//   UV2        x wind sway weight, y phase -- which is also the card's seed
shader_type spatial;
render_mode cull_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

global uniform float wind_strength;

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

varying vec3 world_pos;
varying float sway_w;

void vertex() {
	sway_w = UV2.x;
	if (sway_w > 0.0) {
		// The crown's sway is world.gdshader's, from the same globals, so a card
		// moves with the trunk it grew on and not to its own beat...
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float t = TIME * (1.1 + wind_strength) + UV2.y * 6.283 + wp.x * 0.35 + wp.z * 0.21;
		float gust = 0.6 + 0.4 * sin(TIME * 0.37 + wp.x * 0.05 - wp.z * 0.03);
		vec3 push = vec3(sin(t) * 0.7 + 0.45, 0.0, cos(t * 0.8) * 0.5 + 0.3) * sway_w * 0.07 * (0.25 + wind_strength) * gust;
		// ...and on top of it the tip of each card flutters on a faster beat of
		// its own, which is the one motion a solid crown could never make.
		float f = TIME * (4.7 + UV2.y * 3.1) + UV2.y * 40.0;
		push += vec3(sin(f), cos(f * 1.3) * 0.5, cos(f * 0.9)) * UV.y * sway_w * 0.02 * (0.3 + wind_strength);
		vec3 vp = mat3(VIEW_MATRIX) * push;
		float texel = 2.0 / max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y, 1.0);
		vp.xy = round(vp.xy / texel) * texel;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * (mat3(INV_VIEW_MATRIX) * vp);
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
	vec2 px = matter_px(world_pos);
	// A fight is never hidden: stipple, never a fade.
	float cut = crown_cut(world_pos, sway_w);
	if (cut > 0.0 && ink_hash(px + vec2(53.0, 11.0)) < cut) {
		discard;
	}
	int shape = int(COLOR.a * 255.0 + 0.5);
	float seed = UV2.y * 97.0;
	float which = 0.0;
	float inside = leaf_mask(shape, UV, seed, which);
	if (inside <= 0.0) {
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
	c = sky_apply(c, world_pos, TIME);

	// THE LIGHT. Godot turns NORMAL round for a back face before this code runs;
	// turning it back recovers the crown normal kit.gd wrote, whichever side of
	// the card is showing. The card's own face (above) is the dapple.
	vec3 crown = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 n = normalize(mix(crown, face, LEAF_FACE));
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float rough_add = 0.0;
	c = matter_worn(c, matter_wear(world_pos), n_world, world_pos, LEAF_WEAR, rough_add);

	ALBEDO = matter_albedo(c);
	ROUGHNESS = clamp(0.7 + rough_add, 0.04, 1.0);
	// A leaf has a waxy face: a little comes back off it at a glancing sun.
	SPECULAR = 0.36;
	METALLIC = 0.0;
	NORMAL = n;
	BACKLIGHT = THROUGH_TINT * through;
}

// No light(). The renderer lights a leaf against the same sun, sky and lamps as
// the ground, and BACKLIGHT is the renderer's own transmission term.
