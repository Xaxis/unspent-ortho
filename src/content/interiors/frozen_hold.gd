extends RefCounted
## THE FROZEN HOLD UNDER THE FROST SEA'S LEANING MAST (docs/interiors): the mast
## leaning out of the ice is a trawler frozen into the floe, and this is her
## hold -- canted with her list, ice come in through the seams along the low
## side, the fish room still stacked with frozen boxes, the crew's bunks in the
## fo'c'sle forward, and the galley stove they kept alight their last winter.
## Down through the middle of it, the machines' sounding cable runs from the
## deck into a hole cut through her bottom and on into the black water under
## the ice: "listening to something underneath" (frost_sea.gd).
##
## A REFUGE ON THE ONE LANDSCAPE CROSSED ON THE ICE. Nothing hunts in here. But
## the cold does: the land's cold is under the roof too (52_hazards), and the
## stove is out. RELIT (21_doors `fuel`: what a campfire burns, without its
## stones, for the stove is the stones), it is a fire -- warmth, light, and a
## place to sleep -- and it stays lit for whoever comes back (saved per door).
##
## The crew's sea chest still holds what they kept (Interiors.LOOT
## `frozen_hold`).
##
## STORY SLOTS: the cable's panel at the well (`terminal:cable_panel`) and the
## board over the bunks the crew kept their tally on (`wall:bunk_board`). Laid in
## the canonical frame: the way in is in the south wall (+y), the companionway
## down from the deck.

const HOLD := Rect2i(0, 0, 9, 5)
const FOCSLE := Rect2i(9, 1, 3, 3)
## The stove against the forward bulkhead's corner, and the well the cable goes
## down, in the middle of the hold.
const STOVE_AT := Vector2(1.0, 0.5)
const WELL_AT := Vector2(5.5, 2.4)
const WELL_R := 0.7


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"frozen_hold"
	# Below the deck, the only light down the companionway and what you bring.
	k.closed = 0.9
	k.zoom = 10.0
	k.wall_h = 2.3
	k.cut = 0.8
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/frozen_hold.gd")
	k.model = "res://src/models/interior/frozen_hold_model.gd"
	k.hatch = "res://src/models/interior/hatch_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"hold"
	# Which way she lists: the ice is in along the low side.
	l.dressing = [&"list_port", &"list_starboard"][rng.randi_range(0, 1)]
	l.has_hearth = false
	l.rooms.append(HOLD)
	l.rooms.append(FOCSLE)
	l.door = Vector2(2.5, 5)
	l.door_out = Vector2(0, 1)
	l.hearth = STOVE_AT
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(2.4, 2.0)
	l.lay_edges()
	var fwd := Vector2(FOCSLE.position.x, 2.5)
	for e: Dictionary in l.edges:
		var m := ((e.a as Vector2) + (e.b as Vector2)) * 0.5
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and m.distance_to(fwd) < 0.1:
			e.kind = &"inner"
	_fit(l)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _fit(l: InteriorLayout) -> void:
	# The galley stove, out, and the crew's table by it.
	_put(l, &"stove", STOVE_AT, Vector2(0, 1), 0.45, {"fuel": true})
	_put(l, &"galley_table", l.table, Vector2(0, 1), 0.45, {"long": 1.2})
	# The cable down through the hold into the well cut in her bottom, and its
	# panel on the frame beside it.
	_put(l, &"sounding_well", WELL_AT, Vector2(0, 1), WELL_R)
	var panel := Vector2(WELL_AT.x + 1.3, 0.36)
	_put(l, &"cable_panel", panel, Vector2(0, 1), 0.0)
	l.slots.append({"slot": &"terminal", "at": panel, "face": Vector2(0, 1)})
	# The fish room aft of the well: boxes of the last catch, frozen together.
	_put(l, &"fish_boxes", Vector2(7.9, 0.8), Vector2(-1, 0), 0.55)
	_put(l, &"fish_boxes", Vector2(7.9, 4.1), Vector2(-1, 0), 0.55)
	# The ice come in through the seams along the low side, and the frames.
	_put(l, &"ice_seam", Vector2(4.5, 4.64), Vector2(0, -1), 0.0, {"long": 8.0})
	# The fo'c'sle: two bunks and the board over them, and the sea chest.
	_put(l, &"bunk", Vector2(10.5, 1.4), Vector2(0, 1), 0.4)
	_put(l, &"bunk", Vector2(10.5, 3.6), Vector2(0, -1), 0.4)
	var board := Vector2(FOCSLE.end.x - 0.36, 2.5)
	_put(l, &"bunk_board", board, Vector2(-1, 0), 0.0)
	l.slots.append({"slot": &"wall", "at": board, "face": Vector2(-1, 0)})
	_put(l, &"strongbox", Vector2(11.5, 1.4), Vector2(0, 1), 0.36)
	l.walks.append(PackedVector2Array([l.door, STOVE_AT + Vector2(0.4, 1.0)]))
