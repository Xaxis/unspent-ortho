extends SceneTree
## A child process for test_exit.gd: a game made through the loading page's
## stages (threads or not, as the first user argument says), run to its hand-over
## and a few frames on, then quit, so its exit report can be read.
##   godot --headless --path . -s tests/export/exit_page.gd -- threads|nothreads


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node.new()
	root.add_child(holder)
	var page := BootPage.new()
	page._plan(holder, BootOptions.parse(["--seed=4", "--size=64"]), "game", OS.get_cmdline_user_args().has("threads"))
	holder.add_child(page)
	# Wait on real time, not on a frame count. A headless loop runs frames as
	# fast as the machine allows, so with THREADS on — where the work is off the
	# main thread — 900 frames go by in a couple of seconds while the worker is
	# still making the world, and a hand-over that is simply late reads as one
	# that never came. The nothreads case did the work between the frames and so
	# always passed, which is why only "threads" failed. Scaled like every other
	# wall-clock budget in the tests, and kept inside the parent's own bound.
	var until := Time.get_ticks_msec() + int(20000.0 * minf(TestCase.machine_slack(), 4.0))
	while Time.get_ticks_msec() < until:
		if page.scene != null and page.stages.done():
			break
		await process_frame
	print("exit page handed over: %s" % (page.scene != null))
	for i in 20:
		await process_frame
	quit()
