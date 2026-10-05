extends TestCase
## THE PLAN COMES FOR WHO HAS SEEN HIM, in a real game (slice 1 step 6). A
## village's people see him; on its own small hours, while he is away, one of them
## is carried to its region's yard, and the 71 hours run from then. Nobody who has
## not seen him is taken, nothing is taken in front of him, a dark yard takes
## nobody, and held past the last of the hours they are lost to the story.

const Sx := preload("res://tests/save/save_fixture.gd")
const SEEDS: Array[int] = [1, 7, 3]
const SIZE := 256


func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## A game whose world has a village in a region with a working yard, and that
## village's index: [game, index], or [] when none of SEEDS has one.
func _village_with_a_yard() -> Array:
	for s in SEEDS:
		var g := Sx.game(tree, ["--seed=%d" % s, "--size=%d" % SIZE, "--hour=11", "--weather=clear:0"])
		await frames(3)
		var works := g.get_node("34_works")
		for i in g.world.villages.size():
			var at: Vector2 = g.world.villages[i].get("pos", Vector2.INF)
			var region := g.world.region_at(floori(at.x), floori(at.y))
			if works.call(&"state", region) != null:
				return [g, i]
		Sx.end(g)
		await frames(1)
	return []


func _taken(g: Game) -> Taken:
	return g.get_node("45_taken").get("taken")


func _seen(g: Game, v: int) -> void:
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	_stand(g, at)
	# Long enough for the village to stream in (a figure every other frame) and
	# for the folk's half-second look round to find him among them.
	for i in 90:
		await frames(1)


func test_a_village_that_saw_him_loses_one_to_the_yard_while_he_is_away() -> void:
	Story.forget()
	var got := await _village_with_a_yard()
	check(not got.is_empty(), "one of %s has a village in a region with a yard" % str(SEEDS))
	if got.is_empty():
		return
	var g: Game = got[0]
	var v: int = got[1]
	var folk := g.get_node("folk")
	var raids := g.get_node("48_raids")
	var name := str(g.world.villages[v].get("name", ""))
	check(is_inf(folk.call(&"seen_at", v)), "nobody there has seen him yet")
	raids.call(&"sweep")
	eq(_taken(g).people.size(), 0, "and nobody who has not seen him is taken")

	await _seen(g, v)
	var seen_at: float = folk.call(&"seen_at", v)
	check(is_finite(seen_at), "standing among them, they have seen him")
	var due := SnatchNight.due(seen_at, g.world.seed_value, v)

	# Due, and he is still standing there: it waits for the next small hours.
	g.clock.minutes = due + 1.0
	raids.call(&"sweep")
	eq(_taken(g).people.size(), 0, "not in front of him")

	# Gone from there, and past the next small hours: somebody out of that village.
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	_stand(g, g.world.spawn if g.world.spawn.distance_to(at) > SnatchNight.AWAY else at + Vector2(SnatchNight.AWAY + 10.0, 0.0))
	# Its next small hours are a day on (SnatchNight.after_him); the morning after.
	g.clock.minutes = due + 1440.0 + 300.0
	raids.call(&"sweep")
	var people := _taken(g).people
	eq(people.size(), 1, "one of them is carried off while he is away")
	if people.size() == 1:
		eq(people[0].home_name, name, "out of the village that saw him")
		near(people[0].minutes, due + 1440.0, 1e-3, "at its own hour, not when he next looked")
	raids.call(&"sweep")
	eq(_taken(g).people.size(), 1, "and only one: it is come for once")

	# Held past the last of the hours, they are lost, and the story hears it.
	g.clock.minutes += Taken.GONE_HOURS * 60.0
	for i in 150:
		await frames(1)
	if people.size() == 1:
		check(people[0].gone and people[0].lost, "held past the last of the hours, they are gone")
	check(Story.landed(&"not_home"), "and somebody did not get home")
	Sx.end(g)
	await frames(1)
	Story.forget()


func test_a_dark_yard_comes_for_nobody() -> void:
	var got := await _village_with_a_yard()
	if got.is_empty():
		return
	var g: Game = got[0]
	var v: int = got[1]
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	var st: WorksState = g.get_node("34_works").call(&"state", g.world.region_at(floori(at.x), floori(at.y)))
	st.parts = [true, true, true]
	await _seen(g, v)
	_stand(g, at + Vector2(SnatchNight.AWAY + 10.0, 0.0))
	g.clock.minutes += 3.0 * 1440.0
	g.get_node("48_raids").call(&"sweep")
	eq(_taken(g).people.size(), 0, "a yard that is out holds nobody, so nobody is taken to it")
	Sx.end(g)
	await frames(1)


func test_who_has_seen_him_survives_a_save() -> void:
	var got := await _village_with_a_yard()
	if got.is_empty():
		return
	var g: Game = got[0]
	var v: int = got[1]
	await _seen(g, v)
	var folk := g.get_node("folk")
	var saved: Variant = JSON.parse_string(JSON.stringify(folk.call(&"_save_seen")))
	var was: float = folk.call(&"seen_at", v)
	folk.get("seen_by").clear()
	folk.call(&"_load_seen", saved)
	near(float(folk.call(&"seen_at", v)), was, 1e-3, "when they first saw him comes back")
	Sx.end(g)
	await frames(1)


## `hour snatch` (98_tour): a tour stages the snatch by name, on the minute the
## plan comes for the village that saw him first, whatever day a seed puts it on.
func test_a_tour_stages_the_snatch_by_the_village_that_saw_him_first() -> void:
	Story.forget()
	var got := await _village_with_a_yard()
	if got.is_empty():
		return
	var g: Game = got[0]
	var v: int = got[1]
	var raids := g.get_node("48_raids")
	await _seen(g, v)
	var folk := g.get_node("folk")
	# Only the village he stood in: whoever saw him as the game began is not this test's.
	var seen: Dictionary = folk.get("seen_by")
	for k: int in seen.keys():
		if k != v:
			seen.erase(k)
	var at: Vector2 = g.world.villages[v].get("pos", Vector2.INF)
	_stand(g, at + Vector2(SnatchNight.AWAY + 10.0, 0.0))
	var due := SnatchNight.due(float(seen[v]), g.world.seed_value, v)
	var staged := float(raids.call(&"tour_hour", "snatch"))
	near(staged, due, 1e-3, "the snatch is staged on the minute it is due")
	var o := (v + 1) % g.world.villages.size()
	if o != v:
		seen[o] = float(seen[v]) - 60.0
		near(float(raids.call(&"tour_hour", "snatch")), SnatchNight.due(float(seen[o]), g.world.seed_value, o), 1e-3,
			"with two that saw him, the one that saw him first is staged")
		seen.erase(o)
	g.clock.minutes = staged
	raids.call(&"sweep")
	var people := _taken(g).people
	eq(people.size(), 1, "and on that minute, away from them, one of them is taken")
	if people.size() == 1:
		eq(people[0].home_name, str(g.world.villages[v].get("name", "")), "out of the village that saw him")
	g.clock.minutes += 60.0
	near(float(raids.call(&"tour_hour", "snatch")), g.clock.minutes, 1e-3, "once it has come, staging it again keeps the clock")
	Sx.end(g)
	await frames(1)
	Story.forget()
