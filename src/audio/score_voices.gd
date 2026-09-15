class_name ScoreVoices
## The score's instruments, all streamed (ScoreVoice): every one keeps its own
## phases and filter states between blocks.
##
##   Analog detuned saws or pulses in unison, a sub sine, a resonant low-pass with
##          its own envelope and a slow sweep: pads, drones, plucks, pulses, brass
##   Fm     a carrier and two modulators with decaying indices: bells, glass, growl
##   Hiss   filtered noise or sparse impulses under a swell: air, breath, rain, ash
##   Ping   decaying resonant modes: drips, ice, stone, glass rain
##   Sine   sine partials with slow tremolo: hum, ghost tones, shimmer
##
## Inner loops keep their state in locals and write straight into the block:
## GDScript pays for every member read, and a stem is a million samples.

const CHUNK := ScoreVoice.CHUNK


## Samples a note of this instrument sounds for (a ping rings for its longest mode).
static func frames_of(kind: GDScript, p: Dictionary, sample_rate: int) -> int:
	if kind == Ping and not p.has("frames"):
		var longest := 0.02
		for md: Array in p.get("modes", [[1.0, 1.0, 0.6]]):
			longest = maxf(longest, float(md[2]))
		return roundi(longest * sample_rate)
	return ScoreVoice.length_of(p, sample_rate)


