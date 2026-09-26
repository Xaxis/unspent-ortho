extends RefCounted
## A SQUAT IN THE MACHINE CITY (docs/interiors): people living in the machines'
## own gaps, which is the game's premise, and rare -- the machine city is built
## for machines, and only one house in so many has somebody in it
## (`BiomeDef.home.open`, Interiors.thresholds); the rest stay shut.
##
## Precarious, and it looks it: one room, no hearth (smoke would be seen), dark
## (InteriorKind.dark), a bedroll on the floor, a tarp over the one window, a
## strip lamp stolen off the machines' own lines the only light, water in
## buckets, a crate for a table -- and a SECOND WAY OUT, a hole broken through
## the back wall and hidden behind a sheet, that puts whoever crawls through it
## out behind the house rather than at its door (21_doors `exit`).
##
## Laid in the canonical frame: the way in is in the south wall (+y).

const ROOM := Rect2i(0, 0, 5, 4)


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"squat"
	# A tarp over the window: the day comes in only round its edges.
	k.closed = 0.9
	k.dark = 0.7
	k.zoom = 8.5
	k.wall_h = 2.4
	k.cut = 0.8
	k.door_width = 0.9
	# Its words are its landscape's (a squat's slot opens where they are written).
	k.by_land = true
	k.recipe = load("res://src/content/interiors/squat.gd")
	k.model = "res://src/models/interior/cottage_model.gd"
	return k


static func lay(rng: RandomNumberGenerator, land: int = -1) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"squat"
	# How long it has been lived in: a bedroll alone, or a second one.
	l.dressing = [&"one", &"two"][rng.randi_range(0, 1)]
	l.has_hearth = false
	l.rooms.append(ROOM)
	l.door = Vector2(1.5, 4)
	l.door_out = Vector2(0, 1)
	l.hearth = Vector2(2.5, 2.0)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(3.4, 2.4)
	l.lay_edges()
	for e: Dictionary in l.edges:
		var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif m.distance_to(window_at()) < 0.1:
			e.kind = &"window"
	_fit(l, land)
	return l


## The one window, in the east wall, under its tarp.
static func window_at() -> Vector2:
	return Vector2(ROOM.end.x, 1.5)


## The hole through the back wall: stood at from inside, it is the way out
## behind the house.
static func crawl_at() -> Vector2:
	return Vector2(3.5, 0.36)


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _fit(l: InteriorLayout, land: int) -> void:
	_put(l, &"tarp", window_at() - Vector2(0.36, 0.0), Vector2(-1, 0), 0.0)
	_put(l, &"bedroll", Vector2(0.9, 1.0), Vector2(1, 0), 0.0)
	if l.dressing == &"two":
		_put(l, &"bedroll", Vector2(0.9, 2.4), Vector2(1, 0), 0.0)
	_put(l, &"machine_lamp", Vector2(2.2, 0.36), Vector2(0, 1), 0.0)
	_put(l, &"buckets", Vector2(4.5, 3.4), Vector2(-1, 0), 0.3)
	_put(l, &"chest", l.table, Vector2(0, 1), 0.28)
	_put(l, &"crawl_hole", crawl_at(), Vector2(0, 1), 0.0, {"exit": true})
	if not StoryRooms.words_for(&"squat", &"wall:squat", land, l.dressing).is_empty():
		l.slots.append({"slot": &"wall", "thing": &"squat", "at": crawl_at(), "face": Vector2(0, 1)})
	l.walks.append(PackedVector2Array([l.door, crawl_at() + Vector2(0.0, 0.8)]))
