class_name Sentinels
## Every sentinel design the game knows, and the pure rules about where a keeper
## stands and what it holds (docs/VISION.md).
##
## A design is one file under `src/core/sentinel/designs/` declaring
## `static func make() -> SentinelDef`, discovered here the way a landscape is
## discovered by `BiomeRegistry`. A landscape claims its keeper by name in
## `BiomeDef.sentinel`, and that is the only door: nothing in this package names a
## landscape, and nothing in a landscape's file knows how a fight works.
##
##   Sentinels.for_land(&"coast")        the design a landscape keeps, or null
##   Sentinels.states(world)             one state per region that has a keeper
##   Sentinels.lair(world, region, def)  where that region's keeper stands
##   Sentinels.declare_loot()            its drops and its one elite material
##
## Every region of a type grows its own instance from the one design (VISION §3:
## "one sentinel design per landscape type, never reskinned between types"), so
## the second Salt Flats keeper is the same species and a different fight: its
## arena is the terrain of its own region, its station is its own region's work,
## and what feeds it is what stands near that.

const DIR := "res://src/core/sentinel/designs"

## The body comes out when the player is this near its lair (Chebyshev tiles) and
## is culled by the coast at `Spawner.CULL`, which is further, so a keeper does not
## flicker in and out on the edge of its own ground.
const PUT_OUT := 19.0
## How often the ways are judged (sim ms). Four times a second is finer than any
## of them needs and far cheaper than a frame.
const JUDGE_MS := 250.0
## A keeper's feeds are counted inside this share of its reach: the works it stands
## among, not every mast in the region.
const FEED_SHARE := 0.8
## Tiles round where a keeper fell that the land closes over after it, a tuft at
## a time on the yard's own clock (Works.green_tufts; 44_sentinels).
const GREEN_REACH := 6.0
## No keeper stands within this of where the player wakes. A boss on top of the
## village a player opens their eyes in is not a boss, it is a wall — and the
## plan's own works keep off villages too (GenWorks). A region with nowhere far
## enough from home has no keeper at all: a run of land that small has no room for
## an arena, and the first thing a new player meets should never be the last thing
## they were meant to.
const CLEAR_OF_HOME := 48.0
## The smallest run of land worth keeping. A world is full of small runs of a
## landscape — a strip of shingle, a spur of crust — and a keeper on a scrap of
## ground 70 tiles across is a boss standing in a puddle with no works to feed it,
## no room for its arena and nothing of its own to guard. Above this, every region
## of the type has its own instance, varied by the terrain it stands in (VISION §3),
## and a world regularly holds two of one design.
const MIN_TILES := 240

static var _defs: Dictionary = {}
static var _order: Array[SentinelDef] = []
static var _lock := Mutex.new()
static var _declared := false
## Each world's keepers' lairs: [region, def, lair] rows, keyed as `states` asks.
static var _lairs: Dictionary = {}
## How many lairs have been worked out (never answered from memory): a test's count.
static var lairs_worked := 0
static var _lair_at: Dictionary = {}
static var _lair_lock := Mutex.new()
## Several worlds' regions (a surface and its realms, a test's few seeds).
const LAIRS_MOST := 512


## Let go of every remembered lair, so the next ask works it out afresh (a test
## timing the real search).
static func forget() -> void:
	_lair_lock.lock()
	_lair_at.clear()
	_lair_lock.unlock()
	_lairs_lock.lock()
	_lairs.clear()
	_lairs_lock.unlock()
static var _lairs_lock := Mutex.new()


static func all() -> Array[SentinelDef]:
	_ensure()
	return _order.duplicate()


static func by_id(id: StringName) -> SentinelDef:
	_ensure()
	return _defs.get(id, null)


## The design the landscape type `land` keeps, read off its own file
## (`BiomeDef.sentinel`). Null when that landscape has no keeper yet.
## Whether a roster row is a landscape's keeper (Roster `sentinel`).
static func is_keeper(row: Dictionary) -> bool:
	return StringName(str(row.get("sentinel", &""))) != &""


static func for_land(land: StringName) -> SentinelDef:
	var d := BiomeRegistry.get_def(land)
	if d == null or d.sentinel == &"":
		return null
	return by_id(d.sentinel)


## Landscape ids that have a keeper, in registry order.
static func lands() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: BiomeDef in BiomeRegistry.land():
		if d.sentinel != &"" and by_id(d.sentinel) != null:
			out.append(d.id)
	return out


## What is wrong with the designs and the landscapes that claim them, as lines, so
## one test can fail with the list (the registry pattern).
static func problems() -> PackedStringArray:
	_ensure()
	var out := PackedStringArray()
	for d: SentinelDef in _order:
		var w := "sentinel %s: " % d.id
		if d.land == &"" or BiomeRegistry.get_def(d.land) == null:
			out.append(w + "keeps a landscape that does not exist: %s" % d.land)
		elif BiomeRegistry.get_def(d.land).sentinel != d.id:
			out.append(w + "%s does not claim it (its file says %s)" % [d.land, BiomeRegistry.get_def(d.land).sentinel])
		if not Roster.has(d.kind):
			out.append(w + "its body is not in the roster: %s" % d.kind)
		if d.phases.size() < 2:
			out.append(w + "a sentinel wants phases, it has %d" % d.phases.size())
		if d.ways.size() != 3:
			out.append(w + "VISION §3 asks for three ways to beat it, it has %d" % d.ways.size())
		if not d.has_way(SentinelWay.FORCE):
			out.append(w + "nothing can be beaten only by cleverness: it wants a way through its body")
		var last := 2.0
		for p in d.phases:
			if p.at > last:
				out.append(w + "phase %s comes at %.2f health, after one at %.2f" % [p.id, p.at, last])
			last = p.at
			if p.part == &"none" or p.part == &"":
				out.append(w + "phase %s has no working side" % p.id)
			if p.bite.is_empty():
				out.append(w + "phase %s has no bite" % p.id)
		if d.drops == &"" or Drops.table(d.drops).is_empty():
			out.append(w + "nothing on its drop table (src/core/loot)")
		if d.core == &"" or not Materials.can_come_from(d.core, &"", d.drops):
			out.append(w + "its core is not declared as coming from it: %s" % d.core)
		var two := 0
		for other: SentinelDef in _order:
			if other.land == d.land:
				two += 1
		if two > 1:
			out.append(w + "%s has more than one keeper" % d.land)
	return out


