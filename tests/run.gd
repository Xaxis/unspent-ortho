extends SceneTree
## Headless test runner.
##   godot --headless --path . -s tests/run.gd [-- filter] [--shard=I/N]
##
## --shard=I/N runs shard I (0-based) of N, so the gate can run N processes side
## by side. Whole files stay together, so a file's cached worlds are built once,
## and each shard keeps the runner's own order. Which shard a file is in goes by
## its measured time (`shard_of`, tests/shard_times.txt); with no table, every
## Nth file from the Ith. Each file's time is printed as `file-time PATH MS`.
## Scripts under src are loaded in each.
##
## 1. Loads every script under res://src so a parse error anywhere fails the run,
##    even in a file no test touches.
## 2. Runs every test_* method of every tests/**/test_*.gd, optionally filtered by
##    a substring of "file:method".
## Exit code 0 only if everything loaded and every test passed.
##
## **A SCRIPT ERROR IS RED.** GDScript prints one and carries on, and the
## function it happened in just stops: a test that died half way returned with
## no failed assertion and printed "ok" over code that never ran. Every script
## error (tests/script_error_log.gd) raised while a test runs, its teardown
## included, fails that test; one raised while the scripts load is a load error.
## `tools/runner_red.sh` plants both and a control, and proves the runner red.

const ScriptErrorLog := preload("res://tests/script_error_log.gd")

