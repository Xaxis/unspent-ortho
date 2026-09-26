extends TestCase
## How a fight ends: won, away, downed (+180 and the threat's toll, wake at 6,
## coast cleared, no death), carried (+480, woken at the nearest rock face
## facing it, lamp burnt out).

const F := preload("res://tests/fight/fixture.gd")


func test_downed_when_health_runs_out() -> void:
	var sim := F.make_sim()
	var hero := sim.hero
	var dog := F.still(sim, &"dog.yard", Vector2(21.3, 20.5), PI)
	dog.calm_until = 0.0
	dog.set_mood(MobState.ATTACKING, sim.now)
	hero.body.health = 1
	F.ms(sim, 3000)
	var e := F.first(sim.drain(), &"outcome")
	eq(e.get("outcome", &""), &"downed")
	eq((e.get("by") as MobState).kind, &"dog.yard", "knows what put you down")
	eq(hero.health, FightRules.DOWNED_WAKE_HEALTH, "wakes at half health")
	eq(sim.living(), 0, "mobs cleared")
	eq(sim.fight_on, false)


func test_downed_costs_180_minutes_and_the_toll() -> void:
	var body := Body.new()
	body.health = 0
	var clock := WorldClock.new(10.0)
	var before := clock.minutes
	var r := Outcomes.downed(body, clock, &"dog.yard")
	near(clock.minutes - before, 180.0 + 25.0, 0.001, "180 and a yard dog's 25")
	near(float(r.minutes), 205.0, 0.001)
	eq(body.health, FightRules.DOWNED_WAKE_HEALTH)
	gt(body.hurt_until, clock.minutes, "wakes hurt")
	var bare := WorldClock.new(10.0)
	Outcomes.downed(Body.new(), bare, &"")
	near(bare.minutes - 600.0, 180.0, 0.001, "no threat, no toll")


func test_carried_costs_a_shift_and_wakes_at_the_rock_facing_it() -> void:
	var w := F.flat_world(96)
	var ore := WorldProp.new(1, PropKind.IRON_ORE, Vector2(70.5, 60.5), 0.0, 1.0)
	var far_ore := WorldProp.new(2, PropKind.COAL_ORE, Vector2(90.5, 90.5), 0.0, 1.0)
	w.add_prop(ore)
	w.add_prop(far_ore)
	var q := WorldQuery.new(w)
	var body := Body.new()
	body.lamp_lit = true
	var clock := WorldClock.new(14.0)
	var before := clock.minutes
	var r := Outcomes.carried(body, Inventory.new(), clock, w, q, Vector2(10.5, 10.5))
	near(clock.minutes - before, 480.0, 0.001, "a shift")
	check(r.moved, "taken somewhere")
	var at: Vector2 = r.pos
	lt(at.distance_to(ore.pos), 1.6, "beside the nearest ore")
	near(wrapf(float(r.facing) - (ore.pos - at).angle(), -PI, PI), 0.0, 0.001, "facing it")
	eq(body.lamp_lit, false, "the lamp is burnt out")
	gt(body.hurt_until, clock.minutes)


func test_carried_with_no_rock_in_range_stays_put() -> void:
	var w := F.flat_world(64)
	var q := WorldQuery.new(w)
	var r := Outcomes.carried(Body.new(), null, WorldClock.new(), w, q, Vector2(10.5, 10.5))
	eq(r.moved, false)
	eq(r.pos, Vector2(10.5, 10.5))


func test_won_when_every_hostile_is_dead() -> void:
	var sim := F.make_sim()
	var dog := F.still(sim, &"dog.yard", Vector2(21.2, 20.5), PI)
	dog.health = 1
	dog.bite = null
	dog.calm_until = 0.0
	dog.set_mood(MobState.ATTACKING, sim.now)
	F.ms(sim, 16)
	check(sim.fight_on, "a pressing body starts a fight")
	sim.hero.facing = 0.0
	sim.press_swing()
	F.ms(sim, 300)
	var events := sim.drain()
	eq(F.count(events, &"killed"), 1)
	eq(F.first(events, &"outcome").get("outcome", &""), &"won")


