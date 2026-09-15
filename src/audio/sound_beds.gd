class_name SoundBeds
## Country beds, weather beds and the scattered one-shots that keep them from
## repeating. Beds are named after the thing making the sound and placed by
## world conditions (SoundMix.bed_levels). Everything here is alive or
## natural, so it wanders: control curves on unaligned knot counts, detuned
## partials, random events. Loops stay seamless because every curve wraps,
## noise is filtered periodically and events wrap around the end.
##
## Beds run at 22,050 Hz: their content sits between 120 Hz and 9 kHz, and
## half the rate is half the baking.

## Loop lengths in seconds. The shore is four of its 5.4 s wave cycles.
const LENGTH := {
	&"bed_shore": 21.6, &"bed_wind": 16.0, &"bed_pines": 18.0, &"bed_moss": 14.0,
	&"bed_snowfield": 16.0, &"bed_bones": 16.0, &"bed_burning": 16.0, &"bed_river": 12.0,
	&"weather_rain": 12.0, &"weather_storm": 16.0, &"weather_gust": 12.0,
	&"weather_hail": 10.0, &"weather_snow": 12.0, &"weather_sand": 14.0,
	&"weather_blizzard": 16.0, &"weather_ash": 14.0, &"bed_far_works": 12.0,
}
const SHORE_CYCLE := 5.4

## Which one-shots each bed scatters, and the gap range between them in seconds.
## Hours limit when (gulls sleep); `near` beds need the player close to the source.
const SCATTER := {
	&"bed_pines": [[&"pines_snap", 6.0, 22.0], [&"pines_creak", 9.0, 30.0]],
	&"bed_moss": [[&"moss_drip", 0.5, 2.4], [&"moss_bloop", 7.0, 26.0]],
	&"bed_snowfield": [[&"snow_creak", 10.0, 35.0]],
	&"bed_bones": [[&"bones_tick", 5.0, 18.0]],
	&"bed_burning": [[&"burning_crackle", 0.6, 3.5], [&"burning_thud", 9.0, 28.0]],
	&"bed_shore": [[&"shore_gull", 7.0, 30.0]],
}


static func make(name: StringName, variant: int, rate: int) -> PackedFloat32Array:
	match name:
		&"bed_shore": return _shore(rate)
		&"bed_wind": return _wind(rate)
		&"bed_pines": return _pines(rate)
		&"bed_moss": return _moss(rate)
		&"bed_snowfield": return _snowfield(rate)
		&"bed_bones": return _bones(rate)
		&"bed_burning": return _burning(rate)
		&"bed_river": return _river(rate)
		&"bed_far_works": return _far_works(rate)
		&"weather_rain": return _rain(rate)
		&"weather_storm": return _storm(rate)
		&"weather_gust": return _gust(rate)
		&"weather_hail": return _hail(rate)
		&"weather_snow": return _snow(rate)
		&"weather_sand": return _sand(rate)
		&"weather_blizzard": return _blizzard(rate)
		&"weather_ash": return _ash(rate)
		&"pines_snap": return _snap(rate, variant)
		&"pines_creak": return _creak(rate, variant)
		&"moss_drip": return _drip(rate, variant)
		&"moss_bloop": return _bloop(rate, variant)
		&"snow_creak": return _crust(rate, variant)
		&"bones_tick": return _stone_tick(rate, variant)
		&"burning_crackle": return _crackle(rate, variant)
		&"burning_thud": return _thud(rate, variant)
		&"shore_gull": return SoundCreatures.gull(rate, variant, true)
		&"heat_tick": return _heat_tick(rate, variant)
		&"fog_horn": return _fog_horn(rate)
	push_warning("no bed %s" % name)
	return Synth.buffer(64)


# ------------------------------------------------------------------ helpers

static func _n(name: StringName, rate: int) -> int:
	return Synth.samples(rate, LENGTH[name])


## Periodic band noise at unit RMS. Natural bands roll off gently (12 dB per
## octave); the bank's high-pass keeps the bottom clean.
static func _band(n: int, rate: int, seed_value: int, lo: float, hi: float, steep: bool = false) -> PackedFloat32Array:
	var b := Synth.noise(n, seed_value)
	Synth.band(b, rate, lo, hi, true, steep)
	Synth.scale(b, 1.0 / maxf(1e-6, Synth.rms(b)))
	return b


## A wrapping control curve raised to a power: `knots` should differ between
## layers so their swells never line up.
static func _curve(n: int, knots: int, seed_value: int, lo: float, hi: float, power: float = 1.0) -> PackedFloat32Array:
	var c := Synth.wander(n, knots, seed_value, lo, hi)
	if power != 1.0:
		for i in n:
			c[i] = pow(c[i], power)
	return c


