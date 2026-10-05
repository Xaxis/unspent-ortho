extends RefCounted
## A keeper fought through the game's input on a real world (GameDriver and the
## plate player), shared by the played ways: tests/sentinel/test_ways.gd (the
## Tide Reaper) and tests/sentinel/test_anvil_ways.gd (the second keeper).

const Sx := preload("res://tests/save/save_fixture.gd")
const GD := preload("res://tests/fight/game_driver.gd")


## A spot `dist` off its lair on its own level, down a line its run can take,
## with the most (or least) of the ground `grounds` round it. With `ends_on`, the
## line is on `grounds` for that many tiles short of the spot too: where a run
## at the player standing there stops to bite (Brains: its front a bite's reach
## off), so a lure draws the keeper onto the ground and not to its edge.
static func stand(g: Game, s: SentinelState, dist: float, grounds: Array, most: bool, ends_on := 0.0) -> Vector2:
	var best := Vector2.INF
	var score := -INF
	var level := g.world.level_at(floori(s.lair.x), floori(s.lair.y))
	for i in 32:
		var p := s.lair + Vector2.from_angle(TAU * i / 32.0) * dist
		var tx := floori(p.x)
		var ty := floori(p.y)
		if not g.query.standable(tx, ty) or not g.world.same_body(p, s.lair) \
				or (not most and not FightRules.levels_meet(g.world.level_at(tx, ty), level)) \
				or (ends_on <= 0.0 and not NavField.line_walkable(g.world, s.lair, p, 0.45)):
			continue
		if ends_on > 0.0:
			var stop := p + (s.lair - p).normalized() * ends_on
			if not grounds.has(g.world.ground_at(floori(stop.x), floori(stop.y))):
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


