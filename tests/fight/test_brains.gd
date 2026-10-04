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
	# Over on its clock, or once the bite it carries in goes live if that is later.
	var set_off := sim.now
	while h.charging and sim.now - set_off < Brains.RUN_MS + h.bite.windup + 200.0:
		sim.slices(1)
	check(not h.charging, "the run is over")
	gt(sim.now - set_off, Brains.RUN_MS - 80.0, "after its whole run (%.0f ms)" % (sim.now - set_off))
	gt(h.pause_until - sim.now, 420.0 * 5 - 200.0, "a hauler stands about 2100 ms (turns 5)")
	var at := h.pos
	F.ms(sim, 1000)
	lt(h.pos.distance_to(at), 0.05, "and does not move while it comes round")


## THE CHARGE THAT REACHES. A charge's tell starts a windup's run away, so the
## blow is live as its front gets there: a run set off at a player standing
## still in its row, from 4.5 to 10 tiles, bites him, never short of him. The
## run used to stop on its clock with the tell still winding, so from 9 tiles
## and more the Tide Reaper bit the air a tile short (live at 3.7 to 4.5 tiles,
## its reach 3.25): on the home coast's flats every one of those misses spent
## it, and it never stood the 1.4 s it founders in (tours/home-coast.tour).
func test_a_charge_bites_a_player_standing_in_its_row_from_any_start() -> void:
	for kind: StringName in [&"sentinel.coast", &"harvester", &"bull.field"]:
		var short: Array[String] = []
		for i in 12:
			var dist := 4.5 + i * 0.5
			var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
			var m := sim.add_mob(kind, Vector2(40.5 + dist, 40.5))
			m.facing = PI
			m.aim = PI
			m.calm_until = 0.0
			m.set_mood(MobState.CHASING, sim.now)
			var hit := false
			for k in 400:
				F.ms(sim, 16)
				sim.hero.health = FightRules.HEALTH
				hit = hit or F.count(sim.drain(), &"hurt") > 0
				if m.blow_phase(sim.now) == &"recovery":
					break
			if not hit:
				short.append("%.1f" % dist)
		check(short.is_empty(), "%s's first bite reaches him from every start (short from %s)" % [kind, short])


## AND FROM CLOSE IN. A run told from close in eases so its front arrives as the
## bite goes live (FightSim), and its first think found it had moved less than
## a full-speed run is held to: ruled blocked, it stood out its windup where it
## was and bit the air short (a harvester from a 1.69 gap, 0.2 short of a still
## player). Every charger, from every close start, on ground it moves on.
func test_a_charge_bites_a_player_standing_close_in_its_row() -> void:
	for kind: StringName in Roster.kinds():
		var row := Roster.row(kind)
		if row.get("approach", &"") != &"charge":
			continue
		var keeps: Array = row.get("keeps_to", [])
		var ground := Ground.GRASS if keeps.is_empty() else Ground.NAMES.find(String(keeps[0]))
		var short: Array[String] = []
		for i in 18:
			var sim := F.make_sim(F.flat_world(96, ground), Vector2(40.5, 40.5))
			var m := sim.add_mob(kind, Vector2(40.5, 40.5))
			var gap := 0.2 + i * 0.25
			m.pos = Vector2(40.5 + m.radius + sim.hero.radius + gap, 40.5)
			m.facing = PI
			m.aim = PI
			m.calm_until = 0.0
			m.disturbed = true
			m.set_mood(MobState.CHASING, sim.now)
			var hit := false
			var bit := false
			for k in 400:
				F.ms(sim, 16)
				sim.hero.health = FightRules.HEALTH
				hit = hit or F.count(sim.drain(), &"hurt") > 0
				bit = bit or m.blow != null
				if m.blow != null and m.blow_phase(sim.now) == &"recovery":
					break
			if bit and not hit:
				short.append("%.2f" % gap)
		check(short.is_empty(), "%s's first bite reaches a still player from every close start (air from gaps %s)" % [kind, short])


