extends TestCase
## `darker` (10_sky.tour_seen) answers on a FALL of the composed picture. Its first
## ask had nothing to compare with and answered yes for any hour at all, so a
## walk's first step was never proven. The first ask compares against the light
## before the clock was last set.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_first_ask_after_the_clock_is_set_must_really_be_darker() -> void:
	# A tour's game: the baseline is kept only while a tour runs.
	var g := Sx.game(tree, ["--seed=1", "--size=128", "--hour=17", "--weather=clear:0", "--tour=tours/none.tour"])
	await process_frames(3)
	var sky := Sx.system(g, "10_sky")
	# Set the clock BACK a little, to earlier and brighter: no fall at all.
	g.clock.skip(-0.5 * 60.0)
	await process_frames(3)
	check(not bool(sky.call("tour_seen", &"darker")), "an earlier, brighter hour is not darker")
	# Then on into the evening: that IS a fall.
	g.clock.skip(3.0 * 60.0)
	await process_frames(3)
	check(bool(sky.call("tour_seen", &"darker")), "the evening, after, is darker")
	Sx.end(g)
