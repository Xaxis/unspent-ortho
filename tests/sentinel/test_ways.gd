extends TestCase
## The three ways a landscape is taken from its keeper (docs/VISION.md): first
## as pure rules over a `SentinelLook`, then each played in a running game on
## seed 1's Tide Reaper by what a player does, nothing set by hand (below).


func _look() -> SentinelLook:
	var l := SentinelLook.new()
	l.health = 1.0
	l.ground = Ground.GRASS
	# The smallest larder a starve way opens on (SentinelWay.FEEDS_LEAST).
	l.feeds = 4
	l.feeds_at_first = 4
	return l


func test_force_is_its_body_spent_and_nothing_less() -> void:
	var w := SentinelWay.make(SentinelWay.FORCE)
	var l := _look()
	check(not w.met(l), "at full health it is not beaten")
	near(w.progress(l), 0.0, 1e-4, "and nothing has been done to it")
	l.health = 0.5
	near(w.progress(l), 0.5, 1e-4, "half its health is half the way")
	check(not w.met(l), "half is not beaten")
	l.health = 0.0
	check(w.met(l), "spent is beaten")
	check(w.kills(), "and it leaves a wreck")


func test_the_land_takes_it_only_where_the_ground_will_not_carry_it_and_only_if_it_stays() -> void:
	var w := SentinelWay.make(SentinelWay.FOUNDER, 1500.0, [Ground.MUD, Ground.WATER])
	var l := _look()
	l.ground_ms = 9000.0
	check(not w.met(l), "on turf it can stand all day")
	near(w.progress(l), 0.0, 1e-4, "and the way has not begun")
	l.ground = Ground.MUD
	l.ground_ms = 750.0
	near(w.progress(l), 0.5, 1e-4, "half way in")
	check(not w.met(l), "a machine that crosses the mud is not a machine that founders in it")
	l.ground_ms = 1500.0
	check(w.met(l), "stood in it, the land has it")
	check(w.kills(), "and what is left is a hulk")
	# The way a player spends it: a charge commits to a bearing (Brains._charge),
	# so it is the keeper's own run that puts it where the ground gives.
	var def := Sentinels.for_land(&"coast")
	check(Roster.row(def.kind).get("approach", &"") == &"charge", "the reaper commits to a run")
	check(def.way_of(SentinelWay.FOUNDER) != null, "and the tide flats are one of its three ways")


func test_starving_it_wants_its_works_gone_and_time_standing_dark() -> void:
	var w := SentinelWay.make(SentinelWay.STARVE, 3000.0)
	var l := _look()
	check(not w.met(l), "fed, it keeps working")
	l.feeds = 2
	near(w.progress(l), 0.5, 1e-4, "two of its four works robbed is half the way")
	check(not w.met(l), "but it is still fed")
	l.feeds = 0
	l.dark_ms = 1500.0
	near(w.progress(l), 0.5, 1e-4, "dark, and counting")
	check(not w.met(l), "not yet")
	l.dark_ms = 3000.0
	check(w.met(l), "dark long enough and it has stopped keeping anything")
	check(not w.kills(), "nothing was killed: it is standing there, switched off")
	# A keeper with nothing feeding it in the first place is not already beaten.
	var none := _look()
	none.feeds = 0
	none.feeds_at_first = 0
	none.dark_ms = 99999.0
	check(not w.met(none), "a keeper the plan never fed cannot be starved")


func test_spoofing_it_wants_the_player_inside_its_guard_and_read_as_one_of_its_own() -> void:
	var w := SentinelWay.make(SentinelWay.SPOOF, 2000.0)
	var l := _look()
	l.spoof_ms = 9000.0
	check(not w.met(l), "a signature alone does nothing from outside its guard")
	l.inside = true
	check(not w.met(l), "nor does walking in without one")
	l.spoofed = true
	l.spoof_ms = 1000.0
	near(w.progress(l), 0.5, 1e-4, "half way to being filed as one of them")
	l.spoof_ms = 2000.0
	check(w.met(l), "and then it stands down")
	check(not w.kills(), "beaten, never killed")


