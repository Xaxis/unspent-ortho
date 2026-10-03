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
## FLOOR_R and RIM_R are PAST the pad's own radius, so a heel wider than a toe
## gets a crater wider by as much: `floor_r(p)`, `rim_r(p)`.
const FLOOR_R := 2.0
const STEP_W := 1.5
const RIM_R := 26.0


static func floor_r(p: Vector3) -> float:
	return p.z + FLOOR_R


static func rim_r(p: Vector3) -> float:
	return p.z + RIM_R
## How far the floor goes down under the lowest ground a pad covers, in levels.
const DEPTH := 3


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


## Which of `pads` is the middle toe's: the crater the cable comes down into
## (WalkerClimb.FOOT_TURN is turned off it), and so the one the walker lead pins
## (19_colossi `craters`) and the crater's people stand by.
const MIDDLE_TOE := 1


## The pads of a foot set down at `centre` facing `yaw` (its toes, then its heel), as circles
## Vector3(x, y, radius) in tile space: where its weight is, and so where a
## crater is cut, a body is stopped and a prop is crushed.
static func pads(def: RefCounted, centre: Vector2, yaw: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in int(def.toes.size()):
		var t: Vector3 = def.toe(i)
		var p := centre + Vector2.from_angle(yaw + t.x) * t.y
		out.append(Vector3(p.x, p.y, t.z))
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
	var w: Vector2 = Walk.window(def, route, k)
	var t := (float(j) + w.x + w.y) * float(def.cycle_minutes)
	return fposmod(t - float(route.offset), float(route.lap_minutes()))


## The feet that are not yet within `below` of their tread's floor at `minutes`
## and will be within `lead` world minutes (`below` 0: down in it): `over`'s rows
## as they will stand, for the shadow a pad throws before it comes (19_colossi,
## DESIGN 5c).
static func landing_soon(def: RefCounted, route: RefCounted, minutes: float, lead: float, below: float = 0.0) -> Array:
	var low := {}
	for o: Dictionary in over(def, route, minutes):
		if _low(o, below):
			low[int(o.leg)] = true
	var out: Array = []
	for o: Dictionary in over(def, route, minutes + lead):
		if _low(o, below) and not low.has(int(o.leg)):
			out.append(o)
	return out


static func _low(o: Dictionary, below: float) -> bool:
	return bool(o.planted) or float(o.height) < below


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


## Every tread's pads, each as (x, y, rim radius): what a landing presses.
static func pressed(w: WorldData) -> Array[Array]:
	var out: Array[Array] = []
	for m: Dictionary in w.landmarks:
		if StringName(m.get("kind", &"")) != &"tread":
			continue
		var pads: Array[Vector3] = []
		for p: Vector3 in (m.pads as Array):
			pads.append(Vector3(p.x, p.y, rim_r(p)))
		out.append(pads)
	return out


## The ids of every prop the tread stage laid round its own craters: what a
## landing leaves standing.
static func owned(w: WorldData) -> Dictionary:
	var out := {}
	for m: Dictionary in w.landmarks:
		if StringName(m.get("kind", &"")) == &"tread" and m.has("props"):
			for id: int in PackedInt32Array(m.props):
				out[id] = true
	return out


## EVERYTHING THE WORLD LAID WHERE A PAD COMES DOWN, crushed for good before he
## ever arrives: within a pad's rim and its own mass, of the props whose tile is
## within the rim and four (the search 19_colossi crushes with), save the ones
## the tread stage laid round its own craters. Pure over the world, read off its
## table; held per world, because the crush, the ore a chapter counts as
## standing and the ore it counts as taken all ask it (none of it was ever there
## for him to take).
static var _crushed: Dictionary = {}
static var _crushed_lock := Mutex.new()


static func crushed(w: WorldData) -> Dictionary:
	_crushed_lock.lock()
	var held: Array = _crushed.get(w.get_instance_id(), [])
	_crushed_lock.unlock()
	if not held.is_empty() and (held[0] as WeakRef).get_ref() == w:
		return held[1]
	var out := {}
	var mine := owned(w)
	w.sync_table()
	var t := w.table
	for pads: Array[Vector3] in pressed(w):
		for pad: Vector3 in pads:
			var at := Vector2(pad.x, pad.y)
			var reach := pad.z + 4.0
			var x0 := maxi(0, floori(at.x - reach))
			var x1 := mini(w.size - 1, floori(at.x + reach))
			var y0 := maxi(0, floori(at.y - reach))
			var y1 := mini(w.size - 1, floori(at.y + reach))
			for row in t.size():
				var p: Vector2 = t.pos[row]
				var tx := floori(p.x)
				var ty := floori(p.y)
				if tx < x0 or tx > x1 or ty < y0 or ty > y1:
					continue
				var id: int = t.id[row]
				if mine.has(id) or p.distance_to(at) > pad.z + float(t.solid[row]):
					continue
				out[id] = true
	_crushed_lock.lock()
	for k: int in _crushed.keys():
		if ((_crushed[k] as Array)[0] as WeakRef).get_ref() == null:
			_crushed.erase(k)
	_crushed[w.get_instance_id()] = [weakref(w), out]
	_crushed_lock.unlock()
	return out
