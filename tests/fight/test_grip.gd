extends TestCase
## Grip: a seizing bite holds the feet and the dodge; the swing key pulls,
## one a press bare and two with a cutting tool, 140 ms apart; held 6000 ms
## and you are carried.

const F := preload("res://tests/fight/fixture.gd")


## A body of `kind` whose bite has just closed on the hero.
func _seized(kind: StringName, held_item: StringName = &"") -> FightSim:
	var sim := F.make_sim(F.flat_world(64, Ground.WATER))
	if held_item != &"":
		sim.hero.inventory.add(held_item)
		sim.hero.inventory.set_held(held_item)
	var m := F.still(sim, kind, Vector2(22.0, 20.5), PI)
	sim.hero.pos = m.pos + Vector2(-(m.radius + sim.hero.radius + 0.4), 0)
	m.start_blow(m.bite, sim.now)
	F.ms(sim, m.bite.windup + m.bite.active + 16)
	return sim


func _pulls_to_free(sim: FightSim) -> int:
	var n := 0
	while sim.hero.held() and n < 10:
		F.ms(sim, 150)
		sim.press_swing()
		n += 1
	return n


func test_dredger_seizes_without_damage() -> void:
	var sim := _seized(&"dredger")
	var events := sim.drain()
	eq(sim.hero.grip, 4, "a dredger's grip is 4")
	eq(F.count(events, &"grip"), 1)
	eq(sim.hero.health, FightRules.HEALTH, "a grip does no damage")
	check(not sim.hero.invulnerable(sim.now), "and gives no i-frames")


func test_dredger_bare_takes_four_pulls_cut_takes_two() -> void:
	eq(_pulls_to_free(_seized(&"dredger")), 4, "bare hands")
	eq(_pulls_to_free(_seized(&"dredger", &"knife")), 2, "a knife cuts")


func test_lineman_bare_takes_three_cut_takes_two() -> void:
	eq(_pulls_to_free(_seized(&"lineman")), 3)
	eq(_pulls_to_free(_seized(&"lineman", &"knife")), 2)


func test_pulls_closer_than_140_ms_do_not_count() -> void:
	var sim := _seized(&"dredger")
	sim.press_swing()
	F.ms(sim, 80)
	sim.press_swing()
	eq(sim.hero.grip, 3, "the second press was too soon")
	F.ms(sim, 80)
	sim.press_swing()
	eq(sim.hero.grip, 2)


func test_held_feet_and_dodge_are_refused() -> void:
	var sim := _seized(&"dredger")
	var holder := sim.hero.holder
	eq(sim.hero.dodge_refusal(sim.now), &"held")
	sim.hero.move = Vector2.LEFT
	sim.hero.run = true
	F.ms(sim, 500)
	var mouth := holder.pos + Vector2.from_angle(holder.facing) * (holder.radius + sim.hero.radius * 0.6)
	lt(sim.hero.pos.distance_to(mouth), 0.5, "walking away does nothing; it draws you to the jaw")
	sim.press_dodge()
	F.ms(sim, 50)
	eq(sim.hero.held(), true)


func test_held_six_seconds_is_carried() -> void:
	var sim := _seized(&"dredger")
	sim.drain()
	F.ms(sim, 5800)
	eq(F.count(sim.drain(), &"outcome"), 0, "not yet")
	F.ms(sim, 300)
	var e := F.first(sim.drain(), &"outcome")
	eq(e.get("outcome", &""), &"carried")
	eq(sim.hero.grip, 0, "let go")
	eq(sim.living(), 0, "the coast is cleared")


func test_freed_when_no_living_holder_remains() -> void:
	var sim := _seized(&"dredger")
	sim.drain()
	var m := sim.hero.holder as MobState
	m.alive = false
	F.ms(sim, 16)
	eq(sim.hero.held(), false, "no living holder, no grip")
	eq(F.count(sim.drain(), &"loose"), 1)


func test_second_act_turns_the_grip_into_a_swing() -> void:
	var sim := _seized(&"dredger")
	var m := sim.hero.holder as MobState
	sim.hero.release()
	sim.hero.blow = null
	sim.hero.pos = m.pos + Vector2.from_angle(m.facing) * (m.radius + sim.hero.radius + 0.2)
	sim.hero.facing = (m.pos - sim.hero.pos).angle()
	m.health = int(floor(m.max_health * 0.45)) + 1
	F.ms(sim, 600)
	sim.press_swing()
	F.ms(sim, 200)
	check(m.second_act, "at 45% the dredger changes")
	eq(m.bite.grip, 0, "and no longer takes hold")
	eq(m.bite.dmg, 4)
