extends TestCase
## The score's engine and its stems: a stem is the same samples however it is
## sliced across frames, loops run seamlessly into themselves, every landscape
## has its own key, mode and rhythm, loop lengths keep to the bar and never line
## up, and stems sit at their levels with nothing under 120 Hz.


## A small stem with every instrument and every effect in it, a note wrapping
## past the end of the loop and a held drone.
static func _small(stereo: bool) -> ScoreRender:
	var j := ScoreRender.new(&"score_test", 16000, stereo, true, roundi(1.2 * 16000))
	j.highpass = 110.0
	j.hold(ScoreVoices.Analog, {"freqs": [220.0, 330.0], "unison": 2, "detune": 7.0, "cut": 900.0, "sweep": 0.8, "sweep_hz": 0.9, "seed": 3})
	j.hold(ScoreVoices.Sine, {"freqs": [880.0, 1320.0], "amps": [0.1, 0.05], "am_hz": 1.7, "am_depth": 0.8})
	j.note(0.9, ScoreVoices.Analog, {"freqs": [440.0], "wave": 1, "pwm": 0.2, "cut": 1500.0, "cut_env": 2.0, "a": 0.01, "hold": 0.3, "r": 0.2, "vib": 20.0, "drive": 0.5})
	j.note(0.2, ScoreVoices.Fm, {"freq": 660.0, "ratio": 3.5, "index": 2.0, "idecay": 0.4, "ratio2": 7.0, "index2": 0.3, "hold": 0.4, "r": 0.3, "detune": 5.0})
	j.note(0.5, ScoreVoices.Hiss, {"shape": 1, "hold": 0.6, "cut": 2000.0, "q": 2.0, "sweep": 1.0, "sweep_hz": 1.5, "density": 400.0, "seed": 9})
	j.note(0.7, ScoreVoices.Ping, {"freq": 1760.0, "modes": [[1.0, 1.0, 0.4], [2.76, 0.3, 0.2]], "pan": 0.5})
	j.fx(ScoreFx.Tape, {"delay_ms": 6.0, "depth_ms": 1.5, "hz": 1.3, "mix": 0.5})
	j.fx(ScoreFx.Echo, {"time": 0.15, "fb": 0.4, "wet": 0.3})
	j.fx(ScoreFx.Hall, {"t60": 0.6, "wet": 0.3})
	j.fx(ScoreFx.Tone, {"hz": 5000.0, "sweep": 0.5, "sweep_hz": 0.9})
	return j


func test_a_stem_is_the_same_however_it_is_sliced_across_frames() -> void:
	for stereo: bool in [false, true]:
		var whole := _small(stereo)
		whole.run()
		var sliced := _small(stereo)
		var frames := 0
		# A zero budget stops after every block and every slice: the most frames
		# a browser without threads could ever spread it over.
		while not sliced.step(0):
			frames += 1
		gt(float(frames), 20.0, "it really was spread over many frames (%d)" % frames)
		eq(sliced.samples.size(), whole.samples.size(), "same length")
		check(sliced.samples == whole.samples, "same samples, stereo %s" % stereo)
		check(sliced.pcm == whole.pcm, "same 16-bit data")
		check(whole.raw_peak > 0.01, "it made sound")


## The clock is read between units small enough that a frame never waits: a
## step with no budget left does exactly one (a block of voices, or a slice of
## the high-pass, its priming, the measure or the encode), however a stem is
## made. Load-proof, unlike a stopwatch.
func test_a_step_past_its_budget_does_one_small_unit() -> void:
	lt(float(ScoreRender.BLOCK), 257.0, "a block of voices is short")
	lt(float(ScoreRender.POST_SLICE), 2049.0, "a finishing slice is short")
	var j := _small(true)
	var post := {}
	var steps := 0
	while true:
		var st := j.stage
		var fin := j.step(0)
		check(j.last_units <= 1, "one unit per step with no budget (stage %d did %d)" % [st, j.last_units])
		post[st] = int(post.get(st, 0)) + 1
		steps += 1
		if fin:
			break
	var channels := 2
	# Each high-pass pass primes over PRIME samples of the tail, then runs the loop.
	var hp_slices := channels * 2 * (ceili(float(mini(ScoreRender.PRIME, j.frames)) / ScoreRender.POST_SLICE) + ceili(float(j.frames) / ScoreRender.POST_SLICE))
	gt(float(post.get(ScoreRender.Stage.HIGHPASS, 0)), float(hp_slices - 1), "the high-pass and its priming are sliced (%d steps)" % post.get(ScoreRender.Stage.HIGHPASS, 0))
	gt(float(post.get(ScoreRender.Stage.ENCODE, 0)), float(ceili(float(j.frames) / ScoreRender.POST_SLICE)), "so is the encode")


