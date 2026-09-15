extends TestCase
## Sketches are drawn at their pixel size in the two idioms: made things with a
## hand (hatched shadow cast on the page), found things with a ruler (no
## hatching, an amber working part).


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
	return c.a > 0.3 and c.a < 0.7 and absf(c.r - UiTheme.PAPER_DEEP.r) < 0.05


func test_every_shape_is_drawn_in_ink() -> void:
	for shape: StringName in UiSketch.SHAPES:
		var parts: Array = UiSketch.SHAPES[shape]
		var img := UiSketch.render(parts, Vector2(32, 32), Vector2i(48, 48), &"stone", &"earth", UiSketch.FOUND_SHAPES.has(shape), 3)
		var filled := _count(img, func(c: Color) -> bool: return c.a > 0.5)
		check(filled > 48 * 48 / 10, "%s covers some of its box: %d" % [shape, filled])
		check(filled < 48 * 48, "%s leaves paper round it" % shape)
		gt(_count(img, _is_ink), 30, "%s has an inked contour" % shape)
	for st: StringName in UiSketch.STATIONS:
		var img := UiSketch.render(UiSketch.STATIONS[st][0], Vector2(48, 32), Vector2i(96, 64), &"stone", &"earth", false, 1)
		gt(_count(img, _is_ink), 60, "station %s is inked" % st)


func test_made_is_hatched_and_found_is_ruled() -> void:
	var made := UiSketch.render(UiSketch.SHAPES[&"axe"], Vector2(32, 32), Vector2i(64, 64), &"stone", &"earth", false, 1)
	var found := UiSketch.render(UiSketch.SHAPES[&"beam"], Vector2(32, 32), Vector2i(64, 64), &"found", &"lens", true, 1)
	gt(_count(made, _is_cast_hatch), 10, "a made thing casts hatched shade on the page")
	eq(_count(found, _is_cast_hatch), 0, "a found thing casts no hatching")
	gt(_count(found, _is_amber), 4, "a found thing's working part glows amber")
	eq(_count(made, _is_amber), 0, "a made tool has no amber part")


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


func test_an_amber_part_is_lit_from_inside() -> void:
	# A slot of charge takes no shade: all of its wash stays amber.
	var slot := [["poly", "a3", [2.0, 2.0, 30.0, 2.0, 30.0, 30.0, 2.0, 30.0]], ["poly", "l", [10.0, 12.0, 22.0, 12.0, 22.0, 20.0, 10.0, 20.0]]]
	var img := UiSketch.render(slot, Vector2(32, 32), Vector2i(64, 64), &"plate", &"lens", true, 1)
	var amber := _count(img, func(c: Color) -> bool: return c.a > 0.99 and absf(c.r - Palette.LENS[2].r) < 0.01 and absf(c.g - Palette.LENS[2].g) < 0.01 and absf(c.b - Palette.LENS[2].b) < 0.01)
	gt(amber, 20 * 12, "the slot is flat amber inside its ruled line: %d" % amber)
	var wick := UiSketch.render(UiSketch.SHAPES[&"dram"], Vector2(32, 32), Vector2i(96, 96), &"found", &"lens", true, 1)
	gt(_count(wick, _is_amber), 60, "a wick shows its charge")
