extends RefCounted
## THE CRATERS A COLOSSUS'S FEET HAVE MADE IN THE ISLAND (src/core/colossus/
## colossus_treads.gd says which plants come down here and why).
##
## Two halves, because what is cut into the land has to exist before anything is
## laid on it, and what is left lying round a crater is laid after everything
## else so no other placer's ids move:
##   `site`  after the land is settled and the roads cut, before sites, surface
##           and scatter: finds each wanted plant a place three pads can stand
##           in, lowers the land into three stepped craters with a rim of what
##           they threw out, lays their ground (bared rock, strata, spoil), keeps
##           every later placer out of them, and writes the tread down.
##   `dress` at the very end: spoil and torn plate on the rims, the survey posts
##           the plan keeps round its own treads, and one under the ankle --
##           appended, so every prop that already stood keeps its id.
##
## Reached by path (world_gen.gd preloads it), never by class_name.

const Treads := preload("res://src/core/colossus/colossus_treads.gd")
const Def := preload("res://src/core/colossus/colossus_def.gd")

## The grid candidate centres are tried on, in tiles, and how far a pad's
## outline is sampled round (points on the rim circle) in the first pass.
const GRID := 12
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
	for row: Dictionary in want:
		var d: RefCounted = defs[row.walker]
		var yaw: float = row.yaw
		var at := _find(c, d, yaw, row.natural, taken)
		if at.x < 0.0:
			continue
		var pads := Treads.pads(d, at, yaw)
		var floor_l := _cut(c, pads)
		taken.append_array(pads)
		var region := w.region_at(floori(at.x), floori(at.y))
		w.landmarks.append({"kind": &"tread", "pos": at, "country": int(w.country[floori(at.y) * w.size + floori(at.x)]),
			"region": region, "walker": row.walker, "leg": int(row.leg), "j": int(row.j), "yaw": yaw,
			"floor": float(floor_l) * WorldData.STEP, "pads": pads,
			"half": Vector2(Treads.RIM_R, Treads.RIM_R)})


## The best centre for a foot facing `yaw`, or (-1, -1). Every pad's crater and
## rim must lie on land of one body, dry, off the roads and out of the villages,
## away from the spawn and from any other tread; of those, the flattest and
## highest (a crater needs ground to go down into), nearest the side the foot
## comes in from.
static func _find(c: GenContext, d: RefCounted, yaw: float, natural: Vector2, taken: Array[Vector3]) -> Vector2:
	var w := c.w
	var size := c.size
	var margin := int(float(d.toe_reach) + Treads.RIM_R + 4.0)
	var aim := Vector2(clampf(natural.x, margin, size - margin), clampf(natural.y, margin, size - margin))
	var home := w.continent[floori(w.spawn.y) * size + floori(w.spawn.x)]
	var scored: Array = []
	for y in range(margin, size - margin, GRID):
		for x in range(margin, size - margin, GRID):
			var centre := Vector2(x, y)
			if centre.distance_to(w.spawn) < float(d.toe_reach) + CLEAR_OF_SPAWN_PADS:
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
						pt += Vector2(cos(a), sin(a)) * Treads.RIM_R
					var i := floori(pt.y) * size + floori(pt.x)
					if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or w.continent[i] != body:
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
			scored.append([score, centre])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	# The sieve samples each crater's outline; the whole of it is checked only
	# for the best few, in order, so one failing does not lose the rest.
	for i in mini(scored.size(), 60):
		if _clear(c, d, scored[i][1], yaw):
			return scored[i][1]
	return Vector2(-1, -1)


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
static func _clear(c: GenContext, d: RefCounted, centre: Vector2, yaw: float) -> bool:
	var size := c.size
	var w := c.w
	var body := w.continent[floori(centre.y) * size + floori(centre.x)]
	var lowest := 1 << 20
	var highest := -1
	for p: Vector3 in Treads.pads(d, centre, yaw):
		var r := ceili(Treads.RIM_R)
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
				if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or w.continent[i] != body:
					return false
				highest = maxi(highest, w.level[i])
				if float(dd) <= Treads.FLOOR_R * Treads.FLOOR_R:
					lowest = mini(lowest, w.level[i])
	var floor_l := maxi(1, lowest - Treads.DEPTH)
	return highest - floor_l <= int((Treads.RIM_R - Treads.FLOOR_R) / Treads.STEP_W) - LIP - 1


