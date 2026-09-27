extends RefCounted
## A GROWER'S HOUSE IN THE GREY ORCHARDS, from inside (docs/interiors; the host
## is any house there). The orchards are "the only landscape where the machines
## are FEEDING somebody, and there is nobody left to feed" (grey_orchards.gd):
## this is where they still do. The table is laid for four and kept laid; a hatch
## in the kitchen wall puts a hot meal out at every mealtime and takes the last
## one away uneaten; the beds are made; a hum at the door seals keeps the spore
## mist out. Nothing in here hunts. That is the horror of it.
##
## THE HATCH IS REAL FOOD on the machines' schedule (21_doors `serves`/`meals`):
## at seven, noon and six a meal is put out, and it waits for its household until
## the next. Taken, it is taken for that meal.
##
## Dealt per door: the HOUSEHOLD the machines are keeping it for (`four` a family,
## `two` a couple and their old one's empty chair, `nursery` a child still small
## enough to be fed by hand) -- what is at the places and in the beds.
##
## STORY SLOTS: the table (`desk:laid_table`), the schedule plate by the hatch
## (`wall:schedule_plate`), and the height marks on the bedroom's door frame
## (`wall:height_marks`). Laid in the canonical frame: the way in is in the south
## wall (+y).

const KITCHEN := Rect2i(0, 0, 5, 4)
const BEDROOM := Rect2i(5, 0, 3, 4)
const HOUSEHOLDS: Array[StringName] = [&"four", &"two", &"nursery"]
## What the hatch puts out, and when (hours).
const MEAL := {&"soup": 1, &"bread": 1}
const MEALS: Array[int] = [7, 12, 18]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"laid_table"
	# A house the machines keep: windows shuttered against the mist, lit inside.
	k.closed = 0.8
	k.zoom = 9.0
	k.wall_h = 2.4
	k.cut = 0.8
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/laid_table.gd")
	k.model = "res://src/models/interior/laid_table_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"kept"
	l.dressing = HOUSEHOLDS[rng.randi_range(0, HOUSEHOLDS.size() - 1)]
	l.has_hearth = false
	l.rooms.append(KITCHEN)
	l.rooms.append(BEDROOM)
	l.door = Vector2(2.5, 4)
	l.door_out = Vector2(0, 1)
	# No fire: the hatch is where the heat comes from.
	l.hearth = Vector2(1.0, 0.4)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(2.3, 2.0)
	l.lay_edges()
	var inner := Vector2(5, 2.5)
	for e: Dictionary in l.edges:
		var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and m.distance_to(inner) < 0.1:
			e.kind = &"inner"
	_fit(l)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _fit(l: InteriorLayout) -> void:
	# The table, laid, with a chair at each place -- or, for a couple, the old
	# one's chair drawn in and its place still set.
	_put(l, &"laid_table", l.table, Vector2(0, 1), 0.5, {"long": 1.4})
	l.slots.append({"slot": &"desk", "at": l.table, "face": Vector2(0, 1)})
	for p: Vector2 in [Vector2(-0.45, -0.75), Vector2(0.45, -0.75), Vector2(-0.45, 0.75), Vector2(0.45, 0.75)]:
		var face := Vector2(0, 1) if p.y < 0.0 else Vector2(0, -1)
		_put(l, &"chair", l.table + p, face, 0.0)
	# The hatch in the kitchen's back wall and its schedule plate beside it.
	var hatch := Vector2(1.0, 0.36)
	_put(l, &"food_hatch", hatch, Vector2(0, 1), 0.0, {"serves": MEAL, "meals": MEALS})
	var plate := Vector2(1.9, 0.36)
	_put(l, &"schedule_plate", plate, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"wall", "at": plate, "face": Vector2(0, 1)})
	# The dresser, the sink, and the lamp over the table the machines keep lit.
	_put(l, &"dresser", Vector2(4.6, 0.8), Vector2(-1, 0), 0.3)
	_put(l, &"sink", Vector2(3.4, 0.4), Vector2(0, 1), 0.3)
	# The height marks on the bedroom's door frame, on the kitchen side.
	var marks := Vector2(4.64, 3.2)
	_put(l, &"height_marks", marks, Vector2(-1, 0), 0.0)
	l.slots.append({"slot": &"wall", "at": marks, "face": Vector2(-1, 0)})
	# The beds, made: two along the far wall, two against the back.
	_put(l, &"bed", Vector2(7.3, 1.0), Vector2(-1, 0), 0.5)
	_put(l, &"bed", Vector2(7.3, 3.1), Vector2(-1, 0), 0.5)
	if l.dressing != &"two":
		_put(l, &"cot", Vector2(5.7, 0.6), Vector2(0, 1), 0.3)
	# The door seal: what keeps the mist out, and hums.
	_put(l, &"door_seal", l.door, Vector2(0, -1), 0.0)
	l.walks.append(PackedVector2Array([l.door, l.table + Vector2(0.0, 1.2)]))
	l.walks.append(PackedVector2Array([l.table + Vector2(0.0, 1.2), Vector2(4.4, 2.5), Vector2(6.0, 2.5)]))
