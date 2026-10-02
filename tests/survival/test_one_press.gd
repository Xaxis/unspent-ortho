extends TestCase
## ONE PRESS, ONE OWNER (Survival.ask_pending). `use` is one key that several
## systems answer, each reading it in its own `_process`, and the seam has
## broken three ways: a cache opened over a faced talk, a press swallowed, and a
## cache opened on the press a fire was asked for. An ask's next press is the
## ask's, so every system that reads the key leaves that press be while one is
## out. Found by what each script reads, never by a list: a new system that
## answers `use` is red here until it defers. The press itself is played in
## tests/landmarks/test_in_game.gd (a fire asked for beside a cache).

const DIR := "res://src/systems"
## The system that answers the ask.
const OWNER := "50_survival.gd"


func test_every_system_that_answers_use_leaves_an_asks_press_alone() -> void:
	var reads := RegEx.create_from_string("is_action_(just_)?pressed\\(&?\"use\"\\)")
	var found := 0
	for f: String in DirAccess.get_files_at(DIR):
		if not f.ends_with(".gd") or f == OWNER:
			continue
		var src := FileAccess.get_file_as_string("%s/%s" % [DIR, f])
		if reads.search(src) == null:
			continue
		found += 1
		check(src.contains("Survival.ask_pending(game)"), "%s answers `use`, so it leaves an ask's press alone (Survival.ask_pending)" % f)
	gt(float(found), 6.5, "the systems that answer `use` were found by what they read (%d)" % found)
