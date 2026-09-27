// Water, drawn like a chart. TerrainMesher writes per vertex:
//   COLOR.r  kind / 8: 0 sea, 1 river or still water, 2 blackwater, 4 a fall
//   COLOR.gb flow direction * 0.5 + 0.5 (zero: still water)
//   COLOR.a  depth: 0 at the waterline .. 1 deep
// The sea is cut into flat depth bands with an inked sounding line at each
// edge, foam that laps in and draws back along the shore, and wave ticks that
// come and go. Rivers carry short dashes downstream and break white where the
// sheet falls. Blackwater is near-black with green edges and an oily marbling.
// No gradients, no gloss.
shader_type spatial;
render_mode cull_back;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

uniform vec3 shade_tint = vec3(0.66, 0.68, 0.82);

// What the INLAND water in view is made of (BiomeDef.water_wash, blended over
// the landscapes in frame by SkyLight.water_wash_at): rgb the colour a middling
// depth takes, w how far the chart is pulled to it. The sea never reads it.
global uniform vec4 water_wash;

const vec3 BRINE0 = vec3(0.0392, 0.0824, 0.1412);
const vec3 BRINE1 = vec3(0.0627, 0.1490, 0.2471);
const vec3 BRINE2 = vec3(0.1059, 0.2471, 0.3765);
const vec3 BRINE3 = vec3(0.1686, 0.3882, 0.5373);
const vec3 BRINE4 = vec3(0.2627, 0.5725, 0.6902);
const vec3 BRINE5 = vec3(0.4980, 0.7961, 0.8471);
const vec3 SPRUCE1 = vec3(0.0824, 0.1451, 0.1882);
const vec3 SPRUCE2 = vec3(0.1137, 0.2353, 0.2549);
const vec3 SPRUCE3 = vec3(0.1647, 0.3529, 0.3255);
const vec3 INK1 = vec3(0.0706, 0.0667, 0.1137);
const vec3 SAND3 = vec3(0.5216, 0.4392, 0.3529);
const vec3 FOAM = vec3(0.8667, 0.9412, 0.9686);
const vec3 LINE = vec3(0.0392, 0.0824, 0.1412);

varying vec3 world_pos;

#include "res://src/render/near_mask.gdshaderinc"

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float band_edge(float d, float t, float w) {
	return 1.0 - smoothstep(0.0, w, abs(d - t));
}

// THE SUN'S PATH. From above, under an orthographic camera, every pixel of the
// sea looks along ONE direction, so the sun's mirror is at the same angle over
// the whole surface: the share of wave faces that catch it is uniform, and no
// bend or roughness can make a path. It is all of the sea or none of it -- a
// white slab at a bend of 0.035, tinfoil from shore to edge at 0.12 (the canon's
// coast morning, 2026-09-24). A path is what perspective does, so here it is
// drawn: the sea keeps its reflection in a band from the middle of the view
// toward the sun's bearing, narrowing as it goes, and elsewhere only OFF_PATH of
// it, with a few glints. A sun behind the viewer puts no path on the sea at all,
// which is the truth. The lens over the shoulder makes a real path, so this
// stands down by the horizon share, and at night it fades out, because the
// moon, a fire on the shore and a beacon are all reflections too.
const float SEA_SPECULAR = 0.5;
const float OFF_PATH = 0.04;
const float PATH_NEAR = 2.4;
const float PATH_FAR = 0.7;
const float PATH_REACH = 14.0;
const float GLINTS = 0.035;

float sun_path(vec2 wp) {
	// `sky_sun.xy` is the offset per unit of height TOWARD the light
	// (SkyLight.compose), so it points along the sun's bearing.
	vec2 toward = sky_sun.xy;
	float len = length(toward);
	if (len < 0.0001) {
		return 1.0;
	}
	toward /= len;
	vec2 rel = wp - sky_focus.xz;
	float along = dot(rel, toward);
	float across = abs(dot(rel, vec2(-toward.y, toward.x)));
	float half_width = mix(PATH_NEAR, PATH_FAR, clamp(along / PATH_REACH, 0.0, 1.0));
	float band = 1.0 - smoothstep(half_width * 0.45, half_width, across);
	return band * smoothstep(-PATH_NEAR, 0.0, along) * (1.0 - smoothstep(PATH_REACH, PATH_REACH * 1.3, along));
}

