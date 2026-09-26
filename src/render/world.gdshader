// MADE: everything a person or the land made. Terrain, props, houses, people.
//
// LANTERN (docs/LOOK.md): the world is LIT, not drawn. There is no hatch, no
// paper grain, no ink line and no two-band shade in here any more, and there is
// no light() either -- the renderer does real physically-based lighting, and
// this shader's whole job is to say, per fragment, WHAT THE SURFACE IS:
//
//   ALBEDO     the colour, through matter_albedo() and nothing else
//   ROUGHNESS  how the light scatters off it (ice 0.16, dead ash 0.98)
//   SPECULAR   how much comes back at a glancing angle
//   METALLIC   0 for everything here but metal filings trodden into a floor
//   NORMAL     bent by the material's OWN relief in world space, so the sun
//              finds the pebble the wash draws (matter_bump)
//
// The big procedural library below -- ground_mark, ground_wear, strata,
// works_mark, survey_mark -- is kept, and it is the reason a landscape looks
// like itself. What changed is that it is now read as PIGMENT on a real
// surface rather than as marks on a page: its patterns are anchored to the
// world at a fixed grain (matter_px) instead of to the screen, so raising the
// resolution draws the same pebble with more pixels instead of a smaller one.
//
// Vertex channels (MeshKit writes them):
//   COLOR.rgb  wash colour (palette sRGB)
//   COLOR.a    MARK code / 255 (GroundColors): 0 or 1.0 = plain. The mark says
//              what the surface is MADE OF -- turf, shingle, ice, slag, salt --
//              and so it picks both its pigment and its material row.
//   CUSTOM0    rgb = second wash for an ecotone or ground edge, a = weight (0..1)
//   UV.x       landscape hand, style1 + style2 * 16. The hatch it used to pick
//              is gone; works_mark and survey_mark still read it to tell one
//              landscape's ground from another's.   UV.y  weight of that edge
//   UV2.x      wind sway weight (0 = rigid)
//   UV2.y      sway phase when swaying; on rigid geometry, how much the wash
//              breaks into large organic light/dark patches (0..1). Terrain
//              writes 2 + the second wash's mark code (patches at full).
shader_type spatial;
render_mode cull_back;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/render/sight.gdshaderinc"
#include "res://src/render/wind.gdshaderinc"
#include "res://src/render/salt_crust.gdshaderinc"

// Where a crown must not hide a fight (18_crowns writes it every frame): up to
// six points as (x, ground y, z, reach in tiles), reach 0 for an unused slot.
// Leaves and crowns above a point thin out to stipple and then to nothing
// within its reach, so the player and any body they can see are never covered.
const int CROWN_CLEAR = 6;
uniform vec4 crown_clear[CROWN_CLEAR];
// How far above a point's own ground a leaf has to be before it is in the way.
const float CROWN_LIFT = 0.85;
// Below this sway weight the geometry is a trunk, a wall or the land, and never
// opens. Both numbers are pinned by tests/render/test_crowns.gd.
const float CROWN_SWAY = 0.25;
// A TALL BUILT THING NEVER HIDES THE PLAYER EITHER. The line above says walls
// never open, and it was right for as long as a wall was a cottage wall you
// stand beside. It stopped being right the day a landscape could build upward:
// at this pitch a fragment draws over ground 1/tan(pitch) = 0.649 tiles further
// from the eye per unit of its height, so a six-storey block covers everything
// within four tiles behind it -- and a city street has a row of them on the near
// side, with the player walking between.
//
// Two things stop this opening holes in the world at large:
//
//   THE LAND NEVER OPENS. Only what somebody BUILT is cut: the ground band
//   `mark_land`, the same discriminator fore.gdshader uses to decide how much wear a
//   piece takes. A cliff, a terrace and a bank stay solid, so a player under an
//   overhang is still under it.
//
//   NOTHING A VILLAGE RAISES IS TALL ENOUGH. TALL_FLOOR is 3.0 and the tallest
//   form in `BiomeForms.PLAIN` is the steading at 2.8, so no village in the game
//   changes by a pixel and only the city's forms, the landmarks and the machines'
//   own works can ever stipple.
//   AND IT IS THE CAMERA'S NUMBER, NOT THE WORLD'S, so the lens moves it. 3.0
//   is right for a camera pitched 57 degrees, which sees OVER a two-metre post;
//   a third-person lens at 30 looks along the street and that same post stands
//   squarely between the eye and the player. So it is a uniform the camera sets
//   and it DEFAULTS TO 3.0, which is the shipped game unchanged.
//
//   It is NOT derived from the live lean, though that was the obvious move and
//   it is wrong: `42_target.LOCK_PITCH` is -4.5, so a target lock FLATTENS the
//   orthographic camera to 52.5 and a lean-derived floor would fall to about
//   2.54 -- under the steading's 2.8, stippling a village the moment the player
//   held Z, and breaking the guarantee three lines above this one.
uniform float tall_floor = 3.0;
// Wider than a crown's hole for the same reason ForeView's CLEAR_REACH is wider
// than 18_crowns': the higher the thing, the further off its own ground it draws.
const float TALL_WIDEN = 1.4;
// The machines' works cut into the ground (WorksMap): one texel per tile,
// R cut, G scorch, B quarry, A bores. works_inv_size 0 = no map (the gallery,
// hand-built worlds). works_dir: the survey bearing every ruled work lies on.
uniform sampler2D works_map : hint_default_black, filter_linear, repeat_disable;
uniform float works_inv_size = 0.0;
uniform vec2 works_dir = vec2(1.0, 0.0);
// The survey (GenWorks.survey_sections): R 1 where a stretch survives;
// works_survey = (phase along, phase across, spacing along, spacing across).
uniform sampler2D works_lines : hint_default_black, filter_linear, repeat_disable;
uniform vec4 works_survey = vec4(0.0, 0.0, 41.0, 59.0);
// The one-step shade: pushed toward blue-violet. Ink colour is darker still.
uniform vec3 shade_tint = vec3(0.66, 0.68, 0.82);
uniform vec3 ink_tint = vec3(0.42, 0.40, 0.55);
uniform float emission_strength = 0.0;
// How deep this thing's own relief runs, as a factor on the material row.
// The land keeps 1; a small prop or a figure turns it down so a hand-sized
// object is not covered in boulder-sized bumps.
uniform float relief = 1.0;
// A blow's paper-white, as a sphere in world space. See the end of fragment();
// found.gdshader carries the same three. MobFx.set_flash writes them into a
// COPY of a struck body's material, never into the world's own, which every
// tile and every animal draws with.
uniform vec3 flash_at = vec3(0.0);
uniform float flash_r = 0.0;
// Whether the land's growth takes this draw (matter_grown): 1 for what stands,
// 0 for what walks -- a figure or a machine does not stand still long enough.
uniform float grows = 1.0;
uniform vec3 flash_col = vec3(0.9098, 0.8627, 0.7529);

varying vec3 world_pos;
varying vec3 wash2;

#include "res://src/render/near_mask.gdshaderinc"
varying float wash_blend;
varying float style_packed;
varying float style_blend;
varying float patch_raw;
varying float sway_w;

const vec3 STEP = vec3(0.700, 0.704, 0.749);
const vec3 INK1 = vec3(0.0706, 0.0667, 0.1137);
const vec3 INK2 = vec3(0.1176, 0.1098, 0.1804);
const vec3 INK3 = vec3(0.1843, 0.1725, 0.2706);
const vec3 STONE0 = vec3(0.1059, 0.1216, 0.1686);
const vec3 STONE1 = vec3(0.1843, 0.2118, 0.2745);
const vec3 STONE2 = vec3(0.2902, 0.3333, 0.4000);
const vec3 SLATE1 = vec3(0.1373, 0.1843, 0.2392);
const vec3 SLATE2 = vec3(0.2157, 0.2824, 0.3529);
const vec3 BRINE0 = vec3(0.0392, 0.0824, 0.1412);
const vec3 BRINE2 = vec3(0.1059, 0.2471, 0.3765);
const vec3 BRINE4 = vec3(0.2627, 0.5725, 0.6902);
const vec3 BRINE5 = vec3(0.4980, 0.7961, 0.8471);
const vec3 EARTH0 = vec3(0.1020, 0.0706, 0.1255);
const vec3 EARTH1 = vec3(0.2000, 0.1373, 0.1216);
const vec3 EARTH2 = vec3(0.3098, 0.2118, 0.1529);
const vec3 EARTH3 = vec3(0.4353, 0.3020, 0.1922);
const vec3 EARTH4 = vec3(0.6000, 0.4392, 0.2667);
const vec3 RUST1 = vec3(0.2902, 0.1137, 0.0941);
const vec3 RUST2 = vec3(0.4314, 0.2000, 0.1255);
const vec3 RUST3 = vec3(0.6039, 0.3098, 0.1569);
const vec3 MOSS2 = vec3(0.1725, 0.2667, 0.1882);
const vec3 MOSS3 = vec3(0.2745, 0.4118, 0.2275);
const vec3 MOSS4 = vec3(0.4275, 0.5725, 0.2784);
const vec3 SPRUCE1 = vec3(0.0824, 0.1451, 0.1882);
const vec3 SPRUCE2 = vec3(0.1137, 0.2353, 0.2549);
const vec3 SPRUCE4 = vec3(0.2588, 0.5176, 0.4157);
const vec3 SAND2 = vec3(0.3608, 0.3020, 0.2706);
const vec3 SAND3 = vec3(0.5216, 0.4392, 0.3529);
const vec3 LINEN1 = vec3(0.2980, 0.2667, 0.2471);
const vec3 LINEN2 = vec3(0.4353, 0.3961, 0.3490);
const vec3 LINEN3 = vec3(0.5882, 0.5412, 0.4627);
const vec3 LINEN4 = vec3(0.7529, 0.7020, 0.5804);
const vec3 LINEN5 = vec3(0.9098, 0.8627, 0.7529);
// The ceiling on every pixel of salt crust (marks 55 and 57), and the colour of
// the one lit edge on it. The salt flats has no headroom: a frame holding two
// landscapes lifts every wash in it by the average of their grades, so a crust
// drawn near the page comes back CLIPPED across a border — no second wash, no
// shade band, no plate rim, no hatch (art review 1). Kept in step with
// src/content/biomes/salt_flats.gd (Ground.SALT) and src/models/props/salt.gd.
const vec3 SALT_TOP = vec3(0.6080, 0.5770, 0.5040);
const vec3 ASH1 = vec3(0.2314, 0.2510, 0.2902);
const vec3 ASH3 = vec3(0.5255, 0.5529, 0.6000);
const vec3 ASH4 = vec3(0.7216, 0.7490, 0.7882);
const vec3 EMBER2 = vec3(0.5765, 0.2000, 0.0471);
const vec3 EMBER3 = vec3(0.7843, 0.3529, 0.0824);
const vec3 EMBER4 = vec3(0.9608, 0.6471, 0.1843);
const vec3 RIME2 = vec3(0.2078, 0.3451, 0.4314);
const vec3 RIME3 = vec3(0.3647, 0.5451, 0.6275);
const vec3 RIME4 = vec3(0.5882, 0.7529, 0.8157);
const vec3 RIME5 = vec3(0.8667, 0.9412, 0.9686);
const vec3 BLOOM2 = vec3(0.6275, 0.2392, 0.4235);
const vec3 BLOOM3 = vec3(0.8157, 0.4353, 0.5725);

// WAS: ink_floor(), a floor lifted UNDER every albedo so the renderer's light
// could not crush a wash to black. It is gone, and what replaced it is a real
// ambient sky (SkyLight.NIGHT_AMBIENT) -- light, rather than a lie told to the
// albedo, which nothing downstream could take back out again.
// tests/render/test_dark_floor.gd holds both halves of the law it carried.

vec3 dn(vec3 c, float n) {
	return c * pow(STEP, vec3(n));
}

vec3 up(vec3 c, float n) {
	return min(c / pow(STEP, vec3(n)), vec3(1.0));
}

// A short pen stroke in a cell of `size` pixels: one cell in (1 - density) is
// empty; `len` pixels long, leaning `lean` pixels per pixel.
float stroke(vec2 px, vec2 size, float salt, float density, float len, float lean) {
	vec2 cell = floor(px / size);
	if (ink_hash(cell + vec2(salt, salt * 0.37)) > density) {
		return 0.0;
	}
	vec2 lp = px - cell * size;
	float ox = floor(ink_hash(cell + vec2(13.1, salt)) * max(size.x - 1.0 - abs(lean) * len, 1.0));
	float oy = floor(ink_hash(cell + vec2(salt, 27.7)) * max(size.y - len, 1.0));
	float dy = lp.y - oy;
	if (dy < 0.0 || dy >= len) {
		return 0.0;
	}
	return lp.x == ox + floor(dy * lean) ? 1.0 : 0.0;
}

// Pixel-scale raggedness for any threshold drawn on a world field, so every
// patch edge is the same crisp, torn line as a ground edge.
float rag(vec2 wp) {
	return (ink_vnoise(wp * 7.1 + 3.0) - 0.5) * 0.06;
}

float flicker(vec3 p, float rate) {
	return step(0.35, ink_hash(vec2(floor(TIME * rate), floor(p.x * 5.0) + floor(p.z * 7.0) * 13.0)));
}

// What a landscape holds at the zoom it is PLAYED at. The marks below are drawn
// at the scale of a blade, a pebble or a drift, and at the play camera they fall
// under a pixel and leave a flat colour field (playtest, wave N). So every
// ground also carries three reads between about 2 and 15 units, which is 50 to
// 350 screen pixels at the play camera: where it has been walked and worked,
// what was spilt or burnt or left standing on it, and the litter the ruin sheds.
// Sparse and low-contrast: a wash must still read as a wash.
// The four bands of wear are cut at the QUARTILES of `worn`, so each covers a
// quarter of the land and the ladder has a known middle at 1.5. Cutting on an
// even ramp instead left a third of the land in the lowest band and clamped the
// top, so the ladder's mean sat wherever the clamp happened to put it and wear
// pulled the whole land one way without anyone choosing it.
// WEAR_MID is where the ladder is pinned, half a band above that middle on
// purpose: two quarters of the land lift, one stays, one lays down. A crest
// nobody walks bleaches and gathers dust, and the open finding on the land is
// that it is too dark at noon, not too light.
// tests/render/test_ground_wear.gd holds the bands to a quarter each.
const vec3 WEAR_CUT = vec3(0.40, 0.50, 0.60);
const float WEAR_MID = 2.0;
vec3 ground_wear(int m, vec3 c, vec2 wp, vec2 px) {
	bool pale = m == 42 || m == 43 || m == 45;
	bool page = m == 44 || m == 51;    // snow and ice: the page itself, barely marked
	bool burnt = m == 46 || m == 47;
	float wear = page ? 0.18 : (pale ? 0.34 : 0.55);
	vec3 tramp = burnt ? INK2 : (pale ? LINEN1 : (page ? RIME2 : EARTH1));
	vec3 bare = burnt ? ASH1 : (pale ? SAND2 : (page ? RIME3 : EARTH2));
	// 1. Trodden and worked: the whole ground is laid in four flat bands of wear
	//    on torn edges (never a gradient, docs/LOOK.md law 2), from the lift where
	//    nothing goes to the bare ground showing through where everything does.
	//    Three octaves, so a screen holds features of about 3, 9 and 3 units.
	float worn = ink_vnoise(wp * 0.11 + 61.0) * 0.55 + ink_vnoise(wp * 0.31 + 13.0) * 0.3
		+ ink_vnoise(wp * 0.9 + 5.0) * 0.15 + rag(wp);
	float lay = step(WEAR_CUT.x, worn) + step(WEAR_CUT.y, worn) + step(WEAR_CUT.z, worn);
	// The bands are cut where `lay` says, but their EDGES are soft and their
	// steps shallow: at 0.75 of the wear per band and a hard step, four bands
	// of torn-edged two-tone patches read as a camouflage print over the whole
	// of the land (the crags, the drowned floor, the metropolis' squares).
	float soft = smoothstep(WEAR_CUT.x - 0.03, WEAR_CUT.x + 0.03, worn) + smoothstep(WEAR_CUT.y - 0.03, WEAR_CUT.y + 0.03, worn)
		+ smoothstep(WEAR_CUT.z - 0.03, WEAR_CUT.z + 0.03, worn);
	// The shallower steps keep the land's mean where the old ladder put it: the
	// mean band is 1.5, and the lift the old steps gave at it is added back.
	c = dn(c, (soft - WEAR_MID) * wear * 0.4 + (1.5 - WEAR_MID) * wear * 0.35);
	if (lay > 2.5 && ink_hash(px + 29.0) > 0.965) {
		c = mix(c, bare, 0.5);
	}
	// 2. A line walked through to the ground under it: it wanders, it stops, its
	//    edge is torn, and stones are trodden into it.
	float gate = ink_vnoise(wp * 0.03 + 44.0);
	float pw = (0.010 + ink_vnoise(wp * 0.35) * 0.012) * clamp((gate - 0.52) * 6.0, 0.0, 1.0);
	if (pw > 0.0) {
		float pd = abs(ink_vnoise(wp * vec2(0.055, 0.045) + 7.0) - 0.5) + rag(wp) * 0.12;
		if (pd < pw) {
			c = mix(c, tramp, (page ? 0.3 : 0.62) * (1.0 - 0.45 * smoothstep(pw * 0.5, pw, pd)));
			if (ink_hash(px + 3.0) > 0.95) {
				c = up(c, 0.35);
			}
		}
	}
	// 3. What was spilt, burnt or left standing: lobes with a torn rim.
	float st = ink_vnoise(wp * 0.22 + 91.0) * 0.7 + ink_vnoise(wp * 0.8 + 5.0) * 0.3 + rag(wp);
	if (st > 0.71 && !page) {
		c = mix(c, burnt ? INK1 : mix(tramp, RUST1, 0.4), clamp((st - 0.71) * 3.5, 0.0, 0.5));
	}
	// 4. Litter in drifts: two or three pixels of rust and plate, never an even
	//    scatter over the whole land.
	float drift = ink_vnoise(wp * 0.16 + 33.0) * 0.7 + ink_vnoise(wp * 0.6 + 77.0) * 0.3;
	if (drift > 0.66) {
		float h = ink_hash(px + 17.0);
		float much = (drift - 0.66) * 3.0;
		if (h > 1.0 - 0.0035 * much) {
			c = RUST2;
		} else if (h < 0.0025 * much) {
			c = pale || page ? SLATE2 : LINEN3;
		}
	}
	return c;
}