## Its drop table and the one elite material only it gives (docs/VISION.md,
## src/core/loot). Called by the system on setup and by tests: the loot tables are
## static and a test may have cleared them, so it is safe to call again.
static func declare_loot() -> void:
	_ensure()
	for d: SentinelDef in _order:
		# Its own table id, not its kind: 56_economy rolls a kind's table on every
		# kill, and this one is rolled once for the region it keeps.
		Drops.declare(d.drops, [
			# A relic's core: one per sentinel, and this keeper is the only thing
			# in the world it comes off.
			{"item": d.core, "chance": 1.0, "rarity": Rarity.RELIC},
			# What comes off a body that size when it is opened up.
			{"item": &"scrap", "count": Vector2i(6, 11)},
			{"item": &"wick", "count": Vector2i(2, 5), "rarity": Rarity.UNCOMMON},
		], d.kind)
		Materials.declare(d.core, {
			"sources": [d.drops], "rarity": Rarity.RELIC,
			"what": "cut out of %s, still warm" % d.display_name,
		})
	_declared = true


static func loot_declared() -> bool:
	return _declared


# --- a phase, worn by a live body -------------------------------------------

## Give this body its OWN copy of its roster row. `Roster.row` hands back the
## table itself, and a phase writes onto the row, so a keeper that patched it in
## place would rewrite the roster for every body in the game.
static func own_row(m: MobState) -> void:
	m.row = Roster.row(m.kind).duplicate(true)


## Put phase `i` on a live body: its working part, whether that part throws blows
## off, its bite, its speeds and how fast it comes round. Pure (it touches nothing
## but the body), so a test can walk a keeper through all of its phases headless
## and read what a player would read.
static func wear_phase(m: MobState, def: SentinelDef, i: int) -> void:
	var p := def.phase(i)
	if m.row == Roster.row(m.kind):
		own_row(m)
	m.row.merge(p.row_patch(), true)
	m.part = p.part
	m.pace = p.pace * FightRules.SPEED_SCALE
	m.dash = p.dash * FightRules.SPEED_SCALE
	m.quick = float(p.quick) / 100.0
	m.turn_rate = p.turn
	m.bite = Blow.from_dict(p.bite)
	m.bite.creep = 1.0
	m.come_round = come_round_of(m.bite)
	m.flank_since = -1.0
	# The sim's own one-shot second act belongs to ordinary machines; a keeper's
	# phases are these, and they are counted here.
	m.second_act = false


## The come-round a phase's bite makes (SentinelDef.come_round says it in the
## keeper's own words): a sweep at the side a body keeps to, told short -- never
## longer than COME_ROUND_WINDUP, or than the bite -- as wide as the bite and never
## wider than COME_ROUND_WIDTH (wider, and no dodge clears it: measured, the
## anchor's at 3.6 and the plumb's at 3.0 took the reader every time), a
## little lighter, and with a long recovery after, so the dodge it asks for is
## also the opening it gives.
const COME_ROUND_WINDUP := 380
const COME_ROUND_RECOVERY := 760
## The widest a sweep is: a dodge (about 1.3 tiles) clears 2.0 from its middle.
const COME_ROUND_WIDTH := 2.0


static func come_round_of(bite: Blow) -> Blow:
	if bite == null:
		return null
	var b := Blow.from_dict({
		"swing": [mini(COME_ROUND_WINDUP, bite.windup), 150, COME_ROUND_RECOVERY, 900],
		"reach": bite.reach,
		"width": minf(bite.width, COME_ROUND_WIDTH),
		"dmg": maxi(2, bite.dmg - 1),
		"knock": bite.knock * 0.8,
		"knock_ms": bite.knock_ms,
	})
	b.creep = 1.0
	return b


# --- where a keeper stands --------------------------------------------------

## One state per region whose landscape type has a keeper, biggest region first
## (the order `WorldData.regions` is in).
static func states(world: WorldData) -> Array[SentinelState]:
	var out: Array[SentinelState] = []
	if world == null:
		return out
	# Where each keeper stands is fixed by the world (its regions and the marks
	# laid on it), so it is worked out once per world; the states are made fresh
	# every time, because a game wears their health down.
	var key := "%d:%d" % [world.get_instance_id(), world.landmarks.size()]
	_lairs_lock.lock()
	var got: Variant = _lairs.get(key)
	_lairs_lock.unlock()
	# Asked by type, never by an operator on the Variant: this can run on a
	# worker (tests/core/test_worker_types.gd).
	var rows: Array = got if typeof(got) == TYPE_ARRAY else []
	if typeof(got) != TYPE_ARRAY:
		var found: Array = []
		for r: Dictionary in world.regions:
			var def := for_land(StringName(str(r.get("type", &""))))
			if def == null or int(r.get("tiles", 0)) < MIN_TILES:
				continue
			var at := lair(world, r, def)
			if at.is_finite():
				found.append([int(r.get("id", -1)), def, at])
		_lairs_lock.lock()
		if _lairs.size() >= 8:
			_lairs.clear()
		_lairs[key] = found
		_lairs_lock.unlock()
		rows = found
	for row: Array in rows:
		var def: SentinelDef = row[1]
		var s := SentinelState.new()
		s.region = int(row[0])
		s.design = def.id
		s.land = def.land
		s.lair = row[2]
		s.max_health = Roster.health_of(def.kind)
		s.health = s.max_health
		out.append(s)
	return out


