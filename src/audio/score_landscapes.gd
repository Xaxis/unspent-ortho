class_name ScoreLandscapes
## What each landscape's score is made of: its key and mode, its rhythm (pulses
## a bar on a grid every landscape shares, so two scores can overlap in an
## ecotone without their pulses fighting), its two chord progressions, and the
## timbres of its drone, pad, pulse, melody and texture.
##
## Keyed by landscape type id (BiomeRegistry ids). A type with no entry here gets
## a score composed from its id (procedural()): its own key, mode, rhythm and a
## choice of timbres, so a new landscape is never silent and never borrows
## another's music. An explicit entry always wins.
##
## The tonal web. Every landscape shares one bar (BAR), so two rhythms can
## overlap without fighting; what differs is the key. affinity(a, b) says how
## near two keys stand — shared pitch classes, the interval between their
## tonics, and whether their drones hold a tone in common — and the conductor
## widens or narrows an ecotone's overlap by it: near keys modulate slowly into
## each other, far keys cross over in a short, marked, unbroken turn. A
## composed landscape does not pick a key at random: it picks the one that
## stands nearest the landscapes already written (KEY_FLOOR), so the world
## keeps one tonal centre however many types are added to it.
##
## Notes are MIDI numbers. Pads keep their weight above 120 Hz (voicings from
## G3 up); drones sit on a pitch whose fundamental a laptop can play and imply
## the octave below with harmonics.

## One bar of the shared grid, seconds. Loops and phrases are whole bars of it.
const BAR := 4.8

const MODES := {
	&"ionian": [0, 2, 4, 5, 7, 9, 11],
	&"dorian": [0, 2, 3, 5, 7, 9, 10],
	&"phrygian": [0, 1, 3, 5, 7, 8, 10],
	&"lydian": [0, 2, 4, 6, 7, 9, 11],
	&"mixolydian": [0, 2, 4, 5, 7, 9, 10],
	&"aeolian": [0, 2, 3, 5, 7, 8, 10],
	&"locrian": [0, 1, 3, 5, 6, 8, 10],
}

## How near two tonics stand, by the interval between them in semitones: the
## same centre, a fifth or fourth away, a third, a whole tone, a semitone, a
## tritone. Symmetric (11 reads as 1).
const TONIC_NEAR: Array[float] = [1.0, 0.25, 0.5, 0.6, 0.6, 0.85, 0.0, 0.85, 0.6, 0.6, 0.5, 0.25]
## A composed landscape's key must stand at least this near the written ones.
const KEY_FLOOR := 0.5

