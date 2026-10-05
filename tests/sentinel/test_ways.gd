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
	if not stepped_now():
		return
	Sx.use_root("ways-starve")
	# Robbing eight works is hours of the clock: a player going to do it carries
	# something to eat, and eats when the body says so.
	var g := await Sx.played(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--held=knife_shear", "--give=fish:6"])
	# Bodies numbered from the same place whatever ran before in this process:
	# the reader's hands are hashed on a body's id (Reader.human).
	MobState._next_id = 900000
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
	var out: Dictionary = await KF.rob_larder(tree, g, s)
	print("  info starve: robbed %d of %d in %d takes, %.0f s waited off its ground, refused %s" % [out.robbed, out.works, out.thefts, out.waited, out.refused])
	gt(float(out.works), float(SentinelWay.FEEDS_LEAST) - 0.5, "it is fed by %d works" % out.works)
	eq(out.robbed, out.works, "every work that fed it is robbed out, in the world")
	# Away from it, and the dark counted.
	g.player.place(s.lair + Vector2(Sentinels.PUT_OUT * 2.0, 0.0))
	var t0 := g.player.sim.now
	while not s.fallen and g.player.sim.now - t0 < 12000.0:
		await tree.physics_frame
	check(s.fallen and s.how == def.way_of(SentinelWay.STARVE).id(), "and it stands dark and keeps nothing (%s)" % s.how)
	Sx.end(g)


const PR := preload("res://tests/fight/plate_reader.gd")
const KF := preload("res://tests/sentinel/keeper_fight.gd")


func test_by_force_from_firm_ground_it_falls_to_blows_and_never_founders() -> void:
	if not stepped_now():
		return
	var out: Dictionary = await _by_force(false)
	print("  info force by hand: %s" % out)
	check(out.fallen and out.how == SentinelWay.make(SentinelWay.FORCE).id(), "it falls to blows (%s)" % out)
	check(out.how != SentinelWay.make(SentinelWay.FOUNDER).id(), "and never founders under a fight kept on firm ground")
	lt(float(out.tries), 4.5, "in a few tries (%d)" % out.tries)


## Holding target is what a player does at a boss, so the lock must not cost the
## fight: the same players locked fall it as surely and about as fast. Summed
## over LOCK_READERS, because one reader is one draw of a fight a hair's change
## sends another way (one draw gave 49 s locked to 113 s free, the next 79 to 43,
## with nothing about the lock changed between them).
func test_from_above_the_lock_costs_the_fight_nothing() -> void:
	if not stepped_now():
		return
	await _lock_costs_nothing(false)


func test_over_the_shoulder_the_lock_costs_the_fight_nothing() -> void:
	if not stepped_now():
		return
	await _lock_costs_nothing(true)


func _lock_costs_nothing(shoulder: bool) -> void:
	var free := {"tries": 0, "s": 0.0, "fell": 0}
	var held := {"tries": 0, "s": 0.0, "fell": 0}
	for human: int in LOCK_READERS:
		for locked: bool in [false, true]:
			var out: Dictionary = await _by_force(locked, shoulder, human)
			print("  info   reader %d %s: %s" % [human, "locked" if locked else "free", out])
			var sum: Dictionary = held if locked else free
			sum.tries += int(out.tries)
			sum.s += float(out.s)
			sum.fell += int(out.fallen)
	var view := "over the shoulder" if shoulder else "from above"
	print("  info force %s, readers %s: free %s, locked %s" % [view, LOCK_READERS, free, held])
	check(held.fell >= free.fell, "%s, locked it falls as often (%d) as free (%d)" % [view, held.fell, free.fell])
	# Tries per fall: a fight never won within the budget spends fewer tries than
	# one won on the last of them, and must not count as the better.
	var per_free := float(free.tries) / maxf(1.0, float(free.fell))
	var per_held := float(held.tries) / maxf(1.0, float(held.fell))
	lt(per_held, per_free + 0.25, "in no more tries a fall locked (%.2f) than free (%.2f)" % [per_held, per_free])
	lt(float(held.s), float(free.s) * LOCKED_MOST, "and about as fast: %.1f s locked, %.1f s free" % [held.s, free.s])


## How much longer the locked fights may take than the same players' free ones.
const LOCKED_MOST := 1.2
## The players both are fought by (Reader.human).
const LOCK_READERS: Array[int] = [1, 2, 3]

const NONE := {"fallen": false, "how": &"", "tries": 99, "downs": 0, "s": INF, "health": -1}


## The Reaper fought by plate player `human` from firm ground, the target key
## held throughout when `locked`, from above or over the shoulder. Returns the tally, NONE when there was no fight.
func _by_force(locked: bool, shoulder := false, human := 1) -> Dictionary:
	Sx.use_root("ways-force")
	var g := await Sx.played(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--held=knife_shear",
		"--view=shoulder" if shoulder else "--view=top"])
	# Bodies numbered from the same place whatever ran before in this process:
	# the reader's hands are hashed on a body's id (Reader.human).
	MobState._next_id = 900000
	var s := _reaper(g)
	check(s != null, "seed 1 holds a reaper")
	if s == null:
		Sx.end(g)
		return NONE
	KF.calm(g)
	var flats: Array = Sentinels.by_id(s.design).way_of(SentinelWay.FOUNDER).grounds
	var at := KF.stand(g, s, 6.0, flats, false)
	check(at.is_finite(), "firm ground to come at it from")
	if not at.is_finite():
		Sx.end(g)
		return NONE
	var r: Variant = PR.new(g.player.sim)
	r.human = human
	r.keep_off = flats
	r.home = at
	var out: Dictionary = await KF.fight(tree, g, s, at, r, 240.0, locked)
	Sx.end(g)
	return out


func test_held_out_on_the_flats_it_founders() -> void:
	if not stepped_now():
		return
	Sx.use_root("ways-founder")
	var g := await Sx.played(tree, ["--seed=1", "--hour=11", "--weather=clear:0", "--held=knife_shear"])
	# Bodies numbered from the same place whatever ran before in this process:
	# the reader's hands are hashed on a body's id (Reader.human).
	MobState._next_id = 900000
	var s := _reaper(g)
	check(s != null, "seed 1 holds a reaper")
	if s == null:
		Sx.end(g)
		return
	KF.calm(g)
	var flats: Array = Sentinels.by_id(s.design).way_of(SentinelWay.FOUNDER).grounds
	# Drawn to its flats by name, as a player is and a tour stages it (`near
	# keeper_flats`): the nearest of its ground in a patch a body's width across.
	# The spot picked by distance off the den, with the most of that ground round
	# it, was the edge of a two-tile strip by the water once seed 1's Reaper
	# denned off its larder, and it stood biting from the firm ground.
	var flat := Sentinels.founder_spot(g.world, s.lair, Sentinels.by_id(s.design))
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
	var out: Dictionary = await KF.fight(tree, g, s, start, r, 90.0)
	print("  info founder by hand: %s" % out)
	check(out.fallen and out.how == SentinelWay.make(SentinelWay.FOUNDER).id(), "drawn out onto the flats and held there, it founders (%s)" % out)
	Sx.end(g)
