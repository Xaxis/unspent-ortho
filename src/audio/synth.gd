class_name Synth
## Offline, deterministic synthesis into mono PackedFloat32Array buffers.
## Every sound in the game is a recipe built from these pieces and baked once
## into a 16-bit AudioStreamWAV by SoundBank. Nothing here touches nodes or
## shared state, so a recipe runs identically on a worker thread, in a test and
## in tools/audio.sh.
##
## Loops. A buffer of n samples is periodic when sample n wraps to sample 0:
##   - oscillators loop when every frequency makes whole cycles (snap_freq);
##   - add(..., wrap = true) folds an event's tail back onto the start;
##   - filters with periodic = true prime their state with the buffer's own
##     tail, so filtered periodic noise stays periodic (no crossfade, no seam).
##
## Levels are linear amplitudes; recipes need not care about absolute level,
## SoundBank normalises every sound and the mix sheet sets what is heard.

const LN_1000 := 6.907755279
## Samples of a periodic buffer's tail run through an IIR before the pass, so
## its state at sample 0 is the state it will have at the end. Enough for the
## slowest filter used on a loop (a Q 45 resonance at 147 Hz decays in ~0.1 s).
const PRIME := 16000


# ------------------------------------------------------------------ buffers

static func samples(rate: int, seconds: float) -> int:
	return maxi(1, roundi(rate * seconds))


