class_name ScoreStems
## Every stem of the score, by key: score_<landscape>_<layer>[:variant].
##
##   drone       held tones on whole cycles; 0 day, 1 night (lower, darker)
##   pad         two progressions of four chords, two bars each (0, 1)
##   pulse       the landscape's rhythm (0 calm) and twice as fast with the flat
##               second creeping in (1 tense: machines near)
##   texture     the air: 0 its own, 1 rain, 2 fog, 3 snow, 4 ash
##   grid        a machine installation's exact sequenced pulse and neon hum
##   dissonance  beating clusters while danger stands
##   melody      twelve phrase shapes on the landscape's instrument (one-shots),
##               each starting from its own place in the landscape's pool
##   resolve     the chord and a bell when danger passes (one-shot)
##   motif       the landscape's sentinel figure (one-shot)
##
## Loops are whole bars of ScoreLandscapes.BAR, drone 11, pad 8, pulse 6 and
## texture 7 bars: together they come round again after 1848 bars (two and a
## half hours), and the conductor moves them long before that.
## Rate, stereo and high-pass come from the bank category of each layer.

const BAR := ScoreLandscapes.BAR
const PREFIX := "score_"

## bars (loops: length; one-shots: nominal), variants, bank category, heard dB at level 1.
const LAYERS := {
	&"drone": {"bars": 11, "variants": 2, "category": &"score_drone", "heard": -12.0},
	&"pad": {"bars": 8, "variants": 2, "category": &"score_pad", "heard": -11.0},
	&"pulse": {"bars": 6, "variants": 2, "category": &"score_pulse", "heard": -14.0},
	&"texture": {"bars": 7, "variants": 5, "category": &"score_texture", "heard": -16.0},
	&"grid": {"bars": 2, "variants": 1, "category": &"score_grid", "heard": -15.0},
	&"dissonance": {"bars": 5, "variants": 1, "category": &"score_dissonance", "heard": -14.0},
	&"melody": {"bars": 4, "variants": 12, "category": &"score_cue", "heard": -10.0},
	&"resolve": {"bars": 3, "variants": 1, "category": &"score_cue", "heard": -10.5},
	&"motif": {"bars": 4, "variants": 1, "category": &"score_cue", "heard": -9.0},
}

const AIR := 0
const RAIN := 1
const FOG := 2
const SNOW := 3
const ASH := 4


static func name_for(land: StringName, layer: StringName) -> StringName:
	return StringName(PREFIX + String(land) + "_" + String(layer))


static func key_for(land: StringName, layer: StringName, variant: int = 0) -> StringName:
	var n := name_for(land, layer)
	var count := int(LAYERS[layer]["variants"])
	return n if count <= 1 else StringName("%s:%d" % [n, posmod(variant, count)])


## {land, layer, variant} of a score key or name, or {} when it is not one.
static func parse(key: StringName) -> Dictionary:
	var s := String(key)
	if not s.begins_with(PREFIX):
		return {}
	var variant := 0
	var c := s.find(":")
	if c >= 0:
		variant = s.substr(c + 1).to_int()
		s = s.substr(0, c)
	var body := s.substr(PREFIX.length())
	var u := body.rfind("_")
	if u <= 0:
		return {}
	var layer := StringName(body.substr(u + 1))
	if not LAYERS.has(layer):
		return {}
	return {"land": StringName(body.substr(0, u)), "layer": layer, "variant": variant}


## [category, heard dB, variants] for a score name the bank may play, or [].
## A landscape the score has no entry for still has stems when the registry
## knows the type (its score is composed from its id).
static func sheet_row(name: StringName) -> Array:
	var k := parse(name)
	if k.is_empty() or String(name).contains(":"):
		return []
	var land: StringName = k["land"]
	if not ScoreLandscapes.has(land) and BiomeRegistry.get_def(land) == null:
		return []
	var row: Dictionary = LAYERS[k["layer"]]
	return [row["category"], row["heard"], row["variants"]]


## Every score name for the landscapes the score has entries for.
static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for land in ScoreLandscapes.ids():
		for layer: StringName in LAYERS:
			out.append(name_for(land, layer))
	return out


