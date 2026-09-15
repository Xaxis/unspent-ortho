class_name SoundSignals
## One-shots a machine makes when it does something to you: registering you
## (alert_<kind>), calling others (watcher_call), shedding its load
## (second_act), letting go (loose), and taking (snatch_<kind>).
##
## The machine discipline holds here too, so a call is recognisably the thing
## you have been hearing: each alert is built from its own bed's partials and
## events (SoundMachines), tones step instead of gliding, repeats are identical
## copies at exact intervals, nothing wanders.

const RATE := 44100


static func make(name: StringName, variant: int, rate: int) -> PackedFloat32Array:
	var s := String(name)
	if s.begins_with("alert_"):
		return _alert(StringName(s.substr(6)), rate)
	match name:
		&"watcher_call": return _watcher_call(rate)
		&"second_act": return _second_act(rate)
		&"loose": return _loose(rate)
		&"snatch_flock": return _snatch_flock(rate)
		&"snatch_warden": return _snatch_warden(rate)
		&"snatch_clerk": return _snatch_clerk(rate)
	push_warning("no signal %s" % name)
	return Synth.buffer(64)


static func handles(name: StringName) -> bool:
	var s := String(name)
	return (s.begins_with("alert_") and SoundMachines.RACKET.has(StringName(s.substr(6)))) \
		or name in [&"watcher_call", &"second_act", &"loose", &"snatch_flock", &"snatch_warden", &"snatch_clerk"]


# ------------------------------------------------------------------ helpers

static func _modes(rate: int, seconds: float, freqs: Array, amps: Array, t60s: Array) -> PackedFloat32Array:
	return Synth.modes(rate, seconds, PackedFloat32Array(freqs), PackedFloat32Array(amps), PackedFloat32Array(t60s))


static func _burst(rate: int, seconds: float, seed_value: int, lo: float, hi: float, t60: float, attack: float = 0.0004) -> PackedFloat32Array:
	var b := Synth.noise(Synth.samples(rate, seconds), seed_value)
	Synth.band(b, rate, lo, hi, false, false)
	Synth.env_perc(b, rate, attack, t60)
	Synth.normalize(b, 1.0)
	return b


## A held machine tone: exact partials, a hard-edged gate (5 ms ramps, no swell).
static func _tone(rate: int, seconds: float, freqs: Array, amps: Array) -> PackedFloat32Array:
	var b := Synth.buffer(Synth.samples(rate, seconds))
	for k in freqs.size():
		Synth.add_sine(b, rate, float(freqs[k]), float(amps[k]))
	Synth.fade(b, rate, 0.005, 0.012)
	return b