## Where this region's keeper stands: the plan's own work inside the region (the
## first of the design's `stations` the region holds where its ways can be done,
## in the order the design prefers them), else, for a design whose stations
## nobody lays yet, the region's heart. Deterministic: the same seed and the same
## region always put it in the same place, because a boss that moves between
## runs cannot be walked to twice.
## Vector2.INF when this region has nowhere to keep (see CLEAR_OF_HOME and
## `ways_closed`).
##
## Worked out once per world, region and design and remembered (`_lair_at`):
## the search is dear and every caller -- the depot sweep over every region,
## the keepers' states, the spawner, the tours -- asks the same question.
## Keyed like Works.sites, by the world's instance and how many marks it holds,
## so a world still being laid is never handed an old answer.
## THE NEXT KEEPER (ROADMAP slice 2, step 6): the nearest to `from` still
## standing whose design none that fell had, among those on `bodies` (body ids of
## `world`: the journey's legs he can reach, Guide.bodies_reached). A design taken
## once is not sent again: nearest alone gave seed 7 a second Tide Reaper at 354
## tiles, where the anvil stands at 506. Never where he cannot go: on seeds 1 and
## 7 that anvil stands on an islet off the journey, across deep water from home,
## and the lead pointed there in slice 2, before the raft. Null when every design
## standing on those bodies has been taken. A design whose fight is not built
## yet (SentinelDef.ready) is never the next: it keeps its region unnamed.
static func next_keeper(states: Array, from: Vector2, world: WorldData, bodies: Array[int]) -> SentinelState:
	var taken: Dictionary = {}
	for s: SentinelState in states:
		if s.fallen:
			taken[s.design] = true
	var best: SentinelState = null
	for s: SentinelState in states:
		if s.fallen or taken.has(s.design) or s.region < 0 or not bodies.has(body_of(world, s.lair)):
			continue
		var def := by_id(s.design)
		if def != null and not def.ready:
			continue
		if best == null or s.lair.distance_to(from) < best.lair.distance_to(from):
			best = s
	return best


## The body a lair stands on: its own tile's, or, for a lair out in the shallows
## off a shore, the nearest land's within SHORE tiles. 0 where there is none.
const SHORE := 4
static func body_of(world: WorldData, at: Vector2) -> int:
	var x := floori(at.x)
	var y := floori(at.y)
	for r in SHORE + 1:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var id := world.continent_at(x + dx, y + dy)
				if id != 0:
					return id
	return 0


## The keepers as a game holds them (44_sentinels), worn and fallen; [] with none.
## Untyped as a Node: this file is loaded by world generation, before Game is.
static func live(game: Node) -> Array:
	for sys: Node in game.get(&"systems"):
		if sys.name == "44_sentinels":
			return sys.call(&"states")
	return []


static func lair(world: WorldData, region: Dictionary, def: SentinelDef) -> Vector2:
	var key := "%d:%d:%d:%s" % [world.get_instance_id(), world.landmarks.size(), int(region.get("id", -1)), def.id]
	_lair_lock.lock()
	var had: Variant = _lair_at.get(key)
	_lair_lock.unlock()
	# Asked by type, never by an operator on the Variant: this runs on the
	# realm raise's worker (tests/core/test_worker_types.gd).
	if typeof(had) == TYPE_VECTOR2:
		return had as Vector2
	var at := _lair_worked(world, region, def)
	_lair_lock.lock()
	if _lair_at.size() >= LAIRS_MOST:
		_lair_at.clear()
	_lair_at[key] = at
	lairs_worked += 1
	_lair_lock.unlock()
	return at


