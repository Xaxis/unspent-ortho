extends TestCase
## The glide over the shoulder never finishes in one frame (src/core/view/shoulder.gd).
##
## It advanced by the frame's whole delta, so one long frame -- a load spike, a
## stall anywhere else in the frame -- carried the camera from the land to over
## the shoulder with nothing in between: the pop the glide exists to prevent.
## A step is capped at a frame of 30 Hz, so the glide keeps real time at any
## frame rate a player plays at and only runs slow through a frame that long.

const Shoulder := preload("res://src/core/view/shoulder.gd")


func test_one_long_frame_moves_the_glide_one_step() -> void:
	var t := Shoulder.blend_step(0.0, true, 0.5)
	gt(t, 0.0, "a long frame still moves the glide")
	lt(t, 0.2, "and never carries it to the end: %.2f of the way" % t)
	var back := Shoulder.blend_step(1.0, false, 2.0)
	gt(back, 0.8, "nor back up again in one: %.2f" % back)


func test_the_glide_keeps_real_time_at_a_played_frame_rate() -> void:
	for hz: float in [30.0, 60.0, 120.0, 144.0]:
		var t := 0.0
		var secs := 0.0
		while t < 1.0 and secs < 5.0:
			t = Shoulder.blend_step(t, true, 1.0 / hz)
			secs += 1.0 / hz
		lt(absf(secs - Shoulder.BLEND_SECS), 1.5 / hz,
			"at %d Hz the glide takes %.3f s, not BLEND_SECS %.2f" % [int(hz), secs, Shoulder.BLEND_SECS])
