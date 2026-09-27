extends TestCase
## Regions are the plan's (streamed worldgen S4e4). Which runs of a landscape
## are places, how big, and which is biggest are asked of the plan's coarse
## cells (`WorldData.plan_country`); a tile takes its region from those cells
## and its own landscape. So a section's tiles, with no margin at all, get the
## regions the composed world gives them, and the world's region records are
## what the plan's cells alone make.

const SIZE := 512
const SEEDS: Array[int] = [1, 42, 90210]
const SIDE := 96
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(130, 200), Vector2i(256, 96), Vector2i(416, 416), Vector2i(300, 380)]


func test_a_section_gives_its_tiles_the_regions_the_world_does() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var cw := GenFields.coarse_width(SIZE, GenContext.STEP)
		eq(w.plan_country.size(), cw * cw, "seed %d: the world keeps the plan's cells" % s)
		var held := 0
		for at in CORNERS:
			var country := PackedByteArray()
			country.resize(SIDE * SIDE)
			for y in SIDE:
				for x in SIDE:
					country[y * SIDE + x] = w.country[(at.y + y) * SIZE + at.x + x]
			var region := PackedInt32Array()
			region.resize(SIDE * SIDE)
			GenCountries.tile_regions(country, SIDE, at, w.plan_cells, w.plan_country, cw, GenContext.STEP, SIZE, region)
			var bad := 0
			for y in SIDE:
				for x in SIDE:
					var mine := region[y * SIDE + x]
					if mine != w.region[(at.y + y) * SIZE + at.x + x]:
						bad += 1
					if mine > 0:
						held += 1
			eq(bad, 0, "seed %d: the section at %s gives its tiles the world's regions" % [s, at])
		gt(held, SIDE * SIDE, "seed %d: the sections hold places" % s)


func test_the_world_holds_the_regions_its_plan_makes() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var cw := GenFields.coarse_width(SIZE, GenContext.STEP)
		var plan := GenCountries.plan_regions(w.plan_country, cw, GenContext.STEP, SIZE, BiomeRegistry.land_indices_in(w.realm).size())
		var made: Array = plan.regions
		eq(made.size(), w.regions.size(), "seed %d: as many regions as the plan makes" % s)
		for r in mini(made.size(), w.regions.size()):
			eq(made[r].type, w.regions[r].type, "seed %d: region %d's landscape" % [s, r])
			eq(made[r].tiles, w.regions[r].tiles, "seed %d: region %d's size" % [s, r])
			eq(made[r].bounds, w.regions[r].bounds, "seed %d: region %d's bounds" % [s, r])
