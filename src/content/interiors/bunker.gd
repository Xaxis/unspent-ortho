extends RefCounted
## A BUNKER UNDER THE CAST STONES (docs/interiors): sunk before the machines by
## somebody who knew what was coming and hid what they knew under a ring of
## stones nobody would dig in. People made it -- poured concrete, painted
## steel, the tech of 2029 -- and it has been shut since. Nothing lives in it.
##
## A corridor runs in from the stair, and the rooms open off it, dealt per door:
##   the bunk room    a cot, a locker, something pinned to the wall
##   the work room    a desk and its terminal, a whiteboard, cabinets, a rack
##                    of servers gone dark
##   the records room at the far end: cabinets, a footlocker, and a sealed steel
##                    door in its back wall -- the way further down, shut
##   (the plant room  sometimes: a dead generator and its fuel)
## The corridor keeps its emergency lamps, still on their batteries, and the
## tubes in its ceiling are dead. It is night down here at any hour.
##
## STORY SLOTS (`InteriorLayout.slots`) say where words can be found -- the desk,
## the terminal, the wall -- and nothing here says what they are: that is the
## story's (docs/STORY.md), written into them later. Laid in the canonical frame:
## the way in is in the south wall (+y).

const OFF_WALL := 0.4


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"bunker"
	# Shut: night at any hour, the lamp worth lighting.
	k.closed = 1.0
	k.zoom = 9.0
	k.wall_h = 2.6
	k.cut = 0.9
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/bunker.gd")
	k.model = "res://src/models/interior/bunker_model.gd"
	k.hatch = "res://src/models/interior/bunker_hatch_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"corridor"
	l.dressing = &"researcher"
	l.has_hearth = false
	var length := rng.randi_range(7, 9)
	var cx := 4
	# The corridor, three wide, from the stair (south) to the records room: two
	# was too narrow for the eye over the shoulder to stand anywhere but in the
	# player's hair.
	var corridor := Rect2i(cx, 0, 3, length)
	l.rooms.append(corridor)
	# The records room across its far end.
	var records := Rect2i(cx - 1, -4, 5, 4)
	l.rooms.append(records)
	# The bunk room and the work room, one each side, which side dealt.
	var west_bunk := rng.randf() < 0.5
	var bunk := Rect2i(cx - 3, rng.randi_range(1, 2), 3, 3)
	var work := Rect2i(cx + 3, rng.randi_range(1, 2), 4, 4)
	if not west_bunk:
		bunk = Rect2i(cx + 3, bunk.position.y, 3, 3)
		work = Rect2i(cx - 4, work.position.y, 4, 4)
	l.rooms.append(bunk)
	l.rooms.append(work)
	# And now and then the plant room, further along on the bunk room's side.
	var plant := Rect2i()
	var has_plant := rng.randf() < 0.55 and length >= 8
	if has_plant:
		var px := bunk.position.x
		plant = Rect2i(px, bunk.end.y + 1, 3, mini(3, length - bunk.end.y - 1))
		if plant.size.y >= 2:
			l.rooms.append(plant)
		else:
			has_plant = false
	l.door = Vector2(cx + 1.5, length)
	l.door_out = Vector2(0, 1)
	l.hearth = Vector2(cx + 1.5, length * 0.5)
	l.hearth_wall = Vector2(0, -1)
	l.table = l.hearth
	l.lay_edges()
	_openings(l)
	_fit(l, corridor, records, bunk, work, plant if has_plant else Rect2i())
	return l


static func _mid(e: Dictionary) -> Vector2:
	return ((e.a as Vector2) + (e.b as Vector2)) * 0.5


## The way in, and one doorway from the corridor into each room: the unit of the
## wall they share nearest the room's middle.
static func _openings(l: InteriorLayout) -> void:
	for e: Dictionary in l.edges:
		if _mid(e).distance_to(l.door) < 0.1:
			e.kind = &"door"
	var corridor := l.rooms[0]
	for ri in range(1, l.rooms.size()):
		var r := l.rooms[ri]
		var centre := Vector2(r.position) + Vector2(r.size) * 0.5
		var best: Dictionary = {}
		for e: Dictionary in l.edges:
			if not e.inner:
				continue
			var m := _mid(e)
			# Only the wall this room shares with the corridor.
			var in_r := Rect2(Vector2(r.position) - Vector2.ONE * 0.1, Vector2(r.size) + Vector2.ONE * 0.2).has_point(m)
			var in_c := Rect2(Vector2(corridor.position) - Vector2.ONE * 0.1, Vector2(corridor.size) + Vector2.ONE * 0.2).has_point(m)
			if not (in_r and in_c):
				continue
			if best.is_empty() or m.distance_to(centre) < _mid(best).distance_to(centre):
				best = e
		if not best.is_empty():
			best.kind = &"inner"


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float) -> void:
	l.things.append({"kind": kind, "at": at, "face": face, "solid": solid})


