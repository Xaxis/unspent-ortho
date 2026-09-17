extends TestCase
## The depot in a REAL GAME (docs/VISION.md §2). Everything here used to be
## claimed by a comment and proved by arithmetic over two constants: the first
## version of this package counted "162 bodies a day" out of `OWN_EVERY` and
## `PATROL_EVERY` and called it the measurement that the quieting is judged by,
## and nothing under tests/ ever built `34_works` at all.
##
## So this file runs the system. It counts what a depot really puts on the land
## over world hours, standing and broken; it holds a housing open with a real
## steel edge and reads the plan network's own file before and after; and it
## walks a body into the deck and into a tower to prove the two of them stop it.


func _game(args: PackedStringArray) -> Game:
	var o := BootOptions.parse(args)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func _works(g: Game) -> Node:
	return g.get_node("34_works")


## Put the body where a walk would have put it. The fight body owns the player's
## place in a running game, so both move or the next frame undoes it.
func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## World hours of the depot's own traffic, counted at the gate. The bodies are
## taken off the land as they come, because the coast is capped at six living and
## a full ring would stop the yard sending anyone: what is being measured is what
## the DEPOT does, not how many bodies fit in a frame.
func _traffic(g: Game, hours: float) -> int:
	var sys := _works(g)
	var sim := g.player.sim
	var steps := int(hours * 60.0 / 2.0)
	for i in steps:
		g.clock.skip(2.0)
		await frames(1)
		for m: MobState in sim.mobs.duplicate():
			sim.remove_mob(m)
	var out := 0
	for region: Variant in sys.put_out.values():
		out += int(region)
	return out


