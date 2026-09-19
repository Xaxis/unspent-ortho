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


## The LAND: what the ground is shaped like, which must be identical.
func _land_digest(w: WorldData) -> String:
	var b := PackedByteArray()
	for i in w.level.size():
		b.append(w.level[i] & 255)
	return b.compress().hex_encode().md5_text()


## THE SAME LAND, AND NOT THE SAME COVER. It used to be one digest over levels
## AND ground, called "the surface's own ground, tile for tile", and that wording
## was right only while 2029 held everything 2098 does. It does not: the machines'
## works are not there yet (`Realm.before_the_plan`), and a work stamps the ground
## it stands on — a quarry scar, clinker, a cut road. So the levels are the land
## and must match to the tile, and the GROUND is what sixty-nine years did to it
## and must not.
func test_the_before_is_the_same_land() -> void:
	var now := WorldGen.generate(4, 192)
	var then := WorldGen.generate(4, 192, &"", Realm.ERA)
	eq(_land_digest(then), _land_digest(now), "the era is shaped like this coast, tile for tile")
	eq(then.spawn, now.spawn, "he wakes in the same place in both")
	eq(then.regions.size(), now.regions.size(), "the same land holds the same places")
	check(then.regions.size() > 0, "and there are some")
	# The cover differs, and only where the machines have since been: most of the
	# coast is the same grass and the same shingle it always was.
	var moved := 0
	for i in now.ground.size():
		if now.ground[i] != then.ground[i]:
			moved += 1
	gt(float(moved), 0.0, "sixty-nine years of the plan left a mark on the ground")
	lt(float(moved) / float(now.ground.size()), 0.25,
		"and only where they worked: %d of %d tiles" % [moved, now.ground.size()])


func test_the_plan_has_not_begun_in_2029() -> void:
	# Everything `GenWorks` lays is the machines': ruled on their survey bearing,
	# keeping their hours. In 2029 there is no plan to have laid it, and that is
	# most of what makes the Before a different year rather than a redress.
	var then := WorldGen.generate(4, 192, &"", Realm.ERA)
	var now := WorldGen.generate(4, 192)
	var theirs: Array[int] = [PropKind.RELAY, PropKind.SURVEY, PropKind.DRILL_RIG,
		PropKind.CONVEYOR, PropKind.CHECKPOINT, PropKind.PIPE, PropKind.INTAKE]
	var back := 0
	var ahead := 0
	for p: WorldProp in then.props:
		if theirs.has(p.kind):
			back += 1
	for p: WorldProp in now.props:
		if theirs.has(p.kind):
			ahead += 1
	eq(back, 0, "2029 holds none of the machines' works (%d of them stand in 2098)" % ahead)
	gt(float(ahead), 0.0, "and 2098 holds some, or this proves nothing")


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
	var now := _land_digest(WorldGen.generate(4, 192))
	for kind: StringName in [Realm.UNDERGROUND]:
		eq(Realm.land_realm(kind), kind, "%s lays its own landscapes" % kind)
		check(_land_digest(WorldGen.generate(4, 192, &"", kind)) != now,
			"%s is somewhere else, not the surface redressed" % kind)