## Rob every work that feeds `s` with `use`, farthest first, as a player walking
## in along them would: off out of its ground whenever a theft has stirred it,
## back in behind its back, eating when the body says so. Returns the tally:
## works fed on and robbed, takes, sim seconds waited off its ground, what
## refused a take, and what it cost: sim seconds in all, clock minutes, and
## tiles walked from work to work (the run places him, so a player walks those
## on top of `s`).
static func rob_larder(tree: SceneTree, g: Game, s: SentinelState) -> Dictionary:
	var def := Sentinels.by_id(s.design)
	var reach := def.reach * Sentinels.FEED_SHARE
	var works: Array[WorldProp] = []
	for q: WorldProp in g.query.props_near(s.lair, reach):
		if def.feeds.has(q.kind) and q.pos.distance_to(s.lair) <= reach:
			works.append(q)
	works.sort_custom(func(a: WorldProp, b: WorldProp) -> bool: return a.pos.distance_to(s.lair) > b.pos.distance_to(s.lair))
	var refused := {}
	var said: Array[String] = []
	var hear := func(line: String) -> void: said.append(line)
	Events.message.connect(hear)
	var waited := 0.0
	var thefts := 0
	var walked := 0.0
	var sim0 := g.player.sim.now
	var clock0 := g.clock.minutes
	for k in works.size():
		var q := works[k]
		if k > 0:
			walked += works[k - 1].pos.distance_to(q.pos)
		var away := (q.pos - s.lair).normalized() if q.pos.distance_to(s.lair) > 0.1 else Vector2.RIGHT
		for take in 8:
			if g.world.depleted.has(q.id):
				break
			# A theft stirs it (34_works: a plan work opened tells its machines),
			# and a fight still on refuses a long take ("Not with that so close").
			# A player goes off out of its ground until it has settled, and back.
			var m: MobState = s.body
			if (m != null and (m.disturbed or m.roused() or m.mood == MobState.ALERTED)) or g.player.sim.fight_on or Survival.threat_near(g):
				g.player.place(s.lair + away * Sentinels.PUT_OUT * 2.0)
				var w0 := g.player.sim.now
				while (s.body != null or g.player.sim.fight_on) and g.player.sim.now - w0 < 60000.0:
					await tree.physics_frame
				waited += (g.player.sim.now - w0) / 1000.0
			# Back in on the far side of its lair from the work: it comes out
			# facing that way, and the work is taken behind its back.
			if s.body == null and q.pos.distance_to(s.lair) < 8.0:
				g.player.place(off_its_guard(g, s, -away))
				for f in 30:
					await tree.physics_frame
			if Condition.hours_to_full(g.body.fed_until, g.clock.minutes) >= 4.0 and Survival.best_food(g) != &"":
				@warning_ignore("return_value_discarded")
				Survival.eat(g, Survival.best_food(g))
			# Coming to after a down, the body is busy a moment (40_fight _wake).
			for f in 2000:
				if not Survival.busy(g):
					break
				await tree.physics_frame
			# Beside the work, and out of the keeper's eye where there is a side of
			# it that is: a player robbing its larder keeps behind its back.
			var spot := unseen_beside(g, q, s.body)
			g.player.place(spot, (q.pos - spot).angle())
			for f in 2:
				await tree.process_frame
			var used := Survival.use(g)
			if not used:
				var t := Survival.use_target(g)
				var line: String = said.back() if not said.is_empty() else ""
				refused[PropKind.NAMES[q.kind]] = "%s (aimed at %s, said %s)" % [q.pos.distance_to(s.lair), PropKind.NAMES[t.kind] if t != null else "nothing", line]
				if line == Survival.DARK_LINE and not g.body.lamp_lit:
					# Hours gone after a down and night come on: the lamp, lit with its key.
					Input.action_press(&"lamp")
					await tree.physics_frame
					await tree.process_frame
					Input.action_release(&"lamp")
					await tree.physics_frame
					said.clear()
					continue
				if line == Survival.THREAT_LINE or line == Outcomes.KEEPER_DOWNED_LINE:
					# Seen and turned on (or downed by it): off again until it
					# settles, and another go.
					said.clear()
					continue
				break
			thefts += 1
			# The take itself is a real second and a bit (Survival.WORK_SECONDS):
			# waited out in frames, however many that is on this box.
			for f in 20000:
				if SurvivalState.of(g).job.is_empty():
					break
				await tree.physics_frame
	Events.message.disconnect(hear)
	var robbed := 0
	for q in works:
		robbed += int(g.world.depleted.has(q.id))
	return {"works": works.size(), "robbed": robbed, "thefts": thefts, "waited": waited, "refused": refused,
		"sim_s": (g.player.sim.now - sim0) / 1000.0, "clock_min": g.clock.minutes - clock0, "walked": walked}


## Standable ground 12 tiles off its lair on the `away` side (or round from it):
## outside the guard it turns on a player inside, inside the ground it is put out on.
static func off_its_guard(g: Game, s: SentinelState, away: Vector2) -> Vector2:
	for k in 16:
		var p := s.lair + away.rotated(float((k + 1) / 2) * (TAU / 16.0) * (1.0 if k % 2 == 0 else -1.0)) * 12.0
		if g.query.standable(floori(p.x), floori(p.y)) and g.world.same_body(p, s.lair):
			return p
	return s.lair + away * 12.0


## A spot to stand beside `q` and take from it, as far out of `m`'s view (the
## angle off its facing) as the ground allows.
static func unseen_beside(g: Game, q: WorldProp, m: MobState) -> Vector2:
	var best := Vector2.INF
	var best_off := -1.0
	for k in 16:
		var p := q.pos + Vector2.from_angle(TAU * k / 16.0) * (q.solid + 0.7)
		if not g.query.standable(floori(p.x), floori(p.y)) or not g.query.body_fits(p, Tuning.PLAYER_RADIUS, null, true, FightSim.HERO_TALL):
			continue
		var off := 0.0 if m == null else absf(wrapf((p - m.pos).angle() - m.facing, -PI, PI))
		if off > best_off:
			best_off = off
			best = p
	return best if best.is_finite() else q.pos + Vector2.RIGHT * (q.solid + 0.7)
