extends TestCase
## A CITY STREET, and the three things that make one: everybody is working, the
## crowd is indifferent to a stranger, and violence in front of it is expensive.
##
## The measurements here are the point as much as the passes. A crowd is where
## `PersonLook`'s caps actually bind, and the numbers below are what they bind
## at, taken rather than assumed.

const Fx := preload("res://tests/fight/fixture.gd")

static var _world: WorldData


func _game(hour: float = 12.0) -> Game:
	if _world == null:
		_world = WorldGen.generate(5)
	var g := Game.new()
	g.world = _world
	g.query = WorldQuery.new(_world)
	g.clock = WorldClock.new(hour)
	g.player = Player.new()
	g.player.world = _world
	g.player.query = g.query
	g.player.pos = _world.spawn
	return g


func _folk(g: Game) -> GameSystem:
	var f: GameSystem = (load("res://src/systems/35_folk.gd") as GDScript).new()
	f.game = g
	return f


func _free(g: Game, f: GameSystem) -> void:
	for p: Dictionary in f.get("folk"):
		(p.model as Node).free()
	f.free()
	g.player.free()
	g.free()


## How many others somebody must stand among before they stop looking up.
func _blind() -> int:
	var s := load("res://src/systems/35_folk.gd") as GDScript
	return int(s.get_script_constant_map()["CROWD_BLIND"])


## Stand `n` people round the player and settle who is standing among whom.
func _street(g: Game, n: int) -> GameSystem:
	var f := _folk(g)
	f.call("_ring", n)
	f.call("_count_crowd")
	return f


# ---------------------------------------------------------------- the trades

func test_every_street_trade_is_somebody_at_work_and_still_reads_apart() -> void:
	for trade: StringName in PersonLook.STREET_TRADES:
		var carried := 0
		for i in 40:
			var d := PersonLook.dress(PersonLook.random(31, i), {}, trade, i)
			eq(d.trade, trade, "%s is kept by normalize" % trade)
			check(PersonLook.contrast_ok(d), "%s %d still meets the contrast bar" % [trade, i])
			lt((d.salvage as Array).size(), 3, "%s is a stranger, not a kitted player" % trade)
			lt((d.gear as Array).size(), PersonLook.GEAR_MAX + 1, "%s carries no more than a body can" % trade)
			if not (d.gear as Array).is_empty() or not (d.extras as Array).is_empty() or not (d.salvage as Array).is_empty():
				carried += 1
		# Working is the whole of what the place says, so every trade has to show
		# it on the body somewhere.
		gt(float(carried) / 40.0, 0.8, "%s shows its work on the body" % trade)


func test_a_preacher_carries_nothing_and_a_courier_is_never_bent() -> void:
	for i in 40:
		var p := PersonLook.dress(PersonLook.random(47, i), {}, &"preacher", i)
		eq((p.gear as Array).size(), 0, "a preacher carries nothing")
		gt(int(p.gaunt), 0, "and is hungry with it")
		var c := PersonLook.dress(PersonLook.random(51, i), {}, &"courier", i)
		check(c.build != &"old" and c.build != &"bent", "a courier sells legs")


func test_no_village_anywhere_is_ever_dealt_a_street_trade() -> void:
	# The whole reason STREET_TRADES is a separate list: dealing one to a coast
	# village would put a city's wraps on a fishing hamlet and move every frame
	# already taken.
	for land: StringName in [&"coast", &"snowfield", &"moss", &"burning"]:
		var hz: Dictionary = BiomeRegistry.get_def(land).hazards
		for d: Dictionary in PersonLook.villagers(3, 40, hz):
			check(not PersonLook.STREET_TRADES.has(d.trade), "%s dealt %s to a village" % [land, d.trade])


# ---------------------------------------------------------------- the caps

func test_how_many_silhouettes_a_crowd_can_actually_hold() -> void:
	# MEASURED, not assumed. `random()` draws build x FAIR_HATS x FAIR_COATS and
	# insists on two of {build, hat, coat} differing from the base man, so the
	# space is smaller than BUILDS x HATS x COATS suggests. Ask for far more than
	# a street needs and see where it stops.
	var most := PersonLook.crowd(9, 400).size()
	print("  crowd: %d distinct silhouettes at the ceiling (build x fair hat x fair coat = %d)" % [most, 10 * 7 * 4])
	gt(most, 120, "a crowd can hold more silhouettes than any street needs (%d)" % most)
	lt(most, 10 * 7 * 4 + 1, "and never more than build x fair hat x fair coat")
	# What a real street asks for, which must be met exactly.
	for n: int in [24, 40, 60]:
		eq(PersonLook.crowd(9, n).size(), n, "a street of %d is dealt in full" % n)


