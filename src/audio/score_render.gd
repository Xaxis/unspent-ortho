class_name ScoreRender
extends RefCounted
## One stem of the score as a job that can stop and resume: notes laid on a
## timeline (ScoreVoice), effects over the whole stem (ScoreEffect), then the
## bank's own finishing (high-pass, measure, normalise, 16-bit), every stage in
## slices. step(budget) does as much as the budget allows and returns whether
## it is done, so a browser without threads builds the score a few milliseconds
## a frame and never freezes one; run() does it all at once on a worker, in a
## test or in tools/audio.sh. Same samples either way: block edges are invisible.
##
## Loops. A note is laid at its place in the loop and again one loop earlier, so
## its tail past the end sounds at the start; held voices (drones) span the loop
## on whole cycles; the effects run over a pre-roll of their own memory before
## frame 0, which is thrown away. The frame after the last is then the first.

const BLOCK := 256
const POST_SLICE := 16384
## Samples of a loop's tail the high-pass runs over before its pass, so its state
## at frame 0 is its state at the end.
const PRIME := 16000
## The longest pre-roll a loop renders, seconds.
const PREROLL_MAX := 12.0

enum Stage { PREPARE, RENDER, HIGHPASS, MEASURE, ENCODE, DONE }

var key: StringName = &""
var rate := 22050
var stereo := true
var loop := true
## Loop length in frames. A one-shot's is set by prepare(): its last note's end plus `tail`.
var frames := 0
## One-shots: seconds kept after the last note ends (echo and hall tails).
var tail := 0.0
## Fourth-order high-pass corner applied after rendering (the bank category's).
var highpass := 0.0
## [start frame, voice class, params]
var notes: Array = []
var effects: Array[ScoreEffect] = []

var stage := Stage.PREPARE
## Loops: frames of effect memory rendered before frame 0.
var preroll := 0
## Interleaved when stereo, normalised to SoundBank.PEAK; and the same as 16-bit PCM.
var samples := PackedFloat32Array()
var pcm := PackedByteArray()
## The loudest half-second RMS of the normalised samples (the mix measure).
var loudest := 0.0
## Peak before normalising, and the gain that normalised it.
var raw_peak := 0.0
var norm := 1.0
## Milliseconds of work spent, however many frames it was spread over.
var busy_usec := 0

var _left := PackedFloat32Array()
var _right := PackedFloat32Array()
var _held: Array = []
var _list: Array = []
var _next := 0
var _active: Array[ScoreVoice] = []
var _cursor := 0
var _bl := PackedFloat32Array()
var _br := PackedFloat32Array()
var _pass := 0
var _pos := 0
var _primed := false
var _z1 := 0.0
var _z2 := 0.0
var _hops := PackedFloat64Array()
var _hop := 1


func _init(p_key: StringName = &"", p_rate: int = 22050, p_stereo: bool = true, p_loop: bool = true, p_frames: int = 0) -> void:
	key = p_key
	rate = p_rate
	stereo = p_stereo
	loop = p_loop
	frames = p_frames


## Lays a note at `at` seconds (wrapped into the loop for loops).
func note(at: float, kind: GDScript, p: Dictionary) -> void:
	notes.append([roundi(at * rate), kind, p])


## A voice held through the whole loop (a drone): it sounds from the start of the
## pre-roll to the end, and its frequencies and sweeps are snapped to whole cycles
## over the loop, so its last sample runs into its first.
func hold(kind: GDScript, p: Dictionary) -> void:
	_held.append([kind, p])


## Adds an effect to the chain (in order) and returns it.
func fx(kind: GDScript, p: Dictionary) -> ScoreEffect:
	var e: ScoreEffect = kind.new()
	e.setup(p, rate, stereo, frames if loop else 0)
	effects.append(e)
	return e


func done() -> bool:
	return stage == Stage.DONE


## Everything at once.
func run() -> void:
	# Every stage finishes inside one unlimited step; a stage that did not has
	# failed (a script error), and asking again would spin forever.
	for attempt in 3:
		if step(1 << 40):
			return
	push_error("score stem %s did not finish (stage %d)" % [key, stage])
	stage = Stage.DONE


