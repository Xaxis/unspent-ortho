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
	# ASKED BY TAKING THE DECK AWAY, ON A WALK THE DECK IS REALLY IN THE WAY OF.
	# This walked in from six tiles to one side and out again, and read "stopped"
	# as the deck and "open" as the yard. Sited by region, seed 1's depot stands on
	# a hillside there: the walk in stopped at 6.21 with the deck and 5.86 WITHOUT
	# it -- the terraces stopped it, so "a body cannot walk through the deck"
	# passed on a walk that never reached the deck. So every walk is taken twice,
	# with the yard's mass and without it (`set_blocks(&"works", [])`), from
	# bearings all round; one that reaches the deck with nothing there is a real
	# approach, and on it the deck has to stop the body and walking away has to
	# be the same either way.
	var bearings: Array[Vector2] = []
	for k in 16:
		bearings.append(Vector2.from_angle(site.facing + TAU * k / 16.0))
	var walled: Array[Vector2] = []
	var outward: Array[Vector2] = []
	for dir: Vector2 in bearings:
		var from := site.pos + dir * 6.0
		walled.append(g.query.move_body(from, -dir * 5.0, 0.34))
		outward.append(g.query.move_body(from, dir * 3.0, 0.34))
	g.query.set_blocks(&"works", [] as Array[Vector3])
	var tried := 0
	for k in bearings.size():
		var from := site.pos + bearings[k] * 6.0
		var open := g.query.move_body(from, -bearings[k] * 5.0, 0.34)
		if open.distance_to(site.pos) > 1.4:
			continue
		tried += 1
		gt(walled[k].distance_to(site.pos), 1.4, "a body walks straight through the deck (bearing %d)" % k)
		near(outward[k].distance_to(g.query.move_body(from, bearings[k] * 3.0, 0.34)), 0.0, 0.01,
			"and walking away is the same with or without it: walled at the deck, not all round (bearing %d)" % k)
	gt(float(tried), 0.0, "some bearing reaches the deck when the deck is not there")
	g.queue_free()
	await frames(1)


