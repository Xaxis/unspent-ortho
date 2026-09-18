class_name GenBodies
## The bodies a world is made of, and the void between them (`docs/WORLD.md`).
##
## THE RECORDING HALF LANDS FIRST, ON PURPOSE. The finished stage runs BEFORE
## `GenShape` and hands each body a footprint, a land budget, a climate band and a
## set of landscape types; `GenShape` and everything after it then run per body.
## That inversion moves every seed's island and re-accepts every baseline, so it
## is worth landing behind a step that moves nothing: this reads the shape that
## already exists and writes down which body each tile is on. Today that is one
## body, because `GenShape` makes one island and sinks anything detached
## (`ISLET_TILES`) — so the answer is true, complete, and identical to the world
## that was there before it.
##
## It is here rather than derived at the point of use because `WorldData.continent`
## has one writer and this is it. A reader that worked a continent out from the
## ocean mask would be right until the first continent that is not where its
## latitude suggests, which is exactly the shape of bug `WorldData.road` was added
## to end.

## Body ids start at 1; 0 is the void.
const VOID := 0


static func run(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var n := size * size
	var body := PackedByteArray()
	body.resize(n)
	# Every run of land that touches is one body. One island gives one body; the
	# loop is written for the many because that is what it becomes.
	var sizes := PackedInt32Array()
	var label := GenFields.components(c.land, size, sizes)
	var rank: Array[Dictionary] = []
	for i in n:
		if sizes[i] > 0:
			rank.append({"label": i, "tiles": sizes[i]})
	rank.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.tiles) > int(b.tiles))
	var id_of := {}
	for r in rank.size():
		id_of[int(rank[r].label)] = mini(r + 1, 255)
	var sum_x := {}
	var sum_y := {}
	var box := {}
	for i in n:
		var lab := label[i]
		if lab < 0:
			continue
		var got: Variant = id_of.get(lab)
		if got == null:
			continue
		var id := int(got)
		body[i] = id
		var x := i % size
		var y := i / size
		sum_x[id] = float(sum_x.get(id, 0.0)) + float(x)
		sum_y[id] = float(sum_y.get(id, 0.0)) + float(y)
		var b: Array = box.get(id, [size, size, -1, -1])
		b[0] = mini(int(b[0]), x)
		b[1] = mini(int(b[1]), y)
		b[2] = maxi(int(b[2]), x)
		b[3] = maxi(int(b[3]), y)
		box[id] = b
	w.continent = body
	var out: Array[Dictionary] = []
	for r in rank.size():
		var id := mini(r + 1, 255)
		if not box.has(id):
			continue
		var tiles := int(rank[r].tiles)
		var b: Array = box[id]
		out.append({
			"id": id, "tiles": tiles,
			"centre": Vector2(float(sum_x[id]) / tiles, float(sum_y[id]) / tiles),
			"bounds": Rect2(int(b[0]), int(b[1]), int(b[2]) - int(b[0]) + 1, int(b[3]) - int(b[1]) + 1),
		})
	w.continents = out


# --- The planning half (docs/WORLD.md) -----------------------------------------
# Pure, cheap, and deliberately not wired into generation yet: `plan` decides how
# many bodies a world has, how big the square must be to hold them, where each
# one sits and what climate band it was dealt, WITHOUT making a world. Anyone may
# ask for it — which is the whole reason it is separate. The underground needs the
# SURFACE's footprints (a shaft must come up where it went down) and asking for a
# world to get them would turn the one frame a shaft costs on the no-threads web
# path into two world generations, with both resident.