var _script_errors: Logger = ScriptErrorLog.new()
var _failed := 0
## How many WorldProps one test may leave alive past its end. A grown world holds
## its props as rows and keeps a handful as objects (tests/stream/test_prop_table.gd);
## a test that keeps thousands is holding the world's props, and the file that
## noticed used to be some later one.
const LEAK_PROPS := 1000
var _passed := 0
var _load_errors := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	# The runner's own settings file, before anything reads one. Left on the
	# default, every test read the PLAYER's file: a test that made a game opened
	# at whatever zoom the owner last played at, and a night zoomed fully in
	# turned test_lock_lens red at 38 degrees on a tree nobody had touched.
	PlayerSettings.use_file(&"test")
	# Everything this runner writes, in a folder no other runner on the machine
	# shares (RunnerHome), taken away again at the end.
	RunnerHome.open()
	var filter := ""
	var shard := 0
	var shards := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shard="):
			var sp := a.trim_prefix("--shard=").split("/")
			shard = sp[0].to_int()
			shards = maxi(1, sp[1].to_int())
		elif a != "":
			filter = a
	var index := -1
	OS.add_logger(_script_errors)
	var tests: PackedStringArray = []
	for path in _find("res://tests", ".gd"):
		if path.get_file().begins_with("test_") and path.get_file() != "test_case.gd":
			tests.append(path)
	var times := read_times(TIMES)
	var shard_at := shard_of(tests, shards, times) if shards > 1 and not times.is_empty() else {}

	for path in _find("res://src", ".gd"):
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			_load_errors += 1
			printerr("LOAD FAIL ", path)
	for path in _find("res://src", ".gdshader"):
		if load(path) == null:
			_load_errors += 1
			printerr("LOAD FAIL ", path)

	for path in tests:
		_load_script_errors()
		index += 1
		if shard_at.is_empty() and index % shards != shard:
			continue
		if not shard_at.is_empty() and int(shard_at[path]) != shard:
			continue
		var script: GDScript = load(path)
		if script == null:
			_load_errors += 1
			printerr("LOAD FAIL ", path)
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var name: String = m.name
			if name.begins_with("test_") and not methods.has(name):
				methods.append(name)
		var file_t := Time.get_ticks_msec()
		var file_ran := 0
		for name in methods:
			var id := "%s:%s" % [path.get_file().get_basename(), name]
			# **A COMMA MEANS "ANY OF THESE", AND IT IS HOW AN ORDER-DEPENDENCE IS
			# AFFORDED ON A THIN BOX.** A leak only shows when the polluter and
			# the victim run in ONE process, and the only way to arrange that
			# used to be the whole suite — which on 2026-09-20 was killed by the
			# OS four times for memory, once a tenth of the way in. Naming the
			# suspect file and its victims keeps them in runner order, in one
			# process, for a fraction of the memory: `tools/test.sh
			# "test_player_settings,test_map,test_autosave"`. It proves nothing
			# about the rest of the set, which is the price.
			#
			# **A FILTER CHOOSES WHICH TESTS RUN, NEVER THE ORDER THEY RUN IN.**
			# The runner keeps its own traversal order whatever the filter says,
			# so naming the suspect first does not make it run first. An A/B built
			# on "the settings file immediately before its victims" was run that
			# way and had no power at all: measured off a full run's log, the two
			# victims sit at files 105 and 147 and the suspect at 161, so in both
			# arms the suspect ran AFTER them. Read the real order before building
			# an experiment on it — a full run's own log is the order, first
			# appearance of each file name.
			#
			# And the match is a substring over `basename:method`, so a file name
			# can pull in a method from ANOTHER file whose name contains it
			# ("test_map" also takes one out of test_screens). Do not read a
			# filtered count as a file count.
			if filter != "" and not _wanted(id, path, filter):
				continue
			file_ran += 1
			var inst: TestCase = script.new()
			inst.tree = self
			inst.current = id
			_load_script_errors()
			var t := Time.get_ticks_msec()
			var props_before := WorldProp.live
			await inst.call(name)
			# **A TEST MAY CLEAN UP AFTER ITSELF, AND NOW IT IS ASKED TO.** A file
			# that defines `teardown()` has it awaited after every test in it, and
			# after one that died of a script error too, because the runner goes on
			# past a failed call. There was no such hook, and `test_pointing`
			# wrote a `teardown()` that nothing called: its camera rigs stayed in
			# the root as the CURRENT camera for the rest of the process and the
			# crowd test behind it read a figure at the origin as off camera. A
			# teardown should `free()` rather than queue: the next test starts in
			# this same frame, before anything queued is gone.
			if inst.has_method(&"teardown"):
				await inst.call(&"teardown")
			# A TEST THAT BOOTS A GAME ENDS IT. One left in the root (`Sx.game`
			# with no `Sx.end`) keeps running its systems through every test after
			# it in the shard, and the one that fails is never the one that leaked:
			# a fight test's keeper and a pocket test have each gone red for a game
			# some earlier file booted. So the game is ended here and the test that
			# left it FAILS, by name. One only queued for freeing was ended; it is
			# freed now, because the next test starts in this same frame. Asked by
			# the script's name: naming the class here loads game.gd with the
			# runner, before what it needs is up (a LOAD FAIL on every run).
			for n: Node in get_root().get_children():
				var sc: Script = n.get_script()
				if sc != null and sc.get_global_name() == &"Game":
					if not n.is_queued_for_deletion():
						inst.failures.append("%s: left a game running (end it: Sx.end)" % id)
					get_root().remove_child(n)
					n.free()
			# NO TEST INHERITS ANOTHER'S SAVES. `SaveSlots.root` is a static, so a
			# test that points it at its own folder (`Sx.use_root`) and does not
			# call `Sx.finish` leaves every later test in the shard reading THAT
			# folder — with that test's save still in it. Nothing about the victim
			# looks wrong: `UiTitleMenu` simply finds a save, offers "continue",
			# selects it, and three title tests fail asserting "new" while passing
			# alone. That is docs/LOOK.md's whole chapter arriving as a red test
			# instead of a green one, and it has now bitten three times (#92, the
			# title menu; test_round_trip; these three), each time looking like a
			# different bug. The fixture already knew the rule — its own comment
			# says TEST_ROOT is "where tests outside tests/save read an empty set
			# of slots" — it was just left to every test to remember.
			#
			# `turned_away` goes with it: it is process-lived by design, so one
			# game's refusal would otherwise still be standing for the next test.
			SaveSlots.root = SaveSlots.TEST_ROOT
			SaveSlots.turned_away.clear()
			SaveSlots.handed_back = -1
			# NO TEST LEAVES A WORLD HALTED. A game that ends asks the raises it
			# began to stop (RealmWorlds.forget, WorldGen.halt), and a stop left
			# standing makes every later generation of that seed and size stop at
			# its first stage: a half-made world, the player at the map's middle
			# in the sea, and five tests in another file red while passing alone
			# (CI shard 1/8, 2026-09-30). An ended game's raises are waited out
			# here (they stop at their next stage); any stop still standing is the
			# test's, named, and lifted so the next test grows whole worlds.
			RealmWorlds.settle()
			for k: String in WorldGen.halted():
				inst.failures.append("%s: left a world halted (%s)" % [id, k])
				var parts := k.split(":")
				WorldGen.unhalt(parts[0].to_int(), parts[1].to_int(), StringName(parts[2]))
			var ms := Time.get_ticks_msec() - t
			# NO TEST KEEPS THE WORLD'S PROPS. What a test still holds goes with it
			# here, so whatever is alive past this point it put somewhere that lasts
			# (a static, a cache, a node left in the root). Counted on the test that
			# did it: before, the file that went red was a later one that asked how
			# many props a grown world keeps (32,028, 2026-10-03).
			var failures := inst.failures
			inst = null
			# A FINISHED COROUTINE'S FRAME OUTLIVES IT (Godot 4.7, measured): every
			# slot of the last test that awaited, a loop's array and every local,
			# stays alive until the next coroutine runs to its end. A test that
			# walked a world's props kept all of them into the tests after it, and
			# the one that went red was a later test that never awaited (32,028
			# props in test_prop_table, 2026-10-03). One empty coroutine run to its
			# end lets go of it before anything is counted or the next test starts.
			await _let_go_of_the_frame()
			var kept := WorldProp.live - props_before
			if kept > LEAK_PROPS:
				failures.append("%s: left %d WorldProps alive (keep rows, not objects)" % [id, kept])
			for e: String in _script_errors.call(&"take"):
				failures.append("%s: %s" % [id, e])
			if failures.is_empty():
				_passed += 1
				print("  ok   %s (%d ms)" % [id, ms])
			else:
				_failed += 1
				print("  FAIL %s (%d ms)" % [id, ms])
				for f in failures:
					print("       ", f)
		if file_ran > 0:
			print("file-time %s %d" % [path.trim_prefix("res://"), Time.get_ticks_msec() - file_t])
	_load_script_errors()
	var total := Time.get_ticks_msec() - t0
	print("\n%d passed, %d failed, %d load errors in %d ms" % [_passed, _failed, _load_errors, total])
	# A worker left in the pool when this quits (a sketch bake, the realm raise
	# every game lets go of as it ends) deadlocks the runner on GDScript's own lock
	# or kills it on freed memory, and the shard then prints nothing after its last
	# "ok": a red or cancelled gate with nothing to blame. The same drain the game's
	# root runs, so the two cannot drift apart (tools/runner_red.sh proves it).
	# By path, for the reason src/main.gd gives.
	# Each phase says it began, so a runner that never exits names where it stopped
	# in its own log (tools/check.sh prints the tail of a hung one).
	print("runner: draining the pool")
	(load("res://src/main.gd") as GDScript).call("drain_pool")
	print("runner: drained; quitting")
	RunnerHome.remove()
	quit(0 if _failed == 0 and _load_errors == 0 and _passed > 0 else 1)


