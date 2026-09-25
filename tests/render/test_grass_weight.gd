extends TestCase
## A heavy plant costs what it looks like it costs, and no more: seed heads are
## small puffs, not clumps, and under the lens a heavy plant thins sooner with
## distance (Decor.HEAVY_TRIS, grass.gdshader). Measured on seed 7's moss the
## sward added 321k primitives to a frame, most of it bog cotton heads.


func test_no_grass_plant_is_heavier_than_its_budget() -> void:
	for id: StringName in [&"coast", &"moss", &"pinewood", &"salt_flats"]:
		var d := BiomeRegistry.get_def(id)
		for gi in d.grasses.size():
			var tris := Decor.template(Decor.GRASS_A + gi, d.index, 0).v.size() / 3
			lt(float(tris), 240.0, "%s %s: %d triangles a plant" % [id, d.grasses[gi].id, tris])


func test_a_heavy_plant_says_how_heavy_it_is() -> void:
	var moss := BiomeRegistry.index_of(&"moss")
	var cotton := Decor.template(Decor.GRASS_B, moss, 0)
	# What Decor adds to every plant's UV2.y (Out.put).
	var weight := cotton.motion / 100
	check(cotton.v.size() / 3 >= Decor.HEAVY_TRIS, "bog cotton is one of the heavy ones")
	gt(float(weight), 0.0, "and says so in its motion code (%d)" % weight)
	var src := FileAccess.get_file_as_string("res://src/render/foliage/grass.gdshader")
	check(src.contains("GRASS_HEAVY_SOONER * heavy"), "and the shader thins it sooner")
