// A flame drawn the way a notebook draws one: a few short strokes radiating
// from it, pixel-exact, that lengthen and shorten as it flickers. Never a glow
// disc, never bloom. Screen-aligned; the node's position is the flame.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.94, 0.73, 0.31);
// In screen pixels: the gap around the flame and the longest stroke's reach.
uniform float inner = 3.0;
uniform float outer = 6.0;
// 0 = steady (a lamp), 1 = a fire changing its mind a dozen times a second.
uniform float flicker = 0.0;
// 8 = straight and diagonal strokes; 4 = straight only.
uniform float spokes = 8.0;
uniform float seed = 0.0;

varying vec2 v_px;

float rays_hash(float n) {
	return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

void vertex() {
	float reach = outer + 1.0;
	vec4 c = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0));
	vec2 ndc = c.xy / c.w;
	// Snap the flame to a pixel centre so every stroke is exactly one pixel wide.
	vec2 pix = floor((ndc * 0.5 + 0.5) * VIEWPORT_SIZE) + 0.5;
	vec2 corner = VERTEX.xy * 2.0 * reach;
	v_px = corner;
	vec2 at = (pix + corner) / VIEWPORT_SIZE * 2.0 - 1.0;
	POSITION = vec4(at * c.w, c.z, c.w);
}

void fragment() {
	vec2 q = floor(v_px + 0.5);
	vec2 a = abs(q);
	float r = max(a.x, a.y);
	bool straight = a.x < 0.5 || a.y < 0.5;
	bool diagonal = abs(a.x - a.y) < 0.5 && spokes > 4.5;
	float beat = floor(TIME * (4.0 + 8.0 * flicker));
	// Each spoke has its own length this beat: diagonals shorter than straights.
	float dir = straight ? (q.x > 0.5 ? 0.0 : (q.x < -0.5 ? 1.0 : (q.y > 0.5 ? 2.0 : 3.0))) : (q.x > 0.0 ? (q.y > 0.0 ? 4.0 : 5.0) : (q.y > 0.0 ? 6.0 : 7.0));
	float reach = diagonal ? outer * 0.65 : outer;
	reach -= floor(rays_hash(dir + beat * 0.37) * (1.0 + 2.5 * flicker));
	if (!(straight || diagonal) || r < inner || r > reach) {
		discard;
	}
	ALBEDO = color;
}
