extends RefCounted
## THE FACE SETTLEMENT, behind a mouth in a junction room's wall in the middens
## (docs/MIDDENS_ROOMS.md §2). The people of the middens live IN the walls:
## rooms cut back into the refuse, the face their street and the heap their
## town. It is the middens' village, and the only one it has.
##
## THE PLAN, laid in the canonical frame (the mouth in the south wall, +y):
## - the SORT, one wide room behind the mouth, a long table down it where what
##   is dug out is read and sorted, and a brazier at its back (smoke out
##   through the plateau above);
## - a back row cut further in: two family CELLS and between them the WORDS
##   ROOM, the settlement's store of everything with writing on it, shelved;
## - by hash, a cell to either side of the sort as well (`two`, `three`,
##   `four` cells in all);
## - the LOOKOUT, a small room RISE levels up at a front corner, up a ladder
##   (Climb takes it), with a slit in the face looking along the slot.
##
## THE HOUSEHOLDS are the middens' own (BiomeDef.home): each cell is kept by
## one, and the READER, who keeps what has words in it, is always among them.
## Each cell holds its household's wanted pieces (Furnish) and a bedroll, and
## the reader is at home by their desk: a DWELLER (21_doors), a person the use
## key talks to.
##
## THE STRING IS EARNED, NEVER SOLD (the rulings). The reader WANTS a filed
## record, what the warrens' boxes keep (Interiors.LOOT `container_warren`):
## brought one, they take it and GIVE the string, a ball of it laid from this
## door to the nearest ramp up out of the slots (SlotRoute), which the map draws
## while it is carried. Once per settlement (21_doors `dweller_deed`).
##
## STORY SLOTS: the sort table (`desk:the_sort`), the words room's shelves
## (`wall:words_room`), the lookout's slit (`wall:lookout`), the reader's desk
## (`desk:reader`) and each other household's wall (`wall:sorter`,
## `wall:wirer`), each opened only where words are written for it in the
## landscape (StoryRooms.words_for).

const Home := preload("res://src/content/interiors/home.gd")
## The sort room, and the rooms cut behind and beside it, in tiles.
const SORT := Vector2i(9, 5)
const CELL := Vector2i(3, 3)
const SIDE := Vector2i(4, 3)
const LOOKOUT := Vector2i(3, 2)
## The lookout's floor over the sort's: a person's height and more, to see over
## the refuse along the slot.
const RISE := 5
## What the reader says: asked before the deed, on it, and after it.
## story: proposed (awaiting review).
const ASKS: Array[String] = [
	"Anything with words in it. The boxes in the walls still have some.",
	"Bring me one and I will lay you the way out.",
]
const THANKS: Array[String] = [
	"A filed record. Somebody kept this, once.",
	"Here. It is laid from our door to the nearest way up. Follow it out.",
]
const AFTER: Array[String] = [
	"Keep the string. It knows the way better than the walls do.",
]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"face_hold"
	# Cut into the heap: the slit and the mouth are all the day there is.
	k.closed = 0.8
	k.zoom = 11.0
	k.wall_h = 2.3
	k.cut = 0.8
	k.door_width = 1.0
	k.by_land = true
	k.recipe = load("res://src/content/interiors/face_hold.gd")
	k.model = "res://src/models/interior/face_hold_model.gd"
	k.hatch = "res://src/models/interior/face_hold_hatch_model.gd"
	return k


