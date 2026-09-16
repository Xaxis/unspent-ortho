extends TestCase
## Living in the gaps: a watcher's round has a gap, the gap is the same every
## time, and a player down in the heather at dusk can use it.

const F := preload("res://tests/fight/fixture.gd")


func _dusk(w: WorldData, at: Vector2) -> FightSim:
	var sim := F.make_sim(w, at)
	sim.moment.minutes = 20.0 * 60.0
	sim.moment.weather = &"clear"
	sim.moment.weather_strength = 0.0
	return sim


func test_a_watcher_sweeps_its_optics_and_the_sweep_repeats() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 40.5))
	var w := sim.add_mob(&"watcher", Vector2(20.5, 20.5))
	w.facing = 0.0
	w.aim = 0.0
	w.bearing = Vector2.RIGHT
	var aims: Array[float] = []
	for i in 140:
		F.ms(sim, 100)
		aims.append(w.aim)
	var lo := aims[0]
	var hi := aims[0]
	for a: float in aims:
		lo = minf(lo, a)
		hi = maxf(hi, a)
	gt(hi - lo, StealthQuery.SWEEP_SPAN, "it looks well either side of its bearing")
	lt(hi - lo, StealthQuery.SWEEP_SPAN * 2.0 + 0.01, "and never further than its span")
	# The round itself is exact: a period on, the same bearing, for ever. (The
	# live aim lags it by up to one think, which is why the rule is tested here.)
	for t: float in [0.7, 2.4, 5.9]:
		near(StealthQuery.sweep(0.3, t), StealthQuery.sweep(0.3, t + StealthQuery.SWEEP_PERIOD), 1e-5,
			"the same bearing a period after %.1f s" % t)


func test_the_sweep_leaves_a_gap_a_player_could_walk_through() -> void:
	var w := F.flat_world(64)
	var sim := F.make_sim(w, Vector2(20.5, 20.5))
	var watcher := sim.add_mob(&"watcher", Vector2(20.5, 30.5))
	var row := watcher.row
	var to_player := (sim.hero.pos - watcher.pos).angle()
	var covered := 0
	var open := 0
	for i in 120:
		var aim := StealthQuery.sweep(to_player + StealthQuery.SWEEP_SPAN, i * 0.1)
		if StealthQuery.in_cone(watcher.pos, aim, sim.hero.pos, StealthQuery.cone_half(row)):
			covered += 1
		else:
			open += 1
	gt(float(open), 0.0, "there is a stretch of its round when it is not reading that way")
	gt(float(covered), 0.0, "and a stretch when it is")
	gt(float(open) / float(covered + open), 0.3, "the gap is worth waiting for")


func test_crouched_in_the_heather_at_dusk_a_player_gets_past_what_would_see_them_standing() -> void:
	var w := F.flat_world(64, Ground.HEATH)
	var sim := _dusk(w, Vector2(20.5, 20.5))
	var watcher := F.still(sim, &"watcher", Vector2(26.5, 20.5), PI)
	watcher.calm_until = 0.0
	# Standing in the open, six tiles off, it has them at once.
	F.ms(sim, 200)
	check(watcher.suspicion >= 1.0, "standing up, it reads them")
	# The same place, down in the heather with nothing lit.
	var sim2 := _dusk(w, Vector2(20.5, 20.5))
	var watcher2 := F.still(sim2, &"watcher", Vector2(26.5, 20.5), PI)
	watcher2.calm_until = 0.0
	sim2.moment.crouched = true
	sim2.moment.cover = Cover.at(w, null, sim2.hero.pos, true, sim2.moment.nightfall() * Senses.DARKEST, false)
	gt(sim2.moment.cover, 0.2, "the heather and the dusk together are worth something")
	F.ms(sim2, 1000)
	eq(watcher2.suspicion, 0.0, "down in it, it never picks them up")
	check(not watcher2.roused(), "and nothing is filed")
	# Light the lamp and every bit of that is undone.
	sim2.moment.lamp_lit = true
	sim2.moment.cover = Cover.at(w, null, sim2.hero.pos, true, sim2.moment.nightfall() * Senses.DARKEST, true)
	F.ms(sim2, 300)
	gt(watcher2.suspicion, 0.0, "a lit lamp gives them away, crouched or not")


func test_creeping_is_quiet_enough_to_get_past_ears_that_would_hear_a_walk() -> void:
	var w := F.flat_world(64, Ground.MOSS)
	var sim := F.make_sim(w, Vector2(20.5, 20.5))
	var d := F.still(sim, &"dredger", Vector2(27.5, 20.5), 0.0)
	d.calm_until = 0.0
	var walking := StealthNoise.loudness(Tuning.WALK_SPEED, Ground.MOSS, false, 0)
	var creeping := StealthNoise.loudness(Tuning.WALK_SPEED, Ground.MOSS, true, 0)
	sim.moment.loudness = walking
	gt(StealthQuery.hearing_range(d.row, sim.moment), 7.0, "walking, it hears them seven tiles off")
	sim.moment.loudness = creeping
	lt(StealthQuery.hearing_range(d.row, sim.moment), 7.0, "creeping, it does not")
	# And it is looking the other way, so hearing is all it has.
	F.ms(sim, 600)
	eq(d.suspicion, 0.0, "so it works on and never knows")
