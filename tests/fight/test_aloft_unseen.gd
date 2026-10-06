extends TestCase
## UP THE LEG, OUT OF THEIR WORLD (Moment.aloft, FightSim._notice). While he hangs
## on a walker's leg his fight body stays at the cable's foot on the land, but no
## body below notices him there: as inside a crags ring, its senses read him as
## nothing. One that had him counts him lost and, past its forget, goes back to
## its rounds; none of them lands a blow on the body he left below.

const F := preload("res://tests/fight/fixture.gd")

const FOOT := Vector2(40.5, 40.5)


func _sim() -> FightSim:
	return F.make_sim(F.flat_world(96, Ground.MOSS, BiomeRegistry.index_of(&"home_coast"), 2), FOOT)


## Steps the sim `ms` with the hero still; returns the hurts it threw.
func _run(sim: FightSim, ms: float) -> Array:
	var hurts: Array = []
	var t := 0.0
	while t < ms:
		sim.slices(2)
		t += 2.0 * FightRules.SLICE_MS
		for e in sim.drain():
			if e.type == &"hurt":
				hurts.append(e)
	return hurts


func _hunting(m: MobState) -> bool:
	return m.mood == MobState.CHASING or m.mood == MobState.ATTACKING


func test_a_body_below_never_notices_him_aloft() -> void:
	# The same runner, the same distance, in plain sight: on the land it has him.
	var land := _sim()
	var seen := land.add_mob(&"runner", FOOT + Vector2(4.0, 0.0))
	seen.facing = PI
	_run(land, 3000.0)
	check(seen.disturbed or _hunting(seen), "on the land a runner 4 tiles off notices him (mood %s)" % seen.mood)
	var up := _sim()
	up.moment.aloft = true
	var below := up.add_mob(&"runner", FOOT + Vector2(4.0, 0.0))
	below.facing = PI
	_run(up, 3000.0)
	check(not _hunting(below), "up the leg, a runner at the foot never hunts him (mood %s)" % below.mood)


func test_one_that_had_him_loses_him_and_lands_nothing() -> void:
	var sim := _sim()
	var m := sim.add_mob(&"runner", FOOT + Vector2(6.0, 0.0))
	m.disturbed = true
	m.set_mood(MobState.CHASING, sim.now)
	sim.moment.aloft = true
	var hurts := _run(sim, 30000.0)
	check(not _hunting(m), "past its forget it has stopped hunting him (mood %s)" % m.mood)
	eq(hurts.size(), 0, "and no blow landed on the body he left below")
