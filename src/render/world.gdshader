// MADE: everything a person or the land made. Terrain, props, houses, people.
// A flat palette wash, lit in two bands; shade is a colour AND ink hatching in
// the style of the country (or of the hand, for made things). See docs/ART.md.
//
// Vertex channels (MeshKit writes them):
//   COLOR.rgb  wash colour (palette sRGB)
//   COLOR.a    MARK code / 255 (GroundColors): 0 or 1.0 = plain. Marks are ink
//              and wash details drawn into a surface by what it is: turf ticks,
//              grikes, drifts, strata, embers (glow), lamps, glints.
//   CUSTOM0    rgb = second wash for an ecotone or ground edge, a = weight (0..1)
//   UV.x       hatch styles, style1 + style2 * 16; style2 is used where the
//              second wash shows.   UV.y  weight of that edge (terrain: = CUSTOM0.a)
//   UV2.x      wind sway weight (0 = rigid)
//   UV2.y      sway phase when swaying; on rigid geometry, how much the wash
//              breaks into large organic light/dark patches (0..1). Terrain
//              writes 2 + the second wash's mark code (patches at full).
shader_type spatial;
render_mode cull_back, specular_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

global uniform float wind_strength;
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

varying vec3 world_pos;
varying vec3 wash2;
varying float wash_blend;
varying float style_packed;
varying float style_blend;
varying float patch_raw;
varying float sway_w;
// Written in fragment(), read in light().
varying float style_sel;
varying float unhatched;

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

// Jittered-cell distances: (nearest, second nearest, id of nearest).
vec3 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = g + vec2(ink_hash(i + g), ink_hash(i + g + vec2(5.3, 1.7))) * 0.8 + 0.1 - f;
			float d = dot(o, o);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = ink_hash(i + g + vec2(9.1, 3.3));
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

// Pixel-scale raggedness for any threshold drawn on a world field, so every
// patch edge is the same crisp, torn line as a ground edge.
float rag(vec2 wp) {
	return (ink_vnoise(wp * 7.1 + 3.0) - 0.5) * 0.06;
}

float flicker(vec3 p, float rate) {
	return step(0.35, ink_hash(vec2(floor(TIME * rate), floor(p.x * 5.0) + floor(p.z * 7.0) * 13.0)));
}

