extends TestCase
## Pools are a section's to lay (streamed worldgen S4g). A pool stands where its
## cell proposes it and no proposal that outranks it lies within reach, so a
## section with `GenWater.POOL_MARGIN` round its own tiles lays the same pools on
## them as the whole world does -- water, ground, and the pools it records.

const SIZE := 512
## A 512 world holds only a few pools (two to five), so six seeds between them.
const SEEDS: Array[int] = [1, 2, 3, 7, 42, 90210]
const CORE := 128


func test_a_section_lays_its_pools_as_the_whole_world_does() -> void:
	var pools := 0
	for s in SEEDS:
		GenWater.keeping = true
		var c := WorldGen.plan(s, SIZE)
		GenWater.keeping = false
		var b: Dictionary = GenWater.before_still
		GenWater.before_still = {}
		var specs := GenWater.pool_specs(c)
		var water: PackedByteArray = GenFields.snapshot(b.water)
		var ground := PackedByteArray()
		ground.resize(SIZE * SIZE)
		var whole := GenWater.pools_square(s, specs, b.level, b.land, water, b.country, b.blend, b.inland, SIZE, Vector2i.ZERO, SIZE,
			Rect2i(0, 0, SIZE, SIZE), ground)
		pools += whole.size()
		var bad := 0
		var m := GenWater.POOL_MARGIN
		var side := CORE + m * 2
		for gy in SIZE / CORE:
			for gx in SIZE / CORE:
				var o := Vector2i(gx * CORE - m, gy * CORE - m)
				var lv := PackedInt32Array()
				lv.resize(side * side)
				lv.fill(-1)
				var la := PackedByteArray()
				la.resize(side * side)
				var wa := PackedByteArray()
				wa.resize(side * side)
				var co := PackedByteArray()
				co.resize(side * side)
				var bl := PackedFloat32Array()
				bl.resize(side * side)
				var inl := PackedFloat32Array()
				inl.resize(side * side)
				for y in side:
					var wy := o.y + y
					if wy < 0 or wy >= SIZE:
						continue
					for x in side:
						var wx := o.x + x
						if wx < 0 or wx >= SIZE:
							continue
						var i := wy * SIZE + wx
						var k := y * side + x
						lv[k] = b.level[i]
						la[k] = b.land[i]
						wa[k] = b.water[i]
						co[k] = b.country[i]
						bl[k] = b.blend[i]
						inl[k] = b.inland[i]
				var gr := PackedByteArray()
				gr.resize(side * side)
				var core := Rect2i(gx * CORE, gy * CORE, CORE, CORE)
				GenWater.pools_square(s, specs, lv, la, wa, co, bl, inl, side, o, SIZE, core, gr)
				for y in CORE:
					for x in CORE:
						var i := (core.position.y + y) * SIZE + core.position.x + x
						var k := (m + y) * side + m + x
						if wa[k] != water[i] or gr[k] != ground[i]:
							bad += 1
		eq(bad, 0, "seed %d: every section lays its pools as the whole world does" % s)
	gt(float(pools), 15.0, "the seeds between them lay pools to judge (%d)" % pools)
