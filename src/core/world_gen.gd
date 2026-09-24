class_name WorldGen
## seed -> WorldData. Deterministic, no side effects, no nodes. Per-tile passes
## run in row bands on the WorkerThreadPool (GenFields.rows); results never
## depend on scheduling.
##
## Stages (src/core/worldgen/), each reading only what earlier ones wrote:
##   1. shape      GenShape      one island: peninsulas, bays, sea lochs, islets, sea on every edge
##   2. layout     GenCountries  countries as a journey north from the south coast, balanced shares
##   3. relief     GenRelief     float elevation per country; beaches, dunes, sea cliffs, stacks, caldera
##   4. tiles      GenCountries  country per tile, shares rebalanced, enclaves folded in, ecotones
##   5. rivers     GenWater      drainage from high ground to the sea, beds and valleys
##   6. terrace    GenRelief     integer levels
##   7. still      GenWater      round blackwater pools, frozen tarns
##   8. settle     GenSettle     villages (middles levelled), roads (graded, bridged), spawn
##   9. access     GenAccess     scree breaches so every region can be walked to
##  10. sites      GenScatter    tips, circles, ruins, fumaroles, summits, falls
##  11. surface    GenSurface    grounds as washes from walk-scale fields; GenTidy takes out specks and stairs
##  12. props      GenScatter    wrecks, villages, the spawn's first frame, landmarks, the grid, scatter

const DEFAULT_SIZE := Tuning.WORLD_SIZE
const GenTreads := preload("res://src/core/worldgen/gen_treads.gd")
const MAX_LEVEL := GenRelief.MAX_LEVEL

## Milliseconds per stage of the most recent generate() (for tools and tests).
static var last_timings: Dictionary = {}


## `until` = &"tiles" stops once every tile has its country (the layout is
## final by then; country2 and blend are not filled): for tests that only
## need shares.
## `realm` is which realm's world this is (Realm.SURFACE by default): it decides
## which landscape types may be laid, and nothing else here knows about it.
static func generate(seed_value: int, size: int = DEFAULT_SIZE, until: StringName = &"", realm: StringName = &"surface") -> WorldData:
	var w := WorldData.new(seed_value, size)
	w.realm = realm
	var c := GenContext.new(w)
	# What the world is MADE of, before a tile of it exists (docs/DESIGN.md). The
	# size asked for is a ceiling: at every size this project currently uses it
	# comes back one body, which is the island that has always been here.
	c.bodies = GenBodies.plan(seed_value, realm, size).bodies
	# A place is measured against the BODY it stands on, never against the square.
	var share := 1.0
	for body: Dictionary in c.bodies:
		share = minf(share, float(body.get("share", 1.0)))
	c.body_k = c.k * sqrt(clampf(share, 0.01, 1.0))
	# A REALM NOBODY HAS BUILT IS EMPTY, NOT A FAKE OF ANOTHER ONE. `land_types` is
	# the types whose `BiomeDef.realms` names this realm, and for `orbital` and
	# `era` there are none yet. Asked for one anyway, the stages downstream fall
	# back on defaults — `Country.COAST` is index 1 and a great many readers reach
	# for it when unsure — and what came out was a plausible little island with
	# eleven regions, six villages and 378 props, labelled `orbital`. A world that
	# is convincingly the wrong thing is worse than one that is nothing, because
	# nothing announces itself and this did not: it passed every test that asks
	# whether a world generates.
	if c.land_types.is_empty():
		push_error("no landscape declares BiomeDef.realms = [&\"%s\"], so that realm has no world to grow" % realm)
		for i in w.level.size():
			w.level[i] = -1
		return w
	var t := Time.get_ticks_usec()
	var marks := {}
	c.mark(&"start")
	GenShape.run(c)
	# WHICH BODY EACH TILE IS ON, BEFORE ANYTHING IS LAID ON IT. It ran at the end
	# when all it had to do was record; the dealer needs it here, because "may this
	# landscape stand on THIS continent" cannot be asked of a world that does not
	# yet know where its continents are (docs/DESIGN.md).
	GenBodies.run(c)
	t = _mark(c, marks, &"shape", t)
	if _halted(w):
		return w
	GenCountries.coarse(c)
	t = _mark(c, marks, &"layout", t)
	if _halted(w):
		return w
	GenRelief.run(c)
	t = _mark(c, marks, &"relief", t)
	if _halted(w):
		return w
	GenCountries.fine(c, until != &"tiles")
	t = _mark(c, marks, &"tiles", t)
	if _halted(w):
		return w
	if until == &"tiles":
		var level := w.level
		var land := c.land
		GenFields.rows(size, func(y0: int, y1: int) -> void:
			for i in range(y0 * size, y1 * size):
				level[i] = 1 if land[i] != 0 else -1
		)
		last_timings = marks
		return w
	GenWater.rivers(c)
	t = _mark(c, marks, &"rivers", t)
	if _halted(w):
		return w
	GenRelief.terrace(c)
	t = _mark(c, marks, &"terrace", t)
	if _halted(w):
		return w
	# Before anything is sited: a strait that goes deep here can never drown a
	# village, a road or a site that was put on it.
	GenBodies.deepen_straits(c)
	t = _mark(c, marks, &"straits", t)
	if _halted(w):
		return w
	GenWater.still(c)
	t = _mark(c, marks, &"still", t)
	if _halted(w):
		return w
	GenSettle.villages(c)
	c.mark(&"settle.villages")
	GenSettle.roads(c)
	c.mark(&"settle.roads")
	GenSettle.spawn(c)
	# Which continent he wakes on, once there is a spawn to read it from.
	GenBodies.mark_home(c)
	t = _mark(c, marks, &"settle", t)
	if _halted(w):
		return w
	GenAccess.run(c)
	t = _mark(c, marks, &"access", t)
	if _halted(w):
		return w
	# Where a colossus's feet come down: cut before anything is sited or laid,
	# so every placer after it keeps out of the craters (gen_treads.gd).
	GenTreads.site(c)
	t = _mark(c, marks, &"treads", t)
	if _halted(w):
		return w
	GenScatter.sites(c)
	c.mark(&"surface.sites")
	GenSurface.run(c)
	t = _mark(c, marks, &"surface", t)
	if _halted(w):
		return w
	GenScatter.props(c)
	GenTreads.dress(c)
	t = _mark(c, marks, &"props", t)
	if _halted(w):
		return w
	w.rivers = c.rivers
	# The mask every placing stage sited against, and the recipe every tile's
	# ground and scatter came out of: kept so anything outside worldgen can ask
	# the questions the stages asked, instead of guessing from the ground or from
	# whose land a tile is on.
	w.road = c.road
	w.recipe = c.recipe
	var total := 0.0
	for k: StringName in marks:
		total += marks[k]
	marks[&"total"] = total
	last_timings = marks
	last_detail = c.timings
	return w


