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
// The one warm read on a machine is still the amber LENS (docs/LOOK.md section
// 4), and the machine's own light -- strips, beacons, a working part -- still
// runs on sky_power(), so a lightning strike stutters it.
shader_type spatial;
render_mode cull_back;

#define SKY_FOUND
#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"
#include "res://src/render/near_mask.gdshaderinc"
#include "res://src/render/sight.gdshaderinc"
#include "res://src/render/colossus/walker_plate.gdshaderinc"

uniform float emission_strength = 0.0;
// A share of the pixels this draw keeps, on a screen-pinned stipple: 1 keeps
// them all (every draw but one). A colossus's near foot comes in over its far
// body on it (src/render/colossus/colossus_foot.gd), the far body keeping the
// complement (colossus.gdshader `l0_share`), so the handover never pops.
uniform float lod_keep = 1.0;
// How big the plates are, over a man-sized machine's (1). A colossus's foot is
// made of plates the size of a house (colossus_foot.gd sets it).
uniform float panel_scale = 1.0;
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
// How much of the world's ruled panels (`found_panels`) it wears: 0 for plate
// whose panels are laid in its geometry (the leg a climber is on,
// colossus_leg.gd), which the world's upright grid would cut across in a
// lattice of seams on a leg leaning over.
uniform float ruled = 1.0;

// PLATE A HAND IS ON (the leg a climber is on; colossus_leg_model.gd sets 1):
// its wear is laid on each plate's own frame, which rides in its vertices (UV2
// the metres across and up the plate from its lower corner; CUSTOM0 its width,
// the height that shows below the row lapped over it, its pick, and which part
// of it a face is: 1 the face, 2 the chamfer, 3 a lip, 0 none). The world's
// wear is keyed on world space, and on a leg that walks it slid across the
// plates with every stride. 0 everywhere else, where nothing reads those
// vertices.
uniform float plate_detail = 0.0;

// A WALKER UP CLOSE IS LIT AS FORM (colossus_leg_model.gd NEAR_LIFT): the
// patch under a climber's hands is the far body's plate, in the far body's
// daylight (walker_plate.gdshaderinc), raised near the eye, so it reads by its
// faces, lips and seams while the same body a few hundred metres off is the
// dark mass the ground sees. x 0 (every other draw) leaves FOUND as it is.
// The patch and, while a climb is live, the near foot are handed the dome's
// sun and zenith every frame (colossus_leg_model.gd `daylight`).
uniform vec4 near_lift = vec4(0.0, 1.0, 2.0, 0.0);
uniform float near_fill = 0.0;
uniform vec3 near_sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 near_sun_color : source_color = vec3(1.0);
uniform vec3 near_top_color : source_color = vec3(0.29, 0.42, 0.66);
// AND WHERE A WALKER'S PART HAS NO PLATES OF ITS OWN (the near foot sets 1), the
// near rule lays them in the shader as the pitches lay them in geometry
// (`virtual_plate`), taking over from the ruled panels as it comes in: from the
// drum the foot's top was house-size panels, flat, under a riveted pitch.
uniform float plate_virtual = 0.0;

// Written once a frame by 18_crowns. Four (x, the ground's own height there,
// z, reach in tiles); reach 0 is an unused slot. Zero = the cut is off.
global uniform mat4 found_clear;
global uniform float found_floor;

// A blow's paper-white, as a sphere in world space (docs/LOOK.md section 7).
// Only the part that was struck goes white: a machine that whites out whole
// proves nothing about where the blow landed, hides its own amber working part
// at the exact moment the player is aiming at it, and is the biggest thing in
// the frame. `flash_r` 0 is every draw but the sixty milliseconds after a hit.
// MobFx.set_flash writes these into a copy of the struck body's material.
uniform vec3 flash_at = vec3(0.0);
uniform float flash_r = 0.0;
uniform vec3 flash_col = vec3(0.9098, 0.8627, 0.7529);

varying vec3 world_pos;
varying vec2 plate_uv;
varying vec4 plate_of;
varying vec3 model_pos;
varying vec3 model_n;

