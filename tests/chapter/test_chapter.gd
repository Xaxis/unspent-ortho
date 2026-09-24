extends TestCase
## A region is a chapter: explored, mined and defended before the way on opens
## (docs/VISION.md).
##
## What these hold is the claim the whole shape rests on — **a chapter invents
## nothing**. Every demand is read off state the game already keeps, so a player
## who did the work before this file existed has already answered the chapter, and
## there is no second counter to fall out of step with the world.

const Worlds := preload("res://tests/core/test_world_gen.gd")


## The biggest region of a world, which is the one most likely to hold everything
## a chapter reads: landmarks, ore and a keeper.
func _big(w: WorldData) -> int:
	var best := -1
	var most := 0
	for r: Dictionary in w.regions:
		var t := int(r.get("tiles", 0))
		if t > most and not BiomeRegistry.get_def(StringName(str(r.get("type", &"")))).sea:
			most = t
			best = int(r.get("id", -1))
	return best


func test_a_chapter_asks_for_what_the_region_actually_holds() -> void:
	var w := Worlds.world(Worlds.WORLD_SEEDS[0])
	var id := _big(w)
	gt(float(id), -1.0, "the world has a region to be a chapter")
	var d := Chapter.read(w, id, {}, false, false)
	# It never asks for more than is there, which is the whole reason the demand
	# is a share and not a number: a count right for a pinewood is a grind in a
	# coast and a formality in a spur.
	check(int(d.want_ore) <= int(d.ore), "never asks for more ore than the region holds")
	check(int(d.want_seen) <= int(d.landmarks), "never asks for more landmarks than it has")
	if int(d.ore) > 0:
		gt(float(d.want_ore), 0.0, "a region with ore in it asks for some")
		check(int(d.want_ore) <= Chapter.MINE_MOST, "and never more than a shift's worth")


func test_nothing_is_answered_by_a_player_who_has_done_nothing() -> void:
	var w := Worlds.world(Worlds.WORLD_SEEDS[0])
	var id := _big(w)
	var d := Chapter.read(w, id, {}, false, false)
	check(not bool(d.answered), "a chapter nobody has touched is not answered")
	check(not bool(d.defended), "and the plan still holds it")


func test_defended_is_either_half_and_the_keeper_is_not_the_only_way() -> void:
	# `SentinelWay` offers three ways to take a keeper and `34_works` says a
	# broken depot quiets a region for good. A chapter that only counted the kill
	# would have quietly deleted two thirds of the ways this game offers.
	var w := Worlds.world(Worlds.WORLD_SEEDS[0])
	var id := _big(w)
	check(bool(Chapter.read(w, id, {}, true, false).defended), "the keeper taken is enough")
	check(bool(Chapter.read(w, id, {}, false, true).defended), "the yard put dark is enough")


func test_mined_is_read_off_the_world_edits_and_not_off_a_counter() -> void:
	# THE POINT OF THE WHOLE FILE. Take the region's ore out of the world the way
	# the game takes it — `WorldData.depleted`, which is what a save carries — and
	# the demand answers itself. Nothing was told that anything happened.
	var w := Worlds.world(Worlds.WORLD_SEEDS[0])
	var id := _big(w)
	var kinds := Chapter.ore_kinds(w, id)
	if kinds.is_empty():
		unmeasured("this seed's biggest region declares no ore", 0.0, 1.0)
		return
	var want := int(Chapter.read(w, id, {}, false, false).want_ore)
	var took := 0
	var before: Dictionary = w.depleted.duplicate()
	for p: WorldProp in w.props:
		if took >= want:
			break
		if kinds.has(p.kind) and w.region_at(floori(p.pos.x), floori(p.pos.y)) == id:
			w.depleted[p.id] = true
			took += 1
	var d := Chapter.read(w, id, {}, false, false)
	check(bool(d.mined), "taking the region's own ore answers MINED, with nothing counting")
	eq(int(d.taken), took, "and what it reads back is what was taken")
	w.depleted = before