const SPECS := {
	# Bleak grey days by the sea: D dorian, a warm detuned pad that never quite
	# resolves, a sonar pulse under a dub echo, glass over it.
	&"coast": {
		"tonic": 50, "mode": &"dorian", "steps": 8,
		"drone": {"wave": 0, "notes": [50, 57, 62], "unison": 2, "detune": 5.0, "cut": 520.0, "q": 0.8, "sweep": 0.9, "ghost": [74, 81]},
		"night": {"wave": 1, "notes": [38, 50], "unison": 2, "detune": 7.0, "cut": 380.0, "q": 1.0, "sweep": 0.6, "pw": 0.3},
		"pad": {"wave": 0, "unison": 2, "detune": 12.0, "cut": 900.0, "cut_env": 1.2, "fdecay": 3.0, "q": 0.9, "a": 2.2, "d": 3.0, "s": 0.75, "r": 3.5},
		"chords": [
			[[57, 62, 64, 65], [58, 62, 65, 69], [60, 64, 65, 69], [60, 62, 67, 69]],
			[[58, 62, 65, 69], [57, 60, 62, 65], [57, 60, 62, 64], [58, 60, 65, 69]],
		],
		"pulse": {"kind": &"synth", "wave": 1, "cut": 700.0, "cut_env": 2.2, "fdecay": 0.09, "q": 3.0, "a": 0.003, "d": 0.25, "s": 0.0, "hold": 0.3, "r": 0.25},
		"pulse_notes": [74, 69, 62, 76, 69],
		"tense_notes": [62, 62, 63, 62, 69, 62, 60, 62],
		"echo_steps": 3, "echo_fb": 0.5,
		"melody": {"kind": &"fm", "ratio": 3.0, "index": 1.8, "idecay": 0.9, "floor": 0.15, "ratio2": 7.01, "index2": 0.35, "i2decay": 0.25, "a": 0.004, "d": 1.5, "s": 0.0, "hold": 2.4, "r": 2.0, "detune": 4.0},
		"pool": [69, 72, 74, 77, 79, 81, 84],
		"texture": {"cut": 1100.0, "q": 0.9, "sweep": 1.1, "hiss": 5500.0},
		"space": {"t60": 7.0, "wet": 0.45, "damp": 3500.0, "wobble": 1.2},
		"dissonance": [62, 63, 68],
		"motif": [[0.0, 50, 2.0], [2.0, 57, 1.5], [3.5, 58, 0.5], [4.0, 55, 3.0], [8.0, 53, 2.0], [10.0, 50, 5.0]],
	},
	# Drowned green gloom: D phrygian on hollow pulse-width pads, tape that has
	# been under water, drips pitched into the key. It shares the coast's centre
	# on purpose — the two lie against each other over most of a world, and a
	# walk from the shore into the moss should be one modulation, not two songs.
	&"moss": {
		"tonic": 50, "mode": &"phrygian", "steps": 6,
		"drone": {"wave": 1, "notes": [50, 57], "unison": 2, "detune": 10.0, "cut": 430.0, "q": 1.2, "sweep": 0.7, "pw": 0.42, "pwm": 0.15, "ghost": [86, 93]},
		"night": {"wave": 1, "pw": 0.3, "notes": [38, 50], "unison": 2, "detune": 9.0, "cut": 300.0, "q": 1.1, "sweep": 0.5},
		"pad": {"wave": 1, "pw": 0.5, "pwm": 0.2, "pwm_hz": 0.6, "unison": 2, "detune": 12.0, "cut": 750.0, "q": 1.6, "a": 3.0, "d": 3.0, "s": 0.8, "r": 4.0},
		"chords": [
			[[57, 60, 62, 65], [58, 62, 63, 67], [58, 62, 65, 69], [60, 63, 65, 67]],
			[[55, 58, 62, 65], [57, 60, 62, 65], [58, 62, 63, 67], [57, 62, 63, 69]],
		],
		"pulse": {"kind": &"ping", "modes": [[1.0, 1.0, 0.5], [2.76, 0.25, 0.15]]},
		"pulse_notes": [74, 77, 81, 74, 86],
		"tense_notes": [74, 75, 74, 81, 75],
		"echo_steps": 2, "echo_fb": 0.6,
		"melody": {"kind": &"fm", "ratio": 2.0, "index": 1.2, "idecay": 1.4, "floor": 0.1, "ratio2": 5.4, "index2": 0.25, "i2decay": 0.4, "vib": 14.0, "vib_hz": 0.35, "a": 0.02, "d": 2.0, "s": 0.2, "hold": 2.8, "r": 2.5, "detune": 6.0},
		"pool": [69, 72, 74, 77, 79, 81],
		"texture": {"cut": 420.0, "q": 2.0, "sweep": 1.3, "bubbles": 2.0},
		"space": {"t60": 8.0, "wet": 0.5, "damp": 2200.0, "wobble": 3.5},
		"dissonance": [62, 63, 68],
		"motif": [[0.0, 50, 2.0], [2.0, 53, 2.0], [4.0, 51, 3.0], [8.0, 57, 2.0], [10.0, 50, 5.0]],
	},
	# Under the canopy toward curfew: A aeolian strings, a plucked arpeggio in
	# fives, a breathing sine flute.
	&"pinewood": {
		"tonic": 45, "mode": &"aeolian", "steps": 10,
		"drone": {"wave": 0, "notes": [57, 64], "unison": 3, "detune": 6.0, "cut": 600.0, "q": 0.7, "sweep": 0.6, "ghost": [69, 76]},
		"night": {"wave": 1, "pw": 0.3, "notes": [45, 52], "unison": 2, "detune": 6.0, "cut": 330.0, "q": 0.9, "sweep": 0.4},
		"pad": {"wave": 0, "unison": 2, "detune": 10.0, "cut": 1300.0, "q": 0.7, "a": 2.8, "d": 2.0, "s": 0.85, "r": 4.0},
		"chords": [
			[[57, 60, 64, 71], [57, 60, 64, 65], [55, 59, 60, 64], [55, 59, 62, 64]],
			[[57, 60, 62, 65], [57, 59, 60, 64], [55, 57, 62, 67], [57, 59, 64, 65]],
		],
		"pulse": {"kind": &"synth", "wave": 0, "cut": 900.0, "cut_env": 2.5, "fdecay": 0.12, "q": 1.2, "a": 0.002, "d": 0.4, "s": 0.0, "hold": 0.35, "r": 0.3},
		"pulse_notes": [69, 72, 76, 81, 76, 69, 71, 76, 79, 76],
		"tense_notes": [69, 69, 70, 69, 76, 69, 70, 72],
		"echo_steps": 3, "echo_fb": 0.4,
		"melody": {"kind": &"synth", "wave": 2, "unison": 2, "detune": 4.0, "cut": 3000.0, "q": 0.7, "vib": 12.0, "vib_hz": 4.5, "a": 0.25, "d": 1.0, "s": 0.8, "hold": 1.6, "r": 1.2},
		"pool": [69, 72, 74, 76, 79, 81],
		"texture": {"cut": 2400.0, "q": 0.6, "sweep": 0.8, "hiss": 0.0, "sough": 700.0},
		"space": {"t60": 6.0, "wet": 0.4, "damp": 4500.0, "wobble": 1.0},
		"dissonance": [57, 58, 63],
		"motif": [[0.0, 45, 1.5], [1.5, 52, 1.5], [3.0, 53, 1.0], [4.0, 52, 4.0], [8.0, 48, 2.0], [10.0, 45, 6.0]],
	},
	# White and wide: E lydian, sine drones beating slowly, bells with the raised
	# fourth in them, ice pinging a bar apart.
	&"snowfield": {
		"tonic": 52, "mode": &"lydian", "steps": 4,
		"drone": {"wave": 2, "notes": [52, 59, 66], "unison": 2, "detune": 3.0, "cut": 2500.0, "q": 0.6, "sweep": 0.3, "ghost": [88, 95]},
		"night": {"wave": 1, "pw": 0.3, "notes": [40, 52], "unison": 2, "detune": 5.0, "cut": 400.0, "q": 0.8, "sweep": 0.5},
		"pad": {"wave": 0, "unison": 2, "detune": 8.0, "cut": 2200.0, "q": 0.6, "a": 3.5, "d": 3.0, "s": 0.8, "r": 5.0},
		"chords": [
			[[59, 63, 64, 66], [58, 61, 64, 66], [61, 64, 68, 71], [59, 61, 66, 71]],
			[[59, 63, 66, 68], [59, 61, 64, 68], [59, 61, 66, 71], [58, 63, 64, 68]],
		],
		"pulse": {"kind": &"ping", "modes": [[1.0, 1.0, 1.6], [2.76, 0.3, 0.6], [5.4, 0.12, 0.25]]},
		"pulse_notes": [88, 83, 90, 83],
		"tense_notes": [76, 77, 76, 83],
		"echo_steps": 1, "echo_fb": 0.55,
		"melody": {"kind": &"fm", "ratio": 3.5, "index": 2.2, "idecay": 1.8, "floor": 0.1, "a": 0.002, "d": 3.0, "s": 0.0, "hold": 4.0, "r": 3.0, "detune": 5.0},
		"pool": [76, 78, 80, 82, 83, 85, 87],
		"texture": {"cut": 5200.0, "q": 0.7, "sweep": 0.6, "hiss": 0.0, "sough": 500.0},
		"space": {"t60": 10.0, "wet": 0.55, "damp": 7000.0, "wobble": 0.6, "size": 1.4},
		"dissonance": [64, 65, 70],
		"motif": [[0.0, 52, 3.0], [3.0, 59, 1.0], [4.0, 58, 4.0], [8.0, 56, 2.0], [10.0, 52, 6.0]],
	},
	# Hard white glare on stone: F# phrygian, a bare fifth, stone struck in
	# sevens, a lonely pulse-wave line, dry air.
	&"bonelands": {
		"tonic": 54, "mode": &"phrygian", "steps": 7,
		"drone": {"wave": 1, "notes": [54, 61], "unison": 2, "detune": 5.0, "cut": 1400.0, "q": 0.6, "sweep": 0.4, "pw": 0.35, "ghost": [78, 79]},
		"night": {"wave": 1, "pw": 0.3, "notes": [42, 54], "unison": 2, "detune": 5.0, "cut": 450.0, "q": 0.8, "sweep": 0.5},
		"pad": {"wave": 1, "pw": 0.5, "unison": 2, "detune": 6.0, "cut": 1600.0, "q": 0.8, "a": 1.5, "d": 2.0, "s": 0.6, "r": 2.5},
		"chords": [
			[[57, 61, 64, 71], [59, 62, 66, 73], [59, 62, 66, 67], [57, 61, 62, 66]],
			[[59, 61, 62, 66], [59, 62, 66, 67], [59, 61, 66, 71], [59, 62, 64, 67]],
		],
		"pulse": {"kind": &"ping", "modes": [[1.0, 1.0, 0.22], [2.32, 0.5, 0.12], [4.25, 0.25, 0.06]]},
		"pulse_notes": [66, 73, 66, 69, 78, 73, 66],
		"tense_notes": [66, 67, 66, 72, 66, 67],
		"echo_steps": 2, "echo_fb": 0.35,
		"melody": {"kind": &"synth", "wave": 1, "pw": 0.3, "unison": 1, "cut": 1800.0, "q": 1.0, "vib": 10.0, "vib_hz": 5.0, "a": 0.08, "d": 0.5, "s": 0.7, "hold": 1.8, "r": 0.8},
		"pool": [66, 69, 71, 73, 76, 78],
		"texture": {"cut": 3200.0, "q": 0.5, "sweep": 0.5, "ticks": 12.0},
		"space": {"t60": 3.5, "wet": 0.25, "damp": 6000.0, "wobble": 0.4},
		"dissonance": [66, 67, 72],
		"motif": [[0.0, 54, 2.0], [2.0, 55, 2.0], [4.0, 61, 3.0], [7.0, 60, 1.0], [8.0, 54, 6.0]],
	},
	# Furnace dusk: G# locrian on a tritone drone, saturated saws, a forge
	# ticking in twelves, a brass growl, embers.
	&"burning": {
		"tonic": 44, "mode": &"locrian", "steps": 12,
		"drone": {"wave": 0, "notes": [56, 62], "unison": 3, "detune": 9.0, "cut": 480.0, "q": 1.5, "sweep": 1.0, "drive": 0.8, "ghost": [68, 74]},
		"night": {"wave": 1, "pw": 0.3, "notes": [50, 56], "unison": 2, "detune": 12.0, "cut": 280.0, "q": 1.3, "sweep": 0.6, "drive": 1.2},
		"pad": {"wave": 0, "unison": 2, "detune": 16.0, "drive": 0.5, "cut": 700.0, "cut_env": 0.8, "fdecay": 4.0, "q": 1.3, "a": 3.0, "d": 3.0, "s": 0.8, "r": 4.0},
		"chords": [
			[[56, 59, 62, 66], [56, 57, 61, 64], [56, 61, 62, 66], [56, 59, 62, 64]],
			[[57, 61, 64, 68], [57, 59, 62, 66], [59, 61, 64, 68], [57, 61, 62, 68]],
		],
		"pulse": {"kind": &"synth", "wave": 1, "pw": 0.2, "cut": 1300.0, "cut_env": 1.8, "fdecay": 0.05, "q": 4.0, "a": 0.001, "d": 0.12, "s": 0.0, "hold": 0.1, "r": 0.1},
		"pulse_notes": [56, 56, 68, 56, 62, 56, 57, 68, 56, 62, 56, 64],
		"tense_notes": [56, 57, 56, 62, 56, 57],
		"echo_steps": 3, "echo_fb": 0.45,
		"melody": {"kind": &"fm", "ratio": 1.0, "index": 2.8, "idecay": 0.5, "floor": 0.9, "a": 0.12, "d": 0.6, "s": 0.7, "hold": 2.0, "r": 1.2, "detune": 7.0},
		"pool": [56, 59, 62, 64, 66, 68],
		"texture": {"cut": 380.0, "q": 1.4, "sweep": 0.6, "ticks": 18.0},
		"space": {"t60": 6.0, "wet": 0.4, "damp": 2500.0, "wobble": 1.8},
		"dissonance": [56, 57, 62],
		"motif": [[0.0, 44, 3.0], [3.0, 45, 1.0], [4.0, 50, 4.0], [8.0, 49, 2.0], [10.0, 44, 6.0]],
	},
}