static func _lair_worked(world: WorldData, region: Dictionary, def: SentinelDef) -> Vector2:
	var id := int(region.get("id", -1))
	var home := world.spawn
	# **AMONG THE STATIONS OF ONE KIND, THE ONE IT CAN EAT AT.** This took the
	# FIRST station of the best kind the region held, which is deterministic and
	# was the whole of the requirement -- and it is why the STARVE way was open on
	# no island. A keeper was placed by what the plan BUILT and a depot by what the
	# plan was DOING, and neither asked about the other, so breaking a yard took
	# nothing out of any keeper's reach: measured, six of six depots spent nothing.
	# `Works._knot` now sites a depot at a work its keeper can feel; this is the
	# same agreement from the other end, and the two are not circular because both
	# read the same fixed thing -- the marked works worldgen already laid.
	#
	# The design's own `stations` order still decides the KIND. This only chooses
	# between stations of that kind, and prefers the one with the most marked
	# works inside its feeding reach. Ties keep landmark order, so it is as
	# deterministic as it was: a boss that moves between runs cannot be walked to
	# twice.
	var feed := def.reach * FEED_SHARE
	# Never on the ground its own FOUNDER way takes it on: stood there, a roused
	# keeper foundered at home in the time it took to turn round (seed 1's anchor
	# on the mesas' sand, tests/sentinel/test_keeper_reach.gd).
	var sink := founders(def)
	# And stood on room it can come out of: `stand_near` answers the point it was
	# asked when it finds none, a region with no room (seed 1's glass sliver: 27
	# tiles, all the sand it founders on) has no keeper, and a lair in a pocket of
	# terraces (seed 4's crags) strikes only what walks up to it. Asked of the
	# ground in rays about the spot (`gets_out`), the cheap test: this runs while
	# the world is worked out. tests/sentinel/test_keeper_reach.gd floods what
	# its move truly opens round every lair it gives.
	#
	# THE STATION RULE (`ways_closed`): it dens only at a station where every way
	# its design declares can be done, the first kind in the design's order that
	# has one. Where the plan builds its stations (one stands anywhere in the
	# world) and none in this region keeps its ways, the region has no keeper: a
	# keeper is the plan's, and a fight with a way its design promises shut is
	# not one. Seed 42's Reaper on a skerry the coast laid nothing on, and seed
	# 90210's on a coast with no shore, stood at their hearts with nothing to eat.
	# A design whose stations nobody lays yet dens by its heart (below).
	#
	# THE LANDING IS SAFE GROUND: no keeper dens within its reach of where the
	# raft from home comes ashore (GenBodies' `from` on the LANDFALL body's row),
	# so the first thing across the water is never a keeper at the quay.
	var landings: Array[Vector2] = []
	for row: Dictionary in world.continents:
		if bool(row.get("landfall", false)) and row.has("from"):
			landings.append(row["from"] as Vector2)
	var built := false
	for want: StringName in def.stations:
		var best := Vector2.INF
		var best_works := -1
		for m: Dictionary in world.landmarks:
			if StringName(str(m.get("kind", &""))) != want:
				continue
			built = true
			var p: Vector2 = m.get("pos", Vector2.ZERO)
			if world.region_at(floori(p.x), floori(p.y)) != id:
				continue
			var at := den_at(world, p, def, landings)
			if at.is_finite() and def.way_of(SentinelWay.STARVE) != null and not larder_robbable(world, at, def):
				at = _den_off_larder(world, p, def, landings, id)
			if not at.is_finite():
				continue
			var n := 0
			for w2: Dictionary in world.landmarks:
				if not w2.has("mark"):
					continue
				if (w2.get("pos", Vector2.ZERO) as Vector2).distance_to(at) <= feed:
					n += 1
			if n > best_works and ways_closed(world, at, def).is_empty():
				best_works = n
				best = at
		if best.is_finite():
			return best
	if built:
		return Vector2.INF
	# NOBODY LAYS ITS STATIONS YET: it dens at the room nearest its region's heart
	# where every way the ground alone answers can be done (`ways_closed`'s
	# ground_only: its founder ground in reach, its craft's water in its guard),
	# first with that ground where it sees a lure from the den (`lure_reach`),
	# then anywhere in its reach. At the bare heart, seed 1's anvil had no sand
	# in reach and its lure could never be played. Where no room in the region
	# keeps them, the heart as it was, then the quietest room nearest it; none at
	# all, and no keeper.
	var centre: Vector2 = region.get("centre", Vector2.ZERO)
	var heart := stand_near(world, centre, 1.4, sink)
	var heart_ok := _den_ok(world, heart, def, landings)
	for near: bool in [true, false]:
		if heart_ok and ways_closed(world, heart, def, true, near).is_empty():
			return heart
		var kept := _room_nearest(world, region, def, sink, centre, landings, true, near)
		if kept.is_finite():
			return kept
	if heart_ok:
		return heart
	return _room_nearest(world, region, def, sink, centre, landings, false)


## Where a keeper of `def` would den at a station laid at `p`: the nearest room
## to it off the ground it founders in, clear of home and with a way out of it
## (`_lair_worked`); INF when there is none.
## `landings`: where rafts come ashore (`_lair_worked`), which no den covers.
static func den_at(world: WorldData, p: Vector2, def: SentinelDef, landings: Array[Vector2] = []) -> Vector2:
	var at := stand_near(world, p, 1.4, founders(def))
	return at if _den_ok(world, at, def, landings) else Vector2.INF


## Where a keeper of `def` dens for a station laid at `p` when the nearest room
## to it has works of its larder under its feet (`larder_robbable`): seed 1's
## Reaper denned two tiles off its own intake. The nearest room in region `id`
## past THREAT_RADIUS of the station, where every way is kept, tried in squares
## of Chebyshev rings one tile apart (DEN_OFF), nearest first: the station's
## works stay its larder and the den stays by the station. INF when none is.
const DEN_OFF := 4


static func _den_off_larder(world: WorldData, p: Vector2, def: SentinelDef, landings: Array[Vector2], id: int) -> Vector2:
	var sink := founders(def)
	var spots: Array[Vector2] = []
	var first := floori(Senses.THREAT_RADIUS) + 1
	for d in range(first, first + DEN_OFF):
		for k in range(-d, d + 1, 2):
			for q: Vector2 in [Vector2(k, -d), Vector2(k, d), Vector2(-d, k), Vector2(d, k)]:
				spots.append(p + q)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(p) < b.distance_squared_to(p))
	for q: Vector2 in spots:
		if not world.in_bounds(floori(q.x), floori(q.y)) or world.region_at(floori(q.x), floori(q.y)) != id:
			continue
		if not larder_robbable(world, q, def):
			continue
		var at := stand_near(world, q, 1.4, sink)
		if larder_robbable(world, at, def) and _den_ok(world, at, def, landings) and ways_closed(world, at, def).is_empty():
			return at
	return Vector2.INF


## A keeper of `def` can den at `at`: clear of home and of every landing by its
## reach, on room off the ground it founders in, with a way out and the ground
## its move opens round it.
static func _den_ok(world: WorldData, at: Vector2, def: SentinelDef, landings: Array[Vector2]) -> bool:
	if at.distance_to(world.spawn) < CLEAR_OF_HOME:
		return false
	for l: Vector2 in landings:
		if at.distance_to(l) <= def.reach:
			return false
	return _room_at(world, floori(at.x), floori(at.y), 1.4, founders(def)) and gets_out(world, at, def) \
		and opens(world, at, def) >= OPENS_LEAST


## Rays a keeper's lair is looked out along, how far, and how many must get
## that far on the ground its move keeps (a level step no more than it climbs,
## room over it for its height, no deep water) for it to come out of the lair.
const RAYS := 16
const RAY_OUT := 10
const RAYS_OUT := 6
## Spots `_room_nearest` looks out from before a region is given up.
const ROOM_TRIES := 40


