extends TestCase
## Every MENDED thing is drawn as both idioms at once (docs/LOOK.md): FOUND
## parts in the machines' violet, bound with MADE cord in phosphor. A 9x9 with no
## cord pixel in it reads as a machine part nobody made, however the ramp is
## written.
##
## This is the rule that made the `icon` door in `UiIcons.style_of` necessary:
## every fallback that door sits in front of reaches for a shape with no cord
## (`bundle`, `kit`, `glim`), so a whole tech tree of mended gear would have been
## drawn as machine parts. It is pinned here rather than left to the next reader —
## it has to fail for a piece that named no icon just as loudly as for one that
## named the wrong shape.

## The characters `UiIcons.colours_for` draws in phosphor: the binding, the haft.
const CORD := ["4", "5", "6"]


static func cord_pixels(id: StringName) -> int:
	var n := 0
	for row: String in UiIcons.shape_of(id):
		for c: String in row:
			n += 1 if CORD.has(c) else 0
	return n


func test_every_mended_row_has_binding_drawn_on_it() -> void:
	var seen := 0
	for id: StringName in Items.DEFS:
		if not Gear.is_mended(id):
			continue
		seen += 1
		var shape: StringName = UiIcons.style_of(id)[0]
		check(UiIcons.SHAPES.has(shape), "%s draws as '%s', which is not a mark" % [id, shape])
		check(UiSketch.SHAPES.has(shape), "%s has no sketch at size" % id)
		gt(float(cord_pixels(id)), 1.0,
			"%s is mended and its mark ('%s') has no cord on it: name an icon with some" % [id, shape])
	gt(float(seen), 25.0, "the mended tree is drawn (%d pieces)" % seen)


func test_a_mended_mark_is_read_in_both_palettes() -> void:
	for id: StringName in Items.DEFS:
		if not Gear.is_mended(id):
			continue
		var cols := UiIcons.colours_for(id)
		check(UiTheme.MACHINE.has(cols["3"]), "%s's plate is the stolen module's violet" % id)
		check(UiTheme.PHOSPHOR.has(cols["5"]), "%s's cord is phosphor" % id)


## The door itself: an item may only name a mark that exists, and a ramp that
## exists, so the icon table keeps authority over what can be drawn.
func test_an_item_may_only_name_a_mark_and_ramps_that_exist() -> void:
	var named := 0
	for id: StringName in Items.DEFS:
		var icon: Variant = Items.def(id).get("icon", null)
		if icon == null:
			continue
		named += 1
		var rows := icon as Array
		check(rows != null and rows.size() == 3, "%s's icon is [shape, ramp, ramp]" % id)
		if rows == null or rows.size() != 3:
			continue
		check(UiIcons.SHAPES.has(StringName(rows[0])), "%s names mark '%s', which does not exist" % [id, rows[0]])
		for i: int in [1, 2]:
			# `ramp` falls back to STONE for a name it does not know, so the only way
			# to catch a typo is to ask whether the name is one of the real ones.
			check(UiIcons.ramp(StringName(rows[i])) != UiIcons.ramp(&"stone") or StringName(rows[i]) == &"stone",
				"%s names ramp '%s', which is not a ramp" % [id, rows[i]])
	gt(float(named), 40.0, "the economy's rows name their own marks (%d)" % named)


func test_an_item_that_names_no_icon_still_gets_one() -> void:
	# The door must not have changed what anything already drawn draws as.
	eq(StringName(UiIcons.style_of(&"knife")[0]), &"knife")
	eq(StringName(UiIcons.style_of(&"shield_plate")[0]), &"shield")
	eq(StringName(UiIcons.style_of(&"soup")[0]), &"bowl")
	# And a row nobody listed anywhere still lands on a real mark.
	check(UiIcons.SHAPES.has(StringName(UiIcons.style_of(&"nothing_at_all")[0])),
		"an unknown id still has something to draw")
