class_name BootStages
extends RefCounted
## An ordered list of slow start-up jobs that a page can run without freezing:
## with threads, each run of consecutive worker stages goes to the pool as one
## task while the page keeps drawing; without threads (the no-threads web build)
## every stage runs on the main thread, one per step(), so a frame is drawn
## between stages.
##
##   var s := BootStages.new()
##   s.add(&"world", "raising the land", 900.0, func() -> void: ...)        # worker-safe
##   s.add(&"game", "waking the systems", 300.0, func() -> void: ..., false) # main thread
##   s.add(&"near", "one chunk a step", 900.0, func() -> bool: return built_all, false)
##   while not s.step(threaded):
##       await get_tree().process_frame
##
## A main-thread stage whose job returns false runs again on the next step (a
## long job cut into frame-sized pieces); a worker stage runs once.
##
## Such a stage may carry a DEADLINE in milliseconds, and one that waits on
## anything outside the program must. A stage waiting for something that never
## comes is a loading page that never ends, and the player has no way to know the
## difference between that and a slow machine: measured on this laptop, two boots
## in five sat at 37 s against a normal 7 s, because an off-screen window stops
## being composited and `RenderingServer.frame_post_draw` stops firing. Past its
## deadline a stage is counted finished and `gave_up()` names it, so the line
## always ends and the log always says which stage was given up on.
##
## Weights are expected milliseconds: progress() eases through a running stage
## by its elapsed time against its weight (never past 90% of it), so the drawn
## line keeps moving through one long job and never runs ahead of the work.

class Stage:
	var id: StringName
	var label: String
	var weight: float
	var run: Callable
	var worker: bool
	var ms := -1.0
	## The longest single piece of this stage run on the main thread (a frame the page could not draw).
	var held_ms := 0.0
	## Milliseconds it may wait before it is counted finished anyway (0: for ever).
	var deadline := 0.0
	## It reached that deadline without saying it was done.
	var gave_up := false


var stages: Array[Stage] = []
## Where the line starts (0..1): a page that continues a line drawn before it
## (the web shell's download) never draws it going back.
var start_at := 0.0
## Index of the first stage not yet finished.
var next := 0
var _task := -1
## Stages [next, _task_end) are on the pool now.
var _task_end := 0
## When the current stage became current (usec; 0 before the first step). The
## line eases through a stage from here, so it never restarts and falls back.
var _started_usec := 0
var _task_done_count := 0
var _mutex := Mutex.new()


func add(id: StringName, label: String, weight: float, run: Callable, worker: bool = true,
		deadline: float = 0.0) -> void:
	var s := Stage.new()
	s.id = id
	s.label = label
	s.weight = maxf(1.0, weight)
	s.run = run
	s.worker = worker
	s.deadline = maxf(0.0, deadline)
	stages.append(s)


func done() -> bool:
	return next >= stages.size()


## Advance. `threaded`: worker stages may run on the pool. Returns done().
func step(threaded: bool) -> bool:
	if _task >= 0:
		_collect()
		if _task >= 0:
			return false
	if done():
		return true
	var s := stages[next]
	if threaded and s.worker:
		_task_end = next
		while _task_end < stages.size() and stages[_task_end].worker:
			_task_end += 1
		_task_done_count = 0
		if _started_usec == 0:
			_started_usec = Time.get_ticks_usec()
		var first := next
		var last := _task_end
		_task = WorkerThreadPool.add_task(func() -> void: _run_range(first, last), true, "boot stages")
		return false
	if _started_usec == 0:
		_started_usec = Time.get_ticks_usec()
	var t0 := Time.get_ticks_usec()
	var finished := _run_one(s)
	s.held_ms = maxf(s.held_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	if not finished and s.deadline > 0.0 \
			and (Time.get_ticks_usec() - _started_usec) / 1000.0 >= s.deadline:
		s.gave_up = true
		finished = true
	if finished:
		# On the main thread a stage's time is the wall time it was current,
		# frames between its pieces included.
		s.ms = (Time.get_ticks_usec() - _started_usec) / 1000.0
		next += 1
		_started_usec = Time.get_ticks_usec()
	return done()


## Block until a worker chain in flight has finished (before freeing its owner).
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		next = _task_end


## Run every stage now, on this thread (tools, tests, headless).
func run_all() -> void:
	while not step(false):
		pass


func _run_range(first: int, last: int) -> void:
	for i in range(first, last):
		_run_one(stages[i])
		_mutex.lock()
		_task_done_count += 1
		_started_usec = Time.get_ticks_usec()
		_mutex.unlock()


## Runs the job once; true when the stage is finished. `ms` sums every piece.
func _run_one(s: Stage) -> bool:
	var t0 := Time.get_ticks_usec()
	var r: Variant = s.run.call()
	s.ms = maxf(0.0, s.ms) + (Time.get_ticks_usec() - t0) / 1000.0
	return not (r is bool and r == false)


func _collect() -> void:
	if not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	next = _task_end


## The stage running now (or next), or null when done.
func current() -> Stage:
	var i := next
	if _task >= 0:
		_mutex.lock()
		i = next + _task_done_count
		_mutex.unlock()
	return stages[i] if i < stages.size() else null


## 0..1 by weight: finished stages, plus the running one eased by its time.
func progress() -> float:
	var total := 0.0
	for s in stages:
		total += s.weight
	if total <= 0.0:
		return 1.0
	var i := next
	var started := _started_usec
	if _task >= 0:
		_mutex.lock()
		i = next + _task_done_count
		started = _started_usec
		_mutex.unlock()
	var got := 0.0
	for k in mini(i, stages.size()):
		got += stages[k].weight
	if i < stages.size() and started > 0:
		var s := stages[i]
		var elapsed := (Time.get_ticks_usec() - started) / 1000.0
		got += s.weight * minf(0.9, elapsed / s.weight)
	return clampf(start_at + (1.0 - start_at) * got / total, 0.0, 1.0)


## Ids of stages that reached their deadline without finishing. Empty is the
## normal answer; anything in it is a start that went wrong and said so.
func gave_up() -> PackedStringArray:
	var out := PackedStringArray()
	for s in stages:
		if s.gave_up:
			out.append(String(s.id))
	return out


## Milliseconds of the longest main-thread piece of each stage that ran one, by id.
func held() -> Dictionary:
	var out := {}
	for s in stages:
		if s.held_ms > 0.0:
			out[s.id] = s.held_ms
	return out


## Milliseconds each finished stage took, by id, and the total.
func timings() -> Dictionary:
	var out := {}
	var total := 0.0
	for s in stages:
		if s.ms >= 0.0:
			out[s.id] = s.ms
			total += s.ms
	out[&"total"] = total
	return out
