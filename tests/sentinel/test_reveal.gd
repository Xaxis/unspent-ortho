extends TestCase
## THE REVEAL AND THE FALL, the fight's side (44_sentinels `_begin_reveal`,
## `_stage`; roadmap slice 1 step 4): the first time a keeper is put out it
## stands at its work, not noticing the player, for REVEAL_S, and a reveal is
## staged once; met again it is not. Its fall stages a beat where it falls. The
## camera beat itself is the shared staging API's (slice 1b-ii).

const Sx := preload("res://tests/save/save_fixture.gd")


## Physics frames: 44_sentinels puts a keeper out on its physics step, and a
## fast box runs several process frames to one of those, so "3 frames" could pass
## with nothing stepped ("it is out again" failed on one box and not another).
func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _put(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.pos = p
	g.player.position = g.world.to_3d(p)
	g.player.sync_view(0.0)


func _count(sys: Node, what: StringName) -> int:
	var n := 0
	for b: Dictionary in sys.call(&"staged"):
		n += int(b.what == what)
	return n


func test_the_first_sight_is_staged_once_and_the_fall_too() -> void:
	Sx.use_root("reveal")
	var g := Sx.game(tree, ["--seed=7", "--hour=11", "--weather=clear:0"])
	var sys := Sx.system(g, "44_sentinels")
	var reaper: SentinelState = null
	for s: SentinelState in sys.call(&"states"):
		if s.land == &"coast" and not s.fallen and s.region >= 0:
			reaper = s
			break
	check(reaper != null, "seed 7 holds a reaper")
	if reaper == null:
		Sx.end(g)
		return
	var at := Vector2.INF
	for k in 16:
		var p := reaper.lair + Vector2.from_angle(TAU * k / 16.0) * 12.0
		if g.query.standable(floori(p.x), floori(p.y)):
			at = p
			break
	_put(g, at)
	await _frames(3)
	eq(_count(sys, &"reveal"), 1, "its first sight is staged")
	check(bool(sys.call(&"revealing")), "and stands")
	var m: MobState = reaper.body
	check(m != null and (m.mood == MobState.IDLE or m.mood == MobState.WORKING), "it stands at its work, not on the player (%s)" % (m.mood if m != null else &"none"))
	var t0 := Time.get_ticks_msec()
	while bool(sys.call(&"revealing")) and Time.get_ticks_msec() - t0 < 8000:
		await _frames(1)
	check(not bool(sys.call(&"revealing")), "and it is over")
	# Met again: taken in, and come back to.
	g.player.sim.remove_mob(reaper.body)
	reaper.body = null
	await _frames(3)
	eq(_count(sys, &"reveal"), 1, "a keeper met again is not revealed again")
	# Its fall is staged where it falls.
	var body: MobState = reaper.body
	check(body != null, "it is out again")
	if body != null:
		g.player.sim._kill(body, true)
		await _frames(4)
		eq(_count(sys, &"fall"), 1, "its fall is staged")
	Sx.end(g)


## While the staged look holds the player's keys for its first sight (42_stage:
## the turn in, the hold, the turn back), the keeper holds off too. Calm for
## REVEAL_S alone, it woke 1.2 s before the keys came back and ran its first bite
## at a player who could not move (tours/reaper_force.tour, seed 1).
func test_it_holds_off_for_as_long_as_the_look_holds_the_keys() -> void:
	Sx.use_root("reveal-keys")
	var g := Sx.game(tree, ["--seed=7", "--hour=11", "--weather=clear:0"])
	var sys := Sx.system(g, "44_sentinels")
	var stage := tree.get_first_node_in_group(&"stage")
	var reaper: SentinelState = null
	for s: SentinelState in sys.call(&"states"):
		if s.land == &"coast" and not s.fallen and s.region >= 0:
			reaper = s
			break
	check(reaper != null and stage != null, "seed 7 holds a reaper, and the game its stage")
	if reaper == null or stage == null:
		Sx.end(g)
		return
	var at := Vector2.INF
	for k in 16:
		var p := reaper.lair + Vector2.from_angle(TAU * k / 16.0) * 8.0
		if g.query.standable(floori(p.x), floori(p.y)):
			at = p
			break
	_put(g, at)
	await _frames(3)
	check(bool(stage.call(&"looking")) and StringName(stage.call(&"why")) == &"reveal", "its first sight holds the keys")
	var sim: FightSim = g.player.sim
	var woke_under_it := 0
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while bool(stage.call(&"looking")) and Time.get_ticks_msec() - t0 < 10000:
		var m: MobState = reaper.body
		if m != null and (sim.now >= m.calm_until or m.roused()):
			woke_under_it += 1
		frames += 1
		await tree.physics_frame
	check(not bool(stage.call(&"looking")), "and hands them back")
	eq(woke_under_it, 0, "it never woke while the keys were held (%d of %d frames)" % [woke_under_it, frames])
	Sx.end(g)