## Finer marks inside stages (GenContext.mark) from the most recent generate().
static var last_detail: Dictionary = {}


## WORLDS NOBODY WANTS ANY MORE. A background raise (RealmWorlds) cannot be
## killed, and a game that ended used to wait out a whole world on one worker --
## minutes on a slow machine, and a quit that hangs. `halt` asks a generation of
## this seed, size and realm to stop at its next stage; what it hands back then is
## unfinished and its caller throws it away. `unhalt` lets the same world be grown
## again for real.
static var _halt_lock := Mutex.new()
static var _halts: Dictionary = {}


static func halt(seed_value: int, size: int, realm: StringName) -> void:
	_halt_lock.lock()
	_halts["%d:%d:%s" % [seed_value, size, realm]] = true
	_halt_lock.unlock()


static func unhalt(seed_value: int, size: int, realm: StringName) -> void:
	_halt_lock.lock()
	_halts.erase("%d:%d:%s" % [seed_value, size, realm])
	_halt_lock.unlock()


static func _halted(w: WorldData) -> bool:
	_halt_lock.lock()
	var h: bool = not _halts.is_empty() and _halts.has("%d:%d:%s" % [w.seed_value, w.size, w.realm])
	_halt_lock.unlock()
	return h


static func _mark(c: GenContext, marks: Dictionary, name: StringName, t0: int) -> int:
	c.mark(StringName(String(name) + ".rest"))
	var t := Time.get_ticks_usec()
	marks[name] = (t - t0) / 1000.0
	return t


## Chamfer distance in tiles from each tile to the nearest tile at level <= 0.
static func distance_to_sea(w: WorldData) -> PackedFloat32Array:
	var solid := PackedByteArray()
	solid.resize(w.size * w.size)
	for i in solid.size():
		solid[i] = 1 if w.level[i] <= 0 else 0
	return distance_field(solid, w.size)


## 4-neighbour chamfer distance to the nearest cell where mask == 1: exactly
## the city-block distance, which separates into a pass along every row and
## then along every column, each row or column on its own, so it runs on the
## worker pool.
static func distance_field(mask: PackedByteArray, size: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(size * size)
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for y in range(y0, y1):
			var row := y * size
			var v := 1e9
			for x in size:
				v = 0.0 if mask[row + x] == 1 else v + 1.0
				d[row + x] = v
			v = 1e9
			for x in range(size - 1, -1, -1):
				v = minf(d[row + x], v + 1.0)
				d[row + x] = v
	)
	GenFields.rows(size, func(x0: int, x1: int) -> void:
		for x in range(x0, x1):
			var v := 1e9
			for y in size:
				var i := y * size + x
				v = minf(d[i], v + 1.0)
				d[i] = v
			v = 1e9
			for y in range(size - 1, -1, -1):
				var i := y * size + x
				v = minf(d[i], v + 1.0)
				d[i] = v
	)
	return d
