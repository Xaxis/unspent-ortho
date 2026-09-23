// The readability rim for people (docs/LOOK.md section 5): a hairline
// round the silhouette in the person's own colours, one ramp step lighter on the
// side toward the key light (screen upper left) and one step darker opposite.
// Never ink-black. Drawn as a next pass of person.gdshader: the back faces,
// pushed out across the screen by exactly one texel along the smoothed normal
// SkinRig stores in TANGENT (skinned with the bones, so the rim follows limbs).
//
// Figures read at every hour: the rim takes a little colour from the nearest
// lamp, fire or lantern (the pools the lights system hands the sky), and in
// gloom the side of the outline facing that light catches it, so a person
// standing near a fire, or carrying the lantern, is drawn by its light.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, skip_vertex_transform, fog_disabled, shadows_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/models/people/person_light.gdshaderinc"

uniform vec3 step_down = vec3(0.700, 0.704, 0.749);
// Rim width in WORLD units, not in pixels. It used to be one texel of the
// 640x360 image, which at 1920x1080 is a third as thick and at another zoom is
// something else again; a width in world units is the same apparent line
// whatever the tier renders at, which is what the web path needs.
uniform float width = 0.021;
// How far past a pool's own range a figure still takes its colour.
uniform float reach = 1.6;

varying vec3 world_pos;
varying float toward;
varying vec2 rim_dir;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 v = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = (MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz;
	vec2 dir = length(n.xy) > 1e-4 ? normalize(n.xy) : vec2(0.0);
	// Orthographic: 2 / P[1][1] is the view height in world units.
	v.xy += dir * width;
	// A hair toward the camera would let the rim cover the body; a hair away
	// keeps it behind.
	v.z -= width * 0.5;
	VERTEX = v;
	NORMAL = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	toward = dot(dir, normalize(vec2(-1.0, 1.0)));
	rim_dir = dir;
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 lit = toward > -0.2 ? min(c / step_down, vec3(1.0)) : c * step_down;
	vec3 at;
	vec4 lamp = person_nearest_light(world_pos, reach, at);
	float strength = clamp(lamp.a * 1.5, 0.0, 1.0);
	float gloom = sky_gloom();
	vec3 col = sky_apply(lit, world_pos, TIME);
	// The whole line takes the light's colour in the pool: warm by a fire, cold by
	// the lantern (the same stepped wash as the body, so line and body agree).
	col = person_in_light(col, lit, lamp, sky_pool(lamp.a, world_pos) * step(0.35, gloom));
	// The side of the outline that faces the light catches it: a whole ramp step
	// lighter than the lit rim, in the light's colour.
	vec2 to_light = (VIEW_MATRIX * vec4(at - world_pos, 0.0)).xy;
	float facing = length(to_light) > 1e-4 ? dot(rim_dir, normalize(to_light)) : 0.0;
	// Only on the silhouette, where a back face turns edge-on: the inside of an
	// open hem seen from above is a back face too, facing the camera, and must
	// never light up as a sheet.
	float edge = step(abs(normalize(NORMAL).z), 0.6);
	float catch_light = step(0.2, facing) * step(0.3, strength) * step(0.35, gloom) * edge;
	vec3 caught = min(min(lit / step_down, vec3(1.0)) / step_down, vec3(1.0)) * (0.45 + lamp.rgb * 0.75);
	col = mix(col, caught, catch_light);
	ALBEDO = matter_albedo(col);
	ALPHA = 1.0;
}
