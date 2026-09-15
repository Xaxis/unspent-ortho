class_name SoundMusic
## The only music: one four-note figure (D, A, G, B), heard rarely. Its notes
## never change; what changes with the country is the harmony under it and the
## instrument playing it. On the coast it is whole and warm; further out it
## loses its thirds, then its harmony, until in the burning country it is alone
## over a drone a tritone away. Nobody mentions it.
##
## Written the early-90s sample-based way (warm, a little strange): FM electric
## piano, marimba, Karplus-Strong plucks, a breathy flute, detuned strings,
## choir, bell, organ; a generated room; humanised timing and velocity. Not
## chiptune, no drone pads, no sad piano.
##
## A phrase is 12 beats at 72 BPM: the figure over chord A, its answer over
## chord B (last note changed), and the answer note left ringing over chord C.
## Variant = mood: 0 arriving in a country, 1 dawn (the figure an octave up,
## brighter), 2 dusk (slower, the bass lower).

const BPM := 72.0
const TAIL := 3.2

## [beat, length in beats, MIDI note]. The last note of the answer comes from the country.
const FIGURE := [[0.0, 1.0, 62], [1.0, 1.5, 69], [2.5, 0.5, 67], [3.0, 1.0, 71]]

const COUNTRIES := {
	# Whole: G major nine, E minor nine, home to G with the ninth.
	&"coast": {
		"lead": &"ep", "pad": &"strings", "bass": &"pluck_bass", "answer": 67,
		"chords": [[43, [59, 62, 66, 69]], [40, [55, 59, 62, 66]], [43, [59, 62, 67, 69]]],
	},
	# Lydian air over the stand: C with the raised fourth, A minor nine, D over C.
	&"pinewood": {
		"lead": &"flute", "pad": &"strings", "bass": &"bowed", "answer": 66,
		"chords": [[48, [52, 55, 59, 66]], [45, [60, 64, 67, 71]], [48, [62, 66, 69]]],
	},
	# Wet and wrong: the figure's B against B-flat, then E-flat under an E.
	&"moss": {
		"lead": &"marimba", "pad": &"clarinet", "bass": &"pluck_bass", "answer": 64,
		"chords": [[46, [50, 53, 57, 64]], [41, [58, 62, 67, 69]], [51, [55, 58, 62]]],
	},
	# Thirds gone: open fifths, a sus2, a hanging fourth.
	&"snowfield": {
		"lead": &"bell", "pad": &"choir", "bass": &"none", "answer": 69,
		"chords": [[52, [59, 64]], [45, [59, 64]], [52, [59, 64]]],
	},
	# Phrygian and bare: E minor, F over E, D minor over E, ending on the flat second.
	&"bonelands": {
		"lead": &"koto", "pad": &"bowed_pad", "bass": &"bowed", "answer": 65,
		"chords": [[52, [55, 59, 64]], [52, [53, 57, 60]], [52, [62, 65, 69]]],
	},
	# No harmony left: a thin drone on A-flat and E-flat, the figure alone above it.
	&"burning": {
		"lead": &"brass", "pad": &"organ", "bass": &"none", "answer": 61,
		"chords": [[44, [51, 56]], [44, [51, 56]], [44, [51, 56]]],
	},
}

