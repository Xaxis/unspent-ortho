extends TestCase
## Blows respect levels (FightRules.levels_meet): a body a whole ledge (two
## levels) above or below is out of every blow, both ways, while a body one
## step away is in the same fight it always was. So a ledge is a place to stand
## off and a place to come down from, never a place to be bitten through.

const F := preload("res://tests/fight/fixture.gd")

## The hero's tile column and everything west of it is raised by `rise` levels.
const EDGE_X := 21


func _ledge(rise: int) -> FightSim:
	var w := F.flat_world(64, Ground.GRASS, Country.COAST, 2)
	for y in w.size:
		for x in EDGE_X:
			w.level[y * w.size + x] = 2 + rise
	return F.make_sim(w, Vector2(20.6, 20.5))


## A dog just below the lip, facing the hero, its bite thrown at once.
func _bitten(rise: int) -> int:
	var sim := _ledge(rise)
	var m := F.still(sim, &"dog.yard", Vector2(21.35, 20.5), PI)
	m.start_blow(m.bite.copy(), sim.now)
	F.ms(sim, 700)
	return F.count(sim.drain(), &"hurt")


## The hero swings east off the lip at a dog below it.
func _struck(rise: int) -> Array[Dictionary]:
	var sim := _ledge(rise)
	F.still(sim, &"dog.yard", Vector2(21.35, 20.5), PI)
	sim.hero.facing = 0.0
	sim.press_swing()
	F.ms(sim, 300)
	return sim.drain()


func test_a_body_a_ledge_below_cannot_bite_a_hero_on_it() -> void:
	eq(_bitten(2), 0, "a dog two levels down bit the hero on the ledge")


func test_a_body_a_step_below_still_bites() -> void:
	eq(_bitten(1), 1, "one level is a step, not a ledge: the bite lands")
	eq(_bitten(0), 1, "on the flat the bite lands")


func test_a_blow_off_a_ledge_does_not_reach_a_body_below() -> void:
	var ev := _struck(2)
	eq(F.count(ev, &"hit"), 0, "a swing two levels down landed")
	eq(F.count(ev, &"whiff"), 1, "and it is a swing at air")


func test_a_blow_down_a_step_lands() -> void:
	eq(F.count(_struck(1), &"hit"), 1, "a swing one level down landed")


func test_the_rule_is_the_same_both_ways() -> void:
	check(FightRules.levels_meet(2, 2), "level")
	check(FightRules.levels_meet(2, 3) and FightRules.levels_meet(3, 2), "a step either way")
	check(not FightRules.levels_meet(2, 4) and not FightRules.levels_meet(4, 2), "a ledge either way")
