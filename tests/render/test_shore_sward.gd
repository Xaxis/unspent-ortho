extends TestCase
## THE COAST'S HEATH IN DRIFTS (ShoreSward; matter.gdshaderinc shore_thick and
## shore_cushion; world.gdshader shore_sward; Decor._heather). The first try grew
## the heather as one octave of stride-wide cushions kept at random, with the
## decor's clumps laid evenly over all of it, and from above the heath was an
## even field of round dark spots (review, 2026-09-30). The heather lies in
## drifts on pale grass, and the decor's clumps stand in the drifts the ground
## draws and nowhere else.

const MATTER := "res://src/render/matter.gdshaderinc"
## Where the samples are taken, clear of the origin's lattice symmetry.
const AT := Vector2(613.0, 1171.0)


## Whether each point of an n x n grid, one world unit apart, is under heather.
func _under(n: int, y: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(n * n)
	for j in n:
		for i in n:
			out[j * n + i] = 1 if ShoreSward.thick(AT.x + i, AT.y + j, y) > 0.5 else 0
	return out


func _share(cells: PackedByteArray) -> float:
	var n := 0
	for v: int in cells:
		n += v
	return float(n) / float(cells.size())


## The areas of the 4-connected patches of `want` in an n x n grid.
func _patches(cells: PackedByteArray, n: int, want: int) -> Array[int]:
	var seen := PackedByteArray()
	seen.resize(n * n)
	var out: Array[int] = []
	for start in n * n:
		if seen[start] == 1 or cells[start] != want:
			continue
		var area := 0
		var stack := PackedInt32Array([start])
		seen[start] = 1
		while not stack.is_empty():
			var c := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			area += 1
			var cx := c % n
			var cy := c / n
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var x := cx + o.x
				var y := cy + o.y
				if x < 0 or y < 0 or x >= n or y >= n:
					continue
				var k := y * n + x
				if seen[k] == 0 and cells[k] == want:
					seen[k] = 1
					stack.append(k)
		out.append(area)
	return out


func test_the_shader_draws_the_drifts_from_shore_swards_own_numbers() -> void:
	# The decor's clumps stand where ShoreSward says and the ground draws where
	# the shader says: one number moved alone and the clumps leave the drifts.
	var src := FileAccess.get_file_as_string(MATTER)
	for want: String in [
			"const vec2 SHORE_WIND = vec2(%.1f, %.3f);" % [ShoreSward.WIND.x, ShoreSward.WIND.y],
			"uint h = (q.x * %du) ^ (q.y * %du);" % [ShoreSward._K1, ShoreSward._K2],
			"h ^= h >> 15u;", "h *= %du;" % ShoreSward._K3, "h ^= h >> 13u;",
			"return float(h & 16777215u) / 16777215.0;",
			"shore_noise(p * %s + 3.0), shore_noise(p * %s + 17.0)) - 0.5;" % [ShoreSward.BEND, ShoreSward.BEND],
			"p = rot * p * %s + %s;" % [ShoreSward._SCALE[0], ShoreSward._OFFSET[0]],
			"p = rot * p * %s + %s;" % [ShoreSward._SCALE[1], ShoreSward._OFFSET[1]],
			"float v = shore_noise(p) * %s;" % ShoreSward._WEIGHT[0],
			"v += shore_noise(p) * %s;" % ShoreSward._WEIGHT[1],
			"return v + shore_noise(p) * %s;" % ShoreSward._WEIGHT[2],
			"shore_fbm(vec2(a.x * %s, a.y * %s) + w * %s);" % [ShoreSward.ALONG, ShoreSward.ACROSS, ShoreSward.BEND_REACH],
			"d += clamp((y - %s) / %s, 0.0, 1.0) * %s - %s;" % [ShoreSward.LOW, ShoreSward.EXPOSED, ShoreSward.RISE, ShoreSward.SINK],
			"return smoothstep(%s, %s, d);" % [ShoreSward.THIN, ShoreSward.THICK]]:
		check(src.contains(want), "matter.gdshaderinc's drift field says `%s`, as ShoreSward does" % want)


func test_the_lattice_is_the_32_bit_hash_the_shader_computes() -> void:
	# Worked outside the game in exact unsigned 32-bit arithmetic, the shader's
	# own steps: a negative point wraps as uint(int) does.
	near(ShoreSward.lattice(7, -3), 0.6302261132136651, 1e-12)
	near(ShoreSward.lattice(-1, 5), 0.2915139968105553, 1e-12)
	near(ShoreSward.lattice(123456, -98765), 0.0999510943860468, 1e-12)
	var lo := 1.0
	var hi := 0.0
	var sum := 0.0
	for i in 400:
		var v := ShoreSward.lattice(i * 37 - 5000, i * 91 + 13)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	check(lo >= 0.0 and hi <= 1.0, "it is 0..1")
	near(sum / 400.0, 0.5, 0.05, "and spread over it, not bunched")


func test_about_a_third_of_the_heath_is_under_heather() -> void:
	# The pale grass is the ground: at the heath's middle height (level 7, the
	# median of the coast's heath on seeds 1 and 7) the heather covers a fifth to
	# under half of it.
	var share := _share(_under(240, 3.5))
	gt(share, 0.2, "the heath is heathery (%.2f under heather)" % share)
	lt(share, 0.45, "and the grass between is the ground (%.2f under heather)" % share)


func test_the_high_heath_holds_more_heather_than_the_low() -> void:
	# The coast's heath runs from level 3 to 22 and its grass from 1 to 4: the
	# heather gathers on the crest and thins down toward the turf.
	var low := _share(_under(160, 1.5))
	var high := _share(_under(160, 9.5))
	gt(high, low + 0.1, "level 19 is heathier than level 3 (%.2f against %.2f)" % [high, low])


func test_the_heather_lies_in_drifts_and_the_grass_between_is_open() -> void:
	var n := 200
	var cells := _under(n, 3.5)
	var drifts := _patches(cells, n, 1)
	var total := 0
	var in_drifts := 0
	for a: int in drifts:
		total += a
		if a >= 25:
			in_drifts += a
	gt(float(total), 0.0, "there is heather to measure")
	# A drift is several strides across: 25 square units is five by five.
	gt(float(in_drifts) / float(total), 0.85, "nearly all the heather lies in drifts five strides across or more (%d of %d)" % [in_drifts, total])
	var open := _patches(cells, n, 0)
	var biggest := 0
	var all_open := 0
	for a: int in open:
		biggest = maxi(biggest, a)
		all_open += a
	gt(float(biggest) / float(all_open), 0.8, "and the grass between runs through, not penned into holes (%d of %d)" % [biggest, all_open])


## A chunk of seed 7 with the coast's heath on it.
func _heath_chunk() -> Array:
	var w := WorldGen.generate(7, 160)
	var decor := Decor.new(w)
	var m := TerrainMesher.new(w)
	var coast := BiomeRegistry.index_of(&"coast")
	var best: TerrainMesher.Chunk = null
	var most := 0
	for cy in 5:
		for cx in 5:
			var ch := m.build(cx, cy)
			var n := 0
			for ty in ch.h:
				for tx in ch.w:
					var k := Decor.turf(ch, tx, ty)
					if k >= 0 and (k & 0xFF) == Ground.HEATH and ((k >> 8) & 0xFF) == coast:
						n += 1
			if n > most:
				most = n
				best = ch
	return [best, decor, most]


func test_the_decor_heather_stands_only_in_the_drifts() -> void:
	var got := _heath_chunk()
	var ch: TerrainMesher.Chunk = got[0]
	var decor: Decor = got[1]
	gt(float(got[2]), 40.0, "seed 7 has a chunk of the coast's heath (%d tiles)" % got[2])
	var coast := BiomeRegistry.index_of(&"coast")
	var plants := decor.meadow(ch, 0, 0, ch.w, ch.h, Decor.MEADOW_THICK)
	var in_drift := 0
	var in_open := 0
	for key: int in plants:
		var kd := key / 4
		if kd / BiomeRegistry.SLOTS != Decor.HEATHER or kd % BiomeRegistry.SLOTS != coast:
			continue
		var buf: PackedFloat32Array = plants[key]
		for i in range(0, buf.size(), Decor.MEADOW_FLOATS):
			var x := buf[i + 3]
			var z := buf[i + 11]
			# Raised half a unit past where the plant stands, above any height the
			# tile's gate could have read: the field only thickens with height.
			if ShoreSward.thick(floorf(x) + 0.5, floorf(z) + 0.5, buf[i + 7] + 0.5) > 0.0:
				in_drift += 1
			else:
				in_open += 1
	gt(float(in_drift), 0.0, "the heath's drifts carry heather clumps (%d)" % in_drift)
	eq(in_open, 0, "and the open grass between carries none")


func test_the_heaths_open_ground_is_the_coasts_own_grass() -> void:
	# Between the drifts the heath is cropped grass, the same wash as the turf it
	# meets at its edge, so the two grounds join in one colour and not two.
	var src := FileAccess.get_file_as_string("res://src/render/world.gdshader")
	var head := "const vec3 SHORE_GRASS = vec3("
	var at := src.find(head)
	gt(at, 0, "world.gdshader states the coast's grass")
	var nums := src.substr(at + head.length(), src.find(")", at) - at - head.length()).split(",")
	var g := GroundColors.wash(Ground.GRASS, BiomeRegistry.index_of(&"coast"))
	for i in 3:
		near(nums[i].to_float(), g[i], 0.002, "channel %d is the coast's grass wash" % i)
