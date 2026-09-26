extends TestCase
## The three ways a landscape is taken from its keeper (docs/VISION.md). They
## are pure rules over a `SentinelLook`, which is the whole reason they can be
## proved here: the fight is full of nodes and none of them is needed to say
## whether the land has taken a machine or the plan has stopped feeding it.


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
				var known := land.grounds.has(g) or g == land.plain_ground or g == land.bank_ground \
					or g == Ground.WATER or g == Ground.RIVER or g == Ground.MUD
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
