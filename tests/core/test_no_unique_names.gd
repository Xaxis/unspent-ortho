extends TestCase
## No script under src asks for a scene-unique node (`%Name`). Everything here is
## built in code and nothing is marked unique, so such a lookup can only ever
## fail, and it fails at run time as an engine error in whatever frame reaches it.
## It is also what a `%%` outside a string turns into: `"a: %%s." %% line` read
## as a modulo of `%line` (44_crafts' teaching hint was exactly that). A `%`
## with a name straight after it, outside strings and comments, is the pattern.


func test_no_script_looks_up_a_unique_node() -> void:
	var found: Array[String] = []
	var n := 0
	for path in _scripts("res://src"):
		n += 1
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var codes := _code_of(lines)
		for i in codes.size():
			if _unique_lookup(codes[i]):
				found.append("%s:%d  %s" % [path, i + 1, lines[i].strip_edges()])
	gt(float(n), 100.0, "the scripts were read (%d)" % n)
	eq(found.size(), 0, "unique-node lookups: %s" % "\n".join(found))


## The two shapes it takes in code: a `%` with a name straight after it, or a
## `%` that follows another `%` (with only spaces between), where the second
## can only be the start of an operand.
static func _unique_lookup(code: String) -> bool:
	var at := code.find("%")
	while at >= 0:
		var next := code.substr(at + 1, 1)
		if next != "" and (next == "_" or next.to_upper() != next.to_lower()):
			return true
		var rest := code.substr(at + 1).strip_edges(true, false)
		if rest.begins_with("%"):
			return true
		at = code.find("%", at + 1)
	return false


## The file's lines with every string blanked (a triple-quoted one across lines
## too) and every comment cut off, so only code is left.
static func _code_of(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var quote := ""
	for line in lines:
		var code := ""
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 2
					continue
				if line.substr(i, quote.length()) == quote:
					i += quote.length()
					quote = ""
					code += " "
					continue
				code += " "
			elif line.substr(i, 3) == "\"\"\"":
				quote = "\"\"\""
				i += 3
				code += " "
				continue
			elif ch == "\"" or ch == "'":
				quote = ch
				code += " "
			elif ch == "#":
				break
			else:
				code += ch
			i += 1
		out.append(code)
	return out


static func _scripts(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(root):
		if f.ends_with(".gd"):
			out.append(root.path_join(f))
	for d in DirAccess.get_directories_at(root):
		out.append_array(_scripts(root.path_join(d)))
	return out