## Each test file's measured seconds in the gate, all of it: its run in a shard,
## and its costs and played tests run again after the shard (tools/check.sh).
## `PATH SECONDS` lines, PATH from the project root; tools/shard-times.sh writes
## it from a gate's own log.
const TIMES := "res://tests/shard_times.txt"


## {path (res://): seconds} from a table of `PATH SECONDS` lines; {} with none.
static func read_times(file: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.size() == 2:
			out["res://" + parts[0]] = parts[1].to_float()
	return out


## WHICH SHARD EACH FILE RUNS IN: longest first onto the lightest shard (ties to
## the lowest), by `times`, a file not in it at the table's median. By index alone
## one added file reshuffled every shard and the slow played files clustered: on
## 1430cd50 the shards took 14 to 75 minutes against a step limit of 80.
## {path: shard}
static func shard_of(paths: PackedStringArray, shards: int, times: Dictionary) -> Dictionary:
	var known: Array[float] = []
	for p: String in paths:
		if times.has(p):
			known.append(float(times[p]))
	known.sort()
	var median := known[known.size() / 2] if not known.is_empty() else 1.0
	var weight := func(p: String) -> float: return float(times.get(p, median))
	var order: Array[String] = []
	order.assign(paths)
	order.sort_custom(func(a: String, b: String) -> bool:
		var wa: float = weight.call(a)
		var wb: float = weight.call(b)
		return wa > wb or (wa == wb and a < b))
	var loads: Array[float] = []
	loads.resize(shards)
	loads.fill(0.0)
	var out := {}
	for p: String in order:
		var best := 0
		for i in shards:
			if loads[i] < loads[best]:
				best = i
		out[p] = best
		loads[best] += weight.call(p)
	return out


## Script errors raised outside any test (loading scripts, making a test's
## instance): each is a load error, printed where it is counted.
## One empty coroutine run to its end, so the last one that ran lets go of its
## frame (the call says why).
func _let_go_of_the_frame() -> void:
	await process_frame


func _load_script_errors() -> void:
	for e: String in _script_errors.call(&"take"):
		_load_errors += 1
		printerr("LOAD FAIL ", e)


func _find(root: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(ext):
			out.append(root.path_join(f))
	for d in dir.get_directories():
		if not d.begins_with("."):
			out.append_array(_find(root.path_join(d), ext))
	return out


## Does this test match `filter`? One substring as it always was, or several
## separated by commas, where any one matching is enough. Blank parts are ignored
## so a trailing comma cannot quietly select everything.
##
## **THE PATH IS MATCHED AS WELL AS THE ID, BECAUSE BASENAMES ARE NOT UNIQUE.**
## The id is `basename:method`, and twelve of this suite's 256 files share a
## basename with another — `test_in_game.gd` exists FIVE times (story, survival,
## disposition, landmarks, works) and `test_rules.gd` and `test_world.gd` three
## times each. So "test_in_game" as a filter drags in five files from five
## directories that sit far apart in the traversal, which silently destroys a
## SPAN: the whole point of naming a run of files is that they are contiguous.
## Matching the path too means `tests/works/test_in_game` selects exactly one,
## while the bare basename keeps working for everything that is unique.
static func _wanted(id: String, path: String, filter: String) -> bool:
	if not filter.contains(","):
		return id.contains(filter) or path.contains(filter)
	for part: String in filter.split(",", false):
		var want := part.strip_edges()
		if want != "" and (id.contains(want) or path.contains(want)):
			return true
	return false
