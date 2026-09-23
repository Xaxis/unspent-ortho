extends TestCase
## The Before is THIS land, earlier (docs/STORY.md, docs/DESIGN.md).
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


## THE SAME LAND AND THE SAME COVER; THE DIFFERENCE IS WHAT STANDS ON IT. This
## header said the opposite twice over, and each version was believed because it
## was specific. First it was one digest over levels AND ground, "the surface's
## own ground, tile for tile". Then it was split, on the reasoning that a work
## stamps the ground it stands on, and demanded the ground DIFFER. Measured: it
## never does, on any tile of any size, because `GenWorks` only ever reads
## `w.ground` and runs after `GenSurface` has written it. Both versions were a
## sentence about a mechanism nobody had checked.
func test_the_before_is_the_same_land() -> void:
	var now := WorldGen.generate(4, 192)
	var then := WorldGen.generate(4, 192, &"", Realm.ERA)
	eq(_land_digest(then), _land_digest(now), "the era is shaped like this coast, tile for tile")
	eq(then.spawn, now.spawn, "he wakes in the same place in both")
	eq(then.regions.size(), now.regions.size(), "the same land holds the same places")
	check(then.regions.size() > 0, "and there are some")
	# **AND THE MARK IS NOT IN THE GROUND FIELD, WHICH THIS ASKED FOR AND CANNOT
	# HAVE.** It used to require `w.ground` to differ somewhere, on the strength of
	# a comment saying a work stamps the ground it stands on — a quarry scar,
	# clinker, a cut road. It does not: all eight reads of `w.ground` in
	# `gen_works.gd` are comparisons, the stage runs inside `GenScatter.props`
	# which is AFTER `GenSurface` has written the cover, and a work's `mark`
	# (`&cut`/`&scorch`/`&quarry`/`&bores`) is recorded on its LANDMARK for
	# `WorksMap` to paint. So the two years share the ground on all 36,864 tiles
	# and always will, whatever the size, and a bar demanding otherwise could only
	# ever be met by a feature nobody has written. Whether they SHOULD scar the
	# ground is a real question and it is task #55, not something to smuggle in
	# under a red test.
	#
	# So the claim is asked where the mark actually is. The land is the same land —
	# levels above, and the cover here — and the sixty-nine years are entirely in
	# what STANDS on it.
	var moved := 0
	for i in now.ground.size():
		if now.ground[i] != then.ground[i]:
			moved += 1
	eq(moved, 0, "the cover is the same cover: a work marks its landmark, never the ground")
	var marked_now := 0
	var marked_then := 0
	for m: Dictionary in now.landmarks:
		if m.has("mark"):
			marked_now += 1
	for m: Dictionary in then.landmarks:
		if m.has("mark"):
			marked_then += 1
	gt(float(marked_now), 0.0, "sixty-nine years of the plan left its marks (%d)" % marked_now)
	eq(marked_then, 0, "and 2029 carries none of them")
	gt(float(now.props.size()), float(then.props.size()),
		"and 2098 stands more on the same ground: %d against %d" % [now.props.size(), then.props.size()])


func test_the_plan_has_not_begun_in_2029() -> void:
	# Everything `GenWorks` lays is the machines': ruled on their survey bearing,
	# keeping their hours. In 2029 there is no plan to have laid it, and that is
	# most of what makes the Before a different year rather than a redress.
	var then := WorldGen.generate(4, 192, &"", Realm.ERA)
	var now := WorldGen.generate(4, 192)
	# READ OFF THE PLAN'S OWN LIST, never a copy: `GenWorks.THEIRS` is what
	# `GenScatter.allow` clears before the plan, so a kind added to one and not the
	# other cannot pass here.
	var theirs: Array[int] = GenWorks.THEIRS
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
