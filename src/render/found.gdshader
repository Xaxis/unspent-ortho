// FOUND: the machines and everything taken off them (pylons, plate on roofs,
// salvage kit).
//
// LANTERN (docs/LOOK.md) keeps the MADE/FOUND split that ART.md drew with two
// pens, and moves it into MATERIAL, where it is stronger. FOUND is METAL:
// panelled, ruled, precise, with a real specular response and seams that catch
// the light. MADE is timber, mud, thatch and cloth, and nothing about it is
// straight. You can tell them apart at a glance in a dark frame with one lamp
// in it, which is the test a pen line could never pass.
//
// There is no light() here either. The renderer lights the metal.
//
// The one warm read on a machine is still the amber LENS (docs/ART.md section
// 4), and the machine's own light -- strips, beacons, a working part -- still
// runs on sky_power(), so a lightning strike stutters it.
shader_type spatial;
render_mode cull_back;

#define SKY_FOUND
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

uniform float emission_strength = 0.0;
// Machines keep their light at night: they are powered and the land is not.
uniform float night_keep = 0.35;
// How much of the built-in glow (vertex alpha, below) the hour leaves. 1 is a
// lamp burning in the dark. A lamp under the noon sun is NOT a brighter lamp:
// pushed to full it blows its own colour out to white, which is how a hostile
// machine came to carry exactly one pure-white pixel at noon and no colour at
// all. Turned down by day the lens shows the colour it is made of.
// Props leave it at 1; MachineModel drives it from the sky's darkness.
uniform float glow_scale = 1.0;
// How worn a piece of FOUND is. Plate off a wreck takes the land's rust and
// soot whole; a machine still on its round is kept, and takes about half.
uniform float wear_take = 1.0;
// How deep its panel relief runs. A pylon's plate is heavier than a salvage kit.
uniform float relief = 1.0;

// A blow's paper-white, as a sphere in world space (docs/ART.md section 7).
// Only the part that was struck goes white: a machine that whites out whole
// proves nothing about where the blow landed, hides its own amber working part
// at the exact moment the player is aiming at it, and is the biggest thing in
// the frame. `flash_r` 0 is every draw but the sixty milliseconds after a hit.
// MobFx.set_flash writes these into a copy of the struck body's material.
uniform vec3 flash_at = vec3(0.0);
uniform float flash_r = 0.0;
uniform vec3 flash_col = vec3(0.9098, 0.8627, 0.7529);

varying vec3 world_pos;

// How metal a machine reads. Not 1.0: a fully metallic surface has no diffuse
// at all, and in a dark game lit by two lamps that is a machine you cannot see
// the shape of. Held here so the body keeps its ramp and the light adds to it.
const float FOUND_METAL = 0.52;
// These machines have stood out in the weather for years. A smooth metal under
// a high sun throws the sun's own reflection straight up at this camera, which
// is exactly how a harvester came to measure BRIGHTER than the turf it stands
// on -- the one thing docs/ART.md section 4 and the Palette contract say a
// machine must never be. It is rough because it is filthy, and what is left
// smooth is the one rubbed edge.
const float FOUND_ROUGH = 0.64;
// Where the plate is rubbed back to bare metal: the chamfer lines and the one
// worn edge, and nothing else.
const float FOUND_RUBBED = 0.20;
// THE MACHINE-AGAINST-THE-TURF LAW, and this is where it is enforced.
//
// docs/ART.md section 4 and the Palette contract: "the body fill sits BELOW the
// turf in value, so the amber LENS stays the only saturated thing on a machine
// and a machine is a dark mass by day". The palette keeps that -- the harvester's
// fill is luma 0.322 against the coast turf's 0.373 -- but a palette value was
// authored as what a surface LOOKED like when it was drawn in two flat bands,
// not as what it reflects. Handed to a real sun and a real sky unchanged, a
// machine's broad up-faces come back over the turf, which has meanwhile been
// darkened by its own wear: measured +10.4 on main and +10.3 with the metal
// merely roughened.
//
// So a machine's albedo is taken down to what it must be for the ordering to
// survive the light. It is one number, it is measured, and the measurement is
// tests/render/test_machine_mass.gd -- which shoots the frame rather than
// reading the table, because the table was never what was wrong.
const float FOUND_MASS = 0.55;

