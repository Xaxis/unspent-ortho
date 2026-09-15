class_name ScoreFx
## The score's effects (ScoreEffect), in the order a stem usually chains them:
##
##   Tape   a wandering delay: wow and flutter (mix 0) or a wide ensemble (mix 0.5)
##   Echo   the dub delay: repeats that grow darker and thinner, crossing sides
##   Hall   a long feedback-delay-network reverb, four lines, damped
##   Tone   a state-variable low- or high-pass, optionally sweeping
##
## All of them stream: a stem can stop between two blocks and resume. Every
## statement in a per-sample loop costs a GDScript VM dispatch, so the loops are
## written for the fewest: LFOs move per chunk, ring buffers are powers of two.

const CHUNK := 32


static func pow2_at_least(n: int) -> int:
	var s := 16
	while s < n:
		s <<= 1
	return s


## delay_ms (centre), depth_ms (wow), hz, flutter_ms, flutter_hz, mix (0 only
## the wobbled copy is heard .. 1 dry and wobbled equal), spread (0..1 of a
## cycle between the ears).
class Tape:
	extends ScoreEffect
	var _bl := PackedFloat32Array()
	var _br := PackedFloat32Array()
	var _mask := 15
	var _w := 0
	var _base := 0.0
	var _depth := 0.0
	var _flut := 0.0
	var _w1 := 0.0
	var _w2 := 0.0
	var _spread := 0.0
	var _dry := 0.0
	var _wet := 1.0

	func _init_fx(p: Dictionary) -> void:
		_base = float(p.get("delay_ms", 12.0)) * rate / 1000.0
		_depth = float(p.get("depth_ms", 1.5)) * rate / 1000.0
		_flut = float(p.get("flutter_ms", 0.12)) * rate / 1000.0
		_w1 = TAU * snap_hz(float(p.get("hz", 0.3))) / rate
		_w2 = TAU * snap_hz(float(p.get("flutter_hz", 5.3))) / rate
		_spread = TAU * float(p.get("spread", 0.25))
		var mix := clampf(float(p.get("mix", 0.0)), 0.0, 1.0)
		_dry = mix * 0.7071
		_wet = 1.0 - mix * (1.0 - 0.7071)
		var size := ScoreFx.pow2_at_least(ceili(_base + _depth + _flut) + 4)
		_mask = size - 1
		_bl.resize(size)
		_bl.fill(0.0)
		_br.resize(size)
		_br.fill(0.0)

	func _delay_at(t: float, ph: float) -> float:
		return _base + _depth * sin(_w1 * t + ph) + _flut * sin(_w2 * t + ph * 1.7)

	func process(l: PackedFloat32Array, r: PackedFloat32Array, n: int, t0: int) -> void:
		var bl := _bl
		var br := _br
		var mask := _mask
		var w := _w
		var dry := _dry
		var wet := _wet
		var two := stereo
		var j := 0
		while j < n:
			var m := mini(CHUNK, n - j)
			var dl := _delay_at(float(t0 + j), 0.0)
			var ddl := (_delay_at(float(t0 + j + m), 0.0) - dl) / m
			var dr := _delay_at(float(t0 + j), _spread)
			var ddr := (_delay_at(float(t0 + j + m), _spread) - dr) / m
			for i in range(j, j + m):
				var x := l[i]
				bl[w & mask] = x
				var rp := float(w) - dl
				var k := floori(rp)
				var f := rp - k
				var a := bl[k & mask]
				l[i] = x * dry + (a + (bl[(k + 1) & mask] - a) * f) * wet
				dl += ddl
				if two:
					x = r[i]
					br[w & mask] = x
					rp = float(w) - dr
					k = floori(rp)
					f = rp - k
					a = br[k & mask]
					r[i] = x * dry + (a + (br[(k + 1) & mask] - a) * f) * wet
					dr += ddr
				w += 1
			j += m
		_w = w


