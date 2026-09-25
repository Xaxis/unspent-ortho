extends TestCase
## The drop strike (FightSim.drop_strike): a jump taken from a ledge above a body
## lands beside it as a blow that opens any plate for that one hit. The flat
## world here is level 2, so a take-off of 4 is a ledge over it and 2 or 3 is a
## hop or a step. A landing with nothing in reach is only a landing.

const F := preload("res://tests/fight/fixture.gd")


## A still harvester facing west (its guarded front there), the hero at its back.
func _behind_harvester() -> Array:
	var sim := F.make_sim()
	var m := F.still(sim, &"harvester", Vector2(30.5, 20.5), PI)
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.pos = m.pos + Vector2(m.radius + sim.hero.radius + 0.3, 0.0)
	sim.hero.facing = PI
	return [sim, m]


func test_a_drop_off_a_ledge_onto_its_back_opens_the_plate() -> void:
	var r := _behind_harvester()
	var sim: FightSim = r[0]
	var m: MobState = r[1]
	var before := m.health
	check(sim.drop_strike(4), "a two-level drop beside a body strikes")
	F.ms(sim, 200)
	var hit := F.first(sim.drain(), &"hit")
	check(not hit.is_empty(), "the landing met the body")
	eq(hit.get("plate", null), false, "the plate is open to it")
	check(m.health < before, "and it hurt")
	check(m.stunned(sim.now), "a blow in the part stalls the machine")


func test_the_same_blow_swung_from_there_rings() -> void:
	var r := _behind_harvester()
	var sim: FightSim = r[0]
	sim.press_swing()
	F.ms(sim, 300)
	var hit := F.first(sim.drain(), &"hit")
	eq(hit.get("plate", null), true, "a swing at its back is plate")


func test_the_plate_is_open_for_one_hit_only() -> void:
	var r := _behind_harvester()
	var sim: FightSim = r[0]
	check(sim.drop_strike(4))
	F.ms(sim, 1200)
	sim.drain()
	sim.press_swing()
	F.ms(sim, 300)
	eq(F.first(sim.drain(), &"hit").get("plate", null), true, "the next swing is a swing")


func test_a_hop_on_the_flat_is_not_a_strike() -> void:
	var r := _behind_harvester()
	var sim: FightSim = r[0]
	check(not sim.drop_strike(2), "no drop, no strike")
	check(not sim.drop_strike(3), "a step down is a step")
	F.ms(sim, 200)
	eq(F.count(sim.drain(), &"hit"), 0)


func test_a_landing_with_nothing_in_reach_is_only_a_landing() -> void:
	var sim := F.make_sim()
	F.still(sim, &"dog.yard", Vector2(30.5, 20.5), PI)
	check(not sim.drop_strike(5), "nothing near")
	F.ms(sim, 200)
	var ev := sim.drain()
	eq(F.count(ev, &"drop_strike"), 0)
	eq(F.count(ev, &"whiff"), 0, "no swing at air either")


func test_it_turns_to_the_body_whichever_way_it_came_down() -> void:
	var r := _behind_harvester()
	var sim: FightSim = r[0]
	sim.hero.facing = 0.0
	check(sim.drop_strike(4))
	near(sim.hero.facing, PI, 0.01, "faces what it came down on")
