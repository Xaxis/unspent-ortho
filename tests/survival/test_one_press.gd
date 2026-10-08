extends TestCase
## ONE PRESS, ONE OWNER (Survival.ask_pending). `use` is one key that several
## systems answer, each reading it in its own `_process`, and the seam has
## broken three ways: a cache opened over a faced talk, a press swallowed, and a
## cache opened on the press a fire was asked for. An ask's next press is the
## ask's, so every system that reads the key leaves that press be while one is
## out, and names in the hint row what its press would do. Found by what each
## script reads, never by a list: a new system that answers `use` is red here
## until it defers and names its press. The press itself is played in
## tests/landmarks/test_in_game.gd (a fire asked for beside a cache).

const DIR := "res://src/systems"
## The system that answers the ask.
const OWNER := "50_survival.gd"
## The words' system's number (49_story): systems load and answer in name order.
const WORDS_AT := 49


func test_every_system_that_answers_use_leaves_an_asks_press_alone() -> void:
	var reads := RegEx.create_from_string("(is_action_(just_)?pressed|Keys\\.down)\\(&?\"use\"\\)")
	var found := 0
	for f: String in DirAccess.get_files_at(DIR):
		if not f.ends_with(".gd") or f == OWNER:
			continue
		var src := FileAccess.get_file_as_string("%s/%s" % [DIR, f])
		if reads.search(src) == null:
			continue
		found += 1
		check(src.contains("Survival.ask_pending(game)"), "%s answers `use`, so it leaves an ask's press alone (Survival.ask_pending)" % f)
		# And the hint row names what the press does (UiLink.use_hint asks every
		# system's `use_line` before Survival's own words): the row said
		# "campfire - build?" over a cache the press opened.
		check(src.contains("func use_line() -> String:"), "%s answers `use`, so it names what the press does (use_line)" % f)
	gt(float(found), 6.5, "the systems that answer `use` were found by what they read (%d)" % found)


## THE PRESS GOES TO WHAT HE FACES (Survival.words_in_front). The words answer
## `use` in 49_story, and every system that reads the key before them would take
## a press meant for a person or a page in front of him: a cache took Otto's, and
## the gate home took June's and crossed him back to 2098. So each one that runs
## before the words leaves that press be. A thing he presses at his hand (a works
## housing, a road's barrier) keeps it only against words farther off than it is
## (Survival.words_nearer_than): a survey stake behind a quarry's housing took
## every press meant for the housing (#67). A system after them (50_survival) is
## left the press only when the words did not spend it (49_story `use_spent`).
## Found by what each script reads, as above.
func test_every_system_before_the_words_leaves_a_faced_press_to_them() -> void:
	var reads := RegEx.create_from_string("(is_action_(just_)?pressed|Keys\\.down)\\(&?\"use\"\\)")
	var found := 0
	for f: String in DirAccess.get_files_at(DIR):
		if not f.ends_with(".gd") or f.left(2).to_int() >= WORDS_AT:
			continue
		var src := FileAccess.get_file_as_string("%s/%s" % [DIR, f])
		if reads.search(src) == null:
			continue
		found += 1
		check(src.contains("Survival.words_in_front(game)") or src.contains("Survival.words_nearer_than(game, "),
			"%s answers `use` before the words, so it leaves a faced press to them (Survival.words_in_front, or words_nearer_than its own thing)" % f)
	gt(float(found), 5.5, "the systems that answer `use` before the words were found by what they read (%d)" % found)

