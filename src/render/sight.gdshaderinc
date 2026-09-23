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
