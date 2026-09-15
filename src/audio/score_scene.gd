class_name ScoreScene
## Minutes of the score rendered offline through the conductor's own rules, the
## stems' own bakes, the Music bus level and its night/fog low-pass, so how the
## score evolves can be looked at (tools/audio.sh --score) and tested.
##
## A scene is a Dictionary of timelines (times in seconds; values between two
## points are interpolated, kinds hold until the next point):
##   seed, secs, rate (output, default 22050), hour (at 0 s; the clock runs
##   Tuning.MINUTES_PER_SECOND), step (conductor tick, default BLOCK)
##   lands:    [[t, {id: weight}], ...]
##   weather:  [[t, kind, strength], ...]
##   danger:   [[t, v], ...]   grid: [[t, v], ...]   sentinel: [[t, v], ...]
## timeline() runs only the rules; render() also mixes the sound: stereo,
## interleaved.

const BLOCK := 0.05


static func _at(points: Array, t: float, default: float = 0.0) -> float:
	if points.is_empty():
		return default
	if t <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if t <= float(b[0]):
			var u := (t - float(a[0])) / maxf(1e-6, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), u)
	return float(points[-1][1])


static func _weights_at(points: Array, t: float) -> Dictionary:
	if points.is_empty():
		return {&"coast": 1.0}
	var a: Array = points[0]
	var b: Array = points[0]
	for i in points.size():
		if float(points[i][0]) <= t:
			a = points[i]
			b = points[mini(i + 1, points.size() - 1)]
	var u := 0.0
	if b != a:
		u = clampf((t - float(a[0])) / maxf(1e-6, float(b[0]) - float(a[0])), 0.0, 1.0)
	var out := {}
	for k: StringName in (a[1] as Dictionary):
		out[k] = float(out.get(k, 0.0)) + float(a[1][k]) * (1.0 - u)
	for k: StringName in (b[1] as Dictionary):
		out[k] = float(out.get(k, 0.0)) + float(b[1][k]) * u
	return out


static func _weather_at(points: Array, t: float) -> Dictionary:
	if points.is_empty():
		return {"kind": &"clear", "strength": 0.0}
	var kind: StringName = points[0][1]
	var s := float(points[0][2])
	for i in points.size():
		var p: Array = points[i]
		if float(p[0]) <= t:
			kind = p[1]
			s = float(p[2])
			if i + 1 < points.size():
				var q: Array = points[i + 1]
				var u := clampf((t - float(p[0])) / maxf(1e-6, float(q[0]) - float(p[0])), 0.0, 1.0)
				# Strength eases toward the next point's, the kind holds.
				s = lerpf(float(p[2]), float(q[2]), u) if q[1] == kind else float(p[2]) * (1.0 - u)
	return {"kind": kind, "strength": s}


## The rules over time: every stem's level per block, the cues, and the inputs.
static func timeline(scene: Dictionary) -> Dictionary:
	var secs := float(scene.get("secs", 60.0))
	var step := float(scene.get("step", BLOCK))
	var blocks := ceili(secs / step)
	var conductor := ScoreConductor.new(int(scene.get("seed", 1)))
	var hour0 := float(scene.get("hour", 12.0))
	var lanes := {}
	var cues: Array = []
	var cutoff := PackedFloat32Array()
	var form := PackedFloat32Array()
	var danger := PackedFloat32Array()
	var weathers: Array = []
	for b in blocks:
		var t := b * step
		var weather := _weather_at(scene.get("weather", []), t)
		var input := {
			"weights": _weights_at(scene.get("lands", []), t),
			"hour": fposmod(hour0 + t * Tuning.MINUTES_PER_SECOND / 60.0, 24.0),
			"weather": weather,
			"danger": _at(scene.get("danger", []), t),
			"grid": _at(scene.get("grid", []), t),
			"sentinel": {"strength": _at(scene.get("sentinel", []), t)},
		}
		conductor.tick(step, input)
		for key: StringName in conductor.levels:
			if not lanes.has(key):
				var lane := PackedFloat32Array()
				lane.resize(blocks)
				lane.fill(0.0)
				lanes[key] = lane
			var l: PackedFloat32Array = lanes[key]
			l[b] = conductor.levels[key]
		for c: Array in conductor.cues:
			cues.append([conductor.time, c[0], c[1]])
		cutoff.append(ScoreConductor.bus_cutoff(conductor.night, weather))
		form.append(conductor.effective)
		danger.append(conductor.danger)
		weathers.append(weather)
	return {"lanes": lanes, "cues": cues, "blocks": blocks, "step": step, "cutoff": cutoff, "form": form, "danger": danger, "weather": weathers, "secs": secs}


