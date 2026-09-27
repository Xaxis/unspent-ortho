extends TestCase
## THE CABLE BRACE'S LINE (GEAR.md §6, G8): the grapple brace raised on the
## Ruined Metropolis's tower cable (and the ram brace over it). Its hook is the
## grapple's anchor (AbilityGrapple.anchor) and FightSim.cable: a machine ahead
## whose working part faces the line is a hold; the line stalls the part and
## pulls the player in to the edge of its body. A pull, not a haul: the machine
## stays where it is. A machine turned so its part is away from the line is no
## hold. The undertow, fitted too, hauls instead.

const F := preload("res://tests/fight/fixture.gd")
const G := preload("res://tests/fight/test_crowd_reader.gd")


func test_the_cable_braces_read_as_the_line() -> void:
	check(FightKit.of([&"brace_cable"]).cable, "the cable brace")
	check(FightKit.of([&"brace_ram"]).cable, "and the ram brace raised on it")
	check(not FightKit.of([&"boots_magnet"]).cable, "not the plain magnet boots")


func test_the_line_takes_a_part_that_faces_it() -> void:
	for kit: Array[StringName] in [[&"boots_magnet"] as Array[StringName], [&"brace_cable"] as Array[StringName], [&"brace_cable", &"mod_undertow"] as Array[StringName]]:
		var sim := F.make_sim()
		sim.hero.kit = FightKit.of(kit)
		sim.hero.facing = 0.0
		var ahead := sim.hero.pos + Vector2(5.0, 0.0)
		# A cutter's part is its back: turned away, the back faces the line.
		var m := F.still(sim, &"cutter", ahead, 0.0)
		var a := AbilityGrapple.anchor(sim.world, sim.query, sim.hero.pos, Vector2.RIGHT, sim)
		var what: StringName = a.get("what", &"")
		if kit.has(&"boots_magnet"):
			check(what != &"part" and what != &"machine", "plain boots take no machine")
			continue
		if kit.has(&"mod_undertow"):
			eq(what, &"machine", "with the undertow too, it hauls")
			continue
		eq(what, &"part", "the cable takes a part that faces the line")
		m.facing = PI
		a = AbilityGrapple.anchor(sim.world, sim.query, sim.hero.pos, Vector2.RIGHT, sim)
		check(a.get("what", &"") != &"part", "and not one turned away from it")


func test_the_line_stalls_the_part_it_takes() -> void:
	var sim := F.make_sim()
	sim.hero.kit = FightKit.of([&"brace_cable"])
	var m := F.still(sim, &"cutter", sim.hero.pos + Vector2(4.0, 0.0), 0.0)
	var was := m.pos
	m.set_mood(MobState.ATTACKING, sim.now)
	Brains.bite(m, sim)
	eq(m.blow_phase(sim.now), &"windup", "it was winding up")
	check(sim.cable(m), "the line takes it")
	check(m.stunned(sim.now), "and its part stalls")
	check(m.blow_phase(sim.now) != &"windup", "its tell broken")
	near(m.pos.distance_to(was), 0.0, 1e-4, "a pull, not a haul: it stays where it stood")
	m.facing = PI
	check(not sim.cable(m), "turned away, the line does not take it")


## THE BOUT: the crowd reader with the knife, 24 bouts a row, the grapple brace
## bare and the cable brace (it throws the line at a machine standing off whose
## part faces it, when the grapple is ready and there is breath, alone with it).
func _gate(kind: StringName, n: int, kit: Array[StringName]) -> Dictionary:
	var won := 0
	var lost := 0
	var t := 0.0
	var cables := 0
	for i in 24:
		var r := G.gate(true, i % 8, kind, n, kit, 120.0, &"knife", 0, 1000 + i / 8)
		won += int(r.won)
		lost += int(r.lost)
		cables += int(r.get("cabled", 0))
		if r.won:
			t += float(r.t)
	return {"won": won, "lost": float(lost) / 24.0, "t": t / maxf(won, 1), "cables": cables}


func test_the_cable_bout() -> void:
	var bare: Array[StringName] = [&"boots_magnet"]
	var cable: Array[StringName] = [&"brace_cable"]
	var paid := false
	for pair: Array in [[&"harvester", 1], [&"hauler", 1], [&"harvester", 3], [&"cutter", 2]]:
		var b := _gate(pair[0], pair[1], bare)
		var w := _gate(pair[0], pair[1], cable)
		print("  info %d %s: bare won %d/24 in %.1f s losing %.2f; cable won %d/24 in %.1f s losing %.2f, %d lines"
			% [pair[1], pair[0], b.won, b.t, b.lost, w.won, w.t, w.lost, w.cables])
		gt(float(w.won), float(b.won) - 2.5, "the line costs no bouts (%s)" % pair[0])
		paid = paid or (w.cables > 0 and (w.t < b.t * 0.85 or w.lost < b.lost * 0.8))
	check(paid, "and closes on a machine standing off sooner, or for less")