## The relay that closes before a machine does anything: two identical clicks.
static func _relay(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(Synth.samples(rate, 0.05))
	var click := _modes(rate, 0.02, [2900.0, 5100.0], [0.5, 0.3], [0.008, 0.005])
	Synth.add(out, click, 0)
	Synth.add(out, click, Synth.samples(rate, 0.019), 0.7)
	return out


static func _at(rate: int, seconds: float) -> int:
	return Synth.samples(rate, seconds)


## `count` copies of ev every `gap` seconds from `start`, identical.
static func _repeat(dst: PackedFloat32Array, rate: int, ev: PackedFloat32Array, start: float, gap: float, count: int, gain: float = 1.0) -> void:
	for k in count:
		Synth.add(dst, ev, _at(rate, start + k * gap), gain)


# ------------------------------------------------------------------- alerts

## Registering you. Every one opens on the relay; what follows is the machine's
## own sound brought forward and made urgent, never a generic alarm.
static func _alert(kind: StringName, rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 0.9))
	Synth.add(out, _relay(rate), 0, 0.5)
	var p: Dictionary = SoundMachines.PARTIALS
	match kind:
		&"watcher":
			# The optic finds you: six identical focusing ticks, then its note, level.
			var tick := _modes(rate, 0.015, [4125.0, 6187.5], [0.5, 0.25], [0.006, 0.004])
			_repeat(out, rate, tick, 0.05, 0.028, 6, 0.5)
			Synth.add(out, _tone(rate, 0.45, [1100.0, 1787.5, 1063.0], [0.5, 0.25, 0.12]), _at(rate, 0.23), 0.45)
		&"longlegs":
			var knock := _modes(rate, 0.4, [196.0, 541.0, 1058.0, 1750.0], [0.5, 0.34, 0.2, 0.11], [0.3, 0.22, 0.16, 0.1])
			_repeat(out, rate, knock, 0.04, 0.13, 2, 0.8)
			# The hum steps up a fourth: 147 -> 196.
			Synth.add(out, _tone(rate, 0.18, [294.0, 588.0], [0.4, 0.2]), _at(rate, 0.3), 0.35)
			Synth.add(out, _tone(rate, 0.3, [392.0, 784.0], [0.4, 0.2]), _at(rate, 0.48), 0.35)
		&"harvester":
			# The engine doubles: sixteen identical pulses, the drive a fourth up.
			var pulse := _modes(rate, 0.06, [180.0, 360.0, 540.0], [0.5, 0.3, 0.15], [0.04, 0.03, 0.02])
			_repeat(out, rate, pulse, 0.04, 0.036, 16, 0.6)
			var drive: Array = p[&"harvester_drive"]
			Synth.add(out, _tone(rate, 0.6, [float(drive[1]) * 4.0 / 3.0, float(drive[2]) * 4.0 / 3.0], [0.3, 0.2]), _at(rate, 0.08), 0.4)
		&"cutter":
			# The disc comes up to speed in three exact steps of its 16th harmonic.
			for k in 3:
				var f := 168.0 * (14 + k)
				Synth.add(out, _tone(rate, 0.12, [f, f * 2.0], [0.4, 0.1]), _at(rate, 0.05 + k * 0.12), 0.35)
			var saw := _burst(rate, 0.4, 3301, 2600.0, 11000.0, 0.35, 0.01)
			Synth.env_gate(saw, rate, 14.0 * 2.0, 0.62, 0.3, 0.8)
			Synth.add(out, saw, _at(rate, 0.38), 0.45)
		&"hauler":
			# Brakes off: a hiss, then its double rail knock.
			var hiss := _burst(rate, 0.3, 3401, 1800.0, 6000.0, 0.25, 0.02)
			Synth.add(out, hiss, _at(rate, 0.03), 0.35)
			var one := _modes(rate, 0.16, [240.0, 610.0, 1320.0], [0.5, 0.3, 0.14], [0.12, 0.09, 0.06])
			Synth.add(out, one, _at(rate, 0.32), 0.9)
			Synth.add(out, one, _at(rate, 0.385), 0.72)
		&"warden":
			# The quietest: the band ticks tight, and one footfall's note held.
			var tick := _modes(rate, 0.02, [2475.0, 3712.5], [0.5, 0.25], [0.012, 0.008])
			_repeat(out, rate, tick, 0.05, 0.06, 4, 0.5)
			Synth.add(out, _tone(rate, 0.35, [402.0, 905.0], [0.35, 0.15]), _at(rate, 0.3), 0.3)
		&"sweeper":
			# No transient even now: the brush swells in and the drive rises an octave.
			var brush := _burst(rate, 0.7, 3601, 1100.0, 6800.0, 2.0, 0.0)
			for i in brush.size():
				brush[i] *= pow(sin(PI * float(i) / brush.size()), 2.0)
			Synth.add(out, brush, _at(rate, 0.05), 0.6)
			Synth.add(out, _tone(rate, 0.5, [348.0, 696.0], [0.3, 0.15]), _at(rate, 0.2), 0.3)
		&"dredger":
			var hiss := _burst(rate, 0.4, 3701, 300.0, 1500.0, 0.3, 0.12)
			Synth.add(out, hiss, _at(rate, 0.03), 0.4)
			Synth.add(out, _modes(rate, 0.3, [150.0, 330.0, 720.0], [0.6, 0.35, 0.15], [0.16, 0.12, 0.08]), _at(rate, 0.4), 0.9)
			Synth.add(out, _tone(rate, 0.25, [552.0, 828.0], [0.3, 0.15]), _at(rate, 0.42), 0.25)
		&"lineman":
			# The wire is struck and rings; two grips answer it.
			var wire: Array = p[&"lineman_wire"]
			Synth.add(out, _modes(rate, 0.8, wire, [0.4, 0.3, 0.18, 0.15], [0.6, 0.45, 0.3, 0.5]), _at(rate, 0.04), 0.55)
			var grip := _modes(rate, 0.12, [690.0, 1490.0, 2870.0], [0.45, 0.35, 0.22], [0.08, 0.06, 0.04])
			_repeat(out, rate, grip, 0.3, 0.125, 2, 0.6)
		&"flock":
			# Twelve identical chirps above 900 Hz: the sound the wind hides.
			var chirp := _tone(rate, 0.022, [3200.0, 4800.0], [0.4, 0.2])
			_repeat(out, rate, chirp, 0.04, 0.035, 12, 0.6)
			Synth.highpass4(out, rate, 900.0)
		&"runner":
			var step := _modes(rate, 0.1, [232.0, 540.0, 1180.0], [0.5, 0.34, 0.18], [0.06, 0.045, 0.03])
			_repeat(out, rate, step, 0.08, 1.0 / 10.5, 5, 0.8)
			Synth.add(out, _modes(rate, 0.12, [310.0, 820.0], [0.5, 0.25], [0.08, 0.05]), _at(rate, 0.04), 0.6)
		&"clerk":
			# A shutter, and its carrier twice.
			var shutter := _modes(rate, 0.02, [3100.0, 5300.0], [0.5, 0.3], [0.01, 0.006])
			Synth.add(out, shutter, _at(rate, 0.05), 0.7)
			Synth.add(out, shutter, _at(rate, 0.1), 0.5)
			var carrier: Array = p[&"clerk_carrier"]
			var blip := _tone(rate, 0.09, carrier, [0.3, 0.2])
			_repeat(out, rate, blip, 0.22, 0.14, 2, 0.5)
		_:
			Synth.add(out, _tone(rate, 0.3, [1375.0, 2750.0], [0.4, 0.15]), _at(rate, 0.06), 0.5)
	return out


