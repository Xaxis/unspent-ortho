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


func test_a_machine_is_floored_by_the_same_pen_as_the_land() -> void:
	# The law is "nothing is pure black", not "nothing MADE is": a FOUND surface
	# graded down at night has the same floor as the ground beside it, and the
	# two shaders carry the same two numbers.
	var src := FileAccess.get_file_as_string("res://src/render/found.gdshader")
	check(src.contains("ALBEDO = ink_floor("), "found.gdshader floors its albedo")
	check(src.contains("const float INK_FLOOR = %.4f;" % FLOOR), "at the same floor as the land")
	var ink: Color = Palette.INK[2]
	check(src.contains("const vec3 FOUND_INK = vec3(%.4f, %.4f, %.4f);" % [ink.r, ink.g, ink.b]),
		"and on the same pen colour")


func test_no_prop_is_drawn_below_the_ink_floor() -> void:
	# Props may be ink-dark (a cavity, an open hatch, a cable), never darker.
	# Every landscape the registry holds, so a landscape added as a file cannot
	# dress a prop below the pen without this failing.
	for kind in PropKind.COUNT:
		for v in PropModels.variants(kind):
			for d: BiomeDef in BiomeRegistry.land():
				var t := PropModels.template(kind, v, d.index)
				var worst := 9.0
				for col in t.made_c:
					worst = minf(worst, luma(col))
				for col in t.found_c:
					worst = minf(worst, luma(col))
				if worst < luma(Palette.INK[0]) - 0.0005:
					fail("%s %d in %s is drawn at luma %.4f, under the pen" % [PropKind.NAMES[kind], v, d.id, worst])


func test_no_decor_and_no_ground_is_drawn_below_the_pen() -> void:
	for kd in Decor.KINDS:
		for d: BiomeDef in BiomeRegistry.land():
			for st in Decor.STAGES:
				for col in Decor.template(kd, d.index, st).c:
					if luma(col) < luma(Palette.INK[0]) - 0.0005:
						fail("decor %d in %s is drawn at luma %.4f" % [kd, d.id, luma(col)])
	for g in Ground.COUNT:
		for d: BiomeDef in BiomeRegistry.all():
			for col: Color in [GroundColors.wash(g, d.index), GroundColors.cliff(g, d.index)]:
				if luma(col) < luma(Palette.INK[0]) - 0.0005:
					fail("ground %s in %s is washed at luma %.4f" % [Ground.NAMES[g], d.id, luma(col)])


func test_a_torn_hull_is_closed_so_the_tear_is_an_interior() -> void:
	# The art review found the largest pure-black blob in the game inside a
	# beached hull: the tear must show plating, not the void behind it.
	for v in PropModels.variants(PropKind.HULL):
		var t := PropModels.template(PropKind.HULL, v, BiomeRegistry.index_of(&"coast"))
		var inked := 0
		for col in t.made_c:
			if col.is_equal_approx(Palette.INK[2]) or col.is_equal_approx(Palette.INK[3]):
				inked += 1
		gt(inked, 20, "hull %d closes its tear with inked plating" % v)
