class_name SoundWork
## Hands at work, and the notebook: the taking verbs the fight never uses
## (scrape, tap, turn), mending an edge, putting a station down, lying down to
## sleep, a tool that will not take, and the book the interface is drawn in.
## Made things by hand: uneven timing, a little different every stroke.

const NAMES: Array[StringName] = [
	&"refuse", &"scrape", &"tap", &"turn", &"hone", &"reedge", &"build_fire", &"build_bench",
	&"build_kiln", &"sleep", &"book_open", &"book_close",
]


static func handles(name: StringName) -> bool:
	return name in NAMES


static func make(name: StringName, variant: int, rate: int) -> PackedFloat32Array:
	match name:
		&"refuse": return _refuse(rate)
		&"scrape": return _scrape(rate, variant)
		&"tap": return _tap(rate, variant)
		&"turn": return _turn(rate, variant)
		&"hone": return _hone(rate)
		&"reedge": return _reedge(rate)
		&"build_fire": return _build_fire(rate)
		&"build_bench": return _build_bench(rate)
		&"build_kiln": return _build_kiln(rate)
		&"sleep": return _sleep(rate)
		&"book_open": return _book(rate, true)
		&"book_close": return _book(rate, false)
	push_warning("no work sound %s" % name)
	return Synth.buffer(64)


# ------------------------------------------------------------------ helpers

static func _modes(rate: int, seconds: float, freqs: Array, amps: Array, t60s: Array) -> PackedFloat32Array:
	return Synth.modes(rate, seconds, PackedFloat32Array(freqs), PackedFloat32Array(amps), PackedFloat32Array(t60s))


static func _burst(rate: int, seconds: float, seed_value: int, lo: float, hi: float, t60: float, attack: float = 0.0006) -> PackedFloat32Array:
	var b := Synth.noise(Synth.samples(rate, seconds), seed_value)
	Synth.band(b, rate, lo, hi, false, false)
	Synth.env_perc(b, rate, attack, t60)
	Synth.normalize(b, 1.0)
	return b


static func _grains(rate: int, seconds: float, seed_value: int, density: float, lo: float, hi: float, attack: float, t60: float) -> PackedFloat32Array:
	var b := Synth.buffer(Synth.samples(rate, seconds))
	Synth.add_impulses(b, rate, density, seed_value, 0.05, 1.0)
	Synth.band(b, rate, lo, hi, false, false)
	Synth.env_perc(b, rate, attack, t60)
	Synth.normalize(b, 1.0)
	return b


## Friction: stick-slip pulses at a wandering rate through a resonant body,
## under a bell-shaped stroke. The rasp of a blade or a stone.
static func _friction(rate: int, seconds: float, seed_value: int, slip_lo: float, slip_hi: float, body: Array, qs: Array) -> PackedFloat32Array:
	var n := Synth.samples(rate, seconds)
	var src := Synth.buffer(n)
	var r := Rng.make(seed_value, 0x2f)
	var slip := Synth.wander(n, 5, seed_value + 1, slip_lo, slip_hi)
	var ph := 0.0
	for i in n:
		ph += slip[i] / rate
		if ph >= 1.0:
			ph -= 1.0
			src[i] = r.randf_range(0.3, 1.0)
	Synth.add(src, Synth.noise(n, seed_value + 2), 0, 0.08)
	var gains := PackedFloat32Array()
	for k in body.size():
		gains.append(1.0 / (k + 1))
	var out := Synth.formants(src, rate, PackedFloat32Array(body), PackedFloat32Array(qs), gains)
	for i in n:
		out[i] *= pow(sin(PI * float(i) / n), 1.3)
	Synth.normalize(out, 1.0)
	return out


static func _at(rate: int, seconds: float) -> int:
	return Synth.samples(rate, seconds)


# -------------------------------------------------------------------- verbs

## The tool will not take: a short dull glance off it, lower than any success
## and no louder.
static func _refuse(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 0.35))
	Synth.add(out, _modes(rate, 0.12, [290.0, 720.0, 1450.0], [0.5, 0.25, 0.08], [0.05, 0.035, 0.02]), 0, 0.9)
	Synth.add(out, _burst(rate, 0.04, 6101, 600.0, 3000.0, 0.03), 0, 0.3)
	Synth.add(out, _friction(rate, 0.12, 6102, 90.0, 140.0, [900.0, 2100.0], [5.0, 6.0]), _at(rate, 0.05), 0.25)
	return out