static func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, curve: PackedFloat32Array = PackedFloat32Array()) -> void:
	if curve.is_empty():
		Synth.add(dst, src, 0, gain)
		return
	for i in dst.size():
		dst[i] += src[i] * curve[i] * gain


## A one-shot noise burst in a band with a percussive envelope, unit peak.
static func _burst(rate: int, seconds: float, seed_value: int, lo: float, hi: float, t60: float, attack: float = 0.001) -> PackedFloat32Array:
	var b := Synth.noise(Synth.samples(rate, seconds), seed_value)
	Synth.band(b, rate, lo, hi, false, false)
	Synth.env_perc(b, rate, attack, t60)
	Synth.normalize(b, 1.0)
	return b


## Distance for scattered sounds: duller and wetter, not just quieter.
static func _far(buf: PackedFloat32Array, rate: int, cutoff: float, wet: float, tail: float) -> PackedFloat32Array:
	Synth.lowpass(buf, rate, cutoff)
	return Synth.reverb(buf, rate, 0.7, 0.5, wet, tail)


# --------------------------------------------------------------- country

## Four overlapping washes on a 5.4 s cycle (noise 260 Hz to 2.4 or 5 kHz under
## a sin^3 swell, brighter at the crest), a surf floor, and shingle dragged
## back in the backwash above 4.2 kHz.
static func _shore(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_shore", rate)
	var out := Synth.buffer(n)
	var floor_noise := Synth.pink(n, 5101, true)
	Synth.band(floor_noise, rate, 260.0, 900.0, true)
	Synth.scale(floor_noise, 0.03 / maxf(1e-6, Synth.rms(floor_noise)))
	Synth.env_swell(floor_noise, LENGTH[&"bed_shore"] / SHORE_CYCLE, 1.0, 0.4, 0.3)
	Synth.add(out, floor_noise, 0)
	# Every wash shares four long noise layers; what differs is the envelope each
	# wash writes into them (built from a looked-up shape, wrapping round the loop).
	var body := _band(n, rate, 5201, 260.0, 1200.0)
	var crest_low := _band(n, rate, 5202, 1200.0, 2400.0)
	var crest_high := _band(n, rate, 5203, 1200.0, 5000.0)
	var rattle := Synth.buffer(n)
	Synth.add_impulses(rattle, rate, 700.0, 5204, 0.1, 1.0)
	Synth.band(rattle, rate, 4200.0, 9500.0, true, false)
	Synth.scale(rattle, 1.0 / maxf(1e-6, Synth.rms(rattle)))
	var env_body := Synth.buffer(n)
	var env_low := Synth.buffer(n)
	var env_high := Synth.buffer(n)
	var env_back := Synth.buffer(n)
	const SHAPE := 512
	var arrive := PackedFloat32Array()
	var drag := PackedFloat32Array()
	for k in SHAPE + 1:
		var u := float(k) / SHAPE
		# Arrive fast, fall back slowly: the sin^3 swell skewed toward the start.
		arrive.append(pow(sin(PI * pow(u, 0.62)), 3.0))
		drag.append(pow(sin(PI * clampf((u - 0.35) / 0.65, 0.0, 1.0)), 2.0))
	var r := Rng.make(5102, 1)
	var cycles := roundi(LENGTH[&"bed_shore"] / SHORE_CYCLE)
	for c in cycles:
		for layer in 4:
			var m := Synth.samples(rate, r.randf_range(3.0, 5.2))
			var amp := r.randf_range(0.25, 1.0) * (1.0 if layer == 0 else 0.7)
			var at := posmod(roundi((c * SHORE_CYCLE + layer * SHORE_CYCLE / 4.0 + r.randf_range(-0.3, 0.3)) * rate), n)
			var crest_env := env_low if layer % 2 == 0 else env_high
			var shingle := layer % 2 == 1
			for j in m:
				var x := float(j) / m * SHAPE
				var k := mini(floori(x), SHAPE - 1)
				var f := x - k
				var e := arrive[k] + (arrive[k + 1] - arrive[k]) * f
				var i := (at + j) % n
				env_body[i] += e * amp
				crest_env[i] += e * e * amp * 0.8
				if shingle:
					env_back[i] += (drag[k] + (drag[k + 1] - drag[k]) * f) * amp * 0.5
	for i in n:
		out[i] += 0.11 * (body[i] * env_body[i] + crest_low[i] * env_low[i] + crest_high[i] * env_high[i] + rattle[i] * env_back[i])
	return out


## Open-country wind: a body band and an upper band on unaligned swells, grass
## hiss on top, and a faint moan where it finds an edge.
static func _wind(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_wind", rate)
	var out := Synth.buffer(n)
	_mix_into(out, _band(n, rate, 5401, 250.0, 1100.0), 0.07, _curve(n, 8, 5402, 0.45, 1.0))
	_mix_into(out, _band(n, rate, 5403, 1100.0, 3800.0), 0.035, _curve(n, 11, 5404, 0.3, 1.0, 2.0))
	_mix_into(out, _band(n, rate, 5405, 3000.0, 7500.0), 0.014, _curve(n, 13, 5406, 0.3, 1.0))
	var moan := Synth.noise(n, 5407)
	Synth.resonate(moan, rate, 430.0, 7.0, true)
	Synth.scale(moan, 1.0 / maxf(1e-6, Synth.rms(moan)))
	_mix_into(out, moan, 0.02, _curve(n, 5, 5408, 0.0, 1.0, 3.0))
	return out


## Pines: canopy hiss soughing in swells, a farther stand behind it, a trunk
## band kept above the laptop line, needles shimmering high.
static func _pines(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_pines", rate)
	var out := Synth.buffer(n)
	_mix_into(out, _band(n, rate, 5501, 900.0, 3400.0), 0.06, _curve(n, 7, 5502, 0.3, 1.0, 2.0))
	_mix_into(out, _band(n, rate, 5503, 600.0, 2200.0), 0.03, _curve(n, 5, 5504, 0.4, 1.0))
	_mix_into(out, _band(n, rate, 5505, 130.0, 260.0), 0.02, _curve(n, 4, 5506, 0.5, 1.0))
	_mix_into(out, _band(n, rate, 5507, 4000.0, 7000.0), 0.008, _curve(n, 9, 5508, 0.2, 1.0, 2.0))
	return out


## Moss: still air under 420 Hz, a seep ticking through wet peat, and the odd
## bubble. Drips are scattered live so they never fall in a pattern.
static func _moss(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_moss", rate)
	var out := Synth.buffer(n)
	var air := Synth.pink(n, 5601, true)
	Synth.band(air, rate, 120.0, 420.0, true)
	Synth.scale(air, 1.0 / maxf(1e-6, Synth.rms(air)))
	_mix_into(out, air, 0.035, _curve(n, 3, 5602, 0.7, 1.0))
	var seep := Synth.buffer(n)
	Synth.add_impulses(seep, rate, 38.0, 5603, 0.05, 1.0)
	var tick := Synth.formants(seep, rate, PackedFloat32Array([1300.0, 1900.0, 2650.0]), PackedFloat32Array([25.0, 30.0, 35.0]), PackedFloat32Array([1.0, 0.7, 0.45]), true)
	Synth.scale(tick, 1.0 / maxf(1e-6, Synth.rms(tick)))
	_mix_into(out, tick, 0.012, _curve(n, 6, 5604, 0.3, 1.0))
	_mix_into(out, _band(n, rate, 5605, 800.0, 2000.0), 0.004)
	var r := Rng.make(5606)
	for k in 5:
		var b := _bloop(rate, k + 10)
		Synth.add(out, b, r.randi_range(0, n - 1), 0.05, true)
	return out


## The quietest: a thin hiss, a moan that comes and goes, blown grains.
static func _snowfield(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_snowfield", rate)
	var out := Synth.buffer(n)
	_mix_into(out, _band(n, rate, 5701, 2200.0, 5200.0), 0.03, _curve(n, 6, 5702, 0.5, 1.0))
	var moan := Synth.noise(n, 5703)
	var m2 := moan.duplicate()
	Synth.resonate(moan, rate, 520.0, 9.0, true)
	Synth.resonate(m2, rate, 780.0, 11.0, true)
	Synth.add(moan, m2, 0, 0.7)
	Synth.scale(moan, 1.0 / maxf(1e-6, Synth.rms(moan)))
	_mix_into(out, moan, 0.018, _curve(n, 5, 5704, 0.0, 1.0, 3.0))
	var grains := Synth.buffer(n)
	Synth.add_impulses(grains, rate, 220.0, 5705, 0.05, 1.0)
	Synth.band(grains, rate, 3000.0, 8000.0, true)
	Synth.scale(grains, 1.0 / maxf(1e-6, Synth.rms(grains)))
	_mix_into(out, grains, 0.008, _curve(n, 7, 5706, 0.0, 1.0, 2.0))
	return out


## Limestone pavement: wind 0.7-2.4 kHz and the grikes answering it with
## bottle tones on D and A, never together for long.
static func _bones(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_bones", rate)
	var out := Synth.buffer(n)
	_mix_into(out, _band(n, rate, 5801, 700.0, 2400.0), 0.05, _curve(n, 7, 5802, 0.35, 1.0, 1.5))
	var tones := [[146.8, 5803, 5], [220.0, 5804, 6], [293.6, 5805, 4]]
	var gains := [0.05, 0.04, 0.015]
	for k in tones.size():
		var t: Array = tones[k]
		var b := Synth.noise(n, t[1])
		Synth.resonate(b, rate, t[0], 45.0, true)
		Synth.resonate(b, rate, t[0], 45.0, true)
		Synth.scale(b, 1.0 / maxf(1e-6, Synth.rms(b)))
		_mix_into(out, b, gains[k], _curve(n, t[2], int(t[1]) + 50, 0.0, 1.0, 2.5))
	return out


## The burning ground: a note whose fundamental is missing (harmonics of 27.5
## and 41.25 Hz, so a laptop still hears the depth), a roar, steam chuffing.
static func _burning(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_burning", rate)
	var out := Synth.buffer(n)
	var partials: Array[float] = [123.75, 137.5, 165.0, 206.25, 220.0, 247.5, 275.0]
	var amps: Array[float] = [0.03, 0.022, 0.02, 0.018, 0.012, 0.008, 0.006]
	var r := Rng.make(5901)
	for k in partials.size():
		# Natural: detuned off the loop grid by a little, then snapped back so it wraps.
		var f := Synth.snap_freq(partials[k] + r.randf_range(-0.4, 0.4), rate, n)
		var b := Synth.buffer(n)
		Synth.add_sine(b, rate, f, 1.0, 0, -1, r.randf())
		_mix_into(out, b, amps[k], _curve(n, 3 + k, 5910 + k, 0.4, 1.0))
	_mix_into(out, _band(n, rate, 5902, 120.0, 640.0), 0.07, _curve(n, 6, 5903, 0.5, 1.0))
	_mix_into(out, _band(n, rate, 5904, 2600.0, 8000.0), 0.03, _curve(n, 9, 5905, 0.0, 1.0, 3.0))
	return out


## Running water: hundreds of small bubbles over a soft rush.
static func _river(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_river", rate)
	var out := Synth.buffer(n)
	_mix_into(out, _band(n, rate, 6001, 300.0, 3000.0), 0.025, _curve(n, 5, 6002, 0.7, 1.0))
	var r := Rng.make(6003)
	var bubbles := 320
	for k in bubbles:
		var len_s := r.randf_range(0.015, 0.045)
		var f := r.randf_range(380.0, 1500.0)
		var b := Synth.buffer(Synth.samples(rate, len_s))
		Synth.add_chirp(b, rate, f, f * r.randf_range(1.2, 1.7), 1.0)
		Synth.env_perc(b, rate, 0.002, len_s)
		Synth.add(out, b, r.randi_range(0, n - 1), r.randf_range(0.01, 0.05), true)
	return out


## Machinery nobody switched off, a long way off, on still air. The machine
## keeps the machine rules (a shaft whose fundamental is missing, 41.25 Hz, so
## only its harmonics carry; ten identical belt slaps; four identical clanks,
## all on exact samples), and the air between wanders: the whole of it swells
## and sinks as the air moves, and it is dull and wet with distance.
static func _far_works(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_far_works", rate)
	var works := Synth.buffer(n)
	var shaft := PackedFloat32Array([123.75, 165.0, 206.25, 247.5, 288.75, 330.0, 371.25])
	Synth.add_partials(works, rate, shaft, PackedFloat32Array([0.03, 0.045, 0.03, 0.02, 0.014, 0.01, 0.008]), 8101)
	var slap := Synth.noise(Synth.samples(rate, 0.12), 8102)
	Synth.band(slap, rate, 400.0, 1800.0, false, false)
	Synth.env_perc(slap, rate, 0.002, 0.09)
	Synth.normalize(slap, 0.05)
	var beats := 10
	for k in beats:
		Synth.add(works, slap, k * n / beats, 1.0, true)
	var clank := Synth.modes(rate, 0.6, PackedFloat32Array([210.0, 580.0, 1134.0]), PackedFloat32Array([0.5, 0.3, 0.15]), PackedFloat32Array([0.4, 0.3, 0.2]), 0.002)
	var far_clank := Synth.reverb(clank, rate, 0.9, 0.6, 0.6, 2.0)
	var clanks := 4
	for k in clanks:
		Synth.add(works, far_clank, k * n / clanks + n / 13, 0.09, true)
	Synth.lowpass4(works, rate, 950.0, true)
	var air := _curve(n, 5, 8103, 0.35, 1.0, 1.5)
	var out := Synth.buffer(n)
	_mix_into(out, works, 1.0, air)
	_mix_into(out, _band(n, rate, 8104, 160.0, 900.0), 0.012, _curve(n, 4, 8105, 0.5, 1.0))
	return out


# --------------------------------------------------------------- weather

## The reference bed. Dense patter over a soft wash, close drops on top.
static func _rain(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_rain", rate)
	var out := Synth.buffer(n)
	var patter := Synth.buffer(n)
	Synth.add_impulses(patter, rate, 2600.0, 6101, 0.05, 1.0)
	Synth.band(patter, rate, 900.0, 9000.0, true)
	Synth.scale(patter, 1.0 / maxf(1e-6, Synth.rms(patter)))
	_mix_into(out, patter, 0.07, _curve(n, 5, 6102, 0.8, 1.0))
	var wash := Synth.pink(n, 6103, true)
	Synth.band(wash, rate, 300.0, 2000.0, true)
	Synth.scale(wash, 1.0 / maxf(1e-6, Synth.rms(wash)))
	_mix_into(out, wash, 0.035, _curve(n, 4, 6104, 0.8, 1.0))
	var drops := Synth.buffer(n)
	Synth.add_impulses(drops, rate, 45.0, 6105, 0.3, 1.0)
	var plip := Synth.formants(drops, rate, PackedFloat32Array([1900.0, 2900.0, 4300.0]), PackedFloat32Array([3.5, 4.0, 4.5]), PackedFloat32Array([1.0, 0.8, 0.5]), true)
	Synth.scale(plip, 1.0 / maxf(1e-6, Synth.rms(plip)))
	_mix_into(out, plip, 0.025)
	return out


## Heavy rain, a wind roar in swells, a whistle, and far thunder rolling twice.
static func _storm(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_storm", rate)
	var out := Synth.buffer(n)
	var patter := Synth.buffer(n)
	Synth.add_impulses(patter, rate, 6000.0, 6201, 0.05, 1.0)
	Synth.band(patter, rate, 700.0, 9000.0, true)
	Synth.scale(patter, 1.0 / maxf(1e-6, Synth.rms(patter)))
	_mix_into(out, patter, 0.08, _curve(n, 6, 6202, 0.75, 1.0))
	_mix_into(out, _band(n, rate, 6203, 250.0, 2500.0), 0.05, _curve(n, 5, 6204, 0.7, 1.0))
	_mix_into(out, _band(n, rate, 6205, 200.0, 1400.0), 0.06, _curve(n, 6, 6206, 0.3, 1.0, 1.5))
	var whistle := Synth.noise(n, 6207)
	Synth.resonate(whistle, rate, 900.0, 6.0, true)
	Synth.scale(whistle, 1.0 / maxf(1e-6, Synth.rms(whistle)))
	_mix_into(out, whistle, 0.018, _curve(n, 7, 6208, 0.0, 1.0, 3.0))
	for at: float in [3.5, 11.0]:
		Synth.add(out, _roll(rate, 6210 + roundi(at), 3.8), roundi(at * rate), 0.09, true)
	return out


## A far thunder roll: brown-ish rumble kept above 120 Hz, in bursts.
static func _roll(rate: int, seed_value: int, seconds: float) -> PackedFloat32Array:
	var m := Synth.samples(rate, seconds)
	var b := Synth.pink(m, seed_value)
	Synth.band(b, rate, 120.0, 420.0, false, true)
	var bursts := _curve(m, 9, seed_value + 1, 0.2, 1.0, 2.0)
	for i in m:
		var u := float(i) / m
		b[i] *= bursts[i] * pow(sin(PI * pow(u, 0.4)), 2.0)
	Synth.normalize(b, 1.0)
	return b


## Wind gusts that find a voice: whistles gliding through resonance.
static func _gust(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_gust", rate)
	var out := Synth.buffer(n)
	_mix_into(out, _band(n, rate, 6301, 300.0, 1500.0), 0.06, _curve(n, 5, 6302, 0.3, 1.0, 1.5))
	# A swept filter cannot be primed from its tail: run it past the end and
	# fold the overrun back over the start.
	var extra := Synth.samples(rate, 0.5)
	var centre := _curve(n, 9, 6303, 520.0, 1500.0)
	var tiled := centre.duplicate()
	tiled.append_array(centre.slice(0, extra))
	var whistle := Synth.noise(n + extra, 6304)
	Synth.sweep_band(whistle, rate, tiled, 14.0)
	var looped := _fold_overrun(whistle, n)
	Synth.scale(looped, 1.0 / maxf(1e-6, Synth.rms(looped)))
	_mix_into(out, looped, 0.035, _curve(n, 7, 6305, 0.0, 1.0, 2.0))
	_mix_into(out, _band(n, rate, 6306, 1800.0, 5000.0), 0.02, _curve(n, 11, 6307, 0.2, 1.0, 2.0))
	return out


## Hail: hard ice ticks, bounces, a wash under them.
static func _hail(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_hail", rate)
	var out := Synth.buffer(n)
	var ticks := Synth.buffer(n)
	Synth.add_impulses(ticks, rate, 1500.0, 6401, 0.1, 1.0)
	var ice := Synth.formants(ticks, rate, PackedFloat32Array([3300.0, 5100.0, 7000.0]), PackedFloat32Array([6.0, 7.0, 8.0]), PackedFloat32Array([1.0, 0.8, 0.5]), true)
	Synth.band(ice, rate, 2000.0, 9500.0, true, false)
	Synth.scale(ice, 1.0 / maxf(1e-6, Synth.rms(ice)))
	_mix_into(out, ice, 0.08, _curve(n, 5, 6402, 0.7, 1.0))
	var bounce := Synth.buffer(n)
	Synth.add_impulses(bounce, rate, 800.0, 6403, 0.05, 0.6)
	Synth.band(bounce, rate, 1200.0, 4000.0, true)
	Synth.scale(bounce, 1.0 / maxf(1e-6, Synth.rms(bounce)))
	_mix_into(out, bounce, 0.03)
	_mix_into(out, _band(n, rate, 6404, 400.0, 3000.0), 0.02)
	return out


## Snow: a soft hush and the smallest ticks. Snow deadens everything else too.
static func _snow(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_snow", rate)
	var out := Synth.buffer(n)
	var hush := Synth.pink(n, 6501, true)
	Synth.band(hush, rate, 900.0, 4000.0, true)
	Synth.scale(hush, 1.0 / maxf(1e-6, Synth.rms(hush)))
	_mix_into(out, hush, 0.05, _curve(n, 4, 6502, 0.6, 1.0))
	var flakes := Synth.buffer(n)
	Synth.add_impulses(flakes, rate, 90.0, 6503, 0.1, 1.0)
	Synth.band(flakes, rate, 4000.0, 8000.0, true)
	Synth.scale(flakes, 1.0 / maxf(1e-6, Synth.rms(flakes)))
	_mix_into(out, flakes, 0.006)
	return out


## Blown sand: grit hiss in gusts over a wind body.
static func _sand(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_sand", rate)
	var out := Synth.buffer(n)
	var grit := Synth.buffer(n)
	Synth.add_impulses(grit, rate, 5000.0, 6601, 0.05, 1.0)
	Synth.band(grit, rate, 2000.0, 9000.0, true)
	Synth.scale(grit, 1.0 / maxf(1e-6, Synth.rms(grit)))
	var gusts := _curve(n, 6, 6602, 0.5, 1.0, 1.5)
	_mix_into(out, grit, 0.06, gusts)
	_mix_into(out, _band(n, rate, 6603, 1500.0, 6000.0), 0.04, gusts)
	_mix_into(out, _band(n, rate, 6604, 250.0, 1200.0), 0.05, _curve(n, 5, 6605, 0.4, 1.0))
	return out


## A blizzard: snow driven flat, a howl finding every edge, a roar under it.
static func _blizzard(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_blizzard", rate)
	var out := Synth.buffer(n)
	var gusts := _curve(n, 7, 6701, 0.45, 1.0, 1.5)
	var hiss := Synth.buffer(n)
	Synth.add_impulses(hiss, rate, 4200.0, 6702, 0.05, 1.0)
	Synth.band(hiss, rate, 1500.0, 7000.0, true)
	Synth.scale(hiss, 1.0 / maxf(1e-6, Synth.rms(hiss)))
	_mix_into(out, hiss, 0.05, gusts)
	_mix_into(out, _band(n, rate, 6703, 220.0, 1000.0), 0.07, gusts)
	var extra := Synth.samples(rate, 0.5)
	var centre := _curve(n, 11, 6704, 380.0, 1150.0)
	var tiled := centre.duplicate()
	tiled.append_array(centre.slice(0, extra))
	var howl := Synth.noise(n + extra, 6705)
	Synth.sweep_band(howl, rate, tiled, 18.0)
	var looped := _fold_overrun(howl, n)
	Synth.scale(looped, 1.0 / maxf(1e-6, Synth.rms(looped)))
	_mix_into(out, looped, 0.04, _curve(n, 6, 6706, 0.0, 1.0, 2.0))
	return out


## Ash coming down: almost nothing. A dry hush and the smallest ticks settling.
static func _ash(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_ash", rate)
	var out := Synth.buffer(n)
	var hush := Synth.pink(n, 6801, true)
	Synth.band(hush, rate, 500.0, 2600.0, true)
	Synth.scale(hush, 1.0 / maxf(1e-6, Synth.rms(hush)))
	_mix_into(out, hush, 0.03, _curve(n, 4, 6802, 0.6, 1.0))
	var ticks := Synth.buffer(n)
	Synth.add_impulses(ticks, rate, 24.0, 6803, 0.2, 1.0)
	var dry := Synth.formants(ticks, rate, PackedFloat32Array([3100.0, 5200.0]), PackedFloat32Array([9.0, 10.0]), PackedFloat32Array([1.0, 0.6]), true)
	Synth.scale(dry, 1.0 / maxf(1e-6, Synth.rms(dry)))
	_mix_into(out, dry, 0.01, _curve(n, 6, 6804, 0.3, 1.0))
	return out


## A buffer rendered past its loop length n: the overrun [n, size) continues
## straight on from sample n-1, so crossfading it over the start (overrun
## fading out, start fading in) makes sample 0 follow sample n-1. Returns n samples.
static func _fold_overrun(buf: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var m := buf.size() - n
	var out := buf.slice(0, n)
	for i in m:
		var t := float(i) / m
		out[i] = buf[i] * sin(t * PI * 0.5) + buf[n + i] * cos(t * PI * 0.5)
	return out


# --------------------------------------------------------------- scatter

static func _snap(rate: int, v: int) -> PackedFloat32Array:
	var n := Synth.samples(rate, 0.12)
	var b := Synth.buffer(n)
	var r := Rng.make(7001, v)
	for k in r.randi_range(2, 4):
		var at := r.randi_range(0, Synth.samples(rate, 0.04))
		Synth.add(b, _burst(rate, 0.02, 7002 + v * 5 + k, 1200.0, 6000.0, 0.012), at, r.randf_range(0.5, 1.0))
	var wood := Synth.modes(rate, 0.12, PackedFloat32Array([700.0 + v * 60.0, 1650.0 + v * 90.0]), PackedFloat32Array([0.4, 0.25]), PackedFloat32Array([0.05, 0.035]))
	Synth.add(b, wood, 0)
	return _far(b, rate, 4500.0, 0.35, 0.8)


## Stick-slip friction in a trunk: a pulse train wandering 35-70 Hz through wood.
static func _creak(rate: int, v: int) -> PackedFloat32Array:
	var secs := 0.9 + v * 0.25
	var n := Synth.samples(rate, secs)
	var b := Synth.buffer(n)
	var r := Rng.make(7101, v)
	var rate_curve := Synth.wander(n, 4, 7102 + v, 32.0, 70.0)
	var ph := 0.0
	for i in n:
		ph += rate_curve[i] / rate
		if ph >= 1.0:
			ph -= 1.0
			b[i] = r.randf_range(0.5, 1.0)
	var body := Synth.formants(b, rate, PackedFloat32Array([420.0, 980.0, 1900.0]), PackedFloat32Array([8.0, 9.0, 10.0]), PackedFloat32Array([1.0, 0.7, 0.35]))
	for i in n:
		body[i] *= pow(sin(PI * float(i) / n), 1.5)
	Synth.normalize(body, 1.0)
	return _far(body, rate, 3500.0, 0.3, 0.8)


static func _drip(rate: int, v: int) -> PackedFloat32Array:
	var f: float = [880.0, 1040.0, 1230.0, 1420.0][v % 4]
	var n := Synth.samples(rate, 0.08)
	var b := Synth.buffer(n)
	Synth.add_chirp(b, rate, f, f * 1.9, 1.0)
	Synth.env_perc(b, rate, 0.001, 0.07)
	var click := _burst(rate, 0.004, 7201 + v, 2000.0, 8000.0, 0.003)
	Synth.add(b, click, 0, 0.25)
	return _far(b, rate, 6000.0, 0.28, 0.6)


static func _bloop(rate: int, v: int) -> PackedFloat32Array:
	var f := 180.0 + (v % 5) * 22.0
	var n := Synth.samples(rate, 0.14)
	var b := Synth.buffer(n)
	Synth.add_chirp(b, rate, f, f * 1.9, 1.0)
	var h := Synth.buffer(n)
	Synth.add_chirp(h, rate, f * 2.0, f * 3.8, 0.35)
	Synth.add(b, h, 0)
	Synth.env_perc(b, rate, 0.004, 0.13)
	Synth.lowpass(b, rate, 1600.0)
	return b


static func _crust(rate: int, v: int) -> PackedFloat32Array:
	var n := Synth.samples(rate, 0.25)
	var b := Synth.buffer(n)
	Synth.add_impulses(b, rate, 160.0, 7301 + v, 0.2, 1.0)
	Synth.band(b, rate, 900.0, 2400.0, false, false)
	var body := Synth.modes(rate, 0.25, PackedFloat32Array([310.0 + v * 25.0, 760.0 + v * 40.0]), PackedFloat32Array([0.5, 0.3]), PackedFloat32Array([0.08, 0.05]))
	Synth.add(b, body, 0)
	Synth.env_perc(b, rate, 0.002, 0.22)
	return _far(b, rate, 3000.0, 0.3, 1.0)


static func _stone_tick(rate: int, v: int) -> PackedFloat32Array:
	var n := Synth.samples(rate, 0.5)
	var b := Synth.buffer(n)
	var tick := Synth.modes(rate, 0.05, PackedFloat32Array([1850.0 + v * 120.0, 3900.0, 5200.0 - v * 200.0]), PackedFloat32Array([0.6, 0.35, 0.2]), PackedFloat32Array([0.03, 0.02, 0.015]))
	var gap := 0.11 + v * 0.02
	var t := 0.0
	var g := 1.0
	for k in 3 + v % 2:
		Synth.add(b, tick, Synth.samples(rate, t), g)
		t += gap
		gap *= 0.62
		g *= 0.55
	return _far(b, rate, 5000.0, 0.35, 0.9)


static func _crackle(rate: int, v: int) -> PackedFloat32Array:
	var n := Synth.samples(rate, 0.35)
	var b := Synth.buffer(n)
	var r := Rng.make(7401, v)
	for k in r.randi_range(5, 12):
		var at := r.randi_range(0, n - Synth.samples(rate, 0.01))
		Synth.add(b, _burst(rate, 0.006, 7402 + v * 13 + k, 1500.0, 7000.0, 0.004), at, r.randf_range(0.2, 1.0))
	return b


static func _thud(rate: int, v: int) -> PackedFloat32Array:
	var n := Synth.samples(rate, 1.2)
	var b := _burst(rate, 1.2, 7501 + v, 120.0, 500.0, 0.6, 0.01)
	var body := Synth.modes(rate, 1.2, PackedFloat32Array([140.0 + v * 12.0, 212.0, 300.0 + v * 15.0]), PackedFloat32Array([0.6, 0.35, 0.2]), PackedFloat32Array([0.5, 0.35, 0.25]), 0.008)
	Synth.add(b, body, 0, 0.9)
	var bursts := _curve(n, 6, 7502 + v, 0.3, 1.0, 2.0)
	Synth.multiply(b, bursts)
	return _far(b, rate, 900.0, 0.35, 1.2)


## Stone or iron ticking as the heat works in it: one to three small exact
## ticks, off to one side.
static func _heat_tick(rate: int, v: int) -> PackedFloat32Array:
	var n := Synth.samples(rate, 0.9)
	var b := Synth.buffer(n)
	var r := Rng.make(7701, v)
	var tick := Synth.modes(rate, 0.05, PackedFloat32Array([2300.0 + v * 190.0, 5150.0]), PackedFloat32Array([0.5, 0.2]), PackedFloat32Array([0.025, 0.012]))
	var t := 0.0
	for k in 1 + v % 3:
		Synth.add(b, tick, Synth.samples(rate, t), r.randf_range(0.5, 1.0))
		t += r.randf_range(0.2, 0.3)
	return _far(b, rate, 5000.0, 0.3, 0.6)


## A diaphone somewhere in the fog: machinery nobody switched off, so exact
## integer harmonics, a steady blast and the grunt at the end.
static func _fog_horn(rate: int) -> PackedFloat32Array:
	var n := Synth.samples(rate, 3.0)
	var b := Synth.buffer(n)
	var blast := Synth.samples(rate, 2.2)
	for h in range(1, 9):
		var amp := 1.0 / pow(h, 0.9)
		Synth.add_sine(b, rate, 185.0 * h, amp * 0.3, 0, blast)
		Synth.add_sine(b, rate, 155.0 * h, amp * 0.3, blast, n - blast)
	Synth.env_adsr(b, rate, 0.25, 0.3, 0.85, 2.5, 0.35)
	return _far(b, rate, 1800.0, 0.5, 3.0)
