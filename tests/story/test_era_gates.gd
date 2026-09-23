extends TestCase
## The way into 2029 (docs/STORY.md). `StoryGates` says where a gate is and
## when it opens; this is the crossing's half of that seam.
##
## A GATE PAIRS BY COORDINATE, NOT BY INDEX, and that is the whole reason the
## Before was built tile for tile. `Portals` pairs shafts by index because two
## realms are two islands sharing no ground (its own header says so). The era
## shares every tile, so a gate must land you on the tile you left -- a way
## through time that moved you sideways as well as back would be a different
## place, not a different year.

const SIZE := 256


func test_a_gate_stands_on_the_same_tile_in_both_years() -> void:
	var now := WorldGen.generate(1, SIZE)
	var then := WorldGen.generate(1, SIZE, &"", Realm.ERA)
	var here := StoryGates.all(now)
	var there := StoryGates.all(then)
	gt(here.size(), 0, "this world holds gates at all")
	eq(there.size(), here.size(), "and 2029 holds the same ones")
	for g: Dictionary in here:
		var twin := Vector2.INF
		for h: Dictionary in there:
			if h.id == g.id:
				twin = h.pos
		eq(twin, g.pos as Vector2, "%s stands on the same tile in both years" % g.id)


func test_a_gate_is_shut_until_its_beat_has_been_felt() -> void:
	Story.forget()
	var w := WorldGen.generate(1, SIZE)
	var all := StoryGates.all(w)
	eq(StoryGates.open(w).size(), 0, "nothing is open before anything is known")
	var first: Dictionary = all[0]
	# Landed as if long ago, the way 49_story stages --beats: a revelation is not
	# FELT until it has settled, and a gate waits on the feeling rather than the
	# landing.
	Story.beat(first.opens, -INF)
	var open := StoryGates.open(w)
	gt(open.size(), 0, "the beat lands and the way through opens")
	var ids := []
	for g: Dictionary in open:
		ids.append(g.id)
	check(ids.has(first.id), "and it is the gate that beat belongs to")
	Story.forget()


func test_every_gate_waits_on_a_beat_that_exists() -> void:
	# A gate whose `opens` names nothing is a frame standing in a field that the
	# story can never light, and it would look exactly like one the player has
	# not reached yet.
	var beats := StoryContent.all_beats()
	for g: Dictionary in StoryGates.GATES:
		check(beats.has(g.opens), "%s waits on %s, which is a beat" % [g.id, g.opens])