static func lay(rng: RandomNumberGenerator, land: int = -1) -> InteriorLayout:
	var l := InteriorLayout.new()
	var households := Home.households_of(land)
	var sides := rng.randi_range(0, 2)
	l.plan = [&"two", &"three", &"four"][sides]
	l.dressing = &"reader"
	l.has_hearth = false
	# The sort, its back wall at y = -SORT.y, the mouth in its south wall at y 0.
	var sort := Rect2i(0, -SORT.y, SORT.x, SORT.y)
	l.rooms.append(sort)
	# The back row: a cell, the words room, a cell, across the sort's width.
	var back_y := -SORT.y - CELL.y
	var cell_a := Rect2i(0, back_y, CELL.x, CELL.y)
	var words := Rect2i(CELL.x, back_y, SORT.x - 2 * CELL.x, CELL.y)
	var cell_b := Rect2i(SORT.x - CELL.x, back_y, CELL.x, CELL.y)
	l.rooms.append(cell_a)
	l.rooms.append(words)
	l.rooms.append(cell_b)
	var cells: Array[Rect2i] = [cell_a, cell_b]
	# Side cells, against the sort's back half: one side, or both.
	var west_first := rng.randf() < 0.5
	var side_rects: Array[Rect2i] = []
	for i in sides:
		var west := west_first if i == 0 else not west_first
		var x := -SIDE.x if west else SORT.x
		side_rects.append(Rect2i(x, -SORT.y, SIDE.x, SIDE.y))
	for r: Rect2i in side_rects:
		l.rooms.append(r)
		cells.append(r)
	# The lookout, at the east front corner, in front of any east cell.
	var lookout := Rect2i(SORT.x, -LOOKOUT.y, LOOKOUT.x, LOOKOUT.y)
	l.rooms.append(lookout)
	for r: Rect2i in l.rooms:
		l.room_ground.append(Ground.FLOOR)
		l.room_level.append(RISE if r == lookout else 0)
	# The mouth: in the sort's south wall, clear of the lookout's corner.
	var dx := rng.randi_range(2, SORT.x - 3)
	l.door = Vector2(dx + 0.5, 0.0)
	l.door_out = Vector2(0, 1)
	# The brazier against the sort's west wall by the mouth, clear of every
	# doorway and of the table's end; the long table down the middle.
	l.hearth = Vector2(0.9, -1.3)
	l.hearth_wall = Vector2(-1, 0)
	l.table = Vector2(SORT.x * 0.5, -SORT.y * 0.5 + 0.2)
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": l.hearth_wall, "variant": PropModels.HELD_FIRE})
	_put(l, &"brazier", l.hearth, -l.hearth_wall, 0.42)
	l.props.append({"kind": PropKind.BENCH, "at": l.table, "face": Vector2(0, 1)})
	l.lay_edges()
	_openings(l, cells, words, lookout)
	_fit(l, rng, land, households, cells, words, lookout)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _mid(e: Dictionary) -> Vector2:
	return ((e.a as Vector2) + (e.b as Vector2)) * 0.5


## The unit of wall the sort shares with `r` nearest the middle of what they
## share: a doorway through it.
static func _doorway(l: InteriorLayout, r: Rect2i) -> Dictionary:
	var sort := l.rooms[0]
	var best: Dictionary = {}
	# The exact middle: Rect2i's rounds a three-wide room's to a corner unit, and
	# a doorway one unit wide at a corner is too tight for a body (the warren's).
	var want := Rect2(r).get_center()
	for e: Dictionary in l.edges:
		if not e.inner:
			continue
		var m := _mid(e)
		var a := m - (e.out as Vector2) * 0.25
		var b := m + (e.out as Vector2) * 0.25
		var joins := (Rect2(sort).has_point(a) and Rect2(r).has_point(b)) or (Rect2(sort).has_point(b) and Rect2(r).has_point(a))
		if joins and (best.is_empty() or m.distance_to(want) < _mid(best).distance_to(want)):
			best = e
	return best


## The mouth, a doorway from the sort into every room cut off it, the lookout's
## riser (open, with its ladder), and the slit in the lookout's face.
static func _openings(l: InteriorLayout, cells: Array[Rect2i], words: Rect2i, lookout: Rect2i) -> void:
	for e: Dictionary in l.edges:
		var m := _mid(e)
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif not e.inner and (e.out as Vector2).is_equal_approx(Vector2(0, 1)) and Rect2(lookout).has_point(m - Vector2(0, 0.25)):
			if absf(m.x - (float(lookout.position.x) + LOOKOUT.x * 0.5)) < 0.6:
				e.kind = &"window"
	for r: Rect2i in cells + [words, lookout]:
		var d := _doorway(l, r)
		if not d.is_empty():
			d.kind = &"inner"
			if r == lookout:
				# Up the riser from the sort, facing (as things do) into the lower room.
				_put(l, &"ladder", _mid(d), _into_sort(l, d), 0.0)


