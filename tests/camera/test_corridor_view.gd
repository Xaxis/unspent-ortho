extends TestCase
## DOWN A CORRIDOR THE VIEW LOOKS ALONG IT (Shoulder.corridor, Shoulder.along):
## a slot is found from the clear distances round the head, open ground and a
## square room are not, and a view across the slot is turned toward the nearer
## end, most of the way, holding that end until it is well past square.

const Shoulder := preload("res://src/core/view/shoulder.gd")


## Clear distances at the probes' headings for a corridor `width` wide along
## ground direction `axis`, `reach` long each way, the head in its middle.
func _slot(axis: Vector2, width: float, reach: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in Shoulder.AXIS_PROBES:
		var d := Vector2.from_angle(k * TAU / Shoulder.AXIS_PROBES)
		var across := absf(d.dot(axis.orthogonal()))
		var to_wall := (width * 0.5) / across if across > 1e-4 else INF
		out.append(minf(to_wall, reach))
	return out


func test_a_slot_is_found_along_its_length() -> void:
	var axis := Vector2(1, 0)
	var got: Array = Shoulder.corridor(_slot(axis, 4.5, Shoulder.AXIS_REACH))
	gt(float(got[1]), 0.9, "a slot four and a half wide is a corridor (%.2f)" % float(got[1]))
	gt(absf((got[0] as Vector2).dot(axis)), 0.99, "along its length")
	var diag := Vector2(1, 1).normalized()
	var probe_axis := Vector2.from_angle(TAU / Shoulder.AXIS_PROBES * 2.0)
	var got2: Array = Shoulder.corridor(_slot(probe_axis, 4.0, Shoulder.AXIS_REACH))
	gt(absf((got2[0] as Vector2).dot(probe_axis)), 0.99, "at any heading the probes hold (%s)" % diag)


func test_open_ground_and_a_room_are_no_corridor() -> void:
	var open := PackedFloat32Array()
	var room := PackedFloat32Array()
	for k in Shoulder.AXIS_PROBES:
		open.append(Shoulder.AXIS_REACH)
		var d := Vector2.from_angle(k * TAU / Shoulder.AXIS_PROBES)
		room.append(2.5 / maxf(absf(d.x), absf(d.y)))
	eq(float(Shoulder.corridor(open)[1]), 0.0, "open ground")
	eq(float(Shoulder.corridor(room)[1]), 0.0, "a square room five across")
	eq(float(Shoulder.corridor(_slot(Vector2(1, 0), 9.0, Shoulder.AXIS_REACH))[1]), 0.0, "a way nine wide is no corridor")


func test_a_view_across_is_turned_to_the_nearer_end_and_holds_it() -> void:
	var axis := Vector2(1, 0)
	var east := Shoulder.yaw_along(axis)
	# Looking straight at the side wall, a little toward the east end.
	var view := east + 80.0
	var a := Shoulder.along(view, axis, 1.0, 0)
	eq(int(a.y), 1, "the nearer end")
	near(Shoulder.turn(view + a.x, east), -80.0 * (1.0 - Shoulder.AXIS_SHARE), 0.01, "most of the way along")
	# Turned past square it holds that end, until well past.
	var held := Shoulder.along(east + 100.0, axis, 1.0, 1)
	eq(int(held.y), 1, "held past square")
	var flipped := Shoulder.along(east + 130.0, axis, 1.0, 1)
	eq(int(flipped.y), -1, "the other end once well past")
	eq(Shoulder.along(view, axis, 0.0, 1).x, 0.0, "no corridor, no turn")
	near(Shoulder.along(east, axis, 1.0, 1).x, 0.0, 1e-4, "looking along, left alone")