## Cut the three craters and return the floor's level, the SAME for all three:
## the foot is rigid, so its three pads stand at one height, DEPTH levels under
## the lowest ground any of them covers. Each is a floor as wide as the pad and
## a little more, stepped up out of it one level at a time -- the strata, which
## a body can climb -- to a rim of spoil one level over the land it fell on. The
## outline is not a drawn circle: it wanders a little with the bearing, as a
## thing pressed into ground does.
static func _cut(c: GenContext, pads: Array[Vector3]) -> int:
	var w := c.w
	var size := c.size
	var lowest := 1 << 20
	for p: Vector3 in pads:
		var r := ceili(Treads.FLOOR_R)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					lowest = mini(lowest, w.level[(floori(p.y) + dy) * size + floori(p.x) + dx])
	var floor_l := maxi(1, lowest - Treads.DEPTH)
	for pi in pads.size():
		var p: Vector3 = pads[pi]
		var r := ceili(Treads.RIM_R) + 1
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := floori(p.x) + dx
				var y := floori(p.y) + dy
				var i := y * size + x
				var off := Vector2(float(x) + 0.5 - p.x, float(y) + 0.5 - p.y)
				var a := off.angle()
				var wander := 1.0 + 0.05 * sin(a * 3.0 + float(pi) * 1.7 + float(c.s % 97)) + 0.03 * sin(a * 7.0 + float(pi))
				var dist := off.length() / wander
				if dist > Treads.RIM_R:
					continue
				var was := w.level[i]
				# The strata: one level up for every STEP_W out from the floor's
				# edge, until they meet the ground as it was -- so however deep the
				# floor lies under this pad's own ground, every step out is one a
				# body can climb.
				var wall := floor_l + (0 if dist < Treads.FLOOR_R else 1 + int((dist - Treads.FLOOR_R) / Treads.STEP_W))
				if wall < was:
					w.level[i] = wall
					c.site_ground[i] = Ground.ROCK + 1 if dist < Treads.FLOOR_R else Ground.SCREE + 1
				elif wall - was < LIP:
					# The spoil it threw out: a lip one level over the ground just
					# past where the strata come up to it.
					w.level[i] = was + 1
					c.site_ground[i] = Ground.GRAVEL + 1
				else:
					continue
				c.village[i] = 1
	return floor_l


## How wide the spoil's lip is, in steps of the strata past where they meet the
## ground.
const LIP := 3


## What lies round a tread, appended after every other prop.
static func dress(c: GenContext) -> void:
	var w := c.w
	for m: Dictionary in w.landmarks:
		if StringName(m.get("kind", &"")) != &"tread":
			continue
		var at: Vector2 = m.pos
		var pads: Array = m.pads
		var n := 0
		for p: Vector3 in pads:
			# Spoil on the rim: what it broke and threw out, and plate off the pad.
			# Placed kinds only (GenScatter.PLACED): a crater is cut in any
			# landscape, and a boulder belongs to the ones that grow them.
			for s in 7:
				var a := GenFields.h01(c.s, n, 7011, s) * TAU
				var r := Treads.FLOOR_R + Treads.STEP_W * float(Treads.DEPTH + 2) + GenFields.h01(c.s, n, 7012, s) * 4.0
				var q := Vector2(p.x, p.y) + Vector2(cos(a), sin(a)) * r
				_put(c, PropKind.WRECKAGE if s % 3 == 0 else PropKind.DEBRIS, q)
			n += 1
			# The plan keeps a survey post on the far side of every crater: it
			# measures its own footprint.
			var out := (Vector2(p.x, p.y) - at).normalized()
			_put(c, PropKind.SURVEY, Vector2(p.x, p.y) + out * (Treads.RIM_R + 5.0))
		# Under the ankle, between the toes, one more post: the only thing in
		# the arch a person's size.
		_put(c, PropKind.SURVEY, at + Vector2(3.0, -2.0))


static func _put(c: GenContext, kind: int, p: Vector2) -> void:
	var w := c.w
	var i := floori(p.y) * c.size + floori(p.x)
	if i < 0 or i >= c.n or w.level[i] <= 0 or Ground.is_water(w.ground[i]) or c.road[i] != 0:
		return
	var id := w.props.size()
	w.props.append(WorldProp.new(id, kind, p, GenFields.h01(c.s, id, kind, 77) * TAU, 0.8 + GenFields.h01(c.s, id, kind, 78) * 0.4))
