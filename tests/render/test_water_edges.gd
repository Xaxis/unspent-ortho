extends TestCase
## Foam belongs to the sea on a shore that shelves. The moss is "black water
## with green edges" (docs/ART.md section 3): the art review found a near-white
## lapping band round a water body sitting on peat, a 180-luma jump and the
## brightest thing in the landscape. The mesher decides this, from the nearest
## land's `wet` hazard (BiomeRegistry), never from a country.


## A 48-tile world: sea on the west, land east of x = 10. `wet_land` makes that
## land the moss (wet 0.6) instead of the coast (wet 0.3). A river runs at
## x = 30..32 on the land.
static func fixture(wet_land: bool) -> WorldData:
	var w := WorldData.new(11, 48)
	for y in 48:
		for x in 48:
			var i := y * 48 + x
			var l := -1 if x < 7 else (0 if x < 10 else 2)
			w.level[i] = l
			w.country[i] = Country.SEA if l <= 0 else (Country.MOSS if wet_land else Country.COAST)
			var g := Ground.GRASS if not wet_land else Ground.PEAT
			if l < 0:
				g = Ground.DEEP_WATER
			elif l == 0:
				g = Ground.WATER
			elif x >= 30 and x < 33:
				g = Ground.RIVER
			w.ground[i] = g
	return w


func test_a_bog_bank_takes_no_surf_and_an_open_coast_does() -> void:
	var dry := TerrainMesher.new(fixture(false))
	var wet := TerrainMesher.new(fixture(true))
	# Just off the waterline, where the foam is drawn.
	near(dry._surf_at(9.0, 20.0), 1.0, 0.001, "the coast breaks white")
	near(wet._surf_at(9.0, 20.0), 0.0, 0.001, "peat takes no surf")
	# Far out, with no land within reach, the sea is the sea.
	near(wet._surf_at(0.0, 20.0), 1.0, 0.001, "open water")


func test_inland_water_in_a_bog_is_black_water() -> void:
	var dry := TerrainMesher.new(fixture(false))
	var wet := TerrainMesher.new(fixture(true))
	var key := Ground.RIVER
	eq(dry._inland_kind(key, 31.0, 20.0), 1, "a coast river is a plain sheet")
	eq(wet._inland_kind(key, 31.0, 20.0), 2, "a river in the moss is black water")
	eq(dry._inland_kind(Ground.BLACKWATER, 31.0, 20.0), 2, "blackwater is always black water")


func test_the_sea_carries_the_weight_to_the_shader() -> void:
	# COLOR.g on a sea vertex is the surf weight; the shader must use it for the
	# foam and for the pale chart shallows, or the rule is only written down.
	var m := TerrainMesher.new(fixture(true))
	var ch := m.build(0, 0)
	check(ch.water != null, "the chunk has water")
	var cols: PackedColorArray = ch.water.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var lowest := 9.0
	for c in cols:
		if c.r < 0.01:
			lowest = minf(lowest, c.g)
	lt(lowest, 0.01, "the sea against peat carries no surf")
	var src := FileAccess.get_file_as_string("res://src/render/water.gdshader")
	check(src.contains("float surf = clamp(COLOR.g, 0.0, 1.0);"), "the shader reads the weight")
	check(src.contains("FOAM, surf"), "foam is weighted by it")


func test_an_open_coast_keeps_its_foam() -> void:
	var m := TerrainMesher.new(fixture(false))
	var ch := m.build(0, 0)
	var cols: PackedColorArray = ch.water.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var best := 0.0
	for c in cols:
		if c.r < 0.01:
			best = maxf(best, c.g)
	gt(best, 0.99, "a shelving shore still breaks white")
