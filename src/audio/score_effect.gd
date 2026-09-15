class_name ScoreEffect
extends RefCounted
## A stem's effect, streamed like its voices: process() takes the next block of
## the stem in place and keeps its delay lines and filter states, so a stem stops
## and resumes between any two blocks with the same samples.
##
## Loops: an effect's LFOs read absolute stem time and are snapped to whole
## cycles over the loop (snap_hz), and the stem renders a pre-roll first, so the
## sample after the last is the first (ScoreRender).

var rate := 22050
var stereo := true
## Loop length in samples, 0 for a one-shot.
var period := 0


func setup(p: Dictionary, sample_rate: int, is_stereo: bool, loop_frames: int) -> void:
	rate = sample_rate
	stereo = is_stereo
	period = loop_frames
	_init_fx(p)


func _init_fx(_p: Dictionary) -> void:
	pass


## Processes n samples of l (and r) in place; t0 is the absolute stem sample of index 0.
func process(_l: PackedFloat32Array, _r: PackedFloat32Array, _n: int, _t0: int) -> void:
	pass


## The nearest rate that makes whole cycles over the loop (any rate for one-shots).
func snap_hz(hz: float) -> float:
	if period <= 0 or hz <= 0.0:
		return hz
	var cycles := maxf(1.0, roundf(hz * period / rate))
	return cycles * rate / period


## Seconds this effect keeps ringing after its input stops (to -60 dB).
func memory() -> float:
	return 0.0
