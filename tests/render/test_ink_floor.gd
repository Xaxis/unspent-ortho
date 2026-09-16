extends TestCase
## The ink floor: nothing in the world is drawn black (docs/ART.md section 2,
## "deep shade is denser hatching, never black"; section 6, "nothing is pure
## black"). Every wash a prop, a piece of decor or the ground is drawn with sits
## at or above the floor, and world.gdshader carries the floor to the frame so a
## cavity, a bore or a graded-down wash cannot crush to #000000 either.

## The floor is the luma of Palette.INK[2]: world.gdshader's INK_FLOOR.
const FLOOR := 0.1203


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func test_the_shader_floors_what_it_draws() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/world.gdshader")
	check(src.contains("ALBEDO = ink_floor(sky_apply("), "world.gdshader floors its albedo")
	check(src.contains("const float INK_FLOOR = %.4f;" % FLOOR), "the floor is INK[2]'s luma")
	near(luma(Palette.INK[2]), FLOOR, 0.0005, "INK[2] luma")


func test_no_prop_is_drawn_below_the_ink_floor() -> void:
	# Props may be ink-dark (a cavity, an open hatch, a cable), never darker.
	for kind in PropKind.COUNT:
		for v in PropModels.variants(kind):
			for c: int in Country.LAND:
				var t := PropModels.template(kind, v, c)
				var worst := 9.0
				for col in t.made_c:
					worst = minf(worst, luma(col))
				for col in t.found_c:
					worst = minf(worst, luma(col))
				if worst < luma(Palette.INK[0]) - 0.0005:
					fail("%s %d in %s is drawn at luma %.4f, under the pen" % [PropKind.NAMES[kind], v, Country.NAMES[c], worst])


func test_no_decor_and_no_ground_is_drawn_below_the_pen() -> void:
	for kd in Decor.KINDS:
		for c: int in Country.LAND:
			for st in Decor.STAGES:
				for col in Decor.template(kd, c, st).c:
					if luma(col) < luma(Palette.INK[0]) - 0.0005:
						fail("decor %d in %s is drawn at luma %.4f" % [kd, Country.NAMES[c], luma(col)])
	for g in Ground.COUNT:
		for c in Country.COUNT:
			for col: Color in [GroundColors.wash(g, c), GroundColors.cliff(g, c)]:
				if luma(col) < luma(Palette.INK[0]) - 0.0005:
					fail("ground %s in %s is washed at luma %.4f" % [Ground.NAMES[g], Country.NAMES[c], luma(col)])


func test_a_torn_hull_is_closed_so_the_tear_is_an_interior() -> void:
	# The art review found the largest pure-black blob in the game inside a
	# beached hull: the tear must show plating, not the void behind it.
	for v in PropModels.variants(PropKind.HULL):
		var t := PropModels.template(PropKind.HULL, v, Country.COAST)
		var inked := 0
		for col in t.made_c:
			if col.is_equal_approx(Palette.INK[2]) or col.is_equal_approx(Palette.INK[3]):
				inked += 1
		gt(inked, 20, "hull %d closes its tear with inked plating" % v)
