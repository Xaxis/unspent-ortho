extends TestCase
## The fight is reachable from a normal game start: the systems load, a body
## put on the coast gets a Mob node that keeps the contract, and a blow thrown
## through the running game reaches it.


func test_a_running_game_has_mobs_that_keep_the_contract() -> void:
	var o := BootOptions.parse(PackedStringArray(["--seed=4", "--size=128", "--spawn=dog"]))
	var game := Game.new()
	tree.root.add_child(game)
	game.setup(o)
	await frames(3)
	var sim := game.player.sim
	check(sim != null, "30_mobs made the simulation")
	check(game.player.hero != null, "and gave the player its body")
	var mobs := tree.get_nodes_in_group(&"mobs")
	eq(mobs.size(), 1, "one Mob node for --spawn=dog")
	if mobs.size() == 1:
		var mob: Node = mobs[0]
		eq(mob.get(&"kind"), &"dog.yard")
		check(mob.get(&"pos") is Vector2, "pos in tile space")
		eq(mob.get(&"alive"), true)
		lt((mob.get(&"pos") as Vector2).distance_to(game.player.pos), 4.0, "placed in front of the player")
	var ended: Array[StringName] = []
	Events.fight_ended.connect(func(outcome: StringName) -> void: ended.append(outcome))
	var killed: Array[StringName] = []
	Events.killed.connect(func(kind: StringName, _at: Vector3) -> void: killed.append(kind))
	var dog := sim.mobs[0]
	dog.health = 1
	sim.hero.pos = dog.pos + Vector2(-(dog.radius + sim.hero.radius + 0.2), 0)
	sim.hero.facing = 0.0
	sim.press_swing()
	await frames(20)
	check(not dog.alive, "a blow thrown through the running game lands")
	eq(killed, [&"dog.yard"] as Array[StringName], "Events.killed")
	game.queue_free()
	await frames(1)
