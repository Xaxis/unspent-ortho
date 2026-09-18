extends TestCase
## The realm spine: the table is sound, every landscape is registered into a
## realm the game can draw, a landscape in a realm keeps that realm's rules, and
## a world of a realm holds only that realm's landscapes.


func test_the_realm_table_is_sound() -> void:
	for p in Realm.problems():
		fail(p)
	check(Realm.problems().is_empty(), "the realm table is sound")
	for kind: StringName in Realm.KINDS:
		check(Realm.DEFS.has(kind), "%s has a row" % kind)
	eq(Realm.beyond(Realm.SURFACE), Realm.UNDERGROUND, "a shaft out of the surface goes down")
	eq(Realm.beyond(Realm.UNDERGROUND), Realm.SURFACE, "and back up")


func test_every_landscape_is_registered_into_a_realm_the_game_can_draw() -> void:
	for d: BiomeDef in BiomeRegistry.all():
		check(not d.realms.is_empty(), "%s says which realm it is in" % d.id)
		for kind: StringName in d.realms:
			check(Realm.KINDS.has(kind), "%s names realm %s, which is not one" % [d.id, kind])
		# A realm whose medium nobody has drawn yet may be declared in the table
		# and may not hold a landscape: the page is what makes it a place.
		check(Realm.PAGES_DRAWN.has(Realm.page(Realm.of(d))),
			"%s is in %s, whose page (%s) is not drawn yet" % [d.id, Realm.of(d), Realm.page(Realm.of(d))])


func test_a_landscape_keeps_the_rules_of_the_realm_it_is_in() -> void:
	for d: BiomeDef in BiomeRegistry.land():
		var kind := Realm.of(d)
		var banned := Realm.bans(kind)
		for row: Array in d.weather:
			check(not banned.has(row[0]),
				"%s is in %s and its air holds %s, which cannot fall there" % [d.id, kind, row[0]])
		# The light and the grade a realm lends are a ceiling, not a suggestion:
		# a landscape may be darker than its realm, never brighter.
		var lent := Realm.light(kind)
		for ch: Array in [[d.light_tint.r, lent.r, "red"], [d.light_tint.g, lent.g, "green"], [d.light_tint.b, lent.b, "blue"]]:
			check(float(ch[0]) <= float(ch[1]) + 1e-4,
				"%s lights its %s at %.2f, over its realm's %.2f" % [d.id, ch[2], ch[0], ch[1]])
		# Under a roof the realm's dark term is a FLOOR: a landscape may be darker
		# than the realm it is in and never brighter, which is what stops a cave
		# being lit like a coast. Above it the realm lends a starting point and a
		# landscape argues freely with it, held only by the sky's own clamp
		# (tests/biome/test_registry).
		if Realm.roofed(kind):
			check(d.grade.x >= Realm.lift(kind) - 1e-4,
				"%s is in %s and dims only %.2f, less than its realm's %.2f" % [d.id, kind, d.grade.x, Realm.lift(kind)])


func test_a_roofed_realm_has_a_landscape_and_the_surface_keeps_its_own() -> void:
	gt(float(BiomeRegistry.land_in(Realm.UNDERGROUND).size()), 0.0, "something is registered under the world")
	gt(float(BiomeRegistry.land_in(Realm.SURFACE).size()), 5.0, "and the surface still holds its own")
	for d: BiomeDef in BiomeRegistry.land_in(Realm.UNDERGROUND):
		check(not BiomeRegistry.land_in(Realm.SURFACE).has(d),
			"%s cannot be laid in two realms at once yet" % d.id)


func test_a_world_of_a_realm_holds_only_that_realms_landscapes() -> void:
	for kind: StringName in [Realm.SURFACE, Realm.UNDERGROUND]:
		var w := WorldGen.generate(Realm.seed_for(3, kind), 160, &"", kind)
		eq(w.realm, kind, "the world knows which realm it is")
		var ids := {}
		for i in w.country.size():
			ids[w.country[i]] = true
		for c: Variant in ids:
			var d := BiomeRegistry.by_index(int(c))
			check(d.sea or d.realms.has(kind), "a %s world holds %s, which is not in it" % [kind, d.id])
		# And the realm of a tile is the realm of the world it is in — the water
		# at the bottom of it included, which belongs to no realm of its own.
		for p: Vector2 in [Vector2(80, 80), w.spawn, Vector2(20, 140), Vector2(1, 1)]:
			eq(Realm.at(w, p), kind, "the realm of the tile at %s" % p)


func test_each_realm_is_its_own_island_from_one_seed() -> void:
	for s: int in [1, 7, 42]:
		var seen := {}
		for kind: StringName in Realm.KINDS:
			var n := Realm.seed_for(s, kind)
			eq(Realm.seed_for(s, kind), n, "%s of seed %d is the same number twice" % [kind, s])
			check(not seen.has(n), "%s of seed %d collides with another realm's" % [kind, s])
			seen[n] = true
		eq(Realm.seed_for(s, Realm.SURFACE), s, "the surface keeps the seed the player was given")


func test_a_landscape_under_a_roof_is_dark_and_one_above_it_is_not() -> void:
	# The rule the whole scratchboard hangs on (docs/VISION.md §8): a roofed
	# realm dims its page and an open one lifts it. Read off the same field the
	# shader reads (sky.gdshaderinc scales by 1 - grade.x).
	for d: BiomeDef in BiomeRegistry.land():
		if Realm.roofed(Realm.of(d)):
			gt(d.grade.x, 0.0, "%s is under a roof and must dim its page" % d.id)
		else:
			check(d.grade.x <= 0.0, "%s is under the sky and may not dim its noon" % d.id)


## A REALM NOBODY HAS BUILT IS EMPTY, NOT A FAKE OF ANOTHER ONE. `orbital` and
## `era` are in `Realm.KINDS` and no landscape declares them yet. Asked for one
## anyway, the stages fell back on defaults — `Country.COAST` is index 1 and a
## great many readers reach for it when unsure — and what came out was a plausible
## little island with eleven regions, six villages and 378 props, labelled
## `orbital`. It passed every test that asks whether a world generates, because
## every one of them asks that rather than asking whether it is the right world.
func test_a_realm_with_no_landscapes_grows_nothing() -> void:
	for realm: StringName in Realm.KINDS:
		var has := not BiomeRegistry.land_in(realm).is_empty()
		var w := WorldGen.generate(1, 192, &"", realm)
		var land := 0
		for i in w.level.size():
			if w.level[i] > 0:
				land += 1
		if has:
			gt(float(land), 100.0, "%s has landscapes and grows a world" % realm)
			for i in w.country.size():
				if w.level[i] > 0 and w.country[i] != Country.SEA:
					check(BiomeRegistry.by_index(w.country[i]).realms.has(realm),
						"%s: every tile is a landscape of this realm, not another's" % realm)
					break
		else:
			eq(land, 0, "%s has no landscapes, so it has no land" % realm)
			eq(w.regions.size(), 0, "%s: and no places" % realm)
			eq(w.villages.size(), 0, "%s: and nobody living in them" % realm)
