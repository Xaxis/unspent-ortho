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
	&"bed_wreck": 16.0, &"bed_hum": 8.0, &"bed_far_drone": 20.0, &"bed_gutter": 12.0,
	&"weather_rain_metal": 12.0, &"weather_rain_leaves": 12.0, &"weather_rain_water": 12.0,
}
const SHORE_CYCLE := 5.4

## Which one-shots each bed scatters: [name, min gap, max gap] seconds, and
## optionally a fourth entry of conditions (SoundMix.scatter_allowed):
##   hours: [from, to)   only then; wraps past midnight when from > to
##   fair: true           only in weather a small thing would be out in
##   wet: [kinds]         only while one of these is falling
##   wind: w              only in at least this much wind
## Together with the beds these keep ART.md's promise per country: the moss's
## still air and wisps, the pines' rain drip, the snowfield's poles.
const SCATTER := {
	&"bed_pines": [[&"pines_snap", 6.0, 22.0], [&"pines_creak", 9.0, 30.0], [&"bird_song", 5.0, 16.0, {"hours": [4.8, 9.5], "fair": true}],
		[&"pines_drip", 1.2, 4.0, {"wet": [&"rain", &"storm", &"hail"]}]],
	&"bed_moss": [[&"moss_drip", 0.5, 2.4], [&"moss_bloop", 7.0, 26.0], [&"bird_song", 9.0, 26.0, {"hours": [4.8, 9.0], "fair": true}],
		[&"moss_wisp", 14.0, 40.0, {"hours": [21.0, 4.5]}]],
	&"bed_snowfield": [[&"snow_creak", 10.0, 35.0], [&"wire_sing", 9.0, 26.0, {"wind": 0.45}]],
	&"bed_bones": [[&"bones_tick", 5.0, 18.0]],
	&"bed_burning": [[&"burning_crackle", 0.6, 3.5], [&"burning_thud", 9.0, 28.0]],
	&"bed_shore": [[&"shore_gull", 7.0, 30.0, {"hours": [6.5, 19.5], "fair": true}]],
	&"bed_wind": [[&"bird_song", 7.0, 20.0, {"hours": [5.0, 9.0], "fair": true}]],
	# The dystopia in the air: what the wind finds in wreckage, what an
	# installation does to itself, what rain does to a roof nobody mends.
	&"bed_wreck": [[&"wreck_knock", 4.0, 16.0, {"wind": 0.3}], [&"chain_clink", 6.0, 22.0]],
	&"bed_hum": [[&"relay_click", 3.0, 12.0], [&"arc_snap", 8.0, 30.0, {"wet": [&"rain", &"storm", &"fog", &"hail"]}]],
	&"bed_gutter": [[&"gutter_drip", 1.2, 4.5]],
}

## One-shots scattered by what works_near found rather than by a bed: wire
## strung on poles sings, faintly, when the wind is up. field -> entries.
const WORKS_SCATTER := {
	"wires": [[&"wire_sing", 10.0, 30.0, {"wind": 0.4}]],
}


## The level a WORKS_SCATTER field scatters at, from works_near's result.
static func works_scatter_level(field: String, works: Dictionary) -> float:
	match field:
		"wires":
			return clampf(float(works.get("wires", 0.0)), 0.0, 1.0) * SoundMix.WIRE_FAINT
	return 0.0


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
		&"bird_song": return SoundCreatures.bird(rate, variant)
		&"heat_tick": return _heat_tick(rate, variant)
		&"pines_drip": return _pines_drip(rate, variant)
		&"moss_wisp": return _wisp(rate, variant)
		&"wire_sing": return _wire_sing(rate, variant)
		&"fog_horn": return _fog_horn(rate)
		&"bed_wreck": return _wreck(rate)
		&"bed_hum": return _hum(rate)
		&"bed_far_drone": return _far_drone(rate)
		&"bed_gutter": return _gutter(rate)
		&"weather_rain_metal": return _rain_metal(rate)
		&"weather_rain_leaves": return _rain_leaves(rate)
		&"weather_rain_water": return _rain_water(rate)
		&"wreck_knock": return _wreck_knock(rate, variant)
		&"chain_clink": return _chain_clink(rate, variant)
		&"relay_click": return _relay_click(rate, variant)
		&"arc_snap": return _arc_snap(rate, variant)
		&"gutter_drip": return _gutter_drip(rate, variant)
		&"thunder_roll": return _thunder_roll(rate, variant)
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


