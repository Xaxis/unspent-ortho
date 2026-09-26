extends TestCase
## HITS STACK ACROSS SOURCES (SETTLE.md S7). A machine's hurt frames stop one
## source landing twice in a window, not several: three turrets covering each
## other put three bolts into it in the same moment, and a turret and the
## player's swing both land.

const F := preload("res://tests/fight/fixture.gd")


func _target(sim: FightSim) -> MobState:
	# Facing east: its working part (the back) faces west, where the guns are.
	return F.still(sim, &"demolisher", Vector2(30.5, 30.5), 0.0)


func _gun(m: MobState, turn: float) -> Vector2:
	return m.pos + Vector2.from_angle(PI + turn) * 3.0


func test_three_covering_turrets_land_three_hits_in_one_window() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(10.5, 10.5))
	var m := _target(sim)
	var life := m.health
	var landed := 0
	for turn: float in [-0.25, 0.0, 0.25]:
		if sim.strike(m, TurretRules.blow(), _gun(m, turn)) == &"hit":
			landed += 1
	eq(landed, 3, "all three bolts land")
	eq(m.health, life - 3 * TurretRules.DMG, "and all three hurt it")


func test_one_turret_still_cannot_land_twice_in_a_window() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(10.5, 10.5))
	var m := _target(sim)
	var at := _gun(m, 0.0)
	eq(sim.strike(m, TurretRules.blow(), at), &"hit", "the first bolt lands")
	eq(sim.strike(m, TurretRules.blow(), at), &"", "the same gun's second, in the same window, does not")
	F.ms(sim, float(m.mob_iframes()) + 20.0)
	eq(sim.strike(m, TurretRules.blow(), at), &"hit", "and once the window is past, it does")
