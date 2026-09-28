class_name SlotDoors
extends RefCounted
## WHERE THE SLOT LABYRINTH'S ROOMS HAVE THEIR DOORS (docs/MIDDENS_ROOMS.md,
## "Recipes against the labyrinth as built"). Derived from the seed's slot plan
## (GenSlots) and the finished land, never written into either, so nothing here
## moves a seed. Two kinds of site, for any landscape whose relief cuts `slots`:
##
##   alleys(w)  a door at the end of each blind alley that meets a face tall
##              enough for a door: the alley runs into the heap and stops there
##   rooms(w)   a mouth in the wall of a junction room, at most one to a patch
##              of CELL x CELL blocks, the room with most ways in and then the
##              widest
##
## Each site is [face point, out direction, landscape index], and an alley's a
## fourth: where a crawl up through the heap from behind its door comes out on
## the plateau (`exit_beside`), or INF where there is no plateau for one. A face
## is found on the TILES, not the plan: the warp moves the land under the plan,
## and about half of the planned alley ends meet no face within reach.

## Levels a face must rise in one step to hold a door: a container's end door is
## 2.5 units, five levels.
const FACE_LEVELS := 5
## Tiles walked along an alley past a point three short of its planned end.
const ALLEY_SHORT := 3.0
const ALLEY_REACH := 9.0
## Blocks on a side of the patch that holds at most one settlement.
const CELL := 4
## Tiles past a room's radius a face is looked for.
const ROOM_REACH := 5.0
const ROOM_SALT := 0x5E77
## A crawl exit comes up this far to the side of the alley's axis at the face's
## top, onto a plateau that runs on at least EXIT_RUN tiles that way: straight
## behind an alley's end is the next node's floor (measured: 0 of 30 faces had
## 4 plateau tiles behind them, and 24 of 30 had 4+ to one side).
const EXIT_SIDE := 3.5
const EXIT_RUN := 4
const EXIT_LOOK := 12

## Per world OBJECT: its plan (GenSlots.node does not answer blind alleys).
static var _plans: Dictionary = {}


static func alleys(w: WorldData) -> Array:
	var out: Array = []
	var plan := _plan(w)
	if plan == null:
		return out
	var pw := plan.width
	for k in plan.centre.size():
		var gx := k % pw
		var gy := k / pw
		for side in 2:
			var f := plan.east_stub[k] if side == 0 else plan.south_stub[k]
			if f == 0.0:
				continue
			var other := k + (1 if side == 0 else pw)
			if other >= plan.centre.size() or (side == 0 and gx >= pw - 1) or (side == 1 and gy >= pw - 1):
				continue
			var a := plan.centre[k] if f > 0.0 else plan.centre[other]
			var b := plan.centre[other] if f > 0.0 else plan.centre[k]
			var dir := (b - a).normalized()
			var end := a + (b - a) * absf(f)
			var land := _slot_land(w, end)
			if land < 0:
				continue
			var face := face_along(w, end - dir * ALLEY_SHORT, dir, ALLEY_REACH)
			if face.is_finite() and _slot_land(w, face + dir * 0.5) == land \
					and not _on_ramp(plan, [k, other], face - dir * Threshold.FACE_OUT):
				out.append([face, -dir, land, exit_beside(w, face, dir, land)])
	return out


static func rooms(w: WorldData) -> Array:
	var out: Array = []
	var plan := _plan(w)
	if plan == null:
		return out
	var pw := plan.width
	var best := {}
	for k in plan.centre.size():
		if plan.degree[k] < 3:
			continue
		var c := plan.centre[k]
		var land := _slot_land(w, c)
		if land < 0:
			continue
		var gx := k % pw
		var gy := k / pw
		var cell := Vector2i(gx / (GenSlots.BLOCK * CELL), gy / (GenSlots.BLOCK * CELL))
		var score := float(plan.degree[k]) * 100.0 + plan.radius[k] + Rng.hash01(w.seed_value, gx, gy, ROOM_SALT) * 0.01
		var dirs := _room_dirs(plan, k, gx, gy, w.seed_value)
		for d: Vector2 in dirs:
			var face := face_along(w, c, d, plan.radius[k] + ROOM_REACH)
			if not face.is_finite() or _slot_land(w, face + d * 0.5) != land:
				continue
			var near: Array[int] = [k]
			for n: int in [k - 1, k + 1, k - pw, k + pw]:
				if n >= 0 and n < plan.centre.size():
					near.append(n)
			if _on_ramp(plan, near, face - d * Threshold.FACE_OUT):
				continue
			if not best.has(cell) or float(best[cell][0]) < score:
				best[cell] = [score, face, -d, land]
			break
	var cells := best.keys()
	cells.sort()
	for cell: Vector2i in cells:
		var e: Array = best[cell]
		out.append([e[1], e[2], e[3]])
	return out


