// FOREGROUND: the world between the camera and the place (docs/LOOK.md law 3,
// "the world has thickness"). Boughs, snapped lines, eaves and girders that
// stand over the play plane, so that something is in front of something.
//
// WHY THIS IS NOT TRANSPARENT, and it is deliberate. A transparent world
// material at the default render_priority is drawn and then painted over by
// everything opaque, which is a silent, total failure -- another builder lost an
// afternoon to it on the same day this was written. Every alpha here is a
// DISCARD against a world-pinned stipple, exactly as world.gdshader cuts a
// crown, so this draws in the opaque pass, sorts by depth like the land, writes
// depth for everything behind it and has no priority to get wrong. A foreground
// layer is the one thing in the game that MUST be in front, and the way to be
// sure of that is to not be transparent at all.
//
// WHY IT IS NOT world.gdshader, since it is the same kind of matter. Two
// reasons, and the second is the whole package:
//
//   1. world.gdshader is the TERRAIN's shader: two washes meeting on a ragged
//      edge, cliff strata, ground marks, patches. A bough wants one wash.
//   2. `crown_clear` cuts a crown by its HORIZONTAL distance from the body it
//      would hide, which is right for a crown two units up and wrong for
//      anything higher. Under an orthographic camera a thing at height h draws
//      over the ground point h/tan(pitch) further from the eye than its own --
//      2.6 tiles for a bough at four units, against `crown_clear`'s reach of
//      1.6. The existing cut would have opened a hole in clear air and left the
//      machine hidden. So the hole here is opened where the piece actually
//      DRAWS, not where it stands (`fore_lean`, `fore_toward`).
//
// That second point is this package's central risk, stated as arithmetic: an
// occluder may never hide a threat or a thing that can be taken.
//
// Everything else -- colour space, what the surface is, what the land has done
// to it, the air it is seen through -- goes through the same three includes the
// world does, so a bough is lit by exactly the same renderer, in exactly the
// same weather, as the ground under it.
shader_type spatial;
// Needle blades and rags are single triangles: they have no back, so culling
// one would make a bough vanish from underneath, which is exactly where a
// player standing under it is.
render_mode cull_disabled;

#include "res://src/render/sky.gdshaderinc"
#include "res://src/render/ink.gdshaderinc"
#include "res://src/render/matter.gdshaderinc"

// The wind, as SkyLight writes it. Declared here as world.gdshader declares it
// (not in sky.gdshaderinc), because a global uniform may be declared by every
// shader that reads it and the sky include is shared with shaders that do not.
global uniform float wind_strength;

// Bodies a foreground piece may never hide: (x, the ground's own height there,
// z, reach in tiles). Reach 0 is an unused slot. The player is always slot 0.
const int FORE_CLEAR = 8;
uniform vec4 fore_clear[FORE_CLEAR];
// Tiles further from the eye that a piece draws over, per unit of its height:
// 1/tan(pitch). Written from the LIVE camera, so a target lean or a zoom cannot
// move the hole off the body it is for.
uniform float fore_lean = 0.6494;
// The horizontal direction toward the camera, unit length. Same source.
uniform vec2 fore_toward = vec2(0.7071, 0.7071);
// 0 draws the piece whole; 1 takes it away. The view fades a piece in and out
// at the edge of its band with this, in stipple, so nothing ever pops.
uniform float fore_thin = 0.0;

varying vec3 world_pos;
varying float sway_w;