## Common params: a d s hold r (seconds), shape (0 ADSR, 1 swell, 2 flat),
## gain, width (0 centre .. 1 wide), seed, held.
class Analog:
	extends ScoreVoice
	var _inc := PackedFloat64Array()
	var _ph := PackedFloat64Array()
	var _side := PackedByteArray()
	var _norm := 1.0
	var _wave := 0
	var _pw := 0.5
	var _pwm := 0.0
	var _pwm_w := 0.0
	var _sub := 0.0
	var _sub_inc := 0.0
	var _sub_ph := 0.0
	var _cut := 1200.0
	var _cut_env := 0.0
	var _fdecay := 0.3
	var _q := 0.707
	var _sweep := 0.0
	var _sweep_w := 0.0
	var _sweep_ph := 0.0
	var _vib := 0.0
	var _vib_w := 0.0
	var _gain := 1.0
	var _width := 0.6
	var _drive := 0.0
	var _ta := PackedFloat32Array()
	var _tb := PackedFloat32Array()
	var _z1a := 0.0
	var _z2a := 0.0
	var _z1b := 0.0
	var _z2b := 0.0

	## freqs (Hz), unison, detune (cents between the outermost), wave (0 saw,
	## 1 pulse, 2 sine), pw, pwm, pwm_hz, sub (level of a sine an octave under
	## the first note), cut (Hz), cut_env (octaves at the start, decaying over
	## fdecay s), q, sweep (octaves), sweep_hz, vib (cents), vib_hz, drive.
	func _init_voice(p: Dictionary) -> void:
		var freqs: Array = p.get("freqs", [220.0])
		var unison := maxi(1, int(p.get("unison", 1)))
		var spread := float(p.get("detune", 0.0))
		var seed_value := int(p.get("seed", 1))
		_wave = int(p.get("wave", 0))
		_pw = clampf(float(p.get("pw", 0.5)), 0.05, 0.95)
		_pwm = float(p.get("pwm", 0.0))
		_pwm_w = TAU * snap(float(p.get("pwm_hz", 0.3)), p)
		_cut = float(p.get("cut", 1200.0))
		_cut_env = float(p.get("cut_env", 0.0))
		_fdecay = maxf(0.005, float(p.get("fdecay", 0.3)))
		_q = float(p.get("q", 0.707))
		_sweep = float(p.get("sweep", 0.0))
		_sweep_w = TAU * snap(float(p.get("sweep_hz", 0.05)), p)
		_sweep_ph = TAU * Rng.hash01(seed_value, 0x5e)
		_vib = float(p.get("vib", 0.0)) / 1731.2
		_vib_w = TAU * float(p.get("vib_hz", 5.0))
		_gain = float(p.get("gain", 1.0))
		_width = clampf(float(p.get("width", 0.6)), 0.0, 1.0) if stereo else 0.0
		_drive = float(p.get("drive", 0.0))
		for fi in freqs.size():
			for u in unison:
				# Spread evenly, then nudged per voice, so the beating between them never
				# settles into one regular throb.
				var cents := 0.0 if unison == 1 else spread * (float(u) / (unison - 1) - 0.5 + (Rng.hash01(seed_value, fi, u, 0xde) - 0.5) * 0.3)
				var f := snap(float(freqs[fi]) * pow(2.0, cents / 1200.0), p)
				_inc.append(f / rate)
				var ph0 := Rng.hash01(seed_value, fi, u)
				if held:
					ph0 = fposmod(ph0 + f * float(start) / rate, 1.0)
				_ph.append(ph0)
				_side.append((fi + u) % 2 if stereo else 0)
		_norm = 1.0 / sqrt(float(_inc.size()))
		if _inc.size() == 1:
			_width = 0.0
		_sub = float(p.get("sub", 0.0))
		if _sub > 0.0 and not freqs.is_empty():
			var fs := snap(float(freqs[0]) * 0.5, p)
			_sub_inc = fs / rate
			_sub_ph = fposmod(fs * float(start) / rate, 1.0) if held else 0.0

	func render(l: PackedFloat32Array, rb: PackedFloat32Array, at: int, count: int) -> void:
		if _ta.size() < count:
			_ta.resize(count)
			_tb.resize(count)
		_ta.fill(0.0)
		_tb.fill(0.0)
		for o in _inc.size():
			var t := _ph[o]
			var dt := _inc[o]
			var buf := _ta if _side[o] == 0 else _tb
			var j := 0
			while j < count:
				var m := count - j
				var d := dt
				if _vib > 0.0:
					m = mini(CHUNK, m)
					var tv := float(pos + j) / rate
					d = dt * (1.0 + _vib * sin(_vib_w * tv) * minf(1.0, tv * 2.0))
				match _wave:
					0:
						var hi := 1.0 - d
						for i in range(j, j + m):
							var v := t + t - 1.0
							if t < d:
								var x := t / d
								v -= x + x - x * x - 1.0
							elif t > hi:
								var x := (t - 1.0) / d
								v -= x * x + x + x + 1.0
							buf[i] += v
							t += d
							if t >= 1.0:
								t -= 1.0
					1:
						if _pwm > 0.0:
							m = mini(CHUNK, m)
						var pw := clampf(_pw + _pwm * sin(_pwm_w * clock(pos + j)), 0.06, 0.94)
						var t2 := fposmod(t + pw, 1.0)
						var hi := 1.0 - d
						for i in range(j, j + m):
							var v := 2.0 * (t - t2)
							if t < d:
								var x := t / d
								v -= x + x - x * x - 1.0
							elif t > hi:
								var x := (t - 1.0) / d
								v -= x * x + x + x + 1.0
							if t2 < d:
								var x := t2 / d
								v += x + x - x * x - 1.0
							elif t2 > hi:
								var x := (t2 - 1.0) / d
								v += x * x + x + x + 1.0
							buf[i] += v
							t += d
							if t >= 1.0:
								t -= 1.0
							t2 += d
							if t2 >= 1.0:
								t2 -= 1.0
					_:
						var w := TAU * d
						var ph := t * TAU
						for i in range(j, j + m):
							buf[i] += sin(ph)
							ph += w
						t = fposmod(ph / TAU, 1.0)
				j += m
			_ph[o] = t
		if _sub > 0.0:
			var ph := _sub_ph * TAU
			var w := TAU * _sub_inc
			var a := _sub / _norm
			for i in count:
				var v := sin(ph) * a
				_ta[i] += v
				if stereo:
					_tb[i] += v
				ph += w
			_sub_ph = fposmod(ph / TAU, 1.0)
		if _drive > 0.0:
			# Soft saturation on the normalised sum, scaled back so the envelope's
			# gain stays what it was: thickens a growl without changing its level much.
			var dr := _drive
			var nm := _norm
			for i in count:
				var x := _ta[i] * nm
				_ta[i] = x * (1.0 + dr) / (1.0 + dr * absf(x)) / nm
				if stereo:
					x = _tb[i] * nm
					_tb[i] = x * (1.0 + dr) / (1.0 + dr * absf(x)) / nm
		_filter_out(l, rb, at, count)

	func _filter_out(l: PackedFloat32Array, rb: PackedFloat32Array, at: int, count: int) -> void:
		var z1a := _z1a
		var z2a := _z2a
		var z1b := _z1b
		var z2b := _z2b
		var ta := _ta
		var tb := _tb
		var ga := 0.5 + 0.5 * _width
		var gb := 0.5 - 0.5 * _width
		var j := 0
		var nyq := rate * 0.45
		var kq := 1.0 / maxf(0.3, _q)
		while j < count:
			var m := mini(CHUNK, count - j)
			var k0 := pos + j
			var e := env_at(k0) * _norm * _gain
			var de := (env_at(k0 + m) * _norm * _gain - e) / m
			var oct := 0.0
			if _cut_env != 0.0:
				oct += _cut_env * exp(-float(k0) / (_fdecay * rate))
			if _sweep != 0.0:
				oct += _sweep * sin(_sweep_w * clock(k0 + (m >> 1)) + _sweep_ph)
			var g := tan(PI * clampf(_cut * pow(2.0, oct), 10.0, nyq) / rate)
			var a1 := 1.0 / (1.0 + g * (g + kq))
			var a2 := g * a1
			var a3 := g * a2
			if stereo and _inc.size() > 1:
				for i in range(j, j + m):
					var v3 := ta[i] - z2a
					var v1 := a1 * z1a + a2 * v3
					var v2 := z2a + a2 * z1a + a3 * v3
					z1a = v1 + v1 - z1a
					z2a = v2 + v2 - z2a
					var ya := v2 * e
					v3 = tb[i] - z2b
					v1 = a1 * z1b + a2 * v3
					v2 = z2b + a2 * z1b + a3 * v3
					z1b = v1 + v1 - z1b
					z2b = v2 + v2 - z2b
					var yb := v2 * e
					l[at + i] += ya * ga + yb * gb
					rb[at + i] += ya * gb + yb * ga
					e += de
			elif stereo:
				# One oscillator: one filter, the same in both ears.
				for i in range(j, j + m):
					var v3 := ta[i] - z2a
					var v1 := a1 * z1a + a2 * v3
					var v2 := z2a + a2 * z1a + a3 * v3
					z1a = v1 + v1 - z1a
					z2a = v2 + v2 - z2a
					var y := v2 * e * 0.7071
					l[at + i] += y
					rb[at + i] += y
					e += de
			else:
				for i in range(j, j + m):
					var v3 := ta[i] - z2a
					var v1 := a1 * z1a + a2 * v3
					var v2 := z2a + a2 * z1a + a3 * v3
					z1a = v1 + v1 - z1a
					z2a = v2 + v2 - z2a
					l[at + i] += v2 * e
					e += de
			j += m
		_z1a = z1a
		_z2a = z2a
		_z1b = z1b
		_z2b = z2b
		pos += count


