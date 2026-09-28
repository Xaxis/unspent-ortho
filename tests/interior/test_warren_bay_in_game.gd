extends TestCase
## A BUCKLED BAY, WALKED AT BY THE REAL KEYS (container_warren.gd, COLLAPSE):
## inside a warren on seed 1 whose roof has buckled, a walk at the bay standing
## never gets under it, and the same walk crouched does. The hero steps with its
## crouched height while crouched (FightSim.HERO_CROUCH_TALL), which is what the
## query-level rule in test_container_warren cannot see.

const Sx := preload("res://tests/save/save_fixture.gd")


func _walk_at(g: Game, target: Vector2, frames_n: int) -> bool:
	var hero := g.player.sim.hero
	for i in frames_n:
		var d := target - hero.pos
		if d.length() < 0.05:
			break
		g.scripted_move = LockOn.keys_for(d.normalized(), g.camera.yaw_now(), g.player.pos, Vector2.INF, g.camera.shoulder)
		g.scripted_run = false
		g.scripted_seconds = 0.05
		await tree.physics_frame
		var t := Vector2i(floori(hero.pos.x), floori(hero.pos.y))
		if g.world.headroom_at(t.x, t.y) < FightSim.HERO_TALL:
			g.scripted_seconds = 0.0
			return true
	g.scripted_seconds = 0.0
	return false


func test_a_stand_is_stopped_at_the_bay_and_a_crouch_goes_under() -> void:
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	var doors: Node = Sx.system(g, "21_doors")
	var t: Threshold = null
	for th: Threshold in Interiors.thresholds(g.world):
		if th.kind != &"container_warren":
			continue
		for thing: Dictionary in InteriorGen.grow(g.options.seed_value, th).layout.things:
			if thing.kind == &"buckled":
				t = th
		if t != null:
			break
	check(t != null, "seed 1 has a warren with a buckled bay")
	if t == null:
		Sx.end(g)
		return
	await doors.call(&"go_in", t)
	var bay: Dictionary = {}
	for thing: Dictionary in (doors.get(&"pocket") as InteriorGen.Pocket).layout.things:
		if thing.kind == &"buckled":
			bay = thing
	var mid: Vector2 = bay.at
	var f: Vector2 = bay.face
	var start := mid + f * 2.5
	g.player.sim.hero.pos = start
	g.player.pos = start
	await frames(3)
	check(not await _walk_at(g, mid, 150), "standing, the walk never gets under the buckle")
	Input.action_press(&"crouch")
	await frames(3)
	check(g.body.crouched, "crouched")
	check(await _walk_at(g, mid, 150), "crouched, the same walk goes under it")
	Input.action_release(&"crouch")
	await frames(2)
	Sx.end(g)
