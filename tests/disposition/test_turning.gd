extends TestCase
## What turns a machine, in the simulation: a careful player is nothing to a
## worker, a thief is everything, a watcher never fights whatever you do, and
## suspicion fills, shows and drains (VISION §2).

const F := preload("res://tests/fight/fixture.gd")


func test_a_careful_player_walks_among_workers_and_is_never_touched() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 26.5))
	var rows: Array[MobState] = []
	for i in 3:
		var h := sim.add_mob(&"harvester", Vector2(14.5 + i * 6.0, 20.5))
		h.line_a = Vector2(h.pos.x, 16.5)
		h.line_b = Vector2(h.pos.x, 24.5)
		h.facing = PI * 0.5
		h.aim = h.facing
		rows.append(h)
	var bad := 0
	# Walking along the headland beside their rows, three tiles clear of them.
	for i in 400:
		sim.hero.move = Vector2(1, 0)
		F.ms(sim, 32)
		sim.hero.health = FightRules.HEALTH
		if sim.hero.pos.x > 32.0:
			sim.hero.pos.x = 14.5
		for e in sim.drain():
			if e.type in [&"disturbed", &"alerted", &"crowd_warning", &"hurt"]:
				bad += 1
	eq(bad, 0, "never disturbed, warned, roused or struck")
	for h in rows:
		check(h.indifferent(), "still at its work")
		eq(h.disposition, &"indifferent")
	eq(sim.fight_on, false, "and no fight ever started")


func test_taking_a_workers_parts_turns_it_and_nothing_else_does() -> void:
	for cause: StringName in [&"theft", &"blocked", &"damaged"]:
		var sim := F.make_sim()
		var h := F.still(sim, &"harvester", Vector2(24.5, 20.5), PI)
		sim.disturb(h, cause)
		check(h.disturbed, "a worker turns when %s" % cause)
		eq(h.disturbed_by, cause)
		var events := sim.drain()
		eq(F.count(events, &"disturbed"), 1, "and says so once (%s)" % cause)
	for cause: StringName in [&"trespass", &"curfew", &"downed"]:
		var sim2 := F.make_sim()
		var h2 := F.still(sim2, &"harvester", Vector2(24.5, 20.5), PI)
		sim2.disturb(h2, cause)
		check(not h2.disturbed, "a worker does not care about %s: not its part of the plan" % cause)
		check(h2.indifferent(), "it works on")


func test_a_keeper_holds_its_site_and_its_hours() -> void:
	for cause: StringName in [&"trespass", &"curfew"]:
		var sim := F.make_sim()
		var k := F.still(sim, &"warden", Vector2(24.5, 20.5), PI)
		k.disposition = &"indifferent"
		sim.disturb(k, cause)
		check(k.disturbed, "a keeper turns on %s" % cause)


func test_a_watcher_never_fights_whatever_is_done_to_it() -> void:
	var sim := F.make_sim()
	var w := F.still(sim, &"watcher", Vector2(24.5, 20.5), PI)
	w.disposition = &"indifferent"
	for cause: StringName in [&"theft", &"damaged", &"blocked", &"trespass"]:
		sim.disturb(w, cause)
	check(not w.disturbed, "it files; it does not turn")


func test_a_noise_out_of_sight_turns_a_machines_optics_and_fills_its_suspicion() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := F.still(sim, &"harvester", Vector2(32.5, 20.5), PI)
	h.calm_until = 0.0
	# Twelve tiles off: past anything it can see or hear of a player standing there.
	gt(Senses.chebyshev(h.pos, sim.hero.pos), Senses.sight_range(h.row, sim.moment), "out of its sight")
	gt(Senses.chebyshev(h.pos, sim.hero.pos), StealthQuery.hearing_range(h.row, sim.moment), "and its hearing")
	F.ms(sim, 300)
	eq(h.suspicion, 0.0, "nothing to be suspicious of")
	var bang := sim.hero.pos + Vector2(2.0, 0.0)
	sim.make_noise(bang, 24.0)
	F.ms(sim, 100)
	gt(h.suspicion, 0.0, "it heard that")
	eq(h.heard_at, bang, "and knows where it came from")
	gt(h.look_until, sim.now, "its optics are on it")
	var events := sim.drain()
	eq(F.count(events, &"heard"), 1, "said once, for the view to draw")
	# Kept up, it is sure; but it is a worker, so it goes back to work, not to war.
	for i in 6:
		sim.make_noise(bang, 24.0)
		F.ms(sim, 100)
	near(h.suspicion, 1.0, 1e-5, "banging away at it, it is sure something is there")
	check(h.indifferent(), "and still not hunting: it is a worker, and nothing of its has been touched")