// The panels a machine is built out of, in world space and on the machines'
// own bearing -- ruled, regular, and nothing like the torn edges of the land.
// Returns x: how near a seam (1 on it), y: which panel (0..1, for its finish).
vec2 found_panels(vec3 wp) {
	// Two families of ruled lines at right angles on a fixed bearing, plus the
	// horizontal courses plate is laid in. A machine is a made thing: its
	// pattern is periodic, not noisy.
	vec2 q = vec2(wp.x * 0.7071 + wp.z * 0.7071, wp.x * -0.7071 + wp.z * 0.7071);
	vec3 grid = vec3(q * 1.6, wp.y * 2.4);
	vec3 f = abs(fract(grid) - 0.5);
	float seam = 1.0 - smoothstep(0.0, 0.055, min(f.x, min(f.y, f.z)));
	float panel = ink_hash(floor(grid.xy) + floor(grid.z) * 7.0);
	return vec2(seam, panel);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	// The hour, the weather and what has settled in the air. Nothing LIES on a
	// machine (SKY_FOUND), and its wash is dimmed less than the land's: they
	// are powered and the land is not.
	vec3 tinted = sky_apply(c, world_pos, TIME);
	c = mix(tinted, c, night_keep * (1.0 - clamp(dot(tinted, vec3(0.333)) / max(dot(c, vec3(0.333)), 1e-3), 0.0, 1.0)));

	// A light built into the machine: vertex alpha below 1. 0.5..0.98 a steady
	// strip (brighter lower); below 0.5 a beacon that blinks on a slow machine
	// beat, each at its own phase.
	float glow = 0.0;
	if (COLOR.a < 0.98) {
		if (COLOR.a >= 0.5) {
			glow = (1.0 - COLOR.a) * 5.0;
		} else {
			float beat = fract(TIME * 0.45 + dot(floor(world_pos.xz * 0.5), vec2(0.37, 0.61)));
			glow = step(beat, 0.18) * (1.0 - COLOR.a * 2.0) * 6.0 + 0.15;
		}
	}
	bool lit_part = emission_strength > 0.0 || COLOR.a < 0.98;

	vec2 pan = found_panels(world_pos);
	// Every panel is finished a shade differently, and its seams are darker and
	// rougher than its face: that is what makes a machine read as ASSEMBLED
	// rather than moulded, and it is the FOUND half of law 1.
	float rub = smoothstep(0.80, 1.0, pan.y);
	// Every panel is finished a shade differently, and a seam is darker than the
	// face either side of it. Only ever DOWN from the ramp's own value: the
	// palette put the body fill below the turf deliberately and nothing here may
	// lift it back over.
	c *= 1.0 - pan.y * 0.09 - pan.x * 0.30;
	float rough = mix(FOUND_ROUGH, FOUND_RUBBED, rub) + pan.x * 0.42;

	// What standing HERE has done to it. A machine is the thing the law was
	// written for: the same harvester rusts along its underside in the bog,
	// blooms white in its seams on the salt flat, and blacks in its lee in the
	// Burning, because the land it stands in says so and nothing else does.
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rough_add = 0.0;
	if (!lit_part) {
		c = matter_worn(c, matter_wear(world_pos), n_world, world_pos, wear_take, rough_add);
	}

	ALBEDO = matter_albedo(lit_part ? c : c * FOUND_MASS);
	METALLIC = lit_part ? 0.0 : FOUND_METAL;
	ROUGHNESS = clamp(rough + rough_add, 0.05, 1.0);
	SPECULAR = 0.48;
	if (!lit_part) {
		// The seams themselves, as relief: a ruled bevel, not a torn one.
		NORMAL = matter_bump(NORMAL, world_pos, -1, 0.006 * relief);
		vec3 bevel = vec3(dFdx(pan.x), -dFdy(pan.x), 0.0) * 0.5 * relief;
		NORMAL = normalize(NORMAL - clamp(bevel, vec3(-1.0), vec3(1.0)));
	}
	// The machines' own light runs on their power: a lightning strike stutters it.
	EMISSION = matter_light((c * emission_strength + c * glow * glow_scale) * sky_power())
		+ matter_light(neon_skyglow(c));
	// The blow's white, hard-edged because FOUND is made to a rule. Laid as
	// EMISSION over a black albedo so it lands on exactly that value whatever
	// the light is doing. It whitens PLATE and never LIGHT: a machine's own
	// strips keep burning through their own hit mark, which is the whole point
	// -- the player is aiming at the amber part, and the blow that lands must
	// not be the thing that hides it.
	if (flash_r > 0.0 && !lit_part && distance(world_pos, flash_at) < flash_r) {
		ALBEDO = vec3(0.0);
		METALLIC = 0.0;
		EMISSION = matter_light(flash_col);
	}
}
