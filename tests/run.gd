extends SceneTree
## Headless test runner.
##   godot --headless --path . -s tests/run.gd [-- filter]
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
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]

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
			if filter != "" and not id.contains(filter):
				continue
			var inst: TestCase = script.new()
			inst.tree = self
			inst.current = id
			var t := Time.get_ticks_msec()
			await inst.call(name)
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