## freq, ratio, index, idecay (s to -60 dB of the index), floor (index that
## remains), ratio2, index2, i2decay, detune (cents on the right carrier),
## vib (cents), vib_hz, plus the envelope.
class Fm:
	extends ScoreVoice
	var _wc := 0.0
	var _wc2 := 0.0
	var _wm := 0.0
	var _wm2 := 0.0
	var _pc := 0.0
	var _pc2 := 0.0
	var _pm := 0.0
	var _pm2 := 0.0
	var _index := 1.0
	var _idecay := 1.0
	var _floor := 0.0
	var _index2 := 0.0
	var _i2decay := 0.5
	var _gain := 1.0
	var _pan := 0.0
	var _vib := 0.0
	var _vib_w := 0.0

	func _init_voice(p: Dictionary) -> void:
		var f := float(p.get("freq", 440.0))
		var detune := float(p.get("detune", 0.0))
		_wc = TAU * f / rate
		_wc2 = TAU * f * pow(2.0, detune / 1200.0) / rate
		_wm = TAU * f * float(p.get("ratio", 1.0)) / rate
		_wm2 = TAU * f * float(p.get("ratio2", 0.0)) / rate
		_index = float(p.get("index", 1.0))
		_idecay = maxf(0.01, float(p.get("idecay", 1.0)))
		_floor = float(p.get("floor", 0.0))
		_index2 = float(p.get("index2", 0.0))
		_i2decay = maxf(0.01, float(p.get("i2decay", 0.3)))
		_gain = float(p.get("gain", 1.0))
		_pan = clampf(float(p.get("pan", 0.0)), -1.0, 1.0)
		_vib = float(p.get("vib", 0.0)) / 1731.2
		_vib_w = TAU * float(p.get("vib_hz", 5.0))
		var seed_value := int(p.get("seed", 1))
		_pm = TAU * Rng.hash01(seed_value, 0xf1)

	func _indices(k: int) -> Vector2:
		var t := float(k) / rate
		return Vector2(_index * exp(-LN_1000 * t / _idecay) + _floor, _index2 * exp(-LN_1000 * t / _i2decay))

	func render(l: PackedFloat32Array, rb: PackedFloat32Array, at: int, count: int) -> void:
		var pc := _pc
		var pc2 := _pc2
		var pm := _pm
		var pm2 := _pm2
		var gl := sqrt(0.5 * (1.0 - _pan))
		var gr := sqrt(0.5 * (1.0 + _pan))
		var j := 0
		while j < count:
			var m := mini(CHUNK, count - j)
			var k0 := pos + j
			var e := env_at(k0) * _gain
			var de := (env_at(k0 + m) * _gain - e) / m
			var ix := _indices(k0)
			var ix1 := _indices(k0 + m)
			var i1 := ix.x
			var di1 := (ix1.x - i1) / m
			var i2 := ix.y
			var di2 := (ix1.y - i2) / m
			var vib := 1.0
			if _vib > 0.0:
				var tv := float(k0) / rate
				vib = 1.0 + _vib * sin(_vib_w * tv) * minf(1.0, tv)
			var wc := _wc * vib
			var wc2 := _wc2 * vib
			var wm := _wm * vib
			var wm2 := _wm2 * vib
			if stereo:
				for i in range(j, j + m):
					var md := i1 * sin(pm)
					if i2 > 1e-5:
						md += i2 * sin(pm2)
					l[at + i] += sin(pc + md) * e * gl
					rb[at + i] += sin(pc2 + md) * e * gr
					pc += wc
					pc2 += wc2
					pm += wm
					pm2 += wm2
					i1 += di1
					i2 += di2
					e += de
			else:
				for i in range(j, j + m):
					var md := i1 * sin(pm)
					if i2 > 1e-5:
						md += i2 * sin(pm2)
					l[at + i] += sin(pc + md) * e
					pc += wc
					pm += wm
					pm2 += wm2
					i1 += di1
					i2 += di2
					e += de
			j += m
		_pc = fmod(pc, TAU)
		_pc2 = fmod(pc2, TAU)
		_pm = fmod(pm, TAU)
		_pm2 = fmod(pm2, TAU)
		pos += count


