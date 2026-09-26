extends TestCase
## Works as rows (slice S4b): a landscape's works are sited in order, and each
## is composed from its row alone -- a stream keyed on the work and its tile,
## the occupancy the works stage began from, and its own pieces. So a section
## of a streamed world can lay a work it was handed without laying any other.
##
## `GenWorks.witnessing` makes generation compose every standing work twice:
## once in the world, and once alone on a fresh Lay holding nothing but the
## stage's first occupancy. The two must lay the same pieces.

const SIZE := 512
const SEEDS: Array[int] = [7, 42]


func test_every_work_composed_alone_lays_what_the_world_holds() -> void:
	for s in SEEDS:
		GenWorks.witness.clear()
		GenWorks.witnessing = true
		WorldGen.generate(s, SIZE)
		GenWorks.witnessing = false
		var rows: Array = GenWorks.witness.duplicate()
		GenWorks.witness.clear()
		gt(rows.size(), 20, "seed %d: works composed as rows" % s)
		var kinds := {}
		var bad := 0
		for row: Dictionary in rows:
			kinds[row.work] = true
			var here: Array = row.world
			var alone: Array = row.alone
			if not _same(here, alone):
				bad += 1
				if bad <= 5:
					check(false, "seed %d: %s at %s in %s lays %d pieces in the world and %d alone%s" % [
						s, row.work, row.at, row.land, here.size(), alone.size(), _first_difference(here, alone)])
		eq(bad, 0, "seed %d: works whose pieces hang on something beside their row" % s)
		for work: StringName in [&"_turf_rows", &"_drained", &"_clearcut", &"_quarry", &"_slag", &"_block", &"_pans", &"_breaking_yard"]:
			check(kinds.has(work), "seed %d: some %s was composed" % [s, work])


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if _differs(a[i], b[i]):
			return false
	return true


static func _differs(x: Array, y: Array) -> bool:
	return int(x[0]) != int(y[0]) or (x[1] as Vector2).distance_to(y[1] as Vector2) > 1e-3 \
		or absf(float(x[2]) - float(y[2])) > 1e-3 or absf(float(x[3]) - float(y[3])) > 1e-3


static func _first_difference(a: Array, b: Array) -> String:
	for i in mini(a.size(), b.size()):
		if _differs(a[i], b[i]):
			return "; piece %d: %s vs %s" % [i, a[i], b[i]]
	return ""
