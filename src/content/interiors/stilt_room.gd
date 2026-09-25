extends RefCounted
## A STILT HOUSE IN THE DROWNED CITY, from inside (docs/interiors; the form
## outside is props/drowned_city.gd `stilt_house`). One room of boards on piles
## over the canal, built by people who stayed when the water came and learned
## to live a man's height above it. The water is under the floor: it shows
## green-black between the boards and through the trapdoor, open in one corner,
## where a ladder goes down to the punt tied under the house. The fire is laid
## in a box of sand on the boards, under a hood of the machines' own ducting.
## The windows look out on the water.
##
## Dealt per door off its own hash:
##   the PLAN      `deep` a long room, the hammock across its far end
##                 `square` a squarer room, the hammock in a corner by a window
##   the HOUSEHOLD what the water gives them:
##                 `eeler`   eel traps, a creel, nets on the walls
##                 `salvor`  what they dive for: a shelf of salvage, a coil of
##                           cable brought up, a stolen lamp wired in
##                 `ferrier` oars, floats, a pole: they carry people
## and in every house: the hammock, the trapdoor, buckets under the drips, the
## sand hearth, a lamp over the table, and a post by the door scratched with
## the heights the water came to (a STORY SLOT: what the marks say is the
## story's, docs/STORY.md).
##
## Laid in the canonical frame: the way in is in the south wall (+y).

const Cottage := preload("res://src/content/interiors/cottage.gd")
const PLANS: Array[StringName] = [&"deep", &"square"]
const HOUSEHOLDS: Array[StringName] = [&"eeler", &"salvor", &"ferrier"]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"stilt_room"
	k.closed = 0.45
	k.zoom = 9.0
	k.wall_h = 2.3
	k.cut = 0.8
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/stilt_room.gd")
	k.model = "res://src/models/interior/stilt_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = PLANS[rng.randi_range(0, PLANS.size() - 1)]
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	var w := rng.randi_range(7, 8) if l.plan == &"deep" else rng.randi_range(5, 6)
	var d := 4 if l.plan == &"deep" else 5
	l.rooms.append(Rect2i(0, 0, w, d))
	var dx := rng.randi_range(1, w - 2)
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	# The sand hearth on the back wall, away from the door.
	var hx := clampi(w - 1 - dx + rng.randi_range(-1, 1), 1, w - 2)
	l.hearth = Vector2(hx + 0.5, 0.75)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(w * 0.5 + rng.randf_range(-0.5, 0.5), d * 0.5 + 0.1)
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": l.hearth_wall})
	l.props.append({"kind": PropKind.BENCH, "at": l.table, "face": Vector2(1, 0)})
	l.lay_edges()
	_openings(l)
	_furnish(l, rng, w, d, dx)
	return l


## The door, and a window in the middle of each outside wall but the door's --
## every one of them onto the water -- never where the hearth is.
static func _openings(l: InteriorLayout) -> void:
	for e: Dictionary in l.edges:
		if Cottage._mid(e).distance_to(l.door) < 0.1:
			e.kind = &"door"
	var r := l.rooms[0]
	var centre := Vector2(r.position) + Vector2(r.size) * 0.5
	for dir: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
		var want := centre + dir * Vector2(r.size) * 0.5
		var best: Dictionary = {}
		for e: Dictionary in l.edges:
			if e.kind != &"wall" or not (e.out as Vector2).is_equal_approx(dir):
				continue
			var m := Cottage._mid(e)
			if m.distance_to(l.hearth) < 1.6:
				continue
			if best.is_empty() or m.distance_to(want) < Cottage._mid(best).distance_to(want):
				best = e
		if not best.is_empty():
			best.kind = &"window"


static func _furnish(l: InteriorLayout, rng: RandomNumberGenerator, w: int, d: int, dx: int) -> void:
	var east := dx * 2 < w
	# The trapdoor, open, in the corner of the door's wall away from the door.
	var trap := Vector2(w - 0.85 if east else 0.85, d - 0.85)
	_put(l, &"trapdoor", trap, Vector2(0, -1), 0.5)
	# The hammock along the side wall away from the hearth, slung from the posts
	# at its ends: a body goes round it, never under.
	var hx := 0.62 if l.hearth.x > w * 0.5 else w - 0.62
	var hy := 1.4 if l.plan == &"deep" else 1.6
	_put(l, &"hammock", Vector2(hx, hy), Vector2(0, 1), 0.34, {"deep": 1.7})
	var across := Vector2(-l.door_out.y, l.door_out.x)
	var side := 1.0 if east else -1.0
	# By the door: the post the water's heights are scratched on.
	var post := l.door - l.door_out * 0.35 - across * side * 0.72
	_put(l, &"gauge", post, -l.door_out, 0.12)
	l.slots.append({"slot": &"wall", "at": post, "face": -l.door_out})
	_put(l, &"boots", l.door - l.door_out * 0.55 + across * side * 0.72, -l.door_out, 0.0)
	_put(l, &"lamp", l.table, Vector2(0, 1), 0.0)
	_put(l, &"rug", l.hearth - l.hearth_wall * 1.5, l.hearth_wall, 0.0)
	# Whatever stands against the walls, off the slots the cottage keeps.
	var slots := Cottage._slots(l)
	var keep: Array[Dictionary] = []
	for s: Dictionary in slots:
		if (s.at as Vector2).distance_to(trap) > 1.3 and (s.at as Vector2).distance_to(Vector2(hx, hy)) > 1.3:
			keep.append(s)
	var wants: Array[StringName] = [&"bucket", &"shelf", &"chest"]
	match l.dressing:
		&"eeler":
			wants.append_array([&"eeltrap", &"nets", &"creel", &"eeltrap"])
		&"salvor":
			wants.append_array([&"shelf_salvage", &"coil", &"machine_lamp", &"bucket"])
		_:
			wants.append_array([&"oars", &"floats", &"pole", &"nets"])
	for kind: StringName in wants:
		var s := Cottage._take(keep, rng)
		if s.is_empty():
			break
		_put(l, kind, s.at, s.face, _solid(kind))
	l.walks.append(PackedVector2Array([l.door, l.hearth - l.hearth_wall * 1.2]))
	l.walks.append(PackedVector2Array([l.door, l.table]))
	l.walks.append(PackedVector2Array([l.door, trap + Vector2(0, -0.6)]))


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _solid(kind: StringName) -> float:
	match kind:
		&"shelf", &"shelf_salvage":
			return 0.26
		&"chest", &"creel", &"eeltrap":
			return 0.28
		&"coil", &"bucket":
			return 0.2
	return 0.0