## Frames a loop stem is long (0 for one-shots, whose length comes from their notes).
static func loop_frames(key: StringName) -> int:
	var k := parse(key)
	if k.is_empty():
		return 0
	var row: Dictionary = LAYERS[k["layer"]]
	var cat: Dictionary = SoundBank.CATEGORIES[row["category"]]
	return roundi(int(row["bars"]) * BAR * int(cat["rate"])) if bool(cat["loop"]) else 0


## The job that renders a stem (not yet run). `bars` shortens a loop (tests
## judge a held layer's timbre and level on a couple of bars, not all of them).
static func job(key: StringName, bars: int = 0) -> ScoreRender:
	var k := parse(key)
	var land: StringName = k["land"]
	var layer: StringName = k["layer"]
	var row: Dictionary = LAYERS[layer]
	var variant := posmod(int(k["variant"]), int(row["variants"]))
	var cat: Dictionary = SoundBank.CATEGORIES[row["category"]]
	var rate := int(cat["rate"])
	var loop := bool(cat["loop"])
	var frames := roundi(bars * BAR * rate) if bars > 0 and loop else loop_frames(key)
	var j := ScoreRender.new(key, rate, bool(cat.get("stereo", false)), loop, frames)
	j.highpass = float(cat["hp"])
	var s := ScoreLandscapes.spec(land)
	var seed_value := Rng.hash_ints(String(land).hash(), String(layer).hash(), variant, 0x5c)
	match layer:
		&"drone": _drone(j, s, variant, seed_value)
		&"pad": _pad(j, s, variant, seed_value)
		&"pulse": _pulse(j, s, variant, seed_value)
		&"texture": _texture(j, s, variant, seed_value)
		&"grid": _grid(j, s, seed_value)
		&"dissonance": _dissonance(j, s, seed_value)
		&"melody": _melody(j, s, variant, seed_value)
		&"resolve": _resolve(j, s, seed_value)
		&"motif": _motif(j, s, seed_value)
	return j


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func _hzs(notes: Array) -> Array:
	var out: Array = []
	for n: int in notes:
		out.append(hz(n))
	return out


static func _space(s: Dictionary) -> Dictionary:
	return s.get("space", {"t60": 6.0, "wet": 0.4, "damp": 4000.0, "wobble": 1.0})


# ------------------------------------------------------------------ layers

static func _drone(j: ScoreRender, s: Dictionary, variant: int, seed_value: int) -> void:
	var d: Dictionary = s["night" if variant == 1 else "drone"]
	var sp := _space(s)
	var p := {
		"freqs": _hzs(d["notes"]), "wave": int(d.get("wave", 0)), "unison": int(d.get("unison", 2)),
		"detune": float(d.get("detune", 6.0)), "cut": float(d.get("cut", 500.0)), "q": float(d.get("q", 0.8)),
		"sweep": float(d.get("sweep", 0.6)), "sweep_hz": 1.0 / (3.0 * BAR), "pw": float(d.get("pw", 0.5)),
		"pwm": float(d.get("pwm", 0.0)), "pwm_hz": 1.0 / (2.0 * BAR), "drive": float(d.get("drive", 0.0)),
		"gain": 1.0, "seed": seed_value,
	}
	j.hold(ScoreVoices.Analog, p)
	# The same tones an octave up as sines that breathe out of step with the
	# sweep, so the drone's colour turns over the loop instead of pulsing.
	var up: Array = []
	var amps: Array = []
	for n: int in d["notes"]:
		up.append(hz(n + 12))
		amps.append((0.22 if variant == 0 else 0.12) / (up.size()))
	j.hold(ScoreVoices.Sine, {"freqs": up, "amps": amps, "am_hz": 1.0 / (4.0 * BAR), "am_depth": 0.8, "seed": seed_value + 1})
	var ghost: Array = d.get("ghost", [])
	if not ghost.is_empty():
		j.hold(ScoreVoices.Sine, {"freqs": _hzs(ghost), "amps": [0.07, 0.04], "am_hz": 1.0 / (4.0 * BAR), "am_depth": 0.95, "seed": seed_value + 2})
	j.fx(ScoreFx.Tape, {"delay_ms": 8.0, "depth_ms": float(sp.get("wobble", 1.0)), "hz": 0.2, "flutter_ms": 0.08, "mix": 0.0})
	j.fx(ScoreFx.Hall, {"t60": float(sp["t60"]) * 0.8, "wet": 0.3, "damp": float(sp["damp"]) * 0.6, "size": float(sp.get("size", 1.0))})


