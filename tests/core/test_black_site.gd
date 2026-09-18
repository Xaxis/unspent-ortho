extends TestCase
## The old THRESHOLD site: offshore of the home coast, seen from the beach, not
## walked to. Derived and never saved, so a seed always puts it in the same water.

const SEEDS: Array[int] = [1, 42, 90210, 7]


func test_it_stands_in_open_water_off_the_spawn() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 256)
		var p := BlackSite.site(w)
		check(p != Vector2.INF, "seed %d: the spawn has sea off it" % s)
		if p == Vector2.INF:
			continue
		var d := p.distance_to(w.spawn)
		check(d >= BlackSite.NEAREST - 1.5 and d <= BlackSite.FURTHEST + 1.5,
			"seed %d: %.1f tiles out, wanted %.0f-%.0f" % [s, d, BlackSite.NEAREST, BlackSite.FURTHEST])
		eq(w.ground_at(floori(p.x), floori(p.y)), Ground.DEEP_WATER, "seed %d: it is in deep water" % s)


func test_nobody_walks_to_it() -> void:
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 256)
		var p := BlackSite.site(w)
		if p == Vector2.INF:
			continue
		# The spawn stands beside a village, not on the sand, so the first tiles
		# toward the sea are dry and that is the beach. What matters is that once
		# the way out is IN the water it stays in the water: no bar, no spit, no
		# stepping stones. Only a craft crosses it.
		var steps := int(p.distance_to(w.spawn))
		var afloat := false
		var dry_after := 0
		for i in range(1, steps):
			var q := w.spawn.lerp(p, float(i) / float(steps))
			var wet := Ground.is_water(w.ground_at(floori(q.x), floori(q.y)))
			if wet:
				afloat = true
			elif afloat:
				dry_after += 1
		check(afloat, "seed %d: there is water between the spawn and it" % s)
		eq(dry_after, 0, "seed %d: %d dry tiles once out of the shallows, so it could be waded to" % [s, dry_after])


func test_it_is_derived_and_the_same_every_time() -> void:
	for s: int in SEEDS:
		var a := BlackSite.site(WorldGen.generate(s, 256))
		var b := BlackSite.site(WorldGen.generate(s, 256))
		check(a.is_equal_approx(b), "seed %d: the same water both times" % s)