## The design world every body is sized against. A continent should hold about
## what today's island holds, or its landscapes stop being legible and its regions
## stop qualifying as places, so the SQUARE grows with the body count rather than
## the bodies shrinking into a fixed one.
const BASE_SIZE := 512
## How many bodies each realm has, as (least, most). The surface is continents in
## an ocean; the underground follows the surface because it inherits its
## footprints; orbital is many small bodies in vacuum.
const COUNT := {
	&"surface": Vector2i(2, 4),
	&"underground": Vector2i(2, 4),
	&"orbital": Vector2i(3, 8),
	&"era": Vector2i(1, 2),
}
## An orbital body is a captured asteroid, not a continent: it takes this share of
## the land a continent would.
const ORBITAL_SHARE := 0.32
## How far apart body centres are kept, as a share of the square. Below this the
## ocean between them stops reading as an ocean.
const APART := 0.28
## The spread of the climate band a body is dealt, in the 0..1 units
## `BiomeDef.temp_range` and `moist_range` are written in. Two continents at one
## latitude are otherwise the same place.
const BAND := 0.22


## What a world of `realm` is made of, without making one.
##
## `want_size` is what `--size=` becomes: a CEILING, honoured by dropping bodies
## until each remaining one still holds a legible continent, with a floor of one.
## That is what keeps every small world in the tests and tours meaning what it
## meant — one body is exactly the island this game has always had.
##
## Returns {size: int, bodies: Array[Dictionary]}, each body
## {id, at: Vector2 (0..1 of the square), share: float, band: Vector2 (temp, moist), home: bool}.
static func plan(seed_value: int, realm: StringName = &"surface", want_size: int = 0) -> Dictionary:
	var range_of: Vector2i = COUNT.get(realm, Vector2i(1, 1))
	# The underground is the surface's map with its own type sets: ask for the
	# surface's plan rather than making a second, unrelated one. The rule lives
	# HERE so no caller has to know the underground is special.
	if realm == Realm.UNDERGROUND:
		var above := plan(seed_value, Realm.SURFACE, want_size)
		return {"size": above.size, "bodies": above.bodies}
	var rng := Rng.make(seed_value, 0xB0D1E5)
	var count := range_of.x + (rng.randi() % maxi(1, range_of.y - range_of.x + 1))
	var small: float = ORBITAL_SHARE if realm == Realm.ORBITAL else 1.0
	# The square that holds `count` bodies of the design world's size.
	var size := roundi(BASE_SIZE * sqrt(float(count) * small))
	if want_size > 0:
		# Drop bodies until they fit what was asked for, never below one.
		while count > 1 and roundi(BASE_SIZE * sqrt(float(count) * small)) > want_size:
			count -= 1
		size = maxi(want_size, 64)
	var bodies: Array[Dictionary] = []
	var placed: Array[Vector2] = []
	for i in count:
		var at := _spot(rng, placed, count)
		placed.append(at)
		bodies.append({
			"id": i + 1,
			"at": at,
			"share": small / float(count),
			# Latitude is the WORLD's: a body laid north is a cold body before a
			# landscape is chosen. The band is what it was DEALT, and it is what
			# stops two bodies at one latitude being the same place.
			"band": Vector2((rng.randf() - 0.5) * 2.0 * BAND, (rng.randf() - 0.5) * 2.0 * BAND),
			"home": false,
		})
	# The player wakes on one of them, and it is the one nearest the south — the
	# journey has run south to north since M1 (docs/WORLD.md §8).
	var home := 0
	for i in bodies.size():
		if float((bodies[i].at as Vector2).y) > float((bodies[home].at as Vector2).y):
			home = i
	bodies[home]["home"] = true
	return {"size": size, "bodies": bodies}


## A centre at least APART from the ones already placed, given a few tries.
static func _spot(rng: RandomNumberGenerator, placed: Array[Vector2], count: int) -> Vector2:
	var want := APART / maxf(1.0, sqrt(float(count)) * 0.7)
	var best := Vector2(0.5, 0.5)
	var best_gap := -1.0
	for _try in 24:
		var p := Vector2(rng.randf_range(0.22, 0.78), rng.randf_range(0.22, 0.78))
		var gap := 9.0
		for q: Vector2 in placed:
			gap = minf(gap, p.distance_to(q))
		if placed.is_empty():
			return p
		if gap > best_gap:
			best_gap = gap
			best = p
		if gap >= want:
			return p
	return best
