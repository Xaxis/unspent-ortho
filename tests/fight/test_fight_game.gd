extends TestCase
## The fight is reachable from a normal game start: the systems load, a body
## put on the coast gets a Mob node that keeps the contract, and a blow thrown
## through the running game reaches it.

const ErrorLog := preload("res://tests/fight/error_log.gd")


func test_a_running_game_has_mobs_that_keep_the_contract() -> void:
	var errors := ErrorLog.new()
	OS.add_logger(errors)
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
	# And a bad end reaches the world: the clock, the body, the coast, the lines.
	var lines: Array[String] = []
	Events.message.connect(func(t: String) -> void: lines.append(t))
	var mobs_system: Node = game.get_node("30_mobs")
	var biter: MobState = mobs_system.call(&"place_near_player", &"dog.feral")
	biter.pos = sim.hero.pos + Vector2(0.8, 0.0)
	biter.calm_until = 0.0
	biter.set_mood(MobState.ATTACKING, sim.now)
	game.body.health = 1
	var before := game.clock.minutes
	for i in 120:
		await frames(1)
		if ended.has(&"downed"):
			break
	check(ended.has(&"downed"), "downed through the running game: %s" % [ended])
	gt(game.clock.minutes - before, FightRules.DOWNED_MINUTES, "the clock lost the hours")
	eq(game.body.health, FightRules.DOWNED_WAKE_HEALTH, "woke hurt")
	gt(game.body.busy_until, Time.get_ticks_msec() / 1000.0, "and lies a moment before walking")
	eq(sim.living(), 0, "the coast was cleared")
	check(lines.has(Outcomes.DOWNED_LINE), "and was told so, plainly")
	# A warden's arrest leaves the player at the side of the track, camera and all.
	var w := game.world
	var hp := sim.hero.pos
	for dy in range(-6, 7):
		for dx in range(-1, 2):
			var tx := floori(hp.x) + dx
			var ty := floori(hp.y) + dy
			if w.in_bounds(tx, ty) and w.ground_at(tx, ty) != Ground.DEEP_WATER:
				w.ground[ty * w.size + tx] = Ground.ROAD
	var warden: MobState = mobs_system.call(&"place_near_player", &"warden")
	sim.snatch(warden)
	await frames(3)
	var at := sim.hero.pos
	check(w.ground_at(floori(at.x), floori(at.y)) != Ground.ROAD, "arrested and stood off the track")
	lt(at.distance_to(hp), 4.0, "beside where it met you")
	lt(Vector2(game.camera.target.x, game.camera.target.z).distance_to(at), 1.0, "and the camera went with you")
	game.queue_free()
	await frames(1)
	OS.remove_logger(errors)
	eq(errors.errors(), PackedStringArray(), "the run logged no engine errors")