// A few round spots off the path that catch the light for a moment. Jittered
// cells, soft-edged, so they never stand on a grid.
float sea_glints(vec2 wp, float t) {
	vec3 cell = matter_cells(wp * 2.5);
	float on = step(ink_hash(vec2(cell.z * 37.0, floor(t * 1.7 + cell.z * 13.0))), GLINTS);
	return on * (1.0 - smoothstep(0.05, 0.3, cell.x));
}

// How far the chop bends the normal per unit of its world slope. The camera is
// orthographic, so every pixel of the sea looks along ONE direction: a low sun
// either lies in the specular lobe for the whole surface or for none of it. Only
// normals tilted further than the lobe is wide can break that into a path of
// glints; at 0.035 (about 6 degrees) the whole sea at 08:00 was one white slab.
const float CHOP_BEND = 0.12;
// The chop at `wp`: two octaves of the ink noise, each on axes turned off the
// lattice (37 and 71 degrees) so neither lays a grid.
float chop_at(vec2 wp, float t) {
	vec2 a = mat2(vec2(0.7986, 0.6018), vec2(-0.6018, 0.7986)) * wp;
	vec2 b = mat2(vec2(0.3256, 0.9455), vec2(-0.9455, 0.3256)) * wp;
	return ink_vnoise(a * 2.3 + vec2(t, t * 0.7)) * 0.6 + ink_vnoise(b * 6.1 - vec2(t * 1.3, t)) * 0.4;
}

// Its slope in the world (x, z), by central differences a fifth of a tile wide.
vec2 chop_slope(vec2 wp, float t) {
	const float H = 0.1;
	return vec2(chop_at(wp + vec2(H, 0.0), t) - chop_at(wp - vec2(H, 0.0), t),
		chop_at(wp + vec2(0.0, H), t) - chop_at(wp - vec2(0.0, H), t)) / (2.0 * H);
}

// The swash: 0 drawn back .. 1 run up. Travels along the shore, so the foam
// laps in one stretch while it draws back in the next.
float swash(vec2 wp) {
	return 0.5 + 0.5 * sin(TIME * 1.05 + (wp.x + wp.y) * 0.45 + ink_vnoise(wp * 0.2) * 4.0);
}

