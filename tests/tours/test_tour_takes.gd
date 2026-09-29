extends TestCase
## `await took` and `await made` ANSWER FOR WHAT ARRIVED, not that a step
## finished. home-coast.tour's `near mussel_rock; press use; await took` passed on
## a take of the driftwood beside the rock, and the next frame claimed a fed man
## who had eaten nothing. `took:ITEM` / `made:ITEM` answer only when that item
## came in, and neither form answers on a count of nothing.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_take_answers_for_the_item_that_came_in() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11"])
	await frames(2)
	var tour := Sx.system(g, "98_tour")
	# A game booted without --tour never starts the runner; listen as a tour does.
	tour.call(&"_listen")
	Events.took.emit(&"driftwood", 2)
	check(tour.call(&"_answered", "took"), "something was taken")
	check(tour.call(&"_answered", "took:driftwood"), "and it was driftwood")
	check(not tour.call(&"_answered", "took:mussels"), "which is not mussels")
	Events.took.emit(&"mussels", 1)
	check(tour.call(&"_answered", "took:mussels"), "mussels, once they come in")
	Events.made.emit(&"charcoal", 2)
	check(tour.call(&"_answered", "made:charcoal"), "a make answers for what it made")
	check(not tour.call(&"_answered", "made:haft"), "and not for another thing")
	Sx.end(g)
	await frames(1)


func test_nothing_taken_answers_nothing() -> void:
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11"])
	await frames(2)
	var tour := Sx.system(g, "98_tour")
	# A game booted without --tour never starts the runner; listen as a tour does.
	tour.call(&"_listen")
	Events.took.emit(&"mussels", 0)
	Events.made.emit(&"charcoal", 0)
	check(not tour.call(&"_answered", "took"), "a take of nothing is not a take")
	check(not tour.call(&"_answered", "took:mussels"), "not of mussels either")
	check(not tour.call(&"_answered", "made"), "nor a make of nothing a make")
	Sx.end(g)
	await frames(1)