void vertex() {
	// The same sway the world's own crowns take, from the same globals, so a
	// bough over the frame moves with the wood it grew out of and not to its
	// own beat. In whole texels: a blade steps a pixel and never smears.
	sway_w = UV2.x;
	if (sway_w > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float t = TIME * (1.1 + wind_strength) + UV2.y * 6.283 + wp.x * 0.35 + wp.z * 0.21;
		float gust = 0.6 + 0.4 * sin(TIME * 0.37 + wp.x * 0.05 - wp.z * 0.03);
		vec3 push = vec3(sin(t) * 0.7 + 0.45, 0.0, cos(t * 0.8) * 0.5 + 0.3)
			* sway_w * 0.07 * (0.25 + wind_strength) * gust;
		vec3 vp = mat3(VIEW_MATRIX) * push;
		float texel = 2.0 / max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y, 1.0);
		vp.xy = round(vp.xy / texel) * texel;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * (mat3(INV_VIEW_MATRIX) * vp);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// How much of this fragment is in the way of something that must be seen.
// `wp` is where the piece IS; `g` is the ground point it draws over, which is
// the only thing a player can compare it against.
float fore_cut(vec3 wp) {
	float cut = 0.0;
	for (int i = 0; i < FORE_CLEAR; i++) {
		vec4 p = fore_clear[i];
		if (p.w <= 0.0) {
			continue;
		}
		vec2 g = wp.xz - fore_toward * max(wp.y - p.y, 0.0) * fore_lean;
		float d = length(g - p.xz);
		// Wide open in the middle and stippled only at the rim, because the
		// point of the hole is that the thing under it READS, not that there is
		// a hole. A rim of noise is what stops it being a drawn disc.
		cut = max(cut, 1.0 - smoothstep(p.w * 0.58, p.w, d));
	}
	return cut;
}

void fragment() {
	vec2 px = matter_px(world_pos);
	float cut = max(fore_cut(world_pos), fore_thin);
	// Gone outright over the body, stipple at the edge of the hole. Stipple,
	// never a fade: a half-transparent branch over a machine is worse evidence
	// than either a branch or no branch (docs/ART.md law 5, kept by LANTERN).
	if (cut > 0.86 || (cut > 0.0 && ink_hash(px + vec2(53.0, 11.0)) < cut)) {
		discard;
	}
	vec3 c = COLOR.rgb;
	c = sky_apply(c, world_pos, TIME);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	int mi = int(COLOR.a * 255.0 + 0.5);
	vec4 mr = matter_of(mi);
	float rough_add = 0.0;
	// A LIT BOARD OVER THE STREET. A sign arm's board carries `GroundColors.NEON`
	// (34) and means exactly what it means in world.gdshader: dark enamel by day,
	// burning when the light goes, and on the MACHINES' power, so a strike
	// stutters the advertising over the lane the same way it stutters the strip it
	// was cut from. At ten units up, over a street, the LIGHT is the whole of what
	// carries -- nobody is reading the lettering from this camera.
	//
	// Wear is skipped on it on purpose: `matter_worn` grows salt and rust in the
	// seams of a built thing, and a tube that is lit does not bloom.
	vec3 emit = vec3(0.0);
	bool neon = (mi == 34);
	if (neon) {
		float ndim = (sky_tint.r + sky_tint.g + sky_tint.b) / 3.0;
		float non = neon_burn(ndim) * sky_power();
		emit = c * 2.0 * non;
		c = mix(c * 0.32, c, non);
	}
	// How much of the land a piece takes ON, by exactly world.gdshader's rule:
	// a GROUND material (40..70) takes a little, anything else takes it nearly
	// whole. It matters more here than anywhere, because `matter_worn` only
	// grows SEAMS above 0.5 -- seams are for things that were built -- and a
	// bough given 0.85 came back as a white crystalline star: salt and frost
	// blooming out of the seams of a pine needle. A girder over the bog still
	// rusts along its flanks and an eave over the salt still blooms.
	float takes = (mi >= 40 && mi <= 70) ? 0.14 : 0.85;
	if (!neon) {
		c = matter_worn(c, matter_wear(world_pos), n_world, world_pos, takes, rough_add);
	}
	ALBEDO = matter_albedo(c);
	ROUGHNESS = clamp(mr.x + rough_add, 0.04, 1.0);
	SPECULAR = mr.y;
	METALLIC = mr.w;
	NORMAL = matter_bump(NORMAL, world_pos, mi, mr.z);
	EMISSION = matter_light(neon_reflect(world_pos, px) + emit);
}

// No light(). The renderer lights it, against the same sun, the same sky and
// the same lamps as the ground it is standing over -- which is the only reason
// a piece hung four units up reads as part of the place and not as a sticker.
