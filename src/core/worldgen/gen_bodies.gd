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
	# FIVE AT LEAST, and the owner asked for that by name (2026-09-18): a home
	# continent, two in the middle of the journey, one late and one remote, which
	# is the structure `StoryPlan.SPINE` has assumed for weeks with its `leg` per
	# slot while this stage laid at most four.
	&"surface": Vector2i(5, 7),
	&"underground": Vector2i(5, 7),
	&"orbital": Vector2i(3, 8),
	&"era": Vector2i(1, 2),
}
## An orbital body is a captured asteroid, not a continent: it takes this share of
## the land a continent would.
const ORBITAL_SHARE := 0.32
## The radius of the ONE island this game has always had, as a share of the
## square: `GenShape` draws it at 0.34-0.38 by 0.38-0.41, so about this.
const ONE_RADIUS := 0.375
## Clear water between two bodies, and clear water between a body and the frame,
## as shares of the square. The second exists because `GenShape` drowns land that
## runs into the frame, so a body laid across the edge is a body cut in half.
const SEA_GAP := 0.06
const FRAME := 0.05
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
## The square that makes each of `count` bodies a whole island. One body is
## BASE_SIZE exactly; the packing below says what share of the square a body of a
## ring of `count` actually gets, and the square grows by the inverse of it.
static func _square_for(count: int, small: float) -> int:
	return roundi(float(BASE_SIZE) / sqrt(maxf(_share_for(count, small), 0.0001)))


## What share of a one-body world's land each of `count` bodies gets, from the
## ring packing. The one place that answers it, so the square and the bodies can
## never disagree about how big a continent is.
static func _share_for(count: int, small: float) -> float:
	var r := ONE_RADIUS
	if count > 1:
		var sn := sin(PI / float(count))
		r = maxf((sn * (1.0 - 2.0 * FRAME) - SEA_GAP) / (2.0 * (1.0 + sn)), 0.06)
	return small * pow(r / ONE_RADIUS, 2.0)


