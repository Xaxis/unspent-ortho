extends TestCase
## A LANDSCAPE OF THE SHORE HOLDS NO PLACE THE SEA DOES NOT REACH
## (GenCountries._dry_shores). The coast, the drowned city and the frost sea keep
## their keepers and works at the water, and a region of one walled off from the
## sea had nowhere for them: 90210's coast r23 (9,485 tiles, 16 from the sea)
## and seed 1's frost sea r22 (13,822 tiles, 54 off). Every region of each, on
## both seeds at 1840, has ground within 4 tiles of the sea.

const REACH := 4.0


func test_every_shore_region_reaches_the_sea() -> void:
	for s: int in [1, 90210]:
		var w := WorldGen.generate(s, Tuning.WORLD_SIZE)
		var n := w.size
		var sea := PackedByteArray()
		sea.resize(n * n)
		for i in n * n:
			sea[i] = 1 if w.country[i] == Country.SEA else 0
		var dist := WorldGen.distance_field(sea, n)
		var nearest := {}
		for i in n * n:
			var rid := w.region[i] - 1
			if rid >= 0:
				nearest[rid] = minf(float(nearest.get(rid, INF)), dist[i])
		var shores := 0
		for r: Dictionary in w.regions:
			var def := BiomeRegistry.get_def(StringName(str(r.get("type", ""))))
			var rid := int(r.get("id", -1))
			if def == null or def.coastal < GenCountries.SHORE_BOUND or not nearest.has(rid):
				continue
			shores += 1
			lt(float(nearest[rid]), REACH + 0.01, "seed %d's %s region %d (%d tiles) reaches the sea" % [s, def.id, rid, int(r.get("tiles", 0))])
		gt(float(shores), 3.0, "seed %d has shore regions to hold to this (%d)" % [s, shores])
