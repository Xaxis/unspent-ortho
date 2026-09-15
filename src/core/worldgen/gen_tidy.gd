class_name GenTidy
## Stage 11b: tidy the ground map so it reads as washes with long, curving
## edges, never camouflage or a staircase.
##
##   1. a 3x3 mode filter (three times): lone tiles and ragged fringes go;
##   2. every same-ground patch under MIN_PATCH tiles joins the ground that
##      surrounds it most;
##   3. notches (a tile its neighbours enclose on three sides) and
##      diagonal-only contacts (a 2x2 chequer) are filled.
##
## Fixed tiles (sea, water, roads, sites, pool rims) never change, and never
## vote: a road through a field does not split the field's vote. When a tile
## takes a new ground it also takes the recipe of a neighbour that has it, so
## props still follow the ground they stand on.

const MIN_PATCH := 20


static func run(c: GenContext, fixed: PackedByteArray) -> void:
	var size := c.size
	for pass_i in 3:
		mode3(c.w.ground, c.recipe, fixed, size)
	c.mark(&"tidy.mode")
	merge_small(c.w.ground, c.recipe, fixed, size, MIN_PATCH)
	c.mark(&"tidy.merge")
	for pass_i in 2:
		unnotch(c.w.ground, c.recipe, fixed, size)
	c.mark(&"tidy.notch")


## One 3x3 mode pass over free tiles. Ties keep the tile's own ground.
static func mode3(ground: PackedByteArray, recipe: PackedByteArray, fixed: PackedByteArray, size: int) -> void:
	var was: PackedByteArray = GenFields.snapshot(ground)
	var was_r: PackedByteArray = GenFields.snapshot(recipe)
	GenFields.rows(size - 1, func(y0: int, y1: int) -> void:
		var votes := PackedInt32Array()
		votes.resize(32)
		var offs := PackedInt32Array([-size - 1, -size, -size + 1, -1, 0, 1, size - 1, size, size + 1])
		for y in range(maxi(y0, 1), y1):
			for x in range(1, size - 1):
				var i := y * size + x
				if fixed[i] != 0:
					continue
				var g := was[i]
				# Most tiles sit inside a patch: nothing to decide.
				if was[i - 1] == g and was[i + 1] == g and was[i - size] == g and was[i + size] == g:
					continue
				var best := g
				var best_n := 0
				var own_n := 0
				for o in offs:
					var j := i + o
					if fixed[j] != 0:
						continue
					var h := was[j]
					var k := votes[h] + 1
					votes[h] = k
					if h == g:
						own_n = k
					if k > best_n:
						best_n = k
						best = h
				for o in offs:
					votes[was[i + o]] = 0
				if best != g and best_n > own_n:
					ground[i] = best
					recipe[i] = _recipe_of(was, was_r, fixed, i, size, best)
	)


## The recipe of a free 8-neighbour whose ground is g (the tile's own if none).
static func _recipe_of(ground: PackedByteArray, recipe: PackedByteArray, fixed: PackedByteArray, i: int, size: int, g: int) -> int:
	for j: int in [i - 1, i + 1, i - size, i + size, i - size - 1, i - size + 1, i + size - 1, i + size + 1]:
		if fixed[j] == 0 and ground[j] == g:
			return recipe[j]
	return recipe[i]


## Patches of one ground smaller than min_tiles take the free ground most
## common along their edge.
static func merge_small(ground: PackedByteArray, recipe: PackedByteArray, fixed: PackedByteArray, size: int, min_tiles: int) -> void:
	var sizes := PackedInt32Array()
	var label := GenFields.patches(ground, fixed, size, sizes)
	var band := 12
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(size) / band))
	GenFields.rows(size - 1, func(y0: int, y1: int) -> void:
		var found := PackedInt32Array()
		for i in range(maxi(y0, 1) * size, y1 * size):
			var la := label[i]
			if la >= 0 and sizes[la] < min_tiles:
				found.append(i)
		parts[y0 / band] = found
	, band)
	# Votes per small patch: label -> counts by ground.
	var votes := {}
	for part in parts:
		for i in part:
			var la := label[i]
			var x := i % size
			if x == 0 or x == size - 1:
				continue
			var v: PackedInt32Array = votes.get(la, PackedInt32Array())
			if v.is_empty():
				v.resize(32)
			for j: int in [i - 1, i + 1, i - size, i + size]:
				if label[j] >= 0 and label[j] != la:
					v[ground[j]] += 1
			votes[la] = v
	var winner := {}
	for la: int in votes:
		var v: PackedInt32Array = votes[la]
		var best := -1
		var best_n := 0
		for g in v.size():
			if v[g] > best_n:
				best_n = v[g]
				best = g
		if best >= 0:
			winner[la] = best
	var was: PackedByteArray = GenFields.snapshot(ground)
	var was_r: PackedByteArray = GenFields.snapshot(recipe)
	for part in parts:
		for i in part:
			var la := label[i]
			if not winner.has(la):
				continue
			var g: int = winner[la]
			ground[i] = g
			recipe[i] = _recipe_of(was, was_r, fixed, i, size, g)


## Fill notches and chequers among free tiles.
static func unnotch(ground: PackedByteArray, recipe: PackedByteArray, fixed: PackedByteArray, size: int) -> void:
	var was: PackedByteArray = GenFields.snapshot(ground)
	var was_r: PackedByteArray = GenFields.snapshot(recipe)
	GenFields.rows(size - 1, func(y0: int, y1: int) -> void:
		for y in range(maxi(y0, 1), y1):
			for x in range(1, size - 1):
				var i := y * size + x
				if fixed[i] != 0:
					continue
				var g := was[i]
				# Fixed neighbours read as 255: a tile never takes water or road.
				var a := 255 if fixed[i - 1] != 0 else was[i - 1]
				var b := 255 if fixed[i + 1] != 0 else was[i + 1]
				var u := 255 if fixed[i - size] != 0 else was[i - size]
				var d := 255 if fixed[i + size] != 0 else was[i + size]
				if a == g and b == g and u == g and d == g:
					continue
				var to := g
				# A notch: three sides of one other ground.
				if a != g and ((a == b and (a == u or a == d)) or (a == u and a == d)):
					to = a
				elif b != g and b == u and b == d:
					to = b
				else:
					# Chequer with this tile top-right: left and below share a ground
					# the diagonal (below-left) does not.
					var dl := 255 if fixed[i + size - 1] != 0 else was[i + size - 1]
					var dr := 255 if fixed[i + size + 1] != 0 else was[i + size + 1]
					if a == d and a != g and dl != a:
						to = a
					elif b == d and b != g and dr != b:
						# Chequer with this tile top-left.
						to = b
				if to != g and to != 255:
					ground[i] = to
					recipe[i] = _recipe_of(was, was_r, fixed, i, size, to)
	)
