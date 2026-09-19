class_name Sentinels
## Every sentinel design the game knows, and the pure rules about where a keeper
## stands and what it holds (docs/VISION.md §3).
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


static func all() -> Array[SentinelDef]:
	_ensure()
	return _order.duplicate()


static func by_id(id: StringName) -> SentinelDef:
	_ensure()
	return _defs.get(id, null)


## The design the landscape type `land` keeps, read off its own file
## (`BiomeDef.sentinel`). Null when that landscape has no keeper yet.
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


## Its drop table and the one elite material only it gives (docs/VISION.md §6.1,
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
	# The sim's own one-shot second act belongs to ordinary machines; a keeper's
	# phases are these, and they are counted here.
	m.second_act = false


# --- where a keeper stands --------------------------------------------------

## One state per region whose landscape type has a keeper, biggest region first
## (the order `WorldData.regions` is in).
static func states(world: WorldData) -> Array[SentinelState]:
	var out: Array[SentinelState] = []
	if world == null:
		return out
	for r: Dictionary in world.regions:
		var def := for_land(StringName(str(r.get("type", &""))))
		if def == null or int(r.get("tiles", 0)) < MIN_TILES:
			continue
		var at := lair(world, r, def)
		if not at.is_finite():
			continue
		var s := SentinelState.new()
		s.region = int(r.get("id", -1))
		s.design = def.id
		s.land = def.land
		s.lair = at
		s.max_health = Roster.health_of(def.kind)
		s.health = s.max_health
		out.append(s)
	return out


## Where this region's keeper stands: the plan's own work inside the region (the
## first of the design's `stations` the region holds, in the order the design
## prefers them), else the region's heart. Deterministic: the same seed and the
## same region always put it in the same place, because a boss that moves between
## runs cannot be walked to twice.
## Vector2.INF when this region has nowhere to keep (see CLEAR_OF_HOME).
static func lair(world: WorldData, region: Dictionary, def: SentinelDef) -> Vector2:
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
	for want: StringName in def.stations:
		var best := Vector2.INF
		var best_works := -1
		for m: Dictionary in world.landmarks:
			if StringName(str(m.get("kind", &""))) != want:
				continue
			var p: Vector2 = m.get("pos", Vector2.ZERO)
			if world.region_at(floori(p.x), floori(p.y)) != id:
				continue
			var at := stand_near(world, p)
			if at.distance_to(home) < CLEAR_OF_HOME:
				continue
			var n := 0
			for w2: Dictionary in world.landmarks:
				if not w2.has("mark"):
					continue
				if (w2.get("pos", Vector2.ZERO) as Vector2).distance_to(at) <= feed:
					n += 1
			if n > best_works:
				best_works = n
				best = at
		if best.is_finite():
			return best
	var centre: Vector2 = region.get("centre", Vector2.ZERO)
	var heart := stand_near(world, centre)
	if heart.distance_to(home) >= CLEAR_OF_HOME:
		return heart
	# Nothing the plan built stands far enough out: the quietest ground in the
	# region that is, nearest its heart, so a keeper is still where its own land is.
	var bounds: Rect2 = region.get("bounds", Rect2())
	var best := Vector2.INF
	var best_d := INF
	var y := floori(bounds.position.y)
	while y < int(bounds.end.y):
		var x := floori(bounds.position.x)
		while x < int(bounds.end.x):
			if world.region_at(x, y) == id and _room_at(world, x, y, 1.4):
				var p := Vector2(x + 0.5, y + 0.5)
				var d := p.distance_to(centre)
				if p.distance_to(home) >= CLEAR_OF_HOME and d < best_d:
					best_d = d
					best = p
			x += 3
		y += 3
	return best


## The nearest tile to `p` a body of this size can stand on, searched in rings, so
## a station laid on the shore does not put a keeper in the sea.
static func stand_near(world: WorldData, p: Vector2, radius: float = 1.4) -> Vector2:
	var cx := floori(p.x)
	var cy := floori(p.y)
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if _room_at(world, x, y, radius):
					return Vector2(x + 0.5, y + 0.5)
	return Vector2(cx + 0.5, cy + 0.5)


## Room for a body of `radius` tiles: dry, on the map, and the level within a step
## all round, so a machine three tiles wide is not stood astride a cliff.
static func _room_at(world: WorldData, x: int, y: int, radius: float) -> bool:
	var r := maxi(1, ceili(radius))
	if not world.in_bounds(x - r, y - r) or not world.in_bounds(x + r, y + r):
		return false
	var level := world.level_at(x, y)
	if level < 1:
		return false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var g := world.ground_at(x + dx, y + dy)
			if Ground.is_water(g) or g == Ground.ROAD:
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
	return feeds_among(world.props, at, def, world.depleted, def.reach * FEED_SHARE)


## The same over a list of props already gathered (`WorldQuery.props_near`), so a
## running game asks the spatial index instead of walking every prop in the world.
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