// How metal a machine reads. Not 1.0: a fully metallic surface has no diffuse
// at all, and in a dark game lit by two lamps that is a machine you cannot see
// the shape of. Held here so the body keeps its ramp and the light adds to it.
const float FOUND_METAL = 0.52;
// These machines have stood out in the weather for years. A smooth metal under
// a high sun throws the sun's own reflection straight up at this camera, which
// is exactly how a harvester came to measure BRIGHTER than the turf it stands
// on -- the one thing docs/LOOK.md section 4 and the Palette contract say a
// machine must never be. It is rough because it is filthy, and what is left
// smooth is the one rubbed edge.
const float FOUND_ROUGH = 0.64;
// Where the plate is rubbed back to bare metal: the chamfer lines and the one
// worn edge, and nothing else.
const float FOUND_RUBBED = 0.20;
// THE MACHINE-AGAINST-THE-TURF LAW, and this is where it is enforced.
//
// docs/LOOK.md section 4 and the Palette contract: "the body fill sits BELOW the
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
// survive the light. It is one number and it is MEASURED ON A FRAME, because
// the table was never what was wrong: shoot
//   tools/shot.sh x.png --seed=7 --place=coast --spawn=harvester,watcher --zoom=8 --hour=12
// and take the median luma of the violet-hued pixels against the green ones.
// main: +10.4. Roughening the metal alone: +10.3. This: -13.0.
//
// tests/models/test_machines_ramps.gd still holds the PALETTE half of the law
// (no kind meets another at step 3, the fill is under the coast turf, nothing
// leaves the violet arc). A headless test cannot render the frame, so the
// number above is reported rather than pinned, and this constant is the one
// place anybody has to look when it drifts.
const float FOUND_MASS = 0.55;

// The panels a machine is built out of, in world space and on the machines'
// own bearing -- ruled, regular, and nothing like the torn edges of the land.
// Returns x: how near a seam (1 on it), y: which panel (0..1, for its finish).
vec2 found_panels(vec3 wp) {
	// Two families of ruled lines at right angles on a fixed bearing, plus the
	// horizontal courses plate is laid in. A machine is a made thing: its
	// pattern is periodic, not noisy.
	vec2 q = vec2(wp.x * 0.7071 + wp.z * 0.7071, wp.x * -0.7071 + wp.z * 0.7071);
	vec3 grid = vec3(q * 1.6, wp.y * 2.4) / panel_scale;
	vec3 f = abs(fract(grid) - 0.5);
	float seam = 1.0 - smoothstep(0.0, 0.055, min(f.x, min(f.y, f.z)));
	// A seam thinner than a pixel is let go rather than drawn: past that it is
	// not a ruled line but a crawl of noise across the plate.
	vec3 fw = fwidth(grid);
	seam *= 1.0 - smoothstep(0.12, 0.35, max(fw.x, max(fw.y, fw.z)));
	float panel = ink_hash(floor(grid.xy) + floor(grid.z) * 7.0);
	return vec2(seam, panel);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	plate_uv = UV2;
	plate_of = CUSTOM0;
	model_pos = VERTEX;
	model_n = NORMAL;
}

// THE PLATES OF A SURFACE THAT HAS NONE (`plate_virtual`): PLATE_W by PLATE_H,
// as colossus_leg_model.gd lays the pitches' (PANEL), each row half a plate
// over, on the surface's own lines in the model's frame so they ride with it. A
// face that stands up is laid with its rows up it; one that looks up or down, on
// the model's x and z. Returns where on its plate `p` is, metres from its lower
// corner, and writes that plate's frame for `plate_worn` into `of`.
const float PLATE_W = 4.0;
const float PLATE_H = 6.0;

