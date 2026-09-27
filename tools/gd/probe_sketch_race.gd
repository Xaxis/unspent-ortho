extends SceneTree
## THE SKETCH BAKE, COLD, ON EVERY WORKER AT ONCE: the one shape the pool crash
## has been seen in (src/ui/ui_sketch.gd `_plan`, and sound_bank.gd's header on
## the GDScript VM's lazily-resolved operators). A fresh process resolves one job
## per worker on the main thread, then lines the workers up behind a barrier so
## they all enter the cold bake in the same instant, and waits. One process is
## one throw of the dice; run it many times.
##
##   godot --headless --path . -s tools/gd/probe_sketch_race.gd -- [--workers=N] [--size=N]
##
## Prints "sketch race ok N" and quits 0; a crash is the process gone.

static var _gate := Mutex.new()
static var _arrived := 0


func _init() -> void:
	# Fewer than the pool has threads, or the barrier waits for a task the pool
	# has not started; and the spin gives up after a second either way.
	var workers := maxi(2, OS.get_processor_count() / 2)
	var size := 24
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--workers="):
			workers = a.trim_prefix("--workers=").to_int()
		elif a.begins_with("--size="):
			size = a.trim_prefix("--size=").to_int()
	var ids: Array[StringName] = []
	for id: StringName in Items.DEFS:
		ids.append(id)
		if ids.size() >= workers:
			break
	var jobs: Array[Dictionary] = []
	for id in ids:
		jobs.append(UiSketch._item_job(id, size))
	var tasks: Array[int] = []
	var n := jobs.size()
	for j in jobs:
		var job := j
		tasks.append(WorkerThreadPool.add_task(func() -> void:
			_gate.lock()
			_arrived += 1
			_gate.unlock()
			var here := 0
			var until := Time.get_ticks_msec() + 1000
			while here < n and Time.get_ticks_msec() < until:
				_gate.lock()
				here = _arrived
				_gate.unlock()
			var _img := UiSketch._bake(job)))
	for t in tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	print("sketch race ok %d" % n)
	quit(0)
