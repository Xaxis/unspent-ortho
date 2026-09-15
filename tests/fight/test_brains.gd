extends TestCase
## The approaches: a charge commits to its bearing and will not turn for you
## mid-run; a lunge presses in and bites; an errand keeps to its line; a
## second act changes the bite; a watcher that has you calls the others.

const F := preload("res://tests/fight/fixture.gd")


func test_charge_commits_to_a_bearing() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
	var hero := sim.hero
	var h := F.still(sim, &"harvester", Vector2(34.5, 40.5), 0.0)
	h.calm_until = 0.0
	h.set_mood(MobState.ATTACKING, sim.now)
	# Wait for the run to start.
	var guard := 0
	while not h.charging and guard < 200:
		sim.slices(1)
		guard += 1
	check(h.charging, "it set off")
	var bearing := h.bearing
	near(bearing.angle(), 0.0, 0.36, "aimed at the player when it set off")
	var from := h.pos
	# The player steps well out of the row.
	hero.pos = Vector2(38.5, 44.5)
	F.ms(sim, 480)
	near(h.bearing.angle(), bearing.angle(), 0.0001, "the bearing never moved")
	var travelled := h.pos - from
	gt(travelled.length(), 1.0, "and it kept coming")
	near(travelled.normalized().dot(bearing), 1.0, 0.02, "along the bearing, not after the player")


func test_charge_stands_and_comes_round_after_a_run() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
	var h := F.still(sim, &"hauler", Vector2(34.5, 40.5), 0.0)
	h.calm_until = 0.0
	h.set_mood(MobState.ATTACKING, sim.now)
	var guard := 0
	while not h.charging and guard < 200:
		sim.slices(1)
		guard += 1
	F.ms(sim, Brains.RUN_MS + 80)
	check(not h.charging, "the run is over")
	gt(h.pause_until - sim.now, 420.0 * 5 - 200.0, "a hauler stands about 2100 ms (turns 5)")
	var at := h.pos
	F.ms(sim, 1000)
	lt(h.pos.distance_to(at), 0.05, "and does not move while it comes round")


func test_lunge_presses_in_and_bites() -> void:
	var sim := F.make_sim()
	var dog := F.still(sim, &"dog.yard", Vector2(23.5, 20.5), PI)
	dog.calm_until = 0.0
	dog.set_mood(MobState.ATTACKING, sim.now)
	F.ms(sim, 2000)
	var events := sim.drain()
	gt(F.count(events, &"hurt"), 0, "a dog in reach bites within two seconds")


func test_errand_never_chases() -> void:
	var sim := F.make_sim(F.flat_world(64, Ground.NEEDLES, Country.PINEWOOD), Vector2(20.5, 30.5))
	var s := sim.add_mob(&"sweeper", Vector2(20.5, 20.5))
	s.line_a = Vector2(13.5, 20.5)
	s.line_b = Vector2(27.5, 20.5)
	for i in 30:
		F.ms(sim, 200)
		lt(absf(s.pos.y - 20.5), 0.3, "keeps to its line")
		lt(absf(s.pos.x - 20.5), 7.6, "within its stretch")
	eq(sim.fight_on, false, "a player off the line has nothing to fight")


func test_errand_closes_on_a_player_on_its_line() -> void:
	var sim := F.make_sim(F.flat_world(64, Ground.NEEDLES, Country.PINEWOOD), Vector2(22.5, 20.5))
	var s := sim.add_mob(&"sweeper", Vector2(20.5, 20.5))
	s.line_a = Vector2(13.5, 20.5)
	s.line_b = Vector2(27.5, 20.5)
	F.ms(sim, 2500)
	gt(F.count(sim.drain(), &"hurt"), 0, "comes along the track over you")


func test_harvester_second_act_at_sixty_percent() -> void:
	var sim := F.make_sim()
	var h := F.still(sim, &"harvester", Vector2(22.5, 20.5), PI)
	var first := h.bite
	h.health = int(floor(h.max_health * 0.6)) + 1
	sim.hero.pos = h.pos + Vector2(-(h.radius + sim.hero.radius + 0.3), 0)
	sim.press_swing()
	F.ms(sim, 200)
	var events := sim.drain()
	check(h.second_act, "the second act starts")
	eq(F.count(events, &"second_act"), 1)
	check(h.bite != first, "a different bite")
	eq(h.bite.windup, 300, "faster")
	near(h.bite.width, 2.6, 0.001, "and wider")


func test_a_blow_in_the_working_part_stops_the_work_once_in_a_while() -> void:
	var sim := F.make_sim()
	var h := F.still(sim, &"harvester", Vector2(23.5, 20.5), PI)
	sim.hero.pos = h.pos + Vector2(-(h.radius + sim.hero.radius + 0.3), 0)
	h.start_blow(h.bite, sim.now)
	sim.press_swing()
	F.ms(sim, 120)
	check(h.stunned(sim.now), "stalled")
	eq(h.blow, null, "its tell is lost")
	var ready := h.stall_ready_at
	near(ready - (sim.now - 120.0), float(FightRules.STALL_EVERY_MS), 130.0)
	F.ms(sim, 500)
	h.start_blow(h.bite, sim.now)
	sim.press_swing()
	F.ms(sim, 120)
	check(h.blow != null, "a second blow inside the rhythm does not stop it")


func test_watcher_that_sees_you_calls_the_others() -> void:
	var w := F.flat_world(96)
	var sim := F.make_sim(w, Vector2(40.5, 40.5))
	var watcher := sim.add_mob(&"watcher", Vector2(40.5, 30.5))
	# Fifteen tiles from the player: too far to have noticed for itself.
	var runner := sim.add_mob(&"runner", Vector2(55.5, 30.5))
	runner.line_a = runner.pos
	runner.line_b = runner.pos
	F.ms(sim, 900)
	var events := sim.drain()
	eq(watcher.mood, MobState.ALERTED, "a watcher registers the player by eye")
	eq(F.count(events, &"called"), 1, "and calls")
	check(runner.mood != MobState.IDLE, "a machine in earshot of it comes")
	eq(runner.last_seen, sim.hero.pos)


func test_watcher_cannot_see_a_player_behind_a_ridge() -> void:
	var w := F.flat_world(96)
	for x in range(30, 50):
		w.level[35 * w.size + x] = 6
	var sim := F.make_sim(w, Vector2(40.5, 40.5))
	var watcher := sim.add_mob(&"watcher", Vector2(40.5, 30.5))
	F.ms(sim, 900)
	eq(watcher.mood, MobState.WORKING, "the ridge hides the player")


func test_dredger_keeps_to_the_water() -> void:
	var w := F.flat_world(64, Ground.GRASS, Country.MOSS)
	for y in 64:
		for x in 20:
			w.ground[y * 64 + x] = Ground.BLACKWATER
	var sim := F.make_sim(w, Vector2(26.5, 20.5))
	var d := sim.add_mob(&"dredger", Vector2(15.5, 20.5))
	d.calm_until = 0.0
	d.set_mood(MobState.CHASING, sim.now)
	F.ms(sim, 3000)
	lt(d.pos.x, 20.0, "it never leaves the water: the bank is the answer")
	gt(d.pos.x, 18.0, "though it comes to the edge")
