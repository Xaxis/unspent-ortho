extends RefCounted
## THE FOUNDRY UNDER THE BURNING'S WORKS (docs/interiors): where the machines
## MAKE what they fight with, as the coast's weapons hall is where they keep it.
## The refinery above feeds it (content/biomes/burning.gd: "refineries and slag
## runs the machines put in it still working"), and it is still working.
##
## Built for machines, not people: a hatch they come through, a line the length
## of the hall -- the furnace at its head, the pour channel running along it with
## moulds riding under the spout, the quench tank at its end -- and the cast
## bodies racked to cool in a wall of racks to the ceiling. Nothing is lit but
## what the machines need to see: the pour. So THE POUR'S LIGHT IS WHAT SHOWS YOU
## (InteriorKind.dark, the line's `glare`): away from it a body is hard to see,
## in it a body is plain, and a lamp lit in here is the pour carried in a hand.
##
## TWO WAYS TO THE STORE, as in the hall. QUIET: in at the hatch under the sweep
## of the turret over the furnace, and down behind the cooling racks, which stand
## to the ceiling between the line and the south wall, out of the pour's light
## and out of the turrets' lines (21_doors `_screens`), to the store's door at
## the far end. LOUD: along the line, at the warden that stands watching the
## pour. While it stands, the turrets fire and the store's box stays shut;
## broken, both let go (21_doors, as for the hall).
##
## What the store keeps (Interiors.LOOT `foundry`): the burning's glass, and the
## lance body the line was pouring -- what a lance is built on.
##
## STORY SLOTS: the line's panel at a sensor's height (`terminal:line_panel`) and
## the cooling racks (`wall:cast_rack`). Laid in the canonical frame: the way in
## is in the south wall (+y).

const HALL := Rect2i(0, 0, 12, 7)
const STORE := Rect2i(12, 4, 3, 3)
## The line: its middle, its length along the hall, how far the pour lights.
## It divides the hall: the furnace closes its head against the west wall, and
## the one way round it is at its end, past the quench -- where the warden is.
const LINE_AT := Vector2(6.0, 2.6)
const LINE_LONG := 7.0
const GLARE := 2.2
## The cooling racks: between the line and the south wall, the passage behind.
const RACKS_AT := Vector2(6.5, 4.8)
const RACKS_LONG := 7.0


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"foundry"
	k.closed = 1.0
	# Away from the pour, darker than any night outside.
	k.dark = 0.85
	k.zoom = 12.0
	k.wall_h = 3.4
	k.cut = 1.0
	# A hauler comes through with a load of castings; a harvester does not.
	k.door_width = 1.3
	k.recipe = load("res://src/content/interiors/foundry.gd")
	k.model = "res://src/models/interior/foundry_model.gd"
	k.hatch = "res://src/models/interior/hatch_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"line"
	# What the line is pouring today; the store keeps the lance body whatever it is.
	l.dressing = [&"lances", &"plate", &"barrels"][rng.randi_range(0, 2)]
	l.has_hearth = false
	l.rooms.append(HALL)
	l.rooms.append(STORE)
	l.door = Vector2(1.5, 7)
	l.door_out = Vector2(0, 1)
	# The heart of the room is the pour.
	l.hearth = LINE_AT
	l.hearth_wall = Vector2(0, -1)
	l.table = LINE_AT
	l.lay_edges()
	var store_door := Vector2(STORE.position.x, 5.5)
	for e: Dictionary in l.edges:
		var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and m.distance_to(store_door) < 0.1:
			e.kind = &"inner"
	_fit(l, rng)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _fit(l: InteriorLayout, rng: RandomNumberGenerator) -> void:
	# The line: the furnace at its head, the pour channel along it lighting the
	# hall round it, the quench at its end; a crane over it on the ceiling.
	_put(l, &"furnace", Vector2(1.0, LINE_AT.y), Vector2(1, 0), 0.7, {"glare": 1.6})
	_put(l, &"line", LINE_AT, Vector2(0, 1), 0.35, {"long": LINE_LONG, "glare": GLARE})
	_put(l, &"quench", Vector2(10.3, LINE_AT.y), Vector2(-1, 0), 0.5)
	_put(l, &"crane", LINE_AT, Vector2(0, 1), 0.0, {"long": LINE_LONG})
	# The cooling racks, to the ceiling, facing the line: the wall the quiet way
	# goes behind.
	_put(l, &"cast_rack", RACKS_AT, Vector2(0, -1), 0.3, {"long": RACKS_LONG, "screens": true})
	l.slots.append({"slot": &"wall", "at": RACKS_AT, "face": Vector2(0, -1)})
	# The line's panel on the north wall, at the height a machine's sensor is.
	var panel := Vector2(LINE_AT.x, 0.36)
	_put(l, &"line_panel", panel, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"terminal", "at": panel, "face": Vector2(0, 1)})
	# Turrets high in the north corners, over the furnace and over the quench:
	# the one over the furnace sweeps the hatch, the one over the quench the
	# store's door; neither sees through the racks.
	for c: Vector2 in [Vector2(0.6, 0.6), Vector2(HALL.end.x - 0.6, 0.6)]:
		var inward := (Vector2(HALL.size) * 0.5 + Vector2(0.0, 1.0) - c).normalized()
		_put(l, &"turret", c, inward, 0.0)
	# The store: its box against the far wall.
	_put(l, &"strongbox", Vector2(STORE.end.x - 0.52, STORE.position.y + 1.5), Vector2(-1, 0), 0.36)
	# The warden stands its watch at the line's end, watching the pour go down
	# it -- the store at its back, the racks between it and the quiet way.
	var post := Vector2(9.4, 1.3)
	_put(l, &"post", post, Vector2(-1, 0), 0.0)
	l.residents.append({"role": &"warden", "at": post, "face": Vector2(-1, 0)})
	# And one at the furnace, watching the pour come out of it.
	if rng.randf() < 0.7:
		l.residents.append({"role": &"guard", "at": Vector2(2.6, 1.1), "face": Vector2(1, 0)})
	l.walks.append(PackedVector2Array([l.door, Vector2(1.5, 5.9), Vector2(10.9, 5.9), store_door_in()]))


## A step inside the store's doorway.
static func store_door_in() -> Vector2:
	return Vector2(STORE.position.x + 0.8, 5.5)