## A TOLD RUN STILL STOPS AT A WALL. Held to the speed it was asked for, not
## excused while its bite winds up: a run whose player is suddenly past a
## terrace wall (a dodge over a step, a shove) is ruled blocked against the rock
## and stands, rather than pressing into it to the end of its windup.
func test_a_told_run_that_meets_a_wall_stands_at_it() -> void:
	var w := F.flat_world(96)
	for y in 96:
		w.level[y * w.size + 42] = 8
	var sim := F.make_sim(w, Vector2(40.8, 40.5))
	var h := sim.add_mob(&"harvester", Vector2(38.5, 40.5))
	h.facing = 0.0
	h.aim = 0.0
	h.calm_until = 0.0
	h.disturbed = true
	h.set_mood(MobState.CHASING, sim.now)
	var guard := 0
	while not (h.charging and h.blow != null) and guard < 200:
		sim.slices(1)
		guard += 1
	check(h.charging and h.blow_phase(sim.now) == &"windup", "it set off with its bite told")
	sim.hero.pos = Vector2(50.5, 40.5)
	var set_off := sim.now
	while h.charging and h.blow_phase(sim.now) == &"windup":
		sim.slices(1)
	check(not h.charging, "the wall ended the run")
	lt(sim.now - set_off, float(h.blow.windup), "before its windup was out (%.0f ms)" % (sim.now - set_off))
	lt(h.pos.x + FightSim.move_radius(h), 42.05, "and it stands at the rock")


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


func test_harvester_second_act_at_half_health() -> void:
	var sim := F.make_sim()
	var h := F.still(sim, &"harvester", Vector2(22.5, 20.5), PI)
	var first := h.bite
	h.health = int(floor(h.max_health * float(h.row.then_at))) + 1
	sim.hero.pos = h.pos + Vector2(-(h.radius + sim.hero.radius + 0.3), 0)
	sim.press_swing()
	F.ms(sim, 200)
	var events := sim.drain()
	check(h.second_act, "the second act starts")
	eq(F.count(events, &"second_act"), 1)
	check(h.bite != first, "a different bite")
	lt(float(h.bite.windup), float(first.windup), "faster")
	gt(h.bite.width, first.width, "and wider")


func test_a_blow_in_the_working_part_stops_the_work_once_in_a_while() -> void:
	var sim := F.make_sim()
	var h := F.still(sim, &"harvester", Vector2(23.5, 20.5), PI)
	sim.hero.pos = h.pos + Vector2(-(h.radius + sim.hero.radius + 0.3), 0)
	h.start_blow(h.bite, sim.now)
	sim.press_swing()
	F.ms(sim, 120)
	check(h.stunned(sim.now), "stalled")
	check(h.blow != null and h.blow_phase(sim.now) != &"windup" and h.spent(sim.now),
		"its tell is lost, and it stands spent as if the bite had gone past (FightSim._break_tell)")
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


func test_a_standing_machine_eases_the_player_out_of_itself() -> void:
	var sim := F.make_sim()
	var h := F.still(sim, &"harvester", Vector2(22.5, 20.5), PI)
	h.bite = null
	sim.hero.pos = h.pos + Vector2(0.2, 0.1)
	F.ms(sim, 600)
	gt(sim.hero.pos.distance_to(h.pos), h.radius, "no longer inside it")


func test_a_charge_shoulders_the_player_off_its_line_and_never_hides_them() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
	var h := sim.add_mob(&"harvester", Vector2(46.5, 40.5))
	h.facing = PI
	h.aim = PI
	h.calm_until = 0.0
	h.set_mood(MobState.ATTACKING, sim.now)
	var inside := 0
	var samples := 0
	for i in 150:
		F.ms(sim, 40)
		sim.hero.health = FightRules.HEALTH
		samples += 1
		if h.pos.distance_to(sim.hero.pos) < h.radius:
			inside += 1
	lt(float(inside) / samples, 0.05, "inside the hull %d of %d looks" % [inside, samples])