// The ground's own marks. wp: world xz. Marks are sparse: a wash stays a wash,
// and interest lives at edges and in rare features (docs/LOOK.md). Nothing
// tessellates. Returns the colour; may add emission and lift the hatching.
vec3 ground_mark(int m, vec3 c, vec2 wp, vec2 px, inout vec3 emit, inout float unh) {
	if (m == 40) {
		// TURF: tussock ticks leaning with the weather, a few bright blades.
		if (ink_vnoise(wp * 0.9) > 0.7) {
			c = dn(c, 0.3);
		}
		if (stroke(px, vec2(5.0, 4.0), 3.0, 0.42, 2.0, 0.5) > 0.5) {
			c = dn(c, 0.8);
		} else if (stroke(px, vec2(7.0, 6.0), 9.0, 0.16, 2.0, 0.5) > 0.5) {
			c = up(c, 0.5);
		}
	} else if (m == 41) {
		// HEATH: dark clumps with heather in bloom on their rims.
		float n = ink_vnoise(wp * 1.7) * 0.7 + ink_vnoise(wp * 4.1) * 0.3 + rag(wp);
		if (n > 0.56) {
			c = dn(c, 0.55);
			if (n < 0.59 && ink_hash(px) < 0.3 && ink_vnoise(wp * 0.07 + 3.0) > 0.7) {
				c = ink_hash(px + 1.3) < 0.5 ? BLOOM2 : BLOOM3;
			}
		} else if (n < 0.3) {
			c = up(c, 0.25);
		}
		if (stroke(px, vec2(4.0, 4.0), 5.0, 0.3, 2.0, 0.0) > 0.5) {
			c = dn(c, 0.6);
		}
	} else if (m == 42) {
		// SAND: wind ripples in broken lines, a speckle of shell and grit.
		float q = dot(wp, vec2(0.6, 0.8)) * 2.4 + ink_vnoise(wp * 0.3) * 2.5;
		float fr = fract(q);
		float gate = ink_vnoise(wp * vec2(1.3, 0.7));
		if (fr < 0.07 && gate > 0.35) {
			c = up(c, 0.3);
		} else if (fr > 0.07 && fr < 0.13 && gate > 0.45) {
			c = dn(c, 0.2);
		}
		// Shell grit and dark wrack crumbs, gathered along the tide's drifts.
		if (ink_vnoise(wp * 0.16 + 12.0) > 0.66) {
			float h = ink_hash(px);
			if (h > 0.985) {
				c = LINEN5;
			} else if (h < 0.015) {
				c = dn(c, 0.9);
			}
		}
	} else if (m == 43) {
		// SHINGLE: drawn pebbles, lit on the upper left and dark below, with the
		// ground showing between; now and then a piece of sea glass. The cells
		// they are found in are warped and each pebble is thrown well off its
		// own centre and turned its own way, so a beach is never an offset
		// lattice of identical lozenges (playtest, wave N; CLAUDE.md: no grid).
		// A wash of wet and weed lies over the whole of it, and pays the cells
		// no attention at all.
		vec2 qw = wp + vec2(ink_vnoise(wp * 0.09 + 3.0) - 0.5, ink_vnoise(wp * 0.09 + 21.0) - 0.5) * 2.6;
		vec2 q = qw * 6.0;
		vec2 i = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = ink_hash(i + 3.0);
		vec2 o = (vec2(ink_hash(i + 7.0), ink_hash(i + 11.0)) - 0.5) * 0.85;
		float pa = ink_hash(i + 17.0) * 3.1416;
		vec2 g = f - o;
		vec2 e = vec2(g.x * cos(pa) - g.y * sin(pa), g.x * sin(pa) + g.y * cos(pa)) * vec2(1.0, 1.05 + h * 0.9);
		float r = 0.24 + h * 0.22;
		float dd = length(e) + rag(wp) * 0.5;
		if (h > 0.18 && dd < r) {
			c = h < 0.45 ? dn(c, 0.35) : (h > 0.8 ? up(c, 0.3) : c);
			if (dd > r - 0.1) {
				c = (e.x + e.y) > 0.0 ? dn(c, 0.9) : up(c, 0.3);
			}
			if (h > 0.992) {
				// Sea glass: rubbed matt by the sea, a step under the shingle's
				// own light, never the brightest thing on the beach.
				c = mix(h > 0.996 ? SPRUCE2 : BRINE2, c, 0.3);
			}
		} else if (ink_hash(px + 2.0) < 0.2) {
			c = dn(c, 0.4);
		}
		float wash = ink_vnoise(wp * 0.28 + 44.0) * 0.7 + ink_vnoise(wp * 1.1 + 9.0) * 0.3 + rag(wp);
		if (wash > 0.64) {
			c = dn(c, 0.3);
		} else if (wash < 0.34) {
			c = up(c, 0.14);
		}
	} else if (m == 44) {
		// SNOW: drifts laid by one wind as short crescents, horns downwind:
		// a blue lee inside the curve, a broken pale crest on its back, soot in
		// a few lees. Open shapes, never closed loops, so no drift reads as a
		// frozen stream.
		vec2 wd = vec2(0.83, -0.55);
		vec2 q = vec2(dot(wp, wd), dot(wp, vec2(-wd.y, wd.x))) / vec2(3.4, 2.3);
		vec2 qi = floor(q);
		for (int yy = -1; yy <= 1; yy++) {
			for (int xx = -1; xx <= 1; xx++) {
				vec2 g = qi + vec2(float(xx), float(yy));
				float h = ink_hash(g + vec2(41.0, 7.0));
				if (h > 0.36) {
					continue;
				}
				vec2 ctr = g + vec2(ink_hash(g + 3.1), ink_hash(g + 8.7)) * 0.7 + 0.15;
				vec2 l = (q - ctr) * vec2(3.4, 2.3);
				// Long across the wind, thin along it; one horn often cut short.
				float squash = 0.38 + ink_hash(g + 5.5) * 0.3;
				float r = 0.6 + h * 1.6;
				float edge = rag(wp) * 1.5;
				float da = length(l * vec2(1.0, squash)) + edge;
				float db = length((l - vec2(r * (0.16 + ink_hash(g + 6.6) * 0.12), 0.0)) * vec2(1.0, squash * 1.05)) + edge;
				float horn = ink_hash(g + 9.9) < 0.5 ? l.y : -l.y;
				if (da < r && db > r * 0.9 && horn < r * (0.9 + ink_hash(g + 2.2) * 1.2)) {
					c = RIME4;
					if (da > r - 0.04 && ink_hash(floor(px / vec2(3.0, 1.0))) < 0.75) {
						// The crest, drawn on the drift's windward back.
						c = RIME3;
					} else if (h < 0.08 && db > r * 0.96 && ink_hash(px + 7.0) < 0.3) {
						c = ASH3;
					}
				}
			}
		}
		float g = ink_hash(px + 3.7);
		if (g > 0.997 && fract(TIME * 0.21 + g * 91.0) < 0.12) {
			c = vec3(1.0);
			emit += vec3(0.25);
		}
	} else if (m == 45) {
		// PAVEMENT: clints of pale limestone cut by grikes (ink cuts with a worn
		// pale lip and moss down in them). THE ONE LAW: it must never read as a
		// tiled floor (docs/LOOK.md section 8.1), so nothing about the grain is a
		// global constant.
		//  - the bearing turns and the rows bend, from a low-frequency domain
		//    warp: over tens of units the pavement runs a different way, and the
		//    warp is bounded at any world coordinate (a rotation by a field is not).
		//  - the pitch opens and closes, from a warp of the across axis by
		//    itself: rows are never evenly spaced.
		//  - the cross joints are sparse and lean hard, so the second family
		//    never closes the first into rectangles.
		//  - a clint is never filled light or dark as a whole: the value comes
		//    from a world field that walks straight across the joints.
		// Drill-hole rows on a few clints: the machine age in the stone.
		// Four octaves of warp, so the grain bends at every scale the camera can
		// be at. The two slow ones turn the bearing over tens of units, which a
		// wide frame reads; the two fast ones bend a joint inside a single
		// close-zoom screen, which spans about thirteen units — without them a
		// fight was fought on ruled parallel bars.
		vec2 warp = wp + vec2(ink_vnoise(wp * 0.022 + 3.0) - 0.5, ink_vnoise(wp * 0.022 + 29.0) - 0.5) * 14.0
			+ vec2(ink_vnoise(wp * 0.09 + 7.0) - 0.5, ink_vnoise(wp * 0.09 + 41.0) - 0.5) * 2.6
			+ vec2(ink_vnoise(wp * 0.13 + 19.0) - 0.5, ink_vnoise(wp * 0.13 + 61.0) - 0.5) * 1.1
			+ vec2(ink_vnoise(wp * 0.34 + 5.0) - 0.5, ink_vnoise(wp * 0.34 + 83.0) - 0.5) * 0.45;
		vec2 r = vec2(dot(warp, vec2(0.94, 0.34)), dot(warp, vec2(-0.34, 0.94)));
		// The pitch opens and closes twice over: slowly across tens of units, and
		// again from one row to the next, so no two neighbouring joints are the
		// same distance apart.
		// ...and the line itself wanders along its length at three scales, the
		// fastest of them under a unit — at the zoom a fight is fought at a joint
		// is seventy pixels of screen per unit, so without that last term a grike
		// is a ruled bar however far the bearing has turned since the last one.
		// The salt is the row's own, so no two joints wander together.
		float across = r.y
			+ (ink_vnoise(vec2(r.y * 0.06, 11.0)) - 0.5) * 5.0
			+ (ink_vnoise(vec2(r.y * 0.33, 23.0)) - 0.5) * 0.7
			+ (ink_vnoise(vec2(r.x * 0.22, 17.0)) - 0.5) * 0.4
			+ (ink_vnoise(vec2(r.x * 1.3, r.y * 0.26 + 31.0)) - 0.5) * 0.13
			+ (ink_vnoise(vec2(r.x * 3.3, r.y * 0.26 + 57.0)) - 0.5) * 0.055;
		const float ROW = 1.9;
		float row = floor(across / ROW);
		float fy = (across - row * ROW);
		float rh = ink_hash(vec2(row, 11.0));
		float along = r.x + rh * 11.0;
		float seg_len = 1.5 + rh * 1.6;
		float seg = floor(along / seg_len);
		float fx = along - seg * seg_len;
		float sh = ink_hash(vec2(row, seg));
		// A clint's ends are cut on their own slant, up to about 45 degrees.
		float lean = (ink_hash(vec2(row, seg + 3.0)) - 0.5) * 2.0;
		float end_x = fx + lean * fy;
		// A grike is a cracked line, not a ruled one: it pinches shut along its
		// length and opens again, and runs only a few blocks before it stops.
		float gw = (0.1 + ink_vnoise(vec2(r.x * 0.5, row * 7.0)) * 0.09 + rag(wp))
			* smoothstep(0.30, 0.56, ink_vnoise(vec2(along * 0.42, row * 3.7)))
			// ...and it pinches to a hairline and opens again every half unit, so
			// close up it is a crack and not a band of even width.
			* (0.5 + 0.5 * ink_vnoise(vec2(along * 1.9, row * 13.0)));
		bool grike_on = ink_hash(vec2(row, floor(along / 3.4) + 20.0)) < 0.58;
		bool cross_on = ink_hash(vec2(row, seg + 40.0)) < 0.42;
		float cw = 0.08 + rag(wp);
		// Weathering, not tiling: a field of pans and bleached backs that pays
		// no attention to where the joints run.
		float weather = ink_vnoise(wp * 0.55 + 21.0) * 0.65 + ink_vnoise(wp * 1.9 + 4.0) * 0.35 + rag(wp);
		c = weather < 0.36 ? dn(c, 0.13) : (weather > 0.68 ? up(c, 0.1) : c);
		bool in_grike = grike_on && fy < gw;
		bool in_cross = cross_on && end_x > 0.0 && end_x < cw;
		if (in_grike || in_cross) {
			c = ink_vnoise(wp * 0.7 + 2.0) > 0.55 ? MOSS2 : LINEN2;
			if ((in_grike && fy > gw * 0.3 && fy < gw * 0.75) || (in_cross && end_x > cw * 0.3 && end_x < cw * 0.7)) {
				c = INK3;
			}
		} else if ((grike_on && fy < gw + 0.06) || (cross_on && end_x >= cw && end_x < cw + 0.06)) {
			c = up(c, 0.2);
		} else if (grike_on && fy > ROW - 0.05) {
			c = dn(c, 0.28);
		} else {
			float pan = ink_vnoise(wp * 1.1 + vec2(row * 3.0, seg)) + rag(wp);
			if (pan > 0.87) {
				c = dn(c, 0.2);
			}
			if (sh > 0.88 && abs(fy - ROW * 0.5) < 0.06 && mod(px.x, 3.0) < 1.0 && fx > seg_len * 0.25 && fx < seg_len * 0.7) {
				// A row of drill holes across a clint: the machine age in the stone.
				c = LINEN1;
			}
		}
	} else if (m == 46) {
		// ASH: laid by the wind in long drifts, pale crests and scorched
		// troughs. In some stretches the ground is cracked and the cracks
		// still glow (unhatched): the embers gather there, never sprinkled
		// evenly. Now and then a leaf of burnt ruled paper.
		vec2 ad = vec2(0.9, -0.44);
		float along = dot(wp, ad);
		float across = dot(wp, vec2(-ad.y, ad.x));
		float band = ink_vnoise(vec2(along * 0.05, across * 0.45)) * 0.88 + ink_vnoise(wp * 0.3) * 0.12 + rag(wp);
		if (band > 0.66) {
			c = up(c, 0.3);
		} else if (band < 0.2) {
			c = mix(dn(c, 0.35), EARTH1, 0.25);
			if (stroke(px, vec2(6.0, 5.0), 17.0, 0.35, 2.0, -1.0) > 0.5) {
				c = dn(c, 0.6);
			}
		} else if (band > 0.58 && stroke(px, vec2(7.0, 3.0), 23.0, 0.3, 3.0, 2.0) > 0.5) {
			// Wind-combed streaks on the lee of a drift.
			c = up(c, 0.25);
		}
		float field = ink_vnoise(wp * 0.13 + vec2(17.0, 3.0)) * 0.75 + ink_vnoise(wp * 0.05 + 9.0) * 0.25;
		if (field > 0.68) {
			// Crust broken into plates; some seams still glow.
			vec3 cr = matter_cells(wp * 0.9 + (vec2(ink_vnoise(wp * 1.7), ink_vnoise(wp * 1.7 + 9.0)) - 0.5) * 0.35);
			float seam = cr.y - cr.x;
			float width = 0.045 * clamp((field - 0.68) * 12.0, 0.0, 1.0);
			bool live = ink_hash(vec2(floor(cr.z * 97.0), floor((cr.x + cr.y) * 3.0))) < 0.4 && field > 0.72;
			if (seam < width) {
				c = INK2;
				float eh = ink_hash(px);
				if (live && eh < 0.6) {
					float fl = flicker(vec3(floor(wp.x * 3.0), 0.0, floor(wp.y * 3.0)), 1.5 + eh * 5.0);
					c = mix(EMBER2, eh < 0.25 ? EMBER4 : EMBER3, fl);
					emit += c * (0.5 + 0.7 * fl);
					unh = 1.0;
				}
			} else if (seam < width * 2.2) {
				c = mix(dn(c, 0.45), RUST1, live ? 0.4 : 0.1);
			}
		}
		vec2 pc = floor(wp / 3.1);
		vec2 pl = wp - pc * 3.1;
		if (ink_hash(pc + 5.0) < 0.14) {
			vec2 o = vec2(0.6, 0.6) + vec2(ink_hash(pc + 8.0), ink_hash(pc + 9.0)) * 1.6;
			vec2 q = pl - o;
			float ang = ink_hash(pc + 11.0) * 3.0;
			vec2 r = vec2(dot(q, vec2(cos(ang), sin(ang))), dot(q, vec2(-sin(ang), cos(ang))));
			vec2 half_size = vec2(0.2, 0.14);
			vec2 e = abs(r) / half_size;
			float edge = max(e.x, e.y) + (ink_vnoise(wp * 9.0) - 0.5) * 0.35;
			if (edge < 1.0) {
				c = edge > 0.72 ? mix(EARTH1, INK2, 0.4) : LINEN4;
				if (edge <= 0.72 && abs(r.y + 0.02) < 0.018) {
					c = RIME3;
				} else if (edge <= 0.72 && abs(r.y - 0.06) < 0.014) {
					c = LINEN3;
				}
			}
		}
	} else if (m == 47) {
		// CLINKER: slag grit, rusted where water stood, with small pools of
		// vitrified glass: ink and spruce, a green glint, a rust rim that
		// here and there still glows. Never a large area of near black.
		float grit = ink_vnoise(wp * 0.3 + 2.0);
		if (grit > 0.55 && ink_hash(px + 5.0) > 0.86) {
			c = dn(c, 0.6);
		} else if (grit < 0.4 && ink_hash(px + 6.0) > 0.93) {
			c = up(c, 0.45);
		}
		if (ink_vnoise(wp * 0.5 + 8.0) > 0.72) {
			c = mix(c, RUST2, 0.35);
		}
		vec3 v = matter_cells(wp * 0.45);
		float r = 0.08 + v.z * 0.3;
		float dd = v.x + (ink_vnoise(wp * 3.1) - 0.5) * 0.16 + rag(wp);
		if (v.z < 0.3 && dd < r) {
			// Vitrified glass, not a hole: bottle green over black, a sheen of
			// the sky across it toward the key light, and bright glints.
			c = dd < r * 0.55 ? mix(INK2, SPRUCE2, 0.7) : mix(INK3, SPRUCE1, 0.5);
			float sheen = fract(dot(wp, vec2(0.62, -0.78)) * 1.7 + v.z * 11.0);
			if (dd < r * 0.8 && sheen < 0.16) {
				c = sheen < 0.06 ? RIME3 : mix(SPRUCE2, RIME3, 0.45);
				unh = 1.0;
			}
			float g = ink_hash(px + 2.0);
			if (dd < r * 0.7 && g > 0.93) {
				c = g > 0.97 ? RIME4 : SPRUCE4;
				unh = 1.0;
			}
		} else if (v.z < 0.3 && dd < r + 0.06 && dd >= r + 0.03) {
			// A pale crust where the glass ran out over the ash.
			c = mix(c, ASH3, 0.55);
		} else if (v.z < 0.3 && dd < r + 0.03) {
			c = mix(RUST1, RUST2, step(0.5, ink_hash(floor(px / 2.0))));
			if (v.z < 0.07 && ink_hash(px + 4.0) < 0.5) {
				float fl = flicker(vec3(floor(wp * 4.0), 1.0).xzy, 1.5);
				c = mix(EMBER2, EMBER3, fl);
				emit += c * (0.4 + 0.4 * fl);
				unh = 1.0;
			}
		}
	} else if (m == 48) {
		// FEN: hummocks and hollows, black pools with green edges, bog cotton.
		// Hummock and hollow are RELIEF (matter_height's FEN mounds): the wash only
		// leans with them, softly. Hard two-tone steps here were the camouflage
		// print over every mossy ground (the crags' lichened turf most of all).
		// The pools below are water and keep their shore.
		float n = ink_vnoise(wp * 0.95) * 0.7 + ink_vnoise(wp * 2.3 + 4.0) * 0.3 + rag(wp);
		c = up(c, 0.4 * smoothstep(0.56, 0.72, n));
		c = dn(c, 0.5 * (1.0 - smoothstep(0.24, 0.40, n)) * step(0.2, n));
		if (n > 0.64) {
			// Bog cotton in drifts on a few hummocks, none on the rest.
			if (ink_vnoise(wp * 0.12 + 40.0) > 0.68 && ink_hash(px) > 0.97) {
				c = LINEN5;
			}
		} else if (n < 0.2) {
			c = n < 0.165 ? BRINE0 : SPRUCE2;
		}
		if (ink_vnoise(wp * 0.45 + 20.0) > 0.78 && n > 0.33) {
			c = mix(c, RUST2, 0.55);
		}
		if (stroke(px, vec2(4.0, 4.0), 31.0, 0.22, 1.0, 0.0) > 0.5) {
			c = dn(c, 0.7);
		}
	} else if (m == 49) {
		// PEAT: fibrous dark ground, wet black patches, a little heather.
		if (stroke(px, vec2(4.0, 3.0), 12.0, 0.45, 2.0, 0.5) > 0.5) {
			c = dn(c, 0.6);
		} else if (stroke(px, vec2(5.0, 4.0), 19.0, 0.2, 2.0, -0.5) > 0.5) {
			c = up(c, 0.3);
		}
		if (ink_vnoise(wp * 0.8) + rag(wp) > 0.74) {
			c = mix(c, BRINE0, 0.6);
		}
		if (stroke(px, vec2(6.0, 6.0), 23.0, 0.12, 1.0, 0.0) > 0.5) {
			c = BLOOM2;
		}
	} else if (m == 50) {
		// NEEDLES: a brown floor swept into long curves by something on its
		// round: the contours of a slow field, drawn faint and broken.
		// Shafts of light fall through the canopy as long pale bands.
		float shaft = ink_vnoise(vec2(dot(wp, vec2(0.7, 0.7)) * 0.07, dot(wp, vec2(-0.7, 0.7)) * 0.55));
		if (shaft > 0.66 || (shaft > 0.63 && ink_hash(px + 3.0) < 0.5)) {
			c = up(c, 0.35);
		}
		float f = ink_vnoise(wp * 0.07) * 0.8 + ink_vnoise(wp * 0.21) * 0.2;
		float arc = fract(f * 9.0);
		float gate = ink_vnoise(wp * 0.6 + 2.0);
		if (arc < 0.06 && gate > 0.3) {
			c = up(c, 0.3);
		} else if (arc > 0.5 && arc < 0.54 && gate > 0.5) {
			c = dn(c, 0.3);
		}
		if (stroke(px, vec2(4.0, 3.0), 7.0, 0.35, 2.0, 1.0) > 0.5) {
			c = dn(c, 0.6);
		} else if (stroke(px, vec2(5.0, 4.0), 13.0, 0.15, 2.0, -1.0) > 0.5) {
			c = up(c, 0.35);
		}
	} else if (m == 51) {
		// ICE: pale streaks, long cracks, trapped bubbles.
		float st = ink_vnoise(vec2(dot(wp, vec2(0.89, 0.45)) * 0.25, dot(wp, vec2(-0.45, 0.89)) * 1.6));
		if (st > 0.7) {
			c = RIME5;
		} else if (st < 0.3) {
			c = dn(c, 0.3);
		}
		float crack = abs(ink_vnoise(wp * 0.6 + 5.0) - 0.5);
		if (crack < 0.012) {
			c = RIME3;
		} else if (crack < 0.03 && ink_hash(px) < 0.3) {
			c = RIME5;
		}
		if (ink_hash(px + 6.0) > 0.993) {
			c = RIME5;
		}
	} else if (m == 52) {
		// ROCK: bare stone: a few long cracks, lichen in small blooms. The stone's
		// own tone drifts softly; a hard threshold here drew two-tone patches
		// a few tiles across over every rocky land (the camouflage finding).
		c = dn(c, 0.25 * smoothstep(0.52, 0.72, ink_vnoise(wp * 0.35)));
		float crack = abs(ink_vnoise(wp * 0.8 + 1.0) - 0.5);
		if (crack < 0.014 && ink_vnoise(wp * 1.5) > 0.4) {
			c = dn(c, 1.0);
		} else if (crack < 0.03 && crack > 0.014) {
			c = up(c, 0.2);
		}
		float lich = ink_vnoise(wp * 2.2 + 6.0);
		if (lich > 0.87 && ink_hash(px + 8.0) < 0.3) {
			c = ink_vnoise(wp * 0.3) > 0.5 ? LINEN3 : MOSS3;
		}
	} else if (m == 53) {
		// MUD: puddles holding the sky, hoof-pocked.
		float pu = ink_vnoise(wp * 0.6) + ink_vnoise(wp * 1.8) * 0.25;
		if (pu > 0.9) {
			c = BRINE2;
		} else if (pu > 0.84) {
			c = dn(c, 0.6);
		}
		if (stroke(px, vec2(6.0, 5.0), 21.0, 0.25, 1.0, 0.0) > 0.5) {
			c = dn(c, 0.7);
		}
	} else if (m == 54) {
		// ROAD: worn, stones trodden in.
		float h = ink_hash(px);
		if (h > 0.96) {
			c = dn(c, 0.5);
		} else if (h < 0.03) {
			c = up(c, 0.3);
		}
		if (ink_vnoise(wp * 0.7) > 0.7) {
			c = dn(c, 0.2);
		}
	} else if (m == M_VITRIFIED) {
		// VITRIFIED: the glass desert's floor. Sand fused to a sheet in one
		// second and broken ever since, so four things are drawn and nothing
		// else is: the PLATES it cooled into (the same cells matter_height
		// tilts, so each plate's glare is its own), the heat CRAZING inside
		// each plate, the FLOW the melt set in -- smoke-green banding swirled
		// the way it ran -- and here and there a FULGURITE vein, the branching
		// track a strike burnt through it, pale fused sand in a dark scorch.
		vec3 cd = matter_cells(wp * 0.42);
		float crack = cd.y - cd.x;
		// Flow: banding along a warped direction, differing per plate a little
		// because each plate slid as it set.
		vec2 fw = wp + vec2(ink_vnoise(wp * 0.05 + 5.0), ink_vnoise(wp * 0.05 + 17.0)) * 12.0;
		float band = fract(dot(fw, vec2(0.52, 0.85)) * 0.45 + cd.z * 0.25);
		c = band < 0.22 ? mix(c, SPRUCE4, 0.22) : (band > 0.70 ? dn(c, 0.4) : c);
		// A hairline of paler glass along each band's edge: the set flow lines.
		if (abs(band - 0.22) < 0.012) {
			c = up(c, 0.3);
		}
		// Clouded patches where the sand did not quite melt: milky, not white.
		float cloud = ink_vnoise(wp * 0.23 + 40.0) * 0.7 + ink_vnoise(wp * 0.9) * 0.3;
		if (cloud > 0.7) {
			c = mix(c, mix(SLATE2, LINEN2, 0.35), clamp((cloud - 0.7) * 2.5, 0.0, 0.45));
		}
		// Crazing: where the sheet cooled fastest, a fine net of hairlines, lit
		// on one side. In patches only, and each line broken, so the floor never
		// reads as a laid pavement.
		float craze = ink_vnoise(wp * 0.12 + 55.0) * 0.8 + rag(wp) * 2.0;
		if (craze > 0.6) {
			vec3 cz = matter_cells(wp * 2.3 + cd.z * 7.0);
			float hair = cz.y - cz.x;
			if (hair < 0.03 && ink_vnoise(wp * 1.7 + cd.z * 3.0) > 0.5) {
				c = hair < 0.013 ? dn(c, 0.5) : up(c, 0.3);
			}
		}
		// Fulgurite veins: a ridged field thinned to lines that branch and
		// stop, scorched dark beside and fused pale along the middle.
		float vr = abs(ink_vnoise(wp * 0.33 + 71.0) - 0.5) + abs(ink_vnoise(wp * 0.9 + 13.0) - 0.5) * 0.35;
		float gate = ink_vnoise(wp * 0.05 + 29.0);
		if (gate > 0.56) {
			float w = 0.018 * clamp((gate - 0.56) * 8.0, 0.0, 1.0);
			if (vr < w * 0.45) {
				c = mix(LINEN3, SAND3, 0.4);
			} else if (vr < w * 2.2) {
				c = mix(c, INK2, 0.55);
			}
		}
		// The join between plates: a dark crack with a pale chipped lip -- but
		// only where it has opened. A crack runs a few plates and stops, and
		// its width wanders, so the plates never read as paving.
		float open = ink_vnoise(wp * 0.21 + 83.0) + rag(wp) * 1.5;
		float cw = 0.028 * smoothstep(0.42, 0.62, open);
		if (crack < cw) {
			c = mix(INK2, c, 0.2);
		} else if (crack < cw * 1.7) {
			c = up(c, 0.35);
		}
		// Glints: a few grains standing proud catch the sun.
		if (ink_hash(px + 23.0) > 0.994) {
			c = up(c, 0.9);
		}
	} else if (m == 55) {
		// SALT: the crust dries in plates a stride across and lifts at every
		// join, so the flat is a pale mosaic of raised rims over a duller floor.
		// Only some joins have lifted: a rim runs a few plates and stops, so the
		// pattern never reads as a net thrown over the ground. A lifted plate
		// stands OVER its neighbour — its edge takes the light and throws a line
		// of shadow on the plate it overhangs — so the crust has thickness and
		// never reads as paving. The floor of a plate is grained, not flat: salt
		// dries in grains and a few of them catch the sun.
		vec2 own;
		vec2 next;
		float join;
		salt_cells(wp, rag(wp) * 0.7, own, next, join);
		float ch = ink_hash(own + 11.0);
		// Plate against plate is a VALUE step, not a tint: the crust carries a
		// second wash under its first, so the flat still draws structure when a
		// neighbour's grade lifts the whole frame (art review 1 — clipped white
		// holds no wash, no shade, no plate and no hatch).
		c = ch < 0.3 ? dn(c, 0.12) : (ch > 0.72 ? up(c, 0.05) : c);
		// Grain across the plate, at its own angle: a dried floor, not a panel.
		float gr = ink_vnoise(wp * 4.1 + own * 3.3) * 0.7 + ink_vnoise(wp * 11.0) * 0.3;
		c = gr > 0.6 ? up(c, 0.07) : (gr < 0.33 ? dn(c, 0.12) : c);
		// A slow field of damp: where the pan never dried the crust takes a
		// mineral stain. ONE connected wash with its own shore, never a tint per
		// plate. It is the flat's shade band: wide enough to compose the frame,
		// pale enough that the crust around it still reads as the brightest
		// ground in the game.
		float damp = ink_vnoise(wp * 0.05 + 21.0) * 0.8 + ink_vnoise(wp * 0.19) * 0.2;
		float stain = smoothstep(0.68, 0.80, damp + rag(wp) * 1.5);
		if (stain > 0.0) {
			c = mix(c, mix(LINEN2, EARTH3, 0.45), stain * 0.26);
			// Brine still lying in the deepest of it: a SKIN, a finger deep, that
			// holds the sky rather than hiding the crust under it. One sheet
			// with its own shore — the damp field's contour decides where its
			// edge falls — never a sprinkle of blue over the flat.
			float pool = smoothstep(0.900, 0.918, damp + rag(wp) * 2.0);
			if (pool > 0.0) {
				vec3 skin = mix(mix(c, BRINE5, 0.45), BRINE4, step(0.88, ink_hash(px + 3.0)) * 0.5);
				c = mix(c, skin, pool);
			}
		}
		// Which joins have lifted: decided per pair, in runs, so a rim has ends,
		// and no two rims weigh the same.
		float lifted = salt_lifted(own, next);
		float weight = SALT_RIM_MIN + lifted * SALT_RIM_SPAN;
		if (lifted < SALT_LIFT && join < weight) {
			// The plate that sorts above rode up over the other: this side is
			// the lit edge of the lift, the other is under its overhang.
			bool over = own.x * 7.0 + own.y > next.x * 7.0 + next.y;
			if (join < weight * 0.3) {
				c = dn(c, 0.7);
			} else {
				c = over ? mix(dn(SALT_TOP, 0.35), SALT_TOP, lifted) : dn(c, 0.45);
			}
		} else if (join < 0.028 && ink_vnoise(wp * 0.9 + own * 1.7) > 0.55) {
			// An unlifted join is only a hairline, and only where it has opened:
			// every plate outlined drew a paved floor over the whole flat.
			c = dn(c, 0.18);
		}
		// THE PRESSURE RIDGES: the crust grows, has nowhere to go, and buckles up
		// along the edges of great polygons tens of plates across: a pale ridge
		// of salt pushed up and catching the light (its relief is matter_height's).
		// Two scales, so the flat is never one repeating tile.
		vec3 big = matter_cells(wp * 0.22 + vec2(ink_vnoise(wp * 0.05), ink_vnoise(wp * 0.05 + 7.0)) * 2.0);
		float ridge = 1.0 - smoothstep(0.0, 0.12 + max(fwidth(big.y - big.x), 1e-4), big.y - big.x);
		c = mix(c, min(up(c, 0.25), SALT_TOP), ridge * 0.7);
		float sh = ink_hash(px + 9.0);
		if (sh > 0.991) {
			c = up(c, 0.22);
		} else if (sh < 0.006) {
			c = dn(c, 0.45);
		}
	} else if (m == 57) {
		// PAN: the floor of an evaporation pan the brine drew back from. Damp
		// silt gone grey-brown, drying in a coarse net of cracks that are wide
		// and dark, with the tide lines of the water it lost drawn across it in
		// mineral stain, and a little salt left along the cracks.
		float net = ink_vnoise(wp * 0.45) * 0.7 + ink_vnoise(wp * 1.3) * 0.3;
		float cell = abs(fract(net * 7.0) - 0.5);
		// Tide lines: the pan lost its water in stages and marked each one.
		float stage = ink_vnoise(vec2(wp.x * 0.04 + wp.y * 0.02, 13.0));
		float line = abs(fract(stage * 22.0) - 0.5);
		if (line < 0.06) {
			c = mix(c, RUST2, 0.4);
		} else if (line < 0.12) {
			c = mix(c, EARTH3, 0.22);
		}
		if (cell < 0.035 + rag(wp)) {
			// A drying crack: dark, and salt gathered along its lip.
			c = cell < 0.016 ? dn(c, 0.8) : mix(c, LINEN4, 0.55);
		} else if (ink_vnoise(wp * 0.9 + 3.0) > 0.72) {
			c = up(c, 0.16);
		}
		float h = ink_hash(px);
		if (h > 0.985) {
			c = SALT_TOP;
		} else if (h < 0.015) {
			c = dn(c, 0.5);
		}
	} else if (m == 56) {
		// SWARF: rust grit and filings over the litter of a wood grown through
		// dead machines. The filings are not scattered: they lie in the arcs of
		// the fields still in the iron, so the ground is combed in long curves
		// that meet nothing. Between the arcs, wet leaf litter and bright
		// flecks of cut metal.
		float f = ink_vnoise(wp * 0.11) * 0.75 + ink_vnoise(wp * 0.4) * 0.25;
		float arc = fract(f * 11.0);
		float gate = ink_vnoise(wp * 0.5 + 7.0);
		if (arc < 0.17 && gate > 0.24) {
			// A drawn line of filings, standing on edge: the far side of the comb
			// is in its own shadow and the near side catches the light, so the
			// arc reads as iron combed up and not as a stain in the dirt.
			if (arc < 0.06) {
				c = dn(c, 0.95);
			} else if (arc < 0.115) {
				c = mix(c, STONE2, 0.62);
			} else {
				c = mix(c, RUST2, 0.5);
			}
		} else if (arc > 0.46 && arc < 0.56 && gate > 0.5) {
			// The next line over, fainter: the field drew more than one.
			c = arc < 0.5 ? mix(c, RUST3, 0.42) : dn(c, 0.3);
		}
		// Leaf litter over it all, gone to mulch in the hollows: warm brown
		// between the arcs, soft-edged, so the floor is a wood's and not a
		// swept yard's.
		float mulch = ink_vnoise(wp * 0.6 + 4.0) * 0.7 + ink_vnoise(wp * 2.1) * 0.3;
		if (arc >= 0.17) {
			c = mix(c, mix(EARTH2, RUST1, 0.35), smoothstep(0.45, 0.7, mulch) * 0.55);
		}
		c = dn(c, 0.4 * smoothstep(0.7, 0.85, ink_vnoise(wp * 1.3 + 4.0) + rag(wp)));
		// Cut shavings gather where something was broken up, not evenly over a
		// wood: a drift of them, and only a few bright enough to catch the eye.
		float drift = ink_vnoise(wp * 0.13 + 19.0);
		float h = ink_hash(px);
		if (drift > 0.66 && h > 0.985) {
			c = h > 0.996 ? ASH3 : mix(STONE2, RUST2, 0.35);
			unh = max(unh, 0.5);
		} else if (h < 0.025) {
			c = mix(c, RUST1, 0.5);
		}
	}
	return c;
}

