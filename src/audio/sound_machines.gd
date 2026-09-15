class_name SoundMachines
## The twelve machine beds. Machines are heard before they are seen, and they
## are characterised by never wandering: exact integer partials (every
## frequency makes whole cycles over the loop), no amplitude LFO that is not
## locked to the loop, and identical event samples at exact intervals.
## Everything alive or natural in SoundBeds wanders; the contrast is the point.
##
## Every bed is LOOP samples at RATE (8.0 s). LOOP = 352,800 = 2^5 3^2 5^2 7^2,
## so every event count in COUNTS divides it and each event lands on a whole
## sample. Tests hold both rules.

const RATE := 44100
const LOOP := 352800

const KINDS: Array[StringName] = [
	&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden",
	&"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk",
]

## Tiles at which the bed becomes audible. The clerk was silent in the source;
## here it is heard only when it is already close.
const RACKET := {
	&"watcher": 18.0, &"longlegs": 20.0, &"harvester": 22.0, &"cutter": 16.0,
	&"hauler": 19.0, &"warden": 9.0, &"sweeper": 13.0, &"dredger": 14.0,
	&"lineman": 11.0, &"flock": 12.0, &"runner": 10.0, &"clerk": 7.0,
}

## Identical events (or gate cycles) per loop. Each must divide LOOP.
const COUNTS := {
	&"longlegs": {"knocks": 10},
	&"harvester": {"bar_gates": 224, "engine": 112, "reel": 40},
	&"cutter": {"gates": 112, "chips": 56},
	&"hauler": {"joints": 56},
	&"warden": {"footfalls": 16, "ticks": 96},
	&"sweeper": {"swells": 7},
	&"dredger": {"jaws": 8},
	&"lineman": {"grips": 32},
	&"flock": {"tremolo": 168, "swells": 3},
	&"runner": {"steps": 84, "satchel": 42},
	&"clerk": {"ticks": 32, "stamps": 2, "shuffles": 2},
}

## Partials in Hz, all multiples of RATE / LOOP (0.125 Hz), so they loop exactly.
const PARTIALS := {
	&"watcher": [137.5, 275.0, 412.5, 687.5, 1100.0, 1787.5],
	&"watcher_bearing": [1063.0],
	&"longlegs_hum": [147.0, 294.0],
	&"harvester_drive": [156.0, 312.0, 468.0, 624.0],
	&"cutter_drive": [168.0, 336.0, 504.0, 2688.0],
	&"hauler_rumble": [152.0, 304.0, 456.0],
	&"sweeper_drive": [174.0, 348.0, 522.0],
	&"dredger_pump": [276.0, 552.0],
	&"lineman_wire": [412.5, 825.0, 1237.5, 1063.0],
	&"clerk_carrier": [1378.125, 2756.25],
}


## Roster ids come as "machine.longlegs", "rows.harvester", "long_legs" or
## "harvester"; returns the bed kind, or &"" when the mob is not a machine.
static func kind_of(mob_kind: StringName) -> StringName:
	var s := String(mob_kind).to_lower()
	var dot := s.rfind(".")
	if dot >= 0:
		s = s.substr(dot + 1)
	s = s.replace("_", "").replace("-", "").replace(" ", "")
	var k := StringName(s)
	return k if RACKET.has(k) else &""


static func make(kind: StringName) -> PackedFloat32Array:
	match kind:
		&"watcher": return _watcher()
		&"longlegs": return _longlegs()
		&"harvester": return _harvester()
		&"cutter": return _cutter()
		&"hauler": return _hauler()
		&"warden": return _warden()
		&"sweeper": return _sweeper()
		&"dredger": return _dredger()
		&"lineman": return _lineman()
		&"flock": return _flock()
		&"runner": return _runner()
		&"clerk": return _clerk()
	push_warning("no machine bed %s" % kind)
	return Synth.buffer(LOOP)


# ------------------------------------------------------------------ helpers

static func _pf(key: StringName) -> PackedFloat32Array:
	return PackedFloat32Array(PARTIALS[key])


## A band of noise that repeats exactly every 2 s (four times a loop): a
## machine's hiss is the same hiss every time round.
static func _hiss(seed_value: int, lo: float, hi: float, amp: float) -> PackedFloat32Array:
	return Synth.tile(_hiss_segment(seed_value, lo, hi, amp), LOOP)


## One 2 s period of that hiss, for shaping (gates at whole cycles per 2 s)
## before it is tiled.
static func _hiss_segment(seed_value: int, lo: float, hi: float, amp: float) -> PackedFloat32Array:
	var n := Synth.noise(LOOP / 4, seed_value)
	Synth.band(n, RATE, lo, hi, true)
	Synth.scale(n, amp / maxf(1e-6, Synth.rms(n)))
	return n