func test_a_loop_runs_seamlessly_into_itself() -> void:
	var j := _small(true)
	j.run()
	var n := j.frames
	for side in 2:
		var ch := PackedFloat32Array()
		ch.resize(n)
		for i in n:
			ch[i] = j.samples[i * 2 + side]
		lt(Synth.seam_ratio(ch), 2.5, "side %d: the frame after the last is the first" % side)


func test_every_stem_is_planned_the_same_every_time() -> void:
	for land in ScoreLandscapes.ids():
		for layer: StringName in ScoreStems.LAYERS:
			for v in int(ScoreStems.LAYERS[layer]["variants"]):
				var key := ScoreStems.key_for(land, layer, v)
				var a := ScoreStems.job(key)
				var b := ScoreStems.job(key)
				check(str(a.notes) == str(b.notes) and a.effects.size() == b.effects.size() and a.frames == b.frames, "%s plans the same" % key)
				check(not a.notes.is_empty() or a.effects.size() > 0, "%s has something in it" % key)


func test_loops_keep_to_the_bar_and_their_lengths_never_line_up() -> void:
	var sounding: Array[StringName] = [&"drone", &"pad", &"pulse", &"texture"]
	var lcm := 1
	for layer in sounding:
		var bars := int(ScoreStems.LAYERS[layer]["bars"])
		lcm = lcm * bars / _gcd(lcm, bars)
	gt(float(lcm) * ScoreLandscapes.BAR, 3600.0, "the loops that sound together come round together only after an hour (%d bars)" % lcm)
	for land in ScoreLandscapes.ids():
		for layer: StringName in ScoreStems.LAYERS:
			var key := ScoreStems.key_for(land, layer, 0)
			var cat: Dictionary = SoundBank.CATEGORIES[ScoreStems.LAYERS[layer]["category"]]
			var j := ScoreStems.job(key)
			if bool(cat["loop"]):
				eq(j.frames, roundi(int(ScoreStems.LAYERS[layer]["bars"]) * ScoreLandscapes.BAR * int(cat["rate"])), "%s is whole bars" % key)
				for nt: Array in j.notes:
					lt(float(ScoreVoices.frames_of(nt[1], nt[2], j.rate)), float(j.frames), "%s: every note is shorter than its loop" % key)
			else:
				eq(j.frames, 0, "%s is a one-shot, as long as its notes" % key)
				var last := 0
				for nt: Array in j.notes:
					last = maxi(last, int(nt[0]))
				lt(float(last) / j.rate, 4.0 * ScoreLandscapes.BAR, "%s says what it says inside four bars" % key)


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := a % b
		a = b
		b = t
	return a


func test_every_landscape_has_its_own_key_mode_and_rhythm() -> void:
	var seen := {}
	for land in ScoreLandscapes.ids():
		var s := ScoreLandscapes.spec(land)
		var sig := "%d %s %d" % [int(s["tonic"]) % 12, s["mode"], int(s["steps"])]
		check(not seen.has(sig), "%s shares %s with %s" % [land, sig, seen.get(sig, "")])
		seen[sig] = land
		for prog: Array in s["chords"]:
			eq(prog.size(), 4, "%s: four chords a progression" % land)
			for chord: Array in prog:
				gt(float((chord as Array).min()), 52.0, "%s: pads keep their weight over 120 Hz" % land)
		for n: int in (s["drone"] as Dictionary)["notes"]:
			gt(ScoreStems.hz(n), 128.0, "%s: the day drone's tones are ones a laptop plays" % land)
		check(ScoreLandscapes.scale_notes(s, 60, 71).size() == 7, "%s: a seven-note mode" % land)
	# A landscape nobody has written a score for yet gets one of its own.
	var a := ScoreLandscapes.procedural(&"salt_flats")
	var b := ScoreLandscapes.procedural(&"salt_flats")
	check(str(a) == str(b), "composed the same every time")
	for field: String in ["tonic", "mode", "steps", "drone", "night", "pad", "chords", "pulse", "pulse_notes", "tense_notes", "melody", "pool", "texture", "dissonance", "motif"]:
		check(a.has(field), "a composed score has %s" % field)
	check(str(ScoreLandscapes.procedural(&"scrapwood")) != str(a), "two new landscapes do not share one")


