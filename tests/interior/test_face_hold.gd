extends TestCase
## THE FACE SETTLEMENT (src/content/interiors/face_hold.gd): the middens'
## village, cut back into the heap behind a junction room's wall. Asked of the
## doors seed 1 grows, and of settlements grown behind many doors: every room is
## reached from the mouth (the lookout up its ladder), no two rooms overlap, the
## reader keeps a cell in every one, and the lookout has its slit in the face.

const STEP := 0.2
const GROWN := 40

var _doors := load("res://src/systems/21_doors.gd") as GDScript


func _grown() -> Array[InteriorGen.Pocket]:
	var land := BiomeRegistry.index_of(&"the_middens")
	var out: Array[InteriorGen.Pocket] = []
	for i in GROWN:
		var t := Threshold.of_face(Vector2(50.0 + 9.0 * i, 70.0 + 3.0 * (i % 7)), Vector2(0, 1), &"face_hold", land)
		out.append(InteriorGen.grow(1, t))
	return out


## Walked from `from`, and up every ladder whose foot the walk reaches by the
## climb the jump key makes there.
func _reach(q: WorldQuery, from: Vector2, l: InteriorLayout) -> Dictionary:
	var seen := {Vector2i(roundi(from.x / STEP), roundi(from.y / STEP)): true}
	var todo: Array[Vector2i] = [seen.keys()[0]]
	var climbed := {}
	while true:
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + d
				if seen.has(n):
					continue
				var a := Vector2(c) * STEP
				var b := Vector2(n) * STEP
				if q.move_body(a, b - a, Tuning.PLAYER_RADIUS).distance_to(b) < 0.02:
					seen[n] = true
					todo.append(n)
		for th: Dictionary in l.things:
			if th.kind != &"ladder" or climbed.has(th.at):
				continue
			var foot: Vector2 = (th.at as Vector2) + (th.face as Vector2) * 0.6
			if not _reached(seen, foot):
				continue
			climbed[th.at] = true
			var c := Climb.plan(q.world, q, foot, -(th.face as Vector2), FightRules.WIND)
			if c != null and not c.slides:
				var k := Vector2i(roundi(c.top.x / STEP), roundi(c.top.y / STEP))
				seen[k] = true
				todo.append(k)
		if todo.is_empty():
			break
	return seen


## Whether the walk got anywhere inside `r` (its middle may be under a table).
func _in_room(reach: Dictionary, r: Rect2i) -> bool:
	var inner := Rect2(r).grow(-0.35)
	for k: Vector2i in reach:
		if inner.has_point(Vector2(k) * STEP):
			return true
	return false


func _reached(reach: Dictionary, at: Vector2) -> bool:
	var c := Vector2i(roundi(at.x / STEP), roundi(at.y / STEP))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


## A JUNCTION ROOM'S WALL IN THE MIDDENS OPENS ON A SETTLEMENT.
func test_the_middens_room_doors_open_on_settlements() -> void:
	var w := BootWorld.world(1, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"face_hold":
			n += 1
			eq(BiomeRegistry.by_index(t.land).id, &"the_middens", "%s: in the middens" % t.key)
			check(t.key.begins_with("face@"), "%s: set in a face" % t.key)
	eq(n, SlotDoors.rooms(w).size(), "one settlement behind each room door")
	gt(float(n), 0.0, "seed 1 has settlements")


## EVERY ROOM IS REACHED FROM THE MOUTH, the lookout up its ladder; none overlap;
## the reader keeps a cell; the lookout has its slit; every plan turns up.
func test_every_settlement_is_walked_through_from_its_mouth() -> void:
	var plans := {}
	for p: InteriorGen.Pocket in _grown():
		var l := p.layout
		plans[l.plan] = true
		for i in l.rooms.size():
			for j in range(i + 1, l.rooms.size()):
				check(not l.rooms[i].intersects(l.rooms[j]), "%s: rooms %d and %d do not overlap" % [p.threshold.key, i, j])
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside(), l)
		for i in l.rooms.size():
			check(_in_room(reach, l.rooms[i]), "%s: room %d (%s) is reached from the mouth" % [p.threshold.key, i, l.rooms[i]])
		var readers := 0
		var ladders := 0
		for th: Dictionary in l.things:
			if th.get("household", &"") == &"reader" and th.kind == &"desk":
				readers += 1
				check(_reached(reach, (th.at as Vector2) + (th.face as Vector2) * 0.7), "%s: the reader's desk can be walked to" % p.threshold.key)
			if th.kind == &"ladder":
				ladders += 1
		eq(readers, 1, "%s: the reader keeps one cell" % p.threshold.key)
		eq(ladders, 1, "%s: one ladder, up to the lookout" % p.threshold.key)
		var slits := 0
		for e: Dictionary in l.edges:
			if e.kind == &"window":
				slits += 1
		eq(slits, 1, "%s: one slit, in the lookout's face" % p.threshold.key)
		eq(l.rooms.size(), {&"two": 5, &"three": 6, &"four": 7}[l.plan], "%s (%s): the sort, the back row, its side cells and the lookout" % [p.threshold.key, l.plan])
	for plan: StringName in [&"two", &"three", &"four"]:
		check(plans.has(plan), "a %s settlement is among those grown" % plan)
