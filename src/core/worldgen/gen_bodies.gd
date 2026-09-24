class_name GenBodies
## The bodies a world is made of, and the void between them (`docs/DESIGN.md`).
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
			"home": false,
		})
	w.continents = out


## **THE OCEAN IS A WALL AND THE SHELF IS NOT** (docs/DESIGN.md, task #50).
## Deep water is the only thing that stops a body on foot (`WorldQuery.standable`)
## and deep water is `level < 0`. Every coast carries a shelf of level-0 water out
## to about twenty tiles, which is exactly right for a shore — you wade off a
## beach — and exactly wrong where two CONTINENTS' shelves happen to touch: those
## twenty tiles become a dry road between two landmasses that the plan, the
## journey, the chapters and `Realm` all treat as separate places.
##
## **THE OCEAN WAS NEVER THE PROBLEM, WHICH IS WHY THE TASK'S OWN NAME MISLEADS.**
## Measured at `Tuning.WORLD_SIZE`: 1,025,135 sea tiles are already at level -1
## and the deepest water stands 456 tiles from the nearest land. The whole fault
## is 19 tiles wide and it is on ONE seed in three — seed 1 joins continents 4
## and 5 across a twelve-tile strait at (955, 454..467), and seeds 42 and 90210
## have no seam at all. A change that deepened the ocean, or widened `SEA_GAP`,
## would move every tile of every seed to fix nineteen of them.
##
## So the cut is the WATERSHED between two shelves and nothing else: each level-0
## tile takes the continent of the nearest land reachable through shallow water,
## and where two continents' shelves meet, that seam goes deep. It is widened to
## `CHANNEL` on each side so the strait reads as a channel rather than as a ditch
## down the middle of a beach. Where the property already holds nothing moves at
## all, which is why no parity seed shifts: at 256 a world has one body of
## continent size and there is no pair to separate.
const CHANNEL := 3
## A body is a continent rather than a skerry at this share of the biggest one.
## Stated as a share so it cannot go stale against a world size: measured, a
## continent is 104,000 to 146,000 tiles and the biggest thing floating in a
## strait is under 1,000, so anything in between would do and this is the middle
## of a two-order-of-magnitude gap. Wading out to a skerry is a thing a player
## should be able to do; this is about the ocean between continents.
const CONTINENT_SHARE := 0.25


