extends TestCase
## THE PLOUGHSHARE (the plough's core on the jig, worn on the hands): a dodge
## taken ACROSS a charge -- within SHARE_ARC of square to its run while its bite
## is winding up or live -- turns it off your share. Its run carries on twice as
## far and it stands spent twice as long (recovery and cooldown doubled). It
## amplifies the shared overrun a charging crowd is beaten through, instead of
## breaking it (docs/GEAR.md §12). Its cost: each charge turned takes SHARE_WIND
## dodges' breath more, so turning a crowd winds you.

const F := preload("res://tests/fight/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_ploughs_core_becomes_the_share_on_the_jig() -> void:
	check(Gear.is_module(&"mod_ploughshare"), "the share is a module")
	eq(Items.def(&"mod_ploughshare").get("fits", []), [&"hands"], "worn on the hands")
	eq(GearTree.row(&"mod_ploughshare").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_ploughshare"), &"plough_core", "made of the plough's core")
	check(ModifierTable.costs(&"mod_ploughshare") != "", "it says what it costs")
	check(FightKit.of([&"mod_ploughshare"]).ploughshare, "the kit reads it")
	eq(UiRules.core_uses(&"plough_core").size(), 2, "the plough's core reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


## A harvester running in from the east with its bite winding up; the player
## dodges north, square across it, or east, straight back along it.
func _dodge(kit: Array[StringName], dir: Vector2) -> Dictionary:
	var sim := F.make_sim()
	sim.hero.kit = FightKit.of(kit)
	var m := F.still(sim, &"harvester", sim.hero.pos + Vector2(3.0, 0.0), PI)
	m.disturbed = true
	m.set_mood(MobState.ATTACKING, sim.now)
	m.charging = true
	m.bearing = Vector2.LEFT
	m.run_until = sim.now + 600.0
	Brains.bite(m, sim)
	var rec := m.blow.recovery
	var cool := m.blow.cooldown
	var run := m.run_until
	var wind := sim.hero.wind
	sim.hero.move = dir
	sim.press_dodge()
	sim.slices(1)
	return {"rec": float(m.blow.recovery) / rec, "cool": float(m.blow.cooldown) / cool,
		"run": m.run_until - run, "wind": wind - sim.hero.wind}


func test_a_dodge_across_a_charge_turns_it_off_the_share() -> void:
	var s: Array[StringName] = [&"mod_ploughshare"]
	var bare := _dodge([], Vector2.UP)
	var across := _dodge(s, Vector2.UP)
	var back := _dodge(s, Vector2.RIGHT)
	near(bare.rec, 1.0, 1e-4, "bare, a dodge changes nothing about its blow")
	near(across.rec, FightKit.SHARE_SPENT, 1e-4, "across it, it stands spent twice as long")
	near(across.cool, FightKit.SHARE_SPENT, 1e-4, "cooldown and all")
	gt(across.run, 1.0, "and its run carries on past")
	near(back.rec, 1.0, 1e-4, "a dodge straight back along its run does not turn it")
	near(across.wind - bare.wind, FightRules.DODGE_COST * FightKit.SHARE_WIND, 0.01, "turning it takes half a dodge's breath more")
	near(back.wind, bare.wind, 0.01, "and a dodge that turns nothing costs as ever")


## THE BOUT: the shoulder reader with the knife, 16 bouts a crowd, bare and with
## the share. Its bar, set before it was built: 3 harvesters beat bare on wins or
## health lost; a lone charger no worse; biters no worse.
func _gate(kind: StringName, n: int, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var lost := 0
	for i in 16:
		var r := G.gate(true, i % 8, kind, n, kit, 120.0, &"knife", 0, 1000 + i / 8, true)
		won += int(r.won)
		lost += int(r.lost)
	return {"won": won, "lost": float(lost) / 16.0}


func test_the_ploughshare_bout() -> void:
	var s: Array[StringName] = [&"mod_ploughshare"]
	for pair: Array in [[&"harvester", 3], [&"harvester", 1], [&"cutter", 2], [&"runner", 3]]:
		var b := _gate(pair[0], pair[1], [])
		var w := _gate(pair[0], pair[1], s)
		print("  info %d %s: bare won %d/16 losing %.2f; share won %d/16 losing %.2f" % [pair[1], pair[0], b.won, b.lost, w.won, w.lost])
		if pair[0] == &"harvester" and pair[1] == 3:
			check(w.won > b.won or w.lost < b.lost - 0.1, "three harvesters: better than bare")
		else:
			gt(float(w.won), float(b.won) - 1.5, "%d %s: no fewer won" % [pair[1], pair[0]])
			lt(w.lost, b.lost + 0.35, "%d %s: no more lost" % [pair[1], pair[0]])
