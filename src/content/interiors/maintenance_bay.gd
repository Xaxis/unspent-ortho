extends RefCounted
## A MAINTENANCE BAY IN THE MACHINE CITY, from inside (docs/interiors; the form
## outside is props/towers.gd `block`, whose frontage keeps a service hatch where
## this landscape keeps a room behind it). The machine city was never for a
## body (content/biomes/machine_city.gd): no door at a person's height, no light
## where light is not needed, no room that is not exactly the size of what it
## holds. So this is a bay the length of one machine, under a gantry, on a deck
## with its guide line painted down the middle, lit by nothing but what the
## machines need to see by -- a charge lamp, a panel, the standby points on the
## bins. The hatch is lower than a person stands.
##
## And off it, where the parts niche should be full, the one thing out of place:
## a gap somebody has been living in.
##
## Dealt per door off its own hash:
##   the PLAN      `cradle`  the charging cradle at the bay's end, empty, and the
##                           bins of spares along the wall
##                 `parts`   racks the bay's length, a sorting bench at its end
##   the TRACE     `tally`   a count scratched into the niche's plate, and a tin
##                 `nest`    the same count, and a bedroll pushed into the gap
## and in every one: the gantry, its tool head parked, the drain, the diagnostic
## panel at the height of a machine's sensor and not a person's eye.
##
## STORY SLOTS: the diagnostic panel (`terminal:diag_panel`) and the count in the
## niche (`wall:tally`). Laid in the canonical frame: the way in is in the south
## wall (+y).

const Cottage := preload("res://src/content/interiors/cottage.gd")
const PLANS: Array[StringName] = [&"cradle", &"parts"]
const TRACES: Array[StringName] = [&"tally", &"nest"]
## The bay: three tiles across, seven long -- one machine and the room to work
## round it, and not a hand more.
const BAY := Rect2i(0, 0, 3, 7)


static func make() -> InteriorKind:
	var k := InteriorKind.new()
	k.id = &"maintenance_bay"
	# Shut and dark at any hour: the lantern is the only light a body brings.
	k.closed = 1.0
	k.zoom = 9.0
	# A machine's height under the gantry, not a storey.
	k.wall_h = 2.3
	k.cut = 0.9
	k.door_width = 0.9
	k.recipe = load("res://src/content/interiors/maintenance_bay.gd")
	k.model = "res://src/models/interior/maintenance_model.gd"
	return k


static func lay(rng: RandomNumberGenerator) -> InteriorLayout:
	var l := InteriorLayout.new()
	l.plan = PLANS[rng.randi_range(0, PLANS.size() - 1)]
	l.dressing = TRACES[rng.randi_range(0, TRACES.size() - 1)]
	l.has_hearth = false
	var east := rng.randf() < 0.5
	# The niche the parts should fill, off one side of the bay, the gap into it
	# in its middle: at its end, the gap came against the niche's own wall and a
	# body had two centimetres to turn the corner in.
	var niche := Rect2i(3 if east else -2, 2, 2, 3)
	l.rooms.append(BAY)
	l.rooms.append(niche)
	l.door = Vector2(1.5, 7)
	l.door_out = Vector2(0, 1)
	l.hearth = Vector2(1.5, 3.5)
	l.hearth_wall = Vector2(0, -1)
	l.table = Vector2(niche.position) + Vector2(1.0, 1.5)
	l.lay_edges()
	var gap := Vector2(3.0 if east else 0.0, 3.5)
	for e: Dictionary in l.edges:
		var m := Cottage._mid(e)
		if m.distance_to(l.door) < 0.1:
			e.kind = &"door"
		elif e.inner and m.distance_to(gap) < 0.1:
			e.kind = &"inner"
	_furnish(l, niche, east)
	return l


static func _put(l: InteriorLayout, kind: StringName, at: Vector2, face: Vector2, solid: float, extra: Dictionary = {}) -> void:
	var t := {"kind": kind, "at": at, "face": face, "solid": solid}
	t.merge(extra)
	l.things.append(t)


static func _furnish(l: InteriorLayout, niche: Rect2i, east: bool) -> void:
	# The wall away from the niche, and the way into the bay off it.
	var far_x := 0.36 if east else 2.64
	var far_face := Vector2(1, 0) if east else Vector2(-1, 0)
	# The gantry down the bay's middle under the ceiling, its tool head parked at
	# the bay's end over what it works on: it hangs to a person's shoulder, so
	# never over the way a body walks.
	_put(l, &"gantry", Vector2(1.5, 3.5), Vector2(0, 1), 0.0, {"deep": 6.4})
	_put(l, &"tool_head", Vector2(1.5, 1.0), Vector2(0, 1), 0.0)
	_put(l, &"drain", Vector2(1.5, 4.6), Vector2(0, 1), 0.0)
	# The diagnostic panel, at the height a machine's sensor comes to.
	var panel := Vector2(far_x, 2.0)
	_put(l, &"diag_panel", panel, far_face, 0.0)
	l.slots.append({"slot": &"terminal", "at": panel, "face": far_face})
	if l.plan == &"cradle":
		# The cradle a machine backs into to be charged, at the bay's end, and
		# empty: whatever it holds is out.
		_put(l, &"cradle", Vector2(1.5, 1.1), Vector2(0, 1), 0.5, {"deep": 1.6})
		_put(l, &"bins", Vector2(far_x, 4.6), far_face, 0.3, {"long": 2.2})
	else:
		# Racks the bay's length on the far wall, and a short one on the niche's
		# side past the gap; a sorting bench across the bay's end.
		_put(l, &"rack", Vector2(far_x + far_face.x * 0.04, 4.2), far_face, 0.34, {"long": 3.8})
		var near_x := 2.6 if east else 0.4
		_put(l, &"rack", Vector2(near_x, 5.2), -far_face, 0.34, {"long": 2.0})
		_put(l, &"sort_bench", Vector2(1.5, 0.55), Vector2(0, 1), 0.4, {"long": 2.4})
	# The niche: the count scratched into its back plate, and what the one who
	# made it keeps.
	var back := Vector2(niche.position.x + 1.64, niche.position.y + 1.5) if east \
		else Vector2(niche.position.x + 0.36, niche.position.y + 1.5)
	var back_face := Vector2(-1, 0) if east else Vector2(1, 0)
	_put(l, &"tally", back, back_face, 0.0)
	l.slots.append({"slot": &"wall", "at": back, "face": back_face})
	var n := Vector2(niche.position)
	_put(l, &"tin", n + Vector2(1.0, 0.5), Vector2(0, 1), 0.0)
	if l.dressing == &"nest":
		_put(l, &"bedroll", n + Vector2(1.0, 2.45), Vector2(1, 0), 0.0)
	l.walks.append(PackedVector2Array([l.door, Vector2(1.5, 2.5)]))
	l.walks.append(PackedVector2Array([Vector2(1.5, 2.5), l.table]))