// The machines' works laid into the ground (WorksMap): the rim of a work is
// torn by the hand's noise, what lies inside is ruled along the survey
// bearing. `wk` is the map at this point. Which work shows depends on the
// ground's own mark: rows in turf, drainage in the fen, tracks in the needles.
// `stump`: works_lines G here, above 0 within a tile of a stump.
vec3 works_mark(int m, vec3 c, vec2 wp, vec2 px, vec4 wk, float stump, int hand, inout vec3 emit, inout float unh) {
	vec2 d = works_dir;
	vec2 r = vec2(dot(wp, d), dot(wp, vec2(-d.y, d.x)));
	float torn = (ink_vnoise(wp * 0.55) - 0.5) * 0.5 + (ink_vnoise(wp * 2.7 + 7.0) - 0.5) * 0.18;
	// Where the land has begun to take a work back: patches of the ground's
	// own wash left over the ruled pattern.
	float regrow = ink_vnoise(wp * 0.32 + 31.0) * 0.7 + ink_vnoise(wp * 1.3 + 5.0) * 0.3 + rag(wp);
	float sc = wk.g + torn;
	if (sc > 0.5) {
		// Scorched: burnt dark in lobes, a little ash combed by the wind, the
		// odd ember still alive where it burnt hottest.
		float lobe = ink_vnoise(wp * 0.7 + 11.0) + rag(wp);
		c = mix(c, lobe > 0.55 ? EARTH0 : mix(INK3, EARTH1, 0.4), clamp((sc - 0.5) * 2.5, 0.0, 0.4));
		if (stroke(px, vec2(7.0, 4.0), 41.0, 0.12, 3.0, 2.0) > 0.5) {
			c = mix(c, ASH1, 0.6);
		}
		if (sc > 0.9 && ink_hash(px + 91.0) > 0.9985) {
			float fl = flicker(vec3(floor(wp.x * 3.0), 2.0, floor(wp.y * 3.0)), 2.0);
			c = mix(EMBER2, EMBER3, fl);
			emit += c * 0.5 * fl;
			unh = 1.0;
		}
	}
	float cut = wk.r + torn;
	// The pines' hand (UPRIGHT) marks a harvester's ground, whatever grows there.
	bool pines = hand == 3;
	if (cut > 0.5) {
		if ((m == 40 || m == 41) && !pines) {
			// Turf cut in rows: strips of bare peat ruled between strips left
			// standing, each row stopped where the cutter stopped; sods stacked
			// to dry on some standing strips; turf creeping back over the old.
			//
			// THE LAW HERE (art finding 4): the machines' order is RULED, and a
			// ruled line is not one line stamped five times. A frame carried four
			// or five bars of identical width at identical spacing with the same
			// grain in each, which reads as a texture rather than as work done.
			// So: the pitch opens and closes, every row is its own width, every
			// row runs from somewhere to somewhere and lifts here and there, and
			// a row's grain is its own — while all of them still lie dead
			// straight on the bearing, which is the part that says a machine.
			const float ROW = 1.9;
			// The pitch opens and closes over tens of units, so no two neighbouring
			// cuts are the same distance apart (the pavement's rule, in a straight field).
			float across = r.y + (ink_vnoise(vec2(r.y * 0.05, 3.0)) - 0.5) * 2.4;
			float row = floor(across / ROW);
			float fy = across - row * ROW;
			// A cutter's width is its own: the narrowest rows are half the widest.
			float wide = 0.30 + ink_hash(vec2(row, 3.0)) * 0.36;
			// A RUN is where the blade was down. Each row is a broken line of them,
			// its own runs at its own offset, and a run tapers away at both ends
			// instead of stopping square. The period is wider than a screen, so
			// nothing on the glass ever repeats.
			const float RUN = 26.0;
			float rx = r.x + ink_hash(vec2(row, 5.0)) * RUN;
			float seg = floor(rx / RUN);
			float sx = rx - seg * RUN;
			float len = RUN * (0.5 + ink_hash(vec2(row, seg) + 7.0) * 0.45);
			bool cutting = sx < len && ink_hash(vec2(row, seg) + 11.0) < 0.84
				&& regrow < 0.66 + ink_hash(vec2(row, 13.0)) * 0.12;
			float w = wide * clamp(min(sx, len - sx) * 1.6, 0.0, 1.0);
			if (cutting && fy < w) {
				c = mix(EARTH1, EARTH2, step(0.55, ink_hash(floor(px / vec2(3.0, 1.0)) + row)));
				// A row's grain is its own: combed finer or coarser, and never in
				// step with the row beside it.
				vec2 comb = vec2(3.0 + floor(ink_hash(vec2(row, 23.0)) * 4.0), 2.0 + floor(ink_hash(vec2(row, 29.0)) * 3.0));
				if (stroke(px, comb, 51.0 + row, 0.22 + ink_hash(vec2(row, 31.0)) * 0.26, 2.0, 0.5) > 0.5) {
					c = EARTH0;
				}
				// The shoulder the blade left, on whichever side it came down.
				float lip = ink_hash(vec2(row, 37.0)) < 0.5 ? fy : w - fy;
				if (lip < 0.06) {
					c = dn(c, 0.8);
				}
			} else if (cutting && fy < w + 0.08) {
				c = up(c, 0.25);
			} else if (cutting && ink_hash(vec2(row, 21.0)) < 0.4) {
				float sx = fract(r.x / 3.1 + row * 0.37);
				if (sx < 0.1 && fy > 1.0 && fy < 1.3 + rag(wp) * 3.0) {
					c = sx < 0.025 ? EARTH0 : EARTH1;
				}
			}
		} else if (m == 48 || m == 49 || m == 53) {
			// Drainage cuts: water cut straight into the peat on the bearing. A cut
			// narrows and silts up toward its ends and wherever the map fades it
			// (before a river, a road, a house); a green wet rim where the water
			// meets the peat, a spoil bank thrown up on one side, reeds on the
			// other; the sky caught in the water in broken glints, oil here and there.
			const float SPAN = 7.5;
			float lane = floor(r.y / SPAN);
			// Each cut was dug from its own start, and the digging stopped: it
			// silts to nothing over a few tiles at both ends.
			float from_x = -16.0 + ink_hash(vec2(lane, 5.0)) * 12.0;
			float to_x = from_x + 18.0 + ink_hash(vec2(lane, 6.0)) * 18.0;
			float live = smoothstep(0.55, 0.95, cut) * smoothstep(from_x, from_x + 4.0, r.x) * smoothstep(to_x, to_x - 4.0, r.x);
			float wob = ink_vnoise(vec2(r.x * 0.31, lane * 7.0 + 3.0)) - 0.5;
			float fy = r.y - (lane + 0.5) * SPAN - wob * 0.12;
			float dd = abs(fy);
			float wch = 0.17 * live * (0.8 + wob * 0.8);
			// Now and then a cross cut, as tapered, ending where it ends.
			float cx = abs(mod(r.x + ink_hash(vec2(lane, 17.0)) * 23.0, 23.0) - 11.5);
			bool cross_cut = ink_hash(vec2(lane, 3.0)) < 0.45 && dd < SPAN * 0.5 * live;
			float cw = 0.14 * live * smoothstep(SPAN * 0.5 * live, SPAN * 0.2 * live, dd);
			if (dd < wch || (cross_cut && cx < cw)) {
				// Water holding the sky, dark under its banks; silt fills the cut as
				// it dies away, water to brown to turf.
				float silt = clamp((0.75 - live) * 2.2, 0.0, 1.0);
				vec3 water = dd > wch * 0.55 ? BRINE0 : mix(BRINE0, BRINE2, 0.6);
				float g = ink_vnoise(vec2(r.x * 0.9, lane * 3.0));
				if (dd < wch * 0.55 && g > 0.62 && ink_hash(floor(px / vec2(3.0, 1.0)) + lane) < 0.55) {
					water = g > 0.74 ? BRINE4 : BRINE2;
				}
				c = mix(water, mix(EARTH1, SPRUCE2, 0.35), silt);
				if (silt < 0.2 && ink_vnoise(wp * vec2(0.23, 0.31) + 17.0) > 0.66) {
					float sheen = fract(r.x * 0.29 + ink_vnoise(wp * 0.8) * 1.6 + TIME * 0.02);
					if (sheen < 0.05) {
						c = mix(BRINE0, BLOOM2, 0.5);
						unh = 1.0;
					} else if (sheen > 0.4 && sheen < 0.44) {
						c = mix(BRINE0, SPRUCE4, 0.45);
						unh = 1.0;
					}
				}
			} else if (dd < wch + 0.09 * max(live, 0.3)) {
				// The wet rim.
				c = mix(c, SPRUCE2, 0.75);
			} else if (fy > 0.0 && fy < wch + (0.2 + 0.45 * live) * (0.75 + ink_vnoise(wp * 1.9) * 0.5)) {
				// The spoil bank: peat thrown up in sods on the far side.
				c = mix(c, EARTH2, 0.6);
				if (stroke(px, vec2(4.0, 3.0), 61.0, 0.4, 2.0, 0.0) > 0.5) {
					c = EARTH1;
				} else if (ink_hash(floor(px / vec2(3.0, 2.0)) + lane) > 0.82) {
					c = mix(c, EARTH3, 0.5);
				}
			} else if (fy < 0.0 && fy > -(wch + 0.5) && ink_hash(px + lane) > 0.8 && live > 0.2) {
				// Reeds along the near side.
				c = ink_hash(px + 3.1) < 0.5 ? SPRUCE2 : MOSS3;
			} else if (regrow < 0.6) {
				c = mix(c, EARTH2, 0.15);
			}
		} else if (m == 50 || pines) {
			// Harvester tracks: the machine drove its lanes on the bearing, but the
			// ground kept only pieces of them: short pairs of ruts where the wheels
			// sank, lanes at uneven spacing, brash thrown between the wheels, and
			// nothing near the rim of the cut or round a stump.
			float live = smoothstep(0.62, 0.95, cut);
			const float BAND = 4.4;
			float band = floor(r.y / BAND);
			float ly = r.y - band * BAND - (1.0 + ink_hash(vec2(band, 41.0)) * 2.4);
			const float SEG = 5.0;
			float sx0 = r.x + ink_hash(vec2(band, 43.0)) * SEG;
			float seg = floor(sx0 / SEG);
			float sx = sx0 - seg * SEG;
			float piece = 1.2 + ink_hash(vec2(band, seg) + 7.0) * 2.4;
			bool on = sx < piece && ink_hash(vec2(band, seg) + 11.0) < 0.75 && stump < 0.5;
			float gauge = 0.42 + ink_hash(vec2(band, seg)) * 0.12;
			float rut = min(abs(ly - gauge), abs(ly + gauge));
			float tip = clamp(min(sx, piece - sx) * 2.5, 0.0, 1.0) * live;
			if (regrow < 0.7) {
				c = dn(c, 0.1 * live);
			}
			if (on && rut < 0.085 * tip) {
				c = dn(c, 1.1);
			} else if (on && rut < 0.085 * tip + 0.05) {
				c = up(c, 0.2);
			} else if (on && abs(ly) < gauge - 0.12 && stroke(px, vec2(4.0, 3.0), 83.0, 0.4 * live, 2.0, 1.0) > 0.5) {
				// Brash between the wheels.
				c = mix(c, EARTH3, 0.7);
			}
			if (ink_hash(px + 13.0) > 0.996) {
				c = EARTH4;
			}
			if (stroke(px, vec2(7.0, 5.0), 71.0, 0.2, 3.0, -1.0) > 0.5) {
				c = EARTH3;
			}
		}
	}
	float qu = wk.b + torn;
	if (qu > 0.5 && (m == 45 || m == 52 || m == 43 || m == 40 || m == 41)) {
		// Benches cut in the grid: long blocks of stone lifted row by row, each
		// row a step down from the last; the long cuts ruled hard, the cross
		// cuts faint and unfinished; spoil and dust where a block broke.
		const vec2 CELL = vec2(4.6, 1.9);
		vec2 cell = floor(r / CELL);
		vec2 f = r - cell * CELL;
		float h = ink_hash(cell + 17.0);
		float depth = mod(cell.y, 3.0);
		c = mix(LINEN4, LINEN3, 0.3 + depth * 0.22);
		if (h > 0.84) {
			c = up(c, 0.15);
		}
		if (f.y < 0.08) {
			c = dn(c, 1.1);
		} else if (f.y < 0.16) {
			c = up(c, 0.35);
		} else if (f.x < 0.06 && ink_hash(cell + 3.0) < 0.6) {
			c = dn(c, 0.6);
		} else if (abs(f.y - CELL.y * 0.55) < 0.05 && h > 0.5 && mod(px.x, 3.0) < 1.0) {
			c = LINEN1;
		}
		if (regrow > 0.64) {
			c = mix(c, LINEN3, 0.35);
			if (ink_hash(px + 7.0) > 0.96) {
				c = LINEN2;
			}
		}
	}
	float bo = wk.a + torn;
	if (bo > 0.5) {
		// Bores in an exact grid, and the survey's paint run between them.
		const float BSTEP = 2.6;
		vec2 g = r / BSTEP;
		vec2 f = (fract(g) - 0.5) * BSTEP;
		float dh = length(f);
		if (dh < 0.1) {
			c = INK1;
		} else if (dh < 0.2) {
			c = up(c, 0.4);
		} else if (abs(f.y) < 0.03 && ink_hash(vec2(floor(g.y), 23.0)) < 0.5 && mod(floor(r.x * 3.0), 2.0) < 1.0) {
			c = mix(c, RUST3, 0.7);
		}
	}
	return c;
}

