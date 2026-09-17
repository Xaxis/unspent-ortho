extends TestCase
## What was taken, said on the HUD with its own mark (UiPickupFeed), and the
## ratchet on those marks: every material the world gives is drawn with a mark
## of its own, and where two still share one it is written down here, so the
## list can only get shorter.

## Materials the land gives that still share one shape: the same 9x9 mark and the
## same sketch (the feed's picture), told apart on the glass only by a step of
## tone, since the slate's phosphor draws every ramp in its own few greens.
## A NEW sharing fails the test; drawing one of these its own mark means taking
## it off the list. Owner's ask, 2026-09-17: "consistent detailed icons of each
## material".
const SHARED := {
	&"ore": [&"copper_ore", &"iron_ore", &"tin_ore"],
	&"shell": [&"mussels", &"whelks"],
	&"greens": [&"crottle", &"gorse_cut", &"reeds", &"samphire", &"wrack"],
	&"lump": [&"coal", &"peat"],
	&"stone": [&"brimstone", &"limestone", &"stone"],
}


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


func test_every_material_the_land_gives_has_its_own_mark_or_is_listed() -> void:
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
		if not by_shape.has(shape):
			by_shape[shape] = []
		(by_shape[shape] as Array).append(id)
	for shape: StringName in by_shape:
		var ids: Array = by_shape[shape]
		ids.sort()
		if ids.size() < 2:
			continue
		check(SHARED.has(shape), "%s now share the '%s' mark: draw one its own, or list them in SHARED" % [ids, shape])
		if SHARED.has(shape):
			for id: StringName in ids:
				check((SHARED[shape] as Array).has(id), "%s joined the shared '%s' mark: draw it its own" % [id, shape])
	# The list is a ratchet: an entry that no longer shares is taken off it.
	for shape: StringName in SHARED:
		var now: Array = by_shape.get(shape, [])
		for id: StringName in SHARED[shape]:
			check(now.size() >= 2 and now.has(id), "%s no longer shares '%s': take it off SHARED" % [id, shape])
