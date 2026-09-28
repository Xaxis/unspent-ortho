extends TestCase
## Settling is the plan's rows and a section's stamping (streamed worldgen S4h).
## Which villages stand where, at what level, and where every road runs and how
## high each of its tiles lies are the plan's to decide (`GenSettle.rows`). Given
## them, a section with `GenSettle.ROAD_POOL_MARGIN` of the world round its own
## tiles lays them as the whole world did: villages levelled in id order and
## their pools drained, road tiles laid, crossed pools drained.
##
## It bites where it matters most: laid in reverse, the villages' aprons meet
## and thirteen tiles of seed 42's differ. The pool margin it cannot show red
## on these worlds -- no crossed pool's box straddles a section's edge -- so it
## is held as the bound a pool's box gives.

const SIZE := 512
const SEEDS: Array[int] = [1, 42, 90210]
const CORE := 128


func test_a_section_settles_from_the_plan_s_rows_as_the_whole_world_does() -> void:
	for s in SEEDS:
		GenSettle.keeping = true
		WorldGen.plan(s, SIZE)
		GenSettle.keeping = false
		var b: Dictionary = GenSettle.before
		var a: Dictionary = GenSettle.after
		var rows: Dictionary = GenSettle.rows
		GenSettle.before = {}
		GenSettle.after = {}
		GenSettle.rows = {}
		gt(float((rows.villages as Array).size()), 5.0, "seed %d: villages to lay" % s)
		gt(float((rows.road_tiles as PackedInt32Array).size()), 200.0, "seed %d: roads to lay" % s)
		var m := GenSettle.ROAD_POOL_MARGIN
		var side := CORE + m * 2
		var bad := {}
		for gy in SIZE / CORE:
			for gx in SIZE / CORE:
				var o := Vector2i(gx * CORE - m, gy * CORE - m)
				var lv := _cut_i(b.level, o, side, -1)
				var el := _cut_f(b.elev, o, side)
				var la := _cut_b(b.land, o, side)
				var wa := _cut_b(b.water, o, side)
				var vi := PackedByteArray()
				vi.resize(side * side)
				var ro := PackedByteArray()
				ro.resize(side * side)
				GenSettle.settle_square(s, rows, b.pools, lv, el, la, wa, vi, ro, side, o, SIZE)
				for y in CORE:
					for x in CORE:
						var i := (gy * CORE + y) * SIZE + gx * CORE + x
						var k := (m + y) * side + m + x
						for field: Array in [["level", lv[k], a.level[i]], ["elev", el[k], a.elev[i]], ["land", la[k], a.land[i]],
								["water", wa[k], a.water[i]], ["village", vi[k], a.village[i]], ["road", ro[k], a.road[i]]]:
							if field[1] != field[2]:
								bad[field[0]] = int(bad.get(field[0], 0)) + 1
		eq(bad, {}, "seed %d: every section settles as the whole world did (tiles differing, by field)" % s)


static func _cut_i(a: PackedInt32Array, o: Vector2i, side: int, outside: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(side * side)
	out.fill(outside)
	for y in side:
		for x in side:
			var wx := o.x + x
			var wy := o.y + y
			if wx >= 0 and wy >= 0 and wx < SIZE and wy < SIZE:
				out[y * side + x] = a[wy * SIZE + wx]
	return out


static func _cut_f(a: PackedFloat32Array, o: Vector2i, side: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(side * side)
	for y in side:
		for x in side:
			var wx := o.x + x
			var wy := o.y + y
			if wx >= 0 and wy >= 0 and wx < SIZE and wy < SIZE:
				out[y * side + x] = a[wy * SIZE + wx]
	return out


static func _cut_b(a: PackedByteArray, o: Vector2i, side: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(side * side)
	for y in side:
		for x in side:
			var wx := o.x + x
			var wy := o.y + y
			if wx >= 0 and wy >= 0 and wx < SIZE and wy < SIZE:
				out[y * side + x] = a[wy * SIZE + wx]
	return out