const COUNTRY_KEYS := [&"sea", &"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]


static func name_for(country: int) -> StringName:
	var k: StringName = COUNTRY_KEYS[clampi(country, 0, COUNTRY_KEYS.size() - 1)]
	return StringName("music_" + String(&"coast" if k == &"sea" else k))


static func make(name: StringName, variant: int, rate: int) -> PackedFloat32Array:
	var country := StringName(String(name).trim_prefix("music_"))
	var spec: Dictionary = COUNTRIES.get(country, COUNTRIES[&"coast"])
	var mood := clampi(variant, 0, 2)
	var bpm := BPM if mood != 2 else 64.0
	var beat := 60.0 / bpm
	var r := Rng.make(9001 + COUNTRY_KEYS.find(country) * 31, mood)
	var out := Synth.buffer(Synth.samples(rate, 15.0 * beat + 1.5))
	var lead := Synth.buffer(out.size())
	var lead_shift := 12 if mood == 1 else 0
	var bass_shift := -12 if mood == 2 else 0
	# The figure, then its answer.
	for bar in 2:
		for k in FIGURE.size():
			var note: Array = FIGURE[k]
			var midi: int = note[2]
			var length: float = note[1]
			if bar == 1 and k == FIGURE.size() - 1:
				midi = spec["answer"]
				length = 7.0
			var onset := (bar * 4.0 + float(note[0])) * beat + r.randf_range(-0.012, 0.012)
			var vel := r.randf_range(0.82, 1.0) * (0.9 if bar == 1 else 1.0)
			var tone := _voice(spec["lead"], rate, _hz(midi + lead_shift), length * beat, vel, r.randi())
			Synth.add(lead, tone, maxi(0, Synth.samples(rate, onset)), 0.55)
	# The lead repeats itself three quarters of a beat later, duller each time:
	# the beat-synced echo of the sample machines, not a hall.
	var echoed := Synth.echo(lead, rate, 0.75 * beat, 0.32, 2400.0, 0.3, 0.0)
	Synth.add(out, echoed, 0)
	# Harmony: three chords, four beats each, the last one ringing out.
	var chords: Array = spec["chords"]
	for c in chords.size():
		var chord: Array = chords[c]
		var at := c * 4.0 * beat + r.randf_range(0.0, 0.02)
		var hold := (4.0 if c < chords.size() - 1 else 6.0) * beat
		var voices: Array = chord[1]
		var freqs := PackedFloat32Array()
		for note: int in voices:
			freqs.append(_hz(note))
		var pad := _pad(spec["pad"], rate, freqs, hold, r.randi())
		Synth.add(out, pad, Synth.samples(rate, at), r.randf_range(0.75, 0.9) * 0.34 / sqrt(voices.size()))
		if spec["bass"] != &"none":
			# Dusk drops the bass an octave, but never under G2: the laptop line.
			var bass_note := int(chord[0]) + (bass_shift if int(chord[0]) + bass_shift >= 43 else 0)
			var bt := _voice(spec["bass"], rate, _hz(bass_note), hold, 0.9, r.randi())
			Synth.add(out, bt, Synth.samples(rate, at), 0.42)
	# Warmth of the era: gentle saturation, the top rolled off, a generated room.
	Synth.saturate(out, 1.25)
	Synth.lowpass(out, rate, 7500.0 if mood != 1 else 9500.0)
	return Synth.reverb(out, rate, 0.84, 0.45, 0.3, TAIL)


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## One note of an instrument, `hold` seconds before its release.
static func _voice(kind: StringName, rate: int, f: float, hold: float, vel: float, seed_value: int) -> PackedFloat32Array:
	var b: PackedFloat32Array
	match kind:
		&"ep":
			b = Synth.fm(rate, f, hold + 1.2, 1.0, 1.5, 0.8, 2.6, 0.004, 14.0, 0.35 * vel)
			var oct := Synth.fm(rate, f * 2.0, hold + 0.8, 1.0, 0.4, 0.4, 1.4, 0.004)
			Synth.add(b, oct, 0, 0.12)
			_release(b, rate, hold, 0.5)
		&"marimba":
			b = Synth.modes(rate, 1.6, PackedFloat32Array([f, f * 3.93, f * 9.7]), PackedFloat32Array([1.0, 0.25, 0.06]), PackedFloat32Array([0.9, 0.3, 0.1]), 0.002)
			var click := Synth.noise(Synth.samples(rate, 0.01), seed_value)
			Synth.band(click, rate, 1000.0, 4000.0, false, false)
			Synth.env_perc(click, rate, 0.0005, 0.006)
			Synth.add(b, click, 0, 0.15)
		&"koto":
			b = Synth.pluck(rate, f, hold + 1.4, seed_value, 0.62, 1.6)
			_release(b, rate, hold + 0.8, 0.6)
		&"pluck_bass":
			b = Synth.pluck(rate, f, hold + 0.6, seed_value, 0.25, 1.4)
			Synth.lowpass(b, rate, 900.0)
			_release(b, rate, hold, 0.4)
		&"bell":
			b = Synth.fm(rate, f, hold + 3.0, 3.5, 2.4, 1.2, 4.0, 0.002)
			Synth.add(b, Synth.fm(rate, f, hold + 3.0, 1.0, 0.3, 1.0, 3.0, 0.002), 0, 0.4)
		&"flute":
			var n := Synth.samples(rate, hold + 0.35)
			b = Synth.buffer(n)
			var ph := 0.0
			for i in n:
				var t := float(i) / rate
				var vib := 1.0 + 0.006 * sin(TAU * 5.2 * t) * smoothstep(0.25, 0.6, t)
				ph += TAU * f * vib / rate
				b[i] = sin(ph) + 0.18 * sin(2.0 * ph) + 0.05 * sin(3.0 * ph)
			var breath := Synth.noise(n, seed_value)
			Synth.resonate(breath, rate, f * 2.0, 3.0)
			Synth.add(b, breath, 0, 0.12)
			Synth.env_adsr(b, rate, 0.09, 0.2, 0.85, hold, 0.25)
		&"bowed":
			var n := Synth.samples(rate, hold + 0.8)
			b = Synth.buffer(n)
			Synth.add_saw(b, rate, f, 0.5)
			Synth.add_saw(b, rate, f * 1.003, 0.3)
			Synth.lowpass(b, rate, 700.0)
			Synth.tremolo(b, rate, 5.0, 0.1)
			Synth.env_adsr(b, rate, 0.3, 0.3, 0.85, hold, 0.6)
		&"brass":
			var n := Synth.samples(rate, hold + 0.4)
			b = Synth.buffer(n)
			var ph := 0.0
			for i in n:
				var t := float(i) / rate
				var index := 2.2 * smoothstep(0.0, 0.06, t) - 0.8 * smoothstep(0.06, 0.3, t)
				ph += TAU * f / rate
				b[i] = sin(ph + index * sin(ph))
			Synth.lowpass(b, rate, 1500.0)
			Synth.env_adsr(b, rate, 0.06, 0.2, 0.7, hold, 0.25)
		_:
			b = Synth.buffer(Synth.samples(rate, hold))
			Synth.add_sine(b, rate, f, 1.0)
			Synth.env_adsr(b, rate, 0.02, 0.1, 0.8, hold * 0.9, 0.1)
	Synth.scale(b, vel)
	return b


## A held chord on a sustained instrument. The voices share one filter and one
## envelope (the filters are linear, so summing first is the same sound for a
## fraction of the work); each voice enters a few milliseconds after the last.
static func _pad(kind: StringName, rate: int, freqs: PackedFloat32Array, hold: float, seed_value: int) -> PackedFloat32Array:
	var release := 1.2
	var n := Synth.samples(rate, hold + release)
	var b := Synth.buffer(n)
	var strum := Synth.samples(rate, 0.012)
	for v in freqs.size():
		var f := freqs[v]
		var from := v * strum
		match kind:
			&"strings", &"bowed_pad", &"choir":
				for cents: float in [0.0, -8.0, 7.0]:
					Synth.add_saw(b, rate, f * pow(2.0, cents / 1200.0), 0.3, from, -1, Rng.hash01(seed_value, v, roundi(cents)))
			&"clarinet":
				Synth.add_pulse(b, rate, f, 1.0, 0.5, from)
			&"organ":
				# The lowest voice keeps its upper drawbars down, so the drone's
				# stack does not pile up under the figure.
				var bars: Array = [[1.0, 1.0], [2.0, 0.35], [3.0, 0.1], [4.0, 0.06]] if v == 0 else [[1.0, 1.0], [2.0, 0.5], [3.0, 0.2], [4.0, 0.12]]
				for bar: Array in bars:
					Synth.add_sine(b, rate, f * float(bar[0]), float(bar[1]), from)
	match kind:
		&"strings":
			Synth.lowpass(b, rate, 2000.0)
			Synth.env_adsr(b, rate, 0.45, 0.5, 0.8, hold, 0.9)
		&"bowed_pad":
			Synth.lowpass(b, rate, 1100.0)
			Synth.env_adsr(b, rate, 0.7, 0.5, 0.8, hold, 0.9)
		&"choir":
			b = Synth.formants(b, rate, PackedFloat32Array([730.0, 1090.0, 2440.0]), PackedFloat32Array([6.0, 8.0, 10.0]), PackedFloat32Array([1.0, 0.5, 0.25]))
			Synth.tremolo(b, rate, 4.8, 0.12)
			Synth.env_adsr(b, rate, 0.6, 0.4, 0.85, hold, 1.2)
		&"clarinet":
			Synth.lowpass(b, rate, 1500.0)
			Synth.env_adsr(b, rate, 0.12, 0.3, 0.8, hold, 0.35)
		&"organ":
			# Thin: the drone is a line under the figure, not a floor of 120-500 Hz.
			Synth.highpass(b, rate, 250.0)
			Synth.highpass(b, rate, 250.0)
			Synth.tremolo(b, rate, 6.5, 0.25)
			Synth.env_adsr(b, rate, 0.08, 0.1, 0.9, hold, 0.4)
	return b


## Fade a ringing voice out after `hold` seconds over `release`.
static func _release(b: PackedFloat32Array, rate: int, hold: float, release: float) -> void:
	var start := Synth.samples(rate, hold)
	var k := exp(-Synth.LN_1000 / maxf(1.0, release * rate))
	var g := 1.0
	for i in range(mini(start, b.size()), b.size()):
		b[i] *= g
		g *= k
