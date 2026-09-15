extends TestCase
## Chasers find the way round: a BFS field of steps to the player (radius 24)
## over ground a body can climb, used when the straight line meets a cliff.

const F := preload("res://tests/fight/fixture.gd")


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
