extends TestCase
## The Before is THIS land, earlier (docs/STORY.md, docs/WORLD.md §5).
##
## A realm is normally its own island: `Realm.seed_for` mixes a salt in so two
## realms can never land on one another's world. The era is the exception the
## whole story rests on — the ruin he wakes in was his own town — and it was NOT
## the exception for the realm system's whole life: `ERA` carried a salt of its
## own, so 2029 was a different coast with a different spawn, while
## `src/core/realm/portals.gd`'s header already described an era portal as "the
## same coordinates in another time". The invariant was written down and the data
## quietly said otherwise, which is why this is a test and not a comment.


func _world_digest(w: WorldData) -> String:
	var b := PackedByteArray()
	for i in w.level.size():
		b.append(w.level[i] & 255)
	for g in w.ground:
		b.append(g)
	return b.compress().hex_encode().md5_text()


func test_the_before_is_the_same_land() -> void:
	var now := WorldGen.generate(4, 192)
	var then := WorldGen.generate(4, 192, &"", Realm.ERA)
	eq(_world_digest(then), _world_digest(now), "the era is the surface's own ground, tile for tile")
	eq(then.spawn, now.spawn, "he wakes in the same place in both")
	eq(then.regions.size(), now.regions.size(), "the same land holds the same places")
	check(then.regions.size() > 0, "and there are some")


func test_an_era_portal_opens_on_the_same_coordinates() -> void:
	# Portals pair by INDEX because two realms share no coordinates. The era is
	# the one realm that does share them, so index pairing has to come out as
	# coordinate pairing — or a time gate moves you sideways as well as back.
	Portals.forget()
	var now := WorldGen.generate(4, 192)
	var then := WorldGen.generate(4, 192, &"", Realm.ERA)
	var here := Portals.in_world(now)
	var there := Portals.in_world(then)
	check(here.size() > 0, "the surface has a shaft to step into")
	eq(there.size(), here.size(), "and 2029 has the same shafts")
	for i in here.size():
		eq(there[i].pos, here[i].pos, "shaft %d stands on the same tile in both times" % i)


func test_the_era_lays_the_surfaces_landscapes() -> void:
	# Nothing declares `realms = [&"era"]` and nothing should have to: the coast
	# was the coast in 2029. Without this the realm is empty and WorldGen's own
	# guard refuses to grow it.
	var mine := BiomeRegistry.land_in(Realm.ERA)
	eq(mine.size(), BiomeRegistry.land_in(Realm.SURFACE).size(), "the era lays what the surface lays")
	check(mine.size() > 0, "and that is not nothing")


func test_every_other_realm_is_still_its_own_island() -> void:
	# The exception is the era ALONE. Sharing a map must not have leaked into the
	# realms that are meant to be somewhere else.
	var now := _world_digest(WorldGen.generate(4, 192))
	for kind: StringName in [Realm.UNDERGROUND]:
		eq(Realm.land_realm(kind), kind, "%s lays its own landscapes" % kind)
		check(_world_digest(WorldGen.generate(4, 192, &"", kind)) != now,
			"%s is somewhere else, not the surface redressed" % kind)
