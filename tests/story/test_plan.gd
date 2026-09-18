extends TestCase
## The guided path, held to being a path (docs/STORY_SYSTEM.md §6).
##
## The owner's ruling is that a procedurally generated world still offers a
## general guided path to success. That is a promise about every seed, and this is
## the only thing that makes it worth anything: worlds are really generated, the
## spine is really cast into them, and a slot that cannot be filled fails here
## rather than in front of somebody playing.

const SEEDS: Array[int] = [1, 7]
const SIZE := 256


func test_the_spine_asks_for_nothing_a_world_may_not_carry() -> void:
	# No world needed: this half is about what the story DECLARES, and it is the
	# rule that keeps a player from being stranded by a landscape that a given
	# world was never dealt (docs/WORLD.md §spread).
	var bad := StoryPlan.problems(null)
	check(bad.is_empty(), "\n  ".join(bad))


func test_every_required_slot_casts_in_a_world_that_was_really_grown() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var bad := StoryPlan.problems(w)
		check(bad.is_empty(), "seed %d:\n  %s" % [s, "\n  ".join(bad)])


func test_casting_is_the_same_every_time_a_seed_is_grown() -> void:
	# Casting stays out of the save because it can be recomputed. That is only
	# true while it is deterministic — a save that reopened onto a thread which
	# had moved would be worse than one that refused to open.
	for s in SEEDS:
		var a := StoryPlan.cast(WorldGen.generate(s, SIZE))
		var b := StoryPlan.cast(WorldGen.generate(s, SIZE))
		eq(a.size(), b.size(), "seed %d casts the same number of slots" % s)
		for id: StringName in a:
			check(b.has(id), "seed %d casts %s both times" % [s, id])
			if b.has(id):
				eq(a[id].pos as Vector2, b[id].pos as Vector2, "seed %d puts %s in the same place" % [s, id])


func test_a_slot_is_cast_somewhere_the_spine_can_use() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var done := StoryPlan.cast(w)
		for id: StringName in done:
			var p: Vector2 = done[id].pos
			check(p.x >= 0.0 and p.y >= 0.0 and p.x < float(w.size) and p.y < float(w.size),
				"seed %d: %s is inside the world" % [s, id])
		# The slots that asked to be clear of the fire are clear of it, or "walk
		# to it" means "it was already under your boots".
		for sl: StorySlot in StoryPlan.slots():
			if sl.apart <= 0.0 or not done.has(sl.id):
				continue
			var at: Vector2 = done[sl.id].pos
			gt(at.distance_to(w.spawn), sl.apart - 0.001,
				"seed %d: %s stands %.0f from the spawn, and asked for %.0f" % [s, sl.id, at.distance_to(w.spawn), sl.apart])


func test_what_the_story_calls_guaranteed_is_in_every_world_it_grows() -> void:
	# `StoryWorld.guaranteed` is a PROMISE — today a hand-written one, later the
	# dealer's `spread.least`. The world is the FACT. Until some landscape carries a
	# floor, nothing else in the repo checks the two against each other, so the
	# story checks it from its own side: every landscape it may lean on is really
	# there, in worlds that were really grown (unspent-ortho-df, 2026-09-18).
	var leaned_on: Array[StringName] = []
	for d: BiomeDef in BiomeRegistry.all():
		if StoryWorld.guaranteed(d.id):
			leaned_on.append(d.id)
	check(not leaned_on.is_empty(), "the story leans on at least the coast")
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var found := {}
		for y in range(0, w.size, 2):
			for x in range(0, w.size, 2):
				var def := BiomeRegistry.at(w, Vector2(x + 0.5, y + 0.5))
				if def != null:
					found[def.id] = true
		for land: StringName in leaned_on:
			check(found.has(land), "seed %d holds %s, which the story was promised it always would" % [s, land])


## The story spans every continent in order (owner, 2026-09-18), so a world big
## enough to hold several must put each leg on its own land, farther out each time.
func test_the_journey_crosses_the_continents_in_order() -> void:
	for s: int in [1, 7]:
		_crosses_in_order(WorldGen.generate(s, 1024))


func _crosses_in_order(w: WorldData) -> void:
	var order := StoryJourney.bodies(w)
	gt(float(order.size()), 1.0, "a big world holds more than one continent to cross")
	eq(order[0], w.continent_at(floori(w.spawn.x), floori(w.spawn.y)), "the journey starts where he wakes")
	var bad := StoryPlan.problems(w)
	check(bad.is_empty(), "every required slot casts across the continents:\n  %s" % "\n  ".join(bad))
	var done := StoryPlan.cast(w)
	var last_leg := -1
	var last_rank := -1
	for sl: StorySlot in StoryPlan.slots():
		if not done.has(sl.id):
			continue
		var p: Vector2 = done[sl.id].pos
		var rank := order.find(int(done[sl.id].body))
		check(rank >= 0, "%s is cast on a body of the journey" % sl.id)
		if sl.needs != StorySlot.BLACK_SITE:
			eq(int(done[sl.id].body), w.continent_at(floori(p.x), floori(p.y)), "%s stands on the body it was cast on" % sl.id)
		gt(float(rank), float(mini(sl.leg, order.size() - 1)) - 0.5, "%s stands no nearer home than its own leg" % sl.id)
		gt(float(rank), float(last_rank) - 0.5, "%s is no nearer home than the slot before it" % sl.id)
		last_rank = rank
		last_leg = sl.leg


func test_a_one_island_world_still_holds_the_whole_journey() -> void:
	# Every test and tour size is one island: the later legs share it.
	var w := WorldGen.generate(1, SIZE)
	eq(StoryJourney.bodies(w).size(), 1, "a small world is one island")
	for sl: StorySlot in StoryPlan.slots():
		eq(StoryJourney.body_for(w, sl.leg), StoryJourney.bodies(w)[0], "%s's leg folds onto the island" % sl.id)
