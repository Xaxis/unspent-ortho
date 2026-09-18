extends TestCase
## `line_coil` is cut out of a lineman, and for a while nothing could get one.
##
## Every other test of the economy walks TABLES: this roster row names that
## landscape, so the material is reachable. None of them asked the question a
## player asks — **stand in the best place on the island at the right hour and
## does the machine come?** It is a different question because `Spawner.roll`
## puts a body on a tile in the square ring `RING_MIN..RING_MAX`, and only after
## `place_fits` has passed on THAT tile, so what decides whether a kind can be met
## is not how much of the island suits it but how much suits it AT ONCE.
##
## The lineman failed that and nothing noticed. `near_props` (a pylon or pole
## within 4) is a narrow gate on its own — 188 tiles on seed 1 — and `green_min`
## 34 on top of it left SIX, of which the best spawn ring covered six, and forty
## minutes of standing there rolled nothing. A hunter would have survived that,
## because a hunted network SENDS one past `place_fits` entirely
## (`32_disposition._spot_for`); a lineman is a WORKER and has no second path.
##
## So this is the last mile of "obtainable" for the one kind that has only the
## one door, and it is held on three seeds because a single seed's island is not
## evidence about worldgen.
const SIZE := 256
## Rolls come every 200 ms of play, so this is about forty minutes of standing
## still in the best place on the island — long past the point where a player
## would have concluded the machine does not exist.
const ROLLS := 12000
const SEEDS: Array[int] = [1, 4, 7]
## The lineman declares no `hours`, so one hour answers for all of them.
const HOUR := 12.0


## Tiles the spawner would take `kind` on, as a flat 0/1 grid.
static func _marks(kind: StringName, w: WorldData, q: WorldQuery) -> PackedInt32Array:
	var row := Roster.row(kind)
	var g := PackedInt32Array()
	g.resize(SIZE * SIZE)
	for ty: int in SIZE:
		for tx: int in SIZE:
			if Spawner.place_fits(row, w, q, tx, ty, kind, HOUR):
				g[ty * SIZE + tx] = 1
	return g


## Inclusive prefix sums with a row and column of padding, so a box is four reads.
static func _sums(g: PackedInt32Array) -> PackedInt32Array:
	var s := PackedInt32Array()
	s.resize((SIZE + 1) * (SIZE + 1))
	for y: int in SIZE:
		var acc := 0
		for x: int in SIZE:
			acc += g[y * SIZE + x]
			s[(y + 1) * (SIZE + 1) + x + 1] = s[y * (SIZE + 1) + x + 1] + acc
	return s


static func _box(s: PackedInt32Array, x0: int, y0: int, x1: int, y1: int) -> int:
	x0 = clampi(x0, 0, SIZE)
	y0 = clampi(y0, 0, SIZE)
	x1 = clampi(x1 + 1, 0, SIZE)
	y1 = clampi(y1 + 1, 0, SIZE)
	if x1 <= x0 or y1 <= y0:
		return 0
	var w := SIZE + 1
	return s[y1 * w + x1] - s[y0 * w + x1] - s[y1 * w + x0] + s[y0 * w + x0]


## How many marked tiles the spawn ring around (x, y) covers.
static func _in_ring(s: PackedInt32Array, x: int, y: int) -> int:
	var out := Spawner.RING_MAX
	var inn := Spawner.RING_MIN - 1
	return _box(s, x - out, y - out, x + out, y + out) - _box(s, x - inn, y - inn, x + inn, y + inn)


func test_the_lineman_the_coil_is_cut_out_of_is_really_rolled() -> void:
	GearEconomy.declare(true)
	Sources.clear()
	var kind := EliteStock.kind_of(&"line_coil")
	eq(kind, &"lineman", "the coil is the lineman's, and this test is about that gate")
	var spawner := Spawner.new()
	var m := Moment.new()
	var total := 0
	for seed_value: int in SEEDS:
		var w := WorldGen.generate(seed_value, SIZE)
		var q := WorldQuery.new(w)
		m.seed_value = w.seed_value
		var g := _marks(kind, w, q)
		var marked := 0
		for v: int in g:
			marked += v
		var s := _sums(g)
		# Stand where the spawn ring covers most of them: the best case, because a
		# gate the best case cannot satisfy is not a gate, it is a wall.
		var stood := Vector2.INF
		var cover := 0
		for y: int in range(0, SIZE, 2):
			for x: int in range(0, SIZE, 2):
				if Ground.is_water(w.ground_at(x, y)) or not q.standable(x, y):
					continue
				var n := _in_ring(s, x, y)
				if n > cover:
					cover = n
					stood = Vector2(x + 0.5, y + 0.5)
		check(stood != Vector2.INF,
			"seed %d: nowhere on the island to stand whose spawn ring covers a lineman tile"
			% seed_value)
		if stood == Vector2.INF:
			continue
		# Late enough that every kind's `day_min` is met and the hunters' share is up,
		# so the lineman is competing against the whole roster and not a quiet one.
		m.minutes = 24.0 * 60.0 * 6.0 + HOUR * 60.0
		var got := 0
		for i in ROLLS:
			if StringName(spawner.roll(i, w, q, m, stood, 0).get("kind", &"")) == kind:
				got += 1
		total += got
		print("  seed %d: %d tiles island-wide, best ring covers %d, %d of %d rolls put one out"
			% [seed_value, marked, cover, got, ROLLS])
		gt(float(got), 0.0,
			"seed %d: standing at the best place on the island rolled no lineman in %d rolls, so line_coil has no door"
			% [seed_value, ROLLS])
	# Per seed the bar is only "at all", which one island can pass by luck: at
	# `green_min` 34 seeds 4 and 7 still rolled 3 and 4, and three in forty minutes
	# of standing in the single best place is not a door either. The three islands
	# together are the honest bar — 7 at 34, 25 at 10 — and a sum survives one
	# seed's island moving under a worldgen change, which a tight per-seed bar
	# would not.
	print("  three islands together: %d of %d rolls (it was 7 when green_min was 34)"
		% [total, ROLLS * SEEDS.size()])
	gt(float(total), 12.0,
		"a lineman is rolled %d times across three islands' best standing places; it is gated too hard to be met"
		% total)
