extends TestCase
## A VILLAGE THAT LOST SOMEBODY IS ONE SHORT (slice 1 step 6). The only sign he
## gets that the plan came while he was away: its people are drawn one fewer for
## each of them held, gone, lost or still on the road; one got back whole makes it
## whole again; one got back empty stands among them and never answers.

const Sx := preload("res://tests/save/save_fixture.gd")


func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## Walk away past where its people are dropped, and back into it, and let it fill.
func _visit(g: Game, v: int) -> void:
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	var folk := g.get_node("folk")
	_stand(g, at + Vector2(500.0, 0.0) if at.x < 1000.0 else at - Vector2(500.0, 0.0))
	for i in 600:
		await frames(1)
		if not (folk.get("_spawned") as Dictionary).has(v):
			break
	_stand(g, at)
	# Until it is streamed in (the folk's half-second look round) and every one of
	# its people queued has been built (a figure every other frame).
	for i in 600:
		await frames(1)
		if (folk.get("_spawned") as Dictionary).has(v) and (folk.get("queue") as Array).is_empty():
			break
	await frames(2)


func _drawn(g: Game, v: int) -> Array:
	var out: Array = []
	for f: Dictionary in g.get_node("folk").get("folk"):
		if int(f.get("village", -1)) == v:
			out.append(f)
	return out


func _silent(rows: Array) -> int:
	var n := 0
	for f: Dictionary in rows:
		if bool(f.get("silent", false)):
			n += 1
	return n


func test_a_village_is_drawn_one_short_for_each_it_lost_and_whole_again_for_each_back() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"])
	await frames(3)
	check(g.world.villages.size() > 0, "a village to stand in")
	var v := 0
	var name := str(g.world.villages[v].get("name", ""))
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	var region := g.world.region_at(floori(at.x), floori(at.y))
	var sys := g.get_node("45_taken")
	var taken: Taken = sys.get("taken")

	await _visit(g, v)
	var full := _drawn(g, v).size()
	gt(float(full), 1.0, "the village has its people")

	sys.call(&"took", -1, "", -1, name, region)
	await _visit(g, v)
	eq(_drawn(g, v).size(), full - 1, "one taken: one fewer at their doors")

	@warning_ignore("return_value_discarded")
	taken.free_region(region, g.clock.minutes)
	await _visit(g, v)
	eq(_drawn(g, v).size(), full, "got back whole: the village is whole again")
	eq(_silent(_drawn(g, v)), 0, "and everybody in it answers")

	var t: Taken.TakenPerson = taken.take(-1, "", -1, name, region, g.clock.minutes - (Taken.RUN_HOURS + 5.0) * 60.0)
	await _visit(g, v)
	eq(_drawn(g, v).size(), full - 1, "held again")
	@warning_ignore("return_value_discarded")
	taken.free_region(region, g.clock.minutes)
	check(t.empty, "out past the run")
	await _visit(g, v)
	var rows := _drawn(g, v)
	eq(rows.size(), full, "got back empty: they are there")
	eq(_silent(rows), 1, "and one of them never answers")

	var gone: Taken.TakenPerson = taken.take(-1, "", -1, name, region, g.clock.minutes - (Taken.GONE_HOURS + 5.0) * 60.0)
	@warning_ignore("return_value_discarded")
	taken.run_out(g.clock.minutes)
	check(gone.gone, "held past the last of it")
	await _visit(g, v)
	eq(_drawn(g, v).size(), full - 1, "gone: one short for good")
	Sx.end(g)
	await frames(1)