// The machines' survey lines, ruled across every landscape and kept in broken
// stretches: each ground carries one its own way (a lane through the pines, a
// ditch in the fen, prints in the snow, drill holes in the pavement, a scraped
// strip with a line of paint on the rest).
// `wet`: works_lines B, 1 where the survey may run as a wet ditch.
vec3 survey_mark(int m, vec3 c, vec2 wp, vec2 px, float wet, int hand) {
	vec2 d = works_dir;
	vec2 r = vec2(dot(wp, d), dot(wp, vec2(-d.y, d.x)));
	float sa = mod(r.y - works_survey.x + works_survey.z * 0.5, works_survey.z) - works_survey.z * 0.5;
	float sb = mod(r.x - works_survey.y + works_survey.w * 0.5, works_survey.w) - works_survey.w * 0.5;
	float da = abs(sa);
	float db = abs(sb);
	float dl = min(da, db);
	float signed_off = da < db ? sa : sb;
	if (dl > 1.2) {
		return c;
	}
	float along = da < db ? r.x : r.y;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	if (hand == 3 || m == 50) {
		if (dl < 1.05) {
			c = dn(c, 0.14);
		}
		if (abs(dl - 0.55) < 0.06) {
			c = dn(c, 0.7);
		} else if (abs(dl - 0.62) < 0.05) {
			c = up(c, 0.2);
		}
	} else if (m == 48 || m == 49 || m == 53) {
		// Deep in a wide fen the survey was cut as a ditch: narrow water with a
		// green rim and its spoil on one side, drying to a silted groove where
		// the fen ends or water or a house comes near. Elsewhere in the moss it is
		// only a trodden strip with the holes of its stakes.
		float live = smoothstep(0.3, 0.9, wet);
		float wob = ink_vnoise(vec2(along * 0.4, 5.0)) - 0.5;
		float off = signed_off - wob * 0.08;
		float w = 0.11 * live * (0.8 + wob * 0.7);
		if (live > 0.05 && abs(off) < w) {
			float silt = clamp((0.8 - live) * 2.5, 0.0, 1.0);
			vec3 water = abs(off) > w * 0.5 ? BRINE0 : mix(BRINE0, BRINE2, 0.6);
			float g = ink_vnoise(vec2(along * 0.9, 9.0));
			if (abs(off) < w * 0.5 && g > 0.6 && ink_hash(floor(px / vec2(3.0, 1.0)) + 37.0) < 0.55) {
				water = g > 0.72 ? BRINE4 : BRINE2;
			}
			c = mix(water, mix(EARTH1, SPRUCE2, 0.35), silt);
		} else if (live > 0.05 && abs(off) < w + 0.07) {
			c = mix(c, SPRUCE2, 0.7);
		} else if (live > 0.05 && off > 0.0 && off < w + (0.12 + 0.3 * live) * (0.75 + ink_vnoise(wp * 1.9) * 0.5)) {
			c = mix(c, EARTH2, 0.5);
			if (stroke(px, vec2(4.0, 3.0), 67.0, 0.35, 2.0, 0.0) > 0.5) {
				c = EARTH1;
			}
		} else if (live <= 0.05 && dl < 0.28) {
			c = mix(c, EARTH2, 0.22);
			float hole = abs(fract(along / 1.7) - 0.5) * 1.7;
			if (dl < 0.06 && hole < 0.06) {
				c = BRINE0;
			}
		}
	} else if (m == 44 || m == 51) {
		if (dl < 0.3 && mod(floor(along * 2.4), 2.0) < 1.0 && ink_hash(floor(px / 2.0) + 5.0) < 0.55) {
			c = RIME4;
		}
	} else if (m == 45) {
		float hole = abs(fract(along / 1.3) - 0.5) * 1.3;
		if (dl < 0.1 && hole < 0.1) {
			c = INK2;
		} else if (dl < 0.18 && hole < 0.18) {
			c = up(c, 0.3);
		} else if (dl < 0.03) {
			c = mix(c, RUST3, 0.5);
		}
	} else {
		if (dl < 0.3) {
			c = lum > 0.35 ? dn(c, 0.2) : up(c, 0.22);
		}
		if (dl < 0.035 && mod(floor(along * 1.6), 3.0) < 2.0) {
			c = lum > 0.35 ? mix(c, RUST2, 0.7) : mix(c, mix(LINEN3, ASH3, 0.5), 0.55);
		}
	}
	return c;
}

// THE DROWNED CITY'S TIDE. Every wall is marked the same way down from its own
// top (STRATA_TIDE): the flood's salt line TIDE_SALT under the lip, and weed
// from TIDE_WEED down. The floor is silted wherever it lies under TIDE_HIGH in
// world height, which is all but the city's highest ground.
const float TIDE_SALT = 0.12;
const float TIDE_WEED = 0.34;
const float TIDE_HIGH = 2.85;

// How far under the old high water a point lies, 0..1.
float tide_under(float y) {
	return 1.0 - smoothstep(TIDE_HIGH - 0.1, TIDE_HIGH + 0.2, y);
}

// Where a puddle stands on the drowned floor, 0..1 (TIDEFLAT): in the hollows of
// one slow field, with its own shore, most of them under the old high water.
// Read for the colour and again for the roughness, so the water is where it shows.
float tide_pool(vec3 wp) {
	float f = ink_vnoise(wp.xz * 0.09 + 17.0) * 0.75 + ink_vnoise(wp.xz * 0.37 + 3.0) * 0.25 + rag(wp.xz) * 1.2;
	return smoothstep(0.54, 0.58, f) * max(tide_under(wp.y), 0.6);
}

// TIDEFLAT: the drowned city's poured floor, and everything on it is the water's:
// the SILT the flood laid under the high line, in scalloped drift lines with a
// dark wrack dashed along each (the last tides' own marks); the cast floor's
// broken expansion joints on the slant the city was laid to; weed greening the
// rims of the standing water; and the water itself, black-green and still,
// taking the sky (its roughness is taken off in fragment()).
vec3 tide_floor(vec3 c, vec3 wp, vec2 px, inout vec3 emit) {
	float under = tide_under(wp.y);
	// The joints: bays six units across on a turned grid, drawn only where they
	// have opened, so it reads as a floor that was laid and never as a grid.
	vec2 q = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * wp.xz / 6.0;
	vec2 fq = abs(fract(q) - 0.5);
	float joint = 0.5 - max(fq.x, fq.y);
	if (joint < 0.012 && ink_vnoise(wp.xz * 0.4 + 7.0) > 0.45) {
		c = dn(c, 0.45);
	}
	if (under > 0.0) {
		// Silt: a grey-green skin over the concrete, heaviest in the low ground.
		float silt = ink_vnoise(wp.xz * 0.14 + 61.0) * 0.7 + ink_vnoise(wp.xz * 0.5) * 0.3;
		c = mix(c, mix(EARTH2, SPRUCE2, 0.45), under * clamp((silt - 0.3) * 1.8, 0.0, 0.7));
		// The drift lines: contours of the silt field, each a dark dashed wrack.
		float line = abs(fract(silt * 9.0 + rag(wp.xz) * 2.0) - 0.5);
		if (line < 0.03 && ink_vnoise(wp.xz * 1.7 + 11.0) > 0.42) {
			c = mix(c, INK2, 0.7 * under);
		}
	}
	float pool = tide_pool(wp);
	float rim = tide_pool(wp + vec3(0.35, 0.0, 0.2));
	if (pool > 0.0) {
		c = mix(c, mix(SPRUCE1, BRINE0, 0.4), pool * 0.85);
		// The water's edge: a dark wet line where it meets the silt.
		if (pool < 0.45) {
			c = dn(c, 0.4);
		}
		// What is in the water: whatever the port spilled, feeding a bloom
		// that glows a sick green along the puddles' edges in the dark. Only
		// in drifts and only at night (sky_view.y), faint: poisoned water,
		// not a lamp.
		// Over the whole of a puddle, faintly, and thickest where it drifts.
		// (Measured: on the puddles' edges alone it was under a pixel wide and
		// the frame did not move.)
		float bloom = 0.3 + 0.7 * smoothstep(0.5, 0.75, ink_vnoise(wp.xz * 0.2 + 33.0));
		emit += vec3(0.10, 0.34, 0.24) * 3.5 * bloom * pool * sky_view.y * (0.75 + 0.25 * sin(TIME * 0.7 + wp.x));
	} else if (rim > 0.0) {
		c = mix(c, MOSS2, rim * 0.6);
	}
	return c;
}

