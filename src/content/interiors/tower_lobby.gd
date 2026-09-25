extends RefCounted
## A TOWER'S LOBBY IN THE RUINED METROPOLIS, lived in (docs/interiors; the form
## outside is props/metropolis.gd `infill`). The ground floor of a dead tower,
## its cast columns still holding up the slab, walled in between them with
## doors taken from every floor above. Somebody made a home in the lobby of a
## place that sold the future: the reception counter is their kitchen, the
## letterboxes their shelves, the lift doors are prised open on a shaft of dark
## and the stair is choked with what came down it. Their light is a tube taken
## off the machines' own street furniture, wired to a battery; their fire is in
## the middle of the stone floor, and its smoke has blackened the slab.
##
## Dealt per door off its own hash:
##   the PLAN      `open` the lobby as it stood, a stall walled off in a corner
##                 `halls` two stalls, the columns between them hung with cloth
##   the HOUSEHOLD `picker` who strips the towers: bales of wire, sorted scrap
##                 `grower`  who grows under the tube: trays of greens, jars
##                 `keeper`  who keeps the old place: its chairs, its signs
## STORY SLOTS: the letterboxes, the counter and the lift doors (docs/STORY.md).
##
## Laid in the canonical frame: the way in is in the south wall (+y).

const Cottage := preload("res://src/content/interiors/cottage.gd")
const PLANS: Array[StringName] = [&"open", &"halls"]
const HOUSEHOLDS: Array[StringName] = [&"picker", &"grower", &"keeper"]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"tower_lobby"
	# Shut in: light only where the walls have gaps, the slab a hole, and the
	# tube. At 0.5 it was lit evenly from nowhere, a showroom (InteriorKind).
	k.closed = 0.78
	k.zoom = 10.0
	k.wall_h = 3.2
	k.cut = 0.9
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/tower_lobby.gd")
	k.model = "res://src/models/interior/lobby_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = PLANS[rng.randi_range(0, PLANS.size() - 1)]
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	l.has_hearth = false
	var w := 9
	var d := 7
	l.rooms.append(Rect2i(0, 0, w, d))
	var dx := rng.randi_range(3, w - 4)
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	# The fire on the floor between the columns, off the way in.
	l.hearth = Vector2(w * 0.5 + (1.0 if dx * 2 < w else -1.0), d * 0.5 + 0.3)
	l.hearth_wall = Vector2(0, -1)
	l.table = l.hearth + Vector2(0, 1.4)
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": Vector2(0, 1)})
	l.lay_edges()
	_openings(l)
	_furnish(l, rng, w, d, dx)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


## The way in, and a gap in the doors of each side wall where the day comes in.
static func _openings(l: InteriorLayout) -> void:
	for e: Dictionary in l.edges:
		if Cottage._mid(e).distance_to(l.door) < 0.1:
			e.kind = &"door"
	var r := l.rooms[0]
	for dir: Vector2 in [Vector2(-1, 0), Vector2(1, 0)]:
		var want := Vector2(r.position) + Vector2(r.size) * 0.5 + dir * Vector2(r.size) * 0.5 + Vector2(0, 1.0)
		var best: Dictionary = {}
		for e: Dictionary in l.edges:
			if e.kind != &"wall" or not (e.out as Vector2).is_equal_approx(dir):
				continue
			if best.is_empty() or Cottage._mid(e).distance_to(want) < Cottage._mid(best).distance_to(want):
				best = e
		if not best.is_empty():
			best.kind = &"window"


