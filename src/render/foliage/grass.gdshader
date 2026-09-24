// GRASS: every tuft, reed, flower and frond a chunk's decor lays (Decor, the
// `grass` surface). Its own material so a blade pays for what a blade needs --
// the wind, the trample field, a root-to-tip shade and the land's own light --
// and none of the terrain's library (ground marks, strata, works, crown and tall
// cuts: grass stands under CROWN_LIFT and under every tall floor).
//
// Opaque and never discarded, so early-z survives on WebGL. Casts no shadow
// (WorldView); the dark at a blade's root is painted here instead.
//
// Vertex channels (MeshKit, Decor templates):
//   COLOR.rgb  the blade's colour (palette sRGB); COLOR.a its MARK code / 255
//   UV2.x      sway weight: 0 at the root, rising to the tip
//   UV2.y      the plant's seed 0..1: its phase in the wind
shader_type spatial;
render_mode cull_back;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/render/wind.gdshaderinc"

// Where bodies pushed through (18_trample, TrampleField): rg the lean as
// 128 + 127 x lean, b how far it is pressed down. `foliage_trample_at`: xz the
// window's low corner, z 1 / its span; outside it nothing is pressed.
global uniform sampler2D foliage_trample : filter_linear, repeat_enable;
global uniform vec4 foliage_trample_at;

// A blade bends further than a crown: 1 is a crown's stiffness.
const float GRASS_STIFF = 0.55;
// Tiles a tip goes over, per unit of sway weight, when a body parts it.
const float PART_LEAN = 0.42;
// And how far it drops when pressed flat.
const float PRESS_DROP = 0.22;
// How dark the root of a tuft is against its tip: the light the tuft itself
// takes off its own base.
const float ROOT_SHADE = 0.52;
// How much paler a blade laid over by a gust reads: the underside and the
// sheen turned to the sky, which is what carries a front seen from above.
const float GUST_PALE = 0.4;

varying vec3 world_pos;
varying float sway_w;
varying float gust_v;

void vertex() {
	sway_w = UV2.x;
	gust_v = 0.0;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (sway_w > 0.0) {
		vec3 push = wind_push(wp, sway_w, UV2.y, GRASS_STIFF);
		gust_v = gust_at(wp.xz) * sway_w;
		vec2 tuv = (wp.xz - foliage_trample_at.xy) * foliage_trample_at.z;
		if (tuv.x >= 0.0 && tuv.y >= 0.0 && tuv.x < 1.0 && tuv.y < 1.0) {
			vec4 tr = texture(foliage_trample, wp.xz * foliage_trample_at.z);
			vec2 lean = (tr.rg * 255.0 - 128.0) / 127.0;
			push += vec3(lean.x, 0.0, lean.y) * PART_LEAN * sway_w;
			push.y -= (length(lean) * 0.5 + tr.b) * PRESS_DROP * sway_w;
		}
		// A blade keeps its length: the further its tip goes over, the lower it
		// sits, so a gust lays the grass down instead of stretching it.
		float over = length(push.xz);
		push.y -= min(over * over * 1.6 / max(sway_w, 0.1), over * 0.9);
		mat3 to_model = inverse(mat3(MODEL_MATRIX));
		VERTEX += to_model * (mat3(INV_VIEW_MATRIX) * wind_view(push, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE));
		NORMAL = wind_tilt(NORMAL, to_model * push, sway_w, to_model * vec3(0.0, 1.0, 0.0));
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 px = matter_px(world_pos);
	int m = int(COLOR.a * 255.0 + 0.5);
	vec3 c = COLOR.rgb;
	c *= mix(ROOT_SHADE, 1.0, smoothstep(0.0, 0.55, sway_w));
	c = mix(c, c * (1.0 + GUST_PALE) + vec3(0.04, 0.04, 0.03), gust_v);
	c = sky_apply(c, world_pos, TIME);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 mr = matter_of(m);
	float rough_add = 0.0;
	c = matter_worn(c, matter_wear(world_pos), n_world, world_pos, 0.85, rough_add);
	ALBEDO = matter_albedo(c);
	ROUGHNESS = clamp(mr.x + rough_add - gust_v * 0.15, 0.04, 1.0);
	SPECULAR = mr.y;
	METALLIC = mr.w;
	EMISSION = matter_light(neon_reflect(world_pos, px) + neon_skyglow(c));
}