## What a landscape with no entry borrows from, one timbre family each.
const FAMILIES: Array[StringName] = [&"coast", &"moss", &"pinewood", &"snowfield", &"bonelands", &"burning"]

static var _cache: Dictionary = {}
static var _mutex := Mutex.new()


static func has(id: StringName) -> bool:
	return SPECS.has(id)


## The spec for a landscape type (explicit, or composed from its id). Thread-safe.
static func spec(id: StringName) -> Dictionary:
	if SPECS.has(id):
		return SPECS[id]
	_mutex.lock()
	if not _cache.has(id):
		_cache[id] = procedural(id)
	var out: Dictionary = _cache[id]
	_mutex.unlock()
	return out


## Every landscape type the score knows by name.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in SPECS:
		out.append(k)
	return out


## The twelve pitch classes a landscape's mode holds, as a bitmask.
static func pitch_classes(s: Dictionary) -> int:
	var bits := 0
	for step: int in MODES[s["mode"]]:
		bits |= 1 << posmod(int(s["tonic"]) + step, 12)
	return bits


static func _bits_set(bits: int) -> int:
	var n := 0
	for i in 12:
		n += (bits >> i) & 1
	return n


## The pitch classes a landscape's drone holds (day and night), as a bitmask:
## two bare fifths sharing a tone cross over without a clash whatever their modes.
static func drone_classes(s: Dictionary) -> int:
	var bits := 0
	for which: StringName in [&"drone", &"night"]:
		for n: int in (s[which] as Dictionary)["notes"]:
			bits |= 1 << posmod(n, 12)
	return bits


