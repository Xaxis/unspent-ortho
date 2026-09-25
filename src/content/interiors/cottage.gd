extends RefCounted
## A COTTAGE on the coast, and who lives in it. Two deals off the door's own hash
## (InteriorGen's rng), so no two neighbours share a room:
##
##   the PLAN     `hall`  one long room, the bed in its far corner
##                `side`  a main room and a small sleeping room off one side
##                `back`  a main room with the hearth on a side wall, and a back
##                        room behind it through a doorway in the back wall
##   the HOUSEHOLD, what they live by and so what is in the rooms:
##                `fisher`  nets and floats on the walls, oars, a creel, fish
##                          drying on a line by the fire
##                `tinker`  a bench of salvage, a coil of stolen cable, a
##                          machine's strip light wired to the wall
##                `keeper`  herbs drying from the beams, shelves of jars, a
##                          chair drawn up to the hearth
##   and in every house what every house has: a bed with its blankets, shelves,
##   a chest, rag rugs, boots by the door, a lamp hung over the table, and a hole
##   in the wall patched with a machine's plate.
##
## Laid in the canonical frame: the way in is in the south wall (+y). Where a
## thing stands is decided here and is data; what it looks like is the model's
## (src/models/interior/furnish.gd).

const PLANS: Array[StringName] = [&"hall", &"side", &"back"]
const HOUSEHOLDS: Array[StringName] = [&"fisher", &"tinker", &"keeper"]
## How far out from a wall a thing standing against it stands.
const OFF_WALL := 0.36


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"cottage"
	k.closed = 0.4
	k.zoom = 9.0
	k.wall_h = 2.4
	k.cut = 0.8
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/cottage.gd")
	k.model = "res://src/models/interior/cottage_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = PLANS[rng.randi_range(0, PLANS.size() - 1)]
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	var w := 0
	var d := 0
	match l.plan:
		&"hall":
			w = rng.randi_range(8, 9)
			d = 5
			l.rooms.append(Rect2i(0, 0, w, d))
		&"side":
			w = rng.randi_range(6, 7)
			d = rng.randi_range(5, 6)
			l.rooms.append(Rect2i(0, 0, w, d))
			var sw := rng.randi_range(3, 4)
			var sd := rng.randi_range(3, d)
			l.rooms.append(Rect2i(w, 0, sw, sd) if rng.randf() < 0.5 else Rect2i(-sw, 0, sw, sd))
		_:
			w = rng.randi_range(6, 8)
			d = rng.randi_range(4, 5)
			l.rooms.append(Rect2i(0, 0, w, d))
			var bw := rng.randi_range(3, w - 2)
			var bx := rng.randi_range(0, w - bw)
			l.rooms.append(Rect2i(bx, -3, bw, 3))
	# The way in: in the south wall, never in a corner.
	var dx := rng.randi_range(1, w - 2)
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	if l.plan == &"back":
		# The back wall is the way through, so the hearth stands on a side wall,
		# the side the door is further from.
		var east := dx * 2 < w
		l.hearth_wall = Vector2(1, 0) if east else Vector2(-1, 0)
		var hy := clampi(floori(d * 0.5) + rng.randi_range(-1, 0), 1, d - 2)
		l.hearth = Vector2(w - 0.75 if east else 0.75, hy + 0.5)
	else:
		var hx := clampi(w - 1 - dx + rng.randi_range(-1, 1), 1, w - 2)
		l.hearth = Vector2(hx + 0.5, 0.75)
		l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(w * 0.5 + rng.randf_range(-0.6, 0.6), d * 0.5 + 0.2)
	# The hearth is the world's own fire (lit, warmed at, slept beside) and the
	# table a bench to work at, in that order: their ids are what a save keeps.
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": l.hearth_wall})
	l.props.append({"kind": PropKind.BENCH, "at": l.table, "face": Vector2(-l.door_out.y, l.door_out.x)})
	l.lay_edges()
	_openings(l)
	_furnish(l, rng)
	return l