## Works until `budget_usec` microseconds have passed (checked between blocks
## and slices); true once the stem is finished.
func step(budget_usec: int) -> bool:
	var t0 := Time.get_ticks_usec()
	var until := t0 + budget_usec
	while stage != Stage.DONE:
		match stage:
			Stage.PREPARE:
				_prepare()
			Stage.RENDER:
				_render(until)
			Stage.HIGHPASS:
				_highpass(until)
			Stage.MEASURE:
				_measure(until)
			Stage.ENCODE:
				_encode(until)
		if Time.get_ticks_usec() >= until:
			break
	busy_usec += Time.get_ticks_usec() - t0
	return stage == Stage.DONE


func _prepare() -> void:
	var memory := 0.0
	for e in effects:
		memory = maxf(memory, e.memory())
	var ends := 0
	# Echo older than PREROLL_MAX is 30-40 dB under its own repeats: not worth
	# rendering twice.
	preroll = mini(frames, ceili(minf(memory, PREROLL_MAX) * rate)) if loop else 0
	if loop:
		for h: Array in _held:
			var p: Dictionary = (h[1] as Dictionary).duplicate()
			p["held"] = true
			p["period"] = frames
			p["frames"] = frames + preroll
			_list.append([-preroll, h[0], p])
	for n: Array in notes:
		var s: int = n[0]
		var kind: GDScript = n[1]
		var p: Dictionary = n[2]
		var d := ScoreVoices.frames_of(kind, p, rate)
		if loop:
			s = posmod(s, frames)
			# Notes are shorter than their loop, so one earlier copy carries every tail.
			for k: int in [-1, 0]:
				var c := s + k * frames
				if c + d > -preroll:
					_list.append([c, kind, p])
		else:
			_list.append([s, kind, p])
			ends = maxi(ends, s + d)
	_list.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	if loop:
		_cursor = -preroll
		if not _list.is_empty():
			_cursor = mini(_cursor, int(_list[0][0]))
	else:
		frames = maxi(1, ends + roundi(tail * rate))
		_cursor = mini(0, int(_list[0][0])) if not _list.is_empty() else 0
	_left.resize(frames)
	_left.fill(0.0)
	if stereo:
		_right.resize(frames)
		_right.fill(0.0)
	_bl.resize(BLOCK)
	_br.resize(BLOCK)
	stage = Stage.RENDER


func _render(until: int) -> void:
	while _cursor < frames:
		var n := mini(BLOCK, frames - _cursor)
		while _next < _list.size() and int(_list[_next][0]) < _cursor + n:
			var e: Array = _list[_next]
			var v: ScoreVoice = (e[1] as GDScript).new()
			v.setup(e[2], rate, stereo, int(e[0]))
			_active.append(v)
			_next += 1
		_bl.fill(0.0)
		_br.fill(0.0)
		for k in range(_active.size() - 1, -1, -1):
			var v := _active[k]
			var at := maxi(0, v.start - _cursor)
			var count := mini(n - at, v.length - v.pos)
			if count > 0:
				v.render(_bl, _br, at, count)
			if v.finished():
				_active.remove_at(k)
		for e in effects:
			e.process(_bl, _br, n, _cursor)
		var from := maxi(0, -_cursor)
		var left := _left
		var right := _right
		var c := _cursor
		for i in range(from, n):
			left[c + i] = _bl[i]
		if stereo:
			for i in range(from, n):
				right[c + i] = _br[i]
		_cursor += n
		if Time.get_ticks_usec() >= until:
			return
	_active.clear()
	_list.clear()
	_pass = 0
	_pos = 0
	_primed = not loop
	stage = Stage.HIGHPASS if highpass > 0.0 else Stage.MEASURE