// The ground's own marks. wp: world xz. Marks are sparse: a wash stays a wash,
// and interest lives at edges and in rare features (docs/ART.md). Nothing
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
		// SHINGLE: drawn pebbles, lit on the upper left and dark below, with
		// the ground showing between; now and then a piece of sea glass.
		vec2 q = wp * 6.0;
		vec2 i = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = ink_hash(i + 3.0);
		vec2 o = (vec2(ink_hash(i + 7.0), ink_hash(i + 11.0)) - 0.5) * 0.3;
		vec2 e = (f - o) * vec2(1.0, 1.35 + h * 0.5);
		float r = 0.28 + h * 0.16;
		float dd = length(e);
		if (h > 0.18 && dd < r) {
			c = h < 0.45 ? dn(c, 0.35) : (h > 0.8 ? up(c, 0.3) : c);
			if (dd > r - 0.1) {
				c = (e.x + e.y) > 0.0 ? dn(c, 0.9) : up(c, 0.3);
			}
			if (h > 0.992) {
				c = h > 0.996 ? SPRUCE4 : BRINE5;
			}
		} else if (ink_hash(px + 2.0) < 0.2) {
			c = dn(c, 0.4);
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
		// PAVEMENT: clints of pale limestone, long blocks laid along one
		// dominant joint, cut by grikes: deep ink cuts with a worn pale lip and
		// moss down in them. A grike runs a few blocks and stops; cross joints
		// break a clint into lengths, offset row to row, so it never makes a
		// grid. Drill-hole rows on a few clints.
		vec2 r = vec2(dot(wp, vec2(0.94, 0.34)), dot(wp, vec2(-0.34, 0.94)));
		float across = r.y + (ink_vnoise(vec2(r.x * 0.06, 3.0)) - 0.5) * 0.9;
		const float ROW = 1.9;
		float row = floor(across / ROW);
		float fy = (across - row * ROW);
		float rh = ink_hash(vec2(row, 11.0));
		float along = r.x + rh * 11.0;
		float seg_len = 1.5 + rh * 1.6;
		float seg = floor(along / seg_len);
		float fx = along - seg * seg_len;
		float sh = ink_hash(vec2(row, seg));
		// A clint's own slightly leaning edges, so blocks are not rectangles.
		float lean = (ink_hash(vec2(row, seg + 3.0)) - 0.5) * 0.5;
		float end_x = fx + lean * fy;
		float gw = 0.1 + ink_vnoise(vec2(r.x * 0.5, row * 7.0)) * 0.09 + rag(wp);
		bool grike_on = ink_hash(vec2(row, floor(along / 3.4) + 20.0)) < 0.58;
		bool cross_on = ink_hash(vec2(row, seg + 40.0)) < 0.82;
		float cw = 0.08 + rag(wp);
		c = sh < 0.3 ? dn(c, 0.1) : (sh > 0.8 ? up(c, 0.1) : c);
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
			vec3 cr = cells(wp * 0.9 + (vec2(ink_vnoise(wp * 1.7), ink_vnoise(wp * 1.7 + 9.0)) - 0.5) * 0.35);
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
		vec3 v = cells(wp * 0.45);
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
		float n = ink_vnoise(wp * 0.95) * 0.7 + ink_vnoise(wp * 2.3 + 4.0) * 0.3 + rag(wp);
		if (n > 0.64) {
			c = up(c, 0.4);
			// Bog cotton in drifts on a few hummocks, none on the rest.
			if (ink_vnoise(wp * 0.12 + 40.0) > 0.68 && ink_hash(px) > 0.97) {
				c = LINEN5;
			}
		} else if (n < 0.2) {
			c = n < 0.165 ? BRINE0 : SPRUCE2;
		} else if (n < 0.33) {
			c = dn(c, 0.5);
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
		// ROCK: bare stone: a few long cracks, lichen in small blooms.
		if (ink_vnoise(wp * 0.35) > 0.62) {
			c = dn(c, 0.25);
		}
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
			const float ROW = 1.9;
			float row = floor(r.y / ROW);
			float fy = r.y - row * ROW;
			float stop_at = (ink_hash(vec2(row, 5.0)) - 0.5) * 22.0;
			bool cutting = (r.x > stop_at || ink_hash(vec2(row, 9.0)) < 0.25) && regrow < 0.66 + ink_hash(vec2(row, 13.0)) * 0.12;
			if (cutting && fy < 0.5) {
				c = mix(EARTH1, EARTH2, step(0.55, ink_hash(floor(px / vec2(3.0, 1.0)) + row)));
				if (stroke(px, vec2(5.0, 3.0), 51.0, 0.35, 2.0, 0.5) > 0.5) {
					c = EARTH0;
				}
				if (fy < 0.06) {
					c = dn(c, 0.8);
				}
			} else if (cutting && fy < 0.58) {
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
		float h = ink_hash(vec2(floor(b), floor(px.x / 23.0) + 3.0));
		c = h < 0.3 ? dn(c, 0.15) : (h > 0.8 ? up(c, 0.12) : c);
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
		// MOSS: a deep peat bank, fibrous, over dark wet rock.
		if (dt < 0.3 + (vn - 0.5) * 0.12) {
			c = ink_hash(vec2(col, floor(y * 30.0))) < 0.3 ? EARTH0 : EARTH1;
			if (fract(y * 11.0 + vn) < 0.1) {
				c = EARTH2;
			}
		} else {
			c = SLATE1;
			if (ink_hash(vec2(floor(px.x / 3.0), 2.0)) > 0.75) {
				c = SPRUCE2;
			}
		}
	} else if (id == 3) {
		// PINEWOOD: dark rock in joints, roots hanging from the soil.
		float jh = ink_hash(vec2(floor(px.x / 7.0), 4.0));
		c = jh < 0.4 ? dn(c, 0.25) : c;
		if (mod(px.x, 7.0) < 1.0) {
			c = dn(c, 0.8);
		}
		if (dt < 0.08 + vn * 0.05) {
			c = EARTH1;
		} else if (ink_hash(vec2(px.x, 5.0)) > 0.86 && dt < 0.12 + ink_hash(vec2(px.x, 6.0)) * 0.22) {
			c = EARTH2;
		}
	} else if (id == 4) {
		// SNOWFIELD: a snow cap with a ragged hem and icicle runs over blue rock.
		float hem = 0.07 + ink_hash(vec2(col, 1.0)) * 0.06;
		if (dt < hem) {
			c = RIME5;
		} else if (ink_hash(vec2(col, 2.0)) > 0.78 && dt < hem + ink_hash(vec2(col, 3.0)) * 0.24) {
			c = RIME4;
		} else {
			float b = floor((y + (vn - 0.5) * 0.08) / 0.17);
			c = ink_hash(vec2(b, 4.0)) < 0.5 ? SLATE2 : RIME2;
		}
	} else if (id == 5) {
		// BONELANDS: thick limestone beds, dark bedding planes, joints as ink cuts.
		float b = (y + (vn - 0.5) * 0.04) / 0.24;
		c = ink_hash(vec2(floor(b), 1.0)) < 0.5 ? LINEN3 : LINEN4;
		if (fract(b) < 0.09) {
			c = LINEN1;
		} else if (fract(b) > 0.88) {
			c = up(c, 0.2);
		}
		float jx = floor(px.x / 13.0);
		if (px.x - jx * 13.0 == floor(ink_hash(vec2(jx, floor(b))) * 12.0)) {
			c = LINEN1;
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
	}
	return c;
}

void vertex() {
	sway_w = UV2.x;
	if (sway_w > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float t = TIME * (1.1 + wind_strength) + UV2.y * 6.283 + wp.x * 0.35 + wp.z * 0.21;
		float gust = 0.6 + 0.4 * sin(TIME * 0.37 + wp.x * 0.05 - wp.z * 0.03);
		vec3 push = vec3(sin(t) * 0.7 + 0.45, 0.0, cos(t * 0.8) * 0.5 + 0.3) * sway_w * 0.07 * (0.25 + wind_strength) * gust;
		// Move in whole texels, so a blade steps a pixel and never smears.
		vec3 vp = mat3(VIEW_MATRIX) * push;
		float texel = 2.0 / max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y, 1.0);
		vp.xy = round(vp.xy / texel) * texel;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * (mat3(INV_VIEW_MATRIX) * vp);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wash2 = CUSTOM0.rgb;
	// A mesh without CUSTOM0 reads (0, 0, 0, 1): no second wash is ever pure black.
	wash_blend = dot(CUSTOM0.rgb, vec3(1.0)) > 0.0 ? CUSTOM0.a : 0.0;
	style_packed = UV.x;
	style_blend = UV.y;
	patch_raw = UV2.x > 0.0 ? 0.0 : UV2.y;
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	int m1 = int(COLOR.a * 255.0 + 0.5);
	int m2 = patch_raw >= 1.5 ? int(mod(patch_raw - 2.0 + 0.5, 256.0)) : m1;
	float bend = patch_raw >= 257.5 ? -1.0 : 1.0;
	float patchy = min(patch_raw, 1.0);
	// A second wash (another ground, another country) meets this one on a
	// crisp, ragged edge: never a muddy average, never a dither, never a tile
	// square. The weight is bent by a world field so the edge wanders freely
	// inside its band, and the lighter wash is inked along it, broken like a
	// pen lifting (docs/ART.md: one edge language for every patch).
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
	float s1 = mod(style_packed, 16.0);
	float s2 = floor(style_packed / 16.0 + 0.01);
	style_sel = second ? s2 : s1;
	float unh = 0.0;
	vec3 emit = vec3(0.0);
	if (patchy > 0.0) {
		float pn = ink_vnoise(world_pos.xz * 0.11) * 0.65 + ink_vnoise(world_pos.xz * 0.37) * 0.35 + rag(world_pos.xz);
		c *= 1.0 + patchy * (step(0.66, pn) * 0.04 - step(pn, 0.32) * 0.04);
	}
	if (m >= 40 && m < 60) {
		c = ground_mark(m, c, world_pos.xz, px, emit, unh);
		if (works_inv_size > 0.0) {
			vec4 wk = texture(works_map, world_pos.xz * works_inv_size);
			vec3 wl = texture(works_lines, world_pos.xz * works_inv_size).rgb;
			if (wk.r + wk.g + wk.b + wk.a > 0.02) {
				c = works_mark(m, c, world_pos.xz, px, wk, wl.g, int((second ? s2 : s1) + 0.5), emit, unh);
			}
			if (wl.r > 0.5) {
				c = survey_mark(m, c, world_pos.xz, px, wl.b, int((second ? s2 : s1) + 0.5));
			}
		}
	} else if (m > 60 && m < 70) {
		c = strata(m - 60, c, world_pos, px, emit, unh);
	} else if (m >= 1 && m <= 16) {
		// Embers and flames: they give light, so they are never shaded or hatched.
		float fl = 0.8 + 0.2 * flicker(world_pos, 6.0);
		emit += c * (float(m) / 8.0) * fl;
		unh = 1.0;
	} else if (m >= 17 && m <= 32) {
		// A lamp or a window: dark glass by day, lit when the light goes.
		float dim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
		float on = clamp((0.9 - dim) * 6.0, 0.0, 1.0);
		emit += c * (float(m - 16) / 8.0) * on;
		c = mix(BRINE2, c, on);
		unh = on;
	} else if (m == 33) {
		// A glint: glass or ice catching the light for a moment.
		float gh = ink_hash(floor(world_pos.xz * 7.0) + floor(world_pos.y * 7.0));
		if (fract(TIME * 0.27 + gh * 17.0) < 0.06) {
			c = up(c, 1.6);
			emit += c * 0.3;
		}
	}
	if (edge_ink && unh < 0.5) {
		c = dn(c, 0.75);
	}
	unhatched = unh;
	c *= paper(px);
	ALBEDO = sky_apply(c, world_pos, TIME);
	EMISSION = c * emission_strength + emit + neon_reflect(world_pos, sky_px(world_pos)) + neon_skyglow(c);
}

void light() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	float ndl = dot(NORMAL, LIGHT);
	int style = int(style_sel + 0.5);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.0, ndl) * step(0.5, ATTENUATION);
		float band = ndl > 0.42 ? 1.0 : 0.9;
		// Depth of shade: 0 in cast shadow on a sunward face, 1 on a face turned away.
		float depth = lit > 0.5 ? 0.0 : clamp(0.55 - ndl * 0.8, 0.0, 1.0);
		// The sky lays ink on lit faces (cloud shadow, night) and lifts it (lamplight, fog).
		vec3 sk = sky_ink(world_pos, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
		float ink = max(1.0 - lit, sk.x) * hatch(style, px, depth + sk.z) * (1.0 - sk.y) * (1.0 - unhatched);
		vec3 k = mix(shade_tint * sky_shade.rgb, vec3(band), max(lit, unhatched));
		k = mix(k, ink_tint, ink * 0.75);
		DIFFUSE_LIGHT += LIGHT_COLOR * k / PI;
	} else {
		// Lamps and fire: a warm pool in hard steps; its ink is lifted in sky_ink().
		vec3 up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float a = sky_pool(clamp(ATTENUATION * step(-0.2, ndl), 0.0, 1.0) * sky_lamp_gate(up.y, (INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).y), world_pos);
		// Ink & Neon: a pool is a low stain of coloured light on wet dark ground;
		// the light itself and its reflection carry the brightness.
		DIFFUSE_LIGHT += LIGHT_COLOR * a * 0.3 / PI;
	}
}