func test_suspicion_drains_and_the_body_settles_back() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := F.still(sim, &"runner", Vector2(40.5, 20.5), PI)
	h.calm_until = 0.0
	sim.make_noise(sim.hero.pos, 26.0)
	F.ms(sim, 100)
	var peak := h.suspicion
	gt(peak, 0.0, "it heard something")
	# The noise goes stale, and then it drains: a couple of seconds either side.
	F.ms(sim, 7000)
	eq(h.suspicion, 0.0, "nothing came of it, and it is over it")
	check(not h.roused(), "it never came")
	lt(h.look_until, sim.now, "and its optics are off the place")


func test_something_low_in_the_heather_takes_more_than_one_look() -> void:
	var w := F.flat_world(64, Ground.HEATH)
	var sim := F.make_sim(w, Vector2(20.5, 20.5))
	var h := F.still(sim, &"runner", Vector2(23.5, 20.5), PI)
	h.calm_until = 0.0
	sim.moment.crouched = true
	sim.moment.cover = 0.5
	sim.moment.loudness = 0.1
	gt(StealthQuery.sight_range(h.row, sim.moment), 3.0, "it can make something out at three tiles")
	F.ms(sim, 100)
	lt(h.suspicion, 1.0, "one beat is not enough to be sure of it")
	gt(h.suspicion, 0.0, "but it has seen something")
	check(not h.roused(), "and has not come yet")
	F.ms(sim, 400)
	near(h.suspicion, 1.0, 1e-5, "half a second later it is sure")


func test_a_body_is_sure_of_a_player_standing_in_the_open_at_once() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := F.still(sim, &"runner", Vector2(26.5, 20.5), PI)
	h.calm_until = 0.0
	F.ms(sim, 110)
	near(h.suspicion, 1.0, 1e-5, "in the open, one beat")
	var events := sim.drain()
	eq(F.count(events, &"alerted"), 1, "and the alert snaps")


func test_a_worker_reads_its_own_cone_and_a_player_behind_it_is_not_seen() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	# Seven tiles behind a harvester that is looking the other way, on its beat.
	var h := sim.add_mob(&"harvester", Vector2(27.5, 20.5))
	h.facing = 0.0
	h.aim = 0.0
	h.line_a = h.pos
	h.line_b = h.pos
	h.calm_until = 0.0
	sim.moment.loudness = 0.0
	F.ms(sim, 500)
	eq(h.suspicion, 0.0, "it is looking away, and has not registered the player behind it")
	var events := sim.drain()
	eq(F.count(events, &"noticed"), 0)
	# Turned round, the same seven tiles are plainly in front of it.
	h.facing = PI
	h.aim = PI
	F.ms(sim, 200)
	gt(h.suspicion, 0.0, "turned round, it sees them")


func test_a_worker_a_region_has_turned_wary_stops_working_and_comes() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := F.still(sim, &"harvester", Vector2(26.5, 20.5), PI)
	h.calm_until = 0.0
	F.ms(sim, 500)
	check(not h.roused(), "a calm region: it works on with the player in plain sight")
	# The region heats: the disposition system writes what the network thinks.
	h.disposition = Disposition.of(h.role, 2)
	eq(h.disposition, &"hostile", "a region at hostile: the harvest comes for you too")
	check(not h.indifferent(), "it is not at its work any more")
	F.ms(sim, 400)
	check(h.roused() or h.mood == MobState.ALERTED, "and it comes for the player it was walking past")
