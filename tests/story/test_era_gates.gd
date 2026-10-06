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
const Sx := preload("res://tests/save/save_fixture.gd")


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


## THE PRESS BESIDE SOMEBODY IS THEIRS, NOT THE GATE'S. 2029's people stood round
## the slot its gate stood on, and beside June, six, in the house she grew up in,
## the gate's reach caught the key: before.tour pressed to speak to her and was
## back in 2098. Nobody is cast in a gate's reach now, but a scene may stand
## anyone anywhere, so like a cache (22_landmarks `_cache_wins`), a gate takes
## the press only when nothing in front of him has words.
func test_the_press_beside_somebody_at_a_gate_speaks_to_them() -> void:
	Story.forget()
	Sx.use_root("era-gate-press")
	var g := Sx.game(tree, ["--seed=1", "--realm=era", "--hour=2", "--weather=clear:0", "--beats=body_new"])
	await frames(3)
	var cast := Sx.system(g, "49_cast")
	var realms := Sx.system(g, "20_realms")
	# Nobody is CAST in a gate's reach now (49_cast `_taken`), so she is stood in
	# it, as a scene may stand anyone anywhere (49_cast `stand`), and he beside her
	# facing her: the press must still be hers.
	var gate := Vector2.INF
	for row: Dictionary in StoryGates.all(g.world):
		if row.id == &"gate_home":
			gate = row.pos
	check(gate.is_finite(), "his house's gate stands in 2029")
	var her := gate + Vector2(0.8, 0.0)
	check((cast.call(&"stand", &"june_young", her, PI) as Vector2).is_finite(), "June is cast in 2029")
	g.view.ensure_near(g.player.place(gate + Vector2(-0.4, 0.0)))
	Survival.face(g, 0.0)
	# Past the arrival's settle (20_realms SETTLE), in the world's own time.
	await tree.create_timer(1.0).timeout
	eq(realms.get("gate_near"), &"gate_home", "beside her, he stands in the gate's reach")
	check(not bool(realms.call(&"use_spent")), "and nothing has spent the key")
	check(bool(Sx.system(g, "49_story").call(&"faces_words")), "and faces her")
	Input.action_press(&"use")
	await frames(3)
	Input.action_release(&"use")
	await frames(3)
	eq(StringName(realms.get("_realm")), Realm.ERA, "the press beside her keeps him in 2029")
	check(bool(Sx.system(g, "49_story").call(&"tour_seen", &"talking")), "and speaks to her")
	Sx.end(g)
	Story.forget()



## A PRESS OUT OF A GATE'S REACH IS NOT THE GATE'S. 20_realms looks for the gate
## a body stands in every LOOK_EVERY, and a press made between two looks, after a
## step or a warp out of its reach, was answered by the gate he had left:
## holdfast.tour stood at Oyster Row beside its gate, warped to the driftwood and
## pressed to gather, and was in 2029. The look is held off here, as it is for up
## to LOOK_EVERY after any step.
func test_a_press_out_of_a_gates_reach_stays_in_2098() -> void:
	Story.forget()
	Sx.use_root("era-gate-left")
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--beats=body_new"])
	await process_frames(3)
	var realms := Sx.system(g, "20_realms")
	var gate := Vector2.INF
	for row: Dictionary in StoryGates.all(g.world):
		if row.id == &"gate_home":
			gate = row.pos
	check(gate.is_finite(), "his house's gate stands in 2098")
	g.view.ensure_near(g.player.place(gate))
	await tree.create_timer(1.0).timeout
	eq(realms.get("gate_near"), &"gate_home", "standing in it, he is in its reach")
	realms.set("_look", 10.0)
	var out := g.player.place(gate + Vector2(6.0, 0.0))
	g.view.ensure_near(out)
	check(out.distance_to(gate) > GateStand.REACH, "and then out of it (%.1f off)" % out.distance_to(gate))
	Input.action_press(&"use")
	await process_frames(3)
	Input.action_release(&"use")
	await process_frames(3)
	eq(StringName(realms.get("_realm")), Realm.SURFACE, "a press made out of its reach stays in 2098")
	Sx.end(g)
	Story.forget()
