extends TestCase
## WE BREAK THEIR WORKS, THEY BURN A VILLAGE, in a real game and by the player's
## own hands: a housing opened with a steel edge under the held key puts the
## yard's hunters on the road to the nearest roof, and ninety minutes on the
## houses there have burned; put the whole yard dark before then and nothing does.


func _game() -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0",
		"--place=works", "--held=axe_felling"])))
	return g


func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## Hold `use` at housing `i` until it opens, as a player does.
func _open(g: Game, site: WorksSite, i: int) -> bool:
	var works := g.get_node("34_works")
	# Where housing `i` is the one under the hand, as 49_story's `_at_housing`
	# finds it for a tour: a tile to stand on, in the housing's reach, with no
	# other workable thing nearer (a bush there takes the key instead).
	var at := Vector2.INF
	var part := site.part(i)
	for r: float in [0.8, 1.2, 1.6, 2.0]:
		for k in 12:
			var p := part + Vector2.from_angle(TAU * float(k) / 12.0) * r
			if not g.query.standable(floori(p.x), floori(p.y)):
				continue
			var stand := Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
			var clear := stand.distance_to(part) <= Works.PART_REACH and Works.part_near(site, stand) == i
			for q in g.query.props_near(stand, 4.0):
				if clear and Takes.workable(q.kind) and not g.world.depleted.has(q.id) \
						and q.pos.distance_to(stand) < part.distance_to(stand):
					clear = false
			if clear:
				at = stand
				break
		if at.is_finite():
			break
	if not at.is_finite():
		return false
	_stand(g, at)
	await frames(2)
	works.call(&"tour_forget", &"works_part")
	Input.action_press(&"use")
	var got := false
	for f in 400:
		await frames(1)
		if works.call(&"tour_seen", "works_part"):
			got = true
			break
	Input.action_release(&"use")
	return got


func _raids(g: Game) -> Node:
	return g.get_node("48_raids")


