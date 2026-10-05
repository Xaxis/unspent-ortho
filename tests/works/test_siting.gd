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


# --- the crags' store, at a lip (#68) ------------------------------------------

const Worlds := preload("res://tests/core/test_world_gen.gd")
const YARD := Vector2(20.5, 20.5)


## A shelf of rock at level 5, `lower` cut into it.
func _shelf(lower: Callable) -> WorldData:
	var w := WorldData.new(11, 40)
	for i in w.size * w.size:
		w.level[i] = 5
		w.ground[i] = Ground.ROCK
	lower.call(w)
	return w


func _cut(w: WorldData, x0: int, y0: int, x1: int, y1: int, to: int) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			w.level[y * w.size + x] = to


## THE LIP (Works.lip_foot) as a rule on ground laid by hand. A shelf falling to
## open ground has one, and the cable comes down at its foot; a gully at the foot
## of a higher crag has none (seed 1's first store hung its cable into one), nor
## does a pit, nor a shelf with no drop by it.
func test_a_lip_is_a_shelf_falling_to_open_ground() -> void:
	var open := _shelf(func(w: WorldData) -> void: _cut(w, 0, 26, 40, 40, 2))
	var foot := Works.lip_foot(open, YARD)
	check(foot.is_finite(), "a shelf falling to open ground has a lip")
	near(foot.y, 27.5, 0.01, "and its foot is on the open ground below, a tile clear of the face")
	var gully := _shelf(func(w: WorldData) -> void:
		_cut(w, 0, 26, 40, 29, 2)
		_cut(w, 0, 29, 40, 40, 9))
	eq(Works.lip_foot(gully, YARD), Vector2.INF, "a gully under a higher crag is no lip")
	var pit := _shelf(func(w: WorldData) -> void: _cut(w, 24, 24, 26, 26, 2))
	eq(Works.lip_foot(pit, YARD), Vector2.INF, "nor is a pit")
	eq(Works.lip_foot(_shelf(func(_w: WorldData) -> void: pass), YARD), Vector2.INF, "nor a shelf with no drop")
	# Falling both ways, the drop the play camera faces is taken though it is
	# farther: one falling away is hidden behind its own lip (PlayView.toward_eye).
	var both := _shelf(func(w: WorldData) -> void:
		_cut(w, 0, 0, 40, 14, 2)
		_cut(w, 0, 28, 40, 40, 2))
	var seen := Works.lip_foot(both, YARD)
	check(seen.is_finite() and seen.y > YARD.y, "the drop the camera faces is the lip (%s)" % seen)


## THE CRAGS KEEP A DEPOT: a survey bench is no yard's heart, so the plan's old
## store is (the_crags `_store_on`), standing where a yard stands whole, by a lip
## its winch's cable comes down, drawn as its landscape says. On every world the
## gate grows.
func test_the_crags_keep_a_depot_at_a_lip() -> void:
	eq(BiomeRegistry.get_def(&"the_crags").depot_form, WorksDepot.WINCH, "the crags draw their depot as a winch house")
	for s: int in Worlds.WORLD_SEEDS:
		var w := Worlds.world(s)
		var n := 0
		for site: WorksSite in Works.sites(w):
			if site.land != &"the_crags":
				continue
			n += 1
			eq(site.trade, &"store", "seed %d: the crags' yard is the plan's store" % s)
			check(Works._room_at(w, floori(site.pos.x), floori(site.pos.y)), "seed %d: and stands whole" % s)
			var foot := Works.lip_foot(w, site.pos)
			check(foot.is_finite(), "seed %d: by a lip its cable comes down" % s)
			print("  crags store, seed %d: yard %s, its cable %.1f tiles down to %s" % [s, site.pos, site.pos.distance_to(foot), foot])
		gt(float(n), 0.0, "seed %d keeps a crags depot" % s)
