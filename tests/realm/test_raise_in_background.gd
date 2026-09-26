extends TestCase
## A realm raised behind a running game leaves the worker pool to the game.
##
## 20_realms starts raising the realms behind this world's shafts three frames
## into play, and a world is twenty seconds of generation. It was one pool task
## whose stages each fan out over EVERY worker at high priority
## (`GenFields.parallel`), so for those twenty seconds anything else the game or
## the engine put on the pool queued behind world generation: chunks, sounds,
## and the engine's own shader work, which the renderer waits on inside the
## draw. Measured on seed 7 with the camera over the shoulder: one frame of
## 4.6-5.2 s in 14 of 17 runs, three of about 380 ms before it, and p95 twice
## what it was with the raise switched off (perf/stutters).
##
## So a background raise is a group of one: `GenFields.parallel` runs inline
## inside a group, which is the path a four-thread machine already takes, so the
## world is the same world and it takes one worker instead of all of them.

const SLEEP_MS := 40


func test_the_pool_answers_while_a_realm_is_raised() -> void:
	RealmWorlds.forget()
	RealmWorlds.settle()
	var seed_value := 90417
	var size := 1024
	eq(RealmWorlds.begin(seed_value, size, &"underground"), false, "the raise is started, not done")
	# Let it get into its stages.
	OS.delay_msec(1500)
	# What a game and its engine ask of the pool while it plays: short jobs, at
	# low priority (a chunk, a sound, a mid model) and at high (the renderer's
	# own shader work, which the draw waits on). Asked again and again for as
	# long as the raise runs, so the stage that holds the pool longest is met.
	var worst := 0
	var worst_hi := 0
	var until := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < until and not RealmWorlds.ready(seed_value, size, &"underground"):
		var began := Time.get_ticks_msec()
		var t := WorkerThreadPool.add_task(func() -> void: OS.delay_msec(SLEEP_MS), false, "game work")
		WorkerThreadPool.wait_for_task_completion(t)
		worst = maxi(worst, Time.get_ticks_msec() - began)
		began = Time.get_ticks_msec()
		t = WorkerThreadPool.add_task(func() -> void: OS.delay_msec(SLEEP_MS), true, "game work")
		WorkerThreadPool.wait_for_task_completion(t)
		worst_hi = maxi(worst_hi, Time.get_ticks_msec() - began)
	lt(worst, 1000, "a low-priority job waits at worst %d ms behind a realm being raised" % worst)
	lt(worst_hi, 1000, "a high-priority job waits at worst %d ms behind a realm being raised" % worst_hi)
	# And the world raised this way is a world.
	var w := RealmWorlds.take(seed_value, size, &"underground")
	check(w != null and w.size == size, "the raise finishes and hands its world over")
	RealmWorlds.forget()


## A GAME THAT ENDS DOES NOT WAIT FOR ITS REALMS. `forget` used to wait out any
## raise still running, and a raise is a whole world on one worker, so every game
## shut down a few frames in paid for one: 34 s here, and enough across the suite
## to run the CI gate past 45 minutes. It lets go now, and throws the world away.
func test_a_game_that_ends_does_not_wait_for_its_realms() -> void:
	RealmWorlds.forget()
	RealmWorlds.settle()
	var seed_value := 90418
	var size := 1024
	RealmWorlds.begin(seed_value, size, &"underground")
	OS.delay_msec(300)
	var t := Time.get_ticks_msec()
	RealmWorlds.forget()
	var ms := Time.get_ticks_msec() - t
	lt(float(ms), 200.0, "forget lets go of a raise in flight (%d ms)" % ms)
	check(not RealmWorlds.ready(seed_value, size, &"underground"), "and keeps nothing it made")
	eq(RealmWorlds.begin(seed_value + 1, size, &"underground"), false, "a new raise waits while the old one holds its worker")
	RealmWorlds.settle()
	check(not RealmWorlds.ready(seed_value, size, &"underground"), "the abandoned world is thrown away when it finishes")
	RealmWorlds.forget()
	RealmWorlds.settle()


## AN ABANDONED RAISE STOPS, IT DOES NOT RUN ON. A process cannot exit while a
## worker is busy, so a game quit in the middle of a raise used to hang until a
## whole world was grown on one worker (minutes on the CI runner). `forget` asks
## the generation to stop at its next stage. Asked of the state, not the clock:
## a wall-clock bar was green here and red on a loaded runner for the same code.
func test_an_abandoned_raise_stops_early() -> void:
	RealmWorlds.forget()
	RealmWorlds.settle()
	# A generation told to stop stops after the stage it is in.
	var s := 90419
	WorldGen.halt(s, 256, &"underground")
	var cut := WorldGen.generate(s, 256, &"", &"underground")
	eq(cut.prop_count(), 0, "a halted generation stops before it lays anything")
	WorldGen.unhalt(s, 256, &"underground")
	var whole := WorldGen.generate(s, 256, &"", &"underground")
	gt(float(whole.prop_count()), 0.0, "and the same world grown after the stop is whole")
	# And `forget` is what tells an abandoned raise to stop, and the stop is let go
	# once that raise has ended.
	var seed_value := 90420
	var size := 1024
	var grown := Realm.seed_for(seed_value, &"underground")
	RealmWorlds.begin(seed_value, size, &"underground")
	RealmWorlds.forget()
	check(WorldGen.is_halted(grown, size, &"underground"), "forget asks the abandoned raise to stop")
	RealmWorlds.settle()
	check(not WorldGen.is_halted(grown, size, &"underground"), "and the stop does not outlive the raise")
	RealmWorlds.forget()
	RealmWorlds.settle()


## A PROCESS THAT ENDS CLAIMS ITS REALMS. A game lets go of its raise (above),
## but the process then came apart with that group task still in the pool, never
## claimed: `Pages in use exist at exit in PagedAllocator: WorkerThreadPool::Group`
## on every such run, and on a desktop run 2 in 5 hung for ever inside
## NSApplication terminate, every worker idle (seed 7, eye-level cost tour). The
## scene root halts it and waits it out as it leaves: 0 in 5, and no leaked group.
func test_a_process_that_ends_claims_every_realm_raise() -> void:
	RealmWorlds.forget()
	RealmWorlds.settle()
	RealmWorlds.begin(90421, 1024, &"underground")
	OS.delay_msec(300)
	# The game ends first (20_realms), letting go of its raise, then the root.
	RealmWorlds.forget()
	check(RealmWorlds._orphan_running(), "the game's raise is still running when it ends")
	var root := Node.new()
	root.set_script(load("res://src/main.gd"))
	root.call("_exit_tree")
	check(not RealmWorlds._orphan_running(), "no raise is left in the pool when the root has gone")
	root.free()
	RealmWorlds.forget()
	RealmWorlds.settle()
