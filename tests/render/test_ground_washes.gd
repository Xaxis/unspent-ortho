extends TestCase
## A landscape must colour the ground it is made of.
##
## `GroundColors` falls back to a shared table for any ground a landscape does
## not name. That table is the COAST'S: it was written when the coast was the
## only landscape, and it still reads as a coast. The scrapwood left SWARF out —
## its own `plain_ground`, sixty per cent of every tile in it, the floor the file
## is named after — so it drew in the coast's warm brown-mauve and was then
## multiplied by this landscape's 1.52x lift, which is why the wood read as an
## ordinary wood on bare earth (playtest 6). The salt flats left PAN out, 8% of
## it, the thing the machines built the whole place for and its own bank, pool
## rim and village ground; worse, every wash the flat writes is taken down by
## its TONE to pay for its lift and the fallback is not, so the pans arrived
## half a step brighter than the crust they are cut into.
##
## The rule binds the landscapes added from M2 onward (`order` past the M1 six),
## because the M1 six ARE the shared table and there is nothing for them to fall
## through to. docs/VISION.md wants twenty more; this is the thing each of them
## must not forget. Widening it to the first six means retuning three of their
## grounds and belongs to whoever owns them (contract request in the report).

const M1_LANDSCAPES := 6


static func _new_lands() -> Array[BiomeDef]:
	var out: Array[BiomeDef] = []
	for d: BiomeDef in BiomeRegistry.land():
		if d.order >= M1_LANDSCAPES:
			out.append(d)
	return out


## Every ground a landscape puts on the map itself, whatever the terrain does.
static func _own(d: BiomeDef) -> Array[int]:
	var out: Array[int] = []
	for g: int in [d.plain_ground, d.bank_ground, d.pool_rim_ground,
			d.village_ground, d.village_square_ground]:
		if g >= 0 and not Ground.is_water(g) and not out.has(g):
			out.append(g)
	return out


func test_there_are_landscapes_past_the_first_six() -> void:
	gt(float(_new_lands().size()), 0.0, "the rule below has something to bind")


func test_every_landscape_colours_the_ground_it_is_made_of() -> void:
	for d: BiomeDef in _new_lands():
		for g: int in _own(d):
			check(d.grounds.has(g),
				"%s is floored in %s and does not say what colour that is" % [d.id, Ground.NAMES[g]])


## And nothing it shows may arrive out of key. A wash the landscape writes is
## taken down by that landscape's own tone; the shared table is not, so an
## unnamed ground comes in brighter than everything beside it and becomes the
## loudest object in the frame.
func test_nothing_a_new_landscape_shows_is_brighter_than_its_own_brightest() -> void:
	for d: BiomeDef in _new_lands():
		var top := 0.0
		var top_of: String = ""
		for g: Variant in d.grounds:
			var c: Color = d.grounds[g]
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			if l > top:
				top = l
				top_of = Ground.NAMES[int(g)]
		gt(top, 0.0, "%s declares some ground" % d.id)
		for g: int in Ground.COUNT:
			if Ground.is_water(g) or g == Ground.FLOOR:
				continue
			var c: Color = GroundColors.wash(g, d.index)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			check(l <= top + 1e-4,
				"%s draws %s at %.0f, brighter than its own brightest ground (%s, %.0f)"
				% [d.id, Ground.NAMES[g], l * 255.0, top_of, top * 255.0])