func test_away_when_the_hostile_is_left_behind() -> void:
	var sim := F.make_sim(F.flat_world(128), Vector2(20.5, 20.5))
	var dog := F.still(sim, &"dog.yard", Vector2(23.5, 20.5), PI)
	dog.calm_until = 0.0
	dog.set_mood(MobState.CHASING, sim.now)
	# An old dog: slower than a running player.
	dog.dash = 2.0
	dog.quick = 2.0
	F.ms(sim, 16)
	check(sim.fight_on)
	var outcome := &""
	sim.hero.move = Vector2(-1, 1).normalized()
	sim.hero.run = true
	for i in 100:
		F.ms(sim, 100)
		dog.lost_beats = 0
		var e := F.first(sim.drain(), &"outcome")
		if not e.is_empty():
			outcome = e.outcome
			break
	eq(outcome, &"away")
	gt(Senses.chebyshev(dog.pos, sim.hero.pos), FightRules.AWAY_DISTANCE, "it was left behind")
	gt(dog.calm_until, sim.now, "the survivor calms before it can start again")


func test_something_coming_from_far_off_is_not_yet_a_fight() -> void:
	var sim := F.make_sim(F.flat_world(96), Vector2(20.5, 20.5))
	var dog := F.still(sim, &"dog.yard", Vector2(34.5, 20.5), PI)
	dog.calm_until = 0.0
	dog.set_mood(MobState.CHASING, sim.now)
	F.ms(sim, 16)
	eq(sim.fight_on, false, "fourteen tiles off, it is only coming")
	var began := -1.0
	var outcome := &""
	for i in 60:
		F.ms(sim, 100)
		for e in sim.drain():
			if e.type == &"fight_started" and began < 0.0:
				began = sim.now
			elif e.type == &"outcome":
				outcome = e.outcome
		if dog.mood == MobState.ATTACKING:
			break
	gt(began, 0.0, "it became a fight when it arrived")
	lt(Senses.chebyshev(dog.pos, sim.hero.pos), FightRules.AWAY_DISTANCE + 1.0)
	eq(outcome, &"", "and it was never called away while it closed")


func test_an_arrest_leaves_you_beside_the_track() -> void:
	var w := F.flat_world(48, Ground.NEEDLES, Country.PINEWOOD)
	# A track three tiles wide running north-south at x 20..22.
	for y in 48:
		for x in range(20, 23):
			w.ground[y * 48 + x] = Ground.ROAD
	# West of it a cliff, so the nearest ground a step away is to the east.
	for y in 48:
		w.level[y * 48 + 19] = 5
	var q := WorldQuery.new(w)
	var r := Outcomes.off_the_track(w, q, Vector2(20.6, 10.5))
	check(r.moved, "moved")
	var at: Vector2 = r.pos
	eq(w.ground_at(floori(at.x), floori(at.y)), Ground.NEEDLES, "off the road")
	eq(floori(at.x), 23, "on the near side that is not a cliff")
	lt(absf(at.y - 10.5), 1.01, "beside where you stood, not down the track")
	var already := Outcomes.off_the_track(w, q, Vector2(30.5, 10.5))
	eq(already.moved, false, "already off it: stay")
	eq(already.pos, Vector2(30.5, 10.5))


## Coming round at 3 of 12 left a new player one bite from the next downing for
## most of a morning; half health, and a fire to mend by, is a way back.
func test_a_downed_player_wakes_at_half_and_mends_faster_by_a_fire() -> void:
	eq(FightRules.DOWNED_WAKE_HEALTH, FightRules.HEALTH / 2, "half health")
	near(FightRules.mend_minutes(false), 60.0, 0.001, "a point an hour out on the land")
	near(FightRules.mend_minutes(true), 15.0, 0.001, "four an hour by a fire")
