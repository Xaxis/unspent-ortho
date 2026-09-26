extends TestCase
## Darts take what they came for and go: a warden's arrest costs more at each
## meeting, gulls take food, a clerk that gets clear files you.

const F := preload("res://tests/fight/fixture.gd")


func test_warden_arrests_compound_to_the_cap() -> void:
	var body := Body.new()
	var got: Array[float] = []
	for i in 5:
		got.append(float(Snatch.apply(&"warden", body, null, 0.0).minutes))
	eq(got, [60.0, 120.0, 180.0, 240.0, 240.0] as Array[float])
	eq(body.health, 12, "never hurts")


func test_gulls_take_food_or_nothing() -> void:
	var inv := Inventory.new()
	inv.add(&"mussels", 2)
	inv.add(&"stone", 1)
	var r := Snatch.apply(&"gulls", Body.new(), inv, 0.0)
	eq(r.took, &"mussels")
	eq(inv.count(&"mussels"), 1)
	eq(inv.count(&"stone"), 1, "not the stone")
	var empty := Inventory.new()
	var r2 := Snatch.apply(&"gulls", Body.new(), empty, 0.0)
	eq(r2.took, &"")
	check(String(r2.line).contains("nothing"), "a line that says so")


func test_flock_costs_time_and_a_wound() -> void:
	var body := Body.new()
	var r := Snatch.apply(&"flock", body, null, 100.0)
	near(float(r.minutes), 90.0, 0.001)
	check(r.hurt)
	gt(body.hurt_until, 100.0 + 90.0)


func test_clerk_reads_you_and_files_when_clear() -> void:
	var sim := F.make_sim(F.flat_world(96, Ground.ASH, Country.BURNING), Vector2(40.5, 40.5))
	var c := sim.add_mob(&"clerk", Vector2(46.5, 40.5))
	F.ms(sim, 6000)
	var events := sim.drain()
	eq(F.count(events, &"snatch"), 1, "it came close and read you")
	eq(F.count(events, &"filed"), 1, "and got clear with it")
	check(c.removed, "and is gone")
	eq(sim.fight_on, false, "darts are never a fight")


func test_a_clerk_caught_first_files_nothing() -> void:
	var sim := F.make_sim(F.flat_world(96, Ground.ASH, Country.BURNING), Vector2(40.5, 40.5))
	var c := F.still(sim, &"clerk", Vector2(41.2, 40.5), PI)
	sim.press_swing()
	F.ms(sim, 300)
	var events := sim.drain()
	eq(F.count(events, &"killed"), 1, "life 6 scales to one blow")
	check(not c.alive)
	eq(F.count(events, &"filed"), 0)


func test_a_meeting_shuts_every_dart_out_for_hours() -> void:
	var sim := F.make_sim(F.flat_world(96, Ground.ASH, Country.BURNING), Vector2(40.5, 40.5))
	var coast := Coast.new(sim, Spawner.new())
	# The dart gaps alone: no first meeting holding the hunters back (test_presence has that).
	coast.rounds = false
	check(coast.shut().is_empty(), "nothing shut on a fresh coast")
	var c := sim.add_mob(&"clerk", Vector2(41.5, 40.5))
	sim.snatch(c)
	var shut := coast.shut()
	check(shut.has(&"clerk") and shut.has(&"warden") and shut.has(&"gulls") and shut.has(&"flock"), "every dart: %s" % [shut.keys()])
	check(not shut.has(&"harvester") and not shut.has(&"dog.yard"), "the fights still come")
	sim.moment.minutes += Coast.MEETING_GAP - 1.0
	check(coast.shut().has(&"gulls"), "still shut just before the gap is up")
	sim.moment.minutes += 2.0
	check(coast.shut().is_empty(), "and open after")


