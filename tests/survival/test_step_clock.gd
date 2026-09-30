extends TestCase
## The body's clock (Survival.now_real) counts this game's physics steps, from
## its setup: the same fight after another in the process is the same fight.
## Counted from the process's first step, a window ending exactly on a step fell
## either side of it with how many steps an earlier game had run (a played
## Reaper fight: 6 tries after a two-frame pad, 4 without).

const Sx := preload("res://tests/save/save_fixture.gd")


func test_the_body_clock_starts_with_the_game_not_the_process() -> void:
	for i in 90:
		await tree.physics_frame
	Sx.use_root("step-clock")
	var g := Sx.game(tree, ["--seed=1", "--hour=11", "--weather=clear:0"])
	lt(Survival.now_real(), 0.05, "a new game's body clock reads from its own start (%.3f s)" % Survival.now_real())
	for i in 30:
		await tree.physics_frame
	near(Survival.now_real(), 0.5, 0.02, "and counts its steps (%.3f s after 30)" % Survival.now_real())
	Sx.end(g)
