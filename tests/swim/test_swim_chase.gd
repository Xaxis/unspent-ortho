extends TestCase
## What the water does to a chase (owner, 2026-09-17): the beasts come in after
## you, the machines that were not built for it stop at the waterline, and
## anything that swims crosses at a swimmer's pace and not its own.

const Fixture := preload("res://tests/fight/fixture.gd")


## Land on the left, a channel of deep water from x = 24, so a chaser put on the
## bank has to decide what the water is to it.
static func _bay() -> WorldData:
	var w := Fixture.flat_world(48, Ground.GRASS, Country.COAST, 1)
	for y in 48:
		# One tile of shallows at the edge, as a real shore has: it is where a
		# dredger stands, because its own keeps_to allows it no dry ground at all.
		w.ground[y * 48 + 23] = Ground.WATER
		for x in range(24, 48):
			w.ground[y * 48 + x] = Ground.DEEP_WATER
			w.level[y * 48 + x] = 0
	return w


func _chase(kind: StringName, from_x: float = 22.5) -> Dictionary:
	var w := _bay()
	# The player is out in the channel; the body is put on the bank behind them.
	var sim := Fixture.make_sim(w, Vector2(30.5, 24.5))
	var m := sim.add_mob(kind, Vector2(from_x, 24.5))
	m.set_mood(MobState.CHASING, sim.now)
	var wettest := 0.0
	for i in 400:
		sim.step(0.032)
		if m.removed or not m.alive:
			break
		m.set_mood(MobState.CHASING, sim.now)
		wettest = maxf(wettest, m.pos.x)
	return {"mob": m, "x": wettest, "sim": sim}


func test_a_dog_comes_in_after_a_swimmer() -> void:
	var r := _chase(&"dog.feral")
	gt(float(r.x), 25.0, "a dog swims: it got to %.1f and the water starts at 24" % float(r.x))


func test_a_runner_stops_at_the_waterline() -> void:
	var r := _chase(&"runner")
	lt(float(r.x), 24.5, "a machine that cannot swim keeps its feet: %.1f" % float(r.x))
	gt(float(r.x), 21.0, "and it does come as far as the water")


func test_a_dredger_is_the_machine_the_water_does_not_stop() -> void:
	# Started in the shallows, which is the only ground a dredger keeps to.
	var r := _chase(&"dredger", 23.5)
	gt(float(r.x), 25.0, "it was built to work in water: %.1f" % float(r.x))


## A swimmer crosses at a swimmer's pace, whoever it is. Without this the water
## is a trap: the player crawls at two fifths and everything else keeps its legs.
func test_a_body_swims_at_a_swimmer_pace() -> void:
	var w := _bay()
	var sim := Fixture.make_sim(w, Vector2(40.5, 24.5))
	var m := sim.add_mob(&"dog.feral", Vector2(30.5, 24.5))
	m.set_mood(MobState.CHASING, sim.now)
	var from := m.pos
	for i in 60:
		sim.step(0.032)
		m.set_mood(MobState.CHASING, sim.now)
	var swum := from.distance_to(m.pos) / (60.0 * 0.032)
	var pace := float(Roster.row(&"dog.feral").get("dash", 7.5))
	lt(swum, pace * Tuning.SWIM_FACTOR * 1.6, "it is swimming, not running: %.2f t/s" % swum)
	gt(swum, 0.15, "and it is getting somewhere: %.2f t/s" % swum)


## A blow needs something to push against. The crossing still costs only time and
## a soaking — this is not a toll, it is having no footing.
func test_nothing_swings_from_the_water() -> void:
	var w := _bay()
	var sim := Fixture.make_sim(w, Vector2(20.5, 24.5))
	sim.step(0.032)
	eq(sim.hero.swing_refusal(sim.now), &"", "on the bank a swing is a swing")
	sim.hero.pos = Vector2(30.5, 24.5)
	sim.step(0.032)
	check(sim.hero.swimming, "out of its depth")
	eq(sim.hero.swing_refusal(sim.now), &"swimming", "and nothing to push against")
	# A dodge is still allowed: that is a kick away, which is the one thing a body
	# in water CAN do, and the fight has no other way out of a bite.
	eq(sim.hero.dodge_refusal(sim.now), &"", "a kick away is still a kick away")


## THE SEAM BETWEEN SWIMMING AND THE THINGS WAVE B PUT IN THE WATER. A body
## whose move is refused falls back on stepping one axis at a time, and the
## second of those two steps was being asked whether a WALKER could stand
## there — so to a swimmer every tile of deep water refused it, and a swimmer
## pushed into anything solid stopped dead instead of working its way round.
## Nothing caught it while the only walls were trunks on dry land; the drowned
## lighthouse stands in the water, which is where a player meets one.
func test_a_swimmer_pushed_into_a_wall_still_gets_round_it() -> void:
	var w := _bay()
	var q := WorldQuery.new(w)
	# A pocket of drowned stonework out in the channel, as a long landmark is
	# walled: a chain of circles, which is what makes a corner to be caught in.
	var walls: Array[Vector3] = [
		Vector3(30.0, 23.2, 1.3), Vector3(30.0, 25.8, 1.3), Vector3(31.2, 24.5, 1.3)]
	q.set_blocks(&"landmarks", walls)
	var from := Vector2(28.4, 24.2)
	var delta := Vector2(0.6, 0.6)
	var swum := q.move_body(from, delta, 0.34, null, true)
	gt(swum.distance_to(from), 0.2,
		"a swimmer stuck fast against the stonework: it got to %.2f,%.2f" % [swum.x, swum.y])
	gt(swum.distance_to(Vector2(30.0, 25.8)), 1.3, "and it is not inside the stonework")
	# The same push on legs is refused outright, because deep water IS a wall to
	# a walker: the fallback must read the water differently for the two of them.
	eq(q.move_body(from, delta, 0.34, null, false), from, "a walker does not paddle out")
