// THE FAR WORLD STANDS DOWN WHERE A NEAR CHUNK IS DRAWN (world_far.gd). One
// texel per chunk, 1 where that chunk is in the scene; only the far world's own
// copy of a material sets `near_cut`, so a near chunk never samples it. The
// coarse land can then carry its true height -- a ridge forty tiles off stands as
// high as it is -- without ever drawing through the detailed land it lies under,
// and a chunk not built yet is not a hole: the far land is still there.
//
// One file for every material the far world draws with (land, water, and what
// stands on the land: made, found and leaves), because four copies of one rule
// are four chances for the far city to draw through the near one.
uniform sampler2D near_mask : filter_nearest, repeat_disable;
uniform float near_cut = 0.0;
uniform float near_cell = 32.0;

bool near_drawn(vec3 wp) {
	ivec2 n = textureSize(near_mask, 0);
	ivec2 c = ivec2(floor(wp.xz / near_cell));
	if (c.x < 0 || c.y < 0 || c.x >= n.x || c.y >= n.y) {
		return false;
	}
	return texelFetch(near_mask, c, 0).r > 0.5;
}