## How near two landscapes' keys stand, 0 (a tritone apart, sharing little) to 1
## (the same centre and the same notes). Pure and symmetric; the conductor turns
## it into how wide their ecotone's overlap is.
static func affinity(a: StringName, b: StringName) -> float:
	if a == b:
		return 1.0
	return affinity_of(spec(a), spec(b))


static func affinity_of(sa: Dictionary, sb: Dictionary) -> float:
	var shared := float(_bits_set(pitch_classes(sa) & pitch_classes(sb))) / 7.0
	var tonic := TONIC_NEAR[posmod(int(sa["tonic"]) - int(sb["tonic"]), 12)]
	var da := drone_classes(sa)
	var db := drone_classes(sb)
	var drone := float(_bits_set(da & db)) / maxf(1.0, float(maxi(_bits_set(da), _bits_set(db))))
	return clampf(0.5 * shared + 0.3 * tonic + 0.2 * drone, 0.0, 1.0)


## The nearest a key stands to any landscape the score has an entry for.
static func nearest_written(s: Dictionary) -> float:
	var best := 0.0
	for land: StringName in SPECS:
		best = maxf(best, affinity_of(s, SPECS[land]))
	return best


## The pitch classes of a landscape's mode over its tonic, as MIDI notes in [lo, hi].
static func scale_notes(s: Dictionary, lo: int, hi: int) -> Array[int]:
	var mode: Array = MODES[s["mode"]]
	var out: Array[int] = []
	for m in range(lo, hi + 1):
		if mode.has(posmod(m - int(s["tonic"]), 12)):
			out.append(m)
	return out


