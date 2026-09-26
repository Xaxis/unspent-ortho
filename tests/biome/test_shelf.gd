extends TestCase
## Terrace shelves (`BiomeDef.relief.shelf`, `GenRelief.run`). A terrace of a
## fixed two-level step climbs tall land as a stair of equal treads, and at eye
## level that is a ziggurat. It shows in the levels: tiles pile onto the even
## ones. The crags ask for tall, varied steps, so their levels must not.
##
## Seed 7 at the shipped size, because the stair only appears where the land
## stands tall, and at 256 the crags never do. Measured at the shelf's landing:
## the two-level step put 0.70 of the crags' tiles between levels 6 and 20 on
## even levels, the shelf 0.54.


func test_the_crags_climb_in_cliffs_not_a_stair_of_equal_treads() -> void:
	var w := WorldGen.generate(7, Tuning.WORLD_SIZE)
	var id := BiomeRegistry.index_of(&"the_crags")
	var even := 0
	var all := 0
	for i in w.country.size():
		if w.country[i] != id:
			continue
		var l := w.level[i]
		if l < 6 or l > 20:
			continue
		all += 1
		if l % 2 == 0:
			even += 1
	gt(float(all), 20000.0, "the crags stand tall on this seed")
	lt(float(even) / maxf(1.0, all), 0.58, "no step height takes the crags' levels over")