static func _pad(j: ScoreRender, s: Dictionary, variant: int, seed_value: int) -> void:
	var chords: Array = (s["chords"] as Array)[variant]
	var sp := _space(s)
	var base: Dictionary = s["pad"]
	var r := Rng.make(seed_value, 1)
	for c in chords.size():
		var p := base.duplicate()
		p["freqs"] = _hzs(chords[c])
		p["hold"] = 2.0 * BAR + 0.4
		p["seed"] = seed_value + c
		p["width"] = 0.75
		p["gain"] = r.randf_range(0.85, 1.0)
		j.note(c * 2.0 * BAR + r.randf_range(0.0, 0.06), ScoreVoices.Analog, p)
		# The top of the chord again, two octaves up as a sine that blooms late:
		# light caught in the pad, not a second instrument.
		var top: int = (chords[c] as Array).max()
		j.note(c * 2.0 * BAR + BAR * 0.5, ScoreVoices.Sine, {
			"freqs": [hz(top + 12), hz(top + 19)], "amps": [0.05, 0.025], "a": 2.5, "d": 2.0, "s": 0.7,
			"hold": 1.6 * BAR, "r": 3.0, "am_hz": 0.21, "am_depth": 0.5, "seed": seed_value + 10 + c, "width": 0.8,
		})
	j.fx(ScoreFx.Tape, {"delay_ms": 9.0, "depth_ms": float(sp.get("wobble", 1.0)) + 1.0, "hz": 0.35, "flutter_ms": 0.1, "mix": 0.5, "spread": 0.25})
	j.fx(ScoreFx.Hall, {"t60": float(sp["t60"]), "wet": float(sp["wet"]), "damp": float(sp["damp"]), "size": float(sp.get("size", 1.0))})


## Gates a bar of `steps`: the downbeat always, an evenly spread set strongly,
## the rest seldom (so a bar has a shape, and no two bars are the same).
static func _gate(pos: int, steps: int) -> float:
	if pos == 0:
		return 1.0
	var pulses := maxi(2, roundi(steps * 0.45))
	# Euclidean: pos is on when the running share of pulses steps up there.
	if floori(float(pos * pulses) / steps) != floori(float((pos - 1) * pulses) / steps):
		return 0.7
	return 0.14


static func _pulse(j: ScoreRender, s: Dictionary, variant: int, seed_value: int) -> void:
	var tense := variant == 1
	var steps := int(s["steps"]) * (2 if tense else 1)
	var bars := int(LAYERS[&"pulse"]["bars"])
	var total := steps * bars
	var step_s := BAR / steps
	var notes: Array = s["tense_notes"] if tense else s["pulse_notes"]
	var inst: Dictionary = s["pulse"]
	var sp := _space(s)
	for k in total:
		var pos := k % steps
		var chance := (1.0 if pos % 2 == 0 else 0.72) if tense else _gate(pos, steps)
		if Rng.hash01(seed_value, k, 0x9a) >= chance:
			continue
		var vel := 1.0 if pos == 0 else (0.62 + 0.3 * Rng.hash01(seed_value, k, 0x9b))
		if tense:
			vel = 0.95 if pos % 4 == 0 else 0.6
		# The filter opens and closes across the loop, so six bars read as a phrase.
		var bright := 1.0 + 0.55 * sin(TAU * float(k) / total)
		var midi: int = notes[k % notes.size()]
		var at := k * step_s + (0.0 if tense else (Rng.hash01(seed_value, k, 0x9c) - 0.5) * 0.012)
		if StringName(inst.get("kind", &"synth")) == &"ping":
			j.note(at, ScoreVoices.Ping, {
				"freq": hz(midi), "modes": inst["modes"], "gain": vel * (0.7 if tense else 0.55), "a": 0.003,
				"pan": (Rng.hash01(seed_value, k, 0x9d) - 0.5) * 0.7,
			})
		else:
			var p := inst.duplicate()
			p["freqs"] = [hz(midi)]
			p["gain"] = vel
			p["cut"] = float(inst.get("cut", 900.0)) * bright * (1.5 if tense else 1.0)
			p["seed"] = seed_value + k
			j.note(at, ScoreVoices.Analog, p)
	var echo := int(s.get("echo_steps", 3)) * BAR / int(s["steps"])
	j.fx(ScoreFx.Echo, {"time": echo, "fb": float(s.get("echo_fb", 0.45)) * (0.8 if tense else 1.0), "damp_hz": 2600.0, "low_hz": 260.0, "wet": 0.35, "ping": true})
	j.fx(ScoreFx.Hall, {"t60": float(sp["t60"]) * 0.6, "wet": 0.25, "damp": float(sp["damp"]), "size": 0.8})


