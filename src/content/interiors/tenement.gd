extends RefCounted
## A TENEMENT IN THE SLUMS, from inside (docs/interiors; the forms outside are
## props/towers.gd `tower` and `stack`). The slums are where the plan WORKED
## (content/biomes/slums.gd): nothing here is ruined, and that is what is wrong
## with it. The stair hall is swept, the paint is the plan's two municipal
## colours, the doors are numbered and every one has its meter turning over
## beside it and a pair of shoes squared outside it. The stair up is behind a
## permit turnstile, and the shift board by it says who goes where, when.
## Behind one door, left open, one household's one room: everything put away.
##
## Dealt per door off its own hash:
##   the PLAN      which way the corridor runs off the hall (`east`/`west`) and
##                 which of its doors is the one standing open
##   the HOUSEHOLD `clerk`  ledgers squared on the table, a lamp for late
##                 `shift`  overalls on the hook, a lunch tin, boots by the bed
##                 `keeper` who keeps the building: the key board, the register
## and in every one: the bed made, the stove the plan issues (the fire is laid
## in its firebox), the radio the plan speaks through, a calendar of shifts.
##
## STORY SLOTS: the shift board (`wall:shift_board`) and the household's table
## with its ration book on it (`desk:ration_book`).
## Laid in the canonical frame: the way in is in the south wall (+y).

const Cottage := preload("res://src/content/interiors/cottage.gd")
const HOUSEHOLDS: Array[StringName] = [&"clerk", &"shift", &"keeper"]
## The corridor's length, tiles, and how many doors are down each side of it.
const RUN := 7


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"tenement"
	# No windows on the stair: the building's own lamps, day and night.
	k.closed = 0.7
	k.zoom = 9.5
	k.wall_h = 2.6
	k.cut = 0.9
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/tenement.gd")
	k.model = "res://src/models/interior/tenement_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	var east := rng.randf() < 0.5
	l.plan = &"east" if east else &"west"
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	l.has_hearth = false
	# The stair hall, entered from the street.
	var hall := Rect2i(0, 0, 4, 5)
	# The corridor off it, three wide so the shoulder eye has room.
	var cx := 4 if east else -RUN
	var corridor := Rect2i(cx, 1, RUN, 3)
	# The flat whose door stands open, off the corridor's far wall.
	var slot := rng.randi_range(2, RUN - 3)
	var fx := cx + slot - 1
	var flat := Rect2i(fx, -3, 4, 4)
	l.rooms.append(hall)
	l.rooms.append(corridor)
	l.rooms.append(flat)
	# The street door on the corridor's side of the hall; the stair on the other.
	l.door = Vector2(2.5 if east else 1.5, 5)
	l.door_out = Vector2(0, 1)
	l.hearth = Vector2(fx + 3.3, -2.3)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(fx + 1.4, -1.2)
	# The fire is laid in the stove's firebox: the world's own, cooked at and slept by.
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": Vector2(0, 1)})
	l.props.append({"kind": PropKind.BENCH, "at": l.table, "face": Vector2(1, 0)})
	l.lay_edges()
	_openings(l, hall, corridor, flat, east)
	_furnish(l, rng, hall, corridor, flat, east)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _inside(r: Rect2i, p: Vector2) -> bool:
	return Rect2(Vector2(r.position) - Vector2.ONE * 0.1, Vector2(r.size) + Vector2.ONE * 0.2).has_point(p)


## The street door, the hall's opening into the corridor, and the flat's door
## standing open off the corridor. The hall opens its whole side: those edges are
## taken out, not made doorways, which would stand a pair of jambs across the
## corridor's mouth at every tile of it.
static func _openings(l: InteriorLayout, hall: Rect2i, corridor: Rect2i, flat: Rect2i, east: bool) -> void:
	var flat_door := Vector2(flat.position.x + 1.5, flat.end.y)
	var kept: Array[Dictionary] = []
	for e: Dictionary in l.edges:
		var m := Cottage._mid(e)
		if e.inner and _inside(hall, m) and _inside(corridor, m):
			continue
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and m.distance_to(flat_door) < 0.1:
			e.kind = &"inner"
		kept.append(e)
	l.edges = kept


static func _furnish(l: InteriorLayout, rng: RandomNumberGenerator, hall: Rect2i, corridor: Rect2i, flat: Rect2i, east: bool) -> void:
	var away := Vector2(-1, 0) if east else Vector2(1, 0)
	# The stair up, against the hall's wall away from the corridor, and the
	# turnstile across its foot.
	var stair_x := 0.62 if east else 3.38
	_put(l, &"stair", Vector2(stair_x, 1.55), Vector2(0, 1), 0.46, {"deep": 2.5})
	_put(l, &"turnstile", Vector2(stair_x, 3.3), Vector2(0, 1), 0.3)
	# The shift board on the hall's back wall, facing whoever comes in.
	var board := Vector2(2.5 if east else 1.5, 0.36)
	_put(l, &"shift_board", board, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"wall", "at": board, "face": Vector2(0, 1)})
	# Doors down both walls of the corridor, numbered, each with its meter and a
	# pair of shoes squared outside -- all shut but the flat's.
	var flat_door_x := float(flat.position.x) + 1.5
	var number := 11 + rng.randi_range(0, 8) * 10
	for i in RUN:
		var x := float(corridor.position.x) + 0.5 + float(i)
		for side: float in [-1.0, 1.0]:
			var y := float(corridor.position.y) + (0.0 if side < 0.0 else float(corridor.size.y))
			# Not on the flat's own wall: it has the one door, standing open.
			if side < 0.0 and x > float(flat.position.x) and x < float(flat.end.x):
				continue
			if i % 2 == 1:
				continue
			var face := Vector2(0, -side)
			_put(l, &"flat_door", Vector2(x, y), face, 0.0, {"number": number})
			_put(l, &"shoes", Vector2(x + 0.35, y + face.y * 0.3), face, 0.0)
			number += 1
	# The flat: the bed made, the stove with the fire in it, the radio, the
	# calendar, and what the household keeps.
	var fx := float(flat.position.x)
	_put(l, &"bed", Vector2(fx + 0.6, -2.0), Vector2(1, 0), 0.5)
	_put(l, &"stove", l.hearth, Vector2(0, 1), 0.0)
	_put(l, &"radio", Vector2(fx + 2.3, -2.6), Vector2(0, 1), 0.0)
	_put(l, &"calendar", Vector2(fx + 1.6, -2.64), Vector2(0, 1), 0.0)
	_put(l, &"wardrobe", Vector2(fx + 3.6, -0.8), Vector2(-1, 0), 0.3)
	# The ration book the plan issues every household, on its table: what the
	# desk slot stands at, whoever lives here.
	_put(l, &"ration_book", l.table, Vector2(0, -1), 0.0)
	l.slots.append({"slot": &"desk", "at": l.table, "face": Vector2(0, -1)})
	match l.dressing:
		&"clerk":
			_put(l, &"ledgers", l.table + Vector2(0.2, 0.0), Vector2(0, 1), 0.0)
		&"shift":
			_put(l, &"overalls", Vector2(fx + 0.36, -0.6), Vector2(1, 0), 0.0)
		_:
			_put(l, &"key_board", board + Vector2(-away.x * 1.0, 0.0), Vector2(0, 1), 0.0)
	l.walks.append(PackedVector2Array([l.door, Vector2(2.0, 2.5)]))
	l.walks.append(PackedVector2Array([Vector2(2.0, 2.5), Vector2(flat_door_x, 2.5)]))
	l.walks.append(PackedVector2Array([Vector2(flat_door_x, 2.5), l.table]))
