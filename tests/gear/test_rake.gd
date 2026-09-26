extends TestCase
## THE RAKE (GEAR.md G4): the pan rake's core on the jig, set in the tool. As a
## heavy blow is drawn back it rakes the ground ahead: every body in an arc
## RAKE_REACH out and RAKE_ARC either side has its tell broken and stands
## stalled open. A charger rides over the tines. Its cost: a heavy blow rings
## half as loud again (FightKit.blow_noise).

const F := preload("res://tests/fight/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_rakes_core_becomes_the_rake_on_the_jig() -> void:
	check(Gear.is_module(&"mod_rake"), "the rake is a module")
	eq(Items.def(&"mod_rake").get("fits", []), [&"tool"], "set in the tool")
	eq(GearTree.row(&"mod_rake").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_rake"), &"rake_core", "made of the pan rake's core")
	check(ModifierTable.costs(&"mod_rake") != "", "it says what it costs")
	check(FightKit.of([&"mod_rake"]).rake, "the kit reads it")
	eq(UiRules.core_uses(&"rake_core").size(), 2, "the rake's core now reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


## A runner winding up two tiles off ahead, one behind, a harvester ahead: the
## heavy, drawn, breaks the tell of the one ahead and holds it open; the one
## behind is out of the arc; the harvester, a charger, rides over it.
func test_a_heavy_rakes_the_arc_ahead() -> void:
	for kit: Array[StringName] in [[] as Array[StringName], [&"mod_rake"] as Array[StringName]]:
		var sim := F.make_sim()
		sim.hero.inventory.add(&"knife")
		sim.hero.inventory.set_held(&"knife")
		sim.hero.kit = FightKit.of(kit)
		sim.hero.facing = 0.0
		var ahead := F.still(sim, &"runner", sim.hero.pos + Vector2(2.0, 1.0), PI)
		var behind := F.still(sim, &"runner", sim.hero.pos + Vector2(-2.0, 0.0), 0.0)
		var charger := F.still(sim, &"harvester", sim.hero.pos + Vector2(2.2, -1.4), PI)
		ahead.set_mood(MobState.ATTACKING, sim.now)
		Brains.bite(ahead, sim)
		sim.press_heavy()
		sim.slices(2)
		var raked: Array = []
		for e in sim.drain():
			if e.type == &"rake":
				raked = e.bodies
		if kit.is_empty():
			eq(raked.size(), 0, "bare, a heavy rakes nothing")
			check(not ahead.stunned(sim.now), "and the one ahead is not held")
			continue
		check(raked.has(ahead), "the one ahead is raked")
		check(ahead.blow_phase(sim.now) != &"windup", "its tell broken")
		check(ahead.stunned(sim.now), "and held open")
		check(not raked.has(behind), "the one behind is out of the arc")
		check(not raked.has(charger), "a charger rides over the tines")


func test_the_rake_makes_a_heavy_louder() -> void:
	var bare := FightKit.of([])
	var rake := FightKit.of([&"mod_rake"])
	near(bare.blow_noise(false, true), 1.0, 1e-6, "bare, a heavy is as loud as a blow")
	near(rake.blow_noise(false, true), FightKit.RAKE_NOISE, 1e-6, "raked, half as loud again")
	near(rake.blow_noise(false, false), 1.0, 1e-6, "a light blow is not")


## THE BOUT: roused crowds at a gate, the crowd reader with the knife, 24 bouts
## (tests/fight/test_crowd_reader `gate`), bare and with the rake (the reader
## rakes two or more biters pressing ahead). Its identity, held both ways:
## against the biters (two cutters) it wins more of the fight; against the
## chargers (three harvesters) it changes nothing.
func _gate(kind: StringName, n: int, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var t := 0.0
	for i in 24:
		var r := G.gate(true, i % 8, kind, n, kit, 120.0, &"knife", 0, 1000 + i / 8)
		won += int(r.won)
		if r.won:
			t += float(r.t)
	return {"won": won, "t": t / maxf(won, 1)}


func test_the_rake_at_a_gate() -> void:
	var rk: Array[StringName] = [&"mod_rake"]
	var cb := _gate(&"cutter", 2, [])
	var cr := _gate(&"cutter", 2, rk)
	var hb := _gate(&"harvester", 3, [])
	var hr := _gate(&"harvester", 3, rk)
	print("  info 2 cutters: bare won %d/24 in %.1f s, rake %d/24 in %.1f s; 3 harvesters: bare %d/24 in %.1f s, rake %d/24 in %.1f s"
		% [cb.won, cb.t, cr.won, cr.t, hb.won, hb.t, hr.won, hr.t])
	gt(float(cr.won), float(cb.won) + 2.5, "against the biters the rake wins three more bouts in 24 or better")
	eq(hr.won, hb.won, "against the chargers it wins as often")
	near(float(hr.t), float(hb.t), float(hb.t) * 0.1, "and no faster or slower")
