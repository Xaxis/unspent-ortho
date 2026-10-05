extends TestCase
## ONE TRUTH FOR WALKER TIME (#98): a walker's pose and place are functions of
## the walkers' own minute (19_colossi `minutes()`, WorldClock.walk_minutes),
## which a set piece keeps at full pace while it slows the world (43_climb). A
## reader that computes a pose, a step, a foot or a tread's landing from the
## world clock's `minutes` forks walker time: after a climb it is off by the
## climb's lead, and a foot is drawn where the walk is not. Found by what each
## function reads, never by a list: a function under src that calls the walk and
## reads `clock.minutes` is red here. src/core/colossus is the walk itself and
## worldgen has no clock; 19_colossi `world_at` turns a walk minute into a world
## one and calls no walk.

const ROOT := "res://src"
const SKIP: Array[String] = ["res://src/core/colossus", "res://src/core/worldgen"]
## The calls that place a walker in time.
const WALK: Array[String] = ["Walk.pose(", "Walk.steps_between(", "Walk.foot(", "Walk.window(", "lands_at(",
	"lap_minutes(", "natural_plant(", ".call(&\"minutes\")"]


func _files(dir: String, out: Array[String]) -> void:
	if SKIP.has(dir):
		return
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), out)


## Each function's name and body in `src`, split at the lines that open one.
static func _functions(src: String) -> Dictionary:
	var out := {}
	var name := ""
	var body := PackedStringArray()
	for line: String in src.split("\n"):
		var opens := line.begins_with("func ") or line.begins_with("static func ")
		if opens:
			if name != "":
				out[name] = "\n".join(body)
			name = line.trim_prefix("static ").trim_prefix("func ").get_slice("(", 0)
			body = PackedStringArray()
		elif name != "":
			body.append(line)
	if name != "":
		out[name] = "\n".join(body)
	return out


func test_nothing_reads_a_walker_off_the_world_clock() -> void:
	var files: Array[String] = []
	_files(ROOT, files)
	var walking := 0
	for path: String in files:
		var fns := _functions(FileAccess.get_file_as_string(path))
		for fn: String in fns:
			var body: String = fns[fn]
			var walks := false
			for w: String in WALK:
				if body.contains(w):
					walks = true
			if not walks:
				continue
			walking += 1
			check(not body.contains("clock.minutes"), "%s::%s places a walker in time and reads the world clock's minutes: ask 19_colossi minutes()" % [path, fn])
	gt(float(walking), 5.5, "the functions that place a walker in time were found by what they call (%d)" % walking)


func test_the_walks_minute_is_the_walkers_clock() -> void:
	var fns := _functions(FileAccess.get_file_as_string("res://src/systems/19_colossi.gd"))
	check(String(fns.get("minutes", "")).contains("walk_minutes()"), "19_colossi minutes() reads the walkers' clock")
	check(not String(fns.get("minutes", "")).contains("clock.minutes"), "and never the world's")
