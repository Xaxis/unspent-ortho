class_name SoundScene
## What the player would hear at a place, rendered offline with the running
## mix's own rules (SoundMix levels, the audio system's fades, the sheet's
## gains and the bus levels), so a crossfade, a night or a machine walking up
## can be looked at and tested without a sound card.
##
## A scene is a Dictionary:
##   seed, size       the world (WorldGen.generate)
##   at: Vector2      where the listener starts (default: spawn)
##   walk: Vector2    tiles per second the listener moves (footfalls follow)
##   hour: float      world hour at the start (the clock runs 1 minute a second)
##   weather: {kind, strength, wind} or {} for the sky's rules
##   secs: float      how long
##   machine: {kind, from, to}  one machine whose distance goes from -> to tiles
##   layers: which of [beds, steps, machine] to render (default all)
## render() returns {samples (mono, RATE), rate, lanes: {bed: PackedFloat32Array
## per block}, block (s), path (Array of Vector2 per block), countries}.

const RATE := 44100
const BLOCK := 0.05


static func render(scene: Dictionary, world: WorldData = null, baked: Dictionary = {}) -> Dictionary:
	if world == null:
		world = WorldGen.generate(int(scene.get("seed", 1)), int(scene.get("size", Tuning.WORLD_SIZE)))
	var secs := float(scene.get("secs", 12.0))
	var walk: Vector2 = scene.get("walk", Vector2.ZERO)
	var machine: Dictionary = scene.get("machine", {})
	var layers: Array = scene.get("layers", [&"beds", &"steps", &"machine"])
	var timeline := levels_over_time(scene, world)
	var lanes: Dictionary = timeline["lanes"]
	var path: Array[Vector2] = timeline["path"]
	# Bake what is heard (in parallel) unless the caller brought it, then lay it down.
	var wanted: Array[StringName] = []
	if &"beds" in layers:
		for bed: StringName in lanes:
			var lane: PackedFloat32Array = lanes[bed]
			for v in lane:
				if v > 0.005:
					wanted.append(bed)
					break
	var steps := _footfalls(world, path, walk.length()) if &"steps" in layers else []
	for st: Array in steps:
		if not wanted.has(st[1]):
			wanted.append(st[1])
	var machine_key := StringName("machine_" + String(machine.get("kind", &"watcher")))
	if not machine.is_empty() and &"machine" in layers:
		wanted.append(machine_key)
	var missing: Array[StringName] = []
	for k in wanted:
		if not baked.has(k):
			missing.append(k)
	if not missing.is_empty():
		var more := bake(missing)
		baked = baked.duplicate()
		for k: StringName in more:
			baked[k] = more[k]
	var n := Synth.samples(RATE, secs)
	var out := Synth.buffer(n)
	for bed: StringName in wanted:
		if not lanes.has(bed):
			continue
		var bk: SoundBank.Baked = baked[bed]
		var g := db_to_linear(bk.gain_db + SoundMix.bus_db(bk.bus))
		# Start inside the loop, as the system does, so beds never phase together.
		_lay_loop(out, bk, lanes[bed], g, Rng.hash01(int(bed.hash()), 0, 0x8e))
	for st: Array in steps:
		var key := SoundBank.key_for(st[1], st[2])
		var bk: SoundBank.Baked = baked.get(key, baked.get(st[1]))
		if bk == null:
			continue
		Synth.add(out, _resample(bk.samples, bk.rate), Synth.samples(RATE, st[0]), db_to_linear(bk.gain_db + SoundMix.bus_db(bk.bus)))
	if not machine.is_empty() and &"machine" in layers:
		_lay_machine(out, baked[machine_key], machine)
	return {"samples": out, "rate": RATE, "lanes": lanes, "block": BLOCK, "path": path, "countries": timeline["countries"]}


