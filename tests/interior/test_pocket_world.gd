extends TestCase
## S0 of enterable structures (docs/interiors DESIGN.md): no feature, only the
## measurements the design rests on, in a running game.
##   M1  does a running game survive being pointed at a tiny hand-made world
##       (no villages, regions, rivers or landmarks), and what does raising and
##       entering one cost;
##   M2  what does coming back out cost: the outside re-grown by `rebind`, or
##       the outside's view set aside whole and put back.
## Each asserts what S1 needs to be true, and prints the numbers.

const Sx := preload("res://tests/save/save_fixture.gd")
const SIZE := 48
const RING := 8.0


func _realms(g: Game) -> Node:
	return Sx.system(g, "20_realms")


## A pocket: a flat floor of the outside's own landscape, one body of land.
func _pocket(outside: WorldData, land: int) -> WorldData:
	var w := WorldData.new(outside.seed_value, SIZE)
	for i in SIZE * SIZE:
		w.level[i] = 2
		w.ground[i] = Ground.FLOOR
		w.country[i] = land
		w.continent[i] = 1
	w.realm = outside.realm
	w.spawn = Vector2(SIZE * 0.5, SIZE * 0.5)
	return w


## A ring of walls round the middle, handed to the query as a package would.
func _walls(g: Game) -> void:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	var ring: Array[Vector3] = []
	for k in 64:
		var p := c + Vector2.from_angle(k * TAU / 64.0) * RING
		ring.append(Vector3(p.x, p.y, 0.6))
	g.query.set_blocks(&"pocket", ring)


## Frames of the running game, bounded in wall time (a probe error idles for
## ever): the worst frame, in ms, over `n`.
func _run(n: int) -> float:
	var worst := 0.0
	var until := Time.get_ticks_msec() + 20000
	var t := Time.get_ticks_usec()
	for i in n:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - t) / 1000.0)
		t = now
		if Time.get_ticks_msec() > until:
			break
	return worst


func _walk(g: Game, dir: Vector2, secs: float) -> void:
	g.scripted_move = dir
	g.scripted_run = false
	g.scripted_seconds = secs
	var until := Time.get_ticks_msec() + int(secs * 1000.0) + 4000
	while g.scripted_seconds > 0.0 and Time.get_ticks_msec() < until:
		await tree.physics_frame


func _view_line(g: Game) -> String:
	return "built %d chunks, %.1f ms on workers (worst %.1f), %.1f ms on the main thread (worst %.1f)" % [
		g.view.build_count, g.view.build_ms, g.view.build_ms_max, g.view.main_ms, g.view.main_ms_max]


func test_m1_m2_a_pocket_and_back_through_rebind() -> void:
	Sx.use_root("pocket-rebind")
	var g := Sx.game(tree, ["--seed=4", "--size=96", "--hour=11", "--weather=clear:0"])
	var r := _realms(g)
	var outside := g.world
	var stood := g.player.pos
	var depleted := outside.depleted.duplicate()
	var land := outside.country_at(floori(stood.x), floori(stood.y))
	await _run(30)
	# M1: raise and enter.
	var t0 := Time.get_ticks_usec()
	var pocket := _pocket(outside, land)
	var raise_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# The entry's cost in its three parts: the outside's view let go and bound
	# to the pocket, the pocket's near chunks grown, and the game pointed at it
	# (which, the view already drawing the pocket, rebinds nothing).
	t0 = Time.get_ticks_usec()
	g.view.rebind(pocket)
	var rebind_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	g.view.ensure_near(pocket.spawn)
	var near_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	r.call("enter", pocket, &"pocket:s0", pocket.spawn)
	var enter_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_walls(g)
	var in_worst := await _run(120)
	var in_view := _view_line(g)
	eq(g.world, pocket, "the game is in the pocket")
	eq(g.view.world, pocket, "and the view draws it")
	var before := g.player.pos
	await _walk(g, Vector2(1.0, 0.0), 1.0)
	gt(g.player.pos.distance_to(before), 1.0, "the player walks inside (%.2f tiles)" % g.player.pos.distance_to(before))
	await _walk(g, Vector2(1.0, 0.0), 4.0)
	lt(g.player.pos.distance_to(pocket.spawn), RING, "and the walls stop them (%.2f from the middle)" % g.player.pos.distance_to(pocket.spawn))
	# M2: back out, through rebind.
	t0 = Time.get_ticks_usec()
	r.call("enter", outside, &"surface", stood)
	var exit_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var out_worst := await _run(120)
	var out_view := _view_line(g)
	check(g.world == outside, "out onto the SAME outside world, not a new one")
	eq(g.world.depleted, depleted, "with what was taken from it intact")
	lt(g.player.pos.distance_to(stood), 0.5, "where the player stood")
	print("S0 M1 raise %.2f ms; entry: rebind %.1f ms + near chunks %.1f ms + point the game %.1f ms; worst frame inside %.1f ms; inside %s" % [raise_ms, rebind_ms, near_ms, enter_ms, in_worst, in_view])
	print("S0 M2 rebind: exit %.1f ms, worst frame after %.1f ms; after %s" % [exit_ms, out_worst, out_view])
	Sx.end(g)
	Sx.finish()


## The stand-in stash: the outside's view set aside whole and a view of its own
## for the pocket; coming out puts the old one back. A real stash keeps the same
## things in one view, so this bounds what the way out can cost with one.
func test_m2_back_out_with_the_outside_set_aside() -> void:
	Sx.use_root("pocket-stash")
	var g := Sx.game(tree, ["--seed=4", "--size=96", "--hour=11", "--weather=clear:0"])
	var r := _realms(g)
	var outside := g.world
	var stood := g.player.pos
	var land := outside.country_at(floori(stood.x), floori(stood.y))
	await _run(30)
	var kept := g.view
	var outside_chunks := (kept.get("_chunks") as Dictionary).size() + (kept.get("_parked") as Dictionary).size()
	var pocket := _pocket(outside, land)
	var t0 := Time.get_ticks_usec()
	g.remove_child(kept)
	var inner := WorldView.new()
	inner.setup(pocket)
	inner.name = "pocket_view"
	g.add_child(inner)
	g.view = inner
	r.call("enter", pocket, &"pocket:s0", pocket.spawn)
	var enter_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await _run(120)
	t0 = Time.get_ticks_usec()
	g.remove_child(inner)
	inner.queue_free()
	g.add_child(kept)
	g.view = kept
	r.call("enter", outside, &"surface", stood)
	var exit_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var builds_before := kept.build_count
	var out_worst := await _run(120)
	check(g.world == outside and g.view == kept, "out onto the same world, drawn by the same view")
	eq(kept.build_count - builds_before, 0, "and the way out built nothing: the outside was kept")
	print("S0 M2 set aside: enter (with a view of its own) %.1f ms, exit %.2f ms, worst frame after %.1f ms, %d outside chunks kept, %d built after" % [
		enter_ms, exit_ms, out_worst, outside_chunks, kept.build_count - builds_before])
	Sx.end(g)
	Sx.finish()
