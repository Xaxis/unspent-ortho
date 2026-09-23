extends TestCase
## The carried-off (docs/VISION.md).
##
## The gap this closes is one sentence long: **the game took people and forgot
## them the same frame.** A snatcher walked out of a yard, `lose_person` took
## somebody off the books, a line was said on the glass, and afterwards there was
## nobody anywhere — so nothing could be written about getting them back, and two
## of §2's eight sub-arc goals had nothing to stand on.


func test_somebody_taken_is_still_somebody_afterwards() -> void:
	var t := Taken.new()
	var who := t.take(41, "", 3, "Oyster Row", 7, 1200.0)
	eq(t.held().size(), 1, "they are still held")
	eq(t.held_in(7).size(), 1, "and the region holding them knows")
	eq(t.held_in(9).size(), 0, "and no other region does")
	check(t.holds_anyone(7), "the cheap question answers")
	# THE FIELD THAT DOES THE WORK. A record that can only say an id forces every
	# caller to invent its own way round, and nobody rescues a number.
	eq(Taken.say(who), "somebody out of Oyster Row", "it can be said out loud")


func test_a_name_is_used_when_anybody_knows_one() -> void:
	var t := Taken.new()
	eq(Taken.say(t.take(1, "Ruth", 3, "Oyster Row", 7, 0.0)), "Ruth", "a named person is named")
	eq(Taken.say(t.take(2, "", 3, "", 7, 0.0)), "somebody", "and nowhere to say is still somebody")
	eq(Taken.say(null), "somebody", "and nothing at all never crashes a line of dialogue")


func test_the_yard_going_dark_is_what_frees_them() -> void:
	# ONE ACT, THREE MEANINGS. Breaking a depot is half of a chapter's DEFENDED,
	# it quiets the region for good, and it is what lets these people out. No new
	# verb, no new place: the yard was always the most important thing in a
	# region and now it is possible to say why.
	var t := Taken.new()
	var _a := t.take(1, "", 3, "Oyster Row", 7, 0.0)
	var _b := t.take(2, "", 3, "Oyster Row", 7, 0.0)
	var _c := t.take(3, "", 4, "Low Scar", 9, 0.0)
	var out := t.free_region(7)
	eq(out.size(), 2, "both of the ones held there walk out")
	eq(t.held_in(7).size(), 0, "and that yard holds nobody")
	eq(t.held_in(9).size(), 1, "while a yard nobody has touched still does")
	eq(t.free_region(7).size(), 0, "breaking it twice frees nobody twice")


func test_the_record_outlives_the_rescue() -> void:
	# A person who was taken and came back is a different person to one who never
	# was, so nothing is ever deleted — the story has to be able to remember it.
	var t := Taken.new()
	var _p := t.take(1, "Ruth", 3, "Oyster Row", 7, 500.0)
	var _f := t.free_region(7)
	eq(t.people.size(), 1, "the record stays")
	check(t.people[0].freed, "and says how it ended")


func test_it_survives_a_save() -> void:
	# Saved outside `WorldStamp` on purpose: somebody being held is never a reason
	# to refuse a player's save.
	var t := Taken.new()
	var _p := t.take(41, "Ruth", 3, "Oyster Row", 7, 1200.0)
	var _q := t.take(42, "", 3, "Oyster Row", 7, 1260.0)
	var _f := t.free_region(7)
	var _r := t.take(43, "", 5, "Tidesend", 2, 1300.0)
	var back := Taken.new()
	back.load_from(JSON.parse_string(JSON.stringify(t.save())))
	eq(back.people.size(), 3, "everybody comes back")
	eq(back.held_in(2).size(), 1, "still held where they were")
	eq(back.held_in(7).size(), 0, "and freed where they were freed")
	eq(Taken.say(back.people[0]), "Ruth", "with what to call them")
