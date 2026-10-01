extends TestCase
## THE MOSS'S FEN (BogFen; matter.gdshaderinc bog_wet and bog_hummock;
## world.gdshader bog_floor and bog_water; Decor.fen_share). On main the fen was
## a flat teal print with its sedge and bog cotton laid evenly over all of it,
## and its water a few dark dots. A fen reads as one by its wet: standing water
## in the hollows, a sodden margin round them, and the sphagnum lawn as the
## ground, with the sedge ringing the pools and the cotton drifting by them.

const MATTER := "res://src/render/matter.gdshaderinc"
## Where the samples are taken, clear of the origin's lattice symmetry.
const AT := Vector2(811.0, 907.0)


func _shares(n: int, y: float) -> Vector2:
	var water := 0
	var margin := 0
	for j in n:
		for i in n:
			var w := BogFen.wet(AT.x + i, AT.y + j, y)
			if w > BogFen.WATER:
				water += 1
			elif w > BogFen.MARGIN:
				margin += 1
	return Vector2(water, margin) / float(n * n)


func test_the_shader_draws_the_fen_from_bog_fens_own_numbers() -> void:
	# The decor stands where BogFen says and the ground draws where the shader
	# says: one number moved alone and the sedge rings nothing.
	var src := FileAccess.get_file_as_string(MATTER)
	for want: String in [
			"const float BOG_MARGIN = %s;" % BogFen.MARGIN,
			"const float BOG_WATER = %s;" % BogFen.WATER,
			"vec2 w = vec2(lattice_noise(p * %s + 5.0), lattice_noise(p * %s + 23.0)) - 0.5;" % [BogFen.BEND, BogFen.BEND],
			"float d = lattice_fbm(p * %s + w * %s);" % [BogFen.SCALE, BogFen.BEND_REACH],
			"return d + clamp((%s - y) / %s, -1.0, 1.0) * %s;" % [BogFen.LOW, BogFen.DEEP, BogFen.SINK]]:
		check(src.contains(want), "matter.gdshaderinc's fen says `%s`, as BogFen does" % want)


func test_the_moss_is_the_ground_and_the_water_lies_in_it() -> void:
	# Fewer pools than moss: standing water on a tenth to a fifth of the fen at
	# its middle height, a sodden margin about as much again.
	var s := _shares(220, 1.5)
	gt(s.x, 0.08, "the fen holds standing water (%.2f)" % s.x)
	lt(s.x, 0.22, "and the sphagnum is the ground (%.2f under water)" % s.x)
	gt(s.y, 0.05, "with a sodden margin round it (%.2f)" % s.y)


func test_the_low_fen_is_wetter_than_the_high() -> void:
	var low := _shares(150, 0.5).x
	var high := _shares(150, 3.0).x
	gt(low, high + 0.03, "water gathers in the low ground (%.2f against %.2f)" % [low, high])


func test_the_sedge_rings_the_pools_and_the_cotton_drifts_by_them() -> void:
	var dry := BogFen.MARGIN - 0.1
	var margin := (BogFen.MARGIN + BogFen.WATER) * 0.5
	var deep := BogFen.WATER + 0.08
	gt(Decor.fen_share(Decor.GRASS_A, margin), Decor.fen_share(Decor.GRASS_A, dry) * 4.0,
		"the sedge stands thick on the margin and scarce out on the lawn")
	eq(Decor.fen_share(Decor.GRASS_B, dry), 0.0, "no bog cotton out on the dry lawn")
	gt(Decor.fen_share(Decor.GRASS_B, margin), 0.9, "and the cotton drifts on the margin")
	for kind: int in [Decor.GRASS_A, Decor.GRASS_B, Decor.SPHAGNUM, Decor.TUFT, Decor.FLOWER]:
		eq(Decor.fen_share(kind, deep), 0.0, "nothing of kind %d stands out in the water" % kind)
	gt(Decor.fen_share(Decor.SPHAGNUM, dry), 0.9, "and the lawn keeps its own")


func test_only_the_moss_fen_is_gated_by_its_wet() -> void:
	# The decor reads the fen's wet on ground drawn as the bog floor, and on no
	# other: the coast's turf and a fen anywhere else keep their own tables.
	var moss := BiomeRegistry.index_of(&"moss")
	var coast := BiomeRegistry.index_of(&"coast")
	eq(GroundColors.mark(Ground.MOSS, moss), GroundColors.BOG_FLOOR, "the moss draws its fen as the bog floor")
	near(Decor._fen_wet(Ground.MOSS, moss, 900, 950, 1.5), BogFen.wet(900.5, 950.5, 1.5), 1e-9,
		"and its decor reads how wet each tile of it lies")
	check(is_nan(Decor._fen_wet(Ground.GRASS, coast, 900, 950, 1.5)), "the coast's turf is not gated by it")
	check(is_nan(Decor._fen_wet(Ground.PEAT, moss, 900, 950, 1.5)), "nor the moss's own peat")
