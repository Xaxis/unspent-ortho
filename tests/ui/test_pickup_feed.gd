extends TestCase
## What was taken, said on the HUD with the thing's own picture (UiPickupFeed),
## and the rule on those pictures: every material the land gives is drawn in a
## shape no other material the land gives is drawn in — its own 9x9 mark and its
## own sketch, since both are chosen by the one shape name. Owner's ask,
## 2026-09-17: "consistent detailed icons of each material". It was a list of
## sharings that could only get shorter, and it got to empty; a tint is not a
## picture, because the slate's phosphor draws every ramp in its own few greens.


func test_a_take_is_a_row_and_the_same_thing_again_adds_to_it() -> void:
	var f := UiPickupFeed.new()
	f.add(&"stone", 2)
	f.add(&"driftwood", 2)
	f.add(&"stone", 1)
	eq(f.rows.size(), 2, "stone merged")
	eq(f.rows[-1].item, &"stone", "the row that grew is the newest")
	eq(int(f.rows[-1].count), 3)
	eq(UiPickupFeed.words_of(f.rows[-1]), "+3 stone")
	f.free()


func test_rows_fade_and_go() -> void:
	var f := UiPickupFeed.new()
	f.add(&"reeds", 2)
	f.step(UiPickupFeed.HOLD * 0.5)
	near(UiPickupFeed.alpha_of(f.rows[0]), 1.0, 1e-6, "full while it holds")
	f.step(UiPickupFeed.HOLD * 0.5 + UiPickupFeed.FADE * 0.5)
	near(UiPickupFeed.alpha_of(f.rows[0]), 0.5, 1e-3, "half way through its fade")
	f.step(UiPickupFeed.FADE)
	eq(f.rows.size(), 0, "gone")
	# Taking the same thing after its row has gone starts a new count.
	f.add(&"reeds", 2)
	eq(int(f.rows[0].count), 2)
	f.free()


func test_the_oldest_row_makes_way() -> void:
	var f := UiPickupFeed.new()
	var ids: Array[StringName] = [&"stone", &"reeds", &"peat", &"coal", &"mussels"]
	for id in ids:
		f.add(id, 1)
	eq(f.rows.size(), UiPickupFeed.MOST)
	eq(f.rows[0].item, &"reeds", "the first went")
	f.free()


func test_a_thing_that_counts_itself_is_counted_in_words() -> void:
	eq(UiPickupFeed.words_of({"item": &"stone", "count": 1}), "+1 stone")
	var plate := &""
	for id: StringName in Items.DEFS:
		if UiRules.has_article(UiRules.item_name(id)):
			plate = id
			break
	if plate != &"":
		var one := UiPickupFeed.words_of({"item": plate, "count": 1})
		check(not one.contains("+1 a ") and not one.contains("+1 an "), "no article after a number: %s" % one)


func test_every_material_the_land_gives_has_a_shape_of_its_own() -> void:
	var given: Dictionary = {}
	for kind: int in Takes.table():
		for o: Dictionary in Takes.options(kind):
			given[o.item] = true
			if not (o.bonus as Array).is_empty():
				given[o.bonus[0]] = true
	var by_shape: Dictionary = {}
	for id: StringName in given:
		var shape: StringName = UiIcons.style_of(id)[0]
		check(UiIcons.ITEMS.has(id) or Items.def(id).has("icon"),
			"%s is given by the land and drawn by a fallback ('%s'): give it a mark" % [id, shape])
		check(shape != &"bundle", "%s is drawn as the unnamed bundle" % id)
		check(UiIcons.SHAPES.has(shape) and UiSketch.SHAPES.has(shape), "%s's shape '%s' has a mark and a sketch" % [id, shape])
		if not by_shape.has(shape):
			by_shape[shape] = []
		(by_shape[shape] as Array).append(id)
	for shape: StringName in by_shape:
		var ids: Array = by_shape[shape]
		ids.sort()
		check(ids.size() == 1, "%s are all drawn as '%s': each material the land gives is drawn its own" % [ids, shape])
	gt(float(by_shape.size()), 20.0, "every material counted (%d shapes)" % by_shape.size())
