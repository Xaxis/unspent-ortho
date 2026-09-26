extends TestCase
## THE WHOLE-WORLD READERS MAY ONLY GO. A streamed world keeps some sections
## resident and drops the rest (the streaming design, slice S0), and every
## reader in `whole_world_readers.txt` assumes it can see all of it. This holds
## the code against that list both ways: a reader the list does not name is new
## and fails, and a line the code no longer matches is done and fails until it
## is deleted, so the list is always exactly what is left to do.

const Scan := preload("res://tests/stream/whole_world_scan.gd")
const LIST := "res://tests/stream/whole_world_readers.txt"


static func listed() -> Dictionary:
	var out := {}
	for raw: String in FileAccess.get_file_as_string(LIST).split("\n"):
		var line := raw.strip_edges()
		if line != "" and not line.begins_with("#"):
			out[line] = true
	return out


func test_no_new_whole_world_reader() -> void:
	var known := listed()
	gt(float(known.size()), 100.0, "the list was read (%d)" % known.size())
	for key: String in Scan.new().scan():
		check(known.has(key), "%s reads the whole world and is not in whole_world_readers.txt: read a window or the plan instead" % key)


func test_every_listed_reader_is_still_there() -> void:
	var found := {}
	for key: String in Scan.new().scan():
		found[key] = true
	for key: String in listed():
		check(found.has(key), "%s no longer reads the whole world: delete its line from whole_world_readers.txt" % key)


## The scanner itself, on lines it must and must not catch, so a green run
## above cannot come from a scanner that finds nothing.
func test_the_scan_sees_the_forms_it_names() -> void:
	var s := Scan.new()
	var cases := {
		"\tfor p in w.props:": "list",
		"\tfor p in w.each_prop():": "list",
		"\tfor i in range(base, w.prop_count()):": "list",
		"\treturn feeds_among(world.each_prop(), at)": "list",
		"\tfor i in game.world.villages.size():": "list",
		"\tvar q: WorldProp = world.props[id]": "index",
		"\tbytes.resize(w.size * w.size)": "tiles",
		"\tfor y in size:": "tiles",
		"\tvar g := world.ground[i]": "raw",
		"\tvar level := w.level": "raw",
		"\tvar props := game.world.props": "whole",
		"\tvar id := w.props.size()": "alloc",
		"\tvar sites := Landmarks.sites(world)": "builder Landmarks.sites",
	}
	for line: String in cases:
		var keys := {}
		s._scan_file_text("t.gd", "func f() -> void:\n" + line + "\n", true, keys)
		check(keys.has("t.gd::f::" + cases[line]), "%s is seen as %s (got %s)" % [line.strip_edges(), cases[line], keys.keys()])
	for line: String in [
		"\tfor ty in range(maxi(0, cy - r), mini(world.size - 1, cy + r) + 1):",
		"\t# for p in w.props: a comment",
		"\tfor y in range(p, size.y, p * 2):",
		"\tvar n := near.size()",
		"\tregion = w.region",
	]:
		var keys := {}
		s._scan_file_text("t.gd", "func f() -> void:\n" + line + "\n", true, keys)
		eq(keys.size(), 0, "%s is local (got %s)" % [line.strip_edges(), keys.keys()])
