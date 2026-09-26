extends TestCase
## The dropper (Brains `drop`, the tamper): it waits on a ledge a blow cannot
## cross, and when someone comes within DROP_REACH of under it, it tells and
## comes down on where they stood. The landing spot is set when the tell starts,
## so a player who reads the shadow steps out from under it; down among them it
## stands a while where it landed, which is the opening. A reader beats it with
## the start knife and a player who walks in swinging loses.

const F := preload("res://tests/fight/fixture.gd")
const Reader := preload("res://tests/fight/reader.gd")
const Masher := preload("res://tests/fight/masher.gd")
const FirstMeetings := preload("res://tests/fight/test_first_meetings.gd")
## The ledge: every tile at x >= LIP stands this many levels over the rest.
const LIP := 52
const UP := 3


func _ledge_sim(hero_at: Vector2) -> FightSim:
	var w := F.flat_world(96)
	for y in 96:
		for x in range(LIP, 96):
			w.level[y * 96 + x] = 2 + UP
	var sim := F.make_sim(w, hero_at)
	sim.hero.inventory.add(&"knife")
	sim.hero.inventory.set_held(&"knife")
	sim.hero.inventory.set_edge(&"knife", FirstMeetings.START_EDGE)
	return sim


func _on_the_ledge(sim: FightSim, at: Vector2 = Vector2(LIP + 0.6, 48.5)) -> MobState:
	var m := sim.add_mob(&"tamper", at)
	m.facing = PI
	m.aim = PI
	m.set_mood(MobState.ATTACKING, sim.now)
	return m


func _until_tell(sim: FightSim, most_ms: float) -> Dictionary:
	var t := 0.0
	while t < most_ms:
		sim.slices(1)
		t += FightRules.SLICE_MS
		for e in sim.drain():
			if e.type == &"windup":
				return e
	return {}


func test_it_waits_on_its_ledge_for_someone_far_off() -> void:
	var sim := _ledge_sim(Vector2(45.5, 48.5))
	var m := _on_the_ledge(sim)
	var at := m.pos
	check(_until_tell(sim, 3000.0).is_empty(), "no drop at someone %.1f tiles off" % m.pos.distance_to(sim.hero.pos))
	lt(m.pos.distance_to(at), 0.05, "and it stayed on its ledge")


func test_it_comes_down_on_where_a_player_stood() -> void:
	var sim := _ledge_sim(Vector2(50.0, 48.5))
	var m := _on_the_ledge(sim)
	check(not _until_tell(sim, 2000.0).is_empty(), "it dropped on someone under it")
	var spot := sim.hero.pos
	eq(m.drop_at, spot, "on where they stood at the tell, standing still")
	var health := sim.hero.health
	F.ms(sim, m.drop.windup + m.drop.active * 0.5)
	lt(m.pos.distance_to(spot), 0.05, "it came down there")
	eq(sim.level_of(m.pos), 2, "on the low ground")
	F.ms(sim, m.drop.active)
	lt(float(sim.hero.health), float(health), "and a player who stood there was hit")


func test_it_comes_down_ahead_of_a_player_walking_on_under_it() -> void:
	var sim := _ledge_sim(Vector2(46.0, 48.5))
	var m := _on_the_ledge(sim)
	sim.hero.move = Vector2(1, 0)
	check(not _until_tell(sim, 3000.0).is_empty(), "it dropped on someone walking in")
	gt(m.drop_at.x, sim.hero.pos.x + 0.5, "ahead of them, where they were going")
	var health := sim.hero.health
	F.ms(sim, m.drop.windup + m.drop.active + 20.0)
	lt(float(sim.hero.health), float(health), "and walking on into it, they were hit")


func test_the_spot_is_set_when_the_tell_starts() -> void:
	var sim := _ledge_sim(Vector2(50.0, 48.5))
	var m := _on_the_ledge(sim)
	check(not _until_tell(sim, 2000.0).is_empty(), "it dropped")
	var spot := m.drop_at
	F.ms(sim, 250.0)
	sim.hero.move = Vector2(-1, 0)
	var health := sim.hero.health
	F.ms(sim, m.drop.windup - 250.0 + m.drop.active + 20.0)
	sim.hero.move = Vector2.ZERO
	eq(m.drop_at, spot, "the landing did not follow the player")
	eq(sim.hero.health, health, "a player who walked out from under it was not hit")
	# And it stands where it came down: spent, and on the player's level.
	var down := m.pos
	F.ms(sim, m.drop.recovery - 100.0)
	check(m.spent(sim.now), "it is spent after coming down on nothing")
	lt(m.pos.distance_to(down), 0.05, "and stands where it landed")
	check(sim.meets(sim.hero.pos, m.pos), "where a blow can reach it")


func test_a_reader_beats_it_and_a_player_walking_in_swinging_does_not() -> void:
	var times: Array[float] = []
	var lost := 0
	var drops := 0
	for i in FirstMeetings.STARTS:
		var r := _bout(i, true)
		check(r.won, "the reader beat the tamper from start %d: %s" % [i, r])
		times.append(float(r.t))
		lost += int(r.lost)
		drops += int(r.drops)
	var mashed := 0
	for i in FirstMeetings.STARTS:
		var r := _bout(i, false)
		if not r.won:
			mashed += 1
	print("  bout tamper: reader won %d of %d, middle %.1f s, longest %.1f s, %d drops, lost %d health; walking in swinging lost %d of %d"
		% [FirstMeetings.STARTS, FirstMeetings.STARTS, middle(times), times.max(), drops, lost, mashed, FirstMeetings.STARTS])
	gt(float(mashed), FirstMeetings.STARTS * 0.74, "a player who walks in swinging loses to it")
	check(drops >= FirstMeetings.STARTS, "it came down on the reader in every bout (%d drops)" % drops)


## A bout from start `i`: the player seven tiles off the ledge's foot, along a
## bearing that differs by start, the tamper at the lip above.
func _bout(i: int, careful: bool) -> Dictionary:
	var a := (float(i) / FirstMeetings.STARTS - 0.5) * 1.6
	var sim := _ledge_sim(Vector2(LIP + 0.6, 48.5) + Vector2.from_angle(PI + a) * 7.0)
	var m := _on_the_ledge(sim)
	var player: Variant = Reader.new(sim) if careful else Masher.new(sim)
	var t := 0.0
	var downed := false
	var lost := 0
	var drops := 0
	while t < 90000.0 and m.alive and not downed:
		player.act()
		sim.slices(2)
		t += 16.0
		for e in sim.drain():
			match e.type:
				&"hurt": lost += int(e.damage)
				&"windup": drops += int(m.blow != null and m.blow.area)
				&"outcome": downed = downed or e.outcome in [&"downed", &"carried"]
	return {"won": not m.alive and not downed, "t": snappedf(t / 1000.0, 0.1), "lost": lost, "drops": drops}
