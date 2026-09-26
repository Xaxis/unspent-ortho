extends TestCase
## THE TWO MODULES THAT DID NOTHING (GEAR.md G3).
##   lattice (mod_lattice)  "every blow shocks": a blow that lands in a working
##                          part also shocks every other body within
##                          FightKit.LATTICE_REACH of it for LATTICE_DAMAGE
##   icelens (mod_icelens)  "sight": the scan reads further (ICELENS_REACH x)

const F := preload("res://tests/fight/fixture.gd")


## A harvester facing west with the hero at its working part, and two runners
## standing close beside it, their backs to the hero.
func _crowd(kit: Array[StringName], charges: int = 20) -> Array:
	var sim := F.make_sim()
	var m := F.still(sim, &"harvester", Vector2(30.5, 20.5), PI)
	var a := F.still(sim, &"runner", m.pos + Vector2(0.0, 1.0), PI)
	var b := F.still(sim, &"runner", m.pos + Vector2(0.0, -3.5), PI)
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.kit = FightKit.of(kit)
	sim.hero.inventory.add(FightRules.CHARGE, charges)
	sim.hero.pos = m.pos - Vector2(m.radius + sim.hero.radius + 0.3, 0.0)
	sim.hero.facing = 0.0
	return [sim, m, a, b]


func test_a_lattice_blow_shocks_the_bodies_beside_it() -> void:
	for kit: Array[StringName] in [[] as Array[StringName], [&"mod_lattice"] as Array[StringName]]:
		var r := _crowd(kit)
		var sim: FightSim = r[0]
		var m: MobState = r[1]
		var a: MobState = r[2]
		var b: MobState = r[3]
		var hp := [m.health, a.health, b.health]
		sim.press_swing()
		F.ms(sim, 400)
		lt(float(m.health), float(hp[0]), "%s: the blow lands in the part" % [kit])
		if kit.is_empty():
			eq(a.health, hp[1], "bare: the runner beside it is untouched")
		else:
			eq(a.health, hp[1] - FightKit.LATTICE_DAMAGE, "lattice: the runner beside it is shocked")
			eq(b.health, hp[2], "and one three tiles off is not")


func test_an_icelens_scan_reads_further() -> void:
	near(AbilityScan.reach_of(FightKit.of([])), AbilityScan.REACH, 1e-6, "bare")
	near(AbilityScan.reach_of(FightKit.of([&"mod_icelens"])), AbilityScan.REACH * FightKit.ICELENS_REACH, 1e-6, "an icelens reads further")
	gt(FightKit.ICELENS_REACH, 1.2, "by a real stretch")


## THE BOUT NUMBER: ten seconds of a careful reader swinging at a harvester's
## part with a runner pressed beside it. What the lattice takes off the runner
## is the whole of its worth, and the heat it wants a cool for is its cost.
func test_the_lattice_bout() -> void:
	var out := {}
	for kit: Array[StringName] in [[] as Array[StringName], [&"mod_lattice"] as Array[StringName]]:
		var r := _crowd(kit)
		var sim: FightSim = r[0]
		var a: MobState = r[2]
		var hp := a.health
		var t := 0.0
		while t < 10000.0:
			if sim.hero.swing_refusal(sim.now) == &"":
				sim.press_swing()
			F.ms(sim, 100)
			sim.drain()
			t += 100.0
		out[kit.size()] = hp - a.health
	print("  info lattice bout: the runner beside the harvester loses %d health in 10 s bare, %d with a lattice" % [out[0], out[1]])
	gt(float(out[1]), float(out[0]), "a lattice wears the bystander down")



## Each discharge spends one charge (FightRules.CHARGE), as a charged weapon's
## swing does: dry, the blow lands and nothing jumps.
func test_a_lattice_discharge_spends_a_charge() -> void:
	var r := _crowd([&"mod_lattice"] as Array[StringName], 1)
	var sim: FightSim = r[0]
	var a: MobState = r[2]
	var hp := a.health
	sim.press_swing()
	F.ms(sim, 400)
	eq(a.health, hp - FightKit.LATTICE_DAMAGE, "with a charge it jumps")
	eq(sim.hero.inventory.count(FightRules.CHARGE), 0, "and the charge is spent")
	F.ms(sim, 2500)
	sim.drain()
	hp = a.health
	sim.press_swing()
	F.ms(sim, 400)
	eq(a.health, hp, "dry, nothing jumps")
