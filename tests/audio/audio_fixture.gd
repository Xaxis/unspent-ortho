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
	var group := WorkerThreadPool.add_group_task(task, todo.size(), -1, true, "audio test renders")
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


## Holds a no-thread build to its frame budget. A stem built in slices takes
## dozens of frames that are all alike, so the FRAME COUNT and the MIDDLE frame
## are the measures: a build that let a stage run whole would take a handful of
## frames and blow both. The worst frame is not judged and the bounds are loose
## — on a machine running eight builders at once world gen itself goes from one
## second to ten, and a frame the OS took away is not a frame the score held.
## What the slicing going would look like is a handful of frames, not a stall.
static func judge_frames(t: TestCase, times: PackedInt32Array, what: String) -> void:
	var budget := SoundBank.SCORE_BUDGET_USEC
	t.gt(float(times.size()), 8.0, "%s: built across many frames, not in one (%d)" % [what, times.size()])
	if times.is_empty():
		return
	var sorted := times.duplicate()
	sorted.sort()
	var median: int = sorted[sorted.size() / 2]
	var stolen := 0
	for us in times:
		if us > budget * 4:
			stolen += 1
	t.lt(float(median), float(budget * 4), "%s: the middle frame is %d us (budget %d us)" % [what, median, budget])
	var allowed := maxi(1, roundi(times.size() * 0.4))
	t.check(stolen <= allowed, "%s: %d of %d frames ran far past it, %d allowed (worst %d us)" % [what, stolen, times.size(), allowed, sorted[-1]])
