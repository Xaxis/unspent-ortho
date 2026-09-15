class_name SoundCreatures
## The living: dogs, the bull, gulls, small birds at first light, and a body
## going down. Everything here wanders, the opposite of a machine: pitch drifts
## through each call, pulses jitter, no two takes share timing. Distance is timbre (gull(far = true) is
## duller and wetter), matched on loudness to the near call by the mix sheet.

const NAMES: Array[StringName] = [&"dog_bark", &"dog_growl", &"bull_snort", &"bull_paw", &"gull_cry", &"snatch_gull", &"beast_down", &"bird_song"]


static func handles(name: StringName) -> bool:
	return name in NAMES


static func make(name: StringName, variant: int, rate: int) -> PackedFloat32Array:
	match name:
		&"dog_bark": return _dog(rate, variant)
		&"dog_growl": return _growl(rate, variant)
		&"bull_snort": return _bull(rate, variant)
		&"bull_paw": return _paw(rate, variant)
		&"gull_cry": return gull(rate, variant, false)
		&"snatch_gull": return _snatch_gull(rate, variant)
		&"beast_down": return _beast_down(rate)
		&"bird_song": return bird(rate, variant)
	push_warning("no creature %s" % name)
	return Synth.buffer(64)


# ------------------------------------------------------------------ helpers

## A voiced source: a narrow pulse train whose pitch follows `pitch(u)` over
## the call (u 0..1), with per-cycle jitter (the throat is not a clock) and
## breath mixed in. Unit peak.
static func _voice(rate: int, seconds: float, pitch: Callable, seed_value: int, duty: float, jitter: float, breath: float) -> PackedFloat32Array:
	var n := Synth.samples(rate, seconds)
	var out := Synth.buffer(n)
	var r := Rng.make(seed_value, 0x7c)
	var ph := 0.0
	var wobble := 1.0
	for i in n:
		var u := float(i) / n
		ph += float(pitch.call(u)) * wobble / rate
		if ph >= 1.0:
			ph -= 1.0
			wobble = 1.0 + r.randf_range(-jitter, jitter)
		out[i] = 1.0 if ph < duty else -duty / (1.0 - duty)
	var air := Synth.noise(n, seed_value + 1)
	Synth.add(out, air, 0, breath)
	Synth.normalize(out, 1.0)
	return out


static func _shape(buf: PackedFloat32Array, attack_share: float, power: float) -> void:
	var n := buf.size()
	for i in n:
		var u := float(i) / n
		var e := (u / attack_share) if u < attack_share else pow(1.0 - (u - attack_share) / (1.0 - attack_share), power)
		buf[i] *= e


static func _formed(src: PackedFloat32Array, rate: int, freqs: Array, qs: Array, gains: Array) -> PackedFloat32Array:
	var b := Synth.formants(src, rate, PackedFloat32Array(freqs), PackedFloat32Array(qs), PackedFloat32Array(gains))
	Synth.normalize(b, 1.0)
	return b


# -------------------------------------------------------------------- calls

