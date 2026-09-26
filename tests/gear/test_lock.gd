extends TestCase
## THE LOCK (GEAR.md G4): the drowned lockkeeper's core on the jig, worn on the
## back. A narrow way the player passes through -- a gap between two solid
## things no wider than LOCK_GAP, a gate, a door in a wall -- is shut behind them
## to machines for LOCK_SECONDS. Its cost: a charge a lock.

const F := preload("res://tests/fight/fixture.gd")

const GAP_AT := Vector2(40.0, 40.0)


## A line of boulders north and south across the way east, with one gap 1.8
## tiles wide in it, and the player west of it.
func _sim(kit: Array[StringName], charges: int = 3) -> FightSim:
	var w := F.flat_world(96)
	for side: float in [-1.0, 1.0]:
		for k in 16:
			var rock := WorldProp.new(w.next_id(), PropKind.BOULDER, GAP_AT + Vector2(0.0, side * (1.6 + k * 1.3)), 0.0, 1.0)
			rock.solid = 0.7
			w.add_prop(rock)
	var sim := F.make_sim(w, GAP_AT + Vector2(-3.0, 0.0))
	sim.hero.kit = FightKit.of(kit)
	sim.hero.inventory.add(FightRules.CHARGE, charges)
	return sim


func test_the_lockkeepers_core_becomes_the_lock_on_the_jig() -> void:
	check(Gear.is_module(&"mod_lock"), "the lock is a module")
	eq(Items.def(&"mod_lock").get("fits", []), [&"back"], "worn on the back")
	eq(GearTree.row(&"mod_lock").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_lock"), &"lockkeeper_core", "made of the lockkeeper's core")
	check(ModifierTable.costs(&"mod_lock") != "", "it says what it costs")
	check(FightKit.of([&"mod_lock"]).lock, "the kit reads it")
	eq(UiRules.core_uses(&"lockkeeper_core").size(), 2, "the lockkeeper's core reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


## Walked east through the gap: with the lock a charge is spent and a runner
## chasing after cannot come through it; bare, it can. An open field locks
## nothing.
func test_a_gap_passed_is_shut_behind_you() -> void:
	for kit: Array[StringName] in [[] as Array[StringName], [&"mod_lock"] as Array[StringName]]:
		var sim := _sim(kit)
		var m := sim.add_mob(&"runner", GAP_AT + Vector2(-6.0, 0.0))
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		sim.hero.move = Vector2.RIGHT
		F.ms(sim, 1400)
		sim.hero.move = Vector2.ZERO
		var through := false
		var t := 0.0
		while t < 4000.0:
			F.ms(sim, 32)
			t += 32.0
			through = through or m.pos.x > GAP_AT.x + 0.5 and absf(m.pos.y - GAP_AT.y) < 1.0
		var charges := sim.hero.inventory.count(FightRules.CHARGE)
		if kit.is_empty():
			check(through, "bare, the runner comes through the gap after the player")
			eq(charges, 3, "and nothing is spent")
		else:
			check(not through, "locked, it cannot come through the gap")
			eq(charges, 2, "for one charge")
	var open := _sim([&"mod_lock"] as Array[StringName])
	open.hero.pos = GAP_AT + Vector2(-3.0, 30.0)
	var chaser := open.add_mob(&"runner", open.hero.pos + Vector2(-8.0, 0.0))
	chaser.disturbed = true
	chaser.set_mood(MobState.CHASING, open.now)
	open.hero.move = Vector2.RIGHT
	F.ms(open, 1400)
	eq(open.hero.inventory.count(FightRules.CHARGE), 3, "an open field locks nothing")


func _hunt(sim: FightSim) -> void:
	var m := sim.add_mob(&"runner", GAP_AT + Vector2(-12.0, 0.0))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)


func test_the_lock_lets_go_after_its_seconds_and_wants_a_charge() -> void:
	var calm := _sim([&"mod_lock"] as Array[StringName])
	calm.hero.move = Vector2.RIGHT
	F.ms(calm, 1400)
	eq(calm.lock_walls.size(), 0, "not hunted, a way passed is only a way")
	eq(calm.hero.inventory.count(FightRules.CHARGE), 3, "and nothing is spent on it")
	var sim := _sim([&"mod_lock"] as Array[StringName], 0)
	_hunt(sim)
	sim.hero.move = Vector2.RIGHT
	F.ms(sim, 1400)
	eq(sim.lock_walls.size(), 0, "with no charge, nothing is locked")
	var s2 := _sim([&"mod_lock"] as Array[StringName])
	_hunt(s2)
	s2.hero.move = Vector2.RIGHT
	F.ms(s2, 1400)
	eq(s2.lock_walls.size(), 1, "the gap is locked")
	F.ms(s2, FightKit.LOCK_SECONDS * 1000.0 + 200.0)
	eq(s2.lock_walls.size(), 0, "and it lets go after LOCK_SECONDS")


## THE BOUT: hunted, a runner six tiles behind, the player walks east through
## the gap in a line of boulders and keeps walking. Bare, it follows through the
## gap; locked, it must go the long way round the line, and falls far behind.
func _chase(kit: Array[StringName]) -> Dictionary:
	var sim := _sim(kit)
	var m := sim.add_mob(&"runner", sim.hero.pos + Vector2(-6.0, 0.0))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	var lost := 0
	var t := 0.0
	while t < 12000.0:
		sim.hero.move = Vector2.RIGHT
		sim.hero.run = false
		F.ms(sim, 32)
		t += 32.0
		for e in sim.drain():
			if e.type == &"hurt":
				lost += int(e.damage)
	return {"lost": lost, "apart": m.pos.distance_to(sim.hero.pos)}


func test_the_lock_bout() -> void:
	var bare := _chase([])
	var locked := _chase([&"mod_lock"] as Array[StringName])
	print("  info hunted through a gap: bare lost %d, %.1f tiles apart after 12 s; locked lost %d, %.1f apart"
		% [bare.lost, bare.apart, locked.lost, locked.apart])
	eq(locked.lost, 0, "locked, it never reaches the player")
	gt(float(locked.apart), float(bare.apart) + 10.0, "and it is ten tiles further behind than through an open gap")
