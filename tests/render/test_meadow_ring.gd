extends TestCase
## The meadow ring (MeadowView, Decor.meadow): dense grass near the eye, grown
## by the baked decor's own rule for where anything small stands, pinned to the
## world, and handing over to the decor at its edge.

static var _w: WorldData
static var _grassy: TerrainMesher.Chunk
static var _decor: Decor


## A chunk of seed 7 with a sward on it, and the decor that knows its tables.
static func _chunk() -> TerrainMesher.Chunk:
	if _grassy != null:
		return _grassy
	_w = WorldGen.generate(7, 160)
	_decor = Decor.new(_w)
	var m := TerrainMesher.new(_w)
	var best := 0
	for cy in 5:
		for cx in 5:
			var ch := m.build(cx, cy)
			var n := 0
			for data: PackedFloat32Array in _decor.meadow(ch, 0, 0, ch.w, ch.h, 1.0).values():
				n += data.size()
			if n > best:
				best = n
				_grassy = ch
	return _grassy


static func _plants(d: Dictionary) -> Array:
	var out := []
	for key: int in d:
		var buf: PackedFloat32Array = d[key]
		for i in range(0, buf.size(), Decor.MEADOW_FLOATS):
			out.append([key, snappedf(buf[i + 3], 0.0001), snappedf(buf[i + 7], 0.0001), snappedf(buf[i + 11], 0.0001), buf[i + 12]])
	out.sort()
	return out


func test_the_meadow_grows_only_where_the_decor_may() -> void:
	var ch := _chunk()
	var plants := _plants(_decor.meadow(ch, 0, 0, ch.w, ch.h, Decor.MEADOW_THICK))
	gt(float(plants.size()), 500.0, "a grassy chunk grows a meadow (%d plants)" % plants.size())
	var bad := 0
	for p: Array in plants:
		var tx := floori(float(p[1]) - ch.x0)
		var ty := floori(float(p[3]) - ch.y0)
		if Decor.turf(ch, tx, ty) < 0:
			bad += 1
		check(Decor.template_of(p[0]).sways, "a meadow plant sways: no stone or litter in it")
	eq(bad, 0, "no plant stands on a tile the decor refuses (a lip, water, two terraces)")


func test_a_plant_stands_where_it_stands_whatever_cell_asked_for_it() -> void:
	var ch := _chunk()
	var whole := _plants(_decor.meadow(ch, 0, 0, ch.w, ch.h, 1.0))
	var parts := {}
	for oy: int in [0, 16]:
		for ox: int in [0, 16]:
			var d := _decor.meadow(ch, ox, oy, 16, 16, 1.0)
			for key: int in d:
				var buf: PackedFloat32Array = parts.get(key, PackedFloat32Array())
				buf.append_array(d[key])
				parts[key] = buf
	eq(_plants(parts), whole, "four cells of a chunk grow exactly the chunk's meadow")


func test_the_meadow_thickens_with_its_density() -> void:
	var ch := _chunk()
	var thin := float(_plants(_decor.meadow(ch, 0, 0, ch.w, ch.h, 1.0)).size())
	var thick := float(_plants(_decor.meadow(ch, 0, 0, ch.w, ch.h, 3.0)).size())
	var ratio := thick / thin
	check(ratio > 2.6 and ratio < 3.4, "three times the density is three times the plants (%.2f)" % ratio)


func test_every_tier_says_how_far_and_how_thick_the_meadow_stands() -> void:
	var last_reach := INF
	var last_density := INF
	for r: Dictionary in Quality.ROWS:
		check(r.get("grass_reach") is int, "%s has an int grass_reach" % r.id)
		check(r.get("grass_density") is float, "%s has a float grass_density" % r.id)
		if r.id == &"web":
			continue
		check(int(r.grass_reach) <= last_reach and float(r.grass_density) <= last_density, "%s is no richer than the tier above it" % r.id)
		last_reach = int(r.grass_reach)
		last_density = float(r.grass_density)
	var web := Quality.row(&"web")
	gt(float(web.grass_reach), 0.0, "the web has a meadow, thinned, not removed")
	lt(float(web.grass_reach), float(Quality.row(&"high").grass_reach), "and a nearer one than high")


func test_the_ring_asks_for_every_cell_it_reaches_nearest_first() -> void:
	var c := Vector2(100.3, 57.8)
	var cells := MeadowView.cells_near(c, 24.0)
	var last := -1.0
	for cell: Vector2i in cells:
		var d := MeadowView.cell_distance(cell, c)
		lt(d, 24.0, "%s is within reach" % cell)
		check(d >= last, "nearest first")
		last = d
	for y in range(-4, 5):
		for x in range(-4, 5):
			var cell := Vector2i(floori(c.x / MeadowView.CELL) + x, floori(c.y / MeadowView.CELL) + y)
			if MeadowView.cell_distance(cell, c) < 24.0:
				check(cells.has(cell), "%s is asked for" % cell)


func test_the_grass_shader_hands_the_ring_over_to_the_decor() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/foliage/grass.gdshader")
	check(src.contains("global uniform vec4 foliage_meadow;"), "the ring's centre and reach are one global")
	check(src.contains("INSTANCE_CUSTOM.x"), "a meadow plant's seed is its instance's")
	check(src.contains("MODEL_MATRIX[3].xz"), "and its root is its instance's origin")
	check(src.contains("meadow_share("), "decor and meadow split the band by seed")
	var godot := FileAccess.get_file_as_string("res://project.godot")
	check(godot.contains("foliage_meadow={"), "the global is registered")