## Where, walking from `from` along `dir` in quarter tiles for up to `reach`, the
## land first rises FACE_LEVELS or more in one step: the face point, on the
## boundary between the floor tile and the face tile. INF where none.
static func face_along(w: WorldData, from: Vector2, dir: Vector2, reach: float) -> Vector2:
	var prev := w.level_at(floori(from.x), floori(from.y))
	var last := from
	var t := 0.0
	while t < reach:
		t += 0.25
		var p := from + dir * t
		var l := w.level_at(floori(p.x), floori(p.y))
		if l - prev >= FACE_LEVELS:
			return (last + p) * 0.5
		prev = l
		last = p
	return Vector2.INF


## Where a crawl from behind a face door at `face` (the alley running along
## `dir` into it) comes up: EXIT_SIDE to the side of the axis just over the
## face's top, on the side where the plateau runs on further, if it runs at least
## EXIT_RUN tiles there at the face's height or above, in the same landscape.
## INF where neither side does.
static func exit_beside(w: WorldData, face: Vector2, dir: Vector2, land: int) -> Vector2:
	var over := face + dir * 0.5
	var top := w.level_at(floori(over.x), floori(over.y))
	var side := Vector2(-dir.y, dir.x)
	var best := Vector2.INF
	var most := EXIT_RUN - 1
	for s: float in [1.0, -1.0]:
		var at := over + side * (s * EXIT_SIDE)
		var run := 0
		for n in EXIT_LOOK:
			var p := at + side * (s * float(n))
			var tx := floori(p.x)
			var ty := floori(p.y)
			if not w.in_bounds(tx, ty) or w.country_at(tx, ty) != land or w.level_at(tx, ty) < top - 1 \
					or Ground.is_water(w.ground_at(tx, ty)):
				break
			run += 1
		if run > most:
			most = run
			best = Vector2(floorf(at.x) + 0.5, floorf(at.y) + 0.5)
	return best


## A room's mouth: toward its one closed side if it has one, else round its
## diagonals from one the seed picks, so a four-way room is not always opened
## the same way.
static func _room_dirs(plan: GenSlots, k: int, gx: int, gy: int, s: int) -> Array[Vector2]:
	var pw := plan.width
	var open: Array[bool] = [
		gx < pw - 1 and plan.east[k] != 0, gy < pw - 1 and plan.south[k] != 0,
		gx > 0 and plan.east[k - 1] != 0, gy > 0 and plan.south[k - pw] != 0,
	]
	var sides: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var out: Array[Vector2] = []
	for q in 4:
		if not open[q]:
			out.append(sides[q])
	var first := floori(Rng.hash01(s, gx, gy, ROOM_SALT + 1) * 4.0)
	for i in 4:
		out.append(Vector2.from_angle(PI * 0.25 + PI * 0.5 * float((first + i) % 4)))
	return out


## Whether `p` lies on any of the ramps of nodes `ks`: a ramp starts at the
## junction it leaves, so a room's mouth turned toward it would open onto the
## scree, which is the way up and not a wall.
static func _on_ramp(plan: GenSlots, ks: Array, p: Vector2) -> bool:
	for k: int in ks:
		if plan.ramp[k] == 0:
			continue
		var a := plan.ramp_from[k]
		var b := plan.ramp_to[k]
		var u := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 1e-4), 0.0, 1.0)
		if p.distance_to(a + (b - a) * u) <= plan.ramp_half[k] + 0.5:
			return true
	return false


## The landscape at `p` when it cuts slots, else -1.
static func _slot_land(w: WorldData, p: Vector2) -> int:
	if not w.in_bounds(floori(p.x), floori(p.y)):
		return -1
	var land := w.country_at(floori(p.x), floori(p.y))
	var d := BiomeRegistry.by_index(land)
	return land if d != null and d.param(&"slots") > 0.0 else -1


static func _plan(w: WorldData) -> GenSlots:
	var id := w.get_instance_id()
	if not _plans.has(id):
		var any := false
		for d: BiomeDef in BiomeRegistry.all():
			if d.param(&"slots") > 0.0:
				any = true
		_plans[id] = GenSlots.plan(w.seed_value, w.size) if any else null
	return _plans[id]