## Two Butterworth sections per channel, each primed from the loop's tail first.
func _highpass(until: int) -> void:
	var channels := 2 if stereo else 1
	while _pass < channels * 2:
		var buf := _left if _pass < 2 else _right
		var c := Synth.coeffs_highpass(rate, highpass, 0.5412 if _pass % 2 == 0 else 1.3066)
		var b0 := c[0]
		var b1 := c[1]
		var b2 := c[2]
		var a1 := c[3]
		var a2 := c[4]
		var z1 := _z1
		var z2 := _z2
		if not _primed:
			for i in range(maxi(0, frames - PRIME), frames):
				var x := buf[i]
				var y := b0 * x + z1
				z1 = b1 * x - a1 * y + z2
				z2 = b2 * x - a2 * y
			_primed = true
		while _pos < frames:
			var end := mini(frames, _pos + POST_SLICE)
			for i in range(_pos, end):
				var x := buf[i]
				var y := b0 * x + z1
				z1 = b1 * x - a1 * y + z2
				z2 = b2 * x - a2 * y
				buf[i] = y
			_pos = end
			if Time.get_ticks_usec() >= until and _pos < frames:
				_z1 = z1
				_z2 = z2
				return
		_pass += 1
		_pos = 0
		_z1 = 0.0
		_z2 = 0.0
		_primed = not loop
		if Time.get_ticks_usec() >= until:
			return
	_pos = 0
	stage = Stage.MEASURE


## Peak, and the energy of every eighth of a half-second, for the loudest window.
func _measure(until: int) -> void:
	var w := Synth.samples(rate, 0.5)
	_hop = maxi(1, w / 8)
	if _pos == 0:
		_hops.resize(ceili(float(frames) / _hop))
		_hops.fill(0.0)
		raw_peak = 0.0
	var left := _left
	var right := _right
	var hops := _hops
	var hop := _hop
	while _pos < frames:
		var end := mini(frames, _pos + POST_SLICE)
		var pk := raw_peak
		for i in range(_pos, end):
			var x := left[i]
			var e := x * x
			if stereo:
				var y := right[i]
				e = (e + y * y) * 0.5
				pk = maxf(pk, absf(y))
			pk = maxf(pk, absf(x))
			hops[i / hop] += e
		raw_peak = pk
		_pos = end
		if Time.get_ticks_usec() >= until and _pos < frames:
			return
	var best := 0.0
	if frames <= w:
		for h in _hops:
			best += h
	else:
		var win := 0.0
		for h in 8:
			win += _hops[mini(h, _hops.size() - 1)]
		best = win
		for h in range(8, _hops.size()):
			win += _hops[h] - _hops[h - 8]
			best = maxf(best, win)
	norm = SoundBank.PEAK / raw_peak if raw_peak > 1e-9 else 1.0
	loudest = sqrt(best / float(w)) * norm
	_hops = PackedFloat64Array()
	_pos = 0
	stage = Stage.ENCODE


func _encode(until: int) -> void:
	var channels := 2 if stereo else 1
	if _pos == 0:
		samples.resize(frames * channels)
		pcm.resize(frames * channels * 2)
	var g := norm
	var fade_from := frames if loop else frames - Synth.samples(rate, 0.05)
	var left := _left
	var right := _right
	while _pos < frames:
		var end := mini(frames, _pos + POST_SLICE)
		for i in range(_pos, end):
			var gi := g
			if i >= fade_from:
				gi *= float(frames - i) / (frames - fade_from)
			var x := left[i] * gi
			if stereo:
				var y := right[i] * gi
				samples[i * 2] = x
				samples[i * 2 + 1] = y
				pcm.encode_s16(i * 4, roundi(clampf(x, -1.0, 1.0) * 32767.0))
				pcm.encode_s16(i * 4 + 2, roundi(clampf(y, -1.0, 1.0) * 32767.0))
			else:
				samples[i] = x
				pcm.encode_s16(i * 2, roundi(clampf(x, -1.0, 1.0) * 32767.0))
		_pos = end
		if Time.get_ticks_usec() >= until and _pos < frames:
			return
	_left = PackedFloat32Array()
	_right = PackedFloat32Array()
	stage = Stage.DONE
