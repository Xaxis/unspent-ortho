class_name Works
## The machines' depots, and the rules about them (docs/VISION.md §2: "the plan
## is visible and progresses"). Pure and deterministic: the same island always
## holds the same depots in the same places, so a works cased at dusk is the
## works broken at midnight.
##
##   Works.sites(world)              one depot per region the plan is working
##   Works.route(site)               the round its patrols walk, along the survey
##   Works.stage(site, days, broken) how far the plan has got here, 0..STAGES-1
##   Works.greening(hours)           how far the land has taken the yard back
##
## A depot is FOUND where the machines already had works: `GenWorks` lays every
## ruled thing in a world on one survey bearing, and the densest knot of those
## in a region is where the plant that feeds them stands. Nothing here places a
## prop or writes to the world — the world already says where the plan is busy,
## and this reads it.
##
## Why a region and not a country: a plan network is a region
## (`Interference.network`), so one depot per region means robbing the depot on
## one snowfield never heats the snowfield on the far coast, and breaking one
## puts out exactly the network whose file the player is in.

## Tiles of the depot's own ground (its yard), and how far out the machines here
## are ITS machines: inside `REACH` the plan is working and says so.
const YARD := 8.0
const REACH := 30.0
## Tiles from a working part at which it can be got at.
const PART_REACH := 2.6
## The three working parts, offset along the survey bearing (x) and across it
## (y). They are far enough apart that a player cannot stand between two and
## break both, which is the whole of why breaking a works is a set piece and not
## a keypress: each one is its own walk, in the open, with the yard awake.
const PART_OFFSETS: Array[Vector2] = [Vector2(-4.4, -2.6), Vector2(0.4, 3.4), Vector2(4.6, -2.2)]
const PART_NAMES: Array[StringName] = [&"feed", &"breaker", &"coolant"]
## Real seconds of work to get one part open, with a steel edge in the hand.
## Long enough that the yard has time to answer, short enough to be a held key.
const BREAK_SECONDS := 4.5
## Hardness the edge in hand must reach to open one (Items.hard_enough).
const BREAK_STUFF := &"steel"

## What a region needs before the plan keeps a depot in it: something of the
## plan's own already standing there, and room enough to be worth working. A
## world holds twenty-odd ruled works in all (`GenWorks` lays them along ONE
## survey bearing across the whole island), so a region rarely has more than a
## handful and never a dense knot of them — the depot goes to the busiest one
## its region has, and `yard` records how much company it has, which is what
## decides how far the plan has got here.
const MIN_WORKS := 1
## Tiles a work counts as being in another's yard. Works further apart than this
## are two separate pieces of the same survey line.
const CLUSTER := 26.0
## The smallest run of land the plan keeps a depot on. Below this the machines
## are crossing the ground, not working it, and a depot on a spur of crust is a
## set piece with nowhere to walk away to.
const MIN_TILES := 900
## A depot keeps this far off a village green and off where the player wakes. The
## plan builds away from people, and the first thing a new player sees should not
## be the set piece they are two days from being able to break.
const CLEAR_VILLAGE := 20.0
const CLEAR_HOME := 34.0

## Plan stages. A works that still stands gets on with its work: every
## `STAGE_DAYS` world days it raises another bay and lights another strip, which
## is the plan advancing where a player can see it. A broken one never does.
const STAGES := 4
const STAGE_DAYS := 3.0

## What a standing depot puts on the land itself, over and above the coast's own
## rolls: one of its own out of the yard every OWN_EVERY world minutes, and one
## on its round along the survey every PATROL_EVERY. A works is where the
## machines ARE, and a region reads busy because its depot is working — not
## because the spawner was told to roll harder in this landscape.
##
## A broken depot puts out NEITHER, for the rest of the game.
##
## And that is only the yard: putting a body out of the gate reaches thirty tiles
## and no further, so a region whose depot had been dark for a week went on
## rolling exactly as many machines over the rest of its ground as one whose yard
## was lit. "The region quiets" is the OTHER half, and it lives in 34_works: on
## ground a broken depot's region covers, no machine of the plan comes out of the
## coast's rolls at all (`Coast.also_shut`). What lives there still does, so the
## land is quiet and not empty. Nothing is thinned by a multiplier — the source
## of the bodies is gone, and a player can count the difference
## (tests/works/test_in_game.gd).
const OWN_EVERY := 14.0
const PATROL_EVERY := 24.0
## How long the depot's round is, in tiles, and how far off the yard it swings.
const ROUTE_LENGTH := 46.0
## World minutes the plan lets pass before it files a person standing in its yard
## again. The disposition package's own gap is longer, so this never doubles a
## cause; it is here so a works that has been disturbed keeps pressing while the
## player is still in it.
const TRESPASS_EVERY := 8.0

