extends TestCase
## Sketches are drawn at their pixel size in the two idioms, then shown as the
## slate's scanner shows them: made things drawn by hand (hatched shade cast
## behind them), found things with a ruler (no hatching, a working part), all
## in the slate's tones: phosphor for what people made, violet for what was
## taken from the machines.


func _count(img: Image, pred: Callable) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if pred.call(img.get_pixel(x, y)):
				n += 1
	return n


func _is_ink(c: Color) -> bool:
	return c.a > 0.99 and c.r < 0.12 and c.g < 0.12 and c.b < 0.16


func _is_amber(c: Color) -> bool:
	return c.a > 0.99 and c.r > 0.85 and c.g > 0.7 and c.b < 0.8 and c.r > c.b + 0.2


func _is_cast_hatch(c: Color) -> bool:
	return c.a > 0.3 and c.a < 0.7 and c.r + c.g + c.b < 0.05


func _is(c: Color, tone: Color) -> bool:
	return c.a > 0.99 and absf(c.r - tone.r) < 0.01 and absf(c.g - tone.g) < 0.01 and absf(c.b - tone.b) < 0.01


func test_every_shape_is_drawn_with_a_contour() -> void:
	for shape: StringName in UiSketch.SHAPES:
		var parts: Array = UiSketch.SHAPES[shape]
		var img := UiSketch.render(parts, Vector2(32, 32), Vector2i(48, 48), &"stone", &"earth", UiSketch.FOUND_SHAPES.has(shape), 3)
		var filled := _count(img, func(c: Color) -> bool: return c.a > 0.5)
		check(filled > 48 * 48 / 10, "%s covers some of its box: %d" % [shape, filled])
		check(filled < 48 * 48, "%s leaves glass round it" % shape)
		gt(_count(img, _is_ink), 30, "%s has an inked contour" % shape)
	for st: StringName in UiSketch.STATIONS:
		var img := UiSketch.render(UiSketch.STATIONS[st][0], Vector2(48, 32), Vector2i(96, 64), &"stone", &"earth", false, 1)
		gt(_count(img, _is_ink), 60, "station %s is inked" % st)


func test_made_is_hatched_and_found_is_ruled() -> void:
	var made := UiSketch.render(UiSketch.SHAPES[&"axe"], Vector2(32, 32), Vector2i(64, 64), &"stone", &"earth", false, 1)
	var found := UiSketch.render(UiSketch.SHAPES[&"beam"], Vector2(32, 32), Vector2i(64, 64), &"found", &"lens", true, 1)
	gt(_count(made, _is_cast_hatch), 10, "a made thing casts hatched shade")
	eq(_count(found, _is_cast_hatch), 0, "a found thing casts no hatching")
	gt(_count(found, _is_amber), 4, "a found thing's working part glows")
	eq(_count(made, _is_amber), 0, "a made tool has no working part")


func test_the_scanner_shows_every_pixel_in_the_slate_tones() -> void:
	var made := UiSketch.to_phosphor(UiSketch.render(UiSketch.SHAPES[&"axe"], Vector2(32, 32), Vector2i(64, 64), &"stone", &"earth", false, 1), UiTheme.PHOSPHOR)
	var tones := UiTheme.PHOSPHOR
	var other := _count(made, func(c: Color) -> bool: return c.a > 0.0 and not tones.any(func(t: Color) -> bool: return _is(c, t)))
	eq(other, 0, "nothing but phosphor tones")
	gt(_count(made, func(c: Color) -> bool: return _is(c, tones[3])), 30, "the contour is bright")
	gt(_count(made, func(c: Color) -> bool: return _is(c, tones[1])), 10, "the cast shade is the faint tone")
	var found := UiSketch.to_phosphor(UiSketch.render(UiSketch.SHAPES[&"beam"], Vector2(32, 32), Vector2i(64, 64), &"found", &"lens", true, 1), UiTheme.MACHINE)
	gt(_count(found, func(c: Color) -> bool: return _is(c, UiTheme.MACHINE[4])), 4, "a found working part is the hottest violet")
	eq(_count(found, func(c: Color) -> bool: return tones.any(func(t: Color) -> bool: return _is(c, t))), 0, "a found thing has no phosphor in it")


func test_items_scan_in_their_own_tone() -> void:
	check(UiIcons.is_found(&"las_hand"), "a found weapon")
	check(UiIcons.is_found(&"wick"), "a charge")
	check(UiIcons.is_found(&"kit_lens"), "salvage kit")
	check(not UiIcons.is_found(&"knife"), "a made knife")
	eq(UiIcons.tones_for(&"las_hand"), UiTheme.MACHINE)
	eq(UiIcons.tones_for(&"axe_hand"), UiTheme.PHOSPHOR)
	for id: StringName in [&"knife", &"las_hand"]:
		for v: Color in UiIcons.colours_for(id).values():
			check(UiIcons.tones_for(id).has(v), "%s's icon is in its tones" % id)


