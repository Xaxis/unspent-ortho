extends TestCase
## A rectangle of the world scatters as the whole world did (streamed worldgen
## S4j3d). Every tile's scatter is its own hash and its own neighbourhood, so a
## rectangle laid from a window one tile wider -- its fields cut from the world,
## its two noise fields made for it alone -- finds on its tiles exactly what the
## whole world found there, in the same order. Rectangles are odd-sized and off
## any grid, so every edge case of the window is met.

const SIZE := 512
const SEEDS: Array[int] = [1, 90210]
const SIDE := 97


func test_a_rectangle_scatters_as_the_whole_world_did() -> void:
	for s in SEEDS:
		GenScatter.keeping = true
		var c := WorldGen.plan(s, SIZE)
		GenSurface.run(c)
		WorldGen.finish(c)
		GenScatter.keeping = false
		var kept := GenScatter.kept
		GenScatter.kept = {}
		var whole: PackedFloat32Array = kept.found
		gt(float(whole.size() / 4), 5000.0, "seed %d: things to scatter" % s)
		# The world's finds, by tile.
		var by_tile := {}
		for j in range(0, whole.size(), 4):
			var key := Vector2i(floori(whole[j + 1]), floori(whole[j + 2]))
			var at: Array = by_tile.get(key, [])
			at.append([whole[j], whole[j + 1], whole[j + 2], whole[j + 3]])
			by_tile[key] = at
		var bad := 0
		var seen := 0
		var y := -11
		while y < SIZE:
			var x := -11
			while x < SIZE:
				var core := Rect2i(x, y, SIDE, SIDE).intersection(Rect2i(0, 0, SIZE, SIZE))
				var got := GenScatter.scatter_rect(c, kept.occ, core)
				var want: Array = []
				for ty in range(core.position.y, core.end.y):
					for tx in range(core.position.x, core.end.x):
						want.append_array(by_tile.get(Vector2i(tx, ty), []))
				var have: Array = []
				for j in range(0, got.size(), 4):
					have.append([got[j], got[j + 1], got[j + 2], got[j + 3]])
				seen += have.size()
				if var_to_str(have) != var_to_str(want):
					bad += 1
				x += SIDE
			y += SIDE
		eq(seen, whole.size() / 4, "seed %d: the rectangles found as many things as the world" % s)
		eq(bad, 0, "seed %d: every rectangle scatters as the whole world did (rectangles differing)" % s)
