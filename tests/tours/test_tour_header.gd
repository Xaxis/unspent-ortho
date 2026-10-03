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


func _env(tour: String) -> PackedStringArray:
	var out: Array = []
	var cmd := ". tools/_tour_args.sh && tour_header_env %s" % tour
	var code := OS.execute("bash", PackedStringArray(["-c", "cd '%s' && %s" % [ProjectSettings.globalize_path("res://"), cmd]]), out, true)
	eq(code, 0, "the shell function runs for %s" % tour)
	var got := PackedStringArray()
	for line: String in String(out[0] if not out.is_empty() else "").split("\n", false):
		got.append(line.strip_edges())
	return got


## THE HEADER'S CLOCK IS THE RUN'S CLOCK. home-coast.tour was cut off at frame 14
## by the default 180 s because its header's TOUR_TIMEOUT was only a comment:
## tour.sh takes a header's TOUR_TIMEOUT and TOUR_FIXED_FPS when the shell has
## not set them.
func test_a_header_says_how_long_and_at_what_rate() -> void:
	eq(_env("tours/colossi_step.tour"), PackedStringArray(["TOUR_TIMEOUT=400"]), "colossi_step's header gives it 400 s")
	var home := _env("tours/home-coast.tour")
	check(home.has("TOUR_FIXED_FPS=60") and home.has("TOUR_TIMEOUT=600"), "home-coast runs at 60 fixed and gets ten minutes (%s)" % [home])
	eq(_env("tours/bunker.tour"), PackedStringArray(), "a header with no prefix says nothing")


## EVERY TOUR'S HEADER BOOTS. main.gd refuses options it cannot read
## (BootOptions.problems), so a header naming what is not there fails the run
## instead of staging half of it: carried_home's `--holding=hearth,lean_to` stood
## its hearth and dropped the lean-to (`lean-to` is the piece's name) with only
## a warning in the log.
func test_every_tour_header_boots() -> void:
	eq(BootOptions.parse(PackedStringArray(["--holding=hearth,lean_to"])).problems.size(), 1, "a piece nobody can build is a problem")
	eq(BootOptions.parse(PackedStringArray(["--holding=lean-to,radio_mast"])).problems.size(), 0, "a piece's own name, underscores for spaces, is not")
	for f: String in DirAccess.get_files_at("res://tours"):
		if not f.ends_with(".tour"):
			continue
		var problems := BootOptions.parse(_args("tours/" + f)).problems
		check(problems.is_empty(), "tours/%s boots its header: %s" % [f, "; ".join(problems)])


## A COPY KEEPS ITS ORIGINAL'S HEADER. Run under its own name it would take none
## of those options and boot bare, which reads as the tour failing, so tour.sh
## refuses a tour whose header runs other tours and never itself
## (tour_header_others). Three copies of june.tour, run twice-wide to catch a
## flake, failed at line 35 that way.
func test_a_header_that_runs_only_another_tour_is_told_so() -> void:
	var copy := ProjectSettings.globalize_path("user://june-copy.tour")
	eq(DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tours/june.tour"), copy), OK, "a copy of june.tour is made")
	eq(_others(copy), "tours/june.tour", "the copy is told its header runs june.tour")
	eq(_others("tours/june.tour"), "", "and june.tour itself runs as its header says")
	DirAccess.remove_absolute(copy)


func _others(tour: String) -> String:
	var out: Array = []
	var cmd := ". tools/_tour_args.sh && tour_header_others '%s'" % tour
	var code := OS.execute("bash", PackedStringArray(["-c", "cd '%s' && %s" % [ProjectSettings.globalize_path("res://"), cmd]]), out, true)
	eq(code, 0, "the shell function runs for %s" % tour)
	return String(out[0] if not out.is_empty() else "").strip_edges()

