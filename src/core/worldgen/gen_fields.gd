class_name GenFields
## Grid helpers for world generation. Everything here works on flat packed
## arrays indexed y * width + x, because GDScript is fast over packed arrays and
## slow over Dictionaries and objects. Heavy lifting that Godot can do natively
## (bilinear resize, box averaging) goes through Image.


static func noise(seed_value: int, salt: int, freq: float, octaves: int, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = Rng.hash_ints(seed_value, salt) & 0x7FFFFFFF
	n.noise_type = kind
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


## Stateless 32-bit hash to [0, 1). Cheaper than Rng.hash01 (no loop), for
## per-tile rolls in hot loops. Inline the body where a loop is very hot.
static func h01(s: int, x: int, y: int, salt: int) -> float:
	var h := (x * 0x27d4eb2d + y * 0x165667b1 + s * 0x9e3779b1 + salt * 0x85ebca77) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297a2d39) & 0xFFFFFFFF
	h ^= h >> 15
	return float(h) / 4294967296.0


## Width of a coarse grid whose cells are `step` tiles, covering `size` tiles.
static func coarse_width(size: int, step: int) -> int:
	return (size + step - 1) / step


## Tile coordinate of the centre of coarse cell k (matches Image bilinear
## resize, which interpolates between pixel centres).
static func cell_centre(k: int, step: int) -> float:
	return k * step + step * 0.5 - 0.5