## Bakes stems on every core; key -> Baked.
static func bake(keys: Array[StringName]) -> Dictionary:
	var done := {}
	var mutex := Mutex.new()
	var task := func(i: int) -> void:
		var b := SoundBank.render(keys[i])
		mutex.lock()
		done[keys[i]] = b
		mutex.unlock()
	var group := WorkerThreadPool.add_group_task(task, keys.size(), -1, true, "score scene")
	WorkerThreadPool.wait_for_group_task_completion(group)
	return done


## The rules and the sound. `baked` may bring stems already rendered.
static func render(scene: Dictionary, baked: Dictionary = {}) -> Dictionary:
	var tl := timeline(scene)
	var lanes: Dictionary = tl["lanes"]
	var cues: Array = tl["cues"]
	var wanted: Array[StringName] = []
	for key: StringName in lanes:
		var lane: PackedFloat32Array = lanes[key]
		for v in lane:
			if v > 0.002:
				wanted.append(key)
				break
	for c: Array in cues:
		if not wanted.has(c[1]):
			wanted.append(c[1])
	var missing: Array[StringName] = []
	for k in wanted:
		if not baked.has(k):
			missing.append(k)
	var all := baked.duplicate()
	if not missing.is_empty():
		var more := bake(missing)
		for k: StringName in more:
			all[k] = more[k]
	var rate := int(scene.get("rate", 22050))
	var frames := roundi(float(tl["secs"]) * rate)
	var out := PackedFloat32Array()
	out.resize(frames * 2)
	out.fill(0.0)
	var bus := db_to_linear(SoundMix.bus_db(&"Music"))
	var step := float(tl["step"])
	for key: StringName in lanes:
		if not wanted.has(key):
			continue
		_lay_loop(out, rate, all[key], lanes[key], step, bus)
	for c: Array in cues:
		_lay_cue(out, rate, all[c[1]], float(c[0]), float(c[2]) * bus)
	_bus_lowpass(out, rate, tl["cutoff"], step)
	return {"samples": out, "rate": rate, "timeline": tl, "baked": all}


## A looping stem at the music clock's place in it (t mod its length, so every
## loop keeps to the bar lines), under its level lane.
static func _lay_loop(out: PackedFloat32Array, rate: int, b: SoundBank.Baked, lane: PackedFloat32Array, step: float, bus: float) -> void:
	var src := b.samples
	var ch := 2 if b.stereo else 1
	var m := src.size() / ch
	var g := db_to_linear(b.gain_db) * bus
	var inc := float(b.rate) / rate
	var frames := out.size() / 2
	var per_block := step * rate
	var blocks := lane.size()
	for i in frames:
		var bf := i / per_block
		var b0 := mini(floori(bf), blocks - 1)
		var b1 := mini(b0 + 1, blocks - 1)
		var lvl := lerpf(lane[b0], lane[b1], bf - floorf(bf))
		if lvl < 1e-5:
			continue
		var pos := fposmod(i * inc, float(m))
		var k := floori(pos)
		var f := pos - k
		var k1 := (k + 1) % m
		var gl := lvl * g
		if ch == 2:
			out[i * 2] += (src[k * 2] + (src[k1 * 2] - src[k * 2]) * f) * gl
			out[i * 2 + 1] += (src[k * 2 + 1] + (src[k1 * 2 + 1] - src[k * 2 + 1]) * f) * gl
		else:
			var v := (src[k] + (src[k1] - src[k]) * f) * gl
			out[i * 2] += v
			out[i * 2 + 1] += v


static func _lay_cue(out: PackedFloat32Array, rate: int, b: SoundBank.Baked, at: float, gain: float) -> void:
	var src := b.samples
	var ch := 2 if b.stereo else 1
	var m := src.size() / ch
	var g := db_to_linear(b.gain_db) * gain
	var inc := float(b.rate) / rate
	var frames := out.size() / 2
	var start := roundi(at * rate)
	var n := mini(frames - start, floori((m - 1) / inc))
	for j in maxi(0, n):
		var pos := j * inc
		var k := floori(pos)
		var f := pos - k
		var i := start + j
		if ch == 2:
			out[i * 2] += (src[k * 2] + (src[k * 2 + 2] - src[k * 2]) * f) * g
			out[i * 2 + 1] += (src[k * 2 + 1] + (src[k * 2 + 3] - src[k * 2 + 1]) * f) * g
		else:
			var v := (src[k] + (src[k + 1] - src[k]) * f) * g
			out[i * 2] += v
			out[i * 2 + 1] += v


