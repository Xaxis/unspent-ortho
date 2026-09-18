extends TestCase
## The bodies a world is made of, and the void between them (docs/WORLD.md).
## Today one island gives one body; this holds the recording honest so that the
## day the planning half inverts the stage, what broke is obvious.

const SEEDS: Array[int] = [1, 42, 90210]


func test_every_land_tile_is_on_a_body_and_no_sea_tile_is() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 256)
		eq(w.continent.size(), w.level.size(), "seed %d: a body id per tile" % s)
		var land := 0
		var stray := 0
		for i in w.level.size():
			var on_land := w.level[i] > 0
			var id := w.continent[i]
			if on_land:
				land += 1
				if id == GenBodies.VOID:
					stray += 1
			elif id != GenBodies.VOID:
				stray += 1
		gt(float(land), 1000.0, "seed %d: there is land to be on" % s)
		eq(stray, 0, "seed %d: land is on a body and the sea is the void" % s)


func test_the_bodies_describe_themselves() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 256)
		check(not w.continents.is_empty(), "seed %d: a world is made of something" % s)
		var counted := {}
		for i in w.continent.size():
			var id := w.continent[i]
			if id != GenBodies.VOID:
				counted[id] = int(counted.get(id, 0)) + 1
		var last := 1 << 30
		for b: Dictionary in w.continents:
			var id := int(b.id)
			eq(int(b.tiles), int(counted.get(id, -1)), "seed %d body %d: says how big it is" % [s, id])
			check(int(b.tiles) <= last, "seed %d: biggest first" % s)
			last = int(b.tiles)
			var r: Rect2 = b.bounds
			check(r.has_point(b.centre as Vector2), "seed %d body %d: its middle is inside it" % [s, id])
		eq(w.continents.size(), counted.size(), "seed %d: every body on the ground is described" % s)


## ONE WRITER, and a test that fails when a second appears — the discipline
## docs/WORLD.md §3 asks for, because a rule that is only in a header is a rule
## until the first hurry. `tests/render/test_one_writer.gd` does this for the sky
## globals and caught a real bypass by somebody who knew the rule.
func test_gen_bodies_is_the_only_thing_that_writes_a_body_id() -> void:
	var writers := PackedStringArray()
	var dir := DirAccess.open("res://src/")
	check(dir != null, "src/ exists")
	_walk("res://src", writers)
	for f: String in writers:
		check(f.ends_with("gen_bodies.gd") or f.ends_with("world_data.gd"),
			"%s writes WorldData.continent; GenBodies is its one writer" % f)


static func _walk(path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_walk(path.path_join(sub), out)
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var whole := path.path_join(f)
		var text := FileAccess.get_file_as_string(whole)
		if text.is_empty():
			continue
		for line: String in text.split("\n"):
			var t := line.strip_edges()
			if t.begins_with("#"):
				continue
			if t.contains(".continent =") or t.contains(".continent[") or t.contains(".continents ="):
				out.append(whole)
				break