void fragment() {
	if (near_cut > 0.5 && near_drawn(world_pos)) {
		discard;
	}
	// World-anchored grain, as everywhere else now (matter.gdshaderinc).
	vec2 px = matter_px(world_pos);
	vec2 wp = world_pos.xz;
	int kind = int(COLOR.r * 8.0 + 0.5);
	// Sea: 0 at the waterline .. 1 deep. Inland (TerrainMesher.inland_alpha):
	// negative on the bank, 1 about 2.5 field units in.
	float d = kind == 0 ? COLOR.a : (COLOR.a * 3.5 - 1.0) / 2.5;
	float w = max(fwidth(d), 1e-4) * 1.2;
	// How fast this water runs: still water is a mirror, running water is not.
	vec2 flow = kind == 0 ? vec2(0.0) : COLOR.gb * 2.0 - 1.0;
	vec3 c;
	if (kind == 0) {
		// COLOR.g on the sea: 1 where it meets an open coast, 0 where the bank is
		// a bog (TerrainMesher._surf_at). Foam belongs to a shore that shelves;
		// against peat the edge is scum and reed, never a beach in a fen.
		float surf = clamp(COLOR.g, 0.0, 1.0);
		// The chart's pale shallows belong to the coast too: where the sea lies
		// against peat it takes the fen's own dark greens, so an inlet in the
		// moss is not a lagoon on a bog.
		c = mix(d < 0.12 ? SPRUCE2 : (d < 0.45 ? SPRUCE1 : BRINE0),
			d < 0.12 ? BRINE3 : (d < 0.45 ? BRINE2 : BRINE1), surf);
		// Soundings: a solid line at the shallows, a dotted one further out.
		if (band_edge(d, 0.12, w) > 0.5) {
			c = mix(c, LINE, 0.5);
		} else if (band_edge(d, 0.45, w) > 0.5 && mod(px.x + px.y, 3.0) < 1.0) {
			c = mix(c, LINE, 0.6);
		}
		float s = swash(wp);
		float lap = 0.006 + 0.03 * s;
		if (d < lap && (d < lap - 0.012 || ink_hash(px) < 0.7)) {
			// On a soft bank the same band is scum and weed, a step DARKER than
			// the water, so the edge reads without a 180-luma jump.
			c = mix(ink_vnoise(wp * 1.7) > 0.55 ? SPRUCE1 : SPRUCE3, FOAM, surf);
		} else if (d < lap + 0.02 && ink_hash(px) < 0.5) {
			c = mix(SPRUCE2, BRINE4, surf);
		} else if (surf > 0.5 && abs(d - (0.075 + 0.03 * (1.0 - s))) < 0.006 && ink_hash(floor(px / vec2(2.0, 1.0))) < 0.7) {
			// The line the last wave left.
			c = mix(c, FOAM, 0.6);
		} else if (surf < 0.5 && d < 0.1 && ink_hash(px + 5.0) > 0.94) {
			// Reeds standing out of the shallows instead.
			c = ink_hash(px + 9.0) < 0.5 ? SPRUCE2 : SPRUCE3;
		}
		// Wave ticks: short dashes that appear and fade on a slow beat.
		float beat = floor(TIME * 0.9);
		vec2 cell = floor(px / vec2(11.0, 7.0));
		float h = ink_hash(cell + vec2(beat * 7.0, beat * 3.0));
		vec2 local = px - cell * vec2(11.0, 7.0);
		if (d > 0.18 && h < 0.08 && local.y == 3.0 && local.x >= 3.0 && local.x < 6.0 + floor(h * 20.0)) {
			c = mix(c, FOAM, (d > 0.45 ? 0.35 : 0.5) * max(surf, 0.35));
		}
	} else if (kind == 2) {
		// Blackwater: green at the edges, an oily film in marbled bands.
		c = d < 0.08 ? SPRUCE2 : (d < 0.22 ? SPRUCE1 : BRINE0);
		if (band_edge(d, 0.08, w) > 0.5) {
			c = SPRUCE3;
		}
		float marb = fract(ink_vnoise(wp * 0.35 + TIME * 0.01) * 5.0 + wp.x * 0.1);
		if (d >= 0.22 && marb < 0.06) {
			c = INK1;
		} else if (d >= 0.22 && marb > 0.5 && marb < 0.53 && ink_hash(px) < 0.5) {
			c = SPRUCE2;
		}
	} else {
		float fl = length(flow);
		c = d < 0.1 ? BRINE3 : BRINE2;
		if (band_edge(d, 0.1, w) > 0.5) {
			c = mix(c, LINE, 0.4);
		}
		if (d < 0.02 + 0.03 * swash(wp * 2.0)) {
			c = BRINE4;
		}
		if (kind == 1 && fl > 0.2) {
			// Flow: a few long threads carried downstream, gathered where the
			// current runs, never an even scatter of specks.
			vec2 dir = flow / fl;
			float along = dot(wp, dir) * 0.9 - TIME * 0.7;
			float across = dot(wp, vec2(-dir.y, dir.x)) * 5.0;
			vec2 cell = vec2(floor(along), floor(across));
			float h = ink_hash(cell + 3.0);
			float run = ink_vnoise(wp * 0.4 + vec2(TIME * 0.05, 0.0));
			if (h < 0.09 * step(0.45, run) && fract(along) < 0.7 && fract(across) < 0.14 && d > 0.3) {
				c = h < 0.02 ? BRINE5 : BRINE4;
			}
		}
		if (kind == 4) {
			// A fall: thin white threads pouring down, broken by the water
			// between them. One pixel wide, never blocks.
			float col = floor(px.x / 2.0);
			float ph = ink_hash(vec2(col, 5.0));
			float fall = fract((px.y - TIME * (18.0 + ph * 10.0)) / (6.0 + ph * 8.0) + ph);
			c = BRINE3;
			if (mod(px.x, 2.0) < 1.0 && fall < 0.55) {
				c = ph < 0.6 ? FOAM : BRINE5;
			}
		}
	}
	if (kind != 0 && water_wash.w > 0.001) {
		// A landscape that has said what its water is: the drawing is kept and
		// only the colour is moved, so a pool gone black keeps its edge, its
		// marbling and its soundings and a brine pan keeps its swash. The value
		// curve flattens toward the top on purpose — foam on dead water is a
		// pale film, not the page.
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, water_wash.rgb * (0.30 + 1.55 * l), water_wash.w);
	}
	// Water ABSORBS. Deep water is nearly black and what you see in it is the
	// sky, the moon and whatever is burning on the shore -- which is the whole
	// of why a night coast is worth looking at, and it cannot happen while the
	// albedo is a bright chart blue with the reflection fighting it. The chart's
	// own structure is kept (soundings, the bank line, the broken white of a
	// fall): this only takes the LEVEL down with depth, and leaves the foam,
	// which is air in water and really is that bright.
	// Only what is really FOAM is spared: at a lower threshold a bog river's
	// pale chart blue counted as foam and the whole of it stayed the brightest
	// thing in the frame.
	float pale = smoothstep(0.80, 0.96, dot(c, vec3(0.2126, 0.7152, 0.0722)));
	float deep = clamp(kind == 0 ? d : d * 0.8, 0.0, 1.0);
	c *= mix(mix(1.0, 0.22, deep), 1.0, pale);
	// THE SUN'S HUE BELONGS IN THE WATER'S REFLECTION, NOT IN ITS BODY. The body
	// colour is lit by the sun like any albedo, so an amber evening sun turned a
	// blue sea to ochre from above and dragged the frame brown (canon 12). Water
	// barely scatters what falls on it; what it shows of the sun is the path and
	// the glints (SPECULAR below) and the sky it mirrors. So the sun's hue is
	// divided back out of the body, and foam, which does scatter, keeps it.
	// Most of it, not all: the whole of it lit a dusk shallows noon blue.
	vec3 sh = mix(vec3(1.0), max(sun_hue.rgb, vec3(0.3)), 0.6);
	c /= mix(sh, vec3(1.0), pale);
	ALBEDO = matter_albedo(sky_apply(c, world_pos, TIME));
	// Water is the smoothest thing in the world and it is what makes a night
	// coast worth looking at: the sky, the moon, a fire on the shore and every
	// machine's beacon are IN it. Deep water is smoother than the ripple at the
	// bank, and a fall is broken white and returns almost nothing.
	float still = 1.0 - clamp(length(flow) * 1.6, 0.0, 1.0);
	ROUGHNESS = clamp(mix(0.34, 0.06, still * clamp(d, 0.0, 1.0)), 0.04, 0.6);
	// F0 4%: real water is 2%, and 0.9 (7%) clipped even the lobe's tails to white.
	// By day the top-down sea keeps it only on the sun's path and at a few glints;
	// see sun_path() for why a path has to be drawn rather than found.
	float day = 1.0 - sky_gloom();
	float top_down = 1.0 - clamp(sky_focus.w, 0.0, 1.0);
	float caught = max(sun_path(wp), sea_glints(wp, TIME));
	SPECULAR = SEA_SPECULAR * mix(1.0, mix(OFF_PATH, 1.0, caught), day * top_down);
	// Under a colossus's pad coming down there is no sky left to mirror
	// (sky.gdshaderinc `sky_colossus_pads`): the water goes dark with the land.
	float under_pad = sky_colossus_pads(world_pos);
	SPECULAR *= 1.0 - under_pad;
	ROUGHNESS = mix(ROUGHNESS, 1.0, under_pad);
	METALLIC = 0.0;
	// The surface's own chop, small and slow, so the reflection breaks up the
	// way water does instead of standing as a mirror.
	//
	// ITS SLOPE IS TAKEN IN THE WORLD, ON TURNED AXES. It was `dFdx/dFdy` of the
	// chop, and a low sun turned both halves of that into blocks on the sea: a
	// screen derivative is one value per 2x2 pixel quad, so the bent normal came
	// in steps, and `ink_vnoise` blends its lattice with a smoothstep whose slope
	// is exactly zero along every integer line -- so the surface lay dead flat on
	// a grid, and a near-mirror caught that grid as white rectangles (seed 1 at
	// 08:00, the spawn's first view). Central differences of the chop in world
	// space are smooth at any render scale, and each octave is turned off the
	// axes so no two share a lattice.
	float t = TIME * 0.35;
	vec2 slope = chop_slope(wp, t);
	vec3 bend = vec3(slope.x, 0.0, slope.y) * CHOP_BEND;
	NORMAL = normalize(NORMAL - clamp((VIEW_MATRIX * vec4(bend, 0.0)).xyz, vec3(-1.0), vec3(1.0)));
}

// There is no light(): the renderer lights the water, and what it finds in it
// is the sky, the sun and every lamp on the shore (docs/LOOK.md law 2).

