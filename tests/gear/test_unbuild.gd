extends TestCase
## THE UNBUILDER'S HANDS (GEAR.md G4): the ruined metropolis unbuilder's core on
## the jig, worn on the hands. Held `use` at a machine's working part while it
## stands open (stalled or spent) strips it: UNBUILD_MS of holding, gathered
## only while it is open and in reach, and it is disarmed -- no bite, ever
## again -- and gives up its elite part. Its cost: the strip is a held use of
## that long, inside openings a swing would spend on damage.

const F := preload("res://tests/fight/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_unbuilders_core_becomes_its_hands_on_the_jig() -> void:
	check(Gear.is_module(&"mod_unbuild"), "the hands are a module")
	eq(Items.def(&"mod_unbuild").get("fits", []), [&"hands"], "worn on the hands")
	eq(GearTree.row(&"mod_unbuild").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_unbuild"), &"unbuilder_core", "made of the unbuilder's core")
	check(ModifierTable.costs(&"mod_unbuild") != "", "it says what it costs")
	check(FightKit.of([&"mod_unbuild"]).unbuild, "the kit reads it")
	eq(UiRules.core_uses(&"unbuilder_core").size(), 2, "the unbuilder's core reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


## A cutter stalled with the player at its back: the strip gathers only while it
## is open, and done, it is disarmed and its part is given up. Bare, nothing.
func test_a_stalled_machine_is_stripped() -> void:
	for kit: Array[StringName] in [[] as Array[StringName], [&"mod_unbuild"] as Array[StringName]]:
		var sim := F.make_sim()
		sim.hero.kit = FightKit.of(kit)
		var m := F.still(sim, &"cutter", sim.hero.pos + Vector2(1.2, 0.0), 0.0)
		m.stun_until = sim.now + 5000.0
		var got: Array = []
		for i in 250:
			sim.strip(m, FightRules.SLICE_MS)
			sim.slices(1)
			for e in sim.drain():
				if e.type == &"stripped":
					got.append(e.item)
		if kit.is_empty():
			check(m.bite != null, "bare, nothing is stripped")
			continue
		check(m.bite == null, "stripped, it has no bite")
		eq(got.size(), 1, "and gives up one part")
		if got.size() == 1:
			check(EliteStock.from_kind(&"cutter").has(StringName(got[0])), "its own elite part (%s)" % [got])
	var sim2 := F.make_sim()
	sim2.hero.kit = FightKit.of([&"mod_unbuild"])
	var shut := F.still(sim2, &"cutter", sim2.hero.pos + Vector2(1.2, 0.0), 0.0)
	for i in 200:
		sim2.strip(shut, FightRules.SLICE_MS)
	check(shut.bite != null, "a machine that is not open cannot be stripped")


## THE BOUT: the crowd reader with the knife, 24 bouts, bare and with the hands
## (it strips an open body rather than striking it when that body is the only
## one roused near it; in a crowd it fights). Its identity: a machine met alone
## ends disarmed with its part in the creel, and a crowd is no easier for it.
func _gate(kind: StringName, n: int, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var lost := 0
	var parts := 0
	var t := 0.0
	for i in 24:
		var r := G.gate(true, i % 8, kind, n, kit, 120.0, &"knife", 0, 1000 + i / 8)
		won += int(r.won)
		lost += int(r.lost)
		parts += int(r.get("stripped", 0))
		if r.won:
			t += float(r.t)
	return {"won": won, "lost": float(lost) / 24.0, "parts": parts, "t": t / maxf(won, 1)}


func test_the_unbuild_bout() -> void:
	var u: Array[StringName] = [&"mod_unbuild"]
	for pair: Array in [[&"cutter", 1], [&"harvester", 1], [&"cutter", 2]]:
		var b := _gate(pair[0], pair[1], [])
		var w := _gate(pair[0], pair[1], u)
		print("  info %d %s: bare won %d/24 in %.1f s losing %.1f; stripping %d/24 in %.1f s losing %.1f, %d parts"
			% [pair[1], pair[0], b.won, b.t, b.lost, w.won, w.t, w.lost, w.parts])
		if pair[1] == 1:
			gt(float(w.parts), 20.0, "a %s met alone gives up its part" % pair[0])
			eq(w.won, b.won, "and is beaten as often")
		else:
			gt(float(w.won), float(b.won) - 2.5, "a crowd is no harder for the hands")
