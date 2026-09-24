extends RefCounted
## WHERE A COLOSSUS'S FOOT COMES DOWN ON THE ISLAND (docs: the colossi design,
## slice 3, "A foot in the region"). Pure: numbers in, numbers out.
##
## A walk is a pure function of the clock, so every plant it will ever make is
## known the moment a world is grown. The straddling walker (a route that passes
## over the island, `ColossusDef.route_offset` > 0) sets a few of them near it;
## world generation takes the nearest (`wanted`), finds each a place on land
## that three pads can stand in, cuts the craters there (GenTreads), and writes
## the tread down in `WorldData.landmarks` as kind `&"tread"`. The walk is then
## handed those rows (`hand_over`) and steps back into its own holes every lap:
## the craters were made by the feet, and the feet always come back to them.
##
## A tread moves its plant a few kilometres from where the gait alone would set
## it. At a stride of forty and legs seventy long that is a longer step and a
## hub leaning a little toward the island, and nothing a player could measure.
##
## Positions are tile space (x east, y south), which is world XZ in metres.

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")

## How near the island a plant must fall, from its middle, to be pulled onto it.
const REACH := 32000.0
## How many treads a world gets. Two, of two different legs, so a pass over the
## island sets a foot down in it and then the next.
const MOST := 2
## A pad's crater, out from the pad's centre: the floor the pad stands on, the
## strata stepped up out of it one level every STEP_W until they meet the
## ground, and the rim of what it threw out, all inside RIM_R. A body steps one
## level, so the steps are walkable; the floor is a little wider than the pad
## (`ColossusDef.pad`), so the pad sits IN it.
const FLOOR_R := 22.0
const STEP_W := 1.5
const RIM_R := 46.0
## How far the floor goes down under the lowest ground a pad covers, in levels.
const DEPTH := 3
## How near the spawn a pad may come: a new game does not open in a crater.
const CLEAR_OF_SPAWN := 160.0


## The plants world generation should find room for, nearest first: [{walker
## (the def's id), leg, j (the plant's index in the lap), natural (Vector2, where
## the gait alone sets it), yaw}]. Empty for a world no straddling walker comes
## near.
static func wanted(seed_value: int, size: int) -> Array:
	var mid := Vector2(size, size) * 0.5
	var near: Array = []
	for d: RefCounted in Def.walkers(size):
		if float(d.route_offset) <= 0.0:
			continue
		var route: RefCounted = Route.make(d, seed_value, size)
		for k in 3:
			for j: int in int(route.cycles()):
				var p: Vector3 = Walk.natural_plant(d, route, k, j)
				var at := Vector2(p.x, p.z)
				var dist := at.distance_to(mid)
				if dist < REACH:
					near.append([dist, {"walker": d.id, "leg": k, "j": j, "natural": at,
						"yaw": Walk.natural_yaw(d, route, k, j)}])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for n: Array in near:
		var row: Dictionary = n[1]
		var clash := false
		for o: Dictionary in out:
			if o.walker == row.walker and int(o.leg) == int(row.leg):
				clash = true
		if not clash:
			out.append(row)
		if out.size() >= MOST:
			break
	return out


## The three pads of a foot set down at `centre` facing `yaw`, as circles
## Vector3(x, y, radius) in tile space: where its weight is, and so where a
## crater is cut, a body is stopped and a prop is crushed.
static func pads(def: RefCounted, centre: Vector2, yaw: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for toe in 3:
		var a := yaw + TAU * float(toe) / 3.0
		var p := centre + Vector2(cos(a), sin(a)) * float(def.toe_reach)
		out.append(Vector3(p.x, p.y, float(def.pad)))
	return out


## Hand a world's treads to its walks: every `&"tread"` row in `landmarks` goes
## to the route of the walker it names, keyed by its plant.
static func hand_over(defs: Array, routes: Array, landmarks: Array) -> void:
	for m: Dictionary in landmarks:
		if StringName(m.get("kind", &"")) != &"tread":
			continue
		for i in defs.size():
			if defs[i].id != StringName(m.get("walker", &"")):
				continue
			var at: Vector2 = m.pos
			var r: RefCounted = routes[i]
			r.treads[r.tread_key(int(m.leg), int(m.j))] = Vector4(at.x, float(m.floor), at.y, float(m.yaw))


## The first world minute, 0 or later, at which plant `j` of leg `k` is set down:
## the end of that leg's j-th swing on the walk's own clock, less its offset.
static func lands_at(def: RefCounted, route: RefCounted, k: int, j: int) -> float:
	var f: float = def.swing_share()
	var t := (float(j) + float(k) / 3.0 + f) * float(def.cycle_minutes)
	return fposmod(t - float(route.offset), float(route.lap_minutes()))


## WHERE A FOOT IS OVER ITS TREAD NOW: for each leg of this walk whose foot
## stands on a tread, or is on its way down to one, {leg, tread (the plant's
## Vector4), height (the pads over the crater floor, metres), planted (bool),
## at (the foot now, Vector3)}. A foot lifting off one is `height` above it too,
## until it is carried away. Asked of the clock, never latched.
static func over(def: RefCounted, route: RefCounted, minutes: float) -> Array:
	var out: Array = []
	if route.treads.is_empty():
		return out
	var t := fposmod(minutes + float(route.offset), float(route.lap_minutes()))
	for k in 3:
		var fs: Array = Walk.foot(def, route, k, t)
		var j: int = fs[3]
		var s: float = fs[1]
		var at: Vector3 = fs[0]
		var to: Vector4 = route.tread_of(k, j)
		var from: Vector4 = route.tread_of(k, j - 1)
		var tread := Vector4(NAN, NAN, NAN, NAN)
		if not is_nan(to.x) and (s < 0.0 or s > 0.5):
			tread = to
		elif not is_nan(from.x) and s >= 0.0 and s <= 0.5:
			tread = from
		if is_nan(tread.x):
			continue
		out.append({"leg": k, "tread": tread, "height": at.y - tread.y, "planted": s < 0.0, "at": at})
	return out
