extends RefCounted
## THE CRATERS A COLOSSUS'S FEET HAVE MADE IN THE ISLAND (src/core/colossus/
## colossus_treads.gd says which plants come down here and why).
##
## RUN LAST, INTO A WORLD ALREADY LAID, so nothing any other stage placed moves
## by a tile or an id: a crater sited first reshuffled every later placer's
## draws and moved places across the whole island (the canon's burning, slums
## and moss frames were other places). Two halves:
##   `site`  finds each wanted plant a place three pads can stand in, clear of
##           anything built, lowers the land into three stepped craters with a
##           rim of what they threw out, lays their ground (bared rock, strata,
##           spoil) and writes the tread down. What GREW where a pad comes down
##           is not taken out here -- that would renumber every prop after it --
##           it is crushed at load by 19_colossi, from the tread, every time.
##   `dress` spoil and torn plate on the rims, the survey posts the plan keeps
##           round its own treads, one under the ankle, and the tread's people's
##           holding at the tread `site` marks theirs (`folk`) -- appended.
##
## Reached by path (world_gen.gd preloads it), never by class_name.

const Treads := preload("res://src/core/colossus/colossus_treads.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

## The grid candidate centres are tried on, in tiles.
const GRID := 8
## How many facings a foot is tried at, across SPLAY either side of the walk.
const YAWS := 5
const SPLAY := 0.55
## Room kept between one tread's pads and another's.
const APART := 140.0


static func site(c: GenContext) -> void:
	var w := c.w
	last_ring = PackedInt32Array()
	var want: Array = Treads.wanted(w.seed_value, w.size)
	if want.is_empty():
		return
	var defs := {}
	for d: RefCounted in Def.walkers(w.size):
		defs[d.id] = d
	var taken: Array[Vector3] = []
	# Closes whatever the stages before left open, so the marks below are ours.
	c.mark(&"treads.before")
	# Asked before any cut, so the world holds the landmarks sited on uncut land
	# for its life (Landmarks.sited): the ids `_trod` records name those.
	var bears := _bearing(c)
	var built := _built(c, bears)
	c.mark(&"treads.built")
	var no := _never(c, built)
	c.mark(&"treads.never")
	var clear := WorldGen.distance_field(_any(no, c.size), c.size)
	c.mark(&"treads.clearance")
	var tops := _tops(c)
	c.mark(&"treads.tops")
	var roads := WorldGen.distance_field(c.road, c.size)
	c.mark(&"treads.roads")
	var laid: PackedByteArray = GenFields.snapshot(w.ground)
	for i in want.size():
		var row: Dictionary = want[i]
		var d: RefCounted = defs[row.walker]
		var ranked: Array = []
		var found := _find(c, d, float(row.yaw), row.natural, taken, no, clear, tops, roads, i == 0, ranked)
		if found.x < 0.0:
			continue
		var at := Vector2(found.x, found.y)
		var yaw := found.z
		var pads := Treads.pads(d, at, yaw)
		var floor_l := _cut(c, pads, at, no)
		c.mark(&"treads.cut")
		taken.append_array(pads)
		var region := w.region_at(floori(at.x), floori(at.y))
		w.landmarks.append({"kind": &"tread", "pos": at, "country": int(w.country[floori(at.y) * w.size + floori(at.x)]),
			"region": region, "walker": row.walker, "leg": int(row.leg), "j": int(row.j), "yaw": yaw,
			"floor": float(floor_l) * WorldData.STEP, "pads": pads,
			"half": Vector2.ONE * _extent(d), "trod": _trod(w, pads, bears),
			"folk": i == 0, "rank": int(ranked.back())})
	# The strata climb a level per STEP_W and stop at the reach, so on land that
	# rises faster than that a cut ends in a step, and a road across it would
	# climb it. Graded again as settle grades every road.
	GenSettle.ease_roads(c)
	c.mark(&"treads.roads.eased")
	_tidy(c, laid, no)
	c.mark(&"treads.tidy")


## The ground a foot laid, tidied as GenSurface's was: the strata's scree meets
## the spoil's gravel along a contour of the old land, which is ragged tile by
## tile and draws as a staircase. Only what the feet changed may change, and the
## ground just round it, so the edge of a crater can meet the land it cut; roads,
## water and kept ground never do.
static func _tidy(c: GenContext, laid: PackedByteArray, no: PackedByteArray) -> void:
	var size := c.size
	var ground := c.w.ground
	var fixed := PackedByteArray()
	fixed.resize(c.n)
	fixed.fill(1)
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var i := y * size + x
			if ground[i] == laid[i]:
				continue
			for j: int in [i, i - 1, i + 1, i - size, i + size]:
				if no[j] == 0 and c.road[j] == 0:
					fixed[j] = 0
	for pass_i in 4:
		GenTidy.unnotch(ground, c.recipe, fixed, size)


## The best centre for a foot facing `yaw`, as (x, y, yaw), or x < 0; `ranked`
## takes how far down its list the place was found (the tread row's `rank`).
##
## EVERY WORLD OF THE SHIPPED SIZE CARRIES A FOOTPRINT (owner: the colossi must
## be impactful), so this searches the whole island and not a sample of it. One
## CLEARANCE field says how far every tile is from anything a tread may never
## cut -- sea and water, a village, a depot, a landmark -- and a pad passes the
## sieve where its floor lies inside it (L1 over-reads the true distance, so the
## sieve never refuses a place that fits). Props and roads are not in it: the
## tread crushes the one and carries the other (`_cut`). The exact question is
## `_fits`, run in order until one fits (FITS_ASKED_MOST).
##
## Of those: the `first` (the lame leg's) on leg 1's body near where he comes
## ashore (LEG1_FIRST), every other on the continent the player wakes on (a walk
## from the spawn, not across the sea), whenever any fits there; then with room for every pad's whole
## cut (`ROOMY`), so the first checked is the one that fits; then high enough to
## go down into, flat, and turned least from the walk's own heading.
static func _find(c: GenContext, d: RefCounted, natural_yaw: float, natural: Vector2, taken: Array[Vector3], no: PackedByteArray, clear: PackedFloat32Array, tops: PackedInt32Array, roads: PackedFloat32Array, first := false, ranked: Array = []) -> Vector3:
	var w := c.w
	var size := c.size
	var margin := int(_extent(d) + 4.0)
	var aim := Vector2(clampf(natural.x, margin, size - margin), clampf(natural.y, margin, size - margin))
	var home := w.continent_at(floori(w.spawn.x), floori(w.spawn.y))
	var leg1 := _landfall(w)
	var anchor: Vector2 = leg1.get("from", Vector2.INF)
	var leg1_id := int(leg1.get("id", -1)) if first else -1
	var bw := ceili(float(size) / TOP_BLOCK)
	var scored: Array = []
	for turn in YAWS:
		var yaw := natural_yaw + SPLAY * (float(turn) / float(YAWS - 1) * 2.0 - 1.0 if YAWS > 1 else 0.0)
		var offs: Array[Vector3] = Treads.pads(d, Vector2.ZERO, yaw)
		for y in range(margin, size - margin, GRID):
			for x in range(margin, size - margin, GRID):
				var ci := y * size + x
				if clear[ci] < 1.0:
					continue
				var centre := Vector2(x, y)
				var body := w.continent_at(x, y)
				var ok := true
				var lo := 1 << 20
				var hi := -1
				# How far each pad's cut could reach at most (the strata come up to
				# the highest ground near it) against how far its clearance goes:
				# where every pad has room, `_fits` passes without a scan.
				var room := INF
				var pad_room := PackedFloat32Array()
				for o: Vector3 in offs:
					var px := x + floori(o.x)
					var py := y + floori(o.y)
					var pi := py * size + px
					if clear[pi] < Treads.floor_r(o) or roads[pi] < o.z + 1.0 or w.continent_at(px, py) != body:
						ok = false
						break
					var pad := Vector2(px, py)
					if pad.distance_to(w.spawn) < reach_r(o) + SPAWN_ROOM:
						ok = false
						break
					# Where he comes ashore on leg 1 (GenBodies' landfall anchor, its slip and
					# the ring a raft lands in) is kept as where he wakes is.
					if anchor.is_finite() and pad.distance_to(anchor) < reach_r(o) + SPAWN_ROOM:
						ok = false
						break
					for q: Vector3 in taken:
						if pad.distance_to(Vector2(q.x, q.y)) < APART:
							ok = false
					var l := w.level[pi]
					lo = mini(lo, l)
					hi = maxi(hi, l)
					pad_room.append(clear[pi] * SQRT_HALF - WANDER_MOST * (Treads.floor_r(o) + Treads.STEP_W * float(tops[(py / TOP_BLOCK) * bw + px / TOP_BLOCK] + 1)))
				if not ok:
					continue
				# The floor lies DEPTH under the lowest ground the pads cover, a
				# little lower than their centres say: the strata climb from there.
				for pr: float in pad_room:
					room = minf(room, pr + WANDER_MOST * Treads.STEP_W * float(maxi(1, lo - Treads.DEPTH - 2)))
				var score := minf(float(lo), 7.0) - float(hi - lo) - centre.distance_to(aim) / 2000.0
				score += ROOMY if room >= 0.0 else room
				if body == leg1_id:
					score += LEG1_FIRST - centre.distance_to(anchor) / LEG1_NEAR
				elif body == home and leg1_id < 0:
					score += HOME_FIRST - absf(centre.distance_to(w.spawn) - WALK) / 60.0
				score -= absf(yaw - natural_yaw) * 1.5
				scored.append([score, centre, yaw])
	scored.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	c.mark(&"treads.score")
	for i in mini(scored.size(), FITS_ASKED_MOST):
		if _fits(c, d, scored[i][1], scored[i][2], no, clear, tops, roads):
			c.mark(&"treads.fits")
			ranked.append(i)
			return Vector3(scored[i][1].x, scored[i][1].y, scored[i][2])
	c.mark(&"treads.fits")
	# Nothing fits on leg 1's body: sited as every other tread is.
	if leg1_id >= 0:
		return _find(c, d, natural_yaw, natural, taken, no, clear, tops, roads, false, ranked)
	return Vector3(-1, -1, 0)


## What a place whose every pad has room for its whole cut (the clearance
## outreaches the strata) is worth over one that only might fit: more than
## height and flatness, less than the home continent.
const ROOMY := 40.0


## How much a place on the home continent is worth over one anywhere else: more
## than any difference of height or flatness can make up, so a footprint lands
## where the player can walk to it whenever one fits there at all.
const HOME_FIRST := 100.0
## THE FIRST TREAD IS ON LEG 1'S BODY, NEAR WHERE HE COMES ASHORE. The first
## wanted plant is the lame leg's, the one the climb goes up, and the story
## sends him to climb from leg 1 (the landfall body, StoryJourney): its crater
## (`crater:the_tread`) on the Covenant's body is a walk, not a second raft
## (StoryCrossing.to_walker). Scored home-first,
## on GEN 47's worlds of several bodies no crater stood on leg 1's on seeds 7, 3
## and 42, and the set piece was gone. So the first tread scores leg 1's body
## first, and on it the nearer the landfall anchor (where GenBodies says the
## water from home comes ashore) the better, LEG1_NEAR tiles to a point; where
## nothing fits there, it scores as every other tread does. Later treads keep
## the home continent first.
const LEG1_FIRST := 100.0
const LEG1_NEAR := 20.0


## The landfall body's row in `continents` (`landfall`, its `id` and `from`),
## or {} on a world of one body.
static func _landfall(w: WorldData) -> Dictionary:
	for r: Dictionary in w.continents:
		if bool(r.get("landfall", false)):
			return r
	return {}


## How many of the best-scored places are asked `_fits`, in order, at most: a
## tread that fits is found wherever it ranks, and a list where nothing fits is
## given up in bounded time. Asking only the best sixty lost seed 41's second
## tread when its place ranked 61st behind sixty that the strata's water or a
## pad's floor refused (#72); over twelve worlds at 1840 the deepest first fit
## is that 61st, and a refusal costs about 16 ms on a loaded box.
const FITS_ASKED_MOST := 300
## The most a crater's outline wanders out past its circle (`_cut`: 1 + 0.05 +
## 0.03, and a hair).
const WANDER_MOST := 1.09


## How far round a pad nothing may stand that a tread must never cut: its crater
## to the rim and the terraces `_cut` may carry past the rim to meet high ground.
static func reach_r(p: Vector3) -> float:
	return Treads.rim_r(p) + TERRACE


## Every tile a tread must never change: HARD (off the land, water of any kind)
## and KEPT (a village, a depot, a landmark). No pad's floor comes down on
## either. The strata may not cut hard ground -- water left standing over a cut
## is water hung in the air -- but where they meet kept ground they stop, and
## leave it standing on the edge of the crater over a face the foot sheared:
## never cut, and the crater still climbed out of the other way. A ROAD IS NOT HERE: a foot comes down across
## one, and `_cut` keeps it a road down the strata and out again, a level a
## tile, so it stays the way it promised to be (test_world_gen). Only the pad
## itself keeps off one (`_fits`), so every print reads as a print.
static func _never(c: GenContext, built: PackedByteArray) -> PackedByteArray:
	var no := PackedByteArray()
	no.resize(c.n)
	var size := c.size
	var land := c.land
	var water := c.water
	var village := c.village
	var level := c.w.level
	var ground := c.w.ground
	# A frost sea's leads are its ice opened, not standing water (BiomeDef.leads):
	# a foot comes down through them as through the sheet round them. Asked of
	# the RECIPE that laid the tile, so a lead its rules ran into the blend band
	# of the land next door is a lead too.
	var recipe := c.recipe
	var opened := PackedByteArray()
	opened.resize(256)
	for def: BiomeDef in BiomeRegistry.all():
		if def.leads:
			opened[def.index] = 1
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			var g := ground[i]
			if land[i] == 0 or water[i] != 0 or level[i] <= 0 \
					or g == Ground.DEEP_WATER or g == Ground.WATER or g == Ground.RIVER \
					or (g == Ground.BLACKWATER and opened[recipe[i]] == 0):
				no[i] = HARD
			elif village[i] != 0 or built[i] != 0:
				no[i] = KEPT
	)
	# A shaft's mouth is kept too: it was sited on this ground in every era.
	for shaft: Portal in c.w.shafts:
		var sx := floori(shaft.pos.x)
		var sy := floori(shaft.pos.y)
		for y in range(maxi(0, sy - Portals.HOLD), mini(size, sy + Portals.HOLD + 1)):
			for x in range(maxi(0, sx - Portals.HOLD), mini(size, sx + Portals.HOLD + 1)):
				if no[y * size + x] == 0:
					no[y * size + x] = KEPT
	# A village is kept to its whole radius, the clearing its people walk, not
	# only the core `GenSettle` marks: scree laid past the core is still scree in
	# the middle of a village (test_world_gen_surface).
	for v: Dictionary in c.w.villages:
		_keep(no, size, v.pos, v.radius)
	# THE WORKING PARTS ARE KEPT, not the land round them: a crater crushed into
	# the edge of the drowned city is a sight, its lock under a pad is a keeper
	# with nothing to keep. Each keeper's den keeps its reach (Sentinels.states:
	# the station it dens at, its larder, the ground its ways are done on); a
	# placed site (SiteKinds) keeps its radius and its walls, a slip its stair.
	# A tip is the plan's spoil and is crushed, as `_built` says.
	for s: SentinelState in Sentinels.states(c.w):
		var def := Sentinels.by_id(s.design)
		if def != null:
			_keep(no, size, s.lair, def.reach)
	for m: Dictionary in c.w.landmarks:
		var kind := StringName(m.get("kind", &""))
		if kind == &"slip":
			_keep(no, size, m.pos, (m.half as Vector2).length() + PLACE_ROOM)
		elif kind != &"tip" and SiteKinds.has(kind):
			_keep(no, size, m.pos, float(SiteKinds.row(kind).get("radius", 0.0)) + PLACE_ROOM)
	return no


