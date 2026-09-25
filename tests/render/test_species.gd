extends TestCase
## Each landscape grows its own grass (GrassSpecies, BiomeDef.grasses, Decor's
## GRASS_A/B/C): the coast's sward and marram, the moss's sedge and bog cotton,
## the pinewood's fern and bracken, the salt flats' straw. Before this every
## grass in the game was one tuft recoloured.

const OWN: Array[StringName] = [&"coast", &"moss", &"pinewood", &"salt_flats"]


func test_the_four_landscapes_declare_their_own_grasses_and_lay_them() -> void:
	for id: StringName in OWN:
		var d := BiomeRegistry.get_def(id)
		gt(float(d.grasses.size()), 0.0, "%s declares its grasses" % id)
		var laid := false
		for g: int in d.decor:
			var row: Array = d.decor[g]
			for i in range(1, row.size(), 2):
				if int(row[i]) in [Decor.GRASS_A, Decor.GRASS_B, Decor.GRASS_C]:
					laid = true
					check(int(row[i]) - Decor.GRASS_A < d.grasses.size(), "%s lays a grass it declares" % id)
		check(laid, "%s lays its grasses on its own ground" % id)


func test_no_two_landscapes_share_a_grass() -> void:
	var seen: Array = []
	var from: Array[StringName] = []
	for d: BiomeDef in BiomeRegistry.all():
		for gs: GrassSpecies in d.grasses:
			var sig := gs.signature()
			var at := seen.find(sig)
			check(at < 0, "%s's %s is the same grass as %s's" % [d.id, gs.id, from[at] if at >= 0 else &""])
			seen.append(sig)
			from.append(d.id)


func test_a_species_moves_as_it_is_declared() -> void:
	var g := GrassSpecies.new()
	g.stiff = 0.8
	g.flutter = 7
	eq(g.motion_code(), 87, "stiffness in the tens, flutter in the units")
	var src := FileAccess.get_file_as_string("res://src/render/foliage/grass.gdshader")
	check(src.contains("floor(UV2.y)"), "the shader reads the motion out of the whole part")
	check(src.contains("fract(UV2.y)"), "and the plant's seed out of the fraction")


func test_each_landscapes_grass_is_a_different_shape() -> void:
	var shapes := {}
	for id: StringName in OWN:
		var d := BiomeRegistry.get_def(id)
		var t := Decor.template(Decor.GRASS_A, d.index, 0)
		check(t.sways, "%s's first grass sways" % id)
		var top := 0.0
		for v: Vector3 in t.v:
			top = maxf(top, v.y)
		var key := "%d/%.2f" % [t.v.size(), top]
		check(not shapes.has(key), "%s's grass has its own shape (%s, as %s)" % [id, key, shapes.get(key, "")])
		shapes[key] = id
