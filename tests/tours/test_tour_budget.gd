extends TestCase
## AN AWAIT'S BUDGET IS RUN OUT BY BOTH CLOCKS (98_tour `budget_left`). A stepped
## run whose world has had only part of its seconds is still waiting, whatever
## the wall says; a free run is held to the wall, as before; work on a thread
## always has at least the wall's budget; and a world that takes no steps at all
## still fails at its own line, at the wall's ceiling.

const Tour := preload("res://src/systems/98_tour.gd")


## home-coast's charcoal on the GPU wrapper: 45 s of wall had passed, and only
## about 21 s of the world's, so the forty minutes on the fire had not.
func test_a_slow_stepped_world_gets_its_own_seconds() -> void:
	check(Tour.budget_left(45_500, 21 * 60, 45.0, 1.0, 60), "21 world seconds of 45: still waiting, though the wall's 45 have passed")
	check(not Tour.budget_left(45_500, 46 * 60, 45.0, 1.0, 60), "and out once the world's 45 have passed too")


func test_a_free_run_keeps_the_walls_budget() -> void:
	check(Tour.budget_left(30_000, 30 * 60, 45.0, 1.0, 60), "30 s of both: still waiting")
	check(not Tour.budget_left(46_000, 46 * 60, 45.0, 1.0, 60), "46 s of both: out")
	check(Tour.budget_left(20_000, 50 * 60, 45.0, 1.0, 60), "a fast stepped world past its 45 in 20 s of wall: a thread still has the wall's")
	check(Tour.budget_left(60_000, 50 * 60, 45.0, 2.0, 60), "slack stretches the wall as before")


## A stalled stepped world (a hang, a wedged raise) takes no steps, so its own
## seconds never pass: it fails at the wall's ceiling, at its own line, not at
## TOUR_TIMEOUT with no line at all.
func test_a_stalled_world_fails_at_the_walls_ceiling() -> void:
	var ceiling := int(45.0 * 1000.0 * Tour.WALL_CEILING)
	check(Tour.budget_left(ceiling - 1000, 10 * 60, 45.0, 1.0, 60), "slow but stepping, under the ceiling: still waiting")
	check(not Tour.budget_left(ceiling + 1, 0, 45.0, 1.0, 60), "no step at all past the ceiling: out")
	check(not Tour.budget_left(ceiling * 2 + 1, 0, 45.0, 2.0, 60), "the ceiling stretches with slack, and still holds")