// WHAT THE WEATHER HAS DONE TO A TERRACE WALL, whatever it is cut through. Laid
// over a wall's own pattern, so it is the same few things everywhere and the
// wall's material still decides everything else:
//  - the LIP is ragged: the ground above overhangs by a depth that wanders along
//    the wall, and throws a dark band under itself, so the top is never ruled;
//  - RUN-OFF has stained the face in soft streaks from the lip, darkest where
//    it starts and fading as it runs down;
//  - the FOOT is darker and damper, where the wall meets the ground and what
//    fell off it has lodged, so the wall stands IN the land and not on it.
// It exists because the stepped terraces are what read as blocks, and a wall
// that is ruled at the top, flat down its face and cut clean at the foot is a
// box however it is painted.
vec3 strata_weather(vec3 c, float dt, vec2 px) {
	float over = 0.018 + ink_vnoise(vec2(px.x * 0.12, 71.0)) * 0.035 + ink_vnoise(vec2(px.x * 0.45, 73.0)) * 0.012;
	if (dt < over + 0.03 && dt >= over) {
		c = dn(c, 0.45 * (1.0 - (dt - over) / 0.03));
	}
	float run = ink_vnoise(vec2(px.x * 0.22, 77.0));
	float reach = 0.12 + ink_vnoise(vec2(px.x * 0.06, 79.0)) * 0.3;
	if (run > 0.58 && dt < reach) {
		c = dn(c, 0.3 * smoothstep(0.58, 0.75, run) * (1.0 - dt / reach));
	}
	float foot = smoothstep(0.34, 0.5, dt + (ink_vnoise(vec2(px.x * 0.1, 83.0)) - 0.5) * 0.08);
	c = mix(c, dn(c, 0.35), foot);
	return c;
}

// CITY_FLOOR: the metropolis' own floor. What a city's ground is after
// seventy years: poured slabs in bays on the city's own grid (turned, and
// drawn only where a joint has opened, so it is never a grid laid over the
// land), with grass up through the joints; the lane paint of a road nobody
// drives, faded to a few dashes; a crack spidered out from where something
// heavy came down; oil stains; and drifts of window glass from the towers,
// glinting (their roughness is taken off in fragment()).
float city_glass(vec2 wp) {
	float drift = ink_vnoise(wp * 0.07 + 91.0) * 0.8 + ink_vnoise(wp * 0.3) * 0.2;
	return smoothstep(0.62, 0.7, drift);
}

vec3 city_floor(vec3 c, vec3 wp, vec2 px) {
	vec2 q = mat2(vec2(0.97, 0.26), vec2(-0.26, 0.97)) * wp.xz;
	vec2 bay = q / vec2(5.0, 3.2);
	vec2 fq = abs(fract(bay) - 0.5);
	float joint = min(0.5 - fq.x, (0.5 - fq.y) * 0.64);
	float opened = ink_vnoise(wp.xz * 0.35 + 5.0);
	if (joint < 0.05 && opened > 0.4) {
		c = opened > 0.62 ? mix(c, MOSS2, 0.6) : dn(c, 0.4);
	}
	// Each slab a little different: poured on different days.
	c *= 1.0 + (ink_hash(floor(bay) + 3.0) - 0.5) * 0.08;
	// Lane paint along the old road, faded, in dashes, broken where worn.
	float lane = abs(fract(q.y / 7.0) - 0.5) * 7.0;
	if (lane < 0.08 && fract(q.x / 2.4) < 0.55 && ink_vnoise(wp.xz * 0.5 + 17.0) > 0.35) {
		c = mix(c, mix(LINEN4, SAND3, 0.3), 0.55);
	}
	// A crack spidered out from an impact.
	float sp = abs(ink_vnoise(wp.xz * 0.6 + 33.0) - 0.5) + abs(ink_vnoise(wp.xz * 1.7 + 41.0) - 0.5) * 0.4;
	if (sp < 0.018 && ink_vnoise(wp.xz * 0.06 + 7.0) > 0.5) {
		c = dn(c, 0.55);
	}
	// Oil, where vehicles stood.
	float oil = ink_vnoise(wp.xz * 0.18 + 71.0);
	if (oil > 0.74) {
		c = mix(c, INK3, clamp((oil - 0.74) * 3.0, 0.0, 0.4));
	}
	// Window glass, in drifts: dark specks, a few bright ones -- and only near
	// the eye. Far off a speck per pixel is noise, not glass (the city at eye
	// level came back as white pixel static), so the drift thins as a pixel
	// covers more ground.
	float near_eye = 1.0 - smoothstep(0.02, 0.07, length(fwidth(wp.xz)));
	float g = city_glass(wp.xz) * near_eye;
	if (g > 0.0) {
		float h = ink_hash(px + 51.0);
		// Only the dark of it is drawn. A painted bright speck is a white pixel
		// whatever the sun is doing; the glint is the light's, off the lower
		// roughness where the glass lies (fragment()), so it comes only toward
		// the sun.
		if (h > 1.0 - 0.05 * g) {
			c = mix(c, SLATE1, 0.4);
		}
	}
	return c;
}

// OVERGROWN: the green towers' floor, the city's own under the forest. Moss has
// come out of every joint first and spread from them, so the green follows the
// slabs' edges; roots run across it; leaves have gathered in the lee of the
// joints. What shows between is the old poured floor with its lane paint.
vec3 overgrow(vec3 c, vec3 wp, vec2 px) {
	vec2 q = mat2(vec2(0.97, 0.26), vec2(-0.26, 0.97)) * wp.xz;
	vec2 fq = abs(fract(q / vec2(5.0, 3.2)) - 0.5);
	float joint = min(0.5 - fq.x, (0.5 - fq.y) * 0.64);
	float spread = ink_vnoise(wp.xz * 0.12 + 13.0) * 0.8 + ink_vnoise(wp.xz * 0.5) * 0.2;
	float reach = 0.04 + spread * 0.45;
	float moss = 1.0 - smoothstep(reach * 0.7, reach, joint);
	c = mix(c, mix(MOSS2, SPRUCE2, ink_vnoise(wp.xz * 1.3)), moss * 0.85);
	// Roots: long, wandering, dark, from the canopy's trunks across the slab.
	float root = abs(ink_vnoise(vec2(dot(wp.xz, vec2(0.8, 0.6)) * 0.35, dot(wp.xz, vec2(-0.6, 0.8)) * 1.4)) - 0.5);
	if (root < 0.02 && ink_vnoise(wp.xz * 0.09 + 29.0) > 0.45) {
		c = mix(EARTH1, EARTH2, root * 30.0);
	}
	// Leaf litter in drifts, warm against the green.
	float leaf = ink_vnoise(wp.xz * 0.2 + 51.0);
	if (leaf > 0.64 && ink_hash(px + 13.0) > 0.55) {
		c = mix(c, ink_hash(px + 17.0) > 0.5 ? mix(EARTH3, RUST2, 0.4) : mix(MOSS3, EARTH2, 0.5), 0.7);
	}
	return c;
}

// The machines' status light: the one violet in the world that is theirs.
const vec3 STATUS_VIOLET = vec3(0.50, 0.34, 0.92);

// CAST_FLOOR: the server fields' floor, the machines' own and still maintained.
// Long cast runs on the survey's bearing, exact and swept, with a cable tray
// between each pair; in every tray a violet status strip, dashed, lit on the
// machines' power (so a strike stutters it, as it does every strip they own)
// and repeated to the horizon. Across the runs only the panel ends, faint, so
// the floor is ruled one way and never a grid. Coolant weeps from the trays in
// dark tongues, the one thing on it the machines do not clean.
vec3 cast_floor(vec3 c, vec3 wp, vec2 px, inout vec3 emit) {
	vec2 q = mat2(vec2(0.97, 0.26), vec2(-0.26, 0.97)) * wp.xz;
	float row = fract(q.y / 6.0) * 6.0;
	// The tray: a channel 0.5 wide in the middle of the gap between runs.
	float tray = abs(row - 3.0);
	if (tray < 0.28) {
		c = mix(INK2, INK3, 0.5);
		if (tray > 0.2) {
			c = mix(STONE2, LINEN3, 0.3);
		}
		// The strip: dashed, on the machines' power.
		if (tray < 0.07 && fract(q.x / 2.2) < 0.72) {
			float ndim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
			float on = max(neon_burn(ndim), 0.25) * sky_power();
			c = mix(mix(INK3, STATUS_VIOLET, 0.4), STATUS_VIOLET, on);
			emit += STATUS_VIOLET * 1.6 * on;
		}
	} else {
		// A run: the pour lines trowelled flat, exact.
		if (abs(row - 1.5) < 0.02 || abs(row - 4.5) < 0.02) {
			c = dn(c, 0.12);
		}
		// Panel ends across the run, faint.
		if (abs(fract(q.x / 9.0) - 0.5) > 0.497) {
			c = dn(c, 0.18);
		}
		// Coolant weeping out of the tray onto the run, in tongues.
		float weep = ink_vnoise(vec2(q.x * 0.4, 7.0));
		if (weep > 0.66 && tray < 0.9 + (weep - 0.66) * 3.0) {
			c = mix(c, mix(SPRUCE1, INK2, 0.5), 0.5);
		}
	}
	return c;
}

// The machine city's own light: cold, exact, white with the least blue in it.
const vec3 GUIDE_WHITE = vec3(0.70, 0.82, 0.95);

// MACHINE_DECK: the machine city's floor, built for what drives on it. Plate in
// an exact running bond on the survey bearing (never a square grid: every
// course is offset half a plate), each plate a hair different in its temper,
// fastened in exact rows at its ends; and guide lines for the traffic: a lane
// edge every eight units, and down the middle of each lane a row of arrows
// pointing the way it runs, lit cold on the machines' power when the light goes.
// Nothing weathers here and nothing is left lying: no wear, no litter.
vec3 machine_deck(vec3 c, vec3 wp, vec2 px, inout vec3 emit) {
	vec2 q = mat2(vec2(0.97, 0.26), vec2(-0.26, 0.97)) * wp.xz;
	float course = floor(q.y / 1.5);
	float pl = (q.x + mod(course, 2.0) * 1.5) / 3.0;
	float fy = fract(q.y / 1.5);
	float fx = fract(pl);
	c *= 1.0 + (ink_hash(vec2(floor(pl), course) + 7.0) - 0.5) * 0.06;
	float fwq = max(length(fwidth(q)), 1e-4);
	// Plate seams, filtered so a far seam fades rather than aliases.
	float seam = min(min(fx, 1.0 - fx) * 3.0, min(fy, 1.0 - fy) * 1.5);
	c = mix(dn(c, 0.35), c, smoothstep(0.0, 0.02 + fwq, seam));
	// Fastener rows at each plate's ends.
	float fast = abs(fract(q.y / 0.3) - 0.5);
	if (min(fx, 1.0 - fx) * 3.0 < 0.1 && fast < 0.12) {
		c = mix(c, STONE2, 0.5);
	}
	// Lane edges and the arrows down each lane.
	float lane = fract(q.y / 8.0) * 8.0;
	float edge = min(lane, 8.0 - lane);
	float ndim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
	float on = max(neon_burn(ndim), 0.0) * sky_power();
	float line = 1.0 - smoothstep(0.05, 0.05 + fwq, edge);
	float mid = abs(lane - 4.0);
	float ax = fract(q.x / 5.0) * 5.0;
	float arrow = (ax < 1.2 && mid < 0.5 - ax * 0.4 && mid > 0.3 - ax * 0.4) ? 1.0 : 0.0;
	float guide = max(line, arrow);
	if (guide > 0.0) {
		// Held low: a guide for a machine's sensor, not a lamp for anybody's
		// eyes. At full strength the lines ruled bright scratches across the
		// slums' dusk next door (canon 08).
		c = mix(c, mix(mix(c, GUIDE_WHITE, 0.25), mix(c, GUIDE_WHITE, 0.7), on), guide);
		// Held low by day and dusk, and full only once night has fallen
		// (sky_view.y): then the ruled lines are the city, to the horizon.
		emit += GUIDE_WHITE * mix(0.45, 4.0, sky_view.y) * on * guide;
	}
	return c;
}

// SULPHUR: the crust the vents' water laid. Sinter in lobed terraces, each
// pool rimmed with a pale lip standing proud (matter_height) and floored in
// warm water gone milky; sulphur growing yellow in crystal clusters where the
// steam condenses, thickest on the rims; iron runs bleeding orange down the
// steps; and the wet of it all, which never dries (its roughness in fragment()).
vec3 sulphur_crust(vec3 c, vec3 wp, vec2 px) {
	vec2 p = wp.xz;
	vec3 cd = matter_cells(p * 0.9 + vec2(ink_vnoise(p * 0.4), ink_vnoise(p * 0.4 + 9.0)) * 1.5);
	float rim = cd.y - cd.x;
	float fw = max(fwidth(rim), 1e-4);
	// The pool floor is the land's own wash, the sulphur yellow that names the
	// place (the only yellow in the game), a shade deeper under the water.
	vec3 pool = mix(dn(c, 0.25), SPRUCE2, 0.12);
	vec3 sinter = mix(LINEN3, SAND3, 0.5);
	float lip = 1.0 - smoothstep(0.06 - fw, 0.06 + fw, rim);
	c = mix(pool, sinter, lip);
	// Sulphur: yellow crystals on the rims, clustered.
	float sul = ink_vnoise(p * 1.6 + cd.z * 7.0) * 0.7 + ink_vnoise(p * 5.0) * 0.3;
	c = mix(c, c * 0.3 + vec3(0.78, 0.66, 0.16) * 0.7, smoothstep(0.55, 0.72, sul) * mix(0.45, 1.0, lip));
	// Iron runs, orange, down the steps in one direction.
	float run = ink_vnoise(vec2(dot(p, vec2(0.8, 0.6)) * 2.5, dot(p, vec2(-0.6, 0.8)) * 0.4));
	c = mix(c, mix(RUST3, EMBER4, 0.3), smoothstep(0.68, 0.8, run) * 0.6);
	return c;
}

// DESERT_PAVEMENT: the mesas' floor, where the wind has taken the fine sand and
// left the stones: packed tight, each a small dome, the tops varnished dark by
// the sun and the sides the red of the ground; and in the lee of anything, red
// sand lying in ripples. Nothing else here moves.
vec3 desert_pavement(vec3 c, vec3 wp, vec2 px) {
	vec2 p = wp.xz;
	// Stones of every size, not a pattern: two scales of cells, thinned by a
	// field, so the pavement is packed in places and open sand in others, and
	// the varnish is a shade on each stone, never a hole punched in the floor.
	float packed = smoothstep(0.3, 0.6, ink_vnoise(p * 0.2 + 3.0));
	vec3 cd = matter_cells(p * 7.0 + ink_vnoise(p * 1.1) * 0.8);
	vec3 cd2 = matter_cells(p * 3.1 + 17.0);
	float fw = max(fwidth(cd.x), 1e-4);
	float r1 = 0.18 + cd.z * 0.18;
	float stone = (1.0 - smoothstep(r1 - fw, r1 + fw, cd.x)) * step(0.35, cd.z);
	float big = (1.0 - smoothstep(0.22 - fw, 0.22 + fw, cd2.x)) * step(0.8, cd2.z);
	vec3 varnish = mix(c, mix(RUST1, EARTH1, 0.4), 0.35 + cd.z * 0.15);
	c = mix(c, varnish, max(stone * packed, big) * 0.8);
	// Drifts of red sand in the lee, rippled across the wind.
	float lee = ink_vnoise(p * 0.12 + 5.0) * 0.8 + ink_vnoise(p * 0.5) * 0.2;
	float sand = smoothstep(0.58, 0.7, lee);
	if (sand > 0.0) {
		float rip = sin(dot(p, vec2(0.6, 0.8)) * 7.0 + ink_vnoise(p * 0.6) * 4.0);
		vec3 drift = mix(SAND3, RUST3, 0.45) * (1.0 + 0.08 * rip);
		c = mix(c, drift, sand);
	}
	return c;
}

// SEA_ICE: the frost sea's floor, which is the sea's lid. Floes frozen together,
// each its own white, their rafted edges ridged up and bright where one rode
// over the next (relief); between the floes, where the lead froze last, thin
// BLACK ice the sea shows through, strung with frozen bubbles and near a
// mirror (its roughness in fragment()); and snow dust blown along the wind in
// streaks. No square anything: the floes are the cells of a warped field.
float sea_black(vec2 p) {
	vec3 cd = matter_cells(p * 0.35 + vec2(ink_vnoise(p * 0.2), ink_vnoise(p * 0.2 + 5.0)) * 1.2);
	float lead = 1.0 - smoothstep(0.05, 0.3, cd.y - cd.x);
	return lead * smoothstep(0.3, 0.5, ink_vnoise(p * 0.15 + 21.0));
}

vec3 sea_ice(vec3 c, vec3 wp, vec2 px) {
	vec2 p = wp.xz;
	vec3 cd = matter_cells(p * 0.35 + vec2(ink_vnoise(p * 0.2), ink_vnoise(p * 0.2 + 5.0)) * 1.2);
	float fw = max(fwidth(cd.y - cd.x), 1e-4);
	c *= 1.0 + (cd.z - 0.5) * 0.08;
	// The rafted edge: a bright ridge where two floes met.
	// A bright crest with a blue shadow on its lee side, so the ridge reads on
	// ice that is already pale.
	float ridge = 1.0 - smoothstep(0.02 - fw, 0.06 + fw, cd.y - cd.x);
	float lee = (1.0 - smoothstep(0.06, 0.14 + fw, cd.y - cd.x)) - ridge;
	c = mix(c, mix(RIME3, SLATE2, 0.3), clamp(lee, 0.0, 1.0) * 0.5);
	c = mix(c, RIME5, ridge * 0.8);
	// Black ice in the frozen leads.
	float black = sea_black(p);
	if (black > 0.0) {
		vec3 dark = mix(BRINE0, SLATE1, 0.4);
		// Bubbles frozen in it, in strings.
		float bub = ink_vnoise(vec2(dot(p, vec2(0.7, 0.7)) * 3.0, dot(p, vec2(-0.7, 0.7)) * 0.6));
		dark = mix(dark, RIME3, smoothstep(0.78, 0.9, bub) * 0.6);
		c = mix(c, dark, black * 0.85);
	}
	// Snow dust along the wind.
	float dust = ink_vnoise(vec2(dot(p, vec2(0.83, -0.55)) * 0.3, dot(p, vec2(0.55, 0.83)) * 1.8));
	c = mix(c, RIME5, smoothstep(0.6, 0.78, dust) * 0.5 * (1.0 - black));
	return c;
}

