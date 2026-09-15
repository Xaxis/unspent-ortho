class_name ScoreVoice
extends RefCounted
## One sounding thing in a score stem: a note, a held drone, a swell of noise.
##
## Voices stream. render() adds the voice's next samples into a block and keeps
## every phase, filter state and envelope position in the voice, so a stem can be
## rendered in blocks of any size, stopped between two blocks and resumed on a
## later frame with exactly the same samples (ScoreRender). That is what lets a
## browser with no threads build the score without ever freezing a frame.
##
## Params are a read-only Dictionary. A loop's wrapped copy of a note spawns a
## fresh voice from the same params, so it plays the same samples; a voice must
## therefore never read absolute time unless it is `held` (a drone that spans the
## whole loop, whose frequencies the stem builder snapped to whole cycles).

## Sub-block for envelopes and filter coefficients: 1.5 ms at 22,050 Hz.
const CHUNK := 32
const LN_1000 := 6.907755279

var rate := 22050
var stereo := true
## Absolute sample the voice starts at in its stem (negative inside a loop's pre-roll).
var start := 0
## Samples it sounds for, release included.
var length := 1
## Samples already rendered.
var pos := 0
## Held voices read absolute time for their phases and LFOs.
var held := false

var _a := 0.01
var _d := 0.2
var _s := 1.0
var _hold := 1.0
var _r := 0.5
## Envelope shape: 0 attack-decay-sustain-release, 1 a sin^2 swell over the length, 2 flat (held).
var _shape := 0


func setup(p: Dictionary, sample_rate: int, is_stereo: bool, at: int) -> void:
	rate = sample_rate
	stereo = is_stereo
	start = at
	held = bool(p.get("held", false))
	_a = maxf(0.0005, float(p.get("a", 0.01)))
	_d = maxf(0.001, float(p.get("d", 0.2)))
	_s = clampf(float(p.get("s", 1.0)), 0.0, 1.0)
	_hold = maxf(0.0, float(p.get("hold", 1.0)))
	_r = maxf(0.005, float(p.get("r", 0.5)))
	_shape = int(p.get("shape", 2 if held else 0))
	length = length_of(p, sample_rate)
	_init_voice(p)


## Samples a note with these params sounds for: its hold plus a release to -60 dB.
static func length_of(p: Dictionary, sample_rate: int) -> int:
	if p.has("frames"):
		return maxi(1, int(p["frames"]))
	if int(p.get("shape", 0)) == 1:
		return maxi(1, roundi(float(p.get("hold", 1.0)) * sample_rate))
	return maxi(1, roundi((float(p.get("hold", 1.0)) + float(p.get("r", 0.5))) * sample_rate))


func _init_voice(_p: Dictionary) -> void:
	pass


## Adds samples [pos, pos + count) of this voice into l (and r when stereo)
## from index `at`. count never runs past the voice's length (ScoreRender clips).
func render(_l: PackedFloat32Array, _r_buf: PackedFloat32Array, _at: int, _count: int) -> void:
	pass


func finished() -> bool:
	return pos >= length


## Seconds of the voice's own clock at sample offset k (absolute for held voices).
func clock(k: int) -> float:
	return float((start if held else 0) + k) / rate


## Amplitude envelope at sample k of the voice.
func env_at(k: int) -> float:
	match _shape:
		1:
			var u := clampf(float(k) / maxf(1.0, float(length)), 0.0, 1.0)
			var sn := sin(PI * u)
			return sn * sn
		2:
			return 1.0
	var t := float(k) / rate
	var lvl: float
	var th := minf(t, _hold)
	if th < _a:
		# A rounded attack: pads bloom, they do not ramp.
		var u := th / _a
		lvl = u * u * (3.0 - 2.0 * u)
	else:
		lvl = _s + (1.0 - _s) * exp(-4.6 * (th - _a) / _d)
	if t > _hold:
		lvl *= exp(-LN_1000 * (t - _hold) / _r)
	return lvl


## TPT state-variable filter coefficients [a1, a2, a3, k] for a cutoff and Q.
static func svf(sample_rate: int, hz: float, q: float) -> PackedFloat64Array:
	var g := tan(PI * clampf(hz, 10.0, sample_rate * 0.45) / sample_rate)
	var k := 1.0 / maxf(0.3, q)
	var a1 := 1.0 / (1.0 + g * (g + k))
	var a2 := g * a1
	return PackedFloat64Array([a1, a2, g * a2, k])


## A deterministic 32-bit LCG step (no overflow in 64-bit ints, identical on
## every platform): noise that any copy of a voice repeats exactly.
static func lcg(x: int) -> int:
	return (x * 1664525 + 1013904223) & 0xFFFFFFFF


## For a held voice, the nearest rate making whole cycles over its loop
## (`period` frames); any rate for a note.
func snap(hz: float, p: Dictionary) -> float:
	var period := int(p.get("period", 0))
	if not held or period <= 0 or hz <= 0.0:
		return hz
	return maxf(1.0, roundf(hz * period / rate)) * rate / period


static func midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)
