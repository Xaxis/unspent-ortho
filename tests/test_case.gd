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
## machine. Eight builders on one laptop put the load average past sixty, and
## every wall-clock budget then misses by three or four times over for reasons
## that have nothing to do with the code under test. A budget that fails for
## that is a budget everyone learns to ignore.
##
## **SLACK IS FOR WAITING, NOT FOR COSTING.** Use it for "how long may I wait
## for something to happen" — a job to finish, a page to open, a body to arrive
## — because that really does take longer on a loaded machine. Do NOT use it for
## "how much does this cost": widening a cost bar by up to 8x makes the test
## blind to a 4x regression, which is docs/LOOK.md's whole chapter on
## instruments that fail toward green. A cost is measured with `best_of()`
## instead, which removes the noise rather than making room for it.
##
## It is RE-SAMPLED (`SAMPLE_GOOD_FOR`), and that is not a detail. It used to be
## cached for the life of the process, and the gate's three shards are three
## processes: in one run `siting_them_costs_nothing` failed at 398 against a bar
## of 90 x 4.1 while `street_crowd` failed at 2233 against 1000 x 1.3 — two
## shards, one machine, one moment, disagreeing by 3.2x about how loaded it was.
## The shard that starts first reads a machine whose siblings have not spun up
## yet, and then spends that number on budgets minutes later. The one-minute
## load average lags the same ramp, which is why the TTL is short.
static func machine_slack() -> float:
	var now := Time.get_ticks_msec()
	if _slack > 0.0 and now - _slack_at < SAMPLE_GOOD_FOR:
		return _slack
	_slack_at = now
	_slack = 1.0
	var cores := maxi(1, OS.get_processor_count())
	var load := _load_average()
	if load > 0.0:
		_slack = clampf(load / float(cores), 1.0, 8.0)
	return _slack


## Long enough that a wait loop asking every frame does not spawn a `sysctl` a
## frame, short enough that a shard cannot spend one reading for a whole run.
const SAMPLE_GOOD_FOR := 3000

static var _slack := 0.0
static var _slack_at := 0


## Is this machine quiet enough for a COST to mean anything at all?
##
## `best_of` removes the noise of a machine that is busy in bursts, because at
## least one run lands in a clear window. It cannot remove the noise of a machine
## that is SATURATED, because then no run does: the landmarks sweep measures 41
## ms quiet, 51 ms beside ten other processes, and 161 ms inside a gate running
## three shards and four shots while another session ran a wave. Best-of-three
## was every one of those.
##
## So there are three regimes and only two of them can be asserted in. When the
## third arrives, a cost test PRINTS ITS NUMBER AND DOES NOT JUDGE IT — which is
## docs/LOOK.md's own third method, "print UNMEASURED, never 0.00 ms", arriving
## in the place it was really needed. The alternative is a bar wide enough to
## pass on a saturated machine, and that is a bar that can no longer fail for a
## real reason, which is the whole thing this file gave up on widening for.
##
## A skipped measurement is not a hole: the gate is run on a quiet machine before
## anything lands, and `tools/check.sh` is where that happens.
##
## AND A RELATIONAL BAR IS NOT IMMUNE EITHER, which is worth writing down because
## it was argued here first and it was an over-claim. Stating a cost as a SHARE
## of something measured in the same run does cancel a load that slows everything
## equally — but contention does not slow everything equally. Three relational or
## best-of bars tripped in one afternoon on this machine: the works stage against
## its own generation (0.269 against a bar of 0.22), the warp list against one
## sweep of the island, and the landmarks sweep at best-of-three. A stage that
## allocates harder loses more of a shared machine than the whole it is a share
## of, so the ratio moves too. Relational is still the better bar — it is tighter
## and it survives the ordinary case — it just is not a licence to assert on a
## machine that cannot be measured.
static func can_measure_cost() -> bool:
	return machine_slack() < 2.0


## Say the number and why it was not judged, so a skipped bar is visible in the
## log rather than being a test that quietly asserts nothing.
func unmeasured(what: String, got: float, bound: float) -> void:
	print("  UNMEASURED %s: %.2f against %.2f, machine at %.1fx — too loaded to mean anything"
		% [what, got, bound, machine_slack()])


## Assert a COST, unless the machine is too loaded for the number to mean
## anything, in which case say so and judge nothing.
func cost_lt(got: float, bound: float, what: String) -> void:
	if can_measure_cost():
		lt(got, bound, what)
	else:
		unmeasured(what, got, bound)


## The cheapest of `n` runs of `what`, in microseconds -- the honest cost of a
## thing on a machine that is also doing something else.
##
## Contention only ever ADDS time: no amount of load makes work finish sooner.
## So the MINIMUM over a few repeats is the closest thing to the quiet-machine
## number that a busy machine can give you, and it lets the bar stay tight
## instead of being widened by `machine_slack()` until it cannot fail. This is
## what fixed the `DevCheats.places()` cost guard, which read 91 ms under gate
## load for a sweep that takes 4.9 ms.
##
## `what` must be repeatable and must do the same work every time -- warm any
## cache it is not measuring first, or forget it inside the callable.
static func best_of(n: int, what: Callable) -> float:
	var best := INF
	for i in maxi(1, n):
		var t := Time.get_ticks_usec()
		what.call()
		best = minf(best, float(Time.get_ticks_usec() - t))
	return best


## The middle of `samples`, which is what to report when a thing is measured
## many times and cannot be repeated whole (a frame inside a soak, one villager
## inside a street). Same reasoning as `best_of`: the tail is the scheduler's,
## not the code's. Takes the low middle of an even count; 0.0 if empty.
static func middle(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var s := samples.duplicate()
	s.sort()
	return s[(s.size() - 1) / 2]


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
