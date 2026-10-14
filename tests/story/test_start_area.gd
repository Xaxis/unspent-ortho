extends TestCase
## THE START IS CALM (StartArea; owner, 2026-10-13: "at the home coast or the
## initial area you start there just shouldn't be any enemies at the start of
## the game"). While the first steps are under way in a game that opened washed
## up, nothing comes out near the spawn: no roll, no worker on its round, no
## first meeting. Past the start area, or once the steps are done, or in a game
## booted straight into the world, the coast is as it always was.

const F := preload("res://tests/fight/fixture.gd")
const Sx := preload("res://tests/save/save_fixture.gd")


func _coast() -> Coast:
	var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
	sim.moment.minutes = 10.0 * 60.0
	var sp := Spawner.new()
	sp.rate = 0.0
	return Coast.new(sim, sp)


func test_a_calm_coast_puts_nothing_out() -> void:
	var c := _coast()
	c.calm = func(_at: Vector2) -> bool: return true
	for i in 6:
		c.sim.now = Coast.FIRST_MEETING_MS + 10.0 + i * 5000.0
		c.tick()
	eq(c.sim.mobs.size(), 0, "no worker on its round, no first meeting, nothing")
	c.calm = func(_at: Vector2) -> bool: return false
	c.sim.now += 5000.0
	c.tick()
	gt(float(c.sim.mobs.size()), 0.0, "and once it is not calm, the land is as it was")


func test_the_start_is_calm_only_while_the_first_steps_run_and_only_near_the_spawn() -> void:
	Story.forget()
	var g := Sx.game(tree, ["--seed=1", "--hour=10", "--weather=clear:0"])
	var guide := Sx.system(g, "58_guide")
	var spawn := g.world.spawn
	guide.call(&"_ask_steps")
	check(bool(guide.call(&"steps_on")), "the first steps are under way")
	check(not StartArea.calm(g, spawn), "a game booted straight into the world is not kept calm (a test, a shot, a tour)")
	Story.washed_up = true
	check(StartArea.calm(g, spawn), "a game that opened washed up is, at the spawn")
	check(StartArea.calm(g, spawn + Vector2(StartArea.REACH - 1.0, 0.0)), "and across the start area")
	check(not StartArea.calm(g, spawn + Vector2(StartArea.REACH + 1.0, 0.0)), "but not past it")
	var done: Dictionary = guide.get("steps_done")
	for s: Dictionary in FirstSteps.STEPS:
		done[s.key] = true
	guide.call(&"_ask_steps")
	check(not StartArea.calm(g, spawn), "nor once the first steps are done")
	Sx.end(g)
	Story.forget()


func test_washed_up_is_kept_with_the_game() -> void:
	Story.forget()
	Story.washed_up = true
	var d := Story.save_state()
	Story.forget()
	check(not Story.washed_up, "forgotten")
	Story.load_state(JSON.parse_string(JSON.stringify(d)))
	check(Story.washed_up, "and back with the save")
	Story.forget()