## Crottle off the crust: three short strokes of a blade across stone.
static func _scrape(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(6201, v)
	var out := Synth.buffer(_at(rate, 1.0))
	var t := 0.0
	for k in 3:
		var secs := r.randf_range(0.16, 0.24)
		var stroke := _friction(rate, secs, 6210 + v * 5 + k, 60.0, 130.0, [r.randf_range(1900.0, 2400.0), 3800.0, 6100.0], [6.0, 7.0, 8.0])
		Synth.add(out, stroke, _at(rate, t), r.randf_range(0.7, 1.0))
		t += secs + r.randf_range(0.06, 0.12)
	return out


## Tapping a pine: the knife point into bark twice, and flakes falling.
static func _tap(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(6301, v)
	var out := Synth.buffer(_at(rate, 0.8))
	for k in 2:
		var at := 0.0 if k == 0 else r.randf_range(0.2, 0.28)
		var f := r.randf_range(560.0, 640.0)
		Synth.add(out, _modes(rate, 0.14, [f, f * 2.3, f * 4.1], [0.5, 0.3, 0.12], [0.06, 0.04, 0.025]), _at(rate, at), 0.9 - k * 0.15)
		Synth.add(out, _burst(rate, 0.015, 6302 + v + k, 2000.0, 7000.0, 0.008), _at(rate, at), 0.35)
	Synth.add(out, _grains(rate, 0.3, 6303 + v, 60.0, 1800.0, 6000.0, 0.01, 0.25), _at(rate, 0.35), 0.3)
	return out


## Turning a tip over by hand: scrap sliding, pieces clinking, one heavy clunk.
static func _turn(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(6401, v)
	var out := Synth.buffer(_at(rate, 1.2))
	Synth.add(out, _grains(rate, 0.8, 6402 + v, 400.0, 900.0, 5000.0, 0.15, 0.6), 0, 0.4)
	Synth.add(out, _modes(rate, 0.35, [230.0, 590.0, 1270.0], [0.5, 0.3, 0.15], [0.14, 0.1, 0.06]), _at(rate, r.randf_range(0.2, 0.35)), 0.9)
	for k in 11:
		var f := r.randf_range(900.0, 3400.0)
		Synth.add(out, _modes(rate, 0.08, [f, f * 1.73, f * 2.61], [0.5, 0.25, 0.12], [0.05, 0.03, 0.02]), _at(rate, r.randf_range(0.05, 0.9)), r.randf_range(0.15, 0.5))
	return out


## An edge on the hone: three long strokes, each pass a little higher.
static func _hone(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.3))
	for k in 3:
		var stroke := _friction(rate, 0.3, 6501 + k, 180.0, 260.0, [3600.0 + k * 250.0, 5900.0, 8200.0], [9.0, 10.0, 10.0])
		Synth.add(out, stroke, _at(rate, k * 0.38), 0.85)
	return out


## Re-edging at the fire: three blows on hot iron, then the quench.
static func _reedge(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 2.0))
	var blow := _modes(rate, 0.5, [880.0, 2430.0, 4750.0], [0.5, 0.3, 0.12], [0.3, 0.15, 0.08])
	Synth.add(blow, _burst(rate, 0.02, 6601, 800.0, 5000.0, 0.012), 0, 0.4)
	for t: float in [0.0, 0.34, 0.66]:
		Synth.add(out, blow, _at(rate, t), 0.9 if t > 0.0 else 1.0)
	var hiss := Synth.noise(_at(rate, 1.0), 6602)
	Synth.band(hiss, rate, 2500.0, 9000.0, false, false)
	Synth.env_adsr(hiss, rate, 0.01, 0.1, 0.6, 0.2, 0.6)
	Synth.normalize(hiss, 1.0)
	Synth.add(out, hiss, _at(rate, 0.95), 0.45)
	Synth.add(out, _grains(rate, 0.8, 6603, 120.0, 2000.0, 6000.0, 0.01, 0.6), _at(rate, 0.97), 0.3)
	return out


# ----------------------------------------------------------------- stations

## Sticks laid, then a light struck and caught.
static func _build_fire(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 2.6))
	var r := Rng.make(6701)
	var t := 0.0
	for k in 4:
		var f := r.randf_range(480.0, 760.0)
		Synth.add(out, _modes(rate, 0.12, [f, f * 2.4], [0.5, 0.2], [0.05, 0.03]), _at(rate, t), r.randf_range(0.5, 0.8))
		t += r.randf_range(0.12, 0.2)
	Synth.add(out, SoundEffects.make(&"fire", 0, rate), _at(rate, 0.8), 0.9)
	return out