static func _furnish(l: InteriorLayout, rng: RandomNumberGenerator, w: int, d: int, dx: int) -> void:
	var east := dx * 2 < w
	var far_x := float(w) - 1.2 if east else 1.2
	var near_x := 1.2 if east else float(w) - 1.2
	# The columns: the tower's grid, three bays by two, still standing.
	for cx: float in [3.0, 6.0]:
		for cy: float in [2.3, 4.7]:
			_put(l, &"column", Vector2(cx, cy), Vector2(0, 1), 0.28)
	# The stair in the back corner on the far side, choked with rubble from the
	# floors above; beside it the lift, its doors prised apart.
	_put(l, &"stair", Vector2(far_x, 1.2), Vector2(0, 1), 0.62, {"deep": 1.3})
	var lift := Vector2(far_x + (-2.0 if east else 2.0), 0.3)
	_put(l, &"lift", lift, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"wall", "at": lift, "face": Vector2(0, 1)})
	# The counter along the near side wall: the kitchen now.
	var side := Vector2(-1, 0) if east else Vector2(1, 0)
	var counter := Vector2(0.75 if east else float(w) - 0.75, 3.0)
	_put(l, &"counter", counter, Vector2(0, 1), 0.36, {"deep": 2.2})
	l.slots.append({"slot": &"desk", "at": counter, "face": -side})
	# The letterboxes on the back wall, the near side.
	var boxes := Vector2(near_x + (0.6 if east else -0.6), 0.3)
	_put(l, &"letterboxes", boxes, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"wall", "at": boxes, "face": Vector2(0, 1)})
	# The stall: a corner walled off with doors on the far side toward the front,
	# a mattress in it and a curtain for its door. Two in the halls plan.
	var stalls: Array[Vector2] = [Vector2(far_x, float(d) - 1.5)]
	if l.plan == &"halls":
		stalls.append(Vector2(near_x, float(d) - 1.5))
	for s: Vector2 in stalls:
		var inward := Vector2(1, 0) if s.x < float(w) * 0.5 else Vector2(-1, 0)
		# Its wall of doors runs from the front wall back, then turns along.
		_put(l, &"partition", s + inward * 1.3 + Vector2(0, -0.2), Vector2(0, 1), 0.14, {"deep": 2.2})
		# The curtain hangs across its open back, from the partition to the wall.
		_put(l, &"curtain", s + inward * 1.3 + Vector2(0, -1.3), -inward, 0.0)
		_put(l, &"mattress", s + Vector2(0, 0.1), inward, 0.0)
	# The light: the stolen tube, on the column nearest the fire.
	var near_col := Vector2(3.0 if l.hearth.x < float(w) * 0.5 else 6.0, 4.7)
	_put(l, &"tube_post", near_col + Vector2(0, -0.3), Vector2(0, -1), 0.0)
	# What they live by, against the walls.
	var slots := Cottage._slots(l)
	var keep: Array[Dictionary] = []
	for s: Dictionary in slots:
		var at: Vector2 = s.at
		var clear := at.distance_to(Vector2(far_x, 1.2)) > 1.8 and at.distance_to(counter) > 1.5 and at.distance_to(boxes) > 1.0
		for st: Vector2 in stalls:
			clear = clear and at.distance_to(st) > 1.8
		if clear:
			keep.append(s)
	var wants: Array[StringName] = [&"shelf", &"chest"]
	match l.dressing:
		&"picker":
			wants.append_array([&"bale", &"coil", &"shelf_salvage", &"bale"])
		&"grower":
			wants.append_array([&"trays", &"jars", &"trays", &"basket"])
		_:
			wants.append_array([&"chair", &"sign", &"jars", &"shelf"])
	for kind: StringName in wants:
		var s := Cottage._take(keep, rng)
		if s.is_empty():
			break
		_put(l, kind, s.at, s.face, _solid(kind))
	_put(l, &"rug", l.hearth + Vector2(0, 1.2), Vector2(0, -1), 0.0)
	l.walks.append(PackedVector2Array([l.door, l.hearth + Vector2(0, 1.0)]))
	l.walks.append(PackedVector2Array([l.hearth, counter + (-side) * 0.8]))
	l.walks.append(PackedVector2Array([l.door, stalls[0] + Vector2(0, -1.4)]))


static func _solid(kind: StringName) -> float:
	match kind:
		&"shelf", &"shelf_salvage", &"jars":
			return 0.26
		&"chest", &"basket":
			return 0.28
		&"bale", &"trays":
			return 0.32
		&"coil":
			return 0.22
		&"chair":
			return 0.25
	return 0.0
