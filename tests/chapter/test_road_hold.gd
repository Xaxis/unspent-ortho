extends TestCase
## Preloaded rather than named: a `class_name` resolves out of Godot's global
## class cache, which the tools refresh and a player's own run does not.
const Hold := preload("res://src/core/chapter/road_hold.gd")
## Where the plan stands on the road out of a chapter (docs/VISION.md §10.3).

const SEEDS: Array[int] = [1, 7]


func test_a_hold_stands_on_a_road_inside_the_region_that_keeps_it() -> void:
	# The two things that make it a checkpoint rather than a wall: it is ON the
	# carriageway, and it is IN one region, so it never has to know which way a
	# body is walking.
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 512)
		var holds := Hold.sites(w)
		for h: Hold.HoldSite in holds:
			var x := floori(h.pos.x)
			var y := floori(h.pos.y)
			check(w.on_road(x, y), "seed %d: a hold at %s stands on a road" % [s, str(h.pos)])
			eq(w.region_at(x, y), h.region,
				"seed %d: a hold at %s stands in the region it says it does" % [s, str(h.pos)])
			check(h.beyond != h.region, "seed %d: a hold leads somewhere else" % s)
			near(h.along.length(), 1.0, 1e-3, "seed %d: it knows the road's heading" % s)


func test_a_hold_is_where_the_road_really_changes_region() -> void:
	# The premise the whole thing rests on: there IS a tile beyond it that is the
	# other region. Asserted rather than assumed, because a derivation that
	# quietly found nothing would leave every chapter unheld and look identical
	# to one that decided nothing needed holding.
	var found := 0
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 512)
		for h: Hold.HoldSite in Hold.sites(w):
			found += 1
			# **NOT ALONG A STRAIGHT LINE.** Walking `along` from the hold was the
			# first version of this and it failed: a road curves, so a heading
			# taken at the barrier stops following it within a few tiles. That is
			# the same mistake the black site's old siting made. Scan the ground
			# near it instead -- the claim is that the other region is JUST
			# THERE, which is what makes this a border crossing and not a
			# checkpoint in the middle of a landscape.
			var beyond_seen := false
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					if w.region_at(floori(h.pos.x) + dx, floori(h.pos.y) + dy) == h.beyond:
						beyond_seen = true
						break
				if beyond_seen:
					break
			check(beyond_seen, "seed %d: the hold at %s stands within sight of %d" % [s, str(h.pos), h.beyond])
	gt(float(found), 0.0, "the seeds hold some roads at all")


func test_it_is_derived_and_the_same_every_time() -> void:
	# Pure, like `Works.sites` and `BlackSite.site`: nothing here is saved, so a
	# loaded game and a fresh one have to agree tile for tile.
	var a := Hold.sites(WorldGen.generate(7, 512))
	var b := Hold.sites(WorldGen.generate(7, 512))
	eq(a.size(), b.size(), "the same holds both times")
	for i in mini(a.size(), b.size()):
		check(a[i].pos.is_equal_approx(b[i].pos), "hold %d is in the same place" % i)
		eq(a[i].region, b[i].region, "hold %d belongs to the same region" % i)


func test_one_crossing_is_held_once() -> void:
	# A road that wanders over a border and back is one way out, not three
	# checkpoints in a row.
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 512)
		var holds := Hold.sites(w)
		for i in holds.size():
			for j in range(i + 1, holds.size()):
				var gap := holds[i].pos.distance_to(holds[j].pos)
				# The declared rule, AND a floor that does not depend on it.
				# Reading `APART` alone made this unable to fail for the thing it
				# names: set the constant to nothing and the bar goes with it, so
				# a world with three checkpoints on one tile passed. A number a
				# test takes from the code it is checking is not a check.
				gt(gap, Hold.APART - 0.001,
					"seed %d: two holds at %s and %s are one crossing" % [s, str(holds[i].pos), str(holds[j].pos)])
				gt(gap, 2.0, "seed %d: and never two barriers on top of each other" % s)


func test_a_region_can_be_asked_for_its_own_holds() -> void:
	# What a chapter opens when it is answered.
	var w := WorldGen.generate(1, 512)
	var all := Hold.sites(w)
	if all.is_empty():
		return
	var id := all[0].region
	var mine := Hold.of_region(w, id)
	gt(float(mine.size()), 0.0, "the region keeps at least the one")
	for h: Hold.HoldSite in mine:
		eq(h.region, id, "and only its own")
