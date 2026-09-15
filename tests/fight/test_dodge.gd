extends TestCase
## Dodge: a 9 tiles/s burst decaying to 45% over 170 ms, invulnerable only in
## [50, 140) ms after the press, swing and dodge locked until 420 ms, 700 wind.

const F := preload("res://tests/fight/fixture.gd")


func test_invulnerable_only_in_the_window() -> void:
	var sim := F.make_sim()
	var hero := sim.hero
	F.ms(sim, 16)
	sim.press_dodge()
	sim.slices(1)
	var t := hero.dodge_at
	check(t > 0.0, "the dodge started")
	check(not hero.invulnerable(t + 0.0), "exposed at the press")
	check(not hero.invulnerable(t + 49.0), "exposed for the first 50 ms")
	check(hero.invulnerable(t + 50.0), "slipping from 50 ms")
	check(hero.invulnerable(t + 139.0), "slipping until 140 ms")
	check(not hero.invulnerable(t + 140.0), "exposed for the last 30 ms of the burst")


func test_burst_covers_about_a_tile() -> void:
	var sim := F.make_sim()
	var start := sim.hero.pos
	sim.hero.move = Vector2.RIGHT
	sim.press_dodge()
	sim.slices(1)
	sim.hero.move = Vector2.ZERO
	F.ms(sim, 200)
	near(sim.hero.pos.distance_to(start), 1.1, 0.12, "dodge distance")


## A wide bite whose live window is [at, at + len) ms relative to the dodge press.
func _bite_against_dodge(live_from: float, live_len: int) -> Dictionary:
	var sim := F.make_sim()
	var hero := sim.hero
	var m := F.still(sim, &"harvester", Vector2(22.9, 20.5), PI)
	m.bite = null # its own brain must not throw one
	var b := Blow.new()
	b.windup = 200
	b.active = live_len
	b.recovery = 100
	b.cooldown = 100
	b.reach = 3.0
	b.width = 4.0
	b.dmg = 2
	b.knock = 0.0
	b.knock_ms = 0
	F.ms(sim, 24)
	# Dodge straight into it, so the burst never leaves the box.
	hero.move = Vector2.RIGHT
	var press_at := sim.now
	sim.press_dodge()
	m.start_blow(b, press_at + FightRules.SLICE_MS + live_from - b.windup)
	sim.slices(1)
	hero.move = Vector2.ZERO
	F.ms(sim, 500)
	return {"sim": sim, "events": sim.drain(), "health": hero.health}


func test_a_blow_live_only_inside_the_window_slips_past() -> void:
	var r := _bite_against_dodge(60.0, 64)
	eq(r.health, FightRules.HEALTH, "no damage taken")
	eq(F.count(r.events, &"hurt"), 0)
	eq(F.count(r.events, &"evaded"), 1, "the blow passed through the dodge")


func test_a_blow_at_the_press_lands() -> void:
	var r := _bite_against_dodge(0.0, 40)
	eq(r.health, FightRules.HEALTH - 2, "hit in the first 50 ms")


func test_a_blow_still_live_after_the_window_lands() -> void:
	var r := _bite_against_dodge(96.0, 120)
	eq(r.health, FightRules.HEALTH - 2, "slipping does not spend the blow; it lands after 140 ms")


func test_dodge_locks_swing_and_dodge_until_420() -> void:
	var sim := F.make_sim()
	var hero := sim.hero
	F.ms(sim, 16)
	sim.press_dodge()
	sim.slices(1)
	var t := hero.dodge_at
	eq(hero.swing_refusal(t + 300.0), &"dodge_locked")
	eq(hero.dodge_refusal(t + 419.0), &"dodge_locked")
	eq(hero.swing_refusal(t + 420.0), &"")
	eq(hero.dodge_refusal(t + 420.0), &"")


func test_wind_pays_for_dodges() -> void:
	var sim := F.make_sim()
	var hero := sim.hero
	F.ms(sim, 16)
	hero.wind = 1500.0
	sim.press_dodge()
	sim.slices(1)
	near(hero.wind, 800.0, 1.0, "a dodge costs 700")
	F.ms(sim, 430)
	hero.wind = 600.0
	eq(hero.dodge_refusal(sim.now), &"winded", "refused below 700")
	near(FightRules.max_wind(false, 1.0), 2400.0, 0.1)
	near(FightRules.max_wind(true, 1.0), 3100.0, 0.1, "a brace adds 700")
	near(FightRules.max_wind(false, 0.2), 840.0, 0.1, "a worn body floors at 35%")


func test_swing_costs_wind_and_is_never_refused_for_it() -> void:
	var sim := F.make_sim()
	var hero := sim.hero
	sim.slices(1)
	hero.wind = 50.0
	sim.press_swing()
	sim.slices(1)
	check(hero.blow != null, "swung with no wind")
	lt(hero.wind, 5.0, "fists cost 120, floored at 0 (then one slice of breath back)")


func test_shift_tap_dodges_and_hold_runs() -> void:
	var d := DodgeInput.new()
	check(not d.shift_pressed(1000.0, false), "out of a fight a press is not yet a dodge")
	check(d.shift_released(1120.0), "a tap is")
	check(not d.shift_pressed(2000.0, false))
	check(not d.shift_released(2600.0), "a hold only ran")
	check(d.shift_pressed(3000.0, true), "in a fight the press dodges at once")
	check(not d.shift_released(3050.0), "and the release does not dodge twice")