static func _swells(j: ScoreRender, seed_value: int, spacing: float, length: float, p: Dictionary) -> void:
	var loop_s := float(j.frames) / j.rate
	var count := maxi(1, roundi(loop_s / spacing))
	for k in count:
		var q := p.duplicate()
		var h := Rng.hash01(seed_value, k, 0x7e)
		q["shape"] = 1
		q["hold"] = length * lerpf(0.8, 1.2, h)
		q["cut"] = float(p.get("cut", 1000.0)) * pow(2.0, (Rng.hash01(seed_value, k, 0x7f) - 0.5) * 0.8)
		q["sweep_hz"] = 1.0 / float(q["hold"])
		q["gain"] = float(p.get("gain", 1.0)) * lerpf(0.6, 1.0, Rng.hash01(seed_value, k, 0x80))
		q["seed"] = seed_value + k * 7
		j.note(k * loop_s / count, ScoreVoices.Hiss, q)


static func _pings(j: ScoreRender, seed_value: int, density: float, notes: Array[int], t60_lo: float, t60_hi: float, gain_lo: float, gain_hi: float, overtone: float) -> void:
	var loop_s := float(j.frames) / j.rate
	var count := roundi(density * loop_s)
	var r := Rng.make(seed_value, 0x91)
	for k in count:
		var t60 := r.randf_range(t60_lo, t60_hi)
		j.note(r.randf_range(0.0, loop_s), ScoreVoices.Ping, {
			"freq": hz(notes[r.randi_range(0, notes.size() - 1)]),
			"modes": [[1.0, 1.0, t60], [2.0, overtone, t60 * 0.4]],
			"gain": r.randf_range(gain_lo, gain_hi), "a": 0.004, "pan": r.randf_range(-0.8, 0.8),
		})


