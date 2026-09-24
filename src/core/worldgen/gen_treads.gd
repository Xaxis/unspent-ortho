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
##           round its own treads, and one under the ankle -- appended.
##
## Reached by path (world_gen.gd preloads it), never by class_name.

const Treads := preload("res://src/core/colossus/colossus_treads.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

## The grid candidate centres are tried on, in tiles, and how far a pad's
## outline is sampled round (points on the rim circle) in the first pass.
const GRID := 12
## How many facings a foot is tried at, across SPLAY either side of the walk.
const YAWS := 5
const SPLAY := 0.55
const RING := 10
## Room kept between one tread's pads and another's.
const APART := 140.0


static func site(c: GenContext) -> void:
	var w := c.w
	var want: Array = Treads.wanted(w.seed_value, w.size)
	if want.is_empty():
		return
	var defs := {}
	for d: RefCounted in Def.walkers(w.size):
		defs[d.id] = d
	var taken: Array[Vector3] = []
	var built := _built(c)
	for row: Dictionary in want:
		var d: RefCounted = defs[row.walker]
		var found := _find(c, d, float(row.yaw), row.natural, taken, built)
		if found.x < 0.0:
			continue
		var at := Vector2(found.x, found.y)
		var yaw := found.z
		var pads := Treads.pads(d, at, yaw)
		var floor_l := _cut(c, pads, at)
		taken.append_array(pads)
		var region := w.region_at(floori(at.x), floori(at.y))
		w.landmarks.append({"kind": &"tread", "pos": at, "country": int(w.country[floori(at.y) * w.size + floori(at.x)]),
			"region": region, "walker": row.walker, "leg": int(row.leg), "j": int(row.j), "yaw": yaw,
			"floor": float(floor_l) * WorldData.STEP, "pads": pads,
			"half": Vector2.ONE * _extent(d)})


## The best centre for a foot facing `yaw`, or (-1, -1). Every pad's crater and
## rim must lie on land of one body, dry, off the roads and out of the villages,
## away from the spawn and from any other tread; of those, the flattest and
## highest (a crater needs ground to go down into), nearest the side the foot
## comes in from.
static func _find(c: GenContext, d: RefCounted, natural_yaw: float, natural: Vector2, taken: Array[Vector3], built: PackedByteArray) -> Vector3:
	var w := c.w
	var size := c.size
	var margin := int(_extent(d) + 4.0)
	var aim := Vector2(clampf(natural.x, margin, size - margin), clampf(natural.y, margin, size - margin))
	var home := w.continent[floori(w.spawn.y) * size + floori(w.spawn.x)]
	var scored: Array = []
	# The foot comes down facing the way the machine walks, toes ahead and heel
	# behind, turned out or in by as much as a foot is (`SPLAY`): the walk swings
	# it round to the tread's own yaw as it carries it (colossus_walk.gd
	# `plant_yaw`). The walk's own heading is preferred, by a little.
	for turn in YAWS:
		var yaw := natural_yaw + SPLAY * (float(turn) / float(YAWS - 1) * 2.0 - 1.0 if YAWS > 1 else 0.0)
		for y in range(margin, size - margin, GRID):
			for x in range(margin, size - margin, GRID):
				var centre := Vector2(x, y)
				if centre.distance_to(w.spawn) < _extent(d) + CLEAR_OF_SPAWN_PADS:
					continue
				var ci := y * size + x
				if c.land[ci] == 0 or c.water[ci] != 0:
					continue
				var body := w.continent[ci]
				var pads := Treads.pads(d, centre, yaw)
				var lo := 1 << 20
				var hi := -1
				var ok := true
				for p: Vector3 in pads:
					if not ok:
						break
					for q: Vector3 in taken:
						if Vector2(p.x, p.y).distance_to(Vector2(q.x, q.y)) < APART:
							ok = false
					if Vector2(p.x, p.y).distance_to(w.spawn) < Treads.CLEAR_OF_SPAWN:
						ok = false
					for s in RING + 1:
						if not ok:
							break
						var pt := Vector2(p.x, p.y)
						if s < RING:
							var a := TAU * float(s) / float(RING)
							pt += Vector2(cos(a), sin(a)) * Treads.rim_r(p)
						var i := floori(pt.y) * size + floori(pt.x)
						if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or built[i] != 0 or w.continent[i] != body:
							ok = false
							break
						var l := w.level[i]
						lo = mini(lo, l)
						hi = maxi(hi, l)
				# Flat enough that the strata come up to the ground inside the rim.
				if not ok or lo < 2 or hi - lo > FLAT:
					continue
				# Flat, and high enough to go down into; on the continent the player
				# wakes on, a walk from the spawn rather than across the sea; and
				# toward the side the foot comes in from, which only breaks ties.
				var score := -float(hi - lo) * 3.0 + 2.0 * minf(float(lo), 7.0) - centre.distance_to(aim) / 2000.0
				if body == home:
					score += 12.0 - absf(centre.distance_to(w.spawn) - WALK) / 60.0
				score -= absf(yaw - natural_yaw) * 1.5
				scored.append([score, centre, yaw])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	# The sieve samples each crater's outline; the whole of it is checked only
	# for the best few, in order, so one failing does not lose the rest.
	for i in mini(scored.size(), 80):
		if _clear(c, d, scored[i][1], scored[i][2], built):
			return Vector3(scored[i][1].x, scored[i][1].y, scored[i][2])
	return Vector3(-1, -1, 0)


## How far from the spawn a tread on the home continent would best be: out of
## sight of where a new game opens, and a short walk.
const WALK := 520.0


## The most a crater's ground may rise and fall across it, in levels: at DEPTH
## under the lowest and a level every STEP_W, the strata meet any ground within
## this of the lowest before the rim.
const FLAT := 10


## How far the ankle's centre stands from the spawn at the least, beyond the toes.
const CLEAR_OF_SPAWN_PADS := 120.0


## The whole of every crater, tile by tile, is dry land of one body, off roads
## and out of villages, and no higher than the strata can climb to inside the
## rim: the rim samples of `_find` are a sieve, this is the check.
static func _clear(c: GenContext, d: RefCounted, centre: Vector2, yaw: float, built: PackedByteArray) -> bool:
	var size := c.size
	var w := c.w
	var body := w.continent[floori(centre.y) * size + floori(centre.x)]
	var lowest := 1 << 20
	var highest := -1
	for p: Vector3 in Treads.pads(d, centre, yaw):
		var r := ceili(Treads.rim_r(p))
		var fr := Treads.floor_r(p)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var dd := dx * dx + dy * dy
				if dd > r * r:
					continue
				var x := floori(p.x) + dx
				var y := floori(p.y) + dy
				if x < 1 or y < 1 or x >= size - 1 or y >= size - 1:
					return false
				var i := y * size + x
				if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or built[i] != 0 or w.continent[i] != body:
					return false
				highest = maxi(highest, w.level[i])
				if float(dd) <= fr * fr:
					lowest = mini(lowest, w.level[i])
	var floor_l := maxi(1, lowest - Treads.DEPTH)
	return highest - floor_l <= int((Treads.RIM_R - Treads.FLOOR_R) / Treads.STEP_W) - LIP - 1


## Every tile something BUILT stands on or reaches over -- a placed prop as wide
## as a building (`BUILT_SOLID`), the plan's depots and the landmarks -- so no
## crater is cut through a house, a yard or a tower. What grew or was dropped is not here.
const BUILT_SOLID := 2.0
## How far past a depot's yard its parts and walls reach, and a margin.
const YARD_ROOM := 18.0
## How far round a landmark's own spot its model and cache reach, and a margin.
const LANDMARK_ROOM := 9.0
static func _built(c: GenContext) -> PackedByteArray:
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
	for p: WorldProp in w.props:
		# A building, a tank, a rig: something a pad could not come down on
		# without it being a story. Debris, stumps and posts are crushed.
		if p.kind in GenScatter.PLACED and p.solid >= BUILT_SOLID:
			mark.call(p.pos, p.solid + 1.0)
	# The plan's depots keep their ground and the room round it their parts and
	# walls stand in (Works.sites, derived from the marks this world was laid
	# with). A works mark with no yard on it, a tip, a bridge or a summit is not
	# in a pad's way: what was dug, dumped or grew where a pad comes down is
	# crushed, and the machines' own treads through their own fields is the
	# plan working.
	for site: WorksSite in Works.sites(w):
		mark.call(site.pos, Works.YARD + YARD_ROOM)
	# And the places worth the walk (Landmarks.sites, derived the same way): a
	# lighthouse or a tower standing in a crater is a model on ground that is no
	# longer there.
	for site: LandmarkSite in Landmarks.sites(w):
		mark.call(site.pos, LANDMARK_ROOM)
	return out


## Cut the three craters and return the floor's level, the SAME for all three:
## the foot is rigid, so its three pads stand at one height, DEPTH levels under
## the lowest ground any of them covers. Each is a floor as wide as the pad and
## a little more, stepped up out of it one level at a time -- the strata, which
## a body can climb -- to a rim of spoil one level over the land it fell on. The
## outline is not a drawn circle: it wanders a little with the bearing, as a
## thing pressed into ground does.
static func _cut(c: GenContext, pads: Array[Vector3], centre: Vector2) -> int:
	var w := c.w
	var size := c.size
	var lowest := 1 << 20
	for p: Vector3 in pads:
		var r := ceili(Treads.floor_r(p))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					lowest = mini(lowest, w.level[(floori(p.y) + dy) * size + floori(p.x) + dx])
	var floor_l := maxi(1, lowest - Treads.DEPTH)
	for pi in pads.size():
		var p: Vector3 = pads[pi]
		var r := ceili(Treads.rim_r(p)) + 1
		var fr := Treads.floor_r(p)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := floori(p.x) + dx
				var y := floori(p.y) + dy
				var i := y * size + x
				var off := Vector2(float(x) + 0.5 - p.x, float(y) + 0.5 - p.y)
				var a := off.angle()
				var wander := 1.0 + 0.05 * sin(a * 3.0 + float(pi) * 1.7 + float(c.s % 97)) + 0.03 * sin(a * 7.0 + float(pi))
				var dist := off.length() / wander
				if dist > Treads.rim_r(p):
					continue
				var was := w.level[i]
				# What the pad itself did, read off its own shape: its rim pressed a
				# ring of crushed, fresh-broken rock into the floor.
				var r_pad := off.length()
				var ring := absf(r_pad - p.z) < RING_WIDE
				# The strata: one level up for every STEP_W out from the floor's
				# edge, until they meet the ground as it was -- so however deep the
				# floor lies under this pad's own ground, every step out is one a
				# body can climb.
				var wall := floor_l + (0 if dist < fr else 1 + int((dist - fr) / Treads.STEP_W))
				if dist < fr:
					# The floor is pressed wherever it lies, cut down or not.
					w.level[i] = mini(was, floor_l)
					w.ground[i] = FRESH if ring else PRESSED
				elif wall < was:
					w.level[i] = wall
					w.ground[i] = Ground.SCREE
				elif wall - was < LIP:
					# The spoil it threw out: a lip one level over the ground just
					# past where the strata come up to it.
					w.level[i] = was + 1
					w.ground[i] = Ground.GRAVEL
	_gouge(c, pads, centre, floor_l)
	_press_ring(c, pads, centre)
	return floor_l


## THE CLAWS' GOUGES: two long raked trenches off each toe pad, dragged out ahead
## of it through the strata and the ground past the lip as the weight came on --
## what says, from above, that these pits are a foot's. One level below whatever
## they cross (a body steps into one and out of it), tapering to nothing, in the
## fresh-broken rock. The heel drags none: it comes down last and straight.
const GOUGE_LONG := 46.0
const GOUGE_WIDE := 2.4
const GOUGE_SPREAD := 0.28
static func _gouge(c: GenContext, pads: Array[Vector3], centre: Vector2, floor_l: int) -> void:
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
					if cut.has(i) or c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
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
## villages, and out of the craters it rings.
const PRESS_OUT := 8.0
const PRESS_WIDE := 2.2
static func _press_ring(c: GenContext, pads: Array[Vector3], centre: Vector2) -> void:
	var w := c.w
	var r := 0.0
	for p: Vector3 in pads:
		r = maxf(r, centre.distance_to(Vector2(p.x, p.y)) + Treads.rim_r(p))
	r += PRESS_OUT
	var ri := ceili(r + 4.0)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := floori(centre.x) + dx
			var y := floori(centre.y) + dy
			if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
				continue
			var off := Vector2(float(x) + 0.5 - centre.x, float(y) + 0.5 - centre.y)
			var a := off.angle()
			var want := r * (1.0 + 0.035 * sin(a * 5.0 + float(c.s % 31)) + 0.02 * sin(a * 11.0))
			if absf(off.length() - want) > PRESS_WIDE:
				continue
			var i := y * c.size + x
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or Ground.is_water(w.ground[i]):
				continue
			w.ground[i] = PRESSED


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
	for m: Dictionary in w.landmarks:
		if StringName(m.get("kind", &"")) != &"tread":
			continue
		var at: Vector2 = m.pos
		var pads: Array = m.pads
		var n := 0
		var first := w.props.size()
		for p: Vector3 in pads:
			# Crushed in the bowl: what stood where the pad came down, pressed
			# flat against the floor round the pad's edge -- plate and wreck, not
			# stone, because the land's own stone is the floor it is pressed into.
			for s in 5:
				var a := GenFields.h01(c.s, n, 7013, s) * TAU
				var r := float(p.z) + 0.6 + GenFields.h01(c.s, n, 7014, s) * 1.2
				_put(c, PropKind.WRECKAGE if s % 2 == 0 else PropKind.DEBRIS, Vector2(p.x, p.y) + Vector2(cos(a), sin(a)) * r)
			# Spoil on the rim: what it broke and threw out, and plate off the pad.
			# Placed kinds only (GenScatter.PLACED): a crater is cut in any
			# landscape, and a boulder belongs to the ones that grow them.
			for s in 7:
				var a := GenFields.h01(c.s, n, 7011, s) * TAU
				var r := Treads.floor_r(p) + Treads.STEP_W * float(Treads.DEPTH + 2) + GenFields.h01(c.s, n, 7012, s) * 4.0
				var q := Vector2(p.x, p.y) + Vector2(cos(a), sin(a)) * r
				_put(c, PropKind.WRECKAGE if s % 3 == 0 else PropKind.DEBRIS, q)
			n += 1
			# The plan keeps a survey post on the far side of every crater: it
			# measures its own footprint.
			var out := (Vector2(p.x, p.y) - at).normalized()
			_put(c, PropKind.SURVEY, Vector2(p.x, p.y) + out * (Treads.rim_r(p) + 5.0))
		# Under the ankle, between the toes, one more post: the only thing in
		# the arch a person's size.
		_put(c, PropKind.SURVEY, at + Vector2(3.0, -2.0))
		# What this stage laid is the tread's own and is never crushed by it
		# (19_colossi reads these ids).
		m["props"] = Vector2i(first, w.props.size())


static func _put(c: GenContext, kind: int, p: Vector2) -> void:
	var w := c.w
	var i := floori(p.y) * c.size + floori(p.x)
	if i < 0 or i >= c.n or w.level[i] <= 0 or Ground.is_water(w.ground[i]) or c.road[i] != 0:
		return
	var id := w.props.size()
	w.props.append(WorldProp.new(id, kind, p, GenFields.h01(c.s, id, kind, 77) * TAU, 0.8 + GenFields.h01(c.s, id, kind, 78) * 0.4))
