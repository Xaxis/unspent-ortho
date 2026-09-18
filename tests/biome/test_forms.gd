extends TestCase
## What a landscape's people BUILT (`BiomeForms`).
##
## The bug this package closed: a landscape could say what its things were MADE
## of and not what SHAPE they were. `Houses.VARIANTS` was a fixed pack of eight
## coastal silhouettes and `GenScatter.HOUSE_MODELS` was that same eight written
## down a second time, so a landscape dressed head to foot in its own materials
## still raised a fishing village. Nothing said so, and it is what blocks every
## urban landscape the owner has asked for.
##
## So the tests here are about a landscape ARGUING: that one which says nothing
## builds exactly what every landscape built before the field existed, that one
## which says "towers" gets towers and a settlement laid out to be walked
## through, and that nothing in the table can quietly stop having geometry.

const Houses := preload("res://src/models/props/houses.gd")
const Towers := preload("res://src/models/props/towers.gd")
const Kit := preload("res://src/models/props/kit.gd")


# --- what a landscape that argues with nothing gets ------------------------------

func test_a_landscape_that_declares_nothing_builds_what_it_always_built() -> void:
	# The whole safety of the change: the default is not "the coast's", it is the
	# one-storey stock every landscape raised before the field existed, dressed by
	# `BiomeDressing` in whatever this landscape is made of.
	var d := BiomeDef.new()
	d.id = &"nowhere"
	var r := BiomeForms.resolve(d)
	eq(r.stock, BiomeForms.PLAIN, "it builds the plain stock")
	eq(String(r.plan), "ring", "scattered round a square")
	eq(r.apart, BiomeForms.RING_APART, "at the distance every seed's village was laid at")
	# AND A LANDSCAPE THAT DECLARES NOTHING ON PURPOSE. The coast is the baseline
	# every other landscape is stated against — its village is the village every
	# seed's first frame has always held — so it arguing with none of this is a
	# decision and not an omission, which is what makes it the honest example.
	var coast := BiomeRegistry.get_def(&"coast")
	check(coast != null, "the coast is registered")
	if coast != null:
		eq(BiomeForms.of(coast.index).stock, BiomeForms.PLAIN,
			"the coast builds what it always built, so its island did not move")


## WHICH LANDSCAPES ARGUE, named, because declaring `built` MOVES THAT
## LANDSCAPE'S ISLAND: the stock's size is how many buildings a settlement
## raises and the plan is where each one stands, so every prop placed after the
## first village in it takes a new id (`WorldStamp.TERRAIN`, GEN 3).
##
## This replaces a loop asserting that EVERY landscape shipped `PLAIN` — written
## as a safety net while the field existed and nothing used it, and true only
## because the one landscape the forms package was built for had a TODO where
## its declaration should be. The net outlived what it was protecting and became
## the thing arguing the city should stay a village. A list that has to be edited
## deliberately is the honest form: adding a landscape here is a decision, and
## the diff says so.
func test_the_landscapes_that_argue_with_the_plain_stock_are_named() -> void:
	var arguing: Array[String] = []
	for land: BiomeDef in BiomeRegistry.land():
		if BiomeForms.of(land.index).stock != BiomeForms.PLAIN:
			arguing.append(String(land.id))
	arguing.sort()
	eq(arguing, ["slums"],
		"a landscape declaring its own `built` moves its island; say so on purpose: %s" % [arguing])


func test_the_plain_stock_is_the_eight_models_in_the_order_they_were_dealt() -> void:
	# Every seed's village is the village it was. The forms are named now, but
	# index 1 must still be the slated house and index 4 the lit cot, or the deal
	# — and every canon frame taken of a village — moves under the rename.
	eq(BiomeForms.PLAIN.size(), 8, "eight forms")
	eq(String(BiomeForms.PLAIN[1]), "slated")
	eq(String(BiomeForms.PLAIN[4]), "cot")
	eq(BiomeForms.of(Country.COAST).lit(), [1, 4] as Array[int],
		"the two that wired a machine's light in are the two that always were")


# --- a landscape that argues -----------------------------------------------------