## Against a room's wall on side `side` (the way out of the room through that
## wall), `u` along it from the wall's middle.
static func _against(r: Rect2i, side: Vector2, u: float) -> Vector2:
	var centre := Vector2(r.position) + Vector2(r.size) * 0.5
	var half := Vector2(r.size) * 0.5
	var at := centre + side * (half * side.abs() - Vector2.ONE * OFF_WALL * side.abs()).length()
	var along := Vector2(-side.y, side.x)
	return at + along * u


static func _fit(l: InteriorLayout, corridor: Rect2i, records: Rect2i, bunk: Rect2i, work: Rect2i, plant: Rect2i) -> void:
	var to_corridor_bunk := Vector2(1, 0) if bunk.position.x < corridor.position.x else Vector2(-1, 0)
	var away_bunk := -to_corridor_bunk
	var away_work := Vector2(-1, 0) if work.position.x < corridor.position.x else Vector2(1, 0)
	# The bunk room: a cot along its far wall, a locker, and a slot on the wall
	# over the cot where something was pinned.
	var cot := _against(bunk, away_bunk, 0.0)
	_put(l, &"cot", cot, -away_bunk, 0.45)
	_put(l, &"locker", _against(bunk, Vector2(0, -1), 0.8), Vector2(0, 1), 0.3)
	l.slots.append({"slot": &"wall", "at": cot, "face": -away_bunk})
	# The work room: a desk against the far wall with its terminal, a whiteboard
	# on the wall beside, cabinets, and the dark rack.
	var desk := _against(work, away_work, 0.0)
	_put(l, &"desk", desk, -away_work, 0.45)
	l.slots.append({"slot": &"desk", "at": desk, "face": -away_work})
	l.slots.append({"slot": &"terminal", "at": desk, "face": -away_work})
	var board := _against(work, Vector2(0, -1), -0.6)
	_put(l, &"whiteboard", board, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"wall", "at": board, "face": Vector2(0, 1)})
	_put(l, &"server_rack", _against(work, Vector2(0, -1), 1.1), Vector2(0, 1), 0.35)
	_put(l, &"cabinet", _against(work, Vector2(0, 1), 0.9), Vector2(0, -1), 0.3)
	# The records room: cabinets down both sides, the footlocker, the sealed door.
	for side: Vector2 in [Vector2(-1, 0), Vector2(1, 0)]:
		for u: float in [-0.8, 0.6]:
			_put(l, &"cabinet", _against(records, side, u), -side, 0.3)
	_put(l, &"strongbox", _against(records, Vector2(0, -1), -1.1), Vector2(0, 1), 0.36)
	_put(l, &"vault_door", _against(records, Vector2(0, -1), 0.6), Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"desk", "at": _against(records, Vector2(0, -1), 0.0), "face": Vector2(0, 1)})
	# The plant room, when there is one: the generator and its fuel.
	if plant.size.x > 0:
		_put(l, &"generator", Vector2(plant.position) + Vector2(plant.size) * 0.5, Vector2(0, 1), 0.55)
		for i in 3:
			_put(l, &"drum", _against(plant, away_bunk, -0.7 + 0.55 * float(i)), -away_bunk, 0.22)
	# The corridor: emergency lamps down its walls, still on their batteries, and
	# dead tubes in the ceiling; one lamp in the records room.
	for y in range(1, corridor.size.y, 2):
		var side := Vector2(-1, 0) if ((y >> 1) & 1) == 0 else Vector2(1, 0)
		_put(l, &"elamp", _against(Rect2i(corridor.position.x, y, 3, 1), side, 0.0), -side, 0.0)
	_put(l, &"elamp", _against(records, Vector2(1, 0), -1.2), Vector2(-1, 0), 0.0)
	for y in range(1, corridor.size.y, 3):
		_put(l, &"tube", Vector2(corridor.position.x + 1.5, float(y) + 0.5), Vector2(0, 1), 0.0)
	# Where a body walks: down the corridor and into each room.
	l.walks.append(PackedVector2Array([l.door, Vector2(corridor.position.x + 1.5, 0.5)]))
