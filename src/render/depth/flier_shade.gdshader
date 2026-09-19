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
	float r = clamp(radius, 0.0, 1.0);
	// A BEAM'S FOOTPRINT, NOT A CLOUD, and this is the second correction taken off
	// a frame. What stood here was soft all the way out with no core and no edge,
	// on the reasoning that a hard disc under a moving thing reads as a decal.
	// True, and it solved the wrong half: a featureless falloff five and a half
	// tiles wide, over a street, IS FOG. Shot over the city it read as weather —
	// a pale patch with no cause anywhere in the frame — and the machine it was
	// supposed to be evidence of went unnoticed entirely.
	//
	// What says "something is up there looking down" is STRUCTURE: a core bright
	// enough to have a middle, falling away fast, and a rim where the cone's edge
	// cuts. Neither is hard — the rim is two smoothsteps wide, so it is a beam
	// seen through night air and not a sticker — but between them the patch has a
	// shape the eye can attribute to a source, which a gaussian never has.
	// The two terms have to OVERLAP. Cubed, the core was spent by 0.6 while the rim
	// did not begin until 0.55, which left a dark trough between them and drew a
	// halo — a ring with a hole in it, which is a flying saucer and not a beam.
	// The core is carried out far enough to meet the rim and the rim is only a
	// firming of the edge, so the falloff stays monotonic all the way out.
	float core = pow(1.0 - r, 1.8);
	float rim = smoothstep(0.52, 0.84, r) * (1.0 - smoothstep(0.84, 1.0, r));
	float a = COLOR.a * (core + rim * 0.22);
	// On the machines' power, like every other light of theirs, so a strike
	// stutters the traffic overhead exactly as it stutters the strip it was cut
	// from. And only once the light has gone: a searchlight at noon is a stain.
	float dim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
	a *= neon_burn(dim) * sky_power();
	ALBEDO = matter_light(COLOR.rgb) * a;
	ALPHA = a;
}
