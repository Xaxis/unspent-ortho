extends TestCase
## The tidy is a section's to run (streamed worldgen S4d): a square tidied with
## `GenTidy.MARGIN` tiles of the world round it decides its own tiles exactly as
## the whole-world tidy does, ground and recipe.
##
## The input is a real world's ground with a tenth of its free tiles thrown to a
## neighbour's ground, so the tidy has patches, fringes and notches to decide
## everywhere, and water and roads held fixed as generation holds them.

const SIZE := 512
const SEEDS: Array[int] = [1, 42, 90210]
## The core of each window, and where the windows' corners fall (in cores).
const CORE := 64
const WINDOWS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 2), Vector2i(5, 4), Vector2i(2, 6), Vector2i(6, 6)]


func test_a_section_tidies_its_own_tiles_as_the_whole_world_does() -> void:
	for s in SEEDS:
		var w := WorldGen.generate(s, SIZE)
		var input := _messy(w)
		var ground: PackedByteArray = input[0]
		var recipe: PackedByteArray = input[1]
		var fixed: PackedByteArray = input[2]
		# Private copies: a duplicate shares storage until its first write, and
		# the tidy's first writes are made on several threads (GenFields.snapshot).
		var whole_g: PackedByteArray = GenFields.snapshot(ground)
		var whole_r: PackedByteArray = GenFields.snapshot(recipe)
		GenTidy.tidy(whole_g, whole_r, fixed, SIZE)
		var moved := 0
		for i in ground.size():
			if whole_g[i] != ground[i]:
				moved += 1
		gt(moved, SIZE * SIZE / 100, "seed %d: the tidy had work to do (%d tiles)" % [s, moved])
		for win in WINDOWS:
			var bad := _window_differs(ground, recipe, fixed, whole_g, whole_r, win * CORE, GenTidy.MARGIN)
			eq(bad, 0, "seed %d: window at %s tidied with its margin differs from the whole-world tidy on its core" % [s, win * CORE])


## Tiles of the core at `at` whose ground or recipe differ between the whole-world
## tidy and the tidy of the window reaching `margin` round it.
static func _window_differs(ground: PackedByteArray, recipe: PackedByteArray, fixed: PackedByteArray,
		whole_g: PackedByteArray, whole_r: PackedByteArray, at: Vector2i, margin: int) -> int:
	var side := CORE + margin * 2
	var o := at - Vector2i(margin, margin)
	var g := PackedByteArray()
	var r := PackedByteArray()
	var f := PackedByteArray()
	g.resize(side * side)
	r.resize(side * side)
	f.resize(side * side)
	for y in side:
		for x in side:
			var j := (o.y + y) * SIZE + o.x + x
			g[y * side + x] = ground[j]
			r[y * side + x] = recipe[j]
			f[y * side + x] = fixed[j]
	GenTidy.tidy(g, r, f, side)
	var bad := 0
	for y in CORE:
		for x in CORE:
			var k := (margin + y) * side + margin + x
			var j := (at.y + y) * SIZE + at.x + x
			if g[k] != whole_g[j] or r[k] != whole_r[j]:
				bad += 1
	return bad


## [ground, recipe, fixed]: the world's ground with a tenth of its free tiles
## thrown to the ground two tiles off, the landscape as the recipe, and water
## and roads fixed.
static func _messy(w: WorldData) -> Array:
	var ground: PackedByteArray = GenFields.snapshot(w.ground)
	var recipe := PackedByteArray()
	recipe.resize(ground.size())
	var fixed := PackedByteArray()
	fixed.resize(ground.size())
	for i in ground.size():
		recipe[i] = w.country[i]
		if Ground.is_water(w.ground[i]) or w.ground[i] == Ground.ROAD or w.level[i] <= 0:
			fixed[i] = 1
	for y in range(2, SIZE - 2):
		for x in range(2, SIZE - 2):
			var i := y * SIZE + x
			if fixed[i] != 0 or Rng.hash01(w.seed_value, x, y, 0x71D) >= 0.1:
				continue
			var k := floori(Rng.hash01(w.seed_value, x, y, 0x71E) * 4.0)
			var j: int = i + ([2, -2, 2 * SIZE, -2 * SIZE] as Array[int])[k]
			if fixed[j] == 0:
				ground[i] = w.ground[j]
				recipe[i] = w.country[j]
	return [ground, recipe, fixed]
