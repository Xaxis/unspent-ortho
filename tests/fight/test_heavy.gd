extends TestCase
## The heavy blow (FightSim.press_heavy; the swing key held HEAVY_HOLD_MS): the
## held tool's blow wound up HEAVY_WINDUP_MS longer, for HEAVY_WIND wind, hitting
## an open part for HEAVY_DAMAGE times as much. Into a guarded part the machine is
## not holding open it jams the turning blades: no damage, but the machine stalls,
## and the part is open for the light blows after. Short of the wind for it, the
## swing is the light one.

const F := preload("res://tests/fight/fixture.gd")


func _sim_with_knife() -> FightSim:
	var sim := F.make_sim()
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	return sim


## A still harvester facing west, the hero at its guarded front, facing it.
func _at_front(sim: FightSim) -> MobState:
	var h := F.still(sim, &"harvester", Vector2(30.5, 20.5), PI)
	sim.hero.pos = h.pos + Vector2(-(h.radius + sim.hero.radius + 0.3), 0)
	sim.hero.facing = 0.0
	return h


func test_the_heavy_blow_is_the_light_one_slower_harder_and_dearer() -> void:
	var light := Blow.for_item(&"knife")
	var heavy := light.heavier()
	eq(heavy.windup, light.windup + FightRules.HEAVY_WINDUP_MS, "wound up longer")
	eq(heavy.dmg, light.dmg * FightRules.HEAVY_DAMAGE, "hits harder")
	near(heavy.wind_cost, FightRules.HEAVY_WIND, 0.01, "costs its wind")
	check(heavy.heavy and not light.heavy)
	eq(heavy.active, light.active, "the strike itself is the same length")


func test_holding_the_swing_throws_the_heavy_blow() -> void:
	var sim := _sim_with_knife()
	var wind := sim.hero.wind
	sim.press_heavy()
	F.ms(sim, 16)
	check(sim.hero.blow != null and sim.hero.blow.heavy, "a heavy blow is thrown")
	near(sim.hero.wind, wind - FightRules.HEAVY_WIND, 20.0, "and its wind is spent")
	var sw := F.first(sim.drain(), &"swing")
	eq(sw.get("heavy", false), true, "the swing says it is heavy")


func test_short_of_wind_it_is_the_light_swing() -> void:
	var sim := _sim_with_knife()
	sim.hero.wind = FightRules.HEAVY_WIND - 1.0
	sim.hero.body.wind = sim.hero.wind
	sim.press_heavy()
	F.ms(sim, 16)
	check(sim.hero.blow != null and not sim.hero.blow.heavy, "winded, the swing is light")


func test_it_jams_a_guarded_part_and_stalls_it() -> void:
	var sim := _sim_with_knife()
	var h := _at_front(sim)
	h.disturbed = true
	h.set_mood(MobState.ATTACKING, sim.now)
	check(not sim.reaches_part(h, sim.hero.pos), "roused, its turning blades throw a light blow off")
	check(sim.reaches_part(h, sim.hero.pos, false, true), "a heavy blow goes through them")
	var before := h.health
	sim.press_heavy()
	F.ms(sim, Blow.for_item(&"knife").heavier().windup + 60)
	var hit := F.first(sim.drain(), &"hit")
	eq(hit.get("plate", null), false, "it reached the part")
	eq(hit.get("jammed", false), true, "and jammed it")
	eq(h.health, before, "the turning blades took the blow")
	check(h.stunned(sim.now), "and the machine stands stalled")
	check(sim.reaches_part(h, sim.hero.pos), "stalled, its part is open to a light blow")


func test_into_an_open_part_it_hits_twice_as_hard() -> void:
	var sim := _sim_with_knife()
	var h := _at_front(sim)
	var before := h.health
	sim.press_heavy()
	F.ms(sim, Blow.for_item(&"knife").heavier().windup + 60)
	eq(F.first(sim.drain(), &"hit").get("plate", null), false)
	eq(before - h.health, 2 * FightRules.HEAVY_DAMAGE, "a worker at its round is open: twice a knife")