static func plan(seed_value: int, realm: StringName = &"surface", want_size: int = 0) -> Dictionary:
	var range_of: Vector2i = COUNT.get(realm, Vector2i(1, 1))
	# A realm may lie UNDER another one, or BE it at another time: either way it is
	# the same map and it says so with `Realm.DEFS[...].footprints_of`. Ask for that
	# realm's plan rather than making a second, unrelated one. The rule lives HERE
	# so no caller has to know which realms share a map (docs/WORLD.md §5).
	var shares: StringName = Realm.def(realm).get("footprints_of", &"")
	if shares != &"" and shares != realm:
		var other := plan(seed_value, shares, want_size)
		return {"size": other.size, "bodies": other.bodies}
	var rng := Rng.make(seed_value, 0xB0D1E5)
	var count := range_of.x + (rng.randi() % maxi(1, range_of.y - range_of.x + 1))
	var small: float = ORBITAL_SHARE if realm == Realm.ORBITAL else 1.0
	# THE SQUARE'S WIDTH DECIDES HOW MANY CONTINENTS FIT IN IT, because a continent
	# is a whole island and not a share of one (see `share_each` below). Asked for
	# a size, drop the count until they fit at that size rather than shrinking them
	# to suit — never below the least this realm is allowed, because "at least five"
	# is the shape of the journey (`StoryPlan.SPINE` walks them in order) and not a
	# budget. A world too small for its own least count gets small continents, and
	# that is the honest failure: it says the square is too small.
	if want_size > 0:
		while count > range_of.x and _square_for(count, small) > want_size:
			count -= 1
	# HOW BIG A BODY CAN BE IS A PACKING PROBLEM, NOT A DIVISION. The first version
	# of this gave each body 1/count of the land and scattered the centres, and at
	# 1024 the four "continents" came out as ONE mass of half a million tiles with
	# a litter of islets round it. Two reasons, and both matter: the centres were
	# closer than the bodies were wide, and `GenShape` normalises the land to a
	# fixed share whatever shapes it is given, so it simply filled the gaps in.
	#
	# So the radius is solved for instead. Bodies sit on a ring of radius R, and
	# two constraints have to hold at once: a body must not touch the frame
	# (R = 0.5 - r - FRAME) and two neighbours must not touch each other
	# (2 R sin(pi/n) >= 2r + SEA_GAP). Solving the pair gives
	#
	#     r = (sin(pi/n) (1 - 2 FRAME) - SEA_GAP) / (2 (1 + sin(pi/n)))
	#
	# and the share each body takes of the land follows from its area, so the
	# TOTAL land of a world falls out of the packing rather than being decreed.
	# A world of continents therefore has less land than a world of one island,
	# which is right: the ocean has to come from somewhere.
	# `_share_for` is the one place that solves it, so the square below and the
	# bodies laid here can never disagree about how big a continent is — which is
	# exactly what went wrong when the square was sized by one formula and the
	# bodies by another.
	var share_each := _share_for(count, small)
	var r := ONE_RADIUS * sqrt(share_each / maxf(small, 0.0001))
	var ring := 0.0
	if count > 1:
		ring = 0.5 - r - FRAME
	# A CONTINENT IS A WHOLE ISLAND, SO THE SQUARE GROWS TO HOLD THEM ALL.
	#
	# The old sizing was `BASE_SIZE * sqrt(count)`, which is the square that would
	# hold `count` bodies IF each took a body's full share of it. The ring packing
	# does not give them that: five bodies solve to r = 0.148 against ONE_RADIUS
	# 0.375, so each was 15% of an island's area and a "continent" came out a
	# tenth the size of the one island this game started with. The square was
	# sized for the world we meant and the bodies were laid in the world we got —
	# two numbers answering one question, and the smaller one won.
	#
	# `share_each` is what a body actually gets, so the square that makes a body a
	# full island is `BASE_SIZE / sqrt(share_each)`, and it falls out of the same
	# packing solve rather than being decreed beside it. One body is 512 exactly,
	# which is the island this game has always had.
	var size := _square_for(count, small)
	if want_size > 0:
		size = maxi(want_size, 64)
	var bodies: Array[Dictionary] = []
	var turn := rng.randf() * TAU
	for i in count:
		# ONE BODY IS THE WHOLE SQUARE, CENTRED. Not a special case for its own
		# sake: it is what makes the stage a no-op on every world this project
		# generates today, because `GenShape` has always laid its island about the
		# middle. Move it and every seed's island moves with it.
		var at := Vector2(0.5, 0.5)
		if count > 1:
			var a := turn + TAU * float(i) / float(count)
			at = Vector2(0.5 + cos(a) * ring, 0.5 + sin(a) * ring)
		bodies.append({
			"id": i + 1,
			"at": at,
			"share": share_each,
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


# --- The deal (docs/WORLD.md §4) ------------------------------------------------

## Which landscapes may lie on which body, recorded on `WorldData.continents` so
## nobody downstream has to work it out. Honours `BiomeDef.spread`:
## `most` caps how many bodies carry a type, `least` floors it.
##
## ONE BODY TAKES EVERY TYPE, which is what a world has always done, so this is a
## no-op on every world the project generates today.
##
## A body is never left with nothing: a world with an empty continent on it is a
## worse outcome than a type appearing once more than its `most` asked, so the
## floor wins and the reason is written into the deal.
static func deal(c: GenContext) -> void:
	var bodies := c.w.continents
	if bodies.is_empty():
		return
	# Only the CONTINENTS the plan asked for are dealt to. Everything else that
	# came out of the shape is a skerry and is left alone: `w.continents` records
	# every run of land, and a 512 world is one island and half a dozen of them.
	var planned := maxi(1, c.bodies.size())
	if planned == 1:
		bodies[0]["types"] = PackedInt32Array(c.land_types)
		return
	var rng := Rng.make(c.s, 0xDEA1)
	var home := 0
	for i in bodies.size():
		if bool((c.bodies[i] as Dictionary).get("home", false)) if i < c.bodies.size() else false:
			home = i
	planned = mini(planned, bodies.size())
	var got: Array[PackedInt32Array] = []
	for i in planned:
		got.append(PackedInt32Array())
	for cc: int in c.land_types:
		var sp: Vector2i = c.defs[cc].spread
		var most := planned if sp.y <= 0 else mini(sp.y, planned)
		var want := maxi(1, mini(most, planned))
		# A guaranteed type goes on the HOME body first: the spine of the game
		# lives there (docs/WORLD.md §8.4) and a player who never crosses water
		# must still meet everything something depends on.
		var order: Array[int] = []
		if sp.x >= 1:
			order.append(home)
		var rest: Array[int] = []
		for i in planned:
			if i != home or sp.x < 1:
				rest.append(i)
		while not rest.is_empty():
			order.append(rest.pop_at(rng.randi() % rest.size()))
		for r in mini(want, order.size()):
			got[order[r]].append(cc)
	# Nothing may be left barren.
	for i in planned:
		if got[i].is_empty() and not c.land_types.is_empty():
			got[i].append(c.land_types[rng.randi() % c.land_types.size()])
	for i in planned:
		bodies[i]["types"] = got[i]


## The tile rect a body occupies, for placing anything within it.
static func bounds_of(w: WorldData, id: int) -> Rect2:
	for b: Dictionary in w.continents:
		if int(b.id) == id:
			return b.bounds
	return Rect2(0, 0, w.size, w.size)