## Sample a noise at every coarse cell centre.
static func sample(n: FastNoiseLite, cw: int, step: int, ox: float = 0.0, oy: float = 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(cw * cw)
	var off := step * 0.5 - 0.5
	for gy in cw:
		var ty := gy * step + off + oy
		for gx in cw:
			out[gy * cw + gx] = n.get_noise_2d(gx * step + off + ox, ty)
	return out


## A smooth noise as a full-resolution field, sampled every `step` tiles and
## spread bilinearly. For frequencies well under 1/step it is indistinguishable
## from sampling every tile, at a fraction of the cost.
static func field(n: FastNoiseLite, size: int, step: int, ox: float = 0.0, oy: float = 0.0) -> PackedFloat32Array:
	var cw := coarse_width(size, step)
	return upsample(sample(n, cw, step, ox, oy), cw, step, size)


## Bilinear upsample of a cw*cw coarse grid to size*size tiles.
static func upsample(g: PackedFloat32Array, cw: int, step: int, size: int) -> PackedFloat32Array:
	var img := Image.create_from_data(cw, cw, false, Image.FORMAT_RF, g.to_byte_array())
	img.resize(cw * step, cw * step, Image.INTERPOLATE_BILINEAR)
	if cw * step != size:
		img.crop(size, size)
	return img.get_data().to_float32_array()


## Mean of a 0/1 mask over blocks of 2^levels tiles, bilinearly spread back to
## full resolution: "how much of the neighbourhood is X", natively.
static func neighbourhood_share(mask: PackedByteArray, size: int, levels: int) -> PackedFloat32Array:
	var p2 := 1
	while p2 < size:
		p2 *= 2
	var bytes := PackedByteArray()
	bytes.resize(p2 * p2)
	for y in size:
		var row := y * size
		var prow := y * p2
		for x in size:
			bytes[prow + x] = 255 if mask[row + x] != 0 else 0
	var img := Image.create_from_data(p2, p2, false, Image.FORMAT_L8, bytes)
	for i in levels:
		img.shrink_x2()
	img.convert(Image.FORMAT_RF)
	img.resize(p2, p2, Image.INTERPOLATE_BILINEAR)
	img.crop(size, size)
	return img.get_data().to_float32_array()


## 8-neighbour chamfer distance (1, 1.41) to the nearest cell where mask != 0,
## capped at `cap`.
static func distance8(mask: PackedByteArray, width: int, cap: float = 1e6) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(mask.size())
	for i in d.size():
		d[i] = 0.0 if mask[i] != 0 else cap
	propagate_min(d, width, 1.0)
	return d


## In place: v[i] = min(v[i], v[j] + cost * dist(i, j)) over 8-neighbours, two
## sweeps. With v seeded at sources and large elsewhere this is a weighted
## distance transform; seeded with heights it carves cones (valleys, ramps).
static func propagate_min(v: PackedFloat32Array, width: int, cost: float) -> void:
	var height := v.size() / width
	var dc := cost * 1.4142
	for y in height:
		var row := y * width
		for x in width:
			var i := row + x
			var m := v[i]
			if x > 0:
				m = minf(m, v[i - 1] + cost)
			if y > 0:
				m = minf(m, v[i - width] + cost)
				if x > 0:
					m = minf(m, v[i - width - 1] + dc)
				if x < width - 1:
					m = minf(m, v[i - width + 1] + dc)
			v[i] = m
	for y in range(height - 1, -1, -1):
		var row := y * width
		for x in range(width - 1, -1, -1):
			var i := row + x
			var m := v[i]
			if x < width - 1:
				m = minf(m, v[i + 1] + cost)
			if y < height - 1:
				m = minf(m, v[i + width] + cost)
				if x < width - 1:
					m = minf(m, v[i + width + 1] + dc)
				if x > 0:
					m = minf(m, v[i + width - 1] + dc)
			v[i] = m


## Like propagate_min but the step cost varies per cell (cost of entering i).
static func propagate_min_field(v: PackedFloat32Array, width: int, cost: PackedFloat32Array) -> void:
	var height := v.size() / width
	for y in height:
		var row := y * width
		for x in width:
			var i := row + x
			var c := cost[i]
			var m := v[i]
			if x > 0:
				m = minf(m, v[i - 1] + c)
			if y > 0:
				m = minf(m, v[i - width] + c)
				if x > 0:
					m = minf(m, v[i - width - 1] + c * 1.4142)
				if x < width - 1:
					m = minf(m, v[i - width + 1] + c * 1.4142)
			v[i] = m
	for y in range(height - 1, -1, -1):
		var row := y * width
		for x in range(width - 1, -1, -1):
			var i := row + x
			var c := cost[i]
			var m := v[i]
			if x < width - 1:
				m = minf(m, v[i + 1] + c)
			if y < height - 1:
				m = minf(m, v[i + width] + c)
				if x < width - 1:
					m = minf(m, v[i + width + 1] + c * 1.4142)
				if x > 0:
					m = minf(m, v[i + width - 1] + c * 1.4142)
			v[i] = m


## Breadth-first steps (4-neighbour) from every cell where mask != 0, stopping
## at max_steps; cells further away read max_steps + 1. Cost scales with the
## band it visits, not the grid, so it suits "within a few tiles of the shore".
static func near_steps(mask: PackedByteArray, width: int, max_steps: int) -> PackedByteArray:
	var n := mask.size()
	var height := n / width
	var d := PackedByteArray()
	d.resize(n)
	d.fill(max_steps + 1)
	# Only mask cells on the mask's edge can reach anything: start from those.
	var frontier := PackedInt32Array()
	for y in height:
		var row := y * width
		for x in width:
			var i := row + x
			if mask[i] == 0:
				continue
			d[i] = 0
			if (x > 0 and mask[i - 1] == 0) or (x < width - 1 and mask[i + 1] == 0) or (y > 0 and mask[i - width] == 0) or (y < height - 1 and mask[i + width] == 0):
				frontier.append(i)
	for step in range(1, max_steps + 1):
		var next := PackedInt32Array()
		for i in frontier:
			var x := i % width
			var y := i / width
			if x > 0 and d[i - 1] > step:
				d[i - 1] = step
				next.append(i - 1)
			if x < width - 1 and d[i + 1] > step:
				d[i + 1] = step
				next.append(i + 1)
			if y > 0 and d[i - width] > step:
				d[i - width] = step
				next.append(i - width)
			if y < height - 1 and d[i + width] > step:
				d[i + width] = step
				next.append(i + width)
		frontier = next
	return d


## Value at the q-quantile (0..1) of the values where mask != 0, via a histogram.
static func quantile(v: PackedFloat32Array, mask: PackedByteArray, q: float, lo: float, hi: float) -> float:
	var bins := 2048
	var hist := PackedInt32Array()
	hist.resize(bins)
	var total := 0
	var scale := bins / (hi - lo)
	for i in v.size():
		if mask.is_empty() or mask[i] != 0:
			hist[clampi(int((v[i] - lo) * scale), 0, bins - 1)] += 1
			total += 1
	var want := int(q * total)
	var acc := 0
	for b in bins:
		acc += hist[b]
		if acc >= want:
			return lo + (b + 0.5) / scale
	return hi


## Label 4-connected components of cells where mask != 0. Returns labels
## (-1 for masked-out cells) and fills `sizes` with each label's cell count.
static func components(mask: PackedByteArray, width: int, sizes: PackedInt32Array) -> PackedInt32Array:
	var n := mask.size()
	var label := PackedInt32Array()
	label.resize(n)
	label.fill(-1)
	var stack := PackedInt32Array()
	sizes.clear()
	for start in n:
		if mask[start] == 0 or label[start] != -1:
			continue
		var id := sizes.size()
		var count := 0
		label[start] = id
		stack.append(start)
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x := i % width
			if x > 0 and mask[i - 1] != 0 and label[i - 1] == -1:
				label[i - 1] = id
				stack.append(i - 1)
			if x < width - 1 and mask[i + 1] != 0 and label[i + 1] == -1:
				label[i + 1] = id
				stack.append(i + 1)
			if i >= width and mask[i - width] != 0 and label[i - width] == -1:
				label[i - width] = id
				stack.append(i - width)
			if i < n - width and mask[i + width] != 0 and label[i + width] == -1:
				label[i + width] = id
				stack.append(i + width)
		sizes.append(count)
	return label
