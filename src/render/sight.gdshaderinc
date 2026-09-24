// THE LINE OF SIGHT, for a camera that stands close (docs/LOOK.md law 3:
// "Nothing in front may hide what the player must see").
//
// Every other cut in this game asks where a fragment DRAWS on the ground, which
// is the right question for a camera high over the land: what covers a body is
// whatever stands tall enough to reach into the picture over it. Over the
// shoulder that question has no answer -- the eye is two units up, a cottage
// between it and the player is SHORTER than the eye, and `tall_cut` (which only
// opens what stands over `tall_floor`) never touches it.
//
// So a close eye asks the direct question instead: is this fragment inside the
// cone from the eye to the subject's body? That cone is exactly the set of
// points that draw over the body on screen, at every depth, so the hole is where
// the body is and nowhere else. Stipple is the caller's (a discard against a
// world-pinned hash), never a fade.
//
// ONLY FOR A CLOSE EYE, weighted by how close: `sight_close` is 1 with the eye
// within SIGHT_ON of the player and 0 past SIGHT_OFF. The lens a held Z takes
// stands about fourteen units back and is outside it entirely, so the cut
// `tall_cut` makes there -- and the owner's call that a cottage does not open
// under that lens -- is untouched; the glide down to the shoulder passes through
// the band, which is where the cut comes in, stippling up as the eye comes down.

#ifndef SIGHT_GDSHADERINC
#define SIGHT_GDSHADERINC

// World units over a subject's ground where its body's middle is.
const float SIGHT_MID = 0.95;
// The body's own half-size seen from the eye, grown a little so the rim of the
// hole falls off the silhouette rather than on it.
const float SIGHT_RADIUS = 1.15;
// Nothing this close in front of the subject is cut: its own hands, what it
// holds, the ground it stands on.
const float SIGHT_KEEP = 0.7;
const float SIGHT_ON = 6.0;
const float SIGHT_OFF = 9.0;

// How much of the close-eye cut applies, from the eye's distance to slot 0 (the
// player, always).
float sight_close(vec3 eye, vec4 player) {
	if (player.w <= 0.0) {
		return 0.0;
	}
	float d = distance(eye, vec3(player.x, player.y + SIGHT_MID, player.z));
	return 1.0 - smoothstep(SIGHT_ON, SIGHT_OFF, d);
}

// 0 keep, 1 take: whether `wp` lies in the cone from `eye` to the body at slot `p`.
float sight_cone(vec3 wp, vec3 eye, vec4 p) {
	if (p.w <= 0.0) {
		return 0.0;
	}
	vec3 s = vec3(p.x, p.y + SIGHT_MID, p.z);
	vec3 v = s - eye;
	float len = length(v);
	if (len < 0.01) {
		return 0.0;
	}
	vec3 a = v / len;
	vec3 r = wp - eye;
	float t = dot(r, a);
	if (t <= 0.0 || t > len - SIGHT_KEEP) {
		return 0.0;
	}
	float d = length(r - a * t);
	float rim = SIGHT_RADIUS * t / len;
	return 1.0 - smoothstep(rim * 0.72, rim * 1.2, d);
}

// THE PLAYER'S OWN BODY GETS OUT OF THE WAY OF THE EYE. Over the shoulder and
// tipped up past Shoulder.PITCH_LEAST (the gaze, looking up at a colossus), the
// eye comes forward to the head (Shoulder.rise) and the figure it passes through
// is stippled away by the same share. xyz: the player's feet; w: how much of the
// body is gone, 0..1. Written by CameraRig every frame the lens is up, 0
// otherwise, so every other frame pays one comparison.
global uniform vec4 eye_yield;
// How far round the feet's column the body reaches (its held tool included).
const float YIELD_REACH = 1.25;

// True where this fragment of a body is to be dropped: inside the player's own
// column, on a screen-pinned stipple whose share is w. A stipple, never an alpha,
// so the figure keeps its depth and its rim on the pixels it still owns.
bool sight_yield(vec3 wp, vec2 frag) {
	if (eye_yield.w <= 0.0) {
		return false;
	}
	vec2 d = wp.xz - eye_yield.xz;
	float h = wp.y - eye_yield.y;
	if (dot(d, d) > YIELD_REACH * YIELD_REACH || h < -0.2 || h > 2.3) {
		return false;
	}
	return ink_hash(floor(frag) + vec2(17.0, 3.0)) < eye_yield.w;
}

#endif