static func _texture(j: ScoreRender, s: Dictionary, variant: int, seed_value: int) -> void:
	var tex: Dictionary = s["texture"]
	var tonic := int(s["tonic"])
	match variant:
		AIR:
			_swells(j, seed_value, 5.6, 11.0, {"cut": float(tex["cut"]), "q": float(tex["q"]), "mode": 1, "sweep": float(tex["sweep"]), "gain": 1.0})
			if float(tex.get("hiss", 0.0)) > 0.0:
				_swells(j, seed_value + 1, 11.2, 12.0, {"cut": float(tex["hiss"]), "q": 0.7, "mode": 2, "sweep": 0.3, "gain": 0.12})
			if float(tex.get("sough", 0.0)) > 0.0:
				_swells(j, seed_value + 2, 11.2, 13.0, {"cut": float(tex["sough"]), "q": 1.2, "mode": 1, "sweep": 0.7, "gain": 0.55})
			if float(tex.get("bubbles", 0.0)) > 0.0:
				var low := ScoreLandscapes.scale_notes(s, tonic + 12, tonic + 26)
				_pings(j, seed_value + 3, float(tex["bubbles"]), low, 0.05, 0.12, 0.2, 0.5, 0.3)
			if float(tex.get("ticks", 0.0)) > 0.0:
				_swells(j, seed_value + 4, 5.0, 12.0, {"cut": 2800.0, "q": 3.0, "mode": 1, "density": float(tex["ticks"]), "gain": 0.9})
			j.fx(ScoreFx.Hall, {"t60": 3.0, "wet": 0.25, "damp": 5000.0})
		RAIN:
			# Rain on glass that is tuned: drops ring in the landscape's mode, high.
			_pings(j, seed_value, 5.0, ScoreLandscapes.scale_notes(s, tonic + 36, tonic + 52), 0.25, 0.9, 0.12, 0.45, 0.15)
			_swells(j, seed_value + 1, 4.0, 10.0, {"cut": 4200.0, "q": 0.7, "mode": 2, "sweep": 0.4, "gain": 0.14})
			j.fx(ScoreFx.Echo, {"time": BAR * 3.0 / 16.0, "fb": 0.3, "damp_hz": 5000.0, "low_hz": 400.0, "wet": 0.25, "ping": false})
			j.fx(ScoreFx.Hall, {"t60": 4.0, "wet": 0.35, "damp": 6000.0})
		FOG:
			_swells(j, seed_value, 5.0, 14.0, {"cut": 620.0, "q": 2.5, "mode": 1, "sweep": 1.0, "gain": 1.0})
			j.hold(ScoreVoices.Sine, {"freqs": [hz(tonic + 24), hz(tonic + 31)], "amps": [0.12, 0.08], "am_hz": 2.0 / (7.0 * BAR), "am_depth": 0.9, "seed": seed_value})
			j.fx(ScoreFx.Hall, {"t60": 9.0, "wet": 0.6, "damp": 2500.0, "size": 1.3})
		SNOW:
			_pings(j, seed_value, 1.2, ScoreLandscapes.scale_notes(s, tonic + 48, tonic + 60), 1.5, 2.5, 0.15, 0.35, 0.2)
			j.hold(ScoreVoices.Sine, {"freqs": [hz(tonic + 48), hz(tonic + 55), hz(tonic + 50)], "amps": [0.05, 0.04, 0.03], "am_hz": 3.0 / (7.0 * BAR), "am_depth": 0.9, "seed": seed_value})
			j.fx(ScoreFx.Hall, {"t60": 10.0, "wet": 0.6, "damp": 8000.0, "size": 1.4})
		ASH:
			_swells(j, seed_value, 4.5, 11.0, {"cut": 1800.0, "q": 1.2, "mode": 1, "density": 25.0, "gain": 1.0})
			_swells(j, seed_value + 1, 5.5, 12.0, {"cut": 300.0, "q": 1.0, "mode": 0, "sweep": 0.5, "gain": 0.6})
			j.fx(ScoreFx.Tape, {"delay_ms": 6.0, "depth_ms": 1.5, "hz": 0.3, "mix": 0.0})
			j.fx(ScoreFx.Hall, {"t60": 3.0, "wet": 0.2, "damp": 3000.0})


## The FOUND idiom in sound: an exact sixteenth pattern, identical every time,
## and a neon buzz on the tonic two octaves up.
static func _grid(j: ScoreRender, s: Dictionary, seed_value: int) -> void:
	var tonic := int(s["tonic"])
	var notes := [tonic + 12, tonic + 24, tonic + 19, tonic + 24]
	var step_s := BAR / 16.0
	var pattern := Rng.hash_ints(seed_value, 0x6d) | 0x8081
	for k in 32:
		var pos := k % 16
		if ((pattern >> pos) & 1) == 0:
			continue
		j.note(k * step_s, ScoreVoices.Analog, {
			"freqs": [hz(notes[pos % notes.size()])], "wave": 1, "pw": 0.5, "unison": 1, "cut": 2400.0, "q": 1.2,
			"a": 0.001, "d": 0.06, "s": 0.0, "hold": 0.07, "r": 0.04, "gain": 1.0 if pos % 4 == 0 else 0.7, "seed": seed_value,
		})
	j.hold(ScoreVoices.Analog, {"freqs": [hz(tonic + 24)], "wave": 0, "unison": 2, "detune": 2.0, "cut": 1400.0, "q": 5.0, "gain": 0.22, "seed": seed_value + 1})
	j.fx(ScoreFx.Echo, {"time": BAR * 3.0 / 16.0, "fb": 0.3, "damp_hz": 9000.0, "low_hz": 400.0, "wet": 0.3, "ping": true})
	j.fx(ScoreFx.Hall, {"t60": 1.2, "wet": 0.1, "damp": 8000.0, "size": 0.5})