## The way from an edge on the sort's boundary into the sort.
static func _into_sort(l: InteriorLayout, e: Dictionary) -> Vector2:
	var o: Vector2 = e.out
	return o if Rect2(l.rooms[0]).has_point(_mid(e) + o * 0.25) else -o


## A story slot at a thing, if words are written for it here.
static func _slot(l: InteriorLayout, land: int, slot: StringName, thing: StringName, at: Vector2, face: Vector2) -> void:
	if StoryRooms.words_for(&"face_hold", StringName("%s:%s" % [slot, thing]), land, l.dressing).is_empty():
		return
	l.slots.append({"slot": slot, "thing": thing, "at": at, "face": face})


static func _fit(l: InteriorLayout, rng: RandomNumberGenerator, land: int, households: Dictionary, cells: Array[Rect2i], words: Rect2i, lookout: Rect2i) -> void:
	# The sort table, long, down the middle; what is on it today.
	_put(l, &"sort_table", l.table, Vector2(0, 1), 0.5, {"long": float(SORT.x) - 5.0})
	_slot(l, land, &"desk", &"the_sort", l.table, Vector2(0, 1))
	# The words room: shelves on its back wall and both ends.
	var wb := Vector2(float(words.position.x) + words.size.x * 0.5, float(words.position.y) + 0.35)
	_put(l, &"words_shelves", wb, Vector2(0, 1), 0.3, {"wide": float(words.size.x) - 0.4})
	_slot(l, land, &"wall", &"words_room", wb, Vector2(0, 1))
	# The lookout's slit.
	var slit := Vector2(float(lookout.position.x) + LOOKOUT.x * 0.5, float(lookout.end.y) - 0.3)
	_slot(l, land, &"wall", &"lookout", slit, Vector2(0, -1))
	# The cells: the reader in the first, the rest dealt from the landscape's
	# other households.
	var others: Array[StringName] = []
	for id: StringName in households.keys():
		if id != &"reader":
			others.append(id)
	others.sort()
	for i in cells.size():
		var c := cells[i]
		var hh: StringName = &"reader" if i == 0 or others.is_empty() else others[rng.randi_range(0, others.size() - 1)]
		var row: Dictionary = households.get(hh, {})
		var wants: Array = row.get("wants", [])
		# The wall away from the sort: the back wall for the back row, the outer
		# wall for a side cell.
		var back := Vector2(0, 1)
		var wall := Vector2(float(c.position.x) + c.size.x * 0.5, float(c.position.y) + 0.4)
		if c.size == SIDE:
			var west := c.position.x < 0
			back = Vector2(1, 0) if west else Vector2(-1, 0)
			wall = Vector2(float(c.position.x) + 0.4 if west else float(c.end.x) - 0.4, float(c.position.y) + c.size.y * 0.5)
		var along := Vector2(-back.y, back.x)
		var n := mini(2, wants.size())
		for j in n:
			var off := (float(j) - (float(n) - 1.0) * 0.5) * 1.1
			_put(l, wants[j], wall + along * off, back, 0.3, {"household": hh})
		_put(l, &"bedroll", Rect2(c).get_center() + back * 0.5 + along * 0.2, back, 0.0, {"household": hh})
		match hh:
			&"reader":
				var desk := Rect2(c).get_center() - back * 0.2
				_put(l, &"desk", desk, back, 0.35, {"household": hh})
				_slot(l, land, &"desk", &"reader", desk, back)
				# The reader at home beside the desk, facing into the cell (`back`
				# is the way the wall's things face, into the room).
				l.residents.append({"role": &"dweller", "household": hh, "at": desk + along * 0.95 + back * 0.2, "face": back,
					"wants": &"record", "gives": &"string", "asks": ASKS, "thanks": THANKS, "after": AFTER})
			_:
				_slot(l, land, &"wall", hh, wall, back)