## seed, cut (Hz), q, mode (0 low-pass, 1 band-pass at 0 dB peak, 2 high-pass),
## sweep (octaves), sweep_hz, density (impulses a second; 0 = continuous noise),
## width (0 one noise in both ears .. 1 a separate noise each side), plus the envelope.
class Hiss:
	extends ScoreVoice
	var _xl := 1
	var _xr := 2
	var _cut := 1000.0
	var _q := 0.707
	var _mode := 1
	var _sweep := 0.0
	var _sweep_w := 0.0
	var _sweep_ph := 0.0
	var _density := 0.0
	var _gain := 1.0
	var _width := 1.0
	var _z1l := 0.0
	var _z2l := 0.0
	var _z1r := 0.0
	var _z2r := 0.0

	func _init_voice(p: Dictionary) -> void:
		var seed_value := int(p.get("seed", 1))
		_xl = Rng.hash_ints(seed_value, 0x4e1) | 1
		_xr = Rng.hash_ints(seed_value, 0x4e2) | 1
		_cut = float(p.get("cut", 1000.0))
		_q = float(p.get("q", 0.707))
		_mode = int(p.get("mode", 1))
		_sweep = float(p.get("sweep", 0.0))
		_sweep_w = TAU * float(p.get("sweep_hz", 0.1))
		_sweep_ph = TAU * Rng.hash01(seed_value, 0x5f)
		_density = float(p.get("density", 0.0))
		_gain = float(p.get("gain", 1.0))
		_width = clampf(float(p.get("width", 1.0)), 0.0, 1.0) if stereo else 0.0

	func render(l: PackedFloat32Array, rb: PackedFloat32Array, at: int, count: int) -> void:
		var xl := _xl
		var xr := _xr
		var z1l := _z1l
		var z2l := _z2l
		var z1r := _z1r
		var z2r := _z2r
		var kq := 1.0 / maxf(0.3, _q)
		var chance := int(_density / rate * 65536.0)
		var sparse := _density > 0.0
		var mode := _mode
		var mix := _width
		var j := 0
		while j < count:
			var m := mini(CHUNK, count - j)
			var k0 := pos + j
			var e := env_at(k0) * _gain
			var de := (env_at(k0 + m) * _gain - e) / m
			var oct := 0.0
			if _sweep != 0.0:
				oct = _sweep * sin(_sweep_w * clock(k0 + (m >> 1)) + _sweep_ph)
			var g := tan(PI * clampf(_cut * pow(2.0, oct), 10.0, rate * 0.45) / rate)
			var a1 := 1.0 / (1.0 + g * (g + kq))
			var a2 := g * a1
			var a3 := g * a2
			for i in range(j, j + m):
				xl = (xl * 1664525 + 1013904223) & 0xFFFFFFFF
				var n := float(xl) / 2147483648.0 - 1.0
				if sparse:
					# The gate reads the high bits (an LCG's low bits repeat every
					# 2^16 samples); a gated sample draws its own amplitude.
					if (xl >> 16) < chance:
						xl = (xl * 1664525 + 1013904223) & 0xFFFFFFFF
						n = (float(xl) / 2147483648.0 - 1.0) * 1.6
					else:
						n = 0.0
				var v3 := n - z2l
				var v1 := a1 * z1l + a2 * v3
				var v2 := z2l + a2 * z1l + a3 * v3
				z1l = v1 + v1 - z1l
				z2l = v2 + v2 - z2l
				var y := v2
				if mode == 1:
					y = v1 * kq
				elif mode == 2:
					y = n - kq * v1 - v2
				if stereo:
					var yr := y
					if mix > 0.0:
						xr = (xr * 1664525 + 1013904223) & 0xFFFFFFFF
						var nr := float(xr) / 2147483648.0 - 1.0
						if sparse:
							if (xr >> 16) < chance:
								xr = (xr * 1664525 + 1013904223) & 0xFFFFFFFF
								nr = (float(xr) / 2147483648.0 - 1.0) * 1.6
							else:
								nr = 0.0
						v3 = nr - z2r
						v1 = a1 * z1r + a2 * v3
						v2 = z2r + a2 * z1r + a3 * v3
						z1r = v1 + v1 - z1r
						z2r = v2 + v2 - z2r
						var o := v2
						if mode == 1:
							o = v1 * kq
						elif mode == 2:
							o = nr - kq * v1 - v2
						yr = y + (o - y) * mix
					l[at + i] += y * e
					rb[at + i] += yr * e
				else:
					l[at + i] += y * e
				e += de
			j += m
		_xl = xl
		_xr = xr
		_z1l = z1l
		_z2l = z2l
		_z1r = z1r
		_z2r = z2r
		pos += count