// Terrace walls: each country's rock, banded by world height. dt: depth below
// the wall's top (a wall is one level tall).
vec3 strata(int id, vec3 c, vec3 wp, vec2 px, inout vec3 emit, inout float unh) {
	float y = wp.y;
	float top = (floor(y / 0.5 - 0.002) + 1.0) * 0.5;
	float dt = top - y;
	float col = floor(px.x / 2.0);
	float vn = ink_vnoise(vec2(px.x * 0.07, y * 3.0));
	if (id == 1) {
		// COAST: a turf-cut face, dark roots under the sod, then pale weathered
		// beds with white streaks below the ledges: lighter than any water, so
		// a one-level step never reads as a ditch.
		// Beds run with the wall at a slant and break off, so a long one-step
		// wall is a bank of soil, not a rail with posts along it.
		float b = (y + (vn - 0.5) * 0.08 + px.x * 0.004) / 0.11;
		// Each bed's tone drifts along it on a smooth field. It was a hash per
		// 23-pixel run of each bed, which cut every bed into blocks of one length.
		float h = ink_vnoise(vec2(px.x * 0.045, floor(b) * 1.7 + 3.0));
		c = h < 0.35 ? dn(c, 0.15) : (h > 0.68 ? up(c, 0.12) : c);
		if (fract(b) < 0.1 && ink_vnoise(vec2(px.x * 0.05, floor(b))) > 0.45) {
			c = dn(c, 0.3);
		}
		float sod = 0.07 + vn * 0.05;
		if (dt < sod) {
			c = dt < sod - 0.025 ? EARTH3 : EARTH1;
		} else if (ink_hash(vec2(px.x, 5.0)) > 0.9 && dt < sod + ink_hash(vec2(px.x, 6.0)) * 0.12) {
			// Roots hanging from the sod, uneven.
			c = EARTH2;
		}
	} else if (id == 2) {
		// MOSS: a deep peat bank, fibrous, over dark wet rock. The fibres run
		// DOWN the cut (it is a bank of roots and dead moss, sliced), and the
		// peat's foot wanders over the rock in a ragged line; moss hangs off the
		// rock in soft runs. Smooth fields only: a hash per pixel cell here read
		// as a wall of little bricks at eye level.
		float peat = 0.3 + (vn - 0.5) * 0.12 + (ink_vnoise(vec2(px.x * 0.09, 5.0)) - 0.5) * 0.12;
		if (dt < peat) {
			float fib = ink_vnoise(vec2(px.x * 0.7, y * 5.0)) * 0.7 + ink_vnoise(vec2(px.x * 2.1, y * 1.5)) * 0.3;
			c = mix(EARTH0, EARTH1, smoothstep(0.3, 0.7, fib));
			// A paler layer where the bog grew in a dry century.
			if (abs(fract(y * 5.5 + vn * 0.8) - 0.5) < 0.06) {
				c = mix(c, EARTH2, 0.6);
			}
		} else {
			c = SLATE1;
			float moss = ink_vnoise(vec2(px.x * 0.15, 2.0)) - smoothstep(peat, peat + 0.35, dt) * 0.5;
			c = mix(c, SPRUCE2, smoothstep(0.45, 0.62, moss));
		}
	} else if (id == 3) {
		// PINEWOOD: dark rock in beds of uneven depth that dip along the face,
		// each bed broken into blocks by its own joints, offset from the bed
		// above and leaning a little, so the face is jointed stone and never a
		// row of boards. Roots hang from the soil in a few places, not a fringe.
		float b = (y + (vn - 0.5) * 0.1 + px.x * 0.0025) / 0.13;
		float bi = floor(b);
		float span = 10.0 + floor(ink_hash(vec2(bi, 21.0)) * 16.0);
		float jx = px.x + ink_hash(vec2(bi, 22.0)) * span + (fract(b) - 0.5) * 3.0;
		float cx = floor(jx / span);
		float jh = ink_hash(vec2(cx, bi + 4.0));
		c = jh < 0.35 ? dn(c, 0.25) : (jh > 0.82 ? up(c, 0.12) : c);
		if (mod(jx, span) < 1.0 && ink_hash(vec2(cx, bi + 9.0)) > 0.3) {
			c = dn(c, 0.7);
		}
		if (fract(b) < 0.07 && ink_vnoise(vec2(px.x * 0.04, bi)) > 0.35) {
			c = dn(c, 0.55);
		}
		if (dt < 0.08 + vn * 0.05) {
			c = EARTH1;
		} else if (ink_hash(vec2(px.x, 5.0)) > 0.95 && dt < 0.12 + ink_hash(vec2(px.x, 6.0)) * 0.22) {
			c = EARTH2;
		}
	} else if (id == 4) {
		// SNOWFIELD: a CORNICE, not a cap: the wind loads snow over the lip
		// until it overhangs, a rounded roll with a deep blue shadow in the curl
		// under it, its depth swelling and thinning along the wall. Under it
		// the rock is wind-scoured dark, rimed white on its ledges in streaks
		// that lean with the wind, and ice hangs only where meltwater runs:
		// in clusters, each run its own length, never a comb. All on smooth
		// fields: a hash per two-pixel column drew the comb and the bricks.
		float roll = 0.06 + ink_vnoise(vec2(px.x * 0.04, 1.0)) * 0.07 + ink_vnoise(vec2(px.x * 0.15, 2.0)) * 0.025;
		float curl = roll + 0.03 + ink_vnoise(vec2(px.x * 0.05, 3.0)) * 0.03;
		if (dt < roll) {
			// The roll: lit on top, shading round its belly.
			c = mix(RIME5, RIME4, smoothstep(roll * 0.4, roll, dt));
		} else if (dt < curl) {
			c = mix(RIME3, SLATE2, 0.35);
		} else {
			float b = (y + (vn - 0.5) * 0.08 + px.x * 0.003) / 0.19;
			c = mix(SLATE1, SLATE2, smoothstep(0.3, 0.7, ink_vnoise(vec2(px.x * 0.04, floor(b) * 2.3))));
			// Rime on the ledges, where snow can lie, and a soft frost breathing
			// over the face: never a threshold on a stretched field, which drew
			// marbled ribbons across the rock.
			c = mix(c, RIME4, smoothstep(0.78, 0.9, fract(b)) * 0.7);
			c = mix(c, RIME3, ink_vnoise(vec2(px.x * 0.03, y * 1.5 + 5.0)) * 0.25);
			// Ice where meltwater runs from the cornice: clusters only.
			float melt = smoothstep(0.55, 0.72, ink_vnoise(vec2(px.x * 0.05, 7.0)));
			float run = curl + (0.06 + ink_vnoise(vec2(px.x * 0.45, 9.0)) * 0.3) * melt;
			if (melt > 0.0 && dt < run && ink_vnoise(vec2(px.x * 0.7, 11.0)) > 0.45) {
				c = mix(RIME4, RIME3, (dt - curl) / max(run - curl, 0.01));
			}
		}
	} else if (id == 5) {
		// BONELANDS: thick limestone beds that swell and pinch along the face,
		// each bedding plane an eroded groove rather than a ruled line, and the
		// vertical joints few, leaning, and only where the rock has opened. The
		// old joints were one in every 13 pixels of every bed, which is
		// masonry: at eye level the whole landscape read as dry-stone walling.
		float bi;
		float groove;
		float fb = bone_bed(px.x, y, bi, groove);
		float tone = ink_vnoise(vec2(px.x * 0.05, bi * 3.1));
		c = mix(LINEN3, LINEN4, smoothstep(0.3, 0.7, tone * 0.6 + ink_hash(vec2(bi, 1.0)) * 0.4));
		// The bedding plane is RELIEF (matter_height, row 65): an undercut the
		// sun shades under a lit ledge. Here it is only a little dirtier, where
		// water sits in it; no stroke is drawn.
		if (fb < groove) {
			c = mix(c, LINEN2, 0.35);
		}
		// A joint: sparse, leaning across the bed, and only where it has opened.
		float lean = (fb - 0.5) * 3.0;
		float jc = (px.x + lean) / 31.0;
		float jx = abs(fract(jc + ink_hash(vec2(bi, 7.0))) - 0.5) * 31.0;
		if (jx < 0.8 && ink_hash(vec2(floor(jc), bi + 11.0)) > 0.62) {
			c = mix(c, LINEN1, 0.8);
		}
		// Solution pits: the rain has been at the face for a long time.
		if (ink_vnoise(vec2(px.x * 0.6, y * 14.0)) > 0.84) {
			c = dn(c, 0.25);
		}
	} else if (id == 6) {
		// BURNING: basalt in upright columns of uneven width, each with a lit
		// facet, a flat face and a shaded one; joints dark and broken, a few
		// still glowing; at the lip the column heads stand as pale caps, some
		// higher than others.
		float span = 9.0;
		float shift = floor(ink_hash(vec2(floor(px.x / 37.0), 5.0)) * 9.0);
		float cx = floor((px.x + shift) / span);
		float lx = px.x + shift - cx * span;
		float jw = 6.0 + floor(ink_hash(vec2(cx, 1.0)) * 3.0);
		float h = ink_hash(vec2(cx, 2.0));
		c = h < 0.33 ? STONE1 : (h < 0.7 ? mix(STONE1, STONE2, 0.45) : mix(STONE0, STONE1, 0.6));
		float cap = 0.04 + ink_hash(vec2(cx, 3.0)) * 0.08;
		bool joint = lx >= jw && ink_hash(vec2(cx, floor(y * 4.0) + 9.0)) < 0.8;
		if (dt < cap) {
			c = lx < jw * 0.45 ? ASH3 : (lx < jw ? mix(ASH3, STONE2, 0.55) : STONE1);
		} else if (dt < cap + 0.018) {
			c = INK2;
		} else if (joint) {
			c = INK2;
			// Only a few joints still burn, and those along a stretch of face.
			if (ink_vnoise(vec2(px.x * 0.02, y * 0.5 + 3.0)) > 0.62 && ink_hash(vec2(cx, floor(y * 10.0))) > 0.7) {
				float fl = flicker(vec3(cx, floor(y * 10.0), 0.0), 1.6);
				c = mix(EMBER2, EMBER3, fl);
				emit += c * (0.5 + 0.5 * fl);
				unh = 1.0;
			}
		} else {
			if (lx < 2.0) {
				c = up(c, 0.75);
			} else if (lx >= jw * 0.6) {
				c = dn(c, 0.35);
			}
			if (abs(fract(y * 1.7 + h * 3.0) - 0.5) < 0.012 && ink_hash(vec2(cx, 4.0)) < 0.35) {
				c = INK2;
			}
		}
	} else if (id == 7) {
		// SAND and SHINGLE banks: soft layers.
		float b = (y + (vn - 0.5) * 0.03) / 0.07;
		c = mod(floor(b), 3.0) < 1.0 ? dn(c, 0.4) : c;
		if (dt < 0.03) {
			c = up(c, 0.3);
		}
	} else if (id == 8) {
		// ICE: a frozen face, pale blue, hung with icicle runs of uneven length
		// from the lip, a darker melt line at the foot.
		float ic = floor(px.x / 3.0);
		float run = 0.08 + ink_hash(vec2(ic, 8.0)) * ink_hash(vec2(ic, 9.0)) * 0.4;
		c = RIME4;
		if (mod(px.x, 3.0) < 1.0 && dt < run) {
			c = RIME5;
		} else if (mod(px.x, 3.0) >= 2.0 && dt < run * 0.7) {
			c = RIME3;
		}
		if (dt > 0.42) {
			c = RIME3;
		}
	} else if (id == 9) {
		// SALT FLATS: the pan cut through. Thin evaporite beds, each a slightly
		// different mineral, laid down in a season and stained where the brine
		// soaked back in; a crust lip at the top that overhangs, and grey silt
		// at the foot where nothing crystallised.
		float b = (y + (vn - 0.5) * 0.03) / 0.09;
		float bh = ink_hash(vec2(floor(b), 2.0));
		c = bh < 0.4 ? LINEN4 : (bh < 0.75 ? LINEN5 : mix(LINEN3, RUST2, 0.25));
		if (fract(b) < 0.1) {
			c = LINEN2;
		}
		if (dt < 0.05 + vn * 0.03) {
			c = LINEN5;
		} else if (dt < 0.075 + vn * 0.03) {
			c = LINEN1;
		}
		if (dt > 0.6) {
			c = mix(LINEN2, STONE2, 0.5);
		}
		// This wall is salt too, and the salt flats has no headroom: every
		// contour in the landscape was drawn as a ruled WHITE line because the
		// evaporite beds were laid at the page (art review 1, and SALT_TOP).
		c = min(c, SALT_TOP);
	} else if (id == 10) {
		// SCRAPWOOD: a bank of made ground. Crushed plate and cable in courses
		// between bands of soil, roots reaching down through it, and the odd
		// whole piece still sticking out of the face.
		// Dumped, not laid: the layers wander and thicken and pinch out along the
		// bank, so no line runs level across it; the seam between two loads shows
		// only where it has opened; and what sticks out is a lump of plate or a
		// cable end with its own shape, never a ruled dash every few pixels --
		// the old pale plate lips at a fixed pitch read as mortar, and the whole
		// bank as brickwork.
		float wander = (ink_vnoise(vec2(px.x * 0.04, 3.0)) - 0.5) * 0.16 + (ink_vnoise(vec2(px.x * 0.13, 9.0)) - 0.5) * 0.05;
		float b = (y + (vn - 0.5) * 0.06 + wander) / (0.11 + ink_vnoise(vec2(px.x * 0.02, 17.0)) * 0.08);
		float bh = ink_hash(vec2(floor(b), 3.0));
		c = bh < 0.45 ? mix(EARTH1, RUST1, 0.35) : (bh < 0.8 ? EARTH2 : mix(STONE1, RUST2, 0.4));
		// Loads blend a little into each other rather than meeting on a rule.
		c = mix(c, EARTH1, smoothstep(0.75, 1.0, fract(b)) * 0.35);
		if (fract(b) < 0.07 && ink_vnoise(vec2(px.x * 0.11, floor(b))) > 0.55) {
			c = mix(c, INK2, 0.75);
		}
		// Plate and cable proud of the face: blobs on a smooth field, lit on top.
		float lump = ink_vnoise(vec2(px.x * 0.28, b * 2.3 + 40.0));
		if (lump > 0.8) {
			c = mix(STONE2, RUST2, 0.35 + 0.3 * ink_vnoise(vec2(px.x * 0.5, b)));
			if (lump > 0.8 && fract(b * 2.3) > 0.85) {
				c = up(c, 0.25);
			}
		}
		if (dt < 0.09 + vn * 0.05) {
			c = mix(EARTH1, MOSS2, 0.4);
		}
	} else if (id == 11) {
		// GLASS: a terrace wall the glassing ran over. The melt came over the
		// lip and ran down the whole face before it set, so the wall is GLASS
		// top to foot, and what it has to show is light and not a pattern: the
		// rolled lip and the runnels are relief (matter_height, row 71) the sun
		// finds, and the colour only says how thick the glaze lies. Thick under
		// the lip, it thins toward the foot, where the baked sand shows through
		// it as a warm cloud -- a gradient in the glass, never an edge drawn on
		// it, because an outline across the face read as a printed motif.
		float thick = ink_vnoise(vec2(px.x * 0.035, 3.0)) * 0.7 + ink_vnoise(vec2(px.x * 0.13, 7.0)) * 0.3;
		float thin = smoothstep(0.12 + thick * 0.3, 0.5 + thick * 0.2, dt);
		vec3 glaze = mix(SPRUCE1, SLATE1, 0.45 + 0.3 * ink_vnoise(vec2(px.x * 0.4, y * 2.0)));
		c = mix(glaze, mix(glaze, mix(SAND2, LINEN2, 0.4), 0.55), thin);
	} else if (id == 12) {
		// TIDE: the drowned city's cast walls, and every one of them carries the
		// water the same way, measured down from its own top (a terrace is 0.5
		// high): a white band of salt where the flood stood, TIDE_SALT under the
		// lip, with wrack hung under it; below that the concrete stained and
		// streaked down its fall; and the foot, under TIDE_WEED, green-black weed
		// that never dries (its roughness is taken off in fragment()). Above the
		// salt the lip is bleached. All of it on smooth fields along the wall,
		// never a per-pixel hash, which read as sparkle at eye level.
		float wob = (ink_vnoise(vec2(px.x * 0.06, 3.0)) - 0.5) * 0.04;
		float salt_at = TIDE_SALT + wob;
		float weed_at = TIDE_WEED + wob + smoothstep(0.55, 0.75, ink_vnoise(vec2(px.x * 0.12, 21.0))) * 0.08;
		if (dt < salt_at - 0.012) {
			c = mix(ASH3, LINEN3, 0.4);
		} else if (dt < salt_at + 0.012) {
			c = ink_vnoise(vec2(px.x * 0.25, 13.0)) > 0.3 ? LINEN4 : mix(ASH3, LINEN3, 0.5);
		} else if (dt < weed_at) {
			float streak = ink_vnoise(vec2(px.x * 0.18, 5.0));
			c = mix(mix(ASH1, SPRUCE2, 0.3), SPRUCE1, smoothstep(0.45, 0.8, streak) * 0.5);
			// Wrack hung under the salt line, in rags of uneven length.
			float hang = 0.02 + ink_vnoise(vec2(px.x * 0.3, 9.0)) * 0.07;
			if (dt - salt_at < hang && ink_vnoise(vec2(px.x * 0.2, 33.0)) > 0.45) {
				c = mix(EARTH1, SPRUCE1, 0.5);
			}
		} else {
			float wd = ink_vnoise(vec2(px.x * 0.08, y * 4.0));
			c = mix(mix(SPRUCE1, INK2, 0.4), mix(SPRUCE1, MOSS2, 0.35), smoothstep(0.4, 0.7, wd));
		}
	} else if (id == 13) {
		// CAVE: a wall of wet limestone that water has been building on for
		// longer than there were people. Flowstone curtains come down from the
		// lip, pale calcite with an iron stain in bands down their length, and
		// each ends where the flow gave out in a rounded lobe; between them the
		// rock is dark and running wet. No beds and no joints: nothing about a
		// cave wall is laid in courses, and the courses were what read as brick.
		float lip = 0.03 + (vn - 0.5) * 0.02;
		float fall = 0.16 + ink_vnoise(vec2(px.x * 0.07, 3.0)) * 0.3 + ink_vnoise(vec2(px.x * 0.22, 7.0)) * 0.1;
		float across = ink_vnoise(vec2(px.x * 0.16, 11.0));
		float curtain = smoothstep(0.42, 0.5, across);
		vec3 rock = mix(SLATE1, INK2, 0.35 + 0.3 * ink_vnoise(vec2(px.x * 0.05, y * 3.0)));
		vec3 calcite = mix(LINEN2, LINEN3, ink_vnoise(vec2(px.x * 0.3, y * 2.0)));
		// Iron in the flow: rust bands running the curtain's length.
		float iron = ink_vnoise(vec2(px.x * 0.45, 17.0));
		calcite = mix(calcite, mix(RUST1, EARTH2, 0.5), smoothstep(0.62, 0.8, iron) * 0.55);
		if (dt < lip) {
			c = mix(calcite, LINEN3, 0.4);
		} else if (dt < fall && curtain > 0.0) {
			c = mix(rock, calcite, curtain);
			// The lobe where the flow stopped: lit on its belly, dark under it.
			float end = fall - dt;
			if (end < 0.025 && curtain > 0.5) {
				c = end < 0.008 ? dn(c, 0.5) : up(c, 0.15);
			}
		} else {
			c = rock;
			// A wet streak down the face, darker, where water is running now.
			if (ink_vnoise(vec2(px.x * 0.2, 29.0)) > 0.7) {
				c = dn(c, 0.3);
			}
		}
	} else if (id == 14) {
		// REFUSE: the middens' walls, seventy years of it -- and the plan SORTED
		// it before it dumped it, which is the one thing that makes a wall of
		// rubbish into something worse than a heap. Bands by what it is, each
		// pinching out along the wall: dead boards (green, with a few lit
		// solder points), cable (black, looping), white goods (pale enamel
		// chips, yellowed), and rust. Bales pressed into it (matter_height) and
		// cable hanging off the lip in loops of uneven length.
		float wander = (ink_vnoise(vec2(px.x * 0.035, 3.0)) - 0.5) * 0.2;
		float b = (y + wander + (vn - 0.5) * 0.04) / 0.15;
		float kind = ink_hash(vec2(floor(b), 61.0));
		// Blotches as wide as they are tall: crushed things, not grain.
		float n1 = ink_vnoise(vec2(px.x * 0.16, y * 7.0)) * 0.7 + ink_vnoise(vec2(px.x * 0.45, y * 18.0)) * 0.3;
		if (kind < 0.25) {
			// Boards: green, and a few points of copper catching the light.
			c = mix(mix(SPRUCE1, MOSS2, 0.3), SPRUCE1, smoothstep(0.4, 0.7, n1));
			if (ink_vnoise(vec2(px.x * 1.1, y * 30.0)) > 0.9) {
				c = mix(RUST3, LINEN3, 0.4);
			}
			// A board somewhere in the heap still has power: a status light, one
			// pixel, amber or green, blinking slow and out of step, seen only
			// once the light goes. The last thing in the midden that thinks.
			float led = ink_hash(vec2(floor(px.x / 3.0), floor(y * 20.0)) + 71.0);
			if (led > 0.9975) {
				vec3 lc = led > 0.997 ? vec3(0.55, 0.9, 0.35) : vec3(1.0, 0.62, 0.2);
				float blink = step(0.35, fract(TIME * (0.2 + led * 0.3) + led * 17.0));
				c = mix(c, lc, 0.6);
				emit += lc * 3.0 * blink * sky_view.y;
			}
		} else if (kind < 0.5) {
			// Cable: black, with loops showing as paler arcs.
			c = mix(INK2, INK3, n1);
			if (abs(fract(n1 * 5.0) - 0.5) < 0.05) {
				c = mix(INK3, SLATE2, 0.5);
			}
		} else if (kind < 0.72) {
			// White goods: yellowed enamel in chips over the dark between them.
			// Fewer, larger, dirtier pieces heaped in the dark between them; the
			// enamel is seventy years of dust, not paint.
			float piece = ink_vnoise(vec2(px.x * 0.07, y * 3.5 + 7.0));
			vec3 enamel = mix(mix(LINEN2, ASH3, 0.4), RUST1, 0.25 * ink_vnoise(vec2(px.x * 0.3, y * 9.0)));
			c = mix(mix(INK3, RUST1, 0.4), enamel, smoothstep(0.55, 0.68, piece));
		} else {
			c = mix(RUST1, mix(RUST2, EARTH1, 0.4), n1);
		}
		// Loads meet on a dark seam only where it has opened.
		if (fract(b) < 0.06 && ink_vnoise(vec2(px.x * 0.09, floor(b))) > 0.5) {
			c = mix(c, INK1, 0.7);
		}
		// Seventy years: everything the colour of what it used to be.
		c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.3);
		// Cable hung off the lip in loops.
		float hang = 0.04 + ink_vnoise(vec2(px.x * 0.18, 91.0)) * 0.14;
		if (dt < hang && abs(fract(px.x * 0.07 + ink_vnoise(vec2(px.x * 0.05, 93.0)) * 3.0) - 0.5) < 0.06) {
			c = INK2;
		}
	} else if (id == 15) {
		// CRAG: gritstone, split by vertical joints of no fixed spacing into
		// tall blocks the weather has rounded (matter_height, row 75). The water
		// runs down it in black streaks from the lip, and it is crusted with
		// lichen: pale grey-green rosettes and a few of the sulphur-yellow ones
		// that grow only where the air is clean -- which, here, it is. No bedding
		// and no courses: nothing about a crag is laid.
		float blk = ink_vnoise(vec2(px.x * 0.04, 5.0));
		c = mix(SLATE2, mix(SLATE2, STONE2, 0.5), smoothstep(0.3, 0.7, blk));
		c = mix(c, dn(c, 0.3), smoothstep(0.55, 0.8, ink_vnoise(vec2(px.x * 0.12, y * 0.8))));
		// A joint: open, leaning, and not in every block.
		float jw = abs(fract(px.x / (19.0 + blk * 17.0) + ink_vnoise(vec2(y * 2.0, 11.0)) * 0.15) - 0.5);
		if (jw < 0.018 && ink_vnoise(vec2(px.x * 0.03, y * 1.5 + 3.0)) > 0.4) {
			c = mix(c, INK2, 0.7);
		}
		// Black water streaks from the lip.
		float wet = ink_vnoise(vec2(px.x * 0.25, 17.0));
		if (wet > 0.62 && dt < 0.1 + ink_vnoise(vec2(px.x * 0.07, 19.0)) * 0.35) {
			c = mix(c, INK2, 0.45 * smoothstep(0.62, 0.8, wet));
		}
		// Lichen: round rosettes a hand across, scattered in drifts, each its own
		// disc with a paler rim. On a noise threshold they came out as square
		// pixel blocks, a camouflage print on the rock.
		// Laid on the wall's CONTINUOUS world coordinate, not the screen grain
		// `px` (a whole grain wide, so every rim came out as a stair of square
		// pixels), and its edges filtered by the footprint (fwidth): a rosette
		// fades into the rock over one pixel at any distance, never a hard ring.
		float drift = ink_vnoise(vec2(px.x * 0.05, y * 0.9 + 23.0));
		vec2 lp = vec2(wp.x + wp.z, y) * 9.0;
		vec3 rc = matter_cells(lp);
		float rr = 0.18 + rc.z * 0.16;
		float fw = max(fwidth(rc.x), 1e-4);
		float disc = 1.0 - smoothstep(rr - fw, rr + fw, rc.x);
		// Far off, where a rosette is under a couple of pixels, it fades to the
		// average tint of the drift rather than twinkling.
		float far = smoothstep(0.08, 0.3, fw);
		if (drift > 0.55 && rc.z > 0.55) {
			vec3 lich = rc.z > 0.93 ? mix(SAND3, EMBER4, 0.2) : mix(LINEN2, MOSS3, 0.35);
			float rim = smoothstep(rr * 0.6 - fw, rr * 0.8 + fw, rc.x);
			float cover = disc * mix(0.6, 0.9, rim);
			c = mix(c, lich, mix(cover, 0.25, far));
		}
	} else if (id == 17) {
		// DECK: the broken edge of a cast highway deck, which is what a terrace
		// in the metropolis is. A slab of grey concrete in its pours, the top a
		// kerb and a strip of asphalt, spalled where it broke with the aggregate
		// showing, rebar standing out of the break in rust, a conduit run along
		// it, and stains bled down from the drains.
		c = mix(STONE2, mix(STONE2, LINEN2, 0.5), smoothstep(0.3, 0.7, ink_vnoise(vec2(px.x * 0.03, 3.0))));
		if (fract(y * 4.0 + 0.1) < 0.04) {
			c = dn(c, 0.18);
		}
		if (dt < 0.035) {
			c = mix(INK3, STONE1, 0.4);
		} else if (dt < 0.05) {
			c = up(c, 0.2);
		}
		float spall = ink_vnoise(vec2(px.x * 0.06, y * 2.0 + 7.0));
		if (spall > 0.66 && dt > 0.08) {
			c = mix(c, mix(STONE1, EARTH2, 0.3), 0.6);
			if (ink_vnoise(vec2(px.x * 0.9, y * 20.0)) > 0.8) {
				c = dn(c, 0.3);
			}
			// Rebar out of the break: short rusty stubs in a row.
			if (mod(px.x, 7.0) < 1.0 && abs(fract(y * 4.0) - 0.55) < 0.12) {
				c = mix(RUST2, RUST3, 0.4);
			}
		}
		// A conduit along the deck's face.
		float cy = 0.16 + ink_vnoise(vec2(px.x * 0.01, 9.0)) * 0.05;
		if (abs(dt - cy) < 0.012 && ink_vnoise(vec2(px.x * 0.02, 13.0)) > 0.45) {
			c = abs(dt - cy) < 0.005 ? mix(SLATE2, STONE2, 0.5) : INK3;
		}
		// A drain's stain bled down the face.
		float drain = ink_vnoise(vec2(px.x * 0.3, 17.0));
		if (drain > 0.7 && dt < 0.4 * ink_vnoise(vec2(px.x * 0.1, 19.0)) + 0.1) {
			c = mix(c, mix(RUST1, INK3, 0.5), 0.45 * smoothstep(0.7, 0.85, drain));
		}
	} else if (id == 18) {
		// ROOTED: a deck edge the forest has. Grey concrete in its pours, and over
		// it a curtain of roots and vine let down from the canopy on top,
		// hanging in strands of uneven length, darker at their tips; ferns out of
		// the cracks; a cushion of moss along the lip.
		c = mix(STONE2, mix(STONE2, MOSS2, 0.35), smoothstep(0.3, 0.7, ink_vnoise(vec2(px.x * 0.03, 3.0))));
		if (fract(y * 4.0 + 0.1) < 0.04) {
			c = dn(c, 0.15);
		}
		// Green creeping up from the foot.
		c = mix(c, mix(MOSS2, SPRUCE1, 0.4), smoothstep(0.3, 0.5, dt + (ink_vnoise(vec2(px.x * 0.08, 5.0)) - 0.5) * 0.2) * 0.6);
		// The curtain: strands a couple of pixels wide, each its own length.
		float strand = ink_vnoise(vec2(px.x * 0.35, 7.0));
		float hang = 0.06 + ink_vnoise(vec2(px.x * 0.11, 9.0)) * 0.36;
		if (strand > 0.52 && dt < hang) {
			c = mix(mix(SPRUCE2, MOSS3, ink_vnoise(vec2(px.x * 0.9, y * 4.0))), EARTH1, smoothstep(hang * 0.6, hang, dt));
		}
		// Ferns in the cracks.
		if (ink_vnoise(vec2(px.x * 0.2, y * 6.0 + 11.0)) > 0.8 && dt > 0.15) {
			c = mix(MOSS3, SPRUCE2, 0.3);
		}
		// Moss cushion on the lip.
		if (dt < 0.035 + ink_vnoise(vec2(px.x * 0.1, 13.0)) * 0.03) {
			c = mix(MOSS2, MOSS3, 0.4);
		}
	} else if (id == 19) {
		// CAST: a retaining wall the machines cast and keep. Formwork panels to an
		// exact module, tie holes in exact rows, a violet strip along the lip on
		// their power, and a clean face -- no weather is allowed on it, and that
		// is what makes it the most frightening wall in the world.
		c = mix(STONE2, SLATE2, 0.35);
		float pan = fract(px.x / 48.0);
		if (pan < 0.02) {
			c = dn(c, 0.3);
		}
		if (abs(fract(px.x / 12.0) - 0.5) < 0.04 && abs(fract(dt / 0.125) - 0.5) < 0.1) {
			c = INK3;
		}
		if (dt < 0.03) {
			float ndim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
			float on = max(neon_burn(ndim), 0.25) * sky_power();
			c = mix(mix(INK3, STATUS_VIOLET, 0.4), STATUS_VIOLET, on);
			emit += STATUS_VIOLET * 1.4 * on;
			unh = max(unh, on);
		}
	} else if (id == 20) {
		// MACHINE: a wall of the machine city. Machined plate to an exact module,
		// a row of vents at one height along every wall, and a cold lit seam
		// under the lip on the machines' power. Clean: nothing weathers it.
		c = mix(SLATE1, STONE1, 0.5);
		if (fract(px.x / 36.0) < 0.03) {
			c = dn(c, 0.35);
		}
		float vy = abs(dt - 0.26);
		if (vy < 0.05 && fract(px.x / 6.0) < 0.6) {
			c = fract(vy * 60.0) < 0.5 ? INK2 : SLATE1;
		}
		if (dt > 0.03 && dt < 0.05) {
			float ndim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
			float on = max(neon_burn(ndim), 0.0) * sky_power();
			c = mix(mix(c, GUIDE_WHITE, 0.3), GUIDE_WHITE, on);
			emit += GUIDE_WHITE * mix(1.2, 2.0, sky_view.y) * on;
			unh = max(unh, on);
		}
	} else if (id == 21) {
		// MESA: sandstone laid down in a desert that was here before this one,
		// so its bands are its history. Red, cream and a bruised purple in beds
		// that swell and pinch, some cross-bedded (thin laminae at a slant
		// inside the bed, the old dunes' faces); a hard pale caprock at the top
		// holding the lip up; and desert varnish streaked dark down the face
		// from the lip, where water ran for a thousand years a night at a time.
		// Laid LEVEL, with a long low undulation and a steady thickness: a
		// thickness that varied along the wall bent every bed and the face
		// read as marbled swirls at a low sun (the bonelands lesson).
		float sw = (ink_vnoise(vec2(px.x * 0.006, 3.0)) - 0.5) * 0.03;
		// Beds a forearm deep, in reds close in value: a strong contrast
		// between neighbours drew a tiger stripe. One bed in five is paler.
		float b = (y + sw) / 0.19;
		float bi = floor(b);
		float kind = ink_hash(vec2(bi, 41.0));
		c = kind < 0.4 ? mix(RUST2, RUST3, 0.5) : (kind < 0.8 ? mix(RUST2, EARTH2, 0.3) : mix(RUST3, SAND3, 0.3));
		// Soft bedding planes between them.
		c = mix(c, dn(c, 0.18), 1.0 - smoothstep(0.0, 0.12, fract(b)));
		// Cross-bedding: faint slanted laminae inside a few beds.
		if (ink_hash(vec2(bi, 43.0)) > 0.6 && fract(b) > 0.15 && fract(b) < 0.9) {
			float lam = fract(fract(b) * 4.0 + px.x * 0.025 * (ink_hash(vec2(bi, 44.0)) > 0.5 ? 1.0 : -1.0));
			c = mix(c, dn(c, 0.07), smoothstep(0.75, 0.9, lam));
		}
		// The caprock.
		float cap = 0.06 + ink_vnoise(vec2(px.x * 0.05, 7.0)) * 0.03;
		if (dt < cap) {
			c = mix(LINEN3, SAND3, 0.35);
		} else if (dt < cap + 0.02) {
			c = dn(c, 0.4);
		}
		// Desert varnish: dark streaks from the lip down the face.
		float vs = ink_vnoise(vec2(px.x * 0.12, 9.0)) * 0.7 + ink_vnoise(vec2(px.x * 0.5, 11.0)) * 0.3;
		float reach = 0.1 + ink_vnoise(vec2(px.x * 0.04, 13.0)) * 0.35;
		if (vs > 0.56 && dt > cap && dt < reach) {
			c = mix(c, mix(INK2, RUST1, 0.35), smoothstep(0.56, 0.72, vs) * (1.0 - (dt - cap) / reach) * 0.7);
		}
	} else if (id == 22) {
		// FLOE: the edge of a floe standing out of the sea. The ice is laid in
		// blue and white layers, a winter each, the blue deepening down toward
		// the waterline; melt hung off the lip in icicles that cluster where the
		// sun works on the lip and are absent elsewhere, each its own length;
		// and a snow cap along the top.
		float sw = (ink_vnoise(vec2(px.x * 0.03, 3.0)) - 0.5) * 0.04;
		float b = fract((y + sw) / 0.07);
		c = mix(RIME4, RIME3, smoothstep(0.55, 0.8, b));
		c = mix(c, mix(RIME2, BRINE2, 0.4), smoothstep(0.15, 0.5, dt));
		float cap = 0.035 + ink_vnoise(vec2(px.x * 0.07, 5.0)) * 0.03;
		float cluster = smoothstep(0.45, 0.7, ink_vnoise(vec2(px.x * 0.04, 7.0)));
		float ic = ink_vnoise(vec2(px.x * 0.6, 9.0));
		float run = cap + (0.05 + ink_vnoise(vec2(px.x * 0.25, 11.0)) * 0.25) * cluster;
		if (dt < cap) {
			c = RIME5;
		} else if (ic > 0.5 && dt < run) {
			c = mix(RIME5, RIME4, (dt - cap) / max(run - cap, 0.01));
		}
	}
	return c;
}

