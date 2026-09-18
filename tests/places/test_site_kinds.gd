extends TestCase
## The places a landscape is made of (docs/VISION.md §10).
##
## What is held here is that every kind is a PLACE and not scenery: a reason to
## walk there, something standing in it, and — for the ones that are meant to be
## earned — something in the way. Four kinds of place across a whole island is
## what made a bigger landscape a bigger empty one, so the thing most worth
## failing on is a kind that gives nothing.
##
## And one boundary: how MANY of anything a region holds is worldgen's question,
## never this file's.


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


func test_this_file_never_answers_how_many() -> void:
	# THE OWNERSHIP LINE, and it is worth a test because it was crossed. For one
	# day this file held a per-region density of its own beside the one worldgen
	# owns — two answers to one question, which is how every long-lived bug in
	# this project has started: a rule nobody restated when its premise changed.
	#
	# Nothing here may know how big a region is. Every number in this file is
	# about ONE place — how wide it is, how far it keeps from a village — so a
	# constant in the thousands could only be a tile count, and a tile count is
	# `GenScatter`'s, where the tiles are actually known.
	var consts := (SiteKinds as Script).get_script_constant_map()
	for name: String in consts:
		var v: Variant = consts[name]
		if v is float or v is int:
			lt(absf(float(v)), 1000.0, "SiteKinds.%s is about a place, not about a region" % name)
	for id: StringName in SiteKinds.ids():
		var r := SiteKinds.row(id)
		lt(float(r.radius), 1000.0, "%s is a place, not a region" % id)
		lt(float(r.clear), 1000.0, "%s keeps a walk's distance, not a region's" % id)


func test_a_place_is_a_walk_and_not_a_doorstep() -> void:
	# Every kind keeps a distance from a village, because a landscape whose places
	# are all in the square is a village with scenery round it.
	for id: StringName in SiteKinds.ids():
		gt(float(SiteKinds.row(id).clear), 18.0, "%s is a walk from anybody's village" % id)