## How well a key would sit in the tonal web: the nearest written landscape's
## shared notes and the interval between the two tonics, 0..1.
static func _key_fit(tonic: int, mode: StringName) -> float:
	var probe := {"tonic": tonic, "mode": mode}
	var best := 0.0
	for land: StringName in SPECS:
		var s: Dictionary = SPECS[land]
		var shared := float(_bits_set(pitch_classes(probe) & pitch_classes(s))) / 7.0
		var near := TONIC_NEAR[posmod(tonic - int(s["tonic"]), 12)]
		best = maxf(best, 0.625 * shared + 0.375 * near)
	return best


## The keys a composed landscape may take: near enough to the written ones to
## modulate into them (KEY_FLOOR), and never one of theirs note for note. If a
## set of written landscapes ever puts KEY_FLOOR out of reach of every candidate
## (SPECS grows: VISION asks for twenty types), the floor drops to the best any
## key can do rather than leaving a composed landscape with no key at all.
static func keys_in_the_web(floor_fit: float = KEY_FLOOR) -> Array:
	var taken := {}
	for land: StringName in SPECS:
		taken["%d %s" % [posmod(int(SPECS[land]["tonic"]), 12), SPECS[land]["mode"]]] = true
	var free: Array = []
	var best := 0.0
	for tonic in range(43, 56):
		for mode: StringName in MODES:
			if taken.has("%d %s" % [posmod(tonic, 12), mode]):
				continue
			var fit := _key_fit(tonic, mode)
			free.append([tonic, mode, fit])
			best = maxf(best, fit)
	var out: Array = []
	var floor_used := minf(floor_fit, best)
	for k: Array in free:
		if float(k[2]) >= floor_used:
			out.append([k[0], k[1]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else String(a[1]) < String(b[1]))
	return out


## A score for a landscape type nobody wrote one for, composed from its id: a
## key chosen from the tonal web (so it modulates into its neighbours rather
## than landing a tritone off them), a rhythm, chords built on the mode over a
## pedal, and timbres taken from one family each (drone, pad, pulse, melody,
## texture).
static func procedural(id: StringName) -> Dictionary:
	var h := Rng.hash_ints(String(id).hash(), 0x5c0)
	var r := Rng.make(h, 0x5c1)
	var web := keys_in_the_web()
	var chosen: Array = web[Rng.hash_ints(h, 0x5c2) % web.size()]
	var tonic: int = chosen[0]
	var mode: StringName = chosen[1]
	var steps: int = [4, 5, 6, 7, 8, 9, 10, 12][r.randi_range(0, 7)]
	var pick := func(salt: int) -> Dictionary:
		return SPECS[FAMILIES[Rng.hash_ints(h, salt) % FAMILIES.size()]]
	var drone_from: Dictionary = pick.call(1)
	var pad_from: Dictionary = pick.call(2)
	var pulse_from: Dictionary = pick.call(3)
	var mel_from: Dictionary = pick.call(4)
	var tex_from: Dictionary = pick.call(5)
	var s := {"tonic": tonic, "mode": mode, "steps": steps}
	var shift := tonic - int(drone_from["tonic"])
	var drone: Dictionary = (drone_from["drone"] as Dictionary).duplicate(true)
	drone["notes"] = _shifted(drone["notes"], shift, 55)
	drone["ghost"] = _shifted(drone.get("ghost", []), shift, 67)
	s["drone"] = drone
	var night: Dictionary = (drone_from["night"] as Dictionary).duplicate(true)
	night["notes"] = _shifted(night["notes"], shift, 36)
	s["night"] = night
	s["pad"] = pad_from["pad"]
	var scale := scale_notes(s, 55, 76)
	var chords: Array = []
	for prog in 2:
		var one: Array = []
		for c in 4:
			var root := r.randi_range(0, 6)
			var voicing: Array = []
			for k: int in [0, 2, 4, 6]:
				voicing.append(scale[mini(scale.size() - 1, root + k)])
			voicing.sort()
			one.append(voicing)
		chords.append(one)
	s["chords"] = chords
	s["pulse"] = pulse_from["pulse"]
	var high := scale_notes(s, 62, 88)
	var pulse_notes: Array = []
	for k in r.randi_range(4, 7):
		pulse_notes.append(high[r.randi_range(0, high.size() - 1)])
	s["pulse_notes"] = pulse_notes
	s["tense_notes"] = [tonic + 12, tonic + 13, tonic + 12, tonic + 19, tonic + 12, tonic + 13]
	s["echo_steps"] = r.randi_range(1, 3)
	s["echo_fb"] = r.randf_range(0.35, 0.58)
	s["melody"] = mel_from["melody"]
	s["pool"] = scale_notes(s, tonic + 24, tonic + 36)
	s["texture"] = tex_from["texture"]
	s["space"] = mel_from["space"]
	s["dissonance"] = [tonic + 12, tonic + 13, tonic + 18]
	s["motif"] = [[0.0, tonic, 2.0], [2.0, tonic + 7, 2.0], [4.0, tonic + 6, 3.0], [8.0, tonic + 1, 2.0], [10.0, tonic, 5.0]]
	return s


## Notes moved by `shift` semitones, then by octaves until the lowest is at or over `floor`.
static func _shifted(notes: Array, shift: int, floor_note: int) -> Array:
	if notes.is_empty():
		return []
	var out: Array = []
	for n: int in notes:
		out.append(n + shift)
	while int(out.min()) < floor_note:
		for i in out.size():
			out[i] = int(out[i]) + 12
	while int(out.min()) >= floor_note + 12:
		for i in out.size():
			out[i] = int(out[i]) - 12
	return out