func test_a_landscape_may_say_its_buildings_are_towers() -> void:
	var d := BiomeDef.new()
	d.id = &"uptown"
	d.built = BiomeForms.new()
	d.built.stock = BiomeForms.RAISED.duplicate()
	d.built.plan = &"row"
	var r := BiomeForms.resolve(d)
	eq(r.stock, BiomeForms.RAISED, "it builds upward")
	eq(String(r.plan), "row", "and stands them along a street")
	eq(r.apart, BiomeForms.ROW_APART, "which pulls the frontage in toward the square")
	check(r.raised(), "its people build upward")
	check(not BiomeForms.of(Country.COAST).raised(), "and a fishing village's do not")
	# The two things that make a tower not a shack with more storeys.
	gt(r.reach(0), BiomeForms.of(Country.COAST).reach(0), "a tower stands on more ground")
	gt(r.room(), 0.0, "and a settlement of them is laid out for the widest of them")


func test_every_form_a_landscape_may_name_is_actually_built() -> void:
	# A form in the table with nobody to build it draws NOTHING — the dispatch's
	# default hands it to `Towers`, whose match simply falls through — and world
	# gen would go on placing it happily. Every row in the table is raised here,
	# and none may come out the same size as another: two forms that are one
	# model are the repeated silhouette the deal exists to stop.
	var seen := {}
	for form: StringName in BiomeForms.FORMS:
		var k := Kit.new()
		k.hand(Ink.HAND)
		if BiomeForms.RAISED.has(form):
			Towers.build(k, form, Country.COAST)
		else:
			# The plain ones are reached the way world gen reaches them: by index
			# into the stock that names them.
			Houses.build(k, PropKind.HOUSE, BiomeForms.PLAIN.find(form), Country.COAST)
		var n := k.made.vertex_count() + k.found.vertex_count()
		gt(n, 300, "%s is built" % form)
		check(not seen.has(n), "%s is its own model and not %s" % [form, seen.get(n, &"")])
		seen[n] = form


func test_the_table_and_the_geometry_agree_about_which_forms_are_lit() -> void:
	# `lit` is world gen's only way of knowing which building to deal nearest the
	# square, and world gen cannot load a model. A form that claims a light and
	# never drew a tube puts the deal on the dark house for ever, silently.
	for v in BiomeForms.PLAIN.size():
		var drew := not PropModels.neon_point(PropKind.HOUSE, v, Country.COAST).is_empty()
		var says: bool = bool(BiomeForms.FORMS[BiomeForms.PLAIN[v]][BiomeForms.LIT])
		eq(drew, says, "%s: the table says lit=%s and the model drew a tube=%s" % [BiomeForms.PLAIN[v], says, drew])
	# AND THE CITY'S STOCK, which this was blind to for its whole life. It walked
	# `PLAIN` only, because when it was written `PLAIN` was the only stock any
	# landscape shipped — so the six forms the forms package exists FOR were the
	# six it could not see. Same shape as `GroundColors.PLAIN`, as the wear law's
	# "underside", as `_clean` keeping one landmass: a guard that was complete
	# when it was written and silently stopped being so.
	var city := BiomeRegistry.get_def(&"slums")
	check(city != null, "the city is registered")
	if city != null:
		for v in BiomeForms.RAISED.size():
			var drew := not PropModels.neon_point(PropKind.HOUSE, v, city.index).is_empty()
			var says: bool = bool(BiomeForms.FORMS[BiomeForms.RAISED[v]][BiomeForms.LIT])
			eq(drew, says, "%s: the table says lit=%s and the model drew a tube=%s"
				% [BiomeForms.RAISED[v], says, drew])


func test_no_stock_is_longer_than_the_model_cache_can_tell_apart() -> void:
	# The ceiling is the cache key's packing, which lives in the renderer; core
	# may not read it, so the number is written down in both and held equal here.
	eq(BiomeForms.MOST, PropModels.MAX_VARIANTS, "core and the cache agree on the ceiling")
	for stock: Array in [BiomeForms.PLAIN, BiomeForms.RAISED]:
		check(stock.size() <= BiomeForms.MOST, "a shipped stock fits under the ceiling")


# --- what a landscape got wrong ---------------------------------------------------

func test_a_stock_nobody_can_build_is_caught() -> void:
	var d := BiomeDef.new()
	d.id = &"wrong"
	d.built = BiomeForms.new()
	d.built.stock = [&"palace", &"washed", &"washed"] as Array[StringName]
	d.built.plan = &"terrace"
	var said := "\n".join(BiomeForms.problems(d))
	check(said.contains("palace"), "a form nobody builds: %s" % said)
	check(said.contains("washed twice"), "one form dealt twice is two buildings the same")
	check(said.contains("terrace"), "a plan nobody lays")

	var one := BiomeDef.new()
	one.id = &"single"
	one.built = BiomeForms.new()
	one.built.stock = [&"tower"] as Array[StringName]
	check("\n".join(BiomeForms.problems(one)).contains("one form"),
		"a stock of one is a settlement of one building drawn over and over")