func test_it_still_rings_off_plate() -> void:
	var sim := _sim_with_knife()
	var h := _at_front(sim)
	sim.hero.pos = h.pos + Vector2(h.radius + sim.hero.radius + 0.3, 0)
	sim.hero.facing = PI
	var before := h.health
	sim.press_heavy()
	F.ms(sim, Blow.for_item(&"knife").heavier().windup + 60)
	eq(F.first(sim.drain(), &"hit").get("plate", null), true, "its back is plate to any blow")
	eq(h.health, before)


func test_a_blow_taken_in_its_windup_cancels_it_and_its_wind_stays_spent() -> void:
	var sim := _sim_with_knife()
	var h := _at_front(sim)
	var wind := sim.hero.wind
	sim.press_heavy()
	F.ms(sim, 120)
	check(sim.hero.blow != null and sim.hero.blow.heavy, "winding up")
	var spent := sim.hero.wind
	lt(spent, wind - FightRules.HEAVY_WIND + 100.0, "its wind went when it was thrown")
	check(sim.strike_hero(Roster.bite(&"dog.yard"), sim.hero.pos + Vector2(0, 1)), "struck in the windup")
	F.ms(sim, 600)
	var ev := sim.drain()
	eq(F.count(ev, &"hit"), 0, "the heavy blow never landed")
	eq(h.health, h.max_health, "and did nothing")
	check(sim.hero.blow == null, "it was taken away by the hurt")


func test_at_low_wind_no_heavy_blow_starts() -> void:
	var sim := _sim_with_knife()
	sim.hero.wind = FightRules.HEAVY_WIND * 0.5
	sim.hero.body.wind = sim.hero.wind
	sim.press_heavy()
	F.ms(sim, 16)
	var b := sim.hero.blow
	check(b != null and not b.heavy, "a light swing, not a heavy one")
	check(b != null and b.windup == Blow.for_item(&"knife").windup, "with the light swing's windup")


## A machine or a creature facing the hero, both in reach, throws its bite; the
## hero answers it as a player who has seen the tell would, `react` ms in, with
## a tap or a held swing instead of getting out of the way. What came of it.
func _answer_a_bite(kind: StringName, heavy: bool, react: float = 120.0) -> Dictionary:
	var sim := _sim_with_knife()
	var m := F.still(sim, kind, Vector2(30.5, 20.5), PI)
	m.disturbed = true
	m.calm_until = 0.0
	m.set_mood(MobState.ATTACKING, sim.now)
	sim.hero.pos = m.pos + Vector2(-(m.radius + sim.hero.radius + 0.35), 0)
	sim.hero.facing = 0.0
	Brains.bite(m, sim)
	F.ms(sim, react)
	if heavy:
		sim.press_heavy()
	else:
		sim.press_swing()
	var hurt := 0
	var landed := 0
	var t := 0.0
	while t < 900.0:
		F.ms(sim, 16)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				hurt += int(e.damage)
			elif e.type == &"hit" and not e.plate:
				landed += int(e.damage)
	return {"hurt": hurt, "landed": landed}


## The heavy blow's risk: its long windup is a blow a quicker bite comes
## through, and a blow taken in it is a blow that never lands. Answering a
## dog's bite (no plate, so only the race counts) with a held swing comes off
## worse than answering it with a tap. A runner's front is plate, so from there
## neither answer does anything: the answer to a runner is to get out of it.
func test_a_heavy_blow_into_a_bite_does_worse_than_a_tap() -> void:
	for kind: StringName in [&"dog.yard", &"dog.feral"]:
		var tap := _answer_a_bite(kind, false)
		var hold := _answer_a_bite(kind, true)
		print("  info %s's bite answered: tap %s, heavy %s" % [kind, tap, hold])
		check(int(hold.hurt) > int(tap.hurt) or int(hold.landed) < int(tap.landed),
			"%s: the heavy blow into its bite did no worse than a tap (tap %s, heavy %s)" % [kind, tap, hold])
		gt(float(hold.hurt), 0.0, "%s: its bite came through the heavy blow's windup" % kind)
		eq(int(hold.landed), 0, "%s: and the heavy blow never landed" % kind)
