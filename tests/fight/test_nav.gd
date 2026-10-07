extends TestCase
## Chasers find the way round: a BFS field of steps to the player (radius 24)
## over ground a body can climb, used when the straight line meets a cliff.

const F := preload("res://tests/fight/fixture.gd")
const Worlds := preload("res://tests/core/test_world_gen.gd")


## A cliff wall across x = 30 from y = 5 to 40, with a way round below it.
func _walled() -> WorldData:
	var w := F.flat_world(64)
	for y in range(5, 41):
		w.level[y * w.size + 30] = 8
	return w


func test_steps_go_round_a_cliff() -> void:
	var w := _walled()
	var nav := NavField.new(w, WorldQuery.new(w))
	nav.update(Vector2(34.5, 20.5))
	eq(nav.steps(34, 20), 0)
	eq(nav.steps(33, 20), NavField.STRAIGHT)
	eq(nav.steps(30, 20), NavField.FAR, "the cliff itself is not ground")
	gt(float(nav.steps(26, 20)), 40.0, "the far side is the long way round")
	check(nav.detour_needed(Vector2(26.5, 20.5)), "so straight is no good there")
	check(not nav.detour_needed(Vector2(34.5, 26.5)), "on the open side it is")
	var d := nav.direction(Vector2(26.5, 20.5))
	lt(d.y, -0.5, "and the way is up, round the nearer end of the wall")


func test_a_straight_line_is_walkable_only_on_open_ground() -> void:
	var w := _walled()
	check(NavField.line_walkable(w, Vector2(26.5, 44.5), Vector2(34.5, 44.5)), "below the wall")
	check(not NavField.line_walkable(w, Vector2(26.5, 20.5), Vector2(34.5, 20.5)), "through it")
	check(NavField.line_walkable(w, Vector2(31.0, 4.5), Vector2(31.0, 30.5)), "a line beside it")
	check(not NavField.line_walkable(w, Vector2(31.0, 4.5), Vector2(31.0, 30.5), 0.3), "that a body that wide would scrape")
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var r := sim.add_mob(&"runner", Vector2(10.5, 20.5))
	r.set_mood(MobState.CHASING, sim.now)
	F.ms(sim, 500)
	eq(sim.nav.builds, 0, "open ground never builds the field")


func test_the_field_is_rebuilt_only_when_the_player_changes_tile() -> void:
	var w := F.flat_world(32)
	var nav := NavField.new(w, WorldQuery.new(w))
	nav.update(Vector2(10.2, 10.2))
	nav.update(Vector2(10.9, 10.7))
	eq(nav.builds, 1)
	nav.update(Vector2(11.1, 10.7))
	eq(nav.builds, 2)


func test_a_runner_comes_round_the_wall() -> void:
	var w := _walled()
	var sim := F.make_sim(w, Vector2(34.5, 20.5))
	# Far enough that it is not a fight until it has come round.
	var r := sim.add_mob(&"runner", Vector2(22.5, 20.5))
	r.line_a = r.pos
	r.line_b = r.pos
	r.calm_until = 0.0
	r.last_seen = sim.hero.pos
	r.set_mood(MobState.CHASING, sim.now)
	var reached := false
	for i in 150:
		F.ms(sim, 100)
		r.lost_beats = 0
		if r.pos.distance_to(sim.hero.pos) < 2.5:
			reached = true
			break
	check(reached, "it got to the player, at %s" % r.pos)


