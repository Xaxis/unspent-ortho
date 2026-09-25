extends RefCounted
## THE HOLD OF A HULK IN THE DROWNED CITY, lived in (docs/interiors; the form
## outside is props/drowned_city.gd `hulk_home`). A steel barge nobody moves any
## more, moored for good: down the companion ladder from the deck is its hold,
## the hull's ribs standing up both sides like a whale's, the plate between them
## rolled in the machines' age and riveted, portholes along the waterline. The
## boards laid across the floor keep feet out of the bilge. Light comes down the
## open hatch in the deck, through the portholes, and from a tube somebody wired
## to a battery; the fire is laid in an oil drum cut down to a brazier, under a
## hood whose pipe goes out through the deck.
##
## Dealt per door off its own hash:
##   the PLAN      `open`     one long hold
##                 `bulkhead` the fore end walled off by the hull's own bulkhead,
##                            its oval door hooked open, and the hammocks there
##   the HOUSEHOLD `salvor`   who dives the drowned streets: a diving helmet on a
##                            hook, a coil of line, a shelf of what came up
##                 `grower`   greens in tins set out under the hatch, where the
##                            light falls
##                 `ferrier`  oars, floats and nets: they carry people
## STORY SLOTS: the hull's builder's plate by the ladder (&"wall") and the table
## (&"desk"). Laid in the canonical frame: the way in is in the south wall (+y).

const Cottage := preload("res://src/content/interiors/cottage.gd")
const PLANS: Array[StringName] = [&"open", &"bulkhead"]
const HOUSEHOLDS: Array[StringName] = [&"salvor", &"grower", &"ferrier"]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"hulk_hold"
	# Below the deck: dim, the hatch and the portholes its daylight.
	k.closed = 0.6
	k.zoom = 9.0
	k.wall_h = 2.3
	k.cut = 0.8
	k.door_width = 0.8
	k.recipe = load("res://src/content/interiors/hulk_hold.gd")
	k.model = "res://src/models/interior/hulk_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = PLANS[rng.randi_range(0, PLANS.size() - 1)]
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	l.has_hearth = false
	var w := rng.randi_range(8, 9)
	var d := 4
	var aft_left := rng.randf() < 0.5
	if l.plan == &"bulkhead":
		var main_w := w - 3
		if aft_left:
			l.rooms.append(Rect2i(0, 0, main_w, d))
			l.rooms.append(Rect2i(main_w, 0, 3, d))
		else:
			l.rooms.append(Rect2i(3, 0, main_w, d))
			l.rooms.append(Rect2i(0, 0, 3, d))
	else:
		l.rooms.append(Rect2i(0, 0, w, d))
	# The companion ladder comes down at the aft end.
	var dx := 1 if aft_left else w - 2
	l.door = Vector2(dx + 0.5, d)
	l.door_out = Vector2(0, 1)
	# The stove against the far side, amidships; the table under the hatch.
	var mid := float(w) * 0.5
	l.hearth = Vector2(mid + (0.5 if aft_left else -0.5), 0.85)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(mid + (-1.0 if aft_left else 1.0), float(d) * 0.5 + 0.2)
	# The hearth is the world's own fire (lit, cooked at, slept beside), laid in
	# the brazier the model draws round it.
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": Vector2(0, 1)})
	l.props.append({"kind": PropKind.BENCH, "at": l.table, "face": Vector2(1, 0)})
	l.lay_edges()
	_openings(l, w, d)
	_furnish(l, rng, w, d, aft_left)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


## The companion's door, portholes along both sides every other frame, and the
## bulkhead's oval door.
static func _openings(l: InteriorLayout, w: int, d: int) -> void:
	for e: Dictionary in l.edges:
		var m := Cottage._mid(e)
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner:
			continue
		elif absf((e.out as Vector2).y) > 0.5 and int(floor(m.x)) % 2 == 1 and m.distance_to(l.door) > 1.6 and m.distance_to(l.hearth) > 1.2:
			e.kind = &"window"
	if l.rooms.size() > 1:
		var best: Dictionary = {}
		for e: Dictionary in l.edges:
			if e.inner and (best.is_empty() or absf(Cottage._mid(e).y - float(d) * 0.5) < absf(Cottage._mid(best).y - float(d) * 0.5)):
				best = e
		if not best.is_empty():
			best.kind = &"inner"


static func _furnish(l: InteriorLayout, rng: RandomNumberGenerator, w: int, d: int, aft_left: bool) -> void:
	var fore := Vector2(-1, 0) if not aft_left else Vector2(1, 0)
	_put(l, &"stove", l.hearth, Vector2(0, 1), 0.0)
	_put(l, &"lamp_tube", Vector2(l.table.x, float(d) * 0.5), Vector2(1, 0), 0.0)
	# The builder's plate riveted by the ladder.
	var plate := l.door - l.door_out * 0.14 + Vector2(-fore.x * 0.7, 0.0)
	_put(l, &"builders_plate", plate, -l.door_out, 0.0)
	l.slots.append({"slot": &"wall", "at": plate, "face": -l.door_out})
	l.slots.append({"slot": &"desk", "at": l.table, "face": Vector2(0, -1)})
	# The hammocks, fore, slung fore and aft along the hull's sides the way a
	# ship's are, the way clear between them: in the bulkhead's cabin when there
	# is one. Side by side across a three-wide cabin they boxed a body out.
	var fore_room := l.rooms[1] if l.rooms.size() > 1 else l.rooms[0]
	var hx := float(fore_room.position.x) + (float(fore_room.size.x) - 1.5 if fore.x > 0.0 else 1.5)
	_put(l, &"hammock", Vector2(hx, 0.75), Vector2(1, 0), 0.34, {"deep": 1.9})
	if l.rooms.size() > 1:
		_put(l, &"hammock", Vector2(hx, float(d) - 0.75), Vector2(1, 0), 0.34, {"deep": 1.9})
	# The bilge hatch in the boards, aft of the table and off the way.
	var bilge := Vector2(l.table.x - fore.x * 1.6, 0.9)
	_put(l, &"trapdoor", bilge, Vector2(0, 1), 0.5)
	# What the household lives by, against the hull.
	var slots := Cottage._slots(l)
	var keep: Array[Dictionary] = []
	for s: Dictionary in slots:
		var at: Vector2 = s.at
		if absf(at.x - hx) > 1.4 and at.distance_to(bilge) > 1.2 and at.distance_to(l.hearth) > 1.1:
			keep.append(s)
	var wants: Array[StringName] = [&"bucket", &"chest"]
	match l.dressing:
		&"salvor":
			wants.append_array([&"helmet", &"coil", &"shelf_salvage"])
		&"grower":
			wants.append_array([&"tins", &"tins", &"basket"])
		_:
			wants.append_array([&"oars", &"floats", &"nets"])
	for kind: StringName in wants:
		var s := Cottage._take(keep, rng)
		if s.is_empty():
			break
		_put(l, kind, s.at, s.face, _solid(kind))
	l.walks.append(PackedVector2Array([l.door, l.table + Vector2(0, 0.8)]))
	l.walks.append(PackedVector2Array([l.table + Vector2(0, 0.8), Vector2(hx, float(d) * 0.5)]))


static func _solid(kind: StringName) -> float:
	match kind:
		&"shelf_salvage":
			return 0.26
		&"chest", &"basket":
			return 0.28
		&"coil", &"bucket":
			return 0.2
		&"tins":
			return 0.24
	return 0.0
