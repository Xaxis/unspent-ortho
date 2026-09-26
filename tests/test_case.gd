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
##
## **AS A MULTIPLE OF ITS OWN BAR, because a bare pair of numbers is not read.**
## `Works.sites` went 1.99 ms to 10.41 against a bar of 5, and for as long as the
## machine stayed loud this line printed the 10.41, judged nothing and the test
## said ok — the instrument had the answer and the verdict was not allowed to use
## it. The number and the bound were both already on the line; nobody divided
## them. "2.1x its bar" cannot be skimmed past the way "10.41 against 5.00" can,
## and it needs no stored baseline to go stale, since both halves come from the
## same run.
func unmeasured(what: String, got: float, bound: float) -> void:
	print("  UNMEASURED %s: %.2f is %.1fx its bar of %.2f, machine at %.1fx — OVER ITS BAR AND NOT JUDGED, re-run it alone"
		% [what, got, got / maxf(bound, 0.0001), bound, machine_slack()])


## Assert a COST. **A number UNDER its bar is judged on any machine**, because
## load only ever ADDS time: the quiet-machine cost is at most what was measured,
## so under the bar here is under the bar anywhere and the machine gets no say in
## it. Only a number OVER its bar is ambiguous — that is the one case where the
## load might be the whole of the answer — and only then is the bar skipped, out
## loud. Declining in both directions threw away every valid pass as well, which
## is how a red and a green came to look the same in a busy log.
func cost_lt(got: float, bound: float, what: String) -> void:
	# A bar is a claim about the machine the game is built on. A CI runner is a
	# DIFFERENT, slower machine that is not loaded, so `can_measure_cost` says
	# "measure" and a quiet-box bar then fails on raw CPU speed: measured
	# 2026-09-22 on GitHub's runner, two `best_of` costs came in 1.02x and 1.19x
	# over bars they clear here. That is a calibration between machine classes,
	# not load, so it is a FIXED factor stated here and never `machine_slack`'s
	# open-ended widening -- a real regression still fails CI at CI_SPEED times
	# its bar, and the local gate still judges the bar itself.
	var b := bound * (CI_SPEED if OS.get_environment("CI") == "true" else 1.0)
	if got < b or can_measure_cost():
		lt(got, b, what)
	else:
		unmeasured(what, got, b)


## How much slower a CI runner may be than the machine the bars were set on.
## Measured on the first sharded CI gate: worst 1.19x. Raise it only with a
## measurement beside it.
const CI_SPEED := 2.0


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


## **A COST IN YARDSTICKS, NOT MILLISECONDS.** A bar in ms is a claim about one
## machine's clock. CI's runner is a different, slower machine, so four such bars
## failed there in a week on code that had not changed (a frame of the trample
## field at 4.244 ms against 4.0). A yardstick is a fixed piece of interpreted
## work timed beside the cost in the same process, so a slower machine slows both,
## and the cost is stated as how many yardsticks it takes.
##
## The bar is put BETWEEN two measurements, not above one: the shipped ratio and
## the ratio with the timed work planted twice over. `yard_lt` asserts the
## first is under the bar AND that the doubled one is over it, so every run
## proves the bar can still see a doubling. A bar that the doubled cost clears
## is a bar that catches nothing, and that is caught here instead of later.
##
## (How a cost is measured is the caller's: `best_of` for work that repeats,
## `middle` for samples.)
static func yardstick_us() -> float:
	return best_of(40, _yard_work)


## The yardstick itself: 400 steps of interpreted vector work, the same the
## shoulder probe's cost test times (tests/camera/test_shoulder.gd), about the
## weight of the costs it measures on this laptop (tens of microseconds).
static func _yard_work() -> void:
	var acc := Vector2.ZERO
	var pts := PackedVector2Array()
	pts.resize(64)
	for i in 400:
		var p := Vector2(float(i) * 0.37, float(i) * 0.11)
		pts[i & 63] = p
		acc += (p - pts[(i * 7) & 63]).normalized() * p.length()


## A cost, its doubling and its yardstick, timed IN TURN over `rounds` rounds,
## each the cheapest of `reps`: [work_us, doubled_us, yard_us]. Timed apart,
## a burst of load that lands on the yardstick alone moves the ratio as much as
## a regression would (measured: the interpreted yardstick read 68 us against its
## usual 40 in one run, and a doubled trample frame fell under its bar). In turn,
## the three share whatever the machine was doing, round by round.
static func yard_sample(work: Callable, doubled: Callable, yard: Callable, rounds: int = 6, reps: int = 3) -> Array[float]:
	var w := INF
	var d := INF
	var y := INF
	for r in rounds:
		y = minf(y, best_of(reps * 4, yard))
		w = minf(w, best_of(reps, work))
		d = minf(d, best_of(reps, doubled))
	return [w, d, y]


