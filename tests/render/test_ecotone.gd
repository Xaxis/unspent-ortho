extends TestCase
## A border between two landscapes is a BAND, not a line (docs/ART.md law 6:
## twelve to twenty-four tiles where the two hands interleave). The mesher
## already drew ragged patches of the neighbour's COUNTRY across that band —
## but a country is only a tint on the ground already there, and where two
## landscapes are laid with different grounds (pale limestone against ash) the
## tint is a fraction of the difference. So the band read as a seam with a
## ragged edge (art review 13). A patch drawn as its neighbour now carries that
## neighbour's GROUND: its marks, its hatch, and most of its value.


## A 128-tile world: bonelands laid on limestone west of x = 32, the burning laid
## on ash east of it, with a blend band twelve tiles each side of the border.
static func fixture() -> WorldData:
	var w := WorldData.new(21, 128)
	for y in 128:
		for x in 128:
			var i := y * 128 + x
			w.level[i] = 2
			var west := x < 32
			w.country[i] = Country.BONELANDS if west else Country.BURNING
			w.country2[i] = Country.BURNING if west else Country.BONELANDS
			w.ground[i] = Ground.LIMESTONE if west else Ground.ASH
			# 0.5 on the border, falling to 0 by twelve tiles (the contract).
			w.blend[i] = maxf(0.0, 0.5 - absf(float(x) - 31.5) / 12.0 * 0.5)
	# One road and one river across the whole band: neither is ever borrowed over.
	for x in 128:
		w.ground[20 * 128 + x] = Ground.ROAD
		w.ground[40 * 128 + x] = Ground.RIVER
	return w


func test_a_country_is_read_from_the_grounds_it_is_actually_laid_with() -> void:
	# No table of "what the burning is made of" anywhere: a landscape type added
	# tomorrow is tallied from the world like the rest.
	var m := TerrainMesher.new(fixture())
	eq(m._eco_ground[Country.BONELANDS * TerrainMesher.ECO_MENU], Ground.LIMESTONE, "the bonelands is limestone")
	eq(m._eco_ground[Country.BURNING * TerrainMesher.ECO_MENU], Ground.ASH, "the burning is ash")


func test_a_patch_drawn_as_its_neighbour_carries_the_neighbours_ground() -> void:
	var m := TerrainMesher.new(fixture())
	# Somewhere in the band, limestone standing in for the burning.
	var got := m._eco_borrow(Country.BURNING, Ground.LIMESTONE, 26.0, 26.0)
	eq(got, Ground.ASH, "a burning patch in the bonelands is laid with ash")
	eq(m._eco_borrow(Country.BONELANDS, Ground.ASH, 37.0, 26.0), Ground.LIMESTONE,
		"and a bonelands patch in the burning with limestone")


func test_water_and_made_ground_cross_a_border_as_themselves() -> void:
	# A river does not become ash because the country round it changed, and a
	# road the machines laid runs through a landscape, not into it.
	var m := TerrainMesher.new(fixture())
	eq(m._eco_borrow(Country.BURNING, Ground.RIVER, 26.0, 40.0), Ground.RIVER, "a river stays a river")
	eq(m._eco_borrow(Country.BURNING, Ground.ROAD, 26.0, 20.0), Ground.ROAD, "a road stays a road")
	eq(m._eco_borrow(Country.BURNING, Ground.FLOOR, 26.0, 20.0), Ground.FLOOR, "a floor stays a floor")


func test_the_band_holds_both_grounds_a_dozen_tiles_from_the_border() -> void:
	# The measure that matters: a chunk well inside the band must be MESHED with
	# both landscapes' grounds, not with one and a tinted copy of it.
	var m := TerrainMesher.new(fixture())
	var seen := {}
	for cx: int in [0, 1]:
		var ch := m.build(cx, 0)
		for k: int in ch.key:
			seen[k & 0xFF] = true
	check(seen.has(Ground.LIMESTONE), "the band still holds the bonelands' own ground")
	check(seen.has(Ground.ASH), "and the burning's, a dozen tiles into the bonelands")


func test_a_heartland_is_its_own_landscape_alone() -> void:
	# The band is twelve tiles: nothing of the neighbour beyond it, or every
	# landscape is a mixture of every other and none of them reads as itself.
	var m := TerrainMesher.new(fixture())
	var ch := m.build(3, 1)    # x 96..127, sixty tiles clear of the border
	var strays := 0
	for k: int in ch.key:
		if (k & 0xFF) == Ground.LIMESTONE:
			strays += 1
	eq(strays, 0, "no limestone in the burning's heartland")