## The Music bus's low-pass, its corner moved per block as the running game moves it.
static func _bus_lowpass(out: PackedFloat32Array, rate: int, cutoff: PackedFloat32Array, step: float) -> void:
	var frames := out.size() / 2
	var per_block := roundi(step * rate)
	for side in 2:
		var z1 := 0.0
		var z2 := 0.0
		for start in range(0, frames, per_block):
			var c := Synth.coeffs_lowpass(rate, cutoff[mini(cutoff.size() - 1, start / per_block)])
			for i in range(start, mini(frames, start + per_block)):
				var x := out[i * 2 + side]
				var y := c[0] * x + z1
				z1 = c[1] * x - c[3] * y + z2
				z2 = c[2] * x - c[4] * y
				out[i * 2 + side] = y


## Loudest half-second RMS of a stretch of the mix, dB relative to the weather bed.
static func heard_db(out: PackedFloat32Array, rate: int, from_s: float, to_s: float) -> float:
	var a := Synth.samples(rate, from_s) * 2
	var b := mini(out.size(), Synth.samples(rate, to_s) * 2)
	var r := Synth.loudest_rms(out.slice(a, b), rate * 2, 0.5)
	return 20.0 * log(maxf(1e-9, r)) / log(10.0) - SoundMix.REF_DBFS


## RMS of a stretch, dB relative to the weather bed (how full it is on average).
static func mean_db(out: PackedFloat32Array, rate: int, from_s: float, to_s: float) -> float:
	var a := Synth.samples(rate, from_s) * 2
	var b := mini(out.size(), Synth.samples(rate, to_s) * 2)
	var r := Synth.rms(out, a, maxi(1, b - a))
	return 20.0 * log(maxf(1e-9, r)) / log(10.0) - SoundMix.REF_DBFS


## Three minutes walking from one landscape into another: pure `from` for a
## minute, the ecotone over the next, pure `to` for the last.
static func crossing(from: StringName, to: StringName, seed_value: int = 1) -> Dictionary:
	var s := excerpt(from, seed_value)
	s["lands"] = [[0.0, {from: 1.0}], [60.0, {from: 1.0}], [90.0, {from: 0.5, to: 0.5}], [120.0, {to: 1.0}]]
	s["danger"] = []
	s["grid"] = []
	s["sentinel"] = []
	s["weather"] = [[0.0, &"clear", 0.0]]
	return s


## The scripted three minutes tools/audio.sh renders for a landscape: its air
## at an hour that suits it, the pad and pulse arriving, its weather coming in,
## machines closing and passing, and an installation at the end.
static func excerpt(land: StringName, seed_value: int = 1) -> Dictionary:
	var arcs := {
		&"coast": {"hour": 10.0, "weather": [[0.0, &"grey", 0.3], [70.0, &"rain", 0.0], [110.0, &"rain", 0.8], [180.0, &"rain", 0.5]]},
		&"moss": {"hour": 16.5, "weather": [[0.0, &"fog", 0.2], [80.0, &"fog", 0.9], [180.0, &"fog", 0.7]]},
		&"pinewood": {"hour": 19.2, "weather": [[0.0, &"clear", 0.0], [60.0, &"rain", 0.0], [110.0, &"rain", 0.9], [180.0, &"rain", 0.6]]},
		&"snowfield": {"hour": 13.0, "weather": [[0.0, &"clear", 0.0], [60.0, &"snow", 0.0], [120.0, &"snow", 1.0], [180.0, &"snow", 0.8]]},
		&"bonelands": {"hour": 12.0, "weather": [[0.0, &"heat", 0.3], [90.0, &"dust", 0.0], [130.0, &"dust", 0.8], [180.0, &"dust", 0.6]]},
		&"burning": {"hour": 19.5, "weather": [[0.0, &"heat", 0.4], [70.0, &"ash", 0.0], [120.0, &"ash", 0.9], [180.0, &"ash", 0.9]]},
	}
	var arc: Dictionary = arcs.get(land, arcs[&"coast"])
	return {
		"seed": seed_value, "secs": 180.0, "hour": arc["hour"], "weather": arc["weather"],
		"lands": [[0.0, {land: 1.0}]],
		"danger": [[0.0, 0.0], [118.0, 0.0], [124.0, 1.0], [146.0, 1.0], [150.0, 0.0]],
		"grid": [[0.0, 0.0], [158.0, 0.0], [164.0, 1.0], [180.0, 1.0]],
		"sentinel": [[0.0, 0.0], [168.0, 0.0], [170.0, 1.0]],
	}