func test_a_standing_depot_puts_bodies_on_the_land_and_a_broken_one_puts_none() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--place=works"]))
	await frames(4)
	var sys := _works(g)
	var site: WorksSite = sys.here()
	check(site != null, "the player is standing on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var standing := await _traffic(g, 6.0)
	gt(float(standing), 8.0, "a working depot is why the land round it is busy")
	# Now put it out, exactly the way a player does, and count the same six hours.
	var st: WorksState = sys.state(site.region)
	for i in Works.PART_NAMES.size():
		st.parts[i] = true
	st.dark_at = g.clock.minutes
	st.dark_day = float(g.clock.day())
	check(sys.broken(site.region), "the yard is dark")
	sys.put_out.clear()
	var quiet := await _traffic(g, 6.0)
	eq(quiet, 0, "and a dark one puts nobody out, ever again")
	print("works in play: %d bodies out of the yard over 6 world hours standing -> %d broken" % [standing, quiet])
	g.queue_free()
	await frames(1)


## AND THE REGION, not only the yard. Putting a body out of the gate reaches
## thirty tiles; the region's ambient machines are the coast's own rolls, and
## until the depot was given a say in those, a region whose yard had been dark
## for a week rolled exactly as many machines as one whose yard was lit.
func test_a_dark_yard_shuts_its_whole_region_to_the_plan_and_leaves_what_lives_there() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--place=works"]))
	await frames(4)
	var sys := _works(g)
	var site: WorksSite = sys.here()
	check(site != null, "the player is standing on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var mobs := g.get_node("30_mobs")
	var coast: Coast = mobs.get(&"coast")
	var open := coast.shut()
	check(not open.has(&"harvester"), "a working region still sends its machines")
	var st: WorksState = sys.state(site.region)
	for i in Works.PART_NAMES.size():
		st.parts[i] = true
	st.dark_at = g.clock.minutes
	await frames(2)
	var closed := coast.shut()
	# Every machine of the plan that could have come out is shut, and nothing
	# that lives here is: the coast shuts hunters of its own until the first
	# meeting has come, so the two lists are compared rather than guessed at.
	var beasts := 0
	for k: StringName in Roster.DEFS:
		var machine: bool = Roster.row(k).get("machine", false)
		if machine:
			check(closed.has(k), "%s still comes out of a region whose yard is dark" % k)
		elif not open.has(k):
			check(not closed.has(k), "%s stopped living here because a yard went dark" % k)
			beasts += 1
	gt(float(beasts), 0.0, "the land is quiet, not empty")
	print("works: a dark yard shuts %d machines out of its region and leaves %d living things" % [closed.size() - open.size(), beasts])
	g.queue_free()
	await frames(1)


## INTERFERENCE IS FILED, and it is filed against the network the depot serves.
## Both systems found the disposition system by the string "32_disposition" and
## nothing proved the call landed: a rename would have turned "interference rises
## around a disturbed works" into a silent no-op.
func test_opening_a_housing_raises_the_plan_networks_file_on_the_player() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0",
		"--place=works", "--held=axe_felling"]))
	await frames(4)
	var sys := _works(g)
	var disp := g.get_node("32_disposition")
	var site: WorksSite = sys.here()
	check(site != null, "the player is standing on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	# Stand at the feed housing. `--place=works` puts a body on the yard's ground
	# and not on its hands, which is right for a player walking up to it.
	_stand(g, site.part(0) + Vector2.from_angle(site.facing) * 1.1)
	await frames(2)
	eq(Works.part_near(site, g.player.sim.hero.pos), 0, "the feed housing is under the hand")
	var net := Interference.network(g.world, site.pos)
	var before: float = disp.interference.value(net)
	# The plan already files a body standing in its yard (`_press`), so the
	# reading before is whatever trespass has cost, not nothing.
	# The real key, on the real part, for as long as a player would hold it.
	Input.action_press(&"use")
	var got := false
	for i in 400:
		await frames(1)
		if sys.tour_seen("works_part"):
			got = true
			break
	Input.action_release(&"use")
	check(got, "a housing came open under a held key and a steel edge")
	var after: float = disp.interference.value(net)
	gt(after, before, "and the plan filed it against this region's own network")
	print("works: interference on the yard's network %.2f -> %.2f when a housing goes" % [before, after])
	g.queue_free()
	await frames(1)


## THE DECK IS A WALL. Nothing in this package stopped a body at all until the
## masses were written: a player walked into the middle of the depot deck and
## stood inside it, and the yard was an open field with decorative furniture.
func test_a_body_cannot_walk_through_the_deck() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--place=works"]))
	await frames(4)
	var sys := _works(g)
	var site: WorksSite = sys.here()
	check(site != null, "the player is standing on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var from := site.pos + Vector2.from_angle(site.facing + PI * 0.5) * 6.0
	var into := g.query.move_body(from, (site.pos - from).normalized() * 5.0, 0.34)
	gt(into.distance_to(site.pos), 1.4, "a body walks straight through the deck")
	# And the ground it came from is still open, so the wall is the deck and not
	# a world that stops bodies everywhere.
	var away := g.query.move_body(from, (from - site.pos).normalized() * 3.0, 0.34)
	gt(away.distance_to(from), 2.0, "the yard is walled all round instead of walled at the deck")
	g.queue_free()
	await frames(1)


## THE SEAM WITH THE KEEPERS, which each package held half of and neither
## measured. Breaking a depot spends every plan work in its YARD, and a keeper
## eats the same works over its OWN reach — so putting a yard out is a real bite
## out of what feeds the region's keeper, and the STARVE way opens that far.
##
## IT IS A BITE AND NOT A KILL, which is the thing the package claimed and this
## is the measurement. A yard is `Works.YARD` (8 tiles) and a keeper feeds over
## `def.reach * FEED_SHARE` (about 21), so on seed 4 the salt flats keeper is fed
## by twelve works and breaking the depot spends four of them: it is a third of
## the way to starving, and the rest has to be robbed by hand. That is better
## than the claim — the set piece pays into the boss route without being a
## shortcut past it — so the radius is left alone and the number written down.
##
## Only two landscapes have a keeper at all (coast, salt flats), and where the
## island put no plan work inside one of their yards this way is not open there:
## seed 1's coast yard is such a one (docs/ROADMAP.md).
func test_what_a_broken_depot_spends_is_what_a_keeper_eats() -> void:
	var g := _game(PackedStringArray(["--seed=4", "--size=256", "--hour=11", "--weather=clear:0"]))
	await frames(4)
	var sys := _works(g)
	var found := false
	for s: WorksSite in Works.sites(g.world):
		var def := Sentinels.for_land(s.land)
		if def == null:
			continue
		var reach := def.reach * Sentinels.FEED_SHARE
		var before := Sentinels.feeds_among(g.query.props_near(s.pos, reach), s.pos, def,
			g.world.depleted, reach)
		if before <= 0:
			continue
		found = true
		sys._strip(s, sys.state(s.region))
		var after := Sentinels.feeds_among(g.query.props_near(s.pos, reach), s.pos, def,
			g.world.depleted, reach)
		lt(float(after), float(before),
			"%s: the yard went dark and its keeper lost nothing" % s.land)
		# Which is exactly how far the STARVE way has come, in the sentinel
		# package's own arithmetic: nothing here invents a second rule.
		var got := 1.0 - float(after) / float(before)
		gt(got, 0.1, "%s: a broken yard is worth less than a tenth of its keeper" % s.land)
		print("works/sentinels: the %s yard feeds its keeper %d works standing -> %d broken, %.0f%% of the way to starving it"
			% [s.land, before, after, got * 100.0])
	check(found, "seed 4 held no depot whose yard feeds a keeper; the chain went untested")
	g.queue_free()
	await frames(1)


## And the plan's own file: `Events.works_broken` was emitted for a whole wave
## with nothing listening, so a region whose yard had gone dark went on working
## itself up to hunted and sending bodies out of it. 32_disposition listens now.
func test_a_broken_depot_costs_the_plan_the_region() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--place=works"]))
	await frames(4)
	var sys := _works(g)
	var disp := g.get_node("32_disposition")
	var site: WorksSite = sys.here()
	check(site != null, "the player is standing on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	check(not disp.interference.is_lost(site.region), "the plan has not lost it yet")
	for i in Works.PART_NAMES.size():
		sys._break(site, i)
	await frames(2)
	check(sys.broken(site.region), "the yard is out")
	check(disp.interference.is_lost(site.region),
		"the plan still runs a region whose yard is dark")
	# Which is worth exactly one thing: nothing can be sent from there again.
	lt(disp.interference.level(site.region), 3, "a dark yard cannot hunt")
	g.queue_free()
	await frames(1)


## THE SLATE CAN BE PUT ON IT. A depot could be walked to, cased, broken and left
## dark, and the one thing in the game that says what a thing is had nothing to
## say about it — every body and every person on screen reads, and the biggest
## set piece in the game did not. It sorts BELOW every body and every person, so
## putting it in the list can never take the lock off what is coming at you.
func test_a_depot_reads_on_the_slate_and_never_steals_the_lock() -> void:
	var g := _game(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--place=works"]))
	await frames(4)
	var sys := _works(g)
	var site: WorksSite = sys.here()
	check(site != null, "the player is standing on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var rows: Array = sys.target_rows(g.player.pos, 40.0)
	gt(float(rows.size()), 0.0, "the depot answers for itself")
	var subject := TargetSubject.from_place(rows[0])
	var read := TargetRead.of_subject(subject, g.player.pos, g.player.sim.moment)
	check(str(read.get("name", "")).to_lower().contains("works"), "it says what it is: %s" % read.get("name"))
	var said := PackedStringArray()
	for pair: Array in (read.get("stats", []) as Array):
		said.append(String(pair[0]))
	for want: String in ["trade", "stage", "housings"]:
		check(said.has(want), "a player casing a yard is told its %s: %s" % [want, said])
	eq(int(read.get("health", -1)), 0, "a place has no health and does not invent one")
	# And it is the last thing a lock would take: below a person, which is itself
	# below every body.
	var far := g.player.pos
	lt(Targeting.threat_of(subject, far), Targeting.THREAT_PERSON,
		"a yard outranked a person for the lock")
	# What it says changes with what has been done to it.
	for i in Works.PART_NAMES.size():
		sys._break(site, i)
	await frames(2)
	var after: Array = sys.target_rows(g.player.pos, 40.0)
	var dark := TargetRead.of_subject(TargetSubject.from_place(after[0]), g.player.pos, g.player.sim.moment)
	check(str(dark.get("thinking", "")).to_lower().contains("dark"),
		"a broken yard still reads as a working one: %s" % dark.get("thinking"))
	g.queue_free()
	await frames(1)