## The watcher calls the others: its thin note pulsed three times, identical,
## then held. Heard far: this is how a place fills up.
static func _watcher_call(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.7))
	Synth.add(out, _relay(rate), 0, 0.4)
	var pulse := _tone(rate, 0.12, [1100.0, 1787.5, 2200.0], [0.4, 0.22, 0.08])
	_repeat(out, rate, pulse, 0.06, 0.2, 3)
	Synth.add(out, _tone(rate, 0.8, [1100.0, 1787.5, 2200.0, 1063.0], [0.4, 0.22, 0.08, 0.06]), _at(rate, 0.7))
	# Heard across open ground: a room of air on it, the top a little dulled.
	Synth.lowpass(out, rate, 6000.0)
	return Synth.reverb(out, rate, 0.8, 0.4, 0.35, 0.8)


## Load shed, harder now: a crash of plate, pieces falling by gravity (the
## only natural timing in it), the relay, and the drive stepping up 4:5:6.
static func _second_act(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.6))
	var f := 210.0
	Synth.add(out, _modes(rate, 0.9, [f, f * 2.76, f * 5.4, f * 8.93], [0.6, 0.4, 0.22, 0.12], [0.45, 0.3, 0.2, 0.12]), 0, 0.9)
	Synth.add(out, _burst(rate, 0.12, 3901, 900.0, 7000.0, 0.08), 0, 0.6)
	var r := Rng.make(3902)
	var t := 0.12
	var gap := 0.16
	for k in 8:
		var pf := r.randf_range(1400.0, 3600.0)
		Synth.add(out, _modes(rate, 0.06, [pf, pf * 2.31], [0.5, 0.2], [0.03, 0.02]), _at(rate, t), 0.45 * pow(0.82, k))
		t += gap
		gap *= 0.72
	Synth.add(out, _relay(rate), _at(rate, 0.7), 0.6)
	for k in 3:
		var tone := 220.0 * (4 + k) / 4.0
		Synth.add(out, _tone(rate, 0.16, [tone, tone * 2.0, tone * 3.0], [0.4, 0.2, 0.1]), _at(rate, 0.78 + k * 0.17), 0.4)
	return out


