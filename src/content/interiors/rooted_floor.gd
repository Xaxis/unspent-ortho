extends RefCounted
## THE STANDING FLOOR OF A FALLEN TOWER IN GREEN TOWERS, lived in (docs/
## interiors; the form outside is props/towers.gd `shell`). The storeys above
## came down; this one stood, and the forest came up through it. A trunk rises
## out of a break in the slab and goes out through a hole in the ceiling where
## the day comes down it; its roots have split the floor and run over it; moss
## has the concrete, ferns the cracks, vines hang from the slab's edge. The
## people who live here closed the frame's gaps with plate and board, laid their
## fire on a stone, and sleep on a platform woven up off the floor. This is the
## one place the plan was beaten without a fight, and it feels like it.
##
## Dealt per door off its own hash:
##   the PLAN      `open`  the trunk off to one side, the room round it
##                 `split` the trunk nearer the middle, the room its ring
##   the HOUSEHOLD `gatherer` baskets of what the canopy gives, gourds
##                 `grower`   seedlings in whatever holds earth, under the light
##                 `climber`  rope, and a line of pegs driven up the trunk
## STORY SLOTS: marks cut in the bark (&"wall") and the platform (&"desk").
## Laid in the canonical frame: the way in is in the south wall (+y).

const Cottage := preload("res://src/content/interiors/cottage.gd")
const PLANS: Array[StringName] = [&"open", &"split"]
const HOUSEHOLDS: Array[StringName] = [&"gatherer", &"grower", &"climber"]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"rooted_floor"
	# Under a slab with a hole in it: the day comes down the trunk, green.
	k.closed = 0.6
	k.zoom = 9.5
	k.wall_h = 2.9
	k.cut = 0.9
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/rooted_floor.gd")
	k.model = "res://src/models/interior/rooted_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = PLANS[rng.randi_range(0, PLANS.size() - 1)]
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	l.has_hearth = false
	var w := rng.randi_range(7, 8)
	var d := 6
	l.rooms.append(Rect2i(0, 0, w, d))
	var dx := rng.randi_range(2, w - 3)
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	var east := dx * 2 < w
	# The trunk: to the side away from the door, back from it.
	var tx := (float(w) - 2.0) if east else 2.0
	if l.plan == &"split":
		tx = float(w) * 0.5 + (0.8 if east else -0.8)
	var trunk := Vector2(tx, 2.2)
	# The fire on its stone across from the trunk, the table (a plank on
	# salvage) between it and the door.
	l.hearth = Vector2((1.6 if east else float(w) - 1.6), 2.4)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(float(dx) + 0.5 + (0.9 if east else -0.9), float(d) - 2.0)
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": Vector2(0, 1)})
	l.props.append({"kind": PropKind.BENCH, "at": l.table, "face": Vector2(1, 0)})
	l.lay_edges()
	_openings(l, w, d)
	_furnish(l, rng, w, d, trunk, east)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


## The way in, and the frame's gaps left open to the canopy on the side walls.
static func _openings(l: InteriorLayout, w: int, d: int) -> void:
	for e: Dictionary in l.edges:
		if Cottage._mid(e).distance_to(l.door) < 0.1:
			e.kind = &"door"
	for dir: Vector2 in [Vector2(-1, 0), Vector2(1, 0)]:
		var want := Vector2(float(w) * 0.5, float(d) * 0.5 + 0.5) + dir * float(w) * 0.5
		var best: Dictionary = {}
		for e: Dictionary in l.edges:
			if e.kind != &"wall" or not (e.out as Vector2).is_equal_approx(dir):
				continue
			if Cottage._mid(e).distance_to(l.hearth) < 1.5:
				continue
			if best.is_empty() or Cottage._mid(e).distance_to(want) < Cottage._mid(best).distance_to(want):
				best = e
		if not best.is_empty():
			best.kind = &"window"


static func _furnish(l: InteriorLayout, rng: RandomNumberGenerator, w: int, d: int, trunk: Vector2, east: bool) -> void:
	_put(l, &"trunk", trunk, Vector2(0, 1), 0.62)
	l.slots.append({"slot": &"wall", "at": trunk, "face": (l.door - trunk).normalized()})
	_put(l, &"roots", trunk, Vector2(0, 1), 0.0)
	_put(l, &"vines", trunk, Vector2(0, 1), 0.0)
	# The platform, woven up off the floor in the back corner away from the fire.
	var nest := Vector2((float(w) - 1.1) if not east else 1.1, 1.1)
	if nest.distance_to(trunk) < 2.2:
		nest = Vector2(nest.x, float(d) - 1.9)
	_put(l, &"nest", nest, Vector2(1, 0), 0.5, {"deep": 1.6})
	l.slots.append({"slot": &"desk", "at": nest, "face": (Vector2(float(w), float(d)) * 0.5 - nest).normalized()})
	# The basin under the drip, by the trunk where the rain runs down it.
	_put(l, &"basin", trunk + (l.door - trunk).normalized() * 1.0 + Vector2(0.6, 0.0), Vector2(0, 1), 0.2)
	# Against the walls, what the household lives by.
	var slots := Cottage._slots(l)
	var keep: Array[Dictionary] = []
	for s: Dictionary in slots:
		var at: Vector2 = s.at
		if at.distance_to(trunk) > 1.6 and at.distance_to(nest) > 1.4 and at.distance_to(l.hearth) > 1.3:
			keep.append(s)
	var wants: Array[StringName] = [&"basket", &"chest"]
	match l.dressing:
		&"gatherer":
			wants.append_array([&"gourds", &"basket", &"gourds"])
		&"grower":
			wants.append_array([&"seedlings", &"seedlings", &"basket"])
		_:
			wants.append_array([&"coil", &"basket"])
			_put(l, &"pegs", trunk, Vector2(0, 1), 0.0)
	for kind: StringName in wants:
		var s := Cottage._take(keep, rng)
		if s.is_empty():
			break
		_put(l, kind, s.at, s.face, _solid(kind))
	l.walks.append(PackedVector2Array([l.door, l.table + Vector2(0, 0.8)]))
	l.walks.append(PackedVector2Array([l.door, l.hearth + Vector2(0, 1.1)]))
	l.walks.append(PackedVector2Array([l.hearth + Vector2(0, 1.1), trunk + (l.door - trunk).normalized() * 1.1]))


static func _solid(kind: StringName) -> float:
	match kind:
		&"chest", &"basket":
			return 0.28
		&"gourds", &"seedlings":
			return 0.26
		&"coil":
			return 0.22
	return 0.0
