extends TestCase
## THE DOORS IN A SLOT LABYRINTH'S FACES (SlotDoors, Threshold.of_face;
## docs/MIDDENS_ROOMS.md slice 1): a door at the end of a blind alley and a
## mouth in a junction room's wall, derived from the seed's slot plan and the
## finished land. Every door stands in a sheer face over a floor a body can stand
## on, walks out to somewhere, is never on a ramp or in a junction's middle, and
## is named the same every time.

static var _w: WorldData = null


static func _world() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(1)
	return _w


static func _all(w: WorldData) -> Array:
	var out: Array = []
	for s: Array in SlotDoors.alleys(w):
		out.append(["alley"] + s)
	for s: Array in SlotDoors.rooms(w):
		out.append(["room"] + s)
	return out


func test_every_door_stands_in_a_sheer_face_over_a_floor() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	var alleys := SlotDoors.alleys(w)
	var rooms := SlotDoors.rooms(w)
	print("       slot doors on seed 1: %d alleys, %d rooms" % [alleys.size(), rooms.size()])
	gt(float(alleys.size()), 2.0, "blind alleys get their warrens")
	# One to a patch of 4 x 4 blocks: 5, 5 and 3 on seeds 1, 7 and 42, a
	# village's share, each one a find.
	check(rooms.size() >= 3 and rooms.size() <= 6, "a village's share of settlements: %d" % rooms.size())
	for s: Array in _all(w):
		var face: Vector2 = s[1]
		var out: Vector2 = s[2]
		var t := Threshold.of_face(face, out, &"x", int(s[3]))
		var dt := Vector2i(floori(t.door.x), floori(t.door.y))
		var inside := face - out * 0.5
		var rise := w.level_at(floori(inside.x), floori(inside.y)) - w.level_at(dt.x, dt.y)
		check(rise >= SlotDoors.FACE_LEVELS, "%s door %s stands in a face %d levels tall" % [s[0], t.key, rise])
		check(q.standable(dt.x, dt.y) and not Ground.is_water(w.ground_at(dt.x, dt.y)), "%s door %s opens onto dry floor" % [s[0], t.key])
		eq(w.country_at(dt.x, dt.y), int(s[3]), "%s door %s is in the slots' own landscape" % [s[0], t.key])


## From every door a body walks out of the maze: up to the plateau (which only a
## ramp reaches) or onto other land.
func test_every_door_walks_out() -> void:
	var w := _world()
	var q := WorldQuery.new(w)
	for s: Array in _all(w):
		var t := Threshold.of_face(s[1], s[2], &"x", int(s[3]))
		var start := Vector2i(floori(t.door.x), floori(t.door.y))
		var floor_l := w.level_at(start.x, start.y)
		var seen := {start: true}
		var todo: Array[Vector2i] = [start]
		var out := false
		while not todo.is_empty() and seen.size() < 40000 and not out:
			var c: Vector2i = todo.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + d
				if seen.has(n) or not q.passable(c.x, c.y, n.x, n.y):
					continue
				seen[n] = true
				if w.level_at(n.x, n.y) >= floor_l + SlotDoors.FACE_LEVELS or w.country_at(n.x, n.y) != int(s[3]):
					out = true
					break
				todo.append(n)
		check(out, "%s door %s walks out of the maze (%d tiles searched)" % [s[0], t.key, seen.size()])


## A door is never on a ramp (a ramp is the way up, not a wall) nor in the middle
## of a junction room (a mouth is in its wall).
func test_no_door_on_a_ramp_or_in_a_room_s_middle() -> void:
	var w := _world()
	var plan := GenSlots.plan(w.seed_value, w.size)
	for s: Array in _all(w):
		var t := Threshold.of_face(s[1], s[2], &"x", int(s[3]))
		for k in plan.centre.size():
			if plan.degree[k] >= 3:
				check(t.door.distance_to(plan.centre[k]) > plan.radius[k] * 0.5, "%s door %s is not in a room's middle" % [s[0], t.key])
			if plan.ramp[k] != 0:
				var a := plan.ramp_from[k]
				var b := plan.ramp_to[k]
				var u := clampf((t.door - a).dot(b - a) / maxf((b - a).length_squared(), 1e-4), 0.0, 1.0)
				check(t.door.distance_to(a + (b - a) * u) > plan.ramp_half[k], "%s door %s is not on a ramp" % [s[0], t.key])


func test_the_keys_are_unique_and_stable() -> void:
	var w := _world()
	var keys := {}
	for s: Array in _all(w):
		var t := Threshold.of_face(s[1], s[2], &"x", int(s[3]))
		check(not keys.has(t.key), "one door per key: %s" % t.key)
		keys[t.key] = true
	SlotDoors._plans.clear()
	var again := {}
	for s: Array in _all(w):
		again[Threshold.of_face(s[1], s[2], &"x", int(s[3])).key] = true
	eq(again.keys(), keys.keys(), "the same doors from a fresh plan")