## time (s), fb, damp_hz (low-pass in the loop), low_hz (high-pass in the
## loop), wet, ping (repeats cross sides).
class Echo:
	extends ScoreEffect
	var _dl := PackedFloat32Array()
	var _dr := PackedFloat32Array()
	var _size := 1
	var _i := 0
	var _fb := 0.4
	var _cl := 0.5
	var _ch := 0.99
	var _wet := 0.3
	var _ping := true
	var _lpl := 0.0
	var _lpr := 0.0
	var _hpl := 0.0
	var _hpr := 0.0
	var _time := 0.5

	func _init_fx(p: Dictionary) -> void:
		_time = maxf(0.01, float(p.get("time", 0.5)))
		_size = maxi(1, roundi(_time * rate))
		_dl.resize(_size)
		_dl.fill(0.0)
		_dr.resize(_size)
		_dr.fill(0.0)
		_fb = clampf(float(p.get("fb", 0.45)), 0.0, 0.92)
		_cl = 1.0 - exp(-TAU * float(p.get("damp_hz", 2400.0)) / rate)
		_ch = 1.0 - exp(-TAU * float(p.get("low_hz", 180.0)) / rate)
		_wet = float(p.get("wet", 0.35))
		_ping = bool(p.get("ping", true)) and stereo

	## Until the repeats are 60 dB down.
	func memory() -> float:
		return _time * 6.907755279 / maxf(0.01, -log(maxf(0.001, _fb))) + _time

	func process(l: PackedFloat32Array, r: PackedFloat32Array, n: int, _t0: int) -> void:
		var dl := _dl
		var dr := _dr
		var size := _size
		var idx := _i
		var fb := _fb
		var cl := _cl
		var ch := _ch
		var wet := _wet
		var lpl := _lpl
		var lpr := _lpr
		var hpl := _hpl
		var hpr := _hpr
		if not stereo:
			for i in n:
				var yl := dl[idx]
				lpl += (yl - lpl) * cl
				hpl += (lpl - hpl) * ch
				var fl := (lpl - hpl) * fb
				dl[idx] = l[i] + fl / (1.0 + absf(fl) * 0.3)
				l[i] += yl * wet
				idx += 1
				if idx >= size:
					idx = 0
		else:
			var ping := _ping
			for i in n:
				var yl := dl[idx]
				var yr := dr[idx]
				lpl += (yl - lpl) * cl
				hpl += (lpl - hpl) * ch
				lpr += (yr - lpr) * cl
				hpr += (lpr - hpr) * ch
				var fl := (lpl - hpl) * fb
				var fr := (lpr - hpr) * fb
				fl = fl / (1.0 + absf(fl) * 0.3)
				fr = fr / (1.0 + absf(fr) * 0.3)
				if ping:
					dl[idx] = (l[i] + r[i]) * 0.5 + fr
					dr[idx] = fl
				else:
					dl[idx] = l[i] + fl
					dr[idx] = r[i] + fr
				l[i] += yl * wet
				r[i] += yr * wet
				idx += 1
				if idx >= size:
					idx = 0
		_i = idx
		_lpl = lpl
		_lpr = lpr
		_hpl = hpl
		_hpr = hpr


