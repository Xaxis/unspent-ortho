extends TestCase
## What a machine only half has makes it unsure, not sure (FightSim._notice and
## _suspicion): the player HEARD, or GLIMPSED behind its cone, ramps its
## suspicion over beats; past LOOK_AT it turns to look; only what it then sees
## in its cone makes it sure. Seen in front, it is sure at once, as ever.

const F := preload("res://tests/fight/fixture.gd")


func _keeper(sim: FightSim, at: Vector2, facing: float) -> MobState:
	var m := sim.add_mob(&"warden", at)
	m.facing = facing
	m.aim = facing
	m.home = at
	# Standing its watch, no round (Brains: a line of no length).
	m.line_a = at
	m.line_b = at
	return m


func test_heard_behind_it_a_machine_is_unsure_and_then_turns_to_look() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 30.5))
	# Facing away (+y is behind it), the player three tiles back: in its hearing
	# and in what it glimpses behind its cone, never in its cone.
	var m := _keeper(sim, Vector2(20.5, 27.5), -PI * 0.5)
	F.ms(sim, 300)
	lt(m.suspicion, 0.99, "three beats in, what it heard has not made it sure (%.2f)" % m.suspicion)
	check(m.mood == MobState.IDLE, "and it has not turned on anybody")
	var sure_at := -1.0
	var looked := false
	for i in 60:
		F.ms(sim, 100)
		if absf(angle_difference(m.aim, (sim.hero.pos - m.pos).angle())) < 0.6:
			looked = true
		if m.suspicion >= 0.99 and sure_at < 0.0:
			sure_at = sim.now
	check(looked, "unsure long enough, it turns its optics to where the player was")
	gt(sure_at, 0.0, "and, looking, it sees them and is sure")
	gt(sure_at, 1000.0, "but not before a second has gone: time to get out of it")


func test_seen_in_front_it_is_sure_at_once() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 24.5))
	var m := _keeper(sim, Vector2(20.5, 29.5), -PI * 0.5)
	F.ms(sim, 300)
	gt(m.suspicion, 0.99, "the player in its cone five tiles off: sure within three beats")


func test_a_player_who_keeps_out_of_its_sight_is_never_found() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 39.5))
	# Well behind it, past what it glimpses (a share of its 14) and what it hears
	# of someone standing (9): nothing rises.
	var m := _keeper(sim, Vector2(20.5, 27.5), -PI * 0.5)
	for i in 40:
		F.ms(sim, 100)
	lt(m.suspicion, 0.5, "twelve tiles behind it, standing still, it never becomes unsure (%.2f)" % m.suspicion)
	check(m.mood == MobState.IDLE, "and goes on keeping its post")


## A WALL HIDES. A room's walls stand in the query as blocks (21_doors), and a
## machine's line of sight is stopped by them as by a boulder -- or a warden
## looked through a bay's wall at whoever hid in it.
func test_a_wall_between_a_machine_and_the_player_hides_them() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 24.5))
	var m := _keeper(sim, Vector2(20.5, 29.5), -PI * 0.5)
	check(StealthQuery.sees(m.row, m.pos, sim.hero.pos, sim.moment, sim.world, sim.query, m.facing), "in the open, in its cone, it sees them")
	var wall: Array[Vector3] = []
	for k in 9:
		wall.append(Vector3(18.5 + 0.5 * float(k), 27.0, 0.3))
	sim.query.set_blocks(&"rooms", wall)
	check(not StealthQuery.sees(m.row, m.pos, sim.hero.pos, sim.moment, sim.world, sim.query, m.facing), "a wall across the line, it does not")
	sim.query.set_blocks(&"rooms", [] as Array[Vector3])
	check(StealthQuery.sees(m.row, m.pos, sim.hero.pos, sim.moment, sim.world, sim.query, m.facing), "and the wall gone, it does again")