func test_a_spoof_that_reads_under_a_lamp_reads_nowhere_else() -> void:
	# The unbuilder takes its orders off the district's lamps, so the signature
	# is only read under one: inside its guard and spoofed is not enough.
	var w := SentinelWay.make(SentinelWay.SPOOF, 2000.0)
	w.beside = [PropKind.LAMP]
	var l := _look()
	l.inside = true
	l.spoofed = true
	l.spoof_ms = 9000.0
	near(w.progress(l), 0.0, 1e-4, "spoofed inside its guard in the open, nothing is read")
	check(not w.beside_met(l), "and the system is told the clock should not run")
	l.beside = [PropKind.DEBRIS]
	near(w.progress(l), 0.0, 1e-4, "a heap of rubble is not a lamp")
	l.beside = [PropKind.DEBRIS, PropKind.LAMP]
	check(w.beside_met(l), "under a lamp, the way is open")
	l.spoof_ms = 1000.0
	near(w.progress(l), 0.5, 1e-4, "and the hold counts from there")
	# A way that names nothing reads anywhere inside the guard, as the rake's does.
	var plain := SentinelWay.make(SentinelWay.SPOOF, 2000.0)
	l.beside = []
	check(plain.beside_met(l), "no gate, no lamp needed")
	var unbuilder := Sentinels.by_id(&"unbuilder")
	check(unbuilder != null and unbuilder.way_of(SentinelWay.SPOOF) != null
		and unbuilder.way_of(SentinelWay.SPOOF).beside.has(PropKind.LAMP), "the unbuilder's own spoof is the lamp's")


func test_a_spoof_read_off_a_boat_is_read_off_nothing_else() -> void:
	# The lockkeeper keeps a canal's timetable and reads a signature as one of
	# its boats' calls, so the signet is only read from a raft in its lane:
	# inside its guard and spoofed, on foot, is a person in a canal.
	var w := SentinelWay.make(SentinelWay.SPOOF, 2000.0)
	w.aboard = &"raft"
	var l := _look()
	l.inside = true
	l.spoofed = true
	l.spoof_ms = 9000.0
	near(w.progress(l), 0.0, 1e-4, "spoofed inside its guard, wading, nothing is read")
	check(not w.reads_here(l), "and the system is told the clock should not run")
	l.riding = &"hover_sled"
	near(w.progress(l), 0.0, 1e-4, "a sled is not a boat")
	l.riding = &"raft"
	check(w.reads_here(l), "on a raft, the way is open")
	l.spoof_ms = 1000.0
	near(w.progress(l), 0.5, 1e-4, "and the hold counts from there")
	l.spoofed = false
	near(w.progress(l), 0.0, 1e-4, "a raft without the signet is only a raft")
	# A way that names no craft reads a body on foot, as every other keeper does.
	var plain := SentinelWay.make(SentinelWay.SPOOF, 2000.0)
	l.riding = &""
	check(plain.reads_here(l), "no craft named, none needed")
	var keeper := Sentinels.by_id(&"lockkeeper")
	check(keeper != null and keeper.way_of(SentinelWay.SPOOF) != null
		and keeper.way_of(SentinelWay.SPOOF).aboard == &"raft", "the lockkeeper's own spoof is read off a raft")
	check(keeper != null and not keeper.has_way(SentinelWay.FOUNDER), "and nothing in a drowned city founders it")
	check(CraftKinds.known(&"raft"), "the craft it names is one a player can ride")


func test_each_design_offers_its_three_and_they_are_reachable_in_its_own_land() -> void:
	for def: SentinelDef in Sentinels.all():
		var land := BiomeRegistry.get_def(def.land)
		var founder := def.way_of(SentinelWay.FOUNDER)
		if founder != null:
			check(not founder.grounds.is_empty(), "%s: the land that takes it is named" % def.id)
			for g: int in founder.grounds:
				# The ground it founders in is ground its own landscape has, or the
				# way is a promise the world never keeps.
				var pool_ground := int(land.pools.get("ground", -1)) if not land.pools.is_empty() else -1
				var known := land.grounds.has(g) or g == land.plain_ground or g == land.bank_ground \
					or g == Ground.WATER or g == Ground.RIVER or g == Ground.MUD or g == pool_ground
				check(known, "%s founders in %s, which %s has" % [def.id, Ground.NAMES[g], def.land])
		var starve := def.way_of(SentinelWay.STARVE)
		if starve != null:
			check(not def.feeds.is_empty(), "%s: what feeds it is named" % def.id)
			for kind: int in def.feeds:
				check(kind >= 0 and kind < PropKind.COUNT, "%s: %d is a prop kind" % [def.id, kind])
		var spoof := def.way_of(SentinelWay.SPOOF)
		if spoof != null:
			# Something a player can actually wear has to grant the spoof, or the
			# way is a rule with nothing behind it.
			var granted := false
			for id: StringName in Items.DEFS:
				if Items.def(id).get("ability", &"") == &"spoof":
					granted = true
			check(granted, "%s: a module grants the signature it reads" % def.id)