## The interpreted yardstick's work, as a Callable for `yard_sample`.
static func yard_work() -> Callable:
	return _yard_work


## The rig yardstick's work (see bone_yardstick_us), as a Callable.
static func bone_work() -> Callable:
	bone_yardstick_us()
	return _bone_work


## A yardstick for a cost that is mostly the engine's own work: posing a rig.
## An interpreted loop is a poor ruler for it, because one machine's interpreter
## and another's engine code are not slower by the same factor (measured on CI:
## the interpreted yardstick ran 2.2x this laptop's, a street of forty's step
## 1.3x, so a doubled street read UNDER a bar it cleared twice over here). This
## times what `SkinRig.pose` does, per bone, on a skeleton of its own: a
## rotation from euler angles and a position written back, 24 bones, twenty
## times over: tens of microseconds, well clear of the timer's own step.
static func bone_yardstick_us() -> float:
	if _bones == null:
		_bones = Skeleton3D.new()
		for i in 24:
			_bones.add_bone("b%d" % i)
			if i > 0:
				_bones.set_bone_parent(i, i - 1)
	return best_of(40, _bone_work)


static var _bones: Skeleton3D = null


static func _bone_work() -> void:
	for k in 20:
		for i in 24:
			var e := Vector3(float(i) * 0.07, float(k) * 0.3, 0.1)
			_bones.set_bone_pose_rotation(i, Quaternion.from_euler(e))
			_bones.set_bone_pose_position(i, Vector3(0.0, float(i) * 0.1, 0.0))


## Assert a cost in yardsticks: `us` (shipped) under `bar` x `yard`, and
## `doubled_us` (the same work twice) over it. Over the bar on a machine too busy
## to measure is said and not judged, as `cost_lt` does; a doubling that the bar
## misses is a failure, because that is the bar being wrong, not the box.
##
## **UNLESS THE DOUBLING WAS NOT SEEN AT ALL.** Twice the work reads about twice
## the time on any machine; read at under DOUBLED_SEEN times the shipped, the
## instrument failed on this run (measured: a trample frame 1337 us shipped and
## 1875 doubled beside other sessions' runs, 1.4x), and that says nothing about
## the bar. Said, not judged.
const DOUBLED_SEEN := 1.6


func yard_lt(us: float, doubled_us: float, yard: float, bar: float, what: String) -> void:
	var r := us / maxf(yard, 0.001)
	var r2 := doubled_us / maxf(yard, 0.001)
	print("  %s: %.2f yardsticks shipped, %.2f doubled, bar %.2f (%.0f us, yardstick %.1f us)" % [what, r, r2, bar, us, yard])
	if r < bar or can_measure_cost():
		lt(r, bar, "%s, in yardsticks" % what)
	else:
		unmeasured(what, r, bar)
	if r2 > bar or r2 >= r * DOUBLED_SEEN:
		gt(r2, bar, "%s: the bar sees the work doubled" % what)
	else:
		print("  UNMEASURED %s doubled: read %.2fx the shipped, not twice — the run was disturbed, re-run it alone" % [what, r2 / maxf(r, 0.0001)])


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


## **WHAT THIS NODE DREW, AND NOTHING ELSE.** `UiDraw.tape` is a GLOBAL: while
## `UiDraw.taping` is on it collects from EVERY CanvasItem that draws, so a test
## that makes one node, taps a frame and then reads the whole tape is asserting
## about whatever else the process happened to have on screen. Alone there is
## nothing else and it passes; in a full single-process run a node left alive by
## an earlier test draws into the same tape. `tests/ui/test_map.gd` failed that
## way — it asked for opaque and got 0.75, which is three of `UiDraw.stepped()`'s
## four steps and could never be the `UiTheme.GLASS` it draws with (a const, six
## hex digits, alpha 1).
##
## Filtering was already being done by hand in several files and NOWHERE
## consistently — measured across the eight files that read the tape: 45 reads,
## 13 of them filtered. `test_slate.gd` applies it to 3 of its own 13. So the
## knowledge was in the tree as scar tissue rather than as a rule, and six
## careful edits would have left the next read to rediscover it. This is the
## rule: ask the tape what a NODE drew, never what the process drew.
func drawn_by(ci: CanvasItem) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in UiDraw.tape:
		if d.get("ci") == ci:
			out.append(d)
	return out


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
