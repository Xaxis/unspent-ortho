extends RefCounted
## A ROUNDHOUSE IN THE CRAGS, from inside (docs/interiors; the form outside is
## props/crags.gd `roundhouse`). The oldest shape people build and the one they
## went back to: one round room of dry stone, no window, a peat fire in the middle
## of the floor and the smoke finding its own way out through the hole at the top
## of the roof. The fire is the only light; by day a shaft of grey comes down the
## smoke hole onto the hearth.
##
## Stone PIERS stand out from the wall like the spokes of a wheel (a wheelhouse),
## and the bays between them are the rooms, dealt per door off its own hash:
##   the bed       a box bed of stone, heather and fleeces
##   the loom      a warp-weighted loom leaning on the wall, its stones hanging
##   the quern     the hand mill and the meal sack
##   the store     a stone kist and the crocks
##   the peat      the winter's fuel, beside the way in
##   the slates    hush slate stacked and scratched: what the old people keep
## and in every one: the fire in its kerb, a crane over it -- a survey post the
## chainman planted, pulled up and put to use -- the pot on its chain, fish
## drying in the smoke, rushes on the floor.
##
## STORY SLOTS say where words can be found (a stone scratched with marks, the
## kist); the story fills them (docs/STORY.md). Laid in the canonical frame: the
## way in is in the south wall (+y).

## The room's radius and its middle, in tiles. The middle stands so that the
## doorway's chord lies on the edge of the tiles the room stands in (y 8): a
## circle centred in its square put the doorway inside the last row, with
## floor beyond the way out.
const R := 3.6
## (8 - R cos(PI / 22), written out.)
const C := Vector2(4.0, 4.43664)
## Chords the wall is laid in: one of them is the doorway.
const SIDES := 22
## Spokes: how far a pier reaches in from the wall, and at what bearings, as
## eighths of a turn off the doorway (the bay the door opens into is between the
## first pair).
const PIER_DEEP := 1.15
const BAYS := 8
## Where a thing in a bay stands, from the middle.
const IN_BAY := R - 0.78

const WANTS: Array[StringName] = [&"bed", &"loom", &"quern", &"store", &"slates", &"bed", &"store"]


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"roundhouse"
	# No window: dark at noon but for the fire and the smoke hole.
	k.closed = 0.9
	k.zoom = 9.0
	k.wall_h = 1.7
	k.cut = 0.8
	k.door_width = 0.8
	k.recipe = load("res://src/content/interiors/roundhouse.gd")
	k.model = "res://src/models/interior/roundhouse_model.gd"
	return k


## A bearing round the room: 0 is the doorway (+y), turning toward +x.
static func _at(bearing: float, r: float) -> Vector2:
	return C + Vector2(sin(bearing), cos(bearing)) * r


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = &"wheel"
	l.dressing = &"crofter"
	l.has_hearth = false
	l.rooms.append(Rect2i(0, 0, 8, 8))
	_walls(l)
	l.hearth = C
	l.hearth_wall = Vector2(0, -1)
	# Nobody works at a table here: the bench is the hearth's kerb, on the side
	# away from the door.
	l.table = C + Vector2(0, -1.1)
	l.props.append({"kind": PropKind.FIRE, "at": l.hearth, "face": Vector2(0, 1)})
	_bays(l, rng)
	return l


## The wall as chords of a circle, one centred on the way in.
static func _walls(l: InteriorLayout) -> void:
	var step := TAU / SIDES
	for i in SIDES:
		var a0 := (float(i) - 0.5) * step
		var a1 := (float(i) + 0.5) * step
		var a := _at(a0, R)
		var b := _at(a1, R)
		var out := Vector2(sin(float(i) * step), cos(float(i) * step))
		l.edges.append({"a": a, "b": b, "out": out, "kind": &"door" if i == 0 else &"wall", "inner": false})
	l.door = _at(0.0, R * cos(step * 0.5))
	l.door_out = Vector2(0, 1)


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _bays(l: InteriorLayout, rng: RandomNumberGenerator) -> void:
	var turn := TAU / BAYS
	# The piers, between the bays; each stands as a run of circles from the wall in.
	for i in BAYS:
		var b := (float(i) + 0.5) * turn
		var inward := -Vector2(sin(b), cos(b))
		_put(l, &"pier", _at(b, R - PIER_DEEP * 0.5 - 0.1), inward, 0.24, {"deep": PIER_DEEP})
	# The bays, the door's first: peat stacked to one side of the way in.
	var wants := WANTS.duplicate()
	for i in range(wants.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var s: StringName = wants[i]
		wants[i] = wants[j]
		wants[j] = s
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var peat_b := side * turn * 0.32
	_put(l, &"peat", _at(peat_b, IN_BAY + 0.2), -Vector2(sin(peat_b), cos(peat_b)), 0.3)
	var bed_at := Vector2.INF
	for i in range(1, BAYS):
		var b := float(i) * turn
		var inward := -Vector2(sin(b), cos(b))
		var at := _at(b, IN_BAY)
		var what: StringName = wants[i - 1]
		match what:
			&"bed":
				_put(l, &"bed", _at(b, R - 0.62), inward, 0.5)
				_put(l, &"fleece", _at(b, R - 1.55), inward, 0.0)
				if bed_at == Vector2.INF:
					bed_at = _at(b, R - 1.4)
			&"loom":
				_put(l, &"loom", _at(b, R - 0.45), inward, 0.3)
				l.slots.append({"slot": &"wall", "at": _at(b, R - 0.3), "face": inward})
			&"quern":
				_put(l, &"quern", at, inward, 0.3)
				_put(l, &"sack", _at(b + turn * 0.24, IN_BAY + 0.1), inward, 0.2)
			&"store":
				_put(l, &"kist", _at(b - turn * 0.12, IN_BAY + 0.15), inward, 0.34)
				_put(l, &"crocks", _at(b + turn * 0.22, IN_BAY + 0.2), inward, 0.25)
				l.slots.append({"slot": &"desk", "at": _at(b - turn * 0.12, IN_BAY + 0.15), "face": inward})
			&"slates":
				_put(l, &"slates", at, inward, 0.3)
				l.slots.append({"slot": &"wall", "at": _at(b, R - 0.3), "face": inward})
	# The fire's kerb, the crane over it on the far side from the door, and what
	# dries in its smoke.
	_put(l, &"kerb", C, Vector2(0, 1), 0.0)
	var crane_b := PI + rng.randf_range(-0.5, 0.5)
	_put(l, &"crane", _at(crane_b, 0.95), -Vector2(sin(crane_b), cos(crane_b)), 0.12)
	_put(l, &"hang", C + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)), Vector2.from_angle(rng.randf() * TAU), 0.0)
	# The flags of the path worn from the door to the fire.
	l.walks.append(PackedVector2Array([l.door, C + Vector2(0, 0.7)]))
	if bed_at != Vector2.INF:
		l.walks.append(PackedVector2Array([C, bed_at]))
