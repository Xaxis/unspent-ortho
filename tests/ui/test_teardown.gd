extends TestCase
## The bake must not outlive the process. A sketch is rastered on a
## WorkerThreadPool worker, and if one is still inside `_bake` when the main
## thread tears the scripting language down, the two outcomes are a coin toss:
## the worker reads freed memory and takes signal 11 (seen in a tour, with the
## backtrace naming `_poly_of`, a line that only reads an array), or the main
## thread blocks forever on GDScript's own recursive lock, which the worker
## holds (seen here, every time, before `src/main.gd` and `tests/run.gd` waited).
##
## The second half is a SOURCE test on purpose. A behaviour test cannot prove
## this: the drain runs at `_exit_tree` and at the runner's own quit, after the
## last test has reported, so by the time anything could assert on it the process
## is already going. What can be checked is that the two doors still say so.

## Every place a process running this game can end, and what must drain there.
const DRAINS := [
	["res://src/main.gd", "_exit_tree"],
	["res://tests/run.gd", "_run"],
]


func _body(source: String, fn: String) -> String:
	var lines := source.split("\n")
	var out := PackedStringArray()
	var inside := false
	for line in lines:
		var l: String = line
		if l.begins_with("func ") or l.begins_with("static func "):
			inside = l.contains("func %s(" % fn)
			continue
		if inside:
			out.append(l)
	return "\n".join(out)


func test_every_door_out_of_the_process_drains_the_bake() -> void:
	for row: Array in DRAINS:
		var path: String = row[0]
		var fn: String = row[1]
		var source := FileAccess.get_file_as_string(path)
		check(source.length() > 0, "read %s" % path)
		var body := _body(source, fn)
		check(body.length() > 0, "%s still has %s()" % [path, fn])
		# By PATH in both, deliberately: naming UiSketch in either file compiles the
		# UI package before the Events autoload exists and takes game.gd,
		# crafting.gd and survival.gd down as load errors. Both forms are accepted
		# here so a later reader who can safely name the class is not blocked.
		check(body.contains("ui_sketch.gd") or body.contains("UiSketch.wait()"),
			"%s %s() must wait out the sketch bake, or a worker outlives the tree" % [path, fn])
		check(body.contains("ui_slate.gd") or body.contains("UiSlate.wait()"),
			"%s %s() must wait out the slate bake too" % [path, fn])


func test_a_bake_left_running_is_waited_out_not_abandoned() -> void:
	# The shape the forcing case had: start a creel, do not wait, and hand back.
	# Whatever the drain is, `wait()` must finish it rather than leave it out —
	# a pool task cannot be cancelled, so "abandon it" is not on the table.
	var ids: Array[StringName] = []
	for id: StringName in Items.DEFS:
		ids.append(id)
		if ids.size() >= 12:
			break
	UiSketch._cache.clear()
	UiSketch.warm(ids, 234)
	check(UiSketch.waiting(), "the pool took the bake")
	UiSketch.wait()
	check(not UiSketch.waiting(), "and wait() left nothing running")
	for id in ids:
		check(UiSketch.item_texture(id, 234) != null, "%s finished rather than being dropped" % id)
	UiSketch.wait()