# --- each way won by what a player does -------------------------------------
# The rules above are the ways' own. What follows plays them in a running game
# with nothing set by hand: the feeds robbed with the take a player makes, the
# flats reached by walking, the fight fought by a player-like driver
# (tests/sentinel/test_reaper_force.gd, the plate player). On seed 1's Tide
# Reaper, the owner's.

const Sx := preload("res://tests/save/save_fixture.gd")


func _reaper(g: Game) -> SentinelState:
	for s: SentinelState in Sx.system(g, "44_sentinels").call(&"states"):
		if s.land == &"coast" and not s.fallen and s.region >= 0:
			return s
	return null


## Rob every work that feeds it with `use`, farthest first, as a player walking
## in along its pipe would, then wait on the dark. STARVE's words: "The intake
## feeds it. Rob the intake."
func test_robbing_its_feeds_by_hand_starves_it() -> void:
	Sx.use_root("ways-starve")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--held=knife_shear"])
	var s := _reaper(g)
	check(s != null, "seed 1 holds a reaper")
	if s == null:
		Sx.end(g)
		return
	var def := Sentinels.by_id(s.design)
	# The coast's own comings and goings held off, as a tour's `coast calm`:
	# this is the keeper's way, not a crowd's.
	(Sx.system(g, "30_mobs").get("coast") as Object).set("spawning", false)
	g.player.sim.clear_mobs()
	var reach := def.reach * Sentinels.FEED_SHARE
	var feeds: Array[WorldProp] = []
	for q: WorldProp in g.query.props_near(s.lair, reach):
		if def.feeds.has(q.kind) and q.pos.distance_to(s.lair) <= reach:
			feeds.append(q)
	feeds.sort_custom(func(a: WorldProp, b: WorldProp) -> bool: return a.pos.distance_to(s.lair) > b.pos.distance_to(s.lair))
	gt(float(feeds.size()), float(SentinelWay.FEEDS_LEAST) - 0.5, "it is fed by %d works" % feeds.size())
	var refused := {}
	var said: Array[String] = []
	var hear := func(line: String) -> void: said.append(line)
	Events.message.connect(hear)
	var waited := 0.0
	var thefts := 0
	for q in feeds:
		var away := (q.pos - s.lair).normalized() if q.pos.distance_to(s.lair) > 0.1 else Vector2.RIGHT
		for take in 4:
			if g.world.depleted.has(q.id):
				break
			# A theft stirs it (34_works: a plan work opened tells its machines).
			# A player goes off out of its ground until it has settled, and back.
			var m: MobState = s.body
			if m != null and (m.disturbed or m.roused()):
				g.player.place(s.lair + away * Sentinels.PUT_OUT * 2.0)
				var w0 := Time.get_ticks_msec()
				while s.body != null and Time.get_ticks_msec() - w0 < 60000:
					await frames(5)
				waited += (Time.get_ticks_msec() - w0) / 1000.0
			g.player.place(q.pos + away * (q.solid + 0.7), (-away).angle())
			await frames(2)
			if not Survival.use(g):
				var t := Survival.use_target(g)
				for mm: MobState in g.player.sim.mobs:
					if mm.alive and not mm.removed and Senses.chebyshev(mm.pos, g.player.pos) <= Survival.THREAT_RADIUS:
						print("  threat? %s mood=%s disturbed=%s disp=%s at_work=%s roused=%s fight_on=%s" % [mm.kind, mm.mood, mm.disturbed, mm.disposition, mm.at_work(), mm.roused(), g.player.sim.fight_on])
				refused[PropKind.NAMES[q.kind]] = "%s (aimed at %s, said %s)" % [q.pos.distance_to(s.lair), PropKind.NAMES[t.kind] if t != null else "nothing", said.back() if not said.is_empty() else ""]
				break
			thefts += 1
			var t0 := Time.get_ticks_msec()
			while not SurvivalState.of(g).job.is_empty() and Time.get_ticks_msec() - t0 < 4000:
				await frames(1)
	Events.message.disconnect(hear)
	var robbed := 0
	for q in feeds:
		robbed += int(g.world.depleted.has(q.id))
	print("  info starve: robbed %d of %d in %d takes, %.0f s waited off its ground, refused %s" % [robbed, feeds.size(), thefts, waited, refused])
	eq(robbed, feeds.size(), "every work that fed it is robbed out, in the world")
	# Away from it, and the dark counted.
	g.player.place(s.lair + Vector2(Sentinels.PUT_OUT * 2.0, 0.0))
	var t0 := Time.get_ticks_msec()
	while not s.fallen and Time.get_ticks_msec() - t0 < 12000:
		await frames(5)
	check(s.fallen and s.how == def.way_of(SentinelWay.STARVE).id(), "and it stands dark and keeps nothing (%s)" % s.how)
	Sx.end(g)