# --- walls ---------------------------------------------------------------------

static func _mid(e: Dictionary) -> Vector2:
	return ((e.a as Vector2) + (e.b as Vector2)) * 0.5


## The door, the doorway between rooms, and the windows. A window goes in the
## middle of every outside wall a room has that runs across the light (its side
## walls, and a back room's back wall), never where the hearth is.
static func _openings(l: InteriorLayout) -> void:
	var inner: Array[Dictionary] = []
	for e: Dictionary in l.edges:
		if _mid(e).distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner:
			inner.append(e)
	# One doorway between each pair of rooms, the one nearest the middle of the
	# wall they share; the rest of that wall stands.
	if l.rooms.size() > 1:
		var other := l.rooms[1]
		var centre := Vector2(other.position) + Vector2(other.size) * 0.5
		var best: Dictionary = {}
		for e: Dictionary in inner:
			var m := _mid(e)
			if best.is_empty() or m.distance_to(centre) < _mid(best).distance_to(centre):
				best = e
		if not best.is_empty():
			best.kind = &"inner"
	for ri in l.rooms.size():
		var r := l.rooms[ri]
		var sides: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0)]
		if ri > 0 and l.plan == &"back":
			sides.append(Vector2(0, -1))
		if ri == 0 and l.plan == &"hall":
			# A long room gets a window beside the door as well.
			sides.append(Vector2(0, 1))
		for dir: Vector2 in sides:
			var want := Vector2(r.position) + Vector2(r.size) * 0.5 + dir * Vector2(r.size) * 0.5
			var best: Dictionary = {}
			for e: Dictionary in l.edges:
				if e.inner or e.kind != &"wall" or not (e.out as Vector2).is_equal_approx(dir):
					continue
				var m := _mid(e)
				if m.distance_to(l.hearth) < 1.6 or m.distance_to(l.door) < 1.9:
					continue
				if not Rect2(Vector2(r.position) - Vector2.ONE * 0.1, Vector2(r.size) + Vector2.ONE * 0.2).has_point(m):
					continue
				if best.is_empty() or m.distance_to(want) < _mid(best).distance_to(want):
					best = e
			if not best.is_empty():
				best.kind = &"window"


# --- what is in the rooms ------------------------------------------------------

## Places against the walls where a thing can stand: every plain stretch of wall
## clear of the door, the hearth, a doorway and a window, a step out from it.
static func _slots(l: InteriorLayout) -> Array[Dictionary]:
	var openings: Array[Vector2] = []
	for e: Dictionary in l.edges:
		if e.kind != &"wall":
			openings.append(_mid(e))
	var out: Array[Dictionary] = []
	for e: Dictionary in l.edges:
		if e.kind != &"wall":
			continue
		var m := _mid(e)
		var o: Vector2 = e.out
		# An inner wall has a face in each room; the slot goes on the side the
		# edge was first laid for, which is the room whose wall it is.
		var at := m - o * OFF_WALL
		if at.distance_to(l.door) < 1.5 or at.distance_to(l.hearth) < 1.5 or at.distance_to(l.table) < 1.3:
			continue
		var clear := true
		for q: Vector2 in openings:
			if q.distance_to(m) < 0.9:
				clear = false
		if clear:
			out.append({"at": at, "face": -o, "mid": m})
	return out


## Two slots side by side on one wall, for a thing two tiles long.
static func _pair(slots: Array[Dictionary], rng: RandomNumberGenerator, prefer: Callable) -> Array[Dictionary]:
	var pairs: Array[Array] = []
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var a: Dictionary = slots[i]
			var b: Dictionary = slots[j]
			if (a.face as Vector2).is_equal_approx(b.face) and (a.mid as Vector2).distance_to(b.mid) < 1.01:
				pairs.append([a, b])
	if pairs.is_empty():
		return []
	pairs.sort_custom(func(p: Array, q: Array) -> bool: return float(prefer.call(p)) > float(prefer.call(q)))
	# The best few, dealt: the bed is not always in the same corner of a plan.
	var pick: Array = pairs[rng.randi_range(0, mini(2, pairs.size() - 1))]
	slots.erase(pick[0])
	slots.erase(pick[1])
	return [pick[0], pick[1]]