## The rules over time, without a sample of sound: every bed's smoothed level
## per BLOCK, the path walked, and the country underfoot. A scene starts
## settled (the running game fades in from silence once, at start; that is
## not what a scene is looking at).
static func levels_over_time(scene: Dictionary, world: WorldData) -> Dictionary:
	var secs := float(scene.get("secs", 12.0))
	var blocks := ceili(secs / BLOCK)
	var start: Vector2 = scene.get("at", world.spawn)
	var walk: Vector2 = scene.get("walk", Vector2.ZERO)
	var hour0 := float(scene.get("hour", Tuning.START_HOUR))
	var forced: Dictionary = scene.get("weather", {})
	var lanes := {}
	var path: Array[Vector2] = []
	var countries: Array[int] = []
	var levels := {}
	var sea := {}
	var river := {}
	var remote := 0.0
	var weather := {}
	var fade := 1.0 - exp(-BLOCK / SoundMix.BED_FADE)
	for b in blocks:
		var t := b * BLOCK
		var p := start + walk * t
		p = Vector2(clampf(p.x, 0.0, world.size - 1.0), clampf(p.y, 0.0, world.size - 1.0))
		path.append(p)
		var minutes := hour0 * 60.0 + t * Tuning.MINUTES_PER_SECOND
		var here := SoundMix.dominant_country(world, p)
		countries.append(int(here["country"]))
		if b % roundi(SoundMix.SCAN_EVERY / BLOCK) == 0:
			sea = SoundMix.sea_near(world, p)
			river = SoundMix.river_near(world, p)
			remote = SoundMix.remoteness(world, p)
			weather = forced if not forced.is_empty() else SoundMix.weather_at(world.seed_value, minutes, int(here["country"]))
		var extra := {"hour": fposmod(minutes / 60.0, 24.0), "remote": remote, "tide": SoundMix.tide_at(minutes)}
		var targets := SoundMix.bed_levels(world, p, weather, sea, river, t, extra)
		for bed: StringName in targets:
			if not levels.has(bed):
				levels[bed] = float(targets[bed]) if b == 0 else 0.0
				var fresh := PackedFloat32Array()
				fresh.resize(blocks)
				fresh.fill(0.0)
				lanes[bed] = fresh
		for bed: StringName in levels:
			var lvl: float = levels[bed]
			lvl += (float(targets.get(bed, 0.0)) - lvl) * fade
			levels[bed] = lvl
			var lane: PackedFloat32Array = lanes[bed]
			lane[b] = lvl
			lanes[bed] = lane
	return {"lanes": lanes, "path": path, "countries": countries}


## Bakes keys on every core; returns key -> Baked. Footfall families bake all takes.
static func bake(keys: Array[StringName]) -> Dictionary:
	var todo: Array[StringName] = []
	for k in keys:
		var name := SoundBank.base_name(k)
		for v in maxi(1, SoundBank.variants(name)):
			var key := SoundBank.key_for(name, v)
			if not todo.has(key):
				todo.append(key)
	var done := {}
	var mutex := Mutex.new()
	var task := func(i: int) -> void:
		var b := SoundBank.render(todo[i])
		mutex.lock()
		done[todo[i]] = b
		mutex.unlock()
	var group := WorkerThreadPool.add_group_task(task, todo.size(), -1, true, "sound scene")
	WorkerThreadPool.wait_for_group_task_completion(group)
	for k: StringName in keys:
		if not done.has(k):
			done[k] = done.get(SoundBank.key_for(k, 0))
	return done


## [seconds, step name, variant] for a listener walking `speed` tiles/s.
static func _footfalls(world: WorldData, path: Array[Vector2], speed: float) -> Array:
	var out := []
	if speed < 0.1:
		return out
	var stride := SoundMix.STRIDE_RUN if speed > (Tuning.WALK_SPEED + Tuning.RUN_SPEED) * 0.5 else SoundMix.STRIDE_WALK
	var gap := maxf(SoundMix.STEP_MIN_GAP, stride / speed)
	var t := gap * 0.3
	var k := 0
	while t < path.size() * BLOCK:
		var p: Vector2 = path[mini(path.size() - 1, floori(t / BLOCK))]
		var name := SoundEffects.step_name(world.ground_at(floori(p.x), floori(p.y)))
		out.append([t, name, k])
		t += gap
		k += 1
	return out