## How far past a placed site's radius, or a slip's stair, its ground is kept:
## a flooded hall's walls stand HALL_WALL and half a block out of its floor.
const PLACE_ROOM := 4.0


static func _keep(no: PackedByteArray, size: int, p: Vector2, r: float) -> void:
	for y in range(maxi(0, floori(p.y - r)), mini(size, ceili(p.y + r) + 1)):
		for x in range(maxi(0, floori(p.x - r)), mini(size, ceili(p.x + r) + 1)):
			var i := y * size + x
			if no[i] == 0 and Vector2(x + 0.5, y + 0.5).distance_to(p) <= r:
				no[i] = KEPT


const HARD := 1
const KEPT := 2


## 1 wherever `no` is anything: what a pad's floor keeps off, as the mask
## `WorldGen.distance_field` reads.
static func _any(no: PackedByteArray, size: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(no.size())
	GenFields.rows(size, func(y0: int, y1: int) -> void:
		for i in range(y0 * size, y1 * size):
			if no[i] != 0:
				out[i] = 1
	)
	return out


## How far from the spawn a tread on the home continent would best be: out of
## sight of where a new game opens, and a short walk.
const WALK := 520.0


## How far past a crater's rim its terraces may be carried, cutting the ground
## down in steps a body can climb, until they meet ground that stands high over
## the floor. The stage writes the ground, so a site on a slope is terraced
## rather than refused.
const TERRACE := 30.0


## How far past its terraces a pad stays from where a new game opens, and from
## where he comes ashore on leg 1: he wakes and lands in sight of a footprint,
## never in one.
const SPAWN_ROOM := 40.0


## Whether a foot set down here changes nothing it may never change, and can be
## climbed out of: tile by tile over what `_cut` would really do. The floor
## must be off everything in `no`, every strata step that cuts the ground down
## off HARD ground and on the centre's body (KEPT ground stops the strata, and a
## spoil lip is simply left off such a tile); and
## by the end of the terraces the strata must have come up to the ground,
## within one step, so no crater ends in a cliff it cut.
##
## EXACT, BUT ONLY WHERE IT CAN MATTER. The strata climb a level every STEP_W,
## so past `fr + STEP_W * (top - floor + 1)` -- `top` the highest ground near
## the pad, off `tops` -- they stand over any ground there: nothing is cut and
## no cliff is left, and the scan stops at that radius. Where the clearance
## field already says nothing in `no` lies inside it (L1 distance over root 2
## is a floor on the true one), the pad is not scanned at all.
static func _fits(c: GenContext, d: RefCounted, centre: Vector2, yaw: float, no: PackedByteArray,
		clear: PackedFloat32Array, tops: PackedInt32Array, roads: PackedFloat32Array) -> bool:
	var size := c.size
	var w := c.w
	var body := w.continent_at(floori(centre.x), floori(centre.y))
	var pads := Treads.pads(d, centre, yaw)
	var floor_l := _floor_of(c, pads)
	if floor_l < 0:
		return false
	for p: Vector3 in pads:
		var reach := reach_r(p)
		var fr := Treads.floor_r(p)
		var px := floori(p.x)
		var py := floori(p.y)
		var top := tops[(py / TOP_BLOCK) * ceili(float(size) / TOP_BLOCK) + px / TOP_BLOCK]
		reach = minf(reach, fr + Treads.STEP_W * float(top - floor_l + 1) + 1.0)
		var r := ceili(reach * WANDER_MOST)
		if px - r < 1 or py - r < 1 or px + r >= size - 1 or py + r >= size - 1:
			return false
		var bounded := reach < reach_r(p) - 1.5
		if bounded and clear[py * size + px] * SQRT_HALF > reach * WANDER_MOST + 1.0 and roads[py * size + px] * SQRT_HALF > p.z + 1.0:
			continue
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var dd := dx * dx + dy * dy
				if float(dd) > reach * reach * WANDER_MOST * WANDER_MOST:
					continue
				var i := (py + dy) * size + px + dx
				var was := w.level[i]
				var dist := sqrt(float(dd))
				if dist < p.z + 1.0 and c.road[i] != 0:
					return false
				# The nearest the wandering outline of `_cut` can bring this tile.
				var near := dist / WANDER_MOST
				var wall := floor_l + (0 if near < fr else 1 + int((near - fr) / Treads.STEP_W))
				if near < fr and no[i] != 0:
					return false
				if wall < was and (no[i] == HARD or w.continent_at(px + dx, py + dy) != body):
					return false
				if not bounded and dist > reach_r(p) - 1.5 and was > wall + 1:
					return false
	return true


const SQRT_HALF := 0.70710678


## The side of a `tops` block, in tiles, and how many blocks out it looks: 96
## tiles, past the farthest a pad's cut reaches (`reach_r` * WANDER_MOST).
const TOP_BLOCK := 16
const TOP_REACH := 6


## The highest level within TOP_REACH blocks of each TOP_BLOCK square of the
## island (a square of blocks, so past any pad's reach): how high the ground
## round a pad can stand, without reading every tile.
static func _tops(c: GenContext) -> PackedInt32Array:
	var size := c.size
	var bw := ceili(float(size) / TOP_BLOCK)
	var out := PackedInt32Array()
	out.resize(bw * bw)
	var level := c.w.level
	# A band of block rows per job, so no two jobs write one block.
	GenFields.rows(bw, func(b0: int, b1: int) -> void:
		for y in range(b0 * TOP_BLOCK, mini(size, b1 * TOP_BLOCK)):
			var row := y * size
			var brow := (y / TOP_BLOCK) * bw
			for x in size:
				var k := brow + x / TOP_BLOCK
				var l := level[row + x]
				if l > out[k]:
					out[k] = l
	, 2)
	return _spread_max(_spread_max(out, bw, 1), bw, bw)


## The max over TOP_REACH blocks either side along one axis (`stride` 1 is
## along a row, `bw` down a column).
static func _spread_max(a: PackedInt32Array, bw: int, stride: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(a.size())
	var across := 1 if stride != 1 else bw
	for line in bw:
		for j in bw:
			var top := 0
			for o in range(maxi(0, j - TOP_REACH), mini(bw - 1, j + TOP_REACH) + 1):
				top = maxi(top, a[line * across + o * stride])
			out[line * across + j * stride] = top
	return out


## The floor all the pads stand at: DEPTH under the lowest ground any pad's
## floor covers, or -1 where a floor would lie off the map.
static func _floor_of(c: GenContext, pads: Array[Vector3]) -> int:
	var lowest := 1 << 20
	for p: Vector3 in pads:
		var r := ceili(Treads.floor_r(p))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy > r * r:
					continue
				var x := floori(p.x) + dx
				var y := floori(p.y) + dy
				if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
					return -1
				lowest = mini(lowest, c.w.level[y * c.size + x])
	return maxi(1, lowest - Treads.DEPTH)


## Every tile a tread must never cut: the plan's depots, the landmarks that
## carry load (`_bearing`) and the keepers' stations. A house, a wreck or a tank
## standing alone out on the land is crushed where a pad comes down (19_colossi,
## at load); a village is kept to its radius (`_never`).
## How far past a depot's yard its parts and walls reach, and a margin.
const YARD_ROOM := 18.0
## How far round a landmark's own spot its model and cache reach, and a margin.
const LANDMARK_ROOM := 9.0
## How far past a keeper's station's own footprint (its record's `half`) a pad
## keeps: its larder's runs (an intake's pipe) and a margin.
const STATION_ROOM := 8.0
static func _built(c: GenContext, bears: Dictionary) -> PackedByteArray:
	var w := c.w
	var out := PackedByteArray()
	out.resize(c.n)
	var mark := func(p: Vector2, r: float) -> void:
		var ri := ceili(r)
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var x := floori(p.x) + dx
				var y := floori(p.y) + dy
				if x >= 0 and y >= 0 and x < c.size and y < c.size:
					out[y * c.size + x] = 1
	# The plan's depots keep their ground and the room round it their parts and
	# walls stand in (Works.sites, derived from the marks this world was laid
	# with). A works mark with no yard on it, a tip, a bridge or a summit is not
	# in a pad's way: what was dug, dumped or grew where a pad comes down is
	# crushed, and the machines' own treads through their own fields is the
	# plan working.
	for site: WorksSite in Works.sites(w):
		mark.call(site.pos, Works.YARD + YARD_ROOM)
	# And the places worth the walk that carry load (Landmarks.sited, derived the
	# same way): kept, one stands at most on the crater's edge, over a face the
	# foot sheared. The rest yield to a foot (`_trod`).
	for site: LandmarkSite in Landmarks.sited(w):
		if bears.has(site.id):
			mark.call(site.pos, LANDMARK_ROOM)
	# And a keeper's first station, the work its larder is laid round (an
	# intake, a lock, a strike field; `Sentinels.lair` dens by it, and its STARVE
	# way is robbing what stands there): a pad on it crushes the way with the
	# works. Seed 1's lame walker came down on the glass's strike field and
	# crushed all nine of its rods. Its other stations (a hulk, a sea wall) are a
	# den's ground and nothing it eats, and crushed they cost no way.
	for m: Dictionary in w.landmarks:
		var land := BiomeRegistry.by_index(int(m.get("country", -1)))
		var keeper := Sentinels.for_land(land.id) if land != null else null
		if keeper != null and not keeper.stations.is_empty() and keeper.stations[0] == StringName(str(m.get("kind", &""))):
			var half: Vector2 = m.get("half", Vector2.ZERO)
			mark.call(m.pos as Vector2, maxf(half.x, half.y) + STATION_ROOM)
	return out


## THE LANDMARKS THAT CARRY THE WORLD'S LOAD, by id, from world facts alone: a
## kind a keeper may den at (a station), one that marks where he comes ashore (it
## wants the landfall: the clock), and one whose landscape keeps a room under it.
## Every other is colour, and a walker's foot may come down on it. The story is
## cast afterwards from the landmarks still standing (StoryCasting), and is never
## asked here (test_worldgen_casts_no_story). Kept from every landmark, the foot
## found no room at all on the Covenant's body on three seeds of five, the
## landmarks standing every hundred tiles or so with no pad's floor allowed
## within thirty of one.
static func _bearing(c: GenContext) -> Dictionary:
	var w := c.w
	var stations := {}
	for def: SentinelDef in Sentinels.all():
		for k: StringName in def.stations:
			stations[k] = true
	var out := {}
	for site: LandmarkSite in Landmarks.sited(w):
		var def := Landmarks.by_id(site.kind)
		var land := BiomeRegistry.by_index(w.country_at(floori(site.pos.x), floori(site.pos.y)))
		if stations.has(site.kind) or (def != null and def.wants == &"landfall") \
				or (land != null and land.interiors.has(StringName("landmark:%s" % site.kind))):
			out[site.id] = true
	return out


## The landmarks a tread's pads came down on (inside a rim, as 19_colossi
## crushes a prop), of those that carry no load: what stood there lies under the
## crater, and `Landmarks.sites` no longer stands it.
static func _trod(w: WorldData, pads: Array[Vector3], bears: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for site: LandmarkSite in Landmarks.sited(w):
		if bears.has(site.id):
			continue
		for p: Vector3 in pads:
			if site.pos.distance_to(Vector2(p.x, p.y)) < Treads.rim_r(p):
				out.append(site.id)
				break
	return out


## Cut the three craters and return the floor's level, the SAME for all three:
## the foot is rigid, so its three pads stand at one height, DEPTH levels under
## the lowest ground any of them covers. Each is a floor as wide as the pad and
## a little more, stepped up out of it one level at a time -- the strata, which
## a body can climb -- to a rim of spoil one level over the land it fell on. The
## outline is not a drawn circle: it wanders a little with the bearing, as a
## thing pressed into ground does.
static func _cut(c: GenContext, pads: Array[Vector3], centre: Vector2, no: PackedByteArray) -> int:
	var w := c.w
	var size := c.size
	var floor_l := _floor_of(c, pads)
	for pi in pads.size():
		var p: Vector3 = pads[pi]
		var r := ceili(reach_r(p)) + 1
		var fr := Treads.floor_r(p)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := floori(p.x) + dx
				var y := floori(p.y) + dy
				var i := y * size + x
				var off := Vector2(float(x) + 0.5 - p.x, float(y) + 0.5 - p.y)
				# The wander is never more than WANDER_MOST: past that, no bearing
				# can bring the tile inside, and the trig is not worth doing.
				if off.length() > reach_r(p) * WANDER_MOST:
					continue
				var a := off.angle()
				var wander := 1.0 + 0.05 * sin(a * 3.0 + float(pi) * 1.7 + float(c.s % 97)) + 0.03 * sin(a * 7.0 + float(pi))
				var dist := off.length() / wander
				if dist > reach_r(p):
					continue
				var was := w.level[i]
				var past_rim := dist > Treads.rim_r(p)
				if no[i] == KEPT or (no[i] == HARD and not (dist < fr or floor_l + 1 + int((dist - fr) / Treads.STEP_W) < was)):
					continue
				# What the pad itself did, read off its own shape: its rim pressed a
				# ring of crushed, fresh-broken rock into the floor.
				var r_pad := off.length()
				var ring := absf(r_pad - p.z) < RING_WIDE
				# The strata: one level up for every STEP_W out from the floor's
				# edge, until they meet the ground as it was -- so however deep the
				# floor lies under this pad's own ground, every step out is one a
				# body can climb.
				var wall := floor_l + (0 if dist < fr else 1 + int((dist - fr) / Treads.STEP_W))
				# A road it came down across is still the road: stamped down the
				# strata and out, a level a tile, never a spoil lip across it.
				var road := c.road[i] != 0
				if dist < fr:
					# The floor is pressed wherever it lies, cut down or not.
					w.level[i] = mini(was, floor_l)
					if not road:
						w.ground[i] = FRESH if ring else PRESSED
				elif wall < was:
					w.level[i] = wall
					if not road:
						w.ground[i] = Ground.SCREE
				elif past_rim or road:
					continue
				elif wall - was < LIP:
					# The spoil it threw out: a lip one level over the ground just
					# past where the strata come up to it.
					w.level[i] = was + 1
					w.ground[i] = Ground.GRAVEL
				else:
					continue
	c.mark(&"treads.cut.pits")
	_gouge(c, pads, centre, floor_l, no)
	c.mark(&"treads.cut.gouge")
	_press_ring(c, pads, centre, no)
	c.mark(&"treads.cut.ring")
	return floor_l


## THE CLAWS' GOUGES: two long raked trenches off each toe pad, dragged out ahead
## of it through the strata and the ground past the lip as the weight came on --
## what says, from above, that these pits are a foot's. One level below whatever
## they cross (a body steps into one and out of it), tapering to nothing, in the
## fresh-broken rock. The heel drags none: it comes down last and straight.
const GOUGE_LONG := 46.0
const GOUGE_WIDE := 2.4
const GOUGE_SPREAD := 0.28
static func _gouge(c: GenContext, pads: Array[Vector3], centre: Vector2, floor_l: int, no: PackedByteArray) -> void:
	var w := c.w
	var cut := {}
	for pi in pads.size() - 1:
		var p: Vector3 = pads[pi]
		var pc := Vector2(p.x, p.y)
		var toe := (pc - centre).angle()
		for side: float in [-1.0, 1.0]:
			var dir := Vector2.from_angle(toe + side * GOUGE_SPREAD)
			var from := pc + dir * (p.z - 1.0)
			var steps := int(GOUGE_LONG / 0.5)
			for s in steps:
				var t := float(s) / float(steps)
				var at := from + dir * (GOUGE_LONG * t)
				var half := GOUGE_WIDE * (1.0 - t * 0.8) * 0.5
				var norm := Vector2(-dir.y, dir.x)
				for q in 7:
					var o := (float(q) / 6.0 - 0.5) * 2.0 * half
					var pt := at + norm * o
					var x := floori(pt.x)
					var y := floori(pt.y)
					if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
						continue
					var i := y * c.size + x
					if cut.has(i) or no[i] != 0 or c.road[i] != 0:
						continue
					cut[i] = true
					w.level[i] = maxi(floor_l, w.level[i] - 1)
					w.ground[i] = FRESH


## THE PRESSURE RING round the whole sole: where the ground split as the foot's
## weight came onto it, a thin wandering line of the same pressed ground as the
## prints' floors, round all four together, ground only, so the four read as one
## foot. Pressed and not fresh-broken: the land round a tread is often bare rock
## already, and a pale line on it was measured at a few percent over the rock
## that was there (seed 7). Kept off water, roads and
## kept ground (a village to its radius), and out of the craters it rings.
const PRESS_OUT := 8.0
const PRESS_WIDE := 11.0
const PRESS_CORE := 2.0
## At most this share of the band's tiles is pressed: a broken band, not a line.
const PRESS_DENSE := 0.62
## The ring's blotches, cycles per tile, and the smallest patch it keeps.
const PRESS_BLOT := 0.09
const PRESS_SPECK := 8
static func _press_ring(c: GenContext, pads: Array[Vector3], centre: Vector2, no: PackedByteArray) -> void:
	var w := c.w
	var r := 0.0
	for p: Vector3 in pads:
		r = maxf(r, centre.distance_to(Vector2(p.x, p.y)) + Treads.rim_r(p))
	r += PRESS_OUT
	var ri := ceili(r + 4.0)
	var laid := PackedInt32Array()
	var was := PackedByteArray()
	# Laid in BLOTCHES off low-frequency noise, never a tile at a time: a scatter
	# of single tiles is salad to the land's own wash (test_world_gen_surface).
	var blot := GenFields.noise(c.s, 0x7E5D, PRESS_BLOT, 2)
	var tone := GenFields.noise(c.s, 0x7E5E, PRESS_BLOT * 0.7, 1)
	var r_lo := r * 0.945 - PRESS_WIDE
	var r_hi := r * 1.055 + PRESS_WIDE
	for dy in range(-ri, ri + 1):
		# Only the annulus the band can lie in, a row at a time: the square round
		# it is ten times the tiles.
		var ay := absf(float(dy)) - 1.5
		var out_x := sqrt(maxf(0.0, r_hi * r_hi - maxf(0.0, ay) * maxf(0.0, ay))) + 2.0
		var in_x := sqrt(maxf(0.0, r_lo * r_lo - (absf(float(dy)) + 1.5) * (absf(float(dy)) + 1.5))) - 2.0
		for dx in range(-ceili(out_x), ceili(out_x) + 1):
			if absf(float(dx)) < in_x:
				continue
			var x := floori(centre.x) + dx
			var y := floori(centre.y) + dy
			if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
				continue
			var off := Vector2(float(x) + 0.5 - centre.x, float(y) + 0.5 - centre.y)
			var len := off.length()
			if len < r * 0.945 - PRESS_WIDE or len > r * 1.055 + PRESS_WIDE:
				continue
			var a := off.angle()
			var want := r * (1.0 + 0.035 * sin(a * 5.0 + float(c.s % 31)) + 0.02 * sin(a * 11.0))
			var across := absf(len - want)
			if across > PRESS_WIDE:
				continue
			var i := y * c.size + x
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or no[i] == KEPT or Ground.is_water(w.ground[i]) or w.level[i] <= 0:
				continue
			# A broad band that thins out to either side in blotches, pressed
			# ground and scree: never the hard-edged even line a road is at map
			# scale.
			var keep := PRESS_DENSE * (1.0 - smoothstep(PRESS_CORE, PRESS_WIDE, across))
			if blot.get_noise_2d(x, y) * 0.5 + 0.5 > keep:
				continue
			# Nor on the shore: a band of scree along the water's edge is a beach
			# the land never had. Asked last: it is the dearest question here.
			if _shore(w, x, y):
				continue
			was.append(w.ground[i])
			w.ground[i] = PRESSED if tone.get_noise_2d(x, y) < 0.1 else Ground.SCREE
			laid.append(i)
	# What is left a speck by the fringe goes back to the ground it was. Flooded
	# on a local grid over the ring's square, not through dictionaries.
	var side := 2 * ri + 1
	var ox := floori(centre.x) - ri
	var oy := floori(centre.y) - ri
	var slot := PackedInt32Array()
	slot.resize(side * side)
	slot.fill(-1)
	for k in laid.size():
		slot[(laid[k] / c.size - oy) * side + laid[k] % c.size - ox] = k
	var seen := PackedByteArray()
	seen.resize(laid.size())
	var keep_i := PackedInt32Array()
	var part := PackedInt32Array()
	for k0 in laid.size():
		if seen[k0] != 0:
			continue
		seen[k0] = 1
		part.resize(0)
		part.append(k0)
		var h := 0
		while h < part.size():
			var k := part[h]
			h += 1
			var j := laid[k]
			var lx := j % c.size - ox
			var ly := j / c.size - oy
			for o in 4:
				var nx := lx + (1 if o == 0 else (-1 if o == 1 else 0))
				var ny := ly + (1 if o == 2 else (-1 if o == 3 else 0))
				if nx < 0 or ny < 0 or nx >= side or ny >= side:
					continue
				var kn := slot[ny * side + nx]
				if kn >= 0 and seen[kn] == 0 and w.ground[laid[kn]] == w.ground[j]:
					seen[kn] = 1
					part.append(kn)
		for k: int in part:
			if part.size() <= PRESS_SPECK:
				w.ground[laid[k]] = was[k]
			else:
				keep_i.append(laid[k])
	last_ring.append_array(keep_i)


## Every tile the pressure rings of the last world grown were laid on (a test
## asks what the ring did without guessing it back from the ground).
static var last_ring := PackedInt32Array()


static func _shore(w: WorldData, x: int, y: int) -> bool:
	for dy in range(-SHORE, SHORE + 1):
		for dx in range(-SHORE, SHORE + 1):
			var i := (y + dy) * w.size + x + dx
			if i >= 0 and i < w.level.size() and (w.level[i] <= 0 or Ground.is_water(w.ground[i])):
				return true
	return false


## Tiles from water within which the pressure ring is not laid.
const SHORE := 2


## How far out from the ankle's centre a foot's craters reach, at the most.
static func _extent(d: RefCounted) -> float:
	var out := 0.0
	for i: int in int(d.toes.size()):
		var t: Vector3 = d.toe(i)
		out = maxf(out, t.y + Treads.rim_r(Vector3(0, 0, t.z)) + PRESS_OUT + GOUGE_LONG * 0.5)
	return out


## How wide the spoil's lip is, in steps of the strata past where they meet the
## ground.
const LIP := 3
## The marks a pad leaves: its pressure ring, half as wide as this either side
## of its edge (the claws' gouges are `_gouge`'s).
const RING_WIDE := 1.4
## What the floor is: the ground a pad has pressed, dark and packed, the same in
## every landscape -- bared rock in a pale one read as ice or a pond -- and the
## fresh broken rock of its rings and its gouges, pale against it.
const PRESSED := Ground.CLINKER
const FRESH := Ground.ROCK


## What lies round a tread, appended after every other prop.
static func dress(c: GenContext) -> void:
	var w := c.w
	# Every tread's pads, so each lays nothing in another's craters: a crater is
	# crushed at load, but never the treads' own pieces (19_colossi), so a post
	# a second tread stood in the first one's crater stood there for good.
	var treads: Array[Dictionary] = []
	for m: Dictionary in w.landmarks:
		if StringName(m.get("kind", &"")) == &"tread":
			treads.append(m)
	for m: Dictionary in treads:
		var at: Vector2 = m.pos
		var pads: Array = m.pads
		var others: Array[Vector3] = []
		for o: Dictionary in treads:
			if o != m:
				for op: Vector3 in (o.pads as Array):
					others.append(op)
		var n := 0
		var first := w.props.size()
		for p: Vector3 in pads:
			# Crushed in the bowl: what stood where the pad came down, pressed
			# flat against the floor round the pad's edge -- plate and wreck, not
			# stone, because the land's own stone is the floor it is pressed into.
			for s in 5:
				var a := GenFields.h01(c.s, n, 7013, s) * TAU
				var r := float(p.z) + 0.6 + GenFields.h01(c.s, n, 7014, s) * 1.2
				_put(c, PropKind.WRECKAGE if s % 2 == 0 else PropKind.DEBRIS, Vector2(p.x, p.y) + Vector2(cos(a), sin(a)) * r, others)
			# Spoil on the rim: what it broke and threw out, and plate off the pad.
			# Placed kinds only (GenScatter.PLACED): a crater is cut in any
			# landscape, and a boulder belongs to the ones that grow them.
			for s in 7:
				var a := GenFields.h01(c.s, n, 7011, s) * TAU
				var r := Treads.floor_r(p) + Treads.STEP_W * float(Treads.DEPTH + 2) + GenFields.h01(c.s, n, 7012, s) * 4.0
				var q := Vector2(p.x, p.y) + Vector2(cos(a), sin(a)) * r
				_put(c, PropKind.WRECKAGE if s % 3 == 0 else PropKind.DEBRIS, q, others)
			n += 1
			# The plan keeps a survey post on the far side of every crater: it
			# measures its own footprint.
			var out := (Vector2(p.x, p.y) - at).normalized()
			_put(c, PropKind.SURVEY, Vector2(p.x, p.y) + out * (Treads.rim_r(p) + 5.0), others)
		# Under the ankle, between the toes, one more post: the only thing in
		# the arch a person's size.
		_put(c, PropKind.SURVEY, at + Vector2(3.0, -2.0), others)
		if bool(m.get("folk", false)):
			_holding(c, at, pads, float(m.yaw), others)
		# What this stage laid is the tread's own and is never crushed by it
		# (19_colossi reads these ids).
		m["props"] = Vector2i(first, w.props.size())


## THE TREAD'S PEOPLE'S HOLDING (docs/STORY.md: the walkers; Tull speaks for
## them), at the tread `site` marks theirs (`folk`: the lame leg's, wherever it
## came down), round the lip they stand on (Treads.folk_lip): a shack HOLD_SHACK out
## past it, turned to the crater they farm, and a fire and a bench between it and
## the lip, to one side of the line out so Tull's spot stays open. Colour, never
## load: nothing here is asked for by the story or the climb, and nothing here
## asks the story; the story casts `the_tread` from the row (StoryCasting).
static func _holding(c: GenContext, ankle: Vector2, pads: Array, yaw: float, others: Array[Vector3]) -> void:
	var lip := Treads.folk_lip(ankle, pads, yaw)
	var pad: Vector3 = pads[Treads.MIDDLE_TOE]
	var out := (lip - Vector2(pad.x, pad.y)).normalized()
	var side := Vector2(-out.y, out.x)
	_put(c, PropKind.SHACK, lip + out * HOLD_SHACK, others, (-out).angle())
	_put(c, PropKind.FIRE, lip + out * HOLD_FIRE + side * HOLD_ASIDE, others)
	_put(c, PropKind.BENCH, lip + out * HOLD_FIRE + side * (HOLD_ASIDE + 1.8), others)


## Tiles out from the lip to the shack and to the fire, and aside of the line out
## to the fire: the lip is FOLK_LIP_IN inside the rim, so the shack stands four
## past it and the fire just over it.
const HOLD_SHACK := 6.0
const HOLD_FIRE := 2.5
const HOLD_ASIDE := 1.5


## Nothing the foot throws lands in a village's own ground: the crater is sited
## clear of the clearings, but its spoil reaches past the rim, and a tread sited
## near one would drop plate in the square (seed 42, Chalkstone). Nor in another
## tread's craters (`others`, their pads), out to the rim.
static func _put(c: GenContext, kind: int, p: Vector2, others: Array[Vector3], rot := NAN) -> void:
	var w := c.w
	for op: Vector3 in others:
		if p.distance_to(Vector2(op.x, op.y)) < Treads.rim_r(op):
			return
	var i := floori(p.y) * c.size + floori(p.x)
	if i < 0 or i >= c.n or w.level[i] <= 0 or Ground.is_water(w.ground[i]) or c.road[i] != 0 or c.village[i] != 0:
		return
	for shaft: Portal in w.shafts:
		if maxf(absf(p.x - shaft.pos.x), absf(p.y - shaft.pos.y)) <= Portals.HOLD + 0.5:
			return
	var id := w.props.size()
	# Turn and scale from where it lies, as GenScatter._add's (S4b).
	var px := roundi(p.x * 256.0)
	var py := roundi(p.y * 256.0)
	var turn := rot if not is_nan(rot) else Rng.hash01(c.s, px, py, kind, 0, 77) * TAU
	w.props.append(WorldProp.new(id, kind, p, turn, 0.8 + Rng.hash01(c.s, px, py, kind, 0, 78) * 0.4))
