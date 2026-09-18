// What a flying machine puts on the street under it (FlierView).
//
// IT IS A LIGHT AND NOT A SHADOW, and that was a correction taken off a frame.
// The first version laid a bar of shade, which is what LANTERN law 3 says a near
// thing does for a far one and is the right answer in daylight. The city is at
// permanent night under its own lid: a dark disc on a dark street is nothing at
// all, and the machine itself is nineteen units up, which is deep inside the
// near depth of field, so the body reads as a smudge crossing the top of the
// frame. What a player can actually SEE of a machine passing over a night street
// is the light it drops — which is also the image the owner asked for.
//
// So it is the machines' own cold light, additive, and it does nothing in
// daylight because an additive pool against a lit street is already washed out.
// The colour is the machines' (`works.gd` STRIP), so the one violet-cold thing
// crossing a sodium street is a machine, which is the cue `palette.gd` reserves
// the band for.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

// The disc's own radius, read off the MODEL and not off UV: MeshKit writes uvs
// for the material library's own purposes and a builder that never set them
// would give every fragment the same one. The mesh is a unit disc, so the
// vertex's length IS the radius.
varying float radius;

void vertex() {
	radius = length(VERTEX.xz);
}

void fragment() {
	// Soft all the way out, with no core and no edge: a hard disc under a moving
	// thing reads as a decal, and what says a machine is overhead is that a
	// patch of street brightens and passes.
	float a = COLOR.a * pow(1.0 - clamp(radius, 0.0, 1.0), 2.0);
	// On the machines' power, like every other light of theirs, so a strike
	// stutters the traffic overhead exactly as it stutters the strip it was cut
	// from. And only once the light has gone: a searchlight at noon is a stain.
	float dim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
	a *= neon_burn(dim) * sky_power();
	ALBEDO = matter_light(COLOR.rgb) * a;
	ALPHA = a;
}
