extends TestCase
## NO PROP IS COMPARED AS AN OBJECT. Props are packed columns and a WorldProp is
## a view made fresh from its row (the streaming design, S7): two views of one
## prop are two objects, so `a == b`, `list.has(p)`, `list.find(p)`,
## `list.erase(p)`, `p in list` and a dictionary keyed by a prop are all
## silently false for the same prop. Compare ids (`WorldProp.same`, `.id`).
##
## Text, not a parser. A name is taken to be a prop when the file declares it
## `: WorldProp`, sets it from `prop(` / `prop_at(`, or loops over a list
## declared `Array[WorldProp]`; a list is taken to hold props when declared
## `Array[WorldProp]`. WorldData and generation are not scanned: they own the
## objects while a world is grown. Hand-built test worlds keep their objects, but
## a test cannot tell which kind it holds, so tests compare ids too.

## The tests too: a test comparing props as objects fails for the wrong reason,
## or passes for one.
const ROOTS := ["res://src", "res://tests"]
const SKIP := ["res://src/core/worldgen", "res://src/core/world_data.gd", "res://src/core/world_prop.gd",
	"res://src/core/prop_table.gd", "res://tests/stream/test_prop_identity.gd"]


static func hits() -> PackedStringArray:
	var out := PackedStringArray()
	for root: String in ROOTS:
		for path: String in _files(root):
			out.append_array(scan_text(path.trim_prefix("res://"), FileAccess.get_file_as_string(path)))
	return out


static func _files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if dir_path in SKIP:
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f: String in dir.get_files():
		var p := dir_path + "/" + f
		if f.ends_with(".gd") and not p in SKIP:
			out.append(p)
	for d: String in dir.get_directories():
		out.append_array(_files(dir_path + "/" + d))
	return out


## Every line of `text` that compares a prop as an object, as "path:line: code".
## A name declared inside a function is a prop only in that function; one
## declared at the top of the file is a prop everywhere in it.
static func scan_text(rel: String, text: String) -> PackedStringArray:
	var lines := text.split("\n")
	var file_props := {}
	var file_lists := {}
	var fn := RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s")
	# The file's own members: declared at column 0.
	_names(lines, 0, lines.size(), file_props, file_lists, true)
	var out := PackedStringArray()
	var starts: Array[int] = []
	for i in lines.size():
		if fn.search(lines[i]) != null:
			starts.append(i)
	starts.append(lines.size())
	for k in starts.size() - 1:
		var props := file_props.duplicate()
		var lists := file_lists.duplicate()
		_names(lines, starts[k], starts[k + 1], props, lists, false)
		for i in range(starts[k], starts[k + 1]):
			var line := _code(lines[i])
			if line.strip_edges() == "" or line.strip_edges().begins_with("for "):
				continue
			if _compares(line, props, lists):
				out.append("%s:%d: %s" % [rel, i + 1, line.strip_edges()])
	return out


static func _names(lines: PackedStringArray, a: int, b: int, props: Dictionary, lists: Dictionary, top_only: bool) -> void:
	var typed := RegEx.create_from_string("\\b(\\w+)\\s*:\\s*WorldProp\\b(?!\\])")
	var listed := RegEx.create_from_string("\\b(\\w+)\\s*:\\s*Array\\[WorldProp\\]")
	var made := RegEx.create_from_string("\\bvar\\s+(\\w+)\\s*:?=\\s*[\\w.]*\\b(?:prop|prop_at)\\(")
	var walked := RegEx.create_from_string("\\bfor\\s+(\\w+)(?:\\s*:\\s*\\w+)?\\s+in\\s+(\\w+)\\s*:")
	var alias := RegEx.create_from_string("\\bvar\\s+(\\w+)\\s*:=\\s*(\\w+)\\s*$")
	for pass_i in 2:
		for i in range(a, b):
			var raw := lines[i]
			if top_only and (raw.begins_with("\t") or raw.begins_with(" ")):
				continue
			var line := _code(raw)
			for m: RegExMatch in typed.search_all(line):
				props[m.get_string(1)] = true
			for m: RegExMatch in listed.search_all(line):
				lists[m.get_string(1)] = true
			var mm := made.search(line)
			if mm != null:
				props[mm.get_string(1)] = true
			var w := walked.search(line)
			if w != null and lists.has(w.get_string(2)):
				props[w.get_string(1)] = true
			var al := alias.search(line.strip_edges(false, true))
			if al != null and props.has(al.get_string(2)):
				props[al.get_string(1)] = true


static func _compares(line: String, props: Dictionary, lists: Dictionary) -> bool:
	for name: String in props:
		var n := "\\b" + name + "\\b(?!\\s*\\.|\\s*\\()"
		for pat: String in [
			n + "\\s*(?:==|!=)\\s*(?!null\\b)",
			"(?<!null)\\s*(?:==|!=)\\s*" + n,
			"\\.(?:has|find|erase|rfind|count)\\(\\s*" + n,
			n + "\\s+(?:not\\s+)?in\\s",
			"\\[\\s*" + n + "\\s*\\]",
			"\\.get\\(\\s*" + n,
		]:
			var re := RegEx.create_from_string(pat)
			var m := re.search(line)
			if m != null and not _null_side(line, m):
				return true
	for name: String in lists:
		if RegEx.create_from_string("\\b" + name + "(?:\\[[^\\]]*\\])?\\.(?:has|find|erase|rfind|count)\\(").search(line) != null:
			return true
	return false


## A comparison with null is a presence test, not an identity one.
static func _null_side(line: String, m: RegExMatch) -> bool:
	var around := line.substr(maxi(0, m.get_start() - 8), m.get_end() - m.get_start() + 16)
	return around.contains("null")


## The line without its comment, and with every string's contents blanked: a
## message saying "the heap in reach" is not a prop in a list.
static func _code(line: String) -> String:
	var quote := ""
	var out := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if quote != "":
			if ch == "\\":
				i += 1
				out += "  "
			elif ch == quote:
				quote = ""
				out += ch
			else:
				out += " "
		elif ch == "\"" or ch == "'":
			quote = ch
			out += ch
		elif ch == "#":
			return out
		else:
			out += ch
		i += 1
	return out


func test_no_prop_is_compared_as_an_object() -> void:
	var found := hits()
	for h: String in found:
		fail("compares a prop as an object (use WorldProp.same or .id): %s" % h)
	eq(found.size(), 0, "props compared by id only")


func test_the_scan_sees_what_it_names() -> void:
	var src := """func f(p: WorldProp, q: WorldProp, heaps: Array[WorldProp]) -> void:
	if p == q:
		pass
	if heaps.has(p):
		pass
	var d := {}
	d[p] = 1
	var t := w.prop(3)
	if t != q:
		pass
	if p == null:
		pass
	if p.id == q.id:
		pass
	check(WorldProp.same(p, q), "the heap in reach")
"""
	var got := scan_text("t.gd", src)
	eq(got.size(), 4, "four comparisons of objects, and none of null or ids: %s" % [got])
