extends TestCase
## The bake runs on WorkerThreadPool workers. What a worker may touch is the
## contract this file holds, because the failure mode is not a red test: it is
## the process gone, mid-play, with no save.
##
## Three halves, and the source one is the durable half. A worker's code reads
## only its arguments, `Rng`, `Geometry2D` and its own `Image`; everything that
## comes out of a content class (UiIcons, Items, Palette, UiTheme) is read by
## whoever asked for the sketch, on its own thread, and handed over as numbers.
## A contention test cannot prove that — it passed for months against the code
## that crashed — so the guard reads the shipped source instead.

## Every function that runs on a worker, reached from `_bake`.
const ON_A_WORKER := [
	"_bake", "_raster", "to_phosphor", "_box_of", "_colour",
	"_id", "_wobble", "_plot", "_stroke", "_glow",
]

## An operator on an untyped value (an element of a plain Array, a Dictionary
## value, an untyped const Array) is resolved by the VM the first time it runs
## and written into the bytecode with no barrier for readers; two workers
## reaching the same cold one at once crash the process (sound_bank.gd's header;
## tools/gd/probe_sketch_race.gd crashed 1 cold process in 150 at `match
## part[0]`). The worker reads the shape tables only through `_plan`'s typed
## arrays, never by indexing them.
const UNTYPED := ["part[", "parts[", "part.slice(", "BAYER["]

## Naming one of these from a worker is the bug this file exists to stop. The
## content classes because a worker must not be the thread that asks them
## anything; the Node doors because a Node touched off the main thread is an
## abort, not an error.
const OFF_LIMITS := [
	"UiIcons.", "Items.", "Palette.", "UiTheme.", "UiFont.", "Gear.",
	"get_tree(", "get_viewport(", "add_child(", "queue_redraw(", "propagate_",
]


## The body of each `static func` in a script's source, by name.
func _bodies(source: String) -> Dictionary:
	var out := {}
	var name := ""
	var body := PackedStringArray()
	for line in source.split("\n"):
		var l: String = line
		if l.begins_with("static func ") or l.begins_with("func "):
			if name != "":
				out[name] = "\n".join(body)
			var head := l.substr(l.find("func ") + 5)
			name = head.substr(0, head.find("("))
			body = PackedStringArray()
		elif name != "":
			body.append(l)
	if name != "":
		out[name] = "\n".join(body)
	return out


func test_no_worker_side_function_asks_a_content_class() -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/ui_sketch.gd")
	check(source.length() > 0, "read the sketch source")
	var bodies := _bodies(source)
	for fn: String in ON_A_WORKER:
		check(bodies.has(fn), "%s is still a function in ui_sketch.gd" % fn)
		if not bodies.has(fn):
			continue
		var body: String = bodies[fn]
		for bad: String in OFF_LIMITS:
			check(not body.contains(bad),
				"%s runs on a worker and must not name %s — resolve it in _item_job/_station_job/_ramps_for instead" % [fn, bad])


func test_a_worker_runs_no_operator_on_an_untyped_value() -> void:
	var bodies := _bodies(FileAccess.get_file_as_string("res://src/ui/ui_sketch.gd"))
	for fn: String in ON_A_WORKER:
		var body: String = bodies.get(fn, "")
		for bad: String in UNTYPED:
			check(not body.contains(bad),
				"%s runs on a worker and indexes an untyped value (%s): read it in _plan, on the main thread" % [fn, bad])
	check(not bodies.get("_raster", "").contains("_poly_of("), "_raster takes its polygons from the plan, not from the parts")


func test_the_split_did_not_change_a_single_pixel() -> void:
	# What `_bake` makes off a main-thread job, against the same sketch composed
	# the long way round. The scan keeps brightness and drops hue, so a sketch
	# that shifted by one step would read as another material's picture.
	var ids: Array[StringName] = [&"knife", &"pick", &"timber", &"driftwood", &"wick", &"limestone", &"resin", &"reeds"]
	for id in ids:
		var st := UiIcons.style_of(id)
		var shape: StringName = st[0]
		var parts: Array = UiSketch.SHAPES.get(shape, UiSketch.SHAPES[&"bundle"])
		var want := UiSketch.to_phosphor(
			UiSketch.render(parts, Vector2(UiSketch.GRID, UiSketch.GRID), Vector2i(48, 48),
				st[1], st[2], UiSketch.FOUND_SHAPES.has(shape), hash(id)),
			UiIcons.tones_for(id))
		var got := UiSketch._bake(UiSketch._item_job(id, 48))
		eq(got.get_size(), want.get_size(), "%s is the same size" % id)
		var differ := 0
		for y in want.get_height():
			for x in want.get_width():
				if got.get_pixel(x, y) != want.get_pixel(x, y):
					differ += 1
		eq(differ, 0, "%s is pixel for pixel what it was" % id)
	for st: StringName in [&"fire", &"bench", &"kiln", &"hand"]:
		var row: Array = UiSketch.STATIONS[st]
		var want := UiSketch.to_phosphor(
			UiSketch.render(row[0], Vector2(48, 32), UiSketch.station_size(96), row[1], row[2], row[3], hash(st)),
			UiTheme.PHOSPHOR)
		var got := UiSketch._bake(UiSketch._station_job(st, 96))
		var differ := 0
		for y in want.get_height():
			for x in want.get_width():
				if got.get_pixel(x, y) != want.get_pixel(x, y):
					differ += 1
		eq(differ, 0, "station %s is pixel for pixel what it was" % st)


func _ids(most: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Items.DEFS:
		out.append(id)
		if out.size() >= most:
			break
	return out


func test_a_creel_bakes_under_contention() -> void:
	var ids := _ids(24)
	var shapes: Array = UiSketch.SHAPES.keys()
	for round_i in 4:
		UiSketch._cache.clear()
		UiSketch.warm(ids, 234)
		# The main thread rasterising the same const shape table while the
		# workers are on it.
		for k in 4:
			var shape: StringName = shapes[(round_i * 4 + k) % shapes.size()]
			UiSketch.render(UiSketch.SHAPES[shape], Vector2(UiSketch.GRID, UiSketch.GRID), Vector2i(64, 64),
				&"stone", &"earth", UiSketch.FOUND_SHAPES.has(shape), round_i)
		frames(2)
		UiSketch.wait()
	for id in ids:
		check(UiSketch.item_texture(id, 234) != null, "%s baked" % id)


func test_a_key_already_out_is_not_baked_twice() -> void:
	# `warm` used to check only _cache and _ready, so a key already out on a
	# worker from _texture was rasterised a second time.
	UiSketch._cache.clear()
	UiSketch.wait()
	check(UiSketch.item_texture(&"whelk", 96) == null, "the first ask puts it out")
	var out_after_ask := UiSketch._tasks.size()
	UiSketch.warm([&"whelk"] as Array[StringName], 96)
	eq(UiSketch._tasks.size(), out_after_ask, "warming the same key adds no second worker")
	UiSketch.wait()
	check(UiSketch.item_texture(&"whelk", 96) != null, "and it still lands")