vec2 virtual_plate(vec3 p, vec3 n, out vec4 of) {
	vec2 s = p.xz;
	if (abs(n.y) < 0.7) {
		vec3 t = normalize(cross(vec3(0.0, 1.0, 0.0), n));
		s = vec2(dot(p, t), p.y);
	}
	float row = floor(s.y / PLATE_H);
	float x = s.x + mod(row, 2.0) * PLATE_W * 0.5;
	float col = floor(x / PLATE_W);
	of = vec4(PLATE_W, PLATE_H, ink_hash(vec2(col, row) + vec2(17.0, 3.0)), 1.0);
	return vec2(x - col * PLATE_W, s.y - row * PLATE_H);
}

// THE WEAR OF ONE PLATE, on its own lines (`plate_detail`), and the relief it
// leaves in `bump` (metres, for the normal). Rivets along its lapped lower edge,
// two rows, which fasten it through the plate it laps, and up its sides; scores
// where grit and boots have run, mostly up and down the pitch; grime in its
// lips, in the lap under the row above and streaked down its face from there;
// and a broad stain of its own. Every term only takes value AWAY (the ramp's
// value is the law's, above): a rubbed rivet head or a score is told by the
// light, as a smoother finish, never as a lighter paint.
const float RIVET_IN = 0.12;
const float RIVET_EVERY = 0.22;
const float RIVET_R = 0.03;
const float RIVET_ROW = 0.14;

// How near the nearest rivet is, across a plate `w` wide and `h` showing.
float plate_rivet(vec2 q, float w, float h) {
	float n = max(1.0, floor((w - 2.0 * RIVET_IN) / RIVET_EVERY));
	float sx = (w - 2.0 * RIVET_IN) / n;
	float ix = clamp(floor((q.x - RIVET_IN) / sx + 0.5), 0.0, n);
	// The second row is staggered half a pitch, as a lap joint is.
	float ix2 = clamp(floor((q.x - RIVET_IN) / sx), 0.0, n - 1.0);
	float d = length(q - vec2(RIVET_IN + ix * sx, RIVET_IN));
	d = min(d, length(q - vec2(RIVET_IN + (ix2 + 0.5) * sx, RIVET_IN + RIVET_ROW)));
	float m = max(1.0, floor((h - 2.0 * RIVET_IN) / RIVET_EVERY));
	float sy = (h - 2.0 * RIVET_IN) / m;
	float iy = clamp(floor((q.y - RIVET_IN) / sy + 0.5), 0.0, m);
	d = min(d, length(q - vec2(RIVET_IN, RIVET_IN + iy * sy)));
	d = min(d, length(q - vec2(w - RIVET_IN, RIVET_IN + iy * sy)));
	return d;
}

// A score across the plate: lanes a few centimetres apart, a few of them cut,
// each for a length and then not.
float plate_score(vec2 q, float id, float h) {
	float a = (id - 0.5) * 0.7;
	vec2 r = vec2(cos(a) * q.x - sin(a) * q.y, sin(a) * q.x + cos(a) * q.y);
	float lane = r.x * 17.0;
	float li = floor(lane);
	float on = step(0.7, ink_hash(vec2(li, id * 91.0 + 1.0)));
	float s0 = ink_hash(vec2(li + 3.0, id * 57.0)) * h;
	float len = 0.5 + ink_hash(vec2(li, id * 13.0 + 7.0)) * 2.4;
	float along = smoothstep(s0, s0 + 0.15, r.y) * (1.0 - smoothstep(s0 + len - 0.4, s0 + len, r.y));
	float fw = fwidth(lane);
	float cut = 1.0 - smoothstep(0.04, 0.1 + fw, abs(fract(lane) - 0.5));
	// Finer than a pixel it is let go, not drawn as a crawl.
	return on * along * cut * (1.0 - smoothstep(0.35, 0.8, fw));
}

