// A lit thing's halo: a camera-facing disc added over the scene in two hard
// steps (a bright core, a faint ring), never a smooth bloom. Only flames and
// lamps get one; nobody glows.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.94, 0.73, 0.31);
uniform float strength = 0.5;
uniform float core = 0.42;

void vertex() {
	// Face the camera, keep the node's position and scale.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = r < core ? 1.0 : (r < 1.0 ? 0.35 : 0.0);
	ALBEDO = color * ring * strength;
}