## `count` identical copies of an event at exact intervals (wrapping).
static func _lay(dst: PackedFloat32Array, ev: PackedFloat32Array, count: int, gain: float = 1.0, offset: int = 0) -> void:
	var step := LOOP / count
	for k in count:
		Synth.add(dst, ev, offset + k * step, gain, true)


## A short noise burst in a band, with a percussive envelope.
static func _burst(seed_value: int, seconds: float, lo: float, hi: float, t60: float, attack: float = 0.0005) -> PackedFloat32Array:
	var b := Synth.noise(Synth.samples(RATE, seconds), seed_value)
	Synth.band(b, RATE, lo, hi, false, false)
	Synth.env_perc(b, RATE, attack, t60)
	Synth.normalize(b, 1.0)
	return b


static func _modes(seconds: float, freqs: Array, amps: Array, t60s: Array) -> PackedFloat32Array:
	return Synth.modes(RATE, seconds, PackedFloat32Array(freqs), PackedFloat32Array(amps), PackedFloat32Array(t60s))


# ------------------------------------------------------------------ recipes

## A thin level note on Fibonacci partials of 137.5 Hz, a bearing that is not in
## the series, and casing hiss. It stands and looks; nothing in it moves.
static func _watcher() -> PackedFloat32Array:
	var b := Synth.buffer(LOOP)
	Synth.add_partials(b, RATE, _pf(&"watcher"), PackedFloat32Array([0.055, 0.10, 0.085, 0.055, 0.03, 0.014]), 7)
	Synth.add_partials(b, RATE, _pf(&"watcher_bearing"), PackedFloat32Array([0.022]), 11)
	Synth.add(b, _hiss(101, 1900.0, 7000.0, 0.012), 0)
	return b


## Ten identical knocks, 0.8 s apart: a plate ring (1 : 2.76 : 5.40 : 8.93), a
## ground thump and a click, over a thin whir and hum. Near silence between.
static func _longlegs() -> PackedFloat32Array:
	var b := Synth.buffer(LOOP)
	Synth.add(b, _hiss(201, 340.0, 2400.0, 0.012), 0)
	Synth.add_partials(b, RATE, _pf(&"longlegs_hum"), PackedFloat32Array([0.018, 0.009]), 3)
	var knock := _modes(0.7, [196.0, 541.0, 1058.0, 1750.0], [0.5, 0.34, 0.2, 0.11], [0.55, 0.38, 0.26, 0.16])
	Synth.add(knock, _modes(0.2, [132.0, 264.0], [0.55, 0.2], [0.11, 0.07]), 0)
	Synth.add(knock, _burst(202, 0.012, 2000.0, 9000.0, 0.006), 0, 0.35)
	_lay(b, knock, COUNTS[&"longlegs"]["knocks"], 0.5)
	return b


## Busy and dense: the drive, a cutting bar gated at 28 Hz with the crop fall a
## quarter cycle behind it, 112 engine pulses and 40 reel slaps.
static func _harvester() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"harvester"]
	var b := Synth.buffer(LOOP)
	Synth.add_partials(b, RATE, _pf(&"harvester_drive"), PackedFloat32Array([0.05, 0.036, 0.024, 0.012]), 5)
	var gate_hz := float(c["bar_gates"]) * RATE / LOOP
	var bar := _hiss_segment(301, 1700.0, 7500.0, 0.05)
	Synth.env_gate(bar, RATE, gate_hz, 0.42, 0.25)
	Synth.add(b, Synth.tile(bar, LOOP), 0)
	var crop := _hiss_segment(302, 500.0, 2200.0, 0.035)
	Synth.env_gate(crop, RATE, gate_hz, 0.5, 0.4, 0.85, 0.25)
	Synth.add(b, Synth.tile(crop, LOOP), 0)
	var pulse := _modes(0.09, [180.0, 360.0, 540.0], [0.5, 0.3, 0.15], [0.06, 0.045, 0.03])
	Synth.add(pulse, _burst(303, 0.05, 200.0, 900.0, 0.03), 0, 0.3)
	_lay(b, pulse, c["engine"], 0.14)
	var slap := _burst(304, 0.04, 900.0, 3500.0, 0.018)
	_lay(b, slap, c["reel"], 0.16, LOOP / c["reel"] / 3)
	return b


## The only bright one: a disc through stone, gated at 14 Hz, chips falling at
## exact intervals, the drive and the disc singing on its 16th harmonic.
static func _cutter() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"cutter"]
	var b := Synth.buffer(LOOP)
	var saw := _hiss_segment(401, 2600.0, 11000.0, 0.075)
	Synth.env_gate(saw, RATE, float(c["gates"]) * RATE / LOOP, 0.62, 0.3, 0.8)
	Synth.add(b, Synth.tile(saw, LOOP), 0)
	Synth.add_partials(b, RATE, _pf(&"cutter_drive"), PackedFloat32Array([0.05, 0.03, 0.015, 0.009]), 13)
	var chip := Synth.buffer(Synth.samples(RATE, 0.09))
	Synth.add_impulses(chip, RATE, 180.0, 402, 0.2, 1.0)
	Synth.band(chip, RATE, 500.0, 3200.0, false, false)
	Synth.env_perc(chip, RATE, 0.002, 0.08)
	Synth.normalize(chip, 1.0)
	_lay(b, chip, c["chips"], 0.12, 997)
	return b