func test_a_street_of_forty_keeps_its_silhouettes_apart() -> void:
	# The dense case the village test never reached: forty people, dressed for a
	# land with real weather in it and set apart from each other afterwards.
	var hz := {&"dark": 0.7, &"fumes": 0.5, &"wet": 0.3}
	var taken := {}
	var sigs := {}
	var repeats := 0
	var i := 0
	for spec: Dictionary in PersonLook.crowd(77, 40):
		var trade := PersonLook.street_trade(77, i)
		var d := PersonLook.set_apart(PersonLook.dress(spec, hz, trade, 77 * 31 + i), taken, hz, 77 * 17 + i)
		var sig := PersonLook.signature(d)
		if sigs.has(sig):
			repeats += 1
		sigs[sig] = true
		check(PersonLook.contrast_ok(d), "%d of forty still meets the contrast bar" % i)
		i += 1
	# dress() pushes a whole street toward the one hood its weather asks for, and
	# set_apart only has the hats and coats that land still allows to pull them
	# back with. Some collision is the honest outcome; a street that was mostly
	# one silhouette would not be.
	print("  street of 40 in dark/fumes/wet: %d distinct silhouettes, %d repeats" % [sigs.size(), repeats])
	lt(repeats, 8, "forty on one street: %d repeated silhouettes of 40" % repeats)
	gt(sigs.size(), 32, "and %d distinct ones" % sigs.size())


# ---------------------------------------------------------------- the tag