func test_score_names_are_known_and_nonsense_is_not() -> void:
	check(SoundBank.has_sound(&"score_coast_pad:1"), "a pad progression")
	check(SoundBank.has_sound(&"score_burning_melody:5"), "a phrase")
	check(not SoundBank.has_sound(&"score_coast_banjo"), "no such layer")
	check(not SoundBank.has_sound(&"score_nowhere_drone"), "no such landscape")
	eq(SoundBank.category_of(&"score_moss_texture"), &"score_texture")
	eq(ScoreStems.parse(&"score_coast_pulse:1"), {"land": &"coast", "layer": &"pulse", "variant": 1})
	for name in ScoreStems.names():
		var row := SoundBank.row(name)
		var win: Array = SoundBank.CATEGORIES[row[0]]["window"]
		check(float(row[1]) >= win[0] and float(row[1]) <= win[1], "%s sits in its window" % name)
		eq(SoundBank.CATEGORIES[row[0]]["bus"], &"Music", "%s plays on the Music bus" % name)


## The score sits under the world: its layers at full density together near
## -7 dB of the weather bed, a quiet stretch (drone and air) under -10, and the
## offline mix lays a stem at level 1 exactly at its sheet level.
func test_the_score_sits_under_the_world() -> void:
	var heard := func(layers: Array) -> float:
		var power := 0.0
		for pair: Array in layers:
			var db := float(ScoreStems.LAYERS[pair[0]]["heard"]) + 20.0 * log(float(pair[1])) / log(10.0)
			power += pow(10.0, db / 10.0)
		return 10.0 * log(power) / log(10.0)
	var full: float = heard.call([[&"drone", 1.0], [&"pad", 1.0], [&"pulse", 1.0], [&"texture", 1.0]])
	check(full > -10.0 and full < -4.0, "all of it together at %+.1f dB" % full)
	var quiet: float = heard.call([[&"drone", 0.8], [&"texture", 0.6]])
	lt(quiet, -10.0, "a rest is quiet (%+.1f dB)" % quiet)
	gt(quiet, -18.0, "but still there")
	for name: StringName in SoundBank.SHEET:
		if SoundBank.category_of(name) in [&"bed", &"weather"]:
			gt(float(SoundBank.SHEET[name][1]), full - 6.0, "%s is not buried by the score" % name)
	# A stand-in stem at its sheet level, laid at level 1 by the offline mixer.
	var b := SoundBank._header(&"score_coast_drone")
	b.samples.resize(b.rate * 2)
	for i in b.samples.size():
		b.samples[i] = 0.5 * sin(TAU * 220.0 * i / b.rate)
	b.gain_db = SoundBank._gain_for(b.samples, b)
	var out := PackedFloat32Array()
	out.resize(22050 * 2 * 2)
	out.fill(0.0)
	var lane := PackedFloat32Array()
	lane.resize(40)
	lane.fill(1.0)
	ScoreScene._lay_loop(out, 22050, b, lane, 0.05, db_to_linear(SoundMix.bus_db(&"Music")))
	near(ScoreScene.heard_db(out, 22050, 0.0, 2.0), float(ScoreStems.LAYERS[&"drone"]["heard"]), 0.15, "the mixer honours the sheet and the bus")


## Night drones reach lowest: rendered for two bars each, they must still keep
## their weight above 120 Hz, sit at their sheet level, and fit under the ceiling.
func test_night_drones_are_deep_without_mud() -> void:
	var keys: Array[StringName] = []
	for land in ScoreLandscapes.ids():
		keys.append(ScoreStems.key_for(land, &"drone", 1))
	var done := {}
	var mutex := Mutex.new()
	var task := func(i: int) -> void:
		var job := ScoreStems.job(keys[i], 2)
		job.run()
		var b := SoundBank.from_score(job)
		var f := {"lf": Synth.low_energy_ratio(b.samples, b.rate, 120.0, 4.0), "heard": SoundMix.heard_db(b), "limited": b.limited_db, "sheet": b.heard, "gain": b.gain_db}
		mutex.lock()
		done[keys[i]] = f
		mutex.unlock()
	# The first one alone, on this thread, before the rest go to every core:
	# SoundBank's header, on cold code and the pool.
	task.call(0)
	var group := WorkerThreadPool.add_group_task(func(i: int) -> void: task.call(i + 1), keys.size() - 1, -1, true, "score test drones")
	WorkerThreadPool.wait_for_group_task_completion(group)
	for key in keys:
		var f: Dictionary = done[key]
		lt(float(f["lf"]), 0.08, "%s below 120 Hz (%.3f)" % [key, f["lf"]])
		near(float(f["heard"]), float(f["sheet"]), 0.1, "%s heard at its sheet level" % key)
		lt(float(f["limited"]), 1.0, "%s fits under the ceiling without being turned down" % key)
		check(float(f["gain"]) > -30.0 and float(f["gain"]) < 18.0, "%s needs a sane call gain (%+.1f)" % [key, f["gain"]])