static func _take(slots: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if slots.is_empty():
		return {}
	var s: Dictionary = slots[rng.randi_range(0, slots.size() - 1)]
	slots.erase(s)
	return s


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float) -> void:
	l.things.append({"kind": kind, "at": at, "face": face, "solid": solid})


static func _furnish(l: InteriorLayout, rng: RandomNumberGenerator) -> void:
	var slots := _slots(l)
	# The bed, as far from the door as the house allows, in the other room when
	# there is one: nobody sleeps across the way in.
	var far := func(p: Array) -> float:
		var m: Vector2 = ((p[0] as Dictionary).at + (p[1] as Dictionary).at) * 0.5
		var away := m.distance_to(l.door)
		if l.rooms.size() > 1 and l.rooms[1].has_point(Vector2i(floori(m.x), floori(m.y))):
			away += 6.0
		return away
	var bed := _pair(slots, rng, far)
	var bed_at := l.door
	if not bed.is_empty():
		bed_at = ((bed[0].at as Vector2) + (bed[1].at as Vector2)) * 0.5 + (bed[0].face as Vector2) * 0.14
		_put(l, &"bed", bed_at, bed[0].face, 0.5)
	var across := Vector2(-l.door_out.y, l.door_out.x)
	# By the door, inside: boots, and whatever the household leaves there.
	_put(l, &"boots", l.door - l.door_out * 0.55 + across * 0.72, -l.door_out, 0.0)
	# The hearth's own corner: a rug before it, and the soot above it is the model's.
	_put(l, &"rug", l.hearth - l.hearth_wall * 1.55, l.hearth_wall, 0.0)
	# A lamp hung from the beam over the table.
	_put(l, &"lamp", l.table, Vector2(0, 1), 0.0)
	# A rug by the bed as well.
	if not bed.is_empty():
		_put(l, &"rug", bed_at + (bed[0].face as Vector2) * 0.9, bed[0].face, 0.0)
	var wants: Array[StringName] = [&"shelf", &"chest", &"patch"]
	match l.dressing:
		&"fisher":
			wants.append_array([&"nets", &"oars", &"creel", &"floats"])
			_put(l, &"fishline", l.hearth - l.hearth_wall * 1.2, l.hearth_wall, 0.0)
		&"tinker":
			wants.append_array([&"workbench", &"machine_lamp", &"shelf_salvage", &"coil"])
		_:
			wants.append_array([&"jars", &"jars", &"basket", &"shelf"])
			_put(l, &"herbs", l.hearth - l.hearth_wall * 1.3, l.hearth_wall, 0.0)
			var side := Vector2(-l.hearth_wall.y, l.hearth_wall.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			_put(l, &"chair", l.hearth - l.hearth_wall * 1.25 + side * 1.0, l.hearth_wall, 0.25)
	for kind: StringName in wants:
		var s := _take(slots, rng)
		if s.is_empty():
			break
		_put(l, kind, s.at, s.face, _solid(kind))
	# The ways worn into the boards.
	var hearth_front := l.hearth - l.hearth_wall * 1.2
	l.walks.append(PackedVector2Array([l.door, hearth_front]))
	l.walks.append(PackedVector2Array([l.door, l.table]))
	l.walks.append(PackedVector2Array([l.table, hearth_front]))
	if not bed.is_empty():
		l.walks.append(PackedVector2Array([l.door, bed_at + (bed[0].face as Vector2) * 0.8]))


## How much of the room a thing stands in (what stops a body), by kind.
static func _solid(kind: StringName) -> float:
	match kind:
		&"shelf", &"jars", &"shelf_salvage":
			return 0.26
		&"chest", &"creel", &"basket":
			return 0.28
		&"workbench":
			return 0.36
		&"coil":
			return 0.22
	return 0.0
