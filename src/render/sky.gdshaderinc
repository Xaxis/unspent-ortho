// Owned by the sky/weather package. Included by world.gdshader and
// water.gdshader. Everything that tints the lit world by time, weather or
// region goes here, so the geometry shaders never change for it.
global uniform vec3 sky_tint;

vec3 sky_apply(vec3 albedo, vec3 world_pos, float time) {
	return albedo * sky_tint;
}
