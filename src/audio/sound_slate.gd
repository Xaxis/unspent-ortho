class_name SoundSlate
## The slate's own voice (slate package): a salvaged machine display in a
## patched case. Every sound is synthetic and a little broken: square blips
## through a cheap speaker, samples held too long (a crushed rate), a tick that
## sometimes doubles, a whine when its power runs low.
##
##   ui_slate_click    moving down a list
##   ui_slate_confirm  doing the chosen row (up a fifth)
##   ui_slate_back     one level back (down a fourth)
##   ui_slate_deny     not now: a double buzz, never louder than a confirm
##   ui_slate_wake     the glass waking: a chirp up out of static
##   ui_slate_sleep    the glass going dark: a chirp down and a click
##   ui_slate_switch   one app to the next
##   ui_slate_whine    power running low
##   ui_slate_ping     the location ping when a landscape is crossed into

const NAMES: Array[StringName] = [
	&"ui_slate_click", &"ui_slate_confirm", &"ui_slate_back", &"ui_slate_deny", &"ui_slate_wake",
	&"ui_slate_sleep", &"ui_slate_switch", &"ui_slate_whine", &"ui_slate_ping",
]


static func handles(name: StringName) -> bool:
	return name in NAMES


static func make(name: StringName, _variant: int, rate: int) -> PackedFloat32Array:
	match name:
		&"ui_slate_click": return _click(rate)
		&"ui_slate_confirm": return _blips(rate, [880.0, 1318.5], 0.034, 9101)
		&"ui_slate_back": return _blips(rate, [1174.7, 880.0], 0.03, 9102)
		&"ui_slate_deny": return _deny(rate)
		&"ui_slate_wake": return _wake(rate)
		&"ui_slate_sleep": return _sleep(rate)
		&"ui_slate_switch": return _switch(rate)
		&"ui_slate_whine": return _whine(rate)
		&"ui_slate_ping": return _ping(rate)
	push_warning("no slate sound %s" % name)
	return Synth.buffer(64)


static func _n(rate: int, seconds: float) -> int:
	return Synth.samples(rate, seconds)


## Hold every k-th sample: the cheap converter in a salvaged module.
static func _crush(buf: PackedFloat32Array, k: int) -> void:
	var held := 0.0
	for i in buf.size():
		if i % k == 0:
			held = buf[i]
		buf[i] = held


static func _click(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_n(rate, 0.05))
	var tick := Synth.buffer(_n(rate, 0.008))
	Synth.add_pulse(tick, rate, 2400.0, 0.8, 0.3)
	Synth.env_perc(tick, rate, 0.0003, 0.006)
	_crush(tick, 5)
	Synth.add(out, tick, 0, 1.0)
	# The contact is dirty: a ghost of the tick a few milliseconds late.
	Synth.add(out, tick, _n(rate, 0.011), 0.3)
	Synth.band(out, rate, 900.0, 7000.0, false, false)
	return out


static func _blips(rate: int, freqs: Array, each: float, seed_value: int) -> PackedFloat32Array:
	var out := Synth.buffer(_n(rate, each * freqs.size() + 0.08))
	for i in freqs.size():
		var b := Synth.buffer(_n(rate, each))
		Synth.add_pulse(b, rate, float(freqs[i]), 0.6, 0.5)
		Synth.add_pulse(b, rate, float(freqs[i]) * 1.004, 0.25, 0.25)
		Synth.env_adsr(b, rate, 0.002, 0.01, 0.6, each * 0.7, each * 0.25)
		_crush(b, 3)
		Synth.add(out, b, _n(rate, each * i + 0.004 * i), 0.8)
	var crackle := Synth.buffer(out.size())
	Synth.add_impulses(crackle, rate, 60.0, seed_value, 0.05, 0.4)
	Synth.add(out, crackle, 0, 0.15)
	Synth.band(out, rate, 400.0, 6500.0, false, false)
	return out


static func _deny(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_n(rate, 0.26))
	var buzz := Synth.buffer(_n(rate, 0.07))
	Synth.add_pulse(buzz, rate, 196.0, 0.7, 0.35)
	Synth.add_pulse(buzz, rate, 207.6, 0.35, 0.5)
	Synth.env_adsr(buzz, rate, 0.003, 0.02, 0.7, 0.05, 0.015)
	_crush(buzz, 4)
	Synth.add(out, buzz, 0)
	Synth.add(out, buzz, _n(rate, 0.1))
	Synth.band(out, rate, 180.0, 3000.0, false, false)
	return out