func test_the_registry_is_still_sound_with_every_landscape_built() -> void:
	var problems := BiomeRegistry.problems()
	for p in problems:
		fail(p)
	check(problems.is_empty(), "no landscape declared forms nobody can raise")


# --- the stamp ---------------------------------------------------------------------

func test_the_forms_are_inside_the_stamp_and_spell_the_same_every_run() -> void:
	# Classified TERRAIN, not LOOK: how many buildings a settlement has is the
	# stock's own size, how much ground each stands on is its form's, and the plan
	# decides where they go — so moving it moves the id of every prop placed after
	# the first village, and a save's `depleted` ids would come back pointing at
	# different things. And an OBJECT field has to be spelled out rather than
	# `str()`ed, or the stamp moves on every launch and refuses every save there is.
	check(WorldStamp.TERRAIN.has("built"), "a building's shape decides the island")
	check(not WorldStamp.LOOK.has("built"), "and is not only its drawing")
	var was := WorldStamp.current()
	eq(WorldStamp.current(), was, "the same registry stamps the same twice")
	var d := BiomeRegistry.all()[BiomeRegistry.count() - 1]
	var keep := d.built
	d.built = BiomeForms.new()
	d.built.stock = BiomeForms.RAISED.duplicate()
	var moved := WorldStamp.current()
	d.built = keep
	check(moved != was, "a landscape that starts building towers moves the stamp")
	eq(WorldStamp.current(), was, "and putting it back puts the stamp back")


func test_the_stamped_fields_are_every_field_and_no_others() -> void:
	# `BiomeForms.stamped()` is written out by hand, because `get_property_list()`
	# orders itself however the engine likes and nothing promises that survives an
	# export — and a landscape that stamped differently in the desktop build and
	# the web one would have each build refuse the other's saves by name, with
	# nothing in the editor able to show it.
	#
	# The price of writing it down is that a field added and not listed is silently
	# outside the stamp: a landscape could change where its buildings go and every
	# save on disk would open onto the moved island believing it knew it. So the
	# list is held to being EXACTLY the declared fields, which is the only thing
	# that makes the boring version safe in both directions.
	var declared := PackedStringArray()
	for p: Dictionary in BiomeForms.new().get_property_list():
		if int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name := str(p.get("name", ""))
		if name.begins_with("_"):
			continue
		declared.append(name)
	var listed := BiomeForms.new().stamped()
	var missing := PackedStringArray()
	for name: String in declared:
		if not listed.has(name):
			missing.append(name)
	var unknown := PackedStringArray()
	for name: String in listed:
		if not declared.has(name):
			unknown.append(name)
	eq(" ".join(missing), "", "every declared field is stamped; these are not, so a landscape could move its buildings under a save")
	eq(" ".join(unknown), "", "and nothing is stamped that is not declared")


func test_an_object_that_names_no_fields_is_never_spelled_as_an_instance_id() -> void:
	# The whole bug this arm exists to stop: `str()` on an object is an id that
	# changes every run, so a stamp that fell back to it would move on every
	# launch and refuse every save on disk. A type that forgets `stamped()` must
	# still spell the SAME for two instances of it, or the fallback carries the
	# original bug.
	#
	# Asked of `_spell` directly, and that is deliberate. The obvious test — put
	# one on a `BiomeDef` and stamp the registry — cannot be written: `built` is
	# typed, so the assignment is refused at runtime, `built` stays null, both
	# stamps come out as "none" and the test passes having proved nothing. It did
	# exactly that before this comment was written.
	var a := WorldStamp._spell(RefCounted.new())
	var b := WorldStamp._spell(RefCounted.new())
	eq(a, b, "two objects that name no fields spell alike: %s against %s" % [a, b])
	check(not a.contains("<"), "and never as the `<RefCounted#...>` an instance id prints as: %s" % a)
	# And one that DOES name its fields spells them, so the fallback is not simply
	# what everything gets.
	var f := BiomeForms.new()
	f.stock = [&"tower"] as Array[StringName]
	check(WorldStamp._spell(f).contains("tower"), "a type that names its fields has them spelled")