## Let go: the pawl lifts in three identical clicks, the spring gives, the servo falls.
static func _loose(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 0.7))
	var click := _modes(rate, 0.03, [1800.0, 3500.0], [0.5, 0.3], [0.015, 0.01])
	_repeat(out, rate, click, 0.0, 0.04, 3, 0.55)
	Synth.add(out, _modes(rate, 0.45, [310.0, 740.0, 1620.0], [0.5, 0.3, 0.12], [0.3, 0.18, 0.1]), _at(rate, 0.12), 0.7)
	for k in 3:
		# The servo winds down in steps (900, 675, 506 Hz), not a glide.
		Synth.add(out, _tone(rate, 0.07, [900.0 * pow(0.75, k)], [0.3]), _at(rate, 0.16 + k * 0.07), 0.25)
	return out


# ------------------------------------------------------------------- taking

## The flock sprays: a hiss swelling and gone, and droplets pattering after.
static func _snatch_flock(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.3))
	var spray := Synth.noise(_at(rate, 0.7), 4001)
	Synth.band(spray, rate, 2000.0, 9000.0, false, true)
	Synth.tremolo(spray, rate, 21.0, 0.5)
	for i in spray.size():
		var u := float(i) / spray.size()
		spray[i] *= pow(sin(PI * pow(u, 0.5)), 2.0)
	Synth.normalize(spray, 1.0)
	Synth.add(out, spray, 0, 0.8)
	var drops := Synth.buffer(_at(rate, 0.9))
	Synth.add_impulses(drops, rate, 70.0, 4002, 0.2, 1.0)
	var plip := Synth.formants(drops, rate, PackedFloat32Array([2100.0, 3400.0]), PackedFloat32Array([12.0, 14.0]), PackedFloat32Array([1.0, 0.6]))
	Synth.env_perc(plip, rate, 0.02, 0.8)
	Synth.normalize(plip, 1.0)
	Synth.add(out, plip, _at(rate, 0.35), 0.35)
	Synth.highpass4(out, rate, 900.0)
	return out


## Arrested: the band closes, locks in two exact clicks, and reads you twice.
static func _snatch_warden(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.2))
	Synth.add(out, _modes(rate, 0.3, [690.0, 1490.0, 2870.0], [0.45, 0.35, 0.2], [0.15, 0.1, 0.06]), 0, 0.8)
	var lock := _modes(rate, 0.03, [2475.0, 3712.5], [0.5, 0.3], [0.02, 0.012])
	_repeat(out, rate, lock, 0.18, 0.05, 2, 0.8)
	var read := _tone(rate, 0.16, [402.0, 804.0, 1206.0], [0.35, 0.2, 0.1])
	_repeat(out, rate, read, 0.42, 0.3, 2, 0.5)
	return out


## Filed: the shutter, a sheet drawn through, a stamp.
static func _snatch_clerk(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.2))
	var shutter := _modes(rate, 0.02, [3100.0, 5300.0], [0.5, 0.3], [0.01, 0.006])
	Synth.add(out, shutter, 0, 0.8)
	Synth.add(out, shutter, _at(rate, 0.045), 0.6)
	var n := _at(rate, 0.35)
	var sheet := Synth.noise(n, 4201)
	Synth.sweep_band(sheet, rate, Synth.glide(n, 1800.0, 4200.0), 1.2)
	for i in n:
		sheet[i] *= sin(PI * float(i) / n)
	Synth.normalize(sheet, 1.0)
	Synth.add(out, sheet, _at(rate, 0.14), 0.45)
	Synth.add(out, _modes(rate, 0.25, [220.0, 610.0, 1400.0], [0.6, 0.35, 0.15], [0.1, 0.08, 0.05]), _at(rate, 0.62), 0.9)
	Synth.add(out, _burst(rate, 0.05, 4202, 300.0, 2500.0, 0.03), _at(rate, 0.62), 0.35)
	return out
