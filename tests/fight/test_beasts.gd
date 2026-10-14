extends TestCase
## A BEAST LEAVES YOU BE UNTIL YOU STRIKE IT (owner, 2026-10-13: "why do dogs
## just randomly start attacking me? They would need to be attacked for them to
## even think about attacking you"). A dog or a field bull beside the player goes
## about its business however long he stands there; struck, it turns on him.

const F := preload("res://tests/fight/fixture.gd")
const BEASTS: Array[StringName] = [&"dog.yard", &"dog.feral", &"bull.field"]


func _hurt(sim: FightSim, start: int) -> bool:
	return sim.hero.health < start


func test_a_beast_beside_you_does_not_attack() -> void:
	for kind in BEASTS:
		var sim := F.make_sim()
		var b := sim.add_mob(kind, sim.hero.pos + Vector2(2.0, 0.0))
		var start := sim.hero.health
		F.ms(sim, 12000)
		check(not _hurt(sim, start), "%s beside him for twelve seconds: not a bite (health %d of %d)" % [kind, sim.hero.health, start])
		check(not b.roused(), "%s is not hunting him" % kind)


func test_struck_it_turns_on_you() -> void:
	for kind in BEASTS:
		var sim := F.make_sim()
		# Held where it stands, in reach in front of him, so the blow is the test.
		var b := F.still(sim, kind, sim.hero.pos + Vector2(b_reach(sim, kind), 0.0), PI)
		sim.hero.facing = 0.0
		sim.press_swing()
		F.ms(sim, 600)
		check(b.health < b.max_health, "%s: the blow landed (%d of %d, %.2f off)" % [kind, b.health, b.max_health, b.pos.distance_to(sim.hero.pos)])
		check(b.roused() or b.disturbed, "%s struck: it turns on him" % kind)


static func b_reach(sim: FightSim, kind: StringName) -> float:
	return float(Roster.row(kind).get("radius", 0.4)) + sim.hero.radius + 0.3