## t60 (s), size (scales the lines), damp_hz, wet, dry. Four delay lines mixed
## by a Householder reflection (energy kept, so the decay is set by the line
## gains alone), each damped by a one-pole low-pass, fed from the middle of the
## stem through two allpass diffusers so a pluck does not flutter; the two sides
## are read from different lines, which is where the width comes from.
class Hall:
	extends ScoreEffect
	const LINES := [1433, 1777, 2087, 2383]
	const DIFFUSE := [347, 131]
	var _l0 := PackedFloat32Array()
	var _l1 := PackedFloat32Array()
	var _l2 := PackedFloat32Array()
	var _l3 := PackedFloat32Array()
	var _a0 := PackedFloat32Array()
	var _a1 := PackedFloat32Array()
	var _n := PackedInt32Array()
	var _gain := PackedFloat64Array()
	var _mask := 0
	var _amask := 0
	var _w := 0
	var _d := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var _c := 0.5
	var _wet := 0.3
	var _dry := 1.0
	var _t60 := 4.0

	func _init_fx(p: Dictionary) -> void:
		_t60 = maxf(0.2, float(p.get("t60", 4.0)))
		var size := clampf(float(p.get("size", 1.0)), 0.3, 2.5)
		var sr := float(rate) / 44100.0
		var longest := 16
		for k in LINES.size():
			var n := maxi(16, roundi(float(LINES[k]) * size * sr))
			_n.append(n)
			_gain.append(pow(10.0, -3.0 * n / (_t60 * rate)))
			longest = maxi(longest, n + 1)
		var s := ScoreFx.pow2_at_least(longest)
		_mask = s - 1
		_l0.resize(s)
		_l0.fill(0.0)
		_l1.resize(s)
		_l1.fill(0.0)
		_l2.resize(s)
		_l2.fill(0.0)
		_l3.resize(s)
		_l3.fill(0.0)
		var d0 := maxi(8, roundi(float(DIFFUSE[0]) * sr))
		var d1 := maxi(8, roundi(float(DIFFUSE[1]) * sr))
		_n.append(d0)
		_n.append(d1)
		var sa := ScoreFx.pow2_at_least(maxi(d0, d1) + 1)
		_amask = sa - 1
		_a0.resize(sa)
		_a0.fill(0.0)
		_a1.resize(sa)
		_a1.fill(0.0)
		_c = exp(-TAU * float(p.get("damp_hz", 5000.0)) / rate)
		_wet = float(p.get("wet", 0.3))
		_dry = float(p.get("dry", 1.0))

	func memory() -> float:
		return _t60

	func process(l: PackedFloat32Array, r: PackedFloat32Array, n: int, _t0: int) -> void:
		var l0 := _l0
		var l1 := _l1
		var l2 := _l2
		var l3 := _l3
		var a0 := _a0
		var a1 := _a1
		var n0 := _n[0]
		var n1 := _n[1]
		var n2 := _n[2]
		var n3 := _n[3]
		var m0 := _n[4]
		var m1 := _n[5]
		var g0 := _gain[0]
		var g1 := _gain[1]
		var g2 := _gain[2]
		var g3 := _gain[3]
		var d0 := _d[0]
		var d1 := _d[1]
		var d2 := _d[2]
		var d3 := _d[3]
		var mask := _mask
		var amask := _amask
		var w := _w
		var c := _c
		var wet := _wet
		var dry := _dry
		var two := stereo
		const G := 0.6
		for i in n:
			var x := (l[i] + r[i]) * 0.5 if two else l[i]
			var b := a0[(w - m0) & amask]
			var y := b - G * x
			a0[w & amask] = x + G * y
			b = a1[(w - m1) & amask]
			x = b - G * y
			a1[w & amask] = y + G * x
			var o0 := l0[(w - n0) & mask]
			var o1 := l1[(w - n1) & mask]
			var o2 := l2[(w - n2) & mask]
			var o3 := l3[(w - n3) & mask]
			d0 = o0 + c * (d0 - o0)
			d1 = o1 + c * (d1 - o1)
			d2 = o2 + c * (d2 - o2)
			d3 = o3 + c * (d3 - o3)
			var h := (d0 + d1 + d2 + d3) * 0.5
			l0[w & mask] = (d0 - h) * g0 + x
			l1[w & mask] = (d1 - h) * g1 - x
			l2[w & mask] = (d2 - h) * g2 + x
			l3[w & mask] = (d3 - h) * g3 - x
			l[i] = l[i] * dry + (o0 - o2 + o1 * 0.4) * wet
			if two:
				r[i] = r[i] * dry + (o1 - o3 + o2 * 0.4) * wet
			w += 1
		_w = w
		_d = PackedFloat64Array([d0, d1, d2, d3])


## mode (0 low-pass, 2 high-pass), hz, q, sweep (octaves), sweep_hz (snapped).
class Tone:
	extends ScoreEffect
	var _hz := 2000.0
	var _q := 0.707
	var _mode := 0
	var _sweep := 0.0
	var _sw := 0.0
	var _z := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])

	func _init_fx(p: Dictionary) -> void:
		_hz = float(p.get("hz", 2000.0))
		_q = float(p.get("q", 0.707))
		_mode = int(p.get("mode", 0))
		_sweep = float(p.get("sweep", 0.0))
		_sw = TAU * snap_hz(float(p.get("sweep_hz", 0.05))) / rate

	func process(l: PackedFloat32Array, r: PackedFloat32Array, n: int, t0: int) -> void:
		var z1l := _z[0]
		var z2l := _z[1]
		var z1r := _z[2]
		var z2r := _z[3]
		var kq := 1.0 / maxf(0.3, _q)
		var two := stereo
		var hp := _mode == 2
		var j := 0
		while j < n:
			var m := mini(CHUNK * 4, n - j)
			var hz := _hz
			if _sweep != 0.0:
				hz *= pow(2.0, _sweep * sin(_sw * float(t0 + j + (m >> 1))))
			var g := tan(PI * clampf(hz, 10.0, rate * 0.45) / rate)
			var a1 := 1.0 / (1.0 + g * (g + kq))
			var a2 := g * a1
			var a3 := g * a2
			for i in range(j, j + m):
				var x := l[i]
				var v3 := x - z2l
				var v1 := a1 * z1l + a2 * v3
				var v2 := z2l + a2 * z1l + a3 * v3
				z1l = v1 + v1 - z1l
				z2l = v2 + v2 - z2l
				l[i] = (x - kq * v1 - v2) if hp else v2
				if two:
					x = r[i]
					v3 = x - z2r
					v1 = a1 * z1r + a2 * v3
					v2 = z2r + a2 * z1r + a3 * v3
					z1r = v1 + v1 - z1r
					z2r = v2 + v2 - z2r
					r[i] = (x - kq * v1 - v2) if hp else v2
			j += m
		_z = PackedFloat64Array([z1l, z2l, z1r, z2r])
