extends TestCase
## THE CONTAINER WARREN (src/content/interiors/container_warren.gd): a run of
## steel boxes behind a blind alley's door in the middens. Asked of the doors
## seed 1 grows, and of warrens grown behind many doors: every room is reached
## from the way in, the floor rings, and in a sorted warren the sorter docked at
## the curfew does not hear a crouched walk down the run and does hear a
## standing one (docs/MIDDENS_ROOMS.md, teammate1's ruling).

const STEP := 0.2
## Warrens grown behind doors at this many places: every plan and dressing the
## hash deals turns up among them.
const GROWN := 40

var _doors := load("res://src/systems/21_doors.gd") as GDScript


func _reach(q: WorldQuery, from: Vector2) -> Dictionary:
	var seen := {Vector2i(roundi(from.x / STEP), roundi(from.y / STEP)): true}
	var todo: Array[Vector2i] = [seen.keys()[0]]
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
	return seen


func _reached(reach: Dictionary, at: Vector2) -> bool:
	var c := Vector2i(roundi(at.x / STEP), roundi(at.y / STEP))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


func _grown() -> Array[InteriorGen.Pocket]:
	var land := BiomeRegistry.index_of(&"the_middens")
	var out: Array[InteriorGen.Pocket] = []
	for i in GROWN:
		var t := Threshold.of_face(Vector2(40.0 + 7.0 * i, 60.0 + 3.0 * (i % 5)), Vector2(0, 1), &"container_warren", land)
		out.append(InteriorGen.grow(1, t))
	return out


## EVERY BLIND ALLEY'S DOOR IN THE MIDDENS OPENS ON A WARREN.
func test_the_middens_alley_doors_open_on_warrens() -> void:
	var w := BootWorld.world(1, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"container_warren":
			n += 1
			eq(BiomeRegistry.by_index(t.land).id, &"the_middens", "%s: in the middens" % t.key)
			check(t.key.begins_with("face@"), "%s: set in a face" % t.key)
	eq(n, SlotDoors.alleys(w).size(), "one warren behind each alley door")
	gt(float(n), 0.0, "seed 1 has warrens")


## EVERY ROOM IS REACHED FROM THE WAY IN, and the strongbox with it; no two rooms
## overlap; the containers ring and the vault does not.
func test_every_warren_is_walked_through_from_its_door() -> void:
	var dressings := {}
	for p: InteriorGen.Pocket in _grown():
		var l := p.layout
		dressings[l.dressing] = true
		for i in l.rooms.size():
			for j in range(i + 1, l.rooms.size()):
				check(not l.rooms[i].intersects(l.rooms[j]), "%s: rooms %d and %d do not overlap" % [p.threshold.key, i, j])
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		for i in l.rooms.size():
			var r := l.rooms[i]
			var c := Vector2(r.position) + Vector2(r.size) * 0.5
			check(_reached(reach, c), "%s: room %d (%s) is reached from the door" % [p.threshold.key, i, r])
			var g := p.world.ground_at(floori(c.x), floori(c.y))
			var steel := r.size.x == 3 or r.size.y == 3
			eq(g, Ground.STEEL_FLOOR if steel else Ground.FLOOR, "%s: room %d's floor" % [p.threshold.key, i])
		var boxes := 0
		for th: Dictionary in l.things:
			if th.kind == &"strongbox":
				boxes += 1
				check(_reached(reach, (th.at as Vector2) + (th.face as Vector2) * 0.8), "%s: the strongbox can be walked to" % p.threshold.key)
		eq(boxes, 1, "%s: one strongbox" % p.threshold.key)
	for d: StringName in [&"dug", &"kept", &"sorted"]:
		check(dressings.has(d), "a %s warren is among those grown" % d)


## THE FLOOR RINGS, AND A CAREFUL PLAYER CAN PASS. In a sorted warren at the
## curfew, every step of the way down the run keeps further from the sorter's
## dock than a crouched walk on steel is heard, and somewhere on it a standing
## walk is heard: crouched, it sleeps; upright, it wakes.
func test_a_crouched_walk_passes_the_docked_sorter_and_a_standing_one_wakes_it() -> void:
	var row := Roster.row(&"sorter")
	var crouched := float(row.hears) * StealthNoise.loudness(Tuning.WALK_SPEED, Ground.STEEL_FLOOR, true, 0)
	var walked := float(row.hears) * StealthNoise.loudness(Tuning.WALK_SPEED, Ground.STEEL_FLOOR, false, 0)
	gt(StealthNoise.loudness(Tuning.WALK_SPEED, Ground.STEEL_FLOOR, false, 0), StealthNoise.loudness(Tuning.WALK_SPEED, Ground.FLOOR, false, 0), "steel is louder than boards")
	var sorted := 0
	for p: InteriorGen.Pocket in _grown():
		var l := p.layout
		if l.dressing != &"sorted":
			continue
		sorted += 1
		var docks: Array[Vector2] = []
		for r: Dictionary in l.residents:
			if r.get("docks", false):
				docks.append(r.at)
		eq(docks.size(), 1, "%s: the sorter docks" % p.threshold.key)
		var walk: PackedVector2Array = l.walks[0]
		var nearest := INF
		var from := walk[0]
		for i in range(1, walk.size()):
			var to := walk[i]
			var steps := maxi(1, ceili(from.distance_to(to) / STEP))
			for k in steps:
				var at := from.lerp(to, float(k + 1) / float(steps))
				for s: Vector2 in docks:
					nearest = minf(nearest, Senses.chebyshev(at, s))
			from = to
		gt(nearest, crouched, "%s: crouched down the run, never within the dock's hearing (%.2f)" % [p.threshold.key, nearest])
		lt(nearest, walked, "%s: standing, the dock hears the run (%.2f)" % [p.threshold.key, nearest])
	gt(float(sorted), 0.0, "sorted warrens were grown")
