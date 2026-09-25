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