## freq, modes ([[ratio, amp, t60 s], ...]), a (attack s), pan, gain. Each mode
## is a two-pole resonator started ringing, so a ping costs a few multiplies a
## sample and nothing once it has died.
class Ping:
	extends ScoreVoice
	var _b1 := PackedFloat64Array()
	var _b2 := PackedFloat64Array()
	var _s1 := PackedFloat64Array()
	var _s2 := PackedFloat64Array()
	var _na := 1
	var _gain := 1.0
	var _pan := 0.0

	func _init_voice(p: Dictionary) -> void:
		var f := float(p.get("freq", 880.0))
		var modes: Array = p.get("modes", [[1.0, 1.0, 0.6]])
		var longest := 0.02
		for md: Array in modes:
			var w := TAU * f * float(md[0]) / rate
			if w >= PI * 0.9:
				continue
			var t60 := maxf(0.005, float(md[2]))
			var rr := exp(-LN_1000 / (t60 * rate))
			_b1.append(2.0 * rr * cos(w))
			_b2.append(-rr * rr)
			_s1.append(float(md[1]) * sin(w))
			_s2.append(0.0)
			longest = maxf(longest, t60)
		_na = maxi(1, roundi(float(p.get("a", 0.002)) * rate))
		_gain = float(p.get("gain", 1.0))
		_pan = clampf(float(p.get("pan", 0.0)), -1.0, 1.0)
		length = roundi(longest * rate)

	func render(l: PackedFloat32Array, rb: PackedFloat32Array, at: int, count: int) -> void:
		var gl := sqrt(0.5 * (1.0 - _pan)) * _gain
		var gr := sqrt(0.5 * (1.0 + _pan)) * _gain
		for k in _b1.size():
			var b1 := _b1[k]
			var b2 := _b2[k]
			var s1 := _s1[k]
			var s2 := _s2[k]
			var na := _na
			var p0 := pos
			for i in count:
				var y := s1
				var nx := b1 * s1 + b2 * s2
				s2 = s1
				s1 = nx
				if p0 + i < na:
					y *= float(p0 + i) / na
				l[at + i] += y * gl
				if stereo:
					rb[at + i] += y * gr
			_s1[k] = s1
			_s2[k] = s2
		pos += count