static func buffer(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	b.fill(0.0)
	return b


## The nearest frequency that makes a whole number of cycles in n samples.
static func snap_freq(freq: float, rate: int, n: int) -> float:
	var cycles := maxf(1.0, roundf(freq * n / rate))
	return cycles * rate / n


## Adds src into dst from sample `at`, scaled by gain. With wrap the part that
## runs past the end folds back to the start, which is how loop events are laid.
static func add(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float = 1.0, wrap: bool = false) -> void:
	var n := dst.size()
	var m := src.size()
	if wrap:
		at = posmod(at, n)
		var done := 0
		while done < m:
			var room := mini(n - at, m - done)
			for j in room:
				dst[at + j] += src[done + j] * gain
			done += room
			at = 0
		return
	var j0 := maxi(0, -at)
	var j1 := mini(m, n - at)
	for j in range(j0, j1):
		dst[at + j] += src[j] * gain


static func scale(buf: PackedFloat32Array, gain: float) -> void:
	for i in buf.size():
		buf[i] *= gain


## Multiply two equal-length buffers in place into a.
static func multiply(a: PackedFloat32Array, b: PackedFloat32Array) -> void:
	for i in mini(a.size(), b.size()):
		a[i] *= b[i]


static func slice(buf: PackedFloat32Array, from: int, count: int) -> PackedFloat32Array:
	return buf.slice(from, from + count)


## Resample by linear interpolation (for pitched copies of a baked event).
static func stretch(src: PackedFloat32Array, factor: float) -> PackedFloat32Array:
	var m := maxi(1, roundi(src.size() * factor))
	var out := buffer(m)
	var step := float(src.size() - 1) / maxf(1.0, float(m - 1))
	for i in m:
		var x := i * step
		var k := floori(x)
		var f := x - k
		var a := src[k]
		var b := src[mini(k + 1, src.size() - 1)]
		out[i] = a + (b - a) * f
	return out


# -------------------------------------------------------------- oscillators

## A sine added into buf[from, from + count). phase is in cycles.
static func add_sine(buf: PackedFloat32Array, rate: int, freq: float, amp: float, from: int = 0, count: int = -1, phase: float = 0.0) -> void:
	if count < 0:
		count = buf.size() - from
	count = mini(count, buf.size() - from)
	var w := TAU * freq / rate
	var p0 := phase * TAU
	for j in count:
		buf[from + j] += amp * sin(w * j + p0)


## Several sine partials over the whole buffer (exact integer partials for
## machines: pass frequencies already snapped to the loop).
## When every partial makes whole cycles over the buffer, their sum repeats
## every n / gcd(cycles) samples: that one period is computed and tiled.
static func add_partials(buf: PackedFloat32Array, rate: int, freqs: PackedFloat32Array, amps: PackedFloat32Array, phase_seed: int = 0) -> void:
	var n := buf.size()
	var g := n
	for k in freqs.size():
		var cycles := freqs[k] * n / rate
		if absf(cycles - roundf(cycles)) > 1e-6:
			g = 1
			break
		g = _gcd(g, roundi(cycles))
	var period := n / maxi(1, g) if g > 1 else n
	var one := buffer(period)
	for k in freqs.size():
		var ph := Rng.hash01(phase_seed, k, 0x9a) if phase_seed != 0 else 0.0
		add_sine(one, rate, freqs[k], amps[k], 0, -1, ph)
	var at := 0
	while at < n:
		var m := mini(period, n - at)
		for j in m:
			buf[at + j] += one[j]
		at += m


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := a % b
		a = b
		b = t
	return absi(a)


## Repeats a periodic segment to fill n samples (machine textures: identical
## samples at exact intervals is the point).
static func tile(segment: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var out := buffer(n)
	var m := segment.size()
	var at := 0
	while at < n:
		var c := mini(m, n - at)
		for j in c:
			out[at + j] = segment[j]
		at += c
	return out


## Band-limited sawtooth (PolyBLEP), added.
static func add_saw(buf: PackedFloat32Array, rate: int, freq: float, amp: float, from: int = 0, count: int = -1, phase: float = 0.0) -> void:
	if count < 0:
		count = buf.size() - from
	count = mini(count, buf.size() - from)
	var dt := freq / rate
	var t := fposmod(phase, 1.0)
	for j in count:
		var v := 2.0 * t - 1.0
		if t < dt:
			var x := t / dt
			v -= x + x - x * x - 1.0
		elif t > 1.0 - dt:
			var x := (t - 1.0) / dt
			v -= x * x + x + x + 1.0
		buf[from + j] += amp * v
		t += dt
		if t >= 1.0:
			t -= 1.0


## Band-limited pulse (PolyBLEP), duty 0..1, added.
static func add_pulse(buf: PackedFloat32Array, rate: int, freq: float, amp: float, duty: float = 0.5, from: int = 0, count: int = -1) -> void:
	if count < 0:
		count = buf.size() - from
	count = mini(count, buf.size() - from)
	var dt := freq / rate
	var t := 0.0
	for j in count:
		var v := 1.0 if t < duty else -1.0
		v += _blep(t, dt)
		v -= _blep(fposmod(t - duty, 1.0), dt)
		buf[from + j] += amp * v
		t += dt
		if t >= 1.0:
			t -= 1.0


static func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


## A sine whose frequency glides exponentially from f0 to f1 over the buffer
## (drops, chirps, bubbles, thumps), added.
static func add_chirp(buf: PackedFloat32Array, rate: int, f0: float, f1: float, amp: float, from: int = 0, count: int = -1) -> void:
	if count < 0:
		count = buf.size() - from
	count = mini(count, buf.size() - from)
	var ph := 0.0
	var ratio := f1 / f0
	for j in count:
		var f := f0 * pow(ratio, float(j) / maxf(1.0, count - 1.0))
		ph += TAU * f / rate
		buf[from + j] += amp * sin(ph)


# -------------------------------------------------------------------- noise

## White noise in -1..1 from a seed (PCG32 via RandomNumberGenerator).
static func noise(n: int, seed_value: int) -> PackedFloat32Array:
	var r := Rng.make(seed_value, 0x401)
	var b := buffer(n)
	for i in n:
		b[i] = r.randf() * 2.0 - 1.0
	return b


## Pink-ish noise (Kellet's economy filter). Periodic noise stays periodic
## because the filter is primed from the tail.
static func pink(n: int, seed_value: int, periodic: bool = false) -> PackedFloat32Array:
	var w := noise(n, seed_value)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	if periodic:
		for i in range(maxi(0, n - 22050), n):
			var x := w[i]
			b0 = 0.99765 * b0 + x * 0.0990460
			b1 = 0.96300 * b1 + x * 0.2965164
			b2 = 0.57000 * b2 + x * 1.0526913
	for i in n:
		var x := w[i]
		b0 = 0.99765 * b0 + x * 0.0990460
		b1 = 0.96300 * b1 + x * 0.2965164
		b2 = 0.57000 * b2 + x * 1.0526913
		w[i] = (b0 + b1 + b2 + x * 0.1848) * 0.2
	return w


## Sparse random impulses (Poisson-like, `density` per second) with random
## sign and amplitude in [lo, hi]: the excitation for rain, gravel, crackle.
## Added into buf; positions wrap, so a loop stays periodic.
static func add_impulses(buf: PackedFloat32Array, rate: int, density: float, seed_value: int, lo: float = 0.3, hi: float = 1.0) -> void:
	var n := buf.size()
	var count := roundi(density * n / rate)
	var r := Rng.make(seed_value, 0x1217)
	for k in count:
		var i := r.randi_range(0, n - 1)
		var a := r.randf_range(lo, hi)
		buf[i] += a if r.randf() < 0.5 else -a


# ------------------------------------------------------------------ filters

## RBJ biquad coefficients, normalised: [b0, b1, b2, a1, a2].
static func coeffs_lowpass(rate: int, fc: float, q: float = 0.7071) -> PackedFloat64Array:
	var w := TAU * _clamp_fc(fc, rate) / rate
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return PackedFloat64Array([(1.0 - cw) * 0.5 / a0, (1.0 - cw) / a0, (1.0 - cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


static func coeffs_highpass(rate: int, fc: float, q: float = 0.7071) -> PackedFloat64Array:
	var w := TAU * _clamp_fc(fc, rate) / rate
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return PackedFloat64Array([(1.0 + cw) * 0.5 / a0, -(1.0 + cw) / a0, (1.0 + cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


## Band-pass with 0 dB peak gain at fc.
static func coeffs_bandpass(rate: int, fc: float, q: float) -> PackedFloat64Array:
	var w := TAU * _clamp_fc(fc, rate) / rate
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return PackedFloat64Array([alpha / a0, 0.0, -alpha / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


static func coeffs_peaking(rate: int, fc: float, q: float, db: float) -> PackedFloat64Array:
	var a := pow(10.0, db / 40.0)
	var w := TAU * _clamp_fc(fc, rate) / rate
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha / a
	return PackedFloat64Array([(1.0 + alpha * a) / a0, -2.0 * cw / a0, (1.0 - alpha * a) / a0, -2.0 * cw / a0, (1.0 - alpha / a) / a0])


static func coeffs_highshelf(rate: int, fc: float, db: float) -> PackedFloat64Array:
	var a := pow(10.0, db / 40.0)
	var w := TAU * _clamp_fc(fc, rate) / rate
	var cw := cos(w)
	var alpha := sin(w) / 2.0 * sqrt(2.0)
	var sa := 2.0 * sqrt(a) * alpha
	var a0 := (a + 1.0) - (a - 1.0) * cw + sa
	return PackedFloat64Array([
		a * ((a + 1.0) + (a - 1.0) * cw + sa) / a0,
		-2.0 * a * ((a - 1.0) + (a + 1.0) * cw) / a0,
		a * ((a + 1.0) + (a - 1.0) * cw - sa) / a0,
		2.0 * ((a - 1.0) - (a + 1.0) * cw) / a0,
		((a + 1.0) - (a - 1.0) * cw - sa) / a0,
	])


static func _clamp_fc(fc: float, rate: int) -> float:
	return clampf(fc, 5.0, rate * 0.49)


## Runs a biquad over buf in place. periodic primes the state with the tail.
static func biquad(buf: PackedFloat32Array, c: PackedFloat64Array, periodic: bool = false) -> void:
	var n := buf.size()
	var b0 := c[0]
	var b1 := c[1]
	var b2 := c[2]
	var a1 := c[3]
	var a2 := c[4]
	# Transposed direct form II: two states, the fewest statements per sample.
	var z1 := 0.0
	var z2 := 0.0
	if periodic:
		var p := mini(n, PRIME)
		for i in range(n - p, n):
			var x := buf[i]
			var y := b0 * x + z1
			z1 = b1 * x - a1 * y + z2
			z2 = b2 * x - a2 * y
	for i in n:
		var x := buf[i]
		var y := b0 * x + z1
		z1 = b1 * x - a1 * y + z2
		z2 = b2 * x - a2 * y
		buf[i] = y


static func lowpass(buf: PackedFloat32Array, rate: int, fc: float, q: float = 0.7071, periodic: bool = false) -> void:
	biquad(buf, coeffs_lowpass(rate, fc, q), periodic)


static func highpass(buf: PackedFloat32Array, rate: int, fc: float, q: float = 0.7071, periodic: bool = false) -> void:
	biquad(buf, coeffs_highpass(rate, fc, q), periodic)


## Fourth-order Butterworth low-pass (two sections).
static func lowpass4(buf: PackedFloat32Array, rate: int, fc: float, periodic: bool = false) -> void:
	biquad(buf, coeffs_lowpass(rate, fc, 0.5412), periodic)
	biquad(buf, coeffs_lowpass(rate, fc, 1.3066), periodic)


## Fourth-order Butterworth high-pass (two sections).
static func highpass4(buf: PackedFloat32Array, rate: int, fc: float, periodic: bool = false) -> void:
	biquad(buf, coeffs_highpass(rate, fc, 0.5412), periodic)
	biquad(buf, coeffs_highpass(rate, fc, 1.3066), periodic)


## Keep lo..hi: high-pass at lo, low-pass at hi, each fourth order when steep.
static func band(buf: PackedFloat32Array, rate: int, lo: float, hi: float, periodic: bool = false, steep: bool = true) -> void:
	if steep:
		highpass4(buf, rate, lo, periodic)
		lowpass4(buf, rate, hi, periodic)
	else:
		highpass(buf, rate, lo, 0.7071, periodic)
		lowpass(buf, rate, hi, 0.7071, periodic)


## A resonant band-pass (0 dB at fc): turns impulses and noise into pitch.
static func resonate(buf: PackedFloat32Array, rate: int, fc: float, q: float, periodic: bool = false) -> void:
	biquad(buf, coeffs_bandpass(rate, fc, q), periodic)


static func peak_eq(buf: PackedFloat32Array, rate: int, fc: float, q: float, db: float, periodic: bool = false) -> void:
	biquad(buf, coeffs_peaking(rate, fc, q, db), periodic)


## Sum of parallel resonances over one excitation (formants, bottle tones, bodies).
static func formants(src: PackedFloat32Array, rate: int, freqs: PackedFloat32Array, qs: PackedFloat32Array, gains: PackedFloat32Array, periodic: bool = false) -> PackedFloat32Array:
	var out := buffer(src.size())
	for k in freqs.size():
		var b := src.duplicate()
		resonate(b, rate, freqs[k], qs[k], periodic)
		add(out, b, 0, gains[k])
	return out


## Time-varying band-pass (Chamberlin state-variable filter): the centre
## follows `curve` (Hz per sample, same length as buf). Whistles, swooshes,
## vowel glides. Keep the centre under rate / 6 for stability.
static func sweep_band(buf: PackedFloat32Array, rate: int, curve: PackedFloat32Array, q: float) -> void:
	var low := 0.0
	var bp := 0.0
	var damp := 1.0 / maxf(0.5, q)
	var k := PI / rate
	var lim := rate / 6.5
	for i in buf.size():
		var f := 2.0 * sin(k * minf(curve[i], lim))
		low += f * bp
		var high := buf[i] - low - damp * bp
		bp += f * high
		buf[i] = bp


## A control curve: `from` to `to` over n samples with an exponential shape.
static func glide(n: int, from: float, to: float) -> PackedFloat32Array:
	var out := buffer(n)
	var ratio := to / from
	for i in n:
		out[i] = from * pow(ratio, float(i) / maxf(1.0, n - 1.0))
	return out


## One-pole low-pass smoothing (cheap; for control curves and dulling).
static func smooth(buf: PackedFloat32Array, rate: int, fc: float, periodic: bool = false) -> void:
	var a := exp(-TAU * fc / rate)
	var y := 0.0
	var n := buf.size()
	if periodic:
		for i in range(maxi(0, n - PRIME), n):
			y = buf[i] + a * (y - buf[i])
	for i in n:
		y = buf[i] + a * (y - buf[i])
		buf[i] = y


# ---------------------------------------------------------------- envelopes

## Linear attack, then exponential decay reaching -60 dB `t60` seconds later.
## Multiplies buf[from, from + count) in place; samples past the decay go on decaying.
static func env_perc(buf: PackedFloat32Array, rate: int, attack: float, t60: float, from: int = 0, count: int = -1) -> void:
	if count < 0:
		count = buf.size() - from
	count = mini(count, buf.size() - from)
	var na := maxi(1, roundi(attack * rate))
	var k := exp(-LN_1000 / maxf(1e-4, t60 * rate))
	var g := 1.0
	for j in count:
		if j < na:
			buf[from + j] *= float(j) / na
		else:
			buf[from + j] *= g
			g *= k


## Attack, decay to sustain, hold until `release_at` seconds, then release.
static func env_adsr(buf: PackedFloat32Array, rate: int, a: float, d: float, s: float, release_at: float, r: float) -> void:
	var na := maxf(1.0, a * rate)
	var nd := maxf(1.0, d * rate)
	var nr := release_at * rate
	var kr := exp(-LN_1000 / maxf(1.0, r * rate))
	var level := 0.0
	var rel := 1.0
	for i in buf.size():
		if i < na:
			level = i / na
		elif i < na + nd:
			level = 1.0 + (s - 1.0) * ((i - na) / nd)
		else:
			level = s
		if i >= nr:
			rel *= kr
		buf[i] *= level * rel


## Periodic swell: level = floor + (1 - floor) * |sin(pi * (cycles * i / n + phase))|^power.
## Whole cycles over the buffer, so a loop stays a loop.
static func env_swell(buf: PackedFloat32Array, cycles: float, power: float, floor_level: float = 0.0, phase: float = 0.0) -> void:
	var n := buf.size()
	var w := PI * cycles / n
	var p0 := PI * phase
	var depth := 1.0 - floor_level
	if power == 2.0:
		for i in n:
			var s := sin(w * i + p0)
			buf[i] *= floor_level + depth * s * s
		return
	for i in n:
		var s := absf(sin(w * i + p0))
		buf[i] *= floor_level + depth * pow(s, power)


## Periodic soft-edged gate at `hz` (snap it to the loop), duty 0..1.
static func env_gate(buf: PackedFloat32Array, rate: int, hz: float, duty: float = 0.5, edge: float = 0.15, depth: float = 1.0, phase: float = 0.0) -> void:
	var dt := hz / rate
	for i in buf.size():
		var t := fposmod(i * dt + phase, 1.0)
		var g: float
		if t < duty:
			var e := minf(t, duty - t) / maxf(1e-6, edge * duty)
			g = smoothstep(0.0, 1.0, minf(1.0, e))
		else:
			g = 0.0
		buf[i] *= 1.0 - depth + depth * g


## Sine tremolo at `hz` (snap to the loop for beds).
static func tremolo(buf: PackedFloat32Array, rate: int, hz: float, depth: float, phase: float = 0.0) -> void:
	var w := TAU * hz / rate
	var p0 := TAU * phase
	for i in buf.size():
		buf[i] *= 1.0 - depth * (0.5 - 0.5 * cos(w * i + p0))


## Short linear fades at both ends (kills clicks on one-shots).
static func fade(buf: PackedFloat32Array, rate: int, fade_in: float, fade_out: float) -> void:
	var n := buf.size()
	var ni := mini(n, roundi(fade_in * rate))
	var no := mini(n, roundi(fade_out * rate))
	for i in ni:
		buf[i] *= float(i) / ni
	for i in no:
		buf[n - 1 - i] *= float(i) / no


## A smooth random control curve (0..1) with `points` knots per buffer, cosine
## interpolated; wraps, so it is periodic. For slow natural wandering.
static func wander(n: int, points: int, seed_value: int, lo: float = 0.0, hi: float = 1.0) -> PackedFloat32Array:
	var r := Rng.make(seed_value, 0x3a1)
	var knots := PackedFloat32Array()
	for k in points:
		knots.append(r.randf_range(lo, hi))
	var out := buffer(n)
	var seg := float(n) / points
	for i in n:
		var x := i / seg
		var k := floori(x)
		var f := x - k
		var a := knots[k % points]
		var b := knots[(k + 1) % points]
		var m := (1.0 - cos(f * PI)) * 0.5
		out[i] = a + (b - a) * m
	return out


# ----------------------------------------------------------------- physical

## Exponentially decaying sine modes: plates, bars, knocks. An identical copy
## every time it is used, which is what machines want.
static func modes(rate: int, seconds: float, freqs: PackedFloat32Array, amps: PackedFloat32Array, t60s: PackedFloat32Array, attack: float = 0.0008) -> PackedFloat32Array:
	var n := samples(rate, seconds)
	var out := buffer(n)
	var na := maxi(1, roundi(attack * rate))
	for k in freqs.size():
		if freqs[k] >= rate * 0.48:
			continue
		var w := TAU * freqs[k] / rate
		var dk := exp(-LN_1000 / maxf(1.0, t60s[k] * rate))
		var g := amps[k]
		for i in n:
			var a := g
			if i < na:
				a *= float(i) / na
			out[i] += a * sin(w * i)
			g *= dk
			if g < 1e-5:
				break
	return out


## Karplus-Strong plucked string with a fractional-delay allpass so pitch is
## exact; `t60` sets how long the fundamental rings, `bright` the pick.
static func pluck(rate: int, freq: float, seconds: float, seed_value: int, bright: float = 0.5, t60: float = 1.5) -> PackedFloat32Array:
	var n := samples(rate, seconds)
	var out := buffer(n)
	var period := float(rate) / freq - 0.5
	var length := maxi(2, floori(period))
	var frac := period - length
	if frac < 0.1:
		length -= 1
		frac += 1.0
	var ap := (1.0 - frac) / (1.0 + frac)
	var line := noise(length, seed_value)
	# Pick brightness: a one-pole over the excitation.
	var sm := clampf(1.0 - bright, 0.0, 0.95)
	var y := 0.0
	for i in length:
		y = line[i] + sm * (y - line[i])
		line[i] = y
	var mean := 0.0
	for i in length:
		mean += line[i]
	mean /= length
	for i in length:
		line[i] -= mean
	var loss := pow(10.0, -3.0 / (freq * maxf(0.01, t60))) / maxf(0.2, cos(PI * freq / rate))
	loss = minf(loss, 0.99995)
	var idx := 0
	var prev := 0.0
	var ap_x1 := 0.0
	var ap_y1 := 0.0
	for i in n:
		var cur := line[idx]
		var avg := 0.5 * (cur + prev) * loss
		prev = cur
		# Allpass fractional delay.
		var apo := ap * avg + ap_x1 - ap * ap_y1
		ap_x1 = avg
		ap_y1 = apo
		line[idx] = apo
		out[i] = cur
		idx += 1
		if idx >= length:
			idx = 0
	return out


## Two-operator FM with an optional second (tine) modulator: the electric
## piano and the bell. index decays with index_t60 so attacks are bright and
## tails mellow; amplitude decays with amp_t60.
static func fm(rate: int, freq: float, seconds: float, ratio: float, index: float, index_t60: float, amp_t60: float, attack: float = 0.003, tine_ratio: float = 0.0, tine_index: float = 0.0) -> PackedFloat32Array:
	var n := samples(rate, seconds)
	var out := buffer(n)
	var wc := TAU * freq / rate
	var wm := TAU * freq * ratio / rate
	var wt := TAU * freq * tine_ratio / rate
	var ki := exp(-LN_1000 / maxf(1.0, index_t60 * rate))
	var ka := exp(-LN_1000 / maxf(1.0, amp_t60 * rate))
	var kt := exp(-LN_1000 / maxf(1.0, 0.05 * rate))
	var na := maxi(1, roundi(attack * rate))
	var idx := index
	var amp := 1.0
	var tidx := tine_index
	for i in n:
		var mod := idx * sin(wm * i)
		if tidx > 1e-4:
			mod += tidx * sin(wt * i)
			tidx *= kt
		var a := amp
		if i < na:
			a *= float(i) / na
		out[i] = a * sin(wc * i + mod)
		idx *= ki
		amp *= ka
	return out


## Freeverb-style mono room (four damped combs, two allpasses). Returns a new
## buffer with `tail` seconds appended. The impulse response is generated, not
## loaded. Delay indices count and wrap instead of taking a modulo per sample.
static func reverb(buf: PackedFloat32Array, rate: int, room: float = 0.75, damp: float = 0.35, wet: float = 0.3, tail: float = 2.0) -> PackedFloat32Array:
	var n := buf.size()
	var total := n + samples(rate, tail)
	var out := buffer(total)
	var sr := rate / 44100.0
	var l0 := maxi(8, roundi(1116 * sr))
	var l1 := maxi(8, roundi(1277 * sr))
	var l2 := maxi(8, roundi(1422 * sr))
	var l3 := maxi(8, roundi(1557 * sr))
	var m0 := maxi(8, roundi(556 * sr))
	var m1 := maxi(8, roundi(341 * sr))
	var c0 := buffer(l0)
	var c1 := buffer(l1)
	var c2 := buffer(l2)
	var c3 := buffer(l3)
	var a0 := buffer(m0)
	var a1 := buffer(m1)
	var i0 := 0
	var i1 := 0
	var i2 := 0
	var i3 := 0
	var j0 := 0
	var j1 := 0
	var fb := room * 0.28 + 0.7
	var d := damp * 0.4
	var nd := 1.0 - d
	var f0 := 0.0
	var f1 := 0.0
	var f2 := 0.0
	var f3 := 0.0
	var dry := 1.0 - wet * 0.5
	var wet_gain := wet * 4.5
	for i in total:
		var x := buf[i] if i < n else 0.0
		var inp := x * 0.015
		var y0 := c0[i0]
		f0 = y0 * nd + f0 * d
		c0[i0] = inp + f0 * fb
		var y1 := c1[i1]
		f1 = y1 * nd + f1 * d
		c1[i1] = inp + f1 * fb
		var y2 := c2[i2]
		f2 = y2 * nd + f2 * d
		c2[i2] = inp + f2 * fb
		var y3 := c3[i3]
		f3 = y3 * nd + f3 * d
		c3[i3] = inp + f3 * fb
		var o := y0 + y1 + y2 + y3
		var b := a0[j0]
		a0[j0] = o + b * 0.5
		o = b - o
		b = a1[j1]
		a1[j1] = o + b * 0.5
		o = b - o
		out[i] = x * dry + o * wet_gain
		i0 += 1
		if i0 == l0:
			i0 = 0
		i1 += 1
		if i1 == l1:
			i1 = 0
		i2 += 1
		if i2 == l2:
			i2 = 0
		i3 += 1
		if i3 == l3:
			i3 = 0
		j0 += 1
		if j0 == m0:
			j0 = 0
		j1 += 1
		if j1 == m1:
			j1 = 0
	return out


## A tape-less feedback echo: repeats every `delay` seconds, each `feedback`
## as loud and duller (a one-pole low-pass at damp_hz in the loop), mixed in
## at `wet`. The early-90s sample machines' echo, a beat-synced repeat rather
## than a hall. Returns a new buffer `tail` seconds longer.
static func echo(buf: PackedFloat32Array, rate: int, delay: float, feedback: float, damp_hz: float, wet: float, tail: float) -> PackedFloat32Array:
	var n := buf.size()
	var total := n + samples(rate, tail)
	var out := buffer(total)
	var d := maxi(1, samples(rate, delay))
	var line := buffer(d)
	var a := exp(-TAU * damp_hz / rate)
	var lp := 0.0
	var idx := 0
	for i in total:
		var x := buf[i] if i < n else 0.0
		var y := line[idx]
		lp = y + a * (lp - y)
		line[idx] = x + lp * feedback
		out[i] = x + y * wet
		idx += 1
		if idx == d:
			idx = 0
	return out


## Drops a one-shot's silent tail (below `floor_db` of its peak), keeping a
## short fade, so reverb tails and generous buffers cost nothing to play.
static func trim_tail(buf: PackedFloat32Array, rate: int, floor_db: float = -66.0) -> PackedFloat32Array:
	var p := peak(buf)
	if p <= 0.0:
		return buf
	var lim := p * pow(10.0, floor_db / 20.0)
	var last := buf.size() - 1
	while last > 0 and absf(buf[last]) < lim:
		last -= 1
	var keep := mini(buf.size(), last + samples(rate, 0.02))
	if keep >= buf.size() - samples(rate, 0.05):
		return buf
	var out := buf.slice(0, keep)
	fade(out, rate, 0.0, 0.02)
	return out


# ----------------------------------------------------------------- analysis

static func peak(buf: PackedFloat32Array) -> float:
	var p := 0.0
	for i in buf.size():
		var a := absf(buf[i])
		if a > p:
			p = a
	return p


static func rms(buf: PackedFloat32Array, from: int = 0, count: int = -1) -> float:
	if count < 0:
		count = buf.size() - from
	if count <= 0:
		return 0.0
	var s := 0.0
	for i in range(from, from + count):
		s += buf[i] * buf[i]
	return sqrt(s / count)


## RMS of the loudest `window` seconds (the mix measure). A sound shorter than
## the window is measured over the full window, silence included: short sounds
## must be hotter to be heard as loud, which is how ears integrate.
static func loudest_rms(buf: PackedFloat32Array, rate: int, window: float = 0.5) -> float:
	var n := buf.size()
	var w := samples(rate, window)
	if n <= w:
		var s := 0.0
		for i in n:
			s += buf[i] * buf[i]
		return sqrt(s / w)
	var hop := maxi(1, w / 8)
	var best := 0.0
	var acc := 0.0
	for i in w:
		acc += buf[i] * buf[i]
	best = acc
	var start := 0
	while start + w + hop <= n:
		for i in hop:
			acc -= buf[start + i] * buf[start + i]
			acc += buf[start + w + i] * buf[start + w + i]
		start += hop
		best = maxf(best, acc)
	return sqrt(maxf(0.0, best) / w)


## Fraction of energy below fc (eighth-order split, so a partial just above
## the line does not leak into the measure). The laptop-speaker rule: nothing
## may carry its weight below 120 Hz.
static func low_energy_ratio(buf: PackedFloat32Array, rate: int, fc: float = 120.0, max_seconds: float = 2.0) -> float:
	# Two seconds say it: loops repeat and one-shots front-load their energy.
	var lo := buf.slice(0, mini(buf.size(), samples(rate, max_seconds)))
	var orig := lo.duplicate()
	for q: float in [0.5098, 0.6013, 0.9000, 2.5629]:
		biquad(lo, coeffs_lowpass(rate, fc * 0.9, q), buf.size() == lo.size())
	var el := 0.0
	var et := 0.0
	for i in lo.size():
		el += lo[i] * lo[i]
		et += orig[i] * orig[i]
	return el / maxf(1e-12, et)


## Amplitude of the component at `freq` (Goertzel over the given span). A pure
## sine of amplitude A reads ~A.
static func tone_level(buf: PackedFloat32Array, rate: int, freq: float, from: int = 0, count: int = -1) -> float:
	if count < 0:
		count = buf.size() - from
	var w := TAU * freq / rate
	var cw := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in range(from, from + count):
		# Hann window keeps leakage from neighbours out.
		var win := 0.5 - 0.5 * cos(TAU * (i - from) / count)
		var s := buf[i] * win + cw * s1 - s2
		s2 = s1
		s1 = s
	var power := s1 * s1 + s2 * s2 - cw * s1 * s2
	return sqrt(maxf(0.0, power)) * 4.0 / count


## Where a sound's weight sits: the amplitude-weighted mean frequency of `count`
## samples from `from`, over tone_level probes a third of an octave apart
## (60 Hz to 12 kHz). Cheap enough for tests; not a spectrum analyser.
static func centroid(buf: PackedFloat32Array, rate: int, from: int = 0, count: int = -1) -> float:
	if count < 0:
		count = buf.size() - from
	count = mini(count, buf.size() - from)
	var f := 60.0
	var num := 0.0
	var den := 0.0
	while f < minf(12000.0, rate * 0.45):
		var a := tone_level(buf, rate, f, from, count)
		num += a * f
		den += a
		f *= pow(2.0, 1.0 / 3.0)
	return num / maxf(1e-12, den)


## How unusual the wrap from the last sample to the first is, against the
## buffer's own sample-to-sample steps: ~1 or less is seamless.
static func seam_ratio(buf: PackedFloat32Array) -> float:
	var n := buf.size()
	if n < 4:
		return 0.0
	# Judge the wrap against the steps right around it (a quarter-second each side).
	var w := mini(n / 2 - 1, 11025)
	var diffs := PackedFloat32Array()
	for i in range(n - w - 1, n - 1):
		diffs.append(absf(buf[i + 1] - buf[i]))
	for i in w:
		diffs.append(absf(buf[i + 1] - buf[i]))
	diffs.sort()
	var p99 := diffs[mini(diffs.size() - 1, floori(diffs.size() * 0.99))]
	return absf(buf[0] - buf[n - 1]) / maxf(1e-6, p99)


static func normalize(buf: PackedFloat32Array, target_peak: float) -> float:
	var p := peak(buf)
	if p < 1e-9:
		return 1.0
	var g := target_peak / p
	scale(buf, g)
	return g


## tanh-style soft saturation; drive > 1 thickens and tames peaks.
static func saturate(buf: PackedFloat32Array, drive: float) -> void:
	var norm := 1.0 / tanh(drive)
	for i in buf.size():
		buf[i] = tanh(buf[i] * drive) * norm


# ---------------------------------------------------------------- conversion

static func to_pcm16(buf: PackedFloat32Array) -> PackedByteArray:
	var n := buf.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, roundi(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return bytes


static func wav_from_pcm(pcm: PackedByteArray, rate: int, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = pcm
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = pcm.size() / 2
	return s


static func to_wav(buf: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	return wav_from_pcm(to_pcm16(buf), rate, loop)
