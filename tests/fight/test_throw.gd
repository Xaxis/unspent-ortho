extends TestCase
## The thrower (Brains `throw`, the middens' sorter): its bite is a lane it
## throws down from a distance, told on the ground for the whole windup; the lane
## is set when the tell starts, so a player who reads it steps out; and after a
## throw it stands to reload, which is the opening. A reader beats it with the
## start knife from every start and a player who walks in swinging loses.

const F := preload("res://tests/fight/fixture.gd")
const FirstMeetings := preload("res://tests/fight/test_first_meetings.gd")
const Reader := preload("res://tests/fight/reader.gd")


func _turned(sim: FightSim, at: Vector2) -> MobState:
	var m := sim.add_mob(&"sorter", at)
	m.facing = (sim.hero.pos - at).angle() + 0.8
	m.aim = m.facing
	m.disturbed = true
	m.set_mood(MobState.ATTACKING, sim.now)
	return m


## Run until its tell starts; the windup event, or {}.
func _until_tell(sim: FightSim, most_ms: float) -> Dictionary:
	var t := 0.0
	while t < most_ms:
		sim.slices(1)
		t += FightRules.SLICE_MS
		for e in sim.drain():
			if e.type == &"windup":
				return e
	return {}


func test_its_bite_is_a_lane_told_as_one() -> void:
	var b := Roster.bite(&"sorter")
	check(FightRules.throws(b), "the sorter's bite reaches %.1f tiles: it throws" % b.reach)
	check(not FightRules.throws(Roster.bite(&"harvester")), "a harvester's does not")
	var lane := FightRules.tell_lane(Vector2(10, 10), 0.55, b, 0.3)
	eq(Vector2(lane.x, lane.y), Vector2(10, 10), "the lane starts at the thrower")
	# Every point just inside the drawn lane is hit, and just outside is not.
	for along: float in [0.5, 2.5, lane.z - 0.35]:
		var inside := Vector2(10.0 + along, 10.0 + lane.w * 0.5 - 0.35)
		var outside := Vector2(10.0 + along, 10.0 + lane.w * 0.5 + 0.05)
		check(FightRules.box_hits(Vector2(10, 10), 0.0, 0.55, b, inside, 0.3), "inside the lane at %.1f is hit" % along)
		check(not FightRules.box_hits(Vector2(10, 10), 0.0, 0.55, b, outside, 0.3), "outside it at %.1f is not" % along)


func test_it_throws_from_a_distance_and_hits_a_player_who_stands() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var m := _turned(sim, Vector2(29.5, 20.5))
	var tell := _until_tell(sim, 6000.0)
	check(not tell.is_empty(), "it threw within 6 s")
	var d := m.pos.distance_to(sim.hero.pos)
	gt(d, 3.0, "from out of a knife's reach (%.2f tiles)" % d)
	lt(d, m.radius + m.bite.reach, "and from inside its lane")
	var health := sim.hero.health
	F.ms(sim, m.bite.windup + m.bite.active + 20.0)
	lt(float(sim.hero.health), float(health), "a player who stood there was hit")


func test_the_lane_is_set_when_the_tell_starts() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var m := _turned(sim, Vector2(29.5, 20.5))
	check(not _until_tell(sim, 6000.0).is_empty(), "it threw")
	var facing := m.facing
	# A walk aside, begun a player's reaction after the tell.
	F.ms(sim, 250.0)
	sim.hero.move = Vector2.from_angle(facing + PI * 0.5)
	var health := sim.hero.health
	F.ms(sim, m.bite.windup - 250.0 + m.bite.active + 20.0)
	sim.hero.move = Vector2.ZERO
	lt(absf(wrapf(m.facing - facing, -PI, PI)), 1e-4, "the lane did not follow the player")
	eq(sim.hero.health, health, "a player who walked out of it was not hit")


func test_after_a_throw_it_stands_to_reload() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var m := _turned(sim, Vector2(29.5, 20.5))
	check(not _until_tell(sim, 6000.0).is_empty(), "it threw")
	# Out of the lane, then straight in on it while it reloads.
	F.ms(sim, 250.0)
	sim.hero.move = Vector2.from_angle(m.facing + PI * 0.5)
	F.ms(sim, m.bite.windup - 250.0 + m.bite.active + 20.0)
	var at := m.pos
	var tells := 0
	var t := 0.0
	while t < m.bite.recovery + m.bite.cooldown - 200.0:
		sim.hero.move = (m.pos - sim.hero.pos).normalized() if m.pos.distance_to(sim.hero.pos) > m.radius + sim.hero.radius + 0.3 else Vector2.ZERO
		sim.slices(1)
		t += FightRules.SLICE_MS
		tells += F.count(sim.drain(), &"windup")
	lt(m.pos.distance_to(at), 0.3, "it stood through its reload (%.2f tiles)" % m.pos.distance_to(at))
	eq(tells, 0, "and threw nothing more")
	lt(m.pos.distance_to(sim.hero.pos), m.radius + sim.hero.radius + 0.5, "so a player walking in got to it")


