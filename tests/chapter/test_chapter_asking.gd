extends TestCase
## What the slate says a place is still asking (docs/VISION.md, task #112
## step 4). `Chapter.read` has always known; until now nothing could say it, and
## no UI read the file at all.
##
## EVERY BRANCH IS REACHED FROM A STATE `Chapter.read` CAN REALLY PRODUCE, which
## is the point of the last test here: the first draft of `asking` ended in a
## branch that could never run, because `keeper_down` implies `defended` implies
## (with the other two) `answered`, which returns three branches earlier. A line
## nobody can reach is the same bug as a face nobody can see.


## A read dictionary in the shape `Chapter.read` returns, with the three demands
## set by hand. Staged rather than grown, so each state is exactly itself.
func _read(explored: bool, mined: bool, keeper_down: bool, yard_broken: bool) -> Dictionary:
	var defended := keeper_down or yard_broken
	return {
		"region": 1,
		"explored": explored, "seen": 0, "landmarks": 3, "want_seen": 2,
		"mined": mined, "taken": 0, "ore": 10, "want_ore": 4,
		"defended": defended, "keeper_down": keeper_down, "yard_broken": yard_broken,
		"answered": explored and mined and defended,
	}


func test_a_place_says_the_nearest_thing_it_is_still_asking() -> void:
	eq(Chapter.asking(_read(false, false, false, false)),
		"Sections of this file have never been walked.", "unwalked comes first")
	eq(Chapter.asking(_read(true, false, false, false)),
		"The seams here are still being worked.", "then what is still in the ground")
	eq(Chapter.asking(_read(true, true, false, false)),
		"The plan still works this place.", "then what is standing over it")


func test_an_answered_place_says_the_plan_has_lost_it() -> void:
	eq(Chapter.asking(_read(true, true, true, false)),
		"Nothing here is on the plan's books any more.", "the keeper route closes it")
	eq(Chapter.asking(_read(true, true, false, true)),
		"Nothing here is on the plan's books any more.", "and so does the yard route")


func test_it_says_nothing_about_a_place_it_has_no_file_on() -> void:
	eq(Chapter.asking({}), "", "no chapter, no line")
	eq(Chapter.asking({"explored": true}), "", "a dictionary that is not a chapter read")


## NEVER A CHECKLIST WITH A PERCENTAGE (VISION §10). The read carries counts —
## seen, want_seen, taken, want_ore — and none of them may reach the glass.
func test_no_line_leaks_a_count_onto_the_glass() -> void:
	for st: Array in [[false, false, false, false], [true, false, false, false],
			[true, true, false, false], [true, true, true, false]]:
		var line := Chapter.asking(_read(bool(st[0]), bool(st[1]), bool(st[2]), bool(st[3])))
		check(not line.is_empty(), "every real state says something")
		for ch in line:
			check(not (ch as String).is_valid_int(), "'%s' puts a number on the glass" % line)
		check(not line.contains("%"), "'%s' puts a percentage on the glass" % line)


## Every branch is reachable from a state the rules can really be in, so none of
## them is dead. Four distinct lines out of the states above, and the answered
## one is shared by both routes on purpose.
func test_every_line_is_reachable_and_they_are_distinct() -> void:
	var seen := {}
	for explored: bool in [false, true]:
		for mined: bool in [false, true]:
			for keeper: bool in [false, true]:
				for yard: bool in [false, true]:
					var line := Chapter.asking(_read(explored, mined, keeper, yard))
					if not line.is_empty():
						seen[line] = int(seen.get(line, 0)) + 1
	eq(seen.size(), 4, "four distinct things a place can be saying, and no dead branch")
