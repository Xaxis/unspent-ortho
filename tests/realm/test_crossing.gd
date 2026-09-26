extends TestCase
## Going through a shaft, in a running game: the world under the game changes,
## the body and its simulation go with it, and a save made on the far side opens
## back there with what that realm was carrying.

const Sx := preload("res://tests/save/save_fixture.gd")


func realms(g: Game) -> Node:
	return Sx.system(g, "20_realms")


func test_a_crossing_moves_the_whole_game_to_the_other_realm() -> void:
	Sx.use_root("realm-cross")
	var g := Sx.game(tree, ["--seed=1", "--size=96", "--hour=10"])
	var r := realms(g)
	check(r != null, "the realms system is loaded")
	if r == null:
		Sx.end(g)
		Sx.finish()
		return
	var up := g.world
	var shafts: Array = r.get("here")
	gt(float(shafts.size()), 0.0, "the surface has a shaft")
	if shafts.is_empty():
		Sx.end(g)
		Sx.finish()
		return
	var shaft: Portal = shafts[0]
	r.call("cross", shaft)

	eq(g.world.realm, Realm.UNDERGROUND, "the game is under the world")
	check(g.world != up, "on another world entirely")
	eq(g.query.world, g.world, "and the queries ask that one")
	eq(g.player.world, g.world, "the body walks in it")
	eq(g.player.query, g.query)
	eq(g.view.world, g.world, "and the view draws it")
	eq(Realm.at(g.world, g.player.pos), Realm.UNDERGROUND, "the ground under the player is under the world")
	if g.player.sim != null:
		eq(g.player.sim.world, g.world, "the simulation is in the new world")
		eq(g.player.sim.query, g.query)
		eq(g.player.sim.hero.pos, g.player.pos, "and the fight body came with it")
		# Nothing follows a person down a shaft.
		for m in g.player.sim.mobs:
			check(m.removed, "a body left on the far side was retired")
	var far := Portals.paired(g.world, shaft.id)
	check(far != null and far.pos.distance_to(g.player.pos) < 9.0, "the body came out of the paired shaft")
	eq(int(r.get("crossings")), 1, "the crossing is on the record")

	# And back up, to where it was standing.
	var down := g.world
	var back: Array = r.get("here")
	r.call("cross", back[0])
	eq(g.world.realm, Realm.SURFACE, "back on the surface")
	check(g.world == up, "on the same world it left, not a new one")
	check(g.world != down)
	eq(int(r.get("crossings")), 2)
	Sx.end(g)
	Sx.finish()


func test_a_save_made_under_the_world_opens_back_under_it() -> void:
	Sx.use_root("realm-save")
	var a := Sx.game(tree, ["--seed=1", "--size=96", "--hour=10"])
	var r := realms(a)
	var shafts: Array = r.get("here") if r != null else []
	if r == null or shafts.is_empty():
		fail("no shaft to cross")
		Sx.end(a)
		Sx.finish()
		return
	r.call("cross", shafts[0])
	var stood: Vector2 = a.player.pos
	# Something taken out of the cave, so the save has to carry THIS realm's
	# edits and not the surface's.
	var took := -1
	for p in a.world.each_prop():
		if p.solid > 0.0:
			took = p.id
			break
	if took >= 0:
		a.world.depleted[took] = INF
	var saver := Sx.system(a, "05_save")
	eq(str(saver.call("save_to", 1)), "", "saved from under the world")
	Sx.end(a)

	var o := BootOptions.new()
	eq(SaveSlots.options_for(1, o), "", "the slot boots")
	var b := Sx.game(tree, [], o)
	eq(b.world.realm, Realm.UNDERGROUND, "and opens under the world again")
	lt(b.player.pos.distance_to(stood), 0.01, "where it was standing")
	if took >= 0:
		check(b.world.depleted.has(took), "with what was taken out of THIS realm still taken")
	eq(int(Sx.system(b, "20_realms").get("crossings")), 1, "and what it remembers of the way down")
	Sx.end(b)
	Sx.finish()