## World hours the land takes to close over a broken yard. Four days: long
## enough that a player who breaks one and comes back tomorrow finds it dark and
## bare, and short enough that the same save shows it green.
const RECOVER_HOURS := 96.0
## The most tufts the land puts back over one yard as it greens.
const GREEN_MOST := 14

## A theft of a part is worth this much of the network's file directly, over and
## above what the disposition package files for the sabotage itself. Breaking a
## whole works is meant to be the loudest thing a player can do to one region.
const BREAK_CAUSE := &"sabotage"


## Every depot in a world, biggest region first (the order `WorldData.regions`
## is in), so a save's list and a fresh game's list are the same list.
static func sites(world: WorldData) -> Array[WorksSite]:
	var out: Array[WorksSite] = []
	if world == null:
		return out
	var bearing := GenWorks.bearing(world.seed_value)
	var by_region := {}
	for m: Dictionary in world.landmarks:
		if not m.has("mark"):
			continue
		var p: Vector2 = m.get("pos", Vector2.ZERO)
		var r := world.region_at(floori(p.x), floori(p.y))
		if r < 0:
			continue
		var rows: Array = by_region.get(r, [])
		rows.append(m)
		by_region[r] = rows
	for region: Dictionary in world.regions:
		var id := int(region.get("id", -1))
		var rows: Array = by_region.get(id, [])
		if rows.size() < MIN_WORKS or int(region.get("tiles", 0)) < MIN_TILES:
			continue
		var feed := _keeper_feed(world, region)
		var heart := _knot(world, rows, region.get("centre", Vector2.ZERO), feed[0], feed[1])
		if heart.is_empty():
			continue
		var at := stand_near(world, heart.get("pos", Vector2.ZERO), true)
		if not at.is_finite():
			continue
		var s := WorksSite.new()
		s.region = id
		s.land = StringName(str(region.get("type", &"")))
		s.pos = at
		s.facing = bearing
		s.trade = StringName(str(heart.get("kind", &"depot")))
		s.yard = int(heart.get("count", 0))
		out.append(s)
	return out


## The busiest work in a region: the one with the most others within CLUSTER of
## it, ties broken by which is nearer the region's heart so a depot is inland
## rather than on whatever edge GenWorks happened to lay first, and never on a
## village or on where the player wakes. {pos, kind, count} or {}.
##
## **AND, WHERE THE REGION HAS A KEEPER, ONE THE KEEPER CAN FEEL.** Breaking a
## yard is meant to take food out of the keeper's reach -- that is the STARVE way
## of taking a sentinel, one of the three in `SentinelWay`. It only does so if the
## two are near each other, and nothing here asked: a yard was chosen by what the
## plan had been DOING in a region, and a lair by what the keeper EATS, so the two
## sets missed entirely. Measured at the shipped size before this, seeds 4, 1 and
## 42: six qualifying depots, six spending nothing into their keeper. The starve
## way was open on no island.
##
## So reach is a RANK above busyness, not a weight added to it: among the works a
## keeper could feel, take the busiest; if it can feel none, take the busiest
## there is and nothing changes. A weight would have been a number to tune, and
## the thing being asked for is not "somewhat nearer" -- it is inside a radius or
## outside it.
static func _knot(world: WorldData, rows: Array, centre: Vector2,
		feeds_at := Vector2.INF, feeds_reach := 0.0) -> Dictionary:
	var best := {}
	var best_score := -INF
	var best_fed := false
	for m: Dictionary in rows:
		var p: Vector2 = m.get("pos", Vector2.ZERO)
		if p.distance_to(world.spawn) < CLEAR_HOME or _near_village(world, p):
			continue
		var n := 0
		for other: Dictionary in rows:
			if (other.get("pos", Vector2.ZERO) as Vector2).distance_to(p) <= CLUSTER:
				n += 1
		var score := float(n) - p.distance_to(centre) * 0.004
		var fed := feeds_at.is_finite() and p.distance_to(feeds_at) <= feeds_reach
		if not best.is_empty() and best_fed and not fed:
			continue
		if fed != best_fed or score > best_score:
			best_score = score
			best_fed = fed
			best = {"pos": p, "kind": StringName(str(m.get("kind", &"depot"))), "count": n}
	return best


