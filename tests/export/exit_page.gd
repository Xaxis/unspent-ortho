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
	for i in 900:
		if page.scene != null and page.stages.done():
			break
		await process_frame
	print("exit page handed over: %s" % (page.scene != null))
	for i in 20:
		await process_frame
	quit()
