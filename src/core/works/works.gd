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
		var heart := _knot(world, rows, region.get("centre", Vector2.ZERO))
		if heart.is_empty():
			continue
		var at := stand_near(world, heart.get("pos", Vector2.ZERO))
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
static func _knot(world: WorldData, rows: Array, centre: Vector2) -> Dictionary:
	var best := {}
	var best_score := -INF
	for m: Dictionary in rows:
		var p: Vector2 = m.get("pos", Vector2.ZERO)
		if p.distance_to(world.spawn) < CLEAR_HOME or _near_village(world, p):
			continue
		var n := 0
		for other: Dictionary in rows:
			if (other.get("pos", Vector2.ZERO) as Vector2).distance_to(p) <= CLUSTER:
				n += 1
		var score := float(n) - p.distance_to(centre) * 0.004
		if score > best_score:
			best_score = score
			best = {"pos": p, "kind": StringName(str(m.get("kind", &"depot"))), "count": n}
	return best


static func _near_village(world: WorldData, p: Vector2) -> bool:
	for v: Dictionary in world.villages:
		if (v.get("pos", Vector2.ZERO) as Vector2).distance_to(p) < CLEAR_VILLAGE:
			return true
	return false


## The nearest tile to `p` with room for a yard: dry, on the map, off a road, and
## the ground within a step all round, so a depot is never stood astride a cliff.
static func stand_near(world: WorldData, p: Vector2) -> Vector2:
	var cx := floori(p.x)
	var cy := floori(p.y)
	for r in 14:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if _room_at(world, cx + dx, cy + dy):
					return Vector2(cx + dx + 0.5, cy + dy + 0.5)
	return Vector2.INF


static func _room_at(world: WorldData, x: int, y: int) -> bool:
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