## One to three barks: a rough pitch that jumps up and falls, through a
## muzzle's formants. The yard dog is a warning, not a monster.
static func _dog(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(5301, v)
	var out := Synth.buffer(Synth.samples(rate, 1.0))
	var t := 0.0
	var barks := 2 + v % 2
	for k in barks:
		var secs := r.randf_range(0.09, 0.14)
		var top := r.randf_range(560.0, 700.0)
		var fall := r.randf_range(0.55, 0.7)
		var src := _voice(rate, secs, func(u: float) -> float:
			return top * (0.85 + 0.25 * sin(PI * minf(1.0, u * 2.5))) * lerpf(1.0, fall, u), 5310 + v * 7 + k, 0.22, 0.06, 0.35)
		var bark := _formed(src, rate, [r.randf_range(760.0, 900.0), 1650.0, 2900.0], [3.0, 4.0, 5.0], [1.0, 0.7, 0.35])
		_shape(bark, 0.08, 1.6)
		Synth.add(out, bark, Synth.samples(rate, t), r.randf_range(0.8, 1.0))
		t += secs + r.randf_range(0.14, 0.26)
	return out


## The dog's tell before it goes for you: a growl that tightens, the lip up.
## Short (a dog winds up in a quarter of a second), rough (the throat jitters
## hard), its pitch and its snarl rising into the bite.
static func _growl(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(5351, v)
	var secs := r.randf_range(0.26, 0.32)
	var base := r.randf_range(150.0, 175.0)
	var src := _voice(rate, secs, func(u: float) -> float:
		return base * (1.0 + 0.35 * u * u) * (1.0 + 0.06 * sin(TAU * 31.0 * u * secs)), 5352 + v, 0.14, 0.18, 0.3)
	# The snarl: formants opening as the lip comes up.
	var growl := _formed(src, rate, [520.0, 1250.0, 2600.0], [3.0, 4.0, 5.0], [1.0, 0.7, 0.45])
	var bright := _formed(src, rate, [780.0, 1800.0, 3200.0], [3.0, 4.0, 5.0], [1.0, 0.8, 0.5])
	var out := Synth.buffer(Synth.samples(rate, secs + 0.05))
	for i in growl.size():
		var u := float(i) / growl.size()
		var e := smoothstep(0.0, 0.25, u) * (0.55 + 0.45 * u) * (1.0 - smoothstep(0.9, 1.0, u))
		out[i] = (growl[i] * (1.0 - u) + bright[i] * u) * e
	return out


## The bull's tell: a hoof dragged back through the ground twice and a hard
## breath out through the nose, head down.
static func _paw(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(5451, v)
	var out := Synth.buffer(Synth.samples(rate, 0.62))
	var t := 0.0
	for k in 2:
		var n := Synth.samples(rate, r.randf_range(0.11, 0.15))
		var scrape := Synth.buffer(n)
		Synth.add_impulses(scrape, rate, 900.0, 5452 + v * 5 + k, 0.1, 1.0)
		Synth.add(scrape, Synth.noise(n, 5460 + v * 5 + k), 0, 0.15)
		Synth.sweep_band(scrape, rate, Synth.glide(n, 1600.0, 500.0), 1.2)
		_shape(scrape, 0.2, 1.5)
		Synth.normalize(scrape, 1.0)
		Synth.add(out, scrape, Synth.samples(rate, t), 0.7 if k == 0 else 0.85)
		# The hoof meets the ground at the end of the drag.
		var thud := Synth.noise(Synth.samples(rate, 0.06), 5470 + v * 5 + k)
		Synth.band(thud, rate, 160.0, 700.0, false, false)
		Synth.env_perc(thud, rate, 0.003, 0.05)
		Synth.normalize(thud, 1.0)
		Synth.add(out, thud, Synth.samples(rate, t) + n - Synth.samples(rate, 0.02), 0.5)
		t += float(n) / rate + r.randf_range(0.04, 0.07)
	var blow := Synth.noise(Synth.samples(rate, 0.2), 5480 + v)
	var nose := _formed(blow, rate, [650.0, 1600.0, 3300.0], [2.5, 3.0, 4.0], [1.0, 0.6, 0.3])
	_shape(nose, 0.08, 2.2)
	Synth.add(out, nose, Synth.samples(rate, minf(t, 0.4)), 0.75)
	return out


## A snort through the nose, then a short low grunt that is mostly chest.
static func _bull(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(5401, v)
	var out := Synth.buffer(Synth.samples(rate, 1.5))
	var snort := Synth.noise(Synth.samples(rate, 0.32), 5402 + v)
	var nose := _formed(snort, rate, [620.0, 1500.0, 3200.0], [2.5, 3.0, 4.0], [1.0, 0.6, 0.3])
	_shape(nose, 0.12, 2.5)
	Synth.add(out, nose, 0, 0.8)
	var base := r.randf_range(128.0, 142.0)
	var src := _voice(rate, 0.75, func(u: float) -> float:
		return base * (1.0 + 0.14 * sin(PI * pow(u, 0.6))) * lerpf(1.0, 0.86, u * u), 5403 + v, 0.3, 0.04, 0.12)
	var grunt := _formed(src, rate, [430.0, 1050.0, 2300.0], [4.0, 5.0, 6.0], [1.0, 0.55, 0.2])
	_shape(grunt, 0.15, 1.4)
	Synth.add(out, grunt, Synth.samples(rate, 0.42 + r.randf_range(0.0, 0.08)), 0.9)
	return out


## Two or three gull calls, each a gliding nasal cry with breath. far = heard
## across the shore: duller and wetter, which is how the bed scatters them.
static func gull(rate: int, v: int, far: bool) -> PackedFloat32Array:
	var r := Rng.make(7601 if far else 5501, v)
	var total := Synth.samples(rate, 1.6)
	var out := Synth.buffer(total)
	var t := 0.0
	for k in r.randi_range(2, 3):
		var secs := r.randf_range(0.28, 0.42)
		var f0 := r.randf_range(820.0, 980.0)
		var peak_f := f0 * r.randf_range(1.35, 1.6)
		var src := _voice(rate, secs, func(u: float) -> float:
			return lerpf(f0, peak_f, sin(PI * pow(u, 0.5))) * (1.0 + 0.012 * sin(TAU * 23.0 * u * secs)), 7602 + v * 7 + k, 0.18, 0.01, 0.06)
		var cry := _formed(src, rate, [1450.0, 2800.0, 3900.0], [4.0, 5.0, 6.0], [1.0, 0.6, 0.25])
		for i in cry.size():
			var u := float(i) / cry.size()
			cry[i] *= pow(sin(PI * pow(u, 0.35)), 1.2)
		Synth.add(out, cry, Synth.samples(rate, t))
		t += secs + r.randf_range(0.08, 0.2)
	Synth.normalize(out, 1.0)
	if far:
		Synth.lowpass(out, rate, 3800.0)
		return Synth.reverb(out, rate, 0.7, 0.5, 0.35, 1.2)
	return Synth.reverb(out, rate, 0.5, 0.5, 0.12, 0.4)


## A small bird somewhere off in the stand, at first light: a phrase of three
## to seven quick notes, each a whistle that glides and sometimes trills, the
## phrase's shape different every take. Far and a little wet.
static func bird(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(5801, v)
	var out := Synth.buffer(Synth.samples(rate, 1.6))
	var t := 0.0
	var home := r.randf_range(2600.0, 4200.0)
	var notes := r.randi_range(5, 10)
	var trill := r.randf() < 0.5
	for k in notes:
		var secs := r.randf_range(0.018, 0.06)
		var n := Synth.samples(rate, secs)
		var b := Synth.buffer(n)
		var f0 := home * r.randf_range(0.8, 1.25)
		var f1 := f0 * r.randf_range(0.7, 1.45)
		var ph := 0.0
		for i in n:
			var u := float(i) / n
			var f := f0 * pow(f1 / f0, u)
			if trill and k == notes - 1:
				f *= 1.0 + 0.08 * sin(TAU * 38.0 * u * secs)
			ph += TAU * minf(f, rate * 0.45) / rate
			b[i] = sin(ph) * sin(PI * u)
		Synth.add(out, b, Synth.samples(rate, t), r.randf_range(0.5, 1.0))
		t += secs + r.randf_range(0.012, 0.05) + (0.12 if k == notes / 2 and notes > 6 else 0.0)
		if t > 1.3:
			break
	Synth.lowpass(out, rate, 6500.0)
	return Synth.reverb(out, rate, 0.4, 0.7, 0.1, 0.3)


## A gull down on your bag: the canvas, wingbeats beating off, one call.
static func _snatch_gull(rate: int, v: int) -> PackedFloat32Array:
	var r := Rng.make(5601, v)
	var out := Synth.buffer(Synth.samples(rate, 1.6))
	var rustle := Synth.buffer(Synth.samples(rate, 0.25))
	Synth.add_impulses(rustle, rate, 500.0, 5602 + v, 0.05, 1.0)
	Synth.band(rustle, rate, 1000.0, 6000.0, false, false)
	Synth.env_perc(rustle, rate, 0.02, 0.22)
	Synth.normalize(rustle, 1.0)
	Synth.add(out, rustle, 0, 0.5)
	var t := 0.12
	for k in 7:
		var flap := Synth.noise(Synth.samples(rate, 0.09), 5610 + v * 11 + k)
		Synth.band(flap, rate, 280.0, 2600.0, false, false)
		_shape(flap, 0.3, 2.0)
		Synth.normalize(flap, 1.0)
		Synth.add(out, flap, Synth.samples(rate, t), 0.75 * pow(0.86, k))
		t += r.randf_range(0.085, 0.11)
	var cry := gull(rate, v + 20, false)
	Synth.add(out, cry.slice(0, mini(cry.size(), Synth.samples(rate, 0.5))), Synth.samples(rate, 0.5), 0.35)
	return out


## Something alive goes down: the body meeting the ground, a breath let out.
static func _beast_down(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(Synth.samples(rate, 1.1))
	var thud := Synth.noise(Synth.samples(rate, 0.3), 5701)
	Synth.band(thud, rate, 140.0, 700.0, false, false)
	Synth.env_perc(thud, rate, 0.004, 0.22)
	Synth.normalize(thud, 1.0)
	Synth.add(out, thud, 0, 0.9)
	Synth.add(out, Synth.modes(rate, 0.3, PackedFloat32Array([185.0, 430.0]), PackedFloat32Array([0.5, 0.25]), PackedFloat32Array([0.12, 0.08]), 0.004), 0, 0.6)
	var grit := Synth.buffer(Synth.samples(rate, 0.3))
	Synth.add_impulses(grit, rate, 700.0, 5702, 0.05, 1.0)
	Synth.band(grit, rate, 1500.0, 6000.0, false, false)
	Synth.env_perc(grit, rate, 0.005, 0.25)
	Synth.normalize(grit, 1.0)
	Synth.add(out, grit, Synth.samples(rate, 0.02), 0.25)
	var exhale := Synth.noise(Synth.samples(rate, 0.6), 5703)
	var breath := _formed(exhale, rate, [650.0, 1300.0], [2.0, 3.0], [1.0, 0.4])
	for i in breath.size():
		var u := float(i) / breath.size()
		breath[i] *= sin(PI * pow(u, 0.4)) * (1.0 - u)
	Synth.add(out, breath, Synth.samples(rate, 0.35), 0.35)
	return out