static func gets_out(world: WorldData, at: Vector2, def: SentinelDef) -> bool:
	var row := Roster.row(def.kind)
	var step := maxi(1, int(row.get("climbs", 1)))
	# Its height in levels, as its move asks the room over a tile (FightSim.tall_of).
	var tall := int(ceil(float(row.get("height", 1.0)) / WorldData.STEP))
	var out := 0
	for i in RAYS:
		var dir := Vector2.from_angle(TAU * float(i) / float(RAYS))
		var was := Vector2i(floori(at.x), floori(at.y))
		var ok := true
		for k in range(1, RAY_OUT + 1):
			var p := at + dir * float(k)
			var t := Vector2i(floori(p.x), floori(p.y))
			if t == was:
				continue
			if not world.in_bounds(t.x, t.y) or world.level_at(t.x, t.y) < 0 or world.ground_at(t.x, t.y) == Ground.DEEP_WATER \
					or absi(world.level_at(t.x, t.y) - world.level_at(was.x, was.y)) > step \
					or (world.has_overhead() and world.headroom_at(t.x, t.y) < tall):
				ok = false
				break
			was = t
		out += int(ok)
		if out >= RAYS_OUT:
			return true
	return false


## How many tiles OPEN_FROM..OPEN_TO out of `at` (Chebyshev) a keeper's own move
## reaches from it, by the rules its move keeps on the ground (`gets_out`'s). A
## lair is held to OPENS_LEAST: `gets_out`'s rays are the cheap test, and they
## passed seed 1's crags heart boxed into 254 by terraces, where the keeper
## struck only what walked up to it (tests/sentinel/test_keeper_reach.gd floods
## the same window).
const OPEN_FROM := 8
const OPEN_TO := 14
const OPENS_LEAST := 300


static func opens(world: WorldData, at: Vector2, def: SentinelDef) -> int:
	var row := Roster.row(def.kind)
	var step := maxi(1, int(row.get("climbs", 1)))
	var tall := int(ceil(float(row.get("height", 1.0)) / WorldData.STEP))
	var cx := floori(at.x)
	var cy := floori(at.y)
	if not _keeper_ground(world, cx, cy, tall):
		return 0
	# READ OFF A WINDOW (TileWindow), not through the world's methods a tile at a
	# time: that was the cost of every lair and every station's den (the frost
	# sea's soundings, 5-12 ms each). The same tiles in the same order, so the
	# same count; tests/sentinel/test_flood_plain.gd keeps the body this replaced
	# and holds the two equal.
	var size := world.size
	var win := TileWindow.of(world, cx - OPEN_TO, cy - OPEN_TO, cx + OPEN_TO + 1, cy + OPEN_TO + 1)
	var levels := win.level
	var grounds := win.ground
	var overhead := world.has_overhead()
	var side := OPEN_TO * 2 + 1
	var seen := PackedByteArray()
	seen.resize(side * side)
	seen[OPEN_TO * side + OPEN_TO] = 1
	var qx := PackedInt32Array([cx])
	var qy := PackedInt32Array([cy])
	var head := 0
	var n := 0
	while head < qx.size():
		var tx := qx[head]
		var ty := qy[head]
		head += 1
		if maxi(absi(tx - cx), absi(ty - cy)) >= OPEN_FROM:
			n += 1
		var level: int = levels[(ty - win.y0) * win.w + tx - win.x0]
		for k in 4:
			var ux := tx + (1 if k == 0 else (-1 if k == 1 else 0))
			var uy := ty + (1 if k == 2 else (-1 if k == 3 else 0))
			var lx := ux - cx + OPEN_TO
			var ly := uy - cy + OPEN_TO
			if lx < 0 or ly < 0 or lx >= side or ly >= side or seen[ly * side + lx] != 0:
				continue
			if ux < 0 or uy < 0 or ux >= size or uy >= size:
				continue
			var i := (uy - win.y0) * win.w + ux - win.x0
			var l: int = levels[i]
			if l < 0 or grounds[i] == Ground.DEEP_WATER or absi(l - level) > step \
					or (overhead and world.headroom_at(ux, uy) < tall):
				continue
			seen[ly * side + lx] = 1
			qx.append(ux)
			qy.append(uy)
	return n


## Ground a keeper `tall` levels high stands on: on the map, land or shallows,
## not deep water, and room over it.
static func _keeper_ground(world: WorldData, x: int, y: int, tall: int) -> bool:
	if not world.in_bounds(x, y) or world.level_at(x, y) < 0 or world.ground_at(x, y) == Ground.DEEP_WATER:
		return false
	return not world.has_overhead() or world.headroom_at(x, y) >= tall


