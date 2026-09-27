extends TestCase
## A PACKED ARRAY IS COPIED WITH GenFields.snapshot WHERE WORKERS WRITE. A
## packed array's duplicate() shares its storage until the first write, and a
## first write made on several worker threads at once corrupts both arrays
## (GenFields.snapshot's header). A test's duplicate() of a ground map, tidied
## on the pool, read indices past its own end (S4d). Generation moves onto
## workers section by section, so a copy that is safe today because only the
## main thread writes it is not safe once the stream runs it: in world
## generation, and in any file that hands work to a group task, every packed
## array this file declares is copied with snapshot.
##
## ITS LIMIT: it knows a name is a packed array only when the same file
## declares it so (`name: PackedXArray`, `name := PackedXArray(`). A packed
## array that reaches a worker through a field or a parameter typed in another
## file, and is duplicate()d here under an untyped name, is not seen.

const PARALLEL: Array[String] = ["GenFields.rows(", "GenFields.parallel(", "add_group_task("]


func test_packed_arrays_are_copied_with_snapshot_where_workers_write() -> void:
	var found := PackedStringArray()
	var scanned := 0
	for path in _scripts("res://src"):
		var text := FileAccess.get_file_as_string(path)
		if not (path.begins_with("res://src/core/worldgen/") or _parallel(text)):
			continue
		if path == "res://src/core/worldgen/gen_fields.gd":
			# snapshot itself: the one duplicate() it makes it writes at once.
			continue
		scanned += 1
		var packed := _packed_names(text)
		var lines := text.split("\n")
		for n in lines.size():
			var line := lines[n].strip_edges()
			if line.begins_with("#"):
				continue
			for name in _duplicated(line):
				if packed.has(name):
					found.append("%s:%d %s.duplicate()" % [path.trim_prefix("res://"), n + 1, name])
	gt(scanned, 20, "the scan read world generation and the parallel files")
	for f in found:
		check(false, "%s copies a packed array this file declares: use GenFields.snapshot" % f)
	eq(found.size(), 0, "packed arrays copied with duplicate() where workers write")


static func _parallel(text: String) -> bool:
	for p in PARALLEL:
		if text.contains(p):
			return true
	return false


## Names this file declares as packed arrays: typed (`name: PackedXArray`) or
## made (`name := PackedXArray(`).
static func _packed_names(text: String) -> Dictionary:
	var out := {}
	var typed := RegEx.create_from_string("([A-Za-z_][A-Za-z_0-9]*)\\s*:\\s*Packed[A-Za-z0-9]*Array\\b")
	var made := RegEx.create_from_string("([A-Za-z_][A-Za-z_0-9]*)\\s*:=\\s*Packed[A-Za-z0-9]*Array\\(")
	for re: RegEx in [typed, made]:
		for m: RegExMatch in re.search_all(text):
			out[m.get_string(1)] = true
	return out


## The last name before each `.duplicate()` on the line (`c.w.ground` -> ground).
static func _duplicated(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("([A-Za-z_][A-Za-z_0-9]*)\\.duplicate\\(\\)")
	for m in re.search_all(line):
		out.append(m.get_string(1))
	return out


static func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
