extends TestCase
## A hurt that no body struck (a hall's turret) is dealt between fight steps, and
## the next step opens by reading the body back. It has to survive that read.

const F := preload("res://tests/fight/fixture.gd")


func test_a_hurt_dealt_between_steps_is_kept_by_the_next_step() -> void:
	var sim := F.make_sim()
	F.ms(sim, 200)
	var before := sim.hero.health
	var b := HallTurret.blow()
	check(sim.strike_hero(b, sim.hero.pos + Vector2(4.0, 0.0)), "the blow landed")
	F.ms(sim, 100)
	eq(sim.hero.health, before - b.dmg, "the step after did not undo the hurt")
	eq(sim.hero.body.health, sim.hero.health, "the body carries it")
