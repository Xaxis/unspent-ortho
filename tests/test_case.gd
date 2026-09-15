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


## Advance the real scene tree by n physics+process frames.
func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame
