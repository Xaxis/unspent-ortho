// THE SALT CRUST'S PLATES, shared by what draws them (world.gdshader, SALT) and
// what grows along them (Decor, a species that `rims`), through its GDScript
// mirror src/core/biome/salt_crust.gd. The two are held to one another by
// tests/render/test_salt_crust.gd: change a number here and change it there.
// Include after ink.gdshaderinc (ink_hash).
//
// The crust dries in plates about half a tile across (SALT_FREQ cells a tile),
// a jittered Voronoi. Only some joins have lifted: decided per PAIR of plates,
// so a rim runs a few plates and stops. `join` is how far inside its own plate a
// point lies (0 on the join); a lifted join draws up to SALT_RIM_MIN + lifted x
// SALT_RIM_SPAN of it as the rim.

const float SALT_FREQ = 2.1;
const float SALT_LIFT = 0.62;
const float SALT_RIM_MIN = 0.03;
const float SALT_RIM_SPAN = 0.075;

// The plate `wp` lies in (own), its nearest neighbour (next), and how far the
// point is from the join between them (join). `jitter` wanders the joins.
void salt_cells(vec2 wp, float jitter, out vec2 own, out vec2 next, out float join) {
	vec2 q = wp * SALT_FREQ;
	vec2 gi = floor(q);
	float d1 = 9.0;
	float d2 = 9.0;
	own = vec2(0.0);
	next = vec2(0.0);
	for (int yy = -1; yy <= 1; yy++) {
		for (int xx = -1; xx <= 1; xx++) {
			vec2 g = gi + vec2(float(xx), float(yy));
			vec2 ctr = g + vec2(ink_hash(g + 1.7), ink_hash(g + 5.3)) * 0.8 + 0.1;
			float d = length(q - ctr) + jitter;
			if (d < d1) {
				d2 = d1;
				d1 = d;
				next = own;
				own = g;
			} else if (d < d2) {
				d2 = d;
				next = g;
			}
		}
	}
	join = d2 - d1;
}

// 0..1: how far this pair of plates' join has lifted; under SALT_LIFT it has.
float salt_lifted(vec2 own, vec2 next) {
	return ink_hash(min(own, next) * 3.1 + max(own, next) * 7.3);
}
