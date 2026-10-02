// A WALKER'S PLATE IN DAYLIGHT, for the far body (colossus.gdshader) and for the
// patch of it under a climber's hands (found.gdshader, `near_lift`), so where
// the patch ends the body goes on in the same light. Include after
// matter.gdshaderinc.
//
// THE LIGHT IT TAKES OVER THE RENDERER'S. The renderer's sun is the one the land
// is lit by at eye level; over a body kilometres across it leaves the whole
// machine one dark value. So the plate takes the sky's own light too: the
// zenith's blue on every face by how far it looks up (the fill a thing in open
// air stands in), and the real sun on the faces turned to it -- tops of the hub
// and the thighs lit, undersides in their own shade.
const float WALKER_SKY_FILL = 0.55;
const float WALKER_SUN_TOP = 1.1;
// What a face turned straight down takes of the zenith's light from the ground
// under an eye on the ground (`walker_low`).
const float WALKER_LOW = 0.35;

// UP CLOSE (colossus_leg_model.gd NEAR_LIFT and NEAR_FILL say why): how much of
// the near rule a plate `d` metres from the eye takes, 1 nearer than `lift.y`,
// 0 past `lift.z`, and always 0 with `lift.x` 0.
float walker_near(vec4 lift, float d) {
	return lift.x > 0.0 ? 1.0 - smoothstep(lift.y, lift.z, d) : 0.0;
}

// The plate `c` (as the far body keeps it) raised `lift.x` times over by `t`,
// and `lift.w` of the way to its own grey as it is, so it is weathered metal in
// daylight and not a brighter violet.
vec3 walker_near_albedo(vec3 c, vec4 lift, float t) {
	vec3 up = c * (1.0 + lift.x * t);
	return mix(up, vec3(dot(up, vec3(0.299, 0.587, 0.114))), lift.w * t);
}

// The light a face turned straight down takes from under it: the ground's bounce,
// a share of the zenith's, for an eye near the ground; for an eye high in the air
// (`aloft` 0..1, SkyLight.aloft_share) the air under it, which is the dome's
// own ground half from up there (`low_col`). Up a leg the faces in its own shade
// were lit by the dark bounce alone and came out a flat black slab.
vec3 walker_low(vec3 top_col, vec3 low_col, float aloft) {
	return mix(top_col * WALKER_LOW, low_col, aloft);
}

// What the day adds to a plate whose normal is `n` (world), seen from `to_eye`
// (world, toward the eye), as a factor on its albedo. `low_col` is the light from
// under it (walker_low), `near` is walker_near's share and `fill` its strength.
// Up close the renderer's own sun is true, and the far body's second sun goes;
// in its place the open air in front of the plate lights it, the day's white,
// most on what faces the eye and least on what the sun already has, so a face
// in the leg's own shade still shows its lips, chamfers and rivets, and a face
// in the sun is not burnt flat.
vec3 walker_day(vec3 n, vec3 to_eye, vec3 sun_dir, vec3 sun_col, vec3 top_col, vec3 low_col, float near, float fill) {
	vec3 sun = normalize(sun_dir);
	float day = clamp(sun.y * 4.0, 0.0, 1.0);
	float sun_n = max(dot(n, sun), 0.0);
	vec3 sky = mix(low_col, top_col, n.y * 0.5 + 0.5) * WALKER_SKY_FILL;
	vec3 lit = sun_col * sun_n * WALKER_SUN_TOP * (1.0 - near);
	vec3 front = mix(top_col, sun_col, 0.5) * (0.5 + 0.5 * max(dot(n, to_eye), 0.0)) * (1.0 - 0.8 * sun_n) * fill * near;
	return (sky + lit + front) * day;
}