## Laden rumble and 56 identical double rail-joint knocks.
static func _hauler() -> PackedFloat32Array:
	var b := Synth.buffer(LOOP)
	Synth.add(b, _hiss(501, 190.0, 1400.0, 0.05), 0)
	Synth.add_partials(b, RATE, _pf(&"hauler_rumble"), PackedFloat32Array([0.045, 0.02, 0.01]), 17)
	var one := _modes(0.16, [240.0, 610.0, 1320.0], [0.5, 0.3, 0.14], [0.12, 0.09, 0.06])
	Synth.add(one, _burst(502, 0.01, 1500.0, 6000.0, 0.005), 0, 0.25)
	var joint := Synth.buffer(Synth.samples(RATE, 0.25))
	Synth.add(joint, one, 0)
	Synth.add(joint, one, Synth.samples(RATE, 0.065), 0.8)
	_lay(b, joint, COUNTS[&"hauler"]["joints"], 0.24)
	return b


## The quietest: sixteen even, damped footfalls over almost nothing, and the
## mechanism ticking 96 times under them.
static func _warden() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"warden"]
	var b := Synth.buffer(LOOP)
	Synth.add(b, _hiss(601, 400.0, 2000.0, 0.004), 0)
	var foot := _modes(0.22, [178.0, 402.0, 905.0], [0.6, 0.38, 0.18], [0.1, 0.075, 0.05])
	Synth.add(foot, _burst(602, 0.08, 180.0, 800.0, 0.05), 0, 0.25)
	_lay(b, foot, c["footfalls"], 0.3)
	var tick := _modes(0.02, [2475.0, 3712.5], [0.5, 0.25], [0.012, 0.008])
	_lay(b, tick, c["ticks"], 0.03, 211)
	return b


## The only machine with no transient: brush noise swelling seven times, deck
## grit, and the drive at 174 Hz.
static func _sweeper() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"sweeper"]
	var b := Synth.buffer(LOOP)
	var brush := _hiss(701, 1100.0, 6800.0, 0.07)
	Synth.env_swell(brush, float(c["swells"]), 2.0, 0.25)
	Synth.add(b, brush, 0)
	var grit_seg := Synth.buffer(LOOP / 4)
	Synth.add_impulses(grit_seg, RATE, 900.0, 702, 0.1, 0.6)
	Synth.band(grit_seg, RATE, 2500.0, 9000.0, true)
	var grit := Synth.tile(grit_seg, LOOP)
	Synth.env_swell(grit, float(c["swells"]), 2.0, 0.4, 0.5)
	Synth.scale(grit, 0.018 / maxf(1e-6, Synth.rms(grit)))
	Synth.add(b, grit, 0)
	Synth.add_partials(b, RATE, _pf(&"sweeper_drive"), PackedFloat32Array([0.035, 0.02, 0.01]), 19)
	return b


## The only wet one: water noise, and eight identical slow hydraulic jaw closes
## (a swell of hiss, a soft knock, then draining).
static func _dredger() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"dredger"]
	var b := Synth.buffer(LOOP)
	var water := _hiss(801, 240.0, 2600.0, 0.045)
	Synth.env_swell(water, float(c["jaws"]), 1.5, 0.45, 0.2)
	Synth.add(b, water, 0)
	Synth.add_partials(b, RATE, _pf(&"dredger_pump"), PackedFloat32Array([0.012, 0.006]), 23)
	var jaw_n := Synth.samples(RATE, 1.0)
	var jaw := Synth.buffer(jaw_n)
	var swell := Synth.noise(Synth.samples(RATE, 0.5), 802)
	Synth.band(swell, RATE, 300.0, 1500.0)
	for i in swell.size():
		var t := float(i) / swell.size()
		swell[i] *= t * t * (1.0 - smoothstep(0.9, 1.0, t))
	Synth.normalize(swell, 0.6)
	Synth.add(jaw, swell, 0)
	var knock := _modes(0.3, [150.0, 330.0, 720.0], [0.6, 0.35, 0.15], [0.16, 0.12, 0.08])
	Synth.add(jaw, knock, Synth.samples(RATE, 0.5), 0.9)
	var drain := Synth.buffer(Synth.samples(RATE, 0.48))
	Synth.add_impulses(drain, RATE, 90.0, 803, 0.2, 1.0)
	var drops := Synth.formants(drain, RATE, PackedFloat32Array([950.0, 1500.0, 2300.0]), PackedFloat32Array([18.0, 22.0, 26.0]), PackedFloat32Array([1.0, 0.8, 0.6]))
	Synth.env_perc(drops, RATE, 0.05, 0.5)
	Synth.normalize(drops, 0.35)
	Synth.add(jaw, drops, Synth.samples(RATE, 0.52))
	_lay(b, jaw, c["jaws"], 0.4)
	return b