func test_a_housing_opened_burns_the_nearest_roof_ninety_minutes_on() -> void:
	var g := _game()
	await frames(4)
	var site: WorksSite = g.get_node("34_works").call(&"here")
	check(site != null, "the player stands on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var roof := Reprisal.nearest_roof(g.query.props_near(site.pos, Reprisal.REACH), site.pos)
	check(roof.is_finite(), "a roof inside the hunters' reach of this yard")
	check(await _open(g, site, 0), "a housing came open under the held key and a steel edge")
	var raids := _raids(g)
	var r: Reprisal = raids.get("reprisal")
	check(r.marching.has(site.region), "and the yard's hunters are on the road")
	eq((raids.get("burned") as Dictionary).size(), 0, "nothing has burned yet")
	g.clock.skip(Reprisal.MARCH_MINUTES + 1.0)
	raids.call(&"sweep")
	var burned: Dictionary = raids.get("burned")
	gt(float(burned.size()), 0.0, "ninety minutes on, the houses at the nearest roof have burned")
	for id: int in burned:
		var house := g.world.prop(id)
		lt(house.pos.distance_to(roof), raids.get("BURN_REACH") + 0.01, "each of them at that roof")
		check(g.world.depleted.has(id), "the house is gone")
		var shell := false
		for q in g.query.props_near(house.pos, 0.5):
			if q.kind == PropKind.HOUSE_BURNT and q.pos == house.pos and is_equal_approx(q.rot, house.rot):
				shell = true
		check(shell, "and its burnt shell stands in its place, turned as it was")
	g.queue_free()
	await frames(1)


## THE VILLAGE COUNTS ONE SHORT: the roofs the hunters burned stand in it as
## shells, and its people come out one fewer than they did the day before, the
## count 35_folk keeps for each it lost (step 6), not a house's worth each.
func test_a_burned_village_comes_out_one_short() -> void:
	var g := _game()
	await frames(4)
	var site: WorksSite = g.get_node("34_works").call(&"here")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var roof := Reprisal.nearest_roof(g.query.props_near(site.pos, Reprisal.REACH), site.pos)
	var village := -1
	for i in g.world.villages.size():
		var vp: Vector2 = g.world.villages[i].get("pos", Vector2.INF)
		if vp.distance_to(roof) < 12.0 and (village < 0 or vp.distance_to(roof) < (g.world.villages[village].pos as Vector2).distance_to(roof)):
			village = i
	check(village >= 0, "the roof is a village's")
	if village < 0:
		g.queue_free()
		await frames(1)
		return
	var folk := g.get_node("folk")
	var centre: Vector2 = g.world.villages[village].pos
	var queue: Array = folk.get("queue")
	queue.clear()
	folk.call(&"_populate", village, centre)
	var before := queue.size()
	var doors_before: Array[Vector2] = []
	for r: Dictionary in queue:
		doors_before.append(r.door)
	check(await _open(g, site, 0), "a housing opened")
	g.clock.skip(Reprisal.MARCH_MINUTES + 1.0)
	_raids(g).call(&"sweep")
	gt(float((_raids(g).get("burned") as Dictionary).size()), 0.0, "the roofs burned")
	queue.clear()
	folk.call(&"_populate", village, centre)
	eq(queue.size(), before - 1, "and the village comes out one short")
	# Burn the rest of it: every door the village used the day before is gone,
	# and nobody goes in at a shell.
	var houses: Array[WorldProp] = []
	for q in g.query.props_near(centre, 12.0):
		if q.kind == PropKind.HOUSE and not g.world.depleted.has(q.id):
			houses.append(q)
	var rooms_before := 0
	for t: Threshold in g.get_node("21_doors").get("doors"):
		for h in houses:
			if t.host_code == PropKind.HOUSE and t.host == h.pos:
				rooms_before += 1
	gt(float(rooms_before), 0.0, "the day before, its houses had rooms to go into")
	for h in houses:
		_raids(g).call(&"_burn", h)
	var rooms := g.get_node("21_doors")
	var ways_in := func() -> int:
		var n := 0
		for t: Threshold in rooms.get("doors"):
			for h in houses:
				if t.host_code == PropKind.HOUSE and t.host == h.pos:
					n += 1
		return n
	# The burning is the raid's, so the doors hear of it as they would.
	Events.village_burned.emit(centre)
	eq(ways_in.call(), 0, "and no burned house has a way into its rooms")
	var went_in := 0
	for d in doors_before:
		for h in houses:
			if d.distance_to(h.pos) <= h.solid + 0.35:
				went_in += 1
	gt(float(went_in), 0.0, "the day before, people went in at those doors")
	queue.clear()
	folk.call(&"_populate", village, centre)
	for r: Dictionary in queue:
		for h in houses:
			check((r.door as Vector2).distance_to(h.pos) > h.solid + 0.35, "nobody goes in at a burned door")
	g.queue_free()
	await frames(1)


func test_a_yard_put_dark_in_time_burns_nothing() -> void:
	var g := _game()
	await frames(4)
	var site: WorksSite = g.get_node("34_works").call(&"here")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	for i in Works.PART_NAMES.size():
		check(await _open(g, site, i), "housing %d opened" % i)
	var raids := _raids(g)
	check(not (raids.get("reprisal") as Reprisal).marching.has(site.region), "the yard is dark: its hunters are called back")
	g.clock.skip(Reprisal.MARCH_MINUTES + 1.0)
	raids.call(&"sweep")
	eq((raids.get("burned") as Dictionary).size(), 0, "and nothing burns")
	g.queue_free()
	await frames(1)


## The machines of the road party near where the march is now: raiders out on
## their errand, alive.
func _on_the_road(g: Game, at: Vector2) -> Array[MobState]:
	var out: Array[MobState] = []
	for m in g.player.sim.mobs:
		if m.alive and not m.removed and m.raider and m.pos.distance_to(at) < 12.0:
			out.append(m)
	return out


## OUT ON THE ROAD, where he can meet them: near where the march has got to, the
## yard's hunters are there to be seen walking to the roof; met and put down, the
## march is over and nothing burns. Walked away from, they go back on paper and
## the roof burns when it was due.
func test_the_hunters_are_on_the_road_and_met_there_nothing_burns() -> void:
	var g := _game()
	await frames(4)
	var site: WorksSite = g.get_node("34_works").call(&"here")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	check(await _open(g, site, 0), "a housing opened")
	var raids := _raids(g)
	var r: Reprisal = raids.get("reprisal")
	g.clock.skip(Reprisal.MARCH_MINUTES * 0.4)
	var at := r.on_road(site.region, g.clock.minutes)
	_stand(g, at + Vector2(6, 0))
	await frames(2)
	raids.call(&"sweep")
	await frames(2)
	var party := _on_the_road(g, r.on_road(site.region, g.clock.minutes))
	gt(float(party.size()), 0.0, "the yard's hunters are on the road where he stands")
	for m in party:
		check(m.line_b.distance_to(r.on_road(site.region, g.clock.minutes)) < 1.0 or m.line_b.distance_to(r.marching[site.region].roof) < 1.0,
			"walking the road to the roof")
		var hits := 0
		while m.alive and hits < 200:
			# From behind, a frame apart: a body's hurt frames take one blow at a time.
			@warning_ignore("return_value_discarded")
			g.player.sim.strike(m, Blow.for_item(&"axe_felling"), m.pos + Vector2.from_angle(m.facing + PI) * 1.2)
			hits += 1
			await frames(2)
		check(not m.alive, "put down on the road")
	await frames(2)
	for m in party:
		var wreck := false
		for q in g.query.props_near(m.pos, 2.0):
			if q.kind == PropKind.WRECKAGE and q.pos.distance_to(m.pos) < 0.5:
				wreck = true
		check(wreck, "and what he put down lies on the road where it fell")
	raids.call(&"sweep")
	check(not r.marching.has(site.region), "met on the road, the march is over")
	g.clock.skip(Reprisal.MARCH_MINUTES)
	raids.call(&"sweep")
	eq((raids.get("burned") as Dictionary).size(), 0, "and nothing burns")
	g.queue_free()
	await frames(1)


func test_walked_away_from_they_go_on_paper_and_the_roof_burns() -> void:
	var g := _game()
	await frames(4)
	var site: WorksSite = g.get_node("34_works").call(&"here")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	check(await _open(g, site, 0), "a housing opened")
	var raids := _raids(g)
	var r: Reprisal = raids.get("reprisal")
	g.clock.skip(Reprisal.MARCH_MINUTES * 0.4)
	var at := r.on_road(site.region, g.clock.minutes)
	_stand(g, at + Vector2(6, 0))
	await frames(2)
	raids.call(&"sweep")
	gt(float(_on_the_road(g, at).size()), 0.0, "on the road while he is by")
	# Off to the far side of the coast from them.
	var size := float(g.world.size)
	var away := Vector2(size - at.x, size - at.y)
	gt(away.distance_to(at), float(raids.get("ROAD_SEEN")) * 1.5, "somewhere well away from the road")
	_stand(g, away)
	g.clock.skip(1.0)
	await frames(2)
	raids.call(&"sweep")
	eq(_on_the_road(g, r.on_road(site.region, g.clock.minutes)).size(), 0, "gone from the land once he is far from them")
	check(r.marching.has(site.region), "but still marching")
	g.clock.skip(Reprisal.MARCH_MINUTES)
	raids.call(&"sweep")
	gt(float((raids.get("burned") as Dictionary).size()), 0.0, "and the roof burns when it was due")
	g.queue_free()
	await frames(1)
