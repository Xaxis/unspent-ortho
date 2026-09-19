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


func test_a_line_continued_from_the_shell_starts_where_it_left_off() -> void:
	var s := _stages([])
	s.start_at = 0.12
	near(s.progress(), 0.12, 0.0001, "before any stage, where the shell's download ended")
	var last := s.progress()
	while not s.step(false):
		check(s.progress() >= last, "never back")
		last = s.progress()
	eq(s.progress(), 1.0, "and full at the end")


func test_a_stage_that_waits_for_ever_is_given_up_on_at_its_deadline() -> void:
	# The loading page's failure mode: `draw` waits on a frame that never comes
	# (an off-screen window stops being composited), and before there were
	# deadlines the line simply never ended.
	# **THE CHEAPEST OF THREE, NOT ONE RUN TIMES `machine_slack`.** The overshoot
	# past a deadline IS load-sensitive -- the line polls, so a run descheduled
	# between two steps takes the deadline plus however long it was away -- which
	# is why slack was reached for. But slack is for WAITING and clamps at 8, so
	# this bar stood at 7,260 ms for an overshoot that measures under a TENTH of
	# a millisecond: a hundred-thousand-fold too loose to fail for a real reason.
	#
	# The line is cheap to rebuild, so run it three times and keep the fastest.
	# Load only ever ADDS time, so the minimum is the honest overshoot and the bar
	# can sit close to the deadline where it means something.
	var deadline := 60.0
	var tries := [0]
	var quickest := INF
	var s: BootStages = null
	for attempt in 3:
		tries[0] = 0
		s = BootStages.new()
		s.add(&"never", "waiting", 10.0, func() -> bool:
			tries[0] += 1
			return false, false, deadline)
		s.add(&"after", "after", 10.0, func() -> void: pass, false)
		var t0 := Time.get_ticks_msec()
		var guard := 0
		while not s.step(false) and guard < 100000:
			guard += 1
		quickest = minf(quickest, float(Time.get_ticks_msec() - t0))
		check(s.done(), "the line reaches its end even though a stage never finished")
		gt(float(tries[0]), 1.0, "and it really was asked more than once first")
	gt(quickest, deadline - 5.0, "it waited out its deadline")
	lt(quickest, deadline + 20.0, "and not much past it")
	eq(Array(s.gave_up()), ["never"], "which stage was given up on is on the record")
	check(s.timings().has(&"after"), "and the stages after it still ran")


func test_a_stage_that_finishes_in_time_is_never_given_up_on() -> void:
	var n := [0]
	var s := BootStages.new()
	s.add(&"soon", "soon", 10.0, func() -> bool:
		n[0] += 1
		return n[0] == 3, false, 5000.0)
	while not s.step(false):
		pass
	eq(Array(s.gave_up()), [], "nothing was given up on")
	eq(n[0], 3, "the job ran to its own end")


func test_the_loading_page_puts_a_deadline_on_everything_that_waits() -> void:
	# The rule, held on the page itself rather than on a copy of it: a main-thread
	# stage whose job returns a bool is a stage that WAITS, and every one of those
	# must carry a deadline or the page can hang on it.
	var page := BootPage.new()
	var o := BootOptions.new()
	page._plan(null, o, "game", true)
	var waiting := 0
	for st: BootStages.Stage in page.stages.stages:
		if st.worker:
			continue
		var r: Variant = st.run.get_method()
		# Only the repeating ones: a stage that returns nothing runs once and cannot wait.
		if st.id == &"start":
			continue
		waiting += 1
		gt(st.deadline, 0.0, "the page's %s stage waits with no deadline (%s)" % [st.id, r])
	gt(float(waiting), 2.0, "there are waiting stages to hold to the rule")
	page.free()


func test_held_reports_the_longest_main_thread_piece() -> void:
	var s := BootStages.new()
	var n := [0]
	s.add(&"slow", "slow", 10.0, func() -> bool:
		n[0] += 1
		OS.delay_msec(40 if n[0] == 2 else 5)
		return n[0] == 3, false)
	s.add(&"pool", "pool", 10.0, func() -> void: OS.delay_msec(30))
	while not s.step(true):
		OS.delay_msec(1)
	var held := s.held()
	check(held.has(&"slow"), "a main-thread stage reports how long it held the page")
	gt(float(held.get(&"slow", 0.0)), 35.0, "its longest piece, not the sum or the first")
	lt(float(held.get(&"slow", 0.0)), 90.0)
	check(not held.has(&"pool"), "a stage on the pool never held the page")