## A bench knocked together: a mallet on timber, never quite even.
static func _build_bench(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.6))
	var r := Rng.make(6801)
	var t := 0.0
	for k in 4:
		var f := r.randf_range(190.0, 215.0)
		Synth.add(out, _modes(rate, 0.3, [f, f * 2.35, f * 4.2, 1900.0], [0.5, 0.35, 0.16, 0.08], [0.14, 0.09, 0.05, 0.02]), _at(rate, t), r.randf_range(0.75, 1.0))
		Synth.add(out, _burst(rate, 0.012, 6802 + k, 1500.0, 6000.0, 0.006), _at(rate, t), 0.25)
		t += r.randf_range(0.26, 0.36)
	return out


## A kiln stacked: stone set on stone, grit, and the last one settling.
static func _build_kiln(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 1.8))
	var r := Rng.make(6901)
	var t := 0.0
	for k in 5:
		var f := r.randf_range(820.0, 1150.0)
		Synth.add(out, _modes(rate, 0.1, [f, f * 2.2, f * 3.9], [0.5, 0.25, 0.1], [0.04, 0.025, 0.015]), _at(rate, t), r.randf_range(0.6, 0.9))
		Synth.add(out, _grains(rate, 0.15, 6902 + k, 500.0, 1500.0, 6000.0, 0.003, 0.1), _at(rate, t + 0.01), 0.3)
		t += r.randf_range(0.18, 0.3)
	Synth.add(out, _burst(rate, 0.3, 6903, 150.0, 700.0, 0.2, 0.004), _at(rate, t + 0.05), 0.8)
	return out


# ------------------------------------------------------------------- resting

## Lying down: cloth pulled round, and a long breath out.
static func _sleep(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 2.2))
	var cloth := Synth.noise(_at(rate, 0.7), 7001)
	Synth.band(cloth, rate, 800.0, 5000.0, false, false)
	Synth.tremolo(cloth, rate, 11.0, 0.4)
	for i in cloth.size():
		cloth[i] *= pow(sin(PI * float(i) / cloth.size()), 2.0)
	Synth.normalize(cloth, 1.0)
	Synth.add(out, cloth, 0, 0.6)
	var air := Synth.noise(_at(rate, 1.3), 7002)
	var breath := Synth.formants(air, rate, PackedFloat32Array([520.0, 1150.0, 2400.0]), PackedFloat32Array([2.0, 3.0, 4.0]), PackedFloat32Array([1.0, 0.45, 0.15]))
	for i in breath.size():
		var u := float(i) / breath.size()
		breath[i] *= sin(PI * pow(u, 0.3)) * pow(1.0 - u, 0.6)
	Synth.normalize(breath, 1.0)
	Synth.add(out, breath, _at(rate, 0.6), 0.5)
	return out


# ------------------------------------------------------------------ notebook

## The interface is a field notebook: its pages turn and its cover closes.
static func _book(rate: int, opening: bool) -> PackedFloat32Array:
	var out := Synth.buffer(_at(rate, 0.5))
	var n := _at(rate, 0.22 if opening else 0.12)
	var page := Synth.noise(n, 7101 if opening else 7102)
	Synth.sweep_band(page, rate, Synth.glide(n, 1400.0 if opening else 3000.0, 3800.0 if opening else 1600.0), 0.9)
	Synth.tremolo(page, rate, 34.0, 0.45)
	for i in n:
		var u := float(i) / n
		page[i] *= pow(sin(PI * pow(u, 0.6 if opening else 0.3)), 2.0)
	Synth.normalize(page, 1.0)
	Synth.add(out, page, 0, 0.45)
	# Paper is not a hiss: it crackles where the sheet bends.
	var crackle := Synth.buffer(n)
	Synth.add_impulses(crackle, rate, 260.0 if opening else 180.0, 7104 if opening else 7105, 0.1, 1.0)
	Synth.band(crackle, rate, 1800.0, 7000.0, false, false)
	for i in n:
		crackle[i] *= sin(PI * float(i) / n)
	Synth.normalize(crackle, 1.0)
	Synth.add(out, crackle, 0, 0.55)
	# The cover meets the page block: a soft board, felt more than heard.
	var cover := _modes(rate, 0.12, [240.0, 530.0, 1100.0], [0.5, 0.28, 0.1], [0.05, 0.035, 0.02])
	Synth.add(cover, _burst(rate, 0.03, 7103, 500.0, 3000.0, 0.02, 0.002), 0, 0.5)
	Synth.add(out, cover, _at(rate, 0.16 if opening else 0.06), 0.5 if opening else 0.85)
	return out
