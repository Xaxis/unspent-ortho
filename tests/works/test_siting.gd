extends TestCase
## Where a depot chooses to stand, as a rule rather than as an island.
##
## The live half is `test_in_game.gd`, which grows real worlds and reports how
## many yards actually reach their keeper. This is the DECISION on its own, with
## the works placed by hand, so a change to the rule fails here in milliseconds
## instead of failing there in fifty seconds and being read as the island moving.

func _world() -> WorldData:
	var w := WorldData.new(11, 64)
	# **EVERY CANDIDATE MUST SURVIVE THE CLEARANCES OR THIS TESTS NOTHING.** A
	# depot is refused within `CLEAR_HOME` (34) of the spawn, and the first
	# staging put the spawn 25 tiles from the lone work: it was struck out before
	# the rule was consulted, so the busy knot "won" by being the only candidate
	# left and the test would have passed with the whole preference deleted.
	# From (62, 2) every work below is 43 tiles or more away.
	w.spawn = Vector2(62.0, 2.0)
	w.villages = []
	return w


func _work(at: Vector2) -> Dictionary:
	return {"pos": at, "kind": &"depot", "mark": &"cut"}


func test_a_depot_takes_the_busiest_work_when_no_keeper_is_listening() -> void:
	var w := _world()
	# Three together at 40,40 and a lone one at 20,20.
	var rows: Array = [_work(Vector2(40, 40)), _work(Vector2(41, 40)), _work(Vector2(40, 41)),
		_work(Vector2(20, 20))]
	var got := Works._knot(w, rows, Vector2(30, 30))
	check(not got.is_empty(), "a depot is sited at all")
	near((got.pos as Vector2).x, 40.0, 1.5, "the busy knot wins with nothing else to weigh")


func test_a_keeper_that_can_feel_a_work_outranks_a_busier_one_it_cannot() -> void:
	# **THE STARVE WAY, AS A RULE.** Breaking a yard is meant to take food out of
	# a keeper's reach, and it only does if the two are near each other. A yard
	# used to be chosen by what the plan had been DOING and a lair by what the
	# keeper EATS, so the two sets missed entirely: six of six depots on three
	# shipped-size seeds spent nothing into their keeper.
	var w := _world()
	var rows: Array = [_work(Vector2(40, 40)), _work(Vector2(41, 40)), _work(Vector2(40, 41)),
		_work(Vector2(20, 20))]
	# The keeper dens by the LONE work. Reach covers it and nothing else.
	var got := Works._knot(w, rows, Vector2(30, 30), Vector2(20, 20), 5.0)
	near((got.pos as Vector2).x, 20.0, 1.5,
		"the work the keeper can feel is taken over the busier one it cannot")
	# It is a RANK and not a weight: with two inside the reach, busyness decides
	# again. A weight would have been a number to tune.
	var both := Works._knot(w, rows, Vector2(30, 30), Vector2(40, 40), 30.0)
	near((both.pos as Vector2).x, 40.0, 1.5, "among works it can feel, the busiest still wins")


func test_a_landscape_with_no_keeper_changes_nothing() -> void:
	# Nineteen of twenty-one landscapes have no keeper at all, so the common case
	# is "no preference" and it must not become "no depot".
	var w := _world()
	var rows: Array = [_work(Vector2(40, 40)), _work(Vector2(41, 40)), _work(Vector2(20, 20))]
	var none := Works._knot(w, rows, Vector2(30, 30), Vector2.INF, 0.0)
	var plain := Works._knot(w, rows, Vector2(30, 30))
	eq(none.get("pos"), plain.get("pos"), "an absent keeper is no preference, not a refusal")