## The nearest room to `centre` in the region, clear of home and off `avoid`,
## that its keeper gets out of (`_den_ok`), and with `ground_ways` where every way
## the ground answers holds; INF when none of ROOM_TRIES (twice that for the ways) spread
## over the region does.
static func _room_nearest(world: WorldData, region: Dictionary, def: SentinelDef, avoid: Array, centre: Vector2,
		landings: Array[Vector2] = [], ground_ways := false, near := false) -> Vector2:
	var id := int(region.get("id", -1))
	var bounds: Rect2 = region.get("bounds", Rect2())
	# The GROUND_CELL cells within its reach of its founder ground: a spot in no
	# such cell is never tried, which is most of a region and every flood saved.
	var close_cells := {}
	var sink := founders(def)
	if ground_ways and not sink.is_empty():
		var within := lure_reach(def) if near else def.reach
		var cells := _ground_cells(world, bounds.grow(within), sink)
		if cells.is_empty():
			return Vector2.INF
		var r := ceili(within / GROUND_CELL) + 1
		for c: Vector2i in cells:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					close_cells[c + Vector2i(dx, dy)] = true
	var spots: Array[Vector2] = []
	var y := floori(bounds.position.y)
	while y < int(bounds.end.y):
		var x := floori(bounds.position.x)
		while x < int(bounds.end.x):
			var p := Vector2(x + 0.5, y + 0.5)
			if not close_cells.is_empty() and not close_cells.has(Vector2i(x / GROUND_CELL, y / GROUND_CELL)):
				x += 3
				continue
			if world.region_at(x, y) == id and p.distance_to(world.spawn) >= CLEAR_OF_HOME and _room_at(world, x, y, 1.4, avoid):
				spots.append(p)
			x += 3
		y += 3
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(centre) < b.distance_squared_to(centre))
	# A spot beside one that failed is in the same pocket: passed over, so the
	# tries spread across the region instead of one plateau.
	var failed: Array[Vector2] = []
	var tries := ROOM_TRIES * (2 if ground_ways else 1)
	for p: Vector2 in spots:
		if failed.size() >= tries:
			break
		var near_failed := false
		for f: Vector2 in failed:
			if p.distance_to(f) < float(RAY_OUT) * 0.6:
				near_failed = true
				break
		if near_failed:
			continue
		if (not ground_ways or ways_closed(world, p, def, true, near).is_empty()) and _den_ok(world, p, def, landings):
			return p
		failed.append(p)
	return Vector2.INF


## The GROUND_CELL cells inside `rect` holding a tile of `grounds`, as a set of
## Vector2i; empty when `grounds` is. Read every other tile: it only says where
## a den is worth trying, and a patch FOUNDER_LEAST across is never missed.
const GROUND_CELL := 8


static func _ground_cells(world: WorldData, rect: Rect2, grounds: Array) -> Dictionary:
	var out := {}
	if grounds.is_empty():
		return out
	for y in range(maxi(0, floori(rect.position.y)), mini(world.size, ceili(rect.end.y)), 2):
		for x in range(maxi(0, floori(rect.position.x)), mini(world.size, ceili(rect.end.x)), 2):
			if grounds.has(world.ground_at(x, y)):
				out[Vector2i(x / GROUND_CELL, y / GROUND_CELL)] = true
	return out



## The grounds a design's FOUNDER way takes it on (none when it has no such way).
static func founders(def: SentinelDef) -> Array:
	for way: SentinelWay in def.ways:
		if way.kind == SentinelWay.FOUNDER:
			return way.grounds
	return []


## THE STATION RULE: a keeper dens only where every way its design declares can
## be done. Stations were chosen by what the plan built, and nothing asked the
## ways: seed 1's Reaper took an intake on a narrow inlet with no mud or wash it
## could be drawn onto, so its FOUNDER way was closed at its own den.
##   FORCE    nothing.
##   FOUNDER  FOUNDER_LEAST tiles of its grounds inside its reach that its own
##            move carries it onto from the den: a lure it cannot follow is none.
##            With `near`, inside what it sees from the den (`lure_reach`).
##   STARVE   its larder can be robbed out (`larder_robbable`).
##   SPOOF    inside its guard, one of the props it reads beside, and SPOOF_WATER
##            tiles the craft it reads off travels over.
## The ids of the ways closed at `at`; empty when it is kept. `ground_only` asks
## only what the ground answers (FOUNDER, a SPOOF's water): a work being laid
## asks that, its feeds and lamps not laid yet (GenWorks._work).
const FOUNDER_LEAST := 6
const SPOOF_WATER := 6


static func ways_closed(world: WorldData, at: Vector2, def: SentinelDef, ground_only: bool = false, near := false) -> Array[StringName]:
	var out: Array[StringName] = []
	for way: SentinelWay in def.ways:
		var open := true
		match way.kind:
			SentinelWay.FOUNDER:
				open = founder_tiles(world, at, def, FOUNDER_LEAST, lure_reach(def) if near else def.reach) >= FOUNDER_LEAST
			SentinelWay.STARVE:
				open = ground_only or larder_robbable(world, at, def)
			SentinelWay.SPOOF:
				var inside := guard(def)
				if way.aboard != &"":
					open = _craft_tiles(world, at, way.aboard, inside) >= SPOOF_WATER
				if open and not ground_only and not way.beside.is_empty():
					open = laid_near(world, at, way.beside, inside) > 0
		if not open:
			out.append(way.id())
	return out


## A keeper of `def` denned at `at` can be starved by robbing its works: at least
## SentinelWay.FEEDS_LEAST of its feeds inside FEED_SHARE of its reach, and none
## where a take is refused with it near (Senses.THREAT_RADIUS of the den, the
## number Survival.threat_near reads). Play counts every feed in reach and the
## way is won only when all are robbed, so one under its feet holds it shut: seed
## 1's Reaper at its intake, robbed 7 of 10 (tests/sentinel/test_ways.gd).
static func larder_robbable(world: WorldData, at: Vector2, def: SentinelDef) -> bool:
	return laid_near(world, at, def.feeds, def.reach * FEED_SHARE) >= SentinelWay.FEEDS_LEAST \
		and laid_near(world, at, def.feeds, Senses.THREAT_RADIUS, true) == 0


## How near a keeper lets anybody come: inside it, a signature is read (SPOOF)
## and the fight's wary body comes for whoever is there, by the one number.
static func guard(def: SentinelDef) -> float:
	return float(Roster.row(def.kind).get("sees", 12)) * Senses.WARY_INSIDE


## Tiles of its FOUNDER grounds inside `reach` (its own, unless asked nearer)
## that its move takes it onto from `at` (a flood under its move's rules, as
## `opens`), counted to `enough`.
static func founder_tiles(world: WorldData, at: Vector2, def: SentinelDef, enough: int = 1 << 30, reach: float = -1.0) -> int:
	return int(_founder_flood(world, at, def, enough, false, reach)[0])


