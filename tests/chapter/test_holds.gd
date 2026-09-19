extends TestCase
## Preloaded rather than named: a `class_name` resolves out of Godot's global
## class cache, which the tools refresh and a player's own run does not.
const Hold := preload("res://src/core/chapter/road_hold.gd")
## The plan standing on the road out of an unanswered chapter (VISION §10.3).


func _game(args: PackedStringArray) -> Game:
	var o := BootOptions.parse(args)
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func _holds(g: Game) -> Node:
	return g.get_node("24_holds")


func test_the_plan_holds_every_road_out_of_a_place_it_still_owns() -> void:
	var g := _game(PackedStringArray(["--seed=7", "--size=512"]))
	var h := _holds(g)
	var sites: Array = h.get(&"sites")
	gt(float(sites.size()), 0.0, "the world has roads worth holding")
	# Nothing is explored, mined or defended on the first frame, so every one of
	# them is held. A run where some were already open would mean `closed` had
	# stopped asking the chapter.
	eq(int(h.call(&"open_count")), 0, "and holds all of them while it still owns the places")
	g.queue_free()


## Walk a body straight at something and report how far it got.
static func _walk(g: Game, from: Vector2, dir: Vector2) -> float:
	var p := from
	for i in 40:
		var q := g.query.move_body(p, dir * 0.25, 0.3, null, false)
		if q.distance_to(p) < 0.05:
			break
		p = q
	return p.distance_to(from)


func test_it_holds_the_road_and_not_the_country() -> void:
	# **THE WHOLE DESIGN IN ONE MEASUREMENT, AND IT HAS TO BE A BODY WALKING.**
	# A barrier that walled the region would be the invisible wall §10.3 forbids
	# with a model on it, so this has to stop a body on the carriageway and stop
	# nothing at all off it -- or the third way through, leave the road and cross
	# the country, is not real and the chapter has become a lock.
	#
	# `blocks_at` is the wrong door for asking and I used it first: it is a BROAD
	# PHASE, returning every circle near enough to be worth checking, so it reads
	# non-empty over a 17x17 box round a barrier and made a line across a road
	# look like a wall round a landscape. The only honest question is what a body
	# actually does, so this walks one.
	var g := _game(PackedStringArray(["--seed=7", "--size=512"]))
	var h := _holds(g)
	var sites: Array = h.get(&"sites")
	if sites.is_empty():
		return
	var stopped := 0
	var through := 0
	for s: Hold.HoldSite in sites:
		var across := Vector2(-s.along.y, s.along.x)
		if _walk(g, s.pos - s.along * 4.0, s.along) < 3.5:
			stopped += 1
		if _walk(g, s.pos + across * 10.0 - s.along * 4.0, s.along) >= 7.0:
			through += 1
	eq(stopped, sites.size(), "every closed hold stops a body on the road it stands on")
	# **AND THE CONTROL, which is the half that means anything.** Some of those
	# off-road lines are stopped by cliffs and water and would be with no barrier
	# in the world. So take every barrier away and walk the same lines again: the
	# number has to be IDENTICAL, because the plan's effect off the carriageway
	# is meant to be nothing at all. Measured on seed 7, it is 14 of 17 both ways.
	for s2: Hold.HoldSite in sites:
		h.call(&"_break", s2)
	var through_open := 0
	for s3: Hold.HoldSite in sites:
		var across3 := Vector2(-s3.along.y, s3.along.x)
		if _walk(g, s3.pos + across3 * 10.0 - s3.along * 4.0, s3.along) >= 7.0:
			through_open += 1
	eq(through, through_open, "and walls nothing beside it that the country was not already walling")
	g.queue_free()


func test_breaking_one_opens_that_road_and_leaves_the_others() -> void:
	var g := _game(PackedStringArray(["--seed=7", "--size=512"]))
	var h := _holds(g)
	var sites: Array = h.get(&"sites")
	if sites.is_empty():
		return
	var one: Hold.HoldSite = sites[0]
	h.call(&"_break", one)
	check(not bool(h.call(&"closed", one)), "the one taken apart is open")
	eq(int(h.call(&"open_count")), 1, "and only that one")
	check((g.query.blocks_at(one.pos) as Array).is_empty(), "its road is clear")
	if sites.size() > 1:
		var other: Hold.HoldSite = sites[1]
		check(bool(h.call(&"closed", other)), "the next crossing is still held")
	g.queue_free()


func test_what_was_broken_survives_a_save() -> void:
	# Where a hold IS is derived and never saved; what was DONE to it has to be.
	var g := _game(PackedStringArray(["--seed=7", "--size=512"]))
	var h := _holds(g)
	var sites: Array = h.get(&"sites")
	if sites.is_empty():
		return
	h.call(&"_break", sites[0])
	var d: Dictionary = h.call(&"_save")
	var g2 := _game(PackedStringArray(["--seed=7", "--size=512"]))
	var h2 := _holds(g2)
	h2.call(&"_load", d)
	var same: Array = h2.get(&"sites")
	check(not bool(h2.call(&"closed", same[0])), "it is still open in the loaded game")
	eq(int(h2.call(&"open_count")), 1, "and nothing else came open with it")
	g.queue_free()
	g2.queue_free()


func test_a_chapter_is_asked_again_only_when_something_could_have_moved_it() -> void:
	# **THE FIX FOR A 224 ms HITCH, AND WHY IT IS NOT A SLOWER TIMER.** This
	# system read every chapter on a clock, and a chapter's answer walks every
	# prop in the world. Rescheduling that cost turned a low frame rate into a
	# stall; the answer was that its inputs cannot move without something saying
	# so. Four things say so, and this holds all four to being wired.
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=4", "--size=256"])))
	var holds: Node = g.get_node("24_holds")
	check(holds != null, "the holds system loads")
	if holds == null:
		g.free()
		return
	# Nothing has happened, so nothing is pending: an idle frame costs nothing,
	# which is the whole point and the thing a timer can never do.
	holds.call("_process", 0.016)
	eq(holds.get("_dirty"), false, "an idle frame leaves nothing to recompute")
	for sig: Signal in (holds.call("_watched") as Array[Signal]):
		check(sig.is_connected(Callable(holds, "_chapters_moved")),
			"the holds system is listening to what can move a chapter")
	# Each of the four marks it, and a frame spends the mark exactly once.
	Events.took.emit(&"iron_ore", 1)
	eq(holds.get("_dirty"), true, "ore taken asks the chapters again")
	holds.call("_process", 0.016)
	eq(holds.get("_dirty"), false, "and one frame answers it once")
	Events.works_broken.emit(0, &"coast")
	eq(holds.get("_dirty"), true, "a yard put dark asks again")
	g.free()