static func _dissonance(j: ScoreRender, s: Dictionary, seed_value: int) -> void:
	var d: Array = s["dissonance"]
	j.hold(ScoreVoices.Analog, {"freqs": _hzs(d), "wave": 0, "unison": 2, "detune": 28.0, "cut": 700.0, "q": 1.4, "sweep": 1.2, "sweep_hz": 1.0 / (5.0 * BAR), "gain": 1.0, "seed": seed_value})
	var top := hz(int(d[d.size() - 1]) + 12)
	j.hold(ScoreVoices.Sine, {"freqs": [top, top * 1.012], "amps": [0.15, 0.15], "am_hz": 2.0 / (5.0 * BAR), "am_depth": 0.7, "seed": seed_value + 1})
	j.fx(ScoreFx.Tape, {"delay_ms": 7.0, "depth_ms": 2.0, "hz": 0.5, "mix": 0.0})
	j.fx(ScoreFx.Hall, {"t60": 5.0, "wet": 0.35, "damp": 3000.0})


## A voice on the landscape's melody instrument.
static func _melody_note(j: ScoreRender, s: Dictionary, at: float, midi: int, beats: float, vel: float, seed_value: int) -> void:
	var inst: Dictionary = s["melody"]
	var beat := BAR / 4.0
	var p := inst.duplicate()
	p["gain"] = vel
	p["seed"] = seed_value
	if StringName(inst.get("kind", &"synth")) == &"fm":
		p["freq"] = hz(midi)
		# A bell rings as long as it rings; a longer note only holds it a little.
		p["hold"] = maxf(float(inst.get("hold", 2.0)), beats * beat * 0.5)
		j.note(at, ScoreVoices.Fm, p)
	else:
		p["freqs"] = [hz(midi)]
		p["hold"] = beats * beat * 0.92
		j.note(at, ScoreVoices.Analog, p)


static func _melody(j: ScoreRender, s: Dictionary, variant: int, seed_value: int) -> void:
	var pool: Array = s["pool"]
	var r := Rng.make(seed_value, 3)
	var beat := BAR / 4.0
	var n := pool.size()
	var i := r.randi_range(n / 3, n - 1)
	# [index step, beats] per note, per shape.
	var shape: Array
	match variant:
		0: shape = [[0, 2.0], [-1, 1.0], [-2, 3.0]]
		1: shape = [[-3, 1.0], [1, 1.0], [1, 1.0], [2, 4.0]]
		2: shape = [[0, 1.0], [0, 1.0], [0, 1.5], [-2, 3.0]]
		3: shape = [[-4, 1.5], [4, 2.5], [-2, 3.0]]
		4: shape = [[-1, 0.3], [1, 6.0]]
		5: shape = [[0, 1.0], [1, 0.5], [-1, 1.5], [-2, 1.0], [1, 3.0]]
		# A long fall.
		6: shape = [[0, 3.0], [2, 1.0], [-1, 1.0], [-3, 5.0]]
		# A slow arpeggio climbing, then dropping away.
		7: shape = [[-2, 0.5], [1, 0.5], [1, 0.5], [1, 0.5], [-4, 6.0]]
		# A question left open.
		8: shape = [[0, 1.5], [-2, 1.5], [0, 1.0], [3, 4.0]]
		# Two long tones: a sigh.
		9: shape = [[0, 4.0], [-1, 4.0]]
		# Climbing in thirds and settling back a step.
		10: shape = [[-5, 1.0], [2, 1.0], [2, 1.0], [2, 1.0], [-1, 5.0]]
		# A call repeated, answered higher.
		_: shape = [[0, 0.5], [0, 0.5], [-1, 3.0], [1, 0.5], [1, 4.0]]
	var t := beat * 0.5
	for k in shape.size():
		var step: Array = shape[k]
		i = clampi(i + int(step[0]), 0, n - 1)
		var beats := float(step[1])
		var vel := r.randf_range(0.72, 1.0) * (0.8 if k == 0 and variant == 4 else 1.0)
		_melody_note(j, s, t + r.randf_range(-0.015, 0.015), int(pool[i]), beats, vel, seed_value + k)
		t += beats * beat
	var sp := _space(s)
	j.tail = 7.0
	j.fx(ScoreFx.Echo, {"time": BAR * 3.0 / 8.0, "fb": 0.5, "damp_hz": 2200.0, "low_hz": 300.0, "wet": 0.4, "ping": true})
	j.fx(ScoreFx.Hall, {"t60": float(sp["t60"]) + 1.0, "wet": minf(0.7, float(sp["wet"]) + 0.05), "damp": float(sp["damp"]), "size": float(sp.get("size", 1.0))})


