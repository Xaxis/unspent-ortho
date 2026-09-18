extends TestCase
## A note in the key strip never draws through the key hints.
##
## tests/save/test_problem_fits.gd holds the ten sentences SaveSlots.problem()
## writes to the room the title's narrow slate leaves them. That is the right
## rule for that file, but it only covers the notes ONE package writes: the
## saves package asked, in its report, for the clip to be made general, because
## UiSlate.keys laid the hints left to right and the note right-aligned from the
## far edge with nothing between them checking they did not meet. Any package
## could put a long note on the title and letter it over "e choose" again.
##
## So the clip lives in UiSlate.keys, and this holds UiSlate.keys itself: given
## a strip of hints and a note too long for what is left, what comes back fits.

const LONG := "That game was made on another island and this build cannot open it at all."


## The pixels left for a right-aligned note once the hints have had theirs.
##
## ASKED FOR, NOT LAID OUT AGAIN. This used to be its own copy of UiSlate.keys's
## walk, and when the base moved from 640x360 to 1920x1080 the copy stayed where
## it was: the cap floor was 9 against the strip's 18, the gap after a cap 4
## against 8, the gap after a hint 12 against 24 — every constant exactly half,
## the TYPE factor. It therefore reported about 25 px A PAIR more room than the
## strip has, so a note that clipped on the glass fitted in the test, which is
## the one thing this file exists to catch.
func room_on(device: Rect2i, pairs: Array) -> int:
	return UiSlate.keys_room(pairs, device)


func test_a_note_too_long_for_its_strip_is_cut_to_fit() -> void:
	for room: int in [40, 80, 120, 200, 400]:
		var out := UiSlate.elided(LONG, room)
		check(UiFont.width(out) <= room,
			"a note cut for %d px fits in %d px (got %d)" % [room, room, UiFont.width(out)])


func test_a_note_that_already_fits_is_left_exactly_alone() -> void:
	var short := "Slot 1 is from another island."
	eq(UiSlate.elided(short, UiFont.width(short)), short, "an exact fit is not cut")
	eq(UiSlate.elided(short, UiFont.width(short) + 40), short, "and neither is a note with room to spare")


func test_a_strip_with_no_room_says_nothing_rather_than_a_stub() -> void:
	eq(UiSlate.elided(LONG, 12), "", "twelve pixels cannot carry a word and an ellipsis")
	eq(UiSlate.elided(LONG, 0), "", "and neither can none")


func test_what_is_cut_says_it_was_cut() -> void:
	var out := UiSlate.elided(LONG, 120)
	check(out.ends_with("..."), "a cut note ends in an ellipsis, so nobody reads a half sentence as the whole one")
	check(LONG.begins_with(out.trim_suffix("...").strip_edges()),
		"and what is left is the front of the sentence, not a rewrite of it")


## The title is the narrow case the saves package measured, and the one a
## returning player meets first.
func test_the_titles_own_strip_clears_its_own_hints() -> void:
	var room := room_on(UiTitleMenu.DEVICE, UiTitleMenu.KEY_HINTS)
	gt(float(room), 0.0, "the title's hints leave room for a note at all")
	for code: StringName in [&"missing", &"newer", &"older", &"elsewhere", &"damaged", &"nonsense"]:
		var note := SaveSlots.problem(0, code)
		if note == "":
			continue
		var out := UiSlate.elided(note, room)
		check(UiFont.width(out) <= room,
			"'%s' fits the title's strip (%d px of room)" % [code, room])


## A single word longer than the whole strip still has to come back short: the
## word-at-a-time path must not fall through and return the word whole.
func test_one_unbroken_word_is_still_cut() -> void:
	var word := "ANTIDISESTABLISHMENTARIANISM"
	var out := UiSlate.elided(word, 60)
	check(UiFont.width(out) <= 60, "an unbreakable word is taken back a letter at a time")
	check(out != word, "and is not handed back whole")