const PR := preload("res://tests/fight/plate_reader.gd")
const GD := preload("res://tests/fight/game_driver.gd")


## A spot `dist` off its lair on its own level, down a line its run can take,
## with the most (or least) of the ground `grounds` round it.
func _stand(g: Game, s: SentinelState, dist: float, grounds: Array, most: bool) -> Vector2:
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


## Fought by the plate player through the game's input (GameDriver): the coast
## held off, knife_shear in hand, from firm ground it keeps to. Downed, it comes
## to at the edge of the keeper's ground and walks back. Returns the tally.
func _fight_it(g: Game, s: SentinelState, at: Vector2, reader: Variant, seconds: float) -> Dictionary:
	var sim: FightSim = g.player.sim
	g.player.place(at, (s.lair - at).angle())
	var d: Variant = GD.new(g, reader)
	var downs := [0]
	var on_end := func(o: StringName) -> void:
		if o == &"downed" or o == &"carried":
			downs[0] += 1
	Events.fight_ended.connect(on_end)
	var t0 := sim.now
	var until := Time.get_ticks_msec() + int(seconds * 1000.0 * 4.0)
	while not s.fallen and sim.now - t0 < seconds * 1000.0 and Time.get_ticks_msec() < until:
		d.step()
		await tree.physics_frame
	Events.fight_ended.disconnect(on_end)
	return {"fallen": s.fallen, "how": s.how, "tries": downs[0] + 1, "downs": downs[0], "s": (sim.now - t0) / 1000.0, "health": s.health}


func _calm(g: Game) -> void:
	(Sx.system(g, "30_mobs").get("coast") as Object).set("spawning", false)
	g.player.sim.clear_mobs()


func test_by_force_from_firm_ground_it_falls_to_blows_and_never_founders() -> void:
	Sx.use_root("ways-force")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--held=knife_shear"])
	var s := _reaper(g)
	check(s != null, "seed 1 holds a reaper")
	if s == null:
		Sx.end(g)
		return
	_calm(g)
	var flats: Array = Sentinels.by_id(s.design).way_of(SentinelWay.FOUNDER).grounds
	var at := _stand(g, s, 6.0, flats, false)
	check(at.is_finite(), "firm ground to come at it from")
	if not at.is_finite():
		Sx.end(g)
		return
	var r: Variant = PR.new(g.player.sim)
	r.human = 1
	r.keep_off = flats
	r.home = at
	var out: Dictionary = await _fight_it(g, s, at, r, 240.0)
	print("  info force by hand: %s" % out)
	check(out.fallen and out.how == SentinelWay.make(SentinelWay.FORCE).id(), "it falls to blows (%s)" % out.how)
	check(out.how != SentinelWay.make(SentinelWay.FOUNDER).id(), "and never founders under a fight kept on firm ground")
	lt(float(out.tries), 4.5, "in a few tries (%d)" % out.tries)
	Sx.end(g)


func test_held_out_on_the_flats_it_founders() -> void:
	Sx.use_root("ways-founder")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--held=knife_shear"])
	var s := _reaper(g)
	check(s != null, "seed 1 holds a reaper")
	if s == null:
		Sx.end(g)
		return
	_calm(g)
	var flats: Array = Sentinels.by_id(s.design).way_of(SentinelWay.FOUNDER).grounds
	var flat := Vector2.INF
	for dist: float in [6.0, 8.0, 10.0, 12.0, 4.0]:
		flat = _stand(g, s, dist, flats, true)
		if flat.is_finite():
			break
	check(flat.is_finite(), "flats to draw it onto")
	if not flat.is_finite():
		Sx.end(g)
		return
	# Stirred from inside its guard, on the firm ground short of the flats.
	var start := s.lair + (flat - s.lair).normalized() * 5.0
	var r: Variant = PR.new(g.player.sim)
	r.human = 2
	r.keep_on = flats
	r.lure = flat
	r.home = start
	var out: Dictionary = await _fight_it(g, s, start, r, 90.0)
	print("  info founder by hand: %s" % out)
	check(out.fallen and out.how == SentinelWay.make(SentinelWay.FOUNDER).id(), "drawn out onto the flats and held there, it founders (%s)" % out.how)
	Sx.end(g)
