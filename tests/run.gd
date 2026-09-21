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

var _failed := 0
var _passed := 0
var _load_errors := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
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
			if filter != "" and not _wanted(id, filter):
				continue
			var inst: TestCase = script.new()
			inst.tree = self
			inst.current = id
			var t := Time.get_ticks_msec()
			await inst.call(name)
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
			if inst.failures.is_empty():
				_passed += 1
				print("  ok   %s (%d ms)" % [id, ms])
			else:
				_failed += 1
				print("  FAIL %s (%d ms)" % [id, ms])
				for f in inst.failures:
					print("       ", f)
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
	quit(0 if _failed == 0 and _load_errors == 0 and _passed > 0 else 1)


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


## Does `id` ("file:method") match `filter`? One substring as it always was, or
## several separated by commas, where any one matching is enough. Blank parts are
## ignored so a trailing comma cannot quietly select everything.
static func _wanted(id: String, filter: String) -> bool:
	if not filter.contains(","):
		return id.contains(filter)
	for part: String in filter.split(",", false):
		var want := part.strip_edges()
		if want != "" and id.contains(want):
			return true
	return false
