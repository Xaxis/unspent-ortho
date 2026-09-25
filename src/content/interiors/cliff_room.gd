extends RefCounted
## A ROOM CUT INTO THE MESA, from inside (docs/interiors; the form outside is
## props/mesas.gd `cut_room`). The scarp was dug back into and only the front
## wall was built: mud brick with the door and one small window in it. Every
## other wall, and the low roof, is the rock itself in its own bands, worked
## smooth where hands and shoulders go and left rough where they do not, black
## over the fire. The rock keeps the day's heat out and the night's in.
##
## Dealt per door off its own hash:
##   the PLAN      `single` one room, dug wide
##                 `deep`   a front room and a store cut further in behind it,
##                          through a low doorway in the back wall
##   the HOUSEHOLD `grinder` who grinds: the metate and its mano, baskets of
##                           meal, ristras of dried chiles hung from the poles
##                 `weaver`  a backstrap loom tied to a pole, hanks of spun wool
##                 `rigger`  who works the span for the plan and keeps what
##                           came off it: a coil of the machines' cable, a pulley
## and in every room: the fire in a pit in the floor with a slab stood between
## it and the door against the draught, a sleeping ledge left in the rock, niches
## cut in the walls, water jars, mats, a line of the span's own wire strung
## across to dry things on.
##
## STORY SLOTS: a niche (&"wall") and the ledge (&"desk"). Laid in the canonical
## frame: the way in is in the south wall (+y), and that wall is the built one.

const Cottage := preload("res://src/content/interiors/cottage.gd")
const PLANS: Array[StringName] = [&"single", &"deep"]
const HOUSEHOLDS: Array[StringName] = [&"grinder", &"weaver", &"rigger"]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"cliff_room"
	# One window and a door into a hillside: dim, the fire the room's own light.
	k.closed = 0.45
	k.zoom = 9.0
	k.wall_h = 2.2
	k.cut = 0.8
	k.door_width = 0.8
	k.recipe = load("res://src/content/interiors/cliff_room.gd")
	k.model = "res://src/models/interior/cliff_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = PLANS[rng.randi_range(0, PLANS.size() - 1)]
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	# No chimney breast: the fire is in the floor.
	l.has_hearth = false
	var w := rng.randi_range(6, 7)
	var d := rng.randi_range(5, 6)
	l.rooms.append(Rect2i(0, 0, w, d))
	if l.plan == &"deep":
		var bw := rng.randi_range(3, 4)
		l.rooms.append(Rect2i(rng.randi_range(1, w - bw - 1), -3, bw, 3))
	var dx := rng.randi_range(2, w - 3)
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	# The fire pit well in from the door, the slab between them against the draught.
	l.hearth = Vector2(dx + 0.5, d * 0.5 - 0.5)
	l.hearth_wall = Vector2(0, -1)
	var east := dx * 2 < w
	l.table = Vector2((w - 1.2) if east else 1.2, d * 0.5 + 0.4)
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": Vector2(0, 1)})
	l.lay_edges()
	_openings(l, w, d, dx)
	_furnish(l, rng, w, d, east)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


## The door, the one small window in the built wall beside it, and the low
## doorway through to the store.
static func _openings(l: InteriorLayout, w: int, d: int, dx: int) -> void:
	var win_x := dx + (2 if dx + 2 < w else -2)
	for e: Dictionary in l.edges:
		var m := Cottage._mid(e)
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif m.distance_to(Vector2(win_x + 0.5, d)) < 0.1:
			e.kind = &"window"
	if l.rooms.size() > 1:
		var back := l.rooms[1]
		var want := Vector2(back.position.x + back.size.x * 0.5, 0.0)
		var best: Dictionary = {}
		for e: Dictionary in l.edges:
			if not e.inner:
				continue
			if best.is_empty() or Cottage._mid(e).distance_to(want) < Cottage._mid(best).distance_to(want):
				best = e
		if not best.is_empty():
			best.kind = &"inner"


static func _furnish(l: InteriorLayout, rng: RandomNumberGenerator, w: int, d: int, east: bool) -> void:
	var side := Vector2(1, 0) if east else Vector2(-1, 0)
	# The ledge left standing in the rock along the side wall away from the door:
	# a bed, a bench, a shelf, the whole of the furniture a cut room is born with.
	var ledge_x := (float(w) - 0.45) if east else 0.45
	_put(l, &"ledge", Vector2(ledge_x, float(d) * 0.5 - 0.3), Vector2(0, 1), 0.36, {"deep": float(d) - 1.4})
	l.slots.append({"slot": &"desk", "at": Vector2(ledge_x, float(d) * 0.5 - 0.3), "face": -side})
	# The slab between the fire and the door.
	_put(l, &"deflector", l.hearth + Vector2(0, 0.75), Vector2(1, 0), 0.14, {"deep": 0.9})
	# A mat by the fire, the jars by the door, the wire across the room.
	_put(l, &"mat", l.hearth + Vector2(0, -1.0), Vector2(0, 1), 0.0)
	_put(l, &"ollas", l.door + Vector2(-side.x * 0.8, -0.5), Vector2(0, -1), 0.24)
	_put(l, &"wire", Vector2(float(w) * 0.5, 0.9), Vector2(1, 0), 0.0, {"deep": float(w) - 1.2})
	# Niches cut in the back wall, a slot in one of them.
	var niches := 2 + rng.randi_range(0, 1)
	for i in niches:
		var nx := (float(i) + 0.8) * float(w) / (float(niches) + 0.6)
		_put(l, &"niche", Vector2(nx, 0.3), Vector2(0, 1), 0.0)
		if i == 0:
			l.slots.append({"slot": &"wall", "at": Vector2(nx, 0.3), "face": Vector2(0, 1)})
	# What the household lives by, against what wall is left.
	var slots := Cottage._slots(l)
	var keep: Array[Dictionary] = []
	for s: Dictionary in slots:
		var at: Vector2 = s.at
		if absf(at.x - ledge_x) > 1.0 and at.distance_to(l.hearth) > 1.5:
			keep.append(s)
	var wants: Array[StringName] = [&"basket"]
	match l.dressing:
		&"grinder":
			wants.append_array([&"metate", &"basket", &"ristra"])
		&"weaver":
			wants.append_array([&"loom", &"hanks", &"basket"])
		_:
			wants.append_array([&"cable", &"pulley", &"basket"])
	for kind: StringName in wants:
		var s := Cottage._take(keep, rng)
		if s.is_empty():
			break
		_put(l, kind, s.at, s.face, _solid(kind))
	# In the store behind, when there is one: jars and baskets in the cool.
	if l.rooms.size() > 1:
		var back := l.rooms[1]
		for i in back.size.x - 1:
			_put(l, &"ollas", Vector2(back.position.x + 0.8 + float(i), back.position.y + 0.45), Vector2(0, 1), 0.24)
	l.walks.append(PackedVector2Array([l.door, l.hearth + Vector2(0, 1.4)]))
	l.walks.append(PackedVector2Array([l.hearth + Vector2(0, 1.4), Vector2(ledge_x - side.x * 0.9, float(d) * 0.5)]))


static func _solid(kind: StringName) -> float:
	match kind:
		&"metate":
			return 0.3
		&"basket", &"hanks":
			return 0.22
		&"loom":
			return 0.2
		&"cable":
			return 0.24
	return 0.0