## The nearest tile (by its move) of its FOUNDER grounds from `at` that stands in
## a patch of them a body's width across, inside its reach: where a lure draws it
## to founder (a tour's `near keeper_flats`). INF where there is none.
static func founder_spot(world: WorldData, at: Vector2, def: SentinelDef) -> Vector2:
	var u: Vector2i = _founder_flood(world, at, def, 1 << 30, true, -1.0)[1]
	return Vector2(u.x + 0.5, u.y + 0.5) if u.x >= 0 else Vector2.INF


## How far from its den a keeper of `def` sees a lure on the ground it founders
## in: its body's `sees`, inside what it holds. A den by the heart is sought with
## its founder ground this near first: seed 1's anvil denned 26 tiles from the
## nearest sand, inside its reach and past anything a lure could show it.
static func lure_reach(def: SentinelDef) -> float:
	return minf(def.reach, float(Roster.row(def.kind).get("sees", def.reach)))


## The flood `founder_tiles` and `founder_spot` share: [tiles counted to
## `enough`, the first tile in a 3x3 patch of the grounds when `patch`].
static func _founder_flood(world: WorldData, at: Vector2, def: SentinelDef, enough: int, patch: bool, within: float = -1.0) -> Array:
	var sink := founders(def)
	var start := Vector2i(floori(at.x), floori(at.y))
	if sink.is_empty() or not world.in_bounds(start.x, start.y):
		return [0, Vector2i(-1, -1)]
	var row := Roster.row(def.kind)
	var step := maxi(1, int(row.get("climbs", 1)))
	var tall := int(ceil(float(row.get("height", 1.0)) / WorldData.STEP))
	var reach := within if within >= 0.0 else def.reach
	var r2 := reach * reach
	var r := ceili(reach)
	# READ OFF A WINDOW (TileWindow), not through the world's methods, tile for
	# tile in the same order (tests/sentinel/test_flood_plain.gd keeps the body
	# this replaced): off the map is deep water, as `ground_at` says, and the sink
	# is a table rather than a list asked each tile.
	var size := world.size
	var win := TileWindow.of(world, start.x - r, start.y - r, start.x + r + 1, start.y + r + 1)
	var levels := win.level
	var grounds := win.ground
	var overhead := world.has_overhead()
	var sunk := PackedByteArray()
	sunk.resize(Ground.COUNT)
	for g: int in sink:
		sunk[g] = 1
	# None of the ground anywhere in reach: no flood. Most of a region's rooms are
	# this, and the room search asks dozens of them.
	var any := false
	for dy in range(-r, r + 1):
		var y := start.y + dy
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r2:
				continue
			var x := start.x + dx
			var g: int = grounds[(y - win.y0) * win.w + x - win.x0] if x >= 0 and y >= 0 and x < size and y < size else Ground.DEEP_WATER
			if sunk[g] != 0:
				any = true
				break
		if any:
			break
	if not any:
		return [0, Vector2i(-1, -1)]
	var side := r * 2 + 1
	var seen := PackedByteArray()
	seen.resize(side * side)
	seen[r * side + r] = 1
	var qx := PackedInt32Array([start.x])
	var qy := PackedInt32Array([start.y])
	var head := 0
	var n := 0
	while head < qx.size() and n < enough:
		var tx := qx[head]
		var ty := qy[head]
		head += 1
		var l: int = levels[(ty - win.y0) * win.w + tx - win.x0]
		for k in 4:
			var ux := tx + (1 if k == 0 else (-1 if k == 1 else 0))
			var uy := ty + (1 if k == 2 else (-1 if k == 3 else 0))
			var lx := ux - start.x + r
			var ly := uy - start.y + r
			if lx < 0 or ly < 0 or lx >= side or ly >= side or seen[ly * side + lx] != 0 \
					or ux < 0 or uy < 0 or ux >= size or uy >= size \
					or Vector2(ux + 0.5, uy + 0.5).distance_squared_to(at) > r2:
				continue
			seen[ly * side + lx] = 1
			var i := (uy - win.y0) * win.w + ux - win.x0
			var ul: int = levels[i]
			var g: int = grounds[i]
			if ul < 0 or g == Ground.DEEP_WATER or (overhead and world.headroom_at(ux, uy) < tall) or absi(ul - l) > step:
				continue
			if sunk[g] != 0:
				n += 1
				if patch and _all_of(world, Vector2i(ux, uy), sink):
					return [n, Vector2i(ux, uy)]
			qx.append(ux)
			qy.append(uy)
	return [n, Vector2i(-1, -1)]


## Every tile of the 3x3 round `u` is one of `grounds`.
static func _all_of(world: WorldData, u: Vector2i, grounds: Array) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not grounds.has(world.ground_at(u.x + dx, u.y + dy)):
				return false
	return true


const STEPS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Tiles inside `radius` of `at` that a craft of `kind` travels over.
static func _craft_tiles(world: WorldData, at: Vector2, kind: StringName, radius: float) -> int:
	var ride := CraftKinds.ride(kind)
	if ride == null:
		return 0
	var r := ceili(radius)
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := floori(at.x) + dx
			var y := floori(at.y) + dy
			if world.in_bounds(x, y) and Vector2(dx, dy).length() <= radius and ride.crosses(world.ground_at(x, y)):
				n += 1
	return n


## How many props generation laid of `kinds` within `radius` of `at` (or, with
## `square`, within it in Chebyshev distance): what the world was made with,
## never what play has robbed or set down since, because a den is fixed by the
## world (`lair`). Read from the sections the circle touches (WorldSections),
## never the whole world's props.
static func laid_near(world: WorldData, at: Vector2, kinds: Array, radius: float, square := false) -> int:
	var r2 := radius * radius
	var made := world.generated() if world.packed else world.prop_count()
	var lo := WorldSections.of(at - Vector2(radius, radius))
	var hi := WorldSections.of(at + Vector2(radius, radius))
	var n := 0
	for sy in range(lo.y, hi.y + 1):
		for sx in range(lo.x, hi.x + 1):
			_sections_lock.lock()
			var rows := WorldSections.rows_in(world, Vector2i(sx, sy))
			_sections_lock.unlock()
			for row: int in rows:
				if row >= made or not kinds.has(int(world.table.kind[row])):
					continue
				var q: Vector2 = world.table.pos[row]
				if (Senses.chebyshev(q, at) <= radius) if square else (q.distance_squared_to(at) <= r2):
					n += 1
	return n


