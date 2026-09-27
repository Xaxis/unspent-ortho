extends TestCase
## A HOLDING'S GUNS ANSWER WHAT IS STRIKING ITS WALLS FIRST (TurretRules.wants):
## a raider at a wall piece, blow on blow, is the one thing a defence is for, so
## it is shot before a nearer raider only walking up.

const F := preload("res://tests/fight/fixture.gd")


func test_a_raider_at_the_wall_is_shot_before_a_nearer_one() -> void:
	var sim := F.make_sim()
	var gun := sim.hero.pos
	var near := sim.add_mob(&"runner", gun + Vector2(2.0, 0.0))
	var at_wall := sim.add_mob(&"hauler", gun + Vector2(0.0, 5.0))
	near.raider = true
	at_wall.raider = true
	eq(TurretRules.pick(sim.mobs, gun, Callable(), sim.now), near, "with nobody at the wall, the nearer raider")
	at_wall.struck_wall_at = sim.now
	eq(TurretRules.pick(sim.mobs, gun, Callable(), sim.now), at_wall, "one striking the wall is shot first")
	gt(float(TurretRules.wants(at_wall, sim.now)), float(TurretRules.wants(near, sim.now)), "it is wanted more")
	sim.now += TurretRules.AT_WALL_MS + 100.0
	eq(TurretRules.pick(sim.mobs, gun, Callable(), sim.now), near, "and a while after its last blow, it is only a raider again")
