extends TestCase
## A HOUSE THE HUNTERS BURNED (props/burnt.gd) is dark: nothing on it is lit.
## The house it is drawn from lights its windows and any neon wired into it by
## its colours' marks; a burned house that kept them would glow at night from
## a shell with nobody in it.


func test_nothing_on_a_burnt_house_is_lit() -> void:
	for d: BiomeDef in BiomeRegistry.land():
		for v in PropModels.variants(PropKind.HOUSE_BURNT, d.index):
			var t := PropModels.template(PropKind.HOUSE_BURNT, v, d.index)
			var lit := 0
			for c: Color in t.made_c:
				var code := roundi(c.a * 255.0)
				if code >= 1 and code <= GroundColors.FAILING:
					lit += 1
			var beacons := 0
			for c: Color in t.found_c:
				if c.a < 0.5:
					beacons += 1
			eq(lit, 0, "burnt house %d in %s has no lit window, lamp or neon" % [v, d.id])
			eq(beacons, 0, "and no beacon on it in %s" % d.id)


## The house it was is lit, or the rule above tests nothing.
func test_the_house_it_was_is_lit() -> void:
	var any := 0
	for d: BiomeDef in BiomeRegistry.land():
		for v in PropModels.variants(PropKind.HOUSE, d.index):
			for c: Color in PropModels.template(PropKind.HOUSE, v, d.index).made_c:
				var code := roundi(c.a * 255.0)
				if code >= 1 and code <= GroundColors.FAILING:
					any += 1
	gt(float(any), 0.0, "houses light their windows")
