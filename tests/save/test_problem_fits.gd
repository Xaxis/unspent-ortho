extends TestCase
## A save's one-line problem has to FIT where it is said.
##
## UiSlate.keys draws the key hints left to right and the note right-aligned at
## the other end, and nothing between them checks they do not meet. On the big
## page slate they never do; on the title's small one (UiTitleMenu.DEVICE, 276 px
## of glass) a long sentence is drawn straight THROUGH the key hint, so a player
## who opens the game after an update read "e chooseThe autosave was made on
## another island." Four of these sentences were already over that line before
## the stamp added a fifth:
##
##   newer      slot 0  284 px  over by 84      older  slot 0  262 px  over by 62
##   damaged    slot 0  227 px  over by 27      elsewhere slot 0  208 px  over by 8
##
## So the rule is here, on the file that writes the sentences, rather than left
## to whoever next makes one longer. The whole reason is SaveFile.WHY_*, said on
## the saves app's own page, which has the room for it.

## The title's slate is the narrowest place a note is said.
const TITLE_DEVICE := Rect2i(166, 158, 308, 188)
## The key strip the title draws under its menu.
const TITLE_KEYS: Array = [["e", "choose"]]

const CODES: Array[StringName] = [&"missing", &"newer", &"older", &"elsewhere", &"damaged", &"nonsense"]


## The pixels left for a right-aligned note once the key hints have had theirs,
## worked out the way UiSlate.keys lays them out.
func room_on(device: Rect2i, pairs: Array) -> int:
	var g := UiSlate.glass_of(device)
	var x := g.position.x + UiSlate.MARGIN_L
	for p: Array in pairs:
		x += maxi(9, UiFont.width(p[0] as String) + 6) + 4
		x += UiFont.width(p[1] as String) + 12
	# The 12 above is the gap after the last hint; a note may start there.
	return (g.end.x - UiSlate.MARGIN_R) - x


func test_every_problem_a_slot_can_have_fits_the_title_key_strip() -> void:
	var room := room_on(TITLE_DEVICE, TITLE_KEYS)
	gt(float(room), 100.0, "the title leaves a note somewhere to go (%d px)" % room)
	for code: StringName in CODES:
		for slot: int in range(SaveSlots.COUNT):
			var s := SaveSlots.problem(slot, code)
			var w := UiFont.width(s)
			check(w <= room, "%d px in %d: \"%s\" (%s, slot %d)" % [w, room, s, code, slot])


func test_the_short_form_fits_a_slot_row_beside_its_name() -> void:
	# The row shows "slot 2" and under it the short form; it may not run into the
	# played-time on the right of the same row.
	for code: StringName in CODES:
		var s := SaveSlots.short_problem(code)
		lt(float(UiFont.width(s)), 90.0, "short form \"%s\" (%s)" % [s, code])
		check(not s.ends_with("."), "the short form is a label, not a sentence: \"%s\"" % s)


func test_every_code_says_something_and_never_the_same_thing_twice() -> void:
	var seen := {}
	for code: StringName in CODES:
		var s := SaveSlots.problem(1, code)
		check(s != "", "%s says something" % code)
		check(s.ends_with("."), "%s is a whole sentence: \"%s\"" % [code, s])
		if code != &"nonsense":
			check(not seen.has(s), "%s says something of its own: \"%s\"" % [code, s])
			seen[s] = true
	# An unknown code falls back to the same line as a damaged one, on purpose:
	# a save this build cannot account for is one it cannot read.
	eq(SaveSlots.problem(1, &"nonsense"), SaveSlots.problem(1, &"damaged"))


func test_the_autosave_is_named_as_itself_and_a_slot_by_its_number() -> void:
	for code: StringName in CODES:
		check(SaveSlots.problem(SaveSlots.AUTO, code).begins_with("The autosave"),
			"the autosave is called the autosave (%s)" % code)
		for slot: int in SaveSlots.MANUAL:
			check(SaveSlots.problem(slot, code).begins_with("Slot %d" % slot),
				"slot %d is called by its number (%s)" % [slot, code])


func test_the_whole_reason_is_longer_than_the_line_and_lives_on_the_page() -> void:
	# The point of the short line is that the long one exists: the strip says
	# which slot, the page says why. If they ever became the same sentence the
	# page would be wasted and the strip would overrun again.
	var pairs := [[&"elsewhere", SaveFile.WHY_ELSEWHERE], [&"damaged", SaveFile.WHY_DAMAGED],
		[&"newer", SaveFile.WHY_NEWER], [&"older", SaveFile.WHY_OLDER], [&"missing", SaveFile.WHY_MISSING]]
	for p: Array in pairs:
		var code: StringName = p[0]
		var why: String = p[1]
		check(why != SaveSlots.problem(1, code), "%s: the page says more than the strip" % code)
	gt(float(SaveFile.WHY_ELSEWHERE.length()), 100.0, "the island reason is said in full somewhere")