static func deepen_straits(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var level := w.level
	var most := 0
	for row: Dictionary in w.continents:
		most = maxi(most, int(row.get("tiles", 0)))
	var big := {}
	for row: Dictionary in w.continents:
		if float(row.get("tiles", 0)) >= CONTINENT_SHARE * float(most):
			big[int(row.get("id", 0))] = true
	if big.size() < 2:
		return
	# Which shelf each patch of shallow water belongs to: the nearest land you
	# could wade to from it.
	var owner := PackedByteArray()
	owner.resize(size * size)
	var q := PackedInt32Array()
	for i in level.size():
		if level[i] > 0:
			owner[i] = w.continent[i]
			q.append(i)
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var x := i % size
		var y := i / size
		var own := owner[i]
		for d: Vector2i in NEIGHBOURS:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var j := ny * size + nx
			if owner[j] != 0 or level[j] != 0:
				continue
			owner[j] = own
			q.append(j)
	# The seam, and then `CHANNEL` tiles either side of it.
	var marked := PackedByteArray()
	marked.resize(size * size)
	var front := PackedInt32Array()
	for i in level.size():
		if level[i] != 0 or not big.has(int(owner[i])):
			continue
		var x := i % size
		var y := i / size
		for d: Vector2i in NEIGHBOURS:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				continue
			var j := ny * size + nx
			if level[j] < 0 or owner[j] == owner[i] or not big.has(int(owner[j])):
				continue
			marked[i] = 1
			front.append(i)
			break
	if front.is_empty():
		return
	for _step in CHANNEL:
		var next := PackedInt32Array()
		for i: int in front:
			var x := i % size
			var y := i / size
			for d: Vector2i in NEIGHBOURS:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var j := ny * size + nx
				if marked[j] != 0 or level[j] != 0:
					continue
				marked[j] = 1
				next.append(j)
		front = next
	for i in marked.size():
		if marked[i] != 0:
			level[i] = -1


const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## WHICH CONTINENT IS HOME IS RECORDED, not worked out by whoever asks. The
## journey is authored on it, a chapter's first demand is there, and the story's
## legs start there — and until now the only way to know was to find the spawn and
## look its continent up, which is the shape of bug `WorldData.road` and the
## landmark `region` field both exist to end.
##
## It is called AFTER `GenSettle.spawn`, and read off the spawn rather than off
## the plan's home body, because the two can disagree: measured, on seed 42 the
## plan's home centre and the tile the player actually wakes on are different
## masses. **Home is where he wakes.** Anything else is a second answer that will
## be wrong on one seed in three.
static func mark_home(c: GenContext) -> void:
	var w := c.w
	var at := w.spawn
	var x := clampi(floori(at.x), 0, c.size - 1)
	var y := clampi(floori(at.y), 0, c.size - 1)
	var id := w.continent_at(x, y)
	for row: Dictionary in w.continents:
		row["home"] = int(row.get("id", -1)) == id


# --- The planning half (docs/DESIGN.md) -----------------------------------------
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
	#
	# AND FIVE AT MOST, since L1 (2026-09-22). A bigger square was meant to give
	# each landscape a bigger place, and it did not: `plan` keeps every dealt
	# continent that fits, so at 1600-2048 the room went to a sixth and seventh
	# continent and the main regions grew 1.5-1.8x for 2.5x the area (seed 90210,
	# dealt five, grew them 2.49x). A landscape's size is what the 40-frame rule
	# asks for, so the continents stay five and the square pays for them to be
	# bigger. The roll is still drawn (`% 1`), so the stream after it is unchanged
	# and a world that already had five is byte-identical.
	&"surface": Vector2i(5, 5),
	&"underground": Vector2i(5, 7),
	&"orbital": Vector2i(3, 8),
	&"era": Vector2i(1, 2),
}
## An orbital body is a captured asteroid, not a continent: it takes this share of
## the land a continent would.
const ORBITAL_SHARE := 0.32
## The share of a world's continents a landscape lies on when it declares no
## `BiomeDef.spread`. Under half is what makes two continents different places
## rather than two draws of one deck; a landscape that wants to be everywhere (a
## coast) or nowhere but one (a rarity) says so in its own file.
##
## **0.4, WHICH IS TWO OF FIVE, AND THE SIZE OF A PLACE IS WHY** (L1, 2026-09-23).
## It was 0.5, and `roundi(2.5)` is three: every landscape lay on three of the five
## continents, broke into three to six regions, and its main region -- the place
## the 40-frame rule is about -- was about a third of its tiles. Measured at 1840,
## seeds 1/42/90210: 6 of 21 landscapes had a main region of 40 frames on every
## seed at 0.5, 13 at 0.4 with nothing else changed, and 21 once the eight still
## short had their shares raised out of the coast's. A continent now carries about
## eight landscapes instead of thirteen: fewer, and each one a place you can walk
## for a while.
const MOST_BODIES := 0.4
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
	# so no caller has to know which realms share a map (docs/DESIGN.md).
	var shares: StringName = Realm.def(realm).get("footprints_of", &"")
	if shares != &"" and shares != realm:
		var other := plan(seed_value, shares, want_size)
		return {"size": other.size, "bodies": other.bodies}
	var rng := Rng.make(seed_value, 0xB0D1E5)
	var count := range_of.x + (rng.randi() % maxi(1, range_of.y - range_of.x + 1))
	var small: float = ORBITAL_SHARE if realm == Realm.ORBITAL else 1.0
	# THE SQUARE'S WIDTH DECIDES HOW MANY CONTINENTS FIT IN IT, because a continent
	# is a whole island and not a share of one (see `share_each` below). Asked for
	# a size, drop the count until they fit AT FULL SIZE rather than shrinking them
	# to suit.
	#
	# DOWN TO ONE, and "at least five" is not a floor here. It is what a square of
	# 1300 or more buys (`Tuning.WORLD_SIZE` is 1840), which is the world a game is played in; a
	# 64-tile test fixture is not a small world with five continents in it, it is
	# one island, as it always was. Flooring the count at the realm's least instead
	# put five continents on a 64-tile square and took thirty tests down with it —
	# every one of them a true statement about a world nobody meant to make.
	if want_size > 0:
		while count > 1 and _square_for(count, small) > want_size:
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
	# journey has run south to north since M1 (docs/DESIGN.md).
	var home := 0
	for i in bodies.size():
		if float((bodies[i].at as Vector2).y) > float((bodies[home].at as Vector2).y):
			home = i
	bodies[home]["home"] = true
	return {"size": size, "bodies": bodies}