func test_it_gives_ground_to_a_player_inside_its_lane_before_it_throws() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var m := _turned(sim, Vector2(22.0, 20.5))
	var tell := _until_tell(sim, 6000.0)
	check(not tell.is_empty(), "it threw")
	var lane := m.radius + m.bite.reach
	var d := m.pos.distance_to(sim.hero.pos)
	gt(d, lane * Brains.THROW_NEAR - 0.1, "it backed off to %.2f tiles before throwing, not from 1.5" % d)


func test_it_stands_to_reload_after_a_throw_that_landed_too() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var m := _turned(sim, Vector2(29.5, 20.5))
	check(not _until_tell(sim, 6000.0).is_empty(), "it threw")
	var health := sim.hero.health
	F.ms(sim, m.bite.windup + m.bite.active + 20.0)
	lt(float(sim.hero.health), float(health), "it landed")
	# A bite that landed is over sooner (FightSim._landed): its own lockout.
	var at := m.pos
	F.ms(sim, m.blow_at + m.blow.lockout() - sim.now - 40.0)
	lt(m.pos.distance_to(at), 0.3, "and it stood to reload all the same (%.2f tiles)" % m.pos.distance_to(at))


func test_a_reader_beats_it_and_a_player_walking_in_swinging_does_not() -> void:
	var lost := 0
	var longest := 0.0
	var times: Array[float] = []
	for i in FirstMeetings.STARTS:
		var r := FirstMeetings.bout(&"sorter", true, i, 90.0)
		check(r.won and not r.downed, "the reader beat the sorter from start %d: %s" % [i, r])
		lost += int(r.lost_health)
		longest = maxf(longest, float(r.t))
		times.append(float(r.t))
	var mashed := 0
	for i in FirstMeetings.STARTS:
		var r := FirstMeetings.bout(&"sorter", false, i, 90.0)
		if r.downed or not r.won:
			mashed += 1
	print("  bout sorter: reader won %d of %d, middle %.1f s, longest %.1f s, lost %d health; walking in swinging lost %d of %d"
		% [FirstMeetings.STARTS, FirstMeetings.STARTS, middle(times), longest, lost, mashed, FirstMeetings.STARTS])
	gt(float(mashed), FirstMeetings.STARTS * 0.74, "a player who walks in swinging loses to it")


## Met already turned, seven tiles off and throwing, from eight bearings: the
## case a first meeting on its round does not reach, since the reader's first
## blow lands before it has ever thrown.
func test_a_reader_beats_it_already_turned_and_throwing() -> void:
	var times: Array[float] = []
	var hurt := 0
	var throws := 0
	for i in FirstMeetings.STARTS:
		var sim := F.make_sim(F.flat_world(96), Vector2(48.5, 48.5))
		sim.hero.inventory.add(&"knife")
		sim.hero.inventory.set_held(&"knife")
		sim.hero.inventory.set_edge(&"knife", FirstMeetings.START_EDGE)
		var at := sim.hero.pos + Vector2.from_angle(float(i) / FirstMeetings.STARTS * TAU) * 7.0
		var m := _turned(sim, at)
		var bot := Reader.new(sim)
		var t := 0.0
		var downed := false
		while t < 90000.0 and m.alive and not downed:
			bot.act()
			sim.slices(2)
			t += 16.0
			for e in sim.drain():
				match e.type:
					&"hurt": hurt += int(e.damage)
					&"windup": throws += 1
					&"outcome": downed = downed or e.outcome in [&"downed", &"carried"]
		check(not m.alive and not downed, "the reader took a turned sorter from start %d in %.1f s" % [i, t / 1000.0])
		times.append(t / 1000.0)
	print("  bout sorter, turned at 7 tiles: middle %.1f s, longest %.1f s, %d throws, %d health lost over %d"
		% [middle(times), times.max(), throws, hurt, FirstMeetings.STARTS])
	gt(float(throws), float(FirstMeetings.STARTS), "it threw at the reader more than once a bout")
