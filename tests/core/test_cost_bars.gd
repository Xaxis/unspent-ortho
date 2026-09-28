extends TestCase
## EVERY COST BAR GOES THROUGH ITS DOOR. A timed bar (`lt` on something read off
## the clock) judged inside a shard reads the other shards' load as its own cost
## and goes red for nothing: test_overhead did, on land/fight4. So a bar on a
## duration is asserted with `cost_lt` (an absolute time: deferred beside the
## shards, CI_SPEED on CI), `ratio_lt` (a ratio of two timings from one run) or
## `yard_lt` (in yardsticks), never a bare `lt`.
##
## Read from the source: in each test function, every name taken off the clock
## (Time.get_ticks_usec/msec, best_of, yard_sample), or worked out from one, and
## any bare `lt(` whose first argument uses such a name. A floor (`gt` on a
## time) is not a bar load can break (load only adds time) and is let be.

const CLOCK := ["get_ticks_usec", "get_ticks_msec", "best_of(", "yard_sample("]
## The doors themselves, and the tests of the doors.
const EXEMPT := ["res://tests/test_case.gd", "res://tests/core/test_yard_bar.gd", "res://tests/core/test_cost_bars.gd", "res://tests/run.gd"]


static func files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		files(dir.path_join(sub), out)


## Bare timed bars in `src`: "line: text" for each.
static func bare_bars(src: String) -> Array[String]:
	var out: Array[String] = []
	var timed := {}
	var lines := src.split("\n")
	var word := RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	var assign := RegEx.create_from_string("^\\s*(?:var\\s+)?([A-Za-z_][A-Za-z0-9_]*)\\s*(?::[^=]*)?(?::=|=|\\+=|-=)\\s*(.+)$")
	for i in lines.size():
		var line: String = lines[i]
		var bare := line.strip_edges()
		if bare.begins_with("func ") or bare.begins_with("static func "):
			timed.clear()
			continue
		if bare.begins_with("#"):
			continue
		var m := assign.search(line)
		if m != null:
			var rhs := m.get_string(2)
			var from_clock := false
			for c: String in CLOCK:
				from_clock = from_clock or rhs.contains(c)
			for w in word.search_all(rhs):
				from_clock = from_clock or timed.has(w.get_string())
			if from_clock:
				timed[m.get_string(1)] = true
		if not bare.begins_with("lt("):
			continue
		# The first argument, up to the first comma outside brackets.
		var depth := 0
		var arg := ""
		for ch in bare.substr(3):
			if ch in ["(", "[", "{"]:
				depth += 1
			elif ch in [")", "]", "}"]:
				depth -= 1
			if ch == "," and depth == 0:
				break
			arg += ch
		for w in word.search_all(arg):
			if timed.has(w.get_string()):
				out.append("%d: %s" % [i + 1, bare])
				break
	return out


func test_no_timed_bar_skips_its_door() -> void:
	var all: Array[String] = []
	files("res://tests", all)
	gt(float(all.size()), 100.0, "the tests were found")
	var bad: Array[String] = []
	for path in all:
		if path in EXEMPT:
			continue
		for b in bare_bars(FileAccess.get_file_as_string(path)):
			bad.append("%s:%s" % [path.trim_prefix("res://"), b])
	eq(bad.size(), 0, "a bar on a duration goes through cost_lt, ratio_lt or yard_lt:\n      %s" % "\n      ".join(bad))


func test_the_rule_sees_a_bare_bar() -> void:
	var src := "func test_x() -> void:\n\tvar t := Time.get_ticks_usec()\n\tdo_it()\n\tvar ms := (Time.get_ticks_usec() - t) / 1000.0\n\tlt(ms, 20.0, \"quick\")\n"
	eq(bare_bars(src).size(), 1, "a bare lt on a time is caught")
	var worked := "func test_y() -> void:\n\tvar a := best_of(3, f)\n\tvar share := a / 2.0\n\tlt(share, 0.1, \"a share\")\n"
	eq(bare_bars(worked).size(), 1, "and one on a number worked out from a time")
	var routed := "func test_z() -> void:\n\tvar a := best_of(3, f)\n\tcost_lt(a, 20.0, \"quick\")\n\tgt(a, 0.0, \"a floor\")\n\tlt(count, 3, \"not a time\")\n"
	eq(bare_bars(routed).size(), 0, "a routed bar, a floor and a bar on no time pass")
