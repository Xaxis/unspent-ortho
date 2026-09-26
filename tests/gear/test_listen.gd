extends TestCase
## THE LISTENER'S EAR (GEAR.md G4): the frost sea listener's core on the jig,
## worn on the head. A machine's tell is heard where it cannot be seen: behind
## the player, past a wall, out of the eye's cone, its ring on the ground drawn
## through whatever stands between. Its cost: the player is heard as far as they
## hear, every noise they make (their steps too) LISTEN_NOISE as loud.

const F := preload("res://tests/fight/fixture.gd")
const SR := preload("res://tests/fight/shoulder_reader.gd")
## What comes from behind in the bout: its tell is long, and far off.
const BEHIND := &"sorter"


func test_the_listeners_core_becomes_the_ear_on_the_jig() -> void:
	check(Gear.is_module(&"mod_listen"), "the ear is a module")
	eq(Items.def(&"mod_listen").get("fits", []), [&"head"], "worn on the head")
	eq(GearTree.row(&"mod_listen").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_listen"), &"listener_core", "made of the listener's core")
	check(ModifierTable.costs(&"mod_listen") != "", "it says what it costs")
	check(FightKit.of([&"mod_listen"]).listen, "the kit reads it")
	eq(UiRules.core_uses(&"listener_core").size(), 2, "the listener's core reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


func test_the_ear_is_heard_back() -> void:
	near(FightKit.of([]).noise_scale(), 1.0, 1e-6, "bare, a noise is as loud as it is")
	near(FightKit.of([&"mod_listen"]).noise_scale(), FightKit.LISTEN_NOISE, 1e-6, "with the ear, it carries as far as the ear hears")


## THE BOUT: taken from behind. A cutter roused in front, and behind them
## something whose blow is told from afar (BEHIND: a thrower, its lane five tiles
## long), the shoulder reader (tests/fight/shoulder_reader.gd:
## what a player over the shoulder knows) with the knife, 24 bouts, bare and with
## the ear.
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
	for pair: Array in [[&"cutter", 4.0], [BEHIND, -7.0]]:
		var m := sim.add_mob(pair[0], sim.hero.pos + ahead * float(pair[1]))
		m.facing = (sim.hero.pos - m.pos).angle()
		m.aim = m.facing
		m.disturbed = true
		m.set_mood(MobState.CHASING, sim.now)
		mobs.append(m)
	var player := SR.new(sim)
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


func test_the_ear_bout() -> void:
	var bare := _gate([])
	var ear := _gate([&"mod_listen"] as Array[StringName])
	print("  info taken from behind over the shoulder: bare won %d/24 losing %.1f a bout; with the ear %d/24 losing %.1f"
		% [bare.won, bare.lost, ear.won, ear.lost])
	check(ear.won > bare.won or float(ear.lost) < float(bare.lost) * 0.8,
		"hearing the tell behind wins more, or loses a fifth less or better")


## THE COST: a walk past idle hunters standing off the path with their backs to
## it, 11 to 15 tiles off (past a walk's hearing, inside the ear's), the
## player's steps as loud as the ear makes them (32_disposition scales
## Moment.loudness): more of them hear it and come.
func _walk(scale: float) -> int:
	MobState._next_id = 2000
	var sim := F.make_sim(F.flat_world(96), Vector2(20.5, 48.5))
	sim.moment.loudness = 1.0 * scale
	var mobs: Array[MobState] = []
	for k in 12:
		var side := 1.0 if k % 2 == 0 else -1.0
		var m := sim.add_mob(&"runner", Vector2(26.0 + k * 4.0, 48.5 + side * (11.0 + (k % 4) * 1.2)))
		m.facing = side * PI * 0.5
		m.aim = m.facing
		mobs.append(m)
	sim.hero.facing = 0.0
	sim.hero.move = Vector2.RIGHT
	F.ms(sim, 16000)
	var roused := 0
	for m in mobs:
		roused += int(m.mood != MobState.IDLE and m.mood != MobState.WORKING)
	return roused


func test_the_ear_costs_a_walk() -> void:
	var bare := _walk(1.0)
	var ear := _walk(FightKit.LISTEN_NOISE)
	print("  info a walk past twelve hunters: %d come bare, %d with the ear" % [bare, ear])
	gt(float(ear), float(bare), "more of them hear the ear's steps and come")
