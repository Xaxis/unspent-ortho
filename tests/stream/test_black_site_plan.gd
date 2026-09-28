extends TestCase
## The black site stands in the sea the PLAN decided (streamed worldgen S4j3e):
## water at or under the sea's level joined to the map's edge, not the surface's
## water grounds. A streamed world must know where the sea is before it lays the
## whole surface; this holds the site that answer picks to the one the surface's
## own water picks, on every seed here.

const SEEDS: Array[int] = [1, 7, 42, 90210]


func test_the_plan_s_sea_picks_the_site_the_surface_s_water_picks() -> void:
	var found := 0
	for s in SEEDS:
		var w := WorldGen.generate(s, 512)
		var by_plan := BlackSite.site(w)
		var by_ground := _site_by(w, _ground_sea(w))
		eq(by_plan, by_ground, "seed %d: the same site from the plan's sea as from the surface's water" % s)
		if by_plan != Vector2.INF:
			found += 1
	gt(float(found), 2.0, "the seeds hold a site to compare")


## `BlackSite._look` with `sea` for its sea.
static func _site_by(w: WorldData, sea: PackedByteArray) -> Vector2:
	var best := Vector2.INF
	var best_out := INF
	var n := ceili(BlackSite.FURTHEST)
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var x := floori(w.spawn.x) + dx
			var y := floori(w.spawn.y) + dy
			if not w.in_bounds(x, y):
				continue
			var at := Vector2(x + 0.5, y + 0.5)
			var out := at.distance_to(w.spawn)
			if out < BlackSite.NEAREST or out > BlackSite.FURTHEST or out >= best_out:
				continue
			if sea[y * w.size + x] == 0 or w.ground_at(x, y) != Ground.DEEP_WATER or not BlackSite._moated(w, x, y):
				continue
			best_out = out
			best = at
	return best


## The surface's water joined to the map's edge.
static func _ground_sea(w: WorldData) -> PackedByteArray:
	var size := w.size
	var seen := PackedByteArray()
	seen.resize(size * size)
	var edge := PackedInt32Array()
	for i in size:
		for k: int in [i, (size - 1) * size + i, i * size, i * size + size - 1]:
			if seen[k] == 0 and Ground.is_water(w.ground[k]):
				seen[k] = 1
				edge.append(k)
	while not edge.is_empty():
		var k := edge[edge.size() - 1]
		edge.remove_at(edge.size() - 1)
		var x := k % size
		var y := k / size
		for nb: int in [k - 1 if x > 0 else -1, k + 1 if x < size - 1 else -1, k - size if y > 0 else -1, k + size if y < size - 1 else -1]:
			if nb >= 0 and seen[nb] == 0 and Ground.is_water(w.ground[nb]):
				seen[nb] = 1
				edge.append(nb)
	return seen
