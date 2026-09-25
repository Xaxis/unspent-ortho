extends RefCounted
## THE PLAN'S WEAPONS HALL, under a works depot's yard (docs/interiors): the
## machines' own place, made by machines for machines. A long plated hall on the
## survey bearing, racked down both sides with what they arm themselves with; a
## gutted machine hung on a gantry in the middle, being worked on or taken apart;
## one or two caged bays off the back wall where what is worth guarding is kept;
## strip lights ruled down the ceiling in lines, and the roof torn open in places
## where the yard above has settled onto it, so the day comes down in columns.
##
## Nothing here is homely and nothing is warm: no hearth, no windows, a cold light
## on a schedule. What stands where is decided here and is data; how it looks is
## `src/models/interior/weapons_hall_model.gd`. Laid in the canonical frame: the
## way in is in the south wall (+y).

## How far out from a wall a thing standing against it stands.
const OFF_WALL := 0.42


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"weapons_hall"
	# A torn roof: under SkyLight's casting line, so the sun through a tear is the
	# sun itself, and the rest of the hall is the strips' cold light.
	k.closed = 0.3
	k.zoom = 12.0
	k.wall_h = 3.6
	k.cut = 1.0
	# A machine as wide as a hauler comes through; a harvester does not.
	k.door_width = 1.3
	k.recipe = load("res://src/content/interiors/weapons_hall.gd")
	k.model = "res://src/models/interior/weapons_hall_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"bays"
	l.dressing = &"armoury"
	l.has_hearth = false
	var w := rng.randi_range(12, 14)
	var d := 7
	l.rooms.append(Rect2i(0, 0, w, d))
	# One or two caged bays off the back wall, never at its ends and a unit apart:
	# `slack` is what the wall has left over once they and those gaps are placed.
	var bays := 1 if rng.randf() < 0.45 else 2
	var bay_w := 4
	var slack := w - 2 - bays * bay_w - (bays - 1)
	var x := 1 + rng.randi_range(0, slack)
	slack -= x - 1
	for _i in bays:
		l.rooms.append(Rect2i(x, -3, bay_w, 3))
		var gap := rng.randi_range(0, slack)
		slack -= gap
		x += bay_w + 1 + gap
	var dx := floori(w * 0.5) + rng.randi_range(-1, 1)
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	# No hearth: `hearth` is where the gutted machine hangs, the hall's middle,
	# so a reader that asks for "the heart of the room" gets the right answer.
	l.hearth = Vector2(w * 0.5, d * 0.5 - 0.3)
	l.hearth_wall = Vector2(0, -1)
	l.table = l.hearth
	l.lay_edges()
	_openings(l)
	_fit(l, rng)
	return l


static func _mid(e: Dictionary) -> Vector2:
	return ((e.a as Vector2) + (e.b as Vector2)) * 0.5


## The way in, and one doorway into each bay: the middle unit of the wall the
## bay shares with the hall. A hall has no windows.
static func _openings(l: InteriorLayout) -> void:
	for e: Dictionary in l.edges:
		if _mid(e).distance_to(l.door) < 0.1:
			e.kind = &"door"
	for ri in range(1, l.rooms.size()):
		var r := l.rooms[ri]
		var want := Vector2(r.position.x + r.size.x * 0.5, r.end.y)
		var best: Dictionary = {}
		for e: Dictionary in l.edges:
			if not e.inner:
				continue
			var m := _mid(e)
			if absf(m.y - want.y) > 0.1 or m.x < r.position.x or m.x > r.end.x:
				continue
			if best.is_empty() or m.distance_to(want) < _mid(best).distance_to(want):
				best = e
		if not best.is_empty():
			best.kind = &"inner"


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float) -> void:
	l.things.append({"kind": kind, "at": at, "face": face, "solid": solid})


## What the hall holds.
static func _fit(l: InteriorLayout, rng: RandomNumberGenerator) -> void:
	var hall := l.rooms[0]
	var w := hall.size.x
	var d := hall.size.y
	# Racks down both long walls of the hall, a unit apart, clear of the door and
	# of the bays' doorways; and turrets high in the four corners.
	var doorways: Array[Vector2] = [l.door]
	for e: Dictionary in l.edges:
		if e.kind == &"inner":
			doorways.append(_mid(e))
	for xi in range(1, w - 1):
		var x := float(xi) + 0.5
		for side: int in [0, 1]:
			var wall_y := 0.0 if side == 0 else float(d)
			var face := Vector2(0, 1) if side == 0 else Vector2(0, -1)
			var at := Vector2(x, wall_y + face.y * OFF_WALL)
			var clear := true
			for q: Vector2 in doorways:
				if q.distance_to(Vector2(x, wall_y)) < 1.6:
					clear = false
			if clear and rng.randf() < 0.7:
				_put(l, &"rack", at, face, 0.32)
	for c: Vector2 in [Vector2(0.6, 0.6), Vector2(w - 0.6, 0.6), Vector2(0.6, d - 0.6), Vector2(w - 0.6, d - 0.6)]:
		var inward := (Vector2(w * 0.5, d * 0.5) - c).normalized()
		_put(l, &"turret", c, inward, 0.0)
	# The gutted machine on its gantry, the hall's middle; the gantry's legs stop
	# a body, the machine hangs clear of the floor.
	_put(l, &"gantry", l.hearth, Vector2(0, 1), 0.0)
	for u: float in [-1.4, 1.4]:
		_put(l, &"gantry_leg", l.hearth + Vector2(u, 0.0), Vector2(0, 1), 0.22)
	# A strongbox in each bay against its back wall: what the hall is guarding.
	for ri in range(1, l.rooms.size()):
		var r := l.rooms[ri]
		_put(l, &"strongbox", Vector2(r.position.x + r.size.x * 0.5, r.position.y + OFF_WALL + 0.1), Vector2(0, 1), 0.36)
	# The strip lights, ruled in two lines down the hall's length.
	for xi in range(1, w, 3):
		for yy: float in [d * 0.3, d * 0.7]:
			_put(l, &"strip", Vector2(float(xi) + 0.5, yy), Vector2(1, 0), 0.0)
	# Where the roof is torn: two or three places, never over the door.
	var tears := 2 + rng.randi_range(0, 1)
	for _i in tears:
		var tx := rng.randi_range(1, w - 2)
		var ty := rng.randi_range(1, d - 3)
		_put(l, &"tear", Vector2(float(tx) + 0.5, float(ty) + 0.5), Vector2(0, 1), 0.0)
	# Where the warden stands its watch: in front of the bays.
	_put(l, &"post", Vector2(w * 0.5, 1.6), Vector2(0, 1), 0.0)
