extends TestCase
## A lock holds the body (owner, 2026-09-24; docs/CONTROLS.md §Lock-on): it faces
## what is locked, a strafe circles it at the distance it started, a swing goes
## at it whatever else is near, a dodge with no key held goes straight back from
## it, and letting go hands the facing back as a turn, not a snap. Each is asked
## of the real simulation on flat ground, so what is measured is the rule.

const F := preload("res://tests/fight/fixture.gd")


func _locked_sim(lock_at: Vector2) -> FightSim:
	var sim := F.make_sim()
	sim.hero.set_lock(lock_at, sim.now)
	return sim


func test_a_locked_body_faces_what_it_holds_while_walking_away_across_it() -> void:
	var target := Vector2(24.5, 20.5)
	var sim := _locked_sim(target)
	# Walking SOUTH, with the target due east: unlocked the body would face south.
	sim.hero.move = Vector2(0.0, 1.0)
	F.ms(sim, 600)
	var want := (target - sim.hero.pos).angle()
	lt(absf(wrapf(sim.hero.facing - want, -PI, PI)), 0.05,
		"facing %.2f, the target is at %.2f" % [sim.hero.facing, want])


func test_a_strafe_circles_the_target_at_the_distance_it_started() -> void:
	var target := Vector2(24.5, 20.5)
	var sim := _locked_sim(target)
	var start := sim.hero.pos.distance_to(target)
	var a0 := (sim.hero.pos - target).angle()
	# Right held at a run for four seconds over the shoulder, read afresh every
	# slice as the game reads it. Even re-aimed every slice a straight step drifts
	# outward (about 0.12 tiles here); an arc does not drift at all.
	sim.hero.run = true
	var went := 0.0
	var was := a0
	for i in 500:
		sim.hero.move = LockOn.intent(Vector2(1.0, 0.0), 45.0, sim.hero.pos, target, true)
		sim.slices(1)
		var a := (sim.hero.pos - target).angle()
		went += wrapf(a - was, -PI, PI)
		was = a
	var now := sim.hero.pos.distance_to(target)
	lt(absf(now - start), 0.01, "still %.3f from it, started %.3f" % [now, start])
	gt(absf(went), PI, "and it went more than half way round (%.2f rad)" % went)


func test_forward_closes_and_back_retreats_along_the_line() -> void:
	var target := Vector2(26.5, 20.5)
	var sim := _locked_sim(target)
	var start := sim.hero.pos.distance_to(target)
	sim.hero.move = (target - sim.hero.pos).normalized()
	F.ms(sim, 500)
	lt(sim.hero.pos.distance_to(target), start - 1.0, "toward it closes")
	var mid := sim.hero.pos.distance_to(target)
	sim.hero.move = -(target - sim.hero.pos).normalized()
	F.ms(sim, 500)
	gt(sim.hero.pos.distance_to(target), mid + 1.0, "away from it retreats")


func test_a_swing_goes_at_the_lock_not_at_a_nearer_body() -> void:
	var target := Vector2(22.0, 20.5)
	var sim := _locked_sim(target)
	F.still(sim, &"runner", target, PI)
	# A second body just off the way the body is walking, and nearer: the aim
	# assist would turn a free swing onto it.
	F.still(sim, &"runner", Vector2(20.5, 21.6), 0.0)
	sim.hero.move = Vector2(0.0, 1.0)
	F.ms(sim, 16)
	sim.press_swing()
	sim.slices(2)
	var want := (target - sim.hero.pos).angle()
	lt(absf(wrapf(sim.hero.facing - want, -PI, PI)), 0.05,
		"the blow faces the lock (%.2f), not the nearer body" % want)


func test_a_dodge_with_no_key_goes_straight_back_from_the_lock() -> void:
	var target := Vector2(20.5, 17.5)
	var sim := _locked_sim(target)
	# Facing east, away from a target to the north: an unlocked dodge would go
	# back from the FACING, which is west.
	sim.hero.facing = 0.0
	sim.hero.move = Vector2.ZERO
	sim.press_dodge()
	sim.slices(1)
	var away := (sim.hero.pos - target).normalized()
	gt(sim.hero.dodge_dir.dot(away), 0.99, "the dodge goes straight back from it: %s" % str(sim.hero.dodge_dir))


