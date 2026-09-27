extends RefCounted
## WHAT RUNS ON A WORKER, AND WHAT IT MUST NOT DO THERE (tests/core/test_worker_types.gd).
##
## The GDScript VM resolves an operator on an untyped operand (an element of a
## plain Array, a Dictionary value, a Variant) the first time it runs, and writes
## the evaluator into the bytecode with no barrier for readers; two threads
## reaching the same cold operator at once jump through a half-written pointer
## and the process is gone (sound_bank.gd's header; ui_sketch.gd `_plan`). So a
## function any worker runs does its arithmetic and its comparisons on typed
## values, and this reads the shipped source to say which do not.
##
## Reached: every function named in the call or the lambda of a
## `WorkerThreadPool.add_task` / `add_group_task` / `Thread.start`, and everything
## those call, followed through `func` in the same file, `ClassName.fn(` and a
## file's `const X := preload("...gd")` aliases.
##
## Flagged, in a reached function: an index `a[...]` (chained or not) whose base
## is an untyped container (declared `Array`, `Dictionary` or `Variant` with no
## element type, a literal `[`/`{`, a file const or static var the same, or a
## `for` variable walking one of those), and a local `var x := a[...]` / `a.get(...)` from one,
## used as an operand of a binary operator or of `match`. A cast (`float(a[0])`)
## is a call, not an operator, and is what makes the operand typed.
##
## It is a scan of text, and it errs toward saying too much; what it cannot see
## (a Dictionary read with a dot) it does not claim to.

const OPS := "(==|!=|<=|>=|<|>|\\+|-|\\*|/|%|\\band\\b|\\bor\\b|\\bnot\\b)"


static func _re(p: String) -> RegEx:
	var r := RegEx.new()
	var err := r.compile(p)
	assert(err == OK, p)
	return r


static func sources() -> Dictionary:
	var out := {}
	_walk("res://src", out)
	return out