func test_a_dart_out_keeps_its_own_kind_back() -> void:
	var sim := F.make_sim(F.flat_world(96, Ground.ASH, Country.BURNING), Vector2(40.5, 40.5))
	var spawner := Spawner.new()
	spawner.rate = 200.0
	var coast := Coast.new(sim, spawner)
	var most := 0
	var checked := false
	for i in 50:
		sim.slices(25)
		coast.tick()
		var n := _count(sim, &"clerk")
		most = maxi(most, n)
		if n == 1 and not checked and sim.last_meeting_minutes < 0.0:
			checked = true
			check(coast.shut().has(&"clerk"), "the clerk is shut for its gap")
			check(not coast.shut().has(&"gulls"), "another dart is not, until one meets you")
	check(checked, "a clerk came out")
	eq(most, 1, "one clerk out however hard the coast rolls")


func _count(sim: FightSim, kind: StringName) -> int:
	var n := 0
	for m in sim.mobs:
		if m.kind == kind:
			n += 1
	return n


## Days in a clerk's country, standing about: the coast must not read the player
## more than the gaps allow, and must still read the player at all.
##
## THREE days, not one. One day saw a single meeting, and a single meeting is not
## a measurement: putting the body's night on the sky's curve (FightRules.nightfall)
## moved that one meeting out of the day and the test failed, though the rate had
## actually RISEN — over ten days the same run gives 5 meetings on the old curve
## and 8 on the new one. A claim that rests on one event fails for noise and
## passes for nothing.
func test_a_day_in_clerk_country_meets_a_few_darts_not_dozens() -> void:
	var w := F.flat_world(96, Ground.ASH, Country.BURNING)
	var sim := F.make_sim(w, Vector2(48.5, 48.5))
	sim.moment.minutes = 2.0 * 1440.0 + 8.0 * 60.0
	var spawner := Spawner.new()
	var coast := Coast.new(sim, spawner)
	# The clock runs six times as fast as play: a day in four minutes of the sim.
	# The gaps are in world minutes, so this only makes the rolls scarcer per hour.
	const WORLD_PER_MS := 6.0 / 1000.0
	var meetings := 0
	var filings := 0
	var hours := 72.0
	var steps := int(hours * 60.0 / WORLD_PER_MS / 16.0)
	var wander := Rng.make(5, 5)
	for i in steps:
		sim.moment.minutes += 16.0 * WORLD_PER_MS
		coast.tick()
		if i % 300 == 0:
			sim.hero.move = Vector2.from_angle(wander.randf() * TAU) * 0.5
		if sim.hero.pos.distance_to(Vector2(48.5, 48.5)) > 12.0:
			sim.hero.move = (Vector2(48.5, 48.5) - sim.hero.pos).normalized() * 0.5
		sim.slices(2)
		for e in sim.drain():
			if e.type == &"snatch":
				meetings += 1
			elif e.type == &"filed":
				filings += 1
	var per_hour := meetings / hours
	print("  %.0f hours among clerks: %d meetings, %d filings (%.2f an hour)" % [hours, meetings, filings, per_hour])
	gt(float(meetings), 0.0, "a clerk country still reads you")
	lt(per_hour, 60.0 / Coast.MEETING_GAP + 0.05, "no more than the gap allows")
	check(filings <= meetings, "a filing is a meeting that got away")


## A DART ALREADY OUT KEEPS THE GAP TOO. The gap shut the darts not yet out, and
## two on the land at once (a clerk and a gull keep different gaps) could both
## reach the player: two meetings in nine game minutes on seed 1 (test_soak).
## Inside the gap the second breaks off, takes nothing, files nothing, and goes.
func test_a_second_dart_inside_the_gap_breaks_off_and_takes_nothing() -> void:
	var sim := F.make_sim(F.flat_world(96, Ground.ASH, Country.BURNING), Vector2(40.5, 40.5))
	var first := sim.add_mob(&"clerk", Vector2(46.5, 40.5))
	var second := sim.add_mob(&"clerk", Vector2(34.5, 40.5))
	F.ms(sim, 12000)
	var events := sim.drain()
	eq(F.count(events, &"snatch"), 1, "one meeting, not two")
	eq(F.count(events, &"filed"), 1, "and one clerk files")
	check(first.snatched and second.snatched, "both came close and turned for home")
	check(first.removed and second.removed, "and both are gone")
