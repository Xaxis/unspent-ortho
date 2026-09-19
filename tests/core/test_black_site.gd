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
		# NO SLACK. It used to allow 1.5 tiles either side, which was covering the
		# placer measuring its ray while recording a tile centre; the placer now
		# measures the place it writes down, so the rule it states is the rule.
		check(d >= BlackSite.NEAREST and d <= BlackSite.FURTHEST,
			"seed %d: %.1f tiles out, wanted %.0f-%.0f" % [s, d, BlackSite.NEAREST, BlackSite.FURTHEST])
		eq(w.ground_at(floori(p.x), floori(p.y)), Ground.DEEP_WATER, "seed %d: it is in deep water" % s)


func test_nobody_walks_to_it() -> void:
	# **A STRAIGHT LINE IS NOT THE QUESTION.** This used to lerp from the spawn to
	# the site and count dry tiles after the first wet one, which is wrong twice
	# over: it walks a line the placer never walked (`_look` steps along one of 72
	# fixed bearings and writes down a tile CENTRE, so the two diverge by half a
	# tile and, at range, by a whole one), and a sandbar off to the side is not a
	# way to anything. It failed seed 1 on a spit that goes nowhere while missing
	# the real wade on the other three: the site stood on one deep tile in a shelf
	# of shallows and a walker strolled to within a tile of the ladder.
	#
	# So ask what the story actually says -- that he is reached by raft. Flood the
	# island with everything a body that CANNOT swim may stand on, and find how
	# near that gets. Anything inside `MOAT` is a wade, whatever line it took.
	for s: int in SEEDS:
		var w := WorldGen.generate(s, 256)
		var p := BlackSite.site(w)
		if p == Vector2.INF:
			continue
		var q := WorldQuery.new(w)
		var goal := Vector2(floori(p.x), floori(p.y))
		var start := Vector2i(floori(w.spawn.x), floori(w.spawn.y))
		var seen := {start: true}
		var edge: Array[Vector2i] = [start]
		var nearest := INF
		while not edge.is_empty():
			var at: Vector2i = edge.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := at + d
				if seen.has(n) or not w.in_bounds(n.x, n.y):
					continue
				if not q.passable(at.x, at.y, n.x, n.y, null, false):
					continue
				seen[n] = true
				nearest = minf(nearest, Vector2(n).distance_to(goal))
				edge.append(n)
		check(nearest >= BlackSite.MOAT,
			"seed %d: a body that cannot swim walks within %.1f tiles of it, so it is waded to (wanted %.1f)"
				% [s, nearest, BlackSite.MOAT])


func test_it_is_derived_and_the_same_every_time() -> void:
	for s: int in SEEDS:
		var a := BlackSite.site(WorldGen.generate(s, 256))
		var b := BlackSite.site(WorldGen.generate(s, 256))
		check(a.is_equal_approx(b), "seed %d: the same water both times" % s)