## Periodic band noise whose centre follows `curve` (0..1 -> lo..hi Hz): wind
## through something, climbing as it rises. Unit RMS. The swept filter has no
## tail to prime from, so it runs past the loop and folds the overrun back.
static func _sough(n: int, rate: int, seed_value: int, curve: PackedFloat32Array, lo: float, hi: float, q: float) -> PackedFloat32Array:
	var extra := Synth.samples(rate, 0.5)
	var centre := PackedFloat32Array()
	centre.resize(n + extra)
	for i in n + extra:
		centre[i] = lo * pow(hi / lo, curve[i % n])
	var b := Synth.noise(n + extra, seed_value)
	Synth.sweep_band(b, rate, centre, q)
	var looped := _fold_overrun(b, n)
	Synth.scale(looped, 1.0 / maxf(1e-6, Synth.rms(looped)))
	return looped


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


## Open-country wind: a body that swells deep and slow, its band climbing as
## it rises (air speeding up whistles higher), grass hiss riding the same
## gusts, and a faint moan where it finds an edge.
static func _wind(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_wind", rate)
	var out := Synth.buffer(n)
	var gusts := _curve(n, 7, 5402, 0.0, 1.0)
	var level := PackedFloat32Array()
	level.resize(n)
	for i in n:
		level[i] = lerpf(0.22, 1.0, pow(gusts[i], 1.4))
	_mix_into(out, _sough(n, rate, 5401, gusts, 380.0, 1300.0, 1.6), 0.075, level)
	_mix_into(out, _band(n, rate, 5403, 1100.0, 3800.0), 0.03, _curve(n, 11, 5404, 0.2, 1.0, 2.0))
	_mix_into(out, _band(n, rate, 5405, 3000.0, 7000.0), 0.012, level)
	var moan := Synth.noise(n, 5407)
	Synth.resonate(moan, rate, 430.0, 7.0, true)
	Synth.scale(moan, 1.0 / maxf(1e-6, Synth.rms(moan)))
	_mix_into(out, moan, 0.011, _curve(n, 5, 5408, 0.0, 1.0, 4.0))
	return out


## Pines: the canopy soughing, a long rise as a gust comes through the stand
## (the needles' hiss climbing from 900 Hz toward 2.6 kHz and falling back), a
## farther stand answering out of step, a trunk band kept above the laptop
## line, and the top rolled off: needles hiss, they do not fizz.
static func _pines(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_pines", rate)
	var out := Synth.buffer(n)
	var near := _curve(n, 6, 5502, 0.0, 1.0)
	var near_level := PackedFloat32Array()
	near_level.resize(n)
	for i in n:
		near_level[i] = lerpf(0.08, 1.0, pow(near[i], 2.4))
	_mix_into(out, _sough(n, rate, 5501, near, 900.0, 2600.0, 1.3), 0.07, near_level)
	var far := _curve(n, 5, 5504, 0.0, 1.0)
	var far_level := PackedFloat32Array()
	far_level.resize(n)
	for i in n:
		far_level[i] = lerpf(0.3, 1.0, far[i])
	_mix_into(out, _sough(n, rate, 5503, far, 600.0, 1500.0, 1.1), 0.035, far_level)
	_mix_into(out, _band(n, rate, 5505, 130.0, 260.0), 0.018, _curve(n, 4, 5506, 0.5, 1.0))
	Synth.lowpass(out, rate, 5200.0, 0.7071, true)
	return out


## Moss: still air under 420 Hz, wet peat ticking and popping (tiny drips,
## each at its own pitch, so they never ring into a chord), a far seep, and
## the odd bubble. Nearer drips are scattered live so they never fall in a
## pattern.
static func _moss(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_moss", rate)
	var out := Synth.buffer(n)
	var air := Synth.pink(n, 5601, true)
	Synth.band(air, rate, 120.0, 420.0, true)
	Synth.scale(air, 1.0 / maxf(1e-6, Synth.rms(air)))
	_mix_into(out, air, 0.035, _curve(n, 3, 5602, 0.7, 1.0))
	var peat := Synth.buffer(n)
	var r := Rng.make(5603)
	var busy := _curve(n, 6, 5604, 0.15, 1.0, 1.5)
	var count := roundi(26.0 * n / rate)
	for k in count:
		var at := r.randi_range(0, n - 1)
		if r.randf() > busy[at]:
			continue
		var m := Synth.samples(rate, r.randf_range(0.008, 0.022))
		var tick := Synth.buffer(m)
		var f := r.randf_range(900.0, 2800.0)
		Synth.add_chirp(tick, rate, f, f * r.randf_range(1.05, 1.5), 1.0)
		Synth.env_perc(tick, rate, 0.0008, m / float(rate))
		Synth.add(peat, tick, at, r.randf_range(0.2, 1.0), true)
	Synth.scale(peat, 1.0 / maxf(1e-6, Synth.rms(peat)))
	_mix_into(out, peat, 0.012)
	_mix_into(out, _band(n, rate, 5605, 800.0, 2000.0), 0.004)
	var rb := Rng.make(5606)
	for k in 5:
		var b := _bloop(rate, k + 10)
		Synth.add(out, b, rb.randi_range(0, n - 1), 0.05, true)
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
	# D3 and A3 as the research has them, and the octave and fifth above that
	# a laptop can actually play, so the grikes are heard on one.
	var tones := [[146.8, 5803, 5], [220.0, 5804, 6], [293.6, 5805, 4], [440.0, 5806, 7]]
	var gains := [0.04, 0.035, 0.03, 0.02]
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
		Synth.add(works, far_clank, k * n / clanks + n / 13, 0.2, true)
	Synth.lowpass4(works, rate, 950.0, true)
	var air := _curve(n, 5, 8103, 0.35, 1.0, 1.5)
	var out := Synth.buffer(n)
	_mix_into(out, works, 1.0, air)
	_mix_into(out, _band(n, rate, 8104, 160.0, 700.0, true), 0.008, _curve(n, 4, 8105, 0.5, 1.0))
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


## Heavy rain, a wind roar in swells, and a whistle.
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
	# No thunder baked in: rolls on a loop repeat where anyone can hear it. The
	# sky strikes, and thunder is played where and when it lands.
	return out


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


## Rain collecting in the canopy and letting go: fat drops onto needles and
## the floor, a few at a time, never together.
static func _pines_drip(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(7801, v)
	var out := Synth.buffer(Synth.samples(rate, 1.8))
	for k in r.randi_range(3, 7):
		var at := Synth.samples(rate, r.randf_range(0.0, 1.4))
		var f := r.randf_range(620.0, 1700.0)
		var drop := Synth.buffer(Synth.samples(rate, 0.05))
		Synth.add_chirp(drop, rate, f, f * r.randf_range(1.3, 2.0), 1.0)
		Synth.env_perc(drop, rate, 0.001, 0.04)
		Synth.add(out, drop, at, r.randf_range(0.4, 1.0))
		var tap := _burst(rate, 0.03, 7802 + v * 9 + k, 1200.0, 5000.0, 0.02)
		Synth.add(out, tap, at, r.randf_range(0.2, 0.5))
	return _far(out, rate, 5500.0, 0.25, 0.5)


## Something cold and lit over the black water at night: a thin glassy chord
## that swells in and out, its partials beating slowly against each other.
static func _wisp(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(7901, v)
	var secs := r.randf_range(1.8, 2.6)
	var n := Synth.samples(rate, secs)
	var out := Synth.buffer(n)
	var base := r.randf_range(1900.0, 2600.0)
	for k: float in [1.0, 1.498, 2.013]:
		Synth.add_sine(out, rate, base * k, 0.3 / k)
		Synth.add_sine(out, rate, base * k * 1.0035, 0.2 / k)
	for i in n:
		out[i] *= pow(sin(PI * float(i) / n), 3.0)
	return _far(out, rate, 7000.0, 0.4, 1.4)


## Wind on the lines between the poles: an aeolian tone that rises with the
## gust and wavers, with its octave, and dies off.
static func _wire_sing(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(8001, v)
	var secs := r.randf_range(2.2, 3.4)
	var n := Synth.samples(rate, secs)
	var out := Synth.buffer(n)
	var f0 := r.randf_range(420.0, 760.0)
	var drift := Synth.wander(n, 5, 8002 + v, 0.97, 1.05)
	var ph := 0.0
	for i in n:
		var u := float(i) / n
		ph += TAU * f0 * drift[i] * lerpf(0.96, 1.04, sin(PI * u)) / rate
		out[i] = (sin(ph) + 0.35 * sin(2.0 * ph) + 0.1 * sin(3.0 * ph)) * pow(sin(PI * pow(u, 0.7)), 2.0)
	var air := _burst(rate, secs, 8003 + v, 1500.0, 5000.0, secs, 0.3)
	Synth.add(out, air, 0, 0.08)
	return _far(out, rate, 4000.0, 0.3, 1.0)


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


# ----------------------------------------------------------- the dystopia

## Wind through wreckage and wire: a shell of sheet steel singing in its own
## hollow modes as a gust rises, two strands of wire whistling out of step, loose
## things rattling at the top of a gust, and a torn sheet flapping when it blows hard.
static func _wreck(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_wreck", rate)
	var out := Synth.buffer(n)
	var gusts := _curve(n, 7, 9101, 0.0, 1.0)
	var level := PackedFloat32Array()
	level.resize(n)
	for i in n:
		level[i] = lerpf(0.15, 1.0, pow(gusts[i], 1.3))
	var shell_in := _band(n, rate, 9102, 150.0, 1600.0)
	for i in n:
		shell_in[i] *= level[i]
	var shell := Synth.formants(shell_in, rate, PackedFloat32Array([187.0, 311.0, 463.0, 742.0, 1130.0]), PackedFloat32Array([22.0, 26.0, 30.0, 24.0, 20.0]), PackedFloat32Array([1.0, 0.8, 0.6, 0.45, 0.3]), true)
	Synth.scale(shell, 1.0 / maxf(1e-6, Synth.rms(shell)))
	_mix_into(out, shell, 0.05)
	_mix_into(out, _sough(n, rate, 9103, gusts, 820.0, 1500.0, 28.0), 0.02, level)
	_mix_into(out, _sough(n, rate, 9104, _curve(n, 5, 9105, 0.0, 1.0), 1210.0, 2150.0, 32.0), 0.012, level)
	_mix_into(out, _band(n, rate, 9106, 400.0, 1400.0), 0.03, level)
	var rattle := Synth.buffer(n)
	var r := Rng.make(9107)
	for k in roundi(40.0 * n / rate):
		var at := r.randi_range(0, n - 1)
		if r.randf() > pow(gusts[at], 2.0):
			continue
		Synth.add(rattle, _burst(rate, 0.012, 9120 + k, 2200.0, 5200.0, 0.008), at, r.randf_range(0.3, 1.0), true)
	_mix_into(out, rattle, 0.03)
	var flap := _band(n, rate, 9108, 300.0, 900.0)
	var w := TAU * Synth.snap_freq(7.0, rate, n) / rate
	for i in n:
		var gate := maxf(0.0, sin(w * i))
		flap[i] *= gate * gate * smoothstep(0.55, 0.9, gusts[i])
	_mix_into(out, flap, 0.03)
	return out


## An installation humming to itself: the 100 Hz of magnetostriction and its
## harmonics, exact, with the fundamental left under the laptop line so the
## harmonics carry it; a clipped copy buzzing up to 3 kHz as it breathes; a thin
## coil whine; static in the air around it.
static func _hum(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_hum", rate)
	var out := Synth.buffer(n)
	Synth.add_partials(out, rate, PackedFloat32Array([100.0, 200.0, 300.0, 400.0, 500.0, 600.0, 800.0, 1000.0]), PackedFloat32Array([0.008, 0.05, 0.035, 0.03, 0.012, 0.018, 0.008, 0.005]), 9201)
	var buzz := Synth.buffer(n)
	Synth.add_partials(buzz, rate, PackedFloat32Array([100.0, 200.0]), PackedFloat32Array([1.0, 0.6]), 9202)
	Synth.saturate(buzz, 6.0)
	Synth.band(buzz, rate, 600.0, 3200.0, true, false)
	Synth.scale(buzz, 1.0 / maxf(1e-6, Synth.rms(buzz)))
	_mix_into(out, buzz, 0.012, _curve(n, 3, 9203, 0.3, 1.0, 2.0))
	var whine := Synth.buffer(n)
	Synth.add_sine(whine, rate, Synth.snap_freq(3150.0, rate, n), 1.0)
	_mix_into(out, whine, 0.003, _curve(n, 4, 9204, 0.0, 1.0, 3.0))
	var crackle := Synth.buffer(n)
	Synth.add_impulses(crackle, rate, 60.0, 9205, 0.05, 1.0)
	Synth.band(crackle, rate, 3000.0, 8000.0, true)
	Synth.scale(crackle, 1.0 / maxf(1e-6, Synth.rms(crackle)))
	_mix_into(out, crackle, 0.004, _curve(n, 5, 9206, 0.0, 1.0, 2.0))
	return out


## The machines at work a long way off, by day as well as night: a low wrong
## chord (harmonics of 55 Hz with a flattened third among them) swinging slowly
## in pitch as if something the size of a hill turned, dull with distance and
## swelling as the air carries it.
static func _far_drone(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_far_drone", rate)
	var chord := Synth.buffer(n)
	var partials: Array[float] = [165.0, 220.0, 262.0, 275.0, 330.0, 392.0, 440.0]
	var amps: Array[float] = [0.05, 0.04, 0.02, 0.03, 0.025, 0.012, 0.01]
	var bend := TAU / n
	for k in partials.size():
		var f := Synth.snap_freq(partials[k], rate, n)
		var phk := Rng.hash01(9301, k) * TAU
		var ph := 0.0
		for i in n:
			ph += TAU * f * (1.0 + 0.004 * sin(bend * i + phk)) / rate
			chord[i] += amps[k] * sin(ph)
	Synth.lowpass4(chord, rate, 900.0, true)
	var out := Synth.buffer(n)
	_mix_into(out, chord, 1.0, _curve(n, 3, 9302, 0.45, 1.0, 1.4))
	_mix_into(out, _band(n, rate, 9303, 130.0, 320.0, true), 0.012, _curve(n, 4, 9304, 0.3, 1.0))
	return out


## Rain finding its way down a broken downpipe (a thin gurgle through the pipe's
## own resonances) and dripping onto tin and into standing water.
static func _gutter(rate: int) -> PackedFloat32Array:
	var n := _n(&"bed_gutter", rate)
	var out := Synth.buffer(n)
	var trickle := Synth.buffer(n)
	var r := Rng.make(9401)
	for k in 900:
		var len_s := r.randf_range(0.006, 0.02)
		var f := r.randf_range(900.0, 2600.0)
		var b := Synth.buffer(Synth.samples(rate, len_s))
		Synth.add_chirp(b, rate, f, f * r.randf_range(1.2, 1.8), 1.0)
		Synth.env_perc(b, rate, 0.001, len_s)
		Synth.add(trickle, b, r.randi_range(0, n - 1), r.randf_range(0.2, 1.0), true)
	var pipe := Synth.formants(trickle, rate, PackedFloat32Array([460.0, 1250.0, 2300.0]), PackedFloat32Array([5.0, 6.0, 7.0]), PackedFloat32Array([1.0, 0.7, 0.4]), true)
	Synth.scale(pipe, 1.0 / maxf(1e-6, Synth.rms(pipe)))
	_mix_into(out, pipe, 0.04, _curve(n, 5, 9402, 0.5, 1.0))
	var t := 0.0
	var k := 0
	while t < LENGTH[&"bed_gutter"] - 0.2:
		t += r.randf_range(0.5, 1.7)
		var at := Synth.samples(rate, t)
		if r.randf() < 0.55:
			var tin := Synth.modes(rate, 0.12, PackedFloat32Array([1900.0 + k * 37.0, 3150.0, 4700.0]), PackedFloat32Array([1.0, 0.5, 0.3]), PackedFloat32Array([0.07, 0.05, 0.03]))
			Synth.add(out, tin, at, 0.05 * r.randf_range(0.5, 1.0), true)
		else:
			var f := r.randf_range(900.0, 1400.0)
			var plip := Synth.buffer(Synth.samples(rate, 0.06))
			Synth.add_chirp(plip, rate, f, f * 1.8, 1.0)
			Synth.env_perc(plip, rate, 0.001, 0.05)
			Synth.add(out, plip, at, 0.04 * r.randf_range(0.5, 1.0), true)
		k += 1
	return out


## Rain on metal: a sheet's high modes pinged by every drop, the drum of the
## sheet under the fat ones, a wash over both. Roofs nobody mends, hulls, cars.
static func _rain_metal(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_rain_metal", rate)
	var out := Synth.buffer(n)
	var patter := Synth.buffer(n)
	Synth.add_impulses(patter, rate, 1600.0, 9501, 0.05, 1.0)
	var ping := Synth.formants(patter, rate, PackedFloat32Array([2350.0, 3720.0, 5480.0, 7300.0]), PackedFloat32Array([14.0, 16.0, 18.0, 20.0]), PackedFloat32Array([1.0, 0.8, 0.6, 0.4]), true)
	Synth.scale(ping, 1.0 / maxf(1e-6, Synth.rms(ping)))
	_mix_into(out, ping, 0.05, _curve(n, 5, 9502, 0.8, 1.0))
	var drops := Synth.buffer(n)
	Synth.add_impulses(drops, rate, 70.0, 9503, 0.4, 1.0)
	var drum := Synth.formants(drops, rate, PackedFloat32Array([410.0, 655.0, 980.0, 1460.0]), PackedFloat32Array([9.0, 10.0, 11.0, 12.0]), PackedFloat32Array([1.0, 0.8, 0.6, 0.4]), true)
	Synth.scale(drum, 1.0 / maxf(1e-6, Synth.rms(drum)))
	_mix_into(out, drum, 0.03)
	_mix_into(out, _band(n, rate, 9504, 1200.0, 6000.0), 0.025)
	return out


## Rain on leaves and needles: a dense soft patter high up, leaves ticking, and
## the canopy letting go of heavier drops below.
static func _rain_leaves(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_rain_leaves", rate)
	var out := Synth.buffer(n)
	var patter := Synth.buffer(n)
	Synth.add_impulses(patter, rate, 4800.0, 9601, 0.05, 1.0)
	Synth.band(patter, rate, 1500.0, 7000.0, true, false)
	Synth.scale(patter, 1.0 / maxf(1e-6, Synth.rms(patter)))
	_mix_into(out, patter, 0.06, _curve(n, 5, 9602, 0.7, 1.0))
	var ticks := Synth.buffer(n)
	Synth.add_impulses(ticks, rate, 260.0, 9603, 0.2, 1.0)
	var leaf := Synth.formants(ticks, rate, PackedFloat32Array([3400.0, 4700.0]), PackedFloat32Array([5.0, 6.0]), PackedFloat32Array([1.0, 0.7]), true)
	Synth.scale(leaf, 1.0 / maxf(1e-6, Synth.rms(leaf)))
	_mix_into(out, leaf, 0.02)
	var fat := Synth.buffer(n)
	Synth.add_impulses(fat, rate, 50.0, 9604, 0.4, 1.0)
	Synth.band(fat, rate, 600.0, 1700.0, true, false)
	Synth.scale(fat, 1.0 / maxf(1e-6, Synth.rms(fat)))
	_mix_into(out, fat, 0.03)
	return out


## Rain on water: plinks and small bubbles everywhere, a hiss, the low wash of
## the surface taking it.
static func _rain_water(rate: int) -> PackedFloat32Array:
	var n := _n(&"weather_rain_water", rate)
	var out := Synth.buffer(n)
	var r := Rng.make(9701)
	for k in 1400:
		var len_s := r.randf_range(0.01, 0.03)
		var f := r.randf_range(1100.0, 3800.0)
		var b := Synth.buffer(Synth.samples(rate, len_s))
		Synth.add_chirp(b, rate, f, f * r.randf_range(1.3, 1.9), 1.0)
		Synth.env_perc(b, rate, 0.001, len_s)
		Synth.add(out, b, r.randi_range(0, n - 1), r.randf_range(0.02, 0.06), true)
	_mix_into(out, _band(n, rate, 9702, 2500.0, 8500.0), 0.03)
	var wash := Synth.pink(n, 9703, true)
	Synth.band(wash, rate, 300.0, 900.0, true)
	Synth.scale(wash, 1.0 / maxf(1e-6, Synth.rms(wash)))
	_mix_into(out, wash, 0.03, _curve(n, 4, 9704, 0.7, 1.0))
	return out


## A loose panel banging in a gust: one to three knocks of thin steel.
static func _wreck_knock(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(9801, v)
	var out := Synth.buffer(Synth.samples(rate, 1.2))
	var t := 0.0
	for k in 1 + v % 3:
		var body := Synth.modes(rate, 0.6, PackedFloat32Array([160.0 + v * 17.0, 233.0 + v * 9.0, 377.0, 612.0]), PackedFloat32Array([1.0, 0.7, 0.45, 0.25]), PackedFloat32Array([0.35, 0.3, 0.2, 0.12]))
		Synth.add(body, _burst(rate, 0.05, 9802 + v * 7 + k, 200.0, 1200.0, 0.04), 0, 0.4)
		Synth.add(out, body, Synth.samples(rate, t), r.randf_range(0.5, 1.0))
		t += r.randf_range(0.12, 0.3)
	return _far(out, rate, 3000.0, 0.3, 1.0)


## Chain or wire links clinking against each other.
static func _chain_clink(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(9811, v)
	var out := Synth.buffer(Synth.samples(rate, 0.6))
	var t := 0.0
	for k in 2 + v % 3:
		var link := Synth.modes(rate, 0.1, PackedFloat32Array([2100.0 + v * 140.0 + k * 60.0, 3400.0, 5200.0]), PackedFloat32Array([1.0, 0.5, 0.3]), PackedFloat32Array([0.08, 0.05, 0.03]))
		Synth.add(out, link, Synth.samples(rate, t), r.randf_range(0.4, 1.0))
		t += r.randf_range(0.06, 0.14)
	return _far(out, rate, 6000.0, 0.25, 0.6)


## A relay somewhere in a cabinet: a hard click, a hollow tock, and sometimes
## the release a moment later.
static func _relay_click(rate: int, v: int) -> PackedFloat32Array:
	var out := Synth.buffer(Synth.samples(rate, 0.3))
	for k in 1 + v % 2:
		var at := Synth.samples(rate, 0.03 + k * (0.04 + v * 0.01))
		Synth.add(out, _burst(rate, 0.015, 9821 + v * 3 + k, 2000.0, 6000.0, 0.006), at, 0.5 - k * 0.2)
		# The armature's clack in its steel housing: a body, not only a click.
		var body := Synth.modes(rate, 0.12, PackedFloat32Array([620.0 + v * 60.0, 1340.0 + v * 45.0, 2900.0]), PackedFloat32Array([0.8, 0.5, 0.3]), PackedFloat32Array([0.05, 0.035, 0.02]))
		Synth.add(out, body, at, 1.0 - k * 0.35)
	return _far(out, rate, 9000.0, 0.12, 0.3)


## Current arcing across something wet: a crack, a sizzle that thins out, and a
## breath of 100 Hz buzz.
static func _arc_snap(rate: int, v: int) -> PackedFloat32Array:
	var secs := 0.45 + v * 0.15
	var n := Synth.samples(rate, secs)
	var out := Synth.buffer(n)
	Synth.add(out, _burst(rate, 0.02, 9831 + v, 800.0, 8000.0, 0.012), 0, 1.0)
	var sizzle := Synth.buffer(n)
	Synth.add_impulses(sizzle, rate, 900.0, 9832 + v, 0.1, 1.0)
	Synth.band(sizzle, rate, 1500.0, 7000.0, false, false)
	Synth.env_perc(sizzle, rate, 0.002, secs * 0.8)
	Synth.add(out, sizzle, 0, 0.5)
	var buzz := Synth.buffer(n)
	Synth.add_partials(buzz, rate, PackedFloat32Array([200.0, 300.0, 400.0]), PackedFloat32Array([0.3, 0.2, 0.15]))
	Synth.env_perc(buzz, rate, 0.01, secs * 0.6)
	Synth.add(out, buzz, 0, 0.4)
	return _far(out, rate, 8000.0, 0.2, 0.6)


## A fat drop off a gutter into a tin can.
static func _gutter_drip(rate: int, v: int) -> PackedFloat32Array:
	var out := Synth.modes(rate, 0.3, PackedFloat32Array([1450.0 + v * 120.0, 2980.0 + v * 40.0, 4400.0]), PackedFloat32Array([1.0, 0.5, 0.25]), PackedFloat32Array([0.18, 0.1, 0.06]))
	Synth.add(out, _burst(rate, 0.02, 9841 + v, 1500.0, 6000.0, 0.01), 0, 0.3)
	return _far(out, rate, 7000.0, 0.25, 0.5)


## Thunder far beyond sight: a long roll of rumbles overlapping, no crack.
static func _thunder_roll(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(9851, v)
	var secs := 6.0 + v
	var n := Synth.samples(rate, secs)
	var out := Synth.buffer(n)
	for k in r.randi_range(8, 14):
		var len_s := r.randf_range(0.8, 2.4)
		var b := _burst(rate, len_s, 9852 + v * 31 + k, 110.0, 700.0, len_s * 0.8, len_s * 0.3)
		Synth.add(out, b, Synth.samples(rate, r.randf_range(0.0, secs - len_s)), r.randf_range(0.3, 1.0) * (1.0 - float(k) / 16.0))
	Synth.lowpass(out, rate, 600.0)
	return _far(out, rate, 500.0, 0.4, 2.0)
