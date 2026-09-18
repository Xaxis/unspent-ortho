extends TestCase
## THE LOOP, and this file exists because a chapter with three demands and no
## pressure is a checklist (docs/VISION.md §10).
##
## What is held here is the arithmetic of the game the demands are supposed to
## make: a region turns against you AS you work it, and the only thing that ends
## that is the very work you had to equip yourself for. Every number is read off
## the shipped constants, so retuning either side fails here rather than quietly
## flattening the loop into a list of errands.


func test_working_a_region_out_turns_it_against_you() -> void:
	var each: float = Interference.CAUSES.get(&"quarried", 0.0)
	gt(each, 0.0, "stripping a region is a cause the plan files")
	lt(each, Interference.CAUSES[&"theft"], "and a seam is a smaller thing than hands on the plan's own works")
	# A chapter asks for at most MINE_MOST seams; that much work has to MOVE the
	# network, or mining is free and the place never notices a landscape going.
	var whole := each * float(Chapter.MINE_MOST)
	var wary: float = Interference.THRESHOLDS[1]
	var hostile: float = Interference.THRESHOLDS[2]
	gt(whole, wary, "mining out what a chapter asks for carries a calm region past wary (%.2f)" % whole)
	lt(whole, hostile, "but never to hostile on its own: a seam is not a blow (%.2f)" % whole)


func test_answering_the_chapter_is_what_ends_the_pressure() -> void:
	# DEFENDED is the keeper down or the yard dark, and both already tell
	# `Interference.lose` that nothing is running the plan here. That is the
	# payoff, and it is what makes the danger you built while mining worth
	# walking into rather than avoiding.
	lt(Interference.LOST_CEILING, Interference.THRESHOLDS[2],
		"a region the plan has lost can never reach hostile again")
	gt(Interference.LOST_DECAY, 1.0, "and what is left of its file cools faster than an ordinary one")
	# The half that makes it a CHOICE rather than a chore: there is more than one
	# way to take a keeper, and the chapter counts any of them.
	gt(float(SentinelWay.KIND_NAMES.size()), 2.0, "a keeper can be taken more than one way: %s" % [SentinelWay.KIND_NAMES])


func test_the_demands_cannot_be_answered_by_standing_still() -> void:
	# Each demand is work in a different direction — crossing, digging, fighting —
	# so a player who is good at one still has to do the others. A chapter that
	# could be finished by repeating the cheapest of the three would be a grind
	# with a story bolted on.
	gt(Chapter.EXPLORE_SHARE, 0.5, "most of what is worth the walk has to be found")
	gt(Chapter.MINE_LEAST, 1, "one seam is never a landscape worked")
	gt(Chapter.MINE_MOST, Chapter.MINE_LEAST, "and a big region asks more of you than a small one")