## The highest: the wire tone, and hands gripping hand over hand, alternating.
## Nothing below 200 Hz.
static func _lineman() -> PackedFloat32Array:
	var b := Synth.buffer(LOOP)
	Synth.add_partials(b, RATE, _pf(&"lineman_wire"), PackedFloat32Array([0.04, 0.03, 0.018, 0.015]), 29)
	Synth.add(b, _hiss(901, 3000.0, 8000.0, 0.006), 0)
	var left := _modes(0.12, [690.0, 1490.0, 2870.0], [0.45, 0.35, 0.22], [0.08, 0.06, 0.04])
	Synth.add(left, _burst(902, 0.006, 3000.0, 12000.0, 0.004), 0, 0.3)
	var right := _modes(0.12, [648.6, 1400.6, 2697.8], [0.4, 0.32, 0.2], [0.08, 0.06, 0.04])
	Synth.add(right, _burst(902, 0.006, 3000.0, 12000.0, 0.004), 0, 0.3)
	var grips: int = COUNTS[&"lineman"]["grips"]
	var pair := LOOP / grips
	_lay(b, left, grips / 2, 0.22)
	_lay(b, right, grips / 2, 0.2, pair)
	Synth.highpass4(b, RATE, 200.0, true)
	return b


## No single source: two noise bands, a 21 Hz tremolo, three swells, and
## nothing below 900 Hz, so wind masks it first.
static func _flock() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"flock"]
	var seg := _hiss_segment(1001, 1400.0, 7600.0, 0.05)
	Synth.add(seg, _hiss_segment(1002, 900.0, 2600.0, 0.035), 0)
	Synth.highpass4(seg, RATE, 900.0, true)
	Synth.tremolo(seg, RATE, float(c["tremolo"]) * RATE / LOOP, 0.7)
	var b := Synth.tile(seg, LOOP)
	Synth.env_swell(b, float(c["swells"]), 2.0, 0.3)
	return b


## 84 identical light steps at 10.5 a second and a satchel knock every other
## step. Uncanny because every step is the same.
static func _runner() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"runner"]
	var b := Synth.buffer(LOOP)
	var step := _modes(0.1, [232.0, 540.0, 1180.0], [0.5, 0.34, 0.18], [0.06, 0.045, 0.03])
	Synth.add(step, _burst(1101, 0.008, 1500.0, 7000.0, 0.004), 0, 0.2)
	_lay(b, step, c["steps"], 0.3)
	var sat := _modes(0.12, [310.0, 820.0], [0.5, 0.25], [0.08, 0.05])
	Synth.add(sat, _burst(1102, 0.03, 1500.0, 4000.0, 0.02), 0, 0.2)
	_lay(b, sat, c["satchel"], 0.16, LOOP / c["steps"] / 2)
	return b


## Never built to be near anything: a relay escapement ticking and tocking, a
## thin carrier, a paper shuffle, and twice a loop a stamp.
static func _clerk() -> PackedFloat32Array:
	var c: Dictionary = COUNTS[&"clerk"]
	var b := Synth.buffer(LOOP)
	Synth.add_partials(b, RATE, _pf(&"clerk_carrier"), PackedFloat32Array([0.005, 0.004]), 31)
	var shuffle := _hiss(1201, 1500.0, 4000.0, 0.03)
	Synth.env_swell(shuffle, float(c["shuffles"]), 4.0, 0.0, 0.25)
	Synth.add(b, shuffle, 0)
	var tick := _modes(0.03, [2310.0, 4100.0], [0.5, 0.3], [0.02, 0.012])
	var tock := _modes(0.035, [1750.0, 3150.0], [0.5, 0.3], [0.025, 0.015])
	var ticks: int = c["ticks"]
	_lay(b, tick, ticks / 2, 0.12)
	_lay(b, tock, ticks / 2, 0.1, LOOP / ticks)
	var stamp := _modes(0.25, [220.0, 610.0, 1400.0], [0.6, 0.35, 0.15], [0.1, 0.08, 0.05])
	Synth.add(stamp, _burst(1202, 0.05, 300.0, 2500.0, 0.03), 0, 0.3)
	_lay(b, stamp, c["stamps"], 0.3, LOOP / 8)
	Synth.highpass4(b, RATE, 200.0, true)
	return b