func test_a_passer_never_joins_the_fight_however_hard_it_is_provoked() -> void:
	# THE CONDITION ON THE TAG EXCEPTION (docs/LOOK.md, ui_target_view.gd). A
	# body may carry no wordless tag only if it can never become a threat: losing
	# the read at the moment something turns on you would be the pillar failing in
	# the one moment it exists for. So this does not argue it, it provokes one.
	var row := Roster.row(&"passer")
	check(not row.has("bite"), "a passer has no blow to throw")
	check(not row.has("hits"), "and takes nothing off you")

	# The plan can never hand a watcher `hostile`: Roles.FILES holds it, and
	# Disposition.of answers observant before it ever reads `disturbed`. So there
	# is no interference level and no provocation that turns this body.
	for level in Interference.LEVELS.size():
		for disturbed: bool in [false, true]:
			eq(Disposition.of(&"watcher", level, disturbed), &"observant",
				"a watcher at %s, disturbed %s" % [Interference.LEVELS[level], disturbed])
	check((Roles.TURNS[&"watcher"] as Array).is_empty(), "and nothing in the game turns it")

	# And live, in a real fight: stand one next to the player and hit it until it
	# dies, watching every slice for a mood or a blow it is not supposed to have.
	var sim := Fx.make_sim(Fx.flat_world(96, Ground.GRASS), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	var m := sim.add_mob(&"passer", Vector2(49.6, 48.5))
	m.facing = PI
	m.aim = PI
	var ever_roused := false
	var ever_blow := false
	var ever_hostile := false
	var t := 0.0
	while t < 30000.0 and m.alive:
		sim.press_swing()
		sim.slices(2)
		t += 16.0
		ever_roused = ever_roused or m.roused()
		ever_blow = ever_blow or m.bite != null or m.blow != null
		ever_hostile = ever_hostile or Disposition.hostile(m.disposition)
	print("  a passer under the knife for %.1f s: alive %s, roused %s, blow %s, hostile %s"
		% [t / 1000.0, m.alive, ever_roused, ever_blow, ever_hostile])
	check(not ever_roused, "a passer never chases and never attacks, even struck")
	check(not ever_blow, "and never has a blow to throw")
	check(not ever_hostile, "and is never hostile")
	# It is still a body the player can put down — it is unreadable, not immortal.
	check(m.health < m.max_health or not m.alive, "and a blow still tells on it")


# ---------------------------------------------------------------- the cost

func test_what_a_street_of_forty_costs_through_the_real_path() -> void:
	# THE NUMBER THAT DECIDES THE DESIGN. 35_folk builds one villager per EVEN
	# frame because building one is dear, and six per village is what that budget
	# was drawn for; a city asks for forty through the same door. This measures
	# the real path — crowd(), dress(), set_apart(), PersonModel.make(), the rig
	# and the dressing — and then what forty cost to keep, every frame, for ever.
	#
	# The build is the one-off and the step is the forever, so they are reported
	# apart: a build that is dear but STREAMED costs a ramp, not a stall.
	var g := _game()
	var f := _folk(g)
	# EACH VILLAGER TIMED ON ITS OWN, through the steps `_ring` takes: the looks
	# dealt once for the street, then every one seated (`_ring_seat`, `_standable`)
	# and built through `_add` -- dress, set_apart, PersonModel.make, the rig. This
	# timed ONE call of `_ring(40)` and divided by the count, so a single stall on
	# a shared runner landed in the average: 31.93 ms "each" on CI at 1b69d6c6
	# against 8.47 ms measured here, with nothing about villagers changed.
	var built: Array[float] = []
	var at: Vector2 = g.player.pos
	var first := int((f.get_script() as GDScript).get_script_constant_map()["RING_FIRST"])
	var t0 := Time.get_ticks_usec()
	var looks := PersonLook.crowd(g.world.seed_value * 7 + 3, 40)
	var inner := mini(looks.size(), first)
	for i in looks.size():
		var p: Vector2
		if i < first:
			var a := TAU * i / inner
			p = at + Vector2(cos(a), sin(a)) * (1.6 + 0.25 * (i % 2))
		else:
			p = f.call("_ring_seat", at, i - first)
			if not bool(f.call("_standable", p)):
				continue
		var t := Time.get_ticks_usec()
		f.call("_add", looks[i], p, &"idle", -2, float(i) / 40.0, p)
		built.append((Time.get_ticks_usec() - t) / 1000.0)
	var build_us := Time.get_ticks_usec() - t0
	var folk: Array = f.get("folk")
	var n := folk.size()
	# Asked for forty and report what STOOD: the outer ring seats test the ground,
	# so a spawn near the shore drops the ones that landed in the sea. Naming a
	# count the measurement did not take is how a number starts lying.
	gt(n, 23, "a street's worth stood up (%d of the 40 asked for)" % n)
	eq(built.size(), n, "every villager standing was timed")
	# The middle build, not the mean: a stall is the scheduler's, and one villager
	# built slowly is a hitch the stream absorbs, where a slow MIDDLE is every one.
	var each_ms := middle(built)

	# Both of these are FOREVER costs and both repeat, so they are measured
	# best-of-five rather than once: load only adds time, and the cheapest run is
	# the honest one. Measured once and widened by `machine_slack()`, this pair
	# failed at 2233 us against a bar of 1316 in the same gate run where the
	# landmarks budget had sampled a slack of 4.1 -- two shards, one machine, one
	# moment, disagreeing 3.2x about how busy it was (TestCase.machine_slack).
	f.call("_count_crowd")
	var count := func() -> void:
		f.call("_count_crowd")
	var count_us := best_of(5, count)

	var step := func() -> void:
		for row: Dictionary in folk:
			f.call("_step", row, 0.016, false)
	var step_us := best_of(5, step)

	var tris := 0
	var draws := 0
	for row: Dictionary in folk:
		var p := row.model as PersonModel
		tris += p.body_triangles() + p.tool_triangles()
		draws += p.get_child_count()

	print("  A STREET OF %d, through 35_folk's own path:" % n)
	print("    build   %6.1f ms total, %5.2f ms the middle one, %5.2f ms the slowest (streamed one an even frame: %.1f s to fill)"
		% [build_us / 1000.0, each_ms, built.max(), float(n) * 2.0 / 60.0])
	print("    step    %6.1f us a frame for all %d, %4.1f us each" % [step_us, n, float(step_us) / float(n)])
	print("    crowd   %6.1f us a tick (O(n^2), twice a second)" % count_us)
	print("    draw    %6d triangles, %d each over %d meshes" % [tris, tris / maxi(n, 1), draws])

	# The forever cost is what a frame has to carry, and it is the one that must
	# hold: a street may not cost more than a millisecond a frame to walk
	# through. No slack on it -- the measurement above already took the noise out,
	# so this bar is the real number and can still fail for a real reason.
	cost_lt(step_us + count_us * 0.5, 1000.0,
		"forty on a street cost under a millisecond a frame (%.0f us step + %.0f us count)" % [step_us, count_us])
	# And the build stays a ramp rather than a stall, because nothing builds two
	# in one frame: what a player feels is the street filling in, not a hitch.
	#
	# Building forty people is not repeatable cheaply, so there is no best-of to
	# take, and the middle of forty separate builds is the honest figure instead.
	# This used to widen the bar by `machine_slack()` instead, which is the
	# trade the file's own header argues against: widened to 3.2x it could not see
	# a regression smaller than the slack it was handed, and it still went red at
	# 41 ms in a gate sharing the machine with two other sessions.
	#
	# `cost_lt` is the third option. The bar is the REAL figure with no slack on
	# it, and on a machine too busy to measure a cost the test says so rather than
	# failing or passing meaninglessly (TestCase.can_measure_cost).
	cost_lt(each_ms, 12.0,
		"one villager still builds in the time a frame can spare (%.2f ms, the middle of %d)" % [each_ms, n])


# ---------------------------------------------------------------- indifference

func test_a_village_looks_up_and_a_street_does_not() -> void:
	var g := _game()
	var small := _street(g, 6)
	var looked := 0
	for f: Dictionary in small.get("folk"):
		small.call("_step", f, 0.1, false)
		if not is_nan((f.model as PersonModel).gaze):
			looked += 1
	gt(looked, 0, "in a village of six a stranger is an event")
	_free(g, small)

	var g2 := _game()
	var big := _street(g2, 30)
	var turned := 0
	for f: Dictionary in big.get("folk"):
		gt(int(f.near), _blind() - 1, "everybody in a street of thirty stands among enough others")
		big.call("_step", f, 0.1, false)
		if not is_nan((f.model as PersonModel).gaze):
			turned += 1
	eq(turned, 0, "in a street nobody looks up: %d heads turned" % turned)
	_free(g2, big)


func test_a_witness_is_somebody_who_is_out_and_within_reach() -> void:
	var g := _game()
	var f := _street(g, 30)
	var at: Vector2 = g.player.pos
	var near: int = f.call("witnesses", at, Interference.WITNESS_REACH)
	print("  street of 30: %d witnesses within %.0f tiles, scaling a swing x%.2f"
		% [near, Interference.WITNESS_REACH, Interference.witness_scale(near)])
	gt(near, 8, "a street of thirty is a street of witnesses (%d)" % near)
	eq(f.call("witnesses", at + Vector2(400, 400), Interference.WITNESS_REACH), 0, "nobody sees it from across the island")
	# Somebody who has gone in at their door saw nothing.
	for row: Dictionary in f.get("folk"):
		row.state = &"in"
	eq(f.call("witnesses", at, Interference.WITNESS_REACH), 0, "an empty street files nothing")
	_free(g, f)


# ---------------------------------------------------------------- the price

func test_what_counts_as_a_crowd_is_one_number_written_in_two_places() -> void:
	# Core holds no systems, so the threshold is duplicated on purpose. The whole
	# design rests on them being the same number: the point at which a stranger
	# stops being an event is the point at which a street can testify.
	eq(Interference.WITNESS_CROWD, _blind(), "Interference and 35_folk disagree about what a crowd is")


func test_nobody_watching_leaves_every_other_landscape_exactly_as_it_was() -> void:
	eq(Interference.witness_scale(0), 1.0, "an empty bog costs what it always did")
	# The regression that started this: a coast village has a couple of people
	# standing about, and pricing them as a crowd re-tuned every landscape in the
	# game. Everything under a crowd must cost precisely what the table says.
	for n in Interference.WITNESS_CROWD:
		eq(Interference.witness_scale(n), 1.0, "%d onlookers are not a crowd" % n)
	gt(Interference.witness_scale(Interference.WITNESS_CROWD), 1.0, "and one more is")
	var quiet := Interference.new()
	near(quiet.raise(1, &"sabotage", Vector2.ZERO, 0.0), Interference.CAUSES[&"sabotage"], 1e-5,
		"a raise with no witnesses named is the cause's own weight")


func test_one_swing_in_a_full_street_turns_the_network() -> void:
	var crowd := Interference.new()
	var rose := crowd.raise(1, &"sabotage", Vector2.ZERO, 0.0, Interference.WITNESS_MOST)
	gt(rose, Interference.THRESHOLDS[2], "one swing seen by a street crosses hostile (%.2f)" % rose)
	eq(crowd.level_name(1), &"hostile")
	# And the same blow where nobody is standing does not.
	var alone := Interference.new()
	var quiet := alone.raise(1, &"sabotage", Vector2.ZERO, 0.0, 0)
	lt(quiet, Interference.THRESHOLDS[1], "the same swing alone is not even wary (%.2f)" % quiet)


func test_a_crowd_only_scales_what_a_crowd_can_see() -> void:
	for cause: StringName in Interference.CAUSES:
		var seen := Interference.new().raise(1, cause, Vector2.ZERO, 0.0, Interference.WITNESS_MOST)
		var unseen := Interference.new().raise(1, cause, Vector2.ZERO, 0.0, 0)
		if Interference.WITNESSED.has(cause):
			gt(seen, unseen, "%s is something a street can watch happen" % cause)
		else:
			near(seen, unseen, 1e-5, "%s is not, so a crowd may not price it" % cause)


func test_a_lost_region_still_cannot_be_driven_past_its_ceiling_by_a_crowd() -> void:
	# The reward for breaking a depot survives the crowd: a region with nothing
	# running it can never reach `hunted`, however many people watched.
	var i := Interference.new()
	i.lose(1)
	i.raise(1, &"killed_worker", Vector2.ZERO, 0.0, Interference.WITNESS_MOST)
	lt(i.value(1), Interference.LOST_CEILING + 0.001, "a lost region keeps its ceiling")