vec3 plate_worn(vec3 c, vec2 q, vec4 of, inout float rough, out float bump) {
	float w = of.x;
	float h = of.y;
	float id = of.z;
	int part = int(of.w + 0.5);
	bump = 0.0;
	float fw = length(fwidth(q));
	// The plate's own finish and a broad stain across it.
	c *= 1.0 - id * 0.07;
	float stain = ink_vnoise(q * 0.55 + vec2(id * 31.0, id * 17.0));
	c *= 1.0 - smoothstep(0.45, 0.85, stain) * 0.14;
	if (part == 3) {
		// Down in a lip, where nothing reaches to clean it.
		rough = min(1.0, rough + 0.2);
		return c * 0.72;
	}
	if (part == 2) {
		// The chamfer is the edge that catches: rubbed bright by the light, and
		// only by the light.
		rough = mix(rough, 0.24, 0.8);
		return c;
	}
	// The lap: grime gathers under the row above, and runs from it down the
	// face in streaks, each as long as its own weather made it.
	float lap = smoothstep(h - 0.7, h, q.y);
	float sx = q.x * 2.6 + id * 11.0;
	float col = floor(sx);
	float run = step(0.5, ink_hash(vec2(col, id * 7.0 + 2.0)));
	float reach = 0.8 + ink_hash(vec2(col + 5.0, id * 3.0)) * 3.6;
	float streak = run * (1.0 - smoothstep(0.0, reach, h - q.y))
		* (1.0 - smoothstep(0.1, 0.45, abs(fract(sx) - 0.5)));
	// Along its lower edge and sides, grime where it meets the seam.
	float edge = min(min(q.x, w - q.x), q.y);
	float seam = 1.0 - smoothstep(0.0, 0.3, edge);
	c *= 1.0 - max(lap * 0.3, max(streak * 0.18, seam * 0.2));
	// The scores: a smoother line in a filthy face, and a groove.
	float score = plate_score(q, id, h);
	rough = mix(rough, 0.3, score * 0.7);
	c *= 1.0 - score * 0.05;
	bump -= score * 0.002;
	// The rivets: a head, rubbed, in a ring of dirt; let go once it is under a
	// pixel and a half.
	float d = plate_rivet(q, w, h);
	float seen = 1.0 - smoothstep(RIVET_R * 0.5, RIVET_R * 1.5, fw);
	float head = (1.0 - smoothstep(RIVET_R - fw, RIVET_R + fw, d)) * seen;
	float ring = (1.0 - smoothstep(RIVET_R, RIVET_R + 0.03 + fw, d)) * (1.0 - head) * seen;
	c *= 1.0 - ring * 0.35 - head * 0.04;
	rough = mix(rough, 0.34, head);
	bump += sqrt(max(0.0, RIVET_R * RIVET_R - d * d)) * seen;
	return c;
}

// A FIGHT IS NEVER HIDDEN (docs/LOOK.md law 5), and until now that was only true
// of MADE geometry. `world.gdshader` has cut timber and thatch out of the way
// for as long as the law has existed; a pylon, a mast, a machine's plate or a
// lamppost has stood straight through the player the whole time. Nobody fixed
// it because the mechanism could not reach here: 18_crowns writes `crown_clear`
// every frame through two material handles, and FOUND has no handle -- it is
// built in eight places (prop_models, machine_model, skin_rig twice,
// survival_marks, gallery, craft and structure models). So the subjects arrive
// as GLOBALS instead, packed into a mat4 the way `sky_lamps` already packs four
// lamps, written once a frame by 18_crowns.
//
// FOUR slots, not world.gdshader's six: the player and the three bodies that
// rank highest by 18_crowns' own `choose()`. A second mat4 for the other two is
// a change nothing has asked for.
//
// NO MATTER MARK IS READ HERE, and that is deliberate rather than an omission.
// `world.gdshader`'s cut takes one so it can refuse the ground band and never
// open the land. On this shader the SAME `COLOR.a` byte is a LAMP -- under 0.5 a
// beacon that blinks -- so reading it as a mark would have every machine's
// beacon voting on whether that machine cuts. FOUND is never the land, so the
// guard is not needed and the argument must not be taken.
//
// INERT UNTIL SOMETHING FILLS IT: every slot defaults to zero, so `w <= 0`
// everywhere, the cut is 0.0 and the discard is unreachable. 18_crowns fills
// real slots only under the perspective lens, so an orthographic frame is
// unchanged. Whether FOUND should cut in the shipped orthographic game too is a
// change to frames the owner has already decided once, and it is his to make.
float found_cut(vec3 wp, vec3 camz, vec3 eye, bool persp) {
	float cut = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 p = found_clear[i];
		if (p.w <= 0.0 || wp.y < p.y + found_floor) {
			continue;
		}
		// Where THIS fragment's own ray meets the subject's ground -- the same
		// per-fragment form world.gdshader uses, including both its guards. See
		// `tall_cut` there for why `s` is negative and why a fragment at or above
		// the eye is skipped rather than left to the distance test.
		vec2 g;
		if (persp) {
			if (wp.y >= eye.y - 0.05) {
				continue;
			}
			float s = (p.y - wp.y) / max(eye.y - wp.y, 0.05);
			g = wp.xz + s * (eye.xz - wp.xz);
		} else {
			g = wp.xz - camz.xz * (wp.y - p.y) / max(0.05, abs(camz.y));
		}
		float d = length(g - p.xz);
		float r = p.w * 1.4;
		cut = max(cut, 1.0 - smoothstep(r * 0.58, r, d));
	}
	return cut;
}

