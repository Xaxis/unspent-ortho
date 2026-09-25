extends TestCase
## A stall never takes away an opening the player has already earned. A machine
## that bit at nothing stands spent (recovery, then cooldown), and that is the
## reader's window; a blow in its part landed inside it stalls it, and the stall
## may only ever hold the next bite off, never bring it sooner, however long or
## short the stall is. (A stall in a WINDUP cancels that bite: that is the blow
## taking the tell away, and a different thing.)

const F := preload("res://tests/fight/fixture.gd")
const STALLS: Array[int] = [200, 400, 600, 800, 1000, 1250, 1500, 2000]


## Sim ms from the spent window opening to the machine's next windup, with a part
## hit of `stall` ms landed as the window opens (-1: none landed). The hero cannot
## be struck, so every bite is one it evaded and every window is earned.
func _next_bite(kind: StringName, stall: int) -> float:
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	var m := sim.add_mob(kind, Vector2(51.0, 48.5))
	m.facing = PI
	m.aim = PI
	m.disturbed = true
	m.set_mood(MobState.ATTACKING, sim.now)
	var opened_at := -1.0
	for i in 1500:
		sim.slices(1)
		sim.hero.health = FightRules.HEALTH
		sim.hero.invuln_until = INF
		for e in sim.drain():
			if e.type == &"opened" and opened_at < 0.0:
				opened_at = sim.now
				if stall >= 0:
					var hp := m.health
					sim._hurt_mob(m, Blow.for_item(&"knife"), Vector2.INF, stall)
					m.health = hp
			elif e.type == &"windup" and opened_at >= 0.0 and e.mob == m:
				return sim.now - opened_at
	return -1.0


func test_a_stall_in_the_spent_window_never_brings_the_next_bite_sooner() -> void:
	for kind: StringName in [&"harvester", &"runner", &"cutter"]:
		var none := _next_bite(kind, -1)
		gt(none, 0.0, "%s bites again after its window (%.0f ms)" % [kind, none])
		for s in STALLS:
			var got := _next_bite(kind, s)
			check(got >= none, "%s: a %d ms stall brought its next bite in %.0f ms against %.0f unstalled" % [kind, s, got, none])
