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
		float n = ink_vnoise(wp * 1.7) * 0.7 + ink_vnoise(wp * 4.1) * 0.3;
		if (n > 0.56) {
			c = dn(c, 0.55);
			if (n < 0.61 && ink_hash(px) < 0.35 && ink_vnoise(wp * 0.09 + 3.0) > 0.4) {
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
		float h = ink_hash(px);
		if (h > 0.995) {
			c = LINEN5;
		} else if (h < 0.006) {
			c = dn(c, 0.9);
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
		// SNOW: drifts as long shapes laid by the wind; each drawn by its blue
		// lee and a broken crest line. Soot in some lees, the odd glint.
		vec2 wd = vec2(0.83, 0.55);
		float across = dot(wp, wd);
		float along = dot(wp, vec2(-wd.y, wd.x));
		float d = ink_vnoise(vec2(along * 0.1, across * 0.42)) * 0.75 + ink_vnoise(wp * 0.6) * 0.25;
		if (d > 0.6 && d < 0.68) {
			c = RIME4;
			if (d < 0.615 && ink_hash(px) < 0.5) {
				c = RIME5;
			}
			if (ink_vnoise(wp * 0.7 + 11.0) > 0.74 && ink_hash(px + 7.0) < 0.12) {
				c = ASH3;
			}
		} else if (d >= 0.68 && d < 0.7 && ink_hash(floor(px / vec2(3.0, 1.0))) > 0.3) {
			c = RIME3;
		}
		float g = ink_hash(px + 3.7);
		if (g > 0.997 && fract(TIME * 0.21 + g * 91.0) < 0.12) {
			c = vec3(1.0);
			emit += vec3(0.25);
		}
	} else if (m == 45) {
		// PAVEMENT: clints of pale limestone split by grikes. The grikes are ink
		// cuts that wander and break off; they never make a grid.
		vec2 r = vec2(dot(wp, vec2(0.96, 0.28)), dot(wp, vec2(-0.28, 0.96)));
		vec2 warp = vec2(ink_vnoise(wp * 0.5), ink_vnoise(wp * 0.5 + 9.0)) - 0.5;
		vec3 v = cells(vec2(r.x * 0.32, r.y * 0.6) + warp * 0.45);
		c = v.z < 0.25 ? dn(c, 0.22) : (v.z > 0.85 ? up(c, 0.15) : c);
		float edge = v.y - v.x;
		float gate = ink_vnoise(wp * 1.1 + 4.0);
		if (edge < 0.04 && gate > 0.42) {
			c = gate > 0.74 ? MOSS2 : INK3;
		} else if (edge < 0.075 && gate > 0.42) {
			c = up(c, 0.3);
		} else if (v.z > 0.9 && edge > 0.3 && edge < 0.34 && mod(px.x, 3.0) < 1.0) {
			// A row of drill holes across a clint: the machine age in the stone.
			c = LINEN1;
		}
	} else if (m == 46) {
		// ASH: soft drifts, flakes, ember glints (unhatched, glowing) and now
		// and then a leaf of burnt ruled paper.
		float dr = ink_vnoise(vec2(dot(wp, vec2(0.7, -0.7)) * 0.12, dot(wp, vec2(0.7, 0.7)) * 0.5));
		if (dr > 0.66) {
			c = up(c, 0.22);
		} else if (dr < 0.3) {
			c = dn(c, 0.25);
		}
		vec2 cell = floor(px / vec2(9.0, 7.0));
		vec2 lp = px - cell * vec2(9.0, 7.0);
		float eh = ink_hash(cell + vec2(41.0, 17.0));
		if (eh < 0.02 && lp == floor(vec2(ink_hash(cell), ink_hash(cell + 2.0)) * vec2(8.0, 6.0))) {
			float fl = flicker(vec3(cell.x, 0.0, cell.y), 3.0 + eh * 40.0);
			c = mix(EMBER3, EMBER4, fl);
			emit += c * (0.6 + 0.6 * fl);
			unh = 1.0;
		} else if (stroke(px, vec2(6.0, 5.0), 17.0, 0.3, 2.0, -1.0) > 0.5) {
			c = dn(c, 0.6);
		}
		vec2 pc = floor(wp / 2.3);
		vec2 pl = (wp - pc * 2.3) * 26.0;
		if (ink_hash(pc + 5.0) < 0.1 && pl.x > 20.0 && pl.x < 27.0 && pl.y > 30.0 && pl.y < 35.0) {
			c = abs(pl.y - 32.0) < 0.7 ? LINEN2 : LINEN3;
		}
	} else if (m == 47) {
		// CLINKER: vitrified black glass, a few long cracks, green glints, rust.
		float n = ink_vnoise(wp * 0.8);
		c = n > 0.55 ? mix(INK1, SPRUCE1, 0.5) : c;
		float crack = abs(ink_vnoise(wp * 0.9 + 3.0) - 0.5);
		if (crack < 0.018) {
			c = STONE1;
		}
		if (ink_hash(px + 2.0) > 0.994 && n > 0.5) {
			c = SPRUCE4;
		}
		if (ink_vnoise(wp * 0.5 + 8.0) > 0.76) {
			c = mix(c, RUST2, 0.5);
		}
	} else if (m == 48) {
		// FEN: hummocks and hollows, black pools with green edges, bog cotton.
		float n = ink_vnoise(wp * 0.95) * 0.7 + ink_vnoise(wp * 2.3 + 4.0) * 0.3;
		if (n > 0.64) {
			c = up(c, 0.4);
			if (ink_hash(px) > 0.985) {
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
		// PEAT: spade-cut lines, black wet patches, a little heather.
		float cut = fract(wp.y * 1.2 + ink_vnoise(wp * 0.3) * 0.7);
		if (cut < 0.06 && ink_vnoise(wp * 1.3) > 0.35) {
			c = dn(c, 0.9);
		} else if (cut < 0.1) {
			c = up(c, 0.25);
		}
		if (ink_vnoise(wp * 0.8) > 0.74) {
			c = mix(c, BRINE0, 0.6);
		}
		if (stroke(px, vec2(5.0, 5.0), 12.0, 0.18, 2.0, 0.0) > 0.5) {
			c = BLOOM2;
		}
	} else if (m == 50) {
		// NEEDLES: a brown floor swept into long curves by something on its
		// round: the contours of a slow field, drawn faint and broken.
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
		if (lich > 0.8 && ink_hash(px + 8.0) < 0.45) {
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

// Terrace walls: each country's rock, banded by world height. dt: depth below
// the wall's top (a wall is one level tall).
vec3 strata(int id, vec3 c, vec3 wp, vec2 px, inout vec3 emit, inout float unh) {
	float y = wp.y;
	float top = (floor(y / 0.5 - 0.002) + 1.0) * 0.5;
	float dt = top - y;
	float col = floor(px.x / 2.0);
	float vn = ink_vnoise(vec2(px.x * 0.07, y * 3.0));
	if (id == 1) {
		// COAST: thin slate beds, a soil line, white streaks under ledges.
		float b = (y + (vn - 0.5) * 0.05) / 0.11;
		float h = ink_hash(vec2(floor(b), 3.0));
		c = h < 0.35 ? dn(c, 0.3) : (h > 0.75 ? up(c, 0.25) : c);
		if (fract(b) < 0.2) {
			c = dn(c, 0.7);
		}
		if (dt < 0.05 + vn * 0.04) {
			c = EARTH1;
		}
		float st = ink_hash(vec2(col, 9.0));
		if (st > 0.94 && dt < 0.1 + fract(st * 31.0) * 0.3) {
			c = LINEN4;
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
		// BURNING: basalt columns, and a few joints still glowing.
		float cx = floor((px.x + floor(ink_hash(vec2(floor(y / 0.35), 1.0)) * 3.0)) / 5.0);
		float lx = px.x - cx * 5.0;
		float h = ink_hash(vec2(cx, floor((y + ink_hash(vec2(cx, 2.0)) * 0.4) / 0.45)));
		c = h < 0.33 ? INK2 : (h < 0.7 ? STONE0 : INK3);
		if (lx < 1.0) {
			c = up(c, 0.6);
		} else if (lx > 3.5) {
			c = dn(c, 0.6);
			if (ink_hash(vec2(cx, floor(y * 12.0))) > 0.93) {
				float fl = flicker(vec3(cx, y * 4.0, 0.0), 2.0);
				c = mix(EMBER2, EMBER3, fl);
				emit += c * (0.5 + 0.5 * fl);
				unh = 1.0;
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
		// ICE: streaked blue.
		c = ink_hash(vec2(floor(px.x / 2.0), floor(y * 6.0))) < 0.5 ? RIME3 : RIME4;
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
	int m2 = patch_raw >= 1.5 ? int(patch_raw - 2.0 + 0.5) : m1;
	float patchy = min(patch_raw, 1.0);
	// A second wash (another ground, another country) meets this one on a ragged
	// pixel edge: never a muddy average, never a tile square.
	bool second = wash_blend > 0.0 && ink_edge(wash_blend, px) > 0.5;
	vec3 c = second ? wash2 : COLOR.rgb;
	int m = second ? m2 : m1;
	float s1 = mod(style_packed, 16.0);
	float s2 = floor(style_packed / 16.0 + 0.01);
	style_sel = second ? s2 : s1;
	float unh = 0.0;
	vec3 emit = vec3(0.0);
	if (patchy > 0.0) {
		float pn = ink_vnoise(world_pos.xz * 0.11) * 0.65 + ink_vnoise(world_pos.xz * 0.37) * 0.35;
		c *= 1.0 + patchy * (step(0.64, pn) * 0.055 - step(pn, 0.34) * 0.05);
	}
	if (m >= 40 && m < 60) {
		c = ground_mark(m, c, world_pos.xz, px, emit, unh);
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
	unhatched = unh;
	c *= paper(px);
	ALBEDO = sky_apply(c, world_pos, TIME);
	EMISSION = c * emission_strength + emit;
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
		float ink = (1.0 - lit) * hatch(style, px, depth) * (1.0 - unhatched);
		vec3 k = mix(shade_tint, vec3(band), max(lit, unhatched));
		k = mix(k, ink_tint, ink * 0.75);
		DIFFUSE_LIGHT += LIGHT_COLOR * k / PI;
	} else {
		// Lamps and fire: three hard steps, and inside the pool the page is
		// clean: light adds back what the hatching took (docs/ART.md §6).
		float a = clamp(ATTENUATION * step(-0.2, ndl), 0.0, 1.0);
		a = floor(a * 3.0 + 0.5) / 3.0;
		float erase = hatch(style, px, 1.0) * step(0.3, a) * 0.9;
		DIFFUSE_LIGHT += LIGHT_COLOR * a * (1.0 + erase) / PI;
	}
}
