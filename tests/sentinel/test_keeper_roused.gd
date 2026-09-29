extends TestCase
## A STRUCK KEEPER TURNS ON YOU. In a running game (44_sentinels puts each
## keeper out at its lair when the player comes near), a player who walks up to
## a keeper on its own level and strikes it -- through the fight's own door, as a
## swing that lands does, on plate or on its part -- is turned on and hunted:
## within TURN_SECONDS it is chasing or fighting, still roused, and faces them.
## Seen in a tour: the snowfield's plough stood at its lair and never noticed a
## player beside it.

const Sx := preload("res://tests/save/save_fixture.gd")
const TURN_SECONDS := 3.0


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _put(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)
	g.player.sync_view(0.0)


func test_a_struck_keeper_turns_on_you() -> void:
	Sx.use_root("keeper-roused")
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	var sys := Sx.system(g, "44_sentinels")
	var sim: FightSim = g.player.sim
	var q := g.query
	var tried := 0
	for s: SentinelState in sys.call(&"states"):
		if s.fallen or s.region < 0:
			continue
		var lair: Vector2 = s.lair
		var level := g.world.level_at(floori(lair.x), floori(lair.y))
		# Beside it, on its level, within a swing.
		var at := Vector2.INF
		for k in 16:
			var p := lair + Vector2.from_angle(TAU * k / 16.0) * 2.4
			if q.standable(floori(p.x), floori(p.y)) and g.world.level_at(floori(p.x), floori(p.y)) == level:
				at = p
				break
		if not at.is_finite():
			continue
		_put(g, at)
		await _frames(30)
		var m: MobState = s.body
		# One body, put out once: a lair stood on a tile outside its region was
		# adopted as a stranger and a fresh keeper put out every frame after.
		var kind := Sentinels.for_land(s.land).kind
		var bodies := sim.mobs.filter(func(x: MobState) -> bool: return not x.removed and x.kind == kind and x.pos.distance_to(lair) < 20.0).size()
		check(bodies == 1, "%s: one keeper at its lair, not %d" % [s.land, bodies])
		check(m != null and m.alive, "%s: its keeper is out at its lair" % s.land)
		if m == null:
			continue
		tried += 1
		var b := Blow.for_item(&"knife")
		sim.strike(m, b, g.player.hero.pos)
		var until := Time.get_ticks_msec() + int(TURN_SECONDS * 1000.0 * TestCase.machine_slack())
		var t0 := sim.now
		# Its bite can down a player held beside it, who then comes to at the edge
		# of its ground (Sentinels.arena_edge): turned on, past doubt. The window
		# ends there, and the facing is read where they fell, not twenty tiles off.
		var downed := [false]
		var on_end := func(o: StringName) -> void: downed[0] = downed[0] or o == &"downed" or o == &"carried"
		Events.fight_ended.connect(on_end)
		var to := 0.0
		while sim.now - t0 < TURN_SECONDS * 1000.0 and Time.get_ticks_msec() < until and not downed[0]:
			to = (at - m.pos).angle()
			_put(g, at)
			await _frames(1)
		Events.fight_ended.disconnect(on_end)
		if not downed[0]:
			to = (g.player.hero.pos - m.pos).angle()
		var facing_off := absf(wrapf(to - m.facing, -PI, PI))
		check(downed[0] or m.mood == MobState.CHASING or m.mood == MobState.ATTACKING,
			"%s: struck, it hunts (%s after %.1f s)" % [s.land, m.mood, (sim.now - t0) / 1000.0])
		check(m.disturbed, "%s: and is roused, not at its work" % s.land)
		lt(facing_off, 0.8, "%s: and faces the player (%.2f rad off%s)" % [s.land, facing_off, ", downed by it" if downed[0] else ""])
		# Leave it be before the next: the player goes back to the spawn.
		_put(g, g.world.spawn)
		await _frames(30)
	gt(float(tried), 3.0, "keepers were struck (%d)" % tried)
	Sx.end(g)
