extends TestCase
## THE PLUMB (GEAR.md G4): the crags plumb's core on the jig, worn on the head.
## A scan reads where each machine will be when it next tells a blow (a mark on
## the ground, FightSim.next_tell_at), so a player braced for it answers the
## tell sooner. Its cost: the scan's cooldown doubles.

const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")


func test_the_plumbs_core_becomes_the_plumb_on_the_jig() -> void:
	check(Gear.is_module(&"mod_plumb"), "the plumb is a module")
	eq(Items.def(&"mod_plumb").get("fits", []), [&"head"], "worn on the head")
	eq(GearTree.row(&"mod_plumb").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_plumb"), &"plumb_core", "made of the plumb's core")
	check(ModifierTable.costs(&"mod_plumb") != "", "it says what it costs")
	check(FightKit.of([&"mod_plumb"]).plumb, "the kit reads it")
	eq(UiRules.core_uses(&"plumb_core").size(), 2, "the plumb's core reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


func test_the_scan_cools_twice_as_long() -> void:
	near(AbilityScan.cooldown_of(FightKit.of([])), AbilityScan.COOLDOWN, 1e-6, "bare, the scan's own cooldown")
	near(AbilityScan.cooldown_of(FightKit.of([&"mod_plumb"])), AbilityScan.COOLDOWN * FightKit.PLUMB_COOLDOWN, 1e-6, "with the plumb, twice")


## A runner coming for the player tells its bite at the edge of its reach, on
## the line between them; one at its work tells nothing, and is read where it is.
func test_where_a_machine_will_tell() -> void:
	var sim := F.make_sim()
	var m := sim.add_mob(&"runner", sim.hero.pos + Vector2(8.0, 0.0))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	var at := sim.next_tell_at(m)
	lt(absf(at.y - sim.hero.pos.y), 0.01, "on the line between them")
	near(at.distance_to(sim.hero.pos), Brains.strike_range(m, sim), 0.01, "at the edge of its reach")
	var idle := F.still(sim, &"runner", sim.hero.pos + Vector2(0.0, 8.0), 0.0)
	eq(sim.next_tell_at(idle), idle.pos, "at its work, it is read where it stands")


## THE BOUT: taken from behind, over the shoulder (the ear's bout): a cutter in
## front, a thrower behind, the shoulder reader with the knife and the scan it
## uses when it is ready (SR.scan), 24 bouts. With the plumb the reader answers
## a tell it was braced for sooner (SR.PLUMB_REACT_MS), but scans half as often.
func _bout(kit: Array[StringName], i: int) -> Dictionary:
	MobState._next_id = 1000 + i / 8
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.kit = FightKit.of(kit)
	var a := float(i % 8) / 8.0 * TAU
	var ahead := Vector2.from_angle(a)
	sim.hero.facing = a
	var mobs: Array[MobState] = []
	for pair: Array in [[&"cutter", 4.0], [&"sorter", -7.0]]:
		var m := sim.add_mob(pair[0], sim.hero.pos + ahead * float(pair[1]))
		m.facing = (sim.hero.pos - m.pos).angle()
		m.aim = m.facing
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		mobs.append(m)
	var player := SR.new(sim)
	player.scan = true
	var lost := 0
	var t := 0.0
	while t < 60000.0:
		player.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
			if e.type == &"outcome" and e.outcome in [&"downed", &"carried"]:
				return {"won": false, "lost": lost}
		if not mobs[0].alive and not mobs[1].alive:
			return {"won": true, "lost": lost}
	return {"won": false, "lost": lost}


func _gate(kit: Array[StringName]) -> Dictionary:
	var won := 0
	var lost := 0
	for i in 24:
		var r := _bout(kit, i)
		won += int(r.won)
		lost += int(r.lost)
	return {"won": won, "lost": float(lost) / 24.0}


func test_the_plumb_bout() -> void:
	var bare := _gate([])
	var plumb := _gate([&"mod_plumb"] as Array[StringName])
	print("  info taken from behind over the shoulder, scanning: bare won %d/24 losing %.1f a bout; with the plumb %d/24 losing %.1f"
		% [bare.won, bare.lost, plumb.won, plumb.lost])
	check(plumb.won > bare.won or float(plumb.lost) < float(bare.lost) * 0.8,
		"braced for the tell, the plumb wins more, or loses a fifth less or better")