## A BODY'S FIELD SHUTS THE CELLS ITS OWN MOVE CANNOT STAND IN, WIDE SOLIDS,
## WALLS AND ALL. Disc kinds over WorldQuery.ORDINARY are stamped into the field
## once per rebuild by footprint, the ordinary ones asked cell by cell, and a
## walled kind's walls (PropWalls: houses, city buildings) by the tiles they shut;
## together they must shut exactly the cells `prop_stands_in` shuts one at a
## time. Discs of 0.4 to 3.22 and houses of that solid strewn across wide-cell
## corners, the field's edge and its centre, one of a kind the body breaks, one
## disc and one house taken.
func test_a_bodys_field_shuts_what_its_move_cannot_stand_in() -> void:
	var w := F.flat_world(96)
	var props: Array[WorldProp] = []
	for k in 40:
		var at := Vector2(20.0 + Rng.hash01(5, k, 0, 1) * 56.0, 20.0 + Rng.hash01(5, k, 0, 2) * 56.0)
		var solid := 0.4 + Rng.hash01(5, k, 0, 3) * 2.82
		var kind := PropKind.PINE if k == 7 else (PropKind.HOUSE if k % 4 == 1 else PropKind.BOULDER)
		var p := WorldProp.new(w.next_id(), kind, at, 0.0, solid / PropKind.SOLID[kind])
		w.add_prop(p)
		props.append(p)
	w.depleted[props[11].id] = INF
	w.depleted[props[13].id] = INF
	var q := WorldQuery.new(w)
	check(not PropWalls.walled(PropKind.BOULDER) and not PropWalls.walled(PropKind.PINE), "boulders and pines are disc kinds")
	check(not q._wide.is_empty(), "some of them are wide")
	check(not q._wall_rows.is_empty(), "some of them are walled")
	var row := {"breaks": ["pine"]}
	for target: Vector2 in [Vector2(48.5, 48.5), Vector2(40.2, 55.7), Vector2(63.9, 32.1)]:
		var field := NavField.for_body(w, q, row, 0.45)
		field.update(target)
		var c := Vector2i(floori(target.x), floori(target.y))
		var wrong := 0
		for ly in field._side:
			for lx in field._side:
				if absi(lx - NavField.RADIUS) <= 1 and absi(ly - NavField.RADIUS) <= 1:
					continue
				var x := c.x - NavField.RADIUS + lx
				var y := c.y - NavField.RADIUS + ly
				if x < 0 or y < 0 or x >= w.size or y >= w.size:
					continue
				var shut := field._level[ly * field._side + lx] == NavField.NOT_GROUND
				if shut != NavField.prop_stands_in(q, Vector2(x + 0.5, y + 0.5), 0.45, field.breaks):
					wrong += 1
		eq(wrong, 0, "the field to %s shuts the cells its move cannot stand in" % target)


## And on a real city: seed 1's machine city at full size, a harvester's field
## to the six streets with the most big buildings round them (ranked by how many
## with a solid over WorldQuery.ORDINARY stand within the field), stamped against
## `prop_stands_in` cell by cell. The city's buildings are walled kinds, so what
## these fields must meet is walls; wide discs are the case above.
func test_a_city_field_shuts_what_its_move_cannot_stand_in() -> void:
	var w := Worlds.world(1)
	var q := WorldQuery.new(w)
	var row := Roster.row(&"harvester")
	var t := w.table
	var city: Array[Vector2] = []
	for r in t.size():
		var at: Vector2 = t.pos[r]
		if t.solid[r] > WorldQuery.ORDINARY and BiomeRegistry.at(w, at).id == &"machine_city":
			city.append(at)
	print("  info seed 1 machine city: %d wide solids" % city.size())
	check(city.size() > 20, "seed 1's machine city stands wide solids (%d)" % city.size())
	var ranked: Array = []
	for at: Vector2 in city:
		var n := 0
		for o: Vector2 in city:
			if maxf(absf(o.x - at.x), absf(o.y - at.y)) <= float(NavField.RADIUS):
				n += 1
		ranked.append([n, at])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var centres: Array[Vector2] = []
	for e: Array in ranked:
		var at: Vector2 = e[1]
		var apart := true
		for c0: Vector2 in centres:
			if c0.distance_to(at) < 12.0:
				apart = false
		if apart:
			centres.append(at)
		if centres.size() >= 6:
			break
	var wide := 0
	var walled := 0
	for centre: Vector2 in centres:
		var target := Sentinels.stand_near(w, centre, 0.45)
		var field := NavField.for_body(w, q, row, 0.45)
		field.update(target)
		var c := Vector2i(floori(target.x), floori(target.y))
		wide += q.wide_rows_in(Vector2(c) - Vector2.ONE * NavField.RADIUS, Vector2(c) + Vector2.ONE * NavField.RADIUS, 0.45).size()
		walled += q.wall_rows_in(Vector2(c) - Vector2.ONE * NavField.RADIUS, Vector2(c) + Vector2.ONE * NavField.RADIUS, 0.45).size()
		var wrong := 0
		for ly in field._side:
			for lx in field._side:
				if absi(lx - NavField.RADIUS) <= 1 and absi(ly - NavField.RADIUS) <= 1:
					continue
				var x := c.x - NavField.RADIUS + lx
				var y := c.y - NavField.RADIUS + ly
				if x < 0 or y < 0 or x >= w.size or y >= w.size or w.level_at(x, y) < 0 or w.ground_at(x, y) == Ground.DEEP_WATER:
					continue
				if field.tall > 0 and w.headroom_at(x, y) < field.tall:
					continue
				var shut := field._level[ly * field._side + lx] == NavField.NOT_GROUND
				if shut != NavField.prop_stands_in(q, Vector2(x + 0.5, y + 0.5), 0.45, field.breaks):
					wrong += 1
		eq(wrong, 0, "the field to %s shuts the cells its move cannot stand in" % target)
	print("  info its six fields met %d walled props and %d wide solids" % [walled, wide])
	gt(float(walled), 10.0, "the city's fields met walled buildings (%d)" % walled)
