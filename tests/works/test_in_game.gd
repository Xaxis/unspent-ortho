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