## THE SEAM WITH THE KEEPERS, which each package held half of and neither
## measured. Breaking a depot spends every plan work in its YARD, and a keeper
## eats the same works over its OWN reach — so putting a yard out is a real bite
## out of what feeds the region's keeper, and the STARVE way opens that far.
##
## IT IS A BITE AND NOT A KILL, which is the thing the package claimed. A yard is
## `Works.YARD` (8 tiles) and a keeper feeds over `def.reach * FEED_SHARE` (about
## 21), so the two overlap only partly and the rest has to be robbed by hand: the
## set piece pays into the boss route without being a shortcut past it. The share
## it pays is a property of the island and is measured per site below, not fixed
## here — an earlier version of this header recorded one seed's twelve-and-four as
## though it were the rule, and that number is what broke when an eleventh
## landscape moved the ground.
##
## Only two landscapes have a keeper at all (coast, salt flats), and where an
## island put no plan work inside one of their yards this way is not open there.
## ASKED OF A SAMPLE, AND THE CLOSED YARDS ARE COUNTED (owner, 2026-09-18). This
## pinned seed 4 and asserted the bite at EVERY qualifying site on it, with the
## numbers above written into the header as if they were laws. They were one
## island's measurement: on today's island the same salt flats keeper is fed by
## nine works and its yard spends none, because nothing in that yard passes
## `Takes.is_plan_work` — pan gates and salt heaps are the landscape's own
## furniture. The mechanism is intact; the ground moved under a number.
##
## READ THE FAILURE, NOT THE GREEN. A sampled pass says the chain works SOMEWHERE,
## not that the STARVE way is open on your island: `Works.sites` picks a yard by
## what the plan has been doing there and takes no account of what the region's
## keeper eats, so the two sets can miss entirely. The closed count and the deepest
## bite are printed on purpose. If closed climbs toward all of them, the answer is
## not a looser bar here — it is that the seam only ever worked by coincidence and
## the siting has to learn about the keeper.
##
## WHAT IS ASSERTED IS THE MECHANISM, NOT A SHARE. This used to demand that every
## biting yard was worth more than a TENTH of its keeper, which was seed 4's own
## 33% turned into a law — the same move as the twelve-and-four above, and it
## failed at exactly 0.1 on the eleven-landscape island. No design document ever
## claimed a tenth. What docs/ROADMAP.md does record, deliberately, is that "a
## depot whose yard holds no plan work strips nothing ... that is the island's
## business rather than a broken seam". So the bar is that the chain bites at all,
## somewhere in the sample, and the depth is measured and printed rather than
## legislated. The siting gap is real and is its own task; it is not this test's
## to hold main red over.
##
## **AND AT THE SHIPPED SIZE THE GAP IS TOTAL. MEASURED 2026-09-19, seeds 4, 1
## and 42 at `Tuning.WORLD_SIZE`:**
##
##   seed  4  coast: 9 works, yard spends none    salt_flats: 6 works, none
##   seed  1  coast: 8 works, yard spends none    salt_flats: 15 works, none
##   seed 42  coast: 7 works, yard spends none    salt_flats: 9 works, none
##
## Six of six closed. The header above says what to do when closed climbs toward
## all of them, and it is not a looser bar here: the seam only ever worked by
## coincidence, and `Works.sites` has to learn what the region's keeper eats.
##
## The other half of the picture is why the sample is only ever two landscapes:
## **the game has TWO sentinel designs** (`tide_reaper`, `pan_rake`) for
## twenty-one landscapes, against docs/VISION.md §3's one keeper per landscape.
## So nineteen landscapes have no keeper for a yard to starve in the first place,
## and on the two that do, no depot falls inside the keeper's feeding reach.
## **The STARVE way of taking a sentinel is currently open on no island at all.**
## That is content and siting, not this file, and this test failing is how it is
## visible rather than a thing to tune away.
func test_what_a_broken_depot_spends_is_what_a_keeper_eats() -> void:
	var bit := 0
	var closed := 0
	var best := 0.0
	var said := PackedStringArray()
	# **ASKED OF A SHIPPED-SIZE WORLD.** At 256 this sampled three seeds of a toy
	# island whose regions are a twentieth of a real one's: few runs clear
	# `Works.MIN_TILES`, so few depots exist, and whether any of them happened to
	# land inside a keeper's feeding reach was luck. One real world holds more
	# depots and more keepers than three toy ones, which is what makes the sample
	# a sample. One seed, because a world at 1300 costs about eleven seconds.
	for seed_value: int in [4, 1, 42]:
		var g := _game(PackedStringArray(["--seed=%d" % seed_value, "--size=%d" % Tuning.WORLD_SIZE, "--hour=11", "--weather=clear:0"]))
		await frames(4)
		var sys := _works(g)
		for s: WorksSite in Works.sites(g.world):
			var def := Sentinels.for_land(s.land)
			if def == null:
				continue
			# MEASURED AT THE KEEPER'S LAIR, NOT AT THE YARD. The claim is that
			# breaking a depot takes food out of a KEEPER's reach, and a keeper does
			# not stand in the yard: measured, the coast's reaper dens at its intake
			# and its region's depot is 60 to 168 tiles away, well outside the 21 it
			# feeds over. Asking the question at the yard was asking whether the
			# yard contains anything of the right kind, which is a different
			# question and was true or false by luck. The salt flats' rake dens on
			# its own brine house, so there the two genuinely overlap.
			var region := {}
			for r: Dictionary in g.world.regions:
				if int(r.get("id", -1)) == s.region:
					region = r
			if region.is_empty():
				continue
			var lair := Sentinels.lair(g.world, region, def)
			var reach := def.reach * Sentinels.FEED_SHARE
			var before := Sentinels.feeds_among(g.query.props_near(lair, reach), lair, def,
				g.world.depleted, reach)
			if before <= 0:
				continue
			sys._strip(s, sys.state(s.region))
			var after := Sentinels.feeds_among(g.query.props_near(lair, reach), lair, def,
				g.world.depleted, reach)
			var got := 1.0 - float(after) / float(before)
			if after >= before:
				closed += 1
				said.append("seed %d %s: %d works, yard spends none" % [seed_value, s.land, before])
				continue
			bit += 1
			best = maxf(best, got)
			said.append("seed %d %s: %d works standing -> %d broken, %.0f%% of the way to starving it"
				% [seed_value, s.land, before, after, got * 100.0])
		g.queue_free()
		await frames(1)
	for line: String in said:
		print("works/sentinels: %s" % line)
	gt(float(bit), 0.0, "no yard in the sample fed a keeper anything: the chain is untested, or the siting has stopped meeting the keepers (%d closed)" % closed)
	print("works/sentinels: the yard-to-keeper chain bit at %d sites, was closed at %d, and the deepest bite was %.0f%%"
		% [bit, closed, best * 100.0])


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
