extends TestCase
## BootStages: the loading page's jobs run in order, report progress that only
## ever rises to 1, run one per step without threads, repeat a main-thread job
## that says it is not finished, and chain worker jobs on the pool.


func _stages(log: Array) -> BootStages:
	var s := BootStages.new()
	s.add(&"a", "first", 100.0, func() -> void: log.append("a"))
	s.add(&"b", "second", 300.0, func() -> void: log.append("b"))
	var left := [3]
	s.add(&"c", "third, in pieces", 200.0, func() -> bool:
		log.append("c")
		left[0] -= 1
		return left[0] == 0, false)
	s.add(&"d", "fourth", 400.0, func() -> void: log.append("d"), false)
	return s


func test_without_threads_one_piece_runs_per_step() -> void:
	var log := []
	var s := _stages(log)
	eq(s.progress(), 0.0, "nothing done")
	eq(s.current().id, &"a")
	var steps := 0
	var seen: Array[float] = [s.progress()]
	while not s.step(false):
		steps += 1
		eq(log.size(), steps, "exactly one job per step")
		seen.append(s.progress())
		check(steps < 20, "finishes")
		if steps >= 20:
			break
	eq(log, ["a", "b", "c", "c", "c", "d"], "in order, the piecewise job three times")
	eq(s.progress(), 1.0, "all done")
	check(s.done())
	check(s.current() == null)
	for i in range(1, seen.size()):
		check(seen[i] >= seen[i - 1], "progress never falls (%f then %f)" % [seen[i - 1], seen[i]])
	var t := s.timings()
	for id: StringName in [&"a", &"b", &"c", &"d", &"total"]:
		check(t.has(id), "a timing for %s" % id)


func test_progress_counts_weights_and_eases_through_a_running_stage() -> void:
	var s := BootStages.new()
	s.add(&"light", "light", 100.0, func() -> void: pass, false)
	s.add(&"heavy", "heavy", 300.0, func() -> void: pass, false)
	s.step(false)
	near(s.progress(), 0.25, 0.05, "the first quarter by weight, the second barely begun")
	OS.delay_msec(120)
	var eased := s.progress()
	gt(eased, 0.25, "a running stage moves the line by its time")
	lt(eased, 0.25 + 0.75 * 0.9 + 0.001, "but never past 90% of itself")


func test_with_threads_worker_stages_run_on_the_pool_then_main_ones() -> void:
	var log := []
	var mutex := Mutex.new()
	var threads := []
	var s := BootStages.new()
	for id: StringName in [&"w1", &"w2"]:
		s.add(id, String(id), 50.0, func() -> void:
			OS.delay_msec(30)
			mutex.lock()
			log.append(String(id))
			threads.append(OS.get_thread_caller_id())
			mutex.unlock())
	s.add(&"m", "main", 50.0, func() -> void:
		log.append("m")
		threads.append(OS.get_thread_caller_id()), false)
	check(not s.step(true), "the worker chain starts and the page keeps drawing")
	eq(s.current().id, &"w1")
	var guard := 0
	while not s.step(true) and guard < 400:
		OS.delay_msec(5)
		guard += 1
	check(s.done(), "all stages finish")
	eq(log, ["w1", "w2", "m"])
	check(threads[0] != OS.get_main_thread_id(), "worker stages ran off the main thread")
	eq(threads[2], OS.get_main_thread_id(), "the main stage ran on the main thread")


func test_wait_finishes_a_chain_in_flight() -> void:
	var ran := [false]
	var s := BootStages.new()
	s.add(&"w", "w", 10.0, func() -> void:
		OS.delay_msec(40)
		ran[0] = true)
	s.step(true)
	s.wait()
	check(ran[0], "wait() blocks until the worker job is done")
	check(s.done())
