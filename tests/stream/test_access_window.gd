extends TestCase
## The access pass is a section's to run (streamed worldgen S4e3). The plan
## joins the BIG plateaus (`GenAccess.plan_links`); a square with
## `GenAccess.ACCESS_REACH` + 2 tiles of the world round its core joins its
## small plateaus exactly as the whole world does, level and ramp.

const SIZE := 512
const SEEDS: Array[int] = [1, 42, 90210]
const CORE := 64
const CORNERS: Array[Vector2i] = [Vector2i(130, 130), Vector2i(224, 160), Vector2i(318, 318), Vector2i(160, 300), Vector2i(290, 200)]


func test_a_section_cuts_its_own_breaches_as_the_whole_world_does() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var level := _walled(w)
		var water := PackedByteArray()
		water.resize(level.size())
		for i in level.size():
			water[i] = 1 if Ground.is_water(w.ground[i]) else 0
		var village := PackedByteArray()
		village.resize(level.size())
		var plan := GenAccess.plan_links(level, water, village, SIZE)
		var whole_l: PackedInt32Array = GenFields.snapshot(level)
		var whole_r := PackedByteArray()
		whole_r.resize(level.size())
		GenAccess.access(whole_l, water, village, whole_r, SIZE, plan, Vector2i.ZERO, SIZE)
		var cuts := 0
		for i in whole_r.size():
			cuts += whole_r[i]
		gt(cuts, 20, "seed %d: breaches were cut (%d ramp tiles)" % [s, cuts])
		for at in CORNERS:
			var bad := _window_differs(level, water, village, plan, whole_l, whole_r, at, GenAccess.ACCESS_REACH + 2)
			eq(bad, 0, "seed %d: window at %s differs from the whole world on its core" % [s, at])


## TWO BIG PLATEAUS AND A CLIFF BETWEEN THEM. Joined to the small ones round
## them, each is one place a section has already reached, so only the plan can
## see that they are not joined to each other: without its breach the far one
## is walled off.
func test_the_plan_breaches_between_big_plateaus() -> void:
	for wall: bool in [false, true]:
		var size := 300
		var level := _two_plateaus(size, wall)
		var water := PackedByteArray()
		water.resize(level.size())
		var village := PackedByteArray()
		village.resize(level.size())
		var plan := GenAccess.plan_links(level, water, village, size)
		gt(float(plan.size()), 0.0, "the plan breaches between the plateaus (wall %s)" % wall)
		var with_plan: PackedInt32Array = GenFields.snapshot(level)
		var ramp := PackedByteArray()
		ramp.resize(level.size())
		GenAccess.access(with_plan, water, village, ramp, size, plan, Vector2i.ZERO, size)
		check(_walks(with_plan, size, Vector2i(40, 150), Vector2i(260, 150)), "with the plan, one plateau walks to the other (wall %s)" % wall)
		var without: PackedInt32Array = GenFields.snapshot(level)
		ramp.fill(0)
		var none: Array[Vector3i] = []
		GenAccess.access(without, water, village, ramp, size, none, Vector2i.ZERO, size)
		check(not _walks(without, size, Vector2i(40, 150), Vector2i(260, 150)), "without it, they stay apart (wall %s)" % wall)


## A square of `size`: sea round the edge, a big plateau at level 1 on the west,
## one at level 4 on the east, touching at x = 150 -- or, with `wall`, both at
## level 1 with a ridge 8 tiles thick at level 4 between them (a ridge must be
## as thick as its drop for a breach to be cut into it at all).
static func _two_plateaus(size: int, wall: bool) -> PackedInt32Array:
	var level := PackedInt32Array()
	level.resize(size * size)
	for y in size:
		for x in size:
			var l := -1
			if x >= 10 and x < size - 10 and y >= 10 and y < size - 10:
				if wall:
					l = 4 if x >= 146 and x < 154 else 1
				else:
					l = 1 if x < 150 else 4
			level[y * size + x] = l
	return level


## Walks from a to b stepping at most one level, off deep water.
static func _walks(level: PackedInt32Array, size: int, a: Vector2i, b: Vector2i) -> bool:
	var seen := PackedByteArray()
	seen.resize(level.size())
	var stack := PackedInt32Array([a.y * size + a.x])
	seen[stack[0]] = 1
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if i == b.y * size + b.x:
			return true
		for d: int in [1, -1, size, -size]:
			var j := i + d
			if j < 0 or j >= level.size() or seen[j] != 0 or level[j] < 0 or absi(level[j] - level[i]) > 1:
				continue
			seen[j] = 1
			stack.append(j)
	return false


static func _window_differs(level: PackedInt32Array, water: PackedByteArray, village: PackedByteArray, plan: Array[Vector3i],
		whole_l: PackedInt32Array, whole_r: PackedByteArray, at: Vector2i, margin: int) -> int:
	var side := CORE + margin * 2
	var o := at - Vector2i(margin, margin)
	var l := PackedInt32Array()
	var wa := PackedByteArray()
	var vi := PackedByteArray()
	var r := PackedByteArray()
	l.resize(side * side)
	wa.resize(side * side)
	vi.resize(side * side)
	r.resize(side * side)
	for y in side:
		for x in side:
			var j := (o.y + y) * SIZE + o.x + x
			l[y * side + x] = level[j]
			wa[y * side + x] = water[j]
			vi[y * side + x] = village[j]
	# The plan's breaches, in the window's tiles (-1 outside it).
	var mine: Array[Vector3i] = []
	for e in plan:
		mine.append(Vector3i(_into(e.x, o, side), _into(e.y, o, side), e.z))
	GenAccess.access(l, wa, vi, r, side, mine, o, SIZE)
	var bad := 0
	for y in CORE:
		for x in CORE:
			var k := (margin + y) * side + margin + x
			var j := (at.y + y) * SIZE + at.x + x
			if l[k] != whole_l[j] or r[k] != whole_r[j]:
				bad += 1
	return bad


static func _into(i: int, o: Vector2i, side: int) -> int:
	var x := i % SIZE - o.x
	var y := i / SIZE - o.y
	return y * side + x if x >= 0 and y >= 0 and x < side and y < side else -1


## The world's levels with walled plateaus planted on its land: boxes raised two
## to four levels, 6 to 40 tiles a side, so the pass has cliffs to breach.
static func _walled(w: WorldData) -> PackedInt32Array:
	var level: PackedInt32Array = GenFields.snapshot(w.level)
	var s := w.seed_value
	for k in 160:
		var x0 := 4 + floori(Rng.hash01(s, k, 0xACC1) * (SIZE - 48))
		var y0 := 4 + floori(Rng.hash01(s, k, 0xACC2) * (SIZE - 48))
		var bw := 6 + floori(Rng.hash01(s, k, 0xACC3) * 34)
		var bh := 6 + floori(Rng.hash01(s, k, 0xACC4) * 34)
		var up := 2 + floori(Rng.hash01(s, k, 0xACC5) * 3)
		for y in range(y0, y0 + bh):
			for x in range(x0, x0 + bw):
				var i := y * SIZE + x
				if level[i] > 0:
					level[i] += up
	return level
