extends TestCase

const SEEDS: Array[int] = [1, 2, 3, 42, 1337, 90210]


func test_deterministic_for_a_seed() -> void:
	var a := WorldGen.generate(7, 96)
	var b := WorldGen.generate(7, 96)
	check(a.level == b.level, "levels differ")
	check(a.ground == b.ground, "grounds differ")
	eq(a.props.size(), b.props.size(), "prop count")
	eq(a.spawn, b.spawn, "spawn")


func test_differs_between_seeds() -> void:
	var a := WorldGen.generate(1, 96)
	var b := WorldGen.generate(2, 96)
	check(a.level != b.level, "two seeds made the same land")


func test_every_seed_has_every_country_sea_rim_and_dry_spawn() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s)
		var present := {}
		for c in w.country:
			present[c] = true
		for c: int in Country.LAND:
			check(present.has(c), "seed %d missing country %s" % [s, Country.NAMES[c]])
		for i in w.size:
			check(w.level[i] <= 0, "seed %d north rim is land at x=%d" % [s, i])
			check(w.level[(w.size - 1) * w.size + i] <= 0, "seed %d south rim is land" % s)
		var g := w.ground_at(floori(w.spawn.x), floori(w.spawn.y))
		check(not Ground.is_water(g), "seed %d spawns in water" % s)


func test_every_seed_has_villages_and_ore() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s)
		gt(w.villages.size(), 1, "seed %d villages" % s)
		var ore := 0
		for p in w.props:
			if p.kind == PropKind.STONE_ORE or p.kind == PropKind.IRON_ORE:
				ore += 1
		gt(ore, 10, "seed %d ore nodes" % s)


func test_land_is_a_meaningful_share() -> void:
	var w := WorldGen.generate(3)
	var land := 0
	for l in w.level:
		if l > 0:
			land += 1
	var share := float(land) / w.level.size()
	gt(share, 0.3, "land share")
	lt(share, 0.8, "land share")
