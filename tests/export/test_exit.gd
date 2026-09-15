extends TestCase
## Quitting releases the game. Every run through the boot code (a shot, a tour,
## the Mac app, the title's New game) once ended with ~110 scripts, their static
## materials and meshes, and GL RIDs reported as leaks, which buried real ones in
## every tool's output. Each case runs the real entry in a child process and reads
## its exit report. A handful of small objects is the engine's own (main has 7-15).

const MAX_OBJECTS := 40


func _run(args: PackedStringArray) -> String:
	var out := []
	OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")]) + args, out, true)
	return "\n".join(PackedStringArray(out))


func _check_clean(log: String, what: String) -> void:
	check(not log.contains("still in use at exit"), "%s: no resource left in use at exit (%s)" % [what, _leak_lines(log)])
	check(not log.contains("RID allocations"), "%s: no RIDs leaked at exit" % what)
	var m := RegEx.create_from_string("(\\d+) ObjectDB instances were leaked").search(log)
	var objects := m.get_string(1).to_int() if m != null else 0
	lt(float(objects), float(MAX_OBJECTS), "%s: %d objects leaked at exit" % [what, objects])


func _leak_lines(log: String) -> String:
	var lines := PackedStringArray()
	for l in log.split("\n"):
		if l.contains("leaked") or l.contains("still in use"):
			lines.append(l.strip_edges())
	return "; ".join(lines).left(300)


func test_a_game_started_the_way_shots_and_headless_runs_start_it_exits_clean() -> void:
	var log := _run(["--quit-after", "20", "--", "--seed=1", "--size=64", "--scene=game"])
	check(log.contains("world 1 gen"), "the game ran (%s)" % log.right(300))
	_check_clean(log, "game")


func test_a_game_made_by_the_loading_page_exits_clean() -> void:
	for mode: String in ["threads", "nothreads"]:
		var log := _run(["-s", "res://tests/export/exit_page.gd", "--", mode])
		check(log.contains("exit page handed over: true"), "%s: the page handed over (%s)" % [mode, log.right(300)])
		_check_clean(log, "page, %s" % mode)
