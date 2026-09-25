extends TestCase
## Nothing in this world is BLACK -- and under LANTERN that is two separate
## laws, because the two halves of it moved to different places.
##
## 1. NOTHING IS PAINTED BLACK. No wash a prop, a piece of decor or the ground
##    is drawn with sits below the darkest ink in the palette. That half is
##    unchanged and it is still data, so a landscape added as a file cannot
##    dress a prop below the pen without this failing.
##
## 2. NOTHING IS LIT TO BLACK. This half used to be `ink_floor()`, a floor
##    lifted UNDER every albedo in world, found and outline.gdshader so the
##    renderer's own light could not crush a wash to #000000. It was the largest
##    single reason night was not dark: it put light into a frame no light was
##    falling on, and it put it in the ALBEDO, where nothing could take it out
##    again. LANTERN law 3 wants a night that is genuinely dark and still
##    readable, so the floor is now the ambient light of a real sky
##    (SkyLight.NIGHT_AMBIENT) plus a moon, which a roof can block, a lamp can
##    beat and anyone can measure off a frame.
##
## This pinned the ink floor in three shaders' source text, which no longer
## exists; what it pins instead is the two numbers that replaced it and the
## value the land actually reaches at midnight.

## The darkest ink in the palette. Nothing is painted below it.
const FLOOR := 0.1203


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## Rec.709 over the sRGB the frame is finally written in.
static func luma709(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## What the renderer does between an authored colour and the frame, at a given
## light level: decode to linear, multiply, expose. The tonemapper is left out
## on purpose -- it is monotone and all but the identity this far down the
## curve, so a floor held here is a floor held after it.
static func lit(wash: Color, light: float) -> Color:
	var l := wash.srgb_to_linear()
	return Color(l.r * light, l.g * light, l.b * light).linear_to_srgb()


func test_the_night_has_a_floor_and_it_is_a_light_not_a_lifted_albedo() -> void:
	gt(SkyLight.NIGHT_AMBIENT, 0.0, "there is ambient light at night")
	gt(SkyLight.MOON_NIGHT, 0.0, "and a moon in it")
	# It has to be a LIGHT, which means no shader may lift albedo behind its
	# back. The three that used to are checked by name, and by whether the
	# function is still THERE at all -- a dead one is an invitation.
	for path: String in ["res://src/render/world.gdshader", "res://src/render/found.gdshader",
			"res://src/render/shafts.gdshader"]:
		var src := FileAccess.get_file_as_string(path)
		check(not src.contains("vec3 ink_floor(vec3"), "%s defines no albedo floor" % path)
		check(not src.contains("= ink_floor("), "%s lifts none either" % path)


## THE NUMBER LANTERN IS NAMED AFTER.
##
## docs/LOOK.md law 3: "Night is genuinely dark, which is what makes a lantern
## matter -- and the lantern is the game's own title in miniature." The test the
## owner gave for it is not a number at all: with the lantern out, at 23:00,
## away from any fire, *the player should want to light it*.
##
## There are two ways to fail that and only a narrow band between them. `noir`
## put 51% of its night frame under luma 24, which in a lit room is a black
## screen with a green dot. The first pass of LANTERN put 2.3% under it, which
## is a night you can read the far bank in without help -- so the lantern was a
## decoration, and the fire in the frame was beautiful and unnecessary.
##
## Measured on the canon's own night village at 23:00, no lantern: 31% of the
## frame under luma 24, median 34. A headless test cannot render that frame, so
## what is held here is the arithmetic under it -- the unlit land is DARK, a
## lamp beats it by a wide margin, and there is still a moon on it so the dark
## has shape rather than being a hole.
func test_the_unlit_night_is_dark_enough_that_a_lantern_is_worth_lighting() -> void:
	var coast := BiomeRegistry.index_of(&"coast")
	var turf := GroundColors.wash(Ground.GRASS, coast)
	# Everything here is a RATIO, because `lit()` leaves out the tonemapper's
	# toe, the grade and the air, and so reads a few values high against the
	# frame: the model predicts 45 where the frame measures 34. The ratios it
	# gets right, and they are what the law is actually about.
	var night_light := SkyLight.NIGHT_AMBIENT * SkyLight.EXPOSURE
	var noon_light := (SkyLight.DAY_AMBIENT + SkyLight.SUN_NOON * 0.8) * SkyLight.EXPOSURE
	var unlit := luma709(lit(turf, night_light))
	# The night is held in ABSOLUTE terms, because that is what the frame's luma
	# 24 is about. It used to be held as a share of noon, and noon was lit at
	# 2.6x its albedo, so the day's wash was quietly part of what made the night
	# pass. This is the model's 45 from the header (0.178), with room for the
	# rounding and none for a brighter night.
	lt(unlit, 0.19, "the unlit land at midnight is as dark as the measured frame")
	lt(night_light, noon_light * 0.2, "and noon is more than five times its light")
	gt(unlit, 0.01, "and is still a colour rather than a hole")
	# A lamp has to WIN, and by a lot, or carrying one changes nothing.
	var Lights := load("res://src/systems/15_lights.gd")
	var pool := luma709(lit(turf, (SkyLight.NIGHT_AMBIENT + Lights.GAIN * 0.6) * SkyLight.EXPOSURE))
	gt(pool, unlit * 3.0, "a lamp's pool is worth several times the night round it")
	# And the moon is a real share of what light there is, so the dark has shape.
	gt(SkyLight.MOON_NIGHT * 0.85, SkyLight.NIGHT_AMBIENT * 0.25,
		"there is a moon on it, so a wall still turns away from something")


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
				for col in t.leaf_c:
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