## A world's section index is made on its first ask (WorldSections._index); the
## station rule asks while a realm is raised on a worker, so its asks take turns.
static var _sections_lock := Mutex.new()


## The nearest tile to `p` a body of this size can stand on, searched in rings, so
## a station laid on the shore does not put a keeper in the sea.
## Where a player a keeper has downed comes to: the edge of the ground round its
## lair that puts it out (PUT_OUT), EDGE_OUT tiles past it on the side they
## fell, or round from there until a body stands whole on ground joined to the
## lair's. Woken where they fell, it was put out again on top of a player at
## DOWNED_WAKE_HEALTH, and every try after the first was one bite long.
## INF where no such ground is (the caller leaves them where they fell).
const EDGE_OUT := 2.0


static func arena_edge(world: WorldData, query: WorldQuery, lair: Vector2, from: Vector2, radius: float, tall: int) -> Vector2:
	var toward := (from - lair).angle() if from.distance_to(lair) > 0.1 else 0.0
	for i in 24:
		var a := toward + float((i + 1) / 2) * (TAU / 24.0) * (1.0 if i % 2 == 0 else -1.0)
		var dir := Vector2.from_angle(a)
		# Out along the bearing until it is past the put-out square.
		var d := PUT_OUT + EDGE_OUT
		while Senses.chebyshev(lair + dir * d, lair) <= PUT_OUT + EDGE_OUT * 0.5:
			d += 1.0
		for k in 4:
			var p := lair + dir * (d + k)
			var tx := floori(p.x)
			var ty := floori(p.y)
			if query.standable(tx, ty) and not Ground.is_water(world.ground_at(tx, ty)) \
					and world.same_body(p, lair) and query.body_fits(p, radius, null, true, tall):
				return p
	return Vector2.INF


static func stand_near(world: WorldData, p: Vector2, radius: float = 1.4, avoid: Array = []) -> Vector2:
	var cx := floori(p.x)
	var cy := floori(p.y)
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if _room_at(world, x, y, radius, avoid):
					return Vector2(x + 0.5, y + 0.5)
	return Vector2(cx + 0.5, cy + 0.5)


## Room for a body of `radius` tiles: dry, on the map, the level within a step
## all round, so a machine three tiles wide is not stood astride a cliff, and none
## of it on the grounds in `avoid`.
static func _room_at(world: WorldData, x: int, y: int, radius: float, avoid: Array = []) -> bool:
	var r := maxi(1, ceili(radius))
	if not world.in_bounds(x - r, y - r) or not world.in_bounds(x + r, y + r):
		return false
	var level := world.level_at(x, y)
	if level < 1:
		return false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var g := world.ground_at(x + dx, y + dy)
			if Ground.is_water(g) or g == Ground.ROAD or avoid.has(g):
				return false
			if absi(world.level_at(x + dx, y + dy) - level) > 1:
				return false
	return true


## The props inside a keeper's reach that feed it: the plan's works, which a player
## can break or rob to leave it standing dark. Depleted ones do not count — that is
## the whole of how STARVE is reached.
static func feeds(world: WorldData, at: Vector2, def: SentinelDef) -> int:
	if world == null:
		return 0
	return feeds_among(world.each_prop(), at, def, world.depleted, def.reach * FEED_SHARE)


## The same over a list of props already gathered (`WorldQuery.props_near`), so a
## running game asks the spatial index instead of walking every prop in the world.
## Whether `prop` is a work a keeper of `world` feeds on (its design's `feeds`,
## within FEED_SHARE of its reach of its lair). Robbed out, such a work is gone
## from the world (Survival.finish_work: world.depleted), which is what the
## keeper's hunger counts; a kept take would leave it feeding it for ever.
static func feeds_a_keeper(world: WorldData, prop: WorldProp) -> bool:
	for s in states(world):
		var def := by_id(s.design)
		if def != null and def.feeds.has(prop.kind) and prop.pos.distance_to(s.lair) <= def.reach * FEED_SHARE:
			return true
	return false


static func feeds_among(props: Array, at: Vector2, def: SentinelDef, depleted: Dictionary, reach: float) -> int:
	if def.feeds.is_empty():
		return 0
	var n := 0
	for q: WorldProp in props:
		if not def.feeds.has(q.kind) or depleted.has(q.id):
			continue
		if q.pos.distance_to(at) <= reach:
			n += 1
	return n


# --- discovery --------------------------------------------------------------

static func _ensure() -> void:
	if not _defs.is_empty():
		return
	_lock.lock()
	if not _defs.is_empty():
		_lock.unlock()
		return
	var made: Array[SentinelDef] = []
	for path: String in _files():
		var script: GDScript = load(path)
		if script == null or not script.has_method(&"make"):
			continue
		var d: SentinelDef = script.call(&"make")
		if d != null:
			made.append(d)
	made.sort_custom(func(a: SentinelDef, b: SentinelDef) -> bool: return a.id < b.id)
	var defs := {}
	for d in made:
		defs[d.id] = d
	_order = made
	_defs = defs
	_lock.unlock()


static func _files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_error("Sentinels: no %s" % DIR)
		return out
	for f in dir.get_files():
		if f.ends_with(".gd.remap"):
			f = f.trim_suffix(".remap")
		if not f.ends_with(".gd"):
			continue
		out.append(DIR + "/" + f)
	out.sort()
	return out
