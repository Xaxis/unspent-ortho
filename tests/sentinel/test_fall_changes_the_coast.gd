extends TestCase
## ITS FALL CHANGES THE COAST (docs/ROADMAP.md, slice 1 step 5), in a real game.
## The home coast's keeper is taken through 44_sentinels' own fall, and then the
## land is asked what changed and whether it stays changed:
##   its yard goes dark a moment after it, as a broken yard does, and stays dark;
##   the stations it fed on stand on dark, their lights out for good;
##   the ground closes over where it fell, a tuft at a time, and never twice;
##   the memory it held comes back.

const SEEDS: Array[int] = [1, 7, 3]
const SIZE := 256


func _game(seed_value: int) -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=%d" % seed_value, "--size=%d" % SIZE, "--hour=11", "--weather=clear:0"])))
	return g


func _end(g: Game) -> void:
	g.queue_free()
	await frames(1)
	Story.forget()


func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## The first seed whose home-coast keeper keeps a region the plan has a yard in:
## [game, keeper state, its design], or [] when none of SEEDS has one.
func _coast_with_a_yard() -> Array:
	for s in SEEDS:
		var g := _game(s)
		await frames(3)
		var works := g.get_node("34_works")
		for st: SentinelState in g.get_node("44_sentinels").call(&"states"):
			if st.design == &"tide_reaper" and works.call(&"state", st.region) != null:
				return [g, st, Sentinels.by_id(st.design)]
		await _end(g)
	return []


## The stations it feeds on round `at`, spent or not.
func _feed(g: Game, at: Vector2, def: SentinelDef) -> Array[WorldProp]:
	var reach := def.reach * Sentinels.FEED_SHARE
	var out: Array[WorldProp] = []
	for q in g.query.props_near(at, reach):
		if def.feeds.has(q.kind) and q.pos.distance_to(at) <= reach and not g.world.depleted.has(q.id):
			out.append(q)
	return out


func _fed(g: Game, at: Vector2, def: SentinelDef) -> int:
	var reach := def.reach * Sentinels.FEED_SHARE
	return Sentinels.feeds_among(g.query.props_near(at, reach), at, def, g.world.depleted, reach)


func test_the_reapers_fall_puts_its_yard_dark_darkens_its_feed_and_greens_its_ground() -> void:
	Story.forget()
	var got := await _coast_with_a_yard()
	check(not got.is_empty(), "one of %s has a home-coast keeper in a region with a yard" % str(SEEDS))
	if got.is_empty():
		return
	var g: Game = got[0]
	var s: SentinelState = got[1]
	var def: SentinelDef = got[2]
	var works := g.get_node("34_works")
	var den := s.lair
	var fed := _fed(g, den, def)
	gt(float(fed), 0.0, "the reaper dens where something feeds it")
	check(not works.call(&"broken", s.region), "its yard is lit while it stands")

	g.get_node("44_sentinels").call(&"_fell", s, def, def.way_of(SentinelWay.FORCE), den)
	var feed := _feed(g, den, def)
	eq(feed.size(), fed, "what it fed on is all still standing")
	for q: WorldProp in feed:
		check(g.world.unlit.has(q.id), "%s it fed on has gone dark with it" % PropKind.NAMES[q.kind])
	check(Story.landed(&"mem_car"), "and the memory it held comes back")
	check(not works.call(&"broken", s.region), "the yard is still lit the moment it falls")

	# A moment later, across the land, the yard goes dark as a broken yard does.
	g.clock.skip(WorksState.KEEPER_DARK_AFTER + 1.0)
	await frames(2)
	check(works.call(&"broken", s.region), "the yard goes dark after its keeper")
	var st: WorksState = works.call(&"state", s.region)
	check(st.stripped, "and the plan's works in the yard are spent, as a broken yard's are")

	# Dark for good: across a save the yard, and why it went, come back.
	var back := WorksState.from_save(JSON.parse_string(JSON.stringify(st.save())))
	check(back.broken(), "a yard its keeper put dark comes back dark")
	check(back.by_keeper and back.keeper_fell_at != INF, "and knows it was the keeper")

	# The ground where it fell closes over, a day at a time, while it is watched.
	_stand(g, s.lair + Vector2(3.0, 0.0))
	var before := _tufts_near(g, s.lair, s.region)
	for i in 72:
		g.clock.skip(60.0)
		await frames(1)
	var after := _tufts_near(g, s.lair, s.region)
	gt(float(after), float(before), "three days on, the land has come back over where it fell")
	var again := after
	for i in 6:
		await frames(1)
	eq(_tufts_near(g, s.lair, s.region), again, "and nothing more is laid while no time passes")
	print("fall: fed %d dark, yard dark, %d -> %d tufts at the lair over 72 h" % [fed, before, after])
	await _end(g)


## Tufts round where it fell, and not the yard's own greening if the two are close.
func _tufts_near(g: Game, at: Vector2, region: int) -> int:
	var yard := Vector2.INF
	for site: WorksSite in g.get_node("34_works").get(&"sites"):
		if site.region == region:
			yard = site.pos
	var n := 0
	for q in g.query.props_near(at, Sentinels.GREEN_REACH + 1.0):
		if (q.kind == PropKind.BUSH or q.kind == PropKind.BONES) and q.pos.distance_to(yard) > Works.YARD + 1.0:
			n += 1
	return n


## A yard is out by its three housings or by its keeper, and a keeper only just
## fallen has not put it out yet.
func test_a_yard_is_out_by_its_housings_or_by_its_keeper() -> void:
	var st := WorksState.new()
	st.parts = [true, true, true]
	st.dark_at = 10.0
	check(st.broken(), "broken by hand")
	check(not st.by_keeper, "and not by its keeper")
	var fresh := WorksState.new()
	check(not fresh.broken(), "a yard nobody touched is lit")
	fresh.keeper_fell_at = 5.0
	check(not fresh.broken(), "a keeper just fallen has not put it dark yet")
	fresh.by_keeper = true
	check(fresh.broken(), "and once it has, the yard is out")
	eq(fresh.broken_count(), 0, "with not one housing opened")
