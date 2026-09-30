extends RefCounted
## A keeper fought through the game's input on a real world (GameDriver and the
## plate player), shared by the played ways: tests/sentinel/test_ways.gd (the
## Tide Reaper) and tests/sentinel/test_anvil_ways.gd (the second keeper).

const Sx := preload("res://tests/save/save_fixture.gd")
const GD := preload("res://tests/fight/game_driver.gd")


## A spot `dist` off its lair on its own level, down a line its run can take,
## with the most (or least) of the ground `grounds` round it.
static func stand(g: Game, s: SentinelState, dist: float, grounds: Array, most: bool) -> Vector2:
	var best := Vector2.INF
	var score := -INF
	var level := g.world.level_at(floori(s.lair.x), floori(s.lair.y))
	for i in 32:
		var p := s.lair + Vector2.from_angle(TAU * i / 32.0) * dist
		var tx := floori(p.x)
		var ty := floori(p.y)
		if not g.query.standable(tx, ty) or not g.world.same_body(p, s.lair) \
				or (not most and not FightRules.levels_meet(g.world.level_at(tx, ty), level)) \
				or not NavField.line_walkable(g.world, s.lair, p, 0.45):
			continue
		var n := 0.0
		for dy in range(-5, 6):
			for dx in range(-5, 6):
				n += float(grounds.has(g.world.ground_at(tx + dx, ty + dy)))
		var sc := n if most else -n
		if sc > score and (not most or grounds.has(g.world.ground_at(tx, ty))):
			score = sc
			best = p
	return best


## Fought by `reader` through the game's input (GameDriver), placed at `at`
## facing its lair. Downed, it comes to at the edge of the keeper's ground and
## walks back. The target key is held throughout when `locked`. Returns the tally.
static func fight(tree: SceneTree, g: Game, s: SentinelState, at: Vector2, reader: Variant, seconds: float, locked := false) -> Dictionary:
	var sim: FightSim = g.player.sim
	g.player.place(at, (s.lair - at).angle())
	var d: Variant = GD.new(g, reader)
	d.locked = locked
	var downs := [0]
	var on_end := func(o: StringName) -> void:
		if o == &"downed" or o == &"carried":
			downs[0] += 1
	Events.fight_ended.connect(on_end)
	var t0 := sim.now
	# On the fight's own clock, never the wall's: the same steps on any box. A
	# frame cap stands in for a hang guard (the hitstop holds the clock a while).
	var frames_left := int(seconds * 60.0 * 3.0)
	while not s.fallen and sim.now - t0 < seconds * 1000.0 and frames_left > 0:
		frames_left -= 1
		d.step()
		await tree.physics_frame
	d.release()
	Events.fight_ended.disconnect(on_end)
	return {"fallen": s.fallen, "how": s.how, "tries": downs[0] + 1, "downs": downs[0], "s": (sim.now - t0) / 1000.0, "health": s.health}


## The coast held off: nothing spawns and nothing else is out.
static func calm(g: Game) -> void:
	(Sx.system(g, "30_mobs").get("coast") as Object).set("spawning", false)
	g.player.sim.clear_mobs()
