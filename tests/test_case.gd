class_name TestCase
extends RefCounted
## Base for tests. Any method named test_* is run by tests/run.gd.
## Assertions record a failure and keep going, so one run shows every problem.
## Tests may await (e.g. process frames); the runner awaits each test method.

var failures: PackedStringArray = []
var current: String = ""
## Set by the runner: the SceneTree, for tests that need nodes or frames.
var tree: SceneTree


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current, msg])


func check(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		fail("%s expected %s, got %s" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float = 1e-4, msg: String = "") -> void:
	if absf(actual - expected) > tol:
		fail("%s expected %f +- %f, got %f" % [msg, expected, tol, actual])


func gt(actual: float, bound: float, msg: String = "") -> void:
	if not actual > bound:
		fail("%s expected > %s, got %s" % [msg, str(bound), str(actual)])


func lt(actual: float, bound: float, msg: String = "") -> void:
	if not actual < bound:
		fail("%s expected < %s, got %s" % [msg, str(bound), str(actual)])


## How much less of a processor this run is getting than it would on a quiet
## machine, measured once. Eight builders on one laptop put the load average
## past sixty, and every wall-clock budget then misses by three or four times
## over for reasons that have nothing to do with the code under test. A budget
## that fails for that is a budget everyone learns to ignore, so the budgets
## here are multiplied by this instead: still strict on a quiet machine, honest
## on a busy one.
static func machine_slack() -> float:
	if _slack > 0.0:
		return _slack
	_slack = 1.0
	var cores := maxi(1, OS.get_processor_count())
	var load := _load_average()
	if load > 0.0:
		_slack = clampf(load / float(cores), 1.0, 8.0)
	return _slack


static var _slack := 0.0


## The one-minute load average, or 0.0 where it cannot be read.
static func _load_average() -> float:
	if FileAccess.file_exists("/proc/loadavg"):
		var f := FileAccess.open("/proc/loadavg", FileAccess.READ)
		if f != null:
			return float(f.get_line().split(" ")[0])
	var out: Array = []
	if OS.execute("sysctl", ["-n", "vm.loadavg"], out) == 0 and not out.is_empty():
		# { 50.49 60.10 63.36 }
		var parts := String(out[0]).replace("{", "").replace("}", "").strip_edges().split(" ", false)
		if not parts.is_empty():
			return float(parts[0])
	return 0.0


## Advance the real scene tree by n physics frames. Most of the game is stepped
## on those (the fight, survival, the mobs), and most tests are written against
## them, so this is what "a frame" means here.
func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Advance it by n PROCESS frames instead, for the few things that only happen in
## one: a headless loop runs several physics steps inside a single process frame,
## so `frames(2)` can deliver no `_process` at all, and a test that asks a node to
## do its once-a-frame late pass has to say so (tests/sky/test_one_writer).
func process_frames(n: int) -> void:
	for i in n:
		await tree.process_frame