func test_explored_is_the_regions_own_landmarks_and_a_bare_region_is_not_held_shut() -> void:
	var w := Worlds.world(Worlds.WORLD_SEEDS[0])
	var bare := -1
	var rich := -1
	for r: Dictionary in w.regions:
		var id := int(r.get("id", -1))
		var n := Chapter.landmark_ids(w, id).size()
		if n == 0 and bare < 0:
			bare = id
		if n >= 2 and rich < 0:
			rich = id
	if bare >= 0:
		check(bool(Chapter.read(w, bare, {}, false, false).explored),
			"a region with nothing worth the walk in it is explored by being crossed")
	if rich >= 0:
		var all := {}
		for id: StringName in Chapter.landmark_ids(w, rich):
			all[id] = true
		check(bool(Chapter.read(w, rich, all, false, false).explored), "finding them all answers it")
		check(not bool(Chapter.read(w, rich, {}, false, false).explored), "finding none does not")


func test_a_chapter_is_answered_only_when_all_three_are() -> void:
	var w := Worlds.world(Worlds.WORLD_SEEDS[0])
	var id := _big(w)
	var all := {}
	for sid: StringName in Chapter.landmark_ids(w, id):
		all[sid] = true
	# Explored and defended, but nothing taken out of the ground.
	var d := Chapter.read(w, id, all, true, false)
	if int(d.want_ore) > 0:
		check(not bool(d.answered), "two of three is not a chapter answered")
	var kinds := Chapter.ore_kinds(w, id)
	var before: Dictionary = w.depleted.duplicate()
	var took := 0
	for p: WorldProp in w.props:
		if took >= int(d.want_ore):
			break
		if kinds.has(p.kind) and w.region_at(floori(p.pos.x), floori(p.pos.y)) == id:
			w.depleted[p.id] = true
			took += 1
	check(bool(Chapter.read(w, id, all, true, false).answered), "all three is")
	w.depleted = before


## The one door a live game asks through, so the story, the way on, the slate and
## dev mode can never disagree about whether a place is done.
func test_the_door_answers_for_a_running_game() -> void:
	var o := BootOptions.new()
	# **A 64-TILE WORLD HAS NO CHAPTER FOR THE PLAYER TO BE STANDING IN.** 64
	# squared holds about 1,500 tiles of land in total, and it raised at most one
	# region -- not where the player wakes. `Chapters.here` then answered {}, and
	# the line below read `here.get("answered", true)` off an EMPTY dictionary and
	# got its own DEFAULT back. So the second failure was never a computation: a
	# missing key reported as a finished chapter.
	#
	# (An earlier version of this comment blamed a chapter that "asks nothing"
	# being born answered. It is not: `defended` is `keeper_down or yard_broken`
	# and both are false where neither ever existed. Wrong cause, right symptom.)
	# **AND 512, NOT 256, BECAUSE THE PLAYER HAS TO WAKE IN A PLACE.** Measured
	# at GEN 24: the spawn stands in a region on 11 of seeds 1-12 at 256, all 12 at
	# 512, and on 1, 42 and 90210 at the shipped 1840. Seed 1 at 256 is the one
	# whose coast offers no village that is both inside a region and on a beach the
	# black site can stand off, and the black site is the spine's; so there the
	# spawn goes to the beach and stands in no region at all. This test is about
	# the door, not about that one island.
	o.size = 512
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	await frames(4)
	var here := Chapters.here(g)
	check(not here.is_empty(), "the player is standing in a region, and it is a chapter")
	# **THE KEY IS ASKED FOR, NOT DEFAULTED.** `get("answered", true)` answered
	# this question ITSELF whenever the dictionary was empty, and that is how a
	# player standing in no region at all read as a finished chapter. A default on
	# a "is this done" question is the caller supplying the evidence and then
	# believing it.
	check(here.has("answered"), "the chapter says whether it is answered")
	eq(bool(here.get("answered", true)), false, "and a chapter nobody has touched is not answered")
	check(Chapters.found_of(g) != null, "the door finds the landmark memory by what it keeps")
	# A region nobody laid answers without erroring: the door is asked by the UI
	# every frame and must never be the thing that breaks a frame.
	var none := Chapters.of(g, -1)
	check(none.has("answered"), "a region nobody laid still answers the question")
	eq(bool(none.get("answered", true)), false, "no region, nothing answered, no error")
	g.queue_free()
	await frames(1)
