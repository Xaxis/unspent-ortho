extends SceneTree
## Headless test runner.
##   godot --headless --path . -s tests/run.gd [-- filter] [--shard=I/N]
##
## --shard=I/N runs every Nth test file starting at the Ith (0-based), so the
## gate can run N processes side by side. Whole files stay together, so a file's
## cached worlds are built once. Scripts under src are loaded in each.
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

	for path in _find("res://src", ".gd"):
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			_load_errors += 1
			printerr("LOAD FAIL ", path)
	for path in _find("res://src", ".gdshader"):
		if load(path) == null:
			_load_errors += 1
			printerr("LOAD FAIL ", path)

	for path in _find("res://tests", ".gd"):
		if not path.get_file().begins_with("test_") or path.get_file() == "test_case.gd":
			continue
		_load_script_errors()
		index += 1
		if index % shards != shard:
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
			var inst: TestCase = script.new()
			inst.tree = self
			inst.current = id
			_load_script_errors()
			var t := Time.get_ticks_msec()
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
			var ms := Time.get_ticks_msec() - t
			for e: String in _script_errors.call(&"take"):
				inst.failures.append("%s: %s" % [id, e])
			if inst.failures.is_empty():
				_passed += 1
				print("  ok   %s (%d ms)" % [id, ms])
			else:
				_failed += 1
				print("  FAIL %s (%d ms)" % [id, ms])
				for f in inst.failures:
					print("       ", f)
	_load_script_errors()
	var total := Time.get_ticks_msec() - t0
	print("\n%d passed, %d failed, %d load errors in %d ms" % [_passed, _failed, _load_errors, total])
	# A test that started a sketch bake and did not wait for it leaves a worker
	# inside `_bake` when this quits, and the runner then either deadlocks on
	# GDScript's own lock or dies on freed memory. It killed a gate shard: shards
	# 0 and 2 printed their results and shard 1 printed nothing at all, which
	# reads as a red gate with no failing assertion and nothing to blame. A pool
	# task cannot be cancelled, so the runner waits out what it started.
	#
	# BY PATH, not by class name, for the same reason src/main.gd does it that
	# way: naming UiSketch in this file compiles the UI package before the Events
	# autoload exists, and game.gd, crafting.gd and survival.gd all fail to load
	# behind it. Measured — three load errors, and the gate red for a new reason.
	(load("res://src/ui/ui_sketch.gd") as GDScript).call("wait")
	(load("res://src/ui/ui_slate.gd") as GDScript).call("wait")
	RunnerHome.remove()
	quit(0 if _failed == 0 and _load_errors == 0 and _passed > 0 else 1)


## Script errors raised outside any test (loading scripts, making a test's
## instance): each is a load error, printed where it is counted.
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
