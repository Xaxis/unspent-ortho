extends TestCase
## A MACHINE BEATEN IS A BODY TO STRIP (docs/SALVAGE.md E3, 48_carcasses). A kill
## put its plate and its parts straight into the pack, so the fight paid out the
## moment it ended and nothing about taking a machine apart had a cost. Now it
## stays on the body where it fell, and the hands take it off a piece at a time,
## loud, minutes each.

const Carcasses := preload("res://src/systems/48_carcasses.gd")


func _game() -> Game:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0"]))
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func _carcasses(g: Game) -> Node:
	return g.get_node("48_carcasses")


func test_a_beaten_machine_keeps_its_plate_until_it_is_stripped() -> void:
	var g := _game()
	await frames(4)
	var sim := g.player.sim
	var at := g.player.pos
	g.player.facing = 0.0
	g.player.hero.facing = 0.0
	var m := sim.add_mob(&"harvester", at + Vector2(m_gap(), 0.0))
	await frames(2)
	var had := g.inventory.count(&"scrap")
	sim._kill(m, true)
	await frames(3)
	eq(g.inventory.count(&"scrap"), had, "nothing is in the pack when it goes down")
	check(not m.spoils.is_empty(), "its plate is still on it")
	eq(StringName(str(m.spoils[0].get("item", &""))), &"scrap", "plate first")
	var plate := int(m.spoils[0].get("count", 0))
	gt(float(plate), 0.0, "a harvester carries plate (%d)" % plate)
	var sys := _carcasses(g)
	await frames(2)
	check(sys.get("reachable") == m, "the body is what the key would strip")
	check(String(sys.call(&"use_line")).begins_with("harvester - strip"), "and the prompt says so: %s" % sys.call(&"use_line"))
	# A piece: started, carried through its seconds, and in the pack.
	var pieces := m.spoils.size()
	var was := g.clock.minutes
	sys.call(&"_start", m)
	sys.call(&"_carry_on", Carcasses.STRIP_SECONDS + 0.05, false)
	eq(g.inventory.count(&"scrap"), had + plate, "the plate is in the pack once stripped")
	eq(m.spoils.size(), pieces - 1, "and off the body")
	gt(g.clock.minutes - was, 5.0, "it took minutes of the clock")
	gt(sim.noise_radius, 10.0, "and it was heard (%.1f tiles)" % sim.noise_radius)
	# The rest, and the frame comes apart where it lay.
	while not m.spoils.is_empty():
		sys.call(&"_start", m)
		sys.call(&"_carry_on", Carcasses.STRIP_SECONDS + 0.05, false)
	check(not m.removed, "a stripped frame lies a moment more")
	sim.now += 2000.0
	sim._retire()
	check(m.removed, "then it comes apart")
	g.queue_free()
	await frames(1)


## A BODY NOBODY STRIPS LIES THERE A WHILE, NOT ITS OLD HALF-MINUTE: long enough to
## fight off what the noise brought and come back to it.
func test_a_body_with_something_on_it_lies_where_it_fell() -> void:
	var g := _game()
	await frames(4)
	var sim := g.player.sim
	var m := sim.add_mob(&"harvester", g.player.pos + Vector2(m_gap(), 0.0))
	await frames(2)
	sim._kill(m, true)
	await frames(3)
	check(not m.spoils.is_empty(), "it has something on it")
	sim.now = m.dead_at + float(m.stat("linger", 30.0)) * 1000.0 + 5000.0
	sim._retire()
	check(not m.removed, "it is still there past its linger")
	sim.now = m.dead_at + FightSim.CARCASS_MS + 1.0
	sim._retire()
	check(m.removed, "and gone after CARCASS_MS")
	g.queue_free()
	await frames(1)


## Clear of the player by a little more than a harvester's radius.
func m_gap() -> float:
	return 1.4

