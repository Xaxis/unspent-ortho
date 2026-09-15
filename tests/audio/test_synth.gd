extends TestCase
## The synth's promises: the same seed is the same sound, filters do what they
## say, periodic buffers stay periodic, and baked streams are 16-bit mono loops.

const Fixture := preload("res://tests/audio/audio_fixture.gd")


func test_noise_is_the_same_for_a_seed_and_different_for_another() -> void:
	var a := Synth.noise(2000, 7)
	var b := Synth.noise(2000, 7)
	var c := Synth.noise(2000, 8)
	check(a == b, "same seed, same noise")
	check(a != c, "another seed, other noise")


func test_rendering_a_sound_twice_gives_identical_samples() -> void:
	for key: StringName in [&"hit_plate:1", &"step_gravel:2", &"moss_drip:3", &"machine_runner"]:
		var a := SoundBank.render(key)
		var b := Fixture.baked(key) if key == &"machine_runner" else SoundBank.render(key)
		check(a.samples == b.samples, "%s differs between renders" % key)
		near(a.gain_db, b.gain_db, 1e-6, "%s gain" % key)


func test_variants_are_different_takes() -> void:
	var a := SoundBank.render(&"step_stone:0")
	var b := SoundBank.render(&"step_stone:1")
	check(a.samples != b.samples, "two footfall variants should not be one sample")


func test_lowpass_keeps_the_low_and_removes_the_high() -> void:
	var rate := 44100
	var lo := Synth.buffer(8192)
	Synth.add_sine(lo, rate, 200.0, 0.5)
	var hi := Synth.buffer(8192)
	Synth.add_sine(hi, rate, 6000.0, 0.5)
	Synth.lowpass4(lo, rate, 1000.0)
	Synth.lowpass4(hi, rate, 1000.0)
	gt(Synth.tone_level(lo, rate, 200.0, 2048, 6144), 0.4, "200 Hz passes")
	lt(Synth.tone_level(hi, rate, 6000.0, 2048, 6144), 0.005, "6 kHz is gone")


func test_highpass_removes_what_a_laptop_cannot_play() -> void:
	var rate := 22050
	var b := Synth.buffer(22050)
	Synth.add_sine(b, rate, 60.0, 0.5)
	Synth.add_sine(b, rate, 800.0, 0.5)
	Synth.highpass4(b, rate, 110.0)
	lt(Synth.low_energy_ratio(b, rate, 120.0), 0.02, "60 Hz carried weight")


func test_periodic_filtering_matches_a_buffer_that_really_repeated() -> void:
	var rate := 22050
	var x := Synth.noise(11025, 3)
	var looped := x.duplicate()
	Synth.band(looped, rate, 300.0, 3000.0, true)
	# The same noise played twice through a fresh filter: its second copy is
	# what a loop sounds like once it is running.
	var twice := x.duplicate()
	twice.append_array(x)
	Synth.band(twice, rate, 300.0, 3000.0, false)
	var worst := 0.0
	for i in x.size():
		worst = maxf(worst, absf(looped[i] - twice[x.size() + i]))
	lt(worst, 1e-3, "periodic filter state at the seam")


func test_tiled_partials_equal_the_long_way() -> void:
	var rate := 44100
	var n := 88200
	var fast := Synth.buffer(n)
	Synth.add_partials(fast, rate, PackedFloat32Array([137.5, 275.0, 1063.0]), PackedFloat32Array([0.3, 0.2, 0.1]))
	var slow := Synth.buffer(n)
	Synth.add_sine(slow, rate, 137.5, 0.3)
	Synth.add_sine(slow, rate, 275.0, 0.2)
	Synth.add_sine(slow, rate, 1063.0, 0.1)
	var worst := 0.0
	for i in n:
		worst = maxf(worst, absf(fast[i] - slow[i]))
	lt(worst, 1e-4, "tiling changed the waveform")


func test_pluck_rings_at_its_pitch() -> void:
	var rate := 44100
	var b := Synth.pluck(rate, 220.0, 0.6, 5, 0.5, 1.0)
	var on := Synth.tone_level(b, rate, 220.0, 2000, 16384)
	var off := Synth.tone_level(b, rate, 247.0, 2000, 16384)
	gt(on, off * 8.0, "pluck at 220 Hz (on %.4f, off %.4f)" % [on, off])


func test_events_laid_past_the_end_wrap_to_the_start() -> void:
	var dst := Synth.buffer(10)
	var ev := PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	Synth.add(dst, ev, 8, 1.0, true)
	eq(dst[8], 1.0, "at 8")
	eq(dst[9], 2.0, "at 9")
	eq(dst[0], 3.0, "wrapped to 0")
	eq(dst[1], 4.0, "wrapped to 1")


func test_a_baked_stream_is_16_bit_mono_and_loops_its_whole_length() -> void:
	var b := Synth.buffer(4410)
	Synth.add_sine(b, 44100, 441.0, 0.5)
	var s := Synth.to_wav(b, 44100, true)
	eq(s.format, AudioStreamWAV.FORMAT_16_BITS, "format")
	eq(s.stereo, false, "mono")
	eq(s.mix_rate, 44100, "rate")
	eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loops")
	eq(s.loop_end, 4410, "loop end is the last sample")
	eq(s.data.size(), 8820, "two bytes a sample")
	var one := Synth.to_wav(b, 22050, false)
	eq(one.loop_mode, AudioStreamWAV.LOOP_DISABLED, "one-shots do not loop")


func test_the_limiter_turns_a_transient_down_and_leaves_the_rest() -> void:
	var rate := 44100
	var buf := Synth.buffer(rate / 2)
	Synth.add_sine(buf, rate, 440.0, 0.2)
	var spike := Synth.modes(rate, 0.01, PackedFloat32Array([3000.0]), PackedFloat32Array([1.0]), PackedFloat32Array([0.004]))
	Synth.add(buf, spike, rate / 4, 0.9)
	var before := buf.duplicate()
	var over := Synth.limit(buf, rate, 0.4, 0.0015, 0.006)
	gt(float(over), 0.0, "the spike was over")
	check(Synth.peak(buf) <= 0.4 + 1e-6, "nothing over the ceiling (%.3f)" % Synth.peak(buf))
	var far := rate / 8
	near(buf[far], before[far], 1e-6, "far from the spike, untouched")
	near(Synth.rms(buf, 0, rate / 5), Synth.rms(before, 0, rate / 5), 1e-6, "the body before it is the same")
	# A loop limited round its seam stays a loop.
	var loop := Synth.buffer(44100)
	Synth.add_sine(loop, rate, 441.0, 0.3)
	Synth.add(loop, spike, loop.size() - 100, 0.9, true)
	Synth.limit(loop, rate, 0.35, 0.0015, 0.05, true)
	lt(Synth.seam_ratio(loop), 1.5, "seamless after limiting")
	check(Synth.peak(loop) <= 0.35 + 1e-6, "the wrapped spike is under too")
