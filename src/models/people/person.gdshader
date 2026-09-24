// MADE, for people. Cloth, leather, patched wool and skin, lit by the renderer
// like everything else under LANTERN, plus the one thing docs/LOOK.md section 5
// asks of people only: a readability rim (person_rim.gdshader, the next pass),
// so a figure is never lost against the ground it is standing on.
//
// THE RIM IS NOW THE ONLY THING HOLDING A PERSON APART FROM THE WORLD. The
// camera's full-screen ink pass is gone (LANTERN removes every drawing
// technique), and people used to be excluded from it on purpose and given the
// rim instead. Everything else has lost its outline and gained real light and
// material to be told apart by; a person is small, moves, and is the one thing
// the player must never lose, so they keep theirs.
//
// People stay in the TRANSPARENT pass (ALPHA 1, render_priority 10) because the
// rim is a grow-shell that has to draw over them; they still write and test
// depth, so the world occludes them and they occlude themselves, and their
// shadow comes from a shadows-only twin (SkinRig).
shader_type spatial;
render_mode cull_back, depth_draw_always;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/models/people/person_light.gdshaderinc"
#include "res://src/render/sight.gdshaderinc"

uniform float emission_strength = 0.0;

varying vec3 world_pos;
varying float skin;

// Cloth is rough and almost never shines; skin catches a little. Both are far
// rougher than any FOUND surface, which is half of how a person reads against a
// machine at a glance.
const float PERSON_CLOTH_ROUGH = 0.92;
const float PERSON_SKIN_ROUGH = 0.66;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	skin = UV2.y;
}

void fragment() {
	if (sight_yield(world_pos, FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = COLOR.rgb;
	vec3 at;
	// A person standing in a lamp's pool takes the lamp's own colour on their
	// face. The renderer lights them; this only says WHICH light is nearest, so
	// the warm cast on a face agrees with the pool on the ground under it.
	vec4 lamp = person_nearest_light(world_pos, 1.05, at);
	float gloom = sky_gloom();
	ALBEDO = matter_albedo(person_in_light(sky_apply(c, world_pos, TIME), c, lamp,
		clamp(lamp.a, 0.0, 1.0) * step(0.35, gloom)));
	ALPHA = 1.0;
	ROUGHNESS = mix(PERSON_CLOTH_ROUGH, PERSON_SKIN_ROUGH, step(0.5, skin));
	SPECULAR = mix(0.25, 0.45, step(0.5, skin));
	METALLIC = 0.0;
	// The weave, small enough to catch a low sun on a shoulder and nothing more.
	NORMAL = matter_bump(NORMAL, world_pos, -1, 0.004);
	EMISSION = matter_light(c * emission_strength);
}
