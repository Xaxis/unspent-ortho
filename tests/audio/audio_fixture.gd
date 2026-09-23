extends RefCounted
## Renders shared by the audio tests. Each key is generated once per run, and
## the first request renders the whole set the tests use on every core at once,
## so the gate pays in wall time roughly the slowest sound, not the sum.

static var _cache: Dictionary = {}
static var _facts: Dictionary = {}
static var _mutex := Mutex.new()


static func keys_used() -> Array[StringName]:
	var keys: Array[StringName] = [
		&"weather_rain", &"bed_shore", &"shore_gull:0", &"pines_creak:2", &"thunder:0",
		&"thunder_far:0", &"thunder_far:1", &"hit_plate:1", &"hit_plate:2",
		&"step_gravel:2", &"moss_drip:3", &"heat_tick:1", &"bed_hum",
	]
	for name: StringName in SoundBank.SHEET:
		var cat := SoundBank.category_of(name)
		if cat in [&"event", &"ui", &"machine", &"step"]:
			keys.append(SoundBank.key_for(name, 0))
	return keys


static func baked(key: StringName) -> SoundBank.Baked:
	if _cache.is_empty():
		warm(keys_used())
	if not _cache.has(key):
		_cache[key] = SoundBank.render(key)
	return _cache[key]


static func warm(keys: Array[StringName]) -> void:
	var todo: Array[StringName] = []
	for k in keys:
		if not _cache.has(k) and not todo.has(k):
			todo.append(k)
	var done := {}
	var facts := {}
	var task := func(i: int) -> void:
		var b := SoundBank.render(todo[i])
		# The costly measures are taken here too, on every core at once.
		var f := {
			"heard": SoundMix.heard_db(b),
			"lf120": Synth.low_energy_ratio(b.samples, b.rate, 120.0),
			"peak": Synth.peak(b.samples),
		}
		_mutex.lock()
		done[todo[i]] = b
		facts[todo[i]] = f
		_mutex.unlock()
	# The first one alone, on this thread, before the rest go to every core:
	# SoundBank's header, on cold code and the pool.
	if not todo.is_empty():
		task.call(0)
	if todo.size() > 1:
		var group := WorkerThreadPool.add_group_task(func(i: int) -> void: task.call(i + 1), todo.size() - 1, -1, true, "audio test renders")
		WorkerThreadPool.wait_for_group_task_completion(group)
	for k: StringName in done:
		_cache[k] = done[k]
		_facts[k] = facts[k]


## {heard, lf120, peak} of a key, measured once.
static func facts(key: StringName) -> Dictionary:
	if not _facts.has(key):
		var b := baked(key)
		if not _facts.has(key):
			_facts[key] = {"heard": SoundMix.heard_db(b), "lf120": Synth.low_energy_ratio(b.samples, b.rate, 120.0), "peak": Synth.peak(b.samples)}
	return _facts[key]


## Units of score work one frame may advance. A unit is a block of voices and
## effects (ScoreRender.BLOCK samples, about a millisecond of GDScript) or a
## slice of a finishing stage (POST_SLICE samples, about half of one), so the
## budget buys a couple of dozen of the cheapest; a stage that ran whole would
## be a hundred and fifty of them, or two thousand, which is the regression this
## guards. A step never BEGINS a unit that would carry it past its budget, so a
## machine under load does fewer units a frame, never more: this measure holds
## whatever else the machine is doing, and it is the one that is asserted.
const MAX_UNITS := 64
## Microseconds a frame may overshoot the budget by: the unit of work it was in
## the middle of, and the cost of looking at the clock.
const SLACK := 3000
## A frame the OS took away is not a frame the score held, so a run whose clock
## reads badly is made again. The work is the same every time; the clock is not.
const ATTEMPTS := 3


## Holds a no-thread build to its frame budget, by the work it advances a frame
## (above) and by the clock. The clock cannot say whether one long frame was the
## score's doing or the machine's — this gate runs three shards and four shots
## at once, and frames go missing — so what is asserted of it is the MIDDLE
## frame, which a handful of stolen frames cannot move but a build that stopped
## slicing would blow by a factor of ten. `run` builds the thing and returns
## [per-frame usec, per-frame units].
static func judge_frames(t: TestCase, run: Callable, what: String) -> void:
	# The unit count below is the real guarantee and stays exact whatever else the
	# machine is doing. The clock is not: eight builders on one laptop stretch every
	# frame three or four times over, so the wall-clock half is scaled by what this
	# run is actually getting of a processor (TestCase.machine_slack).
	var budget := int(SoundBank.SCORE_BUDGET_USEC * TestCase.machine_slack())
	var worst_units := 0
	var frames := 0
	var median := 0
	var worst_usec := 0
	for attempt in ATTEMPTS:
		var got: Array = run.call()
		var times: PackedInt32Array = got[0]
		var units: PackedInt32Array = got[1]
		worst_units = 0
		worst_usec = 0
		frames = times.size()
		for i in frames:
			worst_usec = maxi(worst_usec, times[i])
			worst_units = maxi(worst_units, units[i])
		var sorted := times.duplicate()
		sorted.sort()
		median = sorted[sorted.size() / 2] if not sorted.is_empty() else 0
		if median <= budget + SLACK:
			break
	t.gt(float(frames), 8.0, "%s: built across many frames, not in one (%d)" % [what, frames])
	t.check(worst_units <= MAX_UNITS, "%s: no frame advanced more than a slice of the work (worst %d units, %d allowed)" % [what, worst_units, MAX_UNITS])
	t.lt(float(median), float(budget + SLACK), "%s: the middle frame of %d is %d us (budget %d; the worst on the clock was %d)" % [what, frames, median, budget, worst_usec])
