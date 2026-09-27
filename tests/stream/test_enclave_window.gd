extends TestCase
## Enclaves are a section's to absorb (streamed worldgen S4e2): a square with
## `GenCountries.ENCLAVE_REACH` + 2 tiles of the world round its core absorbs
## the core's enclaves exactly as the whole world does, country and country2.
##
## The input is a real world's landscapes with runs of a neighbouring landscape
## planted in them: small blobs, which are enclaves, and long lines a tile wide,
## which are not -- a line of MIN_TILES or more crossing a window is the run the
## window sees only part of, and part of it is under the count.

const SIZE := 512
const SEEDS: Array[int] = [1, 42, 90210]
const MIN_TILES := 400
const CORE := 64
const CORNERS: Array[Vector2i] = [Vector2i(130, 130), Vector2i(224, 160), Vector2i(318, 318), Vector2i(160, 300), Vector2i(290, 200)]


func test_a_section_absorbs_its_own_enclaves_as_the_whole_world_does() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var input := _planted(w)
		var country: PackedByteArray = input[0]
		var country2: PackedByteArray = input[1]
		var types := BiomeRegistry.count()
		var whole_c: PackedByteArray = GenFields.snapshot(country)
		var whole_c2: PackedByteArray = GenFields.snapshot(country2)
		GenCountries.absorb(whole_c, whole_c2, SIZE, types, MIN_TILES)
		var moved := 0
		for i in country.size():
			if whole_c[i] != country[i]:
				moved += 1
		gt(moved, 200, "seed %d: enclaves were absorbed (%d tiles)" % [s, moved])
		for at in CORNERS:
			var bad := _window_differs(country, country2, whole_c, whole_c2, types, at, GenCountries.ENCLAVE_REACH + 2)
			eq(bad, 0, "seed %d: window at %s absorbed with its margin differs from the whole world on its core" % [s, at])


static func _window_differs(country: PackedByteArray, country2: PackedByteArray, whole_c: PackedByteArray,
		whole_c2: PackedByteArray, types: int, at: Vector2i, margin: int) -> int:
	var side := CORE + margin * 2
	var o := at - Vector2i(margin, margin)
	var c := PackedByteArray()
	var c2 := PackedByteArray()
	c.resize(side * side)
	c2.resize(side * side)
	for y in side:
		for x in side:
			var wx := clampi(o.x + x, 0, SIZE - 1)
			var wy := clampi(o.y + y, 0, SIZE - 1)
			c[y * side + x] = country[wy * SIZE + wx]
			c2[y * side + x] = country2[wy * SIZE + wx]
	GenCountries.absorb(c, c2, side, types, MIN_TILES)
	var bad := 0
	for y in CORE:
		for x in CORE:
			var k := (margin + y) * side + margin + x
			var j := (at.y + y) * SIZE + at.x + x
			if c[k] != whole_c[j] or c2[k] != whole_c2[j]:
				bad += 1
	return bad


## [country, country2]: the world's own, with blobs and lines of the landscape
## a few tiles off planted on its land.
static func _planted(w: WorldData) -> Array:
	var country: PackedByteArray = GenFields.snapshot(w.country)
	var country2: PackedByteArray = GenFields.snapshot(w.country2)
	var s := w.seed_value
	# Blobs: 1 to 12 tiles a side.
	for k in 300:
		var x0 := 8 + floori(Rng.hash01(s, k, 0x3E1) * (SIZE - 24))
		var y0 := 8 + floori(Rng.hash01(s, k, 0x3E2) * (SIZE - 24))
		var bw := 1 + floori(Rng.hash01(s, k, 0x3E3) * 12)
		var bh := 1 + floori(Rng.hash01(s, k, 0x3E4) * 12)
		_paint(w, country, x0, y0, bw, bh)
	# Lines a tile wide, 150 to 700 long, across and down.
	for k in 24:
		var x0 := 8 + floori(Rng.hash01(s, k, 0x3E5) * (SIZE - 16))
		var y0 := 8 + floori(Rng.hash01(s, k, 0x3E6) * (SIZE - 16))
		var length := 150 + floori(Rng.hash01(s, k, 0x3E7) * 550)
		if k % 2 == 0:
			_paint(w, country, x0, y0, mini(length, SIZE - 8 - x0), 1)
		else:
			_paint(w, country, x0, y0, 1, mini(length, SIZE - 8 - y0))
	return [country, country2]


## Paint a box of land with the landscape of the land 6 tiles off its corner.
static func _paint(w: WorldData, country: PackedByteArray, x0: int, y0: int, bw: int, bh: int) -> void:
	var from := mini(SIZE - 1, y0 + 6) * SIZE + mini(SIZE - 1, x0 + 6)
	var paint := w.country[from]
	if paint == Country.SEA:
		return
	for y in range(y0, y0 + bh):
		for x in range(x0, x0 + bw):
			var i := y * SIZE + x
			if country[i] != Country.SEA:
				country[i] = paint