## Where this region's keeper dens and how far it feeds, or an infinite point
## where the landscape has no keeper -- nineteen of twenty-one do not, which is
## its own gap (docs/VISION.md §3 asks for one per landscape) and is why this
## must degrade to "no preference" rather than to "no depot".
static func _keeper_feed(world: WorldData, region: Dictionary) -> Array:
	var def := Sentinels.for_land(StringName(str(region.get("type", &""))))
	if def == null:
		return [Vector2.INF, 0.0]
	return [Sentinels.lair(world, region, def), def.reach * Sentinels.FEED_SHARE]


static func _near_village(world: WorldData, p: Vector2) -> bool:
	for v: Dictionary in world.villages:
		if (v.get("pos", Vector2.ZERO) as Vector2).distance_to(p) < CLEAR_VILLAGE:
			return true
	return false


## The nearest tile to `p` with room for a yard: dry, on the map, off a road, and
## the ground within a step all round, so a depot is never stood astride a cliff.
## **THE WHOLE COST OF FINDING EVERY DEPOT WAS HERE, AND IT WAS NOT THE SEARCH,
## IT WAS THE METHOD CALLS.** Measured on a 512 world, best of four: the sweep
## costs 9.72 ms and 9.52 of them are eight calls to this function — the knot is
## 0.06, the keeper feed 0.27, `region_at` over every marked landmark 0.02 and
## `GenWorks.bearing` 0.00. It went 1.99 ms to 10.41 the day the per-region site
## loops were aimed at their own regions, which moved the hearts inland, and an
## inland heart makes this walk further before it finds room.
##
## Two things were paying for it, and both are the lever CLAUDE.md already names
## (a GDScript method call is about ten times an array index). The ring walk
## scanned the whole (2r+1) square and threw away everything that was not the
## perimeter — 3,654 iterations to visit 729 tiles — and `_room_at` asked
## `ground_at` and `level_at` for all forty-nine tiles of its window, two bounds
## checks and two method calls each, so a single call could reach seventy thousand
## of them. Neither changes the ANSWER: the window is guaranteed in bounds before
## it is read, so a direct index into `world.ground` and `world.level` is the same
## number by construction, and the ring is visited in the same order it always
## was. Proved by comparing both implementations tile for tile over a 200x200
## block before the old one was deleted.
## **AND `clear` IS WHY THE RULE HAS TO BE ASKED OF THE ANSWER.** `_knot` refuses
## a heart within `CLEAR_VILLAGE` of a green and `CLEAR_HOME` of the spawn, and
## for the depot's whole life that was taken as the depot keeping its distance.
## It is not: this walks up to thirteen tiles looking for room, so a heart 20.1
## tiles from a village hands back a yard 14.1 from it, which is what seed 4 did.
## The test measured `site.pos` and the code measured the heart, and the two are
## not the same place. A caller that cares about the clearance passes `clear` and
## gets a tile that has room AND keeps it; 34_works, which is placing something
## against a yard that already stands, does not and is unchanged.
static func stand_near(world: WorldData, p: Vector2, clear := false) -> Vector2:
	var cx := floori(p.x)
	var cy := floori(p.y)
	if _room_at(world, cx, cy) and (not clear or _keeps_clear(world, Vector2(cx + 0.5, cy + 0.5))):
		return Vector2(cx + 0.5, cy + 0.5)
	for r in range(1, 14):
		# The perimeter of the ring, in the order the square scan visited it: the
		# top row, then the sides of each row between, then the bottom row.
		for dx in range(-r, r + 1):
			var a := Vector2(cx + dx + 0.5, cy - r + 0.5)
			if _room_at(world, cx + dx, cy - r) and (not clear or _keeps_clear(world, a)):
				return a
		for dy in range(-r + 1, r):
			var l := Vector2(cx - r + 0.5, cy + dy + 0.5)
			if _room_at(world, cx - r, cy + dy) and (not clear or _keeps_clear(world, l)):
				return l
			var t := Vector2(cx + r + 0.5, cy + dy + 0.5)
			if _room_at(world, cx + r, cy + dy) and (not clear or _keeps_clear(world, t)):
				return t
		for dx in range(-r, r + 1):
			var b := Vector2(cx + dx + 0.5, cy + r + 0.5)
			if _room_at(world, cx + dx, cy + r) and (not clear or _keeps_clear(world, b)):
				return b
	return Vector2.INF