func test_every_carried_thing_has_a_sketch_and_a_mark() -> void:
	for id: StringName in Items.DEFS:
		var st := UiIcons.style_of(id)
		check(UiSketch.SHAPES.has(st[0]), "%s sketches as a known shape (%s)" % [id, st[0]])
		check(UiIcons.SHAPES.has(st[0]), "%s has a list mark" % id)
	for id: StringName in UiIcons.ITEMS:
		check(UiSketch.SHAPES.has(UiIcons.style_of(id)[0]), "%s has a sketch" % id)


func test_warmed_sketches_are_ready_when_asked_for() -> void:
	var ids: Array[StringName] = [&"pot", &"lamp"]
	UiSketch.warm(ids, 40, [&"kiln"], 60)
	UiSketch.wait()
	check(UiSketch._has_ready("i|pot|40"), "drawn ahead")
	var tex := UiSketch.item_texture(&"pot", 40)
	eq(tex.get_size(), Vector2(40, 40))
	check(not UiSketch._has_ready("i|pot|40"), "and taken up as a texture")
	eq(UiSketch.station_size(60), Vector2i(60, 40))


## A page warms the size its own scan window will DRAW. A sketch is cached by its
## size, so warming 234 and drawing 222 warms a picture nobody wants and leaves
## the window empty — which is what the carrying page had been doing, unnoticed
## for as long as an unwarmed sketch was quietly rastered on the frame it was
## needed. (`const` cannot hold a call across classes, so the two are arithmetic
## on one inset rather than one expression, and this is what holds them equal.)
func test_a_page_warms_the_size_its_scan_window_draws() -> void:
	eq(UiInventoryScreen.SKETCH, UiSlate.scan_size(UiInventoryScreen.SCAN),
		"the carrying page warms what its scan window draws")


## One nobody warmed is never drawn on the calling thread. A sketch costs the
## square of its size — at the base's resolution one item is over half a second —
## so asking for one on a frame must hand back nothing and start a worker, or
## opening the carrying page freezes the game every time.
func test_a_sketch_nobody_warmed_is_never_drawn_on_the_caller() -> void:
	check(UiSketch.item_texture(&"whelk", 231) == null, "not drawn in the caller")
	# **A COST, SO THE CHEAPEST OF SEVERAL AND NOT ONE RUN TIMES `machine_slack`.**
	# Slack is for WAITING and clamps at 8, so as a cost bar this stood at 160 ms
	# and could not fail for a real reason. Load only ever ADDS time, so the
	# minimum is the honest number and the value stays where it was. Each run asks
	# for a size nobody has warmed, so each measures the early-out and not a cache
	# hit -- and the thing it is guarding against costs over half a second, so
	# 20 ms is clear of noise and nowhere near a draw.
	var asking := INF
	for i in 5:
		var t0 := Time.get_ticks_usec()
		@warning_ignore("return_value_discarded")
		UiSketch.item_texture(&"whelk", 199 + i * 2)
		asking = minf(asking, float(Time.get_ticks_usec() - t0) / 1000.0)
	lt(asking, 20.0, "and asking does not wait for it")
	check(UiSketch.waiting(), "a worker took it")
	UiSketch.wait()
	var tex := UiSketch.item_texture(&"whelk", 231)
	check(tex != null and tex.get_size() == Vector2(231, 231), "and it is there once the worker is done")


func test_an_amber_part_is_lit_from_inside() -> void:
	# A slot of charge takes no shade: all of its wash stays amber.
	var slot := [["poly", "a3", [2.0, 2.0, 30.0, 2.0, 30.0, 30.0, 2.0, 30.0]], ["poly", "l", [10.0, 12.0, 22.0, 12.0, 22.0, 20.0, 10.0, 20.0]]]
	var img := UiSketch.render(slot, Vector2(32, 32), Vector2i(64, 64), &"plate", &"lens", true, 1)
	var amber := _count(img, func(c: Color) -> bool: return c.a > 0.99 and absf(c.r - Palette.LENS[2].r) < 0.01 and absf(c.g - Palette.LENS[2].g) < 0.01 and absf(c.b - Palette.LENS[2].b) < 0.01)
	gt(amber, 20 * 12, "the slot is flat amber inside its ruled line: %d" % amber)
	var wick := UiSketch.render(UiSketch.SHAPES[&"dram"], Vector2(32, 32), Vector2i(96, 96), &"found", &"lens", true, 1)
	gt(_count(wick, _is_amber), 60, "a wick shows its charge")