func test_a_dodge_to_the_side_keeps_the_body_facing_the_lock() -> void:
	var target := Vector2(24.5, 20.5)
	var sim := _locked_sim(target)
	sim.hero.facing = 0.0
	sim.hero.move = Vector2(0.0, 1.0)
	sim.press_dodge()
	F.ms(sim, 150)
	check(sim.hero.dodge_dir.dot(Vector2(0.0, 1.0)) > 0.99, "the dodge went the way the keys pointed")
	var want := (target - sim.hero.pos).angle()
	lt(absf(wrapf(sim.hero.facing - want, -PI, PI)), 0.1, "and the body still faces the lock")


func test_letting_go_turns_the_body_back_instead_of_snapping_it() -> void:
	var target := Vector2(24.5, 20.5)
	var sim := _locked_sim(target)
	sim.hero.move = Vector2(0.0, 1.0)
	F.ms(sim, 400)
	sim.hero.set_lock(Vector2.INF, sim.now)
	sim.slices(1)
	var off := absf(wrapf(sim.hero.facing - PI * 0.5, -PI, PI))
	gt(off, 0.3, "one slice after letting go the body is still turning (%.2f off the walk)" % off)
	F.ms(sim, 400)
	lt(absf(wrapf(sim.hero.facing - PI * 0.5, -PI, PI)), 0.02, "and it comes round onto the walk")


func test_no_lock_is_the_game_as_it_was() -> void:
	var sim := F.make_sim()
	sim.hero.move = Vector2(0.0, 1.0)
	F.ms(sim, 100)
	lt(absf(sim.hero.facing - PI * 0.5), 1e-5, "an unlocked body faces the way it walks, at once")


func test_over_the_shoulder_the_keys_are_the_line_to_the_target() -> void:
	var from := Vector2(10.0, 10.0)
	var target := Vector2(10.0, 4.0)
	# Up closes, whatever the camera's yaw.
	var fwd := LockOn.intent(Vector2(0.0, -1.0), 200.0, from, target, true)
	gt(fwd.dot(Vector2(0.0, -1.0)), 0.99, "up is toward it: %s" % str(fwd))
	# Right circles: across the line, clockwise on the screen.
	var right := LockOn.intent(Vector2(1.0, 0.0), 200.0, from, target, true)
	lt(absf(right.dot(Vector2(0.0, -1.0))), 0.01, "right is across the line")
	gt(right.dot(Vector2(1.0, 0.0)), 0.99, "to the east, with the target north: %s" % str(right))


func test_from_above_the_keys_stay_the_screen() -> void:
	var from := Vector2(10.0, 10.0)
	var target := Vector2(10.0, 4.0)
	for yaw: float in [45.0, 120.0]:
		var keys := Vector2(0.6, -0.8)
		eq(LockOn.intent(keys, yaw, from, target, false), Player.screen_to_world(keys, yaw),
			"from above a lock does not turn the keys (yaw %.0f)" % yaw)
		eq(LockOn.intent(keys, yaw, from, Vector2.INF, true), Player.screen_to_world(keys, yaw),
			"and without a lock nothing turns them")


## Anything that holds keys to walk a world way (a tour, a bot) asks the inverse,
## so it walks where it meant under the view and the lock the game is in. The
## tour's walk assumed the top view's fixed yaw and steered wrong over the shoulder.
func test_keys_for_walks_the_way_it_was_asked_in_every_frame() -> void:
	var from := Vector2(10.0, 10.0)
	for target: Vector2 in [Vector2.INF, Vector2(13.0, 8.0)]:
		for shoulder: bool in [false, true]:
			for yaw: float in [45.0, 170.0, -60.0]:
				for dir: Vector2 in [Vector2(1, 0), Vector2(0.6, -0.8), Vector2(-1, 0)]:
					var keys := LockOn.keys_for(dir, yaw, from, target, shoulder)
					var back := LockOn.intent(keys, yaw, from, target, shoulder)
					lt(back.distance_to(dir), 1e-4, "%s yaw %.0f lock %s over %s" % [str(dir), yaw, str(target), str(shoulder)])
	eq(LockOn.keys_for(Vector2(1, 0), 45.0, from, Vector2.INF, false),
		Vector2(1.0, 1.0) * 0.70710678, "the top view's own answer, as the tour used to spell it")