## freqs, amps, am_hz (tremolo; the builder snaps it for held voices), am_depth,
## width (partials alternate left and right), plus the envelope.
class Sine:
	extends ScoreVoice
	var _w := PackedFloat64Array()
	var _ph := PackedFloat64Array()
	var _amp := PackedFloat64Array()
	var _am_w := 0.0
	var _am_depth := 0.0
	var _gain := 1.0
	var _width := 0.5

	func _init_voice(p: Dictionary) -> void:
		var freqs: Array = p.get("freqs", [220.0])
		var amps: Array = p.get("amps", [])
		var seed_value := int(p.get("seed", 1))
		for k in freqs.size():
			var f := snap(float(freqs[k]), p)
			if f >= rate * 0.45:
				continue
			_w.append(TAU * f / rate)
			var ph0 := Rng.hash01(seed_value, k, 0x51)
			if held:
				ph0 = fposmod(ph0 + f * float(start) / rate, 1.0)
			_ph.append(ph0 * TAU)
			_amp.append(float(amps[k]) if k < amps.size() else 1.0 / (k + 1))
		_am_w = TAU * snap(float(p.get("am_hz", 0.0)), p)
		_am_depth = clampf(float(p.get("am_depth", 0.0)), 0.0, 1.0)
		_gain = float(p.get("gain", 1.0))
		_width = clampf(float(p.get("width", 0.5)), 0.0, 1.0) if stereo else 0.0

	func render(l: PackedFloat32Array, rb: PackedFloat32Array, at: int, count: int) -> void:
		for k in _w.size():
			var w := _w[k]
			var ph := _ph[k]
			var side := k % 2
			var gl := 0.5 + (0.5 if side == 0 else -0.5) * _width
			var gr := 1.0 - gl
			var j := 0
			while j < count:
				var m := mini(CHUNK, count - j)
				var k0 := pos + j
				var trem := 1.0
				var trem1 := 1.0
				if _am_depth > 0.0:
					var off := float(k) * 2.1
					trem = 1.0 - _am_depth * (0.5 - 0.5 * cos(_am_w * clock(k0) + off))
					trem1 = 1.0 - _am_depth * (0.5 - 0.5 * cos(_am_w * clock(k0 + m) + off))
				var e := env_at(k0) * _gain * _amp[k] * trem
				var de := (env_at(k0 + m) * _gain * _amp[k] * trem1 - e) / m
				if stereo:
					for i in range(j, j + m):
						var v := sin(ph) * e
						l[at + i] += v * gl
						rb[at + i] += v * gr
						ph += w
						e += de
				else:
					for i in range(j, j + m):
						l[at + i] += sin(ph) * e
						ph += w
						e += de
				j += m
			_ph[k] = fmod(ph, TAU)
		pos += count