void vertex() {
	sway_w = UV2.x;
	if (sway_w > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 push = wind_push(wp, sway_w, UV2.y, 1.0);
		mat3 to_model = inverse(mat3(MODEL_MATRIX));
		VERTEX += to_model * (mat3(INV_VIEW_MATRIX) * wind_view(push, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE));
		NORMAL = wind_tilt(NORMAL, to_model * push, sway_w, to_model * vec3(0.0, 1.0, 0.0));
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wash2 = CUSTOM0.rgb;
	// A mesh without CUSTOM0 reads (0, 0, 0, 1): no second wash is ever pure black.
	wash_blend = dot(CUSTOM0.rgb, vec3(1.0)) > 0.0 ? CUSTOM0.a : 0.0;
	style_packed = UV.x;
	style_blend = UV.y;
	patch_raw = UV2.x > 0.0 ? 0.0 : UV2.y;
}

// How much of a crown is taken away at this point: 0 keep it, 1 take it all.
// Only what sways and stands clear of the ground can go, so trunks, walls and
// the land itself never open up.
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


// How much of a TALL BUILT thing is taken away here (TALL_FLOOR above). Cut where
// the fragment DRAWS and never where it stands: cutting by plain horizontal
// distance opens the hole in clear air, which is the mistake ForeView's own
// header records. The lean is read off the LIVE camera rather than the rig's
// fixed pitch, because a target lock leans the picture and a hole that did not
// lean with it would sit beside the machine exactly when the player was reading
// it (fore_view.gd `_aim`).
// `toward` and `lean` are handed in rather than read here: a Godot built-in like
// INV_VIEW_MATRIX exists only inside the stage function, so a user function
// cannot see the camera at all (the shader simply refuses to compile).
float tall_cut(vec3 wp, int m, vec3 camz, vec3 eye, bool persp) {
	if (mark_land(m)) {
		return 0.0;
	}
	float cut = 0.0;
	for (int i = 0; i < CROWN_CLEAR; i++) {
		vec4 p = crown_clear[i];
		if (p.w <= 0.0 || wp.y < p.y + tall_floor) {
			continue;
		}
		// WHERE THIS FRAGMENT'S OWN RAY MEETS THE SUBJECT'S GROUND. It used to be
		// one shear for the whole screen -- `toward * (wp.y - p.y) * lean`, which
		// is exactly this intersection for PARALLEL rays and so is right only
		// under an orthographic projection. Under the lens every fragment has its
		// own ray from the eye, and one direction for all of them puts the hole
		// beside the subject everywhere but the middle of the picture.
		vec2 g;
		if (persp) {
			// A fragment at or above the eye has no forward ground intersection at
			// all: the ray through it goes UP. It is drawn above the subject and
			// cannot be covering it. Leaving this to the distance test below would
			// be a guard that works by accident -- the kind that holds for a year
			// and then does not.
			if (wp.y >= eye.y - 0.05) {
				continue;
			}
			// `s` is NEGATIVE on purpose: the loop only runs where the plane is at
			// least `tall_floor` BELOW the fragment, so the ray carries on past it,
			// away from the eye. Anything that forces `s` positive is travelling
			// back through the camera.
			float s = (p.y - wp.y) / max(eye.y - wp.y, 0.05);
			g = wp.xz + s * (eye.xz - wp.xz);
		} else {
			// The shipped expression, rearranged: `toward * lean` IS `camz.xz /
			// camz.y`, so an orthographic frame is identical term for term. The
			// abs() is the shipped guard and stays -- without it a camera pitched
			// the other way clamps to 0.05 instead of using its own slope.
			g = wp.xz - camz.xz * (wp.y - p.y) / max(0.05, abs(camz.y));
		}
		float d = length(g - p.xz);
		float r = p.w * TALL_WIDEN;
		cut = max(cut, 1.0 - smoothstep(r * 0.58, r, d));
	}
	return cut;
}

// THE PINEWOOD'S NIGHT. Under the closed canopy nothing of the sky reaches the
// floor, and the only light is the wood's own: honey fungus threading the
// rotting litter, a cold green-white in fine veins, in a few drifts where the
// deadfall has lain longest and nowhere else. Steady, because fungus does not
// blink; it breathes very slowly. Only after dark (sky_view.y): by day it is
// invisible, as it is.
vec3 pine_foxfire(vec2 wp, vec2 px) {
	float drift = smoothstep(0.62, 0.8, ink_vnoise(wp * 0.09 + 17.0));
	if (drift <= 0.0 || sky_view.y <= 0.0) {
		return vec3(0.0);
	}
	// A glow soaked into the litter, a hand or two across and grained like the
	// litter itself. A line read as ruled neon, a speck alone as fireflies, and
	// an even wash as a lit lawn.
	float clump = smoothstep(0.6, 0.9, ink_vnoise(wp * 0.7 + 5.0) * 0.75 + ink_vnoise(wp * 2.1 + 9.0) * 0.25);
	float grain = 0.3 + 0.7 * step(0.5, ink_hash(floor(px / 2.0) + 29.0));
	float breath = 0.85 + 0.15 * sin(TIME * 0.35 + wp.x * 0.05 + wp.y * 0.07);
	return vec3(0.32, 0.62, 0.42) * 0.8 * drift * clump * grain * breath * sky_view.y;
}

void fragment() {
	if (near_cut > 0.5 && near_drawn(world_pos)) {
		discard;
	}
	// The grain a material's marks are drawn at, pinned to the WORLD at a fixed
	// size (matter_px). It used to be `floor(FRAGCOORD.xy) + world_px`, a SCREEN
	// pixel anchored to the world, which made every speck of grit three times
	// finer the moment the floor rose to 1920x1080 and made the whole library a
	// drawing technique instead of a surface.
	vec2 px = matter_px(world_pos);
	// A fight is never hidden: leaves over the player, or over a body they can
	// see, thin to stipple and then go. Stipple, never a fade (docs/LOOK.md law 5).
	int m1 = int(COLOR.a * 255.0 + 0.5);
	// Where the camera is, for the tall cut: the horizontal part of the camera's
	// own Z over its vertical part is exactly 1/tan(pitch), with no trigonometry
	// and no assumption about the rig it was built with.
	vec3 camz = INV_VIEW_MATRIX[2].xyz;
	// The eye itself, and which projection drew this: PROJECTION_MATRIX[3][3] is
	// 1.0 orthographic and 0.0 perspective, it is uniform across the draw, so the
	// branch below costs nothing to divergence.
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	bool persp = PROJECTION_MATRIX[3][3] < 0.5;
	float cut = max(crown_cut(world_pos, sway_w), tall_cut(world_pos, m1, camz, eye, persp));
	// A CLOSE EYE (the view over the shoulder) cuts whatever lies in the line of
	// sight to a body, at any height (sight.gdshaderinc). Never the land.
	if (persp && !mark_land(m1)) {
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
	int m2 = patch_raw >= 1.5 ? int(mod(patch_raw - 2.0 + 0.5, 256.0)) : m1;
	float bend = patch_raw >= 257.5 ? -1.0 : 1.0;
	float patchy = min(patch_raw, 1.0);
	// A second wash (another ground, another country) meets this one on a
	// crisp, ragged edge: never a muddy average, never a dither, never a tile
	// square. The weight is bent by a world field so the edge wanders freely
	// inside its band, and the lighter wash is inked along it, broken like a
	// pen lifting (docs/LOOK.md: one edge language for every patch).
	bool second = false;
	bool edge_ink = false;
	if (wash_blend > 0.0) {
		float e = wash_blend - 0.5 + bend * ((ink_vnoise(world_pos.xz * 2.3) - 0.5) * 0.36 + (ink_vnoise(world_pos.xz * 7.1 + 3.0) - 0.5) * 0.14);
		second = e > 0.0;
		float l2 = dot(wash2, vec3(0.3, 0.59, 0.11));
		float l1 = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
		bool second_lighter = l2 > l1;
		// Where a pale wash lies on a dark one (snow on turf or ash) the pale
		// side's edge is a wider pen, so the patch has a drawn rim and not a
		// cut-paper edge.
		float fw = fwidth(e) * (abs(l2 - l1) > 0.3 ? 2.2 : 0.9);
		edge_ink = (second_lighter ? (e > 0.0 && e < fw) : (e <= 0.0 && e > -fw)) && ink_hash(floor(px / vec2(3.0, 2.0)) + 71.0) > 0.18;
	}
	vec3 c = second ? wash2 : COLOR.rgb;
	int m = second ? m2 : m1;
	// The pine floor IS the needle floor, in its matter, its marks and its wear;
	// it differs only in what it gives off after dark (pine_foxfire).
	bool pine = m == M_PINE_FLOOR;
	if (pine) {
		m = 50;
	}
	float s1 = mod(style_packed, 16.0);
	float s2 = floor(style_packed / 16.0 + 0.01);
	float unh = 0.0;
	vec3 emit = vec3(0.0);
	if (patchy > 0.0) {
		float pn = ink_vnoise(world_pos.xz * 0.11) * 0.65 + ink_vnoise(world_pos.xz * 0.37) * 0.35 + rag(world_pos.xz);
		c *= 1.0 + patchy * (step(0.66, pn) * 0.04 - step(pn, 0.32) * 0.04);
	}
	if (mark_ground(m)) {
		c = ground_mark(m, c, world_pos.xz, px, emit, unh);
		if (m == M_CITY_FLOOR || m == M_OVERGROWN) {
			c = city_floor(c, world_pos, px);
		}
		if (m == M_OVERGROWN) {
			c = overgrow(c, world_pos, px);
		}
		if (m == M_CAST_FLOOR) {
			c = cast_floor(c, world_pos, px, emit);
		}
		if (m == M_MACHINE_DECK) {
			c = machine_deck(c, world_pos, px, emit);
		}
		if (m == M_SULPHUR) {
			c = sulphur_crust(c, world_pos, px);
		}
		if (m == M_DESERT_PAVEMENT) {
			c = desert_pavement(c, world_pos, px);
		}
		if (m == M_SEA_ICE) {
			c = sea_ice(c, world_pos, px);
		}
		if (m == M_TIDEFLAT) {
			c = tide_floor(c, world_pos, px, emit);
		}
		if (pine) {
			emit += pine_foxfire(world_pos.xz, px);
		}
		// The fused sheet is not trodden to earth: nothing walks glass to a path.
		if (unh < 0.5 && m != M_VITRIFIED && m != M_MACHINE_DECK && m != M_SULPHUR) {
			c = ground_wear(m, c, world_pos.xz, px);
		}
		// Turf, heath and fen are a sward, and a gust crossing one lays it over:
		// the front reads from above as a paler band travelling over the land, to
		// the horizon, with no geometry (wind_sheen).
		if (m == 40 || m == 41 || m == 48) {
			vec3 tr = trample_at(world_pos.xz);
			c *= (1.0 + GROUND_SHEEN * wind_sheen(world_pos.xz)) * (1.0 - GROUND_PRESSED * max(tr.z, length(tr.xy) * 0.6));
		}
		// The machine city's deck IS the plan's order, laid by it: the works'
		// marks and the survey's ruling would draw a second, square grid over it.
		if (works_inv_size > 0.0 && m != M_MACHINE_DECK) {
			vec4 wk = texture(works_map, world_pos.xz * works_inv_size);
			vec3 wl = texture(works_lines, world_pos.xz * works_inv_size).rgb;
			if (wk.r + wk.g + wk.b + wk.a > 0.02) {
				c = works_mark(m, c, world_pos.xz, px, wk, wl.g, int((second ? s2 : s1) + 0.5), emit, unh);
			}
			if (wl.r > 0.5) {
				c = survey_mark(m, c, world_pos.xz, px, wl.b, int((second ? s2 : s1) + 0.5));
			}
		}
		// The salt flats' one hard rule (see SALT_TOP), laid LAST so it catches
		// the mark, the wear and the works alike: no crust pixel is drawn at the
		// page. Scaled, not clipped, so the plates and the rims keep their
		// structure; and only on the warm side, because brine is not crust.
		if ((m == 55 || m == 57) && c.r >= c.b) {
			c *= min(1.0, SALT_TOP.r / max(max(c.r, max(c.g, c.b)), 1e-4));
		}
	} else if (mark_strata(m)) {
		// A wall's pattern runs ALONG the wall. `px` is the play camera's screen
		// grid laid on the world, whose x does not change with height: from
		// above that is invisible, but at eye level every feature keyed on it
		// stood as a full-height vertical stripe, and a bank of rock read as a
		// palisade of planks. So the horizontal coordinate is the world axis the
		// facet runs along, in the same grain.
		vec3 fn = cross(dFdx(world_pos), dFdy(world_pos));
		float along = abs(fn.x) > abs(fn.z) ? world_pos.z : world_pos.x;
		vec2 wpx = vec2(floor(along / SKY_GRAIN), px.y);
		c = strata(m - MARK_STRATA, c, world_pos, wpx, emit, unh);
		// The weathering pass, on every wall: whatever it is cut through, the
		// lip, the run-off and the foot are the weather's -- except the one the
		// machines cast and still maintain.
		// A cornice is snow, and the weather's lip shade would sit in its roll.
		if (m != M_STRATA_CAST && m != M_STRATA_MACHINE && m != MARK_STRATA + 4) {
			c = strata_weather(c, (floor(world_pos.y / 0.5 - 0.002) + 1.0) * 0.5 - world_pos.y, wpx);
		}
	} else if (m >= 1 && m <= 16) {
		// Embers and flames: they give light, so they are never shaded or hatched.
		float fl = 0.8 + 0.2 * flicker(world_pos, 6.0);
		emit += c * (float(m) / 8.0) * fl;
		unh = 1.0;
	} else if (m >= 17 && m <= 32) {
		// A lamp or a window: dark glass by day, lit when the light goes.
		float dim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
		float on = neon_burn(dim);
		emit += c * (float(m - 16) / 8.0) * on;
		c = mix(BRINE2, c, on);
		unh = on;
	} else if (m == 34) {
		// Stolen neon: lit like a lamp when the light goes, but on the MACHINES'
		// power, so lightning stutters the tube exactly as it stutters the strip
		// it was cut from — and its pool, glint and shafts (15_lights) stutter
		// with it. A hearth or a window in the same wall keeps burning.
		float ndim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
		float non = neon_burn(ndim) * sky_power();
		emit += c * 2.0 * non;
		c = mix(BRINE2, c, non);
		unh = non;
	} else if (m == 33) {
		// A glint: glass or ice catching the light for a moment.
		float gh = ink_hash(floor(world_pos.xz * 7.0) + floor(world_pos.y * 7.0));
		if (fract(TIME * 0.27 + gh * 17.0) < 0.06) {
			c = up(c, 1.6);
			emit += c * 0.3;
		}
	}
	if (edge_ink && unh < 0.5) {
		// Where a pale wash lies on a dark one the pale side used to be INKED.
		// Under a real sun the two grounds are different MATERIALS, and that is
		// a far stronger edge than a pen line; all that is left here is the
		// darker lip a drift or a crust actually has where it rides up.
		c = dn(c, 0.22);
	}
	// Weather that has SETTLED on this surface, the airs it is seen through,
	// and what the hour does to its colour.
	c = sky_apply(c, world_pos, TIME);

	// --- Law 1: matter is honest (docs/LOOK.md) --------------------------
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 mr = matter_of(m);
	float rough_add = 0.0;
	// The land itself takes only a little: it IS the bog, it does not rust in
	// it. Anything STANDING in the land takes it nearly whole, which is the law
	// in one line: the same house, fence and machine carry the bog on them, or
	// the flat, or the Burning, and nobody had to author three of each.
	float takes = mark_land(m) ? 0.14 : 0.85;
	// A face opened a moment ago (GroundColors.FRESH: the cut through a boulder
	// somebody is quarrying) has had almost nothing settle on it. The wear map
	// reads the PLACE, not the age, so without this a cut made in a bog rusts as
	// it is made. Almost, not nothing: dust falls on a broken face within the
	// hour, and a face that takes literally none of its land reads as cut out of
	// the picture rather than out of the rock.
	if (m == 58) { takes = 0.06; }
	c = matter_worn(c, matter_wear(world_pos), n_world, world_pos, takes * (1.0 - unh), rough_add);
	// And the land's growth over what was built in it: never the land itself.
	if (!mark_land(m)) {
		c = matter_grown(c, n_world, world_pos, (1.0 - unh) * grows, rough_add);
	}

	if (m == M_SEA_ICE) {
		// The black ice in the leads is near a mirror: the sky lies in it.
		rough_add -= sea_black(world_pos.xz) * 0.25;
	}
	if (m == 55) {
		// THE MIRAGE. Far off across the flat the air over the hot crust bends
		// the sky down onto it: a band of the sky lying on the ground at the
		// horizon, shimmering. It is the light's: the far crust is made smooth
		// enough to mirror what is above it, and the shimmer moves that mirror.
		float far_off = smoothstep(35.0, 90.0, length(world_pos - INV_VIEW_MATRIX[3].xyz));
		float shimmer = ink_vnoise(vec2(world_pos.x * 0.3 + TIME * 0.6, world_pos.z * 0.3));
		rough_add -= far_off * (0.55 + 0.2 * shimmer);
	}
	if (m == M_SULPHUR) {
		// The pools are wet and warm and never dry: they take the sky; the
		// sinter rims do not.
		vec3 scd = matter_cells(world_pos.xz * 0.9 + vec2(ink_vnoise(world_pos.xz * 0.4), ink_vnoise(world_pos.xz * 0.4 + 9.0)) * 1.5);
		rough_add -= smoothstep(0.05, 0.1, scd.y - scd.x) * 0.3;
	}
	if (m == M_CITY_FLOOR) {
		// Window glass lying in drifts on the city floor catches the light.
		rough_add -= city_glass(world_pos.xz) * 0.35;
	}
	if (m == M_TIDEFLAT) {
		// Standing water on the drowned floor is a mirror; the silt round it is not.
		rough_add -= tide_pool(world_pos) * 0.72;
	} else if (m == M_STRATA_CAVE) {
		// A cave wall runs wet in streaks: shinier where water is on it now.
		rough_add -= smoothstep(0.55, 0.8, ink_vnoise(vec2(world_pos.x + world_pos.z, world_pos.y * 0.2) * 1.3)) * 0.2;
	} else if (m == M_STRATA_TIDE) {
		// The weed at a wall's foot is slick and never dries.
		float wall_dt = (floor(world_pos.y / 0.5 - 0.002) + 1.0) * 0.5 - world_pos.y;
		rough_add -= smoothstep(TIDE_WEED - 0.02, TIDE_WEED + 0.04, wall_dt) * 0.45;
	}
	if (m == M_VITRIFIED) {
		// By night the fused sheet is what holds the sky: smoother as the
		// dark comes (sky_view.y), so the moon lies on the glass in a long
		// streak and the stars are in it, and nothing else in the desert is lit.
		rough_add -= sky_view.y * 0.24;
	}
	if (m == M_STRATA_GLASS) {
		// The glaze is not one sheet: runnels polished by the flow alternate
		// with duller skin, so a wall catches the sun in streaks down its fall
		// and never as one lit facet.
		rough_add += ink_vnoise(vec2(world_pos.x + world_pos.z, world_pos.y * 0.3) * 3.1) * 0.35;
	}
	ALBEDO = matter_albedo(c);
	ROUGHNESS = clamp(mr.x + rough_add, 0.04, 1.0);
	SPECULAR = mr.y;
	METALLIC = mr.w;
	if (m == 56) {
		// SWARF: only the combed filings are metal. Metal over the whole floor
		// mirrored the sky at eye level and the wood's floor came back a pale
		// lavender sheet; the mulch between the arcs is the matte of wet leaves.
		float sf = ink_vnoise(world_pos.xz * 0.11) * 0.75 + ink_vnoise(world_pos.xz * 0.4) * 0.25;
		float on_arc = 1.0 - smoothstep(0.12, 0.2, fract(sf * 11.0));
		METALLIC = mr.w * on_arc;
		ROUGHNESS = clamp(ROUGHNESS + (1.0 - on_arc) * 0.4, 0.04, 1.0);
		SPECULAR = mix(0.3, mr.y, on_arc);
	}
	// THE TILE LATTICE MUST NOT REACH THE EYE (CLAUDE.md: no grid on screen).
	//
	// The terrain is a triangle lattice with FLAT per-face normals, and its
	// gentle bump cells give every triangle a slightly different one. Under two
	// hard bands of N dot L that was invisible -- both triangles landed in the
	// same band. Under a real sun it is a herringbone of chevrons about two
	// thirds of a tile across, ruled over every open field in the game, and it
	// is the tile grid arriving in the picture by the back door.
	//
	// So a face that is already all but level is taken to level, and the relief
	// the eye is meant to find is matter_bump's, which belongs to the MATERIAL
	// and not to the mesh. Slopes, walls and everything a body can climb keep
	// the normal they were built with.
	float level = smoothstep(0.80, 0.97, n_world.y);
	if (level > 0.0) {
		NORMAL = normalize(mix(NORMAL, normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), level));
	}
	if (unh < 0.5) {
		NORMAL = matter_bump(NORMAL, world_pos, m, mr.z * relief);
	}
	EMISSION = matter_light(c * emission_strength + emit)
		+ matter_light(neon_reflect(world_pos, px) + neon_skyglow(c));
	// A blow's paper-white, as a sphere in world space: only the part that was
	// struck goes to paper, so the body it landed on is still showing while the
	// mark proves the hit (docs/LOOK.md; and see found.gdshader, which carries
	// the same three uniforms for the machines). MADE, so its edge is a pixel of
	// stipple and not a rule. `flash_r` 0 is every draw but a struck body's.
	if (flash_r > 0.0) {
		float fd = distance(world_pos, flash_at) / flash_r;
		if (fd < 1.0 && (fd < 0.82 || ink_hash(px) < (1.0 - fd) * 5.5)) {
			ALBEDO = vec3(0.0);
			EMISSION = matter_light(flash_col);
		}
	}
}

// There is no light() and that is the whole point of LANTERN. The renderer does
// real diffuse and specular against the sun, the sky and every lamp, and finds
// the relief matter_bump() put in NORMAL. What used to live here -- two flat
// bands of N dot L, a hatch laid into DIFFUSE_LIGHT, and a lamp pool cut into
// two hard steps -- was most of why twelve art directions all came out papery.
