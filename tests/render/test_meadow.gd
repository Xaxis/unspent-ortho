extends TestCase
## The meadow is a haze of many thin blades (Decor.MEADOW), not a few wide
## shards: owner review of the first cut read it as paper spikes.


func test_a_meadow_patch_is_many_thin_blades_at_two_triangles_each() -> void:
	var coast := BiomeRegistry.index_of(&"coast")
	for stage in Decor.STAGES:
		var t := Decor.template(Decor.MEADOW, coast, stage)
		var tris := t.v.size() / 3
		check(t.sways, "a meadow sways, so it draws on grass.gdshader")
		check(tris >= 50 and tris <= 80, "stage %d: 25-40 blades at two triangles each (%d triangles)" % [stage, tris])
		# Each blade's base edge is its width: the first two corners of its first
		# triangle (Kit.sickle), both on the ground.
		var widest := 0.0
		for b in range(0, t.v.size(), 6):
			widest = maxf(widest, t.v[b].distance_to(t.v[b + 2]))
		lt(widest, 0.035, "stage %d: no blade is wider than a grass blade (%.3f)" % [stage, widest])


func test_the_coast_meadow_stands_evenly_and_not_in_drifts() -> void:
	var coast: BiomeDef = BiomeRegistry.get_def(&"coast")
	var head: Variant = (coast.decor[Ground.GRASS] as Array)[0]
	check(head is Vector2, "the coast declares its sward's evenness")
	if head is Vector2:
		gt((head as Vector2).y, 0.5, "and it is even enough that clumps vary it rather than leave holes")