static func _walk(dir: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out[dir.path_join(f)] = FileAccess.get_file_as_string(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)


## {name: [signature line, body]} for every top-level func of a script.
static func funcs(src: String) -> Dictionary:
	var out := {}
	var head := _re("^(static )?func (\\w+)\\(")
	var name := ""
	var sig := ""
	var body := PackedStringArray()
	for line in src.split("\n"):
		var m := head.search(line)
		if m != null:
			if name != "":
				out[name] = [sig, "\n".join(body)]
			name = m.get_string(2)
			sig = line
			body = PackedStringArray()
		elif name != "":
			if line != "" and not (line[0] == "\t" or line[0] == " " or line[0] == "#"):
				out[name] = [sig, "\n".join(body)]
				name = ""
			else:
				body.append(line)
	if name != "":
		out[name] = [sig, "\n".join(body)]
	return out


## Every worker-reached function, as "res://path::name".
static func reached(src: Dictionary) -> Dictionary:
	var fns := {}
	var classes := {}
	var aliases := {}
	var cn := _re("(?m)^class_name\\s+(\\w+)")
	var al := _re("(?m)^const (\\w+) := preload\\(\"(res://[^\"]+\\.gd)\"\\)")
	for p: String in src:
		fns[p] = funcs(src[p])
		var m := cn.search(src[p])
		if m != null:
			classes[m.get_string(1)] = p
		var a := {}
		for am in al.search_all(src[p]):
			a[am.get_string(1)] = am.get_string(2)
		aliases[p] = a
	var seeds: Array[String] = []
	var start := _re("add_task\\(|add_group_task\\(|\\.start\\(")
	var bound := _re("add_(?:group_)?task\\((\\w+)")
	for p: String in src:
		var lines: PackedStringArray = src[p].split("\n")
		for i in lines.size():
			var line := lines[i]
			if start.search(line) == null or not (line.contains("WorkerThreadPool") or line.contains("Thread")):
				continue
			var chunk := "\n".join(lines.slice(i, mini(i + 14, lines.size())))
			seeds.append_array(_callees(p, chunk, fns, classes, aliases))
			var b := bound.search(line)
			if b != null and (fns[p] as Dictionary).has(b.get_string(1)):
				seeds.append("%s::%s" % [p, b.get_string(1)])
	var seen := {}
	while not seeds.is_empty():
		var k: String = seeds.pop_back()
		if seen.has(k):
			continue
		seen[k] = true
		var p := k.get_slice("::", 0)
		var fn := k.get_slice("::", 1)
		var row: Array = (fns[p] as Dictionary)[fn]
		seeds.append_array(_callees(p, row[1], fns, classes, aliases))
	return seen


static func _callees(p: String, body: String, fns: Dictionary, classes: Dictionary, aliases: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var own := _re("(?<![\\w.])(\\w+)\\(")
	for m in own.search_all(body):
		if (fns[p] as Dictionary).has(m.get_string(1)):
			out.append("%s::%s" % [p, m.get_string(1)])
	var dotted := _re("\\b(\\w+)\\.(\\w+)\\(")
	for m in dotted.search_all(body):
		var c := m.get_string(1)
		var tp: String = classes.get(c, (aliases[p] as Dictionary).get(c, ""))
		if tp != "" and fns.has(tp) and (fns[tp] as Dictionary).has(m.get_string(2)):
			out.append("%s::%s" % [tp, m.get_string(2)])
	return out


## Untyped containers a script declares at file level.
static func _file_untyped(src: String) -> Dictionary:
	var u := {}
	var lit := _re("(?m)^(?:static )?(?:const|var) (\\w+)(\\s*:\\s*(\\w+)(\\[)?)?\\s*:?=\\s*[\\[{]")
	for m in lit.search_all(src):
		var typ := m.get_string(3)
		if typ == "" or ((typ == "Array" or typ == "Dictionary" or typ == "Variant") and m.get_string(4) == ""):
			u[m.get_string(1)] = true
	var decl := _re("(?m)^(?:static )?var (\\w+)\\s*:\\s*(Array|Dictionary|Variant)\\s*(?:=|$)")
	for m in decl.search_all(src):
		u[m.get_string(1)] = true
	return u


static func _local_untyped(sig: String, body: String) -> Dictionary:
	var u := {}
	var params := sig.substr(sig.find("(") + 1)
	for pat: String in [
		"(\\w+)\\s*:\\s*(?:Array|Dictionary|Variant)\\b(?!\\[)",
	]:
		for m in _re(pat).search_all(params):
			u[m.get_string(1)] = true
	for pat: String in [
		"\\bvar (\\w+)\\s*:\\s*(?:Array|Dictionary|Variant)\\b(?!\\[)",
		"\\bvar (\\w+)\\s*:?=\\s*[\\[{]",
		"\\bvar (\\w+)\\s*=\\s",
		"\\bfor (\\w+)\\s*:\\s*(?:Array|Dictionary|Variant)\\b(?!\\[) in\\b",
	]:
		for m in _re(pat).search_all(body):
			u[m.get_string(1)] = true
	return u


## An unannotated `for` variable takes its iterable's element type, so it is
## untyped only when what it walks is (a name in `u`, walked whole).
static func _for_untyped(body: String, u: Dictionary) -> void:
	for m in _re("\\bfor (\\w+) in (\\w+)\\s*:").search_all(body):
		if u.has(m.get_string(2)):
			u[m.get_string(1)] = true


## Each finding as "res://path::fn::the line", for every worker-reached function.
static func findings(src: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var idx := _re("\\b(\\w+)((?:\\[[^\\[\\]]*\\])+)")
	var op_after := _re("^" + OPS)
	var op_before := _re(OPS + "$|\\bmatch$")
	var fu := {}
	for k: String in reached(src):
		var p := k.get_slice("::", 0)
		var fn := k.get_slice("::", 1)
		if not fu.has(p):
			fu[p] = _file_untyped(src[p])
		var row: Array = funcs(src[p])[fn]
		var u := _local_untyped(row[0], row[1])
		u.merge(fu[p])
		_for_untyped(row[1], u)
		var sc := {}
		for m in _re("\\bvar (\\w+)\\s*:=\\s*(\\w+)(\\[|\\.get\\()").search_all(row[1]):
			if u.has(m.get_string(2)):
				sc[m.get_string(1)] = true
		for m in _re("\\bvar (\\w+)\\s*:\\s*Variant\\b").search_all(row[1]):
			sc[m.get_string(1)] = true
		for line: String in (row[1] as String).split("\n"):
			var code := line.get_slice("#", 0)
			var hit := false
			for m in idx.search_all(code):
				if not u.has(m.get_string(1)):
					continue
				var after := code.substr(m.get_end()).strip_edges(true, false)
				var before := code.substr(0, m.get_start()).strip_edges(false, true)
				if op_after.search(after) != null or op_before.search(before) != null:
					hit = true
			for v: String in sc:
				for m in _re("(?<![\\w.])" + v + "\\b(?!\\s*[:(\\[])").search_all(code):
					var after := code.substr(m.get_end()).strip_edges(true, false)
					var before := code.substr(0, m.get_start()).strip_edges(false, true)
					if op_after.search(after) != null or op_before.search(before) != null:
						hit = true
			if hit:
				out.append("%s::%s::%s" % [p.trim_prefix("res://"), fn, code.strip_edges()])
	out.sort()
	return out
