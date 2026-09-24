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
	var seed_value := 90417
	var size := Tuning.WORLD_SIZE
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
