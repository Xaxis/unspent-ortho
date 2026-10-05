extends TestCase
## A BODY'S FIELD BUILT FAST ANSWERS AS THE PLAIN ONE DID. NavField.update
## stamps the solids by footprint and runs Dial's off locals and step tables;
## the body it replaced asked every cell for the props round it and stepped its
## neighbours from literal arrays, 17-21 ms a city field on the main thread.
## This keeps that body (`update_plainly`) and holds every cell's level and
## steps equal to it, on seed 1's machine city round its densest buildings and on
## a cliffed world, for a harvester's field and the player's.

const Worlds := preload("res://tests/core/test_world_gen.gd")
const F := preload("res://tests/fight/fixture.gd")


func test_a_fast_field_answers_as_the_plain_one() -> void:
	var w := Worlds.world(1)
	var q := WorldQuery.new(w)
	var t := w.table
	var city: Array[Vector2] = []
	for r in t.size():
		var at: Vector2 = t.pos[r]
		if t.solid[r] > WorldQuery.ORDINARY and BiomeRegistry.at(w, at).id == &"machine_city":
			city.append(at)
	check(city.size() > 20, "seed 1's machine city stands wide solids")
	var targets: Array[Vector2] = []
	for k in 6:
		targets.append(Sentinels.stand_near(w, city[k * city.size() / 6], 0.45))
	_hold(w, q, targets, "seed 1's city")
	var cliffed := F.flat_world(96)
	for y in range(10, 80):
		cliffed.level[y * 96 + 40] = 8
		cliffed.level[y * 96 + 41] = 3
	for k in 30:
		var p := WorldProp.new(cliffed.next_id(), PropKind.BOULDER, Vector2(20.0 + float(k * 7 % 50), 15.0 + float(k * 11 % 60)), 0.0, 1.0)
		cliffed.add_prop(p)
	_hold(cliffed, WorldQuery.new(cliffed), [Vector2(48.5, 48.5), Vector2(38.5, 20.5), Vector2(60.5, 70.5)] as Array[Vector2], "a cliffed world")


func _hold(w: WorldData, q: WorldQuery, targets: Array[Vector2], where: String) -> void:
	for row: Dictionary in [Roster.row(&"harvester"), {}]:
		for target: Vector2 in targets:
			var field := NavField.for_body(w, q, row, 0.45) if not row.is_empty() else NavField.new(w, q)
			field.update(target)
			var plain := update_plainly(field, target)
			var wrong := 0
			for i: int in (plain[0] as PackedInt32Array).size():
				if field._level[i] != plain[0][i] or field._dist[i] != plain[1][i]:
					wrong += 1
			eq(wrong, 0, "%s: the %s field to %s answers as the plain one" % [where, "harvester's" if not row.is_empty() else "player's", target])


## The body NavField.update replaced, as it stood: [levels, steps] for a field
## with `field`'s rules laid to `target`.
static func update_plainly(field: NavField, target: Vector2) -> Array:
	var world := field.world
	var side := field._side
	var radius := NavField.RADIUS
	var level := PackedInt32Array()
	level.resize(side * side)
	var dist := PackedInt32Array()
	dist.resize(side * side)
	dist.fill(NavField.FAR)
	var c := Vector2i(floori(target.x), floori(target.y))
	var size := world.size
	var ox := c.x - radius
	var oy := c.y - radius
	for ly in side:
		var y := oy + ly
		for lx in side:
			var x := ox + lx
			var l := NavField.NOT_GROUND
			if x >= 0 and y >= 0 and x < size and y < size:
				var i := y * size + x
				if world.ground[i] != Ground.DEEP_WATER:
					l = world.level[i]
			var near_target := absi(lx - radius) <= 1 and absi(ly - radius) <= 1
			if l != NavField.NOT_GROUND and not near_target:
				if field.tall > 0 and world.headroom_at(x, y) < field.tall:
					l = NavField.NOT_GROUND
				elif field.prop_radius > 0.0 and field.query != null and NavField.prop_stands_in(field.query, Vector2(x + 0.5, y + 0.5), field.prop_radius, field.breaks):
					l = NavField.NOT_GROUND
			level[ly * side + lx] = l
	var start := radius * side + radius
	if level[start] == NavField.NOT_GROUND:
		return [level, dist]
	var buckets: Array[PackedInt32Array] = [PackedInt32Array([start])]
	dist[start] = 0
	var k := 0
	while k < buckets.size():
		var i := 0
		while i < buckets[k].size():
			var cell := buckets[k][i]
			i += 1
			if dist[cell] != k:
				continue
			var lx := cell % side
			var ly := cell / side
			var here := level[cell]
			for dy: int in [-1, 0, 1]:
				var nly := ly + dy
				if nly < 0 or nly >= side:
					continue
				for dx: int in [-1, 0, 1]:
					var nlx := lx + dx
					if (dx == 0 and dy == 0) or nlx < 0 or nlx >= side:
						continue
					var ni := nly * side + nlx
					var diagonal := dx != 0 and dy != 0
					var nd := k + (NavField.DIAGONAL if diagonal else NavField.STRAIGHT)
					if dist[ni] <= nd:
						continue
					var there := level[ni]
					if there == NavField.NOT_GROUND or absi(there - here) > field.step:
						continue
					if diagonal:
						var a := level[ly * side + nlx]
						var b := level[nly * side + lx]
						if a == NavField.NOT_GROUND or b == NavField.NOT_GROUND or absi(a - here) > field.step or absi(a - there) > field.step \
								or absi(b - here) > field.step or absi(b - there) > field.step:
							continue
					dist[ni] = nd
					while buckets.size() <= nd:
						buckets.append(PackedInt32Array())
					buckets[nd].append(ni)
		k += 1
	return [level, dist]


## A FIELD LAID A SLICE AT A TIME (NavField.request / advance) ends as the one
## laid at once, and answers from its old build until then: the chaser goes on
## following where the player was, never a half-laid field.
func test_a_field_laid_in_slices_answers_as_one_laid_at_once() -> void:
	var w := Worlds.world(1)
	var q := WorldQuery.new(w)
	var row := Roster.row(&"harvester")
	var t := w.table
	var at := Vector2.ZERO
	for r in t.size():
		if t.solid[r] > WorldQuery.ORDINARY and BiomeRegistry.at(w, t.pos[r]).id == &"machine_city":
			at = t.pos[r]
			break
	var first := Sentinels.stand_near(w, at, 0.45)
	var then := Sentinels.stand_near(w, first + Vector2(3, 2), 0.45)
	var whole := NavField.for_body(w, q, row, 0.45)
	whole.update(then)
	var sliced := NavField.for_body(w, q, row, 0.45)
	sliced.update(first)
	var old_here := sliced.steps(floori(first.x) + 2, floori(first.y))
	check(sliced.request(then), "a new tile starts a build")
	check(not sliced.request(then), "asked again for the same tile, it goes on with the one in hand")
	var slices := 0
	while sliced.pending():
		eq(sliced.steps(floori(first.x) + 2, floori(first.y)), old_here, "slice %d: it answers from the old build" % slices)
		@warning_ignore("return_value_discarded")
		sliced.advance(137)
		slices += 1
		if slices > 400:
			break
	gt(float(slices), 10.0, "a city field takes many slices of 137 cells")
	check(not sliced.pending(), "and is laid in the end")
	eq(sliced.centre, whole.centre, "laid to the new tile")
	var wrong := 0
	for i: int in whole._dist.size():
		if sliced._dist[i] != whole._dist[i] or sliced._level[i] != whole._level[i]:
			wrong += 1
	eq(wrong, 0, "every cell as the field laid at once")
