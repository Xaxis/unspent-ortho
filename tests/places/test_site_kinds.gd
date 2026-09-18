extends TestCase
## The places a landscape is made of (docs/VISION.md §10).
##
## What is held here is that every kind is a PLACE and not scenery: a reason to
## walk there, something standing in it, and — for the ones that are meant to be
## earned — something in the way. Four kinds of place and an absolute count per
## island is what made a bigger landscape a bigger empty one, so the two things
## most worth failing on are a kind that gives nothing and a count that does not
## know how big the region is.


func test_every_kind_can_actually_be_built_today() -> void:
	# A kind whose props do not exist cannot be laid, and this project has a long
	# list of things declared and never claimed. Nothing goes in this table that
	# needs somebody to draw a model first.
	for id: StringName in SiteKinds.ids():
		var r := SiteKinds.row(id)
		check(r.has("props") and not (r.props as Array).is_empty(), "%s stands something up" % id)
		for entry: Variant in r.props:
			var e: Array = entry
			var kind := int(e[0])
			gt(float(kind), -1.0, "%s: a real prop kind" % id)
			lt(float(kind), float(PropKind.COUNT), "%s: %d is not a prop kind" % [id, kind])
			gt(float(e[1]), 0.0, "%s: stands up at least one of %s" % [id, PropKind.NAMES[kind]])
		gt(float(r.radius), 0.0, "%s has a size" % id)
		check(r.has("clear") and float(r.clear) > 0.0, "%s keeps its distance from a village" % id)


func test_a_place_is_a_reason_or_a_challenge_and_never_neither() -> void:
	# The rule the whole file rests on. A kind that gives nothing, guards nothing
	# and is behind nothing is a patch of recoloured ground with props on it —
	# which is what the four kinds we had were, and why an immense landscape made
	# of them would still have been empty.
	for id: StringName in SiteKinds.ids():
		var r := SiteKinds.row(id)
		var gives := String(r.get("holds", &"")) != ""
		var guarded := float(r.get("guard", 0.0)) > 0.0
		var walled := StringName(r.get("behind", SiteKinds.OPEN)) != SiteKinds.OPEN
		var tells := id in [&"memorial", &"camp", &"stone_circle", &"den"]
		check(gives or guarded or walled or tells,
			"%s is a reason, a challenge, a barrier or somebody to meet" % id)


func test_the_walls_are_the_games_own_and_never_new_ones() -> void:
	# A barrier has to be a thing the player already has a verb for, or it is a
	# locked door with a key hidden in a menu. Deep water is `Swim`, a drop is
	# `Jump`, a pressure is `Hazards` answered by gear.
	var walls := [SiteKinds.OPEN, SiteKinds.WATER, SiteKinds.HEIGHT, SiteKinds.PRESSURE]
	for id: StringName in SiteKinds.ids():
		var b := StringName(SiteKinds.row(id).get("behind", SiteKinds.OPEN))
		check(walls.has(b), "%s stands behind something the game already has a verb for (%s)" % [id, b])
	# And not everything is behind one: a landscape where every place is earned is
	# a corridor. Most of what is out there should be walked to and taken.
	var open_ones := 0
	for id: StringName in SiteKinds.ids():
		if StringName(SiteKinds.row(id).get("behind", SiteKinds.OPEN)) == SiteKinds.OPEN:
			open_ones += 1
	gt(float(open_ones) / float(SiteKinds.ids().size()), 0.5, "most places are simply out there")


func test_how_many_a_region_holds_knows_how_big_the_region_is() -> void:
	# THE LINE THAT ANSWERS "a bigger region was a bigger empty one". The count was
	# absolute, per landscape TYPE, across the whole island — so a region ten times
	# the size held exactly as many places.
	var chapter := int(SiteKinds.CHAPTER_TILES)
	eq(SiteKinds.want(4, chapter), 4, "a chapter-sized region holds what the landscape declared")
	eq(SiteKinds.want(4, chapter * 2), 8, "twice the region, twice the places")
	eq(SiteKinds.want(4, chapter / 4), 1, "a quarter of one holds a quarter of them")
	eq(SiteKinds.want(0, chapter), 0, "a landscape that declares none holds none")
	# A spur is still a place with something in it, never a blank.
	gt(SiteKinds.want(1, 200), 0, "the smallest run that is a region still holds one")


func test_a_place_is_a_walk_and_not_a_doorstep() -> void:
	# Every kind keeps a distance from a village, because a landscape whose places
	# are all in the square is a village with scenery round it.
	for id: StringName in SiteKinds.ids():
		gt(float(SiteKinds.row(id).clear), 18.0, "%s is a walk from anybody's village" % id)