func test_the_tell_and_the_run_are_announced() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(40.5, 40.5))
	var h := sim.add_mob(&"harvester", Vector2(45.5, 40.5))
	h.facing = PI
	h.aim = PI
	h.calm_until = 0.0
	h.set_mood(MobState.ATTACKING, sim.now)
	var windup := {}
	var charge := {}
	for i in 60:
		F.ms(sim, 40)
		for e in sim.drain():
			if e.type == &"windup" and windup.is_empty():
				windup = e
				eq(h.blow_phase(sim.now) in [&"windup", &"active"], true, "said as the tell starts")
			elif e.type == &"charge" and charge.is_empty():
				charge = e
	check(not charge.is_empty() and charge.mob == h, "a run is announced")
	check(not windup.is_empty() and windup.mob == h, "and so is a bite")


## A FLEEING BODY CAUGHT IN A FOLD OF THE LAND GETS OUT OF IT. Straight away from
## the player into a hollow in a cliff, it used to push the wall and step to the
## same side for half a second, over and over: a clerk carrying a record stood
## "fleeing" 16 tiles out of a yard until the record filed on its clock
## (raids.tour, main, 2 runs in 3).
func test_a_fleeing_body_in_a_fold_of_the_land_gets_out() -> void:
	var w := F.flat_world(96)
	for x in range(44, 53):
		w.level[50 * w.size + x] = 8
	for y in range(50, 57):
		w.level[y * w.size + 44] = 8
		w.level[y * w.size + 52] = 8
	var sim := F.make_sim(w, Vector2(48.5, 60.5))
	var c := sim.add_mob(&"clerk", Vector2(48.5, 53.5))
	c.set_mood(MobState.FLEEING, sim.now)
	var t := 0
	while t < 15000 and c.mood == MobState.FLEEING and c.alive and not c.removed:
		F.ms(sim, 250)
		t += 250
	check(c.removed or c.mood != MobState.FLEEING or c.pos.distance_to(sim.hero.pos) >= float(c.stat("safe", 12)),
		"out of the fold and clear within 15 s (at %s, %.1f from the player, %s)" % [c.pos, c.pos.distance_to(sim.hero.pos), c.mood])



## PAST ITS TETHER, A MACHINE STAYS IN A FIGHT THE PLAYER IS STILL IN
## (FightSim._tethered). A crowd's fight drifts, and a harvester walked home at
## full health from a player five tiles off, mid-fight. Inside its `safe` and on
## its own landscape it stays at them; a player who breaks off past that range
## ends the chase at the tether as ever; a body dragged off its landscape, and a
## keeper, still go home.
func _past_tether(kind: StringName, player_off: float, other_land := false) -> MobState:
	var w := F.flat_world(160)
	if other_land:
		for y in 160:
			for x in range(80, 160):
				w.country[y * 160 + x] = Country.BONELANDS
	var sim := F.make_sim(w, Vector2(20.5, 80.5))
	var m := sim.add_mob(kind, Vector2(20.5, 80.5))
	m.home = Vector2(20.5, 80.5)
	m.pos = m.home + Vector2(float(m.stat("tether", 30)) + 8.0 + (60.0 if other_land else 0.0), 0.0)
	sim.hero.pos = m.pos + Vector2(player_off, 0.0)
	m.facing = 0.0
	m.aim = 0.0
	m.calm_until = 0.0
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	F.ms(sim, 1500)
	return m


func test_past_its_tether_a_machine_stays_in_a_fight_the_player_is_still_in() -> void:
	var m := _past_tether(&"harvester", 5.0)
	check(not m.flee_home, "five tiles from the player it stays in the fight (%s)" % m.mood)


func test_a_player_who_breaks_off_ends_the_chase_at_the_tether() -> void:
	var m := _past_tether(&"harvester", float(Roster.row(&"harvester").get("safe", 12)) + 3.0)
	check(m.flee_home, "past its safe range it goes home (%s)" % m.mood)


func test_a_machine_dragged_off_its_landscape_still_goes_home() -> void:
	var m := _past_tether(&"harvester", 5.0, true)
	check(m.flee_home, "off its own landscape it goes home with the player close (%s)" % m.mood)


func test_a_keeper_keeps_its_own_den_past_its_tether() -> void:
	var m := _past_tether(&"sentinel.coast", 5.0)
	check(m.flee_home, "a keeper takes no fight-range exemption (%s)" % m.mood)
