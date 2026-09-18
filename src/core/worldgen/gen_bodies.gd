class_name GenBodies
## The bodies a world is made of, and the void between them (`docs/WORLD.md`).
##
## THE RECORDING HALF LANDS FIRST, ON PURPOSE. The finished stage runs BEFORE
## `GenShape` and hands each body a footprint, a land budget, a climate band and a
## set of landscape types; `GenShape` and everything after it then run per body.
## That inversion moves every seed's island and re-accepts every baseline, so it
## is worth landing behind a step that moves nothing: this reads the shape that
## already exists and writes down which body each tile is on. Today that is one
## body, because `GenShape` makes one island and sinks anything detached
## (`ISLET_TILES`) — so the answer is true, complete, and identical to the world
## that was there before it.
##
## It is here rather than derived at the point of use because `WorldData.continent`
## has one writer and this is it. A reader that worked a continent out from the
## ocean mask would be right until the first continent that is not where its
## latitude suggests, which is exactly the shape of bug `WorldData.road` was added
## to end.

## Body ids start at 1; 0 is the void.
const VOID := 0


static func run(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var n := size * size
	var body := PackedByteArray()
	body.resize(n)
	# Every run of land that touches is one body. One island gives one body; the
	# loop is written for the many because that is what it becomes.
	var sizes := PackedInt32Array()
	var label := GenFields.components(c.land, size, sizes)
	var rank: Array[Dictionary] = []
	for i in n:
		if sizes[i] > 0:
			rank.append({"label": i, "tiles": sizes[i]})
	rank.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.tiles) > int(b.tiles))
	var id_of := {}
	for r in rank.size():
		id_of[int(rank[r].label)] = mini(r + 1, 255)
	var sum_x := {}
	var sum_y := {}
	var box := {}
	for i in n:
		var lab := label[i]
		if lab < 0:
			continue
		var got: Variant = id_of.get(lab)
		if got == null:
			continue
		var id := int(got)
		body[i] = id
		var x := i % size
		var y := i / size
		sum_x[id] = float(sum_x.get(id, 0.0)) + float(x)
		sum_y[id] = float(sum_y.get(id, 0.0)) + float(y)
		var b: Array = box.get(id, [size, size, -1, -1])
		b[0] = mini(int(b[0]), x)
		b[1] = mini(int(b[1]), y)
		b[2] = maxi(int(b[2]), x)
		b[3] = maxi(int(b[3]), y)
		box[id] = b
	w.continent = body
	var out: Array[Dictionary] = []
	for r in rank.size():
		var id := mini(r + 1, 255)
		if not box.has(id):
			continue
		var tiles := int(rank[r].tiles)
		var b: Array = box[id]
		out.append({
			"id": id, "tiles": tiles,
			"centre": Vector2(float(sum_x[id]) / tiles, float(sum_y[id]) / tiles),
			"bounds": Rect2(int(b[0]), int(b[1]), int(b[2]) - int(b[0]) + 1, int(b[3]) - int(b[1]) + 1),
		})
	w.continents = out