static func _resample(src: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	return src if rate == RATE else Synth.stretch(src, float(RATE) / rate)


## A looping bake laid under a per-block level lane (levels interpolated
## between blocks, so a fade is a ramp, not steps).
static func _lay_loop(out: PackedFloat32Array, bk: SoundBank.Baked, lane: PackedFloat32Array, gain: float, offset01: float) -> void:
	var src := bk.samples
	var m := src.size()
	var step := float(bk.rate) / RATE
	var pos := offset01 * m
	var per_block := BLOCK * RATE
	for i in out.size():
		var bf := i / per_block
		var b0 := mini(floori(bf), lane.size() - 1)
		var b1 := mini(b0 + 1, lane.size() - 1)
		var lvl := lerpf(lane[b0], lane[b1], bf - floorf(bf))
		if lvl > 1e-5:
			var k := floori(pos)
			var f := pos - k
			var a := src[k % m]
			var c := src[(k + 1) % m]
			out[i] += (a + (c - a) * f) * lvl * gain
		pos += step
		if pos >= m:
			pos -= m


## The one machine: level by distance, and the same distance as a low-pass
## before the gain (a two-pole filter whose corner moves per block).
static func _lay_machine(out: PackedFloat32Array, bk: SoundBank.Baked, machine: Dictionary) -> void:
	var kind := StringName(machine.get("kind", &"watcher"))
	var racket: float = SoundMachines.RACKET.get(kind, 12.0)
	var d0 := float(machine.get("from", racket))
	var d1 := float(machine.get("to", 0.0))
	var src := bk.samples
	var g := db_to_linear(bk.gain_db + SoundMix.bus_db(bk.bus))
	var per_block := roundi(BLOCK * RATE)
	var z1 := 0.0
	var z2 := 0.0
	for start in range(0, out.size(), per_block):
		var d := lerpf(d0, d1, float(start) / out.size())
		var lvl := SoundMix.machine_level(d, racket)
		var c := Synth.coeffs_lowpass(RATE, SoundMix.machine_cutoff(d, racket))
		for i in range(start, mini(out.size(), start + per_block)):
			var x := src[i % src.size()]
			var y := c[0] * x + z1
			z1 = c[1] * x - c[3] * y + z2
			z2 = c[2] * x - c[4] * y
			out[i] += y * lvl * g


## The loudest-0.5 s RMS of a stretch of the mix, in dB relative to the weather
## bed at full strength (the sheet's measure, after the buses).
static func heard_db(samples: PackedFloat32Array, from_s: float, to_s: float) -> float:
	var a := Synth.samples(RATE, from_s)
	var b := mini(samples.size(), Synth.samples(RATE, to_s))
	var r := Synth.loudest_rms(samples.slice(a, b), RATE, 0.5)
	return 20.0 * log(maxf(1e-9, r)) / log(10.0) - SoundMix.REF_DBFS


## A walk across the nearest border to `near`: {at, walk} that starts `lead`
## tiles inside one country and ends as far inside the other, at `speed`.
static func border_walk(world: WorldData, near: Vector2, speed: float = 5.0, lead: float = 18.0) -> Dictionary:
	var best := INF
	var best_at := near
	var r := 60
	for y in range(maxi(1, floori(near.y) - r), mini(world.size - 1, floori(near.y) + r)):
		for x in range(maxi(1, floori(near.x) - r), mini(world.size - 1, floori(near.x) + r)):
			var i := y * world.size + x
			var c: int = world.country[i]
			if c == Country.SEA or world.level[i] <= 0:
				continue
			var e: int = world.country[i + 1]
			if e != c and e != Country.SEA:
				var d := Vector2(x, y).distance_to(near)
				if d < best:
					best = d
					best_at = Vector2(x + 0.5, y + 0.5)
	# Across the border: from the lower-x country into the higher.
	var dir := Vector2.RIGHT
	return {"at": best_at - dir * lead, "walk": dir * speed, "secs": lead * 2.0 / speed}