static func _wake(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_n(rate, 0.7))
	# Static first, as the module takes power.
	var st := Synth.noise(_n(rate, 0.22), 9111)
	Synth.band(st, rate, 1500.0, 9000.0, false, false)
	Synth.env_perc(st, rate, 0.01, 0.2)
	_crush(st, 6)
	Synth.add(out, st, 0, 0.35)
	# The chirp up out of it.
	var ch := Synth.buffer(_n(rate, 0.26))
	Synth.add_chirp(ch, rate, 320.0, 2200.0, 0.7)
	Synth.env_adsr(ch, rate, 0.01, 0.05, 0.8, 0.2, 0.05)
	_crush(ch, 3)
	Synth.add(out, ch, _n(rate, 0.05), 0.8)
	# A settle: two small tones, the second a hair flat, the way it always was.
	var p := Synth.buffer(_n(rate, 0.3))
	Synth.add_sine(p, rate, 1760.0, 0.45)
	Synth.add_sine(p, rate, 1757.0, 0.25)
	Synth.env_perc(p, rate, 0.002, 0.25)
	Synth.add(out, p, _n(rate, 0.32), 0.6)
	Synth.band(out, rate, 200.0, 9000.0, false, false)
	return out


static func _sleep(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_n(rate, 0.3))
	var ch := Synth.buffer(_n(rate, 0.17))
	Synth.add_chirp(ch, rate, 1600.0, 220.0, 0.7)
	Synth.env_adsr(ch, rate, 0.004, 0.03, 0.7, 0.12, 0.04)
	_crush(ch, 4)
	Synth.add(out, ch, 0, 0.8)
	var click := Synth.buffer(_n(rate, 0.01))
	Synth.add_pulse(click, rate, 900.0, 0.8, 0.5)
	Synth.env_perc(click, rate, 0.0003, 0.008)
	Synth.add(out, click, _n(rate, 0.17), 0.7)
	Synth.band(out, rate, 200.0, 7000.0, false, false)
	return out


static func _switch(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_n(rate, 0.09))
	var sw := Synth.noise(_n(rate, 0.05), 9131)
	Synth.sweep_band(sw, rate, Synth.glide(sw.size(), 1200.0, 5200.0), 3.0)
	Synth.env_perc(sw, rate, 0.004, 0.05)
	_crush(sw, 4)
	Synth.add(out, sw, 0, 0.7)
	Synth.add(out, _click(rate), _n(rate, 0.035), 0.5)
	return out


static func _whine(rate: int) -> PackedFloat32Array:
	var n := _n(rate, 1.3)
	var out := Synth.buffer(n)
	var f := Synth.wander(n, 9, 9141, 5600.0, 6300.0)
	var phase := 0.0
	for i in n:
		phase += f[i] / rate
		out[i] = sin(phase * TAU) * 0.5
	# It flutters as the cell sags, and dies away.
	Synth.tremolo(out, rate, 11.0, 0.5)
	Synth.env_adsr(out, rate, 0.08, 0.2, 0.6, 0.9, 0.35)
	var hum := Synth.buffer(n)
	Synth.add_pulse(hum, rate, 310.0, 0.12, 0.2)
	Synth.env_adsr(hum, rate, 0.08, 0.2, 0.6, 0.9, 0.35)
	Synth.add(out, hum, 0, 0.5)
	return out


static func _ping(rate: int) -> PackedFloat32Array:
	var out := Synth.buffer(_n(rate, 1.1))
	var p := Synth.buffer(_n(rate, 0.5))
	Synth.add_sine(p, rate, 1318.5, 0.6)
	Synth.add_sine(p, rate, 1975.5, 0.18)
	Synth.env_perc(p, rate, 0.002, 0.45)
	_crush(p, 2)
	Synth.add(out, p, 0, 0.8)
	# Its return, quieter, from far off.
	Synth.add(out, p, _n(rate, 0.38), 0.28)
	Synth.add(out, p, _n(rate, 0.62), 0.1)
	return out