# --- The deal (docs/DESIGN.md) ------------------------------------------------

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
	planned = mini(planned, bodies.size())
	var home := _home_row(c, planned)
	var got: Array[PackedInt32Array] = []
	for i in planned:
		got.append(PackedInt32Array())
	for cc: int in c.land_types:
		var sp: Vector2i = c.defs[cc].spread
		# A LANDSCAPE THAT SAYS NOTHING LIES ON SOME CONTINENTS, NOT ALL OF THEM.
		#
		# The default was `planned` — every landscape on every continent — which
		# made five continents five copies of one island, each carrying the same
		# nine landscapes in the same climate order. That is the owner's brief
		# defeated by its own default: "continents can have different landscapes on
		# them and a well distributed mixture, but some of the rarer types
		# exclusive only to some continents". `BiomeDef.spread` was built to say
		# exactly that and could never be heard over a default that gave everything
		# to everybody.
		#
		# So a landscape that argues with nothing lands on about half of them, and
		# one that wants to be everywhere or nowhere says so. `spread.x >= 1` still
		# guarantees the home continent first, because the spine lives there.
		# At least two where there are two, because MOST_BODIES was tuned for five:
		# a 1024 square holds three continents, `roundi(3 * 0.4)` is one, and every
		# landscape on a single continent left the journey's far legs with nothing
		# of the plan's to cast (`the_far_works`, test_plan at 1024).
		var most := maxi(mini(2, planned), roundi(float(planned) * MOST_BODIES)) if sp.y <= 0 else mini(sp.y, planned)
		var want := maxi(1, mini(most, planned))
		# A guaranteed type goes on the HOME body first: the spine of the game
		# lives there (docs/DESIGN.md) and a player who never crosses water
		# must still meet everything something depends on.
		#
		# **TWO MEANINGS SHARE `spread.x >= 1` AND THEY MUST NOT BE MERGED.** `(1, 0)`
		# is DEPENDENCY: something the spine needs lies here, so it goes on the
		# home body where a player who never crosses water will meet it. `(1, 1)`
		# is EXISTENCE: the guaranteed twin of `(0, 1)`, "the rare thing you cross
		# an ocean for" -- exactly one body, and never home while there is another,
		# or the ocean it is the reward for crossing is not crossed. `frost_sea`
		# says the second in its own words. Home-first read both as the first.
		var rare := sp.x >= 1 and sp.y == 1 and planned > 1
		var order: Array[int] = []
		if sp.x >= 1 and not rare:
			order.append(home)
		var rest: Array[int] = []
		for i in planned:
			if i != home or (sp.x < 1 and not rare):
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
	# THE DEAL IS A RULE ABOUT LAND, NOT ABOUT WHERE A SITE GOES. It was asked only
	# when a site was placed, and a territory then grew by distance across the
	# strait onto whatever body was nearer: measured at 1300, 70.6% of one
	# continent of seed 42 was landscapes it had never been dealt, and the coast
	# lost its own heart on the home body while it held a body it was not dealt.
	# Everything that decides whose land a tile is asks `GenContext.may_stand`.
	# It cannot draw a new line across open ground: a continent's edge is water.
	fill_allow(c)


## Fill `GenContext.allow` from what `w.continents` records was dealt. The one
## place the table is written, so a finished world (a test, a probe) can ask the
## same question world gen asked. A world whose rows carry no deal (one body, or
## nothing dealt yet) restricts nothing and is left empty.
static func fill_allow(c: GenContext) -> void:
	c.allow = PackedByteArray()
	var dealt := 0
	for row: Dictionary in c.w.continents:
		if row.has("types"):
			dealt += 1
	if dealt < 2:
		return
	c.allow.resize(256 * c.types)
	c.allow.fill(1)
	for row: Dictionary in c.w.continents:
		if not row.has("types"):
			continue
		var id := int(row.get("id", 0))
		for cc in c.types:
			c.allow[id * c.types + cc] = 0
		for cc: int in (row.get("types") as PackedInt32Array):
			c.allow[id * c.types + cc] = 1


## The id of the continent the PLAN calls home, or -1 on a world of one body
## (where there is nothing to choose between). Settling asks it so the spawn
## village stands on the body the deal made ready.
static func home_id(c: GenContext) -> int:
	if c.bodies.size() <= 1 or c.w.continents.is_empty():
		return -1
	var planned := mini(c.bodies.size(), c.w.continents.size())
	return int(c.w.continents[_home_row(c, planned)].get("id", -1))


## The row of `w.continents` the PLAN calls home, matched by identity: the row
## whose land holds the plan's home centre. Rows are ranked by size and the plan
## lists its bodies in the order it placed them, so position in one list says
## nothing about the other -- reading `home` off the plan's index sent the home
## guarantee to a different continent on every seed measured (1, 42, 90210).
static func _home_row(c: GenContext, planned: int) -> int:
	var at := Vector2.ZERO
	for b: Dictionary in c.bodies:
		if bool(b.get("home", false)):
			at = (b.at as Vector2) * c.size
	var id := c.w.continent_at(clampi(floori(at.x), 0, c.size - 1), clampi(floori(at.y), 0, c.size - 1))
	var best := 0
	var best_d := INF
	for i in planned:
		var row: Dictionary = c.w.continents[i]
		if int(row.get("id", -1)) == id:
			return i
		# The centre fell in a bay: the nearest continent's centre is the body.
		var d := (row.centre as Vector2).distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best


## The tile rect a body occupies, for placing anything within it.
static func bounds_of(w: WorldData, id: int) -> Rect2:
	for b: Dictionary in w.continents:
		if int(b.id) == id:
			return b.bounds
	return Rect2(0, 0, w.size, w.size)