static func _resolve(j: ScoreRender, s: Dictionary, seed_value: int) -> void:
	var chord: Array = ((s["chords"] as Array)[0] as Array)[0]
	var p: Dictionary = (s["pad"] as Dictionary).duplicate()
	p["freqs"] = _hzs(chord)
	p["a"] = 1.2
	p["hold"] = 6.0
	p["r"] = 5.0
	p["width"] = 0.8
	p["seed"] = seed_value
	j.note(0.0, ScoreVoices.Analog, p)
	var tonic := int(s["tonic"])
	var pool: Array = s["pool"]
	var home := int(pool[0])
	for m: int in pool:
		if posmod(m - tonic, 12) == 0:
			home = m
			break
	_melody_note(j, s, BAR / 4.0, home, 3.0, 0.9, seed_value + 1)
	_melody_note(j, s, BAR * 0.75, home + 7, 4.0, 0.7, seed_value + 2)
	var sp := _space(s)
	j.tail = 6.0
	j.fx(ScoreFx.Hall, {"t60": float(sp["t60"]) + 2.0, "wet": 0.5, "damp": float(sp["damp"]), "size": float(sp.get("size", 1.0))})


static func _motif(j: ScoreRender, s: Dictionary, seed_value: int) -> void:
	var figure: Array = s["motif"]
	var lowest := 127
	for n: Array in figure:
		lowest = mini(lowest, int(n[1]))
	var lift := 0
	while lowest + lift < 50:
		lift += 12
	var beat := BAR / 4.0
	for k in figure.size():
		var n: Array = figure[k]
		var midi := int(n[1]) + lift
		var at := float(n[0]) * beat
		var beats := float(n[2])
		j.note(at, ScoreVoices.Analog, {
			"freqs": [hz(midi)], "wave": 0, "unison": 3, "detune": 10.0, "cut": 420.0, "cut_env": 1.4, "fdecay": 0.5,
			"q": 1.1, "a": 0.18, "d": 0.8, "s": 0.8, "hold": beats * beat * 0.95, "r": 1.0, "drive": 0.3, "gain": 1.0,
			"width": 0.5, "seed": seed_value + k,
		})
		j.note(at + 0.05, ScoreVoices.Fm, {"freq": hz(midi + 12), "ratio": 1.0, "index": 0.6, "idecay": 2.0, "a": 0.2, "d": 1.0, "s": 0.6, "hold": beats * beat * 0.9, "r": 1.0, "gain": 0.2, "seed": seed_value + 50 + k})
	var sp := _space(s)
	j.tail = 8.0
	j.fx(ScoreFx.Echo, {"time": BAR * 3.0 / 8.0, "fb": 0.4, "damp_hz": 1800.0, "low_hz": 250.0, "wet": 0.3, "ping": true})
	j.fx(ScoreFx.Hall, {"t60": 9.0, "wet": 0.45, "damp": float(sp["damp"]), "size": 1.2})