## The distances a yard must keep, asked of a real tile rather than of the heart
## it was found from.
static func _keeps_clear(world: WorldData, p: Vector2) -> bool:
	return p.distance_to(world.spawn) >= CLEAR_HOME and not _near_village(world, p)


## Room for a yard: dry, on the map, off a road, and the ground within a step all
## round. Reads the fields directly because the window is proved in bounds first
## — see `stand_near`'s header for what that is worth.
static func _room_at(world: WorldData, x: int, y: int) -> bool:
	var size := world.size
	if x < 3 or y < 3 or x + 3 >= size or y + 3 >= size:
		return false
	var levels := world.level
	var grounds := world.ground
	var level: int = levels[y * size + x]
	if level < 1:
		return false
	for dy in range(-3, 4):
		var row := (y + dy) * size + x
		for dx in range(-3, 4):
			var i := row + dx
			var g: int = grounds[i]
			if Ground.is_water(g) or g == Ground.ROAD:
				return false
			if absi(int(levels[i]) - level) > 1:
				return false
	return true


## The implementation `_room_at` replaced, kept only to be compared against it.
## `tests/works/test_world.gd` holds the two equal over a real world, so a future
## rewrite of the fast one has something to be checked against rather than a
## promise in a comment.
static func room_at_plainly(world: WorldData, x: int, y: int) -> bool:
	if not world.in_bounds(x - 3, y - 3) or not world.in_bounds(x + 3, y + 3):
		return false
	var level := world.level_at(x, y)
	if level < 1:
		return false
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var g := world.ground_at(x + dx, y + dy)
			if Ground.is_water(g) or g == Ground.ROAD:
				return false
			if absi(world.level_at(x + dx, y + dy) - level) > 1:
				return false
	return true


## The round the depot's own walk: out along the survey bearing and back, which
## is the line every ruled thing the machines built in this world lies on, so a
## patrol crossing the land is crossing it the way the plan reads. [from, to].
static func route(site: WorksSite) -> Array:
	var along := Vector2.from_angle(site.facing)
	var across := Vector2(-along.y, along.x)
	var off := across * (YARD * 0.7)
	return [site.pos + off - along * ROUTE_LENGTH * 0.5, site.pos + off + along * ROUTE_LENGTH * 0.5]


## How far the plan has got here: another bay every STAGE_DAYS while it stands,
## and never another once it is dark. `days` is the world day (1 on the first).
static func stage(site: WorksSite, days: float, broken: bool, broken_day: float = 0.0) -> int:
	var when := broken_day if broken else days
	var from := 1.0 + float(site.yard) * 0.12
	return clampi(int(floor((when - 1.0) / STAGE_DAYS + from) ), 0, STAGES - 1)


## World minutes between bodies a depot puts out of its own yard, and between
## rounds it sends along the survey. INF once it is broken: for good.
static func own_every(broken: bool) -> float:
	return INF if broken else OWN_EVERY


static func patrol_every(broken: bool) -> float:
	return INF if broken else PATROL_EVERY


## How far the land has taken a broken yard back, 0..1, `hours` world hours since
## it went dark.
static func greening(hours: float) -> float:
	return clampf(hours / RECOVER_HOURS, 0.0, 1.0)


## How many tufts stand in the yard at that much greening.
static func green_tufts(hours: float) -> int:
	return int(round(greening(hours) * GREEN_MOST))


## The depot whose ground `p` is on, or null.
static func at(sites: Array[WorksSite], p: Vector2) -> WorksSite:
	var best: WorksSite = null
	var best_d := REACH
	for s in sites:
		var d := s.pos.distance_to(p)
		if d <= best_d:
			best_d = d
			best = s
	return best


## Which working part of `site` is within reach of `p` (-1 for none).
static func part_near(site: WorksSite, p: Vector2) -> int:
	var best := -1
	var best_d := PART_REACH
	for i in PART_OFFSETS.size():
		var d := site.part(i).distance_to(p)
		if d <= best_d:
			best_d = d
			best = i
	return best


## What a player is told a depot is. The trade is the work it was founded on, so
## a coast depot reads as an intake and a snowfield one as a relay yard.
static func says(site: WorksSite) -> String:
	var land := BiomeRegistry.get_def(site.land)
	var where := land.display_name if land != null else String(site.land)
	return "%s works, %s" % [String(site.trade).capitalize(), where.to_lower()]
