extends TestCase
## A TOUR RUN BARE BOOTS WHAT ITS HEADER SAYS (tools/tour.sh, tools/_tour_args.sh).
## A tour is written for the seed, hour and weather its header names; run with
## none, it booted seed 1 at 08:00 and failed on a world it was never staged in --
## twice, in the assembly gate. These ask the real shell function, through bash,
## what it takes from real tours' headers.


func _args(tour: String) -> PackedStringArray:
	var out: Array = []
	var cmd := ". tools/_tour_args.sh && tour_header_args %s" % tour
	var code := OS.execute("bash", PackedStringArray(["-c", "cd '%s' && %s" % [ProjectSettings.globalize_path("res://"), cmd]]), out, true)
	eq(code, 0, "the shell function runs for %s" % tour)
	var got := PackedStringArray()
	for line: String in String(out[0] if not out.is_empty() else "").split("\n", false):
		got.append(line.strip_edges())
	return got


func test_a_plain_header_gives_its_options() -> void:
	var got := _args("tours/bunker.tour")
	check(got.has("--seed=4") and got.has("--hour=15") and got.has("--weather=clear:0"),
		"bunker's header runs it on seed 4 at three in the afternoon (%s)" % [got])


func test_a_header_carried_onto_the_next_line_gives_all_of_them() -> void:
	var got := _args("tours/defences.tour")
	check(got.has("--seed=1"), "the first line's options (%s)" % [got])
	var gave := false
	var held := false
	for a: String in got:
		gave = gave or a.begins_with("--give=")
		held = held or a.begins_with("--holding=")
	check(held and gave, "and the lines it runs on to")
	eq(got.size(), 5, "each once")


func test_what_is_not_a_boot_option_is_left_out() -> void:
	# An environment prefix, and a note in brackets after the options.
	var step := _args("tours/colossi_step.tour")
	check(step.has("--seed=7") and not ("TOUR_TIMEOUT=400" in step), "TOUR_TIMEOUT is the shell's, not the game's (%s)" % [step])
	var canon := _args("tours/canon.tour")
	eq(canon, PackedStringArray(["--seed=7"]), "a note after the options is not one")


func test_only_the_first_run_a_header_names_is_taken() -> void:
	# colossi_step's header shows two runs; the first is the one.
	var got := _args("tours/colossi_step.tour")
	check(got.has("--view=shoulder") and not got.has("--eye=1.7,-8"), "the first run's options, not the second's (%s)" % [got])
