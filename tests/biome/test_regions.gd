extends TestCase
## Regions: the places a world is made of. A landscape type may hold several in
## one world, and a sentinel, a works network, a subarc and a save will all key
## on a region id (docs/VISION.md §3, §7.2).

const SEEDS: Array[int] = [1, 7, 42]
const SIZE := 256


func test_every_world_records_its_regions() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		gt(float(w.regions.size()), 5.0, "seed %d has places" % s)
		var seen := {}
		var tiles := 0
		for r in w.regions:
			eq(r.id, w.regions.find(r), "seed %d: ids run 0..n" % s)
			check(BiomeRegistry.get_def(r.type) != null, "seed %d: region %d is a landscape type (%s)" % [s, r.id, r.type])
			eq(BiomeRegistry.index_of(r.type), r.index, "seed %d: region %d index agrees with its type" % [s, r.id])
			gt(float(r.tiles), 0.0, "seed %d: region %d holds ground" % [s, r.id])
			var b: Rect2 = r.bounds
			gt(b.size.x * b.size.y, 0.0, "seed %d: region %d has bounds" % [s, r.id])
			check(b.has_point(r.centre), "seed %d: region %d centre lies in its bounds" % [s, r.id])
			seen[r.type] = int(seen.get(r.type, 0)) + 1
			tiles += int(r.tiles)
		# The landscapes of THIS world's realm: a world is one realm's world
		# (GenContext), so the ones registered under it are not in this island.
		for d: BiomeDef in BiomeRegistry.land_in(w.realm):
			check(seen.has(d.id), "seed %d: %s holds at least one region" % [s, d.id])
		var land := 0
		for c in w.country:
			if c != Country.SEA:
				land += 1
		gt(float(tiles) / maxf(1.0, land), 0.9, "seed %d: regions cover the land" % s)


func test_a_landscape_may_hold_several_places_in_one_world() -> void:
	var several := 0
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var by_type := {}
		for r in w.regions:
			by_type[r.type] = int(by_type.get(r.type, 0)) + 1
		for t: StringName in by_type:
			if int(by_type[t]) > 1:
				several += 1
	gt(float(several), 0.0, "some landscape lies in more than one place on some seed")


func test_region_at_agrees_with_the_record() -> void:
	var w := WorldGen.generate(7, SIZE)
	var checked := 0
	for y in range(0, w.size, 7):
		for x in range(0, w.size, 7):
			var id := w.region_at(x, y)
			if id < 0:
				check(true, "")
				continue
			var r := w.region_of(id)
			eq(r.index, w.country_at(x, y), "tile %d,%d belongs to a region of its own type" % [x, y])
			check((r.bounds as Rect2).has_point(Vector2(x, y)), "tile %d,%d lies in its region's bounds" % [x, y])
			checked += 1
	gt(float(checked), 100.0, "a real sample of tiles")
	eq(w.region_at(-1, 0), -1, "off the map belongs to no region")
