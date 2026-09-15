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
render_mode cull_back, specular_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"

uniform vec3 shade_tint = vec3(0.66, 0.68, 0.82);

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float band_edge(float d, float t, float w) {
	return 1.0 - smoothstep(0.0, w, abs(d - t));
}

// The swash: 0 drawn back .. 1 run up. Travels along the shore, so the foam
// laps in one stretch while it draws back in the next.
float swash(vec2 wp) {
	return 0.5 + 0.5 * sin(TIME * 1.05 + (wp.x + wp.y) * 0.45 + ink_vnoise(wp * 0.2) * 4.0);
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy) + world_px;
	vec2 wp = world_pos.xz;
	int kind = int(COLOR.r * 8.0 + 0.5);
	// Sea: 0 at the waterline .. 1 deep. Inland (TerrainMesher.inland_alpha):
	// negative on the bank, 1 about 2.5 field units in.
	float d = kind == 0 ? COLOR.a : (COLOR.a * 3.5 - 1.0) / 2.5;
	float w = max(fwidth(d), 1e-4) * 1.2;
	vec3 c;
	if (kind == 0) {
		c = d < 0.12 ? BRINE3 : (d < 0.45 ? BRINE2 : BRINE1);
		// Soundings: a solid line at the shallows, a dotted one further out.
		if (band_edge(d, 0.12, w) > 0.5) {
			c = mix(c, LINE, 0.5);
		} else if (band_edge(d, 0.45, w) > 0.5 && mod(px.x + px.y, 3.0) < 1.0) {
			c = mix(c, LINE, 0.6);
		}
		float s = swash(wp);
		float lap = 0.006 + 0.03 * s;
		if (d < lap && (d < lap - 0.012 || ink_hash(px) < 0.7)) {
			c = FOAM;
		} else if (d < lap + 0.02 && ink_hash(px) < 0.5) {
			c = BRINE4;
		} else if (abs(d - (0.075 + 0.03 * (1.0 - s))) < 0.006 && ink_hash(floor(px / vec2(2.0, 1.0))) < 0.7) {
			// The line the last wave left.
			c = mix(c, FOAM, 0.6);
		}
		// Wave ticks: short dashes that appear and fade on a slow beat.
		float beat = floor(TIME * 0.9);
		vec2 cell = floor(px / vec2(11.0, 7.0));
		float h = ink_hash(cell + vec2(beat * 7.0, beat * 3.0));
		vec2 local = px - cell * vec2(11.0, 7.0);
		if (d > 0.18 && h < 0.08 && local.y == 3.0 && local.x >= 3.0 && local.x < 6.0 + floor(h * 20.0)) {
			c = mix(c, FOAM, d > 0.45 ? 0.35 : 0.5);
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
		vec2 flow = COLOR.gb * 2.0 - 1.0;
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
	ALBEDO = sky_apply(c, world_pos, TIME);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(shade_tint, vec3(1.0), lit) / PI;
	} else {
		float a = floor(clamp(ATTENUATION, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
		DIFFUSE_LIGHT += LIGHT_COLOR * a / PI;
	}
}
