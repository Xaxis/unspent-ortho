// The sky as it is SEEN, for a camera that can see the horizon
// (SkyLight.sees_horizon: the eye-level, over-the-shoulder view).
//
// The play camera never shows the sky: it looks down at 57 degrees, and the sky
// there is only what metal and water reflect, which a ProceduralSkyMaterial does
// well. Seen, a sky has to carry an hour on its own -- a low sun warming the
// horizon on its side of the world and not the other, the stars over a coast at
// midnight, the moon, weather coming over -- and a gradient of two colours
// carries none of that. SkyLight swaps this in only while the horizon is in
// frame, so the orthographic game reflects exactly the sky it always did.
//
// Every colour is the hour's own, handed over by SkyLight from the same keys the
// light is built from (DAY/DUSK/NIGHT_SKY_*, bent by the landscape's air), so the
// sky can never disagree with the light it is the source of.
//
// THE SUN HERE IS WHERE THE SUN REALLY IS. The light's own bearing is chosen for
// the length of a shadow on screen and never drops much below sixty degrees
// (SkyLight._elevation_for_shadow); drawn there, the disc would hang overhead
// at dusk. `sun_dir` shares its AZIMUTH -- so the warm side of the sky is the
// side the light comes from -- and takes its elevation off the clock.
shader_type sky;

// The dome itself -- its colours, glow, cloud, sun, moon and stars -- lives in
// sky_dome.gdshaderinc, so what stands IN this sky (the colossi) takes its air
// from the same arithmetic. Only the procedural sky's light discs stay here,
// because LIGHTn_* exist only in a sky shader.
// The ring in the sky (src/render/orbit/orbit_sky.gdshaderinc), sampled from its
// own layer; only this shader draws it.
#define DOME_ORBIT
#include "res://src/render/sky_dome.gdshaderinc"

vec3 procedural(vec3 d) {
	vec3 sky = dome_procedural_sky(d);
	sky = dome_sun_in(sky, d, LIGHT0_ENABLED, LIGHT0_DIRECTION, LIGHT0_SIZE, LIGHT0_COLOR, LIGHT0_ENERGY);
	sky = dome_sun_in(sky, d, LIGHT1_ENABLED, LIGHT1_DIRECTION, LIGHT1_SIZE, LIGHT1_COLOR, LIGHT1_ENERGY);
	sky = dome_sun_in(sky, d, LIGHT2_ENABLED, LIGHT2_DIRECTION, LIGHT2_SIZE, LIGHT2_COLOR, LIGHT2_ENERGY);
	sky = dome_sun_in(sky, d, LIGHT3_ENABLED, LIGHT3_DIRECTION, LIGHT3_SIZE, LIGHT3_COLOR, LIGHT3_ENERGY);
	return dome_procedural_join(d, sky);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	if (dome_seen <= 0.0) {
		COLOR = procedural(d);
	} else {
		COLOR = dome_color(procedural(d), dome_seen_col(d, AT_CUBEMAP_PASS));
	}
}