// THE CUT'S STIPPLE: a hash per world-pinned cell, the cell a power of two in
// size near a pixel and a half of this fragment's own footprint, in all three
// axes. Hashed on raw world coordinates, as it was, this hash (made for whole
// cells) varied smoothly and beat against the pixel grid: rings across a plate
// a hand from the eye, and on a vertical face `xz` runs one way only
// (maintenance.tour frame 05). Hashed on the land's grain (matter_px), sized for
// the view from above, a plate a hand from the eye was cut in squares a hand
// across. Pinned to the world it does not crawl as the eye moves; a power of
// two, it changes size only in whole steps.
float found_stipple(vec3 wp) {
	vec3 fw = fwidth(wp);
	float foot = max(max(fw.x, fw.y), max(fw.z, 1e-5));
	float lv = ceil(log2(foot * 1.5));
	vec3 c = floor(wp / exp2(lv));
	return ink_hash(vec2(c.x + c.y * 57.0, c.z - c.y * 113.0) + lv * 7.0 + vec2(53.0, 11.0));
}


void fragment() {
	if (sight_yield(world_pos, FRAGCOORD.xy)) {
		discard;
	}
	if (lod_keep < 1.0 && ink_hash(floor(FRAGCOORD.xy) + vec2(5.0, 29.0)) >= lod_keep) {
		discard;
	}
	if (near_cut > 0.5 && near_drawn(world_pos)) {
		discard;
	}
	// The subjects that must not be hidden, from the camera only: what is cut
	// for the eye still shades (world.gdshader says why). Read INSIDE the stage
	// function because INV_VIEW_MATRIX and PROJECTION_MATRIX do not exist
	// outside one.
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	if (!IN_SHADOW_PASS) {
		vec3 camz = INV_VIEW_MATRIX[2].xyz;
		bool persp = PROJECTION_MATRIX[3][3] < 0.5;
		float cut = found_cut(world_pos, camz, eye, persp);
		// A CLOSE EYE (the view over the shoulder) cuts whatever lies in the line
		// of sight to a body, at any height, as world.gdshader does: a machine
		// city's deck at chest height stood square between the eye and the
		// player, who read as a head on a floor (tours/tight_eye.tour frame 01).
		if (persp) {
			float close = sight_close(eye, found_clear[0]);
			if (close > 0.0) {
				for (int i = 0; i < 4; i++) {
					cut = max(cut, sight_cone(world_pos, eye, found_clear[i]) * close);
				}
				cut = max(cut, sight_near(world_pos, eye, found_clear[0]) * close);
			}
		}
		if (cut > 0.0 && found_stipple(world_pos) < cut) {
			discard;
		}
	}
	vec3 c = COLOR.rgb;
	// The hour, the weather and what has settled in the air. Nothing LIES on a
	// machine (SKY_FOUND), and its wash is dimmed less than the land's: they
	// are powered and the land is not. A walker's plate takes none of it: the
	// cloud shade, the legs' shade and the banks of fog are laid on the land,
	// kilometres under most of a leg, and the far body it goes on into takes
	// none either. On the drum, in its own shin's shade band, the patch read at
	// luma 36 with it and 68 without (13:00).
	vec3 tinted = near_lift.x > 0.0 ? c : sky_apply(c, world_pos, TIME);
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

	float near = walker_near(near_lift, distance(world_pos, eye));
	// Laid plates come in over the ruled panels as the near rule does.
	float laid = lit_part ? 0.0 : plate_virtual * near;
	vec2 pan = found_panels(world_pos) * ruled * (1.0 - laid);
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
	float plate_bump = 0.0;
	vec2 bump_uv = plate_uv;
	bool plated = plate_detail > 0.0;
	if (plated && plate_of.x > 0.0 && !lit_part) {
		c = plate_worn(c, plate_uv, plate_of, rough, plate_bump);
	} else if (!lit_part && !plated) {
		vec3 land = matter_worn(c, matter_wear(world_pos), n_world, world_pos, wear_take, rough_add);
		if (laid > 0.0) {
			vec4 of;
			bump_uv = virtual_plate(model_pos, normalize(model_n), of);
			float laid_rough = rough;
			vec3 v = plate_worn(c, bump_uv, of, laid_rough, plate_bump);
			// The seam between two plates: the dark skin, a few centimetres
			// wide, let go once it is under a pixel.
			float e = min(min(bump_uv.x, of.x - bump_uv.x), min(bump_uv.y, of.y - bump_uv.y));
			float fq = length(fwidth(bump_uv));
			v *= 1.0 - (1.0 - smoothstep(0.05, 0.05 + fq, e)) * (1.0 - smoothstep(0.2, 0.5, fq)) * 0.6;
			land = mix(land, v, laid);
			rough = mix(rough, laid_rough, laid);
			rough_add *= 1.0 - laid;
			plate_bump *= laid;
		}
		c = land;
	}

	ALBEDO = matter_albedo(lit_part ? c : walker_near_albedo(c * FOUND_MASS, near_lift, near));
	METALLIC = lit_part ? 0.0 : FOUND_METAL;
	ROUGHNESS = clamp(rough + rough_add, 0.05, 1.0);
	SPECULAR = 0.48;
	if (plated || laid > 0.0) {
		// A plate's relief is its own too: the slope of its rivets and scores,
		// per metre of it under this pixel.
		float wx = max(length(dFdx(bump_uv)), 1e-5);
		float wy = max(length(dFdy(bump_uv)), 1e-5);
		vec2 g = clamp(vec2(dFdx(plate_bump) / wx, -dFdy(plate_bump) / wy), vec2(-1.0), vec2(1.0));
		NORMAL = normalize(NORMAL - vec3(g, 0.0));
	} else if (!lit_part) {
		// The seams themselves, as relief: a ruled bevel, not a torn one.
		NORMAL = matter_bump(NORMAL, world_pos, -1, 0.006 * relief);
		vec3 bevel = vec3(dFdx(pan.x), -dFdy(pan.x), 0.0) * 0.5 * relief;
		NORMAL = normalize(NORMAL - clamp(bevel, vec3(-1.0), vec3(1.0)));
	}
	// The machines' own light runs on their power: a lightning strike stutters it.
	EMISSION = matter_light((c * emission_strength + c * glow * glow_scale) * sky_power())
		+ matter_light(neon_skyglow(c));
	// A walker's plate takes the far body's daylight (walker_plate.gdshaderinc).
	if (near_lift.x > 0.0 && !lit_part) {
		vec3 n_day = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		EMISSION += ALBEDO * walker_day(n_day, normalize(eye - world_pos), near_sun_dir, near_sun_color, near_top_color, walker_low(near_top_color, near_top_color, 0.0), near, near_fill);
	}
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
